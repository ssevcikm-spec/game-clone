# Předání — UO-klon (stav po `render.sort`: první soubor v `render/`, G10 poprvé měří)

> Tento soubor je pro **další session agenta**. Všechno podstatné je v repu
> a v `git log`; tady je jen to, co by jinak stálo hodiny znovuobjevování.
> Datum: 2026-10-04. Zjištění o odemčení W1 (`tiledata --extract` → `data.items`
> → `world.tiledata`) **platí dál**.
> **Poslední session udělala granuli `render.sort`** (`render/sort.gd`).
> Předchozí (`data.recipes`, `data.gen_content`) stále platí.

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
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes]` |
| Testy | `godot --headless --path . --script res://tests/run_tests.gd` → **238 kontrol / 0 selhání** (znovu naměřeno 2026-10-04) |
| Brány | `python tools/gates/run-all.py` → **9 měřeno / 1 NEMĚŘENO / 1 chyba, exit 1** (znovu naměřeno 2026-10-04, viz níže — **změna proti minulému předání**) |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 celkem (10 bran + 9 extrakčních nástrojů), 0 chyb** (znovu naměřeno 2026-10-04) |
| Sonda `render.sort` | `.cache/analysis/probe-sort.gd` (gitignore) → **21 kontrol / 0 selhání** |
| Mutace sondy | `.cache/analysis/mutace-sort.py` → **7 z 7 mutací spadlo** |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` (101 granul; `done` je u všech `false` — stav se pozná jen měřením) |
| Data z instalace | `assets/uo/` (gitignore) — **`tiles.json` 2 405 685 B** (land 16 384, item 65 536) |

## Co je hotové a ověřené (ne „soubor existuje")

bootstrap 4 · W0 8 · M0 5 · M1 8 (**uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc**) · M2 4 (world.doors, world.stairs, entity.stats, world.time) ·
assets.anim 1 · `data.items` 8 748 záznamů · `world.tiledata` · `world.map` ·
`data.gen_content` — `tools/gates/gen-content.py` · `data.recipes` (1053 receptů)
· **`render.sort` (`render/sort.gd`)**.

**Poslední session (2026-10-04, `render.sort`):**

- **`render/sort.gd`** — **60 řádků** proti deklarovaným `<= 60`, jediná funkce
  řazení kreslení. Smlouva z roadmapy: `sort_key(obj) -> int`,
  `draw_order(objects) -> Array`.
  Klíč je **jedno číslo**: `((x + y) * 3 + vrstva) * 256 + (z − Z_MIN)`,
  vrstvy `land` 0 / `static` 1 / `mobile` 2 (`item` = předmět na zemi jde s
  mobily). Pořadí je **stabilní** (poradí vstupu jako třídící klik), `z` se
  **svěruje** do `Z_MIN..Z_MAX` (jinak objekt přeběhne o celé diagonály),
  neznámý `kind` se kreslí jako mobilní a vyvolá **jedno varování** (ticho by
  byla zelená nad vadou).
- **Pořadí je potvrzené dvěma nezávislými zdroji**: `docs/02 §2.4` (hlavní klíč
  `x + y`, `z` až v rámci diagonály) a `research/05 §8.2` (ClassicUO
  `View.CalculateDepthZ`: `depth = (x + y) + (127 + z) * 0.01`). Rozdíl: UO
  škáluje `z` desetinně a shody řeší `>=` (pořadí v seznamu) — u nás
  diagonály odděluje celočíselná základna, takže `z` nikdy nepresáhne na další.
- **Ověření (sonda, ne test):** `.cache/analysis/probe-sort.gd` →
  **21 kontrol / 0 selhání**, exit 0. Kontroly jsou z **pravidel v `docs/02 §2.4`**,
  ne z toho, jak je kód napsaný: přijímací kritérium granule (dva statiky na
  jedné dlaždici s různým `z`), vrstva land → statics → mobiles, diagonala
  `x + y`, stabilita na **1000** shodných klíčů, determinismus, `z` mimo rozsah,
  shoda `sort_key` a `draw_order`, a **reálná data**: blok 8×8 v Britainu =
  **64 dlaždic + 3778 statik = 3842 objektů**, land před statikami, statiky podle `z`.
- **Mutační test — 7 z 7 spadlo:** vrstvy prohozeny · `z` descendo · diagonála
  `x−y` · bez svěření `z` · nestabilní řazení · špatný základ vrstev (`LAYERS 2`) ·
  `z + Z_MIN` místo `z − Z_MIN`. Každá mutace se navíc **ověřila na disku** (sha
  + `stare not in mutant`), aby „spadlo“ nebylo „mutace se neprovedla“.
  **Tři z nich prošly poprvé** a odhalily, že kontrola je slabá — viz
  `LESSONS.md` (stabilita na 3 prvcích; přenos mezi poli u složeného klíče).
  Jedna z nich (`z + Z_MIN`) odhalila **nepravdivé tvrzení v mém komentáři**
  (`sort_key` není použitelné jako `z_index`, Godot bere jen ±4096) — opraveno.
- **Sonda není test.** `tests/` needituje člověk (`docs/09 §9.5`); `render.sort`
  **nemá test v `tests/cases/`** — viz otevřené věci č. 2.
- **Kontroly po změně:** `check-docs-refs.py` **0**, `check-zadani.py` **0**,
  `roadmap-gen.py --check` **0**, testy hry **238/0**, self-testy bran **19/19**.

### ⚠ `run-all.py` dnes vrací **exit 1** — a to je pravda, ne regrese

`9 měřeno / 1 NEMĚŘENO (G9) / 1 chyba (G10)`, exit 1. Před touto session bylo
`9 / 2 / 0`, exit 2. Rozdíl je celý v **G10**:

| bráňa | před | teď | proč |
|---|---|---|---|
| G10 `check-render` | **NEMĚŚENO** „`render/` neobsahuje žádný `.gd`“ | **VADA** „snímek je jednolitý — nic se nevykreslilo“ | vznikl první soubor v `render/`, takže brána poprvé **změřila pixely** |

Snímek, který G10 měří, je `.cache/render/snapshot.png` — **stará artefakt z
2026-10-02 19:24** (uniformní `(77,77,77)`, 1280×720; v téže složce leží
`frame*.png` a `frame.wav` po Movie Makeru z bootstrapu). Brána kontroluje jen
`exists()`, **ne stáří**, takže dnes měří čtyři dny starý prázdný obrázek.

**Červená je pravdivá** („na obrazovce nic není“ — renderer v repu zatím
neexistuje), ale **nejde o vadu `render/sort.gd`** a neopraví se přejmenováním
nebo smazáním souboru. Otočit ji na zelenou může až `render.chunk` +
`render.textures` + `assets.atlas`, které skutečně něco nakreslí. **Nemaž ten
snímek** a nehledej chybu ve svém kódu — viz otevřené věci č. 4 a 5.

**Předchozí session (2026-10-04, `data.recipes`):**

- **`tools/gates/gen-content.py` má generátor `recipes.json`** (585 410 B,
  1053 receptů z `research/04-craft-data.json`, 11 řemesel).
  Záznam má `id, skill, type, min_skill, max_skill, result, materials,
  use_all_res, era, source, group`; `result`/`materials` mají `tile` jen když se
  jméno přeložilo.
- Výsledek má `tile` **354 z 1053**, materiál **1035 z 1696**; nevyřešených
  referencí **1360** jde do `assets/uo/content-report.json`.
- `--only recipes --check` **exit 0**, sha256 `8759e697cefc0d0e…`.
- G5: `recipes.json: tvar seznam, záznamů 1053`, křížové odkazy **1389 vyřešeno,
  0 chyb**.

## Nová rozhodnutí, která jsem musel udělat

1. **Tvar objektu pro `sort_key` — smlouva ho nepínuje.** `docs/04 §4.2` má jen
   řádek „**jediná** funkce řazení“, `docs/02 §2.4` popisuje pořadí, ale
   **žádný tvar objektu**. Zvolil jsem
   `{"kind": "land"|"static"|"mobile"|"item", "x": int, "y": int, "z": int}`
   a zapsal to do hlavičky souboru (stejně jako `sim_world.gd` zapisuje své
   mezery). `docs/` agent nemění (`docs/09 §9.10.7`) — **patří do zadání pro
   člověka**: doplnit tvar do tabulky `render` v `docs/04 §4.2`.
2. **`item` (předmět na zemi) jde do vrstvy s mobily.** V UO je předmět na zemi
   v jednom kreslicím seznamu s mobily (`research/05 §8.2`); `docs/02 §2.4`
   píše jen „land → statiky → mobilové“. Nešlo o to vymyslet 4. vrstvu.
3. **`z` se svěruje do `Z_MIN..Z_MAX`.** Bez toho by `z` mimo rozsah (např.
   `z_at()` mimo mapy vrací `-1`) posunul objekt o celé diagonály. Otestováno
   mutací „bez svěření z“.
4. **Špatný základ vrstev (`LAYERS 2`) je past, ne kosmetika.** Mobilní na
   diagonále `d` by měl stejný klíč jako land na `d+1`. Prošlo to při testu na
   jedné dlaždici — viz `LESSONS.md`.
5. **Proměnnou `layer` jsem nepřejmenoval, aby brána nehlásila falešné zapojení.**
   `check-wiring.py` hledá jméno slovem, takže lokální `layer` v `render/sort.gd`
   nechal zmizet `world.tiledata.layer` ze seznamu mrtvého kódu (26 → 25,
   změřeno odložením souboru). Kód je správný, chyba je v nástroji — patří do
   `tools/gates/check-wiring.py`.
6. **`sand` (tile 9310) zůstává v `items.json`**, `tile` = tiledata item id bez
   `+0x4000` (rozhodnutí z předchozích session, platí dál).

## Otevřené věci a co je potřeba dodělat

0. **`recipes.json` potřebuje rozhodnutí uživatele** (z předchozí session, stále
   otevřené): 1360 nevyřešených referencí je **obsah pozdních eras**, ne chyba
   párování. Dnes je varianta (a) — nechat to a filtrovat `era` až ve hře;
   každý nevyřešený odkaz je vidět v `assets/uo/content-report.json`.
1. **`render.sort` nemá test v `tests/cases/`** — stejná mezera jako u
   `data.items` a `data.recipes`. Sonda v `.cache/analysis/` měří, ale **v čerstvém
   klonu ji nikdo nespustí**. Kandidát na první případ: „dva statiky na jedné
   dlaždici s různým `z` vyjdou v pořadí podle `z`“ + to, co dnes drží mutace
   (stabilita na shodných klíčích, přenos mezi poli u `LAYERS`).
2. **`size_lines` nesedí u 17 z 27 dosavadních souborů** (`gen-content.py` ho
   zvýšil na **18 z 28**). `render/sort.gd` je **60/60**, tedy sedí.
   **Je to rozhodnutí pro uživatele:** uvolnit deklarace, nebo dělit granule —
   `docs/09 §9.2`. Brána to neměří, je to tichá regrese plánování.
   **Pozor na metriku:** `Measure-Object -Line` nepočítá prázdné řádky;
   `size_lines` se měří všemi řádky (Python `splitlines()`).
3. **Tvar objektu pro `render.sort` patří do `docs/04 §4.2`** (viz rozhodnutí 1).
   Dokud tam není, kdokoliv implementuje `render.chunk` bude vymýšlet objekt
   znovu — a to je přesně to, co `docs/09 §9.3` zakazuje.
4. **G10 potřebuje snímek z běhu a kontrolu stáří.** Dnes měří artefakt
   z bootstrapu (viz výše). Patří do `tools/gates/check-render.py` a do `app/`:
   snímek musí vznikat při běhu hry a brána musí odmítnout stará data
   (`docs/08 §8.3` — „brána, která nemá jak selhat“). Agent `tools/gates/`
   nemění.
5. **13 generátorů v `POZADAVKY` chybí** — `weapons.json`, `armor.json`,
   `spells.json`, `item_properties.json`, `monsters.json`, `spawns.json`,
   `vendors.json`, `regions.json`, `moongates.json`, `dungeons.json`,
   `professions.json`, `skills.json`, `balance.json`.
6. **Pixely animací** (z minulého handoffu, **platí dál**): tvar hlavičky framu a
   kódování indexů v RLE proudu jsou neověřené. Zdroj je rozhodnutý měřením:
   **blok v MUL → MUL, jinak UOP**.
7. **`assets.uop` (2 rozpory k rozhodnutí testem)** a **`assets.atlas`/
   `assets.verify`/`assets.extract_cli`** nejsou hotové — bez `atlas.py` není
   `manifest.json`, takže G6 je v části atlasu slepá a `render.textures` nemá
   z čeho číst.
8. **Staré poznámky v `tools/uoextract/worldmap.py` (10–11, 60–63, 87–90) jsou
   zastaralé** — tvrdí, že `docs/03 §3.4` uvádí špatné pořadí bloku a špatné
   šířky polí. `docs/03` je opravený (§3.9.1) a kód `struct.unpack_from("<HBBbH")`
   je správný. Není to vada kódu, ale člověk, který to čte, se zbytečně bojí.

## Další kroky (v tomto pořadí)

1. **`assets.atlas`** (`tools/uoextract/atlas.py`, `strong`, `<= 150`) — tím se
   zapne G10 v části manifestu a vznikne `manifest.json`, bez kterého
   `render.textures` nemá z čeho číst.
2. **`render.textures`** (`render/texture_cache.gd`, `<= 60`) — cache z manifestu.
3. **`render.chunk`** (`render/chunk_renderer.gd`) — první věc, která **něco
   nakreslí**, a tím otočí G10 ze žluté na zelenou. Až tehdy bude
   `render.sort` zavolaný z produkce (dnes G4 hlásí `sort_key` i `draw_order`
   jako „čeká na integraci“ — to je správně, `acceptance` granule `wiring`
   nežádá).
4. **`tests/cases/` pro `render.sort`** a pro data (`items.json`, `recipes.json`) —
   mezera č. 1. Psát ho má člověk; v zadání stojí, co musí držet.

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje“ ani `done: true`
  v roadmapě nic neznamená.
- **Mutační test je to, co odlišuje měření od dojmu.** Z 7 mutací mi **tři
  prošly** a každá ukázala jinou slabost kontroly (stabilita malého seznamu,
  přenos mezi poli, nepravdivý komentář). Bez nich bych do předání napsal
  „7 kontrol prošlo“ a byl bych o tři kontroly chudší.
- **Mutace se musí ověřit, že se provedla** (sha textu + `stále not in mutant`),
  jinak „spadlo“ a „neprovedlo se“ vypadají stejně.
- **Nástroj, který vyrábí data v gitu, musí reprodukovat data.**
- **Vedlejší výpis (ukázky, souhrny) nesmí změnit kód měření.**
- **Dívat se na data, ne na počty.** 3842 objektů z jednoho bloku mapy je
  lepší důkaz řazení než syntetická trojice objektů.
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA.**
- **Binární formát ověř dvěma implementacemi.**
- **Když implementace odhalí díru ve smlouvě, napiš ji do hlavičky souboru
  stejně jako `sim_world.gd`** a zaznamenej jako otevřenou věc — `docs/`
  agent nemění.

## Pasti, které už někoho stáhly čas (naměřené)

1. **Sandbox `workspace-write` blokuje zápis do podsložek, i když je kořen
   zapisovatelný.** Podprocesy běží na `Low` a label má jen kořen workspace.
   Znovu naměřeno 2026-10-04: `Set-Content` do kořene OK, do `.cache`/`.data`
   „Access denied“. `gate_common.py:219` má `user://` Godotu natvrdo v
   `.cache/godot-appdata`, takže **G3, G7 a G11 v tomto režimu nemohou zapsat**
   a `run-all.py` spadne na `summary.json`. Pro **Godot testy** stačí
   `$env:APPDATA` do adresáře **přímo pod kořenem** (label se dědí) — pak
   běží. Na brány nepomůže, ty si cestu píšou samy. Řešení pro celou práci:
   session na **plný přístup**.
