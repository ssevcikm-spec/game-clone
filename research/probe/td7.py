import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)

print("=== land: stride-34 from offset 10, name at rec+6 ===")
for k in (0, 1, 2, 3, 4, 0x3fff, 0x4000, 0x4001):
    rec = 4 + k * 34
    nm = d[rec + 6:rec + 26].split(b"\x00")[0]
    print(f"  land[{k:6}] rec@{rec:8} flags={struct.unpack_from('<I', d, rec)[0]:#010x} "
          f"id={struct.unpack_from('<H', d, rec+4)[0]:6} name={nm!r}")

print("\n=== what is at 557062..673000? ===")
seg = d[557062:557062 + 64]
print("  @557062:", seg.hex(" "))
print("  @557062 ascii:", "".join(chr(c) if 32 <= c < 127 else "." for c in seg))
for probe in (557062, 558000, 560000, 570000, 580000, 600000, 620000, 640000, 660000, 670000, 672800):
    s = d[probe:probe + 48]
    txt = "".join(chr(c) if 32 <= c < 127 else "." for c in s)
    print(f"  @{probe:8}: {s[:24].hex(' ')}  |{txt[:24]}|")

print("\n=== search for the item block: names must be valid on a 41 stride ===")
# Use the ClassicUO item layout: flags(4) wt(1) layer(1) count(4) anim(2) hue(2) light(2) h(1) name(20)
# name is at rec+17, record 41 bytes. Find itemStart such that K records have sane flags/names.
cands = []
for itemStart in range(540000, 900000):
    good = 0
    for k in range(0, 4000, 37):
        o = itemStart + k * 41
        nm = d[o + 17:o + 37].split(b"\x00")[0]
        if not nm or all(0x20 <= c < 0x7f for c in nm):
            good += 1
    cands.append((good, itemStart))
cands.sort(reverse=True)
print("  top 10 (good, itemStart):", cands[:10])
best = cands[0][1]
print(f"\n=== using itemStart={best} ===")
for k in (0, 1, 2, 0x0f, 0x10, 0x2710, 0x3fff):
    o = best + k * 41
    fl = struct.unpack_from("<I", d, o)[0]
    wt, layer = d[o + 4], d[o + 5]
    cnt = struct.unpack_from("<i", d, o + 6)[0]
    anim, hue, light = struct.unpack_from("<HHH", d, o + 10)
    hgt = d[o + 16]
    nm = d[o + 17:o + 37]
    print(f"  item[0x{k:04X}] @{o} flags=0x{fl:08X} wt={wt:3} layer={layer:3} count={cnt:8} "
          f"anim=0x{anim:04X} hue={hue:5} light={light:5} h={hgt:3} name={nm!r}")
print("  item block would need", 0x4000 * 41, "bytes; from", best, "to", best + 0x4000 * 41,
      " file ends", n)
