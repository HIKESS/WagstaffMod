---
Task ID: BAL-A
Agent: Explore (balance analysis)
Task: Research balance issues across bots/sentry/teleporter/skills in WagstaffMod

Work Log:
- Read /home/z/ds-work/WagstaffMod/ imports/william_tuning.lua to extract base bot stats (HP/DMG/fuel/regen constants).
- Grepped william_butler.lua, william_buster.lua, william_brute.lua, william_ballistic.lua for SetMaxHealth / SetDefaultDamage / fueled / scrap / upgradelevel to build per-tier stat tables.
- Found MK2/MK3 upgrade scrap costs by reading the engieworkable OnFinishCallback in each bot prefab:
    Butler MK1->MK2 = 55 scraps (10+10+10+10+15); MK2->MK3 = 70 scraps (5/hit x14)
    Buster MK1->MK2 = 85 scraps (5/hit x17);        MK2->MK3 = 120 scraps (5/hit x24)
    Brute  MK1->MK2 = 75 scraps (5/hit x15);        MK2->MK3 = 90 scraps (5/hit x18)
    Ballistic MK1->MK2 = 100 scraps (5/hit x20);    MK2->MK3 = 150 scraps (5/hit x30)  <-- highest in mod
- Confirmed Brute MK3 (fn3 line 1290-1294) EXPLICITLY reverts HP/DMG back to MK2 values: HP 2500, DMG 27 — comment at line 1277 says "+2000 HP, +20 DMG" but code overrides.
- Confirmed Ballistic MK3 (active3 line 1015 comment "inherits MK2 stats") has HP 400, DMG 28 — IDENTICAL to MK2.
- Confirmed Butler MK3 (active3) inherits active2 stats — HP 200, no combat damage; MK3 only adds AffinityPulse + celestial light + haunt-resurrect + food bonus.
- Confirmed Buster MK3 (active3 line 1031-1033): HP 900, DMG 46; adds 30% chance explosive punch (+50% dmg + AOE) + shadow clone (50% dmg, invincible) at dusk.
- Found Buster LevelUp bug (line 204): SetDefaultDamage(BUSTER_DAMAGE + level*3) OVERWRITES MK2/MK3 damage boost — leveling an MK3 Buster to lvl3 reduces damage from 46 to 45.
- Read esentry.lua (lines 144-176, 230-270, 551-558, 599-653): SENTRY_HEALTH=300, SENTRY_DAMAGE=25, SENTRY_ROF=1.5s, SENTRY_RANGE=12. MK2 (lvl 30) doubles HP to 600; MK3 (lvl 70) triples HP to 900 + enables rockets (50 dmg). Damage stays 25 across all levels. x2_damage skill: 15% chance +base_dmg extra (esentry.lua line 617-620, 631-634, 645-647).
- Read eteleporter.lua + eteleporter_exit.lua + components/engieteleporter.lua: NO cooldown, NO range limit, ETELEPORT_PENALTY=0 (modmain.lua line 548), ENGIE_BUILDINGLOSS/1.5=10 sanity lost only when teleporter destroyed. The OnActivate function that would apply sanity cost (eteleporter.lua line 213-224) is COMMENTED OUT.
- Read skilltree_wagstaff.lua fully: ALL skills cost 1 insight. Three branches (mechanical/robotic/allegiance). No "gadgets" branch exists in skilltree_wagstaff.lua, BUT modmain.lua lines 3399-3533 and wagstaff_skilltree_impl.lua reference wagstaff_calibrated_wrench / wagstaff_stabilized_portals / wagstaff_efficient_refineries / wagstaff_gadgets_5 / wagstaff_gadgets_6 tags — these skill effects are coded but the skills themselves are NOT in the tree (orphaned/dead code).
- Read modmain.lua lines 2250-2263 (WagstaffMechanicalEfficiencyRoll), 4015-4041 (finiteuses interception), 4044-4070 (fueled interception): wagstaff_mechanical_efficiency tag grants THREE separate bonuses — 30% free scrap on all upgrades/repairs, 15% reduced wrench durability, 15% chance free fuel.
- Read modmain.lua lines 3259-3376: extracted all recipe costs and tech levels.
- Read standalone_prefabs.lua lines 785-811: TF2 Wrench has 50 finiteuses, 59.5 weapon damage, recipe = 5 scrap + 3 twigs.
- Read dispenser.lua lines 160-265: confirmed v2.0.14 buff — Dispenser MK3 celestial = SANITYAURA_MED (100/min), shadow = 2 HP/0.5s = 4 HP/sec heal (builder only, range 4).
- Verified bot_aura_v2/v3/v4/v5 + affinity_pulse.lua are PURELY VISUAL FX (light + particle color tints) — no gameplay stats applied by the aura FX prefabs themselves. The actual gameplay effects come from each bot's own DoPeriodicTask handlers (counter-attack on hit, food bonus, etc.).

Stage Summary:

=========================================================================
COMPARISON TABLES
=========================================================================

