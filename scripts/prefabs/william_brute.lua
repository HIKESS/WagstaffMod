local prefabs =
{

}

    local assets =
    {
        Asset("ANIM", "anim/william_brute.zip"),
        Asset("ANIM", "anim/william_upgrades.zip"),
        Asset("ANIM", "anim/william_garyhat_swap.zip"),
    Asset("ANIM", "anim/merm_actions.zip"),
    Asset("ANIM", "anim/merm_guard_transformation.zip"),    
    Asset("ANIM", "anim/ds_pig_boat_jump.zip"),
    Asset("ANIM", "anim/ds_pig_basic.zip"),
    Asset("ANIM", "anim/ds_pig_actions.zip"),
    Asset("ANIM", "anim/ds_pig_attacks.zip"),
    }

-- v2.0.17: debug helpers gated by the "Debug mode" mod config button.
local _dbg  = _G.WagstaffDbg  or function(...) end
local _dbgF = _G.WagstaffDbgF or function(...) end

-- v2.0.35: Design correto = williamgadget (100% via lootsetfn) + 50% de UM item
-- so (o material principal do recipe). Antes v2.0.34 tinha 50% por material (2
-- itens), mas o design original era 50% para 1 item so.
-- Brute recipe: williamgadget + cutstone(4) + transistor(2) -> material principal = cutstone
SetSharedLootTable("brute",
{
    {'cutstone',          0.50},
})

SetSharedLootTable("brutegadget",
{
    {'williamgadget',          1},
})

