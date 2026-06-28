local assets =
{}

local _G = _G or GLOBAL

local SENTRYROCKET_RADIUS = _G.TUNING.CANNONBALL_RADIUS
-- v2.0.88: Use TUNING.SENTRY_ROCKET_DAMAGE (50) instead of hardcoded 100/4 (25).
-- MK3 rockets should deal meaningful damage; 25 was barely more than a bullet.
local SENTRYROCKET_DAMAGE = _G.TUNING.SENTRY_ROCKET_DAMAGE
local SENTRYROCKET_SPLASH_RADIUS = 3
local SENTRYROCKET_SPLASH_DAMAGE_PERCENT = _G.TUNING.CANNONBALL_SPLASH_DAMAGE_PERCENT -- 60% of SENTRYROCKET_DAMAGE

local MUST_ONE_OF_TAGS = { "_combat", "_health" }
local AREAATTACK_EXCLUDETAGS = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "player", "companion", "wall", "largecreature" }

local function HasFriendlyLeader(inst, target)
    local target_leader = (target.components.follower ~= nil) and target.components.follower.leader or nil
    
    if target_leader ~= nil then

        if target_leader.components.inventoryitem then
            target_leader = target_leader.components.inventoryitem:GetGrandOwner()
        end

        local PVP_enabled = _G.TheNet:GetPVPEnabled()
        return (target_leader ~= nil 
                and (target_leader:HasTag("player") 
                and not PVP_enabled)) or
                (target.components.domesticatable and target.components.domesticatable:IsDomesticated() 
                and not PVP_enabled) or
                (target.components.saltlicker and target.components.saltlicker.salted
                and not PVP_enabled)
    end

    return false
end

local function CanDamage(inst, target)
    if target.components.minigame_participator ~= nil or target.components.combat == nil then
                return false
        end

    if target:HasTag("player") and not _G.TheNet:GetPVPEnabled() then
        return false
    end

    if target:HasTag("playerghost") and not target:HasTag("INLIMBO") then
        return false
    end

    if target:HasTag("monster") and not _G.TheNet:GetPVPEnabled() and 
       ((target.components.follower and target.components.follower.leader ~= nil and 
         target.components.follower.leader:HasTag("player")) or target.bedazzled) then
        return false
    end

    if HasFriendlyLeader(inst, target) then
        return false
    end

    return true
end

