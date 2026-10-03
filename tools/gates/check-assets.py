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


def check_extraction_outputs(root: Path, gate: Gate) -> int:
    """Zkontroluje, co uz je extrahovane na disku (assets/uo/...).

    Proc: G6 dosud umela jen manifest atlasu, ktery v CI neni - takze vždy
    NEMERENO. Extrahovana data pritom vznikaji uz v M1 (mapa, barvy, nahledy)
    a jdou zkontrolovat hned. Kdyz nic z toho neni, vraci 0 a brana se chova
    jako predtim (SKIP kvuli chybejicim assetum, docs/08 §8.4).

    Vse se overuje proti CISLUM V SOUBORECH, ne proti dojmu: meta.json mapy
    musi sedet na velikosti souboru, ktere popisuje.
    """
    checked = 0

    meta_path = root / "assets" / "uo" / "world" / "map0.meta.json"
    if meta_path.exists():
        try:
            meta = load_json(meta_path)
        except Exception as exc:
            gate.error(f"world/map0.meta.json se nedá přečíst ({exc})")
            return checked
        checked += 1
        land_path = root / "assets" / "uo" / "world" / "map0.land"
        bin_path = root / "assets" / "uo" / "world" / "map0.statics.bin"
        idx_path = root / "assets" / "uo" / "world" / "map0.statics.idx"
        blocks = int(meta.get("blocks_x", 0)) * int(meta.get("blocks_y", 0))
        gate.measure("mapa_bloku", blocks)
        gate.measure("mapa_dlazdic", int(meta.get("land_tiles", 0)))
        if land_path.exists():
            expected = blocks * int(meta.get("block_bytes", 0))
            actual = land_path.stat().st_size
            gate.measure("mapa_land_bajtu", actual)
            if expected and actual != expected:
                gate.error(f"map0.land má {actual} B, meta.json říká {expected} B")
        else:
            gate.error("world/map0.meta.json je, ale map0.land chybí")
        if idx_path.exists() and bin_path.exists():
            rows = idx_path.stat().st_size // 12
            if rows != blocks:
                gate.error(f"map0.statics.idx má {rows} bloků, meta.json říká {blocks}")
        else:
            gate.error("world/map0.meta.json je, ale statics .idx/.bin chybí")

    hues_path = root / "assets" / "uo" / "hues.json"
    if hues_path.exists():
        try:
            hues = load_json(hues_path)
        except Exception as exc:
            gate.error(f"hues.json se nedá přečíst ({exc})")
            return checked
        sets = hues.get("sets", [])
        checked += 1
        gate.measure("hues_sad", len(sets))
        if len(sets) != 3000:
            gate.error(f"hues.json má {len(sets)} sad, docs/03 §3.2b říká 3000")
        empty = [s for s in sets if len(s.get("colors", [])) != 32]
        if empty:
            gate.error(f"{len(empty)} sad nemá 32 barev (první: {empty[0].get('set')})")
        named = sum(1 for s in sets if s.get("name"))
        gate.measure("hues_pojmenovanych", named)
        if named == 0:
            gate.error("hues.json nemá ani jednu pojmenovanou sadu")

    if checked:
        gate.note("assety z instalace UO (lokálně vyextrahované) - měřeno, viz measured")
    return checked


def check_anim_manifest(root: Path, gate: Gate) -> int:
    """Manifest animaci (assets/uo/anim-manifest.json) - granule assets.anim.

    Proc prave takhle: rozhodnuti "blok v anim.mul -> anim.mul, jinak
    AnimationFrame*.uop" (docs/03 §3.5.1) je TVRZENI o datech, ktere se da
    overit jen na konkretnich telesech. Kdyz manifest u tela 400 (hrac) rekne
    neco jineho nez anim.mul, je rozhodnuti rozbite - a to je vada, ne detail.
    """
    cesta = root / "assets" / "uo" / "anim-manifest.json"
    if not cesta.exists():
        return 0
    try:
        data = load_json(cesta)
    except Exception as exc:
        gate.error(f"uo/anim-manifest.json se nedá přečíst ({exc})")
        return 1
    tela = data.get("bodies", {})
    zdroje = data.get("sources", {})
    gate.measure("anim_tel", len(tela))
    gate.measure("anim_mul_tel", int(zdroje.get("anim*.mul", {}).get("bodies", 0)))
    gate.measure("anim_uop_tel", int(zdroje.get("AnimationFrame*.uop", {}).get("bodies", 0)))
    if not tela:
        gate.error("anim-manifest.json nemá žádné tělo (prázdný manifest není úspěch)")
        return 1
    if not data.get("sha256"):
        gate.error("anim-manifest.json nemá SHA-256 vstupů (docs/03 §3.5.3 bod 5)")
    for telo, ocekavany in (("400", "anim.mul"), ("401", "anim.mul"), ("334", "AnimationFrame.uop")):
        zaznam = tela.get(telo)
        if zaznam is None:
            gate.error(f"anim-manifest.json nezná tělo {telo} (měření: v datech je)")
            continue
        if zaznam.get("source") != ocekavany:
            gate.error(f"tělo {telo} má zdroj {zaznam.get('source')}, "
                       f"měření (docs/03 §3.5.1) říká {ocekavany}")
        if not zaznam.get("actions"):
            gate.error(f"tělo {telo} nemá v manifestu žádnou akci")
    if data.get("pixels_decoded") is True:
        gate.error("manifest tvrdí pixels_decoded=true, ale dekodér pixelů "
                   "v této instalaci ověřený není (research/anim-mereni.md)")
    gate.note("anim manifest: zdroj u každého těla je měřený, ne odhadnutý")
    return 1


def check(root: Path, gate: Gate) -> None:
    measured_outputs = check_extraction_outputs(root, gate)
    measured_outputs += check_anim_manifest(root, gate)
    manifest = find_manifest(root)
    if manifest is None:
        if measured_outputs:
            # Neco jsme zmerili, takze NEMERENO nema smysl; chybejici manifest
            # je jen poznamka (v CI assety nejsou, docs/08 §8.4).
            gate.note("manifest atlasu není (v CI chybí; kontrola manifestu NEPROBĚHLA)")
        else:
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
