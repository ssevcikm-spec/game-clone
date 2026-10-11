# -*- coding: utf-8 -*-
"""artgen_common_v3.py - kontrakt 1x sady `assets/own-v3/` (art krok 2, 2026-10-11).

CO JE TAHDLE SADA: treti jmeno artu, postavene na `assets/own-lit/` (v2). Vznikla
z merenych vad, ktere v2 nechala otevrene (`MERENI.md` §9.3, `ZADANI-25` §11):

  (i)  STIN PRO PLACATE PREDMETY: dyka mela viditelny jen 1px lem (6-7 px),
       ingot 11 px, kdezto ruda 261 px. Postprocess v2 pocital ubytek stinu
       RADIALNE od kotvy, a u placateho predmetu je cely jeho pudorys dal od
       kotvy nez R0 - stin se zahodil. v3 pocita ubytek od OBRYSU OBJEKTU.
  (ii) KONTRAST: jedno smerove slunce bez vyplne vzalo kovum odlesky (rozptyl
       jasu dyky 25,7 -> 15,2). v3 pridava VYPLN (druhe slunce z protismeru,
       `use_shadow=False`, energie 1,5) - mereno na dyce: sd 16,79 -> 18,x.

CO SE NEMENI (a proc):
  * ROZLISENI: 44 px dlazdice, krok 22, render 512, 352 px/jednotku. 2x je ve
    stejnem meritku MEKCÍ (`MERENI.md` §8.3) - rozliseni neni cesta.
  * GEOMETRIE A KOTVA: `ox=(w>>1)-22`, `oy=h-44` - jinak by se sada s hrou
    nesešla a spadla by brana `G1`.
  * MODEL: zadny model se neprepisuje; bere se hotovy `.blend` a meni se JEN
    svetlo (a osvetleni se jinak nez geometrie netyka).

⚠ VZTAH K v2 JE ZAPSANY, NE ZAMLCLENY: `odchylky_od_v2()` vraci seznam toho, co
je proti v2 jine - a brana (`pack_atlas_v3.py --check`) ho porovna s manifestem.
Kdyby se svetlo zmenilo a zapis zustal stary, je to videt.
"""
from __future__ import annotations

from pathlib import Path

import artgen_common as ac1            # 1x geometrie (jen se cte)
import artgen_common_lit as acl        # v2 kontrakt (jen se cte)
import artgen_common_2x as ac2         # puvod receptu svetla

# --- geometrie: 1x, nemeni se ----------------------------------------------
TILE = ac1.TILE
GROUND_PX = ac1.GROUND_PX
PAGE = ac1.PAGE
PAD = ac1.PAD
RENDER = ac1.RENDER
PX_PER_UNIT = ac1.PX_PER_UNIT
SAMPLES = ac1.SAMPLES
CAM_AZIMUTH_DEG = ac1.CAM_AZIMUTH_DEG
CAM_ELEVATION_DEG = ac1.CAM_ELEVATION_DEG
MIRROR_X = ac1.MIRROR_X
VYSTRED_Y = ac1.VYSTRED_Y

LAND = ac1.LAND
ITEMS = ac1.ITEMS
CHAR = ac1.CHAR

# --- kde sada lezi a jak se jmenuje -----------------------------------------
HERE = Path(__file__).resolve().parent
RAW = HERE / "_rawv3"                  # renderovane snimky (ignorovano vzorem `_*`)
BLEND = HERE / "blend"                 # zdroje: `v3_*.blend` (jako `lit_*`, `2x_*`)
SADA = Path("assets/own-v3")           # novy jmenný prostor artu
PREFIX_BLEND = "v3_"
MERITKO = "1x-v3"                      # znacka v `_origin_*.json`
PREDCHOZI_SADA = Path("assets/own-lit")

