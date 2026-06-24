-- ============================================================================
-- Wagstaff Standalone (Integrated) — modmain.lua
-- Merges the clean Hamlet Characters Wagstaff (character + assets + scripts)
-- WITH the Wagstaff Integration Patch features (skill tree, XP progression,
-- William Toymaker bots, Engineer sentry/dispenser/eteleporter, augment +
-- flicker actions, boss kill tracking).
-- Skill XP uses DST's standard skill tree persistence (per-character profile).
-- ============================================================================


local G = GLOBAL

-- Get rawset and rawget from the real global table
local rawset = G.rawset
local rawget = G.rawget

-- Safe aliases for Lua base functions.
--
-- In DST mods, `modmain.lua` runs inside a sandbox environment (a copy of _G).
-- Closures passed to DoTaskInTime / ListenForEvent / scheduler callbacks may,
-- in certain runtime contexts, execute with an _ENV that does NOT expose the
-- standard Lua builtins, causing `attempt to call global '<fn>' (a nil value)`
-- crashes. Binding these functions as upvalues (captured at mod-load time, when
-- the environment is still intact) makes every closure in this file immune to
-- that problem. `G.<fn>` resolves against the real game `_G`, which always has
-- these builtins; the `or <fn>` fallback preserves the previous behavior in the
-- (theoretical) case where even `G.<fn>` is unavailable.
--
-- This fixes the crash at modmain.lua:2014:
--   "attempt to call global 'pcall' (a nil value)"
-- reported in a client-side DoTaskInTime callback.
local pairs        = G.pairs        or pairs
local ipairs       = G.ipairs       or ipairs
local next         = G.next         or next
local pcall        = G.pcall        or pcall
local xpcall      = G.xpcall      or xpcall
local tostring     = G.tostring     or tostring
local tonumber     = G.tonumber     or tonumber
local type         = G.type         or type
local select       = G.select       or select
local print        = G.print        or print
local error        = G.error        or error
local assert       = G.assert       or assert
local setmetatable = G.setmetatable or setmetatable
local getmetatable = G.getmetatable or getmetatable
local unpack       = G.unpack       or unpack

-- Safe table printer (circular-ref aware, depth-limited)
local function tableToString(t, indent, depth, visited)
    indent = indent or ""
    depth = depth or 0
    visited = visited or {}
    if depth > 2 then return "<table depth limit>" end
    if type(t) ~= "table" then return tostring(t) end
    if visited[t] then return "<circular ref>" end
    visited[t] = true
    local result = "{"
    local first = true
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
        if count > 10 then
            result = result .. ", ... (+more)"
            break
        end
        if not first then
            result = result .. ", "
        end
        first = false
        local keyStr = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
        local valStr
        if type(v) == "table" then
            -- Evitar recursão em tabelas conhecidas por causar loop (como TheWorld.state)
            if v._iscomponent or v._isclock or v._isentity then
                valStr = "<" .. (v.prefab or v._name or type(v)) .. ">"
            else
                valStr = tableToString(v, indent .. "  ", depth + 1, visited)
            end
        elseif type(v) == "string" then
            valStr = '"' .. v .. '"'
        elseif type(v) == "function" or type(v) == "userdata" then
            valStr = "<" .. type(v) .. ">"
        else
            valStr = tostring(v)
        end
        result = result .. "\n" .. indent .. "  " .. keyStr .. " = " .. valStr
    end
    result = result .. "\n" .. indent .. "}"
    visited[t] = nil -- Libera para permitir re-visita em outros contextos
    return result
end

-- ============================================================================
-- WAGSTAFF DEBUG SYSTEM (BUFFERED)
-- Buffers debug lines in memory and flushes to file every 5 seconds to avoid
-- freezing the game with file I/O on every call (especially in hot paths like
-- IsActivated which the skill tree UI calls many times per second).
--
-- REVERTED (v2.0.5): The v2.0.3/v2.0.4 rewrite of this system used
-- TheSim:SetPersistentString() to write the debug file. This caused a crash
-- (OLDFILEACCESSMETHOD) when loading skilltree_wagstaff.lua via require().
-- The exact mechanism is unclear (even with deferred I/O the crash persisted),
-- but reverting to the original G.io.open()-based flush (which silently no-ops
-- because io is nil in the DST sandbox) eliminates the crash. Traces still
-- reach the game logs via print() — use: grep "\[Wagstaff" *_log.txt
-- ============================================================================
G.WagstaffDebugEnabled = GetModConfigData("debug") == true

-- Get the mod directory properly using TheModManager or MODROOT
local function get_mod_directory()
    local moddir = "."
    -- First try MODROOT which is set by the game for each mod
    if MODROOT and MODROOT ~= "" then
        return MODROOT
    end
    -- Fallback: Try to get our mod's directory from TheModManager
    if G.TheModManager then
        for _, mod in pairs(G.TheModManager.mods) do
            if mod and mod.modinfo and mod.modinfo.id then
                if mod.modinfo.id == "wagstaff_standalone" or
                   string.find(mod.modinfo.id, "wagstaff") or
                   string.find(mod.modinfo.name, "Wagstaff") then
                    moddir = mod.path or mod.modpath or moddir
                    break
                end
            end
        end
    end
    return moddir
end

local _moddir = get_mod_directory()
local _debug_log_path = _moddir .. "/wagstaff_debug.txt"
local _debug_buffer = {}  -- lines collected in memory, flushed periodically
local _debug_max_buffer = 500  -- flush early if buffer gets this big

-- Flush the buffer to the debug log file (batch write — one open/close per flush)
local function wagstaff_debug_flush()
    if #_debug_buffer == 0 then return end
    local iolib = G.io
    if iolib == nil then _debug_buffer = {} return end
    local ok, file = G.pcall(iolib.open, _debug_log_path, "a")
    if ok and file then
        for i = 1, #_debug_buffer do
            file:write(_debug_buffer[i] .. "\n")
        end
        file:close()
    end
    _debug_buffer = {}
end

-- Clear the debug log on mod load (fresh session)
if G.WagstaffDebugEnabled then
    local iolib = G.io
    if iolib then
        local ok, file = G.pcall(iolib.open, _debug_log_path, "w")
        if ok and file then
            file:write("=== Wagstaff Standalone Debug Log ===\n")
            file:write("=== Session start ===\n\n")
            file:close()
        end
    end
    print("[Wagstaff Debug] Debug mode ON. Log file: " .. _debug_log_path)
    -- Schedule periodic flush every 5 seconds (only runs when world exists)
    -- AddSimPostInit is a modutil function available directly in modmain scope
    AddSimPostInit(function()
        if GLOBAL.TheWorld then
            GLOBAL.TheWorld:DoPeriodicTask(5, wagstaff_debug_flush)
        end
    end)
end

local _wagstaff_debug_last_say = 0
local function wagstaff_debug_emit(str)
    -- 1. Buffer the line (flushed every 5s — NOT on every call)
    local ts = (G.GetTime and G.GetTime()) or 0
    _debug_buffer[#_debug_buffer + 1] = G.string.format("[%.2f] %s", ts, str)
    if #_debug_buffer >= _debug_max_buffer then
        wagstaff_debug_flush()
    end
    -- 2. print() so it appears in server_log too (print is cheap, file I/O is not)
    print(str)
    -- 3. Mirror to in-game chat bubble (throttled, client-only)
    if G.ThePlayer and G.ThePlayer.components and G.ThePlayer.components.talker then
        if ts - _wagstaff_debug_last_say > 2 then
            _wagstaff_debug_last_say = ts
            G.ThePlayer.components.talker:Say(string.sub(str, 1, 120))
        end
    end
end
G.WagstaffDebug = function(...)
    if not G.WagstaffDebugEnabled then
        return
    end
    local args = {...}
    local str = "[Wagstaff Debug] "
    for i, arg in ipairs(args) do
        if i > 1 then
            str = str .. " "
        end
        if type(arg) == "table" then
            str = str .. tableToString(arg)
        else
            str = str .. tostring(arg)
        end
    end
    wagstaff_debug_emit(str)
end

-- Helper functions for debug
local function count_table(t)
    if not t or type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function dump_table_keys(t)
    if not t or type(t) ~= "table" then return "NIL or not a table" end
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, tostring(k))
    end
    if #keys == 0 then return "(empty table)" end
    return table.concat(keys, ", ")
end

-- Runtime toggle: type c_wagstaff_debug() in the console to flip debug on/off
-- without restarting. Announces the new state in-game.
G.c_wagstaff_debug = function()
    G.WagstaffDebugEnabled = not G.WagstaffDebugEnabled
    local msg = "[Wagstaff Debug] " .. (G.WagstaffDebugEnabled and "ENABLED" or "DISABLED")
    print(msg)
    if G.ThePlayer and G.ThePlayer.components and G.ThePlayer.components.talker then
        G.ThePlayer.components.talker:Say("Wagstaff Debug: " .. (G.WagstaffDebugEnabled and "ON" or "OFF"))
    end
    return msg
end
-- Runtime toggle for verbose debug: c_wagstaff_verbose()

-- Alias local para debug, seguro mesmo que G.WagstaffDebug ainda nao exista
local WagstaffDebug = (G.WagstaffDebug ~= nil) and G.WagstaffDebug or function(...) end

-- ============================================================================
-- v2.0.17: LIGHTWEIGHT DEBUG HELPERS (gated by the "Debug mode" mod config button)
-- ============================================================================
-- These are the preferred helpers for all debug print() calls across the mod.
-- They early-return BEFORE any string work when debug is OFF, so the mod does
-- not "pesar à toa" (no I/O, no formatting, no console mirroring).
--
-- Usage:
--   _dbg("[BUTLER REVIVE] haunt by ghost=", ghost.prefab, "shadow=", shadow)
--   _dbgF("[BUTLER COOK] prefab=%s isday=%s owner=%s", prefab, isday, owner)
--
-- When debug is OFF (default): both are zero-cost (single boolean check, return).
-- When debug is ON: behave exactly like print() / print(string.format()).
-- ============================================================================
G.WagstaffDbg = function(...)
    if not G.WagstaffDebugEnabled then return end
    print(...)
end

G.WagstaffDbgF = function(fmt, ...)
    if not G.WagstaffDebugEnabled then return end
    print(string.format(fmt, ...))
end

-- [REMOVED] RPC lookup/publish functions — no longer needed.
-- The engine's built-in skill tree RPC handles everything (matches reference mod pattern).

G.c_wagstaff_verbose = function()
    if not G.WagstaffDebugEnabled then
        print("[Wagstaff Debug] Enable debug mode first with c_wagstaff_debug()")
        return "Debug mode is OFF. Enable it first."
    end
    -- Toggle verbose by reusing the main debug flag logic or a separate internal flag
    -- For simplicity, we'll just use the main debug flag for now as verbose was removed from config
    local msg = "[Wagstaff Debug] Verbose logs are now part of the main Debug mode."
    print(msg)
    if G.ThePlayer and G.ThePlayer.components and G.ThePlayer.components.talker then
        G.ThePlayer.components.talker:Say("Wagstaff Debug: Verbose always ON when Debug is ON")
    end
    return msg
end
if G.WagstaffDebugEnabled then
    print("[Wagstaff Debug] Debug mode is ON at mod load. Use c_wagstaff_debug() to toggle at runtime.")
    print("[Wagstaff Debug] Verbose logs are enabled by default when Debug is ON.")
end
-- Also make a local alias for convenience
local WagstaffDebug = G.WagstaffDebug
local WagstaffVerboseDebug = function(...)
    -- Verbose is now always enabled when Debug is ON
    if G.WagstaffDebugEnabled then
        G.WagstaffDebug("[VERBOSE]", ...)
    end
end

-- Debug command to inspect TheSkillTree profile state
G.c_wagstaff_profile = function()
    print("=== Wagstaff TheSkillTree Profile Debug ===")
    if not GLOBAL.TheSkillTree then
        print("TheSkillTree is NIL!")
        return
    end
    -- Get XP
    local xp = nil
    G.pcall(function() xp = GLOBAL.TheSkillTree:GetSkillXP("wagstaff") end)
    print("XP:", tostring(xp))
    -- Get activated skills
    local skills = nil
    G.pcall(function() skills = GLOBAL.TheSkillTree:GetActivatedSkills("wagstaff") end)
    if not skills then
        print("GetActivatedSkills returned NIL")
    else
        print("Activated skills (raw):")
        if type(skills) == "table" then
            for i, v in GLOBAL.ipairs(skills) do
                print("  ["..tostring(i).."] type="..type(v).." value="..tostring(v))
            end
            -- Also check non-integer keys
            for k, v in pairs(skills) do
                if type(k) ~= "number" then
                    print("  [key="..tostring(k).."] type="..type(v).." value="..tostring(v))
                end
            end
        else
            print("  type="..type(skills).." value="..tostring(skills))
        end
    end
    -- Check player activatedskills
    local player = G.ThePlayer
    if player and player.components and player.components.skilltreeupdater then
        local activated = player.components.skilltreeupdater.activatedskills
        print("\nPlayer activatedskills table:")
        if activated then
            for k, v in pairs(activated) do
                print("  ["..tostring(k).."] = "..tostring(v))
            end
        else
            print("  NIL")
        end
        print("\nPlayer tags containing 'wagstaff_':")
        if player.GetTags then
            for i, tag in ipairs(player:GetTags()) do
                if type(tag) == "string" and tag:find("wagstaff_") then
                    print("  "..tag)
                end
            end
        else
            print("  (GetTags not available on server)")
        end
    end
    print("=== End Profile Debug ===")
end

-- Bypass strict mode for our variables
rawset(G, "strict", false)
G.WagstaffDebug("Standalone Wagstaff Integration mod is loading!")

-- [REMOVED] Custom MOD RPC for skill activation — no longer needed.
-- The engine's built-in skill tree RPC handles activation correctly.
-- This was causing connects chains to break by bypassing TheSkillTree updates.


local TUNING = GLOBAL.TUNING

-- Tropical Experience / Above The Clouds interop (gates the SPY action in postinits)
TUNING.HCRtropicalsupport = false
if GLOBAL.KnownModIndex:IsModEnabled("workshop-1505270912") then
    TUNING.HCRtropicalsupport = true
end
print("    [Wagstaff Standalone]: Tropical support is set to: " .. tostring(TUNING.HCRtropicalsupport))


--==================================================================================

-- SAFETY PATCH: WX78 shadow drone recipe crash for non-WX78 characters

-- wx78_shadowdrone_harvester's getlimitedrecipecount calls

-- builder:GetNumFreeShadowDrone_Harvesters() on every player that opens the

-- crafting menu. Non-WX78 characters don't have this method -> crash.

-- We wrap GetAllRecipeCraftingLimits on builder_replica to add the stub

-- just before the recipe iteration, which is timing-independent.

--==================================================================================

AddComponentPostInit("builder_replica", function(self)

    local old_GARL = self.GetAllRecipeCraftingLimits

    if old_GARL then

        self.GetAllRecipeCraftingLimits = function(self2, ...)

            if self2.inst and self2.inst.wx78_classified == nil then

                self2.inst.wx78_classified = {}

            end

            if self2.inst and self2.inst.wx78_classified then

                -- Add ALL WX78 drone methods

                local wx_methods = {

                    "GetNumFreeShadowDrone_Harvesters",

                    "GetNumFreeDeliveryDrones",

                    "GetMaxShadowDrone_Harvesters",

                    "GetNumFreeShadowDrone_Debuffers",

                    "GetMaxShadowDrone_Debuffers",

                    "GetNumFreeShadowDrone_Defenders",

                    "GetMaxShadowDrone_Defenders",

                }

                for _, method in ipairs(wx_methods) do

                    if self2.inst.wx78_classified[method] == nil then

                        self2.inst.wx78_classified[method] = function() return 0 end

                    end

                    if self2.inst[method] == nil then

                        self2.inst[method] = function() return 0 end

                    end

                    if self2.classified and self2.classified[method] == nil then

                        self2.classified[method] = function() return 0 end

                    end

                end

            end

            return old_GARL(self2, ...)

        end

    end

end)


--==================================================================================

-- RECIPE CRAFTING LIMIT SAFETY PATCH (WX78 drone recipes)

--==================================================================================

AddSimPostInit(function()

    local AllRecipes = G.AllRecipes

    if not AllRecipes then return end

    local patched = 0

    for _, recipe in pairs(AllRecipes) do

        if recipe.getlimitedrecipecount then

            local old_fn = recipe.getlimitedrecipecount

            recipe.getlimitedrecipecount = function(self_, builder)

                -- Ensure ALL wx78_classified functions exist

                if builder and builder.wx78_classified then

                    local wx_methods = {

                        "GetNumFreeShadowDrone_Harvesters",

                        "GetNumFreeDeliveryDrones",

                        "GetMaxShadowDrone_Harvesters",

                        "GetNumFreeShadowDrone_Debuffers",

                        "GetMaxShadowDrone_Debuffers",

                        "GetNumFreeShadowDrone_Defenders",

                        "GetMaxShadowDrone_Defenders",

                    }

                    for _, method in ipairs(wx_methods) do

                        if builder.wx78_classified[method] == nil then

                            builder.wx78_classified[method] = function() return 0 end

                        end

                    end

                end

                return old_fn(self_, builder) or 0

            end

            patched = patched + 1

        end

    end

    -- Patched recipe limit functions: " .. patched

end)


