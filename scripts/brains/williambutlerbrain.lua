require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/panic"
require "behaviours/follow"
require "behaviours/attackwall"
require "behaviours/standstill"
require "behaviours/leash"
require "behaviours/runaway"

local WilliamButlerBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

--Images will help chop, mine and fight.

local MIN_FOLLOW_DIST = 0
local TARGET_FOLLOW_DIST = 3
local MAX_FOLLOW_DIST = 8

local START_FACE_DIST = 6
local KEEP_FACE_DIST = 8

local KEEP_WORKING_DIST = 8
local SEE_WORK_DIST = 6

local KEEP_DANCING_DIST = 2

local KITING_DIST = 3
local STOP_KITING_DIST = 5

local RUN_AWAY_DIST = 6
local STOP_RUN_AWAY_DIST = 10

local AVOID_EXPLOSIVE_DIST = 5

local SEE_TREE_DIST = 8
local SEE_TARGET_DIST = 20

local SEE_BURNING_HOME_DIST_SQ = 20*20

local COMFORT_LIGHT_LEVEL = 0.3

local KEEP_CHOPPING_DIST = 8

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

local function IsDeciduousTreeMonster(guy)
    return guy.monster and guy.prefab == "deciduoustree"
end

local function FindDeciduousTreeMonster(inst)
    return FindEntity(inst, SEE_TREE_DIST / 3, IsDeciduousTreeMonster, { "CHOP_workable" })
end

local function KeepChoppingAction(inst)
    -- Wood chopping ONLY on MK.II (when leader has skill)
    local leader = inst.components.follower.leader
    if not leader or not leader:HasTag("wagstaff_thermal_upgrade") then
        return false
    end
    -- Check if this is MK.II butler (not base MK.I)
    if inst.prefab ~= "williambutler2" and not inst:HasTag("butler_thermal_upgraded") then
        return false
    end
    return inst.tree_target ~= nil
        or (inst:IsNear(leader, KEEP_CHOPPING_DIST))
        or FindDeciduousTreeMonster(inst) ~= nil
end

local function StartChoppingCondition(inst)
    -- Wood chopping ONLY on MK.II (when leader has skill)
    local leader = inst.components.follower.leader
    if not leader or not leader:HasTag("wagstaff_thermal_upgrade") then
        return false
    end
    -- Check if this is MK.II butler (not base MK.I)
    if inst.prefab ~= "williambutler2" and not inst:HasTag("butler_thermal_upgraded") then
        return false
    end
    return inst.tree_target ~= nil
        or (leader.sg ~= nil and leader.sg:HasStateTag("chopping"))
        or FindDeciduousTreeMonster(inst) ~= nil
end

local function FindTreeToChopAction(inst)
    local target = FindEntity(inst, SEE_TREE_DIST, nil, { "CHOP_workable" })
    if target ~= nil then
        if inst.tree_target ~= nil then
            target = inst.tree_target
            inst.tree_target = nil
        else
            target = FindDeciduousTreeMonster(inst) or target
        end
        return BufferedAction(inst, target, ACTIONS.CHOP)
    end
end


local function KeepMiningAction(inst)
    return inst.tree_target ~= nil
        or (inst.components.follower.leader ~= nil and
            inst:IsNear(inst.components.follower.leader, KEEP_CHOPPING_DIST))
end

local function StartPickingCondition(inst)
    return inst.components.follower.leader ~= nil and
           inst.components.follower.leader.sg ~= nil and
           inst.components.follower.leader.sg:HasStateTag("picking")
end

local function KeepPickingAction(inst)
    return inst.components.follower.leader ~= nil and
           inst.components.follower.leader.sg ~= nil and
           inst.components.follower.leader.sg:HasStateTag("picking")
end

local function FindGrassTwigsToPickAction(inst)
    local target = FindEntity(inst, SEE_TREE_DIST, function(ent)
        return ent.components.pickable ~= nil and ent.components.pickable:CanBePicked() and
               (ent.prefab == "grass" or ent.prefab == "twigs")
    end, { "plant", "pickable" }, { "FX", "INLIMBO", "withered" })
    if target ~= nil then
        return BufferedAction(inst, target, ACTIONS.PICK)
    end
end

