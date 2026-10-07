# Předání — UO-klon (průchodnost je opravená; 2026-10-07, 6. session)

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ-2.md`** (etapa 2, Úkoly 1–9);
> **Úkoly 1, 2 a 3 jsou hotové**, další je **Úkol 4 (`sim.interaction`)** — ale
> **před ním je potřeba rozhodnout konvenci dveří** (otevřená věc 62).
> Předchozí etapa je v `ZADANI-DALSI-VYVOJ.md`.
> **Naměřený stav plánu je v `REVIZE-PLANU-2026-10-06.md`** a **stav granul
> měří** `python tools/plan-status.py`.
> **Kam pro co v referenčních zdrojích je `research/REJSTRIK-REFERENCI.md`**.
> **Datum:** 2026-10-07 (6. session). **Poslední změna kódu:** tato session
> (**Úkol 3: dveře a schody ve `world.walk`** + **naměřená vada id prostoru
> statiků**; `sim/world/walk.gd`, `tests/cases/walk.gd`, modul `walk`
> v `mutace-tests.py` 6 → 12 mutací, `docs/04` §4.2/§4.2.1). Předchozí commit
> `702dac2` = revize dvou vad ze snímků (5. session).

## 🎬 DEMO JE NA SVĚTĚ — mapa Britainu + BAREVNÁ postava, která po ní chodí

**Co je na obrazovce:** mapa Britainu (land + statiky) a **postava (tělo 400),
která stojí, otáčí se a chodí** po klávesách; kamera ji sleduje po dlaždicích.
Postava je **dekódovaná z `anim.mul`** (ne placeholder) — 10 framů chůze na směr
— a **tonovaná sadou barvy kůže** (`hues.mul` → `hues.json`, sada 1002
„SkinHue #1001"), takže **od této session není šedá** (`render/hue_cache.gd`).

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
| **Postava je BAREVNÁ (3. session)** | snímek z běhu `.cache/render/snapshot.png` + výřez `.cache/analysis/hue-postava-zoom.png`, ověřeno **pohledem**; G10 měří **shodu s paletou** sady kůže: `kuze_pixelu: 8634`, `kuze_barva: R52 G42 B42`; tentýž snímek v šedé → **0 px** |

**Co v demu NENÍ:** souboj, magie, obchod, řemeslo, UI okna, jména, světlo,
**výbava na postavě** (postava je nahá), jiné postavy (NPC), mount, pathfinding,
zvuk. Barva kůže od této session **je** (věc 1 → vyřešeno, viz nová tabulka).

## ⚡ VÝKON: hra jela na 1–2 FPS a bylo to v KÓDU, ne v assetech (5. session)

**Otázka uživatele:** „může za sekání to, že nám assety nepatří?" **Odpověď
změřená: ne.** Assety se používají lokálně (extraktor je čte z instalace UO do
`assets/uo/`), hra z nich běží a `.gitignore` jen zabraňuje tomu je **rozdávat
dál** — do běhu nezasahuje. Příčina byla v `render/texture_cache.gd`.

| Co | Před | Po |
|---|---|---|
| frame (1280×720, vsync vypnutý) | **655 ms (1–2 FPS)** | **22–25 ms (40–45 FPS)** |
| `texture(art_id)` na objekt | 0,118 ms × 5 767 objektů = **683 ms/frame** | ~0 (hotová okna) |
| načtení atlasové stránky za běh | 3 stránky se načítaly **každý frame** | **27 celkem**, pak 0 |

**Vada:** `texture()` vyráběl **nový `AtlasTexture` při každém volání** a kreslicí
smyčka ho volá pro každý objekt každý frame. **Oprava:** hotová „okna" se drží
v `_wrapped` a vrací se **tatáž instance** (`tests/cases/render_textures.gd` to
hlídá přes `is_same()` a **3 mutace** to dokazují).

**⚠ Co se NESMÍ zatajit (naměřeno):** okna drží referenci na stránku, takže
**strop `MAX_BYTES` (384 MB) platí pro stránky V CACHE, ne pro celkovou pamet** —
britanská scéna potřebuje 27 stránek = 432 MB. Když jsem okna při vyhození mazal,
přišel **thrashing: 1 230 ms/frame (1 FPS)**. Je to zapsané v kódu i tady, ať to
nikdo ne„opraví" znovu.

**Co zbývá (není to vada téhle granule):** zbytek je GPU — **1 516 draw callů**
a 11 534 primitiv na frame při 5 767 spritech. To je práce pro **M9
(`render.chunk_mesh`, dávkové kreslení)**; 40 FPS je dnes hratelných.

## ✅ CO JE NOVÉHO (5. session) — a čím je to doložené

**Granule `sim.pathfind` (Úkol 2 ze `ZADANI-DALSI-VYVOJ-2.md`) je hotová**:
hra umí odpovědět „kudy z A do B" — A* nad dlaždicemi, který se na průchodnost
**ptá `world.walk.can_step`** a nikde si nevede vlastní kopii pravidel.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **`sim.pathfind`** | `sim/world/pathfind.gd` (**173 řádků**, deklarace `<= 150` — překročeno, viz věc 2): `find(from, to, limit) -> Array[Vector3i]` (cesta bez startu, prázdné pole = cesta není), `next_step(from, to) -> Vector3i`, navíc `nodes_visited()` a `cost_last()` |
| **Algoritmus je z referencí, ne z dojmu** | ceny kroků ortogonala **100** / diagonala **141** a strop uzlů **1000** = `MaxSearchNodes` v ModernUO (`dev-docs/pathfinding.md:81`); `MaxDepth 300` a oblast 38×38 v ServUO (`FastAStarAlgorithm.cs:26–28`); lineární hledání minima v open listu jako `FindBest` tamtéž |
| **Průchodnost se neopisuje** | test podstrčí `walk` jako **stub, který si sám určuje průchodnost** a počítá volání: kdyby měl pathfind vlastní kopie pravidel, stub by neobesel a počty kroků by neseděly (`sim.pathfind: pruchodnost se PTÁ walk.can_step (namEReno volani …)`) |
| **Heuristika je octilová (diagonala 141, zbytek 100)** | Test to měří na **4 vzorcích cesty**: odhad nikde nepřekročí skutečnou cenu (přípustnost) a u žádné hrany neklesne víc, než hrana stojí (konzistence) |
| **⚠ FALEŠNÝ POPLACH, korekce 5. session** | Nejprve jsem (podle chybně zapsaného očekávání v testu) tvrdil, že předchozí heuristika `maxi(dx,dy)*100` byla vada. **Nebyla.** Sonda porovnala obě na **256 cílech** (`.cache/analysis/sonda-srovnani.gd`): `rozdilnych 0, stara drazsi 0, nova drazsi 0, uzlu stara 19207 / nova 16673` → octil je **úspora 13 % uzlů**, ne oprava. V kódu je to tak i popsané (+ „ať se to neopravuje znovu") a `LESSONS.md` to má jako záznam o mé chybě |
| **Test granule** | `tests/cases/pathfind.gd` (**27 kontrol**): přímka, souvislost kroků, diagonála, obcházení dírou v překážce, neexistující cesta → prázdno, start == cíl, `next_step` na obě strany, rozpočet uzlů, cena cesty (ortogonala/diagonala), přípustnost + konzistence heuristiky, cíl mimo mapu, `nodes_visited` a **reálná mapa** (když jsou `assets/uo/world`) |
| **⚠ Vada, kterou jsem málem nechal být: `texture()` alokoval každý frame** | `render/texture_cache.gd` — měřeno sondou `.cache/analysis/sonda-fps.gd`: **655 ms/frame → 22–25 ms**; identitu instance hlídá `tests/cases/render_textures.gd` a **3 mutace** v modulu `textures` |
| **Test `render.textures` (nový)** | `tests/cases/render_textures.gd` (13 kontrol): identita instance, region/offset z manifestu, `missing`, **400 dotazů bez dalšího načtení stránky**, `stats()` má všechny složky, chybějící manifest, reálná data navíc. Vyrábí si **vlastní atlas** v `.cache/test-textures/` (v CI nejsou `assets/uo/`) |
| **Dva nové vstupy `render.textures`** | `_init(manifest, max_bytes, page_prefix)` (prefix cest ke stránkám — kvůli testu mimo `assets/uo/`) a `stats()` navíc `wrapped` + `nacteni_stranek`. **Patří do `docs/04 §4.2`** (věc 57) |
| Testy hry | **520 kontrol, 0 selhání** (bylo 507; +13), `exit 0`; case souborů **28** |
| **Mutační důkaz** | `mutace-tests.py` **47/47** (bylo 44/44; +3 `textures`), smlouva vstupu OK; `mutace-render-anim.py` 11/11, `mutace-render-hue.py` 12/12, `mutace-skills.py` 8/8, `mutace-anim.py` 8/8 → **celkem 86/86** |
| **Dvě slepá místa, která mutace odhalily** | (a) mutant „diagonala za 200" **prošel všemi kontrolami na počet kroků** — test měřil jen počet kroků, ne cenu; doplněno `cost_last()` a kontroly ceny. (b) mutant „předchůdce se přepíše i pro rozbalený uzel" **nedoběhl** (exit 124 = timeout) — harness to hlásí jako „sada vůbec neproběhla"; mutace vyřazena a **zapsána jako otevřená věc 53** (harness neumí rozeznat zaseknutí od pomalého běhu) |

**Co pathfind ZATÍM NEUMÍ (otevřené, hlasím):** dveře a schody (`world.walk` je
neřeší — vada F9 / Úkol 3), moby/statiky jako překážky, dosah ani preferenci
trasy (klient `ClassicUO Pathfinder.cs:868`), a **nikdo ho ještě nevolá** z
`sim.ai` ani z click-to-move (to je další krok: `app.player_view`/`sim.commands`).

## ✅ CO JE NOVÉHO (6. session) — Úkol 3: dveře a schody v `world.walk`

**Cíl session byl splněn** (Úkol 3 ze `ZADANI-DALSI-VYVOJ-2.md`), ale **cesta
k němu vedla přes vadu, kterou zadání nepojmenovalo** — a ta vada byla větší než
dveře a schody dohromady.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **⚠ VADA: statiky se čtou ze špatné tabulky tiledata** | `world.map.statics_at` vydává `tile` v prostoru **tiledata id předmětu** (0..0x3FFF), ale `world.tiledata` klíčuje předměty jako **art id** (`tile >= 0x4000`); stejný posun dělá `render/chunk_renderer.gd`. Naměřeno: `tiledata.flags(1717)` → `grass`/`0x00000000`, správně `wooden door`/`0x20006050`. V Británii (80×80 kolem 1495,1630) mělo `Impassable` **2 743** statiků, „syrově" jen 1 044 → `can_step` **pustil 1 325 kroků** do dlaždice s `Impassable` statikem. **Oprava:** konstanta `ITEM_OFFSET` v `walk.gd`. Po opravě: **0** z 6 750 kroků se statikem v pásmu postavy projde. |
| **Dveře: oba stavy mají `Impassable`** | `1717` i `1718` = `0x20006050`, výška 20 → **stav se z flagů poznat NEDÁ**; `walk` se proto ptá `world.doors.is_open` (nový 4. argument konstruktoru). Testy: zavřené blokují, otevřené ne, **oba stavy mají stejné flagy** (kontrola na to je) a přes zavřené dveře se nesmí ani diagonálně. |
| **Schody: výška se počítá** | Naměřeno: **9 z 9** druhů schodů v Británii má `Surface`, výšky **5 a 10**; skok mezi sousedními schody je **přesně výška schodu** (histogram skoku povrchu: `0× 436`, `±5 68+68`, `±1 2+2`). `surface_z` se před opravou lišil u **118 ze 130** dlaždic se schodem, po opravě **0**. Krok nahoru se na dlaždici se schodem povoluje do výšky toho schodu (`world.stairs.is_stair`) — **je to rozhodnutí, ne opsaná reference** (věc 63). |
| **Výškové pásmo statiku** | Statik blokuje, jen když se jeho pásmo protne s pásmem postavy (`docs/05 §5.1.2` bod 2); pásmo je `max(výška, 1)` (645 druhů `Impassable` artů má výšku **0**). Před opravou blokovalo **502** kroků, které pásmo neprotínaly. |
| **Test granule** | `tests/cases/walk.gd` — **+17 kontrol** (537 celkem): id prostor (statik má flagy až na `id+0x4000`), dveře (zavřené/otevřené/stejné flagy/diagonála/40 pod nohama), schody (povrch, nahoru z 0 i z 3, příliš vysoko, dolů), pásmo (pod nohama/nad hlavou), reálná data (reálný schod + dveře z `data/doors.json`) |
| **Mutační důkaz** | `mutace-tests.py --only walk` → **12 z 12 chyceno** (bylo 6); mezi nimi „statik se čte bez +0x4000 (tabulka LAND)" (13 selhání), oba směry dveří, pásmo i výška schodu |
| **Realita se nezhoršila** | demo chodí: `demo-chuze.gd` → 6 pozic `(1495,1630)` … `(1497,1630)`, animace `4 ↔ 0`; G10 **stejná čísla** (`kuze_pixelu 8634`, `R52 G42 B42`); testy **537/0**, brány **11/0/0**, self-testy **19/0**, G4 `volanych_z_produkce` 58 → **59** (`world.doors.is_open` už volá produkce) |

**⚠ Co tato session NEROZHODLA (a je to v otevřených věcech):** `world.doors`
tvrdí, že **kusy 5–8 z `doors.txt` jsou otevřené arty**. Měření to
**nepotvrzuje** — `tiledata` má u dveří sloupec `layer` po dvojicích
(`1717`/`1718` = `layer 0`, `1719`/`1720` = `1`, … `1731`/`1732` = `7`) a
RunUO/ServUO párují **sousední** arty (`closed = base + 2f`, `open = closed + 1`).
`walk` je na tom nezávislý (ptá se `is_open`), takže se rozhodnutí dá udělat
kdykoli — **věc 62**. Dnes to nemá vliv na obraz: v okolí startu (80×80) **není
ani jeden statik dveří** (`doors.json` zná 0 z nich).

## ✅ CO JE NOVÉHO (4. session) — a čím je to doložené

**Granule `sim.entity_registry` (Úkol 1 ze `ZADANI-DALSI-VYVOJ-2.md`) je hotová**
a zavřela obě díry, které Zadání pojmenovalo (F7): `sim.movement` si mobily už
nedrží sám a `render.anim` nebere `serial` jako číslo těla.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **`sim.entity_registry`** | `sim/entity/registry.gd` (**66 řádků**, deklarace `<= 60` — překročeno, viz věc 2): `register(m)->void`, **`get_mobile(serial)`** (neznámý serial → `null`, ne pád), `all()->Array`, `remove(serial)->void`, `size()->int` (navíc, používá jen test) |
| **`all()` je řazené podle serialu** | Jinak by stavový hash a replay závisely na **pořadí vložení**, ne na stavu. Test: registrace ve vysokém→nízkém serialu a `all()` musí vrátit nízký→vysoký; mutace „v poradi vlozeni" **chycena** |
| **Registr odmítá `serial <= 0`** | Nula je výchozí hodnota `entity.mobile`; „mobil na serialu 0" by v `get_mobile(0)` vypadal jako platný hráč. Test + mutace „prijme i mobil bez kladneho serialu" **chycena** |
| **`sim.movement` bere mobily z registru** | `sim/systems/movement.gd`: `_mobiles` **zrušeno**, `register`/`mobile` jsou průchod do registru; registr jde předat **5. argumentem konstruktoru** (`_init(walk, clock, events, drain_model, registry)`). Test: mobil vložený přímo do předaného registru projde krokem; `register()` zapíše do registru |
| **`render.anim` si bere tělo z registru** | `render/anim_player.gd`: `body_of(serial)->int` (`-1` = v registru není) + `_init(manifest_path, registry)`; `play()` volá `body_of` a při `-1` vrací `ok:false` + `null` (ne cizí tělo). Bez registru platí **starší chování** (`serial` = tělo), aby se daly měřit obě cesty |
| **Zapojení do hry** | `app/main.gd` zakládá registr a registruje hráče, předává ho `movement` i `view.set_registry(...)`; `app/world_view.gd:_draw_player` volá `play(int(_player.serial), …)` (dřív `body`) |
| **Test granule** | `tests/cases/registry.gd` (95 řádků, 11 kontrol): prázdný registr, neznámý serial, `get_mobile` vrací **tentýž objekt**, řazení `all()`, odmítnutí serialu 0 a `null`, `remove`, přepsání téhož serialu, a **`render.anim.body_of` z registru** (měří se i v CI — `body_of` nepotřebuje assety) |
| **Testy navazujících granul** | `tests/cases/movement.gd` (+4 kontroly: registr 5. argumentem), `tests/cases/render_anim.gd` (+5: `play(serial)` přes registr, `body_of`, neznámý serial, starší cesta) |
| Testy hry | **480 kontrol, 0 selhání** (bylo 460; +20), `exit 0`; case souborů **26** *(5. session: dnes **507/0**, 27 case souborů — registr zůstal součástí)* |
| Brány | **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0`; self-testy **19 (10 bran + 9 nástrojů), 0 chyb** |
| **Mutační důkaz** | `mutace-tests.py` **38/38** (bylo 34/34, +4 registry), `mutace-render-anim.py` **11/11** (bylo 9/9, +2 registr), `mutace-skills.py` 8/8, `mutace-render-hue.py` 12/12, `mutace-anim.py` 8/8 → **celkem 77/77** |
| **Obraz se NEZMĚNIL** | Snímek z běhu `demo-hue.gd`: `postava nakreslena true`, `chybi sprite false`, `kresleno objektu 5767`, `VERDIKT: KUZE JE BAREVNA`; G10 `kuze_pixelu 8634`, `kuze_barva R52 G42 B42` — **stejná čísla jako před zásahem** (změna je jen v tom, ODKUD se bere tělo) |
| **⚠ VADA SMLOUVY (opravena se svolením uživatele)** | Smlouva i roadmapa žádaly `get(serial)` — **GDScript to neumí**: `get()` je metoda `Object` a jiná signatura je **parse error**. Platí **`get_mobile`**; opraveno v `docs/04 §4.2` + `§4.2.1` a v `tools/roadmap-gen.py` (`.forge/roadmap.json` se generuje) |
| **Dvě pasti, které mě stály čas** | (a) sada s parse errorem hlásila **438 kontrol, 0 selhání** (místo 480) — dva case soubory se tiše přeskočily; (b) v sandboxu `workspace-write` jsou `.cache` i `.godot` needitovatelné → brány hlásí **falešné vady** a Godot **nezapíše `.gd.uid`**. Obě i s čísly v `LESSONS.md` |

