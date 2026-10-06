#!/usr/bin/env python3
"""Mutacni dukaz testu z tests/cases/ (docs/09 §9.6 bod 3).

PROC: zeleny test bez mutace neznamena, ze test meri. Kazda mutace vraci do
kódu VADU a test ji musi chytit. U KAZDE mutace se overuji TRI veci ZVLAST
(bez nich je "spadlo" jen dohad):

  1. PROVEDENA  - text se zmenil a na DISKU je opravdu mutant (hash),
  2. PROBEHLALA - testovaci sada vubec probehla: "N kontrol, M selhani" s N > 0,
  3. CHYCENA    - exit != 0 a aspon jeden radek "[test] FAIL <modul> ...",
                  tedy selhala KONTROLA toho modulu (ne neco jineho).

Navic se overuje SMLOUVA O VSTUPU: test musi brat merenou cestu z argumentu
(`-- --sort-script=...`, `-- --map-script=...`). Dokazuje se to tim, ze se
preda NEEXISTUJICI cesta - test na to MUSI selhat. Kdyby neselhal, meril by
porad vychozi soubor a mutace by "prochazely" (HANDOFF 2026-10-06, past 2).

Baseline (bez mutace) se pousti PRVNI a musi dat 0 selhani - jinak by
"mutace spadla" neznamenalo nic. Nakonec se overi, ze se original na disku
NEZMENIL (mutuje se jen kopie v .cache/gates/mutace/).

SEZNAM MUTACI JE ZAMERNE JEN TO, CO TESTY OPRAVDU CHYTI. NamEReno 2026-10-06:
mutace `_lower` `return a[0] < b[0]` -> `return a[0] <= b[0]` se u Godotu
neprojevi (1000 objektu se stejnym klicem i 200 smisenych dalo stejne poradi
jako spravny kod), takze v seznamu NENI - tvrdit u ni "CHYCENA" by bylo
tvrzeni o nemerenem. Kdo ji tam prida, dostane PROSLA a vi, ze je to slepe
misto, ne vada testu.

  python tools/gates/mutace-tests.py            # vsechny moduly
  python tools/gates/mutace-tests.py --only sort
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import godot_bin, godot_run  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TESTS = "res://tests/run_tests.gd"
MUTANT_DIR = ROOT / ".cache" / "gates" / "mutace"
SOUHRN = re.compile(r"(\d+)\s+kontrol,\s*(\d+)\s+selh")

# klic -> soubor, ktery se mutuje, prefix FAIL radku a prepinac testu
MODULY = {
    "sort": {
        "soubor": ROOT / "render" / "sort.gd",
        "prefix": "render.sort",
        "prepinac": "--sort-script",
        "mutace": [
            ("vrstvy prohozene (static jako mobilni)",
             '"static": LAYER_STATIC', '"static": LAYER_MOBILE'),
            ("item mimo mobilni vrstvu",
             '"item": LAYER_MOBILE', '"item": LAYER_STATIC'),
            ("land jako mobilni",
             '"land": LAYER_LAND', '"land": LAYER_MOBILE'),
            ("neznamy kind jako land",
             "else LAYER_MOBILE", "else LAYER_LAND"),
            ("z descendo",
             "(z - Const.Z_MIN)", "(Const.Z_MAX - z)"),
            ("z vraceno, ne z",
             "(z - Const.Z_MIN)", "(z + Const.Z_MIN)"),
            ("z se nesveruje",
             'clampi(int(obj.get("z", 0)), Const.Z_MIN, Const.Z_MAX)',
             'int(obj.get("z", 0))'),
            ("diagonala x-y",
             'int(obj.get("x", 0)) + int(obj.get("y", 0))',
             'int(obj.get("x", 0)) - int(obj.get("y", 0))'),
            ("nestabilni razeni (rovna se vraci false)",
             "return a[1] < b[1]", "return false"),
            ("spatny radix vrstev (LAYERS 3 -> 2)",
             "const LAYERS: int = 3", "const LAYERS: int = 2"),
        ],
    },
    "map": {
        "soubor": ROOT / "sim" / "world" / "map.gd",
        "prefix": "world.map",
        "prepinac": "--map-script",
        "mutace": [
            ("z zpet na offset +3 (= lokalni y)",
             '"z": data.decode_s8(at + 4)', '"z": data.decode_s8(at + 3)'),
            ("x cte bajt y",
             '"x": data.decode_u8(at + 2)', '"x": data.decode_u8(at + 3)'),
            ("x se neprecte (vsechny statiky na x = 0)",
             '"x": data.decode_u8(at + 2)', '"x": 0'),
            ("bunka v bloku po sloupcich",
             "return (y % Const.BLOCK_SIZE) * Const.BLOCK_SIZE + (x % Const.BLOCK_SIZE)",
             "return (x % Const.BLOCK_SIZE) * Const.BLOCK_SIZE + (y % Const.BLOCK_SIZE)"),
            ("index bloku y-major",
             "var key := bx * _blocks_y + by", "var key := by * _blocks_x + bx"),
            ("hlavicka bloku v .land se preskoci",
             "_land.seek(key * (LAND_HEADER_BYTES + want) + LAND_HEADER_BYTES)",
             "_land.seek(key * (LAND_HEADER_BYTES + want))"),
            ("z_at cte bajt dlazdice misto z",
             "return cells.decode_s8(_cell_at(x, y) * CELL_BYTES + 2)",
             "return cells.decode_s8(_cell_at(x, y) * CELL_BYTES)"),
            ("land_at cte posunuty bajt",
             "return cells.decode_u16(_cell_at(x, y) * CELL_BYTES)",
             "return cells.decode_u16(_cell_at(x, y) * CELL_BYTES + 1)"),
            ("statics_at vraci jen prvni zaznam",
             'out = entry["statics"]', 'out = entry["statics"].slice(0, 1)'),
            ("zaporna y se nekontroluji",
             "if x < 0 or y < 0:", "if x < 0:"),
            ("blocks_x se cte z blocks_y",
             '_blocks_x = int(meta.get("blocks_x", 0))',
             '_blocks_x = int(meta.get("blocks_y", 0))'),
        ],
    },
    "walk": {
        "soubor": ROOT / "sim" / "world" / "walk.gd",
        "prefix": "world.walk",
        "prepinac": "--walk-script",
        "mutace": [
            ("krok nahoru jen o 1 (STEP_HEIGHT ignorovan)",
             "if dz > Const.STEP_HEIGHT:", "if dz > 1:"),
            ("voda neblokuje",
             "if _tiledata.flags(land) & F_WET != 0:", "if false:"),
            ("diagonala symetricka i pro hrace",
             "if dx != 0 and dy != 0 and is_player:", "if false:"),
            ("statik s Impassable neblokuje",
             "func _blokuje_statik(x: int, y: int) -> bool:",
             "func _blokuje_statik(x: int, y: int) -> bool:\n\treturn false\n"),
            ("surface_z ignoruje flag Surface",
             "if _tiledata.flags(tile) & F_SURFACE == 0:",
             "if true:"),
            ("statik se bere z celeho bloku (ignoruje lokalni x,y)",
             'if int(s["x"]) == x % Const.BLOCK_SIZE and int(s["y"]) == y % Const.BLOCK_SIZE:',
             "if true:"),
        ],
    },
    "movement": {
        "soubor": ROOT / "sim" / "systems" / "movement.gd",
        "prefix": "sim.movement",
        "prepinac": "--movement-script",
        "mutace": [
            ("chuze ma prodlevu behu (200 misto 400)",
             "return Const.RUN_MS if run else Const.WALK_MS", "return Const.RUN_MS"),
            ("krok se vykona hned (prodleva 0)",
             '"due_ms": _now() + delay', '"due_ms": _now()'),
            ("druhy krok v letu se neodmitne",
             'if _pending.has(m):', "if false:"),
            ("beh nebere staminu",
             '\tif run or _drain_model == "emulator":\n\t\tconsume_stamina(m, 1)',
             "\tif false:\n\t\tconsume_stamina(m, 1)"),
            ("emulator zapomina zbytek kroku",
             "var celkem: int = int(_carry.get(m, 0)) + steps",
             "var celkem: int = steps"),
            ("is_player se nepredava (kazdy je hrac)",
             "m == player_serial", "true"),
            ("bez staminy se porad bezi",
             "if use_run and mob.stam <= 0:", "if false:"),
        ],
    },
}


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
    ap = argparse.ArgumentParser(description="Mutacni dukaz testu")
    ap.add_argument("--only", default=None, help="sort, map nebo oboje (carkami)")
    args = ap.parse_args()
    if godot_bin() is None:
        print("CHYBA: Godot nenalezen (nastav $GODOT) - mutace by nic nemerily")
        return 2
    klice = list(MODULY) if not args.only else [k.strip() for k in args.only.split(",")]

    puvodni = {k: MODULY[k]["soubor"].read_text(encoding="utf-8") for k in MODULY}
    hash_pred = {k: sha(v) for k, v in puvodni.items()}

    # 0) baseline: bez mutace musi sada projit a NECO zmerit
    rc, vystup, checks, failures = spust(None)
    print(f"[mutace] baseline: {checks} kontrol, {failures} selhani, exit {rc}")
    if rc != 0 or failures != 0 or checks == 0:
        print("[mutace] CHYBA: baseline neprosel - mutace by nemerily nic")
        print(vystup[-2500:])
        return 2

    # 0b) smlouva o vstupu: neexistujici cesta MUSI shodit test daneho modulu
    smlouva_ok = True
    for klic in klice:
        modul = MODULY[klic]
        neexistuje = f"res://.cache/gates/mutace/neexistuje-{klic}.gd"
        rc, vystup, checks, failures = spust(f"{modul['prepinac']}={neexistuje}")
        chyceno = bool(fail_radky(vystup, modul["prefix"])) and rc != 0
        smlouva_ok = smlouva_ok and chyceno
        print(f"[mutace] smlouva vstupu {klic}: neexistujici cesta -> "
              f"{'test selhal (spravne)' if chyceno else 'TEST JI NEVIDI - CHYBA'}"
              f" | {checks} kontrol, exit {rc}")

    MUTANT_DIR.mkdir(parents=True, exist_ok=True)
    vysledek: list[tuple[str, str, bool, bool, bool, int, str]] = []
    for klic in klice:
        modul = MODULY[klic]
        zdroj = puvodni[klic]
        cesta = MUTANT_DIR / f"mutante-{klic}.gd"
        for nazev, stare, nove in modul["mutace"]:
            if stare not in zdroj:
                print(f"[mutace] {klic}: {nazev}: PATRANA VETA SE VE ZDROJI NENASLA - "
                      "mutace se neprovedla, nepocita se")
                vysledek.append((klic, nazev, False, False, False, 0, "neprovedena"))
                continue
            mutant = zdroj.replace(stare, nove, 1)
            cesta.write_text(mutant, encoding="utf-8")
            na_disku = cesta.read_text(encoding="utf-8")
            # PROVEDENA = na disku je PRESNE zamysleny text a neco se zmenilo.
            # Pozor: `stare not in mutant` tu BYT NESMI - nektere mutace obsahuji
            # puvodni text jako predponu (`.slice(0, 1)`) a jine meni jen PRVNI
            # z nekolika vyskytu (dve stejne kontroly v land_at/z_at). Obe by
            # jinak vysly jako "neprovedena", i kdyz se mutace provedla.
            provedena = mutant != zdroj and nove in mutant and na_disku == mutant
            if not provedena:
                print(f"[mutace] {klic}: {nazev}: ZMENA SE NA DISKU NEPROVEDLA")
                vysledek.append((klic, nazev, False, False, False, 0, "neoverena"))
                continue

            rc, vystup, checks, failures = spust(f"{modul['prepinac']}={uri(cesta)}")
            probehla = checks > 0
            chycena = rc != 0 and probehla and bool(fail_radky(vystup, modul["prefix"]))
            radky = fail_radky(vystup, modul["prefix"])
            if not probehla:
                poznamka = "SADA VUBEC NEPROBEHLA (0 kontrol)"
            elif radky:
                poznamka = radky[0][:110]
            else:
                poznamka = "sada selhala, ale bez FAIL tohoto modulu"
            vysledek.append((klic, nazev, provedena, probehla, chycena, checks, poznamka))
            print(f"[mutace] {klic}: {nazev}\n"
                  f"          PROVEDENA {'ano' if provedena else 'NE'} ({sha(mutant)}) | "
                  f"PROBEHLALA {'ano' if probehla else 'NE'} ({checks} kontrol, "
                  f"{failures} selhani, exit {rc}) | "
                  f"{'CHYCENA' if chycena else 'PROSLA - TEST JE SLEPY'}\n"
                  f"          {poznamka}")

    for soubor in MUTANT_DIR.glob("mutante-*.gd"):
        soubor.unlink()

    # strom se NESMI zmenit: mutuje se jen kopie, original zustava
    zmenene = [k for k in MODULY
               if sha(MODULY[k]["soubor"].read_text(encoding="utf-8")) != hash_pred[k]]
    if zmenene:
        print(f"[mutace] CHYBA: original se zmenil u {', '.join(zmenene)} - "
              "mutuje se jen kopie, toto je vada nastroje")
        return 2

    chycene = sum(1 for _, _, p, pr, c, _, _ in vysledek if p and pr and c)
    slepe = [f"{k}/{n}" for k, n, p, pr, c, _, _ in vysledek if not (p and pr and c)]
    print(f"\n[mutace] {chycene} z {len(vysledek)} mutaci chyceno"
          + (f"; NECHYCENE: {', '.join(slepe)}" if slepe else "")
          + f"; smlouva vstupu: {'OK' if smlouva_ok else 'CHYBA'}")
    return 0 if (not slepe and smlouva_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
