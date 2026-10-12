# -*- coding: utf-8 -*-
"""postprocess_lit.py - z 1x renderu udela sprite 1x kontraktu + KONTAKTNI STIN.

KROKY: stejne jako `postprocess.py` (alfa-bleed -> korekce projekce -> pozadi ->
diry -> Lanczos -> kotva), jen s tim, co 1x ZAMERNE NEMEL a co se prebira z 2x
vetve (ZADANI-25 §10):

  KONTAKTNI STIN. Neni dokreslovany: `render_lit.py` vyrenderuje kontaktni
  rovinu (pudorys dlazdice) dvakrat - s objektem a bez objektu - a tady se
  z pomeru jasu pocita FAKTOR ZASTINENI:
      faktor = jas(stin) / jas(ref)        (1 = osvetleno, 0 = plny stin)
      alfa   = (1 - faktor) * radialni_ubytecek * STIN_SILA
  Radialni ubytek dela z vrhu KONTAKTNI stin (louze pod objektem); bez nej by
  stin od 1,2 jednotky vysoke postavy utekl pres celou dlazdici.
  Vsechna cisla stinu (R0/R1, sila, prah) se BEROU z 2x vetve
  (`artgen_common_lit` je jen prebira) - kdyby se recept rozešel, `--check` to
  hlasi.

⚠ STEJNA PAST JAKO V 1x: `PIL.Image.resize` na RGBA rozsype RGB tam, kde je
alfa ~0 (cerna linka). Vsechno zmensovani jde pres `postprocess.zmensi` (RGB
a alfa zvlast) - tady se to tyka i masek stinu.

⚠ MERENE MERITKO (a past, ktera se prebira s receptem): `px_na_jednotku` se
pocita z UHLOPRICKY kontaktni roviny (`sirka / sqrt(2)`), presne jako v 2x
vetvi. Skutecna sirka roviny v UO projekci je ale 1 jednotka (ne sqrt(2)) -
stin je proto v jednotkach ~1,41x mensi, nez rikaji konstanty R0/R1. Je to
PREVZATE zamerne (aby recept zustal tyz) a je to ZMERENO: `pack_atlas_lit.py
--check` hlasi obe cisla vedle sebe (`px_na_jednotku` i `px_na_jednotku_merene`).
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import artgen_common_lit as acl
import postprocess as pp
import styl

ALFA_PRAH = pp.ALFA_PRAH


# ---------------------------------------------------------------------------
# RECEPT STINU (v2 = prevzaty z 2x, v3 = oprava placatych predmetu)
# ---------------------------------------------------------------------------
# ⚠ MERENO 2026-10-11 (`MERENI.md` §9.3 bod 3): soucasny recept dela z kontaktniho
# stinu placateho predmetu jen 1px lem - dyka 6-7 px, ingot 11 px, kdezto ruda
# 235-261 px. Duvod NENI v renderu (ten ma u obou hustotu 0,73-0,83): je to
# RADIALNI UBYTEK od kotvy. U placateho predmetu je cely jeho pudorys dal od
# kotvy nez R0 = 0,14 jednotky (u dyky ~0,3 jednotky = 3-4 px) a ubytek tam
# spadne na ~0, takze stin se do vysledku dostane s alfou 10-30/255.
#
# v3 proto pocita ubytek od OBRYSU OBJEKTU, ne od kotvy:
#     alfa = (1 - faktor) * smoothstep(hloubka / mekkost) * sila
# kde `hloubka` je vzdalenost pixelu od obrysu objektu. Tim je stin kontaktni pro
# KAZDY tvar (placaty predmet ma lem, postava louzi pod nohama) a sirku urcuje
# `mekkost_px`, ne poloha kotvy.
#
# ⚠ OBAL (dilatace) je potreba, protoze souradnice OBJEKTU a ROVINY se lisi:
# objekt stoji NAD rovinou, takze se jeho silueta promita o par pixelu jinde nez
# jeho stopa (mereno: u dyky je hrana tela 2-3 px od mista, kde zacina stin).
# Bez obalu by stin zustal "pod" telem a nebyl by videt - coz je presne vada,
# ktera se opravuje.
RECEPTY_STINU = {
    # dnesni chovani (2x recept) - zustava kvuli srovnani a reprodukovatelnosti
    "v2": {"verze": "v2", "sila": None},
    # OPRAVA (2026-10-11): ubytek od OBRYSU OBJEKTU, ne od kotvy.
    #   sila     - nasobek krytí (v2 mel 0,55; merene krytí u placateho predmetu
    #              bylo 16/255, tedy pod hranici viditelnosti)
    #   posun_px - posun masky tela ve smeru svetla (objekt stoji NAD rovinou)
    #   jadro_px - jak daleko za obrysem je stin jeste plny (kontaktni lem)
    #   mekkost_px - pres kolik px stin od obrysu zmizi (0 = tvrdy lem)
    #   odstup_px - blize nez tohle od tela se stin nekresli (stejne by zmizel)
    #   sila     - nasobek krytí. ⚠ JE TO ZMERENE ROZHODNUTI, NE ODHAD: sada
    #              variant se posoudila POHLEDEM ve hre 1 : 1
    #              (`srovnani_receptu_stinu.py`, `_srovnani-recept-stinu.png`);
    #              sila 1,0 vysla jako TMAVY OBAL (prumerne krytí 97-107/255
    #              u dyky a rudy) a na trave to je videt jako skvrna. 0,5 drzi
    #              stin citelny (dyka 48/255, ruda 53/255) a neprebiji predmet.
    "v3": {"verze": "v3", "sila": 0.5, "posun_px": (-2, -1), "sirka_px": 0.6,
           "mekkost_px": 1.2, "odstup_px": 0.9, "jadro_sila": 0.0},
}
RECEPT_STINU_AKTIVNI = "v2"


def nastav_recept_stinu(jmeno: str) -> dict:
    """Prepnout recept stinu (pro srovnani a ladeni; neni to globalni stav trvale)."""
    if jmeno not in RECEPTY_STINU:
        raise ValueError(f"neznamy recept stinu: {jmeno!r} (je {sorted(RECEPTY_STINU)})")
    global RECEPT_STINU_AKTIVNI
    RECEPT_STINU_AKTIVNI = jmeno
    return RECEPTY_STINU[jmeno]


def recept_stinu() -> dict:
    return RECEPTY_STINU[RECEPT_STINU_AKTIVNI]


# ---------------------------------------------------------------------------
# korekce projekce (1x cisla)
# ---------------------------------------------------------------------------
def na_uo_obrazek(img: Image.Image) -> Image.Image:
    if acl.MIRROR_X:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return pp.zmensi(img, (img.width, acl.na_uo_velikost(img.height)))


def priprav(cesta: Path, origin: tuple[float, float],
            stin: Path = None, ref: Path = None) -> dict:
    """Nacte render (a pripadne masky stinu) a udela bleed + korekci projekce."""
    img = Image.open(cesta).convert("RGBA")
    img = pp.vypln_rgb(img, kolik=3)
    img = na_uo_obrazek(img)
    img, cesta_pozadi, pocet_barva = pp.odstran_pozadi(img)
    maska = pp.maska_obsahu(img)
    if not maska.any():
        raise RuntimeError(f"{cesta}: po odstraneni pozadi nezustal zadny obsah")
    oy, ox = np.nonzero(maska)
    bbox = (int(ox.min()), int(oy.min()), int(ox.max()), int(oy.max()))
    bod = acl.na_uo_bod(origin[0], origin[1])
    out = {"img": img, "maska": maska, "bbox": bbox, "origin": bod,
           "cesta": str(cesta), "pozadi": cesta_pozadi, "pocet_barva": pocet_barva}
    if stin is not None and ref is not None:
        # STEJNE transformace jako u kreativniho pruchodu - jinak by stin
        # nesedel na objekt (a poznalo by se to az na kontaktnim listu)
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
def rovina_bbox(ref: Image.Image) -> tuple[int, int]:
    """(sirka, vyska) viditelne kontaktni roviny v renderu - MERENO z pixelu."""
    alfa = np.asarray(ref)[:, :, 3] > 127
    ys, xs = np.nonzero(alfa)
    if not len(xs):
        raise RuntimeError("v referencnim renderu neni videt kontaktni rovina - "
                           "polomer stinu by se nemel z ceho spocitat")
    return (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))


def px_na_jednotku(ref: Image.Image) -> float:
    """Kolik px je v TOMHLE spritu 1 svetova jednotka - VZOREC PREVZATY Z 2x.

    ⚠ Je to sirka roviny / sqrt(2), tedy "pres uhlopricku" - viz docstring
    modulu: v UO projekci je sirka roviny 1 jednotka, takze tenhle vzorec dava
    o sqrt(2) vic, nez je skutecnost. Prebrano zamerne, aby stin v lit vetvi
    vznikal TYMZ vzorcem jako ve 2x; spravne cislo se meri zvlast
    (`px_na_jednotku_merene`) a obe se hlasí.
    """
    sirka, _vyska = rovina_bbox(ref)
    return sirka / math.sqrt(2.0)


def px_na_jednotku_merene(ref: Image.Image) -> float:
    """Skutecna sirka roviny v px = kolik px je 1 jednotka (bez deleni sqrt(2))."""
    sirka, _vyska = rovina_bbox(ref)
    return float(sirka)


def _vrstva_v2(p: dict, s: float, nw: int, nh: int, w: int, h: int,
               vloz_x: int, vloz_y: int, px_jednotka: float,
               recept: dict) -> tuple[Image.Image, dict]:
    """Dnesni recept (2x): ubytek RADIALNE od kotvy, sila/barva/prah z 2x."""
    sh = pp.zmensi(p["stin"], (nw, nh))
    rf = pp.zmensi(p["ref"], (nw, nh))
    a_sh = np.asarray(sh, dtype=np.float32)
    a_rf = np.asarray(rf, dtype=np.float32)
    jas_stin = a_sh[:, :, :3].mean(axis=2)
    jas_ref = a_rf[:, :, :3].mean(axis=2)
    faktor = np.clip(jas_stin / np.maximum(jas_ref, 1e-3), 0.0, 1.0)
    rovina = a_rf[:, :, 3] > 127                 # jen tam, kde je videt rovina

    # stred = KONTAKTNI BOD spritu (kotva), v jednotkach dlazdice
    ax = (w // 2) - vloz_x
    ay = (h - acl.GROUND_PX) - vloz_y
    yy, xx = np.mgrid[0:nh, 0:nw]
    r = np.hypot(xx - ax, yy - ay) / px_jednotka
    u = np.clip((acl.STIN_R1_JEDNOTEK - r) /
                (acl.STIN_R1_JEDNOTEK - acl.STIN_R0_JEDNOTEK), 0.0, 1.0)
    ubytek = u * u * (3.0 - 2.0 * u)                 # smoothstep

    alfa = (1.0 - faktor) * ubytek * acl.STIN_SILA * 255.0 * rovina
    alfa = np.where(alfa >= acl.STIN_PRAH, alfa, 0.0).astype(np.uint8)
    rgb = np.zeros((nh, nw, 3), dtype=np.uint8)
    rgb[:, :] = acl.STIN_BARVA
    out = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")
    ys, xs = np.nonzero(rovina)
    stat = {"px": int((alfa > 0).sum()),
            "max_alfa": int(alfa.max()) if alfa.size else 0,
            "faktor_min": float(faktor[rovina].min()) if rovina.any() else 1.0,
            "rovina_px": int(rovina.sum()),
            "rovina_sirka_px": int(xs.max() - xs.min() + 1) if len(xs) else 0,
            "rovina_vyska_px": int(ys.max() - ys.min() + 1) if len(xs) else 0,
            "px_na_jednotku": round(px_jednotka, 2)}
    return out, stat


def _vrstva_v3(p: dict, s: float, nw: int, nh: int, w: int, h: int,
               vloz_x: int, vloz_y: int, px_jednotka: float,
               recept: dict, maska_tela: np.ndarray,
               stin_pozadi: Image.Image) -> tuple[Image.Image, dict]:
    """OPRAVA (2026-10-11): ubytek od OBRYSU OBJEKTU, ne od kotvy.

    Vse ostatni je merene z renderu (`1 - jas_stin/jas_ref`), takze TVAR stinu
    porad urcuje slunce - jen se uz nezahodi ubytkem, ktery u placateho predmetu
    vyjde temer nulovy.

    DVE PODMINKY, KTERE SE UKAZALY BYT NUTNE (obojí namEReno pri ladeni):

      * STIN SE KRESLI JEN VNE OBJEKTU (`vzdalenost od tela >= 0,5 px`). Stin
        nakresleny POD telem stejne zmizi (telo je neprůhledné) - a kdyby se
        pocital i pod telem, "vrstva stinu" by hlásila stovky pixelu, ktere
        hrac NIKDY nevidi. Presne to je past z `MERENI.md` §9.4 bod 1.
      * MASKU TELA je potreba POSUNOUT o `posun_px` ve smeru svetla: objekt stoji
        NAD rovinou a jeho stopa je jinde nez jeho silueta (u dyky o 2-3 px).
        Bez posunu by lem vznikl na spatne strane.

    ⚠ STIN SE POCITA NA VETSIM PLATNE (`stin_pozadi`), NE NA PLATNE SPRITU:
    mekkost sahaji za okraj sprite boxu a kdyby se pocitala na nem, stin by
    u hrany spritu chybel. Do sprite boxu se promitne jen to, co se vejde
    (a brana hlida, ze se stin okraje NEDOTYKA).
    """
    sh = pp.zmensi(p["stin"], (nw, nh))
    rf = pp.zmensi(p["ref"], (nw, nh))
    a_sh = np.asarray(sh, dtype=np.float32)
    a_rf = np.asarray(rf, dtype=np.float32)
    jas_stin = a_sh[:, :, :3].mean(axis=2)
    jas_ref = a_rf[:, :, :3].mean(axis=2)
    faktor = np.clip(jas_stin / np.maximum(jas_ref, 1e-3), 0.0, 1.0)
    zastineni = 1.0 - faktor                      # 0 = osvetleno, 1 = plny stin
    rovina = a_rf[:, :, 3] > 127

    pw, ph = stin_pozadi.size
    okraj = recepce_okraj(recept)
    px_off = vloz_x - okraj
    py_off = vloz_y - okraj

    def na_platno(m: np.ndarray, posun=(0, 0)) -> np.ndarray:
        """Vlozi masku (nebo hodnoty) do platna stinu s ORIZNUTIM a posunem.

        ⚠ Oriznuti je nutne: kdyz je maska vetsi nez platno, Python by ji
        zabalil (zaporne indexy) a stin by vznikl na spatnem miste.
        """
        out = np.zeros((ph, pw), dtype=m.dtype)
        ox = px_off + posun[0]
        oy = py_off + posun[1]
        x0, y0 = max(0, ox), max(0, oy)
        x1 = min(pw, ox + m.shape[1])
        y1 = min(ph, oy + m.shape[0])
        if x1 > x0 and y1 > y0:
            out[y0:y1, x0:x1] = m[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
        return out

    telo = na_platno(maska_tela).astype(bool)
    telo_posunute = na_platno(maska_tela, recept.get("posun_px", (0, 0))).astype(bool)

    # ROZMERY PASU STINU. Vsechno jsou PX ve spritu; zadna svetova jednotka.
    # ⚠ PROC PAS A NE ZMERENA HUSTOTA: v surovem renderu je kontaktni stin
    # placateho predmetu jen 1 px siroky (mereno `probe_stin_raw.py`: u dyky
    # `hustota_u_obrysu` 0,25-0,28, u ingotu 0,55, ale vzdy jen v jednom pixelu).
    # Pri zmenseni z 512 px na sprite (~0,097) je z neho antialias, ktery v2
    # pocitalo jako "stin" - a proto mela dyka 6 px a ingot 11 px krytí 16-50/255.
    # v3 z tehoz renderu bere KRYTÍ (jak je stin silny) a SIRKU pasu urcuje
    # v px, aby byl stin videt i po zmenseni.
    odstup = float(recept.get("odstup_px", 1.0))
    sirka = float(recept.get("sirka_px", 1.0))
    mekkost = max(1e-3, float(recept["mekkost_px"]))

    # Zaklad stinu = POSUNUTA MASKA TELA (stin objektu je jeho pudorys; v ortografii
    # ho posune jen ubytek svetla, ktery je u placateho predmetu pod rozlisenim).
    if telo_posunute.any():
        vzdalenost = ndimage.distance_transform_edt(~telo_posunute)
    else:
        vzdalenost = np.full((ph, pw), 1e6, dtype=np.float32)

    # ... a vzdalenost od SKUTECNEHO tela: pod tim, co hrac vidi, stin nema smysl
    # (pocita se v meritku SPRITU - stejne jako `rovina` a `zastineni`)
    if maska_tela.any():
        vzd_od_tela = ndimage.distance_transform_edt(~maska_tela)
    else:
        vzd_od_tela = np.full(maska_tela.shape, 1e6, dtype=np.float32)

    # KRYTÍ stinu = ZMERENA HUSTOTA z PET PIXELU ZA obrysem (90. percentil, ne
    # maximum: jedno odleskove misto nema rozhodovat o sili celeho spritu).
    # ⚠ HUSTOTA SE CTE OD POSUNUTEHO OBYSU (stejne jako pas): fyzicky stin lezi
    # TESNE za obrysem a tou dobou je to prave 1px lem; kdyz se merilo od
    # neposunuteho tela, vychazelo krytí 0,006 (hodnota z pixelu, ktere jsou
    # uvnitr tela a maji hustotu skoro nulovou) - stin by zmizel.
    kryti = float(recept.get("jadro_sila", 0.0))
    if rovina.any():
        # posun masky v meritku SPRITU (stejna operace jako `na_platno` posun)
        _px, _py = recept.get("posun_px", (0, 0))
        pruh_maska = np.zeros_like(maska_tela)
        xs0, ys0 = max(0, _px), max(0, _py)
        xs1 = min(maska_tela.shape[1], maska_tela.shape[1] + _px)
        ys1 = min(maska_tela.shape[0], maska_tela.shape[0] + _py)
        if xs1 > xs0 and ys1 > ys0:
            pruh_maska[ys0:ys1, xs0:xs1] = maska_tela[ys0 - _py:ys1 - _py,
                                                       xs0 - _px:xs1 - _px]
        pruh = rovina & ~pruh_maska & (vzd_od_tela <= 5.0)
        if pruh.any():
            kryti = max(kryti, float(np.quantile(zastineni[pruh], 0.90)))

    # TVAR PASU: plny od obrysu do `odstup + sirka`, pak do `odstup + sirka +
    # mekkost` slábne (smoothstep). Mimo je nula - stin je KONTAKTNI, ne vrh.
    u = np.clip((vzdalenost - odstup - sirka) / mekkost, 0.0, 1.0)
    ubytek = 1.0 - u * u * (3.0 - 2.0 * u)
    ubytek = np.where(vzdalenost >= odstup, ubytek, 0.0)

    sila = acl.STIN_SILA if recept["sila"] is None else float(recept["sila"])
    alfa = ubytek * kryti * sila * 255.0
    alfa = np.where(alfa >= acl.STIN_PRAH, alfa, 0.0).astype(np.uint8)
    rgb = np.zeros((ph, pw, 3), dtype=np.uint8)
    rgb[:, :] = acl.STIN_BARVA
    out = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")

    # statistika se hlasi z OKNA, ktere se opravdu vlozi do spritu. Vrstva je na
    # vetsim platne s posunutym pocatkem, takze okno je (okraj, okraj) - ne
    # (vloz_x, vloz_y); kdyz se pletlo, `max_alfa` hlasilo 0 u spritu, ktery
    # mel videt 123/255 (namEReno).
    _pod = np.asarray(out)
    a_sprite = _pod[okraj:okraj + h, okraj:okraj + w, 3]
    silny = a_sprite > 0
    stat = {"px": int(silny.sum()),
            "max_alfa": int(a_sprite.max()) if a_sprite.size else 0,
            "platno": [pw, ph],
            "faktor_min": float(faktor[rovina].min()) if rovina.any() else 1.0,
            "rovina_px": int(rovina.sum()),
            "rovina_sirka_px": int(round(rovina_bbox(p["ref"])[0] * s)),
            "rovina_vyska_px": int(round(rovina_bbox(p["ref"])[1] * s)),
            "px_na_jednotku": round(px_jednotka, 2),
            "posun_px": list(recept.get("posun_px", (0, 0))),
            "sirka_px": round(float(recept.get("sirka_px", 1.0)), 2),
            "odstup_px": round(float(recept.get("odstup_px", 1.0)), 2),
            "mekkost_px": round(float(recept["mekkost_px"]), 2),
            "kryti": round(kryti, 4),
            "sila": round(sila, 3),
            "px_30_90": int(((a_sprite >= 30) & (a_sprite <= 90)).sum()),
            "platno": [pw, ph]}
    return out, stat


def recepce_okraj(recept: dict) -> int:
    """Kolik px okolo sprite boxu si recept v3 bere (posun + pas + mekkost)."""
    if recept.get("verze") != "v3":
        return 0
    posun = max(abs(int(v)) for v in recept.get("posun_px", (0, 0)))
    return int(math.ceil(posun + float(recept.get("odstup_px", 1.0))
                         + float(recept.get("sirka_px", 1.0))
                         + float(recept["mekkost_px"]))) + 3


def vrstva_stinu(p: dict, s: float, nw: int, nh: int, w: int, h: int,
                 vloz_x: int, vloz_y: int, px_jednotka: float,
                 maska_tela: np.ndarray = None) -> tuple[Image.Image, dict]:
    """Vrstva kontaktniho stinu (+ statistika). Recept se bere z `RECEPTY_STINU`.

    Statistika je tu proto, aby se "stin existuje" dalo OVERIT v brani
    (`pack_atlas_lit.py --check`) - jinak by tvrzeni "lit sada ma kontaktni
    stin" nebylo nicim kryte.
    """
    if "stin" not in p:
        raise RuntimeError(f"{p['cesta']}: chybi render stinu (plan bez roviny?)")
    recept = recept_stinu()
    if recept["verze"] == "v2":
        return _vrstva_v2(p, s, nw, nh, w, h, vloz_x, vloz_y, px_jednotka, recept)
    if maska_tela is None:
        raise RuntimeError(f"{p['cesta']}: recept v3 potrebuje masku tela "
                           "(jinak neni od ceho merit vzdalenost obrysu)")
    okraj = recepce_okraj(recept)
    stin_pozadi = Image.new("RGBA", (w + 2 * okraj, h + 2 * okraj), (0, 0, 0, 0))
    return _vrstva_v3(p, s, nw, nh, w, h, vloz_x, vloz_y, px_jednotka, recept,
                      maska_tela, stin_pozadi)


# ---------------------------------------------------------------------------
# zmenseni a sestaveni s kotvou
# ---------------------------------------------------------------------------
def viditelny_stin(img: Image.Image) -> int:
    """Pocet pixelu, kde je vrstva stinu VIDET (barva stinu + nizsi alfa).

    ⚠ Neni to velikost vrstvy: pixely stinu POD neprůhledným objektem videt
    nejsou a do tohoto cisla nepatri. A je to prave ten rozdil, ktery stoji za
    zapsani - u predmetu lezicich na zemi je videt jen 1px lem u obrysu
    (u dyky 7 px), kdezto vrstva ma 50+ px. Meri se proto z HOTOVEHO spritu.
    """
    a = np.array(img)
    alfa = a[:, :, 3]
    barva = (a[:, :, :3] == np.array(acl.STIN_BARVA, dtype=np.uint8)).all(axis=2)
    return int(((alfa > 0) & (alfa < 200) & barva).sum())


def sestav(pripravene: list[dict], s: float, druh: str,
           popis: str = "", paleta: Image.Image = None, sber=None,
           tvrda_alfa: bool = False) -> tuple[list[Image.Image], list[dict]]:
    """Zmensi a vlozi sprity tak, aby kontakt sedel na (w//2, h-22).

    Stejna logika jako 1x `postprocess.sestav` (vcetne vetve pro dlazdici);
    navic se platno zvetsi tak, aby se do nej vesel kontaktni stin.
    """
    if druh not in ("item", "anim", "land"):
        raise ValueError(f"neznamy druh: {druh!r}")
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
    h = int(round(Oy - t)) + acl.GROUND_PX
    px_jednotka = None
    if druh == "land":
        # dlazdice: presny box a maska kosoctverce (jako 1x) - zadny stin
        w = h = acl.TILE
    elif "ref" in pripravene[0]:
        # Polomer stinu se pocita z MERENEHO meritka spritu (viz `px_na_jednotku`),
        # ne z konstanty TILE - jinak by byl u kazdeho druhu jinak velky vuci objektu.
        px_jednotka = px_na_jednotku(pripravene[0]["ref"]) * s
        for p in pripravene:
            if "ref" not in p:
                raise RuntimeError(f"{p['cesta']}: chybi referencni render roviny, "
                                   "ale jina davka ho ma - stin by nesel premerit")
            if abs(px_na_jednotku(p["ref"]) * s - px_jednotka) > 1.0:
                raise RuntimeError("meritko roviny se v davce lisi (kamera se hybala?) "
                                   "- stin by po framech menil velikost")
        # ... a dost mista na kontaktni stin (kotva je od okraje dal nez R1)
        r1_px = int(math.ceil(acl.STIN_R1_JEDNOTEK * px_jednotka)) + 1
        w = max(w, 2 * r1_px)
        h = max(h, acl.GROUND_PX + r1_px)
        # ⚠ RECEPT v3 meri vzdalenost od OBRYSU, takze maska tela musi byt cela:
        # obal (2 px) + mekkost (2 px) sahaji za obrys obsahu. Kdyby se box
        # nezvetsil, maska by se orizla a stin u hrany spritu by vznikl z Niceho
        # (nebo by chybel). Overscan se pocita z MERENE sirky obsahu.
        okraj_v3 = recepce_okraj(recept_stinu())
        if okraj_v3:
            w = max(w, 2 * (math.ceil(max(Ox - l, r - Ox)) + okraj_v3 + 1))
            h = max(h, int(round(Oy - t)) + acl.GROUND_PX + okraj_v3)
    elif druh in ("item", "anim"):
        raise RuntimeError(f"{popis}: davka nema referencni render roviny - "
                           "kontaktni stin by se nemel z ceho spocitat")
    w += w % 2                                   # sudy box = kotva na stredu pixelu
    pod = b - Oy
    if druh != "land" and pod > acl.GROUND_PX:
        raise RuntimeError(
            f"{popis}: obsah zasahuje {pod:.1f} px pod kontaktni bod, ale sprite "
            f"muze mit pod nim jen {acl.GROUND_PX} px - model je potreba posunout "
            "nad pocatek (kontakt = stred pudorysu)")
    vloz_x = int(round(w // 2 - Ox))
    vloz_y = int(round(h - acl.GROUND_PX - Oy))
    sprity, meta = [], []
    for p in pripravene:
        nw = max(1, int(round(p["img"].width * s)))
        nh = max(1, int(round(p["img"].height * s)))
        maly = pp.zmensi(p["img"], (nw, nh))
        sirsi = ndimage.binary_dilation(p["maska"], iterations=2)
        maska = Image.fromarray((sirsi * 255).astype(np.uint8)).resize((nw, nh), Image.NEAREST)
        gate = np.array(maska) > 127
        alfa = np.array(maly.split()[3])
        if tvrda_alfa:
            # PIXEL-ART STYL (2026-10-11): silueta je 0/255, ne antialiasovana.
            # ⚠ GATE SE RESIZUJE BILINEARNE, NE `NEAREST`: pri `NEAREST` vypadavaji
            # z masky pixely na TENKYCH diagonalach - namEReno POHLEDEM: rukojet
            # krumpace se rozpadla na tecky (zmereno 103 px misto 262 puvodnich).
            # Bilinear + prah > 0 drzi tenky prvek cely; obal daleko od tvaru
            # odstrani az prah alfy (`ALFA_TVRDA_PRAH`).
            jemna = Image.fromarray((sirsi * 255).astype(np.uint8)).resize(
                (nw, nh), Image.BILINEAR)
            alfa = styl.tvrda_alfa(alfa, np.array(jemna) > 0)
        else:
            alfa = np.where(gate & (alfa >= ALFA_PRAH), alfa, 0).astype(np.uint8)
        if paleta is not None or sber is not None:
            rgb = np.asarray(styl.doostri(maly))
        else:
            rgb = np.array(maly)[:, :, :3]
        if sber is not None:
            sber.pridej(rgb, alfa)
        if paleta is not None:
            rgb = styl.na_paletu(rgb, paleta)
        telo = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")
        platno = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        stat = {"px": 0, "max_alfa": 0, "faktor_min": 1.0, "rovina_px": 0,
                "rovina_sirka_px": 0, "rovina_vyska_px": 0, "px_na_jednotku": 0.0,
                "px_na_jednotku_merene": 0.0}
        if druh == "land":
            # ⚠ U dlazdice se BARVA bere BEZ OHLEDU NA ALFU (jako v 1x): tvar je
            # dany presnou maskou, ale barva musi byt vsude, kam maska saha.
            # Barva je od 2026-10-11 DOOSTRENA a KVANTIZOVANA (styl sady).
            platno.paste(Image.fromarray(rgb, "RGB"), (vloz_x, vloz_y))
        else:
            if "stin" in p:
                # MASKA TELA pro recept v3 = to, co se opravdu kresli (po stylu),
                # v meritku spritu. Pocita se z `alfa` (uz po tvrde alfe), aby
                # stin sedel na siluetu, kterou hrac uvidi - ne na rozmazanou
                # masku z renderu.
                maska_tela = alfa >= ALFA_PRAH
                stin_img, stat = vrstva_stinu(p, s, nw, nh, w, h, vloz_x, vloz_y,
                                              px_jednotka, maska_tela=maska_tela)
                stat["px_na_jednotku_merene"] = round(
                    px_na_jednotku_merene(p["ref"]) * s, 2)
                # ⚠ VLOZENI STINU MA JINY POCATEK NEZ TELO (namEReno: stin byl
                # posunuty o `okraj` px a v okne spritu pak nebyl vubec).
                # Vrstva stinu je pocitana na VETSIM platne, ktera ma pocatek
                # posunuty o `okraj` - takze se vklada na (okraj, okraj), ne na
                # (vloz_x, vloz_y). Kdyz se vkladala na vloz_x, stin "ujel"
                # presne o okraj a vyslo 0 px.
                platno.alpha_composite(stin_img, (vloz_x, vloz_y) if recept_stinu()["verze"] == "v2" else (recepce_okraj(recept_stinu()),
                                                  recepce_okraj(recept_stinu())))
            platno.alpha_composite(telo, (vloz_x, vloz_y))
        if druh == "land":
            m = pp.kosoctverec_mask(w, h)
            a2 = np.array(platno)
            a2[:, :, 3] = np.where(m, 255, 0).astype(np.uint8)
            platno = Image.fromarray(a2, "RGBA")
            if int(m.sum()) != pp.KOSOCTVEREC_PX:
                raise RuntimeError(f"maska kosoctverce ma {int(m.sum())} px, "
                                   f"ocekavano {pp.KOSOCTVEREC_PX}")
        sprity.append(platno)
        videt = alfa >= 128
        meta.append({"w": w, "h": h, "obsah_pod_kontaktem_px": round(pod, 2),
                     "obsah_vyska_px": int(round(b - t + 1)),
                     "obsah_sirka_px": int(round(r - l + 1)),
                     "pozadi": p["pozadi"], "barva_pozadi_px": p["pocet_barva"],
                     "meritko": s, "stin_vrstva_px": stat["px"],
                     "stin_viditelne_px": viditelny_stin(platno),
                     "stin_max_alfa": stat["max_alfa"],
                     "stin_px_30_90": stat.get("px_30_90", 0),
                     "stin_faktor_min": round(stat["faktor_min"], 4),
                     "stin_rovina_px": stat["rovina_px"],
                     "rovina_sirka_px": stat["rovina_sirka_px"],
                     "rovina_vyska_px": stat["rovina_vyska_px"],
                     "px_na_jednotku": stat["px_na_jednotku"],
                     "px_na_jednotku_merene": stat["px_na_jednotku_merene"],
                     # STYL (2026-10-11): meri se na TELE spritu (ne na stinu).
                     "styl_tvrda_alfa": 1 if tvrda_alfa else 0,
                     "styl_barvy": int(len(np.unique(rgb[videt].reshape(-1, 3), axis=0)))
                     if videt.any() else 0,
                     "styl_polopruhle_px": int(((alfa > 0) & (alfa < 255)).sum())})
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
    ap = argparse.ArgumentParser(description="postprocess lit (ladici rezim, 1 snimek)")
    ap.add_argument("--render", required=True)
    ap.add_argument("--origin", required=True)
    ap.add_argument("--stin", default="")
    ap.add_argument("--ref", default="")
    ap.add_argument("--obsah-vyska", type=float, required=True)
    ap.add_argument("--druh", default="item")
    ap.add_argument("--out", default="tools/artgen/_postprocess-lit.png")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    o = json.loads(Path(a.origin).read_text(encoding="utf-8"))
    p = priprav(Path(a.render), (o["origin_x"], o["origin_y"]),
                stin=Path(a.stin) if a.stin else None,
                ref=Path(a.ref) if a.ref else None)
    s = meritko([p], obsah_vyska_px=a.obsah_vyska)
    sprity, meta = sestav([p], s, a.druh, popis=str(a.render))
    uloz_nahled(sprity, Path(a.out))
    print(f"[postprocess_lit] {a.render} -> {a.out} sprite {sprity[0].size} "
          f"kotva=({sprity[0].width // 2},{sprity[0].height - acl.GROUND_PX})")
    if a.json:
        print(json.dumps(meta[0], ensure_ascii=False, sort_keys=True))
