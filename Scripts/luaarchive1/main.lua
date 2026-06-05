print("[PerruGiveMod] Mod loading!")

local uim = require("uimanager")
require("give")
require("deletehand")
require("unlocklogs")



local function HandleHelp(mode, secrets)
    -- PD shows in reverse order.
    if secrets then
        uim.sendMessage("Main", "Debug commands from PDCmdMod (MAY CRASH YOUR GAME OR BRICK YOUR SAVE!)\n"..
            "No debug commands yet, that are worth noting at least. How boring"
            , mode, 20.0, true
        )
    end
    uim.sendMessage("Main", "   help\n\tShow this message\n", mode, 20.0)
    uim.sendMessage("Main", "   unlocklogs <all/id/name/help> [args...]\n    Unlock logbook entries. Use 'unlocklogs help' for details and usage info.\n", mode, 20.0)
    uim.sendMessage("Main", "   deletehand\n\tDeletes the item currently in your hand. Only works on droppable items.\n", mode, 20.0)
    uim.sendMessage("Main", "   give <fullpath/path/name/display/help/tips> [args...]\n    Gives an item. Run 'give help' to learn more about this command.\n", mode, 20.0)
    uim.sendMessage("Main", "", mode, 20.0)
    uim.sendMessage("Main", "Commands from PDCmdMod by Perru (@perru_ on discord):", mode, 20.0)
    -- uim.sendMessage("Main", "Help for PDCmdMod by Perru (@perru_ on discord):\n"..
    --     "  give ...\n"..
    --     "    Gives an item. See 'give help' for details and usage info.\n"..
    --     "  deletehand\n"..
    --     "    Deletes the item currently in your hand. Only works on droppable items.\n"..
    --     "  unlocklogs ... - Unlock logbook entries. Use 'unlocklogs help' for details.\n"..
    --     "    Unlock logbook entries. See 'unlocklogs help' for details and usage info.\n"..
    --     "  help\n"..
    --     "    Show this message"
    -- , mode, 20.0, true)

end


RegisterConsoleCommandHandler("pdcmdmod", function(FullCommand, Parameters)

    if #Parameters == 1 and Parameters[1]:lower() == "includedebug" then
        HandleHelp(uim.MessageTypes.CHATLIKE, true)
    end
    HandleHelp(uim.MessageTypes.CHATLIKE, false)

    return true
end)

HandleHelp(uim.MessageTypes.LOGS, true)
