# Předání — UO-klon (DEMO chodí; rejstřík referencí hotový; 2026-10-06 noc, 2. session)

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ.md`** (založeno 2026-10-06
> auditem, který neměnil kód). Tenhle soubor říká, **kde jsme**; tamten, **co dělat**.
> **Kam pro co v referenčních zdrojích je `research/REJSTRIK-REFERENCI.md`**
> (rozcestník, generovaný a kontrolovaný — není to stav).
> **Datum:** 2026-10-06 (noc, 2. session). **Poslední změna kódu:** tato session
> (pixely animací + M2 pohyb + zapojení do scény + rejstřík referencí).
> Předchozí commit `c3617e5` = předání po zeleném CI; `8050096` = demo.

## 🎬 DEMO JE NA SVĚTĚ — mapa Britainu + postava, která po ní chodí

**Co je na obrazovce:** mapa Britainu (land + statiky) a **postava (tělo 400),
která stojí, otáčí se a chodí** po klávesách; kamera ji sleduje po dlaždicích.
Postava je **dekódovaná z `anim.mul`** (ne placeholder) — 10 framů chůze na směr.

**Jak si to spustit (lokálně, 30 s):**

```powershell
cd E:\Workspaces\game-clone
$env:APPDATA = "E:\Workspaces\game-clone\.cache\godot-appdata"   # user:// zůstane ve workspace
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-driver opengl3 --resolution 1280x720
```

**Klávesy:** šipky nebo numpad **1–9** (8 směrů; `4/6` = západ/východ, `7/9` =
severozápad/severovýchod, `2/8` = jih/sever). Chůze je **diskrétní krok** (400 ms),
proto **každé zmáčknutí = jeden krok** — držení klávesy krok neopakuje (viz
otevřená věc 27).

**Čím je to doložené (ne „mělo by to jít"):**

| Důkaz | Jak naměřeno |
|---|---|
| Postava je na mapě | snímek z běhu `.cache/render/chuze/frame00000130.png` (→ `snapshot.png`); G10 `barev: 2148`, `pixelu_mimo_pozadi: 892553` |
| **Postava opravdu chodí** | řidič `.cache/analysis/demo-chuze.gd` poslal do hry **skutečné klávesy** (`Input.parse_input_event`): 6 pozic `(1495,1630)` → `(1496,1630)` → `(1497,1630)` → `(1497,1629)` → `(1498,1630)` → `(1497,1630)`, směry 0/2/7/4, animace se přepínala `4 (idle) ↔ 0 (walk)` |
| Kreslí se i postava | `[demo] SOUHRN: kresleno objektu 5771, postava nakreslena true, chybi sprite false, animace dostupna true` |
| Chůze má správné časování | test: posun **po 8 ticcích** (8 × 50 ms = 400 ms), prodleva běhu 200 ms |
| Krok neprojde vodou/zdí | test: `{ok:false, reason:"blocked"}` + hláška „You cannot move there." |

**Co v demu NENÍ:** souboj, magie, obchod, řemeslo, UI okna, jména, světlo,
výbava na postavě, jiné postavy (NPC), mount, pathfinding. Postava je navíc
**šedá** — barvu kůže v UO dělá hue z `hues.mul` (granule `render.hue`, chybí).

## ✅ CO JE NOVÉHO (tato session) — a čím je to doložené

| Co | Doklad (naměřeno dnes) |
|---|---|
| **Pixely animací JSOU rozluštěné** (byl to blokátor „postava se nepohne") | `x`/`y` v RLE hlavičce jsou **znamenkové 10bitové** (`1020..1023` = `-4..-1`), prvních **512 B bloku JE paleta** (256× u16 ARGB1555, šedý ramp), pixel = **1 bajt** indexu, terminátor `0x7FFF7FFF`. Recept i reference (ClassicUO `AnimationsLoader.ReadSpriteData`) je v hlavičce `tools/uoextract/anim.py` |
| Důkaz, že to není dohad | **0 pixelů mimo frame** na 30 blocích (těla 400/401 × walk/run/idle × 5 směrů); `anim.py --verify` **55 kontrol, 0 chyb**; `--self-test` **35 kontrol, 0 chyb**; `tools/gates/mutace-anim.py` **8 z 8** mutací chyceno |
| Postava je vidět (snímek) | kráčející muž z `anim.mul` vyexportovaný i vykreslený v běhu hry — ověřeno **pohledem** (`read_image`), ne jen testy |
| **Export animací pro klienta** | `python tools/uoextract/anim.py --export assets/uo/anim` → **30 spritů, 210 framů** (těla 400/401, akce 0=walk/1=run/4=idle, 5 směrů) + `anim-sheets.json`; kontrola exportu **240 kontrol, 0 chyb** |
| **M2: pohyb (4 granule)** | `sim/world/walk.gd` (průchodnost, výšky, **asymetrická diagonála**), `sim/entity/skills.gd`, `sim/entity/mobile.gd`, `sim/systems/movement.gd` (prodlevy 400/200, stamina, eventy) — všechny s testy |
| **Mutační důkaz pro M2** | `tools/gates/mutace-tests.py` teď umí i `walk` a `movement`: **34 z 34** mutací chyceno (sort 10, map 11, walk 6, movement 7) + smlouva o vstupu OK |
| **Mutační důkaz celkem** | **59 z 59**: `mutace-tests.py` 34, `mutace-anim.py` 8, `mutace-skills.py` 8, `mutace-render-anim.py` 9 |
| **CI zůstane zelená i bez assetů** | simulace čerstvého klonu (přejmenované `assets/uo`): testy **396 kontrol, 0 selhání** s viditelným `NEMERENO` (render.anim, reálná tiledata, reálná mapa). Test `render_anim.gd` hlásí chybějící **data** přes `print NEMERENO`, ne přes `_pending` (to by shodilo G3 v CI) |
| **Vstup a zapojení do scény** | `app/player_controller.gd` (bez granule) zakládá **12 klávesových vazeb za běhu** a mapuje 8 směrů; `app/world_view.gd` kreslí postavu **v pořadí kreslení** (mezi statiky podle `x + y`) |
| Testy hry | **422 kontrol, 0 selhání** (bylo 276; +146 za tuhle session: 4× M2, controller, data.skills, render.anim) |
| Brány | **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0` |
| **Brána G6 byla slepá a je opravená** | `check-assets.py` **tvrdila**, že `pixels_decoded: true` je VADA (podle rešerše z 2026-10-03). Teď to **měří**: manifest musí nést `pixels_recipe` a self-test dekodéru musí projít → `anim_decoder_kod: 0`, `anim_decoder_kontrol: 35`. Self-test brány má **7 případů** (přibyl známý správný i dva známé chybné) |
| **Kamera respektuje výšku** | kamera stála na `z = 0`, postava na `z = 10` → 40 px nad středem (naměřeno prvním snímkem). `look_at_tile(tile, z)` to opravuje |
| **`data.skills` (58 skillů)** | `data/skills.json` (11 755 B, 58 záznamů) + `gen-content.py --only skills --check` (idempotentní, `sha256 5c6716244234`); test 27 kontrol; `tools/gates/mutace-skills.py` **8 z 8** |
| **`render.anim` (anim player)** | `render/anim_player.gd` (121 řádků): framy z `anim-sheets.json`, časování **80 ms** (`Const.TURN_MS`), mapování 8 → 5 směrů + zrcadlení podle ClassicUO `Animation.cs:76`; `tools/gates/mutace-render-anim.py` |

