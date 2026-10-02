import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
IB = 557056
LANDB = 34
print("LAND block records, absolute offsets and hex:")
for k in (0, 1, 2, 3, 4):
    o = k * LANDB
    print(f"  land[{k}] @{o:6}: {d[o:o+LANDB].hex(' ')}   name@+6 = {d[o+6:o+26]!r}")
print("\n  contiguous 140 bytes from 0:")
print("   ", d[0:140].hex(" "))

print("\nITEM records (stride 41, name at +26):")
for k in (0x0E00, 0x0E01, 0x0E02, 0x0E03, 0x0F, 0x10, 0x2710):
    o = IB + k * 41
    r = d[o:o + 41]
    print(f"  item[0x{k:04X}] @{o}")
    for j in range(0, 41, 8):
        print(f"     +{j:2}: {r[j:j+8].hex(' ')}")
    # annotate the classic layout
    fl = struct.unpack_from("<I", r, 0)[0]
    wt, layer = r[4], r[5]
    cnt = struct.unpack_from("<i", r, 6)[0]
    anim, hue, light = struct.unpack_from("<HHH", r, 10)
    hgt = r[16]
    print(f"     flags=0x{fl:08X} wt={wt} layer={layer} count={cnt} anim=0x{anim:04X} "
          f"hue={hue} light={light} h={hgt} name={r[26:46]!r}")

print("\nName field search: for the katana record, where exactly is 'katana'?")
kat = d.find(b"katana\x00")
print("  'katana\\0' @", kat)
for k in range(0x4000):
    o = IB + k * 41
    if o <= kat < o + 41:
        print(f"  inside item[{k}] (0x{k:04X}) at record offset {kat-o}: {d[o:o+41].hex(' ')}")
        break
