#!/usr/bin/env python3
"""Rozhodujici test O3: pokryti tela v anim*.mul vs AnimationFrame*.uop.

Otazka ze zadani (docs/03 §3.5.1, O3): ktery zdroj animaci je nosny?
Sonda meri oba a rozhodnuti se dela z CISEL, ne z doporuceni v dokumentu.

Co se meri:
  * MUL: pro kazde telo 0..2047 se podle skupiny (ClassicUO CalculateOffset,
    BSD-2) precte z anim.idx pocet (akce, smer) bloku, ktere maji data
    (Position > 0, Size > 0, Position + Size <= velikost anim.mul).
  * UOP: pro kazde telo a akci 0..79 se spocte hash jmena
    "build/animationlegacyframe/{telo:06d}/{akce:02d}.bin" a zjisti se, ve
    kterem z AnimationFrame1..10.uop je zaznam. Meri se vsechny tri kandidaty
    na hash (uop.py, R1), aby se potvrdilo, ktera funkce na animace sedi.

Pouziti:
  python research/probe/anim_pokryti.py            # JSON do research/anim-pokryti.json
  python research/probe/anim_pokryti.py --telo 400 # detail jednoho tela
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "uoextract"))
from uop import UopFile, create_hash, hashlittle2  # noqa: E402

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
OUT = ROOT / "research" / "anim-pokryti.json"

IDX_BLOCK = 12
DIRS = 5
MAX_ACTIONS = 80          # UOP: "gargoyle is like 78" (ClassicUO MAX_ACTIONS)
MUL_BODIES = 2048
HIGH_ACTIONS = 22         # monstra (telo < 200), skupina HIGH
LOW_ACTIONS = 13          # zvirata (200..399), skupina LOW
PEOPLE_ACTIONS = 35       # lide (400+), skupina PEOPLE
UOP_NAME = "build/animationlegacyframe/{0:06d}/{1:02d}.bin"


def mul_offset(body: int) -> tuple[int, int]:
    """(offset v anim.idx, pocet akci) pro telo - podle skupiny."""
    if body < 200:
        return body * 110 * IDX_BLOCK, HIGH_ACTIONS
    if body < 400:
        return ((body - 200) * 65 + 22000) * IDX_BLOCK, LOW_ACTIONS
    return ((body - 400) * 175 + 35000) * IDX_BLOCK, PEOPLE_ACTIONS


def mul_pokryti(install: Path) -> dict[int, dict]:
    idx = (install / "anim.idx").read_bytes()
    mul_size = (install / "anim.mul").stat().st_size
    pokryti: dict[int, dict] = {}
    for body in range(MUL_BODIES):
        off, akci = mul_offset(body)
        bloku = 0
        akce = set()
        for a in range(akci):
            for d in range(DIRS):
                poz = off + (a * DIRS + d) * IDX_BLOCK
                if poz + IDX_BLOCK > len(idx):
                    continue
                p, s, _u = struct.unpack_from("<III", idx, poz)
                if s > 0 and p > 0 and p != 0xFFFFFFFF and p + s <= mul_size:
                    bloku += 1
                    akce.add(a)
        pokryti[body] = {"akci": len(akce), "bloku": bloku, "akce_seznam": sorted(akce)}
    return pokryti


def uop_pokryti(install: Path) -> tuple[dict[int, dict], dict[str, int]]:
    soubory: list[tuple[int, set[int]]] = []
    for i in range(1, 11):
        cesta = install / f"AnimationFrame{i}.uop"
        if not cesta.exists():
            continue
        u = UopFile(cesta)
        u.read_entries()
        soubory.append((i, {e.hash for e in u.entries if e.hash}))
    if not soubory:
        return {}, {}

    # ktera hash funkce na animace sedi (mereno na vzorku tel 0..699)
    shoda = {"classicuo_create_hash": 0, "jenkins_pc_pb": 0, "jenkins_pb_pc": 0}
    for body in range(700):
        for action in range(MAX_ACTIONS):
            jmeno = UOP_NAME.format(body, action)
            pc, pb = hashlittle2(jmeno.encode("latin-1"), 0, 0)
            hodnoty = {
                "classicuo_create_hash": create_hash(jmeno),
                "jenkins_pc_pb": ((pc << 32) | pb) & 0xFFFFFFFFFFFFFFFF,
                "jenkins_pb_pc": ((pb << 32) | pc) & 0xFFFFFFFFFFFFFFFF,
            }
            for jmeno_f, hodnota in hodnoty.items():
                if any(hodnota in h for _i, h in soubory):
                    shoda[jmeno_f] += 1
    rezim = max(shoda, key=lambda k: shoda[k])

    pokryti: dict[int, dict] = {}
    for body in range(MUL_BODIES):
        akce = []
        for action in range(MAX_ACTIONS):
            jmeno = UOP_NAME.format(body, action)
            pc, pb = hashlittle2(jmeno.encode("latin-1"), 0, 0)
            hodnota = (create_hash(jmeno) if rezim == "classicuo_create_hash"
                       else ((pc << 32) | pb) & 0xFFFFFFFFFFFFFFFF)
            for i, h in soubory:
                if hodnota in h:
                    akce.append(action)
                    break
        pokryti[body] = {"akci": len(akce), "akce_seznam": akce}
    return pokryti, shoda


def main() -> int:
    ap = argparse.ArgumentParser(description="Rozhodujici test O3 (zdroj animaci)")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--telo", type=int, default=None)
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    install = Path(args.install)
    if not (install / "anim.idx").exists():
        print(f"[anim] CHYBA: {install} neobsahuje anim.idx")
        return 1

    mul = mul_pokryti(install)
    uop, shoda = uop_pokryti(install)
    mul_tela = {b for b, v in mul.items() if v["akci"]}
    uop_tela = {b for b, v in uop.items() if v["akci"]}

    print(f"[anim] MUL: tela {len(mul_tela)}, akci {sum(v['akci'] for v in mul.values())}, "
          f"bloku {sum(v['bloku'] for v in mul.values())}")
    print(f"[anim] UOP: tela {len(uop_tela)}, akci {sum(v['akci'] for v in uop.values())}")
    print(f"[anim] prunik (tela v obou): {sorted(mul_tela & uop_tela)}")
    print(f"[anim] hash jmen v UOP (vzorek 700 tela x 80 akci): {shoda}")
    for telo in (400, 401, 404, 200, 201, 9, 130, 666):
        m = mul.get(telo, {})
        u = uop.get(telo, {})
        zdroj = "MUL" if m.get("akci") else ("UOP" if u.get("akci") else "zadny")
        print(f"[anim] telo {telo:4}: MUL akci {m.get('akci', 0):2} bloku "
              f"{m.get('bloku', 0):3} | UOP akci {u.get('akci', 0):2} -> zdroj {zdroj}")
    if args.telo is not None:
        print(f"[anim] detail tela {args.telo}: MUL={mul.get(args.telo)} "
              f"UOP={uop.get(args.telo)}")

    if not mul_tela:
        print("[anim] CHYBA: MUL nevratil ani jedno telo - mereni NEPROBĚHLO")
        return 1
    if all(v == 0 for v in shoda.values()):
        print("[anim] CHYBA: zadny kandidat hashe nenasel zaznam - mereni NEPROBĚHLO")
        return 1

    Path(args.out).write_text(json.dumps({
        "install": str(install),
        "mul": {str(k): v for k, v in mul.items()},
        "uop": {str(k): v for k, v in uop.items()},
        "uop_hash_shoda": shoda,
        "souhrn": {
            "mul_tela": len(mul_tela), "uop_tela": len(uop_tela),
            "prunik": sorted(mul_tela & uop_tela),
            "jen_mul": sorted(mul_tela - uop_tela),
            "jen_uop": sorted(uop_tela - mul_tela),
        },
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"[anim] zapsano {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
