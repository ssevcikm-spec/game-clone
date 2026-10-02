"""Empiricky overi formaty datovych souboru Ultima Online Classic.

Nepredpoklada layouty - odvozuje je z dat a overuje je zpetne
(nazvy musi byt citelne ASCII, stridy musi sedet na velikost souboru).
Vystup: konzolove shrnuti + research/probe-uo.json
"""
import json
import re
import struct
import sys
from collections import Counter
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
OUT = Path(r"E:\Workspaces\game-clone\research")
OUT.mkdir(parents=True, exist_ok=True)
REPORT = {}

PRINTABLE = set(range(32, 127))


def find_strings(data, min_len=3, max_len=24, limit=None):
    """Najde NUL-terminovane tisknutelne retezce a jejich offsety."""
    out = []
    n = len(data)
    i = 0
    while i < n:
        c = data[i]
        if c in PRINTABLE:
            j = i
            while j < n and data[j] in PRINTABLE and (j - i) < max_len:
                j += 1
            if data[j:j + 1] == b"\x00" and (j - i) >= min_len:
                out.append((i, data[i:j].decode("latin1")))
                i = j + 1
                if limit and len(out) >= limit:
                    return out
                continue
            i = j
        else:
            i += 1
    return out


def detect_stride(pairs, lo=20, hi=140):
    """Nejcastejsi vzdalenost mezi po sobe jdoucimi retezci = stride recordu."""
    offs = [o for o, _ in pairs]
    diffs = Counter()
    for a, b in zip(offs, offs[1:]):
        d = b - a
        if lo <= d <= hi:
            diffs[d] += 1
    return diffs.most_common(6)


print("=" * 72)
print("TILEDATA.MUL")
print("=" * 72)
td = (UO / "tiledata.mul").read_bytes()
print(f"velikost: {len(td)} B")
pairs = find_strings(td, min_len=3, max_len=20)
print(f"nalezeno retezcu (3-20 znaku): {len(pairs)}")
print(f"nejcastejsi vzdalenosti mezi retezci: {detect_stride(pairs)}")
print("prvni 3 retezce:", pairs[:3])
print("hex zacetku souboru:", td[:48].hex(" "))

# --- odhad: land blok je na zacatku, item blok dal ---
# land zaznam: 4B flagy + 2B textura + 20B nazev  => nazev na offsetu 6
# hledame kandidatni land stridy
land_cands = []
for stride in (26, 30, 32):
    off = 6
    ok = 0
    tested = 0
    for idx in range(0, 0x4000, 37):
        base = idx * stride + off
        if base + 20 > len(td):
            break
        chunk = td[base:base + 20]
        tested += 1
        name = chunk.split(b"\x00")[0]
        if all(c in PRINTABLE or c == 0 for c in chunk):
            ok += 1
    land_cands.append((stride, ok, tested, round(ok / max(tested, 1), 3)))
print("kandidati na land stride (stride, tisknutelne, testovano, pomer):", land_cands)

REPORT["tiledata"] = {
    "size": len(td),
    "strings": len(pairs),
    "land_candidates": land_cands,
    "top_diffs": detect_stride(pairs),
}

# --- item blok: najdi stride z retezcu v druhe polovine souboru ---
half = len(td) // 2
tail_pairs = [(o, s) for o, s in pairs if o > half]
print(f"\nretezcu v druhe polovine: {len(tail_pairs)}")
tail_diffs = detect_stride(tail_pairs, lo=20, hi=140)
print("nejcastejsi vzdalenosti (2. polovina):", tail_diffs)
REPORT["tiledata"]["tail_diffs"] = tail_diffs