2. **`map0.land` má na každém bloku 4B hlavičku** — čti od `key * 196 + 4`.
3. **Godot s nerozjetým skriptem visí, ne selže** — `Parse Error` → prázdná
   smyčka, proces s 0,05 s CPU. Každý `--script` běh spouštěj **s `--quit-after N`**
   a výstup **přesměruj do souboru** (`| Out-File`).
4. **`.uid` vzniká jen při `godot --headless --path . --import`**, ne při testech
   a ne při branách — a **patří do gitu** (`git ls-files` → 36 `.uid`).
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
13. **Hledání podřetězcem u jmen předmětů vybírá smetí** (`log` → `log wall`).
14. **Python bez `$env:PYTHONIOENCODING='utf-8'` padá na českém výstupu**
    (`UnicodeEncodeError`, konzole cp1252).
15. **`check-wiring.py` hledá jméno slovem, ne voláním** — lokální proměnná
    `layer` nechala zmizet `world.tiledata.layer` ze seznamu mrtvého kódu.
16. **Uměřený soubor musí mít stáří** — `check-render.py` hlásí „nic se
    nevykreslilo“ ze snímku starého čtyři dny.
17. **Při editaci cizího dokumentu hledej, jestli jsi nesmazal jeho nadpis.**
    (Dnes: `edit` v `LESSONS.md` smazal hlavičku záznamu „Recepty…“; našel jsem
    to čtením, ne pamětí.)

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03 §3.4` — index bloku mapy**: už opraveno na `bx * blocks_y + by`.
2. **`docs/03 §3.4` — záznam statiky**: už opraveno na `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
3. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; skutečné soubory jsou `assets/uo/tiles.json`
   a `data/items.json`.
