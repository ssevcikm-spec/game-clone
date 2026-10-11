# -*- coding: utf-8 -*-
"""artgen_blender_v3.py - stavebni bloky 1x sceny pro sadu v3 (2026-10-11).

PROC SAMOSTATNY MODUL: sada v2 (`assets/own-lit/`) je hotova a kryta branou
(893 kontrol) - do jeji vetve se nesaha, aby zustal dohledatelny puvodni stav.
Tenhle modul z ni bere VSECHNO, co se nemeni (`artgen_blender.nova_scena`,
kamera, primitiva, modely, chuze, kontaktni rovina, prepinani pruchodu) a meni
JEN TO, CO JE ZMERENE JAKO VADA:

  * SVETLO: k jednomu smerovemu slunci pribyva VYPLN (druhe slunce z protismeru,
    `use_shadow=False`, energie 1,5) - v2 melo jen jedno slunce a kovum to vzalo
    odlesky (rozptyl jasu dyky 25,7 -> 15,2; `MERENI.md` §9.3 bod 1);
  * OBLOHA: 0,45 -> 0,50 (sada v2 je tmavsi o 8-13 %).

⚠ KONTAKTNI STIN SE TADY NEMENI - meni se az v postprocessu
(`postprocess_lit.RECEPTY_STINU["v3"]`), protoze vada byla v ubytku, ne
v renderu. Renderuje se stejna kontaktni rovina jako ve v2.

⚠ Blender vraci exit 0 i pri chybe ve skriptu (ZADANI-25 §2) - proto se po
kazdem renderu kontroluje existence PNG (`artgen_blender.render_do`).
"""
from __future__ import annotations

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab            # noqa: E402
import artgen_blender_lit as abl       # noqa: E402  (zaklad sceny a rovina)
import artgen_common_lit as acl        # noqa: E402
import artgen_common_v3 as acv         # noqa: E402

BLEND = str(acv.BLEND)
RAW = str(acv.RAW)

# ⚠ KONTROLA RECEPTU PROTI v2: co v3 PREBIRA, musi byt SKUTECNE totez. Kdyby se
# v2 zmenilo (nebo v3 "samo" predefinovalo kameru, AO nebo rovinu), lit a v3
# sada by se lisily ve vic vecech, nez je zapsano v `odchylky_od_v2()` - a to by
# nikdo nepoznal. Proto se to overi TADY (uvnitr Blenderu) a pri rozdilu se
# konci chybou.
_ZRCADLENO = ("JMENO_SLUNCE", "JMENO_PODLAHY", "SLUNCE_ENERGIE", "SLUNCE_UHEL_DEG",
              "OBLOHA_BARVA", "AO_REZIMY", "AO_DOSAH", "AO_PAPRSKU", "AO_KROKU",
              "AO_KVALITA", "AO_TLOUSTKA", "PODLAHA_Z", "PODLAHA_ALBEDO",
              "PODLAHA_ROUGHNESS")
_rozdily = [f"{j}: v3={getattr(acv, j)!r} v2={getattr(acl, j, '<v v2 neni>')!r}"
            for j in _ZRCADLENO
            if getattr(acv, j) != getattr(acl, j, "<v v2 neni>")]
if _rozdily:
    raise RuntimeError("recept v3 se v prebirane casti lisi od v2: "
                       + "; ".join(_rozdily))
print(f"RECEPT_V3_OK {len(_ZRCADLENO)} prebiranych konstant je shodnych s v2; "
      f"NOVE: vypln={acv.VYPLN_ENERGIE} obloha={acv.OBLOHA_SILA} "
      f"(v2 mela {acl.OBLOHA_SILA})")


def nova_scena_v3():
    """Scena v2 + NASE zmeny svetla (AO, rezim, alfa i rozliseni se NEMENI)."""
    scene = abl.nova_scena_lit()          # 1x + Fast-GI AO + jedno slunce dle v2
    pozadi = scene.world.node_tree.nodes["Background"]
    pozadi.inputs[1].default_value = acv.OBLOHA_SILA
    print(f"OBLOHA_V3 sila={acv.OBLOHA_SILA} (v2 mela {acl.OBLOHA_SILA})")
    return scene


def kamera_v3(cil=(0.0, 0.0, 0.0)):
    """STEJNA kamera jako 1x/v2 (kdyby se rozešla, art by se rozešel s hrou)."""
    return ab.kamera(cil=cil)


def slunce():
    """Zakladni slunce (presne jako v2) + VYPLN z protismeru, bez stinu."""
    s = abl.slunce()                      # zakladni slunce (4,0; 12 stupnu)
    rot = acv.uhel_vyplne_rad()
    bpy.ops.object.light_add(type="SUN", rotation=rot)
    f = bpy.context.object
    f.name = acv.JMENO_VYPLNE
    f.data.energy = acv.VYPLN_ENERGIE
    f.data.color = (1.0, 1.0, 1.0)
    f.data.angle = math.radians(acv.VYPLN_UHEL_DEG)
    # ⚠ `use_shadow=False` je PODSTATA vyplne: druhy stin z jineho smeru by
    # sadu rozbil (dva stiny pod jednim predmetem). Vypln meni jen BARVU.
    f.data.use_shadow = False
    print(f"VYPLN_V3 rot={tuple(round(v, 3) for v in rot)} "
          f"energie={acv.VYPLN_ENERGIE} uhel_deg={acv.VYPLN_UHEL_DEG} "
          f"use_shadow=False")
    return s, f


def kontaktni_rovina():
    """Stejna rovina jako v2 (stin se pocita z pomeru s objektem / bez objektu)."""
    return abl.kontaktni_rovina()


def ma_rovinu() -> bool:
    return abl.ma_rovinu()


def prepni_rovinu(videt: bool) -> None:
    abl.prepni_rovinu(videt)


def skry_meshe(krome: str = "") -> list[tuple[str, bool]]:
    return abl.skry_meshe(krome)


def vrat_meshe(stav: list[tuple[str, bool]]) -> None:
    abl.vrat_meshe(stav)


if __name__ == "__main__":
    raise SystemExit("artgen_blender_v3.py je modul - spousti se pres "
                     "build_model_v3.py / render_v3.py")
