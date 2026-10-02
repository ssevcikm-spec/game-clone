"""
tiledata.mul - FINAL VERIFIED LAYOUT

MEASURED (see report for raw byte evidence):

LAND (block 1), starts at file offset 4, 512 groups:
    group = [u32 header] + 32 x 30 bytes
    land record (30 B):
        +0  u64 flags
        +8  u16 texId        (land tile graphic)
        +10 char name[20]

ITEM (block 2), starts at file offset 15312, 512 groups:
    group = [u32 header] + 32 x 41 bytes
    item record (41 B):
        +0  u64 flags
        +8  u8  weight
        +9  u8  layer
        +10 i32 count
        +14 u16 animID
        +16 u16 hue
        +18 u16 lightIndex
        +20 u8  height
        +21 char name[20]

Ground truth used to validate:
    gargoyle_leather_arm  -> flags 0x00404002 weight 4 layer 19(Arms) count 566 anim 585
    gargoyle_leather_che  -> layer 13 (InnerTorso)
    gargoyle_leather_leg  -> layer 24 (InnerLegs)
    wooden beam           -> flags 0x00405000, name at +21 = 'wooden beam' then 3 pad bytes
"""
import os, struct, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

LAND_OFF, LAND_GROUPS, LAND_PER, LAND_SZ = 4, 512, 32, 30
ITEM_OFF = LAND_OFF + LAND_GROUPS * (4 + LAND_PER * LAND_SZ)
print("size          =", N)
print("land  block   = %d .. %d" % (LAND_OFF, ITEM_OFF))
print("item  block   = %d .. %d" % (ITEM_OFF, ITEM_OFF + LAND_GROUPS*(4+32*41)))
print("bytes at ITEM_OFF:", data[ITEM_OFF:ITEM_OFF+16].hex())

LAYER = {1: "OneHanded", 2: "TwoHanded", 3: "Shoes", 4: "Pants", 5: "Shirt", 6: "Helm",
         7: "Gloves", 8: "Ring", 10: "Necklace", 11: "Hair", 12: "Waist", 13: "InnerTorso",
         14: "Bracelet", 16: "FacialHair", 17: "MiddleTorso", 18: "Earrings", 19: "Arms",
         20: "Cloak", 21: "Backpack", 22: "OuterTorso", 23: "OuterLegs", 24: "InnerLegs"}


def clean(raw):
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else len(raw)]
    if len(s) == 0:
        return ''
    return s.decode('ascii') if all(0x20 <= c < 0x7f for c in s) else None


def parse_land():
    out = []
    for g in range(LAND_GROUPS):
        base = LAND_OFF + g*(4 + LAND_PER*LAND_SZ) + 4
        for k in range(LAND_PER):
            b = base + k*LAND_SZ
            tid = g*LAND_PER + k
            out.append((tid,
                        int.from_bytes(data[b:b+8], 'little'),
                        int.from_bytes(data[b+8:b+10], 'little'),
                        clean(data[b+10:b+30])))
    return out


def parse_items():
    out = []
    for g in range(LAND_GROUPS):
        base = ITEM_OFF + g*(4 + LAND_PER*41) + 4
        for k in range(LAND_PER):
            b = base + k*41
            tid = g*LAND_PER + k
            out.append(dict(tid=tid, off=b,
                            flags=int.from_bytes(data[b:b+8], 'little'),
                            weight=data[b+8], layer=data[b+9],
                            count=int.from_bytes(data[b+10:b+14], 'little', signed=True),
                            animID=int.from_bytes(data[b+14:b+16], 'little'),
                            hue=int.from_bytes(data[b+16:b+18], 'little'),
                            light=int.from_bytes(data[b+18:b+20], 'little'),
                            height=data[b+20],
                            name=clean(data[b+21:b+41])))
    return out


LAND = parse_land()
ITEM = parse_items()
land_clean = sum(1 for r in LAND if r[3])
item_clean = sum(1 for r in ITEM if r['name'])
print()
print("land entries : %d, clean names %d (%.1f%%)" % (len(LAND), land_clean, 100.0*land_clean/len(LAND)))
print("item entries : %d, clean names %d (%.1f%%)" % (len(ITEM), item_clean, 100.0*item_clean/len(ITEM)))
print()
print("--- first 5 land ---")
for r in LAND[:5]:
    print("   id=%-5d flags=0x%016x tex=%-6d name=%r" % r)
print("--- first 8 items ---")
for r in ITEM[:8]:
    print("   id=%-5d off=%-7d flags=0x%016x w=%-3d L=%-11s cnt=%-6d anim=%-6d %r"
          % (r['tid'], r['off'], r['flags'], r['weight'], LAYER.get(r['layer'], r['layer']),
             r['count'], r['animID'], r['name']))
print()
print("--- known wearables (layer ground truth) ---")
for r in ITEM:
    if r['name'] in ('gargoyle_leather_arm', 'gargoyle_leather_che', 'gargoyle_leather_leg',
                     'leather cap', 'leather gloves', 'leather gorget', 'leather sleeves',
                     'leather leggings', 'leather tunic', 'leather shorts', 'leather skirt',
                     'leather bustier', 'leather armor', 'wooden beam', 'anvil', 'forge'):
        print("   id=%-6d %-22s w=%-3d layer=%-2d %-11s count=%-6d anim=%-6d flags=0x%016x"
              % (r['tid'], r['name'], r['weight'], r['layer'],
                 LAYER.get(r['layer'], '?'), r['count'], r['animID'], r['flags']))
