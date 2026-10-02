"""Focused fixes: Cliloc layout, Skills.mul via Skills.idx, skillgrp.mul, statics, hues."""
import os, struct, sys

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"

print("=" * 78)
print("CLILOC.ENU")
print("=" * 78)
d = open(os.path.join(UO, "Cliloc.enu"), 'rb').read()
print("size=%d first 32: %s" % (len(d), d[:32].hex()))
# The classic layout is [i32 num][u8 flag][u16 len][utf16]. It fails at offset 0.
# Try every header offset AND both len semantics; score by ascending numbers.
def attempt(off, lenpos, flagpos, numpos, lensize, label, maxent=400000):
    p = off
    n = len(d)
    ents = []
    while p + 7 <= n:
        if numpos == 0:
            num = struct.unpack_from('<i', d, p)[0]
        else:
            num = struct.unpack_from('<i', d, p+numpos)[0]
        ln = struct.unpack_from('<H', d, p+lensize)[0] if lensize == 2 else \
             struct.unpack_from('<i', d, p+lensize)[0]
        if ln <= 0 or p + 7 + ln > n or ln > 65535:
            break
        s = d[p+7:p+7+ln]
        if len(s) < 2:
            break
        try:
            txt = s.decode('utf-16-le')
        except Exception:
            break
        if not txt or any(ord(c) < 0x20 and c not in '\r\n\t' for c in txt):
            break
        ents.append((num, ln, txt))
        p += 7 + ln
        if len(ents) > maxent:
            break
    asc = all(ents[i][0] < ents[i+1][0] for i in range(len(ents)-1)) if len(ents) > 1 else False
    return ents, p, asc

best = None
for off in range(0, 16):
    ents, p, asc = attempt(off, None, None, 0, 5, "off%d" % off)
    if best is None or len(ents) > len(best[0]):
        best = (ents, p, asc, off)
    if len(ents) > 10:
        print("  header=%2d -> %6d entries, consumed %d/%d, ascending=%s"
              % (off, len(ents), p, len(d), asc))
ents, p, asc, off = best
print("BEST header offset = %d : %d entries, consumed %d/%d, ascending=%s"
      % (off, len(ents), p, len(d), asc))
if ents:
    print("  first 6:")
    for e in ents[:6]:
        print("     num=%-8d len=%-4d %r" % (e[0], e[1], e[2]))
    print("  last 3:")
    for e in ents[-3:]:
        print("     num=%-8d len=%-4d %r" % (e[0], e[1], e[2]))
    # find a msg containing leather/backpack for human check
    for e in ents:
        if 'backpack' in e[2].lower():
            print("  sample: num=%d %r" % (e[0], e[2]))
            break

