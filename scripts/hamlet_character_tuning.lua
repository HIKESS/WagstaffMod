-- Wagstaff Standalone — Tuning
-- Extracted from Hamlet Characters - Rework (workshop 2399658326), Wagstaff-only.

local require = GLOBAL.require
local TUNING = GLOBAL.TUNING
local wilson_attack = 34
local wilson_health = 150
local seg_time = 30
local total_day_time = seg_time*16
local night_segs = 2
local night_time = seg_time * night_segs

TUNING.HCRDEBUG = GetModConfigData("debug")

TUNING.PRESET = GetModConfigData("preset")

---------[[Wagstaff]]---------
TUNING.GOGGLES_NORMAL_PERISHTIME = 10 * total_day_time
TUNING.GOGGLES_HEAT_PERISHTIME = 2 * total_day_time
TUNING.GOGGLES_ARMOR_ARMOR = wilson_health * 4 * 0.7
TUNING.GOGGLES_ARMOR_ABSORPTION = 0.85
TUNING.GOGGLES_SHOOT_USES = 10
TUNING.NEARSIGHTED_BLUR_START_RADIUS = 0.0
TUNING.NEARSIGHTED_BLUR_STRENGTH = 3.0
TUNING.GOGGLES_HEAT =
	{
		HOT=
		{
			BLOOM = true,
			DESATURATION = 1.0,
			MULT_COLOUR = {0.0, 1.0, 0.5, 1.0},
			ADD_COLOUR  = {1.0, 0.1, 0.3, 1.0},
		},
		COLD=
		{
			BLOOM = false,
			DESATURATION = 0.7,
			MULT_COLOUR = {0.0, 0.0, 0.3, 1.0},
			ADD_COLOUR  = {0.1, 0.1, 0.5, 1.0},
		},
		GROUND=
		{
			MULT_COLOUR = {0.0, 0.1, 0.3, 1.0},
		ADD_COLOUR  = {0.1, 0.1, 0.5, 1.0}
		},
		WAVES=
		{
			MULT_COLOUR = {0.0, 0.0, 0.3, 1.0},
			ADD_COLOUR  = {0.1, 0.1, 0.6, 1.0},
		},
		BLUR=
		{
			ENABLED = true,
			START_RADIUS = -5.0,
			STRENGTH = 0.16,
		}
	}

TUNING.TELEBRELLA_USES = 10
TUNING.NEARSIGHTED_ACTION_RANGE = 4

TUNING.GAMEMODE_STARTING_ITEMS.LAVAARENA.WAGSTAFF = {}
TUNING.GAMEMODE_STARTING_ITEMS.QUAGMIRE.WAGSTAFF = {"gogglesnormalhat", "quagmire_telebrella"}

if TUNING.PRESET == "OLD" then
	TUNING.MYSTERY_CHANCE = 0.05
	TUNING.MYSTERY_NIL_CHANCE = 0.4
	TUNING.MYSTERY_MID_CHANCE = 0.7
	TUNING.WEAKSTOMACHPAIN = -3
	TUNING.TELEBRELLA_SPELLTYPE = "point"
	TUNING.TELEBRELLA_RANDOM = false

elseif TUNING.PRESET == "HAMLET" then
	TUNING.MYSTERY_CHANCE = 0.05
	TUNING.MYSTERY_NIL_CHANCE = 0.4
	TUNING.MYSTERY_MID_CHANCE = 0.7
	TUNING.WEAKSTOMACHPAIN = -3
	TUNING.TELEBRELLA_SPELLTYPE = "point"
	TUNING.TELEBRELLA_RANDOM = false

else
	TUNING.MYSTERY_CHANCE = GetModConfigData("mysterychance")
	TUNING.MYSTERY_NIL_CHANCE = GetModConfigData("mysterynilchance")
	TUNING.MYSTERY_MID_CHANCE = GetModConfigData("mysterymidchance")
	TUNING.WEAKSTOMACHPAIN = GetModConfigData("weakstomachpain")
	TUNING.TELEBRELLA_SPELLTYPE = GetModConfigData("telebrellaspelltype")
	TUNING.TELEBRELLA_RANDOM = GetModConfigData("telebrellarandom")
	-- v2.0.39: finite uses + cooldown to balance the Telebrella. Previously it
	-- used TUNING.TELEBRELLA_USES from the Hamlet DLC (50 uses), which was far
	-- too many — a single Telebrella could skip half the map content. Now
	-- configurable: default 15 uses + 10s cooldown between teleports.
	TUNING.TELEBRELLA_USES = GetModConfigData("telebrellauses") or 15
	TUNING.TELEBRELLA_COOLDOWN = GetModConfigData("telebrellacooldown") or 10
end

TUNING.GOGGLES_RESTRICTED = GetModConfigData("gogglesrestricted")

TUNING.VISIONBLUR_ENABLED = GetModConfigData("enableblur")

TUNING.FLICKERTHRESHOLD = GetModConfigData("flickerthreshold")

-- Wagstaff base stats (used by menustrings / character select screen)
TUNING.WAGSTAFF_HEALTH = 150
TUNING.WAGSTAFF_HUNGER = 225
TUNING.WAGSTAFF_SANITY = 150

-- Forge (Lava Arena) starting health for Wagstaff
if TUNING.LAVAARENA_STARTING_HEALTH == nil then
	TUNING.LAVAARENA_STARTING_HEALTH = {}
end
TUNING.LAVAARENA_STARTING_HEALTH.WAGSTAFF = 150

if TUNING.LAVAARENA_SURVIVOR_DIFFICULTY == nil then
	TUNING.LAVAARENA_SURVIVOR_DIFFICULTY = {}
end
TUNING.LAVAARENA_SURVIVOR_DIFFICULTY.WAGSTAFF = 5

-- Default gamemode starting items for Wagstaff
if TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT == nil then
	TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT = {}
end
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WAGSTAFF = {"gogglesnormalhat"}

-- Starting item image override: gogglesnormalhat should show the Wagstaff goggles icon
if TUNING.STARTING_ITEM_IMAGE_OVERRIDE == nil then
	TUNING.STARTING_ITEM_IMAGE_OVERRIDE = {}
end
TUNING.STARTING_ITEM_IMAGE_OVERRIDE["gogglesnormalhat"] = "wagstaffnormalgoggles.tex"

-- Affinity tuning (Wagstaff loves mashed potatoes)
TUNING.AFFINITY_15_CALORIES_LARGE = 15

-- Wagstaff's weak stomach pain flag name (consumed by wagstaff.lua master_postinit)
-- TUNING.WEAKSTOMACHPAIN is set above per preset/config.
