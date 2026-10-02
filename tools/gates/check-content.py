#!/usr/bin/env python3
"""G5 check-content - obsah a krizove odkazy (docs/08 §8.2).

Meri (az budou data z M1+):
  * kazdy data/*.json se da precist (rozbity JSON je vada, ne prazdno),
  * kazdy zaznam ma pole, ktera zadani pozaduje (tvary z docs/04 §4.5),
  * krizove odkazy: recept -> material -> predmet, monster -> loot predmet,
  * a to, co zadani ZATIM NEPINUJE, se hlasi jako "SCHÉMA NEURČENO" (docs/06) -
    nikdy jako ticha zelená.

Rozsah se bere z roadmapy: granule, ktere vlastni soubor v data/.
Dokud zadny takovy soubor neni, je vysledek NEMERENO.

Spousteni:
  python tools/gates/check-content.py [--root .] [--json cesta]
  python tools/gates/check-content.py --self-test
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, grains_by_id, load_json, selftest_cli,
)

NAME = "check-content"

# Tvary, ktere zadani PINUJE (docs/04 §4.5). Co tu neni, se hlasi jako neurcene.
REQUIRED_FIELDS = {
    "recipes.json": ["id", "skill", "min_skill", "result", "materials"],
    "monsters.json": ["id", "body", "hits", "str", "dex", "int_", "skills",
                      "damage", "fame", "karma", "loot", "ai"],
    "items.json": ["tile", "name", "category", "weight", "value", "source"],
    "weapons.json": ["skill", "damage", "speed", "weight"],
    "spells.json": ["circle", "mana", "reagents", "target"],
    "regions.json": ["name"],
}

# Pocty C1-C10 z docs/06 - dokud je clovek nevyplni do schemat, brana je nemeni.
COUNTS_UNPINNED = "počty C1–C10: SCHÉMA NEURČENO (docs/06 §6.x) - kontrola je zatím neměří"


def as_records(data, key_guess: str) -> tuple[list[dict], str]:
    """Vrati seznam zaznamu a popis tvaru (docs/04 §4.5 tvar souboru nepinuje)."""
    if isinstance(data, list):
        return [r for r in data if isinstance(r, dict)], "seznam"
    if isinstance(data, dict):
        for key in (key_guess, "items", "records", "data"):
            if isinstance(data.get(key), list):
                return [r for r in data[key] if isinstance(r, dict)], f"{{{key}: [...]}}"
        return [], "slovník bez seznamu"
    return [], type(data).__name__


def check(root: Path, gate: Gate) -> None:
    by_id = grains_by_id(root)
    data_grains = sorted(g["id"] for g in by_id.values()
                         if any(o.startswith("data/") for o in g.get("owns", [])))
    files = sorted(p for p in (root / "data").glob("*.json")) if (root / "data").is_dir() else []
    gate.measure("data_granuli_v_roadmape", len(data_grains))
    gate.measure("data_souboru", len(files))

    if not files:
        gate.pending(
            "data/ neobsahuje žádný .json - kontrola obsahu nemá co měřit; čeká se na "
            + ", ".join(data_grains[:3]) + f" (celkem {len(data_grains)})"
        )
        return

    gate.note(COUNTS_UNPINNED)
    tables: dict[str, dict[int, dict]] = {}

    for path in files:
        rel = path.name
        try:
            data = load_json(path)
        except Exception as exc:
            gate.error(f"{rel}: JSON se nedá přečíst ({exc})")
            continue
        records, shape = as_records(data, rel.removesuffix(".json"))
        gate.measure(f"{rel}_zaznamu", len(records))
        gate.note(f"{rel}: tvar {shape}, záznamů {len(records)}")
        if not records:
            gate.error(f"{rel}: 0 záznamů (prázdný soubor není úspěch, docs/08 §8.6)")
            continue

        required = REQUIRED_FIELDS.get(rel)
        if required is None:
            gate.note(f"{rel}: schéma NENÍ PINOVANÉ v docs/04 §4.5 - kontrolují se jen křížové odkazy")
        else:
            for i, rec in enumerate(records):
                missing = [f for f in required if f not in rec]
                if missing:
                    gate.error(f"{rel}[{i}]: chybí pole " + ", ".join(missing))

        if rel == "items.json":
            tiles = set()
            for rec in records:
                for key in ("tile", "art"):
                    if isinstance(rec.get(key), int):
                        tiles.add(rec[key])
            tables["items"] = tiles
            gate.measure("items_tiles", len(tiles))

    # krizove odkazy: recepty a monstra na predmety
    items = tables.get("items")
    for rel in ("recipes.json", "monsters.json"):
        path = root / "data" / rel
        if not path.exists() or items is None:
            continue
        try:
            records, _ = as_records(load_json(path), rel.removesuffix(".json"))
        except Exception:
            continue
        checked = 0
        for i, rec in enumerate(records):
            refs: list[tuple[str, int]] = []
            for mat in rec.get("materials", []) or []:
                if isinstance(mat, dict) and isinstance(mat.get("tile"), int):
                    refs.append(("materials", mat["tile"]))
            result = rec.get("result")
            if isinstance(result, dict) and isinstance(result.get("tile"), int):
                refs.append(("result", result["tile"]))
            loot = rec.get("loot")
            if isinstance(loot, dict):
                for entry in loot.get("items", []) or []:
                    if isinstance(entry, dict) and isinstance(entry.get("tile"), int):
                        refs.append(("loot", entry["tile"]))
            for where, tile in refs:
                checked += 1
                if tile not in items:
                    gate.error(f"{rel}[{i}].{where}: odkazuje na tile {tile}, který není v items.json")
        gate.measure(f"{rel}_odkazu", checked)
        if checked == 0 and records:
            gate.note(f"{rel}: žádný odkaz na items.json - kontrola odkazů NEMĚŘENA pro tento soubor")


def selftest() -> int:
    import json
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-content"
    shutil.rmtree(base, ignore_errors=True)
    roadmap = {"milestones": [], "grains": [
        {"id": "data.items", "kind": "data", "owns": ["data/items.json"], "depends_on": [],
         "provides": [], "consumes": [], "acceptance": ["content"]},
        {"id": "data.recipes", "kind": "data", "owns": ["data/recipes.json"], "depends_on": [],
         "provides": [], "consumes": [], "acceptance": ["content"]},
    ]}
    item = {"tile": 0x1BEF, "name": "iron ingot", "category": "resource",
            "weight": 1, "value": 5, "source": "tiledata"}
    # vysledek i material musi byt v items.json, jinak je to (spravne) vada
    recipe = {"id": 1, "skill": 7, "min_skill": 1, "result": {"tile": 0x1BEF, "amount": 1},
              "materials": [{"tile": 0x1BEF, "amount": 3}]}

    def fixture(label: str, files: dict[str, object], raw: dict[str, str] | None = None) -> Path:
        root = base / label
        (root / ".forge").mkdir(parents=True, exist_ok=True)
        (root / ".forge" / "roadmap.json").write_text(json.dumps(roadmap, ensure_ascii=False), encoding="utf-8")
        for name, content in files.items():
            (root / "data").mkdir(parents=True, exist_ok=True)
            (root / "data" / name).write_text(json.dumps(content, ensure_ascii=False), encoding="utf-8")
        for name, text in (raw or {}).items():
            (root / "data").mkdir(parents=True, exist_ok=True)
            (root / "data" / name).write_text(text, encoding="utf-8")
        return root

    bad_recipe = dict(recipe, materials=[{"tile": 0x9999, "amount": 3}])
    cases = [
        ("dobry", fixture("dobry", {"items.json": [item], "recipes.json": [recipe]}), OK),
        ("vadny_odkaz", fixture("vadny_odkaz", {"items.json": [item], "recipes.json": [bad_recipe]}), VADA),
        ("vadny_chybi_pole", fixture("vadny_chybi_pole",
                                     {"items.json": [{k: v for k, v in item.items() if k != "value"}]}), VADA),
        ("vadny_prazdny", fixture("vadny_prazdny", {"items.json": []}), VADA),
        ("vadny_json", fixture("vadny_json", {}, raw={"items.json": "{tohle neni json"}), VADA),
        ("bez_dat", fixture("bez_dat", {}), NEMERENO),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G5 kontrola obsahu a křížových odkazů")
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
