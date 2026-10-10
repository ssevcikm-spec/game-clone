# -*- coding: utf-8 -*-
"""artgen_blender.py - stavebni bloky Blender skriptu pilotu (kamera, svetla,
primitiva, chuze, modely).

Proc jeden modul: `build_model_*.py` (stavi a uklada .blend) a
`render_sprites.py` (otevre .blend a renderuje) MUSI pouzivat TUTEZ kameru,
svetla i chuzi - kdyby si je pocitaly kazdy zvlast, vyrenderuje se neco jineho,
nez se postavilo, a nikdo to nepozna (ZADANI-25 §4.1 rozdeluje jen "stavba"
a "render", ne cisla).

KAMERA (a proc prave takhle):
  * ORTHO, azimut 45 stupnu, elevace 45 stupnu. Duvod je MERENY, ne esteticky:
    UO land art je 44x44 kosoctverec, ktery vyplnuje CELY box (mereno na
    `assets/uo/atlas/land_0.png`), a presne to je ortho projekce jednotkove
    ctvrtky pri elevaci 45 stupnu. `render/chunk_mesh.gd:641-644` kresli land
    na kosoctverec 2*ISO_STEP = 44x44 px - souhlas.
  * `ortho_scale = RENDER / PX_PER_UNIT` => 1 svetova jednotka = PX_PER_UNIT px
    v renderu. 1 jednotka = 1 dlazdice = 44 px ve finale, takze se vsechno
    modeluje v jednotkach dlazdice a "jak je to velke" je jedno cislo.
  * POCATEK (0,0,0) JE KONTAKTNI BOD predmetu/postavy s terénem a soucasne
    stred pudorysu - proto se modely stavi kolem nej (ne "nekde u modelu").
    `origin_px()` vraci, kam se promitl; `pack_atlas.py` ho pouzije jako kotvu.

SVETLA: tri slunce (klic/vypln/obrys) jako ve VZORU
(`E:\\Workspaces\\uo-shadows\\tools\\blender\\build_character.py`), ale s
trojici z pevnych smeru, aby sada drzela jeden smer svetla.

Pozn.: `bpy.ops.wm.read_factory_settings(use_empty=True)` je na zacatku KAZDEHO
behu - jinak by se do vystupu pletly objekty z uzivatelskeho profilu.
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

from artgen_common import (CAM_AZIMUTH_DEG, CAM_ELEVATION_DEG, PX_PER_UNIT,  # noqa: E402
                           RENDER, SAMPLES, TILE)

BLEND = os.path.join(HERE, "blend")
RAW = os.path.join(HERE, "raw")


# ---------------------------------------------------------------------------
# scena, kamera, svetla
# ---------------------------------------------------------------------------
def nova_scena(rezim_sveta: str = "KLIC") -> bpy.types.Scene:
    """Prazdna scena s EEVEE, alfou a 512x512. Vraci `scene`."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True          # alfa z rendereru, zadny klic
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.resolution_x = RENDER
    scene.render.resolution_y = RENDER
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.eevee.taa_render_samples = SAMPLES
    # Barevna sprava: AgX (vychozi v 4.x/5.x) barvy vymyva - pro sprity chceme
    # to, co je v materialu. Kdyz "Standard" v teto verzi neni, rekni to.
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        print("VAROVANI: view_transform 'Standard' neni, zustava",
              scene.view_settings.view_transform)
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    pozadi = world.node_tree.nodes["Background"]
    pozadi.inputs[0].default_value = (0.40, 0.42, 0.45, 1.0)   # ambient jako ve VZORU
    # ⚠ NAMERENO 2026-10-10: pri strength 0.55 vysel art vyrazne SVETLEJSI nez UO
    # (trava (74,122,48) proti UO (42,64,13)) a bez kontrastu. Ambient je tu jen
    # doplnkove svetlo, hlavni je klic - proto 0.30.
    pozadi.inputs[1].default_value = 0.30
    return scene


