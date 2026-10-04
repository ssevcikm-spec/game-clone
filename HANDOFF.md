# Předání — UO-klon (stav po `data.gen_content`: `items.json` má generátor v repu)

> Tento soubor je pro **další session agenta**. Všechno podstatné je v repu
> a v `git log`; tady je jen to, co by jinak stálo hodiny znovuobjevování.
> Datum: 2026-10-04. Zjištění o odemčení W1 (`tiledata --extract` → `data.items`
> → `world.tiledata`) **platí dál**.
> **Tato session udělala granuli `data.gen_content`** a znovu naměřila testy,
> brány i self-testy.

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
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items]` |
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
assets.anim 1 · `data.items` 8 748 záznamů · `world.tiledata` · `world.map` ·
**NOVĚ `data.gen_content` — `tools/gates/gen-content.py`**.

**Tato session (2026-10-04):**

- **`tools/gates/gen-content.py`** (349 řádků / 303 neprázdných) — generátor
  `data/*.json` podle `docs/06 §6.1`. Tabulka `POZADAVKY` má **15 cílů** se
  zdrojem; zabudovaný je zatím **jen `items.json`**, ostatní se hlásí jako
  `NEMERENO … generator chybí` (**nikdy** jako hotové) a jdou do
  `assets/uo/content-report.json`.
- **Reprodukuje data beze změny:** `--only items --check` → **exit 0**,
  `items.json` **sha256 `f6c9a6122fcb17127…`** = ta, která je v gitu od
  `data.items`. Shodu jsem navíc ověřil **porovnáním se starým skriptem**
  (`.cache/analysis/gen-items.py`, gitignore): 8748 záznamů, jediný rozdíl byl
  `sand`, který jsem v nové verzi omylem vynechal — opraveno, viz `LESSONS.md`.
- **Mutační test:** změna 1 bajtu → **exit 1** (`na disku je jiná verze`);
  prázdné `{}` → **exit 1**; po opravě `git status` čistý.
- **Návratové kody** (0 ok / 1 vada / **2 = něco neměřeno**, stejně jako brány):
  plný `--check` → **2** (14 generátorů chybí), `--only items` → **0**,
  `--only xyz` (neznámý cíl) → **1**.
- **`assets/uo/content-report.json`**: po plném běhu `unresolved: 2`
  (`clean bandage`, `blank scroll` — v tiledata nejsou pod tím jménem),
  `bez_generatoru: 14`. Dílčí `--only` běh hlavní report **nepřepisuje**
  (jde do `.cache/gen-content/`).
- Kontroly po změně: `check-docs-refs.py` **0**, `check-zadani.py` **0**,
  `roadmap-gen.py --check` **0**, `run-all.py` **9/2/0 (exit 2)**,
  `--self-test` **19/19**, Godot testy **238/0**.

## Nová rozhodnutí, která jsem musel udělat

1. **`sand` (tile 9310, váha 255 = statika) zůstává v `items.json`.** Původní
   generátor měl mrtvou sadu `SUROVINY_VYLOUCENE = {"sand"}`. Generátor musí
   data reprodukovat; oprava dat je zvláštní krok u granule `data.items`.
2. **`items.json` má `tile` = tiledata item id** (bez `+0x4000`) — stejně jako u
   `world.map`; rozhodnutí je popsáno v `LESSONS.md` a v hlavičce
   `gen-content.py`.
3. **Generátor sdílí kódové konstanty s branami** (`gate_common.ROOT/OK/VADA/
   NEMERENO`), ačkoliv není brána — jinak by měl jiné návratové kody než
   `run-all.py`, a to je past, kterou člověk čte jako chybu.

## Otevřené věci a co je potřeba dodělat

1. **14 generátorů v `POZADAVKY` chybí** — `recipes.json`, `weapons.json`,
   `armor.json`, `spells.json`, `item_properties.json`, `monsters.json`,
   `spawns.json`, `vendors.json`, `regions.json`, `moongates.json`,
   `dungeons.json`, `professions.json`, `skills.json`, `balance.json`.
   Nejblíž je `data.recipes`: `research/04-craft-data.json` (539 920 B,
   slovník skill → 6 klíčů) už existuje, chybí mapování na `tile` v `items.json`
   a zbytek 12 má zdroje jen v markdownu `research/03`/`research/06`.
2. **`data.items`, `world.tiledata` i `world.map` nemají test v `tests/cases/`** —
   stejná mezera jako předtím. Sonda v `.cache/analysis/` není test; ve
   **čerstvém klonu** ji nikdo nespustí. `gen-content.py --check` kryje jen
   idempotenci, ne správnost dat.
3. **`size_lines` nesedí u 17 z 27 dosavadních souborů** (stav převzatý z
   minulého předání; `gen-content.py` ho zvýšil na **18 z 28** — 349 řádků proti
   deklarovaným `<= 150`). **Buď uvolnit deklarace, nebo dělit granule** —
   `docs/09 §9.2`. **Je to rozhodnutí pro uživatele.**
   **Pozor na metriku:** `Measure-Object -Line` nepočítá prázdné řádky;
   `size_lines` se měří všemi řádky (Python `splitlines()`).
4. **Pixely animací** (z minulého handoffu, **platí dál**): tvar hlavičky framu a
   kódování indexů v RLE proudu jsou neověřené. Zdroj je rozhodnutý měřením:
   **blok v MUL → MUL, jinak UOP**.
5. **`assets.uop` (2 rozpory k rozhodnutí testem)** a **`assets.atlas`/
   `assets.verify`/`assets.extract_cli`** nejsou hotové — bez `atlas.py` není
   `manifest.json`, takže G6 je v části atlasu slepá a `render.textures` nemá
   z čeho číst.
6. **Staré poznámky v `tools/uoextract/worldmap.py` (10–11, 60–63, 87–90) jsou
   zastaralé** — tvrdí, že `docs/03 §3.4` uvádí špatné pořadí bloku a špatné
   šířky polí. `docs/03` je opravený (§3.9.1) a kód `struct.unpack_from("<HBBbH")`
   je správný. Není to vada kódu, ale člověk, který to čte, se zbytečně bojí.

## Další kroky (v tomto pořadí)

1. **`data.recipes`** — první chybějící generátor v `gen-content.py`. Zdroj
   (`research/04-craft-data.json`) je v repu; potřeba rozhodnout mapování
   názvů na `tile` (křížový odkaz musí sednout, jinak G5 `check-content` hlásí
   `odkazuje na tile X, který není v items.json`).
2. **`render.sort`** (`render/sort.gd`, `any`, `<= 60`) — DAG splněný: závisí na
   `core.iso` + **`world.map` (hotový)**. Smlouva: `sort_key(obj) -> int`,
   `draw_order(objects) -> Array`; pořadí land → statiky podle z → mobilové podle z,
   dlaždice podle `(x+y)` (`docs/02 §2.4`, past P21).
3. **`assets.atlas`** (tím se zapne G10, které je teď NEMĚŘENO), pak
   **`render.textures`** — až po `manifest.json`.

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Nástroj, který vyrábí data v gitu, musí reprodukovat data.** Nejdřív
  shoda bajtů s tím, co je commitnuté; pak teprve úpravy (a to jako samostatný
  krok s viditelným diffem dat).
- **Návratový kód musí říct, co se změřilo**: 2 = „něco neměřeno“ u
  `--check` celého seznamu je správný stav, ne selhání.
- **Vedlejší výpis (ukázky, souhrny) nesmí změnit kód měření** — viz dva
  záznamy v `LESSONS.md` z této session.
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA** —
  `depends_on` znamená „hotové a funkční", ne „jméno existuje v DAGu".
- **Binární formát ověř dvěma implementacemi.** Rozsahová kontrola je slabá
  brána: chybný posun o 4 B v `map0.land` dával plausibilní `z` v `-128..127`.
- **Dívat se na data, ne na počty.** 1126 „zbraní" vypadalo jako úspěch;
  teprve výpis jmen ukázal, že jsou to helmy. Každý generátor ať **vypíše ukázky**.
- **Mutační test u každé brány, sondy i nové funkce** (otoč vztah → musí spadnout).
- **Dokumentovaná tabulka není důkaz** — každé číslo ověř na datech.

## Pasti, které už někoho stáhly čas (naměřené)

1. **Sandbox `workspace-write` umí zakázat zápis i DO workspace** a vypadá to jako
   vada ukládání. Přesná příčina: `workspace-write` pouští podprocesy jako
   **Low integrity**, a Low proces nesmí zapsat do objektu **bez Low labelu**.
   Naměřeno 2026-10-04 znovu: label má **jen kořen workspace**, podsložky `sim/`,
   `tools/`, `.cache/`, `data/`, `assets/` **nemají** → `PermissionError` při zápisu
   do `data/items.json` i do `$env:TEMP` (takže „napiš si do tempu“ taky nejde).
   **Postup:** změř label (`icacls <cesta> | findstr Mandatory`), a když chybí,
   přepni session na plný přístup; skript `diagnose-windows-sandbox-acl` spraví
   DACL, ne label.
2. **`map0.land` má na každém bloku 4B hlavičku** — čti od `key * 196 + 4`.
3. **Godot s nerozjetým skriptem visí, ne selže** — `Parse Error` → prázdná
   smyčka, proces s 0,05 s CPU. Každý `--script` běh spouštěj **s `--quit-after N`**
   a výstup **přesměruj do souboru** (`| Out-File`).
4. **`.uid` vzniká jen při `godot --headless --path . --import`**, ne při testech
   a ne při branách. Po každém novém `.gd` ho zkontroluj v `git status`.
5. **Godot z `C:\...\orchestra\tools\godot` NEMŮŽE ZAPISOVAT** (sandbox) a přitom
   lže `err=0`. Řešení: kopie ve workspace (`.cache/godot/`, gitignore).
6. **`JSON.parse_string` vrací VŠECHNA čísla jako `float`** — u int64 stavu RNG
   to tiše poškodilo data. Vždy `int()`; hodnoty > 2^53 jako řetězec.
7. **`.gitignore` je na Windows case-insensitive** — vzor `Cliloc.*` pohltil
   `tools/uoextract/cliloc.py`. Kontroluj `git ls-files`, ne `Test-Path`.
8. **`Measure-Object -Line` nepočítá prázdné řádky** — počty řádků měř Pythonem
   (`splitlines()`).
9. **Brána, která nic nezměří, není zelená** — `run-all.py` vrací 2 = NEMĚŘENO.
10. **Zápis „mezi tím" do souboru, který čte jiný běh, vypadá jako změna souboru**
    — `write` pak odmítne zápis; soubor znovu přečti a zapiš znovu.
11. **Statická kontrola musí číst kód, ne komentáře — i ta tvoje vlastní.**
12. **`& skript.ps1` na této stanici neprojde** (`running scripts is disabled`).
13. **Hledání podřetězcem u jmen předmětů vybírá smetí** (`log` → `log wall`,
    `loom` → `Bloom Firework`, `pan` → `pants`). Hledej přesně, u UO i s plurálem.
14. **Python bez `$env:PYTHONIOENCODING='utf-8'` padá na českém výstupu**
    (`UnicodeEncodeError`, konzole cp1252) — a to i při čtení `.forge/roadmap.json`.
15. **U nové pasti: zapiš ji sem i do `LESSONS.md`** — příští session ji jinak
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
   `loom`, `oven`, `bellows`. Navíc `clean bandage` a `blank scroll` v tiledata
   nejsou pod zadaným jménem (naměřeno v `content-report.json`).
6. **`.forge/roadmap.json` — `size_lines` nesedí u 18 z 28 souborů** (viz bod 3
   otevřených věcí). **Brána to neměří** — je to tichá regrese plánování.
7. **`app/main.tscn` nemá vlastníka** v roadmapě.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (docs/02 §2.6.8).
- **Nečeské znaky (í, š, ň) nepatří do identifikátorů** — GDScript je neumí.
- Pišu **jen do `owns`** své granule; `tests/`, `project.godot`, `.forge/`,
  `docs/`, `assets/uo/` needituju. (`tools/gates/` patří bránám, ale
  `data.gen_content` ho vlastní — viz `.forge/roadmap.json`.)
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py` vrací 0 = vše změřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není
  zelená). `--strict` dělá z NEMĚŘENO vadu (pro M8). Stejné kódy má teď
  `gen-content.py`.
- Testy potřebují `APPDATA` ve workspace, jinak `user://` míří mimo:
  `$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"`.
  **Brány si to nastavují samy** (`tools/gates/gate_common.py:219`).