#!/usr/bin/env python3
"""MYP0 (UOP) kontejner + rozhodnuti R1 o hash funkci (granule assets.uop).

Hlavicka (docs/03 §3.5.4): u64 nextBlock@12, u32 blockSize@20, i32 count@24
(u map ZAPORNE), u32 concurrency@28. Kazdy blok: i32 filesCount, i64 nextBlock,
pak filesCount x 34 B zaznamu (offset i64, header i32, clen i32, dlen i32,
hash u64, dataHash u32, flag u16). Flag 0 = nekomprimovano, 1 = zlib.

ROZPOR R1 (docs/03 §3.5.4) - ROZHODNUTO MERENIM 2026-10-02:
  kandidati se lisili jen tim, jak se spoji dve 32bitove poloviny:
    (A) `create_hash` z ClassicUO (BSD-2) .......... 43 760/43 760 zaznamu (100 %)
    (B) `hashlittle2`, (pb << 32) | pc ............. 43 760/43 760 (stejna funkce)
    (C) `hashlittle2`, (pc << 32) | pb ............. 0/43 760
  Dokumentovanych "1636 z 2000" jsem zreprodukoval presne - ale je to JINE
  pocitadlo (docs/10 P12): 1636 je pocet INDEXU artu, ktere v archivu maji
  zaznam; chybejicich 364 nejsou chyba hashe, ale art ID, ktera v teto
  instalaci nejsou. Meri se proto pokryti VSECH 43 760 zaznamu archivu, a to
  je 100 % pro (A) i (B), 0 % pro (C). Pouziva se (A) - je to portovany kód
  z BSD-2 zdroje a je dokumentovany; (B) dava tytez hodnoty a je v modulu
  ponechan kvuli opakovatelnosti mereni.

Pouziti:
  python tools/uoextract/uop.py --verify --uop "<UO>/artLegacyMUL.uop"
  python tools/uoextract/uop.py --self-test
"""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
UOP_MAGIC = 0x0050594D
MASK32 = 0xFFFFFFFF
ART_NAME = "build/artlegacymul/%08d.tga"


def _rot(value: int, bits: int) -> int:
    return ((value << bits) | (value >> (32 - bits))) & MASK32


def hashlittle2(key: bytes, initval: int = 0, initval2: int = 0) -> tuple[int, int]:
    """Bob Jenkins lookup3 `hashlittle2` (public domain). Vraci (pc, pb)."""
    length = len(key)
    a = b = c = (0xDEADBEEF + length + initval) & MASK32
    c = (c + initval2) & MASK32
    if length == 0:
        # Kanonicky lookup3 pro nulovou delku NEMICHA: vrati seed rovnou
        # (self-test to hlida; bez toho by se hash prazdneho klice rozchazel).
        return c, b
    i = 0
    while length - i > 12:
        a = (a + int.from_bytes(key[i:i + 4], "little")) & MASK32
        b = (b + int.from_bytes(key[i + 4:i + 8], "little")) & MASK32
        c = (c + int.from_bytes(key[i + 8:i + 12], "little")) & MASK32
        a = (a - c) & MASK32; a ^= _rot(c, 4); c = (c + b) & MASK32
        b = (b - a) & MASK32; b ^= _rot(a, 6); a = (a + c) & MASK32
        c = (c - b) & MASK32; c ^= _rot(b, 8); b = (b + a) & MASK32
        a = (a - c) & MASK32; a ^= _rot(c, 16); c = (c + b) & MASK32
        b = (b - a) & MASK32; b ^= _rot(a, 19); a = (a + c) & MASK32
        c = (c - b) & MASK32; c ^= _rot(b, 4); b = (b + a) & MASK32
        i += 12
    tail = key[i:]
    pad = tail + b"\x00" * (12 - len(tail))
    parts = [int.from_bytes(pad[k:k + 4], "little") for k in range(0, 12, 4)]
    if len(tail) > 8:
        c = (c + parts[2]) & MASK32
    if len(tail) > 4:
        b = (b + parts[1]) & MASK32
    if len(tail) > 0:
        a = (a + parts[0]) & MASK32
    c ^= b; c = (c - _rot(b, 14)) & MASK32
    a ^= c; a = (a - _rot(c, 11)) & MASK32
    b ^= a; b = (b - _rot(a, 25)) & MASK32
    c ^= b; c = (c - _rot(b, 16)) & MASK32
    a ^= c; a = (a - _rot(c, 4)) & MASK32
    b ^= a; b = (b - _rot(a, 14)) & MASK32
    c ^= b; c = (c - _rot(b, 24)) & MASK32
    return c, b


