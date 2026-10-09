# Předání — UO-klon (19. session: SEDMNÁCT VAD ZE SNÍMKŮ — řazení hráče, zoom, patra, pohyb, otáčení, auto-run, staty; 2026-10-08)

> ⚠⚠ **DVA AGENTI V JEDNOM WORKSPACE (2026-10-08): tenhle soubor přebírá ten,
> kdo končí POZDĚJI — a NESMÍ při tom zmizet sekce toho prvního.**
> Naměřeno dnes: session 19 sem přidala sekci „CO JE NOVÉHO (19. session)"
> (hned za touhle hlavičkou), přepsala nadpis a do „Co čeká na tebe" vložila
> blok `V5b`/`V1b`/`V3b`; session 20 (paralelně) sem přidala svoje.
> **Kdo soubor přepisuje celý, ať tyhle bloky nechá** — nebo si je přesune;
> zkontroluj to **hledáním**, ne pamětí (`docs/09 §9.7`).

## ✅ CO JE NOVÉHO (2026-10-09 — TŘI VADY ZE HRY, DEBUG OVERLAY, NÁVRH VIZUÁLNÍ REVIZE)

**Zadání uživatele (doslova):** 10 pozorování ze hry (stamina, animace běhu,
zoom, okno, kovárna/roh hradu přes vodu, voda v lese, chybějící debug info,
zeď z podkroví, 2 záseky z ~2300 na ~130 ms, probliknutí) + otázka „dávalo by
smysl pustit tě s maximálním výkonem na revizi… dokončit celý vizuál?".

| Věc | Co je hotové a čím je to doložené |
|---|---|
| **Běh má vlastní animaci** | Číslo akce se bralo jako skupina `anim.mul`, ale u člověka je `1 = WalkArmed` a běh je **2** (`_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs:1721`). Export přepnut na `0:walk,2:run,4:idle`; klient má `render/anim_player.ACTION_GROUP` (id 1 → skupina 2), `sim.movement.ACTION_RUN` **zůstává 1** (spec test na něm stojí). Doklady: `_analyza/p25-groups-montaz.py` (pohledem), `_analyza/p25-run-sprite.gd` (živě: akce 1 → skupina 2, 44×57 px), `_analyza/p25-hrac-srovnani.png` |
| **Stamina vypnuta** | `never` byla v `app/config.gd` SCHEMA povolená, ale `sim.movement` ji neznal → tichý průchod jako `run_only`. Teď jsou implementované všechny 4 modely, `data/balance.json` má `never` (pokyn uživatele). Reference: běh staminu nebere, spotřebu váže **přetížení** (`_src/servuo/Scripts/Misc/WeightOverloading.cs:111`), regenerace 1 bod/interval (`Server/Mobile.cs:1968-1976`) — `sim.regen` u nás chybí |
| **Debug overlay (`F3`)** | `ui/debug_overlay.gd`: lokace, zoom, stav, animace, fps + **špička frame času**. Je viditelný od startu (aby ho zachytil screenshot — návrh uživatele) a má `MOUSE_FILTER_IGNORE`. Snímky: `_analyza/p25-overlay-walk.png` / `-run.png` |
| **⚠ NÁLEZ: zoom rozhází pozici postavy** | Overlay při zoomu 0,75 ukazuje **`pick=(426,280)`** proti skutečnému **(480,300)**: `_camera_offset()` míchá světové a obrazovkové pixely a zoom nezohledňuje (reference má `Camera.ScreenToWorld`, `Camera.cs:88-103`). **NEOpraveno** — je to první bod fáze 1 |
| **⚠ ZMĚNA SPECU (jediná)** | `tests/cases/balance.gd` pinovalo `stamina_drain_model == "run_only"` → nyní `"never"`. Vynuceno pokynem uživatele; vrácení = jedna hodnota v testu + jedna v datech |

**Čísla (celá na tomto stromě):** testy **1372 → 1385 kontrol / 0 selhání**
(nové cases `stamina_model.gd`, `debug_overlay.gd`); brány
`tools/gates/run-all.py` **11 měřeno / 0 chyb**; commit `d858c8c`,
`origin/main = d858c8c` (push ověřen).

### ✅ DOPLNĚNO (FÁZE 1, BOD 5.1 — ZOOM V PŘEVODU SVĚT ↔ OBRAZOVKA)

**Co bylo špatně:** `world = screen + camera_offset` platí jen při zoomu 1,0
(`camera_offset` navíc zoom neznal) → klik, interakce, směr z myši i prah běhu
mířily při zoomu ≠ 1 vedle, tím víc, čím dál byl kurzor od středu okna.

**Co je hotové:** `app/world_view` má `viewport_size()`/`world_to_screen()`/
`screen_to_world()`/`zoom_hodnota()`, `app/input_map` má `zoom` a jediné místo
převodu `_na_svet()` (používá je klik i interakce), `mouse_run` měří od HRÁČE
(`GameSceneInputHandler.cs:48-66`), `_camera_offset()` i záložní
`player_screen_position()` počítají s zoomem.

| Důkaz | Číslo |
|---|---|
| `_analyza/p26-zoom-vstup.gd` (oracle = Godot `Camera2D.get_canvas_transform()`) | odchylka klient vs. engine **0,00 px** při zoomu 1,0/0,75/0,5/1,5/2,0; klik na východní dlaždici = **dir 0** vždy |
| Kolik byla vada | tyž klik starou matematikou: zoom 0,75 → (1490,1631) = **směr 5 (JZ)**, 0,5 → JZ, 1,5/2,0 → **směr 1 (SV)** |
| Overlay | `pick=(426,280)` → **`pick=(480,300)`** (`_analyza/p25-overlay-walk.png`) |
| Test + mutace | nový `tests/cases/zoom_prevod.gd` (19 kontrol, round-trip 80 dlaždic × 5 zoomů = 0 chyb); vrácení vady do `_na_svet` → **52/80** chyb při zoomu 0,75 |
| Testy / brány | **1385 → 1404 kontrol / 0 selhání**; brány **11 měřeno / 0 chyb** |

**⚠ Druhá změna spec testu (schváleno uživatelem 2026-10-09):** `tests/cases/input.gd`
blok 8 dodává `player_screen` — prah běhu se od 2026-10-09 měří od hráče, ne od
středu okna; starý test pinoval střed okna. Záložní cesta (střed okna) zůstává
měřená v `zoom_prevod.gd`.

**➡ Další bod fáze 1 je 5.2** (rám světa volitelný: `stretch/mode=disabled`,
okno 1600×900, pás GUI dopočítaný, `fullsize`), pak 5.3/5.4 (Z-pásma, střechy)
a 5.5 (záseky). Zadání a citace z reference: `VIZUAL-PARITA-2026-10-09.md` §5 a §10.

### ✅ DOPLNĚNO (FÁZE 1, BOD 5.2 — RÁM SVĚTA JE VOLITELNÝ)

**Co bylo špatně:** geometrie okna se počítala JEDNOU v `app/main._setup_ui()`
a `project.godot` držel plátno napevno (`canvas_items` + `scale_mode=integer`) —
naměřeno: okno 1600×900 → viewport i svět zůstaly 1280×720, větší okno
nepřidalo ani dlaždici.

**Co je hotové:** nový modul **`app/window.gd`** (čisté funkce: `pas`,
`svet_obal`, `stred_sveta`, `pozice_oken`) je JEDNO místo pro geometrii;
`app/main._prepocitej_geometrii()` z něj staví uzly a volá se při startu,
při **změně velikosti okna** (`Viewport.size_changed`) a při fullsize;
`project.godot` má `stretch/mode="disabled"` + výchozí **1600×900**;
`world_view.nastav_gui_odsazeni()` posune kameru a **vynutí přestavbu seznamu**
(objektů), aby po zvětšení okna nezůstaly u okrajů díry; **`F2`** přepíná
fullsize (svět = celé okno, černý pás zmizí) — vzor
`_src/classicuo/.../OptionsGump.cs:4113-4133`; `HRA.cmd` spouští 1600×900.

| Důkaz | Číslo |
|---|---|
| `_analyza/p26-okno.gd` (okno 1600×900 i 1280×720, s pásem i fullsize) | `viewport == okno`; svět = okno − pás; ve fullsize pás (0,0) a oba pásy neviditelné; **0 chyb** |
| Snímky | `_analyza/p26-okno-pas-1600x900.png` (svět 1280×780), `_analyza/p26-okno-fullsize-1600x900.png` (svět 1600×900, HUD plave nad světem) |
| Před → po (okno 1600×900) | plátno 1280×720 → **1600×900**; viditelný svět 960×600 → **1280×780**; kreslená plocha 78×44 → **97×55** dlaždic; `pick` (426,280) → **(640,390)** |
| Test + mutace | nový `tests/cases/window.gd` (17 kontrol); mutace „svět z pevného okna“ → **6 selhání**, „fullsize se ignoruje“ → **3 selhání** |
| ⚠ Nález o měřidle | první mutace zavedená do `pas()` **nebyla chycena** — šířka pásu na velikosti okna nezávisí (jen se ořezává); správné místo je `svet_obal()`. Mutační test musí mířit na místo, které na vstupu opravdu závisí |
| Testy / brány | **1404 → 1422 kontrol / 0 selhání**; brány **11 měřeno / 0 chyb** (G10 dál fotí při `--resolution 1280x720`) |

**Co zůstává (pojmenované):** tažení rámu myší (reference
`WorldViewportGump.cs:128-150`) se nedělá — rám se mění velikostí okna;
`fullsize` je klávesa, ne gump; rozložení HUDu ve fullsize je rozhodnutí
o rozložení (popsané v `app/window.gd`).

**➡ Další bod fáze 1 je 5.3** (Z-pásma podle hráče: `playerZ ± 14/16`, strop 150
— `GameSceneDrawingSorting.cs:87-88`, `:564-568`, `RenderLists.cs:274`), pak 5.4
(střechy fade na alfu 0 — `:357-368`) a 5.5 (záseky).

**➡ NÁVRH REVIZE VIZUÁLU JE V `VIZUAL-PARITA-2026-10-09.md`** — naměřené
nálezy k deseti pozorováním, pravidla originálu s citacemi (Z-pásma
`playerZ ± 14/16`, fade střech na alfu 0, hloubka `(x+y) + (127+z)*0.01`) a tři
fáze práce. **Nic z návrhové části se neprovádělo** — čeká na rozhodnutí
uživatele o rozsahu.

**Co zůstává otevřené z tohoto bloku:** zoom (§2.3), Z-pásma a střechy (§2.4),
voda a statiky u Britainu (neměřeno — chybí souřadnice ze snímků uživatele, ty
teď dává overlay), záseky a probliknutí (§2.6), `sim.regen` a spotřeba podle
váhy (§2.2), okno a černý pás GUI (rozhodnutí uživatele).



## ✅ CO JE NOVÉHO (20. session, DRUHÁ ČÁST) — RECEPTY NA TYPY, VÝHEŇ VE SVĚTĚ, BATOH, VÝROBA

**Zadání uživatele (doslova):** „Proveď všechny 3" — (1) push, (2) výheň a kovadlina do světa
+ batoh → `ruda → ingot → dagger`, (3) recepty z artů na typy.

| Věc | Co je hotové a čím je to doložené |
|---|---|
| **(1) Push** | `origin/main` = `105114e`; `git rev-list --count origin/main..HEAD` = **0**. PAT ze souboru, přes `http.extraHeader` (do trezoru se neukládá), před pushí zobrazen `git status` + `git diff --stat` |
| **(3) Recepty mluví TYPEM** | `data/recipes.json`: materiály i výsledky mají `item_type` (1035/1696 materiálů, 354/1053 výsledků — jen tam, kde se jméno v instalaci NAŠLO; vymyšlená identita by byla horší než žádná). `sim.craft` páruje materiál **podle typu** (`_shoda`), s fallbackem na art pro stará data. **Zisk je měřený**: case `item_type` sekce 3 vyrobí recept z materiálu s **JINÝM artem téhož typu** (do 20. session se nepočítal) |
| **Plural se nesmí rozpadnout** | `board%s` vs `boards` (= táž věc, jiný art) dělilo jeden předmět na DVA typy — naměřeno **33 dvojic**. `gen-content.py` je sjednocuje na jednotné číslo (typy 3812 → **3779**) a **sjednocuje kategorii v rámci typu** (role > vlastnost > fallback): `dagger` byl u některých artů „weapon" a u jiných „misc". Report: **0 rozporů typu** |
| **(2) Výheň a kovadlina VE SVĚTĚ** | ⚠ NAMĚŘENO sondou `p24-vyroba.gd`: v okolí Britainu (160 dlaždic) **není žádná stanice jako statik mapy** → `app/main._postav_stanice()` je pokládá jako **předměty na zem** (`parent == 0`) vedle hráče, z DAT podle role. `sim.craft.station_role_at(x,y)` hledá stanici **v mapě i v předmětech** (dřív jen v mapě → kliknutí na naši výheň vracelo `no_pair`) a `smelt` si stanici ověří znovu v dosahu, když nemá serial |
| **BATOH (`ui.backpack`)** | Okno se seznamem předmětů; obsah plní `app/main` z `container.contents`, **ikony jdou INJEKCÍ** z `render.textures` (ui/ nesmí na render/, docs/04 §4.1). Klávesa `B` (`app/player_controller.UI_KEYS`), otevření/zavření se hlásí do konzole |
| **VÝROBA (`ui.craft_gump`)** | Okno receptů; otevírá ho událost `gump_open{gump:"craft"}` — ⚠ **tu do 20. session sim vůbec neposílal** (recepty se ztratily ve `_call`), teď je posílá `sim.interaction._run_pair` podle smlouvy §4.6.3. Klik na recept dá POZADAVEK, který `app/main` pošle jako `Command{t:"craft"}` (UI nezná `sim` ani `Input`) |
| **CELÁ SMYČKA OVĚŘENÁ ŽIVĚ** | `_analyza/p24-vyroba.gd` na SKUTEČNÉ mapě: 12 rudy (Mining 30.0 → 31.5) → **12 ingotů** („You smelt the ore and get 12 ingots.") → kovadlina + kladivo → **196 receptů** → vyrobený **buckler** („You create the item."). Naměřeno i to, že tavení železa při Mining 30 často selže — **je to věrné** (`Ore.cs:355-370`: minSkill 25, maxSkill 75 → ~10 %) |

**Čísla (celá na tomto stromě):** testy **1283 → 1352 kontrol / 0 selhání** (48 case souborů,
všechny se načtou); brány `run-all.py` **11 měřeno / 0 chyb**; mutace
`--only item,container,interaction,craft` **46/46 chyceno** (dva nové vzory: párování materiálu
podle typu a hledání stanice v předmětech).

**⚠ NÁLEZY TÉTO ČÁSTI:**
(`a`) **Mutační harness počítá mutaci za chycenou podle PREFIXU hlášky.** Můj řetězový test
(prefix `interact`) mutaci `sim.craft` **odhalil**, ale harness ji vyhodnotil jako
„PROSLA - TEST JE SLEPÝ: sada selhala, ale bez FAIL tohoto modulu". Řešení: k řetězové kontrole
patří i **přímá kontrola té funkce s prefixem jejího modulu** (`sim.craft: station_role_at …`).
Bez toho vzniká falešný nález „test je slepý" u správného testu — a kdo ho uvěří, „opraví" ho.
(`b`) **`queue_free()` v testu bez framů nechá staré uzly v okně** — okno pak hlásí jiný obsah,
než má (naměřeno: batoh tvrdil prázdný text a chybějící ikonu). V `ui.backpack`/`ui.craft_gump`
se proto uvolňuje `remove_child` + `free()` (okamžitě).
(`c`) **`Control` je ve Godotu viditelný ve vychozím stavu** — nové okno musí `visible = false`
v `_init`, jinak při startu překryje svět (a test měří něco jiného než hra).
(`d`) **Smelting železa při Mining 30 selhává (~10 %) a je to SPRÁVNĚ** — než jsem to ověřil
v referenci, sonda hlásila „CHYBA - z ingotů nic". Sonda teď měří, kolik pokusů to dá
(a neúspěch učí: Mining roste).

