-- AURA V4 - Ajustes finais baseados no feedback!

-- ========================================================================
-- BUTLER - Elegante, SEM sparks (só sparkles suaves)
-- ========================================================================
local function fn_butler()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light azul muito suave
    inst.Light:Enable(true)
    inst.Light:SetRadius(2.5)
    inst.Light:SetFalloff(0.8)
    inst.Light:SetIntensity(0.4)
    inst.Light:SetColour(0.6, 0.8, 1)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    -- SÓ sparkles - elegante!
    inst:DoPeriodicTask(0.8, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- Sparkles lentos e suaves
            for i = 1, 2 do
                local angle = math.random() * 2 * math.pi
                local r = 0.7 + math.random() * 0.5
                local sparkle = SpawnPrefab("ice_sparkle")
                if sparkle then
                    sparkle.Transform:SetPosition(
                        x + math.cos(angle) * r,
                        y + 0.3 + math.random() * 0.3,
                        z + math.sin(angle) * r
                    )
                    sparkle.Transform:SetScale(0.6, 0.6, 0.6)
                end
            end
        end
    end)

    -- Pulso suave
    local pulse = 0
    inst:DoPeriodicTask(0.5, function()
        pulse = pulse + 0.2
        local intensity = 0.3 + math.sin(pulse) * 0.1
        inst.Light:SetIntensity(intensity)
    end)

    return inst
end

-- ========================================================================
-- BATTERY - Fogo de Gestalt girando na cabeça!
-- ========================================================================
local function fn_battery()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light forte
    inst.Light:Enable(true)
    inst.Light:SetRadius(4)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(0.7)
    inst.Light:SetColour(0.3, 0.6, 1)

    inst._parent = nil
    inst._orbit_angle = 0
    inst._gestalt_fire = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent (mais alto - cabeça)
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 1.5, z)  -- Na cabeça!
            
            -- Atualizar fogo de gestalt se existir
            if inst._gestalt_fire and inst._gestalt_fire:IsValid() then
                inst._gestalt_fire.Transform:SetPosition(x, y + 2.0, z)
            end
        else
            inst:Remove()
        end
    end)

    -- Criar fogo de gestalt/lunar na cabeça
    inst:DoTaskInTime(0, function()
        if inst._parent and inst._parent:IsValid() then
            -- Tentar usar o fogo lunar/gestalt
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst._gestalt_fire = SpawnPrefab("lunar_flame")
            if not inst._gestalt_fire then
                -- Fallback: usar willowfire e pintar de azul
                inst._gestalt_fire = SpawnPrefab("willowfire")
                if inst._gestalt_fire and inst._gestalt_fire.AnimState then
                    inst._gestalt_fire.AnimState:SetMultColour(0.3, 0.5, 1, 0.8)
                    inst._gestalt_fire.AnimState:SetAddColour(0.1, 0.2, 0.5, 0)
                end
            end
            if inst._gestalt_fire then
                inst._gestalt_fire.Transform:SetPosition(x, y + 2.0, z)
                inst._gestalt_fire.Transform:SetScale(0.7, 0.7, 0.7)
            end
        end
    end)

    -- Sparkles orbitando em volta
    inst:DoPeriodicTask(0.3, function()
        if inst._parent and inst._parent:IsValid() then
            inst._orbit_angle = inst._orbit_angle + 0.7
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local radius = 1.0
            local angle = inst._orbit_angle
            
            local sparkle = SpawnPrefab("ice_sparkle")
            if sparkle then
                sparkle.Transform:SetPosition(
                    x + math.cos(angle) * radius,
                    y + 1.2 + math.sin(inst._orbit_angle * 2) * 0.2,
                    z + math.sin(angle) * radius
                )
                sparkle.Transform:SetScale(0.7, 0.7, 0.7)
            end
        end
    end)

    -- Limpar fogo ao remover
    inst:ListenForEvent("onremove", function()
        if inst._gestalt_fire and inst._gestalt_fire:IsValid() then
            inst._gestalt_fire:Remove()
        end
    end)

    return inst
end

-- ========================================================================
-- BUSTER - Sparks AZUIS
-- ========================================================================
local function fn_buster()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light elétrico azul
    inst.Light:Enable(true)
    inst.Light:SetRadius(3.5)
    inst.Light:SetFalloff(0.6)
    inst.Light:SetIntensity(0.7)
    inst.Light:SetColour(0.2, 0.4, 1)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.5, z)
        else
            inst:Remove()
        end
    end)

    -- SPARKS AZUIS
    inst:DoPeriodicTask(0.25, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- 2-3 sparks azuis
            for i = 1, 2 + math.random(2) do
                local angle = math.random() * 2 * math.pi
                local radius = 0.5 + math.random() * 0.8
                local spark = SpawnPrefab("sparks")
                if spark then
                    spark.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + 0.4 + math.random() * 0.6,
                        z + math.sin(angle) * radius
                    )
                    -- TENTAR deixar azul
                    if spark.AnimState then
                        spark.AnimState:SetMultColour(0.3, 0.6, 1, 1)  -- Azul!
                        spark.AnimState:SetAddColour(0.1, 0.2, 0.4, 0)
                    end
                end
            end
        end
    end)

    -- Eletricidade azul
    inst:DoPeriodicTask(0.8, function()
        if inst._parent and inst._parent:IsValid() and math.random() < 0.6 then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local zap = SpawnPrefab("sparks_fx")
            if zap then
                zap.Transform:SetPosition(x, y + 0.5, z)
                if zap.AnimState then
                    zap.AnimState:SetMultColour(0.3, 0.5, 1, 1)
                    zap.AnimState:SetAddColour(0.1, 0.2, 0.3, 0)
                end
            end
        end
    end)

    -- Pulso rápido
    local pulse = 0
    inst:DoPeriodicTask(0.15, function()
        pulse = pulse + 1
        if pulse % 3 == 0 then
            inst.Light:SetIntensity(1.0)
            inst.Light:SetRadius(4)
        else
            inst.Light:SetIntensity(0.6)
            inst.Light:SetRadius(3)
        end
    end)

    return inst