def create_hash(text: str) -> int:
    """Port `CreateHash` z ClassicUO (src/ClassicUO.IO/UOFileUop.cs, BSD-2)."""
    M = MASK32
    eax = ecx = edx = ebx = esi = edi = 0
    s = text
    length = len(s)
    ebx = edi = esi = (length + 0xDEADBEEF) & M
    i = 0
    while i + 12 < length:
        edi = (((ord(s[i + 7]) << 24) | (ord(s[i + 6]) << 16) | (ord(s[i + 5]) << 8) | ord(s[i + 4])) + edi) & M
        esi = (((ord(s[i + 11]) << 24) | (ord(s[i + 10]) << 16) | (ord(s[i + 9]) << 8) | ord(s[i + 8])) + esi) & M
        edx = (((ord(s[i + 3]) << 24) | (ord(s[i + 2]) << 16) | (ord(s[i + 1]) << 8) | ord(s[i])) - esi) & M
        edx = ((edx + ebx) ^ (esi >> 28) ^ ((esi << 4) & M)) & M
        esi = (esi + edi) & M
        edi = ((edi - edx) ^ (edx >> 26) ^ ((edx << 6) & M)) & M
        edx = (edx + esi) & M
        esi = ((esi - edi) ^ (edi >> 24) ^ ((edi << 8) & M)) & M
        edi = (edi + edx) & M
        ebx = ((edx - esi) ^ (esi >> 16) ^ ((esi << 16) & M)) & M
        esi = (esi + edi) & M
        edi = ((edi - ebx) ^ (ebx >> 13) ^ ((ebx << 19) & M)) & M
        ebx = (ebx + esi) & M
        esi = ((esi - edi) ^ (edi >> 28) ^ ((edi << 4) & M)) & M
        edi = (edi + ebx) & M
        i += 12
    rem = length - i
    if rem > 0:
        if rem >= 12: esi = (esi + (ord(s[i + 11]) << 24)) & M
        if rem >= 11: esi = (esi + (ord(s[i + 10]) << 16)) & M
        if rem >= 10: esi = (esi + (ord(s[i + 9]) << 8)) & M
        if rem >= 9:  esi = (esi + ord(s[i + 8])) & M
        if rem >= 8:  edi = (edi + (ord(s[i + 7]) << 24)) & M
        if rem >= 7:  edi = (edi + (ord(s[i + 6]) << 16)) & M
        if rem >= 6:  edi = (edi + (ord(s[i + 5]) << 8)) & M
        if rem >= 5:  edi = (edi + ord(s[i + 4])) & M
        if rem >= 4:  ebx = (ebx + (ord(s[i + 3]) << 24)) & M
        if rem >= 3:  ebx = (ebx + (ord(s[i + 2]) << 16)) & M
        if rem >= 2:  ebx = (ebx + (ord(s[i + 1]) << 8)) & M
        if rem >= 1:  ebx = (ebx + ord(s[i])) & M
        esi = ((esi ^ edi) - ((edi >> 18) ^ ((edi << 14) & M))) & M
        ecx = ((esi ^ ebx) - ((esi >> 21) ^ ((esi << 11) & M))) & M
        edi = ((edi ^ ecx) - ((ecx >> 7) ^ ((ecx << 25) & M))) & M
        esi = ((esi ^ edi) - ((edi >> 16) ^ ((edi << 16) & M))) & M
        edx = ((esi ^ ecx) - ((esi >> 28) ^ ((esi << 4) & M))) & M
        edi = ((edi ^ edx) - ((edx >> 18) ^ ((edx << 14) & M))) & M
        eax = ((esi ^ edi) - ((edi >> 8) ^ ((edi << 24) & M))) & M
        return ((edi << 32) | eax) & 0xFFFFFFFFFFFFFFFF
    return ((esi << 32) | eax) & 0xFFFFFFFFFFFFFFFF


