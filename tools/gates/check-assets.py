#!/usr/bin/env python3
"""G6 check-assets - manifest vs. stranky atlasu (docs/08 §8.2, §8.4).

Assety se extrahuji z instalace UO lokalne a necommituji (assets/uo/ je
v .gitignore), takze v CI nejsou. To se NESMI tise preskocit: brana to
vypise jako SKIP a skonci 2 (docs/08 §8.4).

Meri: manifest existuje a je citelny, kazda stranka atlasu z manifestu
existuje, pocet prazdnych spritu (pruhledny sprite je vada, docs/08 G6).

Spousteni:
  python tools/gates/check-assets.py [--root .] [--json cesta]
  python tools/gates/check-assets.py --self-test
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, load_json, selftest_cli,
)

NAME = "check-assets"
MANIFEST_CANDIDATES = ("assets/atlas/manifest.json", "assets/uo/manifest.json")
# Vlastni art (2026-10-11, granule `render.own_art`): G6 se do teto chvile
# divala JEN na `assets/uo/` - a ta jsou v .gitignore, takze v CI byla vzdycky
# NEMERENO. Vlastni sada je v gitu, takze se od teto chvile meri VZDY: stranky,
# prazdne sprity a invariant "je to NAHRAZENI, ne pridani" (SEAM.md §3 bod 1).
OWN_CONFIG = "assets/own-art.json"


def find_manifest(root: Path) -> Path | None:
    for rel in MANIFEST_CANDIDATES:
        path = root / rel
        if path.exists():
            return path
    return None


def collect_entries(data) -> tuple[list[dict], str]:
    if isinstance(data, list):
        return [e for e in data if isinstance(e, dict)], "seznam"
    if isinstance(data, dict):
        for key in ("sprites", "entries", "tiles", "items"):
            if isinstance(data.get(key), list):
                return [e for e in data[key] if isinstance(e, dict)], f"{{{key}: [...]}}"
        if isinstance(data.get("pages"), list):
            return [e for e in data["pages"] if isinstance(e, dict)], "{pages: [...]}"
    return [], "neznámý tvar"


def check_extraction_outputs(root: Path, gate: Gate) -> int:
    """Zkontroluje, co uz je extrahovane na disku (assets/uo/...).

    Proc: G6 dosud umela jen manifest atlasu, ktery v CI neni - takze vždy
    NEMERENO. Extrahovana data pritom vznikaji uz v M1 (mapa, barvy, nahledy)
    a jdou zkontrolovat hned. Kdyz nic z toho neni, vraci 0 a brana se chova
    jako predtim (SKIP kvuli chybejicim assetum, docs/08 §8.4).

    Vse se overuje proti CISLUM V SOUBORECH, ne proti dojmu: meta.json mapy
    musi sedet na velikosti souboru, ktere popisuje.
    """
    checked = 0

    meta_path = root / "assets" / "uo" / "world" / "map0.meta.json"
    if meta_path.exists():
        try:
            meta = load_json(meta_path)
        except Exception as exc:
            gate.error(f"world/map0.meta.json se nedá přečíst ({exc})")
            return checked
        checked += 1
        land_path = root / "assets" / "uo" / "world" / "map0.land"
        bin_path = root / "assets" / "uo" / "world" / "map0.statics.bin"
        idx_path = root / "assets" / "uo" / "world" / "map0.statics.idx"
        blocks = int(meta.get("blocks_x", 0)) * int(meta.get("blocks_y", 0))
        gate.measure("mapa_bloku", blocks)
        gate.measure("mapa_dlazdic", int(meta.get("land_tiles", 0)))
        if land_path.exists():
            expected = blocks * int(meta.get("block_bytes", 0))
            actual = land_path.stat().st_size
            gate.measure("mapa_land_bajtu", actual)
            if expected and actual != expected:
                gate.error(f"map0.land má {actual} B, meta.json říká {expected} B")
        else:
            gate.error("world/map0.meta.json je, ale map0.land chybí")
        if idx_path.exists() and bin_path.exists():
            rows = idx_path.stat().st_size // 12
            if rows != blocks:
                gate.error(f"map0.statics.idx má {rows} bloků, meta.json říká {blocks}")
        else:
            gate.error("world/map0.meta.json je, ale statics .idx/.bin chybí")

    hues_path = root / "assets" / "uo" / "hues.json"
    if hues_path.exists():
        try:
            hues = load_json(hues_path)
        except Exception as exc:
            gate.error(f"hues.json se nedá přečíst ({exc})")
            return checked
        sets = hues.get("sets", [])
        checked += 1
        gate.measure("hues_sad", len(sets))
        if len(sets) != 3000:
            gate.error(f"hues.json má {len(sets)} sad, docs/03 §3.2b říká 3000")
        empty = [s for s in sets if len(s.get("colors", [])) != 32]
        if empty:
            gate.error(f"{len(empty)} sad nemá 32 barev (první: {empty[0].get('set')})")
        named = sum(1 for s in sets if s.get("name"))
        gate.measure("hues_pojmenovanych", named)
        if named == 0:
            gate.error("hues.json nemá ani jednu pojmenovanou sadu")

    if checked:
        gate.note("assety z instalace UO (lokálně vyextrahované) - měřeno, viz measured")
    return checked


def _own_klic(entry: dict) -> tuple[str, int] | None:
    kind = str(entry.get("kind", ""))
    if kind not in ("land", "item", "texmap"):
        return None
    return (kind, int(entry.get("id", -1)))


def check_own_art(root: Path, gate: Gate) -> int:
    """Vlastni art: manifest vs. stranky, prazdne sprity, a hlavne to, ze je to
    NAHRAZENI (kazde nase id je i v UO manifestu - SEAM.md §3 bod 1).

    Proc v G6: dokud se vlastni sada nemerila, slo do gitu neplatny atlas a
    nikdo to nepoznal. Vlastni sada je na rozdil od `assets/uo/` V GITU, takze
    se tim G6 konecne stava merenou i v CI.
    """
    cesta = root / OWN_CONFIG
    if not cesta.exists():
        gate.note(f"{OWN_CONFIG} není - vlastni art se NEMEŘIL")
        return 0
    try:
        data = load_json(cesta)
    except Exception as exc:
        gate.error(f"{OWN_CONFIG} se neda precist ({exc})")
        return 1
    vrstvy = data.get("layers", [])
    if not isinstance(vrstvy, list) or not vrstvy:
        gate.error(f"{OWN_CONFIG} nema zadnou vrstvu (prazdny seznam neni uspech)")
        return 1
    gate.measure("own_vrstev", len(vrstvy))

    uo_entries: dict[tuple[str, int], dict] = {}
    uo_manifest = root / "assets" / "uo" / "manifest.json"
    if uo_manifest.exists():
        try:
            for entry in collect_entries(load_json(uo_manifest))[0]:
                klic = _own_klic(entry)
                if klic is not None:
                    uo_entries[klic] = entry
        except Exception as exc:
            gate.note(f"UO manifest se neda precist ({exc}) - nahrazeni NEMEŘENO")

    vlastni: dict[tuple[str, int], str] = {}
    spritu = 0
    stranek: set[str] = set()
    prazdnych = 0
    seam_ok = 0
    seam_chybi = 0
    for i, vrstva in enumerate(vrstvy):
        if not isinstance(vrstva, dict):
            gate.error(f"{OWN_CONFIG}: vrstva {i} neni slovnik")
            continue
        jmeno = str(vrstva.get("name", ""))
        # Cesty jsou `res://...` (cte je Godot); na disk se prekladaji bez prefixu.
        mrel = str(vrstva.get("manifest", "")).replace("res://", "")
        man = root / mrel
        if not man.exists():
            gate.error(f"{OWN_CONFIG}: vrstva '{jmeno}' - manifest {mrel} neexistuje")
            continue
        base = man.parent
        try:
            entries = collect_entries(load_json(man))[0]
        except Exception as exc:
            gate.error(f"{mrel}: JSON se neda precist ({exc})")
            continue
        sprites = vrstva.get("sprites", {})
        if not isinstance(sprites, dict) or not sprites:
            gate.error(f"{OWN_CONFIG}: vrstva '{jmeno}' nema 'sprites' - nic z ni nejde vzit")
            continue
        vybrane = 0
        for entry in entries:
            klic = _own_klic(entry)
            if klic is None:
                continue
            kind, ident = klic
            if kind not in sprites or ident not in [int(v) for v in sprites.get(kind, [])]:
                continue  # tahle vrstva tenhle kus nedodava (vyber po kusech)
            vybrane += 1
            spritu += 1
            if klic in vlastni:
                gate.error(f"{OWN_CONFIG}: {kind} {ident} je ve vrstvach "
                           f"'{vlastni[klic]}' i '{jmeno}' - druha by se tise ignorovala")
            vlastni[klic] = jmeno
            page = entry.get("page")
            if isinstance(page, str) and page:
                stranek.add(page)
            if uo_entries:
                if klic in uo_entries:
                    seam_ok += 1
                else:
                    seam_chybi += 1
                    gate.error(f"seam: {kind} {ident} (vrstva '{jmeno}') NENI v UO manifestu "
                               "- bylo by to PRIDANI, ne nahrazeni (SEAM.md §3 bod 1)")
        if vybrane == 0 and sprites:
            gate.error(f"{OWN_CONFIG}: vrstva '{jmeno}' uvadi {sprites}, ale v manifestu "
                       "se naslo 0 takovych spritu - vyber po kusech nic nevybral")
        # Stranky atlasu musi existovat (jinak se kresli dira).
        for page in sorted({str(e.get("page", "")) for e in entries if e.get("page")}):
            if not (base / page).exists() and not (root / page).exists():
                gate.error(f"{mrel}: stranka atlasu chybi: {page}")

    gate.measure("own_spritu", spritu)
    gate.measure("own_stranek", len(stranek))
    gate.measure("own_seam_id", seam_ok)
    gate.measure("own_seam_chybi", seam_chybi)
    if not vlastni:
        gate.error(f"{OWN_CONFIG} nedal ani jedno pouzitelne id (prazdno neni uspech)")
        return 1

    # Prazdne (cele pruhledne) sprity - vada (docs/08 G6), meri se jen s Pillow.
    try:
        from PIL import Image  # noqa: F401
    except Exception:
        gate.note("Pillow neni k dispozici - prazdne sprity VLASTNIHO artu NEMEŘENY")
        return 1
    for i, vrstva in enumerate(vrstvy):
        if not isinstance(vrstva, dict):
            continue
        mrel = str(vrstva.get("manifest", "")).replace("res://", "")
        man = root / mrel
        if not man.exists():
            continue
        entries = collect_entries(load_json(man))[0]
        sprites = vrstva.get("sprites", {})
        base = man.parent
        for entry in entries:
            klic = _own_klic(entry)
            if klic is None:
                continue
            kind, ident = klic
            if kind not in sprites or ident not in [int(v) for v in sprites.get(kind, [])]:
                continue
            page = entry.get("page")
            rect = entry.get("rect") or entry.get("src")
            if not isinstance(page, str) or not isinstance(rect, (list, tuple)) or len(rect) != 4:
                continue
            obrazek = base / page
            if not obrazek.exists():
                continue
            try:
                with Image.open(obrazek) as img:
                    region = img.convert("RGBA").crop(tuple(int(v) for v in rect))
                    if region.getbbox() is None:
                        prazdnych += 1
                        gate.error(f"prazdny sprite (vlastni art): {mrel} {page} {tuple(rect)}")
            except Exception as exc:
                gate.error(f"{mrel}: {page} nelze zmerit ({exc})")
    gate.measure("own_spritu_prazdnych", prazdnych)
    gate.note("vlastni art: vyber po kusech i invariant 'nahrazeni, ne pridani' jsou MERENE")
    return 1


def _posledni_radek(vystup: str) -> str:
    radky = [r for r in vystup.strip().splitlines() if r.strip()]
    return radky[-1] if radky else "(žádný výstup)"


def _pocet_kontrol(vystup: str) -> int:
    # Self-test píše "[anim] self-test: 35 kontrol, 0 chyb" - bereme PRVNÍ
    # číslo a jen z řádku se souhrnem (jinak by se dalo splést s "0 chyb").
    import re
    m = re.search(r"self-test:\s*(\d+)\s*kontrol", vystup)
    return int(m.group(1)) if m else 0


def anim_selftest(root: Path) -> tuple[int, str]:
    """Spustí offline self-test dekodéru animací a vrátí (exit kód, výstup).

    Skript se bere z `root` (v reálném běhu je to repo); když tam není (self-test
    brány pouští check na FALEŠNÉM rootu), bere se z umístění TÉTO brány - jinak
    by self-test neměřil logiku brány, ale to, co je v atrapě.
    """
    skript = root / "tools" / "uoextract" / "anim.py"
    if not skript.exists():
        skript = Path(__file__).resolve().parents[2] / "tools" / "uoextract" / "anim.py"
    if not skript.exists():
        return 127, f"chybí {skript}"
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"
    try:
        proc = subprocess.run(
            [sys.executable, str(skript), "--self-test"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=120, env=env,
        )
    except subprocess.TimeoutExpired:
        return 124, "self-test dekodéru překročil timeout 120 s"
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def check_anim_manifest(root: Path, gate: Gate) -> int:
    """Manifest animaci (assets/uo/anim-manifest.json) - granule assets.anim.

    Proc prave takhle: rozhodnuti "blok v anim.mul -> anim.mul, jinak
    AnimationFrame*.uop" (docs/03 §3.5.1) je TVRZENI o datech, ktere se da
    overit jen na konkretnich telesech. Kdyz manifest u tela 400 (hrac) rekne
    neco jineho nez anim.mul, je rozhodnuti rozbite - a to je vada, ne detail.
    """
    cesta = root / "assets" / "uo" / "anim-manifest.json"
    if not cesta.exists():
        return 0
    try:
        data = load_json(cesta)
    except Exception as exc:
        gate.error(f"uo/anim-manifest.json se nedá přečíst ({exc})")
        return 1
    tela = data.get("bodies", {})
    zdroje = data.get("sources", {})
    gate.measure("anim_tel", len(tela))
    gate.measure("anim_mul_tel", int(zdroje.get("anim*.mul", {}).get("bodies", 0)))
    gate.measure("anim_uop_tel", int(zdroje.get("AnimationFrame*.uop", {}).get("bodies", 0)))
    if not tela:
        gate.error("anim-manifest.json nemá žádné tělo (prázdný manifest není úspěch)")
        return 1
    if not data.get("sha256"):
        gate.error("anim-manifest.json nemá SHA-256 vstupů (docs/03 §3.5.3 bod 5)")
    for telo, ocekavany in (("400", "anim.mul"), ("401", "anim.mul"), ("334", "AnimationFrame.uop")):
        zaznam = tela.get(telo)
        if zaznam is None:
            gate.error(f"anim-manifest.json nezná tělo {telo} (měření: v datech je)")
            continue
        if zaznam.get("source") != ocekavany:
            gate.error(f"tělo {telo} má zdroj {zaznam.get('source')}, "
                       f"měření (docs/03 §3.5.1) říká {ocekavany}")
        if not zaznam.get("actions"):
            gate.error(f"tělo {telo} nemá v manifestu žádnou akci")
    if data.get("pixels_decoded") is True:
        # 2026-10-06: do téhle chvíle brána tvrdila "dekodér pixelů ověřený
        # není" (podle `research/anim-mereni.md` z 2026-10-03) a manifest
        # s `pixels_decoded: true` rovnou hlásila jako VADU. To tvrzení
        # zestárlo: pixely JSOU dekódované (signed 10bit x/y, 512B paleta
        # v bloku, pixel = 1 bajt) a dekodér má vlastní offline self-test.
        # Brána proto od teď netvrdí "neexistuje" - měří, že to platí:
        # (1) manifest musí nést recept (`pixels_recipe`) a
        # (2) self-test dekodéru musí projít (je offline, takže jde i v CI).
        if not data.get("pixels_recipe"):
            gate.error("manifest tvrdí pixels_decoded=true, ale nenese `pixels_recipe` "
                       "(čím je to dekódované, se musí dát ověřit)")
        kod, vystup = anim_selftest(root)
        kontrol = _pocet_kontrol(vystup)
        gate.measure("anim_decoder_kod", kod)
        gate.measure("anim_decoder_kontrol", kontrol)
        if kod != 0:
            gate.error(f"manifest tvrdí pixels_decoded=true, ale self-test dekodéru "
                       f"(`tools/uoextract/anim.py --self-test`) vyšel {kod}: "
                       f"{_posledni_radek(vystup)}")
        elif kontrol <= 0:
            gate.error("self-test dekodéru proběhl, ale nezměřil nic (`N kontrol`, N<=0)")
    gate.note("anim manifest: zdroj u každého těla je měřený, ne odhadnutý")
    return 1


def check(root: Path, gate: Gate) -> None:
    measured_outputs = check_extraction_outputs(root, gate)
    measured_outputs += check_anim_manifest(root, gate)
    # Vlastni art je V GITU, takze se meri i v CI (kde `assets/uo/` neni).
    measured_outputs += check_own_art(root, gate)
    manifest = find_manifest(root)
    if manifest is None:
        if measured_outputs:
            # Neco jsme zmerili, takze NEMERENO nema smysl; chybejici manifest
            # je jen poznamka (v CI assety nejsou, docs/08 §8.4).
            gate.note("manifest atlasu není (v CI chybí; kontrola manifestu NEPROBĚHLA)")
        else:
            gate.skip(
                "manifest atlasu není (assety se extrahují lokálně z instalace UO; "
                "v CI chybí - kontrola NEPROBĚHLA, docs/08 §8.4)"
            )
        return

    try:
        data = load_json(manifest)
    except Exception as exc:
        gate.error(f"{manifest.relative_to(root).as_posix()}: JSON se nedá přečíst ({exc})")
        return

    entries, shape = collect_entries(data)
    gate.measure("manifest", manifest.relative_to(root).as_posix())
    gate.measure("zaznamu", len(entries))
    gate.note(f"manifest tvar: {shape}")
    if not entries:
        gate.error("manifest nemá žádný záznam (prázdný manifest není úspěch)")
        return

    pages: set[str] = set()
    for entry in entries:
        for key in ("page", "atlas", "file", "sheet"):
            value = entry.get(key)
            if isinstance(value, str):
                pages.add(value)

    gate.measure("stranek", len(pages))
    if not pages:
        gate.note("manifest neuvádí stránky atlasu (klíč page/atlas/file) - existence stránek NEMĚŘENA")
        return

    base = manifest.parent
    missing = 0
    for page in sorted(pages):
        candidate = (base / page)
        if not candidate.exists():
            candidate = root / page
        if not candidate.exists():
            missing += 1
            gate.error(f"stránka atlasu z manifestu chybí: {page}")
    gate.measure("stranek_chybi", missing)

    # prazdne sprity - jen kdyz je cim merit (Pillow + skutecne PNG)
    try:
        from PIL import Image  # noqa: F401
    except Exception:
        gate.note("Pillow není k dispozici - prázdné sprity NEMĚŘENY")
        return
    checked = 0
    empty = 0

    # Optimalizace: seskupit podle stranek, aby se kazdy velky PNG neoteviral
    # a nedekodoval 41874x (namereno: zrychleni ze 120s+ timeoutu na ~3s).
    entries_by_page: dict[str, list[tuple[dict, tuple[int, ...]]]] = {}
    for entry in entries:
        page = entry.get("page") or entry.get("atlas") or entry.get("file")
        rect = entry.get("rect") or entry.get("src")
        if not isinstance(page, str) or not isinstance(rect, (list, tuple)) or len(rect) != 4:
            continue
        entries_by_page.setdefault(page, []).append((entry, tuple(int(v) for v in rect)))

    for page, page_entries in entries_by_page.items():
        candidate = base / page
        if not candidate.exists():
            candidate = root / page
        if not candidate.exists():
            continue
        try:
            with Image.open(candidate) as img:
                rgba = img.convert("RGBA")
                for entry, rect_tuple in page_entries:
                    region = rgba.crop(rect_tuple)
                    if region.getbbox() is None:
                        empty += 1
                        gate.error(f"prázdný sprite: {page} {rect_tuple} (docs/08 G6)")
                    checked += 1
        except Exception as exc:
            gate.error(f"{page}: stranku nelze zmerit ({exc})")
    gate.measure("spritu_zkontrolovano", checked)
    gate.measure("spritu_prazdnych", empty)


def selftest() -> int:
    import json
    import shutil

    try:
        from PIL import Image
    except Exception:
        print(f"[{NAME}] self-test: Pillow není k dispozici, test NEPROBĚHL")
        return NEMERENO

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-assets"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, manifest: dict | None, pages: list[str],
                anim: dict | None = None, rozbity_dekoder: bool = False) -> Path:
        root = base / label
        (root / "assets" / "atlas").mkdir(parents=True, exist_ok=True)
        if manifest is not None:
            (root / "assets" / "atlas" / "manifest.json").write_text(
                json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        if anim is not None:
            (root / "assets" / "uo").mkdir(parents=True, exist_ok=True)
            (root / "assets" / "uo" / "anim-manifest.json").write_text(
                json.dumps(anim, ensure_ascii=False), encoding="utf-8")
        if rozbity_dekoder:
            # Známý chybný případ pro druhou část kontroly: manifest tvrdí, že
            # pixely jsou dekódované, ale dekodér v tomhle rootu selže.
            (root / "tools" / "uoextract").mkdir(parents=True, exist_ok=True)
            (root / "tools" / "uoextract" / "anim.py").write_text(
                "import sys\nprint('[anim] self-test: 3 kontrol, 1 chyb')\n"
                "sys.exit(1)\n", encoding="utf-8")
        for page in pages:
            target = root / "assets" / "atlas" / page
            # platny PNG: kontrola prázdných spritů potřebuje obrázek, ne hlavičku
            img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            for px in range(0, 44):
                for py in range(0, 44):
                    img.putpixel((px, py), (200, 120, 40, 255))
            img.save(target)
        return root

    good = {"sprites": [{"tile": 1, "page": "atlas0.png", "rect": [0, 0, 44, 44]}]}

    def own_fixture(label: str, rect=(0, 0, 44, 44), uo_id=1, dve_vrstvy=False,
                    stranka_chybi=False) -> Path:
        """Fixture pro VLASTNI art: konfigurace + vlastni manifest + stranka + UO
        manifest (kvuli invariantu "nahrazeni, ne pridani")."""
        root = fixture(label, good, ["atlas0.png"])
        own_dir = root / "assets" / "own-lit"
        (own_dir / "atlas").mkdir(parents=True, exist_ok=True)
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        for px in range(0, 44):
            for py in range(0, 44):
                img.putpixel((px, py), (200, 120, 40, 255))
        if not stranka_chybi:
            img.save(own_dir / "atlas" / "land_0.png")
        (own_dir / "manifest.json").write_text(json.dumps({"sprites": [
            {"kind": "land", "id": 1, "page": "atlas/land_0.png",
             "x": rect[0], "y": rect[1], "w": rect[2], "h": rect[3],
             "rect": list(rect), "ox": 0, "oy": 0},
        ]}, ensure_ascii=False), encoding="utf-8")
        uo_dir = root / "assets" / "uo"
        uo_dir.mkdir(parents=True, exist_ok=True)
        (uo_dir / "manifest.json").write_text(json.dumps({"sprites": [
            {"kind": "land", "id": uo_id, "page": "atlas/land_0.png",
             "x": 0, "y": 0, "w": 44, "h": 44, "ox": 0, "oy": 0},
        ]}, ensure_ascii=False), encoding="utf-8")
        vrstva = {"name": "lit", "manifest": "res://assets/own-lit/manifest.json",
                  "anim": None, "sprites": {"land": [1]}}
        vrstvy = [vrstva, dict(vrstva, name="lit2")] if dve_vrstvy else [vrstva]
        (root / OWN_CONFIG).write_text(json.dumps(
            {"version": 1, "layers": vrstvy}, ensure_ascii=False), encoding="utf-8")
        return root

    # Minimální anim manifest, který projde kontrolou těl: 400/401 z MUL,
    # 334 z UOP (přesně to, co měří check_anim_manifest).
    anim_ok = {
        "sha256": {"anim.idx": "0" * 64},
        "sources": {"anim*.mul": {"bodies": 2, "actions": 2},
                    "AnimationFrame*.uop": {"bodies": 1, "actions": 1}},
        "pixels_decoded": True,
        "pixels_recipe": "test",
        "bodies": {"400": {"source": "anim.mul", "actions": [0]},
                   "401": {"source": "anim.mul", "actions": [0]},
                   "334": {"source": "AnimationFrame.uop", "actions": [1]}},
    }
    anim_bez_receptu = dict(anim_ok)
    anim_bez_receptu.pop("pixels_recipe")
    cases = [
        ("dobry", fixture("dobry", good, ["atlas0.png"]), OK),
        ("vadny_chybi_stranka", fixture("vadny_chybi_stranka", good, []), VADA),
        ("vadny_prazdny_manifest", fixture("vadny_prazdny_manifest", {"sprites": []}, []), VADA),
        ("bez_manifestu", fixture("bez_manifestu", None, []), NEMERENO),
        # 2026-10-06: kontrola "manifest tvrdí pixels_decoded=true" MUSÍ mít
        # známý správný i známý chybný případ - jinak je to brána, která
        # nemůže selhat (docs/08 §8.1).
        ("anim_s_receptem", fixture("anim_s_receptem", good, ["atlas0.png"], anim_ok), OK),
        ("anim_bez_receptu", fixture("anim_bez_receptu", good, ["atlas0.png"],
                                     anim_bez_receptu), VADA),
        ("anim_vadny_dekoder", fixture("anim_vadny_dekoder", good, ["atlas0.png"],
                                         anim_ok, rozbity_dekoder=True), VADA),
        # VLASTNI ART (2026-10-11): znamy spravny i znamy chybny pripad pro kazdou
        # novou kontrolu - jinak by to byla brana, ktera nemuze selhat.
        ("own_ok", own_fixture("own_ok"), OK),
        ("own_prazdny_sprite", own_fixture("own_prazdny_sprite", rect=(50, 50, 8, 8)), VADA),
        ("own_chybi_stranka", own_fixture("own_chybi_stranka", stranka_chybi=True), VADA),
        ("own_neni_v_uo", own_fixture("own_neni_v_uo", uo_id=999), VADA),
        ("own_duplicitni_id", own_fixture("own_duplicitni_id", dve_vrstvy=True), VADA),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G6 kontrola assetů")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    gate = Gate(NAME)
    check(Path(args.root).resolve(), gate)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
