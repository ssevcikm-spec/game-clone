# 2. Technická rozhodnutí

> Oddíl je **závazný**. Když se v implementaci ukáže, že rozhodnutí nejde
> dodržet, mění se **nejdřív tento dokument** a teprve pak kód
> (`09-pravidla-pro-agenta.md` §1).

## 2.1 Engine a jazyk

| Věc | Rozhodnutí | Důvod |
|---|---|---|
| Engine | **Godot 4.7.2 stable** | je na stanici (`orchestra\tools\godot\`), zvládá 2D iso scénu, má headless testy, export na Windows |
| Jazyk | **GDScript, typovaný** (`var x: int = 0`, `func f(a: int) -> void:`) | žádná kompilace, agenti ho umí, testy se pouští `--headless --script` |
| Renderer | **Forward+ / Mobile** — hra je 2D, použij `CanvasItem` a `_draw()`; `gl_compatibility` jen pro CI snímky | snímky v CI běží na `opengl3` |
| Verzování | git, `main` je vždy spustitelná | CI běží na každý push |

**Godot past, která se už jednou zaplatila:** `--user-data-dir` tento build
**ignoruje** — `user://` jde do `%APPDATA%\Godot\app_userdata\<projekt>`.
V sandboxu je to mimo workspace, takže se „nic neuloží" a vypadá to jako vada
ukládání. V testech a v CI přesměruj `APPDATA` do workspace:

```powershell
$env:APPDATA = "$PWD\.tmp\godot-appdata"
```

## 2.2 Architektura běhu: klient a simulace v jednom procesu

**Toto je nejdůležitější technické rozhodnutí celého projektu.**

UO je klient/server. Všechny jeho charakteristické vlastnosti (krokový pohyb
s prodlevou, target cursor, gumpy, „swing" timer, zpožděné sesílání, fronta
příkazů, kterou server může odmítnout) pocházejí z toho, že klient **posílá
záměr** a server **rozhoduje**. Když klon slepí ovládání a simulaci dohromady,
věrnost se rozsype a kód se stane netestovatelným.

Proto:

```
        ┌──────────────── UI + RENDER (klient) ────────────────┐
        │  čte: snapshot stavu (read-only) + frontu událostí    │
        │  píše: jen Command do fronty příkazů                  │
        └───────────────┬───────────────────────▲──────────────┘
              Command   │                       │  Event
                        ▼                       │
        ┌──────────────── SIM (server) ────────┴───────────────┐
        │  autorita: pozice, hp, skilly, inventář, svět, čas    │
        │  deterministický: pevný tick, seedovaný RNG, žádné IO │
        └──────────────────────────────────────────────────────┘
```

Pravidla, která z toho plynou a jsou **vynutitelná bránou**:

1. `sim/` **nesmí** volat nic z `ui/`, `render/` ani `app/` (kontrola importů).
2. `ui/` a `render/` **nesmí** měnit stav v `sim/` — jen přes `Command`.
3. `sim/` **nesmí** používat `Input`, `Time`, `OS`, `randf()`, `randi()`,
   `Node2D` ani signály scény. Čas jde z `SimClock`, náhoda z `SimRng`.
4. Simulace musí jít spustit **bez stromu scény** (headless test):
   `var sim := SimWorld.new(seed)` a pak `sim.tick(50)` v cyklu.
5. Každá akce, která v UO trvá čas, je v simulaci **timer v ms**, ne okamžitá
   operace (krok, swing, sesílání, výroba, obchod, otevírání).

Tím se získá: testovatelnost bez enginu, determinismus, replays ze skriptu
příkazů a věrné časování — a zároveň se dá udělat „záznam hraní" jako test.

## 2.3 Čas, RNG, determinismus

| Věc | Rozhodnutí |
|---|---|
| Tick simulace | **pevný, 50 ms (20 Hz)**; všechny timery v ms, zaokrouhlené nahoru na tick |
| Čas světa | `world_time_ms: int` od startu hry; den = 24 herních hodin (`DAY_LENGTH_MS` konstanta, viz §5.11) |
| Náhoda | **PCG32** (`sim/rng.gd`), stav v simulaci, seed v uložené hře; `SimRng.range_i(a,b)`, `SimRng.chance(p)` |
| Zákaz | `randi()`, `randf()`, `Time.get_ticks_msec()`, `OS.get_unix_time()` uvnitř `sim/` |
| Iterace | nad **sorted** klíči, nikdy nad `Dictionary.keys()` v pořadí vložení (Godot mění řazení mezi běhy u hashovaných klíčů) — jinak se rozbije determinismus |
| Test determinismu | spusť 20 000 ticků se skriptem příkazů dvakrát → `state_hash()` musí být stejný |

`state_hash()` = SHA-256 kanonické serializace stavu (seřazené entity podle
serialu, seřazené klíče vlastností, žádné floaty).

## 2.4 Souřadnice, izometrie, vykreslování

| Konstanta | Hodnota | Význam |
|---|---|---|
| `TILE_W` | **44** | šířka artu dlaždice (originální art) |
| `TILE_H` | **44** | výška artu dlaždice (diamant zabírá celou šířku) |
| `ISO_STEP` | **22** | posun po jedné ose dlaždice v pixelech (44 / 2) |
| `Z_SCALE` | **4** | pixelů na jednu jednotku světové výšky `z` |
| `Z_MIN`, `Z_MAX` | **−128 … 127** | rozsah `z` (jako v datech UO) |
| Projekce | `screen.x = (x − y) * 22`, `screen.y = (x + y) * 22 − z * 4` | + offset kamery |
| Inverze | `x = (sy / 22 + sx / 22) / 2`, `y = (sy / 22 − sx / 22) / 2` (se z) | pro klik do světa |
| Rozsah mapy | 7168 × 4096 dlaždic, `z` v blocích po 8×8 | faceta 0 |

**Řazení (occlusion) — musí být jedna funkce, ne rozházené `z_index`:**
kreslí se po dlaždicích ve směru rostoucího `x + y`; v rámci jedné dlaždice
**podle `priority_z` vzestupně** a teprve při shodě `z` rozhoduje druh objektu
(land → statics → mobilové). Statiky s `Surface` flagem tvoří „povrch" pro
postavení.
**`priority_z` NENÍ `z` z mapy** (opraveno 2026-10-07): statik s výškou jde `+1`,
podlaha (`IsBackground`, flag `0x1`) `−1` — stejně jako `PriorityZ` v ClassicUO
(`Chunk.cs:246-272`). Bez toho měly plocha mostu a jeho zábradlí stejný klíč a
rozhodovalo pořadí v souboru mapy (naměřeno: 11 271 shod `z`, z toho 6 401
s vadou, 71 nad vodou — `REVIZE-POHYB-2026-10-07.md` §2.6).
**⚠ Do 2026-10-08 byla v klíči vrstva PŘED `z`** (`(diagonal*3 + layer)*256 + z`),
takže statik na téže diagonále šel před mobilem, i když byl výš — uživatel to
viděl jako „postavu, která stojí na střeše" (naměřeno: 5 dlaždic v Británii,
kde střecha ≥ 8 jednotek nad hráčem překrývala jeho sprite a kreslila se před
ním, `_analyza/p20a-nalez.md`). Dnes platí
`pruchod*PASS_SPAN + diagonal*K_PER_DIAGONAL + (z−Z_MIN)*LAYERS + layer`, což
odpovídá referenci: ClassicUO `GameObject.CalculateDepthZ()`
(`_src/classicuo/.../Views/View.cs:83`) = `(x + y) + (127 + z) * 0.01f`.
Dvě věci se přitom **měřily proti referenci a do 18. session byly špatně**
(obojí vadami ze snímků uživatele, `_analyza/p21-*`):

