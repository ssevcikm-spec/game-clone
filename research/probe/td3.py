import os, struct, sys, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)

print("first 200 bytes of tiledata.mul:")
for i in range(0, 200, 16):
    print(f"  {i:5}  {d[i:i+16].hex(' ')}")

# collect printable ASCII runs (length>=4) with their offsets
runs = []
i = 0
while i < min(n, 4000000):
    if 0x20 <= d[i] < 0x7f:
        j = i
        while j < n and 0x20 <= d[j] < 0x7f and j - i < 40:
            j += 1
        if j - i >= 4:
            runs.append((i, d[i:j].decode("ascii")))
        i = j
    else:
        i += 1
print(f"\nprintable runs >=4 chars in whole file: {len(runs)}")
print("first 30:", runs[:30])
print("last 10:", runs[-10:])

offs = [o for o, s in runs]
print(f"\nfirst run @{offs[0]}, last run @{offs[-1]}")
diffs = [offs[i+1]-offs[i] for i in range(min(len(offs)-1, 200))]
print("first diffs:", diffs[:30])
print("most common diffs (over first 200):", collections.Counter(diffs).most_common(8))

# Check: do the item-block names ("spike trap") start at itemoffset?
sp = [o for o, s in runs if "spike trap" in s]
print("\nspike-trap first 6 offsets:", sp[:6], " diffs:", [sp[i+1]-sp[i] for i in range(5)])
print("spike-trap offset mod 41:", [o % 41 for o in sp[:6]])
print("spike-trap offset mod 37:", [o % 37 for o in sp[:6]])