local function OnOpen(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
end

local function OnClose(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
end

local function lootsetfn(lootdropper)
    -- v2.0.34: williamgadget (core) sempre dropa. gears adicionais por level
    -- (recompensa de level up, nao e bonus aleatorio).
    local loot = {"williamgadget"}
    local amount = lootdropper.inst.level*0.75
        if amount < 1 then amount = 1 end

                if lootdropper.inst.level > 0 then
                for k = 1, amount do
            table.insert(loot, "gears")
                end
                end


    lootdropper:SetLoot(loot)
end

local brain = require "brains/williambrutebrain"
local AffinityPulse = _G.AffinityPulse

-- Helper function to check if bot's owner has affinity skills
local function GetOwner(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end

local function OwnerHasCelestial(inst)
    local owner = GetOwner(inst)
    return owner and owner:HasTag("wagstaff_celestial_possession")
end

local function OwnerHasShadow(inst)
    local owner = GetOwner(inst)
    return owner and owner:HasTag("wagstaff_shadow_possession")
end

local function RememberKnownLocation(inst)
--    inst.components.knownlocations:RememberLocation("home", inst:GetPosition())
end

local function IsTauntable(inst, target)
    return not (target.components.health ~= nil and target.components.health:IsDead())
        and target.components.combat ~= nil
        and not target.components.combat:TargetIs(inst)
        and target.components.combat:CanTarget(inst)
        and  (   target.components.combat:HasTarget() and
                    (   target.components.combat.target:HasTag("player") or
                        (target.components.combat.target:HasTag("companion") and target.components.combat.target.prefab ~= inst.prefab)
                    )
                )
end


local function TauntCreatures(inst)
    if not inst.components.health:IsDead() then
        local x, y, z = inst.Transform:GetWorldPosition()

        -- v2.0.48: Affinity-aware taunt for MK3 brutes. Each affinity now tanks
        -- its ENEMY faction (mirrors the sentry faction logic — lunar and shadow
        -- are opposing rift factions). Previously the taunt was affinity-blind:
        -- the shadow Brute would draw aggro from shadow-aligned creatures (its
        -- own kin), which was thematically wrong.
        --   Celestial (day) -> taunts shadow-aligned + neutral hostiles,
        --                       EXCLUDES lunar-aligned (allies).
        --   Shadow (dusk)   -> taunts lunar-aligned + neutral hostiles,
        --                       EXCLUDES shadow-aligned (allies).
        --   Base / MK1 / MK2 / affinity inactive -> original behavior
        --                       (exclude the legacy "shadow" tag so basic
        --                        brutes don't pull nightmare creatures).
        local is_mk3 = inst.prefab == "williambrute3"
        local celestial_active = is_mk3 and TheWorld.state.isday and OwnerHasCelestial(inst)
        local shadow_active    = is_mk3 and TheWorld.state.isdusk and OwnerHasShadow(inst)

        local cant_tags, affinity_filter
        if celestial_active then
            -- Celestial Brute tanks the shadow faction (its enemy).
            cant_tags = { "INLIMBO", "player", "companion", "epic", "notaunt" }
            affinity_filter = function(v) return not v:HasTag("lunar_aligned") end
        elseif shadow_active then
            -- Shadow Brute tanks the lunar faction (its enemy).
            cant_tags = { "INLIMBO", "player", "companion", "epic", "notaunt" }
            affinity_filter = function(v) return not v:HasTag("shadow_aligned") end
        else
            -- Base/MK1/MK2 or affinity inactive: original behavior.
            cant_tags = { "INLIMBO", "player", "companion", "epic", "notaunt", "shadow" }
        end

        for i, v in ipairs(TheSim:FindEntities(x, y, z, 7, { "_combat", "locomotor" }, cant_tags)) do
            if IsTauntable(inst, v) and (affinity_filter == nil or affinity_filter(v)) then
                v.components.combat:SetTarget(inst)
            end
        end
    end
end

local function OnHammered(inst, worker)
    -- Don't destroy if bot is ON (engieworkable handles upgrade when ON)
    if inst.on == true then
        return
    end

    -- v2.0.85 FIX: Drop ALL items from the container before removing the entity.
    -- Without this, items stored in the brute's chest (including player items like
    -- Chester Cane) were silently destroyed when the bot was hammered. The brute is
    -- the only bot with a container component, so this only applies here.
    if inst.components.container ~= nil then
        inst.components.container:Close()
        inst.components.container:DropEverything()
    end

    -- v2.0.34: lootsetfn garante williamgadget (100%) + gears por level.
    -- Chance table "brute" da 50% cutstone + 50% transistor (bonus alinhado ao recipe).
    -- FIX: antes usava SetChanceLootTable({"armorwood", 1}) que e sintaxe INVALIDA
    -- (SetChanceLootTable espera string, nao tabela) + armorwood nao e do recipe.
    inst.components.lootdropper:DropLoot()

        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("metal")
    inst:Remove()
end


local function _ShareTargetFn(dude)
    return dude:HasTag("willminion") and not dude:HasTag("butler")
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
if data.attacker.components.combat ~= nil then
            inst.components.combat:SuggestTarget(data.attacker)
                if not data.attacker:HasTag("william") then
    inst.components.combat:ShareTarget(data.attacker, 15, _ShareTargetFn, 5)
                end
        end
    end
end




local function retargetfn(inst)
        local exclude_tags = { "playerghost", "INLIMBO", "abigail", "playermonster" }
        if inst.components.minigame_spectator ~= nil then
                table.insert(exclude_tags, "player") -- prevent spectators from auto-targeting webber
        end

    local playertargets = {}
    for i, v in ipairs(AllPlayers) do
        if v.components.combat.target ~= nil then
            playertargets[v.components.combat.target] = true
        end
    end

    local oneof_tags = {"monster", "hostile"}

    return not inst:IsInLimbo()
        and FindEntity(
                inst,
                20,
                function(guy)
                    return inst.components.combat:CanTarget(guy) and playertargets[guy] or
                    (guy.components.combat.target ~= nil and (guy.components.combat.target:HasTag("player") or guy.components.combat.target:HasTag("willminion")))
                        --inst.components.combat:CanTarget(guy)
                end,
                { "_combat" }, -- see entityreplica.lua
                exclude_tags
--                oneof_tags
            )
        or nil
end

-- v2.0.71: distance from leader beyond which the brute disengages from combat.
-- Mirrors KEEP_WORKING_DIST in the brute brain. When the player runs farther
-- than this, the brute drops its target and retreats to the leader instead of
-- fighting to the death.
local BRUTE_DISENGAGE_DIST = 14
-- v2.0.71: HP fraction at or below which the brute retreats (it used to fight
-- to the death). Tuned for a tank: MK1 1500 HP -> retreat at 375, MK2 2100 ->
-- 525, MK3 2600 -> 650.
local BRUTE_FLEE_HP_PCT = 0.25

local function keeptargetfn(inst, target)
    --give up on dead guys, or guys in the dark, or werepigs
    if not inst.components.combat:CanTarget(target) then
        return false
    end
    -- v2.0.71: disengage when the leader has run too far away. Without this the
    -- brute keeps fighting (and re-acquiring herd members via OnAttacked) even
    -- after the player flees — "tentei correr, não consegui". Dropping the
    -- target at the component level means ChaseAndAttack in the brain has
    -- nothing to chase, and retargetfn won't find new targets once the player
    -- is no longer in combat.
    if inst.components.follower ~= nil and inst.components.follower.leader ~= nil then
        if not inst:IsNear(inst.components.follower.leader, BRUTE_DISENGAGE_DIST) then
            return false
        end
    end
    -- v2.0.71: retreat when critically low on HP so the brute doesn't fight to
    -- the death. The brain's LowHP Retreat node then drives it to the leader
    -- (or away from threats if it has no leader).
    if inst.components.health ~= nil and inst.components.health.maxhealth > 0 then
        local pct = inst.components.health.currenthealth / inst.components.health.maxhealth
        if pct <= BRUTE_FLEE_HP_PCT then
            return false
        end
    end
    return true
end

local function getstatus(inst, viewer)
            return inst.components.fueled:IsEmpty() and "EMPTY"
            or inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .3 and "CRITICALFUEL"
            or inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .6 and "LOWFUEL"
            or "FINE"
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function nodebrisdmg(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return afflicter ~= nil and afflicter:HasTag("quakedebris")
end

local function CanInteract(inst)
    return not inst.components.fueled:IsEmpty()
end

local function onworked(inst)
        if inst:HasTag("alive") then
        inst.sg:GoToState("hit")
        end
end

local function TurnOff(inst, doer, instant)
    local GLOBAL = _G
    inst.on = false

    -- v2.0.69: Drop the follower leader when deactivated.
    -- The DST `follower` component has a built-in catch-up teleport that fires
    -- at the COMPONENT level (in OnUpdate), bypassing the brain entirely. Even
    -- though the brain's `Active` WhileNode gates the Follow behaviour when
    -- inst.on == false, the follower component still has a leader reference and
    -- keeps teleporting the deactivated bot to the leader. Butler/buster avoid
    -- this because their `empty` husk is a fresh entity with no leader; the
    -- brute reuses the same entity, so we must explicitly drop the leader here.
    -- TurnOn re-acquires the leader from the activating player (or nearest
    -- player) on reactivation, and william_acts.lua allows WILLYRAISE when the
    -- leader is nil so the bot can be reactivated after deactivation.
    if inst.components.follower ~= nil then
        inst.components.follower:StopFollowing()
    end

                if inst._taunttask ~= nil then
                    inst._taunttask:Cancel()
            inst._taunttask = nil
        end
            MakeHauntableWork(inst)
        inst:RemoveTag("scarytoprey")
        inst:RemoveTag("alive")
        inst:RemoveTag("ebuild_wrenchable")  -- Prevent wrench interaction when OFF
        inst:AddTag("notarget")

    -- v2.0.81 FIX: Do NOT RemoveComponent("container") on deactivation.
    -- That destroys the items stored inside (DST drops/destroys them when
    -- the component is removed), so reactivating the bot gave back an empty
    -- chest and "itens do chest somen quando ele é desativado/reativado".
    -- Instead, just remove the `container` tag so the chest can't be opened
    -- while the bot is off. The component (and its items) persist through
    -- deactivate/reactivate and through save/load (DST's native container
    -- OnSave/OnLoad handles the items now that the component always exists).
    -- Server-only: the component Close() and tag are server-authoritative.
    if not GLOBAL.TheWorld.ismastersim then return end

    if inst:HasTag("container") then
        inst:RemoveTag("container")
        if inst.components.container then
            pcall(function() inst.components.container:Close() end)
        end
    end

    inst.components.fueled:StopConsuming()
        inst.components.combat:SetTarget(nil)
    inst.components.combat:SetRetargetFunction(nil)
    inst.components.combat:SetKeepTargetFunction(nil)
    inst.sg:GoToState("turn_off")
    
    -- When OFF with no fuel: hammering BREAKS the bot (like buster/ballistic behavior)
    -- When OFF with fuel: no workable — WILLYRAISE action handles reactivation
    if inst.components.fueled:IsEmpty() then
        if inst.components.workable == nil then
            inst:AddComponent("workable")
        end
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)
        inst.components.workable:SetOnWorkCallback(onworked)
        -- Add fuel listener: when fuel is added while OFF, remove HAMMER so WILLYRAISE can activate
        inst._fuel_activate_listener = inst:ListenForEvent("percentusedchange", function()
            if inst.on == false and not inst.components.fueled:IsEmpty() then
                if inst.components.workable then
                    inst:RemoveComponent("workable")
                end
                -- WILLYRAISE action will now handle reactivation
                if inst._fuel_activate_listener then
                    inst:RemoveEventCallback("percentusedchange", inst._fuel_activate_listener)
                    inst._fuel_activate_listener = nil
                end
            end
        end)
    else
        -- Has fuel: remove workable so WILLYRAISE "Activate" action is available
        if inst.components.workable then
            inst:RemoveComponent("workable")
        end
    end
end


local function TurnOn(inst, doer, instant)
    -- BUG FIX 4: Check fuel before turning on
    if inst.components.fueled:IsEmpty() or inst.components.fueled:GetPercent() < 0.1 then
        if doer and doer.components.talker then
            doer.components.talker:Say("Need fuel to activate!")
        end
        return false
    end

    inst.on = true

    -- Set leader to whoever turned the bot on, or nearest player if none
    -- Only for MK2+ which have the follower component
    if inst.components.follower ~= nil then
        if doer ~= nil then
            inst.components.follower:SetLeader(doer)
        elseif inst.components.follower:GetLeader() == nil then
            local player = FindClosestPlayerToInst(inst, 20, true)
            if player ~= nil then
                inst.components.follower:SetLeader(player)
            end
        end
    end

    if inst._taunttask == nil then
    inst._taunttask = inst:DoPeriodicTask(2, TauntCreatures, 0)
        end

    MakeHauntablePanic(inst)
        inst:AddTag("scarytoprey")
        inst:AddTag("alive")
        inst:RemoveTag("notarget")

    -- v2.0.81: re-add the container tag so the chest can be opened again.
    -- The component itself was never removed (just the tag), so items are
    -- still inside. Migration fallback: if the component is missing (bot
    -- was deactivated with pre-v2.0.81 code that RemoveComponent'd it),
    -- re-create an empty one — the old items are already lost, but at
    -- least the chest works going forward.
    if inst.prefab == "williambrute3" and not inst:HasTag("container") then
        inst:AddTag("container")
        if inst.components.container == nil then
            inst:AddComponent("container")
            inst.components.container:WidgetSetup("williambrute3")
            inst.components.container.onopenfn = OnOpen
            inst.components.container.onclosefn = OnClose
            inst.components.container.skipopensnd = true
            inst.components.container.skipclosesnd = true
        end
    end
    
    -- RESTORE: When turning on, remove workable entirely
    -- The WILLYRAISE action (from william_acts.lua) handles right-click deactivation
    -- Remove fuel activate listener since we're turning on
    if inst._fuel_activate_listener then
        inst:RemoveEventCallback("percentusedchange", inst._fuel_activate_listener)
        inst._fuel_activate_listener = nil
    end
    if inst.components.workable then
        inst:RemoveComponent("workable")
    end

    -- Re-add wrenchable tag so wrench works when ON
    inst:AddTag("ebuild_wrenchable")

    inst.components.fueled:StartConsuming()
    -- Debug removed
        inst.components.health:SetInvincible(false)
    inst.components.combat:SetRetargetFunction(2, retargetfn) --Look for leader's target.
    inst.components.combat:SetKeepTargetFunction(keeptargetfn) --Keep attacking while leader is near.

    -- Restart brain so it picks up the new leader state
    inst:SetBrain(brain)

    inst.sg:GoToState("turn_on")
    
    return true
end


local function OnFuelEmpty(inst)
    -- Immediately mark as off to prevent interaction during turn-off animation
    inst.on = false
    inst:AddTag("notarget")
    inst:RemoveTag("scarytoprey")
    inst.components.willyraise:Lower()
end

local function OnAddFuel(inst, fuelvalue, fuelitem)
        -- v2.0.70 FIX: DST's `fueled` component calls ontakefuelfn as
        -- (inst, fuelvalue, ...) — NOT (inst, doer, fuelitem). The previous
        -- signature treated the fuelvalue number as `doer`, which crashed with
        -- "attempt to index local 'doer' (a number value)" whenever fuel was
        -- already full (doer.components.talker was called on a number). Find
        -- the nearest player for feedback instead.
        -- v2.0.63: reject fuel when already full (vanilla-style feedback).
        if inst.components.fueled and inst.components.fueled:IsFull() then
            local player = FindClosestPlayerToInst(inst, 10, true)
            if player and player.components.talker then
                player.components.talker:Say("It's already full!")
            end
            return false
        end
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel")
    if inst.on == false then
        inst.components.willyraise:Rise()
    else
        inst.sg:GoToState("fed")
    end
        return true
end

local function LevelUp(inst, amount)
        if inst.level < 3 and amount ~= nil then
        inst.level = inst.level + amount
        if inst.on == true then
        inst.sg:GoToState("upgraded")
        end
end

        if inst.level > 3 then inst.level = 3 end

        inst:DoTaskInTime(0, function()

    local health_percent = inst.components.health:GetPercent()

                inst:AddTag("level"..inst.level)
--            inst.AnimState:OverrideSymbol("swap_hat", "william_upgrades", "swap_brute"..inst.level)

    inst.components.health:StopRegen()
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN+(inst.level*5), TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health:SetAbsorptionAmount(0+inst.level*0.08)
        end)

end

local function onsave(inst, data)
    data.on = inst.on
    data.level = inst.level
    -- Save leader for all versions (MK1 now has follower too)
    if inst.components.follower and inst.components.follower:GetLeader() then
        data.leader_guid = inst.components.follower:GetLeader().GUID
    end
    data.upgradelevel = inst.upgradelevel or 0
    -- v2.0.91 FIX: Save currentfuel so it persists across save/load.
    -- Without this, the fueled component resets to maxfuel after reload,
    -- giving the bot a free full tank every session.
    if inst.components.fueled ~= nil then
        data.currentfuel = inst.components.fueled.currentfuel
    end
end

local function onload(inst, data)
    if data == nil then return end

    inst.on = data.on
    if data.level ~= nil then
        inst.level = data.level
        if inst.level > 0 then inst:DoTaskInTime(0, LevelUp) end
    end

    -- Restore upgradelevel
    if data.upgradelevel ~= nil then
        inst.upgradelevel = data.upgradelevel
    end

    -- v2.0.91 FIX: Restore currentfuel from save data.
    if data.currentfuel ~= nil and inst.components.fueled ~= nil then
        inst.components.fueled.currentfuel = data.currentfuel
    end

    -- Restore leader (MK1 now has follower too)
    if data.leader_guid ~= nil and inst.components.follower ~= nil then
        inst:DoTaskInTime(0, function()
            local leader = Ents[data.leader_guid]
            if leader ~= nil and leader:IsValid() then
                inst.components.follower:SetLeader(leader)
            end
        end)
    end

    inst:DoTaskInTime(0, function()
        if inst.on == true then
            TurnOn(inst, nil, true)
        else
            TurnOff(inst, nil, true)
        end
    end)
end

-- v2.0.94: Removed dead first onbuilt definition (shadowed by the second at line ~1766)

local PLACER_SCALE = 1.5

    local function fn(inst)
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        inst.level = 0

        inst.DynamicShadow:SetSize(2, 1.25)
        inst.MiniMapEntity:SetIcon("williambrute.tex")

        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("pigman")
    inst.AnimState:SetBuild("william_brute")
        inst.AnimState:PlayAnimation("sit_idle", true)

    MakeCharacterPhysics(inst, 0.9, .5)
    inst.Transform:SetScale(1.7, 1.7, 1.7)

        inst:AddTag("alive")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("brute")
        inst:AddTag("ebuild_wrenchable")

    inst._taunttask = nil
    inst.on = false  -- v2.0.98 FIX: was 'nil', but SG checks 'inst.on == false'. nil ~= false in Lua so the guard failed.

        -- v2.0.36 FIX: hover display on CLIENT (same fix as butler/buster).
        -- displaynamefn has the HIGHEST priority, runs on both server+client
        -- before the ismastersim return, forces hover to use named/replica.
        inst.displaynamefn = function(inst)
            if inst.components.named ~= nil then
                return inst.components.named.name
            end
            if inst.replica.named ~= nil then
                return inst.replica.named.name
            end
            return inst.name
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

    inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.WILLIAM_BRUTE_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.WILLIAM_BRUTE_WALK_SPEED

        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

    inst:SetStateGraph("SGwilliambrute")

        inst:AddComponent("combat")
    inst.components.combat.hiteffectsymbol = "pig_torso"
    inst.components.combat:SetAttackPeriod(TUNING.WILLIAM_BRUTE_ATTACK_PERIOD)
        inst.components.combat:SetRange(TUNING.WILLIAM_BRUTE_ATTACK_RANGE)
    inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BRUTE_DAMAGE)

    MakeMediumBurnableCharacter(inst, "pig_torso")
    MakeMediumFreezableCharacter(inst, "pig_torso")

inst.components.burnable.ignorefuel = true

        inst:ListenForEvent("attacked", OnAttacked)

        inst:AddComponent("willyraise")
    inst.components.willyraise:SetOnRiseFn(TurnOn)
    inst.components.willyraise:SetOnLowerFn(TurnOff)

        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BRUTE_HEALTH)
       -- inst.components.health.nofadeout = true
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health.redirect = nodebrisdmg
                inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("brute")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)

    -- Lightning recharge (refuel, no overcharge)
    inst:ListenForEvent("lightningstrike", function(inst)
        if inst.components.fueled then
            inst.components.fueled:DoDelta(inst.components.fueled.maxfuel * 0.25)
        end
    end)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("fueled")
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled.accepting = true  -- Enable manual fueling (reverted to original)
    inst.components.fueled:InitializeFuelLevel(TUNING.WILLIAM_BRUTE_MAXFUEL)
    inst.components.fueled.bonusmult = 1
    inst.components.fueled:SetDepletedFn(OnFuelEmpty)
    inst.components.fueled:StartConsuming()

    -- v2.0.75: per-material fuel balancing. Sets bonusmult=5 (matches original
    -- mod design), restricts accepted fuels to WILLIAM_FUEL.BRUTE list, and
    -- hooks TakeFuelItem so custom materials (gears, transistor, scrap, etc.)
    -- give explicit fuel values even though they lack a DST `fuel` component.
    local WILLIAM_FUEL = _G.WILLIAM_FUEL
    if WILLIAM_FUEL then
        WILLIAM_FUEL.Setup(inst, WILLIAM_FUEL.BRUTE, 5)
    end

    -- Rain damage (like WX-78) when active
    inst:DoPeriodicTask(1, function(inst)
        if TheWorld.state.israining and inst.on ~= false and inst.components.health then
            inst.components.health:DoDelta(-1, false, "wetness")
        end
    end)

        inst:ListenForEvent("levelup", LevelUp)

    -- v2.0.85 FIX: Drop container items on death (combat, starvation, etc.).
    -- The brute is the only bot with a chest. When it dies (HP reaches 0), the
    -- DST engine removes the entity and destroys everything inside the container.
    -- This listener runs before removal and drops all stored items on the ground
    -- so the player can recover them (Chester Cane, tools, resources, etc.).
    inst:ListenForEvent("death", function(inst)
        if inst.components.container ~= nil then
            inst.components.container:Close()
            inst.components.container:DropEverything()
        end
    end)


        inst:SetBrain(brain)

    inst:AddComponent("knownlocations")

    -- Workable for hammer destruction
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

    -- MK1: Add follower component so brute follows player after craft
    inst:AddComponent("follower")
    inst.components.follower:KeepLeaderOnAttacked()
    inst.components.follower.keepdeadleader = true
    inst.components.follower.keepleaderduringminigame = true

    -- Named component for status display
    inst:AddComponent("named")

    --==================================================================================
    -- REINFORCED CHASSIS UPGRADE: Wrench upgrade spawns williambrute2
    -- 75 scraps total, 5 per hit (15 hits). Progress shown in bot name.
    -- Level 2: storage chest, +1500 HP, +10 DMG, follows player, larger size.
    --==================================================================================
    inst.upgradelevel = 0

    local function UpdateBruteName(inst)
        if inst.prefab == "williambrute2" or inst.prefab == "williambrute3" then return end
        local base = "Brute Bot"
        local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
        local hp = math.floor(inst.components.health.currenthealth)
        local maxhp = math.floor(inst.components.health.maxhealth)
        -- v2.0.40: show MK2 upgrade progress only while in progress (>0).
        local upgrade_str = (inst.upgradelevel and inst.upgradelevel > 0) and (" | Upgrade: " .. inst.upgradelevel .. "/75") or ""
        local displayname = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
        inst.components.named:SetName(displayname)
        inst.name = displayname
        inst.GetDisplayName = function() return displayname end
    end
    UpdateBruteName(inst)
    inst:DoPeriodicTask(2, UpdateBruteName)

    inst:AddComponent("engieworkable")
    inst.components.engieworkable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.engieworkable:SetMaxWork(1)
    inst.components.engieworkable:SetWorkLeft(1)
    inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
        if inst.sg ~= nil then
            inst.sg:GoToState("hit")
        end
    end)
    inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
        if inst.on == false then return end
        _dbg("[DEBUG] ==============================================")
        _dbg("[DEBUG] OnFinishCallback chamado para Brute Bot")
        _dbg("[DEBUG] inst.prefab:", inst.prefab)
        _dbg("[DEBUG] worker.prefab:", worker.prefab)
        _dbg("[DEBUG] worker.name:", worker.name)
        _dbg("[DEBUG] inst.upgradelevel:", inst.upgradelevel)
        _dbg("[DEBUG] inst.upgradelevel_mk3:", inst.upgradelevel_mk3)
        
        inst.components.engieworkable:SetWorkLeft(1)
        -- Use wrench durability
        local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        _dbg("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
        if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
            wrench.components.finiteuses:Use(1)
        end

        -- PRIORITY 1: Repair if HP < 100% (NO skill required, works for MK1/MK2/MK3)
        -- v2.0.67 FIX: previously MK1 with damaged HP went straight to the upgrade
        -- path, which requires the Brute MK. II skill — so early-game players could
        -- NOT repair a damaged MK1 brute. Now repair always runs first when damaged.
        if inst.components.health and inst.components.health.currenthealth < inst.components.health.maxhealth then
            _dbg("[DEBUG] Brute - modo repair (HP < max, qualquer tier)")
            local function IsScrap(item)
                return item.prefab == "scrap"
            end
            local scrapstack = worker.components.inventory:FindItem(IsScrap)
            local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
            if repair_cost > 0 and scrapstack == nil then
                if worker.components.talker then
                    worker.components.talker:Say("Need Scrap Metal to repair!")
                end
                return
            end
            if repair_cost > 0 then
                worker.components.inventory:ConsumeByName("scrap", repair_cost)
            end
            inst.components.health:DoDelta(50)
            inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
            if worker.components.talker then
                worker.components.talker:Say("Repaired 50 HP!")
            end
            return
        end

        -- v2.0.68 FIX: the previous "HP is already full" block here did an early
        -- return when HP >= max, which BLOCKED the upgrade path below. So a brute
        -- with full HP + a player who HAD the MK2 skill would just hear "HP is
        -- already full!" and never upgrade. Removed the block — when HP is full,
        -- we fall through to the upgrade path (skill check + scrap consumption).
        -- The upgrade path has its own messages for missing skill / missing scrap.

        _dbg("[DEBUG] Brute é MK1 - verificando upgrade para MK2")
        _dbg("[DEBUG] Chamando WagstaffHasSkill para wagstaff_brute_evolve")
        _dbg("[DEBUG] worker tem skilltreeupdater?", worker.components.skilltreeupdater ~= nil)
        local has_skill = _G.WagstaffHasSkill(worker, "wagstaff_brute_evolve")
        _dbg("[DEBUG] Resultado de WagstaffHasSkill:", has_skill)
        if not has_skill then
            _dbg("[DEBUG] Skill NÃO encontrada! Abortando upgrade.")
            if worker.components.talker then
                worker.components.talker:Say("Requires Brute Bot MK. II skill!\n(Activate it in the skill tree!)")
            end
            return
        end
        _dbg("[DEBUG] Skill encontrada! Prosseguindo com upgrade...")

        -- Upgrade: scrap metal per wrench hit (5 per hit, 75 total for Mk.II)
        local function IsScrap(item)
            return item.prefab == "scrap"
        end
        local scrapstack = worker.components.inventory:FindItem(IsScrap)
        local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
        if upgrade_cost > 0 and scrapstack == nil then
            if worker.components.talker then
                worker.components.talker:Say("Need Scrap Metal!")
            end
            return
        end
        if upgrade_cost > 0 then
            worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
        end
        inst.upgradelevel = inst.upgradelevel + 5
        UpdateBruteName(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

        if inst.upgradelevel >= 75 then
            inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
            if worker.components.talker then
                worker.components.talker:Say("Reinforced Chassis complete!")
            end

            -- Spawn upgraded bot
            local pt = inst:GetPosition()
            local newbot = SpawnPrefab("williambrute2")
            if newbot ~= nil then
                newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                newbot.Transform:SetRotation(inst.Transform:GetRotation())

                -- Transfer fuel
                if inst.components.fueled and newbot.components.fueled then
                    newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                end
                -- Transfer health
                if inst.components.health and newbot.components.health then
                    newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                end
                -- Transfer level
                newbot.level = inst.level

                -- Transfer ON state and turn on automatically if original was on
                newbot.on = inst.on
                if inst.on == true and newbot.components.willyraise ~= nil then
                    newbot.components.willyraise:Rise(worker)
                end

                -- Set leader and reinit brain for MK2+
                if newbot.components.follower ~= nil then
                    newbot.components.follower:SetLeader(worker)
                    newbot:SetBrain(brain)
                end

                -- Spawn FX (craft-like effect)
                local fx = SpawnPrefab("small_puff")
                fx.Transform:SetPosition(pt.x, pt.y, pt.z)
                inst.SoundEmitter:PlaySound("dontstarve/common/craftable")
            end

            inst:Remove()
        end
    end)

    -- Save/load upgrade progress is now handled by base onsave/onload

    inst.OnSave = onsave
    inst.OnLoad = onload

        return inst
    end


    local function gary(inst)
        local inst = fn()

    inst:SetPrefabNameOverride("williambrute")
            inst.AnimState:OverrideSymbol("swap_hat", "william_garyhat_swap", "swap_hat")

    inst:AddTag("_named")

        if not TheWorld.ismastersim then
            return inst
        end
    inst:RemoveTag("_named")
    if not inst.components.named then
        inst:AddComponent("named")
    end
    local ok, err = pcall(function() inst.components.named:SetName("Gary") end)
    if not ok then
        inst.name = "Gary"
        inst.GetDisplayName = function() return "Gary" end
    end
        return inst
    end

    --==================================================================================
    -- BRUTE BOT v2: Upgraded version with storage chest, +1500 HP, +10 DMG,
    -- follows player, larger size. Spawned by wrench upgrade on original brute.
    --==================================================================================
    local function fn2(inst)
        local inst = fn()

        inst.Transform:SetScale(2.3, 2.3, 2.3)

        -- Tintura cinza acinzentada para diferenciar nível 2
        inst.AnimState:SetMultColour(0.8, 0.8, 0.85, 1)

        inst:AddTag("brute_upgraded")

        if not TheWorld.ismastersim then
            return inst
        end

        -- MK2: Follower component already added by fn() - no need to add again
        -- Just ensure leader is set if upgrading from MK1
        if inst.components.follower:GetLeader() == nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            local players = TheSim:FindEntities(x, y, z, 15, {"player"})
            local closest = nil
            local closest_dist = math.huge
            for _, p in ipairs(players) do
                local dist = inst:GetDistanceSqToInst(p)
                if dist < closest_dist then
                    closest = p
                    closest_dist = dist
                end
            end
            if closest ~= nil then
                inst.components.follower:SetLeader(closest)
            end
        end

        -- Override base health and damage
        -- v2.0.39: HP bonus +1000 -> +600 (still the tankiest bot, but not OP).
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BRUTE_HEALTH + 600)
        inst.components.health:DoDelta(600)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BRUTE_DAMAGE + 10)

        -- v2.0.88: PASSIVE TAUNT — Brute MK2+ periodically forces nearby enemies
        -- to target it instead of the player. The brute's role is "tank/juggernaut"
        -- but with only 27 base damage it couldn't hold aggro through damage alone.
        -- This taunt makes the brute actually protect the player by drawing attacks.
        -- Mechanics: every 2 seconds, all enemies within radius 6 that are currently
        -- targeting the brute's leader (or any nearby player) are forced to retarget
        -- to the brute. Enemies already targeting the brute are left alone.
        -- MK2: radius 6, MK3: radius 8 (set in fn3).
        inst._taunt_radius = 6
        inst:DoPeriodicTask(2, function()
            if inst.on == false then return end
            if inst.components.health:IsDead() then return end
            local x, y, z = inst.Transform:GetWorldPosition()
            local radius = inst._taunt_radius or 6
            local enemies = TheSim:FindEntities(x, y, z, radius, {"_combat"}, {"INLIMBO", "notarget", "wall", "companion", "player"})
            local leader = inst.components.follower and inst.components.follower:GetLeader()
            for _, enemy in ipairs(enemies) do
                if enemy.components.combat and enemy.components.combat.target then
                    local target = enemy.components.combat.target
                    -- Only taunt enemies targeting the leader or nearby players
                    if target:HasTag("player") or (leader and target == leader) then
                        enemy.components.combat:SuggestTarget(inst)
                    end
                end
            end
        end)

        -- CELESTIAL POSSESSION: "Lunar Guardian" - Aura fogo AZUL + Enlightenment + Cor pulsante
        inst._celestial_light = nil
        inst._aura_fx = nil
        inst._lunar_aura = nil
        inst._shadow_fx = nil
        inst._celestial_pulse = 0
        
        -- Affinity pulse (shared module, MK3 only)

        inst:DoPeriodicTask(3, function()
            if inst.prefab == "williambrute3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Add planar immunity
                inst:AddTag("planardefense")
                
                -- Light própria azul lunar (suave)
                if inst._celestial_light == nil then
                    inst.entity:AddLight()
                    inst._celestial_light = true
                end
                if inst.Light then
                    inst.Light:SetRadius(2.5)
                    inst.Light:SetIntensity(0.4)
                    inst.Light:SetFalloff(0.8)
                    inst.Light:SetColour(0.4, 0.7, 1) -- Azul lunar
                    inst.Light:Enable(true)
                end
                
                -- AURA BOUNCER - só quando ativo (nil = inicialmente ativo)
                if inst.on ~= false and (inst._aura_fx == nil or not inst._aura_fx:IsValid()) then
                    inst._aura_fx = SpawnPrefab("bot_aura_bouncer")
                    if inst._aura_fx then
                        inst._aura_fx._parent = inst
                    end
                end
                
                -- Aura enlightenment da Ilha Lunar (partículas ao redor)
                if inst._lunar_aura == nil or not inst._lunar_aura:IsValid() then
                    inst._lunar_aura = SpawnPrefab("lunarhail")
                    if inst._lunar_aura then
                        inst._lunar_aura.entity:SetParent(inst.entity)
                        inst._lunar_aura.Transform:SetPosition(0, 0, 0)
                        inst._lunar_aura.Transform:SetScale(0.6, 0.6, 0.6)
                    end
                end
                
                
                -- Remove shadow FX
                if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                    inst._shadow_fx:Remove()
                    inst._shadow_fx = nil
                end
            else
                -- Remove effects
                inst:RemoveTag("planardefense")
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                    inst._aura_fx:Remove()
                    inst._aura_fx = nil
                end
                if inst._lunar_aura ~= nil and inst._lunar_aura:IsValid() then
                    inst._lunar_aura:Remove()
                    inst._lunar_aura = nil
                end
            end
            
            -- SHADOW POSSESSION: "Void Juggernaut" - nightmare fuel particles (MK3 only)
            if inst.prefab == "williambrute3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                if inst._shadow_fx == nil or not inst._shadow_fx:IsValid() then
                    inst._shadow_fx = SpawnPrefab("shadow_puff_large_front")
                    if inst._shadow_fx then
                        inst._shadow_fx.entity:SetParent(inst.entity)
                        inst._shadow_fx.Transform:SetPosition(0, 0, 0)
                        inst._shadow_fx.Transform:SetScale(1.0, 1.0, 1.0)
                        if inst._shadow_fx.SoundEmitter then
                            inst._shadow_fx.SoundEmitter:KillAllSounds()
                        end
                    end
                end
                -- Remove celestial FX
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                -- v2.0.94: Removed dead _lunar_fire cleanup — this variable is
                -- never initialized anywhere. If lunar fire FX is needed in the
                -- future, create it in the celestial path and store it here.
                if inst._lunar_aura ~= nil and inst._lunar_aura:IsValid() then
                    inst._lunar_aura:Remove()
                    inst._lunar_aura = nil
                end
            else
                if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                    inst._shadow_fx:Remove()
                    inst._shadow_fx = nil
                end
            end
        end)
        
        -- Fire counter-attack: deal 30 fire damage to the attacker only when hit
        local old_OnAttacked = OnAttacked
        local function OnAttackedMK2(inst, data)
            old_OnAttacked(inst, data)
            if inst.prefab == "williambrute3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Only counter-attack the specific enemy that hit us
                if data and data.attacker and data.attacker:IsValid() then
                    local attacker = data.attacker
                    if attacker.components.health and not attacker.components.health:IsDead() then
                        -- v2.0.39: 50 -> 30 fire damage (was too punishing, back to v2.0.14 value).
                        attacker.components.health:DoDelta(-30, false, "fire")
                        -- Celestial FX on attacker (azul)
                        local fx = SpawnPrefab("electrichitsparks")
                        if fx then
                            fx.Transform:SetPosition(attacker.Transform:GetWorldPosition())
                            -- Pintar de azul celestial (se tiver AnimState)
                            if fx.AnimState then
                                fx.AnimState:SetMultColour(0.3, 0.6, 1, 1)
                                fx.AnimState:SetAddColour(0.2, 0.3, 0.5, 0)
                            end
                        end
                    end
                end

                -- v2.0.50: CELESTIAL "Lunar Empowerment" AOE — mirrors the shadow
                -- Brute's "Void Weaken" AOE. When hit, emits a lunar pulse that
                -- EMPOWERS nearby allies (+25% damage dealt for 4s, 12s cooldown).
                -- v2.0.50 TUNE: reduced +50% -> +25%. With multiple allies
                -- (player + 4 bots) the +50% stacked up to too much total team
                -- damage; +25% per ally is still strong but not OP.
                -- Same radius (6), duration (4s), cooldown (12s) as shadow weaken.
                local x, y, z = inst.Transform:GetWorldPosition()
                local do_buff = not inst._lunar_pulse_cooldown

                if do_buff then
                    inst._lunar_pulse_cooldown = true
                    inst:DoTaskInTime(12, function() inst._lunar_pulse_cooldown = nil end)

                    -- Central lunar burst FX: celestial-blue sparkle explosion.
                    -- v2.0.50: bigger scale (6 -> 8) so it reads as an explosion,
                    -- but not exaggerated (kept under 10).
                    if inst.SoundEmitter then
                        inst.SoundEmitter:PlaySound("dontstarve/common/lunar_sparkle")
                    end
                    local burst_fx = SpawnPrefab("sparklefx")
                    if burst_fx then
                        burst_fx.Transform:SetPosition(x, y + 0.5, z)
                        burst_fx.Transform:SetScale(8.0, 8.0, 8.0)
                        if burst_fx.AnimState then
                            burst_fx.AnimState:SetMultColour(0.4, 0.7, 1.0, 1)
                            burst_fx.AnimState:SetAddColour(0.3, 0.4, 0.6, 0)
                        end
                        burst_fx:DoTaskInTime(1.5, function()
                            if burst_fx:IsValid() then burst_fx:Remove() end
                        end)
                    end

                    -- Find and empower allies within radius 6
                    -- Allies = player + companion bots + willminion (all wagstaff bots)
                    local ents = TheSim:FindEntities(x, y, z, 6, nil, {"INLIMBO"})
                    for _, ent in ipairs(ents) do
                        if ent:IsValid() and ent.components.combat
                            and (ent:HasTag("player") or ent:HasTag("companion") or ent:HasTag("willminion")) then
                            -- +25% damage dealt for 4 seconds (v2.0.50: was +50%)
                            if ent.components.combat.externaldamagemultipliers then
                                ent.components.combat.externaldamagemultipliers:SetModifier(inst, 1.25)
                                ent:DoTaskInTime(4, function()
                                    if ent:IsValid() and ent.components.combat and ent.components.combat.externaldamagemultipliers then
                                        ent.components.combat.externaldamagemultipliers:RemoveModifier(inst)
                                    end
                                end)
                            end
                            -- Small celestial sparkle on each buffed ally
                            local ally_fx = SpawnPrefab("sparklefx")
                            if ally_fx and ally_fx.AnimState then
                                ally_fx.Transform:SetPosition(ent.Transform:GetWorldPosition())
                                ally_fx.AnimState:SetMultColour(0.4, 0.7, 1.0, 1)
                                ally_fx:DoTaskInTime(1, function() if ally_fx:IsValid() then ally_fx:Remove() end end)
                            end
                        end
                    end
                end
            end

            -- SHADOW POSSESSION: Void Weaken - retaliatory AOE damage reduction + shadow damage on hit (MK3 only)
            if inst.prefab == "williambrute3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                -- Shadow damage to the attacker only (no cooldown) - mirrors celestial counter-attack
                if data and data.attacker and data.attacker:IsValid() then
                    local attacker = data.attacker
                    if attacker.components.health and not attacker.components.health:IsDead() then
                        -- v2.0.15: 15 -> 25 shadow damage (proportional to celestial 30->50 buff)
                        attacker.components.health:DoDelta(-25, false, "shadow")
                        -- Shadow FX on attacker
                        local fx = SpawnPrefab("shadow_puff")
                        if fx then
                            fx.Transform:SetPosition(attacker.Transform:GetWorldPosition())
                        end
                    end
                end

                local x, y, z = inst.Transform:GetWorldPosition()
                local do_debuff = not inst._void_pulse_cooldown

                if do_debuff then
                    inst._void_pulse_cooldown = true
                    -- v2.0.39: cooldown 8s -> 12s (AOE -50% damage was too frequent).
                    inst:DoTaskInTime(12, function() inst._void_pulse_cooldown = nil end)

                    -- Central void burst FX at Bouncer: massive shadow_puff_large_front explosion
                    if inst.SoundEmitter then
                        inst.SoundEmitter:PlaySound("dontstarve/common/nightmarecreature_spawn")
                    end
                    local burst_fx = SpawnPrefab("shadow_puff_large_front")
                    if burst_fx then
                        burst_fx.Transform:SetPosition(x, y + 0.5, z)
                        burst_fx.Transform:SetScale(6.0, 6.0, 6.0)
                        burst_fx:DoTaskInTime(1.5, function()
                            if burst_fx:IsValid() then burst_fx:Remove() end
                        end)
                    end

                    -- Find and weaken enemies within radius 6
                    local ents = TheSim:FindEntities(x, y, z, 6, nil, {"INLIMBO", "player", "companion", "willminion", "epic", "miniboss", "deer"})
                    for _, ent in ipairs(ents) do
                        if ent ~= inst and ent ~= data.attacker and ent:IsValid() and ent.components.combat then
                            -- Reduce damage dealt by 50%
                            if ent.components.combat.externaldamagemultipliers then
                                ent.components.combat.externaldamagemultipliers:SetModifier(inst, 0.5)
                                ent:DoTaskInTime(4, function()
                                    if ent:IsValid() and ent.components.combat and ent.components.combat.externaldamagemultipliers then
                                        ent.components.combat.externaldamagemultipliers:RemoveModifier(inst)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
        inst:RemoveEventCallback("attacked", OnAttacked)
        inst:ListenForEvent("attacked", OnAttackedMK2)

        -- SHADOW POSSESSION: shadow creatures target priority during dusk
        -- v2.0.39: REMOVED planardefense from Shadow path. planardefense is now
        -- EXCLUSIVELY a Celestial trait (line 838) — this creates a real trade-off:
        --   Celestial Brute = anti-planar tank (imune a dano planar de lunar weapons)
        --   Shadow Brute    = anti-shadow tank (shadowlure + counter shadow + Void Weaken)
        -- Before, the Shadow Brute had BOTH planar immunity AND shadow attraction,
        -- making it strictly better than the Celestial version. Now each affinity
        -- has a clear defensive niche.
        inst:DoPeriodicTask(5, function()
            if TheWorld.state.isdusk and OwnerHasShadow(inst) then
                -- Add groundpound immune (keeps Shadow Brute viable vs Deer Clops etc.)
                inst:AddTag("groundpoundimmune")
                -- Attract shadow creatures as absolute priority target
                inst:AddTag("shadowlure")
                inst:AddTag("shadowcreature_target")
            else
                -- Remove effects when not dusk
                inst:RemoveTag("groundpoundimmune")
                inst:RemoveTag("shadowlure")
                inst:RemoveTag("shadowcreature_target")
            end
        end)

        -- Named with status (v2.0.36: upgrade progress removed from name)
        inst.upgradelevel_mk3 = 0
        local function UpdateBrute2Name(inst)
            if inst.prefab == "williambrute3" then return end
            local base = "Brute Bot Mk.II"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            -- v2.0.40: show MK3 upgrade progress only while in progress (>0).
            local upgrade_str = (inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0) and (" | Upgrade: " .. inst.upgradelevel_mk3 .. "/90") or ""
            local displayname = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str
            inst.components.named:SetName(displayname)
            inst.name = displayname
            inst.GetDisplayName = function() return displayname end
        end
        UpdateBrute2Name(inst)
        inst:DoPeriodicTask(2, UpdateBrute2Name)

        -- Mk.II: Repair + Upgrade in one engieworkable
        if inst.components.engieworkable == nil then
            inst:AddComponent("engieworkable")
        end
        inst.components.engieworkable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.engieworkable:SetMaxWork(1)
        inst.components.engieworkable:SetWorkLeft(1)
        inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            if inst.on == false then return end
            _dbg("[DEBUG] ==============================================")
            _dbg("[DEBUG] OnFinishCallback chamado para Brute Bot MK2")
            _dbg("[DEBUG] inst.prefab:", inst.prefab)
            _dbg("[DEBUG] worker.prefab:", worker.prefab)
            _dbg("[DEBUG] inst.upgradelevel_mk3:", inst.upgradelevel_mk3)
            
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            _dbg("[DEBUG] wrench:", wrench and wrench.prefab or "nil")
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- Check if can upgrade first (only if player has MK3 skill AND not capped)
            -- v2.0.67 FIX: previously this was 'if not has_mk3_skill then return end'
            -- which BLOCKED repair of a damaged MK2 brute when the player didn't have
            -- the MK3 skill. Now we only attempt the upgrade when the skill is learned;
            -- otherwise we fall through to the repair path below (same pattern as
            -- buster/ballistic MK2).
            _dbg("[DEBUG] Verificando skill wagstaff_brute_mk3...")
            local has_mk3_skill = _G.WagstaffHasSkill(worker, "wagstaff_brute_mk3")
            _dbg("[DEBUG] Tem skill MK3?", has_mk3_skill)
            _dbg("[DEBUG] upgradelevel_mk3 atual:", inst.upgradelevel_mk3)
            if has_mk3_skill and inst.upgradelevel_mk3 < 90 then
                _dbg("[DEBUG] Tentando upgrade para MK3...")
                -- Try to upgrade
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
                if upgrade_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal!")
                    end
                    return
                end
                if upgrade_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
                end
                inst.upgradelevel_mk3 = inst.upgradelevel_mk3 + 5
                UpdateBrute2Name(inst)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")

                if inst.upgradelevel_mk3 >= 90 then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                    if worker.components.talker then
                        worker.components.talker:Say("Mk.III Complete!")
                    end

                    -- Spawn upgraded bot
                    local pt = inst:GetPosition()
                    local newbot = SpawnPrefab("williambrute3")
                    if newbot ~= nil then
                        newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                        newbot.Transform:SetRotation(inst.Transform:GetRotation())

                        -- Transfer fuel
                        if inst.components.fueled and newbot.components.fueled then
                            newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                        end
                        -- Transfer health
                        if inst.components.health and newbot.components.health then
                            newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                        end
                        -- Transfer level
                        newbot.level = inst.level

                        -- Transfer ON state and turn on automatically if original was on
                        newbot.on = inst.on
                        if inst.on == true and newbot.components.willyraise ~= nil then
                            newbot.components.willyraise:Rise(worker)
                        end

                        -- Set leader and reinit brain
                        if newbot.components.follower ~= nil then
                            -- v2.0.90 FIX: Use SetLeader() instead of direct assignment.
                            -- Direct .leader = bypasses the petleash registration,
                            -- causing pet count mismatch and teleport-on-rollback failures.
                            newbot.components.follower:SetLeader(worker)
                            newbot:SetBrain(brain)
                        end

                        -- Spawn FX (craft-like effect)
                        local fx = SpawnPrefab("small_puff")
                        fx.Transform:SetPosition(pt.x, pt.y, pt.z)
                        inst.SoundEmitter:PlaySound("dontstarve/common/craftable")
                    end

                    inst:Remove()
                end
                return
            end

            -- If not upgrading, try repair
            if inst.components.health and inst.components.health.currenthealth >= inst.components.health.maxhealth then
                if worker.components.talker then
                    worker.components.talker:Say("HP is already full!")
                end
            else
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                if repair_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
            end
        end)

        -- Workable for hammer deactivation (same as MK1)
        if inst.components.workable == nil then
            inst:AddComponent("workable")
        end
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)
        inst.components.workable:SetOnWorkCallback(onworked)

        -- Save/load for brute2 upgrade progress
        local old_OnSaveBrute2 = inst.OnSave
        local function OnSaveBrute2WithUpgrade(inst, data)
            if old_OnSaveBrute2 then
                old_OnSaveBrute2(inst, data)
            end
            if inst.on ~= nil then
                data.on = inst.on
            end
            if inst.level ~= nil then
                data.level = inst.level
            end
            data.upgradelevel_mk3 = inst.upgradelevel_mk3
        end
        local old_OnLoadBrute2 = inst.OnLoad
        local function OnLoadBrute2WithUpgrade(inst, data)
            if old_OnLoadBrute2 then
                old_OnLoadBrute2(inst, data)
            end
            if data then
                inst.upgradelevel_mk3 = data.upgradelevel_mk3 or 0
                UpdateBrute2Name(inst)
            end
            if data ~= nil and data.on ~= nil then
                inst.on = data.on
            end
            if data ~= nil and data.level ~= nil then
                inst.level = data.level
                if inst.level > 0 then inst:DoTaskInTime(0, LevelUp) end
            end
            
            -- v2.0.81 FIX: same as TurnOff — do NOT RemoveComponent("container")
            -- when loading a deactivated MK3. That destroys the items inside.
            -- Just remove the tag so the chest can't be opened while off.
            -- The component (with items) persists and DST's native container
            -- OnSave/OnLoad will handle the items on future saves.
            if inst.on == false and inst:HasTag("container") then
                inst:RemoveTag("container")
                if inst.components.container then
                    pcall(function() inst.components.container:Close() end)
                end
            end
            
            if inst.on == false then
                -- Remove ebuild_wrenchable tag to prevent wrench on deactivated bot
                inst:RemoveTag("ebuild_wrenchable")
                -- Same as TurnOff: HAMMER only when no fuel, otherwise WILLYRAISE handles it
                if inst.components.fueled:IsEmpty() then
                    if inst.components.workable == nil then
                        inst:AddComponent("workable")
                    end
                    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
                    inst.components.workable:SetWorkLeft(4)
                    inst.components.workable:SetOnFinishCallback(OnHammered)
                    inst.components.workable:SetOnWorkCallback(onworked)
                    inst._fuel_activate_listener = inst:ListenForEvent("percentusedchange", function()
                        if inst.on == false and not inst.components.fueled:IsEmpty() then
                            if inst.components.workable then
                                inst:RemoveComponent("workable")
                            end
                            if inst._fuel_activate_listener then
                                inst:RemoveEventCallback("percentusedchange", inst._fuel_activate_listener)
                                inst._fuel_activate_listener = nil
                            end
                        end
                    end)
                else
                    if inst.components.workable then
                        inst:RemoveComponent("workable")
                    end
                end
            end
            -- NOTE: TurnOn/TurnOff is already called by base onload (via DoTaskInTime(0)).
            -- We do NOT duplicate it here to avoid double brain creation and SG interruption
            -- which caused ~1 min follow delay on reload.
        end
        inst.OnSave = OnSaveBrute2WithUpgrade
        inst.OnLoad = OnLoadBrute2WithUpgrade

        -- Clean up celestial FX on removal
        inst:ListenForEvent("onremove", function()
            if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                inst._aura_fx:Remove()
                inst._aura_fx = nil
            end
            if inst._lunar_aura ~= nil and inst._lunar_aura:IsValid() then
                inst._lunar_aura:Remove()
                inst._lunar_aura = nil
            end
            -- v2.0.94: Removed dead _ice_fx cleanup — never initialized
            if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                inst._shadow_fx:Remove()
                inst._shadow_fx = nil
            end
            if inst.Light then
                inst.Light:Enable(false)
            end
        end)

        return inst
    end

    --==================================================================================
    -- BRUTE BOT v3: Upgraded version with storage chest, +2000 HP, +20 DMG,
    -- follows player, larger size. Spawned by wrench upgrade on brute2.
    -- Requires Brute Bot MK.III skill
    --==================================================================================
    local function fn3(inst)
        local inst = fn2()

        inst:AddTag("brute_upgraded_mk3")

        if not TheWorld.ismastersim then
            return inst
        end

        -- v2.0.53 FIX: MK3 HP was still using the OLD MK2 bonus (+1000) baked
        -- into the +1500 total. v2.0.39 nerfed the MK2 HP bonus from +1000 to
        -- +600, but fn3 kept +1500 over base (= old +1000 MK2 + +500 MK3 incr).
        -- Now correctly: base + MK2 bonus (600) + MK3 increment (500) = +1100.
        -- DMG unchanged (+15 over base = +5 over MK2's +10).
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BRUTE_HEALTH + 1100)
        inst.components.health:SetCurrentHealth(inst.components.health.maxhealth)
        inst.components.combat:SetDefaultDamage(TUNING.WILLIAM_BRUTE_DAMAGE + 15)

        -- v2.0.88: MK3 taunt radius is larger (8 vs MK2's 6)
        inst._taunt_radius = 8

        -- Affinity pulse (MK3 only)
        -- v2.0.55: Phase-gate the pulse to match the affinity effect's active
        -- window. The brute's affinity taunt/bonus only fires during
        -- DAY+celestial or DUSK+shadow (see taunt + damage checks). Without
        -- this gate the pulse lit up during battle even in the "weak" passive
        -- phase, which was visually misleading.
        AffinityPulse.Setup(inst, GetOwner, {
            phase_check = function(inst, owner)
                if not (owner and owner:IsValid()) then return false end
                local celestial = owner:HasTag("wagstaff_celestial_possession")
                local shadow    = owner:HasTag("wagstaff_shadow_possession")
                return (TheWorld.state.isday and celestial)
                    or (TheWorld.state.isdusk and shadow)
            end,
        })

        -- Container (chest) for MK3 - ÚNICA adição do MK.III
        inst:AddTag("container")
        inst:AddComponent("container")
        inst.components.container:WidgetSetup("williambrute3")
        inst.components.container.onopenfn = OnOpen
        inst.components.container.onclosefn = OnClose
        inst.components.container.skipopensnd = true
        inst.components.container.skipclosesnd = true

        -- Override engieworkable to only do repair (no more upgrades)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            if inst.on == false then return end
            inst.components.engieworkable:SetWorkLeft(1)
            -- Use wrench durability
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end
            if inst.components.health and inst.components.health.currenthealth >= inst.components.health.maxhealth then
                if worker.components.talker then
                    worker.components.talker:Say("HP is already full!")
                end
            else
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                if repair_cost > 0 and scrapstack == nil then
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
            end
        end)

        -- Workable for hammer deactivation (same as MK1)
        if inst.components.workable == nil then
            inst:AddComponent("workable")
        end
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)
        inst.components.workable:SetOnWorkCallback(onworked)

        -- Override OnSave/OnLoad to ensure MK3 state is preserved
        local old_OnSaveBrute3 = inst.OnSave
        local function OnSaveBrute3(inst, data)
            if old_OnSaveBrute3 then
                old_OnSaveBrute3(inst, data)
            end
            data.is_mk3 = true
        end
        
        inst.OnSave = OnSaveBrute3
        
        local old_OnLoadBrute3 = inst.OnLoad  -- captures OnLoadBrute2WithUpgrade
        inst.OnLoad = function(inst2, data)
            -- Call the MK2→base onload chain first
            if old_OnLoadBrute3 then old_OnLoadBrute3(inst2, data) end
            if not TheWorld.ismastersim then return end
            
            -- Restore MK3 container if it was removed during load (bot was OFF when saved)
            if data and data.is_mk3 and not inst2:HasTag("container") then
                inst2:AddTag("container")
                if inst2.components.container == nil then
                    inst2:AddComponent("container")
                    inst2.components.container:WidgetSetup("williambrute3")
                    inst2.components.container.onopenfn = OnOpen
                    inst2.components.container.onclosefn = OnClose
                    inst2.components.container.skipopensnd = true
                    inst2.components.container.skipclosesnd = true
                end
            end
            
            -- Restore affinity FX (celestial/shadow) after load
            inst2:DoTaskInTime(0, function()
                if not inst2:IsValid() then return end
                local owner = inst2.components.follower and inst2.components.follower:GetLeader()
                local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
                local shadow = owner and owner:HasTag("wagstaff_shadow_possession")
                if TheWorld.state.isday and celestial then
                    if inst2._celestial_light == nil then inst2.entity:AddLight(); inst2._celestial_light = true end
                    if inst2.Light then inst2.Light:Enable(true); inst2.Light:SetRadius(2.5); inst2.Light:SetIntensity(0.4); inst2.Light:SetColour(0.4,0.7,1) end
                    if inst2.on ~= false and (inst2._aura_fx == nil or not inst2._aura_fx:IsValid()) then
                        inst2._aura_fx = SpawnPrefab("bot_aura_bouncer")
                        if inst2._aura_fx then inst2._aura_fx._parent = inst2 end
                    end
                    if inst2._lunar_aura == nil or not inst2._lunar_aura:IsValid() then
                        inst2._lunar_aura = SpawnPrefab("lunarhail")
                        if inst2._lunar_aura then inst2._lunar_aura.entity:SetParent(inst2.entity) end
                    end
                end
                if TheWorld.state.isdusk and shadow then
                    if inst2._shadow_fx == nil or not inst2._shadow_fx:IsValid() then
                        inst2._shadow_fx = SpawnPrefab("shadow_puff_large_front")
                        if inst2._shadow_fx then inst2._shadow_fx.entity:SetParent(inst2.entity) end
                    end
                end
            end)
        end
        
        -- Named status display for MK3
        if inst.components.named == nil then
            inst:AddComponent("named")
        end
        local function UpdateBrute3Name(inst)
            local base = "Brute Bot Mk.III"
            local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
            local hp = math.floor(inst.components.health.currenthealth)
            local maxhp = math.floor(inst.components.health.maxhealth)
            local displayname = base .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp
            inst.components.named:SetName(displayname)
            inst.name = displayname
            inst.GetDisplayName = function() return displayname end
        end
        UpdateBrute3Name(inst)
        inst:DoPeriodicTask(2, UpdateBrute3Name)

        return inst
    end


