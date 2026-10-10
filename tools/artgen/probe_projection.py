# -*- coding: utf-8 -*-
"""probe_projection.py - MERI, kterym smerem na obrazovce jdou svetove osy.

  & '...\\blender.exe' -b -P tools\\artgen\\probe_projection.py

PROC TO EXISTUJE: hra kresli svet podle `core/iso.gd`
(`screen = ((x-y)*ISO_STEP, (x+y)*ISO_STEP - z*Z_SCALE)`) a `anim_player.gd`
na tom stoji zrcadleni 8 smeru na 5 spritu. Kdyby nase kamera promitala svet
ZRCADLENE, bude cela sada spritu otocena na opacnou stranu - a na jedne
dlazdici (kosoctverec je soumerny) to NENI VIDET. Je to tedy prave ta vada,
 ktera se pozna az u postavy a u predmetu lezicich po diagonale.

Metoda: do sceny se daji znacky (emise, presna barva) na +X, -X, +Y, -Y, +Z,
vyrenderuje se a zmeni se TEZISTE pixelu kazde barvy. Vystup se porovna
s konvenci UO. Nic se neodhaduje z uhlu.

Vystup: `tools/artgen/_probe-projekce.json` + `_probe-projekce.png` (na pohled).
Kdo ma jinou kameru, premeri to znovu - hodnoty v `artgen_common.py` se
NEPREPISUJI od oka.
"""
from __future__ import annotations

import json
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
from artgen_common import ITEMS, LAND, PX_PER_UNIT, RENDER  # noqa: E402

# znacky: (jmeno, svetovy smer, barva) - barvy jsou daleko od sebe, aby se
# teziste dalo merit po kanalech
ZNACKY = [
    ("plusX", (1.0, 0.0, 0.0), (1.0, 0.0, 0.0)),
    ("minusX", (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
    ("plusY", (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
    ("minusY", (0.0, -1.0, 0.0), (1.0, 1.0, 0.0)),
    ("plusZ", (0.0, 0.0, 1.0), (1.0, 0.0, 1.0)),
]


def emise(jmeno: str, rgb):
    m = bpy.data.materials.new(jmeno)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = nt.nodes["Material Output"]
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    e.inputs["Strength"].default_value = 1.0
    nt.links.new(e.outputs["Emission"], out.inputs["Surface"])
    return m


def main() -> int:
    ab.nova_scena()
    # znacky dal od sebe (0.4 jednotky), aby se teziste neprekryvala
    for jmeno, smer, barva in ZNACKY:
        o = ab.krabice(jmeno, None, (0.10, 0.10, 0.10),
                       (smer[0] * 0.4, smer[1] * 0.4, 0.05 + smer[2] * 0.4))
        o.data.materials.append(emise(f"em_{jmeno}", barva))
    cam = ab.kamera(cil=(0.0, 0.0, 0.0))
    cesta = os.path.join(ab.RAW, "_probe-projekce.png")
    ab.render_do(cesta)

    img = bpy.data.images.load(cesta)
    pix = np.array(img.pixels[:], dtype=np.float32).reshape(RENDER, RENDER, 4)
    pix = pix[::-1]                       # Blender ma pocatek dole
    telo = {}
    for jmeno, smer, barva in ZNACKY:
        # kazda znacka ma jen jeden kanal > 0.5 a ostatni < 0.2 (kombinace
        # (1,0,0),(0,1,0),(0,0,1),(1,1,0),(1,0,1) jsou rozlisitelne)
        maska = np.ones((RENDER, RENDER), dtype=bool)
        for k in range(3):
            if barva[k] > 0.5:
                maska &= pix[:, :, k] > 0.5
            else:
                maska &= pix[:, :, k] < 0.2
        ys, xs = np.nonzero(maska)
        if len(xs) == 0:
            print(f"CHYBA: znacka {jmeno} v renderu neni - projekci nelze merit")
            return 1
        telo[jmeno] = (float(xs.mean()), float(ys.mean()), int(len(xs)))
        print(f"MARK {jmeno} teziste=({telo[jmeno][0]:.2f}, {telo[jmeno][1]:.2f}) px={len(xs)}")

    # prirustek na jednotku smeru. Znacky +X/-X (a +Y/-Y) lezi ve stejne vysce,
    # takze se prispevek vysky ve rozdilu vykrati - zustava cisty posun po ose.
    def delta(a: str, b: str):
        return ((telo[a][0] - telo[b][0]) / 0.8, (telo[a][1] - telo[b][1]) / 0.8)

    # +Z se meri vuci promitnutemu pocatku (znacka je ve vysce 0.45)
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    p0 = world_to_camera_view(bpy.context.scene, cam, Vector((0.0, 0.0, 0.0)))
    o0 = (p0.x * RENDER, (1.0 - p0.y) * RENDER)
    osy = {"plusX": delta("plusX", "minusX"), "plusY": delta("plusY", "minusY"),
           "plusZ": ((telo["plusZ"][0] - o0[0]) / 0.45, (telo["plusZ"][1] - o0[1]) / 0.45)}
    # UO konvence (`core/iso.gd`): +X -> (+,+) [doprava dolu], +Y -> (-,+) [doleva
    # dolu], +Z -> (0,-) [nahoru]. Vyjadreno v "sirkach artu dlazdice", aby to
    # platilo pro kazde meritko: 1 dlazdice = kosoctverec 44x44 px = 1.4142*px_per_unit
    # v renderu; UO krok je 22 px na osu = 22/44 = 0.5 sirky artu.
    #
    # MIRROR + STRETCH se aplikuji na NAMERENE delty (stejna funkce, jakou
    # pouziva `postprocess.na_uo_obrazek`) - jinak by se merilo neco jineho,
    # nez co se pak opravdu vyrobi.
    from artgen_common import na_uo_delta
    art = 1.4142135623730951 * PX_PER_UNIT
    ocekavane = {"plusX": (0.5, 0.5), "plusY": (-0.5, 0.5), "plusZ": (0.0, -1.0)}
    oc: dict = {}
    for k, (dx, dy) in osy.items():
        ux, uy = na_uo_delta(dx, dy)
        ex, ey = ocekavane[k]
        shoda = (abs(ux / art - ex) < 0.02) and (abs(uy / art - ey) < 0.02)
        oc[k] = {"raw_dx": dx, "raw_dy": dy,
                 "po_korekci_dx": ux, "po_korekci_dy": uy,
                 "dx_v_sirkach_artu": ux / art, "dy_v_sirkach_artu": uy / art,
                 "ocekavano_UO": [ex, ey], "shoda_s_UO": bool(shoda)}
        print(f"OSA {k}: raw ({dx:+.1f}, {dy:+.1f}) px/jedn. -> po korekci "
              f"({ux / art:+.3f}, {uy / art:+.3f}) sirky artu; "
              f"ocekavano UO ({ex:+.3f}, {ey:+.3f}) -> "
              f"{'SHODA' if shoda else 'NESTOVA'}")

    vse = all(v["shoda_s_UO"] for v in oc.values())
    vystup = {"px_per_unit": PX_PER_UNIT, "render": RENDER, "osy": oc,
              "shoda_s_UO": bool(vse),
              "znamky_tezist": {k: v[:2] for k, v in telo.items()}}
    with open(os.path.join(HERE, "_probe-projekce.json"), "w", encoding="utf-8",
              newline="\n") as f:
        json.dump(vystup, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print("PROBE_OK" if vse else "PROBE_NESTOVÁ")
    return 0 if vse else 1


if __name__ == "__main__":
    raise SystemExit(main())
