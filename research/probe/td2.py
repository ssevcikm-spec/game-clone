import os, struct, sys
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
print("size", n, " 0x4000*41*2 =", 0x4000 * 41 * 2)

LANDN = 0x4000
ITEMOFF = LANDN * 41
print("land block [0,%d)  item block [%d,%d)" % (ITEMOFF, ITEMOFF, ITEMOFF + LANDN * 41))
print("item block ends exactly at EOF:", ITEMOFF + LANDN * 41 == n)

print("\n--- LAND sample (41-byte records) ---")
for i in (0, 1, 2, 3, 0x3fff):
    o = i * 41
    fl = struct.unpack_from("<I", d, o)[0]
    tid = struct.unpack_from("<H", d, o + 4)[0]
    name = d[o + 6:o + 26]
    print(f"  land[{i:5}] @{o:8} flags=0x{fl:08X} texid={tid:5} name={name!r}")

print("\n--- ITEM sample (41-byte records) ---")
for i in (0, 1, 0x0f, 0x10, 0x2710, 0x3fff):
    o = ITEMOFF + i * 41
    fl = struct.unpack_from("<I", d, o)[0]
    wt = d[o + 4]
    layer = d[o + 5]
    count = struct.unpack_from("<i", d, o + 6)[0]
    anim = struct.unpack_from("<H", d, o + 10)[0]
    hue = struct.unpack_from("<H", d, o + 12)[0]
    light = struct.unpack_from("<H", d, o + 14)[0]
    height = d[o + 16]
    name = d[o + 17:o + 37]
    print(f"  item[0x{i:04X}] @{o:8} flags=0x{fl:08X} wt={wt:3} layer={layer:2} count={count:6} "
          f"anim=0x{anim:04X} hue={hue:5} light={light:5} h={height:3} name={name!r}")
print("  record bytes = 4+1+1+4+2+2+2+1+20 =", 4+1+1+4+2+2+2+1+20)
print("  land record  = 4+2+20 =", 4+2+20, "(+15 pad =", 41, ")")

print("\n--- ITEM: sanity histogram over all 0x4000 ---")
import collections
wts = collections.Counter()
lyr = collections.Counter()
hs = collections.Counter()
noname = 0
for i in range(0x4000):
    o = ITEMOFF + i * 41
    wts[d[o + 4]] += 1
    lyr[d[o + 5]] += 1
    hs[d[o + 16]] += 1
    if d[o + 17] == 0:
        noname += 1
print("  weight[0..12]:", [wts.get(k, 0) for k in range(13)])
print("  layer values seen (first 25):", sorted(lyr)[:25])
print("  layer histogram (top 12):", lyr.most_common(12))
print("  height range:", min(hs), "..", max(hs), " zero-height count:", hs.get(0, 0))
print("  entries with empty name:", noname)

print("\n--- LAND: sanity ---")
fl = collections.Counter()
for i in range(0x4000):
    o = i * 41
    fl[struct.unpack_from("<I", d, o)[0]] += 1
print("  distinct flag values:", len(fl), " top5:", fl.most_common(5))

print("\n" + "=" * 90)
print("--- Cliloc.enu ---")
c = open(os.path.join(UODIR, "Cliloc.enu"), "rb").read()
print("size", len(c), "first 32:", c[:32].hex(" "))
# header is 6 bytes in modern clients; try record= u32 num, u16 flag, u32 len
for hdr in (0, 4, 6):
    off = hdr
    ok = 0
    samples = []
    try:
        while off + 10 <= len(c) and ok < 4:
            num, flag, ln = struct.unpack_from("<IHI", c, off)
            if ln > 100000 or off + 10 + ln * 2 > len(c):
                break
            txt = c[off + 10:off + 10 + ln * 2].decode("utf-16-le", "replace")
            samples.append((off, num, flag, ln, txt[:70]))
            off += 10 + ln * 2
            ok += 1
    except Exception as e:
        samples.append(("err", e))
    print(f"\n header={hdr}: records parsed ok={ok}")
    for s in samples:
        print("   ", s)
