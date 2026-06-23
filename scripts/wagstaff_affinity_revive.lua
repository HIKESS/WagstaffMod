-- scripts/wagstaff_affinity_revive.lua
-- v2.0.24: Decoupled affinity revive abilities.
--
-- The butler haunt-resurrection is a PLAIN revive (bot dies, player revives).
-- These affinity abilities trigger on the player's "respawnfromghost" event,
-- regardless of revive source (butler haunt, meat effigy, touch stone, amulet).
--
-- CELESTIAL (wagstaff_celestial_possession tag):
--   - Revive with FULL HP (sanity/hunger NOT restored — v2.0.25 nerf).
--   - +100 max-HP bonus (via DeltaMaxHealth).
--   - 25% damage absorption for the duration.
--   - 5 HP/sec regen for the duration (drives the health-badge up-arrow).
--   - +15% damage dealt for the duration (v2.0.39 — closes the gap with Shadow).
--   - Duration: 60s.
--   - FX: ruinshat-style shield using the PERSISTENT `forcefieldfx` prefab
--         (NOT `forcefield` which self-removes after ~2-3s). `forcefieldfx`
--         stays until explicitly Remove()'d, so NO continuous respawns are
--         needed — spawn once, parent to player, tint celestial blue, remove
--         on expiry. Reference: "Bone Armor: Shield FX" mod (workshop 2832660562).
--         Initial spawn at 0.6s to sync with the ghost->body materialization
--         (the revive animation delay), so the shield does NOT appear on the ghost.
--
-- SHADOW (wagstaff_shadow_possession tag):
--   - NO clone. (All clone-spawn logic removed in v2.0.24.)
--   - Revive with FULL HP (no +max HP bonus, unlike celestial — v2.0.25).
--   - Applies a SHADOW BUFF to the player for 60s:
--       * Damage dealt:        +50%   (combat.damagemultiplier * 1.5)
--       * Attack speed:        +20%   (attackperiod * 0.8, re-enforced periodically)
--       * Movement speed:      +15%   (locomotor external speed multiplier)
--       * Lifesteal:           15%    (heal 15% of damage dealt — sustain via offense)
--       * Duration:            60s
--   - Visual: subtle dark tint on the player for the duration (cleared on expiry).
--   - FX (v2.0.37): PERSISTENT forcefieldfx shield (SAME prefab as celestial)
--         recolored BLACK/dark-purple for the shadow theme. Spawned ONCE at
--         0.6s (synced with revive anim) and stays for the full 60s — NO
--         continuous respawns needed (forcefieldfx stays until Remove()).
--         v2.0.36 tried continuous respawn of shadow_shield1 (a quick-effect
--         prefab that self-removes ~2-3s) every 2.5s — worked but was hacky and
--         flickered on each re-spawn. Using the same persistent shield as
--         celestial gives a smooth, natural visual that matches the celestial
--         revive but in shadow colors. ghost_spawn sound on initial spawn.
--         (v2.0.30: statue_transition_2 spawn + shadow_despawn despawn.
--          v2.0.36: continuous respawn of shadow_shield1.
--          v2.0.37: single persistent forcefieldfx, tinted dark — same approach
--          as celestial, just different color.)
--
-- ALL debug output is routed through the mod's debug system (G.WagstaffDbg /
-- G.WagstaffDbgF), gated by the "Debug mode" config toggle. Zero-cost when off.
--
-- Affinity tag persistence: player tags added via AddTag are not reliably saved
-- across save/load. Safety net re-applies the possession tags on spawn by
-- reading the skilltreeupdater state.

local G = GLOBAL

----------------------------------------------------------------
-- TUNING
----------------------------------------------------------------

