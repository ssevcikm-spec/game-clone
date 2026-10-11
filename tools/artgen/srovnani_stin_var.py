# -*- coding: utf-8 -*-
"""srovnani_stin_var.py - zmeri a vykresli varianty RECEPTU STINU (bez Blenderu).

  python tools/artgen/srovnani_stin_var.py
  python tools/artgen/srovnani_stin_var.py --recepty v2,v3s62,v3s80

PROC: `MERENI.md` §9.3 zmerilo, ze placate predmety maji stin jen jako 1px lem
(dyka 6-7 px, ingot 11 px) - a `probe_stin_raw.py` ukazal, ze RENDER tim neni
vinny (hustota 0,73-0,83 u obou). Vada je v postprocessu (radialni ubytek od
kotvy, ktery u placateho predmetu vyjde temer nulovy). Nez se pregeneruje cela
sada, je potreba projit recepty NAD SUROVYMI RENDERY z `_rawlit/`:

  * nic se nerenderuje znovu (vstup je hotovy render - meri se jen postprocess),
  * kazdy recept projde CELOU cestou jako v `pack_atlas_lit.py` (dva pruchody:
    vzorky palety + kvantizace, tvrda alfa), takze se meri to, co by hra dostala,
  * vystupem je cislo (`viditelny_stin_px`, krytí, kontrast tela) A list na
    POHLED (`_srovnani-stin.png`), protoze "je to citelnejsi" se neda rozhodnout
    z jednoho cisla (`MERENI.md` §5).

⚠ Baseline se overuje: sprite z receptu v2 se musi PIXEL PO PIXELU rovnat
`assets/own-lit/` (jinak by sonda merila neco jineho, nez je v sade).
⚠ Vse se zapisuje do `tools/artgen/_*` (ignorovano) - zadny novy art tady
nevznika, jen se meri.
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import artgen_common as ac1
import artgen_common_lit as acl
import postprocess as pp
import postprocess_lit as ppl
import styl

HERE = Path(__file__).resolve().parent
RAW = HERE / "_rawlit"
LIT = Path("assets/own-lit")
OWN1X = Path("assets/own")
UO = Path("assets/uo")

# Recepty k porovnani: jmeno -> parametry receptu v3 (viz `RECEPTY_STINU`)
#   sila      - nasobek krytí stinu
#   posun_px  - posun masky tela ve smeru svetla (objekt stoji NAD rovinou)
#   jadro_px  - jak daleko za obrysem je stin jeste plny (kontaktni lem)
#   mekkost_px- pres kolik px stin zmizi
#   dosah_px  - za timhle odstupem uz zadny stin
RECEPTY = {
    "v2":        dict(verze="v2"),
    "v3s85":     dict(verze="v3", sila=0.85, posun_px=(2, 0), jadro_px=0.5,
                      mekkost_px=2.5, dosah_px=7.0),
    "v3s85m15":  dict(verze="v3", sila=0.85, posun_px=(2, 0), jadro_px=0.5,
                      mekkost_px=1.5, dosah_px=5.0),
    "v3s85p0":   dict(verze="v3", sila=0.85, posun_px=(0, 0), jadro_px=0.5,
                      mekkost_px=2.5, dosah_px=7.0),
    "v3s85p31":  dict(verze="v3", sila=0.85, posun_px=(3, 1), jadro_px=0.5,
                      mekkost_px=2.5, dosah_px=7.0),
    "v3s70":     dict(verze="v3", sila=0.70, posun_px=(2, 0), jadro_px=0.5,
                      mekkost_px=2.5, dosah_px=7.0),
    "v3s100":    dict(verze="v3", sila=1.00, posun_px=(2, 0), jadro_px=0.5,
                      mekkost_px=2.5, dosah_px=7.0),
    "v3s85j15":  dict(verze="v3", sila=0.85, posun_px=(2, 0), jadro_px=1.5,
                      mekkost_px=2.0, dosah_px=7.0),
}


def _dva_pruchody(pripravene, s, druh, popis):
    sber = styl.SadaPalety()
    ppl.sestav(pripravene, s, druh, popis=popis, sber=sber)
    paleta = sber.postav()
    if paleta is None:
        raise SystemExit(f"{popis}: zadne vzorky barev")
    return ppl.sestav(pripravene, s, druh, popis=popis, paleta=paleta,
                      tvrda_alfa=True)


def _origin(davka: str):
    o = json.loads((RAW / f"_origin_{davka}.json").read_text(encoding="utf-8"))
    return (o["origin_x"], o["origin_y"])


def priprav_items():
    out = []
    for spec in acl.ITEMS:
        j = spec["name"]
        out.append((j, spec["uo_id"], ppl.priprav(
            RAW / f"item_{j}.png", _origin(f"item_{j}"),
            stin=RAW / f"_stin_item_{j}.png", ref=RAW / f"_ref_item_{j}.png"),
            spec["uo_content"]))
    return out


def priprav_anim(dirs=5, frames=8):
    """Cely anim model (5 smeru x 8 framu) - stejna davka jako v `pack_atlas_lit.py`.

    ⚠ PROC VSECH 40 A NE JEN 8: paleta se v sade stavi PO DAVKACH a davka je
    "jeden model" = vsech 40 framu. Kdyby sonda vzala jen 8 framu smeru 0,
    vysla by JINA paleta a baseline by "nesedel" - a to by byla vada MERENI,
    ne pipeline. (Overeno: se 40 framy sedi v2 na `assets/own-lit/` pixel po
    pixelu, s 8 framy se lisi ~630 px na sprite.)
    """
    out = []
    ref = RAW / "_ref_character.png"
    for d in range(dirs):
        for f in range(frames):
            ident = acl.anim_id(d, f)
            out.append((f"char_d{d}_f{f}", ident, ppl.priprav(
                RAW / f"char_d{d}_f{f}.png", _origin("character"),
                stin=RAW / f"_stin_char_d{d}_f{f}.png", ref=ref), None))
    return out


def _uo_sprite(kind: str, ident: int):
    m = json.loads((UO / "manifest.json").read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return Image.open(UO / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def statistiky(img: Image.Image, stin_barva=(0, 0, 0)) -> dict:
    a = np.array(img)
    alfa = a[:, :, 3]
    barva = (a[:, :, :3] == np.array(stin_barva, dtype=np.uint8)).all(axis=2)
    stin = (alfa > 0) & (alfa < 200) & barva
    telo = alfa >= 200
    jas = a[:, :, :3].mean(axis=2)[telo]
    sa = alfa[stin]
    return {
        "box": [img.width, img.height],
        "stin_px": int(stin.sum()),
        "stin_max": int(sa.max()) if sa.size else 0,
        "stin_prumer": round(float(sa.mean()), 1) if sa.size else 0.0,
        "stin_px_30_90": int(((sa >= 30) & (sa <= 90)).sum()) if sa.size else 0,
        "stin_px_nad60": int((sa >= 60).sum()) if sa.size else 0,
        "telo_px": int(telo.sum()),
        "telo_jas": round(float(jas.mean()), 2) if jas.size else 0.0,
        "telo_sd": round(float(jas.std()), 2) if jas.size else 0.0,
        "telo_rozptyl": round(float(np.quantile(jas, 0.95) - np.quantile(jas, 0.05)), 2)
        if jas.size else 0.0,
        "barvy_tela": int(len(np.unique(a[:, :, :3][telo].reshape(-1, 3), axis=0)))
        if telo.any() else 0,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="varianty receptu kontaktniho stinu")
    ap.add_argument("--recepty", default="v2,v3s85,v3s85m15,v3s85p0,v3s85p31,v3s70,v3s100,v3s85j15")
    ap.add_argument("--json", default="tools/artgen/_stin-var.json")
    ap.add_argument("--list", default="tools/artgen/_srovnani-stin.png")
    ap.add_argument("--zapis-teren", action="store_true",
                    help="zapsat sprity POLOZENE na dlazdici do `_v3/` (pro list)")
    a = ap.parse_args()
    jmena = [v.strip() for v in a.recepty.split(",") if v.strip()]
    for j in jmena:
        if j not in RECEPTY:
            raise SystemExit(f"neznamy recept {j!r} (je {sorted(RECEPTY)})")

    items = priprav_items()
    anim = priprav_anim()
    if "v2" not in jmena:
        jmena = ["v2"] + jmena      # baseline se vzdy meri (overuje se proti sade)

    vysledky: dict[str, dict] = {}
    sprity_podle: dict[str, dict] = {}
    for jmeno in jmena:
        # recept se zaregistruje pod svym jmenem a nastavi jako aktivni - nic se
        # neprepisuje globalne (po mereni se `v2` vrati zpet)
        ppl.RECEPTY_STINU[jmeno] = dict(RECEPTY[jmeno])
        ppl.nastav_recept_stinu(jmeno)
        m = {}
        for nazev, radek in (("item", items), ("anim", anim)):
            if nazev == "item":
                pripravene = [p for _j, _i, p, _c in radek]
                vysky = [c[1] for _j, _i, _p, c in radek]
                spr = []
                for (_j, _i, p, _c), vyska in zip(radek, vysky):
                    s = ppl.meritko([p], obsah_vyska_px=vyska)
                    o, meta = _dva_pruchody([p], s, "item", _j)
                    spr.append((_j, _i, o[0], meta[0]))
            else:
                pripravene = [p for _j, _i, p, _c in radek]
                s = ppl.meritko(pripravene, obsah_vyska_px=acl.CHAR["cil_obsah_px"])
                o, meta = _dva_pruchody(pripravene, s, "anim", "character")
                spr = [(radek[k][0], radek[k][1], o[k], meta[k])
                       for k in range(len(radek))]
            for jm, ident, img, meta in spr:
                m.setdefault(nazev, {})[str(ident)] = statistiky(img)
            sprity_podle.setdefault(jmeno, {})[nazev] = spr
        vysledky[jmeno] = m
        vse = [v for k in m for v in m[k].values()]
        print(f"--- {jmeno}: spritu {len(vse)}, stin_px "
              f"{min(v['stin_px'] for v in vse)}/{max(v['stin_px'] for v in vse)}, "
              f"max krytí {max(v['stin_max'] for v in vse)}, "
              f"px 30-90 {min(v['stin_px_30_90'] for v in vse)}/"
              f"{max(v['stin_px_30_90'] for v in vse)}, "
              f"telo sd {min(v['telo_sd'] for v in vse):.1f}/"
              f"{max(v['telo_sd'] for v in vse):.1f}")

    # --- overeni baseline proti hotove sade ---------------------------------
    print("\n--- baseline (v2) proti assets/own-lit/ ---")
    shoda = {"item": [], "anim": []}
    man = json.loads((LIT / "manifest.json").read_text(encoding="utf-8"))
    podle = {(s["kind"], s["id"]): s for s in man["sprites"]}
    for nazev in ("item", "anim"):
        for _jm, ident, img, _m in sprity_podle["v2"][nazev]:
            s = podle.get((nazev, ident))
            if s is None:
                shoda[nazev].append((ident, "v sade neni"))
                continue
            ref = Image.open(LIT / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
            d = np.abs(np.asarray(img, dtype=np.int16) - np.asarray(ref, dtype=np.int16))
            shoda[nazev].append((ident, int(d.max()), int((d.max(axis=2) > 0).sum())))
        mx = max(x[1] for x in shoda[nazev] if isinstance(x[1], int))
        px = sum(x[2] for x in shoda[nazev] if isinstance(x[1], int))
        print(f"{nazev}: max|rozdil| = {mx}, pixelu s rozdilem = {px} "
              f"({len(shoda[nazev])} spritu)")
        if mx:
            for ident, d, n in shoda[nazev]:
                if isinstance(d, int) and d:
                    print(f"   {nazev} {ident}: max|rozdil|={d}, px={n}")

    # --- list na POHLED -----------------------------------------------------
    ppl.nastav_recept_stinu("v2")
    if a.zapis_teren:
        _zapis_teren(sprity_podle, jmena)
    _list(sprity_podle, jmena, Path(a.list))
    Path(a.json).write_text(json.dumps(
        {"vysledky": vysledky,
         "baseline_shoda": {k: [[x[0], x[1], x[2] if len(x) > 2 else None]
                                for x in val] for k, val in shoda.items()}},
        ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"ZAPIS {a.json} a {a.list}")
    return 0


def _zapis_teren(sprity_podle, jmena) -> None:
    """Zapise sprity POLOZENE na dlazdici (aby se stin dal posoudit POHLEDEM).

    ⚠ PROC NA DLAZDICI: stin je polopruhledny a na tmavem podkladu srovnavaciho
    listu se ztrati. Ve hre lezi na dlazdici, takze jen tam je videt, jestli
    "predmet stoji" - a to je cely ucel teto zmeny (`MERENI.md` §5).
    """
    out = HERE / "_v3"
    out.mkdir(parents=True, exist_ok=True)
    man = json.loads((UO / "manifest.json").read_text(encoding="utf-8"))
    dlazdice = None
    for s in man["sprites"]:
        if s["kind"] == "land" and s["id"] == 3:
            dlazdice = Image.open(UO / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    if dlazdice is None:
        raise SystemExit("v UO manifestu neni land 3 (trava) - neni na co polozit")
    pozadi = Image.new("RGBA", (dlazdice.width + 44, dlazdice.height + 44), (0, 0, 0, 0))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            pozadi.alpha_composite(dlazdice, (22 + 22 * dx, 22 + 22 * dy))
    kolik = 0
    for j in jmena:
        for nazev in ("item", "anim"):
            for _jm, ident, img, _m in sprity_podle[j][nazev]:
                if nazev == "anim" and ident % 10 not in (0, 4):
                    continue
                platno = pozadi.copy()
                kx, ky = img.width // 2, img.height - acl.GROUND_PX
                platno.alpha_composite(img, (platno.width // 2 - kx,
                                             platno.height // 2 - ky))
                platno.save(out / f"{j}--{nazev}-{ident}--trava.png")
                kolik += 1
    print(f"TEREN zapsano {kolik} spritu do {out}")


def _list(sprity_podle, jmena, cesta: Path, kolik: int = 6) -> None:
    """Srovnavaci list: rada = recept, sloupec = prvek (dyka, krumpac, ruda,
    ingot, 3 framy postavy). Vsechno ve STEJNEM meritku (kolik x)."""
    prvky = [("item", "3921"), ("item", "3717"), ("item", "6583"), ("item", "7151"),
             ("anim", str(acl.anim_id(0, 0))), ("anim", str(acl.anim_id(0, 4))),
             ("anim", str(acl.anim_id(0, 7)))]
    radky = list(sprity_podle)
    bunky = {}
    for j in radky:
        for nazev, ident in prvky:
            for _jm, i, img, _m in sprity_podle[j][nazev]:
                if str(i) == ident:
                    bunky[(j, ident)] = img
    sirka_bunky = max(img.width for img in bunky.values()) * kolik + 6
    vyska_bunky = max(img.height for img in bunky.values()) * kolik + 18
    W = sirka_bunky * (len(prvky) + 1) + 10
    H = vyska_bunky * (len(radky) + 1) + 10
    p = Image.new("RGB", (W, H), (30, 32, 38))
    d = ImageDraw.Draw(p)
    # hlavicka: cisla prvku
    for sl, (nazev, ident) in enumerate(prvky):
        d.text((10 + sirka_bunky * (sl + 1) + 4, 4), f"{nazev} {ident}",
               fill=(230, 230, 230))
    d.text((8, 4), "recept", fill=(230, 230, 230))
    for r, j in enumerate(radky):
        y = 20 + vyska_bunky * r
        d.text((8, y + 4), j, fill=(230, 230, 230))
        for sl, (_nazev, ident) in enumerate(prvky):
            x = 10 + sirka_bunky * (sl + 1)
            d.rectangle([x - 2, y - 2, x + sirka_bunky - 4, y + vyska_bunky - 4],
                        outline=(70, 72, 80))
            img = bunky.get((j, ident))
            if img is None:
                d.text((x + 4, y + 4), "CHYBI", fill=(255, 120, 120))
                continue
            p.paste(img.resize((img.width * kolik, img.height * kolik), Image.NEAREST),
                    (x + 2, y + 2), img.resize((img.width * kolik, img.height * kolik),
                                               Image.NEAREST))
    p.save(cesta)
    print(f"LIST {cesta} ({W}x{H})")


if __name__ == "__main__":
    raise SystemExit(main())