TABLE 1 — Bot/Structure Stats Per Tier (HP / DMG / Fuel / Scrap Cost)
=========================================================================
Entity      | MK1                  | MK1->MK2 cost | MK2                  | MK2->MK3 cost | MK3                  | MK3 vs MK2 stat delta
------------|----------------------|---------------|----------------------|---------------|----------------------|----------------------
Butler      | HP 200, DMG 0, F 32m | 55 scrap      | HP 200, DMG 0, F 32m | 70 scrap      | HP 200, DMG 0, F 32m | +0 HP / +0 DMG (no stat gain at any tier)
Buster      | HP 300, DMG 36, F 24m| 85 scrap      | HP 600, DMG 41, F 24m| 120 scrap     | HP 900, DMG 46, F 24m| +300 HP / +5 DMG (scales linearly)
Brute       | HP 1500, DMG 17, F 40m| 75 scrap     | HP 2500, DMG 27, F 40m| 90 scrap     | HP 2500, DMG 27, F 40m| +0 HP / +0 DMG (CODE EXPLICITLY REVERTS — line 1290-1294)
Ballistic   | HP 150, DMG 16*, F ~18m**| 100 scrap | HP 400, DMG 28*, F ~18m| 150 scrap   | HP 400, DMG 28*, F ~18m| +0 HP / +0 DMG (comment line 1015 confirms "inherits MK2 stats")
Sentry      | HP 300, DMG 25, ROF 1.5s| 30 scrap   | HP 600, DMG 25, ROF 1.5s| 40 scrap    | HP 900, DMG 25, ROF 1.5s + rockets 50| +300 HP / +0 DMG base (rockets only)
Dispenser   | max fuel 4 (day)    | 30 scrap      | max fuel 6 (day+dusk)| 40 scrap      | max fuel 10 (full)   | +4 max fuel + affinity auras

* Ballistic damage is electric (x1.5 vs most mobs) so effective DMG = 24 (MK1) / 42 (MK2/MK3).
** Ballistic fuel uses WINONA_BATTERY_LOW_MAX_FUEL_TIME * 5, NOT the WILLIAM_BALLISTIC_MAXFUEL constant (which is defined but unused — 3630s would be ~60 min).

Fuel durations: seg_time=30s, 16 segs/day = 480s/day. WILLIAM_BUTLER_MAXFUEL=1920s, BUSTER=1440s, BRUTE=2400s. All bots keep same fuel across MK tiers (only Dispenser scales fuel).


TABLE 2 — MK3 Affinity Aura Effects (Celestial Day / Shadow Dusk)
=========================================================================
Bot/Struct  | Celestial (Day + celestial_possession tag)              | Shadow (Dusk + shadow_possession tag)
------------|---------------------------------------------------------|----------------------------------------------------------
Butler MK3  | Cooked food heals +40% of hunger as HP% when eaten;     | Cooked food restores +40% of hunger as sanity% when eaten;
            | +20% max HP bonus on ghost-revive (one-time, bot dies)  | +30% max sanity bonus on ghost-revive (one-time, bot dies)
Buster MK3  | 30% on-hit AOE light explosion (30% dmg to adjacent    | Spawns invincible shadow clone dealing 50% of parent damage,
            | enemies within 3 units); +light aura                    | follows parent, despawns at dusk end
Brute MK3   | Counter-attack 30 fire dmg to attacker when hit;        | Counter-attack 15 shadow dmg to attacker; AOE debuff enemies
            | +planar immunity tag; +light aura                       | -50% damage for 4s (8s cooldown, radius 6); +planar immunity; +shadowlure
Ballistic MK3| Brightshade projectile every 15s (0.6 x base = 9.6 dmg)| Fuelweaver Snare every 15s, snares up to 3 enemies in radius 15
Sentry MK3  | +10% damage to shadow_aligned enemies (onhit hook)     | +10% damage to lunar_aligned enemies (onhit hook)
            | (x2_damage skill: 15% chance +100% base dmg, ALL times) | (x2_damage skill: 15% chance +100% base dmg, ALL times)
Dispenser MK3| **Sanity aura MED = 100/min** (was SMALL 50/min)      | **HP heal 2 HP/0.5s = 4 HP/s = 240 HP/min** (builder only, range 4)
(recently    | Always-on passive aura while in range                  | Always-on passive aura while in range
 buffed)    |                                                         |

Key observation: Dispenser MK3 auras are ALWAYS-ON PASSIVE. All bot MK3 auras are SITUATIONAL (combat, food eaten, hit taken, 15s cooldown). The Dispenser's 100 sanity/min or 240 HP/min massively overshadows the bots' effects.


TABLE 3 — Skill Tree (All skills cost 1 insight)
=========================================================================
Branch      | Skill                                | Effect
------------|--------------------------------------|-----------------------------------
mechanical  | wagstaff_mechanical_1 (ROOT)         | Mechanical Efficiency: 30% free scrap + 15% less wrench wear + 15% free fuel
            | wagstaff_sentry_mk2                  | Unlocks Sentry MK2 (lvl 30)
            | wagstaff_sentry_mk3                  | Unlocks Sentry MK3 (lvl 70)
            | wagstaff_x2_damage                   | Sentry 15% chance double damage
            | wagstaff_dispenser_mk2               | Unlocks Dispenser MK2 (lvl 30)
            | wagstaff_dispenser_mk3               | Unlocks Dispenser MK3 (lvl 70)
            | wagstaff_lucky_engineer              | Dispenser chance for rare resource
robotic     | wagstaff_robotic_1 (ROOT)            | Unlocks Brute MK2
            | wagstaff_robotic_1_parallel          | Unlocks Brute MK3
            | wagstaff_buster_evolve               | Unlocks Buster MK2
            | wagstaff_buster_parallel             | Unlocks Buster MK3
            | wagstaff_ballistic_evolve            | Unlocks Ballistic MK2
            | wagstaff_ballistic_parallel          | Unlocks Ballistic MK3
            | wagstaff_thermal_upgrade             | Unlocks Butler MK2
            | wagstaff_thermal_upgrade_parallel    | Unlocks Butler MK3
