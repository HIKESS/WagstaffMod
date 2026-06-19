local GLOBAL = _G
local WagstaffAugments = Class(function(self, inst)
    self.inst = inst
    self.hand_enabled = false
    self.leg_enabled = false
    self._overcharged_task = nil
    self._overcharged_until = 0
end)

function WagstaffAugments:EnableHand()
    if self.hand_enabled then return end
    self.hand_enabled = true
    self.inst:AddTag("wagstaff_hand_active")

    -- TELEKINETIC AUTO-PICKUP (Lazy Forager style) - always active when hand augment is ON
    -- Picks one item at a time from range, using base game pickup logic
    self._hand_autopick_task = self.inst:DoPeriodicTask(TUNING.ORANGEAMULET_ICD or 0.33, function()
        if not self.inst.components.inventory then return end
        local item = FindPickupableItem(self.inst, TUNING.ORANGEAMULET_RANGE or 4, false)
        if item == nil then return end

        local didpickup = false
        if item.components.trap ~= nil then
            item.components.trap:Harvest(self.inst)
            didpickup = true
        end

        if self.inst.components.minigame_participator ~= nil then
            local minigame = self.inst.components.minigame_participator:GetMinigame()
            if minigame ~= nil then
                minigame:PushEvent("pickupcheat", { cheater = self.inst, item = item })
            end
        end

        SpawnPrefab("sand_puff").Transform:SetPosition(item.Transform:GetWorldPosition())

        if not didpickup then
            local item_pos = item:GetPosition()
            if item.components.stackable ~= nil then
                item = item.components.stackable:Get(1)
            end
            self.inst.components.inventory:GiveItem(item, nil, item_pos)
        end
    end)

    -- SANITY DRAIN: -2/min base
    self._hand_sanity_task = self.inst:DoPeriodicTask(30, function()
        if self.inst.components.sanity then
            self.inst.components.sanity:DoDelta(-1, true)
        end
    end)

    -- MK.II: strong grip (no drop on wetness)
    if self.inst:HasTag("wagstaff_hand_augment") then
        self.inst:AddTag("nodurabilityondrop")
    end

    if self.inst.components.talker then
        self.inst.components.talker:Say("Hand augment engaged.")
    end
end

function WagstaffAugments:DisableHand()
    if not self.hand_enabled then return end
    self.hand_enabled = false
    self.inst:RemoveTag("wagstaff_hand_active")

    -- Cancel telekinetic auto-pickup
    if self._hand_autopick_task then
        self._hand_autopick_task:Cancel()
        self._hand_autopick_task = nil
    end

    -- Cancel sanity drain
    if self._hand_sanity_task then
        self._hand_sanity_task:Cancel()
        self._hand_sanity_task = nil
    end

    self.inst:RemoveTag("nodurabilityondrop")

    if self.inst.components.talker then
        self.inst.components.talker:Say("Hand augment disengaged.")
    end
end

function WagstaffAugments:EnableLeg()
    if self.leg_enabled then return end
    self.leg_enabled = true
    self.inst:AddTag("wagstaff_leg_augment")
    -- Legs MK.II: 1.3x speed if Ballistic Bot deployed, else 1.15x (original)
    local speed = 1.15
    if self.inst.components.locomotor then
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wagstaff_leg", speed)
    end
    -- Ignore spider web / ground slowdown
    self.inst:AddTag("noslowdown")
    -- Legs MK.II: check for deployed Ballistic Bot nearby every 1 second
    self._leg_bot_check_task = self.inst:DoPeriodicTask(1, function()
        if self.inst.components.locomotor then
            if self._overcharged_until > GLOBAL.GetTime() then
                -- Overcharged active: 3x speed
                self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wagstaff_leg", 3.0)
            else
                local x, y, z = self.inst.Transform:GetWorldPosition()
                local bots = GLOBAL.TheSim:FindEntities(x, y, z, 15, {"ballistic"}, {"INLIMBO"})
                local has_deployed_bot = false
                for _, bot in ipairs(bots) do
                    if bot.components.follower and bot.components.follower:GetLeader() == self.inst then
                        has_deployed_bot = true
                        break
                    end
                end
                if has_deployed_bot then
                    -- 1.3x speed when near deployed Ballistic Bot
                    self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wagstaff_leg", 1.3)
                    -- Electric shock FX on legs
                    if math.random() < 0.3 then
                        local fx = GLOBAL.SpawnPrefab("electrichitsparks")
                        if fx then
                            fx.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                        end
                    end
                else
                    -- Normal leg augment speed (original)
                    self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wagstaff_leg", 1.15)
                end
            end
        end
    end)
    -- MK.II: act as lightning rod - player immune to lightning, instead triggers overcharged
    self._leg_lightning_listener = function(inst)
        if not self.leg_enabled then return end
        if self.inst:HasTag("wagstaff_leg_augment") and GLOBAL.TheWorld.state.israining then
            -- Absorb the lightning strike (prevent damage)
            -- Spawn a fake lightning rod strike at our position to redirect
            local x, y, z = self.inst.Transform:GetWorldPosition()
            local rod_fx = GLOBAL.SpawnPrefab("lightning")
            if rod_fx then rod_fx.Transform:SetPosition(x, y, z) end
            self:_ActivateOvercharged()
        end
    end
    self.inst:ListenForEvent("lightningstrike", self._leg_lightning_listener)
    -- Make player immune to lightning while leg is active
    self.inst:AddTag("electricdamageimmune")
    if self.inst.components.talker then
        self.inst.components.talker:Say("Leg augment engaged.")
    end
