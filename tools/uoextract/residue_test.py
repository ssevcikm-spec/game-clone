"""
Definitive residue test.

The 'stone stairs' cluster proves STRIDE == 41 for the region around 534,963.
For ANY absolute offset O in that region, a record layout with name at record+NO
means a string starts at O only if (O - NO) % 41 == phase.  Instead of guessing,
score EVERY (phase, nameoff) pair by how many of the region's records decode to
a clean name AND a sane animID (the animID of consecutive tiles usually increments).
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

# Use a large region entirely inside one block, e.g. 500000..700000
A, B = 500000, 700000


def clean(b, n):
    if b < 0 or b+n > N: return None
    raw = data[b:b+n]
    z = raw.find(b'\0')
    s = raw[:z if z >= 0 else n]
    if len(s) == 0: return b''
    if all(0x20 <= c < 0x7f for c in s): return s
    return None


print("=== score each (nameoff 0..40) over region %d..%d, stride 41 ===" % (A, B))
print("%-8s %-10s %-9s %-9s %s" % ("nameoff", "nameoff%41", "records", "clean", "animID-monotonic%"))
rows = []
for nameoff in range(0, 41):
    for start in range(A, A+41):
        if start - nameoff < 0: continue
        S0 = start - nameoff
        n = 0; cl = 0; mono = 0; prev = None
        S = S0
        while S + 41 <= B:
            s = clean(S+nameoff, 20)
            n += 1
            if s: cl += 1
            anim = int.from_bytes(data[S+14:S+16], 'little') if S+16 <= N else 0
            if prev is not None and anim == (prev+1) & 0xFFFF: mono += 1
            prev = anim
            S += 41
        if n: rows.append((cl/n, cl, n, nameoff, start, mono))
rows.sort(reverse=True)
for frac, cl, n, nameoff, start, mono in rows[:10]:
    print("  nameoff=%2d start=%8d records=%5d clean=%5d (%.1f%%) animID+1 %d"
          % (nameoff, start, n, cl, 100.0*cl/n, mono))
