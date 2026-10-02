import struct, sys
print("python", sys.version)
hdr = bytes.fromhex("4d594d500400000043ec23fd2800000000000000640000002e9f0000000000000000000000000000"[:80])
# rebuild precisely from the real hex string seen
real = "4d 59 50 00 04 00 00 00 43 ec 23 fd 28 00 00 00 00 00 00 00 64 00 00 00 2e 9f 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
h = bytes.fromhex(real.replace(" ", ""))
print("len", len(h))
for off in (12, 16, 20, 24, 28):
    print(f"  I@{off} = {struct.unpack_from('<I', h, off)[0]:<22} raw = {h[off:off+4].hex(' ')}")
    print(f"  Q@{off} = {struct.unpack_from('<Q', h, off)[0]:<22} raw = {h[off:off+8].hex(' ')}")
print()
manual = 0
for i, b in enumerate(h[20:28]):
    manual |= b << (8 * i)
print("manual LE u64 @20 =", manual)
print("struct LE u64 @20 =", struct.unpack_from("<Q", h, 20)[0])
print("struct Q (native) @20 =", struct.unpack_from("Q", h, 20)[0])
print("struct <q @20 =", struct.unpack_from("<q", h, 20)[0])
