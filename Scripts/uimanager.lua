-- NOTE: PDShowInventoryMessage is the alert at the top of the screen.
-- \n for newlines (despite having poor support)

local uim = {}

RegisterConsoleCommandHandler("toasttest", function(FullCommand, Parameters)
    local fm = FindFirstOf("BP_FeedbackManager_C")
    local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
    PDShowInventoryMessage("Gave 100x Rippling Quartz (IA_Resource_Rippling_Quartz)", fmPath)

    return true
end)


-- DATA AND ENUM STUFF

uim.MessageTypes = {
    ALERT = "alert",
    CHATLIKE = "chatlike",
    LOGS = "logs",
    ERR = "err"
}

show_info_logs = false
show_err_logs = true

LOG_PREPEND = "[PDCmdMod] "


-- ============================================================
-- Stream toast system
-- ============================================================

local streamInitialized = false
local streamBox = nil
local streamWidget = nil

local function ResetStream()
    streamInitialized = false
    streamBox = nil
    streamWidget = nil
end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    ResetStream()
end)

local function InitStream()
    if streamInitialized then return true end

    -- Find live FadingBox
    local boxes = FindAllOf("UMG_FadingBox_C")
    if boxes then
        for _, b in ipairs(boxes) do
            local ok, p = pcall(function() return b:GetFullName() end)
            if ok and p:find("DrivingGameEngine") and p:find("UMG_Feedback_ItemStream") then
                streamBox = b
                break
            end
        end
    end
    if not streamBox then return false end

    -- Find live stream widget
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    if all then
        for _, obj in ipairs(all) do
            local ok, p = pcall(function() return obj:GetFullName() end)
            if ok and p:find("DrivingGameEngine") then
                streamWidget = obj
                break
            end
        end
    end
    if not streamWidget then return false end

    -- Resize slot
    local slot = streamWidget.Slot
    if slot then
        local slotPath = slot:GetFullName():match("^%S+%s+(.+)$")
        PDSetSlotSize(slotPath, 10000, 800)
    end

    -- Increase max elements
    streamBox.MaxElements = 25

    streamInitialized = true
    return true
end

function uim.sendStreamMessage(message, duration)
    duration = duration or 6.0

    if not InitStream() then
        -- fallback to top-center alert
        local fm = FindFirstOf("BP_FeedbackManager_C")
        if fm then
            local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
            PDShowInventoryMessage(message, fmPath)
        end
        return false
    end

    -- Snapshot before
    local beforeEntries = {}
    local beforeWidgets = {}
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok then beforeEntries[fn] = true end
    end
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok then beforeWidgets[fn] = true end
    end

    -- Create entry
    streamWidget:OnPickedUp(nil)

    -- Find new entry
    local newEntry = nil
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok and not beforeEntries[fn] then newEntry = e break end
    end

    -- Find new wrapper widget
    local newWidget = nil
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok and not beforeWidgets[fn] then newWidget = w break end
    end

    if not newEntry then
        print(LOG_PREPEND .. "[Stream] Failed to find new entry")
        return false
    end

    -- Set text
    local entryPath = newEntry:GetFullName():match("^%S+%s+(.+)$")
    PDSetFText(entryPath, "Text", message)
    newEntry:UpdateInfo()

    -- Set lifetime
    if newWidget then
        pcall(function() newWidget:SetLifetime(duration) end)
    end

    return true
end


function uim.sendMessage(msg_source, message, messageType, preferredDuration, forceSplitNewlines)

    local duration = preferredDuration or 8.0
    local forceSplit = forceSplitNewlines == true

    local messageLines = {}
    for line in string.gmatch(message, "[^\n]+") do
        table.insert(messageLines, line)
    end
    local logsSafeMessage = table.concat(messageLines, "<nl>")

    if messageType == uim.MessageTypes.ALERT then
        local fm = FindFirstOf("BP_FeedbackManager_C")
        if fm then
            local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
            PDShowInventoryMessage(message, fmPath)
        end
        print(LOG_PREPEND .. "[" .. msg_source .. "] Alert: " .. logsSafeMessage)

    elseif messageType == uim.MessageTypes.CHATLIKE then
        if forceSplit then
            for i = #messageLines, 1, -1 do
                uim.sendStreamMessage(messageLines[i], duration)
            end
        else
            uim.sendStreamMessage(message, duration)
        end
        print(LOG_PREPEND .. "[" .. msg_source .. "] Chatlike: " .. logsSafeMessage)

    elseif messageType == uim.MessageTypes.LOGS then
        print(LOG_PREPEND .. "[" .. msg_source .. "] " .. logsSafeMessage)
        if show_info_logs then
            uim.sendStreamMessage("[LOG] " .. message, duration)
        end

    elseif messageType == uim.MessageTypes.ERR then
        print(LOG_PREPEND .. "[" .. msg_source .. "] [ERROR] " .. logsSafeMessage)
        if show_err_logs then
            local fm = FindFirstOf("BP_FeedbackManager_C")
            if fm then
                local fmPath = fm:GetFullName():match("^%S+%s+(.+)$")
                PDShowInventoryMessage("[ERR] " .. message, fmPath)
            end
        end
    end
end


-- =============================================================
-- TESTING
-- =============================================================

-- local savedFont = nil

-- ExecuteWithDelay(5000, function()
--     local ok, err = pcall(function()
--         RegisterHook("/Game/UI/UXFeedback/Elements/UMG_FadingBox.UMG_FadingBox_C:AddHistoryText",
--             function(self, text, font, listEntry)
--                 print("[FontHook] AddHistoryText fired!")
--                 print("[FontHook] text=" .. tostring(text))
--                 print("[FontHook] font=" .. tostring(font))
--             end
--         )
--     end)
--     print("[FontHook] Register ok=" .. tostring(ok) .. " err=" .. tostring(err))
-- end)