-- v2.0.86: EMPTY brute husk. The stategraph's "powerdown" state (SGwilliambrute.lua:311)
-- calls SpawnPrefab("williambrute_empty") — without this registered prefab, the spawn
-- returns nil and the brute would never be removed (broken entity stuck in the world).
-- Currently TurnOff uses the "turn_off" state instead of "powerdown", so this code path
-- is rarely hit, but registering it prevents a crash if it ever is.
local function empty(inst)
    local inst = fn()

    inst.AnimState:SetBank("william_brute")
    inst.AnimState:PlayAnimation("sit_idle", true)
    inst.Transform:SetScale(1.7, 1.7, 1.7)

    MakeCharacterPhysics(inst, 80, .25)
    inst.Physics:SetFriction(1)

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

    inst:AddTag("notarget")

    -- Mark husk as "off" so the brain's Deactivated gate keeps it from
    -- following/teleporting to the leader.
    inst.on = false

    -- v2.0.90 FIX: Stop fuel consumption on the empty husk. The fn() base
    -- function calls fueled:StartConsuming(), which drains fuel while the
    -- bot sits idle as a husk. This makes reactivation much harder because
    -- fuel the player adds gets consumed immediately. Only active bots
    -- should consume fuel.
    if inst.components.fueled then
        inst.components.fueled:StopConsuming()
    end

    inst.components.fueled.accepting = true

    -- v2.0.91 FIX: Save/load husk state so currentfuel and level persist
    -- across save/load. Without this, the fueled component resets to maxfuel
    -- after reload, and the brute's MK level is lost.
    local function OnSaveEmptyBrute(inst, data)
        if inst.components.fueled ~= nil then
            data.currentfuel = inst.components.fueled.currentfuel
        end
        data.level = inst.level
        data.upgradelevel = inst.upgradelevel or 0
    end

    local function OnLoadEmptyBrute(inst, data)
        if data == nil then return end
        if data.currentfuel ~= nil and inst.components.fueled ~= nil then
            inst.components.fueled.currentfuel = data.currentfuel
        end
        if data.level ~= nil then
            inst.level = data.level
        end
        if data.upgradelevel ~= nil then
            inst.upgradelevel = data.upgradelevel
        end
    end

    inst.OnSave = OnSaveEmptyBrute
    inst.OnLoad = OnLoadEmptyBrute

    MakeHauntableWork(inst)

    return inst
