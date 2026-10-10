# -*- coding: utf-8 -*-
"""build_model_tiles.py - postavi dlazdici terenu (trava / cesta) a ulozi .blend.

  & '...\\blender.exe' -b -P tools\\artgen\\build_model_tiles.py -- --tile grass

Model je ctverka 1x1 jednotky se stredem v pocatku - presne to, co se v ortho
projekci 45/45 promitne jako kosoctverec 44x44 px (tvar UO land artu, mereno).
"""
from __future__ import annotations

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
from artgen_common import LAND  # noqa: E402


def postav(druh: str) -> str:
    ab.nova_scena()
    cam = ab.kamera(cil=(0.0, 0.0, 0.0))
    ab.svetla()
    ab.postav_dlazdici(druh)
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX tile_{druh} {ox:.3f} {oy:.3f}")
    cesta = os.path.join(ab.BLEND, f"tile_{druh}.blend")
    ab.uloz_blend(cesta)
    return cesta


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    druh = "all"
    for i, a in enumerate(argv):
        if a == "--tile" and i + 1 < len(argv):
            druh = argv[i + 1]
    druhy = [t["name"] for t in LAND] if druh == "all" else [druh]
    for d in druhy:
        postav(d)
    print("BUILD_OK", ",".join(druhy))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
