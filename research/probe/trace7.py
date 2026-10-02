import struct, os, zlib
p = r"D:\Games\Electronic Arts\Ultima Online Classic\artLegacyMUL.uop"
size = os.path.getsize(p)
print("size", size)
with open(p, "rb") as f:
    d = f.read(0x600)

print("hdr u32 fields:")
for i in range(0, 48, 4):
    print(f"  +{i:<3} {struct.unpack_from('<I', d, i)[0]}")
print("u64@16 =", struct.unpack_from("<Q", d, 16)[0])
print("u64@20 =", struct.unpack_from("<Q", d, 20)[0])

# is there a chain anywhere in the first 4 MB?
def try_chain(start):
    off, blocks, entries = start, 0, 0
    with open(p, "rb") as f:
        while off and blocks < 200:
            if off + 12 > size:
                return None
            f.seek(off)
            cnt, nxt = struct.unpack("<iQ", f.read(12))
            if cnt <= 0 or cnt > 500000:
                return None
            need = 34 * cnt
            if off + 12 + need > size:
                return None
            f.seek(off + 12)
            buf = f.read(need)
            if len(buf) < need:
                return None
            got = 0
            for i in range(cnt):
                o, hlen, clen, dlen, h, dh, flag = struct.unpack_from("<QiIIQIh", buf, 34 * i)
                if o == 0:
                    continue
                if flag not in (0, 1, 3) or clen > 40_000_000 or dlen > 40_000_000 or o + hlen + clen > size:
                    return None
                got += 1
            entries += got
            blocks += 1
            off = nxt
    return (blocks, entries) if entries else None

hits = [(s, try_chain(s)) for s in range(32, 200000)]
hits = [(s, r) for s, r in hits if r]
print("chain candidates in first 200000 bytes:", hits[:10])

# hash table: what do slots look like?
print("\nhash table slots (32 + i*16) for i in 0..7:")
for i in range(8):
    o = 32 + i * 16
    a, b = struct.unpack_from("<QQ", d, o)
    print(f"  slot[{i}] @{o}: a={a:<22} b={b}")
print("\nfirst non-zero 32-bit words in hash table region [32,132288):")
with open(p, "rb") as f:
    f.seek(32)
    ht = f.read(132288 - 32)
nz = [(i, struct.unpack_from("<I", ht, i)[0]) for i in range(0, len(ht), 4) if struct.unpack_from("<I", ht, i)[0] != 0]
print(f"  nonzero count={len(nz)}  first 10={nz[:10]}")
