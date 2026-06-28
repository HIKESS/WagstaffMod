// WagstaffMod patch notes — extracted from worklog.md and git history
// Source: /home/z/my-project/worklog.md

export interface PatchNote {
  version: string;
  date: string;
  commit?: string;
  type: "feature" | "bugfix" | "balance" | "chore";
  title: string;
  changes: string[];
}

export const PATCH_NOTES: PatchNote[] = [
  {
    version: "2.0.88",
    date: "2026-06-28",
    commit: "d44efb7",
    type: "feature",
    title: "Brute Taunt, Rocket Scaling, Fuel Warnings",
    changes: [
      "Brute MK2+ now has passive taunt: every 2s, enemies within radius 6 (MK2) or 8 (MK3) targeting a player are forced to retarget the brute.",
      "MK3 rockets now deal 50 damage (was 25, hardcoded) — uses TUNING.SENTRY_ROCKET_DAMAGE.",
      "All 12 bot prefab variants (4 bots × 3 tiers) now warn the owner when fuel drops below 20% / 10%.",
      "Documented orphaned 'gadgets' skill branch in modmain.lua for future reference.",
    ],
  },
  {
    version: "2.0.87",
    date: "2026-06-28",
    commit: "526fe36",
    type: "feature",
    title: "Death State Cleanup & Sentry Scaling",
    changes: [
      "All 4 bot stategraphs now call inst:Remove() + Physics:SetActive(false) on death — dead bots no longer persist as ghost entities.",
      "Sentry damage now scales across tiers: MK1=25, MK2=30, MK3=35 (was identical for all tiers).",
      "Bot death announcements: owner receives a speech line when one of their bots dies.",
      "Removed dead WILLYRAISE.fn guard code in william_acts.lua.",
    ],
  },
  {
    version: "2.0.86",
    date: "2026-06-28",
    commit: "55e6030",
    type: "bugfix",
    title: "Ballistic Overcharge & Empty Husk Fixes",
    changes: [
      "CRITICAL: Ballistic MK3 Overcharge now deals 99 damage (was 48 — used base 16 instead of current 33).",
      "CRITICAL: RemoveOvercharge now correctly restores MK3 damage (+17 = 33, was +12 = 28 — permanent -5 DMG bug).",
      "CRITICAL: williambrute_empty prefab is now registered (SG powerdown spawn was returning nil).",
      "Butler OnHammered now calls container:Close() before DropEverything() — fixes client widget bug.",
      "Butler empty husk no longer has container/stewer/cooker tags without matching components.",
      "Removed dead WILLIAM_BALLISTIC_MAXFUEL constant from william_tuning.lua.",
    ],
  },
  {
    version: "2.0.85",
    date: "2026-06-27",
    commit: "15a2b75",
    type: "bugfix",
    title: "Brute Chest Items No Longer Lost on Death",
    changes: [
      "Brute MK3 chest items now drop on the ground when the bot is hammered (was silently destroyed).",
      "Brute MK3 chest items also drop when the bot dies in combat (added 'death' event handler).",
      "Chester Cane and other stored items are now recoverable.",
    ],
  },
  {
    version: "2.0.84",
    date: "2026-06-27",
    commit: "033c46d",
    type: "feature",
    title: "Configurable Crafting Limits",
    changes: [
      "Server admins can now configure crafting limits for sentry guns, dispensers, teleporter entrances, and exits in mod settings.",
      "4 new modinfo.lua config entries: limit_sentry, limit_dispenser, limit_teleporter_entrance, limit_teleporter_exit.",
      "Defaults match previous hardcoded values (sentry=2, dispenser=1, teleporter=2 each) — existing worlds unaffected.",
    ],
  },
  {
    version: "2.0.83",
    date: "2026-06-27",
    commit: "66cdc90",
    type: "bugfix",
    title: "Brute Now Eats Gears for Level-Up",
    changes: [
      "Fixed: Brute bot was storing gears in its chest inventory instead of consuming them for WILLUPGRADE level-ups.",
      "Root cause: container component intercepted gears before willupgrader could process them.",
      "Fix in imports/william_acts.lua — gears now correctly trigger level-up; other items still store normally.",
    ],
  },
];

export const LATEST_VERSION = "2.0.88";
export const MOD_RELEASE_DATE = "2026-06-27";
export const GITHUB_URL = "https://github.com/HIKESS/WagstaffMod";
