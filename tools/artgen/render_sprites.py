# -*- coding: utf-8 -*-
"""render_sprites.py - vyrenderuje sprity z hotovych .blend (s alfou).

  & '...\\blender.exe' -b -P tools\\artgen\\render_sprites.py -- --plan items
  & '...\\blender.exe' -b -P tools\\artgen\\render_sprites.py -- --plan character

Co to dela: otevre .blend (kamera i svetla jsou v nem - postavil je
`build_model_*.py`), nastavi pozu/smer a vyrenderuje PNG do `tools/artgen/raw/`.
Ke kazde davce zapise `raw/_origin_<davka>.json` s tim, KAM se promitl kontaktni
bod (0,0,0) - to je kotva, kterou `pack_atlas.py` potrebuje, aby predmet sedel
na dlazdici. Bez toho by se kotva odhadovala a "sedi to" by nebylo merene.

⚠ Kazdy render se kontroluje (soubor existuje a neni prazdny) - Blender vraci
exit 0 i pri chybe ve skriptu (ZADANI-25 §2).
"""
from __future__ import annotations

import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
from artgen_common import CHAR, ITEMS, LAND, PX_PER_UNIT, RENDER  # noqa: E402


def zapis_origin(davka: str, ox: float, oy: float) -> str:
    cesta = os.path.join(ab.RAW, f"_origin_{davka}.json")
    os.makedirs(ab.RAW, exist_ok=True)
    with open(cesta, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"davka": davka, "origin_x": ox, "origin_y": oy,
                   "render": RENDER, "px_per_unit": PX_PER_UNIT},
                  f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(f"ORIGIN {cesta} {ox:.3f} {oy:.3f}")
    return cesta


def render_items() -> int:
    """Kazdy predmet = jeden snimek (lezi na zemi, zadna animace)."""
    kolik = 0
    for spec in ITEMS:
        jmeno = spec["name"]
        blend = os.path.join(ab.BLEND, f"item_{jmeno}.blend")
        ab.otevri_blend(blend)
        cam = bpy.data.objects["Cam"]
        ox, oy = ab.origin_px(bpy.context.scene, cam)
        zapis_origin(f"item_{jmeno}", ox, oy)
        ab.render_do(os.path.join(ab.RAW, f"item_{jmeno}.png"))
        kolik += 1
    return kolik


def render_tiles() -> int:
    kolik = 0
    for spec in LAND:
        jmeno = spec["name"]
        ab.otevri_blend(os.path.join(ab.BLEND, f"tile_{jmeno}.blend"))
        cam = bpy.data.objects["Cam"]
        ox, oy = ab.origin_px(bpy.context.scene, cam)
        zapis_origin(f"tile_{jmeno}", ox, oy)
        ab.render_do(os.path.join(ab.RAW, f"tile_{jmeno}.png"))
        kolik += 1
    return kolik


def render_character() -> int:
    """5 smeru x 8 framu chuze = 40 spritu."""
    ab.otevri_blend(os.path.join(ab.BLEND, "character.blend"))
    cam = bpy.data.objects["Cam"]
    arm = bpy.data.objects["Rig"]
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    zapis_origin("character", ox, oy)
    kolik = 0
    for d in range(CHAR["dirs"]):
        ab.nastav_smer(arm, d)
        for f in range(CHAR["frames"]):
            ab.apply_walk(arm, f)
            bpy.context.view_layer.update()
            ab.render_do(os.path.join(ab.RAW, f"char_d{d}_f{f}.png"))
            kolik += 1
    return kolik


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    plan = "items"
    for i, a in enumerate(argv):
        if a == "--plan" and i + 1 < len(argv):
            plan = argv[i + 1]
    kolik = {"items": render_items, "tiles": render_tiles,
             "character": render_character}[plan]()
    print(f"RENDER_OK {plan} {kolik}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
