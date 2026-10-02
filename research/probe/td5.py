import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)

# find all occurrences of the 41-stride chain
needle = b"spike trap"
sp = []
i = 0
while True:
    i = d.find(needle, i)
    if i < 0:
        break
    sp.append(i)
    i += 1
print("all 'spike trap' offsets:", sp)
print("n occurrences:", len(sp))

# the last item name region ends near the end of file; guess item block params
print("\nSolving: itemOffset + k*RS + NAME_OFF = sp[k]")
# We know consecutive sp differ by 41 -> RS == 41 (if names are at same field)
# So itemOffset = sp[0] - k0*41 - NAME_OFF. Try k0 values and NAME_OFF values.
print("\ncandidate (itemOffset, k0, NAME_OFF) with itemOffset+k0*41+NAME_OFF = %d and itemOffset+0x4000*41 <= %d:" % (sp[0], n))
cands = []
for k0 in range(0, 0x4000):
    for NAME_OFF in (37, 21, 17, 26, 30, 36, 41 - 20, 41 - 21):
        io = sp[0] - k0 * 41 - NAME_OFF
        if io < 0 or io + 0x4000 * 41 > n:
            continue
        if io % 41 == 0 or True:
            cands.append((io, k0, NAME_OFF))
print("  count:", len(cands))
seen = {}
for io, k0, NAME_OFF in cands:
    seen.setdefault(io, []).append((k0, NAME_OFF))
top = sorted(seen.items())[:12]
for io, v in top:
    print(f"   itemOffset={io}  (n-itemOffset)/41={(n-io)/41}  k0/NAME_OFF={v[:3]}")

# Better: candidate where (n - itemOffset) is an exact multiple of 41 AND equals 0x4000
print("\nExact-fit candidates where (n - itemOffset) % 41 == 0:")
for io in sorted(seen):
    if (n - io) % 41 == 0:
        print(f"   itemOffset={io} records={(n-io)//41} k0/NAME_OFF={seen[io][:4]}")

# Sanity: assume item block = 0x4000 records * 41 and it ends at EOF
io_exact = n - 0x4000 * 41
print(f"\nIf item block is 0x4000*41 and ends at EOF: itemOffset = {io_exact}")
print(f"  then land block = [0,{io_exact}) -> {io_exact} bytes")
print(f"  land bytes / 0x4000 = {io_exact/0x4000}  (per land record)")
print(f"  land: 512 groups * (4 + 32*R) = {io_exact} -> R = {(io_exact/512 - 4)/32}")
# now verify a name offset
R = (io_exact / 512 - 4) / 32
print(f"  land record size R = {R}")
for k in (0, 1, 2, 3):
    o = 4 + k * R + 6
    print(f"   land[{k}] name field @{int(o)}: {d[int(o):int(o)+20]!r}")
o = 4 + 3 * R + 6
print("   land[3] full rec:", d[4+3*int(R):4+4*int(R)].hex(" "))
print("   land[0] full rec:", d[4:4+int(R)].hex(" "))
