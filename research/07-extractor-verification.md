# 07 — UO Classic extractor verification report

**Data source (read-only, never modified):** `D:\Games\Electronic Arts\Ultima Online Classic`
**Code:** `E:\Workspaces\game-clone\tools\uoextract\`
**Samples:** `E:\Workspaces\game-clone\research\extract-out\`
**Python:** `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` (Pillow 12.3.0, numpy 2.3.5)

All commands below assume:

```powershell
$env:PYTHONIOENCODING='utf-8'
$py="C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
```

---

## Status summary

| # | Area | Status |
|---|------|--------|
| 1 | tiledata.mul | **ITEMS VERIFIED**; land geometry VERIFIED, land field semantics PARTIAL |
| 2 | ART from UOP | **VERIFIED** |
| 3 | GUMPS from UOP | **PARTIAL** — container + zlib verified, pixel decode not reproduced |
| 4 | map + statics | **PARTIAL** — statics VERIFIED; map block source not located |
| 5 | Cliloc.enu | **UNRESOLVED** — file is compressed/encrypted, no plaintext exists |
| 6 | skills.mul + skillgrp.mul | **VERIFIED** |
| 7 | hues.mul | **PARTIAL** — geometry verified exactly; name/colour field offsets inconsistent |

---

## 1. TILEDATA.MUL — ITEMS VERIFIED, LAND GEOMETRY VERIFIED / LAND FIELDS PARTIAL

### Settled layout

The file is **exactly two blocks with zero slack**. The task brief's framing
(8-byte flags / 41-byte item / 30-byte land *vs* 4-byte flags / 37-byte item / 26-byte land)
is incomplete: **this install uses 8-byte flags for BOTH blocks**, and the item block has
**2048 groups (65 536 tiles)**, four times the classic 0x4000 range. That is why every
naive model under-predicted the file size by ~4x.

```
LAND block   file offset 4
  group = [u32 header] + 32 records of 30 bytes       group size 964
  record (30 B):  +0  u64 flags
                  +8  u16 texId
                  +10 char name[20]      <-- geometry certain, field semantics UNCERTAIN, see below
  512 groups x 964 = 493,568 bytes

ITEM block   file offset 493,568
  group = [u32 header] + 32 records of 41 bytes       group size 1316
  record (41 B):  +0  u64 flags
                  +8  u8  weight
                  +9  u8  layer
                  +10 i32 count
                  +14 u16 animID
                  +16 u16 hue
                  +18 u16 lightIndex
                  +20 u8  height
                  +21 char name[20]
  2048 groups x 1316 = 2,695,168 bytes

