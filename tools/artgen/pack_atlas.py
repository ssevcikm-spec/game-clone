# -*- coding: utf-8 -*-
"""pack_atlas.py - slozi sprity do stranek 2048^2 a napise manifest ve tvaru UO.

  python tools/artgen/pack_atlas.py            # z `tools/artgen/raw/` do `assets/own/`
  python tools/artgen/pack_atlas.py --check    # premer hotovy vystup (nic nezapisuje)

Vystup (ZADANI-25 §4.2):
  assets/own/manifest.json         - STEJNE klice spritu jako `assets/uo/manifest.json`
                                     (`id`,`kind`,`page`,`x`,`y`,`w`,`h`,`ox`,`oy`,`rect`)
  assets/own/atlas/<kind>_<n>.png  - stranky 2048^2, `pad` 1 (jako UO)
  assets/own/anim/anim-sheets.json - 40 framu chuze ve TVARU UO anim exportu
                                     (`assets/uo/anim/anim-sheets.json`), protoze
                                     postavu hra nebere z manifestu, ale odtud
                                     (`render/anim_player.gd:32`)

`--check` je brana (a neni slepa):
  * klice spritu i klice manifestu se porovnaji s `assets/uo/manifest.json`,
  * kazda kotva musi sedet na vzorec UO (`ox=(w>>1)-22`, `oy=h-44`),
  * obsah sprite se MERI z pixelu v atlase (stred obsahu = stred sprite,
    kontakt neni niz nez 22 px pod obsahem),
  * kosoctverec nasich dlazdic se porovna s REALNOU maskou UO land artu,
  * kontrola prekryvu a mezery `pad` na policich (jako `atlas.py` self-test).

Determinismus: razeni `(-h, w, kind, id)`, zadne casove znacky, `sort_keys`.
`--check --hash` vypise SHA-256 manifestu - dva behy musi dat stejne cislo.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artgen_common as ac
import postprocess as pp
import uo_ref

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
OWN = Path("assets/own")
UO = Path("assets/uo")

KLICE_SPRITU_UO = {"id", "kind", "page", "x", "y", "w", "h", "ox", "oy", "rect"}


# ---------------------------------------------------------------------------
# sbirani podkladu
# ---------------------------------------------------------------------------
def _origin(davka: str) -> tuple[float, float]:
    cesta = RAW / f"_origin_{davka}.json"
    if not cesta.exists():
        raise SystemExit(f"chybi {cesta} - spust `render_sprites.py` (plan?)")
    o = json.loads(cesta.read_text(encoding="utf-8"))
    return (o["origin_x"], o["origin_y"])


def davka_land() -> tuple[list[tuple[str, int]], list[Image.Image], list[dict]]:
    sprity, meta, klice = [], [], []
    for spec in ac.LAND:
        cesta = RAW / f"tile_{spec['name']}.png"
        p = pp.priprav(cesta, _origin(f"tile_{spec['name']}"))
        s = pp.meritko([p], obsah_vyska_px=ac.TILE)
        obrazky, m = pp.sestav([p], s, "land", popis=spec["name"])
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=spec["name"]))
        klice.append(("land", spec["uo_id"]))
    return klice, sprity, meta


def davka_item() -> tuple[list[tuple[str, int]], list[Image.Image], list[dict]]:
    sprity, meta, klice = [], [], []
    for spec in ac.ITEMS:
        cesta = RAW / f"item_{spec['name']}.png"
        p = pp.priprav(cesta, _origin(f"item_{spec['name']}"))
        s = pp.meritko([p], obsah_vyska_px=spec["uo_content"][1])
        obrazky, m = pp.sestav([p], s, "item", popis=spec["name"])
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=spec["name"], uo_obsah=list(spec["uo_content"])))
        klice.append(("item", spec["uo_id"]))
    return klice, sprity, meta


def davka_anim() -> tuple[list[tuple[str, int]], list[Image.Image], list[dict]]:
    pripravene, klice = [], []
    for d in range(ac.CHAR["dirs"]):
        for f in range(ac.CHAR["frames"]):
            cesta = RAW / f"char_d{d}_f{f}.png"
            pripravene.append(pp.priprav(cesta, _origin("character")))
            klice.append(("anim", ac.anim_id(d, f)))
    s = pp.meritko(pripravene, obsah_vyska_px=ac.CHAR["cil_obsah_px"])
    obrazky, meta = pp.sestav(pripravene, s, "anim", popis="character")
    for i, (d, f) in enumerate([(d, f) for d in range(ac.CHAR["dirs"])
                                for f in range(ac.CHAR["frames"])]):
        meta[i]["jmeno"] = f"char_d{d}_f{f}"
        meta[i]["smer"] = d
        meta[i]["frame"] = f
    return klice, obrazky, meta


# ---------------------------------------------------------------------------
# sestaveni
# ---------------------------------------------------------------------------
def sestav(kind: str, klice, sprity, meta) -> tuple[list[dict], int, dict]:
    """Rozmisti sprity po strance a vrati (zaznamy, pocet stranek, souhrn).

    ⚠ POZOR NA PORADI: `ac.rozloz` vraci umisteni SERAZENE podle (-h, w, kind, id),
    kdezto `sprity`/`meta` jdou v poradi zadani. Dvojici je proto potreba hledat
    podle (kind, id) - `zip` pres ne se ROZJEDE a do atlasu se vlozi jiny obrazek,
    nez jaky se zapise do manifestu (namEReno 2026-10-10: dyka se vlozila na
    misto rudy a vysel prekryv). Odhalila to az brana `--check`.
    """
    podle = {(k, i): (obr, m) for (k, i), obr, m in zip(klice, sprity, meta)}
    rady = [(k, i, obr.width, obr.height) for (k, i), (obr, _m) in podle.items()]
    umisteni = ac.rozloz(rady)
    stranky: dict[int, Image.Image] = {}
    zapisy = []
    for k, ident, cislo, x, y in umisteni:
        obrazek, m = podle[(k, ident)]
        if cislo not in stranky:
            stranky[cislo] = Image.new("RGBA", (ac.PAGE, ac.PAGE), (0, 0, 0, 0))
        stranky[cislo].alpha_composite(obrazek, (x, y))
        ox, oy = ac.ofsahy(k, obrazek.width, obrazek.height)
        zapisy.append({
            "id": ident, "kind": k, "page": f"atlas/{k}_{cislo}.png",
            "x": x, "y": y, "w": obrazek.width, "h": obrazek.height,
            "rect": [x, y, x + obrazek.width, y + obrazek.height],
            "ox": ox, "oy": oy})
    return zapisy, len(stranky), {"stranky": stranky, "meta": meta}


def zapis_anim_sheets(sprity: list[Image.Image], klice, meta) -> dict:
    """Zapise 40 framu chuze jako listy ve tvaru UO (`anim-sheets.json`)."""
    out = OWN / "anim"
    out.mkdir(parents=True, exist_ok=True)
    podle = {}
    for (k, ident), obrazek, m in zip(klice, sprity, meta):
        body, akce, smer, frame = ac.anim_parts(ident)
        podle.setdefault(smer, []).append((frame, obrazek, m))
    sprites = {}
    for smer, polozky in sorted(podle.items()):
        polozky.sort(key=lambda t: t[0])
        sirka = sum(o.width for _f, o, _m in polozky)
        vyska = max(o.height for _f, o, _m in polozky)
        pruh = Image.new("RGBA", (sirka, vyska), (0, 0, 0, 0))
        x = 0
        framy = []
        for f, o, m in polozky:
            pruh.alpha_composite(o, (x, 0))
            cx, cy = o.width // 2, -(ac.GROUND_PX)
            framy.append({"rect": [x, 0, x + o.width, o.height], "cx": cx, "cy": cy,
                          "w": o.width, "h": o.height, "pixely_mimo": 0})
            x += o.width
        jmeno = f"own-{ac.CHAR['body']}-{ac.CHAR['action_walk']}-{smer}.png"
        pruh.save(out / jmeno)
        sprites[f"{ac.CHAR['body']}/{ac.CHAR['action_walk']}/{smer}"] = {
            "file": jmeno, "action": "walk", "frames": framy, "source": "assets/own"}
    data = {
        "version": 1,
        "decoder": "tools/artgen/pack_atlas.py (render Blenderu, postprocess Lanczos)",
        "anchor": "obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); "
                  "cy je -22, takze kontaktni bod je 22 px nad spodni hranou spritu",
        "actions": {"0": "walk"},
        "sprites": sprites,
        # UO export ma i seznam chyb (prazdny = vse vyexportovano); drzime tvar
        "chyby": [],
    }
    ac.zapis_manifest(out / "anim-sheets.json", data)
    return {"listy": len(sprites),
            "framu": sum(len(v["frames"]) for v in sprites.values())}


def tabulka_raw() -> int:
    """Vypise MERENE hodnoty z renderu (nic nezapisuje) - na ladeni pred zabalenim.

    Sloupce: sprite (w x h), obsah (bbox), stred obsahu proti KOTVE (`w//2`, ne
    proti stredu sprite - prave kotva rozhoduje o usazeni na dlazdici),
    jak hluboko obsah zasahuje pod kontaktni bod, meritko a srovnani s UO
    (obsah a prumerna barva - "udelej to jako UO" se neda splnit od oka).
    """
    import vzorky_uo
    hlavicka = (f"{'davka':6s} {'jmeno':10s} {'sprite':>9s} {'obsah':>9s} "
                f"{'stred_x':>8s} {'pod_kont':>9s} {'meritko':>8s}  UO obsah / barva")
    print(hlavicka)
    print("-" * len(hlavicka))
    for kind, fn in (("land", davka_land), ("item", davka_item), ("anim", davka_anim)):
        try:
            klice, sprity, meta = fn()
        except SystemExit as e:
            print(f"{kind:6s} NEMERENO: {e}")
            continue
        videno = set()
        for (k, ident), img, m in zip(klice, sprity, meta):
            a = np.array(img)[:, :, 3]
            ys, xs = np.nonzero(a)
            if len(xs) == 0:
                print(f"{kind:6s} {m.get('jmeno', ident):10s} PRAZDNY SPRITE")
                continue
            stred = (xs.min() + xs.max()) / 2.0
            rgb = np.array(img)[:, :, :3][a >= 200].mean(axis=0) if (a >= 200).any() else [0, 0, 0]
            uo = ""
            if kind in ("land", "item"):
                ident_uo = ident
                ref = vzorky_uo.vzorek(kind, ident_uo)
                if ref:
                    uo = (f"{ref['obsah'][0]}x{ref['obsah'][1]} rgb{ref['prumer_rgb_255']}")
            print(f"{kind:6s} {str(m.get('jmeno', ident)):10s} "
                  f"{img.width:4d}x{img.height:<4d} "
                  f"{xs.max()-xs.min()+1:4d}x{ys.max()-ys.min()+1:<4d} "
                  f"{stred - img.width // 2:+8.2f} "
                  f"{m['obsah_pod_kontaktem_px']:9.2f} {m['meritko']:8.4f}  "
                  f"{[int(round(v)) for v in rgb]} {uo}")
            if kind == "anim":
                videno.add(ident % 10)
        if kind == "anim":
            print(f"{kind:6s} (vypis je po framech; framu celkem {len(klice)})")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="atlas vlastniho artu")
    ap.add_argument("--check", action="store_true", help="jen premer hotovy vystup")
    ap.add_argument("--hash", action="store_true", help="vypsat SHA-256 manifestu")
    ap.add_argument("--tabulka-raw", action="store_true",
                    help="vypsat merene hodnoty z renderu (nic nezapisuje)")
    ap.add_argument("--nahled", default="tools/artgen/_atlas-nahled.png")
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
        if kind == "item":
            report["item_obsah_proti_UO"] = {
                m["jmeno"]: {"nase": [m["obsah_sirka_px"], m["obsah_vyska_px"]],
                             "uo": m["uo_obsah"]} for m in meta}
    # kazda stranka patri jednomu druhu - jmena se berou ze zaznamu
    (OWN / "atlas").mkdir(parents=True, exist_ok=True)
    platne = sorted({z["page"] for z in zapisy})
    for stranka in platne:
        jmeno = Path(stranka).name
        druh, cislo = jmeno[:-4].rsplit("_", 1)
        stranky[f"{druh}_{cislo}"].save(OWN / "atlas" / jmeno)
    # uklid osirelych stranek (jen v `assets/own/atlas/`, nic jineho se netyka)
    uklizeno = 0
    for stara in (OWN / "atlas").glob("*.png"):
        if f"atlas/{stara.name}" not in platne:
            stara.unlink()
            uklizeno += 1
    if uklizeno:
        report["uklizeno_stranek"] = uklizeno

    klice_a, sprity_a, meta_a = davky[2][1]
    report["anim_listu"] = zapis_anim_sheets(sprity_a, klice_a, meta_a)["listy"]

    stranky_meta = []
    for stranka in platne:
        jmeno = Path(stranka).name
        druh, cislo = jmeno[:-4].rsplit("_", 1)
        stranky_meta.append({"file": stranka, "w": ac.PAGE, "h": ac.PAGE,
                             "count": sum(1 for z in zapisy if z["page"] == stranka)})
    manifest = {
        "version": 1,
        "generator": "tools/artgen/pack_atlas.py",
        "page_size": ac.PAGE,
        "pad": ac.PAD,
        "source": {
            "pipeline": "tools/artgen (build_model_*.py -> render_sprites.py -> postprocess.py)",
            "blender": "5.2.1 LTS (BLENDER_EEVEE, film_transparent)",
            "render_px": ac.RENDER, "px_per_unit": ac.PX_PER_UNIT,
            "kamera": {"azimut_deg": ac.CAM_AZIMUTH_DEG,
                       "elevace_deg": round(ac.CAM_ELEVATION_DEG, 6),
                       "zrcadleni_x": ac.MIRROR_X,
                       "svisle_roztazeni": round(ac.VYSTRED_Y, 6)},
            "geometrie": "1 jednotka = 1 dlazdice = 44 px; kotva jako UO",
        },
        "pages": stranky_meta,
        "sprites": sorted(zapisy, key=lambda z: (z["kind"], z["id"])),
        "anim": {"file": "anim/anim-sheets.json", "pixels_decoded": True,
                 "id_klic": "body*1000 + action*100 + dir*10 + frame",
                 "smeru": ac.CHAR["dirs"], "framu": ac.CHAR["frames"],
                 "frame_ms": ac.CHAR["frame_ms"],
                 "duvod": "postava se v hre bere z anim listu (render/anim_player.gd), "
                          "ne z manifestu - proto jsou framy i tady"},
        "report": report,
    }
    ac.zapis_manifest(OWN / "manifest.json", manifest)
    print(f"[pack] stranek {len(platne)}, spritu {len(zapisy)} -> {OWN/'manifest.json'}")
    for k in sorted(report):
        print(f"[pack]   {k} = {report[k]}")
    return zkontroluj(a.nahled, a.hash)


# ---------------------------------------------------------------------------
# brana
# ---------------------------------------------------------------------------
def _hash(cesta: Path) -> str:
    h = hashlib.sha256()
    h.update(cesta.read_bytes())
    return h.hexdigest()


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
        print(f"[check] CHYBA: {cesta} neexistuje - neni co overovat")
        return 1
    data = json.loads(cesta.read_text(encoding="utf-8"))
    uo = ac.uo_manifest(UO / "manifest.json")

    kontrola(set(data) == set(uo), f"klice manifestu se lisi od UO: "
             f"chybi {sorted(set(uo) - set(data))}, navic {sorted(set(data) - set(uo))}")
    klice = {k for s in data["sprites"] for k in s}
    kontrola(klice == KLICE_SPRITU_UO, f"klice spritu se lisi od UO: "
             f"chybi {sorted(KLICE_SPRITU_UO - klice)}, navic {sorted(klice - KLICE_SPRITU_UO)}")
    kontrola(data.get("page_size") == ac.PAGE and data.get("pad") == ac.PAD,
             "page_size/pad nejsou 2048/1")

    ocekavane = {("land", t["uo_id"]) for t in ac.LAND} | \
                {("item", i["uo_id"]) for i in ac.ITEMS} | \
                {("anim", ac.anim_id(d, f)) for d in range(ac.CHAR["dirs"])
                 for f in range(ac.CHAR["frames"])}
    nalezene = {(s["kind"], s["id"]) for s in data["sprites"]}
    kontrola(nalezene == ocekavane,
             f"mnozina spritu se lisi: chybi {sorted(ocekavane - nalezene)[:6]}, "
             f"navic {sorted(nalezene - ocekavane)[:6]}")
    kontrola(len(data["sprites"]) == len(ocekavane) == 2 + 4 + ac.CHAR["dirs"] * ac.CHAR["frames"],
             f"pocet spritu {len(data['sprites'])} != ocekavanych "
             f"{2 + 4 + ac.CHAR['dirs'] * ac.CHAR['frames']}")

    stranky = {}
    for p in data["pages"]:
        c = OWN / p["file"]
        kontrola(c.exists(), f"chybi stranka {p['file']}")
        if c.exists():
            img = Image.open(c).convert("RGBA")
            stranky[p["file"]] = img
            kontrola(img.size == (ac.PAGE, ac.PAGE),
                     f"stranka {p['file']} ma {img.size}, ne ({ac.PAGE}, {ac.PAGE})")
    for s in data["sprites"]:
        img = stranky.get(s["page"])
        if img is None:
            continue
        kontrola(s["rect"] == [s["x"], s["y"], s["x"] + s["w"], s["y"] + s["h"]],
                 f"{s['kind']} {s['id']}: rect neni [x,y,x+w,y+h]")
        kontrola(0 < s["w"] <= ac.PAGE and 0 < s["h"] <= ac.PAGE
                 and s["x"] + s["w"] <= ac.PAGE and s["y"] + s["h"] <= ac.PAGE,
                 f"{s['kind']} {s['id']}: sprite leze ze stranky")
        crop = img.crop(tuple(s["rect"]))
        alfa = np.array(crop)[:, :, 3]
        bb = crop.split()[3].getbbox()
        kontrola(bb is not None, f"{s['kind']} {s['id']}: prazdny sprite v atlase")
        if bb is None:
            continue
        kontrola(ac.ofsahy(s["kind"], s["w"], s["h"]) == (s["ox"], s["oy"]),
                 f"{s['kind']} {s['id']}: kotva ({s['ox']},{s['oy']}) neni vzorec UO "
                 f"{ac.ofsahy(s['kind'], s['w'], s['h'])}")
        if s["kind"] == "land":
            kontrola(s["w"] == ac.TILE and s["h"] == ac.TILE and s["ox"] == 0 and s["oy"] == 0,
                     f"land {s['id']}: neni {ac.TILE}x{ac.TILE} s ox=oy=0")
            kontrola(bb == (0, 0, ac.TILE, ac.TILE), f"land {s['id']}: obsah neni cely box")
            # obsah kosoctverce je 1012 pixelu (= soucet radku UO masky); kdyz
            # jich je min, chybi roh (a v mape by byla dira)
            kontrola(int((alfa > 0).sum()) == pp.KOSOCTVEREC_PX,
                     f"land {s['id']}: kosoctverec ma {int((alfa > 0).sum())} px, "
                     f"spravne je {pp.KOSOCTVEREC_PX}")
            # MERENA shoda s REALNOU maskou UO dlazdice (ne s predstavou o ni)
            uo_s = ac.uo_sprite(uo, "land", s["id"])
            if uo_s is not None:
                uo_img = Image.open(UO / uo_s["page"]).convert("RGBA").crop(tuple(uo_s["rect"]))
                rozdil = int(((alfa > 0) != (np.array(uo_img)[:, :, 3] > 0)).sum())
                kontrola(rozdil == 0, f"land {s['id']}: maska se lisi od UO o {rozdil} px")
        else:
            # kotva se overuje Z PIXELU: stred obsahu = KOTVA (`w//2`, tam se
            # sprite v hre sadi) a obsah NESMI koncit nad kontaktni linkou ani
            # pod ni o vic nez GROUND_PX (pak by predmet visel, nebo by se
            # nevesel do sprite).
            # POZOR NA ZNAMENKO: `pod = (h-22) - (spodek-1)` je KLADNE, kdyz
            # obsah konci NAD kontaktem ("visi"), a ZAPORNE, kdyz pod nim.
            # U stojici postavy je kontakt pod chodidly, ale blizsi roh chodidla
            # se promita NIZ - proto je zaporna hodnota normalni (namEReno
            # u postavy -5,8 px, u lezici dyky -4,8 px).
            levy, horni, pravy, spodek = bb
            stred = (levy + pravy - 1) / 2.0
            kontrola(abs(stred - s["w"] // 2) <= 1.0,
                     f"{s['kind']} {s['id']}: stred obsahu {stred} != kotva {s['w'] // 2}")
            pod = (s["h"] - ac.GROUND_PX) - (spodek - 1)
            kontrola(-ac.GROUND_PX <= pod <= 0,
                     f"{s['kind']} {s['id']}: obsah konci {pod:+d} px od kontaktu "
                     f"(povoleno -{ac.GROUND_PX}..0; kladne = sprite visi nad dlazdici)")

    # SMYSL SEAM (SEAM.md): vlastni art je ZAROVEN NAHRAZENI, ne pridani - kazdy
    # nas (kind, id) musi existovat v UO manifestu. Kdyby ne, byla by to nova
    # polozka a "vlastni vyhrava, kde je" by nemelo co prepnout.
    for s in data["sprites"]:
        if s["kind"] in ("land", "item"):
            kontrola(ac.uo_sprite(uo, s["kind"], s["id"]) is not None,
                     f"{s['kind']} {s['id']}: v UO manifestu neni - neni co nahradit "
                     "(seam by musel resit novy id prostor)")

    # police: prekryvy a mezery (stejna logika jako self-test `atlas.py`)
    police: dict = {}
    for s in data["sprites"]:
        police.setdefault((s["page"], s["y"]), []).append(s)
    for (stranka, _y), v in police.items():
        v.sort(key=lambda s: s["x"])
        for a1, b1 in zip(v, v[1:]):
            kontrola(a1["x"] + a1["w"] <= b1["x"],
                     f"prekryv {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']}")
            kontrola(b1["x"] - (a1["x"] + a1["w"]) == ac.PAD,
                     f"mezera mezi {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']} "
                     f"neni {ac.PAD}")
    # anim listy
    listy = OWN / "anim" / "anim-sheets.json"
    kontrola(listy.exists(), "chybi assets/own/anim/anim-sheets.json")
    if listy.exists():
        ld = json.loads(listy.read_text(encoding="utf-8"))
        uo_anim = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
        kontrola(set(ld) == set(uo_anim), f"klice anim listu se lisi od UO: "
                 f"chybi {sorted(set(uo_anim) - set(ld))}, navic {sorted(set(ld) - set(uo_anim))}")
        kontrola(len(ld["sprites"]) == ac.CHAR["dirs"], "anim listu neni 5")
        for k, v in ld["sprites"].items():
            kontrola(len(v["frames"]) == ac.CHAR["frames"], f"{k}: framu neni 8")
            kontrola((OWN / "anim" / v["file"]).exists(), f"{k}: chybi PNG {v['file']}")
            for f in v["frames"]:
                kontrola(f["rect"][2] - f["rect"][0] == f["w"]
                         and f["rect"][3] - f["rect"][1] == f["h"],
                         f"{k}: rect framu neni [x,y,x+w,y+h]")
                kontrola(f["cy"] + f["h"] == f["h"] - ac.GROUND_PX,
                         f"{k}: kontaktni bod neni {ac.GROUND_PX} px nad spodni hranou")

    if nahled:
        _nahled(data, stranky, Path(nahled))
    # Souhrn pro seam (SEAM.md): kolik nasich klicu je zaroven klic UO - jen
    # takovy art jde "prepnut" (nahradit), ne pridat vedle.
    _n_uo = sum(1 for s in data["sprites"] if s["kind"] in ("land", "item")
                and ac.uo_sprite(uo, s["kind"], s["id"]) is not None)
    _n = sum(1 for s in data["sprites"] if s["kind"] in ("land", "item"))
    _anim_uo = set(json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))["sprites"])
    _kk = [f"{ac.CHAR['body']}/{ac.CHAR['action_walk']}/{d}" for d in range(ac.CHAR["dirs"])]
    print(f"[check] seam: land+item {_n_uo}/{_n} id je v UO manifestu; "
          f"anim {sum(1 for k in _kk if k in _anim_uo)}/{len(_kk)} klicu je v UO anim listech")
    if hash_out:
        print(f"[check] sha256(manifest.json) = {_hash(cesta)}")
        for p in sorted((OWN / "atlas").glob("*.png")):
            print(f"[check] sha256({p.name}) = {_hash(p)}")
    print(f"[check] {pocet} kontrol, {len(chyby)} chyb")
    for ch in chyby[:15]:
        print(f"[check] CHYBA: {ch}")
    return 1 if chyby else 0


def _nahled(data: dict, stranky: dict, cesta: Path) -> None:
    """Nahled vyriznutych spritu z atlasu (kontrola pohledem, bez UO)."""
    vyber = {"land": 14, "item": 10, "anim": 10}
    bunky = []
    for s in data["sprites"]:
        k = vyber.get(s["kind"], 8)
        bunky.append((k, stranky[s["page"]].crop(tuple(s["rect"]))))
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
    print(f"[check] nahled: {cesta}")


if __name__ == "__main__":
    raise SystemExit(main())
