local easing = require("easing")

local function BlindActionFilter(inst, action)
	local target = TheInput:GetWorldEntityUnderMouse() --[[Niko: Causes a server desync]]
	-- for k, v in pairs(action) do
	-- 	print(k, v)
	-- end
	return (action.blind_ok or target == nil or target:HasTag("INLIMBO") or inst.components.vision:testsight(target)) and not action.ghost_exclusive
end

local function ConfigureActions(inst, blind) --Not ready yet
	if TheWorld.ismastersim == true then return end
	if inst.components.playeractionpicker ~= nil then
		if blind == true then
	        inst.components.playeractionpicker:PushActionFilter(BlindActionFilter, 50)
	    else
	    	inst.components.playeractionpicker:PopActionFilter(BlindActionFilter)
	    end
	end
end

-- local function OnDeactivate(inst, data)
-- 	local self = inst.components.vision
-- 	if self.focused ~= true then
-- 		self:SetFocused()
-- 	end
-- end

local Vision = Class(function(self, inst)
	self.nearsighted = false
    self.inst = inst   
	self.focused = true
	self:SetFocused()

    inst:ListenForEvent("equip", function() self:CheckForGlasses() end)
    inst:ListenForEvent("unequip", function() self:CheckForGlasses() end)
	-- inst:ListenForEvent("playerdeactivate", OnDeactivate)

    -- v2.0.98 FIX: Delay StartUpdating by 1 second so the entity is fully
    -- initialized before OnUpdate tries to access AnimState. Without this,
    -- GetSymbolPosition("head") can fail during shard migration when the
    -- AnimState hasn't received its build/bank from the server yet.
    self.inst:DoTaskInTime(1, function()
        if self.inst:IsValid() then
            self.inst:StartUpdatingComponent(self)
        end
    end)
end)

function Vision:OnUpdate(dt)
	if self.inst:HasTag("playerghost") then -- Might bog down the client a bit, but I can't find any other options.
		if self.wasghost ~= true then
			self:CheckForGlasses()
			self.wasghost = self.inst:HasTag("playerghost")
		end
	else
		if self.wasghost == true then
			self:CheckForGlasses()
			self.wasghost = self.inst:HasTag("playerghost")
		end
	end

	if self.inst ~= ThePlayer then return end

	-- v2.0.98 FIX: pcall guard against invalid AnimState during shard migration
	local hx, hy, hz = 0, 0, 0
	pcall(function()
		hx, hy, hz = self.inst.AnimState:GetSymbolPosition("head", 0, 0, 0)
	end)

	local px, py = TheSim:GetScreenPos(hx,hy,hz)
	local w,h = TheSim:GetScreenSize()
	PostProcessor:SetBlurCenter(px/w, py/h)

end

function Vision:SetFocused()
	self.focused = true
	-- ConfigureActions(self.inst, false) --Not quite ready yet
	if self.inst ~= ThePlayer then return end --This should only run on the client of the attatched player
	if PostProcessor.SetBlurEnabled ~= nil then -- Not sure why this is an issue sometimes, but let's not crash just in case.
		PostProcessor:SetBlurEnabled(false)
	else
		print("HCR PostProcessor Error! SetBlurEnabled was nil!")
	end
end

function Vision:SetUnfocused()
	self.focused = false
	-- ConfigureActions(self.inst, true) --Not quite ready yet

	if self.inst ~= ThePlayer then return end --This should only run on the client of the attatched player
	if PostProcessor.SetBlurEnabled ~= nil then -- Not sure why this is an issue sometimes, but let's not crash just in case.
		PostProcessor:SetBlurEnabled(true)
	else
		print("HCR PostProcessor Error! SetBlurEnabled was nil!")
	end
	if PostProcessor.SetBlurParams ~= nil then
		PostProcessor:SetBlurParams(TUNING.NEARSIGHTED_BLUR_START_RADIUS, TUNING.NEARSIGHTED_BLUR_STRENGTH)
	else
		print("HCR PostProcessor Error! SetBlurParams was nil!")
	end
end

function Vision:CheckForGlasses()
	if TUNING.VISIONBLUR_ENABLED == false then
		if self.focused == false then
			self:SetFocused()
		end
		return
	end
	if self.inst:HasTag("playerghost") then
		if self.focused == false then
			self:SetFocused()
		end
		return
	end
    local headgear = self.inst.components.inventory and self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or 
		self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
    if headgear and headgear:HasTag("nearsighted_glasses") then  
    	if self.nearsighted then    		
    		self:SetFocused()    		
    	else
    		self:SetUnfocused()			
		end
    else
    	if self.nearsighted then
    		self:SetUnfocused()
    	else
    		self:SetFocused()			
		end
    end
	-- but...headgear can override this again
	if headgear and headgear.CustomFocus then
		headgear:CustomFocus(self.inst)
	end
end

function Vision:testsight(item)
	if item == nil or not item:IsValid() then
		return false
	end
	-- LIMBO gets things in inventory. Maybe it needs to be more robust than just that, but works for now		
	return self.focused == true or (item:GetDistanceSqToInst(self.inst) < TUNING.NEARSIGHTED_ACTION_RANGE*TUNING.NEARSIGHTED_ACTION_RANGE or item:HasTag("INLIMBO"))
end


return Vision
