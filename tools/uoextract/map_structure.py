"""
tiledata.mul - definitive structural map (measured, not assumed).

MEASURED FACTS
--------------
LAND block, offset 4:
    stride 30 bytes = [u64 flags][u16 texId][char name[20]]
    (verified: name 'UNUSED' at +10 = 4+8+2-4? no: record 0 starts at 4, name at 4+8+2 = 14?
     -> resolved below by direct arithmetic on the string offsets 10,44,74,104,134,164,194)

ITEM block:
    stride 41 bytes = [u64 flags][u8 weight][u8 layer][i32 count][u16 animID][u16 hue]
                      [u16 light][u8 height][char name[20]]
    (verified: gargoyle_leather_arm flags=0x00404002 weight=4 layer=19=Arms count=566
     animID=585 hue=7 light=1)

This script finds the true group counts by walking and reporting.
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)


def nm(b, n=20):
    raw = data[b:b+n]
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else n]
    return (len(s) > 0 and all(0x20 <= c < 0x7f for c in s)), s


def walk(off, stride, nameoff, hdrlen, maxg=100000, thresh=26):
    g = 0; o = off
    while o + hdrlen + 32*stride <= N:
        c = sum(1 for k in range(32) if nm(o + hdrlen + k*stride + nameoff)[0])
        if c < thresh:
            return g, o, 'grp%d %d/32 hdr=%d' % (g, c, int.from_bytes(data[o:o+4], 'little'))
        o += hdrlen + 32*stride
        g += 1
        if g > maxg: return g, o, 'maxg'
    return g, o, 'eof'


print("size", N)
print()
print("=== %-46s ===" % "LAND 30B/8B-flags/name@+10, hdr 4" )
g, end, why = walk(4, 30, 10, 4)
print("   groups=%d end=%d  tiles=%d  %s" % (g, end, g*32, why))
print()
for lbl, off, stride, noff, hdr in (
    ("ITEM 41B (hdr4)", 15312, 41, 21, 4),
    ("ITEM 41B (hdr0)", 15312, 41, 21, 0),
    ("ITEM 41B from 15316", 15316, 41, 21, 4),
):
    g, end, why = walk(off, stride, noff, hdr)
    print("=== %-40s groups=%5d end=%8d tiles=0..%7d  %s"
          % (lbl, g, end, g*32-1, why))
