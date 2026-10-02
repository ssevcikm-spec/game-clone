"""Sonda 8: rozhodnuti sporu o tiledata.mul.

research/05 tvrdi:  land = 0x4000 x 34 B od 0, item = 0x4000 x 41 B od 557 056,
                    zbytek [1 228 800, 3 188 736) = 1 959 936 B nevysvetleno.
moje sondy (probe4-6) namerily: jmena ve shlucich s krokem 41 B, ale RUZNE
                    FAZE (leather od 525 227, stone stairs od 534 963,
                    anvil 658 708) - coz jednolite mrizce odporuje.

Tahle sonda obe tvrzeni testuje na bajtech a rozhodne:
  A) land: stride 34, jmeno na +9  -> podil citelnych jmen
  B) item: base 557 056, vsechny faze 0..40 -> nejlepsi cista jmena
  C) co je ve zbytku [1 228 800, 3 188 736)
  D) kde presne lezi 'katana', 'anvil', 'leather gloves' a zda to sedi
"""
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
td = (UO / "tiledata.mul").read_bytes()
PRINT = set(range(32, 127))


def name_at(off, n=20):
    ch = td[off:off + n]
    if len(ch) < n or ch[0] not in PRINT:
        return None
    k = ch.find(b"\x00")
    if k < 0:
        return ch.decode("latin1")
    if k == 0 or any(c != 0 for c in ch[k:]):
        return None
    return ch[:k].decode("latin1")


print("=" * 74)
print("A) LAND: stride 34, jmeno na +9 (tvrzeni research/05)")
print("=" * 74)
for noff in (6, 9, 10, 14, 17):
    ok = sum(1 for r in range(0x4000) if name_at(34 * r + noff))
    print(f"   jmeno na +{noff:2}: citelnych {ok:6}/16384 = {ok/16384:.1%}")
land_names = {}
for r in range(0x4000):
    nm = name_at(34 * r + 9)
    if nm:
        land_names[r] = nm
print("   vzorek (id: jmeno):", {hex(k): land_names[k] for k in list(land_names)[:6]})
for probe_id in (0, 1, 2, 3, 4, 5, 6):
    print(f"     land 0x{probe_id:04X} = {land_names.get(probe_id)!r}")

print()
print("=" * 74)
print("B) ITEM: base 557 056, stride 41, hleda se nejlepsi faze")
print("=" * 74)
best = []
for noff in range(0, 41):
    ok = sum(1 for k in range(4000) if name_at(557056 + k * 41 + noff))
    best.append((ok, noff))
best.sort(reverse=True)
print("   top faze (cistych z 4000):", best[:5])
noff = best[0][1]
items = {}
for k in range(0x4000):
    nm = name_at(557056 + k * 41 + noff)
    if nm:
        items[k] = nm
print(f"   pri fazi +{noff}: {len(items)} pojmenovanych item recordu z 0x4000")
print("   vzorek:", {hex(k): items[k] for k in list(items)[:6]})
for tid in (0x0F52, 0x13FE, 0x0F5E, 0x0F62):
    print(f"     item 0x{tid:04X} = {items.get(tid)!r}")

print()
print("=" * 74)
print("C) ZBYTEK [1 228 800, 3 188 736)")
print("=" * 74)
tail = len(td) - 1228800
print(f"   velikost: {tail} B")
for stride in (41, 34, 37, 26, 88, 100, 2, 4):
    if tail % stride == 0:
        print(f"     delitelne {stride} -> {tail // stride} zaznamu")
# jsou tam jmena?
strings = [(m.start() + 1228800, m.group().decode("latin1"))
           for m in re.finditer(rb"[ -~]{4,}\x00", td[1228800:])][:12]
print(f"   retezcu v zbytku (prvnich 12): {[(hex(o), s) for o, s in strings]}")
# pokracuje mrizka 41 dal?
for noff2 in (best[0][1],):
    ok = sum(1 for k in range(0x4000, 0x8000) if name_at(557056 + k * 41 + noff2))
    print(f"   item records 0x4000..0x8000 (coz je {557056+0x4000*41}..{557056+0x8000*41}): citelnych {ok}/16384")

print()
print("=" * 74)
print("D) KONTROLA: kde lezi zname retezce a sedi s modelem?")
print("=" * 74)
for needle in (b"anvil", b"katana", b"leather gloves", b"black pearl", b"nightshade",
               b"bandage", b"backpack", b"stone stairs", b"leather", b"grass"):
    offs = [m.start() for m in re.finditer(re.escape(needle), td)][:4]
    info = []
    for o in offs:
        land_rec = o - 9
        item_rec = o - noff
        fits_land = land_rec >= 0 and land_rec % 34 == 0 and land_rec < 557056
        fits_item = item_rec >= 557056 and (item_rec - 557056) % 41 == 0
        info.append((o, "LAND" if fits_land else ("ITEM" if fits_item else "mimo")))
    print(f"   {needle.decode():16} {info}")
