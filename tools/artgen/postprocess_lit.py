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

ALFA_PRAH = pp.ALFA_PRAH


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


def vrstva_stinu(p: dict, s: float, nw: int, nh: int, w: int, h: int,
                 vloz_x: int, vloz_y: int, px_jednotka: float) -> tuple[Image.Image, dict]:
    """Vrstva kontaktniho stinu ve velikosti vlozeneho spritu (+ statistika).

    Statistika je tu proto, aby se "stin existuje" dalo OVERIT v brani
    (`pack_atlas_lit.py --check`) - jinak by tvrzeni "lit sada ma kontaktni
    stin" nebylo nicim kryte.
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
            "rovina_vyska_px": int(ys.max() - ys.min() + 1) if len(ys) else 0,
            "px_na_jednotku": round(px_jednotka, 2)}
    return out, stat


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
           popis: str = "") -> tuple[list[Image.Image], list[dict]]:
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
        alfa = np.where(gate & (alfa >= ALFA_PRAH), alfa, 0).astype(np.uint8)
        rgb = np.array(maly)[:, :, :3]
        telo = Image.fromarray(np.dstack([rgb, alfa]), "RGBA")
        platno = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        stat = {"px": 0, "max_alfa": 0, "faktor_min": 1.0, "rovina_px": 0,
                "rovina_sirka_px": 0, "rovina_vyska_px": 0, "px_na_jednotku": 0.0,
                "px_na_jednotku_merene": 0.0}
        if druh == "land":
            # ⚠ U dlazdice se BARVA bere BEZ OHLEDU NA ALFU (jako v 1x): tvar je
            # dany presnou maskou, ale barva musi byt vsude, kam maska saha.
            platno.paste(maly.convert("RGB"), (vloz_x, vloz_y))
        else:
            if "stin" in p:
                stin_img, stat = vrstva_stinu(p, s, nw, nh, w, h, vloz_x, vloz_y,
                                              px_jednotka)
                stat["px_na_jednotku_merene"] = round(
                    px_na_jednotku_merene(p["ref"]) * s, 2)
                platno.alpha_composite(stin_img, (vloz_x, vloz_y))
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
        meta.append({"w": w, "h": h, "obsah_pod_kontaktem_px": round(pod, 2),
                     "obsah_vyska_px": int(round(b - t + 1)),
                     "obsah_sirka_px": int(round(r - l + 1)),
                     "pozadi": p["pozadi"], "barva_pozadi_px": p["pocet_barva"],
                     "meritko": s, "stin_vrstva_px": stat["px"],
                     "stin_viditelne_px": viditelny_stin(platno),
                     "stin_max_alfa": stat["max_alfa"],
                     "stin_faktor_min": round(stat["faktor_min"], 4),
                     "stin_rovina_px": stat["rovina_px"],
                     "rovina_sirka_px": stat["rovina_sirka_px"],
                     "rovina_vyska_px": stat["rovina_vyska_px"],
                     "px_na_jednotku": stat["px_na_jednotku"],
                     "px_na_jednotku_merene": stat["px_na_jednotku_merene"]})
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
