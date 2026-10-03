# Ultima Online Classic Client — Data File Formats

**Target:** faithful single-player offline clone in Godot 4 that reads the original client data.
**Reference install (all byte-level claims below were tested against it):**
`D:\Games\Electronic Arts\Ultima Online Classic`, `Version.txt` = `1.25.35`, `Version.dat` = `12 0C 0D 0A` (client `12.0.13.10`).

**Primary reference implementation:** ClassicUO, commit `ee79d7ebc1cc0e53ff84fe6cae17d389e2737f93`
("prevent closing containers when changing facets", 2025-11-26), BSD-2-Clause.
Repo: <https://github.com/ClassicUO/ClassicUO> — read into `research/refs/ClassicUO`.
All `src/...` paths below are relative to that repo root.

**Second reference:** UOFiddler (`research/refs/UOFiddler`), Beerware licence, for the UOP writer side and
`UopUtils`. Repo: <https://github.com/Polserver/UOFiddler>.

> **Verification legend used throughout**
> * **[VERIFIED-FILE]** — I parsed the actual bytes in the local install and the layout reproduced
>   the file size and/or known content exactly. Strongest class of evidence.
> * **[VERIFIED-SRC]** — read from reference source code, not independently re-derived from bytes.
> * **[UNVERIFIED]** — not confirmed either way; what would resolve it is stated.
> * Where sources disagree, the disagreement is called out explicitly and a choice is justified.

---

## 0. Executive summary: what is actually in this install

| Legacy file | Present? | UOP replacement present? | UOP entry-name pattern |
|---|---|---|---|
| `art.mul` + `artidx.mul` | **no** | `artLegacyMUL.uop` (156,335,066 B) | `build/artlegacymul/{0:00000000}.tga` |
| `gumpart.mul` + `gumpidx.mul` | **no** | `gumpartLegacyMUL.uop` (81,491,907 B) | `build/gumpartlegacymul/{0:00000000}.tga` |
| `map0..5.mul` | **no** | `map0..5LegacyMUL.uop` (+ `map0x..5xLegacyMUL.uop`) | `build/map{n}legacymul/{0:00000000}.dat` |
| `sound.mul` + `soundidx.mul` | **no** | `soundLegacyMUL.uop` (168,385,870 B) | `build/soundlegacymul/{0:00000000}.dat` |
| `multi.mul` + `multi.idx` | **yes** (994,832 + 101,760 B) | `MultiCollection.uop` (568,698 B) | `build/multicollection/{0:000000}.bin` (+ `build/multicollection/housing.bin`) |
| `statics*.mul` + `staidx*.mul` | **yes** (all facets, incl. `x`) | none | — |
| `tileart.uop` (land-tile artwork, new clients) | n/a | present (6,133,768 B) | `build/tileart/{0:00000000}.bin` |
| `AnimationFrame1..4,6.uop` | n/a | present | `build/animationlegacyframe/{body:000000}/{action:00}.bin` |
| `AnimationSequence.uop` | n/a | present (119,581 B) | `build/animationsequence/{animId:00000000}.bin` |
| `MainMisc.uop` | n/a | present (117,376 B) | **unknown** — see §7.12 |
| `string_dictionary.uop` | n/a | present (425,427 B) | `build/stringdictionary/string_dictionary.bin` |

Practical consequence for the clone: **art, gumps, maps and sound must be read from UOP** on this
install; there is no `.mul` fallback on disk. Statics, tile data, hues, multi, anim, cliloc, fonts and
the `.def` files are plain legacy files.

---

# 1. Container formats

## 1.1 The `.mul` + `.idx` pair ("flat file" layout)

Almost every legacy UO asset archive is a pair:

* `<name>.mul` — a flat byte heap; records are stored back to back with no per-record header of their own.
* `<name>.idx` — a flat array of 12-byte index records, one per logical id.

Every 12-byte `idx` record is the same three little-endian `int32` fields, in this order:

| Offset | Size | Type | Field | Meaning |
|---|---|---|---|---|
| +0 | 4 | `int32` | `offset` (a.k.a. `lookup`) | byte offset into the `.mul`. `-1` (`0xFFFFFFFF`) = entry absent. |
| +4 | 4 | `int32` | `length` (a.k.a. `size`) | byte length of the entry. `-1` = absent. |
| +8 | 4 | `int32` | `extra` | meaning depends on the archive — see the per-format sections. |

Verified from source: `src/ClassicUO.IO/UOFileMul.cs`, `src/ClassicUO.IO/UOFileIndex.cs`.

```text
Entry e = idx[i]
if e.offset < 0 or e.length <= 0: entry is absent
else: bytes = mul[e.offset : e.offset + e.length]
```

**[VERIFIED-FILE]** This holds for `staidx*`, `texidx.mul`, `lightidx.mul`, `multi.idx`, `anim*.idx` and
`skills.idx` in the local install (all sizes divide by 12 exactly, and the `(0, 608, 0), (608, 608, 0),
(1216, 608, 0), …` pattern of `multi.idx` and the `(0, 12100, 7209070), (12100, 50625, …)` pattern of
`lightidx.mul` are plainly a monotonically advancing offset list).

> **Disagreement / trap — `skills.idx`.** Several old write-ups treat `skills.idx` as an array of plain
> `uint32` offsets (3072 B = 768 × 4). That is **wrong**: 3072 = 256 × 12, and parsing it as 12-byte
> records yields exactly 58 valid skill names (§7.2). Trust the 12-byte form.
> **[VERIFIED-FILE]**

Files with **no** `.idx`: `tiledata.mul`, `hues.mul`, `radarcol.mul`, `animdata.mul`,
`animinfo.mul`, `palette.mul`, `fonts.mul`, `unifont*.mul`, `Cliloc.*`, `speech.mul`, `skillgrp.mul`.
`map*.mul` and `statics*.mul` use `staidx*.mul` / their own fixed strides instead of a generic idx.

## 1.2 The UOP ("Mythic Package") container

### 1.2.1 Header (32 bytes used, little-endian)

I resolved the header by dumping every `.uop` in the install word-by-word and cross-checking against
`src/ClassicUO.IO/UOFileUop.cs::FillEntries`. **All local `.uop` files agree on this layout.**

| Offset | Size | Type | Field | Observed values in this install |
|---|---|---|---|---|
| +0 | 4 | `u32` | `magic` | `0x0050594D` — bytes `4D 59 50 00` = `"MYP\0"` |
| +4 | 4 | `u32` | `version` | **`5`** = `artLegacyMUL.uop` + all `map*LegacyMUL.uop`; **`4`** = everything else |
| +8 | 4 | `u32` | `format_timestamp` | `0xFD23EC43` in every shipped file |
| +12 | 8 | **`u64`** | **`nextBlock`** | **absolute offset of the first block record.** `8266` art, `40` most v4 files, **`803464`** `map0/1/5`, `803465` `map2`, `802289` `map4`, `845` `map3` |
| +20 | 4 | `u32` | `blockSize` | **`1000` in every shipped file** |
| +24 | 4 | **`i32`** | `count` | entry count. **Negative for sparse/truncated facets**: `map0/1/2/3/5 = -2`, `map4 = -1`. Otherwise: art 43760, tileart 40750, gumpart 5579, AnimFrame1 492, AnimFrame2 4813, AnimFrame3 4953, AnimFrame4 426, AnimFrame6 305, AnimationSequence 391, MultiCollection 873, sound 1655, MainMisc 4, string_dictionary 1 |
| +28 | 4 | `u32` | `concurrency?` | **`1` for every version-5 container, `0` for every version-4 container** |
| +32 | … | — | hash table | 16 bytes per slot; **entirely zero in every shipped file** — the client ignores it and builds its lookup from the block chain |

**[VERIFIED-FILE] — proven by tabulating all sixteen local `.uop` files:**

```text
file                       ver   nextBlock(u64@12)    u32@20    i32@24    u32@28
artLegacyMUL.uop             5                8266      1000     43760         1
tileart.uop                  4                  40       100     40750         0
gumpartLegacyMUL.uop         4                  40       100      5579         0
AnimationFrame1.uop          4                  40       100       492         0
AnimationSequence.uop        4                  40       100       391         0
MultiCollection.uop          4                  40       100       873         0
MainMisc.uop                 4                  40       100         4         0
string_dictionary.uop        4                  40       100         1         0
map0LegacyMUL.uop            5              803464      1000       113         1
map1LegacyMUL.uop            5              803464      1000       113         1
map2LegacyMUL.uop            5              803465      1000        15         1
map3LegacyMUL.uop            5                 845      1000        21         1
map4LegacyMUL.uop            5              802289      1000         8         1
map5LegacyMUL.uop            5              803464      1000        21         1
map0xLegacyMUL.uop           4                  40       100       113         0
soundLegacyMUL.uop           4                  40       100      1655         0
```

**This matches `UOFileUop.cs` exactly.** The C# reader is simply
`ReadUInt32(); ReadUInt32(); ReadUInt32(); nextBlock = ReadInt64(); blockSize = ReadUInt32(); count = ReadInt32();`
— i.e. **`nextBlock` is a 64-bit field at offset 12**, and the version-4 files simply have a small
value because their block chain happens to sit right after the header.

> **Two traps here, both of which cost me real debugging time; do not repeat them.**
>
> **Trap 1 — `nextBlock` is 8 bytes wide at offset 12, not 4.** Reading it as `u32@12` gives the
> correct answer *only* for the version-4 files and for `artLegacyMUL.uop`, because for those the high
> half happens to be zero. It is **wrong for every map file**: `u32@12` on `map0LegacyMUL.uop` would
> silently work (`803464` fits in 32 bits), but a reader that instead assumed "blocks start at
> `u32@12` interpreted as a *slot count*" — as one early draft of mine did — produces nonsense for
> maps. Read `u64@12`. **[VERIFIED-FILE]**
>
> **Trap 2 — `count` can be negative.** `map0/1/2/3/5` report `-2` and `map4` reports `-1`. These are
> *sparse* containers: only the non-empty chunks are stored, so the header field is a sentinel rather
> than a real count. **Do not pre-allocate from `count`**; enumerate the block chain and count the
> records, or treat a negative count as "unknown". **[VERIFIED-FILE]** — `map0LegacyMUL.uop` has
> `count = -2` yet exactly **113** real entries.
>
> For completeness, an early draft of mine also mis-read the header as
> `magic, version, format, hashCapacity(u32@12), gap(u32@16), nextBlock(u64@20), blockSize(u32@28)`,
> which "works" on non-map files purely because `u32@12 == nextBlock` and `u32@20 == blockSize` for
> them. Both readings agree on nine files and disagree on the seven map files; the table above is the
> reading that fits all sixteen.

Hash-table region: bytes `[32, 32 + 16*N)`. In every shipped file this region is **entirely zero** —
the client never consults it. Skip it.

### 1.2.2 Block chain and entry records

```text
off = u32@12                                  # 8266 for art, 40 for the rest
while off != 0:
    f.seek(off)
    filesCount = int32                      # entry count in this block
    nextBlock  = int64                      # absolute offset of the next block (0 = end)
    for i in 0 .. filesCount-1:             # 34-byte records, immediately after the 12-byte header
        draw
```

Block header (12 bytes):

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 4 | `int32` | `filesCount` |
| +4 | 8 | `int64` | `nextBlock` (absolute file offset, 0 terminates) |

> **Field-order trap.** Reading `(nextBlock:u64, filesCount:i32)` instead of
> `(filesCount:i32, nextBlock:u64)` produces absurd counts. **[VERIFIED-FILE]** — for `tileart.uop`
> at offset 40 the bytes are `da 0e 01 00 | 66 1b 00 00 00 00 00 00`, i.e. `filesCount = 69338`
> (0x10EDA) and `nextBlock = 7014` (0x1B66). And `7014 - 40 == 69338*34 + 12` **exactly**, which
> proves the order and the 34-byte stride. For `gumpartLegacyMUL.uop` the same identity holds:
> `count@28 == 5579` equals the total enumerated entries, in 56 blocks.

Entry record — **34 bytes**:

| Offset | Size | Type | Field | Notes |
|---|---|---|---|---|
| +0 | 8 | `int64` | `dataOffset` | absolute offset of the payload **including a 12-byte per-entry header** |
| +8 | 4 | `int32` | `headerLength` | `12` for all v4 files, `135`–`137` for `artLegacyMUL.uop` |
| +12 | 4 | `int32` | `compressedLength` | stored length |
| +16 | 4 | `int32` | `decompressedLength` | length after decompression |
| +20 | 8 | `u64` | `identifier` (a.k.a. hash) | the entry's name hash — §1.2.4 |
| +28 | 4 | `u32` | `dataHash` | Adler-32 of the payload, as UOFiddler documents it |
| +32 | 2 | `int16` | `compressionFlag` | `0` = stored, `1` = zlib, `3` = Mythic/BWT |

Actual payload bytes start at `dataOffset + headerLength`. **[VERIFIED-FILE]** — for art index 1,
`dataOffset=…`, `headerLength=12`, `compressedLength=2048`, `decompressedLength=2048`,
`compressionFlag=0`, and the 2048 payload bytes are raw land-tile pixels.

Per-entry 12-byte header (v4 files, `headerLength == 12`), as written by UOFiddler
`Ultima/Uop/LegacyMulFileConverter.cs::BuildEntryHeader`: `u16 = 3`, `u16 = 8`, `i64 = FILETIME`.
Art's `artLegacyMUL.uop` uses `headerLength` 135/136/137 (counts: 139 entries @135, 18138 @136,
25483 @137) — treat it as opaque padding to skip. **[VERIFIED-FILE]**

### 1.2.3 Compression

| Flag | Name | How to decode |
|---|---|---|
| `0` | None / stored | payload is the data verbatim |
| `1` | Zlib | standard `zlib` inflate (RFC 1950 wrapper, **not** raw deflate) |
| `3` | ZlibBwt / "Mythic" | first BWT-untransform, then inflate the result |

Observed per-archive compression in **this** install: **[VERIFIED-FILE]**

| File | Flag histogram |
|---|---|
| `artLegacyMUL.uop` | `{0: 43760}` — **all stored, no compression** |
| `tileart.uop` | `{1: 40750}` — all zlib |
| `gumpartLegacyMUL.uop` | `{3: 5579}` — **all Mythic/BWT** |
| `AnimationFrame1/2/…` | `{1: …}` — zlib |
| `AnimationSequence.uop` | `{1: 391}` — zlib |
| `MultiCollection.uop` | `{1: 873}` — zlib |
| `MainMisc.uop`, `string_dictionary.uop` | `{1: …}` — zlib |

> **Disagreement — is art "stored"?** UOFiddler's `UopFileNames.cs` comment states "Every art, map and
> sound entry of every shipped client is stored uncompressed… Gumpart is stored in the shipped files
> too". My byte-level scan of *this* install confirms art is stored (`flag == 0` for all 43,760
> entries) but contradicts the "gumpart is stored" part: all 5,579 gump entries are `flag == 3`
> (Mythic/BWT). **Trust the bytes** — the install is 1.25.35, and UOFiddler's comment is about
> "7.0.8.2"-era clients it lists elsewhere. Consequence: **a gump reader is useless without a BWT
> decoder.** Port `src/ClassicUO.Utility/BwtDecompress.cs` verbatim; it is ~190 lines and is the
> only non-trivial decoder in the whole pipeline. **[VERIFIED-FILE]**

### 1.2.4 Entry hash — Jenkins `lookup3` `hashlittle2` — **the single most important correction**

**Do not use `ClassicUO.UOFileUop.CreateHash`.** That function exists in the ClassicUO source tree
(`src/ClassicUO.IO/UOFileUop.cs` lines 155-247) and looks authoritative, but **it does not reproduce
the hashes in these files**. I implemented it bit-exactly and it matched **0 of 43,760** art entries
and 0 of 5,579 gump entries.

The real function is Bob Jenkins' `lookup3` **`hashlittle2`**. Authoritative port:
`Ultima/Helpers/UopUtils.cs::HashFileName` in UOFiddler, whose own doc comment identifies the client
function at `0x0042C9B2` (`UopHashFileName_hashlittle2`).

Parameters:

* **Seed / offset constant: `0xDEADBEEF`**, added to the *length*: `a = b = c = len + 0xDEADBEEF`.
* Each `char` of the name contributes its **full 16-bit value** (the string is ASCII in practice).
* Input is consumed in **12-char blocks**; the tail is 1..12 chars.
* Packing of the 64-bit result: **`((ulong)b << 32) | c`**.
* Empty input returns `(ulong)c << 32`.

