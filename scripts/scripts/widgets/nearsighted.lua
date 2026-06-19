local Widget = require "widgets/widget"

local NearSighted = Class(Widget, function(self, owner)
    self.owner = owner
    Widget._ctor(self, "NearSighted")
    self:SetClickable(false)

    self.blur = self:AddChild(Image("images/fx5.xml", "fog_over.tex"))
    self.blur:SetVAnchor(ANCHOR_MIDDLE)
    self.blur:SetHAnchor(ANCHOR_MIDDLE)
    self.blur:SetScaleMode(SCALEMODE_FILLSCREEN)
	
	self.owner:ListenForEvent("equip", function() return self:CheckPlayerVision() end)
	self.owner:ListenForEvent("unequip", function() return self:CheckPlayerVision() end)
	self.owner:ListenForEvent("healthdelta", function() return self:CheckPlayerVision() end) --I fixed the bug... but at what cost, so laggily inefficient
	-- self.owner:ListenForEvent("ms_respawnedfromghost", function() return self:CheckPlayerVision() end) --death and respawnfromghost and these events seem to not work here, probabily server/client issues ;-;
	-- self.owner:ListenForEvent("ms_becameghost", function() return self:CheckPlayerVision() end)
	self.owner:DoTaskInTime(0, function() return self:CheckPlayerVision() end)

    self:Hide()
end)

function NearSighted:CheckPlayerVision()
	-- print("checking vision")
    local hat = self.owner.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
	if self.owner:HasTag("playerghost") then
		self:Hide()
		-- print("1")
	elseif self.owner:HasTag("nearsighted") then
		if hat and hat:HasTag("nearsighted_glasses") then
			self:Hide()
			self.owner:RemoveTag("nearsightedwidget")
			-- print("2")
		else
			self:Show()
			self.owner:AddTag("nearsightedwidget")
			-- print("3")
		end
	else
		if hat and hat:HasTag("nearsighted_glasses") then
			self:Show()
			self.owner:AddTag("nearsightedwidget")
			-- print("4")
		else
			self:Hide()
			self.owner:RemoveTag("nearsightedwidget")
			-- print("5")
		end
	end
end

return NearSighted