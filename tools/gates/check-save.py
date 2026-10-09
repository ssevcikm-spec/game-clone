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
    # ⚠ ENTITY (od 2026-10-09): `entities` je stavový zdroj, takže se ukládají
    # i mobily. Probe je schvalne osidluje - bez toho by round-trip meril jen
    # prazdny svet a "mobily prezily save" by nebylo MERENE vubec (`docs/09`
    # §9.4: hotovo = brana zavolala funkci a vysla konkretni hodnota).
    mob_po = values.get("mobiles_after")
    if mob_po is None:
        gate.error("sim_probe neposlal `mobiles_after` - ukladani entit NEMĚŘENO")
        return
    gate.measure("mobiles_after", mob_po)
    if values.get("mobiles_before") != mob_po:
        gate.error("po load() je jiný počet mobilů: %s -> %s"
                   % (values.get("mobiles_before"), mob_po))
    if (values.get("pos_x"), values.get("pos_y"), values.get("pos_z")) != ("100", "200", "3"):
        gate.error("nacteny mobil nema pozici 100,200,3 (naměřeno %s,%s,%s) - stav "
                   "entity se neobnovil"
                   % (values.get("pos_x"), values.get("pos_y"), values.get("pos_z")))
    if values.get("telo") != "400":
        gate.error("nacteny mobil nema telo 400 (naměřeno %s)" % values.get("telo"))


def check(root: Path, gate: Gate) -> None:
    if sim_pending(root, gate):
        return
    rc, _, values = run_probe(root, "save")
    evaluate(gate, rc, values)


def selftest() -> int:
    def dobre(**zmeny) -> dict:
        d = {
            "hash_before": "abc", "hash_after": "abc", "save": "true", "load": "true",
            "mobiles_before": "3", "mobiles_after": "3",
            "pos_x": "100", "pos_y": "200", "pos_z": "3", "telo": "400",
        }
        d.update(zmeny)
        return d

    cases = [
        ("dobry", (0, dobre()), OK),
        ("vadny_rozdilny_hash", (0, dobre(hash_after="abd")), VADA),
        ("vadny_save_false", (0, dobre(save="false")), VADA),
        ("vadny_prazdny_hash", (0, dobre(hash_before="", hash_after="")), VADA),
        ("vadny_mobily_ubyly", (0, dobre(mobiles_after="1")), VADA),
        ("vadny_mobil_na_jine_pozici", (0, dobre(pos_x="0")), VADA),
        ("vadny_bez_entit", (0, dobre(mobiles_after=None)), VADA),
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
