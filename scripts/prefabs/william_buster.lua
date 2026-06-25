local prefabs =
{

}

    local assets =
    {
        Asset("ANIM", "anim/william_buster.zip"),
        Asset("ANIM", "anim/william_buster_empty.zip"),
        Asset("SOUND", "sound/maxwell.fsb"),
    }

-- v2.0.17: debug helpers gated by the "Debug mode" mod config button.
local _dbg  = _G.WagstaffDbg  or function(...) end
local _dbgF = _G.WagstaffDbgF or function(...) end

-- v2.0.35: Design correto = williamgadget (100% via lootsetfn) + 50% de UM item
-- so (o material principal do recipe). Antes v2.0.34 tinha 50% por material (2
-- itens), mas o design original era 50% para 1 item so.
-- Buster recipe: williamgadget + marble(3) + transistor(2) -> material principal = marble
SetSharedLootTable("buster",
{
    {'marble',            0.50},
})

SetSharedLootTable("bustergadget",
{
    {'williamgadget',          1},
})

local function lootsetfn(lootdropper)
    -- v2.0.34: williamgadget (core) sempre dropa. gears adicionais por level
    -- (recompensa de level up, nao e bonus aleatorio).
    local loot = {"williamgadget"}
    local amount = lootdropper.inst.level*0.75
        if amount < 1 then amount = 1 end

                if lootdropper.inst.level > 0 then
                for k = 1, amount do
            table.insert(loot, "gears")
                end
                end


    lootdropper:SetLoot(loot)
end

local brain = require "brains/williambusterbrain"
local AffinityPulse = _G.AffinityPulse

