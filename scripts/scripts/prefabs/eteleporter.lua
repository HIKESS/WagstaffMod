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
    "eteleringenter",
    "scrap",
    "collapse_small",
	"deer_fire_burst",
}

local function customfxend(inst)
    if inst.tefx ~= nil then
		inst.tefx:Remove()
	end
	if inst.startfx ~= nil then
		inst.startfx:Cancel()
		inst.startfx = nil
    end
end

local function customfxend_enter(inst)
	local finishfx = _G.SpawnPrefab("deer_fire_burst")
	finishfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
--	finishfx.AnimState:SetMultColour( 250/255, 25/255, 25/255, 0 )
end

local function OnFxTick(inst, target)
	local x,y,z = inst.Transform:GetWorldPosition()
    inst.ringfx = _G.SpawnPrefab("eteleringenter")
	inst.ringfx.entity:SetParent(inst.entity)
    inst.ringfx.entity:AddFollower()
    inst.ringfx.Follower:FollowSymbol(inst.GUID, "shadow", 120, -30, 0)
	inst.ring2fx = _G.SpawnPrefab("eteleringenter")
    inst.ring2fx.Transform:SetPosition(x,1.6,z)
end

local function customfxstart(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
	inst.tefx = _G.SpawnPrefab("ehealfx")
    inst.tefx.entity:SetParent(inst.entity)
    inst.tefx.entity:AddFollower()
    inst.tefx.Follower:FollowSymbol(inst.GUID, "shadow", 100, -150, 0)
	inst.tefx.Transform:SetScale(.5, .5, .5)
	inst.startfx = inst:DoPeriodicTask(.4, OnFxTick)
	--[[
        inst.startfx = inst:DoPeriodicTask(.4, function(inst)
            inst.ringfx = _G.SpawnPrefab("eteleringenter")
			inst.ringfx.entity:SetParent(inst.entity)
            inst.ringfx.entity:AddFollower()
            inst.ringfx.Follower:FollowSymbol(inst.GUID, "shadow", 120, -30, 0)
			inst.ring2fx = _G.SpawnPrefab("eteleringenter")
            inst.ring2fx.Transform:SetPosition(x,1.6,z)
        end)--]]
end

local function onpreload(inst, data)
    inst.maker = data.maker
    inst.telenterID = data.telenterID
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
    data.telenterID = inst.telenterID
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
		inst.telenterID = builder.engieID
		builder:PushEvent("engiebuilding")
		if builder.components.talker ~= nil then
			builder.components.talker:Say(_G.GetString(builder, "ANNOUNCE_TELEPORTERBUILT"))
		end
		local new_name = _G.subfmt("Teleporter Entrance built by {builder}", { builder = builder.name })
		inst.components.named:SetName(new_name)
		inst.components.entitytracker:TrackEntity("builder", builder)
	end

    inst.AnimState:PlayAnimation("place")

    inst:AddTag("lookingtolink")
    inst.maker = builder and builder.name or "unknown"

    for k,v in pairs(_G.Ents) do
	if v.maker == inst.maker and v:HasTag("lookingtolink") and v:HasTag("eteleporter_exit") then
	    inst.paired = v
	    v.paired = inst
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
	if v and v.engieID == inst.telenterID then
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
	if v and v.engieID == inst.telenterID then
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
    inst.AnimState:PushAnimation(inst.anim)
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
end

local function onequip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_body", "swap_engie_building", "swap_body")
	customfxend(inst)
end

--[[local function OnActivate(inst, doer)
	inst.paired:PushEvent("startfx")
	inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_run", "sound")

    if doer.components.talker ~= nil then
        doer.components.talker:ShutUp()
    end

    if doer.components.sanity ~= nil and not (doer:HasTag("engie") or doer:HasTag("nowormholesanityloss")) then
        doer.components.sanity:DoDelta(-_G.TUNING.ETELEPORT_PENALTY)
    end
end--]]

--TODO: Fix shard migration
local function oninit(inst)
    if inst.pairedGUID then
	for k,v in pairs(_G.Ents) do
	    if v.prefab == "eteleporter_exit" and v.pairedGUID == inst.pairedGUID then
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

local function onnear(inst, guy)
    inst.anim = "idle_loop"
    inst.AnimState:PlayAnimation(inst.anim, true)
    inst.SoundEmitter:PlaySound("dontstarve/common/ice_box_LP", "idlesound")
	if guy.replica.inventory ~= nil and guy.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.BODY) ~= nil and guy.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.BODY).prefab == "eteleporter" then
	return
	else
    customfxstart(inst)
	end
end

local function onfar(inst)
    inst.anim = "exit"
    inst.AnimState:PlayAnimation(inst.anim)
    inst.AnimState:PushAnimation("idle")
    customfxend(inst)
end

local function fn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("eteleporterentrance.tex")

    inst.AnimState:SetBank("eteleporter")
    inst.AnimState:SetBuild("eteleporter")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("structure")
    inst:AddTag("eteleporter_enter")
    inst:AddTag("ebuild")
	inst:AddTag("nonpotatable")
    inst:AddTag("heavy")

    inst.no_wet_prefix = true
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("engieteleporter")
    inst:AddComponent("inventory")
    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("named")
    inst.components.named:SetName("Teleporter Entrance")
	inst:AddComponent("entitytracker")-- This is for unique names, not IDs

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

	inst:ListenForEvent("endfx", customfxend_enter)

	inst:ListenForEvent("onremove", OnTeleRemoved)
	inst:ListenForEvent("ondeconstructstructure", UnPair)

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(2, 2)
    inst.components.playerprox.onnear = onnear
    inst.components.playerprox.onfar = onfar

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(_G.ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(6)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)
	
	inst:AddComponent("symbolswapdata")
	inst.components.symbolswapdata:SetData("swap_engie_building", "swap_body")

    _G.MakeHauntableFreeze(inst) 
	
    inst.maker = 0
    inst.anim = "idle"

    inst.OnSave = onsave
    inst.OnPreLoad = onpreload
    inst.OnBuiltFn = onbuilt

    inst:DoTaskInTime(.1, oninit)

    return inst
end

local function eshockfxfn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("goosemoose_nest_fx")
    inst.AnimState:SetBuild("goosemoose_nest_fx")
    inst.AnimState:PlayAnimation("idle")
--    inst.AnimState:SetMultColour( 200/255, 25/255, 25/255, 0 )-- This is now deprecated, for whatever reason
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:ListenForEvent("animover", inst.Remove)

    return inst
end

local function onenter(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
    local shape = .5
    y = 1
    inst.Transform:SetPosition(x,y,z)
--	inst.AnimState:SetMultColour( 25/255, 5/255, 5/255, 0 )
    inst:DoPeriodicTask(.1, function(inst)
	shape = shape - .02
	y = y - .1
	inst.Transform:SetPosition(x,y,z)
--	inst.AnimState:SetMultColour( 250/255, 25/255, 25/255, 0 )
	inst.Transform:SetScale(shape, .10, shape)
	if y <= 0.0 then
	    inst:Remove()
	end
    end)
end

local function enterfn()
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
    inst.Transform:SetScale(.5, .10, .5)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:DoTaskInTime(0, onenter)

    return inst
end

return _G.Prefab("eteleporter", fn, assets, prefabs),
	_G.Prefab("eshockfx", eshockfxfn, assets),
	_G.Prefab("eteleringenter", enterfn, assets),
	_G.MakePlacer("common/eteleporter_placer", "esentry_item", "esentry_item", "idle")