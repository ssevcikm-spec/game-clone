#!/usr/bin/env python3
"""G22 check-travel - DEBUG TELEPORT MEZI TESTOVACIMI BODY (docs/08 §8.2).

Proc existuje: uzivatel pozadal o moznost pohybovat se mezi testovacimi body
(tezba, boj, obchod) - do te doby se k nim muselo dojit pesky. Je to **DEBUG
POMUCKA, NE HERNI FUNKCE** (`app/debug_travel.gd`, `ui/debug_travel.gd`,
`data/test-points.json`). Brana hlida presne to, co by jinak tise zestarlo:

  * DATA (`data/test-points.json`) maji vsech pet druhu bodu (start, tezba,
    kovani, obchod, boj), kazdy s povinnymi poli, ID v ASCII, zadne dva body
    na stejne dlazdici a nejvyce 9 bodu (klavesy jsou cislice 1-9),
  * na ZIVE scene (`tools/gates/travel_probe.gd`): kazdy bod je na mape
    (`z` == vyska povrchu), je prujezdny a od bodu je na dosah vec, kvuli ktere
    tam hrac jde (kovadlina/vyhen, prodejce, balvan, monstrum) - rozsahy se
    berou ZE SYSTEMU, ne z textu brany,
  * teleport nastavi pozici PRESNE na bod a KAMERA ho nasleduje,
  * panel se otevre i zavre (`F7`), `Esc` ho zavre a cislo 1-9 na bod skoci,
  * po teleportu se da dal hrat (sim tickuje, hrac reaguje na sipku),
  * do zurnalu jde hlaska `Teleport: <nazev> (debug)`.

CHYBEJICI BOD JE VADA, NE TICHO: chybi-li v datech bod nektereho druhu, brana
skonci 1 (`exit 1`) jeste pred spustenim Godotu - a pozna to i sonda.

Spousteni:
  python tools/gates/check-travel.py [--root .] [--json cesta]
  python tools/gates/check-travel.py --self-test   # offline, bez Godotu
  python tools/gates/check-travel.py --mutace      # sabotaze: musi spadnout
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, godot_bin, godot_run  # noqa: E402

NAME = "check-travel"
DATA = "data/test-points.json"
PROBE = "res://tools/gates/travel_probe.gd"
SOUHRN_RE = re.compile(r"SOUHRN:\s*bodu\s+(\d+),\s*vad\s+(\d+)")
MERENI_RE = re.compile(r"MERENI:\s*(.+)$", re.MULTILINE)
VADA_RE = re.compile(r"VADA:\s*(.+)$", re.MULTILINE)

# Pet druhu bodu, ktere zadani pojmenovava. Kazdy musi mit PRAVE JEDEN bod -
# osm bodu "tezba" a zadny "obchod" je vada, ne "hodne bodu".
POVINNE_DRUHY = ("start", "tezba", "kovani", "obchod", "boj")
POVINNA_POLE = ("id", "nazev", "x", "y", "z", "proc")
MAX_BODU = 9
MIN_BODU = 5
ID_VZOR = re.compile(r"^[a-z0-9_]+$")

# Mereni, ktera musi sonda dodat a jejichz hodnota se porovnava s poctem bodu.
# Kdyz sonda nejaky klic NEUVEDE, je to vada (chybejici mereni neni nula).
NA_BOD = ("pozice_presna", "kamera", "kamera_se_posunula", "na_mape",
          "vyska_sedi", "prujezd", "dosah")
ASPON_JEDNOU = ("panel_otevreni", "panel_zavreni", "escape_zavreni",
                "skok_cislici", "hlaseni", "tick_po_teleportu",
                "vstup_po_teleportu", "ruzne_body", "panel_zavreny_na_startu")


# -- data (staticka kontrola, bez Godotu) ----------------------------------

def chyby_dat(body) -> list[str]:
    """Vady seznamu bodu. Prazdny seznam = vsechno v poradku (a pocet > 0)."""
    chyby: list[str] = []
    if not isinstance(body, list):
        return [f"{DATA}: `body` neni seznam"]
    if len(body) < MIN_BODU:
        chyby.append(f"{DATA}: bodu je {len(body)}, zadani pojmenovava {MIN_BODU} "
                     "(start, tezba, kovani, obchod, boj)")
    if len(body) > MAX_BODU:
        chyby.append(f"{DATA}: bodu je {len(body)}, maximum je {MAX_BODU} "
                     "(klavesy jsou cislice 1-9)")
    videna_id: dict[str, int] = {}
    videne_dlazdice: dict[str, int] = {}
    druhy: dict[str, int] = {}
    for i, rec in enumerate(body):
        if not isinstance(rec, dict):
            chyby.append(f"{DATA}[{i}]: neni objekt")
            continue
        chybi = [p for p in POVINNA_POLE if p not in rec]
        if chybi:
            chyby.append(f"{DATA}[{i}]: chybi pole " + ", ".join(chybi))
            continue
        rid = str(rec["id"])
        if not ID_VZOR.match(rid):
            chyby.append(f"{DATA}[{i}]: id '{rid}' neni male ASCII (a-z, 0-9, _)")
        if rid in videna_id:
            chyby.append(f"{DATA}[{i}]: id '{rid}' je v datech dvakrat "
                         f"(jinde na indexu {videna_id[rid]})")
        videna_id.setdefault(rid, i)
        if str(rec["nazev"]).strip() == "":
            chyby.append(f"{DATA}[{i}]: prazdny nazev (hrac musi videt, kam skace)")
        for pole in ("x", "y", "z"):
            hodnota = rec[pole]
            if isinstance(hodnota, bool) or not isinstance(hodnota, (int, float)):
                chyby.append(f"{DATA}[{i}]: '{pole}' neni cislo ({hodnota!r})")
            elif int(hodnota) < 0:
                chyby.append(f"{DATA}[{i}]: '{pole}' je zaporne ({hodnota!r})")
        klic = f"{int(rec['x'])},{int(rec['y'])}"
        if klic in videne_dlazdice:
            chyby.append(f"{DATA}[{i}]: dlazdice {klic} je v datech dvakrat "
                         f"(jinde na indexu {videne_dlazdice[klic]}) - body musi byt RUZNE")
        videne_dlazdice.setdefault(klic, i)
        proc = str(rec["proc"])
        if proc not in POVINNE_DRUHY:
            chyby.append(f"{DATA}[{i}]: 'proc' neni jedno z {list(POVINNE_DRUHY)} ({proc!r})")
        else:
            druhy[proc] = druhy.get(proc, 0) + 1
    for druh in POVINNE_DRUHY:
        if druhy.get(druh, 0) == 0:
            chyby.append(f"{DATA}: chybi bod pro '{druh}' - chybejici bod je VADA, "
                         "ne ticho")
        elif druhy[druh] > 1:
            chyby.append(f"{DATA}: bodu pro '{druh}' je {druhy[druh]} (ma byt 1) - "
                         "dva body pro tutez cinnost znamenaji, ze jeden je mrtvy")
    return chyby


def nacti_body(root: Path) -> tuple[list, list[str]]:
    """Precte data a vrati (body, chyby). Rozbity JSON je vada, ne prazdno."""
    cesta = root / DATA
    if not cesta.exists():
        return [], [f"chybi {DATA} - neni odkud teleportovat"]
    try:
        data = json.loads(cesta.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - rozbity JSON je vada, ne pad
        return [], [f"{DATA}: JSON se neda precist ({exc})"]
    if not isinstance(data, dict):
        return [], [f"{DATA}: neni objekt se seznamem `body`"]
    body = data.get("body")
    return (body if isinstance(body, list) else []), chyby_dat(body)


# -- mereni ze sondy -------------------------------------------------------

def vyhodnot(output: str) -> dict:
    """Precte souhrn a mereni ze sondy. `nalezeno: False` = sonda nic nerekla."""
    m = SOUHRN_RE.search(output)
    if m is None:
        return {"nalezeno": False}
    mereni: dict[str, int] = {}
    mm = MERENI_RE.search(output)
    if mm is not None:
        for kus in mm.group(1).split(","):
            if "=" not in kus:
                continue
            klic, hodnota = kus.split("=", 1)
            try:
                mereni[klic.strip()] = int(hodnota.strip())
            except ValueError:
                continue
    vady = [v.strip() for v in VADA_RE.findall(output)]
    return {"nalezeno": True, "bodu": int(m.group(1)), "vad": int(m.group(2)),
            "mereni": mereni, "vady": vady}


def chyby_z_mereni(d: dict, pocet_v_datech: int) -> list[str]:
    """Verdikt z jednoho mereni - pouziva ho brana, self-test i mutace."""
    if not d.get("nalezeno", False):
        return ["ze sondy nelze precist SOUHRN (sonda neprobihla nebo spadla)"]
    chyby: list[str] = []
    bodu = int(d.get("bodu", 0))
    if bodu <= 0:
        chyby.append("sonda nenamerila ANI JEDEN bod (nula neni uspech)")
    elif bodu != pocet_v_datech:
        chyby.append(f"sonda merila {bodu} bodu, v datech je {pocet_v_datech} "
                     "(modul a data se rozesly)")
    for text in d.get("vady", []):
        chyby.append("sonda: " + str(text))
    mereni = d.get("mereni", {})
    for klic in NA_BOD:
        if klic not in mereni:
            chyby.append(f"mereni '{klic}' sonda NEUVEDLA (chybejici mereni neni nula)")
        elif int(mereni[klic]) != bodu:
            chyby.append(f"'{klic}' plati pro {int(mereni[klic])} z {bodu} bodu")
    for klic in ASPON_JEDNOU:
        if klic not in mereni:
            chyby.append(f"mereni '{klic}' sonda NEUVEDLA (chybejici mereni neni nula)")
        elif int(mereni[klic]) <= 0:
            chyby.append(f"'{klic}' je {int(mereni[klic])} - panel/teleport nefunguje")
    for druh in POVINNE_DRUHY:
        klic = "druh_" + druh
        if klic not in mereni:
            chyby.append(f"mereni '{klic}' sonda NEUVEDLA")
        elif int(mereni[klic]) != 1:
            chyby.append(f"bodu pro '{druh}' je {int(mereni[klic])} (ma byt 1)")
    if int(d.get("vad", 0)) > 0 and not d.get("vady"):
        chyby.append(f"sonda hlasi {int(d['vad'])} vad, ale zadnou nevypsala")
    return chyby


# -- brana -----------------------------------------------------------------

def check(root: Path, gate: Gate) -> None:
    body, chyby = nacti_body(root)
    gate.measure("bodu_v_datech", len(body))
    gate.measure("druhy_v_datech", ",".join(sorted(
        {str(b.get("proc", "")) for b in body if isinstance(b, dict)})))
    for text in chyby:
        gate.error(text)
    if not body:
        # Prazdna data: neni co merit a vada uz je nahlasena vys (NEMERENO by
        # ji schovalo - tady je to VADA).
        return
    sonda = root / PROBE.removeprefix("res://")
    if not sonda.exists():
        gate.pending(f"chybi sonda {PROBE.removeprefix('res://')} - neni co merit")
        return
    if godot_bin() is None:
        gate.skip("Godot neni k dispozici (nastav $GODOT nebo dodej binarku do .cache/godot)")
        return
    rc, output = godot_run(root, ["--fixed-fps", "60", "--script", PROBE], timeout=600)
    d = vyhodnot(output)
    gate.measure("probe_exit", rc)
    if not d.get("nalezeno", False):
        gate.error(f"ze sondy nelze precist SOUHRN (exit {rc})")
        for radek in output.splitlines()[-6:]:
            gate.note(radek.strip()[:120])
        return
    gate.measure("bodu_mereno", d["bodu"])
    gate.measure("vad_ze_sondy", d["vad"])
    for klic in sorted(d.get("mereni", {})):
        gate.measure("sonda_" + klic, int(d["mereni"][klic]))
    for text in chyby_z_mereni(d, len(body)):
        gate.error(text)


# -- self-test (offline, bez Godotu) ---------------------------------------

def _body_ok() -> list[dict]:
    return [
        {"id": "start", "nazev": "Start", "x": 1495, "y": 1630, "z": 10, "proc": "start"},
        {"id": "kovani", "nazev": "Vyhen", "x": 1494, "y": 1630, "z": 10, "proc": "kovani"},
        {"id": "obchod", "nazev": "Kovar", "x": 1497, "y": 1629, "z": 10, "proc": "obchod"},
        {"id": "tezba", "nazev": "Balvan", "x": 1495, "y": 1633, "z": 10, "proc": "tezba"},
        {"id": "boj", "nazev": "Hrbitov", "x": 1371, "y": 1482, "z": 10, "proc": "boj"},
    ]


def _mereni_ok(bodu: int = 5) -> dict:
    mereni: dict[str, int] = {k: bodu for k in NA_BOD}
    mereni.update({k: 1 for k in ASPON_JEDNOU})
    mereni.update({"druh_" + d: 1 for d in POVINNE_DRUHY})
    mereni["bodu"] = bodu
    return {"nalezeno": True, "bodu": bodu, "vad": 0, "mereni": mereni, "vady": []}


def selftest() -> int:
    """Znamy spravny i znamy chybny vstup - offline, bez Godotu."""
    chyb = 0
    tisk: list[str] = []

    def zkus(jmeno: str, vysledek: bool, ocekavano: bool) -> None:
        nonlocal chyb
        ok = vysledek == ocekavano
        chyb += 0 if ok else 1
        tisk.append(f"[{NAME}] self-test {jmeno}: {'OK' if ok else 'CHYBA'}")

    # 1) DATA: znamy spravny a znamy chybny vstup.
    zkus("data_platna", not chyby_dat(_body_ok()), True)
    bez_obchodu = [b for b in _body_ok() if b["proc"] != "obchod"]
    zkus("data_bez_bodu_obchod", any("obchod" in e for e in chyby_dat(bez_obchodu)), True)
    dva_obchody = _body_ok() + [{"id": "obchod2", "nazev": "Kovar 2", "x": 1498,
                                 "y": 1629, "z": 10, "proc": "obchod"}]
    zkus("data_dva_obchody", any("ma byt 1" in e for e in chyby_dat(dva_obchody)), True)
    stejna_dlazdice = _body_ok() + [{"id": "tezba2", "nazev": "Balvan 2", "x": 1495,
                                    "y": 1633, "z": 10, "proc": "tezba"}]
    zkus("data_stejna_dlazdice",
         any("dvakrat" in e for e in chyby_dat(stejna_dlazdice)), True)
    zly_proc = [dict(b) for b in _body_ok()]
    zly_proc[0]["proc"] = "neexistuje"
    zkus("data_neznany_proc", any("proc" in e for e in chyby_dat(zly_proc)), True)
    bez_pole = [dict(b) for b in _body_ok()]
    del bez_pole[0]["nazev"]
    zkus("data_chybi_nazev", any("nazev" in e for e in chyby_dat(bez_pole)), True)
    zkus("data_prazdna", bool(chyby_dat([])), True)

    # 2) MERENI: znamy spravny a znamy chybny vstup.
    zkus("mereni_ok", not chyby_z_mereni(_mereni_ok(), 5), True)
    zkus("mereni_sonda_mlci", bool(chyby_z_mereni({"nalezeno": False}, 5)), True)
    bez_pozice = _mereni_ok()
    del bez_pozice["mereni"]["pozice_presna"]
    zkus("mereni_chybi_pozice",
         any("NEUVEDLA" in e for e in chyby_z_mereni(bez_pozice, 5)), True)
    posunuta = _mereni_ok()
    posunuta["mereni"]["pozice_presna"] = 4
    zkus("mereni_pozice_neni_presna",
         any("pozice_presna" in e for e in chyby_z_mereni(posunuta, 5)), True)
    bez_kamery = _mereni_ok()
    bez_kamery["mereni"]["kamera"] = 0
    zkus("mereni_kamera_nic", bool(chyby_z_mereni(bez_kamery, 5)), True)
    panel_zavreny = _mereni_ok()
    panel_zavreny["mereni"]["panel_otevreni"] = 0
    zkus("mereni_panel_se_neotevrel", bool(chyby_z_mereni(panel_zavreny, 5)), True)
    jina_data = _mereni_ok()
    zkus("mereni_jiny_pocet_bodu", bool(chyby_z_mereni(jina_data, 6)), True)
    vada_sondy = _mereni_ok()
    vada_sondy["vad"] = 1
    vada_sondy["vady"] = ["bod 0: neni na mape"]
    zkus("mereni_vada_sondy", bool(chyby_z_mereni(vada_sondy, 5)), True)
    ticha_vada = _mereni_ok()
    ticha_vada["vad"] = 2
    ticha_vada["vady"] = []
    zkus("mereni_ticha_vada", bool(chyby_z_mereni(ticha_vada, 5)), True)
    bez_hlasky = _mereni_ok()
    bez_hlasky["mereni"]["hlaseni"] = 0
    zkus("mereni_bez_hlaseni", bool(chyby_z_mereni(bez_hlasky, 5)), True)
    chybi_druh = _mereni_ok()
    del chybi_druh["mereni"]["druh_boj"]
    zkus("mereni_chybi_druh", bool(chyby_z_mereni(chybi_druh, 5)), True)

    for radek in tisk:
        print(radek)
    print(f"[{NAME}] self-test: {len(tisk)} pripadu, {chyb} chyb")
    return VADA if chyb else OK


# -- mutace: sabotovana kopie ----------------------------------------------
#
# Kazda sabotaz vraci JEDNU vadu, kterou by hrac poznal - a brana ji musi videt
# (`exit 1`). Kdyz se vada nezapise, je to chyba mutace (ticha mutace tvrdi
# totez co mutace, ktera projde).

MUTACE: list[tuple[str, list[tuple[str, str, str]]]] = [
    # M1: teleport vrati "ok", ale pozici NENASTAVI (typicka vada "uveris mi").
    ("M1_teleport_nic", [(
        "app/player_controller.gd",
        "\tplayer.pos = Vector3i(tile.x, tile.y, z)\n",
        "",
    )]),
    # M2: kamera zustane na starem miste (pozice hrace se zmeni, obraz ne).
    ("M2_bez_kamery", [(
        "app/player_controller.gd",
        "\t_follow()\n\tif view != null and view.has_method(\"queue_redraw\"):",
        "\tif view != null and view.has_method(\"queue_redraw\"):",
    )]),
    # M3: CHYBEJICI BOD: "obchod" se v datech prejmenuje na "start" - bod pro
    # obchod neexistuje a dva body pro start. Presne to, co zadani oznacuje
    # jako VADU (ne ticho).
    ("M3_chybi_bod_obchod", [(
        "data/test-points.json",
        '"proc": "obchod",',
        '"proc": "start",',
    )]),
    # M4: F7 seznam neotevre (klavesa se cte, ale jen se cte stav "zavreno").
    ("M4_panel_se_neotevre", [(
        "app/player_controller.gd",
        "\t\tvar seznam_videt: bool = bool(debug_travel.prepni())",
        "\t\tvar seznam_videt: bool = bool(debug_travel.je_otevreny())",
    )]),
    # M5: teleport probehne, ale do zurnalu NIC nejde (hrac nevi, kde je).
    ("M5_bez_hlasky", [(
        "app/debug_travel.gd",
        "\thlaseni.call(zprava_o_teleportu(str(bod[\"nazev\"])))",
        "\tpass",
    )]),
]

KOPIRUJ = ("app", "core", "sim", "ui", "render", "data", "assets", "tools/gates", ".godot")


def _postav_kopii(root: Path, cil: Path) -> None:
    """Kopie projektu s HARD LINKY (data se nekopiruji, jen jmena).

    Hardlink je jen na cteni: kdo chce soubor zmenit, musi ho nejdriv odpojit
    (`_zasad_vadu`), jinak by zmenil ORIGINAL.
    """
    if cil.exists():
        shutil.rmtree(cil)
    cil.mkdir(parents=True)
    shutil.copy2(root / "project.godot", cil / "project.godot")
    for jmeno in KOPIRUJ:
        zdroj = root / jmeno
        if not zdroj.is_dir():
            continue
        for p in zdroj.rglob("*"):
            target = cil / p.relative_to(root)
            if p.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(p, target)
            except OSError:
                shutil.copy2(p, target)


def _zasad_vadu(kopie: Path, zmeny: list[tuple[str, str, str]]) -> str:
    """Vlozi vadu do kopie a OVERI, ze se opravdu zapsala (ticha mutace lze)."""
    for soubor, hledat, nahradit in zmeny:
        cesta = kopie / soubor
        if not cesta.exists():
            return f"soubor {soubor} v kopii neni"
        text = cesta.read_text(encoding="utf-8")
        if hledat not in text:
            return f"v {soubor} neni '{hledat[:70]}'"
        cesta.unlink()
        cesta.write_text(text.replace(hledat, nahradit, 1), encoding="utf-8", newline="\n")
    for soubor, hledat, nahradit in zmeny:
        text = (kopie / soubor).read_text(encoding="utf-8")
        if hledat in text:
            return f"v {soubor} zustalo '{hledat[:70]}' (vada se nezapsala)"
        if nahradit != "" and nahradit not in text:
            return f"v {soubor} neni '{nahradit[:70]}' (vada se nezapsala)"
    return ""


def mutace(root: Path) -> int:
    """Sabotovana kopie -> brana MUSI skoncit 1 (jinak je slepa)."""
    if godot_bin() is None:
        print(f"[{NAME}] mutace: NEMERENO - Godot neni k dispozici")
        return NEMERENO
    zaklad = root / ".cache" / "gates" / "travel-mutace"
    chyb = 0
    print(f"[{NAME}] mutace: sabotovane kopie v {zaklad}")
    for jmeno, zmeny in MUTACE:
        kopie = zaklad / jmeno
        _postav_kopii(root, kopie)
        problem = _zasad_vadu(kopie, zmeny)
        if problem:
            chyb += 1
            print(f"[{NAME}] mutace {jmeno}: CHYBA - {problem}")
            continue
        gate = Gate(f"{NAME}/mutace:{jmeno}")
        try:
            check(kopie, gate)
        except Exception as exc:  # noqa: BLE001 - pad brany je taky nalez
            chyb += 1
            print(f"[{NAME}] mutace {jmeno}: CHYBA - brana spadla ({exc})")
            continue
        verdikt = gate.verdict()
        chyceno = verdikt == VADA
        chyb += 0 if chyceno else 1
        print(f"[{NAME}] mutace {jmeno}: {'CHYCENO' if chyceno else 'NECHYCENO'}"
              f" (exit {verdikt})")
        if chyceno:
            for e in gate.errors[:3]:
                print(f"[{NAME}]   duvod: {e}")
    print(f"[{NAME}] mutace: {len(MUTACE)} sabotazi, {chyb} chyb")
    return VADA if chyb else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G22: debug teleport mezi testovacimi body")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--mutace", action="store_true")
    a = ap.parse_args()
    root = Path(a.root).resolve()
    if a.self_test:
        return selftest()
    if a.mutace:
        return mutace(root)
    gate = Gate(NAME)
    check(root, gate)
    return gate.finish(Path(a.json) if a.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