-- Helper function to check if bot's owner has affinity skills
local function GetOwner(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end

local function OwnerHasCelestial(inst)
    local owner = GetOwner(inst)
    return owner and owner:HasTag("wagstaff_celestial_possession")
end

local function OwnerHasShadow(inst)
    local owner = GetOwner(inst)
    return owner and owner:HasTag("wagstaff_shadow_possession")
end

-- SHADOW POSSESSION: Shadow Clone for Buster Bot Mk.III
-- Cria um segundo Buster totalmente negro com 50% do dano
-- Desaparece quando acaba o período de dusk (shadow)
local function SpawnShadowClone(parent_buster)
    if not parent_buster or not parent_buster:IsValid() then return nil end
    
    local x, y, z = parent_buster.Transform:GetWorldPosition()
    
    -- Spawn a shadow version using the SAME prefab type as parent (MK1, MK2 or MK3)
    local parent_prefab = parent_buster.prefab
    local clone_prefab = (parent_prefab == "williambuster3") and "williambuster3" or ((parent_prefab == "williambuster2") and "williambuster2" or "williambuster")
    local clone = SpawnPrefab(clone_prefab)
    if not clone then return nil end
    
    -- Position near the buster
    local offset = 1.5
    local angle = math.random() * 2 * math.pi
    clone.Transform:SetPosition(x + math.cos(angle) * offset, 0, z + math.sin(angle) * offset)
    
    -- Make it look like a SHADOW version - TOTALLY BLACK (no color)
    -- Apply immediately to prevent any visible color flash
    local function ApplyCloneTint(c)
        if c:IsValid() and c.AnimState then
            c.AnimState:SetMultColour(0.01, 0.01, 0.01, 0.55)
            c.AnimState:SetAddColour(0, 0, 0, 0)
        end
    end
    ApplyCloneTint(clone)
    
    -- Keep enforcing black + semi-transparent color constantly to prevent any reset.
    -- v2.0.57 FIX: clone was losing its dark tint when the player walked away.
    -- Root cause: DoPeriodicTask is PAUSED while the entity is asleep (DST
    -- dormancy — entities far from any player enter sleepstate and their
    -- periodic tasks stop ticking). During dormancy the SG 'spawn'/'revived'
    -- states (and some engine colour resets) could wipe the tint, and the
    -- paused re-tint task couldn't correct it. Now we ALSO listen for
    -- 'entitywake' (fires when the entity wakes back up as the player
    -- approaches) and re-apply the tint immediately — closing the window
    -- where the clone renders at full colour while far from the player.
    clone:DoPeriodicTask(0.05, function() ApplyCloneTint(clone) end)
    clone:ListenForEvent("entitywake", function(c) ApplyCloneTint(c) end)
    -- Also re-apply on 'onremove'/'onpreload' is unnecessary — the clone is
    -- transient (persists = false). But guard the SG 'spawn'/'revived' states
    -- as well (already guarded in SGwilliambuster via shadow_buster_clone tag).
    
    -- Set up combat stats.
    -- v2.0.39: clone damage 50% -> 35% of parent.
    -- v2.0.57: clone damage 35% -> 40% of parent per user request (35% felt
    -- too weak after the v2.0.50 revert stopped the clone hunting shadow
    -- creatures — the clone now only mirrors the parent's target, so a bit
    -- more damage keeps it a meaningful support fighter).
    if clone.components.combat then
        local parent_damage = parent_buster.components.combat and parent_buster.components.combat.defaultdamage or TUNING.WILLIAM_BUSTER_DAMAGE
        clone.components.combat:SetDefaultDamage(parent_damage * 0.40)
    end

    -- v2.0.39: clone HP is now FINITE (50% of parent max HP) instead of
    -- invincible. An immortal clone that also hunts shadows (v2.0.38) had no
    -- trade-off. Now the clone can die if focused by enemies — the player must
    -- position the parent well to keep the clone alive. Still absorbs damage
    -- (50% absorption) so it's tanky but not unkillable.
    if clone.components.health then
        local parent_maxhp = parent_buster.components.health and parent_buster.components.health.maxhealth or TUNING.WILLIAM_BUSTER_HEALTH
        clone.components.health:SetMaxHealth(parent_maxhp * 0.5)
        clone.components.health:SetAbsorptionAmount(0.5)
        -- Keep health regen so the clone recovers between fights (parent has regen too).
        if clone.components.health.StartRegen then
            clone.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN or 5, TUNING.WILLIAM_ROBOT_REGENPERIOD or 5)
        end
    end
    
    -- Don't consume fuel (it's a shadow manifestation)
    if clone.components.fueled then
        clone.components.fueled:StopConsuming()
    end
    
    -- Tag as shadow clone.
    -- v2.0.50: RE-ADDED "shadowcreature" tag. The clone IS a shadow, so
    -- shadow creatures (Terrorbeak, Crawling Horror, Night Hands) are its
    -- kin — they should NOT attack each other. This restores the
    -- shadow-vs-shadow immunity: hostile shadow monsters treat the clone
    -- as friendly and the clone does not hunt them. The clone now fights
    -- ONLY the parent's target (normal combat), consistent with the
    -- faction logic applied to the Brute taunt in v2.0.48 (each faction
    -- doesn't fight its own kin). The v2.0.38 "hunts shadow creatures"
    -- behavior is reverted as thematically wrong.
    clone:AddTag("shadow_buster_clone")
    clone:AddTag("shadowcreature")    -- v2.0.50: shadow-vs-shadow immunity
    clone:AddTag("shadow_aligned")    -- v2.0.50: explicit rift faction tag
    clone:AddTag("NOCLICK") -- Can't be clicked/interacted with
    
    -- CRITICAL: Do not save this clone - it should always be recreated on load
    clone.persists = false
    
    -- Set up follower to follow parent Buster (needed for brain retarget)
    if clone.components.follower and parent_buster:IsValid() then
        clone.components.follower:SetLeader(parent_buster)
    end
    
    -- Configure combat retarget: attack ONLY the parent's current target.
    -- v2.0.50: REVERTED the v2.0.38 "hunts shadow creatures" behavior. The
    -- clone is a shadow (shadowcreature + shadow_aligned tags), so it should
    -- NOT hunt its own kin (Terrorbeak, Crawling Horror). It now mirrors the
    -- parent's target only — a normal shadow-THEMED combat bot, not an
    -- anti-shadow fighter. Consistent with the Brute taunt faction logic.
    if clone.components.combat then
        clone.components.combat:SetRetargetFunction(1, function(inst)
            if not parent_buster:IsValid() then return nil end

            -- Only target: parent's current target.
            -- v2.0.41 FIX: guard with components.health check — IsDead() is a
            -- health COMPONENT method, not an entity method.
            if parent_buster.components.combat then
                local parent_target = parent_buster.components.combat.target
                if parent_target and parent_target:IsValid() and not parent_target:IsInLimbo()
                    and parent_target.components.health ~= nil
                    and not parent_target.components.health:IsDead() then
                    -- v2.0.50: don't target shadow creatures (our kin).
                    if not parent_target:HasTag("shadow") and not parent_target:HasTag("shadow_aligned") then
                        return parent_target
                    end
                end
            end

            return nil
        end)

        clone.components.combat.canretarget = true
        clone.components.combat:SetKeepTargetFunction(function(inst, target)
            if not target or not target:IsValid() then return false end
            if target:IsInLimbo() then return false end
            if target.components.health == nil or target.components.health:IsDead() then return false end
            -- v2.0.50: drop target if it's a shadow creature (our kin).
            if target:HasTag("shadow") or target:HasTag("shadow_aligned") then return false end
            -- Stay on target while parent is alive
            if not parent_buster:IsValid() then return false end
            return true
        end)
    end
    
    -- Remove name to avoid confusion
    if clone.components.named then
        clone.components.named:SetName("Shadow Buster")
    end
    
    -- Monitor dusk state, parent health, and CLONE health.
    -- v2.0.39: clone now has finite HP — also despawn when the clone itself dies
    -- (instead of leaving a corpse that lingers until dusk ends).
    clone:DoPeriodicTask(0.5, function()
        if not parent_buster:IsValid() or not clone:IsValid() then
            if clone:IsValid() then clone:Remove() end
            return
        end

        -- v2.0.39: if the clone's HP ran out, despawn it with the shadow FX
        -- (don't leave a dead clone body hanging around).
        if clone.components.health and clone.components.health:IsDead() then
            local remove_fx = SpawnPrefab("shadow_despawn")
            if remove_fx then
                local cx, cy, cz = clone.Transform:GetWorldPosition()
                remove_fx.Transform:SetPosition(cx, cy, cz)
                if remove_fx.SoundEmitter then
                    remove_fx.SoundEmitter:KillAllSounds()
                end
            end
            clone:Remove()
            return
        end

        -- v2.0.58: Despawn when the parent's shadow pulse fades too — not only
        -- when dusk ends. The pulse (parent_buster._aff_active) turns off when
        -- the owner leaves combat or walks out of range, so the clone fades with
        -- it, keeping pulse + clone in sync. (At dusk, _aff_active implies the
        -- shadow path is active, so this check is safe.)
        local parent_dead = not parent_buster.components.health or parent_buster.components.health:IsDead()
        local pulse_faded = not TheWorld.state.isdusk or parent_buster._aff_active ~= true
        if parent_dead or pulse_faded then
            -- FX: shadow despawn (NO SOUND)
            local remove_fx = SpawnPrefab("shadow_despawn")
            if remove_fx then
                local cx, cy, cz = clone.Transform:GetWorldPosition()
                remove_fx.Transform:SetPosition(cx, cy, cz)
                -- Kill all sounds on this FX
                if remove_fx.SoundEmitter then
                    remove_fx.SoundEmitter:KillAllSounds()
                end
            end
            clone:Remove()
            return
        end
        
        -- Periodically suggest parent's target to the clone
        if parent_buster.components.combat and parent_buster.components.combat.target then
            local target = parent_buster.components.combat.target
            if clone.components.combat and target:IsValid() and not target:IsInLimbo() then
                clone.components.combat:SuggestTarget(target)
            end
        end
    end)
    
    -- Visual effect on spawn (shadow materialization FX - shadows coming together)
    local fx = SpawnPrefab("statue_transition_2")
    if fx then
        fx.Transform:SetPosition(clone.Transform:GetWorldPosition())
    end
    
    -- Spawn sound
    if clone.SoundEmitter then
        clone.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
    end
    
    return clone
end

local function LevelUp(inst, amount)
        if inst.level < 3 and amount ~= nil then
        inst.level = inst.level + amount
        if inst.sg ~= nil then
        inst.sg:GoToState("upgraded")
        end
end
        if inst.level > 3 then inst.level = 3 end

        inst:DoTaskInTime(0, function()
                inst:AddTag("level"..inst.level)

        inst.components.health:SetAbsorptionAmount(0+inst.level*0.05)
        if inst.components.combat ~= nil then
            -- v2.0.15 FIX: preserve tier bonus (MK2 +5, MK3 +10) instead of overriding it
            local tier_bonus = 0
            if inst.prefab == "williambuster2" then tier_bonus = 5
            elseif inst.prefab == "williambuster3" then tier_bonus = 10 end
            inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BUSTER_DAMAGE + tier_bonus + (inst.level*3))
        end
        end)
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        if data.attacker.components.petleash ~= nil and
            data.attacker.components.petleash:IsPet(inst) then
        elseif data.attacker.components.combat ~= nil then
            inst.components.combat:SuggestTarget(data.attacker)
        end
    end
end

local function OnFuelEmpty(inst)
    if inst.sg ~= nil then
        inst.sg:GoToState("powerdown")
    end
end

local VALID_BUSTER_FUELS = {
    gears = true,
    trinket_6 = true, -- frazzled wires
    transistor = true,
}

local function OnAddFuel(inst, fuelvalue, fuelitem)
    -- v2.0.70 FIX: DST's `fueled` component calls ontakefuelfn as
    -- (inst, fuelvalue, ...) — NOT (inst, doer, fuelitem). Previous code
    -- treated the fuelvalue number as `doer`, crashing with "attempt to
    -- index local 'doer' (a number value)" when fuel was already full.
    -- v2.0.63: reject fuel when already full (vanilla-style feedback).
    if inst.components.fueled and inst.components.fueled:IsFull() then
        local player = FindClosestPlayerToInst(inst, 10, true)
        if player and player.components.talker then
            player.components.talker:Say("It's already full!")
        end
        return false
    end
    -- Only accept generator fuel (gears, etc.), reject common fuel like wood.
    -- NOTE: in this DST version, fuelitem is nil from ontakefuelfn (DST passes
    -- only fuelvalue as the 2nd arg), so this validation is currently a no-op.
    -- Fuel-type filtering should be done via the fueled component's
    -- SetFuelAcceptingTest or similar, not here. Left in place for safety.
    if fuelitem and fuelitem.prefab then
        if not VALID_BUSTER_FUELS[fuelitem.prefab] then
            -- Not a valid fuel for Buster Bot
            local player = FindClosestPlayerToInst(inst, 10, true)
            if player and player.components.talker then
                player.components.talker:Say("This won't work as fuel.")
            end
            return false  -- Reject the fuel
        end
    end
    
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel")
        if inst.sg ~= nil then
    inst.sg:GoToState("fed")
        end
    inst:AddTag("alive")
    return true  -- Accept the fuel
end

local function fuelupdate(inst)
        if inst.components.fueled ~= nil
            and inst.components.fueled.currentfuel <= inst.components.fueled.maxfuel*0.1  then
    inst.AnimState:AddOverrideBuild("william_buster_empty")
                --inst.AnimState:SetBuild("william_buster_empty")
                else
    inst.AnimState:ClearOverrideBuild("william_buster_empty")
        end
    end

local function retargetfn(inst)
    --Find things attacking leader
    local leader = inst.components.follower:GetLeader()
    return leader ~= nil
        and FindEntity(
            leader,
            TUNING.SHADOWWAXWELL_TARGET_DIST,
            function(guy)
                return guy ~= inst
                    and (guy.components.combat:TargetIs(leader) or
                        guy.components.combat:TargetIs(inst))
                    and inst.components.combat:CanTarget(guy)
            end,
            { "_combat" }, -- see entityreplica.lua
            { "playerghost", "INLIMBO" }
        )
        or nil
end

local function keeptargetfn(inst, target)
    --Is your leader nearby and your target not dead? Stay on it.
    --Match KEEP_WORKING_DIST in brain
    return inst.components.follower:IsNearLeader(14)
        and inst.components.combat:CanTarget(target)
                and target.components.minigame_participator == nil
end

local function getstatus(inst, viewer)
            return inst.components.fueled:IsEmpty() and "EMPTY"
            or inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .3 and "CRITICALFUEL"
            or inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .6 and "LOWFUEL"
            or "FINE"
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function nodebrisdmg(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return (afflicter ~= nil and afflicter:HasTag("quakedebris")) or (afflicter ~= nil and afflicter:HasTag("epic") and afflicter.components.combat.target ~= inst)
end


local function MakeAlive(inst, doer)
    -- BUG FIX: Check if doer has petleash (fixes bug after c_skip)
    if not doer or not doer.components.petleash then
        return
    end

    local pt = inst:GetPosition()
    -- BUG FIX 3: Use inst.prefab to determine correct bot level
    local prefab = inst.prefab or "williambuster_empty"
    
    -- Determine spawn prefab based on saved state
    local spawn_prefab = "williambuster"
    if prefab == "williambuster_empty" then
        -- Check saved flags to spawn correct level
        if inst.was_mk3 then
            spawn_prefab = "williambuster3"
        elseif inst.was_mk2 or (inst.saved_upgradelevel ~= nil and inst.saved_upgradelevel >= 70) then
            spawn_prefab = "williambuster2"
        end
    end
    
    local respawned = doer.components.petleash:SpawnPetAt(pt.x, 0, pt.z, spawn_prefab)
    if respawned ~= nil then
        respawned.components.fueled.currentfuel = inst.components.fueled.currentfuel
        respawned.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        respawned.Transform:SetRotation(inst.Transform:GetRotation())
        respawned.sg:GoToState("revived")
        respawned.level = inst.level or 0
        respawned.upgradelevel = inst.saved_upgradelevel or inst.upgradelevel or 0
        if inst.saved_upgradelevel_mk3 then
            respawned.upgradelevel_mk3 = inst.saved_upgradelevel_mk3
        end
        
        -- BUG FIX 9: Save owner GUID for tracking
        respawned.owner_guid = doer.GUID
        respawned.owner_name = doer.name
        
        respawned:PushEvent("levelup")
        inst:Remove()
    end
end

local function onworked(inst)
        if inst.sg ~= nil then
        inst.sg:GoToState("hit")
        end
end

local function OnHammered(inst, worker)
    -- v2.0.34: lootsetfn garante williamgadget (100%) + gears por level.
    -- Chance table "buster" da 50% marble + 50% transistor (bonus alinhado ao recipe).
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function onsave(inst, data)
        if inst.level ~= nil then
    data.level = inst.level
        end
    data.upgradelevel = inst.upgradelevel or 0
    data.saved_upgradelevel = inst.saved_upgradelevel or 0
    data.saved_upgradelevel_mk3 = inst.saved_upgradelevel_mk3 or 0
    data.was_mk2 = inst.was_mk2
    data.was_mk3 = inst.was_mk3
    -- BUG FIX 3: Save exact prefab name
    data.saved_prefab_name = inst.prefab
    -- Save leader GUID for persistence
    if inst.components.follower and inst.components.follower:GetLeader() then
        data.leader_guid = inst.components.follower:GetLeader().GUID
    end
end

local function onload(inst, data)
    if data ~= nil and data.level ~= nil then
        inst.level = data.level 
        if inst.level > 0 then inst:DoTaskInTime(0,LevelUp) end
    end
    if data ~= nil and data.upgradelevel ~= nil then
        inst.upgradelevel = data.upgradelevel
    else
        inst.upgradelevel = inst.upgradelevel or 0
    end
    if data ~= nil then
        inst.saved_upgradelevel = data.saved_upgradelevel or 0
        inst.saved_upgradelevel_mk3 = data.saved_upgradelevel_mk3 or 0
        inst.was_mk2 = data.was_mk2
        inst.was_mk3 = data.was_mk3
        -- BUG FIX 3: Load saved prefab name
        inst.saved_prefab_name = data.saved_prefab_name
    end
    -- Restore follower after save/load
    if data ~= nil and data.leader_guid ~= nil then
        inst:DoTaskInTime(0, function()
            local leader = TheWorld.GUIDToPos and TheWorld.GUIDToPos(data.leader_guid)
            if not leader then
                for k, v in pairs(Ents) do
                    if k == data.leader_guid then
                        leader = v
                        break
                    end
                end
            end
            if leader and leader:IsValid() and inst:IsValid() then
                if inst.components.follower then
                    inst.components.follower:SetLeader(leader)
                end
            end
        end)
    end
    -- Wait for inst to have named component before updating name
    inst:DoTaskInTime(0, function()
        if inst.prefab == "williambuster2" and inst.components.named then
            local function UpdateBuster2Name(inst)
                local base = "Buster Bot Mk.II"
                local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
                local hp = math.floor(inst.components.health.currenthealth)
                local maxhp = math.floor(inst.components.health.maxhealth)
                -- v2.0.40: show MK3 upgrade progress only while in progress (>0)
                local upgrade_str = (inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0) and (" | Upgrade: " .. inst.upgradelevel_mk3 .. "/90") or ""
                inst.components.named:SetName(base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str)
            end
            UpdateBuster2Name(inst)
        elseif inst.prefab == "williambuster3" and inst.components.named then
            local function UpdateBuster3Name(inst)
                local base = "Buster Bot Mk.III"
                local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
                local hp = math.floor(inst.components.health.currenthealth)
                local maxhp = math.floor(inst.components.health.maxhealth)
                local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp
                inst.components.named:SetName(name_str)
                inst.name = name_str
            end
            UpdateBuster3Name(inst)
        elseif inst.components.named then
            local function UpdateBusterName(inst)
                local base = "Buster Bot"
                local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
                local hp = math.floor(inst.components.health.currenthealth)
                local maxhp = math.floor(inst.components.health.maxhealth)
                -- v2.0.40: show MK2 upgrade progress only while in progress (>0)
                local upgrade_str = (inst.upgradelevel and inst.upgradelevel > 0) and (" | Upgrade: " .. inst.upgradelevel .. "/85") or ""
                inst.components.named:SetName(base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str)
            end
            UpdateBusterName(inst)
        end
    end)
end

    local function fn(inst)
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()
        inst.MiniMapEntity:SetIcon("williambuster.tex")

        inst.DynamicShadow:SetSize(1.5, 1)

        inst.Transform:SetFourFaced()

    MakeCharacterPhysics(inst, 50, .5)

        inst.level = 0

        inst.Physics:SetCollides(false)
        inst:DoTaskInTime(0, function() inst.Physics:SetCollides(true) end)

    inst.AnimState:SetBank("knight")
    inst.AnimState:SetBuild("william_buster")
        inst.AnimState:PlayAnimation("idle_loop", true)
    inst.Transform:SetScale(0.8, 0.8, 0.8)

        inst:AddTag("willfollower")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")

        -- v2.0.36 FIX: hover display on CLIENT. The client doesn't have
        -- inst.GetDisplayName (set only on server) and inst.name resolves to
        -- STRINGS.NAMES.WILLIAMBUSTER = "Buster Bot" (no fuel/HP info). The
        -- engine's GetDisplayName checks inst.name BEFORE replica.named, so
        -- MK1 showed "Buster Bot" on hover instead of the fuel/HP string.
        -- displaynamefn has the HIGHEST priority (checked before inst.name),
        -- so setting it here (runs on BOTH server and client, before the
        -- ismastersim return) forces hover to use the named component/replica
        -- which has the correct "Buster Bot\nFuel: X% | HP: X/X" string.
        inst.displaynamefn = function(inst)
            if inst.components.named ~= nil then
                return inst.components.named.name
            end
            if inst.replica.named ~= nil then
                return inst.replica.named.name
            end
            return inst.name
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end


        inst:AddComponent("willyraise")
    inst.components.willyraise:SetOnRiseFn(MakeAlive)
    inst.components.willyraise:SetOnLowerFn(OnFuelEmpty)

        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUSTER_HEALTH)
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health.redirect = nodebrisdmg
                inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("buster")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("fueled")
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled.accepting = true  -- Enable manual fueling (reverted to original)
    inst.components.fueled:InitializeFuelLevel(TUNING.WILLIAM_BUSTER_MAXFUEL)
    inst.components.fueled.bonusmult = 1

        inst.OnPreLoad = onload
        inst.OnSave = onsave

        inst:ListenForEvent("levelup", LevelUp)

        return inst
    end

        --ACTIVE BUSTER-----------
        
    local function active(inst)
        local inst = fn(inst)

    MakeCharacterPhysics(inst, 50, .5)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddTag("alive")
        inst:AddTag("scarytoprey")
        inst:AddTag("buster")
        inst:AddTag("ebuild_wrenchable")

    inst:AddComponent("named")

    inst.components.fueled:SetUpdateFn(fuelupdate)
    inst.components.fueled:SetDepletedFn(OnFuelEmpty)

    -- Rain damage (like WX-78) when active
    inst:DoPeriodicTask(1, function(inst)
        if TheWorld.state.israining and inst.components.health then
            inst.components.health:DoDelta(-1, false, "wetness")
        end
    end)

    -- Lightning recharge (refuel, no overcharge)
    inst:ListenForEvent("lightningstrike", function(inst)
        if inst.components.fueled then
            local refuel = inst.components.fueled.maxfuel * 0.25
            inst.components.fueled:DoDelta(refuel)
        end
    end)

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.WILLIAM_BUSTER_WALK_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

    inst:SetStateGraph("SGwilliambuster")

        inst:AddComponent("combat")
    inst.components.combat:SetRetargetFunction(2, retargetfn) --Look for leader's target.
    inst.components.combat:SetKeepTargetFunction(keeptargetfn) --Keep attacking while leader is near.
    inst.components.combat.hiteffectsymbol = "spring"
    inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BUSTER_ATTACK_PERIOD)
        inst.components.combat:SetRange(TUNING.WILLIAM_BUSTER_ATTACK_RANGE)
    inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BUSTER_DAMAGE)

        inst:ListenForEvent("attacked", OnAttacked)

        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true

    inst.components.fueled:StartConsuming()

    MakeHauntablePanic(inst)

    -- v2.0.65: mark active buster as "on" so the brain's Deactivated gate
    -- (WhileNode inst.on == false) does not block movement. The empty husk
    -- prefab sets inst.on = false to stay inert.
    inst.on = true

        inst:SetBrain(brain)

    MakeMediumBurnableCharacter(inst, "spring")
    MakeMediumFreezableCharacter(inst, "spring")
