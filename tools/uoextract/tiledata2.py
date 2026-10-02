"""
tiledata.mul - layout as MEASURED (constants derived from the data below).

LAND block: file offset 4, 512 groups of [u32 hdr] + 32 x 30 bytes
            record = [u64 flags][u16 texId][20 name]
ITEM block: group size 1320 bytes = [8-byte group header] + 32 x 41 bytes
            record = [u64 flags][u8 weight][u8 layer][i32 count][u16 animID]
                     [u16 hue][u16 light][u8 height][20 name]
            record data begins at group_start + 7

Evidence for the ITEM geometry (all measured, printed by this script):
  * consecutive 'delta-45' name anchors (the extra 4 bytes of a group header
    between two adjacent names) are exactly 1316 bytes apart, 831 times:
        4 + 32*41 = 1316
  * sliding the block start over the data gives 128/128 clean names for
    start = 493818.
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

LAND_OFF, LAND_GROUPS, LAND_PER, LAND_SZ = 4, 512, 32, 30
GSZ = 1320
REC0 = 7
ITEM_OFF = 493818
ITEM_GROUPS = (N - ITEM_OFF) // GSZ

LAYER = {0: "-", 1: "OneHanded", 2: "TwoHanded", 3: "Shoes", 4: "Pants", 5: "Shirt",
         6: "Helm", 7: "Gloves", 8: "Ring", 10: "Necklace", 11: "Hair", 12: "Waist",
         13: "InnerTorso", 14: "Bracelet", 16: "FacialHair", 17: "MiddleTorso",
         18: "Earrings", 19: "Arms", 20: "Cloak", 21: "Backpack", 22: "OuterTorso",
         23: "OuterLegs", 24: "InnerLegs"}


def clean(raw):
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else len(raw)]
    if len(s) == 0: return ''
    return s.decode('ascii') if all(0x20 <= c < 0x7f for c in s) else None


print("size =", N, " ITEM_OFF =", ITEM_OFF, " ITEM_GROUPS =", ITEM_GROUPS,
      " covers", ITEM_GROUPS*GSZ, "bytes")

items = []
for g in range(ITEM_GROUPS):
    base = ITEM_OFF + g*GSZ + REC0
    for k in range(32):
        b = base + k*41
        if b + 41 > N: break
        items.append(dict(tid=g*32+k, off=b,
                          flags=int.from_bytes(data[b:b+8], 'little'),
                          weight=data[b+8], layer=data[b+9],
                          count=int.from_bytes(data[b+10:b+14], 'little', signed=True),
                          animID=int.from_bytes(data[b+14:b+16], 'little'),
                          hue=int.from_bytes(data[b+16:b+18], 'little'),
                          light=int.from_bytes(data[b+18:b+20], 'little'),
                          height=data[b+20],
                          name=clean(data[b+21:b+41])))
print("items parsed:", len(items))
cl = sum(1 for r in items if r['name'])
print("clean names : %d (%.1f%%)" % (cl, 100.0*cl/len(items)))

print("\n--- first 10 items ---")
for r in items[:10]:
    print("  id=%-5d off=%-7d flags=0x%016x w=%-3d L=%-11s cnt=%-6d anim=%-6d %r"
          % (r['tid'], r['off'], r['flags'], r['weight'], LAYER.get(r['layer'], r['layer']),
             r['count'], r['animID'], r['name']))

print("\n--- requested known names ---")
WANT = ('anvil', 'forge', 'dagger', 'katana', 'bandage', 'backpack', 'black pearl',
        'nightshade', 'gold', 'leather gloves', 'leather cap', 'leather helm',
        'longsword', 'plate chest', 'wooden beam', 'stone stairs')
for w in WANT:
    hit = [r for r in items if r['name'] == w]
    if not hit:
        print("  %-16s NOT FOUND" % w)
    for r in hit[:3]:
        print("  %-16s id=%-6d w=%-3d layer=%-2d %-11s count=%-6d anim=%-6d flags=0x%016x"
              % (w, r['tid'], r['weight'], r['layer'], LAYER.get(r['layer'], '?'),
                 r['count'], r['animID'], r['flags']))
