"""Sonda 10: dva sporne layouty, tentokrat SPRAVNE a s nulovym modelem.

1) HUES.MUL  - plochy model (4 + k*88) vs skupinovy (k//8*708 + 4 + (k%8)*88)
   Rozhoduje SEMANTIKA: text "Hue (X->Y)" v zaznamu musi sedet s poli
   start/end. To je nezavisle na mne i na dokumentaci.

2) TILEDATA item blok - plochy (491520 + 41k) vs skupinovy
   (493568 + (k//32)*1316 + 4 + (k%32)*41). Rozhoduje pocet CISTYCH JMEN
   proti NULOVEMU MODELU (kontrola, ze mrizka predci nahodu).

Pozor na chybu, kterou jsem udelal predtim: u skupinoveho modelu jsem
posouval jen 4 B na skupinu misto cele velikosti skupiny (1316 B).
"""
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
PRINT = set(range(32, 127))
hu = (UO / "hues.mul").read_bytes()
td = (UO / "tiledata.mul").read_bytes()


def clean(buf, off, n=20):
    ch = buf[off:off + n]
    if len(ch) < n or ch[0] not in PRINT:
        return None
    k = ch.find(b"\x00")
    if k < 0:
        return ch.decode("latin1")
    if k == 0 or any(c != 0 for c in ch[k:]):
        return None
    return ch[:k].decode("latin1")


print("=" * 74)
print("1) HUES.MUL - semanticky test (jmeno vs pole start/end)")
print("=" * 74)
rx = re.compile(r"Hue \((\d+)->(\d+)\)")


def hue_test(offset_fn, count, label):
    ok = bad = named = 0
    for k in range(count):
        off = offset_fn(k)
        nm = clean(hu, off + 68)
        if not nm:
            continue
        m = rx.match(nm)
        if not m:
            continue
        named += 1
        import struct
        s, e = struct.unpack("<HH", hu[off + 64:off + 68])
        if (s, e) == (int(m.group(1)), int(m.group(2))):
            ok += 1
        else:
            bad += 1
    print(f"   {label}: jmenovanych={named}, souhlas={ok}, nesouhlas={bad}")
    return ok, bad


hue_test(lambda k: 4 + k * 88, 3017, "plochy   4 + k*88        ")
hue_test(lambda k: (k // 8) * 708 + 4 + (k % 8) * 88, 3000, "skupinovy 375x(4+8x88) ")

print()
print("=" * 74)
print("2) TILEDATA item blok - cista jmena vs nulovy model")
print("=" * 74)


def count_named(offset_fn, count, name_off):
    return sum(1 for k in range(count) if clean(td, offset_fn(k) + name_off))


def null_model(base, span, count, name_off, trials=5):
    """Nulovy model: stejne mnozstvi nahodnych offsetu ve stejnem rozsahu."""
    import random
    rnd = random.Random(1234)
    tot = 0
    for _ in range(trials):
        tot += sum(1 for _ in range(count)
                   if clean(td, base + rnd.randrange(span) + name_off))
    return tot / trials


base_flat, base_grp = 491520, 493568
for noff in (21, 20, 22):
    flat = count_named(lambda k: base_flat + k * 41, 16384, noff)
    grp = count_named(lambda k: base_grp + (k // 32) * 1316 + 4 + (k % 32) * 41, 16384, noff)
    nul = null_model(base_grp, 2695168 - 200, 16384, noff)
    print(f"   name_off={noff}: plochy={flat:5}  skupinovy={grp:5}  nulovy model={nul:7.1f}")

print()
print("   -- kde lezi zname retezce (rozbor mezer) --")
strings = []
for m in re.finditer(rb"[ -~]{4,}\x00", td):
    if m.start() > 493568:
        strings.append(m.start())
diffs = {}
for a, b in zip(strings, strings[1:]):
    d = b - a
    if 30 <= d <= 200:
        diffs[d] = diffs.get(d, 0) + 1
top = sorted(diffs.items(), key=lambda x: -x[1])[:8]
print("   nejcastejsi mezery mezi jmeny:", top)
print(f"   -> pomer 45/(41+45) = {diffs.get(45,0)/(diffs.get(41,0)+diffs.get(45,0)+1e-9):.4f}"
      f"  (ocekavano ~1/32 = 0.031 pro 4B hlavicku kazdych 32 zaznamu)")