inst.components.burnable.ignorefuel = true

        -- Upgrade progress tracking (must be before named update)
        inst.upgradelevel = inst.upgradelevel or 0

        -- Named status display (Fuel | HP)
        inst._periodic_name_tasks = inst._periodic_name_tasks or {}
        local function UpdateBusterName(inst)
            local base = "Buster Bot"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            -- v2.0.40: show MK2 upgrade progress only while in progress (>0).
            local upgrade_str = (inst.upgradelevel and inst.upgradelevel > 0) and (" | Upgrade: " .. inst.upgradelevel .. "/85") or ""
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateBusterName(inst)
        local task = inst:DoPeriodicTask(2, UpdateBusterName)
        table.insert(inst._periodic_name_tasks, task)

        -- Upgrade + Repair system: wrench + scrap
        inst:AddComponent("engieworkable")
        inst.components.engieworkable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.engieworkable:SetMaxWork(1)
        inst.components.engieworkable:SetWorkLeft(1)
        inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            _dbg("[DEBUG] ==============================================")
            _dbg("[DEBUG] OnFinishCallback chamado para Buster Bot")
            _dbg("[DEBUG] inst.prefab:", inst.prefab)
            _dbg("[DEBUG] worker.prefab:", worker.prefab)
            _dbg("[DEBUG] worker.name:", worker.name)
            _dbg("[DEBUG] inst.upgradelevel:", inst.upgradelevel)
            
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            _dbg("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- PRIORITY 1: Repair if HP < 100% (NO skill required, works for MK1/MK2/MK3)
            -- v2.0.67 FIX: previously MK1 with damaged HP went straight to the upgrade
            -- path, which requires the Buster MK. II skill — so early-game players could
            -- NOT repair a damaged MK1 buster. Now repair always runs first when damaged.
            if inst.components.health and inst.components.health.currenthealth < inst.components.health.maxhealth then
                _dbg("[DEBUG] Buster - modo repair (HP < max, qualquer tier)")
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                if repair_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
                return
            end

            -- v2.0.68 FIX: the previous "HP is already full" block here did an early
            -- return when HP >= max, which BLOCKED the upgrade path below. So a buster
            -- with full HP + a player who HAD the MK2 skill would just hear "HP is
            -- already full!" and never upgrade. Removed — when HP is full we fall
            -- through to the upgrade path (skill check + scrap). The MK2+ repair
            -- fallback below already has its own "HP is already full" message.

            -- Check if trying to upgrade MK1 to MK2
            if not inst:HasTag("buster_upgraded") and inst.prefab ~= "williambuster2" then
                _dbg("[DEBUG] Buster é MK1 - verificando upgrade para MK2")
                _dbg("[DEBUG] Chamando WagstaffHasSkill para wagstaff_buster_evolve")
                _dbg("[DEBUG] worker tem skilltreeupdater?", worker.components.skilltreeupdater ~= nil)
                local has_skill = _G.WagstaffHasSkill(worker, "wagstaff_buster_evolve")
                _dbg("[DEBUG] Resultado de WagstaffHasSkill:", has_skill)
                if not has_skill then
                    _dbg("[DEBUG] Skill NÃO encontrada! Abortando upgrade.")
                    if worker.components.talker then
                        worker.components.talker:Say("Requires Buster Bot MK. II skill!\n(Activate it in the skill tree!)")
                    end
                    return
                end
                _dbg("[DEBUG] Skill encontrada! Prosseguindo com upgrade...")

                -- Upgrade: scrap metal per wrench hit (5 per hit, 85 total for Mk.II)
                local scrap_count = 0
                if worker.components.inventory then
                    for _, item in pairs(worker.components.inventory.itemslots) do
                        if item ~= nil and item.prefab == "scrap" and item.components.stackable then
                            scrap_count = scrap_count + item.components.stackable:StackSize()
                        elseif item ~= nil and item.prefab == "scrap" then
                            scrap_count = scrap_count + 1
                        end
                    end
                end
                local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
                if upgrade_cost > 0 and scrap_count < upgrade_cost then
                    if worker.components.talker then
                        worker.components.talker:Say("Need 5 Scrap Metal!")
                    end
                    return
                end
                if upgrade_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
                end
                inst.upgradelevel = inst.upgradelevel + 5
                UpdateBusterName(inst)

                if inst.upgradelevel >= 85 then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    if worker.components.talker then
                        worker.components.talker:Say("Heavy Impact upgrade complete!")
                    end

                    local pt = inst:GetPosition()
                    local newbot = SpawnPrefab("williambuster2")
                    if newbot ~= nil then
                        newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                        newbot.Transform:SetRotation(inst.Transform:GetRotation())

                        if inst.components.fueled and newbot.components.fueled then
                            newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                        end
                        if inst.components.health and newbot.components.health then
                            newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                        end
                        newbot.level = inst.level
                        newbot.upgradelevel = inst.upgradelevel or 0

                        if inst.components.follower ~= nil and inst.components.follower:GetLeader() ~= nil then
                            newbot.components.follower:SetLeader(inst.components.follower:GetLeader())
                        end

                        local fx = SpawnPrefab("small_puff")
                        fx.Transform:SetPosition(pt.x, pt.y, pt.z)
                        inst.SoundEmitter:PlaySound("dontstarve/common/craftable")
                    end
                    inst:Remove()
                end
                return
            end

            -- Repair for MK2+
            if inst.components.health.currenthealth >= inst.components.health.maxhealth then
                if worker.components.talker then
                    worker.components.talker:Say("HP is already full!")
                end
                return
            end
            local function IsScrap(item)
                return item.prefab == "scrap"
            end
            local scrapstack = worker.components.inventory:FindItem(IsScrap)
            local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
            if repair_cost > 0 and scrapstack == nil then
                if worker.components.talker then
                    worker.components.talker:Say("Need Scrap Metal to repair!")
                end
                return
            end
            if repair_cost > 0 then
                worker.components.inventory:ConsumeByName("scrap", repair_cost)
            end
            inst.components.health:DoDelta(50)
            inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
            if worker.components.talker then
                worker.components.talker:Say("Repaired 50 HP!")
            end
        end)

        return inst
    end