end

local function onbuilt(inst, builder)
        local spawn_type = math.random(1, 100) == 100 and "williambrute_gary" or "williambrute"
    local robot = SpawnPrefab(spawn_type)
        if robot ~= nil then
    robot.Transform:SetPosition(inst.Transform:GetWorldPosition())
    robot.components.knownlocations:RememberLocation("home", inst:GetPosition())
    -- Pass builder as doer so TurnOn sets leader correctly
    -- Rise(doer, instant) -> self.onrisefn(self.inst, doer)
    robot.components.willyraise:Rise(builder)
        robot.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
                    local x, y, z = robot.Transform:GetWorldPosition()
    SpawnPrefab("maxwell_smoke").Transform:SetPosition(x, y, z)
    robot.maker = builder and builder.name or "unknown"
        inst:Remove()
        end
end

    local function builder()
        local inst = CreateEntity()

        inst.entity:AddTransform()

        inst:AddTag("CLASSIFIED")

        --[[Non-networked entity]]
        inst.persists = false

        --Auto-remove if not spawned by builder
        inst:DoTaskInTime(0, inst.Remove)

        if not TheWorld.ismastersim then
            return inst
        end


        inst.OnBuiltFn = onbuilt

        return inst
    end


local function placer_postinit_fn(inst)

    local placer2 = CreateEntity()

    --[[Non-networked entity]]
    placer2.entity:SetCanSleep(false)
    placer2.persists = false

    placer2.entity:AddTransform()
    placer2.entity:AddAnimState()

    placer2:AddTag("CLASSIFIED")
    placer2:AddTag("NOCLICK")
    placer2:AddTag("placer")

    local s = 1.7 / PLACER_SCALE
    placer2.Transform:SetScale(s, s, s)

    placer2.AnimState:SetBank("william_brute")
    placer2.AnimState:SetBuild("william_brute")
    placer2.AnimState:PlayAnimation("sit_idle", true)
    placer2.AnimState:SetLightOverride(1)

    placer2.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(placer2)
end


    return Prefab("williambrute", fn, assets, prefabs),
    Prefab("williambrute2", fn2, assets, prefabs),
    Prefab("williambrute3", fn3, assets, prefabs),
    Prefab("williambrute_gary", gary, assets, prefabs),
    Prefab("williambrute_empty", empty, assets, prefabs),
    MakePlacer("williambrute_placer", "william_brute", "william_brute", "sit_idle", false, nil, nil, 1.7),
        Prefab("williambrute_builder", builder, assets, prefabs)



--------------------------------------------------------------------------
