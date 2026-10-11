#!/usr/bin/env python3
"""G15 check-own-art - vlastni art se prepina PO KUSECH (docs/08 §8.2).

Proc tahle brana existuje: `render.textures` a `render.anim` umi od 2026-10-11
indexovat vlastni vrstvy PRED UO manifestem, takze pro (kind, id) z `assets/own-art.json`
vyhraje vlastni sprite a vsechno ostatni zustane z `assets/uo/`. To je tvrzeni
o CHOVANI, ne o pritomnosti souboru - pouhy fakt, ze `assets/own-lit/manifest.json`
existuje, nedokazuje, ze ho hra pouziva, ani ze `offset()` jde ze STEJNEHO
zaznamu jako textura (`tools/artgen/SEAM.md` §2 bod 2).

Brana proto spousti sondu `tools/gates/own_art_probe.gd`, ktera se REALNE zepta
`texture()`, `offset()`, `page_path()` a `sheet_file()`, a jeji vystup porovnava
s manifesty na disku (nezavisly zdroj). Sonda se jedna tez bez vrstev
(`off_*`), takze se dokazuje i to, ze prepinac OPRAVDU prepina - kdyby vysly
stejne hodnoty, seam nic neprepnul.

Kontroluje se:
  K1 konfigurace `assets/own-art.json` je bez chyb a ma vrstvy,
  K2 kazde vlastni id ma texturu z VLASTNI stranky a region+offset z VLASTNIHO
     manifestu (ne z UO),
  K3 id bez vlastniho artu ma PRESNE totez co s vypnutym vlastnim artem
     (fallback se netyka niceho, co vlastni sada nema),
  K4 animace: klic z vlastni sady je vlastni, klic, ktery vlastni sada nema
     (dnes beh), zustava z UO,
  K5 prepinac: s vypnutym vlastnim artem se kazde vlastni id zmeni na UO
     (jinak by "vlastni vyhrava" bylo jen tvrzeni v komentari).

V CI nejsou `assets/uo/` (jsou v .gitignore), takze se meri jen K1 a K2/K4 pro
vlastni cast a zbytek je viditelne NEMERENO (docs/08 §8.4) - nikdy zelena.

Spousteni:
  python tools/gates/check-own-art.py [--root .] [--json cesta]
  python tools/gates/check-own-art.py --self-test
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, godot_run, load_json,
)

NAME = "check-own-art"
CONFIG = "assets/own-art.json"
UO_MANIFEST = "assets/uo/manifest.json"
PROBE = "tools/gates/own_art_probe.gd"
ITEM_OFFSET = 0x4000
TEXMAP_OFFSET = 0x10000
# Id bez vlastniho artu, na kterych se meri fallback. Cisla jsou z produkce:
# 1004 = trava u Britainu (kde hrac stoji), 0x4E75 = batoh ze startovni sady.
FALLBACK_IDS = (1004, 0x4E75)


def art_id(kind: str, ident: int) -> int:
    if kind == "land":
        return ident
    if kind == "item":
        return ident + ITEM_OFFSET
    if kind == "texmap":
        return ident + TEXMAP_OFFSET
    return -1


def nacti_manifest(cesta: Path) -> dict[int, dict]:
    """art_id -> {page, rect, offset} z manifestu (nezavisly zdroj ocekavanych hodnot)."""
    out: dict[int, dict] = {}
    data = load_json(cesta)
    for sprite in data.get("sprites", []):
        if not isinstance(sprite, dict):
            continue
        kind = str(sprite.get("kind", ""))
        ident = int(sprite.get("id", -1))
        aid = art_id(kind, ident)
        if aid < 0 or aid in out:
            continue
        out[aid] = {
            "page": str(sprite.get("page", "")),
            "rect": "%d,%d,%d,%d" % (int(sprite.get("x", 0)), int(sprite.get("y", 0)),
                                     int(sprite.get("w", 0)), int(sprite.get("h", 0))),
            "offset": "%d,%d" % (int(sprite.get("ox", 0)), int(sprite.get("oy", 0))),
            "file": str(sprite.get("file", "")),
        }
    return out


def nacti_vrstvy(root: Path, gate: Gate) -> tuple[list[dict], dict[int, dict], dict[int, dict]]:
    """Vrati (vrstvy z konfigurace, ocekavane hodnoty z vlastnich manifestu,
    vlastni id -> jmeno vrstvy)."""
    cesta = root / CONFIG
    if not cesta.exists():
        gate.error(f"{CONFIG} chybi - neni co prepinat (vlastni art by se nikdy nepouzil)")
        return [], {}, {}
    try:
        data = load_json(cesta)
    except Exception as exc:
        gate.error(f"{CONFIG} se necte ({exc})")
        return [], {}, {}
    vrstvy = data.get("layers", [])
    if not isinstance(vrstvy, list) or not vrstvy:
        gate.error(f"{CONFIG} nema zadnou vrstvu")
        return [], {}, {}
    ocekavane: dict[int, dict] = {}
    vrstva_id: dict[int, str] = {}
    for i, vrstva in enumerate(vrstvy):
        if not isinstance(vrstva, dict):
            gate.error(f"{CONFIG}: vrstva {i} neni slovnik")
            continue
        jmeno = str(vrstva.get("name", ""))
        # Cesty v konfiguraci jsou `res://...` (cte je Godot) - na disk se
        # prekladaji odstranenim prefixu. Kdo to neudela, hleda slozku "res:".
        manifest = root / str(vrstva.get("manifest", "")).replace("res://", "")
        if not manifest.exists():
            gate.error(f"{CONFIG}: vrstva '{jmeno}' - manifest {manifest} neexistuje")
            continue
        zaznamy = nacti_manifest(manifest)
        sprites = vrstva.get("sprites", {})
        for kind, ids in sprites.items():
            for ident in ids:
                aid = art_id(str(kind), int(ident))
                if aid < 0 or aid not in zaznamy:
                    gate.error(f"{CONFIG}: vrstva '{jmeno}' uvadi {kind} {ident}, "
                               f"ale v manifestu neni")
                    continue
                if aid in ocekavane:
                    gate.error(f"{CONFIG}: {aid} je ve dvou vrstvach - druha by se tise ignorovala")
                    continue
                z = dict(zaznamy[aid])
                z["prefix"] = str(manifest.parent.relative_to(root)).replace("\\", "/") + "/"
                ocekavane[aid] = z
                vrstva_id[aid] = jmeno
    if not ocekavane:
        gate.error(f"{CONFIG}: zadne vlastni id se neda overit (brana by merila prazdno)")
    return vrstvy, ocekavane, vrstva_id


def parse_probe(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"\[probe\]\s+(?P<name>[A-Za-z0-9_]+)=(?P<value>.*)$", line.strip())
        if m:
            out[m.group("name")] = m.group("value")
    return out


def cisla(text: str) -> list[int]:
    out: list[int] = []
    for cast in str(text).split(","):
        cast = cast.strip()
        if cast != "":
            out.append(int(cast))
    return out


def check_mereni(root: Path, gate: Gate, mereni: dict[str, str]) -> None:
    """Porovna vystup sondy s manifesty na disku. Vstup je hotovy slovnik mereni,
    aby slo volat i ze self-testu bez Godotu."""
    vrstvy, ocekavane, vrstva_id = nacti_vrstvy(root, gate)
    gate.measure("vrstvy", len(vrstvy))
    gate.measure("cfg_ok", mereni.get("cfg_ok"))
    gate.measure("cfg_errors", mereni.get("cfg_errors"))
    if mereni.get("cfg_ok") != "1" or mereni.get("cfg_errors") not in ("0", None):
        gate.error("K1: konfigurace vlastniho artu hlasi chyby "
                   f"(cfg_ok={mereni.get('cfg_ok')}, cfg_errors={mereni.get('cfg_errors')})")
    if not ocekavane:
        return

    ma_uo = (root / UO_MANIFEST).exists()
    uo = nacti_manifest(root / UO_MANIFEST) if ma_uo else {}
    gate.measure("vlastnich_id", len(ocekavane))

    # --- K2: vlastni id kresli z vlastni stranky a s vlastnim offsetem ---
    zkontrolovano = 0
    for aid, z in sorted(ocekavane.items()):
        if mereni.get(f"on_{aid}") != "tex":
            gate.error(f"K2: art {aid} ({vrstva_id[aid]}) se nenacetl "
                       f"({mereni.get(f'on_{aid}')})")
            continue
        zkontrolovano += 1
        if mereni.get(f"on_isown_{aid}") != "1":
            gate.error(f"K2: art {aid} neni oznaceny jako vlastni (is_own=0)")
        page = mereni.get(f"on_page_{aid}", "")
        if not page.endswith("/" + z["page"]) or "assets/uo/" in page:
            gate.error(f"K2: art {aid} ma stranku '{page}', ocekavana z vrstvy "
                       f"'{vrstva_id[aid]}' (…/{z['page']})")
        if mereni.get(f"on_region_{aid}") != z["rect"]:
            gate.error(f"K2: art {aid} ma region {mereni.get(f'on_region_{aid}')}, "
                       f"manifest vrstvy '{vrstva_id[aid]}' rika {z['rect']}")
        if mereni.get(f"on_offset_{aid}") != z["offset"]:
            gate.error(f"K2: art {aid} ma offset {mereni.get(f'on_offset_{aid}')}, "
                       f"manifest rika {z['offset']} - textura a offset musi byt ze STEJNEHO zaznamu")
    gate.measure("vlastnich_zkontrolovano", zkontrolovano)

    # --- K5: prepinac opravdu prepina (off = cely UO) ---
    if not ma_uo:
        gate.measure("fallback", "NEMERENO (chybi assets/uo)")
        gate.skip("assets/uo/ nejsou (v CI chybi) - fallback a prepinac NEMERENY (docs/08 §8.4)")
        return
    prepnuto = 0
    for aid in sorted(ocekavane):
        z = uo.get(aid)
        if z is None:
            gate.error(f"K5: art {aid} neni v UO manifestu - 'nahrazeni' by bylo pridani "
                       "(SEAM.md §3 invariant 1)")
            continue
        if mereni.get(f"off_page_{aid}", "").find("assets/uo/") < 0:
            gate.error(f"K5: s vypnutym vlastnim artem ma {aid} stranku "
                       f"'{mereni.get(f'off_page_{aid}')}' - ceka se assets/uo/")
            continue
        if mereni.get(f"off_region_{aid}") != z["rect"] or mereni.get(f"off_offset_{aid}") != z["offset"]:
            gate.error(f"K5: s vypnutym vlastnim artem ma {aid} region/offset "
                       f"{mereni.get(f'off_region_{aid}')}/{mereni.get(f'off_offset_{aid}')}, "
                       f"UO manifest rika {z['rect']}/{z['offset']}")
            continue
        if mereni.get(f"on_page_{aid}") == mereni.get(f"off_page_{aid}") \
                and mereni.get(f"on_region_{aid}") == mereni.get(f"off_region_{aid}"):
            gate.error(f"K5: art {aid} je se zapnutym i vypnutym vlastnim artem STEJNY - "
                       "prepinac nic neprepnul")
            continue
        prepnuto += 1
    gate.measure("prepnuto", prepnuto)

    # --- K3: fallback se netyka niceho, co vlastni sada nema ---
    for aid in FALLBACK_IDS:
        if aid in ocekavane:
            gate.error(f"K3: testovaci fallback id {aid} je omylem ve vlastni sade")
            continue
        for slozka in ("page", "region", "offset"):
            on, off = mereni.get(f"on_{slozka}_{aid}"), mereni.get(f"off_{slozka}_{aid}")
            if on != off:
                gate.error(f"K3: id {aid} bez vlastniho artu se zmenil ({slozka}: '{on}' vs '{off}')")
        if "assets/uo/" not in str(mereni.get(f"on_page_{aid}", "")):
            gate.error(f"K3: id {aid} bez vlastniho artu nebere art z assets/uo/ "
                       f"('{mereni.get(f'on_page_{aid}')}')")
    gate.measure("fallback_id", ",".join(str(i) for i in FALLBACK_IDS))

    # --- K4: animace po klicich ---
    if "anim_own_count" not in mereni:
        gate.error("K4: sonda nehlasila animace - kontrola NEPROBĚHLA")
        return
    anim_vlastnich = 0
    for vrstva in vrstvy:
        anim_cesta = str(vrstva.get("anim") or "").replace("res://", "")
        cesta = root / anim_cesta
        if anim_cesta == "" or not cesta.exists():
            continue
        data = load_json(cesta)
        for klic, zaznam in data.get("sprites", {}).items():
            if zaznam.get("frames"):
                anim_vlastnich += 1
    gate.measure("anim_vlastnich_klicu", anim_vlastnich)
    if int(mereni.get("anim_own_count", "0")) != anim_vlastnich:
        gate.error(f"K4: animaci z vlastni vrstvy je {mereni.get('anim_own_count')}, "
                   f"v anim listech je {anim_vlastnich} klicu")
    for d in range(8):
        if mereni.get(f"anim_walk_own_{d}") != "1":
            gate.error(f"K4: chuze smer {d} NENI z vlastni vrstvy (vlastni sada ji ma)")
    if mereni.get("anim_act_0_own") != "1":
        gate.error("K4: chuze (akce 0) neni z vlastni vrstvy - `play()` by ji vzal z UO")
    # FALLBACK ANIMACE: vlastni sada dnes pokryva jen chuzi, takze musi existovat
    # akce, ktera z ni NENI a pritom se vykresli - a to z `assets/uo/`. Ktera akce
    # to je, se NEHADA: cislo skupiny pro akci je od M5 dane manifestem (`groups`)
    # a muze se zmenit, takze se hleda LIBOVOLNA takova akce.
    fallback_akce = ""
    for a in range(1, 5):
        if mereni.get(f"anim_act_{a}_own") != "0":
            continue
        if mereni.get(f"anim_act_{a}_ok") != "1":
            continue
        if "assets/uo/" not in str(mereni.get(f"anim_act_{a}_file", "")):
            continue
        fallback_akce = str(a)
        break
    if fallback_akce == "":
        gate.error("K4: zadna akce, kterou vlastni sada nema, se nevykresli z assets/uo/ "
                   "- buď je vlastni sada pokryva vsechno (pak sem patri jina), nebo "
                   "fallback animaci nefunguje")
    gate.measure("anim_fallback_akce", fallback_akce if fallback_akce != "" else "ZADNA")
    if "assets/uo/" not in str(mereni.get("anim_off_walk_file_0", "")):
        gate.error(f"K4: s vypnutym vlastnim artem ma chuze list "
                   f"'{mereni.get('anim_off_walk_file_0')}', ceka se assets/uo/")


def run_probe(root: Path) -> tuple[int, dict[str, str], str]:
    kod, vystup = godot_run(root, ["--script", "res://" + PROBE], timeout=300)
    return kod, parse_probe(vystup), vystup


def check(root: Path, gate: Gate) -> None:
    probe = root / PROBE
    if not probe.exists():
        gate.pending(f"chybi {PROBE} - neni cim zmerit chovani seamu")
        return
    if not (root / CONFIG).exists():
        gate.error(f"{CONFIG} chybi - vlastni art by se nikdy nepouzil")
        return
    kod, mereni, vystup = run_probe(root)
    gate.measure("probe_exit", kod)
    if not mereni:
        gate.error(f"sonda {PROBE} nevydala zadne mereni (exit {kod})")
        for radek in vystup.splitlines()[-5:]:
            gate.note(radek.strip()[:160])
        return
    if mereni.get("uo_manifest") != "1":
        gate.note("sonda: chybi " + str(mereni.get("chybi", UO_MANIFEST)))
    check_mereni(root, gate, mereni)


# --- self-test -------------------------------------------------------------

def selftest() -> int:
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-own-art"
    shutil.rmtree(base, ignore_errors=True)

    def zapis(cesta: Path, data) -> None:
        cesta.parent.mkdir(parents=True, exist_ok=True)
        cesta.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    def fixture(label: str, bez_uo: bool = False) -> Path:
        root = base / label
        zapis(root / CONFIG, {
            "version": 1,
            "layers": [{"name": "lit", "manifest": "res://assets/own-lit/manifest.json",
                        "anim": "res://assets/own-lit/anim/anim-sheets.json",
                        "sprites": {"land": [3], "item": [3717]}}],
        })
        zapis(root / "assets" / "own-lit" / "manifest.json", {"sprites": [
            {"kind": "land", "id": 3, "page": "atlas/land_0.png", "x": 0, "y": 0,
             "w": 44, "h": 44, "ox": 0, "oy": 0},
            {"kind": "item", "id": 3717, "page": "atlas/item_0.png", "x": 53, "y": 0,
             "w": 28, "h": 36, "ox": -8, "oy": -8},
        ]})
        zapis(root / "assets" / "own-lit" / "anim" / "anim-sheets.json", {"sprites": {
            "400/0/0": {"file": "a.png", "frames": [{"cx": 12, "cy": -22, "w": 24,
                                                     "h": 76, "rect": [0, 0, 24, 76]}]},
        }})
        if not bez_uo:
            zapis(root / "assets" / "uo" / "manifest.json", {"sprites": [
                {"kind": "land", "id": 3, "page": "atlas/land_0.png", "x": 135, "y": 0,
                 "w": 44, "h": 44, "ox": 0, "oy": 0},
                {"kind": "land", "id": 1004, "page": "atlas/land_0.png", "x": 1350, "y": 810,
                 "w": 44, "h": 44, "ox": 0, "oy": 0},
                {"kind": "item", "id": 3717, "page": "atlas/item_45.png", "x": 988, "y": 1872,
                 "w": 44, "h": 38, "ox": 0, "oy": -6},
                {"kind": "item", "id": 3701, "page": "atlas/item_2.png", "x": 10, "y": 20,
                 "w": 30, "h": 30, "ox": 1, "oy": 2},
            ]})
        return root

    def mereni(label: str, bez_uo: bool = False, **zmeny) -> tuple[Path, dict[str, str]]:
        root = fixture(label, bez_uo=bez_uo)
        # Znamy SPRAVNY stav: presne to, co namerila sonda na realnem strome.
        m = {
            "cfg_ok": "1", "cfg_errors": "0", "uo_manifest": "1",
            "on_3": "tex", "on_page_3": "res://assets/own-lit/atlas/land_0.png",
            "on_region_3": "0,0,44,44", "on_offset_3": "0,0", "on_isown_3": "1",
            "off_3": "tex", "off_page_3": "res://assets/uo/atlas/land_0.png",
            "off_region_3": "135,0,44,44", "off_offset_3": "0,0", "off_isown_3": "0",
            "on_20101": "tex", "on_page_20101": "res://assets/own-lit/atlas/item_0.png",
            "on_region_20101": "53,0,28,36", "on_offset_20101": "-8,-8", "on_isown_20101": "1",
            "off_20101": "tex", "off_page_20101": "res://assets/uo/atlas/item_45.png",
            "off_region_20101": "988,1872,44,38", "off_offset_20101": "0,-6", "off_isown_20101": "0",
            "on_1004": "tex", "on_page_1004": "res://assets/uo/atlas/land_0.png",
            "on_region_1004": "1350,810,44,44", "on_offset_1004": "0,0",
            "off_1004": "tex", "off_page_1004": "res://assets/uo/atlas/land_0.png",
            "off_region_1004": "1350,810,44,44", "off_offset_1004": "0,0",
            "on_20085": "tex", "on_page_20085": "res://assets/uo/atlas/item_2.png",
            "on_region_20085": "10,20,30,30", "on_offset_20085": "1,2",
            "off_20085": "tex", "off_page_20085": "res://assets/uo/atlas/item_2.png",
            "off_region_20085": "10,20,30,30", "off_offset_20085": "1,2",
            "anim_own_count": "1", "anim_sprites": "2",
            "anim_act_0_own": "1", "anim_act_0_ok": "1",
            "anim_act_0_file": "res://assets/own-lit/anim/a.png",
            "anim_act_1_own": "0", "anim_act_1_ok": "1",
            "anim_act_1_file": "res://assets/uo/anim/anim-400-4-1.png",
            "anim_act_2_own": "0", "anim_act_2_ok": "1",
            "anim_act_2_file": "res://assets/uo/anim/anim-400-2-1.png",
            "anim_act_3_own": "0", "anim_act_3_ok": "1",
            "anim_act_3_file": "res://assets/uo/anim/anim-400-2-1.png",
            "anim_act_4_own": "0", "anim_act_4_ok": "1",
            "anim_act_4_file": "res://assets/uo/anim/anim-400-4-1.png",
            "anim_off_own_count": "0",
            "anim_off_walk_file_0": "res://assets/uo/anim/anim-400-0-1.png",
        }
        for d in range(8):
            m[f"anim_walk_own_{d}"] = "1"
        m.update(zmeny)
        return root, m

    def spust(root: Path, m: dict[str, str]) -> int:
        g = Gate("check-own-art/selftest")
        check_mereni(root, g, m)
        return g.verdict()

    pripady = [
        ("dobry", *mereni("dobry"), OK),
        ("vlastni_se_nevyhralo", *mereni("vlastni_se_nevyhralo",
                                          on_page_20101="res://assets/uo/atlas/item_45.png"), VADA),
        ("offset_z_uo", *mereni("offset_z_uo", on_offset_20101="0,-6"), VADA),
        ("fallback_se_zmenil", *mereni("fallback_se_zmenil",
                                       on_page_1004="res://assets/own-lit/atlas/land_0.png"), VADA),
        ("prepinac_neprepnul", *mereni("prepinac_neprepnul",
                                       off_page_20101="res://assets/own-lit/atlas/item_0.png"), VADA),
        ("walk_neni_vlastni", *mereni("walk_neni_vlastni", anim_act_0_own="0"), VADA),
        ("fallback_animace_neni", *mereni("fallback_animace_neni",
                                          anim_act_1_file="",
                                          anim_act_2_file="",
                                          anim_act_3_file="",
                                          anim_act_4_file=""), VADA),
        ("anim_own_malo", *mereni("anim_own_malo", anim_own_count="0"), VADA),
        ("chybejici_uo", *mereni("chybejici_uo", bez_uo=True, uo_manifest="0"), NEMERENO),
    ]

    bad = 0
    for pripad in pripady:
        label, root, m, expected = pripad[0], pripad[1], pripad[2], pripad[3]
        got = spust(root, m)
        ok = got == expected
        if not ok:
            bad += 1
        print(f"[{NAME}] self-test {label}: ocekavano {expected}, vyslo {got}"
              f" {'OK' if ok else 'CHYBA'}")
    print(f"[{NAME}] self-test: {len(pripady)} pripadu, {bad} chyb")
    return VADA if bad else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G15 kontrola seamu vlastniho artu")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    gate = Gate(NAME)
    check(Path(args.root).resolve(), gate)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