-- BUSTER BOT Mk.II: Upgraded version with AoE damage, stun chance, +500HP, +5DMG
    local function active2(inst)
        local inst = active(inst)

        -- _named tag removed (causes on-hover display issues)
        inst:AddTag("buster_upgraded")

        if not TheWorld.ismastersim then
            return inst
        end

        -- Bigger size for Mk.II
        inst.Transform:SetScale(1.0, 1.0, 1.0)

        -- Slightly warmer tint to differentiate (menos acinzentado)
        inst.AnimState:SetMultColour(0.95, 0.9, 0.8, 1)

        -- Override health and damage
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUSTER_HEALTH + 300)
        inst.components.health:DoDelta(300)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BUSTER_DAMAGE + 5)

        -- Named status display (Fuel | HP | Upgrade for Mk.II) - FIXED: format como Brute
        inst.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        if inst.components.named == nil then
            inst:AddComponent("named")
        end
        -- Cancel any existing periodic tasks from parent function (active)
        if inst._periodic_name_tasks then
            for _, task in ipairs(inst._periodic_name_tasks) do
                if task then
                    task:Cancel()
                end
            end
        end
        inst._periodic_name_tasks = inst._periodic_name_tasks or {}
        local function UpdateBuster2Name(inst)
            local base = "Buster Bot Mk.II"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            -- v2.0.40: show MK3 upgrade progress only while in progress (>0).
            local upgrade_str = (inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0) and (" | Upgrade: " .. inst.upgradelevel_mk3 .. "/90") or ""
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateBuster2Name(inst)
        local task = inst:DoPeriodicTask(2, UpdateBuster2Name)
        table.insert(inst._periodic_name_tasks, task)

        -- Mk.II: Repair + Upgrade in one engieworkable callback
        inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            _dbg("[DEBUG] ==============================================")
            _dbg("[DEBUG] OnFinishCallback chamado para Buster Bot MK2")
            _dbg("[DEBUG] inst.prefab:", inst.prefab)
            _dbg("[DEBUG] worker.prefab:", worker.prefab)
            _dbg("[DEBUG] inst.upgradelevel_mk3:", inst.upgradelevel_mk3)
            
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                return
            end
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            _dbg("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- Check if can upgrade first
            _dbg("[DEBUG] Verificando skill wagstaff_buster_mk3...")
            local has_mk3_skill = _G.WagstaffHasSkill(worker, "wagstaff_buster_mk3")
            _dbg("[DEBUG] Tem skill MK3?", has_mk3_skill)
            _dbg("[DEBUG] upgradelevel_mk3 atual:", inst.upgradelevel_mk3)
            if has_mk3_skill and inst.upgradelevel_mk3 < 90 then
                _dbg("[DEBUG] Tentando upgrade para MK3...")
                -- v2.0.16: 5 per hit, 90 total for Mk.III (was 120)
                local scrap_count = 0
                if worker.components.inventory then
                    for _, item in pairs(worker.components.inventory.itemslots) do
                        if item ~= nil and item.prefab == "scrap" and item.components.stackable then
                            scrap_count = scrap_count + item.components.stackable:StackSize()
                        elseif item ~= nil and item.prefab == "scrap" then
                            scrap_count = scrap_count + 1
                        end
                    end
                end
                local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
                if upgrade_cost > 0 and scrap_count < upgrade_cost then
                    if worker.components.talker then
                        worker.components.talker:Say("Need 5 Scrap Metal!")
                    end
                    return
                end
                if upgrade_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
                end
                inst.upgradelevel_mk3 = inst.upgradelevel_mk3 + 5
                UpdateBuster2Name(inst)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

                if inst.upgradelevel_mk3 >= 90 then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    if worker.components.talker then
                        worker.components.talker:Say("Explosive Punch upgrade complete!")
                    end

                    -- Spawn upgraded bot
                    local pt = inst:GetPosition()
                    local newbot = SpawnPrefab("williambuster3")
                    if newbot ~= nil then
                        newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                        newbot.Transform:SetRotation(inst.Transform:GetRotation())

                        -- Transfer fuel
                        if inst.components.fueled and newbot.components.fueled then
                            newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                        end
                        -- Transfer health
                        if inst.components.health and newbot.components.health then
                            newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                        end
                        newbot.level = inst.level
                        newbot.upgradelevel = inst.upgradelevel or 70
                        newbot.upgradelevel_mk3 = inst.upgradelevel_mk3 or 75

                        -- Set leader
                        if inst.components.follower ~= nil and inst.components.follower:GetLeader() ~= nil then
                            newbot.components.follower:SetLeader(inst.components.follower:GetLeader())
                        end

                        -- Spawn FX
                        local fx = SpawnPrefab("small_puff")
                        fx.Transform:SetPosition(pt.x, pt.y, pt.z)
                        inst.SoundEmitter:PlaySound("dontstarve/common/craftable")
                    end

                    inst:Remove()
                end
                return
            end

            -- If not upgrading, try repair
            if inst.components.health.currenthealth >= inst.components.health.maxhealth then
                if worker.components.talker then
                    worker.components.talker:Say("HP is already full!")
                end
            else
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                if repair_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
            end
        end)

        -- Save/load for buster2 upgrade progress
        local old_OnSaveBuster2 = inst.OnSave
        local function OnSaveBuster2WithUpgrade(inst, data)
            if old_OnSaveBuster2 then
                old_OnSaveBuster2(inst, data)
            end
            data.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        end
        local old_OnLoadBuster2 = inst.OnLoad
        local function OnLoadBuster2WithUpgrade(inst, data)
            if old_OnLoadBuster2 then
                old_OnLoadBuster2(inst, data)
            end
            if data then
                inst.upgradelevel_mk3 = data.upgradelevel_mk3 or 0
                UpdateBuster2Name(inst)
            end
        end
        inst.OnSave = OnSaveBuster2WithUpgrade
        inst.OnLoad = OnLoadBuster2WithUpgrade

        -- CELESTIAL POSSESSION: "Gestalt Agressivo" - Aura simples + FX gelo + Cor pulsante
        inst._celestial_light = nil
        inst._aura_fx = nil
        inst._shadow_clone = nil
        
        -- Affinity pulse (shared module, MK3 only)

        inst:DoPeriodicTask(3, function()
            if inst.prefab == "williambuster3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Light própria azul lunar
                if inst._celestial_light == nil then
                    inst.entity:AddLight()
                    inst._celestial_light = true
                end
                if inst.Light then
                    inst.Light:SetRadius(2)
                    inst.Light:SetIntensity(0.5)
                    inst.Light:SetFalloff(0.6)
                    inst.Light:SetColour(0.3, 0.5, 1) -- Blue electric
                    inst.Light:Enable(true)
                end
                
                -- AURA BUSTER - só quando ativo (nil = inicialmente ativo)
                if inst.on ~= false and (inst._aura_fx == nil or not inst._aura_fx:IsValid()) then
                    inst._aura_fx = SpawnPrefab("bot_aura_buster")
                    if inst._aura_fx then
                        inst._aura_fx._parent = inst
                    end
                end
                
                -- v2.0.58: shadow clone lifecycle is now owned by the dedicated
                -- 0.5s sync task below (no reference clearing here — the task
                -- despawns the clone entity properly when the pulse fades).
            else
                -- Remove effects
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                    inst._aura_fx:Remove()
                    inst._aura_fx = nil
                end
            end
            
            -- v2.0.58: Shadow clone spawn/despawn moved out of this 3s task into
            -- a dedicated 0.5s task (below) that is tightly synced to the
            -- AffinityPulse's _aff_active flag, so the clone and the shadow pulse
            -- always turn on/off together. This block only keeps the celestial-
            -- light disable + colour reset for the parent buster.
            if inst.prefab == "williambuster3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
            else
                if not (TheWorld.state.isday and OwnerHasCelestial(inst)) then
                    if not inst:HasTag("shadow_buster_clone") then
                        inst.AnimState:SetMultColour(1, 1, 1, 1)
                        inst.AnimState:SetAddColour(0, 0, 0, 0)
                    end
                end
            end
        end)

        -- v2.0.58: Shadow clone lifecycle — synced to the AffinityPulse.
        -- The pulse (inst._aff_active) is true only during DUSK+shadow while the
        -- owner is near AND in combat. The clone now mirrors this exactly: it
        -- spawns the instant the shadow pulse lights up and despawns the instant
        -- it fades (owner left combat, walked out of range, or dusk ended). This
        -- guarantees the Buster never has a clone spawned without the shadow pulse
        -- (or a shadow pulse without the clone) — they are always in sync.
        inst:DoPeriodicTask(0.5, function()
            if inst.prefab ~= "williambuster3" then return end
            if not TheWorld.ismastersim then return end

            -- At dusk the phase_check only passes via the shadow path, so
            -- _aff_active being true at dusk implies: shadow owner + near + in
            -- combat. That is exactly the condition the clone should live under.
            local shadow_pulse_active = TheWorld.state.isdusk and inst._aff_active == true

            if shadow_pulse_active then
                if not inst._shadow_clone or not inst._shadow_clone:IsValid() then
                    inst._shadow_clone = SpawnShadowClone(inst)
                end
            else
                -- Pulse stopped (left battle / owner far / dusk ended / owner
                -- lost shadow): despawn the clone with the shadow fade FX so it
                -- never lingers without a pulse.
                if inst._shadow_clone and inst._shadow_clone:IsValid() then
                    local cx, cy, cz = inst._shadow_clone.Transform:GetWorldPosition()
                    local remove_fx = SpawnPrefab("shadow_despawn")
                    if remove_fx then
                        remove_fx.Transform:SetPosition(cx, cy, cz)
                        if remove_fx.SoundEmitter then
                            remove_fx.SoundEmitter:KillAllSounds()
                        end
                    end
                    inst._shadow_clone:Remove()
                    inst._shadow_clone = nil
                end
            end
        end)



        return inst
    end

