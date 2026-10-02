#!/usr/bin/env python3
"""G7 check-save - round-trip ulozeni a nacteni (docs/08 §8.2, docs/04 §4.7).

Kriteria: `sim.save(); sim2.load(); sim.state_hash() == sim2.state_hash()`.

Spousteni:
  python tools/gates/check-save.py [--root .] [--json cesta]
  python tools/gates/check-save.py --self-test
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, selftest_cli  # noqa: E402
from sim_gates import run_probe, sim_pending  # noqa: E402

NAME = "check-save"


def evaluate(gate: Gate, rc: int, values: dict[str, str]) -> None:
    gate.measure("exit_kod", rc)
    before, after = values.get("hash_before"), values.get("hash_after")
    if before is None or after is None:
        gate.error(f"sim_probe nevrátil hash (exit {rc}) - round-trip NEMĚŘEN")
        return
    gate.measure("hash_before", before)
    gate.measure("hash_after", after)
    if values.get("save") != "true" or values.get("load") != "true":
        gate.error(f"save()/load() vrátilo save={values.get('save')} load={values.get('load')}")
    if before == "" or after == "":
        gate.error("state_hash() je prázdný řetězec (to není hash)")
    elif before != after:
        gate.error(f"round-trip: hash před != hash po ({before} != {after})")


def check(root: Path, gate: Gate) -> None:
    if sim_pending(root, gate):
        return
    rc, _, values = run_probe(root, "save")
    evaluate(gate, rc, values)


def selftest() -> int:
    cases = [
        ("dobry", (0, {"hash_before": "abc", "hash_after": "abc", "save": "true", "load": "true"}), OK),
        ("vadny_rozdilny_hash", (0, {"hash_before": "abc", "hash_after": "abd", "save": "true", "load": "true"}), VADA),
        ("vadny_save_false", (0, {"hash_before": "abc", "hash_after": "abc", "save": "false", "load": "true"}), VADA),
        ("vadny_prazdny_hash", (0, {"hash_before": "", "hash_after": "", "save": "true", "load": "true"}), VADA),
        ("vadny_bez_vystupu", (1, {}), VADA),
    ]
    return selftest_cli(
        NAME,
        lambda data, gate: evaluate(gate, data[0], data[1]),
        [(label, expected) for label, _, expected in cases],
        fixtures=[(label, data) for label, data, _ in cases],
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="G7 round-trip uložení")
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
