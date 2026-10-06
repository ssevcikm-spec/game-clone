# Předání — UO-klon (stav po auditu 2026-10-06, práce z 10-04 je necommitnutá)

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ.md`** (založeno 2026-10-06
> auditem, který neměnil kód). Tenhle soubor říká, **kde jsme**; tamten, **co dělat**.
> **Datum:** 2026-10-06. **Poslední změna kódu:** 2026-10-04 22:52 (commit
> `3e7864c`), **poslední zápis do stromu:** 2026-10-04 23:28.

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

## ⚠⚠ DVA BLOKÁTORY, KTERÉ JE POTŘEBA VYŘEŠIT PRVNÍ

1. **CI na GitHubu NEBĚŽÍ — a není to chyba kódu.** Push 2026-10-06 dorazil
   (`819c9a3..7a4f3e7`, `ahead 0`), ale oba běhy workflow skončily **okamžitě
   s `failure`, 0 jobů a 0 check-runs** (run #1 `2026-10-03T12:45:32Z` nad
   `819c9a3`, run #2 `2026-10-06T10:59:54Z` nad `7a4f3e7`; u #2 je
   `created_at == updated_at`). **Žádný krok workflow se nikdy nespustil** —
   neproběhl ani download Godotu, takže `UNVERIFIED` URL a SHA v `ci.yml`
   zůstávají neověřené. Podpis „běh selhal bez jobů" je na GitHubu typicky
   **vyčerpaná kvóta minut u privátního repa** (repo je `private: true`;
   ověřeno tokenem) — billing API token nevidí, takže **příčinu je potřeba
   potvrdit v UI** (Settings → Billing → Actions). **Co s tím:** zkontrolovat
   kvótu, a pokud je vyčerpaná, rozhodnout se mezi placenými minutami
   a **zveřejněním repa** (public repo má minuty zdarma; v gitu jsou jen kód
   a dokumentace — `assets/uo/` je gitignore, autorská díla UO tam nejsou).
2. **`tools/uoextract/atlas.py` je v gitu, ale má vadu** (commit `7a4f3e7`).
   Vygeneroval `assets/uo/manifest.json` (3 565 629 B, 17 436 spritů, 198 stran),
   ve kterém je **117 překryvů** spritů a **17 jich je plně průhledných**
   (item 4410 a další). Podrobně „Otevřené věci" č. 9.

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Zadání pro další vývoj** | **`ZADANI-DALSI-VYVOJ.md`** (naměřená cesta k obrazovce, zapojení bez vlastníka) |
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| Projekt | `E:\Workspaces\game-clone` (git, `main`; **`origin/main` = `HEAD`** od 2026-10-06) |
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes]` |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` → **238 kontrol / 1 selhání** |
| Brány | `python tools/gates/run-all.py` → **5 měřeno / 2 NEMĚŘENO / 4 chyba, exit 1** (2026-10-06 — **jiné číslo než minule, viz „Co brány dnes měří"**) |
| Self-testy bran | `python tools/gates/run-all.py --self-test` |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable.official.ed1daf0bf) |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení; `tiledata.mul` je tam, `map0.mul` **ne** — mapa je v `map0LegacyMUL.uop`) |
| Roadmapa | `.forge/roadmap.json` — **101 granul, `done` je u všech `false`** a klíč `done_note` neexistuje: stav se pozná **jen měřením** |
| Data z instalace | `assets/uo/` (gitignore) — `tiles.json` 2 405 685 B, `manifest.json` 3 565 629 B, `world/map0.land` 89 915 392 B, `world/map0.statics.bin` 20 386 415 B |
| Snímek pro G10 | `.cache/render/snapshot.png` — **artefakt z 2026-10-02 19:24**, jedna barva (77,77,77) |

## Stav kódu (počty řádků Pythonem `splitlines()`, bez `.uid` a `__pycache__`)

| složka | souborů | řádků | poznámka |
|---|---|---|---|
| `core/` | 7 | 339 | hotové a otestované (0 souborů bez testu) |
| `sim/` | 8 | 929 | **`systems` je prázdné — plní ho jen testy** |
| `render/` | **1** | **60** | jediný `sort.gd`; plán má 7 granul. `ui/` **neexistuje vůbec** |
| `app/` | 4 | 225 | `main.gd` jen spustí sim; **`input_map` se nikdy nepřidá do stromu** |
| `tests/` | 16 | 1 047 | 14 case souborů, **všechny s asserty** |
| `tools/uoextract/` | 38 | 5 753 | 12 produkčních + 26 jednorázových experimentů |
| `tools/gates/` | 17 | 3 210 | 10 bran + `run-all.py`, `gen-content.py`, `gate_common.py` |

**Hotové granule: 31 v předání + 5, které předání neuvádělo** = `app.main`,
`app.loop`, `app.input`, `sim.commands`, `sim.world_loop` (soubory jsou v gitu
i s testy). **M0 je tím pádem hotové celé (17/17), ne 12/17.** Zbývá **64 granul**.
Hotové soubory přetékají deklaraci u **21 z 31** (faktor ~1,45).

## Co je hotové a ověřené (ne „soubor existuje")

**M0 celek** · **W0** (8) · **M1: uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc, anim, data.items, data.gen_content, data.recipes,
world.tiledata, world.map, render.sort** · **M2: world.doors, world.stairs,
entity.stats, world.time**.

Doklady, které jsem 2026-10-06 viděl na vlastní oči (ne opsané z předání):

- **Mapa se kreslí správně** — `assets/uo/world/preview-britain.png` (4 664²)
  je skutečný isometrický Britain: cesty, budovy, řeka, tráva, dlaždice 22 px.
- **Art se dekóduje** — `.cache/analysis/atlas-preview.png` ukazuje meče, dýku,
  kožené věci, trávu. Řetěz UOP → MUL → pixely funguje.
- **Sonda mapy** `probe-map.gd`: britský blok **60 statik**, okolí ±6 bloků
  **9 329 statik**, 168 různých land id, LRW cache eviction funguje.
- **Data**: `items.json` 8 748 záznamů, `recipes.json` 1 053, atlas 17 436 spritů.
- **Hra nespadne**: `--headless --quit-after 300` → exit 0, tiká
  (`[loop] tick 20`, `tick 40`).

### ⚠ Ale na obrazovce není NIC — a to je dnešní pravda

Ověřeno třemi nezávislými měřeními: `app/main.tscn` má **jediný uzel** `Node2D`
bez potomků; grep na `_draw`/`queue_redraw`/`Sprite2D`/`CanvasItem` v celém
stromě vrací **3 nálezy a všechny jsou uvnitř `render/sort.gd`**; snímek má
**jednu barvu (77,77,77) na 921 600 pixelech**.

**Cesta ze `sim/` do renderu neexistuje.** `render/sort.gd` má **0 volajících
z produkce** — `check-wiring.json` to sám hlásí („zatím nevolané z produkce"),
spolu s **25 neintegrovanými** a **27 jen-z-testů**.

**Simulace nemá ani jednu systémovou jednotku.** `SYSTEM_ORDER`
(`sim/sim_world.gd:34-37`) vypisuje 15 systémů; `systems` je prázdný slovník
a v celém repu ho plní **jen `tests/cases/sim_world.gd:85-87`**. `move` skončí
hláškou „Not available yet: move -> movement.request_step".
**Hratelná mechanika: nula.**

## ⚠ Tři vady ZAPOJENÍ (ne chybějící soubory — chybějící volání)

Tohle nejsou granule a žádná brána je neměří. Jsou to hotové funkce, které
nikdo nevolá:

| # | Vada | Místo | Důsledek |
|---|---|---|---|
| 1 | `input_map` se **nikdy nepřidá jako dítě** | `app/main.gd:30` přidává jen `loop` | `poll()` se v produkci **nezavolá** → vstup hráče se nečte |
| 2 | `sim.systems` **plní jen testy** | `sim_world.gd:82` (čtení), `tests/cases/sim_world.gd:85-87` (zápis) | 15 systémů je jen seznam jmen |
| 3 | `time.world_time_ms` **nikdo nezapíše** | `sim/world/time.gd:23`; `SimWorld` má vlastní `_clock` | `hour()` vrací **vždy 0**; hotový `world.time` je mrtvá funkce |

Navíc: `world.doors`, `world.stairs`, `world.time` jsou hotové a otestované, ale
**nemají ani jednoho konzumenta** (`sim.movement`, `world.walk`, `sim.interaction`
neexistují). `doors.toggle(tile)` je čistá tabulková funkce `tile_id → tile_id`,
ne otevření dveří ve světě; `stairs` jen rozpozná dlaždici a `z` nezmění.

## Co brány dnes měří (a co z toho je prostředí)

`run-all.py` 2026-10-06: **5 měřeno / 2 NEMĚŘENO / 4 VADA**, `exit 1`.
**Pozor na srovnání s minulým předáním (9/2/0 a 9/1/1): počet není srovnatelný**,
protože tato session běžela v sandboxu `workspace-write`, který **neumí zapsat
do `.cache`** (`[Errno 13] Permission denied` na `summary.json` a `*.json`).

| Brána | Výsledek | Je to vada kódu? |
|---|---|---|
| G3, G7, G11 | VADA / NEMĚŘENO | **NE** — `save()` jen `user://`/`.cache`, což sandbox blokuje |
| G6 | VADA: prázdný sprite `atlas/item_10.png` | **ANO** — reálná vada atlasu, viz otevřené věci č. 9 |
| G10 | VADA: snímek je jednolitý | **ANO** — ale je to pravda o 4 dny starém artefaktu |
| G9 | NEMĚŘENO | NE — `tests/replays/` je prázdné (vlastní `boot.tests`) |

