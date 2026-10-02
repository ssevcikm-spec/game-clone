"""Kontrola internich odkazu v docs/.

Kazdy odkaz typu `§5.3` nebo `docs/05 ... §5.3` musi mit v cilenem dokumentu
odpovidajici nadpis. Kdyz ne, je to ticha vada dokumentace (agent pak hleda
smouluvu, ktera neexistuje).
"""
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DOCS = Path(r"E:\Workspaces\game-clone\docs")

# sesbirej nadpisy: soubor -> mnozina cisel sekci
headings = {}
files = sorted(DOCS.glob("*.md"))
for f in files:
    nums = set()
    for line in f.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^#{1,4}\s+(\d+(?:\.\d+)*)", line)
        if m:
            nums.add(m.group(1))
    headings[f.name] = nums

# hlavni zadani v rootu se kontroluje taky (odkazuje do docs/)
MASTER = Path(r"E:\Workspaces\game-clone\ZADANI-UO-KLON.md")
check_files = list(files) + ([MASTER] if MASTER.exists() else [])

# mapa prefixu cisla -> soubor (podle prvniho cisla)
prefix_file = {}
for name, nums in headings.items():
    for n in nums:
        prefix_file.setdefault(n.split(".")[0], name)

errors = []
refs = 0


def strip_quoted(text: str) -> str:
    """Odstran inline kod a bloky kodu.

    Text, ktery vadu jen POPISUJE (napr. `§8.10` -> `§5.10` v poznámce),
    nesmi vypadat jako vada - stejna past jako kontrola ctouci komentare.
    """
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", "", text)
    return text


for f in check_files:
    text = strip_quoted(f.read_text(encoding="utf-8"))
    for m in re.finditer(r"§\s*(\d+(?:\.\d+)*)", text):
        ref = m.group(1)
        refs += 1
        top = ref.split(".")[0]
        target = prefix_file.get(top)
        if target is None:
            errors.append(f"{f.name}: odkaz §{ref} — neexistuje dokument s cislem {top}")
            continue
        if ref not in headings[target]:
            errors.append(f"{f.name}: odkaz §{ref} — v {target} takova sekce neni")

print(f"kontrolovanych souboru: {len(check_files)} (docs + hlavni zadani), odkazu: {refs}")
for name in sorted(headings):
    print(f"  {name:34} sekci: {len(headings[name]):3}  {sorted(headings[name], key=lambda s: [int(x) for x in s.split('.')])[:4]}...")
if errors:
    print(f"\nCHYBY ({len(errors)}):")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)
print("\nOK: vsechny interni odkazy ukazuji na existujici sekce.")