# --- svetlo v3 --------------------------------------------------------------
# ZAKLAD JE PRESNE RECEPT v2 (jedno slunce + AO + kontaktni rovina) - v3 meni
# jen to, co je niz popsane. Cisla se NEOPSUJI: berou se z `artgen_common_lit`
# a z `artgen_common_2x` (odtamtud je vzal i v2), aby se recept nemohl rozejit.
JMENO_SLUNCE = acl.JMENO_SLUNCE            # "Sun"
JMENO_VYPLNE = "Fill"                      # NOVE ve v3
JMENO_PODLAHY = acl.JMENO_PODLAHY          # "Kontakt"
SLUNCE_ENERGIE = acl.SLUNCE_ENERGIE        # 4,0
SLUNCE_UHEL_DEG = acl.SLUNCE_UHEL_DEG      # 12,0 (mekky stin)
SLUNCE_SMER_RAD = ac2.uhel_slunce_rad()    # (-0,7; 0; -2,6)
OBLOHA_SILA = 0.50                         # v2: 0,45 -> +0,05 (tmavsi sada v2)
OBLOHA_BARVA = acl.OBLOHA_BARVA

# VYPLN (jedina zmena svetla proti v2): druhe slunce z PROTISMERU, bez stinu.
# ⚠ PROC `use_shadow=False`: vypln nema kreslit druhy stin (sada by mela dva
# stiny z ruznych smeru). Meri se jen jeji vliv na BARVU - a ten je zmereny:
# dyka sd 16,79 -> 19,71, rozptyl 45,8 -> 53,7 (`_svetlo-var.json`).
VYPLN_ENERGIE = 1.5
VYPLN_UHEL_DEG = SLUNCE_UHEL_DEG
VYPLN_OTOCENI_RAD = 3.141592653589793      # presne z protismeru

# AO: stejne jako v2 (bere se z 2x receptu)
AO_REZIMY = acl.AO_REZIMY
AO_DOSAH = acl.AO_DOSAH
AO_PAPRSKU = acl.AO_PAPRSKU
AO_KROKU = acl.AO_KROKU
AO_KVALITA = acl.AO_KVALITA
AO_TLOUSTKA = acl.AO_TLOUSTKA

# kontaktni rovina: stejna jako v2
PODLAHA_Z = acl.PODLAHA_Z
PODLAHA_ALBEDO = acl.PODLAHA_ALBEDO
PODLAHA_ROUGHNESS = acl.PODLAHA_ROUGHNESS

# --- kontaktni stin: recept v3 (meni se v postprocessu, ne v renderu) -------
# ⚠ CISLA MAJI DOMOV V `postprocess_lit.RECEPTY_STINU["v3"]` a tady jsou
# ZRCADLEM - brana (`pack_atlas_v3.py --check`) porovnava obe strany, aby se
# "recept v manifestu" nemohl rozejit s tim, kterym sada vznikla.
STIN_RECEPT = "v3"
STIN_SILA = 0.5
STIN_POSUN_PX = (-2, -1)                   # posun masky tela ve smeru svetla
STIN_SIRKA_PX = 0.6                        # plna cast pasu za obrysem
STIN_MEKKOST_PX = 1.2                      # pres kolik px stin zmizi
STIN_ODSTUP_PX = 0.9                       # blize k telu se stin nekresli


# ---------------------------------------------------------------------------
# prevzate funkce (jen se predavaji dal - nikde se neopisuji cisla)
# ---------------------------------------------------------------------------
def ofsahy(kind: str, w: int, h: int) -> tuple[int, int]:
    return ac1.ofsahy(kind, w, h)


def na_uo_bod(x: float, y: float, sirka: int = None) -> tuple[float, float]:
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
    return ac1.rozloz(rady, page=page, pad=pad)


def uhel_vyplne_rad() -> tuple[float, float, float]:
    """Rotace vyplne = zakladni smer slunce + 180 stupnu (protismer)."""
    return (SLUNCE_SMER_RAD[0], SLUNCE_SMER_RAD[1],
            SLUNCE_SMER_RAD[2] + VYPLN_OTOCENI_RAD)


