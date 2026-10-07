#!/usr/bin/env python3
"""Mutacni dukaz pro `render/anim_player.gd` a test `tests/cases/render_anim.gd`.

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
     "render.anim" (tedy selhala KONTROLA tohoto modulu, ne neco jineho).

Navic SMLOUVA O VSTUPU: test bere merenou cestu z argumentu (`-- --anim-script=`,
jako `render_sort`). Dokazuje se to NEEXISTUJICI cestou - test na ni MUSI
selhat; kdyby neselhal, meril by porad vychozi soubor a mutace by "prochazely".

POZOR (mereno 2026-10-06): v pracovnim stromu pracuji i jine session, takze
baseline muze mit selhani z CIZICH modulu. Proto se baseline i chyceni hodnoti
podle FAIL radku s prefixem "render.anim" - cizi selhani se jen VYPISE, aby
bylo videt (a ne aby se tvarilo jako chyceni teto mutace).

Spousteni (baseline je bezna sada, mutanti se predavaji argumentem):
  python tools/gates/mutace-render-anim.py [--only nazev]

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
ZDROJ = ROOT / "render" / "anim_player.gd"
MUTANT_DIR = ROOT / ".cache" / "gates" / "mutace-render-anim"
TESTS = "res://tests/run_tests.gd"
PREFIX = "render.anim"
SOUHRN = re.compile(r"(\d+)\s+kontrol,\s*(\d+)\s+selh")

# (nazev, co nahradit, cim, podminka na mutantovi) - kazda mutace vraci do kódu
# JEDNU konkretni vadu a `podminka` dokazuje, ze merena podminka prestala platit.
MUTACE: list[tuple[str, str, str, object]] = [
    ("frame_ms_vrati_40",
     "func frame_ms(_action: int) -> int: return Const.TURN_MS",
     "func frame_ms(_action: int) -> int: return 40",
     lambda t: "return Const.TURN_MS" not in t),
    ("frame_se_neposune_casem",
     'var tick: int = maxi(0, cas - int(state["start"]))',
     "var tick: int = 0",
     lambda t: 'maxi(0, cas - int(state["start"]))' not in t),
    ("cyklus_se_nikdy_nevrati",
     "var frame: int = (tick / frame_ms(action)) % count",
     "var frame: int = clampi(tick / frame_ms(action), 0, count - 1)",
     lambda t: "% count" not in t),
    ("mapa_smeru_naivni_zrcadleni",
     "const DIR_MAP := [[1, true], [2, true], [3, true], [4, false],\n"
     "\t[3, false], [2, false], [1, false], [0, false]]",
     "const DIR_MAP := [[2, true], [3, true], [4, false], [3, false],\n"
     "\t[2, false], [1, false], [0, false], [1, true]]",
     lambda t: "[1, true], [2, true], [3, true]" not in t),
    ("smer_se_ignoruje",
     "var map: Array = DIR_MAP[((dir % 8) + 8) % 8]",
     "var map: Array = DIR_MAP[0]",
     lambda t: ("var map: Array = DIR_MAP[((dir % 8) + 8) % 8]" not in t
                and "var map: Array = DIR_MAP[0]" in t)),
    ("anchor_bez_linky_zeme",
     '"anchor": Vector2(f["cx"], f["cy"] + f["h"])',
     '"anchor": Vector2(f["cx"], f["cy"])',
     lambda t: 'f["cy"] + f["h"]' not in t),
    ("zrcadlo_vzdy_false",
     '"anchor": Vector2(f["cx"], f["cy"] + f["h"]), "mirror": bool(map[1]),',
     '"anchor": Vector2(f["cx"], f["cy"] + f["h"]), "mirror": false,',
     lambda t: ('"cy"] + f["h"]), "mirror": false,' in t
                and '"cy"] + f["h"]), "mirror": bool(map[1]),' not in t)),
    ("chybejici_sprite_ok_true",
     'return {"ok": false, "texture": null, "frame": 0, "count": 0, "anchor": Vector2.ZERO,',
     'return {"ok": true, "texture": null, "frame": 0, "count": 0, "anchor": Vector2.ZERO,',
     lambda t: '"ok": false' not in t),
    ("frame_count_vzdy_nula",
     'return 0 if sheet == null else sheet["frames"].size()',
     "return 0  # mutace: vzdy nula",
     lambda t: 'sheet["frames"].size()' not in t),
    ("registr bytosti se ignoruje (telo = serial)",
     "var telo: int = body_of(serial)\n\tif telo < 0:",
     "var telo: int = serial\n\tif false:",
     lambda t: "var telo: int = body_of(serial)" not in t),
    ("neznamy serial se bere jako cislo tela",
     "if mob == null:\n\t\treturn -1",
     "if mob == null:\n\t\treturn serial",
     lambda t: "\t\treturn -1" not in t),
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
    ap = argparse.ArgumentParser(description="Mutacni dukaz pro render.anim")
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

    # 0) BASELINE: bez mutace musi sada probehnout a v render.anim nic nesmi selhat.
    #    Cizi selhani (jina session pracuje ve stejnem stromu) se jen VYPISOU.
    rc, vystup, checks, failures = spust(None)
    cizi = [line.strip() for line in vystup.splitlines()
            if line.strip().startswith("[test] FAIL") and PREFIX not in line]
    nase_baseline = fail_radky(vystup, PREFIX)
    print(f"[mutace] baseline: {checks} kontrol, {failures} selhani, exit {rc}; "
          f"FAIL s '{PREFIX}': {len(nase_baseline)}, cizich FAIL: {len(cizi)}")
    if checks == 0 or nase_baseline:
        print("[mutace] CHYBA: baseline v render.anim neprosel - mutace by nemerily nic")
        print(vystup[-2000:])
        return 2
    for line in cizi[:5]:
        print(f"[mutace]   (cizi selhani, neni predmetem teto brany) {line[:120]}")

    # 0b) SMLOUVA O VSTUPU: neexistujici cesta MUSI test shodit
    neexistuje = "res://.cache/gates/mutace-render-anim/neexistuje.gd"
    rc, vystup, checks, failures = spust(f"--anim-script={neexistuje}")
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
        cesta = MUTANT_DIR / f"anim_player-{nazev}.gd"
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
                  f"(provedena={provedena}, podminka={podminka_ok})")
            cesta.unlink()
            continue

        rc, vystup, checks, failures = spust(f"--anim-script={uri(cesta)}")
        radky = fail_radky(vystup, PREFIX)
        probehla = checks > 0
        chycena = rc != 0 and probehla and bool(radky)
        if not probehla:
            poznamka = "SADA VUBEC NEPROBEHLA (0 kontrol)"
        elif radky:
            poznamka = radky[0][:110]
        else:
            poznamka = "sada selhala, ale bez FAIL radku 'render.anim'"
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

    for soubor in MUTANT_DIR.glob("anim_player-*.gd"):
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
