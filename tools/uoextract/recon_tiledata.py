"""Reconnaissance of tiledata.mul - no assumptions, pure measurement."""
import os, struct, sys, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
P = os.path.join(UO, "tiledata.mul")
data = open(P, "rb").read()
print("size", len(data))

# 1. Find all ASCII strings >= 3 chars with offsets
def strings(buf, minlen=3):
    out = []
    i = 0
    n = len(buf)
    while i < n:
        c = buf[i]
        if 0x20 <= c < 0x7f:
            j = i
            while j < n and 0x20 <= buf[j] < 0x7f:
                j += 1
            if j - i >= minlen:
                out.append((i, buf[i:j].decode("ascii")))
            i = j
        else:
            i += 1
    return out

S = strings(data)
print("total ascii runs >=3:", len(S))
# where is the last string?
print("last string offset:", S[-1][0], repr(S[-1][1]))
print("first 30 strings:")
for o, s in S[:30]:
    print("  ", o, repr(s))

# 2. region stats: strings per 100k
buckets = collections.Counter(o // 100000 for o, s in S)
for k in sorted(buckets):
    print("bucket %2d (%7d-%7d): %d strings" % (k, k*100000, (k+1)*100000-1, buckets[k]))

# 3. strides between consecutive strings
deltas = collections.Counter(S[i+1][0] - S[i][0] for i in range(len(S)-1))
print("top 15 deltas:", deltas.most_common(15))

# 4. hexdump around each known anchor
for anchor in (10, 44, 74, 104, 134, 164, 194, 658, 525227, 534963):
    print("--- anchor %d ---" % anchor)
    lo = max(0, anchor - 32) & ~0xF
    hi = min(len(data), anchor + 80)
    for off in range(lo, hi, 16):
        chunk = data[off:off+16]
        hexs = " ".join("%02x" % b for b in chunk)
        asc = "".join(chr(b) if 0x20 <= b < 0x7f else "." for b in chunk)
        print("  %08x  %-47s  %s" % (off, hexs, asc))
