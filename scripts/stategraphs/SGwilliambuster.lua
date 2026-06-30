require("stategraphs/commonstates")

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
        inst.AnimState:SetDeltaTimeMultiplier(inst.components.fueled:GetPercent()*4)
        end
                inst.AnimState:PlayAnimation("idle_loop", true)
        end,
        
        onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
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
            inst.AnimState:PlayAnimation("taunt")
           -- inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/voice")
        end,
        
        timeline = 
        {
                    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/pawground") end ),
                    TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/pawground") end ),
        },
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

   State{
        name = "upgraded",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
           -- inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/voice")
        end,
        
        timeline = 
        {
                    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/pawground") end ),
                    TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/pawground") end ),
        },
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
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

            if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
                inst:FacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end
        end,

        onexit = function(inst)
        end,

        timeline =
        {
        TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/attack") end),
        TimeEvent(17*FRAMES, function(inst) inst.components.combat:DoAttack() end),
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
        name = "walk_start",
        tags = {"moving", "walking", "canrotate"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("walk_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("walk")
                end
            end),
        },

    },

    State{
        name = "walk",
        tags = {"moving", "walking", "canrotate"},

        onenter = function(inst)
                inst.AnimState:PlayAnimation("walk_loop", false)
        end,

        timeline =
        {
                    TimeEvent(0*FRAMES, function(inst) inst.Physics:Stop() end ),
            TimeEvent(7*FRAMES, function(inst) 
                inst.SoundEmitter:KillSound("step")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/bounce", "step", 0.5)
                inst.components.locomotor:WalkForward()
            end ),
            TimeEvent(20*FRAMES, function(inst)
                inst.SoundEmitter:KillSound("step")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/land", "step", 0.5)
                inst.Physics:Stop()
            end ),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("walk")
                end
            end),
        },
    },

    State{
        name = "walk_stop",
        tags = {"canrotate", "idle"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("walk_pst")
        end,

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
                inst.AnimState:PushAnimation("walk_pre")
            else
                inst.AnimState:PlayAnimation("walk_loop", false)
            end
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst) 
                inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/bounce")
            end ),
            TimeEvent(20*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/land")
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
            inst.Physics:SetActive(false)
            inst.AnimState:PlayAnimation("death")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/death")
    inst.components.lootdropper:DropLoot()
            -- v2.0.87: Notify the owner when the buster dies
            local owner = inst.components.follower and inst.components.follower:GetLeader()
            if owner and owner.components.talker then
                owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_BUSTER_DOWN"))
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
        tags = {"busy", "shutdown"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.Physics:SetActive(false)
            inst.AnimState:PlayAnimation("sleep_pre")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/death")
        inst.Transform:SetRotation(0)
        end,

        events =
        {
            EventHandler("animover", function(inst)
        --local health = inst.components.health.currenthealth
    local x, y, z = inst.Transform:GetWorldPosition()
    -- v2.0.98 FIX: if on a boat, nudge position toward boat center to
    -- prevent the husk from falling off the edge into the water.
    local platform = TheWorld.Map:GetPlatformAtPoint(x, 0, z)
    if platform ~= nil then
        local cx, _, cz = platform.Transform:GetWorldPosition()
        local dx, dz = cx - x, cz - z
        local dist = math.sqrt(dx*dx + dz*dz)
        if dist > 0.5 then
            x = x + dx/dist * 0.5
            z = z + dz/dist * 0.5
        end
    end
    local husk = SpawnPrefab("williambuster_empty")
        if husk ~= nil then
        husk.Transform:SetPosition(x, y, z)
--      if not inst.components.fueled:IsEmpty() then
        husk.components.fueled.currentfuel = inst.components.fueled.currentfuel
--      end
        husk.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        husk.level = inst.level
        husk.upgradelevel = inst.upgradelevel or 0
        if inst.prefab == "williambuster3" then
            husk.was_mk3 = true
            husk.was_mk2 = true
            husk.saved_upgradelevel = 70
            husk.saved_upgradelevel_mk3 = 75
        elseif inst.prefab == "williambuster2" then
            husk.was_mk2 = true
            husk.saved_upgradelevel = 70
            if inst.upgradelevel_mk3 then
                husk.saved_upgradelevel_mk3 = inst.upgradelevel_mk3
            end
        end
        husk:PushEvent("levelup")
        inst:Remove()
        else
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
        inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/hurt")
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
        
        onenter = function(inst)
            -- Don't reset color for shadow clones
            if not inst:HasTag("shadow_buster_clone") then
                inst.AnimState:SetMultColour(1, 1, 1, 1)
            end
            inst.AnimState:PlayAnimation("sleep_pst", false)
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

    State{  name = "spawn",
        tags = {"busy"},
        
        onenter = function(inst)
            -- Don't reset color for shadow clones
            if not inst:HasTag("shadow_buster_clone") then
                inst.AnimState:SetMultColour(1, 1, 1, 1)
            end
            inst.AnimState:PlayAnimation("spawn")
            inst.AnimState:PushAnimation("sleep_pst", false)
   -- SpawnPrefab("maxwell_smoke").Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
        end,

        timeline =
        {
                TimeEvent(0*FRAMES, function(inst)
         inst.Physics:SetActive(true)
         inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/bounce")
                    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("small_puff").Transform:SetPosition(x, y, z)
         end ),
        },
        
        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}

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
    
return StateGraph("williambuster", states, events, "idle", actionhandlers)

