local PortableWillyBot = Class(function(self, inst)
    self.inst = inst
    self.ondismantlefn = nil
end)

function PortableWillyBot:SetOnDismantleFn(fn)
    self.ondismantlefn = fn
end

function PortableWillyBot:Dismantle(doer)
    if self.ondismantlefn ~= nil then
        self.ondismantlefn(self.inst, doer)
    end
end

return PortableWillyBot
