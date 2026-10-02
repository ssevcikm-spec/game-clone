"""FINAL verified UOP reader for UO Classic 1.25.35 -- single correct layout.

Header (little-endian). CONFIRMED for version 4 AND version 5 containers:
   0  u32  magic              0x0050594D "MYP\\0"
   4  u32  version            5 = artLegacyMUL + map*LegacyMUL, 4 = everything else here
   8  u32  format_timestamp   0xFD23EC43 in every shipped file
  12  u64  nextBlock          absolute offset of the first block record
  20  u32  blockSize          1000 in every shipped file
  24  i32  count              entry count; NEGATIVE for sparse/truncated facets
                              (map0/1/2/3/5 = -2; map4 = -1)
  28  u32  concurrency?       1 for version-5 containers, 0 otherwise
  32  ...  hash table region [32, 32 + 16*N) -- all zeros in shipped files, ignored

Block chain (12-byte header, then 34-byte entry records):
   i32 filesCount ; i64 nextBlock (0 = end)
Entry record (34 bytes):
   i64 dataOffset ; i32 headerLength ; i32 compressedLength ; i32 decompressedLength
   u64 identifier ; u32 dataHash(adler32) ; i16 compressionFlag (0 stored, 1 zlib, 3 BWT)
Payload = file[dataOffset + headerLength : + compressedLength]
"""
import struct, os, zlib, collections

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"


def rotl(x, k):
    return ((x << k) | (x >> (32 - k))) & 0xFFFFFFFF


def hashlittle2(text):
    """Jenkins lookup3 hashlittle2 over the entry path. Seed = len + 0xDEADBEEF,
    result = (b << 32) | c. Ported from UOFiddler Ultima/Helpers/UopUtils.cs."""
    M = 0xFFFFFFFF
    a = b = c = (len(text) + 0xDEADBEEF) & M
    i, ln = 0, len(text)
    while ln > 12:
        a = (a + (ord(text[i])    | ord(text[i+1]) << 8  | ord(text[i+2]) << 16 | ord(text[i+3]) << 24)) & M
        b = (b + (ord(text[i+4])  | ord(text[i+5]) << 8  | ord(text[i+6]) << 16 | ord(text[i+7]) << 24)) & M
        c = (c + (ord(text[i+8])  | ord(text[i+9]) << 8  | ord(text[i+10])<< 16 | ord(text[i+11])<< 24)) & M
        a = (a - c) & M; a ^= rotl(c, 4);  c = (c + b) & M
        b = (b - a) & M; b ^= rotl(a, 6);  a = (a + c) & M
        c = (c - b) & M; c ^= rotl(b, 8);  b = (b + a) & M
        a = (a - c) & M; a ^= rotl(c, 16); c = (c + b) & M
        b = (b - a) & M; b ^= rotl(a, 19); a = (a + c) & M
        c = (c - b) & M; c ^= rotl(b, 4);  b = (b + a) & M
        i += 12; ln -= 12
    k = ln
    while k > 0:
        ch = ord(text[i + k - 1])
        if   k >= 9: c = (c + (ch << ((k - 9) * 8))) & M
        elif k >= 5: b = (b + (ch << ((k - 5) * 8))) & M
        else:        a = (a + (ch << ((k - 1) * 8))) & M
        k -= 1
    if ln == 0:
        return (c << 32) & 0xFFFFFFFFFFFFFFFF
    c = (c ^ b) & M; c = (c - rotl(b, 14)) & M
    a = (a ^ c) & M; a = (a - rotl(c, 11)) & M
    b = (b ^ a) & M; b = (b - rotl(a, 25)) & M
    c = (c ^ b) & M; c = (c - rotl(b, 16)) & M
    a = (a ^ c) & M; a = (a - rotl(c, 4))  & M
    b = (b ^ a) & M; b = (b - rotl(a, 14)) & M
    c = (c ^ b) & M; c = (c - rotl(b, 24)) & M
    return ((b << 32) | c) & 0xFFFFFFFFFFFFFFFF