print()
print("=" * 78)
print("SKILLS.MUL via SKILLS.IDX")
print("=" * 78)
sk = open(os.path.join(UO, "skills.mul"), 'rb').read()
si = open(os.path.join(UO, "Skills.idx"), 'rb').read()
print("skills.mul=%d bytes, Skills.idx=%d bytes -> %d u32 offsets"
      % (len(sk), len(si), len(si)//4))
offs = list(struct.unpack_from('<%dI' % (len(si)//4), si, 0))
print("  first 12 offsets:", offs[:12])
print("  (Skills.idx is 3072 bytes = 768 u32; skills.mul is only 704 bytes so only")
print("   the first few offsets are usable; classic skills.mul is a fixed-record array.)")
# classic skills.mul: 58 records of 12 bytes? 704/12 = 58.67 ; 704/11=64 ; 704/16=44
for rec in (11, 12, 13, 16):
    print("   704 / %d = %.3f" % (rec, 704/rec))
# The names seen suggest: each skill record = [u8 hasName][char name[?]]  Let's
# extract by reading records of 12 bytes and printing.
print()
print("  hypothesis: record = 12 bytes starting at offset 0; names are NUL-terminated inside")
for rec, start in ((12, 0), (12, 1), (11, 0)):
    names = []
    p = start
    while p + rec <= len(sk):
        chunk = sk[p:p+rec]
        z = chunk.find(b'\0')
        nm = chunk[:z if z >= 0 else rec]
        # strip leading non-printable marker bytes
        nm2 = bytes(c for c in nm if 0x20 <= c < 0x7f)
        names.append(nm2.decode('latin-1'))
        p += rec
    good = [n for n in names if n and n.isprintable()]
    print("  rec=%d start=%d -> %d records, %d look like names" % (rec, start, len(names), len(good)))
    if len(good) >= 50 and start == 0 and rec == 12:
        for i, n in enumerate(names):
            print("     %2d %r" % (i, n))

print()
print("=" * 78)
print("SKILLGRP.MUL")
print("=" * 78)
sg = open(os.path.join(UO, "skillgrp.mul"), 'rb').read()
print("size=%d" % len(sg))
gc = struct.unpack_from('<i', sg, 0)[0]
print("  i32 groupCount = %d" % gc)
p = 4
groups = []
try:
    for g in range(gc):
        nl = struct.unpack_from('<i', sg, p)[0]
        p += 4
        gname = sg[p:p+nl].decode('latin-1')
        p += nl
        nsk = struct.unpack_from('<i', sg, p)[0]
        p += 4
        ids = list(struct.unpack_from('<%di' % nsk, sg, p)) if nsk else []
        p += 4*nsk
        groups.append((gname, ids))
    print("  consumed %d/%d" % (p, len(sg)))
    for gname, ids in groups:
        print("   %-24r %2d skills %s" % (gname, len(ids), ids))
except Exception as ex:
    print("  parse error at p=%d: %s" % (p, ex))

print()
print("=" * 78)
print("HUES.MUL")
print("=" * 78)
h = open(os.path.join(UO, "hues.mul"), 'rb').read()
hdr = struct.unpack_from('<i', h, 0)[0]
REC = 88
n = (len(h)-4)//REC
print("size=%d header_i32=%d (size-4)%%88=%d -> %d records"
      % (len(h), hdr, (len(h)-4) % REC, n))
for k in (0, 1, 2, 500, 1500, n-1):
    o = 4 + k*REC
    cols = struct.unpack_from('<32H', h, o)
    s, e = struct.unpack_from('<HH', h, o+64)
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    print("  hue[%-5d] start=%-5d end=%-5d name=%-16r first4 colours=%s"
          % (k, s, e, nm, cols[:4]))
bad = 0
for k in range(n):
    o = 4 + k*REC
    s, e = struct.unpack_from('<HH', h, o+64)
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    if nm != "Hue (%d->%d)" % (s, e):
        bad += 1
print("  name != 'Hue (start->end)' for %d / %d records" % (bad, n))
print("  4 + %d*88 = %d (file %d)" % (n, 4 + n*88, len(h)))

print()
print("=" * 78)
print("STATICS  (block math: staidx 12 B/block, statics 7 B/record)")
print("=" * 78)
sx = os.path.join(UO, "staidx0.mul")
sd = os.path.join(UO, "statics0.mul")
nblocks = os.path.getsize(sx)//12
print("staidx0.mul=%d bytes -> %d blocks" % (os.path.getsize(sx), nblocks))
import math
side = int(math.isqrt(nblocks))
print("  isqrt(%d) = %d  (%d^2 = %d)" % (nblocks, side, side, side*side))
print("statics0.mul=%d bytes -> %d records of 7 B (remainder %d)"
      % (os.path.getsize(sd), os.path.getsize(sd)//7, os.path.getsize(sd) % 7))
bx, by = 1495//8, 1630//8
for label, idx in (("bx*%d+by" % side, bx*side+by), ("by*%d+bx" % side, by*side+bx)):
    if idx >= nblocks:
        print("  %s idx=%d OUT OF RANGE" % (label, idx))
        continue
    with open(sx, 'rb') as f:
        f.seek(idx*12)
        off, length, extra = struct.unpack('<iii', f.read(12))
    print("  %s idx=%d -> offset=%d length=%d extra=%d" % (label, idx, off, length, extra))
    if off == -1 or length <= 0:
        print("     (empty block)")
        continue
    with open(sd, 'rb') as f:
        f.seek(off)
        raw = f.read(length)
    recs = []
    for i in range(len(raw)//7):
        tid, x, y, z, hue = struct.unpack_from('<HBBbH', raw, i*7)
        recs.append((tid, x, y, z, hue))
    print("     %d records; first 14:" % len(recs))
    for r in recs[:14]:
        print("        tile=0x%04X (%5d) x=%2d y=%2d z=%-4d hue=%d" % (r[0], r[0], r[1], r[2], r[3], r[4]))
    if recs:
        print("     z range %d..%d ; x range %d..%d ; y range %d..%d"
              % (min(r[3] for r in recs), max(r[3] for r in recs),
                 min(r[1] for r in recs), max(r[1] for r in recs),
                 min(r[2] for r in recs), max(r[2] for r in recs)))
