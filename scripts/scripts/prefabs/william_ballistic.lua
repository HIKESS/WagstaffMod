local prefabs =
{

}

    local assets =
    {
	Asset("ANIM", "anim/william_ballistic.zip"),
        Asset("SOUND", "sound/maxwell.fsb"),
    }
SetSharedLootTable("ballistic",
{
    {'nitre',          1},
})

SetSharedLootTable("ballisticgadget",
{
    {'williamgadget',          1.00},  -- 100% drop ALWAYS
    {'goldnugget',             0.50},  -- 50% chance
    {'nitre',                  0.50},  -- 50% chance
})

local function lootsetfn(lootdropper)
    local loot = {}
    local amount = lootdropper.inst.level*0.75
	if amount < 1 then amount = 1 end

		if lootdropper.inst.level > 0 then
    		for k = 1, amount do
            table.insert(loot, "gears")
		end
		end
		

    lootdropper:SetLoot(loot)
end

local function LevelUp(inst, amount)
	if inst.level < 3 and amount ~= nil then
	inst.level = inst.level + amount
	if inst.sg ~= nil then
	inst.sg:GoToState("fed")
	end
end

	if inst.level > 3 then inst.level = 3 end

	inst:DoTaskInTime(0, function()
		inst:AddTag("level"..inst.level)

	if inst.components.combat ~= nil then
    inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD/(1+inst.level*0.3))
	end
	end)
end

local brain = require "brains/williamballisticbrain"
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
    local has_shadow = owner and owner:HasTag("wagstaff_shadow_possession")
    if has_shadow then
        -- print("[DEBUG] OwnerHasShadow: TRUE for", inst.prefab, "owner:", owner and owner.name or "nil")
    end
    return has_shadow
end

local function ZapFX(inst)
            local fx = SpawnPrefab("electrichitsparks")
            fx.entity:SetParent(inst.entity)
            fx.entity:AddFollower()
            fx.Follower:FollowSymbol(inst.GUID, "body", 5, -120, 0)

	end

local function CleanupStarcallerOrbs(inst, radius)
    radius = radius or 10
    if inst.Transform == nil then
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local orbs = TheSim:FindEntities(x, y, z, radius, {"williamballistic_orb"})
    for _, orb in ipairs(orbs) do
        if orb._parent_bot == nil or orb._parent_bot == inst then
                    orb:Remove()
        end
    end
end

