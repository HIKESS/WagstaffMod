require "prefabutil"

local _G = _G or GLOBAL
local AffinityPulse = _G.AffinityPulse

local assets =
{
    Asset("ANIM", "anim/dispenser.zip"),
    Asset("ANIM", "anim/dispenser_meter.zip"),
    Asset("ANIM", "anim/swap_engie_building.zip"),
    Asset("ANIM", "anim/esentry_item.zip"),
}

local prefabs =
{
    "collapse_small",
    "scrap",
    "ehealfx",
}

local fuel =
{
    twigs = 1,
    cutgrass = 1,
    log = 1,
    charcoal = .5,
}
local mineral =
{
    flint = 1,
    rocks = 1,
    nitre = .3,
    marble = .1,
}
local night =
{
    lightbulb = .2,
    wormlight = .1,
    nightmarefuel = .1,
}
local rare =
{
    goldnugget = 1,
    gunpowder = .5,
    gears = .3,
    livinglog = .1,
}

local lucky_rare =
{
    { item = "gears", weight = 25 },
    { item = "purplegem", weight = 18 },
    { item = "bluegem", weight = 15 },
    { item = "redgem", weight = 15 },
    { item = "thulecite", weight = 10 },
    { item = "yellowgem", weight = 7 },
    { item = "orangegem", weight = 5 },
    { item = "greengem", weight = 2.5 },
    { item = "ancient_blueprint", weight = 1.5 },
    { item = "opalpreciousgem", weight = 1 },
}

local function weighted_random_choice(items)
    local total = 0
    for _, v in ipairs(items) do
        total = total + v.weight
    end
    local rand = math.random() * total
    for _, v in ipairs(items) do
        rand = rand - v.weight
        if rand <= 0 then
            return v.item
        end
    end
    return items[1].item
end

local function TryLuckyDrop(inst)
    local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
    if builder and builder:HasTag("wagstaff_lucky_engineer") then
        if math.random() < 0.15 then
            local item = weighted_random_choice(lucky_rare)
            inst.components.lootdropper:SpawnLootPrefab(item)
            return true
        end
    end
    return false
end

local UpdateDispenserName
local setmeterlevl
local upgrade

local function onbuilt(inst, builder)
    if builder and builder.engieID then
        inst.dispenserID = builder.engieID
        builder:PushEvent("engiebuilding")
        if builder.components.talker ~= nil then
            builder.components.talker:Say(_G.GetString(builder, "ANNOUNCE_DISPENSERBUILT"))
        end
        inst.components.entitytracker:TrackEntity("builder", builder)
    end
    inst.maker = builder and builder.name or "unknown"
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", true)
    inst.SoundEmitter:PlaySound("dontstarve/common/lightning_rod_craft")
    inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() / 3, function()
        inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod")
    end)
    UpdateDispenserName(inst)
end

