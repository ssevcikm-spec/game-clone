#!/usr/bin/env python3
"""G16 check-style - vlastni art je PIXEL ART, ne rozmazany render (docs/08 §8.2).

PROC: uzivatel videl vlastni art ve hre jako "rozmazany, chybi mu detaily".
Mereno 2026-10-11 na vlastni postave: **473 ruznych barev v 556 pixelech a 197
polopruhlednych pixelu** (UO sprity: 61 barev, 0 polopruhlednych). Styl se proto
dela v `tools/artgen/styl.py` (tvrdá alfa na siluete + paleta) a tahle brana
meri, ze se to OPRAVDU stalo - na SPRITECH, ne v reportu.

Kontroluje se:
  K1 report manifestu tvrdi zapnuty styl (prah tvrde alfy) - bez toho by se
     styl mohl tise preskocit a vsechno ostatni by bylo zelene,
  K2 zadny sprite nema na SILUETE polopruhledny pixel (kontaktni stin se
     neposuzuje - jeho mekkost je zamer; pozna se podle barvy stinu),
  K3 pocet barev v tele je pod stropem (pixel art ma malou paletu).

⚠ CO BRANA ZAMERNE NEMERI: **ostrost hrany**. Zkusila to (hranice 28 mezi
namerenymi 26,3 pred a 31,5 po stylu) a ukazalo se, ze u rudy hlasi vadu
o SPRAVNEM obrazku: ruda ma po stylu 19,4 (pred 14,5) a je CITELNEJSI - je to
hladky kamen s malou paletou, gradient jasu u nej nema co merit. Ostrost se
proto jen HLASI (`nejmensi_ostrost`, `nejvetsi_ostrost`), nehlida se.
Metrika, ktera tresta zadouci vlastnost, neni brana (skill `game-assets`).

V CI nejsou `assets/uo/` (gitignore), ale VLASTNI sada je v gitu, takze tahle
brana meri i v CI - jako G6.

Spousteni:
  python tools/gates/check-style.py [--root .] [--json cesta]
  python tools/gates/check-style.py --self-test
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, load_json, selftest_cli  # noqa: E402

NAME = "check-style"
CONFIG = "assets/own-art.json"
# Prahy jsou NAMERENE (2026-10-11), ne opsane z pocitu:
#   pred stylem: postava 472 barev / 148 polopruhlednych / ostrost 26,3
#   po stylu:    postava  39 barev /   0 polopruhlednych / ostrost 31,5
# Strop barev je 2x vic, nez kolik ma nejhorsi sprite po stylu (39) - aby brana
# nepadala na kosmetice, ale poznala NAVRAT ROZMAZANI (472 barev).
MAX_BAREV = 80
# ⚠ Ostrost tu ZAMERNE neni jako prah - viz docstring (u rudy hlasi vadu
# o spravnem obrazku). Cislo se jen hlasi.


def barva_stinu(root: Path) -> tuple[int, int, int]:
    """Barva kontaktniho stinu z receptu (ne opsana) - aby se stin neposuzoval."""
    for soubor in ("artgen_common_2x.py", "artgen_common_lit.py"):
        cesta = root / "tools" / "artgen" / soubor
        if not cesta.exists():
            continue
        for radek in cesta.read_text(encoding="utf-8").splitlines():
            if radek.strip().startswith("STIN_BARVA"):
                cast = radek.split("=", 1)[1].split("#")[0].strip().strip("()")
                return tuple(int(x) for x in cast.split(","))
    return (0, 0, 0)


def vlastni_sady(root: Path) -> list[tuple[Path, set[tuple[str, int]]]]:
    """(manifest, ktere (kind, id) z nej hra opravdu bere) z konfigurace.

    ⚠ MERI SE JEN TO, CO HRA POUZIVA: `assets/own/` ma i teren a animace, ale
    hra z te sady bere jen PREDMETY (dyku a ingot) - zbytek prebiji vrstvy
    z `assets/own-lit/`. Kdyby brana merila vsechno, hlasila by vadu o spritu,
    ktery se nikdy nekresli (a stylovani nepouzivaneho obrazku by byla prace
    navic, ktera nic nezlepsi).
    """
    cesta = root / CONFIG
    if not cesta.exists():
        return []
    try:
        cfg = load_json(cesta)
    except Exception:
        return []
    out: list[tuple[Path, set[tuple[str, int]]]] = []
    for vrstva in cfg.get("layers", []):
        rel = str(vrstva.get("manifest", "")).replace("res://", "")
        if rel == "":
            continue
        vyber: set[tuple[str, int]] = set()
        for kind, ids in (vrstva.get("sprites") or {}).items():
            for ident in ids:
                vyber.add((str(kind), int(ident)))
        out.append((root / rel, vyber))
    return out


def mer_sprite(cesta: Path, x: int, y: int, w: int, h: int,
               stin: tuple[int, int, int]) -> dict:
    import numpy as np
    from PIL import Image

    with Image.open(cesta) as img:
        a = np.asarray(img.convert("RGBA").crop((x, y, x + w, y + h))).astype(float)
    al, rgb = a[:, :, 3], a[:, :, :3]
    je_stin = (np.abs(rgb - np.array(stin)).max(axis=2) < 2)
    videt = al > 200
    if not videt.any():
        return {"prazdny": True}
    px = rgb[videt]
    g = np.gradient(rgb.mean(axis=2))
    return {"prazdny": False,
            "barvy": int(len(np.unique(px.astype(int).reshape(-1, 3), axis=0))),
            "polopruh": int(((al > 10) & (al < 245) & ~je_stin).sum()),
            "ostrost": float(np.hypot(g[0], g[1])[videt].mean()),
            "px": int(videt.sum())}


def check(root: Path, gate: Gate) -> None:
    manifesty = vlastni_sady(root)
    if not manifesty:
        gate.pending(f"chybi {CONFIG} nebo v nem nejsou vrstvy - neni co merit")
        return
    try:
        import numpy as np  # noqa: F401
        from PIL import Image  # noqa: F401
    except Exception as exc:
        gate.skip(f"Pillow/numpy nejsou k dispozici ({exc}) - NEMERENO")
        return
    stin = barva_stinu(root)
    gate.measure("barva_stinu", list(stin))
    spritu = 0
    vad = 0
    nejvic_barev = 0
    nejmensi_ostrost = 1e9
    nejvetsi_ostrost = 0.0

    # ANIMACE jdou MIMO atlas (`assets/own-lit/anim/anim-sheets.json` + PNG), takze
    # by je mereni spritu z manifestu minulo - a postava je nejviditelnejsi kus
    # sady. Meri se proto i PNG z anim listu vrstvy, ktera ho ma.
    for vrstva in (load_json(root / CONFIG).get("layers", []) if (root / CONFIG).exists() else []):
        anim = str(vrstva.get("anim") or "").replace("res://", "")
        if anim == "":
            continue
        list_cesta = root / anim
        if not list_cesta.exists():
            gate.error(f"anim list {anim} neexistuje - postava by se NEMERILA")
            continue
        sheets = load_json(list_cesta).get("sprites", {})
        for klic, zaznam in sheets.items():
            png = list_cesta.parent / str(zaznam.get("file", ""))
            if not png.exists():
                gate.error(f"{anim}: chybi PNG {zaznam.get('file')}")
                continue
            okno = zaznam.get("frames", [{}])[0].get("rect")
            if not isinstance(okno, (list, tuple)) or len(okno) != 4:
                okno = None
            with Image.open(png) as img:
                im = img.convert("RGBA")
                if okno is not None:
                    im = im.crop((int(okno[0]), int(okno[1]),
                                  int(okno[0]) + int(okno[2]), int(okno[1]) + int(okno[3])))
                a = np.asarray(im).astype(float)
            al, rgb = a[:, :, 3], a[:, :, :3]
            je_stin = (np.abs(rgb - np.array(stin)).max(axis=2) < 2)
            videt = al > 200
            spritu += 1
            if not videt.any():
                gate.error(f"{anim}: {klic} je prazdny frame")
                continue
            px = rgb[videt]
            barvy = int(len(np.unique(px.astype(int).reshape(-1, 3), axis=0)))
            polopruh = int(((al > 10) & (al < 245) & ~je_stin).sum())
            nejvic_barev = max(nejvic_barev, barvy)
            if polopruh > 0:
                vad += 1
                gate.error(f"{anim}: {klic} ma {polopruh} polopruhlednych pixelu "
                           "na siluete (pixel art = 0/255)")
            if barvy > MAX_BAREV:
                vad += 1
                gate.error(f"{anim}: {klic} ma {barvy} barev (strop {MAX_BAREV})")

    for man, vyber in manifesty:
        if not man.exists():
            gate.error(f"manifest {man.relative_to(root).as_posix()} neexistuje")
            continue
        data = load_json(man)
        rep = data.get("report", {})
        # K1: report musi tvrdit zapnuty styl
        prah = int(rep.get("styl_tvrda_alfa_prah", 0)) if isinstance(rep, dict) else 0
        if prah <= 0:
            gate.error(f"{man.name}: report netvrdi tvrdou alfu (`styl_tvrda_alfa_prah`) "
                       "- styl se bud nezapnul, nebo se nemeri")
        for s in data.get("sprites", []):
            kind = str(s.get("kind", ""))
            ident = int(s.get("id", -1))
            if (kind, ident) not in vyber:
                continue          # tenhle kus hra z teto sady nebere
            if kind not in ("item", "anim"):
                continue          # dlazdice ma presnou masku kosoctverce (meri G6)
            cesta = man.parent / str(s.get("page", ""))
            if not cesta.exists():
                gate.error(f"{man.name}: chybi stranka {s.get('page')}")
                continue
            m = mer_sprite(cesta, int(s.get("x", 0)), int(s.get("y", 0)),
                           int(s.get("w", 0)), int(s.get("h", 0)), stin)
            spritu += 1
            if m.get("prazdny"):
                gate.error(f"{man.name}: {kind} {s.get('id')} je prazdny sprite")
                continue
            nejvic_barev = max(nejvic_barev, m["barvy"])
            nejmensi_ostrost = min(nejmensi_ostrost, m["ostrost"])
            nejvetsi_ostrost = max(nejvetsi_ostrost, m["ostrost"])
            if m["polopruh"] > 0:
                vad += 1
                gate.error(f"{man.name}: {kind} {s.get('id')} ma {m['polopruh']} "
                           "polopruhlednych pixelu na siluete (pixel art = 0/255)")
            if m["barvy"] > MAX_BAREV:
                vad += 1
                gate.error(f"{man.name}: {kind} {s.get('id')} ma {m['barvy']} barev "
                           f"(strop {MAX_BAREV}) - to je rozmazany render, ne pixel art")
    gate.measure("spritu_mereno", spritu)
    gate.measure("spritu_s_vadou", vad)
    gate.measure("nejvic_barev", nejvic_barev)
    gate.measure("nejmensi_ostrost", round(nejmensi_ostrost, 2) if spritu else None)
    gate.measure("nejvetsi_ostrost", round(nejvetsi_ostrost, 2) if spritu else None)
    if spritu == 0:
        gate.error("nezmeril se ani jeden sprite (nula neni uspech)")
        return
    # ⚠ OSTROST SE NEMERI JAKO BRANA, jen se hlasi. NamEReno 2026-10-11: ruda ma
    # po stylu ostrost 19,4 (pred 14,5), ale je CITELNEJSI - je to hladky kámen
    # s malou paletou a gradient jasu u nej nema co merit. Kdyby na tom brana
    # stala, hlasila by vadu o SPRAVNEM obrazku (skill `game-assets`: metrika,
    # ktera tresta zadouci vlastnost, je past, ne metrika).
    gate.note(f"ostrost hrany (jen informativne): nejmensi {nejmensi_ostrost:.2f}, "
              f"nejvetsi {nejvetsi_ostrost:.2f}; pred stylem 26,3 / po 31,5 u postavy")
    gate.note("styl: silueta 0/255 (stin se nepocita) a paleta pod stropem, merene na SPRITECH")


def selftest() -> int:
    import shutil
    import numpy as np
    from PIL import Image

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-style"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, barvy: int = 8, polopruhle: bool = False,
                prah_v_reportu: int = 128) -> Path:
        root = base / label
        (root / "assets" / "own-lit" / "atlas").mkdir(parents=True, exist_ok=True)
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        # Pixel-artovy vzorek: TRI barvy ve blocich (vysoky kontrast a mala
        # paleta) - kdyby tu byl gradient, fixture by meritelne nebyla pixel art
        # a "znamy spravny pripad" by spravne spadl.
        for x in range(2, 14):
            for y in range(2, 14):
                barva = (220, 60, 40, 255) if x < 6 else (
                    (240, 220, 90, 255) if y < 8 else (40, 70, 200, 255))
                img.putpixel((x, y), barva)
        if polopruhle:
            for y in range(2, 14):
                img.putpixel((1, y), (200, 200, 200, 120))   # mekky lem
        img.save(root / "assets" / "own-lit" / "atlas" / "item_0.png")
        (root / "assets" / "own-lit" / "manifest.json").write_text(json.dumps({
            "report": {"styl_tvrda_alfa_prah": prah_v_reportu},
            "sprites": [{"kind": "item", "id": 1, "page": "atlas/item_0.png",
                         "x": 0, "y": 0, "w": 16, "h": 16}],
        }, ensure_ascii=False), encoding="utf-8")
        (root / CONFIG).write_text(json.dumps({"version": 1, "layers": [
            {"name": "x", "manifest": "res://assets/own-lit/manifest.json",
             "sprites": {"item": [1]}}]}, ensure_ascii=False), encoding="utf-8")
        return root

    cases = [
        ("dobry", fixture("dobry"), OK),
        ("mekka_alfa", fixture("mekka_alfa", polopruhle=True), VADA),
        ("styl_vypnuty", fixture("styl_vypnuty", prah_v_reportu=0), VADA),
        ("bez_konfigurace", fixture("bez_konfigurace"), NEMERENO),
    ]
    (base / "bez_konfigurace" / CONFIG).unlink()
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G16 kontrola pixel-art stylu vlastni sady")
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