local function StartStarCaller(inst)
    -- print("[DEBUG] StartStarCaller called, starcaller_active:", inst._starcaller_active, "fuel empty:", inst.components.fueled:IsEmpty(), "inst.on:", inst.on)
    if inst._starcaller_active then return end
    if inst.components.fueled:IsEmpty() then
        if inst.components.follower and inst.components.follower:GetLeader() then
            local leader = inst.components.follower:GetLeader()
            if leader.components.talker then
                leader.components.talker:Say("Not enough fuel!")
            end
        end
        return
    end
    inst._starcaller_active = true
    -- Spawn orb
    inst._starcaller_light = SpawnPrefab("stafflight")
    if inst._starcaller_light ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        inst._starcaller_light.Transform:SetPosition(x, y, z)
        -- IMPORTANT: Mark orb as attached to this bot so it gets removed when bot is removed
        inst._starcaller_light._parent_bot = inst
        inst._starcaller_light:AddTag("williamballistic_orb")
        -- Remove sanity aura, heat and fire propagation - orb is purely a light source
        if inst._starcaller_light.components.sanityaura ~= nil then
            inst._starcaller_light:RemoveComponent("sanityaura")
        end
        if inst._starcaller_light.components.heater ~= nil then
            inst._starcaller_light:RemoveComponent("heater")
        end
        if inst._starcaller_light.components.propagator ~= nil then
            inst._starcaller_light:RemoveComponent("propagator")
        end
        -- Remove stafflight's auto-removal timer - bot controls lifetime
        if inst._starcaller_light.components.perishable ~= nil then
            inst._starcaller_light.components.perishable:StopPerishing()
        end
        -- Add periodic check on orb to remove itself if parent bot é gone
        inst._starcaller_light:DoPeriodicTask(1, function(orb)
            if orb._parent_bot == nil or not orb._parent_bot:IsValid() then
                    orb:Remove()
            end
        end)
        -- Orbe padrão stafflight - sem variações celestiais ou shadow
        -- REMOVIDO: listener que só zerava ponteiro sem remover orbe
        -- Orbe será sempre removido por StopStarCaller em onremove/OnDismantle
    end
    -- Disable attacks while channeling
    inst._starcaller_base_attackperiod = inst.components.combat.min_attack_period or TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD
    inst.components.combat:SetAttackPeriod(999999)
    -- Drain fuel continuously
    inst._starcaller_fueltask = inst:DoPeriodicTask(1, function()
        if inst.components.fueled:IsEmpty() then
            StopStarCaller(inst)
            return
        end
        inst.components.fueled:DoDelta(-inst.components.fueled.maxfuel * 0.001) -- 0.1% per second
    end)
    ZapFX(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod")
end

local function StopStarCaller(inst)
    inst._starcaller_active = false
    -- Remove orb - try multiple times to ensure it's gone
    if inst._starcaller_light ~= nil then
        if inst._starcaller_light:IsValid() then
            inst._starcaller_light:Remove()
        end
        inst._starcaller_light = nil
    end
    CleanupStarcallerOrbs(inst, 10)
    -- Remove planar damage bonus
    inst:RemoveTag("planar_damage")
    inst._planar_bonus = nil
    -- Re-enable attacks
    inst.components.combat:SetAttackPeriod(inst._starcaller_base_attackperiod)
    -- Stop fuel drain
    if inst._starcaller_fueltask ~= nil then
        inst._starcaller_fueltask:Cancel()
        inst._starcaller_fueltask = nil
    end
end

local function ToggleStarCaller(inst, doer)
    -- print("[DEBUG] ToggleStarCaller called, starcaller_active:", inst._starcaller_active, "doer:", doer and doer.name or "nil")
    if inst._starcaller_active then
        StopStarCaller(inst)
        if inst.components.talker then
            inst.components.talker:Say("Star Caller OFF")
        end
    else
        StartStarCaller(inst)
        if inst.components.talker then
            inst.components.talker:Say("Star Caller ON - Consuming fuel...")
        end
    end
end

local function maketurret(inst, pt, charge)
    local is_mk3 = inst.was_mk3 or (inst.upgradelevel_mk3 ~= nil and inst.upgradelevel_mk3 >= 85)
    local is_mk2 = is_mk3 or inst.was_mk2 or (inst.upgradelevel ~= nil and inst.upgradelevel >= 90)
    local prefab = is_mk3 and "williamballistic3" or (is_mk2 and "williamballistic2" or "williamballistic")
    local bot = SpawnPrefab(prefab)
    if bot ~= nil then
        bot.Physics:SetCollides(false)
        bot.Physics:Teleport(pt.x, 0, pt.z)
        bot.Physics:SetCollides(true)
        bot.sg:GoToState("revived", charge)
        bot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        bot.components.fueled.currentfuel = inst.components.fueled.currentfuel
        bot.level = inst.level
        bot.upgradelevel = inst.upgradelevel or 0
        if is_mk2 then
            bot.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        end
        bot:PushEvent("levelup")
        inst:Remove()
    end
end

local function MakeAlive(inst)
	local pt = Vector3(inst.Transform:GetWorldPosition())
	maketurret(inst, pt)	
end


local function OnAddFuel(inst)
	inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel")
	if inst.components.inventoryitem == nil then 
    inst.sg:GoToState("fed")
--	elseif inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner == nil then
--	local pt = Vector3(inst.Transform:GetWorldPosition())
--	maketurret(inst, pt)
	end
	
end

local function fuelupdate(inst)
    end

local PLACER_SCALE = 1.6

local function retargetfn(inst)
    local playertargets = {}
    for i, v in ipairs(AllPlayers) do
        if v.components.combat.target ~= nil then
            playertargets[v.components.combat.target] = true
        end
    end

    return FindEntity(inst, PLACER_SCALE*10,
        function(guy)
            return inst.components.combat:CanTarget(guy)
                and (playertargets[guy] or
                    (guy.components.combat.target ~= nil and (guy.components.combat.target:HasTag("player") or guy.components.combat.target:HasTag("willminion"))))
        end,
        { "_combat" }, --see entityreplica.lua
        { "INLIMBO", "player" }
    )
end

local function shouldKeepTarget(inst, target)
    return target ~= nil
        and target:IsValid()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and inst:IsNear(target, 20)
end


local function getstatus(inst, viewer)
    local fuel = inst.components.fueled:IsEmpty() and "EMPTY"
        or inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .3 and "CRITICALFUEL"
        or inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .6 and "LOWFUEL"
        or "FINE"
    return fuel
end
local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function nodebrisdmg(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return (afflicter ~= nil and afflicter:HasTag("quakedebris"))
end

local function EquipWeapon(inst)
    if inst.components.inventory ~= nil and not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
        local weapon = CreateEntity()
        --[[Non-networked entity]]
        weapon.entity:AddTransform()
        weapon:AddComponent("weapon")
        weapon.components.weapon:SetDamage(TUNING.WILLIAM_BALLISTIC_DAMAGE)
        weapon.components.weapon:SetRange(inst.components.combat.attackrange, inst.components.combat.attackrange+4)
        weapon.components.weapon:SetProjectile("william_charge")
        weapon.components.weapon:SetElectric()
        weapon:AddComponent("inventoryitem")
        weapon.persists = false
        weapon.components.inventoryitem:SetOnDroppedFn(inst.Remove)
        weapon:AddComponent("equippable")

        inst.components.inventory:Equip(weapon)
    end
end


local function OnAttacked(inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if attacker ~= nil and not PreventTargetingOnAttacked(inst, attacker, "player") then
        inst.components.combat:SetTarget(attacker)
    end
end



local function onlightning(inst)
	local pt = Vector3(inst.Transform:GetWorldPosition())
	inst.components.fueled:SetPercent(1)
	ZapFX(inst)
	if inst.sg ~= nil then
	inst.sg:GoToState("hit")
	elseif inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner == nil then
--    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PlayAnimation("hit_shield", false)
	end
end

local function onworked(inst)
	if inst.sg~= nil then
	inst.sg:GoToState("hit")
	else
    inst.AnimState:PlayAnimation("hit_shield")
	end
end

local function OnHammered(inst, worker)
	if inst:HasTag("alive") then
    inst.components.lootdropper:SetChanceLootTable("ballisticgadget")
	else
	    inst.components.lootdropper:SetChanceLootTable(nil)
	end
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
    if inst.upgrade_progress ~= nil then
        data.upgrade_progress = inst.upgrade_progress
    end
    data.upgradelevel = inst.upgradelevel or 0
    if inst.components.fueled ~= nil then
        data.currentfuel = inst.components.fueled.currentfuel
    end
end

local function onload(inst, data)
    if data ~= nil and data.level ~= nil then
	inst.level = data.level 
	if inst.level > 0 then inst:DoTaskInTime(0,LevelUp) end
    end
    if data ~= nil and data.upgrade_progress ~= nil then
        inst.upgrade_progress = data.upgrade_progress
    end
    if data ~= nil and data.upgradelevel ~= nil then
        inst.upgradelevel = data.upgradelevel
    else
        inst.upgradelevel = inst.upgradelevel or 0
    end
    if data ~= nil and data.currentfuel ~= nil and inst.components.fueled ~= nil then
        inst.components.fueled.currentfuel = data.currentfuel
    end
    -- Wait for inst to have named component before updating name
    inst:DoTaskInTime(0, function()
        if inst.prefab == "williamballistic2" and inst.components.named then
            local function UpdateBallistic2Name(inst)
                local base = "Ballistic Bot Mk.II"
                local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
                local hp = math.floor(inst.components.health.currenthealth)
                local maxhp = math.floor(inst.components.health.maxhealth)
                local oc = inst._overcharge and "OVERCHARGED" or ""
                local upgrade_str = (inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0) and (" | Upgrade: " .. inst.upgradelevel_mk3 .. " / 85") or ""
                inst.components.named:SetName(base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. (oc ~= "" and " | " .. oc or "") .. upgrade_str)
            end
            UpdateBallistic2Name(inst)
        elseif inst.prefab == "williamballistic3" and inst.components.named then
            local function UpdateBallistic3Name(inst)
                local base = "Ballistic Bot Mk.III"
                local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
                local hp = math.floor(inst.components.health.currenthealth)
                local maxhp = math.floor(inst.components.health.maxhealth)
                local oc = inst._overcharge and "OVERCHARGED" or ""
                local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. (oc ~= "" and " | " .. oc or "")
                inst.components.named:SetName(name_str)
                inst.name = name_str
            end
            UpdateBallistic3Name(inst)
        elseif inst.components.named then
            local function UpdateBallisticName(inst)
                local base = "Ballistic Bot"
                local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
                local hp = math.floor(inst.components.health.currenthealth)
                local maxhp = math.floor(inst.components.health.maxhealth)
                local upgrade_str = (inst.upgradelevel and inst.upgradelevel > 0) and (" | Upgrade: " .. inst.upgradelevel .. " / 90") or ""
                inst.components.named:SetName(base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str)
            end
            UpdateBallisticName(inst)
        end
    end)
end




    local function fn(inst)
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()
        inst.entity:AddDynamicShadow()
        inst.MiniMapEntity:SetIcon("williamballistic.tex")

    inst.AnimState:SetBank("spider_hider")
    inst.AnimState:SetBuild("william_ballistic")
        inst.AnimState:PlayAnimation("idle", true)
   inst.Transform:SetScale(0.9, 0.9, 0.9)

	inst:AddTag("lightningrod")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("ballistic")

    inst:SetPrefabNameOverride("williamballistic")
    inst:AddTag("_named")

	inst.level = 0


        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end


        inst:AddComponent("health")
	inst.components.health.canmurder = false
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BALLISTIC_HEALTH)
       -- inst.components.health.nofadeout = true
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health.redirect = nodebrisdmg
                inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus
    inst.components.inspectable.getdescription = function(inst)
        if inst.components.named then
            return inst.components.named.name
        end
        return nil
    end

    inst:ListenForEvent("lightningstrike", onlightning)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
            inst.components.workable:SetWorkLeft(2)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

    inst:AddComponent("fueled")
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled.accepting = true  -- Enable manual fueling (reverted to original)
    inst.components.fueled:SetUpdateFn(fuelupdate)
    inst.components.fueled:InitializeFuelLevel(TUNING.WINONA_BATTERY_LOW_MAX_FUEL_TIME*5)
    inst.components.fueled.fueltype = FUELTYPE.CHEMICAL
    inst.components.fueled.bonusmult = 1

        inst.OnPreLoad = onload
        inst.OnSave = onsave

        inst:ListenForEvent("levelup", LevelUp)


        return inst
    end

	--ACTIVE-------------


local function OnDismantle(inst, doer)
    -- print("[DEBUG] OnDismantle called for", inst.prefab, "starcaller_active:", inst._starcaller_active)
    -- IMPORTANT: Stop Star Caller BEFORE anything else to ensure orb is removed
    if inst._starcaller_active or inst._starcaller_light ~= nil then
        -- print("[DEBUG] Force stopping Star Caller in OnDismantle")
        -- Directly remove orb if it exists
        if inst._starcaller_light ~= nil and inst._starcaller_light:IsValid() then
            -- print("[DEBUG] Directly removing orb in OnDismantle")
            inst._starcaller_light:Remove()
        end
        inst._starcaller_light = nil
        inst._starcaller_active = false
    end
    -- Also push event for any other cleanup
    inst:PushEvent("stop_starcaller")
    
    local item = SpawnPrefab("williamballistic_empty")
    if item ~= nil then
        item.Transform:SetPosition(inst.Transform:GetWorldPosition())
        item.DynamicShadow:SetSize(2.5, 1)
        item.AnimState:PlayAnimation("hide")
        item:DoTaskInTime(9*FRAMES, function(item) item.DynamicShadow:SetSize(0, 0)  end)
        item.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        item.components.fueled.currentfuel = inst.components.fueled.currentfuel
        item.SoundEmitter:PlaySound("dontstarve/common/together/catapult/hit", nil, .5)
        item.SoundEmitter:PlaySound("dontstarve/common/together/battery/down")
        item.level = inst.level
        item.upgradelevel = inst.upgradelevel or 0
        item.was_mk2 = inst.prefab == "williamballistic2" or inst.prefab == "williamballistic3"
        item.was_mk3 = inst.prefab == "williamballistic3"
        if inst.upgradelevel_mk3 ~= nil then
            item.upgradelevel_mk3 = inst.upgradelevel_mk3
        end
        item:PushEvent("levelup")
        inst:Remove()
    end
end


    local function active(inst)
        local inst = fn(inst)

    inst.DynamicShadow:SetSize(2.5, 1)

    MakeObstaclePhysics(inst, 0.25)
        inst.Transform:SetFourFaced()
        if not TheWorld.ismastersim then
            return inst
        end

	inst:AddTag("alive")
        inst:AddTag("scarytoprey")
        inst:AddTag("ebuild_wrenchable")

    inst:AddComponent("named")

    inst:SetStateGraph("SGwilliamballistic")


    inst:AddComponent("portablewillybot")
    inst.components.portablewillybot:SetOnDismantleFn(OnDismantle)

        inst:AddComponent("combat")
    inst.components.combat:SetRetargetFunction(1, retargetfn)
    inst.components.combat:SetKeepTargetFunction(shouldKeepTarget)
    inst.components.combat.hiteffectsymbol = "body"
    inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD)
    inst.components.combat:SetRange(TUNING.WINONA_CATAPULT_MAX_RANGE)
    inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BALLISTIC_DAMAGE)

        inst:ListenForEvent("attacked", OnAttacked)

    inst.components.lootdropper:SetChanceLootTable("ballistic")


    inst.components.fueled:SetDepletedFn(OnDismantle)

        -- Upgrade progress tracking (must be before named update)
        inst.upgradelevel = inst.upgradelevel or 0

        -- Named status display (Fuel | HP | Upgrade)
        inst._periodic_name_tasks = inst._periodic_name_tasks or {}
        local function UpdateBallisticName(inst)
            local base = "Ballistic Bot"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local upgrade_str = (inst.upgradelevel and inst.upgradelevel > 0) and (" | Upgrade: " .. inst.upgradelevel .. " / 90") or ""
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateBallisticName(inst)
        local task = inst:DoPeriodicTask(2, UpdateBallisticName)
        table.insert(inst._periodic_name_tasks, task)

        inst:SetBrain(brain)

    inst:AddComponent("inventory")
    inst:DoTaskInTime(0, function() EquipWeapon(inst) end)
        inst.components.fueled:StartConsuming()

    MakeMediumFreezableCharacter(inst, "body")

    MakeHauntableWork(inst)

    --[[ TEMPORARILY DISABLED FOR CRASH ISOLATION
    --==================================================================================
    -- MOBILITY UPGRADE: Wrench upgrade adds locomotor + follower
    -- 50 scraps total, 5 per hit (10 hits).
    --==================================================================================
    inst.upgrade_progress = inst.upgrade_progress or 0

    -- Use the existing workable for hammer hits, but redirect to upgrade logic
    inst.components.workable:SetOnWorkCallback(function(inst, worker)
        if inst.sg ~= nil then
            inst.sg:GoToState("hit")
        end
    end)
    inst.components.workable:SetOnFinishCallback(function(inst, worker)
        -- Reset work so it can be hit again
        inst.components.workable:SetWorkLeft(2)
        -- Use wrench durability
        local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
            wrench.components.finiteuses:Use(1)
        end

        -- Count available scrap
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
        if scrap_count < 5 then
            if worker.components.talker then
                worker.components.talker:Say("Need 5 Scrap Metal!")
            end
            return
        end
        worker.components.inventory:ConsumeByName("scrap", 5)
        inst.upgrade_progress = inst.upgrade_progress + 5
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

        if inst.upgrade_progress >= 50 then
            inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
            if worker.components.talker then
                worker.components.talker:Say("Mobility upgrade complete!")
            end

            -- Add mobility components
            inst:AddTag("ballistic_mobile")
            inst:AddComponent("locomotor")
            inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
            inst.components.locomotor:SetAllowPlatformHopping(true)
            inst:AddComponent("embarker")
            inst:AddComponent("follower")
            inst.components.follower:KeepLeaderOnAttacked()
            inst.components.follower.keepdeadleader = true
            inst.components.follower.keepleaderduringminigame = true
            inst.components.follower.leader = worker

            -- Switch to follow brain
            inst:SetBrain(require "brains/williamballisticbrain")
        end
    end)

    -- Load saved upgrade progress
    if inst.upgrade_progress >= 50 then
        -- Re-apply mobility if loading saved upgraded bot
        inst:AddTag("ballistic_mobile")
        inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")
        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true
    end
    --]]

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
            print("[DEBUG] ==============================================")
            print("[DEBUG] OnFinishCallback chamado para Ballistic Bot")
            print("[DEBUG] inst.prefab:", inst.prefab)
            print("[DEBUG] worker.prefab:", worker.prefab)
            print("[DEBUG] worker.name:", worker.name)
            print("[DEBUG] inst.upgradelevel:", inst.upgradelevel)
            
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            print("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- Check if trying to upgrade MK1 to MK2
            if not inst:HasTag("ballistic_upgraded") and inst.prefab ~= "williamballistic2" then
                print("[DEBUG] Ballistic é MK1 - verificando upgrade para MK2")
                print("[DEBUG] Chamando WagstaffHasSkill para wagstaff_ballistic_evolve")
                print("[DEBUG] worker tem skilltreeupdater?", worker.components.skilltreeupdater ~= nil)
                local has_skill = _G.WagstaffHasSkill(worker, "wagstaff_ballistic_evolve")
                print("[DEBUG] Resultado de WagstaffHasSkill:", has_skill)
                if not has_skill then
                    print("[DEBUG] Skill NÃO encontrada! Abortando upgrade.")
                    if worker.components.talker then
                        worker.components.talker:Say("Requires Ballistic Bot MK. II skill!\n(Activate it in the skill tree!)")
                    end
                    return
                end
                print("[DEBUG] Skill encontrada! Prosseguindo com upgrade...")

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
                UpdateBallisticName(inst)

                if inst.upgradelevel >= 90 then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    if worker.components.talker then
                        worker.components.talker:Say("Mobile Artillery upgrade complete!")
                    end

                    local pt = inst:GetPosition()
                    local newbot = SpawnPrefab("williamballistic2")
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
                            newbot.components.follower.leader = inst.components.follower:GetLeader()
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

-- BALLISTIC BOT Mk.II: Walking Battery — Overcharge, Battery Sharing, Rain Splash
    local function active2(inst)
        local inst = active(inst)

        inst:AddTag("_named")
        inst:AddTag("ballistic_upgraded")

        -- Electric blue tint for Mk.II
        inst.AnimState:SetMultColour(0.75, 0.85, 1.0, 1)

        if not TheWorld.ismastersim then
            return inst
        end

        -- Normal fuel battery for Mk.II (same as base bot)
        inst.components.fueled.maxfuel = TUNING.WINONA_BATTERY_LOW_MAX_FUEL_TIME * 5
        inst.components.fueled.currentfuel = inst.components.fueled.maxfuel
        inst.components.fueled.accepting = true  -- Can refuel manually like other bots

        -- Remove obstacle physics, add character physics for movement
        inst.Physics:ClearCollisionMask()
        MakeCharacterPhysics(inst, 50, .5)

        -- Add locomotor for movement
        inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

        -- Add follower so it follows player
        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true

        -- Find nearest player as leader if none set (spawned fresh)
        inst:DoTaskInTime(0, function()
            if inst.components.follower:GetLeader() == nil then
                local x, y, z = inst.Transform:GetWorldPosition()
                local players = TheSim:FindEntities(x, y, z, 15, {"player"})
                local closest = nil
                local closest_dist = math.huge
                for _, p in ipairs(players) do
                    local dist = inst:GetDistanceSqToInst(p)
                    if dist < closest_dist then
                        closest = p
                        closest_dist = dist
                    end
                end
                if closest ~= nil then
                    inst.components.follower.leader = closest
                end
            end
        end)

        -- Switch to follow brain
        inst:SetBrain(require "brains/williamballisticbrain")

        -- Named status display (Fuel | HP | Overcharge | Upgrade MK3)
        inst.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        -- Cancel any existing periodic tasks from parent function (active)
        if inst._periodic_name_tasks then
            for _, task in ipairs(inst._periodic_name_tasks) do
                if task then
                    task:Cancel()
                end
            end
        end
        inst._periodic_name_tasks = inst._periodic_name_tasks or {}
        local function UpdateBallistic2Name(inst)
            local base = "Ballistic Bot Mk.II"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local oc = inst._overcharge and "OVERCHARGED" or ""
            local upgrade_str = (inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0) and (" | Upgrade: " .. inst.upgradelevel_mk3 .. " / 85") or ""
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. (oc ~= "" and " | " .. oc or "") .. upgrade_str
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateBallistic2Name(inst)
        local task = inst:DoPeriodicTask(2, UpdateBallistic2Name)
        table.insert(inst._periodic_name_tasks, task)
        -- Mk.II: Repair + Upgrade in one engieworkable callback
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
            print("[DEBUG] ==============================================")
            print("[DEBUG] OnFinishCallback chamado para Ballistic Bot MK2")
            print("[DEBUG] inst.prefab:", inst.prefab)
            print("[DEBUG] worker.prefab:", worker.prefab)
            print("[DEBUG] inst.upgradelevel_mk3:", inst.upgradelevel_mk3)
            
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            print("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- Check if can upgrade first
            print("[DEBUG] Verificando skill wagstaff_ballistic_mk3...")
            local has_mk3_skill = _G.WagstaffHasSkill(worker, "wagstaff_ballistic_mk3")
            print("[DEBUG] Tem skill MK3?", has_mk3_skill)
            print("[DEBUG] upgradelevel_mk3 atual:", inst.upgradelevel_mk3)
            if has_mk3_skill and inst.upgradelevel_mk3 < 85 then
                print("[DEBUG] Tentando upgrade para MK3...")
                -- Upgrade: scrap metal per wrench hit (5 per hit, 85 total for Mk.III)
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
                UpdateBallistic2Name(inst)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

                if inst.upgradelevel_mk3 >= 85 then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    if worker.components.talker then
                        worker.components.talker:Say("Active Energy Orb upgrade complete!")
                    end

                    local pt = inst:GetPosition()
                    local newbot = SpawnPrefab("williamballistic3")
                    if newbot ~= nil then
                        newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                        newbot.Transform:SetRotation(inst.Transform:GetRotation())

                        -- Transfer fuel and health
                        if inst.components.fueled and newbot.components.fueled then
                            newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                        end
                        if inst.components.health and newbot.components.health then
                            newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                        end
                        newbot.level = inst.level

                        -- Set leader
                        if inst.components.follower ~= nil and inst.components.follower:GetLeader() ~= nil then
                            newbot.components.follower.leader = inst.components.follower:GetLeader()
                        end

                        -- Spawn fx
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

        -- Save/Load for MK3 upgrade progress
        local old_OnSaveBallistic2 = inst.OnSave
        function inst.OnSave(inst, data)
            if old_OnSaveBallistic2 then
                old_OnSaveBallistic2(inst, data)
            end
            data.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        end

        local old_OnLoadBallistic2 = inst.OnLoad
        function inst.OnLoad(inst, data)
            if old_OnLoadBallistic2 then
                old_OnLoadBallistic2(inst, data)
            end
            if data and data.upgradelevel_mk3 ~= nil then
                inst.upgradelevel_mk3 = data.upgradelevel_mk3
                UpdateBallistic2Name(inst)
            end
        end



        -- OVERCHARGE system: triggered by lightning strike while deployed
        inst._overcharge = false
        inst._overchargetask = nil

        local function ApplyOvercharge(inst)
            if inst._overcharge then return end
            inst._overcharge = true
            inst:AddTag("overcharged")

            -- 3x boost: Attack Rate, DMG, HP, Regen
            inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD / 3)
            inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BALLISTIC_DAMAGE * 3)
            local old_max = inst.components.health.maxhealth
            inst.components.health:SetMaxHealth(old_max + 500)
            inst.components.health:DoDelta(500)
            inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN * 3, TUNING.WILLIAM_ROBOT_REGENPERIOD)

            -- Electric FX
            inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
            ZapFX(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod")

            UpdateBallistic2Name(inst)
        end

        local function RemoveOvercharge(inst)
            if not inst._overcharge then return end
            inst._overcharge = false
            inst:RemoveTag("overcharged")

            -- Revert stats
            inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD)
            inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BALLISTIC_DAMAGE)
            inst.components.health:SetMaxHealth(inst.components.health.maxhealth - 500)
            inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
            inst.AnimState:ClearBloomEffectHandle()

            -- DISCHARGE: Drain battery completely after overcharge ends
            if inst.components.fueled then
                inst.components.fueled:SetPercent(0)
                -- Trigger fuel empty to turn off the bot
                if inst.components.fueled:IsEmpty() then
                    inst.components.fueled:SetDepletedFn(OnDismantle)
                end
            end

            if inst._overchargetask ~= nil then
                inst._overchargetask:Cancel()
                inst._overchargetask = nil
            end

            UpdateBallistic2Name(inst)
        end

        -- Override lightning handler for overcharge
        local old_onlightning = onlightning
        inst:RemoveEventCallback("lightningstrike", onlightning)
        inst:ListenForEvent("lightningstrike", function(inst)
            -- Refuel battery
            inst.components.fueled:SetPercent(1)
            ZapFX(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod")

            -- Only overcharge if deployed (not in inventory / following)
            if not inst.components.inventoryitem and inst.components.follower ~= nil then
                ApplyOvercharge(inst)
                -- Overcharge lasts 60 seconds
                if inst._overchargetask ~= nil then
                    inst._overchargetask:Cancel()
                end
                inst._overchargetask = inst:DoTaskInTime(60, RemoveOvercharge)
            end

            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)

        -- Rain Splash: attacks spread electric splash on ground during rain
        local old_onhit = inst.components.combat.onhitotherfn
        inst.components.combat.onhitotherfn = function(inst, other, damage)
            -- Safety: prevent recursion crashes
            if inst._in_rain_splash then return end
            if old_onhit ~= nil then
                old_onhit(inst, other, damage)
            end

            -- Safety checks
            if not other or not other:IsValid() or not other.Transform then return end
            
            inst._in_rain_splash = true
            
            local x, y, z = other.Transform:GetWorldPosition()

            -- Small AoE explosive rounds (MK II skill - sempre ativo)
            local ents = TheSim:FindEntities(x, y, z, 2, {"_combat"}, {"INLIMBO", "player", "companion", "willminion", "wall"})
            for _, ent in ipairs(ents) do
                if ent ~= inst and ent ~= other and ent:IsValid() and ent.components.combat ~= nil and not ent._ballistic_aoe_hit then
                    -- Mark to prevent chain reaction
                    ent._ballistic_aoe_hit = true
                    ent:DoTaskInTime(0.1, function() ent._ballistic_aoe_hit = nil end)
                    ent.components.combat:GetAttacked(inst, damage * 0.3)
                end
            end
            
            -- Rain splash: during rain, attacks leave electric puddles/splash + chain lightning (MK II)
            if TheWorld.state.israining then
                local splash = SpawnPrefab("sparks")
                if splash ~= nil and splash.Transform then
                    splash.Transform:SetPosition(x, 0, z)
                end
                
                -- Chain lightning to nearby enemies during rain (só Mk.II)
                if math.random() < 0.3 then
                    local chain_targets = TheSim:FindEntities(x, y, z, 4, {"_combat"}, {"INLIMBO", "player", "companion", "willminion"})
                    for _, ent2 in ipairs(chain_targets) do
                        if ent2 ~= inst and ent2 ~= other and ent2:IsValid() and ent2.components.health ~= nil then
                            ent2.components.health:DoDelta(-damage * 0.5, false, "ballistic_chain")
                            local zfx = SpawnPrefab("electrichitsparks")
                            if zfx and zfx.Transform then
                                zfx.Transform:SetPosition(ent2.Transform:GetWorldPosition())
                            end
                            
                            break -- only chain to 1 target
                        end
                    end
                end
            end
            
            inst._in_rain_splash = false
        end

        -- AUTO-RECHARGE: Absorb energy from nearby lightning rods / generators
        -- Wx-78 style: drains power from charged lightningrod or Winona battery
        inst:DoPeriodicTask(3, function()
            if inst.components.fueled:IsFull() then return end
            local x, y, z = inst.Transform:GetWorldPosition()
            -- Look for any lightningrod within 6 tiles (exclude self/bots)
            local sources = TheSim:FindEntities(x, y, z, 6, {"lightningrod"}, {"INLIMBO", "willminion"})
            local valid_source = nil
            for _, src in ipairs(sources) do
                if src ~= inst then
                    -- Accept any lightningrod (charged or not - ambient charge)
                    valid_source = src
                    break
                end
            end
            -- If no lightningrod, look for Winona battery/generator
            if valid_source == nil then
                local batteries = TheSim:FindEntities(x, y, z, 6, {"engineering", "battery"}, {"INLIMBO", "willminion"})
                for _, src in ipairs(batteries) do
                    if src ~= inst then
                        valid_source = src
                        break
                    end
                end
            end
            -- Also try engineering_battery tag alone
            if valid_source == nil then
                local batteries = TheSim:FindEntities(x, y, z, 6, {"engineering_battery"}, {"INLIMBO", "willminion"})
                for _, src in ipairs(batteries) do
                    if src ~= inst then
                        valid_source = src
                        break
                    end
                end
            end
            if valid_source ~= nil then
                -- Drain from source if it has fueled (Winona battery)
                if valid_source.components.fueled ~= nil and not valid_source.components.fueled:IsEmpty() then
                    valid_source.components.fueled:DoDelta(-valid_source.components.fueled.maxfuel * 0.05)
                end
                inst.components.fueled:DoDelta(inst.components.fueled.maxfuel * 0.05)
                ZapFX(inst)
                if not inst.SoundEmitter:PlayingSound("ballistic_recharge") then
                    inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod", "ballistic_recharge")
                end
            else
                inst.SoundEmitter:KillSound("ballistic_recharge")
            end
        end)

        -- STAR CALLER ORB: manual toggle via left-click on deployed bot
        inst._starcaller_active = false
        inst._starcaller_light = nil
        inst._starcaller_fueltask = nil
        inst._starcaller_base_attackperiod = TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD



        -- Listen for world save event to disable Star Caller before exit
        -- Auto-disable Star Caller on world save to prevent orb persistence
        inst:ListenForEvent("ms_save", function()
            if inst._starcaller_active then
                StopStarCaller(inst)
                CleanupStarcallerOrbs(inst, 20)
            end
        end, TheWorld)

        -- Clean up starcaller and affinity FX on remove
        inst:ListenForEvent("onremove", function()
            -- Force remove orb directly first
            if inst._starcaller_light ~= nil and inst._starcaller_light:IsValid() then
                inst._starcaller_light:Remove()
            end
            inst._starcaller_light = nil
            inst._starcaller_active = false
            -- Then call StopStarCaller for any additional cleanup
            StopStarCaller(inst)
            CleanupStarcallerOrbs(inst, 20)
            -- Clean up celestial and shadow FX
            if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                inst._aura_fx:Remove()
                inst._aura_fx = nil
            end
            if inst._orbit_fx ~= nil and inst._orbit_fx:IsValid() then
                inst._orbit_fx:Remove()
                inst._orbit_fx = nil
            end
            if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                inst._shadow_fx:Remove()
                inst._shadow_fx = nil
            end
        end)

        -- TEMPEST CALL MK.II: Auto lightning strike during rain combat for overcharge
        -- Automatically triggers when attacking in rain (no manual activation needed)
        inst._tempest_cooldown = false
        
        -- Auto-lightning attraction during rain (lightning rod behavior)
        inst:AddTag("lightningrod")
        inst:ListenForEvent("lightningstrike", function(inst, data)
            -- Only overcharge if deployed and rain is active
            if not inst.components.inventoryitem and TheWorld.state.israining then
                if not inst._overcharge then
                    ApplyOvercharge(inst)
                    inst._overchargetask = inst:DoTaskInTime(60, RemoveOvercharge)
                end
            end
        end)
        


        -- Repair system (verify inherited)
        if inst.components.engieworkable == nil then
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
        end

        -- CELESTIAL POSSESSION: "Brightshade Bomb" + Cor pulsante
        inst._shadow_fx = nil
        
        -- Affinity pulse (shared module)
        AffinityPulse.Setup(inst, GetOwner)

        -- CELESTIAL POSSESSION: Brightshade Projectile - ataque especial a cada 15 segundos
        -- Ataque normal de raio NÃO tem dano planar - só o ataque especial celeste tem
        inst._special_attack_ready = true
        inst._fossil_snare_ready = true
        inst:ListenForEvent("onattackother", function(inst, data)
            -- AUTO TEMPEST CALL: During combat in rain, automatically call lightning on self
            -- This triggers overcharge automatically when fighting in rain
            if TheWorld.state.israining and inst.on ~= false then
                if not inst._tempest_cooldown and not inst.components.inventoryitem then
                    inst._tempest_cooldown = true
                    
                    local x, y, z = inst.Transform:GetWorldPosition()
                    
                    -- Call lightning on self (auto overcharge)
                    TheWorld:PushEvent("ms_sendlightningstrike", Vector3(x, y, z))
                    
                    -- Reset cooldown after 60 seconds
                    inst:DoTaskInTime(60, function() 
                        inst._tempest_cooldown = false 
                    end)
                end
            end
            
            -- CELESTIAL POSSESSION: Brightshade projectile (day + celestial only, MK3)
            if inst.prefab == "williamballistic3" and TheWorld.state.isday and OwnerHasCelestial(inst) and inst.on ~= false then
                if data and data.target and data.target:IsValid() then
                    -- Só ativa se estiver pronto (cooldown de 15 segundos)
                    if inst._special_attack_ready then
                        inst._special_attack_ready = false
                        
                        local x, y, z = inst.Transform:GetWorldPosition()
                        local target = data.target
                        
                        -- Spawn projétil do staff_lunarplant (dano planar)
                        local projectile = SpawnPrefab("brilliance_projectile_fx")
                        if projectile then
                            -- Adicionar componente weapon com dano planar reduzido (balanceado)
                            if projectile.components.weapon == nil then
                                projectile:AddComponent("weapon")
                            end
                            projectile.components.weapon:SetDamage((TUNING.WILLIAM_BALLISTIC_DAMAGE or 17) * 0.6)
                            
                            -- Configurar posição inicial (centro do bot)
                            projectile.Transform:SetPosition(x, y + 1, z)
                            
                            -- Lançar projétil no alvo
                            if projectile.components.projectile then
                                projectile.components.projectile:Throw(inst, target, inst)
                            end
                            
                            -- Efeito visual de lançamento
                            local launch_fx = SpawnPrefab("electricchargedfx")
                            if launch_fx then
                                launch_fx.Transform:SetPosition(x, y + 1, z)
                            end
                        end
                        
                        -- Reset cooldown após 15 segundos
                        inst:DoTaskInTime(15, function() inst._special_attack_ready = true end)
                    end
                end
            end
            
            -- SHADOW POSSESSION: Fuelweaver Snare
            -- Triggers on attack during dusk with shadow affinity. Cooldown: 15s real time. (MK3 only)
            if inst.prefab == "williamballistic3" and TheWorld.state.isdusk and OwnerHasShadow(inst) and inst.on ~= false then
                if data and data.target and data.target:IsValid() then
                    if not inst._fossil_snare_ready then return end
                    inst._fossil_snare_ready = false
                    inst:DoTaskInTime(15, function() inst._fossil_snare_ready = true end)

                    local bx, by, bz = inst.Transform:GetWorldPosition()

                    -- Build target list: prioritize combat target, then nearby hostiles
                    local SNARE_NO_TAGS = { "flying", "ghost", "playerghost", "player", "companion", "willminion", "fossil", "shadow", "shadowminion", "INLIMBO", "smallcreature" }
                    local valid_targets = {}

                    -- Priority 1: current combat target of the bot
                    local primary = inst.components.combat and inst.components.combat.target
                    if primary and primary:IsValid()
                        and primary.components.health and not primary.components.health:IsDead()
                        and not primary:HasTag("player") and not primary:HasTag("companion") and not primary:HasTag("willminion") then
                        table.insert(valid_targets, primary)
                    end

                    -- Priority 2: targets being attacked by or attacking players/willminions nearby
                    if #valid_targets < 3 then
                        local ents = TheSim:FindEntities(bx, by, bz, 15, { "_combat" }, SNARE_NO_TAGS)
                        for _, ent in ipairs(ents) do
                            if ent ~= inst and ent ~= primary and ent:IsValid()
                                and ent.components.health and not ent.components.health:IsDead()
                                and ent.components.combat ~= nil
                                and (ent:HasTag("hostile") or ent:HasTag("monster")
                                    or (ent.components.combat.target ~= nil
                                        and (ent.components.combat.target:HasTag("player")
                                            or ent.components.combat.target:HasTag("willminion")))) then
                                table.insert(valid_targets, ent)
                                if #valid_targets >= 3 then break end
                            end
                        end
                    end

                    if #valid_targets == 0 then
                        -- No targets, refund cooldown
                        inst._fossil_snare_ready = true
                        return
                    end

                    -- Cast FX and sounds (mirrors vanilla snare state timeline)
                    if inst.SoundEmitter then
                        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/attack1_pbaoe_pre")
                    end
                    local aura = SpawnPrefab("shadow_puff_large_front")
                    if aura then
                        aura.Transform:SetPosition(bx, by + 0.5, bz)
                        aura.Transform:SetScale(2.0, 2.0, 2.0)
                        if aura.SoundEmitter then aura.SoundEmitter:KillAllSounds() end
                        aura:DoTaskInTime(2, aura.Remove)
                    end
                    ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, .7, inst, 30)
                    inst.components.combat:DoAreaAttack(inst, 3.5, nil, nil, nil,
                        { "INLIMBO", "notarget", "invisible", "noattack", "flight", "playerghost", "shadow", "shadowchesspiece", "shadowcreature" })

                    -- Spawn fossilspike cage around each target (vanilla SpawnSnare logic)
                    local SNARE_TIME     = TUNING.STALKER_SNARE_TIME     * 0.7
                    local SNARE_VARIANCE = TUNING.STALKER_SNARE_TIME_VARIANCE * 0.7
                    local map = TheWorld.Map
                    local snare_count = 0

                    local function SpawnSnareForTarget(target)
                        if not target:IsValid() then return false end
                        local tx, _, tz = target.Transform:GetWorldPosition()
                        -- Avoid overlapping with existing cages
                        local SNAREOVERLAP_TAGS = { "fossilspike", "groundspike" }
                        if #TheSim:FindEntities(tx, 0, tz, target:GetPhysicsRadius(0) + 3, SNAREOVERLAP_TAGS) > 0 then
                            return false
                        end
                        local islarge = target:HasTag("largecreature")
                        local r = target:GetPhysicsRadius(0) + (islarge and 1.5 or .5)
                        local num = islarge and 12 or 6
                        local vars = { 1,2,3,4,5,6,7 }
                        local used, queued = {}, {}
                        local placed = 0
                        local dtheta = TWOPI / num
                        local delaytoggle = 0
                        for theta = math.random() * dtheta, TWOPI, dtheta do
                            local x1 = tx + r * math.cos(theta)
                            local z1 = tz + r * math.sin(theta)
                            if map:IsPassableAtPoint(x1, 0, z1) and not map:IsPointNearHole(Vector3(x1, 0, z1)) then
                                local spike = SpawnPrefab("fossilspike")
                                spike.Transform:SetPosition(x1, 0, z1)
                                local delay = delaytoggle == 0 and 0 or .2 + delaytoggle * math.random() * .2
                                delaytoggle = delaytoggle == 1 and -1 or 1
                                local duration = GetRandomWithVariance(SNARE_TIME, SNARE_VARIANCE)
                                local variation = table.remove(vars, math.random(#vars))
                                table.insert(used, variation)
                                if #used > 3 then table.insert(queued, table.remove(used, 1)) end
                                if #vars <= 0 then vars, queued = queued, {} end
                                spike:RestartSpike(delay, duration, variation)
                                placed = placed + 1
                            end
                        end
                        if placed > 0 then
                            -- blinkfocus_marker lets controllers teleport out (vanilla behaviour)
                            local marker = SpawnPrefab("blinkfocus_marker")
                            if marker then
                                marker.Transform:SetPosition(tx, 0, tz)
                                marker:MakeTemporary(SNARE_TIME + SNARE_VARIANCE + 1)
                                marker:SetMaxRange(r + 4)
                            end
                            target:PushEvent("snared", { attacker = inst })
                            return true
                        end
                        return false
                    end

                    for _, target in ipairs(valid_targets) do
                        if SpawnSnareForTarget(target) then
                            snare_count = snare_count + 1
                        end
                    end

                    inst:DoTaskInTime(0.5, function()
                        if inst.SoundEmitter then
                            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/attack1_pbaoe")
                        end
                    end)
                end
            end

        end)
        
        -- Save/load for ballistic2
        local _OnSave = inst.OnSave
        local _OnLoad = inst.OnLoad

        local function OnSaveBallistic2(inst, data)
            -- CRITICAL: Disable Star Caller before saving to ensure orb is removed
            if inst._starcaller_active then
                StopStarCaller(inst)
                CleanupStarcallerOrbs(inst, 20)
            end
            if _OnSave ~= nil then
                _OnSave(inst, data)
            end
            if inst.components.follower ~= nil and inst.components.follower:GetLeader() ~= nil then
                data.leader = inst.components.follower:GetLeader().GUID
            end
            data.overcharge = inst._overcharge
            data.upgradelevel = inst.upgradelevel or 0
            data.starcaller = false  -- Always save as disabled
            if inst.components.fueled ~= nil then
                data.currentfuel = inst.components.fueled.currentfuel
            end
        end

        local function OnLoadBallistic2(inst, data)
            if _OnLoad ~= nil then
                _OnLoad(inst, data)
            end
            -- Clean up any orphaned orbs from previous session
            CleanupStarcallerOrbs(inst, 20)
            -- Also clean up any tracked orb reference
            if inst._starcaller_light ~= nil and inst._starcaller_light:IsValid() then
                inst._starcaller_light:Remove()
            end
            inst._starcaller_light = nil
            inst._starcaller_active = false
            -- Only restore if save data says it was active
            if data ~= nil and data.starcaller == true then
                inst:DoTaskInTime(0.1, function()
                    StartStarCaller(inst)
                end)
            end
            if data ~= nil and data.leader ~= nil then
                inst:DoTaskInTime(0, function()
                    local leader = Ents[data.leader]
                    if leader ~= nil and inst.components.follower ~= nil then
                        inst.components.follower.leader = leader
                    end
                end)
            end
            if data ~= nil and data.overcharge then
                ApplyOvercharge(inst)
                inst._overchargetask = inst:DoTaskInTime(60, RemoveOvercharge)
            end
            if data ~= nil and data.upgradelevel ~= nil then
                inst.upgradelevel = data.upgradelevel
            else
                inst.upgradelevel = inst.upgradelevel or 0
            end
            if data ~= nil and data.currentfuel ~= nil and inst.components.fueled ~= nil then
                inst.components.fueled.currentfuel = data.currentfuel
            end
        end

        inst.OnSave = OnSaveBallistic2
        inst.OnLoad = OnLoadBallistic2

        -- PERMITIR PEGAR DE VOLTA COM LEFT-CLICK (haunt)
        MakeHauntableWork(inst)

        -- DESATIVAR STAR CALLER ao pegar de volta (haunt/right-click unploy)
        -- Isso garante que o orbe seja removido antes do unploy
        local old_OnHaunt = inst.components.hauntable.onhaunt
        inst.components.hauntable:SetOnHauntFn(function(inst, haunter)
            -- Se orbe ativo, desativa primeiro
            if inst._starcaller_active then
                StopStarCaller(inst)
                if inst.components.talker then
                    inst.components.talker:Say("Star Caller OFF - Unploying...")
                end
            end
            -- Continua com o unploy normal (volta para inventário)
            if old_OnHaunt then
                return old_OnHaunt(inst, haunter)
            end
            return true
        end)

        return inst
    end

-- BALLISTIC BOT MK.III: Active Energy Orb
    local function active3(inst)
        local inst = active2(inst)

        inst:AddTag("_named")
        inst:AddTag("ballistic_upgraded_mk3")

        -- Golden tint
        inst.AnimState:SetMultColour(1, 0.9, 0.6, 1)
        -- Slightly larger
        inst.Transform:SetScale(1.1, 1.1, 1.1)

        if not TheWorld.ismastersim then
            return inst
        end

        -- Increase stats
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BALLISTIC_HEALTH + 600)
        inst.components.health:DoDelta(600)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BALLISTIC_DAMAGE + 15)

        -- Named status display
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
        local function UpdateBallistic3Name(inst)
            local base = "Ballistic Bot Mk.III"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local oc = inst._overcharge and "OVERCHARGED" or ""
            local sc = inst._starcaller_active and "STAR CALLER ON" or ""
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp
            if oc ~= "" then name_str = name_str .. " | " .. oc end
            if sc ~= "" then name_str = name_str .. " | " .. sc end
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateBallistic3Name(inst)
        local task = inst:DoPeriodicTask(2, UpdateBallistic3Name)
        table.insert(inst._periodic_name_tasks, task)

        inst:AddTag("ballistic_mk2")  -- Tag for left-click Star Caller toggle (agora no MK3)
        
        -- Initial cleanup: remove any orphaned orbs near this bot
        inst:DoTaskInTime(0, function()
            local x, y, z = inst.Transform:GetWorldPosition()
            local nearby = TheSim:FindEntities(x, y, z, 2, {"stafflight"})
            for _, ent in ipairs(nearby) do
                if ent._parent_bot == nil or ent._parent_bot == inst then
                    -- print("[DEBUG] Initial cleanup: removing orphaned orb")
                    ent:Remove()
                end
            end
        end)

        -- Listen for world save event to disable Star Caller before exit
        -- Auto-disable Star Caller on world save to prevent orb persistence
        inst:ListenForEvent("ms_save", function()
            if inst._starcaller_active then
                StopStarCaller(inst)
                CleanupStarcallerOrbs(inst, 20)
            end
        end, TheWorld)

        -- Clean up starcaller and affinity FX on remove
        inst:ListenForEvent("onremove", function()
            -- Force remove orb directly first
            if inst._starcaller_light ~= nil and inst._starcaller_light:IsValid() then
                inst._starcaller_light:Remove()
            end
            inst._starcaller_light = nil
            inst._starcaller_active = false
            -- Then call StopStarCaller for any additional cleanup
            StopStarCaller(inst)
            CleanupStarcallerOrbs(inst, 20)
            -- Clean up celestial and shadow FX
            if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                inst._aura_fx:Remove()
                inst._aura_fx = nil
            end
            if inst._orbit_fx ~= nil and inst._orbit_fx:IsValid() then
                inst._orbit_fx:Remove()
                inst._orbit_fx = nil
            end
            if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                inst._shadow_fx:Remove()
                inst._shadow_fx = nil
            end
        end)

        -- CLIQUE ESQUERDO: Toggle Star Caller via custom action (ativar/desativar orbe)
        -- CLIQUE DIREITO: Unpack/Recolher (via portablewillybot - já configurado automaticamente)
        -- REMOVIDO: activatable component que conflitava com RMB Pack Up
        inst:ListenForEvent("starcaller_toggle_request", function(inst, doer)
            ToggleStarCaller(inst, doer)
        end)

        -- Listen for stop_starcaller event from OnDismantle
        inst:ListenForEvent("stop_starcaller", function(inst)
            -- print("[DEBUG] stop_starcaller event received")
            StopStarCaller(inst)
        end)

        -- Repair system for MK3
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
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- Repair
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
                if TheWorld.state.isdusk and shadow then
                    if inst2._shadow_clone == nil or not inst2._shadow_clone:IsValid() then
                        inst2._shadow_clone = SpawnShadowClone(inst2)
                    end
                end
            end)
        end

        return inst
    end

