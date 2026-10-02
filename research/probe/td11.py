import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
LAND_END = 4 + 0x4000 * 34
print("landEnd", LAND_END, " file", n, " remaining", n - LAND_END)

# score: for candidate (start, stride, nameOff, nameLen) count records whose name
# field is purely [printable chars then NULs] and ends exactly at the field end
def score(start, stride, nameOff, nameLen, kmin=0, kmax=0x4000):
    ok = 0
    tot = 0
    for k in range(kmin, kmax):
        o = start + k * stride
        if o + nameOff + nameLen > n:
            break
        tot += 1
        f = d[o + nameOff:o + nameOff + nameLen]
        z = f.find(b"\x00")
        if z < 0:
            continue
        if all(0x20 <= c < 0x7f for c in f[:z]) and all(c == 0 for c in f[z:]):
            ok += 1
    return ok, tot

print("\n=== score item candidate layouts (start=landEnd) ===")
for stride in (30, 34, 37, 41, 45):
    for nameOff in (16, 17, 21, 26, 29, 30):
        for nameLen in (20,):
            ok, tot = score(LAND_END, stride, nameOff, nameLen)
            if ok > tot * 0.9:
                print(f"  stride={stride} nameOff={nameOff} nameLen={nameLen}: {ok}/{tot}")

print("\n=== score with stride 41, all nameOff 0..41 ===")
best = []
for nameOff in range(0, 42):
    ok, tot = score(LAND_END, 41, nameOff, 20)
    best.append((ok, nameOff, tot))
best.sort(reverse=True)
print("  top:", best[:8])

print("\n=== score with stride 41 and start varied around landEnd ===")
cands = []
for start in range(LAND_END - 200, LAND_END + 200):
    for nameOff in (16, 17, 21, 26, 29, 30):
        ok, tot = score(start, 41, nameOff, 20)
        cands.append((ok, start, nameOff, tot))
cands.sort(reverse=True)
print("  top:", cands[:10])

print("\n=== score with stride 34 (if item records were also 34) ===")
best2 = []
for nameOff in range(0, 35):
    ok, tot = score(LAND_END, 34, nameOff, 20)
    best2.append((ok, nameOff, tot))
best2.sort(reverse=True)
print("  top:", best2[:6])

print("\n=== how many records fit? file-based ===")
for stride in (34, 41):
    print(f"  stride {stride}: (n - LAND_END)/stride = {(n-LAND_END)/stride}")
    print(f"  stride {stride}: LAND_END + 0x4000*stride = {LAND_END + 0x4000*stride}")
