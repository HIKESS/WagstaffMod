-- ============================================================================
-- Wagstaff Standalone (Integrated) — modmain.lua
-- Merges the clean Hamlet Characters Wagstaff (character + assets + scripts)
-- WITH the Wagstaff Integration Patch features (skill tree, XP progression,
-- William Toymaker bots, Engineer sentry/dispenser/eteleporter, augment +
-- flicker actions, per-world persistence, boss kill tracking).
-- ============================================================================


local G = GLOBAL

-- Get rawset and rawget from the real global table
local rawset = G.rawset
local rawget = G.rawget

-- Safe aliases for Lua base iteration functions (they may not be in the global
-- environment during certain mod-load phases in DST).
local pairs = G.pairs or pairs
local ipairs = G.ipairs or ipairs
local next = G.next or next

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

-- ============================================================================
-- WAGSTAFF SKILL TREE RPC HELPERS
-- ============================================================================
-- Em mundos com caves o Master e o Caves carregam em paralelo. Durante essa
-- janela GLOBAL.TheSkillTree pode ainda estar nil ou sem RPC_LOOKUP, enquanto
-- prefabs/skilltree_defs ja possui SKILLTREE_METAINFO.wagstaff.RPC_LOOKUP.
-- O helper abaixo resolve a skill pelo fallback correto e tambem publica o
-- lookup no TheSkillTree quando ele fica disponivel.
-- Garantir alias local seguro para debug, mesmo que G.WagstaffDebug ainda nao exista
local WagstaffDebug = (G.WagstaffDebug ~= nil) and G.WagstaffDebug or function(...) end

local function WagstaffGetSkillTreeDefs()
    if require == nil then
        return nil
    end
    local ok, defs = GLOBAL.pcall(require, "prefabs/skilltree_defs")
    if ok then
        return defs
    end
    return nil
end

local function WagstaffGetRPCLookup()
    local defs = WagstaffGetSkillTreeDefs()

    -- Preferir a tabela da engine quando existir.
    if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.RPC_LOOKUP then
        return GLOBAL.TheSkillTree.RPC_LOOKUP
    end

    -- Fallback principal: criado por CreateSkillTreeFor antes de TheSkillTree existir.
    if defs and defs.SKILLTREE_METAINFO and defs.SKILLTREE_METAINFO["wagstaff"] then
        local meta = defs.SKILLTREE_METAINFO["wagstaff"]
        if meta.RPC_LOOKUP then
            return meta.RPC_LOOKUP
        end
    end

    -- Fallback extra: algumas versoes/ordens de load guardam em SKILLTREE_DEFS.
    if defs and defs.SKILLTREE_DEFS and defs.SKILLTREE_DEFS["wagstaff"] then
        local meta = defs.SKILLTREE_DEFS["wagstaff"].meta
        if meta and meta.RPC_LOOKUP then
            return meta.RPC_LOOKUP
        end
    end

    -- Ultimo fallback caso alguma versao exponha direto em skilltree_defs.
    if defs and defs.RPC_LOOKUP then
        return defs.RPC_LOOKUP
    end

    return nil
end

local function WagstaffResolveSkillRPCID(skill_name)
    if type(skill_name) ~= "string" then
        return skill_name
    end

    local lookup = WagstaffGetRPCLookup()
    if not lookup then
        return nil
    end

    -- Formato possivel A: skill_name -> rpc_id
    local direct = lookup[skill_name]
    if type(direct) == "number" then
        return direct
    end

    -- Formato observado nos logs: rpc_id -> skill_name
    for rpc_id, name in pairs(lookup) do
        if name == skill_name and type(rpc_id) == "number" then
            return rpc_id
        end
    end

    return nil
end

local function WagstaffPublishRPCLookup()
    local lookup = WagstaffGetRPCLookup()
    if lookup and GLOBAL.TheSkillTree then
        GLOBAL.TheSkillTree.RPC_LOOKUP = lookup
        local count = 0
        for _ in pairs(lookup) do
            count = count + 1
        end
        WagstaffDebug("Published Wagstaff RPC_LOOKUP to TheSkillTree, count:", count)
        return true
    end
    return false
end

local function WagstaffScheduleRPCPublish()
    -- Tenta agora; se TheSkillTree ainda nao existir, tenta de novo assim que o mundo existe.
    if WagstaffPublishRPCLookup() then
        return
    end
    if GLOBAL.TheWorld and GLOBAL.TheWorld.DoTaskInTime then
        for i = 1, 20 do
            GLOBAL.TheWorld:DoTaskInTime(0.1 * i, function()
                WagstaffPublishRPCLookup()
            end)
        end
    end
end

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

-- Bypass strict mode for our variables
rawset(G, "strict", false)
G.WagstaffDebug("Standalone Wagstaff Integration mod is loading!")


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