1. **Váha `z` byla moc malá.** `K_PER_DIAGONAL = 769 > Z_SPAN * LAYERS = 765`,
   takže `z` nepřebilo ani jednu diagonálu; reference má váhu `0.01` proti `1.0`,
   tedy **`z` přebije ~2,55 diagonály**. Dnes je krok **300** (`765 / 2,55`) —
   na tom stojí „zeď přes střechu“ (střecha o 1–2 diagonály dál a výš se kreslí
   **po** bližší nízké zdi).
2. **Land byl ve stejném průchodu jako statiky.** Reference kreslí land
   ve **zvláštním průchodu před statiky** (`RenderLists.cs:199-232`: mesh land →
   `_tiles` → `_stretchedTiles` → mesh statics → `_statics`), takže statik
   **nikdy** nemůže být překreslen půdou. U nás šel svah (land s vysokým `z`)
   ve stejném seznamu a **překresloval schody i most**. Dnes je průchod
   (`PASS_LAND = 0`) nejvyšší řád klíče.

**⚠ Vědomé omezení (zapsané, ne zamlčené):** reference má pod objekty
**z-buffer**, takže kopec (land) vpředu schová statik za sebou; náš painter's
algoritmus s landem vždy pod statiky statik za kopcem **nechá vidět**. Je to
cena za to, že svah nepřekresluje schody ani most.

