-- AURA V5 - Usando APENAS FX reais verificados do jogo!
-- Baseado em pesquisa dos arquivos do DST

-- ========================================================================
-- BUTLER - Elegante: moonpulse + sparkles suaves
-- ========================================================================
local function fn_butler()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:Enable(true)
    inst.Light:SetRadius(2.5)
    inst.Light:SetFalloff(0.8)
    inst.Light:SetIntensity(0.4)
    inst.Light:SetColour(0.75, 0.85, 1.0)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent (0.15s = 6.7x/s - suave o bastante)
    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    -- Butler sem aura visível complexa (só luz)
    return inst
end

-- ========================================================================
-- BUSTER - moonpulse constante + efeitos de batalha lunar
-- ========================================================================
local function fn_buster()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:Enable(true)
    inst.Light:SetRadius(1.8)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.4)
    inst.Light:SetColour(0.8, 0.95, 1.0)  -- Gelo celestial

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent (0.15s = 6.7x/s - suave o bastante)
    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    -- Buster sem aura visível (só luz)
    return inst
end

-- ========================================================================
-- BOUNCER - SUPER SAIYAN: Fogo lunar cobrindo o bot (estilo Battery)
-- ========================================================================
local function fn_bouncer()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:Enable(true)
    inst.Light:SetRadius(2.0)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.5)
    inst.Light:SetColour(0.65, 0.88, 1.0)  -- Gelo celestial mais forte

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent (altura do corpo) - 0.15s = 6.7 updates/s
    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    -- Aura no corpo do Bouncer (só quando parent ativo)
    inst:DoPeriodicTask(1.5, function()
        if inst._parent and inst._parent:IsValid() and inst._parent.on ~= false then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local fx = SpawnPrefab("moonpulse2_fx")
            if fx then
                fx.Transform:SetPosition(x, y + 0.3, z)
                fx.Transform:SetScale(0.35, 0.35, 0.35)  -- Ajustado
            end
        end
    end)

    return inst
end

-- ========================================================================
-- BATTERY - 6 mini explosões orbitando (efeito núcleo atômico)
-- ========================================================================
local function fn_battery()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:Enable(true)
    inst.Light:SetRadius(2.5)
    inst.Light:SetFalloff(0.6)
    inst.Light:SetIntensity(0.5)
    inst.Light:SetColour(0.8, 0.92, 1.0)  -- Gelo celestial

    inst._parent = nil
    inst._orbit_angles = {0, 1.05, 2.1, 3.15, 4.2, 5.25}  -- 6 ângulos separados
    inst._orbit_speeds = {0.8, 0.6, 1.0, 0.7, 0.9, 0.5}   -- Velocidades mais lentas
    inst._orbit_radii = {0.6, 0.8, 0.5, 0.9, 0.7, 0.65}
    inst._orbit_heights = {0.4, 0.7, 0.3, 0.8, 0.5, 0.6}

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent (altura na cabeça) - 0.15s = 6.7 updates/s
    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.6, z)
        else
            inst:Remove()
        end
    end)

    -- Battery sem aura visível complexa (só luz)
    return inst
end

-- ========================================================================
-- SHADOW - Efeitos de sombra VERIFICADOS
-- ========================================================================
local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:Enable(true)
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(0.6)
    inst.Light:SetIntensity(0.3)
    inst.Light:SetColour(0.3, 0.1, 0.5)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    -- Usar FX de sombra do jogo
    inst:DoPeriodicTask(0.6, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local fx = SpawnPrefab("shadow_puff_large_front")
            if fx then
                local angle = math.random() * 2 * math.pi
                local r = 0.6 + math.random() * 0.6
                fx.Transform:SetPosition(
                    x + math.cos(angle) * r,
                    y + 0.2 + math.random() * 0.3,
                    z + math.sin(angle) * r
                )
                fx.Transform:SetScale(0.3, 0.3, 0.3)
            end
        end
    end)

    return inst
end

return Prefab("bot_aura_butler", fn_butler),
       Prefab("bot_aura_buster", fn_buster),
       Prefab("bot_aura_bouncer", fn_bouncer),
       Prefab("bot_aura_battery", fn_battery),
       Prefab("bot_aura_shadow", fn_shadow)
