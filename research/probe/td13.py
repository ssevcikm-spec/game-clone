import os, sys, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)

# Search for a distinctive item name and print a wide window so the repeating
# record structure is visible with absolute offsets.
def window(needle, before=60, after=140):
    i = d.find(needle)
    print(f"\n===== {needle!r} @ {i} =====")
    base = i - before
    for off in range(base, min(i + after, n), 41):
        chunk = d[off:off + 41]
        txt = "".join(chr(c) if 32 <= c < 127 else "." for c in chunk)
        print(f"  {off:8} (+{off - base:4}): {chunk.hex(' ')}  |{txt}|")

window(b"pickaxe")
window(b"blacksmith")
window(b"katana")

# Also: is 41 really the stride for ALL items, or only some? measure over a big range
import collections
offs = []
i = 0
while True:
    i = d.find(b"pickaxe", i)
    if i < 0:
        break
    offs.append(i)
    i += 1
print("\npickaxe offsets:", offs)
print("diffs:", [offs[k+1]-offs[k] for k in range(len(offs)-1)])
