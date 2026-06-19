local WillUpgrader = Class(function(self, inst)
    self.inst = inst
end)

function WillUpgrader:DoUpgrade(v, doer, obj)
    v:PushEvent("levelup", 1)
        v.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
	v.components.health:DoDelta(v.components.health.maxhealth*50)
end

return WillUpgrader