"""
Areas 4-7 in one script:
  4. MAP + STATICS  (map0LegacyMUL.uop block, statics0.mul / staidx0.mul)
  5. CLILOC.ENU
  6. SKILLS.MUL + SKILLGRP.MUL
  7. HUES.MUL
Each section prints the measured evidence.
"""
import os, struct, zlib, sys

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
OUT = r"E:\Workspaces\game-clone\research\extract-out"
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, r'E:\Workspaces\game-clone\tools\uoextract')
from uop import UOFileUop, create_hash

print("#" * 78)
print("# 4. MAP + STATICS")
print("#" * 78)
# map0LegacyMUL.uop holds the map blocks; block 0 = (0,0)
# ClassicUO MapLoader: uop pattern "build/map0legacymul/{0:D8}.dat", and the
# block index = (x // 8) *  blockWidth + (y // 8) ... verify with the file's own
# structure: a map block is 196 bytes (64 tiles * 3 bytes?) -> actually 4 bytes
# header + 64 cells * 3 bytes = 196.
mp = os.path.join(UO, "map0LegacyMUL.uop")
u = UOFileUop(mp)
ents = u.read_entries()
byh = {e.hash: e for e in ents if e.offset}
print("map0LegacyMUL.uop: entries=%d nonzero=%d" % (len(ents), len(byh)))
flags = {}
for e in ents:
    flags[e.flag] = flags.get(e.flag, 0) + 1
print("  compression flags:", flags)
pat = "build/map0legacymul/%08d.dat"
resolved = [i for i in range(0, 0x2000) if create_hash(pat % i) in byh]
print("  resolved block indices under pattern %r: %d (min %s max %s)"
      % (pat, len(resolved), min(resolved) if resolved else None,
         max(resolved) if resolved else None))

# Britain around x=1495,y=1630 -> block (1495//8, 1630//8) = (186, 203)
BX, BY = 1495 // 8, 1630 // 8
print("  target block (x=1495,y=1630) -> blockX=%d blockY=%d" % (BX, BY))
# ClassicUO: mapblock index = blockX * (mapWidth/8) + blockY  ; try both orders
for name, idx in (("x*W+y", BX * 7168 + BY), ("y*W+x", BY * 7168 + BX)):
    e = byh.get(create_hash(pat % idx))
    print("    idx=%-8d (%s) -> %s" % (idx, name, "present" if e else "MISSING"))
    if e:
        u.f.seek(e.offset + e.header_length)
        blk = zlib.decompress(u.f.read(e.compressed_length)) if e.flag == 1 else \
              u.f.read(e.decompressed_length)
        print("      block len=%d (expected 196)" % len(blk))
        if len(blk) >= 196:
            print("      first 24 bytes:", blk[:24].hex())
            cells = []
            for i in range(64):
                v = struct.unpack_from('<H', blk, 4 + i*3)[0]
                z = struct.unpack_from('<b', blk, 4 + i*3 + 2)[0]
                cells.append((v, z))
            print("      land tile ids:", [c[0] for c in cells[:8]], "...")
            print("      z values     :", [c[1] for c in cells[:8]], "...")
            bad = [c for c in cells if not (0 <= c[0] <= 0x3FFF) or not (-128 <= c[1] <= 127)]
            print("      cells with id outside 0..0x3FFF or z outside -128..127: %d" % len(bad))
            break