## 📚 REJSTŘÍK REFERENCÍ (třetí část této session) — „kam pro co"

**Proč:** cíl je **naučit se ze hry a pak ji modernizovat**. V repu jsou klony
RunUO, ServUO, ModernUO, ClassicUO a Sphere (`_src/`, gitignore) — ale nikde
nebylo, **který soubor na co**. Vznikl rejstřík, který **není seznam dojmů**:

| Věc | Co to je |
|---|---|
| `research/REJSTRIK-REFERENCI.md` | **rozcestník** (generovaný): metoda, které stromy tu jsou (commit + licence + velikost), rozhodovací tabulka „kterou referenci na co", **~50 řádků „otázka → `soubor:řádek`"** s naměřeným počtem nálezů, vzorový příklad, modernizace, odkaz na multiplayer |
| `tools/refs-index.py` | generátor **a kontrola**: `--write` (default), `--check` (porovná dokument s diskem a spadne na **mrtvém odkazu**, tj. 0 nálezů), `--srovnej` (RunUO vs ServUO vs ModernUO) |
| `research/08-multiplayer-poucky.md` | **poučky bokem**: 17 principů ze serverů (`soubor:řádek` + „u nás dnes" + „platí už teď / až s multiplayrem"), co z multiplayeru **neplatí**, a startovní bod pro LAN/co-op |

**Naměřená odpověď na otázku „je lepší zkoumat RunUO než ServUO?"** — záleží na
vrstvě (měřeno `python tools/refs-index.py --srovnej`):

| vrstva | zdroj | měření |
|---|---|---|
| architektura jádra | **RunUO** | `servuo/Server` = **123 ze 123** souborů `runuo/Server` (nadmnožina) + 20 navíc; RunUO je menší (jádro ~59k vs ~73k řádků, strom ~3,3k vs ~6,3k `.cs`) → **na učení čistší** |
| obsah, éry, pravidla | **ServUO** | aktivní (2026-10-06), `Config/`, `Spawns/`, `RevampedSpawns/`; naše `research/` z něj vychází |
| modernizace | **ModernUO** | z 123 jmen jádra zůstalo **39** (restrukturalizace), 1371 `[Fact]`/`[Theory]` vs **0** v ServUO, 3858 migračních manifestů vs 0 |
| klient (render, animace, vstup) | **ClassicUO** | jediný klient v repu; animace/art/atlas/klávesy |
| rozhodčí při rozporu | **Sphere** | jiný rodokmen; `PLAYER_HEIGHT 16` nezávisle potvrzuje 16 |

**Bonus, který z rejstříku vypadl jako past:** v ClassicUO jsou **dvě konstanty
téhož jména** — `Constants.cs:19 WALKING_DELAY = 150` a
`MovementSpeed.cs:13 STEP_DELAY_WALK = 400`. Pravidlo je **serverové** (400);
kdybych vzal 150, byl by krok 2,7× rychlejší. Tohle je přesně ten druh věci,
kvůli které rejstřík vznikl.

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

**Žádný otevřený blokátor.** „Demo chodí" je naměřené (viz tabulka výš), brány
jsou zelené (11/0/0) a testy taky (422/0).

Dvě věci, které blokátor **nejsou**, ale je dobře je vědět:

1. **Tři mutační harnessy nejsou v CI.** `mutace-tests.py` v CI je, ale
   `mutace-anim.py`, `mutace-skills.py` a `mutace-render-anim.py` se pouští jen
   ručně. Do `ci.yml` patří jako samostatné kroky — `ci.yml` vlastní `boot.gates`,
   agent ho needituje (rozhodnutí uživatele).
