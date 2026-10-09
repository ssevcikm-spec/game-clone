#!/usr/bin/env python3
"""Stav a rozpory vývojového plánu (`.forge/roadmap.json`).

PROČ: roadmapa má `done: false` u VŠECH granul (stav se v ní nevede) a `--check`
generátoru kontroluje jen existenci závislostí a cykly. Plán se ale čte jako
fronta — kdo ji čte, začne znovu dělat hotovou práci. Tenhle nástroj proto
**měří**, co je hotové, a hledá rozpory, které se dají spočítat:

  1. STAV GRANULE: `owns` je v gitu? odkazuje na soubor něco v `tests/`?
     („hotovo" = soubor JE v gitu A existuje na něj test — nic víc, nic míň)
  2. ZÁVISLOST PROTI MILNÍKU: `depends_on` je v plánu POZDĚJI než závislý
  3. POKRYTÍ VLNAMI: kolik granul je zmíněno v `docs/07 §7.3`
  4. SIZE_LINES: deklarace vs skutečný počet řádků
  5. MRT VÉ DEKLARACE: `owns` soubor neexistuje (u M0–M2 to blokuje frontu)

Použití:
  python tools/plan-status.py            # lidsky citelny prehled
  python tools/plan-status.py --json     # do .cache/plan-stav.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
ROADMAPA = ROOT / ".forge" / "roadmap.json"
MILNIKY = ["M0", "M1", "M2", "M3", "M4", "MK", "M5", "M6", "M7", "M8", "M9", "MP"]
# `MK` = krátká smyčka (2026-10-09, `ROZHODNUTI-2026-10-09-SMER.md` §2 D4):
# prioritní větev vložená mezi M4 a M5 — nepotřebuje souboj ani magii.
# `MP` = hosting a malý multiplayer (2026-10-09, `ZADANI-22` + `ROZHODNUTI` §6.9
# D9): za `M9`, protože session u hostitele dává smysl, až je co hrát; hosting je
# ale změřený dopředu (`MERENI-TELEFON-2026-10-09.md`).
# Stejný seznam je v `tools/roadmap-gen.py` (`MILNIKY_PORADI`) a v `docs/07 §7.2`.
# ⚠ `M9` tady do 2026-10-08 CHYBEL, i kdyz ho `tools/roadmap-gen.py`
# (`MILNIKY_PORADI`) i `docs/07 §7.2` maji - takze se granule milniku M9
# v prehledu "po milnicich" VUBEC nezobrazovaly (a stav 0/3 se nedal precist).
PORADI = {m: i for i, m in enumerate(MILNIKY)}


def v_gitu() -> set[str]:
    for prikaz in (["git.exe", "-C", str(ROOT), "ls-files"], ["git", "-C", str(ROOT), "ls-files"]):
        try:
            out = subprocess.run(prikaz, capture_output=True, text=True, timeout=60)
            if out.returncode == 0:
                return {l.strip() for l in out.stdout.splitlines() if l.strip()}
        except Exception:
            continue
    return set()


def texty_testu() -> str:
    casti = []
    for dp, dn, fn in os.walk(ROOT / "tests"):
        dn[:] = [d for d in dn if d != "__pycache__"]
        for f in fn:
            if Path(f).suffix.lower() in (".gd", ".py", ".json"):
                try:
                    casti.append((Path(dp) / f).read_text(encoding="utf-8", errors="replace"))
                except Exception:
                    pass
    return "\n".join(casti)


def main() -> int:
    ap = argparse.ArgumentParser(description="Stav vyvojoveho planu")
    ap.add_argument("--json", action="store_true", help="zapis i .cache/plan-stav.json")
    ap.add_argument("--check", action="store_true",
                    help="spadni, kdyz je granule 'done: true' a pritom NEMERENE hotova")
    args = ap.parse_args()

    data = json.loads(ROADMAPA.read_text(encoding="utf-8"))
    grains = data["grains"]
    sledovane = v_gitu()
    testy = texty_testu()

    hotove, bez_testu, chybi = [], [], []
    for g in grains:
        owns = g.get("owns", [])
        stav = []
        for cesta in owns:
            c = cesta.rstrip("/")
            stav.append({
                "cesta": cesta,
                "existuje": (ROOT / c).exists(),
                "v_gitu": any(s == c or s.startswith(c + "/") for s in sledovane),
                "v_testu": (c in testy) or (Path(c).stem in testy),
            })
        zaznam = {"id": g["id"], "milestone": str(g.get("milestone")), "owns": owns,
                  "soubor": stav, "size_lines": g.get("size_lines"),
                  "model": g.get("model"), "acceptance": g.get("acceptance")}
        if stav and all(s["v_gitu"] for s in stav) and any(s["v_testu"] for s in stav):
            hotove.append(zaznam)
        elif stav and all(s["existuje"] for s in stav):
            bez_testu.append(zaznam)
        else:
            chybi.append(zaznam)

    print(f"granul: {len(grains)} | `done: true` v roadmape: {sum(1 for g in grains if g.get('done'))}")
    print(f"  MĚŘENĚ HOTOVÉ (v gitu + test): {len(hotove)}")
    print(f"  soubor je, test není:          {len(bez_testu)}")
    print(f"  soubor chybí:                  {len(chybi)}")
    print("\npo milnících (hotové / bez testu / chybí):")
    for m in MILNIKY:
        print(f"  {m}  {sum(1 for x in hotove if x['milestone'] == m):3d} / "
              f"{sum(1 for x in bez_testu if x['milestone'] == m):3d} / "
              f"{sum(1 for x in chybi if x['milestone'] == m):3d}")

    print("\n--- soubor je, test není (kandidáti na test, nebo acceptance 'wiring'/'assets') ---")
    for x in sorted(bez_testu, key=lambda y: (y["milestone"], y["id"])):
        print(f"  {x['id']:24s} {x['milestone']:3s} {x['owns']}")

    print("\n--- mrtvé deklarace v M0-M2 (owns soubor neexistuje) ---")
    for x in sorted(chybi, key=lambda y: (y["milestone"], y["id"])):
        if x["milestone"] in ("M0", "M1", "M2"):
            print(f"  {x['id']:24s} {x['milestone']:3s} {x['owns']}")

    print("\n--- závislost proti milníku (dep je POZDĚJI než závislý) ---")
    podle_id = {g["id"]: g for g in grains}
    rozporu = 0
    for g in grains:
        for dep in g.get("depends_on", []):
            if dep not in podle_id:
                print(f"  CHYBÍ CÍL: {g['id']} -> {dep}")
                rozporu += 1
                continue
            if PORADI.get(str(podle_id[dep].get("milestone")), 99) > PORADI.get(str(g.get("milestone")), 99):
                print(f"  {g['id']:24s} ({g.get('milestone')}) čeká na {dep:22s} "
                      f"({podle_id[dep].get('milestone')})")
                rozporu += 1
    print(f"  rozporů: {rozporu}")

    print("\n--- size_lines: deklarace vs skutečnost ---")
    prekroceni = []
    for g in grains:
        for cesta in g.get("owns", []):
            if not cesta.endswith((".gd", ".py")):
                continue
            p = ROOT / cesta
            if not p.exists():
                continue
            radku = len(p.read_text(encoding="utf-8", errors="replace").splitlines())
            m = re.search(r"<=\s*(\d+)", str(g.get("size_lines", "")))
            if m and radku > int(m.group(1)):
                prekroceni.append((radku / int(m.group(1)), g["id"], cesta, radku, int(m.group(1))))
    for pomer, gid, cesta, radku, limit in sorted(prekroceni, reverse=True):
        print(f"  {pomer:5.1f}x  {gid:24s} {cesta:36s} {radku:5d} > {limit}")
    print(f"  překročeno: {len(prekroceni)} deklarací z "
          f"{sum(1 for g in grains for c in g.get('owns', []) if c.endswith(('.gd', '.py')))}")

    d07 = (ROOT / "docs" / "07-granule-a-milniky.md").read_text(encoding="utf-8")
    i, j = d07.find("7.3"), d07.find("7.4")
    cast = d07[i:j] if i >= 0 and j > i else d07
    v_7_3 = [g["id"] for g in grains if re.search(r"\b" + re.escape(g["id"]) + r"\b", cast)]
    print(f"\npokrytí vlnami: docs/07 §7.3 zmiňuje {len(v_7_3)} z {len(grains)} granul")
    print(f"modely: {dict(Counter(str(g.get('model')) for g in grains))}")
    print(f"acceptance: {dict(Counter(a for g in grains for a in g.get('acceptance', [])))}")
    bez_testu_acc = [g["id"] for g in grains if "tests" not in g.get("acceptance", [])]
    print(f"granule bez acceptance 'tests': {len(bez_testu_acc)} "
          f"({bez_testu_acc[:6]}…)")

    if args.json:
        cil = ROOT / ".cache" / "plan-stav.json"
        cil.parent.mkdir(parents=True, exist_ok=True)
        cil.write_text(json.dumps({"hotove": hotove, "bez_testu": bez_testu, "chybi": chybi},
                                  ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"\n[plan] JSON: {cil}")

    if args.check:
        # Jedina vec, ktera je tady VADA (ne jen stav): roadmapa tvrdi "hotovo",
        # ale mereni to nepotvrzuje. Opacny smer ("hotovo a neni to v roadmape")
        # je jen stav - roadmapa se `done` nevede, proto se meri.
        hotove_ids = {h["id"] for h in hotove}
        rozpor = [g["id"] for g in grains if g.get("done") and g["id"] not in hotove_ids]
        if rozpor:
            print(f"[plan] CHYBA: {len(rozpor)} granul je `done: true`, ale nemERene "
                  f"hotovych: {rozpor}")
            return 1
        print(f"[plan] OK: 0 rozporu 'done vs nemEReno' "
              f"({len(hotove)} hotovych, {len(bez_testu)} bez testu, {len(chybi)} chybi)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
