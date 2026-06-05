import os

search = "ForEachUObject"
root = r"D:\Code\PacificDrive\UE4SS_cpp\RE-UE4SS\deps\first\Unreal\include"

for dirpath, dirnames, filenames in os.walk(root):
    for fname in filenames:
        fpath = os.path.join(dirpath, fname)
        try:
            with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                if search in content:
                    print(fpath)
        except:
            pass

input("Press enter...")