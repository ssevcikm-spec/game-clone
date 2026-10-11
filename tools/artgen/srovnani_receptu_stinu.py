# -*- coding: utf-8 -*-
"""srovnani_receptu_stinu.py - VARIANTY RECEPTU STINU na skutecne dlazdici.

  python tools/artgen/srovnani_receptu_stinu.py
      -> tools/artgen/_srovnani-recept-stinu.png + .json

PROC: prvni verze receptu v3 (sila 1,0) vysla na listu 1 : 1 jako TMAVY OBJEM
kolem predmetu, ne jako kontaktni stin (namEReno POHLEDEM 2026-10-11). Cislo
("stin ma 28 px, max 123/255") pritom vypadalo dobre - proto se varianta musi
POSOUDIT POHLEDEM, ve stejnem meritku a na skutecne dlazdici.

Varianta se pousti CELOU cestou jako v `pack_atlas_v3.py` (dva pruchody palety,
tvrda alfa) - jinak by se neposuzovalo to, co by hra dostala.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import artgen_common as ac1
import artgen_common_v3 as acv
import postprocess_lit as ppl
import styl

HERE = Path(__file__).resolve().parent
RAW = HERE / "_rawv3"
UO = Path("assets/uo")

# Varianty: jmeno -> (sila, sirka_px, mekkost_px, odstup_px, posun_px)
VARIANTY = {
    "v3s100": dict(verze="v3", sila=1.00, sirka_px=0.6, mekkost_px=1.2,
                   odstup_px=0.9, posun_px=(-2, -1), jadro_sila=0.0),
    "v3s50": dict(verze="v3", sila=0.50, sirka_px=0.6, mekkost_px=1.2,
                  odstup_px=0.9, posun_px=(-2, -1), jadro_sila=0.0),
    "v3s40": dict(verze="v3", sila=0.40, sirka_px=0.6, mekkost_px=1.2,
                  odstup_px=0.9, posun_px=(-2, -1), jadro_sila=0.0),
    "v3s30": dict(verze="v3", sila=0.30, sirka_px=0.6, mekkost_px=1.2,
                  odstup_px=0.9, posun_px=(-2, -1), jadro_sila=0.0),
    "v3s20": dict(verze="v3", sila=0.20, sirka_px=0.6, mekkost_px=1.2,
                  odstup_px=0.9, posun_px=(-2, -1), jadro_sila=0.0),
}
PRVKY = [("item", 3921), ("item", 7151), ("item", 6583), ("item", 3717)]
KOLIK = 6
VZOREK = 110          # px vyrez okolo kontaktu


def _origin(davka: str):
    o = json.loads((RAW / f"_origin_{davka}.json").read_text(encoding="utf-8"))
    return (o["origin_x"], o["origin_y"])


def _priprav(kind: str, ident: int, jmeno: str):
    if kind == "item":
        p = ppl.priprav(RAW / f"item_{jmeno}.png", _origin(f"item_{jmeno}"),
                        stin=RAW / f"_stin_item_{jmeno}.png",
                        ref=RAW / f"_ref_item_{jmeno}.png")
        vyska = next(i["uo_content"][1] for i in acv.ITEMS if i["name"] == jmeno)
    else:
        raise ValueError(kind)
    return p, vyska


def pozadi(ident_dlazdice: int = 3) -> Image.Image:
    man = json.loads((UO / "manifest.json").read_text(encoding="utf-8"))
    t = None
    for s in man["sprites"]:
        if s["kind"] == "land" and s["id"] == ident_dlazdice:
            t = Image.open(UO / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    if t is None:
        raise SystemExit("v UO neni land 3")
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


def main() -> int:
    ap = argparse.ArgumentParser(description="varianty receptu stinu v3")
    ap.add_argument("--vystup", default="tools/artgen/_srovnani-recept-stinu.png")
    ap.add_argument("--json", default="tools/artgen/_srovnani-recept-stinu.json")
    a = ap.parse_args()
    poz = pozadi()
    vysledky: dict[str, dict] = {}
    bunky: dict[tuple, Image.Image] = {}
    for jmeno_v, recept in VARIANTY.items():
        ppl.RECEPTY_STINU[jmeno_v] = dict(recept)
        ppl.nastav_recept_stinu(jmeno_v)
        vysledky[jmeno_v] = {}
        for kind, ident in PRVKY:
            jm = next(i["name"] for i in acv.ITEMS if i["uo_id"] == ident)
            p, vyska = _priprav(kind, ident, jm)
            s = ppl.meritko([p], obsah_vyska_px=vyska)
            sber = styl.SadaPalety()
            ppl.sestav([p], s, kind, popis=jm, sber=sber)
            pal = sber.postav()
            spr, meta = ppl.sestav([p], s, kind, popis=jm, paleta=pal,
                                   tvrda_alfa=True)
            m = meta[0]
            a_ = np.array(spr[0])
            alfa = a_[:, :, 3]
            telo = alfa >= 200
            jadro = __import__("scipy").ndimage.binary_erosion(telo, iterations=1)
            jas = a_[:, :, :3].mean(axis=2)[jadro] if jadro.any() else np.array([0.0])
            stin = (alfa > 0) & (alfa < 200)
            sa = alfa[stin]
            vysledky[jmeno_v][ident] = {
                "stin_viditelne_px": m["stin_viditelne_px"],
                "stin_max_alfa": m["stin_max_alfa"],
                "stin_prumer_alfa": round(float(sa.mean()), 1) if sa.size else 0.0,
                "telo_sd": round(float(jas.std()), 2),
                "telo_jas": round(float(jas.mean()), 2),
                "box": [spr[0].width, spr[0].height]}
            bunky[(jmeno_v, ident)] = na_dlazdici(spr[0], poz)
    ppl.nastav_recept_stinu("v3")

    # list: rada = varianta, sloupec = prvek
    velikost = VZOREK * KOLIK
    p = Image.new("RGB", (velikost * len(PRVKY) + 10,
                          velikost * len(VARIANTY) + 30), (20, 22, 26))
    d = ImageDraw.Draw(p)
    for c, (_k, ident) in enumerate(PRVKY):
        d.text((12 + velikost * c, 6), f"item {ident}", fill=(240, 240, 240))
    for r, jmeno_v in enumerate(VARIANTY):
        y = 20 + velikost * r
        # ⚠ POPISEK RADY PATRI DO OBRAZKU: prvni verze listu popisek vypisovala
        # mimo plochu radku (na y+4 pres bunku) a na nahledu nebyl videt - kdo se
        # na list dival, nevedel, ktera rada je ktera varianta.
        d.rectangle([2, y, 8 + 10, y + 18], fill=(20, 22, 26))
        d.text((6, y + 3), jmeno_v, fill=(255, 235, 120))
        for c, (_k, ident) in enumerate(PRVKY):
            img = bunky.get((jmeno_v, ident))
            if img is None:
                continue
            p.paste(img.resize((velikost, velikost), Image.NEAREST),
                    (10 + velikost * c, y))
    p.save(a.vystup)
    Path(a.json).write_text(json.dumps(
        {"co_to_je": "varianty receptu stinu v3 (sila pasu) na skutecne dlazdici",
         "varianta_parametry": VARIANTY, "cisla": vysledky},
        ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    for jmeno_v in VARIANTY:
        v = vysledky[jmeno_v]
        print(f"{jmeno_v:8s} " + "  ".join(
            f"{i}: px {v[i]['stin_viditelne_px']:3d} max {v[i]['stin_max_alfa']:3d} "
            f"prum {v[i]['stin_prumer_alfa']:5.1f}" for _k, i in PRVKY))
    print(f"LIST {a.vystup} ({p.width}x{p.height})")
    print(f"ZAPIS {a.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
