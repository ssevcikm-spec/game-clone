# -*- coding: utf-8 -*-
"""build_model_lit.py - postavi 1x modely se SVETLEM do `tools/artgen/blend/lit_*.blend`.

  & 'C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe' -b -P ^
      tools\\artgen\\build_model_lit.py -- --plan all

CO SE NEMENI: modely. Dlazdice, predmety i postava jsou postavene TYMIZ funkcemi
jako 1x sada (`artgen_blender.postav_*`) - kdyby se model zmenil, nemerilo by
srovnani "1x bez svetla vs 1x se svetlem" svetlo, ale i geometrii. Meni se jen
scena: tri slunce -> jedno smerove + Fast-GI AO + kontaktni rovina
(`artgen_blender_lit.py`).

KAM SE UKLADA: `tools/artgen/blend/lit_<co>.blend` - PREDPONA `lit_` je proto,
aby zalohy `.blend1` chytil existujici `.gitignore` (`blend/*.blend1`), stejne
jako to udelala 2x vetev s predponou `2x_`.

⚠ Dlazdice kontaktni rovinu NEDOSTAVAJI: dlazdice JE podlaha, takze stin pod ni
by byl cely schovany pod ni (v ortografii kryji obe presne stejny kosoctverec).
AO na dlazdici zustava - prave ta dava travnim trsum a kamenum hloubku.

⚠ Blender vraci exit 0 i pri chybe ve skriptu - proto se kontroluje, ze .blend
existuje a neni prazdny (`artgen_blender.uloz_blend`).
"""
from __future__ import annotations

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
import artgen_blender_lit as abl  # noqa: E402
import artgen_common_lit as acl  # noqa: E402

STAVITEL = {
    "dagger": ab.postav_dyku,
    "pickaxe": ab.postav_krumpac,
    "ore": ab.postav_rudu,
    "ingot": ab.postav_ingot,
}


def _cesta(jmeno: str) -> str:
    return os.path.join(str(acl.BLEND), f"{acl.PREFIX_BLEND}{jmeno}.blend")


def postav_dlazdici(druh: str) -> str:
    abl.nova_scena_lit()
    cam = abl.kamera_lit(cil=(0.0, 0.0, 0.0))
    abl.slunce()
    ab.postav_dlazdici(druh)
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX lit_tile_{druh} {ox:.3f} {oy:.3f}")
    cesta = _cesta(f"tile_{druh}")
    ab.uloz_blend(cesta)
    return cesta


def postav_predmet(jmeno: str) -> str:
    if jmeno not in STAVITEL:
        raise SystemExit(f"neznamy predmet: {jmeno} (je {sorted(STAVITEL)})")
    abl.nova_scena_lit()
    # kamera se diva na POCATEK = kontaktni bod (0,0,0) uprostred pudorysu;
    # stejne jako 1x `build_model_items.py` (jinak by kotva nesedla)
    cam = abl.kamera_lit(cil=(0.0, 0.0, 0.0))
    abl.slunce()
    STAVITEL[jmeno]()
    abl.kontaktni_rovina()
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX lit_item_{jmeno} {ox:.3f} {oy:.3f}")
    cesta = _cesta(f"item_{jmeno}")
    ab.uloz_blend(cesta)
    return cesta


def postav_postavu() -> str:
    abl.nova_scena_lit()
    # cil kamery ve vysce pulky postavy - stejne jako 1x; pri zamereni na
    # chodidla by se hlava orezala o horni hranu zaberu (v 2x vetvi se to
    # opravdu stalo a poznalo se to az na listu)
    cam = abl.kamera_lit(cil=(0.0, 0.0, acl.CHAR["world_h"] * 0.5))
    abl.slunce()
    arm, objekty = ab.postav_postavu()
    print(f"BOUND_MESHES {len(objekty)}")
    abl.kontaktni_rovina()
    ab.nastav_smer(arm, 0)
    ab.apply_walk(arm, 0)
    bpy.context.view_layer.update()
    ox, oy = ab.origin_px(bpy.context.scene, cam)
    print(f"ORIGIN_PX lit_character {ox:.3f} {oy:.3f}")
    cesta = _cesta("character")
    ab.uloz_blend(cesta)
    return cesta


PLANY = {"tiles": lambda: [postav_dlazdici(t["name"]) for t in acl.LAND],
         "items": lambda: [postav_predmet(i["name"]) for i in acl.ITEMS],
         "character": lambda: [postav_postavu()]}


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
