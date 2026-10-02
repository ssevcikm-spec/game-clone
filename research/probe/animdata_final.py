import os, sys, struct
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(r"D:\Games\Electronic Arts\Ultima Online Classic\animdata.mul", "rb").read()
n = len(d)
S = 92
print("size", n, "= 92 *", n//S)
# find first nonzero record
first = None
for k in range(n // S):
    r = d[k*S:(k+1)*S]
    if any(r):
        first = k
        break
print("first non-zero record index:", first, "byte", first*S if first is not None else None)
for k in range(max(0, first-1), first+3):
    o = k*S
    r = d[o:o+S]
    print(f"\nrec[{k}] @{o}  (u8[0:28] = {list(r[:28])})")
    print(f"   u16 table (32 entries) = {[struct.unpack_from('<H', r, 28+2*i)[0] for i in range(32)]}")

print("\n=== how many records are non-zero? ===")
nz = sum(1 for k in range(n//S) if any(d[k*S:(k+1)*S]))
print(f"   non-zero records: {nz} / {n//S}")
print("\n=== byte 0..27 of a populated record, annotated ===")
k = first
r = d[k*S:(k+1)*S]
for i in range(0, 28, 4):
    print(f"   +{i:2}: {r[i:i+4].hex(' ')}  u8={list(r[i:i+4])}  u16={struct.unpack_from('<H', r, i)[0]}"
          f"  i32={struct.unpack_from('<i', r, i)[0]}")
