#!/usr/bin/env python3
"""PIXEL-ART STYL PRO IMPORT ANIMACI (`styl_anim.py`) - Faze B: render -> pixel art.

PROC TO EXISTUJE (namEReno 23. 10. 2026)
----------------------------------------
`import_anim.py` prenese producentske framy tak, jak vznikly: **Lanczos zmensenina
3D renderu** = hladke polopruhledne okraje a stovky barev. Hra ale kresli pixel art
a brana **G16** to meri: vlastni animace musi mit na siluete alfa 0/255 a malou
paletu. Prvni zapojeni `hra-44` do hry spadlo presne na tomhle (G16: 209
polopruhlednych pixelu a 210 barev u jednoho framu). Reseni neni vypnout branu,
ale **aplikovat tyz styl, jaky pouziva `tools/artgen/styl.py` pro ostatni vlastni
art**: tvrda alfa na siluete + paleta z barvu, ktere se opravdu kresli.

CO TO DELA
----------
Vezme slozku s vystupem `import_anim.py` (anim-sheets.json + pruhy PNG) a pro
KAZDOU sadu:
  1. posbira vzorky barev ze vsech framu vsech smeru (jeden render = jeden model),
  2. postavi paletu (`styl.SadaPalety`, stredni rezy, bez ditheringu),
  3. na kazdem pruhu udela tvrdou alfu (hysterze 128/64 + dilace, viz `styl.tvrda_alfa`),
  4. namapuje barvy na paletu,
  5. zapise PNG do `--vystup` (rozmery i nazvy zustavaji - `rect` v anim listu plati dal).

CO NEDELA: nemeni `anim-sheets.json` (geometrie, kotvy ani framy), nemeni `own-art.json`
a nespousti brany. Neni to brana - je to jednorazovy konverzni krok; vysledek se
overuje branou G16, ne timhle skriptem.

POUZITI
-------
    python tools/artgen/styl_anim.py --slozka .cache/wire-anim/hra44-walk ^
                                     --vystup .cache/wire-anim/hra44-walk-styl

NAVRATOVE KODY: 0 = hotovo, 1 = VADA, 2 = NEMERENO (zadne PNG)
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import styl  # noqa: E402


def gate_maska(alfa: np.ndarray) -> np.ndarray:
    """Maska pro tvrdou alfu: vse, kde je co videt, rozsirene o 2 px (obal z Lanczosu)."""
    return ndimage.binary_dilation(alfa > 0, iterations=2)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--slozka", required=True, help="vystup import_anim.py (anim-sheets.json)")
    ap.add_argument("--vystup", required=True, help="kam zapsat ostylovane PNG + kopii JSONu")
    ap.add_argument("--paleta-barve", type=int, default=styl.PALETA_BAREV)
    o = ap.parse_args()

    zdroj = Path(o.slozka)
    if not zdroj.is_dir():
        print(f"VADA: slozka neexistuje: {zdroj}")
        return 1
    sheet_path = zdroj / "anim-sheets.json"
    if not sheet_path.is_file():
        print(f"VADA: chybi {sheet_path}")
        return 1
    sheet = json.loads(sheet_path.read_text(encoding="utf-8"))
    sprites = sheet.get("sprites") or {}
    soubory = sorted({str(z["file"]) for z in sprites.values() if isinstance(z, dict)})
    if not soubory:
        print("NEMERENO: anim list nema zadny 'file'")
        return 2
    vystup = Path(o.vystup)
    vystup.mkdir(parents=True, exist_ok=True)

    # 1) vzorky barev ze vsech framu vsech smeru
    sber = styl.SadaPalety(pocet=o.paleta_barve)
    obrazy: dict[str, tuple[np.ndarray, np.ndarray]] = {}
    for jmeno in soubory:
        cesta = zdroj / jmeno
        if not cesta.is_file():
            print(f"VADA: chybi PNG {cesta}")
            return 1
        im = Image.open(cesta).convert("RGBA")
        pole = np.asarray(im)
        rgb, alfa = pole[..., :3], pole[..., 3]
        obrazy[jmeno] = (rgb, alfa)
        sber.pridej(rgb, alfa)
    paleta = sber.postav()
    barvy = len(styl.barvy_palety(paleta)) if paleta is not None else 0

    # 2) tvrda alfa + paleta na kazdem pruhu; rozmery se nesmi zmenit
    on_siluete = 0
    for jmeno in soubory:
        rgb, alfa = obrazy[jmeno]
        alfa2 = styl.tvrda_alfa(alfa, gate_maska(alfa))
        rgb2 = styl.na_paletu(rgb, paleta)
        on_siluete += int(np.count_nonzero((alfa2 > 0) & (alfa2 < 255)))
        out = np.dstack([rgb2.astype(np.uint8), alfa2.astype(np.uint8)])
        img = Image.fromarray(out, "RGBA")
        puvodni = Image.open(zdroj / jmeno)
        if img.size != puvodni.size:
            print(f"VADA: {jmeno}: rozmery se zmenily {puvodni.size} -> {img.size}")
            return 1
        img.save(vystup / jmeno)
    shutil.copy2(sheet_path, vystup / "anim-sheets.json")
    (vystup / "_styl.json").write_text(json.dumps({
        "nastroj": "tools/artgen/styl_anim.py",
        "zdroj": str(zdroj),
        "paleta_barev": barvy,
        "semi_transparentni_na_siluete": on_siluete,
        "pruhu": len(soubory),
        "poznamka": ("Tvrda alfa + paleta ze vzorku; rozmery a nazvy pruhu zustavaji, "
                     "takze rect v anim listu plati dal."),
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    if on_siluete != 0:
        print(f"VADA: na siluete zustalo {on_siluete} polopruhlednych pixelu")
        return 1
    print(f"OSTYLOVANO {zdroj.name} -> {vystup}: pruhu={len(soubory)}, "
          f"paleta={barvy} barev, semi-transparentnich na siluete=0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