2. **`tests/run_tests.gd` pořád tiše přeskočí case soubor s parse errory**
   (otevřená věc 21 z minula). Dnes to **není akutní**: každá nová kontrola má
   mutační důkaz, takže „0 selhání" je podložené.

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Demo (hra)** | `& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-driver opengl3` (s `$env:APPDATA` ve workspace) |
| **Zadání pro další vývoj** | **`ZADANI-DALSI-VYVOJ.md`** (naměřená cesta k obrazovce, zapojení bez vlastníka) |
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| **Kam pro co v referencích** | **`research/REJSTRIK-REFERENCI.md`** (rozcestník, ~50 odkazů s měřeným počtem nálezů) — generuje a kontroluje `python tools/refs-index.py [--check\|--srovnej]` |
| **Multiplayer bokem** | **`research/08-multiplayer-poucky.md`** — 17 principů ze serverů, „u nás dnes" + co platí až s multiplayrem |
| **Referenční klony** | `_src/{runuo,servuo,modernuo,classicuo,sphere}` (**pinované**, gitignore, nejsou submoduly). Pozor: `research/_src/{servuo,modernuo}` jsou **druhé checkouty téhož** — pro čtení používej `_src/` |
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes\|skills]` |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` → **422 kontrol / 0 selhání** |
| Brány | `python tools/gates/run-all.py` → **11 měřeno / 0 NEMĚŘENO / 0 chyb**, `exit 0` |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 self-testů (10 bran + 9 extrakčních nástrojů), 0 chyb**; G6 má uvnitř **7 případů** (dřív 4) |
| **Mutační důkaz testů** | `python tools/gates/mutace-tests.py [--only sort\|map\|walk\|movement]` → **34 z 34** (trvá minuty) |
| **Mutační důkaz dekodéru animací** | `python tools/gates/mutace-anim.py` → **8 z 8** |
| **Mutační důkaz `data.skills`** | `python tools/gates/mutace-skills.py` → **8 z 8** |
| **Mutační důkaz `render.anim`** | `python tools/gates/mutace-render-anim.py` |
| **Animace: dekodér** | `python tools/uoextract/anim.py --self-test \| --verify \| --export assets/uo/anim \| --export-check assets/uo/anim` |
| **Dekodér: objevné sondy** | `_analyza/anim-rle-sonda.py`, `_analyza/anim-rle-hledani.py`, `_analyza/anim-dekod.py` (**gitignore** — v gitu je jen produkční `anim.py` a mutační harness) |
| **Snímek z běhu** | `godot --path . --rendering-driver opengl3 --resolution 1280x720 --write-movie .cache/render/run-<tag>/frame.png --quit-after 5` — **cesta musí mít dopředná lomítka** (viz pasti) |
| **Důkaz chůze (řidič)** | `godot --path . --rendering-driver opengl3 --write-movie .cache/render/chuze/frame.png --script res://.cache/analysis/demo-chuze.gd` (řidič je v `.cache/`, gitignore) |
| Fixture pro `world.map` | `python tests/fixtures/world/make_fixture.py [--check]` |
| Replaye pro G9 | `tests/replays/tic_200.json`, `tic_1000.json` |
| Sonda renderu + mutace | `.cache/analysis/{probe-render.gd,mutace-render.py,mutace-snimek.py}` |
| Stav a logy CI běhů | `node _analyza/ci-beh-stav.mjs` · `node _analyza/ci-log.mjs` · `node _analyza/ci-artefakt.mjs` |
| Godot (binárka) | `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable.official.ed1daf0bf) |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` — **101 granul, `done` je u všech `false`**: stav se pozná **jen měřením** |
| Data z instalace | `assets/uo/` (gitignore) — mimo jiné **`anim/` (30 PNG + `anim-sheets.json`)** a `anim-manifest.json` |

## Stav kódu (počty řádků Pythonem `splitlines()`, bez `.uid` a `__pycache__`)

| složka | souborů (kód) | řádků kódu | poznámka |
|---|---|---|---|
| `core/` | 7 | 339 | hotové a otestované |
| `sim/` | **12** | **1 439** | nově `entity/skills.gd`, `entity/mobile.gd`, `world/walk.gd`, `systems/movement.gd`; `systems` **už není prázdné** (registruje `app/main.gd`) |
| `render/` | **4** | **430** | `sort.gd`, `texture_cache.gd`, `chunk_renderer.gd`, **`anim_player.gd`**; `ui/` pořád neexistuje |
| `app/` | **6** (5 kód) | **565** | nově **`player_controller.gd`** (bez granule); `main.gd` a `world_view.gd` rozšířené |
| `tests/` | **33** (26 kód) | **2 713** | **23 case souborů** (+5 za tuhle session) |
| `tools/uoextract/` | 38 | 6 278 | `anim.py` umí pixely, `--export`, `--export-check` |
| `tools/gates/` | **21** | **4 464** | nově `mutace-anim.py`, `mutace-skills.py`, `mutace-render-anim.py` |

*(Počty jsou Pythonem `splitlines()` nad kódovými soubory `.gd`/`.py`/`.sh`/`.mjs`,
bez `.uid` a `__pycache__` — `python _analyza/radky.py`.)*

**Zbývá 62 granul.** Hotové (souborem i měřením) navíc: `assets.anim` (pixely),
`render.anim`, `data.skills`, `entity.skills`, `entity.mobile`, `world.walk`,
`sim.movement` — **7 nových** proti minulému předání.

## Co je hotové a ověřené (ne „soubor existuje")

**M0 celek** · **W0** (8) · **M1: uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc, anim (VČETNĚ pixelů), data.items, data.gen_content,
data.recipes, world.tiledata, world.map, render.sort, render.textures,
render.chunk, render.anim** · **M2: world.doors, world.stairs, entity.stats,
world.time, entity.skills, entity.mobile, world.walk, sim.movement,
data.skills** · **integrace (bez granul): `app/player_controller.gd`,
`app/world_view.gd` (kreslení postavy), `app/main.tscn` (uzly),
`app/main.gd` (registrace systémů)**.