print()
print("=" * 72)
print("HUES.MUL")
print("=" * 72)
hu = (UO / "hues.mul").read_bytes()
print(f"velikost: {len(hu)} B  (= {len(hu)/2} uint16, = {len(hu)/64} x 64B, = {len(hu)/88} x 88B)")
first = struct.unpack_from("<24H", hu, 0)
print("prvnich 24 uint16:", [hex(v) for v in first])
# hledej stride: kazda hue ma 32 barev; zkus 3000 heu
for count in (3000, 3008, 3017, 3088, 4148):
    if len(hu) % count == 0:
        print(f"  {count} heu -> {len(hu)//count} B/hue")
REPORT["hues"] = {"size": len(hu), "first24": [hex(v) for v in first]}

print()
print("=" * 72)
print("SKILLS / SKILLGRP")
print("=" * 72)
for fn in ("skills.mul", "skills.idx", "skillgrp.mul"):
    p = UO / fn
    if p.exists():
        b = p.read_bytes()
        strings = find_strings(b, min_len=2, max_len=40)
        print(f"{fn}: {len(b)} B, retezcu={len(strings)}, prvni={[s for _, s in strings[:12]]}")
        REPORT.setdefault("skills", {})[fn] = {
            "size": len(b),
            "strings": [s for _, s in strings[:80]],
        }

print()
print("=" * 72)
print("ANIM.IDX / ANIM.MUL / ANIMINFO / MULTI")
print("=" * 72)
for fn, rec in (("anim.idx", 12), ("anim.mul", 0), ("anim2.mul", 0), ("animinfo.mul", 0),
                ("animdata.mul", 0), ("multi.idx", 12), ("multi.mul", 0),
                ("radarcol.mul", 2), ("texidx.mul", 12)):
    p = UO / fn
    if p.exists():
        sz = p.stat().st_size
        extra = f"  -> {sz//rec} zaznamu po {rec} B" if rec and sz % rec == 0 else ""
        print(f"{fn:16} {sz:>12} B{extra}")
        REPORT.setdefault("sizes", {})[fn] = sz
if (UO / "anim.idx").exists():
    ai = (UO / "anim.idx").read_bytes()
    print("anim.idx prvnich 6 zaznamu (offset, delka, unknown):")
    for i in range(6):
        print("   ", struct.unpack_from("<iii", ai, i * 12))

print()
print("=" * 72)
print("UOP KONTEJNERY (hlavicky)")
print("=" * 72)
uops = ["artLegacyMUL.uop", "gumpartLegacyMUL.uop", "map0LegacyMUL.uop",
        "soundLegacyMUL.uop", "AnimationFrame1.uop", "AnimationSequence.uop",
        "MultiCollection.uop", "tileart.uop", "MainMisc.uop", "string_dictionary.uop"]
for fn in uops:
    p = UO / fn
    if not p.exists():
        continue
    with p.open("rb") as fh:
        head = fh.read(64)
    magic = head[:4]
    ver, = struct.unpack_from("<I", head, 4)
    fields = struct.unpack_from("<8I", head, 8)
    print(f"{fn:26} magic={magic!r} ver={ver} pole={fields} size={p.stat().st_size}")
    REPORT.setdefault("uop", {})[fn] = {
        "magic": magic.decode("latin1"), "version": ver, "fields": list(fields),
        "size": p.stat().st_size,
    }

print()
print("=" * 72)
print("CLILOC.ENU")
print("=" * 72)
cl = (UO / "Cliloc.enu").read_bytes()
print(f"velikost: {len(cl)} B")
pos = 0
entries = []
while pos + 7 <= len(cl) and len(entries) < 6:
    num, flag, length = struct.unpack_from("<IiH", cl, pos)
    s = cl[pos + 6:pos + 6 + length]
    entries.append((num, flag, length, s.decode("utf-16-le", "replace")[:80]))
    pos += 6 + length
for e in entries:
    print("   ", e)
REPORT["cliloc"] = {"size": len(cl), "first": entries}

(OUT / "probe-uo.json").write_text(json.dumps(REPORT, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nJSON: {OUT / 'probe-uo.json'}")
