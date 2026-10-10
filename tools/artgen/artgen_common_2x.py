# -*- coding: utf-8 -*-
"""artgen_common_2x.py - kontrakt DVOJNASOBNE geometrie (ZADANI-25 §9).

Co je tenhle soubor: obdoba `artgen_common.py` pro 2x vetev. NEMENI 1x kontrakt
(`artgen_common.py` zustava nedotceny) - je to DRUHA sada konstant, ze kterych
se pocita 2x art. Duvod, proc vedle sebe a ne "prepinac v jednom modulu":
1x vetev je hotova, commitnuta a kryta branou (`pack_atlas.py --check`), takze
se do ni nesaha; 2x je zatim jen vyrenderovana varianta pro rozhodnuti.

CO ZNAMENA "2x" (a co NE):
  * ZVETSI SE POCET PIXELU NA TUTEZ SVETOVOU VZDALENOST. Model se NEMENI -
    1 svetova jednotka = 1 dlazdice = 1 mesto v mape, jako v 1x. Meni se jen
    meritko renderu a tim i vysledneho spritu:
        1x: dlazdice 44 px, krok 22 px, 1 jednotka vysky 44 px, render 512 px
        2x: dlazdice 88 px, krok 44 px, 1 jednotka vysky 88 px, render 1024 px
    V hernich konstantach tomu odpovida `ISO_STEP 22 -> 44` a `Z_SCALE 4 -> 8`
    (`core/const.gd`); POMER zustava, meni se jen cisla.

  * ⚠ "DIAMANT 88x44" ZE ZADANI JE ROZPOR (a je to zapsane, ne premlcene).
    ZADANI-25 §9 odst. 1 rika "diamant 88x44", ale §9 ve svem zaveru a §3
    (OPRAVA z pilotu, merena) rikaji, ze pomer je **1 : 1** - UO dlazdice je
    44x44 s kosoctvercem o stejnych uhloprickach (maska 1012 px), kosoctverec
    2:1 je jen tvar kresby uvnitr ctverce, ktery UO NEPOUZIVA. 2x geometrie
    tedy je **88x88** (kosoctverec 1:1), ne 88x44. Kdyby se udelalo 88x44,
    rozbila by se relace `ISO_STEP == TILE_W/2` a s ni brana `G1`.
    cisla v tomhle souboru jsou proto 88/44 (strana/krok), ne 88/44 (sirka/vyska).

  * ANCHOR (kotva) je 2x vzorec UO:  `ox = (w>>1) - 44`, `oy = h - 88`
    pro `item`/`anim`; `land` zustava `ox = oy = 0`.

KAM SE ZAPISUJE: `assets/own2x/` (novy jmenný prostor vedle `assets/own/`).
Hra ho dnes necte - `render/texture_cache.gd` ma jednu cestu k manifestu a ta
zustava `assets/uo/`; 2x je varianta pro rozhodnuti, ne integrace (ZADANI-25 §9).
"""
from __future__ import annotations

# 1x kontrakt jen CTEME - kdyby se 1x zmenil, 2x se musi premyslet, ne tise
# rozejit (proto se odsud bere kamera a projekce, ne opsanim cisel).
import artgen_common as ac1

# --- stranky atlasu: STEJNE jako UO i 1x -----------------------------------
PAGE = 2048
PAD = 1

# --- geometrie (2x vsechno) ------------------------------------------------
TILE = 88                     # px, strana dlazdice (2 x 44)
GROUND_PX = 44                # kontakt je 44 px nad spodni hranou (2 x 22)
ITEM_OFFSET = 0x4000
TEXMAP_OFFSET = 0x10000

# --- render (ortho kamera, 2x meritko) -------------------------------------
# `ortho_scale` je RENDER / PX_PER_UNIT, takze pri obojim dvojnasobnem zustava
# zaber STEJNY - model se vejde do zaberu presne jako v 1x a "2x" je ciste
# rozliseni. Kdyby se zdvojnasobil jen RENDER, byl by ve spritu jen roh modelu.
PX_PER_UNIT = 704             # px svetove jednotky v renderu = 8x koncovy px (2 x 352)
RENDER = 1024                 # px strana renderu (2 x 512)
SAMPLES = 64                  # EEVEE TAA vzorky (stejne jako 1x - srovnatelne)

