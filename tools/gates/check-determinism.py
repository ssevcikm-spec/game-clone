#!/usr/bin/env python3
"""G8 check-determinism - dva behy daji stejny hash (docs/08 §8.2, §2.3).

Kriteria: stejny skript prikazu a 20 000 ticku ve dvou behach -> stejny
`state_hash()`. Rozdil znamena float ve stavu, neusporadanou iteraci nebo
cteni casu uvnitr `sim/`.

Spousteni:
  python tools/gates/check-determinism.py [--root .] [--json cesta]
  python tools/gates/check-determinism.py --self-test
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, selftest_cli  # noqa: E402
from sim_gates import run_probe, sim_pending  # noqa: E402

NAME = "check-determinism"
TICKS = 20000


def evaluate(gate: Gate, runs: list[tuple[int, dict[str, str]]]) -> None:
    hashes = []
    for i, (rc, values) in enumerate(runs, 1):
        gate.measure(f"exit_kod_beh{i}", rc)
        h = values.get("hash")
        if h is None:
            gate.error(f"běh {i}: sim_probe nevrátil hash (exit {rc})")
            return
        hashes.append(h)
    gate.measure("hashe", hashes)
    gate.measure("behu", len(runs))
    if len(runs) < 2:
        gate.error("determinismus se měří na DVOU bězích - spuštěn jen jeden")
        return
    if any(h == "" for h in hashes):
        gate.error("některý běh vrátil prázdný hash")
    elif len(set(hashes)) != 1:
        gate.error("dva běhy téhož skriptu daly jiný hash: " + ", ".join(hashes))


def check(root: Path, gate: Gate) -> None:
    if sim_pending(root, gate):
        return
    runs = []
    for _ in range(2):
        rc, _, values = run_probe(root, "determinism", [f"--ticks={TICKS}"])
        runs.append((rc, values))
    evaluate(gate, runs)


def selftest() -> int:
    same = (0, {"hash": "abc", "ticks": "20000"})
    cases = [
        ("dobry", [same, same], OK),
        ("vadny_ruzne_hashe", [same, (0, {"hash": "abd"})], VADA),
        ("vadny_prazdny_hash", [(0, {"hash": ""}), (0, {"hash": ""})], VADA),
        ("vadny_jeden_beh", [same], VADA),
        ("vadny_bez_vystupu", [(1, {}), (1, {})], VADA),
    ]
    return selftest_cli(
        NAME,
        lambda data, gate: evaluate(gate, data),
        [(label, expected) for label, _, expected in cases],
        fixtures=[(label, data) for label, data, _ in cases],
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="G8 determinismus simulace")
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
