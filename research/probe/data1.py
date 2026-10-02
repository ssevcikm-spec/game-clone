import os, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
FILES = ["tiledata.mul", "hues.mul", "radarcol.mul", "light.mul", "lightidx.mul",
         "texmaps.mul", "texidx.mul", "multi.mul", "multi.idx", "animdata.mul", "animinfo.mul",
         "skills.mul", "skills.idx", "skillgrp.mul", "speech.mul", "Sound.def", "palette.mul",
         "staidx0.mul", "staidx0x.mul", "statics0.mul", "Cliloc.enu", "fonts.mul", "unifont0.mul"]
print(f"{'file':<18}{'size':>12}   divisibility notes")
for fn in FILES:
    p = os.path.join(UODIR, fn)
    if not os.path.exists(p):
        print(f"{fn:<18}{'MISSING':>12}")
        continue
    s = os.path.getsize(p)
    notes = []
    for div, label in ((12, "staidx blk"), (7, "static"), (196, "map blk"), (37, "tiledata old"),
                       (41, "tiledata hs"), (2, "u16"), (4, "u32"), (8, "u64"), (16, "uop slot")):
        if s % div == 0:
            notes.append(f"{label}:{s//div}")
    print(f"{fn:<18}{s:>12}   {' '.join(notes[:6])}")
    # first 32 bytes
    with open(p, "rb") as f:
        d = f.read(32)
    print(f"    first32 = {d.hex(' ')}")

# tiledata record-size detection
p = os.path.join(UODIR, "tiledata.mul")
s = os.path.getsize(p)
print("\n=== tiledata.mul structure probe ===")
for rec, name in ((37, "old (pre-HS)"), (41, "HS/7.0.9+"), (42, "?"), (36, "?")):
    land_bytes = 0x4000 * rec
    item_bytes = 0x4000 * rec
    print(f"  {name}: rec={rec} -> land block {land_bytes} B + item block {item_bytes} B = {land_bytes+item_bytes}"
          f"  {'== file size' if land_bytes+item_bytes == s else '!= %d' % s}")
with open(p, "rb") as f:
    d = f.read(64)
print("  first 48 bytes:", d[:48].hex(" "))
print("  u32 @0 (land header):", struct.unpack_from("<I", d, 0)[0])
# find the item block: search for plausible start
for rec in (37, 41):
    off = 0x4000 * rec
    with open(p, "rb") as f:
        f.seek(off)
        dd = f.read(48)
    print(f"  @{off} (item block if rec={rec}): u32={struct.unpack_from('<I', dd, 0)[0]}  bytes={dd[:40].hex(' ')}")
