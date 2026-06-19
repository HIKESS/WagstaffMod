local WillyRaise = Class(function(self, inst)
    self.inst = inst
    self.onrisefn = nil
    self.onlowerfn = nil
end)

function WillyRaise:SetOnRiseFn(fn)
    self.onrisefn = fn
end

function WillyRaise:Rise(doer, instant)
    if self.onrisefn ~= nil then
        self.onrisefn(self.inst, doer)
    end
end

function WillyRaise:SetOnLowerFn(fn)
    self.onlowerfn = fn
end

function WillyRaise:Lower(doer, instant)
    if self.onlowerfn ~= nil then
        self.onlowerfn(self.inst, doer, instant)
    end
end

return WillyRaise
