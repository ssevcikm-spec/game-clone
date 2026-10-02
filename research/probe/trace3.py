import struct, os
for fn in ("tileart.uop", "AnimationSequence.uop", "MainMisc.uop", "MultiCollection.uop", "artLegacyMUL.uop"):
    p = os.path.join(r"D:\Games\Electronic Arts\Ultima Online Classic", fn)
    size = os.path.getsize(p)
    print("=" * 90)
    print(fn, "size", size)
    for start in (1000, 100):
        with open(p, "rb") as f:
            f.seek(start)
            d = f.read(80)
        print(f"  @{start}: {d[:56].hex(' ')}")
        print(f"     I@{start}+0 = {struct.unpack_from('<I', d, 0)[0]}")
        print(f"     I@{start}+4 = {struct.unpack_from('<I', d, 4)[0]}")
        print(f"     Q@{start}+0 = {struct.unpack_from('<Q', d, 0)[0]}")
        print(f"     Q@{start}+4 = {struct.unpack_from('<Q', d, 4)[0]}")
        # interpret as count=int32,next=int64  vs  next=int64,count=int32
        a = struct.unpack_from("<iQ", d, 0)
        b = struct.unpack_from("<Qi", d, 0)
        print(f"     (count,next)=<iQ> -> {a}   (next,count)=<Qi> -> {b}")
        break
