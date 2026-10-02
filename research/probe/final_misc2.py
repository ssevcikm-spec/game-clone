import os, sys, struct, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
D = lambda f: open(os.path.join(UODIR, f), "rb").read()

print("=== skills.mul with idx-driven variable records ===")
sk = D("skills.mul")
si = D("skills.idx")
print("  skills.mul", len(sk), " skills.idx", len(si), "entries", len(si)//4)
offs = list(struct.unpack_from("<%dI" % (len(si)//4), si, 0))
print("  first 12 offsets:", offs[:12])
names = []
for i, o in enumerate(offs):
    if o >= len(sk):
        names.append((i, None, None)); continue
    end = sk.find(b"\x00", o)
    if end < 0:
        end = len(sk)
    nm = sk[o:end].decode("ascii", "replace")
    names.append((i, o, nm))
for i, o, nm in names[:8]:
    print(f"   idx[{i:3}] off={o:4} name={nm!r}")
print("   ...")
for i, o, nm in names[-8:]:
    print(f"   idx[{i:3}] off={o:4} name={nm!r}")
# Dump raw first 120 bytes
print("  raw[0:120]:", sk[:120].hex(" "))
print("  ascii:", "".join(chr(c) if 32 <= c < 127 else "|" for c in sk[:120]))

print("\n=== speech.mul big-endian id/len ===")
sp = D("speech.mul")
o = 0
n = 0
while o + 4 <= len(sp) and n < 6:
    kw = struct.unpack_from(">H", sp, o)[0]
    ln = struct.unpack_from(">H", sp, o + 2)[0]
    txt = sp[o+4:o+4+ln]
    print(f"   @{o} id={kw} (0x{kw:04X}) len={ln} text={txt[:40]!r}")
    o += 4 + ln
    n += 1
print("   consumed", o, "of", len(sp))

print("\n=== Cliloc.enu flag @3 ===")
c = D("Cliloc.enu")
print("  c[3] = 0x%02X (0x8E means BWT-compressed)" % c[3])
print("  header: u32 =", struct.unpack_from("<I", c, 0)[0], " u16 =", struct.unpack_from("<H", c, 4)[0])
# try flag=1 -> int16 length
o = 6
for k in range(4):
    num = struct.unpack_from("<i", c, o)[0]
    flag = c[o+4]
    ln = struct.unpack_from("<h", c, o+5)[0]
    txt = c[o+7:o+7+ln]
    print(f"   rec{k} @{o} num={num} flag={flag} len={ln} text={txt[:60]!r}")
    o += 7 + ln
print("   consumed", o, "of", len(c))

print("\n=== hues.mul ===")
h = D("hues.mul")
print("  size", len(h), "  /(3000*88) =", len(h)/(3000*88), "  /(3002*88) =", len(h)/(3002*88))
print("  row(88B) header u32@0 =", struct.unpack_from("<I", h, 0)[0])
print("  colors row0 first8 =", [hex(struct.unpack_from('<H', h, 4+2*i)[0]) for i in range(8)])
last = len(h) - 88
print("  last row header =", struct.unpack_from("<I", h, last)[0],
      " colors =", [hex(struct.unpack_from('<H', h, last+4+2*i)[0]) for i in range(4)])

print("\n=== radarcol.mul ===")
r = D("radarcol.mul")
print("  size", len(r), " = 0x4000*2 +", len(r) - 0x4000*2, " (item part)")
print("  land[0..3]:", [hex(struct.unpack_from('<H', r, 2*i)[0]) for i in range(4)])
print("  item[0..3] @0x4000:", [hex(struct.unpack_from('<H', r, 0x4000*2 + 2*i)[0]) for i in range(4)])

print("\n=== light.mul group layout check ===")
li = D("lightidx.mul")
lm = D("light.mul")
e = [struct.unpack_from("<III", li, i*12) for i in range(len(li)//12)]
off, ln, extra = e[0]
print(f"  idx[0] offset={off} len={ln} extra={extra}")
print(f"  len/(4+6*2016) = {ln/(4+6*2016)}")
for sz in (2016, 2048, 4096):
    print(f"   (4+6*{sz}) = {4+6*sz};  ln % that = {ln % (4+6*sz)}")
print("  bytes at group0:", lm[off:off+16].hex(" "))

print("\n=== texmaps: first-group header ===")
tm = D("texmaps.mul")
ti = D("texidx.mul")
te = [struct.unpack_from("<III", ti, i*12) for i in range(len(ti)//12)]
print("  texidx[1] =", te[1], " texidx[2] =", te[2])
o1 = te[1][0]
print(f"  texmaps @{o1}: {tm[o1:o1+12].hex(' ')}  u32@0={struct.unpack_from('<I', tm, o1)[0]}")
print(f"  next entry at {te[2][0]}: delta = {te[2][0]-o1}")
print(f"  first 4096 entries * 8196 = {4096*8196}  0x4000*8196 = {0x4000*8196} file {len(tm)}")
print(f"  (0x4000*8196 + 555*32768) = {0x4000*8196 + 555*32768}")