allegiance  | wagstaff_shadow_possession (LOCKED)  | Shadow affinity (requires Fuelweaver kill)
            | wagstaff_celestial_possession (LOCKED)| Celestial affinity (requires Celestial Champion kill)

NOTE: 5 orphaned skill effects coded in modmain.lua (wagstaff_calibrated_wrench, wagstaff_stabilized_portals, wagstaff_efficient_refineries, wagstaff_gadgets_5, wagstaff_gadgets_6) have NO corresponding skill nodes in skilltree_wagstaff.lua — they are unreachable dead code.


TABLE 4 — Recipe Costs
=========================================================================
Item                       | Cost                                         | Tech
---------------------------|----------------------------------------------|-------------
scrap (crafts 5)           | 2 flint + 2 twigs                            | NONE
tf2wrench (50 uses, 59.5 dmg)| 5 scrap + 3 twigs                          | NONE
williamgadget              | 2 gears + 1 goldnugget                       | NONE
esentry                    | 20 scrap + 3 gears                           | MAGIC_ONE
dispenser                  | 15 scrap + 3 redgem                          | SCIENCE_TWO
eteleporter (entrance)     | 30 scrap + 5 gears + 5 transistor            | MAGIC_TWO
eteleporter_exit           | 25 scrap + 3 gears + 3 transistor            | MAGIC_TWO
williambutler_builder      | 1 williamgadget + 4 boards + 2 transistor    | SCIENCE_ONE
williambuster_builder      | 1 williamgadget + 3 marble + 2 transistor    | MAGIC_ONE
williambrute_builder       | 1 williamgadget + 4 cutstone + 2 transistor  | SCIENCE_TWO
williamballistic_empty     | 1 williamgadget + 4 nitre + 2 transistor     | MAGIC_TWO


TABLE 5 — Tuning Constants (modmain.lua + william_tuning.lua)
=========================================================================
Constant                     | Value      | Notes
-----------------------------|------------|--------
WILLIAM_BALLISTIC_HEALTH     | 150        |
WILLIAM_BALLISTIC_DAMAGE     | 24/1.5=16  | electric, x1.5 vs mobs = 24 effective
WILLIAM_BALLISTIC_MAXFUEL    | 3630s      | UNUSED — code uses WINONA_BATTERY_LOW_MAX_FUEL_TIME * 5
WILLIAM_BUSTER_HEALTH        | 300        |
WILLIAM_BUSTER_DAMAGE        | 36         |
WILLIAM_BUSTER_MAXFUEL       | 1440s      |
WILLIAM_BUTLER_HEALTH        | 200        |
WILLIAM_BUTLER_DAMAGE        | 30         | DEPRECATED — not used (butler has no combat)
WILLIAM_BUTLER_MAXFUEL       | 1920s      |
WILLIAM_BRUTE_HEALTH         | 1500       |
WILLIAM_BRUTE_DAMAGE         | 17         | very low for a "tank/juggernaut" role
WILLIAM_BRUTE_MAXFUEL        | 2400s      |
WILLIAM_ROBOT_REGEN          | 5 HP / 5s  | = 1 HP/s passive regen for all bots
SENTRY_HEALTH                | 300        | MK2=600, MK3=900 (only HP scales)
SENTRY_DAMAGE                | 25         | STAYS 25 across all tiers
SENTRY_RANGE                 | 12         |
SENTRY_ROF                   | 1.5s       | attack period
SENTRY_ROCKET_DAMAGE         | 50         | MK3 only
SENTRY_WRENCH_HEAL           | 10 HP/hit  | repair per wrench swing
ETELEPORT_PENALTY            | 0          | NO sanity cost on teleport (OnActivate code commented out)
ENGIE_BUILDINGLOSS           | 15 sanity  | sentry death; teleporter uses /1.5 = 10
DISP_HEALING                 | 0.5s       | dispenser heal tick interval
DISP_RANGE                   | 4          | dispenser aura radius
TOOLBOX_SPEED_MULT           | 0.15       | 85% speed penalty when carrying sentry (heavy)
TF2_WRENCH_MAXUSES           | 50         | 50 hits per wrench (standalone_prefabs.lua line 806)


=========================================================================
TOP 8 BALANCE ISSUES (ranked by severity)
=========================================================================

#1 (HIGH) — Ballistic MK3 costs 150 scraps but adds ZERO stat gain
  What: Ballistic MK2 -> MK3 = 150 scraps (5/hit x 30 hits, HIGHEST in mod).
        MK3 HP 400 / DMG 28 — IDENTICAL to MK2 (william_ballistic.lua line 1015 confirms).
        The 150 scraps only buys: Overcharge (3x DMG + 500 HP + 3x attack rate, 60s, 1/day from
        invoked lightning only), chain lightning on hit, rain splash, and 15s-cooldown affinity.
  Why bad: MK1->MK2 = 100 scraps for +250 HP / +12 DMG (huge boost). MK2->MK3 = 50% MORE scraps
        (150) for ZERO stats. The Overcharge is strong but requires Tempest Call + rain + only
        60s/day. Affinity projectile is 9.6 dmg/15s = ~38 dmg/min (negligible). Players will feel
        cheated paying 150 scraps for an ability-only upgrade.
  Fix: Add modest stat boost to MK3 — +100 HP (->500) and +5 DMG (->33). OR reduce scrap cost
        from 150 to 100 to match MK1->MK2. Either makes the upgrade feel rewarding. No FX change,
        no tree reordering.

