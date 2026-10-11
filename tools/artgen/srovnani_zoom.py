# -*- coding: utf-8 -*-
"""srovnani_zoom.py - ZOOM na jeden prvek ze vsech sad, ve stejnem meritku.

  python tools/artgen/srovnani_zoom.py --ids 3921,7151,6583,3717
      -> tools/artgen/_srovnani-zoom.png

PROC SAMOSTATNY LIST: `_srovnani-v3.png` je na prehled (vsechno najednou), ale
jeho bunky nejsou ve stejnem meritku - UO sprite je jiny velikosti nez nas a do
mrizky se kazdy vejde jinak. Na "je videt stin a je citelnejsi" je potreba
pohled 1 : 1: bunka je 100 x 100 px OKOLO KONTAKTU (kotvy) a zvetsuje se 6x,
takze vsechny sady maji presne stejne meritko.

Sloupce: UO | nas 1x bez svetla | nas lit (stary) | nas v3 (novy)
Rada 1 = trava, rada 2 = cesta (aby se nevybiralo podle jedne dlazdice).
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
SADY = [("UO", Path("assets/uo")), ("nas 1x", Path("assets/own")),
        ("nas lit", acl.SADA), ("nas v3", acv.SADA)]
VYREZ = 100          # px okolo kontaktu
KOLIK = 6            # zvetseni


def _man(sada: Path):
    cesta = sada / "manifest.json"
    return json.loads(cesta.read_text(encoding="utf-8")) if cesta.exists() else None


def _sprite(sada: Path, man: dict, kind: str, ident: int):
    for s in man["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return s, Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None, None


def _dlazdice(sada: Path, man: dict, ident: int):
    for s in man["sprites"]:
        if s["kind"] == "land" and s["id"] == ident:
            return Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def pozadi(sada: Path, man: dict, ident: int) -> Image.Image:
    """3x3 dlazdic jako ve hre (krok 22 px) - stin ma na cem lezet."""
    t = _dlazdice(sada, man, ident)
    if t is None:
        t = _dlazdice(Path("assets/uo"), _man(Path("assets/uo")), ident)
    w = 44 + 2 * 22
    out = Image.new("RGBA", (w, w), (0, 0, 0, 255))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out.alpha_composite(t, (22 + 22 * dx, 22 + 22 * dy))
    return out


def hlavni(ids: list[int], vystup: Path, anim_ids: list[int] = None) -> int:
    """List pres vsechny sady. Rada = (druh, dlazdice, prvek), sloupec = sada.

    `ids` jsou predmety (na trava i cesta), `anim_ids` framy postavy (jen trava).
    """
    many = {j: _man(s) for j, s in SADY}
    radky: list[tuple] = []
    bunky: dict[tuple, Image.Image] = {}
    for jmeno, sada in SADY:
        man = many[jmeno]
        for dlazdice_id in (3, 1001):
            poz = pozadi(sada, man, dlazdice_id)
            for ident in ids:
                _s, spr = _sprite(sada, man, "item", ident)
                if spr is None:
                    continue
                bunky[(jmeno, "item", dlazdice_id, ident)] = na_vyrez(poz, spr)
        poz = pozadi(sada, man, 3)
        for ident in (anim_ids or []):
            _s, spr = _sprite_s_anim(sada, man, "anim", ident)
            if spr is None:
                continue
            bunky[(jmeno, "anim", 3, ident)] = na_vyrez(poz, spr)
    radky = list(dict.fromkeys(
        (k[1], k[2], k[3]) for k in bunky))
    if not bunky:
        print("NIC se nenaslo - zadny prvek v zadne sade (nic se nedopocitava)")
        return 1
    sloupcu = len(SADY)
    velikost = VYREZ * KOLIK
    p = Image.new("RGB", (velikost * sloupcu + 10, velikost * len(radky) + 30),
                  (20, 22, 26))
    d = ImageDraw.Draw(p)
    for c, (jmeno, _s) in enumerate(SADY):
        d.text((10 + velikost * c, 6), jmeno, fill=(255, 235, 120))
    for r, (kind, dlazdice_id, ident) in enumerate(radky):
        y = 20 + velikost * r
        popis = "trava" if dlazdice_id == 3 else "cesta"
        d.text((4, y + 4), f"{kind} {ident}\n{popis}", fill=(235, 235, 235))
        for c, (jmeno, _s) in enumerate(SADY):
            img = bunky.get((jmeno, kind, dlazdice_id, ident))
            if img is None:
                d.text((10 + velikost * c + 4, y + 4), "CHYBI", fill=(255, 120, 120))
                continue
            p.paste(img.resize((velikost, velikost), Image.NEAREST),
                    (10 + velikost * c, y))
    p.save(vystup)
    print(f"ZOOM {vystup} ({p.width}x{p.height}) bunka {VYREZ}px x {KOLIK}, "
          f"sloupcu {sloupcu}, radku {len(radky)}")
    return 0


def _tyz_fram(sada: Path, ident: int):
    """Stejny frame postavy z `anim/anim-sheets.json` (UO ma jiny format nez my).

    ⚠ UO anim list ma klice `body/action/dir` a framy ve PRUHU (rect), kdezto
    nase sada ma framy v manifestu jako `anim` sprity s id
    `body*1000+action*100+dir*10+frame`. Kdo hleda UO frame v manifestu, nenajde
    ho - a na listu zustane prazdny sloupec (namEReno).
    """
    listy = sada / "anim" / "anim-sheets.json"
    if not listy.exists():
        return None
    d = json.loads(listy.read_text(encoding="utf-8"))
    body, action, smer, frame = ac1.anim_parts(ident)
    klic = f"{body}/{action}/{smer}"
    v = d.get("sprites", {}).get(klic)
    if v is None or frame >= len(v.get("frames", [])):
        return None
    pruh = Image.open(sada / "anim" / v["file"]).convert("RGBA")
    return pruh.crop(tuple(v["frames"][frame]["rect"]))


def _sprite_s_anim(sada: Path, man: dict, kind: str, ident: int):
    """Sprite z manifestu, a kdyz tam neni a jde o anim, z anim listu."""
    s, img = _sprite(sada, man, kind, ident)
    if img is not None:
        return s, img
    if kind == "anim":
        return None, _tyz_fram(sada, ident)
    return None, None


def na_vyrez(poz: Image.Image, spr: Image.Image) -> Image.Image:
    """Sprite na stred dlazdice + vyrez okolo kontaktu (kotvy).

    ⚠ KOTVA SE BERE Z `cy` FRAME (kdyz je k dispozici), NE VZORCEM: UO framy
    maji kazdy jinou vysku (59-64 px) a kontakt neni `h - 22` u vsech. Vzorcem
    by UO postava na listu "stala" o par pixelu jinde nez nase - a to by vypadalo
    jako posun nasi kotvy.
    """
    platno = poz.copy()
    kx, ky = spr.width // 2, spr.height - ac1.GROUND_PX
    cx, cy = platno.width // 2, platno.height // 2
    platno.alpha_composite(spr, (cx - kx, cy - ky))
    levy = max(0, cx - VYREZ // 2)
    horni = max(0, cy - VYREZ // 2)
    return platno.crop((levy, horni, levy + VYREZ, horni + VYREZ))


def main() -> int:
    ap = argparse.ArgumentParser(description="zoom na prvek pres vsechny sady")
    ap.add_argument("--ids", default="3921,7151,6583,3717")
    ap.add_argument("--anim", default="400000,400004",
                    help="id framu postavy (prazdne = zadne)")
    ap.add_argument("--vystup", default="tools/artgen/_srovnani-zoom.png")
    a = ap.parse_args()
    ids = [int(v) for v in a.ids.split(",") if v.strip()]
    anim_ids = [int(v) for v in a.anim.split(",") if v.strip()]
    return hlavni(ids, Path(a.vystup), anim_ids)


if __name__ == "__main__":
    raise SystemExit(main())
