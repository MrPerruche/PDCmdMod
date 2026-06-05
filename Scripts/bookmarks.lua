-- ============================================================
-- bookmarks: Save and load game state bookmarks.
-- Bookmarks stored in Mods/PDCmdMod/Scripts/bookmarks/
-- ============================================================

local uim = require("uimanager")
local cm = require("commandmanager")

local GAME_BMK = "../../../PenDriverPro/Content/Bookmarks/BookMark.bmk"
local BMK_DIR = "../../../PenDriverPro/Content/Bookmarks/"
local RESERVED = "bookmark"

local function GetPath(name)
    return BMK_DIR .. name .. ".bmk"
end

local function IsReserved(name)
    return name:lower() == RESERVED
end

local function CopyFile(src, dst)
    local f = io.open(src, "r")
    if not f then return false, "Cannot read: " .. src end
    local content = f:read("*a")
    f:close()
    local d = io.open(dst, "w")
    if not d then return false, "Cannot write: " .. dst end
    d:write(content)
    d:close()
    return true
end

local function GetSGM()
    local sgm = FindFirstOf("BP_SaveGameManager_C")
    if not sgm then return nil end
    return sgm
end

local function ValidateName(name)
    if not name or name == "" then
        return false, "Name cannot be empty"
    end
    if IsReserved(name) then
        return false, "'" .. name .. "' is reserved by the game"
    end
    -- No path traversal
    if name:find("%.%.") or name:find("[/\\]") then
        return false, "Name cannot contain path characters"
    end
    -- No special characters that would break filenames
    if name:find('[<>:"|%?%*]') then
        return false, "Name contains invalid characters"
    end
    -- Reasonable length
    if #name > 64 then
        return false, "Name too long (max 64 characters)"
    end
    return true
end

local cmd_bmk = cm.MANAGER:register(
    "bookmark",
    { 
        description = "Make and load bookmarks (alternate savestates).",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

-- make
cmd_bmk:branch(
    "make",
    {
        description = "Create a named bookmark of the current game state.",
        args_syntax = "<name>"
    },
    function(args, flags)
        local name = args[1]
        if not name then
            uim.sendMessage("BMK", "Usage: debug bmk make <name>", uim.MessageTypes.ALERT)
            return true
        end
        local is_valid, err = ValidateName(name)
        if not is_valid then
            uim.sendMessage("BMK", "Invalid name: " .. err, uim.MessageTypes.ALERT)
            return true
        end

        local sgm = GetSGM()
        if not sgm then
            uim.sendMessage("BMK", "SaveGameManager not found", uim.MessageTypes.ERR)
            return true
        end

        -- Tell game to write BookMark.bmk
        local ok, err = pcall(function()
            sgm["DbgActEvt_MakeBookmark \"bookmark\"_Execute"](sgm)
        end)
        if not ok then
            uim.sendMessage("BMK", "MakeBookmark failed: " .. tostring(err), uim.MessageTypes.ERR)
            return true
        end

        -- Copy to named file
        local ok2, err2 = CopyFile(GAME_BMK, GetPath(name))
        if not ok2 then
            uim.sendMessage("BMK", "Failed to save: " .. tostring(err2), uim.MessageTypes.ERR)
            return true
        end

        uim.sendMessage("BMK", "Bookmark saved: " .. name, uim.MessageTypes.CHATLIKE)
        return true
    end
)

-- load
cmd_bmk:branch(
    "load",
    {
        description = "Load a named bookmark.",
        args_syntax = "<name>"
    },
    function(args, flags)
        local name = args[1]
        if not name then
            uim.sendMessage("BMK", "Usage: debug bmk load <name>", uim.MessageTypes.ALERT)
            return true
        end
        if IsReserved(name) then
            uim.sendMessage("BMK", "'" .. name .. "' is reserved.", uim.MessageTypes.ALERT)
            return true
        end

        -- Check file exists
        local f = io.open(GetPath(name), "r")
        if not f then
            uim.sendMessage("BMK", "Bookmark not found: " .. name, uim.MessageTypes.ALERT)
            return true
        end
        f:close()

        -- Copy to BookMark.bmk
        local ok, err = CopyFile(GetPath(name), GAME_BMK)
        if not ok then
            uim.sendMessage("BMK", "Failed to copy: " .. tostring(err), uim.MessageTypes.ERR)
            return true
        end

        local sgm = GetSGM()
        if not sgm then
            uim.sendMessage("BMK", "SaveGameManager not found", uim.MessageTypes.ERR)
            return true
        end

        local ok2, err2 = pcall(function()
            sgm["DbgActEvt_LoadBookmark \"bookmark\"_Execute"](sgm)
        end)
        if not ok2 then
            uim.sendMessage("BMK", "LoadBookmark failed: " .. tostring(err2), uim.MessageTypes.ERR)
            return true
        end

        uim.sendMessage("BMK", "Loaded bookmark: " .. name, uim.MessageTypes.CHATLIKE)
        return true
    end
)

-- list
cmd_bmk:branch(
    "list",
    { description = "List all saved bookmarks." },
    function(args, flags)

        local names = {}
        local ok, result = pcall(function()
            local p = io.popen('dir "' .. BMK_DIR .. '" /b 2>nul')
            if not p then return nil end
            local content = p:read("*a")
            p:close()
            return content
        end)

        if not ok or not result or result == "" then
            uim.sendMessage("BMK", "No bookmarks found", uim.MessageTypes.CHATLIKE)
            return true
        end

        for entry in result:gmatch("([^\r\n]+)") do
            if entry:match("%.bmk$") and entry ~= "BookMark.bmk" then
                table.insert(names, (entry:gsub("%.bmk$", "")))
            end
        end

        if #names == 0 then
            uim.sendMessage("BMK", "No bookmarks found", uim.MessageTypes.CHATLIKE)
            return true
        end

        uim.sendMessage("BMK", "Bookmarks:\n  " .. table.concat(names, "\n  "), uim.MessageTypes.CHATLIKE, 20.0, true)
        return true
    end
)

-- delete
cmd_bmk:branch(
    "delete",
    {
        description = "Delete a named bookmark.",
        args_syntax = "<name>"
    },
    function(args, flags)
        local name = args[1]
        if not name then
            uim.sendMessage("BMK", "Usage: debug bmk delete <name>", uim.MessageTypes.ALERT)
            return true
        end
        local is_valid, err = ValidateName(name)
        if not is_valid then
            uim.sendMessage("BMK", "Invalid name: " .. err, uim.MessageTypes.ALERT)
            return true
        end

        local path = GetPath(name)
        local f = io.open(path, "r")
        if not f then
            uim.sendMessage("BMK", "Bookmark not found: " .. name, uim.MessageTypes.ALERT)
            return true
        end
        f:close()

        local ok, err = pcall(function()
            os.remove(path)
        end)
        if not ok then
            uim.sendMessage("BMK", "Delete failed: " .. tostring(err), uim.MessageTypes.ERR)
            return true
        end

        uim.sendMessage("BMK", "Deleted bookmark: " .. name, uim.MessageTypes.CHATLIKE)
        return true
    end
)