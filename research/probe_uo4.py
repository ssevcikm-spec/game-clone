"""Ctvrta sonda: layouty se hledaji MRIZKOU a overuji se SAMY O SOBE.

tiledata: spravny (stride, name_off) musi davat tisice CISTYCH jmen.
hues:     jmeno ma tvar "Hue (X->Y)" a X,Y musi sedet s poli v zaznamu -
          to je sebekontrola, ktera nespoliha na dokumentaci.
cliloc:   hlavicka se overi tim, ze cisla entry jsou vzestupna a texty citelne.
"""
import json
import re
import struct
import sys
from collections import Counter
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
    if k <= 0:
        return None
    if any(c != 0 for c in chunk[k:]):
        return None
    return chunk[:k].decode("latin1")


print("=" * 78)
print("TILEDATA.MUL — mrizka (stride, name_off), hleda se cista jmena")
print("=" * 78)
td = (UO / "tiledata.mul").read_bytes()
BEST = []
for stride in range(20, 61):
    for name_off in range(0, stride - 19):
        score = 0
        for k in range(1500):
            if clean_name(td, 400000 + k * stride + name_off):
                score += 1
            if clean_name(td, 1200000 + k * stride + name_off):
                score += 1
        if score > 100:
            BEST.append((score, stride, name_off))
BEST.sort(reverse=True)
print("kandidati (skore z 3000 vzorku):")
for s, st, no in BEST[:8]:
    print(f"   stride={st:3} name_off={no:3}  cistych={s}")
R["tiledata_grid"] = BEST[:8]

if BEST:
    score, stride, name_off = BEST[0]
    print(f"\n-> stride={stride}, name_off={name_off}  (zaznam {stride} B, jmeno na konci)")
    # najdi zacatek item bloku: souvisly usek cistych jmen
    base = None
    for cand in range(0, len(td) - stride, stride):
        names = sum(1 for k in range(400)
                    if clean_name(td, cand + k * stride + name_off))
        if names > 380:
            base = cand
            break
    print(f"   zacatek prvniho souvisleho bloku: {base}")
    # zpetne: zjisti land blok
    print(f"   {base} / 0x4000 = {base / 0x4000}")
    R["tiledata_item"] = {"stride": stride, "name_off": name_off, "base": base}

    # --- extrakce vsech item jmen ---
    items = {}
    k = 0
    while True:
        off = base + k * stride
        if off + stride > len(td):
            break
        nm = clean_name(td, off + name_off)
        if nm:
            items[k] = nm
        k += 1
    print(f"   nacteno item jmen: {len(items)} z {k} recordu; posledni id={max(items)}")
    print(f"   zbyva na konci: {len(td) - (base + k * stride)} B")
    R["tiledata_item"]["count"] = k
    R["tiledata_item"]["named"] = len(items)

    # --- rozbor jednoho zaznamu: co je ve kterem bajtu? ---
    def rec(idx):
        off = base + idx * stride
        return td[off:off + stride]

    print("\n   rozbor recordu, ktere zname (hleda se, kde je layer/weight/value):")
    for want in ("leather gloves", "leather cap", "leather tunic", "leather leggings",
                 "leather sleeves", "dagger", "katana", "anvil", "black pearl",
                 "nightshade", "bandage", "gold coin", "backpack", "spellbook"):
        idxs = [i for i, n in items.items() if n.lower() == want]
        if not idxs:
            print(f"     {want:18} nenalezeno")
            continue
        i = idxs[0]
        r = rec(i)
        hexs = " ".join(f"{b:02x}" for b in r[:name_off])
        print(f"     id=0x{i:04X} {want:18} pred jmenem: {hexs}  jmeno={items[i]!r}")
    # --- hledani klicovych slov ---
    KEY = ["anvil", "forge", "ingot", "ore", "pickaxe", "shovel", "hatchet", "tongs",
           "hammer", "saw", "sewing", "mortar", "dagger", "katana", "mace", "bow",
           "arrow", "potion", "bottle", "garlic", "ginseng", "nightshade", "mandrake",
           "sulfurous", "spider silk", "black pearl", "blood moss", "gold coin",
           "backpack", "bandage", "leather", "hide", "log", "board", "cloth", "wool",
           "flax", "spool", "torch", "lantern", "rune", "scroll", "spellbook", "lockpick",
           "key", "pitcher", "flour", "dough", "fish", "apple", "bread", "cheese",
           "shield", "helm", "gorget", "tunic", "legging", "glove", "boot", "cloak",
           "robe", "ring", "bracelet", "feather", "sand", "glass", "candle"]
    print("\n   klicova slova v nazvech itemu (hledano v celem bloku):")
    hits = {}
    for kw in KEY:
        found = [(i, n) for i, n in items.items() if kw in n.lower()]
        hits[kw] = found[:10]
        print(f"     {kw:14} {len(found):5}  {[(hex(i), n) for i, n in found[:3]]}")
    R["item_keywords"] = {k: [[hex(i), n] for i, n in v] for k, v in hits.items()}
    R["item_names"] = {hex(i): n for i, n in list(items.items())}
    # --- rozlozeni hodnot bajtu pred jmenem (ktera pole jsou mala?) ---
    print("\n   statistika bajtu pred jmenem (jen nenulove, vzorek 4000):")
    sample = [rec(i) for i in list(items)[:4000]]
    for b in range(name_off):
        vals = [s[b] for s in sample]
        nz = [v for v in vals if v]
        print(f"     bajt {b:2}: nenulovych {len(nz):5}/{len(vals)}  median={sorted(nz)[len(nz)//2] if nz else 0:3}  max={max(vals):3}")
