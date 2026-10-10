# -*- coding: utf-8 -*-
"""pack_atlas_2x.py - slozi 2x sprity do stranek a napise manifest do `assets/own2x/`.

  python tools/artgen/pack_atlas_2x.py            # z `raw2x/` do `assets/own2x/`
  python tools/artgen/pack_atlas_2x.py --check    # premer hotovy vystup (nic nezapisuje)

Vystup je VE STEJNEM TVARU jako `assets/own/` (a tedy i `assets/uo/`):
  assets/own2x/manifest.json         - klice spritu `id,kind,page,x,y,w,h,ox,oy,rect`
  assets/own2x/atlas/<kind>_<n>.png  - stranky 2048^2, pad 1
  assets/own2x/anim/anim-sheets.json - 8 framu smeru 0 ve tvaru UO anim exportu

⚠ CO TENHLE SOUBOR ZAMERNE NEDELA: nebere `assets/own/` a neprepisuje ho.
2x je DRUHA sada vedle 1x (ZADANI-25 §9: "2x je zatim jen vyrenderovana
varianta pro rozhodnuti"), takze 1x zustava nedotcena a `pack_atlas.py --check`
(476 kontrol) se o 2x vubec nedozvi - a to je spravne, protoze 1x kontrakt
(44 px, kotva `oy=h-44`) plati dal. `assets/own/` se odsud jen CTE - jako
referencni meritko pro pomer 2x/1x.

BRANA `--check` se ptá na CHOVANI, ne na pritomnost:
  * kazda kotva musi sedet na 2x vzorec UO (`ox=(w>>1)-44`, `oy=h-88`),
  * obsah sprite se MERI z pixelu atlasu (stred = kotva, obsah nekonci niz nez
    44 px pod kontaktem),
  * **obsah musi byt ~2x obsah 1x sady** - a 1x obsah se MERI Z 1x ATLASU
    (`assets/own/`), ne z reportu; kdyby se omylem vyrenderovalo 1x meritko
    nebo kdyby se 1x sada mezitim zmenila, spadne to tady,
  * **stin musi byt SKUTECNE ve sprite** (pixely tmave polopruhledne alfy mimo
    obsah objektu) - jinak by "2x ma slunce + AO + kontaktni stin" bylo
    tvrzeni bez kryti,
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
import artgen_common_2x as ac2
import postprocess_2x as pp2

HERE = Path(__file__).resolve().parent
RAW = HERE / "_raw2x"
OWN = Path("assets/own2x")
OWN1X = Path("assets/own")
UO = Path("assets/uo")

KLICE_SPRITU_UO = {"id", "kind", "page", "x", "y", "w", "h", "ox", "oy", "rect"}
POMER_TOL = 0.25          # povolena odchylka pomeru 2x/1x (0,25 = +-25 %)


# ---------------------------------------------------------------------------
# sbirani podkladu
# ---------------------------------------------------------------------------
def _origin(davka: str) -> tuple[float, float]:
    cesta = RAW / f"_origin_{davka}.json"
    if not cesta.exists():
        raise SystemExit(f"chybi {cesta} - spust `render_2x.py --meritko 2x`")
    o = json.loads(cesta.read_text(encoding="utf-8"))
    if o.get("meritko") != "2x":
        raise SystemExit(f"{cesta}: meritko={o.get('meritko')!r}, cekam '2x' - "
                         "1x render se do 2x sady nesmi zamichat")
    return (o["origin_x"], o["origin_y"])


def davka_item():
    sprity, meta, klice = [], [], []
    for spec in ac2.ITEMS:
        cesta = RAW / f"item_{spec['name']}.png"
        p = pp2.priprav(cesta, _origin(f"item_{spec['name']}"),
                        stin=RAW / f"_stin_item_{spec['name']}.png",
                        ref=RAW / f"_ref_item_{spec['name']}.png")
        s = pp2.meritko([p], obsah_vyska_px=spec["cil_obsah"][1])
        obrazky, m = pp2.sestav([p], s, "item", popis=spec["name"])
        sprity.append(obrazky[0])
        meta.append(dict(m[0], jmeno=spec["name"],
                         uo_obsah=list(spec["uo_content"]),
                         cil_obsah=list(spec["cil_obsah"])))
        klice.append(("item", spec["uo_id"]))
    return klice, sprity, meta


def davka_anim():
    pripravene, klice = [], []
    ref = RAW / "_ref_character.png"
    for d in range(ac2.CHAR["dirs"]):
        for f in range(ac2.CHAR["frames"]):
            cesta = RAW / f"char_d{d}_f{f}.png"
            stin = RAW / f"_stin_char_d{d}_f{f}.png"
            pripravene.append(pp2.priprav(cesta, _origin("character"),
                                          stin=stin if stin.exists() else None,
                                          ref=ref if ref.exists() else None))
            klice.append(("anim", ac2.anim_id(d, f)))
    s = pp2.meritko(pripravene, obsah_vyska_px=ac2.CHAR["cil_obsah_px"])
    obrazky, meta = pp2.sestav(pripravene, s, "anim", popis="character")
    i = 0
    for d in range(ac2.CHAR["dirs"]):
        for f in range(ac2.CHAR["frames"]):
            meta[i]["jmeno"] = f"char_d{d}_f{f}"
            meta[i]["smer"] = d
            meta[i]["frame"] = f
            i += 1
    return klice, obrazky, meta


# ---------------------------------------------------------------------------
# sestaveni (stejne jako 1x, jen jina cisla stranek)
# ---------------------------------------------------------------------------
def sestav(klice, sprity, meta):
    podle = {(k, i): (obr, m) for (k, i), obr, m in zip(klice, sprity, meta)}
    rady = [(k, i, obr.width, obr.height) for (k, i), (obr, _m) in podle.items()]
    umisteni = ac2.rozloz(rady)
    stranky: dict[int, Image.Image] = {}
    zapisy = []
    for k, ident, cislo, x, y in umisteni:
        obrazek, _m = podle[(k, ident)]
        if cislo not in stranky:
            stranky[cislo] = Image.new("RGBA", (ac2.PAGE, ac2.PAGE), (0, 0, 0, 0))
        stranky[cislo].alpha_composite(obrazek, (x, y))
        ox, oy = ac2.ofsahy(k, obrazek.width, obrazek.height)
        zapisy.append({
            "id": ident, "kind": k, "page": f"atlas/{k}_{cislo}.png",
            "x": x, "y": y, "w": obrazek.width, "h": obrazek.height,
            "rect": [x, y, x + obrazek.width, y + obrazek.height],
            "ox": ox, "oy": oy})
    return zapisy, {"stranky": stranky}


def zapis_anim_sheets(sprity, klice, meta) -> dict:
    out = OWN / "anim"
    out.mkdir(parents=True, exist_ok=True)
    podle = {}
    for (_k, ident), obrazek, _m in zip(klice, sprity, meta):
        _b, _a, smer, frame = ac2.anim_parts(ident)
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
                          "cx": o.width // 2, "cy": -ac2.GROUND_PX,
                          "w": o.width, "h": o.height, "pixely_mimo": 0})
            x += o.width
        jmeno = f"own2x-{ac2.CHAR['body']}-{ac2.CHAR['action_walk']}-{smer}.png"
        pruh.save(out / jmeno)
        sprites[f"{ac2.CHAR['body']}/{ac2.CHAR['action_walk']}/{smer}"] = {
            "file": jmeno, "action": "walk", "frames": framy, "source": "assets/own2x"}
    data = {
        "version": 1,
        "decoder": "tools/artgen/pack_atlas_2x.py (2x render Blenderu, kontaktni stin)",
        "anchor": f"obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); cy je "
                  f"-{ac2.GROUND_PX}, takze kontaktni bod je {ac2.GROUND_PX} px nad "
                  "spodni hranou spritu (2x hodnota 1x kontraktu)",
        "actions": {"0": "walk"},
        "sprites": sprites,
        "chyby": [],
    }
    ac1.zapis_manifest(out / "anim-sheets.json", data)
    return {"listy": len(sprites),
            "framu": sum(len(v["frames"]) for v in sprites.values())}


def main() -> int:
    ap = argparse.ArgumentParser(description="atlas 2x vlastniho artu")
    ap.add_argument("--check", action="store_true", help="jen premer hotovy vystup")
    ap.add_argument("--hash", action="store_true", help="vypsat SHA-256 manifestu")
    a = ap.parse_args()
    if a.check or a.hash:
        return zkontroluj(a.hash)

    davky = {"item": davka_item(), "anim": davka_anim()}
    zapisy, stranky, report = [], {}, {}
    for kind, (klice, sprity, meta) in davky.items():
        zaznamy, info = sestav(klice, sprity, meta)
        zapisy.extend(zaznamy)
        for cislo, obrazek in info["stranky"].items():
            stranky[f"{kind}_{cislo}"] = obrazek
        report[f"{kind}_pozadovano"] = len(klice)
        report[f"{kind}_vyrobeno"] = len(zaznamy)
        report[f"{kind}_obsah_pod_kontaktem_max_px"] = max(
            m["obsah_pod_kontaktem_px"] for m in meta)
        # obsah (bbox OBJEKTU, bez stinu) klicovany ID SPRITU - aby se dal
        # porovnat s 1x sadou, kde jmena framu nejsou
        report[f"{kind}_obsah_vyska_px"] = {
            str(ident): m["obsah_vyska_px"] for (_k, ident), m in zip(klice, meta)}
        report[f"{kind}_obsah_sirka_px"] = {
            str(ident): m["obsah_sirka_px"] for (_k, ident), m in zip(klice, meta)}
        report[f"{kind}_stin_px_min"] = min(m["stin_px"] for m in meta)
        report[f"{kind}_stin_px_max"] = max(m["stin_px"] for m in meta)
        report[f"{kind}_stin_max_alfa"] = max(m["stin_max_alfa"] for m in meta)
        # MERENE meritko: kontaktni rovina je presne 1 jednotka, takze jeji uhlopricka
        # je sqrt(2) jednotky - z ni se pocita, kolik px je 1 jednotka V TOMHLE
        # spritu (a tim i polomer stinu; viz `postprocess_2x.px_na_jednotku`).
        report[f"{kind}_px_na_jednotku"] = sorted({m["px_na_jednotku"] for m in meta})
        report[f"{kind}_rovina_sirka_px"] = sorted({m["rovina_sirka_px"] for m in meta})
        report[f"{kind}_box_2x"] = {
            str(ident): [m["w"], m["h"]] for (_k, ident), m in zip(klice, meta)}
        report[f"{kind}_meritko_min"] = round(min(m["meritko"] for m in meta), 6)
        report[f"{kind}_meritko_max"] = round(max(m["meritko"] for m in meta), 6)

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

    klice_a, sprity_a, meta_a = davky["anim"]
    if len(sprity_a) != ac2.CHAR["dirs"] * ac2.CHAR["frames"]:
        raise SystemExit(f"anim framu {len(sprity_a)} != "
                         f"{ac2.CHAR['dirs'] * ac2.CHAR['frames']}")
    report.update({f"anim_{k}": v
                   for k, v in zapis_anim_sheets(sprity_a, klice_a, meta_a).items()})

    stranky_meta = []
    for stranka in platne:
        jmeno = Path(stranka).name
        stranky_meta.append({"file": stranka, "w": ac2.PAGE, "h": ac2.PAGE,
                             "count": sum(1 for z in zapisy if z["page"] == stranka)})
    manifest = {
        "version": 1,
        "generator": "tools/artgen/pack_atlas_2x.py",
        "page_size": ac2.PAGE,
        "pad": ac2.PAD,
        "source": {
            "pipeline": "tools/artgen (build_model_2x.py -> render_2x.py -> postprocess_2x.py)",
            "blender": "5.2.1 LTS (BLENDER_EEVEE, film_transparent, Fast-GI AO)",
            "render_px": ac2.RENDER, "px_per_unit": ac2.PX_PER_UNIT,
            "kamera": {"azimut_deg": ac2.CAM_AZIMUTH_DEG,
                       "elevace_deg": round(ac2.CAM_ELEVATION_DEG, 6),
                       "zrcadleni_x": ac2.MIRROR_X,
                       "svisle_roztazeni": round(ac2.VYSTRED_Y, 6)},
            "geometrie": "1 jednotka = 1 dlazdice = 88 px; kotva jako UO 2x "
                         "(ox=(w>>1)-44, oy=h-88)",
            "svetlo": "jedno smerove slunce + Fast-GI AO + kontaktni stin "
                      "(renderovany z kontaktni roviny, viz postprocess_2x.py)",
            "2x_kontrakt": ac2.souhrn(),
        },
        "pages": stranky_meta,
        "sprites": sorted(zapisy, key=lambda z: (z["kind"], z["id"])),
        "anim": {"file": "anim/anim-sheets.json", "pixels_decoded": True,
                 "id_klic": "body*1000 + action*100 + dir*10 + frame",
                 "smeru": ac2.CHAR["dirs"], "framu": ac2.CHAR["frames"],
                 "frame_ms": ac2.CHAR["frame_ms"],
                 "duvod": "2x vetev kresli JEN smer 0 (ZADANI-25 §9 odst. 2)"},
        "report": report,
    }
    ac1.zapis_manifest(OWN / "manifest.json", manifest)
    print(f"[pack2x] stranek {len(platne)}, spritu {len(zapisy)} -> {OWN/'manifest.json'}")
    for k in sorted(report):
        print(f"[pack2x]   {k} = {report[k]}")
    return zkontroluj(a.hash)


# ---------------------------------------------------------------------------
# brana
# ---------------------------------------------------------------------------
def _hash(cesta: Path) -> str:
    h = hashlib.sha256()
    h.update(cesta.read_bytes())
    return h.hexdigest()


def obsah_1x(zaklad: Path, kind: str, ident: int) -> tuple[int, int] | None:
    """Obsah (w, h) spritu z 1x sady, MERENY Z PIXELU ATLASU (ne z reportu).

    Duvod, proc z pixelu: report je tvrzeni vyrobce, kdezto atlas je to, co by
    si hra skutecne precetla. Kdyby se 1x sada mezitim zmenila, pomer 2x/1x
    vyjde z reality, ne z pameti.
    """
    m = json.loads((zaklad / "manifest.json").read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            img = Image.open(zaklad / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
            bb = img.split()[3].getbbox()
            if bb is None:
                return None
            return (bb[2] - bb[0], bb[3] - bb[1])
    return None


def zkontroluj(hash_out: bool) -> int:
    chyby: list[str] = []
    pocet = 0

    def kontrola(ok: bool, text: str) -> None:
        nonlocal pocet
        pocet += 1
        if not ok:
            chyby.append(text)

    cesta = OWN / "manifest.json"
    if not cesta.exists():
        print(f"[check2x] CHYBA: {cesta} neexistuje - neni co overovat")
        return 1
    data = json.loads(cesta.read_text(encoding="utf-8"))
    uo = ac1.uo_manifest(UO / "manifest.json")

    kontrola(data.get("page_size") == ac2.PAGE and data.get("pad") == ac2.PAD,
             "page_size/pad nejsou 2048/1")
    kontrola(data.get("source", {}).get("render_px") == ac2.RENDER,
             f"manifest netvrdi render {ac2.RENDER} px")

    # --- kontrakt: klice proti UO ------------------------------------------
    kontrola(set(data) == set(uo), f"klice manifestu se lisi od UO: "
             f"chybi {sorted(set(uo) - set(data))}, navic {sorted(set(data) - set(uo))}")
    klice = {k for s in data["sprites"] for k in s}
    kontrola(klice == KLICE_SPRITU_UO, f"klice spritu se lisi od UO: "
             f"chybi {sorted(KLICE_SPRITU_UO - klice)}, navic {sorted(klice - KLICE_SPRITU_UO)}")

    ocekavane = {("item", i["uo_id"]) for i in ac2.ITEMS} | \
                {("anim", ac2.anim_id(d, f)) for d in range(ac2.CHAR["dirs"])
                 for f in range(ac2.CHAR["frames"])}
    nalezene = {(s["kind"], s["id"]) for s in data["sprites"]}
    kontrola(nalezene == ocekavane,
             f"mnozina spritu se lisi: chybi {sorted(ocekavane - nalezene)[:6]}, "
             f"navic {sorted(nalezene - ocekavane)[:6]}")
    kontrola(len(data["sprites"]) == len(ocekavane) ==
             len(ac2.ITEMS) + ac2.CHAR["dirs"] * ac2.CHAR["frames"],
             f"pocet spritu {len(data['sprites'])} != ocekavanych "
             f"{len(ac2.ITEMS) + ac2.CHAR['dirs'] * ac2.CHAR['frames']}")

    # --- stranky a sprity ---------------------------------------------------
    stranky = {}
    for p in data["pages"]:
        c = OWN / p["file"]
        kontrola(c.exists(), f"chybi stranka {p['file']}")
        if c.exists():
            img = Image.open(c).convert("RGBA")
            stranky[p["file"]] = img
            kontrola(img.size == (ac2.PAGE, ac2.PAGE),
                     f"stranka {p['file']} ma {img.size}, ne ({ac2.PAGE}, {ac2.PAGE})")
    stin_px: dict[tuple, int] = {}
    obsah_2x: dict[tuple, tuple] = {}
    for s in data["sprites"]:
        img = stranky.get(s["page"])
        if img is None:
            continue
        kontrola(s["rect"] == [s["x"], s["y"], s["x"] + s["w"], s["y"] + s["h"]],
                 f"{s['kind']} {s['id']}: rect neni [x,y,x+w,y+h]")
        crop = img.crop(tuple(s["rect"]))
        alfa = np.array(crop)[:, :, 3]
        bb = crop.split()[3].getbbox()
        kontrola(bb is not None, f"{s['kind']} {s['id']}: prazdny sprite v atlase")
        if bb is None:
            continue
        # kotva: 2x vzorec UO
        kontrola(ac2.ofsahy(s["kind"], s["w"], s["h"]) == (s["ox"], s["oy"]),
                 f"{s['kind']} {s['id']}: kotva ({s['ox']},{s['oy']}) neni 2x vzorec UO "
                 f"{ac2.ofsahy(s['kind'], s['w'], s['h'])}")
        # obsah (bbox OBJEKTU) proti kotve a proti kontaktu. Objekt = plna alfa;
        # kontaktni stin je polopruhledny, takze do bboxu objektu nepatri.
        plna = alfa >= 200
        bb_obj = None
        if plna.any():
            ys, xs = np.nonzero(plna)
            bb_obj = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        kontrola(bb_obj is not None, f"{s['kind']} {s['id']}: neni plne nepruhledny obsah")
        if bb_obj is None:
            continue
        obsah_2x[(s["kind"], s["id"])] = (bb_obj[2] - bb_obj[0], bb_obj[3] - bb_obj[1])
        levy, horni, pravy, spodek = bb_obj
        stred = (levy + pravy - 1) / 2.0
        kontrola(abs(stred - s["w"] // 2) <= 1.0,
                 f"{s['kind']} {s['id']}: stred obsahu {stred} != kotva {s['w'] // 2}")
        pod = (s["h"] - ac2.GROUND_PX) - (spodek - 1)
        kontrola(-ac2.GROUND_PX <= pod <= 0,
                 f"{s['kind']} {s['id']}: obsah konci {pod:+d} px od kontaktu "
                 f"(povoleno -{ac2.GROUND_PX}..0)")
        # STIN: musi byt skutecne ve sprite. Kontaktni stin = polopruhledne tmave
        # pixely MIMO obsah objektu (kdyby render stinu chybel, je jich nula).
        polopruhledne = (alfa > 0) & (alfa < 200)
        px = int(polopruhledne.sum())
        stin_px[(s["kind"], s["id"])] = px
        kontrola(px > 0, f"{s['kind']} {s['id']}: ve sprite NENI kontaktni stin "
                         "(2x ma mit slunce + AO + stin pod objektem)")
    pocet_stinu = sum(1 for v in stin_px.values() if v > 0)
    kontrola(len(stin_px) > 0 and pocet_stinu == len(stin_px),
             f"stin ma jen {pocet_stinu}/{len(stin_px)} spritu")

    # --- MERENE MERITKO: kolik px je 1 svetova jednotka v hotovem spritu ------
    # ⚠ PUVODNI ZNENI TOHLE KONTROLY BYLO SPATNE a stoji za zapsani: chtelo
    # "1 jednotka = 88 px" (= TILE). NAMERENO 2026-10-10: neni to pravda a ani
    # to pravda byt nema - sprite se normalizuje na NAMERENY obsah UO
    # (`meritko`), ne na pevne meritko. Vyslo 68,4 px/jednotku u dyky a 82,7 px
    # u postavy (pro 2x; v 1x je pomer stejny). Kdyby to zustalo jako brana,
    # hlásila by chybu u spravneho artu (a "opravilo" by se tim, ze se rozbije
    # to, co funguje - presne ta past z `overovani`).
    #
    # Co se kontrolovat DA: ze stin (polomer v jednotkach) se do spritu VEJDE
    # nad kontaktni linku. Kdyby se sprajt skaloval o hodne jinak, stin by
    # podtekl pod kotvu a objekt by "visel".
    rep = data.get("report", {})
    for kind in ("item", "anim"):
        for pj in rep.get(f"{kind}_px_na_jednotku", []):
            r1_px = ac2.STIN_R1_JEDNOTEK * pj
            kontrola(r1_px <= ac2.GROUND_PX,
                     f"{kind}: polomer stinu {r1_px:.1f} px presahuje {ac2.GROUND_PX} px "
                     f"pod kontakt (px_na_jednotku={pj}) - stin by podtekl pod kotvu")
        if not rep.get(f"{kind}_px_na_jednotku"):
            kontrola(False, f"{kind}: v reportu neni px_na_jednotku - meritko "
                            "roviny se NEMERILO (nic neni uspech)")
    # A pomery, ktere jsou merene a maji se jen HLASIT (nejsou to brany):
    pj_item = (rep.get("item_px_na_jednotku") or [None])[0]
    pj_anim = (rep.get("anim_px_na_jednotku") or [None])[0]
    if pj_item and pj_anim:
        print(f"[check2x] meritko uvnitr spritu: dyka {pj_item} px/jednotku, "
              f"postava {pj_anim} px/jednotku -> postava je vuci dyce "
              f"{pj_anim / pj_item:.3f}x (MERENO, ne brana - viz MERENI.md)")

    # --- POMER 2x/1x: pozna omylem vyrenderovane 1x meritko -----------------
    if not (OWN1X / "manifest.json").exists():
        kontrola(False, f"chybi {OWN1X/'manifest.json'} - pomer 2x/1x se NEMERIL")
    else:
        pary = []
        for (kind, ident), (w2, h2) in sorted(obsah_2x.items()):
            o1 = obsah_1x(OWN1X, kind, ident)
            if o1 is None:
                kontrola(False, f"{kind} {ident}: v 1x sade neni - pomer se NEMERIL")
                continue
            pary.append((kind, ident, o1[1], h2))
        for kind, ident, h1, h2 in pary:
            pomer = h2 / float(h1)
            kontrola(abs(pomer - 2.0) <= POMER_TOL,
                     f"{kind} {ident}: obsah 2x je {pomer:.2f}x obsah 1x "
                     f"(cekam 2,0 +-{POMER_TOL}) - 2x {h2} px vs 1x {h1} px")
        if pary:
            prumer = sum(h2 / float(h1) for _k, _i, h1, h2 in pary) / len(pary)
            kontrola(abs(prumer - 2.0) <= POMER_TOL,
                     f"prumerny pomer obsahu 2x/1x = {prumer:.3f} (cekam 2,0 +-{POMER_TOL})")

    # --- seam ---------------------------------------------------------------
    for s in data["sprites"]:
        if s["kind"] == "item":
            kontrola(ac1.uo_sprite(uo, "item", s["id"]) is not None,
                     f"item {s['id']}: v UO manifestu neni - neni co nahradit")
    listy = OWN / "anim" / "anim-sheets.json"
    kontrola(listy.exists(), "chybi assets/own2x/anim/anim-sheets.json")
    if listy.exists():
        ld = json.loads(listy.read_text(encoding="utf-8"))
        uo_anim = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
        kontrola(set(ld) == set(uo_anim), "klice anim listu se lisi od UO")
        kontrola(len(ld["sprites"]) == ac2.CHAR["dirs"],
                 f"anim listu {len(ld['sprites'])} != {ac2.CHAR['dirs']}")
        for k, v in ld["sprites"].items():
            kontrola(k in uo_anim["sprites"], f"{k}: klic v UO anim listech neni")
            kontrola(len(v["frames"]) == ac2.CHAR["frames"], f"{k}: framu neni 8")
            kontrola((OWN / "anim" / v["file"]).exists(), f"{k}: chybi PNG {v['file']}")
            for fr in v["frames"]:
                kontrola(fr["cy"] == -ac2.GROUND_PX,
                         f"{k}: kontaktni bod neni {ac2.GROUND_PX} px nad spodni hranou")
                kontrola(fr["rect"][2] - fr["rect"][0] == fr["w"]
                         and fr["rect"][3] - fr["rect"][1] == fr["h"],
                         f"{k}: rect framu neni [x,y,x+w,y+h]")

    # --- police: prekryvy a mezery -----------------------------------------
    police: dict = {}
    for s in data["sprites"]:
        police.setdefault((s["page"], s["y"]), []).append(s)
    for (_stranka, _y), v in police.items():
        v.sort(key=lambda s: s["x"])
        for a1, b1 in zip(v, v[1:]):
            kontrola(a1["x"] + a1["w"] <= b1["x"],
                     f"prekryv {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']}")
            kontrola(b1["x"] - (a1["x"] + a1["w"]) == ac2.PAD,
                     f"mezera mezi {a1['kind']} {a1['id']} a {b1['kind']} {b1['id']} "
                     f"neni {ac2.PAD}")

    if hash_out:
        print(f"[check2x] sha256(manifest.json) = {_hash(cesta)}")
    print(f"[check2x] {pocet} kontrol, {len(chyby)} chyb")
    for ch in chyby[:15]:
        print(f"[check2x] CHYBA: {ch}")
    return 1 if chyby else 0


if __name__ == "__main__":
    raise SystemExit(main())
