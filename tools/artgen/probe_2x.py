# -*- coding: utf-8 -*-
"""probe_2x.py - čísla k srovnávacímu listu (barvy, ostrost, krytí stinu).

Sonda k `ZADANI-25` §9: "co je na 2x vidět lépe a co ne" se nemá psát od oka.
Měří se tři věci, každá na obsahu (alfa >= 200), aby se nepočítalo prázdno:

  * PRUMERNA BARVA - změnilo se světlo (1 slunce + AO místo 3 sluncí), takže
    se musí přeměřit, ne předpokládat.
  * OSTROST HRANY - průměr |Laplace| alfy na hranici obsahu. Vyšší číslo =
    ostřejší hrana. Po zmensění 2x na 1x se ukáže, co z rozlišení zbylo.
  * KRYTÍ STINU - kolik pixelů spritu je poloprůhledných (to je stín) a jak
    tmavé jsou.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artgen_common as ac1  # noqa: E402
import artgen_common_2x as ac2  # noqa: E402
import postprocess as pp  # noqa: E402
import uo_ref  # noqa: E402

UO = Path("assets/uo")
OWN1X = Path("assets/own")
OWN2X = Path("assets/own2x")


def _sprite_uo(kind, ident):
    m = uo_ref.nacti_manifest(UO / "manifest.json")
    z = uo_ref.zaznam(m, kind, ident)
    return None if z is None else uo_ref.Stranky(UO).sprite(z)


def _sprite(zaklad, kind, ident):
    m = json.loads((zaklad / "manifest.json").read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return Image.open(zaklad / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def _uo_anim(frame):
    d = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
    v = d["sprites"]["400/0/0"]
    fr = v["frames"][frame]
    return Image.open(UO / "anim" / v["file"]).convert("RGBA").crop(tuple(fr["rect"]))


def barva(img: Image.Image):
    a = np.asarray(img)
    m = a[:, :, 3] >= 200
    if not m.any():
        return None, 0
    return [int(round(v)) for v in a[:, :, :3][m].mean(axis=0)], int(m.sum())


def ostrost(img: Image.Image):
    """Prumer |Laplace| ALFY na hranici obsahu (vyssí = ostřejsi hrana)."""
    a = np.asarray(img.split()[3], dtype=np.float32) / 255.0
    if a.max() <= 0:
        return None
    lap = np.abs(4 * a[1:-1, 1:-1] - a[:-2, 1:-1] - a[2:, 1:-1]
                 - a[1:-1, :-2] - a[1:-1, 2:])
    hrana = lap > 1e-6
    return round(float(lap[hrana].mean()), 4) if hrana.any() else 0.0


def stin(img: Image.Image):
    a = np.asarray(img)[:, :, 3]
    pol = (a > 0) & (a < 200)
    return {"px": int(pol.sum()), "max_alfa": int(a.max()),
            "krytí_prumer": round(float(a[pol].mean()), 1) if pol.any() else 0.0}


def main() -> int:
    print("== DYKA (item 3921) ==")
    d_uo = _sprite_uo("item", 3921)
    d1 = _sprite(OWN1X, "item", 3921)
    d2 = _sprite(OWN2X, "item", 3921)
    d2p = pp.zmensi(d2, (d2.width // 2, d2.height // 2))
    for jmeno, img in (("UO", d_uo), ("1x", d1), ("2x", d2), ("2x/2", d2p)):
        b, n = barva(img)
        print(f"  {jmeno:5s} box {img.width:3d}x{img.height:<3d} obsah_px {n:5d} "
              f"barva {b} ostrost {ostrost(img)} stin {stin(img) if jmeno == '2x' else '-'}")

    print("== POSTAVA (telo 400, smer 0, frame 0) ==")
    a_uo = _uo_anim(0)
    a1 = _sprite(OWN1X, "anim", ac1.anim_id(0, 0))
    a2 = _sprite(OWN2X, "anim", ac2.anim_id(0, 0))
    a2p = pp.zmensi(a2, (a2.width // 2, a2.height // 2))
    for jmeno, img in (("UO", a_uo), ("1x", a1), ("2x", a2), ("2x/2", a2p)):
        b, n = barva(img)
        print(f"  {jmeno:5s} box {img.width:3d}x{img.height:<3d} obsah_px {n:5d} "
              f"barva {b} ostrost {ostrost(img)} stin {stin(img) if jmeno == '2x' else '-'}")

    print("== PLOCHA BOXU (cena v atlase) ==")
    for jmeno, i1, i2 in (("dyka", d1, d2), ("postava", a1, a2)):
        p1, p2 = i1.width * i1.height, i2.width * i2.height
        print(f"  {jmeno:8s} 1x {p1:6d} px2 -> 2x {p2:6d} px2 = {p2 / p1:.2f}x "
              f"(4x by bylo z rozliseni, zbytek dela stin/box)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