#2 (HIGH) — Brute MK3 costs 90 scraps but adds ZERO stat gain (CODE EXPLICITLY REVERTS)
  What: Brute MK2 -> MK3 = 90 scraps. MK3 HP 2500 / DMG 27 — IDENTICAL to MK2. The fn3 function
        (william_brute.lua line 1290-1294) EXPLICITLY reverts HP/DMG back to MK2 values, even
        though the comment at line 1277 says "+2000 HP, +20 DMG". The 90 scraps only buys: storage
        chest, AffinityPulse visual, situational counter-attacks (30 fire / 15 shadow dmg when
        hit), planar immunity, AOE -50% dmg debuff (8s cooldown).
  Why bad: Same inverted value as Ballistic. Brute has 2500 HP so it rarely gets hit, making the
        counter-attack effects mostly irrelevant in normal play. The MK3 is functionally a MK2
        with a chest. The comment suggests the original intent was a much bigger boost — this is
        likely a regression.
  Fix: Restore even a fraction of the commented boost — +500 HP (->3000) and/or +5 DMG (->32).
        Brute is supposed to be the tank/juggernaut; 2500 HP at MK3 feels stagnant.

#3 (HIGH) — Buster LevelUp function OVERWRITES MK2/MK3 damage boost (regression bug)
  What: william_buster.lua line 204 — LevelUp sets SetDefaultDamage(BUSTER_DAMAGE + level*3).
        This OVERWRITES the MK2 boost (+5, line 760) and MK3 boost (+10, line 1033).
        Consequence: a Buster MK3 leveled to lvl3 has DMG = 36+9 = 45, which is LESS than the
        un-leveled MK3's 46. Leveling up your fully-upgraded Buster actively makes it WORSE.
  Why bad: Players who feed items to their MK3 Buster to "level it up" get punished with -1 DMG.
        Counter-intuitive and undocumented.
  Fix: Change LevelUp to stack on top of MK boost, e.g.
        SetDefaultDamage(BUSTER_DAMAGE + (inst:HasTag("buster_upgraded_mk3") and 10 or
        (inst:HasTag("buster_upgraded") and 5 or 0)) + inst.level*3). No FX change.

#4 (MEDIUM-HIGH) — E-Teleporter has NO sanity cost AND NO cooldown (free unlimited travel)
  What: TUNING.ETELEPORT_PENALTY = 0 (modmain.lua line 548). The OnActivate function that would
        apply sanity cost (eteleporter.lua line 213-224) is COMMENTED OUT. The ENGIETELEPORT
        action (modmain.lua line 1473) does DoDelta(-(TUNING.ETELEPORT_PENALTY or 0)) = 0.
        The engieteleporter component (engieteleporter.lua) has NO cooldown timer.
  Why bad: 55 scraps + 8 gears + 8 transistors to build the pair, then ZERO cost infinite fast-
        travel. Trivializes map exploration, boss kiting (teleport mid-fight), and resource
        gathering. Compare to wormholes (sanity cost) or Lazy Explorer (limited uses). Wagstaff's
        own vanilla Telipad/Telebrella has sanity cost.
  Fix: Set TUNING.ETELEPORT_PENALTY = 5 (5 sanity per teleport — small but non-zero). OR add a
        10s cooldown to the engieteleporter component. The sanity cost is the most conservative
        fix and aligns with DST's "no free lunch" design for fast travel.

#5 (MEDIUM) — Mechanical Efficiency skill (1 insight, root) is too broad/strong
  What: wagstaff_mechanical_1 grants tag wagstaff_mechanical_efficiency, which triggers THREE
        separate broad interceptions in modmain.lua:
          - line 2253-2263: 30% chance ALL scrap costs (repair/upgrade for ALL bots/sentry/
            dispenser) become 0
          - line 4015-4041: 15% reduced finiteuses consumption on EVERY Use() call (wrench, etc.)
          - line 4044-4070: 15% chance to NOT consume fuel items when refueling
  Why bad: For 1 insight at the ROOT of the tree, this skill pays for itself almost immediately
        and scales infinitely. A Buster MK3 upgrade (120 scraps) averages to 84 scraps. Wrench
        effectively gains 65 uses. Fuel lasts 18% longer. Three bonuses for one skill point is
        too much — it's an always-on 15-30% discount on the entire engineer economy.
  Fix: Reduce the scrap-free chance from 30% -> 20% (still strong but less swingy). OR keep 30%
        scrap roll but remove the 15% fuel-free roll (fuel is already cheap and abundant). The
        wrench durability discount is negligible in practice (Use(1) floors to 1 anyway) — leave
        it. NO tree reorder, NO FX change.

#6 (MEDIUM) — x2 Damage sentry skill (1 insight, capstone) may be underpriced
  What: wagstaff_x2_damage gives Sentry 15% chance on every hit to deal +100% base damage
        (esentry.lua lines 617-620, 631-634, 645-647). Stacks with +10% celestial/shadow bonus.
        Sentry fires every 1.5s = 6.7 hits/5s, so ~1 doubled-damage hit per 5s on average.
        Effective +15% DPS for 1 insight, positioned as capstone after sentry_mk2 + sentry_mk3.
  Why bad: +15% DPS on a turret that already does 25 * 6.7 = 167 DPS is a meaningful buff. The
        skill costs the same 1 insight as the prerequisite skills (sentry_mk2, sentry_mk3), but
        it's a stronger per-point value because it scales with hit rate. Borderline — not
        game-breaking but feels underpriced relative to other 1-insight skills.
  Fix: Conservative options (pick one): (a) reduce proc chance 15% -> 10%, OR (b) reduce bonus
        from +100% to +75% (so proc = 1.75x). Either brings the average DPS gain to ~10%, more
        in line with 1-insight skills. NO tree reorder.

