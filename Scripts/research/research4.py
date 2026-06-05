import json

with open("UMG_Feedback_ItemStream.json", "r") as f:
    data = json.load(f)

for obj in data:
    props = obj.get("ChildProperties", [])
    for p in props:
        if "SlateFontInfo" in p.get("Name", "") or "Font" in p.get("Name", ""):
            print(obj.get("Name", "?") + " -> " + p.get("Name", "?"))
            print("  Type: " + p.get("Type", "?"))
            # Print PropertyClass if it exists
            pc = p.get("PropertyClass", {})
            if pc:
                print("  PropertyClass: " + str(pc))