local CELESTIAL_DURATION   = 60     -- seconds
local CELESTIAL_HP_BONUS   = 100    -- +max HP
local CELESTIAL_ABSORPTION = 0.25   -- 25% damage absorption
local CELESTIAL_REGEN_RATE = 5      -- HP per second (drives the health-badge up-arrow)
-- v2.0.39: Celestial revive now also grants +15% damage, matching the Shadow
-- revive's offensive identity with a smaller offensive bonus. This closes the
-- gap where Shadow revive (+50% dmg) was strictly better than Celestial for
-- DPS situations. Celestial is still defensively stronger (absorb + regen +
-- max HP), Shadow is still offensively stronger (50% vs 15% dmg + atk speed +
-- lifesteal), but Celestial is no longer a pure-defensive dead pick.
local CELESTIAL_DAMAGE_MULT = 1.15  -- +15% damage dealt

local SHADOW_DURATION        = 60   -- seconds
local SHADOW_DAMAGE_MULT     = 1.50 -- +50% damage dealt
local SHADOW_ATTACK_PERIOD   = 0.80 -- attackperiod * 0.80 = +20% attack speed
local SHADOW_MOVE_SPEED_MULT = 1.15 -- +15% movement speed
local SHADOW_LIFESTEAL_PCT   = 0.15 -- 15% of damage dealt healed (sustain via offense)
local SHADOW_ENFORCE_INTERVAL = 0.5 -- re-apply attackperiod after weapon swaps

-- v2.0.24: ALL debugs go through the mod's debug system (toggle on/off in the
-- config menu "Debug mode"). No-op when WagstaffDbg is unavailable.
local _dbg  = G.WagstaffDbg  or function(...) end
local _dbgF = G.WagstaffDbgF or function(...) end

-- v2.0.27 FIX: capture standard-library functions as locals from GLOBAL.
-- In the modimport'd environment, bare globals like `pcall` can resolve to nil
-- when a closure runs later inside the scheduler (DoTaskInTime / DoPeriodicTask
-- callbacks). Capturing them as upvalues at file-load time is safe and standard
-- DST modding practice. (Crash was: "attempt to call global 'pcall' (a nil
-- value)" at line 76 inside the DoTaskInTime(2) ReapplyAffinityTags callback.)
local pcall    = G.pcall    or pcall
local ipairs   = G.ipairs   or ipairs
local pairs    = G.pairs    or pairs
local tostring = G.tostring or tostring
local math     = G.math     or math

----------------------------------------------------------------
-- Affinity tag persistence (safety net for save/load)
----------------------------------------------------------------

-- Robustly check whether a skill is activated in the player's skilltreeupdater,
-- handling both array-style and map-style return values from GetSkillTree().
local function IsSkillActivatedInTree(inst, skillname)
    if not (inst and inst.components and inst.components.skilltreeupdater) then
        return false
    end
    local stu = inst.components.skilltreeupdater
    local ok, skilltree = pcall(function() return stu:GetSkillTree() end)
    if not ok or not skilltree then return false end
    if skilltree[skillname] ~= nil then return true end
    for _, s in ipairs(skilltree) do
        if s == skillname then return true end
    end
    for k, _ in pairs(skilltree) do
        if k == skillname then return true end
    end
    return false
end

local function ReapplyAffinityTags(inst)
    if not (inst and inst:IsValid()) then return end
    if G.TheWorld and not G.TheWorld.ismastersim then return end

    if not inst:HasTag("wagstaff_shadow_possession")
       and IsSkillActivatedInTree(inst, "wagstaff_shadow_possession") then
        inst:AddTag("wagstaff_shadow_possession")
        _dbg("[AFFINITY] Re-applied wagstaff_shadow_possession tag on load (safety net)")
    end
    if not inst:HasTag("wagstaff_celestial_possession")
       and IsSkillActivatedInTree(inst, "wagstaff_celestial_possession") then
        inst:AddTag("wagstaff_celestial_possession")
        _dbg("[AFFINITY] Re-applied wagstaff_celestial_possession tag on load (safety net)")
    end
end

----------------------------------------------------------------
-- CELESTIAL
----------------------------------------------------------------