Doklady, které jsem dnes viděl na vlastní oči (ne opsané z předání):

- **Na snímku je mapa Britainu i postava** — `read_image` na
  `.cache/render/chuze/frame00000130.png`.
- **Postava se pohnula po skutečných klávesách** — log řidiče `demo-chuze.gd`:
  6 pozic, směry 0/2/7/4, animace `4 ↔ 0`.
- **Postava je z dat, ne kreslená**: výřez z `anim.mul` (tělo 400, 10 framů chůze),
  0 pixelů mimo frame na 30 blocích.
- **Testy 422/0**, **brány 11/0/0** (`exit 0`), **mutace 34/34 + 8/8 + 8/8**.
- **Hra nespadne**: G11 `smoke` → `framu 120, script_error 0, parse_error 0`.

### ⚠ Co na obrazovce ještě NENÍ

Souboj, magie, obchod, řemeslo, UI (žurnál, status bar, paperdoll), jména nad
postavami, světlo (`render.light`), výbava na postavě (vrstvy), druhé postavy,
mount, pathfinding, zvuk. **Hratelná mechanika: chůze a otáčení.** Postava je
šedá (paleta z bloku je šedý ramp; kůže = hue, `render.hue` chybí).

## Co brány dnes měří (2026-10-06 noc, 2. session)

`run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 VADA**, `exit 0`.

| Brána | Výsledek | Je to vada kódu? |
|---|---|---|
| G1–G11 | **OK** | NE |
| G6 | OK — nově měří `anim_decoder_kod: 0`, `anim_decoder_kontrol: 35` | NE |
| G10 | OK — `barev: 2148`, `pixelu_mimo_pozadi: 892553` (snímek S postavou) | NE |
| G13 | PORADNÍ | NE — `vision.mjs` není (poradní je podle `docs/08 §8.2`) |

## Předletová kontrola (5 minut, než začneš psát)

| Co | Jak | Očekáváno (2026-10-06 noc, 2. session) |
|---|---|---|
| Strom je čistý | `git status --porcelain -uall` | **prázdné** po commitu této session |
| Je před GitHubem | `git rev-list --count origin/main..HEAD` | **`0`** — tato session **pushuje** (uživatel povolil) |
| **Běží CI?** | `node _analyza/ci-beh-stav.mjs` | poslední běh nad `c3617e5` byl `success` (běh #11); novější commity uvidíš tam |
| Repo je veřejné | API bez tokenu | `visibility: public` |
| Testy | testy s `APPDATA` ve workspace | `422 kontrol, 0 selhání` |
| Brány | `python tools/gates/run-all.py` | `11/0/0`, `exit 0` |
| Self-testy | `python tools/gates/run-all.py --self-test` | `19, 0 chyb`, `exit 0` |
| Mutační důkaz | `mutace-tests.py` + `mutace-anim.py` + `mutace-skills.py` + `mutace-render-anim.py` | `34/34`, `8/8`, `8/8`, `9/9` |
| Animace | `python tools/uoextract/anim.py --self-test` | `35 kontrol, 0 chyb` |
| Data skillů | `python tools/gates/gen-content.py --only skills --check` | `OK skills.json: shoda` |
| Fixture sedí na generátor | `python tests/fixtures/world/make_fixture.py --check` | `4× OK`, `exit 0` |
| **Snímek je z běhu** | `Get-Item .cache/render/snapshot.png \| % LastWriteTime` | **dnešní** (je to frame z chůze) |
| Godot běží | `& .cache\godot\...console.exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |
| Instalace UO na místě | `Test-Path 'D:\Games\...\tiledata.mul'` | `True` |
| Kontroly zadání | `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` | `exit 0` |
| **Sandbox** | `whoami /groups \| Select-String Mandatory` | **`Medium`** = plný přístup |

## Otevřené věci a co je potřeba dodělat

**Přenáším z minulého předání (nic se nemaže) — u každé je dnešní stav:**

1. **Soubory bez testu** — **PLATÍ DÁL, ale je jich méně**: test má nově
   `world/walk.gd`, `systems/movement.gd`, `entity/skills.gd`, `entity/mobile.gd`,
   `render/anim_player.gd`, `app/player_controller.gd`. **Bez testu zůstávají**
   `world/tiledata.gd`, `app/main.gd`, `app/main.tscn`, `render/texture_cache.gd`,
   `render/chunk_renderer.gd`, `app/world_view.gd`, `app/loop.gd`.
2. **`size_lines` nesedí** — **PLATÍ DÁL a přibylo to**: `world/walk.gd` **~135**/120,
   `sim/systems/movement.gd` **~150**/120, `entity/skills.gd` **~100**/60,
   `entity/mobile.gd` **~75**/60, `render/anim_player.gd` **121**/120,
   `world.map` **210**/120, `texture_cache.gd` 141/60, `chunk_renderer.gd` 110/150,
   `app/world_view.gd` (bez deklarace) a `data/skills.json` **640**/60 (JSON!).
   **Rozhodnutí pro uživatele:** uvolnit deklarace, nebo dělit granule.
3. **Tvar objektu pro `render.sort` patří do `docs/04 §4.2`** — **PLATÍ DÁL**;
   navíc tvar prvku `render.chunk` a rozšíření `world.map.statics_at` o `x`,`y`.
