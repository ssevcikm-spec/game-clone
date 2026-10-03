# Předání — UO-klon (stav po ověření prostředí: testy i brány měří; W1 čeká na `world.map`)

> Tento soubor je pro **další session agenta**. Všechno podstatné je v repu
> a v `git log`; tady je jen to, co by jinak stálo hodiny znovuobjevování.
> Datum: 2026-10-03. Předchozí verze popsala odemčení W1
> (`tiledata --extract` → `data.items` → `world.tiledata`) — ta zjištění **platí dál**.
> **Tato session neudělala žádnou granuli**: spravila přístup k workspace (sandbox
> blokoval zápis do všech podsložek) a znovu naměřila testy i brány.

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
| Testy | `godot --headless --path . --script res://tests/run_tests.gd` → **238 kontrol / 0 selhání** (znovu naměřeno 2026-10-03, s `APPDATA` v `.cache/godot-appdata`) |
| Brány | `python tools/gates/run-all.py` → **9 měřeno / 2 NEMĚŘENO / 0 chyb** (exit 2 = něco neměřeno); znovu naměřeno 2026-10-03 |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 celkem (10 bran + 9 extrakčních nástrojů), 0 chyb** (znovu naměřeno 2026-10-03) |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` (101 granul; `done` je u všech `false` — stav se pozná jen měřením) |
| Data z instalace | `assets/uo/` (gitignore) — **`tiles.json` 2 405 685 B** (land 16 384, item 65 536) |

## Co je hotové a ověřené (ne „soubor existuje")

bootstrap 4 · W0 8 · M0 5 · M1 8 (**uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc**) · M2 4 (world.doors, world.stairs, entity.stats, world.time) ·
assets.anim 1 · **NOVĚ: `data.items` 8 748 záznamů · `world.tiledata` (18 kontrol sondy)**.

**Tato session (2026-10-03, druhá):** žádná granule — spravený **přístup k workspace**
a znovu naměřené hodnoty: testy **238/0**, brány **9 měřeno / 2 NEMĚŘENO / 0 chyb**,
`check-docs-refs` / `check-zadani` / `roadmap-gen --check` **exit 0**. Dvě brány, které
předtím hlásily `VADA` (G3, G7), byly **celé prostředí**, ne kód — viz past 1.

**Bootstrap i W0 jsem v této session jen OVĚŘIL, nedělal znovu** (byly hotové):
28 naměřených hodnot, 1 NEMĚŘENO, 0 vad (`LESSONS.md` 2026-10-03 „Bootstrap i W0…").
Nástroj: `.cache/analysis/bootstrap-verify.py` → `.cache/analysis/bootstrap-vysledek.json`.
Jediné NEMĚŘENO: **`tools/gates/ci-godot.sh` nejde na této stanici spustit** —
`bash`/`sh` tu není a WSL není nainstalované. Je jen volaný z CI a přečtený;
jeho obsah (APPDATA + import + testy) jsem ověřil ručně.

## Jak je zapojený řetěz M1 (zjištění z předchozí session, platí dál)

```
instalace UO (read-only)
   └─ tools/uoextract/tiledata.py --extract assets/uo   ← NOVĚ (dřív jen --verify, nic nezapisoval)
         └─ assets/uo/tiles.json        land + item, 81 920 záznamů
              ├─ (sessions nástroj) .cache/analysis/gen-items.py
              │     └─ data/items.json   8 748 předmětů (V REPU)
              │           └─ assets/uo/content-report.json  (2 nevyřešené role)
              └─ sim/world/tiledata.gd    čte OBOJÍ: tiles.json + data/items.json