--==================================================================================

-- WINONA CATAPULT RESTRICTED TO WINONA ONLY (Wagstaff uses Ballistic Bot instead)

--==================================================================================

AddSimPostInit(function()

    local AllRecipes = G.AllRecipes

    if not AllRecipes then return end

    -- Restrict catapult recipe so only Winona can craft it
    -- Wagstaff has William's Ballistic Bot instead
    -- REMOVED: Winona catapult restrictions (not needed)

end)


-- Define global variables using G. (GLOBAL) so they are accessible in PrefabFiles

rawset(G, "ENGINEERITEMIMAGES", "images/engineeritemimages.xml")


rawset(G, "SENTRY_RANGE", 12)

rawset(G, "SENTRY_DAMAGE", 25)

rawset(G, "SENTRY_ROF", 1.5)

rawset(G, "SENTRY_HEALTH", 300)

rawset(G, "SENTRY_FF", "noff")

rawset(G, "SENTRY_FF_WALL", "yesff")


TUNING.SENTRY_ROCKET_DAMAGE = 50

TUNING.SENTRY_WRENCH_HEAL = 10

TUNING.ETELEPORT_PENALTY = 5  -- v2.0.15: sanity cost per teleport (was 0 = free unlimited travel)

TUNING.ENGIE_BUILDINGLOSS = 15


-- Dispenser tuning values

TUNING.DISP_HEALING = 0.5  -- Healing interval in seconds

TUNING.DISP_RANGE = 4      -- Range for dispenser effects


-- Engineer toolbox speed penalty (must be defined before prefabs load)

TUNING.TOOLBOX_SPEED_MULT = 0.15  -- 15% speed = 85% penalty


PrefabFiles = {
    -----[[Wagstaff (Hamlet Characters)]]---
    "wagstaff",
    "wagstaff_none",

    "goggles",
    "fryfocals_charge",

    "thumper",
    "telipad",
    "telebrella",
    "hiddendanger_fx",

    -----[[William Toymaker / Engineer (Integration Patch)]]---
    "williamgadget",

    "william_butler",
    "william_buster",
    "william_brute",
    "william_ballistic",

    "william_charge",
    "william_charged_fx",

    "william_mistake",

    "bot_aura_v5",  -- Aura FX v5 - APENAS FX reais verificados do jogo!

    "dispenser",

    "esentry",
    "esentry_bullet",
    "esentry_rocket",

    "eteleporter",
    "eteleporter_exit",
}


local forge_prefabs = {
    ---[[Wagstaff]]---
    "gogglesforgehat",
    "wagstaff_laser",
    "lavaarena_charge",
}

local gorge_prefabs = {
    ---[[Wagstaff]]---
    "quagmire_telebrella",
}


Assets = {
    ----------------------------------
    -----------[[Wagstaff]]-----------
    ----------------------------------

    Asset("IMAGE", "images/tinkeringtab.tex"),
    Asset("ATLAS", "images/tinkeringtab.xml"),

    Asset("IMAGE", "images/fx5.tex"),
    Asset("ATLAS", "images/fx5.xml"),

    Asset("IMAGE", "images/fx6.tex"),
    Asset("ATLAS", "images/fx6.xml"),

    Asset("IMAGE", "images/colour_cubes/heat_vision_cc.tex"),
    Asset("IMAGE", "images/colour_cubes/shooting_goggles_cc.tex"),

    Asset( "IMAGE", "images/saveslot_portraits/wagstaff.tex" ),
    Asset( "ATLAS", "images/saveslot_portraits/wagstaff.xml" ),

    Asset( "IMAGE", "bigportraits/wagstaff.tex" ),
    Asset( "ATLAS", "bigportraits/wagstaff.xml" ),

    Asset( "IMAGE", "images/map_icons/wagstaff.tex" ),
    Asset( "ATLAS", "images/map_icons/wagstaff.xml" ),

    Asset( "IMAGE", "images/avatars/avatar_wagstaff.tex" ),
    Asset( "ATLAS", "images/avatars/avatar_wagstaff.xml" ),

    Asset( "IMAGE", "images/avatars/avatar_ghost_wagstaff.tex" ),
    Asset( "ATLAS", "images/avatars/avatar_ghost_wagstaff.xml" ),

    Asset( "IMAGE", "images/avatars/self_inspect_wagstaff.tex" ),
    Asset( "ATLAS", "images/avatars/self_inspect_wagstaff.xml" ),

    Asset( "IMAGE", "images/names_wagstaff.tex" ),
    Asset( "ATLAS", "images/names_wagstaff.xml" ),
    Asset( "ATLAS", "images/names_gold_cn_wagstaff.xml" ),

    Asset( "IMAGE", "bigportraits/wagstaff_none.tex" ),
    Asset( "ATLAS", "bigportraits/wagstaff_none.xml" ),

    Asset("ATLAS", "images/inventoryimages/wagstaffnormalgoggles.xml"),
    Asset("IMAGE", "images/inventoryimages/wagstaffnormalgoggles.tex"),

    Asset("ATLAS", "images/inventoryimages/wagstaffheatgoggles.xml"),
    Asset("IMAGE", "images/inventoryimages/wagstaffheatgoggles.tex"),

    Asset("ATLAS", "images/inventoryimages/wagstaffarmorgoggles.xml"),
    Asset("IMAGE", "images/inventoryimages/wagstaffarmorgoggles.tex"),

    Asset("ATLAS", "images/inventoryimages/wagstaffshootgoggles.xml"),
    Asset("IMAGE", "images/inventoryimages/wagstaffshootgoggles.tex"),

    Asset("ATLAS", "images/inventoryimages/telebrella.xml"),
    Asset("IMAGE", "images/inventoryimages/telebrella.tex"),

    Asset("ATLAS", "images/inventoryimages/telipad.xml"),
    Asset("IMAGE", "images/inventoryimages/telipad.tex"),

    Asset("ATLAS", "images/inventoryimages/thumper.xml"),
    Asset("IMAGE", "images/inventoryimages/thumper.tex"),

    Asset( "ANIM", "anim/player_wagstaff.zip" ),
    Asset( "ANIM", "anim/player_mount_wagstaff.zip"),

    ------------------------
    -------[[Sounds]]-------
    ------------------------
    Asset( "SOUNDPACKAGE","sound/hamletcharactersound.fev" ),
    Asset( "SOUND", "sound/hamletcharactersound.fsb" ),

    Asset( "SHADER", "shaders/postprocess_blur.ksh"),

    ----------------------------------
    ----[[Integration Patch assets]]---
    ----------------------------------

    -- Engineer shared atlas (icons for all TF2 items)

    Asset("ATLAS", "images/engineeritemimages.xml"),

    Asset("IMAGE", "images/engineeritemimages.tex"),

    -- William Toymaker bots

    Asset("ATLAS", "images/inventoryimages/williambutler_builder.xml"),

    Asset("IMAGE", "images/inventoryimages/williambutler_builder.tex"),

    Asset("ATLAS", "images/inventoryimages/williambrute_builder.xml"),

    Asset("IMAGE", "images/inventoryimages/williambrute_builder.tex"),

    Asset("ATLAS", "images/inventoryimages/williambuster_builder.xml"),

    Asset("IMAGE", "images/inventoryimages/williambuster_builder.tex"),

    Asset("ATLAS", "images/inventoryimages/williamballistic_empty.xml"),

    Asset("IMAGE", "images/inventoryimages/williamballistic_empty.tex"),

    Asset("ATLAS", "images/inventoryimages/williamgadget.xml"),

    Asset("IMAGE", "images/inventoryimages/williamgadget.tex"),

    -- William Toymaker animation ZIPs

    Asset("ANIM", "anim/william_gadget.zip"),

    Asset("ANIM", "anim/william_butler.zip"),

    Asset("ANIM", "anim/william_buster.zip"),

    Asset("ANIM", "anim/william_brute.zip"),

    Asset("ANIM", "anim/william_ballistic.zip"),

    -- Butler Bot Level 2 uses vanilla ui_chest_3x2 + separate chef pouch storage

    -- Sentry skill tree icons

    Asset("ATLAS", "images/skilltree/MK2.xml"),

    Asset("IMAGE", "images/skilltree/MK2.tex"),

    Asset("ATLAS", "images/skilltree/mk3.xml"),

    Asset("IMAGE", "images/skilltree/mk3.tex"),

    Asset("ATLAS", "images/skilltree/disp2.xml"),

    Asset("IMAGE", "images/skilltree/disp2.tex"),

    Asset("ATLAS", "images/skilltree/disp3.xml"),

    Asset("IMAGE", "images/skilltree/disp3.tex"),

    Asset("ATLAS", "images/skilltree/Wrench.xml"),

    Asset("IMAGE", "images/skilltree/Wrench.tex"),

    Asset("ATLAS", "images/skilltree/luckyenginer.xml"),

    Asset("IMAGE", "images/skilltree/luckyenginer.tex"),

    Asset("ATLAS", "images/skilltree/doublestrike.xml"),

    Asset("IMAGE", "images/skilltree/doublestrike.tex"),

    Asset("ATLAS", "images/skilltree/brutemk2.xml"),

    Asset("IMAGE", "images/skilltree/brutemk2.tex"),

    Asset("ATLAS", "images/skilltree/brutemk3.xml"),

    Asset("IMAGE", "images/skilltree/brutemk3.tex"),

    Asset("ATLAS", "images/skilltree/bustermk2.xml"),

    Asset("IMAGE", "images/skilltree/bustermk2.tex"),

    Asset("ATLAS", "images/skilltree/bustermk3.xml"),

    Asset("IMAGE", "images/skilltree/bustermk3.tex"),

    Asset("ATLAS", "images/skilltree/balisticmk2.xml"),

    Asset("IMAGE", "images/skilltree/balisticmk2.tex"),

    Asset("ATLAS", "images/skilltree/balisticmk3.xml"),

    Asset("IMAGE", "images/skilltree/balisticmk3.tex"),

    Asset("ATLAS", "images/skilltree/buttlermk2.xml"),

    Asset("IMAGE", "images/skilltree/buttlermk2.tex"),

    Asset("ATLAS", "images/skilltree/buttlermk3.xml"),

    Asset("IMAGE", "images/skilltree/buttlermk3.tex"),

    Asset("ATLAS", "images/skilltree/roboefige.xml"),

    Asset("IMAGE", "images/skilltree/roboefige.tex"),

    Asset("ATLAS", "images/skilltree/sentrymk2.xml"),

    Asset("IMAGE", "images/skilltree/sentrymk2.tex"),

    Asset("ATLAS", "images/skilltree/sentrymk3.xml"),

    Asset("IMAGE", "images/skilltree/sentrymk3.tex"),

    Asset("ATLAS", "images/skilltree/doubledamage.xml"),

    Asset("IMAGE", "images/skilltree/doubledamage.tex"),

    Asset("ATLAS", "images/skilltree/wagstaff_background.xml"),

    Asset("IMAGE", "images/skilltree/wagstaff_background.tex"),

    -- (Generator & Bud Lamp assets come from active mod 2270993633)

    -- Engineer animation ZIPs

    Asset("ANIM", "anim/tf2scrap.zip"),

    Asset("ANIM", "anim/tf2wrench.zip"),

    Asset("ANIM", "anim/swap_tf2wrench.zip"),

    Asset("ANIM", "anim/ehardhat.zip"),

    Asset("ANIM", "anim/ehardhat_swap.zip"),

    Asset("ANIM", "anim/gibus.zip"),

    Asset("ANIM", "anim/gibus_swap.zip"),

    Asset("ANIM", "anim/destructionpda.zip"),

    Asset("ANIM", "anim/esentry.zip"),

    Asset("ANIM", "anim/esentry_item.zip"),

    Asset("ANIM", "anim/dispenser.zip"),

    Asset("ANIM", "anim/eteleporter.zip"),

    -- Minimap / map icons (bots, sentry, dispenser, teleporter)
    -- NOTE: Both IMAGE and ATLAS assets are required for minimap icons to display correctly.
    -- Missing ATLAS causes the icon to show as a generic square on the map.
    Asset("IMAGE", "images/minimap/esentry.tex"),
    Asset("ATLAS", "images/minimap/esentry.xml"),
    Asset("IMAGE", "images/minimap/esentry_2.tex"),
    Asset("ATLAS", "images/minimap/esentry_2.xml"),
    Asset("IMAGE", "images/minimap/esentry_3.tex"),
    Asset("ATLAS", "images/minimap/esentry_3.xml"),
    Asset("IMAGE", "images/minimap/dispenser.tex"),
    Asset("ATLAS", "images/minimap/dispenser.xml"),
    Asset("IMAGE", "images/minimap/eteleporter.tex"),
    Asset("ATLAS", "images/minimap/eteleporter.xml"),
    Asset("IMAGE", "images/minimap/eteleporterentrance.tex"),
    Asset("ATLAS", "images/minimap/eteleporterentrance.xml"),
    Asset("IMAGE", "images/minimap/eteleporterexit.tex"),
    Asset("ATLAS", "images/minimap/eteleporterexit.xml"),
    Asset("IMAGE", "images/map_icons/williambutler.tex"),
    Asset("ATLAS", "images/map_icons/williambutler.xml"),
    Asset("IMAGE", "images/map_icons/williambuster.tex"),
    Asset("ATLAS", "images/map_icons/williambuster.xml"),
    Asset("IMAGE", "images/map_icons/williambrute.tex"),
    Asset("ATLAS", "images/map_icons/williambrute.xml"),
    Asset("IMAGE", "images/map_icons/williamballistic.tex"),
    Asset("ATLAS", "images/map_icons/williamballistic.xml"),
}


-- Register minimap atlases early so prefab MiniMapEntity icons resolve on load
AddMinimapAtlas("images/map_icons/wagstaff.xml")
AddMinimapAtlas("images/inventoryimages/telipad.xml")
AddMinimapAtlas("images/inventoryimages/thumper.xml")

AddMinimapAtlas("images/minimap/esentry.xml")
AddMinimapAtlas("images/minimap/esentry_2.xml")
AddMinimapAtlas("images/minimap/esentry_3.xml")
AddMinimapAtlas("images/minimap/dispenser.xml")
AddMinimapAtlas("images/minimap/eteleporter.xml")
AddMinimapAtlas("images/minimap/eteleporterentrance.xml")
AddMinimapAtlas("images/minimap/eteleporterexit.xml")
AddMinimapAtlas("images/map_icons/williambutler.xml")
AddMinimapAtlas("images/map_icons/williambuster.xml")
AddMinimapAtlas("images/map_icons/williambrute.xml")
AddMinimapAtlas("images/map_icons/williamballistic.xml")


-- Language detection (auto-detects EN/Chinese based on profile, or uses explicit config)
local userlang = GLOBAL.Profile:GetLanguageID()
local modlanguage = GetModConfigData("language")
local lang = "en"
if modlanguage == "auto" then
    if userlang == GLOBAL.LANGUAGE.CHINESE_T or userlang == GLOBAL.LANGUAGE.CHINESE_S then
        lang = "ch"
    else
        lang = "en"
    end
else
    lang = modlanguage
end
GLOBAL.HCM_LANG = lang


-- Load Forge / Gorge prefabs only in those modes
if GLOBAL.TheNet:GetServerGameMode() == "lavaarena" then
    for _, pref in pairs(forge_prefabs) do
        table.insert(PrefabFiles, pref)
    end
elseif GLOBAL.TheNet:GetServerGameMode() == "quagmire" then
    for _, pref in pairs(gorge_prefabs) do
        table.insert(PrefabFiles, pref)
    end
end


local G = GLOBAL
local TUNING = G.TUNING
local STRINGS = GLOBAL.STRINGS
local TECH = GLOBAL.TECH
local require = GLOBAL.require
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS


modimport("imports/william_tuning")

modimport("imports/william_widgets")

modimport("imports/william_acts")

modimport("imports/william_states")

-- DISABLED: william_portal_affinity.lua was deleted
-- local PortalAffinity = modimport("imports/william_portal_affinity")
local PortalAffinity = nil

-- Dispenser tint helper (shadow/celestial) - keep separate file

modimport("imports/william_dispenser_tint")

