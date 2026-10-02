"""Verify the 41-byte item record layout end-to-end and find all block boundaries."""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
STRIDE, NAMEOFF = 41, 21
LAND_OFF, LAND_STRIDE, LAND_CNT, LAND_GROUPS = 4, 26, 512, 512


def nameok(b, n=20):
    raw = data[b:b+n]
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else n]
    return (len(s) > 0 and all(0x20 <= c < 0x7f for c in s)), s


def walk(off, maxg=100000, thresh=26):
    g = 0
    o = off
    while o + 4 + 32*STRIDE <= N:
        ok = sum(1 for k in range(32) if nameok(o + 4 + k*STRIDE + NAMEOFF)[0])
        if ok < thresh:
            return g, o, 'grp%d %d/32 clean (hdr=%d)' % (g, ok, int.from_bytes(data[o:o+4],'little'))
        o += 4 + 32*STRIDE
        g += 1
        if g > maxg: return g, o, 'maxg'
    return g, o, 'eof'


print("=== walk item groups from the measured block start 428036 ===")
g, end, why = walk(428036)
print("groups=%d end=%d (%.1f%% of file) reason=%s" % (g, end, 100.0*end/N, why))
print("-> item block covers tiles 0..%d" % (g*32 - 1))
print("next offset =", end, "bytes:", data[end:end+32].hex())
