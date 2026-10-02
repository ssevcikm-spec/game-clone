import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)

print("=== 'spike trap' occurrence hex context ===")
i = d.find(b"spike trap")
print("first @", i)
print("  41 bytes back-to-back, starting at first occurrence:")
print("  ", d[i:i + 82].hex(" "))
print("  65 bytes BEFORE first occurrence:")
print("  ", d[i - 65:i].hex(" "))

print("\n=== 'telescope' occurrence ===")
j = d.find(b"telescope")
print("  @", j, " context:", d[j - 30:j + 20].hex(" "))

print("\n=== solve: item block start from 'spike trap' stride-41 chain ===")
# chain of 7 consecutive at 41 stride, then 7 more at 41 (two groups)
chain = [672897, 672938, 672979, 673020, 673061, 673102, 673143]
print("  chain:", chain)
print("  chain[1]-chain[0] =", chain[1] - chain[0])
for nameoff in range(0, 41):
    for k0 in range(0, 0x4000):
        if chain[0] - nameoff - k0 * 41 < 0:
            continue
        start = chain[0] - nameoff - k0 * 41
        if start + 0x4000 * 41 != n:
            continue
        print(f"  SOLUTION: itemStart={start} nameOff={nameoff} k0={k0} (start+0x4000*41=={n})")
# also allow the block not to fill the file
print("\n  all (nameOff, k0) mapping chain[0] with itemStart = chain[0]-nameOff-k0*41:")
for nameoff in (16, 17, 21, 26):
    ks = [(chain[0] - nameoff - k0 * 41, k0) for k0 in range(0, 0x4000)]
    ks = [(s, k) for s, k in ks if 0 <= s <= n]
    print(f"   nameOff={nameoff}: itemStart range {min(s for s,_ in ks)}..{max(s for s,_ in ks)}")

print("\n=== dump bytes 557056..557200 (claimed item block start) ===")
print("  ", d[557056:557200].hex(" "))
print("\n=== item[0] as 41-byte record, all offsets annotated ===")
o = 557056
r = d[o:o + 41]
print("  rec:", r.hex(" "))
for k in range(0, 41, 1):
    pass
print("  u32@0 =", struct.unpack_from("<I", r, 0)[0])
print("  u32@4 =", struct.unpack_from("<I", r, 4)[0])

print("\n=== find record start where 'tent roof' name ends at a 41 boundary ===")
t = d.find(b"tent roof")
print("  'tent roof' @", t)
for nameoff in range(0, 41):
    s = t - nameoff
    print(f"   nameOff={nameoff} -> recStart={s}, itemIdx={(s-557056)/41 if (s-557056)>=0 else -1}, "
          f"(s-557056)%41={(s-557056)%41}")
