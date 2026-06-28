require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/panic"
require "behaviours/follow"
require "behaviours/attackwall"
require "behaviours/standstill"
require "behaviours/leash"

local WilliamBruteBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

--Images will help chop, mine and fight.

local MIN_FOLLOW_DIST = 0
local TARGET_FOLLOW_DIST = 6
local MAX_FOLLOW_DIST = 8

local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 20
local MAX_WANDER_DIST = 8
local MAX_AWAY_DIST = 14

local START_FACE_DIST = 6
local KEEP_FACE_DIST = 8

local KEEP_WORKING_DIST = 14
local SEE_WORK_DIST = 10

local KEEP_DANCING_DIST = 4

local KITING_DIST = 3
local STOP_KITING_DIST = 5

local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local AVOID_EXPLOSIVE_DIST = 5

-- v2.0.71: retreat tuning. The brute used to fight to the death — it never
-- disengaged when the player ran away, and never retreated at low HP. Two new
-- thresholds fix this:
--   * KEEP_WORKING_DIST (14): if the leader is farther than this, the brute
--     drops combat and runs to the leader. Mirrors BRUTE_DISENGAGE_DIST in the
--     prefab and the buster bot's "Leader In Range" gate.
--   * FLEE_HP_PCT (0.25): at or below this HP fraction the brute retreats
--     (follows the leader if it has one, else RunAway from threats).
local FLEE_HP_PCT = 0.25

local DIG_TAGS = { "stump", "grave" }

-- v2.0.68: a deactivated bot (inst.on == false) must never follow/chase/wander.
-- The previous fix used a single StandStill node at the top of the PriorityNode,
-- but StandStill returns SUCCESS once the entity is already stopped, which lets
-- the PriorityNode fall through to the Follow node below — and DST's Follow
-- behaviour has a catch-up teleport that yanks the deactivated bot to the leader.
-- Now every movement node is individually gated by IsActive, so when the bot is
-- off NONE of them evaluate. GetLeader also returns nil when off, which makes
-- the Follow node have no target (the real guarantee against the teleport).
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
    if not IsActive(inst) then return nil end
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

-- v2.0.71: HP fraction check. True when the brute is active and critically low
-- on health — it should stop fighting and retreat.
local function ShouldFleeLowHP(inst)
    if not IsActive(inst) then return false end
    if inst.components.health == nil or inst.components.health.maxhealth <= 0 then
        return false
    end
    local hp = inst.components.health.currenthealth
    return hp > 0 and (hp / inst.components.health.maxhealth) <= FLEE_HP_PCT
end

-- v2.0.71: the brute's current combat target (for RunAway). Returns nil when
-- the target is dead/invalid so RunAway has nothing to flee from and idles.
local function GetCombatTarget(inst)
    if inst.components.combat == nil then return nil end
    local target = inst.components.combat.target
    if target == nil then return nil end
    if target.components.health ~= nil and target.components.health:IsDead() then
        return nil
    end
    return target
end

local function GoHomeAction(inst)
    if inst.components.combat.target ~= nil then
        return
    end
    local homePos = inst.components.knownlocations:GetLocation("home")
    return homePos ~= nil
        and BufferedAction(inst, nil, ACTIONS.WALKTO, nil, homePos, nil, .2)
        or nil
end

local function ShouldGoHome(inst)
    if not IsActive(inst) then return false end
    if inst.components.follower ~= nil and inst.components.follower.leader ~= nil then
        return false
    end
    local homePos = inst.components.knownlocations:GetLocation("home")
    return homePos ~= nil and inst:GetDistanceSqToPoint(homePos:Get()) > MAX_AWAY_DIST * MAX_AWAY_DIST
end

function WilliamBruteBrain:OnStart()
    -- Always build a single tree that handles both follow and home-guard modes.
    -- Previously, the tree was built once in OnStart based on whether the leader
    -- existed at that exact moment. On game reload, the leader is restored via
    -- DoTaskInTime(0) which can race with brain creation, causing the brain to
    -- build WITHOUT a Follow node → brute never follows (wanders for ~1 min).
    -- Now Follow is wrapped in a WhileNode so it activates as soon as a leader
    -- is available, even if set after brain creation.
    local root = PriorityNode(
    {
        WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst)),
        WhileNode(function() return self.inst.components.hauntable and self.inst.components.hauntable.panic end, "PanicHaunted", Panic(self.inst)),

        -- v2.0.68: every movement node is gated by IsActive (inst.on ~= false).
        -- When deactivated, none of these evaluate, so the bot stays put.
        WhileNode(function() return IsActive(self.inst) end, "Active",
            PriorityNode({
                -- v2.0.71: #1 LOW HP RETREAT. The brute used to fight to the
                -- death. Now when HP <= 25% it drops combat and retreats. If it
                -- has a leader it sprints to the leader (who can repair/protect
                -- it); if it has no leader it RunAways from its current target.
                -- The condition also clears the combat target each brain tick
                -- so OnAttacked->SuggestTarget can't pull it back into the fight
                -- while it is retreating to the leader.
                WhileNode(function()
                    if not ShouldFleeLowHP(self.inst) then return false end
                    if GetLeader(self.inst) ~= nil then
                        if self.inst.components.combat ~= nil and self.inst.components.combat.target ~= nil then
                            self.inst.components.combat:SetTarget(nil)
                        end
                        return true
                    end
                    return false
                end, "LowHP Flee To Leader",
                    Follow(self.inst, GetLeader, 0, 2, 5)),

                WhileNode(function() return ShouldFleeLowHP(self.inst) and GetLeader(self.inst) == nil end, "LowHP Run Away",
                    PriorityNode({
                        RunAway(self.inst, function() return GetCombatTarget(self.inst) end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST),
                        RunAway(self.inst, "hostile", RUN_AWAY_DIST, STOP_RUN_AWAY_DIST),
                    }, .25)),

                -- v2.0.71: #2 COMBAT GATED BY LEADER DISTANCE. Mirrors the
                -- buster bot: the brute only fights while it is within
                -- KEEP_WORKING_DIST of its leader. If the player runs away
                -- (beyond 14 units), this gate deactivates, the brute drops
                -- ChaseAndAttack, and falls through to the Follow node below —
                -- so it disengages and runs after the player. Fixes "tentei
                -- correr, não conseguir" (the brute wouldn't stop fighting the
                -- beefalo herd even after the player fled). The companion
                -- keeptargetfn in the prefab also drops the target at the
                -- component level so OnAttacked can't re-acquire herd members.
                WhileNode(function() return IsNearLeader(self.inst, KEEP_WORKING_DIST) end, "Leader In Range",
                    PriorityNode({
                        ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST),
                    }, .25)),

                -- v2.0.71: Follow runs when combat is gated off (leader far) or
                -- when there's simply nothing to fight. While retreating to the
                -- leader, also keep clearing any combat target that OnAttacked
                -- may have re-suggested, so the brute doesn't stop to fight
                -- again on the way back.
                WhileNode(function()
                    if GetLeader(self.inst) == nil then return false end
                    if not IsNearLeader(self.inst, KEEP_WORKING_DIST) then
                        if self.inst.components.combat ~= nil and self.inst.components.combat.target ~= nil then
                            self.inst.components.combat:SetTarget(nil)
                        end
                    end
                    return true
                end, "HasLeader",
                    Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST)),
                WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome", DoAction(self.inst, GoHomeAction, "Go Home", true)),
                FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
                Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST),
            }, .25)),
    }, .25)

    self.bt = BT(self.inst, root)
end


return WilliamBruteBrain
