local assets=
{
	Asset("ANIM", "anim/telebrella.zip"),
	Asset("ANIM", "anim/swap_telebrella.zip"),
    Asset("ANIM", "anim/swap_telebrella_red.zip"),
    Asset("ANIM", "anim/swap_telebrella_green.zip"),
	
	Asset("ATLAS", "images/inventoryimages/telebrella.xml"),
	Asset("IMAGE", "images/inventoryimages/telebrella.tex"),
}

local function onfinished(inst)
    inst:Remove()
end

local function onequip(inst, owner) 
    owner.AnimState:OverrideSymbol("swap_object", "swap_telebrella_green", "swap_telebrella")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner) 
    owner.AnimState:Hide("ARM_carry") 
    owner.AnimState:Show("ARM_normal") 
end

local function blinkstaff_reticuletargetfn()
    local player = ThePlayer
    local rotation = player.Transform:GetRotation() * DEGREES
    local pos = player:GetPosition()
    for r = 13, 1, -1 do
        local numtries = 2 * PI * r
        local offset = FindWalkableOffset(pos, rotation, r, numtries, false, true, NoHoles)
        if offset ~= nil then
            pos.x = pos.x + offset.x
            pos.y = 0
            pos.z = pos.z + offset.z
            return pos
        end
    end
end

local function onblink(staff, pos, caster)
    staff.components.finiteuses:Use(1) 
end

local function OnBlinked(caster, self, dpt)
	if caster.sg == nil then
		caster:Show()
		if caster.components.health ~= nil then
			caster.components.health:SetInvincible(false)
		end
		if caster.DynamicShadow ~= nil then
			caster.DynamicShadow:Enable(true)
		end
	elseif caster.sg.statemem.onstopblinking ~= nil then
		caster.sg.statemem.onstopblinking()
	end
	local pt = dpt:GetPosition()
	if pt ~= nil and TheWorld.Map:IsPassableAtPoint(pt:Get()) and not TheWorld.Map:IsGroundTargetBlocked(pt) then
		caster.Physics:Teleport(pt:Get())
	end
end

local function fn()
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
	
	inst:AddComponent("reticule")
    inst.components.reticule.targetfn = blinkstaff_reticuletargetfn
    inst.components.reticule.ease = true

    inst.entity:SetPristine()
	
    if not TheWorld.ismastersim then
        return inst
    end
	
	inst:AddComponent("inspectable")
	
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/telebrella.xml"

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(10)
    inst.components.finiteuses:SetUses(10)
    inst.components.finiteuses:SetOnFinished(onfinished) 

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.UMBRELLA_DAMAGE)

    inst:AddComponent("blinkstaff")
    inst.components.blinkstaff.onblinkfn = onblink
	
	function inst.components.blinkstaff:Blink(pt, caster)
		if (caster.sg ~= nil and caster.sg.currentstate.name ~= "telebrella_finish") then
			return false
		elseif self.blinktask ~= nil then
			self.blinktask:Cancel()
		end

		if caster.sg == nil then
			caster:Hide()
			if caster.DynamicShadow ~= nil then
				caster.DynamicShadow:Enable(false)
			end
			if caster.components.health ~= nil then
				caster.components.health:SetInvincible(true)
			end
		elseif caster.sg.statemem.onstartblinking ~= nil then
			caster.sg.statemem.onstartblinking()
		end

		self.blinktask = caster:DoTaskInTime(0, OnBlinked, self, DynamicPosition(pt))

		if self.onblinkfn ~= nil then
			self.onblinkfn(self.inst, pt, caster)
		end

		return true
	end
   
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
	
	MakeHauntableLaunch(inst)
	
    return inst
end

return Prefab("quagmire_telebrella", fn, assets)