function upgrade(inst)
    if inst.upgradelevel == 30 or inst.upgradelevel == 70 then
        inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup", "sound")
        inst:DoTaskInTime(.75, function()
            inst.SoundEmitter:KillSound("sound")
        end)
    end
    if inst.upgradelevel >= 30 and inst.upgradelevel < 70 then
        inst:AddTag("lvl2")
        inst:RemoveTag("lvl1")
        inst.AnimState:PlayAnimation("upgrade2")
        inst.AnimState:PushAnimation("idle_2", true)
        UpdateDispenserName(inst)
    end
    if inst.upgradelevel >= 70 then
        inst:AddTag("lvl3")
        inst:RemoveTag("lvl1")
        inst:RemoveTag("lvl2")
        inst.AnimState:PlayAnimation("upgrade3")
        inst.AnimState:PushAnimation("idle_3", true)
        -- Mk.III: double max fuel to 8
        inst.components.fueled.maxfuel = 8
        UpdateDispenserName(inst)
        -- MK3 affinity auras (setup once)
        if not inst._mk3_aura_setup then
            inst._mk3_aura_setup = true
            inst._healfx = nil

            local function GetBuilder(inst)
                -- Primeiro tenta entitytracker
                local builder = inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")
                if builder and builder:IsValid() then return builder end
                -- Fallback: busca jogador com afinidade mais próximo (como os bots MK2 fazem)
                local x, y, z = inst.Transform:GetWorldPosition()
                local players = _G.TheSim:FindEntities(x, y, z, 40, {"player"})
                local closest = nil
                local closest_dist = math.huge
                for _, p in ipairs(players) do
                    if p:HasTag("wagstaff_celestial_possession") or p:HasTag("wagstaff_shadow_possession") then
                        local dist = inst:GetDistanceSqToInst(p)
                        if dist < closest_dist then
                            closest = p
                            closest_dist = dist
                        end
                    end
                end
                return closest
            end

            -- Affinity pulse visual (shared module)
            AffinityPulse.Setup(inst, GetBuilder)

            -- Spawn/remove healfx based on affinity, color per affinity
            local function UpdateAuraFX(inst)
                local builder = GetBuilder(inst)
                local celestial = builder and builder:HasTag("wagstaff_celestial_possession")
                local shadow    = builder and builder:HasTag("wagstaff_shadow_possession")
                local active = (TheWorld.state.isday and celestial) or (TheWorld.state.isdusk and shadow)

                if active then
                    if inst._healfx == nil then
                        local x, y, z = inst.Transform:GetWorldPosition()
                        inst._healfx = _G.SpawnPrefab("ehealfx")
                        inst._healfx.Transform:SetPosition(x, 1, z)
                        local follower = inst._healfx.entity:AddFollower()
                        follower:FollowSymbol(inst.GUID, "placer", 205, 140, 1)
                    end
                    -- Celestial: blue-white tint; Shadow: purple tint
                    if TheWorld.state.isday and celestial then
                        inst._healfx.AnimState:SetMultColour(0.4, 0.7, 1.0, 1)
                        inst.Light:SetColour(0.4, 0.7, 1.0)
                    elseif TheWorld.state.isdusk and shadow then
                        inst._healfx.AnimState:SetMultColour(0.6, 0.1, 0.8, 1)
                        inst.Light:SetColour(0.5, 0.0, 0.7)
                    end
                    inst._healfx:Show()
                    inst.Light:Enable(true)
                else
                    if inst._healfx ~= nil then
                        inst._healfx:Hide()
                    end
                    inst.Light:Enable(false)
                end
            end

            -- Sanity aura component for celestial (day)
            inst:AddComponent("sanityaura")
            inst.components.sanityaura.aura = 0

            inst:DoPeriodicTask(_G.TUNING.DISP_HEALING, function()
                local builder = GetBuilder(inst)
                local celestial = builder and builder:HasTag("wagstaff_celestial_possession")
                local shadow    = builder and builder:HasTag("wagstaff_shadow_possession")

                -- Update FX
                UpdateAuraFX(inst)

                -- CELESTIAL (day): Sanity aura 2/tick
                if TheWorld.state.isday and celestial then
                    inst.components.sanityaura.aura = _G.TUNING.SANITYAURA_SMALL
                    -- HP heal as bonus too? No — only sanity per spec
                else
                    inst.components.sanityaura.aura = 0
                end

                -- SHADOW (dusk): HP heal 1/tick to nearby players/willminions
                if TheWorld.state.isdusk and shadow then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    _G.FindEntity(inst, _G.TUNING.DISP_RANGE, function(guy)
                        if guy and guy:HasTag("player") and guy.components.health
                            and not guy.components.health:IsDead()
                            and guy.components.health.currenthealth < guy.components.health.maxhealth then
                            guy.components.health:DoDelta(1, true, nil, true)
                        end
                    end, {"player"}, {"INLIMBO"})
                end
            end)

            -- Cleanup on remove
            inst:ListenForEvent("onremove", function()
                if inst._healfx ~= nil and inst._healfx:IsValid() then
                    inst._healfx:Remove()
                end
            end)
        end
    end
end

function setmeterlevl(inst)
    local fuel = math.floor(inst.components.fueled.currentfuel + 0.5)
    local maxfuel = inst.components.fueled.maxfuel
    if fuel <= 0 then
        inst.AnimState:OverrideSymbol("placer", "dispenser_meter", "0")
    elseif fuel <= maxfuel * 0.25 then
        inst.AnimState:OverrideSymbol("placer", "dispenser_meter", "25")
    elseif fuel <= maxfuel * 0.5 then
        inst.AnimState:OverrideSymbol("placer", "dispenser_meter", "50")
    elseif fuel <= maxfuel * 0.75 then
        inst.AnimState:OverrideSymbol("placer", "dispenser_meter", "75")
    else
        inst.AnimState:OverrideSymbol("placer", "dispenser_meter", "100")
    end
