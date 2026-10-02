"""
Comprehensive geometry search for tiledata.mul item block.

Criterion (measurable, no assumptions):
  A record is VALID if, with the candidate geometry, it has
    - a non-empty printable-ASCII name, AND
    - flags that are a plausible UO TileFlag set (value < 2**41, i.e. only the
      documented bits below bit 41 are used), AND
    - weight < 255
We search group size (no header / small header), record offset within group,
and name offset within record, and report which combination maximises VALIDITY.
"""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
LIMIT = 1 << 41


def namelen(b, n=20):
    raw = data[b:b+n]
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else n]
    if len(s) == 0:
        return 0
    return len(s) if all(0x20 <= c < 0x7f for c in s) else -1


def evaluate(S, gsz, rec0, noff, ngroups=400, nrec=32):
    """Return (valid, total) for ngroups groups starting at S."""
    valid = tot = 0
    for g in range(ngroups):
        base = S + g*gsz + rec0
        for k in range(nrec):
            b = base + k*41
            if b + 41 > N:
                return valid, tot
            tot += 1
            nm = namelen(b + noff)
            if nm <= 0:
                continue
            if int.from_bytes(data[b:b+8], 'little') >= LIMIT:
                continue
            if data[b+8] >= 255:
                continue
            valid += 1
    return valid, tot


# Anchor: leather record name 'gargoyle_leather_arm' at 525218 with name offset 21.
# So a record start R satisfies R = S + g*gsz + rec0 + k*41 and R + 21 == 525218
# => R == 525197.
print("anchor record start (from leather name) =", 525218 - 21)
best = []
for gsz in range(1310, 1340):
    for rec0 in range(0, 12):
        # S such that one record lands on 525197
        for g in (0, 1, 2, 3, 4, 5, 10, 20, 30):
            for k in (0, 1, 2, 3, 5, 10, 16, 31):
                S = 525197 - g*gsz - rec0 - k*41
                if S < 0:
                    continue
                v, t = evaluate(S, gsz, rec0, 21, ngroups=200)
                best.append((v, t, gsz, rec0, S))
best.sort(reverse=True)
seen = set()
print("%-7s %-7s %-6s %-6s %s" % ("valid", "total", "gsz", "rec0", "S"))
for v, t, gsz, rec0, S in best:
    key = (gsz, rec0, S)
    if key in seen: continue
    seen.add(key)
    print("%-7d %-7d %-6d %-6d %d" % (v, t, gsz, rec0, S))
    if len(seen) > 12: break
