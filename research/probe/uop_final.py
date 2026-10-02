"""FINAL, verified UOP reader for UO Classic 1.25.35.

Hash = Bob Jenkins lookup3 hashlittle2 over the entry path (NOT the C#
CreateHash present in ClassicUO's UOFileUop.cs, which does not match these
files). Layout of the container header and of the entry records was verified
byte-for-byte against the eight real .uop files in the install.
"""
import struct, os, zlib, collections

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"


def rotl(x, k):
    return ((x << k) | (x >> (32 - k))) & 0xFFFFFFFF


def hashlittle2(text):
    """UOFiddler Ultima/Helpers/UopUtils.cs::HashFileName.

    Each .NET char contributes its full 16-bit value; seed = len + 0xDEADBEEF;
    consumes 12 "bytes" (chars) per block; returns (b << 32) | c.
    """
    a = b = c = (len(text) + 0xDEADBEEF) & 0xFFFFFFFF
    n = len(text)
    i = 0
    ln = n
    while ln > 12:
        a = (a + (ord(text[i]) | ord(text[i+1]) << 8 | ord(text[i+2]) << 16 | ord(text[i+3]) << 24)) & 0xFFFFFFFF
        b = (b + (ord(text[i+4]) | ord(text[i+5]) << 8 | ord(text[i+6]) << 16 | ord(text[i+7]) << 24)) & 0xFFFFFFFF
        c = (c + (ord(text[i+8]) | ord(text[i+9]) << 8 | ord(text[i+10]) << 16 | ord(text[i+11]) << 24)) & 0xFFFFFFFF
        a = (a - c) & 0xFFFFFFFF; a ^= rotl(c, 4);  c = (c + b) & 0xFFFFFFFF
        b = (b - a) & 0xFFFFFFFF; b ^= rotl(a, 6);  a = (a + c) & 0xFFFFFFFF
        c = (c - b) & 0xFFFFFFFF; c ^= rotl(b, 8);  b = (b + a) & 0xFFFFFFFF
        a = (a - c) & 0xFFFFFFFF; a ^= rotl(c, 16); c = (c + b) & 0xFFFFFFFF
        b = (b - a) & 0xFFFFFFFF; b ^= rotl(a, 19); a = (a + c) & 0xFFFFFFFF
        c = (c - b) & 0xFFFFFFFF; c ^= rotl(b, 4);  b = (b + a) & 0xFFFFFFFF
        i += 12
        ln -= 12
    # trailing 1..12 chars, C# switch fall-through
    k = ln
    while k > 0:
        ch = ord(text[i + k - 1])
        if k >= 9:
            c = (c + (ch << ((k - 9) * 8))) & 0xFFFFFFFF
        elif k >= 5:
            b = (b + (ch << ((k - 5) * 8))) & 0xFFFFFFFF
        else:
            a = (a + (ch << ((k - 1) * 8))) & 0xFFFFFFFF
        k -= 1
    if ln == 0:
        return (c << 32) & 0xFFFFFFFFFFFFFFFF
    c = (c ^ b) & 0xFFFFFFFF; c = (c - rotl(b, 14)) & 0xFFFFFFFF
    a = (a ^ c) & 0xFFFFFFFF; a = (a - rotl(c, 11)) & 0xFFFFFFFF
    b = (b ^ a) & 0xFFFFFFFF; b = (b - rotl(a, 25)) & 0xFFFFFFFF
    c = (c ^ b) & 0xFFFFFFFF; c = (c - rotl(b, 16)) & 0xFFFFFFFF
    a = (a ^ c) & 0xFFFFFFFF; a = (a - rotl(c, 4)) & 0xFFFFFFFF
    b = (b ^ a) & 0xFFFFFFFF; b = (b - rotl(a, 14)) & 0xFFFFFFFF
    c = (c ^ b) & 0xFFFFFFFF; c = (c - rotl(b, 24)) & 0xFFFFFFFF
    return ((b << 32) | c) & 0xFFFFFFFFFFFFFFFF


class Uop:
    def __init__(self, path):
        self.path = path
        self.size = os.path.getsize(path)
        self.f = open(path, "rb")
        d = self.f.read(40)
        self.magic, self.version, self.fmt, self.nextblock = struct.unpack_from("<IIII", d, 0)
        self.count = struct.unpack_from("<I", d, 24)[0]
        self.u28 = struct.unpack_from("<I", d, 28)[0]
        self.u32 = struct.unpack_from("<I", d, 32)[0]
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
        raise ValueError(f"compression flag {e['flag']} (Mythic) unsupported here")


