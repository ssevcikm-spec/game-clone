#!/usr/bin/env python3
"""G10 check-render - vizualni korektnost MERENA (docs/08 §8.2, §8.3).

NamEReno v zadani: hrac nebyl na obrazovce (dlazdice mely vyssi z_index)
a pritom byly testy, schema i assety zelene. Proto se "je videt postava"
meri v PIXELECH, ne dojmem.

Brana meri na snimku:
  * snimek jde nacist a neni jednolity (jednolita barva = nic se nevykreslilo),
  * v ocekavane oblasti (stred, nebo --focus) jsou nenulove pixely - to je
    "postava neni prekryta" v meritelne podobe,
  * pocet barev a podil pozadi (pro lidskou kontrolu v logu).

Bez `render/` kodu nebo bez snimku je vysledek NEMERENO - nikdy zelena.

Spousteni:
  python tools/gates/check-render.py [--root .] [--snapshot cesta.png] [--focus x,y,w,h]
  python tools/gates/check-render.py --self-test
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, selftest_cli  # noqa: E402

NAME = "check-render"
DEFAULT_SNAPSHOT = ".cache/render/snapshot.png"
# STALOST SNIMKU (doplneno 2026-10-12): `run-all.py` snimek NEGENERUJE - cte, co
# je na disku. NamEReno: 12. 10. 2026 byl `.cache/render/snapshot.png` z 10:06,
# ale `assets/stone-path/` (nova cesta v Britainu) vznikl ve 23:00 - G10 tedy
# merila obraz, ktery uz ve hre nebyl, a tvarila se zelene. Vstup obrazu, ktery
# je NOVEJSI nez snimek, je proto VADA: ma se vygenerovat snimek znovu
# (`tools/gates/ci-godot.sh`, nebo `--write-movie`, viz HANDOFF).
# Tolerantni okno je 2 s: soubory zapsane v temz behu maji casy blizko sebe a
# "rozdil 0,3 s" nic neznamena.
STARI_TOLERANCE_S = 2.0
RENDER_GRAINS = ("render.chunk", "render.sort")
# Data, bez kterych se nema co vykreslit (assets/uo/ je v .gitignore, takze
# v cerstvem klonu nejsou). Chybejici DATA nejsou vada kódu - viz check().
ASSET_INPUTS = ("manifest.json", "world/map0.meta.json", "world/map0.land",
                "world/map0.statics.bin")
# KUZE: přesná shoda s PALETOU sady barvy kůže (granule render.hue). Sada se
# bere z `assets/uo/hues.json` (index `HUE_SKIN`), ne z opsaných čísel: pixel
# se počítá, jen když je jeho barva **přesně** některá z 32 barev sady. Tím se
# G10 nemůže splést s hnědými dlaždicemi mapy (naměřeno: klín „R−B > 15" má
# v okolí středu 43 523 px a zahrnuje i mapu, kdežto shoda s paletou je řádově
# nižší a pochází z postavy).
KUZE_MIN = 500
HUE_SKIN_DEFAULT = 1002      # pouzije se, jen kdyz se neda precist z granule
# --- VLASTNI ART (rebaseline 2026-10-11) ----------------------------------
# Do teto chvile G10 pozadovala, aby mel stred snimku pixely z UO palety kuze -
# to je kontrola tonovani hue. Vlastni postava se hue NETONUJE (barvu ma
# z Blenderu, `app.world_view` ji preskakuje), takze by ta kontrola hlasila
# vadu o SPRAVNEM obrazu. Rebaseline proto pridal DRUHOU, rovnocennou moznost:
# pocet pixelu, ktere presne odpovidaji barvam VLASTNIHO spritu postavy.
#
# Cisla jsou namERena na dvojici snimku TEHOZ mista (Britain 1495,1630,
# 1280x720, chuze), `own-art.png` vs `snapshot-uo.png`:
#   stred 1/3, surova shoda:  vlastni 748 / UO 235  (mapa a dalsi art se do
#                             "surove" shody pletou - pomer jen 3,2x)
#   stred 1/3, PO EROZI:      vlastni 138 / UO   0  (eroze 3x3 zahodi
#                             roztrousene pixely mapy; oddeleni je ciste)
# Hranice je proto 60 pixelu po erozi - mezi znamym spravnym (138) a znamym
# chybnym (0) pripadem. Kontrola vypsuje OBE cisla, aby byl videt odstup.
VLASTNI_MIN = 60
OWN_CONFIG = "assets/own-art.json"


def hue_skin(root: Path) -> int:
    """Index sady barvy kůže z granule `render/hue_cache.gd` (ne opsaný)."""
    zdroj = root / "render" / "hue_cache.gd"
    if zdroj.exists():
        match = re.search(r"^const HUE_SKIN: int = (\d+)", zdroj.read_text(encoding="utf-8"),
                          re.MULTILINE)
        if match:
            return int(match.group(1))
    return HUE_SKIN_DEFAULT


def kuze_paleta(root: Path, hue: int) -> list[tuple[int, int, int]]:
    """32 barev sady barvy kůže z `assets/uo/hues.json` (5 -> 8 bitu jako hra)."""
    cesta = root / "assets" / "uo" / "hues.json"
    if not cesta.exists():
        return []
    try:
        data = json.loads(cesta.read_text(encoding="utf-8"))
        barvy = data["sets"][hue - 1]["colors"]
    except Exception:
        return []
    tabulka = [0, 8, 16, 24, 32, 41, 49, 57, 65, 74, 82, 90, 98, 106, 115, 123,
               131, 139, 148, 156, 164, 172, 180, 189, 197, 205, 213, 222, 230,
               238, 246, 255]      # ClassicUO HuesHelper._table (viz render/hue_cache.gd)
    return [(tabulka[(int(c) >> 10) & 0x1F], tabulka[(int(c) >> 5) & 0x1F],
             tabulka[int(c) & 0x1F]) for c in barvy]


def kuzne_pixely(array, paleta: list[tuple[int, int, int]],
                 stred: bool = True) -> tuple[int, list[int]]:
    """Počet pixelů, jejichž barva JE v paletě kůže, a jejich průměrná barva."""
    import numpy as np

    h, w, _ = array.shape
    if stred:
        x, y = w // 3, h // 3
        array = array[y:y + h // 3, x:x + w // 3]
    mask = np.zeros(array.shape[:2], dtype=bool)
    for (r, g, b) in paleta:
        mask |= ((array[:, :, 0] == r) & (array[:, :, 1] == g) & (array[:, :, 2] == b))
    pocet = int(mask.sum())
    if pocet == 0:
        return 0, []
    prumer = [int(array[:, :, i][mask].mean()) for i in range(3)]
    return pocet, prumer


def vlastni_paleta(root: Path) -> list[tuple[int, int, int]]:
    """Barvy VLASTNI postavy z anim listu vrstvy z `assets/own-art.json`.

    Bere se z PNG, ktera hra opravdu kresli (ne z konstanty): kdyby se sada
    pregenerovala, kontrola se stane sama. Kdyz vlastni animace nejsou, vraci
    prazdno a G10 se chova jako pred rebaselinem (vyzaduje UO paletu kuze).
    """
    cesta = root / OWN_CONFIG
    if not cesta.exists():
        return []
    try:
        import numpy as np
        from PIL import Image
    except Exception:
        return []
    try:
        cfg = json.loads(cesta.read_text(encoding="utf-8"))
    except Exception:
        return []
    barvy: set[tuple[int, int, int]] = set()
    for vrstva in cfg.get("layers", []):
        if not isinstance(vrstva, dict):
            continue
        anim = str(vrstva.get("anim") or "")
        if anim == "":
            continue
        anim_cesta = root / anim.replace("res://", "")
        if not anim_cesta.exists():
            continue
        try:
            data = json.loads(anim_cesta.read_text(encoding="utf-8"))
        except Exception:
            continue
        zaklad = anim_cesta.parent
        for zaznam in data.get("sprites", {}).values():
            subor = str(zaznam.get("file", ""))
            if subor == "":
                continue
            png = zaklad / subor
            if not png.exists():
                continue
            with Image.open(png) as img:
                px = np.asarray(img.convert("RGBA"))
            mask = px[:, :, 3] > 200      # polopruhledne okraje se nepocitaji
            for r, g, b in zip(px[:, :, 0][mask], px[:, :, 1][mask], px[:, :, 2][mask]):
                barvy.add((int(r), int(g), int(b)))
    return sorted(barvy)


def vlastni_pixely(array, paleta: list[tuple[int, int, int]]) -> tuple[int, int]:
    """(surove, po erozi) pixely presne ve barve vlastni postavy.

    Eroze 3x3 je tu proto, ze roztrousene pixely mapy se do surove shody pletou
    (namEReno: 235 px na snimku bez vlastniho artu); souvisla silueta postavy
    erozi prezije a rozptyl zmizi (0 px).
    """
    import numpy as np

    mask = np.zeros(array.shape[:2], dtype=bool)
    for (r, g, b) in paleta:
        mask |= ((array[:, :, 0] == r) & (array[:, :, 1] == g) & (array[:, :, 2] == b))
    surove = int(mask.sum())
    if surove == 0:
        return 0, 0
    eroze = (mask & np.roll(mask, 1, 0) & np.roll(mask, -1, 0)
             & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    # `np.roll` obalí i okraje - ty se po erozi nesmi pocitat.
    eroze[0, :] = False
    eroze[-1, :] = False
    eroze[:, 0] = False
    eroze[:, -1] = False
    return surove, int(eroze.sum())


def missing_assets(root: Path) -> list[str]:
    base = root / "assets" / "uo"
    return [name for name in ASSET_INPUTS if not (base / name).exists()]


def render_sources(root: Path) -> list[Path]:
    base = root / "render"
    return sorted(p for p in base.rglob("*.gd")) if base.is_dir() else []


def measure_image(path: Path, focus: tuple[int, int, int, int] | None, gate: Gate,
                  paleta: list[tuple[int, int, int]] | None = None,
                  vyzaduj_kuzi: bool = False,
                  vlastni: list[tuple[int, int, int]] | None = None,
                  vyzaduj_vlastni: bool = False) -> None:
    try:
        import numpy as np
        from PIL import Image
    except Exception as exc:
        gate.skip(f"Pillow/numpy nejsou k dispozici ({exc}) - snímek NEMĚŘEN")
        return
    try:
        with Image.open(path) as img:
            rgb = img.convert("RGB")
            gate.measure("snimek", f"{path.name} {rgb.width}x{rgb.height}")
            array = np.asarray(rgb)
    except Exception as exc:
        gate.error(f"snímek {path} nelze přečíst ({exc})")
        return

    colors, counts = np.unique(array.reshape(-1, 3), axis=0, return_counts=True)
    gate.measure("barev", int(colors.shape[0]))
    if colors.shape[0] <= 1:
        gate.error("snímek je jednolitý - nic se nevykreslilo (docs/08 §8.3)")
        return

    # pozadi = NEJCASTSI barva, ne pixel (0,0): jinak se za pozadi prohlasi
    # rohova postava a "nenulove pixely" vyjdou i tam, kde nic neni (namEReno
    # v self-testu pripadu vadny_postava_mimo).
    background = colors[int(np.argmax(counts))]
    differs = np.any(array != background, axis=2)
    gate.measure("pixelu_mimo_pozadi", int(differs.sum()))

    x, y, w, h = focus or (array.shape[1] // 3, array.shape[0] // 3,
                           max(1, array.shape[1] // 3), max(1, array.shape[0] // 3))
    region = differs[y:y + h, x:x + w]
    inside = int(region.sum())
    gate.measure("oblast", f"{x},{y},{w},{h}")
    gate.measure("pixelu_v_oblasti", inside)
    if inside == 0:
        gate.error(
            f"v očekávané oblasti {x},{y},{w},{h} není žádný nenulový pixel - "
            "postava je překrytá nebo se nevykreslila (docs/08 G10)"
        )

    # KUZE (render.hue): pixel, jehoz barva JE v palete sady barvy kuze. Sediva
    # postava (bez hue) nema v palete ANI JEDEN pixel; hnede dlazdice mapy sice
    # "hnede jsou", ale na konkretni barvy sady se netrefi (proto se nehleda
    # "R-B > 15", ale presna shoda - jinak by se do cisla pocitala i mapa).
    if paleta:
        pocet, prumer = kuzne_pixely(array, paleta)
    else:
        pocet, prumer = 0, []
    gate.measure("kuze_pixelu", pocet)
    gate.measure("kuze_barva", "R%d G%d B%d" % tuple(prumer) if prumer else "zadna")
    if vyzaduj_kuzi and pocet < KUZE_MIN:
        gate.error(
            f"v okoli stredu je {pocet} pixelu z palety barvy kuze (ocekavano aspon "
            f"{KUZE_MIN}) - postava je SEDA, tonovani hue se neprojevilo (docs/08 G10)"
        )

    # VLASTNI POSTAVA (rebaseline 2026-10-11): kdyz je vlastni art zapnuty,
    # meri se misto UO palety kuze shoda s barvami vlastniho spritu.
    if vlastni:
        surove, eroze = vlastni_pixely(array[y:y + h, x:x + w], vlastni)
        gate.measure("vlastni_pixelu", surove)
        gate.measure("vlastni_pixelu_po_erozi", eroze)
        if vyzaduj_vlastni and eroze < VLASTNI_MIN:
            gate.error(
                f"ve stredni oblasti je {eroze} pixelu vlastni postavy po erozi "
                f"(ocekavano aspon {VLASTNI_MIN}; surove {surove}) - vlastni sprite "
                "postavy se nekresli (nebo se kresli UO art)"
            )


def art_inputs(root: Path) -> list[Path]:
    """Vstupy, ktere MENI obraz: konfigurace vlastniho artu, vsechno, na co
    odkazuje (manifest, anim list, cely adresar vrstvy = atlas PNG), a UO art.

    Proc cely adresar: atlas se prepece, i kdyz cesta v manifestu zustane stejna
    (presne to se stalo 11. 10. 2026 - `assets/cobble/atlas/land_0.png` byl
    prepsany sondou a manifest dal tvrdil neco jineho)."""
    out: list[Path] = []
    cfg = root / OWN_CONFIG
    if cfg.exists():
        out.append(cfg)
        try:
            data = json.loads(cfg.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        for vrstva in data.get("layers", []):
            if not isinstance(vrstva, dict):
                continue
            for klic in ("manifest", "anim"):
                rel = str(vrstva.get(klic) or "").replace("res://", "")
                if rel == "":
                    continue
                p = root / rel
                if p.exists():
                    out.append(p)
            rel = str(vrstva.get("manifest") or "").replace("res://", "")
            if rel:
                slozka = (root / rel).parent
                if slozka.is_dir():
                    out.extend(f for f in slozka.rglob("*") if f.is_file())
    uo = root / "assets" / "uo"
    if uo.is_dir():
        out.extend(f for f in uo.rglob("*") if f.is_file())
    return out


def kod_obrazu(root: Path) -> list[Path]:
    """Kod, ktery MUZE zmenit obraz (kreslici uzel a jeho zapojeni).

    Neni to VADA, kdyz je novejsi nez snimek - kod se meni casto a obraz menit
    nemusi. Je to POZNAMKA: "snimek muze byt ze starsiho obrazu, vygeneruj ho".
    (Rozdil je schvalny: art je dukaz, kod je okolnost.)"""
    out: list[Path] = []
    render = root / "render"
    if render.is_dir():
        out.extend(p for p in render.rglob("*.gd") if p.is_file())
    for rel in ("app/world_view.gd", "app/main.gd"):
        p = root / rel
        if p.exists():
            out.append(p)
    return out


def check_stalost(root: Path, snapshot: Path, gate: Gate) -> None:
    """Snimek musi byt NOVEJSI nez vstupy obrazu - jinak meri jiny obraz."""
    if not snapshot.exists():
        return
    cas_snimku = snapshot.stat().st_mtime
    gate.measure("snimek_stari_h", round((time.time() - cas_snimku) / 3600.0, 2))
    vstupy = art_inputs(root)
    if not vstupy:
        return
    nej = max(vstupy, key=lambda f: f.stat().st_mtime)
    gate.measure("art_nejnovejsi", nej.relative_to(root).as_posix())
    pozdejsi = [f for f in vstupy if f.stat().st_mtime > cas_snimku + STARI_TOLERANCE_S]
    if pozdejsi:
        jmena = sorted({f.relative_to(root).as_posix() for f in pozdejsi})
        gate.error(
            f"snímek {snapshot.name} je STARŠÍ než {len(pozdejsi)} vstupů obrazu "
            f"(např. {', '.join(jmena[:3])}) - G10 by měřila obraz, který už ve hře "
            "není; vygeneruj snímek znovu (tools/gates/ci-godot.sh)"
        )
    kod = [f for f in kod_obrazu(root) if f.stat().st_mtime > cas_snimku + STARI_TOLERANCE_S]
    if kod:
        jmena = sorted({f.relative_to(root).as_posix() for f in kod})
        gate.note(
            f"snímek je starší než kód kreslení ({len(kod)} souborů, např. "
            f"{', '.join(jmena[:2])}) - obraz se mohl změnit; vygeneruj snímek znovu "
            "(tools/gates/ci-godot.sh)"
        )


def check(root: Path, gate: Gate, snapshot: Path | None = None,
          focus: tuple[int, int, int, int] | None = None) -> None:
    sources = render_sources(root)
    gate.measure("render_souboru", len(sources))
    if not sources:
        gate.pending(
            "render/ neobsahuje žádný .gd - není co vykreslovat; čeká se na "
            + ", ".join(RENDER_GRAINS) + " (W1/W3)"
        )
        return
    chybi = missing_assets(root)
    if chybi:
        # NamEReno 2026-10-06 v simulaci cerstveho klonu: bez assets/uo se
        # vykresli JEDINA barva (77,77,77) a brana na tom hlasila VADA. To je
        # vada prostredi (chybeji DATA), ne kódu - v CI assety nikdy nejsou
        # (docs/08 §8.4). NEMERENO neni zelena a je videt v souhrnu.
        gate.pending(
            "chybí data pro vykreslení (assets/uo: " + ", ".join(chybi) + ") - "
            "v tomto klonu nejsou extrahovaná data UO, snímek by měřil jen barvu "
            "pozadí; NEMĚŘENO (spusť tools/uoextract/worldmap.py --extract)"
        )
        return
    path = snapshot or (root / DEFAULT_SNAPSHOT)
    if not path.exists():
        gate.pending(f"snímek {path} není - G10 měří pixely, bez snímku NEMĚŘENO")
        return
    # STALOST: plati JEN pro vychozi snimek hry. Cizi snimek (`--snapshot`) je
    # merici vstup pro A/B - u nej se stari neposuzuje (neni to obraz hry).
    if snapshot is None:
        check_stalost(root, path, gate)
    # KUZE: pro VYCHOZI snimek (ten z behu hry) se barva kuze VYZADUJE; kdyz
    # nekdo preda jiny snimek (--snapshot), jen se to ZMERI - brana nesmi tvrdit
    # vadu o obrazku, ktery nema postavu hrace.
    hue = hue_skin(root)
    paleta = kuze_paleta(root, hue)
    if not paleta:
        gate.skip(f"paleta barvy kuze (hues.json, sada {hue}) neni - barvu NEMERIM")
        return
    # VLASTNI ART: kdyz je zapnuty, postava se hue NETONUJE, takze se misto
    # UO palety kuze vyzaduje shoda s barvami VLASTNIHO spritu. Obě cisla se
    # vzdy vypisuji, aby byl videt odstup (rebaseline s dokladem, ne "spraveno").
    vlastni = vlastni_paleta(root)
    gate.measure("vlastni_paleta_barev", len(vlastni))
    gate.measure("kuze_paleta_barev", len(paleta))
    if snapshot is None:
        measure_image(path, focus, gate, paleta, vyzaduj_kuzi=not vlastni,
                      vlastni=vlastni or None, vyzaduj_vlastni=bool(vlastni))
    else:
        # Cizi snimek: brana o nem nesmi tvrdit vadu (nema hrace hry).
        measure_image(path, focus, gate, paleta, vlastni=vlastni or None)


def selftest() -> int:
    import os
    import shutil

    try:
        import numpy as np
        from PIL import Image
    except Exception:
        print(f"[{NAME}] self-test: Pillow/numpy není k dispozici, test NEPROBĚHL")
        return NEMERENO

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-render"
    shutil.rmtree(base, ignore_errors=True)

    # Fixture musi mit i `hues.json` a `render/hue_cache.gd` s `HUE_SKIN` -
    # jinak by brana paletu nenasla a barvu by VUBEC NEMERILA (a to by v self-testu
    # vypadalo jako "proslo": NEMERENO neni zelena, ale tady by se ztratilo).
    hue = 1002
    barvy_5bit = [1, 1, 1058, 2114, 3139, 4196, 5252, 6309, 7334, 8390, 9447, 9447,
                  10504, 11560, 11560, 12617, 13673, 13673, 14730, 15786, 15786,
                  16843, 17899, 17899, 18956, 20012, 20012, 21069, 22125, 22125,
                  23182, 24238]
    kuze_barva = (24, 24, 32)      # uroven 2 sady 1002 (vypocet nize)
    paleta_ref = [(0, 0, 0)] * 32
    tabulka = [0, 8, 16, 24, 32, 41, 49, 57, 65, 74, 82, 90, 98, 106, 115, 123,
               131, 139, 148, 156, 164, 172, 180, 189, 197, 205, 213, 222, 230,
               238, 246, 255]

    def fixture(label: str, kind: str, with_render: bool = True,
                with_assets: bool = True, barva: tuple[int, int, int] | None = None,
                with_hues: bool = True) -> Path:
        root = base / label
        if with_render:
            (root / "render").mkdir(parents=True, exist_ok=True)
            (root / "render" / "chunk_renderer.gd").write_text("extends Node2D\n", encoding="utf-8")
            (root / "render" / "hue_cache.gd").write_text(
                f"extends RefCounted\nconst HUE_SKIN: int = {hue}\n", encoding="utf-8")
        if with_assets:
            # Klon s extrahovanymi daty: jen existence, obsah tu nikdo nemeri
            # (v CI assety nejsou a brana to musi umet rict nahlas).
            for name in ASSET_INPUTS:
                cil = root / "assets" / "uo" / name
                cil.parent.mkdir(parents=True, exist_ok=True)
                cil.write_bytes(b"stub")
        if with_hues and with_assets:
            sets = [{"set": i, "colors": [1] * 32} for i in range(hue - 1)]
            sets.append({"set": hue - 1, "colors": barvy_5bit})
            (root / "assets" / "uo" / "hues.json").write_text(
                json.dumps({"sets": sets}), encoding="utf-8")
        target = root / DEFAULT_SNAPSHOT
        target.parent.mkdir(parents=True, exist_ok=True)
        if kind == "blank":
            Image.new("RGB", (128, 128), (0, 0, 0)).save(target)
        elif kind in ("blob_center", "blob_corner"):
            # Plocha 40 x 40 = 1600 px, tedy NAD hranici `KUZE_MIN` - fixture
            # musi merit to, co brana pozaduje (docs/09 §9.6).
            img = Image.new("RGB", (128, 128), (10, 10, 10))
            rozsah = range(44, 84) if kind == "blob_center" else range(0, 8)
            for px in rozsah:
                for py in rozsah:
                    img.putpixel((px, py), barva or kuze_barva)
            img.save(target)
        return root

    # Barva urovene 2 sady 1002 se POCITA z tehoz `barvy_5bit`, aby fixture
    # nemohla "projit" s barvou, ktera v palate neni.
    c = barvy_5bit[2]
    kuze_barva = (tabulka[(c >> 10) & 0x1F], tabulka[(c >> 5) & 0x1F], tabulka[c & 0x1F])
    # VLASTNI POSTAVA: barva, ktera v UO palate kuze NENI (jinak by se nedalo
    # rozlisit, ktera kontrola vlastne prosla).
    vlastni_barva = (200, 30, 200)

    def own_fixture(label: str, barva: tuple[int, int, int]) -> Path:
        root = fixture(label, "blob_center", barva=barva)
        own_dir = root / "assets" / "own-lit" / "anim"
        own_dir.mkdir(parents=True, exist_ok=True)
        img = Image.new("RGBA", (8, 16), (0, 0, 0, 0))
        for px in range(8):
            for py in range(16):
                img.putpixel((px, py), (*vlastni_barva, 255))
        img.save(own_dir / "a.png")
        (own_dir / "anim-sheets.json").write_text(json.dumps({"sprites": {
            "400/0/0": {"file": "a.png", "frames": [
                {"cx": 4, "cy": -2, "w": 8, "h": 16, "rect": [0, 0, 8, 16]}]},
        }}), encoding="utf-8")
        (root / OWN_CONFIG).write_text(json.dumps({
            "version": 1,
            "layers": [{"name": "x", "manifest": "res://assets/own-lit/manifest.json",
                        "anim": "res://assets/own-lit/anim/anim-sheets.json",
                        "sprites": {"land": [1]}}],
        }), encoding="utf-8")
        # Snimek v teto fixture vzniknul PRED artefakty vyse (fixture() ho pise
        # posledni jen uvnitr sebe) - a kontrola stalosti by spravne rekla
        # "snimek je starsi nez art". Ve skutecnosti se snimek porizuje az po
        # sade, tak to fixture dorovna casem (nic se neprepisuje).
        os.utime(root / DEFAULT_SNAPSHOT, None)
        return root

    cases = [
        # "dobry" ma na stredove dlazdici barvu KUZE (ne jen nejakou barvu) -
        # vynucovani kuze plati i pro fixture, takze i ta musi mit co merit.
        ("dobry", fixture("dobry", "blob_center"), OK),
        ("vadny_jednolity", fixture("vadny_jednolity", "blank"), VADA),
        ("vadny_postava_mimo", fixture("vadny_postava_mimo", "blob_corner"), VADA),
        # SEDA postava na stredove dlazdici = presne vada, kterou ma brana
        # odhalit (docs/08 G10: "postava je seda" se pozna cislem, ne dojmem).
        ("vadny_postava_seda", fixture("vadny_postava_seda", "blob_center",
                                       barva=(123, 123, 123)), VADA),
        # cervena, ktera v palate NENI (driv prosla pres "R-B > 15") = VADA
        ("vadny_barva_mimo_paletu", fixture("vadny_barva_mimo_paletu", "blob_center",
                                            barva=(220, 40, 40)), VADA),
        ("bez_render_kodu", fixture("bez_render_kodu", "blob_center", with_render=False), NEMERENO),
        # klon bez extrahovanych dat: snimek muze byt klidne "pekny", ale merit
        # se nema co - a NEMERENO se nesmi tvarit jako VADA kódu (docs/08 §8.4)
        ("bez_assetu", fixture("bez_assetu", "blank", with_assets=False), NEMERENO),
        # bez `hues.json` neni paleta -> NEMERENO (ne ticha zelena)
        ("bez_palety", fixture("bez_palety", "blob_center", with_hues=False), NEMERENO),
        # VLASTNI ART (rebaseline 2026-10-11): se zapnutym vlastnim artem se
        # misto UO palety kuze vyzaduje shoda s barvami vlastniho spritu.
        # Znamy spravny (blob v barve vlastni postavy) i znamy chybny (sedivy).
        ("vlastni_ok", own_fixture("vlastni_ok", vlastni_barva), OK),
        ("vlastni_sedy", own_fixture("vlastni_sedy", (123, 123, 123)), VADA),
    ]
    # KUZE se meri ZVLAST: `kuzne_pixely` MUSI rozlisit barvu z palety od
    # sedive postavy. Oba pripady jsou ZNAME (spravny i chybny).
    kuze_dobry = fixture("kuze_dobry", "blob_center")
    kuze_seda = fixture("kuze_seda", "blob_center", barva=(123, 123, 123))
    paleta = kuze_paleta(kuze_dobry, hue)
    with Image.open(kuze_dobry / DEFAULT_SNAPSHOT) as img:
        pocet_dobry, _ = kuzne_pixely(np.asarray(img.convert("RGB")), paleta)
    with Image.open(kuze_seda / DEFAULT_SNAPSHOT) as img:
        pocet_seda, _ = kuzne_pixely(np.asarray(img.convert("RGB")), paleta)
    kuze_ok = len(paleta) == 32 and pocet_dobry >= KUZE_MIN and pocet_seda == 0
    print(f"[{NAME}] self-test kuze: paleta {len(paleta)} barev, barva -> {pocet_dobry} px, "
          f"seda -> {pocet_seda} px (hranice {KUZE_MIN}; "
          f"{'OK' if kuze_ok else 'CHYBA - mereni kuze nerozlisuje barvu od sedive'})")
    # STALOST SNIMKU (2026-10-12): znamy spravny (snimek po artefaktech) i znamy
    # chybny (snimek o hodinu starsi, nez je art). U chybneho se overuje I DUVOD
    # - "VADA ze spatneho duvodu" je stejna slepota jako zelena (docs/08 §8.1).
    stale = fixture("stale_snimek", "blob_center")
    snimek = stale / DEFAULT_SNAPSHOT
    stary_cas = time.time() - 3600.0
    os.utime(snimek, (stary_cas, stary_cas))
    os.utime(stale / "assets" / "uo" / "manifest.json", None)
    g_stale = Gate(f"{NAME}/selftest:stale")
    check(stale, g_stale)
    duvod = " ".join(g_stale.errors)
    stale_ok = (g_stale.verdict() == VADA and "STARŠÍ" in duvod
                and "manifest.json" in duvod)
    print(f"[{NAME}] self-test stalost: snimek o 1 h stary + cerstvy art -> "
          f"{'VADA s duvodem (OK)' if stale_ok else 'CHYBA'}"
          f"{'' if stale_ok else ': ' + duvod}")
    # a druha strana: tyz strom s cerstvym snimkem je OK
    os.utime(snimek, None)
    g_cerstvy = Gate(f"{NAME}/selftest:cerstvy")
    check(stale, g_cerstvy)
    cerstvy_ok = g_cerstvy.verdict() == OK
    print(f"[{NAME}] self-test stalost: tyz strom s cerstvym snimkem -> "
          f"{'OK' if cerstvy_ok else 'CHYBA'}")
    if not (kuze_ok and stale_ok and cerstvy_ok):
        return VADA
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G10 kontrola vykreslování ze snímku")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--snapshot", default=None)
    ap.add_argument("--focus", default=None, help="x,y,w,h")
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    focus = None
    if args.focus:
        focus = tuple(int(v) for v in args.focus.split(","))  # type: ignore[assignment]
    gate = Gate(NAME)
    check(Path(args.root).resolve(), gate,
          Path(args.snapshot) if args.snapshot else None, focus)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
