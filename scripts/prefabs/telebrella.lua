local assets=
{
	Asset("ANIM", "anim/telebrella.zip"),
	Asset("ANIM", "anim/swap_telebrella.zip"),
    Asset("ANIM", "anim/swap_telebrella_red.zip"),
    Asset("ANIM", "anim/swap_telebrella_green.zip"),
	
	Asset("ATLAS", "images/inventoryimages/telebrella.xml"),
	Asset("IMAGE", "images/inventoryimages/telebrella.tex"),
}

local TELEDIST = 42.5 * 12.75
  
local function UpdateSound(inst)
    if inst.components.equippable:IsEquipped() and TheWorld.state.israining and not inst.SoundEmitter:PlayingSound("umbrellarainsound") then
        inst.SoundEmitter:PlaySound("hamletcharactersound/characters/wagstaff/telebrella/teleumbrella_rain_LP", "umbrellarainsound")
    else
        inst.SoundEmitter:KillSound("umbrellarainsound")
    end
end  

local function onfinished(inst)
    inst.persists = false
    inst:DoTaskInTime(1.2, inst.Remove)
end
    
local function findclosestpad(inst, sourcepad)    
    local target = inst.components.inventoryitem.owner
    if sourcepad then
        target = sourcepad
    end
    local pad = nil
    if TheWorld.telipads then
        local dist = TELEDIST * TELEDIST
        for i,testpad in ipairs(TheWorld.telipads) do
            local x,y,z = testpad.Transform:GetWorldPosition()
            local ground = TheWorld            
            local tile = ground.Map:GetTileAtPoint(x,y,z)
            if tile ~= GROUND.INTERIOR then
                local testdist = target:GetDistanceSqToInst(testpad)
                if testdist < dist and testpad ~= target then
                    pad = testpad
                    dist = testdist
                end
            end
        end
    end
    return pad
end

local function checkconnection(inst) 
    local player = inst.components.inventoryitem.owner
    local pad = findclosestpad(inst)    
    if inst.lastpad then
        inst.lastpad.turnoff(inst.lastpad)        
    end
    if pad then        
        if player:GetDistanceSqToInst(pad) < 2*2 then
            local otherpad = findclosestpad(inst,pad)
            inst.lastpad = pad
            if otherpad then            
                inst.lastpad.turnon(inst.lastpad)
            end
            pad = otherpad            
        end
        return pad        
    end
end

local function canteleport(inst, caster, target, pos)
    if checkconnection(inst) and not TheCamera.interior then
        return true
    end    
end