-- local cachedEntry = nil

-- ExecuteWithDelay(5000, function()
--     local ok, err = pcall(function()
--         RegisterHook("/Game/UI/UXFeedback/Elements/UMG_FadingBox.UMG_FadingBox_C:AddHistoryWidget",
--             function(self, content, listEntry)
--                 local ok, obj = pcall(function() return content:get() end)
--                 if ok and obj then
--                     local ok2, name = pcall(function() return obj:GetFullName() end)
--                     if ok2 and name:find("UMG_Feedback_ItemStream_Entry_C") then
--                         local classOk = pcall(function() return obj:GetClass() end)
--                         if classOk then
--                             cachedEntry = obj
--                             print("[EntryCache] Captured entry")
--                         end
--                     end
--                 end
--             end
--         )
--     end)
--     print("[EntryCache] Hook ok=" .. tostring(ok))
-- end)

RegisterConsoleCommandHandler("toasttest2", function(FullCommand, Parameters)
    local msg = table.concat(Parameters, " ")
    if msg == "" then msg = "Hello from PDCmdMod!" end

    if not cachedEntry then
        print("[Toast2] No cached entry — pick up an item first")
        return true
    end

    local classOk = pcall(function() return cachedEntry:GetClass() end)
    if not classOk then
        print("[Toast2] Cached entry went stale")
        cachedEntry = nil
        return true
    end

    local box = nil
    local boxes = FindAllOf("UMG_FadingBox_C")
    if boxes then
        for _, b in ipairs(boxes) do
            local ok, p = pcall(function() return b:GetFullName() end)
            if ok and p:find("DrivingGameEngine") and p:find("UMG_Feedback_ItemStream") then
                box = b
                break
            end
        end
    end

    if not box then print("[Toast2] No box") return true end

    local entryPath = cachedEntry:GetFullName():match("^%S+%s+(.+)$")
    PDSetFText(entryPath, "Text", msg)

    local ok, err = pcall(function()
        box:AddHistoryWidget(cachedEntry, {})
    end)
    print("[Toast2] ok=" .. tostring(ok) .. " err=" .. tostring(err))
    return true
end)


RegisterConsoleCommandHandler("toasttest3", function(FullCommand, Parameters)
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    for _, obj in ipairs(all) do
        local ok, path = pcall(function()
            return obj:GetFullName():match("^%S+%s+(.+)$")
        end)
        if ok and path and path:find("DrivingGameEngine") then
            local funcs = PDEnumerateFunctions(path)
            if funcs then
                for _, f in ipairs(funcs) do
                    print("[Toast3] fn: " .. f)
                end
            end
            break
        end
    end
    return true
end)


RegisterConsoleCommandHandler("toasttest4", function(FullCommand, Parameters)
    local msg = table.concat(Parameters, " ")
    if msg == "" then msg = "Hello from PDCmdMod!" end

    local stream = nil
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    if all then
        for _, obj in ipairs(all) do
            local ok, path = pcall(function()
                return obj:GetFullName():match("^%S+%s+(.+)$")
            end)
            if ok and path and path:find("DrivingGameEngine") then
                stream = obj
                break
            end
        end
    end
    if not stream then print("[Toast4] No stream") return true end

    -- Snapshot entries and widgets before
    local beforeEntries = {}
    local beforeWidgets = {}
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok then beforeEntries[fn] = true end
    end
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok then beforeWidgets[fn] = true end
    end

    stream:OnPickedUp(nil)

    -- Find new entry
    local newEntry = nil
    for _, e in ipairs(FindAllOf("UMG_Feedback_ItemStream_Entry_C") or {}) do
        local ok, fn = pcall(function() return e:GetFullName() end)
        if ok and not beforeEntries[fn] then newEntry = e break end
    end

    -- Find new wrapper widget
    local newWidget = nil
    for _, w in ipairs(FindAllOf("UMG_FadingBox_Widget_C") or {}) do
        local ok, fn = pcall(function() return w:GetFullName() end)
        if ok and not beforeWidgets[fn] then newWidget = w break end
    end

    if not newEntry then print("[Toast4] No new entry") return true end

    local entryPath = newEntry:GetFullName():match("^%S+%s+(.+)$")
    PDSetFText(entryPath, "Text", msg)
    newEntry:UpdateInfo()

    if newWidget then
        local ok, err = pcall(function() newWidget:SetLifetime(99.0) end)
        print("[Toast4] SetLifetime ok=" .. tostring(ok) .. " err=" .. tostring(err))
    else
        print("[Toast4] No new widget found")
    end

    print("[Toast4] Done!")
    return true
end)



RegisterConsoleCommandHandler("toasttest5", function(FullCommand, Parameters)
    local all = FindAllOf("UMG_Feedback_ItemStream_C")
    if all then
        for _, obj in ipairs(all) do
            local ok, p = pcall(function() return obj:GetFullName() end)
            if ok and p:find("DrivingGameEngine") then
                local slot = obj.Slot
                if slot then
                    local slotPath = slot:GetFullName():match("^%S+%s+(.+)$")
                    print("[Toast5] Slot path: " .. tostring(slotPath))
                    local ok2, err = pcall(function()
                        PDSetSlotSize(slotPath, 10000, 600)
                    end)
                    print("[Toast5] SetSize ok=" .. tostring(ok2) .. " err=" .. tostring(err))
                end
                break
            end
        end
    end
    return true
end)



return uim
