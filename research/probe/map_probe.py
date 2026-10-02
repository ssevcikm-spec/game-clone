import os, sys, struct, zlib
sys.path.insert(0, r"E:\Workspaces\game-clone\research\probe")
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from uop_final import Uop, hashlittle2

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"

u = Uop(os.path.join(UODIR, "map0LegacyMUL.uop"))
print("map0LegacyMUL.uop: version", u.version, "nextBlock", u.nextblock, "count", u.count,
      "blocks", len(u.blocks), "entries", len(u.entries))

# pattern: build/map0legacymul/{:08d}.dat
for idx in (0, 1, 4095):
    name = f"build/map0legacymul/{idx:08d}.dat"
    e = u.get(name)
    if e is None:
        print(f"  entry {idx}: NOT FOUND")
        continue
    print(f"  entry {idx}: off={e['off']} hlen={e['hlen']} clen={e['clen']} dlen={e['dlen']} flag={e['flag']}")
    data = u.read(e)
    print(f"    inflated {len(data)} bytes  (0xC4000 = {0xC4000})  match={len(data) == 0xC4000}")
    print(f"    first 24: {data[:24].hex(' ')}")
    # decode block 0
    hdr = struct.unpack_from("<I", data, 0)[0]
    print(f"    block0 header u32 = {hdr} (0x{hdr:08X})")
    cells = []
    for cy in range(8):
        row = []
        for cx in range(8):
            o = 4 + (cy * 8 + cx) * 3
            tid, z = struct.unpack_from("<Hb", data, o)
            row.append((tid, z))
        cells.append(row)
    print("    block0 8x8 (tileId,z):")
    for cy in range(8):
        print("      " + " ".join(f"{t:5}/{z:4}" for t, z in cells[cy]))

print("\n=== histogram of block headers over chunk 0 ===")
import collections
e = u.get("build/map0legacymul/00000000.dat")
data = u.read(e)
hs = collections.Counter(struct.unpack_from("<I", data, b * 196)[0] for b in range(4096))
print("  distinct block headers:", len(hs), " top5:", hs.most_common(5))

print("\n=== are all tileIds valid land ids (< 0x4000)? ===")
bad = 0
mx = 0
for b in range(4096):
    base = b * 196
    for c in range(64):
        tid = struct.unpack_from("<H", data, base + 4 + c * 3)[0]
        mx = max(mx, tid)
        if tid >= 0x4000:
            bad += 1
print(f"  max tileId = 0x{mx:04X} ({mx});  ids >= 0x4000: {bad} of {4096*64}")
