-- scripts/wagstaff_affinity_revive.lua
-- v2.0.19: Decoupled affinity revive abilities.
--
-- The butler haunt-resurrection is now a PLAIN revive (bot dies, player revives).
-- These NEW affinity abilities trigger on the player's "respawnfromghost" event,
-- regardless of revive source (butler haunt, meat effigy, touch stone, amulet).
--
-- CELESTIAL (wagstaff_celestial_possession tag):
--   - Revive with FULL HP / sanity / hunger.
--   - +100 max-HP bonus (via DeltaMaxHealth).
--   - 25% damage absorption for the duration.
--   - 5 HP/sec regen for the duration (guarantees the health-badge up-arrow).
--   - Duration: 60s (a "revive protection window").
--   - FX: ruinshat-style shield (forcefield prefab) recolored celestial blue,
--         respawned CONTINUOUSLY (every 2.5s) so the shield persists the full
--         duration. Initial spawn delayed ~0.6s to sync with the ghost->body
--         materialization (NOT on the ghost).
--
-- SHADOW (wagstaff_shadow_possession tag):
--   - Spawns a SHADOW CLONE that fights for Wagstaff.
--   - Clone base: vanilla `shadowwaxwell` (Maxwell's shadow duelist NPC) — has
--     built-in combat AI, follower brain, proper NPC setup. Reliable spawn.
--   - Clone HP: 150 (Wagstaff's HP), NON-invincible (can take damage / die).
--   - Clone damage: 34 (voidcloth scythe ballpark).
--   - Voidcloth gear visual via OverrideSymbol (armor_voidcloth body + scythe).
--   - Duration: 120s (a combat-assist window after revive).
--   - FX: statue_transition_2 spawn (same as Buster clone) + shadow_despawn
--         despawn (same as Buster clone).
--
-- Balance: celestial +100 HP / 25% / 60s, shadow 150 HP / 120s / 34 dmg / non-invincine.

local G = GLOBAL

local CELESTIAL_DURATION   = 60     -- seconds
local CELESTIAL_HP_BONUS   = 100    -- +max HP
local CELESTIAL_ABSORPTION = 0.25   -- 25% damage absorption
local CELESTIAL_REGEN_RATE = 5      -- HP per second (also drives the badge up-arrow)
local CELESTIAL_SHIELD_RESPAWN_INTERVAL = 2.5  -- seconds between shield FX respawns

local SHADOW_CLONE_DURATION = 120   -- seconds
local SHADOW_CLONE_HP       = 150
local SHADOW_CLONE_DAMAGE   = 34    -- voidcloth scythe ballpark

-- v2.0.19: unconditional debug prints (always visible in server log) so the
-- user can diagnose spawn issues without enabling Debug mode.
local function _log(msg)
    print("[AFFINITY REVIVE] " .. tostring(msg))
end
local function _logF(fmt, ...)
    print("[AFFINITY REVIVE] " .. string.format(fmt, ...))
end
local _dbg  = G.WagstaffDbg  or _log
local _dbgF = G.WagstaffDbgF or _logF

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

    -- +100 max HP via DeltaMaxHealth (canonical DST API). Fallback: SetMaxHealth.
    if health then
        if health.DeltaMaxHealth then
            health:DeltaMaxHealth(CELESTIAL_HP_BONUS)
        else
            health:SetMaxHealth(health.maxhealth + CELESTIAL_HP_BONUS)
        end
        health:SetPercent(1)
    end

    -- 25% damage absorption (save the old value to restore on expiry).
    if health then
        player._wagstaff_celestial_old_absorb = health.absorb or 0
        health:SetAbsorptionAmount(CELESTIAL_ABSORPTION)
    end

    -- 5 HP/sec regen — this GUARANTEES the health-badge up-arrow (green pulsing
    -- arrow) is visible for the full duration. DeltaMaxHealth alone may not
    -- trigger the badge indicator in all DST builds; regen always does.
    -- Thematically appropriate: celestial light actively healing you.
    if health and health.SetRegen then
        health:SetRegen(CELESTIAL_REGEN_RATE, 1)
    end

    -- Cancel any previous buff/shield tasks (no stacking on repeated revives).
    if player._wagstaff_celestial_shield_task then
        player._wagstaff_celestial_shield_task:Cancel()
        player._wagstaff_celestial_shield_task = nil
    end
    if player._wagstaff_celestial_expire_task then
        player._wagstaff_celestial_expire_task:Cancel()
    end
    -- Remove any leftover shield FX from a previous buff.
    if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
        player._wagstaff_celestial_shield_fx:Remove()
    end
    player._wagstaff_celestial_shield_fx = nil

    -- FX: ruinshat-style shield (forcefield) recolored celestial blue,
    -- respawned CONTINUOUSLY so the shield visual persists the full 60s.
    local function SpawnShield()
        if not player:IsValid() or not player.entity then return end
        -- Remove previous shield if still around (anti-stack / refresh).
        if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
            player._wagstaff_celestial_shield_fx:Remove()
        end
        local fx = G.SpawnPrefab("forcefield")
        if fx then
            fx.entity:SetParent(player.entity)
            -- Recolor to celestial blue (default forcefield is greenish).
            -- v2.0.19 FIX: SetMultColour/SetAddColour need 4 args (r,g,b,a).
            -- The previous code passed only 3 args, which left alpha nil/0
            -- and made the shield invisible.
            if fx.AnimState then
                fx.AnimState:SetMultColour(0.45, 0.6, 1.0, 1.0)
                fx.AnimState:SetAddColour(0.1, 0.2, 0.45, 0)
            end
            player._wagstaff_celestial_shield_fx = fx
            _logF("SpawnShield: forcefield spawned, parent=%s", tostring(player.prefab))
        else
            _log("SpawnShield: WARN — SpawnPrefab('forcefield') returned nil")
        end
    end

    -- Initial shield at 0.6s (sync with spawn anim), then continuous respawns.
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() then return end
        _log("Celestial: initial SpawnShield + starting periodic respawns")
        SpawnShield()
        player._wagstaff_celestial_shield_task =
            player:DoPeriodicTask(CELESTIAL_SHIELD_RESPAWN_INTERVAL, SpawnShield)
    end)

    -- Expire the buff after the duration.
    player._wagstaff_celestial_expire_task = player:DoTaskInTime(CELESTIAL_DURATION, function()
        if not player:IsValid() then return end
        _log("Celestial: buff expiring")
        -- Stop the continuous shield respawns.
        if player._wagstaff_celestial_shield_task then
            player._wagstaff_celestial_shield_task:Cancel()
            player._wagstaff_celestial_shield_task = nil
        end
        -- Remove the last shield FX.
        if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
            player._wagstaff_celestial_shield_fx:Remove()
        end
        player._wagstaff_celestial_shield_fx = nil
        -- Remove the +100 max HP.
        if health and health:IsAlive() then
            if health.DeltaMaxHealth then
                health:DeltaMaxHealth(-CELESTIAL_HP_BONUS)
            else
                health:SetMaxHealth(math.max(1, health.maxhealth - CELESTIAL_HP_BONUS))
            end
        end
        -- Stop regen (clears the badge up-arrow).
        if health and health.SetRegen then
            health:SetRegen(0, 0)
        end
        -- Restore absorption.
        if health then
            health:SetAbsorptionAmount(player._wagstaff_celestial_old_absorb or 0)
        end
        player._wagstaff_celestial_expire_task = nil
        _logF("Celestial: buff expired after %ss", tostring(CELESTIAL_DURATION))
    end)

    _logF("Celestial: full stats + %s HP + %s%% absorb + %s HP/s regen for %ss",
        tostring(CELESTIAL_HP_BONUS), tostring(CELESTIAL_ABSORPTION * 100),
        tostring(CELESTIAL_REGEN_RATE), tostring(CELESTIAL_DURATION))
end

----------------------------------------------------------------
-- SHADOW CLONE
----------------------------------------------------------------

local function RemoveShadowClone(player)
    local clone = player._wagstaff_shadow_clone
    if clone and clone:IsValid() then
        local cx, cy, cz = clone.Transform:GetWorldPosition()
        local fx = G.SpawnPrefab("shadow_despawn")
        if fx then fx.Transform:SetPosition(cx, cy, cz) end
        clone:Remove()
        _log("SHADOW: clone removed (shadow_despawn FX)")
    end
    player._wagstaff_shadow_clone = nil
end

local function SpawnShadowClone(player)
    _log("SHADOW: SpawnShadowClone called")
    -- Remove any existing clone first (no stacking on repeated revives).
    if player._wagstaff_shadow_clone and player._wagstaff_shadow_clone:IsValid() then
        _log("SHADOW: removing existing clone first")
        RemoveShadowClone(player)
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    local angle = math.random() * 2 * G.PI
    local offset = 1.8
    local sx = px + math.cos(angle) * offset
    local sz = pz + math.sin(angle) * offset

    -- v2.0.19 FIX: use vanilla `shadowwaxwell` (Maxwell's shadow duelist) as the
    -- base instead of `wagstaff` (player prefab). Player prefabs cannot be
    -- reliably spawned as NPCs via SpawnPrefab — they require the engine's player
    -- spawn system, and direct SpawnPrefab creates a broken/invisible entity that
    -- gets cleaned up. `shadowwaxwell` is a vanilla NPC with built-in combat AI,
    -- follower brain, and proper NPC setup — it spawns reliably.
    -- Appearance: dark shadow humanoid (shadow-Maxwell duelist look).
    -- Voidcloth gear visual is applied via OverrideSymbol (best-effort — if the
    -- symbol names don't match the shadowwaxwell build, it's a safe no-op).
    local clone = G.SpawnPrefab("shadowwaxwell")
    if not clone then
        _log("SHADOW: ERROR — SpawnPrefab('shadowwaxwell') returned nil")
        return
    end
    _log("SHADOW: shadowwaxwell spawned successfully")
    clone.Transform:SetPosition(sx, 0, sz)

    -- Tag as a shadow clone (for identification / retarget exclusion).
    clone:AddTag("shadow_wagstaff_clone")
    clone:AddTag("shadowcreature")
    -- Don't persist (always recreated on next revive).
    clone.persists = false

    -- Rename.
    if clone.components.named then
        clone.components.named:SetName("Shadow Wagstaff")
    end
    clone.name = "Shadow Wagstaff"

    -- HP 150, NON-invincible (can take damage / die).
    if clone.components.health then
        clone.components.health:SetMaxHealth(SHADOW_CLONE_HP)
        clone.components.health:SetCurrentHealth(SHADOW_CLONE_HP)
        clone.components.health:SetInvincible(false)
        clone.components.health:SetAbsorptionAmount(0)
    else
        _log("SHADOW: WARN — clone has no health component")
    end

    -- Combat: shadow-scythe damage.
    if clone.components.combat then
        clone.components.combat:SetDefaultDamage(SHADOW_CLONE_DAMAGE)
        clone.components.combat:SetAttackPeriod(2)
        clone.components.combat:SetRange(3)
        -- Retarget: prefer player's target, else nearby hostiles.
        clone.components.combat:SetRetargetFunction(2, function(inst)
            if player and player:IsValid() and player.components.combat then
                local pt = player.components.combat.target
                if pt and pt:IsValid() and not pt:IsInLimbo() and inst.components.combat:CanTarget(pt) then
                    return pt
                end
            end
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = G.TheSim:FindEntities(x, y, z, 10, nil,
                {"player", "shadowcreature", "wall", "INLIMBO"})
            for _, e in ipairs(ents) do
                if e ~= inst and e.components.combat
                   and inst.components.combat:CanTarget(e)
                   and not e:HasTag("shadow_wagstaff_clone") then
                    return e
                end
            end
            return nil
        end)
        clone.components.combat:SetKeepTargetFunction(function(inst, target)
            return target ~= nil and target:IsValid() and not target:IsInLimbo()
        end)
    else
        _log("SHADOW: WARN — clone has no combat component")
    end

    -- Follow the player (shadowwaxwell has a follower component + brain that
    -- handles following and fighting automatically — no manual driver needed).
    if clone.components.follower then
        clone.components.follower:SetLeader(player)
    else
        _log("SHADOW: WARN — clone has no follower component")
    end

    -- Voidcloth gear visual via OverrideSymbol (best-effort).
    -- armor_voidcloth body + voidcloth_scythe weapon. If the shadowwaxwell's
    -- build doesn't have these symbols, the calls are safe no-ops.
    if clone.AnimState then
        clone.AnimState:OverrideSymbol("swap_body", "armor_voidcloth", "swap_body")
        clone.AnimState:OverrideSymbol("swap_object", "swap_voidcloth_scythe", "swap_voidcloth_scythe")
        -- Tint slightly darker to match the shadow theme.
        clone.AnimState:SetMultColour(0.5, 0.5, 0.5, 1.0)
    end

    -- Spawn FX: same as the Buster clone (statue_transition_2), synced with
    -- the clone's spawn animation.
    local spawn_fx = G.SpawnPrefab("statue_transition_2")
    if spawn_fx then
        spawn_fx.Transform:SetPosition(sx, 0, sz)
    end
    if clone.SoundEmitter then
        clone.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
    end
    _log("SHADOW: spawn FX (statue_transition_2) + sound played")

    -- Despawn after duration.
    clone:DoTaskInTime(SHADOW_CLONE_DURATION, function()
        if clone and clone:IsValid() then
            _logF("SHADOW: clone duration (%ss) expired, removing", tostring(SHADOW_CLONE_DURATION))
            RemoveShadowClone(player)
        end
    end)

    player._wagstaff_shadow_clone = clone
    _logF("SHADOW: clone ready, HP=%s dmg=%s duration=%ss",
        tostring(SHADOW_CLONE_HP), tostring(SHADOW_CLONE_DAMAGE), tostring(SHADOW_CLONE_DURATION))
end

----------------------------------------------------------------
-- ENTRY POINT
----------------------------------------------------------------

local function ApplyOnRevive(player)
    if not player or not player:IsValid() then return end

    local celestial = player:HasTag("wagstaff_celestial_possession")
    local shadow    = player:HasTag("wagstaff_shadow_possession")

    _logF("respawnfromghost: player=%s celestial=%s shadow=%s",
        tostring(player.prefab), tostring(celestial), tostring(shadow))

    -- Slight delay so the revive (health restore, ghost->body transition) has
    -- started and the player's tags/components have settled.
    player:DoTaskInTime(0.1, function()
        if not player:IsValid() then
            _log("ApplyOnRevive: player invalid after delay, aborting")
            return
        end
        -- Re-check tags after delay (tags should persist but be safe).
        local cel = player:HasTag("wagstaff_celestial_possession")
        local shd = player:HasTag("wagstaff_shadow_possession")
        _logF("ApplyOnRevive (after 0.1s): celestial=%s shadow=%s", tostring(cel), tostring(shd))
        if cel then
            _log("ApplyOnRevive: -> ApplyCelestialBuff")
            ApplyCelestialBuff(player)
        elseif shd then
            _log("ApplyOnRevive: -> SpawnShadowClone")
            SpawnShadowClone(player)
        else
            _log("ApplyOnRevive: no affinity tag — no ability applied")
        end
    end)
end

-- Hook: listen for the player's revive event. This fires for ANY revive source
-- (butler haunt, meat effigy, touch stone, amulet). The skill tree's exclusion
-- locks guarantee a Wagstaff has at most one of the two affinity tags.
_log("Module loaded — registering AddPrefabPostInit('wagstaff') revive listener")
AddPrefabPostInit("wagstaff", function(inst)
    if not G.TheWorld or not G.TheWorld.ismastersim then return end
    inst:ListenForEvent("respawnfromghost", function(inst, data)
        _logF("respawnfromghost EVENT FIRED on %s, source=%s",
            tostring(inst.prefab), tostring(data and data.source and data.source.prefab or "nil"))
        ApplyOnRevive(inst)
    end)
    _log("AddPrefabPostInit('wagstaff'): revive listener registered")
end)
