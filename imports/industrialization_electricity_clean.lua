-- Electricity Integration for Wagstaff Bots
-- Clean version without custom icon/sparkle logic
local GLOBAL = GLOBAL
local TheWorld = GLOBAL.TheWorld

-- Constants
local CHARGE_RADIUS = 10
local CHARGE_INTERVAL = 2
local BALLISTIC_CHARGE_CAP = 20

-- Storage for tracked entities
local generators = {}
local devices = {}

-- Helper functions
local function GetPosition(inst)
    if inst and inst:IsValid() then
        return inst.Transform:GetWorldPosition()
    end
    return nil
end

-- Main electricity distribution function
local function DistributePower()
    for gen_id, gen_data in pairs(generators) do
        local generator = gen_data.entity
        if not generator or not generator:IsValid() then
            generators[gen_id] = nil
            goto continue
        end
        
        if not generator.components.fueled or generator.components.fueled.currentfuel <= 0 then
            goto continue
        end
        
        local gen_x, gen_y, gen_z = GetPosition(generator)
        if not gen_x then goto continue end
        
        -- Find all devices in range
        local ents = TheSim:FindEntities(gen_x, gen_y, gen_z, CHARGE_RADIUS, {"electricity"}, {"FX", "NOCLICK", "DECOR", "INLIMBO"})
        
        for _, device in ipairs(ents) do
            if device and device:IsValid() and device.components.fueled then
                local fuelvalue = BALLISTIC_CHARGE_CAP
                
                -- Special handling for Ballistic Bot
                if device:HasTag("ballistic") then
                    fuelvalue = math.min(fuelvalue, BALLISTIC_CHARGE_CAP)
                end
                
                -- Charge the device
                device.components.fueled:DoDelta(fuelvalue)
                
                -- Visual feedback (original mod behavior)
                if device.SoundEmitter then
                    device.SoundEmitter:PlaySound("dontstarve/common/lightningrod")
                end
            end
        end
        
        ::continue::
    end
end

-- Register generator
local function RegisterGenerator(inst)
    if not inst or not inst:IsValid() then return end
    
    local id = inst.GUID or tostring(inst)
    generators[id] = {
        entity = inst,
        last_check = 0
    }
end

-- Register device (bot)
local function RegisterDevice(inst)
    if not inst or not inst:IsValid() then return end
    
    local id = inst.GUID or tostring(inst)
    devices[id] = {
        entity = inst
    }
end

-- Main update loop
local function OnUpdate(dt)
    local current_time = GetTime()
    
    -- Update generators
    for gen_id, gen_data in pairs(generators) do
        local generator = gen_data.entity
        if not generator or not generator:IsValid() then
            generators[gen_id] = nil
        end
    end
    
    -- Distribute power every CHARGE_INTERVAL seconds
    if current_time - (TheWorld._last_power_update or 0) >= CHARGE_INTERVAL then
        DistributePower()
        TheWorld._last_power_update = current_time
    end
end

-- World initialization
AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end
    
    inst:ListenForEvent("ms_newcycle", function()
        -- Clean up invalid entities
        for id, data in pairs(generators) do
            if not data.entity or not data.entity:IsValid() then
                generators[id] = nil
            end
        end
        for id, data in pairs(devices) do
            if not data.entity or not data.entity:IsValid() then
                devices[id] = nil
            end
        end
    end)
    
    -- Start update task
    inst:DoPeriodicTask(0.5, OnUpdate)
end)

-- Register generators (industrialization mod)
AddPrefabPostInit("industrialization_generator", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() RegisterGenerator(inst) end)
end)

-- Register Wagstaff bots
AddPrefabPostInit("william_buster", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() RegisterDevice(inst) end)
end)

AddPrefabPostInit("william_ballistic", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() RegisterDevice(inst) end)
end)

AddPrefabPostInit("william_butler", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() RegisterDevice(inst) end)
end)

AddPrefabPostInit("william_brute", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() RegisterDevice(inst) end)
end)

AddPrefabPostInit("william_bouncer", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() RegisterDevice(inst) end)
end)