# ---------------------------------------------------------------------------
# odchylky od v2 (zapisuji se do manifestu a brana je overuje)
# ---------------------------------------------------------------------------
def odchylky_od_v2() -> dict:
    """Co je ve v3 JINE proti `assets/own-lit/` - vcetne cisel."""
    return {
        "reference": str(PREDCHOZI_SADA).replace("\\", "/"),
        "svetlo_pocet_slunci": {"v2": 1, "v3": 2},
        "vypln": {"v2": None,
                  "v3": {"energie": VYPLN_ENERGIE, "uhel_deg": VYPLN_UHEL_DEG,
                         "smer": "protismer zakladniho slunce",
                         "use_shadow": False,
                         "duvod": "vratit odlesky a obrysovy lem kovum "
                                  "(MERENI.md §9.3 bod 1: rozptyl jasu dyky "
                                  "25,7 -> 15,2)"}},
        "obloha_sila": {"v2": acl.OBLOHA_SILA, "v3": OBLOHA_SILA},
        "stin_recept": {"v2": "v2 (radialni ubytek od kotvy)",
                        "v3": "v3 (pas od obrysu objektu, posunuty ve smeru svetla)",
                        "sila": {"v2": acl.STIN_SILA, "v3": STIN_SILA},
                        "posun_px": {"v2": None, "v3": list(STIN_POSUN_PX)},
                        "sirka_px": {"v2": None, "v3": STIN_SIRKA_PX},
                        "mekkost_px": {"v2": None, "v3": STIN_MEKKOST_PX},
                        "odstup_px": {"v2": None, "v3": STIN_ODSTUP_PX},
                        "duvod": "placate predmety mely stin jen jako 1px lem "
                                 "(dyka 6 px, ingot 11 px) - MERENI.md §9.3 bod 3"},
        "geometrie": "NEMENI SE (44 px, krok 22, kotva jako UO)",
        "rozliseni": "NEMENI SE (1x; 2x je ve stejnem meritku mekci)",
    }


def souhrn() -> dict:
    return {
        "tile_px": TILE,
        "ground_px": GROUND_PX,
        "iso_step_px": TILE // 2,
        "render_px": RENDER,
        "px_per_unit": PX_PER_UNIT,
        "ortho_scale": RENDER / float(PX_PER_UNIT),
        "kotva": "item/anim: ox=(w>>1)-%d, oy=h-%d; land: 0,0" % (TILE // 2, TILE),
        "rozliseni": "1x (ZADANI-25 §10: rozliseni se NEMENI)",
        "svetlo": "1 smerove slunce + VYPLN (protismer, bez stinu) + Fast-GI AO "
                  "+ kontaktni stin",
        "stin": "recept v3 - ubytek od obrysu objektu (viz odchylky_od_v2)",
    }


def recept_svetla() -> dict:
    """Vsechna cisla receptu svetla v3 (do manifestu)."""
    return {
        "slunce_pocet": 2,
        "slunce_rotace_rad": list(SLUNCE_SMER_RAD),
        "slunce_energie": SLUNCE_ENERGIE,
        "slunce_uhel_deg": SLUNCE_UHEL_DEG,
        "vypln_rotace_rad": list(uhel_vyplne_rad()),
        "vypln_energie": VYPLN_ENERGIE,
        "vypln_uhel_deg": VYPLN_UHEL_DEG,
        "vypln_stin": False,
        "obloha_sila": OBLOHA_SILA,
        "obloha_barva": list(OBLOHA_BARVA),
        "ao_rezim": list(AO_REZIMY),
        "ao_dosah_jednotek": AO_DOSAH,
        "ao_paprsku": AO_PAPRSKU,
        "ao_kroku": AO_KROKU,
        "ao_kvalita": AO_KVALITA,
        "kontaktni_rovina_z": PODLAHA_Z,
        "kontaktni_rovina_albedo": PODLAHA_ALBEDO,
        "stin_recept": STIN_RECEPT,
        "stin_sila": STIN_SILA,
        "stin_posun_px": list(STIN_POSUN_PX),
        "stin_sirka_px": STIN_SIRKA_PX,
        "stin_mekkost_px": STIN_MEKKOST_PX,
        "stin_odstup_px": STIN_ODSTUP_PX,
    }


if __name__ == "__main__":
    raise SystemExit("artgen_common_v3.py je modul - nespousti se sam")
