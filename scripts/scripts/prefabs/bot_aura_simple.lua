-- AURA SIMPLES - Não precisa de texturas custom!
-- Usa apenas FX existentes do DST combinados

-- Aura AZUL CELESTIAL (só light + sparkles)
local function fn_celestial()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light azul pulsante
    inst.Light:Enable(true)
    inst.Light:SetRadius(4)
    inst.Light:SetFalloff(0.6)
    inst.Light:SetIntensity(0.6)
    inst.Light:SetColour(0.4, 0.7, 1)

    inst._parent = nil
    inst._pulse = 0.6

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent imediatamente
    inst:DoTaskInTime(0, function()
        inst:DoPeriodicTask(0.1, function()
            if inst._parent and inst._parent:IsValid() then
                local x, y, z = inst._parent.Transform:GetWorldPosition()
                inst.Transform:SetPosition(x, y + 0.5, z)
            else
                inst:Remove()
            end
        end)
    end)

    -- Pulsar o light
    inst:DoPeriodicTask(0.2, function()
        inst._pulse = inst._pulse == 0.6 and 0.8 or 0.6
        inst.Light:SetIntensity(inst._pulse)
    end)

    -- Spawn sparkles ao redor
    inst:DoPeriodicTask(0.5, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local angle = math.random() * 2 * math.pi
            local radius = 0.8 + math.random() * 0.7
            local sparkle = SpawnPrefab("ice_sparkle")
            if sparkle then
                sparkle.Transform:SetPosition(
                    x + math.cos(angle) * radius,
                    y + math.random() * 0.5,
                    z + math.sin(angle) * radius
                )
            end
        else
            inst:Remove()
        end
    end)

    return inst
end

-- Aura ROXA SHADOW (só light + sombras)
local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light roxo pulsante
    inst.Light:Enable(true)
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.5)
    inst.Light:SetColour(0.5, 0.2, 0.8)

    inst._parent = nil
    inst._pulse = 0.5

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent imediatamente
    inst:DoTaskInTime(0, function()
        inst:DoPeriodicTask(0.1, function()
            if inst._parent and inst._parent:IsValid() then
                local x, y, z = inst._parent.Transform:GetWorldPosition()
                inst.Transform:SetPosition(x, y + 0.3, z)
            else
                inst:Remove()
            end
        end)
    end)

    -- Pulsar o light
    inst:DoPeriodicTask(0.25, function()
        inst._pulse = inst._pulse == 0.5 and 0.7 or 0.5
        inst.Light:SetIntensity(inst._pulse)
    end)

    -- Spawn partículas de sombra ao redor
    inst:DoPeriodicTask(0.6, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local angle = math.random() * 2 * math.pi
            local radius = 0.8 + math.random() * 0.7
            local puff = SpawnPrefab("shadow_puff_large_front")
            if puff then
                puff.Transform:SetPosition(
                    x + math.cos(angle) * radius,
                    y + 0.3,
                    z + math.sin(angle) * radius
                )
                puff.Transform:SetScale(0.3, 0.3, 0.3)
            end
        else
            inst:Remove()
        end
    end)

    return inst
end

-- AURA FOGO AZUL (para Bouncer) - VERSÃO SÓ LIGHT + SPARKLES
local function fn_coldfire()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light azul intenso pulsante
    inst.Light:Enable(true)
    inst.Light:SetRadius(4)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(0.8)
    inst.Light:SetColour(0.3, 0.6, 1)

    inst._parent = nil
    inst._pulse = 0.6

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent imediatamente
    inst:DoTaskInTime(0, function()
        inst:DoPeriodicTask(0.1, function()
            if inst._parent and inst._parent:IsValid() then
                local x, y, z = inst._parent.Transform:GetWorldPosition()
                inst.Transform:SetPosition(x, y + 0.2, z)
            else
                inst:Remove()
            end
        end)
    end)

    -- Pulsar o light (efeito de fogo)
    inst:DoPeriodicTask(0.15, function()
        inst._pulse = inst._pulse == 0.6 and 0.9 or 0.6
        inst.Light:SetIntensity(inst._pulse)
    end)

    -- Spawnar sparkles frequentemente (efeito de fogo azul)
    inst._sparkle_timer = inst:DoPeriodicTask(0.3, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- Múltiplos sparkles ao redor
            for i = 1, 3 do
                local angle = math.random() * 2 * math.pi
                local radius = 0.5 + math.random() * 1.0
                local sparkle = SpawnPrefab("ice_sparkle")
                if sparkle then
                    sparkle.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + math.random() * 0.5,
                        z + math.sin(angle) * radius
                    )
                end
            end
        else
            inst:Remove()
        end
    end)

    return inst
end

return Prefab("bot_aura_celestial", fn_celestial),
       Prefab("bot_aura_shadow", fn_shadow),
       Prefab("bot_aura_coldfire", fn_coldfire)
