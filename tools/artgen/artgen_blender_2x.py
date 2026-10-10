# -*- coding: utf-8 -*-
"""artgen_blender_2x.py - stavebni bloky 2x vetve (scena, jedno slunce, AO, kontaktni rovina).

Proc samostatny modul a ne "prepinac v artgen_blender.py": 1x vetev je hotova
a kryta branou; 2x se lisi ve TRECH vecech, ktere se v 1x zamerne NEMENI
(ZADANI-25 §9 odst. 2):
  1. JEDNO SMEROVE SLUNCE místo trojice klic/vypln/obrys - aby mel art jeden
     citalny smer svetla (a tim i jeden smer stinu).
  2. JEMNY AMBIENT OCCLUSION - EEVEE 5.2 uz `use_gtao` NEMA (mereno sondou
     `probe_blender_capabilities.py`); AO se dela "Fast GI" v rezimu
     `AMBIENT_OCCLUSION` s kratkym dosahem, aby to bylo kontaktni zastineni.
  3. KONTAKTNI ROVINA (pudorys dlazdice) - bez ni neni na co vrhat stin.
     Rovina se v KREATIVNIM pruchodu SKRYVA (`hide_render`) a renderuje se
     zvlast; stin se pak pocita z pomeru "s objektem / bez objektu"
     (`postprocess_2x.py`). Duvod: Blender 5.2 na teto stanici ma v enumu
     engine JEN `BLENDER_EEVEE` (Cycles neni), takze shadow catcher
     (`object.is_shadow_catcher`) je nedostupny - mereno, ne odhadnuto.

⚠ Blender vraci exit 0 i pri chybe ve skriptu (ZADANI-25 §2) - proto se po
kazdem renderu kontroluje existence PNG (`artgen_blender.render_do`).

KAM SE ZAPISUJE (a proc prave tam):
  * `tools/artgen/blend/2x_*.blend` - zdroje se drzi (ZADANI-25 §8) a `.blend1`
    zalohy jsou v tomhle adresari pokryte `.gitignore` (proto `2x_` PREDPONA
    v existujicim `blend/`, ne novy adresar `blend2x/`).
  * `tools/artgen/_raw2x/` - renderovane snimky; vzor `tools/artgen/_*` je
    ignorovany, takze se do repa nepletou obrazky (stejne jako `raw/`).
"""
from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import artgen_blender as ab  # noqa: E402
import artgen_common_2x as ac2  # noqa: E402

BLEND = os.path.join(HERE, "blend")
RAW = os.path.join(HERE, "_raw2x")

# --- jmena objektu, ktera 2x vetev pouziva ---------------------------------
JMENO_PODLAHY = "Kontakt"
JMENO_SLUNCE = "Sun"

# --- ambient occlusion (Fast GI) -------------------------------------------
# Cisla jsou zvolena tak, aby to bylo KONTAKTNI zastineni (jednotky dlazdice),
# ne globalni zasednuti sceny: dosah 0,20 jednotky = petina dlazdice.
AO_DOSAH = 0.20
AO_PAPRSKU = 4
AO_KROKU = 16
AO_KVALITA = 0.5
AO_TLOUSTKA = 0.05
# ⚠ NAZEV REZIMU JE MERENY, NE UHODNUTY: Blender 5.2 ma hodnotu
# `AMBIENT_OCCLUSION_ONLY` (odlisne od `GLOBAL_ILLUMINATION`). Prvni pokus
# s "AMBIENT_OCCLUSION" spadl na `TypeError: enum ... not found` - a Blender
# pritom vratil EXIT 0 (ZADANI-25 §2). Vybira se proto z realneho enumu.
AO_REZIMY = ("AMBIENT_OCCLUSION_ONLY", "AMBIENT_OCCLUSION")

# --- svetlo ----------------------------------------------------------------
SLUNCE_ENERGIE = 4.0            # stejne jako 1x "Key" (smer i energie prevzaty)
SLUNCE_UHEL_DEG = 12.0          # mekky stin (stejne jako 1x)
OBLOHA_SILA = 0.45              # 1x ma 0,30 + dve dalsi svetla; tady je jen ambient
OBLOHA_BARVA = (0.40, 0.44, 0.50, 1.0)   # lehce do modra = obloha

# --- kontaktni rovina ------------------------------------------------------
PODLAHA_Z = -0.004              # 4 mm pod kontaktem: dost na z-fighting, malo na posun
PODLAHA_ALBEDO = 0.5            # SEDA, ne bila: bila by se prepalila a stin by zmizel
PODLAHA_ROUGHNESS = 1.0


