"""Debug the land diamond decoder: verify it writes exactly 1012 pixels into 44x44."""
import sys, os
sys.path.insert(0, r'E:\Workspaces\game-clone\tools\uoextract')
from uop import UOFileUop, create_hash

u = UOFileUop(r"D:\Games\Electronic Arts\Ultima Online Classic\artLegacyMUL.uop")
ents = u.read_entries()
byh = {e.hash: e for e in ents if e.offset}
pat = 'build/artlegacymul/%08d.tga'

W = H = 44


def diamond(raw, verbose=False):
    at = 0
    writes = 0
    guard = 0
    px = [[0]*W for _ in range(H)]
    for i in range(22):
        start = 22 - (i+1)
        pos = i*W + start
        end = start + ((i+1) << 1)
        n = 0
        for j in range(start, end):
            if at + 2 > len(raw) or pos >= (i+1)*W:
                guard += 1
                break
            px[i][pos % W] = raw[at] | (raw[at+1] << 8)
            at += 2
            pos += 1
            n += 1
            writes += 1
        if verbose and i < 3:
            print("   top i=%d start=%d end=%d wrote=%d at=%d" % (i, start, end, n, at))
    for i in range(22):
        pos = (i+22)*W + i
        end = i + ((22-i) << 1)
        n = 0
        for j in range(i, end):
            if at + 2 > len(raw) or pos >= (i+23)*W:
                guard += 1
                break
            px[i+22][pos % W] = raw[at] | (raw[at+1] << 8)
            at += 2
            pos += 1
            n += 1
            writes += 1
        if verbose and i < 3:
            print("   bot i=%d wrote=%d at=%d" % (i, n, at))
    return px, writes, at, guard


for idx in (0, 3, 168, 100):
    e = byh[create_hash(pat % idx)]
    pl = u.read_data(e)
    px, w, at, g = diamond(pl, verbose=(idx == 3))
    nz = sum(1 for r in px for v in r if v)
    print("idx %-5d len=%d writes=%d consumed=%d guard=%d nonzero=%d"
          % (idx, len(pl), w, at, g, nz))
