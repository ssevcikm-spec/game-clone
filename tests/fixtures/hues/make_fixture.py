#!/usr/bin/env python3
"""Vygeneruje maly fixture hues pro test render.hue (tests/fixtures/hues/).

PROC: `assets/uo/` je v .gitignore, takze v CI zadny `hues.json` NENI. Cast C)
testu `tests/cases/render_hue.gd` se pak preskoci - a nekolik mutaci
(`tools/gates/mutace-render-hue.py`) by v CI "proslo", protoze by je nemelo co
chytit. Fixture je v GITU, deterministicka, a test proti ni bezi VZDY.

ODKUD DATA JSOU (a co z toho plyne):
  * Zdroj: `assets/uo/hues.json` (na vyvojarskem disku JE; 672 443 B, 3000 sad).
    Ten vznikl z instalace UO - `hues.mul` (265 500 B) - nastrojem
    `tools/uoextract/hues.py`: 375 skupin x (4 B hlavicka + 8 x 88 B zaznam)
    = 3000 sad, zaznam = 32 x u16 barva + start + end + 20 B jmeno.
  * Do fixture jsou z realneho souboru prenesene PRESNE DVE sady, a to ty, na
    kterych stoji test i hra: index 1001 = sada `1002` = "SkinHue #1001"
    (v `render/hue_cache.gd` je to `HUE_SKIN`) a index 1002 = sada `1003`.
    Jejich `colors`, `start`, `end`, `group` a `name` jsou opsane 1:1
    (2026-10-07); nic se nepocita ani nezaokrouhluje.
  * Vsechno ostatni je VYPLNOVA sada (32 nul, prazdne jmeno) - slouzi jen k
    tomu, aby sada 1002 lezela na indexu 1001. Index je totiz PRIMO `hue - 1`
    (`_sets[hue - 1]` v `render/hue_cache.gd`), takze bez 1002 zaznamu by se
    sada 1002 vubec nenasla. Odtud plyne i velikost fixture (1003 zaznamu).
  * Fixture NENI produkcni data: nesmi se pouzit pro hru, jen pro test. Je to
    i videt v souboru (klic `fixture`).

FORMAT (overeno na realnem souboru 2026-10-07):
  * top-level: `layout` (groups/record_bytes/records), `sets`, `version` (+ ve
    fixture navic `fixture` s puvodem),
  * zaznam sady: `colors` (32 x u16, 5bitove kanaly `R=(c>>10)&31`,
    `G=(c>>5)&31`, `B=c&31`), `end`, `group`, `name`, `set`, `start`,
  * `partial_hue` v TOMTO FORMATU NENI - je to parametr volani
    `hued(base, hue, partial_hue)` (mod PARTIAL_HUED v ClassicUO), ne pole
    zaznamu. Fixture ho proto nenese; test ho meri na pixelech za behu.

Pouzij:
  python tests/fixtures/hues/make_fixture.py           # zapise soubor
  python tests/fixtures/hues/make_fixture.py --check   # jen overi (pro CI)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parent
CIL = DIR / "hues.json"

# Pocet sad ve fixture: 1001 vyplnovych (index 0..1000) + sada 1002 (index 1001)
# + sada 1003 (index 1002). Mene nez 1002 zaznamu nejde - sada 1002 by nemela
# kam lehnout (viz PROC v hlavicce).
SETS = 1003

# Realne sady opsane z `assets/uo/hues.json` (index v poli -> zaznam).
REALNE = {
    1001: {
        "colors": [1, 1, 1058, 2114, 3139, 4196, 5252, 6309, 7334, 8390, 9447,
                   9447, 10504, 11561, 12617, 13642, 14699, 15755, 16780, 17836,
                   18893, 19950, 19950, 21007, 22064, 23088, 24145, 25201, 26258,
                   27283, 28339, 29396],
        "end": 30453,
        "group": 125,
        "name": "SkinHue #1001",
        "set": 1001,
        "start": 1,
    },
    1002: {
        "colors": [1, 1, 1058, 2082, 3139, 4195, 5220, 5252, 6309, 7334, 8390,
                   9447, 10471, 10504, 11560, 12585, 13642, 14698, 15723, 16779,
                   16812, 17836, 18893, 19949, 20974, 22031, 22063, 23088, 24144,
                   25201, 26225, 27282],
        "end": 28339,
        "group": 125,
        "name": "SkinHue #1002",
        "set": 1002,
        "start": 1,
    },
}

LAYOUT = {"groups": 375, "record_bytes": 88, "records": 8}

# Hlaseni, na kterem stoji `--check` i hlavicka: kdyz se zmeni, meni se i test.
MARK_FIXTURE = ("tests/fixtures/hues/make_fixture.py - NENI produkcni data; "
                "sady 1002 a 1003 opsane z assets/uo/hues.json")


def vyplnova(i: int) -> dict:
    """Vyplnova sada: struktura stejna jako realna, hodnoty zamerne nulove."""
    return {"colors": [0] * 32, "end": 0, "group": i // 8, "name": "",
            "set": i, "start": 0}


def zaznamy() -> list[dict]:
    out: list[dict] = []
    for i in range(SETS):
        out.append(REALNE.get(i, None) or vyplnova(i))
    return out


def obsah() -> bytes:
    # `sort_keys` a kompaktni separatory = stejny tvar, jaky ma realny soubor
    # (klice v zaznamu jsou tam tez abecedne). Zadny newline na konci, aby
    # `--check` porovnaval bajty a ne "skoro bajty".
    doc = {
        "fixture": MARK_FIXTURE,
        "layout": LAYOUT,
        "sets": zaznamy(),
        "version": 1,
    }
    return json.dumps(doc, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":")).encode("utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Fixture hues pro render.hue")
    ap.add_argument("--check", action="store_true", help="jen overit, nezapisovat")
    args = ap.parse_args()
    data = obsah()
    hash_disk = hashlib.sha256(CIL.read_bytes()).hexdigest()[:12] if CIL.exists() else "CHYBI"
    hash_new = hashlib.sha256(data).hexdigest()[:12]
    if args.check:
        ok = hash_disk == hash_new
        print(f"[fixture] {'OK  ' if ok else 'JINA'} {CIL.name}: "
              f"disk {hash_disk}, generator {hash_new} ({len(data)} B)")
        if not ok:
            print("[fixture] soubor na disku neodpovida generatoru - "
                  "spust `python tests/fixtures/hues/make_fixture.py`")
            return 1
        return 0
    CIL.write_bytes(data)
    print(f"[fixture] zapsano {CIL}: {len(data)} B, {SETS} sad, sha256 {hash_new}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
