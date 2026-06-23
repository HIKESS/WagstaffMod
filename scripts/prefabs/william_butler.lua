require "prefabutil"
require "recipe"
require "modutil"

local prefabs =
{

}

    local assets =
    {
        Asset("ANIM", "anim/william_butler.zip"),
    Asset("ANIM", "anim/ui_chest_3x2.zip"),
    Asset("ANIM", "anim/ui_chest_3x1.zip"),
        Asset("SOUND", "sound/maxwell.fsb"),
    }

SetSharedLootTable("butler",
{
    {'cutstone',          1},
    {'transistor',          1},
    {'goldnugget',          1},
    {'silk',          1},

})

SetSharedLootTable("butlergadget",
{
    {'williamgadget',          1},
})

local brain = require "brains/williambutlerbrain"
local AffinityPulse = _G.AffinityPulse

-- v2.0.17: debug helpers gated by the "Debug mode" mod config button.
-- Zero-cost when debug is OFF (early return before any string work).
local _dbg  = _G.WagstaffDbg  or function(...) end
local _dbgF = _G.WagstaffDbgF or function(...) end

local function UpdateButlerName(inst)
    if not inst.components.fueled or not inst.components.health then return end
    local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
    local hp = math.floor(inst.components.health.currenthealth)
    local maxhp = math.floor(inst.components.health.maxhealth)
    local base_name = "Butler Bot"
    if inst.prefab == "williambutler2" then
        base_name = "Butler Bot Mk. II"
    elseif inst.prefab == "williambutler3" then
        base_name = "Butler Bot Mk. III"
    end

    -- Build name string with fuel, HP and upgrade info (show progress from 0)
    local upgrade_str = ""
    if inst.prefab == "williambutler" and inst.upgradelevel and inst.upgradelevel < 50 then
        upgrade_str = " | Upgrade: " .. inst.upgradelevel .. "/50"
    elseif inst.prefab == "williambutler2" and inst.upgradelevel_mk3 and inst.upgradelevel_mk3 < 70 then
        upgrade_str = " | Upgrade: " .. inst.upgradelevel_mk3 .. "/70"
    end
    local name_str = base_name .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str

    -- Set on named component (always exists — added in fn())
    if inst.components.named ~= nil then
        inst.components.named:SetName(name_str)
    end

    -- Directly set inst.name and GetDisplayName for hover display
    inst.name = name_str
    inst.GetDisplayName = function() return name_str end
end

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

local function MakeAlive(inst, doer)
    -- BUG FIX: Check if doer has petleash (fixes bug after c_skip)
    if not doer or not doer.components.petleash then
        return
    end

    local pt = inst:GetPosition()
    local prefab_to_spawn = "williambutler"
    local was_level2 = inst.was_level2 or false
    local was_mk3 = inst.was_mk3 or false
    local saved_upgrade = inst.saved_upgradelevel or 0
    local saved_upgrade_mk3 = inst.saved_upgradelevel_mk3 or 0

    -- Check upgrade state
    if was_mk3 then
        prefab_to_spawn = "williambutler3"
    elseif was_level2 then
        prefab_to_spawn = "williambutler2"
    end

    local respawned = doer.components.petleash:SpawnPetAt(pt.x, 0, pt.z, prefab_to_spawn)
    if respawned ~= nil then
        respawned.components.fueled.currentfuel = inst.components.fueled.currentfuel
        respawned.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        respawned.Transform:SetRotation(inst.Transform:GetRotation())

        -- BUG FIX: Save owner GUID for tracking (fixes bug 9)
        respawned.owner_guid = doer.GUID
        respawned.owner_name = doer.name

        -- Restore upgrade progress
        if was_mk3 and saved_upgrade_mk3 > 0 then
            respawned.upgradelevel_mk3 = saved_upgrade_mk3
        elseif was_level2 then
            respawned.upgradelevel_mk3 = saved_upgrade_mk3 or 0
        elseif not was_level2 and not was_mk3 and saved_upgrade > 0 then
            respawned.upgradelevel = saved_upgrade
        end
        UpdateButlerName(respawned)

        respawned.sg:GoToState("revived")
    end
    inst:Remove()
end

local function onfuelchange(newsection, oldsection, inst, doer)
        if newsection >= 0 then
    local pt = inst:GetPosition()
        -- BUG FIX: Check petleash before reviving
        if doer ~= nil and doer:HasTag("williamcrafter") and doer.components.petleash then
                MakeAlive(inst, doer)
                end
        end
end

local function OnAddFuel(inst)
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel")

        if inst.sg ~= nil and not inst.sg:HasStateTag("busy") then
    inst.sg:GoToState("fed")
        end
        
        -- Update fuel display when refueled
        UpdateButlerName(inst)
    inst:AddTag("alive")
end

local function OnHammered(inst, worker)
    if inst.components.container then
        inst.components.container:DropEverything()
    end

    -- Exactly 1 core — clear preset tables so DropLoot does not stack gadgets
    inst.components.lootdropper:SetLoot({"williamgadget"})
    inst.components.lootdropper:SetChanceLootTable(nil)
    inst.components.lootdropper:DropLoot()

    -- 50% bonus materials only (butler table never includes williamgadget)
    if math.random() < 0.5 then
        inst.components.lootdropper:SetLoot({})
        inst.components.lootdropper:SetChanceLootTable("butler")
        inst.components.lootdropper:DropLoot()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function onworked(inst)
        if inst.sg ~= nil then
        inst.sg:GoToState("hit")
        end
end

local function OnFuelEmpty(inst)
    if inst.sg ~= nil then
        inst.sg:GoToState("powerdown")
    end
end

local function oncook(inst, doer)

