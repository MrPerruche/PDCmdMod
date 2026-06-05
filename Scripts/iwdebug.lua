-- ============================================================
-- widget: Spawn and manage debug widgets.
--
-- Usage:
--   widget open <relative_path>
--     Opens a widget relative to /Game/Systems/DebugTools/
--     e.g. widget open UMG_StatusEffectTools
--
--   widget fullpath <full_path>
--     Opens a widget by full asset path.
--     e.g. widget fullpath /Game/Systems/DebugTools/UMG_QuirkDebugger.UMG_QuirkDebugger_C
--
--   widget close <index>
--     Closes a specific widget by index (shown in widget list).
--
--   widget closeall
--     Closes all widgets opened by this command.
--
--   widget list
--     Lists all currently open widgets.
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local activeWidgets = {}  -- { index, path, widget }
local nextIndex = 1

local BASE_PATHS = {
    "/Game/Systems/DebugTools/",
    "/PDFeature_Fig/Systems/DebugTools/"
}
local EXTENDED_BASE_PATHS = {
    "/Game/Systems/DebugTools/",
    "/PDFeature_Fig/Systems/DebugTools/"
}

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    activeWidgets = {}
    nextIndex = 1
    uim.sendMessage("Widget", "Level reloaded, widget list cleared", uim.MessageTypes.LOGS)
end)

local function GetPlayerController()
    local all = FindAllOf("PlayerController")
    if not all or #all == 0 then return nil end
    for _, pc in ipairs(all) do
        local ok = pcall(function() return pc:GetClass() end)
        if ok then return pc end
    end
    return nil
end

-- local function SetUIInputMode(PC)
--     -- Try UIOnly first, fall back to GameAndUI
--     local ok, err = pcall(function()
--         PC:SetInputMode_UIOnlyEx(nil, 0, true)
--     end)
--     if not ok then
--         pcall(function()
--             PC:SetInputMode_UIOnly(nil, true)
--         end)
--     end
--     -- Show cursor
--     pcall(function() PC.bShowMouseCursor = true end)
-- end

-- local function SetGameInputMode(PC)
--     local ok, err = pcall(function()
--         PC:SetInputMode_GameOnly()
--     end)
--     if not ok then
--         uim.sendMessage("Widget", "Failed to restore game input: " .. tostring(err), uim.MessageTypes.LOGS)
--     end
--     pcall(function()
--         PC.bShowMouseCursor = false 
--     end)
-- end

local function OpenWidget(fullPath)
    local PC = GetPlayerController()
    if not PC then
        uim.sendMessage("Widget", "No valid PlayerController found", uim.MessageTypes.ERR)
        return false
    end

    local ok, result = pcall(function()
        local WidgetClass = LoadAsset(fullPath)
        if not WidgetClass then return nil end

        local w = StaticConstructObject(WidgetClass, PC)
        if not w then return nil end
        w:AddToViewport(0)
        
        return w
    end)

    if not ok or not result then
        uim.sendMessage("Widget", "Failed to open: " .. fullPath, uim.MessageTypes.LOGS)
        return false
    end

    local entry = { index = nextIndex, path = fullPath, widget = result }
    table.insert(activeWidgets, entry)
    nextIndex = nextIndex + 1

    -- Switch to UI input mode so widget receives keypresses
    -- SetUIInputMode(PC)

    uim.sendMessage("Widget", "[" .. entry.index .. "] Opened: " .. fullPath, uim.MessageTypes.CHATLIKE)
    return true
end

local function CloseWidget(index)
    for i, entry in ipairs(activeWidgets) do
        if entry.index == index then
            local ok, err = pcall(function() entry.widget:RemoveFromParent() end)
            if ok then
                uim.sendMessage("Widget", "[" .. index .. "] Closed: " .. entry.path, uim.MessageTypes.CHATLIKE)
            else
                uim.sendMessage("Widget", "RemoveFromParent failed: " .. tostring(err), uim.MessageTypes.ERR)
            end
            table.remove(activeWidgets, i)

            -- Restore game input only if no widgets remain
            -- if #activeWidgets == 0 then
            --     local PC = GetPlayerController()
            --     if PC then SetGameInputMode(PC) end
            -- end
            return
        end
    end
    uim.sendMessage("Widget", "No widget with index " .. index, uim.MessageTypes.ALERT)
end

