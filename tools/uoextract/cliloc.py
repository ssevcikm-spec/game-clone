#!/usr/bin/env python3
"""cliloc(id) a cliloc_all() pro Cliloc.enu (granule assets.cliloc).

FORMAT (docs/03 §3.3.2, overeno merenim 2026-10-02):
  kdyz je treti bajt souboru 0x8E, je celek BWT-komprimovany -> rozbalit
  (BwtDecompress z ClassicUO; pouzivame `uop.bwt_decompress`, stejny kod
  jako u gumpartu - je to kodovani kontejneru, ne gumpu).
  Pak: [u32 number_format][u16 unknown] a zaznamy:
      [i32 cislo][u8 flag][i16 delka v BAJTECH][delka B UTF-8 text]
  Text je UTF-8, NE UTF-16 (proto klasicke cteni selhavalo).

Prijimaci kriterium granule: vypsat 5 po sobe jdoucich zaznamu a najit
v souboru anglicky text.

Pouziti:
  python tools/uoextract/cliloc.py --verify
  python tools/uoextract/cliloc.py --find "iron"
  python tools/uoextract/cliloc.py --self-test
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
from uop import bwt_decompress  # noqa: E402

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
BWT_DISCRIMINATOR = 0x8E


def decode_records(data: bytes) -> tuple[dict[int, str], int, int]:
    """Vrati (id -> text, pocet chyb, pocet zaznamu). Nikdy nespadne na konci."""
    if len(data) < 6:
        return {}, 1, 0
    out: dict[int, str] = {}
    errors = 0
    pos = 6                      # u32 number_format + u16 unknown
    while pos + 7 <= len(data):
        number = struct.unpack_from("<i", data, pos)[0]
        flag = data[pos + 4]
        length = struct.unpack_from("<h", data, pos + 5)[0]
        pos += 7
        if length < 0 or pos + length > len(data):
            errors += 1
            break
        raw = data[pos:pos + length]
        pos += length
        try:
            out[number] = raw.decode("utf-8")
        except UnicodeDecodeError:
            errors += 1
            out[number] = raw.decode("latin-1")
    return out, errors, len(out)


def load(install: str | Path = DEFAULT_INSTALL,
         path: str | Path | None = None) -> tuple[dict[int, str], dict]:
    source = Path(path) if path else Path(install) / "Cliloc.enu"
    raw = source.read_bytes()
    info = {"file": source.name, "bytes": len(raw),
            "third_byte": raw[3] if len(raw) > 3 else None, "bwt": False}
    data = raw
    if len(raw) > 3 and raw[3] == BWT_DISCRIMINATOR:
        data = bwt_decompress(raw)
        info["bwt"] = True
        info["bytes_after_bwt"] = len(data)
    records, errors, count = decode_records(data)
    info["records"] = count
    info["decode_errors"] = errors
    info["header_u32"] = struct.unpack_from("<I", data, 0)[0] if len(data) >= 4 else None
    return records, info


class Cliloc:
    """Kliloky nactene jednou; `cliloc(id)` vraci text nebo None."""

    def __init__(self, install: str | Path = DEFAULT_INSTALL, path: str | Path | None = None) -> None:
        self.records, self.info = load(install, path)

    def cliloc(self, number: int) -> str | None:
        return self.records.get(number)

    def cliloc_all(self) -> dict[int, str]:
        return self.records


def verify(install: str | Path = DEFAULT_INSTALL, path: str | Path | None = None,
           samples: int = 5, needles: tuple[str, ...] = ("iron", "sword", "gold", "the")) -> tuple[int, list[str]]:
    checks = 0
    errors: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(text)

    cliloc = Cliloc(install, path)
    info = cliloc.info
    print(f"[cliloc] {info['file']}: {info['bytes']} B, treti bajt "
          f"0x{info['third_byte']:02X}, BWT: {info['bwt']}"
          + (f" -> {info['bytes_after_bwt']} B" if info["bwt"] else ""))
    check(info["bwt"], "treti bajt neni 0x8E - soubor neni BWT (docs/03 §3.3.2)?")
    check(info["records"] > 10000, f"zaznamu je malo ({info['records']})")
    check(info["decode_errors"] == 0, f"{info['decode_errors']} zaznamu se nepodarilo prelozit")

    numbers = sorted(cliloc.records)
    print(f"[cliloc] zaznamu {len(numbers)}, cisla od {numbers[0]} do {numbers[-1]}")
    consecutive = [n for n in numbers if n + 1 in cliloc.records][:samples]
    print(f"[cliloc] {samples} po sobe jdoucich zaznamu:")
    for number in consecutive:
        print(f"[cliloc]   {number}: {cliloc.cliloc(number)!r}")
    check(len(consecutive) >= samples, f"nema {samples} po sobe jdoucich cisel")

    ascii_ratio = 0
    checked = 0
    for number in numbers[:2000]:
        text = cliloc.cliloc(number) or ""
        if text:
            checked += 1
            if all(0x20 <= ord(c) < 0x7F for c in text):
                ascii_ratio += 1
    print(f"[cliloc] z prvnich 2000 cisel ma text {checked}, z toho ciste ASCII {ascii_ratio}")
    check(checked > 100, f"z prvnich 2000 cisel ma text jen {checked} - kontrola NEPROBĚHLA")
    check(ascii_ratio > checked // 2, f"ASCII textu je jen {ascii_ratio} z {checked}")

    for needle in needles:
        hits = [n for n in numbers if needle in (cliloc.cliloc(n) or "").lower()]
        print(f"[cliloc] '{needle}' v {len(hits)} zaznamech, napr. "
              f"{[(n, cliloc.cliloc(n)) for n in hits[:2]]}")
        check(bool(hits), f"anglicky text '{needle}' v souboru NENI - cteni je spatne")
    return checks, errors


def find(install: str | Path, needle: str, limit: int = 10) -> int:
    cliloc = Cliloc(install)
    hits = [(n, t) for n, t in sorted(cliloc.records.items()) if needle.lower() in t.lower()]
    print(f"[cliloc] '{needle}': {len(hits)} zaznamu")
    for number, text in hits[:limit]:
        print(f"[cliloc]   {number}: {text}")
    return 0 if hits else 1


def self_test() -> int:
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[cliloc] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    def record(number: int, flag: int, text: str) -> bytes:
        raw = text.encode("utf-8")
        # Delka MUSI odpovidat textu; kdyz ne, proud se rozjede (to je presne
        # to, co jsem si v prvni verzi self-testu napsal spatne).
        return struct.pack("<iBh", number, flag, len(raw)) + raw

    body = struct.pack("<IH", 1, 0) + record(100, 0, "hello") + record(101, 1, "iron ingot")
    records, errors, count = decode_records(body)
    check(count == 2 and errors == 0, f"dva zaznamy precteny ({count}, chyb {errors})")
    check(records.get(100) == "hello", "text prvniho zaznamu sedi")
    check(records.get(101) == "iron ingot", "text druheho zaznamu sedi")
    check(decode_records(b"\x01\x00\x00\x00\x00\x00")[2] == 0, "hlavicka bez zaznamu vraci 0")
    truncated = body[:-3]
    _, truncated_errors, truncated_count = decode_records(truncated)
    check(truncated_errors == 1 and truncated_count == 1,
          f"useknuty zaznam je odhalen (chyb {truncated_errors}, zaznamu {truncated_count})")
    check(all(0x20 <= ord(c) < 0x7F for c in records[101]), "text je citelne ASCII")
    print(f"[cliloc] self-test: 6 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="kliloky z Cliloc.enu")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--file", default=None)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--find", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if args.find:
        return find(args.install, args.find)
    if args.verify:
        checks, errors = verify(args.install, args.file)
        for error in errors:
            print(f"[cliloc] CHYBA: {error}")
        print(f"[cliloc] {checks} kontrol, {len(errors)} chyb")
        return 1 if errors else 0
    cliloc = Cliloc(args.install, args.file)
    print(f"[cliloc] nacteno {len(cliloc.records)} zaznamu (bez --verify se nic nemERilo)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
