#!/usr/bin/env python3
"""G17 check-land-variants - dlazdice se vybiraji VARIANTNE (docs/08 §8.2).

Proc tahle brana existuje: do 2026-10-11 platilo "jedno `land` id = jedna
dlazdice", takze se dlazba na velke plose opakovala a rozmanitost se musela
kupovat dalsimi a dalsimi id. `assets/own-art.json` proto umi u vrstvy
nepovinny klic `groups` ("tato id jsou jeden material") a `render.textures`
vybira variantu CISTE podle souradnic bunky.

Tvrzeni, ktera se tu meri (a proc to nejde "jen prectist z kodu"):

  K1  fixture (16 variant) se vubec sestavi - bez toho by vsechno ostatni
      bylo zelene nad prazdnem,
  K2  KALIBRACE: bez `groups` musi podil dlazdic shodnych s pravym sousedem
      (lag 1) vyjit PRESNE 100 % - to je dnešní chovani; kdyby vyslo min,
      meri se neco jineho a cislo z K3 nic neznamena,
  K3  s 16 variantami musi podil spadnout POD 20 % a pouzit se >= 8 variant,
  K4  DETERMINISMUS: dva nezavisle behy (dve cache, dva seznamy) daji stejny
      sha256 poradi variant - nahoda za behu by rozbila replaye i snimky v CI,
  K5  TEXTURA I OFFSET JDOU ZE STEJNEHO ZAZNAMU (fixture ma u kazde varianty
      jiny offset - v produkci maji vsechny land arty ox = oy = 0, takze by se
      to na nich dokazat nedalo),
  K6  bez `groups` je chovani PRESNE dnesni (varianta vraci vstup),
  K7  id mimo skupinu vraci vstup,
  K8  DAVKA (`render/chunk_mesh`) dostane STEJNE varianty: pocet slotu runtime
      atlasu je 1 (bez skupin) vs 16 (se skupinami) - kdyby brala puvodni id,
      zustal by 1 a kreslici cesty by se rozezly,
  K9  `stats()` hlasi pocet skupin a clenu,
  K10 konfigurace na disku (`assets/own-art.json`) je s `groups` KONZISTENTNI:
      clen skupiny musi byt v `sprites` TE SAME vrstvy, skupina musi mit aspon
      2 cleny a zadne id nesmi byt ve dvou skupinach. Kdyz produkce `groups`
      nema, je to POZNAMKA (ne ticho) - mechanika je hotova, ale nepouzita.

V CI nejsou `assets/uo/`; sonda si fixture vyrabi sama, takze G17 meri VZDY
(i v CI) - zadny SKIP.

Spousteni:
  python tools/gates/check-land-variants.py [--root .] [--json cesta]
  python tools/gates/check-land-variants.py --self-test
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, godot_run, load_json,
)

NAME = "check-land-variants"
PROBE = "tools/gates/land_variants_probe.gd"
CONFIG = "assets/own-art.json"
GRID = 20
VARIANT = 16                 # pocet variant ve fixture sondy
STROP_PODILU = 20.0          # zadani §4 A: s N >= 16 musi byt shoda < 20 %
MIN_RUZNYCH = 8              # aspon polovina variant se musi opravdu pouzit
KINDS = ("land", "item", "texmap")


def parse_probe(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"\[variants\]\s+(?P<name>[A-Za-z0-9_]+)=(?P<value>.*)$", line.strip())
        if m:
            out[m.group("name")] = m.group("value")
    return out


def cislo(mereni: dict[str, str], klic: str, gate: Gate) -> float | None:
    """Cislo z mereni; chybejici nebo neciselna hodnota je VADA (ne nula)."""
    if klic not in mereni:
        gate.error(f"K: sonda nehlasila '{klic}' - kontrola NEPROBĚHLA")
        return None
    try:
        return float(mereni[klic])
    except ValueError:
        gate.error(f"K: '{klic}' neni cislo ('{mereni[klic]}')")
        return None


def zkontroluj_mereni(gate: Gate, mereni: dict[str, str]) -> None:
    """K1-K9 nad vystupem sondy. Vstup je hotovy slovnik, aby sel volat i ze
    self-testu bez Godotu."""
    for klic in ("cfg_ok_bez", "cfg_ok_se"):
        if mereni.get(klic) != "1":
            gate.error(f"K1: fixture se nesestavila ({klic}={mereni.get(klic)}, "
                       f"chyby: {mereni.get('cfg_error', '?')})")
    for klic in ("cfg_chyb_bez", "cfg_chyb_se"):
        if mereni.get(klic) not in ("0", None):
            gate.error(f"K1: fixture hlasi chyby konfigurace ({klic}={mereni.get(klic)})")
    if "chyba" in mereni:
        gate.error(f"K1: sonda hlasi vadu fixture: {mereni['chyba']}")

    # --- K2: kalibrace na dnesnim chovani -----------------------------------
    n1_landu = cislo(mereni, "n1_v_seznamu", gate)
    n1_podil = cislo(mereni, "n1_lag1_pct", gate)
    if n1_landu != GRID * GRID:
        gate.error(f"K2: bez `groups` ma 20x20 plocha {n1_landu} land dlazdic, "
                   f"ceka se {GRID * GRID} - meri se jina plocha, nez se mysli")
    if n1_podil is not None and abs(n1_podil - 100.0) > 0.001:
        gate.error(f"K2: bez `groups` ma {n1_podil:.2f} % dlazdic shodny sprite se sousedem, "
                   "ceka se PRESNE 100 % (dnesni chovani) - kalibrace metriky nesedi, "
                   "takze cislo z K3 nic nedokazuje")
    n1_perioda = cislo(mereni, "n1_lagN_pct", gate)
    if n1_perioda is not None and abs(n1_perioda - 100.0) > 0.001:
        gate.error(f"K2: bez `groups` ma {n1_perioda:.2f} % dlazdic shodny sprite se sousedem "
                   f"o {VARIANT} bunek dal, ceka se 100 % - kalibrace periody nesedi")
    if mereni.get("n1_ruznych") != "1":
        gate.error(f"K2: bez `groups` ma plocha {mereni.get('n1_ruznych')} ruznych spritu, ceka se 1")

    # --- K3: zmizelo opakovani ----------------------------------------------
    n16_podil = cislo(mereni, "n16_lag1_pct", gate)
    n16_ruznych = cislo(mereni, "n16_ruznych", gate)
    if mereni.get("n16_v_seznamu") != str(GRID * GRID):
        gate.error(f"K3: se skupinami ma plocha {mereni.get('n16_v_seznamu')} land dlazdic, "
                   f"ceka se {GRID * GRID}")
    if n16_podil is not None and not n16_podil < STROP_PODILU:
        gate.error(f"K3: se {VARIANT} variantami je podil se sousedem {n16_podil:.2f} %, "
                   f"ceka se < {STROP_PODILU} % - varianty se nevybiraji (nebo se vybiraji porad stejne)")
    if n16_ruznych is not None and n16_ruznych < MIN_RUZNYCH:
        gate.error(f"K3: pouzilo se jen {n16_ruznych:.0f} z {VARIANT} variant "
                   f"(ceka se >= {MIN_RUZNYCH})")

    # --- K3b: ZADNA PERIODA ZAROVNANA S MRIZKOU ------------------------------
    # Vlastni past, namERena 2026-10-11 (`_analyza/lv-mix.py`): samotne
    # `x*HASH_X ^ y*HASH_Y` ma pro `n` = mocninu dvou `index(x + n, y) ==
    # index(x, y)` ve 100 % pripadu - vzor se opakuje kazdych `n` bunek.
    # Bez teto kontroly by takova "varianta" prosla (lag 1 je u ni 0 %).
    n16_perioda = cislo(mereni, "n16_lagN_pct", gate)
    if n16_perioda is not None and not n16_perioda < STROP_PODILU:
        gate.error(f"K3b: se {VARIANT} variantami se vzor opakuje s periodou {VARIANT} bunek "
                   f"v {n16_perioda:.2f} % pripadu (ceka se < {STROP_PODILU} %) - vyber varianty "
                   "je zarovnany s mrizkou (hash nemicha nizke bity)")

    # --- K4: determinismus ---------------------------------------------------
    sha_a, sha_b = mereni.get("sha_a", ""), mereni.get("sha_b", "")
    if len(sha_a) != 64 or len(sha_b) != 64:
        gate.error(f"K4: sha256 variant chybi nebo nema 64 znaku ('{sha_a}', '{sha_b}')")
    elif sha_a != sha_b:
        gate.error(f"K4: dva nezavisle behy daji JINY sha256 ({sha_a[:12]} vs {sha_b[:12]}) "
                   "- vyber varianty zavisi na necem jinem nez na souradnicich")
    if mereni.get("determinismus") != "1":
        gate.error(f"K4: sonda hlasi determinismus={mereni.get('determinismus')}")

    # --- K5: textura i offset ze STEJNEHO zaznamu ----------------------------
    if mereni.get("offset_ze_stejneho") != "1":
        gate.error("K5: offset varianty NENI z téhož zaznamu jako textura "
                   f"(offset_ze_stejneho={mereni.get('offset_ze_stejneho')}) - sprite by sedel vedle")
    if mereni.get("textur_null") not in ("0", None):
        gate.error(f"K5: {mereni.get('textur_null')} variant dalo null texturu (merilo by se prazdno)")
    offset_ruznych = cislo(mereni, "offset_ruznych", gate)
    if offset_ruznych is not None and offset_ruznych < 2:
        gate.error(f"K5: fixture ma jen {offset_ruznych:.0f} ruzny offset - "
                   "mereni 'offset ze stejneho zaznamu' by nic nedokazalo")
    offset_mimo = cislo(mereni, "offset_mimo_puvodni", gate)
    if offset_mimo is not None and offset_mimo <= 0:
        gate.error("K5: ani jednou se offset varianty nelisi od offsetu puvodniho id - "
                   "offset se bere z originalu, ne z VYBRANEHO zaznamu")

    # --- K6/K7: dnesni chovani bez skupin a pro id mimo skupinu --------------
    if mereni.get("bez_skupin_id") != "1":
        gate.error("K6: bez `groups` neni varianta TOTEZ co dnes (textura nebo id se zmenily)")
    if mereni.get("stats_bez_groups") not in ("0", None) or mereni.get("stats_bez_members") not in ("0", None):
        gate.error(f"K6: bez `groups` hlasi stats() skupiny "
                   f"({mereni.get('stats_bez_groups')}/{mereni.get('stats_bez_members')})")
    if mereni.get("mimo_skupinu") != "1":
        gate.error("K7: id mimo skupinu se zmenilo (nesmi se 'priclenit' nasilim)")
    if mereni.get("variant_index_rozsah") != "1":
        gate.error("K8: variant_index vraci index mimo rozsah 0..n-1")

    # --- K8b: davka ma STEJNE varianty jako seznam ---------------------------
    if mereni.get("mesh_slotu_n1") not in ("1", None):
        gate.error(f"K8: davka bez skupin ma {mereni.get('mesh_slotu_n1')} slotu land artu, ceka se 1")
    if mereni.get("mesh_slotu_n16") != str(VARIANT):
        gate.error(f"K8: davka ({PROBE}) ma {mereni.get('mesh_slotu_n16')} slotu, "
                   f"ceka se {VARIANT} - davka bere puvodni id a kreslici cesty by se rozezly")
    if mereni.get("mesh_pretek_n16") != "0":
        gate.error(f"K8: davka pretekla stranku ({mereni.get('mesh_pretek_n16')}) - mereni slotu nic nerika")

    # --- K9: stats() ---------------------------------------------------------
    if mereni.get("stats_se_groups") != "1" or mereni.get("stats_se_members") != str(VARIANT):
        gate.error(f"K9: stats() hlasi skupin/clenu {mereni.get('stats_se_groups')}/"
                   f"{mereni.get('stats_se_members')}, ceka se 1/{VARIANT}")

    for klic in ("n1_lag1_pct", "n16_lag1_pct", "n16_lagN_pct", "n16_ruznych",
                 "mesh_slotu_n16", "stats_se_groups", "stats_se_members", "offset_ruznych"):
        gate.measure(klic, mereni.get(klic))


def art_id(kind: str, ident: int) -> int:
    if kind == "land":
        return ident
    if kind == "item":
        return ident + 0x4000
    if kind == "texmap":
        return ident + 0x10000
    return -1


def zkontroluj_konfiguraci(root: Path, gate: Gate) -> None:
    """K10: produkce `assets/own-art.json` - jsou `groups` konzistentni?"""
    cesta = root / CONFIG
    if not cesta.exists():
        gate.error(f"K10: {CONFIG} chybi - neni co kontrolovat")
        return
    try:
        data = load_json(cesta)
    except Exception as exc:
        gate.error(f"K10: {CONFIG} se necte ({exc})")
        return
    skupin = 0
    clenu = 0
    obsazene: dict[str, str] = {}
    for i, vrstva in enumerate(data.get("layers", [])):
        if not isinstance(vrstva, dict):
            continue
        jmeno = str(vrstva.get("name", f"vrstva {i}"))
        sprites = vrstva.get("sprites", {})
        groups = vrstva.get("groups", None)
        if groups is None:
            continue
        if not isinstance(groups, dict):
            gate.error(f"K10: {CONFIG}: vrstva '{jmeno}' ma 'groups', ktere neni slovnik")
            continue
        for kind, seznam in groups.items():
            kind = str(kind)
            if kind not in KINDS:
                gate.error(f"K10: {CONFIG}: vrstva '{jmeno}' ma skupiny pro neznamy druh '{kind}'")
                continue
            if not isinstance(seznam, list):
                gate.error(f"K10: {CONFIG}: vrstva '{jmeno}' - 'groups.{kind}' neni seznam")
                continue
            v_vyberu = [art_id(kind, int(x)) for x in sprites.get(kind, [])]
            for skupina in seznam:
                if not isinstance(skupina, list) or len(skupina) < 2:
                    gate.error(f"K10: {CONFIG}: vrstva '{jmeno}' ma skupinu '{kind}' "
                               "o mene nez 2 clenech - varianta by nemela co vybirat")
                    continue
                skupin += 1
                clenu += len(skupina)
                for ident in skupina:
                    aid = art_id(kind, int(ident))
                    if aid not in v_vyberu:
                        gate.error(f"K10: {CONFIG}: vrstva '{jmeno}' ma ve skupine {kind} {ident}, "
                                   "ktere nema v 'sprites' - skupina by michala vlastni art s UO")
                    klic = f"{kind}|{aid}"
                    if klic in obsazene:
                        gate.error(f"K10: {CONFIG}: {klic} je ve skupinach vrstvy '{obsazene[klic]}' "
                                   f"i '{jmeno}' - druha by se tise ignorovala")
                    obsazene[klic] = jmeno
    gate.measure("produkcni_skupin", skupin)
    gate.measure("produkcni_clenu", clenu)
    if skupin == 0:
        # Neni to vada brany (mechanika je hotova a zmerena na fixture), ale
        # NESMI to byt ticho: bez `groups` v produkci se varianty nevyuzivaji.
        gate.note(f"{CONFIG} zatim zadne 'groups' nema - mechanika je hotova, "
                  "ale v hre se varianty nepouzivaji (viz HANDOFF)")


def run_probe(root: Path) -> tuple[int, dict[str, str], str]:
    kod, vystup = godot_run(root, ["--script", "res://" + PROBE], timeout=300)
    return kod, parse_probe(vystup), vystup


def check(root: Path, gate: Gate) -> None:
    probe = root / PROBE
    if not probe.exists():
        gate.pending(f"chybi {PROBE} - neni cim zmerit varianty dlazdic")
        return
    kod, mereni, vystup = run_probe(root)
    gate.measure("probe_exit", kod)
    if not mereni:
        gate.error(f"sonda {PROBE} nevydala zadne mereni (exit {kod})")
        for radek in vystup.splitlines()[-5:]:
            gate.note(radek.strip()[:160])
        return
    zkontroluj_mereni(gate, mereni)
    zkontroluj_konfiguraci(root, gate)


# --- self-test -------------------------------------------------------------

def selftest() -> int:
    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-land-variants"
    shutil.rmtree(base, ignore_errors=True)

    def mereni(**zmeny) -> dict[str, str]:
        # Znamy SPRAVNY stav: presne to, co namerila sonda na fixture (16 variant).
        m = {
            "cfg_ok_bez": "1", "cfg_ok_se": "1", "cfg_chyb_bez": "0", "cfg_chyb_se": "0",
            "n1_v_seznamu": str(GRID * GRID), "n1_lag1_pct": "100.00", "n1_lagN_pct": "100.00",
            "n1_ruznych": "1",
            "n16_v_seznamu": str(GRID * GRID), "n16_lag1_pct": "6.32", "n16_lagN_pct": "6.90",
            "n16_ruznych": "16",
            "sha_a": "a" * 64, "sha_b": "a" * 64, "determinismus": "1",
            "offset_ze_stejneho": "1", "offset_ruznych": "16", "offset_mimo_puvodni": "399",
            "textur_null": "0", "bez_skupin_id": "1", "stats_bez_groups": "0",
            "stats_bez_members": "0", "mimo_skupinu": "1", "variant_index_rozsah": "1",
            "mesh_slotu_n1": "1", "mesh_slotu_n16": str(VARIANT), "mesh_pretek_n16": "0",
            "stats_se_groups": "1", "stats_se_members": str(VARIANT),
        }
        m.update(zmeny)
        return m

    def root_bez_skupin(label: str) -> Path:
        root = base / label
        (root / "assets").mkdir(parents=True, exist_ok=True)
        (root / "assets" / "own-art.json").write_text(json.dumps({
            "version": 1,
            "layers": [{"name": "lit", "manifest": "res://assets/own-lit/manifest.json",
                        "sprites": {"land": [3]}}],
        }, ensure_ascii=False), encoding="utf-8")
        return root

    def root_vadna_skupina(label: str) -> Path:
        root = base / label
        (root / "assets").mkdir(parents=True, exist_ok=True)
        (root / "assets" / "own-art.json").write_text(json.dumps({
            "version": 1,
            "layers": [{"name": "cesta", "manifest": "res://assets/cesta/manifest.json",
                        "sprites": {"land": [1001, 1002]},
                        # 1003 NENI ve `sprites` te vrstvy - skupina by michala
                        # vlastni art s UO, presne to, co ma brana odhalit.
                        "groups": {"land": [[1001, 1002, 1003]]}}],
        }, ensure_ascii=False), encoding="utf-8")
        return root

    def spust(mereni_slovnik: dict[str, str], root: Path) -> int:
        g = Gate("check-land-variants/selftest")
        zkontroluj_mereni(g, mereni_slovnik)
        zkontroluj_konfiguraci(root, g)
        return g.verdict()

    dobre = root_bez_skupin("dobre")
    vada = root_vadna_skupina("vadna_skupina")
    chybi = base / "chybi"
    chybi.mkdir(parents=True, exist_ok=True)

    pripady = [
        ("dobry", mereni(), dobre, OK),
        ("kalibrace_n1_neni_100", mereni(n1_lag1_pct="92.00"), dobre, VADA),
        ("kalibrace_periody", mereni(n1_lagN_pct="50.00"), dobre, VADA),
        ("n16_porad_stejne", mereni(n16_lag1_pct="100.00"), dobre, VADA),
        ("perioda_zarovnana_s_mrizkou", mereni(n16_lagN_pct="100.00"), dobre, VADA),
        ("n16_jen_dve_varianty", mereni(n16_ruznych="2"), dobre, VADA),
        ("nedeterminismus", mereni(sha_b="b" * 64, determinismus="0"), dobre, VADA),
        ("offset_z_puvodniho", mereni(offset_ze_stejneho="0", offset_mimo_puvodni="0"), dobre, VADA),
        ("bez_skupin_se_zmenil", mereni(bez_skupin_id="0"), dobre, VADA),
        ("davka_bere_puvodni_id", mereni(mesh_slotu_n16="1"), dobre, VADA),
        ("sonda_hlasi_chybu", mereni(chyba="fixture: textura se nenacetla"), dobre, VADA),
        ("sonda_mlci", {}, dobre, VADA),
        ("konfigurace_chybi", mereni(), chybi, VADA),
        ("konfigurace_vadna_skupina", mereni(), vada, VADA),
    ]

    bad = 0
    for label, m, root, expected in pripady:
        got = spust(m, root)
        ok = got == expected
        if not ok:
            bad += 1
        print(f"[{NAME}] self-test {label}: ocekavano {expected}, vyslo {got}"
              f" {'OK' if ok else 'CHYBA'}")
    print(f"[{NAME}] self-test: {len(pripady)} pripadu, {bad} chyb")
    return VADA if bad else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G17 kontrola variant dlazdic podle souradnic")
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