**Testy: 238 kontrol / 1 selhání** s `APPDATA` ve workspace (**6 selhání** bez
něj). To jedno je první `save()` — a je to **prostředí, ne kód**: `load()` vrátí
`true`, `test_sim_world.sav` (295 B) existuje a round-trip `state_hash` projde.
Doklad téhož podpisu: sonda mapy hlásí „NELZE ZAPSAT vystup (err 12)".

## Předletová kontrola (5 minut, než začneš psát)

| Co | Jak | Očekáváno (2026-10-06) |
|---|---|---|
| Přečtené zadání | `ZADANI-DALSI-VYVOJ.md` | cesta k obrazovce + zapojení bez vlastníka |
| Strom je čistý | `git status --porcelain -uall` | **prázdné** (od commitu `7a4f3e7`) |
| Je před GitHubem | `git rev-list --count origin/main..HEAD` | `0` |
| **Běží CI?** | `https://github.com/ssevcikm-spec/game-clone/actions` | zatím **NE** — oba běhy `failure` s **0 jobů** (viz blokátor 1) |
| Testy | testy s `APPDATA` ve workspace | `238 kontrol, 1 selhání` (prostředí) |
| Godot běží | `& .cache\godot\...exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |
| Instalace UO na místě | `Test-Path 'D:\Games\...\tiledata.mul'` | `True` |
| Kontroly zadání | `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` | `exit 0` |

## Otevřené věci a co je potřeba dodělat

**Přenáším z minulého předání (nic se nemaže) — u každé je dnešní stav:**

1. **`render.sort` nemá test v `tests/cases/`** — **PLATÍ DÁL.** Sonda
   v `.cache/analysis/probe-sort.gd` (21 kontrol) je gitignore, v čerstvém klonu
   ji nikdo nespustí. Bez testu jsou i `world/map.gd`, `world/tiledata.gd`,
   `app/main.gd`, `app/main.tscn` → **5 z 22 produkčních souborů**.
2. **`size_lines` nesedí** — **PLATÍ, a je to horší:** 21 z 31 (dřív 18 z 28).
   **Rozhodnutí pro uživatele:** uvolnit deklarace, nebo dělit granule.
3. **Tvar objektu pro `render.sort` patří do `docs/04 §4.2`** — **PLATÍ DÁL.**
4. **G10 měří snímek z bootstrapu (2026-10-02)** — **PLATÍ DÁL** (brána kontroluje
   `exists()`, ne stáří). Otočí ji až běh, který něco nakreslí.
5. **13 generátorů v `POZADOVANÉ` chybí** — **PLATÍ DÁL** (`weapons`, `armor`,
   `spells`, `item_properties`, `monsters`, `spawns`, `vendors`, `regions`,
   `moongates`, `dungeons`, `professions`, `skills`, `balance`).
6. **Pixely animací** — **PLATÍ DÁL a je to blokátor:** `manifest.json` to
   přiznává (`"pixels_decoded": false`). **Hráč (tělo 400/401) je jen v MUL** →
   bez rozluštění RLE se postava nepohne.
7. **`assets.uop` (2 rozpory) a `assets.verify`/`assets.extract_cli`** — **PLATÍ
   DÁL** pro `verify`/`extract_cli`; **`assets.atlas` je nově hotový, ale
   necommitnutý a s vadou** (viz 9).
8. **Zastaralé poznámky v `tools/uoextract/worldmap.py`** (ř. 10–11, 60–63,
   87–90) tvrdí, že `docs/03 §3.4` uvádí špatné pořadí bloku — **PLATÍ DÁL**;
   `docs/03` je opravený (§3.9.1), kód `struct.unpack_from("<HBBbH")` je správný.
9. **`atlas.py`: v gitu (`7a4f3e7`), ale s vadou v rozložení** — **NOVÉ (2026-10-06).**
   `manifest.json` má 17 436 spritů, ale **117 překryvů** na stejné poličce
   (až **27 px ze 44**) → **17 spritů je plně průhledných** (např. item 4410).
   `--self-test` přitom hlásí **„30 kontrol, 0 chyb"**, protože kontrolu překryvů
   pouští na **6 syntetických spritech** na stránce 256 px. Past „zelená, která
   nic nezměřila" — viz `LESSONS.md`. **Oprava je úkol 2 v zadání.**
10. **`docs/11 §11.6` vede O3 jako neuzavřené, `docs/03 §3.5.1` tvrdí
    „rozhodnuto měřením"** — **NOVÉ.** Vnitřní rozpor dokumentace.
11. **Počet granul se v dokumentech rozchází: 101 / 100 / 75–90** — **NOVÉ.**
    Roadmapa 101, `ZADANI` §5 i `README` píšou 100, `docs/07 §7.5` odhaduje 75–90.
12. **`ZADANI` §10 a `docs/05 §5.11` uvádějí světlo „den 12"**, `research/01 §4.2`
    má `DayLevel = 0`, `NightLevel = 12` — **NOVÉ.** Kód (`time.gd`) vrací v noci
    denní hodnotu a **přiznává to v hlavičce** jako nehotovost; vadná je
    dokumentace, ne kód. Rozhodnout lidsky.
13. **Rešerše hlásily dvě „vady", které neobstály** — **NOVÉ, jen aby se
    neopakovaly:** (a) „`manifest.json` neexistuje" — existuje, 3 565 629 B;
    (b) „`world.time` vrací noc = den, je to vada" — je to **dokumentované
    rozhodnutí** v `time.gd:12-21`. **Vada byla v dokumentaci / v rešerši, ne v kódu.**
14. **CI neproběhlo ani jednou — a příčina není v kódu** — **NOVÉ (2026-10-06).**
    Dva běhy (`#1` 2026-10-03 nad `819c9a3`, `#2` 2026-10-06 nad `7a4f3e7`),
    oba `failure` s **0 jobů, 0 check-runs a bez logů**; u `#2` je
    `created_at == updated_at`. **Ani jeden krok se nespustil**, takže
    `ci.yml` zůstává `UNVERIFIED` (URL i SHA Godotu). Podpis odpovídá
    **vyčerpané kvótě minut u privátního repa** — potvrdit v UI
    (Settings → Billing → Actions); billing API token nevidí (404).

