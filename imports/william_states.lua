local STRINGS = GLOBAL.STRINGS
local require = GLOBAL.require
--local State = GLOBAL.State
State = GLOBAL.State
GetPlayer = GLOBAL.GetPlayer
GetWorld = GLOBAL.GetWorld
STRINGS = GLOBAL.STRINGS
Action = GLOBAL.Action
Vector3 = GLOBAL.Vector3
local Vector3 = GLOBAL.Vector3
local FRAMES = GLOBAL.FRAMES
FRAMES = GLOBAL.FRAMES
local TimeEvent = GLOBAL.TimeEvent
TimeEvent = GLOBAL.TimeEvent
local EventHandler = GLOBAL.EventHandler
EventHandler = GLOBAL.EventHandler
localEQUIPSLOTS = GLOBAL.EQUIPSLOTS
EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local SpawnPrefab = GLOBAL.SpawnPrefab
local Action = GLOBAL.Action
local ActionHandler = GLOBAL.ActionHandler
require("stategraphs/commonstates")


AddStategraphState("wilson", GLOBAL.State {
        name = "williampanic",
        tags = {"idle", "talking"},
        
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle_inaction_lunacy")
        end,
     
        onexit = function(inst)
        end,
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        }, 
 })

AddStategraphState("wilson", GLOBAL.State {
        name = "williamcalm",
        tags = {"idle", "talking"},
        
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle_wurt")
        end,
     
        onexit = function(inst)
        end,
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        }, 
 })