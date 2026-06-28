require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/panic"
require "behaviours/follow"
require "behaviours/attackwall"
require "behaviours/standstill"
require "behaviours/leash"

local WilliamBusterBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

--Images will help chop, mine and fight.

local MIN_FOLLOW_DIST = 0
local TARGET_FOLLOW_DIST = 6
local MAX_FOLLOW_DIST = 8

local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 20

local START_FACE_DIST = 6
local KEEP_FACE_DIST = 8

local KEEP_WORKING_DIST = 14
local SEE_WORK_DIST = 10

local KEEP_DANCING_DIST = 3

local KITING_DIST = 3
local STOP_KITING_DIST = 5

local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local AVOID_EXPLOSIVE_DIST = 5

local DIG_TAGS = { "stump", "grave" }

-- v2.0.68: a deactivated bot (inst.on == false) must never follow/chase/dodge.
-- GetLeader returns nil when off, so the Follow node has no target and cannot
-- trigger its catch-up teleport. Every movement node is also gated by IsActive.
local function IsActive(inst)
    return inst.on ~= false
end

local function GetLeader(inst)
    if not IsActive(inst) then return nil end
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
    return leader ~= nil and leader.sg ~= nil and leader.sg:HasStateTag("dancing")
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

function WilliamBusterBrain:OnStart()

        local watch_game = WhileNode( function() return ShouldWatchMinigame(self.inst) end, "Watching Game",
        PriorityNode({
            Follow(self.inst, WatchingMinigame, TUNING.MINIGAME_CROWD_DIST_MIN, TUNING.MINIGAME_CROWD_DIST_TARGET, TUNING.MINIGAME_CROWD_DIST_MAX),
            RunAway(self.inst, "minigame_participator", 5, 7),
            FaceEntity(self.inst, WatchingMinigame, WatchingMinigame),
                }, 0.25))

    local root = PriorityNode(
    {
        WhileNode(function() return self.inst.components.health ~= nil and self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
        WhileNode(function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),

        -- v2.0.68: every movement node is gated by IsActive (inst.on ~= false).
        -- When deactivated, none of these evaluate, so the bot stays put. The
        -- old StandStill-at-top approach failed because StandStill returns
        -- SUCCESS once the entity is stopped, letting the PriorityNode fall
        -- through to Follow (which has a catch-up teleport).
        WhileNode(function() return IsActive(self.inst) end, "Active",
            PriorityNode({
                watch_game,

                --#1 priority is dancing beside your leader. Obviously.
                WhileNode(function() return ShouldDanceParty(self.inst) end, "Dance Party",
                    PriorityNode({
                        Leash(self.inst, GetLeaderPos, KEEP_DANCING_DIST, KEEP_DANCING_DIST),
                        ActionNode(function() DanceParty(self.inst) end),
                }, .25)),

                WhileNode(function() return IsNearLeader(self.inst, KEEP_WORKING_DIST) end, "Leader In Range",
                    PriorityNode({

                        RunAway(self.inst, { fn = ShouldAvoidExplosive, tags = { "explosive" }, notags = { "INLIMBO" } }, AVOID_EXPLOSIVE_DIST, AVOID_EXPLOSIVE_DIST),
                        --Duelists will try to fight before fleeing
                        IfNode(function() return self.inst:HasTag("buster") end, "Is Buster",
                            PriorityNode({
            WhileNode(function()
                            return self.inst.components.combat.target == nil
                                or not self.inst.components.combat:InCooldown()
                            --or (self.inst.components.combat.target ~= nil and self.inst.components.combat.target.components.combat:InCooldown())
                        end,
                        "AttackMomentarily",
                        ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST)),
            -- v2.0.90 FIX: Added nil check on target.components.combat before
            -- calling CanAttack(). Targeting a structure (no combat component)
            -- would crash with "attempt to index field 'combat' (a nil value)".
            WhileNode(function() return self.inst.components.combat.target ~= nil and (self.inst.components.combat:InCooldown() or (self.inst.components.combat.target.components.combat ~= nil and self.inst.components.combat.target.components.combat:CanAttack())) end, "Dodge",
                RunAway(self.inst, function() return self.inst.components.combat.target end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)),
                    }, .25)),

                }, .25)),

                Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
                WhileNode(function() return GetLeader(self.inst) ~= nil end, "Has Leader",
                    FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn)),
            }, .25)),
    }, .25)

    self.bt = BT(self.inst, root)
end

return WilliamBusterBrain
