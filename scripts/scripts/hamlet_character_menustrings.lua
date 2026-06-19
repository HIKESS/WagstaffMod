-- Wagstaff Standalone — Menu strings (character select screen)
-- Extracted from Hamlet Characters - Rework (workshop 2399658326), Wagstaff-only (L1-34).

local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS
local TUNING = GLOBAL.TUNING

---------[[Wagstaff]]---------
TUNING.WAGSTAFF_HEALTH = 150
TUNING.WAGSTAFF_SANITY = 150
TUNING.WAGSTAFF_HUNGER = 225

TUNING.LAVAARENA_STARTING_HEALTH.WAGSTAFF = 125
TUNING.LAVAARENA_SURVIVOR_DIFFICULTY.WAGSTAFF = TUNING.LAVAARENA_SURVIVOR_DIFFICULTY.WX78

STRINGS.CHARACTER_TITLES.wagstaff = "The Cryptic Founder"
STRINGS.CHARACTER_NAMES.wagstaff = "Wagstaff"
STRINGS.CHARACTER_DESCRIPTIONS.wagstaff = "*A great inventor\n*Nearsighted\n*Delicate Stomach"
STRINGS.CHARACTER_QUOTES.wagstaff = "\"Eureka! My destiny awaits!\""
STRINGS.CHARACTER_ABOUTME.wagstaff = "Robert Wagstaff use to be a snake oil salesman before becoming the founder of the Voxola Radio company. He mysteriously disappeared via a malfunctioning portal at the Voxola factory of Sidney, Ohio the night it went ablaze."
STRINGS.CHARACTER_BIOS.wagstaff = {
    { title = "Birthday", desc = "Unknown" },
    { title = "Favorite Food", desc = "Creamy Potato Purée" },
    { title = "The Voxola PR-76", desc = "This radio, manufactured in 1919 by the Voxola Radio company of Sidney, Ohio. The radio offered revolutionary sound and reception quality for the time, and was promoted by an intense national marketing campaign. Very few units were actually produced, because the factory was destroyed in a fire only days after production began. Voxola founder Robert Wagstaff went missing the night of the fire, and the company declared bankruptcy soon thereafter." },
}

STRINGS.LAVAARENA_CHARACTER_DESCRIPTIONS.wagstaff = "*Comes with a modified Iron hulk weapon.\n*Wagstaff's energy collector boosts teammates for 10% more protection.\n*Nearsighted\n*Expertise:\n* Goggles, Darts"
STRINGS.QUAGMIRE_CHARACTER_DESCRIPTIONS.wagstaff = "*Uses his trusty Telebrella to get around the Elder Bog\n\n\n*Expertise:\nGathering"

TUNING.STARTING_ITEM_IMAGE_OVERRIDE["gogglesnormalhat"] = {
    atlas = "images/inventoryimages/wagstaffnormalgoggles.xml",
    image = "wagstaffnormalgoggles.tex",
}

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WAGSTAFF = { "gogglesnormalhat" }

STRINGS.CHARACTER_SURVIVABILITY.wagstaff = "Slim"
