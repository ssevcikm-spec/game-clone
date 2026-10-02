"""
Brute-force the exact FIELD ORDER of the new-style item record.

Proven by direct byte reading of the 'stone stairs' cluster (all records are
exactly 41 bytes apart and the name field is 20 bytes):
    [flags u64][weight u8][layer u8][count i32][animID u16][hue u16][light u16][height u8][name 20]
     0..7        8           9          10..13      14..15      16..17    18..19       20      21..40
For 'stone stairs' that yields flags=0x40 (Surface), count=38, animID=0.

Now confirm with an INDEPENDENT ground truth that does not depend on the layout:
  * 'gargoyle_leather_arm' is a wearable -> TileFlag.Wearable (0x00400000, i.e. high word == 0x0040)
    and its Layer must be 7 (Gloves) per the RunUO/ServUO Layer enum.
  * 'gargoyle_leather_che' (chest) must be Layer 13 (InnerTorso).
  * 'gargoyle_leather_leg' must be Layer 24 (InnerLegs).
If the layer byte lands on Layer values matching the names, the layout is proven.
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
STRIDE, NAMEOFF = 41, 21

LAYER = {1: "OneHanded", 2: "TwoHanded", 3: "Shoes", 4: "Pants", 5: "Shirt", 6: "Helm",
         7: "Gloves", 8: "Ring", 10: "Necklace", 11: "Hair", 12: "Waist", 13: "InnerTorso",
         14: "Bracelet", 16: "FacialHair", 17: "MiddleTorso", 18: "Earrings", 19: "Arms",
         20: "Cloak", 21: "Backpack", 22: "OuterTorso", 23: "OuterLegs", 24: "InnerLegs"}


def name_at(off):
    raw = data[off:off+20]
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else 20]
    return s.decode('ascii', 'replace') if s and all(0x20 <= c < 0x7f for c in s) else None


print("=== every record whose name contains 'leather' in the whole file ===")
i = 0
hits = []
while i < N:
    j = data.find(b'leather', i)
    if j < 0: break
    # find record start candidates: the name may start earlier; use the printable run
    a = j
    while a > 0 and 0x20 <= data[a-1] < 0x7f: a -= 1
    b = j
    while b < N and 0x20 <= data[b] < 0x7f: b += 1
    nm = data[a:b].decode('ascii', 'replace')
    hits.append((a, nm))
    i = b
for a, nm in hits:
    print("   off=%8d name=%r" % (a, nm))

print("\n=== decode the records that hold those names (S = name_off - 21) ===")
print("%-26s %-9s %-6s %-5s %-7s %-6s %-5s %-6s %s" %
      ("name", "flags", "weight", "layer", "count", "animID", "hue", "light", "height"))
seen = set()
for a, nm in hits:
    S = a - NAMEOFF
    if S < 0 or S+41 > N: continue
    if (nm, S) in seen: continue
    seen.add((nm, S))
    flags = int.from_bytes(data[S:S+8], 'little')
    w = data[S+8]; lay = data[S+9]
    cnt = int.from_bytes(data[S+10:S+14], 'little', signed=True)
    anim = int.from_bytes(data[S+14:S+16], 'little')
    hue = int.from_bytes(data[S+16:S+18], 'little')
    light = int.from_bytes(data[S+18:S+20], 'little')
    h = data[S+20]
    layer_name = LAYER.get(lay, '?' + str(lay))
    print("%-26s 0x%08x %-6d %-5s %-7d %-6d %-5d %-6d %d" %
          (nm[:26], flags, w, layer_name, cnt, anim, hue, light, h))

print("\n=== LAYER HISTOGRAM over records whose name is a clean printable run ===")
hist = collections.Counter()
tot = 0
S = 428036 + 4   # block B start (measured), skipping group header
while S + 41 <= N:
    nm = name_at(S+NAMEOFF)
    if nm:
        hist[data[S+9]] += 1
        tot += 1
    S += STRIDE
print("records scanned:", tot)
for lay, c in hist.most_common(28):
    print("   layer %3d (%-12s) %6d" % (lay, LAYER.get(lay, '?'), c))
