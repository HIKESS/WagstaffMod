local assets =
{
	Asset("ANIM", "anim/hat_gogglesshoot.zip"),		
	
	Asset("ATLAS", "images/inventoryimages/wagstaffshootgoggles.xml"),
	Asset("IMAGE", "images/inventoryimages/wagstaffshootgoggles.tex"),
}

local tuning_values = TUNING.WAGSTAFFFORGEGOGGLES

local function onequip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_hat", "hat_gogglesshoot", "swap_hat")
    owner.AnimState:Show("HAT")
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_hat")
    owner.AnimState:Hide("HAT")
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
	    target.components.freezable:AddColdness(-1)
	    if target.components.freezable:IsFrozen() then
	        target.components.freezable:Unfreeze()            
	    end
	end

	if target.components.sleeper and target.components.sleeper:IsAsleep() then
	    target.components.sleeper:WakeUp()
	end
end

local function Laser(inst, caster, pos)
	inst.components.weapon:SetDamage(74)
	
	inst.components.rechargeable:StartRecharge()
	inst.components.aoespell:OnSpellCast(caster)
	inst:DoTaskInTime(1, function()
		inst.components.weapon:SetDamage(tuning_values.DAMAGE)
	end)
end

local weapon_values = {
	projectile = "fryfocals_charge",
	AOESpell = Laser,
}

local function fn()
	local inst = COMMON_FNS.WEAPONS.CommonWeaponFN("gogglesshoothat", "hat_gogglesshoot", "anim", nil, "wagstaffshootgoggles", {"swap_hat", "hat_gogglesshoot", "swap_hat",}, weapon_values, tuning_values)
	-----------------------------------------
	COMMON_FNS.AddTags(inst, "venting", "hat", "nearsighted_glasses", "projectile", "wagstaffgoggles", "wagstafffire")
	-----------------------------------------
	if not TheWorld.ismastersim then
        return inst
    end
	-----------------------------------------
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)
	return inst
end

return ForgePrefab("gogglesforgehat", fn, assets, nil, nil, "WEAPONS", false, "images/inventoryimages/wagstaffshootgoggles.xml", "wagstaffshootgoggles.tex", nil, tuning_values, STRINGS.FORGED_FORGE.WEAPONS.WAGSTAFFFORGEGOGGLES.ABILITIES, "hat_gogglesshoot", "common_hand")