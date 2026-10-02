import os, struct, sys
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def P(n):
    return os.path.join(UODIR, n)


def S(n):
    return os.path.getsize(P(n))


print("=" * 90)
print("### tiledata.mul : which record size fits?")
s = S("tiledata.mul")
print("  size =", s)
for rec in (37, 41, 42):
    for hdr in (0, 4):
        unit = hdr + 32 * rec
        print(f"   rec={rec} grpHeader={hdr} unit={unit} -> units={s/unit}")

# Try: no group header at all, flat array of 0x4000 land then 0x4000 items
for rec in (37, 41):
    print(f"  flat rec={rec}: land block ends {0x4000*rec}, item block ends {0x8000*rec}, file {s}")

# Try: 4-byte group header, 32 entries
for rec in (37, 41):
    g = 4 + 32 * rec
    n = s // g
    print(f"  grp rec={rec}: unit={g} units={n} rem={s % g}")

print("\n  => inspect record boundaries: dump a land group and an item group")
# Hypothesis H1: 4-byte group header + 32 records, land first then item
rec = 41
unit = 4 + 32 * rec
land_units = 0x4000 // 32
item_start = land_units * unit
print(f"  H1: unit={unit} landUnits={land_units} itemStart={item_start} "
      f"totalNeeded={2*land_units*unit} file={s}")
with open(P("tiledata.mul"), "rb") as f:
    f.seek(item_start)
    g = f.read(unit)
print("   item group0 hdr u32 =", struct.unpack_from("<I", g, 0)[0])
for i in range(3):
    e = g[4 + i * rec: 4 + (i + 1) * rec]
    print(f"    item[{i}] hex={e.hex(' ')}")
    # classic 37-byte layout: flags u32, weight u8, quality u8, misc u16, unk u8,
    # quantity u8, anim u16, unk2 u8(hue?), unk3 u8, stackoff u8, value u8, height u8, name[20]
    fl, wt, q, misc, unk, qty, anim = struct.unpack_from("<IBBHBBH", e, 0)
    print(f"      flags=0x{fl:08X} weight={wt} quality={q} misc=0x{misc:04X} unk={unk} qty={qty} anim=0x{anim:04X}"
          f" rest={e[13:21].hex(' ')} name={e[21:41]!r}")

# H2: maybe no group header for items
print("\n  H2: try item block as flat records starting at 0x4000*rec")
for rec in (37, 41):
    with open(P("tiledata.mul"), "rb") as f:
        f.seek(0x4000 * rec)
        d = f.read(rec * 3)
    print(f"   rec={rec}: {d[:rec*2].hex(' ')}")
    if rec == 41:
        fl, wt, q, misc, unk, qty, anim = struct.unpack_from("<IBBHBBH", d, 0)
        print(f"     e0 flags=0x{fl:08X} wt={wt} q={q} misc=0x{misc:04X} name={d[21:41]!r}")

print("\n" + "=" * 90)
print("### Cliloc.enu")
with open(P("Cliloc.enu"), "rb") as f:
    data = f.read()
print("  size", len(data), " first 24:", data[:24].hex(" "))
print("  bytes[0:6] =", data[0:6].hex(" "), " ascii:", data[0:6])
off = 6
for k in range(6):
    num, flag, ln = struct.unpack_from("<IHI", data, off)
    txt = data[off + 10: off + 10 + ln * 2]
    print(f"   rec{k} off={off} num={num} flag=0x{flag:04X} len={ln} text={txt[:60].decode('utf-16-le', 'replace')!r}")
    off += 10 + ln * 2
print("   consumed", off, "of", len(data))
# try alternate: len is u32 at +6 (already) vs u16
off = 6
for k in range(3):
    num = struct.unpack_from("<I", data, off)[0]
    flag = struct.unpack_from("<H", data, off + 4)[0]
    ln = struct.unpack_from("<H", data, off + 6)[0]
    print(f"   alt rec{k} num={num} flag=0x{flag:04X} len16={ln}")
    break

print("\n" + "=" * 90)
print("### light.mul / lightidx.mul")
li = open(P("lightidx.mul"), "rb").read()
tot = 0
for i in range(0, 300, 3):
    off, ln, extra = struct.unpack_from("<III", li, i * 4)
    if ln:
        print(f"   idx[{i//3}] offset={off} len={ln} extra={extra}")
        tot += ln
print("   sum of all idx lengths:", sum(struct.unpack_from("<I", li, i * 4 + 4)[0] for i in range(100)),
      " light.mul size:", S("light.mul"))

print("\n" + "=" * 90)
print("### texmaps.mul / texidx.mul")
ti = open(P("texidx.mul"), "rb").read()
print("   texidx entries:", len(ti) // 12)
for i in range(6):
    print(f"   texidx[{i}] =", struct.unpack_from("<III", ti, i * 12))
print("   texmaps size:", S("texmaps.mul"))
print("   variant 4+8192:", S("texmaps.mul") / 8196, " variant 4+4096:", S("texmaps.mul") / 4100)
with open(P("texmaps.mul"), "rb") as f:
    f.seek(0)
    d = f.read(32)
print("   texmaps[0..16] u16:", [struct.unpack_from("<H", d, 2 * i)[0] for i in range(16)])

print("\n" + "=" * 90)
print("### radarcol.mul")
rc = open(P("radarcol.mul"), "rb").read()
print("   size", len(rc), "u16:", len(rc) // 2)

print("\n" + "=" * 90)
print("### fonts.mul")
with open(P("fonts.mul"), "rb") as f:
    d = f.read(64)
print("   first64:", d.hex(" "))
print("   u8@0..7:", list(d[:8]))

print("\n" + "=" * 90)
print("### animdata.mul / animinfo.mul")
print("   animdata size:", S("animdata.mul"))
for cand, label in ((548, "68*8+4"), (132, "4+64*2"), (4096, "64*64"), (2048, "64*32")):
    print(f"     /{cand} ({label}) = {S('animdata.mul')/cand}")
with open(P("animdata.mul"), "rb") as f:
    d = f.read(32)
print("   first32:", d.hex(" "))
print("   animinfo size:", S("animinfo.mul"), "first16:", open(P("animinfo.mul"), "rb").read(16).hex(" "))

print("\n" + "=" * 90)
print("### skills.mul / skills.idx")
sk = open(P("skills.mul"), "rb").read()
print("   size", len(sk))
for i in range(0, min(len(sk), 13 * 8), 13):
    print(f"   [{i//13}] flag={sk[i]} name={sk[i+1:i+13]!r}")
si = open(P("skills.idx"), "rb").read()
print("   skills.idx size", len(si), "u32 entries:", len(si) // 4)
print("   first 16 u32:", struct.unpack_from("<16I", si, 0))

print("\n### skillgrp.mul")
sg = open(P("skillgrp.mul"), "rb").read()
print("   size", len(sg), " first16:", sg[:16].hex(" "))
print("   u32@0 =", struct.unpack_from("<I", sg, 0)[0])

print("\n### anim.idx / anim2..6.idx")
for a in ("anim.idx", "anim2.idx", "anim3.idx", "anim4.idx", "anim5.idx", "anim6.idx"):
    print(f"   {a}: size={S(a)} entries(/12)={S(a)/12}")
ai = open(P("anim.idx"), "rb").read(48)
for i in range(4):
    print(f"   anim.idx[{i}] =", struct.unpack_from("<iii", ai, i * 12))

print("\n### palette.mul")
pm = open(P("palette.mul"), "rb").read()
print("   size", len(pm), "first12:", pm[:12].hex(" "), "as 6x u16:", struct.unpack_from("<6H", pm, 0))