TUNING.ETELEPORT_PENALTY = 0

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
    Asset("IMAGE", "images/minimap/esentry.tex"),
    Asset("IMAGE", "images/minimap/esentry_2.tex"),
    Asset("IMAGE", "images/minimap/esentry_3.tex"),
    Asset("IMAGE", "images/minimap/dispenser.tex"),
    Asset("IMAGE", "images/minimap/eteleporter.tex"),
    Asset("IMAGE", "images/minimap/eteleporterentrance.tex"),
    Asset("IMAGE", "images/minimap/eteleporterexit.tex"),
    Asset("IMAGE", "images/map_icons/williambutler.tex"),
    Asset("IMAGE", "images/map_icons/williambuster.tex"),
    Asset("IMAGE", "images/map_icons/williambrute.tex"),
    Asset("IMAGE", "images/map_icons/williamballistic.tex"),
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

    AffinityPulse.Setup = function(inst, GetOwnerFn)

        inst._aff_step = 1

        inst._aff_dir  = 1

        inst:DoPeriodicTask(PULSE_PERIOD, function()

            if not inst:IsValid() then return end

            if inst:HasTag("shadow_buster_clone") then return end

            -- Only run for MK3 versions of the bots
            local is_mk3 = inst.prefab == "williambutler3" or 
                          inst.prefab == "williambuster3" or 
                          inst.prefab == "williamballistic3" or 
                          inst.prefab == "williambrute3"
            if not is_mk3 then
                inst.AnimState:SetAddColour(0, 0, 0, 0)
                inst.AnimState:SetMultColour(1, 1, 1, 1)
                inst._aff_step = 1
                inst._aff_dir  = 1
                return
            end

            local owner   = GetOwnerFn and GetOwnerFn(inst)

            local isday   = GLOBAL.TheWorld.state.isday

            local isdusk  = GLOBAL.TheWorld.state.isdusk

            local celestial = owner and owner:HasTag("wagstaff_celestial_possession")

            local shadow    = owner and owner:HasTag("wagstaff_shadow_possession")

            if isday and celestial then

                local s = CELESTIAL_STEPS[inst._aff_step]

                inst.AnimState:SetAddColour(s.add[1], s.add[2], s.add[3], s.add[4])

                inst.AnimState:SetMultColour(s.mul[1], s.mul[2], s.mul[3], s.mul[4])

            elseif isdusk and shadow then

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

-- Internal flag: true while we are doing our own XP injection (to bypass the filter below)
local _wagstaff_xp_injecting = false

local WAGSTAFF_SKILL_THRESHOLDS = {3,6,10,14,18,23,28,33,38,43,48,53,58,63,68}

-- Cluster-aware days survived: reads from the Master/connected shard cluster save
-- data when available (via GetSharedSaveData), falling back to local state.cycles.
-- This prevents cave shards from reporting day 0 and zeroing out insights/skills.
local function GetWagstaffDaysSurvived()
    -- 1. Local cached value set by Master sync (highest priority)
    if GLOBAL.TheWorld and GLOBAL.TheWorld._wagstaff_days_survived ~= nil then
        return GLOBAL.TheWorld._wagstaff_days_survived
    end
    -- 2. Shared cluster save data (autoritativo do Master)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.network and GLOBAL.TheWorld.network.GetSharedSaveData then
        local shared = GLOBAL.TheWorld.network:GetSharedSaveData()
        if shared and shared.wagstaff_days_survived ~= nil then
            return shared.wagstaff_days_survived
        end
    end
    -- 3. Fallback to local world state (non-cave or pre-sync)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.state then
        return GLOBAL.TheWorld.state.cycles or 0
    end
    return 0
end

-- Merge cluster-shared skills into the local world table if available.
-- This is the Camada C bridge: reads from GetSharedSaveData and overrides
-- _wagstaff_activated_skills when the cluster data is more complete.
local function WagstaffMergeClusterSaveData(self)
    if self.network and self.network.GetSharedSaveData then
        local shared = self.network:GetSharedSaveData()
        if shared and type(shared) == "table" and shared.wagstaff_activated_skills then
            WagstaffDebug("[CLUSTER] Merging cluster skills into local world, count:", shared.wagstaff_activated_skills)
            self._wagstaff_activated_skills = CopyActivatedSkills(shared.wagstaff_activated_skills)
            -- Also sync days if available
            if shared.wagstaff_days_survived ~= nil then
                self._wagstaff_days_survived = shared.wagstaff_days_survived
            end
            return true
        end
    end
    return false
end

local function GetWagstaffMaxInsights(days)
    days = days or GetWagstaffDaysSurvived()
    local total = 0
    for i, threshold in ipairs(WAGSTAFF_SKILL_THRESHOLDS) do
        if days >= threshold then
            total = i
        else
            break
        end
    end
    return math.clamp(total, 0, 15)
end

local function GetWagstaffSkillXPFromDays(days)
    return math.min(days or 0, 68)
end

local function SortedActivatedSkillKeys(skills_map)
    local keys = {}
    if skills_map == nil then
        return keys
    end
    for skill, active in pairs(skills_map) do
        if active and not string.find(skill, "_lock") then
            table.insert(keys, skill)
        end
    end
    table.sort(keys)
    return keys
end

local function CopyActivatedSkills(source)
    local copy = {}
    if source == nil then
        return copy
    end
    for skill, active in pairs(source) do
        if active then
            copy[skill] = true
        end
    end
    return copy
end

-- Used by bot/sentry/dispenser upgrade checks: tag OR activated skill (re-applies tag if missing)
G.WagstaffHasSkill = function(worker, skill_id)
    print("[DEBUG WagstaffHasSkill] === CHAMADA DE WagstaffHasSkill ===")
    print("[DEBUG WagstaffHasSkill] worker:", worker, worker and worker.prefab or "NIL")
    print("[DEBUG WagstaffHasSkill] skill_id:", skill_id)
    
    if not worker or not skill_id then
        print("[DEBUG WagstaffHasSkill] worker ou skill_id nil, retornando false")
        return false
    end
    
    -- CRITICAL FIX #1: Check if the TAG exists FIRST (before checking activatedskills)
    -- Many skills add tags with DIFFERENT names than their skill_id
    -- Example: wagstaff_robotic_1 adds tag wagstaff_brute_evolve
    local has_tag = worker:HasTag(skill_id)
    print("[DEBUG WagstaffHasSkill] === INICIANDO VERIFICACAO ===")
    print("[DEBUG WagstaffHasSkill] skill_id:", skill_id)
    print("[DEBUG WagstaffHasSkill] worker.prefab:", worker.prefab)
    print("[DEBUG WagstaffHasSkill] worker:HasTag(skill_id):", has_tag)
    
    if has_tag then
        print("[DEBUG WagstaffHasSkill] Tag encontrada! Retornando true IMEDIATAMENTE")
        return true
    end
    
    print("[DEBUG WagstaffHasSkill] worker.components.skilltreeupdater:", worker.components.skilltreeupdater)
    
    if worker.prefab ~= "wagstaff" or not worker.components.skilltreeupdater then
        print("[DEBUG WagstaffHasSkill] Nao e wagstaff ou nao tem skilltreeupdater, retornando false")
        return false
    end
    
    local activated = worker.components.skilltreeupdater.activatedskills
    print("[DEBUG WagstaffHasSkill] activatedskills:", activated)
    print("[DEBUG WagstaffHasSkill] activatedskills[skill_id]:", activated and activated[skill_id])
    
    -- Dump ALL keys in activatedskills to see what's actually there
    local all_skills = ""
    if activated then
        for k, v in GLOBAL.pairs(activated) do
            all_skills = all_skills .. tostring(k) .. "=" .. tostring(v) .. ", "
        end
    end
    print("[DEBUG WagstaffHasSkill] ALL activatedskills keys:", all_skills ~= "" and all_skills or "(empty)")
    
    if activated and activated[skill_id] then
        print("[DEBUG WagstaffHasSkill] Skill esta em activatedskills mas tag faltando, re-aplicando tag...")
        -- Skill is recorded as activated but the tag is missing (common right after a
        -- reload, before apply_world_skills_to_wagstaff re-runs). Re-apply the tag now.
        if G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill_id] and G.WagstaffSkillDefs[skill_id].onactivate then
            print("[DEBUG WagstaffHasSkill] Chamando onactivate da skill")
            G.WagstaffSkillDefs[skill_id].onactivate(worker, true)
        else
            print("[DEBUG WagstaffHasSkill] Adicionando tag manualmente")
            worker:AddTag(skill_id)
        end
        print("[DEBUG WagstaffHasSkill] Tag re-aplicada, retornando true")
        return true
    end
    
    -- CRITICAL FIX: If activatedskills is empty, try to load from world save immediately
    -- This handles the case where skills were saved but not restored to the player
    if not activated or GLOBAL.next(activated) == nil then
        print("[DEBUG WagstaffHasSkill] activatedskills está VAZIO! Tentando carregar do world save...")
        if GLOBAL.TheWorld and GLOBAL.TheWorld.GetWagstaffSkillsFromWorld then
            local world_skills = GLOBAL.TheWorld:GetWagstaffSkillsFromWorld()
            print("[DEBUG WagstaffHasSkill] world_skills do GetWagstaffSkillsFromWorld:", world_skills)
            if world_skills and type(world_skills) == "table" then
                local found_in_world = false
                for k, v in GLOBAL.pairs(world_skills) do
                    print("[DEBUG WagstaffHasSkill]   world_skill:", k, "=", v)
                    if k == skill_id and v then
                        found_in_world = true
                        break
                    end
                end
                if found_in_world then
                    print("[DEBUG WagstaffHasSkill] Skill encontrada no world save! Restaurando para activatedskills...")
                    -- Initialize activatedskills if needed
                    if not worker.components.skilltreeupdater.activatedskills then
                        worker.components.skilltreeupdater.activatedskills = {}
                    end
                    -- Restore the skill
                    worker.components.skilltreeupdater.activatedskills[skill_id] = true
                    -- Apply the tag
                    if G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill_id] and G.WagstaffSkillDefs[skill_id].onactivate then
                        G.WagstaffSkillDefs[skill_id].onactivate(worker, true)
                    else
                        worker:AddTag(skill_id)
                    end
                    print("[DEBUG WagstaffHasSkill] Skill restaurada com sucesso! Retornando true")
                    return true
                end
            end
        end
    end
    
    -- Fallback: consult the per-world saved skills. If the skill is saved in the world
    -- but not yet restored onto this player (transient desync after a reload), restore
    -- it on the fly. This prevents bot/sentry/dispenser Mk2/Mk3 upgrades from being
    -- blocked with "Requires ... skill!" right after loading a save.
    print("[DEBUG WagstaffHasSkill] Verificando world skills...")
    WagstaffDebug("[WagstaffHasSkill] Verificando world skills para:", skill_id)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.GetWagstaffSkillsFromWorld then
        local world_skills = GLOBAL.TheWorld:GetWagstaffSkillsFromWorld()
        print("[DEBUG WagstaffHasSkill] world_skills:", world_skills)
        WagstaffDebug("[WagstaffHasSkill] world_skills type:", type(world_skills))
        if world_skills then
            WagstaffDebug("[WagstaffHasSkill] world_skills keys:")
            for k, v in GLOBAL.pairs(world_skills) do
                WagstaffDebug("  ", k, "=", v)
            end
        end
        if world_skills and world_skills[skill_id] then
            print("[DEBUG WagstaffHasSkill] Skill encontrada no world data, restaurando...")
            WagstaffDebug("[WagstaffHasSkill] Skill", skill_id, "encontrada no world data! Restaurando...")
            if worker.components.skilltreeupdater.activatedskills then
                worker.components.skilltreeupdater.activatedskills[skill_id] = true
            end
            if G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill_id] and G.WagstaffSkillDefs[skill_id].onactivate then
                G.WagstaffSkillDefs[skill_id].onactivate(worker, true)
            else
                worker:AddTag(skill_id)
            end
            print("[DEBUG WagstaffHasSkill] Skill restaurada do world data, retornando true")
            WagstaffDebug("[WagstaffHasSkill] Skill restaurada com sucesso, retornando true")
            return true
        else
            WagstaffDebug("[WagstaffHasSkill] Skill", skill_id, "NAO encontrada no world data")
        end
    else
        print("[DEBUG WagstaffHasSkill] TheWorld ou GetWagstaffSkillsFromWorld nao disponivel")
        WagstaffDebug("[WagstaffHasSkill] TheWorld ou GetWagstaffSkillsFromWorld nao disponivel")
    end
    
    -- Detailed diagnostic: dump all activatedskills keys
    local all_skills = ""
    if worker.components.skilltreeupdater and worker.components.skilltreeupdater.activatedskills then
        for k, v in GLOBAL.pairs(worker.components.skilltreeupdater.activatedskills) do
            all_skills = all_skills .. tostring(k) .. "=" .. tostring(v) .. ", "
        end
    end
    
    print("[DEBUG WagstaffHasSkill] === DIAGNOSTICO COMPLETO ===")
    print("[DEBUG WagstaffHasSkill] Skill procurada:", skill_id, "- NAO ENCONTRADA")
    print("[DEBUG WagstaffHasSkill] worker.prefab=", tostring(worker.prefab))
    print("[DEBUG WagstaffHasSkill] HasTag=", tostring(has_tag))
    print("[DEBUG WagstaffHasSkill] has skilltreeupdater=", tostring(worker.components.skilltreeupdater ~= nil))
    print("[DEBUG WagstaffHasSkill] activatedskills[skill_id]=", tostring(activated and activated[skill_id] or "NIL"))
    print("[DEBUG WagstaffHasSkill] ALL activatedskills: ", all_skills ~= "" and all_skills or "(empty)")
    if GLOBAL.TheWorld and GLOBAL.TheWorld.GetWagstaffSkillsFromWorld then
        local ws = GLOBAL.TheWorld:GetWagstaffSkillsFromWorld()
        local ws_str = ""
        for k, v in GLOBAL.pairs(ws) do ws_str = ws_str .. tostring(k) .. "=" .. tostring(v) .. ", " end
        print("[DEBUG WagstaffHasSkill] world saved skills: ", ws_str ~= "" and ws_str or "(empty)")
    else
        print("[DEBUG WagstaffHasSkill] world saved skills: GetWagstaffSkillsFromWorld NOT AVAILABLE")
    end
    print("[DEBUG WagstaffHasSkill] Retornando false")
    return false
end

-- Helper: wipe XP via raw table write (bypasses all hooks)
local function WipeWagstaffXP()
    if GLOBAL.TheSkillTree then
        if not GLOBAL.TheSkillTree.skillxp then
            GLOBAL.TheSkillTree.skillxp = {}
        end
        GLOBAL.TheSkillTree.skillxp["wagstaff"] = 0
    end
end