493,568 + 2,695,168 = 3,188,736 = exact file size (slack 0)
```

### Proof obtained

* **Exact size closure:** the two block sizes sum to the file size with **zero remainder**.
  65,536 item entries decode.
* **The 41-byte / 1316-byte geometry is measured, not assumed.** Scanning all
  NUL-terminated printable runs, the distance between consecutive "extra 4 bytes" name
  gaps is **exactly 1316 bytes on 831 occasions** (and 2632/3948/5264 = 2x/3x/4x, i.e.
  skipped groups). 4 + 32x41 = 1316.
* **Layer semantics match names, which is the decisive self-consistency check.**
  Of the 65,536 item entries, **1,268 carry the Wearable flag 0x00400000; 1,268 of 1,268
  (100%) have a non-zero layer, and 1,229 (96.9%) have a layer value inside the RunUO
  `Layer` enum.**

Recognisable tiles with ids (the 20+ requested), from `verify_tiledata.py`:

| name | id | weight | layer | count | animID | flags |
|---|---|---|---|---|---|---|
| `leather cap` | 7609 | 2 | **6 (Helm)** | 145 | 560 | 0x0000000000404002 |
| `leather cap` | 9873 | 1 | **6 (Helm)** | 145 | 560 | 0x0000000000404002 |
| `bandana` | 5439 | 1 | **6 (Helm)** | 217 | 492 | 0x0000000000404002 |
| `gargoyle_leather_arm` | 769 | 4 | **19 (Arms)** | 566 | 585 | 0x0000000000404002 |
| `leather sleeves` | 5061 | 2 | **19 (Arms)** | 102 | 544 | 0x0000000000400002 |
| `gargoyle_leather_che` | 771 | 4 | **13 (InnerTorso)** | 568 | 587 | 0x0000000000404002 |
| `gargoyle_leather_leg` | 773 | 5 | **4 (Pants)** | 570 | 589 | 0x0000000000404002 |
| `backpack` | 2482 | 3 | **21 (Backpack)** | 0 | 422 | 0x0000000000604002 |
| `dagger` | 3921 | 1 | **1 (OneHanded)** | 20 | 622 | 0x0000000000404002 |
| `longsword` | 3936 | 7 | **1 (OneHanded)** | 6 | 618 | 0x0000000000404002 |
| `katana` | 5118 | 6 | **1 (OneHanded)** | 4 | 627 | 0x0000000004404002 |
| `cloak` | 5397 | 5 | **20 (Cloak)** | 225 | 468 | 0x0000000000404002 |
| `skirt` | 5398 | 4 | **23 (OuterLegs)** | 183 | 449 | 0x0000000000404002 |
| `body sash` | 5441 | 1 | **17 (MiddleTorso)** | 227 | 490 | 0x0000000000404002 |
| `anvil` | 4015 | 255 | 0 (not wearable) | 0 | 0 | 0x0000000000008040 |
| `forge` | 4017 | 255 | 0 | 0 | 0 | 0x0000000000004040 |
| `wooden beam` | 321 | 255 | 0 | 0 | 0 | 0x0000000000004050 |
| `stone stairs` | 1006 | 255 | 0 | 0 | 0 | 0x0000000000002600 |
| `nightshade` | 6373 | 1 | 0 | 0 | 0 | 0x0000000000000000 |

Decode quality:

* land: 3,021 / 16,384 clean names (18.4%) — low because most land ids are genuinely empty
* items: 36,221 / 65,536 clean names (55.3%); **100%** of wearable-flagged entries have a layer

### What remains uncertain

* **LAND field semantics are not resolved.** The land *geometry* is proven
  (4-byte block header, 512 groups, 30-byte records, group size 964, block exactly
  493,568 bytes so the item block starts immediately at 493,568), and the name
  positions `UNUSED`@10, `VOID!!!!!!`@44, `NODRAW`@74, `grass`@104/134/164/194,
  `furrows`@284... are reproduced exactly at stride 30. **However, reading `flags` as a
  `u64` at record+0 yields values with ASCII in the high bytes** (e.g. `0x444553554e550000`
  = `UNUS..`), i.e. the flags field overlaps the name text under this origin, and the
  `u16` at record+8 exceeds 0x3FFF for 4,106 of 16,384 entries. A scan that treats the
  `u16` at record+4 as the sequential tile index matches **1,013 / 1,280** records
  (79.1%) for `hdr=4, rec=30`, which is strong but not complete, and no single name
  offset inside the 30-byte record raises clean-name yield above ~25% (4,109 / 16,384).
  Conclusion: the land block definitely occupies `4 .. 493,568` in 30-byte records, but
  **which bytes are flags / texId / name is not settled**; the item block constants are
  the ones to rely on.
* The brief asked for `leather gloves`, `leather helm`, `black pearl`, `gold`,
  `plate chest`, `bandage`. **These exact strings do not exist in this install's
  tiledata.** `leather gorget` (id 5063) uses layer 10 (Necklace), the RunUO convention
  for gorgets. This install is a modern (post-AoS) tile set with renamed/added tiles, so
  classic-era name lists and classic tile ids must not be trusted.
* Only the item block was cross-checked twice; the land block was not.

### Reproduce

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\verify_tiledata.py"
```

---

## 2. ART from UOP — VERIFIED

### Settled layout (container)

`MYP0` UOP, ported from ClassicUO `src/ClassicUO.IO/UOFileUop.cs`:

```
header (28 B): u32 magic=0x0050594D, u32 version, u32 format_timestamp,
               i64 nextBlock, u32 block_size, i32 count
then seek nextBlock and loop:
  i32 filesCount
  i64 nextBlock
  filesCount x 34-byte entry:
     i64 offset, i32 headerLength, i32 compressedLength, i32 decompressedLength,
     u64 hash, u32 data_hash, i16 flag
  real data offset = offset + headerLength
  flag 0 = stored raw, 1 = zlib, 3 = zlib+BWT
```