-- Skill helper functions are defined inline in this file (G.WagstaffHasSkill, G.WagstaffMechanicalEfficiencyRoll)
-- The old wagstaff_skill_helpers.lua used a broken GetSkillTree() method that doesn't exist.
-- Do NOT modimport it here.

-- Affinity pulse module: exposed as global so prefabs can use it

local AffinityPulse = {}

do

    local PULSE_PERIOD = 0.18

    local CELESTIAL_STEPS = {

        { add = { 0.04, 0.07, 0.18, 0 }, mul = { 0.85, 0.90, 1.0,  1 } },

        { add = { 0.07, 0.12, 0.28, 0 }, mul = { 0.90, 0.95, 1.0,  1 } },

        { add = { 0.10, 0.18, 0.38, 0 }, mul = { 0.95, 0.98, 1.0,  1 } },

        { add = { 0.13, 0.22, 0.44, 0 }, mul = { 1.0,  1.0,  1.0,  1 } },

        { add = { 0.16, 0.26, 0.50, 0 }, mul = { 1.0,  1.0,  1.0,  1 } },

    }

    local SHADOW_STEPS = {

        { add = { 0.08, 0.0,  0.12, 0 }, mul = { 0.55, 0.45, 0.60, 1.0  } },

        { add = { 0.12, 0.0,  0.18, 0 }, mul = { 0.45, 0.35, 0.52, 0.92 } },

        { add = { 0.16, 0.0,  0.24, 0 }, mul = { 0.35, 0.25, 0.44, 0.82 } },

        { add = { 0.12, 0.0,  0.18, 0 }, mul = { 0.45, 0.35, 0.52, 0.88 } },

        { add = { 0.08, 0.0,  0.12, 0 }, mul = { 0.55, 0.45, 0.60, 0.95 } },

    }

    -- v2.0.52: Battle + proximity gating. The affinity "breathing glow" used to
    -- run all day (celestial) / all dusk (shadow), so the pulse FX was
    -- permanently on and visually noisy. Now it only lights up when the owner
    -- is CLOSE to the entity (in range / vision) AND in active combat — owner
    -- fighting, the entity itself fighting, or a nearby hostile targeting the
    -- owner ("algo me atacando"). Idle => neutral colours, no pulse. This also
    -- drops the day/dusk phase lock, consistent with the v2.0.51 sentry ramp
    -- change (affinity active 24/7, but combat-driven).
    -- Call sites still gate AffinityPulse.Setup to MK3-only entities (bots in
    -- fn3(), sentry in SetupMK3Affinity w/ lvl3 tag, dispenser at lvl >= 70).
    --
    -- v2.0.54: Added opts table for call-site-specific gating:
    --   opts.proximity_only  (bool)     — skip the battle check (resource items
    --                                     like the dispenser shouldn't be
    --                                     battle-gated; they're not combat items).
    --   opts.proximity_range (number)   — override the proximity radius (default
    --                                     20). Dispenser uses its AURA radius
    --                                     (DISP_RANGE = 4) so the pulse only
    --                                     lights up when the player is actually
    --                                     standing in the aura.
    --   opts.phase_check     (fn(inst, owner) -> bool) — optional extra gate.
    --                                     Dispenser uses this to confine the
    --                                     pulse to the DUSK affinity-active
    --                                     phase only (no pulse during the weak
    --                                     DAY/NIGHT passive tier).
    AffinityPulse.Setup = function(inst, GetOwnerFn, opts)
        opts = opts or {}
        inst._aff_step   = 1
        inst._aff_dir    = 1
        inst._aff_active = false

        local proximity_only  = opts.proximity_only == true
        local proximity_range = opts.proximity_range or 20
        local phase_check     = opts.phase_check
        local PROXIMITY_RANGE_SQ = proximity_range * proximity_range
        local COMBAT_SCAN_RADIUS = 12        -- hostiles targeting owner, near owner

        -- Gate refresh on a slower cadence (0.5s) so the FindEntities scan stays
        -- cheap even with several MK3 entities on the server. Sets the
        -- inst._aff_active flag consumed by the 0.18s colour-cycling task below.
        local function RefreshGate()
            if not inst:IsValid() then return end
            if inst:HasTag("shadow_buster_clone") then inst._aff_active = false; return end

            local owner = GetOwnerFn and GetOwnerFn(inst)
            if not (owner and owner:IsValid()) then inst._aff_active = false; return end

            -- v2.0.54: Optional phase check (dispenser confines the pulse to
            -- the DUSK affinity-active phase only; no pulse during the weak
            -- DAY/NIGHT passive tier).
            if phase_check and not phase_check(inst, owner) then
                inst._aff_active = false
                return
            end

            -- Proximity: owner within range / vision of the entity.
            local near = false
            pcall(function()
                near = inst:GetDistanceSqToInst(owner) <= PROXIMITY_RANGE_SQ
            end)

            -- v2.0.54: proximity-only mode (resource items like the dispenser
            -- are NOT battle-gated — they're not combat items, so the pulse
            -- should light up whenever the player stands in the aura, not only
            -- mid-fight).
            if proximity_only then
                inst._aff_active = near
                return
            end

            -- Battle: owner has a combat target, OR the entity itself has a
            -- combat target, OR a nearby hostile is targeting the owner.
            local in_combat = false
            if owner.components.combat and owner.components.combat.target then
                in_combat = true
            elseif inst.components.combat and inst.components.combat.target then
                in_combat = true
            end

            if not in_combat and near then
                -- Only scan when the owner is actually near (perf guard).
                local ox, oy, oz = owner.Transform:GetWorldPosition()
                local ents = GLOBAL.TheSim:FindEntities(ox, oy, oz,
                    COMBAT_SCAN_RADIUS, nil, { "INLIMBO", "playerghost" }, nil)
                for _, v in ipairs(ents) do
                    if v ~= owner and v ~= inst
                       and v.components.combat
                       and v.components.combat.target == owner then
                        in_combat = true
                        break
                    end
                end
            end

            inst._aff_active = near and in_combat
        end

        inst:DoPeriodicTask(0.5, RefreshGate)

        inst:DoPeriodicTask(PULSE_PERIOD, function()
            if not inst:IsValid() then return end
            if inst:HasTag("shadow_buster_clone") then return end

            -- Idle (owner not near OR not in combat): no glow.
            if not inst._aff_active then
                inst.AnimState:SetAddColour(0, 0, 0, 0)
                inst.AnimState:SetMultColour(1, 1, 1, 1)
                inst._aff_step = 1
                inst._aff_dir  = 1
                return
            end

            -- Active: pick the palette from the owner's affinity path (no longer
            -- phase-locked). Dual-affinity owners default to celestial.
            local owner     = GetOwnerFn and GetOwnerFn(inst)
            local celestial = owner and owner:HasTag("wagstaff_celestial_possession")
            local shadow    = owner and owner:HasTag("wagstaff_shadow_possession")

            if celestial then
                local s = CELESTIAL_STEPS[inst._aff_step]
                inst.AnimState:SetAddColour(s.add[1], s.add[2], s.add[3], s.add[4])
                inst.AnimState:SetMultColour(s.mul[1], s.mul[2], s.mul[3], s.mul[4])
            elseif shadow then
                local s = SHADOW_STEPS[inst._aff_step]
                inst.AnimState:SetAddColour(s.add[1], s.add[2], s.add[3], s.add[4])
                inst.AnimState:SetMultColour(s.mul[1], s.mul[2], s.mul[3], s.mul[4])
            else
                inst.AnimState:SetAddColour(0, 0, 0, 0)
                inst.AnimState:SetMultColour(1, 1, 1, 1)
                inst._aff_step = 1
                inst._aff_dir  = 1
                return
            end

            inst._aff_step = inst._aff_step + inst._aff_dir
            if inst._aff_step > #CELESTIAL_STEPS then
                inst._aff_step = #CELESTIAL_STEPS - 1
                inst._aff_dir  = -1
            elseif inst._aff_step < 1 then
                inst._aff_step = 2
                inst._aff_dir  = 1
            end
        end)
    end

end

GLOBAL.AffinityPulse = AffinityPulse


-- modimport("imports/industrialization_electricity")  -- Temporarily disabled

-- modimport("imports/bot_charge_fx")  -- Temporarily disabled


--==================================================================================

-- STANDALONE PREFABS (no external mod dependencies)

--==================================================================================

modimport("scripts/standalone_prefabs")

-- v2.0.19: Decoupled affinity revive abilities (celestial buff / shadow clone).
-- Triggers globally on the Wagstaff player's respawnfromghost event.
modimport("scripts/wagstaff_affinity_revive")


-- Compatibility / fallback for Miami Ricky portal tuning

-- Some servers or setups may not have the Miami Ricky mod installed,

-- but other mods (or saved worlds) may reference its TUNING values.

-- Define safe defaults here so we can control portal enemy spawns

-- without vendorizing the entire Miami Ricky mod.

if TUNING.DES_MIAMIRICK_ENABLE_EVILPORTALS == nil then

    -- Default for RANDOM mode: 10% chance to spawn an enemy portal

    -- (user suggested ~10%). Change this value (0..1) as desired.

    TUNING.DES_MIAMIRICK_ENABLE_EVILPORTALS = 0.10

end


if TUNING.DES_MIAMIRICK_PORTAL_ENEMY_GROUPS == nil then

    -- Minimal safe fallback group: small spider packs (vanilla prefabs)

    -- Format expected by original mod: { max_easy, max_hard, mob1, mob2, mob3, mob4 }

    TUNING.DES_MIAMIRICK_PORTAL_ENEMY_GROUPS = {

        {1, 1, "spider", "spider_warrior", "spider", "spider_warrior"},

    }

end


if TUNING.DES_MIAMIRICK_SCIENCE_HAUNT_HARD_MOB_DAY == nil then

    TUNING.DES_MIAMIRICK_SCIENCE_HAUNT_HARD_MOB_DAY = 15

end

if TUNING.DES_MIAMIRICK_SCIENCE_HAUNT_MOB_HERD_DAY == nil then

    TUNING.DES_MIAMIRICK_SCIENCE_HAUNT_MOB_HERD_DAY = 30

end


-- Telepad-specific spawn chance fallback (user observed ~30% for telipad focus)

if TUNING.DES_MIAMIRICK_ENABLE_EVILPORTALS_TELEPAD == nil then

    TUNING.DES_MIAMIRICK_ENABLE_EVILPORTALS_TELEPAD = 0.30

end


--==================================================================================

-- PORTAL GUN AFFINITY HOOKS (Celestial + Shadow)

-- Hooked via AddPrefabPostInit so we only patch the spellcaster AFTER the

-- original mod has already set it up. Normal / telepad modes are preserved.

--==================================================================================

AddPrefabPostInit("miamirick_portal_gun", function(inst)

    if PortalAffinity and PortalAffinity.OnPortalGunPostInit then

        PortalAffinity.OnPortalGunPostInit(inst)

    end

end)


--==================================================================================

-- WAGSTAFF: grant William bot crafter tags + petleash (so bots respond to him)

--==================================================================================



-- Tabela de Tradução: { [Nome_da_Tag_que_o_bot_pede] = "ID_real_da_skill_no_arquivo_defs" }
local TAG_TO_SKILL_ID = {
    ["wagstaff_butler_evolve"]    = "wagstaff_thermal_upgrade", -- Butler MK.II
    ["wagstaff_buster_evolve"]    = "wagstaff_buster_evolve",
    ["wagstaff_brute_evolve"]     = "wagstaff_robotic_1", -- Brute MK.II
    ["wagstaff_ballistic_evolve"] = "wagstaff_ballistic_evolve",
    ["wagstaff_butler_mk3"]       = "wagstaff_thermal_upgrade_parallel", -- Butler MK.III
    ["wagstaff_buster_mk3"]       = "wagstaff_buster_parallel",
    ["wagstaff_brute_mk3"]        = "wagstaff_robotic_1_parallel", -- Brute MK.III
    ["wagstaff_ballistic_mk3"]    = "wagstaff_ballistic_parallel",
    
    -- Mapeamento das Sentinelas e Dispensers:
    ["sentry_mk2"]                = "wagstaff_sentry_mk2",
    ["sentry_mk3"]                = "wagstaff_sentry_mk3",
    ["dispenser_mk2"]             = "wagstaff_dispenser_mk2",
    ["dispenser_mk3"]             = "wagstaff_dispenser_mk3",
    ["wagstaff_wrench_heal"]       = "wagstaff_wrench_heal",
}

G.WagstaffHasSkill = function(worker, skill_id)
    if not worker or not skill_id or worker.prefab ~= "wagstaff" then
        return false
    end

    -- 1. Quick check: physical tag (added by onactivate callbacks)
    if worker:HasTag(skill_id) then
        return true
    end

    -- Resolve the real skill ID from tag-to-skill mapping
    local real_skill = TAG_TO_SKILL_ID[skill_id] or skill_id

    -- 2. Server-Side check (activatedskills table populated by engine)
    if worker.components and worker.components.skilltreeupdater then
        local activated = worker.components.skilltreeupdater.activatedskills
        if activated and (activated[skill_id] or activated[real_skill]) then
            worker:AddTag(skill_id)
            return true
        end
    end

    -- 3. TheSkillTree profile fallback (engine's standard persistence)
    if GLOBAL.TheSkillTree then
        local profile_skills = nil
        G.pcall(function()
            profile_skills = GLOBAL.TheSkillTree:GetActivatedSkills("wagstaff")
        end)
        if profile_skills then
            for _, s_name in GLOBAL.ipairs(profile_skills) do
                if s_name == skill_id or s_name == real_skill then
                    worker:AddTag(skill_id)
                    return true
                end
            end
        end
    end

    return false
end



local function WagstaffWilliamPostInit(inst)
    inst:AddTag("william")
    inst:AddTag("williamcrafter")
    inst:AddTag("engie")  -- Required to equip engineer buildings on back

    -- Stub WX78-only method so the base game wx78_shadowdrone_harvester recipe
    -- doesn't crash when building the crafting menu for non-WX78 characters.
    if inst.GetNumFreeShadowDrone_Harvesters == nil then
        inst.GetNumFreeShadowDrone_Harvesters = function() return 0 end
    end

    -- [REMOVED] ActivateSkill/DeactivateSkill/DirtySkillTree/SetSkillActivatedState wrappers.
    -- The engine's built-in skill tree RPC handles everything correctly now.
    -- These wrappers were bypassing TheSkillTree updates, breaking connects chains.

    if not GLOBAL.TheWorld.ismastersim then return end

    if inst.components.petleash == nil then
        inst:AddComponent("petleash")
        inst.components.petleash:SetMaxPets(4)
    else
        inst.components.petleash:SetMaxPets(math.max(inst.components.petleash:GetMaxPets(), 4))
    end


    -- Give starting items (butler builder only; goggles come from wagstaff.lua starting_inventory)
    inst:DoTaskInTime(0, function(inst)
        if not inst:IsValid() then return end

        local inv = inst.components.inventory
        if not inv then return end

        -- Check if player already received starting items (persistent flag)
        if inst.wagstaff_received_starting_items then
            return
        end

        -- Mark that starting items were given (this persists across save/load)
        inst.wagstaff_received_starting_items = true

        -- Only give butler builder (goggles already from starting_inventory)
        local bot = G.SpawnPrefab("williambutler_builder")
        if bot then
            inv:GiveItem(bot)
        end
    end)

    -- Modificação para salvar os dados do Wagstaff (apenas flags de início, não progresso)
    local old_OnSave = inst.OnSave
    inst.OnSave = function(inst, data)
        if old_OnSave then
            data = old_OnSave(inst, data) or data
        end
        data = data or {}
        data.wagstaff_received_starting_items = inst.wagstaff_received_starting_items
        return data
    end
    
    local old_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if old_OnLoad then
            old_OnLoad(inst, data)
        end
        if data and data.wagstaff_received_starting_items then
            inst.wagstaff_received_starting_items = true
        end
    end
end


AddPrefabPostInit("wagstaff", WagstaffWilliamPostInit)


--==================================================================================
-- +60% COMBUSTÍVEL PARA BOTS MK3 (butler, buster, brute, ballistic)
-- Aumenta maxfuel e current fuel em 60% apenas para versões MK3
--==================================================================================
local function BoostMK3Fuel(inst)
    if inst and inst.components and inst.components.fueled and inst.prefab and inst.prefab:find("3") then
        inst.components.fueled.maxfuel = inst.components.fueled.maxfuel * 1.6
        inst.components.fueled.currentfuel = inst.components.fueled.currentfuel * 1.6
    end
end
AddPrefabPostInit("williambutler3", BoostMK3Fuel)
AddPrefabPostInit("williambuster3", BoostMK3Fuel)
AddPrefabPostInit("williambrute3", BoostMK3Fuel)
AddPrefabPostInit("williamballistic3", BoostMK3Fuel)


--==================================================================================
-- MENOR DANO NA WRENCH: evita desmonte acidental de bots/estruturas amigáveis
-- Dano reduzido de 5 para estruturas/bots quando usada como arma
--==================================================================================
AddPrefabPostInit("tf2wrench", function(inst)
    if inst.components.weapon then
        local old_GetDamage = inst.components.weapon.GetDamage
        inst.components.weapon.GetDamage = function(self, attacker, target)
            if target and target:IsValid() then
                if target:HasTag("william") or target:HasTag("willminion") or target:HasTag("ebuild") then
                    return 1 -- Dano MÍNIMO contra bots/estruturas amigáveis
                end
            end
            return old_GetDamage(self, attacker, target)
        end
    end
end)


--==================================================================================
-- BRUTE MK1 FOLLOWER FIX: recupera follower caso se perca após reload/derrota
-- Varre entidades próximas e reconecta o Brute ao dono via petleash
--==================================================================================
AddPrefabPostInit("williambrute", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    inst:DoTaskInTime(1, function()
        if not inst:IsValid() then return end
        if inst.components.follower and inst.components.follower:GetLeader() == nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            local candidates = GLOBAL.TheSim:FindEntities(x, y, z, 20, {"player"}, {"playerghost"})
            for _, candidate in ipairs(candidates) do
                if candidate.components.petleash then
                    local pets = candidate.components.petleash:GetPets()
                    for _, pet in pairs(pets) do
                        if pet == inst and inst.components.follower then
                            inst.components.follower:SetLeader(candidate)
                            return
                        end
                    end
                end
            end
        end
    end)
end)


-- DISABLED: Miami Ricky actions (components deleted)
-- Add refuel action for Miami Ricky items using Nightmare Fuel
--[[local MIAMIRICKREFUEL = AddAction("MIAMIRICKREFUEL", "Refuel", function(act)
    if act.doer ~= nil and act.target ~= nil and act.invobject ~= nil then
        local target = act.target
        local fuel = act.invobject
        
        if target:HasTag("miamirick_items_fueled") and fuel.prefab == "nightmarefuel" and target.components.finiteuses then
            local add_uses
            if target:HasTag("miamirick_portal_gun") then
                add_uses = target.components.finiteuses.total * 0.2
            else
                add_uses = target.components.finiteuses.total * 0.25
            end
            
            local new_val = target.components.finiteuses.current + add_uses
            if new_val > target.components.finiteuses.total then
                new_val = target.components.finiteuses.total
            end
            target.components.finiteuses:SetUses(new_val)
            
            if fuel.components.stackable then
                fuel.components.stackable:Get(1):Remove()
            else
                fuel:Remove()
            end
            
            if target.SoundEmitter then
                target.SoundEmitter:PlaySound("dontstarve/common/nightmare_addfuel")
            end
            
            return true
        end
    end
    return false
end)

MIAMIRICKREFUEL.priority = 1

AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if right and target:HasTag("miamirick_items_fueled") and inst.prefab == "nightmarefuel" then
        table.insert(actions, G.ACTIONS.MIAMIRICKREFUEL)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.MIAMIRICKREFUEL, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.MIAMIRICKREFUEL, "doshortaction"))

local FLICKER = AddAction("FLICKER", "Flicker", function(act)
    if act.doer and act.invobject and act.invobject.components.miamirick_flicker then
        act.invobject.components.miamirick_flicker:Activate(act.doer)
        return true
    end
    return false
end)

AddComponentAction("INVENTORY", "miamirick_flicker", function(inst, doer, actions, right)
    if right then
        table.insert(actions, G.ACTIONS.FLICKER)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.FLICKER, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.FLICKER, "doshortaction"))

