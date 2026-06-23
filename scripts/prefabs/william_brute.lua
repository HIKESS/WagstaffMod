local prefabs =
{

}

    local assets =
    {
        Asset("ANIM", "anim/william_brute.zip"),
        Asset("ANIM", "anim/william_upgrades.zip"),
        Asset("ANIM", "anim/william_garyhat_swap.zip"),
    Asset("ANIM", "anim/merm_actions.zip"),
    Asset("ANIM", "anim/merm_guard_transformation.zip"),    
    Asset("ANIM", "anim/ds_pig_boat_jump.zip"),
    Asset("ANIM", "anim/ds_pig_basic.zip"),
    Asset("ANIM", "anim/ds_pig_actions.zip"),
    Asset("ANIM", "anim/ds_pig_attacks.zip"),
    }

SetSharedLootTable("brute",
{
    {'cutstone',          1},
    {'transistor',          1},
    {'log',          1},
    {'log',          1},
    {'log',          1},
    {'cutreeds',          1},
    {'cutreeds',          1},
    {'cutreeds',          1},
    {'cutreeds',          1},
})

SetSharedLootTable("brutegadget",
{
    {'williamgadget',          1},
})

local function OnOpen(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
end

local function OnClose(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
end

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

local brain = require "brains/williambrutebrain"
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

local function RememberKnownLocation(inst)
--    inst.components.knownlocations:RememberLocation("home", inst:GetPosition())
end

local function IsTauntable(inst, target)
    return not (target.components.health ~= nil and target.components.health:IsDead())
        and target.components.combat ~= nil
        and not target.components.combat:TargetIs(inst)
        and target.components.combat:CanTarget(inst)
        and  (   target.components.combat:HasTarget() and
                    (   target.components.combat.target:HasTag("player") or
                        (target.components.combat.target:HasTag("companion") and target.components.combat.target.prefab ~= inst.prefab)
                    )
                )
end


local function TauntCreatures(inst)
    if not inst.components.health:IsDead() then
        local x, y, z = inst.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, y, z, 7, { "_combat", "locomotor" }, { "INLIMBO", "player", "companion", "epic", "notaunt", "shadow" })) do
            if IsTauntable(inst, v) then
                v.components.combat:SetTarget(inst)
            end
        end
    end
end

local function OnHammered(inst, worker)
    -- Don't destroy if bot is ON (engieworkable handles upgrade when ON)
    if inst.on == true then
        return
    end

    -- 100% drop do core (williamgadget)
    inst.components.lootdropper:SetLoot({"williamgadget"})
    inst.components.lootdropper:DropLoot()
    -- 50% chance para items bonus
    if math.random() < 0.5 then
        inst.components.lootdropper:SetChanceLootTable({"armorwood", 1})
        inst.components.lootdropper:DropLoot()
    end
        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("metal")
    inst:Remove()
end


local function _ShareTargetFn(dude)
    return dude:HasTag("willminion") and not dude:HasTag("butler")
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
if data.attacker.components.combat ~= nil then
            inst.components.combat:SuggestTarget(data.attacker)
                if not data.attacker:HasTag("william") then
    inst.components.combat:ShareTarget(data.attacker, 15, _ShareTargetFn, 5)
                end
        end
    end
end




local function retargetfn(inst)
        local exclude_tags = { "playerghost", "INLIMBO", "abigail", "playermonster" }
        if inst.components.minigame_spectator ~= nil then
                table.insert(exclude_tags, "player") -- prevent spectators from auto-targeting webber
        end

    local playertargets = {}
    for i, v in ipairs(AllPlayers) do
        if v.components.combat.target ~= nil then
            playertargets[v.components.combat.target] = true
        end
    end

    local oneof_tags = {"monster", "hostile"}

    return not inst:IsInLimbo()
        and FindEntity(
                inst,
                20,
                function(guy)
                    return inst.components.combat:CanTarget(guy) and playertargets[guy] or
                    (guy.components.combat.target ~= nil and (guy.components.combat.target:HasTag("player") or guy.components.combat.target:HasTag("willminion")))
                        --inst.components.combat:CanTarget(guy)
                end,
                { "_combat" }, -- see entityreplica.lua
                exclude_tags
--                oneof_tags
            )
        or nil
end

local function keeptargetfn(inst, target)
    --give up on dead guys, or guys in the dark, or werepigs
    return inst.components.combat:CanTarget(target)
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
    return afflicter ~= nil and afflicter:HasTag("quakedebris")
end

local function CanInteract(inst)
    return not inst.components.fueled:IsEmpty()
end

local function onworked(inst)
        if inst:HasTag("alive") then
        inst.sg:GoToState("hit")
        end
end

