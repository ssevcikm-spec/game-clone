#!/usr/bin/env python3
"""DAVKA - prace pro PEAK hodiny DeepSeeku.

PROC TO EXISTUJE: ve spicce je cena tokenu dvojnasobna (viz skill
`dsh-peak-uspory`), ale jen za to, co projde modelem. Stroj muze pracovat dal.
Tahle davka je presne to, co se ve spicce pousti: beh, ktery v projektu nic
 nemeni a jen meri - a na konci rekne stav jednou tabulkou.

CO DAVKA NEDELA: nemeni zdrojove soubory. Brany pisou do `.cache/` (gitignore)
a mutacni testy si mutanta zapisuji do `.cache/gates/mutace/`, ne do stromu -
overeno 12. 10. 2026 v `tools/gates/mutace-tests.py:1689`
(`cesta = MUTANT_DIR / f"mutante-{klic}.gd"`).

DVE VECI, KTERE SE TU MUSELY OSETRIT (obe overene, ne predpokladane):
  * `bash` na teto stanici NENI -> `tools/gates/ci-godot.sh` spustit nelze.
    Godot cast brany proto jede pres `run-all.py`, ktera si `APPDATA` nastavuje
    sama (`gate_common.py`: `OUT_DIR = ROOT/.cache/gates`).
  * `run-all.py` vraci **2**, kdyz neco zustalo NEMERENO. To NENI zelena -
    souhrn to vypise a je to videt i v navratovem kodu teto davky.

POZOR PRI SOUBEHU S JINOU SESSION: brany sdileji `.cache/gates/`. Logy teto
davky jdou do `.cache/davka/`, takze se nemichaji, ale kdyz brany spusti dve
session soucasne, prepisuji si navzajem sve JSON vysledky.

SPOUSTENI:
  python tools/davka.py                # vsechno
  python tools/davka.py --dry          # jen vypis kroku
  python tools/davka.py --only mutace  # jen kroky, jejichz nazev obsahuje text
  python tools/davka.py --rychle       # vynecha mutacni testy (nejdelsi cast)
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT / ".cache" / "davka"
PY = sys.executable

# (nazev, prikaz, timeout v sekundach)
# Poradi kopiruje `.github/workflows/ci.yml`, aby lokalni beh a CI merily totéž.
KROKY: list[tuple[str, list[str], int]] = [
    ("01-brany-vsechny", [PY, "tools/gates/run-all.py"], 1800),
    ("02-brany-selftest", [PY, "tools/gates/run-all.py", "--self-test"], 1800),
    ("03-fixture-world", [PY, "tests/fixtures/world/make_fixture.py", "--check"], 600),
    ("04-fixture-hues", [PY, "tests/fixtures/hues/make_fixture.py", "--check"], 600),
    ("05-fixture-anim", [PY, "tests/fixtures/anim/make_fixture.py", "--check"], 600),
    ("06-plan-stav", [PY, "tools/plan-status.py", "--check"], 600),
    ("07-docs-odkazy", [PY, "tools/check-docs-refs.py"], 600),
    ("08-cesty-k-datum", [PY, "tools/check-data-paths.py"], 600),
    ("09-zadani", [PY, "tools/check-zadani.py"], 600),
    # ⚠ 3600 s NESTACI. NamEReno 12. 10. 2026: 6494 s (329 mutaci, ~20 s na
    # mutaci). Kratky limit nevyrobi "vadu", ale "NEMERENO" - a to se ve souhrnu
    # snadno prehlédne jako hotove. Proto 3 hodiny.
    ("10-mutace-tests", [PY, "tools/gates/mutace-tests.py"], 10800),
    ("11-mutace-skills", [PY, "tools/gates/mutace-skills.py"], 1800),
    ("12-mutace-render-hue", [PY, "tools/gates/mutace-render-hue.py"], 1800),
    ("13-mutace-render-anim", [PY, "tools/gates/mutace-render-anim.py"], 1800),
    ("14-mutace-anim", [PY, "tools/gates/mutace-anim.py"], 1800),
]

# Vyznam navratovych kodu, ktere neni bezne (0/1 zná kazdy).
VYZNAM = {
    2: "NEMERENO - brana nemela co merit (NENI zelena)",
    -9: "TIMEOUT - krok nedobehl v limitu",
}


def prostredi() -> dict[str, str]:
    """Godot potrebuje `APPDATA` ve workspace, jinak hlasi FALESNA selhani."""
    env = dict(os.environ)
    userdata = ROOT / ".cache" / "godot-appdata"
    env["APPDATA"] = str(userdata)
    env["XDG_DATA_HOME"] = str(userdata)
    return env


def posledni_radek(cesta: Path, limit: int = 100) -> str:
    """Posledni NEprazdny radek logu - staci na souhrn, nemusi se cist cely."""
    try:
        radky = [r.strip() for r in cesta.read_text(encoding="utf-8", errors="replace").splitlines()]
    except OSError:
        return "(log se nepodarilo precist)"
    for radek in reversed(radky):
        if radek:
            return radek[:limit]
    return "(log je prazdny - krok nic nevypisal)"


def main() -> int:
    ap = argparse.ArgumentParser(description="Davka prace pro peak hodiny (jen meri, nemeni strom).")
    ap.add_argument("--dry", action="store_true", help="jen vypis kroky")
    ap.add_argument("--only", default=None, help="spust jen kroky obsahujici tento text")
    ap.add_argument("--rychle", action="store_true", help="vynech mutacni testy")
    ap.add_argument("--timeout-mult", type=float, default=1.0, help="nasobek vsech limitu")
    args = ap.parse_args()

    kroky = [(n, c, t) for (n, c, t) in KROKY
             if (args.only is None or args.only in n)
             and not (args.rychle and "mutace" in n)]
    if not kroky:
        print("Zadny krok neodpovida filtru - nic by se nespustilo. (Neni to uspech.)")
        return 3

    if args.dry:
        print(f"Koren: {ROOT}")
        for nazev, prikaz, timeout in kroky:
            print(f"  {nazev:24} limit {timeout:5} s  ->  {' '.join(prikaz)}")
        return 0

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    env = prostredi()
    vysledky = []
    zacatek = time.time()

    print(f"DAVKA: {len(kroky)} kroku, logy do {LOG_DIR}")
    print(f"Python: {PY}")
    print("-" * 78, flush=True)

    for nazev, prikaz, timeout in kroky:
        log = LOG_DIR / f"{nazev}.log"
        limit = int(timeout * args.timeout_mult)
        t0 = time.time()
        kod: int | str = -9
        try:
            # Vystup jde do SOUBORU, ne do roury - v sandboxu by roury spadly na EPERM.
            with log.open("w", encoding="utf-8", errors="replace") as f:
                hotovo = subprocess.run(prikaz, cwd=ROOT, env=env, stdout=f,
                                        stderr=subprocess.STDOUT, timeout=limit, check=False)
            kod = hotovo.returncode
        except subprocess.TimeoutExpired:
            kod = -9
        except OSError as e:
            kod = f"CHYBA: {e}"
        trvani = time.time() - t0
        vysledky.append({"krok": nazev, "kod": kod, "sekund": round(trvani, 1),
                         "log": str(log.relative_to(ROOT)), "posledni": posledni_radek(log)})
        znamka = VYZNAM.get(kod, "OK" if kod == 0 else "VADA")
        print(f"[{nazev:24}] exit {str(kod):>4}  {trvani:7.1f} s  {znamka}", flush=True)

    souhrn = LOG_DIR / "souhrn.json"
    souhrn.write_text(json.dumps(vysledky, ensure_ascii=False, indent=2), encoding="utf-8")

    print("-" * 78)
    print(f"Celkem {time.time() - zacatek:.0f} s. Souhrn: {souhrn.relative_to(ROOT)}")
    print()
    print(f"{'krok':26} {'exit':>5} {'sekund':>8}  posledni radek logu")
    for v in vysledky:
        print(f"{v['krok']:26} {str(v['kod']):>5} {v['sekund']:>8.1f}  {v['posledni']}")

    vady = [v for v in vysledky if v["kod"] != 0]
    if not vady:
        print("\nVsechny kroky prosly (exit 0).")
        return 0
    if all(v["kod"] == 2 for v in vady):
        print("\nNeco zustalo NEMERENO (exit 2) - to NENI zelena, jen to neni vada.")
        return 2
    print(f"\nKroku s vadou nebo chybou: {len(vady)} - podrobnosti v logach.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
