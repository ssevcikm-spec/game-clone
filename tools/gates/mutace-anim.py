#!/usr/bin/env python3
"""Mutační důkaz pro dekodér animací (`tools/uoextract/anim.py`).

Bez tohohle je "self-test 34/0" jen dojem: kdo ví, jestli ty kontroly měří.
Harness u KAŽDÉ mutace overi CTYRI veci (stejne jako `mutace-tests.py`):

  1. PROVEDENA  - text mutace je skutecne v souboru na disku (nahrazeni proslo),
  2. PROBEHLA   - self-test dobehl a vypsal pocet kontrol (`N kontrol`),
  3. CHYCENA    - self-test (nebo sonda na realnych datech) selhal,
  4. SMLOUVA VSTUPU - nad neexistujici cestou / prazdnym blokem to spadne,
     ne ze to tiše projde.

⚠ POZOR NA REALNOU SONDU (namEReno 2026-10-07): sonda `sonda_realna_data` cte
`anim.mul` z instalace UO. **Kdyz instalace neni, vraci chybu pro KAZDY blok -
a stary harness tim prohlasil kazdou mutaci za chycenou** (8/8), i kdyz
nezmeril nic. Presne past "brana, ktera nema jak selhat". Proto se sonda pousti
i na ORIGINALE (baseline): kdyz na originalu chyby ma, do chyceni se NEPOCITA
a rekne se to (`NEMERENO`). V CI (bez instalace UO) tak harness meri jen
self-test - a je to videt.

Pouziti: python tools/gates/mutace-anim.py [--only nazev] [--install <cesta UO>]
"""

from __future__ import annotations

import argparse
import importlib.util
import io
import os
import re
import sys
from contextlib import redirect_stdout
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
ZDROJ = ROOT / "tools" / "uoextract" / "anim.py"
PRACOVNI = ROOT / ".cache" / "mutace-anim"
INSTALL = Path(os.environ.get("UO_INSTALL", r"D:\Games\Electronic Arts\Ultima Online Classic"))

# (nazev, co nahradit, cim) - kazda mutace vraci JEDNU konkretni vec do kódu.
MUTACE = [
    ("x_bez_znamenka", "return v - 1024 if v & 0x200 else v", "return v"),
    ("y_bez_vyzky_framu", "+ cy + h\n        behu += 1", "+ cy\n        behu += 1"),
    ("paleta_z_offsetu_512", 'struct.unpack_from(f"<{PALETA_BAREV}H", block, 0)',
     'struct.unpack_from(f"<{PALETA_BAREV}H", block, 512)'),
    ("barva_prohozene_kanaly", "    r = (v >> 10) & 0x1F\n    g = (v >> 5) & 0x1F\n    b = v & 0x1F",
     "    r = v & 0x1F\n    g = (v >> 5) & 0x1F\n    b = (v >> 10) & 0x1F"),
    ("terminator_jiny", "if header == MUL_TERMINATOR:", "if header == 0x7FFF7FFE:"),
    ("mimo_se_nepocita", "            else:\n                mimo += 1",
     "            else:\n                pass"),
    ("hlavicka_o_4_dal", "p = FRAME_TABLE_OFFSET + offset", "p = FRAME_TABLE_OFFSET + 4 + offset"),
    ("run_maska_0x0ff", "run = header & 0x0FFF", "run = header & 0x00FF"),
]


