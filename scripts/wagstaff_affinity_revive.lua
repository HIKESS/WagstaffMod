-- scripts/wagstaff_affinity_revive.lua
-- v2.0.21: Decoupled affinity revive abilities.
--
-- The butler haunt-resurrection is now a PLAIN revive (bot dies, player revives).
-- These affinity abilities trigger on the player's "respawnfromghost" event,
-- regardless of revive source (butler haunt, meat effigy, touch stone, amulet).
--
-- CELESTIAL (wagstaff_celestial_possession tag):
--   - Revive with FULL HP / sanity / hunger.
--   - +100 max-HP bonus (via DeltaMaxHealth).
--   - 25% damage absorption for the duration.
--   - 5 HP/sec regen for the duration (drives the health-badge up-arrow).
--   - Duration: 60s.
--   - FX: ruinshat-style shield (forcefield prefab) recolored celestial blue,
--         respawned CONTINUOUSLY (every 2.5s). Initial spawn delayed ~0.6s.
--
-- SHADOW (wagstaff_shadow_possession tag):
--   - Spawns a SHADOW CLONE that fights for Wagstaff.
--   - Clone base: vanilla `shadowwaxwell_duelist` (Maxwell's shadow duelist NPC)
--     — has built-in combat AI, follower brain, proper NPC setup. Reliable spawn.
--     Fallback: `williambuster` (mod bot) if the duelist prefab is unavailable.
--   - Clone HP: 150 (Wagstaff's HP), NON-invincible (can take damage / die).
--   - Clone damage: 34 (voidcloth scythe ballpark).
--   - NO item equipping / OverrideSymbol (removed per user request — the equipping
--     was the suspected crash source; the clone keeps its native shadow appearance
--     with a dark tint).
--   - Duration: 120s.
--   - FX: statue_transition_2 spawn (same as Buster clone) + shadow_despawn despawn.
--
-- ALL debug output is routed through the mod's debug system (G.WagstaffDbg /
-- G.WagstaffDbgF), which is gated by the "Debug mode" config toggle. When debug
-- is OFF, these are zero-cost no-ops. No unconditional print() calls.
--
-- Affinity tag persistence: player tags added via AddTag are not reliably saved
-- across save/load. The skill tree's onactivate SHOULD re-fire on load, but as a
-- safety net we re-apply the possession tags on player spawn (deferred) by
-- reading the skilltreeupdater state.

local G = GLOBAL

local CELESTIAL_DURATION   = 60     -- seconds
local CELESTIAL_HP_BONUS   = 100    -- +max HP
local CELESTIAL_ABSORPTION = 0.25   -- 25% damage absorption
local CELESTIAL_REGEN_RATE = 5      -- HP per second (also drives the badge up-arrow)
local CELESTIAL_SHIELD_RESPAWN_INTERVAL = 2.5  -- seconds between shield FX respawns

local SHADOW_CLONE_DURATION = 120   -- seconds
local SHADOW_CLONE_HP       = 150
local SHADOW_CLONE_DAMAGE   = 34    -- voidcloth scythe ballpark

-- v2.0.21: ALL debugs go through the mod's debug system (toggle on/off in the
-- config menu "Debug mode"). No-op when WagstaffDbg is unavailable, so debug
-- output is NEVER unconditional.
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
    -- map-style: skilltree[skillname] == true
    if skilltree[skillname] ~= nil then return true end
    -- array-style: ipairs
    for _, s in ipairs(skilltree) do
        if s == skillname then return true end
    end
    -- generic fallback
    for k, _ in pairs(skilltree) do
        if k == skillname then return true end
    end
    return false
end

