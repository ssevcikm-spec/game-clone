# -*- coding: utf-8 -*-
"""artgen_common_lit.py - kontrakt 1x sady SE SVETLEM (`assets/own-lit/`).

CO JE TENHLE SOUBOR: druha sada konstant vedle `artgen_common.py`, presne jako
`artgen_common_2x.py` je vedle nej. Plyne z **doporuceni ZADANI-25 §10**:
"zustat u 1x a vzit si z 2x JEN svetlo" - proto:

  * GEOMETRIE SE NEMENI a je odsud jen PRECITANA (`artgen_common`): dlazdice
    44x44, krok 22, kotva `ox=(w>>1)-22, oy=h-44`, render 512 px, 352 px na
    jednotku. Kdyby se tady opsala cisla, mohla by se rozejit s 1x sadou.
  * SVETLO SE SEM BERE Z 2x VETVE (`artgen_common_2x`): jedno smerove slunce,
    Fast-GI AO, kontaktni rovina a vsechna cisla kontaktniho stinu. Neni to
    "podobny recept", je to **tyz objekt konstant** - kdyby se 2x recept zmenil,
    zmeni se i tenhle (a `pack_atlas_lit.py --check` na tom ma branu).

CO SE NEBERE: rozliseni. 2x vetev ma 88 px dlazdici, 1024 px render a 704 px na
jednotku; tohle zustava 1x (44/512/352). Presne to je zaver §10: prinos byl ve
svetle, ne v rozliseni (2x je ve stejnem meritku MEKCÍ - ostrost hrany 0,79 ->
0,34).

KAM SE ZAPISUJE: `assets/own-lit/` (novy jmenný prostor; `assets/own/` zustava
nedotcene pro srovnani) a `tools/artgen/_rawlit/` (renderovane snimky; vzor
`tools/artgen/_*` je ignorovany, takze se obrazky do repa nepletou).
"""
from __future__ import annotations

from pathlib import Path

# --- 1x kontrakt: jen CTEME, neopisujeme ------------------------------------
import artgen_common as ac1  # noqa: E402

# --- svetlo: BEREME z 2x vetve (ZADANI-25 §10) ------------------------------
import artgen_common_2x as ac2  # noqa: E402

# --- stranky atlasu (stejne jako UO, 1x i 2x) -------------------------------
PAGE = ac1.PAGE
PAD = ac1.PAD

# --- geometrie: 1x, nemeni se ----------------------------------------------
TILE = ac1.TILE                     # 44 px
GROUND_PX = ac1.GROUND_PX           # 22 px (kontakt nad spodni hranou spritu)
ITEM_OFFSET = ac1.ITEM_OFFSET
TEXMAP_OFFSET = ac1.TEXMAP_OFFSET

# --- render: 1x cisla (rozliseni se NEMENI) --------------------------------
PX_PER_UNIT = ac1.PX_PER_UNIT       # 352
RENDER = ac1.RENDER                 # 512
SAMPLES = ac1.SAMPLES               # 64
CAM_AZIMUTH_DEG = ac1.CAM_AZIMUTH_DEG
CAM_ELEVATION_DEG = ac1.CAM_ELEVATION_DEG
MIRROR_X = ac1.MIRROR_X
VYSTRED_Y = ac1.VYSTRED_Y

# --- jmena objektu ve scene ------------------------------------------------
JMENO_PODLAHY = "Kontakt"
JMENO_SLUNCE = "Sun"

# --- svetlo (jedno smerove slunce + Fast-GI AO) ------------------------------
# ⚠ TYHLE KONSTANTY MAJI SVUJ DOMOV V `artgen_blender_2x.py` - a ten importuje
# `bpy`, takze z Pillow vetve (a z brany) dostupny NENI. Jsou tu proto ZRCADLEM
# a jejich shoda se OVERUJE tam, kde jsou oba moduly importovatelne: uvnitr
# Blenderu (`artgen_blender_lit.py` na startu skonci chybou, kdyby se rozešly -
# vcetne jmen objektu vyse). Cisla jsou opsana z 2x vetve 1:1.
SLUNCE_ENERGIE = 4.0            # stejne jako 1x "Key" i 2x SLUNCE_ENERGIE
SLUNCE_UHEL_DEG = 12.0          # mekky stin
OBLOHA_SILA = 0.45              # 2x: 1x ma 0,30 + dve dalsi svetla, tady je jen ambient
OBLOHA_BARVA = (0.40, 0.44, 0.50, 1.0)     # lehce do modra = obloha

