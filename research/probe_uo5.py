"""Pata sonda: mrizka se SPRÁVNOU FAZI.

Predchozi sonda zkousela jen jednu fazi (offset 400000 mod stride), takze
spravny stride 41 vychazel jako nahoda. Tady se pro kazdy stride zkousi
VSECHNY faze a hleda se ta, na ktere lezi cista jmena.
"""
import json
import re
import struct
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")
OUT = Path(r"E:\Workspaces\game-clone\research")
PRINTABLE = set(range(32, 127))
R = {}


def clean_name(data, off, name_len=20):
    chunk = data[off:off + name_len]
    if len(chunk) < name_len or chunk[0] not in PRINTABLE:
        return None
    k = chunk.find(b"\x00")
    if k < 0:                      # jmeno presne 20 znaku, bez NUL
        return chunk.decode("latin1")
    if k == 0:
        return None
    if any(c != 0 for c in chunk[k:]):
        return None
    return chunk[:k].decode("latin1")


def grid(data, region_start, region_end, strides=range(20, 62), sample=500):
    """Pro kazdy stride a kazdou fazi spocita cista jmena."""
    out = []
    for s in strides:
        for p in range(s):
            first = region_start + ((p - region_start) % s)
            good = 0
            for k in range(sample):
                off = first + k * s
                if off + 20 > region_end:
                    break
                if clean_name(data, off):
                    good += 1
            if good >= sample * 0.30:
                out.append((good, s, p, first))
    out.sort(reverse=True)
    return out


print("=" * 78)
print("TILEDATA.MUL — mrizka s fazi")
print("=" * 78)
td = (UO / "tiledata.mul").read_bytes()
print("-- oblast 400 000 .. 1 200 000 (item blok) --")
g_item = grid(td, 400000, 1200000)
for good, s, p, first in g_item[:8]:
    print(f"   stride={s:3} faze={p:3} prvni={first:9}  cistych={good}/500")
R["grid_item"] = g_item[:8]

print("-- oblast 0 .. 400 000 (land blok) --")
g_land = grid(td, 0, 400000)
for good, s, p, first in g_land[:8]:
    print(f"   stride={s:3} faze={p:3} prvni={first:9}  cistych={good}/500")
R["grid_land"] = g_land[:8]

