local MakePlayerCharacter = require "prefabs/player_common"

local assets = {
	Asset("ANIM", "anim/wagstaff.zip"),
    Asset("ANIM", "anim/player_wagstaff.zip"),
    Asset("ANIM", "anim/wagstaff_face_swap.zip"),
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

local start_inv =
{
    default =
    {
        "gogglesnormalhat",
    },
}

for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
	start_inv[string.lower(k)] = v.WAGSTAFF
end

local prefabs = FlattenTree({ start_inv }, true)

local forge_fn = function(inst)
	inst:AddComponent("passive_armorbuff")
	inst:AddComponent("itemtyperestrictions")
	inst.components.itemtyperestrictions:SetRestrictions("melees","darts")
end

local function GetDistorted(inst)
    return not inst:HasTag("playerghost")
		and "DISTORTED"
end

local function checksoundsandfilter(inst)
    local health = inst.components.health:GetPercent()
	-- local erosion = inst.components.health.maxhealth / inst.components.health.currenthealth
	if health > .75 then
	    -- inst.soundsname = "wagstaff"
		inst.soundsname = "wagstaff_2" -- temporary fix
	elseif health < .75 and health > .50 then
	    inst.soundsname = "wagstaff_2"
	elseif health < .50 and health > .25 then
	    inst.soundsname = "wagstaff_3"
	elseif health < .25 then
	    inst.soundsname = "wagstaff_4"
	end
	local erosion = math.min(inst.components.health.currenthealth/ (TUNING.FLICKERTHRESHOLD * inst.components.health.maxhealth), 1)
	if inst:HasTag("playerghost") or health >= TUNING.FLICKERTHRESHOLD then
		inst.AnimState:SetErosionParams(0, -0.11, 0)
		inst.AnimState:SetSaturation(1)
	else
		inst.AnimState:SetErosionParams(0, -0.11, erosion - 1) -- Transparentcy I think???, Cut off hight, -Wagstaff's projectedness
		inst.AnimState:SetSaturation(erosion)
	end
end

local function UpdateTentacleWarnings(inst)
	local disable = (inst.replica.inventory ~= nil and not inst.replica.inventory:IsVisible())
	local warn_dist = 30

	if not disable and inst:HasTag("spyer") then
		local old_warnings = {}
		for t, w in pairs(inst.danger_active_warnings) do
			old_warnings[t] = w
		end

		local x, y, z = inst.Transform:GetWorldPosition()
		local tentacles = TheSim:FindEntities(x, y, z, warn_dist, {"tentacle", "invisible"})
		for i, t in ipairs(tentacles) do
			if t.replica.health ~= nil and not t.replica.health:IsDead() then
				--print("Hi")
				if inst.danger_active_warnings[t] == nil then
					-- print("it should work!")
					local fx = SpawnPrefab("hiddendanger_fx")
					fx.entity:SetParent(t.entity)
					inst.danger_active_warnings[t] = fx
				else
					old_warnings[t] = nil
				end
			end
		end

		for t, w in pairs(old_warnings) do
			inst.danger_active_warnings[t] = nil
			if w:IsValid() then
				ErodeAway(w, 0.5)
			end
		end
	elseif next(inst.danger_active_warnings) ~= nil then
		for t, w in pairs(inst.danger_active_warnings) do
			if w:IsValid() then
				w:Remove()
			end
		end
		inst.danger_active_warnings = {}
	end
	
	if not disable and inst:HasTag("spyer") then
		local x, y, z = inst.Transform:GetWorldPosition()
		local mystery = TheSim:FindEntities(x, y, z, warn_dist, {"_mystery"})
		for i, t in ipairs(mystery) do
			if inst.danger_active_warnings[t] == nil then
				-- print("Investigated? HMMM")
				if t:HasTag("investigated") then	
					-- print("PLEASE WORK")
					local fx = SpawnPrefab("identified_marker_fx")
					fx.entity:SetParent(t.entity)
					inst.danger_active_warnings[t] = fx
				else
					local fx = SpawnPrefab("peculiar_marker_fx")
					-- print(fx)
					--inst.Transform:SetPosition(fx.Transform:GetWorldPosition())
					-- print("Hi")
					fx.entity:SetParent(t.entity)
					inst.danger_active_warnings[t] = fx
				end
			else
				old_warnings[t] = nil
			end
		end
	elseif next(inst.danger_active_warnings) ~= nil then
		for t, w in pairs(inst.danger_active_warnings) do
			if w:IsValid() then
				w:Remove()
			end
		end
		inst.danger_active_warnings = {}
	end
	
	if not disable and inst.replica.inventory:EquipHasTag("heatvision") then
		local x, y, z = inst.Transform:GetWorldPosition()
		local mystery = TheSim:FindEntities(x, y, z, warn_dist)
		for i, t in ipairs(mystery) do
			if t.AnimState then
				local tuning
				if not t:HasTag("shadow") and ( t:HasTag("monster") or t:HasTag("animal") or t:HasTag("character") or t:HasTag("smallcreature") or t:HasTag("seacreature") or t:HasTag("oceanfish")) then	        			
					tuning = TUNING.GOGGLES_HEAT.HOT
				else
					tuning = TUNING.GOGGLES_HEAT.COLD
				end
				if tuning.BLOOM then
					t.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
				end
				t.AnimState:SetMultColour(unpack(tuning.MULT_COLOUR))
				t.AnimState:SetAddColour(unpack(tuning.ADD_COLOUR))
			end
		end
	end
end

local function DisableTentacleWarning(inst)
	if inst.danger_warning_task ~= nil then
		inst.danger_warning_task:Cancel()
		inst.danger_warning_task = nil
	end
		
	for t, w in pairs(inst.danger_active_warnings) do
		if w:IsValid() then
			w:Remove()
		end
	end
	inst.danger_active_warnings = {}
end

local function EnableTentacleWarning(inst)
	if inst.player_classified ~= nil then
		inst:ListenForEvent("playerdeactivated", DisableTentacleWarning)
		if inst.tentacle_warning_task == nil then
			inst.tentacle_warning_task = inst:DoPeriodicTask(0.1, UpdateTentacleWarnings)
		end
	else
	    inst:RemoveEventCallback("playeractivated", EnableTentacleWarning)
	end
end

local function onbecamehuman(inst)
	inst.components.locomotor:SetExternalSpeedMultiplier(inst, "wagstaff_speed_mod", 1)
end

local function onbecameghost(inst)
	inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "wagstaff_speed_mod")
	
	inst.soundsname = "wagstaff"