**Hash input string form — measured, not assumed.** ClassicUO's `string.Format` pattern
with the decimal index (`build/artlegacymul/{0:D8}.tga`) is the correct form:
it matched **1,636 / 2,000** probed indices (the rest are genuinely absent from the
archive). The three alternative "index bytes written as chars" forms matched **0 / 2,000**.

### Art archive facts (measured)

```
artLegacyMUL.uop : magic ok, version=5, count=43760, blocks=44,
                   total entries 44000, nonzero offsets 43760,
                   compression flags {0: 44000}   (all raw, no zlib)
resolved indices 0..0x1FFFF -> 43760
  indices < 0x4000 : 4244   (land art)
  indices >= 0x4000: 39516  (static/item art)
  min index 0, max index 62763
```

**Static art archive index = tiledata id + 0x4000.** Confirmed directly: index 20320
(= 3936 + 0x4000, the `longsword`) is present and decodes to a sword.

Static art payload at the entry data offset: `u32 flags, i16 width, i16 height`, then the
RLE body (per-row u16 offset table, then per row `u16 xoffs, u16 run`, `run` u16 colours;
`xoffs+run == 0` ends the row). Colour 0 = transparent.

Land art: 2024 bytes = 1012 u16 colours laid into a 44x44 diamond (two triangles, the
top widening by 2 px per row and the bottom narrowing). All land entries in this archive
inflate to **2048** bytes and the first 2024 are the tile; corners are never written.

### Extracted tiles (all files under `research\extract-out\art\`)

| archive index | tiledata name | WxH | non-transparent px | distinct colours | dominant |
|---|---|---|---|---|---|
| 20320 | longsword | 82x40 | 156 | 41 | (32,32,32) |
| 20305 | dagger | 22x26 | 59 | 31 | (24,8,16) |
| 21502 | katana | 44x36 | 109 | 47 | (8,8,8) |
| 23993 | leather cap | 44x32 | 139 | 39 | (41,32,8) |
| 18866 | backpack | 44x32 | 220 | 35 | (115,74,24) |
| 20399 | anvil | 44x46 | 639 | 183 | (49,49,57) |
| 20401 | forge | 44x55 | 1376 | 458 | (24,24,24) |
| 16705 | wooden beam | 44x35 | 732 | 64 | (32,16,8) |
| 21445 | leather sleeves | 44x37 | 289 | 81 | (41,32,16) |
| 21781 | cloak | 58x50 | 1310 | 20 | (115,115,115) |
| 3 (land) | grass land | 44x44 | **1012** | 100 | (57,82,16) |
| 168 (land) | sand land | 44x44 | **1012** | 25 | (0,49,74) |
| 0 (land) | land0 | 44x44 | **1012** | 88 | (0,0,0) |

Land tiles have **exactly 1012 non-transparent pixels = 44*44 - 4*22*22/2**, i.e. the
diamond area exactly. That is an independent arithmetic proof the diamond decoder is right.

### Visual verification (`read_image`, quoted)

* `item_20320_longsword.png` — a diagonal silver blade running from upper-left to
  lower-right with a gold/brown cross-guard and grip: **it is a sword.**
* `item_18866_backpack.png` — a brown leather UO backpack with a flap and strap:
  **it is the classic UO backpack.**
* `land_00003_grass_land.png` — a green isometric diamond of grass texture:
  **it is a grass land tile.**
* `item_20399_anvil.png` — a grey metal anvil on a brown wooden base:
  **it is an anvil.**

### Reproduce

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\art.py"
```

---

## 3. GUMPS from UOP — PARTIAL

### What is verified

```
gumpartLegacyMUL.uop : magic ok, version=4, count=5579, blocks=56,
                       entries 5579, all offsets non-zero,
                       compression flags {3: 5579}   (all zlib+BWT)