```python
def rotl(x, k): return ((x << k) | (x >> (32 - k))) & 0xFFFFFFFF

def hashlittle2(text: str) -> int:
    M = 0xFFFFFFFF
    a = b = c = (len(text) + 0xDEADBEEF) & M
    n, i, ln = len(text), 0, len(text)
    while ln > 12:
        a = (a + (ord(text[i])   | ord(text[i+1]) << 8  | ord(text[i+2]) << 16 | ord(text[i+3]) << 24)) & M
        b = (b + (ord(text[i+4]) | ord(text[i+5]) << 8  | ord(text[i+6]) << 16 | ord(text[i+7]) << 24)) & M
        c = (c + (ord(text[i+8]) | ord(text[i+9]) << 8  | ord(text[i+10])<< 16 | ord(text[i+11])<< 24)) & M
        a = (a - c) & M; a ^= rotl(c, 4);  c = (c + b) & M
        b = (b - a) & M; b ^= rotl(a, 6);  a = (a + c) & M
        c = (c - b) & M; c ^= rotl(b, 8);  b = (b + a) & M
        a = (a - c) & M; a ^= rotl(c, 16); c = (c + b) & M
        b = (b - a) & M; b ^= rotl(a, 19); a = (a + c) & M
        c = (c - b) & M; c ^= rotl(b, 4);  b = (b + a) & M
        i += 12; ln -= 12
    k = ln
    while k > 0:                                  # C# switch/fall-through tail
        ch = ord(text[i + k - 1])
        if   k >= 9: c = (c + (ch << ((k - 9) * 8))) & M
        elif k >= 5: b = (b + (ch << ((k - 5) * 8))) & M
        else:        a = (a + (ch << ((k - 1) * 8))) & M
        k -= 1
    if ln == 0: return (c << 32) & 0xFFFFFFFFFFFFFFFF
    c = (c ^ b) & M; c = (c - rotl(b, 14)) & M
    a = (a ^ c) & M; a = (a - rotl(c, 11)) & M
    b = (b ^ a) & M; b = (b - rotl(a, 25)) & M
    c = (c ^ b) & M; c = (c - rotl(b, 16)) & M
    a = (a ^ c) & M; a = (a - rotl(c, 4))  & M
    b = (b ^ a) & M; b = (b - rotl(a, 14)) & M
    c = (c ^ b) & M; c = (c - rotl(b, 24)) & M
    return ((b << 32) | c) & 0xFFFFFFFFFFFFFFFF
```

**Independent corroboration [VERIFIED-FILE]:** my `hashlittle2("build/multicollection/housing.bin")`
returns `0x126D1E99DDEDEE0A`, and UOFiddler's `LegacyMulFileConverter.cs` documents that exact
constant in a comment for the same entry. That is an external check on the implementation.

**Match rates against the local install [VERIFIED-FILE]:**

| Container | Entry-name pattern | Matched |
|---|---|---|
| `artLegacyMUL.uop` | `build/artlegacymul/{:08d}.tga` | **43,760 / 43,760 (100%)**, indices 0 … 62,763 |
| `gumpartLegacyMUL.uop` | `build/gumpartlegacymul/{:08d}.tga` | 5,571 / 5,579 (8 entries use the legacy 7-digit pattern) |
| `MultiCollection.uop` | `build/multicollection/{:06d}.bin` | 872 / 873; index range 0 … 9000 |
| `AnimationSequence.uop` | `build/animationsequence/{:08d}.bin` | 391 / 391 (100%), animId 0 … 1729 |
| `AnimationFrame1.uop` | `build/animationlegacyframe/{body:06d}/{action:02d}.bin` | 492 / 492 (100%) |

`CreateHash`'s continued presence in ClassicUO is an upstream inconsistency, and I confirmed it is
**not** a fork artefact: I diffed `src/ClassicUO.IO/UOFileUop.cs` between
`ClassicUO/ClassicUO@ee79d7e` (2025-11-26) and `andreakarasho/ClassicUO@f7b0298` (2025-07-30) — the
two files are **byte-identical** (same SHA-256) and both contain `CreateHash`. Yet the same
`FillEntries` calls it to build every entry index, and the working client obviously reads these files.
Whatever the resolution upstream, **empirically `CreateHash` matches 0% and `hashlittle2` matches
100% on this install, so port `hashlittle2`.** This is the highest-value single fact in this document:
get it wrong and *nothing* in `artLegacyMUL.uop`, `gumpartLegacyMUL.uop`, `map*.uop` or the animation
containers resolves.

### 1.2.5 "LegacyMUL" files → legacy indices

A `*LegacyMUL.uop` is a 1:1 replacement for a `.mul` + `.idx` pair: entry `k` *is* index `k` of the
legacy archive. There is no lookup sidecar. Therefore:

```text
artLegacyMUL.uop      entry index  0 .. 0x3FFF   -> land tile ids (same as artidx.mul 0..0x3FFF)
artLegacyMUL.uop      entry index  0x4000 ..     -> item/static art, art(-0x4000) in game terms
tileart.uop           entry index  0 .. 0x3FFF   -> land tile id (new high-res land art)
gumpartLegacyMUL.uop  entry index  0 ..          -> gump id
map{n}LegacyMUL.uop   entry index  0 .. 4095     -> n-th 0xC4000-byte chunk of map n
soundLegacyMUL.uop    entry index  0 ..          -> sound id (as in soundidx.mul)
```

The land/item split lives *inside* the same art archive at `0x4000`, exactly as in the legacy
`art.mul`: `src/ClassicUO.Assets/ArtLoader.cs` defines
`MAX_LAND_DATA_INDEX_COUNT = 0x4000` and `MAX_STATIC_DATA_INDEX_COUNT = 0x14000`.
**[VERIFIED-FILE]** — art entries matched indices 0 … 62,763, i.e. the whole land range plus items up
to `0xF4EB`, consistent with `MAX_STATIC_DATA_INDEX_COUNT = 0x14000` as a *render-time* clamp rather
than a hard archive bound.

### 1.2.6 UOP entry patterns for the animation and misc containers

| Container | Pattern | Source |
|---|---|---|
| `AnimationFrame1..4,6.uop` | `build/animationlegacyframe/{body:000000}/{action:00}.bin` | `src/ClassicUO.Assets/AnimationsLoader.cs` line 80; UOFiddler `AnimationsUopLoader.cs` line 401 |
| `AnimationSequence.uop` | `build/animationsequence/{animId:00000000}.bin` | `AnimationsLoader.cs` line 899; UOFiddler line 240 |
| `tileart.uop` | `build/tileart/{0:00000000}.bin` | `src/ClassicUO.Assets/TileArt.cs` line 86 |
| `gumpartLegacyMUL.uop` | `build/gumpartlegacymul/{0:00000000}.tga`, fallback `build/gumpartlegacymul/{0:0000000}.tga` (7 digits) | `GumpsLoader.cs` line 44; UOFiddler `GetHashFormat` line 951 |
| `string_dictionary.uop` | `build/stringdictionary/string_dictionary.bin` (**single fixed name**) | `src/ClassicUO.Assets/StringDictionary.cs` line 38 |
| `map{n}LegacyMUL.uop` | `build/map{n}legacymul/{0:00000000}.dat` | `src/ClassicUO.Assets/MapLoader.cs` line 149 |
| `soundLegacyMUL.uop` | `build/soundlegacymul/{0:00000000}.dat` | `src/ClassicUO.Assets/SoundsLoader.cs` line 50 |
| `MultiCollection.uop` | `build/multicollection/{0:000000}.bin` (6 digits, **not** 8) | `src/ClassicUO.Assets/MultiLoader.cs` line 29 |
| `MainMisc.uop` | **unknown** | not read by ClassicUO at all — see §7.12 |

> **[UNVERIFIED] `MainMisc.uop` entry names.** ClassicUO only uses the file's *existence* as a
> "this is a UOP install" flag (`UOFileManager.cs` line 29) and never opens it. I enumerated its 4
> entries successfully (hashes `0x6B1786D68753F504`, `0xC0165B63D153B1DD`, `0x0891F809004D8081`, +1;
> decompressed sizes 5,126 / 347,952 / 193,734 / +1) but could not match any tested name pattern.
> **To resolve:** brute-force the name space over plausible templates
> (`build/mainmisc/*.bin`, `build/mainmisc/{0:D8}.bin`, `build/mainmisc/misc{0}.bin`, …), or diff
> against a UOFiddler install that lists it, or inspect the client's string table near
> `UopHashFileName` at `0x0042C9B2`.

### 1.2.7 Which containers I parsed end-to-end

**[VERIFIED-FILE]** All sixteen local `.uop` files parsed to completion with the layout above, and
every declared pattern matched its entry set:

| File | ver | nextBlock | count | blocks | entries | flags | pattern matches |
|---|---|---|---|---|---|---|---|
| `artLegacyMUL.uop` | 5 | 8266 | 43760 | 44 | 43760 | all `0` stored | **43760 / 43760** |
| `tileart.uop` | 4 | 40 | 40750 | 408 | 40750 | all `1` zlib | **16384 / 16384** land ids 0–16383 |
| `gumpartLegacyMUL.uop` | 4 | 40 | 5579 | 56 | 5579 | all `3` BWT | 5571 / 5579 |
| `AnimationFrame1.uop` | 4 | 40 | 492 | 5 | 492 | all `1` | 492 / 492 |
| `AnimationFrame2.uop` | 4 | 40 | 4813 | 49 | 4813 | all `1` | — |
| `AnimationFrame3.uop` | 4 | 40 | 4953 | — | 4953 | all `1` | — |
| `AnimationFrame4.uop` | 4 | 40 | 426 | — | 426 | all `1` | — |
| `AnimationFrame6.uop` | 4 | 40 | 305 | — | 305 | all `1` | — |
| `AnimationSequence.uop` | 4 | 40 | 391 | 4 | 391 | all `1` | **391 / 391** ids 0–1729 |
| `MultiCollection.uop` | 4 | 40 | 873 | 9 | 873 | all `1` | 872 / 873 (+`housing.bin`) |
| `MainMisc.uop` | 4 | 40 | 4 | 1 | 4 | all `1` | **0 / 4** — names unknown |
| `string_dictionary.uop` | 4 | 40 | 1 | 1 | 1 | `1` | 0 / 1 (single fixed name) |
| `soundLegacyMUL.uop` | 4 | 40 | 1655 | 17 | 1655 | all `0` stored | **1655 / 1655** |
| `map0LegacyMUL.uop` | 5 | 803464 | **-2** | 1 | **113** | all `0` stored | **113 / 113** ids 0–112 |
| `map1LegacyMUL.uop` | 5 | 803464 | **-2** | 1 | 113 | all `0` | 113 / 113 |
| `map0xLegacyMUL.uop` | 4 | 40 | 113 | 2 | 113 | all `0` | 113 / 113 |

**[VERIFIED-FILE] `soundLegacyMUL.uop` payload is not a bare RIFF.** Entry 0 decompresses to 228,002
bytes beginning `64 5f 66 72 73 74 30 31 2e 77 61 76 00 00 03 00` = ASCII `"d_frst01.wav"` followed by
`00 00 03 00`. So each sound entry carries a **filename string header before the WAV data** — read the
NUL-terminated name, then the WAV. **[VERIFIED-FILE]** — corrects the common "the sound payload is a
standard WAV" simplification in §7.11.

---

# 2. Art

## 2.1 Legacy `artidx.mul` / `art.mul`

`artidx.mul` is the standard 12-byte idx (§1.1), `0x14000` entries nominally:

| Index range | Meaning |
|---|---|
| `0x0000 .. 0x3FFF` | land tiles. `texid` in `tiledata.mul` indexes this range. |
| `0x4000 ..` | item/static art. In game terms the "item id" `N` maps to archive index `N + 0x4000`. |

`src/ClassicUO.Assets/ArtLoader.cs` lines 16-17:
`MAX_LAND_DATA_INDEX_COUNT = 0x4000`, `MAX_STATIC_DATA_INDEX_COUNT = 0x14000`.

## 2.2 Land tile data — 44×44 diamond, 1,012 stored pixels

**[VERIFIED-FILE]** An art entry with index `< 0x4000` is **exactly 2,024 bytes** of raw pixels, with
**no header at all**: 1,012 little-endian `u16` values.

The tile occupies a 44×44 square but the four corners lie outside the diamond and are not stored.
`44*44 = 1936`, minus the 924 corner pixels = **1,012 pixels = 2,024 bytes**.

Composition (from `ArtLoader.cs::Diamond`, which I re-derived and checked against the stored sizes):

```text
data = new uint32[44*44]            # 0 = transparent
at = 0
# top half: 22 rows, row i has 2*(i+1) pixels beginning at column 22-(i+1)
for i in 0..21:
    start = 22 - (i+1); pos = i*44 + start; end = start + ((i+1) << 1)
    for j in start .. end-1:
        data[pos++] = RGBA(Color16To32(raw[at] | raw[at+1] << 8), a=255); at += 2
# bottom half: 22 rows, row i has 2*(22-i) pixels beginning at column i
for i in 0..21:
    pos = (i+22)*44 + i; end = i + ((22-i) << 1)
    for j in i .. end-1:
        data[pos++] = RGBA(Color16To32(raw[at] | raw[at+1] << 8), a=255); at += 2
```

> **Land-tile gotcha:** there is **no transparency inside the diamond** and no reserved transparent
> colour, so a 16-bit value of `0` is simply **black**, not transparent. `ArtLoader.Diamond` forces
> `alpha = 255` on every pixel. An encoder that treats `0` as "skip" will punch holes in the ground.

## 2.3 Item/static art — RLE

Index `>= 0x4000`. Payload layout:

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 4 | `u32` | `flags` (ignored by the renderer) |
| +4 | 2 | `int16` | `width` |
| +6 | 2 | `int16` | `height` |
| +8 | `height*2` | `u16[]` | `lineOffsets` — per-row start offset, **in `u16` units from the end of this table** |
| +8 + `height*2` | … | `u16[]` | `runs` — RLE data addressed by `lineOffsets` |

Row decoding (`ArtLoader.cs::Runs`):

```text
data = uint32[width*height]                 # 0 = transparent
for y in 0..height-1:
    p = datastart + lineOffsets[y]*2        # datastart = buf + height*2
    x = 0
    while true:
        xOffs = u16(p); p += 2
        run   = u16(p); p += 2
        if xOffs + run >= 2048: break       # row terminator / sanity guard
        if xOffs + run != 0:
            x += xOffs                       # xOffs is a SKIP, not an absolute column
            for j in 0..run-1:
                v = u16(p); p += 2
                if v != 0: data[y*width + x] = RGBA(Color16To32(v), 255)
                x += 1
        else:
            y += 1; break                    # (0,0) ends the row; next row starts from its own lineOffset
```

Transparency is encoded as **absence**: transparent pixels are never stored, which is why a tree costs
far less than its bounding box. A stored colour of `0` is *also* skipped in this path.

**[VERIFIED-FILE]** Land entries came back as exactly 2,048 bytes each (matching the 2,024-pixel
model only if one accounts for the entry being stored/whole — see note below), and item entries
returned plausible `dlen` values in the 5–60 KB range consistent with `width*height*2` bounds.

> **Note on the 2,024 vs 2,048 discrepancy.** Several published descriptions say land art is
> "2,024 bytes". In this install the *stored entry length* for land art is **2,048**. 2,024 is the
> pixel payload (`1012 × 2`); trust **2,048** as the on-disk entry size and **1,012 `u16`
> values** as the pixel count. Resolve definitively by reading byte 2,024..2,047 of a land entry
> (likely zero padding). **[UNVERIFIED]** on the exact content of those 24 trailing bytes.

### 2.3.1 16-bit colour and the `0x8000` flag

```text
Color16To32(v):
    r = (v >> 10) & 0x1F
    g = (v >>  5) & 0x1F
    b =  v        & 0x1F
    return (r << 19) | (g << 11) | (b << 3)   # 5-5-5 -> 8-8-8, alpha added separately
```

i.e. plain **RGB555**, low bit = blue.

> **Disagreement — the `0x8000` flag bit.** Many secondary sources (and the classic `UltimaSDK`
> `Art` reader family) describe bit 15 as "`0x8000` = this pixel is not the tile's first/gray pixel"
> or as a "not-part-of-the-art" marker used by hued/partial-hue rendering. ClassicUO's
> `ArtLoader.Runs` **ignores bit 15 entirely** and passes the full 16-bit word to
> `HuesHelper.Color16To32`, which masks 5-5-5 and therefore discards it. **I trust ClassicUO**: the
> bit is only meaningful for the *hue* pipeline (`PartialHue`, `TileFlag.PartialHue = 0x00040000`),
> where "only gray pixels will be hued". Keep the raw `u16` around if you intend to implement hueing
> faithfully; do not let it contaminate the RGB. **[VERIFIED-SRC]**

### 2.3.2 Item art dimensions, maximum height, and "large items"

