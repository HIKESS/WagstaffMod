// WagstaffMod bot data — extracted from imports/william_tuning.lua and prefab files
// All values reflect v2.0.88 of the mod.

export type Tier = "MK1" | "MK2" | "MK3";

export interface BotTierStats {
  tier: Tier;
  hp: number;
  damage: number;
  attackPeriod: number; // seconds
  fuelCapacity: number; // in "fuel units" (segment-time based)
  special?: string;
}

export interface BotInfo {
  id: string;
  name: string;
  role: string;
  tagline: string;
  emoji: string;
  accentColor: string; // tailwind class fragment, e.g. "amber"
  prefabBase: string; // base prefab name
  scrapToMK2: number;
  scrapToMK3: number;
  tiers: BotTierStats[];
  signature: string; // signature ability description
  deathDropsChest: boolean;
}

export const BOTS: BotInfo[] = [
  {
    id: "buster",
    name: "Buster",
    role: "Melee Striker",
    tagline: "Shadow-fueled brawler with explosive punches.",
    emoji: "🥊",
    accentColor: "rose",
    prefabBase: "william_buster",
    scrapToMK2: 85,
    scrapToMK3: 120,
    signature: "At dusk, spawns a shadow clone dealing 50% damage while invincible.",
    deathDropsChest: false,
    tiers: [
      { tier: "MK1", hp: 600, damage: 34, attackPeriod: 2.0, fuelCapacity: 45, special: "Base melee fighter" },
      { tier: "MK2", hp: 750, damage: 40, attackPeriod: 1.8, fuelCapacity: 60, special: "+150 HP, +6 DMG, faster attacks" },
      { tier: "MK3", hp: 900, damage: 46, attackPeriod: 1.6, fuelCapacity: 75, special: "30% explosive punch (+50% DMG, AOE) + dusk shadow clone" },
    ],
  },
  {
    id: "brute",
    name: "Brute",
    role: "Tank / Juggernaut",
    tagline: "Walking chest that taunts enemies and soaks damage.",
    emoji: "🛡️",
    accentColor: "emerald",
    prefabBase: "william_brute",
    scrapToMK2: 75,
    scrapToMK3: 90,
    signature: "MK2+ passively taunts enemies (radius 6/8) to protect the player. MK3 carries a chest inventory.",
    deathDropsChest: true,
    tiers: [
      { tier: "MK1", hp: 1500, damage: 17, attackPeriod: 3.0, fuelCapacity: 60, special: "Tanky but low damage" },
      { tier: "MK2", hp: 2000, damage: 22, attackPeriod: 2.8, fuelCapacity: 75, special: "+500 HP, +5 DMG, taunt radius 6" },
      { tier: "MK3", hp: 2500, damage: 27, attackPeriod: 2.6, fuelCapacity: 90, special: "Chest inventory (drops on death), taunt radius 8" },
    ],
  },
  {
    id: "ballistic",
    name: "Ballistic",
    role: "Ranged Marksman",
    tagline: "Sniper bot with a temporary Overcharge damage boost.",
    emoji: "🎯",
    accentColor: "amber",
    prefabBase: "william_ballistic",
    scrapToMK2: 100,
    scrapToMK3: 150,
    signature: "Overcharge: 3x damage for a short window. MK3 deals 99 dmg/shot during Overcharge.",
    deathDropsChest: false,
    tiers: [
      { tier: "MK1", hp: 250, damage: 16, attackPeriod: 3.0, fuelCapacity: 40, special: "Ranged dart attacks" },
      { tier: "MK2", hp: 300, damage: 28, attackPeriod: 2.5, fuelCapacity: 55, special: "+50 HP, +12 DMG (Overcharge x3 = 84)" },
      { tier: "MK3", hp: 400, damage: 33, attackPeriod: 2.2, fuelCapacity: 70, special: "+100 HP, +5 DMG (Overcharge x3 = 99)" },
    ],
  },
  {
    id: "butler",
    name: "Butler",
    role: "Support / Cook",
    tagline: "Culinary assistant that cooks, heals, and resurrects.",
    emoji: "🎩",
    accentColor: "violet",
    prefabBase: "william_butler",
    scrapToMK2: 55,
    scrapToMK3: 70,
    signature: "MK3: Affinity Pulse buffs allies, celestial light aura, haunt-resurrect on death, +food bonus.",
    deathDropsChest: false,
    tiers: [
      { tier: "MK1", hp: 150, damage: 0, attackPeriod: 0, fuelCapacity: 50, special: "Cooks raw food, follows player" },
      { tier: "MK2", hp: 200, damage: 0, attackPeriod: 0, fuelCapacity: 65, special: "Faster cooking, basic healing" },
      { tier: "MK3", hp: 200, damage: 0, attackPeriod: 0, fuelCapacity: 80, special: "Affinity Pulse + celestial light + resurrect + food bonus" },
    ],
  },
];

// Sentry damage values (per tier)
export const SENTRY_STATS = {
  bullet: { MK1: 25, MK2: 30, MK3: 35 },
  rocket: { MK1: 0, MK2: 0, MK3: 50 }, // rockets only unlock at MK3
};

// Configuration options exposed in modinfo.lua
export interface ConfigOption {
  key: string;
  label: string;
  description: string;
  defaultValue: string | number;
  options: (string | number)[];
}

export const CONFIG_OPTIONS: ConfigOption[] = [
  {
    key: "limit_sentry",
    label: "Sentry Gun Limit",
    description: "Maximum number of sentry guns a single player can build.",
    defaultValue: 2,
    options: [1, 2, 3, 4, 5, 6, 8, 10, "Unlimited"],
  },
  {
    key: "limit_dispenser",
    label: "Dispenser Limit",
    description: "Maximum number of dispensers a single player can build.",
    defaultValue: 1,
    options: [1, 2, 3, 4, 5, "Unlimited"],
  },
  {
    key: "limit_teleporter_entrance",
    label: "Teleporter Entrance Limit",
    description: "Maximum number of teleporter entrances a single player can build.",
    defaultValue: 2,
    options: [1, 2, 3, 4, 5, "Unlimited"],
  },
  {
    key: "limit_teleporter_exit",
    label: "Teleporter Exit Limit",
    description: "Maximum number of teleporter exits a single player can build.",
    defaultValue: 2,
    options: [1, 2, 3, 4, 5, "Unlimited"],
  },
];

// Fuel thresholds for low-fuel warnings (added v2.0.88)
export const FUEL_THRESHOLDS = {
  warning: 0.2, // 20% — "running low on fuel"
  critical: 0.1, // 10% — "about to shut down"
  reset: 0.25, // refuel above 25% resets warnings
};
