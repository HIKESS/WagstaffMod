require("stategraphs/commonstates")

local actionhandlers = 
{
}


local events=
{
    CommonHandlers.OnLocomote(true, true),
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
    EventHandler("knockback", function(inst, data)
        if inst:HasTag("alive") and not inst.components.health:IsDead() then
            inst.sg:GoToState("knockback", data)
        end
    end),
}

local states=
{


    State{
        name = "turn_on",
        tags = { "busy", "shutdown" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("getup", false)
           inst.Physics:SetMass(50)
inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/liedown")
        end,
        
        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },

        onexit = function(inst)
--            inst.Physics:SetActive(true)
        end,


    },

    State{
        name = "turn_off",
        tags = {"busy", "shutdown"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.Physics:SetMass(100)
	inst.AnimState:SetBank("william_brute")
            inst.AnimState:PlayAnimation("sit_pre")
	inst.Transform:SetRotation(0)
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst)
	inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/sleep")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle_off")
            end),
        }
    },

    State{
        name = "idle_off",
        tags = { "busy", "nointerrupt" },

        onenter = function(inst)
	inst.AnimState:SetBank("william_brute")
            inst.AnimState:PlayAnimation("sit_idle", true)
	--	inst.AnimState:Pause()
        end,

        onexit = function(inst)
	inst.AnimState:SetBank("pigman")
	--	inst.AnimState:Resume()
        end,

    },

    State{
        name = "funnyidle",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
		 inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/idle")
        if inst.components.fueled ~= nil then
            if inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .2 then
                inst.AnimState:PlayAnimation("debuff")
            elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .4 then
                inst.AnimState:PlayAnimation("hungry")
            elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .95 then
                inst.AnimState:PlayAnimation("idle_creepy")
	else
                inst.AnimState:PlayAnimation("idle_happy")
		end
	end

        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

     State{
        
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            inst.Physics:Stop()
                inst.AnimState:PlayAnimation("idle_loop", true)
                inst.sg:SetTimeout(math.random() * 1 + 2)
        end,
        
        timeline = 
        {
		--    TimeEvent(21*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/idle") end ),
        },
        
        ontimeout = function(inst)
                inst.sg:GoToState("funnyidle")
        end,
    },
    
   State{
        name = "taunt",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.Physics:Stop()
                inst.AnimState:PlayAnimation("idle_angry")
          --  inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/voice")
        end,
        
        timeline = 
        {
		    TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/voice") end ),
		    --TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/pawground") end ),
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
        end,
        
        timeline = 
        {
		    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/voice") end ),
        },
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("funnyidle") end),
        },
    },

   State{
        name = "upgraded",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.Physics:Stop()
                inst.AnimState:PlayAnimation("buff")
        end,
        
        timeline = 
        {
		    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/voice") end ),
        },
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("funnyidle") end),
        },
    },


   State{
        name = "attack",
        tags = {"attack", "notalking", "abouttoattack", "busy"},

        onenter = function(inst)
            inst.sg.statemem.target = inst.components.combat.target
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
	if inst.sg.statemem.target ~= nil and inst.sg.statemem.target.components.health ~= nil and inst.sg.statemem.target.components.health ~= nil and not inst.sg.statemem.target.components.health:IsDead() then
	inst.sg.statemem.target.components.combat:SetTarget(inst)
	end
            if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
                inst:FacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end
        end,

        timeline =
        {
		    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/attack") end ),
        TimeEvent(15*FRAMES, function(inst) inst.components.combat:DoAttack() end),
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
            if inst.AnimState:IsCurrentAnimation("walk_pst") then
                inst.AnimState:PushAnimation("idle_happy", true)
            else
                inst.AnimState:PlayAnimation("idle_happy", true)
            end
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst) 
                inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/bounce")
            end ),
            TimeEvent(20*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/bounce")
            end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("dance") end),
        },

    },

    State{
        name = "death",
        tags = {"busy", "shutdown"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("death")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/explo")
    inst.components.lootdropper:DropLoot()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                end
            end),
        },
    },

    State{
        name = "powerdown",
        tags = {"busy", "shutdown"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("sit")
	inst.Transform:SetRotation(0)
        end,

        timeline =
        {
            TimeEvent(6*FRAMES, function(inst)
inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/sleep")

            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local husk = SpawnPrefab("williambrute_empty")
	if husk ~= nil then
    local homePos = inst.components.knownlocations:GetLocation("home")
    husk.components.knownlocations:RememberLocation("home", homePos)
	husk.Transform:SetPosition(x, y, z)
	if not inst.components.fueled:IsEmpty() then
	husk.components.fueled.currentfuel = inst.components.fueled.currentfuel
	end
	husk.components.health:SetCurrentHealth(inst.components.health.currenthealth)
	inst:Remove()
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
        inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/hurt")
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
        name = "knockback",
        tags = { "knockback", "busy", "nosleep", "nofreeze", "jumping" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("smacked")

            if data ~= nil then
                if data.radius ~= nil and data.knocker ~= nil and data.knocker:IsValid() then
                    local x, y, z = data.knocker.Transform:GetWorldPosition()
                    local distsq = inst:GetDistanceSqToPoint(x, y, z)
                    local rangesq = data.radius * data.radius
                    local rot = inst.Transform:GetRotation()
                    local rot1 = distsq > 0 and inst:GetAngleToPoint(x, y, z) or data.knocker.Transform:GetRotation() + 180
                    local drot = math.abs(rot - rot1)
                    while drot > 180 do
                        drot = math.abs(drot - 360)
                    end
                    local k = distsq < rangesq and .3 * distsq / rangesq - 1 or -.7
                    inst.sg.statemem.speed = (data.strengthmult or 1) * 5 * k
                    inst.sg.statemem.dspeed = 0
                    if drot > 90 then
                        inst.sg.statemem.reverse = true
                        inst.Transform:SetRotation(rot1 + 180)
                        inst.Physics:SetMotorVel(-inst.sg.statemem.speed, 0, 0)
                    else
                        inst.Transform:SetRotation(rot1)
                        inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
                    end
                end
            end
        end,

        onupdate = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.dspeed
                if inst.sg.statemem.speed < 0 then
                    inst.sg.statemem.dspeed = inst.sg.statemem.dspeed + .075
                    inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -inst.sg.statemem.speed or inst.sg.statemem.speed, 0, 0)
                else
                    inst.sg.statemem.speed = nil
                    inst.sg.statemem.dspeed = nil
                    inst.Physics:Stop()
                end
            end
        end,

        timeline =
        {
            TimeEvent(3 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/voice") end),
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt") end),
            TimeEvent(14 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("nofreeze")
            end),
            TimeEvent(32 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("nosleep")
            end),
            TimeEvent(35 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            CommonHandlers.OnNoSleepAnimOver("idle"),
        },

        onexit = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.Physics:Stop()
            end
        end,
    },

    State{
        name = "revived",
        tags = {"busy"},
        
        onenter = function(inst)
         --   inst.Physics:SetActive(false)
            inst.AnimState:PlayAnimation("getup", false)
        end,

        timeline =
        {
    		TimeEvent(0*FRAMES, function(inst) inst.Physics:SetActive(true) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/liedown") end ),
        },
        
        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },

        onexit = function(inst)
--            inst.Physics:SetActive(true)
        end,


    },

    State{  name = "spawn",
        tags = {"busy"},
        
        onenter = function(inst)
        inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst.AnimState:PlayAnimation("getup", false)

        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
        end,

        timeline =
        {
    		TimeEvent(0*FRAMES, function(inst)
	 inst.Physics:SetActive(true)
	 inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/bounce") 
                    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("maxwell_smoke").Transform:SetPosition(x, y, z)
	end ),
        },
        
        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}

CommonStates.AddWalkStates(states,
{
	walktimeline = {
        		TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/bounce") end ),
        		TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/land") end ),
	},
})
CommonStates.AddRunStates(states,
{
	runtimeline = {
        		TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/bounce") end ),
        		TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/bounce") end ),
	},
})

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
CommonStates.AddHopStates(states, true, { pre = "boat_jump_pre", loop = "boat_jump_loop", pst = "boat_jump_pst"})
    
return StateGraph("williambrute", states, events, "idle", actionhandlers)