local function TurnOff(inst, doer, instant)
    local GLOBAL = _G
    inst.on = false

                if inst._task ~= nil then
                    inst._task:Cancel()
            inst._task = nil
        end
            MakeHauntableWork(inst)
        inst:RemoveTag("scarytoprey")
        inst:RemoveTag("alive")
        inst:RemoveTag("ebuild_wrenchable")  -- Prevent wrench interaction when OFF
        inst:AddTag("notarget")

    -- Remover COMPLETAMENTE o componente container quando desativado (para não aparecer como chest)
    -- Só executa no servidor para evitar problemas com réplica
    if not GLOBAL.TheWorld.ismastersim then return end
    
    if inst:HasTag("container") then
        inst._had_container_tag = true
        inst:RemoveTag("container")
        -- FECHAR O CONTAINER PRIMEIRO para evitar crash (protegido com pcall)
        if inst.components.container then
            local ok, err = pcall(function()
                inst.components.container:Close()
            end)
            if not ok then
            else
            end
        end
        -- REMOVER O COMPONENTE COMPLETAMENTE (isso evita que pareça um baú)
        if inst.components.container then
            local ok, err = pcall(function()
                inst:RemoveComponent("container")
            end)
            if not ok then
            else
            end
        end
    end

    inst.components.fueled:StopConsuming()
        inst.components.combat:SetTarget(nil)
    inst.components.combat:SetRetargetFunction(nil)
    inst.components.combat:SetKeepTargetFunction(nil)
    inst.sg:GoToState("turn_off")
    
    -- When OFF with no fuel: hammering BREAKS the bot (like buster/ballistic behavior)
    -- When OFF with fuel: no workable — WILLYRAISE action handles reactivation
    if inst.components.fueled:IsEmpty() then
        if inst.components.workable == nil then
            inst:AddComponent("workable")
        end
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)
        inst.components.workable:SetOnWorkCallback(onworked)
        -- Add fuel listener: when fuel is added while OFF, remove HAMMER so WILLYRAISE can activate
        inst._fuel_activate_listener = inst:ListenForEvent("percentusedchange", function()
            if inst.on == false and not inst.components.fueled:IsEmpty() then
                if inst.components.workable then
                    inst:RemoveComponent("workable")
                end
                -- WILLYRAISE action will now handle reactivation
                if inst._fuel_activate_listener then
                    inst:RemoveEventCallback("percentusedchange", inst._fuel_activate_listener)
                    inst._fuel_activate_listener = nil
                end
            end
        end)
    else
        -- Has fuel: remove workable so WILLYRAISE "Activate" action is available
        if inst.components.workable then
            inst:RemoveComponent("workable")
        end
    end
end


local function TurnOn(inst, doer, instant)
    -- BUG FIX 4: Check fuel before turning on
    if inst.components.fueled:IsEmpty() or inst.components.fueled:GetPercent() < 0.1 then
        if doer and doer.components.talker then
            doer.components.talker:Say("Need fuel to activate!")
        end
        return false
    end

    inst.on = true

    -- Set leader to whoever turned the bot on, or nearest player if none
    -- Only for MK2+ which have the follower component
    if inst.components.follower ~= nil then
        if doer ~= nil then
            inst.components.follower:SetLeader(doer)
        elseif inst.components.follower:GetLeader() == nil then
            local player = FindClosestPlayerToInst(inst, 20, true)
            if player ~= nil then
                inst.components.follower:SetLeader(player)
            end
        end
    end

    if inst._task == nil then
    inst._taunttask = inst:DoPeriodicTask(2, TauntCreatures, 0)
        end

    MakeHauntablePanic(inst)
        inst:AddTag("scarytoprey")
        inst:AddTag("alive")
        inst:RemoveTag("notarget")

    -- Restaurar tag container quando ativado
    if inst._had_container_tag then
        -- Debug removed
        inst:AddTag("container")
        inst._had_container_tag = nil
        -- RE-ADICIONAR O COMPONENTE CONTAINER
        if not inst.components.container then
            inst:AddComponent("container")
            inst.components.container:WidgetSetup("williambrute3")
            inst.components.container.onopenfn = OnOpen
            inst.components.container.onclosefn = OnClose
            inst.components.container.skipopensnd = true
            inst.components.container.skipclosesnd = true
            -- Debug removed
        end
    end
    
    -- RESTORE: When turning on, remove workable entirely
    -- The WILLYRAISE action (from william_acts.lua) handles right-click deactivation
    -- Remove fuel activate listener since we're turning on
    if inst._fuel_activate_listener then
        inst:RemoveEventCallback("percentusedchange", inst._fuel_activate_listener)
        inst._fuel_activate_listener = nil
    end
    if inst.components.workable then
        inst:RemoveComponent("workable")
    end

    -- Re-add wrenchable tag so wrench works when ON
    inst:AddTag("ebuild_wrenchable")

    inst.components.fueled:StartConsuming()
    -- Debug removed
        inst.components.health:SetInvincible(false)
    inst.components.combat:SetRetargetFunction(2, retargetfn) --Look for leader's target.
    inst.components.combat:SetKeepTargetFunction(keeptargetfn) --Keep attacking while leader is near.

    -- Restart brain so it picks up the new leader state
    inst:SetBrain(brain)

    inst.sg:GoToState("turn_on")
    
    return true
end


local function OnFuelEmpty(inst)
    -- Immediately mark as off to prevent interaction during turn-off animation
    inst.on = false
    inst:AddTag("notarget")
    inst:RemoveTag("scarytoprey")
    inst.components.willyraise:Lower()
end

local function OnAddFuel(inst)
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel")
    if inst.on == false then
        inst.components.willyraise:Rise()
    else
        inst.sg:GoToState("fed")
    end
end

local function LevelUp(inst, amount)
        if inst.level < 3 and amount ~= nil then
        inst.level = inst.level + amount
        if inst.on == true then
        inst.sg:GoToState("upgraded")
        end
