-- Wagstaff Skill Tree
-- Based on reference implementation pattern from working DST mod skill trees.
-- Key rules:
--   - root = true: marks entry-point skills (available immediately)
--   - connects: chains skills forward (parent -> child). Engine follows this graph.
--   - locks: only for prerequisite back-references to lock nodes with lock_open functions
--   - NO (9999,9999) hidden locks needed -- connects chains handle progression
--
-- Branches:
--   mechanical: Fork (sentry path + dispenser path)
--   robotic:    Linear chain (brute mk2 -> brute mk3 -> buster mk2 -> buster mk3 -> ballistic mk2 -> ballistic mk3 -> butler mk2 -> butler mk3)
--   allegiance: Boss-locked with mutual exclusion (shadow vs lunar)

-- v2.0.17: debug helpers gated by the "Debug mode" mod config button.
-- Zero-cost when debug is OFF (early return before any string work).
local _dbg  = _G.WagstaffDbg  or function(...) end
local _dbgF = _G.WagstaffDbgF or function(...) end

local GAP = 38

-- Module-level locals for diagnostic logging flags.
-- These are used inside lock_open functions to print the unlock state exactly
-- once per skill tree open. Using module-level locals (NOT globals) is required
-- because DST ships with scripts/strict.lua which throws an error on any read
-- of an undeclared global variable. Reading `_WAGSTAFF_LOCK_LOGGED_*` without
-- declaring it first crashed the skill tree panel with:
--   variable '_WAGSTAFF_LOCK_LOGGED_FUELWEAVER' is not declared
local _lock_logged_fuelweaver = false
local _lock_logged_celestial = false

-- ORDERS: one entry per branch with {x, y} header position in the skill tree UI.
-- Format matches DST's standard: {branch_name, {x_offset, y_offset}}.
-- x = horizontal center of the branch column, y = vertical position of branch header.
-- v2.0.21: branch HEADER titles ("mechanical"/"robotic"/"allegiance") moved
-- off-screen to (9999, 9999) so they do not overlay the skill tree layout.
-- The ORDERS entries themselves are KEPT (the branch names are used as `group`
-- / `tags` identifiers by the skill nodes — deleting them would break layout).
-- Only the header label positions are pushed off-screen.
local ORDERS =
{
    {"mechanical", { 9999, 9999 }},
    {"robotic",    { 9999, 9999 }},
    {"allegiance", { 9999, 9999 }},
}

