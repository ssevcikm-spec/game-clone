"""Test whether the non-textual tail of tiledata.mul is compressed, and measure text extent."""
import os, zlib, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)

# 1. printability profile per 64 KB
print("=== bytes 0..0x8020 raw ===")
for off in range(0, 0x8020, 16):
    chunk = data[off:off+16]
    print("  %08x  %-47s |%s|" % (off,
        " ".join("%02x" % b for b in chunk),
        "".join(chr(b) if 0x20 <= b < 0x7f else "." for b in chunk)))

print("\n=== printability per 64KB block ===")
for b in range(0, N, 65536):
    chunk = data[b:b+65536]
    pr = sum(1 for c in chunk if 0x20 <= c < 0x7f)
    print("  %8d  printable %5.1f%%  first16=%s" % (b, 100.0*pr/len(chunk), chunk[:16].hex()))

# 2. zlib attempts at candidate offsets
print("\n=== zlib decompression attempts ===")
cands = [0x3c00, 0x3c04, 0x3c06, 0x3c08, 0x3c10, 0x4000, 0x8000, 0xC000, 0x10000,
         0x20000, 0x30000, 0x40000, 0x80000, 0x100000, 0x200000]
for off in cands:
    if off >= N: continue
    try:
        d = zlib.decompressobj()
        out = d.decompress(data[off:off+8*1024*1024])
        print("  off=0x%06x (%8d) magic=%s -> decompressed %d bytes, unused=%d" %
              (off, off, data[off:off+2].hex(), len(out), len(d.unused_data)))
    except Exception as e:
        print("  off=0x%06x (%8d) magic=%s -> FAIL %s" % (off, off, data[off:off+2].hex(), e))

# 3. Where do long runs of 0x00 live?
runs = []
i = 0
while i < N:
    if data[i] == 0:
        j = i
        while j < N and data[j] == 0:
            j += 1
        if j - i >= 64:
            runs.append((i, j - i))
        i = j
    else:
        i += 1
print("\n=== zero runs >=64 bytes: %d, total %d bytes ===" % (len(runs), sum(r[1] for r in runs)))
for o, l in runs[:20]:
    print("   %8d len %d" % (o, l))
print("   ... last:")
for o, l in runs[-10:]:
    print("   %8d len %d" % (o, l))
