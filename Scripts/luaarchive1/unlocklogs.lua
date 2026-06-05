-- ============================================================
-- unlocklogs: Unlock logbook entries.
--
-- Usage:
--   unlocklogs all
--     Unlocks all currently loaded logbook entries.
--
--   unlocklogs name <display_name>
--     Fuzzy match on display name (case/punctuation insensitive).
--     If multiple matches, lists them with their paths.
--     e.g. unlocklogs name breaking
--
--   unlocklogs id <asset_path>
--     Exact path match. Use after 'unlocklogs name' to disambiguate.
--     e.g. unlocklogs id /Game/Gameplay/StatusEffects/Breaking/LOG_Breaking
--
-- Notes:
--   - Only entries currently loaded in memory can be unlocked.
--   - Entries for items/areas not yet encountered may not be loaded.
--   - DLC entries are supported if the DLC is installed and loaded.
-- ============================================================

local uim = require("uimanager")

local function Normalize(s)
    return s:lower():gsub("[%s%p%-]", "")
end

local function GetLogBook()
    local lb = FindFirstOf("LogBook")
    if not lb or not lb:IsValid() then
        print("[UnlockLogs] ERROR: LogBook not found")
        return nil
    end
    return lb
end

-- Collect all loaded LogBookDataGeneric objects with their paths and display names
local function CollectEntries()
    local all = FindAllOf("LogBookDataGeneric")
    if not all then
        uim.sendMessage("UnlockLogs", "No LogBookDataGeneric objects found in memory", uim.MessageTypes.ERR)
        --print("[UnlockLogs] No LogBookDataGeneric objects found in memory")
        return nil
    end

    local entries = {}
    for i = 1, #all do
        local obj = all[i]
        local classOk = pcall(function() return obj:GetClass() end)
        if classOk then
            local ok, fullName = pcall(function() return obj:GetFullName() end)
            if ok and fullName then
                -- Extract path from "LogBookDataGeneric /Game/..." format
                local path = fullName:match("^%S+%s+(.+)$")
                -- Extract asset name from path for display
                local assetName = path and path:match("([^/.]+)%.[^/]+$") or "?"
                -- Try to get display name via PDGetFText
                local displayName = nil
                if path then
                    pcall(function()
                        displayName = PDGetFText(path, "Title")
                    end)
                end
                table.insert(entries, {
                    obj = obj,
                    path = path,
                    assetName = assetName,
                    displayName = displayName or assetName,
                })
            end
        end
    end
    return entries
end

local function UnlockEntry(lb, entry)
    local ok = pcall(function() lb:AddEntry(entry.obj) end)
    return ok
end