end

        if inst.level > 3 then inst.level = 3 end

        inst:DoTaskInTime(0, function()

    local health_percent = inst.components.health:GetPercent()

                inst:AddTag("level"..inst.level)
--            inst.AnimState:OverrideSymbol("swap_hat", "william_upgrades", "swap_brute"..inst.level)

    inst.components.health:StopRegen()
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN+(inst.level*5), TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health:SetAbsorptionAmount(0+inst.level*0.08)
        end)

end

local function onsave(inst, data)
    data.on = inst.on
    data.level = inst.level
    -- Save leader for all versions (MK1 now has follower too)
    if inst.components.follower and inst.components.follower:GetLeader() then
        data.leader_guid = inst.components.follower:GetLeader().GUID
    end
    data.upgradelevel = inst.upgradelevel or 0
end

local function onload(inst, data)
    if data == nil then return end

    inst.on = data.on
    if data.level ~= nil then
        inst.level = data.level
        if inst.level > 0 then inst:DoTaskInTime(0, LevelUp) end
    end

    -- Restore upgradelevel
    if data.upgradelevel ~= nil then
        inst.upgradelevel = data.upgradelevel
    end

    -- Restore leader (MK1 now has follower too)
    if data.leader_guid ~= nil and inst.components.follower ~= nil then
        inst:DoTaskInTime(0, function()
            local leader = Ents[data.leader_guid]
            if leader ~= nil and leader:IsValid() then
                inst.components.follower:SetLeader(leader)
            end
        end)
    end

    inst:DoTaskInTime(0, function()
        if inst.on == true then
            TurnOn(inst, nil, true)
        else
            TurnOff(inst, nil, true)
        end
    end)
end

local function onbuilt(inst, builder)
    inst.components.knownlocations:RememberLocation("home", inst:GetPosition())
    inst.components.willyraise:Rise()
end

local PLACER_SCALE = 1.5

    local function fn(inst)
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        inst.level = 0

        inst.DynamicShadow:SetSize(2, 1.25)
        inst.MiniMapEntity:SetIcon("williambrute.tex")

        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("pigman")
    inst.AnimState:SetBuild("william_brute")
        inst.AnimState:PlayAnimation("sit_idle", true)

    MakeCharacterPhysics(inst, 0.9, .5)
    inst.Transform:SetScale(1.7, 1.7, 1.7)

        inst:AddTag("alive")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("buster")
        inst:AddTag("ebuild_wrenchable")

    inst._task = nil
    inst.on = nil

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

    inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.WILLIAM_BRUTE_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.WILLIAM_BRUTE_WALK_SPEED

        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

    inst:SetStateGraph("SGwilliambrute")

        inst:AddComponent("combat")
    inst.components.combat.hiteffectsymbol = "pig_torso"
    inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BRUTE_ATTACK_PERIOD)
        inst.components.combat:SetRange(TUNING.WILLIAM_BRUTE_ATTACK_RANGE)
    inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BRUTE_DAMAGE)

    MakeMediumBurnableCharacter(inst, "pig_torso")
    MakeMediumFreezableCharacter(inst, "pig_torso")

