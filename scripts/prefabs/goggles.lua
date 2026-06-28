function MakeGoggle(name)

	local fname = "hat_"..name
	local symname = name.."hat"
	local texture = symname..".tex"
	local prefabname = symname
	local assets =
		{
			Asset("ANIM", "anim/"..fname..".zip"),
			
			Asset("ATLAS", "images/inventoryimages/wagstaffnormalgoggles.xml"),
			Asset("IMAGE", "images/inventoryimages/wagstaffnormalgoggles.tex"),
			
			Asset("ATLAS", "images/inventoryimages/wagstaffheatgoggles.xml"),
			Asset("IMAGE", "images/inventoryimages/wagstaffheatgoggles.tex"),
			
			Asset("ATLAS", "images/inventoryimages/wagstaffarmorgoggles.xml"),
			Asset("IMAGE", "images/inventoryimages/wagstaffarmorgoggles.tex"),
			
			Asset("ATLAS", "images/inventoryimages/wagstaffshootgoggles.xml"),
			Asset("IMAGE", "images/inventoryimages/wagstaffshootgoggles.tex"),
		}
		
	local COLOURCUBE_SHOOT = resolvefilepath("images/colour_cubes/shooting_goggles_cc.tex")

	local COLOURCUBE_SHOOT_TABLE =
	{
		day = COLOURCUBE_SHOOT ,
		dusk = COLOURCUBE_SHOOT ,
		night = COLOURCUBE_SHOOT ,
		full_moon = COLOURCUBE_SHOOT ,
	}

    if name == "gogglesheat" then
        table.insert(assets, Asset("IMAGE", "images/colour_cubes/heat_vision_cc.tex"))
    end
    if name == "gogglesshoot" then
        table.insert(assets, Asset("IMAGE", "images/colour_cubes/shooting_goggles_cc.tex"))
    end

    local function goggletalk(owner, name)
    	if math.random() < 0.2 then
    		owner.components.talker:Say(GetString(owner.prefab, "ANNOUNCE_PUTONGOGGLES_"..name))
    	end
    end

	local function onequip(inst, owner, fname_override)
		goggletalk(owner, inst.prefab)
		local build = fname_override or fname
		owner.AnimState:OverrideSymbol("swap_hat", build, "swap_hat")
		owner.AnimState:Show("HAT")
		
		if owner:HasTag("player") then
			owner.AnimState:Show("HEAD_HAIR")
		end

		if inst:HasTag("venting") then
			owner:AddTag("venting")
		end		

		if inst.components.fueled then
			inst.components.fueled:StartConsuming()        
		end

		-- SendModRPCToClient(GetClientModRPC("HCR", "disablegogglevision"), owner.userid, owner)
	end

	local function onunequip(inst, owner)
		owner.AnimState:Hide("HAT")

		if owner:HasTag("player") then
			owner.AnimState:Show("HEAD")
			owner.AnimState:Hide("HEAD_HAIR")
		end

		if inst:HasTag("venting") then
			owner:RemoveTag("venting")
		end	

		if inst.components.fueled then
			inst.components.fueled:StopConsuming()        
		end
	end
	
	local function simple()
		local inst = CreateEntity()
		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()
		
		MakeInventoryPhysics(inst)
		MakeInventoryFloatable(inst, "small")

		inst.AnimState:SetBank(symname)
		inst.AnimState:SetBuild(fname)
		inst.AnimState:PlayAnimation("anim")

		inst:AddTag("venting")
		inst:AddTag("hat")
		inst:AddTag("nearsighted_glasses")
		inst:AddTag("goggles")
		inst:AddTag("invisiblegoggles")
		
		inst.entity:SetPristine()
	
		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("inspectable")
		
		inst:AddComponent("tradable")
		
		MakeHauntableLaunch(inst)

		return inst
	end

	local function normal_onequip(inst, owner)		
		onequip(inst, owner)
		
		owner:AddTag("spyer")
		
		if owner.spy then
			owner.spy:set(true)
		end

		if owner.prefab == "wagstaff" then
			owner.AnimState:OverrideSymbol("face", "wagstaff_face_swap", "face")		
		end
	end

	local function normal_onunequip(inst, owner)
		onunequip(inst, owner)
		
		owner:RemoveTag("spyer")
		
		if owner.spy then
			owner.spy:set(false)
		end

		if owner.prefab == "wagstaff" then
			owner.AnimState:ClearOverrideSymbol("face")
		end
	end

	local function normal()		
		local inst = simple()
		
		inst:AddTag("sees_hiddendanger")
		inst:AddTag("spygoggles")
		inst:AddTag("magnifying_glass")
		
		inst.entity:SetPristine()
		
		if not TheWorld.ismastersim then
			return inst
		end
		
		inst:AddComponent("inventoryitem")	
		inst.components.inventoryitem.atlasname = "images/inventoryimages/wagstaffnormalgoggles.xml"
		inst.components.inventoryitem.imagename = "wagstaffnormalgoggles"

		inst:AddComponent("equippable")
		if TUNING.GOGGLES_RESTRICTED then
			inst.components.equippable.restrictedtag = "tinkerer"
		end
		inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
		inst.components.equippable:SetOnEquip(normal_onequip)
		inst.components.equippable:SetOnUnequip(normal_onunequip)

		inst:AddComponent("fueled")	
		inst.components.fueled.fueltype = FUELTYPE.USAGE
		inst.components.fueled:InitializeFuelLevel(TUNING.GOGGLES_NORMAL_PERISHTIME)
		inst.components.fueled:SetDepletedFn(inst.Remove)
		inst.components.fueled.no_sewing = true

		return inst
	end

    local function heat_onequip(inst, owner)
		onequip(inst, owner)
	    owner.SoundEmitter:PlaySound("dontstarve_wagstaff/characters/wagstaff/goggles/heat_on") --TODO: play only for the person equipping
    end

    local function heat_onunequip(inst, owner)
        onunequip(inst, owner)
	    owner.SoundEmitter:PlaySound("dontstarve_wagstaff/characters/wagstaff/goggles/heat_off")
    end

	local function heat()
		local inst = simple()
		
		inst:AddTag("no_sewing")	
		inst:AddTag("clearfog")
		inst:AddTag("clearclouds")
		inst:AddTag("heatvision")
		inst:AddTag("nightvision")
		
		if not TheWorld.ismastersim then
			return inst
		end
		
		inst:AddComponent("inventoryitem")	
		inst.components.inventoryitem.atlasname = "images/inventoryimages/wagstaffheatgoggles.xml"
		inst.components.inventoryitem.imagename = "wagstaffheatgoggles"
	
		inst:AddComponent("equippable")
		if TUNING.GOGGLES_RESTRICTED then
			inst.components.equippable.restrictedtag = "tinkerer"
		end
		inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
        inst.components.equippable:SetOnEquip( heat_onequip )
        inst.components.equippable:SetOnUnequip( heat_onunequip )
		
		inst:AddComponent("fueled")		
		inst.components.fueled.fueltype = "USAGE"
		inst.components.fueled:InitializeFuelLevel(TUNING.GOGGLES_HEAT_PERISHTIME)
		inst.components.fueled:SetDepletedFn(inst.Remove)
		inst.components.fueled.accepting = true

		return inst
	end

    local function armor_onequip(inst, owner)
		onequip(inst, owner)		
    	owner.SoundEmitter:PlaySound("dontstarve_wagstaff/characters/wagstaff/goggles/armor_on")    		
		owner.AnimState:Hide("HAIR_HAT")
		owner.AnimState:Hide("HAIR_NOHAT")
		owner.AnimState:Hide("HAIR")		
    end

    local function armor_onunequip(inst, owner)
        onunequip(inst, owner)
    	owner.SoundEmitter:PlaySound("dontstarve_wagstaff/characters/wagstaff/goggles/armor_off")
      	owner.AnimState:Show("HAIR_HAT")
		owner.AnimState:Show("HAIR_NOHAT")
		owner.AnimState:Show("HAIR")      	
    end

	local function armor()
		local inst = simple()
		
		inst:AddTag("visorvision")
		
		if not TheWorld.ismastersim then
			return inst
		end
		
		inst:AddComponent("inventoryitem")
		inst.components.inventoryitem.atlasname = "images/inventoryimages/wagstaffarmorgoggles.xml"
		inst.components.inventoryitem.imagename = "wagstaffarmorgoggles"

		inst:AddComponent("equippable")
		if TUNING.GOGGLES_RESTRICTED then
			inst.components.equippable.restrictedtag = "tinkerer"
		end
		inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
		inst.components.equippable:SetOnEquip( armor_onequip )
        inst.components.equippable:SetOnUnequip( armor_onunequip )

		inst:AddComponent("armor")
    	inst.components.armor:InitCondition(TUNING.GOGGLES_ARMOR_ARMOR, TUNING.GOGGLES_ARMOR_ABSORPTION)

		return inst
	end	

	local function onattack_shoot(inst, attacker, target)
	    if target.components.burnable and not target.components.burnable:IsBurning() then
	        if target.components.freezable and target.components.freezable:IsFrozen() then           
	            target.components.freezable:Unfreeze()            
	        else            
	            if target.components.fueled and target:HasTag("campfire") and target:HasTag("structure") then
	                local fuel = SpawnPrefab("cutgrass")
	                if fuel then target.components.fueled:TakeFuelItem(fuel) end
	            else
	                target.components.burnable:Ignite(true)
	            end
	        end   
	    end
	    if target:HasTag("aquatic") and not target.components.burnable then 
	        local pt = target:GetPosition()
	        local smoke = SpawnPrefab("smoke_out")
	        smoke.Transform:SetPosition(pt:Get())

	         if target.SoundEmitter then 
	            target.SoundEmitter:PlaySound("dontstarve_DLC002/common/fire_weapon_out") 
	        end 
	    end 
	    if target.components.freezable then
	        target.components.freezable:AddColdness(-1) --Does this break ice staff?
	        if target.components.freezable:IsFrozen() then
	            target.components.freezable:Unfreeze()            
	        end
	    end
	    if target.components.sleeper and target.components.sleeper:IsAsleep() then
	        target.components.sleeper:WakeUp()
	    end
	end

    local function shoot_onequip(inst, owner)
		onequip(inst, owner)
    end

    local function shoot_onunequip(inst, owner)
        onunequip(inst, owner)
    end

	local function shoot()	
		local inst = simple()
		
		inst:AddTag("fryfocals")
		inst:AddTag("fryfocalvision")
		inst:AddTag("rangedweapon")
		
		if not TheWorld.ismastersim then
			return inst
		end
		
		inst:AddComponent("inventoryitem")
		inst.components.inventoryitem.atlasname = "images/inventoryimages/wagstaffshootgoggles.xml"
		inst.components.inventoryitem.imagename = "wagstaffshootgoggles"
		
		inst:AddComponent("equippable")
		if TUNING.GOGGLES_RESTRICTED then
			inst.components.equippable.restrictedtag = "tinkerer"
		end
		inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
        inst.components.equippable:SetOnEquip(shoot_onequip)
        inst.components.equippable:SetOnUnequip(shoot_onunequip)

	    inst:AddComponent("weapon")
    	inst.components.weapon:SetDamage(50)
    	inst.components.weapon:SetRange(8, 10)    	
    	inst.components.weapon:SetProjectile("fryfocals_charge")
    	inst.components.weapon:SetOnAttack(onattack_shoot)
		
		inst:AddComponent("finiteuses")
		inst.components.finiteuses:SetMaxUses(TUNING.GOGGLES_SHOOT_USES)
		inst.components.finiteuses:SetUses(TUNING.GOGGLES_SHOOT_USES)
		inst.components.finiteuses:SetOnFinished(function() inst:Remove() end)

		return inst
	end			

	local fn = nil
	local prefabs = {
		"hiddendanger_fx",
		"fryfocals_charge",
	}

	if name == "gogglesnormal" then
		fn = normal
	elseif name == "gogglesheat" then
		fn = heat
	elseif name == "gogglesarmor" then
		fn = armor
	elseif name == "gogglesshoot" then
		fn = shoot		
	end

	return Prefab( prefabname, fn or simple, assets, prefabs)
end

return MakeGoggle("gogglesnormal"),
	   MakeGoggle("gogglesheat"),
	   MakeGoggle("gogglesarmor"),
	   MakeGoggle("gogglesshoot")