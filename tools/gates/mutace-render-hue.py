#!/usr/bin/env python3
"""Mutacni dukaz pro `render/hue_cache.gd` a test `tests/cases/render_hue.gd`.

Zeleny test bez mutace neznamena, ze test meri (LESSONS, docs/09 §9.6). Tenhle
harness vraci do KOPIE granule vzdy JEDNU vadu a pozaduje, aby na ni test
spadl. U kazde mutace se overuji CTYRI veci ZVLAST:

  1. PROVEDENA  - vzor je ve zdroji PRAVE JEDNOU (`count == 1`; jinak by se
     mutovalo neco jineho, nez se meri - overovani §9.8) a na DISKU je mutant
     (text i hash se lisi od originalu),
  2. PODMINKA   - prislusna `podminka(mutant)` vraci True, tedy MERENA PODMINKA
     opravdu prestala platit (ne jen "text se zmenil", overovani §7.14),
  3. PROBEHLA   - sada vubec probehla: "N kontrol, M selhani" s N > 0,
  4. CHYCENA    - exit != 0 a existuje radek "[test] FAIL" s prefixem
     "render.hue" (tedy selhala KONTROLA tohoto modulu, ne neco jineho).

Navic SMLOUVA O VSTUPU: test bere merenou cestu z argumentu (`-- --hue-script=`,
jako `render_sort` a `render_anim`). Dokazuje se to NEEXISTUJICI cestou - test
na ni MUSI selhat; kdyby neselhal, meril by porad vychozi soubor a mutace by
"prochazely".

Spousteni (baseline je bezna sada, mutanti se predavaji argumentem):
  python tools/gates/mutace-render-hue.py [--only nazev]

Vystup: "[mutace] X/Y mutaci chyceno, Z chyb" a exit 0 jen kdyz chyb = 0.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import godot_bin, godot_run  # noqa: E402

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
ZDROJ = ROOT / "render" / "hue_cache.gd"
MUTANT_DIR = ROOT / ".cache" / "gates" / "mutace-render-hue"
TESTS = "res://tests/run_tests.gd"
PREFIX = "render.hue"
SOUHRN = re.compile(r"(\d+)\s+kontrol,\s*(\d+)\s+selh")

# (nazev, co nahradit, cim, podminka na mutantovi) - kazda mutace vraci do kódu
# JEDNU konkretni vadu a `podminka` dokazuje, ze merena podminka prestala platit.
MUTACE: list[tuple[str, str, str, object]] = [
    # 5 -> 8 bitu: tabulka z referencniho klienta vs posun `v << 3`. Rozdil je
    # u 31 z 32 hodnot - proto se to musi poznat.
    ("posun_misto_reference",
     "const EXPAND_5_TO_8 := [0, 8, 16, 24, 32, 41, 49, 57, 65, 74, 82, 90, 98, 106,\n"
     "\t115, 123, 131, 139, 148, 156, 164, 172, 180, 189, 197, 205, 213, 222, 230,\n"
     "\t238, 246, 255]",
     "const EXPAND_5_TO_8 := [0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104,\n"
     "\t112, 120, 128, 136, 144, 152, 160, 168, 176, 184, 192, 200, 208, 216, 224,\n"
     "\t232, 240, 248]",
     lambda t: "65, 74, 82, 90" not in t),
    # Index barvy: uroven se hleda podle R kanalu, ne podle ZELENE (ClassicUO
    # `get_rgb(color.r, hue)`) - jinak vyleze jina barva.
    # POZOR: `roundi(c.r * 255.0)` je v souboru DVAKRAT (take v otisku pro cache)
    # - vzor proto musi byt cely radek, jinak by se mutovalo neco jineho.
    ("uroven_podle_zelene",
     "var index: int = _uroven(roundi(c.r * 255.0))",
     "var index: int = _uroven(roundi(c.g * 255.0))",
     lambda t: "var index: int = _uroven(roundi(c.r * 255.0))" not in t),
    # Zaokrouhleni indexu (banker's rounding u pulky) - chyti jen kontrola
    # zpetneho prevodu na CELYCH 32 urovnich.
    ("uroven_bez_tabulky",
     "\tvar nejlepsi: int = 0\n"
     "\tvar rozdil: int = 1 << 30\n"
     "\tfor i in EXPAND_5_TO_8.size():\n"
     "\t\tvar d: int = absi(int(EXPAND_5_TO_8[i]) - k8)\n"
     "\t\tif d < rozdil:\n"
     "\t\t\trozdil = d\n"
     "\t\t\tnejlepsi = i\n"
     "\treturn nejlepsi",
     "\treturn clampi((k8 + 4) / 8, 0, COLORS_PER_SET - 1)",
     lambda t: "absi(int(EXPAND_5_TO_8[i]) - k8)" not in t),
    # Plny hue prebarvi VSECHNY netransparentni pixely - kdyby preskakoval
    # nesede, byl by to partial hue.
    ("plny_hue_preskakuje_barvy",
     "if partial_hue and not (c.r == c.g and c.g == c.b):",
     "if not (c.r == c.g and c.g == c.b):",
     lambda t: "if partial_hue and not" not in t),
    # Alfa je MASKA spritu - nahrazeni alfou 1.0 vyrobi neprusvitny ctverec.
    ("alfa_vzdy_1",
     "out.set_pixel(x, y, Color(nova.r, nova.g, nova.b, c.a))",
     "out.set_pixel(x, y, Color(nova.r, nova.g, nova.b, 1.0))",
     lambda t: "nova.b, c.a))" not in t),
    # Radky a sloupce barvy prohozene: barva by sla z jineho kanalu.
    ("kanaly_prohozene",
     "\t\t\t| (int(EXPAND_5_TO_8[(c >> 5) & 0x1F]) << 8)\n"
     "\t\t\t| int(EXPAND_5_TO_8[c & 0x1F]))",
     "\t\t\t| (int(EXPAND_5_TO_8[c & 0x1F]) << 8)\n"
     "\t\t\t| int(EXPAND_5_TO_8[(c >> 5) & 0x1F]))",
     lambda t: "| int(EXPAND_5_TO_8[c & 0x1F]))" not in t),
    # Index sady: `hue` je 1-based, `_sets` 0-based - bez `- 1` se pouzije
    # predchozi sada (a "hue 0 = bez barvy" by se rozbilo). Vzor je cely radek:
    # `_sets[hue - 1]` je v souboru DVAKRAT (take v `hue_color`).
    ("sada_bez_posunu",
     "\tvar sada: PackedInt32Array = _sets[hue - 1]",
     "\tvar sada: PackedInt32Array = _sets[hue]",
     lambda t: "var sada: PackedInt32Array = _sets[hue - 1]" not in t),
    # Cache: klic jen podle jmena souboru - textura vytvorena ZA BEHU ma
    # `resource_path` prazdny, takze by si dve ruzne textury vymenily vysledek
    # (presne to se namERilo 2026-10-06).
    ("cache_podle_jmena_souboru",
     "\treturn _otisk(base)",
     '\treturn "%s#%s" % [base.resource_path, "" if not (base is AtlasTexture) else str((base as AtlasTexture).region)]',
     lambda t: "return _otisk(base)" not in t),
    # Neznamy hue se nesmi tvarit jako uspech (docs/08 §8.6).
    ("neznamy_hue_tiche_prazdno",
     "\t\t_missing += 1\n"
     '\t\tpush_warning("render.hue: sadu %d hues.json nema (sad je %d)" % [hue, _sets.size()])\n'
     "\t\treturn base",
     "\t\treturn base",
     lambda t: "sadu %d hues.json nema" not in t),
    # Chybejici data se musi HLASIT (push_warning), ne mlcet.
    ("chybejici_data_mlci",
     '\t\tpush_warning("render.hue: %s nedal zadnou sadu - spust `python tools/uoextract/hues.py --install \\"<UO>\\"`" % hues_path)',
     "\t\tpass",
     lambda t: "nedal zadnou sadu" not in t),
    # Strop cache: bez vyhazovani roste pamet (a `polozek` prez strop).
    ("strop_cache_nevyhazuje",
     "\twhile _cache.size() > _limit and _order.size() > 1:",
     "\twhile false:",
     lambda t: "while _cache.size() > _limit" not in t),
    # Pocet sad: `_sets` se musi naplnit VSEMI sadami (ne jen prvni).
    ("jen_prvni_sada",
     '\t\tfor zaznam in parsed.get("sets", []):\n\t\t\t_sets.append(_barvy(zaznam))',
     '\t\tfor zaznam in parsed.get("sets", []).slice(0, 1):\n\t\t\t_sets.append(_barvy(zaznam))',
     lambda t: 'parsed.get("sets", []):' not in t),
    # ⚠ VADA ZE SNIMKU (uzivatel 2026-10-07): frame animace je OKNO
    # (`AtlasTexture.region`) do stranky, ktera ma vsech 10 framu vedle sebe.
    # Kdo oreze CELOU stranku, vykresli "vsechny animacni snimky" vedle postavy.
    ("cely_atlas_misto_okna",
     "\tif region.size.x > 0 and region.size.y > 0 and obrazek.get_size() != Vector2i(region.size):",
     "\tif false:",
     lambda t: "obrazek.get_size() != Vector2i(region.size)" not in t),
    # ...a kdo oreze SPRAVNE misto, ale z pocatku stranky, vykresli jiny frame
    # (vada by prosla kontrolou rozmeru, ale ne kontrolou barvy).
    ("okno_vzdy_z_pocatku_stranky",
     "\t\tobrazek = obrazek.get_region(region)",
     "\t\tobrazek = obrazek.get_region(Rect2i(Vector2i.ZERO, region.size))",
     lambda t: "obrazek.get_region(region)" not in t),
]


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def uri(cesta: Path) -> str:
    return "res://" + cesta.relative_to(ROOT).as_posix()


def spust(extra: str | None) -> tuple[int, str, int, int]:
    args = ["--script", TESTS]
    if extra:
        args += ["--", extra]
    rc, vystup = godot_run(ROOT, args, timeout=900)
    match = SOUHRN.search(vystup)
    checks, failures = (int(match.group(1)), int(match.group(2))) if match else (0, 0)
    return rc, vystup, checks, failures


def fail_radky(vystup: str, prefix: str) -> list[str]:
    return [line.strip() for line in vystup.splitlines()
            if line.strip().startswith("[test] FAIL") and prefix in line]


def main() -> int:
    ap = argparse.ArgumentParser(description="Mutacni dukaz pro render.hue")
    ap.add_argument("--only", default=None, help="jen mutace s timto nazvem")
    args = ap.parse_args()
    if godot_bin() is None:
        print("[mutace] CHYBA: Godot nenalezen (nastav $GODOT) - mutace by nic nemerily")
        return 2
    if not ZDROJ.exists():
        print(f"[mutace] CHYBA: {ZDROJ} neni - neni co mutovat")
        return 2

    original = ZDROJ.read_text(encoding="utf-8")
    hash_pred = sha(original)
    chyby: list[str] = []

    # 0) BASELINE: bez mutace musi sada probehnout a v render.hue nic nesmi selhat.
    #    Cizi selhani (jina session pracuje ve stejnem stromu) se jen VYPISOU.
    rc, vystup, checks, failures = spust(None)
    cizi = [line.strip() for line in vystup.splitlines()
            if line.strip().startswith("[test] FAIL") and PREFIX not in line]
    nase_baseline = fail_radky(vystup, PREFIX)
    print(f"[mutace] baseline: {checks} kontrol, {failures} selhani, exit {rc}; "
          f"FAIL s '{PREFIX}': {len(nase_baseline)}, cizich FAIL: {len(cizi)}")
    if checks == 0 or nase_baseline:
        print("[mutace] CHYBA: baseline v render.hue neprosel - mutace by nemerily nic")
        print(vystup[-2000:])
        return 2
    for line in cizi[:5]:
        print(f"[mutace]   (cizi selhani, neni predmetem teto brany) {line[:120]}")

    # 0b) SMLOUVA O VSTUPU: neexistujici cesta MUSI test shodit
    neexistuje = "res://.cache/gates/mutace-render-hue/neexistuje.gd"
    rc, vystup, checks, failures = spust(f"--hue-script={neexistuje}")
    smlouva_ok = rc != 0 and bool(fail_radky(vystup, PREFIX))
    print(f"[mutace] smlouva vstupu: neexistujici cesta -> "
          f"{'test selhal (spravne)' if smlouva_ok else 'TEST JI NEVIDI - CHYBA'} "
          f"({checks} kontrol, exit {rc})")
    if not smlouva_ok:
        chyby.append("smlouva o vstupu: neexistujici cesta test neshodila")

    MUTANT_DIR.mkdir(parents=True, exist_ok=True)
    vybrane = [m for m in MUTACE if not args.only or m[0] == args.only]
    chycene = 0
    for nazev, stare, nove, podminka in vybrane:
        pocet = original.count(stare)
        if pocet != 1:
            chyby.append(f"{nazev}: vzor je ve zdroji {pocet}x (musi byt 1x) - "
                         "mutovalo by se neco jineho, nez se meri")
            print(f"[mutace] {nazev}: VZOR {pocet}x - mutace se neprovedla, nepocita se")
            continue
        mutant = original.replace(stare, nove, 1)
        cesta = MUTANT_DIR / f"hue_cache-{nazev}.gd"
        cesta.write_text(mutant, encoding="utf-8")
        na_disku = cesta.read_text(encoding="utf-8")
        # 1) PROVEDENA: na disku je presne zamysleny text a lisi se od originalu
        provedena = (mutant != original and na_disku == mutant and nove in na_disku
                     and sha(na_disku) != hash_pred)
        # 2) PODMINKA: merena podminka opravdu prestala platit
        podminka_ok = bool(podminka(mutant))
        if not provedena or not podminka_ok:
            chyby.append(f"{nazev}: provedena={provedena} podminka={podminka_ok}")
            print(f"[mutace] {nazev}: MUTACE SE NEPROVEDLA / PODMINKA PLATI DAL "
                  f"(provedena={provedena}, podminka={podminka_ok}; "
                  f"stare v mutantovi: {mutant.count(stare)}x, "
                  f"jine: {sum(1 for a, b in zip(original.splitlines(), mutant.splitlines()) if a != b)} radku)")
            cesta.unlink()
            continue

        rc, vystup, checks, failures = spust(f"--hue-script={uri(cesta)}")
        radky = fail_radky(vystup, PREFIX)
        probehla = checks > 0
        chycena = rc != 0 and probehla and bool(radky)
        if not probehla:
            poznamka = "SADA VUBEC NEPROBEHLA (0 kontrol)"
        elif radky:
            poznamka = radky[0][:110]
        else:
            poznamka = "sada selhala, ale bez FAIL radku 'render.hue'"
        print(f"[mutace] {nazev}\n"
              f"          PROVEDENA ano ({sha(na_disku)}) | PODMINKA prestala platit | "
              f"PROBEHLA {'ano' if probehla else 'NE'} ({checks} kontrol, {failures} "
              f"selhani, exit {rc}) | {'CHYCENA' if chycena else 'PROSLA - TEST JE SLEPY'}\n"
              f"          {poznamka}")
        if chycena:
            chycene += 1
        else:
            chyby.append(f"{nazev}: provedena={provedena} podminka={podminka_ok} "
                         f"probehla={probehla} chycena={chycena}")
        cesta.unlink()

    for soubor in MUTANT_DIR.glob("hue_cache-*.gd"):
        soubor.unlink()

    # strom se NESMI zmenit: mutuje se jen kopie v .cache
    if sha(ZDROJ.read_text(encoding="utf-8")) != hash_pred:
        chyby.append(f"{ZDROJ.name} se na disku ZMENIL - toto je vada nastroje")
        print("[mutace] CHYBA: original se zmenil, mutuje se jen kopie")

    print(f"\n[mutace] {chycene}/{len(vybrane)} mutaci chyceno, {len(chyby)} chyb"
          f"; smlouva vstupu: {'OK' if smlouva_ok else 'CHYBA'}")
    for c in chyby:
        print(f"[mutace] CHYBA: {c}")
    return 0 if (not chyby and vybrane) else 1


if __name__ == "__main__":
    raise SystemExit(main())