def nacti_modul(cesta: Path):
    # POZOR (namEReno pri psani tohohle harnessu): mutovany soubor lezi v .cache,
    # takze jeho vlastni `sys.path.insert(parent)` ukazuje na .cache - a `uop`
    # se nenajde. `ModuleNotFoundError` pritom VYPADA jako "mutace chycena".
    # Presne na tomhle stál falesny dukaz stareho `mutace-atlas.py` (LESSONS).
    sys.path.insert(0, str(ROOT / "tools" / "uoextract"))
    spec = importlib.util.spec_from_file_location("anim_mut", cesta)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def sonda_realna_data(mod, install: Path) -> list[str]:
    """Invariant na REALNYCH datech: RLE nikdy nezapisuje mimo frame.

    Tohle je to, co odlisuje spravny vyklad od drivejsiho (x bez znamenka):
    ten hlasil pixely mimo frame. Bez tehle sondy by se mutace v masce behu
    ("run_maska_0x0ff") tise prosla - v syntetickem bloku je beh maly.
    """
    chyby = []
    m = mod.MulAnim(install)
    for telo in (400, 401):
        for cislo in (0, 1, 4):
            for smer in range(5):
                info = m.block(telo, cislo, smer)
                if info is None:
                    chyby.append(f"{telo}/{cislo}/{smer}: blok neni")
                    continue
                framy = mod.decode_block(m._blok(info["offset"], info["size"]))
                if not framy:
                    chyby.append(f"{telo}/{cislo}/{smer}: zadny frame")
                    continue
                if any(not f["terminator"] for f in framy):
                    chyby.append(f"{telo}/{cislo}/{smer}: frame bez terminatoru")
                if sum(f["pixely_mimo"] for f in framy) != 0:
                    chyby.append(f"{telo}/{cislo}/{smer}: pixely mimo frame")
    return chyby


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--install", default=str(INSTALL),
                    help="cesta k instalaci UO (anim.idx + anim.mul); "
                         "lze i promennou prostredi UO_INSTALL")
    args = ap.parse_args()
    install = Path(args.install)

    original = ZDROJ.read_text(encoding="utf-8")
    PRACOVNI.mkdir(parents=True, exist_ok=True)

    # 0) BASELINE realne sondy - viz hlavicka. Bez tohohle je "8/8 chyceno"
    #    pravda i na stroji, kde sonda nemeri nic (chybi anim.mul).
    real_ok = False
    if (install / "anim.idx").exists() and (install / "anim.mul").exists():
        try:
            zaklad = nacti_modul(ZDROJ)
            zakladni = sonda_realna_data(zaklad, install)
        except Exception as exc:                       # rozbita data / cteni
            print(f"[mutace] CHYBA: baseline realne sondy spadla: {type(exc).__name__}: {exc}")
            return 1
        if zakladni:
            print(f"[mutace] CHYBA: baseline realne sondy ma {len(zakladni)} chyb "
                  f"(na ORIGINALE) - sonda by 'chytila' kazdou mutaci:")
            for c in zakladni[:5]:
                print(f"[mutace]   {c}")
            return 1
        real_ok = True
        print("[mutace] baseline realne sondy: 0 chyb (sonda se pocita do chyceni)")
    else:
        print(f"[mutace] NEMERENO: realna sonda neni - chybi {install / 'anim.idx'} / "
              f"{install / 'anim.mul'} (meri se JEN self-test; da se predat --install)")

    chycene = 0
    chyby: list[str] = []
    for nazev, stary, novy in MUTACE:
        if args.only and args.only != nazev:
            continue
        if stary not in original:
            chyby.append(f"{nazev}: VZOR NENALEZEN - mutace se neprovedla (text se zmenil?)")
            continue
        cesta = PRACOVNI / f"anim_{nazev}.py"
        cesta.write_text(original.replace(stary, novy, 1), encoding="utf-8")
        # 1) PROVEDENA: text na disku musi mit novou podobu a jinou velikost
        na_disku = cesta.read_text(encoding="utf-8")
        provedena = (novy in na_disku) and (na_disku != original)
        try:
            mod = nacti_modul(cesta)
        except Exception as exc:
            # Selhany IMPORT neni chycena mutace - je to vada harnessu.
            print(f"[mutace] {nazev:24s} HARNESS CHYBA pri nacitani: {exc}")
            chyby.append(f"{nazev}: modul se nenacetl ({exc})")
            cesta.unlink()
            continue
        buf = io.StringIO()
        spadlo = ""
        try:
            with redirect_stdout(buf):
                kod = mod.self_test()
        except Exception as exc:                     # mutace muze i spadnout
            kod = 1
            spadlo = type(exc).__name__
            buf.write(f"vyjimka: {exc}")
        vystup = buf.getvalue()
        m = re.search(r"self-test:\s*(\d+)\s*kontrol,\s*(\d+)\s*chyb", vystup)
        probehla = bool(m) and int(m.group(1)) > 0
        chycena_selftestem = kod != 0 and bool(m) and int(m.group(2)) > 0
        # Vyjjimka UVNITR self-testu je taky chyceni (kod je rozbity a je to
        # videt), ale musi byt POJMENOVANA - nesmi splatnout s chybou harnessu
        # (presne tak vypadal falesny dukaz stareho `mutace-atlas.py`).
        if spadlo:
            chycena_selftestem = True
        # Realna sonda se pocita JEN kdyz je baseline cista (viz krok 0).
        real = sonda_realna_data(mod, install) if real_ok else []
        chycena = chycena_selftestem or bool(real)
        kontroly = m.group(1) if m else "?"
        chyb = m.group(2) if m else "?"
        stav = "CHYCENA" if chycena else "PROSLABY"
        sonda = f"realna sonda: {len(real)} chyb" if real_ok else "realna sonda: NEMERENA"
        print(f"[mutace] {nazev:24s} provedena={provedena} probehla={probehla} "
              f"({kontroly} kontrol, {chyb} chyb self-testu, {sonda}"
              f"{', spadlo: ' + spadlo if spadlo else ''}) -> {stav}")
        if not (provedena and (probehla or spadlo) and chycena):
            chyby.append(f"{nazev}: provedena={provedena} probehla={probehla} chycena={chycena}")
        else:
            chycene += 1
        cesta.unlink()

    # 4) SMLOUVA O VSTUPU: prazdny a nesmyslny vstup nesmi projit ani projit tise
    mod = nacti_modul(ZDROJ)
    smlouva = (mod.decode_frame(b"", 0) is None and mod.decode_block(b"") == []
               and mod.decode_frame(bytes(600), 0) is None)
    print(f"[mutace] smlouva o vstupu (prazdny blok -> None/[], ne vyjimka): {smlouva}")
    if not smlouva:
        chyby.append("smlouva o vstupu: prazdny vstup neprosel")

    print(f"[mutace] {chycene}/{len([m for m in MUTACE if not args.only or m[0] == args.only])} "
          f"mutaci chyceno ({'self-test + realna sonda' if real_ok else 'JEN self-test - realna sonda NEMERENA'}), "
          f"{len(chyby)} chyb")
    for c in chyby:
        print(f"[mutace] CHYBA: {c}")
    return 1 if chyby else 0


if __name__ == "__main__":
    raise SystemExit(main())