Konkrétní klíč řazení je v `render/sort.gd` a je **pokrytý testem** (dva objekty
na stejné dlaždici různého `z` → pořadí; při stejném `z` rozhoduje vrstva;
`z` přebije 1 i 2 kroky mřížky, ale **ne 3**; land je před statiky i s nejvyšším
`z` na nejbližší diagonále). Dělení dávky na „před hráčem“/„po hráči“ se dělá
podle **celého klíče** (`render.chunk_mesh.split_for_player(klic)`, binární
hledání v neklesajícím poli klíčů) — dělení podle diagonály by od 18. session
řezalo na špatném místě.

**Chunkový renderer:** svět se kreslí po blocích 8×8 dlaždic. Pro každý
viditelný blok se sestaví seznam kreslení (land + statiky + mobilové v dosahu),
který se cachuje a přepočítá jen při změně bloku nebo kamery. Cíl: **jen
viditelné bloky**, aby 29 milionů dlaždic nebylo nikdy v paměti naráz.

| Věc | Rozhodnutí |
|---|---|
| Cache bloků | LRU, max ~256 bloků (`WorldChunkCache`) |
| Statické objekty (statics) | drženy v komprimovaném binárním souboru, čtené **po blocích** s indexem (§3.4) |
| Dynamické objekty | mobilové a předměty v simulaci; renderer dostane každý tick jen delta (co se změnilo) |
| Animace | frame strip z atlasu, časování z `animdata` (§3.5); žádné `AnimationPlayer` uzly pro tisíce objektů |
| Tónování hue | cache `ImageTexture` variant podle `(art_id, hue)` s LRU; UO art má index 0 = „použij hue" |
| Světlo | jedna vrstva `CanvasModulate` + světelné zdroje jako `PointLight2D`; úroveň světla z hodin a `light.mul` (§5.11) |

## 2.5 Struktura projektu

```
game-clone/
├─ project.godot                 # vlastní jen app/, zakázané pro granule
├─ docs/                         # zadání (tenhle dokument) + rozhodnutí
├─ sim/                          # SERVER: autoritativní stav (bez scény)
│  ├─ world/                     # mapové bloky, walkabilita, doors, teleporty
│  ├─ entity/                    # mobile, item, container, equipment
│  ├─ systems/                   # movement, combat, skills, craft, harvest,
│  │                             # magic, ai, economy, spawn, notoriety, time
│  ├─ commands.gd                # příkazy klient → sim
│  ├─ events.gd                  # události sim → klient
│  └─ sim_world.gd               # tick, registr systémů, state_hash, save/load
├─ ui/                           # KLIENT: gumpy, kurzory, HUD, drag & drop
├─ render/                       # KLIENT: chunkový renderer, animace, světlo
├─ app/                          # scéna, vstup, smyčka, menu, nastavení
├─ data/                         # statický obsah (JSON) — předměty, recepty,
│                                # monstra, spawny, vendory, kouzla, skilly
├─ assets/
│  ├─ uo/                        # EXTRAHOVANÉ z UO — v .gitignore (§3.1)
│  ├─ atlas/                     # hotové atlasy + manifest (také gitignore)
│  └─ fonts/, sfx/               # volné (OFL/CC0) assety — commitované
├─ tools/uoextract/              # Python extraktor z instalace UO
├─ tools/gates/                  # brány (schema, wiring, assets, render)
├─ tests/                        # spouštěcí testy (spec, needitovat!)
└─ .forge/roadmap.json           # DAG granulí (viz 07)
```

**Zakázané soubory pro granule:** `tests/`, `tools/gates/`, `project.godot`,
`.forge/`, `docs/`. Mění je jen člověk nebo integrační granule.

## 2.6 Konvence kódu (GDScript — ověřené pasti)