local function ApplyCelestialBuff(player)
    local health = player.components.health

    -- v2.0.25 NERF: no longer restores full sanity/hunger (only full HP).
    -- +100 max HP via DeltaMaxHealth. Fallback: SetMaxHealth.
    if health then
        if health.DeltaMaxHealth then
            health:DeltaMaxHealth(CELESTIAL_HP_BONUS)
        else
            health:SetMaxHealth(health.maxhealth + CELESTIAL_HP_BONUS)
        end
        health:SetPercent(1)
    end

    -- 25% damage absorption (save old value to restore on expiry).
    if health then
        player._wagstaff_celestial_old_absorb = health.absorb or 0
        health:SetAbsorptionAmount(CELESTIAL_ABSORPTION)
    end

    -- 5 HP/sec regen — GUARANTEES the health-badge up-arrow is visible.
    if health and health.SetRegen then
        health:SetRegen(CELESTIAL_REGEN_RATE, 1)
    end

    -- v2.0.39: +15% damage dealt (save old damagemultiplier to restore on expiry).
    -- Same pattern as the Shadow buff's damage multiplier.
    local combat = player.components.combat
    if combat then
        player._wagstaff_celestial_dmg_orig = combat.damagemultiplier or 1
        combat.damagemultiplier = player._wagstaff_celestial_dmg_orig * CELESTIAL_DAMAGE_MULT
    end

    -- Cancel any previous buff/shield (no stacking on repeated revives).
    if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
        player._wagstaff_celestial_shield_fx:Remove()
    end
    player._wagstaff_celestial_shield_fx = nil
    if player._wagstaff_celestial_expire_task then
        player._wagstaff_celestial_expire_task:Cancel()
    end

    -- FX: PERSISTENT forcefieldfx shield (NOT forcefield which self-removes).
    -- Reference: "Bone Armor: Shield FX" mod (workshop 2832660562) — uses
    -- forcefieldfx, parents to owner, disables the Light, tints via SetMultColour.
    -- forcefieldfx stays until Remove(), so NO continuous respawns are needed.
    -- Spawn at 0.6s to sync with the revive animation (ghost->body materialization).
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() or not player.entity then return end
        -- Remove any leftover shield from a previous buff.
        if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
            player._wagstaff_celestial_shield_fx:Remove()
        end
        local fx = G.SpawnPrefab("forcefieldfx")
        if fx then
            fx.entity:SetParent(player.entity)
            -- Disable the Light component (reference mod does this — the default
            -- light is white and looks wrong on a blue shield).
            if fx.Light then
                fx.Light:Enable(false)
            end
            -- Recolor to celestial blue (4 args: r,g,b,a — alpha required).
            if fx.AnimState then
                fx.AnimState:SetMultColour(0.45, 0.6, 1.0, 1.0)
                fx.AnimState:SetAddColour(0.1, 0.2, 0.45, 0)
            end
            player._wagstaff_celestial_shield_fx = fx
            _dbgF("[AFFINITY] Celestial: forcefieldfx spawned (persistent), parent=%s", tostring(player.prefab))
        else
            _dbg("[AFFINITY] Celestial: WARN — SpawnPrefab('forcefieldfx') returned nil")
        end
    end)

    -- Expire the buff after the duration.
    player._wagstaff_celestial_expire_task = player:DoTaskInTime(CELESTIAL_DURATION, function()
        if not player:IsValid() then return end
        _dbg("[AFFINITY] Celestial: buff expiring")
        -- Remove the shield FX (forcefieldfx is persistent — must Remove()).
        if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
            player._wagstaff_celestial_shield_fx:Remove()
        end
        player._wagstaff_celestial_shield_fx = nil
        -- v2.0.29 FIX: Health component has no :IsAlive() method (crash at line 194
        -- in v2.0.27/v2.0.28). The canonical DST API is :IsDead(). Use the inverse.
        if health and not health:IsDead() then
            if health.DeltaMaxHealth then
                health:DeltaMaxHealth(-CELESTIAL_HP_BONUS)
            else
                health:SetMaxHealth(math.max(1, health.maxhealth - CELESTIAL_HP_BONUS))
            end
        end
        if health and health.SetRegen then
            health:SetRegen(0, 0)
        end
        if health then
            health:SetAbsorptionAmount(player._wagstaff_celestial_old_absorb or 0)
        end
        -- v2.0.39: restore the original damage multiplier.
        if player.components.combat and player._wagstaff_celestial_dmg_orig then
            player.components.combat.damagemultiplier = player._wagstaff_celestial_dmg_orig
        end
        player._wagstaff_celestial_dmg_orig = nil
        player._wagstaff_celestial_expire_task = nil
        _dbgF("[AFFINITY] Celestial: buff expired after %ss", tostring(CELESTIAL_DURATION))
    end)

    _dbgF("[AFFINITY] Celestial: full HP (no san/hunger) + %s max HP + %s%% absorb + %s HP/s regen + %s%% damage for %ss",
        tostring(CELESTIAL_HP_BONUS), tostring(CELESTIAL_ABSORPTION * 100),
        tostring(CELESTIAL_REGEN_RATE), tostring((CELESTIAL_DAMAGE_MULT - 1) * 100),
        tostring(CELESTIAL_DURATION))
