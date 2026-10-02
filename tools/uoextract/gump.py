#!/usr/bin/env python3
"""gump(id) -> RGBA obrazek (granule assets.gump).

Kodovani je MERENE / portovane z ClassicUO (src/ClassicUO.Assets/GumpsLoader.cs,
BSD-2):
  UOP zaznam `build/gumpartlegacymul/{id:08d}.tga` -> payload.
  Komprese (flag v UOP): 1 a 2 = zlib, 3 = zlib + BWT. V teto instalaci ma
  VSECHNYCH 5 579 gumpu flag 3, takze BWT je nutne (docs/03 §3.5.4 R2).
  Po rozbaleni: [u32 width][u32 height], pak pro kazdy radek u32 offset
  (ve ctyrbajtovych jednotkach od zacatku tabulky), pak dvojice
  [u16 barva][u16 run]; barva 0 = pruhledna.

ROZPOR R2 ROZHODNUTY MERENIM 2026-10-02: "zlib staci" NEPLATI - archiv ma
vsude flag 3 a bez BWT se nerozbalí ani jeden gump. Rozhodl obrazek (batoh),
ne vlajka: gump 60 da 230x204 a je na nem videt batoh.

Pouziti:
  python tools/uoextract/gump.py --verify [--limit N]
  python tools/uoextract/gump.py --dump assets/uo/gump-preview
  python tools/uoextract/gump.py --self-test
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
from uop import UopFile, create_hash  # noqa: E402

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
PATTERN = "build/gumpartlegacymul/%08d.tga"
MAX_DIM = 4096

# Vzorky pro lidskou kontrolu (R2 zminuje batoh; zbytek jsou bezne gumpy)
KNOWN = {
    "backpack": 60,
    "backpack_alt": 61,
    "paperdoll_bg": 0,
    "container_1": 100,
    "small": 1,
}


def c16(value: int) -> tuple[int, int, int]:
    return (((value >> 10) & 0x1F) * 255 // 31,
            ((value >> 5) & 0x1F) * 255 // 31,
            (value & 0x1F) * 255 // 31)


def decode(body: bytes, width: int, height: int) -> list[list[tuple[int, int, int, int]]] | None:
    """RLE gumpu: tabulka offsetu radku + dvojice (barva, run)."""
    if width <= 0 or height <= 0 or width > MAX_DIM or height > MAX_DIM:
        return None
    if len(body) < height * 4:
        return None
    row_lookup = struct.unpack_from(f"<{height}I", body, 0)
    half_len = len(body) >> 2
    blank = (0, 0, 0, 0)
    pixels = [[blank] * width for _ in range(height)]
    total = width * height
    for y in range(height):
        pixel_index = y * width
        run_count = (row_lookup[y + 1] - row_lookup[y]) if y < height - 1 else (half_len - row_lookup[y])
        ptr = row_lookup[y] * 4
        for _ in range(run_count):
            if ptr + 4 > len(body):
                break
            value, run = struct.unpack_from("<HH", body, ptr)
            ptr += 4
            if run == 0:
                continue
            if pixel_index + run > total:
                run = max(0, total - pixel_index)
                if run == 0:
                    break
            if value != 0:
                r, g, b = c16(value)
                colour = (r, g, b, 255)
                for offset in range(run):
                    index = pixel_index + offset
                    pixels[index // width][index % width] = colour
            pixel_index += run
    return pixels


class GumpArchive:
    """Cteni gumpu z gumpartLegacyMUL.uop. `raw` je jen pro offline testy."""

    def __init__(self, install: str | Path = DEFAULT_INSTALL, uop_path: str | Path | None = None,
                 raw: bytes | None = None) -> None:
        path = Path(uop_path) if uop_path else Path(install) / "gumpartLegacyMUL.uop"
        self.uop = UopFile(path, raw=raw)
        self.entries = self.uop.read_entries()
        self.by_hash = {e.hash: e for e in self.entries if e.offset and e.hash}

    def payload(self, gump_id: int) -> bytes | None:
        entry = self.by_hash.get(create_hash(PATTERN % gump_id))
        return None if entry is None else self.uop.read_data(entry)

    def gump(self, gump_id: int):
        payload = self.payload(gump_id)
        if payload is None or len(payload) < 8:
            return None
        width, height = struct.unpack_from("<II", payload, 0)
        pixels = decode(payload[8:], width, height)
        if pixels is None:
            return None
        return width, height, pixels

    def flags(self) -> dict[int, int]:
        out: dict[int, int] = {}
        for entry in self.entries:
            out[entry.flag] = out.get(entry.flag, 0) + 1
        return out


def to_image(width: int, height: int, pixels):
    from PIL import Image
    image = Image.new("RGBA", (width, height))
    image.putdata([pixels[y][x] for y in range(height) for x in range(width)])
    return image


def verify(archive: GumpArchive, limit: int | None = None) -> tuple[int, list[str]]:
    checks = 0
    errors: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(text)

    flags = archive.flags()
    print(f"[gump] zaznamu {len(archive.entries)}, flagy {dict(sorted(flags.items()))}")
    check(flags.get(3, 0) > 0 or flags.get(1, 0) > 0,
          f"archiv nema komprimovane zaznamy (flagy {flags}) - R2 nelze rozhodnout")

    ids = [i for i in range(0x10000) if create_hash(PATTERN % i) in archive.by_hash]
    print(f"[gump] gump id v archivu: {len(ids)}")
    check(len(ids) > 100, f"gump id je malo ({len(ids)})")
    sample = ids if limit is None else ids[:limit]

    failed = 0        # zaznam ma rozmery, ale decode selhal = skutecna vada
    empty = 0         # zaznam je prazdny (0x0) - takove v archivu jsou (id bez obrazku)
    blank = 0         # ma rozmery, ale vsechny pixely pruhledne
    checked = 0
    for gump_id in sample:
        payload = archive.payload(gump_id)
        if payload is None or len(payload) < 8:
            failed += 1
            continue
        width, height = struct.unpack_from("<II", payload, 0)
        if width == 0 or height == 0:
            empty += 1
            continue
        pixels = decode(payload[8:], width, height)
        if pixels is None:
            failed += 1
            continue
        checked += 1
        opaque = sum(1 for row in pixels for p in row if p[3])
        if opaque == 0:
            blank += 1
    print(f"[gump] zkontrolovano {len(sample)} id: dekodovano {checked}, prazdnych zaznamu {empty}, "
          f"bez pixelu {blank}, nezdarilo se {failed}")
    check(failed == 0, f"{failed} gumpu se nepodarilo dekodovat (ma rozmery, ale decode selhal)")
    check(checked > 10, f"dekodovanych gumpu je malo ({checked}) - kontrola NEPROBĚHLA")
    check(blank * 10 <= max(checked, 1), f"gumpu bez jedineho pixelu je {blank} z {checked} (>10 %)")

    for name, gump_id in sorted(KNOWN.items()):
        result = archive.gump(gump_id)
        if result is None:
            checks += 1
            errors.append(f"'{name}' (gump {gump_id}) se nepodarilo precist")
            continue
        width, height, pixels = result
        opaque = sum(1 for row in pixels for p in row if p[3])
        print(f"[gump] {name:14} id={gump_id:5} {width}x{height} pixelu={opaque} "
              f"({opaque * 100 // max(1, width * height)} %)")
        check(opaque > 0, f"'{name}' je prazdny")
    return checks, errors


def dump(archive: GumpArchive, out_dir: Path) -> int:
    from PIL import Image, ImageDraw
    out_dir.mkdir(parents=True, exist_ok=True)
    tiles = []
    for label, gump_id in sorted(KNOWN.items()):
        result = archive.gump(gump_id)
        if result is None:
            print(f"[gump] {label}: nelze precist")
            continue
        width, height, pixels = result
        image = to_image(width, height, pixels)
        path = out_dir / f"{label}_{gump_id:05d}.png"
        image.save(path)
        tiles.append((f"{label} [{gump_id}] {width}x{height}", image))
        print(f"[gump] zapsano {path} ({width}x{height})")

    if tiles:
        cell_w = max(t[1].width for t in tiles) + 8
        cell_h = max(t[1].height for t in tiles) + 20
        sheet = Image.new("RGBA", (cell_w * len(tiles), cell_h), (40, 40, 60, 255))
        draw = ImageDraw.Draw(sheet)
        for i, (label, image) in enumerate(tiles):
            sheet.alpha_composite(image, (i * cell_w + 4, 4))
            draw.text((i * cell_w + 4, cell_h - 14), label, fill=(230, 230, 230, 255))
        sheet_path = out_dir / "montage.png"
        sheet.save(sheet_path)
        print(f"[gump] montaz pro lidskou kontrolu: {sheet_path}")
    return 0 if tiles else 1


def self_test() -> int:
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[gump] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    # jeden radek: offset radku 0 (za tabulkou), pak 3 pixely cervene a konec
    body = struct.pack("<I", 1) + struct.pack("<HH", 0x7C00, 3)
    pixels = decode(body, 4, 1)
    check(pixels is not None and pixels[0][0][:3] == (255, 0, 0), "barva 0x7C00 je cervena")
    check(pixels is not None and pixels[0][3][3] == 0, "ctvrty pixel zustava pruhledny")

    two = struct.pack("<2I", 2, 3) + struct.pack("<HH", 0x001F, 2) + struct.pack("<HH", 0x03E0, 1)
    pixels2 = decode(two, 4, 2)
    check(pixels2 is not None and pixels2[0][0][2] == 255, "druhy radek: prvni pixel modry")
    check(pixels2 is not None and pixels2[1][0][1] == 255, "druhy radek: zeleny pixel")
    check(decode(b"", 4, 1) is None, "kratke telo vraci None")
    check(decode(body, 0, 1) is None, "nulova sirka vraci None")
    check(decode(body, 5000, 1) is None, "sirka nad 4096 vraci None")
    check(decode(struct.pack("<I", 0) + struct.pack("<HH", 0x7C00, 99), 4, 1)[0][0][3] == 255,
          "run pres konec radku se zastavi (nespadne)")

    empty_uop = struct.pack("<IIIqiI", 0x0050594D, 1, 0, 28, 1000, 0) + struct.pack("<iq", 0, 0)
    archive = GumpArchive(raw=empty_uop)
    check(archive.gump(60) is None, "prazdny archiv vraci None (ne vyjimku)")
    print(f"[gump] self-test: 8 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="gumpy z gumpartLegacyMUL.uop")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--uop", default=None)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--limit", type=int, default=200,
                    help="kolik gumpu overit (BWT v Pythonu je drahy: ~0,2 s/gump; "
                         "vsech 5571 trva ~20 min)")
    ap.add_argument("--dump", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    archive = GumpArchive(args.install, args.uop)
    if args.dump:
        return dump(archive, Path(args.dump))
    if not args.verify:
        print(f"[gump] archiv: {len(archive.entries)} zaznamu, flagy {dict(sorted(archive.flags().items()))}"
              " (bez --verify se nic nemERilo)")
        return 0

    checks, errors = verify(archive, args.limit)
    for error in errors:
        print(f"[gump] CHYBA: {error}")
    print(f"[gump] {checks} kontrol, {len(errors)} chyb")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