for k, v in pairs (inst.components.container.slots) do
                        if v.components.cookable ~= nil then
                local leader = inst.components.follower:GetLeader()
                local cook_pos = inst:GetPosition()
                        inst.sg:GoToState("cook")
        inst:DoTaskInTime(0.9, function()

if inst.components.fueled ~= nil then
        inst.components.fueled:DoDelta(-.01 * inst.components.fueled.maxfuel)
    end

        if inst.components.fueled ~= nil and not inst.components.fueled:IsEmpty() then

        local ingredient = inst.components.container:RemoveItem(v)


        --if ingredient ~= nil then  end

        v.Transform:SetPosition(cook_pos:Get())

        if not inst.components.cooker:CanCook(ingredient, inst) then
            inst.components.container:GiveItem(ingredient, nil, cook_pos)
            return false
        end

        if ingredient.components.health ~= nil and ingredient.components.combat ~= nil then
            inst:PushEvent("killed", { victim = ingredient })
        end

        local product = inst.components.cooker:CookItem(ingredient, inst)
            if product ~= nil and doer ~= nil then
                -- v2.0.17 DEBUG: trace affinity food logic
                local _owner = GetOwner(inst)
                local _has_celest = _owner and _owner:HasTag("wagstaff_celestial_possession")
                local _has_shadow = _owner and _owner:HasTag("wagstaff_shadow_possession")
                _dbgF("[BUTLER COOK] prefab=%s isday=%s isdusk=%s owner=%s celest=%s shadow=%s",
                    inst.prefab, tostring(TheWorld.state.isday), tostring(TheWorld.state.isdusk),
                    tostring(_owner ~= nil), tostring(_has_celest), tostring(_has_shadow))

                -- CELESTIAL POSSESSION: Foods restore HP% (MK3 only)
                if inst.prefab == "williambutler3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                if product.components.edible and product.components.edible.hungervalue then
                    local hunger_percent = product.components.edible.hungervalue / 100
                    if hunger_percent > 1 then hunger_percent = 1 end
                    -- Store the healing amount on the food item (40% of hunger = HP%)
                    product._celestial_hp_heal = hunger_percent * 40
                    product._celestial_hp_doer = doer
                    _dbgF("[BUTLER COOK] CELESTIAL applied: heal=%.1f%% of max HP", product._celestial_hp_heal)
                    -- Listen for when food is eaten
                    local old_oneaten = product.components.edible.oneaten
                    product.components.edible:SetOnEatenFn(function(food, eater)
                        if old_oneaten then old_oneaten(food, eater) end
                        -- Only HP heal, no sanity bonus
                        if eater.components.health and food._celestial_hp_heal then
                            local max_hp = eater.components.health.maxhealth
                            local heal_amount = max_hp * (food._celestial_hp_heal / 100)
                            eater.components.health:DoDelta(heal_amount, false, "celestial_food")
                            _dbgF("[BUTLER COOK] CELESTIAL eaten: healed %.1f HP", heal_amount)
                        end
                    end)
                end
            end

            -- SHADOW POSSESSION: Foods restore SANITY% (MK3 only)
            if inst.prefab == "williambutler3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                if product.components.edible and product.components.edible.hungervalue then
                    local hunger_percent = product.components.edible.hungervalue / 100
                    if hunger_percent > 1 then hunger_percent = 1 end
                    -- Store the sanity amount on the food item (40% of hunger = sanity%)
                    product._shadow_sanity_restore = hunger_percent * 40
                    product._shadow_sanity_doer = doer
                    _dbgF("[BUTLER COOK] SHADOW applied: restore=%.1f%% of max sanity", product._shadow_sanity_restore)
                    -- Listen for when food is eaten
                    local old_oneaten = product.components.edible.oneaten
                    product.components.edible:SetOnEatenFn(function(food, eater)
                        if old_oneaten then old_oneaten(food, eater) end
                        -- Only sanity restore, no HP bonus
                        if eater.components.sanity and food._shadow_sanity_restore then
                            local max_sanity = eater.components.sanity.max
                            local sanity_amount = max_sanity * (food._shadow_sanity_restore / 100)
                            eater.components.sanity:DoDelta(sanity_amount, false, "shadow_food")
                            _dbgF("[BUTLER COOK] SHADOW eaten: restored %.1f sanity", sanity_amount)
                        end
                    end)
                end
            end
            
            doer.components.inventory:GiveItem(product, nil, cook_pos)

            return true
        elseif ingredient:IsValid() then
            inst.components.container:GiveItem(ingredient, nil, cook_pos)
        end

        end

        end)
                end
        end
end

local function fuelupdate(inst)
        if inst.components.fueled ~= nil
            and inst.components.fueled.currentfuel <= inst.components.fueled.maxfuel*0.2  then
                inst:AddTag("lowfuel")
                else
        if inst:HasTag("lowfuel") then
    inst:RemoveTag("lowfuel")
        end
        end
    -- Update name with current fuel (now one function handles all versions!)
    UpdateButlerName(inst)
end

local function nokeeptargetfn(inst)
    return false
end

local function getstatus(inst, viewer)
    -- Fuel status
    local fuel_pct = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
    local fuel_str = "Fuel: " .. fuel_pct .. "%"
    
    -- Upgrade status
    local upgrade_str = ""
    if inst.prefab == "williambutler" and inst.upgradelevel and inst.upgradelevel < 50 then
        upgrade_str = " | Upgrade: " .. inst.upgradelevel .. "/50"
    elseif inst.prefab == "williambutler2" and inst.upgradelevel_mk3 and inst.upgradelevel_mk3 < 70 then
        upgrade_str = " | Upgrade: " .. inst.upgradelevel_mk3 .. "/70"
    end
    
    -- Combined status
    if inst.components.fueled:IsEmpty() then
        return "EMPTY" .. upgrade_str
    elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .3 then
        return "CRITICALFUEL" .. upgrade_str
    elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .6 then
        return "LOWFUEL" .. upgrade_str
    else
        return fuel_str .. upgrade_str
    end
end