local function CloseAll()
    if #activeWidgets == 0 then
        uim.sendMessage("Widget", "No open widgets", uim.MessageTypes.CHATLIKE)
        return
    end
    for _, entry in ipairs(activeWidgets) do
        pcall(function() entry.widget:RemoveFromParent() end)
    end
    local count = #activeWidgets
    activeWidgets = {}

    -- Restore game input
    -- local PC = GetPlayerController()
    -- if PC then SetGameInputMode(PC) end

    uim.sendMessage("Widget", "Closed " .. count .. " widget(s)", uim.MessageTypes.CHATLIKE)
end

local function ListWidgets()
    if #activeWidgets == 0 then
        uim.sendMessage("Widget", "No open widgets", uim.MessageTypes.CHATLIKE)
        return
    end
    local lines = "Open widgets:\n"
    for _, entry in ipairs(activeWidgets) do
        lines = lines .. "  [" .. entry.index .. "] " .. entry.path .. "\n"
    end
    uim.sendMessage("Widget", lines, uim.MessageTypes.CHATLIKE, 20.0, true)
end


local function HandleTips()
    local tips = "You may find widgets by going through game files using FModel,\n" ..
                 "But given you may not know how to do this kind of stuff, here are some useful widgets you may be interested in:\n" ..
                 "  UMG_ActorTools - Actor tools\n" ..
                 "  UMG_Debug_ChartTools - Create custom rewoven disks\n" ..
                 "  UMG_QuirkDebugger - View and manage active quirks\n" ..
                 "  UMG_StatusEffectTools - Mess with game and weather events (misleading name)\n" ..
                 "  RouteTools/UMG_RouteTools - Edit current junction data\n" ..
                 "  RunModDebug/UMG_Debug_RouteModDebugger - See route modifiers list. Seemingly non functional, consider route tools instead.\n" ..
                 "  [WitW DLC] UMG_ArtifactDebugger - Spawn prebuilt and custom artifacts\n" ..
                 "  [WitW DLC] UMG_DebugFigMischief - Make your garage look cooler"
    uim.sendMessage("Widget", tips, uim.MessageTypes.CHATLIKE, 30.0, true)
end



local cmd = cm.MANAGER:register(
    "widget",
    {
        description = "Open any widgets. There are very useful widgets regarding custom artifacts, zone conditions, game events, and much more.",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

local cmd_open = cmd:branch(
    "open",
    {
        description = "Opens a widget relative to /Game/Systems/DebugTools/, eg. 'widget open UMG_StatusEffectTools'",
        args_syntax = "<relative_path>",
        flags_syntax = "--extended"
    },
    function(args, flags)
        local pathList = EXTENDED_BASE_PATHS and (flags and flags["extended"]) or BASE_PATHS
        local path = args[1]

        if not path then
            HandleHelp(uim.MessageTypes.CHATLIKE)
            return true
        end

        local name = path
        name = name:gsub("_C$", "")

        -- extract just the filename part after any slashes for the asset name
        local assetName = name:match("([^/]+)$")

        local success = false

        for _, basePath in ipairs(pathList) do
            local fullPath = basePath .. name .. "." .. assetName .. "_C"

            if OpenWidget(fullPath) then
                success = true
                break
            end
        end

        if not success then
            uim.sendMessage("Widget", "Failed to open widget: " .. name, uim.MessageTypes.ERR)
        end

        return true
    end
)

local cmd_fullpath = cmd:branch(
    "fullpath",
    {
        description = "Opens a widget by full class path, eg. 'widget fullpath /Game/Systems/DebugTools/UMG_QuirkDebugger.UMG_QuirkDebugger_C'",
        args_syntax = "<full_path>",
        flags_syntax = nil
    },
    function(args, flags)
        OpenWidget(args[1])
        return true
    end
)

local cmd_close = cmd:branch(
    "close",
    {
        description = "Closes a widget by index, eg. 'widget close 2' (see widget list for indices)",
        args_syntax = "<index>",
        flags_syntax = nil
    },
    function(args, flags)
        local index = tonumber(args[1])
        if not index then
            uim.sendMessage("Widget", "Usage: widget close <index>", uim.MessageTypes.ALERT)
            return true
        end
        CloseWidget(index)
        return true
    end
)

local cmd_closeall = cmd:branch(
    "closeall",
    {
        description = "Closes all open widgets",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        CloseAll()
        return true
    end
)

local cmd_list = cmd:branch(
    "list",
    {
        description = "Lists all open widgets",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        ListWidgets()
        return true
    end
)

local cmd_tips = cmd:branch(
    "tips",
    {
        description = "Shows tips for useful widgets to open",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        HandleTips()
        return true
    end
)