#7 (MEDIUM) — Dispenser MK3 auras (recently buffed) overshadow all 4 bots' MK3 affinity effects
  What: v2.0.14 buffed Dispenser MK3 auras to: Celestial day = SANITYAURA_MED (100/min, was 50);
        Shadow dusk = 4 HP/sec heal = 240 HP/min (builder only, range 4). These are ALWAYS-ON
        PASSIVE during the affinity phase. By contrast, the 4 bots' MK3 affinity effects are
        situational or weak:
          - Butler MK3: requires eating food (one-time per food)
          - Buster MK3: requires landing hits (combat-only)
          - Brute MK3: requires being hit (rare due to 2500 HP)
          - Ballistic MK3: 9.6 dmg projectile every 15s = 38 dmg/min (negligible)
  Why bad: The Dispenser is a UTILITY building (gives scrap/fuel/minerals) AND now has the
        strongest recovery auras in the mod. Players will stack Dispensers instead of using bot
        MK3 paths. The 4 bots cost 90-150 scraps to upgrade to MK3 but their affinity effects are
        weaker than a single Dispenser MK3 (40 scraps).
  Fix: Do NOT nerf Dispenser (buff was intentional). Instead, bring bots up to competitiveness:
          - Ballistic MK3 celestial: increase projectile from 0.6x to 1.0x base (16 dmg) OR
            reduce cooldown 15s -> 8s
          - Brute MK3 celestial: increase counter-attack 30 -> 50 dmg, OR add small persistent
            taunt
          - Butler MK3: add small always-on sanity aura (e.g., 25/min) in addition to food bonus
          - Buster MK3: increase AOE explosion 30% -> 50% of hit damage
        All conservative number tweaks, no FX or tree changes.

#8 (LOW-MEDIUM) — Butler MK2 -> MK3 costs 70 scraps for no stat gain, only affinity + haunt-revive
  What: Butler MK2 -> MK3 = 70 scraps (5/hit x 14 hits). MK3 HP 200, no combat damage — SAME as
        MK1/MK2. The 70 scraps buys: AffinityPulse visual, celestial light, haunt-resurrect (one-
        time use — bot dies on revive, gives +20% HP / +30% sanity to revived player), and
        celestial/shadow food-cooking bonus.
  Why bad: Butler is the cheapest MK1->MK2 (55 scraps), but MK2->MK3 (70 scraps) is relatively
        expensive for a non-combat bot. The haunt-resurrect is a single-use extra life; the food
        bonus is situational (player must eat food cooked by butler during the affinity phase).
        Compare to Brute MK3 (90 scraps) which at least gets a chest + counter-attacks on a 2500
        HP tank body.
  Fix: Reduce Butler MK2->MK3 cost from 70 -> 50 scraps (matching MK1->MK2). OR add a small HP
        boost to MK3 (+100 HP -> 300) so it survives longer as a follower. The food bonus is
        good but situational — the cost should reflect that.


=========================================================================
ADDITIONAL OBSERVATIONS (not ranked — context for future balance passes)
=========================================================================

A. Orphaned "gadgets" skill branch — modmain.lua references 5 gadget skill tags
   (wagstaff_calibrated_wrench, wagstaff_stabilized_portals, wagstaff_efficient_refineries,
   wagstaff_gadgets_5, wagstaff_gadgets_6) but skilltree_wagstaff.lua has NO corresponding skill
   nodes. These effects (half wrench durability, free refinery inputs, dispenser extra item,
   reduced teleporter sanity) are unreachable dead code. Either add the gadgets branch to the
   skill tree, or remove the orphaned code.

B. Buster's LevelUp also overwrites absorption correctly (line 202) — that one is consistent
   across MK tiers. Only the damage override is a bug.

C. Brute base damage (17) is very low for a "tank/juggernaut" — even MK3 (27) is weaker than
   Buster MK1 (36). Consider Brute's role: it has 1500-2500 HP and is meant to soak damage, but
   its low damage means enemies don't focus it. Not a balance emergency but a role clarification
   concern.

D. SENTRY_DAMAGE stays 25 across all 3 tiers — only HP and ammo capacity scale. Rockets (50 dmg
   on MK3) are the only damage increase. Consider a small MK2/MK3 damage bump (+5 / +10) to make
   the upgrade path feel rewarding, OR keep as-is if the intent is "sentry is for tanking, not
   DPS."

E. WINONA_BATTERY_LOW_MAX_FUEL_TIME * 5 (used by Ballistic) is a vanilla DST constant (~216s *
   5 = ~1080s = ~18 min). The defined-but-unused WILLIAM_BALLISTIC_MAXFUEL = 3630s (~60 min) in
   william_tuning.lua appears to be leftover from a previous design where Ballistic had a much
   larger battery. Either use the constant or remove it.

F. Wrench skill "Calibrated Wrench" (orphaned, see observation A) at line 3413 sets
   num = math.max(0, math.floor(num * 0.5)) — this would make Use(1) = 0, effectively giving
   infinite wrench durability. If this skill is ever activated, it would break the wrench
   economy entirely. Flag for review.

