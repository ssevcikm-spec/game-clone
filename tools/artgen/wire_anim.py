#!/usr/bin/env python3
"""ZAPOJENI IMPORTU ANIMACI DO HRY (`wire_anim.py`) - Faze B: jedna vrstva, jeden anim list.

CO TO DELA (a proc)
-------------------
`import_anim.py` vyrobi z producentske sady herni format: `anim-sheets.json` + pruh PNG.
Hra ho cte pres `assets/own-art.json`: kazda vrstva ma JEDEN `anim` list a `render/anim_player.gd`
ji indexuje PRED UO manifestem. Tahle skripta prevezme 1+ importovanych sad a SLIJE je do
anim listu existujici vlastni vrstvy:

  * pruh PNG zkopiruje do slozky anim listu (protoze `file` se ve hre preklada relativne
    k te slozce - viz `anim_player._prijmi`, `zaklad = cesta.get_base_dir() + "/"`),
  * prida/ prepise klice `telo/skupina/smer` (nove vyhrava: hra bere prvni vrstvu),
  * doplni `groups` (mapa akce -> skupina pro telo), `actions` necha z ciloveho listu,
  * zapise zpatky se stejnym formatem (indent=1, UTF-8, LF).

CO NEDELA: nemeni `assets/own-art.json` (vrstva musi existovat uz) a nespousti brany -
to je prace volajiciho. Neni to brana; je to jednorazovy nastroj integrace s vypisem,
co udelal (zadny tichy zapis).

POUZITI
-------
    python tools/artgen/wire_anim.py ^
        --anim-file assets/own-v3/anim/anim-sheets.json ^
        --import .cache/wire-anim/hra44-walk ^
        [--import .cache/wire-anim/hra44-attack] ... [--tise]

NAVRATOVE KODY
    0 = zapojeno (nebo --tise bez chyb)
    1 = VADA (chybi vstup, neplatny JSON, chybejici PNG)
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def nacti_json(cesta: Path) -> dict:
    if not cesta.is_file():
        raise ValueError(f"chybi JSON: {cesta}")
    data = json.loads(cesta.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{cesta}: neni slovnik")
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--anim-file", required=True,
                    help="cilovy anim list vlastni vrstvy (assets/.../anim-sheets.json)")
    ap.add_argument("--import", dest="importy", action="append", default=[],
                    help="slozka s vystupem import_anim.py (lze vicekrat)")
    ap.add_argument("--tise", action="store_true")
    o = ap.parse_args()

    cil = (ROOT / o.anim_file) if not Path(o.anim_file).is_absolute() else Path(o.anim_file)
    if not o.importy:
        print("VADA: chybi --import (alespon jedna importovana sada)")
        return 1
    try:
        cil_data = nacti_json(cil)
    except ValueError as e:
        print(f"VADA: {e}")
        return 1
    sprites_cil: dict = cil_data.setdefault("sprites", {})
    groups_cil: dict = cil_data.setdefault("groups", {})
    zdroje = []
    prepsano = 0
    pridano = 0
    for slozka in o.importy:
        imp = Path(slozka)
        if not imp.is_dir():
            print(f"VADA: importovana slozka neexistuje: {imp}")
            return 1
        try:
            data = nacti_json(imp / "anim-sheets.json")
        except ValueError as e:
            print(f"VADA: {e}")
            return 1
        for key, zaznam in (data.get("sprites") or {}).items():
            if not isinstance(zaznam, dict):
                print(f"VADA: {imp.name}: zaznam {key} neni slovnik")
                return 1
            soubor = str(zaznam.get("file", ""))
            if soubor == "":
                print(f"VADA: {imp.name}: zaznam {key} nema 'file'")
                return 1
            zdroj_png = imp / soubor
            if not zdroj_png.is_file():
                print(f"VADA: {imp.name}: chybi PNG {zdroj_png}")
                return 1
            shutil.copy2(zdroj_png, cil.parent / soubor)
            if key in sprites_cil:
                prepsano += 1
            else:
                pridano += 1
            sprites_cil[key] = zaznam
        for telo, mapa in (data.get("groups") or {}).items():
            if not isinstance(mapa, dict):
                continue
            cil_mapa = groups_cil.setdefault(str(telo), {})
            for klic, hodnota in mapa.items():
                cil_mapa[str(klic)] = hodnota
        zdroje.append(imp.name)
    cil_data.setdefault("_wire", {})
    cil_data["_wire"] = {
        "nastroj": "tools/artgen/wire_anim.py",
        "zdroje": zdroje,
        "poznamka": ("Slo z importu producenta; `file` je relativni k teto slozce. "
                     "Kdo meni anim list rucne, ma to zapsat sem."),
    }
    cil.write_text(json.dumps(cil_data, ensure_ascii=False, indent=1) + "\n",
                   encoding="utf-8", newline="\n")
    if not o.tise:
        print(f"ZAPOJENO do {cil}: zdroje={zdroje}, klicu pridano={pridano}, prepsano={prepsano}")
        print(f"  sprites celkem={len(sprites_cil)}, groups tela={list(groups_cil.keys())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