local function StartMiningCondition(inst)
    -- Mining ONLY on MK.II (when leader has skill) — same as chopping
    local leader = inst.components.follower.leader
    if not leader or not leader:HasTag("wagstaff_thermal_upgrade") then
        return false
    end
    -- Check if this is MK.II butler (not base MK.I)
    if inst.prefab ~= "williambutler2" and not inst:HasTag("butler_thermal_upgraded") then
        return false
    end
    return inst.tree_target ~= nil
        or (inst.components.follower.leader ~= nil and
            inst.components.follower.leader.sg ~= nil and
            inst.components.follower.leader.sg:HasStateTag("mining"))
end

local function FindRockToMineAction(inst)
    local target = FindEntity(inst, SEE_TREE_DIST, nil, { "MINE_workable" })
    if target ~= nil then
        if inst.mine_target ~= nil then
            target = inst.mine_target
            inst.mine_target = nil
        else
            target = target
        end
        return BufferedAction(inst, target, ACTIONS.MINE)
    end
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

function WilliamButlerBrain:OnStart()

        local watch_game = WhileNode( function() return ShouldWatchMinigame(self.inst) end, "Watching Game",
        PriorityNode({
            Follow(self.inst, WatchingMinigame, TUNING.MINIGAME_CROWD_DIST_MIN, TUNING.MINIGAME_CROWD_DIST_TARGET, TUNING.MINIGAME_CROWD_DIST_MAX),
            RunAway(self.inst, "minigame_participator", 5, 7),
            FaceEntity(self.inst, WatchingMinigame, WatchingMinigame),
                }, 0.25))

    local root = PriorityNode(
    {
                watch_game,

        --#1 priority is dancing beside your leader. Obviously.
        WhileNode(function() return ShouldDanceParty(self.inst) end, "Dance Party",
            PriorityNode({
                Leash(self.inst, GetLeaderPos, KEEP_DANCING_DIST, KEEP_DANCING_DIST),
                ActionNode(function() DanceParty(self.inst) end),
        }, .25)),

        -- Combat avoidance: stay away from fighting leader and hostiles
        WhileNode(function() return GetLeader(self.inst) ~= nil and GetLeader(self.inst).components.combat ~= nil and GetLeader(self.inst).components.combat.target ~= nil end, "Combat Avoidance",
            PriorityNode({
                RunAway(self.inst, { fn = function(target, inst) return target == GetLeader(inst) end, tags = { "player" } }, 8, 14),
                RunAway(self.inst, { fn = ShouldRunAway, oneoftags = { "monster", "hostile" }, notags = { "player", "INLIMBO" } }, 10, 16),
                Wander(self.inst, function() return GetLeaderPos(self.inst) end, 14),
        }, .25)),

        WhileNode(function() return IsNearLeader(self.inst, KEEP_WORKING_DIST) end, "Leader In Range",
            PriorityNode({
                RunAway(self.inst, { fn = ShouldAvoidExplosive, tags = { "explosive" }, notags = { "INLIMBO" } }, AVOID_EXPLOSIVE_DIST, AVOID_EXPLOSIVE_DIST),
                RunAway(self.inst, { fn = ShouldRunAway, oneoftags = { "monster", "hostile" }, notags = { "player", "INLIMBO" } }, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST),
           IfNode(function() return StartChoppingCondition(self.inst) end, "chop", 
                WhileNode(function() return KeepChoppingAction(self.inst) end, "keep chopping",
                    LoopNode{ 
                            DoAction(self.inst, FindTreeToChopAction )})),
           IfNode(function() return StartMiningCondition(self.inst) end, "mine", 
                WhileNode(function() return KeepMiningAction(self.inst) end, "keep mining",
                    LoopNode{ 
                            DoAction(self.inst, FindRockToMineAction )})),
           IfNode(function() return StartPickingCondition(self.inst) end, "pick_grass_twigs",
                WhileNode(function() return KeepPickingAction(self.inst) end, "keep picking",
                    LoopNode{
                            DoAction(self.inst, FindGrassTwigsToPickAction )})),
        }, .25)),

        Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
            WhileNode(function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),
        WhileNode(function() return GetLeader(self.inst) ~= nil end, "Has Leader",
            FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn)),
    }, .25)

    self.bt = BT(self.inst, root)
end

return WilliamButlerBrain
