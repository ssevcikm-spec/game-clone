import os, sys, struct, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
LAND_END = 0x4000 * 34
IB = LAND_END
print(f"file={n}  land[0,{LAND_END})  items[{IB},{IB + 0x4000*41})  trailing={n - (IB + 0x4000*41)}")

def land(k):
    o = k * 34
    return (struct.unpack_from("<I", d, o)[0], struct.unpack_from("<H", d, o + 4)[0],
            d[o + 6:o + 26].split(b"\x00")[0].decode("ascii", "replace"))

def item(k):
    o = IB + k * 41
    r = d[o:o + 41]
    return dict(flags=struct.unpack_from("<I", r, 0)[0], weight=r[4], layer=r[5],
                count=struct.unpack_from("<i", r, 6)[0],
                anim=struct.unpack_from("<H", r, 10)[0],
                hue=struct.unpack_from("<H", r, 12)[0],
                light=struct.unpack_from("<H", r, 14)[0],
                height=r[16], name=r[26:46].split(b"\x00")[0].decode("ascii", "replace"))

print("\n--- land ---")
for k in (0, 1, 2, 3, 4, 5, 6, 0x3FFF):
    f, tid, nm = land(k)
    print(f"  land[{k:5}] flags=0x{f:08X} texid={tid:6} name={nm!r}")

print("\n--- items (spot checks) ---")
for k in (0x0E00, 0x0E01, 0x0E02, 0x0E03, 0x0884, 0x0885, 0x0F, 0x10, 0x2710, 0x3FFF):
    it = item(k)
    print(f"  item[0x{k:04X}] flags=0x{it['flags']:08X} wt={it['weight']:4} layer={it['layer']:3} "
          f"count={it['count']:9} anim=0x{it['anim']:04X} hue={it['hue']:5} light={it['light']:5} "
          f"h={it['height']:3} name={it['name']!r}")

print("\n--- item sanity over all 0x4000 ---")
w = collections.Counter(); ly = collections.Counter(); hh = collections.Counter(); noname = 0
for k in range(0x4000):
    it = item(k)
    w[it["weight"]] += 1; ly[it["layer"]] += 1; hh[it["height"]] += 1
    if not it["name"]:
        noname += 1
print("  weight 0..10:", [w.get(i, 0) for i in range(11)])
print("  distinct weights:", len(w), " max weight:", max(w))
print("  distinct layers:", len(ly))
print("  layer values:", sorted(ly)[:40])
print("  height 0..30:", [hh.get(i, 0) for i in range(31)], " max:", max(hh))
print("  empty names:", noname)

# How many items have a 'plausible' name (printable or empty)?
ok = 0
for k in range(0x4000):
    nm = item(k)["name"]
    if not nm or all(0x20 <= ord(c) < 0x7f for c in nm):
        ok += 1
print(f"  plausible names: {ok}/16384 = {100.0*ok/16384:.1f}%")

# land names
ok = 0
for k in range(0x4000):
    nm = land(k)[2]
    if not nm or all(0x20 <= ord(c) < 0x7f for c in nm):
        ok += 1
print(f"  land plausible names: {ok}/16384 = {100.0*ok/16384:.1f}%")

# ---- now the same for land/item flag words
print("\n--- land flags histogram (top 12) ---")
lf = collections.Counter(land(k)[0] for k in range(0x4000))
print("  ", [(hex(a), b) for a, b in lf.most_common(12)])
print("\n--- item flags: which bits are ever set? ---")
bits = collections.Counter()
for k in range(0x4000):
    f = item(k)["flags"]
    for b in range(32):
        if f >> b & 1:
            bits[b] += 1
print("  ", sorted(bits.items()))
