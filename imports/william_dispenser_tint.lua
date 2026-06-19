-- william_dispenser_tint.lua
-- Applies celestial/shadow visual tints to the dispenser based on owner affinity.

AddPrefabPostInit("dispenser", function(inst)
    if not GLOBAL.TheWorld or not GLOBAL.TheWorld.ismastersim then return end

    inst:DoPeriodicTask(2, function()
        if not inst or not inst:IsValid() then return end
        -- Find owner via engieID
        local owner = nil
        for _, ent in pairs(GLOBAL.Ents) do
            if ent and ent:IsValid() and ent.engieID and inst.dispenserID and
               ent.engieID == inst.dispenserID then
                owner = ent
                break
            end
        end
        if not owner then
            inst.AnimState:SetMultColour(1, 1, 1, 1)
            return
        end
        local isday  = GLOBAL.TheWorld.state.isday
        local isdusk = GLOBAL.TheWorld.state.isdusk
        if isday and owner:HasTag("wagstaff_celestial_possession") then
            inst.AnimState:SetMultColour(0.85, 0.92, 1.0, 1)
        elseif isdusk and owner:HasTag("wagstaff_shadow_possession") then
            inst.AnimState:SetMultColour(0.6, 0.45, 0.7, 1)
        else
            inst.AnimState:SetMultColour(1, 1, 1, 1)
        end
    end)
end)
