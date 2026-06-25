-- Wagstaff Standalone — Recipes
-- Extracted from Hamlet Characters - Rework (workshop 2399658326), Wagstaff-only (L1-68).

local STRINGS = GLOBAL.STRINGS
local TECH = GLOBAL.TECH
local RECIPETABS = GLOBAL.RECIPETABS
local AllRecipes = GLOBAL.AllRecipes

----------------------------[[Wagstaff]]--------------------------
local GogglesIngredient = Ingredient("gogglesnormalhat", 1, "images/inventoryimages/wagstaffnormalgoggles.xml", nil, "wagstaffnormalgoggles.tex")
AddCharacterRecipe("gogglesnormalhat",
    {Ingredient("goldnugget", 1), Ingredient("pigskin", 1)},
    TECH.NONE,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/wagstaffnormalgoggles.xml", image = "wagstaffnormalgoggles.tex"},
    {"MODS", "CLOTHING"}
)
AddCharacterRecipe("gogglesheathat",
    {GogglesIngredient, Ingredient("transistor", 1), Ingredient("torch", 2)},
    TECH.NONE,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/wagstaffheatgoggles.xml", image = "wagstaffheatgoggles.tex"},
    {"MODS", "CLOTHING"}
)
AddCharacterRecipe("gogglesarmorhat",
    {GogglesIngredient, Ingredient("cutstone", 1)},
    TECH.NONE,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/wagstaffarmorgoggles.xml", image = "wagstaffarmorgoggles.tex"},
    {"MODS", "CLOTHING"}
)
AddCharacterRecipe("gogglesshoothat",
    {GogglesIngredient, Ingredient("redgem", 1)},
    TECH.NONE,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/wagstaffshootgoggles.xml", image = "wagstaffshootgoggles.tex"},
    {"MODS", "CLOTHING"}
)

AddCharacterRecipe("telebrella",
    {Ingredient("grass_umbrella", 1), Ingredient("transistor", 1)},
    TECH.MAGIC_TWO,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/telebrella.xml", image = "telebrella.tex"},
    {"MODS", "TOOLS"}
)
AddCharacterRecipe("telipad",
    {Ingredient("gears", 1), Ingredient("transistor", 1), Ingredient("cutstone", 2)},
    TECH.MAGIC_TWO,
    {builder_tag = "tinkerer", placer = "telipad_placer", atlas = "images/inventoryimages/telipad.xml", image = "telipad.tex"},
    {"MODS", "STRUCTURES"}
)

AddCharacterRecipe("thumper",
    {Ingredient("gears", 1), Ingredient("flint", 6), Ingredient("hammer", 2)},
    TECH.SCIENCE_ONE,
    {builder_tag = "tinkerer", placer = "thumper_placer", atlas = "images/inventoryimages/thumper.xml", image = "thumper.tex"},
    {"MODS", "STRUCTURES"}
)

--==================== WILLIAM TOYMAKER (BOTS) ====================--
-- v2.0.78: Moved bot recipes here from modmain.lua's AddSimPostInit block.
-- Using AddCharacterRecipe (the DST standard for character-specific recipes)
-- ensures proper TECH/prototyper enforcement. Recipes registered inside
-- AddSimPostInit with AddRecipe2 did not reliably enforce the TECH level,
-- making bots appear as free craft (no prototyper needed).
--
-- Prototyper requirements:
--   William Gadget: TECH.NONE      (free craft — base material)
--   Butler Bot:     TECH.SCIENCE_ONE  (Science Machine)
--   Buster Bot:     TECH.MAGIC_ONE    (Prestihatitator)
--   Brute Bot:      TECH.SCIENCE_TWO  (Alchemy Engine)
--   Ballistic Bot:  TECH.MAGIC_TWO    (Shadow Manipulator)

local WilliamGadgetIngredient = Ingredient("williamgadget", 1, "images/inventoryimages/williamgadget.xml", nil, "williamgadget.tex")

AddCharacterRecipe("williamgadget",
    {Ingredient("gears", 2), Ingredient("goldnugget", 1)},
    TECH.NONE,
    {builder_tag = "tinkerer", numtogive = 1, atlas = "images/inventoryimages/williamgadget.xml", image = "williamgadget.tex"},
    {"CHARACTER", "REFINE"}
)

AddCharacterRecipe("williambutler_builder",
    {WilliamGadgetIngredient, Ingredient("boards", 4), Ingredient("transistor", 2)},
    TECH.SCIENCE_ONE,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/williambutler_builder.xml", image = "williambutler_builder.tex"},
    {"CHARACTER", "STRUCTURES"}
)

AddCharacterRecipe("williambuster_builder",
    {WilliamGadgetIngredient, Ingredient("marble", 3), Ingredient("transistor", 2)},
    TECH.MAGIC_ONE,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/williambuster_builder.xml", image = "williambuster_builder.tex"},
    {"CHARACTER", "STRUCTURES"}
)

AddCharacterRecipe("williambrute_builder",
    {WilliamGadgetIngredient, Ingredient("cutstone", 4), Ingredient("transistor", 2)},
    TECH.SCIENCE_TWO,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/williambrute_builder.xml", image = "williambrute_builder.tex"},
    {"CHARACTER", "STRUCTURES"}
)

AddCharacterRecipe("williamballistic_empty",
    {WilliamGadgetIngredient, Ingredient("nitre", 4), Ingredient("transistor", 2)},
    TECH.MAGIC_TWO,
    {builder_tag = "tinkerer", atlas = "images/inventoryimages/williamballistic_empty.xml", image = "williamballistic_empty.tex"},
    {"CHARACTER", "STRUCTURES"}
)

STRINGS.RECIPE_DESC.GOGGLESNORMALHAT = "Basic super goggles. Reveal hidden danger"
STRINGS.RECIPE_DESC.GOGGLESHEATHAT = "Is everything hot or not"
STRINGS.RECIPE_DESC.GOGGLESARMORHAT = "Armored lenses"
STRINGS.RECIPE_DESC.GOGGLESSHOOTHAT = "Static boom focusing apparatus"
STRINGS.RECIPE_DESC.TELEBRELLA = "A revolutionary walker"
STRINGS.RECIPE_DESC.TELIPAD = "A revolutionary teleporter"
STRINGS.RECIPE_DESC.THUMPER = "A revolutionary harvester"
STRINGS.RECIPE_DESC.WILLIAMGADGET = "The Robot Core"
STRINGS.RECIPE_DESC.WILLIAMBUTLER_BUILDER = "Your mechanical servant"
STRINGS.RECIPE_DESC.WILLIAMBUSTER_BUILDER = "Heavy hitter"
STRINGS.RECIPE_DESC.WILLIAMBRUTE_BUILDER = "Shield unit"
STRINGS.RECIPE_DESC.WILLIAMBALLISTIC_EMPTY = "Long range support"
