-- affinity_pulse.lua
-- Shared affinity visual pulse system for all Wagstaff bots and sentry guns.
-- Usage: local AffinityPulse = require("imports/affinity_pulse")
--        AffinityPulse.Setup(inst, GetOwnerFn)

local AffinityPulse = {}

-- Celestial gradient: 5-step warm electric blue-white pulse
-- Steps go from a soft cyan tint → bright electric white-blue peak
local CELESTIAL_STEPS = {
    { add = { 0.04, 0.07, 0.18, 0 }, mul = { 0.85, 0.90, 1.0,  1 } },
    { add = { 0.07, 0.12, 0.28, 0 }, mul = { 0.90, 0.95, 1.0,  1 } },
    { add = { 0.10, 0.18, 0.38, 0 }, mul = { 0.95, 0.98, 1.0,  1 } },
    { add = { 0.13, 0.22, 0.44, 0 }, mul = { 1.0,  1.0,  1.0,  1 } },
    { add = { 0.16, 0.26, 0.50, 0 }, mul = { 1.0,  1.0,  1.0,  1 } },
}

-- Shadow gradient: 5-step dark violet-purple pulse with alpha fade
-- Steps go from near-solid dark → semi-transparent deep purple peak
local SHADOW_STEPS = {
    { add = { 0.08, 0.0,  0.12, 0 }, mul = { 0.55, 0.45, 0.60, 1.0  } },
    { add = { 0.12, 0.0,  0.18, 0 }, mul = { 0.45, 0.35, 0.52, 0.92 } },
    { add = { 0.16, 0.0,  0.24, 0 }, mul = { 0.35, 0.25, 0.44, 0.82 } },
    { add = { 0.12, 0.0,  0.18, 0 }, mul = { 0.45, 0.35, 0.52, 0.88 } },
    { add = { 0.08, 0.0,  0.12, 0 }, mul = { 0.55, 0.45, 0.60, 0.95 } },
}

local PULSE_PERIOD = 0.18 -- seconds per step

function AffinityPulse.Setup(inst, GetOwnerFn)
    inst._aff_step  = 1
    inst._aff_dir   = 1  -- 1 = ascending, -1 = descending

    inst:DoPeriodicTask(PULSE_PERIOD, function()
        if not inst:IsValid() then return end
        local owner = GetOwnerFn and GetOwnerFn(inst)

        -- Skip shadow clones (they manage their own color)
        if inst:HasTag("shadow_buster_clone") then return end

        local isday  = TheWorld.state.isday
        local isdusk = TheWorld.state.isdusk
        local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
        local shadow    = owner and owner:HasTag("wagstaff_shadow_possession")

        if isday and celestial then
            local s = CELESTIAL_STEPS[inst._aff_step]
            inst.AnimState:SetAddColour(unpack(s.add))
            inst.AnimState:SetMultColour(unpack(s.mul))
        elseif isdusk and shadow then
            local s = SHADOW_STEPS[inst._aff_step]
            inst.AnimState:SetAddColour(unpack(s.add))
            inst.AnimState:SetMultColour(unpack(s.mul))
        else
            inst.AnimState:SetAddColour(0, 0, 0, 0)
            inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst._aff_step = 1
            inst._aff_dir  = 1
            return
        end

        -- Advance step (ping-pong 1→5→1)
        inst._aff_step = inst._aff_step + inst._aff_dir
        if inst._aff_step > #CELESTIAL_STEPS then
            inst._aff_step = #CELESTIAL_STEPS - 1
            inst._aff_dir  = -1
        elseif inst._aff_step < 1 then
            inst._aff_step = 2
            inst._aff_dir  = 1
        end
    end)
end

return AffinityPulse