class Uop:
    def __init__(self, path):
        self.path = path
        self.size = os.path.getsize(path)
        self.f = open(path, "rb")
        d = self.f.read(32)
        self.magic, self.version, self.fmt = struct.unpack_from("<III", d, 0)
        self.nextblock = struct.unpack_from("<Q", d, 12)[0]
        self.blocksize = struct.unpack_from("<I", d, 20)[0]
        self.count     = struct.unpack_from("<i", d, 24)[0]
        self.conc      = struct.unpack_from("<I", d, 28)[0]
        self.entries = {}
        self.blocks = []
        self._walk()

    def _walk(self):
        off = self.nextblock
        while off:
            self.f.seek(off)
            cnt, nxt = struct.unpack("<iQ", self.f.read(12))
            self.blocks.append((off, cnt, nxt))
            buf = self.f.read(34 * cnt)
            for i in range(cnt):
                o, hlen, clen, dlen, h, dh, flag = struct.unpack_from("<QiIIQIh", buf, 34 * i)
                if o == 0:
                    continue
                self.entries[h] = dict(off=o + hlen, hlen=hlen, clen=clen, dlen=dlen,
                                       flag=flag, dhash=dh)
            off = nxt

    def get(self, name):
        return self.entries.get(hashlittle2(name))

    def read(self, e):
        self.f.seek(e["off"])
        raw = self.f.read(e["clen"])
        if e["flag"] == 1:
            return zlib.decompress(raw)
        if e["flag"] == 0:
            return raw
        raise ValueError("flag 3 (BWT) needs BwtDecompress")


CASES = [
    ("artLegacyMUL.uop",      "build/artlegacymul/{:08d}.tga",             0x14000),
    ("tileart.uop",           "build/tileart/{:08d}.bin",                  0x4000),
    ("gumpartLegacyMUL.uop",  "build/gumpartlegacymul/{:08d}.tga",         0x10000),
    ("MultiCollection.uop",   "build/multicollection/{:06d}.bin",          0x3000),
    ("AnimationSequence.uop", "build/animationsequence/{:08d}.bin",        0x1000),
    ("soundLegacyMUL.uop",    "build/soundlegacymul/{:08d}.dat",           0x2000),
    ("map0LegacyMUL.uop",     "build/map0legacymul/{:08d}.dat",            0x2000),
    ("map1LegacyMUL.uop",     "build/map1legacymul/{:08d}.dat",            0x2000),
    ("map2LegacyMUL.uop",     "build/map2legacymul/{:08d}.dat",            0x2000),
    ("map3LegacyMUL.uop",     "build/map3legacymul/{:08d}.dat",            0x2000),
    ("map4LegacyMUL.uop",     "build/map4legacymul/{:08d}.dat",            0x2000),
    ("map5LegacyMUL.uop",     "build/map5legacymul/{:08d}.dat",            0x2000),
    ("map0xLegacyMUL.uop",    "build/map0legacymul/{:08d}.dat",            0x2000),
]
print("hashlittle2('build/multicollection/housing.bin') =",
      hex(hashlittle2("build/multicollection/housing.bin")), "(expect 0x126d1e99ddedee0a)")
print()
for fn, pat, scanmax in CASES:
    p = os.path.join(UODIR, fn)
    if not os.path.exists(p):
        print(f"{fn}: MISSING"); continue
    u = Uop(p)
    names = {}
    for i in range(scanmax):
        names.setdefault(hashlittle2(pat.format(i)), i)
    present = sorted(names[h] for h in u.entries if h in names)
    fl = collections.Counter(e["flag"] for e in u.entries.values())
    dl = collections.Counter(e["dlen"] for e in u.entries.values())
    runs = []
    if present:
        s = prev = present[0]
        for v in present[1:]:
            if v != prev + 1:
                runs.append((s, prev)); s = v
            prev = v
        runs.append((s, prev))
    print(f"{fn:<24} v{u.version} nextBlock={u.nextblock:<8} count={u.count:<7} "
          f"blocks={len(u.blocks):<4} entries={len(u.entries):<6} flags={dict(fl)}")
    print(f"    matched={len(present)}/{len(u.entries)} runs={runs[:4]} "
          f"dlenTop={dl.most_common(2)}")
# sound payload sanity
u = Uop(os.path.join(UODIR, "soundLegacyMUL.uop"))
e = u.get("build/soundlegacymul/00000000.dat")
if e:
    d = u.read(e)
    print("\nsound 0: len", len(d), "first16", d[:16].hex(" "), "RIFF?", d[:4] == b"RIFF")
