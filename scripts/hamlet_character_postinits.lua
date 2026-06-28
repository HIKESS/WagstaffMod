-- ============================================================
-- hamlet_character_postinits.lua (Wagstaff standalone extraction)
-- Source: Hamlet Characters mod (workshop 2399658326)
--
-- This file contains ONLY Wagstaff-related postinits/actions.
-- Dropped characters: Wheeler, Wilba, Warbucks.
--
-- Removed sections (non-Wagstaff):
--   * DODGE action (Wheeler)
--   * SPECIAL_ACTION3 action (pig royalty, Wilba/Warbucks)
--   * LOAD action + explosive+blunderbus ComponentAction (Warbucks blunderbuss)
--   * container.RemoveSingleItemBySlot (Wheeler's trusty_shooter)
--   * CheckItem + modparams.shooter/tracker + containers.widgetsetup override (Wheeler pewmatic)
--   * AddGlobalClassPostConstruct(widgets/inventorybar, Inv) SmallerInv (Wheeler)
--   * lootdropper:GetPotentialLoot (Wheeler tracker)
--   * combat:GetAttacked override + TUNING.WARBUCKSMELEE_MULT line (Warbucks)
--   * inventory Equip/Count/GetFreeSlotCount (Wheeler proportional inventory)
--   * player_pistol / player_mount_pistol anim builds (Wheeler)
--
-- Mixed-section surgical edits:
--   * combat:GetWeapon override KEPT (fryfocals are HEAD-slot weapons);
--     the Warbucks GetAttacked multiplier that lived in the same block DROPPED.
--   * AddPlayerPostInit anim build: player_wagstaff KEPT;
--     player_pistol / player_mount_pistol DROPPED.
-- ============================================================

local require = GLOBAL.require
local ACTIONS = GLOBAL.ACTIONS
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS

-----------------------------------------------------------------------
-- SPY action: Wagstaff's spygoggles investigation of trees/rocks that
-- have the _mystery component. Gated by TUNING.HCRtropicalsupport
-- (preserved as-is — set by modmain if Tropical Experience is enabled).
-----------------------------------------------------------------------
if not TUNING.HCRtropicalsupport then
	AddAction("SPY", "Investigate", function(act, data)
		if act.target and act.target.components._mystery then
			act.target.components._mystery:Investigate(act.doer)
			return true
		end
	end)

	ACTIONS.SPY.distance = 2
end

-- Offer SPY action on workable entities that have the _mystery tag when
-- the doer has the "spyer" tag (set by Wagstaff's normal goggles on equip).
AddComponentAction("SCENE", "workable", function(inst, doer, actions, right)
	if inst:HasTag("_mystery") and doer:HasTag("spyer") then
		table.insert(actions, ACTIONS.SPY)
	end
end)

-----------------------------------------------------------------------
-- mysteryprefabs: add the _mystery component to trees/rocks so Wagstaff
-- can investigate them via SPY action. The SW/Hamlet prefab names are
-- no-ops in pure DST (AddPrefabPostInit on missing prefabs is safe).
-- wagstaff.lua UpdateTentacleWarnings searches for the _mystery tag.
-----------------------------------------------------------------------
local mysteryprefabs = {
	--DST
		--Trees
	"evergreen",
	"evergreen_sparse",
	"twiggytree",
	"marsh_tree",
	"mushtree_tall",
	"mushtree_medium",
	"mushtree_small",
	"mushtree_moon",
	"livingtree",
	"deciduoustree",
	"tubertree",
	"moon_tree",
		--Rocks
	"rock1",
	"rock2",
	"rock_flintless",
	"rock_moon",
	"rock_moon_shell",

	--SW
		--Trees
	"palmtree",
	"jungletree",
	"mangrovetree",
	"livingjungletree",
	"volcano_shrub",
		--Rocks
	"rock_charcoal",
	"rock_obsidian",

	--Ham
		--Trees
	"rainforesttree",
	"clawpalmtree",
	"teatree",
	"tubertree",
		--Rocks
	"pig_ruins_artichoke",


}

for k, v in pairs(mysteryprefabs) do
	AddPrefabPostInit(v, function(inst)
		if not GLOBAL.TheWorld.ismastersim then
			return
		end
		
		if inst.components._mystery == nil then
			inst:AddComponent("_mystery")
		end
	end)
end

-- Add globalcolourmodifier to TheWorld. REQUIRED for heat-vision tinting —
-- heat-vision listener below accesses GLOBAL.TheWorld.components.globalcolourmodifier.
AddPrefabPostInit("world", function(inst)
	inst:AddComponent("globalcolourmodifier")
end)

-----------------------------------------------------------------------
-- Heat-vision colour modifier listener: when the local player has
-- heatvision (or forceheatvision) active, applies a colour/bloom tint
-- to world entities based on their tags. Reset when vision is disabled.
-----------------------------------------------------------------------
AddPlayerPostInit(function(inst)
	local function fn(ent)                          
		if ent == GLOBAL.TheWorld then
  --       local tuning = TUNING.GOGGLES_HEAT.GROUND
			-- ent.Map:SetMultColour(unpack(tuning.MULT_COLOUR))
			-- ent.Map:SetAddColour(unpack(tuning.ADD_COLOUR))

			-- local tuning = TUNING.GOGGLES_HEAT.WAVES
			-- local waves = ent.WaveComponent or ent.CloudComponent
			-- if waves then
			--      waves:SetMultColour(unpack(tuning.MULT_COLOUR))
			--      waves:SetAddColour(unpack(tuning.ADD_COLOUR))
			-- end
			return
		end
	    if ent.AnimState then
			local tuning
			if not ent:HasTag("shadow") and ( ent:HasTag("monster") or ent:HasTag("animal") or ent:HasTag("character") or ent:HasTag("smallcreature") or ent:HasTag("seacreature") or ent:HasTag("oceanfish")) then                                 
				tuning = TUNING.GOGGLES_HEAT.HOT
			else
				tuning = TUNING.GOGGLES_HEAT.COLD
			end
			if tuning.BLOOM then
				ent.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
			end
			ent.AnimState:SetMultColour(GLOBAL.unpack(tuning.MULT_COLOUR))
			ent.AnimState:SetAddColour(GLOBAL.unpack(tuning.ADD_COLOUR))
			-- ent.AnimState:SetSaturation(1 - tuning.DESATURATION)
		end
	end
	
	local function OnPlayerActivated(inst)
		GLOBAL.TheWorld:ListenForEvent("ccoverrides", function()
			inst:DoTaskInTime(0, function()
				if inst.components.playervision.heatvision or inst.components.playervision.forceheatvision then
					if GLOBAL.TheWorld.components.globalcolourmodifier then         
						GLOBAL.TheWorld.components.globalcolourmodifier:SetModifyColourFn(fn)
					end
				elseif inst.components.playervision.heatvision == false and inst.components.playervision.forceheatvision == false then
					if GLOBAL.TheWorld.components.globalcolourmodifier then
						GLOBAL.TheWorld.components.globalcolourmodifier:Reset()
					end
				end
			end)
		end, inst)
	end

	if not GLOBAL.TheNet:IsDedicated() then
		inst:ListenForEvent("playeractivated", OnPlayerActivated)
	end
end)

-----------------------------------------------------------------------
-- visorover widget: Wagstaff's armor goggles visor overlay.
-- Added to the controls widget on the local player's HUD.
-----------------------------------------------------------------------
AddClassPostConstruct( "widgets/controls", function(self)
	if self.owner == nil then 
		return
	end
	
	local VisorOver = require "widgets/visorover"
	self.visorover = self:AddChild( VisorOver(self.owner) )
	self.visorover:MoveToBack()
	
	-- local Nearsighted = require "widgets/nearsighted"
	-- self.nearsighted = self:AddChild( Nearsighted(self.owner) )
	-- self.nearsighted:MoveToBack()
end)

-----------------------------------------------------------------------
-- gogglesover widget: override ToggleGoggles so that when the player
-- has "invisiblegoggles" equipped, the storm overlay stays reduced
-- but the goggles art is hidden.
-----------------------------------------------------------------------
-- local OldToggleGoggles
local function NewToggleGoggles(self, show)
	-- OldToggleGoggles(self, show)
	
	local headgear = self.owner.components.inventory and self.owner.components.inventory:EquipHasTag("invisiblegoggles") or 
	self.owner.replica.inventory:EquipHasTag("invisiblegoggles")

	if show then
		if not self.shown then
			if not headgear == true then -- Remove the goggles widget while maintaining the reduced storm overlay
				-- self:Hide()
				-- self.storm_overlays:MoveToBack()
			-- else
				self:Show()
				self:AddChild(self.storm_overlays):MoveToBack()
			end
		end
	elseif self.shown then
		self:Hide()
		self.storm_root:AddChild(self.storm_overlays)
	end
	
end

AddClassPostConstruct("widgets/gogglesover", function(self)

	-- OldToggleGoggles = self.ToggleGoggles
	self.ToggleGoggles = NewToggleGoggles

end)

-----------------------------------------------------------------------
-- Add vision component + player_wagstaff anim build to ALL players.
-- NOTE: player_pistol / player_mount_pistol (Wheeler) DROPPED.
-- NOTE: master-sim guard is intentionally commented-out in the source
-- (vision runs client-side for the blur shader).
-----------------------------------------------------------------------
AddPlayerPostInit(function(inst)
	inst.AnimState:AddOverrideBuild("player_wagstaff")

	-- if GLOBAL.TheWorld.ismastersim then
		inst:AddComponent("vision")
		if inst:HasTag("nearsighted") then
			inst.components.vision.nearsighted = true
		end
		inst:DoTaskInTime(1, function()
			inst.components.vision:CheckForGlasses()
		end)
	-- end
end)

-----------------------------------------------------------------------
-- combat:GetWeapon override: adds HEAD-slot weapon support so the
-- stategraph ATTACK handler can detect fryfocals goggles (HEAD-slot
-- weapon). The Warbucks GetAttacked melee-damage-multiplier override
-- that lived in the same source block has been DROPPED.
-----------------------------------------------------------------------
AddComponentPostInit("combat", function(self)
	function self:GetWeapon()
		if self.inst.components.inventory ~= nil then
			local item = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
			return item ~= nil
				and item.components.weapon ~= nil
				and (item.components.projectile ~= nil or
					not (self.inst.components.rider ~= nil and
						self.inst.components.rider:IsRiding()) or
					item:HasTag("rangedweapon"))
				and item
			or nil
		end
	end
end)

AddClassPostConstruct("components/combat_replica", function(self)
	function self:GetWeapon()
		if self.inst.components.combat ~= nil then
			return self.inst.components.combat:GetWeapon()
		elseif self.inst.replica.inventory ~= nil then
			local item = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
			if item ~= nil and item:HasTag("weapon") then
				if item:HasTag("projectile") or item:HasTag("rangedweapon") then
					return item
				end
				local rider = self.inst.replica.rider
				return not (rider ~= nil and rider:IsRiding()) and item or nil
			end
		end
	end
end)

-----------------------------------------------------------------------
-- groundpounder: insert "groundpoundimmune" into noTags so the thumper's
-- groundpound doesn't hit itself (thumper tags itself groundpoundimmune).
-----------------------------------------------------------------------
AddComponentPostInit("groundpounder", function(self)
	table.insert(self.noTags, "groundpoundimmune")
end)

-----------------------------------------------------------------------
-- inspectable.GetDescription: return DESCRIBE_NEARSIGHTED string when
-- the viewer has a vision component but cannot clearly see the target.
-----------------------------------------------------------------------
AddComponentPostInit("inspectable", function(self)
	_OldGetDescription = self.GetDescription
	
	function self:GetDescription(viewer)
		if viewer.components.vision and not viewer.components.vision:testsight(self.inst) then
			return GLOBAL.GetString(viewer, "DESCRIBE_NEARSIGHTED")
		end
		
		return _OldGetDescription(self, viewer)
	end
end)

-- Global GetDescription override: same nearsighted behaviour for the
-- free-function form used by some inspect paths. Applies to wagstaff
-- or any nearsightedwidget player without "nearsighted_glasses" equipped.
local _GetDescription = GLOBAL.GetDescription
function GLOBAL.GetDescription(inst, item, modifier)
	if type(inst) == "table" and inst:GetDistanceSqToInst(item) > 30 and (inst:HasTag("nearsightedwidget") or inst.prefab == "wagstaff") and not inst.replica.inventory:EquipHasTag("nearsighted_glasses") then
		local character =
			type(inst) == "string"
			and inst
			or (inst ~= nil and inst.prefab or nil)

		character = character ~= nil and string.upper(character) or nil
		
		return GLOBAL.GetString(inst, "DESCRIBE_NEARSIGHTED")
	else
		return _GetDescription(inst, item, modifier)
	end
end

-----------------------------------------------------------------------
-- playervision: heatvision / fryfocalvision colour-cube override.
-- Tag handlers (heatvision / fryfocalvision) -> swap colour cube table.
-- Also interop with "Above The Clouds" mod (workshop-3322803908).
-----------------------------------------------------------------------
AddComponentPostInit("playervision", function(self)
	
	local FRYFOCALVISION_COLOURCUBE = GLOBAL.resolvefilepath("images/colour_cubes/shooting_goggles_cc.tex")
	
	local FRYFOCALVISION_COLOURCUBE_TABLE =
	{
		day = FRYFOCALVISION_COLOURCUBE,
		dusk = FRYFOCALVISION_COLOURCUBE,
		night = FRYFOCALVISION_COLOURCUBE,
		full_moon = FRYFOCALVISION_COLOURCUBE,
	}
	
	local HEATVISION_COLOURCUBE = GLOBAL.resolvefilepath("images/colour_cubes/heat_vision_cc.tex")
	
	local HEATVISION_COLOURCUBE_TABLE =
	{
		day = HEATVISION_COLOURCUBE,
		dusk = HEATVISION_COLOURCUBE,
		night = HEATVISION_COLOURCUBE,
		full_moon = HEATVISION_COLOURCUBE,
	}
	
	local function OnEquipChanged(inst)
		local self = inst.components.playervision
		if self.fryfocalvision == not inst.replica.inventory:EquipHasTag("fryfocalvision") then
			self.fryfocalvision = not self.fryfocalvision
			-- self.nightvision = not self.nightvision
			if not self.forcefryfocalvision then
				self:UpdateCCTable()
				-- inst:PushEvent("nightvision", self.nightvision)
			end
		end
		local self = inst.components.playervision
		if self.heatvision == not inst.replica.inventory:EquipHasTag("heatvision") then
			self.heatvision = not self.heatvision
			if not self.forceheatvision then
				self:UpdateCCTable()
			end
		end
	end
	
	local function OnInit(inst, self)
		inst:ListenForEvent("equip", OnEquipChanged)
		inst:ListenForEvent("unequip", OnEquipChanged)
		if not GLOBAL.TheWorld.ismastersim then
			inst:ListenForEvent("inventoryclosed", OnEquipChanged)
			if inst.replica.inventory == nil then
				return
			end
		end
		OnEquipChanged(inst)
	end
	
	self.fryfocalvision = false
    self.forcefryfocalvision = false
	
	self.heatvision = false
    self.forceheatvision = false
	
	self.inst:DoTaskInTime(0, OnInit, self)
	
	local _UpdateCCTable = self.UpdateCCTable
	function self:UpdateCCTable(...)
		if self.inst.replica.inventory and (self.inst.replica.inventory:EquipHasTag("heatvision") or self.inst.replica.inventory:EquipHasTag("fryfocalvision")) then
			local cctable = 
				((self.fryfocalvision or self.forcefryfocalvision) and FRYFOCALVISION_COLOURCUBE_TABLE)
				or ((self.heatvision or self.forceheatvision) and HEATVISION_COLOURCUBE_TABLE)
				or nil

			if cctable ~= self.currentcctable then
				self.currentcctable = cctable
				self.inst:PushEvent("ccoverrides", cctable)
			end
		else
			_UpdateCCTable(self, ...)
		end
	end

	-- Support for "Above The Clouds"
	-- print("test", GLOBAL)
	-- if GLOBAL.ToolUtil then --Checking for if ToolUtil is declared or not will crash the game if it's not declared because it is not declared. 
	--      print(GLOBAL.ToolUtil)
	if GLOBAL.KnownModIndex:IsModEnabled("workshop-3322803908") then
		GLOBAL.ToolUtil.HideFn(self.UpdateCCTable, _UpdateCCTable)
	end
	-- end
	
end)

-----------------------------------------------------------------------
-- hoverer.OnUpdate: when the local player has a vision component but
-- cannot clearly see the hovered entity, replace the entity name shown
-- in the tooltip with a random STRINGS.NAMES entry (nearsighted blur).
-----------------------------------------------------------------------
AddClassPostConstruct("widgets/hoverer", function(self)
	local _OnUpdate = self.OnUpdate
	function self:OnUpdate()
		_OnUpdate(self)
		if self.owner.owner ~= nil then self.owner = self.owner.owner end -- Waypoints mod changes self.owner to be MapWidget instead of the player.
		
		-- if self.owner ~= nil and self.owner.HasTag ~= nil and self.owner:HasTag("nearsighted") then
		if self.owner ~= nil and self.owner.components.vision ~= nil then
			local str = nil
			if not self.isFE then
				str = self.owner.hud and self.owner.HUD.controls:GetTooltip() or (self.owner.components and self.owner.components.playercontroller) and self.owner.components.playercontroller:GetHoverTextOverride()
			else
				str = self.owner:GetTooltip()
			end
			local lmb = nil
			if str == nil and not self.isFE and self.owner and self.owner:IsActionsVisible() and self.owner.components and self.owner.components.playercontroller then
				lmb = self.owner.components.playercontroller:GetLeftMouseAction()
			end
	
			if lmb ~= nil and lmb.target ~= nil then
				if not lmb.target.nearsightedname then
					lmb.target.nearsightedname = GLOBAL.GetRandomItem(GLOBAL.STRINGS.NAMES)
				end
			
				while type(lmb.target.nearsightedname) ~= "string" do
					lmb.target.nearsightedname = GLOBAL.GetRandomItem(GLOBAL.STRINGS.NAMES)
				end
			
				local overriden
				str, overriden = lmb:GetActionString()

				if colour == nil then
					if lmb.target ~= nil then
						if lmb.invobject ~= nil and not (lmb.invobject:HasTag("weapon") or lmb.invobject:HasTag("tool")) then
							colour = lmb.invobject:GetIsWet() and WET_TEXT_COLOUR or NORMAL_TEXT_COLOUR
						else
							colour = lmb.target:GetIsWet() and WET_TEXT_COLOUR or NORMAL_TEXT_COLOUR
						end
					elseif lmb.invobject ~= nil then
						colour = lmb.invobject:GetIsWet() and WET_TEXT_COLOUR or NORMAL_TEXT_COLOUR
					end
				end

				if not overriden and lmb.target ~= nil and lmb.invobject == nil and lmb.target ~= lmb.doer then
					local name = lmb.target.nearsightedname
					if name ~= nil then
						local adjective = lmb.target:GetAdjective()
						str = str.." "..(adjective ~= nil and (adjective.." "..name) or name)

						if lmb.target.replica.stackable ~= nil and lmb.target.replica.stackable:IsStack() then
							str = str.." x"..tostring(lmb.target.replica.stackable:StackSize())
						end
					end
				end
			
				if self.owner and self.owner:IsValid() and lmb.target:IsValid() --[[]]and not (self.owner.components.vision ~= nil and self.owner.components.vision:testsight(lmb.target)) --[[self.owner:GetDistanceSqToInst(lmb.target) > 30 and self.owner.replica.inventory and not self.owner.replica.inventory:EquipHasTag("nearsighted_glasses")]] then
					self.text:SetString(str)
					self.text:Show()
				end
			end
		end
	end
end)


-----------------------------------------------------------------------
-- wagstafftool_nameupdater: base-game wagstaff_tool_1..5 prefabs show
-- a "layman" display name for non-Wagstaff/non-Winona players so other
-- players see a less technical name for Wagstaff's dropped tools.
-----------------------------------------------------------------------
local function wagstafftool_nameupdater(inst)
    if GLOBAL.ThePlayer and not (GLOBAL.ThePlayer.prefab == "winona" or GLOBAL.ThePlayer.prefab == "wagstaff") then
	return GLOBAL.STRINGS.NAMES[string.upper(inst.prefab.."_LAYMAN")]
    else
	return GLOBAL.STRINGS.NAMES[string.upper(inst.prefab)]
    end
end

for i = 1, 5 do
	AddPrefabPostInit("wagstaff_tool_"..i, function(inst)
		inst.displaynamefn = wagstafftool_nameupdater
	end)
end

-----------------------------------------------------------------------
-- playerlightningtarget.DoStrike: push "playerlightningstruck" event so
-- the telebrella can react (telebrella reads player lightning strikes
-- to teleport the player to a telipad during a storm).
-----------------------------------------------------------------------
AddComponentPostInit("playerlightningtarget", function(self)
	local DoStrike = self.DoStrike
	self.DoStrike = function(self)
		DoStrike(self)
		self.inst:PushEvent("playerlightningstruck")
	end
end)
