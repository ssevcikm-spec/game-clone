#!/usr/bin/env python3
"""Mapa a statiky -> assets/uo/world/ (granule assets.worldmap).

FORMAT (docs/03 §3.4, vse znovu overeno merenim 2026-10-02):
  map0LegacyMUL.uop: 113 chunku `build/map0legacymul/{i:08d}.dat`, kazdy presne
  802 816 B = 0xC4000 = 4096 bloku x 196 B. Blok = u32 hlavicka + 64 x 3 B
  (tile_id u16, z i8) - bunka je 3bajtova, ne 4bajtova.
  Linearni index bloku = by * blocks_x + bx, blocks_x = 7168/8 = 896.
  113 * 4096 = 462 848 >= 458 752 potrebnych bloku (docs/03 §3.5.4 R3).
  Statiky: staidx0.mul = 12 B na blok (offset, delka, extra),
  statics0.mul = zaznamy 7 B (tile_id u16, x u16, y u16, z i8).

Vystup (presne podle smlouvy granule):
  assets/uo/world/map0.land          syrove bloky 196 B (89,9 MB)
  assets/uo/world/map0.statics.idx   12 B na blok
  assets/uo/world/map0.statics.bin   zaznamy 7 B
  assets/uo/world/map0.meta.json     rozmery, pocty, sha256 vstupu

Pouziti:
  python tools/uoextract/worldmap.py --extract assets/uo/world
  python tools/uoextract/worldmap.py --verify assets/uo/world
  python tools/uoextract/worldmap.py --preview assets/uo/world/preview-britain.png
  python tools/uoextract/worldmap.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import time
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from uop import UopFile, create_hash  # noqa: E402

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
MAP_PATTERN = "build/map0legacymul/{:08d}.dat"
MAP_W, MAP_H = 7168, 4096
BLOCK_SIZE = 8
BLOCK_BYTES = 4 + BLOCK_SIZE * BLOCK_SIZE * 3      # 196
BLOCKS_X, BLOCKS_Y = MAP_W // BLOCK_SIZE, MAP_H // BLOCK_SIZE
TOTAL_BLOCKS = BLOCKS_X * BLOCKS_Y                  # 458 752
CHUNK_BLOCKS = 4096
LAND_TILE_LIMIT = 0x4000
STATIC_ENTRY = 7
STATIC_INDEX_ENTRY = 12
BRITAIN = (1495, 1630)


def block_offset(x: int, y: int) -> int:
    """Linearni index bloku.

    POZOR: docs/03 §3.4 uvadi `by * blocks_x + bx`, ale to je SPATNE - odhalil
    to az pruhovany nahled Britainu. ClassicUO (MapLoader.cs:623) pocita
    `block = bx * blocks_y + by`, tedy x-major. Overeno 2026-10-02 take tim, ze
    blok Britainu ma pri x-major indexaci 60 statiku, kdezto pri by-major 0.
    """
    return (x // BLOCK_SIZE) * BLOCKS_Y + (y // BLOCK_SIZE)


def read_land(path: Path) -> bytes:
    return path.read_bytes()


def read_statics(idx_path: Path, bin_path: Path, x: int, y: int) -> list[dict]:
    """Statiky bloku, ve kterem lezi (x, y)."""
    index = block_offset(x, y)
    with idx_path.open("rb") as handle:
        handle.seek(index * STATIC_INDEX_ENTRY)
        raw = handle.read(STATIC_INDEX_ENTRY)
    offset, length, _extra = struct.unpack("<III", raw)
    if offset == 0xFFFFFFFF or length == 0:
        return []
    with bin_path.open("rb") as handle:
        handle.seek(offset)
        data = handle.read(length)
    out = []
    for i in range(0, len(data) - STATIC_ENTRY + 1, STATIC_ENTRY):
        # Zaznam statiky je 7 B: [u16 tile][u8 x][u8 y][i8 z][u16 hue].
        # POZOR: docs/03 §3.4 uvadi "[u16 tile][u16 x][u16 y][i8 z]" - to je
        # SPATNE (sirky poli); ClassicUO ma ve strukture StaticsBlock
        # ushort Color + byte X + byte Y. Pri spatnem cteni vychazeji
        # "souradnice" 251, 513 apod. (namEReno 2026-10-02).
        tile, sx, sy, z, hue = struct.unpack_from("<HBBbH", data, i)
        out.append({"tile": tile, "x": sx, "y": sy, "z": z, "hue": hue})
    return out


def water_tile_ids(install: str | Path) -> set[int]:
    """Id land dlazdic, ktere tiledata nazyva vodou (jmena z dat, ne z hlavy)."""
    from tiledata import LAND_COUNT, TileData
    td = TileData(install)
    return {tile for tile in range(LAND_COUNT) if "water" in td.land(tile)["name"].lower()}


def extract(install: str | Path, out_dir: Path) -> int:
    import numpy as np
    inst = Path(install)
    out_dir.mkdir(parents=True, exist_ok=True)
    sources = {}
    started = time.time()

    uop = UopFile(inst / "map0LegacyMUL.uop")
    entries = uop.read_entries()
    by_hash = {e.hash: e for e in entries if e.offset}
    chunks = []
    sizes: dict[int, int] = {}
    for index in range(0x100):
        entry = by_hash.get(create_hash(MAP_PATTERN.format(index)))
        if entry is None:
            continue
        payload = uop.read_data(entry)
        if payload is None:
            print(f"[map] CHYBA: chunk {index} nelze precist")
            return 1
        if len(payload) % BLOCK_BYTES != 0:
            print(f"[map] CHYBA: chunk {index} ma {len(payload)} B, coz neni cele bloky "
                  f"({BLOCK_BYTES} B)")
            return 1
        chunks.append(payload)
        sizes[index] = len(payload)
    blocks = b"".join(chunks)
    short = {i: n for i, n in sizes.items() if n != CHUNK_BLOCKS * BLOCK_BYTES}
    print(f"[map] chunku {len(chunks)}, bloku v chuncich {len(blocks) // BLOCK_BYTES}, "
          f"potreba {TOTAL_BLOCKS}")
    if short:
        # NamEReno 2026-10-02: 112 chunku ma plnych 802 816 B (= 458 752 bloku PRESNE,
        # tedy cely svet) a posledni (112.) ma jediny blok navic. Neni to vada -
        # ale kdyby se pocitalo s "113 x 4096", vyslo by o 4096 bloku vic, nez je treba.
        print(f"[map] kratsi chunky: {short} (docs/03 §3.5.4 R3 je uvadi jako '113 x ~802 816')")
    if len(blocks) < TOTAL_BLOCKS * BLOCK_BYTES:
        print(f"[map] CHYBA: chunky drzi jen {len(blocks) // BLOCK_BYTES} bloku, "
              f"potreba {TOTAL_BLOCKS}")
        return 1

    land = blocks[:TOTAL_BLOCKS * BLOCK_BYTES]
    (out_dir / "map0.land").write_bytes(land)
    sources["map0LegacyMUL.uop"] = hashlib.sha256((inst / "map0LegacyMUL.uop").read_bytes()).hexdigest()

    for name, target in (("staidx0.mul", "map0.statics.idx"), ("statics0.mul", "map0.statics.bin")):
        raw = (inst / name).read_bytes()
        (out_dir / target).write_bytes(raw)
        sources[name] = hashlib.sha256(raw).hexdigest()

    land_ids = np.frombuffer(land, dtype=np.uint8).reshape(TOTAL_BLOCKS, BLOCK_BYTES)[:, 4:]
    land_ids = land_ids.reshape(TOTAL_BLOCKS, BLOCK_SIZE * BLOCK_SIZE, 3)
    tile_ids = land_ids[:, :, 0].astype(np.uint16) | (land_ids[:, :, 1].astype(np.uint16) << 8)

    statics_idx = (out_dir / "map0.statics.idx").read_bytes()
    entries_count = len(statics_idx) // STATIC_INDEX_ENTRY
    meta = {
        "width": MAP_W, "height": MAP_H,
        "blocks_x": BLOCKS_X, "blocks_y": BLOCKS_Y,
        "block_size": BLOCK_SIZE, "block_bytes": BLOCK_BYTES,
        "land_tiles": int(tile_ids.size),
        "land_tile_max": int(tile_ids.max()),
        "chunks": len(chunks), "blocks_in_chunks": len(blocks) // BLOCK_BYTES,
        "statics_index_entries": entries_count,
        "statics_file_bytes": (out_dir / "map0.statics.bin").stat().st_size,
        "versions": {"install": "1.25.35", "format": 1},
        "source_sha256": sources,
    }
    (out_dir / "map0.meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    print(f"[map] zapsano {out_dir}/map0.{{land,statics.idx,statics.bin,meta.json}} "
          f"({(out_dir / 'map0.land').stat().st_size / 1048576:.1f} MB + "
          f"{(out_dir / 'map0.statics.bin').stat().st_size / 1048576:.1f} MB) "
          f"za {time.time() - started:.1f} s")
    return 0


def verify(install: str | Path, world: Path) -> tuple[int, list[str]]:
    import numpy as np
    checks = 0
    errors: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(text)

    land_path, idx_path, bin_path = world / "map0.land", world / "map0.statics.idx", world / "map0.statics.bin"
    for path in (land_path, idx_path, bin_path):
        if not path.exists():
            return 1, [f"{path} neexistuje - spust nejdriv --extract"]

    land = np.fromfile(land_path, dtype=np.uint8)
    check(land.size == TOTAL_BLOCKS * BLOCK_BYTES,
          f"map0.land ma {land.size} B, cekano {TOTAL_BLOCKS * BLOCK_BYTES}")
    cells = land.reshape(TOTAL_BLOCKS, BLOCK_BYTES)[:, 4:].reshape(TOTAL_BLOCKS, 64, 3)
    tile_ids = cells[:, :, 0].astype(np.uint16) | (cells[:, :, 1].astype(np.uint16) << 8)
    bad_ids = int((tile_ids >= LAND_TILE_LIMIT).sum())
    print(f"[map] land: {tile_ids.size} dlazdic, max tile id {int(tile_ids.max())}, "
          f"mimo rozsah {bad_ids} (docs/03 §3.4)")
    check(bad_ids == 0, f"{bad_ids} land dlazdic ma tile id >= 0x4000")
    check(int(tile_ids.max()) > 0, "vsechny land tile id jsou nulove - kontrola NEPROBĚHLA")

    statics_idx = np.fromfile(idx_path, dtype=np.uint32)
    check(statics_idx.size == TOTAL_BLOCKS * (STATIC_INDEX_ENTRY // 4),
          f"index ma {statics_idx.size // 3} bloku, cekano {TOTAL_BLOCKS}")
    triples = statics_idx.reshape(-1, 3)
    # Nepouzite bloky maji offset i delku 0xFFFFFFFF - do souctu delek nepatri
    # (jinak vyjde 1,45e15 misto velikosti souboru; namEReno 2026-10-02).
    used = triples[triples[:, 0] != 0xFFFFFFFF]
    total_length = int(used[:, 1].sum())
    bin_size = bin_path.stat().st_size
    print(f"[map] statiky: index {triples.shape[0]} bloku, z toho pouzitych {used.shape[0]}, "
          f"soucet jejich delek {total_length} B, map0.statics.bin {bin_size} B")
    check(total_length == bin_size,
          f"soucet delek pouzitych statics ({total_length}) != velikost .bin ({bin_size})")
    check(used.shape[0] > 10000, f"pouzitych bloku statics je malo ({used.shape[0]})")

    # Britain: docs/03 §3.4 tvrdi "blok pro Britain (1495,1630) = 20 záznamů".
    # Meri se proto cely okolni region (a rovnou se hleda blok s nejvic statiky),
    # aby se pripadny posun v indexaci poznal, misto aby se hadal.
    bx, by = BRITAIN[0] // BLOCK_SIZE, BRITAIN[1] // BLOCK_SIZE
    around: list[tuple[int, int, int]] = []
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            x, y = (bx + dx) * BLOCK_SIZE, (by + dy) * BLOCK_SIZE
            count = len(read_statics(idx_path, bin_path, x, y))
            if count:
                around.append((count, bx + dx, by + dy))
    around.sort(reverse=True)
    britain = read_statics(idx_path, bin_path, *BRITAIN)
    exact = len(britain)
    region_total = sum(c for c, _, _ in around)
    print(f"[map] Britain ({BRITAIN[0]},{BRITAIN[1]}) blok ({bx},{by}): {exact} statiku; "
          f"v okoli +-6 bloku {region_total} statiku v {len(around)} blocich, "
          f"nejvic {around[:3]}")
    check(region_total > 0, "okoli Britainu nema zadne statiky (docs/03 §3.4) - offset je spatny")
    # Lokalni souradnice statiku MUSI byt 0..7 (blok je 8x8 dlazdic). Kdyz se
    # zaznam cte spatne sirky pole (u16 misto u8), vyjdou hodnoty jako 251 nebo
    # 513 - presne tahle kontrola by vadu odhalila (namEReno 2026-10-02).
    outside = [s for s in britain if not (0 <= s["x"] < BLOCK_SIZE and 0 <= s["y"] < BLOCK_SIZE)]
    check(not outside, f"{len(outside)} statiku Britainu ma lokalni souradnice mimo 0..7 "
                       f"(prvni: {outside[:2]})")
    check(len(around) > 5, f"statiky jsou jen v {len(around)} blocich z 169 - podezrele ridke")

    water = water_tile_ids(install)
    print(f"[map] vodnich land tile id podle tiledata: {sorted(water)}")
    check(len(water) > 0, "tiledata nezná zadnou vodni dlazdici")
    is_water = np.isin(tile_ids, list(water)) if water else np.zeros(tile_ids.shape, dtype=bool)
    grid_all = is_water.reshape(TOTAL_BLOCKS, BLOCK_SIZE, BLOCK_SIZE)
    fractions = grid_all.reshape(TOTAL_BLOCKS, -1).mean(axis=1)
    # Smysl maji jen SMISENE bloky: blok cele vodni nebo cele zemi nema o tvaru
    # co rict (namEReno: u plne vodniho bloku vyjde pozorovane == nulovy model).
    mixed = np.where((fractions > 0.05) & (fractions < 0.95))[0]
    print(f"[map] bloku celkem {TOTAL_BLOCKS}, smisenych (voda i zem) {mixed.size}")
    check(mixed.size > 100, f"smisenych bloku je malo ({mixed.size}) - o tvaru vody nic nevim")
    rng = np.random.default_rng(12345)
    sample = rng.choice(mixed, size=min(200, mixed.size), replace=False)

    def adjacent_pairs(grid) -> int:
        return int((grid[:, :-1] & grid[:, 1:]).sum())

    observed = sum(adjacent_pairs(grid_all[i]) for i in sample)
    shuffled = 0
    for i in sample:
        flat = grid_all[i].reshape(-1).copy()
        rng.shuffle(flat)
        shuffled += adjacent_pairs(flat.reshape(BLOCK_SIZE, BLOCK_SIZE))
    print(f"[map] voda ve {sample.size} smisenych blocich: sousednich dvojic {observed}, "
          f"nulovy model (promichane) {shuffled}")
    check(observed > shuffled * 1.2,
          f"voda netvori souvisle plochy (sousednich dvojic {observed} vs promichane "
          f"{shuffled}) - docs/03 §3.4")
    return checks, errors


def preview(install: str | Path, world: Path, out_path: Path, center=BRITAIN,
            tiles_x: int = 120, tiles_y: int = 90) -> int:
    """Nahled Britainu z land artu - pro lidskou kontrolu (docs/03 §3.4 bod 4)."""
    import numpy as np
    from PIL import Image
    from art import ArtArchive

    land = np.fromfile(world / "map0.land", dtype=np.uint8)
    cells = land.reshape(TOTAL_BLOCKS, BLOCK_BYTES)[:, 4:].reshape(TOTAL_BLOCKS, 64, 3)
    tile_ids = cells[:, :, 0].astype(np.uint16) | (cells[:, :, 1].astype(np.uint16) << 8)
    zs = cells[:, :, 2].astype(np.int8)

    def cell(x: int, y: int):
        block = block_offset(x, y)
        inner = (y % BLOCK_SIZE) * BLOCK_SIZE + (x % BLOCK_SIZE)
        return int(tile_ids[block][inner]), int(zs[block][inner])

    archive = ArtArchive(install)
    step = 22
    origin_x = center[0] - tiles_x // 2
    origin_y = center[1] - tiles_y // 2
    # Projekce pocatku oblasti se MUSI odectat, jinak padnou vsechny dlazdice
    # mimo platno (namEReno 2026-10-02: "dlazdic 0" u 4664x4664).
    origin_sx = (origin_x - origin_y) * step
    origin_sy = (origin_x + origin_y) * step
    canvas_w = (tiles_x + tiles_y) * step + 2 * step
    canvas_h = (tiles_x + tiles_y) * step + 2 * step
    image = Image.new("RGBA", (canvas_w, canvas_h), (16, 16, 24, 255))
    cache: dict[int, object] = {}
    drawn = 0
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            x, y = origin_x + tx, origin_y + ty
            if not (0 <= x < MAP_W and 0 <= y < MAP_H):
                continue
            texture, z = cell(x, y)
            if texture not in cache:
                cache[texture] = archive.land_art(texture)
            art = cache[texture]
            if art is None:
                continue
            _, _, pixels = art
            sx = (x - y) * step - origin_sx + tiles_y * step
            sy = (x + y) * step - origin_sy - z * 4 + step
            if not (0 <= sx < canvas_w - 44 and 0 <= sy < canvas_h - 44):
                continue
            tile = Image.new("RGBA", (44, 44))
            tile.putdata([pixels[row][col] for row in range(44) for col in range(44)])
            image.alpha_composite(tile, (sx, sy))
            drawn += 1
    out_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(out_path)
    print(f"[map] nahled {out_path} ({canvas_w}x{canvas_h}, dlazdic {drawn}, "
          f"ruznych textur {len(cache)})")
    return 0 if drawn else 1


def self_test() -> int:
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[map] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    check(BLOCK_BYTES == 196, f"blok je {BLOCK_BYTES} B (docs/03 §3.4)")
    check(BLOCKS_X == 896 and BLOCKS_Y == 512, f"mrizka bloku {BLOCKS_X}x{BLOCKS_Y}")
    check(TOTAL_BLOCKS == 458752, f"bloku celkem {TOTAL_BLOCKS}")
    check(CHUNK_BLOCKS * BLOCK_BYTES == 0xC4000,
          f"chunk je {CHUNK_BLOCKS * BLOCK_BYTES} B = 0xC4000 (docs/03 §3.4)")
    check(block_offset(0, 0) == 0 and block_offset(0, 8) == 1, "index bloku roste po y")
    check(block_offset(8, 0) == BLOCKS_Y, "dalsi sloupec bloku je o blocks_y dal (x-major)")
    check(block_offset(7160, 4088) == TOTAL_BLOCKS - 1, "posledni dlazdice je v poslednim bloku")
    check(113 * CHUNK_BLOCKS >= TOTAL_BLOCKS,
          f"113 chunku pokryje {113 * CHUNK_BLOCKS} bloku >= {TOTAL_BLOCKS}")
    print(f"[map] self-test: 8 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="mapa a statiky z instalace UO")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--extract", default=None, help="vystupni adresar (assets/uo/world)")
    ap.add_argument("--verify", default=None, help="adresar s extrahovanymi daty")
    ap.add_argument("--preview", default=None, help="cesta k nahledu PNG")
    ap.add_argument("--world", default="assets/uo/world")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if args.extract:
        return extract(args.install, Path(args.extract))
    if args.preview:
        return preview(args.install, Path(args.world), Path(args.preview))
    if args.verify:
        checks, errors = verify(args.install, Path(args.verify))
        for error in errors:
            print(f"[map] CHYBA: {error}")
        print(f"[map] {checks} kontrol, {len(errors)} chyb")
        return 1 if errors else 0
    print("[map] nic se nedelo: zadej --extract, --verify, --preview nebo --self-test")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
