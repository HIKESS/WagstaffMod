require "prefabutil"
require "recipe"
require "modutil"

local prefabs =
{

}

    local assets =
    {
        Asset("ANIM", "anim/william_butler.zip"),
    Asset("ANIM", "anim/ui_chest_3x2.zip"),
    Asset("ANIM", "anim/ui_chest_3x1.zip"),
        Asset("SOUND", "sound/maxwell.fsb"),
    }

-- v2.0.35: Design correto = williamgadget (100% via lootsetfn) + 50% de UM item
-- so (o material principal do recipe). Antes v2.0.34 tinha 50% por material (2
-- itens), mas o design original era 50% para 1 item so.
-- Butler recipe: williamgadget + boards(4) + transistor(2) -> material principal = boards
SetSharedLootTable("butler",
{
    {'boards',            0.50},
})

SetSharedLootTable("butlergadget",
{
    {'williamgadget',          1},
})

-- v2.0.34: lootsetfn garante 1 williamgadget (core) sempre que DropLoot e chamado
-- (tanto em morte por combate quanto em hammer). Sem gears pois butler nao tem level.
local function lootsetfn(lootdropper)
    lootdropper:SetLoot({"williamgadget"})
end

local brain = require "brains/williambutlerbrain"
local AffinityPulse = _G.AffinityPulse

-- v2.0.17: debug helpers gated by the "Debug mode" mod config button.
-- Zero-cost when debug is OFF (early return before any string work).
local _dbg  = _G.WagstaffDbg  or function(...) end
local _dbgF = _G.WagstaffDbgF or function(...) end

-- v2.0.30: PULSE de cor no personagem ao comer comida buffada (NAO e FX prefab).
-- Inspirado no AffinityPulse dos bots (modmain.lua) mas mais discreto e rapido:
-- 4 steps x 0.07s = 0.28s total. Fade out de add/mul colour ate restaurar ao
-- valor base (default OU tint do shadow buff se ativo). Sempre que come comida
-- buffada, emite um pulse celestial (azul) ou shadow (roxo escuro).
local EAT_PULSE_PERIOD = 0.07
local EAT_PULSE_CELESTIAL = {
    { add = { 0.12, 0.20, 0.40, 0 }, mul = { 0.92, 0.96, 1.0,  1 } },
    { add = { 0.08, 0.15, 0.30, 0 }, mul = { 0.95, 0.98, 1.0,  1 } },
    { add = { 0.05, 0.10, 0.20, 0 }, mul = { 0.97, 0.99, 1.0,  1 } },
    { add = { 0.02, 0.05, 0.10, 0 }, mul = { 0.99, 1.0,  1.0,  1 } },
}
local EAT_PULSE_SHADOW = {
    { add = { 0.14, 0.0, 0.20, 0 }, mul = { 0.85, 0.80, 0.90, 1 } },
    { add = { 0.10, 0.0, 0.14, 0 }, mul = { 0.89, 0.85, 0.93, 1 } },
    { add = { 0.06, 0.0, 0.09, 0 }, mul = { 0.93, 0.90, 0.96, 1 } },
    { add = { 0.03, 0.0, 0.04, 0 }, mul = { 0.96, 0.95, 0.98, 1 } },
}
local function DoEatPulse(eater, kind)
    if not eater or not eater:IsValid() or not eater.AnimState then return end
    -- Cancela pulse anterior (não empilha em comer rápido).
    if eater._wagstaff_eat_pulse_task then
        eater._wagstaff_eat_pulse_task:Cancel()
        eater._wagstaff_eat_pulse_task = nil
    end
    local steps = (kind == "shadow") and EAT_PULSE_SHADOW or EAT_PULSE_CELESTIAL
    local step = 0
    eater._wagstaff_eat_pulse_task = eater:DoPeriodicTask(EAT_PULSE_PERIOD, function()
        if not eater:IsValid() or not eater.AnimState then
            eater._wagstaff_eat_pulse_task = nil
            return
        end
        step = step + 1
        if step > #steps then
            -- Restaura cor base: se o shadow buff tint estiver ativo, restaura
            -- o tint do buff; senao restaura ao default (add=0, mul=1).
            if eater._wagstaff_shadow_tinted then
                eater.AnimState:SetMultColour(0.70, 0.70, 0.78, 1.0)
                eater.AnimState:SetAddColour(0.05, 0.03, 0.10, 0)
            else
                eater.AnimState:SetAddColour(0, 0, 0, 0)
                eater.AnimState:SetMultColour(1, 1, 1, 1)
            end
            eater._wagstaff_eat_pulse_task:Cancel()
            eater._wagstaff_eat_pulse_task = nil
            return
        end
        local s = steps[step]
        eater.AnimState:SetAddColour(s.add[1], s.add[2], s.add[3], s.add[4])
        eater.AnimState:SetMultColour(s.mul[1], s.mul[2], s.mul[3], s.mul[4])
    end)
end

