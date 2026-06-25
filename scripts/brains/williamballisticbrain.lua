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

--Images will help chop, mine and fight.

local MIN_FOLLOW_DIST = 0
local TARGET_FOLLOW_DIST = 7
local MAX_FOLLOW_DIST = 10

local MAX_CHASE_TIME = 15
local MAX_CHASE_DIST = 20

local START_FACE_DIST = 5
local KEEP_FACE_DIST = 20

local KEEP_WORKING_DIST = 14
local SEE_WORK_DIST = 10

local KEEP_DANCING_DIST = 3

local RUN_START_DIST = 10
local RUN_STOP_DIST = 15 
local KITING_DIST = 10
local STOP_KITING_DIST = 15

local RUN_AWAY_DIST = 12
local STOP_RUN_AWAY_DIST = 15

local AVOID_EXPLOSIVE_DIST = 5

local DIG_TAGS = { "stump", "grave" }

local function GetLeader(inst)
    local leader = inst.components.follower.leader
    if leader and leader:IsValid() and leader.Transform then
        return leader
    end
    return nil
end

local function GetLeaderPos(inst)
    local leader = GetLeader(inst)
    if leader then
        return leader:GetPosition()
    end
    return nil
end

local function GetFaceTargetFn(inst)
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local function IsNearLeader(inst, dist)
    local leader = GetLeader(inst)
    return leader ~= nil and inst:IsNear(leader, dist)
end

local function KeepFaceTargetFn(inst, target)
    return not target:HasTag("notarget") and inst:IsNear(target, KEEP_FACE_DIST)
end

local function DanceParty(inst)
    inst:PushEvent("dance")
end

local function ShouldDanceParty(inst)
    local leader = GetLeader(inst)
    return leader ~= nil and leader.sg:HasStateTag("dancing")
end

local function ShouldAvoidExplosive(target)
    return target.components.explosive == nil
        or target.components.burnable == nil
        or target.components.burnable:IsBurning()
end

local function ShouldRunAway(target)
    return not (target.components.health ~= nil and target.components.health:IsDead())
        and (not target:HasTag("shadowcreature") or (target.components.combat ~= nil and target.components.combat:HasTarget()))
end

local function ShouldKite(target, inst)
    return inst.components.combat:TargetIs(target)
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

local function ShouldWatchMinigame(inst)
        if inst.components.follower.leader ~= nil and inst.components.follower.leader.components.minigame_participator ~= nil then
                if inst.components.combat.target == nil or inst.components.combat.target.components.minigame_participator ~= nil then
                        return true
                end
        end
        return false
end

local function WatchingMinigame(inst)
        return (inst.components.follower.leader ~= nil and inst.components.follower.leader.components.minigame_participator ~= nil) and inst.components.follower.leader.components.minigame_participator:GetMinigame() or nil
end

local function ShouldRunAway(guy)
    return not (guy:HasTag("player") or guy:HasTag("companion"))
end

local function CanAttackNow(inst)
    return inst.components.combat.target == nil or not inst.components.combat:InCooldown()
end

function WilliamBallisticBrain:OnStart()
    local is_turret = self.inst:HasTag("ballistic_turret")
    local has_leader = not is_turret and self.inst.components.follower ~= nil and self.inst.components.follower:GetLeader() ~= nil

    local root
    if has_leader then
        -- Mobile mode: follow leader, chase and attack enemies
        root = PriorityNode(
        {
            -- v2.0.65 FIX: When deactivated (inst.on == false), do NOT follow/chase.
            -- The Follow behaviour's catch-up teleport was teleporting the
            -- deactivated bot to the player. StandStill blocks all movement nodes.
            WhileNode(function() return self.inst.on == false end, "Deactivated",
                StandStill(self.inst)),

            WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
            WhileNode(function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
            ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST),
            Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
            FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
        }, .25)
    else
        -- Stationary mode: stand and attack only
        root = PriorityNode(
        {
            -- v2.0.65 FIX: When deactivated (inst.on == false), do NOT attack.
            WhileNode(function() return self.inst.on == false end, "Deactivated",
                StandStill(self.inst)),

            StandAndAttack(self.inst),
        }, .25)
    end

    self.bt = BT(self.inst, root)
end

return WilliamBallisticBrain
