# must contain harcdoded values

import json

print("Contains hardcoded values!")

target_file_name = input("File name\n> ")
if not target_file_name:
    target_file_name = "BP_WorldItem.json"

with open(target_file_name, "r") as f:
    data = json.load(f)

targets = [
    "ForceStartEvent",
    "StartEventExternal", 
    "ForceStartEvent",
    "Debug ForceTrigger New Event",
    "StartNewEvent",
    "ChooseEvent",
    "Internal_StartNewEvent",
    "ForceStartEvent",
    "StartMinorEvent",
    "TryMinorEvent",
    "ForcedPositiveEvent",
    "IsEventModifierOn",
    "ShouldEventsPlay",
    "SetupEventActorAndItem",
    "ClearCurrentEvent",
]

for obj in data:
    if obj.get("Type") == "Function" and obj.get("Name") in targets:
        print(obj.get("Name"))
        for p in obj.get("ChildProperties", []):
            print("  " + p.get("Name", "?") + " (" + p.get("Type", "?") + ")")