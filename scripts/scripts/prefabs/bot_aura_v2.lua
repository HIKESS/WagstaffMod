-- AURA V2 - Mais visual e elaborada!
-- Usa múltiplos layers de FX do DST

-- Helper para spawnar particles ao redor
local function SpawnParticlesAround(inst, prefab_name, count, radius, height)
    if not inst._parent or not inst._parent:IsValid() then return end
    
    local x, y, z = inst._parent.Transform:GetWorldPosition()
    for i = 1, count do
        local angle = math.random() * 2 * math.pi
        local r = math.random() * radius
        local particle = SpawnPrefab(prefab_name)
        if particle then
            particle.Transform:SetPosition(
                x + math.cos(angle) * r,
                y + (height or 0.5) + math.random() * 0.5,
                z + math.sin(angle) * r
            )
            -- Alguns particles precisam de escala
            if particle.Transform then
                local scale = 0.5 + math.random() * 0.5
                particle.Transform:SetScale(scale, scale, scale)
            end
        end
    end
end

-- AURA CELESTIAL V2 - Azul lunar elaborada
local function fn_celestial()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("decor")

    -- Light base azul forte
    inst.Light:Enable(true)
    inst.Light:SetRadius(5)
    inst.Light:SetFalloff(0.4)
    inst.Light:SetIntensity(0.7)
    inst.Light:SetColour(0.3, 0.6, 1)

    inst._parent = nil
    inst._age = 0

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent imediatamente
    inst:DoTaskInTime(0, function()
        inst:DoPeriodicTask(0.05, function()  -- Update rápido para suavidade
            if inst._parent and inst._parent:IsValid() then
                local x, y, z = inst._parent.Transform:GetWorldPosition()
                inst.Transform:SetPosition(x, y + 0.3, z)
            else
                inst:Remove()
            end
        end)
    end)

    -- EFEITO 1: Pulso de luz suave
    inst._pulse_phase = 0
    inst:DoPeriodicTask(0.1, function()
        inst._pulse_phase = inst._pulse_phase + 0.3
        local pulse = 0.5 + math.sin(inst._pulse_phase) * 0.3
        inst.Light:SetIntensity(0.4 + pulse * 0.4)
        inst.Light:SetRadius(4 + pulse)
    end)

    -- EFEITO 2: Sparkles frequentes ao redor
    inst:DoPeriodicTask(0.4, function()
        SpawnParticlesAround(inst, "ice_sparkle", 2, 1.2, 0.3)
    end)

    -- EFEITO 3: Sparks elétricos ocasionais
    inst:DoPeriodicTask(1.5, function()
        if math.random() < 0.7 then
            SpawnParticlesAround(inst, "sparks", 1, 0.8, 0.5)
        end
    end)

    -- EFEITO 4: Orbitar partículas (simulado com spawn em círculo)
    inst._orbit_angle = 0
    inst:DoPeriodicTask(0.2, function()
        if inst._parent and inst._parent:IsValid() then
            inst._orbit_angle = inst._orbit_angle + 0.5
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local radius = 1.0
            local angle = inst._orbit_angle
            
            -- Spawn sparkle na posição orbital
            local sparkle = SpawnPrefab("ice_sparkle")
            if sparkle then
                sparkle.Transform:SetPosition(
                    x + math.cos(angle) * radius,
                    y + 0.4 + math.sin(inst._orbit_angle * 2) * 0.2,
                    z + math.sin(angle) * radius
                )
                sparkle.Transform:SetScale(0.7, 0.7, 0.7)
            end
        end
    end)

    return inst
end

