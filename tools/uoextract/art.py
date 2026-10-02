#!/usr/bin/env python3
"""art(item_id) a land_art(tile_id) z artLegacyMUL.uop (granule assets.art).

Vse je MERENE / portovane z ClassicUO (src/ClassicUO.Assets/ArtLoader.cs, BSD-2):
  UOP zaznam -> payload. Staticky art: [u32 flags][i16 width][i16 height] a pak
  RLE ("Runs"): body zacina `height` x u16 offsetu radku (ve u16 slovech od
  zacatku body), kazdy radek je [u16 xoffs][u16 run][run x u16 barva];
  xoffs + run == 0 radek ukoncuje.
  Land art: 2024 B = 1012 u16 barev slozenych do 44x44 diamantu
  (docs/03 §3.5.4: "land art je diamant 44x44 s PRESNE 1012 pixely").
  Index archivu: land 0..0x3FFF, staticky art = tiledata_id + 0x4000
  (docs/03 §3.5.4) - to dela `art()` samo, `land_art()` bere land id.

Hash jmena zaznamu je rozhodnuty v uop.py (R1: create_hash, 100 % z 43 760).

Pouziti:
  python tools/uoextract/art.py --verify [--all] [--limit N]
  python tools/uoextract/art.py --dump assets/uo/art-preview
  python tools/uoextract/art.py --self-test
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from uop import ART_NAME, UopFile, create_hash  # noqa: E402

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
MAX_LAND = 0x4000
STATIC_BASE = 0x4000
LAND_SIZE = 44
LAND_PIXELS = 1012          # docs/03 §3.5.4 - rozhodujici cislo pro land art
LAND_BYTES = LAND_PIXELS * 2
MAX_DIM = 2048

# Vzorky pro lidskou kontrolu (docs/03 §3.5.3): jmeno -> index archivu
KNOWN = {
    "dagger": 3921 + STATIC_BASE,
    "longsword": 3936 + STATIC_BASE,
    "katana": 5118 + STATIC_BASE,
    "leather cap": 7609 + STATIC_BASE,
    "backpack": 2482 + STATIC_BASE,
    "anvil": 4015 + STATIC_BASE,
    "forge": 4017 + STATIC_BASE,
    "land grass": 3,
    # POZOR: puvodni sonda tuhle dlazdici popsala jako "sand", ale tiledata
    # ji zna jako "water" (flags 0x00C0, texture 0) - popisek byl odhad.
    "land water": 168,
}


def tiledata_name(install: str | Path, index: int) -> str | None:
    """Jmeno z tiledata (docs/03 §3.3.1b: jmena se berou z dat, ne z hlavy)."""
    try:
        from tiledata import TileData
        td = TileData(install)
        if index < MAX_LAND:
            return td.land(index)["name"] or None
        return td.item(index - STATIC_BASE)["name"] or None
    except Exception:
        return None


def c16(value: int) -> tuple[int, int, int]:
    return (((value >> 10) & 0x1F) * 255 // 31,
            ((value >> 5) & 0x1F) * 255 // 31,
            (value & 0x1F) * 255 // 31)


def decode_runs(body: bytes, width: int, height: int) -> list[list[tuple[int, int, int, int]]] | None:
    """ClassicUO ArtLoader.Runs -> radky pixelu (r, g, b, a)."""
    if width <= 0 or height <= 0 or width > MAX_DIM or height > MAX_DIM:
        return None
    if len(body) < height * 2:
        return None
    line_offsets = struct.unpack_from(f"<{height}H", body, 0)
    blank = (0, 0, 0, 0)
    pixels = [[blank] * width for _ in range(height)]
    y = 0
    x = 0
    ptr = height * 2 + line_offsets[0] * 2
    guard = 0
    while y < height:
        guard += 1
        if guard > 1_000_000 or ptr + 4 > len(body):
            break
        xoffs, run = struct.unpack_from("<HH", body, ptr)
        ptr += 4
        if xoffs + run >= MAX_DIM:
            break
        if xoffs + run != 0:
            x += xoffs
            row = pixels[y]
            for j in range(run):
                if ptr + 2 > len(body):
                    break
                value = struct.unpack_from("<H", body, ptr)[0]
                ptr += 2
                if value != 0 and 0 <= x + j < width:
                    r, g, b = c16(value)
                    row[x + j] = (r, g, b, 255)
            x += run
        else:
            x = 0
            y += 1
            if y < height:
                ptr = height * 2 + line_offsets[y] * 2
    return pixels


def decode_diamond(raw: bytes) -> list[list[tuple[int, int, int, int]]]:
    """ClassicUO ArtLoader.Diamond -> 44x44 land dlazdice (1012 pixelu)."""
    blank = (0, 0, 0, 0)
    pixels = [[blank] * LAND_SIZE for _ in range(LAND_SIZE)]
    at = 0
    for i in range(22):
        start = 22 - (i + 1)
        pos = i * LAND_SIZE + start
        for _ in range(start, start + ((i + 1) << 1)):
            if at + 2 > len(raw) or pos >= (i + 1) * LAND_SIZE:
                return pixels
            value = raw[at] | (raw[at + 1] << 8)
            at += 2
            r, g, b = c16(value)
            pixels[i][pos % LAND_SIZE] = (r, g, b, 255)
            pos += 1
    for i in range(22):
        pos = (i + 22) * LAND_SIZE + i
        for _ in range(i, i + ((22 - i) << 1)):
            if at + 2 > len(raw) or pos >= (i + 23) * LAND_SIZE:
                return pixels
            value = raw[at] | (raw[at + 1] << 8)
            at += 2
            r, g, b = c16(value)
            pixels[i + 22][pos % LAND_SIZE] = (r, g, b, 255)
            pos += 1
    return pixels


class ArtArchive:
    """Cteni artu z UOP. `raw` je jen pro offline testy."""

    def __init__(self, install: str | Path = DEFAULT_INSTALL, uop_path: str | Path | None = None,
                 raw: bytes | None = None) -> None:
        path = Path(uop_path) if uop_path else Path(install) / "artLegacyMUL.uop"
        self.uop = UopFile(path, raw=raw)
        self.entries = self.uop.read_entries()
        self.by_hash = {e.hash: e for e in self.entries if e.offset and e.hash}

    def payload(self, index: int) -> bytes | None:
        entry = self.by_hash.get(create_hash(ART_NAME % index))
        return None if entry is None else self.uop.read_data(entry)

    def land_art(self, tile_id: int):
        if not 0 <= tile_id < MAX_LAND:
            raise IndexError(f"land id {tile_id} mimo 0..{MAX_LAND - 1}")
        payload = self.payload(tile_id)
        if payload is None or len(payload) < LAND_BYTES:
            return None
        return LAND_SIZE, LAND_SIZE, decode_diamond(payload[:LAND_BYTES])

    def art(self, item_id: int):
        """`item_id` je tiledata id; index archivu je item_id + 0x4000."""
        index = item_id + STATIC_BASE
        payload = self.payload(index)
        if payload is None or len(payload) < 8:
            return None
        _, width, height = struct.unpack_from("<Ihh", payload, 0)
        pixels = decode_runs(payload[8:], width, height)
        if pixels is None:
            return None
        return width, height, pixels


def to_image(width: int, height: int, pixels):
    from PIL import Image
    image = Image.new("RGBA", (width, height))
    image.putdata([pixels[y][x] for y in range(height) for x in range(width)])
    return image


def verify(archive: ArtArchive, limit: int | None = None, check_all: bool = False) -> tuple[int, list[str]]:
    checks = 0
    errors: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(text)

    land_indices = [i for i in range(MAX_LAND) if create_hash(ART_NAME % i) in archive.by_hash]
    check(len(land_indices) > 1000, f"land zaznamu v archivu jen {len(land_indices)}")
    bad_land = 0
    for index in land_indices:
        result = archive.land_art(index)
        if result is None:
            bad_land += 1
            continue
        _, _, pixels = result
        if sum(1 for row in pixels for p in row if p[3]) != LAND_PIXELS:
            bad_land += 1
    print(f"[art] land: {len(land_indices)} dlazdic v archivu, z toho spatne {bad_land}")
    check(bad_land == 0, f"{bad_land} land dlazdic nema presne {LAND_PIXELS} pixelu (docs/03 §3.5.4)")

    static_indices = [i for i in range(STATIC_BASE, 0x10000) if create_hash(ART_NAME % i) in archive.by_hash]
    print(f"[art] staticky art: {len(static_indices)} zaznamu v archivu")
    sample = static_indices if check_all else static_indices[:limit or 3000]
    failed = 0
    empty = 0
    for index in sample:
        result = archive.art(index - STATIC_BASE)
        if result is None:
            failed += 1
            continue
        width, height, pixels = result
        opaque = sum(1 for row in pixels for p in row if p[3])
        if opaque == 0:
            empty += 1
        if width <= 0 or height <= 0:
            failed += 1
    print(f"[art] zkontrolovano {len(sample)} statickych artu: nezdarilo se {failed}, prazdnych {empty}")
    check(failed == 0, f"{failed} statickych artu se nepodarilo dekodovat")
    check(len(sample) > 100, f"kontrolovany vzorek je maly ({len(sample)})")
    check(empty * 100 <= len(sample), f"prazdnych ({empty}) je vic nez 100 % vzorku")

    for name, index in sorted(KNOWN.items()):
        if index >= STATIC_BASE:
            result = archive.art(index - STATIC_BASE)
            kind = "item"
        else:
            result = archive.land_art(index)
            kind = "land"
        if result is None:
            checks += 1
            errors.append(f"'{name}' (index {index}) se nepodarilo precist")
            continue
        width, height, pixels = result
        opaque = sum(1 for row in pixels for p in row if p[3])
        print(f"[art] {name:12} {kind} index={index:6} {width}x{height} pixelu={opaque}")
        check(opaque > 0, f"'{name}' je prazdny (0 pixelu)")
    return checks, errors


def dump(archive: ArtArchive, out_dir: Path, install: str | Path = DEFAULT_INSTALL) -> int:
    from PIL import Image, ImageDraw
    out_dir.mkdir(parents=True, exist_ok=True)
    tiles = []
    for label, index in sorted(KNOWN.items()):
        result = archive.land_art(index) if index < STATIC_BASE else archive.art(index - STATIC_BASE)
        if result is None:
            print(f"[art] {label}: nelze precist")
            continue
        width, height, pixels = result
        image = to_image(width, height, pixels)
        real_name = tiledata_name(install, index)
        name = real_name or label
        path = out_dir / f"{label.replace(' ', '_')}_{index:05d}.png"
        image.save(path)
        tiles.append((f"{name} [{index}]", image))
        print(f"[art] zapsano {path} ({width}x{height}, tiledata: {real_name!r})")

    if tiles:
        scale = 2
        cell_w = max(t[1].width for t in tiles) * scale + 8
        cell_h = max(t[1].height for t in tiles) * scale + 20
        columns = min(5, len(tiles))
        rows = (len(tiles) + columns - 1) // columns
        sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), (24, 24, 32, 255))
        draw = ImageDraw.Draw(sheet)
        for i, (name, image) in enumerate(tiles):
            big = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
            x = (i % columns) * cell_w + (cell_w - big.width) // 2
            y = (i // columns) * cell_h + 4
            sheet.alpha_composite(big, (max(0, x), max(0, y)))
            draw.text(((i % columns) * cell_w + 4, (i // columns) * cell_h + cell_h - 14),
                      f"{name}", fill=(220, 220, 220, 255))
        sheet_path = out_dir / "montage.png"
        sheet.save(sheet_path)
        print(f"[art] montaz pro lidskou kontrolu: {sheet_path}")
    return 0 if tiles else 1


def self_test() -> int:
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[art] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    land_raw = bytearray()
    for i in range(LAND_PIXELS):
        land_raw += struct.pack("<H", 0x03E0 if i % 2 else 0x7C00)
    pixels = decode_diamond(bytes(land_raw))
    opaque = sum(1 for row in pixels for p in row if p[3])
    check(len(pixels) == LAND_SIZE and all(len(row) == LAND_SIZE for row in pixels), "diamant je 44x44")
    check(opaque == LAND_PIXELS, f"diamant ma presne {LAND_PIXELS} pixelu (namEReno {opaque})")
    check(pixels[0][0][3] == 0 and pixels[0][22][3] == 255, "rohy zustavaji prazdne, stred se plni")
    check(decode_diamond(b"\x00" * 10)[43][21][3] == 0,
          "kratky vstup nevyplni spodni radky (cte se, dokud jsou data)")

    row = struct.pack("<HH", 1, 3) + struct.pack("<3H", 0x7C00, 0x03E0, 0x001F)
    end = struct.pack("<HH", 0, 0)
    body = struct.pack("<H", 0) + row + end
    small = decode_runs(body, 4, 1)
    check(small is not None and small[0][1][3] == 255 and small[0][1][0] == 255,
          "RLE: prvni pixel radku ma barvu 0x7C00 -> cervena")
    check(small is not None and small[0][0][3] == 0, "RLE: pixel pred offsetem zustava prazdny")
    check(small is not None and small[0][3][2] == 255, "RLE: treti pixel je modry (0x001F)")
    check(decode_runs(b"", 4, 1) is None, "RLE: prazdne body vraci None")
    check(decode_runs(body, 0, 1) is None, "RLE: nulova sirka vraci None")
    check(decode_runs(body, 4096, 1) is None, "RLE: sirka nad 2048 vraci None")

    empty_uop = struct.pack("<IIIqiI", 0x0050594D, 1, 0, 28, 1000, 0) + struct.pack("<iq", 0, 0)
    archive = ArtArchive(raw=empty_uop)
    check(archive.by_hash == {}, "archiv bez zaznamu vraci prazdny slovnik (nezhrouti se)")
    try:
        ArtArchive(raw=b"\x00" * 28)
        check(False, "poskozena hlavicka ma vyhodit chybu (ne tise pokracovat)")
    except ValueError as exc:
        check(True, f"poskozena hlavicka je odhalena ({exc})")
    print(f"[art] self-test: 11 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="art z artLegacyMUL.uop")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--uop", default=None)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--all", action="store_true", help="dekoduj vsechny staticke arty")
    ap.add_argument("--limit", type=int, default=3000)
    ap.add_argument("--dump", default=None, help="adresar pro nahledove PNG")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    archive = ArtArchive(args.install, args.uop)
    if args.dump:
        return dump(archive, Path(args.dump), args.install)
    if not args.verify:
        print(f"[art] archiv: {len(archive.entries)} zaznamu, {len(archive.by_hash)} s hashem "
              "(bez --verify se nic nemERilo)")
        return 0

    checks, errors = verify(archive, args.limit, args.all)
    for error in errors:
        print(f"[art] CHYBA: {error}")
    print(f"[art] {checks} kontrol, {len(errors)} chyb")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
