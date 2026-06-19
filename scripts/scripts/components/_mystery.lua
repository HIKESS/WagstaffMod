local _Mystery = Class(function(self, inst)
    self.inst = inst

	inst:DoTaskInTime(0, function()
		if not self.rolled then 
			self:RollForMystery()         		
		end
	end)
end)

function _Mystery:GenerateReward()
	local mid_tier = {"flint", "goldnugget"}
	local high_tier = {}
	local NUM_RELICS = 5
	local reward = nil

	for i=1, NUM_TRINKETS do
		table.insert(mid_tier, "trinket_" .. tostring(i))
	end

	if TUNING.HCRtropicalsupport then

		table.insert(mid_tier, "oinc")
		table.insert(mid_tier, "oinc10")

		for i=1,3 do
			table.insert(high_tier, "relic_" .. tostring(i))
		end

		if math.random() <= TUNING.MYSTERY_NIL_CHANCE then
			reward = nil
		elseif math.random() <= TUNING.MYSTERY_MID_CHANCE then
			reward = mid_tier[math.random(#mid_tier)]
		else
			reward = high_tier[math.random(#high_tier)]
		end


	else

		if math.random() <= TUNING.MYSTERY_NIL_CHANCE then
			reward = nil
		else--if math.random() <= 1 then
			reward = mid_tier[math.random(#mid_tier)]
		end

	end

	if TUNING.HCRDEBUG then
		local printprefab = self.inst.prefab
		if printprefab == nil then
			printprefab = "NIL"
		end
		if reward ~= nil then
			print("Peculiar object " .. printprefab .. " rolled reward: " .. reward)
		else
			print("Peculiar object " .. printprefab .. " rolled no reward")
		end
	end

	return reward
end

function _Mystery:AddReward(reward)
	local color = 0.5 + math.random() * 0.5
    self.inst.AnimState:SetMultColour(color - 0.15, color - 0.15, color, 1)

	self.inst:AddTag("_mystery")
	self.reward = reward or self:GenerateReward()

	self.inst:ListenForEvent("onremove", function()
		if self.inst:HasTag("_mystery") and self.inst.components._mystery.investigated then
			self.inst.components.lootdropper:SpawnLootPrefab(self.reward)
		end
	end)
end

function _Mystery:RollForMystery()
	self.rolled = true
	if math.random() <= TUNING.MYSTERY_CHANCE then
		self:AddReward()
	end
end

function _Mystery:OnLoad(data)
	if data.reward then 
		self.reward = data.reward
	end
	if data.investigated then
		self.investigated = data.investigated
	end

	if data.reward then
		self:AddReward(data.reward)
	end
	if data.rolled then
		self.rolled = data.rolled
	end
end

function _Mystery:OnSave()
	local data = {}

	if self.reward then
		data.reward = self.reward
	end

	if self.investigated then
		data.investigated = self.investigated
	end

	data.rolled = self.rolled
	
	return data
end

function _Mystery:IsActionValid(action, right)
    return self.inst:HasTag("_mystery") and action == ACTIONS.SPY
end

function _Mystery:Investigate(doer)	
	if self.reward then
		doer.components.talker:Say(GetString(doer.prefab, "ANNOUNCE_MYSTERY_FOUND"))
		self.inst:AddTag("investigated")
		self.investigated = true
	else
		doer.components.talker:Say(GetString(doer.prefab, "ANNOUNCE_MYSTERY_NOREWARD"))
		self.inst:RemoveTag("_mystery")
	end
end

return _Mystery