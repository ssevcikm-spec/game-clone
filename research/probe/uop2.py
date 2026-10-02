"""Correct UOP (Mythic Package) probe.

Implements the algorithm verified in ClassicUO src/ClassicUO.IO/UOFileUop.cs
(BSD-2-Clause) and checks it against the real files in the local UO install:
header layout, block chain, 34-byte entry records, compression flags, zlib
inflation, and the filename -> hash mapping per container.
"""
import struct
import os
import zlib
import collections

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"


def create_hash(text: str) -> int:
    """ClassicUO UOFileUop.CreateHash, ported 1:1 (32-bit wrapping)."""
    s = text.encode("ascii")
    M = 0xFFFFFFFF
    eax = ecx = edx = ebx = esi = edi = 0
    ln = len(s)
    ebx = edi = esi = (ln + 0xDEADBEEF) & M
    i = 0
    while i + 12 < ln:
        edi = (((s[i + 7] << 24) | (s[i + 6] << 16) | (s[i + 5] << 8) | s[i + 4]) + edi) & M
        esi = (((s[i + 11] << 24) | (s[i + 10] << 16) | (s[i + 9] << 8) | s[i + 8]) + esi) & M
        edx = (((s[i + 3] << 24) | (s[i + 2] << 16) | (s[i + 1] << 8) | s[i]) - esi) & M
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
    rem = ln - i
    if rem > 0:
        for k in range(rem, 0, -1):
            c = s[i + k - 1]
            if k >= 9:
                esi = (esi + (c << ((k - 9) * 8))) & M
            elif k >= 5:
                edi = (edi + (c << ((k - 5) * 8))) & M
            else:
                ebx = (ebx + (c << ((k - 1) * 8))) & M
        esi = ((esi ^ edi) - ((edi >> 18) ^ ((edi << 14) & M))) & M
        ecx = ((esi ^ ebx) - ((esi >> 21) ^ ((esi << 11) & M))) & M
        edi = ((edi ^ ecx) - ((ecx >> 7) ^ ((ecx << 25) & M))) & M
        esi = ((esi ^ edi) - ((edi >> 16) ^ ((edi << 16) & M))) & M
        edx = ((esi ^ ecx) - ((esi >> 28) ^ ((esi << 4) & M))) & M
        edi = ((edi ^ edx) - ((edx >> 18) ^ ((edx << 14) & M))) & M
        eax = ((esi ^ edi) - ((edi >> 8) ^ ((edi << 24) & M))) & M
        return ((edi << 32) | eax) & 0xFFFFFFFFFFFFFFFF
    return ((esi << 32) | eax) & 0xFFFFFFFFFFFFFFFF


class Uop:
    def __init__(self, path):
        self.path = path
        self.size = os.path.getsize(path)
        self.f = open(path, "rb")
        head = self.f.read(32)
        magic, ver, fmt, hcap = struct.unpack("<IIII", head[:16])
        nextblock, blocksize, fcount = struct.unpack("<qII", head[16:32])
        self.magic, self.ver, self.fmt, self.hcap = magic, ver, fmt, hcap
        self.nextblock, self.blocksize, self.filecount = nextblock, blocksize, fcount
        self.count = hcap
        self.raw_header = head[:32]
        self.entries = {}
        self.blocks = []
        self._walk()

    def _walk(self):
        nb = self.nextblock
        guard = 0
        while nb:
            guard += 1
            if guard > 500000:
                raise RuntimeError("block chain loop")
            self.f.seek(nb)
            # VERIFIED BYTE ORDER: int32 filesCount, then int64 nextBlock
            blk = self.f.read(12)
            if len(blk) < 12:
                print(f"    [walk] short block header at {nb}: got {len(blk)} bytes; stopping")
                break
            filesCount, nextBlock = struct.unpack("<iQ", blk)
            self.blocks.append((nb, filesCount, nextBlock))
            for _ in range(filesCount):
                off, hlen, clen, dlen, h, dhash, flag = struct.unpack("<QiIIQIh", self.f.read(34))
                if off == 0:
                    continue
                self.entries[h] = dict(off=off + hlen, hlen=hlen, clen=clen, dlen=dlen,
                                       hash=h, dhash=dhash, flag=flag)
            nb = nextBlock

    def read(self, e):
        self.f.seek(e["off"])
        raw = self.f.read(e["clen"])
        if e["flag"] == 1:
            return zlib.decompress(raw)
        if e["flag"] == 0:
            return raw
        raise ValueError(f"unsupported flag {e['flag']}")


