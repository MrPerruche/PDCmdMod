-- ============================================================
-- dlcgarage: Permanently enable the DLC garage aesthetic.
--
-- Usage:
--   dlcgarage enable   -- Enable DLC aesthetic, persists on reload
--   dlcgarage disable  -- Disable and stop auto-applying
--   dlcgarage apply    -- Manually apply without saving state
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")
local ds = require("datastorage")

local SAVE_KEY = "dlcgarage_mode"

local function IsInGarage()
    local world = FindFirstOf("World")
    if not world then return false end
    local ok, name = pcall(function() return world:GetFullName() end)
    if not ok or not name then return false end
    return name:lower():find("garage") ~= nil
end

local function GetManager()
    local all = FindAllOf("BP_FIG_GarageMischiefManager_C")
    if not all or #all == 0 then return nil end
    for _, obj in ipairs(all) do
        local ok = pcall(function() return obj:GetClass() end)
        if ok then return obj end
    end
    return nil
end

local function ApplyAesthetic()
    if not IsInGarage() then
        uim.sendMessage("DLCGarage", "Not in garage - cannot apply DLC aesthetic here", uim.MessageTypes.ERR)
        return false
    end

    local mgr = GetManager()
    if not mgr then
        uim.sendMessage("DLCGarage", "BP_FIG_GarageMischiefManager_C not found", uim.MessageTypes.ERR)
        return false
    end

    local ok, err = pcall(function() mgr:ApplyIntroAdjustments() end)
    if not ok then
        uim.sendMessage("DLCGarage", "ApplyIntroAdjustments failed: " .. tostring(err), uim.MessageTypes.ERR)
        return false
    end

    uim.sendMessage("DLCGarage", "DLC garage aesthetic applied", uim.MessageTypes.CHATLIKE)
    return true
end

-- Auto-apply on garage load
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    if not ds.get(SAVE_KEY, false) then return end
    ExecuteWithDelay(1000, function()
        if not IsInGarage() then return end
        local mgr = GetManager()
        if not mgr then return end
        pcall(function() mgr:ApplyIntroAdjustments() end)
        uim.sendMessage("DLCGarage", "DLC garage aesthetic auto-applied", uim.MessageTypes.LOGS)
    end)
end)

-- Command registration
local cmd = cm.MANAGER:register(
    "dlcgarage",
    {
        description = "Toggle the DLC garage aesthetic permanently.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

cmd:branch(
    "enable",
    {
        description = "Enable the DLC garage aesthetic and auto-apply on every garage load.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ds.set(SAVE_KEY, true)
        ApplyAesthetic()
        uim.sendMessage("DLCGarage", "DLC garage aesthetic enabled and will persist on reload", uim.MessageTypes.CHATLIKE)
        return true
    end
)

cmd:branch(
    "disable",
    {
        description = "Disable the DLC garage aesthetic and stop auto-applying.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ds.set(SAVE_KEY, false)
        uim.sendMessage("DLCGarage", "DLC garage aesthetic disabled", uim.MessageTypes.CHATLIKE)
        return true
    end
)

cmd:branch(
    "apply",
    {
        description = "Manually apply the DLC garage aesthetic without changing saved state.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ApplyAesthetic()
        return true
    end
)

-- Auto-apply on startup if enabled
if ds.get(SAVE_KEY, false) then
    ExecuteWithDelay(2000, function()
        if not IsInGarage() then return end
        local mgr = GetManager()
        if not mgr then return end
        pcall(function() mgr:ApplyIntroAdjustments() end)
        uim.sendMessage("DLCGarage", "DLC garage aesthetic auto-applied on startup", uim.MessageTypes.LOGS)
    end)
end