end

-- ========================================================================
-- BOUNCER - Aura de LOUCURA da ilha lunar!
-- ========================================================================
local function fn_bouncer()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light azul forte
    inst.Light:Enable(true)
    inst.Light:SetRadius(4)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(0.8)
    inst.Light:SetColour(0.25, 0.55, 1)

    inst._parent = nil
    inst._gestalt_fire = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.2, z)
            
            -- Fogo de gestalt segue
            if inst._gestalt_fire and inst._gestalt_fire:IsValid() then
                inst._gestalt_fire.Transform:SetPosition(x, y + 0.8, z)
            end
        else
            inst:Remove()
        end
    end)

    -- CRIAR FOGO DE GESTALT DENTRO DO BOT!
    inst:DoTaskInTime(0, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            
            -- Tentar lunar_flame primeiro
            inst._gestalt_fire = SpawnPrefab("lunar_flame")
            
            if not inst._gestalt_fire then
                -- Tentar gestalt_mutation_fx
                inst._gestalt_fire = SpawnPrefab("gestalt_mutation_fx")
            end
            
            if not inst._gestalt_fire then
                -- Usar willowfire e pintar de azul
                inst._gestalt_fire = SpawnPrefab("willowfire")
                if inst._gestalt_fire and inst._gestalt_fire.AnimState then
                    inst._gestalt_fire.AnimState:SetMultColour(0.2, 0.4, 1, 0.9)
                    inst._gestalt_fire.AnimState:SetAddColour(0.1, 0.3, 0.5, 0)
                end
            end
            
            if inst._gestalt_fire then
                inst._gestalt_fire.Transform:SetPosition(x, y + 0.8, z)
                inst._gestalt_fire.Transform:SetScale(0.8, 0.8, 0.8)
            end
        end
    end)

    -- Aura de "loucura" - tentar crazy atau usar fallback
    inst:DoPeriodicTask(0.5, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            
            -- Tentar efeito de insanidade/aura lunar
            local crazy = SpawnPrefab("crazy")
            if crazy then
                crazy.Transform:SetPosition(x, y + 0.5, z)
                if crazy.AnimState then
                    crazy.AnimState:SetMultColour(0.3, 0.5, 1, 0.5)
                end
            else
                -- Fallback: partículas de sombra azuis
                for i = 1, 2 do
                    local angle = math.random() * 2 * math.pi
                    local r = 0.8 + math.random() * 0.5
                    local puff = SpawnPrefab("shadow_puff_large_front")
                    if puff then
                        puff.Transform:SetPosition(
                            x + math.cos(angle) * r,
                            y + 0.3 + math.random() * 0.3,
                            z + math.sin(angle) * r
                        )
                        puff.Transform:SetScale(0.25, 0.25, 0.25)
                        if puff.AnimState then
                            puff.AnimState:SetMultColour(0.2, 0.4, 0.8, 0.6)
                        end
                    end
                end
            end
        end
    end)

    -- Sparkles azuis frequentes
    inst:DoPeriodicTask(0.4, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            for i = 1, 2 do
                local angle = math.random() * 2 * math.pi
                local r = 0.9 + math.random() * 0.6
                local sparkle = SpawnPrefab("ice_sparkle")
                if sparkle then
                    sparkle.Transform:SetPosition(
                        x + math.cos(angle) * r,
                        y + 0.4 + math.random() * 0.4,
                        z + math.sin(angle) * r
                    )
                end
            end
        end
    end)

    -- Limpar fogo ao remover
    inst:ListenForEvent("onremove", function()
        if inst._gestalt_fire and inst._gestalt_fire:IsValid() then
            inst._gestalt_fire:Remove()
        end
    end)

    return inst
end

-- ========================================================================
-- SHADOW - Mantido igual
-- ========================================================================
local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:Enable(true)
    inst.Light:SetRadius(3.5)
    inst.Light:SetFalloff(0.6)
    inst.Light:SetIntensity(0.4)
    inst.Light:SetColour(0.4, 0.1, 0.7)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    inst:DoPeriodicTask(0.4, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            for i = 1, 2 + math.random(1) do
                local angle = math.random() * 2 * math.pi
                local radius = 0.6 + math.random() * 0.7
                local puff = SpawnPrefab("shadow_puff_large_front")
                if puff then
                    puff.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + 0.2 + math.random() * 0.3,
                        z + math.sin(angle) * radius
                    )
                    puff.Transform:SetScale(0.3, 0.3, 0.3)
                end
            end
        end
    end)

    local pulse = 0
    inst:DoPeriodicTask(0.25, function()
        pulse = pulse + 0.3
        local intensity = 0.3 + math.sin(pulse) * 0.15
        inst.Light:SetIntensity(intensity)
    end)

    return inst
end

return Prefab("bot_aura_butler", fn_butler),
       Prefab("bot_aura_battery", fn_battery),
       Prefab("bot_aura_buster", fn_buster),
       Prefab("bot_aura_bouncer", fn_bouncer),
       Prefab("bot_aura_shadow", fn_shadow)
