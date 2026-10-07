# 3. Assety a data z instalace UO

> **Tenhle oddíl je o datech, ne o hře.** Všechna čísla a layouty v něm jsou
> buď **ověřené sondou** (uvedeno „ověřeno"), nebo označené jako **nevyřešené**
> s postupem, jak je vyřešit. Nic mezi tím: „myslím, že to tak je" je zakázané
> (viz `10-rizika-a-pasti.md`).

## 3.1 Licence a kde assety bydlí

| Pravidlo | Konkrétně |
|---|---|
| Instalace UO je **read-only zdroj** | `D:\Games\Electronic Arts\Ultima Online Classic` — nikdy se do ní nezapisuje |
| Extrahované assety **nejsou v gitu** | `assets/uo/**` a `assets/atlas/**` patří do `.gitignore` |
| V gitu je **nástroj, ne data** | `tools/uoextract/**`, `CREDITS.md`, a `assets/manifest.schema.json` |
| Hra bez assetů nesmí tiše lžít | běh bez `assets/uo/manifest.json` skončí jasnou hláškou „spusť `python tools/uoextract/extract.py`", ne prázdnou scénou |
| Hudba a zvuk | pro **veřejné** vydání použij CC0/CC-BY alternativy (`11-zdroje-a-data.md`); originální MP3 jen pro lokální build, s poznámkou v `CREDITS.md` |
| Nikdy | `client.exe`, `UO.exe`, DLL, patchery — nekopírovat, nespouštět, nepřebalovat |

Do `CREDITS.md` patří: cesta k instalaci, verze klienta (`Version.txt` =
`1.25.35`, ověřeno), SHA-256 vstupních souborů (viz §3.8) a datum extrakce.

## 3.2 Co v instalaci je (ověřeno sondou `research/probe_uo*.py`)

| Soubor | Velikost | Co to je | Stav |
|---|---|---|---|
| `artLegacyMUL.uop` | 149,1 MB | art předmětů a dlaždic (UOP/MYP0, verze 5) | magie ověřena, obsah ne |
| `gumpartLegacyMUL.uop` | 77,7 MB | gumpy (UI okna, paperdoll) (MYP0 verze 4) | totéž |
| `map0LegacyMUL.uop` … `map5LegacyMUL.uop` | 85,8 MB (map0) | facety 0–5 (land bloky) | hlavička ověřena; matematika bloků sedí (7168×4096 = 458 752 bloků × 196 B ≈ 85,8 MB) |
| `statics0.mul` + `staidx0.mul` | 19,4 MB + 5,25 MB | statické objekty facety 0 (index 12 B/blok) | index sedí (5 242 880 / 12 = 436 906 bloků) |
| `tiledata.mul` | 3 188 736 B | flagy, výšky, vrstvy, váhy, hodnoty, **jména** dlaždic a předmětů | **VYŘEŠENO** — 2 bloky se skupinovými hlavičkami, rezerva 0 B (§3.3.1) |
| `hues.mul` | 265 500 B | 3000 barevných sad | **OVĚŘENO** — 375 skupin × (4 B + 8 × 88 B); viz §3.2b |
| `anim.idx` + `anim.mul` | 1,79 MB + 194,9 MB | starší formát animací (148 810 slotů × 12 B) | struktura indexu ověřena |
| `anim2..anim6.mul` | 212 / 142 / 98 / 95 / 46 MB | animace pro další éry (LBR/AoS/AoW/Mondain) | přítomny |
| `AnimationFrame1..4,6.uop` + `AnimationSequence.uop` | 108 / 112 / 102 / 110 / 22 MB | **nový** formát animací (nahrazuje anim*.mul) | nevyřešeno, musí se rozhodnout zdroj |
| `animdata.mul` | 4,49 MB | tabulky framů a palet pro animace | přítomen |
| `animinfo.mul` | 4 000 B | info o animačních skupinách (ověřeno: první slova `04 02` = 0x0204) | přítomen |
| `texmaps.mul` + `texidx.mul` | 45,2 MB + 197 kB | textury terénu | přítomny |
| `multi.mul` + `multi.idx` | 995 kB + 102 kB | komponenty domů/lodí (8 480 slotů × 12 B) | přítomny |
| `radarcol.mul` | 163 768 B | barvy pro radar (81 884 × uint16) | ověřeno počtem |
| `light.mul` + `lightidx.mul` | 2,78 MB | úrovně světla terénu | přítomny |
| `Cliloc.enu` | 5 110 078 B | lokalizované texty (item properties, gump texty) | **VYŘEŠENO** — BWT komprese + UTF-8 záznamy (§3.3.2) |
| `skills.mul`, `skills.idx`, `skillgrp.mul` | 704 B, 3 072 B, 338 B | jména skillů a skupiny | **OVĚŘENO** (58 jmen + 6 skupin, viz §3.7) |
| `soundLegacyMUL.uop` + `sound.def` | 160,6 MB | zvuky (mapování id → soubor) | přítomny |
| `Music/Digital/*.mp3` + `Music/Digital/Config.txt` | 93 MP3 | hudba + konfigurace (region → skladba) | ověřeno počtem |
| `doors.txt`, `stairs.txt`, `teleprts.txt`, `misc.txt` | 2,4 / 1,8 / 0,3 / 6,8 kB | **chování**: dveře, schody, teleporty, stavební díly | **PŘEČTENO** — viz §3.7 |
| `body.def`, `Corpse.def`, `art.def`, `gump.def`, `Equipconv.def`, `Bodyconv.def`, `Anim1.def`, `Anim2.def` | 4 / 3,8 / 11,3 / 1,4 / 8 / 34,8 / 0,1 / 2,8 kB | přemapování těla/artu/gumpu, konverze výbavy | **PŘEČTENO** (formát je v komentáři souboru) |
| `mobtypes.txt` | 44,9 kB | typ animace a flagy pro každé tělo (`ID TYPE FLAGS`) | formát přečten |
| `Tilehelp.enu` | 33 kB | **originální nápověda k použití předmětů** („Double-click ore and target a forge to smelt…") | přečteno, je to zdroj pravdy pro §5.2 |
| `fonts.mul`, `unifont*.mul` | 0,88 MB + 6 souborů | bitmapové fonty klienta (bez české diakritiky!) | přítomny |

### 3.2b Společný rys této instalace: skupinové hlavičky (4 B)

Naměřeno na dvou nezávislých souborech — a je to **klíč k celému formátu**:
tato instalace skládá `.mul` soubory do **skupin**, kde každá skupina začíná
**4bajtovou hlavičkou** a teprve za ní jdou záznamy:

| soubor | skupina | záznam | celkem |
|---|---|---|---|
| `hues.mul` | 4 B + 8 × 88 B = **708 B** | 32 barev (u16) + start + end + 20B jméno | 375 skupin = **3000 sad** = 265 500 B |
| `tiledata.mul` land | 4 B + 32 × 30 B = **964 B** | `u64 flags` + `u16 texId` + 20B jméno | 512 skupin = **16 384 dlaždic** = 493 568 B |
| `tiledata.mul` item | 4 B + 32 × 41 B = **1316 B** | `u64 flags`+`u8 weight`+`u8 layer`+`i32 count`+`u16 animID`+`u16 hue`+`u16 light`+`u8 height`+20B jméno (na +21) | 2048 skupin = **65 536 předmětů** = 2 695 168 B |

Součty sedí na bajt: `493 568 + 2 695 168 = 3 188 736` = přesná velikost souboru.

**Dva nezávislé důkazy (oba změřené, ne převzaté):**
1. **Semantický test `hues.mul` (naměřeno mnou):** text v záznamu
   (`Hue (6->1080)`) musí sedět s číselnými poli `start`/`end`. Skupinový
   model: **1000 souhlasů, 0 nesouhlasů**. Plochý model: jen **47**.
   *(Nezávislá větev měřila plochý model a našla 47 shod z 2 629 pojmenovaných
   záznamů — tedy totéž číslo a stejný závěr „plochý model nesedí". Rozdíl je
   jen v tom, že ona po tom prohlásila pole za neuzavřená; skupinový model je
   uzavírá. 1000 přesných shod textu s čísly nemůže být náhoda.)*
2. **Mezery mezi jmény v `tiledata.mul`:** dominantní mezera je 41 B (29 472×),
   ale **988× se objeví 45 B** = 41 + 4. Podíl `45/(41+45) = 3,24 %`, což je
   přesně **1/32** — tedy jedna 4bajtová hlavička na každých 32 záznamů.
   (Model bez hlaviček předpovídá 0 %.)

**Třetí důkaz — všechny tři bloky proti nulovému modelu** (naměřeno mnou,
`research/probe_uo10.py` a `probe_uo11.py`; „hodně jmen" samo o sobě nic
neznamená, proto se to srovnává s náhodou):

| blok | správný (skupinový) model | plochý model | nulový model (náhoda) |
|---|---|---|---|
| `tiledata.mul` item | **13 113** | 694 | 786 |
| `tiledata.mul` land | **4 109** | 956 (stride 30) / 857 (stride 34) | 796 |
| `hues.mul` (semanticky) | **1000/1000 shod** | 47 | — |

> **Drobnost, která zůstává:** u land bloku sedí framing (4 B na 32 záznamů)
> i jména záznamů 1–3 (offsety 44, 74, 104 = `4 + r*30 + 10`), ale **jméno
> záznamu 0 vychází o 4 B jinde** (řetězec na offsetu 10 místo 14). Na herní
> logiku to nemá vliv (flagy i `texId` se čtou z jiných polí než jméno), ale
> granule `assets.tiledata` to má **dořešit a zapsat**, ne obcházet.

**Model bez hlaviček vypadá „skoro správně" a je špatný** — a to je poučení:
posune se o 4 bajty každých 32 (resp. 8) záznamů, takže část záznamů pořád
sedí a metrika vyjde „někde mezi". Přesně to mě přivedlo na špatnou stopu
(`docs/10` P5) a přesně proto se každý layout ověřuje **na celém souboru**,
ne na vzorku.

## 3.3 Dvě věci, které vypadaly neřešitelně (a jak se vyřešily)

### 3.3.1 `tiledata.mul` — VYŘEŠENO (dvě fáze: nevyřešeno → vyvrácené hypotézy → změřeno)

**Řešení (naměřeno a doloženo, `research/07`):** soubor jsou **dva bloky
s hlavičkami skupin a NULOVOU rezervou** — součet sedí na bajt přesně.

```text
LAND blok:  offset 4,        512 skupin x (u32 hlavička + 32 záznamů x 30 B) =   493 568 B
            záznam = [u64 flags][u16 texId][20 znaků jméno]
ITEM blok:  offset 493 568, 2048 skupin x (u32 hlavička + 32 záznamů x 41 B) = 2 695 168 B
            záznam = [u64 flags][u8 weight][u8 layer][i32 count][u16 animID]
                     [u16 hue][u16 light][u8 height][20 znaků jméno]   (jméno na +21)

493 568 + 2 695 168 = 3 188 736 = přesná velikost souboru (rezerva 0 B)
65 536 záznamů předmětů (2048 skupin, tj. 4x víc než klasických 0x4000)
```

**Důkaz, že to není jen „číslo, které vychází" — dva nezávislé testy:**

1. **Sémantika polí:** ze 1268 předmětů s flagem `Wearable` (0x00400000) mají
   **všechny** nenulovou vrstvu a **96,9 %** vrstvu uvnitř známého číselníku —
   a vrstvy sedí na jména:

| předmět (id) | vrstva | význam |
|---|---|---|
| `leather cap` (7609) | 6 | Helm |
| `gargoyle_leather_arm` (769) | 19 | Arms (weight 4, animID 585) |
| `gargoyle_leather_che` (771) | 13 | InnerTorso |
| `gargoyle_leather_leg` (773) | 4 | Pants |
| `backpack` (2482) | 21 | Backpack |
| `dagger` / `longsword` / `katana` | 1 | OneHanded (weights 1/7/6) |
| `anvil`, `forge`, `stone stairs` | 0 | nenositelné, weight 255 |

2. **Mřížka proti nulovému modelu** (naměřeno mnou, `research/probe_uo10.py`,
   aby se „hodně jmen" nepletlo s náhodou):

| model | čistých jmen ze 16 384 záznamů |
|---|---|
| skupinový (4 B hlavička + 32 × 41 B, base 493 568, jméno +21) | **13 113** |
| plochý (base 491 520, stride 41) | 694 |
| **nulový model** (16 384 náhodných offsetů ve stejném rozsahu) | **786** |

   Tedy: plochý model je **nerozlišitelný od náhody**, skupinový je 17× nad ní.

**Dvě hypotézy, které jsem předtím změřil a vyvrátil** (historie je poučná —
ukazuje, proč se má měřit, ne hádat):

| Hypotéza | Naměřeno | Verdikt |
|---|---|---|
| land 26 B + item 37 B, 512 skupin po 32 (klasický `TileDataLoader`) | 0x4000×37×2 = 1 212 416 ≠ 3 188 736 | **neplatí** |
| land 34 B (jméno +9), item 41 B od 557 056 (`research/05` §4) | čistých jmen: land **4,4 %**, item **6,5 %** | **vyvráceno měřením** |

**Proč všechny naivní modely selhaly:** blok předmětů má **2048 skupin (65 536
dlaždic)**, ne 512 — proto je soubor 4× větší, než model s 512 skupinami
předpovídá, a proto vycházely „skoro správné" offsety, které neseděly
o jednotky bajtů. Past s fází mřížky (`docs/10` P5) byla příznakem tohoto:
mezi skupinami je 4bajtová hlavička, takže fáze jmen se po každých 32
záznamech posune.

> **Poučení:** „číslo, které nějak vychází" (0x4000 × 34 = 557 056) **není**
> důkaz. Důkaz je **čistota dekódovaných jmen** a **součet délek bloků** —
> a ten tady sedí na **0 bajtů rezervy**.

### 3.3.1b Pozor: tato instalace NEMÁ klasická jména předmětů

Naměřeno: v `tiledata.mul` této instalace **nejsou** řetězce `leather gloves`,
`leather helm`, `black pearl`, `gold`, `plate chest` ani `bandage`. Je to
**moderní/přejmenovaná sada dlaždic** (místo nich jsou např.
`gargoyle_leather_arm`, `leather cap`, `backpack`).

**Co z toho plyne pro obsah (`docs/06`):**
1. **Nikdy nehardcoduj klasická jména ani tile id z paměti** — ani z wiki,
   ani z vlastní zkušenosti s UO. Jména se **hledají skenováním tiledata**
   (podle jména, vrstvy, flagu `Wearable`, animID) a do `data/items.json` jde
   to, co v datech **skutečně je**.
2. Když pro nějakou roli („těžká zbroj", „lektvar") není v datech jméno,
   vyber ji **podle vlastností** (vrstva + weight + animID + flagy), ne podle
   názvu — a zapiš, jak jsi ji vybral (`source: "tiledata-by-properties"`).
3. Když něco v datech není vůbec, je to **nález do `content-report.json`**,
   ne tichý přeskok.

### 3.3.2 `Cliloc.enu` — VYŘEŠENO: soubor je BWT-komprimovaný

První bajty jsou `0f 23 61 8e bb 83 08 03 90 0c 02 00 75 04 02 00 cf 0d 02 00 …`.
ClassicUO/ServUO layout `[int32 číslo][1 B flag][uint16 délka][UTF-16LE text]`
**nesedí** — skener zkoušející hlavičky 6 a 7 B nenašel v prvních 6000 B jediné
platné pole.

**Vyřešeno měřením + zdrojem (`research/05` §7.1): soubor je BWT-komprimovaný.**

```
if data[3] == 0x8E:  data = BwtDecompress(data)     # ClassicUO ClilocLoader.cs:158
u32 number_format    # ignorovat
u16 unknown          # ignorovat
loop until EOF:
    i32 number       # id kliloku
    u8  flag         # 0 = text, 1 = text s argumenty {0}
    i16 length       # délka v BAJTECH
    u8  text[length] # UTF-8  (NE UTF-16!)
```

**Proč to sedí:** můj vlastní průzkum naměřil **třetí bajt `0x8E`** — přesně
ten diskriminátor, který ClassicUO používá — takže „nesmyslná“ první čtyři
slova nejsou data, ale **hlavička BWT bloku**. To je odpověď na to, proč
klasický parse selhal.

**Přijímací kritérium pro granuli `assets.cliloc`:** po portu BWT dekomprese
vypiš 5 po sobě jdoucích záznamů (číslo + text) a najdi v souboru **anglický
text** (např. `iron ingot`). Když se to nepovede, čtení je špatné.

## 3.4 Světová data: mapa a statics

Mapa se **nepřekládá do JSON** (29 milionů dlaždic) a **nečte se z `.uop`
za běhu hry**. Extrakce vytvoří tři soubory:

| Soubor | Formát | Proč |
|---|---|---|
| `assets/uo/world/map0.land` | syrové bloky 196 B = `u32 hlavička` + **64 × 3 B** (`tile_id:u16`, `z:i8`) — **buňka je 3bajtová, ne 4bajtová** (ověřeno dekompresí bloku na přesných 0xC4000 B se všemi 262 144 tile id < 0x4000) | přesná kopie originální geometrie, čte se po blocích |
| `assets/uo/world/map0.statics.bin` + `.idx` | `.idx` = 12 B na blok (`offset:u32`, `length:u32`, `extra:u32`; nepoužitý blok má `offset` i `length` = 0xFFFFFFFF), `.bin` = záznamy **7 B = `[tile_id:u16][x:u8][y:u8][z:i8][hue:u16]`** (OPRAVENO 2026-10-02: dřív tu stálo `x:u16, y:u16`; souřadnice jsou **jeden bajt** a `0..7` v rámci bloku, na konci je navíc `hue`) | statiky se čtou po blocích, stejná matematika jako originál |
| `assets/uo/world/map0.meta.json` | `{width, height, blocks_x, blocks_y, block_size, land_tiles, versions, source_sha256}` | co je potřeba k načtení a k ověření |

**Matematika (musí být v testu, ne v hlavě):** blok `bx,by` obsahuje dlaždice
`x = bx*8 + i`, `y = by*8 + j`; **index bloku v `.land` je `bx * blocks_y + by`**
(x-major — OPRAVENO 2026-10-02, dřív tu stálo `by * blocks_x + bx`, což je
obráceně); `blocks_x = width / 8`, `blocks_y = height / 8`. Ověřeno: faceta 0 = 7168 × 4096 → 896 × 512 = 458 752
bloků; `statics0.mul` 19,4 MB při průměru ~6 B/blok je konzistentní.

**Zdroj mapy (rozpor R3 v §3.5.4):** `map0LegacyMUL.uop` má jen **113
nenulových záznamů** — což není „málo dat", ale **113 chunků po ~802 816 B**
(= 4 096 bloků × 196 B), tedy 462 848 bloků ≥ 458 752 potřebných. Chunk 0 se
dekomprimoval na **přesně 0xC4000** se všemi 262 144 tile id < 0x4000. Granule
to musí potvrdit na dalším chunku, ale jako pracovní model je to podložené.

**Přijímací kritérium extrakce mapy** (bez něj se svět nedá věřit):
1. Součet délek statics bloků == velikost `statics0.mul` (± 0), index se čte
   celý.
2. Pro Britain (kolem 1495 × 1630) obsahuje blok **statics** (budovy, ploty) —
   prázdný výsledek znamená špatný offset.
3. Dlaždice s vodou (tile id z `tiledata`, flag `Wet`/`Impassable`) tvoří
   souvislé plochy, ne šum — ověř na 5 náhodných vzorcích.
4. Vykreslený náhled (snímek) Britainu **vypadá jako město** — lidská kontrola
   `read_image`, ne jen čísla (§8, brána render).

## 3.5 Art, gumpy a animace

### 3.5.1 Co se extrahuje

| Sada | Zdroj | Výstup | Poznámka |
|---|---|---|---|
| Land art | `artLegacyMUL.uop`, id 0–0x3FFF | atlas `land_*.png` + manifest | 44×44, plný diamant |
| Item art | `artLegacyMUL.uop`, id 0x4000–0xFFFF (item id = art id) | atlas `items_*.png` + manifest | velikosti různé (od 1×1 po stovky px), nutné offsety zarovnání |
| Worn art (oblečené předměty) | animace pro `animation` hodnotu z tiledata | atlas `worn_*.png` | skládá se na tělo podle vrstvy |
| Gumpy | `gumpartLegacyMUL.uop` | atlas `gumps_*.png` + manifest | 16bit s alfou; známé rozsahy (paperdoll, batoh, vendor, craft) |
| Animace těl | `anim*.mul` **nebo** `AnimationFrame*.uop` (rozhodnout!) | atlas `anim_<body>_<action>_<dir>.png` + JSON s framy a časováním | `animdata.mul` dává počty framů a palety |
| Barvy | `hues.mul` (ověřeno) | `hues.json` (3000 sad × 32 barev + rozsah + jméno) | tónování za běhu z grayscale artu (index 0 = „použij hue") |

**Rozhodnutí o animacích — ROZHODNUTO MĚŘENÍM 2026-10-03 (O3), a je to jinak,
než dokument dřív doporučoval:**

Použij **oba zdroje**, ale **`anim*.mul` je ten povinný** (ne fallback):

| Zdroj | Těl s obsahem | Akcí | Co v něm je |
|---|---|---|---|
| `anim*.mul` + `anim*.idx` | **270** | 7 165 | monstra 1–199 (60), zvířata 200–399 (35), **lidé 400+ (175 těl × 35 akcí)** |
| `AnimationFrame1..4,6.uop` | **318** | 10 989 | nová těla 400+ (282), zvířata (30), monstra (4) |
| průnik | **2** (826, 990) | — | — |

Těla se **téměř nepotkávají**: hráč (tělo 400 muž, 401 žena) i oblečení
(404–410) mají v MUL 175 bloků (35 akcí × 5 směrů) a v UOP **nula** — bez
`anim.mul` se hráč nepohne. Naopak těla 130, 334, 666 (gargoyle) jsou **jen
v UOP**. Pravidlo tedy je: **blok v MUL → MUL, jinak UOP** (totéž dělá
ClassicUO přes `UseUopAnimation` a UOFiddler přes `IsUopBody`).

Měření i reprodukce: `research/anim-mereni.md`, `research/probe/anim_pokryti.py`.

Dvě věci, které z měření plynou a musí se respektovat při plánování:

1. **Pixely z `anim.mul` zatím extrahovat nelze.** Rozměry, počty framů,
   offsety a terminátory RLE jsou ověřené (tabulka framů na bajtu 512, terminátor
   4 B před koncem framu), ale tvar hlavičky a kódování indexů v RLE proudu
   rozluštěné nejsou — `x` z hlavičky běhu vychází mimo rozměr framu. Kdo na tom
   staví (`assets.atlas`, `render.anim`), staví na **otevřené otázce**.
2. **Prvních 512 B bloku je ve všech blocích stejných** (tělo 400/200/9 shodně
   bit po bitu) → pixely těl **nemají vlastní paletu**, barva jde z
   `animdata.mul`/`hues.mul`, jak uvádí `research/05-data-formats.md` §5.2.
   Varianta „paleta na začátku bloku" (UOFiddler, ServUO) v této instalaci nesedí.

Rozsah extrakce se i tak **zúží na těla, která obsah skutečně potřebuje**
(`data/monsters.json`, profese, mounti) — typicky ~120 těl × 5 akcí × 5 směrů
× ~8 framů.

### 3.5.2 Atlas a manifest

- Stránky atlasu **2048×2048**, bezztrátově (`PNG` nebo `WebP` lossless),
  plněné shelf-packem seřazeným podle výšky (méně plýtvání).
- `assets/uo/manifest.json` (jediný zdroj pravdy pro runtime):
  ```json
  {
    "version": 1,
    "source": { "install": "...", "client_version": "1.25.35",
                "sha256": { "tiledata.mul": "...", "hues.mul": "..." } },
    "pages": [ { "file": "atlas/items_0.png", "w": 2048, "h": 2048 } ],
    "art": { "1531": { "page": 0, "x": 12, "y": 40, "w": 44, "h": 31,
                       "ox": 22, "oy": 31 } },
    "gumps": { "60": { "page": 3, "x": 0, "y": 0, "w": 210, "h": 300 } },
    "anim": { "400": { "actions": { "walk": { "frames": 8, "delay_ms": 80,
                  "dirs": { "0": { "page": 1, "x": 0, "y": 0, "w": 44, "h": 44 } } } } } }
  }
  ```
- `ox, oy` = **offset zarovnání** (u UO artu se kreslí od „středu dole" podle
  rozměrů a výšky); bez nich budou předměty létat o desítky pixelů.
- **Hue varianty se negenerují dopředu** — dělá je až `render/hue_cache.gd`
  (`(art_id, hue)` → `ImageTexture`, LRU se stropem, viz §2.7).

### 3.5.3 Přijímací kritéria extraktoru (tvrdá)

1. **Obrázek, který něco znamená:** extrahuj 6 známých art ID (zbraň, zbroj,
   strom/rostlina, land dlaždice, mince, lektvar), ulož PNG a **podívej se na
   ně** (`read_image`). Musí to být poznat. Čísla nestačí — „nenulová alfa"
   projde i u šumu.
2. **Neshoda s tiledata:** art ID, které tiledata nezná, se do manifestu
   nedostane (a extraktor to vypíše).
3. **Offsety sedí:** postava (tělo 400, muž) položená na dlaždici musí stát
   **nohama na dlaždici** — ověř snímkem, ne výpočtem.
4. **Opakovatelnost:** dva běhy extrakce dají **shodné SHA-256** manifestu
   (žádné časové značky uvnitř, řazení klíčů deterministické).
5. **Vstupy jsou připnuté:** manifest obsahuje SHA-256 vstupních souborů;
   když se instalace změní, extraktor to ohlásí (jinak se tiše změní obsah hry).

### 3.5.4 Co je z extraktoru ověřené — a kde si dva zdroje odporují

Dvě nezávislé výzkumné větve měřily totéž a **ve čtyřech bodech se rozešly**.
Do zadání patří **obojí**, protože rozhodnout má až test v granuli — ne
důvěryhodnost zdroje.

**Ověřeno (tím se dá stavět):**

| Co | Výsledek |
|---|---|
| **Art z UOP** | **funguje a je vidět**: extrahované PNG se daly otevřít a **dlouhý meč je meč** (čepel, záštita, rukojeť), batoh je hnědý batoh UO, kovadlina je kovadlina, land dlaždice 3 je zelený trávník; land art je diamant 44×44 s **přesně 1012 pixely** |
| Statické objekty | `staidx0` 12 B/blok (458 752 bloků), `statics0` 7 B/záznam (20 386 415 / 7 = 2 912 345, zbytek 0); blok pro Britain (1495,1630) = 20 záznamů, x/y v 0..7 |
| `skills.mul` | 58 jmen (NUL-ukončená, s 1bajtovým flagem; **není** to pole pevných záznamů — stridy 7–25 se liší) |
| `tiledata.mul` — předměty | 65 536 předmětů, vrstvy sedí na jména (§3.3.1) |
| Statický art | index statického artu = **`tiledata_id + 0x4000`** (není roven `tiledata_id`) |

**Čtyři rozpory (a jak je rozhodnout — ne „podle delšího dokumentu"):**

| # | Co | Verze A | Verze B | Rozhodující test |
|---|---|---|---|---|
| R1 | Hash jména záznamu v UOP | **Jenkins `hashlittle2`** (seed `len + 0xDEADBEEF`), údajně 100 % z 43 760 | čtečka na `CreateHash` z ClassicUO našla **1 636 z 2 000** zkoušených indexů artu | implementuj **obě**, změř na 2 000 indexech, použij tu se **100 %**. Toto je **blokátor č. 1** celé extrakce |
| R2 | Komprese `gumpart` | celý **BWT** (nutný `BwtDecompress`) | `zlib.decompress` stačí (délka sedí na bajt, `eof=True`) | dekomprimuj **jeden známý gump** (batoh) a **podívej se na něj** (`read_image`); rozhoduje obrázek, ne vlajka |
| R3 | Kde je mapa | v `map0LegacyMUL.uop` „není úložiště bloků" (jen 113 nenulových záznamů) | chunk 0 se dekomprimuje na **přesně 0xC4000** = 802 816 B = 4 096 bloků, se **všemi** 262 144 tile id < 0x4000; 113 × 4 096 = 462 848 ≥ 458 752 potřebných | **chunková interpretace** (113 chunků × ~802 816 B) — sedí na počet bloků i na validitu id; potvrď na dalším chunku |
| R4 | `Cliloc.enu` | **BWT** + UTF-8 (3. bajt `0x8E` = diskriminátor) | „nečitelné, plánovat na tom nic" | **můj poměr:** třetí bajt souboru je **`0x8E`** — přesně ten diskriminátor. Tím je vysvětleno, proč klasické čtení i zlib selhaly. Dokud granule `assets.cliloc` neproběhne, **nesmí na klilocích stát žádná funkce** |

**Pravidlo pro agenta:** u R1–R4 nevybírej podle zdroje, ale **proveď
rozhodující test** a výsledek zapiš do `docs/` **i s číslem**. Když test nejde
provést, je to `UNVERIFIED` — a na neověřené věci se nestaví.

## 3.6 Textová a pravidlová data z instalace

Tohle je **zdroj pravdy pro chování**, ne kosmetika. Extrahuj do `data/`:

| Soubor | Co z něj je | Použití |
|---|---|---|
| `skills.mul` (ověřeno: 58 jmen) | jména a pořadí skillů | `data/skills.json` — id, jméno, pořadí v klientu |
| `skillgrp.mul` (6 skupin: Combat, Trade Skills, Magic, Wilderness, Thieving, Bard) | skupiny skillů | seskupení v UI skill listu |
| `doors.txt` (37 kategorií × 8 art ID + FeatureMask + jméno) | **dveře**: všech 8 artů je **zavřený stav** (8 směrů) a **otevřený = `art + 1`** — dřív tu stálo „zavřené/otevřené × 4 orientace" (oprava níže) | `sim/world/doors.gd`: `is_open`/`toggle` podle dvojice `(art, art+1)`, zvuk, průchodnost |
| `stairs.txt` (19 kategorií: Block, North/East/South/West, Squared1/2, Rounded1/2, Multi*) | **schody** | určení, které dlaždice jsou schody a jak se na nich mění `z` |
| `teleprts.txt` (kategorie teleportovacích dlaždic) | **teleporty** (alchymistické dlaždice, moongate) | průchod dlaždicí → teleport na cílové souřadnice |
| `misc.txt` (kategorie × 8 dílů + TID + jméno) | stavební díly (archways, walls) | mimo rozsah stavění, ale používá se pro rozpoznání „dílu" |
| `hues.mul` (ověřeno) | barvy | tónování, barvy oblečení, kůže, vlasů |
| `body.def`, `Corpse.def`, `art.def`, `gump.def` | `ORIG {NEW} HUE` | přemapování těla (muž/žena/duch), tělo mrtvoly, art a gump pro paperdoll |
| `Bodyconv.def` | `<Object> <LBR> <AoS> <AoW> <Mondain>` (monstra 0–199, zvířata 200–399, lidé 400+, max 2048) | které animace patří kterému tělu |
| `Equipconv.def` | `bodyType equipmentID convertToID gumpID hue` (gumpID 0 = +50000, −1 = +50000 z convertToID) | korekce vzhledu výbavy pro nelidská těla |
| `animdata.mul`, `animinfo.mul` | počty framů, časování, palety | přehrávání animací |
| `mobtypes.txt` | `ID TYPE FLAGS` (MONSTER/ANIMAL/HUMAN, flagy) | AI a animační skupina pro tělo |
| `sound.def` + `soundLegacyMUL.uop` | id zvuku → soubor | zvuky kroků, boje, výroby |
| `Music/Digital/Config.txt` | mapování region → skladba | hudba podle lokace |
| `Tilehelp.enu` | **originální help texty k použití předmětů** | kontrolní seznam interakcí v §5.2 — každá věta z téhle nápovědy musí mít v klonu protějšek |

**Příklad konkrétních dat (ověřeno čtením souborů):**

```
doors.txt      kategorie 4 = "Wood Door":      1721 1723 1717 1719 1725 1727 1729 1731
                                             otevřené téhož: 1722 1724 1718 1720 1726 1728 1730 1732 (= +1)
doors.txt      kategorie 11 = "Weathered Stone Secret Door": 808 810 804 806 812 814 816 818
stairs.txt     kategorie 0 = "Dark Wood": Block 1848, N 1849, E 1852, S 1851, W 1850,
                                            Squared 1856/1854, Rounded 1862/1861,
                                            Multi N/E/S/W 7600/7601/7602/7603
teleprts.txt   kategorie 0 = "Alchemical Tiles": 6173–6184 (F2–F7 a F10–F15)
body.def       11 {28} 1401     (tělo 11 se kreslí jako 28 s hue 1401)
Bodyconv.def   0–199 monstra, 200–399 zvířata, 400+ lidé, max index 2048
Anim1.def      13 {5} 0         (tělo 13 používá animační skupinu 5)
```

> **OPRAVA 2026-10-07 (8. session, měřeno):** v tabulce §3.6 dřív stálo u `doors.txt`
> „**zavřené/otevřené × 4 orientace**" a `sim/world/doors.gd` podle toho pároval
> `kus 1–4` (zavřené) s `kus 5–8` (otevřené). **Naměřeno nad všemi 230 arty:**
> `doors.txt` uvádí **jen zavřené** arty (všech 230 má `Impassable`, 0 průchozích)
> a otevřený je **`art + 1`** — `art + 1` existuje u všech 230 a **ani jednou** není
> sám v `doors.txt` (0 z 230); `tiledata` je u 8 párů jmenuje „wooden door closed"
> / „wooden door opened" a **ani jeden pár obráceně**. Parita ani `layer` kritériem
> nejsou (120 artů lichých / 110 sudých, `layer` se u 39 z 230 párů liší), takže
> „otevřeno = sudý art" by u 16 kategorií (všechny kusy sudé) označilo **každý
> zavřený art za otevřený**. Důkazy a postup:
> hlavička `sim/world/doors.gd`, skripty `_analyza/dvere-konvence.py`
> a `_analyza/dvere-jmena.py`.

## 3.7 Nástroj `tools/uoextract/` — návrh

Jazyk **Python 3.12** (na stanici je; Pillow + numpy stačí). Struktura:

```
tools/uoextract/
├─ extract.py           # CLI: --install <cesta> --out assets/uo [--only map,art,hues]
├─ uo_install.py        # najdi a zaloguj instalaci, spočítej SHA-256 vstupů
├─ uop.py               # MYP0 kontejner (hlavička, hash tabulka, hash funkce, zlib)
├─ tiledata.py          # čtení tiledata (POZOR: layout se musí ověřit, §3.3.1)
├─ art.py               # RLE dekódování artu (16bit, 0x8000 = neprůhledný)
├─ gump.py              # gump art → RGBA
├─ anim.py              # anim.idx/anim.mul + AnimationFrame*.uop, animdata/animinfo
├─ hues.py              # hues.mul → JSON (ověřený layout)
├─ worldmap.py          # map*.uop + staidx/statics → .land/.bin/.idx/.meta.json
├─ textdata.py          # skills, skillgrp, doors, stairs, teleprts, misc, body.def…
├─ atlas.py             # shelf-pack do 2048² + manifest.json
└─ verify.py            # samostatné ověření výstupu (viz §3.5.3) — pouští se v bráně
```

Zásady:
- **Nic se nevyhazuje tiše:** každý krok hlásí počty (`entries read`, `skipped`,
  `unresolved`) a nevyřešené věci končí v `extract-report.json`.
- **Výstup je deterministický** (řazení klíčů, žádné časové značky).
- **`verify.py` je součást brány** — pouští se v CI nad už extrahovanými daty
  (ne nad instalací, ta v CI není).
- V CI **není instalace UO** → brány, které potřebují assety, se v CI
  **přeskočí s viditelnou poznámkou** „assety nejsou v CI, kontrola NEPROBĚHLA"
  (nikdy tiché zelené, viz `08-brany-a-overovani.md` §8.6).

## 3.8 Velikosti a co se commituje

| Cesta | Velikost (odhad) | V gitu? |
|---|---|---|
| `assets/uo/atlas/*.png` (jen referencované art ID) | 150–400 MB | ne |
| `assets/uo/world/map0.*` | ~110 MB | ne |
| `assets/uo/manifest.json` | 5–15 MB | ne (generuje se) |
| `data/*.json` (obsah: předměty, recepty, monstra, vendory) | < 2 MB | **ano** |
| `assets/fonts/*.ttf` (OFL, kvůli diakritice) | < 1 MB | **ano** |
| `assets/sfx/*` (CC0 náhrady, pokud se použijí) | < 20 MB | **ano** |
| `tools/uoextract/**`, `docs/**`, `tests/**` | < 1 MB | **ano** |

**Font rozhodnutí:** originální bitmapové fonty UO (`fonts.mul`, `unifont*.mul`)
**neobsahují českou diakritiku**. Pro české UI texty proto přibal **jeden OFL
font** (Google Fonts) a bitmapové fonty UO používej jen pro „UO vzhled"
anglických textů. Zdroj a licence patří do `CREDITS.md`.

## 3.9 Opravy a rozhodnutí naměřená 2026-10-02

> Tohle je **zápis měření**, ne změna zadání. Vzniklo při implementaci granulí
> `assets.*` a `world.*` (commity `a37a55d` … `a67968d` v `main`); každé číslo
> je reprodukovatelné příkazem, který je u něj uvedený. Co je tady, **platí před
> dřívějším textem** tohoto dokumentu (zejména před §3.4 a §3.5.4).

### 3.9.1 Opravy v §3.3.1 a §3.4

| Co | Dřív v dokumentu | Naměřeno |
|---|---|---|
| `LAND blok: offset 4` | čte se jako začátek bloku | je to offset **prvního záznamu** (za 4bajtovou hlavičkou první skupiny); blok začíná na 0. Kdyby se do `ITEM_OFF` přičetly další 4 B, vyjde 3 188 740 B místo přesných 3 188 736 B a načtení spadne (`tools/uoextract/tiledata.py --verify`) |
| index bloku mapy | `by * blocks_x + bx` | **`bx * blocks_y + by`** (x-major); `ClassicUO MapLoader.cs:623`. Při obráceném pořadí vychází blok Britainu (1495,1630) jako prázdný (0 statiků místo 60) a vykreslený náhled je pruhovaný |
| záznam statiky | `[u16 tile][u16 x][u16 y][i8 z]` | **`[u16 tile][u8 x][u8 y][i8 z][u16 hue]`** (7 B); `ClassicUO StaticsBlock`. Souřadnice jsou 0..7 v rámci bloku — při špatném čtení vycházejí hodnoty 251, 513 … (v jednom vzorku 7255 ze 7644 statiků „mimo blok") |
| blok Britainu | 20 záznamů | **60 statiků**; v okolí ±6 bloků 9 329 statiků |
| vodní dlaždice | neurčeno | id **168, 169, 170, 171, 310, 311** (podle jmen v `tiledata`); dlaždice 168 se jmenuje `water`, ne „sand" |

### 3.9.2 Rozhodnutí R1–R4 (měřením, ne podle zdroje)

| # | Otázka | Výsledek |
|---|---|---|
| **R1** | hash funkce pro jména záznamů UOP | `CreateHash` z ClassicUO **pokrývá 43 760/43 760 záznamů archivu (100 %)**; varianta `(pc << 32) \| pb` z `hashlittle2` dává 0/43 760. Dokumentovaných „1636 z 2000" je **jiné počítadlo** (indexy artu, ne záznamy archivu): 364 chybějících artů v této instalaci prostě není. `python tools/uoextract/uop.py --verify` |
| **R2** | komprese gumpart (BWT vs. zlib) | **„zlib stačí" neplatí**: všech **5 579 záznamů má flag 3 = zlib + BWT**; bez BWT se nerozbalí ani jeden gump. Rozhodl obrázek: batoh (gump 60) je 230×204 a je na něm kožený batoh. `python tools/uoextract/gump.py --verify` |
| **R3** | členění chunků mapy | **112 chunků je plných** (802 816 B = 4 096 bloků × 196 B → 458 752 bloků = **přesně celý svět**) a **113. chunk má jeden blok navíc**. Formulace „113 × 4096 = 462 848 ≥ 458 752" je tím zpřesněná, ne vyvrácená. `python tools/uoextract/worldmap.py --extract <out>` |
| **R4** | kliloky: BWT a kódování | potvrzeno: 3. bajt `Cliloc.enu` je `0x8E` → BWT (5 110 078 → 5 093 682 B); **124 433 záznamů**, text **UTF-8** (ne UTF-16), např. `500000 'Reputation aversion triggered.'`, `'iron'` ve 207 záznamech. `python tools/uoextract/cliloc.py --verify` |

### 3.9.3 Přesná čísla, která §3.5.4 uvádí přibližně

- land art: **4 244 dlaždic, všechny přesně 1 012 pixelů** (diamant 44×44) —
  ověřeno na celém archivu, ne na vzorku.
- statický art: **39 516 záznamů**; vzorek 3 000 dekódován bez chyby.
- mapa: **29 360 128 dlaždic**, max tile id **16 379**, mimo rozsah 0; statiky
  **121 056 použitých bloků**, součet délek **20 386 415 B = přesně** velikost
  `map0.statics.bin`.
- `hues.mul`: 3 000 sad; shoda textu `Hue (X->Y)` s poli `start`/`end`
  **1000/1000** (skupinový model) vs. **47/49** (plochý) — docs/10 P24.
- `skillgrp.mul`: `u32` (7) + 6× 17 B jmen + **58× u32** = 338 B; tabulka používá
  **7 id skupin**, pojmenovaných je 6 — id 6 mají 4 bard skilly (`Peacemaking`,
  `Discordance`, `Provocation`, `Musicianship`) bez jména; UI to musí zvládnout.
- `skills.mul`: `[1 B flag][NUL-ukončené jméno]` spotřebuje **celých 704 B**
  a dává 58 jmen; význam flagu dokument nepopsuje (v datech je zachovaný).

### 3.9.4 Co zůstává neověřené

- **`animinfo.mul`** (4 000 B) — obsah je jen opakující se vzor `04 02`; formát
  žádný dokument nepínuje, proto se neparsuje.
- **`anim*.mul` — pixely těl** (rozhodnutí o zdroji je hotové, viz §3.5.1):
  rozměry, počty framů a offsety ověřené jsou, ale tvar hlavičky framu a
  kódování indexů v RLE proudu ne — `x` z hlavičky běhu vychází mimo rozměr
  framu. Podrobně `research/anim-mereni.md`.
- **`AnimationFrame*.uop` — pixely těl**: záznam a jméno (`create_hash`) ověřené,
  ale rozměry framu z payloadu v této instalaci nesedí na známý tvar
  (ClassicUO/UOFiddler) — stejná otevřená otázka jako u MUL.
- **Světelný cyklus** (`docs/11` §11.6): v `world.time` je hranice noci
  (22:00–06:00) **rozhodnutí** a noční osvětlení je zatím stejné jako denní (12).

### 3.9.5 Mezery roadmapy (patří generátoru `tools/roadmap-gen.py`)

- `sim.world_loop` má `size_lines: "<= 60", model: "any"`, ale jeho vlastní prompt
  říká „size_lines > 60 → model strong" a soubor má ~192 neprázdných řádků;
  obdobně přesahují `sim.commands` (118) a `app.input` (89).
- **`app/main.tscn` nemá vlastníka** v žádném `owns` — `boot.project` vlastní jen
  `project.godot` a `app.main` jen `app/main.gd`; připojení skriptu ke scéně je
  proto integrační krok, který provedl bootstrap.