def nova_scena_2x():
    """Prazdna scena pro 2x: EEVEE, alfa, 1024 px, Fast-GI AO, stiny zapnute."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.resolution_x = ac2.RENDER
    scene.render.resolution_y = ac2.RENDER
    scene.render.resolution_percentage = 100
    scene.eevee.taa_render_samples = ac2.SAMPLES
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        print("VAROVANI: view_transform 'Standard' neni, zustava",
              scene.view_settings.view_transform)
    # AO: Fast GI v rezimu AMBIENT_OCCLUSION (EEVEE Next; `use_gtao` neexistuje)
    ee = scene.eevee
    zapsano = {}
    if hasattr(ee, "use_fast_gi"):
        dostupne = [i.identifier for i in
                    ee.bl_rna.properties["fast_gi_method"].enum_items]
        rezim = next((r for r in AO_REZIMY if r in dostupne), None)
        if rezim is None:
            raise RuntimeError(f"EEVEE nema rezim AO {AO_REZIMY} - ma {dostupne}. "
                               "Nic se nedoplnuje: bez AO by 2x nemelo to, co zadani "
                               "pozaduje (ZADANI-25 §9 odst. 2)")
        ee.use_fast_gi = True
        ee.fast_gi_method = rezim
        ee.fast_gi_distance = AO_DOSAH
        ee.fast_gi_ray_count = AO_PAPRSKU
        ee.fast_gi_step_count = AO_KROKU
        ee.fast_gi_quality = AO_KVALITA
        if hasattr(ee, "fast_gi_thickness_near"):
            ee.fast_gi_thickness_near = AO_TLOUSTKA
        zapsano = {"use_fast_gi": ee.use_fast_gi, "fast_gi_method": ee.fast_gi_method,
                   "fast_gi_distance": ee.fast_gi_distance,
                   "fast_gi_ray_count": ee.fast_gi_ray_count,
                   "fast_gi_step_count": ee.fast_gi_step_count,
                   "fast_gi_quality": ee.fast_gi_quality}
        print("AO_FAST_GI " + " ".join(f"{k}={v}" for k, v in sorted(zapsano.items())))
    else:
        raise RuntimeError("EEVEE nema `use_fast_gi` - AO by se neaplikovalo, "
                           "a to zadani pozaduje (nic se nedoplnuje potichu)")
    if hasattr(ee, "use_shadows"):
        ee.use_shadows = True
        for k, v in (("shadow_ray_count", 2), ("shadow_step_count", 12)):
            if hasattr(ee, k):
                setattr(ee, k, v)
    world = bpy.data.worlds.new("World2x")
    scene.world = world
    world.use_nodes = True
    pozadi = world.node_tree.nodes["Background"]
    pozadi.inputs[0].default_value = OBLOHA_BARVA
    pozadi.inputs[1].default_value = OBLOHA_SILA
    return scene


def kamera_2x(cil=(0.0, 0.0, 0.0), az_deg: float = None,
              elev_deg: float = None):
    """Ortho kamera 2x - STEJNA funkce jako 1x, jen s 2x meritkem.

    `ortho_scale = RENDER / PX_PER_UNIT` je pri zdvojnasobenem rozliseni i
    zdvojnasobenem meritku STEJNY jako v 1x (1,4545 jednotky) - model se tedy
    vejde do zaberu presne jako v 1x a "2x" je ciste rozliseni.
    """
    az = math.radians(ac2.CAM_AZIMUTH_DEG if az_deg is None else az_deg)
    elev = math.radians(ac2.CAM_ELEVATION_DEG if elev_deg is None else elev_deg)
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = ac2.RENDER / float(ac2.PX_PER_UNIT)
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.scene.collection.objects.link(cam)
    d = 4.0
    cam.location = (cil[0] + d * math.sin(az) * math.cos(elev),
                    cil[1] + d * math.cos(az) * math.cos(elev),
                    cil[2] + d * math.sin(elev))
    smer = (Vector(cil) - Vector(cam.location)).normalized()
    cam.rotation_euler = smer.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    print(f"KAMERA_2X ortho_scale={data.ortho_scale:.6f} "
          f"({ac2.RENDER}px / {ac2.PX_PER_UNIT}px_na_jednotku)")
    return cam


def slunce():
    """JEDNO smerove slunce - smer prevzaty z 1x klicoveho svetla."""
    bpy.ops.object.light_add(type="SUN", rotation=ac2.uhel_slunce_rad())
    s = bpy.context.object
    s.name = JMENO_SLUNCE
    s.data.energy = SLUNCE_ENERGIE
    s.data.color = (1.0, 1.0, 1.0)
    s.data.angle = math.radians(SLUNCE_UHEL_DEG)
    s.data.use_shadow = True
    print(f"SLUNCE rot={tuple(round(v, 3) for v in ac2.uhel_slunce_rad())} "
          f"energie={SLUNCE_ENERGIE} uhel_deg={SLUNCE_UHEL_DEG}")
    return s


def kontaktni_rovina():
    """Rovina o presne 1x1 jednotce = pudorys dlazdice; v kreativnim pruchodu SKRYTA.

    Proc presne dlazdice: stin pak nemuze "utect" mimo dlazdici, na ktere objekt
    stoji - a prave to je rozdil mezi "stojí NA dlazdici" a "leti nad ni".
    """
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=1, y_subdivisions=1, size=1.0,
                                    location=(0.0, 0.0, PODLAHA_Z))
    o = bpy.context.object
    o.name = JMENO_PODLAHY
    m = ab.mat("kontakt_rovina", (PODLAHA_ALBEDO, PODLAHA_ALBEDO, PODLAHA_ALBEDO),
               roughness=PODLAHA_ROUGHNESS)
    o.data.materials.append(m)
    o.hide_render = True                  # kreativni pruchod: rovina NESMI byt videt
    print(f"PODLAHA {JMENO_PODLAHY} z={PODLAHA_Z} albedo={PODLAHA_ALBEDO} hide_render=True")
    return o


def prepni_rovinu(videt: bool) -> None:
    """Prepnout kontaktni rovinu mezi kreativnim pruchodem a pruchodem stinu."""
    o = bpy.data.objects.get(JMENO_PODLAHY)
    if o is None:
        raise RuntimeError(f"v scene neni {JMENO_PODLAHY} - stin by se nemel na co vrstvit")
    o.hide_render = not videt


def skry_meshe(krome: str = "") -> list[tuple[str, bool]]:
    """Skryt vsechny meshe (pro REFERENCNI pruchod roviny bez objektu).

    Vraci puvodni stavy, aby se dalo vratit - ne "nechat to skryte a doufat".
    """
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
    raise SystemExit("artgen_blender_2x.py je modul - spousti se pres build_model_2x.py")