end

local function onload(inst)
    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
    inst:ListenForEvent("ms_becameghost", onbecameghost)

    if inst:HasTag("playerghost") then
        onbecameghost(inst)
    else
        onbecamehuman(inst)
    end
end

local common_postinit = function(inst) 
	inst.MiniMapEntity:SetIcon("wagstaff.tex")

	inst._getstatus = nil
	
	if TheNet:GetServerGameMode() == "quagmire" then
		inst.regorged = true
	end

	inst:AddTag("soulless")
    inst:AddTag("weakstomach")
	inst:AddTag("tinkerer")
	inst:AddTag("outofworldprojected")
	if not inst:HasTag("playerghost") then
		inst:AddTag("nearsighted")
	end
	
	inst.spy = net_bool(inst.GUID, "player.spy", "spydirty")
	
	if not TheNet:IsDedicated() then
		inst.danger_active_warnings = {}
		inst:ListenForEvent("playeractivated", EnableTentacleWarning)
	end
end

local master_postinit = function(inst)
	inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default
	
	if TheNet:GetServerGameMode() == "quagmire" then
		inst:DoTaskInTime(0, function()
			local brella = SpawnPrefab("telebrella")
			local goggles = SpawnPrefab("gogglesnormalhat")
			if brella then
				inst.components.inventory:Equip(brella)
			end
			if goggles then
				inst.components.inventory:Equip(goggles)
			end
		end)
	end
	
	inst.components.foodaffinity:AddPrefabAffinity("mashedpotatoes", TUNING.AFFINITY_15_CALORIES_LARGE)
	
	inst.soundsname = "wagstaff"

	inst.components.health:SetMaxHealth(150)
	inst.components.hunger:SetMax(225)
	inst.components.sanity:SetMax(150)

    inst:ListenForEvent("oneat", function(inst, data)
		if data.food:HasTag("preparedfood") or data.food.prefab:find("cooked") then 
			inst.components.talker:Say(GetString(inst.prefab, "ANNOUNCE_EAT", "GENERIC"))        
		else
			inst.components.talker:Say(GetString(inst.prefab, "ANNOUNCE_BAD_STOMACH"))
			inst.components.health:DoDelta(TUNING.WEAKSTOMACHPAIN, false, data.food.prefab --[[or "Uncooked food"]])
		end
	end)

	inst:ListenForEvent("healthdelta", function() checksoundsandfilter(inst) end)
	
	inst:DoTaskInTime(0, function() checksoundsandfilter(inst) end)
	
	if TheNet:GetServerGameMode() == "lavaarena" then
        inst.forge_fn = forge_fn
		return
    end
	
	inst.OnLoad = onload
end

return MakePlayerCharacter("wagstaff", prefabs, assets, common_postinit, master_postinit)