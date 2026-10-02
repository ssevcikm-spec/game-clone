import os, struct, sys, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
data = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(data)
print("size", n, "= 2^?", n.bit_length())

# 1) location of a known item name
for needle in (b"spike trap", b"UNUSED", b"VOID", b"nodraw"):
    idxs = []
    start = 0
    while True:
        i = data.find(needle, start)
        if i < 0:
            break
        idxs.append(i)
        start = i + 1
    print(f"  {needle!r}: {len(idxs)} occurrences, first 8 = {idxs[:8]}")

# 2) candidate record sizes: check name-field alignment consistency.
#    A name field is 20 bytes at the END of the record. For the true record size R
#    and item-block start B, name offsets are B + k*R + (R-20).
print("\nname-offset candidates for 'spike trap' (should be B + k*R + R - 20):")
sp = []
start = 0
while True:
    i = data.find(b"spike trap", start)
    if i < 0:
        break
    sp.append(i)
    start = i + 1
print("  spike-trap offsets:", sp[:12])
if len(sp) > 1:
    diffs = [sp[i+1]-sp[i] for i in range(len(sp)-1)]
    print("  diffs:", diffs)
    c = collections.Counter(diffs)
    print("  most common diffs:", c.most_common(6))

# 3) brute force: for R in a range, find B such that B + k*R is consistent
print("\nbrute force (B, R) where 'spike trap' sits at name-field end:")
best = []
for R in range(30, 60):
    for B in range(0, 2000000):
        k0 = (sp[0] - (R - 20) - B) / R
        if k0 < 0 or k0 != int(k0):
            continue
        ok = all((o - (R - 20) - B) % R == 0 and (o - (R - 20) - B) // R >= 0 for o in sp[:40])
        if ok:
            best.append((B, R, int(k0)))
            break
print("  candidates:", best[:20])
