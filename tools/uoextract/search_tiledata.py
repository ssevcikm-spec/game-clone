"""
Disciplined structural search for tiledata.mul.

Self-consistency checks available:
  (a) id field must equal either the sequential record index or 0
  (b) name must be printable ASCII (or empty)
  (c) land block at offset 0 is already decoded by hand: 26-byte records
  (d) the file size must factor exactly
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
print("size", N)

# ---- 1. Hand-verified land block: offset 4, stride 26, [u32 flags][u16 id][20 name]
def dump_land(off=4, stride=26, cnt=6):
    for i in range(cnt):
        b = off + i*stride
        f = int.from_bytes(data[b:b+4], 'little')
        tid = int.from_bytes(data[b+4:b+6], 'little')
        nm = data[b+6:b+26].split(b'\0')[0].decode('ascii', 'replace')
        print("   land[%d] off=%6d flags=0x%08x id=%d name=%r" % (i, b, f, tid, nm))

print("\n== hand-verified land members (offset 4, stride 26) ==")
dump_land()
dump_land(off=4+7*26, cnt=4)
dump_land(off=4+8*26, cnt=4)

# land block extent
LAND_OFF, LAND_STRIDE, LAND_CNT = 4, 26, 512
land_end = LAND_OFF + LAND_STRIDE*LAND_CNT
print("\nland block: %d..%d (%d bytes)" % (LAND_OFF, land_end, LAND_STRIDE*LAND_CNT))

def good_name(raw, namelen):
    z = raw.find(b'\0')
    nm = raw[:z if z >= 0 else namelen]
    return len(nm) > 0 and all(0x20 <= c < 0x7f for c in nm), nm

# ---- 2. Now measure: at which offsets do item offsets coincide with strings?
# Find all printable string starts in [land_end, N)
starts = set()
i = land_end
while i < N:
    if 0x20 <= data[i] < 0x7f:
        starts.add(i); i += 1
    else:
        i += 1
print("string starts in item region:", len(starts))

# ---- 3. Global phase analysis: for candidate strides, in sliding windows,
#         which phase (off % stride) hits most string starts?
for stride in (26, 30, 37, 41):
    # phase histogram over whole item region relative to land_end
    hist = collections.Counter()
    for s in starts:
        hist[(s - land_end) % stride] += 1
    top = hist.most_common(5)
    print("stride %2d phase histogram top5 (rel to land_end): %s" % (stride, top))

# ---- 4. Windowed phase analysis: where does each phase dominate?
print("\n=== windowed dominant phase (window 200000, strides 26/30/37/41) ===")
print("%9s %6s %6s %6s %6s" % ("win_start", "s26", "s30", "s37", "s41"))
for w in range(0, N, 200000):
    win = [s for s in starts if w <= s < w+200000]
    row = []
    for stride in (26, 30, 37, 41):
        h = collections.Counter((s - land_end) % stride for s in win)
        if not win: row.append("-"); continue
        ph, c = h.most_common(1)[0]
        row.append("%d:%d%%" % (ph, 100*c//len(win)))
    print("%9d %6s %6s %6s %6s   (n=%d)" % (w, row[0], row[1], row[2], row[3], len(win)))

# ---- 5. So: for each window find the stride+phase that maximises *records* where
#         id==index (or id==0) AND name printable.  This is the real test.
print("\n=== per-window best (stride, phase, id-consistency) ===")


def score(off, stride, namelen, flaglen, cnt):
    """Return (clean, idmatch) for cnt records starting at off."""
    clean = 0; idmatch = 0
    for k in range(cnt):
        b = off + k*stride
        if b + flaglen + 2 + namelen > N: break
        tid = int.from_bytes(data[b+flaglen:b+flaglen+2], 'little')
        ok, nm = good_name(data[b+flaglen+2:b+flaglen+2+namelen], namelen)
        if ok: clean += 1
        if tid == k or tid == 0: idmatch += 1
    return clean, idmatch