## Už není otevřené (přesunuto, nemaže se)

- **„12 commitů není před GitHubem"** — **vyřešeno 2026-10-06**: push
  `819c9a3..7a4f3e7` dorazil, `ahead 0`.
- **„`tools/uoextract/atlas.py` není v gitu"** — **vyřešeno**: commit `7a4f3e7`
  (s poctivě popsanou vadou v commit message i tady v bodu 9).
- **„`assets.atlas` není hotový"** (minulé předání, otevřená věc č. 7) — soubor
  i výstupy **jsou**; zůstává vada v rozložení (bod 9).
- **„Další krok = `assets.atlas`"** — krok 1 minulých „dalších kroků" je hotový.
- **Podezření, že brány jsou zelené nad vadou** — v tomto režimu **nejsou**:
  4 červené, z toho 2 pravé vady (G6, G10).

## Další kroky (v tomto pořadí)

1. **Opravit rozložení v `atlas.py`** (překryvy) **a předělat self-test na
   reálný počet stránek**, ne na 6 spritů. Pak `--verify` musí dát 0 chyb.
   (Uživatel 2026-10-06 rozhodl: **atlas dřív než renderer.**)
2. **Zprovoznit CI** (nutné před orchestrou) — zkontrolovat kvótu minut
   v Settings → Billing → Actions; dokud běh neproběhne, je `ci.yml` neověřený.