-- Helper: force zero XP with multiple approaches to ensure it sticks
-- Helper: safely call DirtySkillXP on a skilltreeupdater (guards against nil method
-- during early component init or on clients where the method isn't replicated yet)
local function SafeDirtySkillXP(updater)
    if updater and updater.DirtySkillXP then
        updater:DirtySkillXP()
    end
end

local function ForceZeroWagstaffXP()
    -- First, try the normal wipe
    WipeWagstaffXP()

    -- Replicate the zero to all clients via DirtySkillXP so the skill tree UI stops
    -- showing stale profile XP (e.g. 68 XP = 15 insights on a brand-new world).
    if GLOBAL.AllPlayers then
        for _, player in ipairs(GLOBAL.AllPlayers) do
            if player.prefab == "wagstaff" and player.components.skilltreeupdater then
                SafeDirtySkillXP(player.components.skilltreeupdater)
            end
        end
    end

    -- Then, set it directly multiple times with delays to ensure it sticks
    if GLOBAL.TheSkillTree and GLOBAL.TheWorld and GLOBAL.TheWorld.DoTaskInTime then
        for i = 1, 3 do
            GLOBAL.TheWorld:DoTaskInTime(i * 0.1, function()
                if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.skillxp then
                    GLOBAL.TheSkillTree.skillxp["wagstaff"] = 0
                end
                -- Re-replicate after each delayed wipe so the client converges on 0.
                if GLOBAL.AllPlayers then
                    for _, player in ipairs(GLOBAL.AllPlayers) do
                        if player.prefab == "wagstaff" and player.components.skilltreeupdater then
                            SafeDirtySkillXP(player.components.skilltreeupdater)
                        end
                    end
                end
            end)
        end
    end
end

-- Helper: inject XP via the normal path so the engine recalculates skill points
local function InjectWagstaffXP(days)
    -- BUG FIX #2: Não injetar XP em shards de cave
    if GLOBAL.TheWorld and GLOBAL.TheWorld:HasTag("cave") then
        return
    end
    
    days = days or 0
    local xp = GetWagstaffSkillXPFromDays(days)
    if not GLOBAL.TheSkillTree then return end
    _wagstaff_xp_injecting = true
    GLOBAL.TheSkillTree.skillxp["wagstaff"] = xp
    _wagstaff_xp_injecting = false
    if GLOBAL.AllPlayers then
        for _, player in ipairs(GLOBAL.AllPlayers) do
            if player.prefab == "wagstaff" and player.components.skilltreeupdater then
                SafeDirtySkillXP(player.components.skilltreeupdater)
            end
        end
    end
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

    if not GLOBAL.TheWorld.ismastersim then return end

    -- Re-apply saved world skills whenever this Wagstaff activates (spawn/join/respawn).
    -- This catches the dedicated-server case where the world loaded before the player
    -- existed, so the DoTaskInTime-based restore in OnLoad found no one to restore,
    -- leaving activatedskills empty and all bot/sentry/dispenser Mk2/Mk3 upgrades
    -- blocked until the next world reload.
    inst:ListenForEvent("playeractivated", function()
        if GLOBAL.TheWorld and GLOBAL.TheWorld.ApplyWagstaffSkills then
            GLOBAL.TheWorld:ApplyWagstaffSkills()
        end
    end)

    -- ==============================================================================
    -- SISTEMA DE SKILL TREE PERSISTENTE POR MUNDO (IMUNE A BUGS DE CAVERNAS)
    -- ==============================================================================
    -- Inicializa a variável de insights do mundo (sempre começa com 0 em novos mundos)
    -- Primeiro, força o XP a ser zerado na engine (múltiplas vezes para garantir que pegue)
    inst:DoTaskInTime(0, ForceZeroWagstaffXP)
    
    -- Depois, inicializa com 0 (padrão para novos mundos)
    inst.wagstaff_world_insights = 0

    -- FIX XP INICIAL: Injeta 0 XP IMEDIATAMENTE no spawn para garantir que o jogador
    -- comece com 0 insights (sem forçar delay). O ForceZeroWagstaffXP acima zera o XP
    -- global, mas o player pode já ter XP do profile cache. Aqui forçamos 0 XP.
    inst:DoTaskInTime(0, function()
        if not inst:IsValid() then return end
        _wagstaff_xp_injecting = true
        if GLOBAL.TheSkillTree then
            GLOBAL.TheSkillTree.skillxp["wagstaff"] = 0
        end
        _wagstaff_xp_injecting = false
        if inst.components.skilltreeupdater then
            SafeDirtySkillXP(inst.components.skilltreeupdater)
        end
        WagstaffDebug("[FIX] XP inicial forçado para 0 no spawn do jogador")
    end)

    if inst.components.skilltreeupdater then
        -- 1. Força o servidor a reconhecer apenas os pontos permitidos por este mundo (do componente world)
        inst.components.skilltreeupdater.GetTotalSkillPoints = function(self)
            return GetWagstaffMaxInsights(GetWagstaffDaysSurvived())
        end

        -- 2. Ajusta o cálculo de pontos disponíveis para gastar
        inst.components.skilltreeupdater.GetAvailableSkillPoints = function(self)
            local total = self:GetTotalSkillPoints()
            local spent = 0
            if self.activatedskills then
                for _ in pairs(self.activatedskills) do
                    spent = spent + 1
                end
            end
            return math.max(0, total - spent)
        end

        -- 3. Intercepta a ativação: salva a habilidade ao mundo
        local old_ActivateSkill = inst.components.skilltreeupdater.ActivateSkill
        inst.components.skilltreeupdater.ActivateSkill = function(self, skill, prefab, fromrpc)
            -- BUG FIX #1: No client, NÃO interceptar — deixar o engine original processar
            -- O cliente usa UI do skilltreebuilder que tem seu próprio caminho para enviar RPC
            -- Se interceptarmos no cliente, quebramos o RPC_LOOKUP e a skill nunca é ativada
            if not GLOBAL.TheWorld.ismastersim then
                WagstaffDebug("[CLIENT] ActivateSkill: bypassing override, calling original")
                return old_ActivateSkill(self, skill, prefab, fromrpc)
            end
            
            -- Server-side only from here on
            WagstaffDebug("=== ActivateSkill START (SERVER) ===")
            WagstaffDebug("ActivateSkill: skill=", tostring(skill), "prefab=", tostring(prefab), "fromrpc=", tostring(fromrpc))
            WagstaffDebug("ActivateSkill: available points=", tostring(self:GetAvailableSkillPoints()), "total=", tostring(self:GetTotalSkillPoints()))
            WagstaffDebug("ActivateSkill: already activated?", tostring(self:IsActivated(skill)))
            
            -- Verbose debug: verifica RPC_LOOKUP detalhadamente
            WagstaffDebug("[VERBOSE] Verificando RPC_LOOKUP para skill:", skill)
            if SkillTreeDefs and SkillTreeDefs.SKILLTREE_DEFS and SkillTreeDefs.SKILLTREE_DEFS["wagstaff"] then
                local defs_meta = SkillTreeDefs.SKILLTREE_DEFS["wagstaff"].meta
                if defs_meta and defs_meta.RPC_LOOKUP then
                    local found_in_defs = defs_meta.RPC_LOOKUP[skill]
                    WagstaffDebug("[VERBOSE]   Em SKILLTREE_DEFS.wagstaff.meta.RPC_LOOKUP:", found_in_defs ~= nil and "ENCONTRADA (ID="..tostring(found_in_defs)..")" or "NAO ENCONTRADA")
                end
            end
            if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.RPC_LOOKUP then
                local found_in_global = GLOBAL.TheSkillTree.RPC_LOOKUP[skill]
                WagstaffDebug("[VERBOSE]   Em TheSkillTree.RPC_LOOKUP:", found_in_global ~= nil and "ENCONTRADA (ID="..tostring(found_in_global)..")" or "NAO ENCONTRADA")
            end
            
            -- Debug RPC_LOOKUP antes de ativar
            if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.RPC_LOOKUP then
                local rpc_id = GLOBAL.TheSkillTree.RPC_LOOKUP[skill]
                WagstaffDebug("RPC_LOOKUP[", skill, "] =", rpc_id ~= nil and tostring(rpc_id) or "NIL (PROBLEMA!)")
                if rpc_id == nil then
                    WagstaffDebug("ERROR: Skill '", skill, "' nao esta no RPC_LOOKUP! Skills disponiveis:")
                    local count = 0
                    for k, v in pairs(GLOBAL.TheSkillTree.RPC_LOOKUP) do
                        count = count + 1
                        if count <= 10 then
                            WagstaffDebug("  ", k, "=", v)
                        end
                    end
                    if count > 10 then
                        WagstaffDebug("  ... e mais ", count - 10, " skills")
                    end
                end
            else
                WagstaffDebug("WARNING: TheSkillTree.RPC_LOOKUP is NIL!")
            end
            
            if self:GetAvailableSkillPoints() <= 0 and not self:IsActivated(skill) then
                WagstaffDebug("ActivateSkill BLOCKED: no available insight points")
                return false
            end
            
            -- CORRECAO CRITICA: Quando fromrpc=true, o jogo espera um ID numerico, nao um nome.
            -- Em mundo com caves, GLOBAL.TheSkillTree.RPC_LOOKUP pode ainda nao existir;
            -- por isso resolvemos tambem pelo SKILLTREE_METAINFO.wagstaff.RPC_LOOKUP.
            WagstaffPublishRPCLookup()
            local skill_to_pass = skill
            if fromrpc and type(skill) == "string" then
                local rpc_id = WagstaffResolveSkillRPCID(skill)
                if rpc_id ~= nil then
                    WagstaffDebug("CORRECAO: Convertendo skill string '", skill, "' para ID RPC:", rpc_id)
                    skill_to_pass = rpc_id
                else
                    WagstaffDebug("ERRO: Skill '", skill, "' nao encontrada em nenhum RPC_LOOKUP; abortando ativacao")
                    return false
                end
            end
            
            local result = old_ActivateSkill(self, skill_to_pass, prefab, fromrpc)
            WagstaffDebug("ActivateSkill: old_ActivateSkill returned:", tostring(result))
            if result then
                WagstaffDebug("ActivateSkill: skill activated successfully!")
                WagstaffDebug("ActivateSkill: self.activatedskills now contains:", skill, "?", self.activatedskills and self.activatedskills[skill] or "NOT FOUND")
                -- Apply onactivate callback (adds tag)
                if G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill] and G.WagstaffSkillDefs[skill].onactivate then
                    WagstaffDebug("ActivateSkill: calling onactivate for", skill)
                    G.WagstaffSkillDefs[skill].onactivate(inst, false)
                    WagstaffDebug("ActivateSkill: tag now present?", tostring(inst:HasTag(skill)))
                else
                    WagstaffDebug("ActivateSkill: no onactivate defined, adding tag directly")
                    inst:AddTag(skill)
                end
                -- Save to world
                if GLOBAL.TheWorld and GLOBAL.TheWorld.SaveWagstaffSkillsToWorld then
                    WagstaffDebug("ActivateSkill: saving to world")
                    GLOBAL.TheWorld:SaveWagstaffSkillsToWorld(self.activatedskills)
                else
                    WagstaffDebug("ActivateSkill: WARNING - SaveWagstaffSkillsToWorld not available on TheWorld!")
                end
                -- Log current activatedskills
                local count = 0
                if self.activatedskills then
                    for k, v in pairs(self.activatedskills) do count = count + 1 end
                end
                WagstaffDebug("ActivateSkill: total activated skills now =", count)
            else
                WagstaffDebug("ActivateSkill: FAILED - old_ActivateSkill returned false")
            end
            WagstaffDebug("=== ActivateSkill END ===")
            return result
        end

        -- 4. Intercepta a desativação: salva ao mundo também
        local old_DeactivateSkill = inst.components.skilltreeupdater.DeactivateSkill
        if old_DeactivateSkill then
            inst.components.skilltreeupdater.DeactivateSkill = function(self, skill, prefab, fromrpc)
                WagstaffDebug("DeactivateSkill called with skill:", skill)
                local result = old_DeactivateSkill(self, skill, prefab, fromrpc)
                WagstaffDebug("old_DeactivateSkill returned result:", result)
                if result and G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill] and G.WagstaffSkillDefs[skill].ondeactivate then
                    G.WagstaffSkillDefs[skill].ondeactivate(inst, false)
                end
                if result and GLOBAL.TheWorld and GLOBAL.TheWorld.SaveWagstaffSkillsToWorld then
                    WagstaffDebug("Calling GLOBAL.TheWorld:SaveWagstaffSkillsToWorld")
                    GLOBAL.TheWorld:SaveWagstaffSkillsToWorld(self.activatedskills)
                end
                return result
            end
        end

        -- BUG FIX #5: IsActivated no cliente deve ser simples — apenas verificar se está em activatedskills
        -- No servidor, usa a lógica com limite de pontos do mundo
        inst.components.skilltreeupdater.IsActivated = function(self, skill, ...)
            -- No cliente: confiar no estado replicado pelo engine
            if not GLOBAL.TheWorld.ismastersim then
                return self.activatedskills and self.activatedskills[skill] == true
            end
            
            -- No servidor: lógica com limite de pontos do mundo
            if not (self.activatedskills and self.activatedskills[skill]) then
                return false
            end
            local sorted_skills = SortedActivatedSkillKeys(self.activatedskills)
            local index = 0
            for i, s in ipairs(sorted_skills) do
                if s == skill then
                    index = i
                    break
                end
            end
            local total = self:GetTotalSkillPoints()
            -- NOTE: IsActivated is called many times per second by the skill tree UI.
            -- Do NOT WagstaffDebug here — it would flood the buffer and freeze the game.
            return index > 0 and index <= total
        end
    end

    -- 4. Progressão Automática: Ganha +1 ponto a cada dia que passa (Ex: Dia 1 = 0, Dia 2 = 1...)
    -- A progressão é limitada por dias, não por pontos diretos
    inst:WatchWorldState("cycles", function(inst, cycles)
        -- BUG FIX #2: Não rodar lógica de insights em shards de cave
        if GLOBAL.TheWorld and GLOBAL.TheWorld:HasTag("cave") then
            return
        end
        
        -- Calcula o XP baseado nos dias sobrevividos (máximo 68 = 15 insights)
        -- Dia 1 = 0, Dia 3 = 1, Dia 6 = 2, etc., até Dia 68 = 15
        local days = (GLOBAL.TheWorld and GLOBAL.TheWorld.state and GLOBAL.TheWorld.state.cycles) or 0
        local new_insights = 0
        
        -- Limites para cada insight (baseado em TUNING.SKILL_THRESHOLDS)
        local thresholds = TUNING.SKILL_THRESHOLDS.wagstaff or {3,6,10,14,18,23,28,33,38,43,48,53,58,63,68}
        
        -- Calcula quantos insights o jogador deveria ter
        for i, threshold in ipairs(thresholds) do
            if days >= threshold then
                new_insights = i
            else
                break -- Não precisa verificar mais thresholds
            end
        end
        
        -- Atualiza apenas se o valor mudou
        if new_insights > inst.wagstaff_world_insights then
            inst.wagstaff_world_insights = new_insights
            if inst.components.talker then
                inst.components.talker:Say("Minhas pesquisas avançaram! Agora tenho " .. new_insights .. " Insights neste mundo.")
            end
            -- Inject XP to match days
            inst:DoTaskInTime(0, function()
                InjectWagstaffXP(days)
            end)
        end
    end)

    if inst.components.petleash == nil then
        inst:AddComponent("petleash")
        inst.components.petleash:SetMaxPets(4)
    else
        inst.components.petleash:SetMaxPets(math.max(inst.components.petleash:GetMaxPets(), 4))
    end


    -- Give starting items (tf2wrench + goggles + williambutler_builder)
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

        -- Add starting items in specific slots
        local wrench = G.SpawnPrefab("tf2wrench")
        if wrench then
            inv:GiveItem(wrench, 1)
        end

        local goggles = G.SpawnPrefab("gogglesnormalhat")
        if goggles then
            inv:GiveItem(goggles, 2)
        end

        local bot = G.SpawnPrefab("williambutler_builder")
        if bot then
            inv:GiveItem(bot)
        end
    end)

    -- Modificação para salvar os dados do Wagstaff (apenas flags de início, não progresso)
    local old_OnSave = inst.OnSave
    inst.OnSave = function(inst, data)
        WagstaffDebug("Player OnSave called")
        if old_OnSave then
            data = old_OnSave(inst, data) or data
        end
        data = data or {}
        data.wagstaff_received_starting_items = inst.wagstaff_received_starting_items
        WagstaffDebug("Player OnSave done")
        return data
    end
    
    local old_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
        WagstaffDebug("Player OnLoad called")
        if old_OnLoad then
            old_OnLoad(inst, data)
        end
        
        -- Primeiro, força o XP a ser zerado na engine (múltiplas vezes para garantir que pegue)
        WagstaffDebug("Scheduling ForceZeroWagstaffXP in 0 seconds")
        inst:DoTaskInTime(0, ForceZeroWagstaffXP)
        
        if data then
            if data.wagstaff_received_starting_items then
                inst.wagstaff_received_starting_items = true
                WagstaffDebug("Set wagstaff_received_starting_items to true")
            end
        end

        -- Aplicar habilidades salvas no mundo, depois que o mundo estiver carregado
        WagstaffDebug("Scheduling ApplyWagstaffSkills in 0.6 seconds")
        inst:DoTaskInTime(0.6, function()
            WagstaffDebug("ApplyWagstaffSkills DoTaskInTime callback executing")
            if GLOBAL.TheWorld and GLOBAL.TheWorld.ApplyWagstaffSkills then
                WagstaffDebug("Calling GLOBAL.TheWorld:ApplyWagstaffSkills")
                GLOBAL.TheWorld:ApplyWagstaffSkills()
                -- Also set inst.wagstaff_world_insights correctly
                if inst.components.skilltreeupdater then
                    inst.wagstaff_world_insights = inst.components.skilltreeupdater:GetTotalSkillPoints()
                    WagstaffDebug("Set inst.wagstaff_world_insights to:", inst.wagstaff_world_insights)
                end
            else
                WagstaffDebug("WARNING: GLOBAL.TheWorld or GLOBAL.TheWorld.ApplyWagstaffSkills not found!")
            end
        end)
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

    if inst:HasTag("ebuild_wrenchable") and doer.replica.inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS) ~= nil and doer.replica.inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS).prefab == "tf2wrench" then

        table.insert(actions, G.ACTIONS.ENGIEWORKABLE)

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

