#!/usr/bin/env python3
"""Nezavisla reference PCG32 - doklad k znamemu vektoru v testech.

PROC TU JE: test `tests/cases/core.gd` porovnava prvnich 10 hodnot generatoru
proti konstantnimu vektoru. Kdyby vektor vznikl "od oka", test by mERil neco
jineho, nez si mysli. Tenhle skript pocita vektor znovu, z algoritmu, a umi ho
s obsahem testu srovnat:

    python tools/gates/pcg32_reference.py --check

Kontrola navic: pro initstate=42 a initseq=54 musi vyjit zname demo PCG
(0xa15c02b7 0x7b47f409 ...). Kdyz nesedi, je rozbita reference, ne test.

Kanonicky algoritmus (PCG-XSH-RR 64/32):
    state = state * 6364136223846793005 + inc      (mod 2^64)
    xorshifted = ((state >> 18) ^ state) >> 27     (logicky posun)
    rot = state >> 59
    out = rotr32(xorshifted, rot)

Seedovani: state = 0; inc = (seq << 1) | 1; step(); state += seed; step()
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

MASK64 = (1 << 64) - 1
MASK32 = (1 << 32) - 1
MULT = 6364136223846793005
DEFAULT_STREAM = 1442695040888963407

# Zname demo PCG pro initstate=42, initseq=54 (kontrola reference, ne hry).
DEMO_42_54 = [0xA15C02B7, 0x7B47F409, 0xBA1D3330, 0x83D2F293, 0xBFA4784B, 0xCBED606E]


class Pcg32:
    def __init__(self, seed: int, stream: int = DEFAULT_STREAM) -> None:
        self.state = 0
        self.inc = ((stream << 1) | 1) & MASK64
        self.next_u32()
        self.state = (self.state + seed) & MASK64
        self.next_u32()

    def next_u32(self) -> int:
        old = self.state
        self.state = (old * MULT + self.inc) & MASK64
        xorshifted = (((old >> 18) ^ old) >> 27) & MASK32
        rot = (old >> 59) & 31
        return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & 31))) & MASK32


def vector(seed: int = 42, count: int = 10) -> list[int]:
    rng = Pcg32(seed)
    return [rng.next_u32() for _ in range(count)]


def vector_in_test_file(path: Path) -> list[int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"RNG_SEED42_10\s*:=\s*\[(.*?)\]", text, re.S)
    if not match:
        return []
    return [int(v) for v in re.findall(r"\d+", match.group(1))]


def main() -> int:
    ap = argparse.ArgumentParser(description="Referenční PCG32 a kontrola vektoru")
    ap.add_argument("--check", action="store_true",
                    help="srovná vektor s tests/cases/core.gd a ověří demo PCG")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    if not args.check:
        print(vector(args.seed))
        return 0

    ok = True
    demo = []
    rng = Pcg32(42, 54)
    for _ in range(len(DEMO_42_54)):
        demo.append(rng.next_u32())
    if demo != DEMO_42_54:
        ok = False
        print("CHYBA: reference nedává známé demo PCG 42/54")
        print("  očekáváno:", " ".join(f"0x{v:08x}" for v in DEMO_42_54))
        print("  naměřeno: ", " ".join(f"0x{v:08x}" for v in demo))
    else:
        print("OK: reference dává známé demo PCG 42/54")

    test_file = Path(__file__).resolve().parents[2] / "tests" / "cases" / "core.gd"
    embedded = vector_in_test_file(test_file)
    computed = vector(args.seed)
    if not embedded:
        ok = False
        print(f"CHYBA: v {test_file.name} se nenašel vektor RNG_SEED42_10")
    elif embedded != computed:
        ok = False
        print("CHYBA: vektor v testu nesedí s referencí")
        print("  v testu:  ", embedded)
        print("  spočítáno:", computed)
    else:
        print(f"OK: vektor v {test_file.name} sedí s referencí ({len(embedded)} hodnot)")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