-- ============================================================
-- Mode: all
-- ============================================================
local function HandleAll()
    local lb = GetLogBook()
    if not lb then return end

    local entries = CollectEntries()
    if not entries then return end
    uim.sendMessage("UnlockLogs", "Found " .. #entries .. " loaded entries", uim.MessageTypes.LOGS)
    -- print("[UnlockLogs] Found " .. #entries .. " loaded entries")

    local count = 0
    for _, entry in ipairs(entries) do
        if UnlockEntry(lb, entry) then
            count = count + 1
        end
    end
    uim.sendMessage("UnlockLogs", "Unlocked all existing entries.\nNote: some entries cannot be unlocked because they don't actually exist.", uim.MessageTypes.CHATLIKE)
    --print("[UnlockLogs] Unlocked " .. count .. "/" .. #entries .. " entries!")
end

-- ============================================================
-- Mode: name
-- ============================================================
local function HandleName(params)
    -- Join all params as the name (supports spaces)
    local rawName = table.concat(params, " ")
    local normalizedInput = Normalize(rawName)

    if normalizedInput == "" then
        uim.sendMessage("UnlockLogs", "Invalid syntax.", uim.MessageTypes.ALERT)
        uim.sendMessage("UnlockLogs", "Usage: unlocklogs name <display_name>", uim.MessageTypes.CHATLIKE)
        -- print("[UnlockLogs] Usage: unlocklogs name <display_name>")
        return
    end

    local lb = GetLogBook()
    if not lb then return end

    local entries = CollectEntries()
    if not entries then return end

    local matches = {}
    for _, entry in ipairs(entries) do
        if Normalize(entry.displayName) == normalizedInput then
            table.insert(matches, entry)
        end
    end

    if #matches == 0 then
        uim.sendMessage("UnlockLogs", "No matching logbook entry found.", uim.MessageTypes.ALERT)
        uim.sendMessage("UnlockLogs", "No matches for " .. rawName .. ". Consider using 'unlocklogs id' if required.", uim.MessageTypes.CHATLIKE)
        --print("[UnlockLogs] No entry found matching: '" .. rawName .. "'")
        --print("[UnlockLogs] Tip: check spelling, or use 'unlocklogs id <path>'")
        return
    end

    if #matches == 1 then
        if UnlockEntry(lb, matches[1]) then
            uim.sendMessage("UnlockLogs", "Unlocked: " .. matches[1].displayName, uim.MessageTypes.CHATLIKE)
            --print("[UnlockLogs] Unlocked: " .. matches[1].displayName)
        else
            uim.sendMessage("UnlockLogs", "Unlock failed!", uim.MessageTypes.ALERT)
            uim.sendMessage("UnlockLogs", "Failed to unlock: " .. matches[1].displayName, uim.MessageTypes.CHATLIKE)
            --print("[UnlockLogs] Failed to unlock: " .. matches[1].displayName)
        end
    else
        local outputString = "Multiple matches found.\n"
        outputString = outputString .. #matches .. " entries match '" .. rawName .. "':\n"
        for i, entry in ipairs(matches) do
            outputString = outputString .. " [" .. i .. "] " .. entry.displayName .. " -> " .. tostring(entry.path) .. "\n"
            -- print("[UnlockLogs]   [" .. i .. "] " .. entry.displayName .. " -> " .. tostring(entry.path))
        end
        uim.sendMessage("UnlockLogs", outputString .. "\nUse 'unlocklogs id <path> to unlock a specific one\nOr 'unlocklogs all' to unlock everything", uim.MessageTypes.CHATLIKE, 30.0, true)
        -- print("[UnlockLogs] Use 'unlocklogs id <path>' to unlock a specific one")
        -- print("[UnlockLogs] Or 'unlocklogs all' to unlock everything")
    end
end

-- ============================================================
-- Mode: id
-- ============================================================
local function HandleId(path)
    if not path or path == "" then
        --print("[UnlockLogs] Usage: unlocklogs id <asset_path>")
        return
    end

    local lb = GetLogBook()
    if not lb then return end

    local entries = CollectEntries()
    if not entries then return end

    -- Match by path or asset name
    local match = nil
    for _, entry in ipairs(entries) do
        if entry.path == path or entry.assetName == path then
            match = entry
            break
        end
    end

    if not match then
        uim.sendMessage("UnlockLogs", "Entry not found", uim.MessageTypes.ALERT)
        uim.sendMessage("UnlockLogs", "No loaded entry found with path: " .. path, uim.MessageTypes.CHATLIKE)
        return
    end

    if UnlockEntry(lb, match) then
        uim.sendMessage("UnlockLogs", "Unlocked: " .. match.displayName .. " (" .. match.assetName .. ")", uim.MessageTypes.CHATLIKE)
    else
        uim.sendMessage("UnlockLogs", "Unlock failed!", uim.MessageTypes.ALERT)
        uim.sendMessage("UnlockLogs", "Failed to unlock: " .. match.displayName, uim.MessageTypes.ALERT)
    end
end

-- ============================================================
-- Command handler and usage info
-- ============================================================

local function HandleHelp(mode)
    uim.sendMessage("UnlockLogs", "Usage:\n" ..
        "  unlocklogs all\n" ..
        "    Unlocks all currently loaded logbook entries.\n\n" ..
        "  unlocklogs name <display_name>\n" ..
        "    Fuzzy match on display name (case/punctuation insensitive).\n" ..
        "    If multiple matches, lists them with their paths.\n" ..
        "    e.g. unlocklogs name breaking\n\n" ..
        "  unlocklogs id <asset_path>\n" ..
        "    Exact path match. Use after 'unlocklogs name' to disambiguate.\n" ..
        "    e.g. unlocklogs id /Game/Gameplay/StatusEffects/Breaking/LOG_Breaking" ..
        "  unlocklogs help\n" ..
        "    Show this help message"
    , mode, 20.0, true)
end


RegisterConsoleCommandHandler("unlocklogs", function(FullCommand, Parameters)
    if #Parameters == 0 then
        HandleHelp()
        return true
    end

    local mode = Parameters[1]:lower()

    if mode == "all" then
        HandleAll()

    elseif mode == "name" then
        local nameParams = {}
        for i = 2, #Parameters do
            table.insert(nameParams, Parameters[i])
        end
        HandleName(nameParams)

    elseif mode == "id" then
        HandleId(Parameters[2])

    elseif mode == "help" then
        HandleHelp(uim.MessageTypes.CHATLIKE)

    else
        uim.sendMessage("UnlockLogs", "Unknown mode", uim.MessageTypes.ALERT)
        uim.sendMessage("UnlockLogs", "Valid modes: all, name, id, help", uim.MessageTypes.CHATLIKE)
    end

    return true
end)

HandleHelp(uim.MessageTypes.LOGS)
