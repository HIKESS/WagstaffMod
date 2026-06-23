-- scripts/wagstaff_affinity_revive.lua
-- v2.0.19: Decoupled affinity revive abilities.
--
-- The butler haunt-resurrection is now a PLAIN revive (bot dies, player revives).
-- These NEW affinity abilities trigger on the player's "respawnfromghost" event,
-- regardless of revive source (butler haunt, meat effigy, touch stone, amulet).
--
-- CELESTIAL (wagstaff_celestial_possession tag):
--   - Revive with FULL HP / sanity / hunger.
--   - +100 max-HP bonus (via DeltaMaxHealth -> health badge up-arrow indicator).
--   - 25% damage absorption for the duration.
--   - Duration: 60s (a "revive protection window").
--   - FX: ruinshat-style shield (forcefield prefab) recolored celestial blue,
--         respawned CONTINUOUSLY (every 2.5s) so the shield persists the full
--         duration. Initial spawn delayed ~0.6s to sync with the ghost->body
--         materialization (NOT on the ghost).
--
-- SHADOW (wagstaff_shadow_possession tag):
--   - Spawns a SHADOW CLONE that fights for Wagstaff.
--   - Clone is a recolored Wagstaff body (spawned from the "wagstaff" prefab,
--     stripped of player-ness), tinted fully shadow-black.
--   - Clone HP: 150 (Wagstaff's HP), NON-invincible (can take damage / die).
--   - Clone is equipped with armor_voidcloth + voidcloth_scythe, also tinted
--     fully shadow-black (matching the Buster clone's black tint).
--   - Duration: 120s (a combat-assist window after revive).
--   - FX: statue_transition_2 (same as the Buster clone spawn), synced with
--         the clone's spawn animation.
--   - Despawn FX: shadow_despawn when the clone expires or dies.
--
-- Balance notes (chosen values, easy to tune):
--   * Celestial +100 HP / 25% absorb / 60s: a strong but short revive-protection
--     window. Revive is rare (you died), so a generous buff is fair; 60s is long
--     enough to escape/recover but not a permanent state.
--   * Shadow clone 150 HP / 120s: matches Wagstaff's own HP, lasts long enough
--     to meaningfully assist in a fight, but is killable so it isn't a permanent
--     meat-shield.

local G = GLOBAL

local CELESTIAL_DURATION   = 60     -- seconds
local CELESTIAL_HP_BONUS   = 100    -- +max HP
local CELESTIAL_ABSORPTION = 0.25   -- 25% damage absorption
local CELESTIAL_SHIELD_RESPAWN_INTERVAL = 2.5  -- seconds between shield FX respawns

local SHADOW_CLONE_DURATION = 120   -- seconds
local SHADOW_CLONE_HP       = 150
local SHADOW_CLONE_DAMAGE   = 34    -- voidcloth scythe ballpark

local _dbg  = G.WagstaffDbg  or function(...) end
local _dbgF = G.WagstaffDbgF or function(...) end

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

    -- +100 max HP via DeltaMaxHealth (the canonical DST API for max-HP changes,
    -- same one Wolfgang/WX-78 use). This triggers the health badge's built-in
    -- up-arrow indicator (golden frame / boosted-max marker) so the player sees
    -- the buff is active -- "a seta up no canto onde marca o HP". After
    -- DeltaMaxHealth, current HP scales proportionally; SetPercent(1) then
    -- fills it to the new (boosted) max = full HP.
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
    -- respawned CONTINUOUSLY so the shield visual persists the full 60s
    -- duration (forcefield self-removes after ~2-3s, so we refresh it).
    -- Initial spawn delayed ~0.6s to sync with the ghost->body materialization
    -- (NOT on the ghost), per user request.
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
            if fx.AnimState then
                fx.AnimState:SetMultColour(0.45, 0.6, 1.0)
                fx.AnimState:SetAddColour(0.1, 0.2, 0.45)
            end
            player._wagstaff_celestial_shield_fx = fx
        end
    end

    -- Initial shield at 0.6s (sync with spawn anim), then continuous respawns.
    player:DoTaskInTime(0.6, function()
        if not player:IsValid() then return end
        SpawnShield()
        player._wagstaff_celestial_shield_task =
            player:DoPeriodicTask(CELESTIAL_SHIELD_RESPAWN_INTERVAL, SpawnShield)
    end)

    -- Expire the buff after the duration.
    player._wagstaff_celestial_expire_task = player:DoTaskInTime(CELESTIAL_DURATION, function()
        if not player:IsValid() then return end
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
        -- Remove the +100 max HP. DeltaMaxHealth scales current proportionally
        -- and clears the badge up-arrow. Fallback: SetMaxHealth + clamp.
        if health and health:IsAlive() then
            if health.DeltaMaxHealth then
                health:DeltaMaxHealth(-CELESTIAL_HP_BONUS)
            else
                health:SetMaxHealth(math.max(1, health.maxhealth - CELESTIAL_HP_BONUS))
            end
        end
        -- Restore absorption.
        if health then
            health:SetAbsorptionAmount(player._wagstaff_celestial_old_absorb or 0)
        end
        player._wagstaff_celestial_expire_task = nil
        _dbgF("[AFFINITY REVIVE] CELESTIAL: buff expired after %ss", tostring(CELESTIAL_DURATION))
    end)

    _dbgF("[AFFINITY REVIVE] CELESTIAL: full stats + %s HP (DeltaMaxHealth) + %s%% absorb for %ss, shield continuous FX every %ss",
        tostring(CELESTIAL_HP_BONUS), tostring(CELESTIAL_ABSORPTION * 100),
        tostring(CELESTIAL_DURATION), tostring(CELESTIAL_SHIELD_RESPAWN_INTERVAL))
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
    end
    player._wagstaff_shadow_clone = nil
end

local function SpawnShadowClone(player)
    -- Remove any existing clone first (no stacking on repeated revives).
    if player._wagstaff_shadow_clone and player._wagstaff_shadow_clone:IsValid() then
        RemoveShadowClone(player)
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    local angle = math.random() * 2 * G.PI
    local offset = 1.8
    local sx = px + math.cos(angle) * offset
    local sz = pz + math.sin(angle) * offset

    -- Use the wagstaff prefab as the base so the clone looks like Wagstaff,
    -- then strip its player-ness and turn it into a shadow NPC fighter.
    local clone = G.SpawnPrefab("wagstaff")
    if not clone then
        _dbg("[AFFINITY REVIVE] SHADOW: failed to spawn wagstaff clone")
        return
    end
    clone.Transform:SetPosition(sx, 0, sz)

    -- Strip player-ness so it behaves as an NPC, not a second player.
    clone:RemoveTag("player")
    clone:RemoveTag("playerghost")
    -- Strip Wagstaff character-identity tags added by common_postinit so the
    -- clone doesn't trigger Wagstaff-specific mechanics (projection, nearsight,
    -- soulless, etc.). It is a shadow duplicate, not a second Wagstaff.
    clone:RemoveTag("outofworldprojected")
    clone:RemoveTag("nearsighted")
    clone:RemoveTag("soulless")
    clone:RemoveTag("weakstomach")
    clone:RemoveTag("tinkerer")
    -- Tag as a shadow clone.
    clone:AddTag("shadow_wagstaff_clone")
    clone:AddTag("shadowcreature")
    clone:AddTag("NOCLICK")
    -- Don't persist (always recreated on next revive).
    clone.persists = false

    -- Rename (avoid hover showing a player name).
    if clone.components.named then
        clone.components.named:SetName("Shadow Wagstaff")
    end
    clone.name = "Shadow Wagstaff"

    -- Tint fully shadow-black (same approach as the Buster shadow clone).
    local function ApplyBlackTint()
        if clone:IsValid() and clone.AnimState then
            clone.AnimState:SetMultColour(0.01, 0.01, 0.01, 0.55)
            clone.AnimState:SetAddColour(0, 0, 0, 0)
        end
    end
    ApplyBlackTint()
    -- Re-apply periodically (some anim events reset the tint).
    clone:DoPeriodicTask(0.1, ApplyBlackTint)

    -- HP 150, NON-invincible (can take damage / die).
    if clone.components.health then
        clone.components.health:SetMaxHealth(SHADOW_CLONE_HP)
        clone.components.health:SetCurrentHealth(SHADOW_CLONE_HP)
        clone.components.health:SetInvincible(false)
        clone.components.health:SetAbsorptionAmount(0)
    end

    -- Combat: shadow-scythe damage + retarget (player's target / nearby hostiles).
    if clone.components.combat then
        clone.components.combat:SetDefaultDamage(SHADOW_CLONE_DAMAGE)
        clone.components.combat:SetAttackPeriod(2)
        clone.components.combat:SetRange(3)
        clone.components.combat:SetRetargetFunction(2, function(inst)
            -- Prefer the player's current target.
            if player and player:IsValid() and player.components.combat then
                local pt = player.components.combat.target
                if pt and pt:IsValid() and not pt:IsInLimbo() and inst.components.combat:CanTarget(pt) then
                    return pt
                end
            end
            -- Otherwise find nearby hostiles.
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
    end

    -- Follow the player (follower component drives following; the periodic
    -- driver below also handles movement so the clone stays close).
    if not clone.components.follower then
        clone:AddComponent("follower")
    end
    clone.components.follower:SetLeader(player)

    -- Locomotor: use the shadow duplicate's run speed so it keeps up.
    if clone.components.locomotor then
        clone.components.locomotor.runspeed = G.TUNING.SHADOWWAXWELL_SPEED or 8
    end

    -- Equip voidcloth armor + scythe (wagstaff has an inventory component).
    if clone.components.inventory then
        local armor = G.SpawnPrefab("armor_voidcloth")
        if armor then
            if armor.AnimState then
                armor.AnimState:SetMultColour(0.01, 0.01, 0.01, 0.55)
            end
            clone.components.inventory:Equip(armor)
        end
        local scythe = G.SpawnPrefab("voidcloth_scythe")
        if scythe then
            if scythe.AnimState then
                scythe.AnimState:SetMultColour(0.01, 0.01, 0.01, 0.55)
            end
            clone.components.inventory:Equip(scythe)
        end
    end

    -- Spawn FX: same as the Buster clone (statue_transition_2), synced with the
    -- clone's spawn animation (the clone's anim starts immediately at spawn).
    local spawn_fx = G.SpawnPrefab("statue_transition_2")
    if spawn_fx then
        spawn_fx.Transform:SetPosition(sx, 0, sz)
    end
    if clone.SoundEmitter then
        clone.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
    end

    -- Movement / attack driver. The wagstaff prefab has no brain by default
    -- (characters are player-driven), so we drive the clone directly via its
    -- locomotor + combat components. This pushes the same "locomote" / "doattack"
    -- events that SGwilson already handles.
    clone:DoPeriodicTask(0.3, function()
        if not clone:IsValid() or not player:IsValid() then return end
        local combat = clone.components.combat
        local locomotor = clone.components.locomotor
        if not combat or not locomotor then return end

        local target = combat.target
        if target and (not target:IsValid() or target:IsInLimbo()) then
            target = nil
        end
        if not target then
            -- retarget fn runs on its own schedule, but read the current result
            target = combat.target
        end

        if target then
            local distsq = clone:GetDistanceSqToInst(target)
            local range = (combat.attackrange or 3)
            if distsq <= range * range then
                -- In range: stop and attack.
                locomotor:Stop()
                combat:TryAttack(target)
            else
                -- Chase the target.
                local tx, ty, tz = target.Transform:GetWorldPosition()
                locomotor:GoToPoint(G.Vector3(tx, ty, tz), true)
            end
        else
            -- No target: follow the player.
            local pdistsq = clone:GetDistanceSqToInst(player)
            if pdistsq > 4 * 4 then
                local ppx, ppy, ppz = player.Transform:GetWorldPosition()
                locomotor:GoToPoint(G.Vector3(ppx, ppy, ppz), true)
            else
                locomotor:Stop()
            end
        end
    end)

    -- Despawn after duration (or when the player dies again).
    clone:DoTaskInTime(SHADOW_CLONE_DURATION, function()
        if clone and clone:IsValid() then
            RemoveShadowClone(player)
        end
    end)

    player._wagstaff_shadow_clone = clone
    _dbgF("[AFFINITY REVIVE] SHADOW: clone spawned, HP=%s duration=%ss",
        tostring(SHADOW_CLONE_HP), tostring(SHADOW_CLONE_DURATION))
end

----------------------------------------------------------------
-- ENTRY POINT
----------------------------------------------------------------

local function ApplyOnRevive(player)
    if not player or not player:IsValid() then return end

    local celestial = player:HasTag("wagstaff_celestial_possession")
    local shadow    = player:HasTag("wagstaff_shadow_possession")

    _dbgF("[AFFINITY REVIVE] respawnfromghost: celestial=%s shadow=%s",
        tostring(celestial), tostring(shadow))

    -- Slight delay so the revive (health restore, ghost->body transition) has
    -- started and the player's tags/components have settled.
    player:DoTaskInTime(0.1, function()
        if not player:IsValid() then return end
        if celestial then
            ApplyCelestialBuff(player)
        elseif shadow then
            SpawnShadowClone(player)
        end
    end)
end

-- Hook: listen for the player's revive event. This fires for ANY revive source
-- (butler haunt, meat effigy, touch stone, amulet). The skill tree's exclusion
-- locks guarantee a Wagstaff has at most one of the two affinity tags.
AddPrefabPostInit("wagstaff", function(inst)
    if not G.TheWorld or not G.TheWorld.ismastersim then return end
    inst:ListenForEvent("respawnfromghost", function()
        ApplyOnRevive(inst)
    end)
end)
