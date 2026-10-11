# -*- coding: utf-8 -*-
"""probe_svetlo_var.py - laborator svetla: vyrenderuje 1 scenu s JINYMI svetly.

  & blender.exe -b -P tools\\artgen\\probe_svetlo_var.py -- ^
      --plan dagger --var e12_s112 --out tools\\artgen\\_rawvar\\e12_s112

PROC TENHLE SKRIPT EXISTUJE: nez se pusti cela sada (46 spritů, ~1 min), je
potreba ZMERIT, co ktery zmeneny parametr udela - a to na TOMTEZ modelu se
STEJNOU kamerou a STEJNOU kontaktni rovinou. Skript proto：

  * otevre HOTOVY `blend/lit_*.blend` (model ani kamera se nestavi znovu, takze
    se meri jen svetlo - kdyby se stavělo, merila by se i geometrie);
  * SMIZE vsechna svetla ve scene a postavi svetla podle varianty (pocet slunci,
    energie, smer, uhel, obloha, AO);
  * vyrenderuje stejne pruchody jako `render_lit.py` (beauty / ref / stin);
  * zapise `_origin_<plan>.json` do vystupni slozky (postprocess jinak nema
    kotvu) a `SVETLO_VAR` radek, ktery se da precist a porovnat.

⚠ Vystup jde MIMO `_rawlit/` (do `_rawvar/`), aby se laboratorni snimky nikdy
nezamichaly do hotove sady - `pack_atlas_lit.py` cte jen `_rawlit/`.
⚠ Blender vraci exit 0 i pri chybe ve skriptu; proto se kontroluje existence PNG
(`artgen_blender.render_do`) a na konci se printuje `VAR_OK`.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
import artgen_blender_lit as abl  # noqa: E402
import artgen_common_lit as acl  # noqa: E402

# ---------------------------------------------------------------------------
# varianty svetla (vse, co se da menit; cisla vychazeji z receptu lit sady)
# ---------------------------------------------------------------------------
# `klic`: (energie slunce, elevace smeru [rad] nebo None = prevzit z receptu,
#          uhel slunce [deg], obloha sila, AO dosah)
# Smer slunce se v Blenderu zadava ROTACI, ne "elevaci" - a prevod je past:
# rotace (-0.7, 0, -2.6) znamena slunce naklonene tak, ze svetlo prichazi
# zleva-shora. Aby slo menit "jak nizko je slunce" citelne, prevadi se elevace
# na rotaci takhle: slunce je v rovine XZ a natocene o (90 - elevace) od svislice.
VAR = {
    # referencni (soucasny recept lit sady)
    "lit":      dict(energie=4.0, elev=None, uhel=12.0, obloha=0.45, ao=0.20),
    # jak moc rozhoduje UHEL: nizsi slunce = delsi stin
    "e12":      dict(energie=4.0, elev=12.0, uhel=12.0, obloha=0.45, ao=0.20),
    "e25":      dict(energie=4.0, elev=25.0, uhel=12.0, obloha=0.45, ao=0.20),
    "e35":      dict(energie=4.0, elev=35.0, uhel=12.0, obloha=0.45, ao=0.20),
    "e45":      dict(energie=4.0, elev=45.0, uhel=12.0, obloha=0.45, ao=0.20),
    # jak moc rozhoduje MEKKOST (uhel zdroje): vetsi = rozmazanejsi okraj stinu
    "s25":      dict(energie=4.0, elev=None, uhel=25.0, obloha=0.45, ao=0.20),
    "s40":      dict(energie=4.0, elev=None, uhel=40.0, obloha=0.45, ao=0.20),
    # jak moc rozhoduje VYPLN (navrat kontrastu u kovu)
    "f1":       dict(energie=4.0, elev=None, uhel=12.0, obloha=0.45, ao=0.20,
                     vypln=1.0),
    "f2":       dict(energie=4.0, elev=None, uhel=12.0, obloha=0.45, ao=0.20,
                     vypln=2.0),
    "f15_obl":  dict(energie=4.0, elev=None, uhel=12.0, obloha=0.70, ao=0.20,
                     vypln=1.5),
    # kombinace (kandidat na v3)
    "k_e35_s25": dict(energie=4.0, elev=35.0, uhel=25.0, obloha=0.45, ao=0.20),
    "k_e35_f2":  dict(energie=4.0, elev=35.0, uhel=25.0, obloha=0.45, ao=0.20,
                      vypln=2.0),
}


def _rot_slunce(elev_deg: float, az_rad: float = -0.7) -> tuple[float, float, float]:
    """Rotace smeroveho slunce pro zadanou ELEVACI (0 = u obzoru, 90 = nad hlavou).

    Blender: rotace (0,0,0) sviti SHORA dolu (-Z). Nakloneni o uhel t kolem osy Y
    nakloni smer svetla do roviny XZ; zbytek je azimut (kolem Z).
    """
    t = math.radians(90.0 - elev_deg)
    return (t, 0.0, az_rad)


def smaz_svetla() -> int:
    kolik = 0
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
            kolik += 1
    return kolik


def postav_svetla(v: dict, zaklad: tuple[float, float, float]) -> list[dict]:
    """Postavi slunce podle varianty; vrati popis (pro tisk a mereni)."""
    popis = []
    rot = _rot_slunce(v["elev"]) if v.get("elev") is not None else zaklad
    if v.get("elev") is not None:
        rot = (rot[0], rot[1], zaklad[2])
    bpy.ops.object.light_add(type="SUN", rotation=rot)
    s = bpy.context.object
    s.name = "Sun"
    s.data.energy = v["energie"]
    s.data.color = (1.0, 1.0, 1.0)
    s.data.angle = math.radians(v["uhel"])
    s.data.use_shadow = True
    popis.append({"jmeno": "Sun", "energie": v["energie"], "rot": list(rot),
                  "uhel_deg": v["uhel"], "elev_deg": v.get("elev")})
    if v.get("vypln"):
        # VYPLN: druhe slunce z PROTISMERU (nizsi energie) - vraci odlesky a
        # obrysovy lem, ktery jedno slunce vzalo (MERENI.md §9.3 bod 1).
        rot_f = (zaklad[0], 0.0, zaklad[2] + math.pi)
        bpy.ops.object.light_add(type="SUN", rotation=rot_f)
        f = bpy.context.object
        f.name = "Fill"
        f.data.energy = v["vypln"]
        f.data.color = (1.0, 1.0, 1.0)
        f.data.angle = math.radians(v["uhel"])
        f.data.use_shadow = False        # vypln nema kreslit druhy stin
        popis.append({"jmeno": "Fill", "energie": v["vypln"], "rot": list(rot_f),
                      "uhel_deg": v["uhel"], "stin": False})
    return popis


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", default="dagger", choices=("dagger", "pickaxe", "ore",
                                                         "ingot", "char0"))
    ap.add_argument("--var", default="lit", choices=sorted(VAR))
    ap.add_argument("--out", default="")
    a, _z = ap.parse_known_args(argv)
    v = VAR[a.var]
    # ⚠ VYSTUP JE PO PLANECH: `_rawvar/<varianta>/<plan>/`. Kdyby byl jen po
    # variantach, vyrenderovani druheho modelu by PREPSALO snimky prvniho a
    # mereni by pak cetlo jiny model, nez si mysli (a vyslo by to jako rozdil
    # "svetla"). Stalo se to pri prvnim behu - odtud to pravidlo.
    out = a.out or os.path.join(str(acl.RAW).replace("_rawlit", "_rawvar"),
                                a.var, a.plan)
    os.makedirs(out, exist_ok=True)

    if a.plan == "char0":
        blend = os.path.join(str(acl.BLEND), f"{acl.PREFIX_BLEND}character.blend")
    else:
        blend = os.path.join(str(acl.BLEND), f"{acl.PREFIX_BLEND}item_{a.plan}.blend")
    ab.otevri_blend(blend)
    kam = bpy.data.objects["Cam"]
    zaklad = tuple(bpy.data.objects[acl.JMENO_SLUNCE].rotation_euler)
    kolik_svetel = smaz_svetla()
    popis = postav_svetla(v, zaklad)

    scene = bpy.context.scene
    scene.eevee.fast_gi_distance = v["ao"]
    pozadi = scene.world.node_tree.nodes["Background"]
    pozadi.inputs[1].default_value = v["obloha"]

    # kotva: stejna funkce jako v render_lit.py
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    sou = world_to_camera_view(scene, kam, Vector((0.0, 0.0, 0.0)))
    ox = sou.x * scene.render.resolution_x
    oy = (1.0 - sou.y) * scene.render.resolution_y
    with open(os.path.join(out, f"_origin_{a.plan}.json"), "w",
              encoding="utf-8", newline="\n") as f:
        json.dump({"davka": a.plan, "origin_x": ox, "origin_y": oy,
                   "render": acl.RENDER, "px_per_unit": acl.PX_PER_UNIT,
                   "meritko": acl.MERITKO, "varianta": a.var}, f,
                  ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")

    # beauty (rovina skryta)
    if abl.ma_rovinu():
        abl.prepni_rovinu(False)
    ab.render_do(os.path.join(out, f"item_{a.plan}.png"))
    ab.render_do(os.path.join(out, f"char_d0_f0.png"))
    # ref (rovina bez objektu)
    abl.prepni_rovinu(True)
    stav = abl.skry_meshe(krome=acl.JMENO_PODLAHY)
    try:
        ab.render_do(os.path.join(out, f"_ref_item_{a.plan}.png"))
        ab.render_do(os.path.join(out, "_ref_character.png"))
    finally:
        abl.vrat_meshe(stav)
    # stin (rovina + objekt)
    ab.render_do(os.path.join(out, f"_stin_item_{a.plan}.png"))
    ab.render_do(os.path.join(out, "_stin_char_d0_f0.png"))

    print(f"SVETLO_VAR {a.var} smazano_svetel={kolik_svetel} zaklad_rot="
          f"{tuple(round(x, 3) for x in zaklad)} popis={json.dumps(popis)}")
    print(f"VAR_OK {a.var} {a.plan} -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
