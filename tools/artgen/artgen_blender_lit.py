# -*- coding: utf-8 -*-
"""artgen_blender_lit.py - stavebni bloky 1x sceny SE SVETLEM (ZADANI-25 §10).

PROC SAMOSTATNY MODUL: 1x vetev (`artgen_blender.py`) je hotova, commitnuta
a kryta branou (`pack_atlas.py --check`, 476 kontrol) - do te se nesaha, aby
zustal dohledatelny puvodni stav. Tenhle modul z ni VSE ostatni bere:

  * scenu zaklada `ab.nova_scena()` (512 px, `film_transparent`, `Standard`,
    64 TAA vzorku) - takze se NEMENI nic z 1x renderu;
  * kameru, primitiva, modely i chuzi bere z `artgen_blender` (stejna kamera =
    stejna projekce, jinak by se art rozejel s 1x sadou);
  * jen PRIDAVA/NAHRAZUJE svetlo: jedno smerove slunce misto trojice
    (klic/vypln/obrys), Fast-GI AO a kontaktni rovinu.

⚠ VYMENA SVETLA JE VYMENA SCENY, NE KOSMETIKA: 1x ma tri slunce a ambient 0,30,
lit ma jedno slunce a ambient 0,45 (recept z 2x). Barvy se tim posunou - je to
MERENE (`MERENI.md` §9), ne prehlédnute.

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

import artgen_blender as ab  # noqa: E402
import artgen_blender_2x as ab2  # noqa: E402
import artgen_common_lit as acl  # noqa: E402

BLEND = str(acl.BLEND)
RAW = str(acl.RAW)

# ⚠ KONTROLA RECEPTU: konstanty svetla ma lit vetev ZRCADLEME z `artgen_blender_2x`
# (ten importuje `bpy`, takze z Pillow vetve dostupny neni). TADY - uvnitr
# Blenderu - jsou oba moduly importovatelne, takze se shoda da OVERIT. Kdyby se
# rozešly, lit sada by mela "podobny" recept misto toho sameho a nikdo by si
# toho nevsiml; proto se v tom pripade KONCI CHYBOU.
_rozdily = []
for _jmeno, _hodnota in acl.zrcadlo_2x().items():
    _v2x = getattr(ab2, _jmeno, "<v 2x neni>")
    if _v2x != _hodnota:
        _rozdily.append(f"{_jmeno}: lit={_hodnota!r} 2x={_v2x!r}")
if _rozdily:
    raise RuntimeError("recept svetla se lisi od 2x vetve: " + "; ".join(_rozdily))
print(f"RECEPT_OK {len(acl.zrcadlo_2x())} konstant svetla je shodnych s 2x vetvi "
      f"(slunce={acl.SLUNCE_ENERGIE} uhel={acl.SLUNCE_UHEL_DEG} "
      f"obloha={acl.OBLOHA_SILA} ao_rezim={acl.AO_REZIMY[0]})")


def nova_scena_lit():
    """1x scena + Fast-GI AO + obloha podle 2x receptu (rozliseni zustava 512)."""
    scene = ab.nova_scena()                  # 1x: 512 px, Standard, alfa, 64 TAA
    ee = scene.eevee
    if not hasattr(ee, "use_fast_gi"):
        raise RuntimeError("EEVEE nema `use_fast_gi` - AO by se neaplikovalo, "
                           "a to je to, co se z 2x prebira. Nic se nedoplnuje potichu.")
    dostupne = [i.identifier for i in ee.bl_rna.properties["fast_gi_method"].enum_items]
    rezim = next((r for r in acl.AO_REZIMY if r in dostupne), None)
    if rezim is None:
        # ⚠ Presne tahle past uz jednou nastala v 2x vetvi: hodnota
        # "AMBIENT_OCCLUSION" v Blenderu 5.2 NEEXISTUJE (je ..._ONLY), Blender
        # vratil exit 0 a traceback sel na stderr. Proto se vybira z realneho
        # enumu a kdyz neni, SKONCI SE - AO se nesmi tise vynechat.
        raise RuntimeError(f"EEVEE nema rezim AO {acl.AO_REZIMY} - ma {dostupne}")
    ee.use_fast_gi = True
    ee.fast_gi_method = rezim
    ee.fast_gi_distance = acl.AO_DOSAH
    ee.fast_gi_ray_count = acl.AO_PAPRSKU
    ee.fast_gi_step_count = acl.AO_KROKU
    ee.fast_gi_quality = acl.AO_KVALITA
    if hasattr(ee, "fast_gi_thickness_near"):
        ee.fast_gi_thickness_near = acl.AO_TLOUSTKA
    if hasattr(ee, "use_shadows"):
        ee.use_shadows = True
        for k, v in (("shadow_ray_count", 2), ("shadow_step_count", 12)):
            if hasattr(ee, k):
                setattr(ee, k, v)
    pozadi = scene.world.node_tree.nodes["Background"]
    pozadi.inputs[0].default_value = acl.OBLOHA_BARVA
    pozadi.inputs[1].default_value = acl.OBLOHA_SILA
    print("SVETLO_LIT rezim=%s dosah=%.2f paprsku=%d kroku=%d kvalita=%.2f "
          "obloha=%.2f barva=%s" % (rezim, acl.AO_DOSAH, acl.AO_PAPRSKU,
                                    acl.AO_KROKU, acl.AO_KVALITA, acl.OBLOHA_SILA,
                                    tuple(round(v, 2) for v in acl.OBLOHA_BARVA)))
    return scene


def kamera_lit(cil=(0.0, 0.0, 0.0)):
    """STEJNA kamera jako 1x (`ab.kamera`): ortho_scale = 512/352, elevace 35,264."""
    return ab.kamera(cil=cil)


def slunce():
    """JEDNO smerove slunce - smer i energie prevzate z 2x vetve."""
    bpy.ops.object.light_add(type="SUN", rotation=acl.uhel_slunce_rad())
    s = bpy.context.object
    s.name = acl.JMENO_SLUNCE
    s.data.energy = acl.SLUNCE_ENERGIE
    s.data.color = (1.0, 1.0, 1.0)
    s.data.angle = math.radians(acl.SLUNCE_UHEL_DEG)
    s.data.use_shadow = True
    print(f"SLUNCE_LIT rot={tuple(round(v, 3) for v in acl.uhel_slunce_rad())} "
          f"energie={acl.SLUNCE_ENERGIE} uhel_deg={acl.SLUNCE_UHEL_DEG}")
    return s


def kontaktni_rovina():
    """Rovina presne 1x1 jednotky = pudorys dlazdice; v kreativnim pruchodu SKRYTA.

    Stejna rovina jako ve 2x (jen 1x meritko) - stin se pak pocita z pomeru
    "s objektem / bez objektu", protoze Blender 5.2 na teto stanici nema Cycles
    a tim ani shadow catcher (`probe_blender_capabilities.py`, mereno).
    """
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=1, y_subdivisions=1, size=1.0,
                                    location=(0.0, 0.0, acl.PODLAHA_Z))
    o = bpy.context.object
    o.name = acl.JMENO_PODLAHY
    m = ab.mat("kontakt_rovina_lit", (acl.PODLAHA_ALBEDO, acl.PODLAHA_ALBEDO,
                                      acl.PODLAHA_ALBEDO), roughness=acl.PODLAHA_ROUGHNESS)
    o.data.materials.append(m)
    o.hide_render = True
    print(f"PODLAHA_LIT {acl.JMENO_PODLAHY} z={acl.PODLAHA_Z} "
          f"albedo={acl.PODLAHA_ALBEDO} hide_render=True")
    return o


def ma_rovinu() -> bool:
    return bpy.data.objects.get(acl.JMENO_PODLAHY) is not None


def prepni_rovinu(videt: bool) -> None:
    """Prepnout kontaktni rovinu mezi kreativnim pruchodem a pruchodem stinu."""
    o = bpy.data.objects.get(acl.JMENO_PODLAHY)
    if o is None:
        raise RuntimeError(f"v scene neni {acl.JMENO_PODLAHY} - stin by se nemel "
                           "na co vrstvit")
    o.hide_render = not videt


def skry_meshe(krome: str = "") -> list[tuple[str, bool]]:
    """Skryt vsechny meshe (pro REFERENCNI pruchod roviny bez objektu)."""
    stav = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name != krome:
            stav.append((o.name, o.hide_render))
            o.hide_render = True
    return stav


def vrat_meshe(stav: list[tuple[str, bool]]) -> None:
    for jmeno, byl in stav:
        o = bpy.data.objects.get(jmeno)
        if o is not None:
            o.hide_render = byl


if __name__ == "__main__":
    raise SystemExit("artgen_blender_lit.py je modul - spousti se pres "
                     "build_model_lit.py / render_lit.py")