def hash_candidates(name: str) -> dict[str, int]:
    """Tri kandidati na hash jmena zaznamu (docs/03 §3.5.4, rozpor R1)."""
    pc, pb = hashlittle2(name.encode("latin-1"), 0, 0)
    return {
        "classicuo_create_hash": create_hash(name),
        "jenkins_pc_pb": ((pc << 32) | pb) & 0xFFFFFFFFFFFFFFFF,
        "jenkins_pb_pc": ((pb << 32) | pc) & 0xFFFFFFFFFFFFFFFF,
    }


_BWT_TABLES: dict[int, list[int]] = {}


def _bwt_build_table(start: int) -> list[int]:
    # Tabulka je pro dany start porad stejna a stavi se z 65 536 hodnot -
    # bez cache by se u tisicu gumpu pocitala porad dokola.
    table = _BWT_TABLES.get(start)
    if table is None:
        table = sorted((start + i) & 0xFFFF for i in range(65536))
        _BWT_TABLES[start] = table
    return table.copy()


def _bwt_shift_left(symbols: list[int], upto: int) -> None:
    for i in range(upto):
        symbols[i] = symbols[i + 1]


def _bwt_frequency(counts: list[int]) -> list[int]:
    """Indexy symbolu serazene podle cetnosti (selection sort jako v C#)."""
    work = list(counts[:256])
    order: list[int] = []
    for _ in range(256):
        best_index, best_value = 0, 0
        for j in range(256):
            if work[j] > best_value:
                best_index, best_value = j, work[j]
        if best_value == 0:
            break
        order.append(best_index)
        work[best_index] = 0
    return order


def _bwt_internal(data: bytes, length: int = 0) -> bytes:
    """Druha cast BWT dekomprese (MTF + tabulka cetnosti) - port z ClassicUO."""
    if len(data) < 1024:
        return b""
    counts = list(struct.unpack_from("<256I", data, 0))
    total = sum(counts)
    if length == 0:
        length = total
    if total != length:
        return b""
    symbols = list(range(256))
    starts = [0] * 256
    ends = [0] * 256
    non_zero = sum(1 for c in counts if c)
    order = _bwt_frequency(counts)
    m = 0
    for i in range(non_zero):
        symbol = order[i]
        symbols[data[m + 1024]] = symbol
        starts[symbol] = m + 1
        m += counts[symbol]
        ends[symbol] = m
    out = bytearray()
    value = symbols[0]
    while len(out) < length:
        first = starts[value]
        out.append(value)
        if first >= ends[value]:
            old = non_zero
            non_zero -= 1
            if old > 0:
                _bwt_shift_left(symbols, non_zero)
                value = symbols[0]
        else:
            index = data[first + 1024]
            starts[value] = first + 1
            if index != 0:
                _bwt_shift_left(symbols, index)
                symbols[index] = value
                value = symbols[0]
    return bytes(out)


def bwt_decompress(buffer: bytes) -> bytes:
    """Port `BwtDecompress` z ClassicUO (src/ClassicUO.Utility/BwtDecompress.cs, BSD-2).

    Hlavicka: u32 (nepouziva se) + 1 B firstChar. Pak se pro kazdy dalsi bajt
    otoci tabulkou 65536 hodnot; vysledek je MTF proud pro druhou cast.
    Pouziva ji gumpart (flag 3) i Cliloc.enu - proto je na vrstve kontejneru.
    """
    if len(buffer) < 6:
        return b""
    table = _bwt_build_table(buffer[4])
    out = bytearray(len(buffer) - 4)
    first = buffer[4]
    pos = 5
    index = 0
    while index < len(out):
        value = table[first]
        current = first
        while current > 0:
            table[current] = table[current - 1]
            current -= 1
        table[0] = value
        out[index] = value & 0xFF
        index += 1
        if pos < len(buffer):
            first = buffer[pos]
            pos += 1
    return _bwt_internal(bytes(out), 0)


class UopEntry:
    __slots__ = ("offset", "header_length", "compressed_length", "decompressed_length",
                 "hash", "data_hash", "flag")

    def __repr__(self) -> str:
        return (f"UopEntry(off={self.offset} hdr={self.header_length} "
                f"clen={self.compressed_length} dlen={self.decompressed_length} flag={self.flag})")