3. **`render.textures`** (`render/texture_cache.gd`, ≤ 60) — cache z manifestu.
4. **`render.chunk`** (`render/chunk_renderer.gd`, ≤ 150) — **první věc, která
   něco nakreslí.** Vstupy má všechny hotové.
5. **Zapojit do scény** (kamera + `queue_redraw` + `main.tscn`) a **opravit tři
   vady zapojení** — bez toho zůstane i hotový renderer mrtvý kód. **Tohle
   nemá v roadmapě vlastníka** → patří do zadání pro člověka.
6. Pak teprve M2: `data.skills` → `entity.skills` → `entity.mobile` →
   `world.walk` → `sim.movement` (pohyb), a `tests/cases/` pro `render.sort`.

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená (`done` je u všech 101 granul `false`).
- **Mutační test je to, co odlišuje měření od dojmu** — a **mutace se musí
  ověřit, že se provedla** (sha + `stále not in mutant`).
- **Self-test na malém vstupu neprokazuje nic o velkém** (atlas: 6 spritů vs
  17 436; `render.sort`: stabilita na 3 prvcích vs 1 000).
- **Hotový soubor bez volajícího je mrtvý kód** — ptej se „kdo to volá",
  ne „existuje to".
- **Dívat se na data, ne na počty** — 3 842 objektů z bloku mapy je lepší důkaz
  než syntetická trojice.
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA.**
- **Když implementace odhalí díru ve smlouvě, napiš ji do hlavičky souboru**
  (jako `sim_world.gd` a `time.gd`) a zaznamenej jako otevřenou věc —
  `docs/` agent nemění.