-- Re-apply the affinity possession tags on load if the skill is activated but the
-- tag is missing (tags don't persist across save/load reliably).
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

    -- 5 HP/sec regen — GUARANTEES the health-badge up-arrow is visible for the
    -- full duration. Thematically appropriate: celestial light actively healing.
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
        if player._wagstaff_celestial_shield_fx and player._wagstaff_celestial_shield_fx:IsValid() then
            player._wagstaff_celestial_shield_fx:Remove()
        end
        local fx = G.SpawnPrefab("forcefield")
        if fx then
            fx.entity:SetParent(player.entity)
            -- Recolor to celestial blue (4 args: r,g,b,a — alpha required).
            if fx.AnimState then
                fx.AnimState:SetMultColour(0.45, 0.6, 1.0, 1.0)
                fx.AnimState:SetAddColour(0.1, 0.2, 0.45, 0)
            end
            player._wagstaff_celestial_shield_fx = fx
            _dbgF("[AFFINITY] SpawnShield: forcefield spawned, parent=%s", tostring(player.prefab))
        else
            _dbg("[AFFINITY] SpawnShield: WARN — SpawnPrefab('forcefield') returned nil")
        end
    end

    -- Initial shield at 0.6s (sync with spawn anim), then continuous respawns.
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() then return end
        _dbg("[AFFINITY] Celestial: initial SpawnShield + starting periodic respawns")
        SpawnShield()
        player._wagstaff_celestial_shield_task =
            player:DoPeriodicTask(CELESTIAL_SHIELD_RESPAWN_INTERVAL, SpawnShield)
    end)

    -- Expire the buff after the duration.
    player._wagstaff_celestial_expire_task = player:DoTaskInTime(CELESTIAL_DURATION, function()
        if not player:IsValid() then return end
        _dbg("[AFFINITY] Celestial: buff expiring")
        if player._wagstaff_celestial_shield_task then
            player._wagstaff_celestial_shield_task:Cancel()
            player._wagstaff_celestial_shield_task = nil
        end
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
-- SHADOW CLONE
----------------------------------------------------------------

local function RemoveShadowClone(player)
    local clone = player._wagstaff_shadow_clone
    if clone and clone:IsValid() then
        local cx, cy, cz = clone.Transform:GetWorldPosition()
        local fx = G.SpawnPrefab("shadow_despawn")
        if fx then fx.Transform:SetPosition(cx, cy, cz) end
        clone:Remove()
        _dbg("[AFFINITY] SHADOW: clone removed (shadow_despawn FX)")
    end
    player._wagstaff_shadow_clone = nil
end

local function SpawnShadowClone(player)
    _dbg("[AFFINITY] SHADOW: SpawnShadowClone called")
    -- Remove any existing clone first (no stacking on repeated revives).
    if player._wagstaff_shadow_clone and player._wagstaff_shadow_clone:IsValid() then
        _dbg("[AFFINITY] SHADOW: removing existing clone first")
        RemoveShadowClone(player)
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    local angle = math.random() * 2 * G.PI
    local offset = 1.8
    local sx = px + math.cos(angle) * offset
    local sz = pz + math.sin(angle) * offset

    -- v2.0.21 FIX: `shadowwaxwell` (used in v2.0.20) is NOT a valid spawnable
    -- prefab in the user's DST build — server log showed:
    --   "Can't find prefab shadowwaxwell"
    --   "[AFFINITY REVIVE] SHADOW: ERROR — SpawnPrefab('shadowwaxwell') returned nil"
    -- Switched to `shadowwaxwell_duelist` (Maxwell's shadow duelist NPC — a real,
    -- registered prefab with built-in combat AI, follower brain, and proper NPC
    -- setup). Fallback to `williambuster` (mod's own bot, guaranteed valid) if the
    -- duelist prefab is also unavailable in the build.
    -- Per user request, the item-equipping (OverrideSymbol) has been REMOVED — the
    -- clone keeps its native shadow appearance with a dark tint.
    local clone = G.SpawnPrefab("shadowwaxwell_duelist")
    local base_used = "shadowwaxwell_duelist"
    if not clone then
        _dbg("[AFFINITY] SHADOW: shadowwaxwell_duelist unavailable, falling back to williambuster")
        clone = G.SpawnPrefab("williambuster")
        base_used = "williambuster"
    end
    if not clone then
        _dbg("[AFFINITY] SHADOW: ERROR — both shadowwaxwell_duelist and williambuster returned nil; cannot spawn clone")
        return
    end
    _dbgF("[AFFINITY] SHADOW: clone spawned successfully (base=%s)", base_used)
    clone.Transform:SetPosition(sx, 0, sz)

    -- Tag as a shadow clone (for identification / retarget exclusion).
    clone:AddTag("shadow_wagstaff_clone")
    clone:AddTag("shadowcreature")
    clone:AddTag("NOCLICK")
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
        _dbg("[AFFINITY] SHADOW: WARN — clone has no health component")
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
        _dbg("[AFFINITY] SHADOW: WARN — clone has no combat component")
    end

    -- Follow the player. shadowwaxwell_duelist has a follower component + brain
    -- (shadowwaxwell_brain) that handles following + fighting automatically.
    -- williambuster (fallback) also has follower + brain. No manual driver needed.
    if clone.components.follower then
        clone.components.follower:SetLeader(player)
    else
        _dbg("[AFFINITY] SHADOW: WARN — clone has no follower component")
    end

    -- Dark tint for the shadow appearance (NOT item equipping — just a colour
    -- multiply on the native build). Re-applied periodically like the Buster clone
    -- so it survives anim-state resets.
    if clone.AnimState then
        clone.AnimState:SetMultColour(0.5, 0.5, 0.5, 1.0)
        clone.AnimState:SetAddColour(0, 0, 0, 0)
    end
    clone:DoPeriodicTask(0.1, function()
        if clone:IsValid() and clone.AnimState then
            clone.AnimState:SetMultColour(0.5, 0.5, 0.5, 1.0)
            clone.AnimState:SetAddColour(0, 0, 0, 0)
        end
    end)

    -- Spawn FX: same as the Buster clone (statue_transition_2), synced with the
    -- clone's spawn animation.
    local spawn_fx = G.SpawnPrefab("statue_transition_2")
    if spawn_fx then
        spawn_fx.Transform:SetPosition(sx, 0, sz)
    end
    if clone.SoundEmitter then
        clone.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
    end
    _dbg("[AFFINITY] SHADOW: spawn FX (statue_transition_2) + sound played")

    -- Periodic validity check: if the player is gone, despawn the clone.
    clone:DoPeriodicTask(0.5, function()
        if not player:IsValid() or not clone:IsValid() then
            if clone:IsValid() then
                RemoveShadowClone(player)
            end
            return
        end
        -- Suggest the player's combat target to the clone (helps engagement).
        if player.components.combat and player.components.combat.target then
            local t = player.components.combat.target
            if t:IsValid() and not t:IsInLimbo() and clone.components.combat then
                clone.components.combat:SuggestTarget(t)
            end
        end
    end)

    -- Despawn after duration.
    clone:DoTaskInTime(SHADOW_CLONE_DURATION, function()
        if clone and clone:IsValid() then
            _dbgF("[AFFINITY] SHADOW: clone duration (%ss) expired, removing", tostring(SHADOW_CLONE_DURATION))
            RemoveShadowClone(player)
        end
    end)

    player._wagstaff_shadow_clone = clone
    _dbgF("[AFFINITY] SHADOW: clone ready (base=%s) HP=%s dmg=%s duration=%ss",
        base_used, tostring(SHADOW_CLONE_HP), tostring(SHADOW_CLONE_DAMAGE), tostring(SHADOW_CLONE_DURATION))
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
        -- Re-check tags after delay (tags should persist but be safe).
        local cel = player:HasTag("wagstaff_celestial_possession")
        local shd = player:HasTag("wagstaff_shadow_possession")
        _dbgF("[AFFINITY] ApplyOnRevive (after 0.1s): celestial=%s shadow=%s", tostring(cel), tostring(shd))
        if cel then
            _dbg("[AFFINITY] ApplyOnRevive: -> ApplyCelestialBuff")
            ApplyCelestialBuff(player)
        elseif shd then
            _dbg("[AFFINITY] ApplyOnRevive: -> SpawnShadowClone")
            SpawnShadowClone(player)
        else
            _dbg("[AFFINITY] ApplyOnRevive: no affinity tag — no ability applied")
        end
    end)
end

-- Hook: listen for the player's revive event. This fires for ANY revive source
-- (butler haunt, meat effigy, touch stone, amulet). The skill tree's exclusion
-- locks guarantee a Wagstaff has at most one of the two affinity tags.
_dbg("[AFFINITY] Module loaded — registering AddPrefabPostInit('wagstaff') revive listener")
AddPrefabPostInit("wagstaff", function(inst)
    if not G.TheWorld or not G.TheWorld.ismastersim then return end
    inst:ListenForEvent("respawnfromghost", function(inst, data)
        _dbgF("[AFFINITY] respawnfromghost EVENT FIRED on %s, source=%s",
            tostring(inst.prefab), tostring(data and data.source and data.source.prefab or "nil"))
        ApplyOnRevive(inst)
    end)
    _dbg("[AFFINITY] AddPrefabPostInit('wagstaff'): revive listener registered")

    -- v2.0.21: Affinity tag persistence safety net. Player tags added via AddTag
    -- are not reliably saved across save/load. The skill tree's onactivate SHOULD
    -- re-fire on load and re-add the tag, but as a safety net we re-apply the
    -- possession tags shortly after spawn by reading the skilltreeupdater state.
    -- (Mirrors the boss-kill tag re-application in modmain.lua AddPlayerPostInit.)
    inst:DoTaskInTime(2, function()
        if not inst:IsValid() then return end
        ReapplyAffinityTags(inst)
    end)
    -- Also re-check a bit later (skill tree activation on load can be delayed).
    inst:DoTaskInTime(5, function()
        if not inst:IsValid() then return end
        ReapplyAffinityTags(inst)
    end)
end)
