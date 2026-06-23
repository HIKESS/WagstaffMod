name = "Wagstaff Standalone"
description = [[Standalone Wagstaff character mod — The Cryptic Founder.

A great inventor, nearsighted, with a delicate stomach. Now a fully self-contained mod with integrated skill tree progression, engineer bots, sentry guns, dispensers, and teleporters.

Features:
- Wagstaff character with nearsightedness & weak stomach mechanics
- 4 goggle types (Normal, Heat Vision, Armor, Fryfocals/Shoot)
- Spygoggles investigation system (peculiar objects in the world)
- Telebrella + Telipad teleport network
- Thumper ground-pounding harvester
- FULL SKILL TREE (15 insights, per-world persistence, 3 branches: Mechanical/Robotic/Allegiance)
- Engineer bots: Butler, Buster, Brute, Ballistic (each with MK2/MK3 upgrades)
- Sentry Gun (MK2/MK3 upgrades with rockets + double damage)
- Dispenser (MK2/MK3 upgrades with health regen + lucky drops)
- Engineer Teleporter (entrance + exit, sanity cost reducible via skill)
- TF2 Wrench (calibrated via skill to consume less durability)
- Affinity system: Shadow Engineer vs Celestial Engineer (boss-gated)
- Per-world progression: XP/insights saved per world, not per profile
- Forge (Lava Arena) and Gorge (Quagmire) mode support
- Blur shader for nearsighted vision

Original character by Hornet, reworked by Niko. Skill tree + integration by Wholemaker Team.]]
id = "wagstaff_standalone"
author = "Wholemaker Team (standalone) — original by Hornet/Niko"
version = "2.0.17"

api_version = 10

priority = 5

dst_compatible = true
forge_compatible = true
gorge_compatible = true

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true
client_only_mod = false
server_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {
    "character",
    "wagstaff",
    "inventor",
    "hamlet",
}

mim_assets = {
    characters = {
        wagstaff = {
            gender = "MALE",
            name = "Wagstaff",
            title = "The Cryptic Founder",
            quote = "\"Eureka! My destiny awaits!\"",
            aboutme = "Most who find themselves in the Constant are usually tricked into the realm. Wagstaff however, has found himself exactly where he wants to be."
        },
    }
}

configuration_options = {
    {
        name = "language",
        label = "Select Language",
        hover = "Auto-detects English/Chinese. EN/ZH",
        options = {
            {description = "Auto-Detect", data = "auto"},
            {description = "English",     data = "en"},
            {description = "中文",         data = "ch"},
        },
        default = "auto",
    },
    {
        name = "preset",
        label = "Preset",
        hover = "Overwrite the config with a preset? Options marked * won't be overwritten.",
        options = {
            {description = "None",        data = "NONE"},
            {description = "Default",     data = "DEFAULT"},
            {description = "Old Wagstaff",data = "OLD"},
            {description = "Hamlet",      data = "HAMLET"},
        },
        default = "NONE",
    },
    {
        name = "mysterychance",
        label = "Peculiar object chance",
        hover = "Chance for trees/rocks to be 'peculiar' (investigatable with spygoggles).",
        options = {
            {description = "0%",   data = 0},
            {description = "1%",   data = 0.01},
            {description = "2%",   data = 0.02},
            {description = "3%",   data = 0.03},
            {description = "4%",   data = 0.04},
            {description = "6%",   data = 0.06},
            {description = "7%",   data = 0.07},
            {description = "8%",   data = 0.08},
            {description = "9%",   data = 0.09},
            {description = "10%",  data = 0.10},
            {description = "15%",  data = 0.15},
            {description = "20%",  data = 0.20},
            {description = "25%",  data = 0.25},
            {description = "30%",  data = 0.30},
            {description = "40%",  data = 0.40},
            {description = "50%",  data = 0.50},
            {description = "75%",  data = 0.75},
            {description = "100%", data = 1},
        },
        default = 0.03,
    },
    {
        name = "mysterynilchance",
        label = "Peculiar fail chance",
        hover = "Chance an investigated peculiar object yields nothing.",
        options = {
            {description = "0%",  data = 0},
            {description = "10%", data = 0.1},
            {description = "20%", data = 0.2},
            {description = "30%", data = 0.3},
            {description = "40%", data = 0.4},
            {description = "50%", data = 0.5},
            {description = "60%", data = 0.6},
            {description = "70%", data = 0.7},
            {description = "80%", data = 0.8},
            {description = "90%", data = 0.9},
        },
        default = 0.4,
    },
    {
        name = "mysterymidchance",
        label = "Peculiar uncommon chance",
        hover = "Chance an investigated peculiar object yields an uncommon reward.",
        options = {
            {description = "0%",  data = 0},
            {description = "10%", data = 0.1},
            {description = "20%", data = 0.2},
            {description = "30%", data = 0.3},
            {description = "40%", data = 0.4},
            {description = "50%", data = 0.5},
            {description = "60%", data = 0.6},
            {description = "70%", data = 0.7},
            {description = "80%", data = 0.8},
            {description = "90%", data = 0.9},
        },
        default = 0.7,
    },
    {
        name = "weakstomachpain",
        label = "Weak Stomach Damage",
        hover = "Health lost when eating uncooked/unprepared food.",
        options = {
            {description = "-1",   data = -1},
            {description = "-3",   data = -3},
            {description = "-5",   data = -5},
            {description = "-10",  data = -10},
            {description = "-20",  data = -20},
            {description = "-50",  data = -50},
            {description = "-100", data = -100},
        },
        default = -3,
    },
    {
        name = "telebrellaspelltype",
        label = "Telebrella activation",
        hover = "How the Telebrella triggers: 'item' = right-click item, 'point' = click a telipad on the ground.",
        options = {
            {description = "Item (right-click)", data = "item"},
            {description = "Point (click telipad)", data = "point"},
        },
        default = "item",
    },
    {
        name = "telebrellarandom",
        label = "Telebrella Misfire",
        hover = "If enabled, the Telebrella may teleport you to a random telipad instead of the nearest.",
        options = {
            {description = "No",  data = false},
            {description = "Yes", data = true},
        },
        default = true,
    },
    {
        name = "flickerthreshold",
        label = "*Distortion threshold",
        hover = "* not overwritten by presets. Health % below which Wagstaff's projection starts to distort/flicker.",
        options = {
            {description = "10%",  data = 0.1},
            {description = "20%",  data = 0.2},
            {description = "25%",  data = 0.25},
            {description = "30%",  data = 0.3},
            {description = "40%",  data = 0.4},
            {description = "50%",  data = 0.5},
            {description = "60%",  data = 0.6},
            {description = "70%",  data = 0.7},
            {description = "75%",  data = 0.75},
            {description = "Off (100%)", data = 1},
        },
        default = 0.75,
    },
    {
        name = "enableblur",
        label = "*Poor vision blur",
        hover = "* not overwritten by presets. Enable the screen blur effect when nearsighted (no goggles equipped).",
        options = {
            {description = "No",  data = false},
            {description = "Yes", data = true},
        },
        default = true,
    },
    {
        name = "gogglesrestricted",
        label = "*Restrict Wagstaff's goggles?",
        hover = "* not overwritten by presets. If enabled, only Wagstaff can wear the goggles.",
        options = {
            {description = "No",  data = false},
            {description = "Yes", data = true},
        },
        default = false,
    },
    {
        name = "debug",
        label = "*Debug mode",
        hover = "* not overwritten by presets. Enable debug logging for skill tree registration and activation.",
        options = {
            {description = "No",  data = false},
            {description = "Yes", data = true},
        },
        default = false,
    },
}