def kamera(cil=(0.0, 0.0, 0.0), az_deg: float = None, elev_deg: float = None):
    """Ortho kamera otocena na `cil`; vzdalenost je jen konstrukcni."""
    az = math.radians(CAM_AZIMUTH_DEG if az_deg is None else az_deg)
    elev = math.radians(CAM_ELEVATION_DEG if elev_deg is None else elev_deg)
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = RENDER / float(PX_PER_UNIT)
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.scene.collection.objects.link(cam)
    d = 4.0
    cam.location = (cil[0] + d * math.sin(az) * math.cos(elev),
                    cil[1] + d * math.cos(az) * math.cos(elev),
                    cil[2] + d * math.sin(elev))
    smer = (Vector(cil) - Vector(cam.location)).normalized()
    cam.rotation_euler = smer.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def svetla():
    """Tri slunce: klic (nahore vlevo), vypln (vpravo), obrys (zezadu).

    Smer svetla je KONVENCE pro celou sadu (`game-assets`: "kdyz se smer svetla
    rozjede, sada vypada jako slepenec") - jedna zmena tady meni celou sadu.
    """
    for jmeno, energie, rot in (("Key", 4.0, (-0.7, 0.0, -2.6)),
                                ("Fill", 1.0, (0.6, 0.0, 2.6)),
                                ("Rim", 1.4, (-1.2, 0.0, 3.0))):
        bpy.ops.object.light_add(type="SUN", rotation=rot)
        svetlo = bpy.context.object
        svetlo.name = jmeno
        svetlo.data.energy = energie
        svetlo.data.color = (1.0, 1.0, 1.0)
        svetlo.data.angle = math.radians(12.0)     # mekky stin (zadna tvrda hrana)


def origin_px(scene: bpy.types.Scene, cam) -> tuple[float, float]:
    """KAM se promitl kontaktni bod (0,0,0) - presna hodnota z Blenderu.

    Neodhaduje se z uhlu: `world_to_camera_view` je tatа funkce, kterou pouziva
    i Blender pro render, takze kotva v postprocessu sedi na pixel.
    """
    from bpy_extras.object_utils import world_to_camera_view
    souradnice = world_to_camera_view(scene, cam, Vector((0.0, 0.0, 0.0)))
    return (souradnice.x * scene.render.resolution_x,
            (1.0 - souradnice.y) * scene.render.resolution_y)


def render_do(cesta: str) -> int:
    """Render jednoho snimku. Vraci velikost souboru; chybejici PNG = chyba.

    ⚠ Blender vraci exit 0 i kdyz skript spadne (ZADANI-25 §2), takze "nespadlo
    to" neni dukaz - proto se po renderu KONTROLUJE, ze soubor existuje a neni
    prazdny. Kdyz ne, konci se nenulovym kodem (a volajici to vidi na stderr).
    """
    scene = bpy.context.scene
    os.makedirs(os.path.dirname(cesta), exist_ok=True)
    scene.render.filepath = cesta
    bpy.ops.render.render(write_still=True)
    if not os.path.exists(cesta):
        raise RuntimeError(f"render nezapsal {cesta}")
    velikost = os.path.getsize(cesta)
    if velikost <= 0:
        raise RuntimeError(f"render zapsal prazdny soubor {cesta}")
    print(f"RENDERED {cesta} {velikost}")
    return velikost


def uloz_blend(cesta: str) -> None:
    os.makedirs(os.path.dirname(cesta), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=cesta, compress=True)
    if not os.path.exists(cesta):
        raise RuntimeError(f"blend se neulozil: {cesta}")
    print(f"BLEND {cesta} {os.path.getsize(cesta)}")


def otevri_blend(cesta: str):
    """Otevre .blend a vrati (scene, objekty)."""
    if not os.path.exists(cesta):
        raise RuntimeError(f"chybi blend: {cesta}")
    bpy.ops.wm.open_mainfile(filepath=cesta)
    return bpy.context.scene


# ---------------------------------------------------------------------------
# primitiva a materialy
# ---------------------------------------------------------------------------
def mat(jmeno: str, rgb, roughness: float = 0.6, metallic: float = 0.0):
    m = bpy.data.materials.new(jmeno)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF") or m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def _dokonci(obj, jmeno: str, material, hladke: bool):
    obj.name = jmeno
    if material is not None:
        obj.data.materials.append(material)
    if hladke:
        bpy.ops.object.shade_smooth()
    return obj


