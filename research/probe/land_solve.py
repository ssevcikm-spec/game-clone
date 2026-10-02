import os, sys, struct, collections
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(r"D:\Games\Electronic Arts\Ultima Online Classic\tiledata.mul", "rb").read()
n = len(d)
print("file", n)
print("first 300 bytes:")
for i in range(0, 300, 30):
    print(f"  {i:5}: {d[i:i+30].hex(' ')}  |{''.join(chr(c) if 32<=c<127 else '.' for c in d[i:i+30])}|")

# find the true stride by looking at the *name* field starts:
# a name field start is a byte position where a printable run begins and the
# preceding 4-8 bytes are a plausible flags/texid pair.
# Instead: measure the distance between successive records by finding where the
# 4-byte flags word is all-zero AND the pattern repeats.
print("\n=== candidate strides: score k*S+NAMEOFF as a valid name field ===")
def score(S, NO, limit=0x4000, NL=20):
    ok = 0
    for k in range(limit):
        o = k * S + NO
        if o + NL > n:
            break
        f = d[o:o + NL]
        z = f.find(b"\x00")
        z = NL if z < 0 else z
        if z == 0:
            ok += 1
        elif all(0x20 <= c < 0x7f for c in f[:z]) and all(c == 0 for c in f[z:]):
            ok += 1
    return ok

best = []
for S in range(26, 42):
    for NO in range(0, 20):
        best.append((score(S, NO), S, NO))
best.sort(reverse=True)
print("top 15 (score, stride, nameOff) over 0x4000 records:")
for s, S, NO in best[:15]:
    print(f"   score={s:6} stride={S:3} nameOff={NO:3}  ({100.0*s/0x4000:.1f}%)")

# sanity: the winning combination's contiguous-run behaviour
s, S, NO = best[0]
print(f"\n=== winner stride={S} nameOff={NO} ===")
for k in (0, 1, 2, 3, 4, 5, 6, 7):
    o = k * S
    fl = struct.unpack_from("<I", d, o)[0] if o + 4 <= n else None
    tid = struct.unpack_from("<H", d, o + 4)[0] if o + 6 <= n else None
    nm = d[o + NO:o + NO + 20]
    print(f"   rec={o:6} flags=0x{fl:08X} u16@+4={tid:6} name@{o+NO}= {nm!r}")
