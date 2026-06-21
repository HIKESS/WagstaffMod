-- Wagstaff Skill Tree
-- Based on reference implementation pattern from working DST mod skill trees.
-- Key rules:
--   - root = true: marks entry-point skills (available immediately)
--   - connects: chains skills forward (parent -> child). Engine follows this graph.
--   - locks: only for prerequisite back-references to lock nodes with lock_open functions
--   - NO (9999,9999) hidden locks needed — connects chains handle progression
--
-- Branches:
--   mechanical: Fork (sentry path + dispenser path)
--   robotic:    Linear chain (brute mk2 -> brute mk3 -> buster mk2 -> buster mk3 -> ballistic mk2 -> ballistic mk3 -> butler mk2 -> butler mk3)
--   allegiance: Boss-locked with mutual exclusion (shadow vs lunar)

local GAP = 38

-- ORDERS: one entry per branch with {x, y} header position in the skill tree UI.
-- Format matches DST's standard: {branch_name, {x_offset, y_offset}}.
-- x = horizontal center of the branch column, y = vertical position of branch header.
local ORDERS =
{
    {"mechanical", { -169, 202 }},
    {"robotic",    {    1, 202 }},
    {"allegiance", {  178, 130 }},
}

local function BuildSkillsData(SkillTreeFns)
    local skills =
    {
        -- ════════════════════════════════════════════════════════════════
        -- COLUMN 1: MECHANICAL (Fork: sentry path + dispenser path)
        -- ════════════════════════════════════════════════════════════════

        wagstaff_mechanical_1 = {
            name = "wagstaff_mechanical_1",
            title = "Mechanical Efficiency",
            desc = "30% chance repair, recharge, and upgrade costs no scrap",
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
            desc = "Increases Health\nRate of Fire",
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
            desc = "Increases Health\nAttack Range\nPeriodically shoot rockets that deal AOE damage",
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
            desc = "Chance to cause double damage",
            icon = "doubledamage",
            icon_atlas = "images/skilltree/doubledamage.xml",
            pos = { -206.7, 32.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
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
            desc = "Provides more resources per the day segment\nProvides Health regen in a small aura\nDay and Dusk",
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
            desc = "Increase the fuel duration per day\nProvides Health regen in a small aura\nDay, Dusk, & Night",
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
            desc = "Dispenser 15% rare drop chance",
            icon = "luckyenginer",
            icon_atlas = "images/skilltree/luckyenginer.xml",
            pos = { -131.2, 32.5 },
            group = "mechanical",
            tags = {"mechanical"},
            cost = 1,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_lucky_engineer")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_lucky_engineer")
            end,
        },

        -- ════════════════════════════════════════════════════════════════
        -- COLUMN 2: ROBOTIC (Linear chain: brute->buster->ballistic->butler)
        -- ════════════════════════════════════════════════════════════════
        -- Chain: brute_mk2 -> brute_mk3 -> buster_mk2 -> buster_mk3 ->
        --        ballistic_mk2 -> ballistic_mk3 -> butler_mk2 -> butler_mk3

        wagstaff_robotic_1 = {
            name = "wagstaff_robotic_1",
            title = "Brute Bot MK. II",
            desc = "Increases Health\nIncreases Damage",
            icon = "brutemk2",
            icon_atlas = "images/skilltree/brutemk2.xml",
            pos = { -36.9, 164.2 },
            group = "robotic",
            tags = {"robotic"},
            root = true,
            cost = 1,
            connects = {"wagstaff_robotic_1_parallel"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_robotic_1 onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_brute_evolve")
                print("[SKILL DEBUG] Tag wagstaff_brute_evolve adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_brute_evolve"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_robotic_1 ondeactivate called")
                inst:RemoveTag("wagstaff_brute_evolve")
            end,
        },

        wagstaff_robotic_1_parallel = {
            name = "wagstaff_robotic_1_parallel",
            title = "Brute Bot MK. III",
            desc = "Add Storage",
            icon = "brutemk3",
            icon_atlas = "images/skilltree/brutemk3.xml",
            pos = { 38.6, 164.2 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_buster_evolve"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_robotic_1_parallel onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_brute_mk3")
                print("[SKILL DEBUG] Tag wagstaff_brute_mk3 adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_brute_mk3"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_robotic_1_parallel ondeactivate called")
                inst:RemoveTag("wagstaff_brute_mk3")
            end,
        },

        wagstaff_buster_evolve = {
            name = "wagstaff_buster_evolve",
            title = "Buster Bot MK.II",
            desc = "Increases Health\nIncreases Damage",
            icon = "bustermk2",
            icon_atlas = "images/skilltree/bustermk2.xml",
            pos = { -36.9, 120.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_buster_parallel"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_buster_evolve onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_buster_evolve")
                print("[SKILL DEBUG] Tag wagstaff_buster_evolve adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_buster_evolve"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_buster_evolve ondeactivate called")
                inst:RemoveTag("wagstaff_buster_evolve")
            end,
        },

        wagstaff_buster_parallel = {
            name = "wagstaff_buster_parallel",
            title = "Buster Bot MK. III",
            desc = "Explosive Punch",
            icon = "bustermk3",
            icon_atlas = "images/skilltree/bustermk3.xml",
            pos = { 38.6, 120.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_ballistic_evolve"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_buster_parallel onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_buster_mk3")
                print("[SKILL DEBUG] Tag wagstaff_buster_mk3 adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_buster_mk3"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_buster_parallel ondeactivate called")
                inst:RemoveTag("wagstaff_buster_mk3")
            end,
        },

        wagstaff_ballistic_evolve = {
            name = "wagstaff_ballistic_evolve",
            title = "Ballistic Bot MK. II",
            desc = "Powered by Lightning & Rain\nUnlocks Light Orb toggle (left-click)",
            icon = "balisticmk2",
            icon_atlas = "images/skilltree/balisticmk2.xml",
            pos = { -36.9, 76.4 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_ballistic_parallel"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_ballistic_evolve onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_ballistic_evolve")
                print("[SKILL DEBUG] Tag wagstaff_ballistic_evolve adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_ballistic_evolve"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_ballistic_evolve ondeactivate called")
                inst:RemoveTag("wagstaff_ballistic_evolve")
            end,
        },

        wagstaff_ballistic_parallel = {
            name = "wagstaff_ballistic_parallel",
            title = "Ballistic Bot MK.III",
            desc = "Active Light Orb",
            icon = "balisticmk3",
            icon_atlas = "images/skilltree/balisticmk3.xml",
            pos = { 38.6, 76.4 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_thermal_upgrade"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_ballistic_parallel onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_ballistic_mk3")
                print("[SKILL DEBUG] Tag wagstaff_ballistic_mk3 adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_ballistic_mk3"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_ballistic_parallel ondeactivate called")
                inst:RemoveTag("wagstaff_ballistic_mk3")
            end,
        },

        wagstaff_thermal_upgrade = {
            name = "wagstaff_thermal_upgrade",
            title = "Butler MK. II",
            desc = "Unlocks wood chopping and mining ability for Butler Bot",
            icon = "buttlermk2",
            icon_atlas = "images/skilltree/buttlermk2.xml",
            pos = { -36.9, 32.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            connects = {"wagstaff_thermal_upgrade_parallel"},
            onactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_thermal_upgrade onactivate called, fromload:", fromload)
                print("[SKILL DEBUG] inst.prefab:", inst and inst.prefab or "NIL")
                inst:AddTag("wagstaff_thermal_upgrade")
                print("[SKILL DEBUG] Tag wagstaff_thermal_upgrade adicionada")
                print("[SKILL DEBUG] HasTag check:", inst:HasTag("wagstaff_thermal_upgrade"))
            end,
            ondeactivate = function(inst, fromload)
                print("[SKILL DEBUG] wagstaff_thermal_upgrade ondeactivate called")
                inst:RemoveTag("wagstaff_thermal_upgrade")
            end,
        },

        wagstaff_thermal_upgrade_parallel = {
            name = "wagstaff_thermal_upgrade_parallel",
            title = "Butler MK. III",
            desc = "Your Spirit Remains Bound into machine\nCost 30 Max HP",
            icon = "buttlermk3",
            icon_atlas = "images/skilltree/buttlermk3.xml",
            pos = { 38.6, 32.5 },
            group = "robotic",
            tags = {"robotic"},
            cost = 1,
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_thermal_upgrade_mk3")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_thermal_upgrade_mk3")
            end,
        },

        -- ════════════════════════════════════════════════════════════════
        -- ALLEGIANCE (Boss-locked with mutual exclusion: shadow vs lunar)
        -- ════════════════════════════════════════════════════════════════
        -- These lock nodes use real positions and lock_open functions,
        -- matching the pattern from reference mods (kodi, sdf).

        wagstaff_allegiance_lock_shadow_boss = {
            desc = STRINGS and STRINGS.SKILLTREE and STRINGS.SKILLTREE.ALLEGIANCE_LOCK_2_DESC or "Defeat Ancient Fuelweaver to unlock",
            pos = { 205.8, 91.9 + GAP*2 },
            group = "allegiance",
            tags = {"allegiance","lock"},
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                if readonly then
                    return "question"
                end
                return TheWorld and TheWorld.state and TheWorld.state.wagstaff_fuelweaver_killed
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
                if readonly then
                    return "question"
                end
                return TheWorld and TheWorld.state and TheWorld.state.wagstaff_celestial_killed
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
            title = "Shadow Engineer Herald's Mark",
            desc = "The Void Masque recognizes the inventor as a kindred spirit.\nOne who also builds bodies to house other wills. Your bots now carry the mark of Tenebrae.\n\nButler: MK 2 can revive players (night only).\nBuster: Summons a Shadow Clone with 50% strength, immune to damage. Destroyed at day or when Buster dies.\nBouncer: Immune to planar damage + Bearger's Shovelwave. Shadow creatures target him as absolute priority.\nBattery: Chain lightning causes fear (2-3s)",
            icon = "wolfgang_allegiance_shadow_3",
            pos = { 205.8, 91.9 },
            group = "allegiance",
            tags = {"allegiance", "shadow", "shadow_favor"},
            cost = 1,
            locks = {"wagstaff_allegiance_lock_shadow_boss", "wagstaff_allegiance_lock_shadow_path"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_shadow_possession")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_shadow_possession")
            end,
        },

        wagstaff_celestial_possession = {
            name = "wagstaff_celestial_possession",
            title = "Celestial Engineer Gestalt Resonance",
            desc = "The Gestalt that inhabits the chassis during the day synchronizes its frequency with the inventor's own.\nPushing each bot beyond its mechanical limits. The warmth of lunar light radiates through cold metal.\n\nButler: Foods restore 40% HP based on hunger value (day only). MK 2 can revive players.\nBuster: Explosive punch gains AOE (light explosion)\nBouncer: Heat aura. When hit, deals 25 fire damage to all enemies in aggro radius.\nBattery: Light orb grants full sanity protection",
            icon = "wolfgang_allegiance_lunar_3",
            pos = { 150.2, 91.3 },
            group = "allegiance",
            tags = {"allegiance", "lunar", "lunar_favor"},
            cost = 1,
            locks = {"wagstaff_allegiance_lock_lunar_boss", "wagstaff_allegiance_lock_lunar_path"},
            onactivate = function(inst, fromload)
                inst:AddTag("wagstaff_celestial_possession")
            end,
            ondeactivate = function(inst, fromload)
                inst:RemoveTag("wagstaff_celestial_possession")
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