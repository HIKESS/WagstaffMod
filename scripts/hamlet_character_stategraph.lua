-- ============================================================================
-- Wagstaff Standalone Mod — Character Stategraph
-- Extracted from: hamlet_character_stategraph.lua (Hamlet Characters mod #2399658326)
--
-- This file contains ONLY Wagstaff-related stategraph postinits/states/handlers:
--   * spygoggle / spygoggle_post states (SPY action -> spygoggles investigation)
--   * goggleattack / goggle_attack_post states (fryfocals goggles attack)
--   * telebrella / telebrella_finish / telebrella_pst states (telebrella teleport)
--   * ATTACK action handler (trimmed: only the fryfocals branch retained;
--     the hand_gun/Wheeler and blunderbuss/Warbucks branches were dropped)
--   * CASTSPELL action handler (telebrella)
--   * Quagmire BLINK action handler (commented out — BUG: undefined vars)
--
-- Dropped (other Hamlet characters): Wheeler (shoot/dodge/hand_gun),
-- Wilba (werewilba transform/gnaw/run overrides), Warbucks (blunderbuss/speargun),
-- Pig Trading (daily_gift), and the shared LOAD action handler (Warbucks blunderbuss).
-- Also dropped: BEAVERVISION_COLOURCUBE, GetRunStateAnim, dropbeard (Wilba helpers).
-- ============================================================================


local State = GLOBAL.State
local FRAMES = GLOBAL.FRAMES
local EventHandler = GLOBAL.EventHandler
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local TimeEvent = GLOBAL.TimeEvent
local ActionHandler = GLOBAL.ActionHandler
local ACTIONS = GLOBAL.ACTIONS
local TheNet = GLOBAL.TheNet
local SpawnPrefab = GLOBAL.SpawnPrefab
local PlayFootstep = GLOBAL.PlayFootstep
local Vector3 = GLOBAL.Vector3
local STRINGS = GLOBAL.STRINGS

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.SPY, "spygoggle"))

AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.SPY, "spygoggle"))

AddStategraphState("wilson", 
	State {
		name = "spygoggle",
        tags = {"preinvestigate", "investigating", "working"},
		
        onenter = function(inst)
            inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("goggle")
        end,
        
        timeline=
        {
            TimeEvent(9*FRAMES, function(inst)
                inst.sg:RemoveStateTag("preinvestigate")
            end),

            TimeEvent(13*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("hamletcharactersound/characters/wagstaff/goggles/use_goggles", "goggle")               
            end),            

            TimeEvent(16*FRAMES, function(inst) 
                inst.sg:RemoveStateTag("investigating")
            end),

            TimeEvent(45*FRAMES, function(inst)
                inst:PerformBufferedAction()               
            end),
        },
        
        events=
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end ),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("spygoggle_post")
            end ),
        },
		
        onexit= function(inst)
            inst.SoundEmitter:KillSound("goggle")                
        end,        
    }
)

AddStategraphState("wilson", 
    State{ 
		name = "spygoggle_post",
        tags = {"investigating", "working"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("goggle_pst")
        end,
        
        events=
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end ),
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    }
)

AddStategraphState("wilson_client", 
	State {
		name = "spygoggle",
        tags = {"preinvestigate", "investigating", "working"},
		
        onenter = function(inst)
            inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("goggle")
        end,
        
        timeline=
        {
            TimeEvent(9*FRAMES, function(inst)
                inst.sg:RemoveStateTag("preinvestigate")
            end),

            TimeEvent(13*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("hamletcharactersound/characters/wagstaff/goggles/use_goggles", "goggle")               
            end),            

            TimeEvent(16*FRAMES, function(inst) 
                inst.sg:RemoveStateTag("investigating")
            end),

            TimeEvent(45*FRAMES, function(inst)
                inst:PerformPreviewBufferedAction()               
            end),
        },
        
        events=
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end ),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("spygoggle_post")
            end ),
        },
		
        onexit= function(inst)
            inst.SoundEmitter:KillSound("goggle")                
        end,        
    }
)