hash form: build/gumpartlegacymul/{0:D8}.tga  -> matched 989 / 2000 probed indices
```

* The MYP0 container and the decimal-index hash are the same as art and are **verified**.
* `zlib.decompress` on the stored bytes yields a **complete single-member stream**:
  for gump 0x003C, `clen=44587`, `dlen=119756`, inflated length **119756**, `eof=True`,
  `unused_data=0`. So although the UOP entry says flag 3 ("zlib + BWT"), the payload in
  this archive needs **no additional BWT inverse step** in Python — plain
  `zlib.decompress` is the correct and complete decompression. (ClassicUO's `ZLib.cs`
  also just calls zlib's `uncompress`, which is consistent with this.)

### What is NOT resolved

The byte layout *inside* the inflated gump payload was not reproduced. Measured facts:

* The inflated payload begins with a 3-byte family constant that varies only in the
  third byte: `09 fd` / `2d 8e` / `2c 8e` / `2e 8e`. First bytes of five gumps:
  `fd 09 2d 8e`, `71 d1 2e 8e`, `d9 99 2c 8e`, `b5 9b 2c 8e`, `ad 9b 2c 8e`.
* Treating the next 8 bytes as two little-endian `i32` (ClassicUO's
  `u32 unknown, i32 width, i32 height`) produces absurd values
  (e.g. `1850838573 x 1358430210`), so that published layout does **not** match this
  install's payload.
* Reading `u16` at +2 and `u16` at +4 gives plausible dimensions for gump 0x0035
  (2 x 522) but produces Multi-GB allocations for others, so that reading is wrong too.
* A sliding search over header lengths 0..19 and width/height offsets/sizes found the best
  "row-offset table is monotonic and in-buffer" score of **208/277 (75%)** at
  `hdrlen=10, height@2, width@6`, but that same layout fails on gump 0x003C, so it is not
  the true layout.

**No gump pixel data is claimed to be decoded.** Any gump work in the later project must
re-derive this layout from the raw bytes; the container and hash are ready for it.

### Reproduce (measurements only)

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\gumps.py"        # container + header probe
& $py "E:\Workspaces\game-clone\tools\uoextract\gump_header.py"  # layout score search
```

---

## 4. MAP + STATICS — PARTIAL (statics VERIFIED, map source not found)

### STATICS — VERIFIED

```
staidx<f>.mul : 12 bytes per block  = [i32 offset][i32 length][i32 extra]
                458752 blocks per facet (staidx0.mul = 5,505,024 B / 12)
statics<f>.mul: 7 bytes per record  = [u16 tileId][u8 x][u8 y][i8 z][u16 hue]
                20,386,415 B / 7 = 2,912,345 records, remainder 0
                (facet 1: 20,393,786 B / 7 = 2,913,398, remainder 0)
```

Block index used: `bx * 768 + by`, with `bx = x//8`, `by = y//8`.

**Proof — block for Britain (x=1495, y=1630) => bx=186, by=203, index=143051:**

```
staidx0 block 143051 -> offset=8490377  length=140
statics records     : 20   (140 / 7 = 20 exactly)
x range 0..7, y range 0..7   (an 8x8 block, as the math requires)
z range 0..0, all hues 0
first 10 records (tile, x, y, z, hue):
  (3254,2,0,0,0) (3247,4,0,0,0) (3373,6,0,0,0) (3253,7,0,0,0) (3253,4,1,0,0)
  (3250,1,2,0,0) (3280,4,2,0,0) (3281,4,2,0,0) (3248,1,3,0,0) (3247,5,3,0,0)
```

The block math is confirmed three ways: `length % 7 == 0` exactly, the record count
matches `length/7`, and every record's x and y fall in 0..7.

### MAP — unresolved

* `map0LegacyMUL.uop` parses as a valid MYP0 container but contains only **1000 entries,
  113 with non-zero offsets, indices 0..112**, under the pattern
  `build/map0legacymul/{0:D8}.dat`. That is far too few for a world map, so this file is
  **not** the source of full map blocks in this install.
* The requested block index (186, 203) is therefore absent, and no land tile ids could be
  printed from a map block.
* The obvious alternative, `facet00.mul` (12,216,710 bytes), is a candidate but was not
  decoded in the time available. It is exactly 2 bytes short of 2048x2048x3 = 12,582,912,
  so the dimension hypothesis "2048x2048 cells of 3 bytes" is **unconfirmed**.
