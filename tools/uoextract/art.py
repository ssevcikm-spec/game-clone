"""
Extract item (static) and land art from artLegacyMUL.uop.

Layout (measured + ported from ClassicUO src/ClassicUO.Assets/ArtLoader.cs, BSD-2-Clause):
  UOP entry -> payload. ClassicUO seeks to entry.Offset then reads:
      u32 flags
      i16 width
      i16 height
      ...then the RLE body; note entry.Length is the *decompressed* length and
      the body buffer is entry.Length bytes read AFTER the 8-byte header.
  Static RLE ("Runs"): body = height x u16 row-offsets (in u16 words from body
      start), then per row: u16 xoffs, u16 run, run x u16 colours; xoffs+run==0
      ends the row.
  Land: 2024 raw bytes = 1012 u16 colours laid into a 44x44 diamond (Diamond()).
"""
import os, sys, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from uop import UOFileUop, create_hash
from PIL import Image

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
OUT = r"E:\Workspaces\game-clone\research\extract-out\art"
os.makedirs(OUT, exist_ok=True)
MAX_LAND = 0x4000


def c16(v):
    r = ((v >> 10) & 0x1F) * 255 // 31
    g = ((v >> 5) & 0x1F) * 255 // 31
    b = (v & 0x1F) * 255 // 31
    return (r, g, b)


def runs(buf, width, height):
    """ClassicUO ArtLoader.Runs -> list of rows of (r,g,b,alpha)."""
    if height <= 0 or width <= 0 or width > 2048 or height > 2048:
        return None
    need = height*2
    if len(buf) < need:
        return None
    lineoffsets = struct.unpack_from('<%dH' % height, buf, 0)
    data = buf
    px = [[(0, 0, 0, 0)]*width for _ in range(height)]
    y = 0
    x = 0
    ptr = height*2 + lineoffsets[0]*2
    guard = 0
    while y < height:
        guard += 1
        if guard > 1000000 or ptr + 4 > len(data):
            break
        xoffs, run = struct.unpack_from('<HH', data, ptr)
        ptr += 4
        if xoffs + run >= 2048:
            break
        if xoffs + run != 0:
            x += xoffs
            row = px[y]
            for j in range(run):
                if ptr + 2 > len(data):
                    break
                val = struct.unpack_from('<H', data, ptr)[0]
                ptr += 2
                if val != 0 and 0 <= x+j < width:
                    r, g, b = c16(val)
                    row[x+j] = (r, g, b, 255)
            x += run
        else:
            x = 0
            y += 1
            if y < height:
                ptr = height*2 + lineoffsets[y]*2
    return px


def diamond(raw):
    """ClassicUO ArtLoader.Diamond -> 44x44 land tile.

    Two triangles meeting in the middle: the top half widens by two pixels per
    row, the bottom half narrows by two.  1012 stored pixels, 44*44 = 1936
    slots, the four corners are never written.

    NB ClassicUO's C# loop advances `pos` itself (pos = i*44+start; pos++) and
    only the source cursor `at` advances by 2 per pixel.
    """
    W = H = 44
    px = [[(0, 0, 0, 0)]*W for _ in range(H)]
    at = 0
    for i in range(22):
        start = 22 - (i+1)
        pos = i*W + start
        end = start + ((i+1) << 1)
        for j in range(start, end):
            if at + 2 > len(raw) or pos >= (i+1)*W:
                return px
            v = raw[at] | (raw[at+1] << 8)
            at += 2
            r, g, b = c16(v)
            px[i][pos % W] = (r, g, b, 255)
            pos += 1
    for i in range(22):
        pos = (i+22)*W + i
        end = i + ((22-i) << 1)
        for j in range(i, end):
            if at + 2 > len(raw) or pos >= (i+23)*W:
                return px
            v = raw[at] | (raw[at+1] << 8)
            at += 2
            r, g, b = c16(v)
            px[i+22][pos % W] = (r, g, b, 255)
            pos += 1
    return px


def save(px, path, w, h, name):
    img = Image.new('RGBA', (w, h))
    img.putdata([px[y][x] for y in range(h) for x in range(w)])
    img.save(path)
    return img


def img_stats(img):
    d = list(img.getdata())
    n = len(d)
    nz = sum(1 for p in d if p[3] > 0)
    nb = sum(1 for p in d if p[3] > 0 and (p[0] or p[1] or p[2]))
    from collections import Counter
    c = Counter((p[0], p[1], p[2]) for p in d if p[3] > 0)
    dom = c.most_common(1)[0] if c else ((0, 0, 0), 0)
    return n, nz, nb, dom, len(c)


# ---- open archive and build hash -> entry map
u = UOFileUop(os.path.join(UO, "artLegacyMUL.uop"))
ents = u.read_entries()
by_hash = {}
for e in ents:
    if e.offset:
        by_hash[e.hash] = e
pat = "build/artlegacymul/%08d.tga"
print("archive: entries=%d nonzero=%d distinct_hashes=%d"
      % (len(ents), sum(1 for e in ents if e.offset), len(by_hash)))

by_index = {}
for i in range(0x20000):
    h = create_hash(pat % i)
    if h in by_hash:
        by_index[i] = by_hash[h]
print("resolved indices 0..0x1FFFF -> %d entries" % len(by_index))


def get_art(idx):
    """idx is the ARCHIVE index. For statics that is tiledata_id + 0x4000
    (measured: archive holds 4244 land entries 0..0x3FFF and 39516 statics
    from 0x4000 up to 62763)."""
    e = by_index.get(idx)
    if e is None:
        return None
    payload = u.read_data(e)
    if payload is None:
        return None
    if idx < MAX_LAND:
        raw = payload[:2024]
        if len(raw) < 2024:
            return None
        return diamond(raw), 44, 44
    flags, w, h = struct.unpack_from('<Ihh', payload, 0)
    body = payload[8:]
    px = runs(body, w, h)
    if px is None:
        return None
    return px, w, h


# ---- tiledata names, so ids are chosen by NAME not guessed
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

TARGETS = [
    ('item', 3936+0x4000, 'longsword'), ('item', 3921+0x4000, 'dagger'),
    ('item', 5118+0x4000, 'katana'), ('item', 7609+0x4000, 'leather cap'),
    ('item', 2482+0x4000, 'backpack'), ('item', 4015+0x4000, 'anvil'),
    ('item', 4017+0x4000, 'forge'), ('item', 321+0x4000, 'wooden beam'),
    ('item', 5061+0x4000, 'leather sleeves'), ('item', 5397+0x4000, 'cloak'),
    ('land', 3, 'grass land'), ('land', 168, 'sand land'), ('land', 0, 'land0'),
    ('land', 1006, 'stone stairs land'),
]

print()
print("%-6s %-8s %-16s %-5s %-9s %-11s %-11s %s" %
      ("kind", "index", "name", "WxH", "nz_pixels", "nonblack", "distinct", "dominant"))
results = []
for kind, idx, name in TARGETS:
    r = get_art(idx)
    if r is None:
        print("%-6s %-8d %-16s  MISSING in archive" % (kind, idx, name))
        continue
    px, w, h = r
    fn = os.path.join(OUT, "%s_%05d_%s.png" % (kind, idx, name.replace(' ', '_')))
    img = save(px, fn, w, h, name)
    n, nz, nb, dom, nd = img_stats(img)
    print("%-6s %-8d %-16s %-5s %-9d %-11d %-11d %s" %
          (kind, idx, name, "%dx%d" % (w, h), nz, nb, nd, dom[0]))
    results.append((kind, idx, name, fn, w, h, nz, nb))
print()
for r in results:
    print("SAVED", r[3])
