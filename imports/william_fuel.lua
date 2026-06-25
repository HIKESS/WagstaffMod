-- ============================================================================
-- William Fuel System (v2.0.75)
-- ============================================================================
-- Per-material fuel balancing for all 4 Wagstaff bots.
--
-- PROBLEM (user-reported):
--   The fork had nerfed `fueled.bonusmult` from 5 -> 1 on all bots, making
--   every fuel item give 5x LESS than the original mod design. Standard DST
--   materials (log=30s, cutgrass=7.5s) were nearly useless. Additionally,
--   the buster's VALID_BUSTER_FUELS list (gears/transistor/trinket_6) was
--   dead code because those items don't have a DST `fuel` component, so
--   DST's default `fueled:TakeFuelItem` rejected them before our OnAddFuel
--   callback ever ran.
--
-- SOLUTION:
--   1. Restore original bonusmult (5x for brute/buster/butler, 3x ballistic)
--      so standard DST fuels (log, cutgrass, etc.) give proper value again.
--   2. Add a custom fuel table for NON-STANDARD materials (gears, transistor,
--      scrap, trinket_6, nitre, flint, goldnugget, rotton, etc.) that don't
--      have a DST `fuel` component. These give EXPLICIT fuel values (no
--      bonusmult — controlled per-material).
--   3. Use SetFuelAcceptingTest to restrict what each bot accepts, so each
--      bot has a thematically appropriate fuel diet:
--        BRUTE:    mechanical + wood + plant + minerals (omnivore)
--        BUTLER:   wood + plant + organic + some mechanical (household)
--        BUSTER:   mechanical ONLY (picky combat bot)
--        BALLISTIC: chemical/electrical minerals ONLY (battery bot)
--   4. Hook fueled:TakeFuelItem to intercept custom materials and give them
--      explicit fuel values. Standard DST fuels fall through to the original
--      method (with bonusmult applied).
--
-- FUEL ECONOMY (with bonusmult = 5, per material, seconds of burn time):
--   Standard fuels (via DST default + bonusmult):
--     log       = 30 * 5 = 150s  (5 seg)
--     cutgrass  = 7.5 * 5 = 37.5s (1.25 seg)
--     pinecone  = 15 * 5 = 75s   (2.5 seg)
--   Custom fuels (explicit, NO bonusmult):
--     gears     = 180s  (6 seg)  — rare, high value
--     transistor= 120s  (4 seg)  — crafted
--     trinket_6 = 100s  (~3.3 seg) — frazzled wires, graveyard find
--     scrap     = 60s   (2 seg)  — common industrial
--     nitre     = 150s  (5 seg)  — chemical
--     flint     = 60s   (2 seg)
--     goldnugget= 200s  (~6.7 seg) — valuable conductor
--     rotton    = 25s   (~0.8 seg) — butler compost
--
-- Max fuel tanks (seconds):
--   Brute:    2400s (80 seg, ~5 days)  — needs ~16 logs or ~14 gears to fill
--   Butler:   1920s (64 seg, ~4 days)  — needs ~13 logs or ~10 gears
--   Buster:   1440s (48 seg, ~3 days)  — needs ~10 logs or ~8 gears
--   Ballistic:3630s (121 seg, ~7.5d)   — needs ~25 nitre or ~19 goldnuggets
-- ============================================================================

local WILLIAM_FUEL = {}

-- Custom fuel values for materials WITHOUT a DST `fuel` component.
-- Values are in SECONDS of burn time. These do NOT get bonusmult applied
-- (the values are final, controlled per-material).
WILLIAM_FUEL.CUSTOM_VALUES = {
    -- Mechanical / Industrial
    gears      = 180,  -- 6 seg — rare, high-value mechanical
    transistor = 120,  -- 4 seg — crafted electronic
    trinket_6  = 100,  -- ~3.3 seg — frazzled wires (graveyard/trinket)
    scrap      = 60,   -- 2 seg — common industrial metal

    -- Minerals / Chemical / Electrical
    nitre      = 150,  -- 5 seg — chemical fuel (ballistic primary)
    flint      = 60,   -- 2 seg — spark-producing mineral
    goldnugget = 200,  -- ~6.7 seg — valuable conductor

    -- Organic / Compost (butler)
    rotton      = 25,  -- ~0.8 seg — decomposed organic
    spoiled_food= 20,  -- ~0.67 seg
    foliage     = 20,  -- ~0.67 seg — plant matter
    petalfin   = 15,  -- 0.5 seg
}

-- Per-bot accepted fuel lists.
-- Keys are prefab names. If true, the bot accepts that material.
-- Standard DST fuel items (log, cutgrass, etc.) are accepted if listed here
-- AND the item has a `fuel` component (DST handles the value + bonusmult).
-- Custom materials (gears, transistor, etc.) are accepted if listed here
-- AND exist in CUSTOM_VALUES (our hook gives the explicit value).

-- BRUTE: omnivore industrial — accepts everything mechanical + basic fuels
WILLIAM_FUEL.BRUTE = {
    -- Mechanical
    gears = true, transistor = true, trinket_6 = true, scrap = true,
    -- Wood
    log = true, boards = true, livinglog = true,
    -- Plant
    cutgrass = true, twigs = true, pinecone = true,
    -- Minerals
    nitre = true, flint = true,
}