**Co zůstává (pojmenované):** **předměty na zemi se NEKRESLÍ** — hráč výheň/kovadlinu uvidí
jen v žurnálu („A forge stands to the east."), ne na obrazovce; kreslení pozemských předmětů
patří do `render` s paritní branou a snímkem. Dále: recepty pořád nesou `tile` (art) vedle
typu (resolver jmen zůstal), `ui.target_cursor`/`target_reply`, loot/spawn a ukládání předmětů.

## ✅ CO JE NOVÉHO (20. session) — OBECNÁ INTERAKCE + „TYP JE IDENTITA, ART JE JEHO PROJEV"

**Zadání uživatele (doslova):** „Cílem je nyní zprovoznit nějakou interaktivitu…
Jak začnu těžbu?" → „tlačítko je nejen na těžbu, ale **všeobecně interaktivní**.
Do pytlíku přidej **všechny nástroje** — pokud má probíhat interakce s něčím, co
není připraveno, prostě neproběhne." → „všechna ruda je ruda, tedy použitelná —
aplikovat na arty" → „**Udělej B teď**" (typ jako zdroj pravdy, art jako jeho projev).

| Věc | Co je hotové a čím je to doložené |
|---|---|
| **Obecné interakční tlačítko** | `E` nebo `T` → `Command{t:"interact", target:{kind:"tile",…}}`; klient posílá **jen cíl**, nástroj vybírá SIM (`sim.interaction.interact`/`tool_for`) podle `harvest.resource_kind(x,y)` — hora → krumpáč/lopata, strom → sekera, voda → prut. Jeden úder na stisk (rozhodnutí uživatele). |
| **Všechny nástroje v batohu** | `app/main._give_tools()` — z DAT (`data/items.json`, `category == "tool"`), **jeden od každého TYPU** = 16 (dřív 28: bral se každý art → dva krumpáče, tři sekery) |
| **Těžba je HRATELNÁ** | `data/balance.json` → `player_start_skills` = šablona **Blacksmithy** z `research/profese.json` (4 skilly po 30.0). Naměřeno: se skilly 0 **0 rudy za 30 úderů**, s 30.0 **ruda za 1 úder**. ⚠ Jméno je z NAŠICH dat (`skills.mul` má „Blacksmithy", profesní šablona „Blacksmith") — s druhým jménem by se skill tiše nepřidal |
| **Nikdy ticho** | `sim.harvest` hlásí i `not_ore`/`not_tree`/`not_water`/`too_far`/`empty`/`busy` — do 20. session tyhle větve vracely jen slovník a hráč neviděl nic |
| **TYP = IDENTITA (rozhodnutí B)** | `data/items.json` má `type` (**3812 typů**, z toho **1277 s víc arty = 6213 artů**); `Item.type`; `same_pile` = **typ + hue**; `role`/`category` se ČTOU Z TYPU (`sim/entity/item.gd` je jediný vlastník mapy `art → typ → role`); `sim.interaction` i `sim.craft` ZRUŠILY svoje tabulky artů (`_by_tile`, `_role_by_tile` — byly to druhý a třetí načítač `items.json`) |
| **Ruda je ruda** | `gen-content.py`: roli dostávají **všechny nošené arty téhož jména** (ruda 0x59B7–0x59BA = 4 arty, dřevo 4, prkna 4, ingoty 3, svitky 13…); dekorace s váhou 255 zůstaly nedotčené; `--check` = shoda se souborem |
| **Smlouvy** | `docs/04 §4.5` — tvar `Item` má `type` (dopsáno 20. session). ⚠ `Command{t:"interact"}` je **NAD RÁMEC §4.3** (tabulka má 18 příkazů) — patří do `docs/04 §4.3`; je to pojmenovaná odchylka v hlavičce `sim/commands.gd` |

**Naměřená čísla (celá na tomto stromě):** testy **1320 kontrol / 0 selhání**
(před session 1283/0, +37); brány `run-all.py` **11 měřeno / 0 chyb** (G3 testy,
G11 smoke, G2 vrstvy, G5 obsah nad daty); mutace `--only item,container,interaction,craft`
**44/44 chyceno** a `--only harvest` **9/9**; živý průkaz `_analyza/p23-interakce.gd`
(16 nástrojů, klávesa → **1** příkaz s cílem hory, Mining 30.1, **ruda za 1 úder**,
se skillem 0 nic za 30 úderů). Nové soubory: `tests/cases/interact.gd` (nový case),
`_analyza/p23-interakce.gd` (sonda), `.cache/over-role-vsechny-arty.py` (měření dopadu).

**⚠ NÁLEZY, KTERÉ STOJÍ ZA POZORNOST:**
(`a`) **HEAD po commitu 19. session byl NEKONZISTENTNÍ.** Jejich commit `b8bff4d`
(`git add` přes víc souborů) stáhl i část práce 20. session (`app/main.gd`,
`app/input_map.gd`, `app/player_controller.gd`, `sim/commands.gd`, `app/config.gd`,
`data/balance.json`, `tests/cases/player_controller.gd`, `tools/gates/mutace-tests.py`),
ale `sim/systems/interaction.gd`, `sim/entity/item.gd`, `sim/systems/{harvest,craft}.gd`,
`data/items.json` a `tests/cases/interact.gd` nechal necommitnuté. **Důsledek:** v tom
commitu se trasuje `interact`, který tam `sim.interaction` neumí (hráč by dostal
„Not available yet: interact -> interaction.interact."). 20. session to docommitovala
(commit 20. session) — **kdo se vrací k `b8bff4d`, ať ví, že je to smíšený stav.**
(`b`) **Dva mrtvé mutační vzory.** Po refaktoru mířily `item/same_pile ignoruje hue`
a `interaction/id prostor se neprevadi` na kód, který už neexistuje — harness je
poctivě hlásil jako „PATRANA VETA SE NENASLA… nepočítá se" (a tím i `NECHYCENE`),
takže se opravily (vzor pro id prostory se přesunul z `interaction` do `item`,
protože se tam přestěhovala konverze `art ↔ tiledata id`). **Bez toho by sada
tvrdila, že měří, a neměřila.**
(`c`) **Typová vrstva hned odhalila vadu, kterou způsobila 20. session:** `_give_tools`
bral každý ART, ne typ → hráč dostal 28 nástrojů (dva krumpáče, tři sekery). Sonda
`p23-interakce.gd` to ukázala jako „nastroju v batohu: 28" proti dřívějším 16.
(`d`) **Sonda, která počítá rudu podle ROLE, hlásí nulu i když ruda vznikla** —
poprvé to vypadalo jako „těžba nefunguje", přitom v logu bylo dvakrát
„You gather some iron.". Sonda teď počítá podle ARTU (`ORE_ART`).

**Co zůstává mluvit ARTEM (pojmenované, ne zamlčené):** recepty
(`materials[].tile`/`result.tile`, 1053 záznamů — resolver jmen na art zůstal),
`world.stairs`/`world.doors` (vlastní tabulky z `stairs.txt`/`doors.txt`),
`world.tiledata` (váha/flagy/vrstva — to je SPRÁVNĚ art-keyed, je to tabulka klienta),
`ui.target_cursor` + `target_reply` (dvojklik na předmět → kurzor cíle; `use`/`use_on`
proto `check-wiring` pořád hlásí jako „volá ho jen tests/"), a loot/spawn/ukládání
předmětů (ještě neexistují — až vzniknou, mají mluvit typem).

**Příští krok k hratelné smyčce:** výheň a kovadlina **do světa jako předměty**
(dnes je svět nemá) + gump batohu → `ruda → ingot`. Ruda už má typ i roli, takže
chybí jen „něco ve světě, na co se dá kliknout".

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ-2.md`** (etapa 2, Úkoly 1–9);
> **Úkoly 1–4 a 6 (část) HOTOVÉ**, **Úkol 8 = M9 hotový** (15. session),
> a **16. session dodala `sim.harvest`, `sim.craft`, `ui.journal`**.
> **17. session byla LADICÍ** (uživatel zadal „Tohle debugovací session" se
> šesti vadami ze snímků) — **žádná nová mechanika**, jen opravy a měření;
> nálezy dvou teammateů jsou v `_analyza/p20a-nalez.md` a `_analyza/p20b-nalez.md`.
> **Rozhodnutí otevřených témat (co dřív čekalo na uživatele) je v
> [`ROZHODNUTI-2026-10-08.md`](ROZHODNUTI-2026-10-08.md)**.
> **Naměřený stav plánu je v `REVIZE-PLANU-2026-10-06.md`** a **stav granul
> měří** `python tools/plan-status.py`.
> **Kam pro co v referenčních zdrojích je `research/REJSTRIK-REFERENCI.md`**.
> **Datum:** 2026-10-08 (18. session). **Poslední změna kódu:** tato session
> (`render/sort.gd` — klíč: váha diagonály 769 → 300, vlastní průchod pro land;
> `render/chunk_mesh.gd` — `split_for_player(klic)`, `klic_kvadru`, UV svahů
> z rohů textury + půlpixelový inset, `SVAH_BARVA`, vynechání čekajících artů;
> **⚠ pozor: `SVAH_BARVA` už NENÍ jediná barva svahu — od 19. session (task-5)
> se svah stínuje podle normály (`svah_normal` / `svah_jas` / `svah_barva`),
> viz sekce „CO JE NOVÉHO (19. session)“;**
> `render/chunk_renderer.gd` — skrývání střech/stropů nad hráčem (`je_strop`,
> `pod_strechou`, `nastav_hrace`, `counts["skryto"]`); `render/texture_cache.gd`
> — stránky atlasu jako resource **na pozadí** (+ `page_pending`/`tick_nacteni`/
> `pending`/`verze`); `render/anim_player.gd` — sprite animace přes import;
> `app/world_view.gd` — `gui_odsazeni`, klíč hráče, čekání na stránky, falešné
> hlášení přetečení; `app/player_controller.gd` — plynulý a celočíselný posun,
> `run_toggle`; `app/input_map.gd` — `always_run = true` + přepínač;
> `app/main.gd` — černý pás pro GUI (320/120) a umístění oken;
> `ui/journal.gd` — `velikost` jako vstup; `sim/systems/movement.gd` —
> `stam <= 1`; `tools/gates/mutace-tests.py` — vzory po změnách;
> `tests/cases/{render_sort,chunk_mesh,chunk_renderer,world_view,player_controller,input,render_textures}.gd`;
> `docs/02`, `docs/04`, `LESSONS.md`).

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ-2.md`** (etapa 2, Úkoly 1–9);
> **Úkoly 1–4 a 6 (část) HOTOVÉ**, **Úkol 8 = M9 hotový** (15. session),
> **16. session dodala `sim.harvest`, `sim.craft`, `ui.journal`**.
> **17. a 18. session byly LADICÍ** (vady ze snímků, žádná nová mechanika).
> **19. session je LADICÍ taky**: zadání je `ZADANI-19-VADY-ZE-SNIMKU.md`
> (17 bodů od uživatele, doslovný přepis) a **všechna naměřená čísla jsou
> v `_analyza/p22-*.txt`**.
> **Rozhodnutí otevřených témat je v [`ROZHODNUTI-2026-10-08.md`](ROZHODNUTI-2026-10-08.md)**.
> **Naměřený stav plánu je v `REVIZE-PLANU-2026-10-06.md`** a **stav granul
> měří** `python tools/plan-status.py`.
> **Kam pro co v referenčních zdrojích je `research/REJSTRIK-REFERENCI.md`**.
> **Datum:** 2026-10-08 (19. session). **Poslední změna kódu:** tato session
> (`render/chunk_renderer.gd` — filtr patra `z >= _max_z` podle reference
> `UpdateMaxDrawZ()`; `render/sort.gd` — `klic_nad_diagonalou`; `app/world_view.gd`
> — **zoom jako vstup** (kolečko, `+`/`-`, výchozí 0,75) + `snap_screen` proti
> zrnění + **klic hrace z realnych objektu** (V1); `sim/commands.gd` — `case "turn"`;
> `sim/systems/movement.gd` — `turn(m, dir)`; `sim/world/walk.gd` — `_start_top`
> bere i statiky pod nohama (V11); `app/input_map.gd` — `auto_run_step`,
> `center_for` (V14), `turn_command`; `app/player_controller.gd` — `_publish_center`,
> `TURN_KEYS` (Ctrl+směr), `CANCEL_KEYS` (Esc), převzetí `player.dir` při otáčení;
> `app/config.gd` + `data/balance.json` — `player_start_stats`; `app/main.gd` —
> `_start_stats()`; `tools/gates/mutace-tests.py` — nové vzory;
> `tests/cases/{world_view,chunk_renderer,movement,input,player_controller,walk,balance,config}.gd`;
> `tests/lib.gd` — `text_at`; `LESSONS.md`).

## ✅ CO JE NOVÉHO (19. session) — SEDMNÁCT VAD ZE SNÍMKŮ A Z HRY

**Zadání uživatele:** 17 bodů (doslovný přepis je v `ZADANI-19-VADY-ZE-SNIMKU.md`)
+ 10 snímků. Rozděleno na tři tratě se **výhradními soubory** (aby se session
nepobily) a jednu **ověřovací**: `pohyb` (task-1), `teren` (task-2),
`patra` (task-3), `verifier` (task-4, nezávislé měření tvrzení) + Lead
(staty, řazení hráče, dokumentace, brány).

| Vada | Příčina (naměřená) | Oprava + doklad |
|---|---|---|
| **V1 „propadám se do textury mostu“** | Klič hrace byl `sort_key({mobile, x, y, z})` = klic mobila na jeho dlazdici. Statik na TEZE dlazdici ma ale `priority_z` vyssi (podlaha −1, statik s vyskou +1), takze mel **vetsi klic a kreslil se PO hracovi**. NAMERENO nezavisle (task-4): hrac na (1501,1599) klic 8 930 416 vs statik art 16585 **8 930 418** → hrac neni videt; na molu (1524,1485) ve stoje **0 px z 804**, ale statik art 18684 (key 8 903 418) ho kryl. | `world_view._sort_key_of_player(seznam)` = **maximum REALNYCH klíčů objektů na diagonale hráce a blíž, +1** (reference počítá mobilům hloubku z `maxZ` dlaždice hráče, `GameSceneDrawingSorting.cs:159-166`). Po opravě: ve stoje i na druhem miste **0 px kryto** (`p22-teren-most.gd`), snímek `p22-most-molo-krok.png`. **Vedomá hranice** (viz „Co se NEOPRAVILO“): statik o 1–2 diagonaly dal s vysokym `z` se muze dostat pred hrace. Testy `world_view` 7 a 8c meri oba smery. |
| **V2/V8 „západní břeh nemá břeh“** | **Není to kreslení.** NAMERENO (`p22-voda-mapa.gd`): z **459** prechodu voda/pevnina ma **0** pisek na strane pevniny, ve vsech 4 smerech (V 166, S 76, J 118, Z 99); `holes 0`, `missing_art_ids []`, `VOID_LAND_MAX` se netýká (id 168–171 > 2). U Britannie pisek v datech JE (id 35, z 3–9) a je videt. | **Neopraveno** — chybějící břeh je vlastnost `map0.mul` (jiná data / jiný klient), ne kód. Snímky `p22-voda-hrana-{ocean,britain}.png`. |
| **V3 „běží jen 3 políčka, stamina se neregeneruje“** | `sim.regen` **NEEXISTUJE** → stamina se nikdy nedoplní; `max_stam = DEX` a staty byly **10/10/10** = 10 kroku behu. | Uzivatel rozhodl: staty z `data/balance.json` (`player_start_stats`) → **75/130/20** = `max_hp 87`, `max_stam 130`, `max_mana 20` (soucet 225 = `STAT_CAP`). NAMERENO (`p22-staty-sonda.gd`): **129 kroku behu (25,8 s)**, pak chuze; nezavisly verifier to potvrdil a overil, ze se hodnota opravdu bere z DAT (DEX 130→60 dalo max_stam 60). |
| **V4 „auto-run za myší“** | Chybel uplne. | `input_map.auto_run_step(vstup)` (cista funkce, meritelna bez okna): START = levy klik pri drzenem pravem (`GameSceneInputHandler.cs:422-425`), STOP = novy stisk praveho (`:827-828`) nebo Esc; hlas do konzole. Verifier: 7/7 stavu, 20/20 kroku. |
| **V5 „při pohybu celá obrazovka zrní“** | Dve nezavisle priciny, obe namerene: (a) pri zoomu != 1 je svetovy pixel **zlomek** pixelu obrazovky → zbytek po nejlepsim posunu **52,27 %** (zoom 0,75) a **92,45 %** (0,5); (b) okno != 1280x720 → `canvas_items` stretch skaluje zlomkem (1300x740 → 1,0156x) → zbytek **96,74 %** i pri zoomu 1,0. | (a) opraveno `snap_screen` (kamera i postava na mrizku obrazovky): **0,23 % / 0,01 %** (`p22-teren-zrno.gd`). (b) **NEOPRAVENO** — je to `project.godot`; navrh `stretch/scale_mode="integer"` (viz „Co čeká na tebe“). |
| **V6 „po ~10 polích zásek na půl sekundy“** | 18. session zmerila 2 framy z 2 319 na ~130 ms pri **prekresleni runtime atlasu na GPU** (`hold`). | V teto session **NEMERENO znovu** (teren meril 4 000 framu synteticke chuze: 0 framu s prazdnou davkou, 62 framu `hold`, 89 framu > 33 ms, max 483,8 ms — ale synteticka chuze je ~4x rychlejsi nez realna). Zustava otevrene. |
| **V7 „divně se zobrazuje most, břeh a voda“** | Kanál u Britannie: pisek jen na severozapadni strane (1 dlazdice, z 3–9); „voda“ v kanalu je land 79–95/100 (bez WET, z −15), jeji art vypada jako voda; hrac stojici tam je na z=−15 = **POD** mostem (paluba z=10) → kryty 37,6 %. | Kresleni je verne (0 der, 0 chybejiciho artu). To, ze se hrac na most nedostane, byla **V11** (opraveno). **NEMERENO**: srovnani s zivym UO klientem (na stanici neni). |
| **V9 „je to moc přiblížené, chce to oddálit“** | Zmereny vychozi stav: kamera **nemela zoom**, viditelna plocha sveta 960x600 px = **36,0 dlazdice/osu**. | **Zoom jako vstup** (kolecko mysi, `+`/`-`/numpad/`=`, meze 0,5–2,0, krok 1,25, vychozi **0,75**): **48,0 dlazdice/osu (+33 %)**, 1280x800 px; okno seznamu roste s oddalenim (112x64 → 142x64 → 202x72), obrazovka zustava pokryta pri kazdem zoomu, 0 der, `pretek false` i pri zoomu 0,5 (26 528 kvadru), hrac presne ve stredu (odchylka < 0,001 px). Cisla: `p22-zoom-sonda.txt`, `p22-rozhled-sonda.txt`. |
| **V10 „můžeme to uhladit / zlepšit assety?“** | Nearest vs Linear zmereno na stejnem vyrezu: ostrost 0,22 (Nearest) vs **0,18 (Linear = −18 %, rozmazane)**. | **Doporuceni**: vychozi filtr NEMENIT (Linear maze pixely); rozhled resi zoom; kvalitu artu nezvedne zadny prepinac (44px pixel-art z originalnich dat; HD = jiny zdroj). Detail v `p22-zoom-srovnani-filtr.png`. |
| **Svah byl plošně jedna barva (mimo zadání, dodáno)** | Všech **3 914** dlaždic na svahu v Británii mělo jas **0,85355339** — kopec neměl směr světla. Reference (`IsometricWorld.fx:14,60-69`, `Land.cs:164-238`) počítá jas z normály čtyř rohů. | `render/chunk_mesh.gd` + `app/world_view._draw_slope` (jedna funkce `svah_barva` pro obě cesty): jas **0,500–1,000**, rovná dlažba **přesně** původní hodnota. `Brightlight` je **vstup** s výchozí 1.0 (profil 15 by dal 0,32–**1,07** → přesvícení, proto ořez). Doklady: **[`NASTROJE-SVETLO-SVAHU.md`](NASTROJE-SVETLO-SVAHU.md)** (v gitu), snímek `_analyza/p22-svetlo-pred-po-pred-po.png`, testy **1 362/0**, mutace 6/6 ručně + **32/32 v bráně** (`--only chunk_mesh,world_view`). |
| **Výměna assetů za CC0 sadu SBS (odpověď na „můžeme nahradit?“)** | `E:\Workspaces\assets` má 8 CC0 balíků (Screaming Brain Studios, 748 PNG, 29 druhů dlaždic). **Geometrie sedí**: kosočtverec SBS je **2:1** (změřeno 12/12 kandidátů) a stejně jako UO. **Ale formát dlaždice je jiný**: UO je **čtverec 44×44**, který se při skládání PŘEKRÝVÁ (kosočtverec je jen tvar kresby uvnitř), kdežto SBS je **samostatný kosočtverec 44×22** → v našem kreslení zůstane **polovina místa nevykrytá**. | **NEDOPORUČENO a zastaveno** (rozhodnutí uživatele: „vyměňovat ne“). Naměřeno ve hře: bez výměny **2,7 %** černých pixelů ve světě, s výměnou (dávka) **41,9 %**, s výměnou (stará cesta) **1,1 %** ale dlaždice jsou světlé fleky. Závěr: výměna by **nepřidala detail** (44 px cíl), jen licenční čistotu — a stála by přepis kreslení. **Háček zůstal v kódu** (`world_view.nastav_vymenu()` + `chunk_mesh.vymena`) a je **vypnutý** (default = dnešní stav), s testem a mutacemi (18/18). Měření: `_analyza/p22-pokryti.py`, snímky `p22-sbs-hra-*`. |
| **Vyšší rozměr (odpověď na „nedá se použít větší rozměr?“)** | Art je 44 px a zoom krok 22 px (`ISO_STEP`). Zvětšit rozměr **jde** (zoom 2,0 = krok 44 px, dlaždice 88 px na obrazovce) — ale je to **jen zvětšení téhož artu**: pixel se kreslí 2× větší, **žádný nový detail nevznikne** (v datech není — mapa má jedno celé číslo na buňku). Snímky `_analyza/p22-rozmery-zoom-{10,125,15,20}.png`, sonda `p22-rozmery-hry.gd`. | Vysvětleno a změřené; **nic se neměnilo** (rozhodnutí uživatele: zůstat u dneška). Skutečné „víc detailů“ by znamenalo jiný, detailnější art **a** jiné měřítko světa (přepis atlasu, mapy i kolizí). |
| **V11 „neumožní mi jít na most“** | **NENI diagonala** (molo je 4 dlazdice siroke). `_start_top` ignoroval statiky POD NOHAMI: dlazdice (1522,1468) prkno art 2173 z=0 (Surface+Bridge, vyska 4) → stojna vyska 2; dalsi prkno z=5 → nas strop `2+2=4` < `itemTop 5` → **„height“** na vsech 4 sloupcich paluby. | `_start_top` bere i statiky (`GetStartZ`, `Movement.cs:617-641`, pro strop kroku PLNA vyska). NAMERENO: bloku „height“ v koridoru 52 → **44**, chuze sondou **76 dlazdic** z nabrezi na konec mola (59 kroku na palube z=11). |
| **V12/V16/V17 „zobrazuje se patro nademnou“** | Stara podminka skryvala jen `je_strop` (Roof nebo Surface+Background) nad `hrac+16`, takze **zdivo, okno, trabec, postel ani zabradli** se neskryly. Reference (`GameSceneDrawingSorting.cs:57-213` `UpdateMaxDrawZ()`) pocita **jeden strop `_maxZ`** (kandidat = statik nad `hrac+14` s `(flags & (Transparent\|Foliage))==0 && (!Roof \|\| Surface)`, nikdy pod `hrac+16`, bez kandidata 127) a kresli jen `z < _maxZ`. | Filtr `z_statiku >= _max_z` **sjednoceny** s pravidlem 18. session (strecha bez `Surface` strop nenastavi — v Britanii 204 z 2 970 dlazdic, 6,9 %). NAMERENO: skryto 963→**1354**, 1248→**1664**, 1394→**1971**, 1163→**2075** (vsechno zdivo/okna/trabce/postele), na otevrenem miste **0** a strop 127. V behu hry Δobjektu == Δskryto (2895/3792/3721) — overil nezavisly verifier. **Kadence: 120 kroku ulici i vystup po schodisti → 0 prestaveb navic.** |
| **V13 „vzácně problikne obrazovka“** | Nereprodukovano: 4 000 framu synteticke chuze → 0 framu s prazdnou davkou, 5 podezrelych snimku v poradku (`p22-teren-problik-0..4.png`). | **NEMERENO** — potrebuji snimek nebo misto od uzivatele. |
| **V14 „špatně detekuje, kam mířím myší“** | Stred pro smer z mysi se pocital z `z = 0` (`app/loop.gd:39`), ale kamera je na `z * Z_SCALE` → na z=10 byl stred o **40 px niz**. NAMERENO: **4 473 z 11 163** pozic kurzoru (40 %) vracelo jiny smer. Podezreni na `gui_odsazeni` se **NEPOTVRDILO** (vykrati se). | Klient posila PRESNOU pozici hrace (`player_controller._publish_center()` → `input_map.player_screen`, `center_for`). Po oprave 0 spatnych sektoru; nezavisly verifier: **24/24** referencnich bodu, stary vypocet by se rozesel v **17/24** (meridlo tedy neni slepe). |
| **V15 „neumí se otáčet / odmítá se hýbat“** | (a) `sim/commands.gd` **nemel `case "turn"`** → dispatch odpovidal „Not available yet“ a `movement.turn()` se nikdy nezavolal; (b) ani po doplneni se otoceni **nekreslilo** — `mobile_turned` nemel v `app/` zadneho konzumenta. | (a) doplnen `case "turn"` (Lead); (b) `player_controller.update_step` pri prazdnem kroku **prebira `player.dir`** (Lead). Overeno `p22-turn-sonda.gd`: dir 2/4/6/0 → sim i kresleni sedi, pozice se nemeni, 0 selhani ze 4; nezavisly verifier to potvrdil. **Otáčení je na `Ctrl + šipka`/numpad.** |
| **V15b „měl by jít podél zdi“** | **Není vada**: reference neklouze — ClassicUO `MoveCharacterByMouseInput` posila presny smer, ServUO `Mobile.Move` pri neuspechu jen `return false`; wall-slide ma POUZE AI (ModernUO `AIMovement.cs:668-700`). Diagonalni pravidlo (obe ortogonalni dlazdice) je verne (`Movement.cs:550-554`), hlaska „You cannot move there.“ do zurnalu zustava (zadny tichy stav). | Bez zmeny kodu; uzivateli vysvetlit slovy: **drz smer PODEL zdi, ne do ni.** |
| **V17b „nedaří se mi vystoupat“** | **Není pravidlo chuze.** NAMERENO (BFS pres `can_step`, `p22-pohyb-schody-sonda.gd`): z namesti (1495,1630,z=10) na 1. patro (z>=40) se **DOJDE** — 1 470 stavu, cesta **29 kroku**. „Nevyjde“ byla past: `surface_z` na dlazdici se schodem vraci **60** (strop patra, art 1407), ne vysku, po ktere se chodi (21..40). Navrzena zmena `_blokuje_statik` (`_height` misto `_calc_height`) byla **otestovana a ZAMITNUTA** (5 testu FAIL + sonda „nedojde“); reference ma `checkZ + CalcHeight` (`Movement.cs:84`). | Pravidlo se NEMENILO; opraven **nepravdivy komentar** u `surface_z` (tvrdil „nejnizsi povrch“, funkce vraci maximum) + novy test `walk` 2h, ktery vadu zamkne. |

**Integrační čísla (naměřeno dnes):** sada **1 320 kontrol / 0 selhání** (45 case
souborů; bazově 1 201/0 → 1 212/0 po statých → 1 278/0 po tratích B a C →
1 283/0 po V1 → 1 320/0 po uzavření slepých míst z mutací). Brány `run-all.py`:
**11 měřeno / 0 vad** (G10 na čerstvém snímku). Mutace **84 z 84 chyceno**
(6 modulů, které jsem měnil: `sort`, `walk`, `world_view`, `input`,
`player_controller`, `chunk_renderer`; běh `--only`,
`_analyza/p22-mutace-trate6.txt`); `player_controller` zvlášť 10/10 po opravě
testu níže. `p22-rozhled-sonda.gd`: viewport 1280x720, viditelná plocha světa
960x600 px, **43 dlaždic na ose (x−y) a 27 na (x+y)** při zoomu 1,0 (při
výchozím 0,75 je to 48,0 dlaždice/osu).

**⚠ Co našel až mutační běh (a co se opravilo) — to je dnešní nejcennější nález:**
1. **Slepé místo ve `walk`:** kontrola „voda vrací `blocked`“ prošla i s vymazanou
   kontrolou flagu `F_WET`, protože voda byla **jediný kandidát na povrch** a
   `blocked` vyšlo samo. Opraveno testem, který staví hráče **vysoko nad vodu**
   (krok DOLŮ, kde reference žádný limit nemá) — bez `F_WET` je pak voda
   kandidátem a krok vyjde `ok`.
2. **Slepé místo v `player_controller`:** test volal `_publish_center()` přímo,
   takže nepoznal, když se volání **vyhodilo z `_process`** (skutečná cesta).
   Doplněna statická kontrola těla `_process` — **a ta sama byla slepá**, protože
   četla cestu natvrdo (`res://app/player_controller.gd`) místo vstupu `_arg`;
   teprve po opravě mutace spadne (10/10).
3. **Tři mrtvé mutační vzory** (`walk`, `input` ×2): kód se při V14/V11 přepsal,
   takže vzory cílily text, který v souboru už není. Nahrazeny vzory na totéž
   v novém kódu. **Jeden vzor byl smazán jako neměřitelný** (`sort`: záloha
   `klic_nad_diagonalou` — nemá test, který by ji odlišil).
4. **Test hráčova klíče prošel dvakrát ze špatného důvodu** (jednou volal funkci
   bez seznamu, podruhé tvrdil hranici, která v klíči neplatí) — viz `LESSONS.md`
   „Pasti, které mě dnes chytily“ body 3 a 5.

**Nezávislé ověření (task-4, teammate `verifier`) — všechny revize na SHA-256:**
14 tvrzení měřeno vlastním během, **12 SEDÍ**, 1 ČÁSTEČNĚ (snímek
`-kandidat-1501-1599` je syntetický stav — hráč na té dlaždici **není vidět**,
protože ho kryl statik s klíčem o 2 vyšším, a dlaždice je nedosažitelná; to je
**N1**, stejná příčina jako V1) a nález N2/N3 (`turn` dispatch i kreslení —
oba byly opraveny). Verifier doložil i to, že staty se opravdu berou z DAT
(DEX 130→60 v `data/balance.json` dalo `max_stam` 60 a 59 kroků běhu; po
navrácení byl soubor **bajtově shodný**, SHA-256 `5450367D…`).
Souhrn: `_analyza/p22-overeni-00-souhrn.md`.

**⚠ Co se NEOPRAVILO / NEMĚŘILO (nezamlčeno):**
(`a`) **V1 má vědomou hranici**: hráč se kreslí ZA vším, co ho může překrýt, takže
statik o 1–2 diagonály dal s vysokým `z` (zeď/strom vepředu) se může dostat před
něj — to je cena za to, že ho nepřekrývá podlaha pod ním, a je to stejné chování
jako reference. Testy `world_view` 7/8c měří oba směry;
(`b`) **V5 druhá příčina** (okno != 1280x720, zlomkové škálování canvasu, zbytek
**96,74 %**) je **neopravená** — patří do `project.godot` (viz „Co čeká na tebe“);
(`c`) **V2/V8 = chybějící břeh v datech mapy** (0 písku z 459 přechodů) — kód
s tím nic neudělá;
(`d`) **V13 probliknutí nereprodukováno** (4 000 framů, 0 prázdných dávek);
(`e`) **V6 zásek** se v této session neměřil znovu (18. session: 2 framy z 2 319
na ~130 ms při překreslení runtime atlasu na GPU);
(`f`) **schody shluku #2 z dlaždice schodu samotné** nejdou (7 statiků v jednom
sloupci) — ale **z ulice se na patro dojde** (29 kroků), takže to není blokace hry;
(`g`) **NEMĚŘENO**: srovnání s živým UO klientem, chování na jiných facetách než
Britannie, přesný počet kroků, které hráč ujde v běhu hry (měřil se `can_step`
a BFS, ne chůze), vliv zoomu 0,5 na cenu přestavby seznamu;
(`h`) **`stretch/scale_mode="integer"`** ověřeno jen tak, že Godot 4.7.2 tu hodnotu
zná (`hint_string 'fractional,integer'`, `p22-stretch-sonda.gd`) — **vliv na obraz
jsem naměřit nedokázal** (moje metrika ostrosti oba režimy nerozlišila: 72,65 %
vs 72,66 % hran), takže se **neměnilo nic**.

## ✅ CO JE NOVÉHO (18. session) — ŠEST VAD Z FOTEK: řazení, terén, pohyb, běh, střechy, GUI

**Zadání uživatele (doslova):** šest fotek („zeď prosvítá přes střechu“, „svah
prosvítá přes schody“, „svah prosvítá přes most“, „naše hra vs. živý server —
krajina se neslévá, máme ji kostkovanou, svahy jsou různobarevné, břehy se
opakují a zobrazuje se špatně tráva“) + poslední body: občas zčerná obrazovka
(u kopců), periodický zásek ve stejné chvíli jako WARNING
`Loaded resource as image file`, trhavý ale pravidelný pohyb, chybějící běh,
„postava se nadále zobrazuje přes střechu, takže v budově nevidím vnitřek“,
a journal přes herní okno (žádost o starý způsob UO s černým pásem).
**Každá oprava má naměřenou příčinu a doklad; co se naměřit nepodařilo, je
níže v „Co se NEOPRAVILO / NEMĚŘILO“.**

| Vada | Příčina (naměřená) | Oprava + doklad |
|---|---|---|
| **„zeď prosvítá přes střechu“ (foto 1)** | Klíč řazení měl **moc malou váhu `z`**: `K_PER_DIAGONAL = 769 > Z_SPAN*LAYERS = 765`, takže `z` nepřebilo **ani jednu** diagonálu. Reference má `(x + y) + (127 + z) * 0.01f` → `z` přebije **~2,55 diagonály** (`View.cs:83`) | `K_PER_DIAGONAL` **769 → 300** (= 765/2,55); test `render_sort` 3c („z přebije 1 i 2 kroky mřížky, **ne 3**“) + mutace „krok 300 → 769“ |
| **„svah prosvítá přes schody/most“ (fota 2, 3)** | **Land byl ve stejném průchodu jako statiky.** Reference kreslí land ve **zvláštním průchodu před statiky** (`RenderLists.cs:199-232`), takže statik **nikdy** nemůže být překreslen půdou; u nás svah (land s vysokým `z`) překreslil schody i most | `PASS_LAND = 0` jako nejvyšší řád klíče; test `render_sort` 3d („land před statiky i s nejvyšším `z` na nejbližší diagonále“) + mutace „land ztratí vlastní průchod“ |
| **Dělení dávky „před/po hráči“** | Bylo podle **diagonály** (`split(diagonala)`) — jenže od chvíle, kdy `z` přebije 2,5 diagonály, je diagonala špatná hranice. Navíc se mobily na diagonále hráče vyjímaly do seznamu `hranice()` | `split_for_player(klic)` = binární hledání v **neklesajícím poli celých klíčů** (`klic_kvadru(i)`); `hranice()` zrušeno. Testy `chunk_mesh` (dvojice 2+3 kvadry, „bez hráče je vše v po hráči“) |
| **„svahy jsou různobarevné / jiná světlost“ (fota 4–6)** | **`slope_uv()` mapoval STŘEDY HRAN textury** na vrcholy diamantu (`(0.5,0) (1,0.5) (0.5,1) (0,0.5)`) — reference mapuje **ROHY** (`_cornerOffsetX/Y`, `Batcher2D.cs:16-17`, `ChunkMesh.cs:464-475`). Naše mapa byla vůči referenci **otočená o 45°** a jinak škálovaná, takže každý svah vzorkoval jinou část textury | `slope_uv(sirka, vyska)` = rohy `(0,0),(1,0),(1,1),(0,1)` + **půlpixelový inset** (`rect.X + 0.5`, `Width - 1`); navíc barva svahu `SVAH_BARVA` = **0.85355339** (reference stíní jen stretched land, `IsometricWorld.fx:60-69`). Testy `world_view` 11 + mutace v `chunk_mesh` |
| **„kostkovaná krajina“ / trhavý obraz** | Dvě věci: (a) svět se kreslil na **neceločíselné** pozice (17. session zavedla posun každý frame), (b) `step_fraction` zaokrouhloval čas **dolů na 80 ms**, takže se posun měnil jen 5× za krok | Naměřeno (`_analyza/p21-teren-sonda.gd`): posun o **0,5 px** změní **91,55 %** pixelů obrazu. Oprava: `step_fraction` = `elapsed/delay` (float) a `player_pixel_offset()` = **`round`** na celý pixel (reference kreslí na celá čísla, `GameObject.cs:152-153`) |
| **„chybí běh jako rychlost pohybu“** | `always_run` byl `false` a **nikdo** ho nezapnul → klávesy i numpad chodily vždy 400 ms; běh šel jen drženým pravým tlačítkem >190 px | `always_run = true` (UO má běh jako výchozí pohyb, `PlayerMobile.cs:530`) + **Shift** přepíná (`run_toggle`); `stam <= 1` zakáže běh (`:532`) místo `<= 0`. Testy `input` 7c + `player_controller` |
| **„postava se zobrazuje přes střechu, v budově není vidět vnitřek“** | Na dlaždici hráče jsou statiky **60 jednotek nad ním** (naměřeno: 96 statiků v okně, 25 nad jeho výškou) a kreslily se; reference v `UpdateMaxDrawZ()` (`GameSceneDrawingSorting.cs:57-213`) v tom případě hlásí `_noDrawRoofs` a **střechy vůbec nekreslí** | `render.chunk.je_strop/pod_strechou/nastav_hrace`, `skryt_strechy`, `counts()["skryto"]`; snímek `_analyza/p21-uvnitr.png` (vidět postele a koberce v domě). ⚠ **Naměřeno:** `Roof` flag má jen 1 040 předmětů; běžné střechy (`slate roof`, flags `0x04006201`) mají `Surface|Background` — proto se za strop bere i to |
| **Zásek + WARNING v logu** | Byla to **jedna** věc: stránka atlasu (2048², 16 MB) se četla `Image.load()` **synchronně uvnitř `build()`**. Naměřeno: **~58 ms na stránku** (`_analyza/p21-atlas-cena.gd`, 34 stránek = 1 982 ms) | Stránky se načítají jako **resource na pozadí** (`ResourceLoader.load_threaded_request`; mají `.import`, `compress/mode=0`, bez mipmap) a `render.anim` taky; kdo stránku nemá, dostane `page_pending()` → objekt se **vynechá** (není to „chybí art“ = magenta). `tick_nacteni()` vyzvedne hotové **každý frame** |
| **„journal mi zakrývá výhled“** | Hra kreslila svět přes celé okno a GUI na něj | **Černý pás pro GUI** (starý způsob UO, na přání uživatele): `GUI_PAS_VPRAVO = 320`, `GUI_PAS_DOLE = 120` (`CanvasLayer` layer 1 pod HUD layer 2), žurnál v pravém pásu, stavový pruh v dolním; kamera se posune o `view.gui_odsazeni = (160, 60)`, aby hráč stál ve středu **viditelného** světa. Snímek `_analyza/p21-britain.png` |

**Integrační čísla (naměřeno dnes):** sada **1 201 kontrol / 0 selhání** (44 case
souborů, bylo 1 178/0); brány `run-all.py` **11 měřeno / 0 vad** (G10 měřeno na
**čerstvém** snímku); `check-docs-refs` / `check-zadani` / `roadmap-gen --check`
**exit 0**; **draw calls 5**. **Mutace (8 změněných modulů): 77 z 77 chyceno**,
smlouva vstupu OK (běh `--only sort,chunk_mesh,chunk_renderer,world_view,player_controller,input,movement,journal`;
dvě mutace byly vyměněny: „čekající stránka jako díra“ odhalila chybějící test
(část F v `tests/cases/chunk_mesh.gd`), „stavba se nedělí do framů“ nemohla
selhat → nahrazena mutací na `_STAVBA_MS`).
**Chůze v běhu hry** (`_analyza/p21-chuze.gd`, **2 400 framů**, střídavě NE/SE,
běh): frame ms **median 0,59**, **max 133,33**; rozpad měřených framů:
**≤1 ms 2 093**, ≤2 ms 116, ≤4 ms 42, ≤8 ms 23, ≤16 ms 15, ≤33 ms 24,
**≤150 ms 6**, >150 ms 0 → **> 16 ms jen 30 z 2 319 (1,3 %)**, z toho 6 je
**75–133 ms** (přestavba dávky + první použití překreslené stránky) a 24 je
16–33 ms. Cesty kreslení (`world_view.cesty()`): `davkou 2538`, `predchozi 4`,
`puvodni 8` (původní cesta = jen start), `staveb 7`.
**0 černých snímků** ze 41; **0 framů s prázdnou dávkou**, které by způsobilo
kreslení (4 framy měly prázdná *počítadla* na startu);
`mesh_stats()` `kvadru 13081`, `pretek false`, `ceka 0`; za chůze se dotáhlo
6 dalších stránek atlasu **bez záseku od načítání**.
**WARNINGy o `Loaded resource as image file` zmizely** (atlas i animace).

> ⚠⚠ **Pozor na číslo z dřívějška:** první běhy téhle sondy hlásily
> „75 dlouhých framů“ — a **45 z nich bylo způsobeno SONDOU SAMOTNOU**:
> `get_image()` + `save_png` na snímek se projeví až na **následujícím** framu
> (odectení z GPU). Sonda proto dnes vynechává frame se snímkem **i ten další**;
> teprve pak je vidět skutečný stav (30 framů). Kdo bude měřit frame časy,
> **nesmí u toho ukládat snímky** — nebo je musí z měření vyloučit.

**TERÉN JE VYKRESLENÝ PIXEL NA PIXEL** (`_analyza/p21-teren-parita.gd`, nová
sonda): na čisté rovné louce bez statiků (nalezené programově: (1552, 1400), z −5)
se 44×44 čtverec dlaždice na obrazovce srovnává s artem z atlasové stránky —
**4 ze 7 dlaždic mají 96–97 % pixelů přesně** a **střední odchylka 0,4–0,5/255**
(zbytek jsou pixely, kam už zasahuje sousední dlaždice o jiné výšce). Celková
shoda 86,1 % (12,1/255) včetně těch překrytých. **Co z toho plyne:** naše kreslení
terénu je věrné artu; „kostkovaný“ dojem tedy není chyba vzorkování ani UV —
je to art sám (a překryvy dlaždic na změnách výšky, které má i klient).

**⚠ Co se NEOPRAVILO / NEMĚŘILO (nezamlčeno):**
(`a`) ✅ **Přestavba dávky je VYŘEŠENÁ (R6) — časově dělená.** Naměřeno
(`_analyza/p21-chuze.gd`, 2 400 framů, snímky vyloučené z měření):
**2 037 z 2 319 framů ≤ 1 ms**, framů **> 16 ms: 25** (1,1 %), **> 33 ms: 2**,
max **133 ms** (dřív 6 framů 75–150 ms + 28 framů 16–33 ms).
Stavba se dělá po částech (`chunk_mesh.krok(8 ms)`, 103–166 kroků na stavbu)
a během ní se kreslí **PŘEDCHOZÍ** dávka (`predchozi 137`, `puvodni` jen 29 na
startu). Geometrie je **bit po bitu stejná** jako atomická stavba — dokazuje to
test `chunk_mesh` (sekce G: `_verts/_uvs/_barvy/_klic` se rovnají) a mutace
„obří rozpočet na frame“.
**⚠ CO ZŮSTÁVÁ (změřené, ne zamlčené):** 2 framy z 2 319 mají **~130 ms** a padají
na frame, kdy stavba **dokončí** (`hold 2`) — tj. na **překreslení runtime atlasu
na GPU** (600 spritů do 2048² `SubViewport` + `UPDATE_ONCE`), ne na stavbu
samotnou (`stavba_ms` je rozložená do 8ms kroků, `faze1_ms` = 8,6 ms).
Další krok (samostatný, levný nápad): `render_target_clear_mode = CLEAR_MODE_NEVER`
+ kreslit jen NOVÉ sprity (přeskládání stránky je vzácné: `repakov 0`) — tím by
zmizel i ten poslední zásek. **Do té doby je to 2 záseky za ~7 s chůze místo 6.**
(`b`) **Černá obrazovka se NEPODAŘILA reprodukovat** — 2 400 framů běhu ve dvou
směrech, **0** černých snímků (nejčernější 39,3 % tmavých pixelů = tmavý terén),
**0 framů s prázdnou dávkou**. Pravděpodobná příčina je už opravená cesta
„přetečení atlasu → prázdný mesh“ ze 17. session. **Když se to vrátí, potřebuji
snímek nebo místo** (bylo hlášeno „u kopců“).
(`c`) **„Kostkovaná krajina“ je změřená jako VĚRNÁ ARTU** (viz parita výše):
čisté dlaždice sedí na pixel (odchylka 0,4/255), rozdíl proti živému serveru tedy
není v našem kreslení. Opravené zůstává to, co naměřené bylo: UV svahů (byly
otočené o 45°) a subpixelový posun (0,5 px = 91,55 % pixelů). Jestli je rozdíl
vidět dál, potřebuji **konkrétní dlaždici + dva snímky**.
(`d`) **Postavu v budově může zakrýt PŘEDNÍ ZEĎ** (střecha se už skryje).
⚠ **Ověřeno v referenci:** `UseCircleOfTransparency` je **výchozí `false`**
(`Profile.cs:126`), takže i živý klient hráče za zdí schová — chybí tedy
**funkce**, ne oprava. Reference ji má: `TransparentTest` (`View.cs:98-101`,
`StaticView.cs:17-31`/`MultiView.cs:18-32`, referenční Z = **hráč + 5**),
fade po **±25**, `FOLIAGE_ALPHA = 76`.
(`e`) **Fotku 1 se nepodařilo reprodukovat přesně** (nemám k dispozici snímek od
uživatele, jen popis). Oprava je ale **věrná referenci** (poměr vah klíče), takže
platí i pro místo z fotky; kdyby přesto prosvítalo, je to nový nález.
(`f`) **`nodraw` dlaždice (land id ≤ 2) zůstávají černé** (rozhodnutí do `docs/`).
(`g`) **První frame hry stojí ~2 s** (načtení 34 stránek; R5) — teď asynchronně,
takže se hra rozjede dřív a stránky dotékají za běhu (`ceka`), ale celková doba
načtení se nezkrátila.

**Nové sondy (všechny v `_analyza/`, spouštěcí příkaz v hlavičce):**
`p21-teren-sonda.gd` (subpixel A/B), `p21-snimky.gd` (7 snímků míst),
`p21-chuze.gd` (chůze: frame časy, černé framy, textury, dávka),
`p21-atlas-cena.gd` (cena načtení stránky), `p21-strecha-sonda.gd` (co je nad
hráčem), `p21-land-art.py` (alpha/bbox land artu), `p21-vyrez.py` (výřezy pro
`read_image`).



## ✅ CO JE NOVÉHO (17. session) — ŠEST VAD ZE SNÍMKŮ: PĚT OPRAVENO, JEDNA ZMĚŘENA

**Zadání uživatele (doslova):** „Tohle debugovací session" + šest pozorování při
hře (pauza po 4 krocích, skokový obraz, animace nemění orientaci, postava na
střeše, černé čtverce u stoupání, rozbité textury každým ~4. krokem).
**Každá vada má naměřenou příčinu** (ne dohad) a opravené mají i snímek/test.

| Vada uživatele | Příčina (naměřená) | Oprava + doklad |
|---|---|---|
| **„Po 4 krocích pauza"** | `RECENTER_TILES = 4` + pevné okno `VIEW_TILES_X/Y`: přestavba seznamu objektů vyšla **přesně po 4 krocích** a stála **85–98 ms** (7 872 objektů: `z_grid` 10–15, land 26–31, statiky 27–33, řazení 21–25 ms). `_analyza/p20-kadence.gd` | Okno se **odvozuje od obrazovky** (`_list_okraj()`) a `RECENTER_TILES = 8` → přestavba ~3× méně často. Naměřeno: dlouhých framů ≥ 33 ms **13 → 4** (RECENTER 4 → 14), cena jednoho okna 50–250 ms. **Zbývá: přestavba je pořád jediný zásek (viz „Co čeká na tebe")** |
| **„Obraz se pohybuje skokově"** | Kamera se posouvala **jen při změně dlaždice** (`_follow`): skok **44,00 px na frame** (= celá dlaždice). Postava se přitom posouvala plynule, takže se obě rozešly. `_analyza/p20-finalni.gd` | `look_at_tile(tile, z, offset)` + kamera každý frame → **MAX skok 6,23 px** a hráč je **0,00 px** od středu. Reference: ClassicUO `Mobile.cs:776-782` |
| **„Animace nemění orientaci"** | Směr kreslení se bral z `player.dir`, který `apply_step` přepíše **až na konci kroku (400 ms)** → naměřeno **1 295 framů**, kdy se kreslil jiný směr, než jakým se postava posouvala | Smer kresleni je stav **klienta** (`_view_dir`): mění se **hned se záměrem** kroku. Test `player_controller` 7 + `world_view` 7d |
| **„Postava je vidět na střeše"** | Klíč řazení měl **vrstvu PŘED `z`** (`(diag*3+layer)*256+z`): statik (vrstva 1) na téže diagonále šel PŘED mobilem (vrstva 2), i když byl o 11 jednotek výš — naměřeno **5 dlaždic** v Británii, kde střecha plně překrývala sprite hráče a kreslila se před ním. Chůze **vyloučena** (205 framů: `pos.z − z_at = 0`). `_analyza/p20a-nalez.md` | Klíč = `diagonal*769 + (z−Z_MIN)*3 + layer` (**diagonála → `z` → vrstva**), přesně jako ClassicUO `CalculateDepthZ()` (`View.cs:83`). Snímky: `.cache/render/p20a2/strecha_*.png` |
| **„Černé čtverce u stoupání"** | **Runtime atlas se na GPU nikdy nepřekreslil**: `UPDATE_ONCE` se přiřadí jednou v `_init` a `queue_redraw()` ho znovu neoživí (vlastnost přitom čte 1). Po přeložení stránky zůstalo staré rozvržení na nových UV → 60,3 % kvadrů s průhledným středem (černo). `_analyza/p20b-nalez.md` | Re-arm `UPDATE_ONCE` před každým `queue_redraw()`. **Mutační důkaz** (okno): s re-armem se hash stránky změní, bez něj zůstane stejný (`_analyza/p20b2-stranka.gd`) |
| **„Každým ~4. krokem se rozbíjí zobrazování"** | Totéž co černé čtverce (přestavba seznamu = přeložení stránky) **plus** atlas 2048² se po zvětšení okna už nevešel (`pretek=true`, `bez_slotu=39`) a v tom stavu se **svět nekreslil vůbec** (909 618 px / 98,70 % rozdíl), protože `_priprav_mesh_vnitrni` vracelo `true`, i když dávka postavená nebyla | (a) balení stránky **podle výšky sestupně** (`_predplnit_sloty`) → `pretek=false`, `slotu 573 → 596`, `bez_slotu 39 → 0`; (b) `return _mesh.is_built()` → při přetečení se kreslí **původní cesta** |

**⚠ Vědomé omezení, které je potřeba zapsat (ne zamlčet):** oprava řazení
znamená, že **statik nad hráčem ho může ÚPLNĚ ZAKRYT** (dům/strom) — v referenci
to řeší „roof fade" (`TransparentTest`, `View.cs:98`), který **nemáme**. Je to
věrnější stav než „postava na střeše", ale hráč se pod střechou ztratí.

**Integrační čísla (naměřeno dnes):** sada **1 178 kontrol / 0 selhání**
(44 case souborů, bylo 1 163/0), brány `run-all.py` **11 měřeno / 0 vad**,
self-testy **21 / 0 chyb**, `check-docs-refs` / `check-zadani` /
`roadmap-gen --check` **exit 0**, mutace `sort` **12/12**, `chunk_mesh` a
`chunk_renderer` **vše chyceno** (na zamrzlé revizi).

**⚠ Co tato session NEOPRAVILA (měřené, ne zamlčené):**
(`a`) **`nodraw` dlaždice (land id ≤ 2) zůstávají černé** — 4 dlaždice
(1440..1441, 1660..1661) land=2 → blok 2×2 černé (~88×88 px). Je to věrné UO
(`AllowedToDraw = graphic > 2`), ale **rozhodnutí, co s tím, patří do `docs/`**.
(`b`) **Roof fade neexistuje** (viz výše). (`c`) **Přestavba seznamu (50–250 ms)
je pořád zásek** — jen méně častý; další krok je stavět ji po částech (viz „Co
čeká na tebe"). (`d`) **Přesné pokrytí okna** je ověřené jen výpočtem
(`_list_okraj` + test), ne průchodem celé mapy.



## ✅ CO JE NOVÉHO (16. session) — ŘEMESLO JE CELÉ: sběr + výroba + žurnál

**Zadání uživatele (doslova):** „Pokračuj a témata čekající na mě rozhodni podle
svého úsudku." Vznikla z toho **dvě práce**: (1) rozhodnutí otevřených témat
→ `ROZHODNUTI-2026-10-08.md` (15 rozhodnutí, dvě z nich se hned provedla),
(2) **cíl 16. session** — `sim.harvest` + `sim.craft` + `ui.journal`.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **Sada: 1 163 kontrol / 0 selhání, 44 case souborů** | `godot --headless --path . --script res://tests/run_tests.gd` → `case souboru spusteno: 44 z 44`, `1163 kontrol, 0 selhani`, `exit 0` (bylo 1 055 / 41) |
| **`sim.harvest` (nový)** | `mine/chop/fish(m,x,y)` + `resource_left(x,y)`; **9 rud** (ReqSkill 0…99, žíly 49,6→1,4 %, fallback 0,5 na železo), **7 dřev**, rybolov (8 s, `Fishing ≥ 75` uspěje bez hodu); banky **8×8 / 4×3** s 10–34 rudou, 20–45 logy a respawnem 10–20 / 20–30 min; jeden sběr na systém (`busy` = 1,6 s) a **respawn měřen posunem času** (test: vyčerpat → `empty` → +20 min → znovu ruda) |
| **CELÁ SMYČKA NA REÁLNÉ MAPĚ (ruda → ingot → nůž)** | `_analyza/vlna16-sber-vyroba.gd`: hora nalezena na **(1501,1622)** (land id 240); hráč s **Mining 0** dobyl **624 rudy za 1 581 úseků** (7 cyklů přes 8 žil — jedna žíla má 10–34 rudy) a dostal se na **Mining 75,0**; **`smelt` 624 rudy → 624 ingotů** (1:1); **`craft(dagger)` uspěl na 44. pokus** (sance 0,094, `Blacksmithy` mezitím na 4,4 — neúspěch učí) a **3 ingoty se odečetly**; žurnál přitom drží **200 zpráv s JEDNÍM přebavením** a snímek je v `.cache/render/vlna16-zurnal.png` |
| **⚠ První úspěch na Mining 0 přišel po 63 úsecích** | sance je `CheckSkill(0,100)` = **0 %** při skillu 0, takže nováček těží jen z toho, že **neúspěch učí** (`gained:true`) — je to měřená odpověď na „jde vůbec začít?", ne dohad |
| **⚠ `docs/05 §5.7` mělo 2 chybná čísla** | dřevo: dokument „10–45 logů", reference **20–45** (`Lumberjacking.cs:46-47`); „10 logů za **sek**" → **za úder**; respawn 20–30 min v dokumentu chyběl. Opraveno v `docs/05 §5.7` |
| **`sim.craft` (nový)** | `recipes_for/craft/smelt/repair`; **dva nezávislé hody** (1. exceptionalita, 2. úspěch, `CraftItem.cs:1352-1359`), `floor` podle systému (Tailoring/Carpentry/BowFletching 0,5), exceptionalita `−0,60 → −0,45`; materiál se odečte **opravdu** (test: 3 ingoty → 0), u neúspěchu **celý** (u `use_all_res` polovinu), **existence materiálu se kontroluje PŘED hodem** (jinak by šlo vyrobit z ničeho) |
| **⚠ `skill_gain.check` nestačil: `SKILL_SPAN` byl napevno** | Recepty mají `max − min` **50,0 (509×), 25,0 (349×), jiný (194×)** a žíly 800/1000/1200 desetin. Oprava: `check(m, skill, difficulty, span := SKILL_SPAN)` (**aditivní** změna smlouvy, stará volání beze změny) a `sim.craft` počítá úspěch **vlastním vzorcem** — `check()` volá jen kvůli růstu. Bez toho by 543 z 1053 receptů mělo jinou šanci |
| **⚠ `quality Low (0)` z výroby NIKDY nevznikne** (naměřeno, ne odhad) | `quality` startuje na 1 a jediné přiřazení je `quality = 2` (`CraftItem.cs:1354-1356`); `PlayEndingEffect` větev pro 0 má, ale nikdo ji nenastaví. Test: **40 pokusů na 25,0 skillu → 0× Low** (a 0× Exceptional, protože `chance − 0,6 < 0`), na 60,0 → Exceptional padá. Cíl session přitom žádal „čtyři výsledky" — správně jsou **tři** |
| **⚠ 699 z 1053 receptů nemá `tile` výsledku** | Naměřeno nad `data/recipes.json` (354 má `result.tile`, **267** má `tile` u výsledku i materiálů). Brány to neměří — `check-content` i `tests/cases/recipes.gd` kontrolují jen odkazy, které `tile` **mají**. `craft` proto vrací `{ok:false, reason:"no_result"}` a `recipes_for` má `craftable: false` |
| **`ui.journal` (nový)** | `apply_event/apply_events/add/flush/clear/lines/plain_text/color_of`; **žádná herní logika** (`ui/` je tenký klient); zprávy jdou z `app/loop.gd:_deliver_events`; v běhu hry naměřeno **200 zpráv = 1 přebavení textu** (ne 200) |
| **⚠ Žurnál byl zelený, měřený — a NA OBRAZOVCE PRÁZDNÝ** | Testy procházely (1 163/0) a přesto nebyl na snímku ani řádek: `RichTextLabel` kreslí text **jen uvnitř svého rectu** a nový uzel má velikost `(0,0)`. Chytil to až **pohled na snímek** (`.cache/render/vlna16-zurnal.png`); opraveno (`custom_minimum_size`) + přidána kontrola i mutace. Stejná rodina jako „test prošel" vs. „test měřil" (viz `LESSONS` 16. session) |
| **⚠ „Nováčenec" u žíly: 23 rudy a pak 10–20 min nic** | Sonda: `left:22` po prvním úspěchu, bucket se vyčerpal po 23 rudách; sonda proto měří přes **8 různých žil** (bucket = 8×8). Je to vlastnost reference, ne vada — ale znamená, že cesta na 25,0 Mining (od ní jde tavit železo) není „pár kopnutí" |
| **Rozhodnutí hned provedená (R1, R2)** | **R1 `era.skill_gain: "pre-aos"`** — neúspěch učí (0,2 místo 0,0), `data/balance.json` + `app/config.gd` SCHEMA + `skill_gain._failure_weight`; **R2 barva pozadí `0,0,0`** z kódu (`RenderingServer.set_default_clear_color` v `app/main.gd`; `project.godot` zůstává nedotčený, protože je bootstrap) |
| **Registrace v `SimWorld.systems` (věc 68 jen částečně)** | `app/main.gd` registruje `harvest` i `craft` → `sim.interaction.use_on` na ně **přestal** vracet `not_available` (log běhu: `systemu v sim: ["movement","skill_gain","harvest","craft","time"]`) |
| **⚠ Co v produkci ZŮSTÁVÁ nedořešené** | (`a`) **světové statiky nejsou předměty**: `smelt(m, ore, forge)` bere vyheň jako **serial předmětu**, ale kovadlina/vyheň v mapě je statik a nikdo je podle serialu nedrží (věc 64) → v demu tavení u skutečné výhně nejde; sonda to **řekne**, nezamlčí. (`b`) V okolí Britainu (200 dlaždic) sonda **nenašla žádnou kovadlinu ani vyheň** (role z `data/items.json`) — buď tam nejsou, nebo mají jiný tvar, než role index čeká; **kdo půjde kolem kovárny, ať to změří** |
| **Brány a mutace** | `harvest` **9/9**, `craft` **10/10**, `journal` **7/7** chyceno (`mutace-tests.py --only harvest,craft,journal` → **27 z 27** včetně kontroly vstupu, smlouva vstupu OK). **Mutace našla dvě slepé kontroly v nových testech** (barvy: „say ≠ combat a craft ≠ system" neprošlo, když se `combat` spletl se systémovou; a chybějící kontrola velikosti žurnálu) → obojí opraveno, viz `LESSONS`. Brány `run-all.py` = **11 měřeno / 0 vad**, self-testy **21 / 0 chyb** |
| **Co se NEMĚNILO** | `render/*` (M9 zůstává), `sim/interaction.gd` (routing na `harvest`/`craft` tam byl od 10. session), `sim/sim_world.gd` (`SYSTEM_ORDER` už obě jména měl), `data/recipes.json`, `data/items.json`, `project.godot`, `app/main.tscn`, souboj a magie |


## ✅ CO JE NOVÉHO (15. session) — M9 „MODERNIZACE" JE HOTOVÁ (3 ze 3 granul)

**Zadání uživatele (doslova):** „Je čas pokračovat a provést M9. Pokud ti zbude
kontext, pusť se i do dalšího tématu." **M9 je hotové a měřené**; na další téma
kontext nezbyl (M9 si vylámala celou session — nejdražší část bylo **měření**,
které ukázalo, že naivní „mesh“ by byl pomalejší než dnešní stav).

| Co | Doklad (naměřeno dnes) |
|---|---|
| **VÝKON: 1 324 → 4 draw cally, 48,75 → 0,25 ms/frame** | Před: `_analyza/m9-vykon-pred.gd` (300 framů, vsync vypnutý): **1 324 draw callů, 4 655 objektů v rendereru, `TIME_PROCESS` 48,75 ms, 24 FPS**. Po: `_analyza/m9-vykon-po.gd` (3 s stoj + 6 s chůze, čeká se **nástěnnými hodinami**): **4 draw cally, frame ms median 0,25 (stoj) / 0,26 (chůze), p90 0,33/0,34, Engine FPS 3 724/2 593**. Kritérium `docs/01 §1.6` (60 FPS / ≤ 16 ms) je splněné s velkou rezervou |
| **STEJNÝ OBRAZ (podmínka M9) — pixel na pixel** | `_analyza/m9-parita.gd` + `_analyza/m9-parita.py`: tři scény (stojí / uprostřed kroku / po chůzi), stav je mezi snímky **zmrazený** (loop i controller vypnuté + zafixovaný frame animace) → **stejný hash** pro dávku i původní cestu: `6104e1d9…`, `4e6e3d60…`, `9a3479fe…` |
| **⚠ Měření, které rozhodlo architekturu (a zachránilo session)** | `_analyza/m9-cena-meshe.gd`: (1) **`ArrayMesh.add_surface_from_arrays` stojí 0,3 ms/surface** → 2 090 surface = 633 ms, takže „surface na každou stránku atlasu“ je **pomalejší** než dnešní stav; (2) **přesná parita má dno 1 219 draw callů** = počet souvislých „běhů“ se stejnou texturou (engine je už sám slučuje) — pod to se dá jít JEN jednou texturou; (3) 343 unikátních artů v pohledu = **1,3 Mpx**, vejde se do stránky 2048² |
| **Runtime atlas se skládá NA GPU** | První verze kopírovala sprity na CPU (`Image.blit_rect`) → `ImageTexture.get_image()` je kopie **16 MB na stránku** a LRU při 398 spritech thrashoval → **stavba 3 342 ms**. Dnes `SubViewport` + `Kreslic` (`UPDATE_ONCE`) → **stavba 53,8 ms** (po optimalizaci horké smyčky; před ní 100,3 ms), split **0,66 ms** |
| **⚠ První stavba je 2 008 ms — ale to je NAČTENÍ ATLASU, ne mesh** | `render.textures.stats()` po první stavbě: **`nacteni_stranek` 34** (PNG 2048² z disku). Stejnou cenu platí původní cesta ve svém prvním `_draw`; mesh k ní jen přidává prvních ~50 ms. **Není to regrese M9, ale je to nejdražší věc na startu hry** (viz „Co čeká na tebe“) |
| **`render/chunk_mesh.gd` (nový, M9)** | `build(objects, diagonal_hrace)`, `split(diagonal)`, `draw_before/draw_after`, `hranice()`, `missing_art_ids()`, `stats()`, `hold()/tick_hold()`, `invalidate()`, statické `slope_polygon`/`slope_uv`/**`je_svah`**. Geometrie svahu se tím **přestěhovala** z `app/world_view` (potřebuje ji i dávka) a `world_view` ji jen předává dál, takže testy i smlouva zůstávají na stejném místě |
| **`app/config.gd` (nový, M9)** | Typovaná konfigurace nad `data/balance.json`: `SCHEMA` (klíč + typ + default + rozsah/`values`), `value(key, default)`, `known_keys()`, `check()->Array chyb`, `all()`, `values()`, `source()`, `stats()`. `check()` na **reálných datech** hlásí **0 chyb**; na fixture hlásí chybějící klíč, špatný typ, mimo rozsah, mimo výčet i neznámý klíč |
| **⚠ `app.config` NEMÁ `get`, ale `value`** | `provides` v roadmapě říká `get(key, default)`, jenže `Object.get(StringName)` koliduje a GDScript to hlásí jako **chybu parseru** → soubor se vůbec nenačte. Stejná rodina jako `set_position` u `ui.hud` (věc N7). Odchylka je zapsaná v `docs/04 §4.2.1` |
| **⚠ JSON v Godotu vrací VŠECHNA čísla jako FLOAT** | `7000` z `data/balance.json` je `7000.0`, takže každý klíč typu `TYPE_INT` hlásil „špatný typ“ **a přeskočila se kontrola rozsahu**. `app.config` celá čísla normalizuje na `int` (naměřeno: 5 chyb u správných dat → 0) |
| **`app/metrics.gd` (nový, M9)** | `tick(frame_ms, drawn, textury, davka)`, `fps()`, `frame_ms()`, `drawn_objects()`, `report()`, `text()`, `set_window()`, `samples()`, `reset()` — FPS se **počítá z měřeného frame času** (ne z `Performance`, ten je klouzavý průměr a po dvousekundové stavbě hlásil „46,69 ms konstantně“) |
| **Zapojení v produkci (ne jen v testech)** | `app/main.gd`: `_load_data()` jde přes `app.config` (chyby se `push_warning`), `_process()` plní `app.metrics` a **jednou za sekundu** vypíše `[metrics] fps … frame_ms … kresleno … textur … kvadru … stavba …`. `app/world_view._draw()` kreslí **dávkou jako výchozí cestou** a původní cestu si drží jako fallback pro `pretek()` |
| **Testy granul** | `tests/cases/chunk_mesh.gd`, `config.gd`, `metrics.gd` (nové): geometrie (4 rohy, pořadí, 6 vrcholů kvadru), UV, díry (barva `HOLE_COLOR`), svahy (`z_corners` 4/1/2/3 → prohození stran se pozná), hranice hráče, `split`, přetečení stránky (obě větve), `hold`; config na reálných datech i na fixture; metrics (prázdno = NEMĚŘENO, okno, reset). Sada: **1 053 kontrol / 0 selhání** (bylo 998 s 9 chybami prostředí; po přesunu na plný přístup 998/0 → **+55 kontrol**) |
| **Mutační důkaz** | `tools/gates/mutace-tests.py`: **3 nové moduly** (`chunk_mesh` 10 vzorů, `config` 7, `metrics` 6) → `--only chunk_mesh,config,metrics` = **25 z 25 chyceno**, smlouva vstupu OK. **⚠ Cestou se to zhoršilo na 22/25** (optimalizace horké smyčky zabila 3 vzory) → vzory přepsané, znovu 25/25 (viz `LESSONS`) |
| **`tools/plan-status.py`: M9 chyběl v `MILNIKY`** | Granule milníku M9 se v přehledu „po milnících“ **vůbec nezobrazovaly** (a stav „0/3“ se z něj nedal přečíst). Dnes je `M9` v seznamu (v `tools/roadmap-gen.py` i `docs/07 §7.2` byl od začátku) |
| **Co se NEMĚNILO** | `sim.harvest`/`sim.craft`/`ui.journal` (cíl 16. session), `entity.equipment`, `data/*.json`, `project.godot`, `app/main.tscn`, `render/texture_cache.gd` (atlas se skládá **mimo** něj), `render/chunk_renderer.gd`, `render/sort.gd` |
| **⚠ Vědomá omezení M9 (zapsaná, ne zamlčená)** | (1) **První frame stojí ~2 s** — načtení 34 stránek atlasu z disku (platí i pro původní cestu; mesh přidává ~50 ms). (2) **Přestavba dávky stojí 53,8 ms každé 4 kroky** chůze (max frame 149,8 ms) — to je dnes největší zásek hry; další krok je stavět po částech nebo cachovat geometrii. (3) **Nový art je vidět o 2 frame později** (stránka se kreslí `UPDATE_ONCE`; `hold()` to řeší). (4) Mesh **neorezává** podle kamery (posílá 15 838 primitiv místo 9 310, ale draw callů má 4) |

## ✅ CO JE NOVÉHO (14. session) — VLNA POHYBU UZAVŘENA (V2, V4, V5)

**Zadání uživatele (doslova):** „Pokračuj v plánu" + volba cíle
**„Dokončit vlnu pohybu: V2, V4, V5"**. Měření je v
**[`REVIZE-POHYB-2026-10-07.md`](REVIZE-POHYB-2026-10-07.md)** (§2 příčiny, §5 co
zbývalo); tato session z něj provedla **B (V2)** a **C (V4, V5)** a **nechala
otevřené jen F/M9 a brány na chování v čase**.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **V4 — výška kroku se počítá z ROHŮ dlaždice, ne z `dz`** | `sim/world/walk.gd` přepsán podle `_src/servuo` `Movement.cs:170-171`, `:211-343`, `Map.cs:552-607`, `TileData.cs:112-125`: `stepTop = startTop + STEP_HEIGHT`, u landu `stepTop ≥ landLow` (nejnižší roh) a stojná výška `landCenter`; u statiku `stepTop ≥ itemTop` a `z + CalcHeight`; **dolů žádný limit**; povrch nejbližší postavě; `IsOk` (blokuje i delší `Surface`). **Důkaz na reálné mapě** (`_analyza/vlna14-svah-most.gd`, okno x1400..1620 / y1540..1760, **165 985** kroků, proti **celému** modelu reference): **před 14 965 blokovaných → po 0**; my povolíme 298 navíc a **všech 298 je schodová výjimka** (`_analyza/vlna14-svah-most-PRED.txt` vs `_analyza/vlna14-svah-most.txt`) |
| **V5 — statik se `Surface` rozhoduje i nad vodou (most)** | Voda se kontrolovala **před** statiky → molo bylo nedosažitelné. Naměřeno na molu u Britannie (`x1522..1525 y1470..1500`, paluba `z=10`, voda `z=−5`): kroků na molo povoleno **0 → 16** (z 24 zkoušených) a **BFS z prkna 1 → 4 000** dlaždic (limit sondy). Voda zůstává blokující (má `Impassable|Wet`, `canSwim` neumíme — reference ji blokuje také, `Movement.cs:211`) |
| **V4 — `apply_step` zapisuje `pos.z`** | Stojná výška z `can_step` se do `mob.pos.z` **nikdy nezapsala**, takže postava zůstala ve výšce prvního kroku (a na svahu se každý další krok měřil proti staré výšce). Dnes ji bere z `_pending`. Test: `tests/cases/movement.gd` 3b (stub s `z=7` → `pos == (6,5,7)`) |
| **V2 — posun a animace v JEDNÉ fázi** | `sim.movement.pending_step(serial)` (`{dir, run, start_ms, delay_ms, due_ms, z}`), `app/player_controller.update_step()/step_fraction()/player_pixel_offset()` (posun po **80ms framech**, jako `Mobile.cs:776-782`), `app.world_view.set_player_offset()`/`player_ground_position()`. **V běhu hry** (`_analyza/vlna14-pohyb.gd`): 3 záměry → **3× animace v témže framu**, 38 framů nakreslených **mezi dlaždicemi** (offset 0 → 4,4 → 8,8 → 13,2 → 17,6 px), **max skok obrazu 6,23 px** (starý klient: **31,11 px** = celá dlaždice), skok v okamžiku commitu **0,00 px** |
| **⚠ Vlastní vada nalezená sondou (a opravená)** | Offset se počítal **před** tickem simulace (`app.loop` je ve scéně až za controllerem) → v rámci commitu se posun přičetl k již posunuté dlaždici a obraz skočil **37,33 px** (hůř než před opravou). Řešení: `process_priority = 1` v `setup()` (a test to měří). Zapsáno v `LESSONS` |
| **Vizuální důkaz (pohledem)** | `_analyza/frames14/montaz-krok.png` (3× zoom, dva framy uvnitř jednoho kroku): postava na **dvou místech v téže dlaždici**, svět **stejný**. Měřeno `_analyza/vlna14-posun-snimku.py`: mezi framy uvnitř kroku se mění **0,09–0,11 %** obrazu (obalka změny se posouvá monotónně), commit kroku mění **59,5 %** (svět se posune o dlaždici) |
| **Brány** | testy **997 kontrol / 0 selhání**, `run-all.py` **11 měřeno / 0 vad**, self-testy **21 / 0 chyb**, `check-docs-refs` / `check-zadani` / `roadmap-gen --check` **exit 0**, replaye **beze změny hashů** |
| **Mutační důkaz** | `mutace-tests.py`: modul `walk` **přepsán** (2 mrtvé vzory nahrazeny, 8 nových na V4/V5), `movement` **+3** (V2/V4), `player_controller` **+4** (V2), `world_view` **+1** (V2) — výsledek v „integračních číslech" níž a v `_analyza/vlna14-mutace.txt` |
| **Co se NEMĚNILO** | `sim.harvest`/`sim.craft`/`ui.journal` (cíl 15. session), `entity.equipment`, M9 (`render.chunk_mesh`), `data/*.json`, `app/main.tscn`, `project.godot`, `render/sort.gd`, `render/chunk_renderer.gd` |
| **Nová měřená zjištění (neopravená, patří do rozhodnutí/plánu)** | **(1)** `TileFlag.Bridge` (0x400) mají i **schody** (`stone stairs` art 1823 = `0x2600`) → `CalcHeight` půlí výšku, takže stojná výška na schodu je `z + výška/2` (naše dřívější `z + výška` bylo vlastní pravidlo); **(2)** `GetAverageZ` u **osamocené** vyvýšené dlaždice vrací 0 (rohy `[3,0,0,0]` → průměr `0`), a přesto je průchozí — je to vlastnost reference, měřená testem 1c; **(3)** sondy `_analyza/vada-svah.py` a `vada-most*.gd` z 13. session měřily **opis** našeho pravidla v Pythonu (bez statiků) — srovnání s **celým** modelem reference dává jiná čísla (23 212 vs 0) |

## ✅ CO JE NOVÉHO (13. session) — OPRAVY A, D, E Z VLNY POHYBU

**Zadání uživatele (doslova):** „Souhlasím se všemi tvými návrhy… Implementuj
všechny své návrhy, souhlasím s nimi." Celé měření je v
**[`REVIZE-POHYB-2026-10-07.md`](REVIZE-POHYB-2026-10-07.md)** (§2 příčiny,
§7 co se provedlo); analýza směru projektu v
**[`REVIZE-SMER-2026-10-07.md`](REVIZE-SMER-2026-10-07.md)**.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **A) Kadence kroku byla 718/530 ms místo 400** | Dvě příčiny, dvě malé opravy: (1) `sim/sim_world.gd:tick` tickuje **systémy PŘED dispatchem příkazů** (jinak krok, který je v tomto ticku na řadě, vrací `busy`), (2) `app/loop.gd` dává vstupu **čas simulace** (`poll(..., sim.world_time())`), ne nástěnné hodiny vzorkované po framech. **Před: 7–9 kroků za 5 s (530–718 ms). Po: 12 kroků, median 404 ms, 11 z 12 prodlev u 400 ms, 0 dvojnásobných** (`_analyza/vada-kadence-po-A2.txt`) |
| **D) Směr z myši** | `app/input_map.direction_from_screen()` — obrazové prahy `|dy| ≤ 0,4|dx|` / `≥ 2,5|dx|` z ClassicUO `GameCursor.cs:670-754`; kurzor na hráči = žádný krok a **prodleva se nespálí**; test měří **16 větví tabulky + obě hranice**; mutace `input` **10/10** |
| **E) Zábradlí pod dlaždicemi mostu** | `render/sort.priority_z()` + `render/chunk_renderer._priorita()`: `z − 1` za `IsBackground`, `+ 1` za `Height != 0` (ClassicUO `PriorityZ`). **Vizuálně doloženo** `_analyza/snimky/mol-{pred,po}.png` (zábradlí pod prkny → nad prkny; rozdíl 1 736 px přesně na zábradlí) a **determinismus snímku ověřen hashem** (dva běhy = stejný soubor) |
| **Brány** | testy **969 kontrol / 0 selhání**; `run-all.py` **11 měřeno / 0 vad**; mutace `input`+`world_loop` **11/11**, `sort`+`chunk_renderer` **19/19**; `check-docs-refs`/`check-zadani`/`roadmap-gen --check` exit 0; replaye **beze změny hashů** |
| **Zadání (docs) přepsáno** | `docs/05 §5.1.4` — **zákaz plynulého pohybu ZRUŠEN** (naměřeno, že reference pohyb plynule vykresluje); krok zůstává diskrétní, plynulost je věc vykreslení. `docs/02 §2.4` (řazení podle `priority_z`), `docs/04 §4.2` (5 smluv) |
| **Co ZŮSTÁVÁ z vlny pohybu** | **B** interpolace + animace v jedné fázi (V2), **C** pravidla chůze (V4 svahy, V5 most), **F/M9** `render.chunk_mesh` (1 516 draw callů, 27 FPS při chůzi). Zdůvodnění a čísla: `REVIZE-POHYB` §5 |
| **Co se NEMĚNILO** | `data/*.json`, `sim/world/walk.gd` (V4/V5 zůstávají), `app/world_view.gd`, `render/anim_player.gd`, `project.godot`, `app/main.tscn` |

## ✅ CO JE NOVÉHO (12. session) — VLNA OPRAV: svahy, držení vstupu, stopa framů, sekání

**Zadání uživatele (doslova):** „Chybí výškové assety (kde je svah, tam není tile
a nejde jít), chůze držením klávesy (včetně pravého tlačítka myši), společně
s animací chůze se vedle postavy zobrazí všechny animační snímky, pohyb je teď
jen na zmáčknutí tlačítka (ne držení), takže můj dojem není jistý, ale hra se
asi seká a není plynulá." **Všechny čtyři věci jsou opravené a změřené.**

| Co | Doklad (naměřeno dnes) |
|---|---|
| **1) Svah: chyběl PŘEKLAD i TEXTURA** | Dvě nezávislé vady. **(a)** atlas klíčoval land art polem `texture` (TexID) místo **land tile id** → v atlase chybělo **512** artů, které v archivu jsou (přesně ty u pobřeží: 77–100); **(b)** i po opravě atlasu zůstal u svahu **šedý pás ~140 px** — UO kreslí rovnou plochu land artem a **svah texmapem nataženým přes čtyřrohy** (`LandView.cs:58-96`, `Batcher2D.cs:241`), což u nás neexistovalo. Dnes: `texmaps.py` (4 116 textur), `world.tiledata.texture()`, `render.chunk` dává `texmap` + `z_corners`, `app.world_view.is_slope()`/`slope_polygon()` kreslí svah. **Snímek `.cache/render/…` → `_analyza/snimky/svah-1519-1657.png`**: šedý pás je pryč, svah je texturovaný a voda je u něj |
| **2) Chůze držením (klávesa i pravé tlačítko)** | `app/input_map.poll()` se ptá na `is_action_pressed` a krok vydává po `step_delay_ms` (400/200 ms z `core/const.gd`); puštění prodlevu vynuluje. **Pravé tlačítko** = `walk_to`: směr z kurzoru, `run` podle `mouse_run()` = **190 px** od středu okna (ClassicUO `GameSceneInputHandler.cs:66`). Ověřeno **v běhu hry** (`_analyza/vlna7-drzeni.gd`): držení klávesy 2,5 s → **4 kroky**, krátký stisk 100 ms → **1 krok**, držené pravé tlačítko 2 s → **8 kroků a −4 stamina** (běh!) |
| **3) Stopa animačních framů** | `render.hue._obrazek()` bral **celý atlas** (stránka animace = všech 10 framů vedle sebe) a `hued()` vracel texturu CELÉ STRÁNKY → `_draw_player` ji kreslil na pozici postavy. Opraveno na **okno `region`**. Naměřeno: barvení 1 framu **35,7 ms → 4,1 ms** (8,7×) a kreslí se **jeden** frame (test v `tests/cases/render_hue.gd` sekce 18 + 2 mutace) |
| **4) Sekání: tři měřené příčiny** | **(a)** `render.sort.draw_order()` stavěl `[klic, i, objekt]` a řadil `sort_custom` (GDScript) → **85,7 ms**; dnes klic+pořadí v jednom `int64` a built-in `sort()` → **45,8 ms** celé přestavby; **(b)** přestavba seznamu se dělala při KAŽDÉM kroku → dnes až po `RECENTER_TILES = 4` dlaždicích (**39 → 10 záseků** za 40 kroků) a kreslí se jen to, co je na obrazovce (`CULL_MARGIN = 256 px`) — **46,6 → 34,5 ms** ve stoji (21 → 29 FPS); **(c)** barvení framu animace (viz 3). Chůze: **median 34,6 ms (29 FPS)**, p90 39,6 ms |
| **5) Chybějící art už není ticho (věc 61)** | `app.world_view._draw()` kreslí u chybějícího artu **magenta** diamant/čtverec, počítá `holes` a **jednou na art id** to hlásí (`push_warning`); land id ≤ 2 se nekreslí vůbec (ClassicUO `Land.Create: AllowedToDraw = graphic > 2`) a počítá se jako `nodraw` |
| **6) Atlas: dvě další vady měřením** | **(a)** item arty se vynechávaly podle **prázdného jména** v tiledata — naměřeno `_analyza/vlna6-statiky-bez-jmena.py`: **232 druhů / 14 199 statiků** na mapě má art, ale prázdné jméno (a statiků bez artu je **0**); **(b)** land v atlase = **4 244** (bylo 3 732), item 39 326, texmap 4 116 → manifest **49 705 spritů / 77 stranek, 0 chyb** (`atlas.py --verify`) |
| **7) Smlouvy a dokumentace** | `docs/03 §3.5.2`: blok „OPRAVA 2026-10-07" s tabulkou důkazů (art[0] = „UNUSED" vs `texture[168] = 0`; barva art[id] vs texmap **76:2**; váženo dlaždicemi **934 504 : 738**) + blok o svazích; `docs/03 §3.5.3` bod 2 přepsán (rozhoduje archiv, ne jméno); `docs/04 §4.2`: `world.tiledata.texture`, `render.textures.texmap`, `render.chunk` (`texmap`/`z_corners`), `app.input` (držení) |
| **8) Mutační důkaz** | `mutace-tests.py`: nové moduly **`input` (6), `player_controller` (2)** a rozšířené `chunk_renderer` (3), `world_view` (4), `sort` (10/10 po přepsání na nový kód) — **`--only input,player_controller,chunk_renderer,world_view` 13/13**, `--only sort` 10/10; `mutace-render-hue.py` **13/13** (2 nové na okno `region`); **21 self-testů** (přibyl `atlas.py` a `texmaps.py` — jejich self-testy existovaly, ale **nikdo je nespouštěl**) |
| **9) Integrační čísla** | testy **954 kontrol / 0 selhání** (exit 0), brány **11 měřeno / 0 NEMĚŘENO / 0 vad**, self-testy **21 / 0 chyb**, `check-docs-refs`/`check-zadani`/`roadmap-gen --check` **OK**, G9 replaye **beze změny hashů**, G10 po obnovení snímku `kuze_pixelu 9100` (paleta sady 1002) |
| **10) Co se NEMĚNILO** | `sim.harvest`/`sim.craft`/`ui.journal` (plán 13. session), `entity.equipment`, M9 (`render.chunk_mesh`), souboj, `data/*.json`, `project.godot` ani `app/main.tscn` (bootstrap) |
| **11) CI (push ověřen) — a jedna vada odhalená AŽ v CI** | `origin/main = HEAD = 6871be0`, `ahead 0`. **`#48` nad `de8ecfb` = `failure`** na kroku 11 („Mutační důkaz render.hue"): nová kontrola okna `AtlasTexture` byla **za `return`** v sekci C, takže **v CI se nikdy nespustila** (lokálně chytila 2 mutace, v CI prošla — viz `LESSONS` 12. session, past 11). Po přesunu kontroly **před** `return` (**`#49` nad `6871be0` = `success`**, 16/16 kroků, job 4:59 min) — včetně kroku 9 s novými moduly `input`/`player_controller` |

**Nálezy z 12. session, které zůstávají otevřené (měřené, neopravené):**

| # | Nález | Doklad |
|---|---|---|
| V1 | **Svah se kreslí BEZ osvětlení rohů** — ClassicUO počítá `CalculateNormal` a stínuje (`Land.cs:164-...`); my kreslíme rovnoměrnou barvu. Bez toho je svah „plošší" než v klientu | `app/world_view._draw_slope()` (komentář), čeká na `render.light` |
| V2 | **`texmaps.mul` má 4 116 z 16 384 indexů** a my je máme všechny; ale **`TexTerr.def` remap** (284 řádků) aplikujeme — měřeno v `texmaps.py` | `tools/uoextract/texmaps.py` |
| V3 | **Přestavba seznamu je 45,8 ms** (6 000 objektů) — pořád dost na to, aby to bylo cítit každé 4 kroky. Zbytky: `_z_grid` 6,7 ms, `draw_order` 12,5 ms, zbytek tvorba slovníků | `_analyza/vlna5-cena.gd` |
| V4 | **`demo-hue.gd` (řidič důkazu G10) má slabý heuristický test kůže** (`R-B > 20`): po opravě svahů mu „kůže" vyjde na **191 754 px** (hnědé texmapy terénu). **Brána G10 to neohrožuje** (měří přesnou shodu s paletou) — ale výpis řidiče už nic neříká | `.cache/analysis/demo-hue.gd`, G10 `kuze_pixelu 9100` |
| V5 | **`tiledata.mul`: první land záznam je posunutý o 4 B** (skupinová hlavička je až za ním): `land[0]` vychází `flags 0x4E55…, texture 21333, jméno "ED"`, správně je `UNUSED`. Naměřeno podle offsetů jmen (`UNUSED` na 10, `VOID!!!!!!` na 44, `NODRAW` na 74 → od záznamu 1 sedí 30 B i jméno na +10). **Týká se jen záznamu 0** (mapa ho nepoužívá: 0 dlaždic) | `_analyza/vlna2-offsety-jmen.py` |
| V6 | **Barva „void" (pozadí) je šedá 77,77,77** — v UO je pozadí tmavé; u NODRAW oblastí (727 dlaždic na mapě) je to vidět jako šedá plocha. Rozhodnutí patří uživateli (`project.godot` je bootstrap) | `_analyza/vlna8-seda-plocha.py` |




## ✅ CO JE NOVÉHO (11. session) — PRVNÍ UI, `sim.skill_gain` a odemknutí měření

**Cíl session (zadaný uživatelem, „režim Lead“):** rozšířit frontier měřením,
dodat společný předek řemesla i souboje a postavit první UI; **tři dráhy
paralelně** (3 subagenti), integrace a ověření = Lead.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **`sim/systems/skill_gain.gd`** (325 řádků, 45 kontrol) | `check(m, skill, difficulty) -> {success, gained, new_value, reason}`, `gain_stat(m, stat)`; **růst je nezávislý na úspěchu** (rozhodnutí uživatele; v UO `CheckSkill` je passive check PŘED hodem — `_src/servuo/.../CraftItem.cs:1400-1403`). Naměřeno: 100 pokusů s `difficulty=0` při value 0 → **zisků 100, neúspěchů 89**, value 0 → 100. Dále: GGS mez přesně 1 619 999 / 1 620 000 ms, strop 1000 i celkový 7000 (s arbitráží skillem se zámkem `down`), zámky, determinismus dvou běhů |
| **`ui/hud.gd` (60) + `ui/status_bar.gd` (59) — PRVNÍ UI V PROJEKTU** | `ui/` do dneška neexistoval a ve scéně nebyl žádný CanvasLayer. HUD drží okna a pozice (`register_window`/`window_of`/`position_of`/`set_position`/`layout()` (kopie)/`restore_layout`), status bar skládá text z **vstupního slovníku** (`update`/`text_for`/`apply_event`). **Zapojeno v `app/main.gd`** (`_setup_ui` + `_process` s guardem na změnu textu) |
| **Na obrazovce je vidět** | `.cache/render/run11/frame00000149.png` (150 framů): mapa Britainu, postava a **vlevo nahoře `hp=55/55, stam=10/10, mana=10/10, weight=0, gold=0`** — ověřeno **pohledem** |
| **Odemčené měření (3 nové case soubory)** | `tests/cases/chunk_renderer.gd` (**19**), `world_view.gd` (**19**), `recipes.gd` (**12**). Tím je **měřeně hotový** `render.chunk` (odemkl `render.names`, `render.effects`, `render.chunk_mesh`, `app.player_view`), `app.player_view` a **`data.recipes` je konečně měřené obsahem, ne zmínkou** (dřív falešná zelená — viz `LESSONS`) |
| **Rozhodnutí uživatele (11. session)** | **Éra AoS** — `era.loot` a `era.content` přepnuty z `pre-aos` na `aos` (`combat`/`ui` už AoS byly). **Stupnice kvality dle UO**: `quality` = **0 Low (zpackaný) / 1 Normal / 2 Exceptional** — naměřeno v ServUO `Items/Internal/ItemInterfaces.cs:67-72` + `CraftItem.cs:1356`; `docs/04 §4.2` mělo „0 normal, 1 exceptional" (posun o jedna + chybějící Low) → **opraveno** v `item.gd`, `docs/04` i `tests/cases/item.gd`. **Zvuk = vlastní trať** (vyjmut z M8 v `tools/roadmap-gen.py` + `docs/07`; `.forge/roadmap.json` upraven přesně podle generátoru a doložen `--check`). **Váha odložena** (zůstává jako omezení) |
| **Světlo: naměřeno, NIC k rozhodnutí** | Uživatel zadal „naměř" → měření ukázalo, že **rozhodnutí existuje od 2026-10-06** (den 0 = nejjasnější, noc 12, dungeon 26, rampy 4–6 a 22–24; ServUO/ModernUO `LightCycle.cs:13-16`, ClassicUO `IsometricLight.cs:69`) a **kód to tak má** (`sim/world/time.gd:19-31,86-101`) i testy (`tests/cases/time.gd`, `time_clock.gd`). **Zestárlý je jen ZÁZNAM** — `HANDOFF` (bod 2 v „Co čeká na tebe") a `ZADANI-DALSI-VYVOJ-2.md` F10 ho vedly jako otevřený. **Vada záznamu, ne kódu** |
| **Mutační důkaz nových kontrol** | **6 nových modulů** v `tools/gates/mutace-tests.py` (skill_gain, hud, status_bar, chunk_renderer, world_view, recipes) = **15 vzorů, 15/15 chyceno**, smlouvy vstupů OK. Harness má **14 modulů** (bylo 11) |
| **Integrační čísla** | sada **928 kontrol / 0 selhání** (bylo 806/0), **30 → 37 case souborů**; brány `run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0`; `plan-status.py`: **50 měřeně hotových** (bylo 45), **0 rozporů**; `roadmap-gen.py --check` **OK** |
| **⚠ Prostředí: sandbox blokuje zápis PODPROCESŮM** | V této session `python tools/roadmap-gen.py` spadl na `PermissionError` a `Set-Content` selhal i na `tests/…tmp`, přitom nástroj souborů psát uměl. Godot sám **běžel** (jen neškodný `user://logs` ERROR). Ověření (brány, mutace, snímek) proto potřebovalo **jedno eskalační volání**; v režimu `workspace-write` hlásí brány falešné vady (9 „selhání" v sadě = `render.textures` si vyrábí fixture v `.cache`, `sim.world_loop` ukládá do `user://`). Zapsáno v `LESSONS` |
| **Co se NEMĚNILO** | `entity.equipment`, `entity.notoriety`, vady ze snímků (věci 59–61), M9, `sim.pathfind` (voják), `docs/05` (jen se hlásí) a **`data/recipes.json` ani `data/items.json`** (mutace je čtou jako VSTUP) |

**Nálezy z 11. session, které patří jinam (neopravené, měřené):**

| # | Nález | Doklad |
|---|---|---|
| N1 | **`docs/06 §6.1` tvrdí 1150 receptů, data mají 1053** (id 0..1052) — 97 chybí, nebo je dokument zastaralý | `tests/cases/recipes.gd`, `data/recipes.json` |
| N2 | **`docs/04 §4.5` nesedí na data receptů**: smlouva má `skill:int`, `category`, `name`, `exceptional`, `tool`; data mají `skill` jako **název** (11 hodnot), `result` nese `kind/name/type/amount/tile`, `category`/`name`/`exceptional`/`tool` nejsou | tamtéž |
| N3 | 1 recept (id 525, Cooking) má `min_skill`/`max_skill` **null**; 3 z 11 názvů skillů **nejsou** v `data/skills.json` (BowFletching, Glassblowing, Masonry) | tamtéž |
| N4 | `data/skills.json` **nemá `GainFactor`** (UO per-skill konstanta, `SkillCheck.cs:300`) → v kódu je 1.0 | `sim/systems/skill_gain.gd` |
| N5 | `entity.stats` **nemá zámky statů** (`str_lock`/`dex_lock`/`int_lock`) → atrofie ubírá nejslabší stat > 10, ne podle zámku | `sim/systems/skill_gain.gd` |
| N6 | Událost **`stats_changed` v `docs/04 §4.4` nemá `stam_max`/`mana_max`** a **nikdo ji neposílá**; `ui.status_bar` proto bere `max_hp` jako alias a je napojen jen přes `update()` | `tests/cases/status_bar.gd`, `app/main.gd` |
| N7 | **`set_position` je zabudovaná metoda `Control`** (signatura `(Vector2, bool)`) — kdyby `ui.hud` přešel na `Control`, vznikne tichý parse error (rodina pasti `entity_registry.get()`, `docs/04 §4.2.1`) | `ui/hud.gd` |
| N8 | **`_ready()` se v běhu `--script` z `add_child()` NEZAVOLÁ** (kořen není „inside tree") → uzel zůstane neinicializovaný (8 falešných selhání v prvním běhu) | `tests/cases/world_view.gd` |
| N9 | Smlouva **nedefinuje `difficulty`** u `sim.skill_gain` (zvoleno `minSkill` v desetinách, `maxSkill = difficulty + 500`; 183/196 Blacksmithy receptů) — doplněno do `docs/04 §4.2` | `docs/04` |
| N10 | 661/1696 materiálů a 699/1053 výsledků nemá `tile`; **jmenné párování proti `items.json` nefunguje** (212/286 jmen chybí) | `tests/cases/recipes.gd` |
| N11 | **Mutace na SIGNATURU metody harness nechytí** (viz `LESSONS`: guard v case souborech + mutace jen na těla) | `tools/gates/mutace-tests.py` |



## ✅ CO JE NOVÉHO (10. session) — `sim.interaction` je HOTOVÝ a měřený

**Cíl session (zadaný 9. session):** „Dokončit `sim.interaction` (Úkol 4 ze
`ZADANI-DALSI-VYVOJ-2.md`)" — `use`, `use_on`, `context_menu`, `context_action`
podle `docs/05 §5.2.2` a párové tabulky §5.2.3, s **dynamickým routingem**
a s tím, že **neznámý předmět → hláška, nikdy ticho**. **Splněno** — včetně všech
čtyř bodů přijímacího kritéria (kovadlina, chybějící systém, neznámý předmět,
dveře přes `world.doors.toggle`).

| Co | Doklad (naměřeno dnes) |
|---|---|
| **`sim/systems/interaction.gd`** (461 řádků; deklarace `<= 150` → **3,1×**, věc 2, **3. největší překročení v projektu**) | `use`/`use_on`/`context_menu`/`context_action`. První tři vracejí **`Dictionary`** `{ok, reason, action}` — **odchylka od `->void`** ve smlouvě (zapsaná v `docs/04 §4.2.1` i v hlavičce souboru, i s důvodem: `void` nerozliší „nic se nestalo" od „není to hotové"). `context_menu` vrací `Array[Dictionary]` `{entry, text, custom}` |
| **Routing se rozhoduje z DAT, ne z prozy** | `data/items.json` (8 748 záznamů): `category` (container/weapon/armor/shield/clothing/tool/light/misc/material) + `role` (36 hodnot: pickaxe, smith hammer, anvil, forge, iron ore, …). **`anvil` a `forge` mají `category == "tool"`, ale jsou to CÍLE** (naměřeno: 18 záznamů `tool` = 16 nástrojů + tyto 2) → konstanta `TARGET_ROLES`; proto `use` na kovadlinu nic neudělá **a řekne to** |
| **Dva id prostory (měřeno, ne odhad)** | `entity.item.tile` je **ART ID**, data mají **TILEDATA ID**: názvy v `assets/uo/tiles.json` sedí na indexu `tile` i u **4 744** záznamů s `tile >= 0x4000` (`400/400` shoda), při art konvenci `0/400` shoda. Modul proto hledá **nejdřív** `tile - 0x4000` |
| **`use` — 9 větví §5.2.2** | dveře (`world.doors.toggle`, konvence z 8. session: `art ± 1`), kontejner (`container_contents` + `gump_open`), vendor (AI stav `vendor`, `docs/05 §5.3`), nástroj (`target_request` s kursorem), svitek (→ `sim.magic`), výbava (→ `entity.equipment`), světlo, mobil (→ `sim.combat`), **`unknown` → hláška `You see nothing special.`** |
| **Dynamický routing** | `_call` hledá systém v `SimWorld.systems`; když tam není (nebo nemá metodu) → `{ok:false, reason:"not_available"}` **a hláška** — nikdy ticho. **`callv` se špatným počtem argumentů vrací `null`** → hlásí se `reason:"bad_system"`, ne falešný úspěch (past je v `LESSONS`) |
| **§5.2.3 (párová tabulka z `Tilehelp.enu`)** | Dokument má **36 řádků, pokryto je 10 = 11 párů** (řádek 26 má dvě podoby materiálu: `logs` i `boards`) + 4 páry z §5.2.2 (`pickaxe`/`hatchet`/`axe`/`fishing pole` → dlaždice). Zbytek potřebuje data, která v `data/items.json` **nejsou** (ryba, vlna, nit, obvaz, klíč, lockpick, pochodeň, svitek do knihy, reagent, runa, moongate, srp, vědro, měch, sextant, hodiny) — chybějící řádek odpoví hláškou. **Test to měří proti dokumentu** (počet řádků `docs/05` + přesná množina párů), takže **nový řádek v dokumentu test shodí**, dokud se pokrytí nedoplní |
| **Kontextové menu** | `0x0078` (Open Backpack) a `0x0193` (Paperdoll) = čísla, která **klient zná** (ServUO `Server/ContextMenus/ContextMenu.cs:178-256` přes `research/01 §2.4`); ostatní `>= 0x64` = vlastní (`custom: true`), protože clilocy jsou UNVERIFIED (`docs/11` O7). `0x0078` otevře batoh hráče (jinak `not_available`), `0x0193` pošle `gump_open{paperdoll}`, vlastní číslo je dnes `not_available`, neznámé `unknown_entry` — **vždy s hláškou** |
| **Test granul** | `tests/cases/interaction.gd` (518 řádků, **166 nových kontrol**): všech 9 větví, **každý pár tabulky** (bez systému → `not_available`; se stubem → **zavolaná metoda i argumenty**), pokrytí §5.2.3 proti dokumentu, kontextové menu a akce, sloučení hromad. Sada: **806 kontrol / 0 selhání, `exit 0`**, **31 case souborů** (bylo 640/0 a 30) |
| **Mutační důkaz** | Nový modul `interaction` = **13 vzorů**, každý v souboru **1×** (ověřeno před během) → `python tools/gates/mutace-tests.py --only interaction` = **13 z 13 chyceno**, smlouva vstupu OK. Celkem `mutace-tests` **94 vzorů** (bylo 81); lokálně `120/120` → **133/133** |
| **Brány a self-testy** | `run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0`; self-testy **19 / 0 chyb**, `exit 0`; `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` `exit 0`. **G9 replay zelený beze změny hashů** (`tic_200` = `281e7802…`, `tic_1000` = `9e6218ab…`) — modul v replayi zaregistrovaný není, takže se stav nezměnil (acceptance `replay` je tím splněná měřením, ne tvrzením) |
| **G4 po změně** | `granuli_s_hotovym_souborem 54` (bylo 53), `provides_jmen 112`, `volanych_z_produkce 67`, `jen_z_testu 38`, `neintegrovano 7`; **všechna čtyři jména `sim.interaction` jsou „volá ho jen tests/ — čeká na integraci"** (acceptance `wiring` nežádá; věc 68) |
| **Plán** | `plan-status.py`: **47 měřeně hotových** se započteným testem (po commitu **48**), **0 rozporů**. **⚠ +2 z toho jsou artefakty metriky, ne práce:** `assets.gump` a `data.recipes` přeskočily na „hotové" jen proto, že test používá slova `gump`/`recipes_for` (naměřeno diffem `--json`; věc 70) |
| **Smlouvy (`docs/04`)** | `§4.2` má u `sim.interaction` **změřené signatury** (Dictionary místo `->void`); `§4.2.1` má nový blok „`sim.interaction` je HOTOVÝ" (konstruktor, routing z dat, oba id prostory, `TARGET_ROLES`, pokrytí §5.2.3, kontextová čísla a **dvě díry ve smlouvě**: §4.4 nemá událost „art existujícího předmětu se změnil" ani gump `paperdoll`). **Nic se nepřepsalo** — jen doplnilo |
| **Co se NEMĚNILO** | `entity.equipment`/`entity.notoriety`, voják pro `sim.pathfind`, vady ze snímků (věci 59–61), M9, **`app/main.gd` (systém se NEregistruje — integrační session, věc 68)**, `data/items.json`, `data/skills.json`, `docs/05`, `.forge/roadmap.json` (`done` se nepřepisuje, stav se měří) |
| **⚠ Co je potřeba vědět** | **V demu není vidět nic nového** — do hry se `sim.interaction` nezapojil (nikdo ho neregistruje a předměty nemají registr), takže je to hotová a měřená mechanika, ne hratelná (stejná situace jako `entity.item`/`container`, věc 64) |

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

**⚠ Předměty, kontejnery ANI interakce na obrazovce nejsou** — `entity.item`
i `entity.container` nikdo nekreslí ani nevolá z UI (drag & drop, batoh ani drop
neexistují) a `sim.interaction` (10. session) **není zaregistrovaný v žádné hře**
(`app/main.gd` ho nepřidává, `SimWorld.systems` ho nezná), takže **dopad na obraz
je dnes nulový** a nic se nesnímkovalo. Je to hotová trojice bez vojáka (věc 64 +
věc 68); prvním volajícím `item`/`container` je od 10. session **`sim.interaction`**,
ale zatím **jen z testů** (G4 to hlásí výslovně).

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

## ✅ CO JE NOVÉHO (9. session) — `entity.item` + `entity.container` jsou HOTOVÉ a měřené

**Cíl session (zadaný 8. session):** „Dokončit `entity.item` a `entity.container`“
(první dvě granule Úkolu 6 ze `ZADANI-DALSI-VYVOJ-2.md`). **Splněno** — včetně
toho, co kritérium žádalo: invariant „právě jeden rodič“, stacky a váha, smlouvy
v `docs/04` sedí na kód a brány/testy/self-testy jsou zelené.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **`sim/entity/item.gd`** (66 řádků, deklarace `<= 60` → **1,1×**, viz věc 2) | Tvar **celý podle `docs/04 §4.5`**: `serial, tile, hue, amount, parent, layer, pos, flags, durability, max_durability, quality, props`. Navíc `is_on_ground()` (`parent == 0`), `pile_weight(unit_weight)` (= jednotková váha × `amount`; vzor ServUO `Server/Item.cs:3854` `PileWeight = ceil(Weight * Amount)`) a `same_pile(other)` (stejný `tile` + `hue`). **`tile` je ART ID** (0x4000–0xFFFF, `docs/03` §3.4 „item id = art id“) |
| **`sim/entity/container.gd`** (192 řádků, deklarace `<= 60` → **3,2×**, viz věc 2) | `can_add`/`add`/`remove`/`weight_of`/`contents` podle smlouvy + `has_weights()`. **Jedna instance = všechny kontejnery světa** (`c` = serial), protože jinak **invariant „právě jeden rodič“ nejde vynutit** (viz `LESSONS`). Důvody odmítnutí: `no_container`, `no_item`, `no_serial`, `amount`, `stack`, `already_here`, `full`, `weight`. `remove` vrací, **kolik opravdu odstranil** (dřív to smlouva neříkala) |
| **Limity (docs/05 §5.4)** | 125 předmětů → `reason:"full"`; 400 stones → `reason:"weight"`; hromada 60 000 → `reason:"stack"`. Váha = `tiledata.weight(tile) × amount`. **Když se limit překročí, stav se NEZMĚNÍ** (test to měří u všech tří). Reference: ServUO `Server/Items/Container.cs:1672-1673` (`GlobalMaxItems = 125`, `GlobalMaxWeight = 400`), `CheckHold` `:230-268` |
| **Invariant „právě jeden rodič“** | Vzor ServUO `Server/Item.cs:3971` (`AddItem` nejdřív volá `RemoveItem` na předchozím rodiči, `:3999-4006`). Test: předmět přesunutý z kontejneru `101` do `202` je **jen v `202`** (`contents(101)` je prázdné); druhý `add` téhož předmětu nic nezmění |
| **Slučování hromad (měřené pravidlo, ne dohad)** | Sloučí se stejný `tile` + `hue` **a** flag `Generic` v tiledata = stackable (ClassicUO `TileDataLoader.cs:281`, `TileFlag.Generic = 0x00000800`). **Naměřeno nad `assets/uo/tiles.json`**: zlato (`0x4EED`), obvaz, log, ingot a reagencie flag **mají**, dagger/longsword/backpack **ne** (898 z 65 536 předmětů). Slučuje se do `MAX_STACK`, zbytek zůstane předmětu (test: 59 990 + 30 → 60 000 + 20) |
| **⚠ Odchylky od ServUO (vědomé, zapsané v kódu i v `docs/04 §4.2.1`)** | (a) plná hromada **není** cíl sloučení (ServUO `WillStack` kapacitu nezkoumá a předmět pak přidá jako nový, čímž **překročí `MaxItems`** — tuhle vadu nekopírujeme); (b) plně sloučený předmět ServUO **maže**, my objekt volajícího smazat nemůžeme → skončí prázdný a bez rodiče; (c) váha se u sloučení nekontroluje (`Container.cs:1790` dělá totéž) |
| **Testy granul** | `tests/cases/item.gd` (84 řádků) a `tests/cases/container.gd` (272 řádků); oba berou měřenou cestu **z argumentu** (`-- --item-script=`, `-- --container-script=`) a mají sekci nad **reálnými daty** (bez `assets/uo` hlásí NEMĚŘENO, ne selhání). Sada: **640 kontrol, 0 selhání, `exit 0`**, **30 case souborů** (bylo 584/0 a 28) |
| **Mutační důkaz** | Dva nové moduly: `item` (**5**) a `container` (**15**) → `python tools/gates/mutace-tests.py --only item,container` = **20 z 20 chyceno**, smlouva vstupu OK (neexistující cesta test shodí). Celkem `mutace-tests` **81 vzorů** (bylo 61). Jedna mutace se napoprvé **neprovedla** (`stackable flag` — pattern opsaný z komentáře, ne z kódu) a jedna byla **neunikátní** (`return _tiledata != null` je v souboru 2×) → obojí opraveno, viz `LESSONS` |
| **Smlouvy (`docs/04`) — v rozsahu cíle** | `§4.2`: obě řádky mají **změřený tvar** (tři id prostor, jedna instance, důvody, návrat `remove`, `has_weights`); `§4.2.1`: nový blok „jsou HOTOVÉ“ se všemi čísly a odchylkami; `§4.5`: „KÓD JE“, `tile` = ART ID a kontejner není pole v `Item`. **Nic se nepřepsalo** — jen doplnilo |
| **Co se NEMĚNILO** | `sim.interaction` (Úkol 4) se nedělal, `entity.equipment`/`entity.notoriety` taky ne, vady ze snímků (věci 59–61) a M9 taky ne; `data/items.json`, `data/recipes.json` ani `core/const.gd` se nedotkly; **nikdo `item`/`container` nevolá z produkce** (věc 64) |
| **Brány a self-testy** | `run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0`; self-testy **19 / 0 chyb**, `exit 0`; `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` `exit 0`; G4 po změně: `granuli_s_hotovym_souborem 53` (bylo 51), `volanych_z_produkce 63` (bylo 59), `jen_z_testu 37` |
| **Plán** | `plan-status.py`: **45 měřeně hotových** po commitu (bylo 43), **0 rozporů**, mrtvé deklarace v M2 se zmenšily o `entity.item` a `entity.container`; `size_lines` u obou nových granul **překročeno** (66/60 a 192/60) a je to **věc 2** (rozhodnutí uživatele: měřit, ne přepisovat) |
| **CI** | **`#40` nad `17ebc04` = `success`**, 17 kroků, job 2:03 min; prošel krok 7 (testy **bez `assets/uo`**, lokálně **582/0**) i krok 9 s **81 mutacemi** — viz „BLOKÁTORY“ |

## ✅ CO JE NOVÉHO (8. session) — konvence dveří je ZMĚŘENÁ a OPRAVENÁ

**Cíl session (zadaný 7. session, věc 62):** „Rozhodnout a opravit konvenci dveří
ve `world.doors`." **Splněno — ale ne tak, jak znělo přijímací kritérium:** to
žádalo `is_open(tile)` = „**sudý** člen dvojice", což je **naměřená vada zadání**
(platí jen pro blok 1717..1732, ne pro všech 37 kategorií). Správné pravidlo je
**`art + 1`**, bez ohledu na paritu.

| Co | Doklad (naměřeno dnes) |
|---|---|
| **Konvence: `doors.txt` = ZAVŘENÝ art, `art + 1` = OTEVŘENÝ** | Nad všemi **230 arty** ze `data/doors.json`: `art + 1` **existuje 230/230** a **ani jednou** není sám v `doors.txt` (**0/230** ⇒ otevřený art není „jiný směr", který by šel postavit); `Impassable` má **230/230** artů z `doors.txt` a **71/230** jejich `+1` (opačný směr by potřeboval 230 průchozích „zavřených"); `tiledata` jmenuje **8 párů** přímo „wooden door closed" / „wooden door opened" a **ani jeden obráceně**. Skripty `_analyza/dvere-konvence.py`, `_analyza/dvere-jmena.py` |
| **Reference (ne dohad)** | `base(closedID, openedID)` s **`openedID = closedID + 1`**: ServUO `Scripts/Items/Functional/Doors.cs:138` (`0x675 + 2*facing` → `0x676 + 2*facing`), ModernUO `Items/Construction/Doors/HouseDoors.cs:48–49`; `doors.txt` dodává právě `closedID` (dveře se do světa staví zavřené) |
| **⚠ PARITA ANI `layer` NEJSOU KRITÉRIUM** | Kusů je **120 lichých a 110 sudých** a **16 kategorií má všechny kusy sudé** (7, 9–14, 19, 23, 27, 28, 30, 32–34, 36) — parita sleduje `base` (`MetalDoor` 0x675 lichý, `IronGate` 0x824 sudý). `layer` se liší u **39 z 230** párů (u bloku 1717..1732 sedí, jinde ne). Kdo stav pozná z parity nebo z vrstvy, rozhodne u těch kategorií **opačně** |
| **Starý omyl (2026-10-02) je pojmenovaný, ne smazaný** | Hlavička `doors.gd` tvrdila „kusy 1–4 zavřené, 5–8 tytéž otevřené" a `toggle` pároval `index` s `index + 4`; byl to **jiný směr téhož stavu** (`1721 → 1725`), ne otevřeno. Zůstává v hlavičce jako záznam i s následkem (Úkol 4 by otvíral na špatnou stranu) |
| **Oprava modulu** | `sim/world/doors.gd` (**142 řádků**, deklarace `<= 60` — překročeno, viz věc 2): `is_door` platí pro **oba** členy dvojice, `is_open(t) = not has(t) and has(t-1)`, `toggle(t) = t + 1` (zavřený) / `t - 1` (otevřený), `category`/`orientation` berou zavřené dvojče, `orientation` je **index v `doors.txt` (0..7)**, ne `index % 4`; `open_tile(cat, i) = tiles[i] + 1` |
| **Test granule (přepsaný)** | `tests/cases/doors.gd` (**102 řádků**, **25 kontrol**): literály pro kat. 4 (`1721` zavřený, `1722` otevřený, `toggle` oběma směry, `1733` není dveře, `orientation(1725) == 4`), **sudá kategorie 7** (`2084` zavřený / `2085` otevřený — tím padá „parita"), a **smyčka přes všech 230 artů** (`is_open`, `toggle`, `is_door`, `category`, `orientation`, „partner není v datech"; počty: 230 projitých, 110 sudých zavřených). Cesta k souboru je **vstup** (`-- --doors-script=…`) |
| **`tests/cases/walk.gd` zůstal zelený** | Sekce 8c hledala dvojici přes `is_open(piece) != is_open(piece1)` (stará konvence) → přepsáno na `not is_open(piece) and is_open(piece + 1)`; `walk` je na konvenci nezávislý (ptá se `is_open`) |
| **Mutační důkaz (nový modul `doors`)** | `python tools/gates/mutace-tests.py --only doors` → **8 z 8 chyceno**, smlouva vstupu OK: (1) `toggle` = starý omyl `index + 4`, (2) `otevřeno = sudý art`, (3) `is_open` hledá `+1`, (4) vratná cesta vrací `+1`, (5) `is_door` jen pro zavřený art, (6) `category`/`orientation` otevřeného artu nenajde, (7) `orientation` zpět na `% 4`, (8) `open_tile` zapomene `+1` |
| **Testy a brány** | s assety **584 kontrol / 0 selhání** (bylo 574; +10), **bez `assets/uo` 529 / 0** (bylo 519; +10 — doors test měří `data/doors.json`, ta v gitu jsou), 28/28 case souborů, `exit 0`; brány **11 měřeno / 0 NEMĚŘENO / 0 vad**; self-testy **19 / 0**; `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` **exit 0** |
| **Dokumentace doplněna (ne přepsána)** | `docs/03 §3.6`: řádek `doors.txt` opraven na měřený stav + datovaná oprava pod příkladem (i s tím, že parita kritérium není); `docs/04 §4.2`: smlouva `world.doors` má `is_open`, `orientation` a význam `art + 1`; `docs/05 §5.2.2`: „přepni art na `art + 1` a zpět"; hlavička `sim/world/walk.gd` už neříká „konvence je otevřená věc" |
| **CI** | `node _analyza/ci-beh-stav.mjs`: **#38 nad `98542a3` = `success`, 17 kroků, job 1:33 min** (i krok 9 s **61 mutacemi**); run #37 (7. session) taky `success` |
| **Co se NEMĚNILO** | `sim/interaction` (Úkol 4) se nedělal, vady ze snímků (věci 59–61) taky ne; `data/doors.json` ani `tools/uoextract/textdata.py` se nedotkly; `tools/roadmap-gen.py` se neměnil (`provides` zůstaly stejné, `.forge/roadmap.json` je aktuální) |

**Dopad na obrazovku je dnes nulový** (v okolí startu není ani jeden statik
dveří, 0 z 6 750 kroků) — obraz se proto neměnil a nic se nesnímkovalo.
**Dopad na Úkol 4 je přímý:** `sim.interaction` teď může `toggle` použít
a dostane otevřený art, ne jiný směr.

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

## ✅ CO JE NOVÉHO (7. session) — testy už nemlčí a tři harnessy jsou v CI

**Cíl session (rozhodnutí uživatele 2026-10-07):** „Ano zavřít [slepé místo
v `tests/run_tests.gd`]. Přidej zbývající tři harnessy podle návrhu."

| Co | Doklad (naměřeno dnes) |
|---|---|
| **⚠ SLEPÉ MÍSTO V HARNESSU BYLO VĚTŠÍ, NEŽ SE MYSLILO** | `load()` na case soubor s **parse errorem** vrací **nenulový `GDScript`**, který ale nejde instanciovat; `script.new()` vyhodí runtime error, `_init_case` se **přeruší** a vrátí `null` — a smyčka to brala jako „už ohlášeno" a soubor **tiše přeskočila**. Naměřeno: `503 kontrol, 0 selhání, exit 0` (správně 537). **Oprava:** `can_instantiate()` **před** `new()`, `script_at()` v `tests/lib.gd` vrací `null` i pro neinstanciovatelný skript, a case, který nedodá ani jednu kontrolu, je `FAIL`. |
| **Tři mutace to dokazují (a jsou to tři RŮZNÉ cesty)** | (1) parse error v **case souboru** → `FAIL case soubor … nelze nacist (parse error?)`, `27 z 28`, `504/1`, `exit 1`; (2) parse error v **měřené granuli** → tři case soubory `FAIL`, `453/3`, `exit 1`; (3) parse error v granuli, kterou case **`preloaduje`** → `26 z 28`, `480/3`, `exit 1`. |
| **Fixture pro `render.hue`** | `tests/fixtures/hues/` (generátor + `hues.json`, 124 KB, 1003 sad: index 1001 = sada 1002 = `HUE_SKIN`); test `render_hue.gd` má novou **sekci D) FIXTURE** (15 kontrol) a měří ji **VŽDY** — i v CI. Očekávané barvy jsou v testu **zapsané jako literály** (ne čtené z téhož souboru — jinak by kontrola byla kruhová; první verze taková byla a sabotáž ji odhalila). |
| **Fixture pro `render.anim`** | `tests/fixtures/anim/` (generátor + `anim-sheets.json` 3 177 B + 2 PNG, 6 spritů, framy 2/3/2/4/2 — záměrně jiné než reálných 10); test má **sekci FIXTURE** (22 kontrol) volanou **před** kontrolou `assets/uo`, takže běží vždy. |
| **Fixture se hlídá** | nový krok CI „Fixture sedí na generátor" pouští `make_fixture.py --check` pro `world`, `hues` i `anim` (drift = ruční editace místo generátoru by tiše změnil, co se měří). |
| **⚠ `mutace-anim.py` měl falešné zelené** | Sonda na reálných datech se **nikdy nepouštěla na originále**: bez instalace UO buď spadla (`FileNotFoundError`), nebo (instalace existuje, data prázdná) vrátila **45 chyb pro každou mutaci i pro originál** → harness hlásil **8/8 chyceno, 0 chyb** a nic neměřil. **Oprava:** baseline na originále (0 chyb = sonda se počítá), `--install`/`UO_INSTALL`, a když sonda neměří, **řekne to** (`realna sonda: NEMERENA`). |
| **Tři harnessy v CI** | `mutace-render-hue.py`, `mutace-render-anim.py`, `mutace-anim.py` mají v `ci.yml` vlastní kroky (první dva s `env: GODOT`). **Ověřeno v CI stavu** (bez `assets/uo`, bez instalace UO): `12/12`, `11/11`, `8/8 (JEN self-test – realna sonda NEMERENA)`, všechny `exit 0`. |
| **Testy a brány** | s assety **574 kontrol / 0 selhání**; **bez assetů 519 / 0** (dřív 483 a harness hlásil `13 kontrol` míň) — fixture tedy v CI měří. `run_tests.gd` navíc vypisuje `case souboru spusteno: N z M`. |

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

**✅ CÍL 14. SESSION — SPLNĚN (ať ho další session přepíše):**
> **Dokončit vlnu pohybu z `REVIZE-POHYB-2026-10-07.md` — V2, V4, V5** (uživatel
> zvolil z nabídky „Dokončit vlnu pohybu: V2, V4, V5"). **Všechny tři jsou
> opravené a měřené** (doklady v „CO JE NOVÉHO (14. session)"): svah a most
> (0 blokovaných proti celému modelu reference, molo 0 → 16 kroků a BFS 1 → 4 000),
> posun s animací v jedné fázi (max skok obrazu 6,23 px místo 31,11 px, 3/3 záměry
> animované v témže framu), `pos.z` se zapisuje. **Z vlny pohybu tak zůstává jen
> F/M9** (`render.chunk_mesh`, 1 516 draw callů) a „brány na chování v čase".

**⚠ CÍL TÉTO (12.) SESSION — SPLNĚN, ať ho další session přepíše:**
> **Vlna oprav ze snímků od uživatele (2026-10-07):** (1) chybějící výškové
> assety na svazích, (2) chůze držením klávesy i pravého tlačítka myši,
> (3) „stopa" všech animačních framů vedle postavy, (4) sekání. **Všechny čtyři
> splněné a změřené** — doklady v „CO JE NOVÉHO (12. session)". Uživatel zároveň
> svým zadáním **posunul plánovaný cíl** (`sim.harvest` + `sim.craft` +
> `ui.journal`) na **13. session**.

**✅ CÍL 15. SESSION — SPLNĚN (ať ho další session přepíše): M9 „MODERNIZACE“,
3 ze 3 granul.** Uživatel 2026-10-07 večer M9 předsunul („já mezitím zavolám novou
session pro M9“) a 15. session ho provedla: **`app.config` + `app.metrics` +
`render.chunk_mesh`**, s paritním testem, snímkem a měřením PŘED/PO:
**1 324 → 4 draw cally, 48,75 → 0,25 ms/frame, 24 → ~3 700 FPS** (doklady
v „CO JE NOVÉHO (15. session)“). Přijímací kritérium splněno celé: 3 nové case
soubory, 3 nové modula v `mutace-tests.py` (**25/25**), sada **1 055/0**,
`run-all` **11/0/0**, self-testy **21/0**, `check-docs-refs`/`check-zadani`/
`roadmap-gen --check` **exit 0**, `plan-status` **56 měřeně hotových, 0 rozporů**
(M9 **3/0/0**), smlouvy v `docs/04 §4.2`/`§4.2.1`.
**Co zůstalo jako vědomé omezení** (viz „Co čeká na tebe“ bod 4): první frame ~2 s
(načtení 34 stránek atlasu — platí i pro původní cestu), přestavba dávky 53,8 ms
každé 4 kroky chůze, nový art vidět o 2 frame později, mesh neorezává podle kamery.

**Původní zadání M9 (15. session) — text se NEMAŽE, historie se jen doplňuje:**

> **Co je M9:** poslední milník plánu (dřív „až po M8“) — `docs/07 §7.2` (řádek
> M9), vlna `docs/07 §7.3` **W11**, zadání granulí `tools/roadmap-gen.py:556-570`,
> generovaný plán `.forge/roadmap.json`. **Je to totéž jako „Úkol 8“ v
> `ZADANI-DALSI-VYVOJ-2.md §3`** a jako bod **F** v `REVIZE-POHYB §5`.
> **Tři granule (před session: 0 ze 3):**
>   1. **`app.config`** (`app/config.gd`, `<= 60`, `any`, deps `data.balance`):
>      `provides` = `get(key, default) -> Variant`, `known_keys() -> Array`,
>      `check() -> Array chyb`. Jedna tabulka **klíč + typ + default + rozsah**;
>      **neznámý klíč se HLÁSÍ** (dnes se `data/balance.json` čte ad hoc na více
>      místech). Vzor: ModernUO `Projects/Server/Configuration/ServerConfiguration.cs:43`.
>   2. **`app.metrics`** (`app/metrics.gd`, `<= 60`, `any`, deps `app.loop`,
>      `app.player_view`): `fps()`, `frame_ms()`, `drawn_objects()`,
>      `report() -> Dictionary`; sbírá, co už existuje (`render.textures.stats()`,
>      `app/world_view.drawn`). **Tohle je nástroj, kterým se pak měří M9.**
>   3. **`render.chunk_mesh`** (`render/chunk_mesh.gd`, `<= 150`, **`strong`**,
>      deps `render.chunk`, `render.textures` — obě hotové): místo ~1 500 draw
>      callů na dlaždici **jedna dávka na blok** (land + statiky), rebuild při
>      invalidaci. Vzor: ClassicUO `src/ClassicUO.Client/Game/Map/ChunkMesh.cs:121`.
> **Pravidlo M9 (docs/07 §7.2): modernizace NESMÍ ubrat žádné měření** — každá
> změna má stejnou nebo silnější bránu a **G1–G13 nesmí ubýt**. U meshe je
> podmínka výslovná: **paritní test + snímek** (že obraz je STEJNÝ), ne tvrzení.
> **Přijímací kritérium (měřitelné):**
>   * `tests/cases/{config,metrics,chunk_mesh}.gd` (cesta jako VSTUP přes
>     `--<…>-script=`, jako u ostatních), moduly v `tools/gates/mutace-tests.py`,
>   * `app.config`: neznámý klíč se objeví v `check()` (nesmí být ticho);
>   * `app.metrics`: `report()` dá čísla, která jdou porovnat s `docs/01 §1.6`
>     (**60 FPS / ≤ 16 ms na frame**; dnes naměřeno **27 FPS při chůzi** a
>     **1 516 draw callů**, `_analyza/vlna5-chuze.gd`),
>   * `render.chunk_mesh`: **paritní test** (stejný seznam/obraz jako
>     `render.chunk`) + **snímek**, a čísla PŘED/PO (draw cally, ms na frame)
>     v HANDOFF — bez nich modernizace „nesmí ubrat měření“ nesplňuje,
>   * sada, `run-all.py` (0 vad), self-testy (0 chyb), `check-docs-refs` /
>     `check-zadani` / `roadmap-gen --check`, `plan-status.py` **bez nových
>     rozporů** (dnes 53 měřeně hotových; nové granule stav ZVÝŠÍ, nesmí snížit),
>   * smlouvy do `docs/04 §4.2` (a `§4.5`, pokud se dotkne dat), HANDOFF + LESSONS,
>     commit + push + **CI ověřené s PAT** (viz odstavec „CI“ níž — logy i obsah
>     kroků jsou nyní dosažitelné).
> **Pozor, co M9 může rozbít:** mesh mění cestu vykreslování, na které dnes stojí
> `PriorityZ` (E, 13. session) i **posun postavy mezi dlaždicemi (V2, 14. session)**
> — paritní test musí pokrýt i chůzi, ne jen stojící scénu. Nové `.gd` soubory
> potřebují `--import` pod plným přístupem (jinak nevznikne `.uid`, past 50).
> **Co do cíle NEPATŘÍ:** `sim.harvest`/`sim.craft`/`ui.journal` (16. session),
> `entity.equipment`, obsah M3+ až M8, M9 granule `app.config`/`app.metrics`
> **nejsou** blokované ničím (dají se udělat první a jsou levné).

**⏭ CÍL 19. SESSION (R6 z 2026-10-08) — ZÁSEK PŘI CHŮZI:**

> **⚠ Toto zadání se 18. session NESPLNILO** (session byla ladící: šest vad
> z fotek). Změřený stav po 18. session: `_analyza/p21-chuze.gd` (900 framů běhu) —
> frame ms **median 0,47, max 147,29**, framů **> 16 ms: 19**, `stavba_ms ≈ 170 ms`
> na 13 143 objektů. **WARNING a načítání stránek atlasu už v tom nejsou** —
> 18. session je přesunula na pozadí (`ResourceLoader.load_threaded_request`);
> zbývá **stavba seznamu a dávky**.
>
> **Sundat největší zásek hry: přestavba dávky stojí 53,8 ms každé 4 kroky**
> (max frame 149,8 ms, `_analyza/m9-vykon-po.gd`), tedy přesně to, co uživatel
> 12. session nazval „seká se". **Přijímací kritérium (měřitelné):**
> **žádný frame > 8 ms při souvislé chůzi** (dnes 149,8 ms) a **parita obrazu
> beze změny hashů** (`_analyza/m9-parita.gd` + `.py` musí dát stejné hashe jako
> dnes) — pravidlo M9 platí i pro tuhle změnu. Cesty: stavět dávku **po částech**
> (time-sliced) nebo **znovupoužít geometrii** objektů mezi přestavbami
> (`split` je 0,66 ms). Měří se stejnou sondou `m9-vykon-po.gd`.
> **Hned po R6 patří do plánu R5** (první frame < 300 ms — načtení atlasu)
> a pak `entity.equipment` (odložený cíl níž), který odblokuje souboj.
> **Co do cíle NEPATŘÍ:** `sim.enhance`, `ui.craft_gump`/`ui.backpack`, souboj,
> magie, obsah M3+.

**✅ CÍL 16. SESSION — SPLNĚN (text zadání se nemění, plní se jím další session):**

> **Dokončit `sim.harvest` + `sim.craft` + `ui.journal` (BIG WIN č. 1: „umět
> pracovat“).** Uživatel 11. session zvolil priority: **nejdřív řemeslo, souboj
> hned po něm**; `sim.skill_gain` (společný předek obou) je hotový, `entity.container`
> i `data.recipes` taky — **řemeslo je tím odblokované**.
> **Co musí umět (`docs/05 §5.7` a `§5.8`, měřená pravidla):** `harvest.mine/chop/fish`
> (respawn žíly 10–20 min), `craft.recipes_for/craft/smelt/repair` a **průběh
> s výzvou podle rozhodnutí uživatele**:
>   * **neúspěch craftu = materiál zmizí** (u `UseAllRes` polovina) a **skill
>     roste i při neúspěchu** (už to umí `sim.skill_gain` — jen to spoj),
>   * **dvojitý hod**: exceptionalita z **1. hodu**, úspěch z **2. hodu**
>     (`CraftItem.cs:1352-1359`), kvalita **Low 0 / Normal 1 / Exceptional 2**,
>   * exceptional = +14/+15 resist, +20 % trvanlivosti, zbraň +35 WeaponDamage,
>     nástroje 2× uses; **značka výrobce** při `MainSkill >= 100`.
> **`ui.journal`** je viditelná část (dnes zprávy jen `print`uje `app/loop.gd`):
> textový žurnál s barvami podle typu (`docs/05 §5.4`), napojený na událost
> `message`; **hlášky vlastními anglickými řetězci** (klilocy až po změření
> `assets.cliloc`, `docs/03 §3.5`).
> **⚠ Držení vstupu je od 12. session HOTOVÉ** (bylo to „navíc" v tomto cíli) —
> `app/input_map.poll()` opakuje krok při držení klávesy i pravého tlačítka,
> ověřeno v běhu (`_analyza/vlna7-drzeni.gd`).
> **Přijímací kritérium:** testy `tests/cases/harvest.gd`, `craft.gd`, `journal.gd`
> (cesta jako VSTUP přes `--<…>-script=`, jako u ostatních), **čtyři výsledky
> měřené se seedem** (fail / low / normal / exceptional), materiál se opravdu
> odečte, skill roste i při neúspěchu, `sim.craft` je zaregistrovaný v
> `SimWorld.systems` (aby `sim.interaction.use_on` přestal vracet
> `not_available`), mutační moduly v `tools/gates/mutace-tests.py`, `run-all.py`
> a sada zelené, **snímek s hláškou v žurnálu**.
> **⚠ SPLNĚNO S JEDNOU ODCHYLKOU (16. session): „čtyři výsledky" jsou ve
> skutečnosti TŘI** — `quality Low (0)` reference z výroby **nikdy nevydá**
> (`quality` startuje na 1, jediné přiřazení je `quality = 2`,
> `CraftItem.cs:1354-1356`). Naměřeno: 40 pokusů na 25,0 skillu → **0× Low**
> (a 0× Exceptional, protože `chance − 0,6 < 0`), na 60,0 → Exceptional padá.
> Test to MĚŘÍ (ne že by to předpokládal) a `docs/05 §5.8` to má zapsané.
> **Co do cíle NEPATŘÍ:** `sim.enhance` (zpackaná dýka — samostatná výzva,
> viz „Co čeká na tebe“ bod 5), mistrovské kousky s vlastností (runic/reforging
> až po `data.item_properties.json`), `ui.craft_gump`/`ui.backpack` (až bude
> vidět průběh), `entity.equipment`, souboj a M9.

**⏸ ODLOŽENÝ CÍL (původně 11. session) — `entity.equipment`:** uživatel ho
11. session nahradil vlnou „řemeslo“; **zadání níž platí dál** (je potřeba pro
souboj, ne pro řemeslo):

> **Dokončit `entity.equipment` (poslední granule Úkolu 6 ze
> `ZADANI-DALSI-VYVOJ-2.md`)** — `equip(m, item)`, `unequip(m, layer)`,
> `at_layer(m, layer)`, `total_weight(m)`, `bonus(m, key)` podle `docs/04 §4.2`,
> vrstvy `0x00–0x1F` (`docs/11` §11.7, `research/01` §2.6), **dvouruční zbraň
> uvolní vrstvu štítu**, a hlavně **invariant „právě jeden rodič" i pro nasazený
> předmět** (věc 66b: `entity.container` o předchozím rodiči „mobil" **neví**,
> takže `equip` ho musí z kontejneru vyjmout a `unequip` zase vrátit).
> **Proč právě tohle:** je to poslední granule Úkolu 6 (M2), sedí na hotové
> `entity.item` + `entity.container`, a je to systém, který `sim.interaction`
> (10. session) hledá pro větev `equip` — **rozhodni a zapiš, kudy ho najde**
> (`SimWorld.systems["equipment"]` jako u `craft`/`magic`, nebo dependency
> konstruktorem). Bez toho zůstane `use` na zbraň navždy `not_available`.
> **Přijímací kritérium:** test `tests/cases/equipment.gd` (cesta z argumentu)
> měří: `equip` štítu při dvouručné zbrani → `{ok:false}` s důvodem (roadmapa),
> `at_layer` po `equip`/`unequip`, `total_weight` = součet nasazených předmětů,
> **nasazený předmět není v kontejneru a naopak** (a `equip` ho z kontejneru
> vyjme), `bonus` čte `props`; modul v `mutace-tests.py` to chytí; `run-all.py`,
> testy hry i self-testy zelené.
> **Pozor na velikost:** deklarace je `<= 60` a model `any`, ale **naměřeno
> 9. session: `entity.container` má 192 řádků proti `<= 60`** — reálný odhad je
> 100–200 řádků; napiš do hlavičky, co smlouva nepinuje, a `size_lines` nech být
> (věc 2).
> **Co do cíle NEPATŘÍ:** `entity.notoriety`, vady ze snímků (věci 59–61), M9,
> držení klávesy (`app.input`, věc 27), `ui.*`, **registrace systémů v
> `app/main.gd`** (to je věc 68 — integrační session) a `sim.pathfind` (voják).

**Předchozí cíl (10. session), splněný:** **`sim.interaction`** (Úkol 4) — hotový
a měřený: **806 kontrol / 0 selhání**, **13/13 mutací** (`--only interaction`),
brány **11/0/0**, self-testy **19/0**, pokrytí §5.2.3 **měřené proti dokumentu**
(36 řádků, 10 pokrytých) a `docs/04 §4.2`/`§4.2.1` sedí na kód. Doklady v „CO JE
NOVÉHO (10. session)"; **v demu není vidět nic** (věc 68).

**Předchozí cíl (9. session), splněný:** **`entity.item` + `entity.container`**
(první dvě granule Úkolu 6) — hotové a měřené: **640 kontrol / 0 selhání**,
**20/20 mutací** (`--only item,container`), brány **11/0/0**, self-testy **19/0**,
smlouvy v `docs/04 §4.2`/`§4.2.1`/`§4.5` sedí na kód. Doklady v „CO JE NOVÉHO
(9. session)“ a v `LESSONS` (dvě pasti: invariant přes dvě instance a `tile` =
art id, které odhalila jen sekce nad reálnými daty).

**Předchozí cíl (8. session), splněný:** **konvence dveří ve `world.doors`**
(věc 62) — rozhodnutá **měřením** (art z `doors.txt` je zavřený, `art + 1`
otevřený; doklady v „CO JE NOVÉHO (8. session)"), opravená v modulu i v testu
a doložená **8 mutacemi** (`--only doors` 8/8). **Přijímací kritérium bylo
v jedné části vadné** („`is_open` = sudý člen dvojice" — platí jen pro blok
1717..1732, ne pro všech 37 kategorií) a **nahradilo se měřeným pravidlem**;
zapsáno v `LESSONS`. **Proč to bylo v pořadí před Úkolem 4:** `sim.interaction`
má „dveře → otevřít/zavřít" a se starou konvencí by přepínal dveře na **jiný
směr** téhož stavu. Byl to malý, uzavřený celek (jeden modul + test + mutace).

**Předchozí cíl (7. session), splněný:** rozhodnutí uživatele „zavřít slepé místo
v `tests/run_tests.gd` + přidat zbývající tři mutační harnessy podle návrhu" —
slepé místo zavřené (tři mutace to dokazují), fixture pro `render.hue`
a `render.anim` v gitu, tři harnessy v CI a ověřené v CI stavu (12/12, 11/11, 8/8).

**Předchozí cíl (6. session), splněný:** Úkol 3 ze `ZADANI-DALSI-VYVOJ-2.md`
(dveře a schody ve `world.walk`) — přijímací kritérium splněno: test se
zavřenými i otevřenými dveřmi, test kroku na schod nahoru/dolů, obojí s mutací
(`--only walk` **12/12**), `run_tests.gd` **537/0**, `run-all.py` **0 vad**.

## Co čeká na tebe

**✅ 2026-10-08: uživatel zadal „Pokračuj a témata čekající na mě rozhodni podle
svého úsudku" — rozhodovací pravomoc nad touhle sekcí tím přenesl na agenta.
Všechna otevřená témata jsou rozhodnutá v
[`ROZHODNUTI-2026-10-08.md`](ROZHODNUTI-2026-10-08.md)** (15 rozhodnutí R1–R15,
každé s naměřeným důvodem a cestou zpět). Dvě se provedla hned (R1 `era.skill_gain`,
R2 barva pozadí), zbytek je buď odložený s měřitelným cílem, nebo uzavřený.

**⚠ 2026-10-08 (19. session): tři NOVÉ věci k rozhodnutí (obě první jsou vratné
jedním řádkem, třetí je práce agenta):**

| # | Na co se čeká | Co to blokuje | Cena / cesta zpět |
|---|---|---|---|
| **V5b** | **Okno jiné než 1280x720 převzorkovává CELÝ obraz** — `canvas_items` stretch škáluje canvas zlomkem (okno 1300x740 → 1,0156×), takže i při zoomu 1,0 se změní **96,74 %** pixelů při čistém posunu obrazu. To je druhá, nezávislá příčina vady „při pohybu celá obrazovka zrní“ (první byla opravená `snap_screen`). | vada V5 u uživatele, pokud nehraje v přesně 1280x720 | `display/window/stretch/scale_mode="integer"` v `project.godot` (u pixel-artu obvyklé, ale při neceločíselném poměru okna vzniknou okraje) **nebo** hrát v 1280x720. ⚠ **Nezměřil jsem, že to pomůže** — Godot 4.7.2 tu hodnotu zná (`p22-stretch-sonda.gd`), ale moje metrika ostrosti oba režimy nerozlišila (72,65 % vs 72,66 % hran). Kdo to zkusí, ať udělá snímek PŘED/PO a změří to. |
| **V1b** | **Hranice opravy V1 (řazení hráče)**: hráč se kreslí za vším, co ho může překrýt, takže **statik o 1–2 diagonály dal s vysokým `z`** (zeď/strom vepředu) se může dostat před něj. Je to cena za to, že ho nepřekrývá podlaha pod ním (most, schody) — a stejné chování jako reference (mobilům počítá hloubku z `maxZ` dlaždice hráče). | věrnost u zdi vepředu; plný soulad umí jen **Z-buffer** (velký zásah do `render/`) | Vrátit se dá změnou `world_view._sort_key_of_player` (testy `world_view` 7/8c měří oba směry). Nová vrstva „fade statiků, které překrývají hráče“ (CoT, viz R-věc výš) je **správné dlouhodobé řešení** a je to nová funkce, ne oprava. |
| **V3b** | **`sim.regen` (doplnění staminy) NEEXISTUJE** — 19. session to jen obešla staty `DEX = 130` (`player_start_stats` v `data/balance.json`), takže postava po ~26 s běhu už jen chodí. Do té doby je to **PROZATIMNI** náhrada, ne oprava. | dlouhé běhání ve hře; návrat statů na normál (10/10/10) | Napsat `sim.regen` (v `SYSTEM_ORDER` už je, `app/main.gd` ho neregistruje) a vrátit staty; kritérium: po N sekundách chůze se stamina doplní a `p22-staty-sonda.gd` to změří. |

**Co z toho zůstává jako práce agenta (ne rozhodnutí):**

| # | Věc | Kdy / čím je hotová |
|---|---|---|
| **R6** | **Přestavba seznamu objektů i dávky je JEDINÝ zásek hry** — **18. session to změřila v běhu hry** (`_analyza/p21-chuze.gd`, 900 framů běhu): frame ms **median 0,47**, **max 147,29**, framů **> 16 ms: 19**, **> 33 ms: 15**; `mesh_stats().stavba_ms ≈ 170 ms` (13 143 objektů: 7 168 land + 5 975 statik). Děje se ~1× za 8 kroků (`RECENTER_TILES = 8`); **WARNING a načítání stránek už v tom nejsou** (načítají se na pozadí) | **Cíl 19. session:** stavět seznam i dávku **po částech** (time-sliced) nebo cachovat geometrii mezi přestavbami; kritérium: **žádný frame > 16 ms při chůzi** (dnes 19 z 900) + parita obrazu (hash jako `m9-parita.gd`). Rozpad ceny je v `_analyza/p20-kadence2.txt` |
| — | **⚠ Circle of Transparency / `TransparentTest` NEEXISTUJE** — střechy/stropy nad hráčem se už **skryjí** (18. session), ale **přední zeď** budovy hráče zakryje (naměřeno: `_analyza/p21-uvnitr.png`, hráč za zdí). Reference: `View.cs:98-101` (základ `false`), `StaticView.cs:17-31`/`MultiView.cs:18-32` (test s `World.Player.Z + 5`), fade po **±25** (`CalculateAlpha`), `FOLIAGE_ALPHA = 76`, translucency **178** | Rozhodnout a implementovat (je to **nová vrstva**, ne oprava vady): fade statiků, které překrývají hráče. Do té doby je hráč za zdí neviditelný — **stejně jako v živém klientu bez CoT** (proto to není „vada“, ale chybějící funkce) |
| — | **⚠ Černá obrazovka při chůzi se NEPODAŘILA reprodukovat** (18. session: 900 framů běhu, **0** černých snímků, nejčernější 4,2 %) | Když se vrátí, **potřebuji snímek nebo místo** („u kopců“). Pravděpodobně už opravená cesta „přetečení atlasu → prázdný mesh“ (17. session); 18. session k tomu přidala `pretek()`-only hlášení, aby se přetejk nehlásil, když jde jen o `hold` |
| — | **⚠ Rozdíl terénu proti živému serveru (fota 4–6) je opravený jen v naměřeném**: UV svahů (byly otočené o 45°) a subpixelový posun (91,55 % pixelů při 0,5 px) | Jestli je rozdíl vidět dál, **potřebuji konkrétní dlaždici + dva snímky** (náš a živý). Opravovat „dojem“ by znamenalo hádat |
| — | **⚠ Skrývání střech je ROZHODNUTÍ, které se může změnit**: reference skrývá jen `TileFlag.Roof = 0x10000000`, ale naměřeno, že běžné střechy v Británii (`slate roof`, flags `0x04006201`) ten flag **nemají** — proto se skrývá i `Surface & Background` nad hráčem (+16) | Když se to bude zdát moc agresivní (zmizí i strop, pod kterým hráč stojí jinde), změň prahy `PZ_NAD`/`PZ_SKRYT` v `render/chunk_renderer.gd` |
| — | **⚠ `nodraw` dlaždice (land id ≤ 2) zůstávají ČERNÉ** — 4 dlaždice v Británii (1440..1441, 1660..1661) land=2 → souvislý blok 2×2 černé (~88×88 px). UO je taky nekreslí (`AllowedToDraw = graphic > 2`), ale UO pod nimi má podloží | Rozhodnout v `docs/`: nechat (věrnost) a zapsat jako omezení, nebo kreslit dlaždici „pod“ (druhá vrstva landu z mapy) |
| R5 | **První frame hry ~2 008 ms** (načtení 34 stránek atlasu, ~58 ms/stránku — naměřeno `_analyza/p21-atlas-cena.gd`) | Session po R6: první frame < 300 ms, měřeno `_analyza/m9-vykon-po.gd`. ⚠ 18. session načítání **přesunula na pozadí** (hra se rozjede dřív, `ceka` to hlásí), ale **celkovou dobu nezkrátila** |
| R7 | **Mesh neorezává podle kamery** (15 838 primitiv místo 9 310) | Až s R6 (stejný soubor); dvouframové zpoždění nového artu je vědomé omezení |
| R11 | **Brány na chování v čase v CI** — část bez assetů (kadence kroků) | Do `tests/cases/movement.gd`; vizuální část zůstává lokální sonda |
| R12 | **`sim.enhance`** (zpackaná dýka) | Po `sim.craft` (řemeslo je hotové → může být další samostatný cíl) |
| R3 | **97 svitků kouzel** (1150 vs 1053) | Až se `research/04-gathering-crafting.md` §5.5 převede na data a generátor je vyrobí; `id` musí zůstat bez děr (`tests/cases/recipes.gd`) |
| — | **⚠ Světové statiky nejsou předměty (věc 64)** | Tavení u skutečné výhně nejde: `craft.smelt` bere vyheň jako **serial předmětu**, ale kovadlina/vyheň v mapě je statik. Buď `entity.item` dostane registr světa (`data.items` + mapa), nebo `smelt` přijme cíl dlaždice — **rozhodnout v `docs/04`** |
| — | **⚠ V okolí Britainu (200 dlaždic) není kovadlina ani vyheň** (měřeno sondou) | Ověřit, jestli jsou jinde / jak vypadají; než to bude, je kovářství v demu jen v testech |

**Dvě věci, které může udělat jen uživatel (a nic neblokují):** přenést barvu
pozadí do `project.godot` (R2 — kód to dělá taky) a změnit **trvalá pravidla
stanice** (`~/.dsh/AGENTS.md`), pokud by chtěl některé rozhodnutí povýšit na
pravidlo.

**Historické položky téhle sekce (zůstávají jako záznam, nic se nemaže):**

**⚠ NOVÉ (15. session, k rozhodnutí): čtyři věci kolem M9 — tři z nich jsou
vědomá omezení, jedno je nový nález.** Všechna čísla jsou naměřená
(`_analyza/m9-vykon-po.gd`, `m9-snimek.gd`), cesty zpět jsou levné:

| # | Na co se čeká | Co to blokuje | Cena / cesta zpět |
|---|---|---|---|
| 4a | **První frame hry stojí ~2 008 ms** — je to **načtení 34 atlasových stránek z disku** (`nacteni_stranek 34`; PNG 2048²), ne mesh (ten přidá ~50 ms). **Platí i pro původní cestu** (načítá je ve svém prvním `_draw`) | start hry (dnes 2 s černo/zmrzlý frame) | Buď přesunout načítání do úvodu s progress barem, nebo zmenšit stránky atlasu (`tools/uoextract/atlas.py`), nebo držet jen `Image` místo `ImageTexture`. Vratné; je to **samostatné téma**, ne M9 |
| 4b | **Přestavba dávky stojí 53,8 ms každé 4 kroky chůze** (max frame 149,8 ms) — seznam se přestavuje 45,8 ms + mesh 53,8 ms. Je to dnes **největší zásek hry** (dřív to bylo 45,8 ms, ale hra jela 24 FPS trvale) | plynulost (uživatel si na sekání stěžoval 12. session) | Stavět dávku **po částech** (time-sliced) nebo cachovat geometrii objektů mezi přestavbami; split je 0,66 ms. Vratné |
| 4c | **Nový art je vidět o 2 frame později** (`SubViewport` + `UPDATE_ONCE`; `hold()` to řeší) a **mesh neorezává podle kamery** (posílá 15 838 primitiv místo 9 310) | věrnost obrazu na 1 frame / zbytečná práce GPU | Obojí je zapsané v hlavičce `render/chunk_mesh.gd`; ořez podle kamery je možné přidat (drift pohledu je ±4 dlaždice). Vratné |
| 4d | **`app.config` se ptají jen `app.main` a testy** — `sim.movement` a `sim.skill_gain` čtou `data/balance.json` dál samy (vrstvové pravidlo: `sim/` nesmí volat `app/`) | jedno místo pro konfiguraci | Buď `app.config` přesunout do `core/` (pak ho smí použít i `sim/`), nebo nechat a zapsat jako omezení. Vyžaduje rozhodnutí o vrstvách — proto to není uděláno |

**⚠ NOVÉ (13. session, k rozhodnutí): šest vad pohybu od uživatele + dvě
rozhodnutí, která z nich plynou.** Celé měření (citace z ClassicUO/ServUO/Sphere
i sondy) je v **[`REVIZE-POHYB-2026-10-07.md`](REVIZE-POHYB-2026-10-07.md)**;
tady je jen to, co čeká na tebe (obojí vratné, obojí doložené měřením):

| # | Na co se čeká | Co to blokuje | Cena / cesta zpět |
|---|---|---|---|
| 1 | ~~Smím přepsat `docs/05 §5.1.4` (zákaz plynulého pohybu)?~~ **✅ VYŘEŠENO 13. session** — zákaz zrušen, `docs/05 §5.1.4` přepsán (doklad v „CO JE NOVÉHO (13. session)"). Dnes je **V2 opravená a měřená** (14. session) | — | — |
| 2 | ~~Předsunout `render.chunk_mesh` (M9) před obsah M3+?~~ **✅ VYŘEŠENO 15. session — M9 je HOTOVÉ (3 ze 3 granul), naměřeno 1 324 → 4 draw cally a 48,75 → 0,25 ms/frame** (doklady v „CO JE NOVÉHO (15. session)“). Zbývají jen vědomá omezení 4a–4d výš | — | — |
| 3 | **NOVÉ (14. session): mají být „brány na chování v čase" i v CI?** `REVIZE-POHYB` §5 je žádá (kadence a rozestup kroků, ms na frame proti `docs/01 §1.6`, `can_step` na reálné mapě, vizuální kontrola pohybu). Dnes jsou to **sondy v `_analyza/`** (`vlna14-pohyb.gd`, `vlna14-svah-most.gd`, nově `m9-vykon-po.gd`, `m9-parita.gd`) | regrese v časování a ve pravidlech chůze se v CI nepozná | Zavést jako krok CI jen to, co jde bez assetů (fixtures), zbytek nechat jako sondu; vratné |

**Šest vad pohybu je od 14. session VYŘEŠENÝCH (a měřených):** kadence kroku
(718/530 ms → 12 kroků za 5 s, median 404 ms — A, 13. session), směr z myši
(D, 13. session), zábradlí mostu (`PriorityZ`, E, 13. session), **posun s animací
v jedné fázi (V2)**, **svah (V4)** a **most nad vodou (V5)** — poslední tři
v této session; doklady v „CO JE NOVÉHO (14. session)" a v
`REVIZE-POHYB-2026-10-07.md` §2 a §7.

**⚠ TAKÉ NOVÉ (13. session, k rozhodnutí): směr projektu — singleplayer vs.
cizí shardy vs. vlastní server.** Uživatel se zeptal na hodnotu tří variant
(a) singleplayer, (b) custom klient na cizí UO shardy, (c) klient + vlastní
server, a k tomu na NPC/AI a „živý svět", moderní organizaci objektů (ECS)
a QoL. **Celá analýza s čísly je v
[`REVIZE-SMER-2026-10-07.md`](REVIZE-SMER-2026-10-07.md)**; doporučení je
**(a) teď, (c) jako držená opce, (b) jako samostatný produkt** — a pět ze šesti
oprav pohybu má cenu ve všech třech variantách, takže práce může začít hned.

**Dvě rozhodnutí z 12. session (obojí vizuální, obojí má cestu zpět):**

| # | Na co se čeká | Co to blokuje | Cena / cesta zpět |
|---|---|---|---|
| 1 | **Barva „void" (pozadí světa) je šedá `77,77,77`** — v UO je pozadí tmavé. Je to vidět u oblastí, které mapa označuje jako NODRAW (727 dlaždic z 29,4 M) a u budoucích děr | věrnost obrazu (docs/01 V4) | Jedno číslo v `project.godot` (`rendering/environment/defaults/default_clear_color`), ale **`project.godot` je bootstrap granule** → patří tobě. Vratné jedním řádkem |
| 2 | **Svahy se kreslí BEZ osvětlení rohů** (`CalculateNormal` v ClassicUO) — plocha je rovnoměrně barevná, v klientu je svah stínovaný | „vypadá to jako UO" | Patří k `render.light` (docs/07, M9+); dnes zapsané v kódu i v `docs/03`. Vratné (je to jen `draw_polygon` s bílou barvou) |

**Z plánu 13. session (nezměněné, čeká se jen na provedení):** `sim.harvest` +
`sim.craft` + `ui.journal` (viz „CÍL 15. SESSION").

**Ostatní otevřené (měřené, neopravené — detaily v tabulce V1–V6 výš):**
`V3` přestavba seznamu 45,8 ms každé 4 kroky (M9 `render.chunk_mesh`),
`V4` slabý heuristický test kůže v řidiči důkazu G10, `V5` posunutý první land
záznam v `tiledata.mul` (týká se jen id 0), `V2` `TexTerr.def` remap (aplikován).

**⚠ NOVÉ Z 14. SESSION (měřené, neopravené — k rozhodnutí nebo do plánu):**
`(1)` **stojná výška na schodu je `z + výška/2`**, protože `stone stairs`
(art 1823) mají flag `Bridge` (`0x2600`) — je to věrné referenci
(`TileData.cs:112-125`), ale mění to, jak vysoko postava na schodu stojí (o 3
jednotky níž u výšky 5); kdo bude dělat `render.anim` vrstvy nebo souboj, musí
s tím počítat. `(2)` **`GetAverageZ` u osamocené vyvýšené dlaždice vrací 0**
(rohy `[3,0,0,0]`) a krok na ni je povolený — měřená vlastnost reference
(`tests/cases/walk.gd` 1c), ne vada. `(3)` **sondy z 13. session měřily opis
našeho pravidla v Pythonu** (bez statiků): srovnání s **celým** modelem reference
dává jiná čísla (23 212 vs 0) — kdo z nich bude citovat, musí říct, která
reference to je (`LESSONS` 14. session).

**Na dnešní cíl nečeká nic** — 10. session se rozhodla měřením (`TARGET_ROLES`
z dat, oba id prostory) a cíl je hotový. **Ale čtyři rozhodnutí z
`ZADANI-DALSI-VYVOJ-2.md` §5 (`Otázky k rozhodnutí`) pořád čekají** — každé
z nich blokuje jinou trať, ne tu dnešní:

| # | Na co se čeká | Co to blokuje | Cena / cesta zpět |
|---|---|---|---|
**✅ VYŘEŠENO 11. session (rozhodl uživatel):**

| # | Rozhodnutí | Co z něj plyne |
|---|---|---|
| 1 | **Éra = AoS** (novější) | `era.loot` a `era.content` přepnuty na `aos`; skilly 48–57 zůstávají `implemented:false`, pořadí 55–57 se bere z `skills.mul`; **AoS loot znamená víc práce v `sim.loot`** (AoS packy + `data.item_properties.json`) |
| 2 | **Světlo — „naměř"** | **Naměřeno a nic k rozhodnutí:** den 0 (nejjasnější), noc 12, dungeon 26, rampy 4–6 a 22–24; kód i testy to už mají. Zestárlý byl jen **záznam** (`ZADANI F10`, bod 2 tady) — opraveno v této session |
| 3 | **Zvuk = vlastní trať** | Vyjmuto z M8 (`tools/roadmap-gen.py` + `docs/07`), schedulovatelné po `assets.sounds`; `.forge/roadmap.json` doložen `--check` |
| 4 | **Chůze držením** = ano, **myš i klávesa** | Session smí sáhnout do `app/input_map.gd` (věc 27 vyřešena); UO umí obojí (`GameSceneInputHandler.cs:41`, `_flags[4]`) |
| 5 | **Váha** | Odloženo; zůstává zapsané jako omezení (`docs/05 §5.4` chce 0.02 stones, data mají 0) |

**❓ NOVÉ OTÁZKY Z 11. SESSION (čekají na uživatele):**

| # | Otázka | Co to blokuje | Doporučení a cena |
|---|---|---|---|
| 1 | **AoS vs „učit se z chyb“:** v AoS dává neúspěch do šance na růst **0,0**, v pre-AoS **0,2** (`SkillCheck.cs:295`) — tedy v AoS se z neúspěchu učíš MÉNĚ, i když růst nezávisí na úspěchu | pocit z řemesla (BIG WIN č. 1) | **`era.skill_gain: "pre-aos"`** = jeden klíč v `data/balance.json` + 3 řádky větve v `skill_gain.gd`; `combat`/`loot`/`content` zůstávají AoS. Vratné |
| 2 | **`docs/06 §6.1` tvrdí 1150 receptů, data mají 1053** (97 chybí) | tvrzení o obsahu | Opravit dokument, nebo dostavět chybějících 97 (generátor). Doklad v nálezu N1 |
| 3 | **`sim.enhance`** (zpackaná dýka: neúspěch = půl materiálu, `Broken` = zničeno — `Enhance.cs:303-326`): do vlny s `sim.craft`, nebo až po ní? | „výzva a uspokojení“ (přání uživatele) | **Až po `sim.craft`** (samostatný cíl), ať se řemeslo nejdřív rozjede |

**Nová otázka z dnešní (9.) session (drobnost, ale ať se neztratí):** **váha
předmětů je u nás `int` ve stones a zlato má v datech 0** — `docs/05 §5.4` chce
0.02 stones a reference to řeší přebitím (`Gold.cs:34`) a fallbackem 0/255 → 1
(`Item.cs:3806`). **Doporučení:** váha v **setinách stones** (int, 0.02 = 2)
a `CONTAINER_MAX_WEIGHT` v setinách; cena je zásah do `core/const.gd` a
`world.tiledata` (obojí jiná granule), cesta zpět je triviální (konstanta).
Do rozhodnutí je to **zdokumentované jako omezení**, ne zamčené v kódu.

**Co bude následovat (bez tebe):** cíl 16. session = **`sim.harvest` + `sim.craft` + `ui.journal`** (BIG WIN č. 1 „umět pracovat“) — viz „CÍL 16. SESSION“ výš. **Odložený** je `entity.equipment` (potřebný pro souboj, ne pro řemeslo).

**Konvence dveří (věc 62) je od 8. session rozhodnutá MĚŘENÍM a opravená** —
nic na tebe nečeká. Montáž pro kontrolu pohledem
(`.cache/analysis/dvere-par-pohled.png`, dvojice `1717/1718` … `1731/1732`) na
disku pořád je, ale **rozhodnutí na ní nestojí**: je podložené třemi
asymetrickými signály (jména „closed"/„opened", `Impassable` 230 vs 71, `art+1`
nikdy v `doors.txt`) a referencí `openedID = closedID + 1`. Kdybys na ni koukl
a viděl něco jiného, je to **nový nález**, ne oprava — ozvi se s ním.
**10. session na konvenci navázala:** `sim.interaction` přepíná dveře přes
`world.doors.toggle` a test to měří na artu `1721 → 1722` (`is_open`).

## ⚠⚠ BLOKÁTORY

**Žádný otevřený blokátor v kódu.** „Demo chodí, postava je barevná, **vlevo nahoře je stavový pruh**, **svět je kreslený dávkou** a **od 16. session je
vidět žurnál a hráč umí kopat, tavit a vykovat nůž**“ je naměřené
(viz tabulky výš), brány jsou zelené (**11/0/0**), testy **1 194/0** (44 case
souborů) a **průchodnost, svahy i most jsou opravené** (6. session: statiky se
čtou správnou tabulkou, schody svou výškou; 8. session: `world.doors` páruje
`art` ↔ `art + 1`; 9. session: `entity.item` + `entity.container` hotové,
**20/20 mutací**; 10. session: `sim.interaction` hotový, **13/13 mutací**
a routing z dat; 11. session: `sim.skill_gain` + první UI, **15/15 nových
mutací**; 12. session: **vlna oprav ze snímků** — svahy (atlas + texmapy),
držení vstupu, stopa framů, sekání; **20 nových/rozšířených mutací**;
13. session: vlna pohybu A/D/E (kadence, směr z myši, `PriorityZ`);
14. session: vlna pohybu DOKONČENA — V2, V4, V5; 41/41 mutací;
15. session: M9 HOTOVÁ — `chunk_mesh`/`config`/`metrics`/`world_view` = 30/30;
**16. session: `sim.harvest` + `sim.craft` + `ui.journal` HOTOVÉ —
`harvest` 9/9, `craft` 10/10, `journal` 7/7 mutací**, celý harness **201 vzorů**).
**Hra jede 0,25 ms/frame (stoj) a 0,26 ms (chůze) se 4 draw cally** — naměřeno
`_analyza/m9-vykon-po.gd`; zbývající zásek je **jedna přestavba dávky 53,8 ms
každé 4 kroky** (max frame 149,8 ms) — to je **cíl 17. session (rozhodnutí R6)**.

**⚠ Dvě pojmenované mezery z 16. session (nejsou to blokátory, ale je vidět, že
jsou):** (1) **světové statiky nejsou předměty** (věc 64) → `craft.smelt` bere
vyheň jako serial předmětu a skutečná výheň v mapě serial nemá, takže tavení
u kovárny v demu nejde (sonda si vyheň položí jako předmět a **řekne to**);
(2) **v okolí Britainu 600 dlaždic sonda nenašla kovadlinu ani vyheň** (role
z `data/items.json`) — buď tam nejsou, nebo se statiky v mapě neshodují s rolemi;
kdo půjde kolem kovárny, ať to změří.

**⚠ CI NAD COMMITTY TÉTO SESSION (16.) JE ZELENÝ — `#60` nad `59eced2`
(kód + testy + smlouvy + HANDOFF/LESSONS) = `success`**, job **10:39 min**
(07:03:20 → 07:13:58 UTC). Ověřeno **živě s PAT** (`node _analyza/ci-beh-stav.mjs`,
`node _analyza/ci-hledej.mjs 60`), i **obsahem** kroků:
> * krok 7 (testy, sada **bez `assets/uo`**): **1 094 kontrol, 0 selhání**
>   (lokálně s assety 1 163 — rozdíl jsou `NEMĚŘENO` kontroly nad assety),
> * krok 8 (brány): **`SOUHRN: měřeno 9, čeká 2, chyb 0`** (`check-assets`
>   a `check-render` jsou „čeká“ = bez assetů NEMĚŘENO, což je povolené),
> * krok 9 (mutace): **`201 z 201 mutaci chyceno; smlouva vstupu: OK`** —
>   včetně **27 z 27** z této session (`harvest` 9, `craft` 10, `journal` 7
>   + kontrola vstupu), a krok 10 (`data/skills.json`) **8 z 8**,
> * krok 6 (self-testy): **21 celkem, 0 chyb**; kroky 11–13: `render-hue`
>   14/14, `render-anim` 11/11, `anim` 8/8,
> * krok 15 (plán): **0 rozporů**; krok 4 G4 (`check-wiring`): **63 granul
>   s hotovým souborem** (bylo 60) a **85 volaných z produkce** (bylo 80).
**⚠ Konec řetězu:** tenhle zápis je nový (jen dokumentační) commit, takže **běh
nad ním zkontrolovaný není** — jinak by každý záznam plodil další. Rozhoduje
`sha`: kód je v **`59eced2`** (zelený).

**⚠ CI NAD COMMITTY 15. SESSION JE ZELENÝ — `#57` nad `0275c0e`
(kód + testy + smlouvy + HANDOFF/LESSONS) = `success`**, job **5:00 min**
(23:41:40 → 23:46:41 UTC, 17 kroků + post kroky), a **`#58` nad `e7f8e0b`**
(commit, který zapisuje `#57` do HANDOFFu) = `success`, job **5:19 min**
(06:01:49 → 06:07:08 UTC). Ověřeno **s PAT** živě přes
`node _analyza/ci-beh-stav.mjs` (bez tokenu je API limitované).
**⚠ Konec řetězu:** tenhle zápis je zase nový (jen dokumentační) commit, takže
**běh nad ním zkontrolovaný není** — jinak by každý záznam plodil další. Rozhoduje
`sha`: kód je v `0275c0e` (zelený), dokumentace v `e7f8e0b` (zelený); kdo chce
ověřit i tenhle commit, ať se podívá na `sha` v `ci-beh-stav.mjs`.

**⚠ CI NAD COMMITTY 14. SESSION JE ZELENÝ — `#52` nad `5a42887`
(kód + testy + smlouvy + HANDOFF/LESSONS) = `success`**, **17 kroků (+ 3 post
kroky), job 5:21 min** (21:51:03 → 21:56:24 UTC; ověřeno živě přes API včetně
výpisu všech kroků: 6 self-testy, **7 testy bez `assets/uo`**, 8 brány,
**9 plný mutační důkaz**, 10–13 ostatní harnessy, 14 fixture, 15 stav plánu,
16 souhrn, 17 artefakty). `sha` rozhoduje, ne „poslední běh" — v okamžiku
kontroly byl `HEAD` = `5a42887` a `origin/main..HEAD` = `0`. Předchozí běh
`#51` nad `116f87c` (13. session) = `success` (20:58 → 21:03, 5:08 min).
**Hranice tvrzení bez tokenu:** logy ani artefakty nejdou stáhnout bez PAT
(`ci-log.mjs` -> 403, `ci-artefakt.mjs` -> 401) - tehdy je ověřený jen
**návratový kód** kroků.
**⚠ VYŘEŠENO 2026-10-07 večer (uživatel schválil „schvaluji, že si vezmeš PAT
z local-deepseek“):** PAT je v **`E:\Workspaces\forge-orchestra\.secrets\github_pat.txt`**
(mimo repo; do gitu ani do historie příkazů nepatří) a nástroje ho berou
z **`$env:GH_TOKEN`**. Tím se ověřil **i OBSAH kroků**, což dřív nešlo -
naměřeno v běhu **`#52` nad `5a42887`** (nástrojem **`_analyza/ci-hledej.mjs`**,
nový: hledá v logu podle vzorů, protože `ci-log.mjs` tiskne jen posledních
60 řádků a souhrny v nich nejsou):
> * **krok 7 (testy bez `assets/uo`): `932 kontrol, 0 selhání`** (sada je v CI
>   menší, protože assety v CI nejsou - `NEMERENO` se hlásí, nemizí),
> * **krok 8 (brány): `SOUHRN: měřeno 9, čeká 2, chyb 0`** (`check-assets`
>   a `check-render` jsou „čeká“ = bez `assets/uo` NEMĚŘENO, a to je povolené),
> * **krok 9 (mutace): `149 z 149 mutaci chyceno; smlouva vstupu: OK`** - včetně
>   **mých 41** z této session,
> * kroky 10-13: `skills` 8/8, `render-hue` 14/14, `render-anim` 11/11, `anim` 8/8
>   (self-test); **krok 6 self-testy: 21 celkem, 0 chyb**,
> * **krok 15 (plán): `53 hotových, 4 bez testu, 54 chybí`, `0 rozporů`.**
> * Dvě řádky `[test] FAIL ... NENI HOTOVA` v logu **nejsou vada**: to jsou
>   kontroly smlouvy vstupu (harness schválně podá neexistující cestu a test
>   MUSÍ spadnout).
**⚠ Co ověřené NENÍ (napsáno, ne zamlčeno):** navazující **dokumentační commity
`46848a0` (#53) a `b4b7287` (#54)** mají běhy = **`success` (20 kroků,
0 neúspěšných)**; **`b8e2476` (#55)** v okamžiku zápisu dobíhal. U těch tří jsem
nečetl **obsah** kroků (jen kód a počty). Věta „běh nad `46848a0` nešel vypsat
(HTTP 403)“ **platila pro stav bez PAT** a zůstává tu jako záznam - s PAT se běh
**našel** (`#53`).

**⚠ CI NAD COMMITTY 10. SESSION JE ZELENÝ — `#43` nad `200fdc6` (kód, smlouvy,
HANDOFF/LESSONS) a `#44` nad `4d0715c` (dokumentační dotyk + `cursor()` uvnitř
modulu) = oba `success`**, **17 kroků (+ 3 post kroky), job 2:56 a 3:09 min**
(13:37:45 → 13:40:41 a 13:42:52 → 13:45:45; ověřeno živě
přes API, výpis všech 17 kroků u obou). Prošel **krok 7** (import + testy, tj. sada
**bez `assets/uo`**, kde lokálně vychází **748/0**), **krok 8** (brány),
**krok 9 „Mutační důkaz testů" se 94 mutacemi** a kroky 10–13 (`skills` 8,
`render-hue` 12, `render-anim` 11, `anim` 8 — **dohromady 133**);
krok 15 „Stav plánu" taky (**po commitu 48 měřeně hotových, 0 rozporů**). **Předtím** `#42` nad `2ede2c9` a `#41` nad
`adbd2cb` = `success` (9. session), `#40` nad `17ebc04` = `success`,
**`#39` nad `bcd9128`, `#38` nad `98542a3`,
17 kroků, job 1:33 min** (krok 9 tehdy s **61 mutacemi** — lokálně celý
`mutace-tests.py` trvá minuty, takže `timeout-minutes: 30` je s rezervou).
**Předtím** #37 nad `ce0c38e` = `success`
(7. session push), #36 nad `073583b` = `success`; #34 nad `4259091` = `success`
(17 kroků, včetně nových 11–14 z 7. session); #30 nad `f243ba2` = `success`
(13 kroků; krok 9 = 53 mutací se vešlo do `timeout-minutes: 30`), #31 nad
`062f419`, #29 nad `702dac2`, #23 nad `e6ff22e`, #24 nad `88b4747` — vše `success`.
**Pozor na hranici toho tvrzení:** logy ani artefakty nejdou bez tokenu stáhnout
(`ci-log.mjs` → 403, `ci-artefakt.mjs` → 401), takže **výpis** kroků v CI ověřený
není — **ale návratový kód kroku 9 ověřený je, a není slabý:** `mutace-tests.py`
vrací `1`, když nějaká mutace projde (nebo když selže smlouva vstupu), takže
`success` kroku 9 znamená **všech 94 mutací chycených na runneru** (a to i bez
`assets/uo`). Totéž platí pro krok 7 (testy bez `assets/uo`) a krok 15
(`plan-status.py --check`). **Co ověřené není:** konkrétní čísla, která CI vypsala
(vidíme jen kód, ne text). Lokálně naměřeno (10. session): **`mutace-tests` 94/94**
(+ smlouva vstupu OK), a **kroky 10–13 v CI #43** doložily i `skills` 8/8,
`render-hue` 12/12, `render-anim` 11/11 a `anim` 8/8 — **dohromady 133/133**.
**A pozor na počet běhů:** série pushů pustí víc běhů; „poslední
běh" tedy nemusí být ten, který člověk myslí — **sha v odpovědi API je to, co
rozhoduje.** Předchozí běhy #16, #17 a #19 mají poučení:

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

1. ~~**Tři mutační harnessy nejsou v CI.**~~ — **VYŘEŠENO 7. session** (rozhodnutí
   uživatele): `mutace-anim.py`, `mutace-render-anim.py` a `mutace-render-hue.py`
   mají v `ci.yml` vlastní kroky a **data berou z fixture v gitu**
   (`tests/fixtures/{hues,anim}/`), takže v CI opravdu měří — naměřeno v CI
   stavu (bez `assets/uo`, bez instalace UO): `12/12`, `11/11`, `8/8`.
   **Pozor:** můj původní návrh tvrdil, že `hues.json` „má data v gitu" — nemá;
   fixture musely dostat všechny tři.
2. ~~**`tests/run_tests.gd` tiše přeskočí case soubor s parse errory**~~ —
   **VYŘEŠENO 7. session** (věc 21): `can_instantiate()` před `new()`, `script_at()`
   v `tests/lib.gd` vrací `null` i pro neinstanciovatelný skript, case bez jediné
   kontroly je `FAIL`. **Baseline `N kontrol` si přesto měř před zásahem
   a po něm** — je to nejcitlivější ukazatel (postup v `LESSONS.md`).

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Demo (hra)** | **`HRA.cmd`** v kořeni (dvojklik) — spouštěč řeší Godot, `APPDATA` i chybějící data. Ručně: `& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-driver opengl3` (s `$env:APPDATA` ve workspace) |
| **Zadání pro další vývoj** | **`ZADANI-DALSI-VYVOJ-2.md`** (etapa 2, Úkoly 1–9; **hotové: Úkoly 1, 2, 3, 4 a z Úkolu 6 první dvě granule** — `entity.item`, `entity.container`). Etapa 1 je v `ZADANI-DALSI-VYVOJ.md` |
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| **Kam pro co v referencích** | **`research/REJSTRIK-REFERENCI.md`** (rozcestník, ~50 odkazů s měřeným počtem nálezů) — generuje a kontroluje `python tools/refs-index.py [--check\|--srovnej]` |
| **Multiplayer bokem** | **`research/08-multiplayer-poucky.md`** — 17 principů ze serverů, „u nás dnes" + co platí až s multiplayrem |
| **Referenční klony** | `_src/{runuo,servuo,modernuo,classicuo,sphere}` (**pinované**, gitignore, nejsou submoduly). Pozor: `research/_src/{servuo,modernuo}` jsou **druhé checkouty téhož** — pro čtení používej `_src/` |
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes\|skills]` |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` → **806 kontrol / 0 selhání** (s assety), **31 case souborů**; **bez `assets/uo` (stav jako v CI) `748/0`** — měřeno 10. session dočasným přesunem `assets/uo` do `.cache` a zpět (viz „Předletová kontrola“). **Bez plného přístupu dej `APPDATA` do `.tmp`** (viz pasti) |
| Brány | `python tools/gates/run-all.py` → **11 měřeno / 0 NEMĚŘENO / 0 chyb**, `exit 0` |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 self-testů (10 bran + 9 extrakčních nástrojů), 0 chyb**; **G10 má uvnitř 8 případů** |
| **Mutační důkaz testů** | `python tools/gates/mutace-tests.py [--only sort\|map\|walk\|doors\|movement\|registry\|pathfind\|textures\|item\|container\|interaction]` → **94 z 94** (bylo 81; **+13 `interaction`**; trvá desítky minut — `walk` má 12 mutací) |
| **Mutační důkaz dekodéru animací** | `python tools/gates/mutace-anim.py [--install <UO>]` → **8 z 8** (bez instalace UO měří jen self-test a **řekne to**: `realna sonda: NEMERENA`; proměnná `UO_INSTALL`) |
| **Mutační důkaz `data.skills`** | `python tools/gates/mutace-skills.py` → **8 z 8** |
| **Mutační důkaz `render.anim`** | `python tools/gates/mutace-render-anim.py` → **11 z 11** (fixture v gitu, běží i v CI) |
| **Mutační důkaz `render.hue`** | `python tools/gates/mutace-render-hue.py` → **12 z 12** (fixture v gitu, běží i v CI) |
| **Sonda: unikátnost mutačních vzorů** | `python _analyza/mutace-vzory.py` (**gitignore**) → `mutace-tests: 94 vzorů` (10. session: +13 `interaction`) + `mutace-render-anim: 11` = **105**, `OK`; ověřená mutací sebe sama. **Pozor:** u `mutace-tests` sonda unikátnost jen **vypisuje** (`movement/druhy krok v letu se neodmitne` je **2×**) — tvrdit u ní „vada“ by bylo tvrzení o něčem jiném; nové moduly `item`/`container` (9. session) i `interaction` (10. session) mají všechny vzory **1×** (ověřeno skriptem před během) |
| **Předmět a kontejner (9. session)** | `sim/entity/item.gd` + `sim/entity/container.gd` + `tests/cases/{item,container}.gd`; `tile` = **art id**, invariant „právě jeden rodič“ (jedna instance = všechny kontejnery světa), limity 125/400/60 000, slučování hromad podle flagu `Generic` |
| **Interakce (nové, 10. session)** | `sim/systems/interaction.gd` + `tests/cases/interaction.gd`; `use`/`use_on`/`context_menu`/`context_action`, routing z `data/items.json` (`category`/`role`, `TARGET_ROLES`), parová tabulka §5.2.3 měřená proti `docs/05`, dynamický routing do `SimWorld.systems` (`not_available` místo ticha) |
| **Registr bytostí (nové)** | `sim/entity/registry.gd` + `tests/cases/registry.gd`; `register`, `get_mobile`, `all`, `remove`, `size` |
| **Animace: dekodér** | `python tools/uoextract/anim.py --self-test \| --verify \| --export assets/uo/anim \| --export-check assets/uo/anim` |
| **Dekodér: objevné sondy** | `_analyza/anim-rle-sonda.py`, `_analyza/anim-rle-hledani.py`, `_analyza/anim-dekod.py` (**gitignore** — v gitu je jen produkční `anim.py` a mutační harness) |
| **Snímek z běhu** | `godot --path . --rendering-driver opengl3 --resolution 1280x720 --write-movie .cache/render/run-<tag>/frame.png --quit-after 5` — **cesta musí mít dopředná lomítka** (viz pasti) |
| **Důkaz chůze (řidič)** | `godot --path . --rendering-driver opengl3 --write-movie .cache/render/chuze/frame.png --script res://.cache/analysis/demo-chuze.gd` (řidič je v `.cache/`, gitignore) |
| Fixture pro `world.map` | `python tests/fixtures/world/make_fixture.py [--check]` |
| **Fixture pro `render.hue` (nové)** | `python tests/fixtures/hues/make_fixture.py [--check]` — sady 1002/1003; test je měří VŽDY (`render_hue.gd`, sekce D) |
| **Fixture pro `render.anim` (nové)** | `python tests/fixtures/anim/make_fixture.py [--check]` — 6 spritů + 2 PNG; test je měří VŽDY (`render_anim.gd`, sekce FIXTURE) |
| **Harness testů: kde je smlouva** | `docs/04 §4.8.1` (co dělá při parse erroru) a `§4.8.2` (fixture + které harnessy běží v CI) |
| Replaye pro G9 | `tests/replays/tic_200.json`, `tic_1000.json` |
| Sonda renderu + mutace | `.cache/analysis/{probe-render.gd,mutace-render.py,mutace-snimek.py}` |
| Stav a logy CI běhů | `node _analyza/ci-beh-stav.mjs` · `node _analyza/ci-log.mjs` · `node _analyza/ci-artefakt.mjs` |
| Godot (binárka) | `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable.official.ed1daf0bf) |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` — **111 granul, `done` je u všech `false`**: stav se pozná **jen měřením** (`python tools/plan-status.py`); generuje ji `python tools/roadmap-gen.py` (`--check` ověří aktuálnost) |
| Data z instalace | `assets/uo/` (gitignore) — mimo jiné **`anim/` (30 PNG + `anim-sheets.json`)** a `anim-manifest.json` |

## Stav kódu (počty řádků Pythonem `splitlines()`, bez `.uid` a `__pycache__`)

*(⚠ **Přeměřeno 18. session** — `python _analyza/radky.py`; tabulka níže byla
naposledy aktualizovaná v 10. session, čísla v závorkách jsou proto historická.)*

| složka | souborů (kód) | řádků kódu | poznámka |
|---|---|---|---|
| `core/` | 7 | 339 | hotové a otestované |
| `sim/` | **20** | **4 379** | 10. session: **`systems/interaction.gd` 461**; dřív `entity/item.gd`, `entity/container.gd`, `world/walk.gd`, `world/pathfind.gd`, `systems/movement.gd`; 16. session: `systems/harvest.gd`, `systems/craft.gd` |
| `render/` | **6** | **1 731** | `sort.gd`, `texture_cache.gd`, `chunk_renderer.gd`, `chunk_mesh.gd` (M9), `anim_player.gd`, `hue_cache.gd` |
| `ui/` | **3** | **283** | `hud.gd`, `status_bar.gd`, `journal.gd` (16. session; tabulka `_analyza/radky.py` je nepočítá, čísla jsou z `Path.glob`) |
| `app/` | 8 (7 kód) | 1 906 | `main.gd`, `world_view.gd`, `player_controller.gd`, `input_map.gd`, `loop.gd`, `config.gd`, `metrics.gd` (bez granul) |
| `tests/` | **58** (49 kód) | **9 845** | 44 case souborů; **1 194 kontrol / 0 selhání** (18. session) |
| `tools/uoextract/` | 39 | 6 567 | `anim.py` umí pixely, `--export`, `--export-check` |
| `tools/gates/` | 22 | **5 631** | 18. session: `mutace-tests.py` — vzory po změnách (sort, chunk_mesh, chunk_renderer, world_view, player_controller, movement, journal), nové mutace pro váhu diagonály, průchod landu, `round` posunu a černý pás |

*(Počty jsou Pythonem `splitlines()` nad kódovými soubory `.gd`/`.py`/`.sh`/`.mjs`,
bez `.uid` a `__pycache__` — `python _analyza/radky.py`.)*

**Zbývá 63 granul** (z 111; **48 měřeně hotových** po commitu — ověř
`python tools/plan-status.py`; ⚠ **z toho 2 jsou artefakty metriky** — `assets.gump`
a `data.recipes`, viz věc 69). Hotové (souborem i měřením) navíc proti 3. session:
**`sim.entity_registry`** (4. session), **`sim.pathfind`** (5. session),
**`entity.item` + `entity.container`** (9. session), **`sim.interaction`**
(10. session). *(Pozor: „měřeně hotové" je jiný čítač než
`granuli_s_hotovym_souborem` v G4 — ten je **54**; viz `plan-status.py` vs
`check-wiring.py`.)*

## Co je hotové a ověřené (ne „soubor existuje")

**M0 celek** · **W0** (8) · **M1: uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc, anim (VČETNĚ pixelů), data.items, data.gen_content,
data.recipes, world.tiledata, world.map, render.sort, render.textures,
render.chunk, render.anim, render.hue** · **M2: world.doors, world.stairs,
entity.stats, world.time, entity.skills, entity.mobile, world.walk,
sim.movement, data.skills, `sim.entity_registry`, `sim.pathfind`,
**`entity.item`, `entity.container`** (9. session), **`sim.interaction`**
(10. session)** ·
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
- **Testy už NEMLČÍ (7. session)** — parse error v case souboru i v granulích,
  které case používá, dnes sada **ohlásí** (`FAIL`, `exit 1`), místo aby tiše
  zmizela část kontrol; doloženo **třemi mutacemi** (`504/1`, `453/3`, `480/3`)
  a `case souboru spusteno: N z M`.
- **CI měří i render (7. session)** — `render.hue` a `render.anim` mají fixture
  v gitu, takže jejich mutační harnessy běží v CI a **v CI stavu** (bez
  `assets/uo`) dávají `12/12` a `11/11`.
- **Konvence dveří je ZMĚŘENÁ, ne odhadnutá (8. session)** — `world.doors` páruje
  `art z doors.txt` (zavřený) s `art + 1` (otevřený); tři nezávislé asymetrické
  signály nad 230 arty + reference (`openedID = closedID + 1`) a **8 mutací**,
  které to hlídají. **Sudý art ani `layer` kritériem nejsou** (16 kategorií má
  všechny kusy sudé).
- **Předměty a kontejnery DRŽÍ INVARIANTY (9. session)** — `entity.container` má
  jednu instanci pro všechny kontejnery světa, takže `add` umí předmět vyjmout
  z předchozího rodiče: test měří, že předmět přesunutý z kontejneru `101` do
  `202` je **jen v `202`**. Limity (125/400/60 000) se měří **na obou stranách**
  (přesně na mezi se vejde, o jedna víc ne) a **neúspěšný `add` stav nemění**;
  slučování hromad je měřené pravidlo (flag `Generic`, 898 předmětů z 65 536)
  včetně reálných dat (`0x4EED` zlato ano, `0x4F52` dýka ne, longsword 3×7 = 21).
  Důkaz: `tests/cases/container.gd` (sekce D–K) + **20 mutací** (`--only
  item,container`), které to chytí.
- **Interakce je routing z DAT, ne větev v kódu (10. session)** — `use` na
  **kovadlinu** nic neudělá a **řekne to** (kovadlina má v `data/items.json`
  `category == "tool"`, ale je to cíl: `TARGET_ROLES`), neznámý předmět odpoví
  hláškou (nikdy ticho), `use_on` bez systému vrátí `{ok:false,
  reason:"not_available"}`, dveře jdou přes `world.doors.toggle` (`1721 → 1722`,
  konvence z 8. session) a **každý z 15 párů** tabulky se měří se stubem
  (zavolaná metoda **i argumenty**). Pokrytí §5.2.3 se měří **proti dokumentu**
  (`docs/05` má 36 řádků, pokryto 10 = 11 párů) — nový řádek v dokumentu test
  shodí. Důkaz: `tests/cases/interaction.gd` + **13 mutací**.
- **Testy 806/0 s assety** (v CI stavu **748/0**), **brány 11/0/0** (`exit 0`),
  **self-testy 19/0**, **mutace 133/133** (`mutace-tests` **94** — z toho 13
  `interaction`, 8 `doors`, 5 `item`, 15 `container`, `skills` 8, `render-hue` 12,
  `render-anim` 11, `anim` 8), vzory mutací **105** `OK`.
- **Hra nespadne**: G11 `smoke` → `framu 120, script_error 0, parse_error 0`.

### ⚠ Co na obrazovce ještě NENÍ

Souboj, magie, obchod, řemeslo, UI (žurnál, status bar, paperdoll), jména nad
postavami, světlo (`render.light`), **výbava na postavě** (postava je nahá),
druhé postavy, mount, pathfinding, zvuk. **Hratelná mechanika: chůze, otáčení
a barva kůže.** Statiky nesou barvu ze záznamu mapy, ale **nikdo ji nepoužívá**
(věc 35).

## Co brány dnes měří (2026-10-07, 10. session)

`run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 VADA**, `exit 0`.

| Brána | Výsledek | Je to vada kódu? |
|---|---|---|
| G1–G11 | **OK** | NE |
| G4 | OK — `granuli_s_hotovym_souborem: 54` (bylo 53), `provides_jmen: 112`, `volanych_z_produkce: 67`, `jen_z_testu: 38`, `neintegrovano: 7`; **`sim.interaction.{use,use_on,context_menu,context_action}` i `entity.item`/`entity.container` jsou „volá ho jen tests/"** (acceptance `wiring` nežádá — věci 64 a 68) | NE |
| G6 | OK — měří `anim_decoder_kod: 0`, `anim_decoder_kontrol: 35`, `spritu_zkontrolovano: 41874`, `stranek_chybi: 0` | NE |
| G9 | OK — `tic_200` = `281e7802…`, `tic_1000` = `9e6218ab…` (**stejné hashe jako před session**; `sim.interaction` v replayi zaregistrovaný není) | NE |
| G10 | OK — `barev: 2124`, `pixelu_mimo_pozadi: 892595`, **`kuze_pixelu: 8634`, `kuze_barva: R52 G42 B42`** — **stejná čísla jako 4., 5., 8. a 9. session** (kód obrazu se nedotkl) | NE |
| G13 | PORADNÍ | NE — `vision.mjs` není (poradní je podle `docs/08 §8.2`) |

## Předletová kontrola (5 minut, než začneš psát)

| Co | Jak | Očekáváno (2026-10-08, **15. session**) |
|---|---|---|
| Strom je čistý | `git status --porcelain -uall` | **prázdné** po commitu této session |
| Je před GitHubem | `git rev-list --count origin/main..HEAD` | **`0`** — 15. session pushla (trvalé povolení uživatele z 2026-10-07) |
| **Běží CI?** | `node _analyza/ci-beh-stav.mjs` (bez tokenu je limitovaný — viz past v `LESSONS`) · anotace: `node _analyza/ci-anotace.mjs` | **viz odstavec „CI" v BLOKÁTORECH níž** (vyplněno po pushi této session); sha rozhoduje, ne „poslední běh" |
| **Obsah kroků CI (logy)** | **s PAT:** `$env:GH_TOKEN = (Get-Content 'E:\Workspaces\forge-orchestra\.secrets\github_pat.txt' -Raw).Trim()` a pak `node _analyza/ci-hledej.mjs <cislo_behu> ["vzor"...]` (hledá v logu podle vzorů) · `ci-log.mjs <id>` (posledních 60 řádků + „podezřelé“) — **bez PAT** → `ci-log.mjs` **HTTP 403**, `ci-artefakt.mjs` **401** | S PAT je ověřený **i obsah**: `#52` dal `932 kontrol, 0 selhání` (krok 7), `měřeno 9, čeká 2, chyb 0` (krok 8), **`149 z 149 mutaci chyceno`** (krok 9), `53 hotových, 0 rozporů` (krok 15). Bez PAT je ověřený jen **vznik a výsledek** běhu (a i ten jen mimo rate-limit okno: neautentizované API vrací **403**) |
| Repo je veřejné | API bez tokenu | `visibility: public` |
| **Oprávnění** | `whoami /groups \| Select-String Mandatory` | **⚠ 14. session začala v `Low`** (`workspace-write`): brány hlásily **2 falešné vady** (G3 `sim.world_loop` save a `render.textures`, protože podproces nesměl zapsat do `.cache`) a sada **9 selhání**; po přepnutí na **plný přístup** (`danger-full-access`, přepnul uživatel) je vše zelené. **Měř vždy pod plným přístupem** (`LESSONS` 14. session) |
| Testy | `$env:APPDATA="$PWD\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` | **1 194 kontrol, 0 selhání**, **44 case souborů** (`case souboru spusteno: 44 z 44`), **`$LASTEXITCODE` = 0** (16. session; bylo 1 055 / 41). ⚠ exit kód ber z `$LASTEXITCODE` hned po Godotu — `exit code` celého `pwsh` s rourou je kód posledního příkazu v rouře |
| **FPS (M9 hotová)** | `& .cache\godot\...console.exe --path . --rendering-driver opengl3 --resolution 1280x720 --script res://_analyza/m9-vykon-po.gd` (3 s stoj + 6 s chůze, čeká se **nástěnnými hodinami**) | **4 draw cally, frame 0,25 ms (stoj) / 0,26 ms (chůze), p90 0,33/0,34, Engine FPS 3 724/2 593**; přestavba dávky 53,8 ms, split 0,66 ms. **Před M9** (14. session / `m9-vykon-pred.gd`): 1 324 draw callů, 48,75 ms, 24 FPS. ⚠ `Performance.TIME_PROCESS` je klouzavý průměr — po 2s stavbě hlásí stará čísla; měř `delta` |
| Brány | `python tools/gates/run-all.py` | **11 měřeno / 0 NEMĚŘENO / 0 vad**, `exit 0` (`_analyza/zaver16-brany.txt` = `.cache/zaver16-brany.txt` z 16. session) |
| Self-testy | `python tools/gates/run-all.py --self-test` | **21 celkem (10 bran + 11 extrakčních nástrojů), 0 chyb**, `exit 0` |
| Mutační důkaz | `python tools/gates/mutace-tests.py --only harvest,craft,journal` (nové moduly) · plný běh dělá CI | **27 z 27 chyceno** (`harvest` 9 + `craft` 10 + `journal` 7 + kontrola vstupu), smlouva vstupu OK (16. session). Předtím `chunk_mesh`/`config`/`metrics` = 25/25. **Plný harness 201 vzorů** (15. session: 174). ⚠ Mutace našla dvě slepé kontroly v nových testech (barvy, velikost žurnálu) — viz `LESSONS` |
| Fixture | `python tests/fixtures/{world,hues,anim}/make_fixture.py --check` | **3× OK**, `exit 0` |
| Animace / Barvy / Texmapy | `anim.py` / `hues.py` / `texmaps.py --verify` | `35 / 5 / 4 116` kontrol a texmap, 0 chyb (v self-testech bran) |
| **Snímek je z běhu** | `Get-Item .cache/render/snapshot.png` | G10 prošla (**`kuze_pixelu 9101`**, `barev 3767`) — snímek je z 15. session; **parita obrazu** (dávka vs. původní cesta, 3 scény, stejný hash) je v `_analyza/m9-parita.gd` + `m9-parita.py`. **16. session přidala snímek žurnálu** `.cache/render/vlna16-zurnal.png` (`_analyza/vlna16-sber-vyroba.gd`), na kterém je **vidět řádek zpráv** — kdyby velikost `RichTextLabel` chyběla, je prázdný (naměřeno) |
| Godot běží | `& .cache\godot\...console.exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |
| Instalace UO na místě | `Test-Path 'D:\Games\...\tiledata.mul'` | `True` |
| Kontroly zadání | `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` | `exit 0` (všechny tři, 14. session) |
| Stav plánu | `python tools/plan-status.py` | `111 granul`, **`59` měřeně hotových** (16. session +3), **0 rozporů**; **`M4 4 / 0 / 2`** (16. session; předtím 1/0/5) a **`M9 3 / 0 / 0`**; `done: true` v roadmapě zůstává **0** (stav se měří, nepřepisuje) |
| **Sandbox** | `whoami /groups \| Select-String Mandatory` | **musí být `Medium`** (plný přístup); `Low` = `workspace-write` → falešné vady (viz „Oprávnění" výš a `LESSONS`) |

## Otevřené věci a co je potřeba dodělat

**Přenáším z minulého předání (nic se nemaže) — u každé je dnešní stav:**

1. **Soubory bez testu** — **PLATÍ DÁL, ale je jich méně**: test má
   `world/walk.gd`, `systems/movement.gd`, `entity/skills.gd`, `entity/mobile.gd`,
   `render/anim_player.gd`, `app/player_controller.gd`, `entity/registry.gd`,
   `entity/item.gd`, `entity/container.gd` (9. session) a **od 16. session
   `systems/harvest.gd`, `systems/craft.gd` i `ui/journal.gd`**.
   **Bez testu zůstávají** `world/tiledata.gd`, `app/main.gd`, `app/main.tscn`,
   `render/texture_cache.gd`, `render/chunk_renderer.gd`, `app/world_view.gd`,
   `app/loop.gd`, `render/hue_cache.gd` (má test nepřímo přes G10).
   **⚠ 16. session: `ui/journal.gd` MĚL test a přesto byl v demu neviditelný**
   (velikost `RichTextLabel` 0) — chytil to až snímek; kontrola i mutace už na to
   jsou (`LESSONS` 16. session). `app/main.gd` a `app/loop.gd` jsou teď jediné
   dva soubory, kde se registruje a předává, a test nemají — to je věc 68.
2. **`size_lines` nesedí** — **PLATÍ DÁL a přibylo to** (měří
   `python tools/plan-status.py`; **36 deklarací z 93**, bylo 34): nově
   **`entity/container.gd` 192/60** (3,2×) a **`entity/item.gd` 66/60** (1,1×) —
   obojí je hlavně **hlavička s naměřenými čísly a citacemi** (co smlouva
   nepinovala, odkud je pravidlo, čím se vyvrátí); zkrácení by tu znalost smazalo.
   Dřív: **`world/walk.gd` 222/120** (6. session: +70 řádků — stejný důvod),
   `entity/registry.gd` 66/60,
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
21. ~~**`tests/run_tests.gd` tiše přeskočí case soubor s parse errory**~~ —
    **VYŘEŠENO 7. session** (rozhodnutí uživatele). Mechanismus byl jiný, než
    jsme si mysleli: `load()` vrací **nenulový** `GDScript` a teprve `new()`
    přeruší `_init_case`, která vrátí `null` → smyčka to brala jako „ohlášeno"
    a přeskočila soubor (`503 kontrol, 0 selhání`). Opraveno na třech místech
    (`can_instantiate()` před `new()`, `script_at()` v `tests/lib.gd`, guard na
    „0 nových kontrol") a doloženo **třemi mutacemi** (`504/1`, `453/3`,
    `480/3`, všechny `exit 1`). Detail: `docs/04 §4.8.1`.
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
27. ~~**NOVÉ: držení klávesy neopakuje krok.**~~ — **VYŘEŠENO 12. session**
    (ávodní text se nemaže): `app/input_map.gd` čte `is_action_pressed` a krok
    vydává po `step_delay_ms` (400/200 ms); puštění prodlevu vynuluje. Navíc
    **držené pravé tlačítko** (`walk_to`): směr z kurzoru, `run` podle 190 px od
    středu okna (ClassicUO `GameSceneInputHandler.cs:41,66`). Ověřeno v běhu hry
    (`_analyza/vlna7-drzeni.gd`): 2,5 s držení klávesy → 4 kroky, 100 ms stisk →
    1 krok, 2 s držení pravého tlačítka → 8 kroků a −4 stamina.
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
32. **NOVÉ: řidič dema je v `.cache/` (gitignore).** — **PLATÍ DÁL a rozšířeno
    12. session:** všechny sondy téhle session (`_analyza/vlna*.gd`, `vlna*.py`)
    jsou taky v gitignore, takže **v čistém klonu nejsou**. Kdo je bude
    potřebovat, najde v `LESSONS` (12. session), co měřily a jaké daly číslo;
    reprodukovat je znamená napsat je znovu (jsou popsané v hlavičkách).
    Důkaz chůze (`demo-chuze.gd`) se v čistém klonu nespustí. Kdyby měly být
    reprodukovatelné z gitu, patří do `tools/gates/` (rozhodnutí uživatele).
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
    **DOPLNĚNO 7. session:** časový strop zatím **není potřeba pro velikost** —
    naměřeno v CI (běh #30): **53 mutací `mutace-tests.py` se vešlo do
    `timeout-minutes: 30`** i s krokem 9. Zbývá jen rozlišení „zasekla se" od
    „je pomalá" (věc zůstává otevřená).
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
59. ~~**NOVÉ (5. session): ŠEDÁ PLOCHA v místě změny výšky — chybí překlad land
    tile id → art id.**~~ — **VYŘEŠENO 12. session** (původní znění se nemaže):
    `world.map` vydává land **tile id**, ale atlas
    i `render.textures` pracují s **art id z pole `texture`** v tiledata; kde se
    liší, `texture()` vrátí `null`, `_draw()` udělá `continue` a vznikne **díra**
    (vidět jako šedé pozadí). Naměřeno v okolí `(1519,1657)`: chybí arty
    `{83:12, 95:12, 100:53, 84:1, 88:1, 96:1}`; v `tiles.json` mají 83/95/100
    `texture = 76`; atlas má **3 732 z 16 384** land artů (chybí 12 652).
    **`sim/world/tiledata.gd` neumí `texture`** — to je ta chybějící znalost.
    Detail, snímky a návrh: **`REVIZE-VADY-ZE-SNIMKU-2026-10-07.md` §Vada B**.
    **Jak to dopadlo (12. session, měřeno):** hypotéza z revize byla **obráceně** —
    správný klíč land artu je **land tile id**, ne TexID (důkazy: art index 0 je
    „UNUSED" a `texture[168] = 0`, barva `art[id]` sedí na texmap u 76 druhů vs.
    2 u `art[texture]`, ClassicUO `LandView.cs:96`). Atlas se **přegeneroval**
    (land 4 244, item 39 326, texmap 4 116) a **`world.tiledata.texture()`**
    (TexID) vznikl pro **texturu svahu** — bez ní zůstával po opravě atlasu
    v přechodu výšky stejně šedý pás ~140 px.
60. ~~**NOVÉ (5. session): „stopa" animačních framů při pohybu (vada A).**~~ —
    **VYŘEŠENO 12. session** (původní text se nemaže): uživatel vidí na snímku
    několik postav v různých fázích chůze. **Co to NENÍ (naměřeno):** animace
    v čase funguje (`0->f0 80->f1 160->f2 … 480->f6`)
    a reset při změně klíče taky; past je, že `play(1, …)` měří jinou věc —
    serial 1 není v registru, takže `body_of` vrátí `-1`.
    **Příčina (12. session):** `render.hue._obrazek()` bral u `AtlasTexture`
    **celý atlas** (stránka animace = všech 10 framů vedle sebe), takže `hued()`
    vracel texturu CELÉ STRÁNKY a `world_view._draw_player()` ji kreslil na
    pozici postavy. Opraveno na okno `region`; test v `tests/cases/render_hue.gd`
    (sekce 18) + 2 mutace. Barvení jednoho framu tím zrychlilo **8,7×**
    (35,7 → 4,1 ms).
61. ~~**NOVÉ (5. session): chybějící art se kreslí jako TICHO.**~~ — **VYŘEŠENO
    12. session** (původní text se nemaže): `render.textures` vrátí `null`
    a `world_view._draw` udělá `continue` — díra v mapě tedy nemá
    jak být vidět. Dnes se kreslí **magenta** placeholdr (diamant u landu, čtverec
    u statiku), `world_view.holes` je počítadlo a první výskyt každého art id se
    **hlásí** (`push_warning`); land id ≤ 2 (VOID/NODRAW) se nekreslí vůbec
    a počítá se jako `nodraw` (ClassicUO `Land.Create: AllowedToDraw = graphic > 2`).
62. **VYŘEŠENO 8. session — konvence dveří je opravená** (viz „CO JE NOVÉHO
    (8. session)" a `sim/world/doors.gd`: `toggle` = `art ± 1`, `is_open` =
    členství v `doors.txt`, 8 mutací to hlídá). **Znění, jak bylo otevřené
    6. session (záznam se nemaže):** `doors.gd` tvrdil (hlavička, „rozhodnuto
    obrázkem"): „kusy 1–4 = čtyři zavřené orientace, kusy 5–8 tytéž otevřené". **Naměřeno
    (nic z toho nebylo při rozhodování k dispozici):**
    (a) `assets/uo/tiles.json` má u artů 1717..1732 sloupec `layer` **po
    dvojicích**: `1717`/`1718` = `0`, `1719`/`1720` = `1`, … `1731`/`1732` = `7`;
    (b) RunUO/ServUO `Scripts/Items/Construction/Doors/Doors.cs` párují
    **sousední** arty: `closed = base + 2f`, `open = closed + 1`
    (MediumWoodDoor = 0x6B5: zavřené 1717/1719/1721/1723, otevřené 1718/1720/1722/1724);
    (c) **rozhodující úvaha:** celý blok 1717..1732 je **16 artů = 8 × 2**, tedy
    „8 hodnot `layer` krát dva arty". Osm hodnot odpovídá **4 směrům zdi × 2
    stranám pantu** a `doors.txt` uvádí z každé dvojice **jeden** art — takže
    **otevřené arty nemohou být „kusy 5–8"** (to je druhá strana pantu téhož
    zavřeného stavu). Otevřený stav musí být druhý člen dvojice (`+1`);
    (d) **nezávislý signál:** 4 arty ze 16 **nemají `Impassable`** (1714, 1730,
    1732, 1666) a **všechny čtyři jsou sudé** = „partneři +1" (otevřené dveře
    jsou ty průchozí); při náhodném stavu je to šance 1/16;
    (e) **DOPLNĚNO 7. session — model uživatele (2026-10-07):** „otevřené dveře
    nejsou jiné dveře, jen se křídlo pootočí o 90°, takže vizuálně neblokuje
    cestu; otevřené dveře jsou tytéž dveře z nového směru." **Konceptuálně to
    sedí** (pootočené křídlo leží podél kolmé osy, proto ta záměna) a je to
    lepší popis dat než „stav": dvojice je **tentýž (směr × pant) ve dvou
    kresbách**. **Co měření vyvrátilo:** že jde o **tutéž kresbu otočenou** —
    IoU siluety po izometrickém otočení `(sx,sy) → (−2·sy, sx/2)` je **0,05**
    (tj. žádná shoda; skript `.cache/analysis/dvere-rotace.py`). Jsou to **dva
    ručně kreslené sprity** (1997), ne otočený jeden.
    **(f) co měření NEŘEKLO (a je to past na metriku):** zrcadlová metrika je
    **nasycená** — IoU(zrcadlo(A), B) je **0,96–1,00** pro správné dvojice, ale
    **0,81 i pro dvojice nesprávné** a matice je plná 0,99 (1717 se „shoduje"
    s 1731, 1727 i 1718; skript `.cache/analysis/dvere-zrcadlo-matice.py`).
    **Tou metrikou se párování rozhodnout NEDÁ**; kdo ji použije samotnou,
    „potvrdí" si obojí.
    **(g) strukturní kontrola, která rozhoduje (a je levná):** `data/doors.json`
    má 230 artů a **ani jeden ze sudých osmi** z bloku 1717..1732 v něm není
    (`0 z 8`) — nejsou to tedy „zavřené dveře jiného směru", které by šlo někam
    postavit. Jediné, co se s nimi dá dělat, je druhá kresba téhož (směr × pant)
    = otevřeno.
    **Co z toho pro kód (návrh pro cíl 8):** `toggle(tile) = tile ± 1`;
    `is_open(tile)` = art je **sudý člen** dvojice; `is_door(tile)` ať platí
    **i pro pootočený art** (pootočené dveře jsou pořád dveře). Do hlavičky
    patří i to, co plyne z modelu uživatele: **dveře se vždy staví kresbou
    z `doors.txt`** (ta je „ve stěně"), a jen proto se dá stav poznat z artu.
    **⚠ CO SE Z TOHOTO NÁVRHU ZMĚNILO (8. session, měřeno):** `toggle = tile ± 1`
    a `is_door` pro oba členy platí; **ale `is_open` NENÍ „sudý člen dvojice"** —
    parita je jen vlastnost bloku 1717..1732 (16 z 37 kategorií má všechny kusy
    sudé). Správně je `is_open(t)` = „`t` není v `doors.txt`, ale `t - 1` je".
    **Dopad je dnes nulový** (v okolí startu 80×80 **není ani jeden statik
    dveří**) a `walk` je na konvenci nezávislý (ptá se `is_open`) — ale
    **Úkol 4 (`sim.interaction`) na tom stát bude** (a od 8. session stojí na
    správné konvenci).
    **Montáž pro nezávislou kontrolu pohledem** (gitignore):
    `.cache/analysis/dvere-par-pohled.png` + skripty `dvere-par-pohled.py`,
    `dvere-rotace.py`, `dvere-zrcadlo-matice.py`, `dvere-zrcadleni.py`,
    `dvere-orientace.py`, `sonda-dvere-schody.py`; **nově (8. session)**
    `_analyza/dvere-konvence.py` a `_analyza/dvere-jmena.py` (oba gitignore).
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

64. **NOVÉ (9. session): `entity.item` + `entity.container` NEMAJÍ VOJÁKA**
    (stejná past jako věc 40 `hued_art` a věc 54 `sim.pathfind`). Ze hry je
    nevolá **nic** — `G4` je hlásí jako „volá ho jen tests/" (acceptance `wiring`
    nežádá). Prvním volajícím má být **`sim.interaction`** (Úkol 4) a pak
    **inventář/UI**: `ui.backpack`, `ui.dragdrop`, `ui.tooltip` a uložení
    (`SimWorld.save` o předmětech neví). **Do té doby není hotová žádná hratelná
    mechanika předmětů** — jen měřená pravidla. Tvar obsahu je přitom vázaný
    na **jednu instanci** (`docs/04 §4.2.1`): kdo ji založí dvakrát, vyrobí
    duplikáty.
65. **NOVÉ (9. session): VÁHA PŘEDMĚTŮ JE `int` VE STONES A ZLATO VÁŽÍ 0.**
    Naměřeno: `assets/uo/tiles.json` má u zlata (`0x4EED`) váhu **0** a `docs/05
    §5.4` chce **0.02 stones**; ServUO to řeší **přebitím** (`Scripts/Items/
    Consumables/Gold.cs:34` → 0.02) a fallbackem pro 0/255 (`Server/Item.cs:3806`
    → 1), který u zlata neplatí, protože přebití je dřív. **Naše vrstva přebíjení
    nemá** (váha je z tiledata a je `int`), takže zlato i reagencie (váha 0)
    u nás neváží nic. **Rozhodnutí patří uživateli** (viz „Co čeká na tebe"):
    setiny stones (int), nebo vlastnost předmětu (`props`). Dnes je to
    **pojmenované omezení** v hlavičce `item.gd` a v `docs/04 §4.2.1`.
66. **NOVÉ (9. session): DVĚ VĚCI, KTERÉ `entity.container` VĚDOMĚ NEUMÍ**
    (obojí je v `docs/04 §4.2.1` i v hlavičce modulu): (a) **vnořené kontejnery
    se do váhy nepočítají** — ServUO `TotalWeight` je rekurzivní přes celý strom
    (`Container.cs:1755-1756`), my sčítáme jen přímý obsah; (b) **předchozí rodič
    „mobil" se neuklízí** (předmět nasazený na postavě, `mobile.equip`) — to musí
    dělat `entity.equipment`, až vznikne (jinak by `equip` a `add` mohly tvrdit
    obojí). Není to vada dnešního kódu, je to **hranice granule**.
67. **NOVÉ (9. session): `mutace-tests.py` MUTUJE PRVNÍ VÝSKYT VZORU.** Sonda
    `_analyza/mutace-vzory.py` u `mutace-tests` unikátnost jen **vypisuje**
    (na rozdíl od `mutace-render-anim.py`, který ji **vyžaduje**) — naměřeno:
    `movement/druhy krok v letu se neodmitne` je ve `sim/systems/movement.gd`
    **2×**, takže se mutuje první výskyt (dnes je to ten správný — mutace je
    chycená, ale je to **křehké**: přesun řádků v souboru by mohl měnit to, co
    se měří). Nové moduly `item`/`container` mají všech 20 vzorů **1×** (ověřeno);
    10. session přidala modul `interaction` (**13 vzorů, všechny 1×** — ověřeno
    skriptem před během, protože mutuje se první výskyt).
    Stálo by za to, aby sonda u `mutace-tests` **selhala** jako u `render-anim`.
68. **NOVÉ (10. session): `sim.interaction` JE HOTOVÝ, ALE NIKDO HO NEREGISTRUJE**
    (a je to táž past jako věc 64). Kód je měřený testem, ale:
    (a) **do hry se nepřidává** — `app/main.gd` registruje jen `movement` a `time`,
    takže `SimWorld.systems["interaction"]` neexistuje a `Command{t:"use"}` skončí
    v `sim/commands.gd` jako „Not available yet: use -> interaction.use.";
    (b) **předměty nemají registr podle serialu** (věc 64), takže `use` bere
    `items` **vstupem** (`{serial: Item}` nebo objekt s `get_item(serial)`) — kdo ho
    nezaloží, dostane u každého předmětu `unknown` a hlášku (což je pořád lepší než
    ticho, ale není to hratelné);
    (c) `entity.equipment`/`sim.vendor`/`sim.combat`/`sim.craft`/`sim.magic`/
    `sim.harvest` nejsou v `SimWorld.systems`, takže většina větví vrací
    `not_available` **záměrně a viditelně**.
    **Co s tím (návrh pro integrační session):** založit registr předmětů
    (a rozhodnout, kdo ho plní), zaregistrovat `interaction` v `app/main.gd`
    (a předat mu `world.doors`, kontejner, registr mobilů a ten item registr).
    **Integrační session to má jako vlastní cíl — ne „přilepené" k dnešní práci.**
69. **NOVÉ (10. session): `plan-status.py` UMÍ PŘIDAT „HOTOVÉ" ZA ZMÍNKU V CIZÍM TESTU.**
    Metrika je „soubor v gitu + **kmen názvu souboru** kdekoliv v textu `tests/`".
    Můj nový test používá slova `gump` (v `gump_open`) a `recipes_for`, takže
    **`assets.gump`** a **`data.recipes`** přeskočily mezi měřeně hotové — obě mají
    acceptance `content`/`schema`, což ten test neměří. Naměřeno diffem `--json`:
    s testem **47**, s testem dočasně mimo strom **45**; `přibylo do hotových:
    ['assets.gump', 'data.recipes']`. **Skutečná práce je z toho jedna**
    (`sim.interaction`, po commitu → **48**). Kdo hlásí „stav se zvedl", musí
    přírůstek rozdělit na *skutečně hotové* a *artefakty metriky* (past v `LESSONS`).
70. **NOVÉ (10. session): DVĚ DÍRY VE SMLOUVĚ, KTERÉ ODHALILA INTERAKCE**
    (obojí je zapsané v `docs/04 §4.2.1`):
    (a) **§4.4 nemá událost „art existujícího předmětu se změnil"** — přepnutí
    dveří posílá `item_added` se **stejným serialem** (obnovení u klienta); je to
    nejbližší existující událost, ne správná;
    (b) **seznam gumpů v §4.4 nemá `paperdoll`** (`craft|vendor|container|
    spellbook|skills`), přesto ho `context_action` na `0x0193` posílá.
    **Rozhodnutí patří uživateli** (rozšířit §4.4, nebo změnit kód) — do té doby
    je to v hlavičce modulu i ve smlouvě pojmenované, ne tiché.
71. **NOVÉ (10. session): VELIKOST `sim.interaction` JE 461 ŘÁDKŮ PROTI `<= 150`**
    (**3,1×**, třetí největší překročení v projektu — po `textdata.py` 5,1×
    a `gen-content.py` 4,4×). Drží to zadání „datová tabulka místo rozvětveného
    kódu" (9 větví §5.2.2 + 15 párů §5.2.3), ale **`owns` je jediný soubor**, takže
    se to nedá rozdělit bez porušení vlastnictví granule; rozhodnutí uživatele
    (věc 2) platí: **měřit, nepřepisovat**. Kdo plánuje `strong <= 150`, ať počítá
    s 250–450 řádky, když má granule víc metod a datové tabulky.

## Už není otevřené (přesunuto, nemaže se)

- **„Konvence dveří ve `world.doors` je podezřelá"** (věc 62 z 6. session) —
  **VYŘEŠENO 2026-10-07 (8. session)**: `doors.txt` dodává **zavřené** arty a
  otevřený je `art + 1`; `is_open`/`toggle`/`is_door`/`orientation` opravené,
  test měří oba členy dvojice na všech 230 artech, **8 mutací** to hlídá.
  Pozor: **přijímací kritérium věci 62 mělo vadu** („`is_open` = sudý art") —
  naměřeno a zapsáno v `LESSONS` (parita sleduje `base`, ne stav).

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
1. **Pushnout a zkontrolovat CI** na nových commitech — **10. session pushla
   sama** (trvalé povolení z 2026-10-07; HANDOFF to hlídá v „BLOKÁTORECH"
   a v „Předletové kontrole"). Po pushi čekej běh nad **svým** commitem
   a ověř **počet kroků** (`node _analyza/ci-beh-stav.mjs`; běh 8. session měl
   **17 kroků**) — **sha v odpovědi API rozhoduje**, ne „poslední běh".
2. ~~**Úkol 2 ze `ZADANI-DALSI-VYVOJ-2.md`: `sim.pathfind`**~~ — **HOTOVO
   2026-10-07 (5. session)**: `sim/world/pathfind.gd` + `tests/cases/pathfind.gd`
   + modul `pathfind` v `mutace-tests.py` (6/6). **Zbývá jen voják** (věc 54).
3. ~~**Úkol 3 ze `ZADANI-DALSI-VYVOJ-2.md`: dveře a schody ve `world.walk`**~~ —
   **HOTOVO 2026-10-07 (6. session)**: `world.doors.is_open`, výška schodů,
   výškové pásmo statiků **a oprava id prostoru statiků** (`+0x4000`).
   Testy `pathfind` (mají stub) zůstaly zelené ✓ — předpoklad z předání platil.
4. ~~**Rozhodnout konvenci dveří ve `world.doors`** (věc 62)~~ — **HOTOVO
   8. session**: `toggle(tile) = tile ± 1`, `is_open` = členství v `doors.txt`,
   `is_door` i pro otevřený art, hlavička nese měřené důkazy; test přepsaný,
   `--only doors` **8/8**. **Cestou se naměřilo, že kritérium věci 62 bylo
   v části „`is_open` = sudý art" vadné** (viz `LESSONS`).
5. ~~**Opravit slepé místo v `tests/run_tests.gd`**~~ — **HOTOVO 7. session**
   (rozhodnutí uživatele): `can_instantiate()` před `new()`, `script_at()`
   v `tests/lib.gd`, guard na „0 nových kontrol"; tři mutace to dokazují.
   Souhrn nově vypisuje `case souboru spusteno: N z M`.
6. ~~**`entity.item` + `entity.container`** (Úkol 6, první dvě granule)~~ —
   **HOTOVO 9. session**: **640/0** testů, **20/20** mutací, smlouvy v `docs/04
   §4.2`/`§4.2.1`/`§4.5`; detaily výš.
7. ~~**Úkol 4 ze `ZADANI-DALSI-VYVOJ-2.md`: `sim.interaction`**~~ — **HOTOVO
   10. session**: `use`/`use_on`/`context_menu`/`context_action`, routing z dat,
   parová tabulka §5.2.3 měřená proti dokumentu, dynamický routing s
   `not_available` místo ticha; **806/0** testů, **13/13** mutací, **`docs/04`
   §4.2/§4.2.1**. **Zbývá voják** (věc 68: registrace systému + registr předmětů).
8. ~~**Napojit registr na `sim.world_loop`** (věci 22, 48, 52)~~ — **částečně
   HOTOVO 4. session** (`sim.entity_registry` je hotový a zapojený do `movement`),
   **ale `snapshot().mobiles`, `state_hash` a `save` o mobilech i PŘEDMĚTECH pořád
   nevědí** (věc 64 + věc 68). **Pozor: kdo sáhne na `state_hash`, rozejde G9
   replaye** (pevné hashe v `tests/replays/` patří granuli `boot.tests`, agent je
   needituje) — takže tenhle krok potřebuje vlastní rozhodnutí a nové hashe.
9. **`entity.equipment`** (poslední granule Úkolu 6) — **tohle je cíl 11. session**
   (viz „CÍL SESSION“): obléknout postavu (ta je dnes nahá); navazuje na
   `entity.item` i `entity.container`, **musí uklidit předchozího rodiče „mobil“**
   (věc 66b) a **`sim.interaction` na něj čeká větví `equip`** (věc 68 — rozhodni,
   kudy ho najde). `render.hue` na to stroj má (věc 41) a `render.anim` už tělo
   z registru bere.
10. **Integrace `sim.interaction` do hry** (věc 68): registr předmětů + registrace
    v `app/main.gd` (`world.doors`, kontejner, registr mobilů, item registr) —
    **až po `entity.equipment`**, jinak by `use` na zbraň nemělo co volat.
11. **Voják pro `sim.pathfind`** (věc 54): click-to-move přes `sim.commands`
    (klik do světa → `next_step` → `Command{t:"move"}`), ať cesta není mrtvý kód.
12. **Statiky s barvou** (věc 40): `render.chunk` + `hued_art()` — dveře a cedule.
13. ~~**Držení klávesy = chůze** (`app.input`, věc 27, Úkol 7)~~ — **HOTOVO
    12. session**: drží klávesa i pravé tlačítko myši (`walk_to`), ověřeno
    v běhu hry (`_analyza/vlna7-drzeni.gd`) i testy (`tests/cases/input.gd`
    sekce 7/7b/8) + 6 mutací.
14. Pak M2 zbytek: `entity.notoriety`, `world.teleport`, `world.regions`.
15. (nepovinné) `if: always()` u diagnostických kroků CI (věc 26); časový strop
    v `mutace-tests.py` (věc 53) — **velikost už změřená**: 61 mutací se vešlo do
    `timeout-minutes: 30` (8. session), dnes **94**; zbývá rozlišení „zasekla se“
    od „je pomalá“. A **věc 67**: sonda `mutace-vzory.py` by měla u
    `mutace-tests` **selhat** na neunikátní vzor (dnes ho jen vypíše).

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
31. **NOVÉ (8. session): `docs/03 §3.6` popisoval strukturu `doors.txt` špatně**
    („zavřené/otevřené × 4 orientace") — **OPRAVENO 8. session** podle měření
    (8 zavřených artů, otevřený = `art + 1`) a je u toho datovaná oprava
    s důkazy. Zbývá jen to, co jsem **nemohl** ověřit z dat: u 4prvkových
    kategorií (15–23, 26–34) nejsou v `doors.txt` všech 8 slotů, takže
    „8 = 8 směrů" je doložené jen u kategorií s plnými 8 arty (a referencí
    `DoorFacing`, která má právě 8 hodnot).
32. **NOVÉ (8. session): cíl 8. session (v předání) měl v přijímacím kritériu
    větu „`is_open(tile)` = sudý člen dvojice", která je v rozporu s daty**
    (16 z 37 kategorií má všechny kusy sudé) — **nahrazeno měřeným pravidlem**;
    HANDOFF je přepsaný a důvod je v `LESSONS`. Do `docs/09` patří pravidlo:
    **kritérium se přeměřuje nad CELÝM souborem dat, ne nad blokem, ze kterého
    vzniklo.**
33. **NOVÉ (9. session): `docs/04 §4.5` u `Item` NEUVÁDĚL id prostor `tile`.**
    Kód i `docs/03` §3.4 („item id = art id") berou **art id** (0x4000–0xFFFF),
    ale `data/items.json` a `data/recipes.json` mají **tiledata id** (např.
    potion `8323` = `0x2083`) — kdo z nich předmět vyrobí, musí přičíst `+0x4000`
    (stejná past jako u statiků, 6. session). **Doplněno 9. session** do
    `docs/04 §4.5` i `§4.2`; **zbývá** rozhodnout, kde ten převod bude
    (`data.items`/`sim.craft`), až vzniknou — dnes ho nikdo nedělá, protože
    předměty nikdo nevyrábí (věc 64).
34. **NOVÉ (9. session): `docs/04 §4.2` u `entity.item` a `provides` v roadmapě
    si odporovaly.** Tabulka měla `durability`/`max_durability` a **neměla
    `quality`** (§4.5 ho má); roadmapa `provides` má `quality` a **nemá
    `max_durability`**. Kód má **obojí** (je to sjednocení §4.2 + §4.5)
    a `docs/04 §4.2` je doplněný — ale **roadmapa (`tools/roadmap-gen.py`) by se
    měla srovnat taky** (patří do plánu, ne do kódu).
35. **NOVÉ (9. session): kritérium vs `provides` u `entity.container`.** Zadání
    chce „přidání nad limit vrátí `{ok:false, reason:'full'}`", ale `provides` má
    `add(...)->bool`. Vyřešeno ve prospěch `provides` (`can_add` nese `{ok, reason}`,
    `add` vrací `false`) a zapsáno do `§4.2.1`; **text kritéria v roadmapě je
    ale pořád zavádějící** — patří opravit v `tools/roadmap-gen.py`.
36. **NOVÉ (9. session): `docs/05 §5.4` říká „zlato váží 0.02 stones", ale data
    mají 0 a nikde není, že je váha `int` ve stones.** Naměřeno:
    `assets/uo/tiles.json` (`0x4EED` → `weight 0`); reference to řeší přebitím
    (`Gold.cs:34` = 0.02) a fallbackem (`Item.cs:3806` = 0/255 → 1). **Hlásím,**
    `docs/05` agent needituje — rozhodnutí je v „Co čeká na tebe" a omezení je
    popsané v `docs/04 §4.2.1` i v hlavičce `item.gd`.

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
  **8. session:** `mutace-tests.py` dostal modul `doors` (8 mutací), v
  `tests/cases/walk.gd` je upravená sekce 8c (měřila starou konvenci dveří)
  a `docs/03 §3.6` + `docs/04 §4.2` + `docs/05 §5.2.2` + hlavička
  `sim/world/walk.gd` mají doplněnou měřenou konvenci — **cíl 8. session to
  výslovně žádal** (test i mutace jsou součástí kritéria).
  **9. session:** nové soubory `tests/cases/{item,container}.gd` (+ jejich `.uid`),
  `mutace-tests.py` dostal moduly `item` (5) a `container` (15), a **`docs/04
  §4.2` + `§4.2.1` + `§4.5`** mají změřený tvar obou granul — **cíl 9. session to
  výslovně žádal** („smlouvy v `docs/04 §4.2`/`§4.5` sedí na kód"). Jiné
  soubory v `docs/` se needitovaly (rozpory jsou ve „Vadách ZADÁNÍ").
  Nové `.gd` soubory potřebují **`--import` pod plným přístupem** (jinak `.uid`
  nevznikne — past 50); dnes jsou v commitu.
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
