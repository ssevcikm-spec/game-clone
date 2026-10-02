"""Find the true phase/structure of tiledata.mul by self-consistency, not guesswork."""
import os, struct, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
print("size", N)

# ---- Test A: land block hypothesis: 512 records of 30 bytes, flags u32, id u16, name[20]
def test_land(buf, off, count=512, stride=30, flagoff=0, flaglen=4, idoff=4, nameoff=6, namelen=20):
    good = 0; flags_nonzero = 0; names = []
    for i in range(count):
        b = off + i*stride
        if b + stride > len(buf): return None
        flags = int.from_bytes(buf[b+flagoff:b+flagoff+flaglen], 'little')
        tid = int.from_bytes(buf[b+idoff:b+idoff+2], 'little')
        raw = buf[b+nameoff:b+nameoff+namelen]
        z = raw.find(b'\0')
        nm = raw[:z if z >= 0 else namelen]
        ok = all(0x20 <= c < 0x7f for c in nm) and len(nm) > 0
        if ok: good += 1
        if flags: flags_nonzero += 1
        if i < 6 or i > 508: names.append((i, tid, flags, nm.decode('ascii', 'replace')))
    return good, flags_nonzero, names

print("\n=== Test A: land at offset 4, 512 * 30 ===")
r = test_land(data, 4)
print("clean names: %d/512, nonzero flags: %d" % (r[0], r[1]))
for t in r[2]: print("   ", t)
print("block ends at", 4 + 512*30)
print("bytes 0..3:", data[:4].hex())
print("next 64 bytes after land block:")
o = 4 + 512*30
for off in range(o, o+64, 16):
    print("  %08x  %s" % (off, " ".join("%02x" % b for b in data[off:off+16])))

# ---- Test B: item block hypothesis: 8-byte flags + id u16 + name[20] = 30? or flags 4 -> 26
def test_items(buf, off, count, stride, flaglen, namelen, label):
    b0 = off
    good = 0
    nn = []
    end = off + count*stride
    if end > len(buf):
        print(label, "OVERRUN"); return
    for i in range(count):
        b = b0 + i*stride
        flags = int.from_bytes(buf[b:b+flaglen], 'little')
        tid = int.from_bytes(buf[b+flaglen:b+flaglen+2], 'little')
        raw = buf[b+flaglen+2:b+flaglen+2+namelen]
        z = raw.find(b'\0')
        nm = raw[:z if z >= 0 else namelen]
        ok = len(nm) > 0 and all(0x20 <= c < 0x7f for c in nm)
        if ok: good += 1
        if i < 4: nn.append((i, tid, hex(flags), nm.decode('ascii','replace')))
    print("%s off=%d count=%d stride=%d -> clean %d/%d (%.1f%%) ends=%d" %
          (label, off, count, stride, good, count, 100.0*good/count, end))
    for t in nn: print("     ", t)

print("\n=== Test B candidates for item block after land ===")
for stride, flaglen, namelen in ((26,4,20),(30,8,20),(37,4,20),(41,8,20)):
    test_items(data, 4+512*30, 0x4000, stride, flaglen, namelen, "items flaglen=%d" % flaglen)
