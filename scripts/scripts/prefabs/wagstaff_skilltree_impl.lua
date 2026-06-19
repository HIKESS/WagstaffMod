-- Skill Tree Implementation for Wagstaff Integration Patch
-- Real functional connections between skills and existing craft items

local G = GLOBAL

--==================================================================================
-- GADGETS BRANCH
--==================================================================================

-- Calibrated Wrench (wagstaff_gadgets_1) -> tf2wrench consumes half durability
local function ApplyWrenchSkill(inst)
    if not inst.components.finiteuses then return end
    local old_use = inst.components.finiteuses.Use
    inst.components.finiteuses.Use = function(self, num, ...)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner and owner:HasTag("wagstaff_calibrated_wrench") then
            num = math.max(0, math.floor(num * 0.5))
        end
        return old_use(self, num, ...)
    end
end

-- Stabilized Portals (wagstaff_gadgets_2) -> miamirick_portal_gun costs less fuel
local function ApplyStabilizedPortalsToPortalGun(inst)
    if not inst.components.finiteuses then return end
    local old_use = inst.components.finiteuses.Use
    inst.components.finiteuses.Use = function(self, num, ...)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner and owner:HasTag("wagstaff_stabilized_portals") then
            num = math.max(1, math.floor(num * 0.5))
        end
        return old_use(self, num, ...)
    end
end