local function UpdateButlerName(inst)
    if not inst.components.fueled or not inst.components.health then return end
    local fuel = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
    local hp = math.floor(inst.components.health.currenthealth)
    local maxhp = math.floor(inst.components.health.maxhealth)
    local base_name = "Butler Bot"
    if inst.prefab == "williambutler2" then
        base_name = "Butler Bot Mk. II"
    elseif inst.prefab == "williambutler3" then
        base_name = "Butler Bot Mk. III"
    end

    -- v2.0.40: upgrade progress is shown ONLY when an upgrade is actively in
    -- progress (upgradelevel > 0). A fresh bot (upgradelevel == 0) keeps a clean
    -- title with no "Upgrade" text. Once the player starts hammering with the
    -- wrench, upgradelevel becomes > 0 and the "Upgrade: xx/xx" progress appears
    -- in the name so the player can see how much has been invested.
    local upgrade_str = ""
    if inst.prefab == "williambutler" and inst.upgradelevel and inst.upgradelevel > 0 and inst.upgradelevel < 50 then
        upgrade_str = " | Upgrade: " .. inst.upgradelevel .. "/50"
    elseif inst.prefab == "williambutler2" and inst.upgradelevel_mk3 and inst.upgradelevel_mk3 > 0 and inst.upgradelevel_mk3 < 70 then
        upgrade_str = " | Upgrade: " .. inst.upgradelevel_mk3 .. "/70"
    end
    local name_str = base_name .. "\nFuel: " .. fuel .. "% | HP: " .. hp .. "/" .. maxhp .. upgrade_str

    -- v2.0.53: Re-added the inst.GetDisplayName override (was removed in v2.0.40
    -- due to "double render"). The double render was caused by STRINGS.NAMES
    -- being MISSING at the time (removed in v2.0.20, re-added in v2.0.41) —
    -- without a short STRINGS title, GetBasicDisplayName returned inst.name
    -- (the full string), so both GetDisplayName and GetBasicDisplayName showed
    -- the full string = double render. Now that STRINGS.NAMES are defined AND
    -- SetPrefabNameOverride matches the displaynamefn first line (v2.0.53 fix),
    -- the title is a short string that matches the first line of the detail —
    -- same pattern as the buster bot, which has always had this override and
    -- works correctly. This is what makes the hover show fuel/HP/upgrade on
    -- the HOST (ismastersim = true), which is the common play scenario.
    -- Also explicitly sync the replica for dedicated-server CLIENTS: DST's
    -- named component SetName does NOT auto-call replica:SetName, so without
    -- this the client's replica.named.name netvar stays empty and the client
    -- only sees the short STRINGS title (no fuel/HP).
    if inst.components.named ~= nil then
        inst.components.named:SetName(name_str)
    end
    -- Explicitly push the name to the replica's net_string so dedicated-server
    -- clients receive it (the base game's named:SetName does NOT do this).
    -- v2.0.55: FIX CRASH. named_replica:SetName(name, author) calls
    -- self._author_netid:set(author) internally, and net_string:set(nil)
    -- throws "calling 'set' on bad self (string expected, got nil)". The
    -- butler has no author, so we pass an empty string. This crashed every
    -- time a butler was spawned (OnBuiltFn -> SpawnPrefab -> fn ->
    -- UpdateButlerName) on v2.0.54.
    if inst.replica and inst.replica.named ~= nil then
        inst.replica.named:SetName(name_str, "")
    end
    inst.name = name_str
    -- Direct override (matches buster pattern). On the host this is what the
    -- hover widget calls — guarantees the full string shows regardless of
    -- displaynamefn / replica sync timing.
    inst.GetDisplayName = function() return name_str end
end

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

local function MakeAlive(inst, doer)
    -- BUG FIX: Check if doer has petleash (fixes bug after c_skip)
    if not doer or not doer.components.petleash then
        return
    end

    local pt = inst:GetPosition()
    local prefab_to_spawn = "williambutler"
    local was_level2 = inst.was_level2 or false
    local was_mk3 = inst.was_mk3 or false
    local saved_upgrade = inst.saved_upgradelevel or 0
    local saved_upgrade_mk3 = inst.saved_upgradelevel_mk3 or 0

    -- Check upgrade state
    if was_mk3 then
        prefab_to_spawn = "williambutler3"
    elseif was_level2 then
        prefab_to_spawn = "williambutler2"
    end

    local respawned = doer.components.petleash:SpawnPetAt(pt.x, 0, pt.z, prefab_to_spawn)
    if respawned ~= nil then
        respawned.components.fueled.currentfuel = inst.components.fueled.currentfuel
        respawned.components.health:SetCurrentHealth(inst.components.health.currenthealth)
        respawned.Transform:SetRotation(inst.Transform:GetRotation())

        -- BUG FIX: Save owner GUID for tracking (fixes bug 9)
        respawned.owner_guid = doer.GUID
        respawned.owner_name = doer.name

        -- Restore upgrade progress
        if was_mk3 and saved_upgrade_mk3 > 0 then
            respawned.upgradelevel_mk3 = saved_upgrade_mk3
        elseif was_level2 then
            respawned.upgradelevel_mk3 = saved_upgrade_mk3 or 0
        elseif not was_level2 and not was_mk3 and saved_upgrade > 0 then
            respawned.upgradelevel = saved_upgrade
        end
        UpdateButlerName(respawned)

        respawned.sg:GoToState("revived")
    end
    inst:Remove()
end

local function onfuelchange(newsection, oldsection, inst, doer)
        if newsection >= 0 then
    local pt = inst:GetPosition()
        -- BUG FIX: Check petleash before reviving
        if doer ~= nil and doer:HasTag("williamcrafter") and doer.components.petleash then
                MakeAlive(inst, doer)
                end
        end
end

local function OnAddFuel(inst, fuelvalue, fuelitem)
        -- v2.0.70 FIX: DST's `fueled` component calls ontakefuelfn as
        -- (inst, fuelvalue, ...) — NOT (inst, doer, fuelitem). Previous code
        -- treated the fuelvalue number as `doer`, crashing with "attempt to
        -- index local 'doer' (a number value)" when fuel was already full.
        -- v2.0.63: reject fuel when already full (vanilla-style feedback).
        if inst.components.fueled and inst.components.fueled:IsFull() then
            local player = FindClosestPlayerToInst(inst, 10, true)
            if player and player.components.talker then
                player.components.talker:Say("It's already full!")
            end
            return false
        end
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel")

        if inst.sg ~= nil and not inst.sg:HasStateTag("busy") then
    inst.sg:GoToState("fed")
        end

        -- Update fuel display when refueled
        UpdateButlerName(inst)
    inst:AddTag("alive")
        return true
end

local function OnHammered(inst, worker)
    -- v2.0.86 FIX: Close() the container before DropEverything() to prevent
    -- the client-side container widget remaining open after entity removal.
    -- Same fix as brute v2.0.85. Without Close(), if the player has the
    -- container UI open when the bot is hammered, the widget stays open on
    -- a nil entity, causing a nil reference error or visual glitch.
    if inst.components.container then
        inst.components.container:Close()
        inst.components.container:DropEverything()
    end

    -- v2.0.34: lootsetfn garante williamgadget (100%), chance table "butler" da
    -- 50% boards + 50% transistor (bonus alinhado ao recipe). Uma unica chamada
    -- DropLoot cobre morte e hammer.
    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function onworked(inst)
        if inst.sg ~= nil then
        inst.sg:GoToState("hit")
        end
end

local function OnFuelEmpty(inst)
    if inst.sg ~= nil then
        inst.sg:GoToState("powerdown")
    end
end

local function oncook(inst, doer)

for k, v in pairs (inst.components.container.slots) do
                        if v.components.cookable ~= nil then
                local leader = inst.components.follower:GetLeader()
                local cook_pos = inst:GetPosition()
                        inst.sg:GoToState("cook")
        inst:DoTaskInTime(0.9, function()

if inst.components.fueled ~= nil then
        inst.components.fueled:DoDelta(-.01 * inst.components.fueled.maxfuel)
    end

        if inst.components.fueled ~= nil and not inst.components.fueled:IsEmpty() then

        local ingredient = inst.components.container:RemoveItem(v)


        --if ingredient ~= nil then  end

        v.Transform:SetPosition(cook_pos:Get())

        if not inst.components.cooker:CanCook(ingredient, inst) then
            inst.components.container:GiveItem(ingredient, nil, cook_pos)
            return false
        end

        if ingredient.components.health ~= nil and ingredient.components.combat ~= nil then
            inst:PushEvent("killed", { victim = ingredient })
        end

        local product = inst.components.cooker:CookItem(ingredient, inst)
            if product ~= nil and doer ~= nil then
                -- v2.0.17 DEBUG: trace affinity food logic
                local _owner = GetOwner(inst)
                local _has_celest = _owner and _owner:HasTag("wagstaff_celestial_possession")
                local _has_shadow = _owner and _owner:HasTag("wagstaff_shadow_possession")
                _dbgF("[BUTLER COOK] prefab=%s isday=%s isdusk=%s owner=%s celest=%s shadow=%s",
                    inst.prefab, tostring(TheWorld.state.isday), tostring(TheWorld.state.isdusk),
                    tostring(_owner ~= nil), tostring(_has_celest), tostring(_has_shadow))

                -- CELESTIAL POSSESSION: Foods restore HP% (MK3 only)
                if inst.prefab == "williambutler3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
                if product.components.edible and product.components.edible.hungervalue then
                    local hunger_percent = product.components.edible.hungervalue / 100
                    if hunger_percent > 1 then hunger_percent = 1 end
                    -- Store the healing amount on the food item (40% of hunger = HP%)
                    product._celestial_hp_heal = hunger_percent * 40
                    product._celestial_hp_doer = doer
                    _dbgF("[BUTLER COOK] CELESTIAL applied: heal=%.1f%% of max HP", product._celestial_hp_heal)
                    -- Listen for when food is eaten
                    local old_oneaten = product.components.edible.oneaten
                    product.components.edible:SetOnEatenFn(function(food, eater)
                        if old_oneaten then old_oneaten(food, eater) end
                        -- Only HP heal, no sanity bonus
                        if eater.components.health and food._celestial_hp_heal then
                            local max_hp = eater.components.health.maxhealth
                            local heal_amount = max_hp * (food._celestial_hp_heal / 100)
                            eater.components.health:DoDelta(heal_amount, false, "celestial_food")
                            _dbgF("[BUTLER COOK] CELESTIAL eaten: healed %.1f HP", heal_amount)
                            -- v2.0.30: PULSE de cor celestial no personagem (NAO e FX prefab).
                            -- Discreto e rapido (0.28s). Som gemsparkle como cue audio sutil.
                            DoEatPulse(eater, "celestial")
                            if eater.SoundEmitter then
                                eater.SoundEmitter:PlaySound("dontstarve/common/gemsparkle")
                            end
                        end
                    end)
                end
            end

            -- SHADOW POSSESSION: Foods restore SANITY% (MK3 only)
            if inst.prefab == "williambutler3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
                if product.components.edible and product.components.edible.hungervalue then
                    local hunger_percent = product.components.edible.hungervalue / 100
                    if hunger_percent > 1 then hunger_percent = 1 end
                    -- Store the sanity amount on the food item (40% of hunger = sanity%)
                    product._shadow_sanity_restore = hunger_percent * 40
                    product._shadow_sanity_doer = doer
                    _dbgF("[BUTLER COOK] SHADOW applied: restore=%.1f%% of max sanity", product._shadow_sanity_restore)
                    -- Listen for when food is eaten
                    local old_oneaten = product.components.edible.oneaten
                    product.components.edible:SetOnEatenFn(function(food, eater)
                        if old_oneaten then old_oneaten(food, eater) end
                        -- Only sanity restore, no HP bonus
                        if eater.components.sanity and food._shadow_sanity_restore then
                            local max_sanity = eater.components.sanity.max
                            local sanity_amount = max_sanity * (food._shadow_sanity_restore / 100)
                            eater.components.sanity:DoDelta(sanity_amount, false, "shadow_food")
                            _dbgF("[BUTLER COOK] SHADOW eaten: restored %.1f sanity", sanity_amount)
                            -- v2.0.30: PULSE de cor shadow no personagem (NAO e FX prefab).
                            -- Discreto e rapido (0.28s), roxo escuro.
                            DoEatPulse(eater, "shadow")
                        end
                    end)
                end
            end
            
            doer.components.inventory:GiveItem(product, nil, cook_pos)

            return true
        elseif ingredient:IsValid() then
            inst.components.container:GiveItem(ingredient, nil, cook_pos)
        end

        end

        end)
                end
        end
end

local function fuelupdate(inst)
        if inst.components.fueled ~= nil
            and inst.components.fueled.currentfuel <= inst.components.fueled.maxfuel*0.2  then
                inst:AddTag("lowfuel")
                else
        if inst:HasTag("lowfuel") then
    inst:RemoveTag("lowfuel")
        end
        end
    -- Update name with current fuel (now one function handles all versions!)
    UpdateButlerName(inst)
end

local function nokeeptargetfn(inst)
    return false
end

local function getstatus(inst, viewer)
    -- v2.0.33: upgrade progress removed from getstatus (was always visible,
    -- should only show with skill + wrench). Returns clean status keys now.
    if inst.components.fueled:IsEmpty() then
        return "EMPTY"
    elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .3 then
        return "CRITICALFUEL"
    elseif inst.components.fueled.currentfuel / inst.components.fueled.maxfuel <= .6 then
        return "LOWFUEL"
    end
end

local function GetButlerDescription(inst, viewer)
    -- v2.0.33: upgrade progress removed (was always visible, should only show
    -- with skill + wrench). Fuel/HP are in the name via displaynamefn.
    local fuel_pct = math.floor((inst.components.fueled.currentfuel / inst.components.fueled.maxfuel) * 100)
    if inst.prefab == "williambutler2" then
        return "Butler Bot Mk. II\nFuel: " .. fuel_pct .. "%"
    elseif inst.prefab == "williambutler3" then
        return "Butler Bot Mk. III\nFuel: " .. fuel_pct .. "%"
    end
    return "Butler Bot\nFuel: " .. fuel_pct .. "%"
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function nodebrisdmg(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return (afflicter ~= nil and afflicter:HasTag("quakedebris")) or (afflicter ~= nil and afflicter:HasTag("epic") and afflicter.components.combat.target ~= inst)
end

local function OnOpen(inst)
    if not inst.components.health:IsDead() then
        inst.sg:GoToState("open")
        
        -- Show slot labels for butler2
        if inst.prefab == "williambutler2" and inst.components.follower and inst.components.follower:GetLeader() then
            local leader = inst.components.follower:GetLeader()
            if leader and leader.components.talker then
                leader.components.talker:Say("Slots 1-3: [Cook]")
            end
        end
        
        -- CELESTIAL POSSESSION: FX ao abrir menu - ghostlyelixir_shield central (MK3 only)
        if inst.prefab == "williambutler3" and TheWorld.state.isday and OwnerHasCelestial(inst) then
            local x, y, z = inst.Transform:GetWorldPosition()
            -- FX central no meio do corpo do bot
            local shield_fx = SpawnPrefab("ghostlyelixir_shield_fx")
            if shield_fx then
                shield_fx.Transform:SetPosition(x, y + 0.3, z) -- Centro do corpo (mais baixo)
                shield_fx.Transform:SetScale(0.5, 0.5, 0.5) -- 50% do tamanho (médio)
                if shield_fx.AnimState then
                    shield_fx.AnimState:SetMultColour(1, 1, 1, 0.5) -- 50% transparente
                    shield_fx.AnimState:SetDeltaTimeMultiplier(0.3) -- Pisca 3x mais lento
                end
            end
        end
        
        -- SHADOW POSSESSION: FX ao abrir menu - shadow_shield1 (MK3 only)
        if inst.prefab == "williambutler3" and TheWorld.state.isdusk and OwnerHasShadow(inst) then
            local x, y, z = inst.Transform:GetWorldPosition()
            -- FX de escudo sombrio
            local shield_fx = SpawnPrefab("shadow_shield1")
            if shield_fx then
                shield_fx.Transform:SetPosition(x, y + 0.3, z) -- Centro do corpo
                shield_fx.Transform:SetScale(0.5, 0.5, 0.5) -- 50% do tamanho
            end
        end
    end
end

local function OnClose(inst)
    if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
        inst.sg:GoToState("close")
    end

end

local function onload(inst)
   if inst.components.fueled:IsEmpty() then
                OnFuelEmpty(inst)
        end
end


    local function fn(inst)
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()
        inst.MiniMapEntity:SetIcon("williambutler.tex")
        inst.DynamicShadow:SetSize(1.3, .6)
        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("wilson")
        inst.AnimState:SetBuild("william_butler")
        inst.AnimState:PlayAnimation("idle")
            inst.AnimState:Hide("ARM_carry")
            inst.AnimState:Hide("HEAD_HAT")

    MakeCharacterPhysics(inst, 50, .5)
        --inst.Physics:SetCollides(true)
        --inst:DoTaskInTime(0, function() inst.Physics:SetCollides(true) end)

        inst.AnimState:OverrideSymbol("fx_wipe", "wilson_fx", "fx_wipe")
        inst.AnimState:OverrideSymbol("fx_liquid", "wilson_fx", "fx_liquid")
        inst.AnimState:OverrideSymbol("shadow_hands", "shadow_hands", "shadow_hands")
    inst.AnimState:AddOverrideBuild("player_idles_warly")


        inst:AddTag("willminion")
        inst:AddTag("willfollower")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
    -- v2.0.86 FIX: "cooker", "container", and "stewer" tags moved to active()
    -- only. The empty husk (which calls fn()) had these tags without the
    -- corresponding components, causing a crash when right-clicking the husk
    -- (DST shows "Open" prompt but inst.components.container is nil).
    inst:AddTag("tiddlevirusimmune")
    inst:SetPrefabNameOverride("williambutler")

    -- v2.0.18 FIX: hover display on CLIENT. The client doesn't have
    -- inst.GetDisplayName (set only on server) and inst.name resolves to
    -- STRINGS.NAMES.WILLIAMBUTLER = "Butler Bot" (no fuel/HP info). The
    -- engine's GetDisplayName checks inst.name BEFORE replica.named, so
    -- MK1/MK2 showed "Butler Bot" on hover instead of the fuel/HP string.
    -- MK3 worked because STRINGS.NAMES.WILLIAMBUTLER3 was never defined,
    -- so inst.name was nil and it fell through to replica.named.
    -- displaynamefn has the HIGHEST priority (checked before inst.name),
    -- so setting it here (runs on BOTH server and client, before the
    -- ismastersim return) forces hover to use the named component/replica
    -- which has the correct "Butler Bot\nFuel: X% | HP: X/X" string.
    -- v2.0.53: Made the replica path robust — inst.replica.named.name can be
    -- a net_string OBJECT (not a plain string) on some DST versions, which
    -- displaynamefn would return as-is and GetDisplayName couldn't render.
    -- Now extracts the string value via :value() / tostring() with nil/empty
    -- guards so it never falls through to inst.name (the short STRINGS title)
    -- when the replica actually has data.
    inst.displaynamefn = function(inst)
        if inst.components.named ~= nil then
            return inst.components.named.name
        end
        if inst.replica.named ~= nil then
            local name = inst.replica.named.name
            if name ~= nil then
                if type(name) == "string" then
                    if name ~= "" then return name end
                else
                    -- net_string object: extract the value safely.
                    local ok, val = pcall(function() return name:value() end)
                    if ok and val and val ~= "" then return val end
                    local ok2, val2 = pcall(function() return tostring(name) end)
                    if ok2 and val2 and val2 ~= "" then return val2 end
                end
            end
        end
        return inst.name
    end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

    -- v2.0.65: mark active butler as "on" so the brain's Deactivated gate
    -- (WhileNode inst.on == false) does not block movement. The empty husk
    -- prefab sets inst.on = false to stay inert.
    inst.on = true




        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUTLER_HEALTH)
       -- inst.components.health.nofadeout = true
    inst.components.health:StartRegen(TUNING.WILLIAM_ROBOT_REGEN, TUNING.WILLIAM_ROBOT_REGENPERIOD)
        inst.components.health.redirect = nodebrisdmg
                inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("butler")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("named")

        inst:AddComponent("willyraise")
    inst.components.willyraise:SetOnRiseFn(MakeAlive)
    inst.components.willyraise:SetOnLowerFn(OnFuelEmpty)

    inst:AddComponent("fueled")
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled.accepting = true  -- Enable manual fueling (reverted to original)
    inst.components.fueled:InitializeFuelLevel(TUNING.WILLIAM_BUTLER_MAXFUEL)
    inst.components.fueled.bonusmult = 1

    -- v2.0.75: per-material fuel balancing. Sets bonusmult=5 (matches original
    -- mod design), restricts accepted fuels to WILLIAM_FUEL.BUTLER list
    -- (wood/plant/organic + some mechanical), and hooks TakeFuelItem so
    -- custom materials (gears, transistor, rotton, etc.) give explicit fuel
    -- values even though they lack a DST `fuel` component.
    local WILLIAM_FUEL = _G.WILLIAM_FUEL
    if WILLIAM_FUEL then
        WILLIAM_FUEL.Setup(inst, WILLIAM_FUEL.BUTLER, 5)
    end

    -- Update name AFTER fueled component is added (was crashing on craft: fueled was nil)
    UpdateButlerName(inst)

        return inst
    end

        --ACTIVE butler
        
    local function active(inst)
        local inst = fn(inst)
    MakeCharacterPhysics(inst, 50, .5)

    inst.MiniMapEntity:SetCanUseCache(false)

        inst.Transform:SetFourFaced()

        inst:AddTag("alive")
        inst:AddTag("scarytoprey")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("butler")
        inst:AddTag("dangerouscooker")
        inst:AddTag("expertchef")
        -- v2.0.86: Tags moved from fn() to active() so the empty husk doesn't
        -- have them without the corresponding components.
        inst:AddTag("cooker")
        inst:AddTag("container")
        inst:AddTag("stewer")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("ebuild_wrenchable")
        inst.AnimState:Hide("swap_body")

        if not TheWorld.ismastersim then
            return inst
        end

    -- BUG FIX: Standard workable for regular hammer (always present)
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

 inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

        inst:SetStateGraph("SGwilliambutler")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("williambutler")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.skipopensnd = true
    inst.components.container.skipclosesnd = true

        inst:AddComponent("combat")
        inst.components.combat.hiteffectsymbol = "torso"
        inst.components.combat:SetRange(3)
    inst.components.combat:SetKeepTargetFunction(nokeeptargetfn)


        inst:ListenForEvent("docookery", oncook)

        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true

        -- Meat Effigy Overclock: swap places with owner on near-death
    inst.components.fueled:SetUpdateFn(fuelupdate)
    inst.components.fueled:SetDepletedFn(OnFuelEmpty)

        inst:SetBrain(brain)

    MakeMediumBurnableCharacter(inst, "torso")
    MakeMediumFreezableCharacter(inst, "torso")

    inst.components.fueled:StartConsuming()

    -- Rain damage (like WX-78) when active
    inst:DoPeriodicTask(1, function(inst)
        if TheWorld.state.israining and inst.components.health then
            inst.components.health:DoDelta(-1, false, "wetness")
        end
    end)

    -- Lightning recharge (refuel, no overcharge)
    inst:ListenForEvent("lightningstrike", function(inst)
        if inst.components.fueled then
            inst.components.fueled:DoDelta(inst.components.fueled.maxfuel * 0.25)
        end
    end)

inst.components.burnable.ignorefuel = true
    inst:AddComponent("cooker")
    
    -- Initialize name with fuel status
    UpdateButlerName(inst)
    inst:ListenForEvent("fuelchange", function() UpdateButlerName(inst) end)
    inst:ListenForEvent("healthdelta", function() UpdateButlerName(inst) end)
    -- Periodic update to ensure hover display stays current (matches other bots)
    inst:DoPeriodicTask(2, function() UpdateButlerName(inst) end)

    --==================================================================================
    -- BUTLER UPGRADE: Wrench upgrade spawns williambutler2 with 3 cook slots
    -- v2.0.16: 50 scraps total, 10 per hit (5 hits). Progress shown in bot name.
    -- Requires wagstaff_thermal_upgrade skill to be learned.
    --==================================================================================
    inst.upgradelevel = 0

        local function IsScrap(item)
            return item.prefab == "scrap"
        end

        inst:AddComponent("engieworkable")
        inst.components.engieworkable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.engieworkable:SetMaxWork(1)
        inst.components.engieworkable:SetWorkLeft(1)
        inst.components.engieworkable:SetOnWorkCallback(function(inst, worker)
            _dbg("[DEBUG UPGRADE] OnWorkCallback chamado!")
            if inst.sg ~= nil then
                inst.sg:GoToState("hit")
            end
        end)
        inst.components.engieworkable:SetOnFinishCallback(function(inst, worker)
            _dbg("[DEBUG UPGRADE] === INICIO DO UPGRADE DO BUTLER ===")
            _dbg("[DEBUG UPGRADE] worker:", worker, worker.prefab)
            _dbg("[DEBUG UPGRADE] inst:", inst, inst.prefab)
            
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                _dbg("[DEBUG UPGRADE] Bot em estado shutdown, abortando")
                return
            end
            
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            _dbg("[DEBUG UPGRADE] Wrench equipada:", wrench and wrench.prefab or "NENHUMA")
            
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                _dbg("[DEBUG UPGRADE] Usando durabilidade da wrench")
                wrench.components.finiteuses:Use(1)
            end

            -- PRIORITY 1: Repair if HP < 100% (NO skill required)
            _dbg("[DEBUG UPGRADE] HP atual:", inst.components.health.currenthealth, "/", inst.components.health.maxhealth)
            if inst.components.health.currenthealth < inst.components.health.maxhealth then
                _dbg("[DEBUG UPGRADE] Tentando reparar bot...")
                local function IsScrap(item)
                    return item.prefab == "scrap"
                end
                local scrapstack = worker.components.inventory:FindItem(IsScrap)
                local repair_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 1)
                _dbg("[DEBUG UPGRADE] Scrap encontrado:", scrapstack and scrapstack.prefab or "NENHUM", "Custo reparo:", repair_cost)
                if repair_cost > 0 and scrapstack == nil then
                    _dbg("[DEBUG UPGRADE] Sem scrap para reparo!")
                    if worker.components.talker then
                        worker.components.talker:Say("Need Scrap Metal to repair!")
                    end
                    return
                end
                if repair_cost > 0 then
                    _dbg("[DEBUG UPGRADE] Consumindo", repair_cost, "scrap(s) para reparo")
                    worker.components.inventory:ConsumeByName("scrap", repair_cost)
                end
                inst.components.health:DoDelta(50)
                inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
                if worker.components.talker then
                    worker.components.talker:Say("Repaired 50 HP!")
                end
                _dbg("[DEBUG UPGRADE] Reparo concluido!")
                return
            end

            -- PRIORITY 2: Upgrade if HP = 100% AND skill learned
            _dbg("[DEBUG UPGRADE] Bot com HP maximo, verificando skill wagstaff_thermal_upgrade...")
            _dbg("[DEBUG UPGRADE] worker.prefab=", tostring(worker.prefab))
            _dbg("[DEBUG UPGRADE] worker tem skilltreeupdater=", tostring(worker.components.skilltreeupdater ~= nil))
            
            local has_skill = _G.WagstaffHasSkill(worker, "wagstaff_thermal_upgrade")
            _dbg("[DEBUG UPGRADE] Resultado de WagstaffHasSkill:", has_skill)
            
            if not has_skill then
                _dbg("[DEBUG UPGRADE] Skill NAO encontrada! Bloqueando upgrade.")
                if worker.components.talker then
                    worker.components.talker:Say("Requires Butler MK. II skill!\n(Activate it in the skill tree!)")
                end
                return
            end
            
            _dbg("[DEBUG UPGRADE] Skill encontrada! Prosseguindo com upgrade...")

    -- Upgrade: variable scrap cost per wrench hit (10, 10, 10, 10, 15 = 55 total)
            local scrap_count = 0
            if worker.components.inventory then
                for _, item in pairs(worker.components.inventory.itemslots) do
                    if item ~= nil and item.prefab == "scrap" and item.components.stackable then
                        scrap_count = scrap_count + item.components.stackable:StackSize()
                    elseif item ~= nil and item.prefab == "scrap" then
                        scrap_count = scrap_count + 1
                    end
                end
            end
            _dbg("[DEBUG UPGRADE] Scrap count no inventario:", scrap_count)
            
            -- Determine cost based on current upgrade level
            local upgrade_cost_table = {10, 10, 10, 10, 10}  -- v2.0.16: 50 scraps total (was 55)
            local hits_so_far = math.floor(inst.upgradelevel / 10)  -- 0-5 hits
            local base_cost = upgrade_cost_table[hits_so_far + 1] or 10
            local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, base_cost)
            _dbg("[DEBUG UPGRADE] Upgrade level atual:", inst.upgradelevel, "hits_so_far:", hits_so_far, "base_cost:", base_cost, "upgrade_cost (com eficiencia):", upgrade_cost)
            
            if upgrade_cost > 0 and scrap_count < upgrade_cost then
                _dbg("[DEBUG UPGRADE] Scrap insuficiente! Precisa de", upgrade_cost, "tem", scrap_count)
                if worker.components.talker then
                    worker.components.talker:Say("Need " .. upgrade_cost .. " Scrap Metal!")
                end
                return
            end
            if upgrade_cost > 0 then
                _dbg("[DEBUG UPGRADE] Consumindo", upgrade_cost, "scrap(s) para upgrade")
                worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
            end
            inst.upgradelevel = inst.upgradelevel + base_cost
            _dbg("[DEBUG UPGRADE] Novo upgrade level:", inst.upgradelevel)
            UpdateButlerName(inst)

            if inst.upgradelevel >= 50 then
                _dbg("[DEBUG UPGRADE] UPGRADE COMPLETO! Spawnando williambutler2...")
                inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                if worker.components.talker then
                    worker.components.talker:Say("Butler Bot MK. II upgrade complete!")
                end

                -- Spawn upgraded bot
                local pt = inst:GetPosition()
                local newbot = SpawnPrefab("williambutler2")
                _dbg("[DEBUG UPGRADE] newbot spawned:", newbot and "SUCESSO" or "FALHA")
                if newbot ~= nil then
                    newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                    newbot.Transform:SetRotation(inst.Transform:GetRotation())

                    -- Transfer fuel
                    if inst.components.fueled and newbot.components.fueled then
                        _dbg("[DEBUG UPGRADE] Transferindo fuel:", inst.components.fueled.currentfuel)
                        newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                    end
                    -- Transfer health
                    if inst.components.health and newbot.components.health then
                        _dbg("[DEBUG UPGRADE] Transferindo health:", inst.components.health.currenthealth)
                        newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                    end
                    -- Transfer container items (crockpot slots 1-3)
                    if inst.components.container and newbot.components.container then
                        for slot = 1, 3 do
                            local item = inst.components.container:GetItemInSlot(slot)
                            if item ~= nil then
                                _dbg("[DEBUG UPGRADE] Transferindo item do slot", slot, ":", item.prefab)
                                newbot.components.container:GiveItem(item, slot)
                            end
                        end
                    end

                    -- Transfer follower
                    if inst.components.follower and newbot.components.follower then
                        local leader = inst.components.follower:GetLeader()
                        if leader ~= nil then
                            _dbg("[DEBUG UPGRADE] Transferindo leader:", leader.prefab)
                            newbot.components.follower:SetLeader(leader)
                        end
                    end

                    -- Spawn FX
                    SpawnPrefab("small_puff").Transform:SetPosition(pt.x, pt.y, pt.z)
                end

                _dbg("[DEBUG UPGRADE] Removendo bot antigo...")
                inst:Remove()
            else
                _dbg("[DEBUG UPGRADE] Upgrade em andamento... falta", 50 - inst.upgradelevel, "para completar")
            end
        end)

    -- Save/load upgrade progress
    local function OnSaveButler(inst, data)
        data.upgradelevel = inst.upgradelevel
        -- Save leader GUID for persistence
        if inst.components.follower and inst.components.follower:GetLeader() then
            data.leader_guid = inst.components.follower:GetLeader().GUID
        end
    end

    local function OnLoadButler(inst, data)
        if data then
            inst.upgradelevel = data.upgradelevel or 0
        end
        -- Restore follower after save/load
        if data ~= nil and data.leader_guid ~= nil then
            inst:DoTaskInTime(0, function()
                -- v2.0.90 FIX: TheWorld.GUIDToPos returns a POSITION (Vector3),
                -- not an entity. Use Ents[] instead — the standard DST entity lookup.
                local leader = Ents[data.leader_guid]
                if leader and leader:IsValid() and inst:IsValid() then
                    if inst.components.follower then
                        inst.components.follower:SetLeader(leader)
                    end
                end
            end)
        end
    end

    inst.OnSave = OnSaveButler
    inst.OnLoad = OnLoadButler

    MakeHauntablePanic(inst)

        return inst
    end

    --==================================================================================
    -- BUTLER BOT v2: Upgraded version with 3 cook slots
    -- Now Picks Twigs & Grass when owner picks.
    -- Spawned by wrench upgrade on original butler.
    --==================================================================================
    local function active2(inst)
        local inst = fn(inst)
        -- v2.0.53 FIX: MK2 hover was broken. fn() sets
        -- SetPrefabNameOverride("williambutler") for ALL tiers, so MK2's short
        -- title (GetBasicDisplayName via STRINGS.NAMES.WILLIAMBUTLER) was
        -- "Butler Bot" — which does NOT match the displaynamefn first line
        -- "Butler Bot Mk. II". That mismatch made the hover render the title
        -- AND the detail's first line ("Butler Bot" + "Butler Bot Mk. II\n...")
        -- producing the "repeating"/jumbled hover the user reported. MK3
        -- already overrode this (line ~1108); MK2 was missing the override.
        inst:SetPrefabNameOverride("williambutler2")
        MakeCharacterPhysics(inst, 50, .5)

        inst.MiniMapEntity:SetCanUseCache(false)
        inst.Transform:SetFourFaced()

        inst:AddTag("alive")
        inst:AddTag("scarytoprey")
        inst:AddTag("willminion")
        inst:AddTag("companion")
        inst:AddTag("NOBLOCK")
        inst:AddTag("mech")
        inst:AddTag("butler")
        inst:AddTag("dangerouscooker")
        inst:AddTag("expertchef")
        -- v2.0.86: Tags moved from fn() to here so the empty husk doesn't
        -- have them without the corresponding components.
        inst:AddTag("cooker")
        inst:AddTag("container")
        inst:AddTag("stewer")
        inst:AddTag("tiddlevirusimmune")
        inst:AddTag("butler_thermal_upgraded")
        inst:AddTag("ebuild_wrenchable")
        inst.AnimState:Hide("swap_body")

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")

        inst:SetStateGraph("SGwilliambutler")

        inst:AddComponent("container")
        inst.components.container:WidgetSetup("williambutler2")
        inst.components.container.onopenfn = OnOpen
        inst.components.container.onclosefn = OnClose
        inst.components.container.skipopensnd = true
        inst.components.container.skipclosesnd = true

        inst:AddComponent("combat")
        inst.components.combat.hiteffectsymbol = "torso"
        inst.components.combat:SetRange(3)
        inst.components.combat:SetKeepTargetFunction(nokeeptargetfn)

        inst:ListenForEvent("docookery", oncook)



        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        inst.components.follower.keepleaderduringminigame = true

        inst.components.fueled:SetUpdateFn(fuelupdate)
        inst.components.fueled:SetDepletedFn(OnFuelEmpty)

        inst:SetBrain(brain)

        MakeMediumBurnableCharacter(inst, "torso")
        MakeMediumFreezableCharacter(inst, "torso")

        inst.components.fueled:StartConsuming()

        inst.components.burnable.ignorefuel = true
        inst:AddComponent("cooker")

    -- Wrapper Save/Load (padrão Buster - preserva dados do active())
    local old_OnSaveButler2 = inst.OnSave
    inst.OnSave = function(inst, data)
        if old_OnSaveButler2 then old_OnSaveButler2(inst, data) end
        data.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0
        data.was_mk3 = inst.was_mk3 or false
    end

    local old_OnLoadButler2 = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if old_OnLoadButler2 then old_OnLoadButler2(inst, data) end
        if data then
            inst.upgradelevel_mk3 = data.upgradelevel_mk3 or 0
            inst.was_mk3 = data.was_mk3 or false
        end
        -- Atualiza o nome após carregar
        inst:DoTaskInTime(0, function()
            if inst.components.named then UpdateButlerName(inst) end
        end)
    end

        -- BUTLER MK.II -> MK.III UPGRADE (70 scraps total, 5 per hit)
        inst.upgradelevel_mk3 = inst.upgradelevel_mk3 or 0

        UpdateButlerName(inst)
        inst:ListenForEvent("fuelchange", function() UpdateButlerName(inst) end)
        inst:ListenForEvent("healthdelta", function() UpdateButlerName(inst) end)
        -- v2.0.16: Add periodic task for MK2 (was missing — hover not refreshing)
        inst:DoPeriodicTask(2, function() UpdateButlerName(inst) end)

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
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                return
            end
            inst.components.engieworkable:SetWorkLeft(1)
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end

            -- PRIORITY 1: Repair if HP < 100% (NO skill required)
            if inst.components.health.currenthealth < inst.components.health.maxhealth then
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

            -- PRIORITY 2: Upgrade to MK.III if HP = 100% AND skill learned (70 scraps, 5 per hit)
            if not _G.WagstaffHasSkill(worker, "wagstaff_thermal_upgrade_mk3") then
                if worker.components.talker then
                    worker.components.talker:Say("Requires Butler MK. II skill!\n(Activate it in the skill tree!)")
                end
                return
            end

            -- MK.III Upgrade: 5 scraps per hit, 70 total
            local scrap_count = 0
            if worker.components.inventory then
                for _, item in pairs(worker.components.inventory.itemslots) do
                    if item ~= nil and item.prefab == "scrap" and item.components.stackable then
                        scrap_count = scrap_count + item.components.stackable:StackSize()
                    elseif item ~= nil and item.prefab == "scrap" then
                        scrap_count = scrap_count + 1
                    end
                end
            end
            local upgrade_cost = _G.WagstaffMechanicalEfficiencyRoll(worker, 5)
            if upgrade_cost > 0 and scrap_count < upgrade_cost then
                if worker.components.talker then
                    worker.components.talker:Say("Need 5 Scrap Metal!")
                end
                return
            end
            if upgrade_cost > 0 then
                worker.components.inventory:ConsumeByName("scrap", upgrade_cost)
            end
            inst.upgradelevel_mk3 = inst.upgradelevel_mk3 + 5
            UpdateButlerName(inst)

            if inst.upgradelevel_mk3 >= 70 then
                inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
                if worker.components.talker then
                    worker.components.talker:Say("Butler Bot MK. III upgrade complete!")
                end

                -- Spawn MK.III version
                local pt = inst:GetPosition()
                local newbot = SpawnPrefab("williambutler3")
                if newbot ~= nil then
                    newbot.Transform:SetPosition(pt.x, pt.y, pt.z)
                    newbot.Transform:SetRotation(inst.Transform:GetRotation())
                    newbot.was_mk3 = true

                    if inst.components.fueled and newbot.components.fueled then
                        newbot.components.fueled.currentfuel = inst.components.fueled.currentfuel
                    end
                    if inst.components.health and newbot.components.health then
                        newbot.components.health:SetCurrentHealth(inst.components.health.currenthealth)
                    end
                    if inst.components.container and newbot.components.container then
                        for slot = 1, 3 do
                            local item = inst.components.container:GetItemInSlot(slot)
                            if item ~= nil then
                                newbot.components.container:GiveItem(item, slot)
                            end
                        end
                    end

                    if inst.components.follower and newbot.components.follower then
                        local leader = inst.components.follower:GetLeader()
                        if leader ~= nil then
                            newbot.components.follower:SetLeader(leader)
                            newbot.components.follower:SetLeader(leader)
                        end
                    end

                    SpawnPrefab("small_puff").Transform:SetPosition(pt.x, pt.y, pt.z)
                end

                inst:Remove()
            end
        end)

        return inst
    end

    --==================================================================================
    -- BUTLER BOT v3: Master Chef
    -- Spawned by wrench upgrade on MK.II butler (60 scraps total for MK.II->MK.III)
    --==================================================================================
    local function active3(inst)
        local inst = active2(inst)

        inst:SetPrefabNameOverride("williambutler3")
        inst:AddTag("butler_master_chef")

        if not TheWorld.ismastersim then
            return inst
        end

        -- v2.0.15: MK3 gets +100 HP (→300) so it survives longer as a follower
        if inst.components.health then
            inst.components.health:SetMaxHealth(TUNING.WILLIAM_BUTLER_HEALTH + 100)
            inst.components.health:SetCurrentHealth(inst.components.health.maxhealth)
        end

        -- Slightly larger with golden tint
        inst.Transform:SetScale(1.1, 1.1, 1.1)
        inst.AnimState:SetMultColour(1, 0.95, 0.7, 1)

        -- Ensure Mk.III identity is persistent across saves
        inst.was_mk3 = true

        -- Affinity pulse (MK3 only)
        -- v2.0.55: Phase-gate the pulse to match the affinity effect's active
        -- window. The butler's affinity cooking/effect only fires during
        -- DAY+celestial or DUSK+shadow (see cook + food checks). Without this
        -- gate the pulse lit up during battle even in the "weak" passive phase,
        -- which was visually misleading.
        AffinityPulse.Setup(inst, GetOwner, {
            phase_check = function(inst, owner)
                if not (owner and owner:IsValid()) then return false end
                local celestial = owner:HasTag("wagstaff_celestial_possession")
                local shadow    = owner:HasTag("wagstaff_shadow_possession")
                return (TheWorld.state.isday and celestial)
                    or (TheWorld.state.isdusk and shadow)
            end,
        })

        -- Celestial light + aura (MK3 only)
        inst._celestial_light = nil
        inst._aura_fx = nil
        inst._shadow_fx = nil
        inst:DoPeriodicTask(3, function()
            if TheWorld.state.isday and OwnerHasCelestial(inst) then
                -- Add light component to bot
                if inst._celestial_light == nil then
                    inst.entity:AddLight()
                    inst._celestial_light = true
                end
                if inst.Light then
                    inst.Light:SetRadius(2)
                    inst.Light:SetIntensity(0.45)
                    inst.Light:SetFalloff(0.8)
                    inst.Light:SetColour(0.7, 0.85, 1)
                    inst.Light:Enable(true)
                end
                
                -- NOVA AURA CELESTIAL - só quando ativo (nil = inicialmente ativo)
                if inst.on ~= false and (inst._aura_fx == nil or not inst._aura_fx:IsValid()) then
                    inst._aura_fx = SpawnPrefab("bot_aura_butler")
                    if inst._aura_fx then
                        inst._aura_fx._parent = inst
                    end
                end
                
                -- Remove shadow FX if present
                if inst._shadow_fx ~= nil and inst._shadow_fx:IsValid() then
                    inst._shadow_fx:Remove()
                    inst._shadow_fx = nil
                end
            else
                if inst.Light then
                    inst.Light:Enable(false)
                end
                inst._celestial_light = nil
                if inst._aura_fx ~= nil and inst._aura_fx:IsValid() then
                    inst._aura_fx:Remove()
                    inst._aura_fx = nil
                end
            end
        end)

        -- v2.0.40: MK3 name is handled by the SAME UpdateButlerName function
        -- that active2 already wired up (periodic task + fuelchange/healthdelta
        -- events). UpdateButlerName checks inst.prefab == "williambutler3" and
        -- uses "Butler Bot Mk. III" as the base. The previous separate
        -- UpdateButler3Name used a DIFFERENT format ("Mk.III" with no space)
        -- and fought with the periodic UpdateButlerName task, causing the MK3
        -- hover name to flicker/alternate between two strings every 2s — which
        -- looked like the name was "repeating". Removed the duplicate function.
        if inst.components.named == nil then
            inst:AddComponent("named")
        end
        -- Set initial name immediately (periodic task will refresh every 2s).
        UpdateButlerName(inst)

        -- v2.0.19: Butler haunt-resurrection is now a PLAIN revive.
        -- The bot dies and the player respawns (classic DST behavior).
        -- Affinity abilities (celestial revive-buff / shadow clone) are now
        -- decoupled from the butler and trigger globally on the player's
        -- respawnfromghost event -- see scripts/wagstaff_affinity_revive.lua.
        inst:AddComponent("hauntable")
        inst.components.hauntable:SetOnHauntFn(function(inst, haunter)
            if haunter:HasTag("playerghost") and inst.prefab == "williambutler3" then
                -- Standard revive (player respawns). The global affinity-revive
                -- hook (wagstaff_affinity_revive) applies the celestial/shadow
                -- ability based on the player's possession tags.
                haunter:PushEvent("respawnfromghost", { source = inst })
                -- Butler always dies on revive (classic behavior).
                _dbg("[BUTLER REVIVE] plain revive (bot dies); affinity handled globally")
                inst.components.health:Kill()
                return true
            end
            return false
        end)

        -- MK3 reload resync: re-aplica FX celestial/shadow imediatamente após save->reload
        local old_OnLoad3 = inst.OnLoad
        inst.OnLoad = function(inst2, data)
            if old_OnLoad3 then old_OnLoad3(inst2, data) end
            if not TheWorld.ismastersim then return end
            inst2:DoTaskInTime(0, function()
                if not inst2:IsValid() then return end
                local owner = inst2.components.follower and inst2.components.follower:GetLeader()
                local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
                local shadow = owner and owner:HasTag("wagstaff_shadow_possession")
                if TheWorld.state.isday and celestial then
                    if inst2._celestial_light == nil then inst2.entity:AddLight(); inst2._celestial_light = true end
                    if inst2.Light then inst2.Light:Enable(true); inst2.Light:SetRadius(2); inst2.Light:SetIntensity(0.45); inst2.Light:SetColour(0.7,0.85,1) end
                    if inst2.on ~= false and (inst2._aura_fx == nil or not inst2._aura_fx:IsValid()) then
                        inst2._aura_fx = SpawnPrefab("bot_aura_buster")
                        if inst2._aura_fx then inst2._aura_fx._parent = inst2 end
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

        -- Repair system for MK3 + MK.III upgrade (60 scraps from MK.II to MK.III only - not applicable here since we spawn directly)
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
            if inst.sg ~= nil and inst.sg:HasStateTag("shutdown") then
                return
            end
            inst.components.engieworkable:SetWorkLeft(1)
            local wrench = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if wrench ~= nil and wrench.prefab == "tf2wrench" and wrench.components.finiteuses ~= nil then
                wrench.components.finiteuses:Use(1)
            end
            if inst.components.health.currenthealth >= inst.components.health.maxhealth then
                if worker.components.talker then
                    worker.components.talker:Say("HP is already full!")
                end
                return
            end
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
        end)

        return inst
    end

