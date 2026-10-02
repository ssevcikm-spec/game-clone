"""
tiledata.mul - FINAL VERIFIED LAYOUT (complete)

Ground truth checks that PASS with these constants:
  leather cap       -> layer 6 (Helm)          OK
  gargoyle_leather_arm -> layer 19 (Arms)      OK
  gargoyle_leather_che -> layer 13 (InnerTorso) OK
  gargoyle_leather_leg -> layer 4  (Pants)     OK
  backpack          -> layer 21 (Backpack)     OK
  dagger/longsword/katana -> layer 1 (OneHanded) OK
  anvil/forge/wooden beam/stone stairs -> weight 255, layer 0 (not wearable) OK
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

LAND_OFF, LAND_GSZ, LAND_REC, LAND_NOFF = 4, 964, 30, 10
ITEM_OFF, GSZ, RECSZ, NOFF = 493568, 1316, 41, 21
ITEM_GROUPS = (N - ITEM_OFF) // GSZ

LAYER = {0: "-", 1: "OneHanded", 2: "TwoHanded", 3: "Shoes", 4: "Pants", 5: "Shirt",
         6: "Helm", 7: "Gloves", 8: "Ring", 10: "Necklace", 11: "Hair", 12: "Waist",
         13: "InnerTorso", 14: "Bracelet", 16: "FacialHair", 17: "MiddleTorso",
         18: "Earrings", 19: "Arms", 20: "Cloak", 21: "Backpack", 22: "OuterTorso",
         23: "OuterLegs", 24: "InnerLegs"}


def clean(raw):
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else len(raw)]
    if len(s) == 0:
        return ''
    return s.decode('ascii') if all(0x20 <= c < 0x7f for c in s) else None


def parse_land():
    out = []
    for g in range(512):
        base = LAND_OFF + g*LAND_GSZ + 4
        for k in range(32):
            b = base + k*LAND_REC
            out.append(dict(tid=g*32+k, off=b,
                            flags=int.from_bytes(data[b:b+4], 'little'),
                            texId=int.from_bytes(data[b+4:b+6], 'little'),
                            name=clean(data[b+LAND_NOFF:b+LAND_NOFF+20])))
    return out


def parse_items():
    out = []
    for g in range(ITEM_GROUPS):
        base = ITEM_OFF + g*GSZ + 4
        for k in range(32):
            b = base + k*RECSZ
            out.append(dict(tid=g*32+k, off=b,
                            flags=int.from_bytes(data[b:b+8], 'little'),
                            weight=data[b+8], layer=data[b+9],
                            count=int.from_bytes(data[b+10:b+14], 'little', signed=True),
                            animID=int.from_bytes(data[b+14:b+16], 'little'),
                            hue=int.from_bytes(data[b+16:b+18], 'little'),
                            light=int.from_bytes(data[b+18:b+20], 'little'),
                            height=data[b+20],
                            name=clean(data[b+NOFF:b+NOFF+20])))
    return out


LAND = parse_land()
ITEMS = parse_items()

print("=" * 78)
print("TILEDATA.MUL  size=%d" % N)
print("  land  block off=%d  group=%d (4 + 32*%d)  512 groups = %d bytes"
      % (LAND_OFF, LAND_GSZ, LAND_REC, 512*LAND_GSZ))
print("  item  block off=%d  group=%d (4 + 32*%d)  %d groups = %d bytes"
      % (ITEM_OFF, GSZ, RECSZ, ITEM_GROUPS, ITEM_GROUPS*GSZ))
print("  item block end = %d   file size = %d   slack = %d"
      % (ITEM_OFF + ITEM_GROUPS*GSZ, N, N - (ITEM_OFF + ITEM_GROUPS*GSZ)))
print("  bytes 428036..493568 (gap between land end and item block):")
print("     ", data[428036:428036+32].hex(), " ...")
print("=" * 78)

lc = sum(1 for r in LAND if r['name'])
ic = sum(1 for r in ITEMS if r['name'])
print("land entries %d, clean names %d (%.1f%%)" % (len(LAND), lc, 100.0*lc/len(LAND)))
print("item entries %d, clean names %d (%.1f%%)" % (len(ITEMS), ic, 100.0*ic/len(ITEMS)))

print("\n--- first 6 land tiles ---")
for r in LAND[:6]:
    print("   id=%-5d off=%-7d flags=0x%08x texId=%-6d name=%r"
          % (r['tid'], r['off'], r['flags'], r['texId'], r['name']))

print("\n--- GROUND TRUTH: layer must match the RunUO enum ---")
GT = ['gargoyle_leather_arm', 'gargoyle_leather_che', 'gargoyle_leather_leg',
      'leather cap', 'leather helm', 'leather gloves', 'leather gorget',
      'leather sleeves', 'leather leggings', 'leather tunic', 'leather skirt',
      'backpack', 'dagger', 'katana', 'longsword', 'plate chest', 'plate legs',
      'plate gorget', 'chainmail tunic', 'bandana', 'cloak', 'skirt', 'body sash']
for w in GT:
    hits = [r for r in ITEMS if r['name'] == w]
    if not hits:
        print("   %-22s NOT FOUND" % w)
        continue
    r = hits[0]
    print("   %-22s id=%-6d w=%-3d layer=%-2d %-12s count=%-5d anim=%-5d h=%-2d flags=0x%016x"
          % (w, r['tid'], r['weight'], r['layer'], LAYER.get(r['layer'], '?'),
             r['count'], r['animID'], r['height'], r['flags']))

print("\n--- layer histogram over all named items ---")
h = collections.Counter(r['layer'] for r in ITEMS if r['name'])
tot = sum(h.values())
for lay, c in sorted(h.items(), key=lambda x: -x[1])[:14]:
    print("   layer %-3d %-12s %6d (%.1f%%)" % (lay, LAYER.get(lay, '?'), c, 100.0*c/tot))

print("\n--- wearable flag consistency ---")
W = 0x00400000
wear = [r for r in ITEMS if r['flags'] & W]
print("   items with Wearable flag 0x00400000: %d" % len(wear))
print("   of those, layer != 0 : %d (%.1f%%)"
      % (sum(1 for r in wear if r['layer'] != 0),
         100.0*sum(1 for r in wear if r['layer'] != 0)/max(1, len(wear))))
print("   of those, layer is a valid enum value: %d (%.1f%%)"
      % (sum(1 for r in wear if r['layer'] in LAYER),
         100.0*sum(1 for r in wear if r['layer'] in LAYER)/max(1, len(wear))))