local function GetButlerDescription(inst, viewer)
    -- Direct description for hover text
    local fuel_pct = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
    local desc = "Butler Bot\n"
    
    if inst.prefab == "williambutler2" then
        desc = "Butler Bot Mk. II\n"
    elseif inst.prefab == "williambutler3" then
        desc = "Butler Bot Mk. III\n"
    end
    
    desc = desc .. "Fuel: " .. fuel_pct .. "%"
    
    if inst.prefab == "williambutler" and inst.upgradelevel and inst.upgradelevel < 50 then
        desc = desc .. "\nUpgrade: " .. inst.upgradelevel .. "/50"
    elseif inst.prefab == "williambutler2" and inst.upgradelevel_mk3 and inst.upgradelevel_mk3 < 70 then
        desc = desc .. "\nUpgrade: " .. inst.upgradelevel_mk3 .. "/70"
    end
    
    return desc
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function nodebrisdmg(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return (afflicter ~= nil and afflicter:HasTag("quakedebris")) or (afflicter ~= nil and afflicter:HasTag("epic") and afflicter.components.combat.target ~= inst)
end

local function OnOpen(inst)
    if not inst.components.health:IsDead() then
        inst.sg:GoToState("open")
        
        -- Show slot labels for butler2
        if inst.prefab == "williambutler2" and inst.components.follower and inst.components.follower:GetLeader() then
            local leader = inst.components.follower:GetLeader()
            if leader and leader.components.talker then
                leader.components.talker:Say("Slots 1-3: [Cook]")
            end
        end
        
        -- CELESTIAL POSSESSION: FX ao abrir menu - ghostlyelixir_shield central (MK3 only)
        if inst.prefab == "williambutler3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
            local x, y, z = inst.Transform:GetWorldPosition()
            -- FX central no meio do corpo do bot
            local shield_fx = SpawnPrefab("ghostlyelixir_shield_fx")
            if shield_fx then
                shield_fx.Transform:SetPosition(x, y + 0.3, z) -- Centro do corpo (mais baixo)
                shield_fx.Transform:SetScale(0.5, 0.5, 0.5) -- 50% do tamanho (médio)
                if shield_fx.AnimState then
                    shield_fx.AnimState:SetMultColour(1, 1, 1, 0.5) -- 50% transparente
                    shield_fx.AnimState:SetDeltaTimeMultiplier(0.3) -- Pisca 3x mais lento
                end
            end
        end
        
        -- SHADOW POSSESSION: FX ao abrir menu - shadow_shield1 (MK3 only)
        if inst.prefab == "williambutler3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
            local x, y, z = inst.Transform:GetWorldPosition()
            -- FX de escudo sombrio
            local shield_fx = SpawnPrefab("shadow_shield1")
            if shield_fx then
                shield_fx.Transform:SetPosition(x, y + 0.3, z) -- Centro do corpo
                shield_fx.Transform:SetScale(0.5, 0.5, 0.5) -- 50% do tamanho
            end
        end
    end
end

local function OnClose(inst)
    if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
        inst.sg:GoToState("close")
    end

end

local function onload(inst)
   if inst.components.fueled:IsEmpty() then
                OnFuelEmpty(inst)
        end
end


    local function fn(inst)
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()
        inst.MiniMapEntity:SetIcon("williambutler.tex")
        inst.DynamicShadow:SetSize(1.3, .6)
        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("wilson")
        inst.AnimState:SetBuild("william_butler")
        inst.AnimState:PlayAnimation("idle")
            inst.AnimState:Hide("ARM_carry")
            inst.AnimState:Hide("HEAD_HAT")

    MakeCharacterPhysics(inst, 50, .5)
        --inst.Physics:SetCollides(true)
        --inst:DoTaskInTime(0, function() inst.Physics:SetCollides(true) end)

        inst.AnimState:OverrideSymbol("fx_wipe", "wilson_fx", "fx_wipe")
        inst.AnimState:OverrideSymbol("fx_liquid", "wilson_fx", "fx_liquid")
        inst.AnimState:OverrideSymbol("shadow_hands", "shadow_hands", "shadow_hands")
    inst.AnimState:AddOverrideBuild("player_idles_warly")


        inst:AddTag("willminion")
        inst:AddTag("willfollower")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
    inst:AddTag("cooker")
   inst:AddTag("container")
    inst:AddTag("stewer")
        inst:AddTag("tiddlevirusimmune")
    inst:SetPrefabNameOverride("williambutler")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end





        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUTLER_HEALTH)
       -- inst.components.health.nofadeout = true
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health.redirect = nodebrisdmg
                inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("butler")

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("named")

        inst:AddComponent("willyraise")
    inst.components.willyraise:SetOnRiseFn(MakeAlive)
    inst.components.willyraise:SetOnLowerFn(OnFuelEmpty)

    inst:AddComponent("fueled")
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled.accepting = true  -- Enable manual fueling (reverted to original)
    inst.components.fueled:InitializeFuelLevel(TUNING.WILLIAM_BUTLER_MAXFUEL)
    inst.components.fueled.bonusmult = 1

    -- Update name AFTER fueled component is added (was crashing on craft: fueled was nil)
    UpdateButlerName(inst)

        return inst
    end

        --ACTIVE butler
        
    local function active(inst)
        local inst = fn(inst)
    MakeCharacterPhysics(inst, 50, .5)

    inst.MiniMapEntity:SetCanUseCache(false)

        inst.Transform:SetFourFaced()

        inst:AddTag("alive")
        inst:AddTag("scarytoprey")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("butler")
        inst:AddTag("dangerouscooker")
        inst:AddTag("expertchef")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("ebuild_wrenchable")
        inst.AnimState:Hide("swap_body")

        if not TheWorld.ismastersim then
            return inst
        end

    -- BUG FIX: Standard workable for regular hammer (always present)
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

 inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

        inst:SetStateGraph("SGwilliambutler")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("williambutler")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.skipopensnd = true
    inst.components.container.skipclosesnd = true

        inst:AddComponent("combat")
        inst.components.combat.hiteffectsymbol = "torso"
        inst.components.combat:SetRange(3)
    inst.components.combat:SetKeepTargetFunction(nokeeptargetfn)


        inst:ListenForEvent("docookery", oncook)

        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true

        -- Meat Effigy Overclock: swap places with owner on near-death
    inst.components.fueled:SetUpdateFn(fuelupdate)
    inst.components.fueled:SetDepletedFn(OnFuelEmpty)

        inst:SetBrain(brain)

    MakeMediumBurnableCharacter(inst, "torso")
    MakeMediumFreezableCharacter(inst, "torso")

    inst.components.fueled:StartConsuming()

    -- Rain damage (like WX-78) when active
    inst:DoPeriodicTask(1, function(inst)
        if TheWorld.state.israining and inst.components.health then
            inst.components.health:DoDelta(-1, false, "wetness")
        end
    end)

    -- Lightning recharge (refuel, no overcharge)
    inst:ListenForEvent("lightningstrike", function(inst)
        if inst.components.fueled then
            inst.components.fueled:DoDelta(inst.components.fueled.maxfuel * 0.25)
        end
    end)

