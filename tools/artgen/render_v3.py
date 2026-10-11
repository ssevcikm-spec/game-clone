# -*- coding: utf-8 -*-
"""render_v3.py - vyrenderuje sprity v3 (beauty + ref + stin) do `_rawv3/`.

  & 'C:\\...\\blender.exe' -b -P tools\\artgen\\render_v3.py -- --plan items

PRUCHODY: presne jako `render_lit.py` (a to je podstatne - jinak by srovnani
merilo i neco jineho nez svetlo):
  * `beauty` - objekt s alfou, kontaktni rovina SKRYTA,
  * `ref`    - kontaktni rovina VIDET, objekt SKRYTY (referencni jas),
  * `stin`   - kontaktni rovina VIDET + objekt.
Dlazdice maji jen `beauty` (dlazdice JE podlaha - stin pod ni je cely schovany
pod ni; viz `render_lit.py`).

⚠ Vystup jde do `_rawv3/`, NIKDY do `_rawlit/` - jinak by se do sady v2 zamichal
render s jinym svetlem a nikdo by to nepoznal (v `_origin_*.json` je proto
`meritko`, ktere se kontroluje).
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

import artgen_blender as ab            # noqa: E402
import artgen_blender_v3 as ab3        # noqa: E402
import artgen_common_v3 as acv         # noqa: E402

RAW = str(acv.RAW)


def zapis_origin(davka: str, kam, kde: str = None) -> str:
    ox, oy = ab.origin_px(bpy.context.scene, kam)
    kde = RAW if kde is None else kde
    os.makedirs(kde, exist_ok=True)
    cesta = os.path.join(kde, f"_origin_{davka}.json")
    with open(cesta, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"davka": davka, "origin_x": ox, "origin_y": oy,
                   "render": acv.RENDER, "px_per_unit": acv.PX_PER_UNIT,
                   "meritko": acv.MERITKO}, f, ensure_ascii=False, indent=1,
                  sort_keys=True)
        f.write("\n")
    print(f"ORIGIN {cesta} {ox:.3f} {oy:.3f}")
    return cesta


def _cas(pass_: str, t0: float) -> None:
    print(f"CAS pass={pass_} sekund={time.perf_counter() - t0:.2f}")


def render_beauty(cesta: str) -> None:
    if ab3.ma_rovinu():
        ab3.prepni_rovinu(False)
    t0 = time.perf_counter()
    ab.render_do(cesta)
    _cas("beauty", t0)


def render_ref(cesta: str) -> None:
    if os.path.exists(cesta):
        print(f"REF_SKIP {cesta} (uz existuje a rovina se mezi framy nemeni)")
        return
    ab3.prepni_rovinu(True)
    stav = ab3.skry_meshe(krome=acv.JMENO_PODLAHY)
    try:
        t0 = time.perf_counter()
        ab.render_do(cesta)
        _cas("ref", t0)
    finally:
        ab3.vrat_meshe(stav)


def render_stin(cesta: str) -> None:
    ab3.prepni_rovinu(True)
    t0 = time.perf_counter()
    ab.render_do(cesta)
    _cas("stin", t0)


def plan_tiles() -> int:
    kolik = 0
    for spec in acv.LAND:
        jmeno = spec["name"]
        ab.otevri_blend(os.path.join(str(acv.BLEND),
                                     f"{acv.PREFIX_BLEND}tile_{jmeno}.blend"))
        kam = bpy.data.objects["Cam"]
        zapis_origin(f"tile_{jmeno}", kam)
        render_beauty(os.path.join(RAW, f"tile_{jmeno}.png"))
        kolik += 1
    return kolik


def plan_items() -> int:
    kolik = 0
    for spec in acv.ITEMS:
        jmeno = spec["name"]
        ab.otevri_blend(os.path.join(str(acv.BLEND),
                                     f"{acv.PREFIX_BLEND}item_{jmeno}.blend"))
        kam = bpy.data.objects["Cam"]
        zapis_origin(f"item_{jmeno}", kam)
        render_beauty(os.path.join(RAW, f"item_{jmeno}.png"))
        render_ref(os.path.join(RAW, f"_ref_item_{jmeno}.png"))
        render_stin(os.path.join(RAW, f"_stin_item_{jmeno}.png"))
        kolik += 1
    return kolik


def plan_character() -> int:
    ab.otevri_blend(os.path.join(str(acv.BLEND),
                                 f"{acv.PREFIX_BLEND}character.blend"))
    kam = bpy.data.objects["Cam"]
    arm = bpy.data.objects["Rig"]
    zapis_origin("character", kam)
    render_ref(os.path.join(RAW, "_ref_character.png"))
    kolik = 0
    for d in range(acv.CHAR["dirs"]):
        ab.nastav_smer(arm, d)
        for f in range(acv.CHAR["frames"]):
            ab.apply_walk(arm, f)
            bpy.context.view_layer.update()
            render_beauty(os.path.join(RAW, f"char_d{d}_f{f}.png"))
            render_stin(os.path.join(RAW, f"_stin_char_d{d}_f{f}.png"))
            kolik += 1
    return kolik


PLANY = {"tiles": plan_tiles, "items": plan_items, "character": plan_character}

# ---------------------------------------------------------------------------
# merici vetev (stejny rozsah prace jako `render_lit.py --plan dagger/character0`)
# ---------------------------------------------------------------------------
# PROC: "kolik stoji vypln" se neda spocitat z behu nad jinym poctem spritu -
# `mereni_v3.py` proto meri OBE vetve na TOMTEZ (dyka = 1 sprite, postava =
# 8 framu smeru 0). Vystup jde do `_rawv3/_timing-v3/`, aby se nepletl s raw
# snimky cele sady.
TIMING = os.path.join(RAW, "_timing-v3")


def plan_timing() -> int:
    """Dyka (1 sprite) a postava (8 framu smeru 0) - podle `--jen`."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    jen = "both"
    for i, a in enumerate(argv):
        if a == "--jen" and i + 1 < len(argv):
            jen = argv[i + 1]
    os.makedirs(TIMING, exist_ok=True)
    kolik = 0
    if jen in ("both", "dagger"):
        ab.otevri_blend(os.path.join(str(acv.BLEND),
                                     f"{acv.PREFIX_BLEND}item_dagger.blend"))
        kam = bpy.data.objects["Cam"]
        zapis_origin("item_dagger", kam, kde=TIMING)
        render_beauty(os.path.join(TIMING, "item_dagger.png"))
        render_ref(os.path.join(TIMING, "_ref_item_dagger.png"))
        render_stin(os.path.join(TIMING, "_stin_item_dagger.png"))
        kolik += 1
    if jen in ("both", "character"):
        ab.otevri_blend(os.path.join(str(acv.BLEND),
                                     f"{acv.PREFIX_BLEND}character.blend"))
        kam = bpy.data.objects["Cam"]
        arm = bpy.data.objects["Rig"]
        zapis_origin("character", kam, kde=TIMING)
        render_ref(os.path.join(TIMING, "_ref_character.png"))
        for f in range(acv.CHAR["frames"]):
            ab.nastav_smer(arm, 0)
            ab.apply_walk(arm, f)
            bpy.context.view_layer.update()
            render_beauty(os.path.join(TIMING, f"char_d0_f{f}.png"))
            render_stin(os.path.join(TIMING, f"_stin_char_d0_f{f}.png"))
            kolik += 1
    return kolik


PLANY["timing"] = plan_timing


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
    print(f"RENDER_OK_V3 {plan} {kolik}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