G. The "+15% chance free fuel" interception (modmain.lua line 4046-4070) sets bonus_ratio = 0
   to skip consumption — this is a hack that may interact badly with stackable fuel items.
   Worth testing before relying on it as a balance lever.

H. Teleporter ENGIE_BUILDINGLOSS uses /1.5 divisor (10 sanity) vs sentry's full 15. This is the
   only asymmetric building-loss value. Minor inconsistency but not a balance problem.

End of BAL-A report.

---
Task ID: V2017-REVIVE
Agent: GLM (main)
Task: v2.0.17 — Fix Butler shadow affinity REVIVE bug + rework celestial revive (full discharge + soul FX)

Work Log:
- Cloned https://github.com/HIKESS/DontStarve-logs.git and analyzed master_server_log.txt / client_log.txt.
- Found a Lua error in the logs: skilltree_wagstaff.lua:411 — `_WAGSTAFF_LOCK_LOGGED_FUELWEAVER` undeclared (strict.lua crash). This was ALREADY FIXED in current repo (line 23 declares `local _lock_logged_fuelweaver = false`). The logs were from an older build before that fix. This crash blocked the skill tree UI → player could not activate shadow/celestial possession → no affinity tags → revive affinity never fired.
- Confirmed wrench damage (59.5→30, below spear=34) and modicon (wagstaffgamelist icon + xml fix) were ALREADY done in commit 2f69a98. Only debug logs for COOK affinity were added there (wrong target — user clarified the bug is the REVIVE, not the cook).
- Root cause of shadow revive bug: in william_butler.lua the haunt fn checked affinity tags ONLY via `GetOwner(inst)` (follower:GetLeader()). When the owner is DEAD (ghost), the follower leader link can be nil → OwnerHasShadow/OwnerHasCelestial returned false → butler always died (default path).
- FIX: now check tags on BOTH owner AND haunter (the ghost player attempting revive). The haunter is always valid and its affinity tags persist through death. This was the root cause of "shadow affinity revive doesn't work".
- CELESTIAL revive rework (per user request):
  * Bot now FULLY DISCHARGES (fuel → 0) as the cost of revive. DowngradeButlerToMK1 gained a `discharge` param; celestial path calls it with discharge=true → new MK1 spawns with currentfuel=0 (inert, must be refueled).
  * Replaced generic `small_puff` FX with a celestial "soul leaving" combination: ghostlyelixir_shield_fx (white-blue shield, matches MK3 menu affinity FX) + sparklefx (ascending sparkles = soul rising) + a manually-created celestial light flash (white-blue, fades over 1.2s). Deliberately NOT shadow/dark FX.
- Added comprehensive [BUTLER REVIVE] debug print() logs at every branch (haunt entry, owner/shadow/celestial values, shadow effigy_found, celestial cooldown, which path taken). This mirrors the [BUTLER COOK] debug logs already added in 2f69a98, so the user's next test will reveal exactly where any remaining issue is.
- Verified Lua syntax with luaparse (node): SYNTAX OK.

Stage Summary:
- Files changed: scripts/prefabs/william_butler.lua (revive block lines 1123-1333 rewritten).
- NOT touched: cook affinity code (lines 180-270) — confirmed working, left intact per user instruction.
- modinfo.lua already at version 2.0.17 (from commit 2f69a98); this commit completes the v2.0.17 revive fix.
- Remaining for user: (1) pull latest, (2) open skill tree & activate shadow/celestial possession, (3) die, haunt Butler MK3, (4) share logs — the [BUTLER REVIVE] prints will confirm which path executes.
- Pending Phase 2 (8 balance fixes) and Phase 3 (skill tree reorder + Butler revive rework details) still approved but not yet implemented.

---
Task ID: V2017-REVIVE-PUSH
Agent: GLM (main)
Task: Push v2.0.17 butler revive fix to remote (re-applied after sandbox reset)

Work Log:
- Sandbox was reset between sessions: /home/z/ds-work/WagstaffMod was wiped. Local commit 06abc22 (from previous session) was lost.
- Re-cloned WagstaffMod on GLM-5.1-Fixes branch — remote was at 2f69a98 (my fix was NOT there).
- Re-applied the exact same butler revive fix (tag check on owner+haunter, celestial full discharge + soul FX, debug logs) to scripts/prefabs/william_butler.lua.
- Re-applied the guide updates (v2.0.17 changelog + revive section rewrite) to BOTS_SENTRIES_DISPENSERS_GUIDE.md.
- Committed as 1444009.
- First push attempt via http.extraheader failed ("invalid credentials") due to creds embedded in clone URL conflicting with the extraheader.
- FIX: reset remote URL to clean (no creds), verified PAT validity via GitHub API (HTTP 200), pushed via URL-embedded x-access-token auth: SUCCESS (2f69a98..1444009).
- Post-push security: reset remote URL to clean https://github.com/HIKESS/WagstaffMod.git, unset WAGSTAFF_PAT env var, PAT NOT saved to git config.
- Verified via ls-remote: remote GLM-5.1-Fixes is now at 1444009.

Stage Summary:
- v2.0.17 butler revive fix is now LIVE on remote GLM-5.1-Fixes (commit 1444009).
- User should: (1) pull latest, (2) REVOKE the PAT on GitHub (it was pasted in chat — regenerate it), (3) test the revive in-game, (4) share logs — [BUTLER REVIVE] prints will confirm which path runs.
- Pending: Phase 2 (8 balance fixes) and Phase 3 (skill tree reorder details) still approved but not yet implemented.