-- BUSTER BOT Mk.III: Upgraded version with Explosive Punch, +600HP, +10DMG
    local function active3(inst)
        local inst = active2(inst)

        -- _named tag removed (causes on-hover display issues)
        inst:AddTag("buster_upgraded_mk3")

        if not TheWorld.ismastersim then
            return inst
        end

        -- Bigger size for Mk.III
        inst.Transform:SetScale(1.2, 1.2, 1.2)

        -- Golden tint to differentiate
        inst.AnimState:SetMultColour(1, 0.9, 0.6, 1)

        -- Override health and damage
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUSTER_HEALTH + 600)
        inst.components.health:DoDelta(600)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BUSTER_DAMAGE + 10)

        -- Affinity pulse (MK3 only)
        -- v2.0.55: Phase-gate the pulse to match the affinity effect's active
        -- window. The buster's affinity combat bonus only fires during
        -- DAY+celestial or DUSK+shadow (see onhitotherfn checks). Without this
        -- gate the pulse lit up during battle even in the "weak" passive phase
        -- (e.g. celestial buster fighting at dusk), which was visually misleading.
        AffinityPulse.Setup(inst, GetOwner, {
            phase_check = function(inst, owner)
                if not (owner and owner:IsValid()) then return false end
                local celestial = owner:HasTag("wagstaff_celestial_possession")
                local shadow    = owner:HasTag("wagstaff_shadow_possession")
                return (TheWorld.state.isday and celestial)
                    or (TheWorld.state.isdusk and shadow)
            end,
        })

        -- Explosive Punch: 30% chance for bonus damage with explosion FX + pushback
        local old_onhit = inst.components.combat.onhitotherfn
        inst.components.combat.onhitotherfn = function(inst, other, damage)
            if old_onhit ~= nil then
                old_onhit(inst, other, damage)
            end
            if math.random() < 0.30 then
                local x, y, z = other.Transform:GetWorldPosition()
                
                -- CELESTIAL POSSESSION: AOE light explosion during day (MK3 only)
                if inst.prefab == "williambuster3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                    -- Find adjacent enemies and damage them
                    local adjacents = TheSim:FindEntities(x, y, z, 3, {"_combat"}, {"player", "companion", "willminion", "INLIMBO"})
                    for _, ent in ipairs(adjacents) do
                        if ent ~= other and ent ~= inst and ent.components.health and not ent.components.health:IsDead() then
                            -- v2.0.15: AOE 30% -> 50% of hit damage (was too weak)
                            ent.components.health:DoDelta(-damage * 0.5, false, "light_explosion")
                        end
                    end
                end
                
                -- Bonus explosive damage (50% extra)
                if other.components.health ~= nil and not other.components.health:IsDead() then
                    local bonus = damage * 0.5
                    other.components.health:DoDelta(-bonus, false, "explosive_punch")
                end
                -- Explosion visual effect (COMMON EXPLOSION FX) - 100% chance
                local fx = SpawnPrefab("explode_small")
                if fx then
                    fx.Transform:SetScale(1.0, 1.0, 1.0)  -- Normal scale for AOE
                end
                if fx then
                    fx.Transform:SetPosition(x, y, z)
                end
                inst.SoundEmitter:PlaySound("dontstarve/common/blackpowder_explo")
                -- Pushback: knock enemy away from buster
                if other.Physics ~= nil then
                    local angle = inst:GetAngleToPoint(other.Transform:GetWorldPosition())
                    local speed = 10
                    other.Physics:SetMotorVelOverride(speed * math.cos(angle * DEGREES), 0, -speed * math.sin(angle * DEGREES))
                    other:DoTaskInTime(0.4, function()
                        if other.Physics ~= nil then
                            other.Physics:ClearMotorVelOverride()
                        end
                    end)
                end
            end
        end

        -- Named status display (Fuel | HP only for Mk.III) - FIXED: format como Brute
        if inst.components.named == nil then
            inst:AddComponent("named")
        end
        -- Cancel any existing periodic tasks from parent functions (active or active2)
        if inst._periodic_name_tasks then
            for _, task in ipairs(inst._periodic_name_tasks) do
                if task then
                    task:Cancel()
                end
            end
        end
        inst._periodic_name_tasks = inst._periodic_name_tasks or {}
        local function UpdateBuster3Name(inst)
            local base = "Buster Bot Mk.III"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateBuster3Name(inst)
        local task = inst:DoPeriodicTask(2, UpdateBuster3Name)
        table.insert(inst._periodic_name_tasks, task)

        -- Mk.III Repair system
        if inst.components.engieworkable == nil then
            inst:AddComponent("engieworkable")
        end
        inst.components.engieworkable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.engieworkable:SetMaxWork(1)
        inst.components.engieworkable:SetWorkLeft(1)
        inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                return
            end
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end
            if inst.components.health.currenthealth >= inst.components.health.maxhealth then
                if worker.components.talker then
                    worker.components.talker:Say("HP is already full!")
                end
            else
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                if repair_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
            end
        end)

        -- MK3 reload resync: re-aplica FX celestial/shadow imediatamente após save->reload
        local old_OnLoad3 = inst.OnLoad
        inst.OnLoad = function(inst2, data)
            if old_OnLoad3 then old_OnLoad3(inst2, data) end
            if not TheWorld.ismastersim then return end
            inst2:DoTaskInTime(0, function()
                if not inst2:IsValid() then return end
                local owner = inst2.components.follower and inst2.components.follower:GetLeader()
                local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
                local shadow = owner and owner:HasTag("wagstaff_shadow_possession")
                if TheWorld.state.isday and celestial then
                    if inst2._celestial_light == nil then inst2.entity:AddLight(); inst2._celestial_light = true end
                    if inst2.Light then inst2.Light:Enable(true); inst2.Light:SetRadius(2); inst2.Light:SetIntensity(0.5); inst2.Light:SetColour(0.3,0.5,1) end
                    if inst2.on ~= false and (inst2._aura_fx == nil or not inst2._aura_fx:IsValid()) then
                        inst2._aura_fx = SpawnPrefab("bot_aura_buster")
                        if inst2._aura_fx then inst2._aura_fx._parent = inst2 end
                    end
                end
                -- v2.0.58: Don't spawn the clone on reload — the dedicated 0.5s
                -- sync task will spawn it within ~0.5s once the AffinityPulse's
                -- RefreshGate confirms dusk + shadow + owner near + in combat.
                -- Spawning here unconditionally would flash a clone that despawns
                -- right away if the buster isn't in combat on load.
            end)
        end

        return inst
    end

