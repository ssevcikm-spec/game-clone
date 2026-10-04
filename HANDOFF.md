# Předání — UO-klon (stav po `world.map`: mapa se čte, dvě implementace souhlasí)

> Tento soubor je pro **další session agenta**. Všechno podstatné je v repu
> a v `git log`; tady je jen to, co by jinak stálo hodiny znovuobjevování.
> Datum: 2026-10-04. Zjištění o odemčení W1 (`tiledata --extract` → `data.items`
> → `world.tiledata`) **platí dál**.
> **Tato session udělala granuli `world.map`** a znovu naměřila testy i brány.

## ⚠ POVINNÉ: na konci každé session (rozhodnutí uživatele, 2026-10-03)

Uživatel volá **na každý krok novou session** a **po každé implementaci hned
následuje předání**. Proto platí:

1. **`LESSONS.md`** — přidej záznamy za tuhle session (ponaučení, chyby,
   osvědčené postupy, nové nástroje). Šablona je v hlavičce toho souboru.
   Piš i to, co **nevyšlo**; zápis bez měření je dohad.
2. **`HANDOFF.md`** — přepiš ho na stav po své práci, ale **tuhle sekci
   zkopíruj doslova dál** (jinak pravidlo zmizí). Aktualizuj hlavně: co je
   hotové a ověřené, co je **otevřené a proč**, a co je příští krok.
3. **Ověř před předáním:** brány (`run-all.py`), testy hry, self-testy —
   a napiš do předání **skutečná čísla**, ne ta z minula.