# Projekce se NEMENI (je zmerena v 1x, `probe_projection.py`): elevace 35,264,
# zrcadleni X, svisle roztazeni 1/sin(elev) = 1,7321. Meni se jen meritko.
CAM_AZIMUTH_DEG = ac1.CAM_AZIMUTH_DEG
CAM_ELEVATION_DEG = ac1.CAM_ELEVATION_DEG
MIRROR_X = ac1.MIRROR_X
VYSTRED_Y = ac1.VYSTRED_Y

# Vysledna projekce ve 2x sprite: +X -> (+44, +44) px, +Y -> (-44, +44),
# +Z -> (0, -88). To je PRESNE 2x 1x kontrakt (`UO_OSY_PX` v `artgen_common`).
UO_OSY_PX = {k: (v[0] * 2.0, v[1] * 2.0) for k, v in ac1.UO_OSY_PX.items()}

# --- co se vyrabi -----------------------------------------------------------
# UO obsah je NAMERENY (viz `artgen_common.ITEMS`); cil 2x = PRESNE 2x UO obsah.
# Kdyby 2x melo stejnou velikost jako 1x, nebylo by to "2x geometrie", ale
# "stejny sprite ve vetsim renderu" - a srovnavaci list by nemel co ukazat.
ITEMS = [
    {"name": "dagger", "uo_id": 3921,
     "uo_content": (11, 11),          # namereno na UO artu (1x i 2x zdroj)
     "cil_obsah": (22, 22)},          # 2x UO obsah
]

CHAR = {
    "body": 400,
    "action_walk": 0,
    "dirs": 1,                        # 2x vetev kresli JEN smer 0 (ZADANI-25 §9)
    "frames": 8,
    # Model je STEJNY jako 1x (1,2 jednotky) - meni se jen meritko renderu.
    # `world_h` tu je kvuli zamereni kamery: 1x miri na (0, 0, world_h/2),
    # protoze pri zamereni na chodidla se hlava oreze o horni hranu zaberu.
    "world_h": ac1.CHAR["world_h"],
    "cil_obsah_px": 120,              # 2 x 60 px (1x cil, namereny median UO)
    "uo_content": (25, 60),
    "frame_ms": 80,
}

# --- kontaktni stin ---------------------------------------------------------
# Stin se NEBERE z pruhlednosti renderu (Blender 5.2 na tehle stanici UMI jen
# EEVEE - `CYCLES` v enumu engine NENI, takze shadow catcher neni k dispozici,
# zmereno `probe_blender_capabilities.py`). Místo toho se renderuje KONTAKTNI
# ROVINA (presne pudorys dlazdice) a z pomeru "s objektem / bez objektu" vyjde
# faktor zastineni. Je to skutecny renderovany stin (smer slunce, mekkost,
# self-shadowing objektu), ne dokreslovana elipsa.
STIN_SILA = 0.55                   # max. krytí stinu (0..1); 0 = stin se nekresli
STIN_PRAH = 6                      # alfa pod timhle prahem se zahodi (sum z renderu)
STIN_BARVA = (0, 0, 0)             # neutralni cerny stin (sprite se kresli NA dlazdici)
# Radialni ubytek (v jednotkach dlazdice, mereno od kontaktniho bodu): do R0 je
# stin plny, od R1 neni zadny. Duvod: "kontaktni" stin ma byt louze POD objektem,
# ne dlouhy vrh pres celou dlazdici - a zaroven tim stin zustane v boxu spritu
# (R1*88 = 30 px < GROUND_PX = 44 px, takze se sprite nerozjede pod kontakt).
STIN_R0_JEDNOTEK = 0.14
STIN_R1_JEDNOTEK = 0.34


