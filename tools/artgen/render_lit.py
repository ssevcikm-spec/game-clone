# -*- coding: utf-8 -*-
"""render_lit.py - vyrenderuje 1x sprity SE SVETLEM (kreativni pruchod + stin).

  & '...\\blender.exe' -b -P tools\\artgen\\render_lit.py -- --plan tiles
  & '...\\blender.exe' -b -P tools\\artgen\\render_lit.py -- --plan items
  & '...\\blender.exe' -b -P tools\\artgen\\render_lit.py -- --plan character

PRUCHODY (stejne tri jako v 2x vetvi, jen v 1x rozliseni):
  * `beauty` - objekt s alfou, kontaktni rovina SKRYTA. To je sprite.
  * `ref`    - kontaktni rovina VIDET, objekt SKRYTY. Rovina je osvetlena
               rovnomeme, takze je to referencni jas pro pomer zastineni.
               Renderuje se JEDNOU na davku (rovina se mezi framy nemeni).
  * `stin`   - kontaktni rovina VIDET + objekt. V miste stinu je tmavsi.

Dlazdice maji JEN `beauty`: dlazdice je podlaha, takze stin pod ni je cely
schovany pod ni (v ortografii kryji oba presne stejny kosoctverec) - renderovat
ho by znamenalo merit cas neceho, co neni videt. AO na dlazdici zustava.

Vystup: `tools/artgen/_rawlit/` (+ `_origin_<davka>.json` s tim, KAM se promitl
kontaktni bod - to je kotva pro `postprocess_lit.py`). Kazdy render se
kontroluje (soubor existuje a neni prazdny): Blender vraci exit 0 i pri chybe.

⚠ `film_transparent=True` plati i tady, takze sprite ma alfou danou renderem;
stin se ale NEBERE z alfy (EEVEE nema shadow catcher), nybrz z pomeru
`stin/ref` - proto ten druhy a treti pruchod.
"""
from __future__ import annotations

import json
import os
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
import artgen_blender_lit as abl  # noqa: E402
import artgen_common_lit as acl  # noqa: E402

RAW = str(acl.RAW)


def zapis_origin(davka: str, kam, kde: str = None) -> str:
    ox, oy = ab.origin_px(bpy.context.scene, kam)
    kde = RAW if kde is None else kde
    os.makedirs(kde, exist_ok=True)
    cesta = os.path.join(kde, f"_origin_{davka}.json")
    with open(cesta, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"davka": davka, "origin_x": ox, "origin_y": oy,
                   "render": acl.RENDER, "px_per_unit": acl.PX_PER_UNIT,
                   "meritko": acl.MERITKO},
                  f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(f"ORIGIN {cesta} {ox:.3f} {oy:.3f}")
    return cesta


def _cas(pass_: str, t0: float) -> None:
    print(f"CAS pass={pass_} sekund={time.perf_counter() - t0:.2f}")


def render_beauty(cesta: str) -> None:
    """Kreativni pruchod: kontaktni rovina (kdyz v scene je) se SKRYVA."""
    if abl.ma_rovinu():
        abl.prepni_rovinu(False)
    t0 = time.perf_counter()
    ab.render_do(cesta)
    _cas("beauty", t0)


def render_ref(cesta: str) -> None:
    """Rovina bez objektu = referencni jas pro faktor zastineni."""
    if os.path.exists(cesta):
        print(f"REF_SKIP {cesta} (uz existuje a rovina se mezi framy nemeni)")
        return
    abl.prepni_rovinu(True)
    stav = abl.skry_meshe(krome=acl.JMENO_PODLAHY)
    try:
        t0 = time.perf_counter()
        ab.render_do(cesta)
        _cas("ref", t0)
    finally:
        abl.vrat_meshe(stav)


def render_stin(cesta: str) -> None:
    abl.prepni_rovinu(True)
    t0 = time.perf_counter()
    ab.render_do(cesta)
    _cas("stin", t0)


def plan_tiles() -> int:
    kolik = 0
    for spec in acl.LAND:
        jmeno = spec["name"]
        ab.otevri_blend(os.path.join(str(acl.BLEND),
                                     f"{acl.PREFIX_BLEND}tile_{jmeno}.blend"))
        kam = bpy.data.objects["Cam"]
        zapis_origin(f"tile_{jmeno}", kam)
        render_beauty(os.path.join(RAW, f"tile_{jmeno}.png"))
        kolik += 1
    return kolik


