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

STRINGS.RECIPE_DESC.GOGGLESNORMALHAT = "Basic super goggles. Reveal hidden danger"
STRINGS.RECIPE_DESC.GOGGLESHEATHAT = "Is everything hot or not"
STRINGS.RECIPE_DESC.GOGGLESARMORHAT = "Armored lenses"
STRINGS.RECIPE_DESC.GOGGLESSHOOTHAT = "Static boom focusing apparatus"
STRINGS.RECIPE_DESC.TELEBRELLA = "A revolutionary walker"
STRINGS.RECIPE_DESC.TELIPAD = "A revolutionary teleporter"
STRINGS.RECIPE_DESC.THUMPER = "A revolutionary harvester"
