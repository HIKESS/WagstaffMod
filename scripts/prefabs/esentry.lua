require "prefabutil"

local _G = _G or GLOBAL

local assets =
{
    Asset("ANIM", "anim/esentry.zip"),
    Asset("ANIM", "anim/swap_engie_building.zip"),
    Asset("ANIM", "anim/esentry_item.zip"),
}

local prefabs =
{
    "esentry_bullet",
    "esentry_rocket",
    "scrap",
    "gunpowder",
}

local brain = require "brains/eyeturretbrain" --borrow
local easing = require("easing")
local AffinityPulse = _G.AffinityPulse

----------------------------------------------------------------
-- v2.0.43: Affinity Ramp System + Hit/Blast FX for Sentry MK3
----------------------------------------------------------------
-- Ramp: each hit on an aligned mob (shadow_aligned for celestial,
-- lunar_aligned for shadow) adds +10% base damage as bonus, stacking
-- up to 6 times (+60%). The ramp resets if the sentry doesn't attack
-- for 3 seconds OR gets hit (mirror of shadow_battleaxe ramp design).
-- The x2-Damage proc (10% chance) doubles the CURRENT total damage
-- (base + ramp bonus), not just the base — so a fully-ramped x2 proc
-- is a big burst.
--
-- FX: bullet hits spawn a brightsmithy-style sparkle (celestial) or
-- shadowcraft-style dark spike (shadow). Rocket impacts spawn a
-- bomb_lunarplant explosion FX (altered — tinted black for shadow).
-- All spawns are pcall-guarded with fallbacks so a missing DST prefab
-- never crashes the server.

local AFF_RAMP_MAX        = 4      -- v2.0.50: was 6. Max 4 stacks (+40% total)
                                    -- — 6 stacks (+60%) was OP combined with
                                    -- the x2-Damage proc doubling the total.
local AFF_RAMP_PCT        = 0.10   -- +10% base damage per stack
local AFF_RAMP_RESET_TIME = 3      -- seconds without a hit before reset
-- v2.0.61: x2-Damage reworked. Base proc is now 4% (down from 10%),
-- scaling +2.5% per MK3 sentry the owner has clustered nearby (cached count
-- refreshed every few seconds in the periodic task). A 4-second per-target
-- cooldown prevents melting a single enemy with back-to-back procs.
-- v2.0.65: per-sentry bonus 2.5% -> 3%. One MK3 sentry = 7%, two = 10%.
local AFF_X2_BASE_CHANCE    = 0.04   -- 4% base
local AFF_X2_PER_MK3_BONUS  = 0.03   -- +3% per MK3 sentry (incl. self)
local AFF_X2_TARGET_CD      = 4.0    -- seconds per-target cooldown

local function _safeSpawn(name)
    local ok, inst = pcall(function() return _G.SpawnPrefab(name) end)
    if ok and inst then return inst end
    return nil
end

-- Ramp state helpers (operate on the sentry inst).
local function ResetAffRamp(inst)
    if not inst or not inst:IsValid() then return end
    inst._aff_ramp_stacks = 0
    if inst._aff_ramp_reset_task then
        inst._aff_ramp_reset_task:Cancel()
        inst._aff_ramp_reset_task = nil
    end
end

local function BumpAffRamp(inst)
    if not inst or not inst:IsValid() then return end
    if inst._aff_ramp_stacks == nil then inst._aff_ramp_stacks = 0 end
    if inst._aff_ramp_stacks < AFF_RAMP_MAX then
        inst._aff_ramp_stacks = inst._aff_ramp_stacks + 1
    end
    -- (Re)schedule the 3s no-hit decay timer.
    if inst._aff_ramp_reset_task then
        inst._aff_ramp_reset_task:Cancel()
    end
    inst._aff_ramp_reset_task = inst:DoTaskInTime(AFF_RAMP_RESET_TIME, function()
        ResetAffRamp(inst)
    end)
end

local function GetAffRampBonus(inst, base_dmg)
    if not inst or not inst._aff_type then return 0 end
    local stacks = inst._aff_ramp_stacks or 0
    if stacks <= 0 then return 0 end
    return base_dmg * AFF_RAMP_PCT * stacks
end

-- Determine the aligned-tag for a given affinity type.
local function GetAlignedTag(aff_type)
    if aff_type == "celestial" then return "shadow_aligned" end
    if aff_type == "shadow"    then return "lunar_aligned"  end
    return nil
end

-- FX module: exposed globally so esentry_rocket can use it too.
-- v2.0.47 FIX: use rawget instead of _G.WagstaffAffFX to bypass strict.lua's
-- __index metamethod, which throws "variable not declared" on first load
-- (before line 165 below has a chance to write/declare the global).
local WagstaffAffFX = rawget(_G, "WagstaffAffFX") or {}