# --- ambient occlusion (Fast GI) -------------------------------------------
AO_REZIMY = ("AMBIENT_OCCLUSION_ONLY", "AMBIENT_OCCLUSION")
AO_DOSAH = 0.20                 # 0,20 jednotky = petina dlazdice (kontaktni, ne globalni)
AO_PAPRSKU = 4
AO_KROKU = 16
AO_KVALITA = 0.5
AO_TLOUSTKA = 0.05

# --- kontaktni rovina -------------------------------------------------------
PODLAHA_Z = -0.004              # 4 mm pod kontaktem: dost na z-fighting, malo na posun
PODLAHA_ALBEDO = 0.5            # seda, ne bila: bila by se prepalila a stin by zmizel
PODLAHA_ROUGHNESS = 1.0

# Konstanty, ktere se zrcadli z `artgen_blender_2x` (overuje Blender) ---------
JMENA_ZRCADLENA_2X = ("SLUNCE_ENERGIE", "SLUNCE_UHEL_DEG", "OBLOHA_SILA",
                      "OBLOHA_BARVA", "AO_REZIMY", "AO_DOSAH", "AO_PAPRSKU",
                      "AO_KROKU", "AO_KVALITA", "AO_TLOUSTKA", "PODLAHA_Z",
                      "PODLAHA_ALBEDO", "PODLAHA_ROUGHNESS", "JMENO_PODLAHY",
                      "JMENO_SLUNCE")

# --- kontaktni stin ---------------------------------------------------------
STIN_SILA = ac2.STIN_SILA
STIN_PRAH = ac2.STIN_PRAH
STIN_BARVA = ac2.STIN_BARVA
STIN_R0_JEDNOTEK = ac2.STIN_R0_JEDNOTEK
STIN_R1_JEDNOTEK = ac2.STIN_R1_JEDNOTEK

# --- co se vyrabi (stejny seznam jako 1x, ZADANI-25 §3) --------------------
LAND = ac1.LAND
ITEMS = ac1.ITEMS
CHAR = ac1.CHAR

# --- kam se zapisuje --------------------------------------------------------
HERE = Path(__file__).resolve().parent
RAW = HERE / "_rawlit"                        # renderovane snimky (ignorovano)
BLEND = HERE / "blend"                        # zdroje; prefix `lit_`
SADA = Path("assets/own-lit")                 # novy jmenný prostor
PREFIX_BLEND = "lit_"
MERITKO = "1x-lit"                            # znacka v `_origin_*.json`


# ---------------------------------------------------------------------------
# 1x pomocne funkce - jen se predavaji dal, aby se nikde neopisovala cisla
# ---------------------------------------------------------------------------
def ofsahy(kind: str, w: int, h: int) -> tuple[int, int]:
    """(ox, oy) PRESNE jako 1x a UO: `ox=(w>>1)-22`, `oy=h-44`; land `0,0`."""
    return ac1.ofsahy(kind, w, h)


def na_uo_bod(x: float, y: float, sirka: int = None) -> tuple[float, float]:
    """Korekce projekce (zrcadleni + svisle roztazeni) - 1x cisla."""
    return ac1.na_uo_bod(x, y, sirka=sirka)


def na_uo_velikost(vyska: int) -> int:
    return ac1.na_uo_velikost(vyska)


def jednotky_na_px(jednotky: float) -> float:
    return ac1.jednotky_na_px(jednotky)


def anim_id(direction: int, frame: int) -> int:
    return ac1.anim_id(direction, frame)


def anim_parts(ident: int) -> tuple[int, int, int, int]:
    return ac1.anim_parts(ident)


def rozloz(rady: list[tuple], page: int = PAGE, pad: int = PAD) -> list[tuple]:
    """Shelf-pack se STEJNYM razenim jako `atlas.py` (determinismus)."""
    return ac1.rozloz(rady, page=page, pad=pad)


def uhel_slunce_rad() -> tuple[float, float, float]:
    """Rotace JEDINEHO smeroveho slunce - z 2x vetve (sada musi mit jeden smer)."""
    return ac2.uhel_slunce_rad()