```

**Proč to bylo potřeba:** `world.tiledata` má podle smlouvy číst `data/tiles.json`,
ale **takový soubor neměl kdo vyrobit** — `tiledata.py` uměl jen `--verify`.
Celá W1 (`world.tiledata` → `world.map` → `render.sort`, a `data.items` →
`world.tiledata`) proto stála. Doplnil jsem `--extract` (výjimka schválená
uživatelem, stejný vzor jako `worldmap.py --extract` / `hues.py --out`).

## Rozhodnutí, která jsem udělal (a co z nich plyne)

1. **Dvě id prostranství**: `tile < 0x4000` = land, `tile >= 0x4000` = předmět
   (`tiledata id = tile - 0x4000`, statický art = `tiledata id + 0x4000`).
   `is_land()` platí pro obě strany hranice. `docs/04 §4.2` to měl jen v náznaku.
2. **`value` není v tiledata** (to pole tam neexistuje, je tam jen `count`).
   Bere se z `data/items.json`, kde má každý záznam `value_source`
   (`tiledata-count` / `weight-fallback` / `minimum`) — není to tedy na dvou místech.
3. **Kategorie se NEurčuje z flagů.** Naměřeno: bit 2 (`Weapon` z `research/05`)
   má **všech 1268** Wearable předmětů (i `leather cap`), bit 27 (`Armor`) má
   25 předmětů a **ani jeden není zbroj**. Kdo by věřil tabulce, vyrobí 1126 zbraní.
   Kategorie je z `layer` + jména a každý záznam má `category_rule`, aby bylo vidět proč.
4. **`%s` ve jménech je znak plurálu**, ne vada (`iron ingot%s`). Vyřazovat `%`
   znamená přijít o ingoty, obvazy a šípy. Vyřazují se jen skutečné placeholdery
   (`Missing_Name` 92×, `NoName` 29×, `nodraw` 19×).

## Otevřené věci a co je potřeba dodělat

1. **`HANDOFF.md` past #7 (size_lines) je horší, než se myslelo.** Naměřeno
   systematicky (26 souborů granul): **16 z 26 přesahuje deklaraci** —
   `assets.anim` 516 ř. vs `<= 150`, `assets.uop` 471 vs 150, `assets.worldmap`
   385 vs 150, `assets.art` 365 vs 60, `assets.tiledata` 306 vs 150,
   `sim.world_loop` 232 vs 60, `sim/commands` 137 vs 60, `app.input` 108 vs 60,
   `world.doors` 106 vs 60, `core.rng` 78 vs 60, `world.stairs` 74 vs 60,
   `core.clock` 65 vs 60 (a další). **Buď uvolnit deklarace, nebo dělit granule** —
   `docs/09 §9.2` a „auto-merge podle deklarace" na tom stojí.
   **Pozor na metriku:** `Measure-Object -Line` **nepočítá prázdné řádky**;
   `size_lines` se měří všemi řádky (Python `splitlines()`). Starý HANDOFF uváděl
   451/192/118 (neprázdné), skutečnost je 516/232/137.
2. **`data.items` nemá generátor v repu.** `data/items.json` je hotový a v gitu,
   ale vyrobil ho `.cache/analysis/gen-items.py` (běh ze session, gitignore).
   Podle `docs/06 §6.1` má `data/*.json` generovat `tools/gates/gen-content.py`
   (granule `data.gen_content`, `owns` ho má, soubor **neexistuje**).
   Kdyby se `items.json` měl přegenerovat, teď to nikdo neudělá.
3. **`docs/04 §4.2` je v rozporu s realitou u `world.tiledata`:** slibuje
   `assets/uo/manifest.json` + `data/tiles.json`; skutečnost je
   `assets/uo/tiles.json` + `data/items.json` (`manifest.json` nevzniká, patří
   granuli `assets.atlas`, která není hotová). Smlouvu opravit v `docs/`.
4. **`data.items` nemá test v `tests/cases/`.** Jeho `acceptance` je
   `[content, schema]` a G5 ho měří (8 748 záznamů, OK), ale **G3 (testy) o něm
   nic neví** — agent `tests/` needituje, takže test musí přidat člověk.
   To samé `world.tiledata` (18 kontrol mám jen v sondě `.cache/analysis/probe-tiledata.gd`).
5. **8 `.gd` souborů je v gitu bez svého `.uid`** (`sim/entity/stats.gd`,
   `sim/world/doors.gd`, `stairs.gd`, `time.gd`, `tests/cases/{doors,stairs,stats,time}.gd`).
   `.godot/` v gitu není, takže `.uid` je jediná stopa o identitě skriptu —
   v čerstvém klonu dostanou skripty jinou identitu. Vyřešeno v tomto commitu
   (přidány), ale **platí pravidlo: po každém novém `.gd` přidat i `.uid`**.
6. **`assets.uop` (2 rozpory k rozhodnutí testem)** a **`assets.atlas`/`assets.verify`/
   `assets.extract_cli`** nejsou hotové — bez `atlas.py` není `manifest.json`,
   takže G6 je v části atlasu slepá a `render.textures` nemá z čeho číst.
7. **Pixely animací** (z minulého HANDOFFu, **platí dál**): tvar hlavičky framu
   a kódování indexů v RLE proudu jsou neověřené (`x` z hlavičky vychází
   1020–1023, mimo rozměr framu 24×64). `tools/uoextract/anim.py` pixely těl
   záměrně nevyrábí. **Blokátor pro `assets.atlas` v části `anim`.**
   Zdroj je rozhodnutý měřením: **blok v MUL → MUL, jinak UOP**.

## Další kroky (v tomto pořadí)

1. **`world.map`** (`sim/world/map.gd`, `strong`, `<= 120`) — `assets/uo/world/`
   už je hotové (`map0.land` 89 MB, `map0.statics.bin`, `map0.statics.idx`,
   `map0.meta.json`) a `world.tiledata` funguje, takže **DAG je splněný**.
   `map0.meta.json` dává rozměry: 896×512 bloků, 196 B/blok, `land_tile_max` 16 379.
2. **`data.items` dotáhnout**: přesunout `gen-items.py` do repa jako
   `tools/gates/gen-content.py` (granule `data.gen_content`) + doplnit role,
   které v datech nejsou (6 nástrojů z `docs/06 §6.2`: `skillet`, `flour mill`,
   `spinning wheel`, `loom`, `oven`, `bellows` → `assets/uo/content-report.json`).
3. **`render.textures` / `render.sort`** — až po `world.map` (DAG).
4. Pak **`assets.atlas`** (tím se zapne G10, které je teď NEMĚŘENO).

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA** —
  `depends_on` znamená „hotové a funkční", ne „jméno existuje v DAGu".
  Dnešní blokátor W1 byl přesně tohle.
- **Dívat se na data, ne na počty.** 1126 „zbraní" vypadalo jako úspěch;
  teprve výpis jmen ukázal, že jsou to helmy. Každý generátor ať **vypíše ukázky**.
- **Když se dvě měření rozcházejí, hledej, čím se liší** (451 vs 516 = prázdné řádky).
- **Mutační test u každé brány i u nové funkce** (vlož vadu → musí spadnout).
- **Dokumentovaná tabulka není důkaz** — každý bit/číslo ověř na datech.

## Pasti, které už někoho stály čas (naměřené)

1. **Sandbox `workspace-write` umí zakázat zápis i DO workspace** a vypadá to jako
   vada ukládání: `save()` vrátilo `false` (`FileAccess.get_open_error()` 12),
   test hlásil 1 selhání. **Nebyla to vada kódu** — nešlo zapsat nic (ani Pythonem).
   Po přepnutí file policy na `danger-full-access`: 238/0 bez změny kódu.
   **Když selže jeden test na soubory, nejdřív ověř, že jde zapsat vůbec něco.**
   **Doplněno 2026-10-03 (druhá session) — přesná příčina:** `workspace-write` pouští
   podprocesy jako **Low integrity** (`whoami /groups` → `Mandatory Label\Low Mandatory
   Level`), a Low proces nesmí zapsat do objektu **bez Low labelu** — bez ohledu na ACL.
   Kořen workspace label má (`icacls` → `Mandatory Label\Low Mandatory Level:(OI)(CI)(NW)`),
   **existující podsložky ne** (label se k nim nikdy nedostal), takže zápis prošel
   v kořeni a v nové složce, ale v `sim/`, `tools/`, `.cache/`, `.git/` ne.
   Sonda `_analyza/sonda-zapisu.py`: **1/19 před, 19/19 po** přepnutí na plný přístup.
   Skript `diagnose-windows-sandbox-acl` (14 grantů, vše ověřené) to **nevyřeší** —
   spraví DACL, ale label zůstane; jeho vlastní výstup to reportuje jako `LOW_LABEL=`.
   **Postup:** změř label (`icacls <cesta> | Select-String Mandatory`), a když chybí,
   přepni session na plný přístup; nepřesvědčuj se opravou práv.
2. **Godot z `C:\...\orchestra\tools\godot` NEMŮŽE ZAPISOVAT** (sandbox) a přitom
   lže `err=0`. Řešení: kopie ve workspace (`.cache/godot/`, gitignore);
   brány si ji připraví (`gate_common.godot_bin()`).
3. **`JSON.parse_string` vrací VŠECHNA čísla jako `float`** — u int64 stavu RNG
   to tiše poškodilo data. Vždy `int()`; hodnoty > 2^53 jako řetězec.
   **Pozor ale na opačný omyl:** „nad 2^53" **není** totéž co „ztratí přesnost"
   (`0x4E55000000000000` má 53 nulových bitů a float64 ho drží přesně).
   V `tiledata.mul` **není ani jedna** hodnota neexaktní pro float64 (měřeno
   pro všech 81 920 záznamů), ale `--extract` to **ověřuje při každém běhu**
   a radši spadne, než by vyrobil tichou vadu.
4. **`.gitignore` je na Windows case-insensitive** — vzor `Cliloc.*` pohltil
   `tools/uoextract/cliloc.py`. Kontroluj `git ls-files`, ne `Test-Path`.
5. **`Measure-Object -Line` nepočítá prázdné řádky** — počty řádků měř Pythonem.
6. **Brána, která nic nezměří, není zelená** — `run-all.py` vrací 2 = NEMĚŘENO.
7. **Zápis „mezi tím" do souboru, který čte jiný běh, vypadá jako změna souboru**
   — `write` pak odmítne zápis; soubor znovu přečti a zapiš znovu.
8. **Statická kontrola musí číst kód, ne komentáře — i ta tvoje vlastní.**
   Vlastní sonda mi hlásila vadu `project.godot`, protože našla `TILE_W`
   v komentáři, který vysvětluje, že tam být nemá.
9. **`& skript.ps1` na této stanici neprojde** (`running scripts is disabled`);
   použij `powershell.exe -ExecutionPolicy Bypass -File <cesta>`.
10. **Hledání podřetězcem u jmen předmětů vybírá smetí** (`log` → `log wall`,
    `loom` → `Bloom Firework`, `pan` → `pants`). Hledej přesně, u UO i s plurálem.
11. **U nové pasti: zapiš ji sem i do `LESSONS.md`** — příští session ji jinak
    objeví znovu.

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03` §3.4 — index bloku mapy**: správně je `bx * blocks_y + by`
   (x-major), ne `by * blocks_x + bx`. `MapLoader.cs:623`.
2. **`docs/03` §3.4 — záznam statiky**: `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`
   (7 B), ne `[u16][u16][u16][i8]`.
3. **`docs/03` §3.4 — Britain**: blok (1495,1630) má **60** statiků (ne 20).
4. **`docs/03` §3.5.4 — R1/R2/R3**: uzavřeno měřením (`create_hash` 43 760/43 760;
   všech 5 579 gumpů má flag 3 = zlib **+ BWT**; 112 chunků = celý svět).
5. **`docs/03` §3.3.1 — „LAND blok: offset 4"**: je to offset prvního *záznamu*.
6. **`docs/03` §3.5.1 — doporučení „UOP, MUL jako fallback"**: **naměřeno obráceně**
   (viz `research/anim-mereni.md`); text v `docs/03` je už opravený a
   `research/05-data-formats.md` §5.2 má místo variant výsledek měření.
7. **`.forge/roadmap.json` — `size_lines` nesedí u 16 z 26 souborů** (viz „Otevřené věci" 1).
8. **`app/main.tscn` nemá vlastníka** v roadmapě.
9. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; skutečné soubory jsou `assets/uo/tiles.json`
   a `data/items.json` (viz „Otevřené věci" 3).
10. **`docs/06 §6.2` uvádí 6 nástrojů, které v této instalaci NEJSOU**:
    `skillet` (je `frypan`), `flour mill` (je `millstone`), `spinning wheel`,
    `loom`, `oven`, `bellows`. Patří to do `docs/` jako měření, ne do kódu
    jako hardcodované jméno.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (docs/02 §2.6.8).
- Píšu **jen do `owns`** své granule; `tests/`, `tools/gates/`,
  `project.godot`, `.forge/`, `docs/` needituju (výjimkou jsou bootstrap granule).
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py` vrací 0 = vše změřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není
  zelená). `--strict` dělá z NEMĚŘENO vadu (pro M8).
- Testy potřebují `APPDATA` ve workspace, jinak `user://` míří mimo:
  `$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"`.