-- Efficient Refineries (wagstaff_gadgets_3) -> refinery_* 15% chance to not consume input
local function ApplyEfficientRefinery(inst)
    if inst.components.stewer then
        local old_startcook = inst.components.stewer.StartCooking
        inst.components.stewer.StartCooking = function(self, doer)
            if doer and doer:HasTag("wagstaff_efficient_refineries") and math.random() < 0.30 then
                local items = {}
                for i = 1, 4 do
                    local item = self.inst.components.container:GetItemInSlot(i)
                    if item then table.insert(items, item) end
                end
                local result = old_startcook(self, doer)
                if result and #items > 0 then
                    local refund = items[math.random(#items)]
                    if refund and not refund.components.health then
                        local copy = G.SpawnPrefab(refund.prefab)
                        if copy and doer.components.inventory then
                            doer.components.inventory:GiveItem(copy)
                        end
                    end
                end
                return result
            end
            return old_startcook(self, doer)
        end
    end
end

-- Resupply Protocol (wagstaff_gadgets_5) -> dispenser gives extra item
local function ApplyResupplyProtocol(inst)
    if not inst.components.prototyper then return end
    inst:ListenForEvent("onopen", function(inst, data)
        if not data or not data.doer then return end
        if data.doer:HasTag("wagstaff_resupply_protocol") and math.random() < 0.20 then
            local bonus_items = {"gears", "transistor", "cutstone", "goldnugget", "rocks"}
            local bonus = G.SpawnPrefab(bonus_items[math.random(#bonus_items)])
            if bonus and data.doer.components.inventory then
                data.doer.components.inventory:GiveItem(bonus)
            end
        end
    end)
end

-- Master Engineer (wagstaff_gadgets_6) -> eteleporter costs less sanity
local function ApplyMasterEngineer(inst)
    if inst.components.teleporter then
        local old_activate = inst.components.teleporter.Activate
        inst.components.teleporter.Activate = function(self, doer, ...)
            if doer and doer:HasTag("wagstaff_master_engineer") then
                doer:AddTag("wagstaff_master_engineer_active")
                local result = old_activate(self, doer, ...)
                doer:RemoveTag("wagstaff_master_engineer_active")
                return result
            end
            return old_activate(self, doer, ...)
        end
    end
end

--==================================================================================
-- AUTOMATONS BRANCH
--==================================================================================

-- Optimized Fuel (wagstaff_automatons_1) -> bots consume 10% less fuel
local function ApplyOptimizedFuel(inst)
    if not inst.components.fueled then return end
    local old_takefuel = inst.components.fueled.TakeFuel
    inst.components.fueled.TakeFuel = function(self, item, doer, ...)
        local owner = self.inst.components.follower and self.inst.components.follower.leader
        if owner and owner:HasTag("wagstaff_optimized_fuel") and math.random() < 0.10 then
            return true
        end
        return old_takefuel(self, item, doer, ...)
    end
end

-- Butler Protocols (wagstaff_automatons_2) -> butler bot retreats from hostiles
local function ApplyButlerProtocols(inst)
    if not inst.components.follower then return end
    inst:DoPeriodicTask(2, function()
        local leader = inst.components.follower:GetLeader()
        if not leader or not leader:HasTag("wagstaff_butler_protocols") then return end
        local x, y, z = inst.Transform:GetWorldPosition()
        local hostiles = G.TheSim:FindEntities(x, y, z, 8, {"hostile"}, {"player", "companion", "structure"})
        if #hostiles > 0 and inst.components.locomotor then
            local hx, hy, hz = hostiles[1].Transform:GetWorldPosition()
            local dx, dz = x - hx, z - hz
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist > 0 then
                local run_x = x + (dx/dist) * 8
                local run_z = z + (dz/dist) * 8
                inst.components.locomotor:GoToPoint(G.Vector3(run_x, 0, run_z))
            end
        end
    end)
end

-- Combat Coordination (wagstaff_automatons_3) -> buster bot attacks faster near leader
local function ApplyCombatCoordination(inst)
    if not inst.components.combat then return end
    inst:DoPeriodicTask(1, function()
        local leader = inst.components.follower and inst.components.follower.leader
        if not leader or not leader:HasTag("wagstaff_combat_coordination") then return end
        local dist = inst:GetDistanceSqToInst(leader)
        if dist < 400 then
            inst:AddTag("wagstaff_combat_boost")
            if inst.components.locomotor then
                inst.components.locomotor:SetExternalSpeedMultiplier(inst, "combat_coord", 1.2)
            end
        else
            inst:RemoveTag("wagstaff_combat_boost")
            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "combat_coord")
            end
        end
    end)
end

-- Predictive Maintenance (wagstaff_automatons_5) -> bots warn when fuel < 20%
local function ApplyPredictiveMaintenance(inst)
    if not inst.components.fueled then return end
    inst:DoPeriodicTask(5, function()
        local leader = inst.components.follower and inst.components.follower.leader
        if not leader or not leader:HasTag("wagstaff_predictive_maintenance") then return end
        local pct = inst.components.fueled:GetPercent()
        if pct < 0.20 and pct > 0 then
            if inst.SoundEmitter then
                inst.SoundEmitter:PlaySound("dontstarve/common/together_emote", nil, 0.3)
            end
            local fx = G.SpawnPrefab("collapse_small")
            if fx then
                local x, y, z = inst.Transform:GetWorldPosition()
                fx.Transform:SetPosition(x, y + 1, z)
            end
        end
    end)
end

-- Overclock Protocol (wagstaff_automatons_6) -> bots can be overclocked
local function ApplyOverclockProtocol(inst)
    if not inst.components.follower then return end
    inst.wagstaff_overclock_active = nil
    inst:DoPeriodicTask(1, function()
        local leader = inst.components.follower and inst.components.follower.leader
        if not leader or not leader:HasTag("wagstaff_overclock_protocol") then return end
        if inst.components.combat and inst.components.combat.target and not inst.wagstaff_overclock_active then
            if math.random() < 0.05 then
                inst.wagstaff_overclock_active = true
                if inst.components.locomotor then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "overclock", 1.3)
                end
                inst:DoTaskInTime(30, function()
                    if inst.components.locomotor then
                        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "overclock")
                        inst.components.locomotor:Stop()
                    end
                    inst:DoTaskInTime(5, function()
                        inst.wagstaff_overclock_active = nil
                    end)
                end)
            end
        end
    end)
end

--==================================================================================
-- ALLEGIANCE
--==================================================================================

-- Shadow Engineer: nightmare fuel repairs / +25% damage
local function ApplyShadowAllegianceToItems(inst)
    if inst.components.weapon then
        local old_getdamage = inst.components.weapon.GetDamage
        inst.components.weapon.GetDamage = function(self, attacker, target)
            local base = old_getdamage(self, attacker, target)
            if attacker and attacker:HasTag("wagstaff_shadow_engineer") then
                return base * 1.25
            end
            return base
        end
    end
end

-- Celestial Engineer: 20% less fuel consumption
local function ApplyCelestialAllegianceToItems(inst)
    if inst.components.finiteuses then
        local old_use = inst.components.finiteuses.Use
        inst.components.finiteuses.Use = function(self, num, ...)
            local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
            if owner and owner:HasTag("wagstaff_celestial_engineer") then
                num = math.max(1, math.floor(num * 0.8))
            end
            return old_use(self, num, ...)
        end
    end
end

--==================================================================================
-- EXPORTS
--==================================================================================
return {
    ApplyWrenchSkill = ApplyWrenchSkill,
    ApplyStabilizedPortalsToPortalGun = ApplyStabilizedPortalsToPortalGun,
    ApplyEfficientRefinery = ApplyEfficientRefinery,
    ApplyResupplyProtocol = ApplyResupplyProtocol,
    ApplyMasterEngineer = ApplyMasterEngineer,
    ApplyOptimizedFuel = ApplyOptimizedFuel,
    ApplyButlerProtocols = ApplyButlerProtocols,
    ApplyCombatCoordination = ApplyCombatCoordination,
    ApplyPredictiveMaintenance = ApplyPredictiveMaintenance,
    ApplyOverclockProtocol = ApplyOverclockProtocol,
    ApplyShadowAllegianceToItems = ApplyShadowAllegianceToItems,
    ApplyCelestialAllegianceToItems = ApplyCelestialAllegianceToItems,
}
