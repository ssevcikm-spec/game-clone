# -*- coding: utf-8 -*-
"""artgen_common.py - kontrakt pilotu vlastniho artu (druha kolej, ZADANI-25).

Co je tenhle soubor: **jedno misto**, kde je popsan tvar vystupu pilotu -
kdo ho cte, nemusi hadat, jak je velka dlazdice, jak se pocita kotva ani jak
jsou poskladane stranky atlasu. Neni to dokumentace "jak to vypada", jsou to
hodnoty, ktere SKRIPTY pouzivaji (a ktere se overuji v `pack_atlas.py --check`).

KLICOVE ROZHODNUTI (a jejich duvod, vsechno merene, viz `MERENI.md`):

  * GEOMETRIE SE NEMENI (ZADANI-25 §3): dlazdice 44x44, kotvy jako UO.
    1 svetova jednotka = 1 dlazdice = 44 px. Vsechno se modeluje v techto
    jednotkach, takze "jak je predmet velky" je jedno cislo na jednom miste.

  * KOTVA (ox, oy) JE STEJNY VZOREC JAKO UO (`tools/uoextract/atlas.py:130`):
        item/anim:  ox = (w >> 1) - 22,  oy = h - 44
        land:       ox = 0,               oy = 0
    Tentyz vzorec znamena, ze se vlastni art nasadi do hry bez zmeny
    `render/chunk_renderer.gd` (ten od dlazdice odcita `offset` z manifestu).

  * kde je "zem" ve spritu: UO art to ma NEKONZISTENTNE (merge: u 4 pilotnich
    predmetu je obsah 2 az 19 px nad spodni hranou boxu, mereno 2026-10-10).
    Vlastni art to ma JEDNIM PRAVIDLEM: obsah ma pod sebou `GROUND_PX` px
    prazdna (kontaktni bod je presne `GROUND_PX` nad spodni hranou spritu).
    S vzorcem UO pak kontakt sedi na STRED diamantu dlazdice, ne na jeho
    predni roh - to je videt na kontaktnim listu.

  * `land` je 44x44 kosoctverec, ktery vyplnuje CELY box (mereno na UO
    `land_0.png`: kazda z 44 radku ma pixely, sirka roste 2 px/radek) - neni
    to 2:1 kosoctverec 44x22. Proto je kamera 45 stupnu: jednotkova ctvrtka
    se v ortho projekci promitne presne jako tento kosoctverec.

Pouceni z `E:\\Workspaces\\uo-shadows\\tools\\blender\\` (VZOR, ne kopie):
kamera + svetla + primitiva daji konzistentni sadu; postprocess musi odstranit
pozadi podle BARVY, ne podle jasu, a zmenšovat Lanczos.
"""
from __future__ import annotations

import json
from pathlib import Path

# --- stranky atlasu (stejne jako `assets/uo/manifest.json`) -----------------
PAGE = 2048
PAD = 1

# --- geometrie (NEMENI SE, ZADANI-25 §3) -----------------------------------
TILE = 44                     # px, strana dlazdice
GROUND_PX = 22                # kontaktni bod je 22 px nad spodni hranou spritu
ITEM_OFFSET = 0x4000          # art_id itemu = id + 0x4000 (docs/04)
TEXMAP_OFFSET = 0x10000

# --- render (ortho kamera) --------------------------------------------------
PX_PER_UNIT = 352             # px svetove jednotky v renderu = 8x koncovy px
RENDER = 512                  # px strana renderu; ortho_scale = RENDER/PX_PER_UNIT
CAM_AZIMUTH_DEG = 45.0        # smer pohledu: svet +X+Y (jihovychod)
SAMPLES = 64                  # EEVEE TAA vzorky (8x supersampling + 64 TAA)

