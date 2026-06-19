-- Bot Charge FX Controller - Safe local version (no edits to industrialization_electricity.lua)
-- Icons and sparkles only when generator is ON and bot is in range

local CHARGE_RADIUS = 5
local CHARGE_RADIUS_OFF = 0.5
local CHECK_INTERVAL = 0.5
local SPARK_CHANCE = 0.3
local SOUND_INTERVAL = 5

-- Helper: Find nearest generator entity by common tags/prefabs
local function FindNearestGenerator(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    -- Try multiple possible generator tags/prefabs
    local generators = TheSim:FindEntities(x, y, z, CHARGE_RADIUS, {"generator"}, {"INLIMBO"})
    if #generators > 0 then
        return generators[1]
    end
    generators = TheSim:FindEntities(x, y, z, CHARGE_RADIUS, {"industrialization_generator"}, {"INLIMBO"})
    if #generators > 0 then
        return generators[1]
    end
    generators = TheSim:FindEntities(x, y, z, CHARGE_RADIUS, {"electricity"}, {"INLIMBO"})
    if #generators > 0 then
        return generators[1]
    end
    return nil
end

-- Helper: Check if generator is turned ON (safe checks)
local function IsGeneratorOn(gen)
    if not gen or not gen:IsValid() then return false end
    if gen:HasTag("turnedon") or gen:HasTag("on") then return true end
    if gen.components.machine and gen.components.machine.ison then return true end
    if gen.components.fueled and gen.components.fueled.consuming then return true end
    return false
end

-- Main controller: runs every CHECK_INTERVAL seconds on server
local function BotChargeController(inst)
    if not TheWorld.ismastersim then return end

    local generator = FindNearestGenerator(inst)
    local generator_on = IsGeneratorOn(generator)
    local current_radius = generator_on and CHARGE_RADIUS or CHARGE_RADIUS_OFF

    local in_range = false
    if generator and generator:IsValid() then
        local dist = inst:GetDistanceSqToPoint(generator.Transform:GetWorldPosition())
        in_range = dist <= current_radius * current_radius
    end

    -- Remove all effects if generator OFF or out of range
    if not generator_on or not in_range then
        if inst._charge_icon and inst._charge_icon:IsValid() then
            inst._charge_icon:Remove()
            inst._charge_icon = nil
        end
        if inst._charge_sparkles and inst._charge_sparkles:IsValid() then
            inst._charge_sparkles:Remove()
            inst._charge_sparkles = nil
        end
        return
    end

    -- Show charging icon (industrialization_fx_generator_energy)
    if not inst._charge_icon or not inst._charge_icon:IsValid() then
        local icon = SpawnPrefab("industrialization_fx_generator_energy")
        if icon then
            icon.entity:SetParent(inst.entity)
            inst._charge_icon = icon
        end
    end

    -- Continuous sparkles attached to bot (sparks prefab)
    if not inst._charge_sparkles or not inst._charge_sparkles:IsValid() then
        local sparkles = SpawnPrefab("sparks")
        if sparkles then
            sparkles.entity:SetParent(inst.entity)
            sparkles.Transform:SetPosition(0, 2, 0)
            inst._charge_sparkles = sparkles
        end
    end

    -- Periodic electric sparks (electrichitsparks)
    if math.random() < SPARK_CHANCE then
        local fx = SpawnPrefab("electrichitsparks")
        if fx then
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            fx:DoTaskInTime(0.5, function() fx:Remove() end)
        end
    end

    -- Charging sound every SOUND_INTERVAL seconds
    local now = GetTime()
    if not inst._last_charge_sound or (now - inst._last_charge_sound) > SOUND_INTERVAL then
        inst._last_charge_sound = now
        if inst.SoundEmitter then
            inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod", 0.5)
        end
    end
end

-- Attach controller to a bot prefab
local function AddChargeController(inst)
    if not TheWorld.ismastersim then return end

    -- Start periodic check
    inst._charge_task = inst:DoPeriodicTask(CHECK_INTERVAL, BotChargeController)

    -- Cleanup on remove
    inst:ListenForEvent("onremove", function(inst)
        if inst._charge_task then
            inst._charge_task:Cancel()
            inst._charge_task = nil
        end
        if inst._charge_icon and inst._charge_icon:IsValid() then
            inst._charge_icon:Remove()
        end
        if inst._charge_sparkles and inst._charge_sparkles:IsValid() then
            inst._charge_sparkles:Remove()
        end
    end)
end

-- Register for all relevant bot prefabs
AddPrefabPostInit("william_buster", AddChargeController)
AddPrefabPostInit("william_ballistic", AddChargeController)
AddPrefabPostInit("william_butler", AddChargeController)
AddPrefabPostInit("william_brute", AddChargeController)
AddPrefabPostInit("william_bouncer", AddChargeController)