**Nová pomůcka (v `.gitignore`, proto tu není v gitu):** `_analyza/mutace-vzory.py`
— spočítá výskyty každého mutačního vzoru a u `mutace-render-anim.py` ověří, že
`podminka` neplatí na originále. Ověřena **mutací sebe sama** (vrácená vadná
podmínka i duplicitní vzor ji shodí, `exit 1`). Druhá: `_analyza/handoff-kontrola.py`
— ověří, že **žádný číslovaný seznam v tomto souboru nemá děru** (dva seznamy:
otevřené věci a vady zadání) a že povinná sekce zůstala celá; **při přepisu
předání ji spusť** (taky ověřena mutací: `30.` → `31.` ji shodí).

## ✅ CO JE NOVÉHO (3. session) — a čím je to doložené


| Co | Doklad (naměřeno dnes) |
|---|---|
| **`render.hue` (granule) — postava už není šedá** | `render/hue_cache.gd` (169 řádků): `hued(textura, hue, partial_hue) -> Texture2D`, cache s LRU, `stats()` s `missing`; `HUE_SKIN = 1002` (sada se jmenuje „SkinHue #1001" — číslo v názvu je **0-based**) |
| **Recept na tonování je z referenčního klienta, ne z dojmu** | index barvy = **5 horních bitů R** (ClassicUO `IsometricWorld.fx:127–129`, `get_rgb(color.r, hue)`); partial hue přebarvuje **jen** pixely s R == G == B; tabulka 5 → 8 bitů je **opsaná** z `_src/classicuo/.../HuesHelper.cs` — **NENÍ to `v << 3` ani `round(v*255/31)`** (od vzorce se liší na **15 z 32** hodnot) |
| **Test granule** | `tests/cases/render_hue.gd`: hue 0 = původní textura, převod pixelů, **alfa jako maska**, partial hue, **index z R (ne z G)**, cache (hit/miss/strop/kolize dvou textur), neznámý hue, chybějící data, **tabulka proti referenčnímu klientovi** a `hue_color()` proti `hues.json` u **všech 3000 sad × 32 úrovní** |
| **Mutační důkaz** | `tools/gates/mutace-render-hue.py` → **12 z 12 chyceno**, `exit 0`; baseline 447/0; smlouva o vstupu OK (neexistující cesta test shodí) |
| **G10 měří barvu postavy** | `check-render.py` měří **přesnou shodu s paletou** sady barvy kůže (32 barev z `hues.json`; sada se čte z `HUE_SKIN` v granuli, ne opisuje) a u **výchozího** snímku ji **vyžaduje** (`KUZE_MIN = 500`). Self-test **8 případů** (přibyl známý chybný „postava je sedá", „barva mimo paletu" a „chybí paleta" → NEMĚŘENO) |
| **Vizuální důkaz** | `.cache/render/snapshot.png` z běhu `demo-hue.gd` + výřez `.cache/analysis/hue-postava-zoom.png` — **pohledem** (`read_image`) je vidět oranžovo-hnědá kůže, ne šedá |
| **Hue se opravdu počítá** | `[hue-demo] SOUHRN: … barvy true, cache { "sad": 3000, "polozek": 1, "bytes": 5368, "hits": 0, "misses": 1 }` |
| Testy hry | **447 kontrol, 0 selhání** (bylo 422; +25 za `render.hue`) |
| Brány | **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0` |
| **Dvě pasti, které mě stály čas** | `Image.duplicate()` **nezachová alfou** (128 → 255); `ImageTexture` vytvořená za běhu má **prázdný `resource_path`** → klíč cache se dělá **otiskem obsahu**. Obě i s příkladem v `LESSONS.md` |

## ✅ CO JE NOVÉHO (2. session) — a čím je to doložené

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

**⚠ ZMĚNA 2026-10-07 (rozhodl uživatel): „Můžeš povolit commit a push po každém
sezení."** Od této session platí **trvalé povolení**: na konci session se **commituje
i pushuje na `origin/main` bez ptaní** (dřív si to uživatel vyhrazoval po jedné
session). Týká se to i **tohoto pravidla** — ať ho další session zkopíruje dál
i s touhle větou, jinak se povolení zase ztratí.
**Co to znamená konkrétně:** commitni (strom čistý) → `git push origin main` →
**ověř, že push dorazil** (`git rev-list --count origin/main..HEAD` = `0`) →
**počkej na CI** a zkontroluj běh nad **svým** commitem (`node _analyza/ci-beh-stav.mjs`);
zelený běh nad starším commitem není důkaz (viz „Jak ověřit nasazení" v pravidlech).
Push se **nikdy** nedělá s tajemstvím v diffu a **nikdy přes PAT vypsaný do historie**
(credential helper `manager` si token drží sám).

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
4. **Commitni a pushni** (strom čistý) — `LESSONS.md` i `HANDOFF.md` patří do
   gitu, protože další session je čte odtud. **Push je od 2026-10-07 povolený
   trvale** (viz věta na začátku téhle sekce) a po pushi se **kontroluje CI běh
   nad tím commitem**.

## 🎯 CÍL SESSION (pravidlo uživatele, 2026-10-07)

**Rozhodnutí uživatele:** „Plánuj další sezení tak, aby si určily cíl a dokončily
ho celý." Každá session tedy **není „krok"**, ale **jeden celek s cílem**:

1. **Hned na začátku session si napiš cíl jednou větou** a k němu **přijímací
   kritérium, které se dá změřit** (test, brána, snímek). Když cíl nejde změřit,
   není to cíl, ale přání.
2. **Velikost cíle se volí tak, aby se do session vešel CELÝ** — radši menší
   hotový celek než větší rozdělaný. Když je práce větší, rozděl ji na cíle pro
   **víc session** s jasnou hranicí (co je hotové na konci každé).
3. **Na konci session je cíl hotový, nebo je vidět, že hotový není** — a pak
   musí být v předání pojmenované **co zbývá a proč** a co je **nejbližší další
   krok**. „Rozdělané a zamlčené" je zakázané; „rozdělané a pojmenované" je
   v pořádku.
4. **Nedělat v jedné session víc cílů**, aniž by první byl uzavřený a ověřený.

**⚠ CÍL TÉTO (7.) SESSION — až ho dokončíš, přepiš tuhle větu na další cíl:**

> **Rozhodnout a opravit konvenci dveří ve `world.doors`** (otevřená věc 62).
> `doors.gd` dnes tvrdí „kusy 1–4 zavřené, 5–8 otevřené"; měření (`layer`
> v tiledata po dvojicích + RunUO/ServUO `closed = base+2f`, `open = +1`) ukazuje
> na **sousední dvojice**. **Přijímací kritérium:** rozhodnutí je podložené
> měřením (který art je otevřený, doloženo **pohledem** na montáž i geometrií),
> `world.doors` (`is_open`/`toggle`/`open_tile`) je podle něj opravený,
> `tests/cases/doors.gd` to měří, mutace v `mutace-tests.py` (nový modul
> `doors` nebo stávající) to chytí, a `tests/cases/walk.gd` (dnes stav jen
> konzumuje) zůstane zelený.
> **Proč zrovna tohle:** Úkol 4 (`sim.interaction`) má „dveře → otevřít/zavřít"
> a kdyby konvence zůstala špatná, interakce by přepínala na **jinou orientaci**
> dveří. Je to malý, uzavřený celek (jeden soubor + test + mutace).
> **Co do cíle NEPATŘÍ:** `sim.interaction` (Úkol 4), `render.chunk_mesh` (M9),
> vady ze snímků (věci 59–61).

**Předchozí cíl (6. session), splněný:** Úkol 3 ze `ZADANI-DALSI-VYVOJ-2.md`
(dveře a schody ve `world.walk`) — přijímací kritérium splněno: test se
zavřenými i otevřenými dveřmi, test kroku na schod nahoru/dolů, obojí s mutací
(`--only walk` **12/12**), `run_tests.gd` **537/0**, `run-all.py` **0 vad**.

## ⚠⚠ BLOKÁTORY

**Žádný otevřený blokátor v kódu.** „Demo chodí a postava je barevná" je naměřené
(viz tabulky výš), brány jsou zelené (11/0/0), testy **537/0** (s assety; v čistém
klonu je kontrol méně, protože část měří data z `assets/uo/`) a **průchodnost je
opravená** (6. session: statiky se čtou správnou tabulkou, dveře rozhoduje
`world.doors`, schody svou výškou). **Hra jede 40–45 FPS** (bylo 1–2 FPS) — viz
sekce VÝKON.

**⚠ CI: BĚHY NAD COMMITY 5. SESSION BYLY ZELENÉ.** Ověřeno živě
(`node _analyza/ci-beh-stav.mjs`): **#23 nad `e6ff22e` = `success`, 13/13 kroků**
a **#24 nad `88b4747` = `success`** (krok 9 = mutační důkaz testů prošel). Starší
běh #22 (`137da89`) bylo taky `success`. **Běh nad commity 6. session je
v „Předletové kontrole"** (doplněn po pushi). **Pozor na hranici toho tvrzení:**
logy ani artefakty nejdou bez tokenu stáhnout (`ci-log.mjs` → 403,
`ci-artefakt.mjs` → 401), takže **obsah kroků v CI ověřený není** — mutace jsou
naměřené **lokálně** a v CI je ověřeno jen to, že krok nespadl. **A pozor na
počet běhů:** série pushů pustí víc běhů; „poslední běh" tedy nemusí být ten,
který člověk myslí — **sha v odpovědi API je to, co rozhoduje.** Předchozí běhy
#16, #17 a #19 mají poučení:

| běh | commit | spadl v | příčina | oprava |
|---|---|---|---|---|
| #16 | `878f391` | **7** (testy) | `tests/cases/render_hue.gd` **vynucoval data** (`hues.json`, `_src/`), která v CI nejsou → **10 selhání** | `c010a20`: test rozdělený na „bez dat" / „s daty" |
| #17 | `e26c12a` | **10** (`mutace-skills`) | paralelní session měla v době běhu **rozpracovaný strom** (`data/skills.json` vs `skills_data.gd`) — zelené to bylo až po jejím dalším commitu (`cee3bec`) | její commit, ne můj |
| #19 | `28e3a68` | — | `success` (11/11) — potvrdilo, že oprava kroku 7 i 10 sedí | — |

**Obecné pravidlo z toho:** v CI **nejsou `assets/uo/` ani `_src/`** (gitignore).
Test granule, který potřebuje data z instalace, se **musí** ptát
`FileAccess.file_exists()` a při chybějících datech hlásit `NEMERENO`
(`print`, ne `_pending` — to by shodilo G3), **nikdy nesmí selhat**.

Dvě věci, které blokátor **nejsou**, ale je dobře je vědět:

1. **Tři mutační harnessy nejsou v CI.** `mutace-tests.py` a `mutace-skills.py`
   v CI jsou, ale `mutace-anim.py`, `mutace-render-anim.py` a
   **`mutace-render-hue.py`** se pouští jen ručně — **a v CI běžet nemohou**:
   první chce instalaci UO, druhý `assets/uo/anim/*.png`, třetí `hues.json`
   (a bez nich měří hůř). Chtějí **fixture**; do `ci.yml` je smí přidat jen
   `boot.gates`.
2. **`tests/run_tests.gd` pořád tiše přeskočí case soubor s parse errory**
   (otevřená věc 21 z minula). **4. session to potvrdila znovu a ostřeji:**
   s rozbitým `registry.gd` (metoda `get`, viz věc 47) sada vypsala
   **`438 kontrol, 0 selhání`** místo **480** — dva case soubory se přeskočily
   a jediný viditelný příznak byl **pokles počtu kontrol**. Proto: **baseline
   `N kontrol` si změř před zásahem a po něm** (postup je v `LESSONS.md`).

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Demo (hra)** | **`HRA.cmd`** v kořeni (dvojklik) — spouštěč řeší Godot, `APPDATA` i chybějící data. Ručně: `& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-driver opengl3` (s `$env:APPDATA` ve workspace) |
| **Zadání pro další vývoj** | **`ZADANI-DALSI-VYVOJ-2.md`** (etapa 2, Úkoly 1–9; **Úkol 1 hotový**). Etapa 1 je v `ZADANI-DALSI-VYVOJ.md` |
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| **Kam pro co v referencích** | **`research/REJSTRIK-REFERENCI.md`** (rozcestník, ~50 odkazů s měřeným počtem nálezů) — generuje a kontroluje `python tools/refs-index.py [--check\|--srovnej]` |
| **Multiplayer bokem** | **`research/08-multiplayer-poucky.md`** — 17 principů ze serverů, „u nás dnes" + co platí až s multiplayrem |
| **Referenční klony** | `_src/{runuo,servuo,modernuo,classicuo,sphere}` (**pinované**, gitignore, nejsou submoduly). Pozor: `research/_src/{servuo,modernuo}` jsou **druhé checkouty téhož** — pro čtení používej `_src/` |
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes\|skills]` |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` → **537 kontrol / 0 selhání** (28 case souborů). **Bez plného přístupu dej `APPDATA` do `.tmp`** (viz pasti) |
| Brány | `python tools/gates/run-all.py` → **11 měřeno / 0 NEMĚŘENO / 0 chyb**, `exit 0` |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 self-testů (10 bran + 9 extrakčních nástrojů), 0 chyb**; **G10 má uvnitř 8 případů** |
| **Mutační důkaz testů** | `python tools/gates/mutace-tests.py [--only sort\|map\|walk\|movement\|registry\|pathfind\|textures]` → **53 z 53** (trvá desítky minut; `walk` má 12 mutací) |
| **Mutační důkaz dekodéru animací** | `python tools/gates/mutace-anim.py` → **8 z 8** |
| **Mutační důkaz `data.skills`** | `python tools/gates/mutace-skills.py` → **8 z 8** |
| **Mutační důkaz `render.anim`** | `python tools/gates/mutace-render-anim.py` → **11 z 11** |
| **Mutační důkaz `render.hue`** | `python tools/gates/mutace-render-hue.py` → **12 z 12** |
| **Sonda: unikátnost mutačních vzorů** | `python _analyza/mutace-vzory.py` (**gitignore**) → `mutace-tests: 53 vzorů` + `mutace-render-anim: 11` = **64**, `OK`; ověřená mutací sebe sama |
| **Registr bytostí (nové)** | `sim/entity/registry.gd` + `tests/cases/registry.gd`; `register`, `get_mobile`, `all`, `remove`, `size` |
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
| Roadmapa | `.forge/roadmap.json` — **111 granul, `done` je u všech `false`**: stav se pozná **jen měřením** (`python tools/plan-status.py`); generuje ji `python tools/roadmap-gen.py` (`--check` ověří aktuálnost) |
| Data z instalace | `assets/uo/` (gitignore) — mimo jiné **`anim/` (30 PNG + `anim-sheets.json`)** a `anim-manifest.json` |

## Stav kódu (počty řádků Pythonem `splitlines()`, bez `.uid` a `__pycache__`)

| složka | souborů (kód) | řádků kódu | poznámka |
|---|---|---|---|
| `core/` | 7 | 339 | hotové a otestované |
| `sim/` | **14** | **1 810** | **`world/walk.gd` 150 → 220** (6. session: id prostor statiků, dveře, pásmo, výška schodů); dále `world/pathfind.gd` (5. session, 173 řádků), `entity/registry.gd`, `entity/skills.gd`, `entity/mobile.gd`, `systems/movement.gd` |
| `render/` | 5 | **770** | `sort.gd`, **`texture_cache.gd`** (+48: cache oken a počítadlo načtení), `chunk_renderer.gd`, `anim_player.gd`, `hue_cache.gd`; `ui/` pořád neexistuje |
| `app/` | 6 (5 kód) | 651 | `main.gd`, `world_view.gd`, `player_controller.gd` (bez granule) |
| `tests/` | **38** (31 kód) | **3 820** | **28 case souborů**; `cases/walk.gd` +17 kontrol (6. session) |
| `tools/uoextract/` | 38 | 6 278 | `anim.py` umí pixely, `--export`, `--export-check` |
| `tools/gates/` | 22 | **4 957** | `mutace-tests.py` — modul `walk` **12 mutací** (bylo 6) |

*(Počty jsou Pythonem `splitlines()` nad kódovými soubory `.gd`/`.py`/`.sh`/`.mjs`,
bez `.uid` a `__pycache__` — `python _analyza/radky.py`.)*

**Zbývá 61 granul** (z 111; 40 měřeně hotových po commitu této session — ověř
`python tools/plan-status.py`). Hotové (souborem i měřením) navíc proti 3. session:
**`sim.entity_registry`** (4. session) — **9 nových** proti předání z 2. session.

## Co je hotové a ověřené (ne „soubor existuje")

**M0 celek** · **W0** (8) · **M1: uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc, anim (VČETNĚ pixelů), data.items, data.gen_content,
data.recipes, world.tiledata, world.map, render.sort, render.textures,
render.chunk, render.anim, render.hue** · **M2: world.doors, world.stairs,
entity.stats, world.time, entity.skills, entity.mobile, world.walk,
sim.movement, data.skills, `sim.entity_registry`, `sim.pathfind`** ·
**integrace (bez granul): `app/player_controller.gd`, `app/world_view.gd`
(kreslení postavy + barva + registr), `app/main.tscn` (uzly), `app/main.gd`
(registrace systémů, barva hráče, založení registru a jeho předání `movement`
i `world_view`)**.

Doklady, které jsem viděl na vlastní oči (ne opsané z předání):

- **Na snímku je mapa Britainu i BAREVNÁ postava** — `read_image` na
  `.cache/render/snapshot.png` (4. session; 5. session obraz neměnila, G10 dává
  **stejná čísla**: `kuze_pixelu 8634`, `kuze_barva R52 G42 B42`).
- **Postava se pohnula po skutečných klávesách** — log řidiče `demo-chuze.gd`:
  6 pozic, směry 0/2/7/4, animace `4 ↔ 0`.
- **Postava je z dat, ne kreslená**: výřez z `anim.mul` (tělo 400, 10 framů chůze),
  0 pixelů mimo frame na 30 blocích.
- **Barva je z dat**: `hues.json` sada 1002, reference na recept
  (`IsometricWorld.fx:127–129`, `HuesHelper.cs`).
- **Cesta je z dat a z `walk`** — 5. session: `find` na reálné mapě Británie
  projde 4 dlaždice, každý krok je soused a `z` v rozsahu; na cenu i heuristiku
  jsou kontroly a 6 mutací.
- **Průchodnost je z DAT, ne z dohadu (6. session)** — statiky se čtou tabulkou
  předmětů (`+0x4000`), dveře rozhoduje `world.doors.is_open`, schody svou výškou;
  naměřeno na reálné mapě (`sonda-walk-statiky.gd`, `sonda-walk-presnost.gd`):
  z 6 750 kroků se statikem v pásmu postavy jich projde **0** (před opravou 1 173),
  `surface_z` se u **130 ze 130** dlaždic se schodem shoduje s `z + výška`.
- **Testy 537/0**, **brány 11/0/0** (`exit 0`), **mutace `mutace-tests.py` 53/53**
  (z toho `walk` **12/12**).
- **Hra nespadne**: G11 `smoke` → `framu 120, script_error 0, parse_error 0`.

### ⚠ Co na obrazovce ještě NENÍ

Souboj, magie, obchod, řemeslo, UI (žurnál, status bar, paperdoll), jména nad
postavami, světlo (`render.light`), **výbava na postavě** (postava je nahá),
druhé postavy, mount, pathfinding, zvuk. **Hratelná mechanika: chůze, otáčení
a barva kůže.** Statiky nesou barvu ze záznamu mapy, ale **nikdo ji nepoužívá**
(věc 35).

## Co brány dnes měří (2026-10-07, 6. session)

`run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 VADA**, `exit 0`.

| Brána | Výsledek | Je to vada kódu? |
|---|---|---|
| G1–G11 | **OK** | NE |
| G4 | OK — `granuli_s_hotovym_souborem: 51`, `volanych_z_produkce: 59` (+1: `world.doors.is_open` už volá produkce); `world.doors.is_door`/`toggle`/`open_tile` a `world.stairs.stair_group` jsou **„volá ho jen tests/"** | NE |
| G6 | OK — měří `anim_decoder_kod: 0`, `anim_decoder_kontrol: 35` | NE |
| G10 | OK — `barev: 2124`, `pixelu_mimo_pozadi: 892595`, **`kuze_pixelu: 8634`, `kuze_barva: R52 G42 B42`** — **stejná čísla jako 4. a 5. session** (kód obrazu se nedotkl) | NE |
| G13 | PORADNÍ | NE — `vision.mjs` není (poradní je podle `docs/08 §8.2`) |

## Předletová kontrola (5 minut, než začneš psát)

| Co | Jak | Očekáváno (2026-10-07, 6. session) |
|---|---|---|
| Strom je čistý | `git status --porcelain -uall` | **prázdné** po commitu této session |
| Je před GitHubem | `git rev-list --count origin/main..HEAD` | **`0`** — **6. session pushla** (uživatel 2026-10-07 povolil commit i push po každé session) |
| **Běží CI?** | `node _analyza/ci-beh-stav.mjs` (funguje i bez tokenu) · anotace: `node _analyza/ci-anotace.mjs` | běh nad commitem 6. session (viz „BLOKÁTORY"); předtím **#23 nad `e6ff22e` = `success`** a **#24 nad `88b4747` = `success`**; série pushů pustí **víc běhů** — **sha rozhoduje**, ne „poslední běh" |
| **Co v CI NEJDE ověřit bez tokenu** | `node _analyza/ci-log.mjs` → **HTTP 403**; `ci-artefakt.mjs` → **HTTP 401** | Kdo nemá token, **vidí jen stav kroků**, ne jejich obsah — takže „krok 9 prošel" je naměřené, ale **počet chycených mutací v CI je neověřený** (naměřeno je 53/53 **lokálně**). Nezapisuj do předání „CI má 53/53", když to nevidíš |
| Repo je veřejné | API bez tokenu | `visibility: public` |
| **Oprávnění** | `whoami /groups \| Select-String Mandatory` | **`Medium`** = plný přístup. `Low` = sandbox → brány hlásí **falešné vady**, `.uid` nevzniknou a `run-all.py` spadne na `summary.json` (5. session to naměřila: G7 „VADA save/load", G11 NEMĚŘENO, self-test 9 chyb — **všechno byl sandbox**) |
| Testy | testy s `APPDATA` ve workspace (`Low`: dej ho do `.tmp`) | **537 kontrol, 0 selhání**, 28 case souborů (v čistém klonu je kontrol méně — část měří data z `assets/uo/`) |
| **FPS (nové)** | `& .cache\godot\...console.exe --path . --rendering-driver opengl3 --script res://.cache/analysis/sonda-fps.gd` | **40–45 FPS** (22–25 ms/frame), 5 767 objektů, 1 516 draw callů; cache se po nabehu nemění (27 načtení, 0 změn) |
| Brány | `python tools/gates/run-all.py` | **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0` |
| Self-testy | `python tools/gates/run-all.py --self-test` | **19, 0 chyb**, `exit 0` |
| Mutační důkaz | `mutace-tests.py` + `mutace-anim.py` + `mutace-skills.py` + `mutace-render-anim.py` + `mutace-render-hue.py` | `53/53`, `8/8`, `8/8`, `11/11`, `12/12` (= **92/92**) |
| Vzory mutací | `python _analyza/mutace-vzory.py` (gitignore) | `mutace-tests: 53 vzorů` + `mutace-render-anim: 11` = **64 celkem**, `OK`, `exit 0` |
| Animace | `python tools/uoextract/anim.py --self-test` | `35 kontrol, 0 chyb` |
| Barvy | `python tools/uoextract/hues.py --self-test` | `5 kontrol, 0 chyb` |
| Data skillů | `python tools/gates/gen-content.py --only skills --check` | `OK skills.json: shoda` |
| Fixture sedí na generátor | `python tests/fixtures/world/make_fixture.py --check` | `4× OK`, `exit 0` |
| **Snímek je z běhu** | `Get-Item .cache/render/snapshot.png \| % LastWriteTime` | **dnešní** (frame z `demo-hue.gd`) |
| Godot běží | `& .cache\godot\...console.exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |
| Instalace UO na místě | `Test-Path 'D:\Games\...\tiledata.mul'` | `True` |
| Kontroly zadání | `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` | `exit 0` |
| Stav plánu | `python tools/plan-status.py` | `111 granul`, **`43` měřeně hotových**, 0 rozporů |
| **Sandbox** | `whoami /groups \| Select-String Mandatory` | **`Medium`** = plný přístup |

## Otevřené věci a co je potřeba dodělat

**Přenáším z minulého předání (nic se nemaže) — u každé je dnešní stav:**

1. **Soubory bez testu** — **PLATÍ DÁL, ale je jich méně**: test má
   `world/walk.gd`, `systems/movement.gd`, `entity/skills.gd`, `entity/mobile.gd`,
   `render/anim_player.gd`, `app/player_controller.gd`, **`entity/registry.gd`**.
   **Bez testu zůstávají** `world/tiledata.gd`, `app/main.gd`, `app/main.tscn`,
   `render/texture_cache.gd`, `render/chunk_renderer.gd`, `app/world_view.gd`,
   `app/loop.gd`, `render/hue_cache.gd` (má test nepřímo přes G10).
2. **`size_lines` nesedí** — **PLATÍ DÁL a přibylo to** (měří
   `python tools/plan-status.py`; **34 deklarací z 93**): nově
   **`world/walk.gd` 220/120** (6. session: +70 řádků — hlavička s naměřenými
   čísly; zkrácení by tu znalost smazalo), `entity/registry.gd` 66/60,
   `render/hue_cache.gd` 268/60, `sim/systems/movement.gd` **176**/120,
   `entity/skills.gd` 103/60, `entity/mobile.gd` 66/60,
   `render/anim_player.gd` **143**/120, `world.map` 210/120, `texture_cache.gd`
   141/60, `app/world_view.gd` **212**/60 (bez deklarace) a `data/skills.json`
   640/60 (JSON!). **Rozhodnutí uživatele (2026-10-06): měřit, ne přepisovat.**
   *(Registry: hlavička nese vadu smlouvy `get` → `get_mobile`; zkrácení by tu
   znalost smazalo — viz `LESSONS`.)*
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
    Nové číslo: ve snímku s postavou se kreslí **5 767 objektů**.
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
29. ~~`play(serial, ...)` bere `serial` jako ČÍSLO TĚLA~~ — **VYŘEŠENO 4. session**
    (granule `sim.entity_registry`): `render.anim` má `body_of(serial)` a čte
    tělo z registru; bez registru platí starší chování. **Zbytek je otevřený:**
    `sim_world.snapshot()` pořád vrací `mobiles: []` (věc granule
    `sim.world_loop` — viz nová věc 48).
30. ~~`sim.movement` si mobily drží sám~~ — **VYŘEŠENO 4. session**: systém
    `_mobiles` zrušil a `register`/`mobile` jsou průchod do registru (registr jde
    předat 5. argumentem konstruktoru). Smlouva `docs/04 §4.2` je doplněná.
31. ~~**`Door` a `Container` v průchodnosti**~~ — **VYŘEŠENO 6. session (Úkol 3)**:
    `world.walk` rozhoduje dveře podle `world.doors.is_open` (oba stavy mají
    `Impassable`), schody svou výškou a blokující statik jen ve svém výškovém
    pásmu. **Cestou se našla větší vada** (statiky se čtou správnou tabulkou
    tiledata) — viz sekce „CO JE NOVÉHO (6. session)". Co zůstalo: **konvence
    dveří** (věc 62).
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
    Naměřeno 2026-10-06 ~22:21: během psaní rejstříku (2. session) vznikly soubory
    `render/hue_cache.gd`, `tests/cases/render_hue.gd`, `tools/gates/mutace-render-hue.py`
    a změny `app/main.gd` + `app/world_view.gd` (zapojení `render.hue`, barva kůže)
    — **nejsou z 2. session** a v době commitu byly zelené (testy 444/0,
    brány 11/0/0). **Pravidlo: než začneš psát, podívej se na `git status`
    a na `LastWriteTime` souborů, které nejsou tvoje** — jinak zapíšeš do cizí
    práce (nebo ji commitneš jako svou). A **necommituj cizí soubory**: `git add`
    jen na své cesty. *(To byla tahle session — 3.; z druhé strany to potvrzuji:
    `HANDOFF.md` se mi v průběhu práce přepsal pod rukama a musel jsem ho znovu
    přečíst a mergovat, místo abych ho přepsal celý.)*
40. **NOVÉ (3. session): `hued_art()` v `render.hue` je hotové, ale NIKDO JE
    NEVOLÁ.** Statiky v `render.chunk` nesou `hue` ze záznamu mapy a **nikdo ho
    nepoužívá** — obarvené statiky (dveře, cedule, oblečení na zemi) se kreslí
    bez barvy. Patří do `render.chunk`.
41. **NOVÉ (3. session): `render.anim` nevrací `hue` ani neumí vrstvu.** Rozhraní
    `play()` vrací texturu těla; kdo ji bude skládat s výbavou, musí sáhnout na
    `world_view.player_hue()` — dnes jediné místo, kde se barva aplikuje.
    (Rozšiřuje věc 28: `render.hue` na to stroj má, chybí `entity.equipment`.)
42. **NOVÉ (3. session): G10 měří „klín pixelů kůže" v okolí STŘEDU, ne v boxu
    postavy.** Je to proto, že kamera drží hráče ve středu a přesná geometrie
    spritu je v GDScriptu (`world_view`), ne v bráně. **Není to slepé** (sedá
    postava dá 0 px a self-test to má jako známý chybný případ), ale **není to
    přesné**: číslo zahrnuje i hnědé dlaždice. Přesnější by bylo měřit barvu
    z boxu postavy, který umí spočítat jen hra (řidič v `.cache/`, věc 32).
43. **NOVÉ (3. session): `tools/uoextract/hues.py` nemá `--verify`** (jen
    `--self-test` s 5 kontrolami a `--install`). Při dalším zásahu do barev by
    se hodila kontrola proti `hues.mul` (jako `anim.py --verify`).
44. ~~CI spadá v kroku 10 (`mutace-skills`) na commitu `e26c12a`~~ — **VYŘEŠENO**
    commitem paralelní session (`cee3bec`); běh **#19 je zelený (11/11)**.
    **Poučení zůstává:** kdo mění `data/*.json` nebo case soubor, musí
    `mutace-*` spustit **v čistém klonu** (`git worktree add --detach ../x HEAD`),
    protože CI nemá `assets/uo/` ani `_src/`. A **`mutace-anim.py`,
    `mutace-render-anim.py` ani `mutace-render-hue.py` v CI běžet NEMOHOU**
    (chtějí instalaci UO, `assets/uo/anim/*.png`, resp. `hues.json`) — chtějí
    fixture.
45. **NOVÉ (3. session): `--write-movie` bez existující složky neskončí chybou**
    (vznikne jen `frame.wav` 0 B) — v `ci-godot.sh` to řeší `mkdir -p`, ale kdo
    ten příkaz opisuje ručně, narazí (past 30).
46. **NOVÉ (3. session): test granule musí být ROZDĚLENÝ na „bez dat" a „s daty"**
    (vzor `tests/cases/render_hue.gd` po opravě `c010a20`): kontroly, které
    potřebují `assets/uo`, se v CI **nesmí vynucovat** — jinak spadne krok
    s testy (stalo se v běhu #16: 10 selhání). Patří to i do `docs/09`.
47. **NOVÉ (4. session): smlouva žádala `get(serial)`, což GDScript NEUMÍ.**
    `get()` je metoda `Object`; jiná signatura = **parse error** (a case soubor
    s parse errorem se tiše přeskočí → sada hlásila `438 kontrol, 0 selhání`
    místo `480`). **Opraveno se svolením uživatele** na `get_mobile` v
    `sim/entity/registry.gd`, `docs/04 §4.2` + `§4.2.1` a `tools/roadmap-gen.py`
    (`.forge/roadmap.json` se generuje). **Pravidlo do `docs/09`:** jméno metody
    je součást smlouvy a musí se ověřit proti jazyku (`get`, `set`, `call`,
    `free`, `duplicate`, `connect` jsou jména `Object`).
48. **NOVÉ (4. session): `sim_world.snapshot()` pořád vrací `mobiles: []`.**
    Registr je **jeden zdroj pravdy**, ale `SimWorld` o něm neví — klient mobily
    odsud nevidí (kreslí se jen hráč z `app/main.gd`). Napojit registr na
    `sim.world_loop` (a tím i replay, věc 22) je samostatný krok; patří do
    `docs/04 §4.2` u `sim.world_loop`.
49. **NOVÉ (4. session): `body_of()` je nad smlouvu `render.anim`.** Smlouva
    uvádí jen `play(...)`; `body_of(serial)` vznikl proto, aby se „tělo z registru"
    dalo měřit **i v CI**, kde nejsou `assets/uo` (jinak by to bylo NEMĚŘENO).
    Patří do `docs/04 §4.2` (doplněno) — a rozhraní `play` se tím nemění.
50. **NOVÉ (4. session): `.gd.uid` pro nové skripty vznikne jen s plným
    přístupem.** V sandboxu `workspace-write` je `.godot/uid_cache.bin`
    needitovatelný, takže Godot nový skript nezaregistruje a **`.uid` nenapíše**;
    s plným přístupem ho `--import` zapíše. **Ověřeno 4. session:** `registry.gd.uid`
    i `tests/cases/registry.gd.uid` vznikly po `--import` pod plným přístupem
    a jsou v commitu. Kdo je nemá, ať se ptá na **oprávnění**, ne na `.gitignore`.
51. **NOVÉ (4. session): `_analyza/mutace-vzory.py` není v gitu** (`.gitignore`).
    Sonda na unikátnost mutačních vzorů je obecně užitečná; kdyby měla být
    reprodukovatelná z gitu, patří do `tools/gates/` — rozhodnutí uživatele.
52. **NOVÉ (4. session): registr nemá vlastní `save`/`load`.** `SimWorld.save()`
    ukládá `mobiles: []`, takže poloha hráče se do save nepromítne (G7 měří jen
    hash stavu). Až se registr napojí na `sim.world_loop` (věc 48), musí se
    rozhodnout, co z registru patří do save.
53. **NOVÉ (5. session): `mutace-tests.py` neumí rozeznat ZASEKNUTÍ od pomalého
    běhu.** Mutant `sim.pathfind` s obráceným porovnáním ceny („dražší cesta
    přepíše levnější") **zacyklí rekonstrukci cesty**; Godot nedoběhne do
    `timeout=900`, harness vypíše **„SADA VUBEC NEPROBEHLA (0 kontrol)"** a
    mutant se počítá jako nechyceny — přitom je to vada, kterou by šlo chytit
    časovým stropem (`subprocess` s kratším limitem + klasifikace „ZASEKLA SE").
    Dnes je mutace ze seznamu vyřazená (a je to v `mutace-tests.py` u modulu
    `pathfind` popsané), aby 6/6 nebylo postavené na neměřeném.
54. **NOVÉ (5. session): `sim.pathfind` NEMÁ VOJÁKA.** Nikdo ho nevolá —
    `sim.ai` ani click-to-move neexistují, `sim.commands` cestu nezná. Je to
    hotová granule bez volajícího (stejná past jako `hued_art`, věc 40). Další
    krok: `sim.commands`/`app.player_view` poslat krok z `next_step(from, to)`.
55. **NOVÉ (5. session): smlouva `sim.pathfind` NENÍ v `docs/04 §4.2`.**
    Roadmapa `provides` ji má (`find(from, to, limit)`, `next_step(from, to)`),
    ale dokumentace komponent ji nezmiňuje (a `docs/` agent needituje). Navíc
    implementace přidává **`nodes_visited()` a `cost_last()`** (nad smlouvu,
    používá je test a budou je chtít `app.metrics`) a **`limit` je rozpočet
    uzlů**, ne délka cesty — to patří do smlouvy.
56. **NOVÉ (5. session): u `HRA.cmd` je otestovaná jen šťastná cesta.**
    Naměřeno: `cmd /c "HRA.cmd --quit-after 3"` → hra naběhne (mapa 6095
    objektů, 12 vazeb kláves, hráč `(1495,1630,10)`) a `%ERRORLEVEL%` je **0**.
    **Neotestované větve** (proto tu jsou): „Godot nenalezen" (chtělo by
    dočasně odebrat `.cache\godot`, takže se to netestovalo naostro),
    stažení Godotu přes PowerShell, a chybějící `assets\uo\`. Kdo je bude
    upravovat, ať je **změří** — a pozor na past: `echo` s **neescapovanou
    závorkou uvnitř bloku `if (`** shodí celý skript hláškou „X was unexpected
    at this time" (namEReno 2026-10-07; v souboru je to i jako komentář).
57. **NOVÉ (5. session): `render.textures` má víc, než říká smlouva.** `docs/04
    §4.2` uvádí `texture(art_id)` a `stats()`; implementace má navíc **třetí
    argument `page_prefix`** (kvůli testu, který si staví vlastní atlas mimo
    `assets/uo/`) a ve `stats()` navíc **`wrapped`** a **`nacteni_stranek`**
    (počítadlo načtení stránek — stojí na něm test proti thrashingu). Navíc
    platí, že **strop `MAX_BYTES` je měkký**: hotová okna drží stránky naživu,
    takže skutečná paměť může být vyšší (naměřeno 432 MB při stropu 384 MB).
    To patří do smlouvy — je to chování, na které se dá spolehnout jen takhle.
58. **NOVÉ (5. session): u výkonu je změřený jen STOJÍCÍ scénář.** Sonda
    `sonda-fps.gd` měří Británii ve stoje (5 767 objektů, 1 516 draw callů,
    40–45 FPS). **Chůze** (přestavba chunku, vstup do nových dlaždic, možné
    načtení dalších stránek) změřená není — a je to právě stav, kdy se může
    sekat. Kdo bude dělat M9, ať měří i chůzi, ne jen postoj.
59. **NOVÉ (5. session): ŠEDÁ PLOCHA v místě změny výšky — chybí překlad land
    tile id → art id.** `world.map` vydává land **tile id**, ale atlas
    i `render.textures` pracují s **art id z pole `texture`** v tiledata; kde se
    liší, `texture()` vrátí `null`, `_draw()` udělá `continue` a vznikne **díra**
    (vidět jako šedé pozadí). Naměřeno v okolí `(1519,1657)`: chybí arty
    `{83:12, 95:12, 100:53, 84:1, 88:1, 96:1}`; v `tiles.json` mají 83/95/100
    `texture = 76`; atlas má **3 732 z 16 384** land artů (chybí 12 652).
    **`sim/world/tiledata.gd` neumí `texture`** — to je ta chybějící znalost.
    Detail, snímky a návrh: **`REVIZE-VADY-ZE-SNIMKU-2026-10-07.md` §Vada B**.
    **Neopravovat teď** (rozhodnutí uživatele: až bude čas a bude to relevantní).
60. **NOVÉ (5. session): „stopa" animačních framů při pohybu (vada A).**
    Uživatel vidí na snímku několik postav v různých fázích chůze. **Co to NENÍ
    (naměřeno):** animace v čase funguje (`0->f0 80->f1 160->f2 … 480->f6`)
    a reset při změně klíče taky; past je, že `play(1, …)` měří jinou věc —
    serial 1 není v registru, takže `body_of` vrátí `-1`. **Nedořešeno** —
    hypotézy a způsob ověření (dva framy do PNG a porovnat) jsou v
    **`REVIZE-VADY-ZE-SNIMKU-2026-10-07.md` §Vada A**. Neopravovat teď.
61. **NOVÉ (5. session): chybějící art se kreslí jako TICHO.** `render.textures`
    vrátí `null` a `world_view._draw` udělá `continue` — díra v mapě tedy nemá
    jak být vidět. Patří tam viditelný placeholdr (magenta/šrafování) a vizuální
    kontrola úplnosti land artu (dnes ji nemá nikdo; G10 měří jen barvu postavy).
62. **NOVÉ (6. session): KONVENCE DVEŘÍ v `world.doors` je podezřelá — a je to
    CÍL 7. SESSION.** `doors.gd` tvrdí (hlavička, „rozhodnuto obrázkem"):
    „kusy 1–4 = čtyři zavřené orientace, kusy 5–8 tytéž otevřené". **Naměřeno
    dnes (nic z toho nebylo při rozhodování k dispozici):**
    (a) `assets/uo/tiles.json` má u dveří sloupec `layer` **po dvojicích**:
    `1717`/`1718` = `0`, `1719`/`1720` = `1`, … `1731`/`1732` = `7` — tedy
    **8 orientací a u každé DVA arty**, ne „4 + 4";
    (b) RunUO/ServUO `Scripts/Items/Construction/Doors/Doors.cs` párují
    **sousední** arty: `closed = base + 2f`, `open = closed + 1`
    (MediumWoodDoor = 0x6B5: zavřené 1717/1719/1721/1723, otevřené 1718/1720/1722/1724);
    (c) kdyby platilo „kus 1 zavřený ↔ kus 5 otevřený", **otevření dveří by
    změnilo orientaci** (jiný `layer`) — fyzikálně nesmysl;
    (d) **slabý, ale reálný signál:** 4 arty z 16 v řadě **nemají `Impassable`**
    (1714, 1730, 1732, 1666) a jsou to **sudé** (tedy „partneři +1"), což je
    přesně to, co se čeká od otevřeného artu;
    (e) **co měření NEŘEKLO:** zrcadlová metrika (`d(art, zrcadlo(art'))`) je
    u obou hypotéz blízko šumu (13,9–24,4), takže **sama nerozhoduje** —
    proto se to nemá „opravit od stolu", ale rozhodnout **pohledem** na montáž
    dvojic (`.cache/analysis/dvere-pary.png`, `dvere-zrcadleni.py`,
    `dvere-orientace.py`, `sonda-dvere-schody.py`; vše gitignore).
    **Dnešní dopad je nulový** (v okolí startu 80×80 **není ani jeden statik
    dveří**) a `walk` je na konvenci nezávislý (ptá se `is_open`) — ale
    **Úkol 4 (`sim.interaction`) na tom stát bude**.
63. **NOVÉ (6. session): pravidlo kroku na schod je ROZHODNUTÍ, ne opsaná
    reference.** `walk` dnes povoluje krok nahoru do **výšky schodu**
    (`world.stairs.is_stair` + `tiledata.height`), protože naměřené skoky mezi
    sousedními schody v Británii jsou **přesně výška schodu** (5 nebo 10).
    **Reference se rozcházejí:** RunUO/ServUO/ModernUO `Movement.Check` zná jen
    `startTop + StepHeight` (2) — s tím by se po těch schodech **nedalo jít
    vůbec**; Sphere (`src/common/CServerMap.cpp:221`) má na schody **zvláštní**
    pravidlo (`CAN_I_CLIMB`, `m_zClimbHeight = zHeight/2`, postupné zvedání).
    **Ověřit příště** (až bude po čem): snímek/řidič, který po schodech
    v Británii opravdu vyjde, a porovnat výsledné `z` s naším pravidlem.
    Dnes je to **jediná část 6. session, která je „podle měření", ne „podle
    reference"** — a je to v `docs/04 §4.2.1` i s oběma citacemi.

## Už není otevřené (přesunuto, nemaže se)

- **„Výkonnostní dluh: `AtlasTexture` na objekt"** (věc 19 z minula) — **VYŘEŠENO
  2026-10-07 (5. session)**: hotová okna se cachují, **655 ms → 22–25 ms/frame**.
  Zbytek (1 516 draw callů) patří M9 a je to otevřená věc 58.

- **„Na obrazovce není nic"** — vyřešeno 2026-10-06 (snímek z běhu, G10 zelená).
- **„Na obrazovce není postava"** — **vyřešeno 2026-10-06 (2. session)**: postava
  je na snímku a chodí (důkaz: řidič + log pozic).
- **„`play(serial, ...)` bere serial jako tělo"** a **„`sim.movement` si mobily
  drží sám"** — **vyřešeno 2026-10-06 (4. session)** granuli `sim.entity_registry`
  (věci 29 a 30).
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
- **Podezření, že brány jsou zelené nad vadou** — prověřeno i 4. session: každá
  nová kontrola má mutaci (**77/77** celkem: 38+8+8+11+12), **a jedna brána se
  opravdu chytila** (G6 tvrdila zestárlé „dekodér není" — opraveno na měření).
  **A jedna past se letos potvrdila znovu:** sada hlásila `438 kontrol, 0 selhání`
  nad dvěma case soubory s parse errorem (věc 21) — viz `LESSONS`.
- **Podezření, že v repu jsou tajemství** — prověřeno 2026-10-06.
- **„Replaye nemá co měřit"** — vyřešeno (2 replaye), ale viz otevřená věc 22.
- **„CI neběží — 9 běhů s 0 jobů"** — vyřešeno (běh #11 `success`).
- **„Až CI ožije, bude červené kvůli chybějícím assetům"** — vyřešeno (G6 i G10
  hlásí NEMĚŘENO, krok s branami toleruje `exit 2`).

## Další kroky (v tomto pořadí)

0. **Než začneš hledat cokoli v referencích:** otevři
   `research/REJSTRIK-REFERENCI.md` a použij jeho řádek („otázka → `soubor:řádek`
   + jak ověřit"). Nález, který se nezmění v tvrzení v našem kódu + test, je dojem.
1. **Pushnout a zkontrolovat CI** na nových commitech — **6. session pushla
   sama** (trvalé povolení z 2026-10-07; HANDOFF to hlídá v „BLOKÁTORECH"
   a v „Předletové kontrole"). Po pushi čekej běh nad **svým** commitem
   a ověř **13/13 kroků** (`node _analyza/ci-beh-stav.mjs`).
2. ~~**Úkol 2 ze `ZADANI-DALSI-VYVOJ-2.md`: `sim.pathfind`**~~ — **HOTOVO
   2026-10-07 (5. session)**: `sim/world/pathfind.gd` + `tests/cases/pathfind.gd`
   + modul `pathfind` v `mutace-tests.py` (6/6). **Zbývá jen voják** (věc 54).
3. ~~**Úkol 3 ze `ZADANI-DALSI-VYVOJ-2.md`: dveře a schody ve `world.walk`**~~ —
   **HOTOVO 2026-10-07 (6. session)**: `world.doors.is_open`, výška schodů,
   výškové pásmo statiků **a oprava id prostoru statiků** (`+0x4000`).
   Testy `pathfind` (mají stub) zůstaly zelené ✓ — předpoklad z předání platil.
4. **Rozhodnout konvenci dveří ve `world.doors`** (věc 62) — **cíl 7. session**;
   je to vstup pro Úkol 4 (`sim.interaction`, „dveře → otevřít/zavřít").
5. **Opravit slepé místo v `tests/run_tests.gd`** (`script.can_instantiate()`
   před `script.new()`) — pořád jediná známá slepá brána (věc 21) a **5. session
   na ni naletěla znovu** (parse error v `tests/cases/pathfind.gd` → sada
   hlásila `480 kontrol, 0 selhání`; poznat se to dalo **jen podle poklesu
   počtu kontrol**). Soubor je `boot.tests` → **potřebuje rozhodnutí uživatele**.
6. **Úkol 4 ze `ZADANI-DALSI-VYVOJ-2.md`: `sim.interaction`** (`use`, `use_on`,
   kontextové menu; routing dynamicky, `not_available` místo ticha) — **až po
   věci 62**.
7. **Napojit registr na `sim.world_loop`** (věci 22, 48, 52): `snapshot().mobiles`,
   `state_hash`, `save` — tím se rozhýbou replaye a klient uvidí i jiné mobily.
8. **`entity.equipment` + `entity.item`** — obléknout postavu (ta je dnes nahá).
   `render.hue` na to stroj má (věc 41); `render.anim` už tělo z registru bere.
9. **Voják pro `sim.pathfind`** (věc 54): click-to-move přes `sim.commands`
   (klik do světa → `next_step` → `Command{t:"move"}`), ať cesta není mrtvý kód.
10. **Statiky s barvou** (věc 40): `render.chunk` + `hued_art()` — dveře a cedule.
11. **Držení klávesy = chůze** (`app.input`, věc 27, Úkol 7) — bez toho se demo
    ovládá „klikatě".
12. Pak M2 zbytek: `entity.container`, `entity.notoriety`, `world.teleport`,
    `world.regions`, **`sim.interaction` (Úkol 4)**.
13. (nepovinné) `if: always()` u diagnostických kroků CI (věc 26) a doplnit
    **čtyři** mutační harnessy do `ci.yml`; časový strop v `mutace-tests.py`
    (věc 53) — plný běh harnessu je dnes **53 mutací × celá sada** (naměřeno
    6. session: celý `mutace-tests.py` trval desítky minut) a v CI má
    job `timeout-minutes: 30`, takže to chce změřit, než se přidá víc.

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Mutační test je to, co odlišuje měření od dojmu** — a musí ověřit **čtyři**
  věci: že se mutace provedla, že test **proběhl** (`N kontrol`, N > 0), že
  selhal **na kontrole daného modulu**, a že test **bere měřenou cestu
  z argumentů** (zkus mu předat neexistující cestu — musí selhat).
- **Vizuální změna se ověřuje pohledem** (`read_image`), ne jen testy: dnes to
  ukázalo (a) že postava je na mapě, (b) že stojí 40 px nad středem (kamera
  ignorovala `z`), (c) **že je opravdu barevná** (a ne že „se to počítá").
- **Druhá implementace téhož formátu je jediná obrana** — dnes to byl
  **referenční klient** dvakrát: `AnimationsLoader.cs` rozluštil animace a
  `HuesHelper.cs` ukázal, že tabulka 5 → 8 bitů **není vzorec** (liší se
  na 15 z 32 hodnot). Test to od teď čte **ze souboru reference**.
- **Vzor mutace musí být v souboru JEDNOU** — dnes to `count == 1` zachránilo
  u dvou mutací (`roundi(c.r * 255.0)` a `_sets[hue - 1]` jsou v souboru
  dvakrát); bez té pojistky by se mutovalo něco jiného, než se měří.
- **Kontrolu hlášení nedělej na podřetězec, který je v souboru víckrát** —
  `contains("push_warning")` bylo zelené i po smazání jednoho ze dvou hlášení.
  Počítej **konkrétní** hlášení a před hledáním odstraň komentáře.
- **Diagnostiku nepiš doprostřed měřené smyčky** — dnes jsem si vlastním
  `print` rozbil odsazení a pak „měřil" kód, který jsem si sám rozbil.
- **Data, která v CI nejsou, testuj na fixture v gitu** — a reálná data měř
  navíc, když jsou; když nejsou, řekni to nahlas (NEMĚŘENO), ale neselhávej.
- **Hotový soubor bez volajícího je mrtvý kód** — ptej se „kdo to volá"
  (dnes: `hued_art`, věc 40).
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA.**
- **Když implementace odhalí díru ve smlouvě, napiš ji do hlavičky souboru**
  (`movement.gd`, `anim_player.gd`, `walk.gd`, `hue_cache.gd`) a zaznamenej
  jako otevřenou věc.

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
24. **NOVÉ (3. session): `String.strip()` v GDScriptu NEEXISTUJE** — je
    `strip_edges()`. Parse error v case souboru ale **sadu nezastaví**, jen tiše
    ubere kontroly: naměřeno `422 kontrol, 0 selhání` místo chyby (věc 21).
25. **NOVÉ (3. session): index barvy a POZICE v rampě nejsou totéž.** Kdo v testu
    předá hodnotu pixelu (0..255) místo úrovně (0..31) do `hue_color()`, dostane
    u hodnot < 32 správný výsledek a od 33 „vadu", která žádná není. Stálo mě to
    ~20 minut hledání v produkčním kódu, který byl správný.
26. **NOVÉ (3. session): `Image.duplicate()` nezachová alfou** (naměřeno:
    obrázek s alfou 128 měl po duplikaci 255). Kopíruj `Image.create(... RGBA8)`
    + `fill(transparentní)` + `blit_rect`.
27. **NOVÉ (3. session): `ImageTexture` vytvořená za běhu má PRÁZDNÝ
    `resource_path`** — klíč cache se podle něj dělat nesmí, všechny by
    kolidovaly a cache by vracela **cizí obrázek** (vypadá to jako vada barvy).
28. **NOVÉ (3. session): `push_warning` může být v souboru dvakrát** — kontrola
    hlášení na podřetězec je pak slepá; počítej **konkrétní** hlášení a před
    hledáním odstraň komentáře (jinak najdeš popis vady místo vady).
29. **NOVÉ (3. session): tabulku 5 → 8 bitů NELZE dopočítat.** `round(v*255/31)`
    i `v << 3` se od reference liší (15, resp. 31 z 32 hodnot). Ber ji
    **ze souboru referenčního klienta** a testuj proti ní.
30. **NOVÉ (3. session): `--write-movie` bez existující složky neskončí chybou.**
    Vznikne jen `frame.wav` (0 B). Založ složku **před** spuštěním.
31. **NOVÉ (4. session): sandbox `workspace-write` (Low integrita) blokuje i
    `.cache` a `.godot`.** Projeví se to jako **vada kódu**: G3 a G7 hlásí VADA,
    G11 NEMĚŘENO, `run-all.py` spadne na `summary.json` a **Godot nenapíše
    `.gd.uid`** k novým skriptům. **Rozpoznání:** `whoami /groups | Select-String
    Mandatory` → `Low`; zápis do `.cache` vrátí `Access denied`. **Řešení:**
    plný přístup; testy jdou i tak (`APPDATA` do `.tmp`). **Neopravuj kvůli tomu kód.**
32. **NOVÉ (4. session): metoda `get()` v GDScriptu NEJDE.** `get`/`set`/`call`/
    `free`/`duplicate`/`connect` jsou jména `Object`; jiná signatura je
    **parse error** — a ten se v sadě projeví jen **poklesem počtu kontrol**
    (věc 21), ne chybou. Ověřuj jméno API proti jazyku **před** psaním testů.
33. **NOVÉ (4. session): `git status` neukáže `.uid`, když ho Godot nemohl
    napsat** — a to se stane právě v sandboxu (past 31). Chybějící `.uid` u nového
    skriptu tedy **není** informace o gitu, ale o **oprávnění**.

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
   **odkud se pro `serial` bere číslo těla**. Dnešní implementace vrací
   `{ok, texture, frame, count, anchor, mirror, mirror_x, sprite_dir}` a tělo
   bere z registru (`body_of(serial)`) — **4. session text doplnila i s `body_of`**;
   zbývá jen rozhodnout, zda `body_of` zůstane veřejné (věc 49).
7. **`docs/04 §4.2` u `sim.movement` neříká, kde systém vezme mobily.** **4. session
   to doplnila** (registr, pátý argument konstruktoru).
8. **`docs/04 §4.5` vs `§4.2` u mobila si odporují**: §4.5 má
   `skills: PackedInt32Array`, tabulka `skills: Skills`; §4.5 `equip: Dictionary`,
   tabulka `equipment: Equipment`; §4.5 má `name`/`hunger`/`ai`, tabulka ne;
   §4.5 má `str/dex/int`, tabulka `stats`.
9. **`docs/06 §6.2`** uvádí 6 nástrojů, které v instalaci NEJSOU.
10. **`.forge/roadmap.json` — `size_lines` nesedí** (věc 2), a **`data.skills`
    má `<= 60`**, přitom generovaný JSON má **640 řádků**.
11. **`app/main.tscn` + kamera + kreslicí uzel + `app/player_controller.gd`
    nemají vlastníka** v roadmapě.
12. **V roadmapě chybí vlastník pro pathfinding** — **VYŘEŠENO 2026-10-06**
    (revize Z5: granule `sim.pathfind` je v roadmapě i v `docs/07` W10).
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
    *(3. session: `render.hue` už hotové je — chybí `entity.equipment`.)*
23. **NOVÉ (3. session): `docs/04 §4.2` u `render.hue` uvádí jen
    `(art_id, hue) → textura` a „index 0 v artu = použij hue"**, ale **neumí to
    postavu**: těla jsou v `anim*.mul` a jejich framy jsou PNG (nemají `art_id`).
    Implementace proto bere **texturu** (`hued(textura, hue, partial)`) a
    `(art_id, hue)` má jen jako `hued_art()`; smlouva to musí popsat.
24. **NOVÉ (3. session): `docs/03 §3.2b`/`§3.5.2` neuvádí, že barevné sady
    začínají na 1001.** V `hues.mul` je 0..1000 **převodních šedých tabulek**
    a sada 1002 se jmenuje „SkinHue #1001" (číslo v názvu je **0-based**). Bez
    toho se barva kůže hledá v šedých sadách a „nejde to".
25. **NOVÉ (3. session): `docs/08 §8.2` u G10 neuvádí měření barvy.** G10 dnes
    měří `kuze_pixelu`/`kuze_barva` a u **výchozího** snímku barvu **vyžaduje**
    (`KUZE_MIN`); u cizího snímku (`--snapshot`) ji jen změří.
26. **NOVÉ (4. session): smlouva žádala `get(serial)`, což GDScript NEUMÍ** —
    **OPRAVENO 4. session** (rozhodl uživatel) na **`get_mobile`** v `docs/04 §4.2`
    (+ `§4.2.1`) a v `tools/roadmap-gen.py`. **Do `docs/09 §9.6` patří pravidlo:**
    jméno metody ověř proti jazyku (`get`/`set`/`call`/`free`/`duplicate`/`connect`
    jsou jména `Object`) — jinak je ze smlouvy parse error, který sada tiše přeskočí.
27. **NOVÉ (4. session): `docs/09 §9.5`/`§9.6` neuvádějí, že se má měřit
    `N kontrol` PŘED i PO zásahu.** 4. session to byla jediná viditelná stopa po
    dvou tiše přeskočených case souborech (`438` místo `480`).
28. **NOVÉ (4. session): `docs/04 §4.2` u `render.anim` nemá `body_of(serial)`.**
    Text jsem doplnil (4. session); zbývá rozhodnout, zda veřejné zůstane (věc 49).
29. **NOVÉ (4. session): `docs/04 §4.2` u `sim.entity_registry` neuvádí `size()`.**
    Metoda je nad smlouvu a používá ji jen test; buď ji smlouva pojmenuje, nebo
    se z kódu vyhodí (dnes: pojmenovaná v hlavičce jako „navíc").
30. **NOVÉ (4. session): `docs/04 §4.2` u `sim.world_loop` mlčí o registru.**
    `snapshot()->mobiles` je dnes `[]`, `save`/`state_hash` mobily nevidí
    (věci 48, 52) — smlouva to musí říct, až se registr napojí.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (`docs/02 §2.6.8`).
- **Nečeské znaky nepatří do identifikátorů** — GDScript je neumí.
- Piš **jen do `owns`** své granule; **výjimka 2026-10-06 (rozhodl uživatel)**:
  nové soubory v `tests/cases/`, `tests/replays/`, `tests/fixtures/`
  a `tools/gates/`; **a integrace podle `ZADANI-DALSI-VYVOJ §3 úkol 5**
  (`app/main.gd`, `app/main.tscn`, `app/world_view.gd`, `app/player_controller.gd`).
  Gate `check-assets.py` a `mutace-tests.py` jsem upravil proto, že **měření
  se změnilo** (G6 nesla zestárlé tvrzení); `check-render.py` (3. session) proto,
  že **měření se rozšířilo** (barva postavy) — v předání je to napsané.
  **4. session:** `mutace-tests.py` dostal modul `registry` (4 mutace),
  `mutace-render-anim.py` 2 mutace na registr, a `docs/04 §4.2`/`§4.2.1` +
  `tools/roadmap-gen.py` mají `get` → `get_mobile` (**výslovné svolení uživatele**).
- **Ve workspace může běžet paralelní session** (věc 39): `git add` jen na své
  cesty a před zápisem do `HANDOFF.md`/`LESSONS.md` je **znovu přečti**.
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet.
- `run-all.py`: 0 = vše měřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není zelená).
- Testy potřebují `APPDATA` ve workspace; **brány si to nastavují samy** —
  **bez plného přístupu dej `APPDATA` do `.tmp`** (past 31) a **neoznačuj
  brány za vadné**.
- **Push je POVOLENÝ TRVALE** (rozhodnutí uživatele 2026-10-07: „Můžeš povolit
  commit a push po každém sezení"). Platí **bez ptaní na konci každé session**:
  commit → push → ověřit `git rev-list --count origin/main..HEAD` = `0` →
  zkontrolovat CI nad svým commitem. Před commitem ukázat `git status`
  a `git diff --stat`. *(Starší věty „jen na vyžádání" a „nová session se ptá"
  jsou od 2026-10-07 ZRUŠENÉ — jsou tu jen proto, že historie se nemaže.)*
