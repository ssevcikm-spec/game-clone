# -*- coding: utf-8 -*-
"""render_2x.py - vyrenderuje 2x sprity (kreativni pruchod + pruchod stinu).

  & '...\\blender.exe' -b -P tools\\artgen\\render_2x.py -- --meritko 2x --plan dagger
  & '...\\blender.exe' -b -P tools\\artgen\\render_2x.py -- --meritko 2x --plan character0
  & '...\\blender.exe' -b -P tools\\artgen\\render_2x.py -- --meritko 1x --plan dagger

PRUCHODY (a proc tri):
  * `beauty`  - objekt s alfou, kontaktni rovina SKRYTA. To je sprite.
  * `stin`    - kontaktni rovina VIDET + objekt. Rovina je seda a osvetlena
                jednim sluncem, takze v miste stinu je tmavsi.
  * `ref`     - kontaktni rovina videt, objekt SKRYT. Rovina je osvetlena
                ROVNOMERNE, takze je to referencni hodnota pro pomer
                `stin/ref` = faktor zastineni (`postprocess_2x.py`).
                Renderuje se JEDNOU na davku (rovina se mezi framy nemeni).

`--meritko 1x` je MERICI VETEV: otevre PUVODNI 1x .blend (512 px, tri svetla,
zadna rovina) a udela presne to, co `render_sprites.py` - slouzi k tomu, aby
se "kolik stoji 2x" merilo na TOMTEZ stroji a ve stejnem okamziku, ne
porovnavanim s cisly z jineho dne. Vystup jde do `raw2x/_timing1x/`, takze se
1x sada (ani jeji raw snimky) NEMENI.

⚠ Blender vraci exit 0 i pri chybe ve skriptu - proto se po kazdem renderu
kontroluje existence PNG a nakonec se hlasi `RENDER_OK`.
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
import artgen_blender_2x as ab2  # noqa: E402
import artgen_common as ac1  # noqa: E402
import artgen_common_2x as ac2  # noqa: E402

MERITKA = {
    # `prefix` je PREDPONA SOUBORU v `blend/`: 2x zdroje jsou `2x_*.blend`
    # (aby jejich .blend1 zalohy chytil existujici .gitignore), 1x zdroje
    # zustavaji `item_dagger.blend` / `character.blend` bez zmeny.
    "1x": {"jmeno": "1x", "prefix": "", "blend": ab.BLEND, "render": ac1.RENDER,
           "px_per_unit": ac1.PX_PER_UNIT, "stin": False,
           "dir": os.path.join(ab2.RAW, "_timing1x")},
    "2x": {"jmeno": "2x", "prefix": "2x_", "blend": ab2.BLEND, "render": ac2.RENDER,
           "px_per_unit": ac2.PX_PER_UNIT, "stin": True, "dir": ab2.RAW},
}


def zapis_origin(davka: str, kam, m: dict) -> str:
    ox, oy = ab.origin_px(bpy.context.scene, kam)
    cesta = os.path.join(m["dir"], f"_origin_{davka}.json")
    os.makedirs(m["dir"], exist_ok=True)
    with open(cesta, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"davka": davka, "origin_x": ox, "origin_y": oy,
                   "render": m["render"], "px_per_unit": m["px_per_unit"],
                   "meritko": m["jmeno"]},
                  f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(f"ORIGIN {cesta} {ox:.3f} {oy:.3f}")
    return cesta


def _cas(pass_: str, t0: float) -> None:
    print(f"CAS pass={pass_} sekund={time.perf_counter() - t0:.2f}")


def render_bez_roviny(cesta: str, ma_rovinu: bool) -> None:
    """Kreativni pruchod: rovina skryta (jinak by prekryla cely sprite).

    ⚠ 1x .blend zadnou kontaktni rovinu NEMA (1x se nemeni) - `ma_rovinu` proto
    musi byt False, jinak by `prepni_rovinu` spravne spadlo. Presne to se stalo
    pri prvnim behu `mereni_2x.py`: 1x vetev hledala rovinu, ktera v 1x scene
    byt nema.
    """
    if ma_rovinu:
        ab2.prepni_rovinu(False)
    t0 = time.perf_counter()
    ab.render_do(cesta)
    _cas("beauty", t0)


def render_stin(cesta: str) -> None:
    ab2.prepni_rovinu(True)
    t0 = time.perf_counter()
    ab.render_do(cesta)
    _cas("stin", t0)


def render_ref(cesta: str) -> None:
    """Rovina bez objektu - referencni osvetleni pro pomer zastineni."""
    if os.path.exists(cesta):
        print(f"REF_SKIP {cesta} (uz existuje a rovina se mezi framy nemeni)")
        return
    ab2.prepni_rovinu(True)
    stav = ab2.skry_meshe(krome=ab2.JMENO_PODLAHY)
    try:
        t0 = time.perf_counter()
        ab.render_do(cesta)
        _cas("ref", t0)
    finally:
        ab2.vrat_meshe(stav)


def plan_dagger(m: dict) -> int:
    ab.otevri_blend(os.path.join(m["blend"], f"{m['prefix']}item_dagger.blend"))
    kam = bpy.data.objects["Cam"]
    zapis_origin("item_dagger", kam, m)
    render_bez_roviny(os.path.join(m["dir"], "item_dagger.png"), m["stin"])
    if m["stin"]:
        render_ref(os.path.join(m["dir"], "_ref_item_dagger.png"))
        render_stin(os.path.join(m["dir"], "_stin_item_dagger.png"))
    return 1


def plan_character0(m: dict) -> int:
    """JEN smer 0, vsech 8 framu (ZADANI-25 §9 odst. 2)."""
    ab.otevri_blend(os.path.join(m["blend"], f"{m['prefix']}character.blend"))
    kam = bpy.data.objects["Cam"]
    arm = bpy.data.objects["Rig"]
    zapis_origin("character", kam, m)
    if m["stin"]:
        render_ref(os.path.join(m["dir"], "_ref_character.png"))
    kolik = 0
    for f in range(ac2.CHAR["frames"]):
        ab.nastav_smer(arm, 0)
        ab.apply_walk(arm, f)
        bpy.context.view_layer.update()
        render_bez_roviny(os.path.join(m["dir"], f"char_d0_f{f}.png"), m["stin"])
        if m["stin"]:
            render_stin(os.path.join(m["dir"], f"_stin_char_d0_f{f}.png"))
        kolik += 1
    return kolik


PLANY = {"dagger": plan_dagger, "character0": plan_character0}


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    meritko, plan = "2x", "dagger"
    for i, a in enumerate(argv):
        if a == "--meritko" and i + 1 < len(argv):
            meritko = argv[i + 1]
        if a == "--plan" and i + 1 < len(argv):
            plan = argv[i + 1]
    if meritko not in MERITKA:
        raise SystemExit(f"nezname meritko: {meritko} (je {sorted(MERITKA)})")
    if plan not in PLANY:
        raise SystemExit(f"neznamy plan: {plan} (je {sorted(PLANY)})")
    t0 = time.perf_counter()
    kolik = PLANY[plan](MERITKA[meritko])
    print(f"CAS pass=start_blender_a_nacteni sekund={time.perf_counter() - t0:.2f}")
    print(f"RENDER_OK {meritko} {plan} {kolik}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