local AUGMENT = AddAction("AUGMENT", "Toggle", function(act)
    if act.doer and act.invobject and act.invobject.components.miamirick_augments then
        act.invobject.components.miamirick_augments:Activate(act.doer)
        return true
    end
    return false
end)

AddComponentAction("INVENTORY", "miamirick_augments", function(inst, doer, actions, right)
    if right then
        table.insert(actions, G.ACTIONS.AUGMENT)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.AUGMENT, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.AUGMENT, "doshortaction"))--]]


--==================================================================================

-- ENGINEER STRUCTURE INTERACTIONS

--==================================================================================


-- ENGIETELEPORT: right-click to teleport to paired exit

local ENGIETELEPORT = AddAction("ENGIETELEPORT", "Enter", function(act)

    if act.doer ~= nil and act.target ~= nil and act.doer:HasTag("player") and act.target.components.engieteleporter and act.target:HasTag("eteleporter_enter") then

        act.target.components.engieteleporter.boundEntrance = act.target

        act.target.components.engieteleporter:TeleportAction(act.doer)

        if act.doer.components.sanity and not act.doer:HasTag("tinkerer") then

            act.doer.components.sanity:DoDelta(-(TUNING.ETELEPORT_PENALTY or 0))

        end

        return true

    end

end)

ENGIETELEPORT.encumbered_valid = true

ENGIETELEPORT.mount_valid = true


AddComponentAction("SCENE", "engieteleporter", function(inst, doer, actions, right)

    if inst:HasTag("eteleporter_enter") then

        table.insert(actions, GLOBAL.ACTIONS.ENGIETELEPORT)

    end

end)


AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.ENGIETELEPORT, "doshortaction"))

AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.ENGIETELEPORT, "doshortaction"))


-- v2.0.61: Ballistic MK3 Overcharge toggle. Left-click the deployed bot to
-- toggle its manual overcharge mode on/off. Bound to the `fueled` component
-- (which the bot has) but gated by the `william_overcharge_toggle` tag so only
-- the Ballistic MK3 shows the prompt — not every fueled entity.
local WILLIAM_OVERCHARGE_TOGGLE = AddAction("WILLIAM_OVERCHARGE_TOGGLE", "Toggle Overcharge", function(act)
    if act.target ~= nil and act.target:IsValid() and act.target:HasTag("william_overcharge_toggle") then
        if act.target.ToggleOvercharge ~= nil then
            act.target:ToggleOvercharge(act.doer)
            return true
        end
    end
    return false
end)
WILLIAM_OVERCHARGE_TOGGLE.priority = 5

AddComponentAction("SCENE", "fueled", function(inst, doer, actions, right)
    if right then return end
    if inst:HasTag("william_overcharge_toggle")
       and not inst:HasTag("INLIMBO")
       and inst.components.inventoryitem == nil
       and doer:HasTag("williamcrafter") then
        table.insert(actions, GLOBAL.ACTIONS.WILLIAM_OVERCHARGE_TOGGLE)
    end
end)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLIAM_OVERCHARGE_TOGGLE, "doshortaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.WILLIAM_OVERCHARGE_TOGGLE, "doshortaction"))


-- ENGIEWORKABLE: right-click with tf2wrench on wrenchable engineer buildings

local ENGIEWORKABLE = G.Action()

ENGIEWORKABLE.id = "ENGIEWORKABLE"

ENGIEWORKABLE.str = {

    GENERIC = "Repair",

    DISPENSER = "Refuel",

    SENTRY = "Reload",

    SENTRY_LVL = "Reload/Upgrade",

    DISPENSER_LVL = "Refuel/Upgrade",

    BUTLER = "Repair",

    BUTLER_LVL = "Upgrade Butler Bot MK.II",

}

ENGIEWORKABLE.strfn = function(act)

    if act.target ~= nil then

        if act.target.prefab == "esentry" and act.target:HasTag("lvl3") then

            return "SENTRY"

        elseif act.target.prefab == "esentry" and not act.target:HasTag("lvl3") then

            return "SENTRY_LVL"

        elseif act.target.prefab == "dispenser" and act.target:HasTag("lvl3") then

            return "DISPENSER"

        elseif act.target.prefab == "dispenser" and not act.target:HasTag("lvl3") then

            return "DISPENSER_LVL"

        elseif act.target.prefab == "williambutler" and not act.target:HasTag("butler_thermal_upgraded") then

            return "BUTLER_LVL"

        elseif act.target.prefab == "williambutler" and act.target:HasTag("butler_thermal_upgraded") then

            return "BUTLER"

        end

    end

end

ENGIEWORKABLE.fn = function(act)

    if act.doer ~= nil and act.target ~= nil and act.doer:HasTag("player") then

        -- Verify wrench is still valid and has durability
        local wrench = act.doer.components.inventory and act.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if wrench == nil or wrench.prefab ~= "tf2wrench" or (wrench.components.finiteuses and wrench.components.finiteuses:GetUses() <= 0) then
            return false
        end

        if act.target.components.engieworkable then

            act.target.components.engieworkable:WorkedBy(act.doer, 1)

            return true

        elseif act.target.components.workable and act.target.components.workable.onwork then

            act.target.components.workable.onwork(act.target, act.doer)

            return true

        end

    end

end

AddAction(ENGIEWORKABLE)


AddComponentAction("SCENE", "engieworkable", function(inst, doer, actions, right)
    local equipped = doer.replica.inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS)
    if inst:HasTag("ebuild_wrenchable") and equipped ~= nil and equipped.prefab == "tf2wrench" then
        if equipped.replica.finiteuses == nil or equipped.replica.finiteuses:GetUses() > 0 then
            table.insert(actions, G.ACTIONS.ENGIEWORKABLE)
        end
    end
end)


AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.ENGIEWORKABLE,

        function(inst)

            if inst:HasTag("beaver") then

                return not inst.sg:HasStateTag("gnawing") and "gnaw" or nil

            end

            return not inst.sg:HasStateTag("prehammer")

                and (inst.sg:HasStateTag("hammering") and

                    "hammer" or

                    "hammer_start")

                or nil

end))


AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.ENGIEWORKABLE,

        function(inst)

            if inst:HasTag("beaver") then

                return not inst.sg:HasStateTag("gnawing") and "gnaw" or nil

            end

            return not inst.sg:HasStateTag("prehammer") and "hammer_start" or nil

end))


--==================================================================================

-- SKILL TREE STRINGS (removed - will be reimplemented from reference mod)

--==================================================================================

-- All skill tree strings removed for clean reimplementation


--==================================================================================

-- ITEM NAME STRINGS (required to prevent blueprint crashes)

--==================================================================================

local _NAMES_T = G.rawget(G, "STRINGS") and G.STRINGS.NAMES or {}

local _RECIPE_DESC_T = G.rawget(G, "STRINGS") and G.STRINGS.RECIPE_DESC or {}

-- DST looks up STRINGS.NAMES[string.upper(prefab)] -- write both cases for safety

local function SetName(k, v)

    _NAMES_T[k] = v

    _NAMES_T[string.upper(k)] = v

end

local function SetDesc(k, v)

    _RECIPE_DESC_T[k] = v

    _RECIPE_DESC_T[string.upper(k)] = v

end


-- Miami Ricky

SetName("miamirick_portal_gun", "Portal Gun")

SetName("miamirick_portal", "Unstable Portal")

SetName("miamirick_portal_durable", "Stable Portal")

SetName("miamirick_hand", "Hand Augment")

SetName("miamirick_leg", "Leg Augment")

SetName("miamirick_flicker", "Flicker")

SetDesc("miamirick_portal_gun", "For science!")

SetDesc("miamirick_portal", "I wonder where it leads?")

SetDesc("miamirick_portal_durable", "I wonder where it leads?")

SetDesc("miamirick_hand", "For science!")

SetDesc("miamirick_leg", "For science!")

SetDesc("miamirick_flicker", "For science!")


-- Engineer

SetName("scrap", "Scrap Metal")

SetName("ehardhat", "Hard Hat")

SetName("tf2wrench", "TF2 Wrench")

SetName("esentry", "Sentry Gun")

SetName("dispenser", "Dispenser")

SetName("eteleporter", "Teleporter")

SetName("eteleporter_exit", "Teleporter Exit")

SetName("gibus", "Gibus")

SetName("destructionpda", "Destruction PDA")

SetDesc("scrap", "Engineering material")

SetDesc("ehardhat", "Protect your noggin")

SetDesc("tf2wrench", "For buildings!")

SetDesc("esentry", "Automatic defense")

SetDesc("dispenser", "Restores health and ammo")

SetDesc("eteleporter", "Point A to point B")

SetDesc("eteleporter_exit", "Destination pad")

SetDesc("gibus", "Free hat!")


-- William

SetName("williamgadget", "Machine Hearth")

SetName("williambutler_builder", "Butler Bot")

SetName("williambuster_builder", "Buster Bot")

SetName("williambrute_builder", "Brute Bot")

SetName("williamballistic_empty", "Ballistic Bot")

-- v2.0.33: removed SetName("williambutler2", "Butler Bot Mk.II") — it used
-- "Mk.II" (no space) which MISMATCHED the displaynamefn base "Butler Bot
-- Mk. II" (with space), causing a "jumbled" hover. v2.0.41 re-adds
-- STRINGS.NAMES.WILLIAMBUTLER2 with the CORRECT "Butler Bot Mk. II" (with
-- space, matching displaynamefn) directly in the AddSimPostInit block
-- below — see the v2.0.41 comment there for the full root-cause analysis
-- of why STRINGS.NAMES are REQUIRED (not optional) for all bot tiers.

SetName("williambuster2", "Buster Bot Mk.II")

SetName("williamballistic2", "Ballistic Bot Mk.II")

SetDesc("williamgadget", "The Robot Core")

SetDesc("williambutler_builder", "Your mechanical servant")

SetDesc("williambutler2", "Cooking Assistant")

SetDesc("williambuster_builder", "Heavy hitter")

SetDesc("williambrute_builder", "Shield unit")

SetDesc("williamballistic_empty", "Long range support")

SetDesc("williambuster2", "Explosive Punch + Follows")

SetDesc("williamballistic2", "Lightning Overcharge - ChainLight - Huge Battery - Recharges Nearby Bots.")


-- Robert

SetName("teslaflail", "Tesla Flail")

SetName("compassvest", "Compass Vest")

SetName("refinery_boards", "Board Refinery")

SetName("refinery_papyrus", "Papyrus Refinery")

SetName("refinery_rope", "Rope Refinery")

SetName("refinery_cutstone", "Cut Stone Refinery")

SetDesc("teslaflail", "Shocking!")

SetDesc("compassvest", "Never get lost")

SetDesc("refinery_boards", "Automated crafting")

SetDesc("refinery_papyrus", "Automated crafting")

SetDesc("refinery_rope", "Automated crafting")

SetDesc("refinery_cutstone", "Automated crafting")


--==================================================================================

-- SKILL TREE ICON REGISTRATION (removed - will be reimplemented from reference mod)

--==================================================================================

-- Removed for clean reimplementation


--==================================================================================

-- SKILL TREE REGISTRATION (copied from Medievil Reanimated structure)

--==================================================================================

local SkillTreeDefs = require("prefabs/skilltree_defs")


-- Store the skill definitions for later use (for WagstaffHasSkill)
G.WagstaffSkillDefs = nil

-- Create skill tree — matches reference mod pattern (kodi, mevileyes, sdf)
-- Just CreateSkillTreeFor + SKILLTREE_ORDERS. No custom RPC, no wrappers.
local function CreateSkillTree()
    local BuildSkillsData = require("prefabs/skilltree_wagstaff")
    if not BuildSkillsData then return end

    local data = BuildSkillsData(SkillTreeDefs.FN)
    if not data then return end

    -- Save skill definitions for WagstaffHasSkill
    G.WagstaffSkillDefs = data.SKILLS

    -- Register skill tree with the engine
    if type(SkillTreeDefs.CreateSkillTreeFor) == "function" then
        SkillTreeDefs.CreateSkillTreeFor("wagstaff", data.SKILLS)
        WagstaffDebug("CreateSkillTreeFor succeeded")
    elseif type(SkillTreeDefs.FN) == "function" then
        SkillTreeDefs.FN("wagstaff", data.SKILLS)
    end

    -- Set ORDERS AFTER CreateSkillTreeFor (matches reference mod pattern)
    SkillTreeDefs.SKILLTREE_ORDERS["wagstaff"] = data.ORDERS

    -- Set background
    if SkillTreeDefs.SKILLTREE_METAINFO == nil then
        SkillTreeDefs.SKILLTREE_METAINFO = {}
    end
    if SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] == nil then
        SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] = {}
    end
    SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"].BACKGROUND_SETTINGS = data.BACKGROUND_SETTINGS

    WagstaffDebug("Successfully created wagstaff skill tree")
end

CreateSkillTree()

-- [REMOVED] Cross-shard RPC sync, RPC_LOOKUP nil guard, GetSkillNameFromID wrapper.
-- No longer needed — engine handles all RPC lookups internally.