def krabice(jmeno, material, size, loc, rot=(0.0, 0.0, 0.0), hladke=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _dokonci(o, jmeno, material, hladke)


def valec(jmeno, material, r, h, loc, rot=(0.0, 0.0, 0.0), vrcholu=20, hladke=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vrcholu, radius=r, depth=h,
                                        location=loc, rotation=rot)
    return _dokonci(bpy.context.object, jmeno, material, hladke)


def koule(jmeno, material, r, loc, hladke=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=r, location=loc)
    return _dokonci(bpy.context.object, jmeno, material, hladke)


def koule_ico(jmeno, material, r, loc, hladke=False, poddeleni=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=poddeleni, radius=r, location=loc)
    return _dokonci(bpy.context.object, jmeno, material, hladke)


def kuzel(jmeno, material, r1, r2, h, loc, rot=(0.0, 0.0, 0.0), vrcholu=12, hladke=False):
    bpy.ops.mesh.primitive_cone_add(vertices=vrcholu, radius1=r1, radius2=r2, depth=h,
                                    location=loc, rotation=rot)
    return _dokonci(bpy.context.object, jmeno, material, hladke)


def plocha(jmeno, material, size, loc, rezu=24, hladke=False):
    """Vodorovna ctvrtka (grid) - zaklad dlazdice."""
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=rezu, y_subdivisions=rezu,
                                    size=1.0, location=loc)
    o = bpy.context.object
    o.scale = (size[0], size[1], 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _dokonci(o, jmeno, material, hladke)


def zesikmi(obj, rot):
    obj.rotation_euler = rot


def posun(obj, v):
    obj.location = (obj.location[0] + v[0], obj.location[1] + v[1], obj.location[2] + v[2])


# ---------------------------------------------------------------------------
# smer na obrazovce -> svetova osa
# ---------------------------------------------------------------------------
# Na obrazovce UO plati `screen = ((x - y) * 22, (x + y) * 22)` (core/iso.gd).
# Proto:
#   +X ... na obrazovce DOPRAVA-DOLU   (na jihovychod)
#   +Y ... na obrazovce DOLEVA-DOLU
#   -Y ... na obrazovce DOPRAVA-NAHORU (na severovychod)
# `probe_projection.py` tuhle shodu MERI (a `run_all.py` na ni ma branu) - kdyz
# se azimut kamery zmeni, tyhle smery se musi premerit, ne prepsat od oka.
OSA_X = (1.0, 0.0)          # smer +X ve svete (x, y)
OSA_Y = (0.0, 1.0)
OSA_MINUS_Y = (0.0, -1.0)


def natoc_na(obj, osa_xy, delka: float):
    """Poloha stredu usecky delky `delka` lezici ve smeru `osa_xy` ve vysce z."""
    return (osa_xy[0] * delka, osa_xy[1] * delka, 0.0)


# ---------------------------------------------------------------------------
# modely predmetu (1 jednotka = 1 dlazdice = 44 px)
# ---------------------------------------------------------------------------
def postav_dyku():
    """Dyka lezici na zemi po diagonale (na obrazovce doprava-nahoru jako UO 3921).

    Delka se ladi tak, aby obsah mel na obrazovce ~11x11 px (mereno u UO);
    `pack_atlas.py` to pak PREMERA a zapise do MERENI.md.
    """
    # BARVY PREDMETU: kalibrovane na UO (2026-10-10, dve kola). Prvni beh dal
    # u dyky (136,128,114) proti UO (62,52,68), u ingotu (132,136,142) proti
    # (70,81,89); po prvnim ztmaveni (faktor 0,4) zbyla odchylka hlavne
    # v SATURACI (UO je teplejsi/oranzovejsi). Cisla jsou v `MERENI.md`.
    kov = mat("dyka_kov", (0.20, 0.20, 0.23), roughness=0.25, metallic=1.0)
    drzak = mat("dyka_drzak", (0.075, 0.050, 0.030), roughness=0.7)
    zlaty = mat("dyka_zlaty", (0.26, 0.17, 0.06), roughness=0.35, metallic=0.8)
    u = OSA_MINUS_Y                       # smer "nahoru vpravo" na obrazovce
    # hrot (dolu vlevo) -> hlavice (nahoru vpravo); stredy ve smeru u
    y = lambda t: (u[0] * t, u[1] * t, 0.030)
    kuzel("dyka_hrot", kov, 0.030, 0.0, 0.085, y(0.150), rot=(math.radians(90), 0, 0))
    krabice("dyka_cepel", kov, (0.052, 0.17, 0.020), y(0.020))
    krabice("dyka_zamek", zlaty, (0.115, 0.030, 0.020), y(-0.075))
    valec("dyka_rukojet", drzak, 0.024, 0.085, y(-0.135), rot=(math.radians(90), 0, 0))
    koule("dyka_hlavice", zlaty, 0.030, y(-0.190))


def postav_krumpac():
    """Krumpac lezici na zemi: topurko po ose +X (na obrazovce doprava-dolu).

    POZOR na stred: kontaktni bod je STRED PUDORYSU, takze model musi byt
    vystredeny na pocatku. NamEReno 2026-10-10 u prvni verze: obsah vychazel
    o 2 px vpravo od stredu sprite (nos koncil na -0.42, topurko na +0.53) -
    predmety by na dlazdici sedely bokem. Proto `posun`.
    """
    drevo = mat("krumpac_drevo", (0.16, 0.098, 0.042), roughness=0.8)
    ocel = mat("krumpac_ocel", (0.12, 0.125, 0.135), roughness=0.35, metallic=0.9)
    x = OSA_X
    posun = -0.055
    stred = lambda t: (x[0] * t + posun, x[1] * t, 0.030)
    valec("krumpac_topurko", drevo, 0.021, 0.74, stred(0.16),
          rot=(math.radians(90), math.radians(-45), math.radians(90)))
    # nos: dve ramena do stran (koleno krumpace) + kratky trn
    krabice("krumpac_nos", ocel, (0.055, 0.22, 0.045), stred(-0.24),
            rot=(0, 0, math.radians(45)))
    krabice("krumpac_nos2", ocel, (0.055, 0.16, 0.042), stred(-0.28),
            rot=(0, 0, math.radians(-25)))
    kuzel("krumpac_trn", ocel, 0.030, 0.0, 0.09, stred(-0.33),
          rot=(0, math.radians(-90), 0))


def postav_rudu():
    """Hromadka rudy: 7 hrud (deformovane krychle) rozesazenych po dlazdici.

    MERENO 2026-10-10: UO ruda 6583 ma obsah 30x35 px a prumernou barvu
    (94,60,57) - je to ROZSYPNY shluk malych hrud, ne jeden balvan. Prvni verze
    (5 velkych hrud na hromade) se renderem slila do jednoho bloku.
    """
    kamen = mat("ruda_kamen", (0.040, 0.036, 0.033), roughness=0.9)
    ruda = mat("ruda_ruda", (0.115, 0.048, 0.032), roughness=0.55, metallic=0.35)
    hroudy = [
        # (x, y, r, rotace_z, material)
        (-0.16, -0.05, 0.062, 0.4, kamen),
        (0.10, -0.15, 0.058, 1.1, kamen),
        (0.17, 0.05, 0.052, 2.0, ruda),
        (-0.06, 0.14, 0.060, 2.7, kamen),
        (0.01, -0.02, 0.066, 0.9, ruda),
        (-0.15, 0.10, 0.046, 1.7, kamen),
        (0.13, 0.12, 0.044, 2.4, ruda),
    ]
    for i, (x, y, r, rot, m) in enumerate(hroudy):
        o = koule_ico(f"ruda_hrud{i}", m, r, (x, y, r * 0.75), hladke=False, poddeleni=1)
        o.scale = (1.0, 0.85, 0.75)
        o.rotation_euler = (0.3, 0.2, rot)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def postav_ingot():
    """Ingot (zkosena tyc) lezici na zemi po diagonale jako UO 7151.

    Osy: "nahoru vpravo" na obrazovce je svetove -Y (kamera v azimutu 45 stupnu,
    `probe_projection.py` to MERI). Driv tu byla rotace -45 stupnu, ktera tyc
    otocila na smer +X+Y = KE KAMERE; obsah pak vysel 8x16 px (UO ma 15x15).
    """
    kov = mat("ingot_kov", (0.175, 0.185, 0.20), roughness=0.45, metallic=0.8)
    # sirka (X) 0.32 x delka (Y) 0.30 x tloustka 0.085 -> obsah ~13 x 15 px
    # (UO 7151 ma 15x15; prvni verze mela 0.26 x 0.34 a vychazelo 11x15)
    krabice("ingot_tyc", kov, (0.32, 0.30, 0.080), (0.0, 0.0, 0.040))
    krabice("ingot_hrana", kov, (0.26, 0.24, 0.060), (0.0, 0.0, 0.095))


# ---------------------------------------------------------------------------
# dlazdice terenu
# ---------------------------------------------------------------------------
def _sumova_textura(jmeno: str, velikost: float):
    t = bpy.data.textures.new(jmeno, type="CLOUDS")
    t.noise_scale = velikost
    t.noise_depth = 2
    return t


def _okraj_skupina(obj, sirka: float = 0.22):
    """Vytvori vertex group "okraj": 0 na hranici dlazdice, 1 uvnitr.

    PROC: Displace modifier bez vahy zvedne i krajni vrcholy - a sousedni
    dlazdice pak maji na styku hreben/zbrani, ktery je VIDET jako mrizka
    (namEReno 2026-10-10 na 3x3 skladacce: travni dlazdice mely zretelne
    svetle linky po hranach). Váha displacement na okraji vynuluje, takze
    plocha se v miste styku vraci do roviny a dlazdice na sebe sedi.
    """
    vg = obj.vertex_groups.new(name="okraj")
    for v in obj.data.vertices:
        # vzdalenost od hranice ctverce 1x1 (0 = hranice, 0.5 = stred)
        d = min(0.5 - abs(v.co.x), 0.5 - abs(v.co.y))
        vg.add([v.index], min(1.0, max(0.0, d / sirka)), "REPLACE")
    return vg


def postav_dlazdici(druh: str, seed: int = 20261010):
    """Dlazdice 1x1 jednotky (kosoctverec 44x44 px) - trava nebo cesta.

    Textura je PROCEDURALNI a deterministicka (Clouds nema seed, `random` ho ma
    pevny) - dva behy daji stejny obrazek, coz je podminka opakovatelneho
    pilotu. Displacement dela "povrch", ne jen placatou barvu.
    """
    import random
    rng = random.Random(seed)
    if druh == "grass":
        # BARVA JE ZMERENA z UO (land 3: prumer (42,64,13), odchylka (18,21,10)).
        # Kalibrace 2. kolo (2026-10-10): 1. kolo dalo (64,79,53) proti UO
        # (42,64,13) - jas blizko, ale modra slozka 4x vyssi (modry ambient).
        # Albedo je proto podelene zmerenym pomerem linearu (0.45, 0.66, 0.12).
        zaklad = mat("trava", (0.0060, 0.0207, 0.0002), roughness=0.9)
        p = plocha("tile", zaklad, (1.0, 1.0), (0.0, 0.0, 0.0), rezu=36)
        vg = _okraj_skupina(p)
        d = p.modifiers.new("Displace", type="DISPLACE")
        d.texture = _sumova_textura("trava_sum", 0.16)
        d.strength = 0.030
        d.mid_level = 0.5
        d.vertex_group = "okraj"
        # druha vrstva: jemnejsi zrno, aby trava nebyla jednolita
        d2 = p.modifiers.new("Displace2", type="DISPLACE")
        d2.texture = _sumova_textura("trava_sum2", 0.045)
        d2.strength = 0.012
        d2.mid_level = 0.5
        d2.vertex_group = "okraj"
        # trsy (kuzely) - drzi se dal od okraje, aby nevycnivaly ze dlazdice
        for i in range(22):
            x = rng.uniform(-0.36, 0.36)
            y = rng.uniform(-0.36, 0.36)
            kuzel(f"trs{i}", zaklad, 0.028, 0.0, rng.uniform(0.05, 0.11),
                  (x, y, 0.03), vrcholu=5)
        return [p]
    if druh == "road":
        # UO 1001 (cobblestones): prumer (50,44,41), odchylka (24,22,21) - hodne
        # tmava, hruba plocha. Kalibrace jako u travy: prvni beh (albedo
        # 0.15/0.13/0.11) dal (141,136,131), cil je (50,44,41) -> albedo niz.
        # Kalibrace 2. kolo: 1. kolo dalo (68,64,62) proti UO (50,44,41).
        zaklad = mat("cesta_pisek", (0.0106, 0.0064, 0.0044), roughness=0.95)
        p = plocha("tile", zaklad, (1.0, 1.0), (0.0, 0.0, 0.0), rezu=24)
        kamen = mat("cesta_kamen", (0.0171, 0.0113, 0.0088), roughness=0.85)
        kamen2 = mat("cesta_kamen2", (0.0131, 0.0088, 0.0068), roughness=0.85)
        # KAMENY AZ ZA OKRAJ (do 0.56): kdyz koncily na 0.46, zustal po obvodu
        # dlazdice pruh holeho podkladu a ve skladacce to byl zretelny tmavy
        # RAMEČEK (namEReno 2026-10-10). Presah ukousne az maska kosoctverce.
        for i in range(80):
            x = rng.uniform(-0.56, 0.56)
            y = rng.uniform(-0.56, 0.56)
            s = rng.uniform(0.070, 0.140)
            h = rng.uniform(0.022, 0.040)
            krabice(f"kamen{i}", kamen if i % 2 else kamen2,
                    (s, s * rng.uniform(0.7, 1.1), h),
                    (x, y, h * 0.35), rot=(0, 0, rng.uniform(0, math.pi)))
        return [p]
    raise ValueError(f"neznamy druh dlazdice: {druh}")


# ---------------------------------------------------------------------------
# postava (celi +X, boky +-Y) + chuze
# ---------------------------------------------------------------------------
FRAMES = 8
THIGH_LEN = 0.28
SHIN_LEN = 0.28
HIP_Z = 0.66
ANKLE_Z = 0.10
STRIDE = 0.40
LIFT = 0.075
AARM = 0.75


def postav_postavu():
    """Postava (telo + tunika + kalhoty + boty + vlasy), kostra a vazby.

    Vraci (`arm`, seznam objektu).

    POZOR NA PROPORCE (namEReno 2026-10-10): prvni verze mela uzke proporce
    (sirka/vyska 0,23) a v postprocessu vysla 9 px siroka - UO telo 400 ma
    framy 18-40 px siroke (median 25) pri vysce 56-64 px, tedy pomer ~0,4.
    Proto jsou trup, ramena i koncetiny SIRSI: cil je pomer ~0,35 (UO je
    "stocky" - kreslene postavy jsou proti realnym proporcim siroke).
    """
    # ⚠ NAMERENO 2026-10-10 (druha iterace): i "stocky" proporce daji pri
    # spravne projekci jen ~10 px sirky, protoze UO kresli postavu v PREDNIM
    # pohledu 24-25 px sirokou pri vysce 60 px - tedy 1,14 svetove jednotky,
    # coz jeho vlastni projekce (22 px na jednotku) neumoznuje. UO art je
    # v sirce NADSAZENY. Volime proto zamerne sirsi model (pomer ~0,4 jako UO),
    # aby postava cetla jako clovek; cislo je v `MERENI.md`.
    kuze = mat("kuze", (0.80, 0.60, 0.45), roughness=0.55)
    tunika = mat("tunika", (0.22, 0.28, 0.50), roughness=0.75)
    kalhoty = mat("kalhoty", (0.30, 0.23, 0.16), roughness=0.8)
    boty = mat("boty", (0.20, 0.14, 0.10), roughness=0.7)
    vlasy = mat("vlasy", (0.16, 0.11, 0.07), roughness=0.8)
    pas = mat("pas", (0.42, 0.30, 0.16), roughness=0.6)

    koule("head", kuze, 0.1000, (0.0, 0.0, 1.075))
    koule("hair", vlasy, 0.1045, (0.0, 0.0, 1.090))
    bpy.context.object.scale = (1.0, 1.0, 0.72)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    valec("neck", kuze, 0.0450, 0.0900, (0.0, 0.0, 0.975))
    valec("torso", kuze, 0.1300, 0.3101, (0.0, 0.0, 0.800))
    koule("pelvis", kuze, 0.1250, (0.0, 0.0, 0.650))
    valec("tunic", tunika, 0.1450, 0.3100, (0.0, 0.0, 0.795))
    valec("belt", pas, 0.1500, 0.0550, (0.0, 0.0, 0.642))
    # ramena dal od trupu - v prvni verzi byla ramena ZABORENA v tunice a ve
    # vyrenderovanem spritu nebyla videt (postava vypadala jako hranol)
    for strana, sy in (("L", 0.2600), ("R", -0.2600)):
        valec(f"upper_arm.{strana}", kuze, 0.0560, 0.2022, (0.0, sy, 0.848))
        valec(f"fore_arm.{strana}", kuze, 0.0490, 0.2157, (0.0, sy, 0.652))
        koule(f"hand.{strana}", kuze, 0.0520, (0.0, sy, 0.496))
    for strana, sy in (("L", 0.0750), ("R", -0.0750)):
        valec(f"thigh.{strana}", kuze, 0.0660, 0.2966, (0.0, sy, 0.505))
        valec(f"shin.{strana}", kuze, 0.0540, 0.2966, (0.0, sy, 0.235))
        krabice(f"foot.{strana}", boty, (0.1500, 0.0850, 0.0520), (0.075, sy, 0.0260))
        valec(f"pants_thigh.{strana}", kalhoty, 0.0780, 0.3100, (0.0, sy, 0.505))
        valec(f"pants_shin.{strana}", kalhoty, 0.0620, 0.2900, (0.0, sy, 0.235))
        valec(f"boot.{strana}", boty, 0.0680, 0.1100, (0.0, sy, 0.1150))

    # --- kostra ---
    data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones

    def kost(jmeno, head, tail, rodic=None):
        b = eb.new(jmeno)
        b.head = head
        b.tail = tail
        if rodic is not None:
            b.parent = rodic
        return b

    root = kost("root", (0, 0, 0.95 * 0.674), (0, 0, 1.42 * 0.674))
    neck = kost("neck", (0, 0, 1.42 * 0.674), (0, 0, 1.56 * 0.674), root)
    kost("head", (0, 0, 1.56 * 0.674), (0, 0, 1.74 * 0.674), neck)
    for strana, sy in (("L", 0.2600), ("R", -0.2600)):
        ua = kost(f"upper_arm.{strana}", (0, sy, 1.40 * 0.674), (0, sy, 1.12 * 0.674), root)
        fa = kost(f"fore_arm.{strana}", (0, sy, 1.12 * 0.674), (0, sy, 0.82 * 0.674), ua)
        kost(f"hand.{strana}", (0, sy, 0.82 * 0.674), (0, sy, 0.74 * 0.674), fa)
    for strana, sy in (("L", 0.0750), ("R", -0.0750)):
        th = kost(f"thigh.{strana}", (0, sy, 0.95 * 0.674), (0, sy, 0.55 * 0.674), root)
        sh = kost(f"shin.{strana}", (0, sy, 0.55 * 0.674), (0, sy, 0.15 * 0.674), th)
        kost(f"foot.{strana}", (0, sy, 0.15 * 0.674), (0.18 * 0.674, sy, 0.03 * 0.674), sh)
    bpy.ops.object.mode_set(mode="OBJECT")

    vazby = {"head": "head", "hair": "head", "neck": "neck", "torso": "root",
             "pelvis": "root", "tunic": "root", "belt": "root"}
    for strana in ("L", "R"):
        for kost_jmeno in ("upper_arm", "fore_arm", "hand", "thigh", "shin", "foot",
                           "pants_thigh", "pants_shin", "boot"):
            vazby[f"{kost_jmeno}.{strana}"] = kost_jmeno if kost_jmeno not in (
                "pants_thigh", "pants_shin", "boot") else (
                "thigh" if kost_jmeno == "pants_thigh" else
                "shin" if kost_jmeno == "pants_shin" else "foot")
    objekty = []
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.name in vazby:
            vg = o.vertex_groups.new(name=vazby[o.name])
            vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
            mod = o.modifiers.new(name="Arm", type="ARMATURE")
            mod.object = arm
            objekty.append(o)
    print(f"BOUND_MESHES {len(objekty)}")
    return arm, objekty


def _solve_leg(fx: float, fz: float, hip_z: float) -> tuple[float, float]:
    """2-kostni IK v rovine XY? Ne - v rovine "dopredu (X) / vyska (Z)".

    Vraci (thigh_fwd, knee_bend) v radiánech; kladne `thigh_fwd` = koleno vpred
    (+X). Prevod na rotaci kosti je v `apply_walk` (rotace kolem Y).
    """
    down = hip_z - fz
    d = math.hypot(fx, down)
    L1, L2 = THIGH_LEN, SHIN_LEN
    foot_dir = math.atan2(fx, down)
    if d >= L1 + L2 - 1e-6:
        return foot_dir, 0.0
    d = max(abs(L1 - L2) + 1e-6, d)
    cos_knee = max(-1.0, min(1.0, (L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2)))
    knee_interior = math.acos(cos_knee)
    cos_alpha = max(-1.0, min(1.0, (d * d + L1 * L1 - L2 * L2) / (2.0 * d * L1)))
    alpha = math.acos(cos_alpha)
    return foot_dir + alpha, math.pi - knee_interior


def apply_walk(arm, f: int) -> None:
    """Posa snimku `f` chuze (8 framu, cyklus). Postava jde ve smeru +X."""
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    t = 2.0 * math.pi * f / FRAMES
    bob = 0.012 * math.cos(2 * t)
    hip_z = HIP_Z + bob

    def r(jmeno, dopredu):
        # rotace kolem Y: kladne "dopredu" (+X) znamena ZAPORNY uhel
        pb[jmeno].rotation_euler = (0.0, -dopredu, 0.0)

    fxL = -STRIDE / 2.0 * math.cos(t)
    fzL = ANKLE_Z + LIFT * max(0.0, math.sin(t))
    fxR = -STRIDE / 2.0 * math.cos(t + math.pi)
    fzR = ANKLE_Z + LIFT * max(0.0, math.sin(t + math.pi))
    tl, kl = _solve_leg(fxL, fzL, hip_z)
    tr, kr = _solve_leg(fxR, fzR, hip_z)
    r("thigh.L", tl)
    r("shin.L", -kl)
    r("thigh.R", tr)
    r("shin.R", -kr)
    r("foot.L", 0.0)
    r("foot.R", 0.0)
    r("upper_arm.L", AARM * math.cos(t))
    r("upper_arm.R", -AARM * math.cos(t))
    r("fore_arm.L", 0.25)
    r("fore_arm.R", 0.25)
    pb["root"].rotation_euler = (0.0, 0.05, 0.0)      # predklon vpred
    pb["root"].location = (0.0, 0.0, bob)


def nastav_smer(arm, d: int) -> None:
    """Otoci postavou (kolem Z) do smeru spritu `d` (UO konvence 0..4).

    sprite 0 = celni (postava se diva NA kameru), 1 = ctvrtpredni, 2 = profil,
    3 = ctvrtzadni, 4 = zadni. Otaci se CELY rig, takze chuze zustava lokalni.
    """
    arm.rotation_euler = (0.0, 0.0, math.radians(CAM_AZIMUTH_DEG + 45.0 * d))