-- Bullet hit FX: brightsmithy sparkle (celestial) / shadowcraft spike (shadow).
WagstaffAffFX.HitFX = function(target, aff_type)
    if not target or not target:IsValid() then return end
    local x, y, z = target.Transform:GetWorldPosition()
    local fx = nil
    if aff_type == "celestial" then
        -- Try the brightsmithy (lunarplant) weapon hit sparkle variants.
        fx = _safeSpawn("lunarplant_sparkle_fx")
          or _safeSpawn("lunarplant_knife_fx")
          or _safeSpawn("sparklefx")
    elseif aff_type == "shadow" then
        -- Try the shadowcraft weapon hit spike variants.
        fx = _safeSpawn("shadow_spikes_fx")
          or _safeSpawn("shadowtar_fx")
          or _safeSpawn("shadowstrike_fx")
    end
    -- Fallback: recolored standard impact (guaranteed to exist in DST).
    if not fx then
        fx = _safeSpawn("impact")
        if fx and fx.AnimState then
            if aff_type == "celestial" then
                fx.AnimState:SetAddColour(0.25, 0.35, 0.55, 0)
            elseif aff_type == "shadow" then
                fx.AnimState:SetMultColour(0.30, 0.10, 0.40, 1)
                fx.AnimState:SetAddColour(0.10, 0.00, 0.20, 0)
            end
        end
    end
    if fx then
        fx.Transform:SetPosition(x, y + 1, z)
        fx.persists = false
        fx:DoTaskInTime(2, function() if fx and fx:IsValid() then fx:Remove() end end)
    end
end

-- Rocket impact FX: bomb_lunarplant explosion (celestial) / same tinted
-- black (shadow). The bomb item is spawned but its damage components are
-- stripped so it is purely visual ("the FX, not the bomb" — slightly altered).
WagstaffAffFX.BlastFX = function(host, aff_type)
    if not host or not host:IsValid() then return end
    local x, y, z = host.Transform:GetWorldPosition()
    local fx = nil
    -- Try the pure-FX prefabs first, then the bomb item itself.
    fx = _safeSpawn("bomb_lunarplant_fx")
      or _safeSpawn("lunarplant_bomb_fx")
      or _safeSpawn("bomb_lunarplant")
      or _safeSpawn("explode_small")   -- guaranteed fallback
    if not fx then return end
    fx.Transform:SetPosition(x, y, z)
    -- Strip damage so it's purely visual (safe-guarded with pcall).
    pcall(function()
        if fx.components.explosive then fx:RemoveComponent("explosive") end
    end)
    pcall(function()
        if fx.components.combat then fx:RemoveComponent("combat") end
    end)
    pcall(function()
        if fx.components.burnable then fx:RemoveComponent("burnable") end
    end)
    -- Tint: celestial keeps the default lunarplant blue/silver; shadow = black.
    if aff_type == "shadow" and fx.AnimState then
        fx.AnimState:SetMultColour(0.08, 0.05, 0.12, 1)
        fx.AnimState:SetAddColour(0.05, 0.00, 0.10, 0)
    elseif aff_type == "celestial" and fx.AnimState then
        -- Slight enhancement: brighter blue/silver for the celestial blast.
        fx.AnimState:SetAddColour(0.10, 0.15, 0.25, 0)
    end
    fx.persists = false
    fx:DoTaskInTime(4, function() if fx and fx:IsValid() then fx:Remove() end end)
end

-- v2.0.47 FIX: use rawset to bypass strict.lua's __newindex (avoids potential
-- "assign to undeclared variable" error when writing the global from a module
-- context). rawset writes directly to the table without metatable interception.
rawset(_G, "WagstaffAffFX", WagstaffAffFX)

