#!/usr/bin/env python3
"""Mutacni dukaz testu `data.skills` (tests/cases/skills_data.gd, docs/09 §9.6 bod 3).

PROC: zeleny test bez mutace neznamena, ze test meri. Do KOPIE `data/skills.json`
se vraci vada a test ji musi chytit. U kazde mutace se overuji TRI veci ZVLAST
(bez nich je "spadlo" jen dohad):

  1. PROVEDENA  - text na DISKU je opravdu mutant (jine bajty + zapsany hash),
  2. PROBEHLALA - testovaci sada vubec probehla: "N kontrol, M selhani" s N > 0,
  3. CHYCENA    - exit != 0 a aspon jeden radek "[test] FAIL data.skills ...",
                  tedy selhala kontrola TOHOTO modulu (ne neco jineho).

Navic se delaji tri behy, ktere bez mutace nic neznamenaji:
  * BASELINE nad `data/skills.json` - test na zdravych datech NESMI hlásit
    "data.skills" vadu (jinak by "mutace spadla" znamenalo neco jineho),
  * KONTROLNI BEH nad KOPII bez mutace - kdyby test kopii neumel precist,
    kazda mutace by "prosla" z nespravneho duvodu (HANDOFF 2026-10-06, past 2),
  * SMLOUVA O VSTUPU - neexistujici cesta predana pres `-- --skills-data=` MUSI
    test shodit. Kdyby neselhal, test by meril porad vychozi soubor a mutace
    by "prochazely" (totez jako u tools/gates/mutace-tests.py).

POZOR: testovaci sada muze mit selhani i z jinych granul (jde o cely strom) -
proto se CHYCENI pozna VYHRADNE z radku s prefixem "data.skills", ne z exit kodu
samotneho. Original na disku se NESMI zmenit: mutuje se jen kopie v .cache/.

  python tools/gates/mutace-skills.py            # vsechny mutace
  python tools/gates/mutace-skills.py --only implemented
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import godot_bin, godot_run  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TESTS = "res://tests/run_tests.gd"
ZDROJ = ROOT / "data" / "skills.json"
KOPIE_DIR = ROOT / ".cache" / "gates" / "mutace-skills"
KOPIE = KOPIE_DIR / "skills.json"
PREFIX = "data.skills"
SOUHRN = re.compile(r"(\d+)\s+kontrol,\s*(\d+)\s+selh")


# --- mutace: kazda vraci (klic, popis) a sama si overi, ze dosahla PODMINKY ---
# (ne jen ze zmenila text - to je past ze skillu `overovani` §7.14)

def mut_uber_skill(z: list[dict]) -> tuple[str, str]:
    z.pop(25)
    assert len(z) == 57, "skill neubyl"
    return "uber", "uber jeden skill (Magery, id 25)"


def mut_prehod_id(z: list[dict]) -> tuple[str, str]:
    z[10], z[11] = z[11], z[10]
    assert [r["id"] for r in z] != list(range(len(z))), "poradi id se nezmenilo"
    return "poradi", "prehozene poradi zaznamu 10 a 11 (id != index)"


def mut_prehod_jmena(z: list[dict]) -> tuple[str, str]:
    z[0]["name"], z[1]["name"] = z[1]["name"], z[0]["name"]
    assert z[0]["name"] == "Anatomy" and z[1]["name"] == "Alchemy", "jmena se neprehodila"
    return "jmena", "prehozena jmena id 0 a 1 (Alchemy <-> Anatomy)"


def mut_true_na_false(z: list[dict]) -> tuple[str, str]:
    z[48]["implemented"] = False
    assert z[48]["implemented"] is False, "implemented se nezmenil"
    return "implemented", "implemented: true -> false u id 48 (Remove Trap)"


def mut_false_na_true(z: list[dict]) -> tuple[str, str]:
    z[49]["implemented"] = True
    assert z[49]["implemented"] is True, "implemented se nezmenil"
    return "implemented", "implemented: false -> true u id 49 (Necromancy)"


def mut_stat(z: list[dict]) -> tuple[str, str]:
    z[0]["stat_primary"] = "str"
    assert z[0]["stat_primary"] == "str", "stat se nezmenil"
    return "stat", "stat: Alchemy primary int -> str"


def mut_skupina(z: list[dict]) -> tuple[str, str]:
    z[1]["group_id"] = 5
    assert z[1]["group_id"] == 5, "skupina se nezmenila"
    return "skupina", "skupina: Anatomy group_id 1 -> 5 (nazev zustava 'Combat')"


def mut_era(z: list[dict]) -> tuple[str, str]:
    z[49]["era"] = "pre-aos"
    assert z[49]["era"] == "pre-aos", "era se nezmenila"
    return "era", "era: Necromancy aos -> pre-aos (a implemented zustava false)"


MUTACE = [mut_uber_skill, mut_prehod_id, mut_prehod_jmena, mut_true_na_false,
          mut_false_na_true, mut_stat, mut_skupina, mut_era]


def sha(bajty: bytes) -> str:
    return hashlib.sha256(bajty).hexdigest()[:12]


def uri(cesta: Path) -> str:
    return "res://" + cesta.relative_to(ROOT).as_posix()


def zapis(zaznamy: list[dict]) -> bytes:
    """Stejny zapis jako generator (`gen-content.py: bajty()`) - mutant se smi
    lisit obsahem, ne formatovanim."""
    return json.dumps(zaznamy, ensure_ascii=False, indent=1,
                      sort_keys=True).encode("utf-8") + b"\n"


def spust(extra: str | None) -> tuple[int, str, int, int]:
    args = ["--script", TESTS]
    if extra:
        args += ["--", extra]
    rc, vystup = godot_run(ROOT, args, timeout=900)
    match = SOUHRN.search(vystup)
    checks, failures = (int(match.group(1)), int(match.group(2))) if match else (0, 0)
    return rc, vystup, checks, failures


def fail_radky(vystup: str) -> list[str]:
    return [line.strip() for line in vystup.splitlines()
            if line.strip().startswith("[test] FAIL") and PREFIX in line]


def main() -> int:
    ap = argparse.ArgumentParser(description="Mutacni dukaz testu data.skills")
    ap.add_argument("--only", default=None,
                    help="jen mutace s timto klicem (uber, poradi, jmena, "
                         "implemented, stat, skupina, era)")
    args = ap.parse_args()
    if godot_bin() is None:
        print("CHYBA: Godot nenalezen (nastav $GODOT) - mutace by nic nemerily")
        return 2
    if not ZDROJ.exists():
        print(f"CHYBA: {ZDROJ} neexistuje - spust "
              "`python tools/gates/gen-content.py --only skills`")
        return 2

    original = ZDROJ.read_bytes()
    puvodni_hash = sha(original)
    zaznamy_orig = json.loads(original.decode("utf-8"))
    if not isinstance(zaznamy_orig, list) or len(zaznamy_orig) != 58:
        print(f"CHYBA: {ZDROJ} neni seznam 58 zaznamu - mutace by merily neco jineho")
        return 2

    KOPIE_DIR.mkdir(parents=True, exist_ok=True)

    # 0) baseline: zdrava data v repu - test NESMI hlásit vadu "data.skills"
    rc, vystup, checks, failures = spust(None)
    vadne = fail_radky(vystup)
    print(f"[mutace] baseline: {checks} kontrol, {failures} selhani, exit {rc}, "
          f"vad '{PREFIX}': {len(vadne)}")
    if checks == 0:
        print("[mutace] CHYBA: sada vubec neprobehla (0 kontrol)")
        return 2
    if vadne:
        print("[mutace] CHYBA: baseline hlasi vadu v 'data.skills' - mutace by nemerily nic:")
        for line in vadne[:3]:
            print("   ", line[:150])
        return 2

    # 0b) kontrolni beh nad KOPII bez mutace: jinak by "mutace spadla" mohlo
    #     znamenat jen to, ze test kopii neprecte (past 2 z HANDOFFu).
    KOPIE.write_bytes(original)
    rc, vystup, checks, failures = spust(f"--skills-data={uri(KOPIE)}")
    vadne = fail_radky(vystup)
    print(f"[mutace] kontrola kopie bez mutace: {checks} kontrol, {failures} selhani, "
          f"exit {rc}, vad '{PREFIX}': {len(vadne)}")
    if checks == 0 or vadne:
        print("[mutace] CHYBA: test neumi precist KOPII pres --skills-data - "
              "mutace by 'prochazely' z nespravneho duvodu")
        for line in vadne[:3]:
            print("   ", line[:150])
        return 2

    # 0c) smlouva o vstupu: neexistujici cesta MUSI test shodit
    neexistuje = uri(KOPIE_DIR / "neexistuje.json")
    rc, vystup, checks, failures = spust(f"--skills-data={neexistuje}")
    vadne = fail_radky(vystup)
    smlouva_ok = rc != 0 and checks > 0 and bool(vadne)
    print(f"[mutace] smlouva vstupu: neexistujici cesta -> "
          f"{'test selhal (spravne)' if smlouva_ok else 'TEST JI NEVIDI - CHYBA'} "
          f"| {checks} kontrol, exit {rc}")
    if not smlouva_ok:
        print("[mutace] CHYBA: test meri i s neexistujici cestou - vstup ignoruje")
        return 2

    vysledek: list[tuple[str, str, bool, bool, bool, int, str]] = []
    for funkce in MUTACE:
        mutant_zaznamy = copy.deepcopy(zaznamy_orig)
        klic, nazev = funkce(mutant_zaznamy)
        if args.only and args.only not in (klic, nazev):
            continue
        bajty = zapis(mutant_zaznamy)
        KOPIE.write_bytes(bajty)
        na_disku = KOPIE.read_bytes()

        # PROVEDENA = na DISKU je mutant (jine bajty + tentýž hash) a menena
        # PODMINKA prestala platit (to si overila sama mutace vyse).
        provedena = na_disku == bajty and na_disku != original
        if not provedena:
            print(f"[mutace] {klic}: {nazev}: ZMENA SE NA DISKU NEPROVEDLA")
            vysledek.append((klic, nazev, False, False, False, 0, "neoverena"))
            continue

        rc, vystup, checks, failures = spust(f"--skills-data={uri(KOPIE)}")
        radky = fail_radky(vystup)
        probehla = checks > 0
        chycena = rc != 0 and probehla and bool(radky)
        if not probehla:
            poznamka = "SADA VUBEC NEPROBEHLA (0 kontrol)"
        elif radky:
            poznamka = radky[0][:110]
        else:
            poznamka = "sada selhala, ale bez FAIL radku 'data.skills'"
        vysledek.append((klic, nazev, provedena, probehla, chycena, checks, poznamka))
        print(f"[mutace] {klic}: {nazev}\n"
              f"          PROVEDENA {'ano' if provedena else 'NE'} ({sha(na_disku)}) | "
              f"PROBEHLALA {'ano' if probehla else 'NE'} ({checks} kontrol, "
              f"{failures} selhani, exit {rc}) | "
              f"{'CHYCENA' if chycena else 'PROSLA - TEST JE SLEPY'}\n"
              f"          {poznamka}")

    # uklid: kopie se smaze, original zustava
    shutil.rmtree(KOPIE_DIR, ignore_errors=True)
    if ZDROJ.read_bytes() != original:
        print(f"[mutace] CHYBA: original {ZDROJ.name} se zmenil - "
              "mutuje se jen kopie, toto je vada nastroje")
        return 2

    chycene = sum(1 for _, _, p, pr, c, _, _ in vysledek if p and pr and c)
    slepe = [f"{k}/{n}" for k, n, p, pr, c, _, _ in vysledek if not (p and pr and c)]
    print(f"\n[mutace] {chycene} z {len(vysledek)} mutaci chyceno"
          + (f"; NECHYCENE: {', '.join(slepe)}" if slepe else "")
          + f"; original {ZDROJ.name} sha256 {puvodni_hash} (nezmenen)")
    return 0 if not slepe else 1


if __name__ == "__main__":
    sys.exit(main())