inst.components.burnable.ignorefuel = true

        inst:ListenForEvent("attacked", OnAttacked)

        inst:AddComponent("willyraise")
    inst.components.willyraise:SetOnRiseFn(TurnOn)
    inst.components.willyraise:SetOnLowerFn(TurnOff)

        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BRUTE_HEALTH)
       -- inst.components.health.nofadeout = true
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health.redirect = nodebrisdmg
                inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("brute")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)

    -- Lightning recharge (refuel, no overcharge)
    inst:ListenForEvent("lightningstrike", function(inst)
        if inst.components.fueled then
            inst.components.fueled:DoDelta(inst.components.fueled.maxfuel * 0.25)
        end
    end)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("fueled")
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled.accepting = true  -- Enable manual fueling (reverted to original)
    inst.components.fueled:InitializeFuelLevel(TUNING.WILLIAM_BRUTE_MAXFUEL)
    inst.components.fueled.bonusmult = 1
    inst.components.fueled:SetDepletedFn(OnFuelEmpty)
    inst.components.fueled:StartConsuming()

    -- Rain damage (like WX-78) when active
    inst:DoPeriodicTask(1, function(inst)
        if TheWorld.state.israining and inst.components.health then
            inst.components.health:DoDelta(-1, false, "wetness")
        end
    end)

        inst:ListenForEvent("levelup", LevelUp)


        inst:SetBrain(brain)

    inst:AddComponent("knownlocations")

    -- Workable for hammer destruction
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

    -- MK1: Add follower component so brute follows player after craft
    inst:AddComponent("follower")
    inst.components.follower:KeepLeaderOnAttacked()
    inst.components.follower.keepdeadleader = true
    inst.components.follower.keepleaderduringminigame = true

    -- Named component for status display
    inst:AddComponent("named")

    --==================================================================================
    -- REINFORCED CHASSIS UPGRADE: Wrench upgrade spawns williambrute2
    -- 75 scraps total, 5 per hit (15 hits). Progress shown in bot name.
    -- Level 2: storage chest, +1500 HP, +10 DMG, follows player, larger size.
    --==================================================================================
    inst.upgradelevel = 0

    local function UpdateBruteName(inst)
        if inst.prefab == "williambrute2" or inst.prefab == "williambrute3" then return end
        local base = "Brute Bot"
        local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
        local hp = math.floor(inst.components.health.currenthealth)
        local maxhp = math.floor(inst.components.health.maxhealth)
        local upgrade_str = (inst.upgradelevel and inst.upgradelevel > 0) and (" | Upgrade: " .. inst.upgradelevel .. " / 75") or ""
        local displayname = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
        inst.components.named:SetName(displayname)
        inst.name = displayname
        inst.GetDisplayName = function() return displayname end
    end
    UpdateBruteName(inst)
    inst:DoPeriodicTask(2, UpdateBruteName)

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
        if inst.on == false then return end
        print("[DEBUG] ==============================================")
        print("[DEBUG] OnFinishCallback chamado para Brute Bot")
        print("[DEBUG] inst.prefab:", inst.prefab)
        print("[DEBUG] worker.prefab:", worker.prefab)
        print("[DEBUG] worker.name:", worker.name)
        print("[DEBUG] inst.upgradelevel:", inst.upgradelevel)
        print("[DEBUG] inst.upgradelevel_mk3:", inst.upgradelevel_mk3)
        
        inst.components.engieworkable:SetWorkLeft(1)
        -- Use wrench durability
        local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        print("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
        if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
            wrench.components.finiteuses:Use(1)
        end

        -- Level 2 repair: wrench + scrap restores HP
        if inst.prefab == "williambrute2" or inst:HasTag("brute_upgraded") then
            print("[DEBUG] Brute é MK2 ou superior - modo repair")
            if inst.components.health and inst.components.health.currenthealth >= inst.components.health.maxhealth then
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
            return
        end

        print("[DEBUG] Brute é MK1 - verificando upgrade para MK2")
        print("[DEBUG] Chamando WagstaffHasSkill para wagstaff_brute_evolve")
        print("[DEBUG] worker tem skilltreeupdater?", worker.components.skilltreeupdater ~= nil)
        local has_skill = _G.WagstaffHasSkill(worker, "wagstaff_brute_evolve")
        print("[DEBUG] Resultado de WagstaffHasSkill:", has_skill)
        if not has_skill then
            print("[DEBUG] Skill NÃO encontrada! Abortando upgrade.")
            if worker.components.talker then
                worker.components.talker:Say("Requires Brute Bot MK. II skill!\n(Activate it in the skill tree!)")
            end
            return
        end
        print("[DEBUG] Skill encontrada! Prosseguindo com upgrade...")

        -- Upgrade: scrap metal per wrench hit (5 per hit, 75 total for Mk.II)
        local function IsScrap(item)
            return item.prefab == "scrap"
        end
        local scrapstack = worker.components.inventory:FindItem(IsScrap)
        local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
        if upgrade_cost > 0 and scrapstack == nil then
            if worker.components.talker then
                worker.components.talker:Say("Need Scrap Metal!")
            end
            return
        end
        if upgrade_cost > 0 then
            worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
        end
        inst.upgradelevel = inst.upgradelevel + 5
        UpdateBruteName(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

        if inst.upgradelevel >= 75 then
            inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
            if worker.components.talker then
                worker.components.talker:Say("Reinforced Chassis complete!")
            end

            -- Spawn upgraded bot
            local pt = inst:GetPosition()
            local newbot = SpawnPrefab("williambrute2")
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
                -- Transfer level
                newbot.level = inst.level

                -- Transfer ON state and turn on automatically if original was on
                newbot.on = inst.on
                if inst.on == true and newbot.components.willyraise ~= nil then
                    newbot.components.willyraise:Rise(worker)
                end

                -- Set leader and reinit brain for MK2+
                if newbot.components.follower ~= nil then
                    newbot.components.follower:SetLeader(worker)
                    newbot:SetBrain(brain)
                end

                -- Spawn FX (craft-like effect)
                local fx = SpawnPrefab("small_puff")
                fx.Transform:SetPosition(pt.x, pt.y, pt.z)
                inst.SoundEmitter:PlaySound("dontstarve/common/craftable")
            end

            inst:Remove()
        end
    end)

    -- Save/load upgrade progress is now handled by base onsave/onload

    inst.OnSave = onsave
    inst.OnLoad = onload

        return inst
    end


    local function gary(inst)
        local inst = fn()

    inst:SetPrefabNameOverride("williambrute")
            inst.AnimState:OverrideSymbol("swap_hat", "william_garyhat_swap", "swap_hat")

    inst:AddTag("_named")

        if not TheWorld.ismastersim then
            return inst
        end
    inst:RemoveTag("_named")
    if not inst.components.named then
        inst:AddComponent("named")
    end
    local ok, err = pcall(function() inst.components.named:SetName("Gary") end)
    if not ok then
        inst.name = "Gary"
        inst.GetDisplayName = function() return "Gary" end
    end
        return inst
    end

    --==================================================================================
    -- BRUTE BOT v2: Upgraded version with storage chest, +1500 HP, +10 DMG,
    -- follows player, larger size. Spawned by wrench upgrade on original brute.
    --==================================================================================
    local function fn2(inst)
        local inst = fn()

        inst.Transform:SetScale(2.3, 2.3, 2.3)

        -- Tintura cinza acinzentada para diferenciar nível 2
        inst.AnimState:SetMultColour(0.8, 0.8, 0.85, 1)

        inst:AddTag("brute_upgraded")

        if not TheWorld.ismastersim then
            return inst
        end

        -- MK2: Follower component already added by fn() - no need to add again
        -- Just ensure leader is set if upgrading from MK1
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
                inst.components.follower:SetLeader(closest)
            end
        end

        -- Override base health and damage
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BRUTE_HEALTH + 1000)
        inst.components.health:DoDelta(1000)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BRUTE_DAMAGE + 10)

        -- CELESTIAL POSSESSION: "Lunar Guardian" - Aura fogo AZUL + Enlightenment + Cor pulsante
        inst._celestial_light = nil
        inst._aura_fx = nil
        inst._lunar_aura = nil
        inst._shadow_fx = nil
        inst._celestial_pulse = 0
        
        -- Affinity pulse (shared module, MK3 only)

        inst:DoPeriodicTask(3, function()
            if inst.prefab == "williambrute3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Add planar immunity
                inst:AddTag("planardefense")
                
                -- Light própria azul lunar (suave)
                if inst._celestial_light == nil then
                    inst.entity:AddLight()
                    inst._celestial_light = true
                end
                if inst.Light then
                    inst.Light:SetRadius(2.5)
                    inst.Light:SetIntensity(0.4)
                    inst.Light:SetFalloff(0.8)
                    inst.Light:SetColour(0.4, 0.7, 1) -- Azul lunar
                    inst.Light:Enable(true)
                end
                
                -- AURA BOUNCER - só quando ativo (nil = inicialmente ativo)
                if inst.on ~= false and (inst._aura_fx == nil or not inst._aura_fx:IsValid()) then
                    inst._aura_fx = SpawnPrefab("bot_aura_bouncer")
                    if inst._aura_fx then
                        inst._aura_fx._parent = inst
                    end
                end
                
                -- Aura enlightenment da Ilha Lunar (partículas ao redor)
                if inst._lunar_aura == nil or not inst._lunar_aura:IsValid() then
                    inst._lunar_aura = SpawnPrefab("lunarhail")
                    if inst._lunar_aura then
                        inst._lunar_aura.entity:SetParent(inst.entity)
                        inst._lunar_aura.Transform:SetPosition(0, 0, 0)
                        inst._lunar_aura.Transform:SetScale(0.6, 0.6, 0.6)
                    end
                end
                
                
                -- Remove shadow FX
                if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                    inst._shadow_fx:Remove()
                    inst._shadow_fx = nil
                end
            else
                -- Remove effects
                inst:RemoveTag("planardefense")
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                    inst._aura_fx:Remove()
                    inst._aura_fx = nil
                end
                if inst._lunar_aura ~= nil and inst._lunar_aura:IsValid() then
                    inst._lunar_aura:Remove()
                    inst._lunar_aura = nil
                end
            end
            
            -- SHADOW POSSESSION: "Void Juggernaut" - nightmare fuel particles (MK3 only)
            if inst.prefab == "williambrute3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                if inst._shadow_fx == nil or not inst._shadow_fx:IsValid() then
                    inst._shadow_fx = SpawnPrefab("shadow_puff_large_front")
                    if inst._shadow_fx then
                        inst._shadow_fx.entity:SetParent(inst.entity)
                        inst._shadow_fx.Transform:SetPosition(0, 0, 0)
                        inst._shadow_fx.Transform:SetScale(1.0, 1.0, 1.0)
                        if inst._shadow_fx.SoundEmitter then
                            inst._shadow_fx.SoundEmitter:KillAllSounds()
                        end
                    end
                end
                -- Remove celestial FX
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                if inst._lunar_fire ~= nil and inst._lunar_fire:IsValid() then
                    inst._lunar_fire:Remove()
                    inst._lunar_fire = nil
                end
                if inst._lunar_aura ~= nil and inst._lunar_aura:IsValid() then
                    inst._lunar_aura:Remove()
                    inst._lunar_aura = nil
                end
            else
                if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                    inst._shadow_fx:Remove()
                    inst._shadow_fx = nil
                end
            end
        end)
        
        -- Fire counter-attack: deal 30 fire damage to the attacker only when hit
        local old_OnAttacked = OnAttacked
        local function OnAttackedMK2(inst, data)
            old_OnAttacked(inst, data)
            if inst.prefab == "williambrute3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Only counter-attack the specific enemy that hit us
                if data and data.attacker and data.attacker:IsValid() then
                    local attacker = data.attacker
                    if attacker.components.health and not attacker.components.health:IsDead() then
                        -- v2.0.15: 30 -> 50 fire damage (was too weak vs Dispenser MK3 auras)
                        attacker.components.health:DoDelta(-50, false, "fire")
                        -- Celestial FX on attacker (azul)
                        local fx = SpawnPrefab("electrichitsparks")
                        if fx then
                            fx.Transform:SetPosition(attacker.Transform:GetWorldPosition())
                            -- Pintar de azul celestial (se tiver AnimState)
                            if fx.AnimState then
                                fx.AnimState:SetMultColour(0.3, 0.6, 1, 1)
                                fx.AnimState:SetAddColour(0.2, 0.3, 0.5, 0)
                            end
                        end
                    end
                end
            end

            -- SHADOW POSSESSION: Void Weaken - retaliatory AOE damage reduction + shadow damage on hit (MK3 only)
            if inst.prefab == "williambrute3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                -- Shadow damage to the attacker only (no cooldown) - mirrors celestial counter-attack
                if data and data.attacker and data.attacker:IsValid() then
                    local attacker = data.attacker
                    if attacker.components.health and not attacker.components.health:IsDead() then
                        -- v2.0.15: 15 -> 25 shadow damage (proportional to celestial 30->50 buff)
                        attacker.components.health:DoDelta(-25, false, "shadow")
                        -- Shadow FX on attacker
                        local fx = SpawnPrefab("shadow_puff")
                        if fx then
                            fx.Transform:SetPosition(attacker.Transform:GetWorldPosition())
                        end
                    end
                end

                local x, y, z = inst.Transform:GetWorldPosition()
                local do_debuff = not inst._void_pulse_cooldown

                if do_debuff then
                    inst._void_pulse_cooldown = true
                    inst:DoTaskInTime(8, function() inst._void_pulse_cooldown = nil end)

                    -- Central void burst FX at Bouncer: massive shadow_puff_large_front explosion
                    if inst.SoundEmitter then
                        inst.SoundEmitter:PlaySound("dontstarve/common/nightmarecreature_spawn")
                    end
                    local burst_fx = SpawnPrefab("shadow_puff_large_front")
                    if burst_fx then
                        burst_fx.Transform:SetPosition(x, y + 0.5, z)
                        burst_fx.Transform:SetScale(6.0, 6.0, 6.0)
                        burst_fx:DoTaskInTime(1.5, function()
                            if burst_fx:IsValid() then burst_fx:Remove() end
                        end)
                    end

                    -- Find and weaken enemies within radius 6
                    local ents = TheSim:FindEntities(x, y, z, 6, nil, {"INLIMBO", "player", "companion", "willminion", "epic", "miniboss", "deer"})
                    for _, ent in ipairs(ents) do
                        if ent ~= inst and ent ~= data.attacker and ent:IsValid() and ent.components.combat then
                            -- Reduce damage dealt by 50%
                            if ent.components.combat.externaldamagemultipliers then
                                ent.components.combat.externaldamagemultipliers:SetModifier(inst, 0.5)
                                ent:DoTaskInTime(4, function()
                                    if ent:IsValid() and ent.components.combat and ent.components.combat.externaldamagemultipliers then
                                        ent.components.combat.externaldamagemultipliers:RemoveModifier(inst)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
        inst:ListenForEvent("attacked", OnAttackedMK2)

        -- SHADOW POSSESSION: Planar immunity + shadow creatures target priority during dusk
        inst:DoPeriodicTask(5, function()
            if TheWorld.state.isdusk and OwnerHasShadow(inst) then
                -- Add planar immunity
                inst:AddTag("planardefense")
                -- Add groundpound immune
                inst:AddTag("groundpoundimmune")
                -- Attract shadow creatures as absolute priority target
                inst:AddTag("shadowlure")
                inst:AddTag("shadowcreature_target")
            else
                -- Remove effects when not night
                inst:RemoveTag("planardefense")
                inst:RemoveTag("groundpoundimmune")
                inst:RemoveTag("shadowlure")
                inst:RemoveTag("shadowcreature_target")
            end
        end)

        -- Named with status (upgrade progress for MK3)
        inst.upgradelevel_mk3 = 0
        local function UpdateBrute2Name(inst)
            if inst.prefab == "williambrute3" then return end
            local base = "Brute Bot Mk.II"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local upgrade_str = (inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0) and (" | Upgrade: " .. inst.upgradelevel_mk3 .. " / 90") or ""
            local displayname = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
            inst.components.named:SetName(displayname)
            inst.name = displayname
            inst.GetDisplayName = function() return displayname end
        end
        UpdateBrute2Name(inst)
        inst:DoPeriodicTask(2, UpdateBrute2Name)

        -- Mk.II: Repair + Upgrade in one engieworkable
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
            if inst.on == false then return end
            print("[DEBUG] ==============================================")
            print("[DEBUG] OnFinishCallback chamado para Brute Bot MK2")
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
            print("[DEBUG] Verificando skill wagstaff_brute_mk3...")
            local has_mk3_skill = _G.WagstaffHasSkill(worker, "wagstaff_brute_mk3")
            print("[DEBUG] Tem skill MK3?", has_mk3_skill)
            print("[DEBUG] upgradelevel_mk3 atual:", inst.upgradelevel_mk3)
            if not has_mk3_skill then
                if worker.components.talker then
                    worker.components.talker:Say("Requires Brute Bot MK.III skill!\n(Activate it in the skill tree!)")
                end
                return
            end
            if inst.upgradelevel_mk3 < 90 then
                print("[DEBUG] Tentando upgrade para MK3...")
                -- Try to upgrade
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
                if upgrade_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal!")
                    end
                    return
                end
                if upgrade_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
                end
                inst.upgradelevel_mk3 = inst.upgradelevel_mk3 + 5
                UpdateBrute2Name(inst)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

                if inst.upgradelevel_mk3 >= 90 then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    if worker.components.talker then
                        worker.components.talker:Say("Mk.III Complete!")
                    end

                    -- Spawn upgraded bot
                    local pt = inst:GetPosition()
                    local newbot = SpawnPrefab("williambrute3")
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
                        -- Transfer level
                        newbot.level = inst.level

                        -- Transfer ON state and turn on automatically if original was on
                        newbot.on = inst.on
                        if inst.on == true and newbot.components.willyraise ~= nil then
                            newbot.components.willyraise:Rise(worker)
                        end

                        -- Set leader and reinit brain
                        if newbot.components.follower ~= nil then
                            newbot.components.follower.leader = worker
                            newbot:SetBrain(brain)
                        end

                        -- Spawn FX (craft-like effect)
                        local fx = SpawnPrefab("small_puff")
                        fx.Transform:SetPosition(pt.x, pt.y, pt.z)
                        inst.SoundEmitter:PlaySound("dontstarve/common/craftable")
                    end

                    inst:Remove()
                end
                return
            end

            -- If not upgrading, try repair
            if inst.components.health and inst.components.health.currenthealth >= inst.components.health.maxhealth then
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

        -- Workable for hammer deactivation (same as MK1)
        if inst.components.workable == nil then
            inst:AddComponent("workable")
        end
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)
        inst.components.workable:SetOnWorkCallback(onworked)

        -- Save/load for brute2 upgrade progress
        local old_OnSaveBrute2 = inst.OnSave
        local function OnSaveBrute2WithUpgrade(inst, data)
            if old_OnSaveBrute2 then
                old_OnSaveBrute2(inst, data)
            end
            if inst.on ~= nil then
                data.on = inst.on
            end
            if inst.level ~= nil then
                data.level = inst.level
            end
            data.upgradelevel_mk3 = inst.upgradelevel_mk3
        end
        local old_OnLoadBrute2 = inst.OnLoad
        local function OnLoadBrute2WithUpgrade(inst, data)
            if old_OnLoadBrute2 then
                old_OnLoadBrute2(inst, data)
            end
            if data then
                inst.upgradelevel_mk3 = data.upgradelevel_mk3 or 0
                UpdateBrute2Name(inst)
            end
            if data ~= nil and data.on ~= nil then
                inst.on = data.on
            end
            if data ~= nil and data.level ~= nil then
                inst.level = data.level
                if inst.level > 0 then inst:DoTaskInTime(0, LevelUp) end
            end
            
            if inst.on == false and inst:HasTag("container") then
                inst._had_container_tag = true
                inst:RemoveTag("container")
                if inst.components.container then
                    inst:RemoveComponent("container")
                end
            end
            
            if inst.on == false then
                -- Remove ebuild_wrenchable tag to prevent wrench on deactivated bot
                inst:RemoveTag("ebuild_wrenchable")
                -- Same as TurnOff: HAMMER only when no fuel, otherwise WILLYRAISE handles it
                if inst.components.fueled:IsEmpty() then
                    if inst.components.workable == nil then
                        inst:AddComponent("workable")
                    end
                    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
                    inst.components.workable:SetWorkLeft(4)
                    inst.components.workable:SetOnFinishCallback(OnHammered)
                    inst.components.workable:SetOnWorkCallback(onworked)
                    inst._fuel_activate_listener = inst:ListenForEvent("percentusedchange", function()
                        if inst.on == false and not inst.components.fueled:IsEmpty() then
                            if inst.components.workable then
                                inst:RemoveComponent("workable")
                            end
                            if inst._fuel_activate_listener then
                                inst:RemoveEventCallback("percentusedchange", inst._fuel_activate_listener)
                                inst._fuel_activate_listener = nil
                            end
                        end
                    end)
                else
                    if inst.components.workable then
                        inst:RemoveComponent("workable")
                    end
                end
            end
            -- NOTE: TurnOn/TurnOff is already called by base onload (via DoTaskInTime(0)).
            -- We do NOT duplicate it here to avoid double brain creation and SG interruption
            -- which caused ~1 min follow delay on reload.
        end
        inst.OnSave = OnSaveBrute2WithUpgrade
        inst.OnLoad = OnLoadBrute2WithUpgrade

        -- Clean up celestial FX on removal
        inst:ListenForEvent("onremove", function()
            if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                inst._aura_fx:Remove()
                inst._aura_fx = nil
            end
            if inst._lunar_aura ~= nil and inst._lunar_aura:IsValid() then
                inst._lunar_aura:Remove()
                inst._lunar_aura = nil
            end
            if inst._ice_fx ~= nil and inst._ice_fx:IsValid() then
                inst._ice_fx:Remove()
                inst._ice_fx = nil
            end
            if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                inst._shadow_fx:Remove()
                inst._shadow_fx = nil
            end
            if inst.Light then
                inst.Light:Enable(false)
            end
        end)

        return inst
    end

    --==================================================================================
    -- BRUTE BOT v3: Upgraded version with storage chest, +2000 HP, +20 DMG,
    -- follows player, larger size. Spawned by wrench upgrade on brute2.
    -- Requires Brute Bot MK.III skill
    --==================================================================================
    local function fn3(inst)
        local inst = fn2()

        inst:AddTag("brute_upgraded_mk3")

        if not TheWorld.ismastersim then
            return inst
        end

        -- v2.0.15 FIX: MK3 now gets +500 HP (→3000) and +5 DMG (→32) over MK2
        -- (was: reverting to MK2 stats — regression bug)
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BRUTE_HEALTH + 1500)
        inst.components.health:SetCurrentHealth(inst.components.health.maxhealth)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BRUTE_DAMAGE + 15)

        -- Affinity pulse (MK3 only)
        AffinityPulse.Setup(inst, GetOwner)

        -- Container (chest) for MK3 - ÚNICA adição do MK.III
        inst:AddTag("container")
        inst:AddComponent("container")
        inst.components.container:WidgetSetup("williambrute3")
        inst.components.container.onopenfn = OnOpen
        inst.components.container.onclosefn = OnClose
        inst.components.container.skipopensnd = true
        inst.components.container.skipclosesnd = true

        -- Override engieworkable to only do repair (no more upgrades)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            if inst.on == false then return end
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end
            if inst.components.health and inst.components.health.currenthealth >= inst.components.health.maxhealth then
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

        -- Workable for hammer deactivation (same as MK1)
        if inst.components.workable == nil then
            inst:AddComponent("workable")
        end
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)
        inst.components.workable:SetOnWorkCallback(onworked)

        -- Override OnSave/OnLoad to ensure MK3 state is preserved
        local old_OnSaveBrute3 = inst.OnSave
        local function OnSaveBrute3(inst, data)
            if old_OnSaveBrute3 then
                old_OnSaveBrute3(inst, data)
            end
            data.is_mk3 = true
        end
        
        inst.OnSave = OnSaveBrute3
        
        local old_OnLoadBrute3 = inst.OnLoad  -- captures OnLoadBrute2WithUpgrade
        inst.OnLoad = function(inst2, data)
            -- Call the MK2→base onload chain first
            if old_OnLoadBrute3 then old_OnLoadBrute3(inst2, data) end
            if not TheWorld.ismastersim then return end
            
            -- Restore MK3 container if it was removed during load (bot was OFF when saved)
            if data and data.is_mk3 and not inst2:HasTag("container") then
                inst2:AddTag("container")
                if inst2.components.container == nil then
                    inst2:AddComponent("container")
                    inst2.components.container:WidgetSetup("williambrute3")
                    inst2.components.container.onopenfn = OnOpen
                    inst2.components.container.onclosefn = OnClose
                    inst2.components.container.skipopensnd = true
                    inst2.components.container.skipclosesnd = true
                end
            end
            
            -- Restore affinity FX (celestial/shadow) after load
            inst2:DoTaskInTime(0, function()
                if not inst2:IsValid() then return end
                local owner = inst2.components.follower and inst2.components.follower:GetLeader()
                local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
                local shadow = owner and owner:HasTag("wagstaff_shadow_possession")
                if TheWorld.state.isday and celestial then
                    if inst2._celestial_light == nil then inst2.entity:AddLight(); inst2._celestial_light = true end
                    if inst2.Light then inst2.Light:Enable(true); inst2.Light:SetRadius(2.5); inst2.Light:SetIntensity(0.4); inst2.Light:SetColour(0.4,0.7,1) end
                    if inst2.on ~= false and (inst2._aura_fx == nil or not inst2._aura_fx:IsValid()) then
                        inst2._aura_fx = SpawnPrefab("bot_aura_bouncer")
                        if inst2._aura_fx then inst2._aura_fx._parent = inst2 end
                    end
                    if inst2._lunar_aura == nil or not inst2._lunar_aura:IsValid() then
                        inst2._lunar_aura = SpawnPrefab("lunarhail")
                        if inst2._lunar_aura then inst2._lunar_aura.entity:SetParent(inst2.entity) end
                    end
                end
                if TheWorld.state.isdusk and shadow then
                    if inst2._shadow_fx == nil or not inst2._shadow_fx:IsValid() then
                        inst2._shadow_fx = SpawnPrefab("shadow_puff_large_front")
                        if inst2._shadow_fx then inst2._shadow_fx.entity:SetParent(inst2.entity) end
                    end
                end
            end)
        end
        
        -- Named status display for MK3
        if inst.components.named == nil then
            inst:AddComponent("named")
        end
        local function UpdateBrute3Name(inst)
            local base = "Brute Bot Mk.III"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local displayname = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp
            inst.components.named:SetName(displayname)
            inst.name = displayname
            inst.GetDisplayName = function() return displayname end
        end
        UpdateBrute3Name(inst)
        inst:DoPeriodicTask(2, UpdateBrute3Name)

        return inst
    end


