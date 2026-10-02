import os, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"


def p(name):
    return os.path.join(UODIR, name)


def sz(name):
    return os.path.getsize(p(name))


print("### tiledata.mul")
s = sz("tiledata.mul")
print("  size", s)
for rec in (37, 41):
    grp = 4 + 32 * rec
    n = s / grp
    print(f"  rec={rec} group={grp} -> groups={n} {'EXACT' if n == int(n) else ''}")
with open(p("tiledata.mul"), "rb") as f:
    d = f.read(4 + 32 * 41)
print("  land group0 header u32 =", struct.unpack_from("<I", d, 0)[0])
print("  land entry0 first 41 B =", d[4:45].hex(" "))
print("  land entry1 first 41 B =", d[45:86].hex(" "))
# item block start
itstart = (0x4000 // 32) * (4 + 32 * 41)
print("  item block starts at", itstart)
with open(p("tiledata.mul"), "rb") as f:
    f.seek(itstart)
    d2 = f.read(4 + 32 * 41)
print("  item group0 header u32 =", struct.unpack_from("<I", d2, 0)[0])
print("  item entry0 first 41 B =", d2[4:45].hex(" "))
print("  item entry0 name(20)   =", d2[4 + 21:4 + 41])
print("  item entry1 first 41 B =", d2[45:86].hex(" "))
print("  item entry1 name(20)   =", d2[45 + 21:45 + 41])
print("  file after item block =", s - (itstart + (0x4000 // 32) * (4 + 32 * 41)))

print("\n### hues.mul")
s = sz("hues.mul")
row = 4 + 32 * 2
print("  size", s, "row(4+32*2)=", row, "rows=", s / row)
with open(p("hues.mul"), "rb") as f:
    d = f.read(4 + 32 * 2)
print("  row0 header u32 =", struct.unpack_from("<I", d, 0)[0])
print("  row0 colors[0..7] =", [hex(struct.unpack_from('<H', d, 4 + 2 * i)[0]) for i in range(8)])
with open(p("hues.mul"), "rb") as f:
    f.seek(2999 * row)
    d = f.read(4 + 32 * 2)
print("  row2999 header =", struct.unpack_from("<I", d, 0)[0],
      "colors=", [hex(struct.unpack_from('<H', d, 4 + 2 * i)[0]) for i in range(4)])

print("\n### radarcol.mul")
s = sz("radarcol.mul")
print("  size", s, "u16 count", s // 2, "0x4000 =", 0x4000, "remainder", s // 2 - 0x4000)

print("\n### light.mul / lightidx.mul")
s = sz("light.mul")
with open(p("lightidx.mul"), "rb") as f:
    li = f.read(12 * 4)
for i in range(4):
    print(f"  lightidx[{i}] = {struct.unpack_from('<III', li, i*12)}")
with open(p("light.mul"), "rb") as f:
    f.seek(0x2f44)
    d = f.read(24)
print("  light.mul @0x2f44 first24:", d.hex(" "))

print("\n### texmaps.mul / texidx.mul")
s = sz("texmaps.mul")
print("  size", s, "/(4+64*64*2) =", s / (4 + 64 * 64 * 2))
with open(p("texidx.mul"), "rb") as f:
    ti = f.read(12 * 4)
for i in range(4):
    print(f"  texidx[{i}] = {struct.unpack_from('<III', ti, i*12)}")
with open(p("texmaps.mul"), "rb") as f:
    d = f.read(4 + 8)
print("  texmaps first12:", d.hex(" "))

print("\n### multi.idx / multi.mul")
s = sz("multi.idx")
print("  multi.idx size", s, "12-byte entries:", s / 12)
with open(p("multi.idx"), "rb") as f:
    mi = f.read(12 * 6)
for i in range(6):
    print(f"  multi.idx[{i}] = {struct.unpack_from('<III', mi, i*12)}")
with open(p("multi.mul"), "rb") as f:
    d = f.read(24)
print("  multi.mul first24:", d.hex(" "), struct.unpack_from("<iiiiii", d, 0))

print("\n### Cliloc.enu")
with open(p("Cliloc.enu"), "rb") as f:
    d = f.read(32)
print("  first32:", d.hex(" "))
print("  u32@0 =", struct.unpack_from("<I", d, 0)[0], " u16@4 =", struct.unpack_from("<H", d, 4)[0])
print("  u32@6 =", struct.unpack_from("<I", d, 6)[0], " u32@10 =", struct.unpack_from("<I", d, 10)[0])
print("  bytes[4:6] ascii =", d[4:6])
print("  bytes[10:12] ascii =", d[10:12])
# try 6-byte header then records
off = 6
cnt = 0
with open(p("Cliloc.enu"), "rb") as f:
    f.seek(off)
    while cnt < 5:
        h = f.read(6)
        if len(h) < 6:
            break
        num = struct.unpack_from("<I", h, 0)[0]
        flag = struct.unpack_from("<H", h, 4)[0]
        # try u32 length
        lb = f.read(4)
        L = struct.unpack("<I", lb)[0]
        strb = f.read(L * 2)
        print(f"  rec{ cnt }: num={num} flag={flag} len={L} text={strb[:40].decode('utf-16-le', 'replace')!r}")
        cnt += 1

print("\n### skills.mul / skills.idx")
s = sz("skills.mul")
with open(p("skills.mul"), "rb") as f:
    d = f.read(64)
print("  size", s, "first64:", d.hex(" "))
print("  rec0: flag=", d[0], "name=", d[1:13])
print("  rec1: flag=", d[13], "name=", d[14:26])
with open(p("skills.idx"), "rb") as f:
    si = f.read(16)
print("  skills.idx first16:", si.hex(" "), struct.unpack_from("<IIII", si, 0))
print("  skills.idx size", sz("skills.idx"), "entries", sz("skills.idx") / 4)

print("\n### skillgrp.mul")
with open(p("skillgrp.mul"), "rb") as f:
    d = f.read(64)
print("  first64:", d.hex(" "))

print("\n### animdata.mul")
s = sz("animdata.mul")
print("  size", s, "  /548 =", s / 548, "  (4+64*2)=132 ->", s / 132, "  32*64*2=4096 ->", s / 4096)
with open(p("animdata.mul"), "rb") as f:
    d = f.read(64)
print("  first64:", d.hex(" "))

print("\n### animinfo.mul")
with open(p("animinfo.mul"), "rb") as f:
    d = f.read(32)
print("  first32:", d.hex(" "), [struct.unpack_from("<H", d, 2 * i)[0] for i in range(16)])

print("\n### anim.idx / anim2..6.idx")
for a in ("anim.idx", "anim2.idx", "anim3.idx", "anim4.idx", "anim5.idx", "anim6.idx"):
    s = sz(a)
    print(f"  {a}: size={s} /12={s/12}")
with open(p("anim.idx"), "rb") as f:
    ai = f.read(12 * 4)
for i in range(4):
    print(f"  anim.idx[{i}] =", struct.unpack_from("<iii", ai, i*12))

print("\n### palette.mul")
with open(p("palette.mul"), "rb") as f:
    d = f.read(12)
print("  first12:", d.hex(" "))

print("\n### staidx0.mul / statics0.mul")
print("  staidx0 size", sz("staidx0.mul"), "/12 =", sz("staidx0.mul") / 12)
print("  staidx0x size", sz("staidx0x.mul"), "/12 =", sz("staidx0x.mul") / 12)
print("  statics0 size", sz("statics0.mul"), "/7 =", sz("statics0.mul") / 7)
with open(p("statics0.mul"), "rb") as f:
    st = f.read(7 * 4)
print("  statics0 first4 recs:", [struct.unpack_from("<HBBBB", st, 7 * i) for i in range(4)])
with open(p("staidx0.mul"), "rb") as f:
    f.seek(12 * 656)
    si = f.read(12)
print("  staidx0[656] =", struct.unpack("<III", si))

print("\n### map uop chunk check")
for m in range(6):
    fn = f"map{m}LegacyMUL.uop"
    if os.path.exists(p(fn)):
        print(f"  {fn} size={sz(fn)}")
