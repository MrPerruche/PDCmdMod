# This script is never ran by this mod.
# This script was used to help develop this mod and you can delete it if you do not trust it.

import json

target_file_name = input("File name\n> ")
if not target_file_name:
    target_file_name = "BP_WorldItem.json"

with open(target_file_name, "r") as f:
    data = json.load(f)

for obj in data:
    type = obj.get("Type", "")
    if type == "Function":
        print(obj.get("Name", "no name (?)"))

import os
os.system('pause')