local Queue = require "util/queue"

local Passive_ArmorBuff = Class(function(self, inst)
    self.inst = inst
	self.armorbuff = false
	self.damage_dealt = 0
	self.damage_threshold = 200
	self.radius = 8
	
	self.inst:ListenForEvent("onhitother", function() return self:OnDamageDealt() end)
end)

function Passive_ArmorBuff:OnDamageDealt(damage, is_alt, inst)
	--if not self.armorbuff and not is_alt then
		--self.damage_dealt = self.damage_dealt + damage
		--if self.damage_dealt >= self.damage_threshold then
			self:ApplyArmorBuff(inst)
		--end
	--end
end

function Passive_ArmorBuff:ApplyArmorBuff(inst)
	local armor = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
	armor.components.armor:SetAbsorption(armor.components.armor:ReturnAbsorption() + 0.10)
	self:ApplyBattleCryToNearbyPlayers()
	self.armorbuff = true
end

function Passive_ArmorBuff:ApplyArmorBuffToNearbyPlayers()
	for i,player in pairs(AllPlayers) do
		if self.player.userid ~= player.userid and player:IsNear(self.player, self.radius) and not player.components.health:IsDead() then
			local armor = player.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
			armor.components.armor:SetAbsorption(armor.components.armor:ReturnAbsorption() + 0.10)
		end
	end
end

return Passive_ArmorBuff