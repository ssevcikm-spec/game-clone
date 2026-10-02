import struct, os, zlib
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop", "tileart.uop", "gumpartLegacyMUL.uop", "AnimationFrame1.uop",
         "AnimationSequence.uop", "MultiCollection.uop", "MainMisc.uop", "string_dictionary.uop"]


def walk(p, start, maxblocks=100000):
    size = os.path.getsize(p)
    entries, blocks = {}, []
    off = start
    with open(p, "rb") as f:
        while off:
            if off + 12 > size:
                return None, f"block header {off} past EOF {size}"
            f.seek(off)
            cnt, nxt = struct.unpack("<iQ", f.read(12))
            blocks.append((off, cnt, nxt))
            if cnt < 0 or cnt > 5_000_000:
                return None, f"absurd count {cnt} at {off}"
            need = 34 * cnt
            if off + 12 + need > size:
                return None, f"entries at {off} need {need} B, past EOF"
            buf = f.read(need)
            if len(buf) < need:
                return None, f"short read at {off}"
            for i in range(cnt):
                o, hlen, clen, dlen, h, dh, flag = struct.unpack_from("<QiIIQIh", buf, 34 * i)
                if o == 0:
                    continue
                entries[h] = dict(off=o + hlen, hlen=hlen, clen=clen, dlen=dlen, flag=flag, hash=h)
            if len(blocks) > maxblocks:
                return None, "too many blocks"
            off = nxt
    return (entries, blocks), None


for fn in NAMES:
    p = os.path.join(UODIR, fn)
    with open(p, "rb") as f:
        h = f.read(40)
    cap = struct.unpack_from("<I", h, 12)[0]
    fcount = struct.unpack_from("<I", h, 24)[0]
    cnt28 = struct.unpack_from("<I", h, 28)[0]
    print("=" * 108)
    print(f"{fn}: hashCap={cap} u32@24={fcount} u32@28={cnt28} hashTable=[32,{32+16*cap})")
    for start in (100, 1000):
        res, err = walk(p, start)
        if err:
            print(f"  start={start:<6} FAILED: {err}")
        else:
            entries, blocks = res
            ok = 0
            sample = None
            for hh, e in list(entries.items())[:400]:
                if e["off"] + e["clen"] > os.path.getsize(p):
                    continue
                try:
                    with open(p, "rb") as f:
                        f.seek(e["off"])
                        raw = f.read(e["clen"])
                    dat = zlib.decompress(raw) if e["flag"] == 1 else raw
                    ok += 1
                    if sample is None:
                        sample = (e, dat)
                except Exception:
                    pass
            print(f"  start={start:<6} OK: entries={len(entries)} blocks={len(blocks)} "
                  f"validInflations={ok}/400  bytes={os.path.getsize(p)}")
            if sample:
                e, dat = sample
                print(f"       off={e['off']} clen={e['clen']} dlen={e['dlen']} flag={e['flag']} "
                      f"inflated={len(dat)} first24={dat[:24].hex(' ')}")
                if dat[:1] in (b"\x00",):
                    pass
