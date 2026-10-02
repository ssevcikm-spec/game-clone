#!/usr/bin/env python3
"""G2 check-layers - smer zavislosti (docs/04 §4.1, docs/08 §8.2).

`sim/**` nesmi odkazovat `ui/`, `render/`, `app/` a nesmi obsahovat
`Input.`, `Time.`, `OS.`, `randf(`, `randi(`. Je to tvrda brana: jediny
zakazany odkaz = VADA.

Kontrola CTE KOD, ne komentare (docs/08 §8.1.3) - proto se komentare
odstranuji pred hledanim vzoru. Cesty se hledaji ve stringech (zachovane),
identifikatory v kode bez stringu, aby nasel kazdou vadu prave jednou.

Spousteni:
  python tools/gates/check-layers.py [--root .] [--json cesta]
  python tools/gates/check-layers.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, code_without_comments, grains_by_id, read_text,
    selftest_cli,
)

NAME = "check-layers"
FORBIDDEN_PATHS = ["res://ui/", "res://render/", "res://app/", "res://tests/"]
FORBIDDEN_IDENTS = ["Input.", "Time.", "OS.", "randf(", "randi("]


def strip_comments_only(text: str) -> str:
    """Odstrani komentare, stringy necha - kvuli kontrolam cest v preload()."""
    return "\n".join(re.sub(r"#.*$", "", line) for line in text.splitlines())


def sim_files(root: Path) -> list[Path]:
    sim = root / "sim"
    if not sim.is_dir():
        return []
    return sorted(p for p in sim.rglob("*.gd") if p.is_file())


def check(root: Path, gate: Gate) -> None:
    by_id = grains_by_id(root)
    sim_ids = [g["id"] for g in by_id.values()
               if any(o.startswith("sim/") for o in g.get("owns", []))]
    files = sim_files(root)
    gate.measure("sim_granuli_v_roadmape", len(sim_ids))
    gate.measure("sim_souboru", len(files))

    if not files:
        gate.pending(
            "sim/ neobsahuje žádný .gd soubor - kontrola vrstev nemá co měřit; "
            f"čeká se na {', '.join(sim_ids[:3])} (a další, celkem {len(sim_ids)})"
        )
        return

    path_hits = 0
    ident_hits = 0
    for path in files:
        rel = path.relative_to(root).as_posix()
        raw = strip_comments_only(read_text(path))
        code = code_without_comments(read_text(path), "gd")
        for i, line in enumerate(raw.splitlines(), 1):
            for bad in FORBIDDEN_PATHS:
                if bad in line:
                    path_hits += 1
                    gate.error(f"{rel}:{i}: sim/ nesmí odkazovat {bad} ({line.strip()[:60]})")
        for i, line in enumerate(code.splitlines(), 1):
            for bad in FORBIDDEN_IDENTS:
                if bad in line:
                    ident_hits += 1
                    gate.error(f"{rel}:{i}: sim/ nesmí používat {bad} ({line.strip()[:60]})")

    gate.measure("zakazanych_cest", path_hits)
    gate.measure("zakazanych_identifikatoru", ident_hits)


def selftest() -> int:
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-layers"
    shutil.rmtree(base, ignore_errors=True)
    roadmap = ('{"_popis": ["fixture"], "milestones": [], "grains": ['
               '{"id": "sim.commands", "kind": "code", "owns": ["sim/commands.gd"], '
               '"depends_on": [], "provides": [], "consumes": [], "acceptance": []}]}')

    def fixture(label: str, sim_code: str | None) -> Path:
        root = base / label
        (root / ".forge").mkdir(parents=True, exist_ok=True)
        (root / ".forge" / "roadmap.json").write_text(roadmap, encoding="utf-8")
        if sim_code is not None:
            (root / "sim").mkdir(parents=True, exist_ok=True)
            (root / "sim" / "commands.gd").write_text(sim_code, encoding="utf-8")
        return root

    clean = "extends RefCounted\nfunc parse(d: Dictionary) -> Dictionary:\n\treturn d\n"
    cases = [
        ("dobry", fixture("dobry", clean), OK),
        # zakazany identifikator i cesta
        ("vadny_input", fixture("vadny_input", clean + "func x():\n\tvar a := Input.is_action_pressed(\"ui_accept\")\n"), VADA),
        ("vadny_cesta", fixture("vadny_cesta", "extends RefCounted\nconst U = preload(\"res://ui/hud.gd\")\n"), VADA),
        ("vadny_randf", fixture("vadny_randf", clean + "func y() -> float:\n\treturn randf()\n"), VADA),
        # komentar popisujici vadu NENI vada (docs/08 §8.1.3)
        ("komentar_neni_vada", fixture("komentar_neni_vada", "# tady se NESMI pouzit Input. ani randf(\n" + clean), OK),
        # bez sim/ neni co merit
        ("bez_sim", fixture("bez_sim", None), NEMERENO),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G2 kontrola vrstev")
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
