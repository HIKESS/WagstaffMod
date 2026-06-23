-- scripts/wagstaff_affinity_revive.lua
-- v2.0.24: Decoupled affinity revive abilities.
--
-- The butler haunt-resurrection is a PLAIN revive (bot dies, player revives).
-- These affinity abilities trigger on the player's "respawnfromghost" event,
-- regardless of revive source (butler haunt, meat effigy, touch stone, amulet).
--
-- CELESTIAL (wagstaff_celestial_possession tag):
--   - Revive with FULL HP / sanity / hunger.
--   - +100 max-HP bonus (via DeltaMaxHealth).
--   - 25% damage absorption for the duration.
--   - 5 HP/sec regen for the duration (drives the health-badge up-arrow).
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
--   - Applies a SHADOW BUFF to the player for 60s:
--       * Damage dealt:        +50%   (combat.damagemultiplier * 1.5)
--       * Attack speed:        +20%   (attackperiod * 0.8, re-enforced periodically
--                                      so weapon swaps don't drop the buff)
--       * Movement speed:      +15%   (locomotor external speed multiplier)
--       * Duration:            60s
--   - Visual: subtle dark tint on the player for the duration (cleared on expiry).
--   - FX: statue_transition_2 spawn FX at 0.6s (synced with revive anim),
--         shadow_despawn FX on expiry.
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

local SHADOW_DURATION        = 60   -- seconds
local SHADOW_DAMAGE_MULT     = 1.50 -- +50% damage dealt
local SHADOW_ATTACK_PERIOD   = 0.80 -- attackperiod * 0.80 = +20% attack speed
local SHADOW_MOVE_SPEED_MULT = 1.15 -- +15% movement speed
local SHADOW_ENFORCE_INTERVAL = 0.5 -- re-apply attackperiod after weapon swaps

-- v2.0.24: ALL debugs go through the mod's debug system (toggle on/off in the
-- config menu "Debug mode"). No-op when WagstaffDbg is unavailable.
local _dbg  = G.WagstaffDbg  or function(...) end
local _dbgF = G.WagstaffDbgF or function(...) end

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
    local sanity = player.components.sanity
    local hunger = player.components.hunger

    -- Full sanity / hunger.
    if sanity then sanity:SetPercent(1) end
    if hunger then hunger:SetPercent(1) end

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
        if health and health:IsAlive() then
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
        player._wagstaff_celestial_expire_task = nil
        _dbgF("[AFFINITY] Celestial: buff expired after %ss", tostring(CELESTIAL_DURATION))
    end)

    _dbgF("[AFFINITY] Celestial: full stats + %s HP + %s%% absorb + %s HP/s regen for %ss",
        tostring(CELESTIAL_HP_BONUS), tostring(CELESTIAL_ABSORPTION * 100),
        tostring(CELESTIAL_REGEN_RATE), tostring(CELESTIAL_DURATION))
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

    -- 1) Damage +50%: multiply combat.damagemultiplier (NOT overwritten by
    --    weapon equip — it's a separate field from the weapon's damage).
    if combat then
        player._wagstaff_shadow_dmg_orig = combat.damagemultiplier or 1
        combat.damagemultiplier = player._wagstaff_shadow_dmg_orig * SHADOW_DAMAGE_MULT
    else
        _dbg("[AFFINITY] Shadow: WARN — player has no combat component; damage buff skipped")
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

    -- Spawn FX at 0.6s (synced with the revive animation — ghost->body).
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() then return end
        local px, py, pz = player.Transform:GetWorldPosition()
        local fx = G.SpawnPrefab("statue_transition_2")
        if fx then fx.Transform:SetPosition(px, py, pz) end
        if player.SoundEmitter then
            player.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
        end
        _dbg("[AFFINITY] Shadow: spawn FX (statue_transition_2) + sound played (synced with revive anim)")
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
        -- Despawn FX.
        if player:IsValid() then
            local px, py, pz = player.Transform:GetWorldPosition()
            local fx = G.SpawnPrefab("shadow_despawn")
            if fx then fx.Transform:SetPosition(px, py, pz) end
        end
        -- Clear saved state.
        player._wagstaff_shadow_dmg_orig = nil
        player._wagstaff_shadow_ap_base = nil
        player._wagstaff_shadow_ap_buffed = nil
        player._wagstaff_shadow_expire_task = nil
        _dbgF("[AFFINITY] Shadow: buff expired after %ss", tostring(SHADOW_DURATION))
    end)

    _dbgF("[AFFINITY] Shadow: buff applied — dmg x%s, atk speed x%s, move speed x%s, %ss",
        tostring(SHADOW_DAMAGE_MULT), tostring(1 / SHADOW_ATTACK_PERIOD),
        tostring(SHADOW_MOVE_SPEED_MULT), tostring(SHADOW_DURATION))
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

    -- Slight delay so the revive (health restore, ghost->body transition) has
    -- started and the player's tags/components have settled.
    player:DoTaskInTime(0.1, function()
        if not player:IsValid() then
            _dbg("[AFFINITY] ApplyOnRevive: player invalid after delay, aborting")
            return
        end
        local cel = player:HasTag("wagstaff_celestial_possession")
        local shd = player:HasTag("wagstaff_shadow_possession")
        _dbgF("[AFFINITY] ApplyOnRevive (after 0.1s): celestial=%s shadow=%s", tostring(cel), tostring(shd))
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