SetName("williambutler2", "Butler Bot Mk.II")

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


-- Store the skill definitions for later use
G.WagstaffSkillDefs = nil

local CreateSkillTree = function()
    WagstaffDebug("CreateSkillTree called")

    -- Creating skill tree for wagstaff
    local BuildSkillsData = require("prefabs/skilltree_wagstaff")
    WagstaffDebug("BuildSkillsData loaded:", BuildSkillsData ~= nil)

    
    if BuildSkillsData then
        local data = BuildSkillsData(SkillTreeDefs.FN)
        WagstaffDebug("BuildSkillsData returned data:", data ~= nil)

        

        if data then
            -- Save skill definitions for later use
            local skillCount = 0
            for _ in pairs(data.SKILLS) do
                skillCount = skillCount + 1
            end
            WagstaffDebug("Saving skill definitions to G.WagstaffSkillDefs, #skills:", skillCount)
            G.WagstaffSkillDefs = data.SKILLS

            -- CLEAN ALL OLD SKILL TREE DATA FIRST
            if SkillTreeDefs.SKILLS and SkillTreeDefs.SKILLS.wagstaff then
                SkillTreeDefs.SKILLS.wagstaff = nil
                WagstaffDebug("Cleared old SkillTreeDefs.SKILLS.wagstaff")
            end
            if SkillTreeDefs.SKILLTREE_ORDERS and SkillTreeDefs.SKILLTREE_ORDERS["wagstaff"] then
                SkillTreeDefs.SKILLTREE_ORDERS["wagstaff"] = nil
                WagstaffDebug("Cleared old SkillTreeDefs.SKILLTREE_ORDERS.wagstaff")
            end
            if SkillTreeDefs.SKILLTREE_METAINFO and SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] then
                SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] = nil
                WagstaffDebug("Cleared old SkillTreeDefs.SKILLTREE_METAINFO.wagstaff")
            end
            
            -- Register skills in SkillTreeDefs so the engine recognizes them
            -- (engine checks SkillTreeDefs.SKILLS[charname] when validating RPCs)
            if SkillTreeDefs.SKILLS == nil then
                SkillTreeDefs.SKILLS = {}
            end
            if type(SkillTreeDefs.CreateSkillTreeFor) == "function" then
                WagstaffDebug("=== INICIANDO CreateSkillTreeFor ===")
                WagstaffDebug("SkillTreeDefs antes:", type(SkillTreeDefs))
                WagstaffDebug("SKILLS antes:", type(SkillTreeDefs.SKILLS))
                local has_skills = false
                if data.SKILLS ~= nil then
                    for _ in pairs(data.SKILLS) do
                        has_skills = true
                        break
                    end
                end
                WagstaffDebug("data.SKILLS count:", has_skills and "tem items" or "vazio")
                
                WagstaffDebug("[VERBOSE] Lista completa de skills sendo registradas:")
                local skill_count = 0
                for skill_id, skill_data in pairs(data.SKILLS) do
                    WagstaffDebug("[VERBOSE]   Skill ID:", skill_id, "- Nome:", skill_data.name or "sem_nome")
                    skill_count = skill_count + 1
                end
                WagstaffDebug("[VERBOSE] Total de skills:", skill_count)
                
                -- Registrar a skill tree ANTES de criar o RPC_LOOKUP
                WagstaffDebug("[VERBOSE] Criando skill tree para wagstaff...")
                local ok, err = GLOBAL.pcall(SkillTreeDefs.CreateSkillTreeFor, "wagstaff", data.SKILLS)
                if not ok then
                    WagstaffDebug("CreateSkillTreeFor FAILED:", tostring(err))
                else
                    WagstaffDebug("CreateSkillTreeFor succeeded")
                end
                
                -- DEBUG AGRESSIVO: Verificar se RPC_LOOKUP foi criado corretamente
                WagstaffDebug("=== VERIFICACAO DO RPC_LOOKUP ===")
                local rpc_lookup_to_use = nil
                if SkillTreeDefs and SkillTreeDefs.RPC_LOOKUP then
                    rpc_lookup_to_use = SkillTreeDefs.RPC_LOOKUP
                    WagstaffDebug("RPC_LOOKUP existe em SkillTreeDefs!")
                elseif GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.RPC_LOOKUP then
                    rpc_lookup_to_use = GLOBAL.TheSkillTree.RPC_LOOKUP
                    WagstaffDebug("RPC_LOOKUP existe em GLOBAL.TheSkillTree!")
                else
                    WagstaffDebug("RPC_LOOKUP NAO EXISTE EM LUGAR NENHUM!")
                end
                
                if rpc_lookup_to_use then
                    local rpc_count = 0
                    for k, v in pairs(rpc_lookup_to_use) do
                        rpc_count = rpc_count + 1
                        if rpc_count <= 20 then
                            WagstaffDebug("  RPC_LOOKUP[", k, "] =", v)
                        end
                    end
                    WagstaffDebug("Total entries in RPC_LOOKUP:", rpc_count)
                    
                    -- Verificar especificamente as skills dos bots
                    WagstaffDebug("=== VERIFICANDO SKILLS DOS BOTS NO RPC_LOOKUP ===")
                    local bot_skills = {"wagstaff_brute_evolve", "wagstaff_buster_evolve", "wagstaff_ballistic_evolve", "wagstaff_butler_evolve", "wagstaff_brute_mk3", "wagstaff_buster_mk3", "wagstaff_ballistic_mk3", "wagstaff_butler_mk3"}
                    for _, skill_name in ipairs(bot_skills) do
                        local found = false
                        for k, v in pairs(rpc_lookup_to_use) do
                            if v == skill_name then
                                WagstaffDebug("  [OK]", skill_name, "-> ID:", k)
                                found = true
                                break
                            end
                        end
                        if not found then
                            WagstaffDebug("  [ERRO]", skill_name, "NAO ENCONTRADO NO RPC_LOOKUP!")
                        end
                    end
                end
                
                WagstaffDebug("=== POS CreateSkillTreeFor ===")
                WagstaffDebug("SKILLS depois:", type(SkillTreeDefs.SKILLS), "wagstaff exists?", SkillTreeDefs.SKILLS and SkillTreeDefs.SKILLS["wagstaff"] ~= nil)
                
                -- DEBUG AGRESSIVO: Verificar TODAS as estruturas do SkillTreeDefs
                WagstaffDebug("=== VERIFICACAO COMPLETA DO SKILLTREEDEFS ===")
                WagstaffDebug("SkillTreeDefs keys:", dump_table_keys(SkillTreeDefs))
                
                -- Verificar se TheSkillTree.RPC_LOOKUP foi criado
                if GLOBAL.TheSkillTree then
                    WagstaffDebug("GLOBAL.TheSkillTree EXISTS")
                    if GLOBAL.TheSkillTree.RPC_LOOKUP then
                        local rpc_count = 0
                        for k, v in pairs(GLOBAL.TheSkillTree.RPC_LOOKUP) do 
                            rpc_count = rpc_count + 1
                            if rpc_count <= 20 then
                                WagstaffDebug("TheSkillTree.RPC_LOOKUP[\"" .. tostring(k) .. "\"] = " .. tostring(v))
                            end
                        end
                        WagstaffDebug("TheSkillTree.RPC_LOOKUP TOTAL COUNT: " .. rpc_count)
                        
                        -- Verbose: procura especificamente pelas skills dos bots
                        WagstaffDebug("[VERBOSE] Procurando skills dos bots no RPC_LOOKUP global:")
                        local bot_skills = {"wagstaff_brute_evolve", "wagstaff_buster_evolve", "wagstaff_ballistic_evolve", "wagstaff_butler_evolve", "wagstaff_brute_mk3", "wagstaff_buster_mk3", "wagstaff_ballistic_mk3", "wagstaff_butler_mk3"}
                        for _, skill_name in ipairs(bot_skills) do
                            if GLOBAL.TheSkillTree.RPC_LOOKUP[skill_name] then
                                WagstaffDebug("[VERBOSE]   ENCONTRADA:", skill_name, "-> ID:", GLOBAL.TheSkillTree.RPC_LOOKUP[skill_name])
                            else
                                WagstaffDebug("[VERBOSE]   NAO ENCONTRADA:", skill_name)
                            end
                        end
                    else
                        WagstaffDebug("ERROR: TheSkillTree.RPC_LOOKUP is NIL!")
                    end
                else
                    WagstaffDebug("ERROR: GLOBAL.TheSkillTree is NIL!")
                end
                
                -- Verify RPC_LOOKUP was created
                local meta = SkillTreeDefs.SKILLTREE_METAINFO and SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"]
                WagstaffDebug("SKILLTREE_METAINFO.wagstaff:", type(meta))
                if meta then
                    local rpc_count = 0
                    if meta.RPC_LOOKUP then
                        for k, v in pairs(meta.RPC_LOOKUP) do 
                            rpc_count = rpc_count + 1
                            if rpc_count <= 5 then
                                WagstaffDebug("  RPC_LOOKUP[", k, "] =", v)
                            end
                        end
                    end
                    WagstaffDebug("SKILLTREE_METAINFO.wagstaff EXISTS, RPC_LOOKUP count:", rpc_count, "TOTAL_SKILLS_COUNT:", tostring(meta.TOTAL_SKILLS_COUNT))
                    
                    -- Verbose: lista todo o RPC_LOOKUP do meta
                    WagstaffDebug("[VERBOSE] RPC_LOOKUP completo do meta wagstaff:")
                    if meta.RPC_LOOKUP then
                        for k, v in pairs(meta.RPC_LOOKUP) do
                            WagstaffDebug("[VERBOSE]   ", k, "->", v)
                        end
                    else
                        WagstaffDebug("[VERBOSE]   meta.RPC_LOOKUP é NIL!")
                    end
                    
                    -- Check SKILLTREE_DEFS (engine usa isso!)
                    if SkillTreeDefs and SkillTreeDefs.SKILLTREE_DEFS then
                        WagstaffDebug("SkillTreeDefs.SKILLTREE_DEFS existe!")
                        if SkillTreeDefs.SKILLTREE_DEFS["wagstaff"] then
                            WagstaffDebug("SkillTreeDefs.SKILLTREE_DEFS.wagstaff existe!")
                            local defs_meta = SkillTreeDefs.SKILLTREE_DEFS["wagstaff"].meta
                            if defs_meta and defs_meta.RPC_LOOKUP then
                                local defs_rpc_count = 0
                                for _ in pairs(defs_meta.RPC_LOOKUP) do defs_rpc_count = defs_rpc_count + 1 end
                                WagstaffDebug("SkillTreeDefs.SKILLTREE_DEFS.wagstaff.meta.RPC_LOOKUP count:", defs_rpc_count)
                                
                                -- Verbose: verifica skills dos bots no SKILLTREE_DEFS
                                WagstaffDebug("[VERBOSE] Verificando skills dos bots em SKILLTREE_DEFS.wagstaff.meta.RPC_LOOKUP:")
                                local bot_skills = {"wagstaff_brute_evolve", "wagstaff_buster_evolve", "wagstaff_ballistic_evolve", "wagstaff_butler_evolve", "wagstaff_brute_mk3", "wagstaff_buster_mk3", "wagstaff_ballistic_mk3", "wagstaff_butler_mk3"}
                                for _, skill_name in ipairs(bot_skills) do
                                    if defs_meta.RPC_LOOKUP[skill_name] then
                                        WagstaffDebug("[VERBOSE]   ENCONTRADA em DEFS:", skill_name, "-> ID:", defs_meta.RPC_LOOKUP[skill_name])
                                    else
                                        WagstaffDebug("[VERBOSE]   NAO ENCONTRADA em DEFS:", skill_name)
                                    end
                                end
                            end
                        else
                            WagstaffDebug("ERROR: SkillTreeDefs.SKILLTREE_DEFS.wagstaff NAO EXISTE!")
                        end
                    else
                        WagstaffDebug("ERROR: SkillTreeDefs.SKILLTREE_DEFS global NAO EXISTE!")
                    end
                else
                    WagstaffDebug("WARNING: SKILLTREE_METAINFO.wagstaff is NIL after CreateSkillTreeFor!")
                end
            elseif type(SkillTreeDefs.FN) == "function" then
                print("[WAGSTAFF DEBUG] Using SkillTreeDefs.FN")
                SkillTreeDefs.FN("wagstaff", data.SKILLS)
            end
            -- NOTE: Do NOT set SkillTreeDefs.SKILLS["wagstaff"] here.
            -- The engine uses SKILLTREE_DEFS (populated by CreateSkillTreeFor),
            -- not SKILLS. Setting SKILLS is a no-op for RPC validation.
            print("[WAGSTAFF DEBUG] Skill tree registered with " .. skillCount .. " skills for wagstaff")

            SkillTreeDefs.SKILLTREE_ORDERS["wagstaff"] = data.ORDERS
            print("[WAGSTAFF DEBUG] Set SkillTreeDefs.SKILLTREE_ORDERS.wagstaff")
            
            -- Merge BACKGROUND_SETTINGS into existing METAINFO - don't overwrite
            -- CreateSkillTreeFor already set RPC_LOOKUP, TOTAL_SKILLS_COUNT etc.
            -- Overwriting the whole table would destroy RPC_LOOKUP and break skill activation.
            if SkillTreeDefs.SKILLTREE_METAINFO == nil then
                SkillTreeDefs.SKILLTREE_METAINFO = {}
            end
            if SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] == nil then
                SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] = {}
            end
            SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"].BACKGROUND_SETTINGS = data.BACKGROUND_SETTINGS

            -- FIX RPC_LOOKUP FORMAT: Engine creates {rpc_id -> skill_name} but DST expects
            -- {skill_name -> rpc_id}. We must invert it after CreateSkillTreeFor.
            if SkillTreeDefs.SKILLTREE_METAINFO and SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"] then
                local meta = SkillTreeDefs.SKILLTREE_METAINFO["wagstaff"]
                if meta.RPC_LOOKUP then
                    -- Invert: {id -> name} becomes {name -> id}
                    local inverted = {}
                    for rpc_id, skill_name in pairs(meta.RPC_LOOKUP) do
                        if type(rpc_id) == "number" and type(skill_name) == "string" then
                            inverted[skill_name] = rpc_id
                        end
                    end
                    meta.RPC_LOOKUP = inverted
                    WagstaffDebug("[FIX] RPC_LOOKUP invertido: {id->name} para {name->id}, count:", count_table(inverted))
                end
            end
            
            -- Also fix SKILLTREE_DEFS if it exists
            if SkillTreeDefs.SKILLTREE_DEFS and SkillTreeDefs.SKILLTREE_DEFS["wagstaff"] then
                local defs_meta = SkillTreeDefs.SKILLTREE_DEFS["wagstaff"].meta
                if defs_meta and defs_meta.RPC_LOOKUP then
                    local inverted2 = {}
                    for rpc_id, skill_name in pairs(defs_meta.RPC_LOOKUP) do
                        if type(rpc_id) == "number" and type(skill_name) == "string" then
                            inverted2[skill_name] = rpc_id
                        end
                    end
                    defs_meta.RPC_LOOKUP = inverted2
                    WagstaffDebug("[FIX] SKILLTREE_DEFS RPC_LOOKUP invertido tambem")
                end
            end

            -- Publica o RPC_LOOKUP quando possivel. Em mundos com caves, TheSkillTree
            -- costuma ficar nil neste ponto e aparecer alguns frames depois.
            WagstaffScheduleRPCPublish()

            -- Created wagstaff skill tree
            WagstaffDebug("Successfully created wagstaff skill tree")
        end
    end