local function OnHit(inst, attacker, target)

    -- Do splash damage upon hitting the ground
        inst.components.combat:DoAreaAttack(inst, SENTRYROCKET_SPLASH_RADIUS, nil, nil, nil, AREAATTACK_EXCLUDETAGS)

    -- v2.0.50: REVERTED the v2.0.43 affinity blast FX (bomb_lunarplant). The
    -- user preferred the original sentry missile explosion. Rockets now always
    -- use the default explode_small + impact, regardless of sentry affinity.
    -- The affinity ramp/x2 damage still applies to rocket DAMAGE (in
    -- OnUpdateProjectile); only the visual FX was reverted.

    -- Landed on the ocean
    if inst:IsOnOcean() then
        SpawnPrefab("water_splash_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
    -- Landed on ground
    else
        SpawnPrefab("explode_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
        SpawnPrefab("impact").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end

        if inst.pufftask then
                inst.pufftask:Cancel()
                inst.pufftask = nil
        end

    inst:Remove()
end

local function OnUpdateProjectile(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local targets = _G.TheSim:FindEntities(x, 0, z, SENTRYROCKET_RADIUS, nil, nil, MUST_ONE_OF_TAGS) -- Set y to zero to look for objects on the ground
    for i, target in ipairs(targets) do

    if target ~= nil and target ~= inst.components.complexprojectile.attacker then
                if CanDamage(inst, target) then
            -- Do damage to entities with health
            if target.components.combat then
                -- v2.0.43: Sentry affinity ramp + x2 on rocket direct hits.
                -- The sentry that fired this rocket is the complexprojectile
                -- attacker. Read its affinity state to apply the same ramp
                -- bonus + x2 double-current-total that bullets get.
                local sentry = inst.components.complexprojectile.attacker
                local ramp_bonus = 0
                local aff = nil
                if sentry and sentry.IsValid and sentry:IsValid() and sentry._aff_type then
                    aff = sentry._aff_type
                    -- v2.0.51: adaptive affinity per-target (matches the bullet
                    -- onhitotherfn). Dual-affinity owners get the matching
                    -- affinity for the target's faction.
                    if sentry._owner_celestial and target:HasTag("shadow_aligned") then
                        aff = "celestial"
                    elseif sentry._owner_shadow and target:HasTag("lunar_aligned") then
                        aff = "shadow"
                    end
                    local aligned_tag = (aff == "celestial") and "shadow_aligned" or "lunar_aligned"
                    if target:HasTag(aligned_tag) then
                        -- Bump the sentry's ramp (rockets count as hits too).
                        if sentry.BumpAffRamp then sentry:BumpAffRamp() end
                        -- Calculate ramp bonus on the rocket's base damage.
                        if sentry.GetAffRampBonus then
                            ramp_bonus = sentry:GetAffRampBonus(SENTRYROCKET_DAMAGE)
                        end
                        -- Apply ramp bonus as extra damage.
                        if ramp_bonus > 0 then
                            target.components.combat:GetAttacked(inst, ramp_bonus, nil, "affinity_ramp")
                        end
                    end
                end

                -- Main rocket damage.
                target.components.combat:GetAttacked(inst, SENTRYROCKET_DAMAGE, nil)

                -- x2-Damage (v2.0.61): uses the sentry's cached proc chance
                -- (4% base + 2.5% per MK3 sentry) + 4s per-target cooldown,
                -- same as bullet hits. Shares the cooldown field with bullets.
                if sentry and sentry.IsValid and sentry:IsValid()
                   and sentry._aff_x2_damage then
                    local cd_until = target._william_x2_cd or 0
                    if GetTime() >= cd_until then
                        local chance = sentry._x2_proc_chance or 0.04
                        if math.random() < chance then
                            target.components.combat:GetAttacked(inst, SENTRYROCKET_DAMAGE + ramp_bonus, nil, "x2_damage")
                            target._william_x2_cd = GetTime() + 4.0
                        end
                    end
                end

                                OnHit(inst)-- We don't want rockets to pass through, destroy on impact
                                return  -- v2.0.90 FIX: Stop iterating after OnHit (inst is removed)
            end

            -- Remove and do splash damage if it hits a wall
            if target:HasTag("wall") and target.components.health then
                if not target.components.health:IsDead() then
                    if _G.SENTRY_FF_WALL ~= "noff" then
                                                inst.components.combat:DoAreaAttack(inst, SENTRYROCKET_SPLASH_RADIUS, nil, nil, nil, { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "player", "companion", "largecreature" })
                                                SpawnPrefab("explode_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
                                        end
                    inst:Remove()
                    return
                end
            end
        end
    end

        end
end

local function OnThrown(inst)
    inst.pufftask = inst:DoPeriodicTask(0.1, function(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("dirt_puff")
        fx.Transform:SetScale(.5, .5, .5)
    fx.Transform:SetPosition(x, y+1.35, z)
        fx.persists = false
    end)
end

local function fn(isinventoryitem)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddLight()
        
    if isinventoryitem then
        MakeInventoryPhysics(inst)
    else
        inst.entity:AddPhysics()
        inst.Physics:SetMass(1)
        inst.Physics:SetFriction(0)
        inst.Physics:SetDamping(0)
        inst.Physics:SetRestitution(0)
                inst.Physics:SetCollisionGroup(_G.COLLISION.CHARACTERS)
        inst.Physics:ClearCollisionMask()
        inst.Physics:CollidesWith(_G.COLLISION.GROUND)
        inst.Physics:CollidesWith(_G.COLLISION.OBSTACLES)
                inst.Physics:CollidesWith(_G.COLLISION.GIANTS)
        inst.Physics:SetSphere(SENTRYROCKET_RADIUS)
                inst.Physics:SetCollisionCallback(OnHit)
    end

    inst.Transform:SetTwoFaced()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("projectile")
    inst.AnimState:SetBuild("staff_projectile")
    inst.AnimState:PlayAnimation("fire_spin_loop", true)

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(.5)
    inst.Light:SetRadius(0.5)
    inst.Light:SetColour(237/255, 237/255, 209/255)

        inst:AddComponent("locomotor")
        inst:AddComponent("complexprojectile")
        inst.components.complexprojectile:SetHorizontalSpeed(30)
    inst.components.complexprojectile:SetGravity(-35)
    inst.components.complexprojectile:SetLaunchOffset(Vector3(.25, 1.4, 0))
        inst.components.complexprojectile.usehigharc = false
    inst.components.complexprojectile:SetOnLaunch(OnThrown)
        inst.components.complexprojectile:SetOnHit(OnHit)
        inst.components.complexprojectile:SetOnUpdate(OnUpdateProjectile)
        
        inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(SENTRYROCKET_DAMAGE)
    inst.components.combat:SetAreaDamage(SENTRYROCKET_SPLASH_RADIUS, SENTRYROCKET_SPLASH_DAMAGE_PERCENT)

    inst.persists = false

    return inst
end

return Prefab("esentry_rocket", fn, assets)
