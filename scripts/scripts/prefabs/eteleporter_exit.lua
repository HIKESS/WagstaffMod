require "prefabutil"

local _G = _G or GLOBAL

local assets =
{
	Asset("ANIM", "anim/eteleporter.zip"),
    Asset("ANIM", "anim/swap_engie_building.zip"),
}

local prefabs =
{
    "eshockfx",
    "ehealfx",
    "eteleringexit",
    "scrap",
    "collapse_small",
	"deer_fire_burst",
	"ember_short_fx",
}

local function customfxend(inst)
    inst.AnimState:PlayAnimation("exit")
	if inst.tefx ~= nil then
		inst.tefx:Remove()
	end
	if inst.start2fx ~= nil then
		inst.start2fx:Cancel()
		inst.start2fx = nil
	end
end

local function OnFxTick(inst, target)
	local x,y,z = inst.Transform:GetWorldPosition()
    inst.ringfx = _G.SpawnPrefab("eteleringexit")
	inst.ringfx.entity:SetParent(inst.entity)
    inst.ringfx.entity:AddFollower()
    inst.ringfx.Follower:FollowSymbol(inst.GUID, "shadow", 120, -30, 0)
	inst.ring2fx = _G.SpawnPrefab("eteleringexit")
    inst.ring2fx.Transform:SetPosition(x,1.6,z)
end

local function customfxstart(inst)
    inst.AnimState:PlayAnimation("idle_loop", true)
    local x,y,z = inst.Transform:GetWorldPosition()
	inst.tefx = _G.SpawnPrefab("ehealfx")
    inst.tefx.entity:SetParent(inst.entity)
    inst.tefx.entity:AddFollower()
    inst.tefx.Follower:FollowSymbol(inst.GUID, "shadow", 100, -150, 0)
	inst.tefx.Transform:SetScale(.5, .5, .5)
    inst.start2fx = inst:DoPeriodicTask(.4, OnFxTick)
end

local function onpreload(inst, data)
    inst.maker = data.maker
    inst.telexitID = data.telexitID
    if data.tag == 1 then
	inst:AddTag("lookingtolink")
    end
    if data.tag == 0 then
        inst.pairedGUID = data.pairedGUID
    end
    if data.name and inst.components.named then
        inst.components.named:SetName(data.name)
    end
end

local function onsave(inst, data)
    data.maker = inst.maker
    data.telexitID = inst.telexitID
    if inst:HasTag("lookingtolink") then
	data.tag = 1
    else
	data.tag = 0
	data.pairedGUID = inst.pairedGUID
    end
    if inst.components.named then
        data.name = inst.components.named.name
    end
end

local function onbuilt(inst, builder)
	if builder and builder.engieID then
		-- builder.engieID logged
		inst.telexitID = builder.engieID
		builder:PushEvent("engiebuilding")
		if builder.components.talker ~= nil then
			builder.components.talker:Say(_G.GetString(builder, "ANNOUNCE_TELEPORTERBUILT"))
		end
		local new_name = _G.subfmt("Teleporter Exit built by {builder}", { builder = builder.name })
		inst.components.named:SetName(new_name)
		inst.components.entitytracker:TrackEntity("builder", builder)
	end

    inst.AnimState:PlayAnimation("place")

    inst:AddTag("lookingtolink")
    inst.maker = builder and builder.name or "unknown"

    for k,v in pairs(_G.Ents) do
	if v.maker == inst.maker and v:HasTag("lookingtolink") and v:HasTag("eteleporter_enter") then
	    v.paired = inst
	    inst.paired = v
	    local new_id = tostring(math.random(1000000))
	    inst.pairedGUID = new_id
	    v.pairedGUID = new_id
	    inst.paired:RemoveTag("lookingtolink")
	    inst:RemoveTag("lookingtolink")
	    break
	end
    end
end

local function UnPair(inst)
    if inst.paired then
	inst.paired:AddTag("lookingtolink")
	inst.paired.paired = nil
	inst.paired.pairedGUID = nil
    end

    for k,v in pairs(_G.Ents) do
	if v and v.engieID == inst.telexitID then
		v:PushEvent("engiebuilding")
	end
    end
end

local function onhammered(inst, worker)
    if inst.ringfx then
	inst.ringfx:Remove()
    end
    if inst.tefx then
	inst.tefx:Remove()
    end

    if inst.paired then
	inst.paired:AddTag("lookingtolink")
	inst.paired.paired = nil
	inst.paired.pairedGUID = nil
    end

    local fx = _G.SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")

    inst:Remove()
    inst.components.lootdropper:DropLoot()

    for k,v in pairs(_G.Ents) do
	if v and v.engieID == inst.telexitID then
		v:PushEvent("engiebuilding")
		if v.components.sanity ~= nil then
		v.components.sanity:DoDelta(-_G.TUNING.ENGIE_BUILDINGLOSS/1.5)
		end
		if v.components.talker ~= nil then
        v.components.talker:Say(_G.GetString(v, "ANNOUNCE_TELEPORTER_DOWN"))
		end
	end
    end
end

