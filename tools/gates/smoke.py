#!/usr/bin/env python3
"""G11 smoke - hra se spusti bez SCRIPT ERROR (docs/08 §8.2).

Spusti projekt headless, necha ho bezet 300 framu a meri dve veci, ktere si
mohou odporovat (docs/08 past 9): vystup hleda `SCRIPT ERROR` a zaroven cte
exit kod. Adresar pro `user://` se presmeruje do workspace (docs/02 §2.1).

Spousteni:
  python tools/gates/smoke.py [--root .] [--frames 300]
  python tools/gates/smoke.py --self-test
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, godot_bin, godot_run, selftest_cli,
)

NAME = "smoke"
LOG_PATTERNS = {
    "script_error": "SCRIPT ERROR",
    "parse_error": "Parse Error",
    "write_failed": "Failed to open log file for writing",
    "cannot_create_dir": "Could not create directory",
}


def scan(output: str) -> dict[str, int]:
    return {key: output.count(needle) for key, needle in LOG_PATTERNS.items()}


def check(root: Path, gate: Gate, frames: int = 300) -> None:
    project = root / "project.godot"
    if not project.exists():
        gate.pending("chybí project.godot - není co spustit (čeká se na boot.project)")
        return
    if godot_bin() is None:
        gate.skip("Godot není k dispozici (nastav $GODOT nebo dodej binárku do .cache/godot)")
        return

    rc, output = godot_run(root, ["--quit-after", str(frames)])
    counts = scan(output)
    own_dirs = ("core", "sim", "ui", "render", "app", "tests", "tools")
    own_gd = [p for d in own_dirs if (root / d).is_dir() for p in (root / d).rglob("*.gd")]
    gate.measure("exit_kod", rc)
    gate.measure("framu", frames)
    gate.measure("behu", 1)
    # pocita se jen kod hry, ne referencni klony v _src/ a research/
    gate.measure("gd_souboru_hry", len(own_gd))
    for key, value in counts.items():
        gate.measure(key, value)

    if counts["write_failed"] or counts["cannot_create_dir"]:
        # Prostredi, ne vada hry: engine spusteny mimo workspace nemuze zapisovat.
        gate.skip(
            "Godot nemohl zapisovat do user:// (sandbox) - použij kopii ve workspace, "
            "viz gate_common.godot_bin(); běh tím NEPROBĚHL"
        )
        return
    if counts["script_error"] or counts["parse_error"]:
        for i, line in enumerate(output.splitlines(), 1):
            if "SCRIPT ERROR" in line or "Parse Error" in line:
                gate.error(f"výstup:{i}: {line.strip()[:120]}")
    if rc != 0:
        gate.error(f"Godot skončil s exit kódem {rc} (výstup čti i přesto, že exit je nenulový)")


def selftest() -> int:
    """Offline test: kontroluje se sama analyza vystupu (bez spousteni Godotu)."""
    samples = {
        "cisty_beh": ("Godot Engine v4.7.2\n", 0, OK),
        "script_error": ("Godot Engine v4.7.2\nSCRIPT ERROR: Invalid call\n", 0, VADA),
        "parse_error": ("Parse Error: Expected end of statement\n", 1, VADA),
        "exit_nenulovy": ("Godot Engine v4.7.2\n", 1, VADA),
        "zapis_blokovan": ("ERROR: Failed to open log file for writing: user://logs\n", 0, NEMERENO),
    }

    def check_sample(root: Path, gate: Gate) -> None:
        output, rc, _ = samples[root.name]
        counts = scan(output)
        gate.measure("exit_kod", rc)
        gate.measure("behu", 1)
        for key, value in counts.items():
            gate.measure(key, value)
        if counts["write_failed"] or counts["cannot_create_dir"]:
            gate.skip("Godot nemohl zapisovat (sandbox)")
            return
        if counts["script_error"] or counts["parse_error"]:
            gate.error("ve výstupu je SCRIPT ERROR / Parse Error")
        if rc != 0:
            gate.error(f"exit kód {rc}")

    return selftest_cli(NAME, check_sample, [(l, s[2]) for l, s in samples.items()],
                        fixtures=[(l, Path(l)) for l in samples])


def main() -> int:
    ap = argparse.ArgumentParser(description="G11 smoke běh")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--frames", type=int, default=300)
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    gate = Gate(NAME)
    check(Path(args.root).resolve(), gate, args.frames)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
