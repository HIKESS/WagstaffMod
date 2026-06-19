local _G = _G or GLOBAL

local function onworkable(self)
    if self.maxwork ~= nil and self.workleft < self.maxwork and self.workable then
        self.inst:AddTag("workrepairable")
    else
        self.inst:RemoveTag("workrepairable")
    end
    if self.action ~= nil then
        if self.workleft > 0 and self.workable then
            self.inst:AddTag(self.action.id.."_workable")
        else
            self.inst:RemoveTag(self.action.id.."_workable")
        end
    end
end

local function onaction(self, action, old_action)
    if self.workleft > 0 and self.workable then
        if old_action ~= nil then
            self.inst:RemoveTag(old_action.id.."_workable")
        end
        if action ~= nil then
            self.inst:AddTag(action.id.."_workable")
        end
    end
end

local EngieWorkable = _G.Class(function(self, inst)
    self.inst = inst
    self.onwork = nil
    self.onfinish = nil
    self.workleft = 10
    self.maxwork = -1
    self.action = _G.ACTIONS.CHOP
    self.savestate = false
    self.workable = true
end,
nil,
{
    workleft = onworkable,
    maxwork = onworkable,
    action = onaction,
    workable = onworkable,
})

function EngieWorkable:OnRemoveFromEntity()
    self.inst:RemoveTag("workrepairable")
    if self.action ~= nil then
        self.inst:RemoveTag(self.action.id.."_workable")
    end
end

function EngieWorkable:GetDebugString()
    return "workleft: "..tostring(self.workleft)
        .." maxwork: "..tostring(self.maxwork)
        .." workable: "..tostring(self.workable)
end

function EngieWorkable:SetWorkAction(act)
    self.action = act
end

function EngieWorkable:GetWorkAction()
    return self.action
end

function EngieWorkable:Destroy(destroyer)
    if self:CanBeWorked() then
        self:WorkedBy(destroyer, self.workleft)
    end
end

function EngieWorkable:SetWorkable(able)
    self.workable = able
end

function EngieWorkable:SetWorkLeft(work)
    self.workable = true
    self.workleft = self.maxwork > 0 and math.clamp(work or 10, 1, self.maxwork) or math.max(1, work or 10)
end

function EngieWorkable:CanBeWorked()
    return self.workable and self.workleft > 0
end

function EngieWorkable:SetOnLoadFn(fn)
    if type(fn) == "function" then
        self.onloadfn = fn
    end
end

function EngieWorkable:SetMaxWork(work)
    self.maxwork = math.max(1, work or 10)
end

function EngieWorkable:OnSave()
    return self.savestate
        and {
                maxwork = self.maxwork,
                workleft = self.workleft,
            }
        or {}
end

function EngieWorkable:OnLoad(data)
    self.workleft = data.workleft or self.workleft
    self.maxwork = data.maxwork or self.maxwork
    if self.onloadfn ~= nil then
        self.onloadfn(self.inst, data)
    end
end

function EngieWorkable:WorkedBy(worker, numworks)
    numworks = numworks or 1
    self.workleft = self.workleft - numworks
    self.lastworktime = _G.GetTime()

    worker:PushEvent("working", { target = self.inst })
    self.inst:PushEvent("worked", { worker = worker, workleft = self.workleft })

    if self.onwork ~= nil then
        self.onwork(self.inst, worker, self.workleft)
    end

    if self.workleft <= 0 then
        if self.onfinish ~= nil then
            self.onfinish(self.inst, worker)
        end
        self.inst:PushEvent("workfinished", { worker = worker })

        worker:PushEvent("finishedwork", { target = self.inst, action = self.action })
    end
end

function EngieWorkable:SetOnWorkCallback(fn)
    self.onwork = fn
end

function EngieWorkable:SetOnFinishCallback(fn)
    self.onfinish = fn
end

return EngieWorkable