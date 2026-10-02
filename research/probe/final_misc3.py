import os, sys, struct, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
D = lambda f: open(os.path.join(UODIR, f), "rb").read()

print("=== skills.idx as 12-byte records ===")
sk = D("skills.mul"); si = D("skills.idx")
recs = [struct.unpack_from("<III", si, i*12) for i in range(len(si)//12)]
print("  entries:", len(recs), " first 6:", recs[:6])
names = []
for i, (off, ln, extra) in enumerate(recs):
    if off + ln > len(sk) or ln == 0:
        names.append((i, off, ln, "")); continue
    names.append((i, off, ln, sk[off+1:off+ln-1].decode("ascii", "replace")))
print("  valid names:", sum(1 for _, _, l, n in names if n))
for i, off, ln, nm in names[:6]:
    print(f"   skill[{i:2}] off={off:4} len={ln:3} hasAction={sk[off] if ln else '-'} name={nm!r}")
print("   ...")
for i, off, ln, nm in names[-6:]:
    print(f"   skill[{i:2}] off={off:4} len={ln:3} hasAction={sk[off] if ln else '-'} name={nm!r}")
print("\n  ALL 54/58 skill names:")
for i, off, ln, nm in names:
    if nm:
        print(f"   {i:3} {nm}")

print("\n=== speech.mul big-endian ===")
sp = D("speech.mul")
o = 0; n = 0
while o + 4 <= len(sp) and n < 5:
    kw = struct.unpack_from(">H", sp, o)[0]
    ln = struct.unpack_from(">H", sp, o+2)[0]
    print(f"   @{o} id={kw} (0x{kw:04X}) len={ln} text={sp[o+4:o+4+ln][:40]!r}")
    o += 4 + ln; n += 1
print("   consumed", o, "of", len(sp))

print("\n=== Cliloc.enu (u8 flag, i16 len, UTF-8) ===")
c = D("Cliloc.enu")
print("  c[3] = 0x%02X" % c[3], " hdr u32 =", struct.unpack_from("<I", c, 0)[0], " hdr u16 =", struct.unpack_from("<H", c, 4)[0])
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
print("  size", len(h), "/88 =", len(h)/88)
print("  colors row0 first8:", [hex(struct.unpack_from('<H', h, 4+2*i)[0]) for i in range(8)])

print("\n=== radarcol.mul ===")
r = D("radarcol.mul")
print("  size", len(r), " land 0x4000 u16 =", 0x4000*2, " item part =", len(r)-0x4000*2, "u16:", (len(r)-0x4000*2)//2)

print("\n=== light.mul ===")
li = D("lightidx.mul"); lm = D("light.mul")
e = [struct.unpack_from("<III", li, i*12) for i in range(len(li)//12)]
print("  idx[0:4]:", e[:4])
print("  idx[0] len", e[0][1], "/(4+6*2016) =", e[0][1]/(4+6*2016))
print("  idx[1] len", e[1][1], "/(4+25*2016) =", e[1][1]/(4+25*2016))
print("  sum lens", sum(x[1] for x in e), " light.mul", len(lm))

print("\n=== texmaps.mul ===")
tm = D("texmaps.mul"); ti = D("texidx.mul")
te = [struct.unpack_from("<III", ti, i*12) for i in range(len(ti)//12)]
nz = [(i, x) for i, x in enumerate(te) if x[1]]
print("  texidx nonzero entries:", len(nz), " first:", nz[:3])
lens = collections.Counter(x[1] for _, x in nz)
print("  lengths:", lens.most_common(4))
tot = sum(x[1] for _, x in nz)
print("  sum of lens:", tot, " texmaps size:", len(tm), " incl headers:", tot + 4*len(nz))
off0 = nz[0][1][0]
print("  first entry offset:", off0, " next:", nz[1][1][0] if len(nz) > 1 else None)
print("  bytes @first:", tm[off0:off0+12].hex(" "))
