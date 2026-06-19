-- AURA V3 - Efeitos DISTINTOS e FORTES para cada bot!
-- Usa apenas builds do DST que existem e funcionam

-- ========================================================================
-- BOUNCER - EFEITO FUNÇA/FUMAÇA Densa (coldbreath + sparkles)
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

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.2, z)
        else
            inst:Remove()
        end
    end)

    -- PULSO suave
    local pulse = 0
    inst:DoPeriodicTask(0.1, function()
        pulse = pulse + 0.4
        local intensity = 0.6 + math.sin(pulse) * 0.2
        inst.Light:SetIntensity(intensity)
    end)

    -- FUNÇA Densa usando coldbreath (funciona!)
    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- Múltiplas funças ao redor
            for i = 1, 2 do
                local angle = math.random() * 2 * math.pi
                local radius = 0.4 + math.random() * 0.6
                local breath = SpawnPrefab("coldbreath")
                if breath then
                    breath.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + 0.1,
                        z + math.sin(angle) * radius
                    )
                    -- Azul
                    if breath.AnimState then
                        breath.AnimState:SetMultColour(0.3, 0.6, 1, 0.6)
                        breath.AnimState:SetAddColour(0.1, 0.2, 0.4, 0)
                    end
                end
            end
        end
    end)

    -- Sparkles frequentes
    inst:DoPeriodicTask(0.3, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            for i = 1, 2 do
                local angle = math.random() * 2 * math.pi
                local r = 0.8 + math.random() * 0.5
                local sparkle = SpawnPrefab("ice_sparkle")
                if sparkle then
                    sparkle.Transform:SetPosition(
                        x + math.cos(angle) * r,
                        y + 0.3 + math.random() * 0.4,
                        z + math.sin(angle) * r
                    )
                end
            end
        end
    end)

    return inst
end

-- ========================================================================
-- BUSTER - EFEITO SPARKS Intenso (sparks + light elétrico)
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

    -- SPARKS INTENSOS - a cada 0.2 segundos!
    inst:DoPeriodicTask(0.2, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- 2-3 sparks de uma vez
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
                end
            end
        end
    end)

    -- Eletricidade adicional - fx electrocute
    inst:DoPeriodicTask(0.8, function()
        if inst._parent and inst._parent:IsValid() and math.random() < 0.6 then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local zap = SpawnPrefab("sparks_fx")
            if zap then
                zap.Transform:SetPosition(x, y + 0.5, z)
            end
        end
    end)

    -- Pulso rápido
    local pulse = 0
    inst:DoPeriodicTask(0.15, function()
        pulse = pulse + 1
        if pulse % 3 == 0 then  -- Pico de luz
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
-- BUTLER - EFEITO SPARKS Suave (mas visível)
-- ========================================================================
local function fn_butler()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light azul suave
    inst.Light:Enable(true)
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.5)
    inst.Light:SetColour(0.5, 0.75, 1)

    inst._parent = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.4, z)
        else
            inst:Remove()
        end
    end)

    -- SPARKS suaves - a cada 0.5 segundos
    inst:DoPeriodicTask(0.5, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- 1-2 sparks
            for i = 1, 1 + math.random(1) do
                local angle = math.random() * 2 * math.pi
                local radius = 0.6 + math.random() * 0.5
                local spark = SpawnPrefab("sparks")
                if spark then
                    spark.Transform:SetPosition(
                        x + math.cos(angle) * radius,
                        y + 0.3 + math.random() * 0.4,
                        z + math.sin(angle) * radius
                    )
                end
            end
        end
    end)

    -- Sparkles de gelo (suave)
    inst:DoPeriodicTask(1.0, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local angle = math.random() * 2 * math.pi
            local r = 0.8
            local sparkle = SpawnPrefab("ice_sparkle")
            if sparkle then
                sparkle.Transform:SetPosition(
                    x + math.cos(angle) * r,
                    y + 0.4,
                    z + math.sin(angle) * r
                )
            end
        end
    end)

    -- Pulso muito suave
    local pulse = 0
    inst:DoPeriodicTask(0.3, function()
        pulse = pulse + 0.2
        local intensity = 0.4 + math.sin(pulse) * 0.1
        inst.Light:SetIntensity(intensity)
    end)

    return inst