end

function UpdateDispenserName(inst)
    local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
    local fuel = math.floor(inst.components.fueled.currentfuel + 0.5)
    if builder or inst.maker then
        if inst:HasTag("lvl3") then
            inst.components.named:SetName(_G.subfmt("Dispenser built by {builder}\n(Level 3) Fuel: "..fuel.."/"..inst.components.fueled.maxfuel, { builder = inst.maker }))
        else
            inst.components.named:SetName(_G.subfmt("Dispenser built by {builder}\nUpgrade "..inst.upgradelevel.." / 70 | Fuel: "..fuel.."/"..inst.components.fueled.maxfuel, { builder = inst.maker }))
        end
    else
        if inst:HasTag("lvl3") then
            inst.components.named:SetName("Dispenser\n(Level 3) Fuel: "..fuel.."/"..inst.components.fueled.maxfuel)
        else
            inst.components.named:SetName("Dispenser\nUpgrade "..inst.upgradelevel.." / 70 | Fuel: "..fuel.."/"..inst.components.fueled.maxfuel)
        end
    end
end

local function IsScrap(item)
    return item.prefab == "scrap"
end

local function workup(inst, worker)
    local scrapstack = worker.components.inventory:FindItem(IsScrap)
    if scrapstack ~= nil then
        local next_level = inst.upgradelevel + 1
        if next_level == 30 and not _G.WagstaffHasSkill(worker, "wagstaff_dispenser_mk2") then
            if worker.components.talker then
                worker.components.talker:Say("Requires Dispenser MK.II skill!")
            end
            return
        end
        if next_level == 70 and not _G.WagstaffHasSkill(worker, "wagstaff_dispenser_mk3") then
            if worker.components.talker then
                worker.components.talker:Say("Requires Dispenser MK.III skill!")
            end
            return
        end
        local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
        if upgrade_cost > 0 then
            worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
        end
        inst.upgradelevel = inst.upgradelevel + 1
        if inst.upgradelevel == 30 or inst.upgradelevel == 70 then
            upgrade(inst)
        end
        UpdateDispenserName(inst)
    end
end

local function onhammered(inst)
    inst.components.lootdropper:DropLoot()
    local fx = _G.SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
    for k,v in pairs(_G.Ents) do
        if v and v.engieID == inst.dispenserID then
            v:PushEvent("engiebuilding")
            if v.components.sanity ~= nil then
                v.components.sanity:DoDelta(-_G.TUNING.ENGIE_BUILDINGLOSS)
            end
            if v.components.talker ~= nil then
                v.components.talker:Say(_G.GetString(v, "ANNOUNCE_DISPENSER_DOWN"))
            end
        end
    end
end

local function onhit(inst, worker)
    if not (worker:HasTag("engie") or worker:HasTag("spy") or worker:HasTag("engie_pardner")) then
        inst.components.workable:SetWorkLeft(6)
    end
    setmeterlevl(inst)
    if inst:HasTag("lvl1") then
        inst.AnimState:PlayAnimation("hit")
    end
    if inst:HasTag("lvl2") then
        inst.AnimState:PlayAnimation("hit_2")
    end
    if inst:HasTag("lvl3") then
        inst.AnimState:PlayAnimation("hit_3")
    end
end

local function OnWrenchWork(inst, worker)
    if inst:HasTag("lvl1") then
        inst.AnimState:PlayAnimation("hit")
    elseif inst:HasTag("lvl2") then
        inst.AnimState:PlayAnimation("hit_2")
    elseif inst:HasTag("lvl3") then
        inst.AnimState:PlayAnimation("hit_3")
    end

    if worker.replica.inventory ~= nil and worker.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS) ~= nil and worker.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS).prefab == "tf2wrench" then
        worker.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS).components.finiteuses:Use(1)
    end

    local scrapstack = worker.components.inventory:FindItem(IsScrap)

    if scrapstack ~= nil and inst.components.fueled.currentfuel < inst.components.fueled.maxfuel then
        local refuel_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
        if refuel_cost > 0 then
            worker.components.inventory:ConsumeByName("scrap", refuel_cost)
        end
        inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
        inst.components.fueled.currentfuel = inst.components.fueled.currentfuel + 1
        setmeterlevl(inst)
        UpdateDispenserName(inst)
        return
    end

    if not inst:HasTag("NOLEVEL") and not inst:HasTag("lvl3") and scrapstack ~= nil then
        inst.tick = 0
        while inst.tick ~= 5 and not inst:HasTag("lvl3") do
            workup(inst, worker)
            inst.tick = inst.tick + 1
        end
    end
