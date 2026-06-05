local uim = require("uimanager")
local cm = require("commandmanager")

function Cmd_ApplyGarageIntro()
    local manager = FindFirstOf("BP_FIG_GarageMischiefManager_C")

    if not manager then
        print("[Garage] Manager not found")
        return
    end

    print("[Garage] Manager found:", manager:GetFullName())

    local ok, err = pcall(function()
        -- manager:ApplyIntroAdjustments()
        manager["DbgActEvt_Apply FIG Intro Adjustments_Execute"](manager)
    end)

    if not ok then
        print("[Garage] ApplyIntroAdjustments failed:", err)
    else
        print("[Garage] ApplyIntroAdjustments executed")
    end
end


local cmd_witwtest = cm.cmd_debug:branch(
    "witwtest",
    {
        description = "Apply garage dlc intro (DbgActEvt) (WitW DLC)",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        Cmd_ApplyGarageIntro()
        return true
    end
)


local cmd_legstateforceactive = cm.cmd_debug:branch(
    "legstate",
    {
        description = "Force active all leg states",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        -- Lua side: get whiteboard from PM, pass it directly to C++
        local pm = FindFirstOf("BP_ProgressionManager_C")
        local ok, wb = pcall(function() return pm:GetGlobalWhiteboard(pm) end)
        if ok and wb then
            PDSetWhiteboardTagOnObject(wb, "WB.Routes.RP_NODE_03.Presented", 1.0)
        end
        return true
    end
)

local function GetGlobalWhiteboard()
    local pm = FindFirstOf("BP_ProgressionManager_C")
    if not pm then return nil end
    local ok, wb = pcall(function() return pm:GetGlobalWhiteboard(pm) end)
    if not ok or not wb then return nil end
    local ok2, path = pcall(function() return wb:GetFullName():match("^%S+%s+(.+)$") end)
    if not ok2 or not path then return nil end
    return path
end

RegisterConsoleCommandHandler("revealtest", function()
    local pm = FindFirstOf("BP_ProgressionManager_C")
    local ok, wb = pcall(function() return pm:GetGlobalWhiteboard(pm) end)
    local wbPath = wb:GetFullName():match("^%S+%s+(.+)$")
    
    -- Try all RP_NODE_03 tags
    local tags = {
        "WB.Routes.RP_NODE_41",
        "WB.Routes.RP_NODE_41.Presented",
        "WB.Routes.RP_NODE_41.Completed",
        "WB.Routes.RP_NODE_41.Attempted",
    }
    for _, tag in ipairs(tags) do
        PDSetWhiteboardTag(wbPath, tag, 1.0)
    end
    
    return true
end)

RegisterConsoleCommandHandler("routedebugfuncs", function()
    local all = FindAllOf("UMG_RouteShapeDebugger_Main_C") or {}
    if #all == 0 then print("not found") return true end
    local obj = all[1]
    local path = obj:GetFullName():match("^%S+%s+(.+)$")
    local funcs = PDEnumerateFunctions(path)
    for _, f in ipairs(funcs or {}) do
        print(f)
    end
    return true
end)

RegisterConsoleCommandHandler("exploremaptest", function()
    local all = FindAllOf("UMG_RouteShapeDebugger_Main_C") or {}
    if #all == 0 then print("widget not open") return true end
    local w = all[1]
    
    -- Try Explore All button
    local ok, err = pcall(function()
        w["BndEvt__BtnExploreAll_K2Node_ComponentBoundEvent_6_OnButtonClickedEvent__DelegateSignature"](w)
    end)
    print("ExploreAll ok=" .. tostring(ok) .. " err=" .. tostring(err))
    
    -- Try SetShowAllDebug
    local ok2, err2 = pcall(function()
        w:SetShowAllDebug(true)
    end)
    print("SetShowAllDebug ok=" .. tostring(ok2) .. " err=" .. tostring(err2))
    
    return true
end)


RegisterConsoleCommandHandler("pmwbfuncs", function()
    local pm = FindFirstOf("BP_ProgressionManager_C")
    local path = pm:GetFullName():match("^%S+%s+(.+)$")
    local funcs = PDEnumerateFunctions(path)
    for _, f in ipairs(funcs or {}) do
        if f:lower():find("white") or f:lower():find("board") or f:lower():find("global") or f:lower():find("map") then
            print(f)
        end
    end
    return true
end)


RegisterConsoleCommandHandler("wbtest2", function()
    local pm = FindFirstOf("BP_ProgressionManager_C")
    local ok, wb = pcall(function() return pm:GetGlobalWhiteboard(pm) end)
    print("ok=" .. tostring(ok) .. " wb=" .. tostring(wb))
    return true
end)
RegisterConsoleCommandHandler("legwbtest", function()
    PDSetGlobalWhiteboardTag("WB.Routes.RP_NODE_03.Presented", 1.0)
    return true
end)