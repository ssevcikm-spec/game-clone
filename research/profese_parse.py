"""Prevod Prof.txt z instalace UO na JSON (profese, skilly, staty).

Prof.txt je textovy blokovy format:
    Begin
        Name      Warrior
        TrueName  "Warrior"
        NameId    1062947
        Skill     Tactics   30
        Stat      Str       45
    End
Vystup: research/profese.json + konzolova tabulka.
"""
import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC = Path(r"D:\Games\Electronic Arts\Ultima Online Classic\Prof.txt")
OUT = Path(r"E:\Workspaces\game-clone\research\profese.json")

text = SRC.read_bytes().decode("latin1")
blocks = re.findall(r"Begin(.*?)End", text, re.S)
profese = []
for b in blocks:
    p = {"name": None, "true_name": None, "name_id": None, "desc_id": None,
         "top_level": False, "type": None, "gump": None, "skills": {}, "stats": {}}
    for line in b.splitlines():
        parts = line.split()
        if not parts:
            continue
        key = parts[0].lower()
        if key == "name" and len(parts) >= 2:
            p["name"] = parts[1]
        elif key == "truename":
            p["true_name"] = " ".join(parts[1:]).strip('"')
        elif key == "nameid" and len(parts) >= 2:
            p["name_id"] = int(parts[1])
        elif key == "descid" and len(parts) >= 2:
            p["desc_id"] = int(parts[1])
        elif key == "toplevel":
            p["top_level"] = parts[1].lower() == "true"
        elif key == "type" and len(parts) >= 2:
            p["type"] = parts[1]
        elif key == "gump" and len(parts) >= 2:
            p["gump"] = int(parts[1])
        elif key == "skill" and len(parts) >= 3:
            p["skills"][" ".join(parts[1:-1])] = int(parts[-1])
        elif key == "stat" and len(parts) >= 3:
            p["stats"][parts[1]] = int(parts[-1])
    if p["name"]:
        profese.append(p)

OUT.write_text(json.dumps(profese, indent=2, ensure_ascii=False), encoding="utf-8")

print(f"profesi nalezeno: {len(profese)}")
print(f"{'jméno':16} {'str':>4}{'dex':>4}{'int':>4}  skilly")
for p in profese:
    s = p["stats"]
    sk = ", ".join(f"{k}={v}" for k, v in p["skills"].items())
    print(f"{p['name']:16} {s.get('Str', 0):>4}{s.get('Dex', 0):>4}{s.get('Int', 0):>4}  {sk}")
print(f"\nJSON: {OUT}")
