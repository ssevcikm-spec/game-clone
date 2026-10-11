# -*- coding: utf-8 -*-
"""nahled_na_terenu.py - polozi sprity na SKUTECNOU dlazdici a vykresli list.

  python tools/artgen/nahled_na_terenu.py --recepty v2,v3s85

PROC: `MERENI.md` §5 rika, ze kontaktni stin se neda rozhodnout z cisla - a
plati to dvojnasob: stin je polopruhledny a na tmavem podkladu srovnavaciho
listu (`_srovnani-stin.png`) se ZTRACI. Ve hre ale lezi na dlazdici, takze
jedina poctiva kontrola je polozit sprite na SKUTECNOU dlazdici a podivat se.

List ma:
  * radu pro UO (reference - jak to dela vzor),
  * radu pro kazdy recept (nas stary a nas novy),
  * sloupce: dyka, krumpac, ruda, ingot, postava (2 framy) - VZDY na trave,
  * druhou cast: tyz recept na ceste (aby se nevybiralo podle jedne dlazdice).

Dlazdice se sklada PRESNE jako ve hre: 44x44 kosoctverec na krok 22 px
(`core/const.gd`), sprite se kresli na `tile - (ox, oy)`.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import artgen_common as ac1
import artgen_common_lit as acl

HERE = Path(__file__).resolve().parent
LIT = Path("assets/own-lit")
OWN1X = Path("assets/own")
UO = Path("assets/uo")
KOLIK = 5          # zvetseni na listu


def _manifest(sada: Path):
    return json.loads((sada / "manifest.json").read_text(encoding="utf-8"))


def sprite(sada: Path, man: dict, kind: str, ident: int):
    for s in man["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def dlazdice(sada: Path, man: dict, ident: int, sirka: int = 44):
    """Dlazdice jako pozadi: 3x3 dlaždice, aby stin mel na cem lezet."""
    t = sprite(sada, man, "land", ident)
    if t is None:
        return None
    if t.width != sirka:
        t = t.resize((sirka, sirka), Image.NEAREST)
    # pozadi 3x3 dlazdic (kosoctverec se prekryva o krok 22)
    w = sirka + 2 * 22
    h = sirka + 2 * 22
    out = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    stred = ((w - sirka) // 2, (h - sirka) // 2)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out.alpha_composite(t, (stred[0] + 22 * dx, stred[1] + 22 * dy))
    return out


def poloz(pozadi: Image.Image, spr: Image.Image, kotva_sirka: int = 44,
          stred: bool = True) -> Image.Image:
    """Sprite na stred dlazdice: kresli se na (tile - ox, tile - oy) jako ve hre."""
    out = pozadi.copy()
    cx = out.width // 2
    cy = out.height // 2
    # kontakt = (w//2, h-22) u item/anim; stred dlazdice je (22,22) od jejiho leveho horniho rohu
    kontakt_x, kontakt_y = spr.width // 2, spr.height - acl.GROUND_PX
    tile_x = cx - kotva_sirka // 2 + 22
    tile_y = cy - kotva_sirka // 2 + 22
    out.alpha_composite(spr, (tile_x - kontakt_x, tile_y - kontakt_y))
    return out


def skladacka(bunky: dict, hlavicky: list[str], soubor: Path, kolik: int = KOLIK) -> None:
    """List "rada x sloupec" z hotovych obrazku (spolecna pro oba tvary vstupu)."""
    klice = [k for k in bunky if k[0] == hlavicky[0]]
    sirka = max(v.width for v in bunky.values()) * kolik + 8
    vyska = max(v.height for v in bunky.values()) * kolik + 20
    sloupcu = len(klice)
    p = Image.new("RGB", (sirka * sloupcu + 10, vyska * len(hlavicky) + 24),
                  (22, 24, 28))
    d = ImageDraw.Draw(p)
    for r, jmeno in enumerate(hlavicky):
        y = 20 + vyska * r
        d.text((8, y + 4), jmeno, fill=(235, 235, 235))
        for c, k in enumerate(klice):
            img = bunky.get((jmeno,) + k[1:])
            if img is None:
                continue
            x = 10 + sirka * c
            p.paste(img.resize((img.width * kolik, img.height * kolik), Image.NEAREST),
                    (x + 4, y + 2))
    for c, k in enumerate(klice):
        d.text((14 + sirka * c, 4), str(k[1]), fill=(235, 235, 235))
    p.save(soubor)
    print(f"NAHLED {soubor} ({p.width}x{p.height}), radku {len(hlavicky)}, "
          f"sloupcu {sloupcu}")


def nacti_sadu(jmena_receptu, prvky, popis_dlazdice="trava"):
    """VARIANTY: sprity z `_v3/` se jmenem receptu (napr. `v3s85-trava.png`).

    Kdyz slozka neexistuje, vrati prazdno - sonda to rekne a nesmi to tise
    preskocit (chybejici mereni neni namerena nula).
    """
    slozka = Path("tools/artgen/_v3")
    if not slozka.exists():
        return {}
    out = {}
    for j in jmena_receptu:
        for kind, ident in prvky:
            p = slozka / f"{j}--{kind}-{ident}--{popis_dlazdice}.png"
            if p.exists():
                out[(j, kind, ident)] = Image.open(p).convert("RGBA")
    return out


def list_variant(jmena_receptu, soubor: Path, prvky=None) -> None:
    """List pres recepty: kazda bunka je sprite uz POLOZENY na dlazdici."""
    prvky = prvky or [("item", 3921), ("item", 3717), ("item", 6583),
                      ("item", 7151), ("anim", acl.anim_id(0, 0))]
    bunky = nacti_sadu(jmena_receptu, prvky)
    if not bunky:
        print("NEMERENO: ve `tools/artgen/_v3/` nejsou sprity receptu - "
              "spust `srovnani_stin_var.py --zapis-v3`")
        return
    hlavicky = list(jmena_receptu)
    bunky2 = {(h, k, i): v for (h, k, i), v in bunky.items()}
    skladacka(bunky2, hlavicky, soubor)


def main() -> int:
    ap = argparse.ArgumentParser(description="sprity na skutecne dlazdici")
    ap.add_argument("--vystup", default="tools/artgen/_nahled-teren.png")
    ap.add_argument("--varianty", default="",
                    help="carkou oddelena jmena receptu z `_v3/` (list na porovnani)")
    ap.add_argument("--vystup-varianty", default="tools/artgen/_srovnani-stin-teren.png")
    a = ap.parse_args()
    if a.varianty:
        list_variant([v.strip() for v in a.varianty.split(",") if v.strip()],
                     Path(a.vystup_varianty))
        return 0
    man_lit = _manifest(LIT)
    man_own = _manifest(OWN1X)
    man_uo = _manifest(UO)
    prvky = [("item", 3921), ("item", 3717), ("item", 6583), ("item", 7151),
             ("anim", acl.anim_id(0, 0)), ("anim", acl.anim_id(0, 4))]
    radky = [("UO", UO, man_uo), ("nas 1x bez svetla", OWN1X, man_own),
             ("nas lit (stary stin)", LIT, man_lit)]
    # nova sada: sprite se bere z `_v3/` (vyrobi ji `pack_atlas_v3.py`)
    v3 = Path("assets/own-v3")
    if (v3 / "manifest.json").exists():
        radky.append(("nas v3 (novy stin)", v3, _manifest(v3)))
    vysky = []
    bunky = {}
    for jmeno, sada, man in radky:
        for kind, ident in prvky:
            for dlazdice_id, popis in ((3, "trava"), (1001, "cesta")):
                poz = dlazdice(sada, man, dlazdice_id)
                spr = sprite(sada, man, kind, ident)
                if poz is None or spr is None:
                    continue
                img = poloz(poz, spr)
                bunky[(jmeno, kind, ident, popis)] = img
    if not bunky:
        print("NEMERENO: zadny sprite se nenasel (chybi sada?)")
        return 1
    klic = list(bunky)
    sirka = max(v.width for v in bunky.values()) * KOLIK + 8
    vyska = max(v.height for v in bunky.values()) * KOLIK + 20
    sloupcu = len(prvky)
    W = sirka * sloupcu + 10
    H = vyska * len(radky) + 24
    p = Image.new("RGB", (W, H), (22, 24, 28))
    d = ImageDraw.Draw(p)
    for r, (jmeno, _s, _m) in enumerate(radky):
        y = 20 + vyska * r
        d.text((8, y + 4), jmeno, fill=(235, 235, 235))
        for c, (kind, ident) in enumerate(prvky):
            x = 10 + sirka * c
            img = bunky.get((jmeno, kind, ident, "trava"))
            if img is None:
                continue
            p.paste(img.resize((img.width * KOLIK, img.height * KOLIK), Image.NEAREST),
                    (x + 4, y + 2))
    for c, (kind, ident) in enumerate(prvky):
        d.text((14 + sirka * c, 4), f"{kind} {ident} (trava)", fill=(235, 235, 235))
    p.save(a.vystup)
    print(f"NAHLED {a.vystup} ({p.width}x{p.height}), radku {len(radky)}, "
          f"sloupcu {sloupcu}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
