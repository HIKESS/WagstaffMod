-- Skill helper functions for Wagstaff Standalone
-- These functions are missing from the mod and causing upgrade failures

local G = GLOBAL

-- Check if a player has a specific skill activated
-- Skills are stored as tags on the player when activated
function G.WagstaffHasSkill(inst, skill_name)
    if inst == nil or skill_name == nil then
        return false
    end
    
    -- Method 1: Check for tag directly (skills add tags when activated)
    local tag_name = skill_name
    if inst:HasTag(tag_name) then
        return true
    end
    
    -- Method 2: Check skilltreeupdater component if available
    if inst.components and inst.components.skilltreeupdater ~= nil then
        -- The skilltreeupdater might store active skills differently
        -- Try to get the skill data
        local skilltree = inst.components.skilltreeupdater:GetSkillTree()
        if skilltree then
            -- Check if skill is in the active skills list
            for _, skill in ipairs(skilltree) do
                if skill == skill_name then
                    return true
                end
            end
        end
    end
    
    -- Method 3: Check TheSkillTree global (DST's skill tree system)
    if G.TheSkillTree and G.TheSkillTree.GetSkillData then
        -- This depends on how DST exposes skills
        -- For now, rely on tags which are the primary method
    end
    
    return false
end

-- Calculate upgrade cost with Mechanical Efficiency skill discount
-- If player has "wagstaff_mechanical_1" skill, 30% chance to not consume scrap
function G.WagstaffMechanicalEfficiencyRoll(doer, base_cost)
    if doer == nil or base_cost == nil then
        return base_cost
    end
    
    -- Check if player has Mechanical Efficiency skill
    if G.WagstaffHasSkill(doer, "wagstaff_mechanical_1") then
        -- 30% chance for free upgrade (returns 0 cost)
        if math.random() < 0.30 then
            return 0
        end
    end
    
    return base_cost
end

-- Publish these functions to GLOBAL so they can be accessed with _G.WagstaffHasSkill()
-- In DST modding, GLOBAL is the proper way to expose functions globally
GLOBAL.WagstaffHasSkill = G.WagstaffHasSkill
GLOBAL.WagstaffMechanicalEfficiencyRoll = G.WagstaffMechanicalEfficiencyRoll

print("[Wagstaff Skill Helpers] WagstaffHasSkill and WagstaffMechanicalEfficiencyRoll registered")