local function randomtele(inst, on_ocean)
    local player = inst.components.inventoryitem.owner
    if on_ocean then

        local pt = TheWorld.Map:FindRandomPointInOcean(20)
		if pt ~= nil then
            player.Transform:SetPosition(pt.x, 0, pt.z)
		end
		local from_pt = player:GetPosition()
		local offset = FindSwimmableOffset(from_pt, math.random() * 2 * PI, 90, 16)
						or FindSwimmableOffset(from_pt, math.random() * 2 * PI, 60, 16)
						or FindSwimmableOffset(from_pt, math.random() * 2 * PI, 30, 16)
						or FindSwimmableOffset(from_pt, math.random() * 2 * PI, 15, 16)
		if offset ~= nil then
			local dest = from_pt + offset
            player.Transform:SetPosition(dest.x, 0, dest.z)
		end

    else

        local dest = nil
        local centers = {}
        for i, node in ipairs(TheWorld.topology.nodes) do
            if TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) and node.type ~= NODE_TYPE.SeparatedRoom then
                table.insert(centers, {x = node.x, z = node.y})
            end
        end
        if #centers > 0 then
            local pos = centers[math.random(#centers)]
            dest = Point(pos.x, 0, pos.z)
        else
            dest = caster:GetPosition()
        end

        player.Transform:SetPosition(dest.x, 0, dest.z)

    end
end

local function teleport(inst)
    -- v2.0.39: cooldown between teleports to prevent combat/skip abuse.
    -- TUNING.TELEBRELLA_COOLDOWN is configurable (default 10s). 0 = no cooldown.
    local cooldown = TUNING.TELEBRELLA_COOLDOWN or 0
    if cooldown > 0 and inst._telebrella_cooldown_task ~= nil then
        -- Still on cooldown — emit a subtle "buzz" feedback and abort.
        if inst.SoundEmitter then
            inst.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
        end
        return
    end
    local player = inst.components.inventoryitem.owner 
    local pad = nil
    if canteleport(inst) then
        pad = checkconnection(inst)
    end
    if pad then
        if player.components.rider:IsRiding() then -- Niko: I have no clue how they did it, but this should do the same thing hopefully.
            player.components.rider:ActualDismount()
        end
        local pos = pad:GetPosition()
		player.Transform:SetPosition(pos.x, pos.y, pos.z)
        if TheWorld and TheWorld.components.walkableplatformmanager then -- NOTES(JBK): Workaround for teleporting too far causing the client to lose sync.
            TheWorld.components.walkableplatformmanager:PostUpdate(0)
        end
        player:SnapCamera()
        player.components.locomotor:Clear()

        local light = SpawnPrefab("telebrella_glow")
        if light then
            local x,y,z = player.Transform:GetWorldPosition()
            light.Transform:SetPosition(x,y,z)
        end
    else
        --Can not teleport, yet forced to anyway
        if TUNING.TELEBRELLA_RANDOM == true then
            local x, y, z = player.Transform:GetWorldPosition()
            randomtele(inst, TheWorld.Map:IsOceanAtPoint(x, y, z))
        end
    end
    inst.components.finiteuses:Use(1)

    -- v2.0.39: start the cooldown timer (only if a teleport actually happened).
    if cooldown > 0 then
        inst._telebrella_cooldown_task = inst:DoTaskInTime(cooldown, function()
            inst._telebrella_cooldown_task = nil
        end)
    end
end

local function IsRiding(inst)
    return inst.components.rider ~= nil and inst.components.rider:IsRiding()
end

-- local function OnLightningStruck(player)
--     print("OnLightningStruck", player)
--     local equip = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
--     -- teleport(player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS))
--     -- equip.components.spellcaster:CastSpell() --target, pos, doer
--     player.components.locomotor:SetBufferedAction(BufferedAction(player, nil, ACTIONS.CASTSPELL))
-- end

local function onequip(inst, owner) 
    owner.AnimState:OverrideSymbol("swap_object", "swap_telebrella", "swap_telebrella")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    UpdateSound(inst)

    local INTERVAL = 0.1
    inst.task = inst:DoPeriodicTask(INTERVAL, function() 
        local player = owner   
        
        local pad = checkconnection(inst)
        if pad and not TheCamera.interior --[[and not IsRiding(owner)--]] then

            inst.flashtime = inst.flashtime + INTERVAL
            local switch = false

            local dist = player:GetDistanceSqToInst(pad)

            local period = INTERVAL
            if not inst.red then
                local max = TELEDIST*TELEDIST
                if dist > max *0.9 then
                    period = INTERVAL
                elseif dist > max *0.75 then
                    period = 1
                elseif dist > max *0.5 then
                    period = 3
                else 
                    period = 9999999
                end
            end

            if inst.flashtime > period then
                switch = true            
                inst.flashtime = 0
            end
            if switch then
                if not inst.red then
                    inst.SoundEmitter:PlaySound("hamletcharactersound/characters/wagstaff/telebrella/teleumbrella_beep")
                    inst.red = true
                else                 
                    inst.red = nil
                end                
            end
            if inst.red then
                player.AnimState:OverrideSymbol("swap_object", "swap_telebrella_red", "swap_telebrella")
            else
                player.AnimState:OverrideSymbol("swap_object", "swap_telebrella_green", "swap_telebrella")
            end                

            -- if inst.components.spellcaster == nil then
            --     inst:AddComponent("spellcaster")
            -- end
            
            -- if inst.components.spellcaster ~= nil then
            --     inst.components.spellcaster:SetSpellFn(teleport)
            --     inst.components.spellcaster.canuseonpoint = TUNING.TELEBRELLA_SPELLTYPE == "point"
            --     inst.components.spellcaster.canuseonpoint_water = TUNING.TELEBRELLA_SPELLTYPE == "point" -- Does not work for some reason
            --     inst.components.spellcaster.canusefrominventory = TUNING.TELEBRELLA_SPELLTYPE == "item"
            --     inst.components.spellcaster.quickcast = false
            --     inst.components.spellcaster.castingstate = "telebrella"
            -- end
            
            inst.components.spellcaster.canuseonpoint = TUNING.TELEBRELLA_SPELLTYPE == "point"
            inst.components.spellcaster.canuseonpoint_water = TUNING.TELEBRELLA_SPELLTYPE == "point" -- Does not work for some reason
            inst.components.spellcaster.canusefrominventory = TUNING.TELEBRELLA_SPELLTYPE == "item"
        else
            player.AnimState:OverrideSymbol("swap_object", "swap_telebrella", "swap_telebrella")
            -- inst:RemoveComponent("spellcaster")
            inst.components.spellcaster.canuseonpoint = false
            inst.components.spellcaster.canuseonpoint_water = false
            inst.components.spellcaster.canusefrominventory = false
        end
    end)
    -- owner:ListenForEvent("playerlightningstruck", OnLightningStruck)
end

local function onunequip(inst, owner) 
    owner.AnimState:Hide("ARM_carry") 
    owner.AnimState:Show("ARM_normal")
    UpdateSound(inst)

    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end

    -- owner:RemoveEventCallback("playerlightningstruck", OnLightningStruck)
end

local function fn(Sim)
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()  
	inst.entity:AddNetwork()
	
    MakeInventoryPhysics(inst)
	
	MakeInventoryFloatable(inst, "small")
    
    inst.AnimState:SetBank("telebrella")
    inst.AnimState:SetBuild("telebrella")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("telebrella")
	
    inst.spelltype = "SCIENCE"

    inst.entity:SetPristine()
	
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.TELEBRELLA_USES)
    inst.components.finiteuses:SetUses(TUNING.TELEBRELLA_USES)
    inst.components.finiteuses:SetOnFinished( onfinished) 

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.UMBRELLA_DAMAGE)

    inst.teleport = teleport

    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(teleport)
    inst.components.spellcaster.canuseonpoint = TUNING.TELEBRELLA_SPELLTYPE == "point"
    inst.components.spellcaster.canuseonpoint_water = TUNING.TELEBRELLA_SPELLTYPE == "point" -- Does not work for some reason
    inst.components.spellcaster.canusefrominventory = TUNING.TELEBRELLA_SPELLTYPE == "item"
    inst.components.spellcaster.quickcast = false
    inst.components.spellcaster.castingstate = "telebrella"

    inst:AddComponent("inspectable")
	
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/telebrella.xml"
   
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst.flashtime = 0
	
	inst:WatchWorldState("israining", UpdateSound)
	
	MakeHauntableLaunch(inst)
	
    return inst