## Pasti, které už někoho stáhly čas (naměřené)

1. **Sandbox `workspace-write` blokuje zápis do podsložek** — kořen zapisovatelný
   je, `.cache`/`.data` ne (Low integritní label). Důsledek: G3/G7/G11 nemohou
   zapsat, testy hlásí `save=false`, `run-all.py` spadne na `summary.json`.
   **Řešení pro celou práci: session na plný přístup.**
2. **`map0.land` má na každém bloku 4B hlavičku** — čti od `key * 196 + 4`.
3. **Godot s nerozjetým skriptem visí, ne selže** — vždy `--quit-after N`.
4. **`.uid` vzniká jen při `--import`** a **patří do gitu**.
5. **Godot mimo workspace nemůže zapisovat** a přitom lže `err=0`.
6. **`JSON.parse_string` vrací všechna čísla jako `float`** — vždy `int()`.
7. **`.gitignore` je na Windows case-insensitive** — vzor `Cliloc.*` pohltil
   `tools/uoextract/cliloc.py`. Kontroluj `git ls-files`, ne `Test-Path`.
8. **`Measure-Object -Line` nepočítá prázdné řádky** — měř Pythonem.
9. **Brána, která nic nezměří, není zelená** (`exit 2` = NEMĚŘENO).
10. **Statická kontrola musí číst kód, ne komentáře.**
11. **Shelf-pack bez kontroly překryvů tiše maže sprity** (atlas: 117 překryvů,
    17 prázdných) — a **self-test na malém vstupu to nechytí**.
