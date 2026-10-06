# Předání — UO-klon (stav po zapojení renderu, 2026-10-06 večer)

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ.md`** (založeno 2026-10-06
> auditem, který neměnil kód). Tenhle soubor říká, **kde jsme**; tamten, **co dělat**.
> **Datum:** 2026-10-06 (večer). **Poslední změna kódu:** tato session (zapojení
> renderu; předchozí commit `72a4c0a` = oprava atlasu, je **pushnutý**).

## ✅ CO JE NOVÉHO (tato session) — na obrazovce je mapa Britainu

| Co | Doklad (naměřeno dnes) |
|---|---|
| **Poprvé se něco vykreslilo** | snímek z běhu `.cache/render/snapshot.png`, `1280x720`, **2117 barev**, 891 383 px mimo pozadí, sha256 `8734c5ca…`; lidsky ověřeno `read_image` (dlažby, zdi, dům s břidlicovou střechou, tráva) |
| **G10 zelená** | `[check-render] OK (exit 0)`, měřeno **na snímku z BĚHU** (ne na artefaktu z 2026-10-02, ten je odložený jako `snapshot-2026-10-02.png`) |
| **Brány** | `run-all.py` → **10 měřeno / 1 NEMĚŘENO (G9) / 0 chyb**, `exit 2` (minule 5/2/4, `exit 1`) |
| **`render.sort` má volajícího z produkce** | `render/chunk_renderer.gd` volá `draw_order`; `check-wiring` už `render.sort.draw_order` **nehlásí** (`neintegrovano` 25 → 18, `volanych_z_produkce` 29 → 41) |
| **Naměřená vada `world.map` opravena** | `z` statiky se četlo na offsetu **+3 = lokální `y`**; `z` z API bylo 0..7, ze souboru 10..60 |
| **Testy hry** | **238 kontrol / 0 selhání** (s `APPDATA` ve workspace) |
| **Self-testy bran** | **19 celkem (10 bran + 9 extrakčních nástrojů), 0 chyb** |
| **Nová sonda + mutační test** | `.cache/analysis/probe-render.gd` **35 kontrol / 0 selhání**; `mutace-render.py` **12 z 12 chycených**; `mutace-snimek.py` **3 ze 3** |

**Celý `run-all.py` je poprvé bez vady.** Zbylé `NEMĚŘENO` (G9) je poctivé:
`tests/replays/` je prázdné a vlastní je granule `boot.tests`.

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

## ⚠⚠ BLOKÁTORY

1. **CI na GitHubu NEBĚŽÍ — a není to chyba kódu ani kvóta minut.** Stav se
   **tímto krokem neměnil** (uživatel rozhodl, že se tou věcí tato session
   nemá zdržovat). Push `d9bc48a..72a4c0a` dorazil, `ahead 0`. Poslední známý
   stav: pět běhů (`#1`–`#5`), všechny `failure` s **0 jobů, 0 check-runs a bez
   logů**; `enabled: true`, `allowed_actions: all`, workflow `state: active`,
   YAML syntakticky v pořádku (vlastní parser kalibrovaný na dvou vratných
   vadách), `/actions/runs/<id>/timing` → **`billable: {}`**, repo **veřejné**.
   **Zbývá jediné měření, které API neumí:** přečíst hlášku u běhu v UI
   ([běh #4](https://github.com/ssevcikm-spec/game-clone/actions/runs/37454659740)
   nebo `Settings → Billing`).
2. ~~`tools/uoextract/atlas.py`: vada rozložení~~ — **VYŘEŠENO 2026-10-06**
   (0 překryvů, 0 prázdných, 41 874 spritů na 67 stranách, `--verify` 0 chyb)
   a **pushnuto** (`72a4c0a`). G6 dnes znovu: `zaznamu 41874`, `stranek 67`,
   `spritu_prazdnych 0`, `stranek_chybi 0`.

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Zadání pro další vývoj** | **`ZADANI-DALSI-VYVOJ.md`** (naměřená cesta k obrazovce, zapojení bez vlastníka) |
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes]` |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` → **238 kontrol / 0 selhání** |
| Brány | `python tools/gates/run-all.py` → **10 měřeno / 1 NEMĚŘENO (G9) / 0 chyb**, `exit 2` |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 self-testů, 0 chyb** |
| **Snímek z běhu** | `godot --path . --rendering-driver opengl3 --resolution 1280x720 --write-movie .cache/render/run-<tag>/frame.png --quit-after 5` → první frame se kopíruje na `.cache/render/snapshot.png` (dělá to `.cache/analysis/mutace-snimek.py`) |
| **Sonda renderu + mutace** | `godot --headless --path . --script res://.cache/analysis/probe-render.gd` · `python .cache/analysis/mutace-render.py` · `python .cache/analysis/mutace-snimek.py` |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable.official.ed1daf0bf) |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení; `map0.mul` tam **není** — mapa je v `map0LegacyMUL.uop`) |
| Roadmapa | `.forge/roadmap.json` — **101 granul, `done` je u všech `false`**: stav se pozná **jen měřením** |
| Data z instalace | `assets/uo/` (gitignore) — `tiles.json` 2 405 685 B, `manifest.json` **8 649 632 B** (41 874 spritů, 67 stran), `world/map0.land` 89 915 392 B, `world/map0.statics.bin` 20 386 415 B, `atlas/*.png` 115 153 521 B |
| Důkazy měření | `.cache/analysis/probe-render.gd`, `mutace-render.py`, `mutace-snimek.py`, `probe-input-map.py`, `probe-wiring-intrafile.py` (vše gitignore) |

