# Animace těl — měření a rozhodnutí (docs/03 §3.5.1, O3)

> **DOPLNĚNO 2026-10-06 (datum spotřeby): z tohohle dokumentu se stavělo a jedna
> jeho otevřená otázka je VYŘEŠENÁ.** Oddíl „Co je ověřené o formátu bloku" níž
> končí tím, že **pixely z `anim.mul` se extrahovat nedají** (neznámá hlavička
> běhu, `x` vychází 1020–1023). To **už neplatí**:
>
> * `x` a `y` v hlavičce běhu jsou **znamenkové desetibitové** hodnoty —
>   `1020..1023` je `-4..-1`. Proto taky každá hlavička končí bajtem `0xFF`.
> * Prvních 512 B bloku **JE paleta** (256× u16 ARGB1555). Měření výš je správné
>   v tom, že je ve vzorcích shodná; nesprávný byl závěr, že tedy žádná není.
>   Naked tělo je proto šedé — barvu kůže dělá až hue z `hues.mul`.
> * Pixel = **1 bajt** = index do té palety; terminátor `0x7FFF7FFF` je na konci
>   framu (naše dřívější „konec" mířil o 4 B dál, do další hlavičky).
>
> Reference: `_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs`
> (`ReadMULAnimationFrames`, `ReadSpriteData`). Měření a dekodér:
> `_analyza/anim-rle-sonda.py`, `_analyza/anim-rle-hledani.py`,
> `_analyza/anim-dekod.py`; produkčně `tools/uoextract/anim.py`
> (`decode_frame`, `--export`, `--self-test` 35 kontrol, mutace 8/8).
> Důkaz: 0 pixelů mimo frame na 30 blocích (těla 400/401 × walk/run/idle × 5 směrů).
> Zbytek dokumentu je **ve svém čase správný** a needituje se.

Datum: 2026-10-03. Zdroj: `research/probe/anim_pokryti.py` (spustitelné kdykoli
znovu), surová data v `research/anim-pokryti.json`.

## Rozhodnutí

**Zdroj je nutné použít OBA — a `anim*.mul` je ten povinný, ne fallback.**

Dokument (`docs/03 §3.5.1`) doporučoval opak: „novější `AnimationFrame*.uop`
a `anim*.mul` jen jako fallback". Měření to vyvrací.

| Zdroj | Těl s obsahem | Akcí | Co v něm je |
|---|---|---|---|
| `anim*.mul` + `anim*.idx` | **270** | 7 165 | monstra 1–199 (60), zvířata 200–399 (35), **lidé 400+ (175 těl, 35 akcí každé)** |
| `AnimationFrame1..4,6.uop` | **318** | 10 989 | nová těla 400+ (282), zvířata (30), monstra (4) |
| průnik | **2** (těla 826, 990) | — | — |

**Těla se téměř nepotkávají** (2 z 588). Není to tedy volba „lepší/horší zdroj",
ale dvě disjunktní sady:

* **Hráč a klasický obsah jsou POUZE v MUL.** Tělo 400 (muž) i 401 (žena) mají
  v MUL všech **35 akcí × 5 směrů = 175 bloků**; v UOP mají **0**. Totéž těla
  404–410 (oblečení). Bez `anim.mul` se hráč nepohne — to je rozhodující fakt.
* **Nová těla jsou POUZE v UOP.** Tělo 130 (16 akcí), 334 (52 akcí), 666
  (gargoyle, 52 akcí) v MUL nemají ani blok.

Postup pro `assets.anim` proto je: **tělo se bere z MUL, když tam má blok;
jinak z UOP.** Přesně to dělá i ClassicUO (`UseUopAnimation` flag v
`mobtypes.txt`) a UOFiddler (`IsUopBody`).

## Hash jmen v UOP — rozhodnuto měřením

UOP animace se adresují jménem `build/animationlegacyframe/{tělo:06d}/{akce:02d}.bin`.
Na vzorku 700 těl × 80 akcí:

| Kandidát (uop.py, R1) | Nalezených záznamů |
|---|---|
| `create_hash` (ClassicUO) | **4 747** |
| `jenkins_pb_pc` | 4 747 (tatáž funkce, jiné pořadí složek) |
| `jenkins_pc_pb` | **0** |

Pro animace tedy platí **`create_hash`** — stejně jako pro art. Pozor na opačné
pořadí proti artu: tam rozhodovalo `jenkins_pc_pb`, tady `jenkins_pb_pc`; obojí
je ale táž hodnota jako `create_hash`, jen zapsaná jinak (v `uop.py` je proto
jediná směrodatná funkce `create_hash`).

## Co je ověřené o formátu bloku `anim.mul` (a co ne)

Ověřeno měřením (`research/probe/anim_pokryti.py`, sondy v `.cache/probe-anim*.py`):

* `anim.idx` = 148 810 slotů × 12 B; offset pro tělo se počítá po skupinách
  (`tělo < 200`: `tělo × 110`; `200..399`: `(tělo − 200) × 65 + 22 000`;
  `400+`: `(tělo − 400) × 175 + 35 000`), každý slot 12 B `[u32 offset][u32 size][u32]`.
  **Součet sedí přesně na velikost souboru** — mapování slotů je správné.
* Tabulka framů v bloku: `[u32 počet]` na bajtu 512, `počet × u32 offset` od 516.
  Počet framů i offsety jsou konzistentní (tělo 400 akce 0: 10 framů; akce 4: 1 frame;
  akce 21: 6 framů).
* Terminátor RLE proudu `0x7FFF7FFF` leží u posledního framu **4 B před koncem bloku**
  (ověřeno na 10 framech téhož bloku — všechny na `516 + offset[i+1] − 4`).
* **Prvních 512 B bloku je ve VŠECH blocích stejných** (tělo 400/200/9, různé akce
  — bit po bitu shodné). Pixely těl tedy **nemají vlastní paletu**; barva jde
  z `animdata.mul` / `hues.mul`, jak uvádí `research/05-data-formats.md` §5.2.
  (Varianta „paleta na začátku bloku" z `UOFiddler`/`ServUO` v této instalaci
  nesedí — proto se rozchází i počet pixelů.)

**Neověřeno (zůstává otevřené):** přesný tvar hlavičky framu a kódování indexů
uvnitř RLE proudu. Naměřená čísla, která to ohraničují:

* blok těla 400 akce 4 (1 frame): 1 868 B, stream 1 344 B, hlavička dává
  `cx=13, cy=−4, w=26, h=60` (konzistentní na 4 různých pozicích),
* blok těla 400 akce 0 (10 framů): ~1 210 B na frame, 85 běhů, rozměry 24×64,
* délky běhů vycházejí v desítkách pixelů (`run` 4–9 typicky), ale `x` z hlavičky
  běhu vychází v rozsahu 1 020–1 023, tedy **mimo rozměr framu** — to je přesně
  to, co ještě není rozluštěno (buď se `x` nečte z bitů 22–31, nebo je báze jiná).

Důsledek pro granule: `assets.anim` **umí** dodat rozměry, počty framů, offsety a
zdroj pro každé (tělo, akce, směr) — na tom se dá stavět časování i atlas.
**Pixely z `anim.mul` se zatím extrahovat nedají**; kdo na tom bude stavět
(`assets.atlas`, `render.anim`), musí vědět, že cesta k pixelům těl vede
přes tuto otevřenou otázku, ne přes hotový dekodér.

## Reprodukce

```powershell
python research/probe/anim_pokryti.py --telo 400
```