12. **Dvanáct commitů, které nikdo neviděl, není „práce v bezpečí"** — CI je
    zelené jen nad tím, co je v `origin/main`, a to je 12 commitů zpátky.

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03 §3.4` — index bloku mapy**: opraveno na `bx * blocks_y + by`.
2. **`docs/03 §3.4` — záznam statiky**: opraveno na `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
3. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; skutečné soubory jsou `assets/uo/tiles.json`
   a `data/items.json`.
4. **`docs/04 §4.2` u `world.map` nerozlišuje `tiledata id` a `art id`** u statiků
   (soubor ukládá **id bez `+0x4000`**, naměřeno 37…4758).
5. **`docs/04 §4.2` u `render.sort` neuvádí tvar objektu** (viz otevřené věci 3).
6. **`docs/06 §6.2` uvádí 6 nástrojů, které v instalaci NEJSOU**: `skillet`
   (je `frypan`), `flour mill` (je `millstone`), `spinning wheel`, `loom`,
   `oven`, `bellows`. Navíc `clean bandage` a `blank scroll` v tiledata nejsou
   pod zadaným jménem. **Naměřeno znovu 2026-10-06 i pro `smith hammer`,
   `tinker tools`, `bank box`** → blokátor V9/V11.
7. **`.forge/roadmap.json` — `size_lines` nesedí u 21 z 31** (viz otevřené věci 2).
8. **`app/main.tscn` nemá vlastníka** v roadmapě — a **`app/player_controller.gd`
   v roadmapě vůbec není** (kamera + `queue_redraw`), stejně jako **zapojení
   systémů a `input_map` do stromu**. Bez nich zůstane renderer mrtvý kód.
9. **V roadmapě chybí vlastník pro pathfinding** — `docs/` o něm **nemluví
   vůbec** (0 zmínek, 0 granul), přitom `sim.ai` a click-to-move ho potřebují.
10. **Soubor pro zvuk/hudbu nemá žádná granule** — eventy `sound`/`music` jsou
    v `docs/04 §4.4`, ale žádná granule je nepřehrává (v repu 0× `AudioStream`).
11. **`docs/07 §7.3` (vlny) pokrývá 62 granul z 101** — chybí celá extrakční
    pipeline M1 (14), všechny `data.*` (8) a 4 bootstrap granule. 4 granule mají
    navíc závislost v pozdější vlně (`render.light` → `world.time`,
    `world.walk` → `world.stairs`, `sim.interaction` → `sim.craft`/`sim.magic`).

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (`docs/02 §2.6.8`).
- **Nečeské znaky (í, š, ň) nepatří do identifikátorů** — GDScript je neumí.
- Piš **jen do `owns`** své granule; `tests/`, `project.godot`, `.forge/`,
  `docs/`, `assets/uo/` needituju. (`tools/gates/` patří bránám, ale
  `data.gen_content` ho vlastní.)
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py`: 0 = vše měřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není zelená).
- Testy potřebují `APPDATA` ve workspace, jinak `user://` míří mimo:
  `$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"`.
  **Brány si to nastavují samy** (`tools/gates/gate_common.py:219`).
