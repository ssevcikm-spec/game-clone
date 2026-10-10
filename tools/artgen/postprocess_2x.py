# -*- coding: utf-8 -*-
"""postprocess_2x.py - z 2x renderu udela sprite v 2x kontraktu (a prida kontaktni stin).

Je to OBDOBA `postprocess.py` pro dvojnasobnou geometrii. Krok za krokem dela
totéž (alfa-bleed -> korekce projekce -> pozadi -> diry -> Lanczos -> kotva),
jen s 2x cisly (dlazdice 88, kontakt 44, render 1024) - a navic to, co 1x
ZAMERNE NEMA (ZADANI-25 §9 odst. 3):

  KONTAKTNI STIN. Neni dokreslovany: `render_2x.py` vyrenderuje kontaktni
  rovinu (pudorys dlazdice) dvakrat - s objektem a bez objektu - a tady se
  z pomeru jasu pocita FAKTOR ZASTINENI. Rovina je seda a osvetlena jedinym
  sluncem, takze:
      faktor = jas(stin) / jas(ref)      (1 = osvetleno, 0 = plny stin)
      alfa_stinu = (1 - faktor) * radialni_ubytek * STIN_SILA
  Radialni ubytek dela z vrhu KONTAKTNI stin (louze pod objektem) - bez nej by
  stin od 1,2 jednotky vysoke postavy utekl pres celou dlazdici.

  Proc se pocita z renderu a ne z pruhlednosti: Blender 5.2 na teto stanici ma
  v enumu engine JEN `BLENDER_EEVEE` (Cycles neni), takze shadow catcher
  (`object.is_shadow_catcher`) je nedostupny. Mereno sondou
  `probe_blender_capabilities.py`, ne odhadnuto.

⚠ STEJNA PAST JAKO V 1x: `PIL.Image.resize` na RGBA rozsype RGB tam, kde je
alfa ~0 (cerna linka). Vsechno zmensovani jde pres `postprocess.zmensi`
(RGB a alfa zvlast) - tady se to tyka i masek stinu.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import artgen_common_2x as ac2
import postprocess as pp

# Stejne prahy jako 1x (duvod je popsany v `postprocess.py`): obal z Lanczosu
# daleko od siluety se zahodi maskou rozsirenou o 2 px, zbytek dorazi prah.
ALFA_PRAH = pp.ALFA_PRAH


# ---------------------------------------------------------------------------
# korekce projekce (stejna funkce jako 1x, jen 2x meritko)
# ---------------------------------------------------------------------------
def na_uo_obrazek(img: Image.Image) -> Image.Image:
    """Zrcadleni vodorovne + svisle roztazeni 1,7321 (2x cisla z `artgen_common_2x`)."""
    if ac2.MIRROR_X:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return pp.zmensi(img, (img.width, ac2.na_uo_velikost(img.height)))


def priprav(cesta: Path, origin: tuple[float, float],
            stin: Path = None, ref: Path = None) -> dict:
    """Nacte render (a pripadne masky stinu), udela bleed + korekci projekce."""
    img = Image.open(cesta).convert("RGBA")
    img = pp.vypln_rgb(img, kolik=3)
    img = na_uo_obrazek(img)
    img, cesta_pozadi, pocet_barva = pp.odstran_pozadi(img)
    maska = pp.maska_obsahu(img)
    if not maska.any():
        raise RuntimeError(f"{cesta}: po odstraneni pozadi nezustal zadny obsah")
    oy, ox = np.nonzero(maska)
    bbox = (int(ox.min()), int(oy.min()), int(ox.max()), int(oy.max()))
    bod = ac2.na_uo_bod(origin[0], origin[1])
    out = {"img": img, "maska": maska, "bbox": bbox, "origin": bod,
           "cesta": str(cesta), "pozadi": cesta_pozadi, "pocet_barva": pocet_barva}
    if stin is not None and ref is not None:
        # Stejne transformace jako u kreativniho pruchodu - jinak by stin
        # nesedel na objekt (a poznalo by se to az na listu).
        out["stin"] = na_uo_obrazek(pp.vypln_rgb(Image.open(stin).convert("RGBA"), 3))
        out["ref"] = na_uo_obrazek(pp.vypln_rgb(Image.open(ref).convert("RGBA"), 3))
    return out


def meritko(pripravene: list[dict], obsah_vyska_px: float = None,
            obsah_sirka_px: float = None) -> float:
    """Jedno meritko pro celou davku - STEJNA funkce jako 1x (nic geometrickeho v ni neni)."""
    return pp.meritko(pripravene, obsah_vyska_px=obsah_vyska_px,
                      obsah_sirka_px=obsah_sirka_px)


# ---------------------------------------------------------------------------
# kontaktni stin
# ---------------------------------------------------------------------------
def px_na_jednotku(ref: Image.Image) -> float:
    """Kolik px je v TOMHLE spritu 1 svetova jednotka - MERENO z kontaktni roviny.

    ⚠ NAMERENO 2026-10-10 a je to past, ktera stoji za zapsani: sprite se
    normalizuje na NAMERENY obsah UO (`meritko`), ne na pevne meritko - takze
    "1 jednotka = TILE px" v hotovem spritu NECPLATI. Zmereno: 1 jednotka vysla
    68,4 px u dyky a 82,7 px u postavy (pro 2x by "správně" bylo 88). Kdyby se
    polomer stinu pocital z konstanty `TILE`, byl by stin u kazdeho druhu jinak
    velky VUCI OBJEKTU (u postavy o 21 % mensi nez u dyky) - proto se bere
    z MERENE roviny. Rovina je 1x1 jednotka (`probe_rovina.py`), takze jeji
    uhlopricka = sqrt(2) jednotky.
    """
    alfa = np.asarray(ref)[:, :, 3] > 127
    ys, xs = np.nonzero(alfa)
    if not len(xs):
        raise RuntimeError("v referencnim renderu neni videt kontaktni rovina - "
                           "polomer stinu by se nemel z ceho spocitat")
    return float(xs.max() - xs.min() + 1) / math.sqrt(2.0)


def vrstva_stinu(p: dict, s: float, nw: int, nh: int, w: int, h: int,
                 vloz_x: int, vloz_y: int, px_jednotka: float) -> tuple[Image.Image, dict]:
    """Vrstva kontaktniho stinu ve velikosti vlozeneho spritu.

    Vraci (obrazek, statistika). Statistika je tu proto, aby se "stin existuje"
    dalo OVERIT v `pack_atlas_2x.py --check` - jinak by tvrzeni "2x ma stin"
    nebylo ničím kryte (skill `overovani`: brana se musi ptat na chovani).
    """
    if "stin" not in p:
        raise RuntimeError(f"{p['cesta']}: chybi render stinu (plan bez roviny?)")
    sh = pp.zmensi(p["stin"], (nw, nh))
    rf = pp.zmensi(p["ref"], (nw, nh))
    a_sh = np.asarray(sh, dtype=np.float32)
    a_rf = np.asarray(rf, dtype=np.float32)
    jas_stin = a_sh[:, :, :3].mean(axis=2)
    jas_ref = a_rf[:, :, :3].mean(axis=2)
    faktor = np.clip(jas_stin / np.maximum(jas_ref, 1e-3), 0.0, 1.0)
    rovina = a_rf[:, :, 3] > 127                     # jen tam, kde je videt rovina

    # radialni ubytek kolem KONTAKTNIHO BODU (kotva spritu) v jednotkach dlazdice
    ax = (w // 2) - vloz_x
    ay = (h - ac2.GROUND_PX) - vloz_y
    yy, xx = np.mgrid[0:nh, 0:nw]
    r = np.hypot(xx - ax, yy - ay) / px_jednotka
    u = np.clip((ac2.STIN_R1_JEDNOTEK - r) /
                (ac2.STIN_R1_JEDNOTEK - ac2.STIN_R0_JEDNOTEK), 0.0, 1.0)
    ubytek = u * u * (3.0 - 2.0 * u)                 # smoothstep

    alfa = (1.0 - faktor) * ubytek * ac2.STIN_SILA * 255.0 * rovina
    alfa = np.where(alfa >= ac2.STIN_PRAH, alfa, 0.0).astype(np.uint8)
    rgb = np.zeros((nh, nw, 3), dtype=np.uint8)
    rgb[:, :] = ac2.STIN_BARVA
    out = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")
    # MERENI MERITKA: kontaktni rovina je presne 1x1 jednotka (`primitive_grid_add`
    # size=1.0 -> -0,5..0,5, overeno sondou `probe_rovina.py`), takze JEJÍ Sirka
    # v hotovem spritu je primo "kolik px je 1 jednotka". Kdyby se 2x sprite
    # skaloval jinak nez 2x, pozná se to tady - a ne az tim, ze stin nesedi.
    ys, xs = np.nonzero(rovina)
    sirka = int(xs.max() - xs.min() + 1) if len(xs) else 0
    vyska = int(ys.max() - ys.min() + 1) if len(ys) else 0
    stat = {"px": int((alfa > 0).sum()), "max_alfa": int(alfa.max()) if alfa.size else 0,
            "faktor_min": float(faktor[rovina].min()) if rovina.any() else 1.0,
            "rovina_px": int(rovina.sum()), "rovina_sirka_px": sirka,
            "rovina_vyska_px": vyska, "px_na_jednotku": round(px_jednotka, 2)}
    return out, stat


# ---------------------------------------------------------------------------
# zmenseni a sestaveni s kotvou
# ---------------------------------------------------------------------------
def sestav(pripravene: list[dict], s: float, druh: str,
           popis: str = "") -> tuple[list[Image.Image], list[dict]]:
    """Zmensi a vlozi sprity tak, aby kontakt sedel na (w//2, h-44).

    Stejna logika jako 1x `postprocess.sestav`; navic se platno zvetsi tak, aby
    se do nej vesel kontaktni stin (jinak by se stin na okraji ufikl).
    """
    if druh not in ("item", "anim"):
        raise ValueError(f"2x vetev vyrabi jen item/anim, ne {druh!r} "
                         "(dlazdice se ve 2x nedelaji - ZADANI-25 §9)")
    bod = pripravene[0]["origin"]
    if any(abs(p["origin"][0] - bod[0]) > 0.51 or abs(p["origin"][1] - bod[1]) > 0.51
           for p in pripravene):
        raise RuntimeError("kontaktni bod se v davce lisi (kamera se hybala?) - "
                           "kotva by po framech ujizdela")
    ox, oy = bod
    levy = min(p["bbox"][0] for p in pripravene)
    horni = min(p["bbox"][1] for p in pripravene)
    pravy = max(p["bbox"][2] for p in pripravene)
    dolni = max(p["bbox"][3] for p in pripravene)
    f = lambda v: (v + 0.5) * s - 0.5
    Ox, Oy = f(ox), f(oy)
    l, t, r, b = f(levy), f(horni), f(pravy), f(dolni)
    w = 2 * (math.ceil(max(Ox - l, r - Ox)) + 1)
    h = int(round(Oy - t)) + ac2.GROUND_PX
    # Polomer stinu se pocita z MERENEHO meritka spritu (viz `px_na_jednotku`),
    # ne z konstanty TILE - jinak by byl u kazdeho druhu jinak velky vuci objektu.
    px_jednotka = None
    if "ref" in pripravene[0]:
        px_jednotka = px_na_jednotku(pripravene[0]["ref"]) * s
        for p in pripravene:
            if "ref" not in p:
                raise RuntimeError(f"{p['cesta']}: chybi referencni render roviny, "
                                   "ale jina davka ho ma - stin by nesel premerit")
            if abs(px_na_jednotku(p["ref"]) * s - px_jednotka) > 1.0:
                raise RuntimeError("meritko roviny se v davce lisi (kamera se hybala?) "
                                   "- stin by po framech menil velikost")
        # ... a dost mista na kontaktni stin (kotva je od okraje dal nez R1)
        r1_px = int(math.ceil(ac2.STIN_R1_JEDNOTEK * px_jednotka)) + 1
        w = max(w, 2 * r1_px)
        h = max(h, ac2.GROUND_PX + r1_px)
    w += w % 2                                   # sudy box = kotva na stredu pixelu
    pod = b - Oy
    if pod > ac2.GROUND_PX:
        raise RuntimeError(
            f"{popis}: obsah zasahuje {pod:.1f} px pod kontaktni bod, ale sprite "
            f"muze mit pod nim jen {ac2.GROUND_PX} px - model je potreba posunout "
            "nad pocatek (kontakt = stred pudorysu)")
    vloz_x = int(round(w // 2 - Ox))
    vloz_y = int(round(h - ac2.GROUND_PX - Oy))
    sprity, meta = [], []
    for p in pripravene:
        nw = max(1, int(round(p["img"].width * s)))
        nh = max(1, int(round(p["img"].height * s)))
        maly = pp.zmensi(p["img"], (nw, nh))
        sirsi = ndimage.binary_dilation(p["maska"], iterations=2)
        maska = Image.fromarray((sirsi * 255).astype(np.uint8)).resize((nw, nh), Image.NEAREST)
        gate = np.array(maska) > 127
        alfa = np.array(maly.split()[3])
        alfa = np.where(gate & (alfa >= ALFA_PRAH), alfa, 0).astype(np.uint8)
        rgb = np.array(maly)[:, :, :3]
        telo = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")
        platno = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        stat = {"px": 0, "max_alfa": 0, "faktor_min": 1.0, "rovina_px": 0,
                "rovina_sirka_px": 0, "rovina_vyska_px": 0, "px_na_jednotku": 0.0}
        if "stin" in p:
            stin_img, stat = vrstva_stinu(p, s, nw, nh, w, h, vloz_x, vloz_y,
                                          px_jednotka)
            platno.alpha_composite(stin_img, (vloz_x, vloz_y))
        platno.alpha_composite(telo, (vloz_x, vloz_y))
        sprity.append(platno)
        meta.append({"w": w, "h": h, "obsah_pod_kontaktem_px": round(pod, 2),
                     "obsah_vyska_px": int(round(b - t + 1)),
                     "obsah_sirka_px": int(round(r - l + 1)),
                     "pozadi": p["pozadi"], "barva_pozadi_px": p["pocet_barva"],
                     "meritko": s, "stin_px": stat["px"],
                     "stin_max_alfa": stat["max_alfa"],
                     "stin_faktor_min": round(stat["faktor_min"], 4),
                     "stin_rovina_px": stat["rovina_px"],
                     "rovina_sirka_px": stat["rovina_sirka_px"],
                     "rovina_vyska_px": stat["rovina_vyska_px"],
                     "px_na_jednotku": stat["px_na_jednotku"]})
    return sprity, meta


def uloz_nahled(sprity: list[Image.Image], cesta: Path, kolik: int = 4) -> None:
    """Zvetseny nahled sprite(ů) na kontrolu pohledem."""
    if not sprity:
        return
    w = sum(s.width for s in sprity) * kolik + 4 * (len(sprity) + 1)
    h = max(s.height for s in sprity) * kolik + 8
    p = Image.new("RGBA", (w, h), (40, 44, 52, 255))
    x = 4
    for s in sprity:
        p.alpha_composite(s.resize((s.width * kolik, s.height * kolik), Image.NEAREST), (x, 4))
        x += s.width * kolik + 4
    p.convert("RGB").save(cesta)


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="postprocess 2x (ladici rezim, 1 snimek)")
    ap.add_argument("--render", required=True)
    ap.add_argument("--origin", required=True)
    ap.add_argument("--stin", default="")
    ap.add_argument("--ref", default="")
    ap.add_argument("--obsah-vyska", type=float, required=True)
    ap.add_argument("--out", default="tools/artgen/_postprocess-2x.png")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    o = json.loads(Path(a.origin).read_text(encoding="utf-8"))
    p = priprav(Path(a.render), (o["origin_x"], o["origin_y"]),
                stin=Path(a.stin) if a.stin else None,
                ref=Path(a.ref) if a.ref else None)
    s = meritko([p], obsah_vyska_px=a.obsah_vyska)
    sprity, meta = sestav([p], s, "item", popis=str(a.render))
    uloz_nahled(sprity, Path(a.out))
    print(f"[postprocess_2x] {a.render} -> {a.out} sprite {sprity[0].size} "
          f"kotva=({sprity[0].width // 2},{sprity[0].height - ac2.GROUND_PX})")
    if a.json:
        print(json.dumps(meta[0], ensure_ascii=False, sort_keys=True))
