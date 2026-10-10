# -*- coding: utf-8 -*-
"""build_model_character.py - postavi postavu (1.2 jednotky), kostru a ulozi .blend.

  & '...\\blender.exe' -b -P tools\\artgen\\build_model_character.py

Chuze se SEM NEPOCITA - je v `artgen_blender.apply_walk` a pouziva ji az
`render_sprites.py`. Duvod: kdyby si stavba a render pocitaly pozu kazda svou,
renderovalo by se neco jineho, nez je v .blend.
"""
from __future__ import annotations

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
from artgen_common import CHAR  # noqa: E402


def main() -> int:
    ab.nova_scena()
    # cil kamery ve vysce pulky postavy: kontaktni bod (chodidla) zustane
    # v zaberu a soucasne se do 512 px vejde i hlava.
    cam = ab.kamera(cil=(0.0, 0.0, CHAR["world_h"] * 0.5))
    ab.svetla()
    arm, objekty = ab.postav_postavu()
    ab.apply_walk(arm, 0)
    bpy.context.view_layer.update()
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX character {ox:.3f} {oy:.3f}")
    print(f"MESHES {len(objekty)}")
    ab.uloz_blend(os.path.join(ab.BLEND, "character.blend"))
    print("BUILD_OK character")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