-- ==================================================================================
-- INSIGHT (XP) PROGRESSION SYSTEM FOR WAGSTAFF
-- ==================================================================================
-- Design: XP is managed by DST's standard skill tree persistence (per-character profile).
--   - Day 1 grants the first skill point (threshold 0).
--   - Subsequent thresholds at days 3, 6, 10, 14, 18, 23, 28, 33, 38, 43, 48, 53, 58, 63, 68.
--   - Each daycomplete event adds +1 XP via TheSkillTree:AddSkillXP(1, "wagstaff").
--   - Boss kills are tracked per-world via world save flags.
-- ==================================================================================

if TUNING.SKILL_THRESHOLDS == nil then
    TUNING.SKILL_THRESHOLDS = {}
end
TUNING.SKILL_THRESHOLDS.wagstaff = {0,3,6,10,14,18,23,28,33,38,43,48,53,58,63,68}

-- Per-world persistence: boss kills only.
-- Skill XP/activation is handled by DST's standard skill tree persistence.
-- NETWORKING: Boss kill flags and XP reset signal use net_bool so clients can read them.
-- (Custom world.state fields are NOT networked in DST — they only exist on the server.)
WagstaffDebug("Registering AddPrefabPostInit('world')")
AddPrefabPostInit("world", function(self)
    WagstaffDebug("[WORLD-POSTINIT] ENTERED")
    -- Diagnóstico: registrar contexto de execução (master sim? client? dedicated?)
    local _is_master = self.ismastersim == true
    local _is_dedicated = GLOBAL.TheNet and GLOBAL.TheNet:IsDedicated() == true
    WagstaffDebug("[WORLD-POSTINIT] ismastersim=" .. tostring(_is_master) .. " IsDedicated=" .. tostring(_is_dedicated))
    -- Initialize worldstate boss flags (server-side persistence for save/load)
    if self.state.wagstaff_fuelweaver_killed == nil then
        self.state.wagstaff_fuelweaver_killed = false
    end
    if self.state.wagstaff_celestial_killed == nil then
        self.state.wagstaff_celestial_killed = false
    end
    -- Profile reset flag: true after resetting XP/boss stats on fresh world.
    --
    -- BUG FIX (v2.0.2): Previously stored in self.state.wagstaff_profile_reset.
    -- Custom fields on TheWorld.state are NOT persisted automatically by the
    -- engine — they depend on the OnSave/OnLoad wrap below, which is fragile
    -- (other mods or the engine can override world.OnSave and break the chain).
    -- Storing the flag directly on the world entity and returning it from
    -- OnSave data makes persistence reliable across reloads. This prevents
    -- the flag from reverting to nil/false on reload, which was causing a
    -- DUPLICATE XP reset every time the player relogged.
    if self.wagstaff_profile_reset == nil then
        self.wagstaff_profile_reset = false
    end
    WagstaffDebug("[WORLD-POSTINIT] wagstaff_profile_reset (init)=" .. tostring(self.wagstaff_profile_reset))

    -- Networked variables: these sync from server to client automatically.
    -- IMPORTANT: net_bool must be accessed via GLOBAL here. In the DST mod
    -- environment net_bool is NOT exposed as a bare global — it is only
    -- auto-injected into prefab fn contexts (e.g. scripts/prefabs/*.lua).
    -- Calling bare net_bool here crashed during world generation with:
    --   "attempt to call global 'net_bool' (a nil value)"
    -- (Compare scripts/prefabs/wagstaff.lua:215, where bare net_bool IS valid
    -- because it runs inside the prefab fn environment.)
    if GLOBAL.net_bool then
        self.wagstaff_fuelweaver_killed_net = GLOBAL.net_bool(self.GUID, "wagstaff_fuelweaver_killed_net")
        self.wagstaff_celestial_killed_net  = GLOBAL.net_bool(self.GUID, "wagstaff_celestial_killed_net")
        WagstaffDebug("[WORLD-POSTINIT] net_bool vars CREATED (fuelweaver, celestial)")
        -- net_bool defaults to false, so no initial :set() is required. Also,
        -- :set() may only be called on the master sim — calling it on a client
        -- (when the client constructs its local world entity) is invalid. The
        -- real values are pushed from the master sim via OnLoad below and via
        -- the boss-kill callbacks; clients receive them through net
        -- variable replication automatically.
    else
        WagstaffDebug("[WORLD-POSTINIT] WARNING: GLOBAL.net_bool is NIL — net vars NOT created!")
        print("[Wagstaff WORLD] WARNING: GLOBAL.net_bool is NIL — needs_xp_reset_net will NOT be available!")
    end

    -- SAVE: store boss flags + profile reset flag
    local old_OnSave = self.OnSave
    self.OnSave = function(self, ...)
        local data = old_OnSave and old_OnSave(self, ...) or {}
        data.wagstaff_fuelweaver_killed = self.state.wagstaff_fuelweaver_killed
        data.wagstaff_celestial_killed  = self.state.wagstaff_celestial_killed
        data.wagstaff_profile_reset     = self.wagstaff_profile_reset
        WagstaffDebug("[WORLD-ONSAVE] wagstaff_profile_reset=" .. tostring(self.wagstaff_profile_reset) .. " fuelweaver=" .. tostring(self.state.wagstaff_fuelweaver_killed) .. " celestial=" .. tostring(self.state.wagstaff_celestial_killed))
        print("[Wagstaff WORLD] OnSave: profile_reset=" .. tostring(self.wagstaff_profile_reset) .. " fuelweaver=" .. tostring(self.state.wagstaff_fuelweaver_killed) .. " celestial=" .. tostring(self.state.wagstaff_celestial_killed))
        WagstaffDebug("World OnSave done")
        return data
    end

    -- LOAD: restore boss flags + profile reset flag + sync to net_bool
    local old_OnLoad = self.OnLoad
    self.OnLoad = function(self, data, ...)
        WagstaffDebug("[WORLD-ONLOAD] ENTERED, data=" .. tostring(data ~= nil))
        print("[Wagstaff WORLD] OnLoad called, data present=" .. tostring(data ~= nil))
        if old_OnLoad then old_OnLoad(self, data, ...) end
        if data then
            self.state.wagstaff_fuelweaver_killed = data.wagstaff_fuelweaver_killed or false
            self.state.wagstaff_celestial_killed  = data.wagstaff_celestial_killed  or false
            self.wagstaff_profile_reset     = data.wagstaff_profile_reset or false
            WagstaffDebug("[WORLD-ONLOAD] restored from data: profile_reset=" .. tostring(self.wagstaff_profile_reset) .. " fuelweaver=" .. tostring(self.state.wagstaff_fuelweaver_killed) .. " celestial=" .. tostring(self.state.wagstaff_celestial_killed))
        else
            -- Fresh world (no save data): flag stays false so profile reset will trigger
            self.state.wagstaff_fuelweaver_killed = false
            self.state.wagstaff_celestial_killed  = false
            self.wagstaff_profile_reset     = false
            WagstaffDebug("[WORLD-ONLOAD] FRESH WORLD (no data) — profile_reset=false (reset WILL trigger)")
            print("[Wagstaff WORLD] OnLoad: FRESH WORLD detected — profile reset WILL trigger")
        end
        -- Sync loaded state to networked variables (so client lock_open can read them)
        -- `self` here is TheWorld (this is the world's OnLoad method). Use
        -- self.ismastersim instead of bare TheWorld (which is not in the mod
        -- env) and guard the net vars in case creation was skipped.
        if self.ismastersim and self.wagstaff_fuelweaver_killed_net then
            self.wagstaff_fuelweaver_killed_net:set(self.state.wagstaff_fuelweaver_killed)
            self.wagstaff_celestial_killed_net:set(self.state.wagstaff_celestial_killed)
            WagstaffDebug("[WORLD-ONLOAD] master sim — syncing boss nets: fuelweaver=" .. tostring(self.state.wagstaff_fuelweaver_killed) .. " celestial=" .. tostring(self.state.wagstaff_celestial_killed))
            -- Note: wagstaff_needs_xp_reset_net was removed in v2.0.8 (XP reset
            -- system deleted). Only boss kill net_bools are synced here.
        else
            WagstaffDebug("[WORLD-ONLOAD] NOT master sim OR no boss net — skipping net sync (ismastersim=" .. tostring(self.ismastersim) .. ", boss_net=" .. tostring(self.wagstaff_fuelweaver_killed_net ~= nil) .. ")")
        end
    end
end)


--==================================================================================
-- Listen for boss kills — set server state, net_bool, AND player tags.
-- Player tags are the PRIMARY replication mechanism because they are always
-- networked by DST's engine (unlike net_bool created in a PostInit, which
-- may not replicate because the world entity is already fully networked
-- by the time AddPrefabPostInit("world") runs).
--==================================================================================

-- Helper: apply boss-kill tag to all currently connected players
local function ApplyBossKillTag(tag_name)
    for _, player in ipairs(GLOBAL.AllPlayers) do
        if player and player:IsValid() and not player:HasTag(tag_name) then
            player:AddTag(tag_name)
            print("[Wagstaff] Added tag '" .. tag_name .. "' to player " .. tostring(player.name))
        end
    end
end

AddPrefabPostInit("stalker_atrium", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    inst:ListenForEvent("death", function()
        -- Server-side state (persists in save data, NOT networked)
        GLOBAL.TheWorld.state.wagstaff_fuelweaver_killed = true
        -- net_bool (may not replicate from PostInit, kept as fallback)
        if GLOBAL.TheWorld.wagstaff_fuelweaver_killed_net then
            GLOBAL.TheWorld.wagstaff_fuelweaver_killed_net:set(true)
        end
        -- PRIMARY: player tags (always replicate server->client in DST)
        ApplyBossKillTag("wagstaff_fuelweaver_killed")
        print("[Wagstaff] Ancient Fuelweaver killed — affinity lock unlocked (tag+net)")
    end)
end)

AddPrefabPostInit("alterguardian_phase3", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    inst:ListenForEvent("death", function()
        -- Server-side state (persists in save data, NOT networked)
        GLOBAL.TheWorld.state.wagstaff_celestial_killed = true
        -- net_bool (may not replicate from PostInit, kept as fallback)
        if GLOBAL.TheWorld.wagstaff_celestial_killed_net then
            GLOBAL.TheWorld.wagstaff_celestial_killed_net:set(true)
        end
        -- PRIMARY: player tags (always replicate server->client in DST)
        ApplyBossKillTag("wagstaff_celestial_killed")
        print("[Wagstaff] Celestial Champion killed — affinity lock unlocked (tag+net)")
    end)
end)

--==================================================================================
-- Re-apply boss-kill tags when players join/load (tags don't persist across
-- save/load on players, so we must re-add them from the world's saved state).
-- This runs on the master sim for every player that spawns.
--==================================================================================
AddPlayerPostInit(function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    inst:DoTaskInTime(1, function()
        if not inst:IsValid() then return end
        -- Re-apply tags from world state (handles save/load and late-joining players)
        if GLOBAL.TheWorld.state.wagstaff_fuelweaver_killed then
            if not inst:HasTag("wagstaff_fuelweaver_killed") then
                inst:AddTag("wagstaff_fuelweaver_killed")
                print("[Wagstaff] Re-applied wagstaff_fuelweaver_killed tag to " .. tostring(inst.name) .. " (world state)")
            end
        end
        if GLOBAL.TheWorld.state.wagstaff_celestial_killed then
            if not inst:HasTag("wagstaff_celestial_killed") then
                inst:AddTag("wagstaff_celestial_killed")
                print("[Wagstaff] Re-applied wagstaff_celestial_killed tag to " .. tostring(inst.name) .. " (world state)")
            end
        end
    end)
end)


-- Each day survived: +1 XP via standard DST skill tree persistence
AddPrefabPostInit("wagstaff", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end

    WagstaffDebug("[WAGSTAFF-SERVER-POSTINIT] ENTERED (master sim)")
    WagstaffDebug("[WAGSTAFF-SERVER-POSTINIT] TheWorld.wagstaff_profile_reset=" .. tostring(GLOBAL.TheWorld.wagstaff_profile_reset))
    WagstaffDebug("[WAGSTAFF-SERVER-POSTINIT] inst.wagstaff_needs_xp_reset=" .. tostring(inst.wagstaff_needs_xp_reset ~= nil))
    WagstaffDebug("[WAGSTAFF-SERVER-POSTINIT] inst.GUID=" .. tostring(inst.GUID))
    WagstaffDebug("[WAGSTAFF-SERVER-POSTINIT] TheWorld.GUID=" .. tostring(GLOBAL.TheWorld.GUID))

    --==================================================================================
    -- FRESH WORLD: Zero boss kill stats (affinity-gating bosses)
    -- Only runs once per world creation, never on reload.
    -- (XP and skill activations are NOT reset — players keep their progress.)
    --==================================================================================
    inst:DoTaskInTime(0, function()
        WagstaffDebug("[WAGSTAFF-SERVER] DoTaskInTime(0) fired, inst:IsValid()=" .. tostring(inst:IsValid()))
        if not inst:IsValid() then
            WagstaffDebug("[WAGSTAFF-SERVER] inst NOT valid — aborting reset")
            return
        end
        -- Skip if already reset for this world (reload).
        -- Flag is now stored directly on TheWorld entity (not TheWorld.state)
        -- for reliable persistence across save/load — see AddPrefabPostInit("world").
        if GLOBAL.TheWorld.wagstaff_profile_reset then
            WagstaffDebug("[WAGSTAFF-SERVER] SKIPPING reset — wagstaff_profile_reset already true (reload)")
            print("[Wagstaff SERVER] SKIPPING fresh-world reset — already done for this world (reload)")
            return
        end

        -- Zero boss kill stats in the player profile (affinity-gating bosses)
        local profile = inst.profile
        WagstaffDebug("[WAGSTAFF-SERVER] inst.profile=" .. tostring(profile ~= nil) .. " profile.stats=" .. tostring(profile and profile.stats ~= nil))
        if profile and profile.stats then
            local bosses = {
                "stalker", "stalker_atrium",
                "alterguardian_phase3", "alterguardian_phase2", "alterguardian_phase1",
            }
            for _, boss in ipairs(bosses) do
                profile.stats["killed_" .. boss] = 0
            end
            if profile.Save then
                local save_ok, save_err = pcall(function() profile:Save() end)
                WagstaffDebug("[WAGSTAFF-SERVER] profile:Save() result: ok=" .. tostring(save_ok) .. " err=" .. tostring(save_err))
            end
            print("[Wagstaff] Reset boss kill stats for affinity bosses (fresh world)")
            WagstaffDebug("[WAGSTAFF-SERVER] Reset boss kill stats for affinity bosses")
        else
            WagstaffDebug("[WAGSTAFF-SERVER] WARNING: inst.profile or profile.stats is NIL — boss stats NOT reset")
            print("[Wagstaff SERVER] WARNING: inst.profile or profile.stats is NIL — boss stats NOT reset")
        end

        -- Mark this world as reset — will NOT trigger again on reload
        GLOBAL.TheWorld.state.wagstaff_profile_reset = true
        WagstaffDebug("[WAGSTAFF-SERVER] Set wagstaff_profile_reset=TRUE (boss stats reset complete)")
        print("[Wagstaff] Fresh world boss kill stats reset complete.")
    end)

    inst:ListenForEvent("daycomplete", function(inst)
        WagstaffDebug("[WAGSTAFF-SERVER] daycomplete fired, isghost=" .. tostring(inst:HasTag("playerghost")))
        if not inst:HasTag("playerghost") then
            if GLOBAL.TheSkillTree then
                local xp_before = nil
                pcall(function() xp_before = GLOBAL.TheSkillTree:GetSkillXP("wagstaff") end)
                GLOBAL.TheSkillTree:AddSkillXP(1, "wagstaff")
                local xp_after = nil
                pcall(function() xp_after = GLOBAL.TheSkillTree:GetSkillXP("wagstaff") end)
                WagstaffDebug("[WAGSTAFF-SERVER] AddSkillXP(+1, wagstaff): before=" .. tostring(xp_before) .. " after=" .. tostring(xp_after))
            else
                WagstaffDebug("[WAGSTAFF-SERVER] WARNING: TheSkillTree is NIL on daycomplete — XP NOT added")
            end
        end
    end)
end)


--==================================================================================

-- CLEANUP INVALID LOCK ACTIVATIONS (prevents "Invalid skilltree skill to ActivateSkill" spam)

--==================================================================================

AddPlayerPostInit(function(inst)

    if not GLOBAL.TheWorld.ismastersim then return end

    

    inst:DoTaskInTime(2, function()

        if inst.components.skilltreeupdater then

            local activated = inst.components.skilltreeupdater:GetActivatedSkills()

            if not activated then return end -- No skills activated yet

            

            local needs_cleanup = false

            

            -- Check if any allegiance locks are erroneously in activated skills

            for skill_name, _ in pairs(activated) do

                if string.find(skill_name, "wagstaff_allegiance_lock_") then

                    -- print("[Wagstaff Mod] Cleaning up invalid lock activation: " .. skill_name)

                    activated[skill_name] = nil

                    needs_cleanup = true

                end

            end

            

            if needs_cleanup then
                WagstaffDebug("Cleaned up invalid lock activations")
            end

        end

    end)

end)


-- Register custom skill tree icons with their atlases

RegisterSkilltreeIconsAtlas("images/skilltree/MK2.xml", "MK2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/mk3.xml", "mk3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/disp2.xml", "disp2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/disp3.xml", "disp3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/Wrench.xml", "Wrench.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/luckyenginer.xml", "luckyenginer.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/doublestrike.xml", "doublestrike.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/brutemk2.xml", "brutemk2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/brutemk3.xml", "brutemk3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/bustermk2.xml", "bustermk2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/bustermk3.xml", "bustermk3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/balisticmk2.xml", "balisticmk2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/balisticmk3.xml", "balisticmk3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/buttlermk2.xml", "buttlermk2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/buttlermk3.xml", "buttlermk3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/roboefige.xml", "roboefige.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/sentrymk2.xml", "sentrymk2.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/sentrymk3.xml", "sentrymk3.tex")
RegisterSkilltreeIconsAtlas("images/skilltree/doubledamage.xml", "doubledamage.tex")

-- Registered custom skill tree icons


-- Register skill tree background for Wagstaff

RegisterSkilltreeBGForCharacter("images/skilltree/wagstaff_background.xml", "wagstaff")

-- Registered skill tree background for wagstaff


-- Register minimap atlases for map icons


-- Global helpers used by bot prefabs

rawset(G, "WagstaffBotRainDamage", function(inst)

    if G.TheWorld.state.israining and inst.components.health then

        inst.components.health:DoDelta(-1, false, "wetness")

    end

end)


rawset(G, "WagstaffBotLightningRecharge", function(inst)

    if inst.components.fueled then

        inst.components.fueled:DoDelta(inst.components.fueled.maxfuel * 0.25)

    end

end)


-- 30% chance to cost 0; otherwise costs base_cost

rawset(G, "WagstaffMechanicalEfficiencyRoll", function(worker, base_cost)

    -- v2.0.15: 30% -> 20% free scrap roll (was too strong for 1 insight)
    if worker and worker:HasTag("wagstaff_mechanical_efficiency") and G.math.random() < 0.20 then

        return 0

    end

    return base_cost

end)


-- Patch skill tree widget to remove tint for Wagstaff and fix favor overlay z-order
AddClassPostConstruct("widgets/redux/skilltreewidget", function(self)
    -- v2.0.42 FIX (replaces v2.0.36): The favor overlay (midlay — shadow hands
    -- for Shadow's Embrace / clouds+gestalts for Moon's Blessing) was STILL
    -- going BEHIND the bg_tree parchment background after the player died and
    -- revived, even with the v2.0.36 hooks in place.
    --
    -- Root cause: v2.0.36 only hooked high-level refresh methods (RefreshSkill,
    -- RefreshAll, OnShow, SpawnFavorOverlay). After death/revive, the base game
    -- aggressively refreshes the skill tree panel and calls bg_tree:MoveToFront()
    -- in places our hooks didn't cover (and possibly in DoTaskInTime callbacks
    -- that run AFTER our hooks in the same frame), re-pushing midlay behind.
    --
    -- Robust fix — THREE complementary layers:
    --   1. CASCADE HOOK: wrap bg_tree:MoveToFront itself so that EVERY time
    --      bg_tree is brought to front (by anyone, anytime), midlay immediately
    --      follows it to the front. This is the key fix — it doesn't matter
    --      what method or task moves bg_tree; midlay always stays on top.
    --   2. METHOD HOOKS: keep hooking the high-level refresh methods as a fast
    --      path (catches the common cases without waiting for the periodic task).
    --   3. PERIODIC SAFETY NET: re-assert midlay:MoveToFront() every 0.25s while
    --      the panel is open. Catches any edge case the other two layers miss
    --      (e.g. a DoTaskInTime that moves bg_tree after our hooks ran). Auto-
    --      cancels when the widget's entity is removed.
    --
    -- Note: the target == "wagstaff" gate from v2.0.36 is REMOVED. The fix now
    -- applies to any skill tree widget that has a midlay (favor overlay). This
    -- is correct behavior for all characters (the favor overlay should always
    -- render on top of the parchment), and removes a fragile dependency on the
    -- exact field name/value the base game uses for the character identifier.

    local function ForceMidlayFront(w)
        if w and w.midlay then
            w.midlay:MoveToFront()
        end
    end

    -- Layer 1: CASCADE HOOK on bg_tree:MoveToFront. Whenever bg_tree is moved
    -- to front (by the base game's refresh logic), immediately move midlay to
    -- front too. This is idempotent and safe — MoveToFront on an already-front
    -- widget is a no-op.
    local function HookBgTreeMoveToFront(w)
        if not w or not w.bg_tree then return end
        if w.bg_tree._wagstaff_midlay_hooked then return end
        local orig = w.bg_tree.MoveToFront
        if not orig then return end
        w.bg_tree.MoveToFront = function(bg, ...)
            orig(bg, ...)
            if w.midlay then
                w.midlay:MoveToFront()
            end
        end
        w.bg_tree._wagstaff_midlay_hooked = true
    end

    -- Helper called after every hooked method: re-assert midlay front, and
    -- ensure the bg_tree cascade hook is installed (bg_tree may be created
    -- lazily after the widget constructs).
    local function RefreshAndHook(w)
        ForceMidlayFront(w)
        HookBgTreeMoveToFront(w)
    end

    -- Layer 2: METHOD HOOKS on every refresh/redraw method we know about.
    local original_SpawnFavorOverlay = self.SpawnFavorOverlay
    if original_SpawnFavorOverlay then
        self.SpawnFavorOverlay = function(self2, pre)
            original_SpawnFavorOverlay(self2, pre)
            RefreshAndHook(self2)
        end
    end

    for _, method in ipairs({"RefreshSkill", "RefreshAll", "OnShow", "Refresh",
                              "RefreshTree", "SelectSkill", "BuildSkills",
                              "OnSkillActivated", "RefreshSkillDetail"}) do
        local original = self[method]
        if original then
            self[method] = function(self2, ...)
                original(self2, ...)
                RefreshAndHook(self2)
            end
        end
    end

    -- Layer 3: PERIODIC SAFETY NET. Re-assert midlay:MoveToFront() every 0.25s
    -- while the panel is open. Tied to the widget's inst entity so it auto-
    -- cancels when the widget is destroyed. This is the final backstop that
    -- catches any refresh path the other layers miss.
    if self.inst and self.inst.DoPeriodicTask then
        self.inst:DoPeriodicTask(0.25, function()
            if not self or not self.inst or not self.inst:IsValid() then
                return
            end
            ForceMidlayFront(self)
            HookBgTreeMoveToFront(self)
        end)
    end

    -- v2.0.42: Client-side revive listener. When the player revives from ghost,
    -- the skill tree panel (if open) aggressively refreshes bg_tree. Try at
    -- MULTIPLE delays (0.1s through 2.0s) to catch the refresh at every phase
    -- — the base game's post-revive refresh can span several frames. Each tick
    -- re-asserts midlay front AND installs the bg_tree cascade hook.
    if G.ThePlayer then
        G.ThePlayer:ListenForEvent("ms_respawnedfromghost", function()
            for _, delay in ipairs({0.1, 0.3, 0.5, 1.0, 1.5, 2.0}) do
                G.TheWorld:DoTaskInTime(delay, function()
                    local hud = G.ThePlayer.HUD
                    if not hud or not hud.controls then return end
                    local stb = hud.controls.skilltreebuilder
                    if not stb then return end
                    -- The skilltreewidget may be accessed via several field
                    -- names depending on DST version. Try them all.
                    local candidates = {stb.tree, stb.skilltree, stb.skilltreewidget, stb}
                    for _, widget in ipairs(candidates) do
                        if widget and widget.midlay then
                            ForceMidlayFront(widget)
                        end
                        if widget and widget.bg_tree then
                            HookBgTreeMoveToFront(widget)
                        end
                    end
                end)
            end
        end)
    end
end)

-- Hide "Learn" button after skill is learned (visual fix)
AddClassPostConstruct("widgets/redux/skilltreebuilder", function(self)
    local original_RefreshTree = self.RefreshTree
    if original_RefreshTree then
        self.RefreshTree = function(self2, skillschanged)
            -- Call original
            original_RefreshTree(self2, skillschanged)
            
            -- Visual fix: hide Learn button if skill is already learned
            if not self2.readonly and self2.selectedskill and self2.infopanel and self2.infopanel.activatebutton then
                local graphics = self2.skillgraphics[self2.selectedskill]
                
                -- Check both status.activated (visual state) and IsActivated (actual state)
                if graphics and graphics.status and graphics.status.activated then
                    self2.infopanel.activatebutton:Hide()
                    return
                end
                
                local skilltreeupdater = nil
                if self2.fromfrontend then
                    skilltreeupdater = TheSkillTree
                else
                    skilltreeupdater = ThePlayer and ThePlayer.components.skilltreeupdater or nil
                end
                
                if skilltreeupdater and skilltreeupdater:IsActivated(self2.selectedskill, self2.target) then
                    self2.infopanel.activatebutton:Hide()
                end
            end
        end
    end
end)


--==================================================================================

-- WX78 COMPATIBILITY PATCH (fix missing methods added in newer DST updates)

--==================================================================================

AddPlayerPostInit(function(inst)

    if inst.prefab ~= "wagstaff" then return end


    -- IMMEDIATE: patch inst-level functions that reference player_classified fields

    -- added in newer DST updates. These are set directly on inst (not on a class),

    -- so we can safely override them right here without any timing concerns.

    local _orig_IsFreezingEffectBlocked = inst.IsFreezingEffectBlocked

    if _orig_IsFreezingEffectBlocked then

        inst.IsFreezingEffectBlocked = function(self)

            if self.player_classified and self.player_classified.freezeeffectblocked then

                return _orig_IsFreezingEffectBlocked(self)

            end

            return false

        end

    end


    local _orig_IsOverheatingEffectBlocked = inst.IsOverheatingEffectBlocked

    if _orig_IsOverheatingEffectBlocked then

        inst.IsOverheatingEffectBlocked = function(self)

            if self.player_classified and self.player_classified.overheateffectblocked then

                return _orig_IsOverheatingEffectBlocked(self)

            end

            return false

        end

    end


    local _orig_SetFreezingEffectBlockModifier = inst.SetFreezingEffectBlockModifier

    if _orig_SetFreezingEffectBlockModifier then

        inst.SetFreezingEffectBlockModifier = function(self, key, enabled)

            if self.player_classified and self.player_classified.freezeeffectblocked then

                return _orig_SetFreezingEffectBlockModifier(self, key, enabled)

            end

        end

    end


    local _orig_SetOverheatingEffectBlockModifier = inst.SetOverheatingEffectBlockModifier

    if _orig_SetOverheatingEffectBlockModifier then

        inst.SetOverheatingEffectBlockModifier = function(self, key, enabled)

            if self.player_classified and self.player_classified.overheateffectblocked then

                return _orig_SetOverheatingEffectBlockModifier(self, key, enabled)

            end

        end

    end


    -- player_classified compat patch applied


    -- DEFERRED: patch wx78_classified after original mod's PostInit sets it up

    inst:DoTaskInTime(0, function(inst)

        if not inst or not inst:IsValid() then return end

        if inst.wx78_classified then

            if not inst.wx78_classified.GetNumFreeShadowDrone_Harvesters then

                inst.wx78_classified.GetNumFreeShadowDrone_Harvesters = function(self) return 0 end

            end

            if not inst.wx78_classified.GetNumFreeDeliveryDrones then

                inst.wx78_classified.GetNumFreeDeliveryDrones = function(self) return 0 end

            end

            if not inst.wx78_classified.GetMaxShadowDrone_Harvesters then

                inst.wx78_classified.GetMaxShadowDrone_Harvesters = function(self) return 0 end

            end

            -- wx78_classified compat patch applied

        end

    end)

end)


--==================================================================================

-- CRAFTING LIMITS (Engineer & Toymaker Bots)

--==================================================================================

AddComponentPostInit("builder", function(self)

    local old_DoBuild = self.DoBuild

    function self:DoBuild(recname, pt, rotation, skin)

        local limits = {

            esentry = { max = 2, prefabs = {"esentry"} },

            dispenser = { max = 1, prefabs = {"dispenser"} },

            eteleporter = { max = 2, prefabs = {"eteleporter"} },

            eteleporter_exit = { max = 2, prefabs = {"eteleporter_exit"} },

            williambutler_builder = { max = 1, prefabs = {"williambutler", "williambutler_empty", "williambutler2"} },

            williambuster_builder = { max = 1, prefabs = {"williambuster", "williambuster_empty", "williambuster2", "williambuster3"} },

            williambrute_builder = { max = 1, prefabs = {"williambrute", "williambrute_empty", "williambrute_gary", "williambrute2", "williambrute3"} },

            williamballistic_empty = { max = 1, prefabs = {"williamballistic", "williamballistic_empty", "williamballistic2"} }

        }


        local lim = limits[recname]

        if lim then

            local count = 0

            

            -- Count in world

            for k, v in pairs(GLOBAL.Ents) do

                if v and v:IsValid() and not v:HasTag("INLIMBO") then

                    local match = false

                    for _, p in ipairs(lim.prefabs) do

                        if v.prefab == p then match = true break end

                    end

                    if match then

                        -- Check if it belongs to this player

                        local is_owner = false

                        -- BUG FIX 9: Check owner_guid first (most reliable)
                        if v.owner_guid and v.owner_guid == self.inst.GUID then
                            is_owner = true
                        end

                        if not is_owner and v.maker == self.inst.name then is_owner = true end

                        if not is_owner and v.turretID and v.turretID == self.inst.engieID then is_owner = true end

                        if not is_owner and v.dispenserID and v.dispenserID == self.inst.engieID then is_owner = true end

                        if not is_owner and v.telenterID and v.telenterID == self.inst.engieID then is_owner = true end

                        if not is_owner and v.telexitID and v.telexitID == self.inst.engieID then is_owner = true end

                        -- For pets

                        if not is_owner and v.components.follower and v.components.follower.leader == self.inst then is_owner = true end

                        

                        if is_owner then

                            count = count + 1

                        end

                    end

                end

            end

            

            -- Count in inventory

            if self.inst.components.inventory then

                local items = self.inst.components.inventory:FindItems(function(it)

                    for _, p in ipairs(lim.prefabs) do

                        if it.prefab == p then return true end

                    end

                    return false

                end)

                count = count + #items

                for _, slot in pairs(self.inst.components.inventory.equipslots) do

                    for _, p in ipairs(lim.prefabs) do

                        if slot.prefab == p then count = count + 1 break end

                    end

                end

            end


            -- Also check petleash for bots

            if self.inst.components.petleash then

                local pets = self.inst.components.petleash:GetPets()

                for _, p in ipairs(lim.prefabs) do

                    for _, pet in pairs(pets) do

                        if pet.prefab == p then

                            count = count + 1

                        end

                    end

                end

            end


            if count >= lim.max then

                if self.inst.components.talker then

                    self.inst.components.talker:Say("I've reached my limit for this!")

                end

                return false

            end

        end


        return old_DoBuild(self, recname, pt, rotation, skin)

    end

end)


--==================================================================================

-- COMPONENT PATCHES (Miami Ricky compatibility)

--==================================================================================


-- DISABLED: Component patches for deleted Miami Ricky components
--[[AddComponentPostInit("miamirick_augments", function(self)

    local old_Activate = self.Activate

    self.Activate = function(self, doer)

        if doer and doer.components.wagstaff_augments then

            if self.inst:HasTag("miamirick_hand") then

                doer.components.wagstaff_augments:EnableHand()

            elseif self.inst:HasTag("miamirick_leg") then

                doer.components.wagstaff_augments:EnableLeg()

            end

            return

        end

        return old_Activate(self, doer)

    end

end)--]]


-- Standalone aug toggle action (for hand/leg machine items)

local AUG_TOGGLE = AddAction("WAGSTAFF_ACTIVATE_AUG", "Augment Toggle", function(act)

    local item = act.invobject

    if item then

        if item.components.miamirick_augments then

            item.components.miamirick_augments:Activate(act.doer)

        elseif item.components.machine then

            if item.components.machine.ison then

                item.components.machine:TurnOff()

            else

                item.components.machine:TurnOn()

            end

        end

    end

    return true

end)


-- miamirick_flicker standalone: custom FLICKERTELEPORT action

local FLICKERTELEPORT = AddAction("WAGSTAFF_FLICKERTELEPORT", "Flicker", function(act)

    local item = act.invobject

    if item then

        if item.components.miamirick_flicker then

            item.components.miamirick_flicker:Activate(act.doer)

        elseif item.DoFlicker then

            item.DoFlicker(act.doer)

        end

    end

    return true

end)


-- Single inventoryitem action handler for all standalone Miami Rick inventory items.

-- Uses 'inventoryitem' component (always has replica) + tag checks so it works client-side.

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions, right)

    if inst:HasTag("miamirick_hand") or inst:HasTag("miamirick_leg") then

        table.insert(actions, AUG_TOGGLE)

    end

    if inst:HasTag("miamirick_flicker") then

        table.insert(actions, FLICKERTELEPORT)

    end

end)


-- Stategraph states required for actions to execute (mirrors Miami Rick's miamirick_drinkaction.lua pattern)

local _State      = G.State

local _TimeEvent  = G.TimeEvent

local _EventHandler = G.EventHandler

local _FRAMES     = G.FRAMES


local wagstaff_aug_state = _State({

    name = "wagstaff_activate_aug",

    tags = {"doing", "busy"},

    onenter = function(inst)

        inst.components.locomotor:Stop()

        inst.AnimState:PlayAnimation("pickup")

        inst.AnimState:PushAnimation("pickup_pst", false)

        inst.components.inventory:ReturnActiveActionItem(inst.bufferedaction ~= nil and inst.bufferedaction.invobject or nil)

    end,

    timeline = {

        _TimeEvent(1 * _FRAMES, function(inst) inst:PerformBufferedAction() end),

    },

    events = {

        _EventHandler("animqueueover", function(inst)

            if inst.AnimState:AnimDone() then inst.sg:GoToState("idle") end

        end),

    },

    onexit = function(inst) end,

})

local wagstaff_aug_state_client = _State({

    name = "wagstaff_activate_aug",

    tags = {"doing", "busy", "canrotate"},

    onenter = function(inst)

        inst.components.locomotor:Stop()

        inst.AnimState:PlayAnimation("pickup")

        inst:PerformPreviewBufferedAction()

        inst.sg:SetTimeout(1)

    end,

    onupdate = function(inst)

        if inst:HasTag("doing") then

            if inst.entity:FlattenMovementPrediction() then inst.sg:GoToState("idle", "noanim") end

        elseif inst.bufferedaction == nil then

            inst.sg:GoToState("idle")

        end

    end,

    ontimeout = function(inst) inst:ClearBufferedAction() inst.sg:GoToState("idle") end,

})

AddStategraphState("wilson", wagstaff_aug_state)

AddStategraphState("wilson_client", wagstaff_aug_state_client)

local aug_ah = G.ActionHandler(AUG_TOGGLE, "wagstaff_activate_aug")

AddStategraphActionHandler("wilson", aug_ah)

AddStategraphActionHandler("wilson_client", aug_ah)


local wagstaff_flicker_state = _State({

    name = "wagstaff_flicker",

    tags = {"doing", "busy"},

    onenter = function(inst)

        inst.components.locomotor:Stop()

        inst.AnimState:PlayAnimation("give")

        inst.components.inventory:ReturnActiveActionItem(inst.bufferedaction ~= nil and inst.bufferedaction.invobject or nil)

    end,

    timeline = {

        _TimeEvent(1 * _FRAMES, function(inst) inst:PerformBufferedAction() end),

    },

    events = {

        _EventHandler("animqueueover", function(inst)

            if inst.AnimState:AnimDone() then inst.sg:GoToState("idle") end

        end),

    },

    onexit = function(inst) inst.AnimState:PlayAnimation("idle") end,

})

local wagstaff_flicker_state_client = _State({

    name = "wagstaff_flicker",

    tags = {"doing", "busy", "canrotate"},

    onenter = function(inst)

        inst.components.locomotor:Stop()

        inst.AnimState:PlayAnimation("give")

        inst:PerformPreviewBufferedAction()

        inst.sg:SetTimeout(1)

    end,

    onupdate = function(inst)

        if inst:HasTag("doing") then

            if inst.entity:FlattenMovementPrediction() then inst.sg:GoToState("idle", "noanim") end

        elseif inst.bufferedaction == nil then

            inst.sg:GoToState("idle")

        end

    end,

    ontimeout = function(inst) inst:ClearBufferedAction() inst.sg:GoToState("idle") end,

})

AddStategraphState("wilson", wagstaff_flicker_state)

AddStategraphState("wilson_client", wagstaff_flicker_state_client)

local flicker_ah = G.ActionHandler(FLICKERTELEPORT, "wagstaff_flicker")

AddStategraphActionHandler("wilson", flicker_ah)

AddStategraphActionHandler("wilson_client", flicker_ah)


-- DISABLED: miamirick_flicker component (deleted)
--[[AddComponentPostInit("miamirick_flicker", function(self)

    local old_Activate = self.Activate

    self.Activate = function(self, doer)

        if doer and doer.components.wagstaff_augments then

            if doer.components.sanity then

                doer.components.sanity:DoDelta(-15)

            end

            local maxuses = TUNING.DES_MIAMIRICK_FLICKER_MAXUSES or 20

            self.uses = (self.uses or maxuses) - 1

            if self.uses <= 0 then

                if doer.components.inventory then

                    doer.components.inventory:RemoveItem(self.inst)

                end

                self.inst:Remove()

                return

            end

            local x, y, z = doer.Transform:GetWorldPosition()

            local offset = G.FindWalkableOffset(doer:GetPosition(), math.random() * 2 * G.PI, 12, 8)

            if offset then

                G.SpawnPrefab("shadow_despawn").Transform:SetPosition(x, y, z)

                doer.Physics:Teleport(x + offset.x, 0, z + offset.z)

                G.SpawnPrefab("shadow_despawn").Transform:SetPosition(x + offset.x, 0, z + offset.z)

            end

            return

        end

        return old_Activate(self, doer)

    end

end)--]]


--==================================================================================

-- WAGSTAFF POST INIT (add augments component + flicker pre-damage dodge)

--==================================================================================

AddPrefabPostInit("wagstaff", function(inst)

    if not G.TheWorld or not G.TheWorld.ismastersim then return end

    if not inst.components.wagstaff_augments then

        inst:AddComponent("wagstaff_augments")

    end


    -- Blink Recall: auto-teleport when attacked (only with skill active)

    inst:ListenForEvent("attacked", function(inst, data)

        -- BlinkMK2: Attacked event processed

        if inst:HasTag("wagstaff_flicker_mk2") and inst.components.wagstaff_augments then

            -- BlinkMK2: Calling OnAttackedFlicker

            inst.components.wagstaff_augments:OnAttackedFlicker(data)

        end

    end)


    -- Miami Rick mechanic: 5% chance to spawn monster portal when crafting

    local function TryEvilPortalOnCraft(inst, data)

        if math.random() < 0.05 then

            local x, y, z = inst.Transform:GetWorldPosition()

            -- Find a random valid point nearby

            local angle = math.random() * 2 * math.pi

            local dist = 3 + math.random() * 5

            local px = x + math.cos(angle) * dist

            local pz = z + math.sin(angle) * dist

            if G.TheWorld.Map:IsPassableAtPoint(px, 0, pz) then

                local portal = G.SpawnPrefab("wagstaff_evil_portal")

                if portal then

                    portal.Transform:SetPosition(px, 0, pz)

                end

                if inst.components.talker then

                    inst.components.talker:Say("What did I just create...?")

                end

            end

        end

    end

    inst:ListenForEvent("builditem", TryEvilPortalOnCraft)

    inst:ListenForEvent("buildstructure", TryEvilPortalOnCraft)

end)


--==================================================================================

-- STRINGS (item names/descriptions)

--==================================================================================

AddSimPostInit(function()

    local STRINGS = G.STRINGS

    -- Engineer items

    STRINGS.NAMES.TF2WRENCH = "Calibrated Wrench"

    STRINGS.RECIPE_DESC.TF2WRENCH = "For building and repairing machinery."

    STRINGS.NAMES.SCRAP = "Scrap Metal"

    STRINGS.RECIPE_DESC.SCRAP = "Raw materials for engineering."

    STRINGS.NAMES.EHARDHAT = "Hard Hat"

    STRINGS.RECIPE_DESC.EHARDHAT = "Protect your noggin."

    STRINGS.NAMES.ESENTRY = "Sentry Gun"

    STRINGS.RECIPE_DESC.ESENTRY = "Automatic defense system."

    STRINGS.NAMES.DISPENSER = "Dispenser"

    STRINGS.RECIPE_DESC.DISPENSER = "Restores health and hunger."

    STRINGS.NAMES.ETELEPORTER = "Teleporter Entrance"

    STRINGS.RECIPE_DESC.ETELEPORTER = "Instant travel between two points."

    STRINGS.NAMES.ETELEPORTER_EXIT = "Teleporter Exit"

    STRINGS.RECIPE_DESC.ETELEPORTER_EXIT = "Destination for teleporter."

    STRINGS.NAMES.GIBUS = "Gibus Hat"

    STRINGS.RECIPE_DESC.GIBUS = "A true engineer's hat."

    -- Robert Wagstaff items

    STRINGS.NAMES.TESLAFLAIL = "Static Flail"

    STRINGS.RECIPE_DESC.TESLAFLAIL = "Electrified weapon."

    STRINGS.NAMES.COMPASSVEST = "Locational Harness"

    STRINGS.RECIPE_DESC.COMPASSVEST = "Navigational aid and protection."

    STRINGS.NAMES.REFINERY_BOARDS = "Mini-Mill"

    STRINGS.RECIPE_DESC.REFINERY_BOARDS = "Automated board production."

    STRINGS.NAMES.REFINERY_PAPYRUS = "Paper Pulveriser"

    STRINGS.RECIPE_DESC.REFINERY_PAPYRUS = "Automated papyrus production."

    STRINGS.NAMES.REFINERY_ROPE = "Cuttings Coiler"

    STRINGS.RECIPE_DESC.REFINERY_ROPE = "Automated rope production."

    STRINGS.NAMES.REFINERY_CUTSTONE = "Granite Grinder"

    STRINGS.RECIPE_DESC.REFINERY_CUTSTONE = "Automated cut stone production."

    -- Describe texts for engineer buildings (single-entity: world + carriable)

    if not STRINGS.CHARACTERS then STRINGS.CHARACTERS = {} end

    if not STRINGS.CHARACTERS.GENERIC then STRINGS.CHARACTERS.GENERIC = {} end

    if not STRINGS.CHARACTERS.GENERIC.DESCRIBE then STRINGS.CHARACTERS.GENERIC.DESCRIBE = {} end

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.ESENTRY = "An automated gun turret. Use wrench to upgrade."

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.DISPENSER = "Heals nearby allies. Use wrench to upgrade."

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.ETELEPORTER = "Activate to teleport to the exit."

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.ETELEPORTER_EXIT = "The teleportation destination."

    -- Wagstaff automation bots (MK1/MK2/MK3 variants share the same generic description)
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBUTLER = "An automated servant bot. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBUTLER2 = "An automated servant bot. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBUTLER3 = "An automated servant bot. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBRUTE = "A heavy combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBRUTE2 = "A heavy combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBRUTE3 = "A heavy combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBUSTER = "A combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBUSTER2 = "A combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBUSTER3 = "A combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBALLISTIC = "An electric combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBALLISTIC2 = "An electric combat automaton. Use wrench to upgrade."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WILLIAMBALLISTIC3 = "An electric combat automaton. Use wrench to upgrade."

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.REFINERY_BOARDS = "Give it logs to produce boards. (2:1)"

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.REFINERY_PAPYRUS = "Give it cut reeds to produce papyrus. (2:1)"

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.REFINERY_ROPE = "Give it cut grass to produce rope. (2:1)"

    STRINGS.CHARACTERS.GENERIC.DESCRIBE.REFINERY_CUTSTONE = "Give it rocks to produce cut stone. (2:1)"

    -- Wagstaff speech strings (prevent UNKNOWN STRING messages)

    if not STRINGS.CHARACTERS.WAGSTAFF then STRINGS.CHARACTERS.WAGSTAFF = {} end

    if not STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE then STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE = {} end

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_REPLANTING = "One moment, I must relocate this flora."

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_PACKINGUP = "Disassembling for transport."

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_ENGIE_TELEPORT = "My atoms are being rearranged!"

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_UNIMPLEMENTED = "This device requires further calibration."

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_SENTRYBUILT = "Turret operational!"

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_DISPENSERBUILT = "Healing station assembled!"

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_TELEPORTERBUILT = "Teleportation matrix established!"

    -- v2.0.17: announce strings for when these structures are HAMMERED/destroyed.
    -- Previously missing — caused "STRING UNKNOWN" / broken text when the player
    -- hammered a dispenser, sentry, or teleporter entrance/exit.
    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_DISPENSER_DOWN = "My dispensing unit! Reduced to scrap."

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_SENTRY_DOWN = "My turret! Downed in the line of duty."

    STRINGS.CHARACTERS.WAGSTAFF.ANNOUNCE_TELEPORTER_DOWN = "The teleportation link has been severed!"

    -- Skill tree column titles

    if not STRINGS.SKILLTREE then STRINGS.SKILLTREE = {} end

    if not STRINGS.SKILLTREE.WAGSTAFF then STRINGS.SKILLTREE.WAGSTAFF = {} end

    STRINGS.SKILLTREE.WAGSTAFF.TITLE_MECHANICAL = "Engineering"

    STRINGS.SKILLTREE.WAGSTAFF.TITLE_ROBOTIC = "Robotics"

    STRINGS.SKILLTREE.WAGSTAFF.TITLE_GADGET = "Gadgets"

    STRINGS.SKILLTREE.WAGSTAFF.TITLE_ALLEGIANCE = "Allegiance"

    -- Skill tree panel names (used by skilltreebuilder STRINGS.SKILLTREE.PANELS[group:upper()])

    if not STRINGS.SKILLTREE.PANELS then STRINGS.SKILLTREE.PANELS = {} end

    STRINGS.SKILLTREE.PANELS.MECHANICAL = "Engineering"

    STRINGS.SKILLTREE.PANELS.ROBOTIC    = "Robotics"

    STRINGS.SKILLTREE.PANELS.GADGET     = "Gadgets"

    STRINGS.SKILLTREE.PANELS.ALLEGIANCE = "Allegiance"

    -- Skill tree panel names (used by skilltreebuilder to label each column)

    if not STRINGS.SKILLTREE.PANELS then STRINGS.SKILLTREE.PANELS = {} end

    STRINGS.SKILLTREE.PANELS.MECHANICAL  = "Engineering"

    STRINGS.SKILLTREE.PANELS.ROBOTIC     = "Robotics"

    STRINGS.SKILLTREE.PANELS.GADGET      = "Gadgets"

    STRINGS.SKILLTREE.PANELS.ALLEGIANCE  = "Allegiance"

    -- William Toymaker bots

    STRINGS.NAMES.WILLIAMGADGET = "Machine Hearth"

    -- v2.0.41: RE-ADDED STRINGS.NAMES for all bot tiers (butler MK1/MK2/MK3
    -- + buster3/brute3/ballistic3 that were missing).
    --
    -- BACKGROUND: v2.0.20 removed STRINGS.NAMES.WILLIAMBUTLER /
    -- WILLIAMBUTLER2 because they "masked the replica.named name" — that
    -- was true BEFORE displaynamefn existed (v2.0.18 added displaynamefn,
    -- which has HIGHEST priority in GetDisplayName, so STRINGS.NAMES no
    -- longer masks the fuel/HP string). The removal was based on outdated
    -- reasoning.
    --
    -- ROOT CAUSE of the butler MK1 "name repeating" bug: without
    -- STRINGS.NAMES, the engine's GetBasicDisplayName() falls back to
    -- inst.name. On the CLIENT, inst.name is set to the FULL named string
    -- ("Butler Bot\nFuel: X% | HP: X/X") by the named replica's netvar
    -- sync. So GetBasicDisplayName() returns the full string, AND
    -- GetDisplayName() (via displaynamefn) ALSO returns the full string.
    -- Some hover UI elements show BOTH → the name appears twice (exact
    -- repetition). Buster/brute/ballistic MK1/MK2 don't have this bug
    -- because they HAVE STRINGS.NAMES, so GetBasicDisplayName() returns a
    -- SHORT title ("Buster Bot") while GetDisplayName() returns the full
    -- string — the short title is the first line of the full string, so it
    -- looks like a normal tooltip (title + detail), not repetition.
    --
    -- FIX: define STRINGS.NAMES for every bot tier. The value MUST EXACTLY
    -- MATCH the displaynamefn base name (the first line of the full
    -- displaynamefn string) — otherwise the short title and the first line
    -- of the detail differ, causing a "jumbled" appearance (this was the
    -- v2.0.33 MK2 bug: STRINGS had "Mk.II" but displaynamefn had "Mk. II").
    --
    -- Butler uses "Mk. II" / "Mk. III" (WITH space after the dot) in its
    -- displaynamefn base names, so the STRINGS values must use the same.
    -- Buster/Brute/Ballistic use "Mk.II" / "Mk.III" (NO space) in theirs.

    STRINGS.NAMES.WILLIAMBUTLER = "Butler Bot"

    STRINGS.NAMES.WILLIAMBUTLER2 = "Butler Bot Mk. II"

    STRINGS.NAMES.WILLIAMBUTLER3 = "Butler Bot Mk. III"

    STRINGS.NAMES.WILLIAMBUSTER = "Buster Bot"

    STRINGS.NAMES.WILLIAMBUSTER3 = "Buster Bot Mk.III"

    STRINGS.NAMES.WILLIAMBRUTE = "Brute Bot"

    STRINGS.NAMES.WILLIAMBRUTE2 = "Brute Bot Mk.II"

    STRINGS.NAMES.WILLIAMBRUTE3 = "Brute Bot Mk.III"

    STRINGS.NAMES.WILLIAMBUSTER2 = "Buster Bot Mk.II"

    STRINGS.NAMES.WILLIAMBALLISTIC2 = "Ballistic Bot Mk.II"

    STRINGS.NAMES.WILLIAMBALLISTIC3 = "Ballistic Bot Mk.III"

    STRINGS.NAMES.WILLIAMBALLISTIC = "Ballistic Bot"

    STRINGS.NAMES.WILLIAMBUTLER_BUILDER = "Butler Bot"

    STRINGS.NAMES.WILLIAMBUSTER_BUILDER = "Buster Bot"

    STRINGS.NAMES.WILLIAMBRUTE_BUILDER = "Brute Bot"

    STRINGS.NAMES.WILLIAMBALLISTIC_EMPTY = "Ballistic Bot"

    STRINGS.NAMES.WILLIAMBUTLER_EMPTY = "Butler Bot (Inactive)"

    STRINGS.NAMES.WILLIAMBUSTER_EMPTY = "Buster Bot (Inactive)"

    STRINGS.NAMES.WILLIAMBRUTE_EMPTY = "Brute Bot (Inactive)"

end)


--==================================================================================

-- RECIPES (all integration items)

--==================================================================================

AddSimPostInit(function()

    local Prefabs = G.Prefabs

    local TECH = G.TECH

    local Ingredient = G.Ingredient

    local mimg = function(name) return "images/inventoryimages/"..name..".xml" end

    local eimg = function(name) return "images/engineeritemimages.xml" end


    -- MIAMI RICKY recipes are registered separately below via AddSimPostInit

    -- (patches builder_tag from "miamirick" to "tinkerer" and moves to CHARACTER tab)

    -- THE ENGINEER (TF2)

    AddRecipe2("scrap",

        {Ingredient("flint", 2), Ingredient("twigs", 2)},

        TECH.NONE,

        {builder_tag = "tinkerer", numtogive = 5, atlas = eimg("scrap"), image = "scrap.tex"},

        {"CHARACTER", "REFINE"})

    AddRecipe2("tf2wrench",

        {Ingredient("scrap", 5, eimg("scrap")), Ingredient("twigs", 3)},

        TECH.NONE,

        {builder_tag = "tinkerer", atlas = eimg("tf2wrench"), image = "tf2wrench.tex"},

        {"CHARACTER", "TOOLS"})

    AddRecipe2("esentry",

        {Ingredient("scrap", 30, eimg("scrap")), Ingredient("gears", 3)},  -- v2.0.16: 20 -> 30 (was too cheap for MK3 turret)

        TECH.MAGIC_ONE,

        {builder_tag = "tinkerer", atlas = eimg("esentry"), image = "esentry.tex"},

        {"CHARACTER", "WEAPONS", "STRUCTURES"})

    AddRecipe2("dispenser",

        {Ingredient("scrap", 15, eimg("scrap")), Ingredient("redgem", 3)},

        TECH.SCIENCE_TWO,

        {builder_tag = "tinkerer", atlas = eimg("dispenser"), image = "dispenser.tex"},

        {"CHARACTER", "RESTORATION", "STRUCTURES"})

    AddRecipe2("eteleporter",

        {Ingredient("scrap", 30, eimg("scrap")), Ingredient("gears", 5), Ingredient("transistor", 5)},

        TECH.MAGIC_TWO,

        {builder_tag = "tinkerer", atlas = eimg("eteleporter"), image = "eteleporter.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("eteleporter_exit",

        {Ingredient("scrap", 25, eimg("scrap")), Ingredient("gears", 3), Ingredient("transistor", 3)},

        TECH.MAGIC_TWO,

        {builder_tag = "tinkerer", atlas = eimg("eteleporter_exit"), image = "eteleporter_exit.tex"},

        {"CHARACTER", "STRUCTURES"})


    -- WILLIAM TOYMAKER

    AddRecipe2("williamgadget",

        {Ingredient("gears", 2), Ingredient("goldnugget", 1)},

        TECH.NONE,

        {builder_tag = "tinkerer", numtogive = 1, atlas = mimg("williamgadget"), image = "williamgadget.tex"},

        {"CHARACTER", "REFINE"})


    local williamgadget_ing = Ingredient("williamgadget", 1)

    williamgadget_ing.atlas = mimg("williamgadget")


    AddRecipe2("williambutler_builder",

        {williamgadget_ing, Ingredient("boards", 4), Ingredient("transistor", 2)},

        TECH.SCIENCE_ONE,

        {builder_tag = "tinkerer", atlas = mimg("williambutler_builder"), image = "williambutler_builder.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("williambuster_builder",

        {williamgadget_ing, Ingredient("marble", 3), Ingredient("transistor", 2)},

        TECH.MAGIC_ONE,

        {builder_tag = "tinkerer", atlas = mimg("williambuster_builder"), image = "williambuster_builder.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("williambrute_builder",

        {williamgadget_ing, Ingredient("cutstone", 4), Ingredient("transistor", 2)},

        TECH.SCIENCE_TWO,

        {builder_tag = "tinkerer", atlas = mimg("williambrute_builder"), image = "williambrute_builder.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("williamballistic_empty",

        {williamgadget_ing, Ingredient("nitre", 4), Ingredient("transistor", 2)},

        TECH.MAGIC_TWO,

        {builder_tag = "tinkerer", atlas = mimg("williamballistic_empty"), image = "williamballistic_empty.tex"},

        {"CHARACTER", "STRUCTURES"})


    -- MIAMI RICKY RECIPES (REMOVED PER USER REQUEST)


    -- Winona's Generators (from Wholemaker Wagstaff mod - workshop-3658174287)

    -- These are Wagstaff's original generators, now craftable by him

    -- REMOVED: Winona generator recipes (vestigial)

end)


--==================================================================================

-- REMOVED: Winona generator recreation function
-- SKILL TREE IMPLEMENTATION (functional connections)

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

            if doer and doer:HasTag("wagstaff_efficient_refineries") and math.random() < 0.15 then

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


-- Gadgets

AddPrefabPostInit("tf2wrench", ApplyWrenchSkill)

-- Engineer buildings get skill effects applied

AddPrefabPostInit("dispenser", ApplyResupplyProtocol)

AddPrefabPostInit("eteleporter", ApplyMasterEngineer)

AddPrefabPostInit("eteleporter_exit", ApplyMasterEngineer)


-- Automatons

AddPrefabPostInit("williambutler_builder", ApplyOptimizedFuel)

AddPrefabPostInit("williambutler_builder", ApplyButlerProtocols)

AddPrefabPostInit("williambutler_builder", ApplyPredictiveMaintenance)

AddPrefabPostInit("williambutler_builder", ApplyOverclockProtocol)

AddPrefabPostInit("williambuster_builder", ApplyOptimizedFuel)

AddPrefabPostInit("williambuster_builder", ApplyCombatCoordination)

AddPrefabPostInit("williambuster_builder", ApplyPredictiveMaintenance)

AddPrefabPostInit("williambuster_builder", ApplyOverclockProtocol)


local function MakeTradable(inst)

    if not inst.components.tradable then

        inst:AddComponent("tradable")

        inst.components.tradable.goldvalue = 0

    end

end


-- DISABLED: des_portal_gun_fuel component (deleted)
--[[local function PortalFuelPostInit_1(inst)

    inst:AddComponent("des_portal_gun_fuel")

    inst:AddTag("des_portal_gun_fuel")

    MakeTradable(inst)

    inst.components.des_portal_gun_fuel.portal_fuel = 5

    inst.components.des_portal_gun_fuel.portal_durable = 5

end

local function PortalFuelPostInit_5(inst)

    inst:AddComponent("des_portal_gun_fuel")

    inst:AddTag("des_portal_gun_fuel")

    MakeTradable(inst)

    inst.components.des_portal_gun_fuel.portal_fuel = 25

    inst.components.des_portal_gun_fuel.portal_durable = 25

end

local function PortalFuelPostInit_7(inst)

    inst:AddComponent("des_portal_gun_fuel")

    inst:AddTag("des_portal_gun_fuel")

    MakeTradable(inst)

    inst.components.des_portal_gun_fuel.portal_fuel = 35

    inst.components.des_portal_gun_fuel.portal_durable = 35

end

local function PortalFuelPostInit_10(inst)

    inst:AddComponent("des_portal_gun_fuel")

    inst:AddTag("des_portal_gun_fuel")

    MakeTradable(inst)

    inst.components.des_portal_gun_fuel.portal_fuel = 50

    inst.components.des_portal_gun_fuel.portal_durable = 50

end


AddPrefabPostInit("charcoal", PortalFuelPostInit_1)

AddPrefabPostInit("lightbulb", PortalFuelPostInit_1)

AddPrefabPostInit("slurtleslime", PortalFuelPostInit_1)

AddPrefabPostInit("nightmarefuel", PortalFuelPostInit_5)

AddPrefabPostInit("nitre", PortalFuelPostInit_5)

AddPrefabPostInit("glommerfuel", PortalFuelPostInit_7)

AddPrefabPostInit("redgem", PortalFuelPostInit_7)

AddPrefabPostInit("bluegem", PortalFuelPostInit_7)

AddPrefabPostInit("gears", PortalFuelPostInit_7)

AddPrefabPostInit("purplegem", PortalFuelPostInit_10)

AddPrefabPostInit("moonrocknugget", PortalFuelPostInit_10)

AddPrefabPostInit("moonglass", PortalFuelPostInit_10)--]]


-- Transistor stabilizes portals (matching original mod)

local function TransistorInit(inst)

    inst:AddComponent("tradable")

    inst.components.tradable.goldvalue = 1

    inst:AddTag("miamirick_portal_delaet_dolgim")

end

AddPrefabPostInit("transistor", TransistorInit)


-- DISABLED: Miami Ricky AddPrefabPostInit (prefabs deleted)
--[[AddPrefabPostInit("miamirick_portal_gun", ApplyStabilizedPortalsToPortalGun)

AddPrefabPostInit("miamirick_portal_gun", ApplyCelestialAllegianceToItems)

AddPrefabPostInit("miamirick_hand", ApplyShadowAllegianceToItems)

AddPrefabPostInit("miamirick_hand", ApplyCelestialAllegianceToItems)

AddPrefabPostInit("miamirick_leg", ApplyShadowAllegianceToItems)

AddPrefabPostInit("miamirick_leg", ApplyCelestialAllegianceToItems)

AddPrefabPostInit("miamirick_flicker", ApplyCelestialAllegianceToItems)--]]


-- Robert

AddPrefabPostInit("teslaflail", ApplyShadowAllegianceToItems)

AddPrefabPostInit("teslaflail", ApplyCelestialAllegianceToItems)

AddPrefabPostInit("compassvest", ApplyCelestialAllegianceToItems)


--==================================================================================

-- SUPPRESS gallop_extra_a items (mod 3482371774 - 废铁武器包)

-- Wholemaker Wagstaff had an unnecessary dependency on this mod.

-- If still active, hide its items from crafting menus.

--==================================================================================

local gallop_items = {
    "gallop_extra_a_shield_iron",
    "gallop_extra_a_shield_iron_upgraded",
    "gallop_extra_a_scavenging_axe",
    "gallop_extra_a_moonchargeplasma",
}

AddPrefabPostInit("world", function()
    for _, prefab in ipairs(gallop_items) do
        if G.AllRecipes and G.AllRecipes[prefab] then
            G.AllRecipes[prefab] = nil
        end
    end
end)


--==================================================================================

-- MECHANICAL EFFICIENCY: -15% repair and recharge cost

-- Intercepts finiteuses consumption for items held by Wagstaff with the skill.

--==================================================================================

AddComponentPostInit("finiteuses", function(self)

    local old_Use = self.Use

    self.Use = function(self2, num, ...)

        num = num or 1

        local owner = self2.inst.components.inventoryitem and self2.inst.components.inventoryitem.owner

        if owner and owner:HasTag("wagstaff_mechanical_efficiency") then

            local discounted = math.max(1, math.floor(num * 0.85))

            num = discounted

        end

        return old_Use(self2, num, ...)

    end

end)


-- Also intercept fueled consumption (bots/gadgets refueling)

AddComponentPostInit("fueled", function(self)

    local old_TakeFuel = self.TakeFuel

    self.TakeFuel = function(self2, item, doer, ...)

        if doer and doer:HasTag("wagstaff_mechanical_efficiency") then

            -- 15% chance to not consume the fuel item (simulating -15% cost)

            if math.random() < 0.15 then

                local old_rate = self2.bonus_ratio or 1

                self2.bonus_ratio = 0  -- Don't consume item this time

                local result = old_TakeFuel(self2, item, doer, ...)

                self2.bonus_ratio = old_rate

                return result

            end

        end

        return old_TakeFuel(self2, item, doer, ...)

    end

end)


--==================================================================================

-- BUTLER UPGRADE: Butler Bot Level 2 gains 3 cook slots and auto-picking

--==================================================================================


--==================================================================================

-- TELEBRELLA NERF: Reduce to 1 use

--==================================================================================

-- DISABLED: telebrella and miamirick_telebrella (prefabs deleted)
--[[AddPrefabPostInit("telebrella", function(inst)
    if G.TheWorld.ismastersim then
        inst:DoTaskInTime(0, function()
            if inst.components.finiteuses then
                inst.components.finiteuses:SetMaxUses(1)
                inst.components.finiteuses:SetUses(1)
            end
        end)
    end
end)

AddPrefabPostInit("miamirick_telebrella", function(inst)
    if G.TheWorld.ismastersim then
        inst:DoTaskInTime(0, function()
            if inst.components.finiteuses then
                inst.components.finiteuses:SetMaxUses(1)
                inst.components.finiteuses:SetUses(1)
            end
        end)
    end
end)--]]


--==================================================================================
-- DISABLE HAMMER ON ACTIVE WILLIAM BOTS (allow hammer on empty husks / off brute)
--==================================================================================
-- Active bots are repaired/upgraded with wrench only. Empty husks (_empty) and
-- powered-off Brute bots can still be dismantled with a regular hammer.
AddComponentAction("SCENE", "workable", function(inst, doer, actions, right)
    if inst.prefab == nil then
        return
    end

    local is_empty_husk = inst.prefab:find("_empty") ~= nil
    local is_brute_off = (inst.prefab == "williambrute" or inst.prefab == "williambrute2" or inst.prefab == "williambrute3")
        and inst.on == false

    if is_empty_husk or is_brute_off then
        return
    end

    local is_william_bot = inst.prefab:find("william") ~= nil
    if not is_william_bot then
        return
    end

    for i = #actions, 1, -1 do
        if actions[i] == G.ACTIONS.HAMMER then
            table.remove(actions, i)
        end
    end
end)


----------------------------------------------------------
-- Standalone mod imports (Hamlet Characters Wagstaff scripts)
----------------------------------------------------------
modimport("scripts/hamlet_character_sounds")
modimport("scripts/hamlet_character_tuning")
modimport("scripts/hamlet_character_strings")
modimport("scripts/hamlet_character_menustrings")
if GLOBAL.HCM_LANG == "ch" then
    -- Chinese string overrides would go here if a strings_ch.lua is added later
    -- modimport("scripts/strings_ch")
end
modimport("scripts/hamlet_character_postinits")
modimport("scripts/hamlet_character_stategraph")
modimport("scripts/hamlet_character_recipes")
modimport("scripts/hamlet_character_shaders")
----------------------------------------------------------


-- Register Wagstaff as a playable character
AddModCharacter("wagstaff", "MALE",
    {
        {type = "ghost_skin", anim_bank = "ghost", idle_anim = "idle", scale = 0.75, offset = {0, 25}},
    }
)

-- Gorge lobby voice
if GorgeEnv ~= nil then
    GorgeEnv.AddLobbyVoice("wagstaff", "wagstaff")
end
