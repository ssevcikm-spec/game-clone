"""UOP (Mythic Package) verifier.

Layout confirmed byte-by-byte with PowerShell BitConverter against the real
files, and the walk algorithm is from ClassicUO src/ClassicUO.IO/UOFileUop.cs.

Header, little-endian, offsets measured from byte 0:
  0  u32 magic        0x0050594D  ("MYP\\0")
  4  u32 version      5 (artLegacyMUL), 4 (all others here)
  8  u32 format/timestamp   0xFD23EC43 in every shipped file
 12  u32 hashCapacity   hash table occupies [32, 32 + 16*hashCapacity)
 16  u32 [unknown]      0 in every shipped file
 20  u64 nextBlock       absolute offset of first block record
 28  u32 blockSize
 32  u32 count           == number of file entries
The nextBlock u64 IS at offset 20; the u32 at 16 is an unused/gap field.
"""
import struct
import os
import zlib
import collections

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"


def create_hash(text):
    """ClassicUO UOFileUop.CreateHash, 1:1 port.
    Seed/offset constant: 0xDEADBEEF added to the byte length of the string."""
    s = text.encode("ascii")
    M = 0xFFFFFFFF
    eax = ecx = edx = ebx = esi = edi = 0
    n = len(s)
    ebx = edi = esi = (n + 0xDEADBEEF) & M
    i = 0
    while i + 12 < n:
        edi = (((s[i+7] << 24) | (s[i+6] << 16) | (s[i+5] << 8) | s[i+4]) + edi) & M
        esi = (((s[i+11] << 24) | (s[i+10] << 16) | (s[i+9] << 8) | s[i+8]) + esi) & M
        edx = (((s[i+3] << 24) | (s[i+2] << 16) | (s[i+1] << 8) | s[i]) - esi) & M
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
    rem = n - i
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
        d = self.f.read(36)
        self.raw = d
        self.magic, self.version, self.fmt, self.blockoff = struct.unpack_from("<IIII", d, 0)
        self.hashcap = self.blockoff
        self.count = struct.unpack_from("<I", d, 24)[0]
        self.blocksize = struct.unpack_from("<I", d, 28)[0]
        self.trailer = struct.unpack_from("<I", d, 32)[0]
        self.raw_header = d[:40]
        self.entries = {}
        self.blocks = []
        self._walk()

    def _walk(self):
        off = self.blockoff
        guard = 0
        while off:
            guard += 1
            if guard > 1000000:
                raise RuntimeError("block loop")
            self.f.seek(off)
            hdr = self.f.read(12)
            if len(hdr) < 12:
                raise RuntimeError(f"truncated block header at {off}")
            cnt, nxt = struct.unpack("<iQ", hdr)
            self.blocks.append((off, cnt, nxt))
            buf = self.f.read(34 * cnt)
            for i in range(cnt):
                o, hlen, clen, dlen, h, dh, flag = struct.unpack_from("<QiIIQIh", buf, 34 * i)
                if o == 0:
                    continue
                self.entries[h] = dict(off=o + hlen, hlen=hlen, clen=clen, dlen=dlen,
                                       hash=h, dhash=dh, flag=flag)
            off = nxt

    def get(self, name):
        return self.entries.get(create_hash(name))

    def read(self, e):
        self.f.seek(e["off"])
        raw = self.f.read(e["clen"])
        return zlib.decompress(raw) if e["flag"] == 1 else raw


CASES = [
    ("artLegacyMUL.uop",      "build/artlegacymul/{}.tga",      0x14000),
    ("tileart.uop",           "build/tileart/{}.tga",           0x4000),
    ("gumpartLegacyMUL.uop",  "build/gumpartlegacymul/{}.tga",  0x10000),
    ("AnimationFrame1.uop",   "build/animationframe1/{}.tga",   0x10000),
    ("AnimationFrame2.uop",   "build/animationframe2/{}.tga",   0x10000),
    ("AnimationSequence.uop", "build/animationsequence/{}.bin", 0x10000),
    ("MultiCollection.uop",   "build/multicollection/{}.bin",   0x10000),
    ("MainMisc.uop",          "build/mainmisc/{}.bin",          0x2000),
    ("string_dictionary.uop", "build/string_dictionary/{}.bin", 0x2000),
]

for fn, pat, scanmax in CASES:
    p = os.path.join(UODIR, fn)
    print("=" * 110)
    if not os.path.exists(p):
        print(f"{fn}: MISSING")
        continue
    try:
        u = Uop(p)
    except Exception as ex:
        print(f"{fn}: PARSE ERROR {ex!r}")
        continue
    print(f"{fn}  size={u.size}  version={u.version}  nextBlock={u.blockoff}  "
          f"count={u.count}  u32@28={u.blocksize}  u32@32={u.trailer}")
    print(f"  hashTable=[32,{32+16*u.hashcap})  blocks={len(u.blocks)}  entries={len(u.entries)}")
    fl = collections.Counter(e["flag"] for e in u.entries.values())
    hl = collections.Counter(e["hlen"] for e in u.entries.values())
    print(f"  flags={dict(fl)}  headerLengths={dict(hl)}  blockSizes(first5)={[b[1] for b in u.blocks[:5]]}")
    if u.entries:
        print(f"  sum clen={sum(e['clen'] for e in u.entries.values())}  "
              f"sum dlen={sum(e['dlen'] for e in u.entries.values())}  "
              f"max dlen={max(e['dlen'] for e in u.entries.values())}")
    names = {}
    for i in range(scanmax):
        names.setdefault(create_hash(pat.format(i)), i)
    present = sorted(names[h] for h in u.entries if h in names)
    if present:
        runs, s, prev = [], present[0], present[0]
        for v in present[1:]:
            if v != prev + 1:
                runs.append((s, prev)); s = v
            prev = v
        runs.append((s, prev))
        print(f"  PATTERN {pat!r}: matched={len(present)} min={present[0]} max={present[-1]} "
              f"unmatchedEntries={len(u.entries)-len(present)}")
        print(f"    runs({len(runs)}): {runs[:10]}{' ...' if len(runs) > 10 else ''}")
        for i in present[:3]:
            e = u.get(pat.format(i))
            try:
                dat = u.read(e)
                print(f"    idx {i}: off={e['off']} hlen={e['hlen']} clen={e['clen']} "
                      f"dlen={e['dlen']} flag={e['flag']} inflated={len(dat)} first16={dat[:16].hex(' ')}")
            except Exception as ex:
                print(f"    idx {i}: READ ERROR {ex}")
    else:
        print(f"  PATTERN {pat!r}: NO MATCHES of {len(u.entries)} entries -- pattern likely wrong")
        for h, e in list(u.entries.items())[:3]:
            print(f"    sample hash={h:#018x} off={e['off']} dlen={e['dlen']} flag={e['flag']}")
