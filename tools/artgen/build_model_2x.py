# -*- coding: utf-8 -*-
"""build_model_2x.py - postavi 2x modely (dyka, postava) do `tools/artgen/blend2x/`.

  & 'C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe' -b -P ^
      tools\\artgen\\build_model_2x.py -- --plan all

CO SE NEMENI: modely samotne. Postava i dyka jsou porad ve SVETOVYCH
JEDNOTKACH (1 jednotka = 1 dlazdice) - kdyby se zvetsily modely, nebyla by to
"2x geometrie", ale "2x velky svet". Meni se jen scena: rozliseni renderu
1024 px, meritko 704 px/jednotka (=> stejny zaber), jedno slunce, AO
a kontaktni rovina (`artgen_blender_2x.py`).

⚠ Blender vraci exit 0 i pri chybe ve skriptu - proto se kontroluje, ze .blend
existuje, a chyba konci nenulovym kodem (`artgen_blender.uloz_blend`).
"""
from __future__ import annotations

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
import artgen_blender_2x as ab2  # noqa: E402
import artgen_common_2x as ac2  # noqa: E402


def _zaklad(cil=(0.0, 0.0, 0.0)) -> None:
    """Scena 2x + kamera + jedno slunce. Rovina se pridava az za modelem.

    ⚠ `cil` NENI detail: 1x stavba postavy miri kamerou na `(0, 0, world_h/2)`
    (`build_model_character.py`), ne na kontaktni bod - protoze postava je
    vysoka a pri zamereni na chodidla by se hlava orezala o horni hranu zaberu.
    Prvni verze 2x vetve miri na (0,0,0) a hlava se SKUTECNE orezala (namEReno:
    obsah renderu zacinal na y=0). Neni to kosmetika - orezany sprite by se
    poznal az na srovnavacim listu.
    """
    ab2.nova_scena_2x()
    cam = ab2.kamera_2x(cil=cil)
    ab2.slunce()
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX_2X {ox:.3f} {oy:.3f} (render {ac2.RENDER})")


def postav_dyku() -> str:
    _zaklad(cil=(0.0, 0.0, 0.0))
    ab.postav_dyku()
    ab2.kontaktni_rovina()
    cesta = os.path.join(ab2.BLEND, "2x_item_dagger.blend")
    ab.uloz_blend(cesta)
    return cesta


def postav_postavu() -> str:
    # stejny cil kamery jako 1x (`CHAR["world_h"] * 0.5`), aby se do zaberu
    # vesla i hlava - viz docstring `_zaklad`
    _zaklad(cil=(0.0, 0.0, ac2.CHAR["world_h"] * 0.5))
    arm, objekty = ab.postav_postavu()
    print(f"BOUND_MESHES {len(objekty)}")
    ab2.kontaktni_rovina()
    # smer 0 = celni (stejna konvence jako 1x i UO) + f0, jako 1x stavba
    ab.nastav_smer(arm, 0)
    ab.apply_walk(arm, 0)
    bpy.context.view_layer.update()
    cesta = os.path.join(ab2.BLEND, "2x_character.blend")
    ab.uloz_blend(cesta)
    return cesta


PLANY = {"dagger": postav_dyku, "character": postav_postavu}


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
    print("BUILD_OK", ",".join(jmena))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
