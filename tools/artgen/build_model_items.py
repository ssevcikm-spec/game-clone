# -*- coding: utf-8 -*-
"""build_model_items.py - postavi model PREDMETU z primitiv a ulozi ho jako .blend.

Spousteni (ZADANI-25 §6):
  & 'C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe' -b -P ^
      tools\\artgen\\build_model_items.py -- --item dagger

Co to dela: prazdna scena -> kamera (ortho, 45/45) -> svetla -> model predmetu
-> .blend do `tools/artgen/blend/item_<jmeno>.blend`. RENDER dela az
`render_sprites.py` (ze ulozeneho .blend) - tim je oddeleny "model" od "renderu"
a .blend zustava zdroj (rozhodnuti M6).

⚠ Blender vraci exit 0 i kdyz skript spadne (traceback na stderr) - proto se
kontroluje i to, ze .blend existuje, a chyba konci nenulovym kodem.
"""
from __future__ import annotations

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
from artgen_common import ITEMS  # noqa: E402

STAVITEL = {
    "dagger": ab.postav_dyku,
    "pickaxe": ab.postav_krumpac,
    "ore": ab.postav_rudu,
    "ingot": ab.postav_ingot,
}


def postav(jmeno: str) -> str:
    """Postavi jeden predmet a ulozi .blend. Vraci cestu k .blend."""
    if jmeno not in STAVITEL:
        raise SystemExit(f"neznamy predmet: {jmeno} (je {sorted(STAVITEL)})")
    ab.nova_scena()
    # kamera se diva na POCATEK: kontaktni bod (0,0,0) je stred pudorysu
    # predmetu, takze vsechny smery i framy maji stejnou kotvu.
    cam = ab.kamera(cil=(0.0, 0.0, 0.0))
    ab.svetla()
    STAVITEL[jmeno]()
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX {jmeno} {ox:.3f} {oy:.3f}")
    cesta = os.path.join(ab.BLEND, f"item_{jmeno}.blend")
    ab.uloz_blend(cesta)
    return cesta


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    jmeno = "all"
    for i, a in enumerate(argv):
        if a == "--item" and i + 1 < len(argv):
            jmeno = argv[i + 1]
    jmena = [i["name"] for i in ITEMS] if jmeno == "all" else [jmeno]
    for j in jmena:
        postav(j)
    print("BUILD_OK", ",".join(jmena))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
