"""
FINAL geometry brute force.

MEASURED anchor: the item region's names form runs of 32 names spaced exactly 41
bytes; the gap between runs is 45 bytes = 4 + 41, and run-start differences are
exactly 1316 = 4 + 32*41 (831 occurrences).  So:
      group = [u32 header] + 32 records of 41 bytes
The only remaining unknown is where inside the 41-byte record the name starts.

Score each candidate (nameoff, flaglen) by: name printable AND flags plausible
(< 2**41, i.e. only documented TileFlag bits) AND weight < 255 AND layer in the
RunUO Layer enum.  The correct geometry must score far above chance.
"""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
LIMIT = 1 << 41
LAYERS = {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 21,
          22, 23, 24, 25, 26, 27, 28, 29, 30, 31}

# Block start candidates: group starts are at B + 1316*g, and the name of record r
# in group g is at B + 1316*g + 4 + 41*r + nameoff.
# From run starts: first run name 493634 -> and phase says name_residue 35 mod 41.
BEST = []
for nameoff in range(0, 41):
    for flaglen in (4, 8):
        if flaglen + 2 > nameoff:
            continue
        # derive block start B from the anchor name 493634 belonging to record r of group g
        for g in range(0, 3):
            for r in range(0, 32):
                B = 493634 - nameoff - 41*r - 1316*g - 4
                if B < 0:
                    continue
                ok = tot = 0
                for gg in range(g, g+120):
                    base = B + 1316*gg + 4
                    if base + 32*41 > N:
                        break
                    for rr in range(32):
                        b = base + 41*rr
                        tot += 1
                        raw = data[b+nameoff:b+nameoff+20]
                        z = raw.find(b'\0')
                        s = raw[:z if z >= 0 else 20]
                        if len(s) == 0 or not all(0x20 <= c < 0x7f for c in s):
                            continue
                        if int.from_bytes(data[b:b+flaglen], 'little') >= LIMIT:
                            continue
                        if data[b+flaglen] >= 255:
                            continue
                        if data[b+flaglen+1] not in LAYERS:
                            continue
                        ok += 1
                if tot:
                    BEST.append((ok/tot, ok, tot, nameoff, flaglen, B, g, r))
BEST.sort(reverse=True)
print("%-8s %-8s %-8s %-8s %-8s %-10s %s" % ("frac", "valid", "total", "nameoff", "flaglen", "B", "g,r"))
seen = set()
for frac, ok, tot, nameoff, flaglen, B, g, r in BEST:
    k = (nameoff, flaglen, B)
    if k in seen:
        continue
    seen.add(k)
    print("%-8.3f %-8d %-8d %-8d %-8d %-10d %d,%d" % (frac, ok, tot, nameoff, flaglen, B, g, r))
    if len(seen) > 14:
        break