-- EMPTY ballistic



local function ondeploy(inst, pt, deployer)
	if not inst.components.fueled:IsEmpty() then
	maketurret(inst, pt, false)
	else
        inst.Physics:Teleport(pt.x, 0, pt.z)
	end
	end

    local function empty(inst)
        local inst = fn(inst)

    inst.AnimState:SetBank("spider_hider")
    inst.AnimState:SetBuild("william_ballistic")
        inst.AnimState:PlayAnimation("hide_loop", true)
    inst.Transform:SetScale(0.9, 0.9, 0.9)

    inst:AddTag("portableitem")

    MakeInventoryPhysics(inst)

        if not TheWorld.ismastersim then
            return inst
        end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/williamballistic_empty.xml"
   inst.components.inventoryitem:ChangeImageName("williamballistic_empty")
    inst.components.inventoryitem:SetSinks(true)

    MakeHauntableLaunch(inst)

    inst:AddComponent("deployable")
    inst.components.deployable.restrictedtag = "william"
    inst.components.deployable.ondeploy = ondeploy

    -- BUG FIX 8: Add fuel listener to enable deployment when refueled
    inst.components.fueled.accepting = true
    inst:ListenForEvent("percentusedchange", function(inst)
        local fuel_pct = inst.components.fueled:GetPercent()
        if fuel_pct > 0 and fuel_pct <= 1 and inst.components.deployable then
            -- Has fuel now, can be deployed
            inst.components.deployable.restrictedtag = "william"
        end
    end)

    -- Save/load empty state (for tracking upgrade level)
    local function OnSaveEmpty(inst, data)
        data.upgradelevel = inst.upgradelevel or 0
        data.was_mk2 = inst.was_mk2
        data.was_mk3 = inst.was_mk3
        if inst.upgradelevel_mk3 ~= nil then
            data.upgradelevel_mk3 = inst.upgradelevel_mk3
        end
    end

    local function OnLoadEmpty(inst, data)
        if data then
            inst.upgradelevel = data.upgradelevel or 0
            inst.was_mk2 = data.was_mk2
            inst.was_mk3 = data.was_mk3
            if data.upgradelevel_mk3 ~= nil then
                inst.upgradelevel_mk3 = data.upgradelevel_mk3
            end
        end
    end

    inst.OnSave = OnSaveEmpty
    inst.OnLoad = OnLoadEmpty

        return inst
    end




local function placer_postinit_fn(inst)

    local placer2 = CreateEntity()

    --[[Non-networked entity]]
    placer2.entity:SetCanSleep(false)
    placer2.persists = false

    placer2.entity:AddTransform()
    placer2.entity:AddAnimState()

    placer2:AddTag("CLASSIFIED")
    placer2:AddTag("NOCLICK")
    placer2:AddTag("placer")

    local s = 0.9 / PLACER_SCALE
    placer2.Transform:SetScale(s, s, s)

    placer2.AnimState:SetBank("spider_hider")
    placer2.AnimState:SetBuild("william_ballistic")
    placer2.AnimState:PlayAnimation("idle")
    placer2.AnimState:SetLightOverride(1)

    placer2.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(placer2)
end

    return Prefab("williamballistic", active, assets, prefabs),
    Prefab("williamballistic3", active3, assets, prefabs),
    Prefab("williamballistic2", active2, assets, prefabs),
    Prefab("williamballistic_empty", empty, assets, prefabs),
    MakePlacer("williamballistic_empty_placer", "firefighter_placement", "firefighter_placement", "idle", true, nil, nil, PLACER_SCALE, nil, nil, placer_postinit_fn)


--------------------------------------------------------------------------