---
Task ID: V2017-DEBUG-GATE
Agent: GLM (main)
Task: Gate all debug print() calls behind the mod's "Debug mode" config button

Work Log:
- Found existing debug infrastructure in modmain.lua: G.WagstaffDebugEnabled (reads modinfo "debug" config), G.WagstaffDebug() (heavy helper with tableToString + prefix), G.c_wagstaff_debug() (runtime console toggle), and the "Debug mode" button in modinfo configuration_options (default OFF).
- Problem: my debug prints ([BUTLER COOK], [BUTLER REVIVE], [DEBUG UPGRADE], [DEBUG], [SKILL DEBUG], [Wagstaff LOCK]) used print() directly — ignoring the button, so they ran (and spammed logs) even when debug was OFF.
- Added two LIGHTWEIGHT helpers to modmain.lua (after the existing WagstaffDebug alias, ~line 258):
    G.WagstaffDbg(...)   — early-returns when debug OFF, else print(...) with same args
    G.WagstaffDbgF(fmt, ...) — early-returns when debug OFF, else print(string.format(fmt, ...))
  Both do a single boolean check first, so zero I/O / zero formatting cost when OFF.
- Added local aliases at the top of each prefab file (after assets block):
    local _dbg  = _G.WagstaffDbg  or function(...) end  -- fallback noop if modmain not loaded
    local _dbgF = _G.WagstaffDbgF or function(...) end
- Converted ALL debug prints (164 total) across 5 files:
    william_butler.lua:    45 prints ([BUTLER COOK] 5, [BUTLER REVIVE] 8, [DEBUG UPGRADE] 32)
    william_buster.lua:    23 prints ([DEBUG])
    william_brute.lua:     25 prints ([DEBUG])
    william_ballistic.lua: 24 prints ([DEBUG])
    skilltree_wagstaff.lua: 37 prints ([SKILL DEBUG] 35, [Wagstaff LOCK] 2)
  Format-style prints (print(string.format(...))) → _dbgF(fmt, ...) so string.format is also skipped when OFF.
  Direct prints (print("[TAG] ...", args)) → _dbg("[TAG] ...", args).
- Verified with luaparse: ALL 6 files (5 prefabs + modmain) SYNTAX OK.
- Verified alias defined BEFORE first use in every file (line number comparison).
- Verified no debug-tagged prints remain using print() directly.
- Legitimate non-debug prints (modmain error/info messages, [Wagstaff Debug] prefix prints) were NOT touched.

Stage Summary:
- All debug logging is now gated by the "Debug mode" button in the mod config menu (default OFF = zero cost).
- Runtime toggle still works: c_wagstaff_debug() in console flips G.WagstaffDebugEnabled on/off.
- Debugs are PRESERVED (not removed) for future diagnosis — just silenced unless explicitly enabled.
- Behavior when ON is identical to before (same tags, same output, same log location).
- Files changed: modmain.lua (helpers), william_butler.lua, william_buster.lua, william_brute.lua, william_ballistic.lua, skilltree_wagstaff.lua (aliases + print→_dbg/_dbgF conversions).

---
Task ID: V2017-DEBUG-GATE-PUSH
Agent: GLM (main)
Task: Push debug gating commit to remote

Work Log:
- Committed as d475fd3 locally.
- Push rejected: remote GLM-5.1-Fixes had advanced (merges from main + commit 0223cf6 "fix: correct in-game mod icon + remaining hover display values").
- Fetched remote, inspected divergence: remote had 4 commits I didn't have; I had 1 commit remote didn't have.
- Checked 0223cf6 — it touched william_ballistic.lua and william_buster.lua hover values (different lines from my debug print conversions), so no conflict expected.
- Rebased d475fd3 onto FETCH_HEAD: clean, no conflicts. Commit rebased to 637f386.
- Verified syntax of all 6 files after rebase: ALL OK.
- Pushed 637f386 to origin/GLM-5.1-Fixes: SUCCESS (1b0119b..637f386).
- Post-push security: reset remote URL to clean (no creds), unset WAGSTAFF_PAT env var.

Stage Summary:
- v2.0.17 debug gating is now LIVE on remote GLM-5.1-Fixes (commit 637f386).
- All 164 debug prints across the mod are now gated by the "Debug mode" config button (default OFF = zero cost).
- PAT still valid (was NOT revoked despite being pasted in chat previously) — user should still revoke it for safety.

---
Task ID: V2017-STRING-UNKNOWN-FIX
Agent: GLM (main)
Task: Fix "STRING UNKNOWN" broken text when hammering dispenser/sentry/teleporter

Work Log:
- User reported: when hammering the dispenser or teleporter entrance/exit, the character says broken text like "string unknown".
- Investigated onhammered/ondeath callbacks in:
    dispenser.lua:343        — calls GetString(v, "ANNOUNCE_DISPENSER_DOWN")
    esentry.lua:432 (ondeath) — calls GetString(v, "ANNOUNCE_SENTRY_DOWN")
    eteleporter.lua:140      — calls GetString(v, "ANNOUNCE_TELEPORTER_DOWN")
    eteleporter_exit.lua:128 — calls GetString(v, "ANNOUNCE_TELEPORTER_DOWN")
- Grepped the entire mod for these 3 ANNOUNCE_*_DOWN keys: NONE were defined anywhere.
  The existing ANNOUNCE_*BUILT strings (DISPENSERBUILT, SENTRYBUILT, TELEPORTERBUILT)
  WERE defined in modmain.lua ~line 3178-3182, but the matching "_DOWN" variants
  were missing → DST falls back to showing the raw key / "STRING UNKNOWN".