-- EMPTY BUSTER -----------------

local function onload_empty(inst, data)
    if data ~= nil and data.william ~= nil then
        inst.william = data.william
    end
end

local function onsave_empty(inst, data)
    data.william = inst.william ~= nil and inst.william or nil
end



local function revivetest(newsection, oldsection, inst, doer)
        if newsection >= 0 then
    local pt = inst:GetPosition()
        if doer ~= nil and doer:HasTag("williamcrafter") then
                MakeAlive(inst, doer)
                end
        end
end

    local function empty(inst)
        local inst = fn(inst)

    inst.AnimState:SetBank("knight")
    inst.AnimState:AddOverrideBuild("william_buster_empty")
    inst.AnimState:SetBuild("william_buster")
        inst.AnimState:PlayAnimation("sleep_loop", false)
        inst.AnimState:Pause()
    inst.Transform:SetScale(0.8, 0.8, 0.8)

    MakeCharacterPhysics(inst, 80, .25)
        inst.Physics:SetFriction(1)

        if not TheWorld.ismastersim then
            return inst
        end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
            inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

        inst:AddTag("Notarget")

    -- v2.0.65: mark empty husk as "off" so the brain's Deactivated gate
    -- (WhileNode inst.on == false) keeps it from following/teleporting to
    -- the leader. The husk inherits brain + follower from fn(), so without
    -- this the Follow node's catch-up teleport would drag the inert husk
    -- toward the player.
    inst.on = false

