# -*- coding: utf-8 -*-
"""build_model_v3.py - postavi sceny v3 do `tools/artgen/blend/v3_*.blend`.

  & 'C:\\...\\blender.exe' -b -P tools\\artgen\\build_model_v3.py -- --plan all

CO SE NEMENI: modely ani kamera. Bere se HOTOVY `.blend` z vetve v2
(`lit_*.blend`) a smazou se z nej svetla; pak se postavi svetla v3 (zakladni
slunce + vypln). Duvod je zmereny: kdyby se modely stavely znovu, merila by se
i geometrie, a ta se menit NEMA (`docs/01` §1.2.1 - UO je vzor pocttem).

⚠ Kdyz `.blend` v2 chybi, SKONCI SE - neda se "nejak" pokracovat: v3 bez v2
zakladu by mela jinou kameru i kontaktni rovinu a srovnani by nesrovnavalo.
"""
from __future__ import annotations

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab            # noqa: E402
import artgen_blender_v3 as ab3        # noqa: E402
import artgen_common_lit as acl        # noqa: E402
import artgen_common_v3 as acv         # noqa: E402


def _zdroj(jmeno: str) -> str:
    return os.path.join(str(acv.BLEND), f"{acl.PREFIX_BLEND}{jmeno}.blend")


def _cil(jmeno: str) -> str:
    return os.path.join(str(acv.BLEND), f"{acv.PREFIX_BLEND}{jmeno}.blend")


def _smaz_svetla() -> int:
    kolik = 0
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
            kolik += 1
    return kolik


def prevezmi(jmeno: str) -> str:
    """Otevre v2 blend, vymeni svetla za v3 a ulozi jako v3 blend."""
    zdroj = _zdroj(jmeno)
    if not os.path.exists(zdroj):
        raise SystemExit(f"chybi zaklad z v2: {zdroj} - spust nejdriv "
                         "`build_model_lit.py --plan all`")
    ab.otevri_blend(zdroj)
    smazano = _smaz_svetla()
    ab3.slunce()
    kam = bpy.data.objects["Cam"]
    ox, oy = ab.origin_px(bpy.context.scene, kam)
    print(f"ORIGIN_PX {acv.PREFIX_BLEND}{jmeno} {ox:.3f} {oy:.3f} "
          f"(smazano svetel: {smazano})")
    cesta = _cil(jmeno)
    ab.uloz_blend(cesta)
    return cesta


PLANY = {
    "tiles": lambda: [prevezmi(f"tile_{t['name']}") for t in acv.LAND],
    "items": lambda: [prevezmi(f"item_{i['name']}") for i in acv.ITEMS],
    "character": lambda: [prevezmi("character")],
}


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    plan = "all"
    for i, a in enumerate(argv):
        if a == "--plan" and i + 1 < len(argv):
            plan = argv[i + 1]
    jmena = sorted(PLANY) if plan == "all" else [plan]
    for j in jmena:
        if j not in PLANY:
            raise SystemExit(f"neznamy plan: {j} (je {sorted(PLANY)})")
        PLANY[j]()
    print("BUILD_OK_V3", ",".join(jmena))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
