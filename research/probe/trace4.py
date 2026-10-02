import struct, os
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop", "tileart.uop", "gumpartLegacyMUL.uop", "AnimationFrame1.uop",
         "AnimationFrame2.uop", "AnimationFrame3.uop", "AnimationFrame4.uop", "AnimationFrame6.uop",
         "AnimationSequence.uop", "MultiCollection.uop", "MainMisc.uop", "string_dictionary.uop"]
for fn in NAMES:
    p = os.path.join(UODIR, fn)
    size = os.path.getsize(p)
    with open(p, "rb") as f:
        d = f.read(64)
    cap = struct.unpack_from("<I", d, 12)[0]
    blockoff = struct.unpack_from("<I", d, 20)[0]
    cnt = struct.unpack_from("<I", d, 28)[0]
    bs = struct.unpack_from("<I", d, 32)[0]
    print("=" * 100)
    print(f"{fn}  size={size} ver={struct.unpack_from('<I', d, 4)[0]} hashCap={cap} "
          f"nextBlock(u32@20)={blockoff} count(u32@28)={cnt} u32@32={bs}")
    print(f"  bytes[32:64] = {d[32:64].hex(' ')}")
    for start in (blockoff,):
        if start == 0:
            print(f"  @{start}: nextBlock is 0 -> no block chain?!")
            continue
        with open(p, "rb") as f:
            f.seek(start)
            dd = f.read(48)
        c, n = struct.unpack_from("<iQ", dd, 0)
        walk_count = c * 34 + 12
        print(f"  @{start} [count={c} next={n}]: block bytes={walk_count} -> next should be @{start+walk_count}"
              f"  {'MATCH' if start + walk_count == n else 'MISMATCH'}")
        print(f"     raw48 = {dd[:48].hex(' ')}")