# statics
def statics_block(facet, bx, by):
    sx = os.path.join(UO, "staidx%d.mul" % facet)
    sd = os.path.join(UO, "statics%d.mul" % facet)
    n = os.path.getsize(sx) // 12
    w = 7168
    if bx >= w or by >= w:
        return None
    idx = bx * w + by
    if idx >= n:
        return None
    with open(sx, 'rb') as f:
        f.seek(idx*12)
        off, length, _ = struct.unpack('<iii', f.read(12))
    if off == -1 or length <= 0:
        return []
    with open(sd, 'rb') as f:
        f.seek(off)
        raw = f.read(length)
    out = []
    for i in range(len(raw)//7):
        tid, x, y, z, hue = struct.unpack_from('<HBBbH', raw, i*7)
        out.append((tid, x, y, z, hue))
    return out

print()
print("  staidx0.mul size=%d -> %d entries of 12 bytes" %
      (os.path.getsize(os.path.join(UO, "staidx0.mul")),
       os.path.getsize(os.path.join(UO, "staidx0.mul")) // 12))
st = statics_block(0, BX, BY)
if st is None:
    print("  statics block (%d,%d): out of range" % (BX, BY))
else:
    print("  statics block (%d,%d): %d records" % (BX, BY, len(st)))
    print("    first 12:", st[:12])
    if st:
        tidok = sum(1 for s in st if 0 <= s[0] <= 0xFFFF)
        zok = sum(1 for s in st if -128 <= s[3] <= 127)
        print("    tile id u16 ok: %d/%d ; z in -128..127: %d/%d"
              % (tidok, len(st), zok, len(st)))
        print("    distinct statics ids: %d" % len(set(s[0] for s in st)))

print()
print("#" * 78)
print("# 5. CLILOC.ENU")
print("#" * 78)
cl = open(os.path.join(UO, "Cliloc.enu"), 'rb').read()
print("size=%d  first 24 bytes: %s" % (len(cl), cl[:24].hex()))
# Candidate A: classic [i32 number][u8 flag][u16 len][utf16 string] from offset 0
# Candidate B: 6-byte header then that layout
def try_cliloc(buf, off, label):
    p = off
    n = len(buf)
    entries = []
    while p + 7 <= n:
        num = struct.unpack_from('<i', buf, p)[0]
        flag = buf[p+4]
        ln = struct.unpack_from('<H', buf, p+5)[0]
        if ln == 0 or p + 7 + ln > n:
            break
        s = buf[p+7:p+7+ln]
        try:
            txt = s.decode('utf-16-le')
        except Exception:
            break
        if not all(0x20 <= ord(c) < 0x10000 for c in txt):
            break
        entries.append((num, flag, ln, txt))
        p += 7 + ln
    asc = sum(1 for e in entries if len(e) == 4 and e[0] > 0 and
              all(ord(c) >= 0x20 for c in e[3]))
    print("  %-28s parsed %6d entries, consumed %d/%d, ascending-numbers=%s"
          % (label, len(entries), p, n,
             all(entries[i][0] < entries[i+1][0] for i in range(len(entries)-1))
             if len(entries) > 1 else 'n/a'))
    return entries, p

for off in (0, 4, 6, 8, 12):
    ents, p = try_cliloc(cl, off, "offset %d" % off)
    if len(ents) > 1000:
        print("     first 5:")
        for e in ents[:5]:
            print("       num=%-8d flag=%d len=%-4d %r" % (e[0], e[1], e[2], e[3]))
        print("     last 2:")
        for e in ents[-2:]:
            print("       num=%-8d flag=%d len=%-4d %r" % (e[0], e[1], e[2], e[3]))
        break

print()
print("#" * 78)
print("# 6. SKILLS.MUL + SKILLGRP.MUL")
print("#" * 78)
sk = open(os.path.join(UO, "skills.mul"), 'rb').read()
print("skills.mul size=%d" % len(sk))
names = []
i = 0
while i < len(sk):
    z = sk.find(b'\0', i)
    if z < 0:
        break
    names.append(sk[i:z].decode('latin-1'))
    i = z + 1
print("  null-terminated strings found: %d" % len(names))
for k, nm in enumerate(names):
    print("    %2d  %r" % (k, nm))
si = open(os.path.join(UO, "Skills.idx"), 'rb').read()
print("Skills.idx size=%d -> %d entries of 4 bytes (offset)" % (len(si), len(si)//4))
sg = open(os.path.join(UO, "skillgrp.mul"), 'rb').read()
print("skillgrp.mul size=%d  first 40 bytes: %s" % (len(sg), sg[:40].hex()))
# classic layout: i32 groupCount, then per group: i32 nameLen + name chars,
# then per group i32 skillCount + skill ids
p = 0
try:
    gcount = struct.unpack_from('<i', sg, p)[0]
    print("  groupCount=%d" % gcount)
    p += 4
    groups = []
    for g in range(gcount):
        nl = struct.unpack_from('<i', sg, p)[0]
        p += 4
        gname = sg[p:p+nl].decode('latin-1')
        p += nl
        nsk = struct.unpack_from('<i', sg, p)[0]
        p += 4
        ids = list(struct.unpack_from('<%di' % nsk, sg, p)) if nsk else []
        p += 4*nsk
        groups.append((gname, ids))
    print("  consumed %d/%d bytes" % (p, len(sg)))
    for gname, ids in groups:
        print("    group %-22r %d skills: %s" % (gname, len(ids), ids))
except Exception as ex:
    print("  parse failed: %s" % ex)

print()
print("#" * 78)
print("# 7. HUES.MUL")
print("#" * 78)
h = open(os.path.join(UO, "hues.mul"), 'rb').read()
print("size=%d" % len(h))
hdr = struct.unpack_from('<i', h, 0)[0]
print("  header i32 = %d" % hdr)
REC = 88
print("  (size-4)/88 = %.4f  -> %s" %
      ((len(h)-4)/REC, "exact" if (len(h)-4) % REC == 0 else "NOT exact"))
n = (len(h)-4)//REC
print("  records: %d" % n)
for k in (0, 1, 2, 100, 1000, n-1):
    o = 4 + k*REC
    cols = struct.unpack_from('<32H', h, o)
    start, end = struct.unpack_from('<HH', h, o+64)
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    print("  hue[%-5d] start=%-5d end=%-5d name=%-14r first4=%s"
          % (k, start, end, nm, cols[:4]))
# verify the embedded name matches start/end
bad = 0
for k in range(n):
    o = 4 + k*REC
    s, e = struct.unpack_from('<HH', h, o+64)
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    if nm != "Hue (%d->%d)" % (s, e):
        bad += 1
print("  records whose name != 'Hue (start->end)': %d / %d" % (bad, n))