4. ~~G10 měří snímek z bootstrapu~~ — **VYŘEŠENO 2026-10-06.**
5. **13 generátorů v `POZADOVANÉ` chybí** — **PLATÍ DÁL** (jeden ubyl: `skills` je hotový).
6. ~~Pixely animací~~ — **VYŘEŠENO 2026-10-06** (dekodér + export + snímek).
7. **`assets.uop` (2 rozpory) a `assets.verify`/`assets.extract_cli`** — **PLATÍ DÁL.**
8. **Zastaralé poznámky v `tools/uoextract/worldmap.py`** — **PLATÍ DÁL.**
9. ~~`atlas.py`: vada rozložení~~ — **VYŘEŠENO 2026-10-06.**
10. **`docs/11 §11.6` vs `docs/03 §3.5.1`** — **PLATÍ DÁL** (vnitřní rozpor).
11. **Počet granul v dokumentech: 101 / 100 / 75–90** — **PLATÍ DÁL.**
12. **Světlo „den 12" vs `DayLevel = 0`** — **PLATÍ DÁL.**
13. **Rešerše hlásily dvě „vady", které neobstály** — **PLATÍ DÁL** jako varování;
    **dnes k tomu přibyl třetí případ**: rešerše `anim-mereni.md` tvrdila, že
    pixely těl **nelze** dekódovat — šlo dekódovat (viz výš). Poučení je v `LESSONS`.
14. ~~CI neproběhlo ani jednou s nenulovým počtem jobů~~ — **VYŘEŠENO** (běh #10, #11).
15. **`statics_at` vrací nadmnožinu** — **PLATÍ DÁL**; `world.walk` si proto
    filtruje statiky sám (a má na to test i mutaci).
16. **`check-wiring` nevidí volání UVNITŘ granule** — **PLATÍ DÁL** (vada brány).
17. **`app/world_view.gd` a uzly v `app/main.tscn` nemají vlastníka** — **PLATÍ
    DÁL**; dnes k nim přibyl **`app/player_controller.gd`** (taky bez vlastníka).
18. **`app/input_map.gd` se volá bez vazeb** (`ui.hotkeys` nemá soubor) —
    **ČÁSTEČNĚ VYŘEŠENO**: vazby i `InputMap` akce zakládá
    `app/player_controller.gd` (12 vazeb za běhu). **Patří to ale do `ui.hotkeys`**
    — až vznikne, vazby se odsud přesunou.
19. **Výkonnostní dluh: `AtlasTexture` na objekt** (`UNVERIFIED`) — **PLATÍ DÁL.**
    Nové číslo: ve snímku s postavou se kreslí **5 771 objektů**.
20. ~~Až CI ožije, bude červené kvůli chybějícím assetům~~ — **VYŘEŠENO.**
21. **`tests/run_tests.gd` tiše přeskočí case soubor s parse errory** — **PLATÍ
    DÁL** (věc 21 z minula; oprava `script.can_instantiate()`).
22. **Replay neměří příkazy** (jiné příkazy = stejný hash) — **PLATÍ DÁL**:
    `sim.movement` je zaregistrovaný **jen v `app/main.gd`**, takže replay přes
    `sim_probe.gd` (bez scény) ho nemá a pohyb v replayi nic nezmění. **Až se
    systém registruje v `SimWorld`, replaye přeměřit a hash aktualizovat.**
23. **`sim/world/map.gd` má volitelné cesty** — **PLATÍ DÁL**; stejný princip
    dnes dostal `world/walk.gd` (mapa/tiledata/stairs konstruktorem).
24. **`.gitignore` má výjimku `!tests/fixtures/world/*.idx`** — **PLATÍ DÁL.**
25. **`run-all.py` u G3 nevypíše, co naměřila** — **PLATÍ DÁL**.
26. **Když krok CI spadne, navazující kroky se PŘESKOČÍ** — **PLATÍ DÁL**
    (řešení `if: always()`; rozhodnout, zda to chceme).
27. **NOVÉ: držení klávesy neopakuje krok.** `app/input_map.gd` čte jen
    `is_action_just_pressed`, takže chůze je „jedno zmáčknutí = jeden krok".
    Držení (jak to dělá UO) patří do `app.input` — **granule `app.input`, agent ji
    needituje bez rozhodnutí uživatele**.
28. **NOVÉ: `render.anim` neumí vrstvy výbavy.** Prompt granule žádá „skládej
    vrstvy výbavy podle layerů" — bez `entity.equipment` a `render.hue` to nejde;
    dnes se kreslí jen tělo.
29. **NOVÉ: `play(serial, ...)` bere `serial` jako ČÍSLO TĚLA.** Registr bytostí
    (`serial -> body`) v projektu není (`sim_world.snapshot()` vrací
    `mobiles: []`), takže `render.anim` nemá odkud tělo vzít. Je to díra ve
    smlouvě (`docs/04 §4.2` tvar `play` neuvádí) — patří do docs.
30. **NOVÉ: `sim.movement` si mobily drží sám** (`register`). Smlouva říká
    `request_step(m:int, ...)`, ale neříká, kde systém mobily vezme; žádný
    registr mobilů v projektu není. Patří do `docs/04 §4.2` (a do `sim.world_loop`).
31. **NOVÉ: `Door` a `Container` v průchodnosti.** `world.walk` blokuje
    `Impassable`/`Wet`/`Container` na statikách, ale **otevřené/zavřené dveře
    neřeší** (`Door` flag se ignoruje) a **výška schodů se nepočítá** — schody
    fungují jako `Surface`. Patří do `world.walk` (další session).
32. **NOVÉ: řidič dema je v `.cache/` (gitignore).**
    Důkaz chůze (`demo-chuze.gd`) se v čistém klonu nespustí. Kdyby měl být
    reprodukovatelný z gitu, patří do `tools/gates/` (rozhodnutí uživatele).
33. **NOVÉ: `render.anim` nemá LRU/strop pameti.** Stránku spritu drží jednou na
    soubor (frame je `AtlasTexture`; změřeno 1,27 MB vs 12,2 MB při kopii na
    frame), ale `render.textures` strop má a tohle ne. Kandidát na později.
34. **NOVÉ: PNG z `res://assets/uo/anim/` se načítá `Image.load()`** → Godot
    hlásí `WARNING: Loaded resource as image file, this will not work on export`.
    Stejný vzor jako `render/texture_cache.gd`; **pro export build to bude
    potřeba vyřešit** (importovat PNG jako resource). Netýká se běhu ze zdrojů.
35. **NOVÉ: `tools/refs-index.py --check` není v CI ani v `run-all.py`.**
    Rejstřík se tím může rozejít s diskem (a nikdo si toho nevšimne). Do
    `ci.yml` patří jako samostatný krok vedle `mutace-tests.py`. **Pozor: musí
    běžet na stroji, kde jsou klony `_src/`** — bez nich `--check` u odkazů
    hlásí CHYBÍ STROM (což je správné chování, ale v CI by to bylo červené).
    Rozhodnutí: buď klony v CI nemít a `--check` tam nepouštět, nebo ho pouštět
    jen na „stromy, které existují".
36. **NOVÉ: `research/_src/{servuo,modernuo}` jsou duplicitní checkouty**
    (ne junctiony, oba 2× na disku). Nejsou v gitu, ale zabírají místo a pletou
    rejstřík. **Nic se nemazalo** — rozhodnutí uživatele.
37. **NOVÉ: repo nemá `LICENSE`.** Reference v `_src/` jsou GPL-2.0 (RunUO,
    ServUO), GPL-3.0 (ModernUO), BSD-2 (ClassicUO), Apache-2.0 (Sphere). Z GPL
    zdrojů se smí vzít **fakt nebo formát, ne kód** — ale bez licence našeho
    repa je i publikování samo o sobě nerozhodnuté.
38. **NOVÉ: `refs-index.py` měří jen soubory s kódovými příponami**
    (`.cs`, `.cpp`, `.h`, `.hpp`, `.gd`). Odkaz na `.csproj`, `.json`, `.tbl`
    nebo `.md` by hlásil 0 nálezů (a spadl jako mrtvý). Proto jsou sondy volené
    tak, aby vedly na **kód**, který tu věc používá — a je to i užitečnější.
39. **NOVÉ (a důležité): ve workspace může běžet PARALELNÍ SESSION.**
    Naměřeno 2026-10-06 ~22:21: během psaní rejstříku vznikly soubory
    `render/hue_cache.gd`, `tests/cases/render_hue.gd`, `tools/gates/mutace-render-hue.py`
    a změny `app/main.gd` + `app/world_view.gd` (zapojení `render.hue`, barva kůže)
    — **nejsou z této session** a v době commitu byly zelené (testy 444/0,
    brány 11/0/0). **Pravidlo: než začneš psát, podívej se na `git status`
    a na `LastWriteTime` souborů, které nejsou tvoje** — jinak zapíšeš do cizí
    práce (nebo ji commitneš jako svou). A **necommituj cizí soubory**: `git add`
    jen na své cesty.

## Už není otevřené (přesunuto, nemaže se)

- **„Na obrazovce není nic"** — vyřešeno 2026-10-06 (snímek z běhu, G10 zelená).
- **„Na obrazovce není postava"** — **vyřešeno 2026-10-06 (2. session)**: postava
  je na snímku a chodí (důkaz: řidič + log pozic).
- **„Pixely animací nejdou dekódovat"** (blokátor z 2026-10-03) — **vyřešeno**:
  znamenkové 10bitové `x`/`y`, paleta v prvních 512 B bloku, 1 bajt na pixel.
- **„`systems` v SimWorld je prázdné"** — vyřešeno pro `movement` (registruje
  `app/main.gd`); ostatní systémy (combat, craft…) pořád chybí.
