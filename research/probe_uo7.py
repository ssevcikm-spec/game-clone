"""Sonda 7: Cliloc.enu - najdi layout sebekontrolou (cisla musi rust, texty byt citelne)."""
import json
import struct
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
OUT = Path(r"E:\Workspaces\game-clone\research")
cl = (UO / "Cliloc.enu").read_bytes()
R = {"size": len(cl), "first32": cl[:32].hex(" ")}

print(f"Cliloc.enu: {len(cl)} B")
print("prvnich 32 B:", cl[:32].hex(" "))


def score_at(pos, hdr, len_in_bytes, count=6):
    """Zkusi precti 'count' entry od pozice pos a vrati skore (0 = nesedi)."""
    nums, texts, ok = [], [], 0
    for _ in range(count):
        if pos + hdr > len(cl):
            return 0, [], []
        num, = struct.unpack_from("<i", cl, pos)
        flag = cl[pos + 4]
        ln, = struct.unpack_from("<H", cl, pos + 5)
        if flag > 8 or ln == 0 or ln > 4000:
            return 0, [], []
        nb = ln if len_in_bytes else ln * 2
        raw = cl[pos + hdr:pos + hdr + nb]
        if len(raw) < nb:
            return 0, [], []
        try:
            txt = raw.decode("utf-16-le")
        except Exception:
            return 0, [], []
        printable = sum(1 for c in txt if 32 <= ord(c) < 127)
        if printable < len(txt) * 0.85:
            return 0, [], []
        nums.append(num)
        texts.append(txt[:50])
        pos += hdr + nb
        ok += 1
    # cisla musi rust
    if any(b <= a for a, b in zip(nums, nums[1:])):
        return 0, [], []
    return ok, nums, texts


print("\nhledam prvni offset, kde layout sedi (hlavicka 6 B, delka v bajtech):")
best = None
for start in range(0, 6000):
    for hdr, lib in ((6, True), (6, False), (7, True), (7, False)):
        s, nums, texts = score_at(start, hdr, lib)
        if s >= 6:
            best = (start, hdr, lib, nums, texts)
            break
    if best:
        break
if best:
    start, hdr, lib, nums, texts = best
    print(f"-> layout sedi od offsetu {start}: hlavicka {hdr} B, delka v {'bajtech' if lib else 'znacich'}")
    for n, t in zip(nums, texts):
        print(f"     {n:>8}  {t!r}")
    R["cliloc_layout"] = {"start": start, "header": hdr, "len_in_bytes": lib, "sample": list(zip(nums, texts))}
    # spocitej vsechny entry
    pos, count, last = start, 0, None
    while pos + hdr <= len(cl):
        num, = struct.unpack_from("<i", cl, pos)
        ln, = struct.unpack_from("<H", cl, pos + 5)
        nb = ln if lib else ln * 2
        if ln == 0 or pos + hdr + nb > len(cl):
            break
        pos += hdr + nb
        count += 1
        last = num
    print(f"   entry celkem: {count}, posledni cislo: {last}, zbytek: {len(cl)-pos} B")
    R["cliloc_count"] = {"entries": count, "last": last, "rest": len(cl) - pos}
else:
    print("-> layout nenalezen v prvnich 6000 B (soubor ma zrejme jiny format)")
    R["cliloc_layout"] = None

(OUT / "probe-uo-7.json").write_text(json.dumps(R, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"JSON: {OUT / 'probe-uo-7.json'}")