end

-- ========================================================================
-- BATTERY - EFEITO ORBITAL Forte (satélite + luz central)
-- ========================================================================
local function fn_battery()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light central FORTE
    inst.Light:Enable(true)
    inst.Light:SetRadius(5)
    inst.Light:SetFalloff(0.4)
    inst.Light:SetIntensity(0.8)
    inst.Light:SetColour(0.3, 0.6, 1)

    inst._parent = nil
    inst._orbit_angle = 0

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Seguir parent (altura mais alta - satélite)
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.6, z)
        else
            inst:Remove()
        end
    end)

    -- ORBITA de sparkles - muito visível!
    inst:DoPeriodicTask(0.15, function()
        if inst._parent and inst._parent:IsValid() then
            inst._orbit_angle = inst._orbit_angle + 0.8
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            local radius = 1.2
            local angle = inst._orbit_angle
            
            -- Spawn sparkle orbital
            local sparkle = SpawnPrefab("ice_sparkle")
            if sparkle then
                sparkle.Transform:SetPosition(
                    x + math.cos(angle) * radius,
                    y + 0.8 + math.sin(angle * 2) * 0.3,
                    z + math.sin(angle) * radius
                )
                sparkle.Transform:SetScale(0.8, 0.8, 0.8)
            end
            
            -- Spark adicional (eletricidade)
            if math.random() < 0.4 then
                local spark = SpawnPrefab("sparks")
                if spark then
                    spark.Transform:SetPosition(
                        x + math.cos(angle + math.pi) * radius * 0.7,
                        y + 0.6,
                        z + math.sin(angle + math.pi) * radius * 0.7
                    )
                end
            end
        end
    end)

    -- Núcleo central - mais sparkles
    inst:DoPeriodicTask(0.4, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- Sparkles no centro
            for i = 1, 2 do
                local angle = math.random() * 2 * math.pi
                local r = math.random() * 0.5
                local sparkle = SpawnPrefab("ice_sparkle")
                if sparkle then
                    sparkle.Transform:SetPosition(
                        x + math.cos(angle) * r,
                        y + 0.5 + math.random() * 0.3,
                        z + math.sin(angle) * r
                    )
                end
            end
        end
    end)

    -- Pulso de energia
    local pulse = 0
    inst:DoPeriodicTask(0.2, function()
        pulse = pulse + 0.5
        local intensity = 0.6 + math.sin(pulse) * 0.3
        inst.Light:SetIntensity(intensity)
    end)

    return inst
end

-- ========================================================================
-- SHADOW - Efeito sombrio DENso
-- ========================================================================
local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    -- Light roxo
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

    -- Seguir parent
    inst:DoPeriodicTask(0.05, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, y + 0.3, z)
        else
            inst:Remove()
        end
    end)

    -- Partículas de sombra densas
    inst:DoPeriodicTask(0.4, function()
        if inst._parent and inst._parent:IsValid() then
            local x, y, z = inst._parent.Transform:GetWorldPosition()
            -- 2-3 puffs de sombra
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

    -- Pulso sombrio
    local pulse = 0
    inst:DoPeriodicTask(0.25, function()
        pulse = pulse + 0.3
        local intensity = 0.3 + math.sin(pulse) * 0.15
        inst.Light:SetIntensity(intensity)
    end)

    return inst
end

return Prefab("bot_aura_bouncer", fn_bouncer),
       Prefab("bot_aura_buster", fn_buster),
       Prefab("bot_aura_butler", fn_butler),
       Prefab("bot_aura_battery", fn_battery),
       Prefab("bot_aura_shadow", fn_shadow)