PATTERNS = {
    "artLegacyMUL.uop":      ("build/artlegacymul/{}.tga", 0x14000),
    "tileart.uop":           ("build/tileart/{}.tga", 0x4000),
    "gumpartLegacyMUL.uop":  ("build/gumpartlegacymul/{}.tga", 0x10000),
    "AnimationFrame1.uop":   ("build/animationframe1/{}.tga", 0x8000),
    "AnimationSequence.uop": ("build/animationsequence/{}.bin", 0x800),
    "MultiCollection.uop":   ("build/multicollection/{}.bin", 0x4000),
    "MainMisc.uop":          ("build/mainmisc/{}.bin", 0x1000),
    "string_dictionary.uop": ("build/string_dictionary/{}.bin", 0x1000),
}


def report(name, pattern, scan_max, do_scan=True, do_read=True):
    p = os.path.join(UODIR, name)
    if not os.path.exists(p):
        print(f"\n### {name}: MISSING")
        return None
    u = Uop(p)
    print(f"\n### {name}  size={u.size}  raw_header={u.raw_header.hex(' ')}")
    print(f"  magic=0x{u.magic:08X} version={u.ver} format=0x{u.fmt:08X} hashCapacity={u.hcap}")
    print(f"  nextBlock={u.nextblock} blockSize={u.blocksize} headerFileCount={u.filecount}")
    print(f"  hash table would span [32, {32 + u.hcap*16}) -- "
          f"{'beyond EOF!' if 32 + u.hcap*16 > u.size else 'inside file'}")
    print(f"  blocks={len(u.blocks)}  first3={u.blocks[:3]}")
    fl = collections.Counter(e["flag"] for e in u.entries.values())
    hl = collections.Counter(e["hlen"] for e in u.entries.values())
    print(f"  entries={len(u.entries)}  flags={dict(fl)}  headerLengths={dict(hl)}")
    print(f"  load factor = {len(u.entries)}/{u.count} = {100.0*len(u.entries)/u.count:.2f}%")
    if u.entries:
        print(f"  sum clen={sum(e['clen'] for e in u.entries.values())}"
              f"  sum dlen={sum(e['dlen'] for e in u.entries.values())}"
              f"  max dlen={max(e['dlen'] for e in u.entries.values())}")
    if not do_scan:
        return u
    names = {}
    for i in range(scan_max):
        names.setdefault(create_hash(pattern.format(i)), i)
    present = sorted(names[h] for h in u.entries if h in names)
    print(f"  SCAN pattern {pattern!r} over 0..{scan_max-1}: matched={len(present)}"
          f" min={present[0] if present else None} max={present[-1] if present else None}"
          f" entries-unmatched-by-pattern={len(u.entries)-len(present)}")
    if present:
        runs, s, prev = [], present[0], present[0]
        for v in present[1:]:
            if v != prev + 1:
                runs.append((s, prev))
                s = v
            prev = v
        runs.append((s, prev))
        print(f"  contiguous index runs ({len(runs)}): {runs[:14]}{' ...' if len(runs) > 14 else ''}")
        print(f"  sum dlen over matched = {sum(u.entries[create_hash(pattern.format(i))]['dlen'] for i in present)}")
    if do_read and present:
        for i in present[:3]:
            e = u.entries[create_hash(pattern.format(i))]
            try:
                d = u.read(e)
                print(f"    idx {i}: off={e['off']} hlen={e['hlen']} clen={e['clen']} dlen={e['dlen']}"
                      f" flag={e['flag']} -> inflated {len(d)} B, first16={d[:16].hex(' ')}")
            except Exception as ex:
                print(f"    idx {i}: READ ERROR {ex}")
    return u


if __name__ == "__main__":
    t = "build/artlegacymul/00000000.tga"
    print(f"hash sanity {t!r} = {create_hash(t):#018x}")
    for name, (pattern, scan_max) in PATTERNS.items():
        try:
            report(name, pattern, scan_max)
        except Exception as ex:
            print(f"\n### {name}: ERROR {ex!r}")
        print()