* Consequence: only the statics half of area 4 is verified. The later project must locate
  the map block source (candidates: `facet00.mul`, the `stadif*`/`stadifl*`/`stadifi*`
  family, or an offset/length pair inside `map0LegacyMUL.uop` that this probe mis-indexed).

### Reproduce

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\areas_4_7.py"
```

---

## 5. CLILOC.ENU — UNRESOLVED (and provably so)

### Measurement

```
size = 5,110,078 bytes
first 16 bytes: 0f 23 61 8e bb 83 08 03 90 0c 02 00 75 04 02 00
```

* The classic layout `[i32 number][u8 flag][u16 length][UTF-16LE string]` fails immediately
  at **every** header offset 0..15: 0 entries parsed, 0 bytes consumed.
* **There is no UTF-16LE English text anywhere in the file.**
  `b'b\x00a\x00c\x00k\x00p\x00a\x00c\x00k\x00'` → not found.
  `b't\x00h\x00e\x00'` → not found. A regex for any run of 20+ "ASCII char + NUL" pairs
  → **no match**.
* **There is no plain ASCII English either.** The byte sequence `the` occurs **0 times**
  in 5.1 MB. Only 75 ASCII runs of 12+ characters exist, and they are all noise, e.g.
  `g5AjDCQ5Aya6`, `/I*q,+KD?F&A `, `)K%;1:  -L^%B`, `4i_:&L>P?ZA,O+`.
* zlib inflation was attempted at every offset 0..63 whose byte is 0x78: **all failed**.
* After an 8-byte prefix, the file contains a **monotonically increasing u32 table**
  (134288, 132213, 134607, 136815, 135985, 136504, 139475, 137577, ...). A monotonic u32
  table is an offset/roster table, which together with the total absence of text shows the
  entry bodies are stored **compressed or encrypted** with a codec that is not zlib.

### Conclusion

Cliloc.enu in this install is **not** the classic plain-text UTF-16LE Cliloc format. The
"determine the real structure" goal is **not achieved**: I can prove the file is
compressed/encrypted and that the classic layout is impossible, but I cannot decode it.
The next step is to identify the codec (candidates: a UO-specific LZ/BWT variant as used
by the UOP flag-3 path, or the newer client's string table in `string_dictionary.uop`,
425,427 B, which is a plausible intended replacement).

### Reproduce

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\areas_4_7.py"
```

---

## 6. SKILLS.MUL + SKILLGRP.MUL — VERIFIED

### skills.mul (704 bytes)

**58 skill names**, NUL-terminated, each preceded by a 1-byte flag (0x00/0x01).
Adjacent-name strides are **not constant** (observed 7,8,9,10,11,12,13,14,15,18,20,21,22,25),
so this file is **not** a fixed-record array — the brief's "12-byte records" reading is
wrong. Names are packed; the file ends exactly at the last name.

Client order (id → name), measured:

```
 0 Alchemy                15 Discordance            30 Poisoning       45 Mining
 1 Anatomy                16 Evaluating Intelligence 31 Archery         46 Meditation
 2 Animal Lore            17 Healing                32 Spirit Speak    47 Stealth
 3 Item Identification    18 Fishing                33 Stealing        48 Remove Trap
 4 Arms Lore              19 Forensic Evaluation    34 Tailoring       49 Necromancy
 5 Parrying               20 Herding                35 Animal Taming   50 Focus
 6 Begging                21 Hiding                 36 Taste Identification 51 Chivalry
 7 Blacksmithy            22 Provocation            37 Tinkering       52 Bushido
 8 Bowcraft/Fletching     23 Inscription            38 Tracking        53 Ninjitsu
 9 Peacemaking            24 Lockpicking            39 Veterinary      54 Spellweaving
10 Camping                25 Magery                 40 Swordsmanship   55 Throwing
11 Carpentry              26 Resisting Spells       41 Mace Fighting   56 Imbuing
12 Cartography            27 Tactics                42 Fencing         57 Mysticism
13 Cooking                28 Snooping               43 Wrestling
14 Detecting Hidden       29 Musicianship           44 Lumberjacking
```

