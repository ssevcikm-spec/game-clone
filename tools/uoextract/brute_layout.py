"""
Systematic layout search for tiledata.mul ITEM records.

Established facts (measured):
  * offset 0..15364 : 512 groups x (u32 header + 32 land records of 26 bytes)
                      [4B flags][u16 texid][20B name]   <- verified by hand
  * 'stone stairs' appears 6x with exact stride 41 at 534964, 535005, 535046, 535087,
    535128, 535169  -> RECORD STRIDE IS 41 BYTES in that region.
  * ClassicUO TileDataLoader (BSD-2-Clause) reads item records as
      [flags 4 or 8][weight u8][layer u8][count i32][animID u16][hue u16]
      [lightIndex u16][height u8][name 20]  = 37 (old) / 41 (new) bytes.

So: for the 41-byte/new variant the only unknown is the ORDER of the 13 bytes
between the flags and the 20-byte name.  13 bytes = 3 spare, and the natural
grouping is [weight u8][layer u8][count i32][animID u16][hue u16][light u16]
[height u8].  This script brute-forces which placement is self-consistent.
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

STRIDE = 41
# The 6 measured 'stone stairs' name offsets; record starts are these minus nameoff.
SS = [534964, 535005, 535046, 535087, 535128, 535169]
print("stone stairs offsets:", SS)
print("stride check:", [SS[i+1]-SS[i] for i in range(5)])


def scan(nameoff, flaglen, namelen=20, stride=41):
    """From the anchor 534964, tile record starts at (534964 - nameoff) + k*stride.
    Score by count of records whose name is clean printable ASCII."""
    start = SS[0] - nameoff
    clean = none = 0
    names = []
    k = 0
    while True:
        b = start + k*stride
        if b < 0 or b + stride > N: break
        raw = data[b + nameoff: b + nameoff + namelen]
        z = raw.find(b'\0')
        nm = raw[:z if z >= 0 else namelen]
        if len(nm) and all(0x20 <= c < 0x7f for c in nm):
            clean += 1
            if len(names) < 3: names.append((k, b, nm.decode()))
        else:
            none += 1
        k += 1
    return clean, none, names, start

print("\n=== which (flaglen, nameoff) makes the 41-byte grid self-consistent? ===")
print("%-8s %-6s %-10s %s" % ("nameoff", "flag", "start", "clean/none"))
best = []
for flaglen in (4, 8):
    for nameoff in range(flaglen+2, stride-1):
        c, n, nms, start = scan(nameoff, flaglen)
        best.append((c, flaglen, nameoff, start, n))
best.sort(reverse=True)
for c, flaglen, nameoff, start, n in best[:12]:
    print("  clean=%7d flag=%d nameoff=%2d start=%d none=%d" % (c, flaglen, nameoff, start, n))
