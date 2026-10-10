# -*- coding: utf-8 -*-
"""postprocess.py - z renderu (RGBA) udela sprite v kontraktu atlasu.

KROKY (v tomto poradi - a kazdy ma duvod):
  1. ALFA-BLEED: barva se "rozlije" do pruhledneho okoli (3 px). Bez toho by
     kazde dalsi zmenseni michalo barvu objektu s cernou pruhlednych pixelu
     a na siluete by vznikl tmavy lem (klasicka vada Lanczosu na RGBA).
  2. KOREKCE NA UO PROJEKCI: zrcadleni vodorovne + svisle roztazeni 1.7321
     (viz `artgen_common`: UO neni pohled kamery, je to rotovany pudorys
     s vlastnim meritkem vysky). Pocita se JEDNOU funkci pro obrazek i pro
     kontaktni bod, aby kotva neujela.
  3. POZADI PRYC: prednostne podle barvy pozadi, kdyz neni po ruce alfa
     (`odstran_pozadi`). Render chodi s alfou (`film_transparent`), takze se
     pouzije alfa - a barva pozadi se pouzije jako KONTROLA, ze v siluete
     nezustala (pocet pixelu barvy pozadi v obsahu se hlasi, ne zamici).
  4. `binary_fill_holes`: diry v siluete (svetlo skrz, tenke spoje) se zaplni.
  5. ZMENSENI LANCZOS na cilovou velikost - cil je NAMERENA velikost UO artu
     (`artgen_common.ITEMS`), takze kontaktni list porovnava stejne velke veci.
  6. SESTAVENI S KOTVOU: kontaktni bod (0,0,0) modelu musi lezet na (w//2, h-22)
     sprite. To je presne to, co dela vzorec UO `ox = (w>>1)-22, oy = h-44`
     (sprite se kresli na dlazdici, jejichz stred je 22 px nad spodni hranou
     kosoctverce). Kdyz obsah pod kontakt zasahuje vic nez 22 px, je to CHYBA
     a hlasi se - ne tise orezava.

Pouceni prevzate z VZORU (`uo-shadows/tools/blender/postprocess.py`): pozadi
podle barvy (ne jasu), diry zaplnit, zmensovat Lanczos. Cisla (44 px dlazdice,
22 px krok, kotva) jsou z `assets/uo/manifest.json` a `core/const.gd`.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import artgen_common as ac

PRUHLEDNE = 0
# Prah alfy pro "tohle je jeste sprite". Lanczos pri zmenseni 512 -> ~15 px
# rozkmitá hranu a kolem siluety nechá slabý obal (desítky/255) - ten by se
# pocital do bounding boxu a sprite by "tloustl" o 1-2 px na kazdou stranu.
# MERENO 2026-10-10: bez prahu vysel obsah dyky 14x13 px, s prahem 24 je 12x12
# (a UO ma 11x11).
ALFA_PRAH = 24


# ---------------------------------------------------------------------------
# 1) alfa-bleed
# ---------------------------------------------------------------------------
def vypln_rgb(img: Image.Image, kolik: int = 3) -> Image.Image:
    """Rozlije barvu do pruhlednych pixelu (do vzdalenosti `kolik` px).

    Tim se pri dalsim zmenseni nemicha s barvou pruhledna (cerna), takze na
    siluete nevznikne tmavy lem. Alfa se NEMENI - jen barva.
    """
    a = np.array(img).astype(np.uint8)
    maska = a[:, :, 3] > 0
    if maska.all():
        return img
    # vzdalenost k nejblizsimu nepruhlednemu pixelu + indexy toho pixelu
    _d, (iy, ix) = ndimage.distance_transform_edt(~maska, return_indices=True)
    for k in range(3):
        kanal = a[:, :, k]
        kanal[~maska] = kanal[iy[~maska], ix[~maska]]
    return Image.fromarray(a, "RGBA")


def zmensi(img: Image.Image, velikost: tuple[int, int], filtr=Image.LANCZOS) -> Image.Image:
    """Zmenseni RGBA PO KANALECH - a je to POVINNE, ne kosmetika.

    ⚠ NAMERENO 2026-10-10: `Image.resize` na rezimu RGBA resampluje s alfou
    (premultiplika) a u pixelu s alfou blizkou nule pak v RGB dela neplechu.
    Sonda: ctverec (200,100,50,255) na pozadi (200,100,50,0) zmensenovy
    LANCZOSEM dal v rohu **(255,0,0,1)** - cerveny pixel, ktery v obrazku
    vubec nebyl. V nasem atlase to delalo CERNE LINKY na stycich dlazdic
    (barva 0 misto travy) a tmave lemy u spritu.

    Resi se to tak, ze se barva a alfa resampluji KAZDA ZVLAST (rezim RGB alfu
    nema, takze se ho to netyka) a spoji se az vysledek.
    """
    if img.mode != "RGBA":
        return img.resize(velikost, filtr)
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b)).resize(velikost, filtr)
    out = rgb.convert("RGBA")
    out.putalpha(a.resize(velikost, filtr))
    return out


# ---------------------------------------------------------------------------
# 2) korekce na UO projekci
# ---------------------------------------------------------------------------
def na_uo_obrazek(img: Image.Image) -> Image.Image:
    """Zrcadleni vodorovne + svisle roztazeni (stejna cisla jako `na_uo_bod`)."""
    if ac.MIRROR_X:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    vyska = ac.na_uo_velikost(img.height)
    return zmensi(img, (img.width, vyska))


# ---------------------------------------------------------------------------
# 3) pozadi
# ---------------------------------------------------------------------------
def odstran_pozadi(img: Image.Image, klic=(0.0, 1.0, 0.0),
                   tolerance: int = 24) -> tuple[Image.Image, str, int]:
    """Vrati (obrazek, ktera cesta se pouzila, pocet pixelu barvy pozadi).

    Kdyz ma obrazek pruhledne pixely (render s alfou), pouzije se alfa a barva
    pozadi se jen POCITA (kontrola, ze v obsahu nezustala). Jinak (render bez
    alfy) se pozadi odstrani podle barvy - proto to tu je: pipeline nesmi
    stat na tom, kterou cestu zrovna Blender zvolil.
    """
    a = np.array(img).astype(np.int16)
    rgb, alfa = a[:, :, :3], a[:, :, 3]
    k = np.array([round(c * 255) for c in klic], dtype=np.int16)
    blizko = (np.abs(rgb - k).max(axis=2) <= tolerance) & (alfa > 0)
    pocet_barva = int(blizko.sum())
    if (alfa == 0).any():
        return img, "alfa", pocet_barva
    alfa2 = np.where(blizko, 0, 255).astype(np.uint8)
    out = np.dstack([rgb.astype(np.uint8), alfa2])
    return Image.fromarray(out, "RGBA"), "barva", pocet_barva


# ---------------------------------------------------------------------------
# 4) diry
# ---------------------------------------------------------------------------
def maska_obsahu(img: Image.Image) -> np.ndarray:
    """Binarni maska siluety (alfa >= 128) s ZAPLNENYMI dirami."""
    alfa = np.array(img.split()[3])
    maska = alfa >= 128
    return ndimage.binary_fill_holes(maska)


def kosoctverec_mask(w: int, h: int) -> np.ndarray:
    """Presny kosoctverec dlazdice - MERENE shodny s UO land artem.

    UO `land_0.png` (id 3) ma v radku r presne `2*(min(r, 43-r)+1)` pixelu od
    sloupce `21-min(r,43-r)` do `22+min(r,43-r)`. Presne to vychazi z podminky
    `|(c+0.5) - 22| + |(r+0.5) - 22| <= 22`, ktera je tady - proto se maska
    neopisuje z UO, ale pocita (a `pack_atlas.py --check` ji s UO POROVNAVÁ).
    """
    stred = (ac.TILE / 2.0, ac.TILE / 2.0)
    cc, rr = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    return (np.abs(cc - stred[0]) + np.abs(rr - stred[1])) <= (ac.TILE / 2.0)


# Pocet pixelu kosoctverce 44x44 = soucet 2*(1+2+...+22) = 1012 pixelu.
# Neni to plocha (44*44/2 = 968): pixel patri do kosoctverce cely, kdyz do nej
# patri jeho STRED. UO maska ma 1012 - proto se porovnava pocet, ne plocha.
KOSOCTVEREC_PX = int(kosoctverec_mask(ac.TILE, ac.TILE).sum())


# ---------------------------------------------------------------------------
# 5) + 6) zmenseni a sestaveni s kotvou
# ---------------------------------------------------------------------------
def priprav(cesta: Path, origin: tuple[float, float]) -> dict:
    """Nacte render, udela bleed + korekci projekce a vrati masku, bbox a kotvu."""
    img = Image.open(cesta).convert("RGBA")
    img = vypln_rgb(img, kolik=3)
    img = na_uo_obrazek(img)
    img, cesta_pozadi, pocet_barva = odstran_pozadi(img)
    maska = maska_obsahu(img)
    if not maska.any():
        raise RuntimeError(f"{cesta}: po odstraneni pozadi nezustal zadny obsah")
    oy, ox = np.nonzero(maska)
    bbox = (int(ox.min()), int(oy.min()), int(ox.max()), int(oy.max()))
    bod = ac.na_uo_bod(origin[0], origin[1])
    return {"img": img, "maska": maska, "bbox": bbox, "origin": bod,
            "cesta": str(cesta), "pozadi": cesta_pozadi, "pocet_barva": pocet_barva}


def meritko(pripravene: list[dict], obsah_vyska_px: float = None,
            obsah_sirka_px: float = None) -> float:
    """Jedno meritko pro celou davku (pocita se z PRUNIKU vsech framu).

    Duvod pro prunik: kdyby se kazdy frame zmensoval podle sveho bboxu, postava
    by "dychala" - menila by velikost podle pozy. UO to tak ma (obsah 56..64 px
    u tela 400) a je to videt jako poskakovani.
    """
    if obsah_vyska_px is None and obsah_sirka_px is None:
        raise ValueError("chybi cilova velikost obsahu")
    if obsah_vyska_px is None:
        sirka = max(p["bbox"][2] - p["bbox"][0] + 1 for p in pripravene)
        return obsah_sirka_px / float(sirka)
    vyska = max(p["bbox"][3] - p["bbox"][1] + 1 for p in pripravene)
    return obsah_vyska_px / float(vyska)


def sestav(pripravene: list[dict], s: float, druh: str,
           popis: str = "") -> tuple[list[Image.Image], list[dict]]:
    """Zmensi a vlozi sprity tak, aby kontakt sedel na (w//2, h-22).

    Vsechny framy davky dostanou STEJNY rozmer i kotvu (proto se hleda maximum
    pres cely prunik) - jinak by kotva po framech ujizdela.
    """
    # spolecna kotva a spolecny box pres vsechny framy davky
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
    # hranice obsahu v meritku ciloveho spritu (souradnice STREDU pixelu)
    f = lambda v: (v + 0.5) * s - 0.5
    Ox, Oy = f(ox), f(oy)
    l, t, r, b = f(levy), f(horni), f(pravy), f(dolni)
    w = 2 * (math.ceil(max(Ox - l, r - Ox)) + 1)
    h = int(round(Oy - t)) + ac.GROUND_PX
    if druh == "land":
        w = h = ac.TILE
    # BRANA: obsah nesmi pod kontakt zasahovat vic nez GROUND_PX px. Jinak by
    # sprite na dlazdici sedel niz, nez kam patri (a poznalo by se to az ve hre).
    # U dlazdice se nehlida: jeji kosoctverec kontakt obklopuje presne a maska
    # se dosazuje analyticky (`kosoctverec_mask`).
    pod = b - Oy
    if druh != "land" and pod > ac.GROUND_PX:
        raise RuntimeError(
            f"{popis}: obsah zasahuje {pod:.1f} px pod kontaktni bod, ale sprite "
            f"muze mit pod nim jen {ac.GROUND_PX} px - model je potreba posunout "
            "nad pocatek (kontakt = stred pudorysu)")
    vloz_x = int(round(w // 2 - Ox))
    vloz_y = int(round(h - ac.GROUND_PX - Oy))
    sprity, meta = [], []
    for p in pripravene:
        nw, nh = max(1, int(round(p["img"].width * s))), max(1, int(round(p["img"].height * s)))
        maly = zmensi(p["img"], (nw, nh))
        # gate: maska (alfa >= 128) rozsirena o 2 px v MERITKU RENDERU - odstrani
        # obal z Lanczosu daleko od siluety, ale necha hladkou hranu (ta je
        # v alfe ze supersamplingu). Prah `ALFA_PRAH` pak dorazi zbytek.
        sirsi = ndimage.binary_dilation(p["maska"], iterations=2)
        maska = Image.fromarray((sirsi * 255).astype(np.uint8)).resize((nw, nh), Image.NEAREST)
        gate = np.array(maska) > 127
        alfa = np.array(maly.split()[3])
        alfa = np.where(gate & (alfa >= ALFA_PRAH), alfa, 0).astype(np.uint8)
        rgb = np.array(maly)[:, :, :3]
        telo = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")
        platno = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        if druh == "land":
            # ⚠ U dlazdice se BARVA bere BEZ OHLEDU NA ALFU (`paste` na obrazek
            # bez alfy): tvar je dany presnou maskou, ale barva musi byt vsude,
            # kam maska saha. Kdyz se slozila pruhlednostnim `alpha_composite`,
            # zustaly v rozich kosoctverce pixely (0,0,0,0) a maska z nich
            # udelala ALFA 255 -> v mape byly CERNE LINKY na stycich
            # (namEReno 2026-10-10).
            platno.paste(maly.convert("RGB"), (vloz_x, vloz_y))
        else:
            platno.alpha_composite(telo, (vloz_x, vloz_y))
        if druh == "land":
            # TADY se maska NEPOCITA z renderu, ale dosadi presny kosoctverec:
            # dlazdice musi presne sedet na sousedy (filtr v GPU by jinak vzal
            # pul pixelu z okoli) a UO maska je zmerena presne. ALFA JE 255 -
            # dlazdice je plna plocha, nema co prosvitat; kdyz se nechala alfa
            # z renderu, zustaly na okraji kosoctverce pruhledne pixely
            # (namEReno: 969 misto 1012 pixelu masky).
            m = kosoctverec_mask(w, h)
            a2 = np.array(platno)
            a2[:, :, 3] = np.where(m, 255, 0).astype(np.uint8)
            platno = Image.fromarray(a2, "RGBA")
            if int(m.sum()) != KOSOCTVEREC_PX:
                raise RuntimeError(f"maska kosoctverce ma {int(m.sum())} px, "
                                   f"ocekavano {KOSOCTVEREC_PX}")
        sprity.append(platno)
        meta.append({"w": w, "h": h, "obsah_pod_kontaktem_px": round(pod, 2),
                     "obsah_vyska_px": int(round(b - t + 1)),
                     "obsah_sirka_px": int(round(r - l + 1)),
                     "pozadi": p["pozadi"], "barva_pozadi_px": p["pocet_barva"],
                     "meritko": s})
    return sprity, meta


def uloz_nahled(sprity: list[Image.Image], cesta: Path, kolik: int = 8) -> None:
    """Zvetseny nahled sprite(ů) - na kontrolu pohledem behem ladeni."""
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
    ap = argparse.ArgumentParser(description="postprocess jednoho renderu (ladici rezim)")
    ap.add_argument("--render", required=True)
    ap.add_argument("--origin", required=True, help="JSON z render_sprites.py")
    ap.add_argument("--obsah-vyska", type=float, required=True)
    ap.add_argument("--druh", default="item")
    ap.add_argument("--out", default="tools/artgen/_postprocess-nahled.png")
    ap.add_argument("--json", action="store_true", help="vypsat metadata v JSON")
    a = ap.parse_args()
    o = json.loads(Path(a.origin).read_text(encoding="utf-8"))
    p = priprav(Path(a.render), (o["origin_x"], o["origin_y"]))
    s = meritko([p], obsah_vyska_px=a.obsah_vyska)
    sprity, meta = sestav([p], s, a.druh, popis=str(a.render))
    uloz_nahled(sprity, Path(a.out))
    print(f"[postprocess] {a.render} -> {a.out} sprite {sprity[0].size} "
          f"kotva=({sprity[0].width // 2},{sprity[0].height - ac.GROUND_PX})")
    if a.json:
        print(json.dumps(meta[0], ensure_ascii=False, sort_keys=True))