class UopFile:
    """Cteni MYP0 kontejneru. `raw` je jen pro offline testy (self-test)."""

    def __init__(self, path: str | Path | None = None, raw: bytes | None = None) -> None:
        self.path = str(path) if path else "<memory>"
        if raw is None:
            if path is None:
                raise ValueError("je potreba path nebo raw")
            raw = Path(path).read_bytes()
        self.raw = raw
        self.entries: list[UopEntry] = []
        self.blocks: list[tuple[int, int, int]] = []
        magic, self.version, self.timestamp, self.next_block, self.block_size, self.count = \
            struct.unpack_from("<IIIqiI", raw, 0)
        if magic != UOP_MAGIC:
            raise ValueError(f"spatny UOP magic 0x{magic:08X}")

    def read_entries(self) -> list[UopEntry]:
        offset = self.next_block
        while True:
            files_count, next_block = struct.unpack_from("<iq", self.raw, offset)
            self.blocks.append((files_count, next_block, len(self.entries)))
            blob = self.raw[offset + 12: offset + 12 + files_count * 34]
            for i in range(files_count):
                entry = UopEntry()
                (entry.offset, entry.header_length, entry.compressed_length,
                 entry.decompressed_length, entry.hash, entry.data_hash,
                 entry.flag) = struct.unpack_from("<qiiiQIH", blob, i * 34)
                self.entries.append(entry)
            if next_block == 0:
                break
            offset = next_block
        return self.entries

    def read_data(self, entry: UopEntry) -> bytes | None:
        if entry.offset == 0:
            return None
        start = entry.offset + entry.header_length
        raw = self.raw[start:start + entry.compressed_length]
        # Flagy podle ClassicUO CompressionType: 0 = raw, 1 a 2 = zlib,
        # 3 = zlib + BWT (gumpart ma v teto instalaci VSECHNY zaznamy flag 3).
        if entry.flag in (1, 2, 3):
            data = zlib.decompress(raw)
            return bwt_decompress(data) if entry.flag == 3 else data
        if entry.flag == 0:
            return self.raw[start:start + entry.decompressed_length]
        raise NotImplementedError(f"neznama komprese flag {entry.flag}")

    def hashes(self) -> set[int]:
        return {e.hash for e in self.entries if e.hash}

    def get_by_hash(self, value: int) -> bytes | None:
        for entry in self.entries:
            if entry.hash == value:
                return self.read_data(entry)
        return None

    def resolve(self, name: str, mode: str) -> UopEntry | None:
        wanted = hash_candidates(name)[mode]
        for entry in self.entries:
            if entry.hash == wanted:
                return entry
        return None

    def get(self, name: str, mode: str = "jenkins_pc_pb") -> bytes | None:
        entry = self.resolve(name, mode)
        return None if entry is None else self.read_data(entry)


# Zpetna kompatibilita: vyzkumne sondy (areas_4_7, debug_diamond, gumps,
# gump_bwt, gump_header, hash_probe) importuji `UOFileUop`. Pri prepsani na
# smluvni API se trida jmenuje `UopFile`; alias drzi sondy funkcni, aby se
# mericí historie dala kdykoli spustit znovu.
UOFileUop = UopFile


def verify(path: Path, indices: int = 2000, mode_out: list[str] | None = None) -> tuple[int, list[str]]:
    """Rozhodne R1: ktery kandidat pokryje VSECHNY zaznamy archivu.

    POZOR na dve ruzna pocitadla (docs/10 P12): "1636 z 2000" v docs/03 §3.5.4
    je pocet INDEXU artu, ktere maji v archivu zaznam - chybejicich 364 nejsou
    chyba hashe, ale art ID, ktera v teto instalaci nejsou. Naproti tomu
    "100 % z 43 760" je pocet ZAZNAMU archivu. Merit se proto musi oboji:
      * pokryti zaznamu: pro vsech 65 536 moznych indexu spocti hash a zjisti,
        kolik z 43 760 ulozenych hashu kandidat vubec dokaze najit,
      * pokryti indexu: kolik z prvnich N indexu ma art (srovnatelne s dokumenty).
    """
    uop = UopFile(path)
    entries = uop.read_entries()
    stored = uop.hashes()
    checks = 1
    errors: list[str] = []
    if not stored:
        return checks, ["UOP neobsahuje zadne hashovane zaznamy - kontrola NEPROBĚHLA"]

    covered = {name: 0 for name in hash_candidates("x")}
    present = 0
    for index in range(65536):
        candidates = hash_candidates(ART_NAME % index)
        if index < indices and any(v in stored for v in candidates.values()):
            present += 1
        for name, value in candidates.items():
            if value in stored:
                covered[name] += 1

    print(f"[uop] {path.name}: bloku {len(uop.blocks)}, zaznamu {len(entries)}, "
          f"unikatnich hashu {len(stored)}, hlavicka count={uop.count}")
    for name, hits in sorted(covered.items()):
        print(f"[uop] kandidat {name:22} pokryva {hits}/{len(stored)} zaznamu archivu")
    print(f"[uop] z prvnich {indices} indexu artu ma zaznam {present} "
          f"({indices - present} v teto instalaci nejsou; srovnatelne s docs/03 §3.5.4)")

    best = max(covered, key=lambda k: covered[k])
    checks += 1
    if covered[best] == 0:
        errors.append("zadny kandidat nenasel ani jeden zaznam - kontrola NEPROBĚHLA")
    elif covered[best] < len(stored):
        errors.append(f"ani jeden kandidat nepokryva vsechny zaznamy "
                      f"(nejlepsi {best}: {covered[best]}/{len(stored)})")
    else:
        print(f"[uop] R1 ROZHODNUTO: {best} pokryva vsech {len(stored)} zaznamu (100 %)")
    if mode_out is not None:
        mode_out.append(best)
    return checks, errors