- FIX: added 3 missing announce strings to modmain.lua right after ANNOUNCE_TELEPORTERBUILT:
    ANNOUNCE_DISPENSER_DOWN  = "My dispensing unit! Reduced to scrap."
    ANNOUNCE_SENTRY_DOWN     = "My turret! Downed in the line of duty."
    ANNOUNCE_TELEPORTER_DOWN = "The teleportation link has been severed!"
  Tone matches the existing Wagstaff inventor voice (short, technical, mildly dramatic).
- Cross-checked ALL ANNOUNCE_ references in prefab/component code against definitions
  in modmain.lua + speech_wagstaff.lua. The 5 remaining "missing from modmain" keys
  (ANNOUNCE_BAD_STOMACH, ANNOUNCE_EAT, ANNOUNCE_MYSTERY_*, ANNOUNCE_PUTONGOGGLES_*)
  are all correctly defined in speech_wagstaff.lua (character speech file) — verified
  8 occurrences. No other missing strings remain.
- Verified modmain.lua syntax with luaparse: SYNTAX OK.
- Committed as 7b05d95. Pushed to origin/GLM-5.1-Fixes: SUCCESS (637f386..7b05d95).
- Post-push security: reset remote URL to clean (no creds), unset WAGSTAFF_PAT env var.

Stage Summary:
- v2.0.17 string fix is now LIVE on remote GLM-5.1-Fixes (commit 7b05d95).
- Hammering a dispenser, sentry (ondeath), or teleporter entrance/exit now shows
  a proper character line instead of broken "STRING UNKNOWN" text.
- All other ANNOUNCE_ strings verified present — no other broken-text bugs remain.

---
Task ID: EXAMINE-QUOTES
Agent: Main (Z.ai Code)
Task: Add custom examination (DESCRIBE) quotes for Wagstaff bots/structures that currently fall back to the generic "It's a thing." line. User provided specific quotes for 11 items.

Work Log:
- Read /home/z/my-project/worklog.md to understand prior context (WagstaffMod DST mod at /home/z/ds-work/WagstaffMod/).
- Explored mod structure: located speech_wagstaff.lua (Wagstaff's speech file, 5834 lines) and modmain.lua (which registers GENERIC DESCRIBE entries for engineer buildings).
- Identified prefab names from prefab files:
    Butler Bot -> williambutler / williambutler2 / williambutler3
    Brute Bot  -> williambrute / williambrute2 / williambrute3
    Buster Bot -> williambuster / williambuster2 / williambuster3
    Ballistic  -> williamballistic / williamballistic2 / williamballistic3
    Sentry Gun -> esentry
    Dispenser  -> dispenser
    Telepad    -> telipad (vanilla Wagstaff receiver pad)
    Teleporter Entrance -> eteleporter
    Teleporter Exit     -> eteleporter_exit
    Telebrella -> telebrella
    Thumper     -> thumper
- Found existing GENERIC DESCRIBE entries in modmain.lua (lines 3148-3154) for ESENTRY/DISPENSER/ETELEPORTER/ETELEPORTER_EXIT (functional descriptions), but NO entries for the 4 bots -> bots showed "It's a thing." fallback.
- Found existing Wagstaff DESCRIBE entries for TELEBRELLA (line 4629), TELIPAD (line 4648), THUMPER (line 4679) with old quotes; user provided replacement quotes.
- Edited scripts/speech_wagstaff.lua (Wagstaff's DESCRIBE section) with MultiEdit:
    * Inserted DISPENSER = "My favorite kind of investment." (line 1841, alphabetical D section)
    * Inserted ESENTRY = "Always watching.", ETELEPORTER = "The journey starts here.", ETELEPORTER_EXIT = "You've arrived. Probably." (lines 1971-1973, E section)
    * Replaced TELEBRELLA quote -> "Weather is simply another engineering problem." (line 4633)
    * Replaced TELIPAD quote -> "Spatial relocation begins here." (line 4652)
    * Replaced THUMPER quote -> "Elegance hidden beneath brute force." (line 4683)
    * Inserted WILLIAM* block (12 entries: 4 bots x MK1/MK2/MK3) between WILDBOREHOUSE and WILLOW (lines 5190-5201), each bot's 3 variants sharing the user's quote.
- Edited modmain.lua: added GENERIC DESCRIBE entries for all 12 bot prefab variants (WILLIAMBUTLER/2/3, WILLIAMBRUTE/2/3, WILLIAMBUSTER/2/3, WILLIAMBALLISTIC/2/3) with character-neutral functional descriptions so non-Wagstaff characters also get a proper line instead of "It's a thing."
- Verified bracket balance on both files (braces balanced 512/512 and 143/143) and confirmed all 11 new/replaced Wagstaff entries are present at expected line numbers.

Stage Summary:
- Wagstaff now speaks the user's custom quotes when examining all 11 items (Butler/Brute/Buster/Ballistic bots incl. MK2/MK3, Sentry Gun, Dispenser, Telipad, Teleporter Entrance/Exit, Telebrella, Thumper).
- Non-Wagstaff characters get functional GENERIC descriptions for the 4 bots (new) and keep their existing ESENTRY/DISPENSER/ETELEPORTER/ETELEPORTER_EXIT descriptions.
- No gameplay/logic changes; pure string additions/replacements. Safe to hotreload or restart.
- Files modified: scripts/speech_wagstaff.lua, modmain.lua.
