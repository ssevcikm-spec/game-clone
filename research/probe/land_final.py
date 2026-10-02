import os, sys, struct, collections
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(r"D:\Games\Electronic Arts\Ultima Online Classic\tiledata.mul", "rb").read()
n = len(d)

# Hypothesis: land record = 30 bytes; flags u32@0, texid u16@4, name char[20]@10.
print("=== test: land record 30 B, flags@0, texid@4, name@10 ===")
oktxt = 0
texids = collections.Counter()
flags = collections.Counter()
names = []
for k in range(0x4000):
    o = k * 30
    fl = struct.unpack_from("<I", d, o)[0]
    tid = struct.unpack_from("<H", d, o + 4)[0]
    nm = d[o + 10:o + 30].split(b"\x00")[0]
    flags[fl] += 1
    texids[tid] += 1
    if not nm or all(0x20 <= c < 0x7f for c in nm):
        oktxt += 1
    if k < 8:
        names.append((k, o, fl, tid, nm))
print(f"  plausible names: {oktxt}/16384 = {100.0*oktxt/16384:.1f}%")
for k, o, fl, tid, nm in names:
    print(f"   land[{k}] @{o:6} flags=0x{fl:08X} texid={tid:6} name={nm!r}")
print("  distinct flags:", len(flags), " top5:", [(hex(a),b) for a,b in flags.most_common(5)])
print("  distinct texids:", len(texids), " max:", max(texids))
print("  texid>=0x4000:", sum(1 for t in texids if t >= 0x4000))
print("  block would end at:", 0x4000*30, " file:", n)

# Where does the 30-byte land chain break?
lastgood = 0
for k in range(0x4000):
    o = k * 30
    nm = d[o + 10:o + 30].split(b"\x00")[0]
    if not nm or all(0x20 <= c < 0x7f for c in nm):
        lastgood = k
print("  last plausible land index:", lastgood, "-> bytes to", (lastgood+1)*30)

print("\n=== is 0x4000*30 = 491520 a boundary? dump bytes around it ===")
for base in (491520, 557056, 1228800):
    print(f"  @{base}: {d[base:base+40].hex(' ')}")
    print(f"      |{''.join(chr(c) if 32<=c<127 else '.' for c in d[base:base+40])}|")