local function onbuilt(inst, builder)
        local type = math.random(1, 100) == 100 and "williambrute_gary" or "williambrute"
    local robot = SpawnPrefab(type)
        if robot ~= nil then
    robot.Transform:SetPosition(inst.Transform:GetWorldPosition())
    robot.components.knownlocations:RememberLocation("home", inst:GetPosition())
    -- Pass builder as doer so TurnOn sets leader correctly
    -- Rise(doer, instant) -> self.onrisefn(self.inst, doer)
    robot.components.willyraise:Rise(builder)
        robot.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
                    local x, y, z = robot.Transform:GetWorldPosition()
    SpawnPrefab("maxwell_smoke").Transform:SetPosition(x, y, z)
    robot.maker = builder and builder.name or "unknown"
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


        inst.OnBuiltFn = onbuilt

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

    local s = 1.7 / PLACER_SCALE
    placer2.Transform:SetScale(s, s, s)

    placer2.AnimState:SetBank("william_brute")
    placer2.AnimState:SetBuild("william_brute")
    placer2.AnimState:PlayAnimation("sit_idle", true)
    placer2.AnimState:SetLightOverride(1)

    placer2.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(placer2)
end


    return Prefab("williambrute", fn, assets, prefabs),
    Prefab("williambrute2", fn2, assets, prefabs),
    Prefab("williambrute3", fn3, assets, prefabs),
    Prefab("williambrute_gary", gary, assets, prefabs),
    MakePlacer("williambrute_placer", "william_brute", "william_brute", "sit_idle", false, nil, nil, 1.7),
        Prefab("williambrute_builder", builder, assets, prefabs)



--------------------------------------------------------------------------
