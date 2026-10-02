"""Oprava internich odkazu v docs/01 a docs/02.

V tabulce vernostnich bodu (V1-V12) v docs/01 odkazovaly sekce na §8.x
(ze ktereho se mezitim staly BRANY), ale mysleny byly mechaniky §5.x.
Pozor: §8.1-§8.9 v docs/08 skutecne existuji, takze kontrola odkazu to
NEPOZNALA - odkaz se "rozresil" na jinou sekci. Presne ta past, pred kterou
projekt varuje: odkaz muze byt syntakticky v poradku a vecne vedle.
"""
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DOCS = Path(r"E:\Workspaces\game-clone\docs")

d1 = DOCS / "01-cil-a-scope.md"
t = d1.read_text(encoding="utf-8")
before = t
for n in ("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"):
    t = t.replace(f"§8.{n}", f"§5.{n}")
t = t.replace("| §9 |", "| §6 |")
d1.write_text(t, encoding="utf-8")
print(f"01-cil-a-scope.md: zmenenych znaku {len(before) - len(t)}")

d2 = DOCS / "02-technicka-rozhodnuti.md"
t = d2.read_text(encoding="utf-8")
before = t
t = t.replace("§8.11", "§5.11")
d2.write_text(t, encoding="utf-8")
print(f"02-technicka-rozhodnuti.md: zmenenych znaku {len(before) - len(t)}")

# kontrola: v docs/01 uz nesmi byt odkaz na §8.<cislo>
bad = [l for l in d1.read_text(encoding="utf-8").splitlines() if "§8." in l]
print("zbyle odkazy §8.x v docs/01:", bad if bad else "zadne")