-- EMPTY butler


    local function empty(inst)
        local inst = fn(inst)

        inst.AnimState:PlayAnimation("sleep_loop", false)
        inst.AnimState:Pause()
        MakeCharacterPhysics(inst, 80, .25)
        inst.Physics:SetFriction(1)

        inst:AddTag("NOBLOCK")
        inst:AddTag("Notarget")
        inst:AddTag("mech")
        inst:AddTag("butler")
        inst:AddTag("tiddlevirusimmune")

    -- v2.0.65: mark empty husk as "off" so the brain's Deactivated gate
    -- (WhileNode inst.on == false) keeps it from following/teleporting to
    -- the leader. The husk inherits brain + follower from fn(), so without
    -- this the Follow node's catch-up teleport would drag the inert husk
    -- toward the player.
    inst.on = false

        if not TheWorld.ismastersim then
            return inst
        end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
            inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(onworked)

--    inst.components.fueled.currentfuel = 0

    -- v2.0.34: empty husk usa o mesmo loot do butler ativo (lootsetfn da fn()
    -- ja garante williamgadget + chance table "butler" da 50% boards/transistor).
    -- Antes o husk sobreecrevia para "butlergadget" (so gadget), mas isso
    -- deixava o husk sem bonus de materiais. Agora e consistente com o bot ativo.

    -- v2.0.74 FIX: reverted to original mod's husk design (mirrors buster v2.0.72).
    -- The husk needs only TWO things for reactivation to work:
    --   1. `willyraise` component (inherited from fn()) — gives the right-click
    --      WILLYRAISE action. When the player right-clicks the fueled husk,
    --      WILLYRAISE.fn calls willyraise:Rise(doer) -> MakeAlive(inst, doer)
    --      -> spawns a new active butler at the correct MK level.
    --   2. `workable` HAMMER — for dismantling with a hammer.
    --
    -- The previous code (v2.0.18 "fix") added a SetHuskAction helper +
    -- percentusedchange listener that swapped workable's action from HAMMER
    -- to ACTIVATE when fuel was present. This BROKE reactivation in-session
    -- because:
    --   - When workable has ACTIVATE, DST shows ACTIVATE as the right-click
    --     action instead of WILLYRAISE (workable takes priority).
    --   - The ACTIVATE path calls workable's OnFinishCallback, which is a
    --     different code path than willyraise:Rise -> MakeAlive.
    --   - The percentusedchange listener only fired reliably after save/load,
    --     so the player had to relog to reactivate the husk.
    --
    -- User reported: "o butler esta com o bug de acabou o fuel nao ativa
    -- mais mesmo que reabastecca, tem que relogar." This is the exact same
    -- bug the buster had (fixed in v2.0.72). Applying the same revert.
    --
    -- The husk has no follower component (follower is added in active(), not
    -- fn()), so the WILLYRAISE action condition (inst.replica.follower == nil)
    -- passes and the action appears on right-click.
    inst.components.fueled.accepting = true

    -- Save/load husk state (for reactivating at correct level)
    local function OnSaveHusk(inst, data)
        data.was_level2 = inst.was_level2
        data.was_mk3 = inst.was_mk3
        data.saved_upgradelevel = inst.saved_upgradelevel
        data.saved_upgradelevel_mk3 = inst.saved_upgradelevel_mk3
    end

    local function OnLoadHusk(inst, data)
        if data then
            inst.was_level2 = data.was_level2 or false
            inst.was_mk3 = data.was_mk3 or false
            inst.saved_upgradelevel = data.saved_upgradelevel or 0
            inst.saved_upgradelevel_mk3 = data.saved_upgradelevel_mk3 or 0
        end
    end

    inst.OnSave = OnSaveHusk
    inst.OnLoad = OnLoadHusk

    MakeHauntableWork(inst)

        return inst
    end