- **„`input_map.poll()` se nikdy nezavolá"** — **NEBYLA to pravda** (vada ZADÁNÍ):
  `loop.input_map` je reference a `poll()` se volá z `app/loop.gd:32`; `input_map`
  je `RefCounted`, takže do stromu přidat nelze. Skutečná příčina mrtvých kláves
  byla **prázdné `bindings` a žádné akce v `InputMap`**.
- **„`render.sort` nemá volajícího z produkce"** — vyřešeno (`draw_order`).
- **„G10 měří 4 dny starý artefakt"** — vyřešeno (snímek je z dnešní chůze).
- **„Repo je privátní"**, **„12 commitů není před GitHubem"** — vyřešeno.
- **„`tools/uoextract/atlas.py` není v gitu"**, **„`assets.atlas` není hotový"** — vyřešeno.
- **Podezření, že brány jsou zelené nad vadou** — prověřeno i dnes: každá nová
  kontrola má mutaci (34/34 + 8/8 + 8/8), **a jedna brána se opravdu chytila**
  (G6 tvrdila zestárlé „dekodér není" — opraveno na měření).
- **Podezření, že v repu jsou tajemství** — prověřeno 2026-10-06.
- **„Replaye nemá co měřit"** — vyřešeno (2 replaye), ale viz otevřená věc 22.
- **„CI neběží — 9 běhů s 0 jobů"** — vyřešeno (běh #11 `success`).
- **„Až CI ožije, bude červené kvůli chybějícím assetům"** — vyřešeno (G6 i G10
  hlásí NEMĚŘENO, krok s branami toleruje `exit 2`).

## Další kroky (v tomto pořadí)

