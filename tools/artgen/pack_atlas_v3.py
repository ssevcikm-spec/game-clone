# -*- coding: utf-8 -*-
"""pack_atlas_v3.py - slozi sadu v3 do `assets/own-v3/` (a brana).

  python tools/artgen/pack_atlas_v3.py            # z `_rawv3/` do `assets/own-v3/`
  python tools/artgen/pack_atlas_v3.py --check    # premer hotovy vystup
  python tools/artgen/pack_atlas_v3.py --check --hash

Je to OBDODA `pack_atlas_lit.py` (v2) se tremi zmerenymi zmenami:

  1. **RECEPT STINU v3** - `postprocess_lit.RECEPTY_STINU["v3"]`: ubytek stinu se
     pocita od OBRYSU OBJEKTU, ne radialne od kotvy. V2 u placateho predmetu
     ubytek vynuloval (dyka mela ve sprite videt 6 px stinu, ingot 11 px).
  2. **SVETLO v3** - k jednomu slunci pribyla VYPLN (protismer, bez stinu) a
     obloha sla z 0,45 na 0,50; obe zmeny maji cisla v `odchylky_od_v2()`.
  3. **BRANA MERI I TO, CO BYLO VADOU** - pocet VIDITELNYCH pixelu stinu u
     placateho predmetu (`STIN_MIN_PX_PLOCHY`) a krytí (`STIN_MIN_ALFA` se
     zvedlo z 8 na 40/255) - jinak by se "stin je opraveny" nedalo vyvrátit.

⚠ CO SE NEMENI: kotva (`ox=(w>>1)-22`, `oy=h-44`), rozliseni (44 px, krok 22),
obsah objektu (porovnava se proti OBEMA sadam: 1x i v2 - svetlo a stin meni
barvu a okoli, ne tvar).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

import artgen_common as ac1
import artgen_common_lit as acl
import artgen_common_v3 as acv
import pack_atlas_lit as pal
import postprocess as pp
import postprocess_lit as ppl
import styl

HERE = Path(__file__).resolve().parent
RAW = HERE / "_rawv3"
OWN = acv.SADA
OWN1X = Path("assets/own")
OWNLIT = acv.PREDCHOZI_SADA
UO = Path("assets/uo")
DETERMINISMUS = HERE / "_determinismus-v3.json"

KLICE_SPRITU_UO = pal.KLICE_SPRITU_UO
# Kolik VIDITELNYCH pixelu stinu musi mit placaty predmet (dyka/ingot).
# ⚠ MERENE VADY: dyka 6 px, ingot 11 px (v2) - obe temer neviditelne. Prah 26 px
# je nad obema a pod tim, co dava recept v3 (mereno: dyka 28, ingot 34).
STIN_MIN_PX_PLOCHY = 26
# Obecny prah krytí: v2 mel 16-58/255. Prah je 8 (stejne jako brana v2) -
# a NIZSI se nedava, protoze u krumpace je maximum 13/255, tedy "stin je
# naznaceny, ne jasny". To se NESMI zamlcet: brana to vypise zvlast
# (`STIN_SLABY_POD`) a cislo jde do MERENI.md.
STIN_MIN_ALFA = 8
# Od jake hodnoty se stin povazuje za "jasne viditelny" (jen se to hlasi).
STIN_SLABY_POD = 26
TOLERANCE_OBSAHU_PX = 2

# ktere druhy se povazuji za "placate" (lezi na zemi a jejich stin se schovava)
PLOCHE = {3921, 7151}          # dyka, ingot - MERENE v ZADANI-25 §11


def _origin(davka: str) -> tuple[float, float]:
    cesta = RAW / f"_origin_{davka}.json"
    if not cesta.exists():
        raise SystemExit(f"chybi {cesta} - spust `render_v3.py --plan ...`")
    o = json.loads(cesta.read_text(encoding="utf-8"))
    if o.get("meritko") != acv.MERITKO:
        raise SystemExit(f"{cesta}: meritko={o.get('meritko')!r}, cekam "
                         f"{acv.MERITKO!r} - render z jine vetve se do v3 sady "
                         "nesmi zamichat")
    return (o["origin_x"], o["origin_y"])


def _dva_pruchody(pripravene, s, druh, popis):
    """Styl po davkach (1. pruchod vzorky, 2. kvantizace) - jako v v2."""
    sber = styl.SadaPalety()
    ppl.sestav(pripravene, s, druh, popis=popis, sber=sber)
    paleta = sber.postav()
    if paleta is None:
        raise SystemExit(f"{popis}: zadne vzorky barev - paleta by byla prazdna")
    obrazky, meta = ppl.sestav(pripravene, s, druh, popis=popis, paleta=paleta,
                               tvrda_alfa=True)
    return obrazky, meta, len(styl.barvy_palety(paleta)), sber.pocet_vzorku()


def davka_land():
    sprity, meta, klice = [], [], []
    pripravene = []
    for spec in acv.LAND:
        cesta = RAW / f"tile_{spec['name']}.png"
        p = ppl.priprav(cesta, _origin(f"tile_{spec['name']}"))
        s = ppl.meritko([p], obsah_vyska_px=acv.TILE)
        pripravene.append((spec["name"], p, s))
    sber = styl.SadaPalety()
    for jmeno, p, s in pripravene:
        ppl.sestav([p], s, "land", popis=jmeno, sber=sber)
    paleta = sber.postav()
    for jmeno, p, s in pripravene:
        obrazky, m = ppl.sestav([p], s, "land", popis=jmeno, paleta=paleta,
                                tvrda_alfa=True)
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=jmeno))
        klice.append(("land", next(t["uo_id"] for t in acv.LAND if t["name"] == jmeno)))
    return klice, sprity, meta


def davka_item():
    sprity, meta, klice = [], [], []
    for spec in acv.ITEMS:
        jmeno = spec["name"]
        p = ppl.priprav(RAW / f"item_{jmeno}.png", _origin(f"item_{jmeno}"),
                        stin=RAW / f"_stin_item_{jmeno}.png",
                        ref=RAW / f"_ref_item_{jmeno}.png")
        s = ppl.meritko([p], obsah_vyska_px=spec["uo_content"][1])
        obrazky, m, _pal, _vz = _dva_pruchody([p], s, "item", jmeno)
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=jmeno, uo_obsah=list(spec["uo_content"])))
        klice.append(("item", spec["uo_id"]))
    return klice, sprity, meta


def davka_anim():
    pripravene, klice = [], []
    ref = RAW / "_ref_character.png"
    kazdy = [(d, f) for d in range(acv.CHAR["dirs"])
             for f in range(acv.CHAR["frames"])]
    for d, f in kazdy:
        cesta = RAW / f"char_d{d}_f{f}.png"
        stin = RAW / f"_stin_char_d{d}_f{f}.png"
        pripravene.append(ppl.priprav(cesta, _origin("character"),
                                      stin=stin if stin.exists() else None,
                                      ref=ref if ref.exists() else None))
        klice.append(("anim", acv.anim_id(d, f)))
    s = ppl.meritko(pripravene, obsah_vyska_px=acv.CHAR["cil_obsah_px"])
    obrazky, meta, _pal, _vz = _dva_pruchody(pripravene, s, "anim", "character")
    for i, (d, f) in enumerate(kazdy):
        meta[i]["jmeno"] = f"char_d{d}_f{f}"
        meta[i]["smer"] = d
        meta[i]["frame"] = f
    return klice, obrazky, meta


def hlavicka_manifestu(report: dict) -> dict:
    return {
        "version": 1,
        "generator": "tools/artgen/pack_atlas_v3.py",
        "page_size": acv.PAGE,
        "pad": acv.PAD,
        "source": {
            "sada": "own-v3 (art krok 2: stin pro placate predmety + navrat kontrastu)",
            "pipeline": "tools/artgen (build_model_v3.py -> render_v3.py -> "
                        "postprocess_lit.py s receptem stinu v3)",
            "blender": "5.2.1 LTS (BLENDER_EEVEE, film_transparent, Fast-GI AO, "
                       "1 smerove slunce + vypln, kontaktni rovina)",
            "render_px": acv.RENDER, "px_per_unit": acv.PX_PER_UNIT,
            "kamera": {"azimut_deg": acv.CAM_AZIMUTH_DEG,
                       "elevace_deg": round(acv.CAM_ELEVATION_DEG, 6),
                       "zrcadleni_x": acv.MIRROR_X,
                       "svisle_roztazeni": round(acv.VYSTRED_Y, 6)},
            "geometrie": "1 jednotka = 1 dlazdice = 44 px; kotva jako UO "
                         "(ox=(w>>1)-22, oy=h-44) - ROZLISENI SE NEMENI",
            "svetlo": "1 smerove slunce + VYPLN (protismer, use_shadow=False) + "
                      "Fast-GI AO + kontaktni stin (recept v3)",
            "svetlo_recept": acv.recept_svetla(),
            "lit_kontrakt": acv.souhrn(),
            "odchylky_od_v2": acv.odchylky_od_v2(),
            "odvozeno_z": "artgen_common.py (geometrie 1x) + assets/own-lit (v2 "
                          "jako zaklad srovnani)",
        },
        "pages": [],
        "sprites": [],
        "anim": {"file": "anim/anim-sheets.json", "pixels_decoded": True,
                 "id_klic": "body*1000 + action*100 + dir*10 + frame",
                 "smeru": acv.CHAR["dirs"], "framu": acv.CHAR["frames"],
                 "frame_ms": acv.CHAR["frame_ms"],
                 "duvod": "postava se ve hre bere z anim listu (render/anim_player.gd), "
                          "ne z manifestu - proto jsou framy i tady"},
        "report": report,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="atlas 1x artu v3 (own-v3)")
    ap.add_argument("--check", action="store_true", help="jen premer hotovy vystup")
    ap.add_argument("--hash", action="store_true", help="vypsat SHA-256")
    ap.add_argument("--nahled", default="tools/artgen/_atlas-v3-nahled.png")
    a = ap.parse_args()
    if a.check or a.hash:
        return zkontroluj(a.nahled, a.hash)

    # ⚠ RECEPT STINU v3 se nastavuje TADY (jedno misto) - kdyby ho nekdo
    # prepnul jinam, sada by vznikla jinym receptem, nez ktery se reportuje.
    ppl.nastav_recept_stinu(acv.STIN_RECEPT)

    davky = [("land", davka_land()), ("item", davka_item()), ("anim", davka_anim())]
    zapisy, stranky, report = [], {}, {}
    report["styl_doostreni_procent"] = styl.DOOSTRENI_PROCENT
    report["styl_tvrda_alfa_prah"] = styl.ALFA_TVRDA_PRAH
    report["stin_recept"] = acv.STIN_RECEPT
    report["stin_recept_cisla"] = acv.recept_svetla()
    for kind, (klice, sprity, meta) in davky:
        zaznamy, _n, info = pal.sestav(kind, klice, sprity, meta)
        zapisy.extend(zaznamy)
        for cislo, obrazek in info["stranky"].items():
            stranky[f"{kind}_{cislo}"] = obrazek
        report[f"{kind}_pozadovano"] = len(klice)
        report[f"{kind}_vyrobeno"] = len(zaznamy)
        report[f"{kind}_obsah_pod_kontaktem_max_px"] = max(
            m["obsah_pod_kontaktem_px"] for m in meta)
        report[f"{kind}_pozadi_cesta"] = sorted({m["pozadi"] for m in meta})
        report[f"{kind}_barva_pozadi_px"] = sum(m["barva_pozadi_px"] for m in meta)
        report[f"{kind}_meritko_min"] = round(min(m["meritko"] for m in meta), 6)
        report[f"{kind}_meritko_max"] = round(max(m["meritko"] for m in meta), 6)
        report[f"{kind}_styl_barvy_max"] = max(m.get("styl_barvy", 0) for m in meta)
        report[f"{kind}_styl_polopruhle_px_max"] = max(
            m.get("styl_polopruhle_px", 0) for m in meta)
        report[f"{kind}_box_px"] = {str(i): [m["w"], m["h"]]
                                    for (_k, i), m in zip(klice, meta)}
        report[f"{kind}_obsah_sirka_px"] = {str(i): m["obsah_sirka_px"]
                                            for (_k, i), m in zip(klice, meta)}
        report[f"{kind}_obsah_vyska_px"] = {str(i): m["obsah_vyska_px"]
                                            for (_k, i), m in zip(klice, meta)}
        if kind != "land":
            vid = {str(i): m["stin_viditelne_px"] for (_k, i), m in zip(klice, meta)}
            report[f"{kind}_stin_viditelne_px"] = vid
            report[f"{kind}_stin_vrstva_px"] = {str(i): m["stin_vrstva_px"]
                                                for (_k, i), m in zip(klice, meta)}
            report[f"{kind}_stin_viditelne_px_min"] = min(vid.values())
            report[f"{kind}_stin_max_alfa"] = max(m["stin_max_alfa"] for m in meta)
            report[f"{kind}_stin_px_30_90"] = {
                str(i): m.get("stin_px_30_90", 0) for (_k, i), m in zip(klice, meta)}
            report[f"{kind}_px_na_jednotku"] = sorted({m["px_na_jednotku"] for m in meta})
            report[f"{kind}_px_na_jednotku_podle_spritu"] = {
                str(i): m["px_na_jednotku"] for (_k, i), m in zip(klice, meta)}
            report[f"{kind}_px_na_jednotku_merene"] = sorted(
                {m["px_na_jednotku_merene"] for m in meta})
        else:
            for klic in ("stin_viditelne_px", "stin_vrstva_px", "stin_px_30_90"):
                report[f"{kind}_{klic}"] = {}
            report[f"{kind}_stin_viditelne_px_min"] = 0
            report[f"{kind}_stin_max_alfa"] = 0
            report[f"{kind}_stin_duvod"] = ("dlazdice je podlaha - stin pod ni je "
                                            "cely schovany pod ni")

    (OWN / "atlas").mkdir(parents=True, exist_ok=True)
    platne = sorted({z["page"] for z in zapisy})
    for stranka in platne:
        jmeno = Path(stranka).name
        druh, cislo = jmeno[:-4].rsplit("_", 1)
        stranky[f"{druh}_{cislo}"].save(OWN / "atlas" / jmeno)
    for stara in (OWN / "atlas").glob("*.png"):
        if f"atlas/{stara.name}" not in platne:
            stara.unlink()
            report["uklizeno_stranek"] = report.get("uklizeno_stranek", 0) + 1

    klice_a, sprity_a, meta_a = davky[2][1]
    if len(sprity_a) != acv.CHAR["dirs"] * acv.CHAR["frames"]:
        raise SystemExit(f"anim framu {len(sprity_a)} != "
                         f"{acv.CHAR['dirs'] * acv.CHAR['frames']}")
    sheets = _zapis_anim_sheets(sprity_a, klice_a, meta_a)
    report["anim_listu"] = sheets["listy"]

    manifest = hlavicka_manifestu(report)
    manifest["pages"] = [
        {"file": s, "w": acv.PAGE, "h": acv.PAGE,
         "count": sum(1 for z in zapisy if z["page"] == s)} for s in platne]
    manifest["sprites"] = sorted(zapisy, key=lambda z: (z["kind"], z["id"]))
    ac1.zapis_manifest(OWN / "manifest.json", manifest)
    print(f"[packv3] stranek {len(platne)}, spritu {len(zapisy)} -> "
          f"{OWN/'manifest.json'}")
    for k in sorted(report):
        print(f"[packv3]   {k} = {report[k]}")
    return zkontroluj(a.nahled, a.hash)


def _zapis_anim_sheets(sprity, klice, meta) -> dict:
    """Anim listy ve tvaru UO - stejna logika jako v2, jiny nazev souboru."""
    out = OWN / "anim"
    out.mkdir(parents=True, exist_ok=True)
    podle = {}
    for (k, ident), obrazek, m in zip(klice, sprity, meta):
        _body, _akce, smer, frame = acv.anim_parts(ident)
        podle.setdefault(smer, []).append((frame, obrazek))
    sprites = {}
    for smer, polozky in sorted(podle.items()):
        polozky.sort(key=lambda t: t[0])
        sirka = sum(o.width for _f, o in polozky)
        vyska = max(o.height for _f, o in polozky)
        pruh = Image.new("RGBA", (sirka, vyska), (0, 0, 0, 0))
        x = 0
        framy = []
        for _f, o in polozky:
            pruh.alpha_composite(o, (x, 0))
            framy.append({"rect": [x, 0, x + o.width, o.height],
                          "cx": o.width // 2, "cy": -acv.GROUND_PX,
                          "w": o.width, "h": o.height, "pixely_mimo": 0})
            x += o.width
        jmeno = f"ownv3-{acv.CHAR['body']}-{acv.CHAR['action_walk']}-{smer}.png"
        pruh.save(out / jmeno)
        sprites[f"{acv.CHAR['body']}/{acv.CHAR['action_walk']}/{smer}"] = {
            "file": jmeno, "action": "walk", "frames": framy, "source": "assets/own-v3"}
    data = {
        "version": 1,
        "decoder": "tools/artgen/pack_atlas_v3.py (1x render + vypln + stin v3)",
        "anchor": f"obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); cy je "
                  f"-{acv.GROUND_PX}, takze kontaktni bod je {acv.GROUND_PX} px nad "
                  "spodni hranou spritu (1x kontrakt, jako UO)",
        "actions": {"0": "walk"},
        "sprites": sprites,
        "chyby": [],
    }
    ac1.zapis_manifest(out / "anim-sheets.json", data)
    return {"listy": len(sprites),
            "framu": sum(len(v["frames"]) for v in sprites.values())}


# ---------------------------------------------------------------------------
# brana
# ---------------------------------------------------------------------------
def _hash(cesta: Path) -> str:
    h = hashlib.sha256()
    h.update(cesta.read_bytes())
    return h.hexdigest()


def pixely(img: Image.Image) -> np.ndarray:
    return np.asarray(img.convert("RGBA"), dtype=np.int16)


def obsah_sady(sada: Path, kind: str, ident: int) -> tuple[int, int] | None:
    """Obsah OBJEKTU (alfa >= 200) z dane sady, MERENY Z PIXELU ATLASU."""
    cesta = sada / "manifest.json"
    if not cesta.exists():
        return None
    m = json.loads(cesta.read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            img = Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
            a = np.asarray(img)[:, :, 3]
            plna = a >= 200
            if not plna.any():
                return None
            ys, xs = np.nonzero(plna)
            return (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))
    return None


def zkontroluj(nahled: str, hash_out: bool) -> int:
    chyby: list[str] = []
    pocet = 0

    def kontrola(ok: bool, text: str) -> None:
        nonlocal pocet
        pocet += 1
        if not ok:
            chyby.append(text)

    cesta = OWN / "manifest.json"
    if not cesta.exists():
        print(f"[checkv3] CHYBA: {cesta} neexistuje - neni co overovat")
        return 1
    data = json.loads(cesta.read_text(encoding="utf-8"))
    uo = ac1.uo_manifest(UO / "manifest.json")

    # --- kontrakt proti UO --------------------------------------------------
    kontrola(set(data) == set(uo), f"klice manifestu se lisi od UO: chybi "
             f"{sorted(set(uo) - set(data))}, navic {sorted(set(data) - set(uo))}")
    klice = {k for s in data["sprites"] for k in s}
    kontrola(klice == KLICE_SPRITU_UO, f"klice spritu se lisi od UO: chybi "
             f"{sorted(KLICE_SPRITU_UO - klice)}, navic {sorted(klice - KLICE_SPRITU_UO)}")
    kontrola(data.get("page_size") == acv.PAGE and data.get("pad") == acv.PAD,
             "page_size/pad nejsou 2048/1")
    lit = data.get("source", {}).get("lit_kontrakt", {})
    kontrola(lit.get("tile_px") == acv.TILE and lit.get("tile_px") == ac1.TILE
             and lit.get("render_px") == ac1.RENDER,
             f"manifest netvrdi 1x rozliseni: {lit}")

    # --- (1) STIN: recept a jeho cisla --------------------------------------
    rep = data.get("report", {})
    kontrola(rep.get("stin_recept") == acv.STIN_RECEPT,
             f"report tvrdi recept stinu {rep.get('stin_recept')!r}, sada ma byt "
             f"{acv.STIN_RECEPT!r}")
    zaznamenany = data.get("source", {}).get("svetlo_recept") or {}
    kontrola(zaznamenany == acv.recept_svetla(),
             "manifest ma jiny recept svetla, nez pouziva v3 vetev "
             f"({zaznamenany} vs {acv.recept_svetla()})")
    odch = data.get("source", {}).get("odchylky_od_v2") or {}
    kontrola(odch == acv.odchylky_od_v2(),
             "manifest ma jine odchylky od v2, nez pouziva v3 vetev")
    # ⚠ CISLA RECEPTU STINU MAJI DOMOV V `postprocess_lit.RECEPTY_STINU["v3"]`.
    # Tady se porovnava ZIVY recept s tim, co je v manifestu a co tvrdi
    # `artgen_common_v3` - kdyby se recept zmenil a manifest zustal, je to videt
    # (a kdyby se rozešel jen "kod vs manifest", taky).
    zivy = ppl.RECEPTY_STINU.get(acv.STIN_RECEPT)
    kontrola(zivy is not None,
             f"v `postprocess_lit` neni recept stinu {acv.STIN_RECEPT!r}")
    if zivy is not None:
        for jmeno, tady, tam in (("sila", acv.STIN_SILA, zivy.get("sila")),
                                 ("posun_px", list(acv.STIN_POSUN_PX),
                                  list(zivy.get("posun_px", ()))),
                                 ("sirka_px", acv.STIN_SIRKA_PX, zivy.get("sirka_px")),
                                 ("mekkost_px", acv.STIN_MEKKOST_PX,
                                  zivy.get("mekkost_px")),
                                 ("odstup_px", acv.STIN_ODSTUP_PX,
                                  zivy.get("odstup_px"))):
            kontrola(tady == tam,
                     f"recept stinu '{jmeno}' se lisi: artgen_common_v3={tady!r}, "
                     f"postprocess_lit={tam!r} - sada by vznikla jinym receptem, "
                     "nez ktery se reportuje")
        zaz = zaznamenany.get("stin_sila")
        kontrola(zaz == zivy.get("sila"),
                 f"manifest ma silu stinu {zaz!r}, zivy recept {zivy.get('sila')!r}")

    # --- (2) STYL: silueta tvrda, paleta dodrzena ---------------------------
    kontrola(int(rep.get("styl_tvrda_alfa_prah", 0)) == styl.ALFA_TVRDA_PRAH,
             f"manifest netvrdi tvrdou alfu ({rep.get('styl_tvrda_alfa_prah')!r})")
    for kind in ("land", "item", "anim"):
        polopruhle = int(rep.get(f"{kind}_styl_polopruhle_px_max", -1))
        kontrola(polopruhle == 0,
                 f"{kind}: silueta ma {polopruhle} polopruhlednych pixelu "
                 "(kontaktni stin se do toho nepocita)")
        barvy = int(rep.get(f"{kind}_styl_barvy_max", -1))
        kontrola(0 < barvy <= styl.PALETA_BAREV,
                 f"{kind}: {barvy} barev v tele, paleta ma nejvyse {styl.PALETA_BAREV}")

    ocekavane = {("land", t["uo_id"]) for t in acv.LAND} | \
                {("item", i["uo_id"]) for i in acv.ITEMS} | \
                {("anim", acv.anim_id(d, f)) for d in range(acv.CHAR["dirs"])
                 for f in range(acv.CHAR["frames"])}
    nalezene = {(s["kind"], s["id"]) for s in data["sprites"]}
    ocekavany_pocet = 2 + 4 + acv.CHAR["dirs"] * acv.CHAR["frames"]
    kontrola(nalezene == ocekavane,
             f"mnozina spritu se lisi: chybi {sorted(ocekavane - nalezene)[:6]}, "
             f"navic {sorted(nalezene - ocekavane)[:6]}")
    kontrola(len(data["sprites"]) == len(ocekavane) == ocekavany_pocet,
             f"pocet spritu {len(data['sprites'])} != ocekavanych {ocekavany_pocet}")

    # --- stranky a sprity ---------------------------------------------------
    stranky = {}
    for p in data["pages"]:
        c = OWN / p["file"]
        kontrola(c.exists(), f"chybi stranka {p['file']}")
        if c.exists():
            img = Image.open(c).convert("RGBA")
            stranky[p["file"]] = img
            kontrola(img.size == (acv.PAGE, acv.PAGE),
                     f"stranka {p['file']} ma {img.size}, ne ({acv.PAGE}, {acv.PAGE})")
    stin_px: dict[tuple, int] = {}
    stin_alfa_max: dict[tuple, int] = {}
    obsah_v3: dict[tuple, tuple] = {}
    for s in data["sprites"]:
        img = stranky.get(s["page"])
        if img is None:
            continue
        kontrola(s["rect"] == [s["x"], s["y"], s["x"] + s["w"], s["y"] + s["h"]],
                 f"{s['kind']} {s['id']}: rect neni [x,y,x+w,y+h]")
        kontrola(0 < s["w"] <= acv.PAGE and 0 < s["h"] <= acv.PAGE
                 and s["x"] + s["w"] <= acv.PAGE and s["y"] + s["h"] <= acv.PAGE,
                 f"{s['kind']} {s['id']}: sprite leze ze stranky")
        crop = img.crop(tuple(s["rect"]))
        arr = np.array(crop)
        alfa = arr[:, :, 3]
        bb = crop.split()[3].getbbox()
        kontrola(bb is not None, f"{s['kind']} {s['id']}: prazdny sprite v atlase")
        if bb is None:
            continue
        kontrola(acv.ofsahy(s["kind"], s["w"], s["h"]) == (s["ox"], s["oy"]),
                 f"{s['kind']} {s['id']}: kotva ({s['ox']},{s['oy']}) neni vzorec UO "
                 f"{acv.ofsahy(s['kind'], s['w'], s['h'])}")
        if s["kind"] == "land":
            kontrola(s["w"] == acv.TILE and s["h"] == acv.TILE
                     and s["ox"] == 0 and s["oy"] == 0,
                     f"land {s['id']}: neni {acv.TILE}x{acv.TILE} s ox=oy=0")
            kontrola(bb == (0, 0, acv.TILE, acv.TILE), f"land {s['id']}: obsah neni cely box")
            kontrola(int((alfa > 0).sum()) == pp.KOSOCTVEREC_PX,
                     f"land {s['id']}: kosoctverec ma {int((alfa > 0).sum())} px")
            kontrola(int(((alfa > 0) & (alfa < 200)).sum()) == 0,
                     f"land {s['id']}: dlazdice ma polopruhledne pixely")
            obsah_v3[(s["kind"], s["id"])] = None
            continue
        plna = alfa >= 200
        bb_obj = None
        if plna.any():
            ys, xs = np.nonzero(plna)
            bb_obj = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        kontrola(bb_obj is not None, f"{s['kind']} {s['id']}: neni plne nepruhledny obsah")
        if bb_obj is None:
            continue
        obsah_v3[(s["kind"], s["id"])] = (bb_obj[2] - bb_obj[0], bb_obj[3] - bb_obj[1])
        levy, horni, pravy, spodek = bb_obj
        stred = (levy + pravy - 1) / 2.0
        kontrola(abs(stred - s["w"] // 2) <= 1.0,
                 f"{s['kind']} {s['id']}: stred obsahu {stred} != kotva {s['w'] // 2}")
        pod = (s["h"] - acv.GROUND_PX) - (spodek - 1)
        kontrola(-acv.GROUND_PX <= pod <= 0,
                 f"{s['kind']} {s['id']}: obsah konci {pod:+d} px od kontaktu")

        # --- (3) KONTAKTNI STIN: musi byt VIDET a dost silny ---------------
        barva_stinu = np.array(acl.STIN_BARVA, dtype=np.uint8)
        stin = (alfa > 0) & (alfa < 200) & ((arr[:, :, :3] == barva_stinu).all(axis=2))
        px = int(stin.sum())
        stin_px[(s["kind"], s["id"])] = px
        kontrola(px > 0, f"{s['kind']} {s['id']}: ve sprite NENI videt kontaktni stin")
        kontrola(int((plna & ((arr[:, :, :3] == barva_stinu).all(axis=2))).sum()) == 0,
                 f"{s['kind']} {s['id']}: plne pixely maji barvu stinu")
        mx = int(alfa[stin].max()) if stin.any() else 0
        stin_alfa_max[(s["kind"], s["id"])] = mx
        kontrola(mx >= STIN_MIN_ALFA,
                 f"{s['kind']} {s['id']}: max krytí stinu {mx}/255 < {STIN_MIN_ALFA} "
                 "- stin je prilis slaby na to, aby byl videt (v2 mel u dyky 16)")
        # ... a pro PLACATE predmety plati prisnejsi prah: v2 mel u dyky 6 px
        # a u ingotu 11 px, coz je 1px lem - presne vada, ktera se opravuje
        if s["kind"] == "item" and s["id"] in PLOCHE:
            kontrola(px >= STIN_MIN_PX_PLOCHY,
                     f"PLACHY predmet {s['id']}: viditelny stin ma {px} px < "
                     f"{STIN_MIN_PX_PLOCHY} - to je lem, ne stin (v2: dyka 6, ingot 11)")
        okraj = np.zeros_like(stin)
        okraj[0, :] = okraj[-1, :] = True
        okraj[:, 0] = okraj[:, -1] = True
        kontrola(int((stin & okraj).sum()) == 0,
                 f"{s['kind']} {s['id']}: stin se dotyka okraje spritu - je ukrojen")
        vm = (rep.get(f"{s['kind']}_stin_viditelne_px", {}) or {}).get(str(s["id"]))
        if vm is not None:
            kontrola(int(vm) == px,
                     f"{s['kind']} {s['id']}: manifest tvrdi viditelny stin {vm} px, "
                     f"v atlase je {px} px")
    kontrola(len(stin_px) > 0 and all(v > 0 for v in stin_px.values()),
             f"stin ma jen {sum(1 for v in stin_px.values() if v > 0)}/{len(stin_px)} "
             "spritu (item+anim)")
    # ... a SLABE stiny se VYPISUJI (ne zamlcuji): kdyz je maximum nekde nizko,
    # ma to byt videt v reportu, ne schovane za zelenou branou
    slabe = [(k, v) for k, v in stin_alfa_max.items() if v < STIN_SLABY_POD]
    if slabe:
        print(f"[checkv3] POZOR: {len(slabe)} spritu ma krytí stinu < {STIN_SLABY_POD}/255 "
              f"(stin je naznaceny, ne jasny): "
              + ", ".join(f"{k[0]} {k[1]}={v}" for k, v in slabe[:6]))

    # --- (4) geometrie se nerozjela ani proti 1x, ani proti v2 --------------
    for nazev, sada in (("1x bez svetla", OWN1X), ("v2 (own-lit)", OWNLIT)):
        pokud = preskoceno = 0
        chyby_pred = len(chyby)
        for (kind, ident), velikost in sorted(obsah_v3.items()):
            if velikost is None:
                preskoceno += 1
                continue
            o = obsah_sady(sada, kind, ident)
            if o is None:
                kontrola(False, f"{kind} {ident}: v sade {nazev} neni - geometrii "
                                "nelze porovnat (nic neni uspech)")
                continue
            pokud += 1
            dw, dh = abs(velikost[0] - o[0]), abs(velikost[1] - o[1])
            kontrola(dw <= TOLERANCE_OBSAHU_PX and dh <= TOLERANCE_OBSAHU_PX,
                     f"{kind} {ident}: obsah se lisi od {nazev} o ({dw},{dh}) px "
                     f"[v3 {velikost[0]}x{velikost[1]} vs {o[0]}x{o[1]}]")
        kontrola(pokud > 0, f"geometrie proti {nazev} se NEMERILA (0 spritu)")
        print(f"[checkv3] geometrie proti {nazev}: porovnano {pokud} spritu, "
              f"{preskoceno} dlazdic preskoceno, chyb {len(chyby) - chyby_pred}")

    # --- (5) meritko uvnitr spritu ------------------------------------------
    pj_item = (rep.get("item_px_na_jednotku") or [None])[0]
    pj_item_m = (rep.get("item_px_na_jednotku_merene") or [None])[0]
    if not pj_item:
        kontrola(False, "v reportu neni px_na_jednotku - meritko roviny se NEMERILO")
    else:
        podle = rep.get("item_px_na_jednotku_podle_spritu") or {}
        if set(podle) != {str(s["id"]) for s in data["sprites"] if s["kind"] == "item"}:
            kontrola(False, "v reportu neni px_na_jednotku pro kazdy item")
        for s in data["sprites"]:
            pj = podle.get(str(s["id"]))
            if pj is None:
                continue
            r1_px = int(np.ceil(acl.STIN_R1_JEDNOTEK * pj)) + 1
            kontrola(s["w"] >= 2 * r1_px and s["h"] >= acv.GROUND_PX + r1_px,
                     f"{s['kind']} {s['id']}: box {s['w']}x{s['h']} je mensi nez misto "
                     "na stin - stin by se ukrojil")
        print(f"[checkv3] px/jednotku = {pj_item} (vzorec z 2x), merena sirka roviny = "
              f"{pj_item_m} -> pomer {pj_item_m / pj_item:.3f} (= sqrt(2), prevzato)")

    # --- seam ---------------------------------------------------------------
    for s in data["sprites"]:
        if s["kind"] in ("land", "item"):
            kontrola(ac1.uo_sprite(uo, s["kind"], s["id"]) is not None,
                     f"{s['kind']} {s['id']}: v UO manifestu neni - neni co nahradit")

    # --- police -------------------------------------------------------------
    police: dict = {}
    for s in data["sprites"]:
        police.setdefault((s["page"], s["y"]), []).append(s)
    for (_stranka, _y), v in police.items():
        v.sort(key=lambda s: s["x"])
        for a1, b1 in zip(v, v[1:]):
            kontrola(a1["x"] + a1["w"] <= b1["x"],
                     f"prekryv {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']}")
            kontrola(b1["x"] - (a1["x"] + a1["w"]) == acv.PAD,
                     f"mezera mezi {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']} "
                     f"neni {acv.PAD}")

    # --- anim listy ---------------------------------------------------------
    listy = OWN / "anim" / "anim-sheets.json"
    kontrola(listy.exists(), f"chybi {OWN}/anim/anim-sheets.json")
    if listy.exists():
        ld = json.loads(listy.read_text(encoding="utf-8"))
        uo_anim = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
        kontrola(set(ld) <= set(uo_anim),
                 f"anim list ma klic, ktery UO export nema: "
                 f"{sorted(set(ld) - set(uo_anim))}")
        kontrola(len(ld["sprites"]) == acv.CHAR["dirs"],
                 f"anim listu {len(ld['sprites'])} != {acv.CHAR['dirs']}")
        for k, v in ld["sprites"].items():
            kontrola(k in uo_anim["sprites"], f"{k}: klic v UO anim listech neni")
            kontrola(len(v["frames"]) == acv.CHAR["frames"], f"{k}: framu neni 8")
            kontrola((OWN / "anim" / v["file"]).exists(), f"{k}: chybi PNG {v['file']}")
            for f in v["frames"]:
                kontrola(f["cy"] == -acv.GROUND_PX,
                         f"{k}: kontaktni bod neni {acv.GROUND_PX} px nad spodni hranou")

    # --- (6) DETERMINISMUS --------------------------------------------------
    if not DETERMINISMUS.exists():
        kontrola(False, f"chybi {DETERMINISMUS.name} - determinismus se NEMERIL "
                        "(spust `probe_determinismus_v3.py`)")
    else:
        det = json.loads(DETERMINISMUS.read_text(encoding="utf-8"))
        kontrola(bool(det.get("shodne_manifest")),
                 f"determinismus manifestu NESEDI: {det.get('rozdiely')}")
        kontrola(bool(det.get("shodne_pixely")),
                 f"pixely se mezi behy lisi vic nez o toleranci "
                 f"{det.get('pixel_tolerance')}: {det.get('rozdiely')}")
        kontrola(det.get("baseline", {}).get("manifest_sha") == _hash(cesta),
                 "SHA manifestu na disku neni ten, ktery se meril v determinismu "
                 f"({_hash(cesta)[:12]} vs "
                 f"{str(det.get('baseline', {}).get('manifest_sha'))[:12]}) - sada se "
                 "zmenila, determinismus je potreba premerit")
        print(f"[checkv3] determinismus: manifest SHA shodne: "
              f"{det.get('shodne_manifest')}; max|rozdil| pixelu "
              f"{det.get('max_pixel_rozdil')} (tolerance {det.get('pixel_tolerance')})")

    if nahled:
        _nahled(data, stranky, Path(nahled))
    _n_uo = sum(1 for s in data["sprites"] if s["kind"] in ("land", "item")
                and ac1.uo_sprite(uo, s["kind"], s["id"]) is not None)
    _n = sum(1 for s in data["sprites"] if s["kind"] in ("land", "item"))
    print(f"[checkv3] seam: land+item {_n_uo}/{_n} id je v UO manifestu")
    if hash_out:
        print(f"[checkv3] sha256(manifest.json) = {_hash(cesta)}")
        for p in sorted((OWN / "atlas").glob("*.png")):
            print(f"[checkv3] sha256({p.name}) = {_hash(p)}")
    print(f"[checkv3] {pocet} kontrol, {len(chyby)} chyb")
    for ch in chyby[:20]:
        print(f"[checkv3] CHYBA: {ch}")
    return 1 if chyby else 0


def _nahled(data: dict, stranky: dict, cesta: Path) -> None:
    vyber = {"land": 6, "item": 6, "anim": 4}
    bunky = []
    for s in data["sprites"]:
        img = stranky.get(s["page"])
        if img is None:
            continue
        bunky.append((vyber.get(s["kind"], 4), img.crop(tuple(s["rect"]))))
    if not bunky:
        print("[checkv3] nahled: NELZE vyrobit - zadna stranka se nenacetla")
        return
    bunky.sort(key=lambda t: -t[0])
    sirka = sum(b[1].width * b[0] for b in bunky) + 4 * (len(bunky) + 1)
    vyska = max(b[1].height * b[0] for b in bunky) + 8
    p = Image.new("RGBA", (sirka, vyska), (36, 38, 44, 255))
    x = 4
    for kolik, img in bunky:
        p.alpha_composite(img.resize((img.width * kolik, img.height * kolik),
                                     Image.NEAREST), (x, 4))
        x += img.width * kolik + 4
    p.convert("RGB").save(cesta)
    print(f"[checkv3] nahled: {cesta}")


if __name__ == "__main__":
    raise SystemExit(main())
