#!/usr/bin/env python3
"""G9 check-replay - skriptovane sekvence daji ocekavany hash (docs/08 §8.2).

Replaye jsou v `tests/replays/*.json` (vlastni je bootstrap granule boot.tests)
ve tvaru `{commands: [{at: tick, t: ..., ...}], ticks: int, hash: "..."}`.
Kazdy replay MUSI mit ocekavany hash - jinak se neda nic overit a je to vada.

Spousteni:
  python tools/gates/check-replay.py [--root .] [--json cesta]
  python tools/gates/check-replay.py --self-test
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, read_text, selftest_cli  # noqa: E402
from sim_gates import run_probe, sim_pending  # noqa: E402

NAME = "check-replay"
REPLAY_DIR = "tests/replays"


def validate(gate: Gate, path: Path) -> dict | None:
    rel = path.relative_to(path.parents[2]).as_posix() if len(path.parents) > 2 else path.name
    try:
        data = json.loads(read_text(path))
    except Exception as exc:
        gate.error(f"{rel}: JSON se nedá přečíst ({exc})")
        return None
    if not isinstance(data, dict):
        gate.error(f"{rel}: replay musí být objekt, ne {type(data).__name__}")
        return None
    commands = data.get("commands")
    if not isinstance(commands, list) or not commands:
        gate.error(f"{rel}: chybí neprázdný seznam `commands`")
        return None
    ticks = data.get("ticks")
    if not isinstance(ticks, int) or ticks <= 0:
        gate.error(f"{rel}: `ticks` musí být kladné celé číslo (je {ticks!r})")
        return None
    if not isinstance(data.get("hash"), str) or not data["hash"]:
        gate.error(f"{rel}: chybí `hash` s očekávaným stavem (bez něj replay nic neměří)")
        return None
    return data


def evaluate(gate: Gate, replay: str, rc: int, values: dict[str, str]) -> None:
    gate.measure("exit_kod", rc)
    if values.get("hash") is None:
        gate.error(f"{replay}: sim_probe nevrátil hash (exit {rc})")
        return
    got, expected = values["hash"], values.get("expected", "")
    gate.measure(f"hash[{replay}]", got)
    gate.measure(f"ocekavano[{replay}]", expected)
    if got != expected:
        gate.error(f"{replay}: očekávaný hash {expected}, naměřeno {got}")


def check_shapes(root: Path, gate: Gate) -> list[tuple[str, dict]]:
    """Cást, kterou lze měřit bez Godotu: tvar replayu. Vrací platné replaye."""
    directory = root / REPLAY_DIR
    files = sorted(directory.glob("*.json")) if directory.is_dir() else []
    gate.measure("replayu", len(files))
    if not files:
        gate.pending(
            f"{REPLAY_DIR} neobsahuje žádný .json - replaye nemá co měřit "
            "(vlastní je bootstrap granule boot.tests)"
        )
        return []
    valid: list[tuple[str, dict]] = []
    for path in files:
        data = validate(gate, path)
        if data is not None:
            valid.append((path.name, data))
    gate.measure("replayu_platnych", len(valid))
    return valid


def check(root: Path, gate: Gate) -> None:
    valid = check_shapes(root, gate)
    if not valid or sim_pending(root, gate):
        return
    for name, _ in valid:
        rc, _, values = run_probe(root, "replay", [f"--replay=res://{REPLAY_DIR}/{name}"])
        evaluate(gate, name, rc, values)


def selftest() -> int:
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-replay"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, replays: dict[str, str], with_sim: bool = False) -> Path:
        root = base / label
        (root / "tests" / "replays").mkdir(parents=True, exist_ok=True)
        for name, text in replays.items():
            (root / "tests" / "replays" / name).write_text(text, encoding="utf-8")
        if with_sim:
            (root / "sim").mkdir(parents=True, exist_ok=True)
            (root / "sim" / "sim_world.gd").write_text("extends RefCounted\n", encoding="utf-8")
        return root

    good = json.dumps({"commands": [{"at": 0, "t": "move", "dir": 0, "run": False, "seq": 1}],
                       "ticks": 100, "hash": "deadbeef"})
    no_hash = json.dumps({"commands": [{"at": 0, "t": "move"}], "ticks": 100})
    empty_cmds = json.dumps({"commands": [], "ticks": 100, "hash": "x"})
    cases = [
        ("dobry", fixture("dobry", {"a.json": good}), OK),
        ("vadny_chybi_hash", fixture("vadny_chybi_hash", {"a.json": no_hash}), VADA),
        ("vadny_prazdne_prikazy", fixture("vadny_prazdne_prikazy", {"a.json": empty_cmds}), VADA),
        ("vadny_json", fixture("vadny_json", {"a.json": "{ne"}), VADA),
        ("bez_replayu", fixture("bez_replayu", {}), NEMERENO),
    ]
    shapes = selftest_cli(NAME + "/tvary", check_shapes,
                          [(l, e) for l, _, e in cases],
                          fixtures=[(l, f) for l, f, _ in cases])

    # druha cast: srovnani hashe z replaye (bez spousteni Godotu)
    runs = [
        ("dobry", ("a.json", 0, {"hash": "deadbeef", "expected": "deadbeef"}), OK),
        ("vadny_jiny_hash", ("a.json", 0, {"hash": "cafe", "expected": "deadbeef"}), VADA),
        ("vadny_bez_hashe", ("a.json", 1, {}), VADA),
    ]
    hashes = selftest_cli(NAME + "/hashe",
                          lambda data, gate: evaluate(gate, data[0], data[1], data[2]),
                          [(l, e) for l, _, e in runs],
                          fixtures=[(l, d) for l, d, _ in runs])
    return VADA if (shapes or hashes) else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G9 replaye")
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