0. **Než začneš hledat cokoli v referencích:** otevři
   `research/REJSTRIK-REFERENCI.md` a použij jeho řádek („otázka → `soubor:řádek`
   + jak ověřit"). Nález, který se nezmění v tvrzení v našem kódu + test, je dojem.
1. **Pushnout a zkontrolovat CI** na nových commitech (tato session pushuje).
2. **Opravit slepé místo v `tests/run_tests.gd`** (`script.can_instantiate()`
   před `script.new()`) — pořád jediná známá slepá brána (věc 21).
3. **`render.hue`** (`render/hue_cache.gd`, `hues.mul`): bez něj je postava šedá
   a nejde obléknout. Je to i vstup pro vrstvy výbavy (věc 28).
4. **Držení klávesy = chůze** (`app.input`, věc 27) — bez toho se demo ovládá
   „klikatě".
5. **Dveře a schody v `world.walk`** (věc 31) + `world.doors` napojit.
6. Pak M2 zbytek: `entity.item`, `entity.container`, `entity.equipment`,
   `entity.notoriety`, `world.teleport`, `world.regions`; a **zaregistrovat
   systémy v `SimWorld`** (věci 22 a 30) — tím se replaye rozhýbou.
7. (nepovinné) `if: always()` u diagnostických kroků CI (věc 26) a doplnit tři
   mutační harnessy do `ci.yml`.

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Mutační test je to, co odlišuje měření od dojmu** — a musí ověřit **čtyři**
  věci: že se mutace provedla, že test **proběhl** (`N kontrol`, N > 0), že
  selhal **na kontrole daného modulu**, a že test **bere měřenou cestu
  z argumentů** (zkus mu předat neexistující cestu — musí selhat).
- **Vizuální změna se ověřuje pohledem** (`read_image`), ne jen testy: dnes to
  ukázalo (a) že postava je na mapě, (b) že stojí 40 px nad středem (kamera
  ignorovala `z`).
- **Druhá implementace téhož formátu je jediná obrana** — dnes to byl
  **referenční klient** (`_src/classicuo/.../AnimationsLoader.cs`): tři věty
  z něj rozluštily formát, na kterém rešerše tvrdila, že rozluštit nejde.
- **Data, která v CI nejsou, testuj na fixture v gitu** — a reálná data měř
  navíc, když jsou; když nejsou, řekni to nahlas (NEMĚŘENO), ale neselhávej.
- **Hotový soubor bez volajícího je mrtvý kód** — ptej se „kdo to volá".
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA.**
- **Když implementace odhalí díru ve smlouvě, napiš ji do hlavičky souboru**
  (`movement.gd`, `anim_player.gd`, `walk.gd`) a zaznamenej jako otevřenou věc.

## Pasti, které už někoho stáhly čas (naměřené)

1. **`==` na `Array` v GDScriptu porovnává OBSAHEM** — na identitu `is_same()`.
2. **V mutačním harnessu musí test brát všechny měřené cesty z argumentů.**
3. **Test stropu musí pracovní sadu PŘEKROČIT.**
4. **`"MERENO:"` je podřetězec `"NEMERENO:"`** — parsuj i s hranatou závorkou.
5. **`provides` bez `(` není „volatelné jméno"** (`check-wiring`).
6. **Sandbox `workspace-write` (Low integrita) blokuje zápis do `.cache`** →
   G7 hlásí falešnou vadu a `run-all.py` padá na `summary.json`.
   **Tato práce potřebuje plný přístup** (`whoami /groups` → `Medium`).
7. **`map0.land` má na každém bloku 4B hlavičku**, statika je 7 B se `z` na
   offsetu 4.
8. **Godot s nerozjetým skriptem visí** — vždy `--quit-after N`.
9. **`.uid` vzniká jen při importu** a **patří do gitu** (dnes 13 nových).
10. **`JSON.parse_string` vrací všechna čísla jako `float`** — vždy `int()`.
11. **`.gitignore` je na Windows case-insensitive** — kontroluj `git ls-files`.
12. **`Measure-Object -Line` nepočítá prázdné řádky** — měř Pythonem.
13. **Brána, která nic nezměří, není zelená** (`exit 2` = NEMĚŘENO).
14. **Heredoc v PowerShellu neexistuje** — piš skript do souboru.
15. **Snímek pro G10 vzniká jen s `--rendering-driver opengl3`.**
16. **`Get-Content | -replace | Set-Content` zničí `.py`** — edituj tool
    `edit`/`write` a ověř první tři bajty (`EF BB BF` = BOM).
17. **`script.new()` na souboru s parse errory přeruší volající funkci** (věc 21).
18. **NOVÉ: RLE hlavička v `anim.mul` má ZNAMENKOVÉ 10bitové `x`/`y`.** Kdo je
    čte bez znaménka, dostane `1020..1023` („mimo rozměr") a **vypadá to jako
    nerozluštěný formát** — přitom je to `-4..-1`. Pozná se to tak, že **každá
    hlavička končí bajtem `0xFF`** (horní bity záporného čísla).
19. **NOVÉ: `--write-movie` potřebuje DOPŘEDNÁ lomítka a existující složku.**
    S `.\cache\render\run\frame.png` vznikne jen `frame.wav` a v logu je
    `Condition "f_wav.is_null()" is true` — vypadá to jako rozbitý záznam
    obrazu, přitom jde o cestu. S `.cache/render/run/frame.png` to jde.
20. **NOVÉ: kamera musí dostat `z`.** `iso.to_screen` odečítá `z * Z_SCALE`;
    kamera na `z = 0` postaví postavu na `z = 10` o **40 px** nad střed.
21. **NOVÉ: mutační harness, který importuje mutanta z `.cache`, musí do
    `sys.path` přidat `tools/uoextract`** — jinak `ModuleNotFoundError` a
    **vypadá to jako chycená mutace** (přesně ten falešný důkaz, který měl starý
    `mutace-atlas.py`). Harness to musí hlásit jako chybu harnessu.
22. **NOVÉ: mutace, která se tiše neprovede, tvrdí totéž co ta, která projde.**
    Dnešní `mutace-anim.py` našel **dvě slepá místa** (maska běhu 12 bitů, paleta
    z offsetu 0) — proto přibyly kontroly s během 300 pixelů.
23. **NOVÉ: brána může nést ZESTÁRLÉ TVRZENÍ jako kód** (`check-assets.py`
    zakazovala `pixels_decoded: true`). Když se měření změní, brána nesmí
    „tvrdit opak" — musí **měřit, že to platí** (dnes: recept v manifestu +
    self-test dekodéru). A nová kontrola musí mít známý správný i chybný případ.

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03 §3.4` — index bloku mapy**: opraveno na `bx * blocks_y + by`.
2. **`docs/03 §3.4` — záznam statiky**: `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
3. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; správně `assets/uo/tiles.json` a `data/items.json`.
4. **`docs/04 §4.2` u `world.map`** nerozlišuje `tiledata id` a `art id` u statiků.
5. **`docs/04 §4.2` u `render.sort` neuvádí tvar objektu** (a nově ani
   u `render.chunk`, `render.textures`, **`render.anim`**); chybí i `world.map`
   s volitelnými cestami a tvar `tests/fixtures/world/`.
6. **`docs/04 §4.2` u `render.anim` neuvádí TVAR NÁVRATU `play(...)`** a neříká,
   **odkud se pro `serial` bere číslo těla** (věc 29). Dnešní implementace vrací
   `{ok, texture, frame, count, anchor, mirror, mirror_x, sprite_dir}`.
7. **`docs/04 §4.2` u `sim.movement` neříká, kde systém vezme mobily** (věc 30).
8. **`docs/04 §4.5` vs `§4.2` u mobila si odporují**: §4.5 má
   `skills: PackedInt32Array`, tabulka `skills: Skills`; §4.5 `equip: Dictionary`,
   tabulka `equipment: Equipment`; §4.5 má `name`/`hunger`/`ai`, tabulka ne;
   §4.5 má `str/dex/int`, tabulka `stats`.
9. **`docs/06 §6.2`** uvádí 6 nástrojů, které v instalaci NEJSOU.
10. **`.forge/roadmap.json` — `size_lines` nesedí** (věc 2), a **`data.skills`
    má `<= 60`**, přitom generovaný JSON má **640 řádků**.
11. **`app/main.tscn` + kamera + kreslicí uzel + `app/player_controller.gd`
    nemají vlastníka** v roadmapě.
12. **V roadmapě chybí vlastník pro pathfinding.**
13. **Soubor pro zvuk/hudbu nemá žádná granule** (0× `AudioStream`).
14. **`docs/07 §7.3` (vlny) pokrývá 62 granul z 101.**
15. **`ZADANI-DALSI-VYVOJ` §7 zakazuje měnit `tests/`**, ale acceptance
    `render.textures`/`render.chunk`/`render.anim`/`data.skills` žádá `tests`;
    uživatel 2026-10-06 povolil **nové** soubory v `tests/cases/`.
16. **`docs/09 §9.6` (mutační test) neuvádí čtvrtou podmínku** — že test bere
    měřenou cestu z argumentů.
17. **NOVÉ: `ZADANI-DALSI-VYVOJ` §3 úkol 5 tvrdí, že se `input_map.poll()`
    „nikdy nezavolá"** — není to pravda (viz „Už není otevřené") a `input_map`
    ani nejde přidat do stromu (`RefCounted`). Skutečná vada byla jinde.