end


CreateSkillTree()

--==================================================================================
-- CAMADA A: RPC_LOOKUP cross-shard — republish quando shard conecta ao cluster.
-- Em mundos com caves, o shard de cave carrega TheSkillTree e RPC_LOOKUP
-- MUITO depois do PostInit inicial, quando o link Master↔Cave já está estabelecido.
-- Este hook intercepta SetSharedSaveData no network object; Toda vez que o
-- Master propaga dados para o cluster, o cave também republica o RPC_LOOKUP.
--==================================================================================
AddSimPostInit(function()
    if GLOBAL.TheWorld and GLOBAL.TheWorld.network and GLOBAL.TheWorld.network.SetSharedSaveData then
        local orig_SetSharedSaveData = GLOBAL.TheWorld.network.SetSharedSaveData
        GLOBAL.TheWorld.network.SetSharedSaveData = function(net, data)
            if orig_SetSharedSaveData then
                orig_SetSharedSaveData(net, data)
            end
            -- Master acabou de propagar cluster save: republicar RPC_LOOKUP
            -- no próximo frame para garantir que TheSkillTree existe
            if GLOBAL.TheWorld and GLOBAL.TheWorld.DoTaskInTime then
                GLOBAL.TheWorld:DoTaskInTime(0, function()
                    WagstaffScheduleRPCPublish()
                    WagstaffDebug("[CAMADA A] Re-published RPC_LOOKUP after cluster sync")
                end)
            end
        end
        WagstaffDebug("[CAMADA A] Hooked SetSharedSaveData for cross-shard RPC sync")
    end
    -- Post-load safety: republicar RPC_LOOKUP após 1s (catch shards tardios)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.DoTaskInTime then
        GLOBAL.TheWorld:DoTaskInTime(1.0, function()
            WagstaffScheduleRPCPublish()
        end)
    end
end)