local function OnNameDelta(inst)
        local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
        if builder or inst.maker then
                if inst:HasTag("NOLEVEL") then
                        inst.components.named:SetName(_G.subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ", { builder = inst.maker }))
                else
                if inst:HasTag("lvl1") or inst:HasTag("lvl2") then
                        inst.components.named:SetName(_G.subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ".."\n Upgrade Progress "..inst.upgradelevel.." / 70", { builder = inst.maker }))
                elseif inst:HasTag("lvl3") then
                        inst.components.named:SetName(_G.subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ", { builder = inst.maker }))
                end
                end
        else
                inst.components.named:SetName("Sentry Gun".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health " )
        end
end

--Called from stategraph
local function LaunchProjectile(inst, targetpos)
    local x, y, z = inst.Transform:GetWorldPosition()
        local angle = -inst.Transform:GetRotation() * _G.DEGREES
        local range = _G.SENTRY_RANGE
        local targetpos = _G.Vector3(x + math.cos(angle) * range, y, z + math.sin(angle) * range)
    local projectile = _G.SpawnPrefab("esentry_rocket")
    projectile.Transform:SetPosition(x, y, z)
    projectile.components.complexprojectile:Launch(targetpos, inst, inst)
end

local function EquipWeapon(inst)
    if inst.components.inventory and not inst.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS) then
        local weapon = _G.CreateEntity()
        --[[Non-networked entity]]
        weapon.entity:AddTransform()
        weapon:AddComponent("weapon")
                weapon.components.weapon:SetDamage(_G.SENTRY_DAMAGE)
        weapon.components.weapon:SetRange(inst.components.combat.attackrange, inst.components.combat.attackrange+4)
            weapon.components.weapon:SetProjectile("esentry_bullet")
        weapon:AddComponent("inventoryitem")
        weapon.persists = false
        weapon.components.inventoryitem:SetOnDroppedFn(weapon.Remove)
        weapon:AddComponent("equippable")
        inst.components.inventory:Equip(weapon)
    end
end

local function retargetfn(inst)
    EquipWeapon(inst)
    local playertargets = {}
    for i, v in ipairs(_G.AllPlayers) do
        if v.components.combat.target ~= nil then
            playertargets[v.components.combat.target] = true
        end
    end

    if _G.SENTRY_FF == "noff" then
----------friendly fire OFF--------------
    return _G.FindEntity(inst, _G.SENTRY_RANGE,
        function(guy)
            return not guy:HasTag("player") and inst.components.combat:CanTarget(guy)
                and (playertargets[guy] or guy:HasTag("hostile") or
                    (guy.components.combat.target ~= nil and guy.components.combat.target:HasTag("player") or 
                     guy.components.combat.target ~= nil and guy.components.combat.target:HasTag("esentry")))
        end,
        { "_combat" },
        { "INLIMBO", "engie", "esentry", "wall", "companion", "playermonster" }
    )
----------friendly fire ON--------------
    elseif _G.SENTRY_FF == "yesff" then
    return _G.FindEntity(inst, _G.SENTRY_RANGE,
        function(guy)
                local attackerID = guy.engieID or nil
                if guy ~= nil and (attackerID == nil or attackerID ~= inst.turretID) then
            return inst.components.combat:CanTarget(guy)
                and (playertargets[guy] or guy:HasTag("hostile") or
                    (guy.components.combat.target ~= nil and guy.components.combat.target:HasTag("player") or 
                     guy.components.combat.target ~= nil and guy.components.combat.target:HasTag("esentry")))
        end
                end,
        { "_combat" },
        { "INLIMBO", "esentry", "wall", }
    )
        end
end

local function shouldKeepTarget(inst, target)
    return target ~= nil
        and target:IsValid()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and inst:IsNear(target, _G.SENTRY_RANGE)
end

local function OnAttacked(inst, data)
    local attacker = data ~= nil and data.attacker or nil
    local attackerID = attacker.engieID or nil

    if _G.SENTRY_FF == "noff" then
    if attacker ~= nil and not attacker:HasTag("player") and (attackerID == nil or attackerID ~= inst.turretID) then
        EquipWeapon(inst)
        inst.components.combat:SetTarget(attacker)
    end
    elseif _G.SENTRY_FF == "yesff" then
    if attacker ~= nil and (attackerID == nil or attackerID ~= inst.turretID) then
        EquipWeapon(inst)
        inst.components.combat:SetTarget(attacker)
    end
    end

end

local function lighttweencb(inst, light)
    if light ~= nil then
        light:Enable(false)
    end
end

local function dotweenin(inst, l)
    inst.components.lighttweener:StartTween(nil, 0, .65, .7, nil, 0.15, lighttweencb)
end

local function upgrade(inst)
    local item = inst.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS) or nil
    if inst.upgradelevel >= 30 and inst.upgradelevel < 70 then
        inst:AddTag("lvl2")
        inst:RemoveTag("lvl1")
        if inst.MiniMapEntity then inst.MiniMapEntity:SetIcon("esentry_2.tex") end
        inst.components.health:SetMaxHealth(_G.SENTRY_HEALTH * 2)
        inst.AnimState:PlayAnimation("upgrade2")
        inst.AnimState:PushAnimation("idle_loop_2", true)
        if item ~= nil then
            inst.components.inventory:DropItem(item)
            EquipWeapon(inst)
        end
    end
    if inst.upgradelevel >= 70 then
        inst:AddTag("lvl3")
        inst:AddTag("rocketsready")
        inst:RemoveTag("lvl1")
        inst:RemoveTag("lvl2")
        if inst.MiniMapEntity then inst.MiniMapEntity:SetIcon("esentry_3.tex") end
        inst.components.health:SetMaxHealth(_G.SENTRY_HEALTH * 3)
        inst.AnimState:PlayAnimation("upgrade3")
        inst.AnimState:PushAnimation("idle_loop_3", true)
        if item ~= nil then
            inst.components.inventory:DropItem(item)
            EquipWeapon(inst)
        end
        -- Activate MK3 affinity system
        if inst._SetupMK3Affinity then
            inst._SetupMK3Affinity(inst)
        end
    end
end

local function onpreload(inst, data)
    inst.maker = data.maker
end

local function onsave(inst, data)
    data.upgradelevel = inst.upgradelevel
    data.ammo = inst.ammo
        data.turretID = inst.turretID
    data.maker = inst.maker
    if inst.components.named then
        data.name = inst.components.named.name
    end
end

local function onload(inst, data)
    inst.upgradelevel = data.upgradelevel
    inst.ammo = data.ammo
        inst.turretID = data.turretID
    inst.maker = data.maker or inst.maker
    if data.name and inst.components.named then
        inst.components.named:SetName(data.name)
    end
    upgrade(inst)
    -- v2.0.61: restore the MK3 tag for pre-existing MK3 sentries (the tag is
    -- normally added when upgradelevel hits 70 via wrench, but a sentry that
    -- was already MK3 before this version needs it on load for the x2-Damage
    -- count scaling to work).
    if inst.upgradelevel and inst.upgradelevel >= 70 then
        inst:AddTag("william_sentry_mk3")
    end
end

local function onbuilt(inst, builder)
        if builder and builder.engieID then
                -- builder.engieID logged
                inst.turretID = builder.engieID
                builder:PushEvent("engiebuilding")
                if builder.components.talker ~= nil then
                        builder.components.talker:Say(_G.GetString(builder, "ANNOUNCE_SENTRYBUILT"))
                end
                local new_name = _G.subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ", { builder = builder.name })
                inst.components.named:SetName(new_name)
                inst.components.entitytracker:TrackEntity("builder", builder)
        end
        inst.maker = builder.name
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle_loop", true)
--    inst.components.named:SetName("Sentry Gun Lvl.1".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health " )
    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
end

local function IsScrap(item)
    return item.prefab == "scrap"
end

local function IsGunpowder(item)
    return item.prefab == "gunpowder"
end

local function workup(inst, worker)
    local scrapstack = worker.components.inventory:FindItem(IsScrap)
    if scrapstack ~= nil then
        local next_level = inst.upgradelevel + 1
        if next_level == 30 and not _G.WagstaffHasSkill(worker, "wagstaff_sentry_mk2") then
            if worker.components.talker then
                worker.components.talker:Say("Requires Sentry Mk.2 skill!")
            end
            return
        end
        if next_level == 70 and not _G.WagstaffHasSkill(worker, "wagstaff_sentry_mk3") then
            if worker.components.talker then
                worker.components.talker:Say("Requires Sentry Mk.3 skill!")
            end
            return
        end
        local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
        if upgrade_cost > 0 then
            worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
        end
        inst.upgradelevel = inst.upgradelevel + 1
        if inst.upgradelevel == 30 then
            inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
            upgrade(inst)
        elseif inst.upgradelevel == 70 then
            inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
            upgrade(inst)
            -- v2.0.61: tag MK3 sentries so nearby sentries can count them for
            -- the x2-Damage proc scaling.
            inst:AddTag("william_sentry_mk3")
        end
    end
        local builder = (inst.components.entitytracker and inst.components.entitytracker:GetEntity("builder")) or nil
        if builder or inst.maker then
                if inst:HasTag("lvl1") or inst:HasTag("lvl2") then
                inst.components.named:SetName(_G.subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ".."\n Upgrade Progress "..inst.upgradelevel.." / 70", { builder = inst.maker }))
                elseif inst:HasTag("lvl3") then
                inst.components.named:SetName(_G.subfmt("Sentry Gun built by {builder}".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ", { builder = inst.maker }))
                end
        else
                if inst:HasTag("lvl1") or inst:HasTag("lvl2") then
                        inst.components.named:SetName("Sentry Gun".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health ".."\n Upgrade Progress "..inst.upgradelevel.." / 70" )
                elseif inst:HasTag("lvl3") then
                        inst.components.named:SetName("Sentry Gun".."\n"..inst.ammo.." Rounds Remaining".."\n"..inst.components.health.currenthealth.." Health " )
                end
        end
end

local function onhammered(inst)
    inst.components.lootdropper:DropLoot()
    local fx = _G.SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
    for k,v in pairs(_G.Ents) do
        if v and v.engieID == inst.turretID then
                v:PushEvent("engiebuilding")
        end
    end
end

local function onhit(inst, worker)
    if not (worker:HasTag("engie") or worker:HasTag("spy") or worker:HasTag("engie_pardner")) then
        inst.components.workable:SetWorkLeft(8)
        return
    end

    if inst:HasTag("lvl1") then
        inst.AnimState:PlayAnimation("hit")
    end
    if inst:HasTag("lvl2") then
        inst.AnimState:PlayAnimation("hit2")
    end
    if inst:HasTag("lvl3") then
        inst.AnimState:PlayAnimation("hit3")
    end
end

-- Wrench interaction: repair, reload, and upgrade via engieworkable
local function OnWrenchWork(inst, worker)
    -- Hit animation
    if inst:HasTag("lvl1") then
        inst.AnimState:PlayAnimation("hit")
    elseif inst:HasTag("lvl2") then
        inst.AnimState:PlayAnimation("hit2")
    elseif inst:HasTag("lvl3") then
        inst.AnimState:PlayAnimation("hit3")
    end

    -- Use wrench durability
    if worker.replica.inventory ~= nil and worker.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS) ~= nil and worker.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS).prefab == "tf2wrench" then
        worker.replica.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS).components.finiteuses:Use(1)
    end

    local gpstack = worker.components.inventory:FindItem(IsGunpowder)
    local scrapstack = worker.components.inventory:FindItem(IsScrap)

    -- Repair health first
    if inst.components.health.currenthealth < inst.components.health.maxhealth and scrapstack ~= nil then
        local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
        if repair_cost > 0 then
            worker.components.inventory:ConsumeByName("scrap", repair_cost)
        end
        inst.components.health.currenthealth = inst.components.health.currenthealth + _G.TUNING.SENTRY_WRENCH_HEAL
        if inst.components.health.currenthealth > inst.components.health.maxhealth then
            inst.components.health.currenthealth = inst.components.health.maxhealth
        end
        OnNameDelta(inst)
        return
    end

    -- Reload with gunpowder
    if gpstack ~= nil then
        if inst:HasTag("lvl1") and inst.ammo < 100 then
            worker.components.inventory:ConsumeByName("gunpowder", 1)
            inst.ammo = inst.ammo + 10
            inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
            if inst.ammo >= 100 then
                inst.ammo = 100
            end
            OnNameDelta(inst)
            return
        end
        if inst:HasTag("lvl2") and inst.ammo < 200 then
            worker.components.inventory:ConsumeByName("gunpowder", 1)
            inst.ammo = inst.ammo + 20
            inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
            if inst.ammo >= 200 then
                inst.ammo = 200
            end
            OnNameDelta(inst)
            return
        end
        if inst:HasTag("lvl3") and inst.ammo < 300 then
            worker.components.inventory:ConsumeByName("gunpowder", 1)
            inst.ammo = inst.ammo + 30
            inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
            if inst.ammo >= 300 then
                inst.ammo = 300
            end
            OnNameDelta(inst)
            return
        end
    end

    -- Reload with scrap
    if scrapstack ~= nil then
        if inst:HasTag("lvl1") and inst.ammo < 100 then
            local reload_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
            if reload_cost > 0 then
                worker.components.inventory:ConsumeByName("scrap", reload_cost)
            end
            inst.ammo = inst.ammo + 5
            inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
            if inst.ammo >= 100 then
                inst.ammo = 100
            end
            OnNameDelta(inst)
            return
        end
        if inst:HasTag("lvl2") and inst.ammo < 200 then
            local reload_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
            if reload_cost > 0 then
                worker.components.inventory:ConsumeByName("scrap", reload_cost)
            end
            inst.ammo = inst.ammo + 10
            inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
            if inst.ammo >= 200 then
                inst.ammo = 200
            end
            OnNameDelta(inst)
            return
        end
        if inst:HasTag("lvl3") and inst.ammo < 300 then
            local reload_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
            if reload_cost > 0 then
                worker.components.inventory:ConsumeByName("scrap", reload_cost)
            end
            inst.ammo = inst.ammo + 15
            inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")
            if inst.ammo >= 300 then
                inst.ammo = 300
            end
            OnNameDelta(inst)
            return
        end
    end

    -- Upgrade if health full and ammo full
    if not inst:HasTag("NOLEVEL") and not inst:HasTag("lvl3") and scrapstack ~= nil then
        inst.tick = 0
        while inst.tick ~= 5 and not inst:HasTag("lvl3") do
            workup(inst, worker)
            inst.tick = inst.tick + 1
        end
    end
end

local function resetrockets(inst)
    if inst.rockettask == nil then
        inst.rockettask = inst:DoTaskInTime(5, function(inst)
            inst:AddTag("rocketsready")
            inst.rockettask:Cancel()
            inst.rockettask = nil
        end)
    end
end

local function ondeath(inst)
        for k,v in pairs(_G.Ents) do
                if v and v.engieID == inst.turretID then
                        v:PushEvent("engiebuilding")
                        if v.components.sanity ~= nil then
                                v.components.sanity:DoDelta(-_G.TUNING.ENGIE_BUILDINGLOSS)
                        end
                        if v.components.talker ~= nil then
                                v.components.talker:Say(_G.GetString(v, "ANNOUNCE_SENTRY_DOWN"))
                        end
                end
        end
end

local function onremoved(inst)
        for k,v in pairs(_G.Ents) do
                if v and v.engieID == inst.turretID then
                        v:PushEvent("engiebuilding")
                end
        end
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    if owner.components.health ~= nil and
    not owner.components.health:IsDead() then
        owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_REPLANTING"))
        end

    inst.SoundEmitter:PlaySound("dontstarve/common/birdcage_craft")

        if inst:HasTag("lvl1") then
        inst.AnimState:PlayAnimation("place")
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl1_place")
    end
    if inst:HasTag("lvl2") then
        inst.AnimState:PlayAnimation("upgrade2")
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl2_place")
    end
    if inst:HasTag("lvl3") then
        inst.AnimState:PlayAnimation("upgrade2")
        inst.AnimState:PlayAnimation("upgrade3", false)
--      inst.AnimState:PushAnimation("upgrade2")
--      inst.AnimState:PushAnimation("upgrade3", false)
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_place")
    end
end

local function onequip(inst, owner)
        owner.AnimState:OverrideSymbol("swap_body", "swap_engie_building", "swap_body")
        if owner.components.talker ~= nil then
        owner.components.talker:Say(_G.GetString(owner, "ANNOUNCE_PACKINGUP"))
        end
end

local function fn()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()
    inst.MiniMapEntity:SetIcon("esentry.tex")
    _G.MakeObstaclePhysics(inst, 1)

    inst.no_wet_prefix = true


    inst.AnimState:SetBank("esentry")
    inst.AnimState:SetBuild("esentry")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst:AddTag("structure")
    inst:AddTag("eyeturret")
    inst:AddTag("companion")
    inst:AddTag("esentry")
    inst:AddTag("lvl1")
    inst:AddTag("ebuild")
        inst:AddTag("ebuild_wrenchable")
        inst:AddTag("nonpotatable")
    inst:AddTag("heavy")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventory")
    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("named")
    inst.components.named:SetName("Sentry Gun")
        inst:AddComponent("entitytracker")-- This is for unique names, not IDs

    inst:AddComponent("engieworkable")
    inst.components.engieworkable:SetWorkAction(_G.ACTIONS.ENGIEWORKABLE)
    inst.components.engieworkable:SetMaxWork(1)
    inst.components.engieworkable:SetWorkLeft(1)
    inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
        -- Hit animation
        if inst:HasTag("lvl1") then
            inst.AnimState:PlayAnimation("hit")
        elseif inst:HasTag("lvl2") then
            inst.AnimState:PlayAnimation("hit2")
        elseif inst:HasTag("lvl3") then
            inst.AnimState:PlayAnimation("hit3")
        end
    end)
    inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
        inst.components.engieworkable:SetWorkLeft(1)
        OnWrenchWork(inst, worker)
    end)

    inst:AddComponent("lighttweener")
    inst.components.lighttweener:StartTween(inst.Light, 0, .65, .7, {251/255, 234/255, 234/255}, 0, lighttweencb)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(_G.SENTRY_HEALTH)
    inst.components.health.canheal = false

    inst:AddComponent("combat")
    inst.components.combat:SetRange(_G.SENTRY_RANGE)
    inst.components.combat:SetDefaultDamage(_G.SENTRY_DAMAGE)
    inst.components.combat:SetAttackPeriod(_G.SENTRY_ROF)
    inst.components.combat:SetRetargetFunction(0, retargetfn)
    inst.components.combat:SetKeepTargetFunction(shouldKeepTarget)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(_G.ACTIONS.HAMMER)
--    inst.components.workable:SetMaxWork(4)
    inst.components.workable:SetWorkLeft(8)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)
    inst.components.workable.destroyed = "NODESTROY" --Hack to prevent workable:Destroy() only

        inst:AddComponent("symbolswapdata")
        inst.components.symbolswapdata:SetData("swap_engie_building", "swap_body")

    _G.MakeHauntableFreeze(inst)


    inst:SetStateGraph("SGesentry")
    inst:SetBrain(brain)

    inst.LaunchProjectile = LaunchProjectile

    -- Affinity system (MK3 only - activated when upgrade reaches lvl3)
    inst._affinity_setup_done = false
    local function GetSentryOwner(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local players = TheSim:FindEntities(x, y, z, 40, {"player"})
        for _, p in ipairs(players) do
            if p.turretID == inst.turretID or (inst.turretID and p.engieID == inst.turretID) then
                return p
            end
        end
        for _, p in ipairs(players) do
            if p:HasTag("wagstaff_celestial_possession") or p:HasTag("wagstaff_shadow_possession") or p:HasTag("wagstaff_x2_damage") then
                return p
            end
        end
        return nil
    end

    local base_dmg = _G.SENTRY_DAMAGE
    local function SetupMK3Affinity(inst)
        if inst._affinity_setup_done then return end
        inst._affinity_setup_done = true

        AffinityPulse.Setup(inst, GetSentryOwner)

        -- v2.0.43: Ramp state. The periodic task below only SETS the affinity
        -- type flag + x2 flag — the actual damage logic lives in a SINGLE
        -- onhitotherfn set once here (no more swapping onhitotherfn every
        -- tick, which was fragile and reset closures constantly).
        inst._aff_ramp_stacks = 0
        inst._aff_ramp_reset_task = nil
        inst._aff_type = nil         -- "celestial" | "shadow" | nil
        inst._aff_x2_damage = false  -- owner has wagstaff_x2_damage skill

        -- Expose ramp helpers on the inst so esentry_rocket can call them
        -- (the rocket reads sentry._aff_type / calls sentry.BumpAffRamp etc.
        -- to apply the ramp bonus + x2 on rocket direct hits).
        inst.ResetAffRamp   = ResetAffRamp
        inst.BumpAffRamp    = BumpAffRamp
        inst.GetAffRampBonus = GetAffRampBonus

        -- Unified onhitotherfn: handles ramp + x2 + FX for bullets.
        -- Fires on every bullet hit (the sentry's weapon projectile).
        inst.components.combat.onhitotherfn = function(i, other, dmg)
            if not other or not other:IsValid() then return end
            -- v2.0.51: adaptive affinity per-target. For single-affinity owners
            -- this resolves to _aff_type as before. For dual-affinity owners
            -- (rare) it picks the affinity matching THIS target's faction, so
            -- the ramp applies to whichever aligned mob is being hit.
            local aff = i._aff_type
            if i._owner_celestial and other:HasTag("shadow_aligned") then
                aff = "celestial"
            elseif i._owner_shadow and other:HasTag("lunar_aligned") then
                aff = "shadow"
            end
            local aligned_tag = GetAlignedTag(aff)
            local is_aligned = aligned_tag and other:HasTag(aligned_tag) or false

            -- Ramp: bump + apply bonus damage ONLY on aligned hits.
            local ramp_bonus = 0
            if is_aligned then
                BumpAffRamp(i)
                ramp_bonus = GetAffRampBonus(i, dmg)
                if ramp_bonus > 0 and other.components.health then
                    other.components.health:DoDelta(-ramp_bonus, false, "affinity_ramp")
                end
                -- Bullet hit FX (brightsmithy sparkle / shadowcraft spike).
                if WagstaffAffFX and WagstaffAffFX.HitFX then
                    WagstaffAffFX.HitFX(other, aff)
                end
            end

            -- x2-Damage (v2.0.61 rework): 4% base + 2.5% per nearby MK3 sentry,
            -- with a 4s per-target cooldown so a single enemy can't be melted
            -- by back-to-back procs. Doubles the CURRENT total (base dmg + ramp).
            if i._aff_x2_damage then
                local cd_until = other._william_x2_cd or 0
                if GetTime() >= cd_until then
                    local chance = i._x2_proc_chance or AFF_X2_BASE_CHANCE
                    if math.random() < chance then
                        local total = dmg + ramp_bonus
                        if other.components.health then
                            other.components.health:DoDelta(-total, false, "x2_damage")
                        end
                        other._william_x2_cd = GetTime() + AFF_X2_TARGET_CD
                    end
                end
            end
        end

        -- Reset the ramp when the sentry gets hit (mirror shadow_battleaxe design:
        -- ramp rewards sustained offense, getting hit punishes it).
        inst:ListenForEvent("attacked", function(i)
            ResetAffRamp(i)
        end)

        -- Periodic task: refresh the affinity type + x2 flag from the owner
        -- and the world phase. No more onhitotherfn swapping.
        -- v2.0.51: Removed the day/dusk phase lock. The sentry is a STATIC
        -- defensive turret — locking its affinity to one phase of day made it
        -- useless half the time (e.g. the shadow sentry only fought
        -- lunar-aligned at dusk, but you explore the lunar island by day; the
        -- celestial sentry only fought shadow-aligned by day, but shadow rifts
        -- invade at night). Affinity is now active 24/7 based on the owner's
        -- possession tag. The affinity defines WHO the sentry fights (enemy
        -- faction), not WHEN — consistent with the Brute taunt (v2.0.48).
        inst:DoPeriodicTask(1, function()
            local owner = GetSentryOwner(inst)
            local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
            local shadow    = owner and owner:HasTag("wagstaff_shadow_possession")
            inst._aff_x2_damage = owner and owner:HasTag("wagstaff_x2_damage") or false
            -- Cache owner affinity flags for the adaptive onhitotherfn.
            inst._owner_celestial = celestial or false
            inst._owner_shadow = shadow or false

            -- v2.0.61: Refresh the nearby MK3 sentry count (used by the x2-Damage
            -- proc scaling). Scanned every 3 ticks (3s) instead of every tick to
            -- keep the FindEntities cost low when multiple sentries are deployed.
            -- Counts self + other MK3 sentries within 25 units (base cluster range).
            inst._count_tick = (inst._count_tick or 0) + 1
            if inst._count_tick >= 3 then
                inst._count_tick = 0
                if inst._aff_x2_damage then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local sentries = TheSim:FindEntities(x, y, z, 25, {"william_sentry_mk3"}, {"INLIMBO"})
                    inst._mk3_sentry_count = #sentries
                    -- v2.0.61: cache the computed proc chance so the bullet
                    -- onhitotherfn AND esentry_rocket read the same value.
                    inst._x2_proc_chance = AFF_X2_BASE_CHANCE + AFF_X2_PER_MK3_BONUS * (inst._mk3_sentry_count or 1)
                else
                    inst._mk3_sentry_count = nil
                    inst._x2_proc_chance = nil
                end
            end

            -- Sight tags let the sentry DETECT aligned mobs (which have stealth
            -- against normal observers). Set whichever matches the owner's
            -- path(s). Dual-affinity owners get both sight tags so they can
            -- see both factions.
            if celestial then
                inst:AddTag("shadowaligned_sight")
            else
                inst:RemoveTag("shadowaligned_sight")
            end
            if shadow then
                inst:AddTag("lunarcurse_sight")
            else
                inst:RemoveTag("lunarcurse_sight")
            end

            -- Default affinity for FX/fallback. For dual-affinity owners the
            -- onhitotherfn picks the matching affinity per-target, so this
            -- default only affects non-aligned hits (no ramp anyway).
            -- Priority: celestial > shadow (arbitrary but deterministic).
            local new_aff
            if celestial then
                new_aff = "celestial"
            elseif shadow then
                new_aff = "shadow"
            end

            -- If affinity changed (owner switched path / first setup), reset
            -- the ramp so stale stacks don't carry over.
            if new_aff ~= inst._aff_type then
                inst._aff_type = new_aff
                ResetAffRamp(inst)
            end
        end)
    end

    -- Hook into upgrade to detect MK3
    local old_upgrade = upgrade
    local _upgrade_orig = upgrade
    inst._SetupMK3Affinity = SetupMK3Affinity
    inst:ListenForEvent("ms_save", function() end) -- placeholder to keep inst ref
    -- Patch: after upgrade() runs and lvl3 tag is added, setup affinity
    local _old_onload = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if _old_onload then _old_onload(inst, data) end
        if inst:HasTag("lvl3") then
            inst._SetupMK3Affinity(inst)
        end
    end

    inst.OnSave = onsave
    inst.OnLoad = onload
        inst.OnPreLoad = onpreload
    inst.OnBuiltFn = onbuilt

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("rocketsshot", resetrockets)
    inst:ListenForEvent("checkwep", EquipWeapon)
    inst:ListenForEvent("healthdelta", OnNameDelta)
        inst:ListenForEvent("death", ondeath)
        inst:ListenForEvent("onsink", ondeath) --Cheat
        inst:ListenForEvent("onremove", onremoved)
--      inst:ListenForEvent("ondeconstructstructure", onremoved)

        inst.maker = 0
    inst.dotweenin = dotweenin
    inst.upgradelevel = 0
    inst.ammo = 100
    inst.checkammo = inst:DoPeriodicTask(.1, function(inst)
        if inst.ammo == 0 then
            if math.random() > .90 then
                local x,y,z = inst.Transform:GetWorldPosition()
                _G.SpawnPrefab("sparks").Transform:SetPosition(x + math.random(), 1.75, z + math.random())
            end
        end
    end)
        ---------------------------------------
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = _G.ENGINEERITEMIMAGES
    inst.components.inventoryitem.cangoincontainer = false
    inst.components.inventoryitem:SetSinks(true)
        inst.components.inventoryitem.nobounce = true
        inst.components.inventoryitem.imagename = "esentry_item"        
    if inst.replica.inventoryitem then
        if inst.replica.inventoryitem.SetAtlas then
            inst.replica.inventoryitem:SetAtlas(_G.ENGINEERITEMIMAGES)
        end
        inst.replica.inventoryitem:SetImage("esentry_item")
    end

        inst:AddComponent("heavyobstaclephysics")
    inst.components.heavyobstaclephysics:SetRadius(1)
    inst.components.heavyobstaclephysics:MakeSmallObstacle()

        inst:AddComponent("equippable")
    inst.components.equippable.equipslot = _G.EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = _G.TUNING.TOOLBOX_SPEED_MULT--HEAVY_SPEED_MULT
        inst.components.equippable.restrictedtag = "engie"
    ---------------------------------------
    return inst
end

return _G.Prefab("esentry", fn, assets, prefabs)--,
--      MakePlacer("common/esentry_placer", "esentry_item", "esentry_item", "idle")