end

----------------------------------------------------------------
-- SHADOW BUFF (no clone — all clone logic removed in v2.0.24)
----------------------------------------------------------------

local function ApplyShadowBuff(player)
    local combat   = player.components.combat
    local locomotor = player.components.locomotor

    -- Cancel any previous shadow buff (no stacking on repeated revives).
    if player._wagstaff_shadow_enforce_task then
        player._wagstaff_shadow_enforce_task:Cancel()
        player._wagstaff_shadow_enforce_task = nil
    end
    if player._wagstaff_shadow_expire_task then
        player._wagstaff_shadow_expire_task:Cancel()
    end
    -- Remove any previous lifesteal listener (no stacking on re-revive).
    if player._wagstaff_shadow_lifesteal_fn then
        player:RemoveEventCallback("onattackother", player._wagstaff_shadow_lifesteal_fn)
    end
    -- Restore previously-saved base values (so we don't compound on re-revive).
    if combat and player._wagstaff_shadow_dmg_orig then
        combat.damagemultiplier = player._wagstaff_shadow_dmg_orig
    end
    if combat and player._wagstaff_shadow_ap_base then
        combat.attackperiod = player._wagstaff_shadow_ap_base
    end
    if locomotor then
        locomotor:RemoveExternalSpeedMultiplier(player, "wagstaff_shadow_buff")
    end
    -- Clear previous dark tint.
    if player.AnimState and player._wagstaff_shadow_tinted then
        player.AnimState:SetMultColour(1, 1, 1, 1)
        player.AnimState:SetAddColour(0, 0, 0, 0)
        player._wagstaff_shadow_tinted = nil
    end
    -- Remove previous forcefieldfx shield (no orphan shield on re-revive).
    if player._wagstaff_shadow_shield_fx and player._wagstaff_shadow_shield_fx:IsValid() then
        player._wagstaff_shadow_shield_fx:Remove()
    end
    player._wagstaff_shadow_shield_fx = nil

    -- 0) Full HP recovery (matches celestial's HP recovery, but WITHOUT the
    --    +max HP bonus — just heal to current max).
    if player.components.health then
        player.components.health:SetPercent(1)
    end

    -- 1) Damage +50%: multiply combat.damagemultiplier (NOT overwritten by
    --    weapon equip — it's a separate field from the weapon's damage).
    if combat then
        player._wagstaff_shadow_dmg_orig = combat.damagemultiplier or 1
        combat.damagemultiplier = player._wagstaff_shadow_dmg_orig * SHADOW_DAMAGE_MULT
    else
        _dbg("[AFFINITY] Shadow: WARN — player has no combat component; damage buff skipped")
    end

    -- 1b) Lifesteal 15%: heal for 15% of damage dealt. Ties survivability to
    --     offense (shadow theme: drain life as you fight). Scales with the
    --     +50% damage bonus above (more damage = more healing per hit).
    -- v2.0.42 FIX: DST's "onattackother" event does NOT include damage in its
    --     data payload (unlike the target-side "attacked" event). The old code
    --     read data.damage which was always nil, so lifesteal NEVER fired.
    --     Now we recalculate the damage the same way Combat:DoAttack does, via
    --     Combat:CalcDamage(target, weapon). This mirrors how the batbat's
    --     onattack callback heals, but scaled to a percentage — and WITHOUT
    --     the sanity penalty the batbat applies (batbat drains sanity equal to
    --     half the heal). No sanity penalty here, matching the shadow_battleaxe
    --     / umbral weapon design (drain life, keep your mind).
    if player.components.health then
        player._wagstaff_shadow_lifesteal_fn = function(inst, data)
            if not data or not data.target then return end
            local target = data.target
            if not target or not target:IsValid() then return end
            -- No lifesteal from walls/structures (they have no life to drain).
            if target:HasTag("wall") or target:HasTag("engineering") then return end
            local target_health = target.components.health
            if not target_health or target_health:IsDead() then return end

            local c = inst.components.combat
            if not c then return end

            -- Recalculate the damage dealt for this attack. CalcDamage is
            -- idempotent (pure calculation, no side effects) so calling it
            -- again here is safe. It rolls the same variance/crit logic as
            -- the actual attack, giving an accurate lifesteal value.
            local dmg = 0
            if c.CalcDamage then
                local ok, val = pcall(c.CalcDamage, c, target, data.weapon)
                if ok then dmg = val or 0 end
            end
            -- Fallback: weapon base damage * player damage multiplier (covers
            -- any DST version where CalcDamage is unavailable/renamed).
            if dmg <= 0 then
                local weapon = data.weapon
                if weapon and weapon.components and weapon.components.weapon then
                    dmg = weapon.components.weapon.damage or 0
                elseif c.defaultdamage then
                    dmg = c.defaultdamage
                end
                dmg = dmg * (c.damagemultiplier or 1)
            end
            if dmg <= 0 then return end

            local heal = dmg * SHADOW_LIFESTEAL_PCT
            local hp = inst.components.health
            -- v2.0.29 FIX: Health has no :IsAlive() — use :IsDead() inverse.
            if hp and not hp:IsDead() and not hp:IsInvincible() then
                hp:DoDelta(heal, nil, "wagstaff_shadow_lifesteal")
            end
        end
        player:ListenForEvent("onattackother", player._wagstaff_shadow_lifesteal_fn)
    end

    -- 2) Attack speed +20%: reduce attackperiod by 20%. Weapon swaps re-set
    --    attackperiod via the weapon's onequip, so we re-enforce periodically.
    if combat then
        player._wagstaff_shadow_ap_base = combat.attackperiod or (G.TUNING and G.TUNING.WILSON_ATTACK_PERIOD) or 2
        player._wagstaff_shadow_ap_buffed = player._wagstaff_shadow_ap_base * SHADOW_ATTACK_PERIOD
        combat.attackperiod = player._wagstaff_shadow_ap_buffed
    else
        _dbg("[AFFINITY] Shadow: WARN — player has no combat component; attack-speed buff skipped")
    end

    -- 3) Movement speed +15%: external speed multiplier (clean DST API,
    --    survives weapon swaps / state changes, used by coffee etc.).
    if locomotor and locomotor.SetExternalSpeedMultiplier then
        locomotor:SetExternalSpeedMultiplier(player, "wagstaff_shadow_buff", SHADOW_MOVE_SPEED_MULT)
    else
        _dbg("[AFFINITY] Shadow: WARN — player has no locomotor or SetExternalSpeedMultiplier; speed buff skipped")
    end

    -- 4) Visual: subtle dark tint on the player for the buff duration.
    if player.AnimState then
        player.AnimState:SetMultColour(0.70, 0.70, 0.78, 1.0)
        player.AnimState:SetAddColour(0.05, 0.03, 0.10, 0)
        player._wagstaff_shadow_tinted = true
    end

    -- Re-enforce the attackperiod reduction every 0.5s (catches weapon swaps
    -- that reset attackperiod to the new weapon's base). When a swap is
    -- detected, adopt the new base and re-apply the 20% reduction.
    if combat then
        player._wagstaff_shadow_enforce_task = player:DoPeriodicTask(SHADOW_ENFORCE_INTERVAL, function()
            if not player:IsValid() or not player.components.combat then return end
            local c = player.components.combat
            local cur = c.attackperiod
            if cur == nil then return end
            -- If the current attackperiod matches our buffed value, it's still
            -- our buff — nothing to do. Otherwise a weapon swap reset it to a
            -- new base: adopt it and re-apply the reduction.
            if cur ~= player._wagstaff_shadow_ap_buffed then
                player._wagstaff_shadow_ap_base = cur
                player._wagstaff_shadow_ap_buffed = cur * SHADOW_ATTACK_PERIOD
                c.attackperiod = player._wagstaff_shadow_ap_buffed
            end
        end)
    end

    -- v2.0.37: PERSISTENT forcefieldfx shield (SAME prefab as celestial revive),
    -- recolored BLACK/dark-purple for the shadow theme. Unlike shadow_shield1
    -- (a quick-effect prefab that self-removes ~2-3s), forcefieldfx stays until
    -- explicitly Remove()'d — so a SINGLE spawn at 0.6s persists for the full
    -- 60s buff. Same approach as celestial (consistent visual language), just a
    -- different tint. No continuous respawns, no flicker.
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() or not player.entity then return end
        -- Remove any leftover shield from a previous buff.
        if player._wagstaff_shadow_shield_fx and player._wagstaff_shadow_shield_fx:IsValid() then
            player._wagstaff_shadow_shield_fx:Remove()
        end
        local fx = G.SpawnPrefab("forcefieldfx")
        if fx then
            fx.entity:SetParent(player.entity)
            -- Disable the Light component (same as celestial — the default
            -- white light looks wrong on a dark shield).
            if fx.Light then
                fx.Light:Enable(false)
            end
            -- Recolor to shadow black/dark-purple (4 args: r,g,b,a).
            -- MultColour darkens the shield to near-black; AddColour gives a
            -- faint dark-purple glow so it reads as "shadow" not just "off".
            if fx.AnimState then
                fx.AnimState:SetMultColour(0.12, 0.12, 0.15, 1.0)
                fx.AnimState:SetAddColour(0.03, 0.0, 0.05, 0)
            end
            player._wagstaff_shadow_shield_fx = fx
            _dbgF("[AFFINITY] Shadow: forcefieldfx spawned (persistent, black tint), parent=%s", tostring(player.prefab))
            -- Som de reviver.
            if player.SoundEmitter then
                player.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
            end
        else
            _dbg("[AFFINITY] Shadow: WARN — SpawnPrefab('forcefieldfx') returned nil")
        end
    end)

    -- Expire the buff after the duration.
    player._wagstaff_shadow_expire_task = player:DoTaskInTime(SHADOW_DURATION, function()
        if not player:IsValid() then return end
        _dbg("[AFFINITY] Shadow: buff expiring")
        -- Stop the enforcement task.
        if player._wagstaff_shadow_enforce_task then
            player._wagstaff_shadow_enforce_task:Cancel()
            player._wagstaff_shadow_enforce_task = nil
        end
        -- Remove lifesteal listener.
        if player._wagstaff_shadow_lifesteal_fn then
            player:RemoveEventCallback("onattackother", player._wagstaff_shadow_lifesteal_fn)
            player._wagstaff_shadow_lifesteal_fn = nil
        end
        -- Restore damage multiplier.
        if player.components.combat and player._wagstaff_shadow_dmg_orig then
            player.components.combat.damagemultiplier = player._wagstaff_shadow_dmg_orig
        end
        -- Restore attack period to the tracked base.
        if player.components.combat and player._wagstaff_shadow_ap_base then
            player.components.combat.attackperiod = player._wagstaff_shadow_ap_base
        end
        -- Remove speed multiplier.
        if player.components.locomotor then
            player.components.locomotor:RemoveExternalSpeedMultiplier(player, "wagstaff_shadow_buff")
        end
        -- Clear dark tint.
        if player.AnimState and player._wagstaff_shadow_tinted then
            player.AnimState:SetMultColour(1, 1, 1, 1)
            player.AnimState:SetAddColour(0, 0, 0, 0)
            player._wagstaff_shadow_tinted = nil
        end
        -- Remove forcefieldfx shield (persistent — must Remove()).
        if player._wagstaff_shadow_shield_fx and player._wagstaff_shadow_shield_fx:IsValid() then
            player._wagstaff_shadow_shield_fx:Remove()
        end
        player._wagstaff_shadow_shield_fx = nil
        -- Clear saved state.
        player._wagstaff_shadow_dmg_orig = nil
        player._wagstaff_shadow_ap_base = nil
        player._wagstaff_shadow_ap_buffed = nil
        player._wagstaff_shadow_expire_task = nil
        _dbgF("[AFFINITY] Shadow: buff expired after %ss", tostring(SHADOW_DURATION))
    end)

    _dbgF("[AFFINITY] Shadow: buff applied — full HP, dmg x%s, atk speed x%s, move speed x%s, lifesteal %s%%, %ss",
        tostring(SHADOW_DAMAGE_MULT), tostring(1 / SHADOW_ATTACK_PERIOD),
        tostring(SHADOW_MOVE_SPEED_MULT), tostring(SHADOW_LIFESTEAL_PCT * 100),
        tostring(SHADOW_DURATION))
