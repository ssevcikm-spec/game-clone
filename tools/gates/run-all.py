#!/usr/bin/env python3
"""Vsechny brany v zavaznem poradi (docs/08 §8.2) - vstupni bod pro CI.

Poradi je dane zadanim: G1 -> G3 -> G5 -> G2 -> G4 -> G6 -> G7 -> G8 -> G9 ->
F1 -> G11 -> G10 -> G13 (schema je prvni, protoze rozpor v zadani zneplatnuje
vsechno ostatni).

Vysledek:
  * 0 = vsechno mereno a bez vady,
  * 1 = nektera brana nasla vadu,
  * 2 = zadna vada, ale neco zustalo NEMERENO (cil brany jeste neexistuje).
    To NENI zelena: souhrn to vypise a `--strict` z toho udela vadu.

Proc CI nepadá na 2: dokud je projekt v M0, brany na data a render nemaji co
merit a cervena CI by prehlusila to, co je skutecna vada. `--strict` je pro
uzaverecne milniky (M8).

Spousteni:
  python tools/gates/run-all.py [--root .] [--strict] [--only g1,g3]
  python tools/gates/run-all.py --self-test     # dokazi, ze brany umi selhat
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, OUT_DIR, VADA, Gate, godot_run,
)

NAME = "run-all"

# (stitek, soubor brany) v zavaznem poradi z docs/08 §8.2; None = beh pres Godot
ORDER = [
    ("G1", "check-schema.py"),
    ("G5", "check-content.py"),
    ("G2", "check-layers.py"),
    # G14 (zadny float ve STAVU simulace) patri hned za G2: je to taky staticka
    # kontrola `sim/**`, ale hlida invariantu z docs/01 §1.5 bodu 3, ktera do
    # 2026-10-10 nemela vlastni branu. Pridano 2026-10-10 (rozhodnuti M1).
    ("G14", "check-state-float.py"),
    ("G4", "check-wiring.py"),
    ("G6", "check-assets.py"),
    ("G7", "check-save.py"),
    ("G8", "check-determinism.py"),
    ("G9", "check-replay.py"),
    # F1 (svet ma vlastni cas) patri podle docs/08 §8.2 ZA G9: meri dobeh sveta,
    # ktery stoji na `sim.scheduler` + `sim.save` (milnik MK).
    ("F1", "check-world-clock.py"),
    ("G11", "smoke.py"),
    ("G10", "check-render.py"),
]
TESTS_GATE = "G3"
TESTS_LABEL = "G3"


def run_tests_gate(root: Path, gate: Gate) -> None:
    """G3: tests/run_tests.gd - chovani simulace bez scene a assetu."""
    script = root / "tests" / "run_tests.gd"
    if not script.exists():
        gate.pending("chybí tests/run_tests.gd (bootstrap granule boot.tests)")
        return
    rc, output = godot_run(root, ["--script", "res://tests/run_tests.gd"], timeout=600)
    match = re.search(r"(\d+)\s+kontrol,\s*(\d+)\s+selh", output)
    gate.measure("exit_kod", rc)
    if match is None:
        gate.error(f"z výstupu nelze přečíst 'N kontrol, M selhání' (exit {rc})")
        for line in output.splitlines()[-5:]:
            gate.note(line.strip()[:100])
        return
    checks, failures = int(match.group(1)), int(match.group(2))
    gate.measure("kontrol", checks)
    gate.measure("selhani", failures)
    if checks == 0:
        gate.error("testy proběhly s 0 kontrolami (docs/08 §8.6: nula není úspěch)")
        return
    if failures:
        gate.error(f"{failures} z {checks} kontrol selhalo")
        for line in output.splitlines():
            if line.startswith("[test] FAIL"):
                gate.error(line.strip()[:160])
    elif rc != 0:
        # exit kod a vystup si mohou odporovat (docs/08 past 9) - ctou se oba
        gate.error(f"testy hlásí 0 selhání, ale Godot skončil s exit {rc}")


def build_plan(only: list[str] | None) -> list[tuple[str, str | None]]:
    plan: list[tuple[str, str | None]] = []
    for label, filename in ORDER:
        plan.append((label, filename))
        if label == "G1":
            # G3 (testy) patri v zavaznem poradi hned za schematem
            plan.append((TESTS_LABEL, None))
    if only:
        wanted = {o.lower() for o in only}
        plan = [item for item in plan if item[0].lower() in wanted]
    return plan


def run_gate(root: Path, label: str, filename: str | None) -> tuple[str, int, str]:
    if filename is None:
        gate = Gate(TESTS_LABEL)
        run_tests_gate(root, gate)
        reason = gate.pending_reason or ("vada" if gate.errors else "")
        return TESTS_LABEL, gate.verdict(), reason
    path = Path(__file__).resolve().parent / filename
    proc = subprocess.run(
        [sys.executable, str(path), "--root", str(root)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    sys.stdout.write(proc.stdout)
    if proc.stderr.strip():
        sys.stderr.write(proc.stderr)
    verdict = proc.returncode if proc.returncode in (OK, VADA, NEMERENO) else VADA
    reason = ""
    for line in proc.stdout.splitlines():
        if "NEMERENO:" in line or "SKIP:" in line or "CHYBA:" in line:
            reason = line.split("]", 1)[-1].strip()
            break
    return label, verdict, reason


def main() -> int:
    ap = argparse.ArgumentParser(description="Všechny brány v závazném pořadí")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--strict", action="store_true",
                    help="NEMĚŘENO se počítá jako vada (pro uzávěrečné milníky)")
    ap.add_argument("--only", default=None, help="čárkami oddělené štítky, např. g1,g3")
    ap.add_argument("--self-test", action="store_true",
                    help="spustí self-testy všech bran (důkaz, že umí selhat)")
    args = ap.parse_args()
    root = Path(args.root).resolve()

    if args.self_test:
        return selftest_all(root)

    only = args.only.split(",") if args.only else None
    results: list[dict[str, object]] = []
    worst = OK
    for label, filename in build_plan(only):
        print(f"===== {label} {'(' + filename + ')' if filename else '(tests/run_tests.gd)'} =====")
        name, verdict, reason = run_gate(root, label, filename)
        results.append({"gate": label, "file": filename, "exit": verdict, "reason": reason})
        if verdict == VADA:
            worst = VADA
        elif verdict == NEMERENO and worst == OK:
            worst = NEMERENO

    ok = sum(1 for r in results if r["exit"] == OK)
    pending = sum(1 for r in results if r["exit"] == NEMERENO)
    failed = sum(1 for r in results if r["exit"] == VADA)
    # G13 vision je PORADNI (docs/08 §8.2): nikdy neshodi beh, ale musi byt videt
    vision = ("G13 vision je poradní a neimplementováno (chybí vision.mjs) - "
              "NEMĚŘENO, neblokuje; v pořadí je uvedeno, aby nebylo ticho")
    results.append({"gate": "G13", "file": None, "exit": None, "reason": vision})
    print("=" * 60)
    for r in results:
        mark = {OK: "OK", VADA: "VADA", NEMERENO: "NEMĚŘENO"}.get(r["exit"], "PORADNÍ")
        line = f"  {r['gate']:<5} {mark:<9}"
        if r["reason"]:
            line += f" {str(r['reason'])[:90]}"
        print(line)
    print(f"SOUHRN: měřeno {ok}, čeká {pending}, chyb {failed}")
    summary = OUT_DIR / "summary.json"
    summary.parent.mkdir(parents=True, exist_ok=True)
    summary.write_text(json.dumps({"results": results, "ok": ok, "pending": pending,
                                   "failed": failed}, ensure_ascii=False, indent=1),
                       encoding="utf-8")
    print(f"[{NAME}] souhrn: {summary}")
    if args.strict and worst == NEMERENO:
        print(f"[{NAME}] --strict: NEMĚŘENO se počítá jako vada")
        return VADA
    return worst


# `atlas` a `texmaps` pribyly 2026-10-07 (12. session): jejich self-testy
# existovaly, ale nikdo je nespoustel - prave proto v nich mohla byt vada
# (atlas mel 46 kontrol a pritom se land klicoval spatnym id prostorem).
EXTRACTOR_SELFTESTS = ["uop", "art", "atlas", "gump", "worldmap", "cliloc", "tiledata",
                       "hues", "texmaps", "textdata", "anim"]


def selftest_all(root: Path) -> int:
    """Kazda brana dokaze, ze umi selhat - jinak je to dekorace (docs/08 §8.1).

    Zamerne se pousteji i self-testy extrakcnich nastroju (tools/uoextract/):
    jsou OFFLINE (nepotrebuji instalaci UO), takze je CI muze overit vzdy -
    dosud se poustely jen rucne a v CI by tedy nikdo nepoznal, ze se rozbily.
    """
    failures = 0
    checked = 0
    for label, filename in build_plan(None):
        if filename is None:
            continue
        path = Path(__file__).resolve().parent / filename
        proc = subprocess.run(
            [sys.executable, str(path), "--self-test"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        checked += 1
        tail = [ln for ln in proc.stdout.splitlines() if "self-test:" in ln]
        status = "OK" if proc.returncode == 0 else "CHYBA"
        if proc.returncode != 0:
            failures += 1
        print(f"  {label:<5} {filename:<24} {status:<6} {tail[-1] if tail else ''}")
        if proc.returncode != 0:
            sys.stdout.write(proc.stdout)
            sys.stderr.write(proc.stderr)

    extract_dir = root / "tools" / "uoextract"
    for name in EXTRACTOR_SELFTESTS:
        path = extract_dir / f"{name}.py"
        if not path.exists():
            # Nastroj, ktery v repu neni, se nesmi tise preskocit.
            failures += 1
            checked += 1
            print(f"  {'X':<5} {name + '.py':<24} {'CHYBI':<6} nastroj v repu neni")
            continue
        proc = subprocess.run(
            [sys.executable, str(path), "--self-test"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        checked += 1
        tail = [ln for ln in proc.stdout.splitlines() if "self-test:" in ln]
        status = "OK" if proc.returncode == 0 else "CHYBA"
        if proc.returncode != 0:
            failures += 1
        print(f"  {'EX':<5} {name + '.py':<24} {status:<6} {tail[-1] if tail else ''}")
        if proc.returncode != 0:
            sys.stdout.write(proc.stdout)
            sys.stderr.write(proc.stderr)

    print(f"[{NAME}] self-testy: {checked} celkem "
          f"({checked - len(EXTRACTOR_SELFTESTS)} bran + {len(EXTRACTOR_SELFTESTS)} extrakcnich nastroju), "
          f"{failures} chyb")
    return VADA if failures else OK


if __name__ == "__main__":
    raise SystemExit(main())
