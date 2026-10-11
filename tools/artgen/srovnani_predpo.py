# -*- coding: utf-8 -*-
"""srovnani_predpo.py - "PRED / PO": jeden sprite 1 : 1 na dlazdici, 8x zvetseny.

  python tools/artgen/srovnani_predpo.py --ids 3921,7151,6583,3717
      -> tools/artgen/_srovnani-predpo.png   + .json

PROC A CIM SE LISI OD `_srovnani-v3.png`: ten list je prehled celych sad a
NENI ve stejnem meritku (UO sprite ma jinou velikost). Na otazku "je stin
citelnejsi" je potreba POHLED 1 : 1 na TOMTEZ MERITKU - tady je bunka vyrez
okolo kontaktu ze sprite ZVETSENY 8x (NEAREST, zadna interpolace), takze je
videt jednotlive pixely stinu.

Sloupce: nas lit (stary) | nas v3 (novy). Rada = prvek, druha cast = tyz prvek
na ceste. Cisla (pocet a krytí stinu) se hlasí Z PIXELU tohoto listu.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import artgen_common as ac1
import artgen_common_lit as acl
import artgen_common_v3 as acv

HERE = Path(__file__).resolve().parent
SADY = [("lit (stary)", acl.SADA), ("v3 (novy)", acv.SADA)]
VZOREK = 60          # px okolo kontaktu
KOLIK = 8            # zvetseni 1 : 1


def _man(sada: Path) -> dict:
    cesta = sada / "manifest.json"
    if not cesta.exists():
        raise SystemExit(f"chybi {cesta}")
    return json.loads(cesta.read_text(encoding="utf-8"))


def _sprite(sada: Path, man: dict, kind: str, ident: int):
    for s in man["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def _dlazdice(sada: Path, man: dict, ident: int):
    for s in man["sprites"]:
        if s["kind"] == "land" and s["id"] == ident:
            return Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def pozadi(sada: Path, man: dict, ident: int) -> Image.Image:
    t = _dlazdice(sada, man, ident)
    if t is None:
        uo = Path("assets/uo")
        m = _man(uo)
        t = _dlazdice(uo, m, ident)
    w = 44 + 44
    out = Image.new("RGBA", (w, w), (0, 0, 0, 255))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out.alpha_composite(t, (22 + 22 * dx, 22 + 22 * dy))
    return out


def na_dlazdici(spr: Image.Image, poz: Image.Image) -> Image.Image:
    out = poz.copy()
    kx, ky = spr.width // 2, spr.height - ac1.GROUND_PX
    cx, cy = out.width // 2, out.height // 2
    out.alpha_composite(spr, (cx - kx, cy - ky))
    levy, horni = max(0, cx - VZOREK // 2), max(0, cy - VZOREK // 2)
    return out.crop((levy, horni, levy + VZOREK, horni + VZOREK))


def cisla(spr: Image.Image) -> dict:
    a = np.asarray(spr)
    alfa = a[:, :, 3]
    stin = (alfa > 0) & (alfa < 200)
    sa = alfa[stin]
    telo = alfa >= 200
    jadro = __import__("scipy").ndimage.binary_erosion(telo, iterations=1)
    jas = a[:, :, :3].mean(axis=2)[jadro] if jadro.any() else np.array([0.0])
    return {"box": [spr.width, spr.height],
            "stin_px": int(stin.sum()),
            "stin_max_alfa": int(sa.max()) if sa.size else 0,
            "stin_prumer_alfa": round(float(sa.mean()), 1) if sa.size else 0.0,
            "telo_sd": round(float(jas.std()), 2),
            "telo_jas": round(float(jas.mean()), 2),
            "telo_barvy": int(len(np.unique(a[:, :, :3][telo].reshape(-1, 3), axis=0)))
            if telo.any() else 0}


def main() -> int:
    ap = argparse.ArgumentParser(description="pred/po jeden sprite 1:1")
    ap.add_argument("--ids", default="3921,7151,6583,3717")
    ap.add_argument("--vystup", default="tools/artgen/_srovnani-predpo.png")
    ap.add_argument("--json", default="tools/artgen/_srovnani-predpo.json")
    a = ap.parse_args()
    ids = [int(v) for v in a.ids.split(",") if v.strip()]
    many = {j: _man(s) for j, s in SADY}
    vysledky: dict[str, dict] = {}
    bunky: dict[tuple, Image.Image] = {}
    for jmeno, sada in SADY:
        man = many[jmeno]
        for ident in ids:
            spr = _sprite(sada, man, "item", ident)
            if spr is None:
                print(f"CHYBI {jmeno} item {ident}")
                continue
            vysledky[f"{jmeno} {ident}"] = cisla(spr)
            for dlazdice_id in (3, 1001):
                bunky[(jmeno, dlazdice_id, ident)] = na_dlazdici(
                    spr, pozadi(sada, man, dlazdice_id))
    velikost = VZOREK * KOLIK
    sloupcu = len(SADY)
    radku = 2 * len(ids)
    p = Image.new("RGB", (velikost * sloupcu + 10, velikost * radku + 26),
                  (20, 22, 26))
    d = ImageDraw.Draw(p)
    for c, (jmeno, _s) in enumerate(SADY):
        d.text((12 + velikost * c, 6), jmeno, fill=(255, 235, 120))
    r = 0
    for dlazdice_id, popis_d in ((3, "trava"), (1001, "cesta")):
        for ident in ids:
            y = 20 + velikost * r
            d.text((4, y + 4), f"{ident}\n{popis_d}", fill=(235, 235, 235))
            for c, (jmeno, _s) in enumerate(SADY):
                img = bunky.get((jmeno, dlazdice_id, ident))
                if img is None:
                    continue
                p.paste(img.resize((velikost, velikost), Image.NEAREST),
                        (10 + velikost * c, y))
            r += 1
    p.save(a.vystup)
    Path(a.json).write_text(json.dumps(
        {"co_to_je": "pred/po: jeden sprite 1:1 na dlazdici, 8x zvetseny",
         "vyrez_px": VZOREK, "zvetseni": KOLIK, "cisla": vysledky},
        ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    for k in sorted(vysledky):
        v = vysledky[k]
        print(f"{k:24s} box {str(v['box']):10s} stin {v['stin_px']:4d} px, "
              f"max {v['stin_max_alfa']:3d}, prumer {v['stin_prumer_alfa']:5.1f}, "
              f"sd tela {v['telo_sd']:5.2f}, jas {v['telo_jas']:5.1f}, "
              f"barvy {v['telo_barvy']:3d}")
    print(f"LIST {a.vystup} ({p.width}x{p.height})")
    print(f"ZAPIS {a.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