--    inst.components.fueled.currentfuel = 0

    -- v2.0.72 FIX: reverted to original mod's husk design.
    -- The husk needs only TWO things for reactivation to work:
    --   1. `willyraise` component (inherited from fn()) — gives the right-click
    --      WILLYRAISE action. When the player right-clicks the fueled husk,
    --      WILLYRAISE.fn calls willyraise:Rise(doer) → MakeAlive(inst, doer)
    --      → spawns a new active buster at the correct MK level.
    --   2. `workable` HAMMER — for dismantling with a hammer.
    --
    -- The previous code (v2.0.71 and the old BUG FIX 6) added a
    -- percentusedchange listener that swapped workable's action from HAMMER
    -- to ACTIVATE when fuel was present. This BROKE reactivation because:
    --   - When workable has ACTIVATE, DST shows ACTIVATE as the right-click
    --     action instead of WILLYRAISE (workable takes priority).
    --   - The ACTIVATE path calls workable's OnFinishCallback, which is a
    --     different code path than willyraise:Rise → MakeAlive.
    --   - The RemoveComponent+AddComponent dance (pre-v2.0.71) also left
    --     workable in a broken state.
    --
    -- The original mod (2607507857 & 3665517849) never had this ACTIVATE
    -- swap — it relied purely on willyraise for reactivation. This commit
    -- matches that design. The husk has no follower component (follower is
    -- added in active(), not fn()), so the WILLYRAISE action condition
    -- (inst.replica.follower == nil) passes and the action appears.
    inst.components.fueled.accepting = true

    MakeHauntableWork(inst)

        return inst
    end


