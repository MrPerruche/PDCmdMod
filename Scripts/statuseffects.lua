RegisterConsoleCommandHandler("setest", function(FullCommand, Parameters)
    local im = FindFirstOf("BP_InventoryManager_C")
    if not im then print("No IM") return true end

    local handSlotOut = {}
    im:GetHandSlot(handSlotOut, {})
    local handSlot = handSlotOut["Hand Slot"]

    local ctx = FindFirstOf("BP_UIManager_C")
    local ctxPath = ctx:GetFullName():match("^%S+%s+(.+)$")
    local sePath = "/Game/Gameplay/StatusEffects/StatusEffects/CircumventRestrictions/SE_CircumventRestrictions.SE_CircumventRestrictions_C"

    for _, propName in ipairs({"ItemInstance", "Instance", "Item"}) do
        local inst = handSlot[propName]
        print("Trying " .. propName .. ": " .. tostring(inst))
        if inst then
            local ok = PDApplyStatusEffect(inst, sePath, ctxPath)
            print("Result: " .. tostring(ok))
        end
    end
    return true
end)