local function onhit(inst, worker)
    inst.AnimState:PlayAnimation("hit")
	if not (worker:HasTag("engie") or worker:HasTag("spy") or worker:HasTag("engie_pardner")) then
	inst.components.workable:SetWorkLeft(6)
    end
	--[[
    local x,y,z = inst.Transform:GetWorldPosition()
    inst.fx = _G.SpawnPrefab("eshockfx")
    inst.fx.Transform:SetPosition(x,y,z)
    inst.fx.Transform:SetScale(1, 0.5, 1)
    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/lightninggoat/shocked_electric")--]]
end

-- This exists in case a teleporter gets removed some way other than hammering
local function OnTeleRemoved(inst)
    if inst.ringfx then
	inst.ringfx:Remove()
    end
    if inst.tefx then
	inst.tefx:Remove()
    end
	UnPair(inst)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
	if owner.components.health ~= nil and
    not owner.components.health:IsDead() then
	owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_REPLANTING"))
	end
	inst.AnimState:PlayAnimation("place")
	inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl1_place")
	inst:RemoveTag("carrying")
end

local function onequip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_body", "swap_engie_building", "swap_body")
	inst:AddTag("carrying")
end

local function Exit_OnDoneTeleporting(inst)
	inst:PushEvent("endfx")
	inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")

	local readyfx = _G.SpawnPrefab("deer_fire_burst")
	readyfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
--	readyfx.AnimState:SetMultColour( 250/255, 25/255, 25/255, 0 )

	local offset = 1
	local spd = 1.75 + math.random() * 2.5
	local angle = (135 + math.random() * 45) * _G.DEGREES * 1.1
	local x, y, z = inst.Transform:GetWorldPosition()
    if math.random() < .05 then 
	local bread = _G.SpawnPrefab("winter_food4")
		bread.Transform:SetPosition(x - math.sin(angle) * offset, 1.35, z - math.cos(angle) * offset)
		bread.Physics:SetVel(math.cos(angle) * spd, 12, math.sin(angle) * spd)
	end
end

local function oninit(inst)
    if inst.pairedGUID then
	for k,v in pairs(_G.Ents) do
	    if v.prefab == "eteleporter" and v.pairedGUID == inst.pairedGUID then
	        inst.paired = v
	        v.paired = inst
	    end
        end
    end
    if inst.maker == 0 then
        local fx = _G.SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("metal")
	inst:Remove()
    end
end

local function fn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("eteleporterexit.tex")

    inst.AnimState:SetBank("eteleporter")
    inst.AnimState:SetBuild("eteleporter")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("structure")
    inst:AddTag("eteleporter_exit")
    inst:AddTag("ebuild")
	inst:AddTag("nonpotatable")
    inst:AddTag("heavy")

    inst.no_wet_prefix = true
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventory")
    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("named")
    inst.components.named:SetName("Teleporter Exit")
	inst:AddComponent("entitytracker")-- This is for unique names, not IDs

	inst:AddComponent("engieteleporter")

	inst:ListenForEvent("doneteleporting", Exit_OnDoneTeleporting)

	inst:ListenForEvent("onremove", OnTeleRemoved)
	inst:ListenForEvent("ondeconstructstructure", UnPair)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(_G.ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(6)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)
	
	inst:AddComponent("symbolswapdata")
	inst.components.symbolswapdata:SetData("swap_engie_building", "swap_body")

    _G.MakeHauntableFreeze(inst) 

    inst.maker = 0

    inst.OnSave = onsave
    inst.OnPreLoad = onpreload
    inst.OnBuiltFn = onbuilt

    inst:DoTaskInTime(0, oninit)

	---------------------------------------
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = _G.ENGINEERITEMIMAGES
    inst.components.inventoryitem.cangoincontainer = false
    inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem.nobounce = true
    if inst.replica.inventoryitem then
        if inst.replica.inventoryitem.SetAtlas then
            inst.replica.inventoryitem:SetAtlas(_G.ENGINEERITEMIMAGES)
        end
    end

	inst:AddComponent("equippable")
    inst.components.equippable.equipslot = _G.EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = _G.TUNING.TOOLBOX_SPEED_MULT
	inst.components.equippable.restrictedtag = "engie"
    ---------------------------------------

    inst:ListenForEvent("endfx", customfxend)
    inst:ListenForEvent("startfx", customfxstart)

    return inst
end

local function onexit(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
    local shape = .3
    y = 0
    inst.Transform:SetPosition(x,y,z)
--	inst.AnimState:SetMultColour( 25/255, 5/255, 5/255, 0 )
    inst:DoPeriodicTask(.1, function(inst)
	shape = shape + .02
	y = y + .1
	inst.Transform:SetPosition(x,y,z)
--	inst.AnimState:SetMultColour( 250/255, 25/255, 25/255, 0 )
	inst.Transform:SetScale(shape, .10, shape)
	if y >= 1.0 then
	    inst:Remove()
	end
    end)
end

local function exitfn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("forcefield")
    inst.AnimState:SetBuild("forcefield")
    inst.AnimState:PlayAnimation("open")
	inst.AnimState:PushAnimation("idle_loop", true)
--    inst.AnimState:SetMultColour( 250/255, 25/255, 25/255, 0 )
    inst.Transform:SetScale(.3, .10, .3)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:DoTaskInTime(0, onexit)

    return inst
end

return _G.Prefab("eteleporter_exit", fn, assets, prefabs),
	_G.Prefab("eteleringexit", exitfn, assets),
	_G.MakePlacer("common/eteleporter_exit_placer", "esentry_item", "esentry_item", "idle")