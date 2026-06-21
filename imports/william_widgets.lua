local STRINGS = GLOBAL.STRINGS
local require = GLOBAL.require
local Vector3 = GLOBAL.Vector3

--------------------------------------------------------------------------------
-- [[set container]]
--------------------------------------------------------------------------------
local containers = GLOBAL.require "containers"
local cooking = GLOBAL.require "cooking"

local params = {}

--==================================================================================
-- BUTLER BOT LVL 1: Original layout - 3 Crockpot slots only
-- Compact layout matching original William Toymaker mod
--==================================================================================
params.williambutler =
{
    widget =
    {
        slotpos =
        {
            -- Row 1: 3 Crockpot slots (compact positions)
            Vector3(-(64 + 12), 24, 0),
            Vector3(0, 24, 0),
            Vector3(64 + 12, 24, 0),
        },
        animbank = "ui_chest_3x2",
        animbuild = "ui_chest_3x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
        buttoninfo =
        {
            text = "Cook",
            position = Vector3(0, -48, 0), -- Button below slots
        }
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.williambutler.itemtestfn(container, item, slot)
    -- Only cookable items allowed
    return item:HasTag("cookable") and not container.inst:HasTag("burnt")
end

--==================================================================================
-- BUTLER BOT LVL 2: Upgraded version - 3 Cook slots + built-in heater
-- Emits light, warmth, and smoke FX (like a walking campfire).
--==================================================================================
params.williambutler2 =
{
    widget =
    {
        slotpos =
        {
            -- 3 Crockpot slots (Cook) - vanilla ui_chest_3x2 positions
            Vector3(-80, 40, 0),
            Vector3(0, 40, 0),
            Vector3(80, 40, 0),
        },
        animbank = "ui_chest_3x2",
        animbuild = "ui_chest_3x2",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
        buttoninfo =
        {
            text = "Cook",
            position = Vector3(0, -165, 0), -- Below slots
        }
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.williambutler2.itemtestfn(container, item, slot)
    -- Only cookable items allowed
    return item:HasTag("cookable") and not container.inst:HasTag("burnt")
end

function params.williambutler.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
       GLOBAL.BufferedAction(doer, inst, GLOBAL.ACTIONS.WILLIAM_ACTION):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        GLOBAL.SendRPCToServer(GLOBAL.RPC.DoWidgetButtonAction, GLOBAL.ACTIONS.WILLIAM_ACTION.code, inst, GLOBAL.ACTIONS.WILLIAM_ACTION.mod_name)
    end
end

function params.williambutler.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil
end

-- Butler2 uses same button functions
params.williambutler2.widget.buttoninfo = params.williambutler.widget.buttoninfo

--==================================================================================
-- BRUTE BOT LVL 3: Storage container - 9 slots (3x3)
--==================================================================================
params.williambrute3 =
{
    widget =
    {
        slotpos =
        {
            -- 3x3 grid matching standard treasurechest layout
            Vector3(-81 - 76, 32 + 36, 0),
            Vector3(-81, 32 + 36, 0),
            Vector3(-81 + 76, 32 + 36, 0),
            Vector3(-81 - 76, 32 - 36 - 8, 0),
            Vector3(-81, 32 - 36 - 8, 0),
            Vector3(-81 + 76, 32 - 36 - 8, 0),
            Vector3(-81 - 76, 32 - 36 - 8 - 72, 0),
            Vector3(-81, 32 - 36 - 8 - 72, 0),
            Vector3(-81 + 76, 32 - 36 - 8 - 72, 0),
        },
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    acceptsstacks = false,
    type = "chest",
}

containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS,
    params.williambutler.widget.slotpos ~= nil and #params.williambutler.widget.slotpos or 0,
    params.williambutler2.widget.slotpos ~= nil and #params.williambutler2.widget.slotpos or 0,
    params.williambrute3.widget.slotpos ~= nil and #params.williambrute3.widget.slotpos or 0)

local containers_widgetsetup = containers.widgetsetup

function containers.widgetsetup(container, prefab, data)
    local t = prefab or container.inst.prefab
    if t == "williambutler" or t == "williambutler2" or t == "williambrute3" then
        local t = params[t]
        if t ~= nil then
            for k, v in pairs(t) do
                container[k] = v
            end
            local numslots = container.slots ~= nil and #container.slots or 0
            if numslots == 0 then
                container:SetNumSlots(t.widget.slotpos ~= nil and #t.widget.slotpos or 0)
            end
        end
    else
        return containers_widgetsetup(container, prefab, data)
    end
end

local _GetAdjectivedName = GLOBAL.EntityScript.GetAdjectivedName
function GLOBAL.EntityScript:GetAdjectivedName()
    local name = self:GetBasicDisplayName()
    if self:HasTag("willminion") then
        if self:HasTag("level3") then
        return GLOBAL.ConstructAdjectivedName(self, name, "Brilliant")
        elseif self:HasTag("level2") then
        return GLOBAL.ConstructAdjectivedName(self, name, "Boastful")
        elseif self:HasTag("level1") then
        return GLOBAL.ConstructAdjectivedName(self, name, "Bolstered")
        else
    return _GetAdjectivedName(self)
        end
        else
    return _GetAdjectivedName(self)
    end
end