local function onbuilt(inst, builder)
    local theta = math.random() * 2 * PI
    local pt = builder:GetPosition()
    local radius = math.random(1, 2)
    local offset = FindWalkableOffset(pt, theta, radius, 12, true, true, NoHoles)
    if offset ~= nil then
        pt.x = pt.x + offset.x
        pt.z = pt.z + offset.z
    end
   local pet = builder:HasTag("williamcrafter") and builder.components.petleash:SpawnPetAt(pt.x, 0, pt.z, "williambutler") or SpawnPrefab("williambutler_empty")
        if pet ~= nil then
            if pet.sg ~= nil then
                pet.sg:GoToState("spawn") 
            else
                pet.Transform:SetPosition(pt.x, 0, pt.z)
        pet.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
        SpawnPrefab("small_puff").Transform:SetPosition(pt.x, 0, pt.z)
            end
pet.components.fueled.currentfuel = pet.components.fueled.currentfuel*0.9
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


    return Prefab("williambutler", active, assets, prefabs),
    Prefab("williambutler2", active2, assets, prefabs),
    Prefab("williambutler3", active3, assets, prefabs),
    Prefab("williambutler_builder", builder, assets, prefabs),
    Prefab("williambutler_empty", empty, assets, prefabs)



--------------------------------------------------------------------------