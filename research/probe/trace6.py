import struct, os, zlib
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop", "tileart.uop", "gumpartLegacyMUL.uop", "AnimationFrame1.uop",
         "AnimationSequence.uop", "MultiCollection.uop", "MainMisc.uop", "string_dictionary.uop"]
TSIZE = os.path.getsize


def try_chain(p, start, budget=4000000):
    """Walk a block chain; return (nblocks, nentries) if it looks sane."""
    size = TSIZE(p)
    off, blocks, entries = start, 0, 0
    with open(p, "rb") as f:
        while off and blocks < 64 and entries < budget:
            if off + 12 > size:
                return None
            f.seek(off)
            cnt, nxt = struct.unpack("<iQ", f.read(12))
            if cnt <= 0 or cnt > 400000:
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
                if flag not in (0, 1, 3):
                    return None
                if dlen > 40_000_000 or clen > 40_000_000:
                    return None
                if o + hlen + clen > size:
                    return None
                got += 1
            entries += got
            blocks += 1
            off = nxt
    if entries == 0:
        return None
    return blocks, entries


for fn in NAMES:
    p = os.path.join(UODIR, fn)
    size = TSIZE(p)
    hits = []
    for start in range(32, 4096):
        r = try_chain(p, start)
        if r:
            hits.append((start, r))
    print(f"{fn:<26} size={size:<10} block-chain candidates: {hits[:8]}")
