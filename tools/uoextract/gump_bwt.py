"""
Determine the REAL decompression for gumpartLegacyMUL.uop entries (flag 3).

Candidates:
  A) plain zlib.inflate, use as-is
  B) zlib.inflate, then undo a WHOLE-BUFFER BWT with primary index in the first i32
  C) zlib.inflate, then undo per-block BWT with i32 block sizes

Scored by: does the result start with a sane gump header (i32 unused, i32 w, i32 h)
with 0 < w,h <= 1024 and len(payload) >= 8 + h*2 ?
"""
import os, sys, struct, zlib
sys.path.insert(0, r'E:\Workspaces\game-clone\tools\uoextract')
from uop import UOFileUop, create_hash

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
u = UOFileUop(os.path.join(UO, "gumpartLegacyMUL.uop"))
ents = u.read_entries()
byh = {e.hash: e for e in ents if e.offset}
pat = "build/gumpartlegacymul/%08d.tga"


def inflate(e):
    u.f.seek(e.offset + e.header_length)
    return zlib.decompress(u.f.read(e.compressed_length))


def sane(d):
    if d is None or len(d) < 8:
        return None
    flags, w, h = struct.unpack_from('<Iii', d, 0)
    if 0 < w <= 1024 and 0 < h <= 1024 and len(d) >= 8 + h*2:
        return (flags, w, h)
    return None


def bwt_inv(last: bytes, idx: int) -> bytes:
    m = len(last)
    if m < 2:
        return last
    cnt = [0]*257
    for b in last:
        cnt[b+1] += 1
    for i in range(1, 257):
        cnt[i] += cnt[i-1]
    nxt = [0]*m
    for i, b in enumerate(last):
        nxt[cnt[b]] = i
        cnt[b] += 1
    out = bytearray(m)
    p = nxt[idx] if 0 <= idx < m else nxt[0]
    for i in range(m):
        p = nxt[p]
        out[i] = last[p]
    return bytes(out)


def variant_A(d):
    return d


def variant_B(d):
    idx = struct.unpack_from('<i', d, 0)[0]
    return bwt_inv(d[4:], idx)


def variant_C(d, bsizes=(4096, 8192, 16384, 32768, 65536)):
    # try a simple two-level scheme: i32 count, then per block i32 idx + i32 len
    for off in (0, 4):
        try:
            cnt = struct.unpack_from('<i', d, off)[0]
            if not (0 < cnt < 100000):
                continue
            p = off + 4
            out = bytearray()
            okall = True
            for _ in range(cnt):
                bidx, blen = struct.unpack_from('<ii', d, p)
                p += 8
                if blen <= 0 or p + blen > len(d):
                    okall = False
                    break
                out += bwt_inv(d[p:p+blen], bidx)
                p += blen
            if okall and out:
                return bytes(out)
        except Exception:
            pass
    return None


counts = {'A': 0, 'B': 0, 'C': 0}
tot = 0
samples = {'A': [], 'B': [], 'C': []}
for idx in range(0, 3000):
    e = byh.get(create_hash(pat % idx))
    if e is None:
        continue
    tot += 1
    try:
        d = inflate(e)
    except Exception as ex:
        continue
    for name, fn in (('A', variant_A), ('B', variant_B), ('C', variant_C)):
        s = sane(fn(d))
        if s:
            counts[name] += 1
            if len(samples[name]) < 5:
                samples[name].append((idx, s, len(d)))

print("gumps tested:", tot)
for k in 'ABC':
    print("  variant %s: sane headers %d (%.1f%%)" % (k, counts[k], 100.0*counts[k]/max(1, tot)))
    for s in samples[k]:
        print("      idx=0x%04X flags=0x%08x %dx%d inflated=%d" % (s[0], s[1][0], s[1][1], s[1][2], s[2]))