end

function WagstaffAugments:_ActivateOvercharged()
    if not self.leg_enabled then return end
    -- Cancel previous overcharge timer if already active
    if self._overcharged_task then
        self._overcharged_task:Cancel()
        self._overcharged_task = nil
    end
    self._overcharged_until = GLOBAL.GetTime() + 300  -- 5 minutes
    -- Set 3x speed
    if self.inst.components.locomotor then
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wagstaff_leg", 3.0)
    end
    -- Recharge 100% of leg augment fuel
    if self.inst.components.inventory then
        local leg_item = self.inst.components.inventory:FindItem(
            function(item) return item:HasTag("miamirick_leg") end
        )
        if leg_item and leg_item.components.finiteuses then
            leg_item.components.finiteuses:SetUses(leg_item.components.finiteuses.total)
        end
    end
    local fx = GLOBAL.SpawnPrefab("electrichitsparks")
    if fx then fx.Transform:SetPosition(self.inst.Transform:GetWorldPosition()) end
    if self.inst.components.talker then
        self.inst.components.talker:Say("OVERCHARGED! 3x Speed for 5 minutes!")
    end
    -- After 5min, restore speed
    self._overcharged_task = self.inst:DoTaskInTime(300, function()
        self._overcharged_until = 0
        if not (self.inst.components.locomotor and self.leg_enabled) then return end
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local bots = GLOBAL.TheSim:FindEntities(x, y, z, 15, {"ballistic"}, {"INLIMBO"})
        local has_bot = false
        for _, bot in ipairs(bots) do
            if bot.components.follower and bot.components.follower:GetLeader() == self.inst then
                has_bot = true; break
            end
        end
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "wagstaff_leg", has_bot and 1.3 or 1.15)
    end)
end

function WagstaffAugments:DisableLeg()
    if not self.leg_enabled then return end
    self.leg_enabled = false
    self.inst:RemoveTag("wagstaff_leg_augment")
    self.inst:RemoveTag("noslowdown")
    if self.inst.components.locomotor then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "wagstaff_leg")
    end
    -- Cancel Ballistic Bot check task
    if self._leg_bot_check_task then
        self._leg_bot_check_task:Cancel()
        self._leg_bot_check_task = nil
    end
    if self._overcharged_task then
        self._overcharged_task:Cancel()
        self._overcharged_task = nil
    end
    self._overcharged_until = 0
    self.inst:RemoveTag("electricdamageimmune")
    if self._leg_lightning_listener then
        self.inst:RemoveEventCallback("lightningstrike", self._leg_lightning_listener)
        self._leg_lightning_listener = nil
    end
    if self.inst.components.talker then
        self.inst.components.talker:Say("Leg augment disengaged.")
    end
end

function WagstaffAugments:OnAttackedFlicker(data)
    if not self.inst.components.inventory then return end
    if not data or not data.attacker then return end
    local flicker = self.inst.components.inventory:FindItem(function(item) return item:HasTag("miamirick_flicker") end)
    if flicker then
        -- Standalone: use DoRandomFlicker directly (no miamirick_flicker component)
        if flicker.DoRandomFlicker then
            flicker.DoRandomFlicker(self.inst)
        -- Original mod: use miamirick_flicker component
        elseif flicker.components.miamirick_flicker then
            if flicker.components.finiteuses then
                local uses = flicker.components.finiteuses:GetUses()
                if uses > 15 then
                    flicker.components.miamirick_flicker:Flicker(self.inst, true)
                end
            end
        end
    end
end

function WagstaffAugments:OnSave()
    return { hand = self.hand_enabled, leg = self.leg_enabled }
end

function WagstaffAugments:OnLoad(data)
    if data then
        if data.hand then self:EnableHand() end
        if data.leg then self:EnableLeg() end
    end
end

return WagstaffAugments