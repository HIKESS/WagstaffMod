local assets =
{
    Asset("ANIM", "anim/willbot_attack.zip"),
    Asset("SOUND", "sound/chess.fsb"),
}

local function onupdate(inst, dt)

    inst.Light:SetIntensity(inst.i)
    inst.i = inst.i - dt * 2
    if inst.i <= 0 then
            inst.task:Cancel()
            inst.task = nil
    end
end

local function no_aggro(attacker, target)
	if attacker == nil or not attacker:IsValid() then return false end
	local targets_target = target.components.combat ~= nil and target.components.combat.target or nil
	return targets_target ~= nil and targets_target:IsValid() and targets_target ~= attacker
			and (GetTime() - target.components.combat.lastwasattackedbytargettime) < 4
			and (targets_target.components.health ~= nil and not targets_target.components.health:IsDead())
end


local function OnPreHit(inst, attacker, target)
	target.components.combat.temp_disable_aggro = no_aggro(attacker, target)
end


local function OnHit(inst, owner, target)
    if target ~= nil and target:IsValid() and target.components.combat ~= nil then
	target.components.combat.temp_disable_aggro = false
        SpawnPrefab("electrichitsparks"):AlignToTarget(target, inst, true)
    	inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/shotexplo")
	--target.components.combat:GetAttacked(no_aggro(owner, target) == false and owner or nil , 24 , inst, "electric")
    end
    inst:Remove()
end

local function OnAnimOver(inst)
    inst:DoTaskInTime(.3, inst.Remove)
end

local function OnThrown(inst)
    inst:ListenForEvent("animover", OnAnimOver)
end



local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    --inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("willbot_attack")
    inst.AnimState:SetBuild("willbot_attack")
    inst.AnimState:PlayAnimation("idle")
  --  inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(1)
  --  inst.Transform:SetScale(0.6, 0.6, 0.6)
        inst.AnimState:SetMultColour(0, 0, 0, 0)
	inst:AddComponent("colourtweener")
	inst.components.colourtweener:StartTween({ 1, 1, 1, 1 }, 0.4)
    --projectile (from projectile component) added to pristine state for optimization


    inst.entity:AddLight()

    inst.Light:Enable(true)
    inst.Light:SetRadius(1)
    inst.Light:SetFalloff(1)
    inst.Light:SetIntensity(.9)
    inst.Light:SetColour(235 / 255, 121 / 255, 75 / 255)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false


    local dt = 1 / 20
    inst.i = .9
    inst.sound = inst.SoundEmitter ~= nil
    inst.task = inst:DoPeriodicTask(dt, onupdate, nil, dt)

    return inst
end

local function PlayHitSound(proxy)
    local inst = CreateEntity()

    --[[Non-networked entity]]

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/shotexplo")

    inst:Remove()
end

local function hit_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    --Dedicated server does not need to spawn the local fx
    if not TheNet:IsDedicated() then
        --Delay one frame in case we are about to be removed
        inst:DoTaskInTime(0, PlayHitSound)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:DoTaskInTime(.5, inst.Remove)

    return inst
end

local function projectile()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    --inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("willbot_attack")
    inst.AnimState:SetBuild("willbot_attack")
    inst.AnimState:PlayAnimation("idle")
   -- inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(1)
  --  inst.Transform:SetScale(0.6, 0.6, 0.6)
    --projectile (from projectile component) added to pristine state for optimization

    inst:AddTag("projectile")


    inst.entity:AddLight()

    inst.Light:Enable(true)
    inst.Light:SetRadius(1)
    inst.Light:SetFalloff(1)
    inst.Light:SetIntensity(.9)
    inst.Light:SetColour(0.3, 0.6, 1) -- Azul lunar

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end


    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(30)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetHitDist(1)
    inst.components.projectile:SetOnPreHitFn(OnPreHit)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(OnThrown)
    --inst.components.projectile.has_damage_set = true


    inst.persists = false
    local dt = 1 / 20
    inst.i = .9
    inst.sound = inst.SoundEmitter ~= nil
    inst.task = inst:DoPeriodicTask(dt, onupdate, nil, dt)

    return inst
end

return Prefab("william_chargeup", fn, assets),
	Prefab("william_charge", projectile, assets),
    Prefab("william_charge_hit", hit_fn)