end

local INTENSITY = 1

local function fadein(inst)
    inst.components.fader:StopAll()
    inst.Light:Enable(true)
    if inst:IsAsleep() then
        inst.Light:SetIntensity(INTENSITY)
    else
        inst.Light:SetIntensity(0)
        inst.components.fader:Fade(0, INTENSITY, 0.6, function(v) inst.Light:SetIntensity(v) end)
    end
end

local function fadeout(inst)
    inst.components.fader:StopAll()
    if inst:IsAsleep() then
        inst.Light:SetIntensity(0)
    else
        inst.components.fader:Fade(INTENSITY, 0, 0.6, function(v) inst.Light:SetIntensity(v) end, function() inst.Light:Enable(false) end)
    end
end

local function glowfn(Sim)
    local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local light = inst.entity:AddLight()
	inst.entity:AddNetwork()
	
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("fader")

    light:SetFalloff(.7)
    light:SetIntensity(INTENSITY)
    light:SetRadius(2)
    light:SetColour(220/255, 220/255, 220/255)
    light:Enable(false) 
    inst.fadein = fadein
    inst.fadeout = fadeout
    inst:DoTaskInTime(0,function()    
            fadein(inst)
        end)
    inst:DoTaskInTime(0.6,function()
            fadeout(inst)
        end)
    inst:DoTaskInTime(0.6 * 2,function()
            inst:Remove()
        end)    
    return inst   
end

return Prefab("telebrella", fn, assets),
        Prefab("telebrella_glow", glowfn, assets) 