#!/usr/bin/env python3
"""G10 check-render - vizualni korektnost MERENA (docs/08 §8.2, §8.3).

NamEReno v zadani: hrac nebyl na obrazovce (dlazdice mely vyssi z_index)
a pritom byly testy, schema i assety zelene. Proto se "je videt postava"
meri v PIXELECH, ne dojmem.

Brana meri na snimku:
  * snimek jde nacist a neni jednolity (jednolita barva = nic se nevykreslilo),
  * v ocekavane oblasti (stred, nebo --focus) jsou nenulove pixely - to je
    "postava neni prekryta" v meritelne podobe,
  * pocet barev a podil pozadi (pro lidskou kontrolu v logu).

Bez `render/` kodu nebo bez snimku je vysledek NEMERENO - nikdy zelena.

Spousteni:
  python tools/gates/check-render.py [--root .] [--snapshot cesta.png] [--focus x,y,w,h]
  python tools/gates/check-render.py --self-test
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, selftest_cli  # noqa: E402

NAME = "check-render"
DEFAULT_SNAPSHOT = ".cache/render/snapshot.png"
RENDER_GRAINS = ("render.chunk", "render.sort")
# Data, bez kterych se nema co vykreslit (assets/uo/ je v .gitignore, takze
# v cerstvem klonu nejsou). Chybejici DATA nejsou vada kódu - viz check().
ASSET_INPUTS = ("manifest.json", "world/map0.meta.json", "world/map0.land",
                "world/map0.statics.bin")


def missing_assets(root: Path) -> list[str]:
    base = root / "assets" / "uo"
    return [name for name in ASSET_INPUTS if not (base / name).exists()]


def render_sources(root: Path) -> list[Path]:
    base = root / "render"
    return sorted(p for p in base.rglob("*.gd")) if base.is_dir() else []


def measure_image(path: Path, focus: tuple[int, int, int, int] | None, gate: Gate) -> None:
    try:
        import numpy as np
        from PIL import Image
    except Exception as exc:
        gate.skip(f"Pillow/numpy nejsou k dispozici ({exc}) - snímek NEMĚŘEN")
        return
    try:
        with Image.open(path) as img:
            rgb = img.convert("RGB")
            gate.measure("snimek", f"{path.name} {rgb.width}x{rgb.height}")
            array = np.asarray(rgb)
    except Exception as exc:
        gate.error(f"snímek {path} nelze přečíst ({exc})")
        return

    colors, counts = np.unique(array.reshape(-1, 3), axis=0, return_counts=True)
    gate.measure("barev", int(colors.shape[0]))
    if colors.shape[0] <= 1:
        gate.error("snímek je jednolitý - nic se nevykreslilo (docs/08 §8.3)")
        return

    # pozadi = NEJCASTSI barva, ne pixel (0,0): jinak se za pozadi prohlasi
    # rohova postava a "nenulove pixely" vyjdou i tam, kde nic neni (namEReno
    # v self-testu pripadu vadny_postava_mimo).
    background = colors[int(np.argmax(counts))]
    differs = np.any(array != background, axis=2)
    gate.measure("pixelu_mimo_pozadi", int(differs.sum()))

    x, y, w, h = focus or (array.shape[1] // 3, array.shape[0] // 3,
                           max(1, array.shape[1] // 3), max(1, array.shape[0] // 3))
    region = differs[y:y + h, x:x + w]
    inside = int(region.sum())
    gate.measure("oblast", f"{x},{y},{w},{h}")
    gate.measure("pixelu_v_oblasti", inside)
    if inside == 0:
        gate.error(
            f"v očekávané oblasti {x},{y},{w},{h} není žádný nenulový pixel - "
            "postava je překrytá nebo se nevykreslila (docs/08 G10)"
        )


def check(root: Path, gate: Gate, snapshot: Path | None = None,
          focus: tuple[int, int, int, int] | None = None) -> None:
    sources = render_sources(root)
    gate.measure("render_souboru", len(sources))
    if not sources:
        gate.pending(
            "render/ neobsahuje žádný .gd - není co vykreslovat; čeká se na "
            + ", ".join(RENDER_GRAINS) + " (W1/W3)"
        )
        return
    chybi = missing_assets(root)
    if chybi:
        # NamEReno 2026-10-06 v simulaci cerstveho klonu: bez assets/uo se
        # vykresli JEDINA barva (77,77,77) a brana na tom hlasila VADA. To je
        # vada prostredi (chybeji DATA), ne kódu - v CI assety nikdy nejsou
        # (docs/08 §8.4). NEMERENO neni zelena a je videt v souhrnu.
        gate.pending(
            "chybí data pro vykreslení (assets/uo: " + ", ".join(chybi) + ") - "
            "v tomto klonu nejsou extrahovaná data UO, snímek by měřil jen barvu "
            "pozadí; NEMĚŘENO (spusť tools/uoextract/worldmap.py --extract)"
        )
        return
    path = snapshot or (root / DEFAULT_SNAPSHOT)
    if not path.exists():
        gate.pending(f"snímek {path} není - G10 měří pixely, bez snímku NEMĚŘENO")
        return
    measure_image(path, focus, gate)


def selftest() -> int:
    import shutil

    try:
        from PIL import Image
    except Exception:
        print(f"[{NAME}] self-test: Pillow není k dispozici, test NEPROBĚHL")
        return NEMERENO

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-render"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, kind: str, with_render: bool = True,
                with_assets: bool = True) -> Path:
        root = base / label
        if with_render:
            (root / "render").mkdir(parents=True, exist_ok=True)
            (root / "render" / "chunk_renderer.gd").write_text("extends Node2D\n", encoding="utf-8")
        if with_assets:
            # Klon s extrahovanymi daty: jen existence, obsah tu nikdo nemeri
            # (v CI assety nejsou a brana to musi umet rict nahlas).
            for name in ASSET_INPUTS:
                cil = root / "assets" / "uo" / name
                cil.parent.mkdir(parents=True, exist_ok=True)
                cil.write_bytes(b"stub")
        target = root / DEFAULT_SNAPSHOT
        target.parent.mkdir(parents=True, exist_ok=True)
        if kind == "blank":
            Image.new("RGB", (128, 128), (0, 0, 0)).save(target)
        elif kind == "blob_center":
            img = Image.new("RGB", (128, 128), (10, 10, 10))
            for px in range(50, 78):
                for py in range(50, 78):
                    img.putpixel((px, py), (220, 40, 40))
            img.save(target)
        elif kind == "blob_corner":
            img = Image.new("RGB", (128, 128), (10, 10, 10))
            for px in range(0, 8):
                for py in range(0, 8):
                    img.putpixel((px, py), (220, 40, 40))
            img.save(target)
        return root

    cases = [
        ("dobry", fixture("dobry", "blob_center"), OK),
        ("vadny_jednolity", fixture("vadny_jednolity", "blank"), VADA),
        ("vadny_postava_mimo", fixture("vadny_postava_mimo", "blob_corner"), VADA),
        ("bez_render_kodu", fixture("bez_render_kodu", "blob_center", with_render=False), NEMERENO),
        # klon bez extrahovanych dat: snimek muze byt klidne "pekny", ale merit
        # se nema co - a NEMERENO se nesmi tvarit jako VADA kódu (docs/08 §8.4)
        ("bez_assetu", fixture("bez_assetu", "blank", with_assets=False), NEMERENO),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G10 kontrola vykreslování ze snímku")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--snapshot", default=None)
    ap.add_argument("--focus", default=None, help="x,y,w,h")
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    focus = None
    if args.focus:
        focus = tuple(int(v) for v in args.focus.split(","))  # type: ignore[assignment]
    gate = Gate(NAME)
    check(Path(args.root).resolve(), gate,
          Path(args.snapshot) if args.snapshot else None, focus)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
