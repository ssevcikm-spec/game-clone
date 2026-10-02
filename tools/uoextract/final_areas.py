"""Final verification of skills.mul (12-byte records), hues.mul, skillgrp.mul, statics."""
import os, struct, re

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"

print("=" * 78)
print("SKILLS.MUL  (58 records x 12 bytes = 696, +8 slack = 704)")
print("=" * 78)
sk = open(os.path.join(UO, "skills.mul"), 'rb').read()
print("size=%d  58*12=%d  slack=%d" % (len(sk), 58*12, len(sk)-58*12))
names = []
for i in range(58):
    rec = sk[i*12:(i+1)*12]
    nm = rec.split(b'\0')[0]
    nm = bytes(c for c in nm if 0x20 <= c < 0x7f).decode('latin-1')
    names.append(nm)
print("client-order skill names (%d):" % len(names))
for i, n in enumerate(names):
    ok = "OK " if n and n.isprintable() else "?? "
    print("   %s id=%-2d %r" % (ok, i, n))
clean = sum(1 for n in names if n and all(0x20 <= c < 0x7f for c in n.encode('latin-1')))
print("clean names: %d / 58 (%.1f%%)" % (clean, 100.0*clean/58))
print("trailing 8 bytes:", sk[696:].hex())

print()
print("=" * 78)
print("SKILLGRP.MUL  (4-byte header + 7 fixed 20-byte group names = 144)")
print("=" * 78)
sg = open(os.path.join(UO, "skillgrp.mul"), 'rb').read()
gc = struct.unpack_from('<i', sg, 0)[0]
print("size=%d  i32 groupCount=%d  4+7*20=%d" % (len(sg), gc, 4+7*20))
groups = []
for i in range(gc):
    o = 4 + i*20
    nm = sg[o:o+20].split(b'\0')[0].decode('latin-1')
    groups.append(nm)
    print("   group %d @%-4d %r" % (i, o, nm))
print("after names, offset %d; remaining %d bytes as u32:" % (144, len(sg)-144))
rest = sg[144:]
vals = [struct.unpack_from('<I', rest, i*4)[0] for i in range(len(rest)//4)]
print("   %d u32 values: %s" % (len(vals), vals))
print("   nonzero u32 values: %s" % [v for v in vals if v])

print()
print("=" * 78)
print("HUES.MUL")
print("=" * 78)
h = open(os.path.join(UO, "hues.mul"), 'rb').read()
REC, HDR = 88, 4
n = (len(h)-HDR)//REC
print("size=%d  header=%d records=%d  4+%d*88=%d (slack %d)"
      % (len(h), HDR, n, n, HDR+n*REC, len(h)-(HDR+n*REC)))
named = 0
for k in range(n):
    o = HDR + k*REC
    nm = h[o+68:o+88].split(b'\0')[0]
    if nm:
        named += 1
print("records carrying a non-empty 20-byte name at +68: %d / %d" % (named, n))
# verify embedded name against the start/end fields
bad = ok = 0
for k in range(n):
    o = HDR + k*REC
    s, e = struct.unpack_from('<HH', h, o+64)
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    if not nm:
        continue
    if nm == "Hue (%d->%d)" % (s, e):
        ok += 1
    else:
        bad += 1
print("named records where name == 'Hue (start->end)': %d match, %d differ" % (ok, bad))
for k in (0, 1, 2):
    o = HDR + k*REC
    cols = struct.unpack_from('<32H', h, o)
    s, e = struct.unpack_from('<HH', h, o+64)
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    print("  hue[%d] start=%-5d end=%-5d name=%-16r first 8 colours=%s"
          % (k, s, e, nm, list(cols[:8])))

print()
print("=" * 78)
print("MAP + STATICS")
print("=" * 78)
print("statics0.mul=%d -> %d records of 7 bytes (remainder %d)"
      % (os.path.getsize(os.path.join(UO, "statics0.mul")),
         os.path.getsize(os.path.join(UO, "statics0.mul"))//7,
         os.path.getsize(os.path.join(UO, "statics0.mul")) % 7))
print("staidx0.mul=%d -> %d blocks of 12 bytes" %
      (os.path.getsize(os.path.join(UO, "staidx0.mul")),
       os.path.getsize(os.path.join(UO, "staidx0.mul"))//12))
print("  block index for (x=1495,y=1630) with side=768 : bx=%d by=%d -> %d"
      % (1495//8, 1630//8, (1495//8)*768 + 1630//8))
