#!/usr/bin/env python3
"""Vygeneruje maly fixture sveta pro test world.map (tests/fixtures/world/).

PROC: `assets/uo/` je v .gitignore, takze v CI zadna mapa NENI a test nad
realnymi daty by tam nemel co merit. Fixture je mala, deterministicka a v gitu,
takze test meri FORMAT (docs/03 §3.4) vzdy - i v CI.

FORMAT (docs/03 §3.4, mereno 2026-10-02):
  * `.land`  = pro kazdy blok 4 B hlavicka + 64 bunek po 3 B `[u16 tile][i8 z]`,
    bunka uvnitr bloku na `(y % 8) * 8 + (x % 8)`,
  * index bloku je x-MAJOR `bx * blocks_y + by`,
  * `.statics.idx` = 12 B na blok `[u32 offset][u32 length][u32 extra]`,
  * `.statics.bin` = zaznamy po 7 B `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`,
    `x`,`y` jsou LOKALNI v bloku (0..7).

Hodnoty jsou zamerne RŮZNÉ v kazde bunce a v kazdem bloku - vada, ktera si
splete blok nebo bunku, se projevi hned. `z` statiku je zamerne MIMO 0..7
(kdyby se `z` cetlo na offsetu lokalniho `y`, test to vidi).

  python tests/fixtures/world/make_fixture.py           # zapise soubory
  python tests/fixtures/world/make_fixture.py --check   # jen overi (pro CI)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parent
PREFIX = DIR / "map0"
BLOCKS_X = 2
BLOCKS_Y = 3
BLOCK = 8
LAND_HEADER = 0x0000ABCD  # zamerne nenulova: preskocena hlavicka se projevi
LAND_TILE_MAX = 16383
EMPTY_BLOCK = 0xFFFFFFFF

# (tile, x, y, z, hue) pro kazdy blok; lokalni x,y a z mimo 0..7
STATIKY = {
    0: [(500, 1, 7, 40, 100), (700, 7, 1, -20, 200), (900, 0, 0, 0, 0)],
    1: [(501, 1, 7, 41, 101), (701, 7, 1, -21, 201), (901, 0, 0, 0, 0)],
    2: [(502, 1, 7, 42, 102), (702, 7, 1, -22, 202), (902, 0, 0, 0, 0)],
    3: [(503, 1, 7, 43, 103), (703, 7, 1, -23, 203), (903, 0, 0, 0, 0)],
    4: [(504, 1, 7, 44, 104), (704, 7, 1, -24, 204), (904, 0, 0, 0, 0)],
    # blok 5 je v indexu EMPTY_BLOCK - statiky nema, ale land ma
}


def land_tile(key: int, inner: int) -> int:
    return 1 + key * BLOCK * BLOCK + inner


def land_z(inner: int) -> int:
    return (inner % 25) - 12


def meta() -> dict:
    return {
        "format": "fixture (tests/fixtures/world/make_fixture.py) - NENI to UO data",
        "blocks_x": BLOCKS_X,
        "blocks_y": BLOCKS_Y,
        "land_tile_max": LAND_TILE_MAX,
    }


def land_bytes() -> bytes:
    out = bytearray()
    for key in range(BLOCKS_X * BLOCKS_Y):
        out += struct.pack("<I", LAND_HEADER)
        for inner in range(BLOCK * BLOCK):
            out += struct.pack("<Hb", land_tile(key, inner), land_z(inner))
    return bytes(out)


def statics_bytes() -> tuple[bytes, bytes]:
    bin_out = bytearray()
    idx_out = bytearray()
    for key in range(BLOCKS_X * BLOCKS_Y):
        zaznamy = STATIKY.get(key, [])
        if not zaznamy:
            idx_out += struct.pack("<III", EMPTY_BLOCK, 0, 0)
            continue
        idx_out += struct.pack("<III", len(bin_out), len(zaznamy) * 7, 0)
        for tile, x, y, z, hue in zaznamy:
            bin_out += struct.pack("<HBBbH", tile, x, y, z, hue)
    return bytes(bin_out), bytes(idx_out)


def soubory() -> dict[Path, bytes]:
    biny, idx = statics_bytes()
    return {
        PREFIX.with_suffix(".meta.json"): json.dumps(meta(), ensure_ascii=False,
                                                     indent=1).encode("utf-8"),
        PREFIX.with_suffix(".land"): land_bytes(),
        PREFIX.with_suffix(".statics.idx"): idx,
        PREFIX.with_suffix(".statics.bin"): biny,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Fixture pro world.map")
    ap.add_argument("--check", action="store_true", help="jen overit, nezapisovat")
    args = ap.parse_args()
    chyby = 0
    for path, data in soubory().items():
        hash_disk = hashlib.sha256(path.read_bytes()).hexdigest()[:12] if path.exists() else "CHYBI"
        hash_new = hashlib.sha256(data).hexdigest()[:12]
        if args.check:
            ok = hash_disk == hash_new
            chyby += 0 if ok else 1
            print(f"[fixture] {'OK  ' if ok else 'JINA'} {path.name}: "
                  f"disk {hash_disk}, generator {hash_new}")
        else:
            path.write_bytes(data)
            print(f"[fixture] zapsano {path.name}: {len(data)} B, sha256 {hash_new}")
    if args.check and chyby:
        print(f"[fixture] {chyby} souboru neodpovida generatoru")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