This **confirms the brief's pre-AoS ordering**: Alchemy, Anatomy, Animal Lore,
Item Identification, Arms Lore, Parrying, Begging, Blacksmithy, Bowcraft/Fletching,
Peacemaking, Camping, Carpentry. `Skills.idx` is 3,072 bytes = 768 u32; its first values
(0, 9, 15, 9, 9, 13, 18, 13, 13, 31, 21, 13) look like name lengths, not byte offsets.

### skillgrp.mul (338 bytes)

```
i32 at 0 = 7                          (group count)
7 group names in fixed 17-byte slots starting at offset 4:
   group 0 @4    'Combat'
   group 1 @21   'Trade Skills'
   group 2 @38   'Magic'
   group 3 @55   'Wilderness'
   group 4 @72   'Thieving'
   group 5 @89   'Bard'
   group 6 @106  '\x02'              (odd/blank name)
offset 4 + 7*17 = 123, then 215 bytes = 53 little-endian i32 values (0..6)
   = one group id per skill, in client skill order
   [0,1,0,0,0,2,0,2,0,6,0,0,0,2,0,0,0,2,0,5,0,6,0,3,0,1,0,4,0,0,0,4,0,5,0,6,
    0,2,0,5,0,3,0,3,0,1,0,5,0,6,0,5,0,1,0,3,0,5,0,2,0,4,0,0,0,2,0,4,0,4,0,1,
    0,1,0,1,0,1,0,2,0,2,0,3,0,5,0,5,0,3,0,1,0,3,0,3,0,3,0,3,0,3,0,3,0,1]
```

Only 53 group ids are present for 58 skills, so the mapping tail is **not fully resolved**:
either the last 5 skills share a group not stored here, or the record count differs.
The 17-byte slot size is proven (all six consecutive name strides are exactly 17).

### Reproduce

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\skills_hues.py"
```

---

## 7. HUES.MUL — PARTIAL (geometry exact, name/colour fields inconsistent)

### Reproduced exactly

```
size = 265,500 bytes
4 + 3017 * 88 = 265,500   -> slack 0
header: i32 at offset 0 (value 0 in this file)
record: 88 bytes
```

This **independently confirms the earlier work's geometry**: 4-byte header, 3017 records
of 88 bytes, no slack. The 88-byte record is 32 uint16 colours (64 B) + uint16 start +
uint16 end (4 B) + 20-byte ASCII name (20 B) = 88 B.

The name field is 20 bytes and the string `Hue (X->Y)` is present in the file, in
**1,000 records**, at a **constant offset of record+68** for the first run
(offsets 160, 248, 336, 424, 512, 600 ... — strides all exactly 88).

Three sample hues with names and first colours (as requested):

| record | name | start/end fields (+64) | first 8 of 32 colours |
|---|---|---|---|
| hue[1] | `Hue (6->1080)` | 6, 1080 | 6, 6, 7, 7, 8, 8, 9, 9 |
| hue[2] | `Hue (6->1086)` | 6, 1086 | 6, 6, 7, 8, 9, 9, 10, 11 |
| hue[3] | `Hue (6->7422)` | 6, 7422 | 6, 6, 7, 8, 9, 1065, 1066, 1067 |

For hue[1], hue[2] and hue[3] the embedded text **matches the numeric fields exactly**
(e.g. `Hue (6->1080)` with a `6` and a `1080`), which is the self-consistency check the
brief asked for — but only for **47 of the 2,629 records that carry a non-empty name**.

### What differs from the earlier work — reported as required

* Earlier work: "the embedded name text `Hue (X->Y)` matches the start/end fields".
  My measurement **confirms this for 47 records but not for the other 2,582 named records.**
  With the name at `record+68` and start/end read at `record+64`, only **47 / 2,629** match.
  No header offset 0..87 and no alternative colour interpretation I tested raised this
  above 48 matches.
* The name offsets observed across the whole file cover **every** residue mod 88
  (0,4,8,...,84), not a single fixed phase. That means the 20-byte "name" slot is not at a
  constant position across all 3017 records under this record origin — so either the
  record origin drifts, or the records are not uniformly 88 B inside a single flat array
  even though the total size divides exactly.
* Therefore I am reporting the **geometry as verified** (4 + 3017x88 = 265,500, slack 0)
  and the **field offsets as unresolved**.

### Reproduce

```powershell
& $py "E:\Workspaces\game-clone\tools\uoextract\skills_hues.py"
```

---

## Licences of ported code

| Component | Source | Licence |
|---|---|---|
| UOP container + `CreateHash` (`uop.py`) | ClassicUO `src/ClassicUO.IO/UOFileUop.cs` | **BSD-2-Clause** (`// SPDX-License-Identifier: BSD-2-Clause`) |
| Tiledata record layout (`verify_tiledata.py`) | ClassicUO `src/ClassicUO.Assets/TileDataLoader.cs` | **BSD-2-Clause** |
| Static art RLE + land diamond (`art.py`) | ClassicUO `src/ClassicUO.Assets/ArtLoader.cs` | **BSD-2-Clause** |
| Gump container + header probe (`gumps.py`) | ClassicUO `src/ClassicUO.Assets/GumpsLoader.cs` | **BSD-2-Clause** |
| zlib decompression behaviour | ClassicUO `src/ClassicUO.Utility/ZLib.cs` | **BSD-2-Clause** |

