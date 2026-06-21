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
        and (inst.replica.follower == nil or inst.replica.follower:GetLeader() == doer)
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
        if act.target:HasTag("willfollower") and not (act.target:HasTag("alive") or CrafterCheck(act.doer)) then
            return false
        end
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
--==================================================================================
AddComponentAction("USEITEM", "willupgrader", function(inst, doer, target, actions)
    if CrafterCheck(doer) and target:HasTag("willminion") and not target:HasTag("butler") and not target:HasTag("level3") then
        table.insert(actions, GLOBAL.ACTIONS.WILLUPGRADE)
    end
end)

local WILLUPGRADE = GLOBAL.Action({ mount_valid=false })
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
        and act.doer ~= nil and act.doer.components.inventory ~= nil
        and target:HasTag("butler") and not (target.components.follower ~= nil and target.components.follower:GetLeader() == act.doer) then
        return false, "NOTALLOWED"
    else
        return _STORE(act)
    end
end
