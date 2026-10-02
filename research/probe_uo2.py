"""Druha sonda: presne overi layouty, ktere prvni sonda nechala otevrene.

Metoda: kandidatni layout se nevybira dojmem, ale tim, ze se na nem
pocitaji CITELNA jmena (prvni znak tisknutelny, NUL, zbytek pole NUL).
Spatny stride dava ~0, spravny >0,9. Vse se zapisuje do JSON.
"""
import json
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


def find_strings(data, min_len=3, max_len=20):
    out, n, i = [], len(data), 0
    while i < n:
        if data[i] in PRINTABLE:
            j = i
            while j < n and data[j] in PRINTABLE and (j - i) < max_len:
                j += 1
            if data[j:j + 1] == b"\x00" and (j - i) >= min_len:
                out.append((i, data[i:j].decode("latin1")))
                i = j + 1
                continue
            i = j
        else:
            i += 1
    return out


def score_names(data, base, stride, name_off, count):
    """Podil recordu, jejichz jmeno je cisty ASCII retezec ukonceny NUL."""
    good = total = 0
    for i in range(count):
        off = base + i * stride + name_off
        chunk = data[off:off + 20]
        if len(chunk) < 20:
            break
        total += 1
        if chunk[0] in PRINTABLE:
            k = chunk.find(b"\x00")
            if k > 0 and all(c == 0 for c in chunk[k:]):
                good += 1
    return good, total, round(good / max(total, 1), 4)


def read_names(data, base, stride, name_off, count):
    names = {}
    for i in range(count):
        off = base + i * stride + name_off
        chunk = data[off:off + 20]
        if len(chunk) < 20:
            break
        nm = chunk.split(b"\x00")[0].decode("latin1").strip()
        if nm:
            names[i] = nm
    return names


print("=" * 74)
print("TILEDATA.MUL — hledani layoutu")
print("=" * 74)
td = (UO / "tiledata.mul").read_bytes()
print(f"velikost {len(td)} B")

print("\n-- LAND blok (predpoklad base=0, 0x4000 zaznamu) --")
land_results = []
for stride in (26, 30, 32, 34, 36):
    for name_off in sorted({stride - 20, 6, 10}):
        if name_off < 0:
            continue
        g, t, r = score_names(td, 0, stride, name_off, 0x4000)
        land_results.append((r, stride, name_off, g, t))
        print(f"   stride={stride:3} name_off={name_off:3}  citelnych {g:6}/{t}  = {r}")
land_results.sort(reverse=True)
best_land = land_results[0]
print(f"-> NEJLEPSI: stride={best_land[1]} name_off={best_land[2]} ({best_land[0]})")
R["land"] = {"best": best_land[:3], "all": land_results}

print("\n-- ITEM blok (predpoklad stride=41 z prvni sondy) --")
item_results = []
for land_stride in (26, 30, 32, 34):
    base = 0x4000 * land_stride
    for count in (0x4000, 0x10000):
        g, t, r = score_names(td, base, 41, 21, count)
        item_results.append((r, land_stride, base, count, g, t))
        print(f"   base={base:9} (land {land_stride}) count={count:6}  citelnych {g:6}/{t} = {r}")
item_results.sort(reverse=True)
best_item = item_results[0]
print(f"-> NEJLEPSI: base={best_item[2]} count={best_item[3]} ({best_item[0]})")
R["item"] = {"best": best_item[:4], "all": item_results}

# reziduum retezcu mod 41 v druhe polovine -> potvrzeni name_off
pairs = find_strings(td)
tail = [(o, s) for o, s in pairs if o > best_item[2]]
res = Counter(o % 41 for o, _ in tail)
print(f"\nrezidua offsetu retezcu mod 41 (2. polovina): {res.most_common(4)}")
R["item_residue"] = res.most_common(4)

item_names = read_names(td, best_item[2], 41, 21, best_item[3])
land_names = read_names(td, 0, best_land[1], best_land[2], 0x4000)
print(f"nacteno jmen: land={len(land_names)} item={len(item_names)}")
print(f"posledni item jmeno: id={max(item_names)} '{item_names[max(item_names)]}'")
tail_bytes = len(td) - (best_item[2] + best_item[3] * 41)
print(f"zbyva na konci souboru: {tail_bytes} B")
R["item_names_count"] = len(item_names)
R["item_last"] = [max(item_names), item_names[max(item_names)]]
R["tail_bytes"] = tail_bytes

# --- kontrolni vzorek: jmena zname z UO ---
print("\n-- kontrolni vzorek item jmen (ocekavame zname UO predmety) --")
for tid in (0x0F52, 0x0F5E, 0x0F61, 0x13B9, 0x0F51, 0x0F43, 0x1B72, 0x0EED, 0x0F7A, 0x0F7B):
    print(f"   0x{tid:04X} = {item_names.get(tid, '(prazdne)')!r}")

