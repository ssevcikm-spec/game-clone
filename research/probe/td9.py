import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
IB = 557056
print("item block start", IB, " file", n)

print("\n--- hex of item 0x0E83 area ---")
o = IB + 0x0E83 * 41
print(f"  item[0x0E83] @{o}")
print("  bytes:", d[o:o + 41].hex(" "))

print("\n--- search all 'spike trap' occurrences and their item index ---")
i = 0
while True:
    i = d.find(b"spike trap", i)
    if i < 0:
        break
    k = (i - IB) // 41
    off_in_rec = (i - IB) % 41
    print(f"  @{i}  idx={k} (0x{k:04X})  offsetWithinRecord={off_in_rec}")
    i += 1

print("\n--- item record field probe (name at +21) ---")
for k in (0x0E83, 0x0E84, 0x0000, 0x0001, 0x0002, 0x0F, 0x10, 0x2710, 0x3FFF):
    o = IB + k * 41
    fl = struct.unpack_from("<I", d, o)[0]
    wt, layer = d[o + 4], d[o + 5]
    cnt = struct.unpack_from("<i", d, o + 6)[0]
    anim, hue, light = struct.unpack_from("<HHH", d, o + 10)
    hgt = d[o + 16]
    print(f"  [0x{k:04X}] @{o} flags=0x{fl:08X} wt={wt:4} layer={layer:3} count={cnt:9} "
          f"anim=0x{anim:04X} hue={hue:6} light={light:6} h={hgt:3} name={d[o+21:o+41]!r}")

print("\n--- land record field probe (37/34 byte) ---")
for k in (0, 1, 2, 3, 4, 0x3FFF):
    for R in (34,):
        o = k * R
        fl = struct.unpack_from("<I", d, o)[0]
        tid = struct.unpack_from("<H", d, o + 4)[0]
        print(f"  land[{k:6}] @{o} flags=0x{fl:08X} texid={tid:6} name={d[o+6:o+26]!r}")

print("\n--- which land stride makes name offsets clean? ---")
for R in (30, 34, 26, 37, 41):
    ok = 0
    for k in range(0x4000):
        o = k * R + 6
        if o + 20 > n:
            break
        nm = d[o:o + 20].split(b"\x00")[0]
        if not nm or all(0x20 <= c < 0x7f for c in nm):
            ok += 1
    print(f"  land R={R}: sane {ok}/16384 ; item block would start at {0x4000*R} "
          f"({'== 557056' if 0x4000*R == 557056 else ''})")