# ⚠ ELEVACE JE ZMERENA, NE ZVOLENA (2026-10-10, `probe_projection.py`).
# UO projekce NENI pohled skutecne kamery: pudorys je "rotovany pudorys"
# (ctverec -> kosoctverec 1:1, 44x44 px) a vyska se pricitá vlastnim meritkem
# (`core/iso.gd`: ISO_STEP = 22 px na osu, Z_SCALE = 4 px na jednotku z).
# Zmereno na UO land artu: kosoctverec je 44x44 (1:1), ne 44x22 - rovina terenu
# tedy NENI zkracena, jak by ji zkratila kazda skutecna kamera.
#
# Dosahneme toho dvema korekcemi renderu (viz `na_uo_*` nize):
#   1) elevace 35.264 stupne (= atan(1/sqrt(2))) a svisle roztazeni 1/sin(elev)
#      = 1.7321 -> pudorys je presne 1:1 (kosoctverec 44x44) a soucasne
#      ZUSTAVA spravny pomer vysky: 1 jednotka vysky = 44 px (jako u UO).
#      Pri elevaci 45 stupnu by pudorys vysel 1:0.707 (44x31) a rozbil kontrakt.
#   2) ZRCADLENI VODOROVNE: kamera v azimutu 45 stupnu promita +X doleva-dolu,
#      UO ho ma doprava-dolu (`screen = ((x-y)*22, (x+y)*22)`). Zrcadleni je
#      presne to, co "ruka" kamery neumi - bez nej by byla cela sada zrcadlove
#      obracena (a na kosoctverci dlazdice to neni videt, proto se to meri).
CAM_ELEVATION_DEG = 35.26438968
MIRROR_X = True
VYSTRED_Y = 1.0 / __import__("math").sin(__import__("math").radians(CAM_ELEVATION_DEG))

# Vysledna projekce ve finale (1 jednotka = 1 dlazdice = 44 px artu) - TOTO je
# kontrakt, ktery `--check` overuje proti `core/iso.gd`:
#   +X -> (+22, +22) px   +Y -> (-22, +22) px   +Z -> (0, -44) px
# `probe_projection.py` to meri na vyrenderovanych znackach a `run_all.py` na
# tom ma branu (neshoda = cely art je otoceny jinam).
UO_OSY_PX = {"plusX": (22.0, 22.0), "plusY": (-22.0, 22.0), "plusZ": (0.0, -44.0)}

# --- co se vyrabi (ZADANI-25 §3) -------------------------------------------
# `uo_id` je ZAROVEN id, ktery nahrazujeme - diky tomu jde prepinat po kusech
# (`render/texture_cache.gd` klice (kind, id)) a kontaktni list porovnava
# tutez vec. `uo_content` je NAMERENY obsah (w, h) UO spritu v px (2026-10-10).
LAND = [
    {"name": "grass", "uo_id": 3, "uo_content": (44, 44)},
    {"name": "road", "uo_id": 1001, "uo_content": (44, 44)},
]

ITEMS = [
    # world_len = delka modelu ve svetovych jednotkach (1 jednotka = 44 px).
    # Cil = NAMERENY obsah UO artu, aby kontaktni list porovnaval stejne
    # velke veci (ne "neco proti necemu").
    {"name": "dagger", "uo_id": 3921, "uo_content": (11, 11), "world_len": 11 / 44,
     "popis": "dyka: cepel + zamek + rukojet + hlavice, lezi na zemi po diagonale"},
    {"name": "pickaxe", "uo_id": 3717, "uo_content": (26, 26), "world_len": 26 / 44,
     "popis": "krumpac: topurko + ocelovy nos, lezi na zemi po diagonale"},
    {"name": "ore", "uo_id": 6583, "uo_content": (30, 35), "world_len": 35 / 44,
     "popis": "ruda: 4 hroudy (deformovane krychle) na hromadce"},
    {"name": "ingot", "uo_id": 7151, "uo_content": (15, 15), "world_len": 15 / 44,
     "popis": "ingot: zkosena tyc (komoly) polozena na zemi"},
]

# --- postava: 5 smeru x 8 framu = 40 spritu (ZADANI-25 §3) ------------------
# Smerove poradi je UO konvence (render/anim_player.gd:34): sprite 0 = celni
# (svet SE), 1 = ctvrtpredni, 2 = profil, 3 = ctvrtzadni, 4 = zadni (svet NW).
# Zrcadleni 8 smeru hry na techto 5 je HOTOVE v `anim_player.gd DIR_MAP`
# a NEMENI SE - vyrabime stejnych 5 canonical smeru jako UO.
CHAR = {
    "body": 400,              # telo hry (anim.mul id); vlastni art ho nahradi
    "action_walk": 0,         # 0 = walk (anim_player.gd ACTION_GROUP)
    "dirs": 5,
    "frames": 8,
    "world_h": 1.2,           # vyska MODELU v jednotkach (kvuli zaberu kamery)
    # NAMERENO 2026-10-10 na UO exportu `assets/uo/anim/anim-400-0-*.png`:
    # obsah framu ma vysku 56..64 px (median 60), sirku 18..40 px (median 25).
    # Cilime na median 60 px - proto se postava v postprocessu zmensuje na 60 px
    # a jeji skutecna velikost vuci dlazdici vyjde 60/44 = 1.36 jednotky.
    "cil_obsah_px": 60,
    "uo_content": (25, 60),
    "frame_ms": 80,           # docs/05 §5.1.1
}
CHAR_CONTENT_PX = round(CHAR["world_h"] * TILE)     # jen orientacni (cil je cil_obsah_px)