def plan_items() -> int:
    kolik = 0
    for spec in acl.ITEMS:
        jmeno = spec["name"]
        ab.otevri_blend(os.path.join(str(acl.BLEND),
                                     f"{acl.PREFIX_BLEND}item_{jmeno}.blend"))
        kam = bpy.data.objects["Cam"]
        zapis_origin(f"item_{jmeno}", kam)
        render_beauty(os.path.join(RAW, f"item_{jmeno}.png"))
        render_ref(os.path.join(RAW, f"_ref_item_{jmeno}.png"))
        render_stin(os.path.join(RAW, f"_stin_item_{jmeno}.png"))
        kolik += 1
    return kolik


def plan_character() -> int:
    ab.otevri_blend(os.path.join(str(acl.BLEND),
                                 f"{acl.PREFIX_BLEND}character.blend"))
    kam = bpy.data.objects["Cam"]
    arm = bpy.data.objects["Rig"]
    zapis_origin("character", kam)
    render_ref(os.path.join(RAW, "_ref_character.png"))
    kolik = 0
    for d in range(acl.CHAR["dirs"]):
        ab.nastav_smer(arm, d)
        for f in range(acl.CHAR["frames"]):
            ab.apply_walk(arm, f)
            bpy.context.view_layer.update()
            render_beauty(os.path.join(RAW, f"char_d{d}_f{f}.png"))
            render_stin(os.path.join(RAW, f"_stin_char_d{d}_f{f}.png"))
            kolik += 1
    return kolik


PLANY = {"tiles": plan_tiles, "items": plan_items, "character": plan_character}


# ---------------------------------------------------------------------------
# merici vetve (stejny rozsah prace jako `render_2x.py --meritko 1x`)
# ---------------------------------------------------------------------------
# PROC: "kolik stoji svetlo" se neda spocitat z behu nad jinym poctem spritu.
# `mereni_svetlo.py` proto meri OBE vetve na TOMTEZ: dyka = 1 sprite, postava =
# 8 framu smeru 0. Vystup jde do `_rawlit/_timing-lit/`, aby se nepletl s raw
# snimky cele sady.
TIMING = os.path.join(RAW, "_timing-lit")


def plan_dagger() -> int:
    ab.otevri_blend(os.path.join(str(acl.BLEND),
                                 f"{acl.PREFIX_BLEND}item_dagger.blend"))
    kam = bpy.data.objects["Cam"]
    os.makedirs(TIMING, exist_ok=True)
    zapis_origin("item_dagger", kam, kde=TIMING)
    render_beauty(os.path.join(TIMING, "item_dagger.png"))
    render_ref(os.path.join(TIMING, "_ref_item_dagger.png"))
    render_stin(os.path.join(TIMING, "_stin_item_dagger.png"))
    return 1


def plan_character0() -> int:
    """JEN smer 0, vsech 8 framu - stejny rozsah jako 2x merici vetev."""
    ab.otevri_blend(os.path.join(str(acl.BLEND), f"{acl.PREFIX_BLEND}character.blend"))
    kam = bpy.data.objects["Cam"]
    arm = bpy.data.objects["Rig"]
    os.makedirs(TIMING, exist_ok=True)
    zapis_origin("character", kam, kde=TIMING)
    render_ref(os.path.join(TIMING, "_ref_character.png"))
    kolik = 0
    for f in range(acl.CHAR["frames"]):
        ab.nastav_smer(arm, 0)
        ab.apply_walk(arm, f)
        bpy.context.view_layer.update()
        render_beauty(os.path.join(TIMING, f"char_d0_f{f}.png"))
        render_stin(os.path.join(TIMING, f"_stin_char_d0_f{f}.png"))
        kolik += 1
    return kolik


PLANY.update({"dagger": plan_dagger, "character0": plan_character0})


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    plan = "items"
    for i, a in enumerate(argv):
        if a == "--plan" and i + 1 < len(argv):
            plan = argv[i + 1]
    if plan not in PLANY:
        raise SystemExit(f"neznamy plan: {plan} (je {sorted(PLANY)})")
    t0 = time.perf_counter()
    kolik = PLANY[plan]()
    print(f"CAS pass=start_blender_a_nacteni sekund={time.perf_counter() - t0:.2f}")
    print(f"RENDER_OK lit {plan} {kolik}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