inst.components.burnable.ignorefuel = true
    inst:AddComponent("cooker")
    
    -- Initialize name with fuel status
    UpdateButlerName(inst)
    inst:ListenForEvent("fuelchange", function() UpdateButlerName(inst) end)
    inst:ListenForEvent("healthdelta", function() UpdateButlerName(inst) end)
    -- Periodic update to ensure hover display stays current (matches other bots)
    inst:DoPeriodicTask(2, function() UpdateButlerName(inst) end)

    --==================================================================================
    -- BUTLER UPGRADE: Wrench upgrade spawns williambutler2 with 3 cook slots
    -- v2.0.16: 50 scraps total, 10 per hit (5 hits). Progress shown in bot name.
    -- Requires wagstaff_thermal_upgrade skill to be learned.
    --==================================================================================
    inst.upgradelevel = 0

        local function IsScrap(item)
            return item.prefab == "scrap"
        end

        inst:AddComponent("engieworkable")
        inst.components.engieworkable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.engieworkable:SetMaxWork(1)
        inst.components.engieworkable:SetWorkLeft(1)
        inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
            _dbg("[DEBUG UPGRADE] OnWorkCallback chamado!")
            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            _dbg("[DEBUG UPGRADE] === INICIO DO UPGRADE DO BUTLER ===")
            _dbg("[DEBUG UPGRADE] worker:", worker, worker.prefab)
            _dbg("[DEBUG UPGRADE] inst:", inst, inst.prefab)
            
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                _dbg("[DEBUG UPGRADE] Bot em estado shutdown, abortando")
                return
            end
            
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            _dbg("[DEBUG UPGRADE] Wrench equipada:", wrench and wrench.prefab or "NENHUMA")
            
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                _dbg("[DEBUG UPGRADE] Usando durabilidade da wrench")
                wrench.components.finiteuses:Use(1)
            end

            -- PRIORITY 1: Repair if HP < 100% (NO skill required)
            _dbg("[DEBUG UPGRADE] HP atual:", inst.components.health.currenthealth, "/", inst.components.health.maxhealth)
            if inst.components.health.currenthealth < inst.components.health.maxhealth then
                _dbg("[DEBUG UPGRADE] Tentando reparar bot...")
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                _dbg("[DEBUG UPGRADE] Scrap encontrado:", scrapstack and scrapstack.prefab or "NENHUM", "Custo reparo:", repair_cost)
                if repair_cost > 0 and scrapstack == nil then
                    _dbg("[DEBUG UPGRADE] Sem scrap para reparo!")
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    _dbg("[DEBUG UPGRADE] Consumindo", repair_cost, "scrap(s) para reparo")
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
                _dbg("[DEBUG UPGRADE] Reparo concluido!")
                return
            end

            -- PRIORITY 2: Upgrade if HP = 100% AND skill learned
            _dbg("[DEBUG UPGRADE] Bot com HP maximo, verificando skill wagstaff_thermal_upgrade...")
            _dbg("[DEBUG UPGRADE] worker.prefab=", tostring(worker.prefab))
            _dbg("[DEBUG UPGRADE] worker tem skilltreeupdater=", tostring(worker.components.skilltreeupdater ~= nil))
            
            local has_skill = _G.WagstaffHasSkill(worker, "wagstaff_thermal_upgrade")
            _dbg("[DEBUG UPGRADE] Resultado de WagstaffHasSkill:", has_skill)
            
            if not has_skill then
                _dbg("[DEBUG UPGRADE] Skill NAO encontrada! Bloqueando upgrade.")
                if worker.components.talker then
                    worker.components.talker:Say("Requires Butler MK. II skill!\n(Activate it in the skill tree!)")
                end
                return
            end
            
            _dbg("[DEBUG UPGRADE] Skill encontrada! Prosseguindo com upgrade...")

    -- Upgrade: variable scrap cost per wrench hit (10, 10, 10, 10, 15 = 55 total)
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
            _dbg("[DEBUG UPGRADE] Scrap count no inventario:", scrap_count)
            
            -- Determine cost based on current upgrade level
            local upgrade_cost_table = {10, 10, 10, 10, 10}  -- v2.0.16: 50 scraps total (was 55)
            local hits_so_far = math.floor(inst.upgradelevel / 10)  -- 0-5 hits
            local base_cost = upgrade_cost_table[hits_so_far + 1] or 10
            local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, base_cost)
            _dbg("[DEBUG UPGRADE] Upgrade level atual:", inst.upgradelevel, "hits_so_far:", hits_so_far, "base_cost:", base_cost, "upgrade_cost (com eficiencia):", upgrade_cost)
            
            if upgrade_cost > 0 and scrap_count < upgrade_cost then
                _dbg("[DEBUG UPGRADE] Scrap insuficiente! Precisa de", upgrade_cost, "tem", scrap_count)
                if worker.components.talker then
                    worker.components.talker:Say("Need " .. upgrade_cost .. " Scrap Metal!")
                end
                return
            end
            if upgrade_cost > 0 then
                _dbg("[DEBUG UPGRADE] Consumindo", upgrade_cost, "scrap(s) para upgrade")
                worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
            end
            inst.upgradelevel = inst.upgradelevel + base_cost
            _dbg("[DEBUG UPGRADE] Novo upgrade level:", inst.upgradelevel)
            UpdateButlerName(inst)

            if inst.upgradelevel >= 50 then
                _dbg("[DEBUG UPGRADE] UPGRADE COMPLETO! Spawnando williambutler2...")
                inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                if worker.components.talker then
                    worker.components.talker:Say("Butler Bot MK. II upgrade complete!")
                end

                -- Spawn upgraded bot
                local pt = inst:GetPosition()
                local newbot = SpawnPrefab("williambutler2")
                _dbg("[DEBUG UPGRADE] newbot spawned:", newbot and "SUCESSO" or "FALHA")
                if newbot ~= nil then
                    newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                    newbot.Transform:SetRotation(inst.Transform:GetRotation())

                    -- Transfer fuel
                    if inst.components.fueled and newbot.components.fueled then
                        _dbg("[DEBUG UPGRADE] Transferindo fuel:", inst.components.fueled.currentfuel)
                        newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                    end
                    -- Transfer health
                    if inst.components.health and newbot.components.health then
                        _dbg("[DEBUG UPGRADE] Transferindo health:", inst.components.health.currenthealth)
                        newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                    end
                    -- Transfer container items (crockpot slots 1-3)
                    if inst.components.container and newbot.components.container then
                        for slot = 1, 3 do
                            local item = inst.components.container:GetItemInSlot(slot)
                            if item ~= nil then
                                _dbg("[DEBUG UPGRADE] Transferindo item do slot", slot, ":", item.prefab)
                                newbot.components.container:GiveItem(item, slot)
                            end
                        end
                    end

                    -- Transfer follower
                    if inst.components.follower and newbot.components.follower then
                        local leader = inst.components.follower:GetLeader()
                        if leader ~= nil then
                            _dbg("[DEBUG UPGRADE] Transferindo leader:", leader.prefab)
                            newbot.components.follower:SetLeader(leader)
                        end
                    end

                    -- Spawn FX
                    SpawnPrefab("small_puff").Transform:SetPosition(pt.x, pt.y, pt.z)
                end

                _dbg("[DEBUG UPGRADE] Removendo bot antigo...")
                inst:Remove()
            else
                _dbg("[DEBUG UPGRADE] Upgrade em andamento... falta", 85 - inst.upgradelevel, "para completar")
            end
        end)

    -- Save/load upgrade progress
    local function OnSaveButler(inst, data)
        data.upgradelevel = inst.upgradelevel
        -- Save leader GUID for persistence
        if inst.components.follower and inst.components.follower:GetLeader() then
            data.leader_guid = inst.components.follower:GetLeader().GUID
        end
    end

    local function OnLoadButler(inst, data)
        if data then
            inst.upgradelevel = data.upgradelevel or 0
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
    end

    inst.OnSave = OnSaveButler
    inst.OnLoad = OnLoadButler

    MakeHauntablePanic(inst)

        return inst
    end

    --==================================================================================
    -- BUTLER BOT v2: Upgraded version with 3 cook slots
    -- Now Picks Twigs & Grass when owner picks.
    -- Spawned by wrench upgrade on original butler.
    --==================================================================================
    local function active2(inst)
        local inst = fn(inst)
        MakeCharacterPhysics(inst, 50, .5)

        inst.MiniMapEntity:SetCanUseCache(false)
        inst.Transform:SetFourFaced()

        inst:AddTag("alive")
        inst:AddTag("scarytoprey")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("butler")
        inst:AddTag("dangerouscooker")
        inst:AddTag("expertchef")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("butler_thermal_upgraded")
        inst:AddTag("ebuild_wrenchable")
        inst.AnimState:Hide("swap_body")

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

        inst:SetStateGraph("SGwilliambutler")

        inst:AddComponent("container")
        inst.components.container:WidgetSetup("williambutler2")
        inst.components.container.onopenfn = OnOpen
        inst.components.container.onclosefn = OnClose
        inst.components.container.skipopensnd = true
        inst.components.container.skipclosesnd = true

        inst:AddComponent("combat")
        inst.components.combat.hiteffectsymbol = "torso"
        inst.components.combat:SetRange(3)
        inst.components.combat:SetKeepTargetFunction(nokeeptargetfn)

        inst:ListenForEvent("docookery", oncook)



        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true

        inst.components.fueled:SetUpdateFn(fuelupdate)
        inst.components.fueled:SetDepletedFn(OnFuelEmpty)

        inst:SetBrain(brain)

        MakeMediumBurnableCharacter(inst, "torso")
        MakeMediumFreezableCharacter(inst, "torso")

        inst.components.fueled:StartConsuming()

        inst.components.burnable.ignorefuel = true
        inst:AddComponent("cooker")

    -- Wrapper Save/Load (padrão Buster - preserva dados do active())
    local old_OnSaveButler2 = inst.OnSave
    inst.OnSave = function(inst, data)
        if old_OnSaveButler2 then old_OnSaveButler2(inst, data) end
        data.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        data.was_mk3 = inst.was_mk3 or false
    end

    local old_OnLoadButler2 = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if old_OnLoadButler2 then old_OnLoadButler2(inst, data) end
        if data then
            inst.upgradelevel_mk3 = data.upgradelevel_mk3 or 0
            inst.was_mk3 = data.was_mk3 or false
        end
        -- Atualiza o nome após carregar
        inst:DoTaskInTime(0, function()
            if inst.components.named then UpdateButlerName(inst) end
        end)
    end

        -- BUTLER MK.II -> MK.III UPGRADE (70 scraps total, 5 per hit)
        inst.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0

        UpdateButlerName(inst)
        inst:ListenForEvent("fuelchange", function() UpdateButlerName(inst) end)
        inst:ListenForEvent("healthdelta", function() UpdateButlerName(inst) end)
        -- v2.0.16: Add periodic task for MK2 (was missing — hover not refreshing)
        inst:DoPeriodicTask(2, function() UpdateButlerName(inst) end)

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
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                return
            end
            inst.components.engieworkable:SetWorkLeft(1)
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- PRIORITY 1: Repair if HP < 100% (NO skill required)
            if inst.components.health.currenthealth < inst.components.health.maxhealth then
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

            -- PRIORITY 2: Upgrade to MK.III if HP = 100% AND skill learned (70 scraps, 5 per hit)
            if not _G.WagstaffHasSkill(worker, "wagstaff_thermal_upgrade_mk3") then
                if worker.components.talker then
                    worker.components.talker:Say("Requires Butler MK. II skill!\n(Activate it in the skill tree!)")
                end
                return
            end

            -- MK.III Upgrade: 5 scraps per hit, 70 total
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
            UpdateButlerName(inst)

            if inst.upgradelevel_mk3 >= 70 then
                inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                if worker.components.talker then
                    worker.components.talker:Say("Butler Bot MK. III upgrade complete!")
                end

                -- Spawn MK.III version
                local pt = inst:GetPosition()
                local newbot = SpawnPrefab("williambutler3")
                if newbot ~= nil then
                    newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                    newbot.Transform:SetRotation(inst.Transform:GetRotation())
                    newbot.was_mk3 = true

                    if inst.components.fueled and newbot.components.fueled then
                        newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                    end
                    if inst.components.health and newbot.components.health then
                        newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                    end
                    if inst.components.container and newbot.components.container then
                        for slot = 1, 3 do
                            local item = inst.components.container:GetItemInSlot(slot)
                            if item ~= nil then
                                newbot.components.container:GiveItem(item, slot)
                            end
                        end
                    end

                    if inst.components.follower and newbot.components.follower then
                        local leader = inst.components.follower:GetLeader()
                        if leader ~= nil then
                            newbot.components.follower:SetLeader(leader)
                            newbot.components.follower:SetLeader(leader)
                        end
                    end

                    SpawnPrefab("small_puff").Transform:SetPosition(pt.x, pt.y, pt.z)
                end

                inst:Remove()
            end
        end)

        return inst
    end

    --==================================================================================
    -- BUTLER BOT v3: Master Chef
    -- Spawned by wrench upgrade on MK.II butler (60 scraps total for MK.II->MK.III)
    --==================================================================================
    local function active3(inst)
        local inst = active2(inst)

        inst:SetPrefabNameOverride("williambutler3")
        inst:AddTag("butler_master_chef")

        if not TheWorld.ismastersim then
            return inst
        end

        -- v2.0.15: MK3 gets +100 HP (→300) so it survives longer as a follower
        if inst.components.health then
            inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUTLER_HEALTH + 100)
            inst.components.health:SetCurrentHealth(inst.components.health.maxhealth)
        end

        -- Slightly larger with golden tint
        inst.Transform:SetScale(1.1, 1.1, 1.1)
        inst.AnimState:SetMultColour(1, 0.95, 0.7, 1)

        -- Ensure Mk.III identity is persistent across saves
        inst.was_mk3 = true

        -- Affinity pulse (MK3 only)
        AffinityPulse.Setup(inst, GetOwner)

        -- Celestial light + aura (MK3 only)
        inst._celestial_light = nil
        inst._aura_fx = nil
        inst._shadow_fx = nil
        inst:DoPeriodicTask(3, function()
            if TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Add light component to bot
                if inst._celestial_light == nil then
                    inst.entity:AddLight()
                    inst._celestial_light = true
                end
                if inst.Light then
                    inst.Light:SetRadius(2)
                    inst.Light:SetIntensity(0.45)
                    inst.Light:SetFalloff(0.8)
                    inst.Light:SetColour(0.7, 0.85, 1)
                    inst.Light:Enable(true)
                end
                
                -- NOVA AURA CELESTIAL - só quando ativo (nil = inicialmente ativo)
                if inst.on ~= false and (inst._aura_fx == nil or not inst._aura_fx:IsValid()) then
                    inst._aura_fx = SpawnPrefab("bot_aura_butler")
                    if inst._aura_fx then
                        inst._aura_fx._parent = inst
                    end
                end
                
                -- Remove shadow FX if present
                if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                    inst._shadow_fx:Remove()
                    inst._shadow_fx = nil
                end
            else
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                    inst._aura_fx:Remove()
                    inst._aura_fx = nil
                end
            end
        end)

        -- Override name
        if inst.components.named == nil then
            inst:AddComponent("named")
        end
        inst.components.named:SetName("Butler Bot Mk.III")
        local function UpdateButler3Name(inst)
            local base = "Butler Bot Mk.III"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local name_str = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp
            inst.components.named:SetName(name_str)
            inst.name = name_str
            inst.GetDisplayName = function() return name_str end
        end
        UpdateButler3Name(inst)
        inst:ListenForEvent("fuelchange", function() UpdateButler3Name(inst) end)
        inst:ListenForEvent("healthdelta", function() UpdateButler3Name(inst) end)

        -- v2.0.17: HAUNT RESURRECTION rework — affinity revive powers work ALL DAY
        -- SHADOW (all day): consume haunter's nearest meat_effigy; butler SURVIVES
        -- CELESTIAL (all day): butler FULLY DISCHARGES (fuel->0) + downgrades to MK1;
        --   butler SURVIVES as inert MK1 (must be refueled); 1/day cooldown; celestial FX
        -- Default (no affinity): bot dies, player revives (classic behavior)
        --
        -- v2.0.17 BUGFIX: affinity tags were checked ONLY on GetOwner() (follower
        -- leader). When the owner is DEAD (ghost), the follower leader link can be
        -- nil, so OwnerHasShadow/OwnerHasCelestial returned false and the butler
        -- always died. Now we ALSO check the tags on the haunter (the ghost player
        -- attempting the revive) — its tags persist through death.

        local function FindAndConsumeEffigy(player)
            if not player or not player.Transform then return false end
            local nearest = nil
            local nearest_dist = math.huge
            for _, ent in pairs(_G.Ents) do
                if ent and ent:IsValid() and ent.prefab == "meat_effigy" and not ent:IsInLimbo() then
                    -- Ownership check: DST meat_effigies store builder userid.
                    -- If userid field exists, only match this player's effigies (MP-safe).
                    -- If no userid tracking, accept as candidate (SP/console fallback).
                    local owned = (ent.userid == nil) or (ent.userid == player.userid)
                    if owned then
                        local dist = player:GetDistanceSqToInst(ent)
                        if dist < nearest_dist then
                            nearest = ent
                            nearest_dist = dist
                        end
                    end
                end
            end
            if nearest then
                local ex, ey, ez = nearest.Transform:GetWorldPosition()
                if nearest.components.lootdropper then
                    nearest.components.lootdropper:DropLoot()
                end
                local fx = _G.SpawnPrefab("collapse_small")
                if fx then
                    fx.Transform:SetPosition(ex, ey, ez)
                    fx:SetMaterial("wood")
                end
                nearest:Remove()
                return true
            end
            return false
        end

        -- v2.0.18: Celestial discharge FX for the revive moment.
        -- Reworked: removed ghostlyelixir_shield_fx + sparklefx (didn't fit the
        -- "machine discharging" theme). Now uses lunar-aligned white FX:
        --   - archive_lockbox_dispawn_fx (white dissolve = energy dissolving away)
        --   - moonstorm_spark (white sparks = energy escaping the chassis)
        -- Plus a custom celestial light flash (white-blue, fades) — not a prefab,
        -- so it doesn't conflict with any FX table.
        -- Anti-stacking: SpawnUnique skips spawning if an FX of the same prefab
        -- already exists within 1.5 units (prevents duplicate FX when revive is
        -- triggered repeatedly / haunt spam).
        local function PlayCelestialDischargeFX(pt)
            local x, y, z = pt.x, pt.y, pt.z

            -- Helper: spawn FX only if no existing FX of the same prefab is nearby.
            -- "não repetir fx se já estiver em alguém" — prevents stacking.
            local function SpawnUnique(prefab_name, offset_y, scale)
                offset_y = offset_y or 0
                scale = scale or 1
                local nearby = _G.TheSim:FindEntities(x, y, z, 1.5)
                for _, ent in ipairs(nearby) do
                    if ent.prefab == prefab_name then
                        return nil -- already present nearby, skip
                    end
                end
                local fx = _G.SpawnPrefab(prefab_name)
                if fx then
                    fx.Transform:SetPosition(x, y + offset_y, z)
                    if scale ~= 1 then
                        fx.Transform:SetScale(scale, scale, scale)
                    end
                end
                return fx
            end

            -- Primary: white dissolve (archive_lockbox_dispawn_fx) — the bot's
            -- energy dissolving away as it discharges. Lunar-aligned (celestial).
            SpawnUnique("archive_lockbox_dispawn_fx", 0.5, 1.2)

            -- Secondary: white sparks (moonstorm_spark) — energy escaping the
            -- chassis as the fuel hits zero.
            SpawnUnique("moonstorm_spark", 0.3, 1.0)

            -- Brief celestial light flash (white-blue) that fades — the energy
            -- leaving the bot as it discharges. Custom entity (not a prefab FX),
            -- so no duplicate-check needed (it self-removes after 1.2s).
            local lightfx = _G.CreateEntity()
            if lightfx then
                lightfx.entity:AddTransform()
                lightfx.entity:AddLight()
                lightfx.Light:SetRadius(4)
                lightfx.Light:SetIntensity(0.9)
                lightfx.Light:SetFalloff(0.7)
                lightfx.Light:SetColour(0.7, 0.85, 1) -- celestial white-blue
                lightfx.Light:Enable(true)
                lightfx.Transform:SetPosition(x, y + 0.5, z)
                lightfx.persists = false
                lightfx:DoTaskInTime(0.4, function()
                    if lightfx and lightfx:IsValid() and lightfx.Light then
                        lightfx.Light:SetIntensity(0.5)
                    end
                end)
                lightfx:DoTaskInTime(0.8, function()
                    if lightfx and lightfx:IsValid() and lightfx.Light then
                        lightfx.Light:SetIntensity(0.2)
                    end
                end)
                lightfx:DoTaskInTime(1.2, function()
                    if lightfx and lightfx:IsValid() then lightfx:Remove() end
                end)
            end
        end

        -- v2.0.17: discharge param — when true (celestial revive), the butler
        -- fully discharges (fuel -> 0) as the cost of the revive.
        -- v2.0.18 FIX: when discharge=true, spawn the INERT HUSK (williambutler_empty)
        -- directly instead of an active MK1 with currentfuel=0. The previous code
        -- set currentfuel = 0 directly on an active MK1, which bypassed the fueled
        -- component's SetDepletedFn (OnFuelEmpty) — so the bot never entered the
        -- "powerdown" state and stayed active at 0% fuel indefinitely (infinite
        -- discharge bug: bot kept walking/cooking/following with no fuel).
        -- The husk sleeps (sleep_loop paused), accepts fuel, and reactivates as a
        -- fresh MK1 via MakeAlive when the player refuels + ACTIVATEs it.
        local function DowngradeButlerToMK1(inst, owner, discharge)
            local pt = inst:GetPosition()
            local newbot = nil

            if discharge then
                -- CELESTIAL: spawn the inert husk directly (already sleeping,
                -- paused anim, Notarget tag). Player must refuel + ACTIVATE.
                newbot = _G.SpawnPrefab("williambutler_empty")
                if newbot then
                    newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                    newbot.Transform:SetRotation(inst.Transform:GetRotation())
                    -- Husk starts fully discharged (the cost of the celestial revive)
                    if newbot.components.fueled then
                        newbot.components.fueled.currentfuel = 0
                    end
                    -- Transfer current health (capped at husk max)
                    if inst.components.health and newbot.components.health then
                        newbot.components.health:SetCurrentHealth(
                            math.min(inst.components.health.currenthealth,
                                     newbot.components.health.maxhealth))
                    end
                    -- Celestial revive DOWNGRADES to MK1: explicitly clear all
                    -- tier-upgrade flags so MakeAlive (on later refuel + ACTIVATE)
                    -- spawns a fresh MK1, NOT the old MK2/MK3 tier.
                    newbot.was_level2 = false
                    newbot.was_mk3 = false
                    newbot.saved_upgradelevel = 0
                    newbot.saved_upgradelevel_mk3 = 0
                end
            else
                -- Non-discharge path: spawn active MK1, carry over fuel (existing behavior)
                if owner and owner.components.petleash then
                    newbot = owner.components.petleash:SpawnPetAt(pt.x, 0, pt.z, "williambutler")
                end
                if newbot == nil then
                    newbot = _G.SpawnPrefab("williambutler")
                    if newbot then
                        newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                    end
                end
                if newbot then
                    newbot.Transform:SetRotation(inst.Transform:GetRotation())
                    if newbot.components.fueled and inst.components.fueled then
                        newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                    end
                    if inst.components.health and newbot.components.health then
                        newbot.components.health:SetCurrentHealth(
                            math.min(inst.components.health.currenthealth,
                                     newbot.components.health.maxhealth))
                    end
                end
            end
            inst:Remove()
        end

        inst:AddComponent("hauntable")
        inst.components.hauntable:SetOnHauntFn(function(inst, haunter)
            if haunter:HasTag("playerghost") and inst.prefab == "williambutler3" then
                local owner = GetOwner(inst)
                -- v2.0.17 BUGFIX: check tags on BOTH owner and haunter. The follower
                -- leader (owner) can be nil when the owner is dead; the haunter (the
                -- ghost player) is always valid and its affinity tags persist through
                -- death. This was the root cause of "shadow affinity revive doesn't work".
                local shadow = (owner and owner:HasTag("wagstaff_shadow_possession"))
                            or haunter:HasTag("wagstaff_shadow_possession")
                local celestial = (owner and owner:HasTag("wagstaff_celestial_possession"))
                              or haunter:HasTag("wagstaff_celestial_possession")

                _dbgF("[BUTLER REVIVE] haunt by ghost=%s owner=%s shadow=%s celestial=%s",
                    tostring(haunter and haunter.prefab),
                    tostring(owner and owner.prefab or "NIL"),
                    tostring(shadow), tostring(celestial))

                -- Standard revive (player respawns)
                haunter:PushEvent("respawnfromghost", { source = inst })

                -- v2.0.17 SHADOW (all day): consume haunter's meat_effigy, butler survives
                if shadow then
                    local found = FindAndConsumeEffigy(haunter)
                    _dbgF("[BUTLER REVIVE] SHADOW path: effigy_found=%s", tostring(found))
                    if found then
                        -- Butler survives! Bonus sanity (+30% max)
                        haunter:DoTaskInTime(0.5, function()
                            if haunter:IsValid() and haunter.components.sanity then
                                local bonus_sanity = haunter.components.sanity.max * 0.3
                                haunter.components.sanity:DoDelta(bonus_sanity)
                                _dbgF("[BUTLER REVIVE] SHADOW: +%.0f sanity applied", bonus_sanity)
                            end
                        end)
                        -- Bot does NOT die — effigy took its place
                        return true
                    end
                    -- No effigy found — fall through to default (bot dies)
                end

                -- v2.0.17 CELESTIAL (all day): FULL DISCHARGE + downgrade to MK1,
                -- 1/day cooldown, butler survives as inert MK1. Celestial soul FX.
                if celestial then
                    local today = TheWorld.state.cycles
                    local player_for_cd = owner or haunter
                    local last_day = player_for_cd and player_for_cd._celestial_butler_revive_day or -1
                    _dbgF("[BUTLER REVIVE] CELESTIAL path: today=%s last_day=%s",
                        tostring(today), tostring(last_day))
                    if last_day ~= today then
                        -- Cooldown available — use it
                        if player_for_cd then player_for_cd._celestial_butler_revive_day = today end
                        -- Celestial "soul leaving" discharge FX (NOT shadow)
                        local pt = inst:GetPosition()
                        PlayCelestialDischargeFX(pt)
                        -- Bonus HP (+20% max)
                        haunter:DoTaskInTime(0.5, function()
                            if haunter:IsValid() and haunter.components.health then
                                local bonus_hp = haunter.components.health.maxhealth * 0.2
                                haunter.components.health:DoDelta(bonus_hp)
                                _dbgF("[BUTLER REVIVE] CELESTIAL: +%.0f HP applied", bonus_hp)
                            end
                        end)
                        -- Downgrade butler to MK1 with FULL DISCHARGE (fuel -> 0)
                        haunter:DoTaskInTime(1.0, function()
                            if inst:IsValid() then
                                DowngradeButlerToMK1(inst, owner, true)
                                _dbg("[BUTLER REVIVE] CELESTIAL: downgraded to MK1, fuel=0 (discharged)")
                            end
                        end)
                        return true
                    end
                    -- On cooldown — fall through to default (bot dies)
                    _dbg("[BUTLER REVIVE] CELESTIAL: on cooldown, falling to default")
                end

                -- Default: bot dies on revive (no affinity, or affinity fallback)
                _dbg("[BUTLER REVIVE] DEFAULT path: butler dies")
                inst.components.health:Kill()
                return true
            end
            return false
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
                    if inst2.Light then inst2.Light:Enable(true); inst2.Light:SetRadius(2); inst2.Light:SetIntensity(0.45); inst2.Light:SetColour(0.7,0.85,1) end
                    if inst2.on ~= false and (inst2._aura_fx == nil or not inst2._aura_fx:IsValid()) then
                        inst2._aura_fx = SpawnPrefab("bot_aura_buster")
                        if inst2._aura_fx then inst2._aura_fx._parent = inst2 end
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

        -- Repair system for MK3 + MK.III upgrade (60 scraps from MK.II to MK.III only - not applicable here since we spawn directly)
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
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end
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

-- EMPTY butler


    local function empty(inst)
        local inst = fn(inst)

        inst.AnimState:PlayAnimation("sleep_loop", false)
        inst.AnimState:Pause()
        MakeCharacterPhysics(inst, 80, .25)
        inst.Physics:SetFriction(1)

        inst:AddTag("NOBLOCK")
        inst:AddTag("Notarget")
        inst:AddTag("mech")
        inst:AddTag("butler")
        inst:AddTag("tiddlevirusimmune")

        if not TheWorld.ismastersim then
            return inst
        end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
            inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

--    inst.components.fueled.currentfuel = 0

    inst.components.lootdropper:SetChanceLootTable("butlergadget")

    -- BUG FIX 5: Add fuel listener to enable ACTIVATE when refueled
    inst.components.fueled.accepting = true
    inst:ListenForEvent("percentusedchange", function(inst)
        local fuel_pct = inst.components.fueled:GetPercent()
        if fuel_pct > 0 and fuel_pct <= 1 then
            -- Has fuel now, enable ACTIVATE
            if inst.components.workable and inst.components.workable.action ~= ACTIONS.ACTIVATE then
                inst:RemoveComponent("workable")
                inst:AddComponent("workable")
                inst.components.workable:SetWorkAction(ACTIONS.ACTIVATE)
                inst.components.workable:SetWorkLeft(1)
                inst.components.workable:SetOnFinishCallback(function(inst, doer)
                    if doer and doer.components.petleash then
                        MakeAlive(inst, doer)
                    end
                end)
            end
        end
    end)

    -- Save/load husk state (for reactivating at correct level)
    local function OnSaveHusk(inst, data)
        data.was_level2 = inst.was_level2
        data.was_mk3 = inst.was_mk3
        data.saved_upgradelevel = inst.saved_upgradelevel
        data.saved_upgradelevel_mk3 = inst.saved_upgradelevel_mk3
    end

    local function OnLoadHusk(inst, data)
        if data then
            inst.was_level2 = data.was_level2 or false
            inst.was_mk3 = data.was_mk3 or false
            inst.saved_upgradelevel = data.saved_upgradelevel or 0
            inst.saved_upgradelevel_mk3 = data.saved_upgradelevel_mk3 or 0
        end
    end

    inst.OnSave = OnSaveHusk
    inst.OnLoad = OnLoadHusk

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
   local pet = builder:HasTag("williamcrafter") and builder.components.petleash:SpawnPetAt(pt.x, 0, pt.z, "williambutler") or SpawnPrefab("williambutler_empty")
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

        inst.OnBuiltFn = onbuilt

        return inst
    end


    return Prefab("williambutler", active, assets, prefabs),
    Prefab("williambutler2", active2, assets, prefabs),
    Prefab("williambutler3", active3, assets, prefabs),
    Prefab("williambutler_builder", builder, assets, prefabs),
    Prefab("williambutler_empty", empty, assets, prefabs)



--------------------------------------------------------------------------