else:
    print("mrizka nic nenasla")

print()
print("=" * 78)
print("HUES.MUL — sebekontrola: jmeno 'Hue (X->Y)' musi sedet s poli zaznamu")
print("=" * 78)
hu = (UO / "hues.mul").read_bytes()
rx = re.compile(rb"Hue \((\d+)->(\d+)\)")
hue_ok = []
for base in (0, 2, 4, 6):
    for stride in (88, 86, 90, 92):
        ok = bad = 0
        examples = []
        for k in range(400):
            off = base + k * stride
            if off + stride > len(hu):
                break
            nm = clean_name(hu, off + (stride - 20))
            if not nm:
                continue
            m = rx.match(nm.encode("latin1"))
            if not m:
                continue
            cand = hu[off + stride - 24:off + stride - 20]
            s, e = struct.unpack("<HH", cand)
            if (s, e) == (int(m.group(1)), int(m.group(2))):
                ok += 1
                if len(examples) < 3:
                    examples.append((k, nm, s, e))
            else:
                bad += 1
        if ok + bad:
            hue_ok.append((ok, bad, base, stride, examples))
hue_ok.sort(reverse=True)
for ok, bad, base, stride, ex in hue_ok[:6]:
    print(f"   base={base} stride={stride}: souhlas {ok}, nesouhlas {bad}  {ex[:2]}")
if hue_ok:
    ok, bad, base, stride, ex = hue_ok[0]
    print(f"-> base={base} stride={stride}: {ok} souhlasu, {bad} nesouhlasu")
    R["hues_layout"] = {"base": base, "stride": stride, "ok": ok, "bad": bad}
    n = (len(hu) - base) // stride
    print(f"   heu v souboru: {n}  (zbyva {len(hu) - base - n * stride} B)")

print()
print("=" * 78)
print("CLILOC.ENU — hlavicka")
print("=" * 78)
cl = (UO / "Cliloc.enu").read_bytes()
print("prvnich 48 B:", cl[:48].hex(" "))
for hl in (6, 7):
    pos = 0
    rows = []
    for _ in range(10):
        if pos + hl > len(cl):
            break
        num, = struct.unpack_from("<i", cl, pos)
        flag = cl[pos + 4]
        ln, = struct.unpack_from("<H", cl, pos + 5)
        raw = cl[pos + hl:pos + hl + ln]
        if hl == 7 and ln % 2 == 0:
            txt = raw.decode("utf-16-le", "replace")
        elif hl == 6:
            txt = raw.decode("utf-16-le", "replace")
        else:
            txt = raw.decode("latin1", "replace")
        rows.append((num, flag, ln, txt[:50]))
        pos += hl + (ln if hl == 7 else ln * 2)
    print(f"   hlavicka {hl} B: {rows[:4]}")
    R.setdefault("cliloc_try", {})[hl] = rows[:6]

(OUT / "probe-uo-4.json").write_text(json.dumps(R, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nJSON: {OUT / 'probe-uo-4.json'}")
