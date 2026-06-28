require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/standandattack"
require "behaviours/chaseandattack"
require "behaviours/panic"
require "behaviours/follow"
require "behaviours/attackwall"
require "behaviours/standstill"
require "behaviours/leash"

local WilliamBallisticBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

-- Ballistic Bot is a TURRET — it never follows or chases.
-- v2.0.89 FIX: Removed Follow/ChaseAndAttack behaviors entirely.
-- The Ballistic is a stationary ranged turret (like Winona's Catapult).
-- It stands still and attacks enemies within range. Even MK3, despite having
-- a follower component for owner tracking (affinity/special attacks), must
-- remain fixed at its deployed position. The old mobile mode caused MK2/MK3
-- to follow the player or chase enemies, which is incorrect for a turret.

local START_FACE_DIST = 5
local KEEP_FACE_DIST = 20

local function GetFaceTargetFn(inst)
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local function KeepFaceTargetFn(inst, target)
    return not target:HasTag("notarget") and inst:IsNear(target, KEEP_FACE_DIST)
end

function WilliamBallisticBrain:OnStart()
    -- v2.0.89: Ballistic is ALWAYS a turret. No mobile mode.
    -- StandAndAttack: stands still and attacks the current combat target.
    -- If no target, faces nearby players (cosmetic).
    local root = PriorityNode(
    {
        -- v2.0.65 FIX: When deactivated (inst.on == false), do NOT attack.
        WhileNode(function() return self.inst.on == false end, "Deactivated",
            StandStill(self.inst)),

        WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
        WhileNode(function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
        StandAndAttack(self.inst),
        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
    }, .25)

    self.bt = BT(self.inst, root)
end

return WilliamBallisticBrain
