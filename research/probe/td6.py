import os, sys, struct, collections
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(os.path.join(UODIR, "tiledata.mul"), "rb").read()
n = len(d)
print("file size:", n, hex(n))

# Land: name field at record offset 6, record stride 34 (30 name=20 + pad)
# Verify stride 34 by walking from 6 and checking we land on many known names
for stride in (34, 30):
    hits = 0
    names = []
    for k in range(0, 0x4000):
        o = 6 + k * stride
        if o + 20 > n:
            break
        nm = d[o:o + 20].split(b"\x00")[0]
        if nm and all(0x20 <= c < 0x7f for c in nm):
            hits += 1
            if len(names) < 6:
                names.append((k, o, nm))
    print(f"stride {stride}: valid names {hits}, e.g. {names[:6]}")

# where does stride-34 land chain break?
stride = 34
last_ok = 0
for k in range(0, 0x4000):
    o = 6 + k * stride
    if o + 20 > n:
        break
    nm = d[o:o + 20].split(b"\x00")[0]
    if nm and all(0x20 <= c < 0x7f for c in nm):
        last_ok = k
print("land stride-34 last valid k =", last_ok, "-> land block ends approx", 6 + (last_ok + 1) * stride)

# Now item: use 41-stride from 'spike trap' occurrences
sp = [672897, 805194]
# back out record start assuming name at record offset 21 (37-byte style) or 17
for nameoff in (21, 17, 26, 30, 36, 20, 25):
    print(f"nameoff={nameoff}: rec_start(sp0)={sp[0]-nameoff}, mod41={(sp[0]-nameoff)%41}, "
          f"rec_start(sp_last)={sp[-1]-nameoff}")

# item block: assume starts right after land block; find first offset where a
# 41-stride chain of valid printable names runs for thousands of records
best = None
for start in range(600000, 900000):
    if (start - 21) % 41 and (start - 17) % 41:
        pass
# simpler: for each candidate (itemStart, nameOff) with name at itemStart+k*41+nameOff
for nameOff in (21, 17, 26, 30, 36, 20, 25, 37):
    for itemStart in range(600000, 900000, 1):
        # require the first 200 records to have a null-terminated printable-or-empty name
        ok = 0
        for k in range(200):
            o = itemStart + k * 41 + nameOff
            if o + 20 > n:
                break
            nm = d[o:o + 20].split(b"\x00")[0]
            if not nm or all(0x20 <= c < 0x7f for c in nm):
                ok += 1
        if ok == 200:
            if best is None or itemStart < best[1]:
                best = (nameOff, itemStart)
            break
print("\nbest (nameOff, itemStart) =", best)
if best:
    nameOff, itemStart = best
    print("  item block [%d, %d) size %d = %d records of 41" % (itemStart, n, n - itemStart, (n - itemStart) / 41))
    for k in (0, 1, 2, 0x0f, 0x2710, 0x3fff):
        o = itemStart + k * 41
        fl = struct.unpack_from("<I", d, o)[0]
        wt, layer = d[o + 4], d[o + 5]
        cnt = struct.unpack_from("<i", d, o + 6)[0]
        anim, hue, light, hgt = struct.unpack_from("<HHHB", d, o + 10)
        nm = d[o + nameOff:o + nameOff + 20]
        print(f"   item[0x{k:04X}] @{o} flags=0x{fl:08X} wt={wt} layer={layer} count={cnt} "
              f"anim=0x{anim:04X} hue={hue} light={light} h={hgt} name={nm!r}")
