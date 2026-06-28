local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS
local TUNING = GLOBAL.TUNING


    local seg_time = 30
    local total_day_time = seg_time*16

TUNING.WILLIAM_HEALTH = 100
TUNING.WILLIAM_HUNGER = 150
TUNING.WILLIAM_SANITY = 200
TUNING.WILLIAM_DAMAGE = 0.75

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WILLIAM = {"williamgadget"}
TUNING.STARTING_ITEM_IMAGE_OVERRIDE.williamgadget = {
    atlas = "images/inventoryimages/williamgadget.xml",
    image = "williamgadget.tex",
  }


TUNING.WILLIAM_ROBOT_REGEN = 5
TUNING.WILLIAM_ROBOT_REGENPERIOD = 5


-- v2.0.82: Ballistic HP 150 -> 300. The ranged turret bot was a glass cannon
-- (one hound pack could destroy it). Doubled so it survives a real fight while
-- staying clearly squishier than the melee Buster.
TUNING.WILLIAM_BALLISTIC_HEALTH = 300
TUNING.WILLIAM_BALLISTIC_ATTACK_PERIOD = 3
TUNING.WILLIAM_BALLISTIC_DAMAGE = 24/1.5 -- Due to the damage being electric, it will get multiplied by 1.5 against any mob
-- v2.0.86: Removed WILLIAM_BALLISTIC_MAXFUEL (seg_time*121 = 3630s). It was
-- defined but never used — the code uses TUNING.WINONA_BATTERY_LOW_MAX_FUEL_TIME * 5
-- instead (see william_ballistic.lua MK1/MK2). This was dead code / orphan constant.

-- v2.0.82: Buster HP 300 -> 500. A melee combat bot at 300 HP died too fast in
-- sustained fights; 500 lets it tank a hound wave without instant retirement.
-- Fuel tank 48 seg (3 days) -> 64 seg (4 days): buster had the smallest tank of
-- all four bots, which combined with its restrictive mechanical-only diet made
-- it tedious to keep running. Now matches the Butler's endurance.
TUNING.WILLIAM_BUSTER_HEALTH = 500
TUNING.WILLIAM_BUSTER_ATTACK_PERIOD = 2
TUNING.WILLIAM_BUSTER_ATTACK_RANGE = 3
TUNING.WILLIAM_BUSTER_DAMAGE = 36
TUNING.WILLIAM_BUSTER_WALK_SPEED = 12
TUNING.WILLIAM_BUSTER_MAXFUEL = seg_time*64

TUNING.WILLIAM_BUTLER_HEALTH = 200
TUNING.WILLIAM_BUTLER_ATTACK_PERIOD = 2
TUNING.WILLIAM_BUTLER_ATTACK_RANGE = 3
TUNING.WILLIAM_BUTLER_DAMAGE = 30 -- Depricated
TUNING.WILLIAM_BUTLER_WALK_SPEED = 12
TUNING.WILLIAM_BUTLER_MAXFUEL = seg_time*64

TUNING.WILLIAM_BRUTE_HEALTH = 1500
TUNING.WILLIAM_BRUTE_ATTACK_PERIOD = 2
TUNING.WILLIAM_BRUTE_ATTACK_RANGE = 3
TUNING.WILLIAM_BRUTE_DAMAGE = 17
TUNING.WILLIAM_BRUTE_WALK_SPEED = 1.5
TUNING.WILLIAM_BRUTE_RUN_SPEED = 4
TUNING.WILLIAM_BRUTE_MAXFUEL = seg_time*80

-- Industrialization Generator / Bud Lamp (from mod 2270993633)
TUNING.TERMINAL_FUEL = 10