-- ============================================================================
-- Wagstaff Standalone — modmain.lua
-- Single self-contained character mod. Extracted from Hamlet Characters - Rework
-- (workshop 2399658326), Wagstaff-only.
-- ============================================================================

local TUNING = GLOBAL.TUNING

-- Tropical Experience / Above The Clouds interop (gates the SPY action in postinits)
TUNING.HCRtropicalsupport = false
if GLOBAL.KnownModIndex:IsModEnabled("workshop-1505270912") then
    TUNING.HCRtropicalsupport = true
end
print("    [Wagstaff Standalone]: Tropical support is set to: " .. tostring(TUNING.HCRtropicalsupport))

PrefabFiles = {
    ---[[Wagstaff]]---
    "wagstaff",
    "wagstaff_none",

    "goggles",
    "fryfocals_charge",

    "thumper",
    "telipad",
    "telebrella",
    "hiddendanger_fx",
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
}

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

-- Minimap atlas registration
AddMinimapAtlas("images/map_icons/wagstaff.xml")
AddMinimapAtlas("images/inventoryimages/telipad.xml")
AddMinimapAtlas("images/inventoryimages/thumper.xml")

----------------------------------------------------------
-- Mod imports (all Wagstaff-relevant, extracted from Hamlet Characters)
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
