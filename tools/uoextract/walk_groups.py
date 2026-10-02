"""
Walk tiledata.mul group-by-group and find where each layout stops holding.

Land block (hand-verified):  [u32 hdr] + 32 x 26 bytes, x512 groups, offset 0
Item record variants (from ClassicUO TileDataLoader, BSD-2-Clause):
  old: [u32 flags][u8 weight][u8 layer][i32 count][u16 anim][u16 hue][u16 light][u8 height][20 name] = 37
  new: [u64 flags][same 13 bytes]                                                          [20 name] = 41
"""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
print("size", N)

LAND_OFF, LAND_STRIDE, LAND_CNT, LAND_GROUPS = 4, 26, 512, 512
land_end = LAND_OFF + LAND_GROUPS * (4 + 32*LAND_STRIDE)
print("land block: 4 .. %d  (%d bytes)" % (land_end, land_end - 4))
print("bytes at land_end:", data[land_end:land_end+24].hex())


def valid_name(raw):
    z = raw.find(b'\0')
    nm = raw[:z if z >= 0 else len(raw)]
    return len(nm) > 0 and all(0x20 <= c < 0x7f for c in nm), nm


def walk_items(off, stride, flaglen, groups=None, verbose=0):
    """Walk item groups from off. Returns (groups_ok, last_off, first_fail)."""
    namelen = stride - flaglen - 2
    g = 0
    reason = None
    while True:
        if groups is not None and g >= groups:
            reason = 'group-limit'
            break
        if off + 4 + 32*stride > N:
            reason = 'eof'
            break
        hdr = int.from_bytes(data[off:off+4], 'little')
        ok = 0
        for k in range(32):
            b = off + 4 + k*stride
            good, nm = valid_name(data[b+flaglen+2: b+flaglen+2+namelen])
            if good: ok += 1
        if verbose and g < verbose:
            print("   group %4d off=%8d hdr=%d clean=%2d/32" % (g, off, hdr, ok))
        if ok < 16:
            reason = 'group %d only %d/32 clean (hdr=%d)' % (g, ok, hdr)
            break
        off += 4 + 32*stride
        g += 1
    return g, off, reason


print("\n=== walk OLD items (37B, u32 flags) from land_end ===")
g, end, why = walk_items(land_end, 37, 4, verbose=3)
print("   groups=%d  stopped at %d (%.2f%% of file)  reason: %s" % (g, end, 100.0*end/N, why))

print("\n=== walk NEW items (41B, u64 flags) from land_end ===")
g, end, why = walk_items(land_end, 41, 8, verbose=3)
print("   groups=%d  stopped at %d (%.2f%% of file)  reason: %s" % (g, end, 100.0*end/N, why))
