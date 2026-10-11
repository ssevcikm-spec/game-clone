# -*- coding: utf-8 -*-
"""pack_atlas_lit.py - slozi 1x sprity SE SVETLEM do `assets/own-lit/` (a brana).

  python tools/artgen/pack_atlas_lit.py            # z `_rawlit/` do `assets/own-lit/`
  python tools/artgen/pack_atlas_lit.py --check    # premer hotovy vystup (nic nezapisuje)
  python tools/artgen/pack_atlas_lit.py --check --hash   # + SHA-256 pro determinismus
  python tools/artgen/pack_atlas_lit.py --tabulka-raw    # merene hodnoty z renderu

Vystup je VE STEJNEM TVARU jako `assets/own/` (a tedy i `assets/uo/`):
  assets/own-lit/manifest.json         - klice `id,kind,page,x,y,w,h,ox,oy,rect`
  assets/own-lit/atlas/<kind>_<n>.png  - stranky 2048^2, pad 1
  assets/own-lit/anim/anim-sheets.json - 40 framu chuze ve tvaru UO anim exportu

⚠ CO TENHLE SOUBOR NEDELA: nebere `assets/own/` a neprepisuje ho. `assets/own/`
je 1x sada BEZ svetla a zustava nedotcena (ZADANI-25 §10: je to referencni
polovina srovnani). Odsud se jen CTE - na kontrolu, ze se geometrie nerozjela.

BRANA `--check` se pta na CHOVANI, ne na pritomnost:
  * kotva kazdeho spritu = vzorec UO (`ox=(w>>1)-22`, `oy=h-44`) a stred obsahu
    je na kotve (mereno z pixelu atlasu, ne z reportu),
  * **kontaktni stin je SKUTECNE ve sprite**: (a) polopruhledne pixely vubec,
    (b) z toho pixely v kontaktnim okruhu kolem kotvy (< R1), (c) z toho pixely
    POD obrysem objektu - tedy stin na zemi, ne jen antialias hrany,
  * dlazdice stin MIT NEMA (je to podlaha) a ma presnou masku kosoctverce,
  * **geometrie se nerozjela proti 1x sade**: obsah objektu (alfa >= 200) je
    stejne velky jako v `assets/own/` (svetlo meni barvu, ne tvar),
  * **determinismus**: `_determinismus-lit.json` (dva behy) existuje, hlasi
    shodu a jeho SHA manifestu sedi na ten, ktery je na disku,
  * **recept svetla je TYZ jako v 2x vetvi** (`acl.shoda_receptu_s_2x()`),
  * seam: kazde nase (kind, id) existuje v UO manifestu / UO anim listech.
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
import postprocess as pp
import postprocess_lit as ppl

HERE = Path(__file__).resolve().parent
RAW = HERE / "_rawlit"
OWN = acl.SADA
OWN1X = Path("assets/own")
UO = Path("assets/uo")
DETERMINISMUS = HERE / "_determinismus-lit.json"

KLICE_SPRITU_UO = {"id", "kind", "page", "x", "y", "w", "h", "ox", "oy", "rect"}
# Prah, od ktereho se stin povazuje za VIDITELNY (ne sum z renderu). Recept
# zahazuje vse pod `STIN_PRAH` (6/255); 8 znamena "o chlup vic, nez co recept
# sam povazuje za sum". Namerene minimum je 18/255 (rypadlo), takze brana neni
# nastavena na hrane - a kdyby stin zmizel, spadne.
STIN_MIN_ALFA = 8
# Tolerance velikosti obsahu proti 1x sade v px (svetlo meni barvu, ne tvar;
# antialias a prah alfy mohou hnout hranici o pixel).
TOLERANCE_OBSAHU_PX = 2


# ---------------------------------------------------------------------------
# sbirani podkladu
# ---------------------------------------------------------------------------
def _origin(davka: str) -> tuple[float, float]:
    cesta = RAW / f"_origin_{davka}.json"
    if not cesta.exists():
        raise SystemExit(f"chybi {cesta} - spust `render_lit.py --plan ...`")
    o = json.loads(cesta.read_text(encoding="utf-8"))
    if o.get("meritko") != acl.MERITKO:
        raise SystemExit(f"{cesta}: meritko={o.get('meritko')!r}, cekam "
                         f"{acl.MERITKO!r} - render z jine vetve se do lit sady "
                         "nesmi zamichat")
    return (o["origin_x"], o["origin_y"])


def davka_land():
    sprity, meta, klice = [], [], []
    for spec in acl.LAND:
        cesta = RAW / f"tile_{spec['name']}.png"
        p = ppl.priprav(cesta, _origin(f"tile_{spec['name']}"))
        s = ppl.meritko([p], obsah_vyska_px=acl.TILE)
        obrazky, m = ppl.sestav([p], s, "land", popis=spec["name"])
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=spec["name"]))
        klice.append(("land", spec["uo_id"]))
    return klice, sprity, meta


def davka_item():
    sprity, meta, klice = [], [], []
    for spec in acl.ITEMS:
        jmeno = spec["name"]
        p = ppl.priprav(RAW / f"item_{jmeno}.png", _origin(f"item_{jmeno}"),
                        stin=RAW / f"_stin_item_{jmeno}.png",
                        ref=RAW / f"_ref_item_{jmeno}.png")
        s = ppl.meritko([p], obsah_vyska_px=spec["uo_content"][1])
        obrazky, m = ppl.sestav([p], s, "item", popis=jmeno)
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=jmeno, uo_obsah=list(spec["uo_content"])))
        klice.append(("item", spec["uo_id"]))
    return klice, sprity, meta


def davka_anim():
    pripravene, klice = [], []
    ref = RAW / "_ref_character.png"
    kazdy = [(d, f) for d in range(acl.CHAR["dirs"]) for f in range(acl.CHAR["frames"])]
    for d, f in kazdy:
        cesta = RAW / f"char_d{d}_f{f}.png"
        stin = RAW / f"_stin_char_d{d}_f{f}.png"
        pripravene.append(ppl.priprav(cesta, _origin("character"),
                                      stin=stin if stin.exists() else None,
                                      ref=ref if ref.exists() else None))
        klice.append(("anim", acl.anim_id(d, f)))
    s = ppl.meritko(pripravene, obsah_vyska_px=acl.CHAR["cil_obsah_px"])
    obrazky, meta = ppl.sestav(pripravene, s, "anim", popis="character")
    for i, (d, f) in enumerate(kazdy):
        meta[i]["jmeno"] = f"char_d{d}_f{f}"
        meta[i]["smer"] = d
        meta[i]["frame"] = f
    return klice, obrazky, meta


# ---------------------------------------------------------------------------
# sestaveni
# ---------------------------------------------------------------------------
def sestav(kind: str, klice, sprity, meta):
    """Rozmisti sprity po strance a vrati (zaznamy, pocet stranek, souhrn).

    ⚠ PORADI: `ac.rozloz` vraci umisteni SERAZENE podle (-h, w, kind, id),
    kdezto `sprity`/`meta` jdou v poradi zadani -> dvojice se hleda podle
    (kind, id). `zip` pres ne se ROZJEDE a do atlasu se vlozi jiny obrazek, nez
    jaky se zapise do manifestu (v pilotu se to stalo: dyka na misto rudy).
    """
    podle = {(k, i): (obr, m) for (k, i), obr, m in zip(klice, sprity, meta)}
    rady = [(k, i, obr.width, obr.height) for (k, i), (obr, _m) in podle.items()]
    umisteni = acl.rozloz(rady)
    stranky: dict[int, Image.Image] = {}
    zapisy = []
    for k, ident, cislo, x, y in umisteni:
        obrazek, _m = podle[(k, ident)]
        if cislo not in stranky:
            stranky[cislo] = Image.new("RGBA", (acl.PAGE, acl.PAGE), (0, 0, 0, 0))
        stranky[cislo].alpha_composite(obrazek, (x, y))
        ox, oy = acl.ofsahy(k, obrazek.width, obrazek.height)
        zapisy.append({
            "id": ident, "kind": k, "page": f"atlas/{k}_{cislo}.png",
            "x": x, "y": y, "w": obrazek.width, "h": obrazek.height,
            "rect": [x, y, x + obrazek.width, y + obrazek.height],
            "ox": ox, "oy": oy})
    return zapisy, len(stranky), {"stranky": stranky, "meta": meta}


def zapis_anim_sheets(sprity, klice, meta) -> dict:
    """Zapise 40 framu chuze jako listy ve tvaru UO (`anim-sheets.json`)."""
    out = OWN / "anim"
    out.mkdir(parents=True, exist_ok=True)
    podle = {}
    for (k, ident), obrazek, m in zip(klice, sprity, meta):
        _body, _akce, smer, frame = acl.anim_parts(ident)
        podle.setdefault(smer, []).append((frame, obrazek, m))
    sprites = {}
    for smer, polozky in sorted(podle.items()):
        polozky.sort(key=lambda t: t[0])
        sirka = sum(o.width for _f, o, _m in polozky)
        vyska = max(o.height for _f, o, _m in polozky)
        pruh = Image.new("RGBA", (sirka, vyska), (0, 0, 0, 0))
        x = 0
        framy = []
        for _f, o, _m in polozky:
            pruh.alpha_composite(o, (x, 0))
            framy.append({"rect": [x, 0, x + o.width, o.height],
                          "cx": o.width // 2, "cy": -acl.GROUND_PX,
                          "w": o.width, "h": o.height, "pixely_mimo": 0})
            x += o.width
        jmeno = f"ownlit-{acl.CHAR['body']}-{acl.CHAR['action_walk']}-{smer}.png"
        pruh.save(out / jmeno)
        sprites[f"{acl.CHAR['body']}/{acl.CHAR['action_walk']}/{smer}"] = {
            "file": jmeno, "action": "walk", "frames": framy, "source": "assets/own-lit"}
    data = {
        "version": 1,
        "decoder": "tools/artgen/pack_atlas_lit.py (1x render Blenderu + kontaktni stin)",
        "anchor": f"obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); cy je "
                  f"-{acl.GROUND_PX}, takze kontaktni bod je {acl.GROUND_PX} px nad "
                  "spodni hranou spritu (1x kontrakt, jako UO)",
        "actions": {"0": "walk"},
        "sprites": sprites,
        "chyby": [],
    }
    ac1.zapis_manifest(out / "anim-sheets.json", data)
    return {"listy": len(sprites),
            "framu": sum(len(v["frames"]) for v in sprites.values())}


def hlavicka_manifestu(report: dict) -> dict:
    return {
        "version": 1,
        "generator": "tools/artgen/pack_atlas_lit.py",
        "page_size": acl.PAGE,
        "pad": acl.PAD,
        "source": {
            "pipeline": "tools/artgen (build_model_lit.py -> render_lit.py -> "
                        "postprocess_lit.py)",
            "blender": "5.2.1 LTS (BLENDER_EEVEE, film_transparent, Fast-GI AO, "
                       "1 smerove slunce, kontaktni rovina)",
            "render_px": acl.RENDER, "px_per_unit": acl.PX_PER_UNIT,
            "kamera": {"azimut_deg": acl.CAM_AZIMUTH_DEG,
                       "elevace_deg": round(acl.CAM_ELEVATION_DEG, 6),
                       "zrcadleni_x": acl.MIRROR_X,
                       "svisle_roztazeni": round(acl.VYSTRED_Y, 6)},
            "geometrie": "1 jednotka = 1 dlazdice = 44 px; kotva jako UO "
                         "(ox=(w>>1)-22, oy=h-44) - ROZLISENI SE NEMENI",
            "svetlo": "jedno smerove slunce + Fast-GI AO + kontaktni stin "
                      "(renderovany z kontaktni roviny, viz postprocess_lit.py)",
            "svetlo_recept": acl.recept_svetla(),
            "lit_kontrakt": acl.souhrn(),
            "odvozeno_z": "artgen_common.py (geometrie 1x) + artgen_common_2x.py "
                          "(recept svetla)",
        },
        "pages": [],
        "sprites": [],
        "anim": {"file": "anim/anim-sheets.json", "pixels_decoded": True,
                 "id_klic": "body*1000 + action*100 + dir*10 + frame",
                 "smeru": acl.CHAR["dirs"], "framu": acl.CHAR["frames"],
                 "frame_ms": acl.CHAR["frame_ms"],
                 "duvod": "postava se ve hre bere z anim listu (render/anim_player.gd), "
                          "ne z manifestu - proto jsou framy i tady"},
        "report": report,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="atlas 1x artu se svetlem (own-lit)")
    ap.add_argument("--check", action="store_true", help="jen premer hotovy vystup")
    ap.add_argument("--hash", action="store_true", help="vypsat SHA-256 manifestu a stranek")
    ap.add_argument("--tabulka-raw", action="store_true",
                    help="vypsat merene hodnoty z renderu (nic nezapisuje)")
    ap.add_argument("--nahled", default="tools/artgen/_atlas-lit-nahled.png")
    a = ap.parse_args()

    if a.tabulka_raw:
        return tabulka_raw()
    if a.check or a.hash:
        return zkontroluj(a.nahled, a.hash)

    davky = [("land", davka_land()), ("item", davka_item()), ("anim", davka_anim())]
    zapisy, stranky, report = [], {}, {}
    for kind, (klice, sprity, meta) in davky:
        zaznamy, _n, info = sestav(kind, klice, sprity, meta)
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
        report[f"{kind}_box_px"] = {str(i): [m["w"], m["h"]]
                                    for (_k, i), m in zip(klice, meta)}
        report[f"{kind}_obsah_sirka_px"] = {str(i): m["obsah_sirka_px"]
                                            for (_k, i), m in zip(klice, meta)}
        report[f"{kind}_obsah_vyska_px"] = {str(i): m["obsah_vyska_px"]
                                            for (_k, i), m in zip(klice, meta)}
        if kind != "land":
            vid = {str(i): m["stin_viditelne_px"] for (_k, i), m in zip(klice, meta)}
            vrstva = {str(i): m["stin_vrstva_px"] for (_k, i), m in zip(klice, meta)}
            report[f"{kind}_stin_viditelne_px"] = vid          # po spritech (kontrola)
            report[f"{kind}_stin_vrstva_px"] = vrstva
            report[f"{kind}_stin_viditelne_px_min"] = min(vid.values())
            report[f"{kind}_stin_viditelne_px_max"] = max(vid.values())
            report[f"{kind}_stin_max_alfa"] = max(m["stin_max_alfa"] for m in meta)
            report[f"{kind}_stin_faktor_min"] = min(m["stin_faktor_min"] for m in meta)
            report[f"{kind}_px_na_jednotku"] = sorted({m["px_na_jednotku"] for m in meta})
            report[f"{kind}_px_na_jednotku_podle_spritu"] = {
                str(i): m["px_na_jednotku"] for (_k, i), m in zip(klice, meta)}
            report[f"{kind}_px_na_jednotku_merene"] = sorted(
                {m["px_na_jednotku_merene"] for m in meta})
            report[f"{kind}_rovina_sirka_px"] = sorted({m["rovina_sirka_px"] for m in meta})
        else:
            report[f"{kind}_stin_viditelne_px"] = {}
            report[f"{kind}_stin_vrstva_px"] = {}
            report[f"{kind}_stin_viditelne_px_min"] = 0
            report[f"{kind}_stin_viditelne_px_max"] = 0
            report[f"{kind}_stin_max_alfa"] = 0
            report[f"{kind}_stin_duvod"] = ("dlazdice je podlaha - stin pod ni je "
                                            "cely schovany pod ni, proto se ani "
                                            "nerenderuje")
        if kind == "item":
            report["item_obsah_proti_UO"] = {
                m["jmeno"]: {"nase": [m["obsah_sirka_px"], m["obsah_vyska_px"]],
                             "uo": m["uo_obsah"]} for m in meta}

    (OWN / "atlas").mkdir(parents=True, exist_ok=True)
    platne = sorted({z["page"] for z in zapisy})
    for stranka in platne:
        jmeno = Path(stranka).name
        druh, cislo = jmeno[:-4].rsplit("_", 1)
        stranky[f"{druh}_{cislo}"].save(OWN / "atlas" / jmeno)
    uklizeno = 0
    for stara in (OWN / "atlas").glob("*.png"):
        if f"atlas/{stara.name}" not in platne:
            stara.unlink()
            uklizeno += 1
    if uklizeno:
        report["uklizeno_stranek"] = uklizeno

    klice_a, sprity_a, meta_a = davky[2][1]
    if len(sprity_a) != acl.CHAR["dirs"] * acl.CHAR["frames"]:
        raise SystemExit(f"anim framu {len(sprity_a)} != "
                         f"{acl.CHAR['dirs'] * acl.CHAR['frames']}")
    report["anim_listu"] = zapis_anim_sheets(sprity_a, klice_a, meta_a)["listy"]

    manifest = hlavicka_manifestu(report)
    manifest["pages"] = [
        {"file": s, "w": acl.PAGE, "h": acl.PAGE,
         "count": sum(1 for z in zapisy if z["page"] == s)} for s in platne]
    manifest["sprites"] = sorted(zapisy, key=lambda z: (z["kind"], z["id"]))
    ac1.zapis_manifest(OWN / "manifest.json", manifest)
    print(f"[packlit] stranek {len(platne)}, spritu {len(zapisy)} -> "
          f"{OWN/'manifest.json'}")
    for k in sorted(report):
        print(f"[packlit]   {k} = {report[k]}")
    return zkontroluj(a.nahled, a.hash)


def tabulka_raw() -> int:
    """Vypise MERENE hodnoty z renderu (nic nezapisuje) - na ladeni pred zabalenim."""
    hlavicka = (f"{'davka':6s} {'jmeno':10s} {'sprite':>9s} {'obsah':>9s} "
                f"{'stred_x':>8s} {'pod_kont':>9s} {'stin_vid':>8s} {'stin_vrst':>9s} "
                f"{'stin_alfa':>9s} {'meritko':>8s}")
    print(hlavicka)
    print("-" * len(hlavicka))
    for kind, fn in (("land", davka_land), ("item", davka_item), ("anim", davka_anim)):
        try:
            klice, sprity, meta = fn()
        except SystemExit as e:
            print(f"{kind:6s} NEMERENO: {e}")
            continue
        for (_k, _i), img, m in list(zip(klice, sprity, meta))[:8]:
            a = np.array(img)[:, :, 3]
            ys, xs = np.nonzero(a)
            if len(xs) == 0:
                print(f"{kind:6s} {m.get('jmeno', '')} PRAZDNY SPRITE")
                continue
            print(f"{kind:6s} {str(m.get('jmeno', '')):10s} "
                  f"{img.width:4d}x{img.height:<4d} "
                  f"{xs.max()-xs.min()+1:4d}x{ys.max()-ys.min()+1:<4d} "
                  f"{((xs.min()+xs.max())/2.0) - img.width // 2:+8.2f} "
                  f"{m['obsah_pod_kontaktem_px']:9.2f} {m['stin_viditelne_px']:8d} "
                  f"{m['stin_vrstva_px']:9d} {m['stin_max_alfa']:9d} {m['meritko']:8.4f}")
    return 0


# ---------------------------------------------------------------------------
# brana
# ---------------------------------------------------------------------------
def _hash(cesta: Path) -> str:
    h = hashlib.sha256()
    h.update(cesta.read_bytes())
    return h.hexdigest()


def pixely(img: Image.Image) -> np.ndarray:
    return np.asarray(img.convert("RGBA"), dtype=np.int16)


def obsah_1x(kind: str, ident: int) -> tuple[int, int] | None:
    """Obsah OBJEKTU (alfa >= 200) z 1x sady, MERENY Z PIXELU ATLASU.

    Duvod: report je tvrzeni vyrobce, atlas je to, co by si hra precetla.
    U 1x sady neni stin, takze plna alfa = cely obsah.
    """
    cesta = OWN1X / "manifest.json"
    if not cesta.exists():
        return None
    m = json.loads(cesta.read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            img = Image.open(OWN1X / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
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
        print(f"[checklit] CHYBA: {cesta} neexistuje - neni co overovat")
        return 1
    data = json.loads(cesta.read_text(encoding="utf-8"))
    uo = ac1.uo_manifest(UO / "manifest.json")

    # --- kontrakt: klice proti UO ------------------------------------------
    kontrola(set(data) == set(uo), f"klice manifestu se lisi od UO: chybi "
             f"{sorted(set(uo) - set(data))}, navic {sorted(set(data) - set(uo))}")
    klice = {k for s in data["sprites"] for k in s}
    kontrola(klice == KLICE_SPRITU_UO, f"klice spritu se lisi od UO: chybi "
             f"{sorted(KLICE_SPRITU_UO - klice)}, navic {sorted(klice - KLICE_SPRITU_UO)}")
    kontrola(data.get("page_size") == acl.PAGE and data.get("pad") == acl.PAD,
             "page_size/pad nejsou 2048/1")
    # manifest musi tvrdit 1x ROZLISENI (jinak by sada byla neco jineho, nez co
    # je v zadani) - a cisla musi sedet na zivy kontrakt, ne na text
    lit = data.get("source", {}).get("lit_kontrakt", {})
    kontrola(lit.get("tile_px") == acl.TILE and lit.get("tile_px") == ac1.TILE
             and lit.get("render_px") == ac1.RENDER,
             f"manifest netvrdi 1x rozliseni ({acl.TILE} px / render {ac1.RENDER}): {lit}")

    ocekavane = {("land", t["uo_id"]) for t in acl.LAND} | \
                {("item", i["uo_id"]) for i in acl.ITEMS} | \
                {("anim", acl.anim_id(d, f)) for d in range(acl.CHAR["dirs"])
                 for f in range(acl.CHAR["frames"])}
    nalezene = {(s["kind"], s["id"]) for s in data["sprites"]}
    kontrola(nalezene == ocekavane,
             f"mnozina spritu se lisi: chybi {sorted(ocekavane - nalezene)[:6]}, "
             f"navic {sorted(nalezene - ocekavane)[:6]}")
    ocekavany_pocet = 2 + 4 + acl.CHAR["dirs"] * acl.CHAR["frames"]
    kontrola(len(data["sprites"]) == len(ocekavane) == ocekavany_pocet,
             f"pocet spritu {len(data['sprites'])} != ocekavanych {ocekavany_pocet}")

    # --- svetlo: recept musi byt TYZ jako v 2x vetvi ------------------------
    for jmeno, tady, v2x in acl.shoda_receptu_s_2x():
        kontrola(tady == v2x, f"recept svetla '{jmeno}' se lisi od 2x vetve: "
                              f"{tady!r} vs {v2x!r}")
    zaznamenany = data.get("source", {}).get("svetlo_recept")
    kontrola(zaznamenany == acl.recept_svetla(),
             "manifest ma jiny recept svetla, nez ktery lit vetev pouziva "
             f"({zaznamenany} vs {acl.recept_svetla()})")

    # --- stranky a sprity ---------------------------------------------------
    stranky = {}
    for p in data["pages"]:
        c = OWN / p["file"]
        kontrola(c.exists(), f"chybi stranka {p['file']}")
        if c.exists():
            img = Image.open(c).convert("RGBA")
            stranky[p["file"]] = img
            kontrola(img.size == (acl.PAGE, acl.PAGE),
                     f"stranka {p['file']} ma {img.size}, ne ({acl.PAGE}, {acl.PAGE})")
    stin_px: dict[tuple, int] = {}
    obsah_lit: dict[tuple, tuple] = {}
    for s in data["sprites"]:
        img = stranky.get(s["page"])
        if img is None:
            continue
        kontrola(s["rect"] == [s["x"], s["y"], s["x"] + s["w"], s["y"] + s["h"]],
                 f"{s['kind']} {s['id']}: rect neni [x,y,x+w,y+h]")
        kontrola(0 < s["w"] <= acl.PAGE and 0 < s["h"] <= acl.PAGE
                 and s["x"] + s["w"] <= acl.PAGE and s["y"] + s["h"] <= acl.PAGE,
                 f"{s['kind']} {s['id']}: sprite leze ze stranky")
        crop = img.crop(tuple(s["rect"]))
        arr = np.array(crop)
        alfa = arr[:, :, 3]
        bb = crop.split()[3].getbbox()
        kontrola(bb is not None, f"{s['kind']} {s['id']}: prazdny sprite v atlase")
        if bb is None:
            continue
        # (1) KOTVA: vzorec UO
        kontrola(acl.ofsahy(s["kind"], s["w"], s["h"]) == (s["ox"], s["oy"]),
                 f"{s['kind']} {s['id']}: kotva ({s['ox']},{s['oy']}) neni vzorec UO "
                 f"{acl.ofsahy(s['kind'], s['w'], s['h'])}")
        if s["kind"] == "land":
            kontrola(s["w"] == acl.TILE and s["h"] == acl.TILE
                     and s["ox"] == 0 and s["oy"] == 0,
                     f"land {s['id']}: neni {acl.TILE}x{acl.TILE} s ox=oy=0")
            kontrola(bb == (0, 0, acl.TILE, acl.TILE), f"land {s['id']}: obsah neni cely box")
            kontrola(int((alfa > 0).sum()) == pp.KOSOCTVEREC_PX,
                     f"land {s['id']}: kosoctverec ma {int((alfa > 0).sum())} px, "
                     f"spravne je {pp.KOSOCTVEREC_PX}")
            # dlazdice NEMA mit polopruhledne pixely (je to plna plocha a stin
            # pod ni je schovany pod ni) - kdyby se objevily, je to vada masky
            kontrola(int(((alfa > 0) & (alfa < 200)).sum()) == 0,
                     f"land {s['id']}: dlazdice ma polopruhledne pixely, ale stin "
                     "pod podlahou nema byt videt")
            uo_s = ac1.uo_sprite(uo, "land", s["id"])
            if uo_s is not None:
                uo_img = Image.open(UO / uo_s["page"]).convert("RGBA").crop(tuple(uo_s["rect"]))
                rozdil = int(((alfa > 0) != (np.array(uo_img)[:, :, 3] > 0)).sum())
                kontrola(rozdil == 0, f"land {s['id']}: maska se lisi od UO o {rozdil} px")
            obsah_lit[(s["kind"], s["id"])] = None
            continue
        # (2) obsah OBJEKTU = plna alfa; kontaktni stin je polopruhledny, takze
        # do nej nepatri (jinak by "obsah" rostl o stin a nic by se nezmerilo)
        plna = alfa >= 200
        bb_obj = None
        if plna.any():
            ys, xs = np.nonzero(plna)
            bb_obj = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        kontrola(bb_obj is not None, f"{s['kind']} {s['id']}: neni plne nepruhledny obsah")
        if bb_obj is None:
            continue
        obsah_lit[(s["kind"], s["id"])] = (bb_obj[2] - bb_obj[0], bb_obj[3] - bb_obj[1])
        levy, horni, pravy, spodek = bb_obj
        stred = (levy + pravy - 1) / 2.0
        kontrola(abs(stred - s["w"] // 2) <= 1.0,
                 f"{s['kind']} {s['id']}: stred obsahu {stred} != kotva {s['w'] // 2}")
        pod = (s["h"] - acl.GROUND_PX) - (spodek - 1)
        kontrola(-acl.GROUND_PX <= pod <= 0,
                 f"{s['kind']} {s['id']}: obsah konci {pod:+d} px od kontaktu "
                 f"(povoleno -{acl.GROUND_PX}..0)")
        # (3) KONTAKTNI STIN: musi byt skutecne VIDET ve sprite.
        # ⚠ STIN SE HLEDA PODLE BARVY VRSTVY, NE PODLE "polopruhledne pixely":
        # antialias objektu je taky polopruhledny a ma barvu objektu - prvni
        # verze brany ho pocitala jako stin a hlasila "barva stinu neni cerna"
        # u 45 spritu. Nespravne bylo i druhe zneni ("polopruhledne pixely mimo
        # siluetu rozsirenou o 2 px"): kontaktni stin u predmetu na zemi je 1 px
        # lem TESNE u obrysu a dilatace ho smazala (u dyky zbylo 0 px).
        barva_stinu = np.array(acl.STIN_BARVA, dtype=np.uint8)
        stin = (alfa > 0) & (alfa < 200) & ((arr[:, :, :3] == barva_stinu).all(axis=2))
        px = int(stin.sum())
        stin_px[(s["kind"], s["id"])] = px
        kontrola(px > 0, f"{s['kind']} {s['id']}: ve sprite NENI videt kontaktni "
                         "stin (lit sada ma mit slunce + AO + stin pod objektem)")
        # (3b) maska nesmi chytat TELO objektu: kdyby mel nejaky material barvu
        # stinu, pocitali bychom za stin neco jineho
        kontrola(int((plna & ((arr[:, :, :3] == barva_stinu).all(axis=2))).sum()) == 0,
                 f"{s['kind']} {s['id']}: plne nepruhledne pixely maji barvu stinu "
                 "- maska stinu by merila neco jineho, nez vrstvu stinu")
        # (3c) ... a musi byt v KONTAKTNIM OKRUHU kolem kotvy (je to KONTAKTNI
        # stin, ne vrh pres celou dlazdici). Polomer = R1 * meritko spritu.
        pj = (data.get("report", {}).get(f"{s['kind']}_px_na_jednotku") or [None])[0]
        if pj:
            ax, ay = s["w"] // 2, s["h"] - acl.GROUND_PX
            m = int(np.ceil(acl.STIN_R1_JEDNOTEK * pj)) + 1
            yy, xx = np.mgrid[0:s["h"], 0:s["w"]]
            okruh = (np.hypot(xx - ax, yy - ay) <= m)
            v_okruhu = int((stin & okruh).sum())
            kontrola(v_okruhu > 0,
                     f"{s['kind']} {s['id']}: v kontaktnim okruhu ({m} px kolem "
                     "kotvy) neni zadny stin - stin je od kontaktu daleko")
        # (3d) krytí stinu musi byt nad prahem receptu (jinak je to sum z renderu)
        mx = int(alfa[stin].max()) if stin.any() else 0
        kontrola(mx >= STIN_MIN_ALFA,
                 f"{s['kind']} {s['id']}: max krytí stinu {mx}/255 < {STIN_MIN_ALFA} "
                 f"(prah receptu je {acl.STIN_PRAH}) - stin je prilis slaby na to, "
                 "aby byl videt")
        # (3e) stin nesmi byt UKROJENY okrajem spritu (pak by v mape chybel)
        okraj = np.zeros_like(stin)
        okraj[0, :] = okraj[-1, :] = True
        okraj[:, 0] = okraj[:, -1] = True
        kontrola(int((stin & okraj).sum()) == 0,
                 f"{s['kind']} {s['id']}: stin se dotyka okraje spritu - je ukrojeny")
        # (3f) a cislo, ktere o sobe tvrdi manifest, musi sedet na pixely atlasu
        vm = (data.get("report", {}).get(f"{s['kind']}_stin_viditelne_px", {})
              .get(str(s["id"])))
        if vm is not None:
            kontrola(int(vm) == px,
                     f"{s['kind']} {s['id']}: manifest tvrdi viditelny stin "
                     f"{vm} px, v atlase je {px} px")
    pocet_stinu = sum(1 for v in stin_px.values() if v > 0)
    kontrola(len(stin_px) > 0 and pocet_stinu == len(stin_px),
             f"stin ma jen {pocet_stinu}/{len(stin_px)} spritu (item+anim)")

    # --- (4) geometrie se nerozjela proti 1x sade --------------------------
    # Svetlo meni BARVU, ne tvar: obsah objektu musi byt stejne velky jako v 1x.
    # kdyby se lit vetev omylem vyrenderovala v jinem meritku, spadne to tady.
    pokud = 0
    preskoceno = 0
    for (kind, ident), velikost in sorted(obsah_lit.items()):
        if velikost is None:          # dlazdice: nema "objekt" proti kotve
            preskoceno += 1
            continue
        wl, hl = velikost
        o1 = obsah_1x(kind, ident)
        if o1 is None:
            kontrola(False, f"{kind} {ident}: v 1x sade neni - geometrii nelze "
                            "porovnat (nic neni uspech)")
            continue
        pokud += 1
        dw, dh = abs(wl - o1[0]), abs(hl - o1[1])
        kontrola(dw <= TOLERANCE_OBSAHU_PX and dh <= TOLERANCE_OBSAHU_PX,
                 f"{kind} {ident}: obsah se lisi od 1x sady o ({dw},{dh}) px "
                 f"[lit {wl}x{hl} vs 1x {o1[0]}x{o1[1]}] - svetlo nema menit geometrii")
    kontrola(pokud > 0, "geometrie proti 1x sade se NEMERILA (0 spritu porovnano)")
    if preskoceno:
        print(f"[checklit] geometrie: porovnano {pokud} spritu objektu s 1x sadou; "
              f"{preskoceno} dlazdic preskoceno (nema obsah proti kotve)")

    # --- (5) meritko uvnitr spritu a to, ze se stin VEJDE do spritu ----------
    # ⚠ PUVODNI ZNENI (prevzate z 2x) znelo "polomer stinu R1*px_na_jednotku se
    # musi vejit nad kontakt, tedy <= GROUND_PX". Pri 1x to u rudy NEPLATI
    # (24,7 px > 22) - a ani platit nema: sprite se pro stin ZVETSUJE
    # (`postprocess_lit.sestav`), takze se nic neukroji. Co plati a meri se:
    # platno je aspon tak velke, aby se stin do nej vesel - a pixely to
    # potvrzuji (kontrola (3e): stin se nedotyka okraje).
    rep = data.get("report", {})
    pj_podle_druhu = {}
    for kind in ("item", "anim"):
        px_j = rep.get(f"{kind}_px_na_jednotku") or []
        pj_podle_druhu[kind] = px_j
        if not px_j:
            kontrola(False, f"{kind}: v reportu neni px_na_jednotku - meritko roviny "
                            "se NEMERILO (nic neni uspech)")
            continue
        podle_spritu = rep.get(f"{kind}_px_na_jednotku_podle_spritu") or {}
        if set(podle_spritu) != {str(s["id"]) for s in data["sprites"]
                                 if s["kind"] == kind}:
            kontrola(False, f"{kind}: v reportu neni px_na_jednotku pro kazdy sprite "
                            "- misto na stin by se u casti sady nemerilo")
        for s in data["sprites"]:
            if s["kind"] != kind:
                continue
            pj = podle_spritu.get(str(s["id"]))
            if pj is None:
                continue
            r1_px = int(np.ceil(acl.STIN_R1_JEDNOTEK * pj)) + 1
            kontrola(s["w"] >= 2 * r1_px and s["h"] >= acl.GROUND_PX + r1_px,
                     f"{kind} {s['id']}: box {s['w']}x{s['h']} je mensi nez misto na "
                     f"stin (pri px_na_jednotku={pj} potreba >= "
                     f"{2 * r1_px}x{acl.GROUND_PX + r1_px}) - stin by se ukrojil")
    # ... a obe meritka (vzorec z 2x i merena sirka roviny) se hlasí, aby bylo
    # videt, jaky je mezi nimi rozdil (viz docstring `postprocess_lit.py`)
    pj_item = (rep.get("item_px_na_jednotku") or [None])[0]
    pj_item_m = (rep.get("item_px_na_jednotku_merene") or [None])[0]
    pj_anim = (rep.get("anim_px_na_jednotku") or [None])[0]
    pj_anim_m = (rep.get("anim_px_na_jednotku_merene") or [None])[0]
    if pj_item and pj_item_m:
        print(f"[checklit] px/jednotku (vzorec z 2x: sirka roviny/sqrt(2)) = {pj_item} "
              f"(dyka) / {pj_anim} (postava); MERENA sirka roviny = {pj_item_m} / "
              f"{pj_anim_m} -> pomer {pj_item_m / pj_item:.3f} (= sqrt(2); vzorec je "
              "z 2x prevzaty, ne novy)")
        print(f"[checklit] polomer stinu R1={acl.STIN_R1_JEDNOTEK} jednotky = "
              f"{acl.STIN_R1_JEDNOTEK * pj_item:.1f} px (dyka) / "
              f"{acl.STIN_R1_JEDNOTEK * pj_anim:.1f} px (postava); box je pro stin "
              "zvetseny, takze se neukrojí")

    # --- seam ---------------------------------------------------------------
    for s in data["sprites"]:
        if s["kind"] in ("land", "item"):
            kontrola(ac1.uo_sprite(uo, s["kind"], s["id"]) is not None,
                     f"{s['kind']} {s['id']}: v UO manifestu neni - neni co nahradit")

    # --- police: prekryvy a mezery -----------------------------------------
    police: dict = {}
    for s in data["sprites"]:
        police.setdefault((s["page"], s["y"]), []).append(s)
    for (_stranka, _y), v in police.items():
        v.sort(key=lambda s: s["x"])
        for a1, b1 in zip(v, v[1:]):
            kontrola(a1["x"] + a1["w"] <= b1["x"],
                     f"prekryv {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']}")
            kontrola(b1["x"] - (a1["x"] + a1["w"]) == acl.PAD,
                     f"mezera mezi {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']} "
                     f"neni {acl.PAD}")

    # --- anim listy ---------------------------------------------------------
    listy = OWN / "anim" / "anim-sheets.json"
    kontrola(listy.exists(), f"chybi {OWN}/anim/anim-sheets.json")
    if listy.exists():
        ld = json.loads(listy.read_text(encoding="utf-8"))
        uo_anim = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
        kontrola(set(ld) == set(uo_anim), "klice anim listu se lisi od UO: chybi "
                 f"{sorted(set(uo_anim) - set(ld))}, navic {sorted(set(ld) - set(uo_anim))}")
        kontrola(len(ld["sprites"]) == acl.CHAR["dirs"],
                 f"anim listu {len(ld['sprites'])} != {acl.CHAR['dirs']}")
        for k, v in ld["sprites"].items():
            kontrola(k in uo_anim["sprites"], f"{k}: klic v UO anim listech neni")
            kontrola(len(v["frames"]) == acl.CHAR["frames"], f"{k}: framu neni 8")
            kontrola((OWN / "anim" / v["file"]).exists(), f"{k}: chybi PNG {v['file']}")
            for f in v["frames"]:
                kontrola(f["cy"] == -acl.GROUND_PX,
                         f"{k}: kontaktni bod neni {acl.GROUND_PX} px nad spodni hranou")
                kontrola(f["rect"][2] - f["rect"][0] == f["w"]
                         and f["rect"][3] - f["rect"][1] == f["h"],
                         f"{k}: rect framu neni [x,y,x+w,y+h]")

    # --- (6) DETERMINISMUS: dva behy = stejny SHA --------------------------
    # ⚠ Neni to "spustime to dvakrat tady": baseline zapisuje
    # `probe_determinismus_lit.py`, ktery obe behy SKUTECNE provede a porovna
    # pixely. Brana pak jen overi, ze sada na disku je ta, ktera se merila.
    if not DETERMINISMUS.exists():
        kontrola(False, f"chybi {DETERMINISMUS.name} - determinismus se NEMERIL "
                        "(spust `probe_determinismus_lit.py`); nic neni uspech")
    else:
        det = json.loads(DETERMINISMUS.read_text(encoding="utf-8"))
        # DVE UROVNE, a rozlisuji se ZAMERNE (viz `probe_determinismus_lit.py`):
        # manifest (kotvy, masky, pocty) = determinismus z pilotu §4; pixely jsou
        # prisnejsi a cislo se hlasi, i kdyz projde.
        kontrola(bool(det.get("shodne_manifest")),
                 f"determinismus manifestu NESEDI: {det.get('rozdiely')}")
        kontrola(bool(det.get("shodne_pixely")),
                 f"pixely se mezi behy lisi vic nez o toleranci "
                 f"{det.get('pixel_tolerance')}: {det.get('rozdiely')}")
        kontrola(bool(det.get("shodne")),
                 f"determinismus NESEDI: {det.get('rozdiely')}")
        aktualni = _hash(cesta)
        kontrola(det.get("baseline", {}).get("manifest_sha") == aktualni,
                 "SHA manifestu na disku neni ten, ktery se meril v determinismu "
                 f"({aktualni[:12]} vs {str(det.get('baseline', {}).get('manifest_sha'))[:12]})"
                 " - sada se zmenila, determinismus je potreba premerit")
        pix_st = det.get("pixely_po_strankach", {})
        print("[checklit] determinismus: manifest SHA shodne: "
              f"{det.get('shodne_manifest')}; max|rozdil| pixelu "
              f"{det.get('max_pixel_rozdil')} (tolerance {det.get('pixel_tolerance')}); "
              + ", ".join(f"{k}: {v['pixelu_s_rozdilem']} px" for k, v in sorted(pix_st.items())))

    if nahled:
        _nahled(data, stranky, Path(nahled))
    _n_uo = sum(1 for s in data["sprites"] if s["kind"] in ("land", "item")
                and ac1.uo_sprite(uo, s["kind"], s["id"]) is not None)
    _n = sum(1 for s in data["sprites"] if s["kind"] in ("land", "item"))
    _anim_uo = set(json.loads((UO / "anim" / "anim-sheets.json")
                              .read_text(encoding="utf-8"))["sprites"])
    _kk = [f"{acl.CHAR['body']}/{acl.CHAR['action_walk']}/{d}"
           for d in range(acl.CHAR["dirs"])]
    print(f"[checklit] seam: land+item {_n_uo}/{_n} id je v UO manifestu; "
          f"anim {sum(1 for k in _kk if k in _anim_uo)}/{len(_kk)} klicu je v UO anim listech")
    if hash_out:
        print(f"[checklit] sha256(manifest.json) = {_hash(cesta)}")
        for p in sorted((OWN / "atlas").glob("*.png")):
            print(f"[checklit] sha256({p.name}) = {_hash(p)}")
    print(f"[checklit] {pocet} kontrol, {len(chyby)} chyb")
    for ch in chyby[:15]:
        print(f"[checklit] CHYBA: {ch}")
    return 1 if chyby else 0


def _nahled(data: dict, stranky: dict, cesta: Path) -> None:
    """Nahled vyriznutych spritu z atlasu (kontrola pohledem, bez UO).

    ⚠ Chybejici stranka se PRESKOCI: prvni verze tady spadla na `KeyError`
    (nasel to mutacni test `probe_mutace_lit.py` - "stranka_chybi" tehdy
    skoncila tracebackem misto hlasky). Brana ma vadu POJMENOVAT, ne na ni
    spadnout - rozlisuje se tim "vada v artu" od "vada v brani".
    """
    vyber = {"land": 6, "item": 6, "anim": 4}
    bunky = []
    chybejici = 0
    for s in data["sprites"]:
        img = stranky.get(s["page"])
        if img is None:
            chybejici += 1
            continue
        bunky.append((vyber.get(s["kind"], 4), img.crop(tuple(s["rect"]))))
    if chybejici:
        print(f"[checklit] nahled: {chybejici} spritu vynechano (stranka se nenacetla)")
    if not bunky:
        print("[checklit] nahled: NELZE vyrobit - zadna stranka se nenacetla")
        return
    bunky.sort(key=lambda t: -t[0])
    k = max(b[0] for b in bunky)
    sirka = sum(b[1].width * b[0] for b in bunky) + 4 * (len(bunky) + 1)
    vyska = max(b[1].height * b[0] for b in bunky) + 8
    p = Image.new("RGBA", (sirka, vyska), (36, 38, 44, 255))
    x = 4
    for kolik, img in bunky:
        p.alpha_composite(img.resize((img.width * kolik, img.height * kolik), Image.NEAREST),
                          (x, 4))
        x += img.width * kolik + 4
    p.convert("RGB").save(cesta)
    print(f"[checklit] nahled: {cesta}")


if __name__ == "__main__":
    raise SystemExit(main())
