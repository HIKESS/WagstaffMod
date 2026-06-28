local _G = _G or GLOBAL

local assets =
{
--	Asset("ANIM", "anim/staff_projectile.zip"),
}

local function OnHit(inst, owner, target)
    SpawnPrefab("impact").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end

local function OnThrown(inst)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst:DoTaskInTime(5, inst.Remove)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    if not TheWorld.ismastersim then
        return inst
    end

    inst.AnimState:SetBank("projectile")
    inst.AnimState:SetBuild("staff_projectile")
    inst.AnimState:PlayAnimation("fire_spin_loop", true)

    inst.Transform:SetScale(1, .25, 1)

    inst:AddTag("projectile")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst.persists = false

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(80)
    inst.components.projectile:SetHoming(true)
    inst.components.projectile:SetHitDist(2)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(OnThrown)
    inst.components.projectile:SetLaunchOffset(Vector3(2, 2, 0))

    return inst
end

return Prefab("common/inventory/esentry_bullet", fn, assets)
