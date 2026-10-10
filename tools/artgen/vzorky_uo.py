# -*- coding: utf-8 -*-
"""vzorky_uo.py - NAMERENE barvy a rozmery UO artu, ktery nahrazujeme.

  python tools/artgen/vzorky_uo.py            # vypise prumerne barvy a rozmery
  python tools/artgen/vzorky_uo.py --json     # totez jako JSON

PROC: "udelej to jako UO" se neda splnit od oka - barva se da ZMERIT. Tenhle
nastroj cte `assets/uo/` (jen CTENI) a vraci prumer barvy pres nepruhledne
pixely + obsahovy bounding box. Vysledky jdou do `artgen_common.py` (barvy
materialu) a do `MERENI.md` (odchylka naseho artu od UO).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

import artgen_common as ac
import uo_ref


def vzorek(kind: str, ident: int, zaklad: Path = Path("assets/uo")) -> dict | None:
    m = uo_ref.nacti_manifest(zaklad / "manifest.json")
    z = uo_ref.zaznam(m, kind, ident)
    if z is None:
        return None
    img = uo_ref.Stranky(zaklad).sprite(z)
    a = np.array(img).astype(np.float64)
    maska = a[:, :, 3] > 200
    if not maska.any():
        return None
    barvy = a[:, :, :3][maska]
    bbox = uo_ref.obsah(img)
    # prumer a rozptyl (smerodatna odchylka) - rozptyl je "jak moc je textura
    # mramorovana"; jednolita barva se pozna podle maleho rozptylu
    return {
        "kind": kind, "id": ident, "w": z["w"], "h": z["h"],
        "obsah": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "obsah_bbox": list(bbox),
        "prumer_rgb": [round(float(v) / 255.0, 4) for v in barvy.mean(axis=0)],
        "prumer_rgb_255": [int(round(float(v))) for v in barvy.mean(axis=0)],
        "odchylka_rgb": [round(float(v) / 255.0, 4) for v in barvy.std(axis=0)],
        "pixelu": int(maska.sum()),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="vzorky z UO artu (jen cteni)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="tools/artgen/_vzorky-uo.json")
    a = ap.parse_args()
    out = {"land": [], "item": [], "anim": []}
    for spec in ac.LAND:
        v = vzorek("land", spec["uo_id"])
        if v:
            v["jmeno"] = spec["name"]
            out["land"].append(v)
    for spec in ac.ITEMS:
        v = vzorek("item", spec["uo_id"])
        if v:
            v["jmeno"] = spec["name"]
            out["item"].append(v)
    Path(a.out).write_text(json.dumps(out, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                           encoding="utf-8", newline="\n")
    for druh, seznam in out.items():
        for v in seznam:
            print(f"{druh:5s} {v['jmeno']:8s} {v['w']:3d}x{v['h']:<3d} obsah {v['obsah'][0]:3d}x"
                  f"{v['obsah'][1]:<3d} prumer RGB {v['prumer_rgb_255']} "
                  f"odchylka {[round(x * 255) for x in v['odchylka_rgb']]}")
    print(f"[vzorky_uo] zapsano {a.out}")
    if a.json:
        print(json.dumps(out, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
