#!/usr/bin/env python3
"""G18 check-data-paths - cesta k datum je PARAMETR, ne zapeena konstanta (docs/08).

Proc existuje (S1b, `NAVRH-MODDING` §3 bod 2): modul, ktery cte cestu k datum
z KONSTANTY v tele, se neda prebit modem - a mod pak funguje **zdanlive**
(u `balance.json` ano, u `items.json` ne). Zelene testy to nechyti, protoze
modul "nejak" funguje; chyti to jen staticka metrika nad kodem.

Brana pousti `tools/check-data-paths.py` (jedina implementace metriky) a
pozaduje: v `sim/` (mimo `sim/content.gd`, kde je deklarace) **nula** konstant
ctenych primo. `app/` se meri a VYPISUJE, ale za vadu se nepovazuje - je to
rozhodovaci misto (`_cesta()`/`_nacti_obsah()`), ne modul.

Self-test pousti touz metriku na DVOU fixture stromech (znamy spravny = konstanta
jen jako default parametru, znamy chybny = konstanta v tele), aby brana umela
selhat i projit (docs/08 §8.1).

Spousteni:
  python tools/gates/check-data-paths.py [--root .] [--json cesta]
  python tools/gates/check-data-paths.py --self-test
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate  # noqa: E402

NAME = "check-data-paths"
TOOL = "tools/check-data-paths.py"
KATEGORIE = ("parametr", "primo", "smisene", "nepouzita", "deklarace", "volajici")


def spust(cíl: Path, report: Path) -> tuple[int, dict]:
    """Spusti metriku z REPA nad stromem `cíl` (kvuli self-testu na fixture)."""
    nastroj = Path(__file__).resolve().parents[2] / TOOL
    if not nastroj.exists():
        return -1, {}
    report.parent.mkdir(parents=True, exist_ok=True)
    p = subprocess.run(
        [sys.executable, str(nastroj), "--root", str(cíl), "--json", str(report)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(cíl), timeout=300)
    data: dict = {}
    if report.exists():
        try:
            data = json.loads(report.read_text(encoding="utf-8"))
        except Exception:
            data = {}
    return p.returncode, data


def check(root: Path, gate: Gate) -> None:
    if not (root / "sim").is_dir() and not (root / "app").is_dir():
        gate.pending("strom nema sim/ ani app/ - metrika nema co merit")
        return
    report = root / ".cache" / "gates" / "data-paths.json"
    rc, data = spust(root, report)
    if not data:
        gate.error("metrika nevypsala report - kontrola NEPROBĚHLA (nic se nezměřilo)")
        return
    kat = data.get("kategorie", {})
    for k in KATEGORIE:
        gate.measure(k, int(kat.get(k, 0)))
    gate.measure("exit_kod", rc)
    vady = list(data.get("vady_sim", []))
    for v in vady:
        gate.error("konstanta s cestou k datum se čte PRIMO: " + str(v))
    if rc != 0 and not vady:
        gate.error(f"metrika skončila s exit {rc}, ale žádnou vadu nehlásí")
    if int(kat.get("parametr", 0)) == 0:
        gate.error("v sim/ není ANI JEDNA konstanta jako parametr - metrika "
                   "nejspíš nic nenačetla (nula není úspěch)")


def selftest() -> int:
    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-datapaths"
    shutil.rmtree(base, ignore_errors=True)
    dobra = base / "dobra"
    vadna = base / "vadna"
    (dobra / "sim").mkdir(parents=True)
    (vadna / "sim").mkdir(parents=True)
    # ZNAMY SPRAVNY: konstanta je jen default parametru.
    (dobra / "sim" / "mod.gd").write_text(
        'extends RefCounted\n'
        'const DATA := "res://data/items.json"\n'
        'var _path: String = ""\n'
        'func _init(path: String = DATA) -> void:\n'
        '\t_path = path\n', encoding="utf-8")
    # ZNAMY CHYBNY: konstanta se cte v tele.
    (vadna / "sim" / "mod.gd").write_text(
        'extends RefCounted\n'
        'const DATA := "res://data/items.json"\n'
        'func nacti() -> String:\n'
        '\treturn DATA\n', encoding="utf-8")

    chyb = 0
    for jmeno, strom, ocekavano in (("dobra", dobra, OK), ("vadna", vadna, VADA)):
        gate = Gate(f"{NAME}/selftest:{jmeno}")
        check(strom, gate)
        vyslo = gate.verdict()
        ok = vyslo == ocekavano
        chyb += 0 if ok else 1
        print(f"[{NAME}] self-test {jmeno}: ocekavano {ocekavano}, vyslo {vyslo}"
              f" {'OK' if ok else 'CHYBA'}")
        if not ok:
            for e in gate.errors:
                print(f"[{NAME}]   duvod: {e}")
    print(f"[{NAME}] self-test: 2 případy, {chyb} chyb")
    shutil.rmtree(base, ignore_errors=True)
    return VADA if chyb else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G18: cesta k datům je parametr, ne konstanta")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return selftest()
    gate = Gate(NAME)
    check(Path(a.root).resolve(), gate)
    return gate.finish(Path(a.json) if a.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