4. **`docs/04 §4.2` u `world.map` nerozlišuje `tiledata id` a `art id`** u statiků:
   soubor v této instalaci ukládá **id bez `+0x4000`** (naměřeno 37…4758).
5. **`docs/04 §4.2` u `render.sort` neuvádí tvar objektu** — viz rozhodnutí 1.
6. **`docs/06 §6.2` uvádí 6 nástrojů, které v této instalaci NEJSOU**:
   `skillet` (je `frypan`), `flour mill` (je `millstone`), `spinning wheel`,
   `loom`, `oven`, `bellows`. Navíc `clean bandage` a `blank scroll` v tiledata
   nejsou pod zadaným jménem (naměřeno v `content-report.json`).
7. **`.forge/roadmap.json` — `size_lines` nesedí u 18 z 28 souborů** (viz
   otevřené věci č. 2). **Brána to neměří.**
8. **`app/main.tscn` nemá vlastníka** v roadmapě.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (docs/02 §2.6.8).
- **Nečeské znaky (í, š, ň) nepatří do identifikátorů** — GDScript je neumí.
- Pišu **jen do `owns`** své granule; `tests/`, `project.godot`, `.forge/`,
  `docs/`, `assets/uo/` needituju. (`tools/gates/` patří bránám, ale
  `data.gen_content` ho vlastní — viz `.forge/roadmap.json`.)
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py` vrací 0 = vše změřeno, 1 = vada, **2 = něco NEMĚŚENO** (to není
  zelená). `--strict` dělá z NEMĚŘENO vadu (pro M8). Stejné kódy má teď
  `gen-content.py`.
- Testy potřebují `APPDATA` ve workspace, jinak `user://` míří mimo:
  `$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"`.
  **Brány si to nastavují samy** (`tools/gates/gate_common.py:219`).