18. **NOVÉ: `docs/05 §5.16` uvádí `implemented: false` u DEVÍTI skillů,
    zadání granule `data.skills` u SEDMI** (chybí Chivalry a Focus).
    Data sledují `docs/05` (9) a test ověřuje obojí.
19. **NOVÉ: pořadí skillů 55–57 se rozchází** — `skills.mul` této instalace má
    55 Throwing / 56 Imbuing / 57 Mysticism, `research/02` §3.9+§7.3 a ClassicUO
    mají 55 Mysticism / 57 Throwing. Staty se v datech berou **podle jména**.
20. **NOVÉ: `docs/03 §3.9.3` tvrdí, že skupina skillů „id 6" je bez jména** —
    bez jména je skupina **0** (7 skillů), id 6 = „Bard" (ověřeno proti
    `skillgrp.mul` i ClassicUO `SkillsGroupManager`).
21. **NOVÉ: `docs/03 §3.5.1` (a `research/anim-mereni.md`) tvrdí, že pixely
    `anim.mul` nelze dekódovat** — jde to (recept v `tools/uoextract/anim.py`).
22. **NOVÉ: `docs/04 §4.2` u `render.anim` žádá „skládej vrstvy výbavy podle
    layerů"**, ale `entity.equipment`/`render.hue` v plánu etapy nejsou.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (`docs/02 §2.6.8`).
- **Nečeské znaky nepatří do identifikátorů** — GDScript je neumí.
- Piš **jen do `owns`** své granule; **výjimka 2026-10-06 (rozhodl uživatel)**:
  nové soubory v `tests/cases/`, `tests/replays/`, `tests/fixtures/`
  a `tools/gates/`; **a integrace podle `ZADANI-DALSI-VYVOJ §3 úkol 5**
  (`app/main.gd`, `app/main.tscn`, `app/world_view.gd`, `app/player_controller.gd`).
  Gate `check-assets.py` a `mutace-tests.py` jsem dnes upravil proto, že **měření
  se změnilo** (G6 nesla zestárlé tvrzení) — v předání je to napsané.
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet.
- `run-all.py`: 0 = vše měřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není zelená).
- Testy potřebují `APPDATA` ve workspace; **brány si to nastavují samy**.
- **Push je povolený** (uživatel 2026-10-06: „máš povoleny commity i pushe").