CASES = [
    ("artLegacyMUL.uop",      "build/artlegacymul/{:08d}.tga",              0x14000),
    ("tileart.uop",           "build/tileart/{:08d}.tga",                   0x4000),
    ("gumpartLegacyMUL.uop",  "build/gumpartlegacymul/{:08d}.tga",          0x10000),
    ("MultiCollection.uop",   "build/multicollection/{:06d}.bin",           0x3000),
    ("MainMisc.uop",          "build/mainmisc/{:08d}.bin",                  0x1000),
    ("string_dictionary.uop", "build/string_dictionary/{:08d}.bin",         0x1000),
]

print(f"hashlittle2('build/artlegacymul/00000000.tga') = {hashlittle2('build/artlegacymul/00000000.tga'):#018x}")
print(f"hashlittle2('build/multicollection/housing.bin') = {hashlittle2('build/multicollection/housing.bin'):#018x}  (UOFiddler says 0x126D1E99DDEDEE0A)")

for fn, pat, scanmax in CASES:
    p = os.path.join(UODIR, fn)
    print("=" * 108)
    if not os.path.exists(p):
        print(f"{fn}: MISSING"); continue
    u = Uop(p)
    fl = collections.Counter(e["flag"] for e in u.entries.values())
    hl = collections.Counter(e["hlen"] for e in u.entries.values())
    print(f"{fn}: size={u.size} ver={u.version} nextBlock={u.nextblock} count={u.count} "
          f"u28={u.u28} u32={u.u32}")
    print(f"  blocks={len(u.blocks)} entries={len(u.entries)} flags={dict(fl)} hlen={dict(hl)}")
    print(f"  clen total={sum(e['clen'] for e in u.entries.values())} "
          f"dlen total={sum(e['dlen'] for e in u.entries.values())}")
    names = {}
    for i in range(scanmax):
        names.setdefault(hashlittle2(pat.format(i)), i)
    present = sorted(names[h] for h in u.entries if h in names)
    print(f"  PATTERN {pat!r}: matched={len(present)}/{len(u.entries)} "
          f"min={present[0] if present else None} max={present[-1] if present else None}")
    if present:
        for i in present[:3]:
            e = u.get(pat.format(i))
            try:
                dat = u.read(e)
                print(f"    idx {i}: off={e['off']} clen={e['clen']} dlen={e['dlen']} flag={e['flag']} "
                      f"inflated={len(dat)} first20={dat[:20].hex(' ')}")
            except Exception as ex:
                print(f"    idx {i}: {ex}")
    else:
        for h, e in list(u.entries.items())[:2]:
            print(f"    sample hash={h:#018x} off={e['off']} dlen={e['dlen']} flag={e['flag']}")

# animation patterns: find which AnimationFrame*.uop holds which body
print("=" * 108)
print("ANIMATION: scanning body/action keys across AnimationFrame*.uop")
for i in (1, 2, 3, 4, 6):
    fn = f"AnimationFrame{i}.uop"
    p = os.path.join(UODIR, fn)
    if not os.path.exists(p):
        print(f"  {fn}: MISSING"); continue
    u = Uop(p)
    found = []
    for body in range(0, 2048):
        for action in range(0, 40):
            if hashlittle2(f"build/animationlegacyframe/{body:06d}/{action:02d}.bin") in u.entries:
                found.append((body, action))
                break
    bodies = sorted({b for b, a in found})
    print(f"  {fn}: entries={len(u.entries)} bodies-with-entries={len(bodies)} "
          f"min={bodies[0] if bodies else None} max={bodies[-1] if bodies else None}")
    if bodies:
        runs, s, prev = [], bodies[0], bodies[0]
        for v in bodies[1:]:
            if v != prev + 1:
                runs.append((s, prev)); s = v
            prev = v
        runs.append((s, prev))
        print(f"    body runs({len(runs)}): {runs[:12]}{' ...' if len(runs) > 12 else ''}")

# AnimationSequence
p = os.path.join(UODIR, "AnimationSequence.uop")
u = Uop(p)
seq = [i for i in range(4096) if u.get(f"build/animationsequence/{i:08d}.bin")]
print(f"  AnimationSequence.uop: entries={len(u.entries)} matched={len(seq)} "
      f"min={seq[0] if seq else None} max={seq[-1] if seq else None}")
if seq:
    e = u.get(f"build/animationsequence/{seq[0]:08d}.bin")
    dat = u.read(e)
    print(f"    first seq idx {seq[0]}: dlen={e['dlen']} first64={dat[:64].hex(' ')}")
