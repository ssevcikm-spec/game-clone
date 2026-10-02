#!/usr/bin/env python3
"""G1 check-schema - rozpor v zadani (docs/08 §8.2, §8.3).

Meri, ze tytez konstanty tvrdi vsechny zdroje stejne:
  docs/02 §2.4  <->  data/balance.json  <->  core/const.gd  <->  render/chunk_renderer.gd

Zelena plati jen kdyz:
  * jsou pritomne aspon DVA nezavisle zdroje (jinak NEMERENO - neni co s cim srovnavat),
  * core/const.gd ma vsechny konstanty z docs/04 §4.2 a zadna z nich nema
    NECITELNOU hodnotu (docs/08 §8.3: neprectena konstanta je vada, ne prazdny seznam),
  * hodnoty si neodporuji a plati ISO_STEP == TILE_W/2, TILE_H == TILE_W
    (to je mutace z docs/08 §8.8: ISO_STEP 23 v const.gd musi spadnout),
  * render/chunk_renderer.gd nema hodnoty konstant jako literaly.

Spousteni:
  python tools/gates/check-schema.py [--root .] [--json cesta]
  python tools/gates/check-schema.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, code_without_comments, load_json, read_text,
    selftest_cli,
)

NAME = "check-schema"
DOCS_FILE = "docs/02-technicka-rozhodnuti.md"
DOCS_SECTION = "## 2.4"
SOURCE_DOCS = "docs/02 §2.4"
SOURCE_CODE = "core/const.gd"
SOURCE_BALANCE = "data/balance.json"
SOURCE_RENDER = "render/chunk_renderer.gd"

# Konstanty, ktere docs/02 §2.4 uvadi primo - musi je mit i kod a musi sedet.
DOCS_CONSTANTS = ["TILE_W", "TILE_H", "ISO_STEP", "Z_SCALE", "Z_MIN", "Z_MAX"]

# Konstanty z docs/04 §4.2, ktere musi mit core/const.gd (kdyz soubor existuje).
CODE_CONSTANTS = DOCS_CONSTANTS + [
    "TICK_MS", "WALK_MS", "RUN_MS", "MOUNT_WALK_MS", "MOUNT_RUN_MS", "TURN_MS",
    "PERSON_HEIGHT", "STEP_HEIGHT", "LIFT_RANGE", "MAX_STACK",
    "CONTAINER_MAX_ITEMS", "CONTAINER_MAX_WEIGHT", "SKILL_CAP", "STAT_CAP",
    "SKILL_STEP",
]

# Vazby, ktere musi platit v kazdem zdroji nezavisle na ostatnich (docs/02 §2.4).
RELATIONS = [("ISO_STEP", "TILE_W", 2, "TILE_W/2"), ("TILE_H", "TILE_W", 1, "TILE_W")]

# Hodnoty, ktere se v rendereru nesmi objevit jako literal (hodnota by byla 2x).
MAGIC_IN_RENDER = {"TILE_W": 44, "ISO_STEP": 22, "Z_SCALE": 4}


def from_docs(root: Path) -> dict[str, int]:
    """Konstanty z tabulky docs/02 §2.4.

    bere i radek se dvema konstantami a rozsahem: | `Z_MIN`, `Z_MAX` | **-128 … 127** |
    """
    path = root / DOCS_FILE
    if not path.exists():
        return {}
    out: dict[str, int] = {}
    in_section = False
    for raw in read_text(path).splitlines():
        if raw.startswith("## "):
            in_section = raw.startswith(DOCS_SECTION)
            continue
        if not in_section or not raw.startswith("|"):
            continue
        line = raw.replace("\u2212", "-")
        names = re.findall(r"`([A-Z_0-9]+)`", line)
        nums = re.findall(r"\*\*(-?\d+)\s*(?:…|\.\.\.)?\s*(-?\d+)?\*\*", line)
        if len(names) == 1 and len(nums) == 1 and not nums[0][1]:
            out[names[0]] = int(nums[0][0])
        elif len(names) == 2 and len(nums) == 1 and nums[0][1]:
            out[names[0]] = int(nums[0][0])
            out[names[1]] = int(nums[0][1])
    return out


def from_const_gd(root: Path) -> dict[str, int]:
    """Konstanty z core/const.gd; komentare se odstranuji (docs/08 §8.1.3)."""
    path = root / SOURCE_CODE
    if not path.exists():
        return {}
    code = code_without_comments(read_text(path), "gd")
    out: dict[str, int] = {}
    for line in code.splitlines():
        m = re.match(r"^\s*const\s+([A-Z_0-9]+)\s*(?::\s*int\s*)?=\s*(-?\d[\d_]*)\s*$", line)
        if m:
            out[m.group(1)] = int(m.group(2).replace("_", ""))
    return out


def from_balance(root: Path) -> dict[str, int]:
    """data/balance.json - bere {"constants": {...}} i plochy slovnik."""
    path = root / SOURCE_BALANCE
    if not path.exists():
        return {}
    data = load_json(path)  # rozbity JSON vyhodi vyjimku -> volajici to hlasi jako vadu
    table = data.get("constants", data) if isinstance(data, dict) else {}
    return {k: v for k, v in table.items() if isinstance(v, int) and not isinstance(v, bool)}


def magic_numbers_in_renderer(root: Path) -> list[str]:
    path = root / SOURCE_RENDER
    if not path.exists():
        return []
    code = code_without_comments(read_text(path), "gd")
    problems = []
    for name, value in MAGIC_IN_RENDER.items():
        for i, line in enumerate(code.splitlines(), 1):
            if re.search(rf"(?<![\w.]){value}(?![\w.])", line):
                problems.append(
                    f"{SOURCE_RENDER}:{i}: literál {value} místo {name} "
                    f"({line.strip()[:60]})"
                )
    return problems


def check(root: Path, gate: Gate) -> None:
    sources: dict[str, dict[str, int]] = {}
    present: list[str] = []

    def add(name: str, values: dict[str, int]) -> None:
        sources[name] = values
        if values:
            present.append(name)

    add(SOURCE_DOCS, from_docs(root))
    add(SOURCE_CODE, from_const_gd(root))
    try:
        add(SOURCE_BALANCE, from_balance(root))
    except Exception as exc:
        gate.error(f"{SOURCE_BALANCE} se nedá přečíst: {exc}")
        add(SOURCE_BALANCE, {})

    gate.measure("zdroje_pritomne", present)
    gate.measure("zdroje_sledovane", list(sources))

    # 1) co musi byt citelne, kdyz soubor existuje
    if (root / DOCS_FILE).exists() and not sources[SOURCE_DOCS]:
        gate.error(f"{DOCS_FILE} §2.4: žádnou konstantu nelze přečíst (kontrola NEPROBĚHLA)")
    if sources[SOURCE_CODE]:
        missing = [c for c in CODE_CONSTANTS if c not in sources[SOURCE_CODE]]
        if missing:
            gate.error(f"{SOURCE_CODE}: chybí konstanty " + ", ".join(missing))
        unreadable = [c for c in DOCS_CONSTANTS if c not in sources[SOURCE_DOCS]] if sources[SOURCE_DOCS] else []
        if unreadable:
            gate.error(f"{SOURCE_DOCS}: konstanty " + ", ".join(unreadable) + " nelze přečíst")

    # 2) vnitrni vazby v kazdem zdroji
    for name, values in sources.items():
        for target, base, factor, text in RELATIONS:
            if target in values and base in values:
                if values[target] != values[base] // factor:
                    gate.error(
                        f"{name}: {target} != {text} ({values[target]} != {values[base] // factor})"
                    )

    # 3) krizove srovnani stejne konstanty mezi zdroji
    compared = 0
    for const in DOCS_CONSTANTS:
        seen = {name: values[const] for name, values in sources.items() if const in values}
        if len(seen) < 2:
            continue
        compared += 1
        if len(set(seen.values())) != 1:
            gate.error(f"{const}: zdroje si odporují -> " + ", ".join(f"{n}={v}" for n, v in seen.items()))
    gate.measure("konstant_srovnano", compared)
    if sources[SOURCE_CODE]:
        gate.measure("konstant_v_kodu", len(sources[SOURCE_CODE]))

    # 4) kod kresleni nesmi mit hodnoty jako literaly
    magic = magic_numbers_in_renderer(root)
    for m in magic:
        gate.error(m)
    gate.measure("render_literalu", len(magic))

    if compared == 0 and not gate.errors:
        gate.pending(
            "méně než dva zdroje konstant (přítomné: "
            + (", ".join(present) if present else "žádný")
            + ") - není co s čím srovnat, čeká se na core.const (W0)"
        )


def selftest() -> int:
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-schema"
    shutil.rmtree(base, ignore_errors=True)
    good_docs = (
        "## 2.4 Souřadnice, izometrie, vykreslování\n\n"
        "| Konstanta | Hodnota | Význam |\n|---|---|---|\n"
        "| `TILE_W` | **44** | šířka |\n| `TILE_H` | **44** | výška |\n"
        "| `ISO_STEP` | **22** | posun |\n| `Z_SCALE` | **4** | px na z |\n"
        "| `Z_MIN`, `Z_MAX` | **−128 … 127** | rozsah |\n"
    )

    def consts(iso: int = 22, tile: int = 44) -> str:
        rows = [("TILE_W", tile), ("TILE_H", 44), ("ISO_STEP", iso), ("Z_SCALE", 4),
                ("Z_MIN", -128), ("Z_MAX", 127), ("TICK_MS", 50), ("WALK_MS", 400),
                ("RUN_MS", 200), ("MOUNT_WALK_MS", 200), ("MOUNT_RUN_MS", 100),
                ("TURN_MS", 80), ("PERSON_HEIGHT", 16), ("STEP_HEIGHT", 2),
                ("LIFT_RANGE", 2), ("MAX_STACK", 60000), ("CONTAINER_MAX_ITEMS", 125),
                ("CONTAINER_MAX_WEIGHT", 400), ("SKILL_CAP", 7000), ("STAT_CAP", 225),
                ("SKILL_STEP", 1)]
        return "extends RefCounted\n" + "".join(f"const {n}: int = {v}\n" for n, v in rows)

    cases: list[tuple[str, Path, int]] = []
    plan = [
        ("dobry", good_docs, consts(), OK),
        ("vadny_iso_23", good_docs, consts(iso=23), VADA),
        ("vadny_docs_vs_kod", good_docs.replace("**44** | šířka", "**45** | šířka"), consts(), VADA),
        ("vadny_chybi_const", good_docs, consts().replace("const SKILL_CAP: int = 7000\n", ""), VADA),
        ("vadny_render_literal", good_docs, consts(), VADA),
        # docs existuji, ale §2.4 se neda precist -> VADA (docs/08 §8.3)
        ("vadny_docs_nema_sekci", "## 2.5 Něco jiného\n\n| `TILE_W` | **44** |\n", consts(), VADA),
        ("jen_docs", good_docs, None, NEMERENO),
        ("jen_kod", None, consts(), NEMERENO),
    ]
    for label, doc, gd, expected in plan:
        fixture = base / label
        fixture.mkdir(parents=True, exist_ok=True)
        if doc is not None:
            (fixture / "docs").mkdir(parents=True, exist_ok=True)
            (fixture / "docs" / "02-technicka-rozhodnuti.md").write_text(doc, encoding="utf-8")
        if gd is not None:
            (fixture / "core").mkdir(parents=True, exist_ok=True)
            (fixture / "core" / "const.gd").write_text(gd, encoding="utf-8")
        if label == "vadny_render_literal":
            (fixture / "render").mkdir(parents=True, exist_ok=True)
            (fixture / "render" / "chunk_renderer.gd").write_text(
                "extends Node2D\nvar w := 44  # literál místo TILE_W\nvec = Vector2(0, 22)\n",
                encoding="utf-8",
            )
        cases.append((label, fixture, expected))

    return selftest_cli(
        NAME,
        check,
        [(label, expected) for label, _, expected in cases],
        fixtures=[(label, f) for label, f, _ in cases],
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="G1 kontrola schématu a konstant")
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
