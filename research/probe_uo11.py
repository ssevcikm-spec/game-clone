"""Sonda 11: land blok tiledata.mul - ktery model sedi (s nulovym modelem).

Kandidati (16 384 land zaznamu, jmeno = 20 B):
  A) plochy 30 B:            off = k*30 + o
  B) plochy 34 B:            off = k*34 + o
  C) skupiny 964 B od 0:     off = (k//32)*964 + 4 + (k%32)*30 + o
  D) skupiny 964 B od 4:     off = 4 + (k//32)*964 + (k%32)*30 + o

Rozhoduje pocet CISTYCH JMEN proti nulovemu modelu.
"""
import random
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


def best(offset_fn, label, count=16384):
    results = []
    for o in range(0, 16):
        named = sum(1 for k in range(count) if clean(offset_fn(k) + o))
        results.append((named, o))
    results.sort(reverse=True)
    print(f"   {label:28} nejlepsi faze: {results[:3]}")
    return results[0]


print("=" * 74)
print("LAND blok - kandidati")
print("=" * 74)
a = best(lambda k: k * 30, "A) plochy 30 B")
b = best(lambda k: k * 34, "B) plochy 34 B")
c = best(lambda k: (k // 32) * 964 + 4 + (k % 32) * 30, "C) skupiny 964 od 0")
d = best(lambda k: 4 + (k // 32) * 964 + (k % 32) * 30, "D) skupiny 964 od 4")

rnd = random.Random(7)
nul = sum(1 for _ in range(16384) if clean(rnd.randrange(0, 493568)))
print(f"   {'NULOVY MODEL':28} {nul} cistych jmen")

print()
print("=" * 74)
print("Kontrola znamych jmen land dlazdic")
print("=" * 74)
import re
for needle in (b"grass", b"water", b"UNUSED", b"VOID!!!!!!", b"NODRAW"):
    offs = [m.start() for m in re.finditer(re.escape(needle), td)][:3]
    print(f"   {needle.decode():12} offsety={offs}")
    for o in offs[:2]:
        for name, fn in (("A", lambda k: k * 30), ("C", lambda k: (k // 32) * 964 + 4 + (k % 32) * 30)):
            for k in range(16384):
                base = fn(k)
                if base <= o < base + 30:
                    print(f"        -> v modelu {name} lezi na zaznamu {k} (offset v zaznamu {o - base})")
                    break