-- BUTLER: household — prefers organic/wood, some mechanical
WILLIAM_FUEL.BUTLER = {
    -- Wood (primary)
    log = true, boards = true, livinglog = true,
    -- Plant
    cutgrass = true, twigs = true, pinecone = true, foliage = true,
    -- Organic compost
    rotton = true, spoiled_food = true,
    -- Mechanical (less efficient but accepted)
    gears = true, transistor = true,
}

-- BUSTER: picky combat bot — mechanical ONLY (no wood/plant)
WILLIAM_FUEL.BUSTER = {
    gears = true, transistor = true, trinket_6 = true, scrap = true,
}

-- BALLISTIC: electrical/chemical battery — minerals ONLY
WILLIAM_FUEL.BALLISTIC = {
    nitre = true, flint = true, goldnugget = true,
    transistor = true, trinket_6 = true,
}

-- ----------------------------------------------------------------------------
-- Setup function: apply the custom fuel system to a bot's fueled component.
--
-- Usage in each bot's fn():
--   local WILLIAM_FUEL = require("imports/william_fuel")
--   WILLIAM_FUEL.Setup(inst, WILLIAM_FUEL.BRUTE, 5)  -- brute, bonusmult=5
--
-- Parameters:
--   inst         — the bot entity (must have fueled component already added)
--   fuel_list    — the per-bot accepted fuels table (e.g. WILLIAM_FUEL.BRUTE)
--   bonus_mult   — multiplier for STANDARD DST fuels (default 1; use 5 to
--                  match original mod design for brute/buster/butler, 3 for
--                  ballistic)
-- ----------------------------------------------------------------------------
function WILLIAM_FUEL.Setup(inst, fuel_list, bonus_mult)
    if not inst or not inst.components or not inst.components.fueled then
        print("[WILLIAM_FUEL] ERROR: inst has no fueled component")
        return
    end

    local fueled = inst.components.fueled
    bonus_mult = bonus_mult or 1

    -- 1. Set bonusmult for standard DST fuels
    fueled.bonusmult = bonus_mult

    -- 2. Set the fuel accepting test: accept items in our fuel_list.
    --    This OVERRIDES DST's default fueltype check, so we must accept
    --    both custom materials (in CUSTOM_VALUES) AND standard fuel items
    --    (items with components.fuel) that are in our list.
    fueled:SetFuelAcceptingTest(function(inst, item)
        if item == nil or item.prefab == nil then return false end
        -- Must be in the bot's accepted list
        if not fuel_list[item.prefab] then return false end
        -- Accept if it's a custom material (we'll give it explicit value)
        if WILLIAM_FUEL.CUSTOM_VALUES[item.prefab] then
            return true
        end
        -- Accept if it's a standard DST fuel item (has fuel component)
        if item.components and item.components.fuel then
            return true
        end
        -- Reject anything else (e.g. a listed prefab that's neither custom
        -- nor has a fuel component — shouldn't happen with our lists, but
        -- be safe)
        return false
    end)

    -- 3. Hook TakeFuelItem to intercept custom materials and give them
    --    explicit fuel values (no bonusmult). Standard fuels fall through
    --    to the original method (with bonusmult applied via fueled.bonusmult).
    if fueled._william_fuel_hooked ~= true then
        local _orig_TakeFuelItem = fueled.TakeFuelItem

        fueled.TakeFuelItem = function(self, item, doer)
            -- Guard: nil/invalid item
            if item == nil or not item:IsValid() then
                return false
            end

            -- Custom material: give explicit fuel value (no bonusmult)
            if item.prefab and WILLIAM_FUEL.CUSTOM_VALUES[item.prefab] then
                -- Verify it's in this bot's accepted list
                if not fuel_list[item.prefab] then
                    return false
                end
                -- Don't add if already full
                if self:IsFull() then
                    -- Let ontakefuelfn handle the "already full" feedback
                    if self.ontakefuelfn then
                        self.ontakefuelfn(self.inst, 0, item)
                    end
                    return false
                end
                -- Calculate fuel value (explicit, no bonusmult)
                local fuel_value = WILLIAM_FUEL.CUSTOM_VALUES[item.prefab]
                -- Add the fuel
                self:DoDelta(fuel_value, true)
                -- Call ontakefuelfn callback (plays sound, updates display, etc.)
                if self.ontakefuelfn then
                    self.ontakefuelfn(self.inst, fuel_value, item)
                end
                -- Consume ONE item from the stack (or the item itself)
                if item.components.stackable then
                    item.components.stackable:Get():Remove()
                else
                    item:Remove()
                end
                return true
            end

            -- Standard fuel: delegate to original DST method (bonusmult applies)
            return _orig_TakeFuelItem(self, item, doer)
        end

        fueled._william_fuel_hooked = true
    end
end

-- Export to GLOBAL so prefab files can access it via _G.WILLIAM_FUEL
-- (modimport doesn't capture return values, so we must set it on GLOBAL)
GLOBAL.WILLIAM_FUEL = WILLIAM_FUEL

return WILLIAM_FUEL
