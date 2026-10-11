#!/usr/bin/env python3
"""check-data-paths - MERENI S1b: je cesta k datum PARAMETR, nebo zapeena konstanta?

Proc: modding stoji na tom, ze mod prebije soubor. Kdyz modul cte konstantu
PRIMO, neda se prebit vubec - a mod pak "funguje zdanlive" (u nekterych
souboru ano, u jinych ne). Presne to byl stav do 2026-10-11 (S1b,
`NAVRH-MODDING-2026-10-11.md` §3 bod 2, smlouva `docs/04 §4.9.1`).

Metrika (staticka, orientacni - chovani meri `tests/cases/content_paths.gd`):
pro kazdou modulovou konstantu `const X := "res://data/*.json"` se v TOMTEZ
souboru hleda jeji vyskyt:
  * v SIGNATURE funkce (`func _init(..., path: String = X)`) -> default
    parametru, coz je PRESNE to, co S1b chce,
  * MIMO signaturu a mimo radek deklarace -> telo modulu konstantu CTE PRIMO
    (vada: mod to neprebije, i kdyz ma modul parametr).
Komentare se pred hledanim ODSTRAVI - jinak by stacilo o vade napsat komentar
a metrika by ji nasla v nem.

Kategorie vystupu:
  * `parametr`   - jen jako default parametru (OK),
  * `primo`      - cte se v tele (VADA v sim/),
  * `smisene`    - je parametrem I se cte v tele (VADA v sim/),
  * `nepouzita`  - nikde (ani v signature, ani v tele),
  * `deklarace`  - `sim/content.gd` (BASE_DECL): deklarace zakladu, OK,
  * `volajici`   - `app/` (rozhodovaci misto: `app/main` preklada cesty),
                   pocita se a VYPISUJE, ale za vadu se nepovazuje.

Verdikt: `sim/` (mimo `sim/content.gd`) nesmi mit `primo` ani `smisene`.
Exit 1 = VADA (pouziva to mutacni harness `_analyza/p68-mutace-s1b.py`).

Kde to je: `tools/` (ne `_analyza/`), aby se nastroj dovezl s repem - metrika,
 ktera zustane v gitignorovanem adresari, pro budouci session neexistuje.
NENI to brana v `tools/gates/run-all.py` (nova brana je zmena smlouvy).

Spousteni: $env:PYTHONIOENCODING='utf-8'; python tools/check-data-paths.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
KONST = re.compile(r'^\s*const\s+([A-Za-z0-9_]+)\s*(?::=\s*|:\s*String\s*=\s*)"(res://data/[A-Za-z0-9_.-]+\.json)"')


def bez_komentaru(text: str) -> str:
    # Odstrani `#` komentare (znak v retezci neresime - v techto souborech se
    # `#` v ceskych textech nevyskytuje; kdyby ano, metrika je orientacni).
    return "\n".join(radek.split("#", 1)[0] for radek in text.splitlines())


def main() -> int:
    # Signatury se hledaji PRES VICE RADKU: `func _init(registry, ...,\n
    #     weapons_path: String = WEAPONS_PATH, ...)` je jedna signatura.
    sygnatura = re.compile(r"func\s+[A-Za-z0-9_]+\s*\((?:[^()]|\([^()]*\))*\)", re.S)
    kategorie: dict[str, list[str]] = {
        "parametr": [], "primo": [], "smisene": [], "nepouzita": [],
        "deklarace": [], "volajici": [],
    }
    for path in sorted((ROOT / "sim").rglob("*.gd")) + sorted((ROOT / "app").rglob("*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        cisty = bez_komentaru(text)
        radky = cisty.splitlines()
        # radky, ktere lezi UVNITR nektere signatury
        v_signature: set[int] = set()
        for m in sygnatura.finditer(cisty):
            prvni = cisty.count("\n", 0, m.start())
            posledni = cisty.count("\n", 0, m.end())
            for i in range(prvni, posledni + 1):
                v_signature.add(i)
        for i, radek in enumerate(text.splitlines(), 1):
            m = KONST.match(radek)
            if not m:
                continue
            jmeno, cesta = m.group(1), m.group(2)
            kde = f"{rel}:{i}:{cesta} ({jmeno})"
            vzor = re.compile(rf"(?<![\w.]){jmeno}(?![\w])")
            pouziti: list[str] = []
            v_sig = False
            for j, r in enumerate(radky):
                if j == i - 1:
                    continue                     # radek deklarace neni pouziti
                if not vzor.search(r):
                    continue
                if j in v_signature:
                    v_sig = True
                else:
                    pouziti.append(f"{rel}:{j + 1}")
            if rel == "sim/content.gd":
                cil = "deklarace"
            elif rel.startswith("app/"):
                cil = "volajici"
            elif v_sig and pouziti:
                cil = "smisene"
            elif v_sig:
                cil = "parametr"
            elif pouziti:
                cil = "primo"
            else:
                cil = "nepouzita"
            kategorie[cil].append(kde + (f" [pouziti: {', '.join(pouziti)}]" if pouziti else ""))

    vady_sim = [k for k in kategorie["primo"] + kategorie["smisene"] if k.startswith("sim/")]
    out = {
        "metrika": "modulove konstanty s cestou k datum: parametr vs. primo (S1b)",
        "kategorie": {k: len(v) for k, v in kategorie.items()},
        "seznam": kategorie,
        "vady_sim": vady_sim,
        "stav": "VADA" if vady_sim else "OK",
    }
    report = ROOT / ".cache" / "check-data-paths.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

    print("=== check-data-paths: modulove konstanty s cestou k datum (sim/ a app/) ===")
    for k in ("parametr", "primo", "smisene", "nepouzita", "deklarace", "volajici"):
        print(f"{k:10s}: {len(kategorie[k])}")
        for h in kategorie[k]:
            print("   ", h)
    print("-" * 60)
    if vady_sim:
        print(f"STAV: VADA - {len(vady_sim)} konstant v sim/ se cte PRIMO "
              "(mod je neprebije; NAVRH-MODDING §4 S1b)")
        return 1
    print("STAV: OK - vsechny datove konstanty v sim/ jsou jen default PARAMETRU "
          "(mod je prebije; `app/` rozhoduje na jednom miste)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
