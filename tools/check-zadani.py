"""Kontrola zadavaciho balicku (aby zadani splnovalo to, co pozaduje po hre).

Kontroluje:
  1. vsechny dokumenty existuji a nejsou prazdne,
  2. hlavni zadani odkazuje na vsechny docs/ soubory,
  3. roadmap.json je validni a kazda granule ma prompt/owns/acceptance,
  4. v textech nejsou placeholdery (TODO/TBD/XXX/FIXME) ani zname rozporne
     hodnoty (napr. "120 real seconds" u delky dne - overeno, ze spravne je 7200 s),
  5. cisla, ktera se opakuji napric dokumenty, si neodporuji.

CO KONTROLA NECHYTA (aby se jeji zelena neprecenovala):
  * libovolny vecny rozpor v proze (napr. "chuze je 500 ms" napsana slovy) -
    hlida jen konkretni zname vadne literaly v BAD_PATTERNS,
  * spravnost cisel samotnych (overuje jen, ze nektera klicova cisla existuji),
  * odkazy na research/ soubory, ktere jeste nevznikly.
Mutační test: vloz `WALK_MS = 500` nebo `TODO` -> kontrola musi spadnout.
"""
import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(r"E:\Workspaces\game-clone")
DOCS = ROOT / "docs"
MASTER = ROOT / "ZADANI-UO-KLON.md"
errors = []
notes = []

# 1. dokumenty
docs = sorted(DOCS.glob("*.md"))
if len(docs) < 11:
    errors.append(f"ocekavam 11 dokumentu v docs/, nalezeno {len(docs)}")
for d in docs:
    if d.stat().st_size < 1500:
        errors.append(f"{d.name}: podezrele maly ({d.stat().st_size} B)")

# 2. hlavni zadani odkazuje na vsechny docs
master = MASTER.read_text(encoding="utf-8")
for d in docs:
    if d.name not in master and d.stem.split("-")[0] not in master:
        notes.append(f"hlavni zadani neodkazuje na {d.name}")

# 3. roadmapa
rp = ROOT / ".forge" / "roadmap.json"
if not rp.exists():
    errors.append("chybi .forge/roadmap.json")
else:
    rm = json.loads(rp.read_text(encoding="utf-8"))
    grains = rm.get("grains", [])
    if not grains:
        errors.append("roadmapa nema zadne granule")
    for g in grains:
        for key in ("id", "title", "owns", "acceptance", "prompt", "milestone"):
            if not g.get(key):
                errors.append(f"granule {g.get('id', '?')}: chybi '{key}'")
    if len({g["id"] for g in grains}) != len(grains):
        errors.append("roadmapa ma duplicitni id")
    ids = {g["id"] for g in grains}
    for g in grains:
        for dep in g["depends_on"]:
            if dep not in ids:
                errors.append(f"granule {g['id']}: neznama zavislost {dep}")

# 4. placeholdery a zname rozporne hodnoty
BAD_PATTERNS = [
    (r"\bTODO\b|\bTBD\b|\bFIXME\b|\bXXX\b", "placeholder v textu"),
    (r"120 real seconds|120 realných sekund", "ZNAMA CHYBA: den je 7200 s, ne 120 s"),
    (r"walk\s*=\s*500|WALK_MS\s*=\s*500", "ZNAMA CHYBA: chuze je 400 ms"),
]


def strip_quoted(text: str) -> str:
    """Odstran bloky a inline kod.

    Text, ktery vadu jen cituje (napr. `120 real seconds` v registru pasti),
    neni tvrzeni o hre - stejna past jako kontrola ctouci komentare (P4).
    """
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", "", text)
    return text


for f in list(docs) + [MASTER, ROOT / "README.md"]:
    if not f.exists():
        continue
    text = strip_quoted(f.read_text(encoding="utf-8"))
    for pat, why in BAD_PATTERNS:
        for m in re.finditer(pat, text):
            line = text[:m.start()].count("\n") + 1
            errors.append(f"{f.name}:{line}: {why} ({m.group(0)!r})")

# 5. konzistence cisel napric dokumenty
CHECKS = [
    ("ISO_STEP|izometrie.*22|krok izometrie.*22", "22", "krok izometrie 22 px"),
    ("400 ms", "400", "chuze 400 ms"),
    ("1.90", "1.9", "buy = 1.90 x sell"),
    ("50 \\+ STR/2", "50", "hits_max = 50 + STR/2"),
    ("7200", "7200", "den 7200 s"),
]
all_text = "\n".join(f.read_text(encoding="utf-8") for f in list(docs) + [MASTER])
for pat, val, label in CHECKS:
    n = len(re.findall(pat, all_text))
    if n == 0:
        errors.append(f"v zadani chybi klicove cislo: {label}")
    else:
        notes.append(f"{label}: {n} vyskytu")

print(f"dokumentu: {len(docs)}, granul: {len(json.loads(rp.read_text(encoding='utf-8'))['grains']) if rp.exists() else 0}")
for n in notes:
    print("  .", n)
if errors:
    print(f"\nCHYBY ({len(errors)}):")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)
print("\nOK: zadavaci balicek je konzistentni.")