def _synthetic() -> bytes:
    """Maly UOP: jeden blok, dva zaznamy (nekomprimovany a zlib)."""
    name_a = ART_NAME % 0
    name_b = ART_NAME % 1
    payload_a = b"ART-A" * 4
    payload_b = b"B" * 100
    packed_b = zlib.compress(payload_b)
    header_size = 28
    block_offset = header_size
    entries_offset = block_offset + 12
    data_offset = entries_offset + 2 * 34
    out = bytearray()
    out += struct.pack("<IIIqiI", UOP_MAGIC, 1, 0, block_offset, 1000, 2)
    out += struct.pack("<iq", 2, 0)
    out += struct.pack("<qiiiQIH", data_offset, 0, len(payload_a), len(payload_a),
                       hash_candidates(name_a)["jenkins_pc_pb"], 0, 0)
    out += struct.pack("<qiiiQIH", data_offset + len(payload_a), 0, len(packed_b), len(payload_b),
                       hash_candidates(name_b)["jenkins_pc_pb"], 0, 1)
    out += payload_a + packed_b
    return bytes(out)


def self_test() -> int:
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[uop] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    uop = UopFile(raw=_synthetic())
    entries = uop.read_entries()
    check(len(entries) == 2, f"hlavicka a bloky: {len(entries)} zaznamu")
    check(uop.get(ART_NAME % 0) == b"ART-A" * 4, "nekomprimovany zaznam se precte")
    check(uop.get(ART_NAME % 1) == b"B" * 100, "zlib zaznam se rozbalí")
    check(uop.get(ART_NAME % 7) is None, "neznamy zaznam vraci None (ne vyjimku)")
    check(uop.get_by_hash(hash_candidates(ART_NAME % 1)["jenkins_pc_pb"]) == b"B" * 100,
          "get_by_hash najde zaznam")

    pc, pb = hashlittle2(b"", 0, 0)
    check(pc == 0xDEADBEEF and pb == 0xDEADBEEF,
          f"hashlittle2 prazdneho klice vraci seed (pc=0x{pc:08X}, pb=0x{pb:08X})")
    known = hashlittle2(b"Four score and seven years ago", 0, 0)
    check(isinstance(known[0], int) and 0 <= known[0] <= MASK32,
          f"hashlittle2 vraci 32bitove hodnoty ({known})")
    check(hash_candidates("x")["jenkins_pc_pb"] != hash_candidates("y")["jenkins_pc_pb"],
          "ruzne nazvy maji ruzny hash")

    print(f"[uop] self-test: 8 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="MYP0 (UOP) kontejner a rozhodnutí R1")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--uop", default=None)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--indices", type=int, default=2000)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    path = Path(args.uop) if args.uop else Path(args.install) / "artLegacyMUL.uop"
    if not path.exists():
        print(f"[uop] CHYBA: {path} neexistuje")
        return 1
    if not args.verify:
        uop = UopFile(path)
        print(f"[uop] {path.name}: hlavicka OK, count={uop.count} (bez --verify se nic nemERilo)")
        return 0

    checks, errors = verify(path, args.indices)
    for e in errors:
        print(f"[uop] CHYBA: {e}")
    print(f"[uop] {checks} kontrol, {len(errors)} chyb")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
