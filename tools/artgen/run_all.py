# -*- coding: utf-8 -*-
"""run_all.py - cely pilot jednim prikazem, s MERENIM CASU jednotlivych fazi.

  python tools/artgen/run_all.py            # vse: modely -> render -> atlas -> listy -> brana
  python tools/artgen/run_all.py --jen atlas   # jen postprocess + zabaleni + brana
  python tools/artgen/run_all.py --preskoc-render  # pouzije hotove raw snimky

PROC ORCHESTRATOR: ZADANI-25 pozaduje, aby slo skripty "pustit znovu" a aby
v `MERENI.md` byla cisla s postupem. Tenhle soubor je ten postup: kazdou fazi
spusti, ZMERI ji (sekundy) a zapise do `tools/artgen/_casy.json`. Rucne
opsane casy by se nedaly overit.

Faze (presne tak se deli cas v MERENI.md):
  model     - build_model_*.py (Blender: postavi model, kameru, svetla, ulozi .blend)
  render    - render_sprites.py (Blender: vyrenderuje sprity s alfou)
  postprocess+atlas - pack_atlas.py (Pillow: odstraneni pozadi, diry, Lanczos,
                      sazeni do stranek, manifest, anim listy)
  brana     - pack_atlas.py --check (470 kontrol)
  kontrola pohledem - contact_sheet.py (vyroba listu; LIDSKY cas je jinde)

⚠ Blender vraci exit 0 i kdyz skript spadne (ZADANI-25 §2) - proto se u kazde
faze kontroluje i vystup (pocet RENDERED/BUILD_OK) a chyba konci nenulovym
kodem. Ticho neni uspech.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
sys.path.insert(0, str(HERE))
import artgen_common as ac  # noqa: E402


def spust(jmeno: str, cmd: list[str], ocekavane: list[str] = ()) -> dict:
    """Spusti fazi, zmeri cas a zkontroluje, ze vystup obsahuje, co ma."""
    t0 = time.perf_counter()
    p = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    trvani = time.perf_counter() - t0
    vystup = (p.stdout or "") + (p.stderr or "")
    chyby = [v for v in ocekavane if v not in vystup]
    ok = p.returncode == 0 and not chyby
    print(f"[run_all] {jmeno:22s} {trvani:7.1f} s  {'OK' if ok else 'CHYBA'}"
          + (f"  (chybi ve vystupu: {chyby})" if chyby else ""))
    if not ok:
        print(f"[run_all] --- vystup {jmeno} (poslednich 30 radku) ---")
        for radek in vystup.splitlines()[-30:]:
            print("   " + radek)
    return {"faze": jmeno, "sekund": round(trvani, 1), "ok": ok,
            "navratovy_kod": p.returncode}


def bl(jmeno: str, skript: str, args: list[str], ocekavane: list[str]) -> dict:
    return spust(jmeno, [BLENDER, "-b", "-P", str(HERE / skript), "--", *args], ocekavane)


def main() -> int:
    ap = argparse.ArgumentParser(description="cely pilot vlastniho artu")
    ap.add_argument("--jen", default="", help="atlas = jen postprocess+zabaleni+brana")
    ap.add_argument("--preskoc-render", action="store_true")
    ap.add_argument("--preskoc-model", action="store_true")
    ap.add_argument("--bez-listu", action="store_true")
    a = ap.parse_args()
    jen_atlas = a.jen == "atlas"
    mereni: list[dict] = []
    if not jen_atlas:
        mereni.append(spust("probe projekce",
                            [BLENDER, "-b", "-P", str(HERE / "probe_projection.py")],
                            ["PROBE_OK"]))
        if not a.preskoc_model:
            mereni.append(bl("model: predmety", "build_model_items.py", ["--item", "all"],
                             ["BUILD_OK"]))
            mereni.append(bl("model: dlazdice", "build_model_tiles.py", ["--tile", "all"],
                             ["BUILD_OK"]))
            mereni.append(bl("model: postava", "build_model_character.py", [],
                             ["BUILD_OK", "BOUND_MESHES"]))
        if not a.preskoc_render:
            mereni.append(bl("render: predmety", "render_sprites.py", ["--plan", "items"],
                             [f"RENDER_OK items {len(ac.ITEMS)}"]))
            mereni.append(bl("render: dlazdice", "render_sprites.py", ["--plan", "tiles"],
                             [f"RENDER_OK tiles {len(ac.LAND)}"]))
            mereni.append(bl("render: postava", "render_sprites.py", ["--plan", "character"],
                             [f"RENDER_OK character {ac.CHAR['dirs'] * ac.CHAR['frames']}"]))
    mereni.append(spust("postprocess + atlas", [sys.executable, str(HERE / "pack_atlas.py")],
                        [f"{len(ac.LAND) + len(ac.ITEMS) + ac.CHAR['dirs'] * ac.CHAR['frames']}",
                         "[check]"]))
    if not a.bez_listu:
        mereni.append(spust("kontrolni list", [sys.executable, str(HERE / "contact_sheet.py"),
                                               "--out", "tools/artgen/_kontaktni-list.png"],
                            ["[contact_sheet]"]))
        mereni.append(spust("vzorky UO", [sys.executable, str(HERE / "vzorky_uo.py")],
                            ["[vzorky_uo]"]))
    (HERE / "_casy.json").write_text(
        json.dumps(mereni, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8", newline="\n")
    spatne = [m for m in mereni if not m["ok"]]
    celkem = sum(m["sekund"] for m in mereni)
    print(f"[run_all] fazi {len(mereni)}, chyb {len(spatne)}, celkem {celkem:.1f} s "
          f"({celkem / 60:.1f} min) -> tools/artgen/_casy.json")
    return 1 if spatne else 0


if __name__ == "__main__":
    raise SystemExit(main())
