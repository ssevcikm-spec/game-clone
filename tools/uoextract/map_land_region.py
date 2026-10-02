"""Precise boundary mapping of the FIRST 512-record (land) region of tiledata.mul."""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()

# Walk from offset 0: hypothesis LAND record = [u32 flags][u16 id][20 byte name] = 26 bytes?
# and note the string offsets we already measured:
#   UNUSED @10, VOID @44, NODRAW @74, grass @104,134,164,194, furrows @284,...
# If name begins at rec+10 for some layout and rec+4 for another, the two differ.
# Measured first-block name offsets:
known = [10, 44, 74, 104, 134, 164, 194, 284, 314, 344, 374, 404, 434, 464, 494, 524, 554, 584, 614, 644]
print("first-block name offsets:")
for i, o in enumerate(known):
    d = known[i] - known[i-1] if i else None
    print("  idx %2d off %4d  prev-delta %s" % (i, o, d))

print("\nDeltas sequence:", [known[i]-known[i-1] for i in range(1, len(known))])

# Look for 20-byte names that are NOT the first string in their record (records with empty name).
# Full raw window 0..0x140
print("\nRAW 0x0000-0x0140:")
for off in range(0, 0x140, 16):
    print("  %04x  %-47s |%s|" % (off,
          " ".join("%02x" % b for b in data[off:off+16]),
          "".join(chr(b) if 0x20 <= b < 0x7f else "." for b in data[off:off+16])))

# Hypothesis H1: land record = 30 bytes total: [u32 flags][u16 id][20 name][4 pad]? no.
# Hypothesis H2: land record = 26 bytes: [u32 flags][u16 id][20 name], start offset 4.
for start in (0, 2, 4):
    for stride in (26, 28, 30):
        good = 0
        for i in range(512):
            b = start + i*stride
            if b+26 > len(data): good = -1; break
            raw = data[b+6:b+26]
            z = raw.find(b'\0')
            nm = raw[:z if z >= 0 else 20]
            if len(nm) > 0 and all(0x20 <= c < 0x7f for c in nm):
                good += 1
        print("start=%d stride=%d -> clean %s/512" % (start, stride, good))
