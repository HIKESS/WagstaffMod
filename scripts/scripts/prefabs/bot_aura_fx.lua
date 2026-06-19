local assets =
{
    Asset("ANIM", "anim/fx_warmup.zip"),  -- Usar FX existente do DST como base
}

local function OnUpdate(inst)
    -- Seguir o parent (o bot)
    if inst._parent and inst._parent:IsValid() then
        local x, y, z = inst._parent.Transform:GetWorldPosition()
        inst.Transform:SetPosition(x, y + 0.5, z)
    else
        inst:Remove()
    end
end

-- Aura AZUL CELESTIAL
local function fn_celestial()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    -- Sem física, não colide
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("decor")

    -- Animação circular/aura
    inst.AnimState:SetBank("fx_warmup")
    inst.AnimState:SetBuild("fx_warmup")
    inst.AnimState:PlayAnimation("warmup", true)
    inst.AnimState:SetMultColour(0.4, 0.7, 1, 0.3)  -- Azul transparente
    inst.AnimState:SetAddColour(0.2, 0.3, 0.5, 0)   -- Brilho azul
    
    -- Scale para ficar ao redor do bot
    inst.Transform:SetScale(1.5, 1.5, 1.5)

    -- Light azul suave
    inst.Light:Enable(true)
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(0.8)
    inst.Light:SetIntensity(0.4)
    inst.Light:SetColour(0.4, 0.7, 1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- Atualizar posição para seguir parent
    inst._parent = nil
    inst:DoPeriodicTask(0.1, OnUpdate)

    -- Fade in
    inst.AnimState:SetDeltaTimeMultiplier(0.5)

    return inst
end

-- Aura ROXA SHADOW
local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("decor")

    inst.AnimState:SetBank("fx_warmup")
    inst.AnimState:SetBuild("fx_warmup")
    inst.AnimState:PlayAnimation("warmup", true)
    inst.AnimState:SetMultColour(0.3, 0.1, 0.5, 0.4)  -- Roxo escuro
    inst.AnimState:SetAddColour(0.2, 0, 0.3, 0)      -- Brilho roxo
    
    inst.Transform:SetScale(1.5, 1.5, 1.5)

    -- Light roxo suave
    inst.Light:Enable(true)
    inst.Light:SetRadius(2.5)
    inst.Light:SetFalloff(0.9)
    inst.Light:SetIntensity(0.3)
    inst.Light:SetColour(0.5, 0.2, 0.8)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._parent = nil
    inst:DoPeriodicTask(0.1, OnUpdate)

    return inst
end

-- Aura FOGO AZUL (para Bouncer)
local function fn_coldfire()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("decor")

    -- Usar animação de fogo mas com cor azul
    inst.AnimState:SetBank("fire")
    inst.AnimState:SetBuild("fire")
    inst.AnimState:PlayAnimation("loop", true)
    inst.AnimState:SetMultColour(0.3, 0.6, 1, 0.6)   -- Azul gelado
    inst.AnimState:SetAddColour(0.1, 0.2, 0.4, 0)    -- Brilho azul
    
    inst.Transform:SetScale(1.2, 1.2, 1.2)

    -- Light azul intenso
    inst.Light:Enable(true)
    inst.Light:SetRadius(2.5)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.5)
    inst.Light:SetColour(0.3, 0.6, 1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._parent = nil
    inst:DoPeriodicTask(0.1, OnUpdate)

    return inst
end

return Prefab("bot_aura_celestial", fn_celestial, assets),
       Prefab("bot_aura_shadow", fn_shadow, assets),
       Prefab("bot_aura_coldfire", fn_coldfire, assets)
