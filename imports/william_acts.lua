-- William Toymaker actions (cleaned up; supports both 'william' and 'tinkerer' tags so Wagstaff can use William bots)
local require = GLOBAL.require
require "class"
require "bufferedaction"

local function CrafterCheck(doer)
    return doer ~= nil and (doer:HasTag("william") or doer:HasTag("tinkerer"))
end

--==================================================================================
-- WILLIAM_ACTION (cooking via butler)
-- Note: No stategraph handler needed - cook works via cooker component + docookery event
--==================================================================================
local WILLIAM_ACTION = AddAction("WILLIAM_ACTION", "Cook", function(act)
    local doer = act.doer
    local target = act.target
    if doer ~= nil and target ~= nil and CrafterCheck(doer)
        and target.components.follower ~= nil
        and target.components.follower.leader == doer then
        target:PushEvent("docookery", doer)
    end
end)

--==================================================================================
-- WILLPACKUP (pack up portable bot)
--==================================================================================
AddComponentAction("SCENE", "portablewillybot", function(inst, doer, actions, right)
    if right and CrafterCheck(doer) then
        -- Right click: Pack Up (always available for portable bots)
        table.insert(actions, GLOBAL.ACTIONS.WILLPACKUP)
    end
end)

local WILLPACKUP = GLOBAL.Action({ rmb=true })
WILLPACKUP.str = "Pack Up"
WILLPACKUP.id = "WILLPACKUP"
WILLPACKUP.fn = function(act)
    if act.target ~= nil
        and act.target.components.portablewillybot ~= nil
        and not (act.target.components.health ~= nil and act.target.components.health:IsDead()) then
        act.target.components.portablewillybot:Dismantle(act.doer)
        return true
    end
    return false
end
AddAction(WILLPACKUP)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLPACKUP, "dolongaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLPACKUP, "dolongaction"))

--==================================================================================
-- WILLYRAISE (activate / deactivate bot)
--==================================================================================
AddComponentAction("SCENE", "willyraise", function(inst, doer, actions, right)
    if right and CrafterCheck(doer)
        and (inst.replica.follower == nil
             or inst.replica.follower:GetLeader() == nil
             or inst.replica.follower:GetLeader() == doer)
        and not (inst.replica.health ~= nil and inst.replica.health:IsDead())
        and not inst:HasTag("fueldepleted")
        and not (inst.sg ~= nil and inst.sg:HasStateTag("shutdown")) then
        table.insert(actions, GLOBAL.ACTIONS.WILLYRAISE)
    end
end)

local WILLYRAISE = GLOBAL.Action({ rmb=true })
WILLYRAISE.str = "Activate"
WILLYRAISE.stroverridefn = function(act)
    if act.target:HasTag("alive") then return "Deactivate" end
end
WILLYRAISE.id = "WILLYRAISE"
WILLYRAISE.fn = function(act)
    if act.target ~= nil
        and act.target.components.willyraise ~= nil
        and act.target.components.fueled ~= nil and not act.target.components.fueled:IsEmpty()
        and CrafterCheck(act.doer)
        and not (act.target.sg ~= nil and act.target.sg:HasStateTag("shutdown"))
        and not (act.target.components.health ~= nil and act.target.components.health:IsDead()) then
        -- v2.0.87: Removed dead guard that could never fire (line 76 already
        -- guarantees CrafterCheck is true, so `not (alive or true)` = always false).
        if act.target:HasTag("alive") then
            act.target.components.willyraise:Lower(act.doer)
        else
            act.target.components.willyraise:Rise(act.doer)
        end
        return true
    end
end
AddAction(WILLYRAISE)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLYRAISE, function(inst, action)
    return (action.target ~= nil and action.target:HasTag("alive") and "doshortaction") or "dolongaction"
end))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLYRAISE, function(inst, action)
    return (action.target ~= nil and action.target:HasTag("alive") and "doshortaction") or "dolongaction"
end))

