import struct, os, zlib

p = r"D:\Games\Electronic Arts\Ultima Online Classic\tileart.uop"
size = os.path.getsize(p)
print("size", size)

# exact bytes at the header
with open(p, "rb") as f:
    hdr = f.read(40)
print("hdr[0:40] =", hdr.hex(" "))
for off in (20, 21, 22, 24, 28, 32):
    print(f"  Q@{off} = {struct.unpack_from('<Q', hdr, off)[0]:<25} "
          f"I@{off} = {struct.unpack_from('<I', hdr, off)[0]}")

blockoff = struct.unpack_from("<Q", hdr, 20)[0]
print("blockoff =", blockoff, "-> fits in file:", blockoff < size)

with open(p, "rb") as f:
    f.seek(blockoff)
    bh = f.read(12)
    print("block header bytes:", bh.hex(" "), "len", len(bh))
    cnt, nxt = struct.unpack("<iQ", bh)
    print("  filesCount =", cnt, " nextBlock =", nxt)
    recs = f.read(34 * min(cnt, 4))
    for i in range(min(cnt, 4)):
        t = struct.unpack_from("<QiIIQIh", recs, 34 * i)
        print(f"  rec[{i}] off={t[0]} hlen={t[1]} clen={t[2]} dlen={t[3]} "
              f"hash={t[4]:#018x} dhash={t[5]:#010x} flag={t[6]}")
