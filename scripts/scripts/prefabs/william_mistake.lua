local assets =
{
    Asset("ANIM", "anim/wil.zip"),
    Asset("ANIM", "anim/sil.zip"),
    Asset("ANIM", "anim/hil.zip"),
}

local prefabs =
{
    "explode_small",
}

local function OnIgniteFn(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/blackpowder_fuse_LP", "hiss")
    DefaultBurnFn(inst)
end

local function OnExtinguishFn(inst)
    inst.SoundEmitter:KillSound("hiss")
    DefaultExtinguishFn(inst)
end

local function OnExplodeFn(inst)
    inst.SoundEmitter:KillSound("hiss")
    SpawnPrefab("explode_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
end

local function DoTalk(inst)
    inst.lines = inst.lines + 1
    inst.AnimState:PlayAnimation("dial_loop")
    inst.components.talker:Say("AAAAAAAAAAAAAA")
    local time = 0.5/inst.lines
    inst:DoTaskInTime(time, DoTalk)
    inst.SoundEmitter:PlaySound("hookline_2/creatures/wobster/scared")
end

local function StartTalking(inst)
    inst.lines = 1
    DoTalk(inst)
    inst:DoTaskInTime(3, function() inst.components.burnable:Ignite(true) inst.AnimState:SetBuild("sil") end)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wil")
    inst.AnimState:PlayAnimation("idle")
        inst.AnimState:Hide("ARM_carry")

    inst:AddTag("explosive")


        inst:AddComponent("talker")
        inst.components.talker.offset = Vector3(0, -400, 0)


    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_HUGE*5

    MakeSmallBurnable(inst, 3 + math.random() * 2)
    MakeSmallPropagator(inst)
    --V2C: Remove default OnBurnt handler, as it conflicts with
    --explosive component's OnBurnt handler for removing itself
    inst.components.burnable:SetOnBurntFn(nil)
    inst.components.burnable:SetOnIgniteFn(OnIgniteFn)
    inst.components.burnable:SetOnExtinguishFn(OnExtinguishFn)

    inst:AddComponent("explosive")
    inst.components.explosive:SetOnExplodeFn(OnExplodeFn)
    inst.components.explosive.explosivedamage = 1

    inst:DoTaskInTime(0.1, StartTalking)

    return inst
end

return Prefab("william_mistake", fn, assets, prefabs)
