import json

target_file_name = input("File name\n> ")
if not target_file_name:
    target_file_name = "BP_WorldItem.json"

with open(target_file_name, "r") as f:
    data = json.load(f)

for obj in data:
    if obj.get("Type") == "Function":
        print(obj.get("Name", "?"))
        props = obj.get("ChildProperties", [])
        for p in props:
            print("  param: " + p.get("Name", "?") + " (" + p.get("Type", "?") + ")")

import os
os.system('pause')
