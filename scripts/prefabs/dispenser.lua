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
    "moonglass",
    "moon_moth",
    "nightmarefuel",
    "pure_horror",
    "dark_tatters",
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

-- v2.0.14: Level 2 affinity active drop tables (MK3 only, no dual affinity bonus)
local celestial_drops =
{
    { item = "moonglass",  weight = 60 },
    { item = "moon_moth",  weight = 40 },
}

local shadow_drops =
{
    { item = "nightmarefuel", weight = 50 },
    { item = "pure_horror",   weight = 30 },
    { item = "dark_tatters",  weight = 20 },
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
        -- v2.0.14: Lucky Engineer 15% -> 20% + golden FX feedback
        -- v2.0.44: 20% -> 30% to reach parity with sentry x2-Damage skill
        --          (x2-Damage post-ramp = +16-26% avg DPS; Lucky Engineer now
        --           ~0.9 rare drops/day vs 0.6, matching combat bonus value)
        if math.random() < 0.30 then
            local item = weighted_random_choice(lucky_rare)
            inst.components.lootdropper:SpawnLootPrefab(item)
            -- Golden FX so the player sees the lucky proc (reuses ehealfx with gold tint)
            local fx = _G.SpawnPrefab("ehealfx")
            if fx then
                local x, y, z = inst.Transform:GetWorldPosition()
                fx.Transform:SetPosition(x, 1.2, z)
                fx.AnimState:SetMultColour(1.0, 0.84, 0.0, 1) -- gold
                fx:DoTaskInTime(1.0, function()
                    if fx and fx:IsValid() then fx:Remove() end
                end)
            end
            inst.SoundEmitter:PlaySound("dontstarve/common/gemsparkle")
            return true
        end
    end
    return false
end

local UpdateDispenserName
local setmeterlevl
local upgrade

-- v2.0.42: Minimal interior light for MK2/MK3 dispenser. The MK3 affinity
-- aura light (radius 1.5-2.5) is a real, usable light source — but when the
-- affinity is inactive (wrong time of day / no affinity player nearby), MK3
-- had NO light at all while MK2 appeared to glow. This minimal light gives
-- MK2 and MK3 a subtle "powered on" interior glow for visual consistency,
-- but is intentionally too weak to exploit as a free light source:
--   radius 0.5  — Charlie requires ~1.5+ radius to be warded off, so this
--                  only illuminates the dispenser model itself, not the area.
--   intensity 0.4 — dim, just enough to read as "lit" on the sprite.
--   warm orange   — matches the dispenser's existing meter/UI color palette.
-- The MK3 affinity light overrides this when active (stronger radius/color).
local DISP_MINIMAL_LIGHT_RADIUS    = 0.5
local DISP_MINIMAL_LIGHT_INTENSITY = 0.4
local DISP_MINIMAL_LIGHT_FALLOFF   = 0.9
local DISP_MINIMAL_LIGHT_R         = 235/255
local DISP_MINIMAL_LIGHT_G         = 121/255
local DISP_MINIMAL_LIGHT_B         = 12/255

local function SetMinimalInteriorLight(inst)
    if not inst.Light then return end
    inst.Light:SetRadius(DISP_MINIMAL_LIGHT_RADIUS)
    inst.Light:SetIntensity(DISP_MINIMAL_LIGHT_INTENSITY)
    inst.Light:SetFalloff(DISP_MINIMAL_LIGHT_FALLOFF)
    inst.Light:SetColour(DISP_MINIMAL_LIGHT_R, DISP_MINIMAL_LIGHT_G, DISP_MINIMAL_LIGHT_B)
    inst.Light:Enable(true)
end

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
        -- Mk.II: max fuel 6 (was 4) — v2.0.14 balance
        inst.components.fueled.maxfuel = 6
        UpdateDispenserName(inst)
        -- v2.0.42: MK2 minimal interior light (visual glow, not exploitable).
        SetMinimalInteriorLight(inst)
    end
    if inst.upgradelevel >= 70 then
        inst:AddTag("lvl3")
        inst:RemoveTag("lvl1")
        inst:RemoveTag("lvl2")
        inst.AnimState:PlayAnimation("upgrade3")
        inst.AnimState:PushAnimation("idle_3", true)
        -- Mk.III: max fuel 10 (was 8) — v2.0.14 balance
        inst.components.fueled.maxfuel = 10
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
                    -- v2.0.44: Equalized light to radius 2.0 for BOTH affinities
                    -- (celestial was 2.5, shadow was 1.5). Intensity/falloff also
                    -- matched so neither affinity is a better free base light.
                    if TheWorld.state.isday and celestial then
                        inst._healfx.AnimState:SetMultColour(0.4, 0.7, 1.0, 1)
                        inst.Light:SetRadius(2.0)
                        inst.Light:SetIntensity(0.75)
                        inst.Light:SetFalloff(0.6)
                        inst.Light:SetColour(0.6, 0.8, 1.0)
                    elseif TheWorld.state.isdusk and shadow then
                        inst._healfx.AnimState:SetMultColour(0.6, 0.1, 0.8, 1)
                        inst.Light:SetRadius(2.0)
                        inst.Light:SetIntensity(0.75)
                        inst.Light:SetFalloff(0.6)
                        inst.Light:SetColour(0.5, 0.0, 0.7)
                    end
                    inst._healfx:Show()
                    inst.Light:Enable(true)
                else
                    if inst._healfx ~= nil then
                        inst._healfx:Hide()
                    end
                    -- v2.0.42: When affinity is inactive, fall back to the minimal
                    -- interior light (visual glow) instead of disabling the light
                    -- entirely. This keeps MK3 visually "lit" like MK2 without
                    -- providing a usable light source. The minimal light is too
                    -- weak (radius 0.5) to ward off Charlie or serve as a base
                    -- light — it only glows on the dispenser model itself.
                    SetMinimalInteriorLight(inst)
                end
            end

            -- Sanity aura component for celestial (day)
            inst:AddComponent("sanityaura")
            inst.components.sanityaura.aura = 0

            -- v2.0.14 Level 2 auras: TUNING.DISP_HEALING is 0.5s, so 2 HP/tick = 4 HP/sec shadow heal
            inst:DoPeriodicTask(_G.TUNING.DISP_HEALING, function()
                local builder = GetBuilder(inst)
                local celestial = builder and builder:HasTag("wagstaff_celestial_possession")
                local shadow    = builder and builder:HasTag("wagstaff_shadow_possession")

                -- Update FX
                UpdateAuraFX(inst)

                -- CELESTIAL (day): Sanity aura LARGE — v2.0.44 buffed MED -> LARGE
                -- to better match the value of shadow's HP heal (shadow was
                -- disproportionately strong despite the shorter dusk window).
                if TheWorld.state.isday and celestial then
                    inst.components.sanityaura.aura = _G.TUNING.SANITYAURA_LARGE
                else
                    inst.components.sanityaura.aura = 0
                end

                -- SHADOW (dusk): HP heal 1.5/tick (3 HP/sec) — builder only.
                -- v2.0.44 balance (Option B):
                --   (1) REDUCED 4 -> 3 HP/sec — 4 HP/sec was trivializing HP
                --       management during the entire dusk window.
                --   (2) FIXED RANGE BUG — GetBuilder() searches up to 40 units as
                --       a fallback when entitytracker fails, and the heal had NO
                --       distance check, so a builder could be healed from across
                --       the map. The original comment said "within DISP_RANGE"
                --       but the code never enforced it. Now explicitly checks
                --       builder is within DISP_RANGE (4 units) of the dispenser.
                if TheWorld.state.isdusk and shadow and builder ~= nil then
                    local in_range = inst:GetDistanceSqToInst(builder) <= (_G.TUNING.DISP_RANGE * _G.TUNING.DISP_RANGE)
                    if in_range
                        and builder.components.health
                        and not builder.components.health:IsDead()
                        and builder.components.health.currenthealth < builder.components.health.maxhealth then
                        builder.components.health:DoDelta(1.5, true, nil, true)
                    end
                end
            end)

            -- Cleanup on remove
            inst:ListenForEvent("onremove", function()
                if inst._healfx ~= nil and inst._healfx:IsValid() then
                    inst._healfx:Remove()
                end
            end)
        end
        -- v2.0.42: Set the minimal interior light immediately on MK3 upgrade.
        -- The aura task (DoPeriodicTask) first runs at +0.5s; until then this
        -- gives MK3 the same subtle glow MK2 has. UpdateAuraFX will override
        -- with the stronger affinity light when a celestial/shadow player is
        -- nearby, and fall back to this minimal light otherwise.
        SetMinimalInteriorLight(inst)
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
            -- Mk.I (day only) — v2.0.14 Option B: flat 3 scrap / 2 fuel / 2 mineral (was 2+33% / 1 / 1)
            if inst:HasTag("lvl1") then
                if _G.TheWorld.state.isday then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
                    item = _G.weighted_random_choice(fuel)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(mineral)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
            end
            -- Mk.II (day + dusk) — v2.0.14 Option B: flat 4 scrap / 3 fuel / 3 mineral (was 3+33% / 3 / 2)
            if inst:HasTag("lvl2") then
                if _G.TheWorld.state.isday or _G.TheWorld.state.isdusk then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
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
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    inst.components.fueled.currentfuel = inst.components.fueled.currentfuel - 1
                    inst.AnimState:PlayAnimation("hit_2")
                    TryLuckyDrop(inst)
                    setmeterlevl(inst)
                end
            end
            -- Mk.III (day + dusk + night) — v2.0.14 Option B:
            -- 4 scrap / 3 fuel / 3 mineral / 2 rare flat (was 2 / 2 / 2 / 33% chance 1)
            -- + 33% night-bonus (2 night items) on night cycle
            -- + Level 2 affinity active drops (33% per affinity phase, no dual affinity bonus)
            if inst:HasTag("lvl3") then
                if _G.TheWorld.state.isday or _G.TheWorld.state.isdusk or _G.TheWorld.state.isnight then
                    inst.components.lootdropper:SpawnLootPrefab("scrap")
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
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    -- 2 rare drops flat (was 33% chance for 1)
                    item = _G.weighted_random_choice(rare)
                    inst.components.lootdropper:SpawnLootPrefab(item)
                    item = _G.weighted_random_choice(rare)
                    inst.components.lootdropper:SpawnLootPrefab(item)

                    -- Night cycle bonus: 33% chance for 2 night-themed items
                    if _G.TheWorld.state.isnight then
                        if math.random() < .33 then
                            item = _G.weighted_random_choice(night)
                            inst.components.lootdropper:SpawnLootPrefab(item)
                            inst.components.lootdropper:SpawnLootPrefab(item)
                        end
                    end

                    -- Level 2 affinity active drops: 33% per cycle during the affinity's active phase
                    -- No dual affinity bonus — each phase only triggers its own affinity
                    local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
                    if builder then
                        if _G.TheWorld.state.isday and builder:HasTag("wagstaff_celestial_possession") then
                            if math.random() < 0.33 then
                                local drop = weighted_random_choice(celestial_drops)
                                inst.components.lootdropper:SpawnLootPrefab(drop)
                            end
                        elseif _G.TheWorld.state.isdusk and builder:HasTag("wagstaff_shadow_possession") then
                            if math.random() < 0.33 then
                                local drop = weighted_random_choice(shadow_drops)
                                inst.components.lootdropper:SpawnLootPrefab(drop)
                            end
                        end
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
    -- v2.0.42: Re-enable the minimal interior light when placed back in the
    -- world (onequip disabled it while carried). MK3's aura task will override
    -- with the affinity light within 0.5s if a celestial/shadow player is near.
    if inst:HasTag("lvl2") or inst:HasTag("lvl3") then
        SetMinimalInteriorLight(inst)
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
