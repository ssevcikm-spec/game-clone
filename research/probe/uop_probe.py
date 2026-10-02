"""Probe UOP (Mythic Package) containers in a UO Classic install.

Prints: header fields, hash-table stats, entry-record stats (compression flags,
entry lengths), so the documented layout can be checked against real bytes.
"""
import struct
import sys
import os
import zlib

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"

MAGIC = b"MYP\0"


def probe(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        head = f.read(28)
    magic, ver, fmt, misc, bcount, ncount = struct.unpack("<4sIBBII", head[:18])
    print(f"  header bytes: {head[:18].hex(' ')}")
    print(f"\n===== {os.path.basename(path)}  ({size} bytes)")
    print(f"  magic   = {magic!r}   version={ver}   fmt=0x{fmt:02X}   misc=0x{misc:08X}")
    print(f"  dataStart(after 28-byte header) = 28")
    print(f"  blockCount?={bcount}  fileCount?={ncount}")
    # hash table starts at 28, 16 bytes per slot
    hs = 28
    ts = 28 + bcount * 16

    # first slot
    with open(path, "rb") as f:
        f.seek(28)
        first = struct.unpack("<QQ", f.read(16))
        f.seek(28 + (bcount - 1) * 16)
        last = struct.unpack("<QQ", f.read(16))
    print(f"  hash table: offset 28, {bcount} slots x 16 B, ends at {ts}")
    print(f"    slot[0]      = {first[0]}, {first[1]}")
    print(f"    slot[{bcount-1}] = {last[0]}, {last[1]}")
    print(f"  (file length {size}; remainder after hash table = {size - ts})")
    print(f"  (file length mod (bcount*16) = {size % (bcount * 16)})")

    # walk the first block's chain if it is a valid file offset
    if 0 < first[1] < size:
        with open(path, "rb") as f:
            f.seek(first[1])
            blk = f.read(24)
            off, nxt, cnt = struct.unpack("<QII", blk[:16])
            print(f"    first block @ {first[1]}: next={nxt} count={cnt}")

    # Enumerate entries by scanning all hash slots' chains.
    entries = []
    seen_blocks = set()
    with open(path, "rb") as f:
        for i in range(bcount):
            f.seek(28 + i * 16 + 8)
            b = f.read(8)
            if len(b) < 8:
                break
            off = struct.unpack("<Q", b)[0]
            while off and off not in seen_blocks and off + 24 <= size:
                seen_blocks.add(off)
                f.seek(off)
                blk = f.read(24)
                if len(blk) < 24:
                    break
                _off, nxt, cnt = struct.unpack("<QII", blk[:16])
                if cnt > 100000:
                    break
                f.seek(off + 24)
                for _ in range(cnt):
                    rec = f.read(34)
                    if len(rec) < 34:
                        break
                    (eoff, ehdr, elen, ecomp, edecomp, ehash, eadler) = struct.unpack(
                        "<QIHHII", rec[:24]
                    )
                    entries.append(
                        dict(
                            off=eoff,
                            hdr=ehdr,
                            clen=elen,
                            comp=ecomp,
                            decomp=edecomp,
                            hash=ehash,
                            adler=eadler,
                            raw=rec,
                        )
                    )
                off = nxt

    print(f"  enumerated entries: {len(entries)}  (unique blocks: {len(seen_blocks)})")
    if entries:
        import collections

        c = collections.Counter(e["comp"] for e in entries)
        h = collections.Counter(e["hdr"] for e in entries)
        print(f"    compression flag values: {dict(c)}")
        print(f"    entry header word (offset 8) values: {dict(list(h.items())[:12])}")
        tot_d = sum(e["decomp"] for e in entries)
        tot_c = sum(e["clen"] for e in entries)
        print(f"    sum(compressed len)={tot_c}  sum(decompressed len)={tot_d}")
        print(f"    max decompressed entry = {max(e['decomp'] for e in entries)}")
        # show first few raw records
        for e in entries[:3]:
            print(f"    rec raw: {e['raw'].hex(' ')}")
        # check entry offsets are ascending
        offs = [e["off"] for e in entries]
        print(f"    offsets ascending? {offs == sorted(offs)}")
        # verify one entry by inflating
        for e in entries[:200]:
            if e["off"] + e["clen"] <= size and e["clen"] > 0:
                with open(path, "rb") as f:
                    f.seek(e["off"])
                    raw = f.read(e["clen"])
                if e["comp"]:
                    try:
                        out = zlib.decompress(raw)
                        print(
                            f"    inflate OK @ {e['off']}: {e['clen']} -> {len(out)} "
                            f"(declared {e['decomp']})"
                        )
                    except Exception as ex:
                        print(f"    inflate FAIL @ {e['off']}: {ex}")
                else:
                    print(f"    stored(uncompressed) @ {e['off']} len {e['clen']}")
                break
        # entry hash -> filename check for art
    return entries


def hash_from_name(name: str, seed: int) -> int:
    b = name.encode("ascii")
    eax = (seed + len(b)) & 0xFFFFFFFF
    ecx = 0
    edx = 0
    ebx = 0
    esi = 0
    for ch in b:
        edx = ch
        esi = (esi + edx) & 0xFFFFFFFF
        edx = (edx + esi * 0x100) & 0xFFFFFFFF
        esi = (esi + esi * 0x100) & 0xFFFFFFFF
        edx = (edx + edx * 0x10000) & 0xFFFFFFFF
        esi = (esi + esi * 0x10000) & 0xFFFFFFFF
    # the classic UO hash:
    edx = 0
    for ch in b:
        edx = (ch + 0x20 * edx) & 0xFFFFFFFF if False else edx
    return eax


if __name__ == "__main__":
    files = sys.argv[1:] or [
        "artLegacyMUL.uop",
        "gumpartLegacyMUL.uop",
        "tileart.uop",
        "AnimationFrame1.uop",
        "AnimationSequence.uop",
        "MultiCollection.uop",
        "MainMisc.uop",
        "string_dictionary.uop",
    ]
    for fn in files:
        p = os.path.join(UODIR, fn)
        if os.path.exists(p):
            try:
                probe(p)
            except Exception as ex:
                print(f"  ERROR {fn}: {ex!r}")
        else:
            print(f"  MISSING {fn}")