--==================================================================================
-- FIX: RPC_LOOKUP nil guard for skill tree crashes
--==================================================================================
AddSimPostInit(function()
    -- Tenta preencher RPC_LOOKUP com a tabela real de Wagstaff antes de criar
    -- qualquer fallback vazio. Criar {} cedo demais mascara o lookup valido.
    WagstaffScheduleRPCPublish()
    if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.RPC_LOOKUP == nil then
        GLOBAL.TheSkillTree.RPC_LOOKUP = {}
    end
    
    -- Wrap GetSkillNameFromID with error handling to prevent crashes
    if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.GetSkillNameFromID then
        local _orig_GetSkillNameFromID = GLOBAL.TheSkillTree.GetSkillNameFromID
        GLOBAL.TheSkillTree.GetSkillNameFromID = function(self, rpc_id)
            if self.RPC_LOOKUP == nil then
                self.RPC_LOOKUP = {}
            end
            local ok, result = GLOBAL.pcall(_orig_GetSkillNameFromID, self, rpc_id)
            if ok then
                return result
            end
            return nil
        end
    end
end)


-- ==================================================================================
-- INSIGHT (XP) PROGRESSION SYSTEM FOR WAGSTAFF
-- ==================================================================================
-- Design: XP is per-world, based entirely on days survived.
--   - New world always starts at 0 XP.
--   - On save: number of days survived is stored in the world save file.
--   - On load: XP is ALWAYS reset to 0 first (to block mod/engine injection),
--     then re-injected as (days_survived * 1 XP) capped at 68.
--   - Cave: treated as a separate world with XP = 0 (no cave logic yet).
--   - The engine/original mod may inject 68 XP silently; we neutralize this by
--     always overwriting via AddSkillXP after load, not just setting skillxp directly.
--
-- Thresholds: {3,6,10,14,18,23,28,33,38,43,48,53,58,63,68} (15 points max)
-- Day 1 starts at 0. After day 3 = 1st insight. After day 68 = 15th (max).
-- ==================================================================================

if TUNING.SKILL_THRESHOLDS == nil then
    TUNING.SKILL_THRESHOLDS = {}
end
TUNING.SKILL_THRESHOLDS.wagstaff = {3,6,10,14,18,23,28,33,38,43,48,53,58,63,68}