-- AURA SHADOW V2 - Roxa sombria
local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("decor")

    -- Light roxo escuro
    inst.Light:Enable(true)
    inst.Light:SetRadius(4)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(0.5)
    inst.Light:SetColour(0.4, 0.1, 0.6)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoTaskInTime(0, function()
        inst:DoPeriodicTask(0.05, function()
            if inst._parent and inst._parent:IsValid() then
                local x, y, z = inst._parent.Transform:GetWorldPosition()
                inst.Transform:SetPosition(x, y + 0.2, z)
            else
                inst:Remove()
            end
        end)
    end)

    -- Pulso sombrio
    inst._pulse_phase = 0
    inst:DoPeriodicTask(0.15, function()
        inst._pulse_phase = inst._pulse_phase + 0.25
        local pulse = 0.5 + math.sin(inst._pulse_phase) * 0.3
        inst.Light:SetIntensity(0.3 + pulse * 0.3)
    end)

    -- Partículas de sombra densas
    inst:DoPeriodicTask(0.5, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            for i = 1, 2 do
                local angle = math.random() * 2 * math.pi
                local radius = 0.5 + math.random() * 0.8
                local puff = SpawnPrefab("shadow_puff_large_front")
                if puff then
                    puff.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + 0.2 + math.random() * 0.4,
                        z + math.sin(angle) * radius
                    )
                    puff.Transform:SetScale(0.25, 0.25, 0.25)
                end
            end
        end
    end)

    return inst
end

-- AURA FOGO AZUL V2 (Bouncer) - Muito mais visual!
local function fn_coldfire()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("decor")

    -- Light azul brilhante
    inst.Light:Enable(true)
    inst.Light:SetRadius(4.5)
    inst.Light:SetFalloff(0.35)
    inst.Light:SetIntensity(0.9)
    inst.Light:SetColour(0.2, 0.5, 1)

    inst._parent = nil
    inst._fire_phase = 0

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoTaskInTime(0, function()
        inst:DoPeriodicTask(0.05, function()
            if inst._parent and inst._parent:IsValid() then
                local x, y, z = inst._parent.Transform:GetWorldPosition()
                -- Fica mais baixo que as outras auras (fogo na base)
                inst.Transform:SetPosition(x, y - 0.1, z)
            else
                inst:Remove()
            end
        end)
    end)

    -- Pulso de fogo rápido
    inst:DoPeriodicTask(0.08, function()
        inst._fire_phase = inst._fire_phase + 0.8
        local flicker = 0.6 + math.sin(inst._fire_phase) * 0.3 + math.random() * 0.1
        inst.Light:SetIntensity(0.7 + flicker * 0.3)
        inst.Light:SetRadius(3.5 + flicker)
    end)

    -- MUITOS sparkles de gelo (fogo azul)
    inst:DoPeriodicTask(0.2, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- Spawn 3-4 sparkles ao redor
            for i = 1, 3 + math.random(2) do
                local angle = math.random() * 2 * math.pi
                local radius = 0.6 + math.random() * 0.8
                local sparkle = SpawnPrefab("ice_sparkle")
                if sparkle then
                    sparkle.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + math.random() * 0.6,
                        z + math.sin(angle) * radius
                    )
                    local scale = 0.6 + math.random() * 0.4
                    sparkle.Transform:SetScale(scale, scale, scale)
                end
            end
        end
    end)

    -- Fumaça/ocasoinalmente "puffs" de fogo
    inst:DoPeriodicTask(0.6, function()
        if inst._parent and inst._parent:IsValid() and math.random() < 0.5 then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local puff = SpawnPrefab("small_puff")
            if puff then
                local angle = math.random() * 2 * math.pi
                local r = 0.5 + math.random() * 0.5
                puff.Transform:SetPosition(
                    x + math.cos(angle) * r,
                    y + 0.2,
                    z + math.sin(angle) * r
                )
                -- Tentar deixar azul
                if puff.AnimState then
                    puff.AnimState:SetMultColour(0.3, 0.5, 1, 0.5)
                end
            end
        end
    end)

    return inst
end

return Prefab("bot_aura_celestial", fn_celestial),
       Prefab("bot_aura_shadow", fn_shadow),
       Prefab("bot_aura_coldfire", fn_coldfire)
