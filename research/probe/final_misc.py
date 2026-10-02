import os, sys, struct, zlib, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
D = lambda f: open(os.path.join(UODIR, f), "rb").read()
S = lambda f: os.path.getsize(os.path.join(UODIR, f))

# ---------------- animdata.mul ----------------
a = D("animdata.mul")
print("animdata.mul size", len(a))
for stride in (548, 132, 264, 4096, 2048, 1028, 68):
    print(f"   /{stride} = {len(a)/stride}")

# ---------------- hues.mul ----------------
h = D("hues.mul")
print("\nhues.mul size", len(h), "/88 =", len(h)/88, " /(4+32*2)=68 ->", len(h)/68)
o = 0
print("  row0 header u32 =", struct.unpack_from("<I", h, 0)[0], "colors[0:6] =",
      [hex(struct.unpack_from('<H', h, 4+2*i)[0]) for i in range(6)])

# ---------------- radarcol ----------------
r = D("radarcol.mul")
print("\nradarcol.mul size", len(r), "u16 count", len(r)//2)

# ---------------- lightidx/light ----------------
li = D("lightidx.mul")
entries = [struct.unpack_from("<III", li, i*12) for i in range(len(li)//12)]
nz = [(i, e) for i, e in enumerate(entries) if e[1]]
print("\nlightidx.mul:", len(entries), "entries; first 5 nonzero:", nz[:5])
print("  sum lens:", sum(e[1] for _, e in nz), " light.mul size:", S("light.mul"))

# ---------------- texidx/texmaps ----------------
ti = D("texidx.mul")
tentries = [struct.unpack_from("<III", ti, i*12) for i in range(len(ti)//12)]
tnz = [(i, e) for i, e in enumerate(tentries) if e[1]]
print("\ntexidx.mul:", len(tentries), "entries; first 4 nonzero:", tnz[:4])
print("  distinct tex lengths:", collections.Counter(e[1] for _, e in tnz).most_common(5))
print("  texmaps.mul size:", S("texmaps.mul"))

# ---------------- skills ----------------
sk = D("skills.mul")
print("\nskills.mul size", len(sk), " 13-byte recs:", len(sk)/13)
for i in list(range(0, 6)) + [50, 51, 52, 53]:
    o = i*13
    if o+13 <= len(sk):
        print(f"   skill[{i:2}] flag={sk[o]} name={sk[o+1:o+13]!r}")
si = D("skills.idx")
print("  skills.idx size", len(si), "u32 count", len(si)//4)
print("  first 10 u32:", struct.unpack_from("<10I", si, 0))

# ---------------- skillgrp ----------------
sg = D("skillgrp.mul")
print("\nskillgrp.mul size", len(sg), "u32@0 =", struct.unpack_from("<I", sg, 0)[0])

# ---------------- speech ----------------
sp = D("speech.mul")
print("\nspeech.mul size", len(sp))
for i in range(3):
    kw, unk, count = struct.unpack_from("<HHI", sp, i*8)
    print(f"   id[{i}] id={kw} (0x{kw:04X}) unk={unk} count={count}")

# ---------------- multi.idx / multi.mul ----------------
mi = D("multi.idx")
print("\nmulti.idx size", len(mi), "entries", len(mi)/12)
for i in range(4):
    print(f"   multi.idx[{i}] =", struct.unpack_from("<III", mi, i*12))
mm = D("multi.mul")
print("  multi.mul size", len(mm))

# ---------------- anim.idx ----------------
for f in ("anim.idx","anim2.idx","anim3.idx","anim4.idx","anim5.idx","anim6.idx"):
    print(f"\n{f}: size {S(f)} entries {S(f)/12}")
ai = D("anim.idx")
for i in range(3):
    print(f"   anim.idx[{i}] =", struct.unpack_from("<iii", ai, i*12))

# ---------------- palette ----------------
pm = D("palette.mul")
print("\npalette.mul size", len(pm), "as 256 u16:", [hex(x) for x in struct.unpack_from("<8H", pm, 0)])
print("  as 256 RGB24:", pm[:12].hex(" "))

# ---------------- staidx / statics ----------------
for i in (0,1,2,3,4,5):
    f = f"staidx{i}.mul"
    if os.path.exists(os.path.join(UODIR,f)):
        s = S(f)
        print(f"\n{f}: {s} bytes -> {s/12} blocks")
si = D("staidx0.mul")
print("  staidx0[0:6]:", [struct.unpack_from("<III", si, i*12) for i in range(6)])
st = D("statics0.mul")
print("  statics0 first 6 statics (7B each):")
for i in range(6):
    tid, x, y, z, hue = struct.unpack_from("<HBBBB", st, i*7)
    print(f"    tile=0x{tid:04X} x={x:3} y={y:3} z={z:3} hue={hue:3}")

# ---------------- Cliloc ----------------
c = D("Cliloc.enu")
print("\nCliloc.enu size", len(c), "first 6:", c[:6].hex(" "))
off = 6
for k in range(5):
    num, flag, ln = struct.unpack_from("<IHI", c, off)
    txt = c[off+10:off+10+ln*2].decode("utf-16-le", "replace")
    print(f"   rec{k} @{off}: num={num} flag=0x{flag:04X} len={ln} text={txt[:60]!r}")
    off += 10 + ln*2
print("   consumed", off, "of", len(c), "remainder", len(c)-off)