end

local function dispenseitem(inst, phase, cavephase)
    local item = nil
    if inst.components.fueled.currentfuel ~= 0 then
        inst:DoTaskInTime(5, function()
            if inst:HasTag("lvl1") then
                if _G.TheWorld.state.isday then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    if math.random() < .33 then
                        inst.components.lootdropper:SpawnLootPrefab("scrap")
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
            end
            if inst:HasTag("lvl2") then
                if _G.TheWorld.state.isday then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    if math.random() < .33 then
                        inst.components.lootdropper:SpawnLootPrefab("scrap")
                        inst.components.lootdropper:SpawnLootPrefab("scrap")
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit_2")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
                if _G.TheWorld.state.isdusk then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    if math.random() < .33 then
                        inst.components.lootdropper:SpawnLootPrefab("scrap")
                        inst.components.lootdropper:SpawnLootPrefab("scrap")
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit_2")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
            end
            if inst:HasTag("lvl3") then
                if _G.TheWorld.state.isday then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    if math.random() < .33 then
                        item = _G.weighted_random_choice(rare)
                        inst.components.lootdropper:SpawnLootPrefab(item)
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit_3")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
                if _G.TheWorld.state.isdusk then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    if math.random() < .33 then
                        item = _G.weighted_random_choice(rare)
                        inst.components.lootdropper:SpawnLootPrefab(item)
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit_3")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
                if _G.TheWorld.state.isnight then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    if math.random() < .33 then
                        item = _G.weighted_random_choice(night)
                        inst.components.lootdropper:SpawnLootPrefab(item)
                        inst.components.lootdropper:SpawnLootPrefab(item)
                        item = _G.weighted_random_choice(rare)
                        inst.components.lootdropper:SpawnLootPrefab(item)
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit_3")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
            end
        end)
    end
end

local function onsave(inst, data)
    data.upgradelevel = inst.upgradelevel
    data.dispenserID = inst.dispenserID
    data.maker = inst.maker
    if inst.components.named then
        data.name = inst.components.named.name
    end
end

local function onload(inst, data)
    inst.upgradelevel = data.upgradelevel or 0
    inst.dispenserID = data.dispenserID
    inst.maker = data.maker or inst.maker
    upgrade(inst)
    setmeterlevl(inst)
    UpdateDispenserName(inst)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")

    if _G.TheWorld:HasTag("cave") then
        inst:WatchWorldState("cavephase", dispenseitem)
    end
    if not _G.TheWorld:HasTag("cave") then
        inst:WatchWorldState("phase", dispenseitem)
    end

    if owner.components.talker ~= nil then
        owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_REPLANTING"))
    end
    inst.SoundEmitter:PlaySound("dontstarve/common/lightning_rod_craft")

    if inst:HasTag("lvl1") then
        inst.AnimState:PlayAnimation("place")
    end
    if inst:HasTag("lvl2") then
        inst.AnimState:PlayAnimation("upgrade2")
    end
    if inst:HasTag("lvl3") then
        inst.AnimState:PlayAnimation("upgrade2")
        inst.AnimState:PlayAnimation("upgrade3", false)
    end
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "swap_engie_building", "swap_body")

    if _G.TheWorld:HasTag("cave") then
        inst:StopWatchingWorldState("cavephase", dispenseitem)
    end
    if not _G.TheWorld:HasTag("cave") then
        inst:StopWatchingWorldState("phase", dispenseitem)
    end

    inst.Light:Enable(false)

    if owner.components.health ~= nil and not owner.components.health:IsDead() then
        owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_PACKINGUP"))
    end
end

local function onremoved(inst)
    for k,v in pairs(_G.Ents) do
        if v and v.engieID == inst.dispenserID then
            v:PushEvent("engiebuilding")
        end
    end