--==================================================================================
-- WILLUPGRADE (use gear to upgrade a bot)
-- v2.0.83 FIX: When target is a brute (has both `container` + `willminion`),
-- remove the STORE action from the list so the gear goes to WILLUPGRADE
-- (levelup) instead of into the brute's chest. The brute is the only bot
-- with a container, so the STORE vs WILLUPGRADE conflict only happens here.
--==================================================================================
AddComponentAction("USEITEM", "willupgrader", function(inst, doer, target, actions)
    if CrafterCheck(doer) and target:HasTag("willminion") and not target:HasTag("butler") and not target:HasTag("level3") then
        -- v2.0.83: Remove STORE from the action list when upgrading a brute with gears.
        -- Without this, STORE (put gear into chest) takes priority over WILLUPGRADE
        -- (consume gear for levelup) because DST's container action is registered
        -- before our custom action and gets selected first.
        if target:HasTag("brute") then
            for i = #actions, 1, -1 do
                if actions[i] == GLOBAL.ACTIONS.STORE then
                    table.remove(actions, i)
                end
            end
        end
        table.insert(actions, GLOBAL.ACTIONS.WILLUPGRADE)
    end
end)

-- v2.0.83: priority=2 makes WILLUPGRADE beat STORE (priority=1) when both are
-- available. This fixes the brute bot chest intercepting gears: without this,
-- clicking a gear on a brute always stored it in the chest instead of upgrading.
local WILLUPGRADE = GLOBAL.Action({ mount_valid=false, priority=2 })
WILLUPGRADE.str = "Upgrade"
WILLUPGRADE.id = "WILLUPGRADE"
WILLUPGRADE.fn = function(act)
    if act.doer ~= nil and act.target ~= nil and act.invobject ~= nil
        and CrafterCheck(act.doer)
        and act.target:HasTag("willminion")
        and not act.target:HasTag("butler")
        and not act.target:HasTag("level3") then
        act.invobject.components.willupgrader:DoUpgrade(act.target, act.doer, act.invobject)
        if act.invobject.components.stackable ~= nil and act.invobject.components.stackable:IsStack() then
            act.invobject.components.stackable:Get():Remove()
        else
            act.invobject:Remove()
        end
        return true
    end
    return false
end
AddAction(WILLUPGRADE)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLUPGRADE, "dolongaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLUPGRADE, "dolongaction"))

AddPrefabPostInit("gears", function(inst)
    if not inst.components.willupgrader then
        inst:AddComponent("willupgrader")
    end
end)

--==================================================================================
-- RUMMAGE / STORE override: butler is leader-locked
--==================================================================================
local _RUMMAGE = GLOBAL.ACTIONS.RUMMAGE.fn
GLOBAL.ACTIONS.RUMMAGE.fn = function(act)
    local targ = act.target or act.invobject
    if targ ~= nil and targ.components.container ~= nil then
        if targ.components.container:IsOpenedBy(act.doer) then
            targ.components.container:Close()
            act.doer:PushEvent("closecontainer", { container = targ })
            return true
        elseif targ:HasTag("butler") and not (targ.components.follower ~= nil and targ.components.follower:GetLeader() == act.doer) then
            return false
        else
            return _RUMMAGE(act)
        end
    end
end

local _STORE = GLOBAL.ACTIONS.STORE.fn
GLOBAL.ACTIONS.STORE.fn = function(act)
    local target = act.target
    if target ~= nil and target.components.container ~= nil
        and act.invobject ~= nil and act.invobject.components.inventoryitem ~= nil
        and act.doer ~= nil and act.doer.components.inventory ~= nil then

        -- Butler: leader-locked (only the leader can store items)
        if target:HasTag("butler") and not (target.components.follower ~= nil and target.components.follower:GetLeader() == act.doer) then
            return false, "NOTALLOWED"
        end

        -- v2.0.83 FIX: Brute bot — gears must go to WILLUPGRADE (levelup), not STORE
        -- (into chest). The brute is the only bot with both `container` (chest) AND
        -- the `willminion` tag. When a player holds gears and clicks the brute, DST
        -- sees two USEITEM actions: STORE (chest) and WILLUPGRADE (gear->levelup).
        -- STORE has higher system priority, so the gear always went into the chest
        -- instead of being consumed for upgrade. Now we block STORE for gears on
        -- brute bots, forcing WILLUPGRADE to be the action that fires.
        -- Other items (scrap, food, etc.) still STORE normally into the chest.
        if target:HasTag("brute")
            and act.invobject.prefab == "gears"
            and act.invobject.components.willupgrader ~= nil
            and CrafterCheck(act.doer)
            and not target:HasTag("level3") then
            return false, "UPGRADE"  -- Block STORE; WILLUPGRADE will handle it
        end
    end
    return _STORE(act)
end
