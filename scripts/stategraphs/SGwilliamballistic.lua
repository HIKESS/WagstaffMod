require("stategraphs/commonstates")

local function ZapFX(inst)
            local fx = SpawnPrefab("williamchargedfx")
            fx.entity:SetParent(inst.entity)
            fx.entity:AddFollower()
            fx.Follower:FollowSymbol(inst.GUID, "body", 10, -80, 0)

        end

local function LightningFX(inst)
            local fx = SpawnPrefab("electrichitsparks")
            fx.entity:SetParent(inst.entity)
            fx.entity:AddFollower()
            fx.Follower:FollowSymbol(inst.GUID, "body", 5, -120, 0)

        end

local actionhandlers = 
{
}


local events=
{
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHop(),
    EventHandler("dance", function(inst)
        if not (inst.sg:HasStateTag("dancing") or inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("dance")
        end
    end),
}

local states=
{
     State{
        
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            inst.Physics:Stop()
        if inst.components.fueled ~= nil then
            if inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .2 then
                inst.AnimState:PlayAnimation("cower_loop", true)
        else
                inst.AnimState:PlayAnimation("idle", true)
                end
                if math.random(0, 100) < (7*inst.components.fueled:GetPercent()) then    
    ZapFX(inst)
                end

        end
        end,
        
        timeline = 
        {
                --    TimeEvent(21*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/idle") end ),
        },
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
    
   State{
        name = "fed",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat")
           -- inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/bounce")
        end,
        
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

   State{
        name = "attack",
        tags = {"attack", "longattack", "abouttoattack", "busy"},

        onenter = function(inst)
            inst.sg.statemem.target = inst.components.combat.target
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/charge")
            if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
                inst:FacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end

            inst.sg.statemem.fx = SpawnPrefab("william_chargeup")
            inst.sg.statemem.fx.entity:SetParent(inst.entity)
            inst.sg.statemem.fx.entity:AddFollower()
            inst.sg.statemem.fx.Follower:FollowSymbol(inst.GUID, "body", 0, 0, 0)

        end,

        onexit = function(inst)
               if inst.sg.statemem.fx ~= nil then
                inst.sg.statemem.fx:Remove()
                inst.sg.statemem.fx = nil
                end
        end,

        timeline =
        {
        TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/shoot") end),
        TimeEvent(17*FRAMES, function(inst) 
inst.components.combat:DoAttack(inst.sg.statemem.target) 
               if inst.sg.statemem.fx ~= nil then
                inst.sg.statemem.fx:Remove()
                inst.sg.statemem.fx = nil
                end
end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "dance",
        tags = {"idle", "dancing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
                inst.AnimState:PlayAnimation("eat", false)
                inst.AnimState:PushAnimation("eat_pst", false)
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst) 
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/bounce")
            end ),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("dance") end),
        },

    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
        inst.Physics:SetActive(false)
            inst.AnimState:PlayAnimation("death")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/death")
    inst.components.lootdropper:DropLoot()
            -- v2.0.87: Notify the owner when the ballistic dies
            local owner = inst.components.follower and inst.components.follower:GetLeader()
            if owner and owner.components.talker then
                owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_BALLISTIC_DOWN"))
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:Remove()
                end
            end),
        },
    },

    State{
        name = "powerdown",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hide")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/death")
        inst.Transform:SetRotation(0)
        end,

        events =
        {
            EventHandler("animover", function(inst)
        --local health = inst.components.health.currenthealth
                if inst.AnimState:AnimDone() then
    local x, y, z = inst.Transform:GetWorldPosition()
    local husk = SpawnPrefab("williamballistic_empty")
        if husk ~= nil then
        husk.william = inst.components.follower:GetLeader()
        husk.Transform:SetPosition(x, y, z)
        husk.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        inst:Remove()
        end
                end
            end),
        },
    },

    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/hurt")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        timeline =
        {
            TimeEvent(3*FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },
    },

    State{
        name = "revived",
        tags = {"busy"},
        
        onenter = function(inst, charge)
        inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst.AnimState:PlayAnimation("unhide", false)
                if charge ~= false then
                LightningFX(inst)
                else
                ZapFX(inst)
                end
        end,

        timeline =
        {
                TimeEvent(0*FRAMES, function(inst) inst.Physics:SetActive(true) inst.SoundEmitter:PlaySound("dontstarve/common/together/battery/up") end ),
        },
        
        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{  name = "spawn",
        tags = {"busy"},
        
        onenter = function(inst)
        inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst.AnimState:PlayAnimation("unhide")
  --  SpawnPrefab("maxwell_smoke").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
        end,

        timeline =
        {
                TimeEvent(0*FRAMES, function(inst) inst.Physics:SetActive(true) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/bounce") end ),
        },
        
        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}

CommonStates.AddWalkStates(states,
{
    starttimeline = 
    {
            TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/foley/wx78")end),
    },
        walktimeline = {

            TimeEvent(0*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/foley/wx78")
                if (math.random() < .25) and inst.components.fueled.currentfuel >= inst.components.fueled.maxfuel*0.4 then    
    ZapFX(inst)
                end
end),
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/foley/wx78") end),
            TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/foley/wx78") end),
            TimeEvent(12*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/foley/wx78")
                if (math.random() < .25) and inst.components.fueled.currentfuel >= inst.components.fueled.maxfuel*0.4 then    
    ZapFX(inst)
                end
end),
        },
}, nil,true)

CommonStates.AddSleepStates(states,
{
    starttimeline = 
    {
                TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/liedown") end ),
    },
    
        sleeptimeline = {
        TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/sleep") end),
        },
})

CommonStates.AddFrozenStates(states)
CommonStates.AddHopStates(states, true, { pre = "walk_pre", loop = "walk_loop", pst = "walk_pst"})
    
return StateGraph("williamballistic", states, events, "idle", actionhandlers)

