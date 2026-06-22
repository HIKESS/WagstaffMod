-- Standalone prefabs for Wagstaff Integration
-- No external mod dependencies - all items defined here

local G = GLOBAL
local CreateEntity = G.CreateEntity
local MakeInventoryPhysics = G.MakeInventoryPhysics
local MakeInventoryFloatable = G.MakeInventoryFloatable
local MakeObstaclePhysics = G.MakeObstaclePhysics
local Prefab = G.Prefab
local RegisterPrefabs = G.RegisterPrefabs
local EQUIPSLOTS = G.EQUIPSLOTS

-- Safe fallbacks: these globals may not exist in GLOBAL table during modimport
local MakeCharacterPhysics = G.MakeCharacterPhysics or function(inst, mass, rad)
    if inst.Physics then
        inst.Physics:SetMass(mass)
        inst.Physics:SetCapsuleRadius(rad)
    end
end
local RemovePhysicsColliders = G.RemovePhysicsColliders or function(inst)
    if inst.Physics then
        inst.Physics:ClearCollisionMask()
    end
end

local function MakePlacerCustom(name, bank, build, anim)
    return Prefab(name, function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        
        inst:AddTag("CLASSIFIED")
        inst:AddTag("NOCLICK")
        inst:AddTag("placer")
        
        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim, true)
        inst.AnimState:SetLightOverride(1)
        
        inst.entity:SetPristine()
        
        inst:AddComponent("placer")
        
        if not G.TheWorld.ismastersim then return inst end

        inst.entity:SetCanSleep(false)
        inst.persists = false
        
        return inst
    end)
end

--==================================================================================
-- HELPER: Basic item template
--==================================================================================
local function MakeBasicItem(name, bank, build, atlas, image, extrasetup, anim)
    local assets = {}
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank(bank or name)
        inst.AnimState:SetBuild(build or name)
        inst.AnimState:PlayAnimation(anim or "idle")
        MakeInventoryFloatable(inst, "med", nil, 0.6)

        inst.entity:SetPristine()
        if not G.TheWorld.ismastersim then return inst end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        local _atlas = atlas or ("images/inventoryimages/" .. name .. ".xml")
        inst.components.inventoryitem.atlasname = _atlas
        inst.components.inventoryitem.imagename = image or name

        if extrasetup then extrasetup(inst) end
        local imgname = (image or name):gsub("%.tex$", "")
        if inst.replica.inventoryitem then
            if inst.replica.inventoryitem.SetAtlas then
                inst.replica.inventoryitem:SetAtlas(_atlas)
            end
            inst.replica.inventoryitem:SetImage(imgname)
        end
        G.MakeHauntableLaunch(inst)
        return inst
    end
    return fn()
end

--==================================================================================
-- MIAMI RICKY ITEMS
--==================================================================================

local portal_gun_assets = {
    G.Asset("ANIM", "anim/portalgun_ground.zip"),
    Asset("ANIM", "anim/swap_portalgun.zip"),
    G.Asset("ANIM", "anim/miamirick_portal.zip"),
    G.Asset("IMAGE", "images/inventoryimages/miamirick_portal_gun.tex"),
    G.Asset("ATLAS", "images/inventoryimages/miamirick_portal_gun.xml"),
}
local aug_assets = {
    G.Asset("ANIM", "anim/miamirick_augs_flicker.zip"),
    G.Asset("IMAGE", "images/inventoryimages/miamirick_hand_on.tex"),
    G.Asset("ATLAS", "images/inventoryimages/miamirick_hand_on.xml"),
    G.Asset("IMAGE", "images/inventoryimages/miamirick_leg_on.tex"),
    G.Asset("ATLAS", "images/inventoryimages/miamirick_leg_on.xml"),
    G.Asset("IMAGE", "images/inventoryimages/miamirick_flicker.tex"),
    G.Asset("ATLAS", "images/inventoryimages/miamirick_flicker.xml"),
}

