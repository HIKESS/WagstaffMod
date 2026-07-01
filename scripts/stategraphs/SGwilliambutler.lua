require("stategraphs/commonstates")

local actionhandlers = 
{
    ActionHandler(ACTIONS.CHOP, "work"),
    ActionHandler(ACTIONS.MINE, "mine"),
    ActionHandler(ACTIONS.PICK, "pick"),
}


local events=
{
    CommonHandlers.OnLocomote(true, false),
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
        name = "load",
        tags = { "idle" },

        onenter = function(inst)
                inst.sg:SetTimeout(0.1)
                inst.AnimState:PlayAnimation("idle_loop")
        end,

        ontimeout = function(inst)
                inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "funnyidle",
        tags = { "idle" },

        onenter = function(inst)
            inst.Physics:Stop()
        if inst.components.fueled ~= nil then
        if inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .4 then
                inst.AnimState:PlayAnimation("hungry")
                 inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/liedown")
            elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .95 then
                inst.AnimState:PlayAnimation("idle_warly")
        else
                inst.AnimState:PlayAnimation("research")
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
                inst.sg:SetTimeout(math.random() * 4 + 2)
            inst.Physics:Stop()
        if inst.components.fueled ~= nil then
            if inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .2 then
        if not (inst.AnimState:IsCurrentAnimation("idle_groggy_pre") or inst.AnimState:IsCurrentAnimation("idle_groggy")) then
                inst.AnimState:PlayAnimation("idle_groggy_pre", false)
                inst.AnimState:PushAnimation("idle_groggy", true)
                        else
                inst.AnimState:PlayAnimation("idle_groggy", true)
        end
            elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel >= .95 then
        if not (inst.AnimState:IsCurrentAnimation("idle_onemanband1_pre") or inst.AnimState:IsCurrentAnimation("idle_onemanband1_loop")) then
                inst.AnimState:PlayAnimation("idle_onemanband1_pre", false)
                inst.AnimState:PushAnimation("idle_onemanband1_loop", true)
                        else
                inst.AnimState:PlayAnimation("idle_onemanband1_loop", true)
        end
        else
                inst.AnimState:PlayAnimation("idle_loop", true)
                end
        end
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
        name = "run_start",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },

        timeline =
        {
            TimeEvent(4*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/land", "step", 0.5)
            end),
        },
    },

    State{
        name = "run",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("run_loop") then
                inst.AnimState:PlayAnimation("run_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/land", "step1", 0.5)
                inst.SoundEmitter:KillSound("step2")
            end),
            TimeEvent(14 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/land", "step2", 0.5)
                inst.SoundEmitter:KillSound("step1")
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = {"canrotate", "idle"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("run_pst")
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
        name = "fed",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.components.container:Close()
            inst.Physics:Stop()
                inst.AnimState:PlayAnimation("quick_eat_pre")
                inst.AnimState:PushAnimation("quick_eat", false)
    inst.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_powerup", "teleportato_on", 0.3)
        end,
        
        timeline = 
        {

        },
        
        events=
        {
            EventHandler("animqueueover", function(inst) 
                        if inst.components.container:IsOpen() then
                    inst.sg:GoToState("open")
                        else
                    inst.sg:GoToState("funnyidle")
                end
        end),
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
        name = "open",
        tags = {"idle", "open"},
        
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("bow_pre")
            inst.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_activate_mouth", "open", 0.4)
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("open")
        end,

        events=
        {   
            EventHandler("animover", function(inst) inst.sg:GoToState("open_idle") end ),
        },

        timeline=
        {
            TimeEvent(0*FRAMES, function(inst)
        end),
        },        
    },

    State{
        name = "open_idle",
        tags = {"idle", "open"},
        
        onenter = function(inst)
            inst.AnimState:PlayAnimation("bow_loop")
            
        end,

        events=
        {   
            EventHandler("animover", function(inst) inst.sg:GoToState("open_idle") end ),
        },

        timeline=
        {
        
        },        
    },

    State{
        name = "close",
        tags = {"idle", "dancing"},

        onenter = function(inst)
        if inst.AnimState:IsCurrentAnimation("bow_pre") then
            inst.AnimState:PushAnimation("bow_pst", false)
        else
            inst.AnimState:PlayAnimation("bow_pst", false)
        end
            inst.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_activate_mouth", "close", 0.2)
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("close")
        end,

        events=
        {   
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end ),
        },

        timeline=
        {
            TimeEvent(0*FRAMES, function(inst) 

end),

        },        
    },


   State{
        name = "dance",
        tags = {"idle", "dancing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            if inst.AnimState:IsCurrentAnimation("run_pst") then
                inst.AnimState:PushAnimation("emoteXL_pre_dance0")
            else
                inst.AnimState:PlayAnimation("emoteXL_pre_dance0")
            end
            inst.AnimState:PushAnimation("emoteXL_loop_dance0", true)
        end,

        -- Bug 8 FIX: The dance animation is looping (true) so animover never
        -- fires for the loop itself. However, DST dispatches "animover" for
        -- each cycle of a looping anim. Check ShouldDanceParty each cycle
        -- and exit to funnyidle when the leader stops dancing.
        events =
        {
            EventHandler("animover", function(inst)
                -- ShouldDanceParty is defined in the butler brain; we
                -- re-check it the same way the brain's WhileNode does.
                local leader = inst.components.follower and inst.components.follower:GetLeader()
                local still_dancing = leader ~= nil and leader.sg ~= nil and leader.sg:HasStateTag("dancing")
                if not still_dancing then
                    inst.sg:GoToState("funnyidle")
                end
            end),
        },
    },

    State{
        name = "work",
        tags = { "busy", "working", "doing", "nointerrupt" },

        onenter = function(inst)
            inst.sg:SetTimeout(1)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("punch")
            inst.AnimState:PushAnimation("idle_loop", true)
             --  inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },


        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "mine",
        tags = { "busy", "working", "doing", "nointerrupt" },

        onenter = function(inst)
            inst.sg:SetTimeout(1)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("punch")
            inst.AnimState:PushAnimation("idle_loop", true)
             --  inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction ~= nil then
                    local target = buffaction.target
                    if target ~= nil and target:IsValid() then
                        if target.Transform ~= nil then
                            SpawnPrefab("mining_fx").Transform:SetPosition(target.Transform:GetWorldPosition())
                        end
                        inst.SoundEmitter:PlaySound(target:HasTag("frozen") and "dontstarve_DLC001/common/iceboulder_hit" or "dontstarve/wilson/use_pick_rock")
                    end
                    inst:PerformBufferedAction()
                end
            end),
        },


        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "pick",
        tags = { "busy", "working", "doing", "nointerrupt" },

        onenter = function(inst)
            inst.sg:SetTimeout(0.9)
            inst.Physics:Stop()
            inst.components.container:Close()
            inst.components.container.canbeopened = false
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction ~= nil then
                    local target = buffaction.target
                    if target ~= nil and target:IsValid() and target.components.pickable ~= nil then
                        local leader = inst.components.follower and inst.components.follower:GetLeader()
                        if leader ~= nil and leader.components.inventory ~= nil then
                            target.components.pickable:Pick(leader)
                        else
                            inst:PerformBufferedAction()
                        end
                    end
                end
            end),
        },

        ontimeout = function(inst)
            inst.SoundEmitter:KillSound("make")
            inst.AnimState:PlayAnimation("build_pst")
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("funnyidle")
                end
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("make")
            inst.components.container.canbeopened = true
        end,
    },

    State{
        name = "cook",
        tags = {"busy"},

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_activate_mouth", "close", 0.2)
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
            inst.components.container:Close()
            inst.components.container.canbeopened = false
            inst.sg:SetTimeout(0.9)
            inst.components.locomotor:Stop()
        inst:AddTag("cooking")
        if not (inst.AnimState:IsCurrentAnimation("build_pre") or inst.AnimState:IsCurrentAnimation("build_loop")) then
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
                else
           inst.AnimState:PushAnimation("build_loop", true)
        end
        end,

        ontimeout = function(inst)
            inst.SoundEmitter:KillSound("make")
            inst.AnimState:PlayAnimation("build_pst")
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("funnyidle")
                end
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("close")
            inst.SoundEmitter:KillSound("make")
            inst.components.container.canbeopened = true
        end,
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.container:Close()
            inst.components.container:DropEverything()
            inst.components.container.canbeopened = false
            inst.Physics:Stop()
            inst.Physics:SetActive(false)
            inst.AnimState:PlayAnimation("death")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/knight/death")
            -- v2.0.87: Notify the owner when the butler dies
            local owner = inst.components.follower and inst.components.follower:GetLeader()
            if owner and owner.components.talker then
                owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_BUTLER_DOWN"))
            end
            -- v2.0.34: Uma unica chamada DropLoot. O lootsetfn garante williamgadget
            -- (100%) e a chance table "butler" da 50% boards + 50% transistor
            -- (bonus alinhado ao recipe). Antes havia um segundo DropLoot que
            -- dropava a mesma tabela de novo (double-drop bug).
            inst.components.lootdropper:DropLoot()
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
        tags = {"busy", "nointerrupt", "shutdown"},

        onenter = function(inst)
            inst.components.container:Close()
            inst.components.container:DropEverything()
            inst.components.container.canbeopened = false
            inst.Physics:Stop()
            -- Bug 4 FIX: Powerdown was missing Physics:SetActive(false), unlike
            -- the death state. Without this, the butler keeps colliding with
            -- entities during the powerdown animation.
            inst.Physics:SetActive(false)
            -- Bug 2 FIX: "dozy" doesn't exist in the wilson bank (it's a chess
            -- creature animation). Use "sleep_pre" + "sleep_loop" instead, which
            -- are available in the wilson bank and convey the same "shutting down"
            -- visual. Both are non-looping so animqueueover fires after the full
            -- sequence completes.
            inst.AnimState:PlayAnimation("sleep_pre")
            inst.AnimState:PushAnimation("sleep_loop", false)

        inst.Transform:SetRotation(0)
        end,

        timeline =
        {
            TimeEvent(10*FRAMES, function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/liedown")
            end),
            TimeEvent(24*FRAMES, function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/death")
            end),
        },

        events =
        {
            -- Bug 2 FIX (cont.): changed from animover to animqueueover so the
            -- husk spawn only happens after the full sleep_pre + sleep_loop
            -- sequence, not after sleep_pre alone.
            EventHandler("animqueueover", function(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    -- v2.0.98 FIX: if on a boat, nudge position toward boat center to
    -- prevent the husk from falling off the edge into the water.
    -- Check platform at position first, then fallback to active bot's
    -- current platform (bot still knows its platform via locomotor tracking
    -- even when standing at the very edge where GetPlatformAtPoint returns nil).
    local platform = TheWorld.Map:GetPlatformAtPoint(x, 0, z)
    if platform == nil and inst.components.locomotor and inst.components.locomotor.GetPlatform then
        platform = inst.components.locomotor:GetPlatform()
    end
    if platform ~= nil then
        local cx, _, cz = platform.Transform:GetWorldPosition()
        local dx, dz = cx - x, cz - z
        local dist = math.sqrt(dx*dx + dz*dz)
        if dist > 0.1 then
            local nudge = math.max(1.5, dist * 0.3)
            x = x + dx/dist * nudge
            z = z + dz/dist * nudge
        end
    end
    local husk = SpawnPrefab("williambutler_empty")
        --if husk ~= nil then
        husk.Physics:Teleport(x, y, z)
        husk.components.fueled.currentfuel = inst.components.fueled.currentfuel
        husk.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        -- Save upgrade state for reload
        -- v2.0.74 FIX: added williambutler3 (MK3) branch. Previously MK3 was
        -- NOT handled here, so a MK3 butler that ran out of fuel would be
        -- reactivated as MK1 (MakeAlive checks was_mk3 first, then was_level2,
        -- but neither was set for MK3). Now MK3 sets both was_mk3 and
        -- was_level2 (MK3 is also level 2+), preserving the MK level across
        -- the husk -> reactivation cycle.
        if inst.prefab == "williambutler3" then
            husk.was_mk3 = true
            husk.was_level2 = true
            husk.saved_upgradelevel = 70
            husk.saved_upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        elseif inst.prefab == "williambutler2" then
            husk.was_level2 = true
            husk.saved_upgradelevel = 70
            if inst.upgradelevel_mk3 then
                husk.saved_upgradelevel_mk3 = inst.upgradelevel_mk3
            end
        elseif inst.prefab == "williambutler" and inst.upgradelevel then
            husk.saved_upgradelevel = inst.upgradelevel
        end
        inst:Remove()
        --end
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
        
        onenter = function(inst)
            inst.components.container.canbeopened = false
            inst.Physics:SetActive(false)
        inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst.AnimState:PlayAnimation("wakeup", false)
        end,

        timeline =
        {
                TimeEvent(0*FRAMES, function(inst) inst.Physics:SetActive(true) inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/bounce") end ),
        },
        
        onexit = function(inst)
            inst.Physics:SetActive(true)
            inst.components.container.canbeopened = true
        end,

        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("funnyidle") end),
        },
    },

    State{  name = "spawn",
        tags = {"busy"},
        
        onenter = function(inst)
    inst.DynamicShadow:Enable(false)
        inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst.AnimState:PlayAnimation("jumpout")
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")

        end,

        timeline =
        {
                TimeEvent(0*FRAMES, function(inst)
 inst.Physics:SetActive(true)
 inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/bounce")
                    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("small_puff").Transform:SetPosition(x, y, z)
     inst.DynamicShadow:Enable(true)
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
                TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/bounce")  end ),
    },
    
        sleeptimeline = {
        TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/bounce") end),
        },
})

CommonStates.AddFrozenStates(states)
CommonStates.AddHopStates(states, true, { pre = "boat_jump_pre", loop = "boat_jump_loop", pst = "boat_jump_pst"})
    
return StateGraph("williambutler", states, events, "load", actionhandlers)

