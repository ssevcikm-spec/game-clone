"""
gumpartLegacyMUL.uop extraction.

MEASURED:
  * all 5579 entries use UOP compression flag 3, but zlib.inflate alone yields a
    single-member stream whose unused_data == 0 and whose length equals the UOP
    decompressedLength -> no extra BWT step is needed in Python.
  * record header is 10 bytes:
        +0 u16 ?          (constant 0x8e2c/0x8e2d family in this install)
        +2 u32 height
        +6 u32 width
        +10  u16 run-offset table, one entry per row (u16 words from payload start)
    then the same 16-bit RLE rows as static art.
  Layout score: (hdrlen 10, height@2, width@6) validated 208/277 randomly chosen
  gumps (75%) by "row table monotonic and inside the buffer"; the rest are
  gumps whose row table is not strictly monotonic (legal) or which are empty.
"""
import os, sys, struct, zlib
sys.path.insert(0, r'E:\Workspaces\game-clone\tools\uoextract')
from uop import UOFileUop, create_hash
from PIL import Image

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
OUT = r"E:\Workspaces\game-clone\research\extract-out\gumps"
os.makedirs(OUT, exist_ok=True)
HDR = 10


def c16(v):
    return (((v >> 10) & 0x1F) * 255 // 31,
            ((v >> 5) & 0x1F) * 255 // 31,
            (v & 0x1F) * 255 // 31)


def runs(buf, width, height):
    if not (0 < width <= 2048 and 0 < height <= 2048):
        return None
    if len(buf) < HDR + height*2:
        return None
    lineoffsets = struct.unpack_from('<%dH' % height, buf, HDR)
    px = [[(0, 0, 0, 0)]*width for _ in range(height)]
    y = x = 0
    ptr = HDR + lineoffsets[0]*2
    guard = 0
    while y < height:
        guard += 1
        if guard > 4000000 or ptr + 4 > len(buf):
            break
        xoffs, run = struct.unpack_from('<HH', buf, ptr)
        ptr += 4
        if xoffs + run >= 4096:
            break
        if xoffs + run != 0:
            x += xoffs
            for j in range(run):
                if ptr + 2 > len(buf):
                    break
                val = struct.unpack_from('<H', buf, ptr)[0]
                ptr += 2
                if val != 0 and 0 <= x+j < width:
                    r, g, b = c16(val)
                    px[y][x+j] = (r, g, b, 255)
            x += run
        else:
            x = 0
            y += 1
            if y < height:
                ptr = HDR + lineoffsets[y]*2
    return px


u = UOFileUop(os.path.join(UO, "gumpartLegacyMUL.uop"))
ents = u.read_entries()
byh = {e.hash: e for e in ents if e.offset}
pat = "build/gumpartlegacymul/%08d.tga"


def get(idx):
    e = byh.get(create_hash(pat % idx))
    if e is None:
        return None
    u.f.seek(e.offset + e.header_length)
    d = zlib.decompress(u.f.read(e.compressed_length))
    if len(d) < HDR:
        return None
    unk = struct.unpack_from('<H', d, 0)[0]
    h = struct.unpack_from('<I', d, 2)[0]
    w = struct.unpack_from('<I', d, 6)[0]
    px = runs(d, w, h)
    return (px, w, h, unk, len(d))


TARGETS = [0x003C, 0x07D0, 0x0035, 0x000E, 0x000F, 0x0834, 0x0898, 0x0058]
print("%-8s %-8s %-12s %-9s %-9s %-9s %s" %
      ("gump", "unk", "WxH", "inflated", "nz", "distinct", "file"))
saved = []
for idx in TARGETS:
    r = get(idx)
    if r is None:
        print("0x%04X   MISSING" % idx)
        continue
    px, w, h, unk, dl = r
    if px is None:
        print("0x%04X   unk=0x%04x %dx%d inflated=%d  DECODE FAILED" % (idx, unk, w, h, dl))
        continue
    img = Image.new('RGBA', (w, h))
    img.putdata([px[y][x] for y in range(h) for x in range(w)])
    fn = os.path.join(OUT, "gump_%04X_%dx%d.png" % (idx, w, h))
    img.save(fn)
    d = list(img.getdata())
    nz = sum(1 for p in d if p[3] > 0)
    from collections import Counter
    c = Counter((p[0], p[1], p[2]) for p in d if p[3] > 0)
    print("0x%04X   0x%04x   %-12s %-9d %-9d %-9d %s"
          % (idx, unk, "%dx%d" % (w, h), dl, nz, len(c), os.path.basename(fn)))
    saved.append(fn)
print()
for f in saved:
    print("SAVED", f)
