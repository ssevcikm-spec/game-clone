import os, sys, struct, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
LAND_END = 4 + 0x4000 * 34

# The file has (n - LAND_END)/41 = 64187.22 -- not integral, so 41 is wrong OR
# there is a trailing block. Check divisibility of the REMAINDER after land.
rem = n - LAND_END
print("remaining after land:", rem, " /41 =", rem / 41, " /34 =", rem / 34,
      " /30 =", rem / 30, " /37 =", rem / 37)

# Try: item record = 41, count = 0x4000, then a trailing region
print("\nAfter 0x4000 items at 41: offset", LAND_END + 0x4000 * 41, " trailing", n - (LAND_END + 0x4000 * 41))

# Genuinely determine item record size: find a long run of identical names at fixed stride
def find_stride(lo, hi, name=b"spike trap"):
    offs = []
    i = lo
    while i < hi:
        i = d.find(name, i)
        if i < 0:
            break
        offs.append(i)
        i += 1
    return offs

for name in (b"spike trap", b"tent roof", b"wooden stairs", b"catapult", b"telescope", b"hanging lantern"):
    offs = find_stride(LAND_END, n, name)
    if len(offs) < 2:
        print(f"  {name!r}: {len(offs)} occurrences")
        continue
    diffs = [offs[k+1]-offs[k] for k in range(len(offs)-1)]
    c = collections.Counter(diffs)
    print(f"  {name!r}: {len(offs)} occ, diffs top3={c.most_common(3)}, mod41={[o%41 for o in offs[:4]]}, mod34={[o%34 for o in offs[:4]]}")

print("\n=== hypothesis: item block starts at 557056 with stride 41, 0x4000 entries ===")
# check the name field: try every offset 10..25, require printable-then-NUL for >90%
for no in range(10, 26):
    ok = 0
    for k in range(0x4000):
        o = LAND_END + k * 41 + no
        f = d[o:o + 20]
        z = f.find(b"\x00")
        if z == 0:
            ok += 1
            continue
        if z > 0 and all(0x20 <= c < 0x7f for c in f[:z]) and all(c == 0 for c in f[z:]):
            ok += 1
    print(f"   nameOff={no}: {ok}/16384 = {100.0*ok/16384:.1f}%")

print("\n=== dump item[0] (41 bytes) with byte numbers ===")
o = LAND_END
r = d[o:o + 41]
for i in range(0, 41, 8):
    chunk = r[i:i + 8]
    print(f"   +{i:2}: {chunk.hex(' ')}  {' '.join(chr(c) if 32 <= c < 127 else '.' for c in chunk)}")
print("   as u32:", [struct.unpack_from('<I', r, i)[0] for i in range(0, 40, 4)])