-- Per-world persistence: boss kills + days_survived + activated skills (XP source of truth)
-- NOTE: "world" is a PREFAB (TheWorld), not a component. Must use AddPrefabPostInit
-- (AddComponentPostInit("world") never fires because there's no component named "world").
WagstaffDebug("Registering AddPrefabPostInit('world')")
AddPrefabPostInit("world", function(self)
    print("[Wagstaff Standalone] AddPrefabPostInit('world') FIRED — self=", tostring(self))
    WagstaffDebug("AddPrefabPostInit('world') called, self=", tostring(self))
    WagstaffDebug("TheWorld.state exists?", tostring(self.state ~= nil))
    WagstaffDebug("TheWorld.ismastersim=", tostring(self.ismastersim))
    -- Initialize worldstate boss flags
    if self.state.wagstaff_fuelweaver_killed == nil then
        self.state.wagstaff_fuelweaver_killed = false
    end
    if self.state.wagstaff_celestial_killed == nil then
        self.state.wagstaff_celestial_killed = false
    end
    -- Internal: days survived saved in this world (nil = new world)
    self._wagstaff_days_survived = nil
    self._wagstaff_activated_skills = {} -- Store activated skills per world

    -- Camada C: Persistência cluster-wide via shared save data.
    -- Em clusters (Master + Caves), cada shard tem seu próprio world save.
    -- Usamos GetSharedSaveData/SetSharedSaveData para compartilhar o estado
    -- autoritativo (dias + skills) entre todos os shards.
    -- NOTA: GetSharedSaveData retorna uma VIEW SOMENTE-LEITURA do cluster save.
    -- O engine aceita que mods retornem tabelas customizadas de lá; não chamamos
    -- SetSharedSaveData diretamente (API não existe publicamente).
    local function WagstaffGetClusterSaveData()
        if self.network and self.network.GetSharedSaveData then
            local shared = self.network:GetSharedSaveData()
            if shared and type(shared) == "table" then
                return shared
            end
        end
        return nil
    end

    -- Function to apply world skills to all Wagstaff players
    local function apply_world_skills_to_wagstaff()
        local _sk_count = 0; for _ in pairs(self._wagstaff_activated_skills) do _sk_count = _sk_count + 1 end; WagstaffDebug("apply_world_skills_to_wagstaff called, skills count:", _sk_count)
        WagstaffDebug("self._wagstaff_days_survived:", self._wagstaff_days_survived)
        if not GLOBAL.AllPlayers then
            WagstaffDebug("GLOBAL.AllPlayers is nil, returning")
            return
        end

        local days = self._wagstaff_days_survived or 0
        local max_insights = GetWagstaffMaxInsights(days)
        local sorted_saved = SortedActivatedSkillKeys(self._wagstaff_activated_skills)
        WagstaffDebug("max_insights:", max_insights, "sorted_saved count:", #sorted_saved)

        -- Camada B (autoritativo): Usar o maior valor entre os insights calculados
        -- localmente e o número de skills salvas. Isso NUNCA poda skills que existem
        -- no save. O motivo: o shard de cave pode ter max_insights=0 (day 0 local)
        -- enquanto o Master tem skills salvas de dias > 0. O #sorted_saved é a fonte
        -- de verdade autoritativa para "quantas skills existem".
        local effective_max = math.max(max_insights, #sorted_saved)
        if effective_max ~= max_insights then
            WagstaffDebug("[CLUSTER B] max_insights expandido de", max_insights, "para", effective_max, "(#sorted_saved=", #sorted_saved, ")")
        end

        local keep_set = {}
        for i = 1, math.min(#sorted_saved, effective_max) do
            keep_set[sorted_saved[i]] = true
        end

        for _, player in ipairs(GLOBAL.AllPlayers) do
            WagstaffDebug("Checking player:", player.prefab)
            if player.prefab == "wagstaff" and player.components.skilltreeupdater then
                WagstaffDebug("Found Wagstaff player")
                local updater = player.components.skilltreeupdater
                
                -- CRITICAL FIX: Ensure activatedskills table exists before using it
                if not updater.activatedskills then
                    updater.activatedskills = {}
                    WagstaffDebug("Created empty activatedskills table for player")
                end
                
                local oldActivatedSkills = updater.activatedskills or {}
                local _oc = 0; for _ in pairs(oldActivatedSkills or {}) do _oc = _oc + 1 end; WagstaffDebug("Old activated skills count:", _oc)

                for skill, _ in pairs(oldActivatedSkills) do
                    if not keep_set[skill] then
                        WagstaffDebug("Deactivating skill:", skill)
                        if G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill] and G.WagstaffSkillDefs[skill].ondeactivate then
                            G.WagstaffSkillDefs[skill].ondeactivate(player, true)
                        end
                    end
                end

                -- Clear and rebuild activatedskills (usa effective_max da Camada B)
                updater.activatedskills = {}
                local applied_count = 0
                for i = 1, math.min(#sorted_saved, effective_max) do
                    local skill = sorted_saved[i]
                    WagstaffDebug("Activating skill:", skill)
                    updater.activatedskills[skill] = true
                    applied_count = applied_count + 1
                    if G.WagstaffSkillDefs and G.WagstaffSkillDefs[skill] and G.WagstaffSkillDefs[skill].onactivate then
                        G.WagstaffSkillDefs[skill].onactivate(player, true)
                    end
                end
                WagstaffDebug("Final activated skills count:", applied_count)
                
                -- CRITICAL: Force dirty the skills to ensure they're replicated
                SafeDirtySkillXP(updater)
                player.wagstaff_world_insights = effective_max
                
                -- EXTRA DEBUG: Verify skills were actually set
                local verify_count = 0
                for _ in pairs(updater.activatedskills) do verify_count = verify_count + 1 end
                WagstaffDebug("VERIFICATION: activatedskills now has", verify_count, "skills")
            elseif player.prefab == "wagstaff" then
                WagstaffDebug("Player is wagstaff but MISSING skilltreeupdater component!")
            end
        end
    end

    -- SAVE: store boss flags + days survived + activated skills
    -- BUG FIX #4: OnSave deve sempre copiar skills do player vivo antes de salvar
    -- Isso previne perda de skills em reloads/rollbacks
    local old_OnSave = self.OnSave
    self.OnSave = function(self, ...)
        WagstaffDebug("=== World OnSave START ===")
        WagstaffDebug("World OnSave called")
        local data = old_OnSave and old_OnSave(self, ...) or {}
        data.wagstaff_fuelweaver_killed = self.state.wagstaff_fuelweaver_killed
        data.wagstaff_celestial_killed  = self.state.wagstaff_celestial_killed
        -- Save days survived so we can reconstruct XP on load
        local days = (GLOBAL.TheWorld and GLOBAL.TheWorld.state and GLOBAL.TheWorld.state.cycles) or 0
        data.wagstaff_days_survived = days
        
        WagstaffDebug("=== SALVANDO SKILLS ===")
        WagstaffDebug("self._wagstaff_activated_skills type:", type(self._wagstaff_activated_skills))
        
        -- Debug: mostrar TODAS as skills salvas em self._wagstaff_activated_skills
        WagstaffDebug("Conteudo de self._wagstaff_activated_skills:")
        local skill_count = 0
        if self._wagstaff_activated_skills then
            for k, v in pairs(self._wagstaff_activated_skills) do
                WagstaffDebug("  ", k, "=", v)
                skill_count = skill_count + 1
            end
        else
            WagstaffDebug("  (nil)")
        end
        WagstaffDebug("Total skills em self._wagstaff_activated_skills:", skill_count)
        
        data.wagstaff_activated_skills = CopyActivatedSkills(self._wagstaff_activated_skills)
        
        WagstaffDebug("data.wagstaff_activated_skills apos CopyActivatedSkills type:", type(data.wagstaff_activated_skills))
        if data.wagstaff_activated_skills then
            WagstaffDebug("Conteudo de data.wagstaff_activated_skills:")
            local data_skill_count = 0
            for k, v in pairs(data.wagstaff_activated_skills) do
                WagstaffDebug("  ", k, "=", v)
                data_skill_count = data_skill_count + 1
            end
            WagstaffDebug("Total skills em data.wagstaff_activated_skills:", data_skill_count)
        else
            WagstaffDebug("data.wagstaff_activated_skills is nil!")
        end
        
        local has_skills = false
        if data.wagstaff_activated_skills ~= nil then
            for _ in pairs(data.wagstaff_activated_skills) do
                has_skills = true
                break
            end
        end
        if not has_skills then
            WagstaffDebug("No skills in world data, checking live players")
            if GLOBAL.AllPlayers then
                for _, player in ipairs(GLOBAL.AllPlayers) do
                    if player.prefab == "wagstaff" and player.components.skilltreeupdater then
                        WagstaffDebug("Found live Wagstaff player, checking activatedskills type:", type(player.components.skilltreeupdater.activatedskills))
                        data.wagstaff_activated_skills = CopyActivatedSkills(player.components.skilltreeupdater.activatedskills)
                        local _lc = 0
                        if data.wagstaff_activated_skills ~= nil then
                            for _ in pairs(data.wagstaff_activated_skills) do _lc = _lc + 1 end
                        end
                        WagstaffDebug("Saved wagstaff_activated_skills from live player, count:", _lc)
                        break
                    end
                end
            end
        else
            local _wc = 0
            if data.wagstaff_activated_skills ~= nil then
                for _ in pairs(data.wagstaff_activated_skills) do _wc = _wc + 1 end
            end
            WagstaffDebug("Saved wagstaff_activated_skills to world data, count:", _wc)
        end
        WagstaffDebug("=== World OnSave END ===")
        return data
    end

    -- LOAD: restore boss flags, days survived, and activated skills
    local old_OnLoad = self.OnLoad
    self.OnLoad = function(self, data, ...)
        WagstaffDebug("World OnLoad called")
        if old_OnLoad then old_OnLoad(self, data, ...) end

        -- Always wipe first — blocks the engine/mod injecting 68 XP
        ForceZeroWagstaffXP()

        if data and data.wagstaff_days_survived ~= nil then
            -- Existing world: reconstruct XP from days survived
            self.state.wagstaff_fuelweaver_killed = data.wagstaff_fuelweaver_killed or false
            self.state.wagstaff_celestial_killed  = data.wagstaff_celestial_killed  or false
            self._wagstaff_days_survived = data.wagstaff_days_survived
            WagstaffDebug("Loading wagstaff_activated_skills, data type:", type(data), "data.wagstaff_activated_skills type:", type(data.wagstaff_activated_skills))
            self._wagstaff_activated_skills = CopyActivatedSkills(data.wagstaff_activated_skills)
            WagstaffDebug("Loaded _wagstaff_days_survived:", self._wagstaff_days_survived)

            -- Camada C: merge cluster-shared data (Master → Caves) se disponível.
            -- Isso garante que um shard de cave novo leia skills/dias do Master
            -- mesmo quando seu próprio world save está vazio.
            WagstaffMergeClusterSaveData(self)
            local _lac = 0; for _ in pairs(self._wagstaff_activated_skills) do _lac = _lac + 1 end; WagstaffDebug("Loaded _wagstaff_activated_skills count:", _lac)
            local days = data.wagstaff_days_survived
            
            -- CRITICAL: Apply skills IMMEDIATELY after load, not just on task delay.
            -- This handles saves with many skills that would otherwise appear empty.
            apply_world_skills_to_wagstaff()
            
            if GLOBAL.TheWorld and GLOBAL.TheWorld.DoTaskInTime then
                WagstaffDebug("DoTaskInTime scheduled for 0.5 seconds (redundant safety)")
                GLOBAL.TheWorld:DoTaskInTime(0.5, function()
                    WagstaffDebug("DoTaskInTime callback executed")
                    ForceZeroWagstaffXP()
                    InjectWagstaffXP(days)
                    apply_world_skills_to_wagstaff()
                end)
            end
        else
            -- New world (no wagstaff_days_survived key): stay at 0
            WagstaffDebug("New world detected, setting defaults")
            
            -- BUG FIX #2: Detectar se é cave e usar delay maior + lógica especial
            local is_cave = GLOBAL.TheWorld and GLOBAL.TheWorld:HasTag("cave")
            
            self.state.wagstaff_fuelweaver_killed = false
            self.state.wagstaff_celestial_killed  = false
            self._wagstaff_days_survived = 0
            self._wagstaff_activated_skills = {}
            
            -- Garante que novos mundos começam com 0 insights
            ForceZeroWagstaffXP()
            
            if is_cave then
                -- Cave precisa de delay maior porque o shard sync chega depois
                WagstaffDebug("[CAVE] New cave world detected, using delayed initialization")
                for i = 1, 5 do
                    GLOBAL.TheWorld:DoTaskInTime(i * 0.3, function()
                        ForceZeroWagstaffXP()
                    end)
                end
                GLOBAL.TheWorld:DoTaskInTime(1.5, function()
                    InjectWagstaffXP(0)
                    apply_world_skills_to_wagstaff()
                end)
            else
                if GLOBAL.TheWorld and GLOBAL.TheWorld.DoTaskInTime then
                    GLOBAL.TheWorld:DoTaskInTime(0.5, function()
                        ForceZeroWagstaffXP()
                        InjectWagstaffXP(0)
                        apply_world_skills_to_wagstaff()
                    end)
                end
            end
            
            if GLOBAL.AllPlayers then
                for _, player in ipairs(GLOBAL.AllPlayers) do
                    if player.prefab == "wagstaff" then
                        player.wagstaff_world_insights = 0
                        if player.components.skilltreeupdater then
                            player.components.skilltreeupdater.activatedskills = {}
                            SafeDirtySkillXP(player.components.skilltreeupdater)
                        end
                    end
                end
            end
        end
    end

    -- Camada C (escrita): Propagar dias+skills para o cluster save quando o
    -- shard Master persistir. Usa SetSharedSaveData quando disponível, senão
    -- propaga via eventos de rede. Isso garante que caves recebam o estado
    -- autoritativo sem depender apenas do world save local.
    local function WagstaffPropagateToCluster(self)
        if not self.network then return end
        local ok_write, write_fn = pcall(function()
            return self.network.SetSharedSaveData
        end)
        if ok_write and write_fn then
            -- SetSharedSaveData existe: propagar diretamente.
            local payload = {
                wagstaff_days_survived = self._wagstaff_days_survived or 0,
                wagstaff_activated_skills = CopyActivatedSkills(self._wagstaff_activated_skills),
            }
            -- Usar pcall para evitar crash se a API mudar no futuro.
            local ok_set, err = pcall(write_fn, self.network, payload)
            if not ok_set then
                WagstaffDebug("[CLUSTER] SetSharedSaveData falhou:", tostring(err))
            else
                WagstaffDebug("[CLUSTER] Propagado para cluster save, days:", payload.wagstaff_days_survived)
            end
        else
            -- Fallback: broadcast via evento de rede (menos confiável, mas melhor que nada).
            -- O Master e caves podem escutar esse evento e atualizar seu estado local.
            if GLOBAL.TheWorld and GLOBAL.TheWorld:HasTag("master") then
                self:PushEvent("wagstaff_cluster_sync", {
                    days = self._wagstaff_days_survived or 0,
                    skills = CopyActivatedSkills(self._wagstaff_activated_skills),
                })
                WagstaffDebug("[CLUSTER] Broadcast sync via PushEvent (fallback)")
            end
        end
    end

    -- Intercepta OnSave do world para também propagar ao cluster.
    local old_OnSave = self.OnSave
    self.OnSave = function(self, ...)
        local data = old_OnSave and old_OnSave(self, ...) or {}
        data.wagstaff_fuelweaver_killed = self.state.wagstaff_fuelweaver_killed
        data.wagstaff_celestial_killed  = self.state.wagstaff_celestial_killed
        local days = (GLOBAL.TheWorld and GLOBAL.TheWorld.state and GLOBAL.TheWorld.state.cycles) or 0
        data.wagstaff_days_survived = days
        data.wagstaff_activated_skills = CopyActivatedSkills(self._wagstaff_activated_skills)
        -- Camada C: propagar para o cluster após salvar localmente.
        WagstaffPropagateToCluster(self)
        return data
    end
    -- Expose function to save activated skills to world
    self.SaveWagstaffSkillsToWorld = function(self, activatedskills)
        WagstaffDebug("SaveWagstaffSkillsToWorld called, activatedskills type:", type(activatedskills))
        activatedskills = activatedskills or {}
        local _sc = 0; for _ in pairs(activatedskills) do _sc = _sc + 1 end; WagstaffDebug("SaveWagstaffSkillsToWorld called, skills count:", _sc)
        self._wagstaff_activated_skills = CopyActivatedSkills(activatedskills)
    end

    -- Expose function to get saved activated skills
    self.GetWagstaffSkillsFromWorld = function(self)
        return self._wagstaff_activated_skills or {}
    end

    -- Expose function to apply world skills to all Wagstaff players
    self.ApplyWagstaffSkills = apply_world_skills_to_wagstaff
    print("[Wagstaff Standalone] World persistence installed: ApplyWagstaffSkills, SaveWagstaffSkillsToWorld, GetWagstaffSkillsFromWorld are now on TheWorld")
    WagstaffDebug("World persistence functions installed on TheWorld")
end)


AddComponentPostInit("skilltreeupdater", function(self)
    local old_SaveActivatedSkills = self.SaveActivatedSkills
    self.SaveActivatedSkills = function(self2, ...)
        if self2.inst and self2.inst.prefab == "wagstaff" then
            if GLOBAL.TheWorld and GLOBAL.TheWorld.SaveWagstaffSkillsToWorld then
                GLOBAL.TheWorld:SaveWagstaffSkillsToWorld(self2.activatedskills)
            end
            return
        end
        if old_SaveActivatedSkills then
            return old_SaveActivatedSkills(self2, ...)
        end
    end
end)


-- Block any external AddSkillXP calls for wagstaff EXCEPT our own injection
-- and the legitimate +1/day from daycomplete below.
-- This kills the 68-XP injection from the original workshop mod.
AddSimPostInit(function()
    if GLOBAL.TheSkillTree and GLOBAL.TheSkillTree.AddSkillXP then
        local old_AddSkillXP = GLOBAL.TheSkillTree.AddSkillXP
        GLOBAL.TheSkillTree.AddSkillXP = function(self, amount, prefab)
            if prefab == "wagstaff" and not _wagstaff_xp_injecting then
                if amount ~= 1 then
                    return
                end
            end
            return old_AddSkillXP(self, amount, prefab)
        end
    end
end)

AddSimPostInit(function()
    if not GLOBAL.TheWorld or not GLOBAL.TheWorld.ismastersim then
        return
    end
    local function ClampWagstaffXPToWorldProgress()
        if not GLOBAL.TheSkillTree or not GLOBAL.TheSkillTree.skillxp or _wagstaff_xp_injecting then
            return
        end
        local expected = GetWagstaffSkillXPFromDays(GetWagstaffDaysSurvived())
        local current = GLOBAL.TheSkillTree.skillxp["wagstaff"] or 0
        if current > expected then
            _wagstaff_xp_injecting = true
            GLOBAL.TheSkillTree.skillxp["wagstaff"] = expected
            _wagstaff_xp_injecting = false
            if GLOBAL.AllPlayers then
                for _, player in ipairs(GLOBAL.AllPlayers) do
                    if player.prefab == "wagstaff" and player.components.skilltreeupdater then
                        SafeDirtySkillXP(player.components.skilltreeupdater)
                    end
                end
            end
        end
    end
    if GLOBAL.TheWorld.DoPeriodicTask then
        GLOBAL.TheWorld:DoPeriodicTask(2, ClampWagstaffXPToWorldProgress)
    end
end)


-- Listen for boss kills
AddPrefabPostInit("stalker_atrium", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    inst:ListenForEvent("death", function()
        GLOBAL.TheWorld.state.wagstaff_fuelweaver_killed = true
    end)
end)

AddPrefabPostInit("alterguardian_phase3", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    inst:ListenForEvent("death", function()
        GLOBAL.TheWorld.state.wagstaff_celestial_killed = true
    end)
end)


-- Each day survived: Update XP based on days survived (not +1 per day)
-- Our filter above allows only controlled XP injection, so this is safe.
-- Cave: TheWorld.ismastersim is true in cave too, but the world save is separate
-- and has no wagstaff_days_survived key, so it starts at 0. Cave XP accrues
-- in isolation (no cave-specific logic yet -- future work).
AddPrefabPostInit("wagstaff", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    
    inst:ListenForEvent("daycomplete", function(inst)
        -- BUG FIX #2: Ignorar caves para evitar problemas de sync de XP
        if GLOBAL.TheWorld and GLOBAL.TheWorld:HasTag("cave") then
            return
        end
        
        if not inst:HasTag("playerghost") then
            -- Calcula o XP baseado nos dias sobrevividos
            local days = (GLOBAL.TheWorld and GLOBAL.TheWorld.state and GLOBAL.TheWorld.state.cycles) or 0
            local thresholds = TUNING.SKILL_THRESHOLDS.wagstaff or {3,6,10,14,18,23,28,33,38,43,48,53,58,63,68}
            
            -- Calcula quantos insights o jogador deveria ter
            local new_insights = 0
            for i, threshold in ipairs(thresholds) do
                if days >= threshold then
                    new_insights = i
                else
                    break -- Não precisa verificar mais thresholds
                end
            end
            
            -- Atualiza apenas se o valor mudou
            if new_insights > inst.wagstaff_world_insights then
                inst.wagstaff_world_insights = new_insights
                -- Injeta o XP correspondente ao número de dias
                InjectWagstaffXP(days)
                
                if inst.components.talker then
                    inst.components.talker:Say("Minhas pesquisas avançaram! Agora tenho " .. new_insights .. " Insights neste mundo.")
                end
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
                if inst.prefab == "wagstaff" and GLOBAL.TheWorld and GLOBAL.TheWorld.SaveWagstaffSkillsToWorld then
                    GLOBAL.TheWorld:SaveWagstaffSkillsToWorld(activated)
                end
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

    if worker and worker:HasTag("wagstaff_mechanical_efficiency") and G.math.random() < 0.30 then

        return 0

    end

    return base_cost

end)


-- Patch skill tree widget to remove tint for Wagstaff and fix favor overlay z-order
AddClassPostConstruct("widgets/redux/skilltreewidget", function(self)
    local original_SpawnFavorOverlay = self.SpawnFavorOverlay
    self.SpawnFavorOverlay = function(self2, pre)
        original_SpawnFavorOverlay(self2, pre)
        -- Ensure the favor overlay (midlay) is on top of everything, including the bg_tree!
        if self2.midlay and self2.target == "wagstaff" then
            self2.midlay:MoveToFront()
        end
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


-- Ballistic MK3 Star Caller Toggle action
local BALLISTIC_STARCALLER = AddAction("BALLISTIC_STARCALLER", "Toggle Light Orb", function(act)
    if act.target and act.target:HasTag("ballistic_mk2") then
        act.target:PushEvent("starcaller_toggle_request", act.doer)
        return true
    end
    return false
end)
BALLISTIC_STARCALLER.priority = 10
BALLISTIC_STARCALLER.rmb = false
BALLISTIC_STARCALLER.distance = 2

-- Add component action for Ballistic MK3
AddComponentAction("SCENE", "combat", function(inst, doer, actions, right)
    if not right and inst:HasTag("ballistic_mk2") and inst.components.combat then
        table.insert(actions, GLOBAL.ACTIONS.BALLISTIC_STARCALLER)
    end
end)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.BALLISTIC_STARCALLER, "doshortaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.BALLISTIC_STARCALLER, "doshortaction"))


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

    STRINGS.NAMES.WILLIAMBUTLER = "Butler Bot"

    STRINGS.NAMES.WILLIAMBUTLER2 = "Butler Bot Mk.II"

    STRINGS.NAMES.WILLIAMBUSTER = "Buster Bot"

    STRINGS.NAMES.WILLIAMBRUTE = "Brute Bot"

    STRINGS.NAMES.WILLIAMBRUTE2 = "Brute Bot Mk.II"

    STRINGS.NAMES.WILLIAMBUSTER2 = "Buster Bot Mk.II"

    STRINGS.NAMES.WILLIAMBALLISTIC2 = "Ballistic Bot Mk.II"

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

        {Ingredient("scrap", 20, eimg("scrap")), Ingredient("gears", 3)},

        TECH.MAGIC_TWO,

        {builder_tag = "tinkerer", atlas = eimg("esentry"), image = "esentry.tex"},

        {"CHARACTER", "WEAPONS", "STRUCTURES"})

    AddRecipe2("dispenser",

        {Ingredient("scrap", 15, eimg("scrap")), Ingredient("redgem", 3)},

        TECH.SCIENCE_ONE,

        {builder_tag = "tinkerer", atlas = eimg("dispenser"), image = "dispenser.tex"},

        {"CHARACTER", "RESTORATION", "STRUCTURES"})

    AddRecipe2("eteleporter",

        {Ingredient("scrap", 30, eimg("scrap")), Ingredient("gears", 5), Ingredient("transistor", 5)},

        TECH.MAGIC_THREE,

        {builder_tag = "tinkerer", atlas = eimg("eteleporter"), image = "eteleporter.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("eteleporter_exit",

        {Ingredient("scrap", 25, eimg("scrap")), Ingredient("gears", 3), Ingredient("transistor", 3)},

        TECH.MAGIC_THREE,

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

        TECH.MAGIC_TWO,

        {builder_tag = "tinkerer", atlas = mimg("williambuster_builder"), image = "williambuster_builder.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("williambrute_builder",

        {williamgadget_ing, Ingredient("cutstone", 4), Ingredient("transistor", 2)},

        TECH.SCIENCE_TWO,

        {builder_tag = "tinkerer", atlas = mimg("williambrute_builder"), image = "williambrute_builder.tex"},

        {"CHARACTER", "STRUCTURES"})

    AddRecipe2("williamballistic_empty",

        {williamgadget_ing, Ingredient("nitre", 4), Ingredient("transistor", 2)},

        TECH.MAGIC_THREE,

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