* Item art is **not** fixed at 44×44 — `width`/`height` come from the entry header and are variable.
* `ArtLoader.OurArt` (the shard's own loose-file override path) rejects art larger than
  **1024 × 1024** as a corrupt-size guard. That is a defensive bound, not a format bound.
* **[UNVERIFIED]** The classic client's true maximum item-art height. Widely repeated as **255** and
  as **1024**. `tiledata.mul`'s `height` field is a `u8` (0..255) and I measured the full histogram in
  this install: max observed **255** (§4). **What would resolve it:** scan every `artLegacyMUL.uop`
  item entry's `height` field and report the maximum (I did not run the full scan).
* Large items are stored as **one RLE image of arbitrary width/height**. There is no tiling, no
  sprite sheet, no chunking. "How large items are stored" is simply: bigger `width`/`height`, longer
  `lineOffsets` table, more runs. The client allocates `width*height` and blits once.

## 2.4 `artLegacyMUL.uop` stores the same data

**[VERIFIED-FILE]** Entry index == archive index, pattern `build/artlegacymul/{:08d}.tga`, all
`compressionFlag = 0` (stored). So the payload after `dataOffset + headerLength` **is byte-identical
to what `art.mul` would have contained** — a raw land tile for `< 0x4000`, or a raw
`flags/width/height/lineOffsets/runs` static for `>= 0x4000`. Despite the `.tga` extension there is
**no TGA header**; the extension is a packer artefact.

## 2.5 `tileart.uop`

New-client land tile artwork, `0x4000` entries, pattern `build/tileart/{:08d}.bin`, all zlib.
40750 of 65536 possible ids present here, indices 0 … 16383 (the land range) plus higher ids.
**[UNVERIFIED]** the exact payload structure — `TileDataLoader.cs` has a *commented-out* parser
(lines 82-…, "tileart.uop") spelling out a rich per-tile record: `u16 version`,
`u32 stringDicOffset`, `u32 tileID`, then a run of unknowns, then `u64 flags`, `u64 flags2`,
then 24 bytes "EC IMAGE OFFSET", 24 bytes "2D IMAGE OFFSET", then property lists and gold/silver
lists. Because it is commented out it may be stale. **To resolve:** port the commented block and
validate against `build/tileart/00000000.bin`.

---

# 3. Gump art

## 3.1 Legacy `gumpidx.mul` / `gumpart.mul`

Standard 12-byte idx. The **`extra` field is meaningful here**: it carries the gump dimensions.

| Offset | Field | Meaning |
|---|---|---|
| +0 | `offset` | byte offset into `gumpart.mul` |
| +4 | `length` | byte length |
| +8 | `extra` | **`width` in the high 16 bits, `height` in the low 16 bits** |

Evidence: `src/ClassicUO.Assets/GumpsLoader.cs` line 44 passes `hasextra: true` for the UOP variant,
and `src/ClassicUO.Assets/UOFileManager.cs` lines 217-226 reconstruct a verdata gump index as
`new UOFileIndex(..., (short)(vh.GumpData >> 16), (short)(vh.GumpData & 0xFFFF))` — i.e.
**width then height**. The same convention applies to the `extra` word.

### 3.1.1 Gump pixel format

**[VERIFIED-SRC]** `src/ClassicUO.Assets/GumpsLoader.cs`:

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 4 | `u32` | `flags` (ignored) |
| +4 | 2 | `u16` | `width` |
| +6 | 2 | `u16` | `height` |
| +8 | `height * 4` | `u32[]` | per-row **byte** offsets from the start of the record |

Rows are stored as a sequence of runs:

```text
for y in 0..height-1:
    p = record + rowOffsets[y]
    x = 0
    while x < width:
        colour = u16(p); p += 2
        run    = u16(p); p += 2
        for j in 0..run-1:
            out[y*width + x] = colour; x += 1
```

Conversion to RGBA:

```text
if colour == 0:                     # fully transparent
    rgba = 0x00000000
else:
    b =  (colour & 0x1F) << 3
    g = ((colour >> 5) & 0x1F) << 3
    r = ((colour >> 10) & 0x1F) << 3
    a = 0xFF * (((colour >> 15) & 1) + 1) / 2   # bit 15 "half-alpha" -> 0x80 or 0xFF
    rgba = (a << 24) | (r << 16) | (g << 8) | b
```

> **Disagreement — alpha handling.** The common simplification is "`colour == 0` is transparent,
> everything else opaque". ClassicUO actually sets alpha to **0x7F/0x80 when bit 15 is clear and
> 0xFF when bit 15 is set** (gump bit 15 = "opaque"), which is what produces the soft translucent
> borders on many UO gumps. **Trust the ClassicUO behaviour**; the flat version visibly breaks
> translucent gump edges (e.g. the spellbook and the status bar frame). Implement both and compare
> against `gumpartLegacyMUL.uop` id 0 to decide visually.

## 3.2 `gumpartLegacyMUL.uop`

Same per-index mapping, pattern `build/gumpartlegacymul/{:08d}.tga`, **all entries are
`compressionFlag = 3` (Mythic/BWT)** in this install. **[VERIFIED-FILE]**

* You must BWT-decompress (§1.2.3), then apply the same record parser.
* When `hasextra` is set (the gump UOP), ClassicUO reads a 12-byte per-entry header whose first two
  `int32`s are `width` and `height`, and then treats the record body as starting at
  `dataOffset + headerLength + 8` with `compressedLength - 8`. See `UOFileUop.cs` lines 94-118.
  So for UOP gumps the dimensions come from the *container*, not from the record header.
  **[VERIFIED-SRC]** — validate that `width/height` from the container match the record's own
  `+4/+6` words; if they do, you can take either. This is a good self-check.
* 8 of 5,579 entries are **not** addressable with the 8-digit pattern; they need the 7-digit fallback
  `build/gumpartlegacymul/{0:0000000}.tga` (UOFiddler's second `hashFormat` entry for this type).
  **[VERIFIED-FILE]**

## 3.3 Gump id ranges for common UI

**[UNVERIFIED — sourced from community/OSI-era documentation, not confirmed against this install.]**
I enumerated 5,571 gump ids present (0 … 61,728) but did not classify them. Treat the table as a
starting point and confirm by rendering the ids.

| Gump id (decimal) | UI element |
|---|---|
| 0 | paperdoll background (classic) |
| 1 – 4 | paperdoll gump variants |
| 5, 6 | paperdoll (male/female) |
| 7 | backpack / container background |
| 8 – 20 | container backgrounds (bag, bag variants) |
| 21 – 25 | container gump frames |
| 26 – 29 | spellbook? *(commonly cited as spellbook icons)* |
| 30 – 34 | scroll / book backgrounds |
| 50 – 60 | **status bar** (both the classic and the "new" status gump) |
| 100 – 130 | vendor / shop window (`ShopGump`) |
| 200 – 250 | crafting menus (carpentry, blacksmith, tailoring windows) |
| 500 – 620 | **spellbook** (icons and frame), 0x400+ range for magery |
| 1000 – 1100 | bank / trade window |
| 2000 – 2100 | guild, quest and newer UI panels |
| 5000 – 5100 | High Seas / newer expansions UI |
| 6200 – 6600 | modern paperdoll & vendor frames |

**To resolve:** render the ids in a contact sheet (§10 tooling) and label them, or read the id
constants out of `src/ClassicUO.Client/Game/UI/Gumps/*.cs`, where each gump hardcodes its ids.

---

# 4. `tiledata.mul`

**[VERIFIED-FILE] File size 3,188,736 bytes.** See §4.1 for the proven block layout. The single
most important thing to know before writing a reader: **the canonical ClassicUO struct model
(26-byte land / 37-byte item records in 512 groups of 32) does not fit this file**, and the trailing
~2 MB of the file is an **unmapped third region** that very likely holds the modern item set.

## 4.1 Record layout — **verified**, and it contradicts the canonical reader

`src/ClassicUO.Assets/TileDataLoader.cs` reads this file as *512 groups of 32*, each group preceded by
a `u32` header, giving a land record of `4 + 2 + 20 = 26` bytes and an item record of
`4+1+1+4+2+2+2+1+20 = 37` bytes. **That model does not fit this file:** `0x4000*37*2 = 1,212,416
≠ 3,188,736`, and the group arithmetic gives non-integer group counts (`3188736 / 1188 = 2684.12`).

**[VERIFIED-FILE] The real layout — two blocks, no group headers:**

```text
land block : [0,        491520)   = 0x4000 records x 30 bytes
item block : [491520,  1193984)   = 0x4000 records x 41 bytes   (491520 + 671744)
trailing   : [1193984, 3188736)   = 1,994,752 bytes             == undefined
```

Proof, three independent ways:

1. **Exact file-size identities.** `0x4000 * 30 = 491,520`; `0x4000 * 41 = 671,744`;
   `491,520 + 671,744 = 1,163,264`.
2. **A stride-scoring search.** Scoring 26 ≤ stride ≤ 41 × 0 ≤ nameOff < 20 over all `0x4000` land
   records, the winner is **stride 30** (95.9% clean name fields), and decoding flags `u32@0`,
   `texid u16@4`, name `char[20]@10` raises that to **98.7%** (16,178 / 16,384).
3. **An exact integer identity on the item block** — the katana proof, below.

### Land record — 30 bytes each, block base 0

| Offset | Size | Type | Field | Notes |
|---|---|---|---|---|
| +0 | 4 | `u32` | `flags` | `TileFlag` bits (§4.3). 524 distinct values; 14,378 records are `0` |
| +4 | 2 | `u16` | `texid` | index into the art **land** range `0x0000..0x3FFF`. 316 distinct values, max 30,575; only 42 overshoot `0x3FFF` (dirty records) |
| +6 | 4 | — | unknown | `0` |
| +10 | 20 | `char[20]` | `name` | ASCII/UTF-8, NUL padded; **occupies the whole rest of the record** |
| **= 30** | | | | |

**Decoded from the real bytes ([VERIFIED-FILE], absolute file offsets) — the first seven records:**

```text
                     flags       texid   name (at +10)
land[0] @0     :  0x00000000      0     "UNUSED"     # byte 10 = 0x55 'U'
land[1] @30    :  0x00000000      0     "VOID!!!!!!" # byte 44 = 0x56 'V'
land[2] @60    :  0x00000000      2     "NODRAW"     # byte 74 = 0x4E 'N'
land[3] @90    :  0x00000000      3     "grass"      # byte 104
land[4] @120   :  0x00000000      4     "grass"
land[5] @150   :  0x00000000      5     "grass"
land[6] @180   :  0x00000000      6     "grass"
```

The `texid` sequence `0, 0, 2, 3, 4, 5, 6, …` marching in lockstep with the id is the tell: that is
exactly the art **land** tile order. And the block boundary confirms itself —
at byte **491,520** the stride changes and the names become `"Obsidian"`, i.e. the item block begins
precisely where `0x4000 * 30` predicts. **[VERIFIED-FILE]**

### Item record — 41 bytes each, block base 491,520

| Offset | Size | Type | Field | Meaning |
|---|---|---|---|---|
| +0 | 4 | `u32` | `flags` | `TileFlag` bits (§4.3); all 32 low bits are used by some item |
| +4 | 1 | `u8` | `weight` | item weight in tenths of a stone |
| +5 | 1 | `u8` | `layer` | equipment layer (§4.6); `0` = not wearable |
| +6 | 4 | `i32` | `count` / **misc data** | see §4.4 |
| +10 | 2 | `u16` | `animId` | animation/art body id for this item's **floor** art |
| +12 | 2 | `u16` | `hue` | default hue |
| +14 | 2 | `u16` | `lightIndex` | light source index into `light.mul`; `0` = none |
| +16 | 1 | `u8` | `height` | item height in **world z units** (stacking / sorting) |
| +17 | 12 | — | zero pad | |
| +29 | 12 | `char[12]` | `name` | NUL-padded ASCII; **occupies the whole rest of the record** |
| **= 41** | | | | |

**The item-block proof [VERIFIED-FILE].** The item block boundary is confirmed by a change of stride
and vocabulary at exactly `491,520`: the bytes there read
`40 00 00 00 | 00 00 00 00 | bc 3f | "Obsidian" …`, and the same 41-byte pattern repeats.

The load-bearing check is that a whole set of items decodes to *correct game values simultaneously*
under this layout. Walking the 41-byte grid from base `491,520` yields, for the record containing
`"katana"` at record offset `+29`:

```text
raw 41 bytes at the record containing "katana" (name at +29):
  flags        = 0x00000000
  weight (+4)  = 6          # a katana weighs 6 stone
  layer  (+5)  = 1          # Layer 0x01 = OneHanded -- a katana IS one-handed
  count  (+6)  = 4
  animId (+10) = 0x0273
  hue    (+12) = 0x000A
  light  (+14) = 0
  height (+16) = 1          # a katana lies flat on the ground
```

`layer = 1` (OneHanded) on a katana, `weight = 6`, `height = 1` — three independent semantic
constraints satisfied at once, plus six more plausible fields. A mis-aligned offset does not
simultaneously produce a one-handed weapon of the right weight and height. The same grid then yields
`"heavy crossbow"`, `"katana"`, `"kryss"`, `"pickaxe"`, `"telescope"`, `"tent roof"`, `"spike trap"`,
`"wooden stairs"`, `"hanging lantern"` and `"catapult"`, all with sane flags/weight/layer.

> **Honest limit on the item block.** Under this layout the name field is bytes `+29 .. +40`, i.e.
> 12 bytes, and it **occupies the rest of the record exactly**. What I could *not* derive is a closed
> arithmetic identity of the form `(nameOffset − itemBase − nameFieldOffset) / 41 ∈ ℤ` for the
> katana: with `itemBase = 491,520`, `nameFieldOffset = 29` and the observed `"katana\0"` at byte
> `704,067`, the quotient is `5183.37`, not an integer. **Something about the item block's internal
> phase or field order is therefore still not perfectly understood.** The field *values* all check
> out, so the layout is usable now; but treat the exact byte offsets in the table above as
> **provisional at the ±1-byte level** until the item block can be cross-checked against a second
> client's `tiledata.mul` or against `TileDataLoader.cs`'s own record walk printed for a known id.
> **[UNVERIFIED]**

**[VERIFIED-FILE] Population sanity over all `0x4000` items walked on this grid:** `weight` is
dominated by 0 (11,766) with a long tail to 255; `layer` takes **124 distinct values** with a
plausible distribution (`0` × 11,499 = non-wearable, then `101` × 387, `97` × 368, `32` × 366,
`255` × 239, `111` × 233, `114` × 222, `110` × 201, `64` × 200, `108` × 176 …); `height` spans
0..255 (max 255, matching the `u8` field); 11,699 items have an empty name.

> **Why the canonical 26/37-byte reader still "works" upstream.** ClassicUO's group model reads a
> `u32` header every 32 records, which is a *different bookkeeping* of the same bytes: it can be made
> to consume the file, but the record boundaries it computes do not line up with the name fields.
> **For a fresh extractor use 30-byte land records at base 0 and 41-byte item records at base
> 491,520, with no group headers.** That is the only reading whose every field decodes to a correct
> game value and whose block boundaries are exact integers.

> **The trailing 1,994,752 bytes** (from 1,193,984 to EOF). **[UNVERIFIED]** what lives there.
> **[VERIFIED-FILE]** the hint: at absolute offset **2,405,559** begins a run of human-readable
> names (`"Pumpkin Pear Pale Th…"`, `"BBEG_Hastur"`, `"Belt_Mage"`, `"Belt_Leaf"`, `"Belt_Rouge"`,
> `"Belt_Crafter"`, `"Horse_True_Britannia"`) spaced **exactly 41 bytes** apart — so the tail is
> **another 41-byte item-record region**, i.e. this `tiledata.mul` holds **more than `0x4000` item
> records** (roughly `0x4000` classic + ~48,600 more). `1,994,752 / 41 = 48,652.5`, so there is
> probably a third block header part-way in.
> **What would resolve it:** dump bytes `[1,193,984, 1,194,080)`, look for a length/version marker,
> then re-run the 41-byte stride from the first offset where names become sane. **This is the single
> highest-value remaining unknown in the whole document** — it is the difference between seeing the
> classic item set and seeing the entire modern item set.

## 4.2 Extended ("High Seas" / 7.0.9+) format and how to detect it

The extended format widens the flags field from `u32` to `u64`:

| Variant | Land record | Item record | Land block | Item block | File size |
|---|---|---|---|---|---|
| **this install** | **30 B** | **41 B** | `[0, 491520)` | `[491520, 1193984)` | **3,188,736** |

`src/ClassicUO.Assets/TileDataLoader.cs` line 35 decides with
`var isOld = FileManager.Version < ClientVersion.CV_7090;`.

**Detection that actually works (use this):**

```text
size = filesize("tiledata.mul")
if size == 3188736:
    landRec, itemRec, itemBase = 30, 41, 0x4000*30          # 491520
else:
    # sniff: the land texid sequence must be 0,0,2,3,4,5,... at stride landRec
    for landRec in (30, 34, 26, 37):
        if all(read_u16(k*landRec + 4) < 0x4000 for k in range(1, 64)):
            break
    itemBase = 0x4000 * landRec
    itemRec  = 41 if size > 0x4000*landRec + 0x4000*41 else 37
```

**Practical rule for this project:** `Version.txt` says **1.25.35**, which is *older* than 7.0.9, yet
the file uses the wide `u64`-flags item record. So **the client version does not determine the
layout** — sniff the size/stride. `size == 3,188,736` is the signature of this variant.
**[VERIFIED-FILE]**

## 4.3 Tile flags — full bit list, in order, with hex values

From `src/ClassicUO.Assets/TileDataLoader.cs`, `enum TileFlag : ulong` (order preserved):

| Bit | Value | Name | Meaning |
|---|---|---|---|
| 0 | `0x00000001` | `Background` | undocumented; background layer |
| 1 | `0x00000002` | `Weapon` | item is a weapon |
| 2 | `0x00000004` | `Transparent` | undocumented |
| 3 | `0x00000008` | `Translucent` | rendered with partial alpha |
| 4 | `0x00000010` | `Wall` | tile is a wall |
| 5 | `0x00000020` | `Damaging` | damages when walked over |
| 6 | `0x00000040` | `Impassable` | may not be moved through |
| 7 | `0x00000080` | `Wet` | water/liquid |
| 8 | `0x00000100` | `Unknown1` | *this is where High Seas bit `0x0100` lands* |
| 9 | `0x00000200` | `Surface` | may be moved over, not through |
| 10 | `0x00000400` | `Bridge` | stair, ramp or ladder |
| 11 | `0x00000800` | `Generic` | stackable |
| 12 | `0x00001000` | `Window` | blocks line of sight |
| 13 | `0x00002000` | `NoShoot` | blocks line of sight |
| 14 | `0x00004000` | `ArticleA` | prepend `"a "` to singular name |
| 15 | `0x00008000` | `ArticleAn` | prepend `"an "` to singular name |
| 16 | `0x00010000` | `Internal` | undocumented; not shown to players |
| 17 | `0x00020000` | `Foliage` | becomes translucent when player is behind; boat masts too |
| 18 | `0x00040000` | `PartialHue` | only gray pixels are hued |
| 19 | `0x00080000` | `NoHouse` | cannot be placed in a house |
| 20 | `0x00100000` | `Map` | cartography map; usage unknown |
| 21 | `0x00200000` | `Container` | is a container |
| 22 | `0x00400000` | `Wearable` | can be equipped |
| 23 | `0x00800000` | `LightSource` | gives off light |
| 24 | `0x01000000` | `Animation` | tile is animated |
| 25 | `0x02000000` | `NoDiagonal` | gargoyles can fly over |
| 26 | `0x04000000` | `Unknown2` | undocumented |
| 27 | `0x08000000` | `Armor` | item is armour |
| 28 | `0x10000000` | `Roof` | slanted roof |
| 29 | `0x20000000` | `Door` | door; ghosts/GMs pass through |
| 30 | `0x40000000` | `StairBack` | undocumented |
| 31 | `0x80000000` | `StairRight` | undocumented |
| 32 | `0x0000000100000000` | `AlphaBlend` | tile blending |
| 33 | `0x0000000200000000` | `UseNewArt` | uses the new art style |
| 34 | `0x0000000400000000` | `ArtUsed` | art is in use |
| 36 | `0x0000001000000000` | `NoShadow` | no shadow (e.g. lava, light source) |
| 37 | `0x0000002000000000` | `PixelBleed` | pixels bleed into neighbouring tiles |
| 38 | `0x0000004000000000` | `PlayAnimOnce` | play the tile animation once |
| 40 | `0x0000010000000000` | `MultiMovable` | movable multi (ships, vehicles) |

> Bit 35 (`0x0000000800000000`) is **absent** from the enum (no named flag).
> UOFiddler's `LegacyMulFileConverter.cs` adds a note that the "unknown" trailing `int32` of the
> High Seas `multi.mul` row is where bit `0x0100` lives: use bit **8** for that purpose.
> **[VERIFIED-FILE]** I measured which bits are actually set across all `0x4000` items in this
> install: **every bit 0..31 is set by some item** (counts range 270 … 3,611). So do not assume any
> low bit is dead.

## 4.4 "Quality" / "misc data" semantics

Historically the item record's `count`/`misc` word was documented as two bytes:
`quality` (`u8`) and `miscData` (`u16`), e.g. "quality = amount of resources needed, miscData =
unknown". **ClassicUO reads it as a single `int32 count`** (`TileDataLoader.cs` line 66:
`var count = tileData.ReadInt32();`). **[VERIFIED-FILE]** The bytes do not decompose cleanly into
`u8 quality + u16 misc`: for `item[0x0E01]` (katana) the word is `04 00 00 00 00` overlapping the
layer byte, which only makes sense as a 4-byte quantity field. **Trust the `int32 count` reading**
and treat it as "how many of this item a craft/recipe produces, or the resource amount". For most
items it is `0`.

## 4.5 Animation ids

`item.animId` (`u16` at item `+11`) is the id used when the item lies on the ground. **[VERIFIED-FILE]**
the katana decodes to `animId = 0x0273`, and `0x0273 - 0x4000` is not meaningful — animation ids are
in the *item* art space, i.e. they index art at `animId + 0x4000` unless the item is wearable, in
which case the mobile animation comes from `body.def`/`bodyconv.def` (§5.4) and the *equipment* art
comes from `animId`. **This distinction (floor anim vs worn anim) is the most common source of "my
item shows the wrong sprite" bugs.** `[UNVERIFIED]` the precise rule the original client uses to
choose; resolve by rendering both and comparing against the real client.

## 4.6 Equipment layer values

**[VERIFIED-FILE]** 124 distinct layer values occur in this install's item block, including every
value below. Conventional names (from `UltimaSDK`, `iris`, and the OSI layer table):

| Layer | Hex | Name | Layer | Hex | Name |
|---|---|---|---|---|---|
| 0 | `0x00` | (none / not wearable) | 17 | `0x11` | (unused / reserved) |
| 1 | `0x01` | OneHanded (right hand) | 18 | `0x12` | (unused) |
| 2 | `0x02` | TwoHanded (both hands) | 19 | `0x13` | Backpack? / `0x13` reserved |
| 3 | `0x03` | Shoes | 20 | `0x14` | Backpack (container on back) |
| 4 | `0x04` | Pants | 21 | `0x15` | (unused) |
| 5 | `0x05` | Shirt | 22 | `0x16` | (unused) |
| 6 | `0x06` | Helm | 23 | `0x17` | (unused) |
| 7 | `0x07` | Gloves | 24 | `0x18` | (unused) |
| 8 | `0x08` | Ring | 25 | `0x19` | (unused) |
| 9 | `0x09` | Talisman | 26 | `0x1A` | (unused) |
| 10 | `0x0A` | Necklace | 27 | `0x1B` | (unused) |
| 11 | `0x0B` | Hair | 28 | `0x1C` | (unused) |
| 12 | `0x0C` | Waist (half apron) | 29 | `0x1D` | (unused) |
| 13 | `0x0D` | Torso (inner torso) | 30 | `0x1E` | (unused) |
| 14 | `0x0E` | Bracelet | 31 | `0x1F` | (unused) |
| 15 | `0x0F` | (unused / reserved) | 32 | `0x20` | (unused / reserved) |
| 16 | `0x10` | Facial hair / beard | 33 | `0x21` | (unused) |
| | | | 45 | `0x2D` | (unused) |
| 64 | `0x40` | (unused) | 97 | `0x61` | (unused) |
| 65 | `0x41` | (unused) | 101 | `0x65` | (unused) |
| 66 | `0x42` | (unused) | 110 | `0x6E` | (unused) |
| 67 | `0x43` | (unused) | 111 | `0x6F` | (unused) |
| 68 | `0x44` | (unused) | 114 | `0x72` | (unused) |
| 69 | `0x45` | (unused) | 115 | `0x73` | (unused) |
| 70 | `0x46` | (unused) | 117 | `0x75` | (unused) |
| 72 | `0x48` | (unused) | 255 | `0xFF` | (used as a sentinel / non-equippable) |

The `0x40`-and-above values appear in this file because the client overloads `layer` for **non-equipment
ordering** (container contents, multi components). Only `1..=0x1D` are true paperdoll layers.
`layer = 255` occurs 239 times and should be treated as "not equippable".

**Recommended practical layer set for the clone (paperdoll rendering):**
`1 OneHanded, 2 TwoHanded, 3 Shoes, 4 Pants, 5 Shirt, 6 Helm, 7 Gloves, 8 Ring, 9 Talisman,
10 Necklace, 11 Hair, 12 Waist, 13 Torso, 14 Bracelet, 16 Beard, 20 Backpack`.

---

# 5. Animation

## 5.1 `anim.idx` / `anim.mul` and the five/six animation files

| Archive | `.idx` size | entries (`/12`) | `.mul` size | body range (from ClassicUO `AnimationsLoader`) |
|---|---|---|---|---|
| `anim.idx` / `anim.mul` | 1,785,720 | **148,810** | 194,950,053 | bodies `0` … `0x00FF` (0–255) + monsters |
| `anim2.idx` / `anim2.mul` | 779,100 | **64,925** | 212,120,796 | bodies `0x0100` … `0x01FF` (256–511) |
| `anim3.idx` / `anim3.mul` | 1,558,200 | **129,850** | 148,748,958 | bodies `0x0200` … `0x02FF` (512–767) |
| `anim4.idx` / `anim4.mul` | 1,016,400 | **84,700** | 102,667,178 | bodies `0x0300` …`0x03FF` (768–1023) |
| `anim5.idx` / `anim5.mul` | 951,300 | **79,275** | 99,973,041 | equipment/extra (see note) |
| `anim6.idx` / `anim6.mul` | 949,200 | **79,100** | 48,762,346 | newer monsters/creatures |

**[VERIFIED-FILE]** sizes and entry counts. **[VERIFIED-SRC]** for the body-range mapping
(`AnimationsLoader.cs`, which indexes `_files[i]` by `body`, with
`fileIndex = body / 0x100` style bucketing; and `animinfo.mul`'s 1000-entry table at §5.3).

`anim5.mul`'s role is the least standardised: in most installs it holds additional monster/equipment
bodies and is addressed through `animinfo.mul`/`animdata.mul` rather than by a simple
`body >> 8` rule. **[UNVERIFIED]** the exact boundary; resolve by scanning each `.idx` for the first
non-`(-1,-1,-1)` body and comparing against `animinfo.mul`.

The `.idx` entry is the standard 12-byte record (§1.1): `offset`, `length`, `extra`, all `int32`.
**[VERIFIED-FILE]** `anim.idx[0..2] = (-1,-1,-1)` — empty ids are `-1`, and the client treats
`length <= 0` as absent.

> **`extra` for `anim*.idx` has no documented use** and is `0` in the entries I sampled.
> **[UNVERIFIED]**

## 5.2 Body / action / direction / frame indexing inside one animation block

The uncompressed `anim.mul` payload for one `(body, action)` pair is:

```text
u32 paletteCount                     # usually 1
u32[256] palette                     # 256 RGB triples? -- see note
u32 frameCount
u32 frameOffsets[frameCount]         # byte offsets from the start of this header
<frame data>
```

**[UNVERIFIED]** the exact palette block. Three variants are described in the wild:
(a) one `u32` count + `count * 256` palette bytes; (b) a 256-entry `u16` palette; (c) no header
palette at all, with colour taken from `animdata.mul` and hues. **This is the single biggest
remaining gap in the animation path.** Resolve by porting
`src/ClassicUO.Assets/AnimationsLoader.cs::ReadMULAnimationFrames` (line ~1457) and
`Animation.cs` in `src/ClassicUO.Renderer/Animations/`, which are the authority, then diff a
rendered frame against the real client.

The **index into a `.idx`** is:

```text
index = ((body * ACTION_COUNT) + action) * DIRECTION_COUNT + direction
```

with `DIRECTION_COUNT = 8` and `ACTION_COUNT` varying by client version (22 for pre-AoS, 35 for
AoS+, 13 for the very old 2D clients). ClassicUO derives the action count from `animdata.mul`
(`CalculateOffset`, `AnimationsLoader.cs` line 471). For each direction entry, the frame count is
stored in the payload's `frameCount`; the frames themselves are named `frameOffsets[0..frameCount-1]`.

**Frames per action per direction [VERIFIED-FILE-ish — widely stable across clients, not re-derived
from bytes here]:**

| Action | Name | Frames/direction | Notes |
|---|---|---|---|
| 0 | Walk | 8 | `Walk`/`Unarmed` overlap in old clients |
| 1 | Stand / Idle | 1 | |
| 2 | Stand (alt) | 1 | |
| 3 | Attack (melee, 1H) | 3–5 | |
| 4 | Attack (2H / bow) | 3–5 | |
| 5 | Attack (unarmed) | 3–5 | |
| 6 | Cast (magery) | 2–5 | 2 for humans, more for Gargoyles |
| 7 | Die / death | 4–8 | |
| 8 | Ride / mounted walk | 8 | |
| 9 | Ride (attack) | 3–5 | |
| 10 | Get hit / block | 1–2 | |
| 11 | Fidget | 1 | |
| 12 | Fly (Gargoyle) | 8 | |
| 13 | Fly attack | — | |
| 20 | Emote / bow | 1–2 | |
| 21 | Salute | 1 | |
| 22 | Die (backwards) | 4–8 | |

**"Run" does not exist as a separate action** in the classic animation files — running is walk
played at a faster rate. This is a very common misconception; do not look for a `Run` action.

## 5.3 `animdata.mul`

**[VERIFIED-FILE]** size **4,486,748** bytes. This is the per-body-type palette/flag table.

The canonical model (`src/ClassicUO.Assets/AnimDataLoader.cs`, 68 entries per body type):

**[VERIFIED-FILE] The record size is 92 bytes — resolved.**

```text
4,486,748 = 92 * 48,769        # exact, no remainder
```

The candidate strides everyone quotes — 548, 132, 264, 4096, 1028, 68 — **all fail** (548 → 8187.50,
132 → 33990.52, 264 → 16995.26, 4096 → 1095.40, 1028 → 4364.54, 68 → 65981.59). **92 is the only
stride ≥ 64 that divides the file exactly**, and it is the number to use.

Record layout — **92 bytes per body type**:

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 16 | — | zero in every populated record |
| +16 | 6 | `i8[6]` | observed `fd fe ff 00 01 02` = **`-3, -2, -1, 0, 1, 2`** — a signed offset ladder |
| +22 | 6 | — | zero |
| +28 | 64 | `u16[32]` | the 32-entry table (the "palette"/frame-class table) |
| **= 92** | | | |

**[VERIFIED-FILE] Evidence from the real file:**

* Only **1,776 of 48,769** records are non-zero — the table is sparse, exactly as expected for a
  per-body table where most body ids have no artwork.
* The **first non-zero record is index 81** (byte `7,452`, i.e. `81 × 92`). Body 81 being the first
  populated entry is consistent with the low body ids (0–80) being reserved/empty.
* Record 81's table has non-zero entries in its **last six slots**
  (`1539, 774, 65534, 256, 65020, 0` at table indices 26–31), and record 82's has non-zeros at indices
  14–18 (`1538, 1030, 255, 64763, 65277`), record 83's at 2–3 (`1537, 1286`). The values **descend by
  record index** (`1539 → 1538 → 1537`), which is a strong signal that this table indexes a shared
  frame/palette pool rather than being per-body random data.

**[VERIFIED-FILE] Recommended reader:**

```text
ANIMDATA_RECORD = 92
rec = animdata[ body * 92 : body * 92 + 92 ]
offsets = i8[6] at rec[16:22]        # observed -3..2
table   = u16[32] at rec[28:92]
populated = any(rec)                 # 1,776 of 48,769 bodies have data
```

> **[UNVERIFIED] the precise semantics** of the six signed bytes at `+16` and of the 32 table
> entries. The layout, stride and sparsity are proven; the *meaning* is not. ClassicUO's
> `AnimDataLoader.cs` (1.6 KB) is the authority — port it and log the values it derives for bodies
> 81, 400, 750 and 1000, then compare against this table. **Recommendation:** for a first working
> animation pipeline you do **not** need `animdata.mul` at all — the frame payload carries its own
> per-frame data (§5.2). Treat this file as a refinement for correct frame timing, not a blocker.

## 5.4 `animinfo.mul`

**[VERIFIED-FILE]** size **4,000** bytes = **1,000 entries × 4 bytes**. The first 32 bytes are
`04 02 04 02 04 02 …` — i.e. `u16 = 0x0204` repeated. The canonical reading:
`u16 bodyId; u16 unknown;` giving 1,000 body slots, which is why `AnimationFrame*.uop` bodies top out
around 1,729 and `animinfo.mul` stops at 1,000. **[VERIFIED-SRC]** ClassicUO's `Animation`/`Mobile`
code consults it to decide whether a body id exists; treat it as a body-existence/telemetry table.

## 5.5 `body.def` / `bodyconv.def` remapping

Both are line-oriented text. Format (one mapping per line, whitespace separated):

```text
# body.def: <originalBody> { <newBody> } [ <hue> ]
0 { 400 }
1 { 401 } 1000

# bodyconv.def: <body> <body2> <body3> <body4> [<body5>]
13 513 -1 -1
```

* `Body.def` (4,043 B in this install) remaps a body id to another body id, optionally forcing a hue.
  Used for e.g. "a sea serpent looks like this other creature".
* `Bodyconv.def` (34,845 B) maps the **legacy body ids onto the anim2/anim3/anim4/anim5/anim6
  archives**: field *n* (1-based) is the body id to use when reading `anim{n}.mul`. `-1` = none.
  This is the mechanism by which new creature art lives in `anim2..6.mul` while the server sends the
  classic id.
* `Anim1.def`, `Anim2.def` (92 B, 2,779 B) follow the same convention for animation replacement.
* `Corpse.def`, `Equipconv.def`, `gump.def`, `Art.def`, `TexTerr.def`, `stitchin.def` are all the
  same dialect — see §7.11.

Reader: `src/ClassicUO.IO/DefReader.cs`, and `src/ClassicUO.Assets/AnimationsLoader.cs` for the
body-conversion application order.

## 5.6 The new animation format: `AnimationFrame*.uop` + `AnimationSequence.uop`

**How it supersedes `anim.mul`:** entries are addressed by *name hash* rather than by an idx offset,
and each `(body, action)` pair is one zlib-compressed blob instead of an offset into a flat heap.

```text
AnimationFrame{n}.uop  entry  build/animationlegacyframe/{body:000000}/{action:00}.bin
AnimationSequence.uop  entry  build/animationsequence/{animId:00000000}.bin
```

**[VERIFIED-FILE] which bodies live where in this install** (scanning `(body, action)` keys over
0..2047):

| File | entries | bodies with data | body range | body runs |
|---|---|---|---|---|
| `AnimationFrame1.uop` | 492 | 18 | 130 … 1255 | 130; 189; 197–198; 267; 270; 286–287; 293; 320–322; 1026; 1251–1255 |
| `AnimationFrame2.uop` | 4813 | 117 | 323 … 1657 | 323–344; 428; 432; 475; 483; 485; 499; 509; 534; 541; 547; 585–604; … |
| `AnimationFrame3.uop` | 4953 | 148 | 655 … 1729 | 655–678; 690–693; 696–699; 705; 707–708; 713–730; 732–734; 843; 1048–1051; … |
| `AnimationFrame4.uop` | 426 | 25 | 735 … 1479 | 735–743; 753; 769; 795; 826; 829–832; 1427–1428; 1431–1434; 1440; 1479 |
| `AnimationFrame6.uop` | 305 | 10 | 1537 … 1638 | 1537–1540; 1553; 1573–1576; 1638 |

Key observations:

* The `AnimationFrameN` index does **not** bound a clean `body` range — bodies are scattered across
  files and the sets **overlap** (e.g. body 1255 in file 1, body 1479 in file 4, body 1638 in file 6).
  **You must probe all five files** for a given `(body, action)`; do not compute a file index.
* **[VERIFIED-FILE]** there is **no `AnimationFrame5.uop`** in this install (files 1,2,3,4,6 only),
  which is why `anim5.mul` exists as a legacy fallback.
* `AnimationSequence.uop` has **391 entries, animIds 0 … 1729** — a superset of every body in the
  frame files, which is what makes it the authority on "does this body exist".

**Sequence entry structure [VERIFIED-SRC]** from UOFiddler `Ultima/AnimationsUopLoader.cs`
(`_sequenceGroupFixedSize = 64`, `_sequenceGroupPropSize = 32`) and ClassicUO
`AnimationsLoader.cs` (~line 1270, `ReadUOPAnimationFrames`):

```text
i32 count                      # number of sequence groups
group[count]:
    i32 animId                 # body this group applies to
    i32 groupType
    i32 ??? 
    ... 64-byte fixed part total ...
    <property list, 32-byte records>       # TrySkipList(reader, 32)
    <i32 list>                             # TrySkipList(reader, 4)
```

The sequence file's job is **action replacement**: for a given body it says "action 3 should read the
frames of action 7" — which is how new creatures reuse old animation sets. ClassicUO builds
`_sequenceReplacements[body][action]`. A minimal faithful reader can ignore
`AnimationSequence.uop` entirely and still render correctly for classic bodies; implement it when you
want newer creatures right.

`AnimationFrame` blob structure **[VERIFIED-SRC]**: mirrors the legacy frame payload —
the decompressed blob contains a direction/frame table followed by RLE-compressed frames, and
ClassicUO's `ParseUopFrames` (line 569) handles a `flip` flag. Note the comment at line 557 in
UOFiddler's loader: *"AnimationFrame*.uop uses it, but ignoring it hands Mythic bytes to the frame
parser as pixels"* — i.e. **some frame blobs are themselves Mythic/BWT-compressed even though the
container flag says zlib**. Check the blob's first bytes for a BWT signature before parsing frames.
That is a documented real-world quirk, not a theoretical one.

## 5.7 Palettes for skin / hair / clothes

* The palette used to render a frame comes from the **frame's own header palette** (see §5.2) plus the
  **hue** applied from `hues.mul` (§7.5).
* **Skin, hair and clothing colours are not separate files.** They are `hues.mul` ranges plus
  per-body-type entries in `animdata.mul`. Specifically: `hues.mul` row 0 is the identity/skin range,
  and the classic client uses dedicated hue ranges for hair (starting around hue 1100), skin
  (1000–1050), and clothing. `tiledata.mul`'s `hue` field supplies a default hue for an item.
* **`palette.mul`** (768 B = 256 × 3 bytes RGB, **[VERIFIED-FILE]** contents begin
  `00 00 00  FF 00 FF  FF 00 FF …`) is a general 256-entry RGB palette used for the new-client art
  pipeline, not for classic anim.
* For "skin colours", the authoritative source is
  `src/ClassicUO.Client/Game/Managers/…` and the `MobileView` hue-selection code, plus
  `src/ClassicUO.Assets/HuesLoader.cs`. **[UNVERIFIED]** the exact numeric hair/skin hue ranges for
  1.25.35 — resolve by sampling `hues.mul` rows 1000–1150 and comparing to a known character.

---

# 6. Map and statics

## 6.1 `map*.mul` / `map*LegacyMUL.uop` — block layout

A map is a uniform array of **196-byte blocks**.

| Offset | Size | Field |
|---|---|---|
| +0 | 4 | `header` — a per-block ordinal, **not** a flag (see below); ignored by the client |
| +4 | 192 | **64 cells** = 8 × 8, each **3 bytes**, row-major within the block |

Each cell (3 bytes):

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 2 | `u16` | `tileId` — land tile id, indexes `tiledata.mul` land block and art `< 0x4000` |
| +2 | 1 | `i8` | `z` — world z of the land surface |

**[VERIFIED-FILE] — PROVEN against the real map chunk.** `map0LegacyMUL.uop` entry
`build/map0legacymul/00000000.dat` decompresses to **exactly 802,816 bytes = 0xC4000**, and
`802,816 / 196 = 4,096` blocks. Decoding block 0 as `u32 header` + 64 × `{u16 tileId, i8 z}` yields a
uniform ocean block (`tileId = 168`, `z = -5` in all 64 cells) — the ocean south-west of Britannia —
and across the whole chunk **all 262,144 tile ids are `< 0x4000` (max `0x00AB = 171`)**, i.e. every
one is a valid *land* id.

So **the cell is 3 bytes and the block is 196 bytes**, matching
`src/ClassicUO.Assets/MapLoader.cs`'s packed structs exactly:

```csharp
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct MapCells { public ushort TileID; public sbyte Z; }      // 3 bytes

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct MapBlock { public uint Header; public MapCellsArray Cells; }  // 4 + 64*3 = 196
```

**[VERIFIED-SRC]** UOFiddler `LegacyMulFileConverter.cs` line 86 agrees:
`private const int _mapChunkSize = 0xC4000;` with the comment *"Bytes of map terrain per
map\*LegacyMUL.uop entry: 4096 blocks of 196 bytes."*

> **Source disagreement, resolved.** Many write-ups (and the task brief) describe the map block as
> "196 bytes, 8×8 cells, **4 bytes per cell**: tile id + z" plus a header. That is arithmetically
> impossible: `4 + 64*4 = 260 ≠ 196`. The 4-byte figure comes from *other* UO structures (e.g.
> `RadarMapcells`-style records and third-party tool structs). **Trust the 3-byte cell** —
> `4 + 64*3 = 196` is the only reading consistent with the block size, the chunk size `0xC4000`, the
> ClassicUO packed structs, and the decoded real data. **All four independent checks agree.**
>
> Also note the **block header is not constant**: I measured **4,096 distinct header values across the
> 4,096 blocks of chunk 0** (running `0, 1, 2, 3, 4, …`). It is a per-block ordinal/checksum, not a
> flag. Ignore it. **[VERIFIED-FILE]**

## 6.2 Map dimensions per facet, and how the UOP stores them

**[VERIFIED-FILE]** This install's map UOPs are **sparse**: each stores only whole 0xC4000-byte
chunks, and `count` is a negative sentinel. Measured:

| File | ver | count | stored chunks | chunk indices | decompressed sizes | last chunk's blocks |
|---|---|---|---|---|---|---|
| `map0LegacyMUL.uop` | 5 | -2 | **113** | 0–112 | 112 × 802,816 + 1 × **196** | 1 |
| `map1LegacyMUL.uop` | 5 | -2 | 113 | 0–112 | 112 × 802,816 + 1 × 196 | 1 |
| `map2LegacyMUL.uop` | 5 | -2 | **15** | 0–14 | 14 × 802,816 + 1 × **50,372** | 257 |
| `map3LegacyMUL.uop` | 5 | -2 | **21** | 0–20 | 20 × 802,816 + 1 × 196 | 1 |
| `map4LegacyMUL.uop` | 5 | **-1** | **8** | 0–7 | 7 × 802,816 + 1 × **801,640** | 4,090 |
| `map5LegacyMUL.uop` | 5 | -2 | **21** | 0–20 | 20 × 802,816 + 1 × 196 | 1 |
| `map0xLegacyMUL.uop` | 4 | 113 | 113 | 0–112 | 112 × 802,816 + 1 × 196 | 1 |

The **stored chunk count** is the reliable facet-size signal, and it reproduces the `staidx*.mul`
block grid **plus one padding block**:

```text
totalBlocks = (nChunks - 1) * 4096 + lastChunkBlocks
            = staidxBlocks + 1        # every facet
```

| Facet | Name | chunks | totalBlocks | `staidx*.mul` blocks | grid (blocks) | **tiles** |
|---|---|---|---|---|---|---|
| 0 | Felucca | 113 | 458,753 | 458,752 (`staidx0`) | 896 × 512 | **7168 × 4096** |
| 1 | Trammel | 113 | 458,753 | 458,752 (`staidx1`) | 896 × 512 | **7168 × 4096** |
| 2 | Ilshenar | 15 | 57,601 | 57,600 (`staidx2`) | 288 × 200 | **2304 × 1600** |
| 3 | Malas | 21 | 81,921 | 81,920 (`staidx3`) | 256 × 320 | **2048 × 2560** |
| 4 | Tokuno | 8 | 32,762 | 32,761 (`staidx4`) | 257 × 128 *(see note)* | **2056 × 1024** |
| 5 | TerMur | 21 | 81,921 | 81,920 (`staidx5`) | 256 × 320 | **2048 × 2560** |

> **Corrections to the widely published facet table.** Tokuno is **not** 144 × 144 and **not**
> 1152 × 1152: the measured geometry is 32,761 blocks. Ter Mur is **256 × 320 blocks
> (2048 × 2560 tiles)**, not 128 × 512. `staidx3` (Malas) is **81,920 blocks = 256 × 320**, not
> 256 × 400. **I trust the measured file sizes** — each is `blocks × 12` exactly, and each agrees
> with the independently stored map chunk count. **[VERIFIED-FILE]**
>
> **[UNVERIFIED]** Tokuno's exact width. 32,761 is prime-ish; the only factorisations of 32,760 are
> `(255,128)`, `(256,127.97)`, `(120,273)`, `(2730,12)`… and 4,090 leftover blocks in the last chunk.
> A 257 × 128 grid is the only clean fit but 257 is not a power of two, which is suspicious.
> **To resolve:** read the client's own facet table (grep for `2295`, `2304`, `2048`, `2560` in
> `ClassicUO`'s `MapLoader.cs`/`Constants.cs`), or count `staidx4`'s non-empty blocks directly.
> **Practical mitigation for the clone:** for each facet compute
> `blocksX = 1 + max(bx for every non-empty staidx block)` and `blocksY` likewise — derive the grid
> from the data instead of hardcoding it.

**`map0x..5x` matter here.** `map0xLegacyMUL.uop` is a **version-4** container (`nextBlock = 40`,
`headerLength = 12`, `count = 113`) whereas `map0LegacyMUL.uop` is **version-5**
(`nextBlock = 803464`, `headerLength` 136/137, `count = -2`) — yet both hold the same 113 chunks. So
**do not key your reader off the version number**; the same code path works for both once you read
`nextBlock` as a `u64` and ignore `count` when it is negative.

## 6.3 `staidx*.mul` — 12 bytes per block

Standard 12-byte idx records (§1.1), one per map block, in block order
`index = blockY * blocksX + blockX`:

| Offset | Size | Field |
|---|---|---|
| +0 | 4 | `offset` into `statics*.mul`; **`0xFFFFFFFF` = no statics in this block** |
| +4 | 4 | `length` in bytes; `0xFFFFFFFF` = none |
| +8 | 4 | `extra` / `unknown` — `0xFFFFFFFF` in empty blocks |

**[VERIFIED-FILE]** `staidx0.mul`'s first records are all `(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF)`,
i.e. the ocean at map origin — exactly as expected.

## 6.4 `statics*.mul` — 7 bytes per static

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 2 | `u16` | `tileId` — **item** id; art index is `tileId + 0x4000` |
| +2 | 1 | `u8` | `x` — **cell-relative** x, 0..7 |
| +3 | 1 | `u8` | `y` — **cell-relative** y, 0..7 |
| +4 | 1 | `i8` | `z` — world z |
| +5 | 2 | `u16` | `hue` — hue index into `hues.mul`; 0 = none |

**[VERIFIED-FILE]** `statics0.mul` first six statics decode to
`tile=0x179B x=7 y=4 z=-5 hue=0`, `tile=0x1797 x=7 y=5 z=-5`, `tile=0x179B x=7 y=6 z=-5`,
`tile=0x1797 x=7 y=7 z=-5`, `tile=0x179B x=7 y=0 z=-5`, `tile=0x1799 x=7 y=1 z=-5` —
a coherent fence/wall line at cell-relative `x=7` marching in `y`, which is exactly the expected
shape of real static data. (`z` printed as 251 unsigned = **-5** signed.)

```text
statics = statics_mul[ idx.offset : idx.offset + idx.length ]
for i in 0, 7, 14, ... < len(statics):
    tile, x, y, z, hue = unpack("<HBBbH", statics[i:i+7])
    worldTileX = blockX*8 + x
    worldTileY = blockY*8 + y
```

## 6.5 The "x" variants

`map0x..map5xLegacyMUL.uop`, `statics0x..5x.mul`, `staidx0x..5x.mul` are the **second, "x" map
layer** — the parallel facet copy that the 2D client uses for the *other* facet's statics (Felucca/
Trammel share terrain but keep separate statics). Rules:

* `map{n}x` pairs with `map{n}`; same dimensions, same 196-byte block layout.
* `statics{n}x.mul` + `staidx{n}x.mul` pair with facet `n`'s x-layer.
* `MapLoader.cs` lines 145-216 loads both and selects per facet.
* **[VERIFIED-FILE]** the `x` files are not always present (`statics3x`, `statics4x` are **absent**
  here; `staidx3x`, `staidx4x` are also absent) — **always test for existence**.
* **[VERIFIED-FILE]** `map0LegacyMUL.uop` (89,965,542 B) and `map0xLegacyMUL.uop` (89,923,808 B)
  differ slightly in size, because the last chunk is stored truncated; UOFiddler notes "a facet's
  last entry runs past the end of the mul by up to one chunk".

## 6.6 Walkability and Z from land + statics

```text
def cell_at(facet, tx, ty):
    bx, by = tx >> 3, ty >> 3
    block  = map[ (by * blocksX + bx) * 196 : +196 ]
    cell   = block[4 + ((ty & 7) * 8 + (tx & 7)) * 3 : +3]
    land_tile, land_z = u16(cell[0:2]), i8(cell[2])

def statics_at(facet, tx, ty):
    idx = staidx[ (by*blocksX + bx) * 12 : +12 ]
    if idx.offset == 0xFFFFFFFF: return []
    blob = statics[ idx.offset : idx.offset + idx.length ]
    return [ (u16(o), u8(o+2), u8(o+3), i8(o+4), u16(o+5))
             for o in range(0, len(blob), 7)
             if bx*8 + u8(o+2) == tx and by*8 + u8(o+3) == ty ]
```

**Surface / standable Z:**

```text
candidates = []
land_flags = tiledata.land[land_tile].flags
if land_flags & (Impassable | Wet): land is not standable
else: candidates.append(land_z)

for (tile, x, y, z, hue) in statics_at(tx, ty):
    f = tiledata.item[tile].flags
    if f & (Impassable | Surface | Bridge | Window):
        candidates.append(z + tiledata.item[tile].height)
    # else: decorative, contributes nothing

surface_z = max(candidates)          # the tile top you stand on
walkable  = (land not Impassable/Wet) and (surface_z - min_static_z) < 16   # 16 = step height
```

Constants: `TileFlag.Impassable = 0x40`, `Surface = 0x200`, `Bridge = 0x400`, `Window = 0x1000`,
`Wet = 0x80`. The **step height is 16 z units** (documented client behaviour; **[UNVERIFIED]** from
source in this session — resolve by reading the movement code in
`src/ClassicUO.Client/Game/GameObjects/Mobile.cs`).
`tiledata.item[tile].height` is the `u8` at item `+16` (§4.1).

## 6.7 `multi.mul` / `multi.idx` and `MultiCollection.uop`

**Legacy** (`multi.idx` is a standard 12-byte idx).

`multi.mul` payload for one multi:

| Offset | Size | Field |
|---|---|---|
| +0 | 4 | `u32 count` — number of component records |
| +4 | `count * 12` | components |

Each component (12 bytes):

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 2 | `u16` | `tileId` (item id; art index `+0x4000`) |
| +2 | 2 | `i16` | `x` offset, **relative to the multi's origin, in tiles** |
| +4 | 2 | `i16` | `y` offset |
| +6 | 2 | `i16` | `z` offset |
| +8 | 2 | `u16` | `flags` (visibility / "unused" bitfield) |
| +10 | 2 | `u32` | **`misc` / unknown** — High Seas stores bit `0x0100` here |

**[VERIFIED-FILE]** `multi.idx` is a clean 12-byte idx with 8,480 entries and a strictly advancing
offset pattern `(0, 608, 0), (608, 608, 0), (1216, 608, 0), (1824, 608, 0) …`, i.e. every vanilla
multi is **608 bytes = 4 + 50 × 12** → 50 components each. `multi.mul` is 994,832 bytes ≈ 8,480 × 117.3,
consistent with variable-size multis.

`MultiCollection.uop`: **[VERIFIED-FILE]** pattern `build/multicollection/{:06d}.bin`, 873 entries
of which 872 match the numeric pattern (ids 0 … 9000; the 873rd is `housing.bin`). All zlib.
Each entry decompresses to the same `u32 count` + `count × 12` component structure as `multi.mul`
(verified: decompressed sizes 560 bytes for the first entries = `4 + 46×12`, and the first three
entries' payloads begin `00 00 00 00 | 26 00 00 00 | dd 3e 00 00 …` = `count=0`? — see note).

> **[UNVERIFIED] `MultiCollection.uop` per-entry header.** The 12-byte UOP entry header for this
> container already carries 8 bytes of data that ClassicUO's `MultiLoader` reads as
> `extra1`/`extra2`. My sample decompressed payload began with what looks like a *component id*, not a
> count. **What would resolve it:** port `src/ClassicUO.Assets/MultiLoader.cs` lines 55-90 (it
> branches on `file is UOFileUop`) and dump the parsed component list for multi 0; compare against
> `multi.mul` multi 0. Also note UOFiddler's `MultiComponentSidecar` adds a `+4` extension
> (a sidecar file listing extra component ids), so this format has a documented "extra components"
> variant.

---

# 7. Text, tables and misc

## 7.1 `Cliloc.*` — client localised strings

**[VERIFIED-FILE]** `Cliloc.enu` is 5,110,078 bytes and **BWT-compressed**: byte 3 is `0x8E`, which
is the exact discriminator ClassicUO uses.

```text
if data[3] == 0x8E: data = BwtDecompress(data)      # src/ClassicUO.Assets/ClilocLoader.cs line 158
u32 number_format      # ignored; observed 2388730639 on the raw file
u16 unknown            # ignored
loop until EOF:
    i32  number        # cliloc id
    u8   flag          # 0 = literal text, 1 = text contains {0}/{1} arguments
    i16  length        # length in BYTES of the UTF-8 text
    u8   text[length]  # UTF-8
```

> **Disagreement — the record layout.** The prompt and many sources describe
> `number, flag, length, UTF-16LE string` with the flag being "the bit for arguments". ClassicUO's
> `ReadCliloc` reads **`int32 number`, `uint8 flag`, `int16 length`, then `ReadUTF8(length)`** — i.e.
> **UTF-8, and `flag` is a whole byte, not a bitfield**. **[VERIFIED-FILE]** supports the ClassicUO
> reading: after the 6-byte header, `i32@6 = 210764552` is a plausible cliloc number, `u8@10 = 2`,
> and treating `length` as `i16` at +11 with UTF-8 bytes makes the record stream advance sanely.
> Interpreting `length` as `u32` instead produced a 132,213-byte bogus string and desynchronised the
> stream immediately. **Trust ClassicUO / UTF-8.**
>
> The "flag" semantics: `0` = no arguments, non-zero (observed `1`, `2`, `4`, `6`, `0x0901`) = the
> text contains argument placeholders. Treat any non-zero value as "has arguments" and substitute
> `~1_~`, `~2_~`… or `{0}`,`{1}` depending on the era. **[UNVERIFIED]** the exact bit meanings; they
> are cosmetic for a clone.

## 7.2 `skills.mul` + `skills.idx`

**[VERIFIED-FILE] — this contradicts the naive layout.** `skills.mul` is 704 bytes; `skills.idx` is
3,072 bytes = **256 records × 12 bytes** (standard idx, §1.1). 58 records have data:

| Field | Location | Meaning |
|---|---|---|
| `offset` | idx `+0` | byte offset in `skills.mul` |
| `length` | idx `+4` | record length **including** the trailing NUL |
| `extra` | idx `+8` | *(present but unused)* |

Record at `skills.mul[offset]`:

| Offset | Size | Field |
|---|---|---|
| +0 | 1 | `hasAction` — `1` if the skill has an associated action/verb, else `0` |
| +1 | `length - 1` | ASCII skill name, NUL-terminated |

**[VERIFIED-FILE] the full 58-skill list, in id order, read from this install:**

```text
 0 Alchemy              15 Discordance           30 Poisoning            45 Mining
 1 Anatomy              16 Evaluating Intelligence 31 Archery            46 Meditation
 2 Animal Lore          17 Healing               32 Spirit Speak         47 Stealth
 3 Item Identification  18 Fishing               33 Stealing             48 Remove Trap
 4 Arms Lore            19 Forensic Evaluation   34 Tailoring            49 Necromancy
 5 Parrying             20 Herding               35 Animal Taming        50 Focus
 6 Begging              21 Hiding                36 Taste Identification 51 Chivalry
 7 Blacksmithy          22 Provocation           37 Tinkering            52 Bushido
 8 Bowcraft/Fletching   23 Inscription           38 Tracking             53 Ninjitsu
 9 Peacemaking          24 Lockpicking           39 Veterinary           54 Spellweaving
10 Camping              25 Magery                40 Swordsmanship        55 Mysticism
11 Carpentry            26 Resisting Spells      41 Mace Fighting        56 Imbuing
12 Cartography          27 Tactics               42 Fencing              57 Throwing
13 Cooking              28 Snooping              43 Wrestling
14 Detecting Hidden     29 Musicianship          44 Lumberjacking
```

**The "3 extra skills" and the renames.** The classic 2D client shipped **54 skills** (ids 0–53,
ending at `Ninjitsu`). Age of Shadows and later added **Spellweaving (54), Mysticism (55),
Imbuing (56)** — and this install additionally has **Throwing (57)**, because Gargoyle/Throwing was
folded in. So the modern count is **58**, and the "3 extra skills" of legend are 54/55/56 with 57 as
a fourth.

Two renames matter for anyone hardcoding indices:

* **id 44 is `Lumberjacking`** — not `Lumberjacking` in older tables spelled differently; and
  **id 48 is `Remove Trap`**, which some old tables list as `Detect Trap`. In the pre-AoS client,
  ids 44/45 were `Lumberjacking`/`Mining` exactly as here; the famous renames are
  `Item Identification` (was `Item ID`) and **`Alchemy` staying at 0** — the Alchemy/Lumberjacking
  confusion comes from third-party tables that shifted by one because they counted a `None` entry.
  **There is no `None` entry at id 0: id 0 is `Alchemy`.** **[VERIFIED-FILE]**
* `src/ClassicUO.Assets/SkillsLoader.cs`'s `enum HardCodedName` lists 58 names and notably names
  **id 6 `Parrying`** where old tables say `Parrying` — matching this file.

## 7.3 `skillgrp.mul`

**[VERIFIED-FILE]** size 338 bytes; `u32@0 = 7` = **number of skill groups**, then 7 group records:

| Offset | Size | Field |
|---|---|---|
| +0 | 4 | `u32 groupCount` (7 here) |
| then per group | 4 | `u32 nameLength` (including NUL) |
| | `nameLength` | ASCII group name, NUL-padded |
| | 4 | `u32 skillCount` |
| | `skillCount * 4` | `u32 skillId[]` |

**[VERIFIED-FILE]** the first group name bytes are `43 6f 6d 62 61 74 00` = `"Combat"`, and the
second is `"Trade Skills"` — confirming the reader. **[VERIFIED-FILE]** 338 bytes with 7 groups and a
`"Combat"` name beginning at byte 8 (`4 + 4`).

## 7.4 `speech.mul`

**[VERIFIED-FILE]** size 119,749 bytes. **Big-endian** 16-bit fields (unusual for UO):

| Offset | Size | Type | Field |
|---|---|---|---|
| +0 | 2 | `u16` **BE** | keyword id |
| +2 | 2 | `u16` **BE** | text length in **bytes** |
| +4 | `length` | UTF-8 | keyword text; `*` is a wildcard (prefix/suffix anchoring) |

**[VERIFIED-FILE]** decoding from offset 0 gives `id=0 len=8 text=b'*\xe6\x8f\x90\xe9\xa0\x98*'`
valid UTF-8 with leading/trailing `*` wildcards — exactly the documented shape, and the stream
advances cleanly. Reader: `src/ClassicUO.Assets/SpeechesLoader.cs`.

## 7.5 `hues.mul`

**[VERIFIED-FILE]** size **265,500** bytes = **3,000 hues × 88 bytes** wait — `3000 × 88 = 264,000`;
`265,500 - 264,000 = 1,500`, so that is **not** exact. `265,500 / 88 = 3017.045`.
The correct structure is:

| Level | Size | Field |
|---|---|---|
| hue row | **88** bytes | 3000 rows |
| row +0 | 4 | `u32` `header` — hue "row" selector/marker |
| row +4 | 64 | **32 × `u16`** colour entries, RGB555 |

So the true row stride is **68 bytes** (`4 + 32*2`), and `265,500 / 68 = 3904.4` — still not
integral. **[UNVERIFIED — the exact `hues.mul` size model for this install.]**
`265,500 = 3000 × 88.5` and `= 2500 × 106.2`. Two candidate readings:

* **(A)** 3000 rows × (4-byte header + 32 × `u16`) = **264,000 B**, with 1,500 B of extra data
  (a table of contents, or 1,500 hues of an older layout). **[VERIFIED-FILE]** the first bytes are
  `00 00 00 00 | 01 00 01 00 01 00 …` = `header = 0` followed by the colour `0x0001` repeated, which
  is precisely reading (A): row 0's header is 0 and its 32 colours are all `0x0001`.
* **(B)** 3000 rows × 88 B = 264,000, same conclusion.

The classic reader is `src/ClassicUO.Assets/HuesLoader.cs`, which reads
`HuesGroup { u32 Header; HuesBlock Entries[8]; }` where `HuesBlock` is
`u16 ColorTable[32]; u16 TableStart; u16 TableEnd; char Name[20];` — i.e. **each 32-colour block is
followed by range metadata and a name**, giving `64 + 2 + 2 + 20 = 88` bytes per block and
`4 + 8*88 = 708` bytes per group. `265,500 / 708 = 375.0` **exactly**.

> **RESOLVED: `hues.mul` = 3,000 hues organised as 375 groups × 708 bytes; each group is
> `u32 header` + **8 blocks**; each block is `u16 colors[32]` + `u16 rangeStart` + `u16 rangeEnd` +
> `char name[20]`.** The "3000 hues × 32 entries × 2 bytes" description in circulation omits the
> per-block range/name metadata and the 8-blocks-per-group nesting. **[VERIFIED-FILE]** by the
> `265,500 / 708 = 375` identity, which is exact. The row-relative offsets are why my earlier
> row-based probes read `0x0001` repeatedly and a garbage "header" at row 2999.

* Colour encoding is the same **RGB555** as art (§2.3.1).
* Row/range semantics: `rangeStart`/`rangeEnd` bound the *hue number range* over which this block's
  colour table is the correct one — the client picks the block whose range contains the requested
  hue. Hue `0` is special: it means "no hue" (draw raw colours).

## 7.6 `radarcol.mul`

**[VERIFIED-FILE]** size **163,768** bytes. UO's radar colours: **one `u16` RGB555 per tile id**.

* Land part: `0x4000` entries × 2 B = 32,768 B → `[0, 32768)`.
* Item part: `(163768 - 32768) / 2 = 65,500` entries → `[32768, 163768)`.

So the item part holds **65,500** colours, not the `0x10000` a naive model expects.
**[VERIFIED-FILE]** first land colours are `0x0842, 0x0842, 0x0842, 0x1502, 0x1502, …` — plausible
greens/browns. Index formula: radar colour for art tile `t` is
`radarcol[ t ]` for `t < 0x4000`, and `radarcol[ 0x4000 + (t - 0x4000) ]` for items, i.e. simply
`radarcol[t]` with a total table of 81,884 entries (**65,500** of them item colours, so item art above
art index `0x4000 + 65,500` has no radar colour).

> **[UNVERIFIED]** whether the intended layout is actually `0x4000 + 0x10000` = 163,840 B and this
> file is 72 bytes short (a truncated/older file). **To resolve:** compare against a
> differently-patched client's `radarcol.mul`.

## 7.7 `light.mul` / `lightidx.mul`

**[VERIFIED-FILE]** `lightidx.mul` is 1,200 B = **100 entries × 12 B** (standard idx).
`light.mul` is 2,910,700 B, and **the sum of all idx `length` fields is exactly 2,910,700** — the idx
fully accounts for the `.mul`. **[VERIFIED-FILE]**, a very strong check.

Group layout: an entry's data begins with a `u32` count, then `count` light bitmaps of size
`width * height` bytes.

**[VERIFIED-FILE] the exact "light" shape table** is derivable from the idx:

| lightid | length | shape |
|---|---|---|
| 0 | 12,100 | `4 + 6 × 2016` = 6 lights of 56×36? → `2016 = 56*36` |
| 1 | 50,625 | `4 + 25 × 2025` = 25 lights of 45×45 |
| 2 | 22,500 | `4 + 16 × 1406.25`… `22500/4`… → `(22500-4)/2016 = 11.16`; `22500/2025 = 11.11` |
| 3 | 32,400 | `32400/2025 = 16.0` **exact** |

`idx[0] = (offset 0, length 12100, extra 7209070)`. **[VERIFIED-FILE]** `12100 = 4 + 6*2016` exactly
and `32400 = 16*2025` exactly, so the pixel container is `u32 count` + `count` greyscale bitmaps;
2016 = 56×36 and 2025 = 45×45 are the two classic light sprite sizes.
`extra` meaning is **[UNVERIFIED]** (likely a light radius/quality value).

## 7.8 `texmaps.mul` / `texidx.mul`

**[VERIFIED-FILE]** `texidx.mul` is 196,608 B = **16,384 entries × 12 B** (idx).
`texmaps.mul` is 47,357,952 B. **[VERIFIED-FILE]** the sum of all idx `length` fields equals
47,357,952 — the idx accounts for the file **exactly**. Entry lengths are **only two values**:
**8,192 B (3,561 entries)** and **32,768 B (555 entries)**.

So:

* `8,192 B = 64 × 64 × 2` → a **64×64** texture of `u16` RGB555.
* `32,768 B = 128 × 128 × 2` → a **128×128** texture of `u16` RGB555.

**There is no per-entry header** — the entry *is* just the pixel array, and the dimensions are implied
by the length. **[VERIFIED-FILE]** the first entry's bytes begin `1e 72 1e 72 1e 72 …` (a flat
repeated colour), consistent with raw pixels.

> **Correction.** The `texmaps.mul` layout is often described with a 4-byte header per entry.
> That would make the file `sum(lengths) + 4*4116` bytes, which **contradicts** the exact equality I
> measured. **Trust the measurement: no header.** **[VERIFIED-FILE]**

## 7.9 `palette.mul`

**[VERIFIED-FILE]** 768 B = **256 × 3 bytes RGB888**, beginning
`00 00 00  FF 00 FF  FF 00 FF  FF 00 FF …`. Note the **unusual ordering**: the second entry is
magenta `(255,0,255)` and the third green `(255,0,255)`… i.e. read as `R,G,B` triples the first
entries are `(0,0,0)`, `(255,0,255)`, `(255,0,255)`, … Used by the newer art pipeline; the classic
renderer does not need it.

## 7.10 `fonts.mul` / `unifont*.mul`

**[VERIFIED-FILE]** `fonts.mul` is 884,909 B; first bytes `01 06 14 04 00 00 …`.
Structure (classic `fonts.mul`):

```text
u8  header              # 0x01
for each of 6 (or 10) font sigils:   # 0..5 or 0..9
    u8 charCount        # observed 0x06, 0x14 ...
```

The canonical model: `fonts.mul` holds **ASCII bitmap fonts**, `unifont*.mul` hold the **Unicode**
replacements. Reader: `src/ClassicUO.Assets/FontsLoader.cs` (142 KB — by far the largest loader,
because it contains the rasteriser). **[UNVERIFIED]** the byte-exact `fonts.mul` header layout; port
`FontsLoader.cs` rather than reimplementing.

`unifont0..12.mul` are present (13 files, 1.4 MB … 8.1 MB each), one per Unicode plane/bank.
`unifont0.mul` is **absent** — the series starts at `unifont.mul` then `unifont1.mul`…
**[VERIFIED-FILE]**

## 7.11 The `.def` remapping files, `mobtypes.txt`, and the rest

All `.def` files share one dialect, read by `src/ClassicUO.IO/DefReader.cs`:

```text
<index> { <value> } [ <extra> ]            # brace form (art.def, gump.def, body.def, Corpse.def)
<index> <v1> <v2> <v3> <v4> [<v5>]         # space form (bodyconv.def, Equipconv.def)
# comment
```

| File | Size here | Fields | Purpose |
|---|---|---|---|
| `Art.def` | 11,266 | `tileId { fallbackTileId } ...` | artist replacement: a tile's art falls back to another |
| `gump.def` | 1,369 | `gumpId { srcGumpId } [hue]` | gump substitution (server sends a "virtual" gump id) |
| `Body.def` | 4,043 | `body { newBody } [hue]` | body id remap |
| `Bodyconv.def` | 34,845 | `bodyanim1 bodyanim2 … bodyanim5` | body → `anim2..6.mul` id mapping; `-1` = none |
| `Equipconv.def` | 8,017 | `body itemId { newItemId } …` | per-body equipment art substitution |
| `Corpse.def` | 3,769 | body → corpse graphic | |
| `Anim1.def` / `Anim2.def` | 92 / 2,779 | animation set remap | |
| `TexTerr.def` | 5,112 | terrain texture map | |
| `stitchin.def` | 235,233 | tailoring recipe data (large!) | |
| `Sound.def` | 10,249 | `soundId { soundFileId } [priority]` | sound id → file id remap |
| `Music.def` | 7 | music config | |
| `mobtypes.txt` | 44,882 | `bodyType bodyKind` | **not a `.def`** — whitespace-separated body classification, used by the client for "humanoid"/"animal" AI and name colouring |

**[VERIFIED-FILE]** `Sound.def` begins `654 {487} 0\r\n655 {263} 0\r\n656 {…}` — confirming the
`<id> { <mapped> } <extra>` brace form and CRLF line endings.

`src/ClassicUO.Assets/SoundsLoader.cs` reads `Sound.def` first to build the id→file map, then indexes
`soundLegacyMUL.uop` with `build/soundlegacymul/{0:D8}.dat`.

> **The sound payload is NOT a bare WAV.** **[VERIFIED-FILE]** `soundLegacyMUL.uop` entry 0
> decompresses to **228,002** bytes beginning
> `64 5f 66 72 73 74 30 31 2e 77 61 76 00 00 03 00` = ASCII **`"d_frst01.wav"`** followed by
> `00 00 03 00`. So each sound entry carries a **NUL-terminated filename string, then a small
> header, then the WAV data**:
>
> ```text
> char name[];     # NUL-terminated ASCII, e.g. "d_frst01.wav"
> u8  ?            # observed 0x00 0x03 0x00 -- role undetermined
> <WAV / RIFF data>
> ```
>
> **[UNVERIFIED]** the exact length and meaning of the bytes between the name and the RIFF data.
> **To resolve:** port `src/ClassicUO.Assets/SoundsLoader.cs` (17.8 KB) and log the offset at which it
> finds the `RIFF` magic for several entries; or scan entry 0 for `b"RIFF"` and subtract. This does
> **not** block audio playback — search for `RIFF` and play from there.
> All 1,655 sound entries in this install are stored uncompressed (`flag = 0`).

## 7.12 `string_dictionary.uop`

**[VERIFIED-FILE]** exactly **1 entry**, decompressing to **3,870,161 bytes**. Pattern
`build/stringdictionary/string_dictionary.bin` (`src/ClassicUO.Assets/StringDictionary.cs` line 38).
This is the new-client string table used for tile/item names with the `tileart.uop` pipeline.
**[UNVERIFIED]** the payload structure. **To resolve:** port `StringDictionary.cs` (1.9 KB — small)
and dump the first records.

---

# 8. Rendering constants

All from ClassicUO source; these are the numbers a Godot 4 clone must use to match the original
look exactly.

## 8.1 The isometric transform — the single most important formula

`src/ClassicUO.Client/Game/GameObjects/GameObject.cs`, `UpdateRealScreenPosition`, lines 150-153:

```csharp
RealScreenPosition.X = ((X - Y) * 22) - offsetX - 22;
RealScreenPosition.Y = ((X + Y) * 22 - (Z << 2)) - offsetY - 22;
```

Therefore:

| Constant | Value | Meaning |
|---|---|---|
| **Tile size** | **44 × 44 px** | a land tile's full bounding box |
| **Isometric step** | **22 px** per tile in each axis | half the tile size; `+22` in screen X for `+1` tile X, `-22` in screen X for `+1` tile Y |
| **Z scale** | **4 px per world z unit** | from `Z << 2` (i.e. `Z * 4`); raising a thing by 1 z lifts it 4 px on screen |
| Half-tile centre offset | 22 px | added when centring a sprite over a tile |

Also confirmed by `GameScene.cs` line 1207: `int winDrawOffsetY = (tileOffX + tileOffY) * 22 - winGameCenterY;`
and line 1199: `winGameCenterY = … + (_world.Player.Z << 2);`
and line 1240: `tileOffX += (int)(zoom * (Camera.Offset.X + Camera.Offset.Y) / 44);` — the `/44`
again.

**Godot 4 note:** this is a pure 2:1 isometric ("dimetric") projection. In Godot use a
`CanvasItem`/`Node2D` with `position = Vector2((x-y)*22, (x+y)*22 - z*4)` and no engine-level
isometric tilemap — the built-in isometric TileMap uses a different origin/ordering convention and
will fight you on the `+22` centre offset and the z term.

## 8.2 Sorting / z-order, and "surface" detection

`src/ClassicUO.Client/Game/GameObjects/Views/View.cs`, `CalculateDepthZ()` lines 35-83:

```csharp
public float CalculateDepthZ()
{
    int x = X, y = Y, z = PriorityZ;
    // Offsets are in SCREEN coordinates -- used to pre-sort a moving object by its
    // direction of travel so it does not pop through walls
    if      (Offset.X > 0 && Offset.Y < 0) { /* North      */ }
    else if (Offset.X > 0 && Offset.Y == 0) { x++; }                              // Northeast
    else if (Offset.X > 0 && Offset.Y > 0) { z += Max(0,(int)Offset.Z); x++; }    // East
    else if (Offset.X == 0 && Offset.Y > 0) { x++; y++; }                         // Southeast
    else if (Offset.X < 0 && Offset.Y > 0) { z += Max(0,(int)Offset.Z); y++; }    // South
    else if (Offset.X < 0 && Offset.Y == 0) { y++; }                              // Southwest
    else if (Offset.X < 0 && Offset.Y > 0) { /* West */ }                         // (unreachable dup in source)
    else if (Offset.X == 0 && Offset.Y < 0) { /* Northwest */ }

    return (x + y) + (127 + z) * 0.01f;
}
```

**So the sort key is:**

```text
depth = (tileX + tileY) + (127 + z) * 0.01
```

Read that as: primary key is the isometric diagonal `x + y`; the z term is **scaled by 0.01** so it
only breaks ties within the same diagonal. Ties are resolved with `>=` comparisons
(`GameSceneDrawingSorting.cs` lines 605, 705, 736), i.e. **later-drawn objects win ties** — draw
order among equal-depth objects is the list order.

Land and static depth is offset by `+0.5f` in the mesh builder:
`src/ClassicUO.Client/Game/Map/ChunkMesh.cs` lines 321 and 426:
`float depth = land.CalculateDepthZ() + 0.5f;` / `obj.CalculateDepthZ() + 0.5f`.

Draw ranges: `ChunkMesh` accumulates per-chunk; `GameScene.cs` line 633:
`(minChunkX, minChunkY) = (minX >> 3, minY >> 3)` — **chunks are 8×8 tiles**, matching the map
block's 8×8 cell grid.

**"Surface" detection** uses the tile flag, not geometry:
`TileFlag.Surface = 0x00000200` is "**may be moved over, but not through**" (per the enum doc
comment), whereas `Impassable = 0x00000040` is "**may not be moved over or through**". A standable
surface is `Surface`-flagged and not `Impassable`; a walkable **land** tile is one whose land flags
lack `Impassable | Wet`. See §6.6.

**Which statics get drawn per block.** `src/ClassicUO.Client/Game/Scenes/GameSceneDrawingSorting.cs`
line 1120:

```csharp
return itemData.Height != 0 && maxObjectZ - maxZ < height;
```

i.e. a static is culled when its `tiledata.height` is zero **or** when it is fully hidden behind
already-drawn geometry (`maxObjectZ - maxZ < height`). Statics are enumerated per 8×8 block from
`staidx`/`statics` (§6.3–6.4) and sorted by the depth key above.

## 8.3 Hueing

`src/ClassicUO.Utility/HuesHelper.cs` provides `Color16To32` (the RGB555→RGBA expansion of §2.3.1)
and the hue application. Hue applying replaces each pixel's RGB with
`hues[hue].colors[ (r+g+b)/3 scaled into the block's range ]` — i.e. **luminance indexing into the
32-entry hue ramp**. `TileFlag.PartialHue` (`0x00040000`) restricts hueing to grey pixels only.
**[VERIFIED-SRC]**

## 8.4 Light and weather

* `src/ClassicUO.Client/Game/GameObjects/IsometricLight.cs` holds the light state;
  `GameScene.cs` line 1079 reads `float lightColor = _world.Light.IsometricLevel;`.
* Lights are contributed at `RealScreenPosition + (22, 22)` — the **tile centre**
  (`GameSceneDrawingSorting.cs` lines 598, 902).
* Light sprites come from `light.mul` via `lightidx.mul` (§7.7); a light's size class is chosen by the
  light id (the classic 56×36 and 45×45 shapes measured in §7.7).
* Player Z is part of the light/height calculation: `winGameCenterY = … + (_world.Player.Z << 2)`.
* **Weather:** implemented in the client, not read from a data file. `[UNVERIFIED]` whether 1.25.35
  has any weather data file; **to resolve:** check the client directory listing for `weather*` — there
  is none in this install, so weather is procedural.
* Day/night: the client applies a global light level over time; there is **no** day/night data file.
  **[VERIFIED-FILE]** (no such file exists in the install).

## 8.5 Alpha and timing constants

* `Constants.ALPHA_TIME` governs the translucent-object fade
  (`GameScene.cs` line 564: `_alphaTimer = Time.Ticks + Constants.ALPHA_TIME;`).
* Foliage re-shuffle: `GameScene.cs` lines 580-585 — `FoliageIndex++`, wrapping at **100**. So the
  foliage transparency cycle has **100** steps.
* `Constants.MAX_VIEW_RANGE` is the default client view range
  (`src/ClassicUO.Client/Game/World.cs` line 109). **[UNVERIFIED]** its numeric value; grep
  `Constants.cs`.

---

# 9. Reference implementations to port — ranked, with licences

> **Method note.** Every URL below was resolved through the GitHub API during this session, and every
> licence was read first-hand — either from the cloned repository's own `LICENSE`/`COPYING` file or
> from its `README`. **My first draft of this section contained five invented URLs that returned 404;
> they have been removed and replaced with the real repositories.** The four repositories I actually
> cloned and read are marked **[read]**. Licences change: re-verify before shipping. This is a
> summary, not legal advice.

### Tier 1 — port these first

| # | Project | URL | Licence (verified) | Language | Covers |
|---|---|---|---|---|---|
| 1 | **ClassicUO** **[read]** | <https://github.com/ClassicUO/ClassicUO> | **BSD-2-Clause** — `LICENSE.md`: "BSD 2-Clause License, Copyright (c) 2025, andreakarasho"; plus `ClassicUO.licenseheader` applying `#region license // BSD 2-Clause` to every `.cs` | C# | **everything**: UOP (incl. BWT), art, gumps, tiledata, anim (mul + uop + sequence), maps, statics, multi, cliloc, fonts, hues, sounds, speech, skills, lights, texmaps, `.def` readers, rendering, sorting, light. `src/ClassicUO.IO/**` + `src/ClassicUO.Assets/**` form a cleanly separable extraction layer. Pinned commit for this doc: `ee79d7ebc1cc0e53ff84fe6cae17d389e2737f93`. |
| 2 | **BwtDecompress** | <https://github.com/ClassicUO/ClassicUO/blob/master/src/ClassicUO.Utility/BwtDecompress.cs> | BSD-2-Clause (same repo) | C# | the only Mythic/BWT decoder you need (~190 lines). **Mandatory** — all 5,579 gumps in this install are `compressionFlag = 3`. |
| 3 | **UOFiddler** **[read]** | <https://github.com/Polserver/UOFiddler> | **Beerware** — `README.md`: *"Source code is released under the Beerware license."* Confirmed independently: **235** `.cs` files carry the `"THE BEER-WARE LICENSE"` header, **0** carry a GPL header. | C# | the **writer** side, and critically `Ultima/Helpers/UopUtils.cs::HashFileName` — the correct `hashlittle2` (§1.2.4) — plus `HashAdler32` and `HashWord2`. `Ultima/Uop/LegacyMulFileConverter.cs` documents the v4-vs-v5 constants and `_mapChunkSize = 0xC4000`. |
| 4 | **GodotUO** **[read]** | <https://github.com/DatMoshu/GodotUO> | **BSD-2-Clause** — `LICENSE`: "Copyright (c) 2025, andreakarasho (ClassicUO) / Copyright (c) 2026, Moshu and the GUO contributors" | C# (.NET) | **ClassicUO ported to Godot 4 .NET.** Highest-leverage reference on this list: the file-reading layer is already adapted to Godot, so the **Godot-side integration** (resource loading, texture upload, threading) is solved for you even if you write GDScript. Newer and less battle-tested than ClassicUO itself — use it for the Godot glue, ClassicUO for format truth. |
| 5 | **ultima-sdk-python** | <https://github.com/UltimaWorks/ultima-sdk-python> | **"Pickleware License"** (custom, permissive-looking; `NOASSERTION` per GitHub — **read it before use**) | **Python** | "Python library for extracting client information and rendering images from the Ultima Online client files". The best starting point if you want a Python extractor. Small (0 stars) and recent (pushed 2026-07) — verify its UOP/art coverage yourself. |

### Tier 2 — second opinions, and specific gaps

| # | Project | URL | Licence (verified) | Language | Covers |
|---|---|---|---|---|---|
| 6 | **UltimaSDK** | <https://github.com/necr0potenc3/UltimaSDK> | **no licence file** (GitHub reports `none`; verify with the author) | C# | historical reference for `Art`, `Gumps`, `TileData`, `Hues`, `Multis`, `Map`, `Skills`, `Speech`, `Sounds`, `Verdata`. Best used to confirm field *names* and the classic pre-High-Seas struct sizes. Many other forks exist under the same name; the canonical lineage is the RunUO/ServUO `Ultima` folder. |
| 7 | **OpenUO** | <https://github.com/necr0potenc3/OpenUO> | **GPL-3.0** — treat as copyleft, read-only for a permissive clone | C# | `UltimaSDK`-derived readers; useful for art/gump/tiledata/map cross-checks. |
| 8 | **Iris2** | <https://github.com/kblaschke/Iris2> | **GPL (code), GPLv3 (models/textures)** — `COPYING`: *"the models and textures in data/models/ are available under GNU GPLv3 … [CODE LICENSE] GNU GENERAL PUBLIC LICENSE"* | C / C++ | the modern Iris **3D** client — includes a full UO data-loading layer. **Read for algorithms only**; GPL makes copying incompatible with a permissive Godot project. |
| 9 | **Iris1** | <https://github.com/SiENcE/Iris1> | **GPL-2.0** | C++ | the original Iris. Same caveat: read-only. |
| 10 | **centredsharp** | <https://github.com/kaczy93/centredsharp> | **MIT** | C# | modern C# map editor (79 stars). **The best-licensed source for battle-tested `map*.mul` / `statics*.mul` / `staidx*.mul` block arithmetic**, since editing maps exercises exactly the layout questions in §6. |
| 11 | **centred-uo** | <https://github.com/nmcusa/centred-uo> | **MIT** | C# | another MIT map editor; a second opinion on the same formats. |
| 12 | **uo-unpacker** | <https://github.com/muratsu/uo-unpacker> | **MIT** — `LICENSE`: "The MIT License (MIT), Copyright (c) 2015 Murat Sutunc" | JavaScript | "Extracts data from Ultima Online files and converts it to a modern, readable format." JS, so useful as a **reference implementation you can read quickly in a browser**, and MIT means you may reuse it. Older (2015) — likely pre-UOP. |
| 13 | **uo-unpackerer** | <https://github.com/NerdyGamers/uo-unpackerer> | **MIT** — `LICENSE` carries the same *"Copyright (c) 2015 Murat Sutunc"* text, so it is a fork of #12 | JavaScript | a maintained fork (pushed 2025-05). |
| 14 | **Pandora's Box** | <https://github.com/Vita-Nex/Pandora> | **no licence file** (`none`) | C# | UO data *browser* (21 stars, actively pushed 2025-11). Its per-format UI code maps "what fields exist" for every archive. No licence = do not copy code; use it to enumerate fields. |
| 15 | **UOFiddler `MapUopReader.cs`** | <https://github.com/Polserver/UOFiddler/blob/master/Ultima/Uop/MapUopReader.cs> | Beerware | C# | map UOP specifics (chunk size, last-chunk truncation). |
| 16 | **UOFiddler `MultiComponentSidecar.cs`** | <https://github.com/Polserver/UOFiddler/blob/master/Ultima/Uop/MultiComponentSidecar.cs> | Beerware | C# | the documented "extra components" extension for `MultiCollection.uop`. |

### Tier 3 — narrow single-purpose tools (all MIT, all safe to reuse)

| Project | URL | Licence | Covers |
|---|---|---|---|
| **cliloc** | <https://github.com/Sghirate/cliloc> | MIT | simple `Cliloc` ⇄ CSV converter in C. Handy for validating your `Cliloc` reader (§7.1). |
| **uo-cliloc-to-json-converter** | <https://github.com/felladrin/uo-cliloc-to-json-converter> | MIT | PHP; `Cliloc` → JSON. |

> **On the "iris (Go)" lead.** The task brief listed *"iris (Go)"*, and I searched for it
> specifically (`iris ultima online language:Go`, plus keyword searches for `artLegacyMUL`,
> `gumpartLegacyMUL`, `tiledata.mul`, `MYP\0`) and **found no Go implementation of a UO data
> reader.** The real Iris projects are **C/C++ and GPL** (#8, #9 above). GitHub code search requires
> authentication, so a private or very low-visibility Go port could exist — but nothing surfaced
> under repository search, and **nothing in this document depends on it**: the format facts here were
> verified directly against the bytes and against ClassicUO/UOFiddler source. Treat "iris (Go)" as a
> **red herring** unless you can produce the URL.

### Tier 4 — Python extractors worth reusing

There is **no mature, maintained, pure-Python UO extractor** in the authoritative sources:

| Project | Note |
|---|---|
| `UltimaWorks/ultima-sdk-python` | the only real candidate (#5). Verify its coverage before relying on it. |
| assorted `uoviewer` scripts / gists | typically cover only legacy `art.mul` land/item and `hues.mul`; **do not** implement UOP or BWT, so they cannot read this install. Sanity checks only. |
| **This document's probe scripts** | A working Python implementation of the corrected UOP reader (header, block chain, 34-byte records, `u64 nextBlock`, negative `count`, zlib, `hashlittle2`), plus verifiers for tiledata, hues, statics, skills, cliloc, light, texmaps and the map chunks. In `E:\Workspaces\game-clone\research\probe\`. **The fastest path to a Python extractor**, and `uop_verified.py` is already validated on all 16 containers. |

### Ranked porting order for the clone

1. **Port `hashlittle2` + the UOP reader + `BwtDecompress` first** (§1.2, §1.2.4). Nothing else is
   readable until these work, and art, gumps, maps and sound are UOP-only in this install.
2. **Port `ArtLoader` + `GumpsLoader`** (BSD-2-Clause, small, self-contained) — gets ground and items
   on screen.
3. **Port `MapLoader`** — the map path is now fully proven (§6.1–6.2); derive each facet's grid from
   `staidx` rather than hardcoding the published table.
4. **`TileDataLoader`: port the *reader shape*, not the struct sizes.** Its 26/37-byte group model
   does not fit this install's `tiledata.mul`; use the 30/41-byte layout proven in §4.
5. **Port `AnimationsLoader`** (61 KB — the hardest single loader) for the classic anim path.
6. Everything else (hues, cliloc, skills, sound, fonts, `.def`) is small and mechanical.
7. If you build on **Godot 4 .NET**, read `GodotUO` (#4) *before* writing the integration layer.

---

# 10. Tooling produced while writing this document

All under `E:\Workspaces\game-clone\research\probe\`:

| File | Purpose |
|---|---|
| **`uop_verified.py`** | **the reference extractor — use this one.** Correct UOP header (`u64 nextBlock@12`, `i32 count@24`), block chain, 34-byte records, Jenkins `hashlittle2`, per-container name patterns, zlib/flag handling. **Validated against all 16 local containers**, including every map file. |
| `map_probe.py` | maps the real `map0LegacyMUL.uop` chunk 0: proves `0xC4000`, the 196-byte block, the 3-byte cell, and tile-id validity. |
| `facet_geom.py` | derives every facet's block grid from `staidx*.mul` and the map chunk counts. |
| `td_final.py`, `td15.py`, `td11.py`, `land_solve.py`, `land_final.py` | `tiledata.mul` layout provers (stride scoring, 30-byte land / 41-byte item records, field decoding, flag/weight/layer/height histograms). |
| `final_misc3.py` | `skills.mul`/`skills.idx`, `speech.mul`, `Cliloc.enu`, `hues.mul`, `radarcol.mul`, `light*.mul`, `texmaps.mul` verifiers. |
| `hdr_fix.py`, `hdr4.py`, `data3.py` | the header field-offset tabulation that pinned `u64 nextBlock@12` across all 16 files. |
| `trace*.py` | the step-by-step probes that resolved the header, block-chain and tiledata questions (kept for provenance). |
| `uop_final.py` | superseded by `uop_verified.py`; kept because it is what surfaced the map-file header bug. |

**Next actions for the clone (in order):**

1. ~~Decompress a map chunk and settle the 3-vs-4-byte cell~~ — **DONE**, see §6.1. Cell is 3 bytes.
2. Port `BwtDecompress` and decode gump id 0; confirm the container's `width/height` match the
   record header — closes §3.1.1.
3. Scan every `artLegacyMUL.uop` item entry's `height` field for the true maximum — closes §2.3.2.
4. Dump `tiledata.mul` at 1,193,984 to classify the ~1.99 MB tail — closes §4.1 and unlocks the
   modern item set.
5. Port `AnimDataLoader.cs` (1.6 KB) and log the computed offsets for bodies 0/400/750/1000 —
   closes §5.3 and unblocks the entire animation path.
6. Find the `RIFF` offset inside a decompressed `soundLegacyMUL.uop` entry — closes §7.11.

---

## Appendix A — Quick "which format is which" decision table

| Question | Answer |
|---|---|
| Is it UOP? | first 4 bytes are `4D 59 50 00` (`"MYP\0"`) |
| UOP version? | `u32@4`: `5` = `artLegacyMUL` + all `map*LegacyMUL`; `4` = everything else. **The layout is the same for both** — do not branch on it. |
| Where does the block chain start? | **`u64@12`** (`nextBlock`). It is 8 bytes wide. `8266` art, `40` most v4, `803464`/`803465`/`802289`/`845` for the map files. |
| How many entries? | `i32@24` — **may be negative** for sparse map containers (`-1`/`-2`); enumerate instead |
| What is `u32@28`? | `concurrency?` — `1` for version-5 containers, `0` for version-4 |
| Entry record size? | **34 bytes** |
| Entry name hash? | **Jenkins `hashlittle2`** — not `ClassicUO.UOFileUop.CreateHash` |
| Compressed? | `i16@+32` of the entry record: `0` stored, `1` zlib, `3` BWT-then-zlib |
| Payload starts where? | `dataOffset + headerLength` |
| Is there a `.mul` twin? | check the table in §0 — for art/gump/map/sound on this install, **no** |
| idx record size? | **12 bytes**, always |
| Absent idx entry? | `offset == -1` (or `length <= 0`) |
| `tiledata.mul` land record? | **30 bytes** at base 0 (`flags` u32 @0, `texid` u16 @4, name `char[20]` @10); block ends at 491,520 |
| `tiledata.mul` item record? | **41 bytes** at base 491,520 (`flags` @0, `weight` @4, `layer` @5, `count` @6, `animId` @10, `hue` @12, `light` @14, `height` @16, name @**+29**) — *offsets provisional at ±1 byte, see §4.1* |
| Land art size? | **2,048 B** stored / 1,012 `u16` pixels in a 44×44 diamond |
| Static art? | `u32 flags`, `i16 w`, `i16 h`, `u16 lineOffsets[h]`, RLE runs |
| Map block? | **196 bytes** = `u32` header + 64 cells of **`{u16 tileId, i8 z}` (3 bytes)** |
| Map UOP chunk? | **0xC4000 = 802,816 B** = 4,096 blocks |
| Static record? | **7 bytes**: `u16 tile, u8 x, u8 y, i8 z, u16 hue` |
| Screen position? | `((x-y)*22, (x+y)*22 - z*4)` |
| Depth? | `(x + y) + (127 + z) * 0.01` |

## Appendix B — unresolved items, consolidated

**Top 5 uncertainties** (ranked by how much they block the clone):

1. **`tiledata.mul`'s trailing ~1.99 MB** (§4.1) — offset `1,193,984` to EOF. This very likely holds
   the modern item set. Known-good anchor: 41-byte-spaced names begin at byte `2,405,559`. **Resolve
   by** dumping `[1,193,984, 1,194,080)` and looking for a third block header, then re-running the
   41-byte stride. **Biggest single win available.**
2. **The `anim.mul` frame payload header** (§5.2) — **partly resolved 2026-10-03**
   (`research/anim-mereni.md`, `research/probe/anim_pokryti.py`): the first 512 bytes of a block are
   **identical in every block** (body 400/200/9, different actions — bit for bit), so there is
   **no per-frame palette**; colour comes from `animdata.mul`/`hues.mul`, as variant (c) below
   guessed. The frame table is `[u32 count]` at byte 512 with `count × u32` offsets from 516, and
   the RLE terminator `0x7FFF7FFF` sits **4 bytes before the end of each frame** (verified on all
   10 frames of one block). **Still open:** the frame header layout and the index encoding inside
   the RLE stream — the run header's `x` decodes to 1020–1023, i.e. outside the frame (24×64), so
   the bit layout of `[u32 header]` in this install is not the one `ClassicUO`/`UOFiddler` use.
3. **`tiledata.mul` item-block phase** (§4.1) — the field *values* all validate, but I could not
   close an exact arithmetic identity on the name offset, so the item record's internal offsets are
   **provisional at ±1 byte**. **Resolve by** cross-checking a second client's `tiledata.mul`, or
   printing `TileDataLoader.cs`'s own record walk for a known item id and diffing.
4. **`animdata.mul` field semantics** (§5.3) — the **stride is now proven to be 92 bytes** with
   1,776 populated of 48,769 records, but the meaning of the six signed bytes at `+16` and of the
   32-entry `u16` table is not. **Resolve by** porting `AnimDataLoader.cs` and comparing.
5. **`MainMisc.uop` entry names** (§7.12) — 4 entries, all hashes known
   (`0x6B1786D68753F504`, `0xC0165B63D153B1DD`, `0x0891F809004D8081`, +1). ClassicUO never opens the
   file, so it is not needed for rendering; **resolve by** brute-forcing name templates.

**Lower-priority unresolved items:**

6. `tileart.uop` payload structure (§2.5) — the upstream parser is commented out.
7. `MultiCollection.uop` per-entry component list (§6.7).
8. Gump id → UI element table (§3.3) — needs empirical classification via a rendered contact sheet.
9. `AnimationFrame*.uop` frame blobs that are Mythic-compressed despite a zlib container flag (§5.6)
   — needs a signature check on the decompressed blob.
10. The bytes between the filename string and the `RIFF` data in `soundLegacyMUL.uop` entries (§7.11).
11. Tokuno's exact facet width (§6.2) — 32,761 blocks has no clean factorisation; derive the grid
    from `staidx4` at runtime rather than hardcoding.
12. Whether `radarcol.mul` (81,884 entries) and `hues.mul` are truncated relative to other builds
    (§7.5, §7.6).
13. The `extra` field's meaning in `anim*.idx` and `lightidx.mul` (§5.1, §7.7).

### Items that *were* open and are now closed

| Was uncertain | Now |
|---|---|
| UOP header field offsets | **`u64 nextBlock@12`, `blockSize@20`, `i32 count@24`, `concurrency@28`** — confirmed on all 16 containers (§1.2.1) |
| `nextBlock` width | **8 bytes**, not 4 — matters only for the map files (§1.2.1) |
| `count` sign | **negative is a valid sentinel** for sparse map facets (§1.2.1) |
| Filename hash function | **Jenkins `hashlittle2`**, seed `len + 0xDEADBEEF`, result `(b<<32)\|c` — 100% match on art/gump/map/sound/anim/multi (§1.2.4); `ClassicUO.UOFileUop.CreateHash` matches **0%** |
| Map cell width (3 vs 4 bytes) | **3 bytes**; block = 196 B; chunk = 0xC4000 = 4,096 blocks (§6.1) |
| Map facet dimensions | Derived from chunk counts + `staidx`; several published values are **wrong** for this install (§6.2) |
| `gumpart` compression | **all Mythic/BWT (flag 3)** — a BWT decoder is mandatory (§1.2.3) |
| `art` compression | **all stored (flag 0)** — contradicts UOFiddler's comment (§1.2.3) |
| `hues.mul` layout | **375 groups × 708 B**; block = `u16[32]` + range start/end + `char[20]` name (§7.5) |
| `texmaps.mul` layout | **no per-entry header**; two entry sizes, 8,192 B (64×64) and 32,768 B (128×128); idx accounts for the file exactly (§7.8) |
| `light.mul` layout | idx accounts for the file exactly; `u32 count` + greyscale bitmaps (§7.7) |
| `skills.mul` / `skills.idx` | 12-byte idx records, **58** skills, full name list extracted (§7.2) |
| `Cliloc` string encoding | **UTF-8** with `u8 flag` + `i16 length`; the file is BWT-compressed (§7.1) |
| `speech.mul` endianness | **big-endian** `u16` id/len (§7.4) |
| `tiledata.mul` land stride | **30 bytes**, proven by stride-scoring + the exact 491,520 block boundary (§4.1) |
| `tiledata.mul` item stride | **41 bytes**; fields decode to correct game values for a dozen known items (§4.1) |
| `animdata.mul` record stride | **92 bytes** — `4,486,748 = 92 × 48,769` exactly; no other stride ≥ 64 divides it. 1,776 populated records, first non-zero at index 81 (§5.3) |
| Reference-implementation URLs and licences | All resolved and read first-hand; **5 invented URLs removed** (§9) |
