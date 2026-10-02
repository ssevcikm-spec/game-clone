import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()

IB = 557056
# Find the first record whose name field (any plausible offset) equals 'katana'
i = d.find(b"katana\x00")
print("katana\\0 @", i)
# scan candidate record starts so that name starts at rec+NAMEOFF and rec = IB + k*41
for no in range(0, 30):
    rec = i - no
    if (rec - IB) % 41 == 0:
        print(f"  nameOff={no} -> recStart={rec} itemIndex={(rec-IB)//41} (0x{(rec-IB)//41:04X})")

print("\n=== annotated records around katana ===")
for rec in (704007, 704048, 704089, 704130):
    r = d[rec:rec + 41]
    fl = struct.unpack_from("<I", r, 0)[0]
    wt, layer = r[4], r[5]
    cnt = struct.unpack_from("<i", r, 6)[0]
    anim, hue, light = struct.unpack_from("<HHH", r, 10)
    hgt = r[16]
    name = r[17:37].split(b"\x00")[0].decode("ascii", "replace")
    idx = (rec - IB) // 41
    print(f"  idx 0x{idx:04X} @{rec}: flags=0x{fl:08X} wt={wt:3} layer={layer:3} count={cnt:7} "
          f"anim=0x{anim:04X} hue={hue:5} light={light:5} h={hgt:3} name={name!r}")
    print(f"     raw: {r.hex(' ')}")

print("\n=== annotated records around pickaxe ===")
for rec in (646435, 646476, 646517):
    r = d[rec:rec + 41]
    fl = struct.unpack_from("<I", r, 0)[0]
    wt, layer = r[4], r[5]
    cnt = struct.unpack_from("<i", r, 6)[0]
    anim, hue, light = struct.unpack_from("<HHH", r, 10)
    hgt = r[16]
    name = r[17:37].split(b"\x00")[0].decode("ascii", "replace")
    idx = (rec - IB) // 41
    print(f"  idx 0x{idx:04X} @{rec}: flags=0x{fl:08X} wt={wt:3} layer={layer:3} count={cnt:7} "
          f"anim=0x{anim:04X} hue={hue:5} light={light:5} h={hgt:3} name={name!r}")