end

local function fn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()
    inst.MiniMapEntity:SetIcon("dispenser.tex")

    _G.MakeObstaclePhysics(inst, .4)

    inst.no_wet_prefix = true

    inst:AddTag("structure")
    inst:AddTag("eyeturret")
    inst:AddTag("dispenser")
    inst:AddTag("ebuild_wrenchable")
    inst:AddTag("lvl1")
    inst:AddTag("ebuild")
    inst:AddTag("nonpotatable")
    inst:AddTag("heavy")

    inst.AnimState:SetBank("dispenser")
    inst.AnimState:SetBuild("dispenser")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:OverrideSymbol("placer", "dispenser_meter", "100")

    inst.entity:SetPristine()

    if not _G.TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("named")
    inst.components.named:SetName("Dispenser")
    inst:AddComponent("entitytracker")

    inst:AddComponent("engieworkable")
    inst.components.engieworkable:SetWorkAction(_G.ACTIONS.ENGIEWORKABLE)
    inst.components.engieworkable:SetMaxWork(1)
    inst.components.engieworkable:SetWorkLeft(1)
    inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
        if inst:HasTag("lvl1") then
            inst.AnimState:PlayAnimation("hit")
        elseif inst:HasTag("lvl2") then
            inst.AnimState:PlayAnimation("hit_2")
        elseif inst:HasTag("lvl3") then
            inst.AnimState:PlayAnimation("hit_3")
        end
    end)
    inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
        inst.components.engieworkable:SetWorkLeft(1)
        OnWrenchWork(inst, worker)
    end)

    inst.Light:Enable(false)
    inst.Light:SetRadius(.6)
    inst.Light:SetFalloff(1)
    inst.Light:SetIntensity(.5)
    inst.Light:SetColour(235/255, 62/255, 12/255)

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.PIGTORCH
    inst.components.fueled:InitializeFuelLevel(4)
    inst.components.fueled.accepting = false

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(_G.ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:ListenForEvent("onremove", onremoved)

    inst:AddComponent("symbolswapdata")
    inst.components.symbolswapdata:SetData("swap_engie_building", "swap_body")

    inst.upgradelevel = 0

    inst.OnSave = onsave
    inst.OnLoad = onload
    inst.OnBuiltFn = onbuilt

    inst:DoTaskInTime(0, function(inst)
        setmeterlevl(inst)
        UpdateDispenserName(inst)
    end)

    if not inst.components.inventoryitem then
        inst:AddComponent("inventoryitem")
    end
    inst.components.inventoryitem.atlasname = _G.ENGINEERITEMIMAGES
    inst.components.inventoryitem.cangoincontainer = false
    inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem.imagename = "esentry_item"
    inst.components.inventoryitem.nobounce = true
    if inst.replica.inventoryitem then
        if inst.replica.inventoryitem.SetAtlas then
            inst.replica.inventoryitem:SetAtlas(_G.ENGINEERITEMIMAGES)
        end
        inst.replica.inventoryitem:SetImage("esentry_item")
    end

    inst:AddComponent("heavyobstaclephysics")
    inst.components.heavyobstaclephysics:SetRadius(1)
    inst.components.heavyobstaclephysics:MakeSmallObstacle()

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = _G.EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = _G.TUNING.TOOLBOX_SPEED_MULT
    inst.components.equippable.restrictedtag = "engie"

    if _G.TheWorld:HasTag("cave") then
        inst:WatchWorldState("cavephase", dispenseitem)
    end
    if not _G.TheWorld:HasTag("cave") then
        inst:WatchWorldState("phase", dispenseitem)
    end


    _G.MakeHauntableFreeze(inst)

    return inst
end

local function healfxfn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddPhysics()
    inst.entity:AddNetwork()

    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("fireflies")
    inst.AnimState:SetBuild("fireflies")
    inst.AnimState:PlayAnimation("swarm_pre")
    inst.AnimState:PushAnimation("swarm_loop", true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(1)

    inst.persists = false
    inst.AnimState:SetMultColour(200/255, 50/255, 50/255, 1)

    return inst
end

return _G.Prefab("common/dispenser", fn, assets, prefabs),
    _G.Prefab("ehealfx", healfxfn, assets)
