"""
Find the real gump record header.

MEASURED: zlib.inflate(entry) already yields the final, uncompressed gump for
gumpartLegacyMUL.uop (single-member stream, unused_data == 0).  The first bytes
of gump 0x003C are:
    fd 09 2d 8e 51 6e 02 00 f8 50 02 00 e5 14 02 00 ad 0d 02 00 ...
The run table (one u16 per row) must start at a small offset.  Test candidate
header sizes and score by whether the row-offset table is monotonically
non-decreasing AND every row offset resolves inside the buffer.
"""
import os, sys, struct, zlib
sys.path.insert(0, r'E:\Workspaces\game-clone\tools\uoextract')
from uop import UOFileUop, create_hash

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
u = UOFileUop(os.path.join(UO, "gumpartLegacyMUL.uop"))
ents = u.read_entries()
byh = {e.hash: e for e in ents if e.offset}
pat = "build/gumpartlegacymul/%08d.tga"


def inflate(idx):
    e = byh.get(create_hash(pat % idx))
    if e is None:
        return None
    u.f.seek(e.offset + e.header_length)
    return zlib.decompress(u.f.read(e.compressed_length))


def try_layout(d, hdrlen, wpos, hpos, wsize, hsize):
    if len(d) < hdrlen + 4:
        return None
    w = int.from_bytes(d[wpos:wpos+wsize], 'little')
    h = int.from_bytes(d[hpos:hpos+hsize], 'little')
    if not (0 < w <= 2048 and 0 < h <= 2048):
        return None
    if len(d) < hdrlen + h*2:
        return None
    tab = struct.unpack_from('<%dH' % h, d, hdrlen)
    # monotonic non-decreasing and inside the buffer
    prev = -1
    for t in tab:
        if t < prev:
            return None
        prev = t
    if hdrlen + tab[-1]*2 >= len(d) + 2048:
        return None
    return w, h, hdrlen, tab[0], tab[-1], len(d)


CANDS = []
# (hdrlen, woff, hoff, wsize, hsize)
for hdrlen in range(0, 20):
    for woff, wsize in ((0, 2), (0, 4), (4, 2), (4, 4), (2, 4)):
        for hoff, hsize in ((6, 2), (8, 4), (6, 4), (4, 4), (2, 4), (6, 2)):
            if hoff + hsize > hdrlen:
                continue
            CANDS.append((hdrlen, woff, hoff, wsize, hsize))

score = {}
for cand in CANDS:
    score[cand] = 0
tot = 0
tested = list(range(0, 400)) + [0x003C, 0x07D0, 0x0035, 0x0834, 0x0898, 0x0058, 0x01F4]
for idx in tested:
    d = inflate(idx)
    if d is None:
        continue
    tot += 1
    for cand in CANDS:
        if try_layout(d, *cand):
            score[cand] += 1
res = sorted(score.items(), key=lambda x: -x[1])
print("gumps tested:", tot)
print("%-8s %-6s %-6s %-6s %-6s %s" % ("hdrlen", "woff", "hoff", "wsize", "hsize", "ok"))
for cand, n in res[:12]:
    print("%-8d %-6d %-6d %-6d %-6d %d (%.1f%%)" % (cand[0], cand[1], cand[2], cand[3], cand[4], n, 100.0*n/tot))

print()
best = res[0][0]
print("best candidate:", best)
for idx in (0x003C, 0x07D0, 0x0035, 0x0003, 0x0024):
    d = inflate(idx)
    if d is None:
        continue
    r = try_layout(d, *best)
    print("  gump 0x%04X -> %s   first16=%s" % (idx, r, d[:16].hex()))