local function onbuilt(inst, builder)
    local theta = math.random() * 2 * PI
    local pt = builder:GetPosition()
    local radius = math.random(1, 2)
    local offset = FindWalkableOffset(pt, theta, radius, 12, true, true, NoHoles)
    if offset ~= nil then
        pt.x = pt.x + offset.x
        pt.z = pt.z + offset.z
    end
   local pet = builder:HasTag("williamcrafter") and builder.components.petleash:SpawnPetAt(pt.x, 0, pt.z, "williambuster") or SpawnPrefab("williambuster_empty")
        if pet ~= nil then
            if pet.sg ~= nil then
                pet.sg:GoToState("spawn") 
            else
                pet.Transform:SetPosition(pt.x, 0, pt.z)
        pet.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
        SpawnPrefab("small_puff").Transform:SetPosition(pt.x, 0, pt.z)
            end
        pet.components.fueled.currentfuel = pet.components.fueled.currentfuel*0.9
    inst:Remove()
        end
end

    local function builder()
        local inst = CreateEntity()

        inst.entity:AddTransform()

        inst:AddTag("CLASSIFIED")

        --[[Non-networked entity]]
        inst.persists = false

        --Auto-remove if not spawned by builder
        inst:DoTaskInTime(0, inst.Remove)

        if not TheWorld.ismastersim then
            return inst
        end


    inst.OnSave = onsave_empty
    inst.OnLoad = onload_empty
        inst.OnBuiltFn = onbuilt

        return inst
    end


    return Prefab("williambuster", active, assets, prefabs),
    Prefab("williambuster2", active2, assets, prefabs),
    Prefab("williambuster3", active3, assets, prefabs),
    Prefab("williambuster_builder", builder, assets, prefabs),
    Prefab("williambuster_empty", empty, assets, prefabs)



--------------------------------------------------------------------------