AddStategraphState("wilson_client", 
    State{ 
		name = "spygoggle_post",
        tags = {"investigating", "working"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("goggle_pst")
        end,
        
        events=
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end ),
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    }
)

AddStategraphState("wilson", 
	State{
        name = "goggleattack",
        tags = {"attack", "notalking", "abouttoattack"},
        
        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
            if inst.components.rider:IsRiding() then
                inst.Transform:SetFourFaced()
            end
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("goggle_fast")
            if inst.sg.prevstate == inst.sg.currentstate then
                inst.sg.statemem.chained = true
                inst.AnimState:SetTime(5 * FRAMES)
            end
            inst.AnimState:PushAnimation("goggle_fast_pst", false)

            inst.sg:SetTimeout(math.max((inst.sg.statemem.chained and 14 or 18) * FRAMES, inst.components.combat.min_attack_period + .5 * FRAMES))

            if target ~= nil and target:IsValid() then
                inst:FacePoint(target.Transform:GetWorldPosition())
                inst.sg.statemem.attacktarget = target
            end

            if (equip ~= nil and equip.projectiledelay or 0) > 0 then
                inst.sg.statemem.projectiledelay = (inst.sg.statemem.chained and 9 or 14) * FRAMES - equip.projectiledelay
                if inst.sg.statemem.projectiledelay <= 0 then
                    inst.sg.statemem.projectiledelay = nil
                end
            end
        end,

        onupdate = function(inst, dt)
            if (inst.sg.statemem.projectiledelay or 0) > 0 then
                inst.sg.statemem.projectiledelay = inst.sg.statemem.projectiledelay - dt
                if inst.sg.statemem.projectiledelay <= 0 then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                if inst.sg.statemem.chained then
                end
            end),
            TimeEvent(9 * FRAMES, function(inst)
                if inst.sg.statemem.chained and inst.sg.statemem.projectiledelay == nil then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(13 * FRAMES, function(inst)
                if not inst.sg.statemem.chained then
                end
            end),
            TimeEvent(14 * FRAMES, function(inst)
                if not inst.sg.statemem.chained and inst.sg.statemem.projectiledelay == nil then
                    inst:PerformBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
					if inst.components.moisture:GetMoisture() > 0 then
						inst.components.combat:GetAttacked(nil, TUNING.HEALING_MEDSMALL, nil, "electric")
                        inst:DoTaskInTime(8 * FRAMES, function() inst.components.combat:GetAttacked(nil, TUNING.HEALING_MEDSMALL, nil, "electric") end)
					end
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events =
        {
            EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
            if inst.components.rider:IsRiding() then
                inst.Transform:SetSixFaced()
            end
        end,
    }
)

AddStategraphState("wilson", 
	State{ 
		name = "goggle_attack_post",
        tags = {"investigating", "working"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("goggle_fast_pst")
        end,
        
        events=
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end ),
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    }
)

AddStategraphState("wilson",
	State{
        name = "telebrella",
        tags = { "busy", "pausepredict", "transform", "nomorph" },

        onenter = function(inst)
            inst.telbrellalight = GLOBAL.SpawnPrefab("telebrella_glow")
            if inst.telbrellalight then
                local x,y,z = inst.Transform:GetWorldPosition()
                inst.telbrellalight.Transform:SetPosition(x,y,z)
            end         
            inst.components.playercontroller:Enable(false)
            inst.AnimState:PlayAnimation("teleport_out") 

            -- inst.AnimState:SetBloomEffectHandle( "shaders/anim.ksh" )
            inst.components.bloomer:PushBloom("telebrella", "shaders/anim.ksh")

            inst.components.locomotor:Stop()
        end,

        onexit = function(inst)
            inst.components.playercontroller:Enable(true)
        end,

        timeline = 
        {
            TimeEvent(13*FRAMES, function(inst)     
                inst.SoundEmitter:PlaySound("dontstarve/rain/thunder_close")
                inst:ShakeCamera(GLOBAL.CAMERASHAKE.FULL, 0.7, 0.02, .5, 40)
            end),
        },

        events = {
            EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("telebrella_finish") 
				end
            end ),
        },
    }
)

AddStategraphState("wilson_client",
	State{
        name = "goggleattack",
        tags = { "attack", "notalking", "abouttoattack" },

        onenter = function(inst)
            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("goggle_fast")
            if inst.sg.prevstate == inst.sg.currentstate then
                inst.sg.statemem.chained = true
                inst.AnimState:SetTime(5 * FRAMES)
            end
			
            inst.AnimState:PushAnimation("goggle_fast_pst", false)

            if inst.replica.combat ~= nil then
                inst.replica.combat:StartAttack()
                inst.sg:SetTimeout(math.max((inst.sg.statemem.chained and 14 or 18) * FRAMES, inst.replica.combat:MinAttackPeriod() + .5 * FRAMES))
            end

            local buffaction = inst:GetBufferedAction()
            if buffaction ~= nil then
                inst:PerformPreviewBufferedAction()
                if buffaction.target ~= nil and buffaction.target:IsValid() then
                    inst:FacePoint(buffaction.target:GetPosition())
                    inst.sg.statemem.attacktarget = buffaction.target
                end
            end

            if (equip.projectiledelay or 0) > 0 then
                inst.sg.statemem.projectiledelay = (inst.sg.statemem.chained and 9 or 14) * FRAMES - equip.projectiledelay
                if inst.sg.statemem.projectiledelay <= 0 then
                    inst.sg.statemem.projectiledelay = nil
                end
            end
        end,

        onupdate = function(inst, dt)
            if (inst.sg.statemem.projectiledelay or 0) > 0 then
                inst.sg.statemem.projectiledelay = inst.sg.statemem.projectiledelay - dt
                if inst.sg.statemem.projectiledelay <= 0 then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end
        end,

        timeline =
        {
            TimeEvent(9 * FRAMES, function(inst)
                if inst.sg.statemem.chained and inst.sg.statemem.projectiledelay == nil then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(14 * FRAMES, function(inst)
                if not inst.sg.statemem.chained and inst.sg.statemem.projectiledelay == nil then
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("abouttoattack") and inst.replica.combat ~= nil then
                inst.replica.combat:CancelAttack()
            end
        end,
    }
)
AddStategraphState("wilson_client", 
	State{   
        name = "goggle_attack_post",
        tags = {"investigating", "working"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("goggle_fast_pst")
        end,
        
        events=
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end ),
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    }
)

AddStategraphState("wilson",
	State{
        name = "telebrella_finish",
        tags = { "busy", "pausepredict", "transform", "nomorph" },

        onenter = function(inst)
            if not inst.telbrellalight then
                inst.telbrellalight = SpawnPrefab("telebrella_glow")
                if inst.telbrellalight then
                    local x,y,z = inst.Transform:GetWorldPosition()
                    inst.telbrellalight.Transform:SetPosition(x,y,z)
                end
            end           

            inst.DynamicShadow:Enable(false)
            inst.components.playercontroller:Enable(false)
            inst.AnimState:PlayAnimation("teleport_finish") 

            inst.components.locomotor:Stop()
        end,

        onexit = function(inst)
            inst.DynamicShadow:Enable(true)
            inst.components.playercontroller:Enable(true)
        end,

        timeline = 
        {
        },

        events = {
            EventHandler("animover", function(inst)
			    inst:SnapCamera()
                if inst:GetBufferedAction() ~= nil then
                    inst:PerformBufferedAction()
                else
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped:HasTag("telebrella") then
                        equipped.components.spellcaster:CastSpell(equipped)
                    end
                end
				inst.sg:GoToState("telebrella_pst") 
            end ),
        },
    }
)

AddStategraphState("wilson",
	State{
        name = "telebrella_pst",
        tags = { "busy", "pausepredict", "transform", "nomorph" },
        
		onenter = function(inst)
		    inst:SnapCamera()
		    inst:PerformBufferedAction()
            inst.AnimState:PlayAnimation("teleport_in") 
        end,
		
        timeline=
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("hamletcharactersound/characters/wagstaff/telebrella/telebrella_end") end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },        
		
		onexit = function(inst)
			inst.components.playercontroller:Enable(true)
            inst.components.bloomer:PopBloom("telebrella")
        end,
    }
)

--== ATTACK action handler (trimmed: only fryfocals/Wagstaff branch retained) ==--
AddStategraphPostInit("wilson", function(inst) --thanks mobbstar
	local _attack_actionhandler = inst.actionhandlers[ACTIONS.ATTACK].deststate
	inst.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
		if not (inst.sg:HasStateTag("attack") and action.target == inst.sg.statemem.attacktarget or inst.components.health:IsDead()) then
			local weapon = inst.components.combat ~= nil and inst.components.combat:GetWeapon() or nil

			if weapon and weapon:HasTag("fryfocals") then
				return "goggleattack"
			end
		end
		return _attack_actionhandler(inst, action, ...)
	end
end)

AddStategraphPostInit("wilson_client", function(inst)
	local _attack_actionhandler = inst.actionhandlers[ACTIONS.ATTACK].deststate
	inst.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
		if not (inst.sg:HasStateTag("attack") and action.target == inst.sg.statemem.attacktarget or inst.replica.health:IsDead()) then
			local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
			if equip and equip:HasTag("fryfocals") then
				return "goggleattack"
			end
		end
		return _attack_actionhandler(inst, action, ...)
	end
end)

AddStategraphPostInit("wilson", function(inst)
	local _castspell_actionhandler = inst.actionhandlers[ACTIONS.CASTSPELL].deststate
	inst.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
		return action.invobject ~= nil
            and ( (action.invobject:HasTag("telebrella") and "telebrella")
				or _castspell_actionhandler(inst, action, ...)
				)
	end
end)

-- BUG: undefined vars (_castaoe_actionhandler / _castspell_actionhandler are not
-- in scope here). The original mod referenced these locals but they were never
-- declared in this block: _castspell_actionhandler is local to the CASTSPELL
-- postinit above (out of scope), and _castaoe_actionhandler is never defined
-- anywhere in the file. Commented out to prevent runtime errors. Telebrella
-- BLINK handling in Gorge (quagmire) mode will not work until this is fixed
-- (e.g. by capturing the original BLINK deststate as a local and falling back
-- to it instead of the undefined vars).
-- if GLOBAL.TheNet:GetServerGameMode() == "quagmire" then
-- 	AddStategraphPostInit("wilson", function(inst)
-- 		local _blink_actionhandler = inst.actionhandlers[ACTIONS.BLINK].deststate
-- 		inst.actionhandlers[ACTIONS.BLINK].deststate = function(inst, action, ...)
-- 			return action.invobject ~= nil
-- 				and ( (action.invobject:HasTag("telebrella") and "telebrella")
-- 					or _castaoe_actionhandler(inst, action, ...)  -- BUG: undefined
-- 					)
-- 		end
-- 	end)
--
-- 	AddStategraphPostInit("wilson_client", function(inst)
-- 		local _blink_actionhandler = inst.actionhandlers[ACTIONS.BLINK].deststate
-- 		inst.actionhandlers[ACTIONS.BLINK].deststate = function(inst, action, ...)
-- 			return action.invobject ~= nil
-- 				and ( (action.invobject:HasTag("telebrella") and "telebrella")
-- 					or _castspell_actionhandler(inst, action, ...)  -- BUG: undefined (out of scope)
-- 					)
-- 		end
-- 	end)
-- end