def ofsahy(kind: str, w: int, h: int) -> tuple[int, int]:
    """(ox, oy) 2x vzorec UO: `ox=(w>>1)-44`, `oy=h-88`; land `0,0`."""
    if kind in ("land", "texmap"):
        return (0, 0)
    return ((w >> 1) - TILE // 2, h - TILE)


def na_uo_bod(x: float, y: float, sirka: int = None) -> tuple[float, float]:
    """Pixel v 2x renderu -> pixel po korekci projekce (stejna funkce jako 1x)."""
    sirka = RENDER if sirka is None else sirka
    if MIRROR_X:
        x = (sirka - 1) - x
    return (x, (y + 0.5) * VYSTRED_Y - 0.5)


def na_uo_velikost(vyska: int) -> int:
    """Vyska obrazku po svislem roztazeni (2x render -> 2x sprite)."""
    return int(round(vyska * VYSTRED_Y))


def jednotky_na_px(jednotky: float) -> float:
    """Svetove jednotky -> px ve FINALNI 2x sprite (1 jednotka = 88 px)."""
    return jednotky * TILE


def anim_id(direction: int, frame: int) -> int:
    """Stejny klic spritu jako 1x i UO: `body*1000 + action*100 + dir*10 + frame`."""
    return CHAR["body"] * 1000 + CHAR["action_walk"] * 100 + direction * 10 + frame


def anim_parts(ident: int) -> tuple[int, int, int, int]:
    return (ident // 1000, (ident // 100) % 10, (ident // 10) % 10, ident % 10)


def rozloz(rady: list[tuple], page: int = PAGE, pad: int = PAD) -> list[tuple]:
    """Shelf-pack se STEJNYM razenim jako `atlas.py` (determinismus)."""
    out: list[tuple] = []
    cislo = x = y = vyska = 0
    for kind, ident, w, h in sorted(rady, key=lambda r: (-r[3], r[2], r[0], r[1])):
        if x + w + pad > page:
            x, y, vyska = 0, y + vyska + pad, 0
        if y + h + pad > page:
            cislo, x, y, vyska = cislo + 1, 0, 0, 0
        out.append((kind, ident, cislo, x, y))
        x += w + pad
        vyska = max(vyska, h)
    return out


def kosoctverec_mask(w: int, h: int):
    """Presny kosoctverec 2x dlazdice (jen pro kontrolu pomeru; 2x dlazdice se nevyrabi).

    Stejna podminka jako 1x (`|c-44| + |r-44| <= 44`), takze plati: obsah 2x
    kosoctverce = 4x obsah 1x (protoze pocet pixelu roste se ctvercem meritka).
    """
    import numpy as np
    stred = (w / 2.0, h / 2.0)
    cc, rr = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    return (np.abs(cc - stred[0]) + np.abs(rr - stred[1])) <= (TILE / 2.0)


def souhrn() -> dict:
    """Vsechna cisla 2x kontraktu na jednom miste (pro manifest a MERENI.md)."""
    return {
        "tile_px": TILE,
        "ground_px": GROUND_PX,
        "iso_step_px": TILE // 2,
        "z_scale_px_na_jednotku": TILE,
        "render_px": RENDER,
        "px_per_unit": PX_PER_UNIT,
        "ortho_scale": RENDER / float(PX_PER_UNIT),
        "kotva": "item/anim: ox=(w>>1)-%d, oy=h-%d; land: 0,0" % (TILE // 2, TILE),
        "diamond": "1:1 (kosoctverec %dx%d) - ZADANI-25 §3 OPRAVA, viz docstring" % (TILE, TILE),
        "jednotka_vysky_px": TILE,
        "vystred_y": round(VYSTRED_Y, 6),
        "mirror_x": MIRROR_X,
        "kam_elevace_deg": round(CAM_ELEVATION_DEG, 6),
        "kam_azimut_deg": CAM_AZIMUTH_DEG,
        "pomer_proti_1x": 2.0,
        "1x_tile_px": ac1.TILE,
        "odvozeno_z": "artgen_common.py (1x kontrakt se nemeni)",
    }


def pomer_obsahu_1x_2x() -> float:
    """Kolikrat vetsi ma byt obsah 2x spritu (= 2,0) - kontrola v `pack_atlas_2x --check`."""
    return TILE / float(ac1.TILE)


def uhel_slunce_rad() -> tuple[float, float, float]:
    """Rotace JEDINEHO smeroveho slunce - PREVZATA z 1x klicoveho svetla.

    Duvod: sada musi mit jeden smer svetla; kdyby si 2x vymyslela vlastni,
    vypadala by vedle 1x jako jina sada (a srovnani by merilo i smer svetla).
    """
    return (-0.7, 0.0, -2.6)