end

----------------------------------------------------------------
-- ENTRY POINT
----------------------------------------------------------------

local function ApplyOnRevive(player)
    if not player or not player:IsValid() then return end

    local celestial = player:HasTag("wagstaff_celestial_possession")
    local shadow    = player:HasTag("wagstaff_shadow_possession")

    _dbgF("[AFFINITY] respawnfromghost: player=%s celestial=%s shadow=%s",
        tostring(player.prefab), tostring(celestial), tostring(shadow))

    -- v2.0.42: Delay before applying the affinity ability, so the resurrection
    -- animation (ghost->body materialization + the butler haunt-raise anim)
    -- finishes before the buff/shield activates. Was 0.1s (too early — the
    -- ability fired mid-animation). +0.5s as requested gives the animation
    -- time to complete for a cleaner visual transition.
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() then
            _dbg("[AFFINITY] ApplyOnRevive: player invalid after delay, aborting")
            return
        end
        local cel = player:HasTag("wagstaff_celestial_possession")
        local shd = player:HasTag("wagstaff_shadow_possession")
        _dbgF("[AFFINITY] ApplyOnRevive (after 0.6s): celestial=%s shadow=%s", tostring(cel), tostring(shd))
        if cel then
            _dbg("[AFFINITY] ApplyOnRevive: -> ApplyCelestialBuff")
            ApplyCelestialBuff(player)
        elseif shd then
            _dbg("[AFFINITY] ApplyOnRevive: -> ApplyShadowBuff")
            ApplyShadowBuff(player)
        else
            _dbg("[AFFINITY] ApplyOnRevive: no affinity tag — no ability applied")
        end
    end)
end

_dbg("[AFFINITY] Module loaded — registering AddPrefabPostInit('wagstaff') revive listener")
AddPrefabPostInit("wagstaff", function(inst)
    if not G.TheWorld or not G.TheWorld.ismastersim then return end
    inst:ListenForEvent("respawnfromghost", function(inst, data)
        _dbgF("[AFFINITY] respawnfromghost EVENT FIRED on %s, source=%s",
            tostring(inst.prefab), tostring(data and data.source and data.source.prefab or "nil"))
        ApplyOnRevive(inst)
    end)
    _dbg("[AFFINITY] AddPrefabPostInit('wagstaff'): revive listener registered")

    -- Affinity tag persistence safety net (mirrors boss-kill tag re-application).
    inst:DoTaskInTime(2, function()
        if not inst:IsValid() then return end
        ReapplyAffinityTags(inst)
    end)
    inst:DoTaskInTime(5, function()
        if not inst:IsValid() then return end
        ReapplyAffinityTags(inst)
    end)
end)