def ofsahy(kind: str, w: int, h: int) -> tuple[int, int]:
    """(ox, oy) presne jako `tools/uoextract/atlas.py:130` - jedina kotva pilotu."""
    if kind in ("land", "texmap"):
        return (0, 0)
    return ((w >> 1) - TILE // 2, h - TILE)


# --- korekce renderu na UO projekci (jedno misto pro obrazek i pro bod) -----
def na_uo_bod(x: float, y: float, sirka: int = None) -> tuple[float, float]:
    """Pixel v renderu -> pixel po korekci (zrcadleni + svisle roztazeni).

    Pro PROCESNI BOD plati posun pixelovych stredu: `(y + 0.5) * k - 0.5`
    (presne to dela `PIL.Image.resize`). Kdyby se to pocitalo bez tech 0.5,
    kotva by ujela o (k-1)/2 = 0.37 px - male, ale zbytecne.
    """
    sirka = RENDER if sirka is None else sirka
    if MIRROR_X:
        x = (sirka - 1) - x
    return (x, (y + 0.5) * VYSTRED_Y - 0.5)


def na_uo_delta(dx: float, dy: float) -> tuple[float, float]:
    """Rozdil dvou bodu (bez posunu stredu) - jen zrcadleni a roztazeni."""
    return ((-dx if MIRROR_X else dx), dy * VYSTRED_Y)


def na_uo_velikost(vyska: int) -> int:
    """Vyska obrazku po svislem roztazeni."""
    return int(round(vyska * VYSTRED_Y))


def jednotky_na_px(jednotky: float) -> float:
    """Svetove jednotky -> px ve FINALNI sprite (1 jednotka = 44 px pudy, 44 px vysky)."""
    return jednotky * TILE


def anim_id(direction: int, frame: int, body: int = None, action: int = None) -> int:
    """id spritu animace v manifestu: `body*1000 + action*100 + dir*10 + frame`.

    Duvod pro cislo: manifest ma (stejne jako UO) jen 10 klicu, z nichz `id` je
    cislo - a animace potrebuje trojici (telo, akce, smer). Rozbaleni je
    `anim_parts()`, aby se nikde neopisovalo zvlast.
    """
    body = CHAR["body"] if body is None else body
    action = CHAR["action_walk"] if action is None else action
    return body * 1000 + action * 100 + direction * 10 + frame


def anim_parts(ident: int) -> tuple[int, int, int, int]:
    """(body, action, dir, frame) z `anim_id`."""
    return (ident // 1000, (ident // 100) % 10, (ident // 10) % 10, ident % 10)


def anim_key(direction: int, frame: int) -> str:
    """Klic pro `anim-sheets.json` ve TVARU UO (`assets/uo/anim/anim-sheets.json`)."""
    return f"{CHAR['body']}/{CHAR['action_walk']}/{direction}" if frame == 0 else ""


def rozloz(rady: list[tuple], page: int = PAGE, pad: int = PAD) -> list[tuple]:
    """Shelf-pack SE STEJNYM RAZENIM jako `atlas.py:133` (determinismus).

    `rady` jsou (kind, id, w, h); vraci (kind, id, stranka, x, y). Razeni
    `(-h, w, kind, id)` znamena, ze poradi vstupu nehraje roli.
    """
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


def zapis_manifest(cesta: Path, data: dict) -> None:
    """Zapis manifestu ve tvaru UO: `sort_keys`, indent 1, LF, UTF-8."""
    Path(cesta).write_text(
        json.dumps(data, ensure_ascii=False, sort_keys=True, indent=1) + "\n",
        encoding="utf-8", newline="\n")


def uo_manifest(cesta: Path = None) -> dict:
    """Precte `assets/uo/manifest.json` (POUZE CTENI - je to data z instalace UO)."""
    cesta = Path(cesta) if cesta else Path("assets/uo/manifest.json")
    return json.loads(cesta.read_text(encoding="utf-8"))


def uo_sprite(manifest: dict, kind: str, ident: int) -> dict | None:
    """Zaznam spritu z UO manifestu (nebo None - nikdy ticha nula)."""
    for s in manifest["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return s
    return None
