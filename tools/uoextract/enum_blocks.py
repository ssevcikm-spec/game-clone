"""
Enumerator: given the two proven anchors, walk the whole file and report blocks.

Established by hand:
  Block A (land) : off 4,   512 groups x (u32 hdr + 32 x 26B)  = 428,032 B  -> ends 428,036
  Block B (items): off 428,036, group 0 starts with record 'decimated_NoName',
                   name at record+21, stride 41  (u64 flags)
The task says ids 0x40.. exist for items, so item block 1 holds tiles 0..0x3FFF
and the file must contain further blocks. Confirm by walking to EOF.
"""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
LAND_OFF, LAND_STRIDE, LAND_CNT, LAND_GROUPS = 4, 26, 512, 512
land_end = LAND_OFF + LAND_GROUPS*(4 + 32*LAND_STRIDE)
print("size", N)
print("block A (land): 4 .. %d" % land_end)


def nm(b, n):
    raw = data[b:b+n]
    z = raw.find(b'\0')
    return raw[:z if z >= 0 else n]


def nameok(b, n):
    s = nm(b, n)
    return len(s) > 0 and all(0x20 <= c < 0x7f for c in s)


def try_block(off, stride, nameoff, namelen, maxgroups=200000):
    """Walk item groups. Return (ngroups, end_off, reason)."""
    g = 0
    o = off
    while True:
        if o + 4 + 32*stride > N:
            return g, o, 'eof'
        ok = sum(1 for k in range(32) if nameok(o + 4 + k*stride + nameoff, namelen))
        if ok < 24:
            return g, o, 'group %d: %d/32 clean' % (g, ok)
        o += 4 + 32*stride
        g += 1
        if g > maxgroups:
            return g, o, 'maxgroups'


for stride, nameoff, fl in ((41, 21, 8), (37, 21, 4), (41, 17, 8), (37, 17, 4), (30, 21, 8)):
    namelen = stride - nameoff - 1 if False else 20
    g, end, why = try_block(land_end, stride, nameoff, namelen)
    print("items stride=%-3d nameoff=%-3d -> groups=%6d  end=%8d (%.1f%%)  %s"
          % (stride, nameoff, g, end, 100.0*end/N, why))
