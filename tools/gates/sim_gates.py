"""Spolecna cast bran G7 (save), G8 (determinismus) a G9 (replaye).

Vsechny tri meri beh simulace, ktera jeste neexistuje (sim/sim_world.gd je
granule sim.world_loop). Do te doby hlasi NEMERENO - a to se pozna podle
toho, ze soubor chybi, ne podle dojmu.

Kdyz soubor existuje, spusti se tools/gates/sim_probe.gd pres Godot a cte se
z nej strojovy vystup `PROBE klic=hodnota`.
"""

from __future__ import annotations

import re
from pathlib import Path

from gate_common import NEMERENO, godot_run

PROBE = "res://tools/gates/sim_probe.gd"
SIM_WORLD = "sim/sim_world.gd"


def parse_probe(output: str) -> dict[str, str]:
    """Precte vsechny dvojice `klic=hodnota` z radku zacinajicich `PROBE`.

    Na jednom radku jich muze byt vic (`PROBE save=true load=true`); prvni
    verze umela jen jednu a `load` pak vyslo jako None, i kdyz round-trip
    fungoval (namEReno 2026-10-02: brana G7 hlasila vadu, ktera nebyla)."""
    values: dict[str, str] = {}
    for line in output.splitlines():
        if not line.startswith("PROBE"):
            continue
        for match in re.finditer(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line):
            values[match.group(1)] = match.group(2)
    return values


def run_probe(root: Path, mode: str, extra: list[str] | None = None) -> tuple[int, str, dict[str, str]]:
    args = ["--script", PROBE, "--", f"--mode={mode}"] + (extra or [])
    rc, output = godot_run(root, args, timeout=600)
    return rc, output, parse_probe(output)


def sim_pending(root: Path, gate) -> bool:
    """Vrati True, kdyz neni co merit (a brana to uz nahlasila)."""
    if not (root / SIM_WORLD).exists():
        gate.pending(
            f"chybí {SIM_WORLD} (granule sim.world_loop) - není co měřit; "
            "AŽ BUDE, tato brána spustí tools/gates/sim_probe.gd a změří skutečný běh"
        )
        return True
    return False