# --- hledani klicovych slov v item nazvech ---
KEYWORDS = {
    "ore": ["ore"], "ingot": ["ingot"], "forge": ["forge"], "anvil": ["anvil"],
    "log": ["log"], "board": ["board"], "hide": ["hide"], "leather": ["leather"],
    "cloth": ["cloth", "bolt of"], "bandage": ["bandage"], "pickaxe": ["pickaxe", "pick axe"],
    "shovel": ["shovel"], "hatchet": ["hatchet"], "axe": ["axe"], "hammer": ["hammer"],
    "tongs": ["tongs"], "saw": ["saw"], "sewing": ["sewing"], "mortar": ["mortar"],
    "dagger": ["dagger"], "sword": ["sword"], "katana": ["katana"], "mace": ["mace"],
    "bow": ["bow"], "arrow": ["arrow"], "bolt": ["bolt"], "potion": ["potion"],
    "bottle": ["bottle"], "reagent": ["reagent"], "garlic": ["garlic"], "ginseng": ["ginseng"],
    "nightshade": ["nightshade"], "mandrake": ["mandrake"], "sulfur": ["sulfur"],
    "spider silk": ["spider silk"], "black pearl": ["black pearl"], "blood moss": ["blood moss"],
    "gold": ["gold"], "backpack": ["backpack"], "bag": ["bag"], "chest": ["chest"],
    "key": ["key"], "lockpick": ["lockpick"], "spellbook": ["spellbook"], "scroll": ["scroll"],
    "rune": ["rune"], "fish": ["fish"], "flour": ["flour"], "dough": ["dough"],
    "water": ["water"], "pitcher": ["pitcher"], "torch": ["torch"], "lantern": ["lantern"],
    "shield": ["shield"], "helm": ["helm"], "gorget": ["gorget"], "tunic": ["tunic"],
    "legging": ["legging"], "glove": ["glove"], "boot": ["boot"], "cloak": ["cloak"],
    "robe": ["robe"], "ring": ["ring"], "bracelet": ["bracelet"], "candle": ["candle"],
    "pouch": ["pouch"], "board": ["board"], "feather": ["feather"], "wool": ["wool"],
    "spool": ["spool"], "flax": ["flax"], "sand": ["sand"], "glass": ["glass"],
}
found = {}
for key, words in KEYWORDS.items():
    hits = []
    for tid, nm in item_names.items():
        low = nm.lower()
        if any(w in low for w in words):
            hits.append((tid, nm))
    found[key] = hits[:14]
    print(f"   {key:12} {len(hits):5} nalezu  {[hex(t) for t, _ in hits[:6]]}")
R["keyword_hits"] = {k: [[hex(t), n] for t, n in v] for k, v in found.items()}

print()
print("=" * 74)
print("HUES.MUL — hledani stridy (barevny rampa = monotonni)")
print("=" * 74)
hu = (UO / "hues.mul").read_bytes()
vals = struct.unpack_from(f"<{len(hu)//2}H", hu, 0)
hue_results = []
for stride in (64, 66, 88, 90, 96, 100):
    rows = 3000
    if rows * stride + stride > len(hu):
        rows = len(hu) // stride - 1
    mono = 0
    for i in range(0, rows, 7):
        base = i * (stride // 2)
        row = vals[base:base + 32]
        if len(row) < 32:
            break
        asc = sum(1 for a, b in zip(row, row[1:]) if b >= a)
        desc = sum(1 for a, b in zip(row, row[1:]) if b <= a)
        if max(asc, desc) >= 26:
            mono += 1
    tested = len(range(0, rows, 7))
    hue_results.append((round(mono / max(tested, 1), 3), stride, rows))
    print(f"   stride={stride:4} heu={rows:5} monotonnich={mono:5}/{tested}")
hue_results.sort(reverse=True)
print(f"-> NEJLEPSI stride: {hue_results[0]}")
R["hues"] = {"best": hue_results[0], "all": hue_results, "size": len(hu)}
best_stride = hue_results[0][1]
print("prvnich 32 hodnot prvni hue:", [hex(v) for v in vals[:8]])
for i in (0, 1, 2, 100):
    row = vals[i * (best_stride // 2): i * (best_stride // 2) + 32]
    if len(row) == 32:
        print(f"   hue {i:5}: min={min(row):#06x} max={max(row):#06x} prvni={[hex(v) for v in row[:6]]}")

print()
print("=" * 74)
print("SKILLS.MUL — poradi dovednosti")
print("=" * 74)
sk = (UO / "skills.mul").read_bytes()
sk_pairs = find_strings(sk, min_len=2, max_len=32)
skill_names = [s for _, s in sk_pairs]
print(f"{len(skill_names)} retezcu:")
for i, s in enumerate(skill_names):
    print(f"   {i:2} {s}")
R["skill_names"] = skill_names

print()
print("=" * 74)
print("CLILOC.ENU — hledani spravne hlavicky")
print("=" * 74)
cl = (UO / "Cliloc.enu").read_bytes()
print(f"velikost {len(cl)} B")


def try_cliloc(header_len, len_in_chars, start=0, entries=8):
    pos = start
    out = []
    for _ in range(entries):
        if pos + header_len > len(cl):
            break
        num, = struct.unpack_from("<i", cl, pos)
        flag = cl[pos + 4]
        ln, = struct.unpack_from("<H", cl, pos + 5)
        nbytes = ln * 2 if len_in_chars else ln
        raw = cl[pos + header_len:pos + header_len + nbytes]
        try:
            text = raw.decode("utf-16-le")
        except Exception:
            text = "<decode error>"
        out.append((num, flag, ln, text[:60]))
        pos += header_len + nbytes
    return out


for hl, chars in ((6, True), (6, False), (7, True), (7, False)):
    res = try_cliloc(hl, chars)
    printable = sum(1 for r in res if r[3] and all(32 <= ord(c) < 127 or c in " " for c in r[3]))
    nums = [r[0] for r in res]
    print(f"   header={hl} len_in_chars={chars}: cisla={nums} tisknutelnych={printable}/{len(res)}")
    if printable >= len(res) - 1 and len(res) > 2:
        for r in res[:6]:
            print("        ", r)
        R["cliloc"] = {"header_len": hl, "len_in_chars": chars, "first": res}
        break

(OUT / "probe-uo-2.json").write_text(json.dumps(R, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nJSON: {OUT / 'probe-uo-2.json'}")
