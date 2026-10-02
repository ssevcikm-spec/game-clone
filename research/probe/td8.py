import os, sys, struct, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
LAND_END = 4 + 0x4000 * 34
print("file", n, "land block [0,%d)" % LAND_END)

# candidate item starts: right at land end, and with an optional group header
for itemStart in (LAND_END, LAND_END + 4, LAND_END - 4, 557084):
    print(f"\n--- itemStart={itemStart} ---")
    sane = 0
    for k in range(0x4000):
        o = itemStart + k * 41
        if o + 41 > n:
            break
        nm = d[o + 21:o + 41].split(b"\x00")[0]
        if not nm or all(0x20 <= c < 0x7f for c in nm):
            sane += 1
    print("   sane names:", sane, "of", 0x4000)
    for k in (0, 1, 2, 0x0f, 0x10, 0x0e83, 0x2710, 0x3fff):
        o = itemStart + k * 41
        if o + 41 > n:
            continue
        fl = struct.unpack_from("<I", d, o)[0]
        wt, layer = d[o + 4], d[o + 5]
        cnt = struct.unpack_from("<i", d, o + 6)[0]
        anim, hue, light = struct.unpack_from("<HHH", d, o + 10)
        hgt = d[o + 16]
        u17 = d[o + 17:o + 21]
        nm = d[o + 21:o + 41]
        print(f"   item[0x{k:04X}] @{o} flags=0x{fl:08X} wt={wt:3} layer={layer:3} count={cnt:8} "
              f"anim=0x{anim:04X} hue={hue:5} light={light:5} h={hgt:3} u17={u17.hex(' ')} name={nm!r}")

# verify against known offsets of 'spike trap'
sp = 672897
for nameoff in (21,):
    for k in range(0x4000):
        pass
print("\nspike trap @672897 -> (672897 - 21 - LAND_END)/41 =", (sp - 21 - LAND_END) / 41)
print("  -> item index if itemStart=LAND_END:", (sp - 21 - LAND_END) // 41, " mod:", (sp - 21 - LAND_END) % 41)
for cand in range(LAND_END - 600, LAND_END + 600):
    if (sp - 21 - cand) % 41 == 0 and (sp - 21 - cand) // 41 < 0x4000:
        print("   itemStart candidate:", cand, "index", (sp - 21 - cand) // 41)