# --- vyber item layoutu a rozsah bloku ---
if g_item:
    good, istride, iphase, ifirst = g_item[0]
    print(f"\n-> ITEM: stride={istride}, jmeno na offsetu {iphase} (mod stride), prvni jmeno {ifirst}")
    # najdi zacatek bloku: posledni offset pred ifirst, ktery jeste patri mrizce
    start = ifirst
    while start - istride >= 0 and clean_name(td, start - istride):
        start -= istride
    print(f"   prvni CISTE jmeno v mrizce: {start}")
    # rozsah: dokud jmena (i prazdna) drzi mrizku
    end = ifirst
    while end + istride + 20 <= len(td):
        end += istride
        if end > 3200000:
            break
    named = sum(1 for o in range(start, min(end, len(td) - 20), istride) if clean_name(td, o))
    total = (min(end, len(td) - 20) - start) // istride
    print(f"   mrizka od {start} do {end}: {total} recordu, z toho {named} s cistym jmenem ({named/max(total,1):.1%})")
    R["item_layout"] = {"stride": istride, "name_phase": iphase, "first_name": ifirst,
                        "start": start, "end": end, "records": total, "named": named}
    # kolik recordu se vejde od 0x4000*k ?
    for land_len in (26, 30, 32, 34, 36):
        base = 0x4000 * land_len
        if (start - base) % istride == 0 and start >= base:
            print(f"   (kdyby land blok = {land_len} B/rec, item base = {base}, "
                  f"index prvniho jmena = {(start - base)//istride})")
    items = {}
    idx = 0
    off = start
    while off + 20 <= len(td):
        nm = clean_name(td, off)
        if nm:
            items[(off - start) // istride] = nm
        off += istride
    print(f"   nacteno {len(items)} pojmenovanych recordu, posledni id={max(items)}")
    R["item_names_count"] = len(items)

    print("\n   rozbor poli pred jmenem (u znamych predmetu):")
    for want in ("anvil", "leather gloves", "leather cap", "leather tunic", "dagger",
                 "katana", "black pearl", "nightshade", "bandage", "backpack", "gold"):
        found = [i for i, n in items.items() if n.lower() == want]
        if not found:
            continue
        i = found[0]
        off = start + i * istride
        pre = td[off:off + iphase]
        hexs = " ".join(f"{b:02x}" for b in pre)
        print(f"     id=0x{i:04X} {want:16} pred jmenem ({iphase} B): {hexs}")
    KEY = ["anvil", "forge", "ingot", "pickaxe", "shovel", "hatchet", "tongs", "sewing",
           "mortar", "dagger", "katana", "mace", "arrow", "potion", "bottle", "garlic",
           "ginseng", "nightshade", "mandrake", "sulfurous", "black pearl", "blood moss",
           "gold coin", "backpack", "bandage", "leather", "hide", "log", "board",
           "cloth", "wool", "flax", "torch", "lantern", "rune", "scroll", "spellbook",
           "lockpick", "pitcher", "flour", "dough", "shield", "helm", "gorget", "tunic",
           "legging", "glove", "boot", "cloak", "robe", "bracelet", "feather", "sand", "glass"]
    hits = {}
    print("\n   klicova slova:")
    for kw in KEY:
        f = [(i, n) for i, n in items.items() if kw in n.lower()]
        hits[kw] = [[hex(i), n] for i, n in f[:12]]
        print(f"     {kw:14} {len(f):5}  {[(hex(i), n) for i, n in f[:3]]}")
    R["item_keywords"] = hits
    R["item_names"] = {hex(i): n for i, n in items.items()}

print()
print("=" * 78)
print("HUES.MUL — sebekontrola jmeno vs. pole")
print("=" * 78)
hu = (UO / "hues.mul").read_bytes()
rx = re.compile(r"Hue \((\d+)->(\d+)\)")
results = []
for base in (0, 2, 4, 6):
    for stride in (86, 88, 90, 92, 100):
        ok = bad = 0
        ex = []
        k = 0
        while (base + (k + 1) * stride) <= len(hu):
            off = base + k * stride
            nm = clean_name(hu, off + stride - 20)
            k += 1
            if not nm:
                continue
            m = rx.match(nm)
            if not m:
                continue
            s, e = struct.unpack("<HH", hu[off + stride - 24:off + stride - 20])
            if (s, e) == (int(m.group(1)), int(m.group(2))):
                ok += 1
                if len(ex) < 2:
                    ex.append((k, nm, s, e))
            else:
                bad += 1
        if ok + bad:
            results.append((ok, bad, base, stride, ex))
results.sort(reverse=True)
for ok, bad, base, stride, ex in results[:8]:
    print(f"   base={base} stride={stride}: souhlas={ok} nesouhlas={bad} {ex[:1]}")
if results:
    ok, bad, base, stride, ex = results[0]
    n = (len(hu) - base) // stride
    print(f"-> base={base}, stride={stride}, heu={n}, zbytek={len(hu)-base-n*stride} B")
    R["hues_layout"] = {"base": base, "stride": stride, "ok": ok, "bad": bad, "count": n}
    hues = []
    for k in range(n):
        off = base + k * stride
        s, e = struct.unpack("<HH", hu[off + stride - 24:off + stride - 20])
        nm = clean_name(hu, off + stride - 20) or ""
        cols = list(struct.unpack_from("<32H", hu, off))
        hues.append({"id": k, "start": s, "end": e, "name": nm, "colors": cols})
    R["hues_sample"] = hues[:6] + hues[100:102]
    print("   prvni 4 heu:", [(h["id"], h["name"], h["start"], h["end"],
                               [hex(c) for c in h["colors"][:4]]) for h in hues[:4]])

print()
print("=" * 78)
print("CLILOC.ENU")
print("=" * 78)
cl = (UO / "Cliloc.enu").read_bytes()
print("prvnich 32 B:", cl[:32].hex(" "))
pos = 0
ok7 = []
for _ in range(12):
    if pos + 7 > len(cl):
        break
    num, = struct.unpack_from("<i", cl, pos)
    flag = cl[pos + 4]
    ln, = struct.unpack_from("<H", cl, pos + 5)
    raw = cl[pos + 7:pos + 7 + ln]
    txt = raw.decode("utf-16-le", "replace")
    ok7.append((num, flag, ln, txt[:60]))
    pos += 7 + ln
print("hlavicka 7 B (int32 cislo, 1 B flag, uint16 delka v BAJTECH):")
for r in ok7[:8]:
    print("   ", r)
R["cliloc7"] = ok7

(OUT / "probe-uo-5.json").write_text(json.dumps(R, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nJSON: {OUT / 'probe-uo-5.json'}")