## Stav kódu (počty řádků Pythonem `splitlines()`, bez `.uid` a `__pycache__`)

| složka | souborů | řádků | poznámka |
|---|---|---|---|
| `core/` | 7 | 339 | hotové a otestované |
| `sim/` | 8 | 942 | **`systems` je stále prázdné — plní ho jen testy** |
| `render/` | **3** | **311** | `sort.gd` + **`texture_cache.gd`** + **`chunk_renderer.gd`**; `ui/` pořád neexistuje |
| `app/` | 4 | 306 | +**`world_view.gd`** (bez granule!); `main.gd` připojuje sim, loop i svět |
| `tests/` | 16 | 1 047 | 14 case souborů, **beze změny** (`tests/` agent needituje) |
| `tools/uoextract/` | 38 | 5 910 | 12 produkčních + 26 jednorázových experimentů |
| `tools/gates/` | 16 | 3 130 | 10 bran + `run-all.py`, `gen-content.py`, `gate_common.py` |

**Zbývá 62 granul.** `render.textures` a `render.chunk` už soubor **mají**
(roadmapa je vedla jako nehotové; dnes je `check-wiring` počítá mezi
implementované: `granuli_s_hotovym_souborem` 37 → **39**).

## Co je hotové a ověřené (ne „soubor existuje")

**M0 celek** · **W0** (8) · **M1: uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc, anim, data.items, data.gen_content, data.recipes,
world.tiledata, world.map, render.sort, render.textures, render.chunk** ·
**M2: world.doors, world.stairs, entity.stats, world.time**.

Doklady, které jsem dnes viděl na vlastní oči (ne opsané z předání):