Tohle nejsou stylistické rady; každý bod je chyba, která už jednou shodila běh:

1. **Nikdy nedefinuj `get()` ani `set()`** na svém skriptu. Přebijí
   `Object.get()/set()` a rozbijí testy, které čtou vlastnosti podle jména
   (`sk.get("tezba")`). Použij konkrétní jméno funkce (`hodnota()`) nebo
   veřejnou vlastnost.
2. **Skript komponenty začíná `extends Node`** (nebo `RefCounted`, pokud
   nepotřebuje strom — výslovně to u granule uveď) a **`class_name` nesmí být
   zároveň jménem vnořené `class` v tomtéž souboru** — vnořená třída přebije
   globální jméno, `new()` vrátí ji a smluvní metody „neexistují".
3. **`_init()` bez povinných argumentů** (jinak `new()` v testu spadne).
4. **Godot 3 API je zakázané**: `margin_left` → `add_theme_constant_override`,
   `node.has()` → `node.has_method()`, `OS.get_ticks_msec()` v sim ne,
   `yield` → `await`.
5. **Typované přiřazení**: když `var x := ...` hlásí chybu typu, použij
   `var x = ...` (a nikdy neobcházej typování `Variant`em bez důvodu).
6. **Signály** se připojují `connect(_on_x.bind(...))`; každý `_on_*` musí
   být odněkud připojený (kontroluje brána wiring).
7. **Jeden soubor = jedna komponenta.** Monolit `game.gd` je zakázaný —
   brzdí paralelní práci a je to zdroj konfliktů.
8. **Komentáře česky, identifikátory anglicky** (kanonické termíny UO:
   `mobile`, `serial`, `layer`, `hue`, `notoriety`). Názvy v `data/*.json`
   anglicky (jsou to klíče z UO).
9. **Žádné „magic numbers" v kódu** — konstanty do `sim/const.gd` nebo do
   `data/balance.json`, aby se daly měřit a měnit na jednom místě.

## 2.7 Výkon a rozpočet

| Metrika | Limit | Jak se měří |
|---|---|---|
| Tick simulace | ≤ 2 ms při 200 mobilech a 3000 předmětech | `tests/bench_sim.gd` |
| Frame | ≤ 16 ms v Britainu při 1280×720 | smoke test + snímek |
| Paměť | ≤ 1,5 GB (atlasy + cache bloků) | `OS.get_static_memory_usage()` v testu |
| Start hry | ≤ 5 s do prvního frame | manuálně |
| Velikost `assets/uo/` | ≤ 800 MB (jen referencované art ID) | `tools/gates/check-assets.py` |
| Načtené textury | LRU s stropem ~400 MB | `TextureCache` počítadlo |

**Zakázané:** načíst všechny art ID do paměti při startu (65 536 itemů ×
průměrně 2 kB = ~130 MB jen item art, plus animace násobně víc). Extrahuj
a načítej **jen to, co obsah odkazuje**, zbytek on-demand.

## 2.8 Co se z instalace UO bere a co ne

| Bere se | Nebére se |
|---|---|
| Art dlaždic a předmětů, worn art, gumpy, animace | Hudba a zvuky: **jen pokud** je projekt publikovaný jako lokální; pro veřejnou verzi použij CC0/CC-BY alternativy (`11-zdroje.md`) |
| Mapa a statics (geometrie světa) | `client.exe`, `UO.exe`, knihovny a patchery — nikdy |
| `tiledata.mul`, `hues.mul` — jména, flagy, vrstvy, barvy | Texty z `Cliloc` **jen jako referenční data**, ne jako přebalený obsah hry |
| `body.def`, `Bodyconv.def`, `Equipconv.def`, `animdata`, `animinfo` | Cizí kód z instalace (DLL, exe) |
| `skills.mul`, `skillgrp.mul` (jména skillů, skupiny) | Síťové protokoly a login |
| `doors.txt`, `stairs.txt`, `teleprts.txt`, `misc.txt`, `mobtypes.txt` — **chování** | |

Důvod rozlišení: geometrie, čísla a jména tile jsou **data potřebná
k interoperabilitě** s formátem, který hra čte; hotová hudba a zvuk jsou
autorská díla, u kterých je čistší použít volnou alternativu. Když si nejsi
jistý, zapiš to do `CREDITS.md` a nech rozhodnutí na člověku.
