"""Sesta sonda: mapa sekci tiledata.mul.

Dve skupiny jmen vysly na RUZNYCH fazich mod 41 ('stone stairs' faze 36,
'anvil' faze 2). To znamena, ze soubor neni jedna mrizka - bud ma vic sekci,
nebo jiny zaznam nez 41 B. Tahle sonda to rozresi mapou hustoty.
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
OUT = Path(r"E:\Workspaces\game-clone\research")
PRINTABLE = set(range(32, 127))
R = {}
td = (UO / "tiledata.mul").read_bytes()


def strings(data, min_len=3, max_len=40):
    out, n, i = [], len(data), 0
    while i < n:
        if data[i] in PRINTABLE:
            j = i
            while j < n and data[j] in PRINTABLE and (j - i) < max_len:
                j += 1
            if data[j:j + 1] == b"\x00" and (j - i) >= min_len:
                out.append((i, data[i:j].decode("latin1")))
                i = j + 1
                continue
            i = j
        else:
            i += 1
    return out


S = strings(td)
print(f"retezcu celkem: {len(S)}")
R["strings_total"] = len(S)

print("\n-- faze mod 41 po 200kB oknech (jen faze s >=5 nahlezy) --")
rows = []
for start in range(0, len(td), 200000):
    end = min(start + 200000, len(td))
    grp = [(o, s) for o, s in S if start <= o < end]
    c = Counter(o % 41 for o, _ in grp)
    top = [(r, n) for r, n in c.most_common(3) if n >= 5]
    rows.append((start, end, len(grp), top))
    print(f"   {start:>9}-{end:>9}  retezcu={len(grp):5}  top faze mod 41: {top}")
R["phase_map_41"] = rows

print("\n-- faze mod 30 po 200kB oknech --")
rows30 = []
for start in range(0, len(td), 200000):
    end = min(start + 200000, len(td))
    grp = [(o, s) for o, s in S if start <= o < end]
    c = Counter(o % 30 for o, _ in grp)
    top = [(r, n) for r, n in c.most_common(3) if n >= 5]
    rows30.append((start, end, len(grp), top))
    print(f"   {start:>9}-{end:>9}  retezcu={len(grp):5}  top faze mod 30: {top}")
R["phase_map_30"] = rows30

print("\n-- kde konci land blok? hleda se, kde prestanou byt jmena land dlazdic --")
LAND = ["grass", "water", "furrows", "NODRAW", "VOID!!!!!!", "rock", "sand", "dirt",
        "snow", "jungle", "cave", "lava", "swamp", "forest"]
for name in ("grass", "water", "sand", "rock", "lava"):
    offs = [o for o, s in S if s == name]
    if offs:
        print(f"   {name:8} vyskytu={len(offs):5} prvni={offs[0]:9} posledni={offs[-1]:9}")

print("\n-- hledani souvisle mrizky 41 B: pro kazdou fazi nejdelsi usek cistych jmen --")


def clean_at(off, n=20):
    ch = td[off:off + n]
    if len(ch) < n or ch[0] not in PRINTABLE:
        return None
    k = ch.find(b"\x00")
    if k < 0:
        return ch.decode("latin1")
    if k == 0 or any(c != 0 for c in ch[k:]):
        return None
    return ch[:k].decode("latin1")


best = []
for stride in (30, 41, 44, 45, 46, 48):
    for phase in range(stride):
        run = 0
        maxrun = 0
        maxstart = 0
        first = phase
        off = first
        while off + 20 <= len(td):
            if clean_at(off):
                run += 1
                if run > maxrun:
                    maxrun = run
                    maxstart = off - (run - 1) * stride
            else:
                run = 0
            off += stride
        if maxrun >= 20:
            best.append((maxrun, stride, phase, maxstart))
best.sort(reverse=True)
for maxrun, stride, phase, maxstart in best[:12]:
    print(f"   stride={stride:3} faze={phase:3} nejdelsi usek={maxrun:5} zacatek={maxstart}")

# --- detail: co je na zacatku nejlepsiho useku ---
if best:
    maxrun, stride, phase, maxstart = best[0]
    print(f"\n-> stride={stride}, faze={phase}, usek {maxrun} jmen od {maxstart}")
    R["best_run"] = {"stride": stride, "phase": phase, "run": maxrun, "start": maxstart}
    names = []
    for k in range(min(maxrun, 40)):
        off = maxstart + k * stride
        nm = clean_at(off)
        names.append((off, nm, td[max(0, off - (stride - 20)):off].hex(" ")))
    for off, nm, pre in names[:20]:
        print(f"   {off:>9} {nm!r:22} pole pred: {pre}")

(OUT / "probe-uo-6.json").write_text(json.dumps(R, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nJSON: {OUT / 'probe-uo-6.json'}")