# ---------------------------------------------------------------------------
# brana: "recept svetla je TYZ jako v 2x" (ne jen podobny)
# ---------------------------------------------------------------------------
def recept_svetla() -> dict:
    """Vsechna cisla receptu svetla, ktery je spolecny s 2x vetvi.

    Zapisuje se do manifestu (`source.svetlo_recept`) - aby se dalo overit, ze
    hotova sada vznikla TIMHLE receptem, a ne jen ze si to skript mysli.
    """
    return {
        "slunce_rotace_rad": list(uhel_slunce_rad()),
        "slunce_energie": SLUNCE_ENERGIE,
        "slunce_uhel_deg": SLUNCE_UHEL_DEG,
        "slunce_pocet": 1,
        "obloha_sila": OBLOHA_SILA,
        "obloha_barva": list(OBLOHA_BARVA),
        "ao_rezim": list(AO_REZIMY),
        "ao_dosah_jednotek": AO_DOSAH,
        "ao_paprsku": AO_PAPRSKU,
        "ao_kroku": AO_KROKU,
        "ao_kvalita": AO_KVALITA,
        "kontaktni_rovina_z": PODLAHA_Z,
        "kontaktni_rovina_albedo": PODLAHA_ALBEDO,
        "stin_sila": STIN_SILA,
        "stin_prah": STIN_PRAH,
        "stin_barva": list(STIN_BARVA),
        "stin_r0_jednotek": STIN_R0_JEDNOTEK,
        "stin_r1_jednotek": STIN_R1_JEDNOTEK,
    }


def zrcadlo_2x() -> dict:
    """Konstanty zrcadlene z `artgen_blender_2x` - overuje je Blender.

    Vraci {jmeno: hodnota_tady}; `artgen_blender_lit.py` je porovna s zivym
    modulem 2x vetve a pri rozdilu SKONCI (nesmi se stat, ze by lit sada mela
    "podobny" recept misto toho sameho).
    """
    return {j: globals()[j] for j in JMENA_ZRCADLENA_2X}


def shoda_receptu_s_2x() -> list[tuple[str, object, object]]:
    """[(jmeno, hodnota_tady, hodnota_v_2x)] - brana v `pack_atlas_lit.py --check`.

    Kontroluje se ZIVY model 2x (`artgen_common_2x`), ne text v manifestu:
    kdyby si lit vetev neco predefinovala sama, je to tady videt. Konstanty,
    ktere 2x ma v Blender modulu, overuje `artgen_blender_lit.py` (tam jsou oba
    moduly importovatelne) - tady je proto jen to, co jde z Pillow vetve.
    """
    return [
        # v `artgen_common_2x` (Pillow vetev, bez bpy):
        ("slunce_rotace_rad", list(uhel_slunce_rad()), list(ac2.uhel_slunce_rad())),
        ("stin_sila", STIN_SILA, ac2.STIN_SILA),
        ("stin_prah", STIN_PRAH, ac2.STIN_PRAH),
        ("stin_barva", list(STIN_BARVA), list(ac2.STIN_BARVA)),
        ("stin_r0", STIN_R0_JEDNOTEK, ac2.STIN_R0_JEDNOTEK),
        ("stin_r1", STIN_R1_JEDNOTEK, ac2.STIN_R1_JEDNOTEK),
        # slunce/obloha/AO/rovina jsou v `artgen_blender_2x` (bpy) -> zrcadlo,
        # ktere overuje `artgen_blender_lit.py` uvnitr Blenderu
    ]


def souhrn() -> dict:
    """Cisla lit kontraktu na jednom miste (do manifestu a do MERENI.md)."""
    return {
        "tile_px": TILE,
        "ground_px": GROUND_PX,
        "iso_step_px": TILE // 2,
        "render_px": RENDER,
        "px_per_unit": PX_PER_UNIT,
        "ortho_scale": RENDER / float(PX_PER_UNIT),
        "kotva": "item/anim: ox=(w>>1)-%d, oy=h-%d; land: 0,0" % (TILE // 2, TILE),
        "rozliseni": "1x (ZADANI-25 §10: rozliseni se NEMENI, bere se jen svetlo)",
        "svetlo": "1 smerove slunce + Fast-GI AO + kontaktni stin "
                  "(recept prevzaty z `artgen_common_2x`)",
        "2x_tile_px": ac2.TILE,
        "2x_render_px": ac2.RENDER,
        "pomer_geometrie_proti_2x": TILE / float(ac2.TILE),
    }


if __name__ == "__main__":
    raise SystemExit("artgen_common_lit.py je modul - nespousti se sam")
