require "prefabutil"
require "tuning"

local assets =
{
	Asset("ANIM", "anim/teleport_pad.zip"),
	Asset("ANIM", "anim/teleport_pad_beacon.zip"),
	
	Asset("ATLAS", "images/inventoryimages/telipad.xml"),
	Asset("IMAGE", "images/inventoryimages/telipad.tex"),
}

local prefabs = 
{

}

local function onhammered(inst, worker)
	inst.components.lootdropper:DropLoot()
	SpawnPrefab("collapse_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
	inst:Remove()
	inst.SoundEmitter:PlaySound("dontstarve/common/destroy_wood")
end

local function onbuilt(inst, sound)
	inst.AnimState:PlayAnimation("place")
	inst.AnimState:PushAnimation("idle")	
	inst.SoundEmitter:PlaySound(sound)
end

local function onremove(inst)
	if TheWorld.telipads then
		for i,pad in ipairs(TheWorld.telipads) do
			if pad == inst then
				table.remove(TheWorld.telipads,i)
				break
			end
		end
	end
end

local function turnoff(inst)
	if inst.decor then
		for i,deco in ipairs(inst.decor) do
			if not deco.AnimState:IsCurrentAnimation("place") then
				deco.AnimState:PlayAnimation("off")
			end
		end	
	end
end

local function turnon(inst)
	if inst.decor then
		for i,deco in ipairs(inst.decor) do
			if not deco.AnimState:IsCurrentAnimation("place") then
				deco.AnimState:PlayAnimation("on")
			end
		end	
	end	
end

local function base()
	local rock_front = 1

	local decor_defs =
	{
		beacon = { { -1.28, 0, 1.14 } },
	}

    return function(Sim)
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()
		
		inst.entity:AddMiniMapEntity()
		inst.entity:AddMiniMapEntity():SetPriority(5)
		inst.MiniMapEntity:SetIcon("telipad.tex")
        
        inst:AddTag("structure")
        
        inst.AnimState:SetBank("teleport_pad")
        inst.AnimState:SetBuild("teleport_pad")
        inst.AnimState:PlayAnimation("idle")
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(3)
		
		inst.entity:SetPristine()
		
		if not TheWorld.ismastersim then
			return inst
        end

        inst:AddComponent("inspectable")

        inst.turnoff = turnoff
        inst.turnon = turnon

		inst.Transform:SetRotation(0)

		inst:AddComponent("lootdropper")
		inst:AddComponent("workable")
		inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
		inst.components.workable:SetWorkLeft(4)
		inst.components.workable:SetOnFinishCallback(onhammered)

		local sound_name = "hamletcharactersound/characters/wagstaff/telipad/telipad_1"

		inst:ListenForEvent("onbuilt", function () onbuilt(inst, sound_name) end)
		inst:ListenForEvent("onremove", function () onremove(inst) end)

		local decor_items = decor_defs
		inst.decor = {}
		for item_name, data in pairs( decor_items ) do
			for l, offset in pairs( data ) do
				local item_inst = SpawnPrefab( item_name )
				item_inst.AnimState:PlayAnimation("place")
				item_inst.AnimState:PushAnimation("off")
				item_inst.entity:SetParent( inst.entity )
				item_inst.Transform:SetPosition( offset[1], offset[2], offset[3] )
				table.insert( inst.decor, item_inst )
				if item_inst.placesound then
					inst.SoundEmitter:PlaySound(item_inst.placesound)
				end
			end
		end
        
		if not TheWorld.telipads then
			TheWorld.telipads = {}
		end
		table.insert(TheWorld.telipads,inst)

        return inst
    end
end    

local function makefn(bankname, buildname, animname)
    local function fn(Sim)
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
		inst.entity:AddNetwork()
        inst:AddTag("DECOR")
        
        inst.AnimState:SetBank(bankname)
        inst.AnimState:SetBuild(buildname)
        inst.AnimState:PlayAnimation(animname)
        
        inst.placesound = "hamletcharactersound/characters/wagstaff/telipad/telipad_2"

        return inst
    end
    return fn
end    

local function item(name, bankname, buildname, animname)
    return Prefab( "forest/objects/farmdecor/"..name, makefn(bankname, buildname, animname), assets )
end

return 	item("beacon", "teleport_pad_beacon", "teleport_pad_beacon", "off"),
		Prefab( "telipad", base(), assets, prefabs ),
	   	MakePlacer( "telipad_placer", "teleport_pad", "teleport_pad", "idle", true )