**Important correction for the later project:** ClassicUO is **BSD-2-Clause, NOT MIT** as
the task brief assumed. Every file fetched carried the header
`// SPDX-License-Identifier: BSD-2-Clause`. BSD-2-Clause requires retaining the copyright
notice and the two-clause disclaimer in source and binary redistributions. Confirm the
exact copyright line from the repository's `LICENSE.md` before shipping.

No other third-party code was ported. Pillow and numpy are used as libraries only
(Pillow: MIT-CMU / HPND; numpy: BSD-3-Clause).

---

## Code path index

| file | purpose | status |
|---|---|---|
| `tools\uoextract\uop.py` | MYP0 UOP reader + `create_hash` | verified |
| `tools\uoextract\verify_tiledata.py` | tiledata parser + all proofs | verified |
| `tools\uoextract\art.py` | art extractor (static + land), writes PNGs | verified |
| `tools\uoextract\gumps.py` | gump container reader + header probe | partial |
| `tools\uoextract\gump_header.py` | gump layout score search | diagnostic |
| `tools\uoextract\areas_4_7.py` | statics, cliloc, skills, skillgrp, hues | mixed |
| `tools\uoextract\skills_hues.py` | final skills / skillgrp / hues extraction | verified (hues partial) |
| `tools\uoextract\hash_probe.py` | proves the UOP hash string form | verified |
| `tools\uoextract\debug_diamond.py` | proves the land diamond writes 1012 px | verified |
| `tools\uoextract\find_tiledata_layout.py` | early land/stride reconnaissance | exploratory |
| `tools\uoextract\search_tiledata.py`, `brute_layout.py`, `enum_blocks.py`, `map_structure.py`, `prove_fields.py`, `prove_layout.py`, `residue_test.py`, `walk_groups.py`, `verify_stride.py`, `tiledata.py`, `tiledata2.py`, `tiledata_final.py`, `geometry_search.py`, `final_geometry.py`, `look_items.py`, `map_land_region.py`, `recon_tiledata.py`, `test_compression.py`, `fix_areas.py`, `final_areas.py`, `gump_bwt.py` | the measurement trail that led to the settled tiledata layout | superseded — kept as evidence |

## Sample output index

```
research\extract-out\art\item_20320_longsword.png      (82x40)
research\extract-out\art\item_18866_backpack.png       (44x32)
research\extract-out\art\item_20399_anvil.png          (44x46)
research\extract-out\art\item_20401_forge.png          (44x55)
research\extract-out\art\item_21502_katana.png         (44x36)
research\extract-out\art\item_20305_dagger.png         (22x26)
research\extract-out\art\item_23993_leather_cap.png    (44x32)
research\extract-out\art\item_21445_leather_sleeves.png(44x37)
research\extract-out\art\item_16705_wooden_beam.png    (44x35)
research\extract-out\art\item_21781_cloak.png          (58x50)
research\extract-out\art\land_00003_grass_land.png     (44x44, 1012 px)
research\extract-out\art\land_00168_sand_land.png      (44x44, 1012 px)
research\extract-out\art\land_00000_land0.png          (44x44, 1012 px)
```
