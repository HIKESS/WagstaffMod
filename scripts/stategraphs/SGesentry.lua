require("stategraphs/commonstates")

-- v2.0.90 FIX: These globals must be accessed via _G in the stategraph scope.
-- Without the _G prefix, strict.lua raises "variable X is not declared" crashes.
local EQUIPSLOTS = _G.EQUIPSLOTS
local subfmt = _G.subfmt
local SENTRY_ROF = _G.SENTRY_ROF

local events=
{    
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    EventHandler("doattack", function(inst, target)
        if inst.ammo ~= 0 then
            if not inst.components.health:IsDead() and (inst.sg:HasStateTag("hit") or not inst.sg:HasStateTag("busy")) then 
                inst.sg:GoToState("attack") 
            end
        end
    end),
    CommonHandlers.OnDeath(),
    EventHandler("attacked", function(inst) 
        if not inst.components.health:IsDead() and not 
            inst.sg:HasStateTag("attack") then
            inst.sg:GoToState("hit") 
        end 
    end)
}

local states=
{   
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            if inst:HasTag("lvl1") then
                        inst.AnimState:PlayAnimation("idle_loop", true)
            end
            if inst:HasTag("lvl2") then
                        inst.AnimState:PlayAnimation("idle_loop_2", true)
            end
            if inst:HasTag("lvl3") then
                        inst.AnimState:PlayAnimation("idle_loop_3", true)
            end
        end, 
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

        State{
        name = "death",
        tags = {"busy"},
        
        onenter = function(inst)  
        inst.components.lootdropper:DropLoot(Vector3(inst.Transform:GetWorldPosition()))
            local fx = SpawnPrefab("collapse_small")
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            fx:SetMaterial("metal")
            inst:Remove()
        end,

        timeline = 
        {
            TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/spark") end)
        },
    },    

    State{
        name = "hit",
        tags = {"hit"},
        
        onenter = function(inst)
            if inst:HasTag("lvl1") then
                inst.AnimState:PlayAnimation("hit", true)
            end
            if inst:HasTag("lvl2") then
                inst.AnimState:PlayAnimation("hit2", true)
            end
            if inst:HasTag("lvl3") then
                inst.AnimState:PlayAnimation("hit3", true)
            end
        end,
        
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },        
    },

    State
    { 
        name = "attack",
        tags = {"attack", "canrotate"},
        onenter = function(inst, target)

        inst.components.lighttweener:StartTween(nil, 0, .65, .7, nil, 0, function(inst, light) if light then light:Enable(true) end end)
        inst.components.lighttweener:StartTween(nil, 3.5, .9, .9, nil, .66, inst.dotweenin)

            if inst:HasTag("lvl1") then
                        inst.AnimState:PlayAnimation("atk", true)
            end
            if inst:HasTag("lvl2") then
                        inst.AnimState:PlayAnimation("atk2", true)
            end
            if inst:HasTag("lvl3") then
                        inst.AnimState:PlayAnimation("atk3", true)
            end
        end,
       
        timeline=
        {
            TimeEvent(2*FRAMES, function(inst)
                if inst.ammo ~= 0 and inst.components.combat.target and (inst:HasTag("lvl1") or inst:HasTag("lvl2") or inst:HasTag("lvl3")) then
                    inst:PushEvent("checkwep")
                    -- v2.0.90 FIX: Nil guard on weapon — GetEquippedItem can return nil
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon and weapon.components.weapon then
                        weapon.components.weapon:SetProjectile("esentry_bullet")
                    end
                    inst.components.combat:DoAttack()
                    inst.ammo = inst.ammo - 1
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                end
            end),
            TimeEvent(4*FRAMES, function(inst)
                if inst.ammo ~= 0 and inst.components.combat.target and (inst:HasTag("lvl2") or inst:HasTag("lvl3")) then
                    inst:PushEvent("checkwep")
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon and weapon.components.weapon then
                        weapon.components.weapon:SetProjectile("esentry_bullet")
                    end
                    inst.components.combat:DoAttack()
                    inst.ammo = inst.ammo - 1
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                end
            end),
            TimeEvent(6*FRAMES, function(inst)
                if inst.ammo ~= 0 and inst.components.combat.target and (inst:HasTag("lvl1") or inst:HasTag("lvl2") or inst:HasTag("lvl3")) then
                    inst:PushEvent("checkwep")
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon and weapon.components.weapon then
                        weapon.components.weapon:SetProjectile("esentry_bullet")
                    end
                    inst.components.combat:DoAttack()
                    inst.ammo = inst.ammo - 1
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                end
            end),
            TimeEvent(8*FRAMES, function(inst)
                if inst.ammo ~= 0 and inst.components.combat.target and (inst:HasTag("lvl2") or inst:HasTag("lvl3")) then
                    inst:PushEvent("checkwep")
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon and weapon.components.weapon then
                        weapon.components.weapon:SetProjectile("esentry_bullet")
                    end
                    inst.components.combat:DoAttack()
                    inst.ammo = inst.ammo - 1
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                end
            end),
            TimeEvent(10*FRAMES, function(inst)
                if inst.ammo ~= 0 and inst.components.combat.target and (inst:HasTag("lvl1") or inst:HasTag("lvl2") or inst:HasTag("lvl3")) then
                    inst:PushEvent("checkwep")
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon and weapon.components.weapon then
                        weapon.components.weapon:SetProjectile("esentry_bullet")
                    end
                    inst.components.combat:DoAttack()
                    inst.ammo = inst.ammo - 1
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                end
            end),
            TimeEvent(12*FRAMES, function(inst)
                if inst.ammo ~= 0 and inst.components.combat.target and (inst:HasTag("lvl3")) then
                    inst:PushEvent("checkwep")
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if weapon and weapon.components.weapon then
                        weapon.components.weapon:SetProjectile("esentry_bullet")
                    end
                    inst.components.combat:DoAttack()
                    inst.ammo = inst.ammo - 1
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                end
            end),
            TimeEvent(14*FRAMES, function(inst)
                if inst.ammo >= 2 and inst.components.combat.target and inst:HasTag("rocketsready") then
                    inst.AnimState:PlayAnimation("atk3_rockets", true)
                    inst:PushEvent("checkwep")
                --    inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).components.weapon:SetProjectile("esentry_rocket")
                --    inst.components.combat:DoAttack()
                                        if inst.components.combat.target and inst.components.combat.target:IsValid() then
                                                inst.sg.statemem.rocketpos = Vector3(inst.components.combat.target.Transform:GetWorldPosition())
                                                inst:LaunchProjectile(inst.sg.statemem.rocketpos)
                                        end
                    inst.ammo = inst.ammo - 2
                    inst:RemoveTag("rocketsready")
                    inst:PushEvent("rocketsshot")
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                    inst:DoTaskInTime(2*FRAMES, function(inst)
                        inst:PushEvent("checkwep")
                    --    inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).components.weapon:SetProjectile("esentry_rocket")
                    --    inst.components.combat:DoAttack()
                                        if inst.components.combat.target and inst.components.combat.target:IsValid() then
                                                inst.sg.statemem.rocketpos = Vector3(inst.components.combat.target.Transform:GetWorldPosition())
                                                inst:LaunchProjectile(inst.sg.statemem.rocketpos)
                                        end
                        inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                    end)
                    inst:DoTaskInTime(4*FRAMES, function(inst)
                        inst:PushEvent("checkwep")
                    --    inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).components.weapon:SetProjectile("esentry_rocket")
                    --    inst.components.combat:DoAttack()
                                        if inst.components.combat.target and inst.components.combat.target:IsValid() then
                                                inst.sg.statemem.rocketpos = Vector3(inst.components.combat.target.Transform:GetWorldPosition())
                                                inst:LaunchProjectile(inst.sg.statemem.rocketpos)
                                        end
                        inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                    end)
                    inst:DoTaskInTime(6*FRAMES, function(inst)
                        inst:PushEvent("checkwep")
                    --    inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).components.weapon:SetProjectile("esentry_rocket")
                    --    inst.components.combat:DoAttack()
                                        if inst.components.combat.target and inst.components.combat.target:IsValid() then
                                                inst.sg.statemem.rocketpos = Vector3(inst.components.combat.target.Transform:GetWorldPosition())
                                                inst:LaunchProjectile(inst.sg.statemem.rocketpos)
                                        end
                        inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/explode")
                    end)
                end
            end),
            TimeEvent(13*FRAMES, function(inst)
                        local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
                        if builder or inst.maker then
                                inst.components.named:SetName(subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ", { builder = inst.maker }))
                        else
                                inst.components.named:SetName("Sentry Gun".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health " )
                        end
                        if inst:HasTag("lvl1") then
                                inst.AnimState:PlayAnimation("idle_loop", true)
                        elseif inst:HasTag("lvl2") then
                                inst.AnimState:PlayAnimation("idle_loop_2", true)
                        elseif inst:HasTag("lvl3") then
                                inst.AnimState:PlayAnimation("idle_loop_3", true)
                        end
            end),
            TimeEvent(20*FRAMES, function(inst)
                        local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
                        if builder or inst.maker then
                                inst.components.named:SetName(subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ", { builder = inst.maker }))
                        else
                                inst.components.named:SetName("Sentry Gun".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health " )
                        end
                        if inst:HasTag("lvl1") then
                                inst.AnimState:PlayAnimation("idle_loop", true)
                        elseif inst:HasTag("lvl2") then
                                inst.AnimState:PlayAnimation("idle_loop_2", true)
                        elseif inst:HasTag("lvl3") then
                                inst.AnimState:PlayAnimation("idle_loop_3", true)
                        end
                inst:DoTaskInTime(SENTRY_ROF, function(inst)
                    inst.sg:GoToState("idle")
                end)
            end),
        },

    },   
}
    
return StateGraph("esentry", states, events, "idle")