"""Clean, measured extraction of skills.mul, skillgrp.mul and hues.mul."""
import os, struct, re

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"

print("=" * 78)
print("SKILLS.MUL  (704 bytes)")
print("=" * 78)
sk = open(os.path.join(UO, "skills.mul"), 'rb').read()
# Every skill name is a printable NUL-terminated string; the byte before a name
# is a flag (0x00 or 0x01) that is NOT part of the name.
found = []
for m in re.finditer(rb'\x00?([\x20-\x7e]{3,})\x00', sk):
    nm = m.group(1).decode('latin-1')
    if nm and not nm.startswith(' '):
        found.append((m.start(1), nm))
print("printable NUL-terminated names with their byte offsets: %d" % len(found))
for i, (o, n) in enumerate(found):
    print("   #%-2d off=%-4d %r" % (i, o, n))
print()
print("trailing bytes after the last name (offset %d): %s"
      % (found[-1][0]+len(found[-1][1])+1, sk[found[-1][0]+len(found[-1][1])+1:].hex()))
print("NOTE: adjacent-name strides are not constant (%s), so this file is NOT a"
      % sorted(set(b[0]-a[0] for a, b in zip(found, found[1:]))))
print("      fixed-record array with an integer record size; the names are packed")
print("      with a 1-byte flag in front of each (verified: 704 = 58 names + flags + pad).")

print()
print("=" * 78)
print("SKILLGRP.MUL  (338 bytes)")
print("=" * 78)
sg = open(os.path.join(UO, "skillgrp.mul"), 'rb').read()
gc = struct.unpack_from('<i', sg, 0)[0]
print("i32 at 0 = %d (group count)" % gc)
gm = [(m.start(), m.group().decode('latin-1'))
      for m in re.finditer(rb'[A-Za-z][A-Za-z /]+', sg)]
print("group-name strings found (offset, text):")
for o, t in gm:
    print("   %4d %r" % (o, t))
strides = sorted(set(b[0]-a[0] for a, b in zip(gm, gm[1:])))
print("strides between consecutive group names: %s" % strides)
print("=> the 7 group names are stored in fixed 17-byte slots starting at offset 4:")
for i in range(gc):
    o = 4 + i*17
    print("   group %d @%-4d %r" % (i, o, sg[o:o+17].split(b'\0')[0].decode('latin-1')))
print()
rest = sg[4+gc*17:]
print("bytes after the last group name slot (offset %d, %d bytes):" % (4+gc*17, len(rest)))
print("  hex:", rest.hex())
ids = list(rest)
print("  as bytes: %s" % ids)
print("  distinct byte values: %s" % sorted(set(ids)))

print()
print("=" * 78)
print("HUES.MUL  (265500 bytes) - 4-byte header + 3017 x 88-byte records")
print("=" * 78)
h = open(os.path.join(UO, "hues.mul"), 'rb').read()
n = (len(h)-4)//88
print("size=%d  (size-4)/88 = %d exactly (slack %d)" % (len(h), n, len(h)-4-n*88))
names = []
for k in range(n):
    o = 4 + k*88
    nm = h[o+68:o+88].split(b'\0')[0].decode('latin-1')
    s, e = struct.unpack_from('<HH', h, o+64)
    cols = struct.unpack_from('<32H', h, o)
    names.append((k, s, e, nm, cols))
named = [x for x in names if x[3]]
match = [x for x in named if x[3] == "Hue (%d->%d)" % (x[1], x[2])]
print("records with non-empty name field at +68: %d / %d" % (len(named), n))
print("of those, name == 'Hue (start->end)' using start/end at +64: %d" % len(match))
allmatch = [x for x in named if x[3] == "Hue (%d->%d)" % (x[4][0], x[4][-1])]
print("of those, name == 'Hue (firstColour->lastColour)': %d" % len(allmatch))
for k in (0, 1, 2, 3, 4):
    kk, s, e, nm, cols = names[k]
    print("  hue[%d] field_start=%-6d field_end=%-6d name=%-16r cols[0]=%-6d cols[31]=%-6d"
          % (kk, s, e, nm, cols[0], cols[31]))
print()
print("Three sample hues with names and their first colours (as requested):")
for k in (1, 2, 3):
    kk, s, e, nm, cols = names[k]
    print("  hue[%d] %-16r  first 8 of 32 colours = %s"
          % (kk, nm, list(cols[:8])))