local function BuildSkillsData(SkillTreeFns)
    local skills =
    {
        -- ================================================================
        -- COLUMN 1: MECHANICAL (Fork: sentry path + dispenser path)
        -- ================================================================

        wagstaff_mechanical_1 = {
            name = "wagstaff_mechanical_1",
            title = "Mechanical Efficiency",
            desc = "Years of tinkering pay off.\nRepairs, upgrades, and maintenance have a chance to cost no Scrap.",
            icon = "Wrench",
            icon_atlas = "images/skilltree/Wrench.xml",
            pos = { -168.9, 164.9 },
            group = "mechanical",
            tags = {"mechanical"},
            root = true,
            defaultfocus = true,
            cost = 1,
            connects = {"wagstaff_sentry_mk2", "wagstaff_dispenser_mk2"},
            IsActivated = function(inst, skillsdata)
                return skillsdata ~= nil and skillsdata["wagstaff_mechanical_1"] == true
            end,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_mechanical_efficiency")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_mechanical_efficiency")
            end,
        },

        -- Sentry path (left column of mechanical)
        wagstaff_sentry_mk2 = {
            name = "wagstaff_sentry_mk2",
            title = "Sentry Mk.II",
            desc = "Equips the Sentry with dual guns.\nIncreases durability, damage, and ammo capacity.",
            icon = "sentrymk2",
            icon_atlas = "images/skilltree/sentrymk2.xml",
            pos = { -206.7, 120.7 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_sentry_mk3"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_sentry_mk2")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_sentry_mk2")
            end,
        },

        wagstaff_sentry_mk3 = {
            name = "wagstaff_sentry_mk3",
            title = "Sentry Mk.III",
            desc = "Unlocks the Sentry's full firepower.\nAdds rocket support and increases fire rate, durability, damage, and ammo capacity.",
            icon = "sentrymk3",
            icon_atlas = "images/skilltree/sentrymk3.xml",
            pos = { -206.7, 76.4 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_x2_damage"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_sentry_mk3")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_sentry_mk3")
            end,
        },

        wagstaff_x2_damage = {
            name = "wagstaff_x2_damage",
            title = "x2-Damage",
            desc = "Sometimes one shot is all it takes.\nGives the Sentry a chance to deal double damage.",
            icon = "doubledamage",
            icon_atlas = "images/skilltree/doubledamage.xml",
            pos = { -206.7, 32.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_calibrated_wrench"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_x2_damage")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_x2_damage")
            end,
        },

        -- Dispenser path (right column of mechanical)
        wagstaff_dispenser_mk2 = {
            name = "wagstaff_dispenser_mk2",
            title = "Dispenser MK.II",
            desc = "Improves the Dispenser's production efficiency.",
            icon = "disp2",
            icon_atlas = "images/skilltree/disp2.xml",
            pos = { -131.2, 120.7 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_dispenser_mk3"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_dispenser_mk2")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_dispenser_mk2")
            end,
        },

        wagstaff_dispenser_mk3 = {
            name = "wagstaff_dispenser_mk3",
            title = "Dispenser MK.III",
            desc = "Keeps the workshop running around the clock.\nProduces rarer resources and increases fuel capacity.",
            icon = "disp3",
            icon_atlas = "images/skilltree/disp3.xml",
            pos = { -131.2, 76.4 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_lucky_engineer"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_dispenser_mk3")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_dispenser_mk3")
            end,
        },

        wagstaff_lucky_engineer = {
            name = "wagstaff_lucky_engineer",
            title = "Lucky Engineer",
            desc = "Fortune smiles on good craftsmanship.\nGives the Dispenser a chance to produce an additional rare resource.",
            icon = "luckyenginer",
            icon_atlas = "images/skilltree/luckyenginer.xml",
            pos = { -131.2, 32.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_calibrated_wrench"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_lucky_engineer")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_lucky_engineer")
            end,
        },

        -- ================================================================
        -- COLUMN 2: ROBOTIC (Linear chain: butler->brute->buster->ballistic)
        -- ================================================================
        -- v2.0.15: Reordered — Butler first (support early), Ballistic last (turret late)
        -- Chain: butler_mk2 -> butler_mk3 -> brute_mk2 -> brute_mk3 ->
        --        buster_mk2 -> buster_mk3 -> ballistic_mk2 -> ballistic_mk3

        wagstaff_thermal_upgrade = {
            name = "wagstaff_thermal_upgrade",
            title = "Butler MK. II",
            desc = "Unlocks the Butler's gathering tools.\nAllows it to chop trees and mine.",
            icon = "buttlermk2",
            icon_atlas = "images/skilltree/buttlermk2.xml",
            pos = { -36.9, 164.2 },
            group = "robotic",
            tags = {"robotic"},
            root = true,
            cost = 1,
            connects = {"wagstaff_thermal_upgrade_parallel"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_thermal_upgrade onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_thermal_upgrade")
                _dbg("[SKILL DEBUG] Tag wagstaff_thermal_upgrade adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_thermal_upgrade"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_thermal_upgrade ondeactivate called")
                inst:RemoveTag("wagstaff_thermal_upgrade")
            end,
        },

        wagstaff_thermal_upgrade_parallel = {
            name = "wagstaff_thermal_upgrade_parallel",
            title = "Butler MK. III",
            desc = "Expands the Butler's capabilities far beyond household tasks.\nBrings memories back to life.",
            icon = "buttlermk3",
            icon_atlas = "images/skilltree/buttlermk3.xml",
            pos = { 38.6, 164.2 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_robotic_1"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_thermal_upgrade_mk3")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_thermal_upgrade_mk3")
            end,
        },

        wagstaff_robotic_1 = {
            name = "wagstaff_robotic_1",
            title = "Brute Bot MK. II",
            desc = "Reinforces the Brute's heavy frame.\nGreatly increases durability and damage.",
            icon = "brutemk2",
            icon_atlas = "images/skilltree/brutemk2.xml",
            pos = { -36.9, 120.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_robotic_1_parallel"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_robotic_1 onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_brute_evolve")
                _dbg("[SKILL DEBUG] Tag wagstaff_brute_evolve adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_brute_evolve"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_robotic_1 ondeactivate called")
                inst:RemoveTag("wagstaff_brute_evolve")
            end,
        },

        wagstaff_robotic_1_parallel = {
            name = "wagstaff_robotic_1_parallel",
            title = "Brute Bot MK. III",
            desc = "Turns the Brute into a true pack mule.\nAdds a complete storage system.",
            icon = "brutemk3",
            icon_atlas = "images/skilltree/brutemk3.xml",
            pos = { 38.6, 120.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_buster_evolve"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_robotic_1_parallel onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_brute_mk3")
                _dbg("[SKILL DEBUG] Tag wagstaff_brute_mk3 adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_brute_mk3"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_robotic_1_parallel ondeactivate called")
                inst:RemoveTag("wagstaff_brute_mk3")
            end,
        },

        wagstaff_buster_evolve = {
            name = "wagstaff_buster_evolve",
            title = "Buster Bot MK.II",
            desc = "Upgrades the Buster's combat chassis.\nIncreases its health and damage.",
            icon = "bustermk2",
            icon_atlas = "images/skilltree/bustermk2.xml",
            pos = { -36.9, 76.4 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_buster_parallel"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_buster_evolve onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_buster_evolve")
                _dbg("[SKILL DEBUG] Tag wagstaff_buster_evolve adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_buster_evolve"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_buster_evolve ondeactivate called")
                inst:RemoveTag("wagstaff_buster_evolve")
            end,
        },

        wagstaff_buster_parallel = {
            name = "wagstaff_buster_parallel",
            title = "Buster Bot MK. III",
            desc = "Pushes its offensive systems to the limit.\nUnlocks explosive strike abilities.",
            icon = "bustermk3",
            icon_atlas = "images/skilltree/bustermk3.xml",
            pos = { 38.6, 76.4 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_ballistic_evolve"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_buster_parallel onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_buster_mk3")
                _dbg("[SKILL DEBUG] Tag wagstaff_buster_mk3 adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_buster_mk3"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_buster_parallel ondeactivate called")
                inst:RemoveTag("wagstaff_buster_mk3")
            end,
        },

        wagstaff_ballistic_evolve = {
            name = "wagstaff_ballistic_evolve",
            title = "Ballistic Bot MK. II",
            desc = "Upgrades the Ballistic Bot's electrical systems.\nImproves durability and increases attack power.",
            icon = "balisticmk2",
            icon_atlas = "images/skilltree/balisticmk2.xml",
            pos = { -36.9, 32.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_ballistic_parallel"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_ballistic_evolve onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_ballistic_evolve")
                _dbg("[SKILL DEBUG] Tag wagstaff_ballistic_evolve adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_ballistic_evolve"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_ballistic_evolve ondeactivate called")
                inst:RemoveTag("wagstaff_ballistic_evolve")
            end,
        },

        wagstaff_ballistic_parallel = {
            name = "wagstaff_ballistic_parallel",
            title = "Ballistic Bot MK.III",
            desc = "Unlocks its lightning platform.\nGains advanced electrical weaponry and emits its own light.",
            icon = "balisticmk3",
            icon_atlas = "images/skilltree/balisticmk3.xml",
            pos = { 38.6, 32.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_optimized_fuel"},
            onactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_ballistic_parallel onactivate called, fromload:", fromload)
                _dbg("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_ballistic_mk3")
                _dbg("[SKILL DEBUG] Tag wagstaff_ballistic_mk3 adicionada")
                _dbg("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_ballistic_mk3"))
            end,
            ondeactivate = function(inst, fromload)
                _dbg("[SKILL DEBUG] wagstaff_ballistic_parallel ondeactivate called")
                inst:RemoveTag("wagstaff_ballistic_mk3")
            end,
        },

        -- ================================================================
        -- ALLEGIANCE (Boss-locked with mutual exclusion: shadow vs lunar)
        -- ================================================================
        -- These lock nodes use real positions and lock_open functions,
        -- matching the pattern from reference mods (kodi, sdf).

        wagstaff_allegiance_lock_shadow_boss = {
            desc = STRINGS and STRINGS.SKILLTREE and STRINGS.SKILLTREE.ALLEGIANCE_LOCK_2_DESC or "Defeat Ancient Fuelweaver to unlock",
            pos = { 205.8, 91.9 + GAP*2 },
            group = "allegiance",
            tags = {"allegiance","lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                -- Evaluate the REAL unlock condition FIRST. The previous code did
                -- `if readonly then return "question" end` unconditionally at the
                -- top, which made the skill tree UI render this node as a forever-
                -- locked "?" even AFTER the Fuelweaver was dead -- so the player
                -- could never click/activate the skill. Now we only hide as "?"
                -- when the boss is NOT yet killed (spoiler prevention).
                local unlocked = false
                local player = ThePlayer or (AllPlayers and AllPlayers[1])

                -- PRIMARY: Player tag (always replicates server->client in DST).
                -- net_bool created in AddPrefabPostInit("world") does NOT reliably
                -- replicate because the world entity is already fully networked by
                -- the time PostInit runs. Player tags, by contrast, are part of
                -- DST's core entity networking and always replicate.
                if player and player.HasTag and player:HasTag("wagstaff_fuelweaver_killed") then
                    unlocked = true
                end

                -- Fallback 1: net_bool (may work in some cases, kept for redundancy)
                if not unlocked and TheWorld and TheWorld.wagstaff_fuelweaver_killed_net and TheWorld.wagstaff_fuelweaver_killed_net:value() then
                    unlocked = true
                end

                -- Fallback 2: player profile stats (always available on client,
                -- works cross-shard -- important if the boss was killed in a
                -- different shard than where the skill tree is opened)
                if not unlocked and player and player.profile and player.profile.stats then
                    local fuelweaver_kills = player.profile.stats["killed_stalker_atrium"] or 0
                    if fuelweaver_kills > 0 then
                        unlocked = true
                    end
                end

                -- Diagnostic logging (helps debug if still not unlocking).
                -- Uses module-level locals to avoid strict.lua crashes on
                -- undeclared global reads.
                if not _lock_logged_fuelweaver then
                    _lock_logged_fuelweaver = true
                    _dbg("[Wagstaff LOCK] shadow_boss lock_open: tag=" .. tostring(player and player:HasTag("wagstaff_fuelweaver_killed") or false) ..
                          " net=" .. tostring(TheWorld and TheWorld.wagstaff_fuelweaver_killed_net and TheWorld.wagstaff_fuelweaver_killed_net:value() or false) ..
                          " stat=" .. tostring(player and player.profile and player.profile.stats and player.profile.stats["killed_stalker_atrium"] or 0) ..
                          " -> unlocked=" .. tostring(unlocked))
                end

                -- Only show "?" when the lock is genuinely undiscovered (boss
                -- still alive). Once killed, return the real state so the UI
                -- marks the node as accessible/clickable.
                if readonly and not unlocked then
                    return "question"
                end
                return unlocked
            end,
            connects = {"wagstaff_shadow_possession"},
        },

        wagstaff_allegiance_lock_lunar_boss = {
            desc = STRINGS and STRINGS.SKILLTREE and STRINGS.SKILLTREE.ALLEGIANCE_LOCK_3_DESC or "Defeat Celestial Champion to unlock",
            pos = { 150.2, 91.3 + GAP*2 },
            group = "allegiance",
            tags = {"allegiance","lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                -- Evaluate the REAL unlock condition FIRST. The previous code did
                -- `if readonly then return "question" end` unconditionally at the
                -- top, which made the skill tree UI render this node as a forever-
                -- locked "?" even AFTER the Celestial Champion was dead -- so the
                -- player could never click/activate the skill. Now we only hide
                -- as "?" when the boss is NOT yet killed (spoiler prevention).
                local unlocked = false
                local player = ThePlayer or (AllPlayers and AllPlayers[1])

                -- PRIMARY: Player tag (always replicates server->client in DST).
                -- net_bool created in AddPrefabPostInit("world") does NOT reliably
                -- replicate because the world entity is already fully networked by
                -- the time PostInit runs. Player tags, by contrast, are part of
                -- DST's core entity networking and always replicate.
                if player and player.HasTag and player:HasTag("wagstaff_celestial_killed") then
                    unlocked = true
                end

                -- Fallback 1: net_bool (may work in some cases, kept for redundancy)
                if not unlocked and TheWorld and TheWorld.wagstaff_celestial_killed_net and TheWorld.wagstaff_celestial_killed_net:value() then
                    unlocked = true
                end

                -- Fallback 2: player profile stats (always available on client,
                -- works cross-shard -- important if the boss was killed in a
                -- different shard than where the skill tree is opened)
                if not unlocked and player and player.profile and player.profile.stats then
                    local celestial_kills = player.profile.stats["killed_alterguardian_phase3"] or 0
                    if celestial_kills > 0 then
                        unlocked = true
                    end
                end

                -- Diagnostic logging (helps debug if still not unlocking).
                -- Uses module-level locals to avoid strict.lua crashes on
                -- undeclared global reads.
                if not _lock_logged_celestial then
                    _lock_logged_celestial = true
                    _dbg("[Wagstaff LOCK] lunar_boss lock_open: tag=" .. tostring(player and player:HasTag("wagstaff_celestial_killed") or false) ..
                          " net=" .. tostring(TheWorld and TheWorld.wagstaff_celestial_killed_net and TheWorld.wagstaff_celestial_killed_net:value() or false) ..
                          " stat=" .. tostring(player and player.profile and player.profile.stats and player.profile.stats["killed_alterguardian_phase3"] or 0) ..
                          " -> unlocked=" .. tostring(unlocked))
                end

                -- Only show "?" when the lock is genuinely undiscovered (boss
                -- still alive). Once killed, return the real state so the UI
                -- marks the node as accessible/clickable.
                if readonly and not unlocked then
                    return "question"
                end
                return unlocked
            end,
            connects = {"wagstaff_celestial_possession"},
        },

        -- Exclusion locks: block the opposite path if an affinity was chosen
        wagstaff_allegiance_lock_shadow_path = {
            desc = STRINGS and STRINGS.SKILLTREE and STRINGS.SKILLTREE.ALLEGIANCE_LOCK_4_DESC or "Cannot choose if Celestial path taken",
            pos = { 205.8, 91.9 + GAP },
            group = "allegiance",
            tags = {"allegiance", "lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                if SkillTreeFns.CountTags(prefabname, "lunar_favor", activatedskills) == 0 then
                    return true
                end
                return nil
            end,
            connects = {"wagstaff_shadow_possession"},
        },

        wagstaff_allegiance_lock_lunar_path = {
            desc = STRINGS and STRINGS.SKILLTREE and STRINGS.SKILLTREE.ALLEGIANCE_LOCK_5_DESC or "Cannot choose if Shadow path taken",
            pos = { 150.2, 91.3 + GAP },
            group = "allegiance",
            tags = {"allegiance", "lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                if SkillTreeFns.CountTags(prefabname, "shadow_favor", activatedskills) == 0 then
                    return true
                end
                return nil
            end,
            connects = {"wagstaff_celestial_possession"},
        },

        wagstaff_shadow_possession = {
            name = "wagstaff_shadow_possession",
            title = "Shadow's Embrace",
            desc = "Your inventions embrace the shadows during dusk.",
            icon = "wolfgang_allegiance_shadow_3",
            pos = { 205.8, 91.9 },
            group = "allegiance",
            tags = {"allegiance", "shadow", "shadow_favor"},
            cost = 1,
            locks = {"wagstaff_allegiance_lock_shadow_boss", "wagstaff_allegiance_lock_shadow_path"},
            connects = {"wagstaff_shadow_engineer"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_shadow_possession")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_shadow_possession")
            end,
        },

        wagstaff_celestial_possession = {
            name = "wagstaff_celestial_possession",
            title = "Moon's Blessing",
            desc = "Your inventions draw strength from the moon during the day.",
            icon = "wolfgang_allegiance_lunar_3",
            pos = { 150.2, 91.3 },
            group = "allegiance",
            tags = {"allegiance", "lunar", "lunar_favor"},
            cost = 1,
            locks = {"wagstaff_allegiance_lock_lunar_boss", "wagstaff_allegiance_lock_lunar_path"},
            connects = {"wagstaff_celestial_engineer"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_celestial_possession")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_celestial_possession")
            end,
        },

        -- ================================================================
        -- GROUP A: GADGETS (Branch from mechanical terminal nodes)
        -- ================================================================
        -- These skill effects were coded in wagstaff_skilltree_impl.lua but had
        -- no skill tree nodes to grant their tags. Now reachable via both the
        -- sentry and dispenser terminal nodes (x2_damage / lucky_engineer).

        wagstaff_calibrated_wrench = {
            name = "wagstaff_calibrated_wrench",
            title = "Calibrated Wrench",
            desc = "Precision tools for precision work.\nThe Wrench consumes only half durability.",
            icon = "Wrench",
            icon_atlas = "images/skilltree/Wrench.xml",
            pos = { -168.9, -11.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_stabilized_portals"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_calibrated_wrench")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_calibrated_wrench")
            end,
        },

        wagstaff_stabilized_portals = {
            name = "wagstaff_stabilized_portals",
            title = "Stabilized Portals",
            desc = "Portal technology, refined.\nThe Portal Gun costs less fuel to operate.",
            icon = "MK2",
            icon_atlas = "images/skilltree/MK2.xml",
            pos = { -168.9, -55.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_efficient_refineries"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_stabilized_portals")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_stabilized_portals")
            end,
        },

        wagstaff_efficient_refineries = {
            name = "wagstaff_efficient_refineries",
            title = "Efficient Refineries",
            desc = "Waste not, want not.\nRefineries have a chance to refund an input ingredient.",
            icon = "disp2",
            icon_atlas = "images/skilltree/disp2.xml",
            pos = { -168.9, -99.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_resupply_protocol"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_efficient_refineries")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_efficient_refineries")
            end,
        },

        wagstaff_resupply_protocol = {
            name = "wagstaff_resupply_protocol",
            title = "Resupply Protocol",
            desc = "Always be prepared.\nThe Dispenser has a chance to produce a bonus resource.",
            icon = "disp3",
            icon_atlas = "images/skilltree/disp3.xml",
            pos = { -168.9, -143.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            connects = {"wagstaff_master_engineer"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_resupply_protocol")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_resupply_protocol")
            end,
        },

        wagstaff_master_engineer = {
            name = "wagstaff_master_engineer",
            title = "Master Engineer",
            desc = "Mastery of the craft.\nTeleporters cost less sanity to use.",
            icon = "luckyenginer",
            icon_atlas = "images/skilltree/luckyenginer.xml",
            pos = { -168.9, -187.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_master_engineer")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_master_engineer")
            end,
        },

        -- ================================================================
        -- GROUP B: AUTOMATON (Branch from robotic terminal node)
        -- ================================================================
        -- These skill effects were coded in wagstaff_skilltree_impl.lua but had
        -- no skill tree nodes to grant their tags. Now reachable via the
        -- Ballistic Bot MK.III terminal node.

        wagstaff_optimized_fuel = {
            name = "wagstaff_optimized_fuel",
            title = "Optimized Fuel",
            desc = "Every drop counts.\nAutomatons have a chance to not consume fuel.",
            icon = "flicker",
            icon_atlas = "images/skilltree/flicker.xml",
            pos = { 0.85, -11.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_butler_protocols"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_optimized_fuel")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_optimized_fuel")
            end,
        },

        wagstaff_butler_protocols = {
            name = "wagstaff_butler_protocols",
            title = "Butler Protocols",
            desc = "Safety first.\nThe Butler Bot retreats from hostile creatures.",
            icon = "buttlermk2",
            icon_atlas = "images/skilltree/buttlermk2.xml",
            pos = { 0.85, -55.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_combat_coordination"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_butler_protocols")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_butler_protocols")
            end,
        },

        wagstaff_combat_coordination = {
            name = "wagstaff_combat_coordination",
            title = "Combat Coordination",
            desc = "Fight smarter.\nBuster Bots attack faster when near their leader.",
            icon = "bustermk2",
            icon_atlas = "images/skilltree/bustermk2.xml",
            pos = { 0.85, -99.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_predictive_maintenance"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_combat_coordination")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_combat_coordination")
            end,
        },

        wagstaff_predictive_maintenance = {
            name = "wagstaff_predictive_maintenance",
            title = "Predictive Maintenance",
            desc = "A stitch in time.\nAutomatons warn when fuel is running low.",
            icon = "reinforcedchassis",
            icon_atlas = "images/skilltree/reinforcedchassis.xml",
            pos = { 0.85, -143.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_overclock_protocol"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_predictive_maintenance")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_predictive_maintenance")
            end,
        },

        wagstaff_overclock_protocol = {
            name = "wagstaff_overclock_protocol",
            title = "Overclock Protocol",
            desc = "Push beyond the limits.\nAutomatons can temporarily overclock for increased speed.",
            icon = "shockwave",
            icon_atlas = "images/skilltree/shockwave.xml",
            pos = { 0.85, -187.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_overclock_protocol")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_overclock_protocol")
            end,
        },

        -- ================================================================
        -- GROUP C: ALLEGIANCE EXTENSIONS (Branch from affinity nodes)
        -- ================================================================
        -- These skill effects were coded in wagstaff_skilltree_impl.lua but had
        -- no skill tree nodes to grant their tags. Now reachable via the
        -- Shadow's Embrace / Moon's Blessing nodes.

        wagstaff_shadow_engineer = {
            name = "wagstaff_shadow_engineer",
            title = "Shadow Engineer",
            desc = "The shadows empower your creations.\nWeapons deal +25% damage.",
            icon = "wolfgang_allegiance_shadow_3",
            pos = { 205.8, 47.9 },
            group = "allegiance",
            tags = {"allegiance", "shadow", "shadow_favor"},
            cost = 1,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_shadow_engineer")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_shadow_engineer")
            end,
        },

        wagstaff_celestial_engineer = {
            name = "wagstaff_celestial_engineer",
            title = "Celestial Engineer",
            desc = "Lunar energy makes your tools last longer.\nItems lose durability 20% slower.",
            icon = "wolfgang_allegiance_lunar_3",
            pos = { 150.2, 47.3 },
            group = "allegiance",
            tags = {"allegiance", "lunar", "lunar_favor"},
            cost = 1,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_celestial_engineer")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_celestial_engineer")
            end,
        },
    }

    local BACKGROUND_SETTINGS = {
        background = "images/skilltree/wagstaff_background.xml",
        background_atlas = "images/skilltree/wagstaff_background.xml",
        tint_bright = false,
        tint_dim = false,
    }

    -- Inject IsActivated into every skill (so widget shows "Skill Mastered" instead of "Learn")
    for skillname, skilldata in pairs(skills) do
        if skilldata.lock_open == nil and skilldata.IsActivated == nil then
            local _name = skillname  -- Fix closure capture in Lua
            skilldata.IsActivated = function(inst, skillsdata)
                return skillsdata ~= nil and skillsdata[_name] == true
            end
        end
    end

    return {
        SKILLS = skills,
        ORDERS = ORDERS,
        BACKGROUND_SETTINGS = BACKGROUND_SETTINGS,
    }
end

return BuildSkillsData