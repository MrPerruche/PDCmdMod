local uim = require("uimanager")
local cm = require("commandmanager")


local cmd = cm.MANAGER:register(
    "expedition",
    {
        description = "Expeditions related command(s).",
        args_syntax = nil,
        flags_syntax = nil
    },
    nil
)

local cmd_setlevel = cmd:branch(
    "setlevel",
    {
        description = "[BY SHRUC] Set the current expedition level.",
        args_syntax = "<number>",
        flags_syntax = nil
    },
    function(args, flags)
        -- code modified from shruc's expedition mod

        local lvl = tonumber(args[1])
        if lvl == nil then
            uim.sendMessage("Expedition", "Invalid command", uim.MessageTypes.ALERT)
            return false  -- help
        end

        local pm = FindFirstOf("BP_ProgressionManager_C")
        if not pm then
            uim.sendMessage("Expedition", "Save not loaded", uim.MessageTypes.ALERT)
            return true
        end

        local ok, err = pcall(function()
            pm.CurrentExpeditionDifficulty = lvl
            pm.DisplayedExpeditionDifficulty = lvl
            uim.sendMessage("Expedition", "Set expedition level to " .. lvl, uim.MessageTypes.CHATLIKE)
        end)
        if not ok then
            uim.sendMessage("Expedition", "Failed to set expedition level", uim.MessageTypes.ALERT)
            uim.sendMessage("Expedition", "Error: " .. tostring(err), uim.MessageTypes.LOGS)
        end
        return true
    end
)

local cmd_reroll = cmd:branch(
    "dbg_reroll_pickphaseonly",
    {
        description = "DANGER: CAN SOFTLOCK YOU. RUN COMMAND WITHOUT ARGUMENTS OR FLAGS TO LEARN MORE.",
        args_syntax = nil,
        flags_syntax = "secret. Run to learn more"
    },
    function(args, flags)

        if not flags or not flags["iknowwhatimdoing"] then
            uim.sendMessage("Expedition", "This command will softlock you if you are not in the menu and must currently pick one of 3 rewoven hard drives.\nSave your game then run with flag --iknowwhatimdoing to reroll.\nExit then re-open the route planner to update offers.", uim.MessageTypes.CHATLIKE, 20.0, true)
            return true
        end

        local pm = FindFirstOf("BP_ProgressionManager_C")
        if not pm then
            uim.sendMessage("Expedition", "Save not loaded", uim.MessageTypes.ALERT)
            return true
        end

        local ok, err = pcall(function()
            pm:ClearAndGenerateNewExpeditions()
        end)
        if ok then
            uim.sendMessage("Expedition", "Expedition offerings rerolled", uim.MessageTypes.CHATLIKE)
        else
            uim.sendMessage("Expedition", "Failed to reroll expeditions", uim.MessageTypes.ALERT)
            uim.sendMessage("Expedition", "Error: " .. tostring(err), uim.MessageTypes.LOGS)
        end
        return true
    end
)

-- RegisterConsoleCommandHandler("expedtest", function(FullCommand, Parameters)
--     local pm = FindFirstOf("BP_ProgressionManager_C")
--     if not pm then print("[ExpedTest] No PM") return true end

--     local mode = Parameters[1] and Parameters[1]:lower() or "info"

--     if mode == "info" then
--         -- Check current state
--         local out1, out2, out3, out4 = {}, {}, {}, {}
--         pcall(function() pm:CanStartExpeditionsFromLoad(pm, out1) end)
--         pcall(function() pm:CanStartExpeditionsFromFinishedRun(pm, out2) end)
--         pcall(function() pm:AreThereAnyExpeditionEmbarkRestrictions(pm, out3) end)
--         pcall(function() pm:IsOnRun(pm, out4) end)
--         for k,v in pairs(out1) do print("Load: " .. tostring(k) .. "=" .. tostring(v)) end
--         for k,v in pairs(out2) do print("Finished: " .. tostring(k) .. "=" .. tostring(v)) end
--         for k,v in pairs(out3) do print("Restrictions: " .. tostring(k) .. "=" .. tostring(v)) end
--         for k,v in pairs(out4) do print("OnRun: " .. tostring(k) .. "=" .. tostring(v)) end

--     elseif mode == "rebuild" then
--         local ok, err = pcall(function()
--             pm["DbgActEvt_Rebuild Potential Routes_Execute"](pm)
--         end)
--         print("[ExpedTest] RebuildRoutes: ok=" .. tostring(ok) .. " err=" .. tostring(err))

--     elseif mode == "reroll" then
--         local ok, err = pcall(function()
--             pm:ClearAndGenerateNewExpeditions()
--         end)
--         print("[ExpedTest] ClearAndGenerate: ok=" .. tostring(ok) .. " err=" .. tostring(err))

--     elseif mode == "rebuild+reroll" then
--         local ok1, err1 = pcall(function()
--             pm["DbgActEvt_Rebuild Potential Routes_Execute"](pm)
--         end)
--         print("[ExpedTest] RebuildRoutes: ok=" .. tostring(ok1) .. " err=" .. tostring(err1))
--         local ok2, err2 = pcall(function()
--             pm:ClearAndGenerateNewExpeditions()
--         end)
--         print("[ExpedTest] ClearAndGenerate: ok=" .. tostring(ok2) .. " err=" .. tostring(err2))

--     elseif mode == "abort" then
--         local ok, err = pcall(function()
--             pm["DbgActEvt_[No Travel] Finish Current Run - ABORTED_Execute"](pm)
--         end)
--         print("[ExpedTest] Abort: ok=" .. tostring(ok) .. " err=" .. tostring(err))

--     elseif mode == "abort+reroll" then
--         local ok1, err1 = pcall(function()
--             pm["DbgActEvt_[No Travel] Finish Current Run - ABORTED_Execute"](pm)
--         end)
--         print("[ExpedTest] Abort: ok=" .. tostring(ok1) .. " err=" .. tostring(err1))
--         local ok2, err2 = pcall(function()
--             pm:ClearAndGenerateNewExpeditions()
--         end)
--         print("[ExpedTest] ClearAndGenerate: ok=" .. tostring(ok2) .. " err=" .. tostring(err2))
--     end

--     return true
-- end)