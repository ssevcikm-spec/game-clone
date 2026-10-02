import struct, os
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
for fn in ("artLegacyMUL.uop", "gumpartLegacyMUL.uop", "MultiCollection.uop", "AnimationSequence.uop"):
    p = os.path.join(UODIR, fn)
    with open(p, "rb") as f:
        d = f.read(0x600)
    print("=" * 100)
    print(fn, "size", os.path.getsize(p))
    print("first 96 bytes:", d[:96].hex(" "))
    print()
    for off in range(0, 40, 2):
        u32 = struct.unpack_from("<I", d, off)[0]
        u64 = struct.unpack_from("<Q", d, off)[0]
        print(f"  off {off:3d}: {d[off:off+8].hex(' ')}  u32={u32:<12} u64={u64}")
    print()