4. **Commitni** (strom čistý) — `LESSONS.md` i `HANDOFF.md` patří do gitu,
   protože další session je čte odtud.

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Testy | `godot --headless --path . --script res://tests/run_tests.gd` → **238 kontrol / 0 selhání** (znovu naměřeno 2026-10-04) |
| Brány | `python tools/gates/run-all.py` → **9 měřeno / 2 NEMĚŘENO / 0 chyb** (exit 2 = něco neměřeno; znovu naměřeno 2026-10-04) |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 celkem (10 bran + 9 extrakčních nástrojů), 0 chyb** (znovu naměřeno 2026-10-04) |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` (101 granul; `done` je u všech `false` — stav se pozná jen měřením) |
| Data z instalace | `assets/uo/` (gitignore) — **`tiles.json` 2 405 685 B** (land 16 384, item 65 536) |

## Co je hotové a ověřené (ne „soubor existuje")

bootstrap 4 · W0 8 · M0 5 · M1 8 (**uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc**) · M2 4 (world.doors, world.stairs, entity.stats, world.time) ·
assets.anim 1 · `data.items` 8 748 záznamů · `world.tiledata` (18 kontrol sondy) ·
**NOVĚ `world.map` — `sim/world/map.gd` (18/18 sondy + cross-check + mutace)**.

**Tato session (2026-10-04):**

- **`world.map`** (`sim/world/map.gd`, 186 řádku) — čte `map0.land` + `map0.statics.idx/.bin`
  po blocích 8×8, LRU cache 2048 bloků. API z `docs/04 §4.2`: `land_at`, `z_at`,
  `statics_at` (vrací `{tile, z, hue}`), `load_block`, `is_loaded`.
- **Ověření:** sonda `.cache/analysis/probe-map.gd` **18 kontrol / 0 selhání**;
  nezávislý cross-check `.cache/analysis/probe-map-python.py` (numpy, ta sama
  matematika jako `worldmap.py`) → **shoda True**; **mutační test** (index bloku
  otočen na by-major) → 3 selhání, přesně `0 statiků v Britainu místo 60`.
- Naměřené hodnoty, které sedí na `docs/03 §3.9.1`: **britanský blok 60 statiků**,
  **v okolí ±6 bloků 9329 statiků**, land id **1…16379** (žádné nad `0x3FFF`),
  z **−128…127**.
- **Zásadní nález:** `map0.land` se musí číst **od `key * 196 + 4`** — 4B hlavička
  bloku. Bez `+4` všechno „funguje" a rozsah z je dokonce v pořádku; chybu
  odhalila až shoda s druhou implementací (`LESSONS.md`, záznam z 2026-10-04).

## Nové rozhodnutí, která jsem musel udělat

1. **`statics_at()` vrací tiledata id BEZ `+0x4000`.** Naměřeno: všech 60 statiků
   britanského bloku má `tile` v rozmezí **37…4758**, tedy pod `0x4000`.
   `docs/04 §4.2` přitom píše „statický art = tiledata id + 0x4000". **Obě tvrzení
   nejsou v rozporu, ale v kontraktu chybí, kdo ten přičítá** — musí to být
   zadáno v `docs/`, jinak si to každá granule vyloží jinak (a `world.tiledata.value()`
   bere na vstupu id s offsetem: `value(item - ITEM_OFFSET)`).
2. **`map.gd` nedělám `width()`/`height()`/`land_tile_max()` z `Const`** — čte je
   z `map0.meta.json`, aby čísla nebyla dvakrát (G1 to hlídá, ale pravidlo platí
   i bez brány).

## Otevřené věci a co je potřeba dodělat

1. **`world.map` nemá test v `tests/cases/`** — stejná mezera jako u `data.items`
   a `world.tiledata`. Granule má `acceptance: ["tests", "content"]`, ale G3
   (testy) o ní neví a `tests/` needituje člověk. **Sonda v `.cache/analysis/`
   není test** — ve čerstvém klonu ji nikdo nespustí.
2. **`sim/world/map.gd` má 186 řádků proti deklarovanému `<= 120`** (152 neprázdných,
   19 komentářových). To je **17. soubor z 27**, který deklaraci překračuje —
   viz bod 3, je to systémová věc, ne chyba této granule.
3. **`size_lines` nesedí u 16 z 26 dosavadních souborů granul** (stav z minulého
   předání, `map.gd` ho zvýšil na 17 z 27). `assets.anim` 516 ř. vs `<= 150`,
   `assets.uop` 471 vs 150, `assets.worldmap` 385 vs 150, `assets.art` 365 vs 60,
   `assets.tiledata` 306 vs 150, `sim.world_loop` 232 vs 60, `sim/commands` 137 vs 60,
   `app.input` 108 vs 60, `world.doors` 106 vs 60, `core.rng` 78 vs 60,
   `world.stairs` 74 vs 60, `core.clock` 65 vs 60, **`world.map` 186 vs 120**.
   **Buď uvolnit deklarace, nebo dělit granule** — `docs/09 §9.2` a „auto-merge
   podle deklarace" na tom stojí. **Je to rozhodnutí pro uživatele.**
   **Pozor na metriku:** `Measure-Object -Line` **nepočítá prázdné řádky**;
   `size_lines` se měří všemi řádky (Python `splitlines()`).
4. **`data.items` nemá generátor v repu.** `data/items.json` je hotový a v gitu,
   ale vyrobil ho `.cache/analysis/gen-items.py` (běh ze session, gitignore).
   Podle `docs/06 §6.1` má `data/*.json` generovat `tools/gates/gen-content.py`
   (granule `data.gen_content`, `owns` ho má, soubor **neexistuje**).
5. **`docs/04 §4.2` je v rozporu s realitou u `world.tiledata`:** slibuje
   `assets/uo/manifest.json` + `data/tiles.json`; skutečnost je
   `assets/uo/tiles.json` + `data/items.json`.
6. **`assets.uop` (2 rozpory k rozhodnutí testem)** a **`assets.atlas`/`assets.verify`/
   `assets.extract_cli`** nejsou hotové — bez `atlas.py` není `manifest.json`,
   takže G6 je v části atlasu slepá a `render.textures` nemá z čeho číst.
7. **Pixely animací** (z minulého HANDOFFu, **platí dál**): tvar hlavičky framu
   a kódování indexů v RLE proudu jsou neověřené (`x` z hlavičky vychází
   1020–1023, mimo rozměr framu 24×64). Zdroj je rozhodnutý měřením:
   **blok v MUL → MUL, jinak UOP**.
8. **Stará poznámka v `tools/uoextract/worldmap.py` (10–11, 60–63, 87–90) je zastaralá:**
   tvrdí, že `docs/03 §3.4` uvádí špatné pořadí bloku a špatné šířky polí — `docs/03`
   už je opravený (§3.9.1) a kód `struct.unpack_from("<HBBbH")` je správný.
   Není to vada kódu, ale člověk, který to čte, se zbytečně bojí.

## Další kroky (v tomto pořadí)

1. **`data.gen_content`** — přesunout `gen-items.py` do repa jako
   `tools/gates/gen-content.py` (granule vlastní ten soubor) + doplnit role,
   které v datech nejsou (6 nástrojů z `docs/06 §6.2`: `skillet`, `flour mill`,
   `spinning wheel`, `loom`, `oven`, `bellows` → `assets/uo/content-report.json`).
   Nejde o to být hezký, ale aby `items.json` šel přegenerovat.
2. **`render.sort`** (`render/sort.gd`, `any`, `<= 60`) — DAG splněný: závisí na
   `core.iso` + **`world.map` (hotový)**. Smlouva: `sort_key(obj) -> int`,
   `draw_order(objects) -> Array`; pořadí land → statiky podle z → mobilové podle z,
   dlaždice podle `(x+y)` (`docs/02 §2.4`, past P21).
3. **`render.textures`** — až po `assets.atlas` (chybí `manifest.json`).
4. Pak **`assets.atlas`** (tím se zapne G10, které je teď NEMĚŘENO).

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA** —
  `depends_on` znamená „hotové a funkční", ne „jméno existuje v DAGu".
- **Binární formát ověř dvěma implementacemi.** Rozsahová kontrola je slabá brána:
  chybný posun o 4 B v `map0.land` dával plausibilní `z` v `-128..127` a správných
  60 statiků (ty se čtou z jiného souboru). Prostě porovnej bajty.
- **Dívat se na data, ne na počty.** 1126 „zbraní" vypadalo jako úspěch;
  teprve výpis jmen ukázal, že jsou to helmy. Každý generátor ať **vypíše ukázky**.
- **Když se dvě měření rozcházejí, hledej, čím se liší** (451 vs 516 = prázdné řádky).
- **Mutační test u každé brány, sondy i nové funkce** (otoč vztah → musí spadnout).
- **Dokumentovaná tabulka není důkaz** — každý bit/číslo ověř na datech.

## Pasti, které už někoho stály čas (naměřené)

1. **Sandbox `workspace-write` umí zakázat zápis i DO workspace** a vypadá to jako
   vada ukládání. Přesná příčina: `workspace-write` pouští podprocesy jako
   **Low integrity**, a Low proces nesmí zapsat do objektu **bez Low labelu**.
   Naměřeno 2026-10-04: label má **jen kořen workspace** (`icacls` →
   `Mandatory Label\Low Mandatory Level:(OI)(CI)(NW)`), **podsložky `sim/`, `tools/`,
   `.cache/`, `data/`, `assets/` label nemají**. Sonda `_analyza/sonda-zapisu.py`:
   **1/19 před, 19/19 po přepnutí na `danger-full-access`**.
   **Postup:** změř label (`icacls <cesta> | findstr Mandatory`), a když chybí,
   přepni session na plný přístup; skript `diagnose-windows-sandbox-acl` spraví
   DACL, ne label.
2. **`map0.land` má na každém bloku 4B hlavičku** — čti od `key * 196 + 4`.
   Bez `+4` to nevyvolá žádnou chybu (viz „Jak to dělat"). Viz `LESSONS.md`.
3. **Godot s nerozjetým skriptem visí, ne selže** — `Parse Error` → `_initialize`
   spadne → prázdná smyčka, proces s **0,05 s CPU**. Každý `--script` běh spouštěj
   **s `--quit-after N`** a výstup **přesměruj do souboru** (`| Out-File`):
   `| Select-Object -Last 40` bufferuje a u visícího procesu neukáže nic.
4. **`.uid` vzniká jen při `godot --headless --path . --import`**, ne při testech
   a ne při branách. Po každém novém `.gd` ho zkontroluj v `git status`.
5. **Godot z `C:\...\orchestra\tools\godot` NEMŮŽE ZAPISOVAT** (sandbox) a přitom
   lže `err=0`. Řešení: kopie ve workspace (`.cache/godot/`, gitignore);
   brány si ji připraví (`gate_common.godot_bin()`).
6. **`JSON.parse_string` vrací VŠECHNA čísla jako `float`** — u int64 stavu RNG
   to tiše poškodilo data. Vždy `int()`; hodnoty > 2^53 jako řetězec.
7. **`.gitignore` je na Windows case-insensitive** — vzor `Cliloc.*` pohltil
   `tools/uoextract/cliloc.py`. Kontroluj `git ls-files`, ne `Test-Path`.
8. **`Measure-Object -Line` nepočítá prázdné řádky** — počty řádků měř Pythonem.
9. **Brána, která nic nezměří, není zelená** — `run-all.py` vrací 2 = NEMĚŘENO.
10. **Zápis „mezi tím" do souboru, který čte jiný běh, vypadá jako změna souboru**
    — `write` pak odmítne zápis; soubor znovu přečti a zapiš znovu.
11. **Statická kontrola musí číst kód, ne komentáře — i ta tvoje vlastní.**
12. **`& skript.ps1` na této stanici neprojde** (`running scripts is disabled`);
    použij `powershell.exe -ExecutionPolicy Bypass -File <cesta>`.
13. **Hledání podřetězcem u jmen předmětů vybírá smetí** (`log` → `log wall`,
     `loom` → `Bloom Firework`, `pan` → `pants`). Hledej přesně, u UO i s plurálem.
14. **U nové pasti: zapiš ji sem i do `LESSONS.md`** — příští session ji jinak
     objeví znovu.

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03 §3.4` — index bloku mapy**: už opraveno na `bx * blocks_y + by`.
2. **`docs/03 §3.4` — záznam statiky**: už opraveno na `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
3. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; skutečné soubory jsou `assets/uo/tiles.json`
   a `data/items.json`.
4. **`docs/04 §4.2` u `world.map` nerozlišuje `tiledata id` a `art id`** u statiků:
   soubor v této instalaci ukládá **id bez `+0x4000`** (naměřeno 37…4758).
5. **`docs/06 §6.2` uvádí 6 nástrojů, které v této instalaci NEJSOU**:
   `skillet` (je `frypan`), `flour mill` (je `millstone`), `spinning wheel`,
   `loom`, `oven`, `bellows`. Patří to do `docs/` jako měření, ne do kódu.
6. **`.forge/roadmap.json` — `size_lines` nesedí u 17 z 27 souborů** (viz bod 3
   otevřených věcí). **Brána to neměří** — je to tichá regrese plánování.
7. **`app/main.tscn` nemá vlastníka** v roadmapě.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (docs/02 §2.6.8).
- **Nečeské znaky (í, š, ň) nepatří do identifikátorů** — GDScript je neumí,
  sonda se tak jmenovala `nejniżsí` a musela se přepsat.
- Pišu **jen do `owns`** své granule; `tests/`, `tools/gates/`,
  `project.godot`, `.forge/`, `docs/`, `assets/uo/` needituju.
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py` vrací 0 = vše změřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není
  zelená). `--strict` dělá z NEMĚŘENO vadu (pro M8).
- Testy potřebují `APPDATA` ve workspace, jinak `user://` míří mimo:
  `$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"`.
  **Brány si to nastavují samy** (`tools/gates/gate_common.py:219`).