local function SpawnLinkedPortals(x, z, owner)
    local parent = G.SpawnPrefab("miamirick_portal")
    if not parent then return end
    parent.Transform:SetPosition(x, 0, z)
    parent.owner_rick = owner

    -- Mob spawn: 25% base chance, reduced to 15% with wagstaff_controlled_rifts skill
    local mob_chance = 0.25
    if owner and owner:HasTag("wagstaff_controlled_rifts") then
        mob_chance = 0.15
    end
    if math.random() < mob_chance then
        local mob_types = {"spider", "krampus", "pig"}
        local mob = G.SpawnPrefab(mob_types[math.random(#mob_types)])
        if mob then
            mob.Transform:SetPosition(x, 0, z)
        end
    end

    -- Find destination: prefer nearby telipad when wagstaff_telepad_focus is active
    local dest_x, dest_z = x, z
    local found_dest = false
    if owner and owner:HasTag("wagstaff_telepad_focus") then
        local tx, ty, tz = owner.Transform:GetWorldPosition()
        local telipads = G.TheSim:FindEntities(tx, ty, tz, 300, {"telepad"}, {"burnt"})
        if #telipads > 0 then
            local tp = telipads[math.random(#telipads)]
            local tpx, _, tpz = tp.Transform:GetWorldPosition()
            dest_x = tpx + (math.random() - 0.5) * 3
            dest_z = tpz + (math.random() - 0.5) * 3
            found_dest = true
        end
    end
    if not found_dest then
        local centers = {}
        for _, node in ipairs(G.TheWorld.topology.nodes) do
            if G.TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) then
                table.insert(centers, {x = node.x, z = node.y})
            end
        end
        if #centers > 0 then
            local rpos = centers[math.random(#centers)]
            dest_x, dest_z = rpos.x, rpos.z
        end
    end

    local child = G.SpawnPrefab("miamirick_portal")
    if child then
        child.Transform:SetPosition(dest_x, 0, dest_z)
        child.owner_rick = owner
        parent.portal_link = child
        child.portal_link = parent
        parent.isparent = true
        child.ischild = true
    end
end

-- Portal Gun
local function portal_gun_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("portalgun_ground")
    inst.AnimState:SetBuild("portalgun_ground")
    inst.AnimState:PlayAnimation("idle")
    inst:AddTag("miamirick_portal_gun")
    inst:AddTag("miamirick_items_fueled")
    inst:AddTag("allow_action_on_impassable")
    inst.spelltype = "SCIENCE"

    inst.entity:SetPristine()
    if not G.TheWorld.ismastersim then return inst end

    -- Portal Gun MK.II helper: find closest telipad, avoiding the one player is standing on
    local function FindClosestTelipad(owner, exclude_pad)
        if not G.TheWorld.telipads or #G.TheWorld.telipads == 0 then return nil end
        local best_pad = nil
        local best_dist = math.huge
        for _, pad in ipairs(G.TheWorld.telipads) do
            if pad and pad:IsValid() and pad ~= exclude_pad then
                local dist = owner:GetDistanceSqToInst(pad)
                if dist < best_dist then
                    best_dist = dist
                    best_pad = pad
                end
            end
        end
        return best_pad
    end

    -- Portal Gun MK.II: 2 modes - Random Destination / Telepad Focus
    local function teleport_fn(staff, tar, pos)
        local caster = staff.components.inventoryitem and staff.components.inventoryitem.owner
        if not (caster and caster:IsValid()) then return end
        if staff.components.finiteuses.current <= 0 then
            return
        end

        -- Apply sanity cost based on mode
        local sanity_cost = 0
        if caster and caster.components.sanity then
            if staff._portal_gun_mode == "telepad_focus" then
                sanity_cost = 20  -- Telepad Focus: 20 sanity
            else
                sanity_cost = 5   -- Random Destination: 5 sanity
            end
            caster.components.sanity:DoDelta(-sanity_cost, true)
        end

        -- Summon linked portals
        local tx, ty, tz = caster.Transform:GetWorldPosition()
        SpawnLinkedPortals(tx, tz, caster)
        staff.components.finiteuses:Use(1)
    end

    inst:AddComponent("reticule")
    inst.components.reticule.ease = true

    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(teleport_fn)
    inst.components.spellcaster.quickcast = true
    inst.components.spellcaster.canuseonpoint = true
    inst.components.spellcaster.canuseonpoint_water = false

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(34)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(function(i, owner)
        owner.AnimState:OverrideSymbol("swap_object", "swap_portalgun", "swap_portalgun")
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
        -- Portal Gun MK.II: toggle mode on equip if skill learned
        if owner:HasTag("wagstaff_calculated_escape") then
            if i._portal_gun_mode == "telepad_focus" then
                i._portal_gun_mode = "random_destination"
                if owner.components.talker then
                    owner.components.talker:Say("Mode: Random Destination. (Cost: 5 sanity)")
                end
            else
                i._portal_gun_mode = "telepad_focus"
                if owner.components.talker then
                    owner.components.talker:Say("Mode: Telepad Focus. (Cost: 20 sanity)")
                end
            end
        end
    end)
    inst.components.equippable:SetOnUnequip(function(i, owner)
        owner.AnimState:ClearOverrideSymbol("swap_object")
        owner.AnimState:Hide("ARM_carry")
        owner.AnimState:Show("ARM_normal")
    end)

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/miamirick_portal_gun.xml"
    inst.replica.inventoryitem:SetImage("miamirick_portal_gun")

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(5)
    inst.components.finiteuses:SetUses(5)

    inst:AddComponent("miamirick_recharge")

    G.MakeHauntableLaunch(inst)
    return inst
end

-- Hand Augment + Leg Augment (shared factory, inventory items activated via machine toggle)
local function make_aug_fn(typeof)
    return function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("miamirick_augs_flicker")
        inst.AnimState:SetBuild("miamirick_augs_flicker")
        inst.AnimState:PlayAnimation(typeof)  -- "hand" or "leg"

        inst:AddTag("miamirick_" .. typeof)
        inst:AddTag("miamirick_items_fueled")

        local scale = 1.6
        inst.Transform:SetScale(scale, scale, scale)

        inst.entity:SetPristine()
        if not G.TheWorld.ismastersim then return inst end

        local function turnon(i)
            i:DoTaskInTime(0.1, function()
                local owner = i.components.inventoryitem and i.components.inventoryitem.owner
                if not owner then return end
                -- Block activation from backpack
                if owner.components.container then
                    local grandowner = i.components.inventoryitem:GetGrandOwner()
                    if grandowner and grandowner.components.talker then
                        grandowner.components.talker:Say("It won't work from the backpack!")
                    end
                    i.components.machine.ison = false
                    return
                end
                if i.components.finiteuses.current <= 10 then
                    if owner.components.talker then owner.components.talker:Say("It is discharged.") end
                    i.components.machine.ison = false
                    return
                end
                -- Apply effect via wagstaff_augments
                if owner.components.wagstaff_augments then
                    if typeof == "hand" then
                        owner.components.wagstaff_augments:EnableHand()
                        if owner.components.talker then owner.components.talker:Say("Hand augment: On.") end
                    else
                        owner.components.wagstaff_augments:EnableLeg()
                        if owner.components.talker then owner.components.talker:Say("Leg augment: On.") end
                    end
                end
                i.rick_owner = owner
                local x, y, z = owner.Transform:GetWorldPosition()
                local sparks = G.SpawnPrefab("sparks")
                if sparks then sparks.Transform:SetPosition(x, y + 0.25 + math.random() * 2, z) end
                i.components.finiteuses:Use(5)
            end)
        end

        local function turnoff(i)
            i:DoTaskInTime(0.1, function()
                local owner = i.components.inventoryitem and i.components.inventoryitem.owner or i.rick_owner
                if not owner then return end
                if owner.components.wagstaff_augments then
                    if typeof == "hand" then
                        owner.components.wagstaff_augments:DisableHand()
                        if owner.components.talker then owner.components.talker:Say("Hand augment: Off.") end
                    else
                        owner.components.wagstaff_augments:DisableLeg()
                        if owner.components.talker then owner.components.talker:Say("Leg augment: Off.") end
                    end
                end
            end)
        end

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetMaxUses(200)
        inst.components.finiteuses:SetUses(200)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(0)

        inst:AddComponent("inspectable")
        -- Show fuel percentage on inspect
        inst:DoPeriodicTask(1, function()
            if inst.components.finiteuses and inst.components.inspectable then
                local pct = math.floor(inst.components.finiteuses:GetPercent() * 100)
                inst.components.inspectable:SetDescription("Fuel: " .. tostring(pct) .. "%")
            end
        end)

        inst:AddComponent("inventoryitem")
        if typeof == "leg" then
            inst.replica.inventoryitem:SetImage("miamirick_leg_on")
            inst.components.inventoryitem.atlasname = "images/inventoryimages/miamirick_leg_on.xml"
        else
            inst.replica.inventoryitem:SetImage("miamirick_hand_on")
            inst.components.inventoryitem.atlasname = "images/inventoryimages/miamirick_hand_on.xml"
        end

        inst:AddComponent("machine")
        inst.components.machine.turnonfn = turnon
        inst.components.machine.turnofffn = turnoff
        inst.components.machine.cooldowntime = 0

        -- Disable when moved to backpack or dropped
        inst:ListenForEvent("onputininventory", function(i)
            local container1 = i.components.inventoryitem and i.components.inventoryitem.owner
            if container1 and container1.components.container then
                turnoff(i)
                i.components.machine.ison = false
            end
        end)
        inst:ListenForEvent("ondropped", function(i)
            turnoff(i)
        end)

        -- Drain fuel every 5s while on
        inst:DoPeriodicTask(5, function()
            if inst.components.machine.ison then
                local owner = inst.rick_owner or (inst.components.inventoryitem and inst.components.inventoryitem.owner)
                local drain = 1
                if inst.components.finiteuses.current < drain then
                    turnoff(inst)
                    inst.components.machine.ison = false
                else
                    inst.components.finiteuses:Use(drain)
                end
            end
        end)

        G.MakeHauntableLaunch(inst)
        return inst
    end
end

local hand_fn = make_aug_fn("hand")
local leg_fn = make_aug_fn("leg")

-- Flicker (inventory item, no equippable)
local FLICKER_DIST = 12
local DEGREES = math.pi / 180

local function flicker_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("miamirick_augs_flicker")
    inst.AnimState:SetBuild("miamirick_augs_flicker")
    inst.AnimState:PlayAnimation("flicker")

    inst:AddTag("miamirick_flicker")
    inst:AddTag("miamirick_items_fueled")

    local scale = 1.6
    inst.Transform:SetScale(scale, scale, scale)

    inst.entity:SetPristine()
    if not G.TheWorld.ismastersim then return inst end

    -- Forward teleport (directional) - 20% charge (40 uses out of 200 max)
    local function DoFlicker(owner)
        if not (inst.components.finiteuses and inst.components.finiteuses.current >= 40) then
            if owner.components.talker then owner.components.talker:Say("It is discharged.") end
            return
        end
        -- Sanity cost like Lazy Explorer (15 per use)
        if owner.components.sanity then
            owner.components.sanity:DoDelta(-15, true)
        end
        local x, y, z = owner.Transform:GetWorldPosition()
        -- Calculate heading: DST uses clockwise rotation where 0 = north
        -- Subtracting 90 aligns with world coordinates (east = +x, south = -z)
        local heading = (owner.Transform:GetRotation() - 90) * DEGREES
        local dir_x = math.cos(heading)
        local dir_z = math.sin(heading)
        local end_x = x + FLICKER_DIST * dir_x
        local end_z = z + FLICKER_DIST * dir_z
        if G.TheWorld.Map:IsPassableAtPoint(end_x, 0, end_z)
            and not G.TheWorld.Map:IsPointNearHole({x=end_x, y=0, z=end_z}) then
            local fx1 = G.SpawnPrefab("shadow_despawn")
            if fx1 then fx1.Transform:SetPosition(x, 0, z) end
            owner.Physics:Teleport(end_x, 0, end_z)
            local fx2 = G.SpawnPrefab("shadow_despawn")
            if fx2 then fx2.Transform:SetPosition(end_x, 0, end_z) end
            inst.components.finiteuses:Use(40)
        elseif owner.components.talker then
            owner.components.talker:Say("Can't teleport there.")
        end
    end

    -- Random short-distance teleport (for Flicker MK.II skill) - 10% charge (20 uses out of 200 max)
    local function DoRandomFlicker(owner)
        if not (inst.components.finiteuses and inst.components.finiteuses.current >= 20) then
            if owner.components.talker then owner.components.talker:Say("It is discharged.") end
            return
        end
        -- Sanity cost like Lazy Explorer (15 per use)
        if owner.components.sanity then
            owner.components.sanity:DoDelta(-15, true)
        end
        local x, y, z = owner.Transform:GetWorldPosition()
        local attempts = 0
        local end_x, end_z
        repeat
            local angle = math.random() * 2 * math.pi
            local dist = 1 + math.random() * 15
            end_x = x + math.cos(angle) * dist
            end_z = z + math.sin(angle) * dist
            attempts = attempts + 1
        until (G.TheWorld.Map:IsPassableAtPoint(end_x, 0, end_z)
            and not G.TheWorld.Map:IsPointNearHole({x=end_x, y=0, z=end_z})
            and not G.TheWorld.Map:IsOceanAtPoint(end_x, 0, end_z))
            or attempts > 20
        if attempts <= 20 then
            local fx1 = G.SpawnPrefab("shadow_despawn")
            if fx1 then fx1.Transform:SetPosition(x, 0, z) end
            owner.Physics:Teleport(end_x, 0, end_z)
            local fx2 = G.SpawnPrefab("shadow_despawn")
            if fx2 then fx2.Transform:SetPosition(end_x, 0, end_z) end
            inst.components.finiteuses:Use(20)
            if inst.SoundEmitter then
                inst.SoundEmitter:PlaySound("dontstarve/common/teleportworm/teleportworm_exit")
            end
        elseif owner.components.talker then
            owner.components.talker:Say("Can't find a safe spot.")
        end
    end

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(0)

    inst:AddComponent("inspectable")
    -- Show fuel percentage on inspect
    inst:DoPeriodicTask(1, function()
        if inst.components.finiteuses and inst.components.inspectable then
            local pct = math.floor(inst.components.finiteuses:GetPercent() * 100)
            inst.components.inspectable:SetDescription("Fuel: " .. tostring(pct) .. "%")
        end
    end)

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/miamirick_flicker.xml"
    inst.replica.inventoryitem:SetImage("miamirick_flicker")

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(200)
    inst.components.finiteuses:SetUses(200)

    -- Expose DoFlicker for the WAGSTAFF_FLICKERTELEPORT action
    inst.DoFlicker = DoFlicker
    inst.DoRandomFlicker = DoRandomFlicker

    G.MakeHauntableLaunch(inst)
    return inst
end

-- Blue stabilized portal accepts these refill items (prefab -> seconds added)
local PORTAL_REFILL = {
    lightbulb     = 30,
    nightmarefuel = 60,
    glommerfuel   = 90,
    redgem        = 30,
    bluegem       = 60,
    purplegem     = 120,
    transistor    = 120,
    gears         = 180,
}

local function StabilizePortal(inst)
    if inst.stabilized then return end
    inst.stabilized = true
    inst.perish_time = math.max(inst.perish_time or 0, 120)
    -- visual: green -> blue tint
    inst.AnimState:SetMultColour(0.35, 0.55, 1.0, 1)
    -- effect
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = G.SpawnPrefab("statue_transition")
    if fx then fx.Transform:SetPosition(x, y, z) end
    if inst.SoundEmitter then
        inst.SoundEmitter:PlaySound("dontstarve/common/lavaarena_warpgate/portal_idle_LP", "portal_lp")
    end
end

local function ExtendPortal(inst, seconds)
    inst.perish_time = (inst.perish_time or 0) + seconds
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = G.SpawnPrefab("collapse_small")
    if fx then fx.Transform:SetPosition(x, y, z) end
end

-- Standalone miamirick_portal (walkable portal created by portal gun)
local function DestroyPortal(inst)
    inst.perish_time = 100
    inst.persists = false
    inst:AddTag("PortalFadeOut")
    local a = 1
    inst:DoPeriodicTask(0.1, function()
        a = a - 0.05
        inst.AnimState:SetMultColour(a, a, a, a)
        if a <= 0 then
            inst:Remove()
        end
    end)
    inst:DoTaskInTime(1.25, function()
        inst.portal_link = nil
    end)
    inst:DoTaskInTime(1.9, function()
        inst.AnimState:ClearBloomEffectHandle()
        inst.AnimState:SetBloomEffectHandle("")
    end)
end

local function OnActivate(inst, player)
    if inst.portal_link and inst.portal_link:IsValid() then
        local x, y, z = inst.portal_link.Transform:GetWorldPosition()
        local is_ground = G.TheWorld.Map:IsVisualGroundAtPoint(x, 0, z)
        local platform = G.TheWorld.Map:GetPlatformAtPoint(x, 0, z)
        local valid_ground = is_ground or platform
        if valid_ground then
            local fx = G.SpawnPrefab("collapse_big")
            if fx then fx.Transform:SetPosition(player.Transform:GetWorldPosition()) end
            player.Physics:Teleport(x, 0, z)
            local fx2 = G.SpawnPrefab("collapse_big")
            if fx2 then fx2.Transform:SetPosition(x, 0, z) end
            inst.components.activatable.inactive = true
        else
            if player and player.components.talker then
                player.components.talker:Say("Something is off.")
            end
        end
    end
end

local function onget_special_item(inst, item)
    local add_time = 0
    if item.components.des_portal_gun_fuel then
        add_time = item.components.des_portal_gun_fuel.portal_durable * 15 * 2
    end
    local times = inst.perish_time
    local newtime = add_time + times

    if inst.type == "_durable" then
        inst.perish_time = newtime
        if inst.portal_link and inst.portal_link.perish_time < inst.perish_time then
            inst.portal_link.perish_time = inst.perish_time
        end
    elseif inst.type == "" and item:HasTag("miamirick_portal_delaet_dolgim") then
        -- making portal durable
        local link_for_inst = inst.portal_link
        local owner_rick = inst.owner_rick
        local par_pos_x, par_pos_y, par_pos_z = inst.Transform:GetWorldPosition()
        local chi_pos_x, chi_pos_y, chi_pos_z = inst.portal_link.Transform:GetWorldPosition()

        if inst.isparent and inst.isparent == true then
            local portal = G.SpawnPrefab("miamirick_portal_durable")
            portal.owner_rick = inst.owner_rick
            portal.Transform:SetPosition(par_pos_x, 0, par_pos_z)

            local portal_child = G.SpawnPrefab("miamirick_portal_durable")
            portal_child.owner_rick = inst.owner_rick
            portal_child.Transform:SetPosition(chi_pos_x, 0, chi_pos_z)

            portal_child.portal_link = portal
            portal.portal_link = portal_child

            DestroyPortal(inst.portal_link)
            DestroyPortal(inst)
        else
            inst.portal_link.isparent = true
            onget_special_item(inst.portal_link, item)
        end
    end
end

local function OnGetItemFromPlayer(inst, giver, item)
    onget_special_item(inst, item)
end

local function AcceptTest(inst, item)
    if inst:HasTag("PortalFadeOut") then return false end
    if inst.type == "" then
        return item.prefab == "transistor"
    elseif inst.type == "_durable" then
        return item.components.des_portal_gun_fuel ~= nil and item.components.des_portal_gun_fuel.portal_durable > 0
    end
    return false
end

local function OnRefuseItem(inst, giver, item)
    if giver and giver.components.talker then
        giver.components.talker:Say("I think not.")
    end
end

local function buildportal(type)
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()
        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        inst.AnimState:SetBank("miamirick_portal")
        inst.AnimState:SetBuild("miamirick_portal")
        if type == "_durable" then
            inst.AnimState:SetBank("miamirick_portal_blue")
            inst.AnimState:SetBuild("miamirick_portal_blue")
        end
        inst.AnimState:PlayAnimation("birth")
        inst.AnimState:PushAnimation("idle", true)
        inst.entity:AddLabel()
        inst.Label:SetFont(G.BODYTEXTFONT)
        inst.Label:SetFontSize(20)
        inst.Label:SetWorldOffset(0, 3.2, 0)
        if type == "_durable" then
            inst.Label:SetColour(0.4, 0.85, 1, 1)
        else
            inst.Label:SetColour(0.4, 1, 0.4, 1)
        end
        inst.Label:SetText("")
        local s = 1.75
        inst.Transform:SetScale(s, s, s)
        inst:AddTag("miamirick_portal_tag")
        inst.entity:SetPristine()
        if not G.TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("activatable")
        inst.components.activatable.OnActivate = OnActivate
        inst.components.activatable.inactive = true
        inst.components.activatable.quickaction = true
        inst.perish_time = (type == "_durable") and 120 or 16
        inst.type = type
        inst:AddComponent("trader")
        inst:AddTag("trader")
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGetItemFromPlayer
        inst.components.trader.onrefuse = OnRefuseItem
        inst.components.trader:Enable()
        local function UpdatePortalLabel()
            local remaining = math.max(0, inst.perish_time)
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            if mins > 0 then
                inst.Label:SetText(string.format("%d:%02d", mins, secs))
            else
                inst.Label:SetText(tostring(secs) .. "s")
            end
        end
        UpdatePortalLabel()
        inst:DoPeriodicTask(1, function()
            inst.perish_time = inst.perish_time - 1
            UpdatePortalLabel()
            local remaining = math.max(0, inst.perish_time)
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            if mins > 0 then
                inst.components.inspectable:SetDescription(string.format("Perishes in %d min %02d sec.", mins, secs))
            else
                inst.components.inspectable:SetDescription("Perishes in " .. remaining .. " seconds.")
            end
            if inst.perish_time <= 0 then
                inst.Label:SetText("")
                if inst.portal_link then
                    DestroyPortal(inst.portal_link)
                end
                DestroyPortal(inst)
            end
        end)
        inst:AddComponent("des_portal_data")
        inst.owner_rick = nil
        return inst
    end
    return Prefab("miamirick_portal" .. type, fn, {G.Asset("ANIM", "anim/miamirick_portal.zip"), G.Asset("ANIM", "anim/miamirick_portal_blue.zip")})
end


--==================================================================================
-- ENGINEER ITEMS (TF2)
--==================================================================================

-- Scrap Metal
local function scrap_fn()
    local inst = MakeBasicItem("scrap", "tf2scrap", "tf2scrap",
        "images/engineeritemimages.xml", "scrap.tex",
        function(inst)
            inst:AddComponent("stackable")
            inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
            inst:AddTag("molebait")
            inst:AddComponent("bait")
        end)
    return inst
end

-- TF2 Wrench
local function wrench_fn()
    local inst = MakeBasicItem("tf2wrench", "tf2wrench", "tf2wrench",
        "images/engineeritemimages.xml", "tf2wrench.tex",
        function(inst)
            inst:AddTag("hammer")
            inst:AddComponent("weapon")
            inst.components.weapon:SetDamage(59.5)
            inst:AddComponent("tool")
            inst:AddComponent("equippable")
            inst.components.equippable:SetOnEquip(function(i, owner)
                owner.AnimState:OverrideSymbol("swap_object", "swap_tf2wrench", "tf2wrench")
                owner.AnimState:Show("ARM_carry")
                owner.AnimState:Hide("ARM_normal")
            end)
            inst.components.equippable:SetOnUnequip(function(i, owner)
                owner.AnimState:Hide("ARM_carry")
                owner.AnimState:Show("ARM_normal")
            end)
            inst:AddComponent("finiteuses")
            inst.components.finiteuses:SetMaxUses(50)
            inst.components.finiteuses:SetUses(50)
            inst.components.finiteuses:SetOnFinished(inst.Remove)
        end)
    return inst
end

-- Hard Hat
local function hardhat_fn()
    local inst = MakeBasicItem("ehardhat", "ehardhat", "ehardhat",
        "images/engineeritemimages.xml", "ehardhat.tex",
        function(inst)
            inst:AddTag("hat")
            inst:AddComponent("equippable")
            inst.components.equippable.equipslot = G.EQUIPSLOTS.HEAD
            inst.components.equippable:SetOnEquip(function(i, owner)
                if owner.prefab == "engineer" then
                    owner.AnimState:OverrideSymbol("swap_hat", "ehardhat_swap", "swap_hat")
                elseif owner.prefab == "wagstaff" then
                    owner.AnimState:OverrideSymbol("swap_hat", "ehardhat_swap", "swap_hat")
                    owner:AddTag("engie_pardner")
                else
                    owner.AnimState:OverrideSymbol("swap_hat", "ehardhat_large_swap", "swap_hat")
                    owner:AddTag("engie_pardner")
                end
                owner.AnimState:Show("HAT")
                owner.AnimState:Show("HAIR_HAT")
                owner.AnimState:Hide("HAIR_NOHAT")
                owner.AnimState:Hide("HAIR")
                if owner:HasTag("player") then
                    owner.AnimState:Hide("HEAD")
                    owner.AnimState:Show("HEAD_HAT")
                    owner.AnimState:Show("HEAD_HAT_NOHELM")
                    owner.AnimState:Hide("HEAD_HAT_HELM")
                end
            end)
            inst.components.equippable:SetOnUnequip(function(i, owner)
                owner.AnimState:ClearOverrideSymbol("swap_hat")
                owner.AnimState:Hide("HAT")
                owner.AnimState:Hide("HAIR_HAT")
                owner.AnimState:Show("HAIR_NOHAT")
                owner.AnimState:Show("HAIR")
                owner:RemoveTag("engie_pardner")
                if owner:HasTag("player") then
                    owner.AnimState:Show("HEAD")
                    owner.AnimState:Hide("HEAD_HAT")
                    owner.AnimState:Hide("HEAD_HAT_NOHELM")
                    owner.AnimState:Hide("HEAD_HAT_HELM")
                end
            end)
            inst:AddComponent("armor")
            inst.components.armor:InitCondition(G.TUNING.ARMOR_EHARDHAT or 295, G.TUNING.ARMOR_HARDHAT_ABSORPTION or 0.7)
            inst:AddComponent("waterproofer")
            inst.components.waterproofer:SetEffectiveness(G.TUNING.WATERPROOFNESS_SMALL)
        end)
    return inst
end

-- Gibus Hat
local function gibus_fn()
    local inst = MakeBasicItem("gibus", "gibus", "gibus",
        "images/engineeritemimages.xml", "gibus.tex",
        function(inst)
            inst:AddTag("hat")
            inst:AddComponent("equippable")
            inst.components.equippable.equipslot = G.EQUIPSLOTS.HEAD
            inst.components.equippable.dapperness = G.TUNING.DAPPERNESS_SMALL
            inst.components.equippable:SetOnEquip(function(i, owner)
                owner.AnimState:OverrideSymbol("swap_hat", "gibus_swap", "swap_hat")
                owner.AnimState:Show("HAT")
                owner.AnimState:Show("HAIR_HAT")
                owner.AnimState:Hide("HAIR_NOHAT")
                owner.AnimState:Hide("HAIR")
                if owner:HasTag("player") then
                    owner.AnimState:Hide("HEAD")
                    owner.AnimState:Show("HEAD_HAT")
                    owner.AnimState:Show("HEAD_HAT_NOHELM")
                    owner.AnimState:Hide("HEAD_HAT_HELM")
                end
                if i.components.fueled then i.components.fueled:StartConsuming() end
            end)
            inst.components.equippable:SetOnUnequip(function(i, owner)
                owner.AnimState:ClearOverrideSymbol("swap_hat")
                owner.AnimState:Hide("HAT")
                owner.AnimState:Hide("HAIR_HAT")
                owner.AnimState:Show("HAIR_NOHAT")
                owner.AnimState:Show("HAIR")
                if owner:HasTag("player") then
                    owner.AnimState:Show("HEAD")
                    owner.AnimState:Hide("HEAD_HAT")
                    owner.AnimState:Hide("HEAD_HAT_NOHELM")
                    owner.AnimState:Hide("HEAD_HAT_HELM")
                end
                if i.components.fueled then i.components.fueled:StopConsuming() end
            end)
            inst:AddComponent("armor")
            inst.components.armor:InitCondition(G.TUNING.ARMOR_BEEHAT or 100, G.TUNING.ARMOR_BEEHAT_ABSORPTION or 0.5)
            inst.components.armor:SetTags({"ghost"})
            inst:AddComponent("fueled")
            inst.components.fueled.fueltype = G.FUELTYPE.USAGE
            inst.components.fueled:InitializeFuelLevel(G.TUNING.EARMUFF_PERISHTIME)
            inst.components.fueled:SetDepletedFn(inst.Remove)
        end)
    return inst
end

-- Destruction PDA
local function pda_fn()
    local inst = MakeBasicItem("destructionpda", "destructionpda", "destructionpda",
        "images/engineeritemimages.xml", "destructionpda.tex",
        function(inst)
            inst:AddTag("engiepda")
            inst:AddComponent("equippable")
            inst.components.equippable:SetOnEquip(function(i, owner)
                owner:AddTag("engiepdaowner")
            end)
            inst.components.equippable:SetOnUnequip(function(i, owner)
                owner:RemoveTag("engiepdaowner")
            end)
        end)
    return inst
end

--==================================================================================
-- ENGINEER BUILDINGS (single-entity)
--==================================================================================

local ENGIE_ASSETS = {
    Asset("ANIM", "anim/esentry.zip"),
    Asset("ANIM", "anim/esentry_item.zip"),
    Asset("ANIM", "anim/dispenser.zip"),
    Asset("ANIM", "anim/dispenser_meter.zip"),
    Asset("ANIM", "anim/eteleporter.zip"),
    Asset("ANIM", "anim/swap_engie_building.zip"),
}

-- Shared equip/unequip for all engineer buildings
local function OnEngieBuildingEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "swap_engie_building", "swap_body")
end
local function OnEngieBuildingUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
end

--==================================================================================
-- REFINERY WORLD STRUCTURES
--==================================================================================

local function MakeRefineryWorld(bank, input_prefab, output_prefab, drop_prefab, input_amount)
    return function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()
        MakeObstaclePhysics(inst, .4)
        inst.entity:AddMiniMapEntity()

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(bank)
        inst.AnimState:PlayAnimation("idle_off", true)
        inst:AddTag("structure")

        inst.entity:SetPristine()
        if not G.TheWorld.ismastersim then return inst end

        inst:AddTag("refinery_building")

        inst:AddComponent("lootdropper")
        inst.components.lootdropper:AddRandomLoot(drop_prefab or bank, 1)

        inst:AddComponent("inspectable")

        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(300)
        inst.components.health.nofadeout = true
        inst:ListenForEvent("death", function(i)
            i.components.lootdropper:DropLoot()
            G.SpawnPrefab("collapse_small").Transform:SetPosition(i.Transform:GetWorldPosition())
            i:Remove()
        end)

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(G.ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(function(i, worker)
            i.components.lootdropper:DropLoot()
            G.SpawnPrefab("collapse_small").Transform:SetPosition(i.Transform:GetWorldPosition())
            i:Remove()
        end)

        -- Internal buffer: stores received items
        inst._stored = 0

        -- Trader: accepts input_prefab, stores count in buffer
        inst:AddComponent("trader")
        inst.components.trader:SetAcceptTest(function(i, item)
            return item.prefab == input_prefab
        end)
        inst.components.trader:SetOnAccept(function(i, giver, item)
            local sz = (item.components.stackable and item.components.stackable:StackSize()) or 1
            i._stored = i._stored + sz
            i.AnimState:PlayAnimation("turn_on")
            i.AnimState:PushAnimation("idle_on", true)
            i.SoundEmitter:PlaySound("dontstarve/common/researchmachine_place")
        end)
        inst.components.trader.acceptsstacks = true

        local needed = input_amount or 2
        inst:DoPeriodicTask(5, function(i)
            if not i:IsValid() or i._stored < needed then return end
            i._stored = i._stored - needed

            local x, y, z = i.Transform:GetWorldPosition()
            local out_count = 1
            local nearby = GLOBAL.TheSim:FindEntities(x, y, z, 20, {"player"}, {"playerghost"})
            for _, p in ipairs(nearby) do
                if p:HasTag("wagstaff_efficient_refineries") then out_count = 2; break end
            end

            for n = 1, out_count do
                local out = G.SpawnPrefab(output_prefab)
                if out then
                    out.Transform:SetPosition(x + math.random(-1,1)*0.5, 2, z + math.random(-1,1)*0.5)
                    if out.Physics then out.Physics:SetVel(0, 4 + math.random()*2, 0) end
                end
            end

            i.AnimState:PlayAnimation("use")
            i:DoTaskInTime(1.5, function(ii)
                if ii:IsValid() then
                    local anim = ii._stored > 0 and "idle_on" or "idle_off"
                    ii.AnimState:PlayAnimation(anim, true)
                end
            end)
            i.SoundEmitter:PlaySound("dontstarve/common/meat_rack_craft")
        end)

        inst:ListenForEvent("onbuilt", function(i)
            i.AnimState:PlayAnimation("place")
            i.AnimState:PushAnimation("idle_off", true)
            i.SoundEmitter:PlaySound("dontstarve/common/researchmachine_place")
        end)

        return inst
    end
end

local refinery_boards_fn   = MakeRefineryWorld("refinery_boards",   "log",      "boards",   "refinery_boards",   3)
local refinery_papyrus_fn  = MakeRefineryWorld("refinery_papyrus",  "cutreeds", "papyrus",  "refinery_papyrus",  3)
local refinery_rope_fn     = MakeRefineryWorld("refinery_rope",     "cutgrass", "rope",     "refinery_rope",     2)
local refinery_cutstone_fn = MakeRefineryWorld("refinery_cutstone", "rocks",    "cutstone", "refinery_cutstone", 2)

--==================================================================================
-- WILLIAM TOYMAKER ITEMS
--==================================================================================

local function gadget_fn()
    local inst = MakeBasicItem("williamgadget", "william_gadget", "william_gadget",
        "images/inventoryimages/williamgadget.xml", "williamgadget.tex",
        function(inst)
            inst:AddComponent("stackable")
            inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
        end)
    return inst
end

local function butler_fn()
    local inst = MakeBasicItem("williambutler_builder", "BUILD_PLAYER", "william_butler",
        "images/inventoryimages/williambutler_builder.xml", "williambutler_builder.tex",
        nil, "idle")
    return inst
end

local function buster_fn()
    local inst = MakeBasicItem("williambuster_builder", "william_buster", "william_buster",
        "images/inventoryimages/williambuster_builder.xml", "williambuster_builder.tex",
        nil, "idle_loop")
    return inst
end

local function brute_fn()
    local inst = MakeBasicItem("williambrute_builder", "william_brute", "william_brute",
        "images/inventoryimages/williambrute_builder.xml", "williambrute_builder.tex",
        nil, "idle")
    return inst
end

local function ballistic_fn()
    local inst = MakeBasicItem("williamballistic_empty", "william_ballistic", "william_ballistic",
        "images/inventoryimages/williamballistic_empty.xml", "williamballistic_empty.tex")
    return inst
end

--==================================================================================
-- ROBERT WAGSTAFF ITEMS
--==================================================================================

local function flail_onattack(inst, attacker, target)
    if target ~= nil and target:IsValid() and attacker ~= nil and attacker:IsValid() then
        G.SpawnPrefab("electrichitsparks"):AlignToTarget(target, attacker, true)
        if target.SoundEmitter ~= nil then
            target.SoundEmitter:PlaySound("dontstarve/common/whip_small")
        end
    end
end

local function flail_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    G.MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("teslaflail_ground")
    inst.AnimState:SetBuild("teslaflail_ground")
    inst.AnimState:PlayAnimation("idle")
    inst:AddTag("teslaflail")
    inst:AddTag("weapon")
    inst:AddTag("whip")
    G.MakeInventoryFloatable(inst, "med", nil, 0.9)
    inst.entity:SetPristine()
    if not G.TheWorld.ismastersim then return inst end
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(28)
    inst.components.weapon:SetRange(G.TUNING.WHIP_RANGE)
    inst.components.weapon:SetOnAttack(flail_onattack)
    inst.components.weapon:SetElectric()
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(100)
    inst.components.finiteuses:SetUses(100)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "teslaflail"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/teslaflail.xml"
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(function(i, owner)
        owner.AnimState:OverrideSymbol("swap_object", "new_teslaflailtest", "swap_object")
        owner.AnimState:OverrideSymbol("whipline", "swap_whip", "whipline")
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
    end)
    inst.components.equippable:SetOnUnequip(function(i, owner)
        owner.AnimState:ClearOverrideSymbol("whipline")
        owner.AnimState:Hide("ARM_carry")
        owner.AnimState:Show("ARM_normal")
    end)
    G.MakeHauntableLaunch(inst)
    return inst
end

local function compassvest_fn()
    local inst = MakeBasicItem("compassvest", "compassvest", "compassvest",
        "images/inventoryimages/compassvest.xml", "compassvest.tex",
        function(inst)
            inst:AddComponent("equippable")
            inst.components.equippable.equipslot = EQUIPSLOTS.BODY
            inst.components.equippable:SetOnEquip(function(i, owner)
                owner.AnimState:OverrideSymbol("body", "compassvest", "swap_body")
            end)
            inst.components.equippable:SetOnUnequip(function(i, owner)
                owner.AnimState:ClearOverrideSymbol("body")
            end)
            inst:AddComponent("armor")
            local wood_cond = TUNING.ARMOR_WOOD or 450
            local wood_abs  = TUNING.ARMOR_WOOD_ABSORPTION or 0.8
            inst.components.armor:InitCondition(wood_cond * 0.6, wood_abs * 0.6)
        end)
    return inst
end

--==================================================================================
-- EVIL PORTAL
--==================================================================================

local EVIL_PORTAL_MOB_GROUPS = {
    {2, 1, "spider", "spider_warrior", "spider_warrior", "spider_spitter"},
    {2, 1, "hound", "hound", "firehound", "firehound"},
    {1, 2, "ghost", "ghost", "ghost", "ghost"},
    {2, 2, "bat", "bat", "bat", "bat"},
    {1, 1, "slurper", "slurper", "slurper", "slurper"},
    {2, 1, "monkey", "monkey", "monkey", "monkey"},
    {2, 2, "mosquito", "mosquito", "killerbee", "killerbee"},
    {2, 1, "frog", "frog", "frog", "frog"},
    {2, 2, "rabbit", "rabbit", "rabbit", "rabbit"},
    {1, 1, "crow", "crow", "crow", "crow"},
}

local function SpawnMob(portal, prefabname, count)
    if count < 1 then return end
    for i = 1, count do
        local mob = G.SpawnPrefab(prefabname)
        if mob then
            local x, y, z = portal.Transform:GetWorldPosition()
            mob.Transform:SetPosition(x + (math.random() - 0.5) * 4, 0, z + (math.random() - 0.5) * 4)
            local fx = G.SpawnPrefab("electrichitsparks")
            if fx then
                fx.Transform:SetPosition(mob.Transform:GetWorldPosition())
            end
        end
    end
end

local function evil_portal_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetPristine()
    if not G.TheWorld.ismastersim then return inst end
    inst.persists = false
    inst.entity:AddLight()
    inst.Light:SetRadius(2)
    inst.Light:SetFalloff(0.9)
    inst.Light:SetIntensity(0.3)
    inst.Light:SetColour(100/255, 150/255, 100/255)
    inst.Light:Enable(true)
    local fx = G.SpawnPrefab("electrichitsparks")
    if fx then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    local group = EVIL_PORTAL_MOB_GROUPS[math.random(#EVIL_PORTAL_MOB_GROUPS)]
    local max_easy = group[1]
    local max_hard = group[2]
    local mob1, mob2, mob3, mob4 = group[3], group[4], group[5], group[6]
    local mob1_count = math.max(1, math.floor(math.random(0, max_easy)))
    local mob2_count = math.max(1, math.floor(math.random(0, max_easy)))
    local mob3_count = math.max(1, math.floor(math.random(0, max_hard)))
    local mob4_count = math.max(1, math.floor(math.random(0, max_hard)))
    inst:DoTaskInTime(1 + math.random(), function()
        SpawnMob(inst, mob1, mob1_count)
    end)
    inst:DoTaskInTime(4 + 2 * math.random(), function()
        SpawnMob(inst, mob2, mob2_count)
    end)
    inst:DoTaskInTime(6 + 3 * math.random(), function()
        SpawnMob(inst, mob3, mob3_count)
    end)
    inst:DoTaskInTime(10 + 6 * math.random(), function()
        SpawnMob(inst, mob4, mob4_count)
    end)
    inst:DoTaskInTime(20, function()
        local remove_fx = G.SpawnPrefab("electrichitsparks")
        if remove_fx then
            remove_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
        inst:Remove()
    end)
    return inst
end

-- REGISTER ALL PREFABS
--==================================================================================
local _engie_anim_assets = {
    Asset("ANIM", "anim/esentry.zip"),
    Asset("ANIM", "anim/esentry_item.zip"),
    Asset("ANIM", "anim/dispenser.zip"),
    Asset("ANIM", "anim/dispenser_meter.zip"),
    Asset("ANIM", "anim/eteleporter.zip"),
    Asset("ANIM", "anim/swap_engie_building.zip"),
}
RegisterPrefabs(
    Prefab("teslaflail", flail_fn, {Asset("ANIM", "anim/teslaflail_ground.zip"), Asset("ANIM", "anim/new_teslaflail.zip")}, {"electrichitsparks"}),
    Prefab("compassvest", compassvest_fn, {Asset("ANIM", "anim/compassvest.zip")}),
    Prefab("scrap", scrap_fn, {Asset("ANIM", "anim/tf2scrap.zip")}),
    Prefab("tf2wrench", wrench_fn, {Asset("ANIM", "anim/tf2wrench.zip"), Asset("ANIM", "anim/swap_tf2wrench.zip")}),
    Prefab("destructionpda", pda_fn, {Asset("ANIM", "anim/destructionpda.zip")}),
    Prefab("refinery_boards",   refinery_boards_fn,   {Asset("ANIM", "anim/refinery_boards.zip")}),
    Prefab("refinery_papyrus",  refinery_papyrus_fn,  {Asset("ANIM", "anim/refinery_papyrus.zip")}),
    Prefab("refinery_rope",     refinery_rope_fn,     {Asset("ANIM", "anim/refinery_rope.zip")}),
    Prefab("refinery_cutstone", refinery_cutstone_fn, {Asset("ANIM", "anim/refinery_cutstone.zip")}),
    MakePlacerCustom("refinery_boards_placer",   "refinery_boards",   "refinery_boards",   "idle_off"),
    MakePlacerCustom("refinery_papyrus_placer",  "refinery_papyrus",  "refinery_papyrus",  "idle_off"),
    MakePlacerCustom("refinery_rope_placer",     "refinery_rope",     "refinery_rope",     "idle_off"),
    MakePlacerCustom("refinery_cutstone_placer", "refinery_cutstone", "refinery_cutstone", "idle_off"),
    MakePlacerCustom("winona_generator_small_placer",  "winona_gen_small",  "winona_gen_small",  "idle"),
    MakePlacerCustom("winona_generator_medium_placer", "winona_gen_medium", "winona_gen_medium", "idle"),
    MakePlacerCustom("winona_generator_large_placer",  "winona_gen_large",  "winona_gen_large",  "idle"),
    Prefab("wagstaff_evil_portal", evil_portal_fn),
    Prefab("wagstaff_emergency_portal", function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddNetwork()
        inst:AddTag("FX")
        inst:AddTag("NOCLICK")
        inst.entity:SetPristine()
        if not G.TheWorld.ismastersim then return inst end
        inst.persists = false
        inst._use_count = 0
        inst._original_pos = nil
        inst.entity:AddLight()
        inst.Light:SetRadius(4)
        inst.Light:SetFalloff(0.7)
        inst.Light:SetIntensity(0.6)
        inst.Light:SetColour(50/255, 100/255, 255/255)
        inst.Light:Enable(true)
        local fx = G.SpawnPrefab("telebrella_glow")
        if fx then
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            fx._emergency_portal = true
        end
        inst._check_task = inst:DoPeriodicTask(0.5, function()
            if inst._use_count >= 2 then return end
            local x, y, z = inst.Transform:GetWorldPosition()
            local players = G.TheSim:FindEntities(x, y, z, 3, {"player"}, {"playerghost"})
            for _, player in ipairs(players) do
                if player == inst._owner then
                    inst._use_count = inst._use_count + 1
                    if inst._use_count == 1 then
                        inst._original_pos = {player.Transform:GetWorldPosition()}
                        if G.TheWorld.telipads and #G.TheWorld.telipads > 0 then
                            local pad = G.TheWorld.telipads[math.random(#G.TheWorld.telipads)]
                            if pad and pad:IsValid() then
                                local px, py, pz = pad.Transform:GetWorldPosition()
                                if player.components.rider and player.components.rider:IsRiding() then
                                    player.components.rider:ActualDismount()
                                end
                                player.Transform:SetPosition(px, py, pz)
                                if G.TheWorld.components.walkableplatformmanager then
                                    G.TheWorld.components.walkableplatformmanager:PostUpdate(0)
                                end
                                player:SnapCamera()
                                player.components.locomotor:Clear()
                                if player.SoundEmitter then
                                    player.SoundEmitter:PlaySound("dontstarve/common/teleportworm/teleportworm_exit")
                                end
                                if player.components.talker then
                                    player.components.talker:Say("Portal remains open for return!")
                                end
                            end
                        end
                    elseif inst._use_count == 2 then
                        if inst._original_pos then
                            if player.components.rider and player.components.rider:IsRiding() then
                                player.components.rider:ActualDismount()
                            end
                            player.Transform:SetPosition(inst._original_pos[1], inst._original_pos[2], inst._original_pos[3])
                            if G.TheWorld.components.walkableplatformmanager then
                                G.TheWorld.components.walkableplatformmanager:PostUpdate(0)
                            end
                            player:SnapCamera()
                            player.components.locomotor:Clear()
                            if player.SoundEmitter then
                                player.SoundEmitter:PlaySound("dontstarve/common/teleportworm/teleportworm_exit")
                            end
                        end
                        if inst._check_task then inst._check_task:Cancel() end
                        local remove_fx = G.SpawnPrefab("statue_transition")
                        if remove_fx then
                            remove_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                        end
                        inst:Remove()
                    end
                    break
                end
            end
        end)
        inst:DoTaskInTime(180, function()
            if inst._use_count < 2 then
                if inst._check_task then inst._check_task:Cancel() end
                local remove_fx = G.SpawnPrefab("statue_transition")
                if remove_fx then
                    remove_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                inst:Remove()
            end
        end)
        return inst
    end)
)