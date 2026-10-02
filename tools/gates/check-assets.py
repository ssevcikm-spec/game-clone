#!/usr/bin/env python3
"""G6 check-assets - manifest vs. stranky atlasu (docs/08 §8.2, §8.4).

Assety se extrahuji z instalace UO lokalne a necommituji (assets/uo/ je
v .gitignore), takze v CI nejsou. To se NESMI tise preskocit: brana to
vypise jako SKIP a skonci 2 (docs/08 §8.4).

Meri: manifest existuje a je citelny, kazda stranka atlasu z manifestu
existuje, pocet prazdnych spritu (pruhledny sprite je vada, docs/08 G6).

Spousteni:
  python tools/gates/check-assets.py [--root .] [--json cesta]
  python tools/gates/check-assets.py --self-test
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, load_json, selftest_cli,
)

NAME = "check-assets"
MANIFEST_CANDIDATES = ("assets/atlas/manifest.json", "assets/uo/manifest.json")


def find_manifest(root: Path) -> Path | None:
    for rel in MANIFEST_CANDIDATES:
        path = root / rel
        if path.exists():
            return path
    return None


def collect_entries(data) -> tuple[list[dict], str]:
    if isinstance(data, list):
        return [e for e in data if isinstance(e, dict)], "seznam"
    if isinstance(data, dict):
        for key in ("sprites", "entries", "tiles", "items"):
            if isinstance(data.get(key), list):
                return [e for e in data[key] if isinstance(e, dict)], f"{{{key}: [...]}}"
        if isinstance(data.get("pages"), list):
            return [e for e in data["pages"] if isinstance(e, dict)], "{pages: [...]}"
    return [], "neznámý tvar"


def check(root: Path, gate: Gate) -> None:
    manifest = find_manifest(root)
    if manifest is None:
        gate.skip(
            "manifest atlasu není (assety se extrahují lokálně z instalace UO; "
            "v CI chybí - kontrola NEPROBĚHLA, docs/08 §8.4)"
        )
        return

    try:
        data = load_json(manifest)
    except Exception as exc:
        gate.error(f"{manifest.relative_to(root).as_posix()}: JSON se nedá přečíst ({exc})")
        return

    entries, shape = collect_entries(data)
    gate.measure("manifest", manifest.relative_to(root).as_posix())
    gate.measure("zaznamu", len(entries))
    gate.note(f"manifest tvar: {shape}")
    if not entries:
        gate.error("manifest nemá žádný záznam (prázdný manifest není úspěch)")
        return

    pages: set[str] = set()
    for entry in entries:
        for key in ("page", "atlas", "file", "sheet"):
            value = entry.get(key)
            if isinstance(value, str):
                pages.add(value)

    gate.measure("stranek", len(pages))
    if not pages:
        gate.note("manifest neuvádí stránky atlasu (klíč page/atlas/file) - existence stránek NEMĚŘENA")
        return

    base = manifest.parent
    missing = 0
    for page in sorted(pages):
        candidate = (base / page)
        if not candidate.exists():
            candidate = root / page
        if not candidate.exists():
            missing += 1
            gate.error(f"stránka atlasu z manifestu chybí: {page}")
    gate.measure("stranek_chybi", missing)

    # prazdne sprity - jen kdyz je cim merit (Pillow + skutecne PNG)
    try:
        from PIL import Image  # noqa: F401
    except Exception:
        gate.note("Pillow není k dispozici - prázdné sprity NEMĚŘENY")
        return
    checked = 0
    empty = 0
    for entry in entries:
        page = entry.get("page") or entry.get("atlas") or entry.get("file")
        rect = entry.get("rect") or entry.get("src")
        if not isinstance(page, str) or not isinstance(rect, (list, tuple)) or len(rect) != 4:
            continue
        candidate = base / page
        if not candidate.exists():
            candidate = root / page
        if not candidate.exists():
            continue
        try:
            from PIL import Image
            with Image.open(candidate) as img:
                region = img.convert("RGBA").crop(tuple(int(v) for v in rect))
                if region.getbbox() is None:
                    empty += 1
                    gate.error(f"prázdný sprite: {page} {tuple(rect)} (docs/08 G6)")
                checked += 1
        except Exception as exc:
            gate.error(f"{page} {tuple(rect)}: sprite nelze změřit ({exc})")
    gate.measure("spritu_zkontrolovano", checked)
    gate.measure("spritu_prazdnych", empty)


def selftest() -> int:
    import json
    import shutil

    try:
        from PIL import Image
    except Exception:
        print(f"[{NAME}] self-test: Pillow není k dispozici, test NEPROBĚHL")
        return NEMERENO

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-assets"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, manifest: dict | None, pages: list[str]) -> Path:
        root = base / label
        (root / "assets" / "atlas").mkdir(parents=True, exist_ok=True)
        if manifest is not None:
            (root / "assets" / "atlas" / "manifest.json").write_text(
                json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        for page in pages:
            target = root / "assets" / "atlas" / page
            # platny PNG: kontrola prázdných spritů potřebuje obrázek, ne hlavičku
            img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            for px in range(0, 44):
                for py in range(0, 44):
                    img.putpixel((px, py), (200, 120, 40, 255))
            img.save(target)
        return root

    good = {"sprites": [{"tile": 1, "page": "atlas0.png", "rect": [0, 0, 44, 44]}]}
    cases = [
        ("dobry", fixture("dobry", good, ["atlas0.png"]), OK),
        ("vadny_chybi_stranka", fixture("vadny_chybi_stranka", good, []), VADA),
        ("vadny_prazdny_manifest", fixture("vadny_prazdny_manifest", {"sprites": []}, []), VADA),
        ("bez_manifestu", fixture("bez_manifestu", None, []), NEMERENO),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G6 kontrola assetů")
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
