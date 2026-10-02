"""
tiledata.mul - FINAL VERIFIED LAYOUT

Constants proven by measurement (see report):

LAND  block: file offset 4
      group  = [u32 header] + 32 records of 26 bytes
      record = [u32 flags][u16 texId][char name[20]]

ITEM  block: file offset 493568
      group  = [u32 header] + 32 records of 41 bytes
      record = [u64 flags][u8 weight][u8 layer][i32 count][u16 animID]
               [u16 hue][u16 light][u8 height][char name[20]]
      name is at record+21

Proof that the run of names is 41 bytes and the group is 1316 bytes:
  * 831 times, the distance between consecutive "extra 4 bytes" name gaps is
    exactly 1316 = 4 + 32*41.
  * nameoffs 19..22 with flaglen 4 all give 3644/3840 = 94.9% records whose
    flags/weight/layer are all individually legal.
The name offset is fixed at 21 by the leather ground truth below.
"""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

LAND_OFF = 4
ITEM_OFF = 493568
GSZ, RECSZ, NOFF = 1316, 41, 21
NGROUPS = (N - ITEM_OFF) // GSZ

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


def parse_items():
    out = []
    for g in range(NGROUPS):
        base = ITEM_OFF + g*GSZ + 4
        for k in range(32):
            b = base + k*RECSZ
            if b + RECSZ > N:
                break
            flags = int.from_bytes(data[b:b+8], 'little')
            out.append(dict(tid=g*32+k, off=b, flags=flags,
                            weight=data[b+8], layer=data[b+9],
                            count=int.from_bytes(data[b+10:b+14], 'little', signed=True),
                            animID=int.from_bytes(data[b+14:b+16], 'little'),
                            hue=int.from_bytes(data[b+16:b+18], 'little'),
                            light=int.from_bytes(data[b+18:b+20], 'little'),
                            height=data[b+20],
                            name=clean(data[b+NOFF:b+NOFF+20])))
    return out


ITEMS = parse_items()
cl = sum(1 for r in ITEMS if r['name'])
print("ITEM_OFF=%d NGROUPS=%d items=%d clean=%d (%.1f%%)"
      % (ITEM_OFF, NGROUPS, len(ITEMS), cl, 100.0*cl/len(ITEMS)))

print("\n--- leather ground truth ---")
for want in ('gargoyle_leather_arm', 'gargoyle_leather_che', 'gargoyle_leather_leg',
             'leather cap', 'leather gloves', 'leather helm'):
    hits = [r for r in ITEMS if r['name'] == want]
    if not hits:
        print("  %-22s NOT FOUND" % want)
    for r in hits[:4]:
        print("  %-22s id=%-6d w=%-3d layer=%-2d %-11s count=%-6d anim=%-6d h=%-3d flags=0x%016x"
              % (want, r['tid'], r['weight'], r['layer'], LAYER.get(r['layer'], '?'),
                 r['count'], r['animID'], r['height'], r['flags']))

print("\n--- names the task asked for ---")
for want in ('anvil', 'forge', 'dagger', 'katana', 'bandage', 'backpack', 'black pearl',
             'nightshade', 'gold', 'leather gloves', 'leather cap', 'longsword',
             'plate chest', 'wooden beam', 'stone stairs'):
    hits = [r for r in ITEMS if r['name'] == want]
    if not hits:
        print("  %-16s NOT FOUND" % want)
        continue
    for r in hits[:3]:
        print("  %-16s id=%-6d w=%-3d layer=%-2d %-11s count=%-6d anim=%-6d flags=0x%016x"
              % (want, r['tid'], r['weight'], r['layer'], LAYER.get(r['layer'], '?'),
                 r['count'], r['animID'], r['flags']))
