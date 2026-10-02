"""Sonda 9: rozhodnuti mezi dvema modely tiledata.mul (item blok).

Model A (research/05, bez skupinovych hlavicek):
    land = 0x4000 zaznamu x 30 B od 0, item blok od 491 520, stride 41
Model B (extractor, se skupinovymi hlavickami):
    land = 512 skupin x (4 B + 32 x 30 B) od 4, item blok od 493 568,
    item = 2048 skupin x (4 B + 32 x 41 B)

Oba modely jsou arithmetic "presne"; rozhoduje jedine: na ktere mrizce
lezi CITELNA JMENA. Test meri podil cistych jmen pro vsechny faze.
"""
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
td = (UO / "tiledata.mul").read_bytes()
PRINT = set(range(32, 127))


def clean(off, n=20):
    ch = td[off:off + n]
    if len(ch) < n or ch[0] not in PRINT:
        return None
    k = ch.find(b"\x00")
    if k < 0:
        return ch.decode("latin1")
    if k == 0 or any(c != 0 for c in ch[k:]):
        return None
    return ch[:k].decode("latin1")


def score(model, base, count, name_off):
    """Podil cistych jmen na dane mrizce."""
    ok = 0
    named = 0
    for k in range(count):
        off = base(k) + name_off
        if off + 20 > len(td):
            break
        nm = clean(off)
        if nm:
            ok += 1
            named += 1
    return named, count


print("=" * 72)
print("MODEL A: bez hlavicek, item base 491 520, stride 41")
print("=" * 72)
bestA = []
for noff in range(0, 41):
    named, cnt = score(None, lambda k: 491520 + k * 41, 16384, noff)
    bestA.append((named, noff))
bestA.sort(reverse=True)
print("   top faze:", bestA[:5], f"-> {bestA[0][0]}/16384 = {bestA[0][0]/16384:.1%}")

print()
print("=" * 72)
print("MODEL B: skupinove hlavicky 4 B, item base 493 568")
print("=" * 72)
bestB = []
for noff in range(0, 41):
    named, cnt = score(None, lambda k: 493568 + (k // 32) * 4 + (k % 32) * 41, 16384, noff)
    bestB.append((named, noff))
bestB.sort(reverse=True)
print("   top faze:", bestB[:5], f"-> {bestB[0][0]}/16384 = {bestB[0][0]/16384:.1%}")

print()
print("=" * 72)
print("MODEL B rozsireny na 65 536 predmetu (cely zbytek souboru)")
print("=" * 72)
for noff in (bestB[0][1], 21):
    named, cnt = score(None, lambda k: 493568 + (k // 32) * 4 + (k % 32) * 41, 65536, noff)
    print(f"   noff={noff}: cistych {named}/{cnt} = {named/cnt:.1%}")

print()
print("=" * 72)
print("LAND: kontrolni identita obou modelu")
print("=" * 72)
for noff in (10, 6, 14):
    named, cnt = score(None, lambda k: k * 30, 16384, noff)
    print(f"   bez hlavicek, noff={noff}: {named}/16384 = {named/16384:.1%}")
for noff in (10, 6, 14):
    named, cnt = score(None, lambda k: 4 + (k // 32) * 4 + (k % 32) * 30, 16384, noff)
    print(f"   s hlavickami, noff={noff}: {named}/16384 = {named/16384:.1%}")

print()
print("=" * 72)
print("KDE lezi zname retezce a co z toho plyne")
print("=" * 72)
import re
for needle in (b"katana", b"anvil", b"backpack"):
    for m in list(re.finditer(re.escape(needle), td))[:2]:
        o = m.start()
        relA = (o - 491520)
        relB = (o - 493568)
        okA = relA % 41
        okB_off = relB
        # pro model B: 4*(k//32) + 41*(k%32) == relB - noff  ->  nutne (relB-noff) mod 4 == ...
        fitsB = [noff for noff in range(41)
                 if (relB - noff) >= 0 and any((relB - noff - 41 * r) % 4 == 0 and
                                               (relB - noff - 41 * r) // 4 < 2048 for r in range(32))]
        print(f"   {needle.decode():9} offset {o:8}  A: mod41={okA:2}   B: {len(fitsB)} vyhovujicich fazi")
