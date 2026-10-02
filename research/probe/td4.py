import os, sys, collections, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)

runs = []
i = 0
while i < n:
    if 0x20 <= d[i] < 0x7f:
        j = i
        while j < n and 0x20 <= d[j] < 0x7f and j - i < 40:
            j += 1
        runs.append((i, d[i:j].decode("ascii")))
        i = j
    else:
        i += 1

print("total runs:", len(runs))
# 1) where does the "grass/furrows" land region end and what is the land stride?
landend = max(o for o, s in runs if o < 600000)
print("last land-ish run offset:", landend)

# 2) histogram of stride to next run, split by region
def strides(lo, hi):
    os_ = [o for o, s in runs if lo <= o < hi]
    return collections.Counter(os_[k+1]-os_[k] for k in range(len(os_)-1))

print("\nstrides in [0, 600000):", strides(0, 600000).most_common(8))
print("strides in [600000, 1200000):", strides(600000, 1200000).most_common(8))
print("strides in [1200000, 2500000):", strides(1200000, 2500000).most_common(8))

# 3) find the item block start: first run whose stride becomes 41 permanently
os_ = [o for o, s in runs]
first41 = None
for k in range(len(os_) - 40):
    if all(os_[k + t + 1] - os_[k + t] == 41 for t in range(40)):
        first41 = os_[k]
        break
print("\nfirst offset from which 40 consecutive strides are 41:", first41)
if first41 is not None:
    print("  -> item block start (name field offset) =", first41)
    print("  -> item record = 41 bytes")

# 4) land stride consistency from 0
print("\nfirst 20 land name offsets:", os_[:20])
print("diffs:", [os_[k+1]-os_[k] for k in range(19)])

# 5) hypothesis test: land record = 30 bytes, N land entries
for L in (0x4000,):
    for R in (30, 34, 38, 26):
        print(f"  land R={R} N={L}: block ends {L*R}, spike starts 672897 -> item block would start "
              f"{672897 - 5} (name at +5 within 41-byte rec)")
print("  0x4000*41 =", 0x4000*41, " + ", 0x4000*41, " = ", 0x8000*41, " file =", n)
print("  n / 41 =", n/41, " n / 30 =", n/30, " n/  (30+41) =", n/71)