- **Na obrazovce je mapa Britainu** — snímek z běhu (viz „Co je nového") a
  `read_image` na něm: dlažební kostky, kamenné zdi, dům s břidlicovou střechou,
  tráva. **Není to** `preview-britain.png` z extrakce.
- **Kreslicí seznam je měřený, ne dojmový** — sonda ho srovnává s **nezávislým
  parserem týchž bajtů** `.land`/`.statics.bin`: **6095 prvků** (3072 land +
  3023 statik) a shoda na **každé** čtveřici `x,y,z,art`.
- **Textury**: indexováno **39 855** land+item spritů (`manifest` má tolik),
  land art 3 = 44×44, land 3 ≠ item 3 (prostory se nemíchají), chybějící art →
  `null` + počítadlo `missing`.
- **Hra nespadne**: G11 `smoke` → `framu 120, script_error 0, parse_error 0`.
- **Testy hry**: 238 kontrol / 0 selhání.

### ⚠ Co na obrazovce ještě NENÍ

Postava, animace (pixely `anim*.mul` **nejsou dekódované**, `pixels_decoded: false`),
pohyb, UI, světlo. Simulace pořád **nemá ani jednu systémovou jednotku**:
`SYSTEM_ORDER` (`sim/sim_world.gd:34-37`) vypisuje 15 systémů, `systems` je
prázdný slovník a v celém repu ho plní **jen `tests/cases/sim_world.gd:85-87`**.
`move` skončí hláškou „Not available yet: move -> movement.request_step".
**Hratelná mechanika: nula** (což je pořád pravda — dnešní práce je o obrazu).

## ⚠ Tři „vady zapojení" z minulého předání — PŘEMĚŘENO

| # | Tvrzení z minula | Dnešní měření |
|---|---|---|
| 1 | `input_map` se nikdy nepřidá jako dítě → `poll()` se nezavolá | **NEPLATÍ (dvě nezávislá měření).** `app/input_map.gd:1` je `extends RefCounted` → dítětem být **nemůže**; `app/main.gd:31` ho předává `loop` a `app/loop.gd:31-32` ho volá v `_process`. Živý běh (`.cache/analysis/probe-input-map.py`): **`poll()` volán 8× za 20 framů**. **Skutečná vada je jinde:** `InputMapScript.new()` se volá **bez tabulky vazeb**, takže `bindings` je prázdný a `poll()` proiteruje **nula akcí**. Chybí vlastník výchozích kláves (`ui.hotkeys`, `docs/04 §4.2`). |
| 2 | `sim.systems` plní jen testy | **PLATÍ DÁL** (`sim_world.gd:81` čte, `tests/cases/sim_world.gd:85-87` píše). |
| 3 | `time.world_time_ms` nikdo nezapíše → `hour()` vždy 0 | **PLATÍ DÁL** (`sim/world/time.gd:23`; `SimWorld` má vlastní `_clock`). |

Navíc: `world.doors`, `world.stairs`, `world.time` jsou hotové a otestované, ale
**nemají ani jednoho konzumenta** (`sim.movement`, `world.walk`, `sim.interaction`
neexistují).

## Co brány dnes měří (2026-10-06 večer, plný přístup)

`run-all.py`: **10 měřeno / 1 NEMĚŘENO / 0 VADA**, `exit 2`.

| Brána | Výsledek | Je to vada kódu? |
|---|---|---|
| G1, G2, G3, G5, G6, G7, G8, G11, G10 | **OK** | NE |
| G9 | NEMĚŘENO | NE — `tests/replays/` je prázdné (vlastní `boot.tests`) |
| G13 | PORADNÍ | NE — `vision.mjs` není |

Pozor na srovnání s minulým předáním (**5/2/4**): tehdy session běžela
v sandboxu `workspace-write`, který **neuměl zapsat do `.cache`** — G3/G7/G11
hlásily vadu a `run-all.py` padal na `summary.json`. **Dnešní session běžela
s plným přístupem** (rozhodnutí uživatele), takže naměřená čísla nejsou
srovnatelná: není to oprava, je to jiné prostředí.

**Testy: 238 kontrol / 1 selhání bylo v sandboxu; dnes 238 / 0.**
`run-all.py --self-test`: 19 self-testů, **0 chyb**.

## Předletová kontrola (5 minut, než začneš psát)

| Co | Jak | Očekáváno (2026-10-06 večer) |
|---|---|---|
| Přečtené zadání | `ZADANI-DALSI-VYVOJ.md` | cesta k obrazovce + zapojení bez vlastníka |
| Strom je čistý | `git status --porcelain -uall` | **prázdné** po commitu této session |
| Je před GitHubem | `git rev-list --count origin/main..HEAD` | `0` (tato session **nepushuje bez vyžádání**) |
| **Běží CI?** | `https://github.com/ssevcikm-spec/game-clone/actions` | **NE** — běhy `failure` s **0 jobů** (blokátor 1). **Až ožije, bude červené** — chybí assety (otevřená věc 20) |
| Repo je veřejné | `git ls-remote` bez přihlášení, nebo API bez tokenu | `visibility: public` |
| Testy | testy s `APPDATA` ve workspace | `238 kontrol, 0 selhání` |
| Brány | `python tools/gates/run-all.py` | `10/1/0`, `exit 2` |
| **Snímek je z běhu** | `Get-Item .cache/render/snapshot.png \| % LastWriteTime` | **dnešní** (ne 2026-10-02) |
| Godot běží | `& .cache\godot\...exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |
| Instalace UO na místě | `Test-Path 'D:\Games\...\tiledata.mul'` | `True` |
| Kontroly zadání | `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` | `exit 0` (dnes všechny tři) |

## Otevřené věci a co je potřeba dodělat

**Přenáším z minulého předání (nic se nemaže) — u každé je dnešní stav:**

1. **`render.sort` nemá test v `tests/cases/`** — **PLATÍ DÁL** (a `tests/`
   agent needituje). Dnes to **není slepé místo**: měří ho sonda
   `.cache/analysis/probe-render.gd` (35 kontrol) **a je dokázaná mutacemi**
   (12/12). Sonda je ale gitignore → v čerstvém klonu ji nikdo nespustí.
   Bez testu v `tests/cases/` jsou i `world/map.gd`, `world/tiledata.gd`,
   `app/main.gd`, `app/main.tscn`, `render/texture_cache.gd`,
   `render/chunk_renderer.gd` → **8 souborů** (dřív 5 z 22).
2. **`size_lines` nesedí** — **PLATÍ DÁL a je to horší:** `world.map` 199/120,
   `render/texture_cache.gd` **141/60**, `render/chunk_renderer.gd` 110/150,
   `app/world_view.gd` (**bez deklarace**). **Rozhodnutí pro uživatele:**
   uvolnit deklarace, nebo dělit granule.
3. **Tvar objektu pro `render.sort` patří do `docs/04 §4.2`** — **PLATÍ DÁL**;
   navíc přibyl tvar prvku `render.chunk` (`{kind,x,y,z,art_id,offset}`) a
   **rozšíření `world.map.statics_at` o `x`,`y`** (viz bod 15).
4. **G10 měří snímek z bootstrapu (2026-10-02)** — **VYŘEŠENO.** G10 dnes měří
   snímek z běhu, starý artefakt je odložený jako
   `.cache/render/snapshot-2026-10-02.png`; `.cache/render/frame*.png`
   z bootstrapu zůstaly na místě jako doklad.
5. **13 generátorů v `POZADOVANÉ` chybí** — **PLATÍ DÁL** (`weapons`, `armor`,
   `spells`, `item_properties`, `monsters`, `spawns`, `vendors`, `regions`,
   `moongates`, `dungeons`, `professions`, `skills`, `balance`).
6. **Pixely animací** — **PLATÍ DÁL a je to blokátor:** `manifest.json` to
   přiznává (`"pixels_decoded": false`). **Hráč (tělo 400/401) je jen v MUL** →
   bez rozluštění RLE se postava nepohne.
7. **`assets.uop` (2 rozpory) a `assets.verify`/`assets.extract_cli`** —
   **PLATÍ DÁL**; `assets.atlas` je hotový, ověřený a pushnutý.
8. **Zastaralé poznámky v `tools/uoextract/worldmap.py`** (ř. 10–11, 60–63,
   87–90) tvrdí, že `docs/03 §3.4` uvádí špatné pořadí bloku — **PLATÍ DÁL**.
9. **`atlas.py`: vada rozložení** — **VYŘEŠENO 2026-10-06** (viz blokátor 2).
10. **`docs/11 §11.6` vede O3 jako neuzavřené, `docs/03 §3.5.1` tvrdí
    „rozhodnuto měřením"** — **PLATÍ DÁL.** Vnitřní rozpor dokumentace.
11. **Počet granul se v dokumentech rozchází: 101 / 100 / 75–90** — **PLATÍ DÁL.**
12. **`ZADANI` §10 a `docs/05 §5.11` uvádějí světlo „den 12"**, `research/01 §4.2`
    má `DayLevel = 0`, `NightLevel = 12` — **PLATÍ DÁL.** Vadná je dokumentace.
13. **Rešerše hlásily dvě „vady", které neobstály** — **PLATÍ DÁL** jako
    varování, ať se neopakují.
14. **CI neproběhlo ani jednou s nenulovým počtem jobů** — **PLATÍ DÁL**
    (blokátor 1). Dnes se tím session **neměla zdržovat**.
15. **`statics_at` vrací nadmnožinu `{tile,x,y,z,hue}` místo smluvních
    `{tile,z,hue}`** — **NOVÉ, VADA ZADÁNÍ.** `docs/04 §4.2` (ř. 50) souřadnice
    neuvádí, ale `render.chunk` je potřebuje a `world.map` je jediný čtenář
    `.statics.bin`. Doplněno do smlouvy **v kódu** (hlavička `sim/world/map.gd`),
    `docs/` agent needituje.
16. **`check-wiring` nevidí volání UVNITŘ granule** — **NOVÉ, VADA BRÁNY
    (měřeno, ne dojmem).** Brana vylučuje vlastní soubor granule, takže
    `render.sort.sort_key` zůstává v seznamu „zatím nevolané z produkce", **i když
    ho `draw_order` v tomtéž souboru volá** (`render/sort.gd:46`).
    Důkaz: `.cache/analysis/probe-wiring-intrafile.py` postaví dvě fixture, které
    se liší **jen tím, je-li jméno `helper` zmíněno v jiném produkčním souboru**:
    A → `volanych_z_produkce 1 / neintegrovano 1` **s hláškou u volané funkce**,
    B → `2 / 0`. **Verdikt tedy mění slovo, ne volání.** Oprava patří vlastníkovi
    brány (`boot.gates`), ne agentovi.
17. **`app/world_view.gd` a uzly `Camera`/`WorldView` v `app/main.tscn` nemají
    v roadmapě vlastníka** — **NOVÉ, VADA ZADÁNÍ** (přesně to předpovídalo
    `ZADANI-DALSI-VYVOJ` §3 úkol 5 a §„Vady ZADÁNÍ" bod 8). Soubor existuje,
    je zapojený a ověřený snímkem, ale granule pro něj není.
18. **`app/input_map.gd` se v produkci volá, ale bez vazeb** — **NOVÉ, VADA
    ZAPOJENÍ (skutečná podstata „vady 1").** Vlastníkem výchozích kláves je
    `ui.hotkeys` (`docs/04 §4.2`), který v roadmapě je, ale soubor nemá.
    Do té doby je vstup hráče **funkčně mrtvý**, i když se `poll()` volá.
19. **Kreslení řeší každý objekt zvlášť (`AtlasTexture` na objekt a frame)** —
    **NOVÉ, VÝKONNOSTNÍ DLUH, `UNVERIFIED`.** Snímek z běhu v Movie Maker módu
    vznikl ~1 s/frame (z toho 369 ms/frame kódování PNG), takže **žádné tvrzení
    o FPS nemám**. Kdyby měl být cíl „60 FPS při 1280×720" měřený, musí se
    textury cachovat **v seznamu `render.chunk`** — a tím se změní platnost
    stropu paměti v `render.textures` (dnes platí proto, že seznam textury
    nedrží). Rozhodnout před M2.
20. **⚠ AŽ CI OŽIJE, BUDE ČERVENÉ — a nebude to vada kódu.** `assets/uo/` je
    v `.gitignore` (`git ls-files assets/uo` → **0 souborů**) a `ci.yml`
    **extrakci nespouští**. Naměřeno v simulaci čerstvého klonu
    (`.cache/analysis/dukaz-ci-bez-assetu/`): bez assetů `world.map` i
    `render.textures` jen varují, svět má **0 objektů**, frame má **1 barvu
    (77,77,77)** — a `check-render.py` na něm hlásí **VADA (exit 1)**.
    Stejně tak G6 (`check-assets`) na datech z instalace. **Rozhodnutí pro
    uživatele:** (a) nechat G6/G10 v CI `NEMĚŘENO`, když assety nejsou,
    (b) dodat do CI fixture (malý atlas + blok mapy), nebo (c) generovat assety
    v CI z instalace UO (ta tam ale není). Do té doby platí: **zelené brány
    lokálně ≠ zelené CI.**

## Už není otevřené (přesunuto, nemaže se)

- **„Na obrazovce není nic"** — **vyřešeno 2026-10-06**: snímek z běhu má
  2117 barev a je na něm Britain; G10 je zelená.
- **„`render.sort` nemá volajícího z produkce"** — **vyřešeno**:
  `render/chunk_renderer.gd` volá `draw_order`; `check-wiring` už
  `render.sort.draw_order` nehlásí v `neintegrovano` (25 → 18).
- **„G10 měří 4 dny starý artefakt"** — **vyřešeno**: snímek je z běhu
  a `.cache/analysis/mutace-snimek.py` to každé spuštění obnoví a ověří.
- **„Repo je privátní, a proto nemá minuty Actions"** — vyřešeno 2026-10-06.
- **„12 commitů není před GitHubem"** — vyřešeno 2026-10-06 (`ahead 0`).
- **„`tools/uoextract/atlas.py` není v gitu"** — vyřešeno (`7a4f3e7`).
- **„`assets.atlas` není hotový"** — vyřešeno; i vada rozložení (dnes).
- **Podezření, že brány jsou zelené nad vadou** — **nejsou**: dnes 0 vad,
  ale každá nová kontrola je **doložená mutací** (12/12 a 3/3), ne dojmem.
- **Podezření, že v repu jsou tajemství** — prověřeno 2026-10-06.

## Další kroky (v tomto pořadí)

1. **Zapsat `tests/cases/` pro `render.sort` + `world.map` + render** — dnes to
   dělá jen gitignore sonda. **Rozhodnutí uživatele:** `tests/` agent needituje,
   takže to musí udělat člověk (nebo povolit výjimku). Sonda je hotová a může
   se přepsat 1:1.
2. **Zprovoznit CI** (nutné před orchestrou) — přečíst hlášku v UI.
   **Pozor:** jakmile CI poběží, G6/G10 budou červené kvůli chybějícím assetům
   (otevřená věc 20) — vyřešit **dřív**, než se začne hledat vada v kódu.
3. **`app/player_controller.gd` / pohyb kamery** — dnešní `world_view.gd` kameru
   jen **nastaví**, neposouvá; klávesy nejsou nikde namapované (bod 18).
4. **Pixely animací** (`anim*.mul`, RLE) — **blokátor „postava se pohne"**.
   Rozhodnout: statický sprite v této etapě, nebo rozluštit RLE.
5. Pak M2: `data.skills` → `entity.skills` → `entity.mobile` → `world.walk` →
   `sim.movement`; a **zaregistrovat systémy do `SimWorld`** (vada 2).

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená (`done` je u všech 101 granul `false`).
- **Mutační test je to, co odlišuje měření od dojmu** — a musí se ověřit
  **tři věci**: že se mutace provedla, že sonda **vůbec proběhla** (`N kontrol`,
  N > 0) a že selhala **na kontrole**. Dnešní harness to dělá
  (`.cache/analysis/mutace-render.py`).
- **Druhá implementace téhož formátu je jediná obrana** — sonda, která čte
  `.statics.bin` sama, našla dnešní vadu `z` za minutu.
- **Snímek z běhu je deterministický** → hash snímku je použitelná regrese.
- **Hotový soubor bez volajícího je mrtvý kód** — ptej se „kdo to volá".
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA.**
- **Když implementace odhalí díru ve smlouvě, napiš ji do hlavičky souboru**
  (jako `sim_world.gd`, `time.gd` a dnes `map.gd`) a zaznamenej jako otevřenou
  věc — `docs/` agent nemění.

## Pasti, které už někoho stáhly čas (naměřené)

1. **`==` na `Array` v GDScriptu porovnává OBSAHEM.** Na identitu je `is_same()`.
   Dnešní sonda kvůli tomu hlásila vadu o **správném** kódu (LESSONS 2026-10-06).
2. **V mutačním harnessu musí sonda brát všechny měřené cesty z argumentů.**
   Pevná `res://` cesta v sondě znamená, že mutant se do kontroly vůbec nedostane
   (dvě mutace kvůli tomu „prošly").
3. **Test stropu musí pracovní sadu PŘEKROČIT** — 10 000 požadavků na jedné
   atlasové stránce neprokáže nic o stropu (dvě mutace prošly).
4. **`"MERENO:"` je podřetězec `"NEMERENO:"`** — parsování výstupu bran
   musí hledat i s hranatou závorkou (`] MERENO:`). Dnes to shodilo sondu.
5. **`provides` bez `(` není „volatelné jméno"** — `check-wiring` bere jen jména
   ve tvaru `foo(` nebo `KONSTANTA_VELKÁ`; jinak granuli přeskočí jako prózu.
6. **Sandbox `workspace-write` blokuje zápis do `.cache`** (Low integritní
   label na kořeni). Důsledek: G3/G7/G11 hlásí falešnou vadu a `run-all.py`
   padá na `summary.json`. **Tato práce potřebuje plný přístup.**
7. **`map0.land` má na každém bloku 4B hlavičku** — čti od `key * 196 + 4`.
8. **Statika je 7 B `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`** — `z` je na
   **offsetu 4**, ne 3 (dnešní oprava). `x`,`y` jsou 0..7 v rámci bloku.
9. **Godot s nerozjetým skriptem visí, ne selže** — vždy `--quit-after N`.
10. **`.uid` vzniká jen při `--import`** a **patří do gitu**.
11. **`JSON.parse_string` vrací všechna čísla jako `float`** — vždy `int()`.
12. **`.gitignore` je na Windows case-insensitive** — kontroluj `git ls-files`.
13. **`Measure-Object -Line` nepočítá prázdné řádky** — měř Pythonem.
14. **Brána, která nic nezměří, není zelená** (`exit 2` = NEMĚŘENO).
15. **Heredoc v PowerShellu neexistuje** — piš skript do souboru.
16. **Snímek pro G10 vzniká jen s `--rendering-driver opengl3`** (`--headless`
    nekreslí). Frame se jmenuje `frame00000000.png` a `.wav` k němu patří.

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03 §3.4` — index bloku mapy**: opraveno na `bx * blocks_y + by`.
2. **`docs/03 §3.4` — záznam statiky**: opraveno na `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
3. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; skutečné soubory jsou `assets/uo/tiles.json`
   a `data/items.json`.
4. **`docs/04 §4.2` u `world.map` nerozlišuje `tiledata id` a `art id`** u statiků
   (soubor ukládá **id bez `+0x4000`**, naměřeno 37…4758).
5. **`docs/04 §4.2` u `render.sort` neuvádí tvar objektu** — a **nově ani
   u `render.chunk` a `render.textures`**: `statics_at` vrací `{tile,x,y,z,hue}`
   (bod 15), `render.chunk` vydává `{kind,x,y,z,art_id,offset}` a
   `render.textures` má navíc `offset(art_id)` a `stats().missing`.
6. **`docs/06 §6.2` uvádí 6 nástrojů, které v instalaci NEJSOU** (`skillet`,
   `flour mill`, `spinning wheel`, `loom`, `oven`, `bellows`) + `smith hammer`,
   `tinker tools`, `bank box`.
7. **`.forge/roadmap.json` — `size_lines` nesedí** (dnes `world.map` 199/120,
   `render/texture_cache.gd` 141/60).
8. **`app/main.tscn` + kamera + kreslicí uzel nemají vlastníka** v roadmapě
   (`app/world_view.gd` taky ne) — dnes **skutečně vznikl** a je ověřený.
9. **V roadmapě chybí vlastník pro pathfinding.**
10. **Soubor pro zvuk/hudbu nemá žádná granule** — eventy `sound`/`music` jsou
    v `docs/04 §4.4`, ale žádná granule je nepřehrává (v repu **0× `AudioStream`**).
11. **`docs/07 §7.3` (vlny) pokrývá 62 granul z 101.**
12. **`ZADANI-DALSI-VYVOJ` §7 zakazuje měnit `tests/`, ale acceptance
    `render.textures`/`render.chunk` žádá `tests`** — **NOVÝ ROZPOR.** Dokud se
    nerozhodne, měří render **jen gitignore sonda** (a v čerstvém klonu nikdo).

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (`docs/02 §2.6.8`).
- **Nečeské znaky nepatří do identifikátorů** — GDScript je neumí.
- Piš **jen do `owns`** své granule; `tests/`, `project.godot`, `.forge/`,
  `docs/`, `assets/uo/` needituju. (`tools/gates/` patří bránám, ale
  `data.gen_content` ho vlastní.)
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (dnes všechny `exit 0`).
- `run-all.py`: 0 = vše měřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není zelená).
- Testy potřebují `APPDATA` ve workspace:
  `$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"`.
  **Brány si to nastavují samy** (`tools/gates/gate_common.py:219`).
- **Nepushovat bez vyžádání.** Tato session commitne, ale **nepushuje**.
