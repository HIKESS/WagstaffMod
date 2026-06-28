local EngieTeleporter = Class(function(self, inst)
    self.inst = inst
    self.boundEntrance = nil
end)

function EngieTeleporter:PushDoneTeleporting(doer)
	if doer ~= nil then
		if doer:HasTag("player") then
			if self.inst.telenterID and self.inst.telenterID ~= doer.engieID then
				doer:DoTaskInTime(doer:HasTag("engie") and 1 or 1.5, doer.components.talker:Say(GetString(doer, "ANNOUNCE_ENGIE_TELEPORT"))) -- for talker
			end
		end
	end

	local telefx = SpawnPrefab("ember_short_fx")
--	telefx.Transform:SetScale(.80, 0.5, .80)
	telefx.entity:SetParent(doer.entity)
end

function EngieTeleporter:TeleportAction(doer)	

    if self.boundEntrance.pairedGUID == nil then
	doer.components.talker:Say(GetString(doer, "ANNOUNCE_UNIMPLEMENTED"))
    end
--  TODO: Fix or introduce shard migrations!! Or deprecate this component
    if self.boundEntrance.pairedGUID then
	if self.boundEntrance.paired and not self.boundEntrance.paired:HasTag("carrying") then

	self.boundEntrance.paired:PushEvent("startfx")
	doer.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_run", "sound")
	if doer.components.talker ~= nil then
        doer.components.talker:ShutUp()
    end
--	doer.AnimState:PlayAnimation("townportal_enter_pre")
	doer:ScreenFade(false, 0)
	doer.sg:GoToState("forcetele")
	doer.components.locomotor:Clear()
	doer:Show()
    doer:DoTaskInTime(1.3, function()
	doer.Physics:Teleport(self.boundEntrance.paired:GetPosition():Get())

    if doer.components.leader ~= nil then
        for follower, v in pairs(doer.components.leader.followers) do
            follower.Physics:Teleport(self.boundEntrance.paired:GetPosition():Get())
        end
    end

    --special case for the chester_eyebone: look for inventory items with followers
    if doer.components.inventory ~= nil then
        for k, item in pairs(doer.components.inventory.itemslots) do
            if item.components.leader ~= nil then
                for follower, v in pairs(item.components.leader.followers) do
                    follower.Physics:Teleport(self.boundEntrance.paired:GetPosition():Get())
                end
            end
        end
        -- special special case, look inside equipped containers
        for k, equipped in pairs(doer.components.inventory.equipslots) do
            if equipped.components.container ~= nil then
                for j, item in pairs(equipped.components.container.slots) do
                    if item.components.leader ~= nil then
                        for follower, v in pairs(item.components.leader.followers) do
                            follower.Physics:Teleport(self.boundEntrance.paired:GetPosition():Get())
                        end
                    end
                end
            end
        end
    end

	    doer:SnapCamera()
		doer:ScreenFade(true, .5)
	    doer.SoundEmitter:KillSound("sound")
	    self.boundEntrance.paired:PushEvent("endfx")

	    doer:DoTaskInTime(3*FRAMES, function()
		self.inst:PushEvent("endfx")
		doer.sg:GoToState("portal_jumpout")
		self.boundEntrance.paired:PushEvent("doneteleporting")
		self:PushDoneTeleporting(doer)
	--	doer.components.talker:Say(GetString(doer, "ANNOUNCE_ENGIE_TELEPORT")) -- for wisecracker
	--	doer.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
	    end)
	end)

	end
    end
end

return EngieTeleporter