# Rozhodnutí otevřených témat — 2026-10-08 (16. session)

> **Co je tenhle soubor:** **záznam o rozhodnutích**, ne stav a ne zadání.
> Vznikl tak, že uživatel 2026-10-08 zadal **„Pokračuj a témata čekající na mě
> rozhodni podle svého úsudku"** — rozhodovací pravomoc nad položkami sekce
> „Co čeká na tebe" v `HANDOFF.md` tím **přenesl na agenta**. Každé rozhodnutí
> tu má **důvod (naměřené číslo)** a **cestu zpět**; co rozhodnout nešlo
> (mazání, cizí služby, peníze, trvalá pravidla stanice), je označené.
> **Současný stav projektu je v `HANDOFF.md`** (ten se přepisuje celý); tohle
> je historie rozhodnutí — **nemaže se, jen doplňuje**.
> **Co je v něm už provedené, je u položky napsané** (`PROVEDENO` / `ODLOŽENO`).

---

## 1. Rozhodnutí, která měnila chování hry (provedená)

| # | Téma | Rozhodnutí | Důvod (měření) | Cesta zpět |
|---|---|---|---|---|
| R1 | **AoS vs. „učit se z chyb"** (`era.skill_gain`) | **`pre-aos`** — neúspěch přispívá do šance na růst **0,2** (dřív AoS: `0.0`) — **PROVEDENO** (`data/balance.json` `era.skill_gain`, `app/config.gd` SCHEMA, `sim/systems/skill_gain.gd` `_failure_weight`; testy + mutace) | Uživatel 11. session zvolil řemeslo jako „BIG WIN č. 1" a u něj jde o pocit z výzvy; `SkillCheck.cs:295` má obě větve (`Core.AOS ? 0.0 : 0.2`); `combat`/`loot`/`content` zůstávají **AoS** (míchá se jen jedna položka, ne éra celku) | Jeden klíč `era.skill_gain` v `data/balance.json` (`aos` = původní chování). Kód i test to měří |
| R2 | **Barva pozadí světa („void") je šedá `77,77,77`** | **Tmavá `0,0,0`** — nastavuje se **z kódu** (`RenderingServer.set_default_clear_color` v `app/main.gd`) — **PROVEDENO** | V UO je pozadí tmavé (docs/01 V4); `project.godot` je **bootstrap granule** a agenti do něj nesmí (docs/09 §9.2) — z kódu je efekt stejný a bootstrap zůstává nedotčený. Uživatel může tentýž efekt přenést do `project.godot` jedním řádkem (`rendering/environment/defaults/default_clear_color=Color(0,0,0,1)`), ale **nemusí**: kód dělá totéž | Smazat jeden řádek v `app/main.gd` |
| R15 | **Směr projektu** (singleplayer / cizí shardy / vlastní server) | **(a) singleplayer teď, (c) vlastní server jako držená opce, (b) custom klient na cizí shardy jako samostatný produkt** | Analýza s čísly je v `REVIZE-SMER-2026-10-07.md`; pět ze šesti oprav pohybu má cenu ve všech třech variantách, takže práce na klonu není vsazená | Rozhodnutí neblokuje nic; mění se, až uživatel zvolí jinak |

## 2. Rozhodnutí o dokumentech a datech (provedená)

| # | Téma | Rozhodnutí | Důvod (měření) | Cesta zpět |
|---|---|---|---|---|
| R3 | **`docs/06 §6.1` tvrdilo 1150 receptů, data mají 1053** | **Dokument opraven na naměřených 1053** — a 97 chybějících je **pojmenováno i s cestou, jak je dostat** — **PROVEDENO** (`docs/06 §6.1`, `docs/06 §6.3`, `docs/05 §5.8`) | Naměřeno `data/recipes.json` = **1053** (Alchemy 51, Blacksmithy 196, BowFletching 27, Carpentry 223, Cartography 8, Cooking 88, Glassblowing 22, Inscription **16**, Masonry 59, Tailoring 198, Tinkering 165; součet 1053). Rozdíl 97 = **svitky kouzel** (64 Magery + 17 Necromancy + 16 Mysticism), které `research/04-gathering-crafting.md` **§5.5 má — ale jen jako markdown tabulky**; `research/04-craft-data.json` je neobsahuje a generátor čte jen ten. **Cesta k 1150 tedy existuje** (převést §5.5 na data a rozšířit generátor), ale „dopsat číslo" jí není | Až generátor svitky vyrobí, počet se **změří**, ne odhadne. `tests/cases/recipes.gd` drží `id` bez děr, takže se přidávají na konec |
| R4 | **`ZADANI-DALSI-VYVOJ-2.md §5 „Otázky k rozhodnutí"** (4 body) | **Uzavřeno** — všechny čtyři jsou zodpovězené (1. éra = AoS, 11. session; 2. světlo = naměřeno, 11. session; 3. zvuk = vlastní trať, 11. session; 4. `ui.hotkeys` vs `app.input` = smí, držení hotové 12. session) | Každý bod má v `HANDOFF.md` vlastní záznam „VYŘEŠENO" s dokladem; v zadání zůstávají jako **záznam o zadání** (nepřepisuje se) | — |

## 3. Rozhodnutí „nedělat teď" (odložená s cílem a důvodem)

| # | Téma | Rozhodnutí | Důvod | Kdy se k tomu vrátit |
|---|---|---|---|---|
| R5 | **M9 4a: první frame hry stojí ~2 008 ms** (načtení 34 atlasových stránek 2048² z disku; mesh přidá ~50 ms) | **Odloženo jako samostatné téma** — není to vada M9 (stejnou cenu platí původní cesta ve svém prvním `_draw`) | Oprava má tři různé tvary (načítat při startu s progress barem / menší stránky / držet `Image` místo `ImageTexture`) a každý mění **jiné** granule (`render.textures`, `tools/uoextract/atlas.py`, `app.menu`); udělat ji „mimochodem" by znamenalo neměřit ji | Samostatná session s cílem: **první vykreslený frame < 300 ms** a plný atlas; měřeno `_analyza/m9-vykon-po.gd` (stejná sonda jako dnes) |
| R6 | **M9 4b: přestavba dávky 53,8 ms každé 4 kroky chůze** (max frame 149,8 ms) — dnes **největší zásek hry** | **Odloženo na nejbližší session** (je to nejcitelnější vada, kterou uživatel 12. session hlásil jako „sekání") | Oprava je zásah do `render/chunk_mesh.gd` (hotová granule M9) a **pravidlo M9 platí i pro ni**: nesmí ubrat měření → musí zůstat zelený **paritní test obrazu** a přibýt časový důkaz. To je plnohodnotný cíl, ne „mimochodem" | Cíl: **žádný frame > 8 ms při souvislé chůzi** (dnes max 149,8 ms), parita obrazu beze změny hashů; vzor: stavět dávku po částech (time-sliced) nebo znovupoužít geometrii mezi přestavbami (`split` je 0,66 ms) |
| R7 | **M9 4c: nový art je vidět o 2 framy později; mesh neorezává podle kamery** (posílá 15 838 primitiv místo 9 310) | **První část přijata jako vědomé omezení** (`hold()` ji řeší), **druhá (ořez) zůstává jako levné vylepšení v plánu** | Ořez je měřitelná úspora práce GPU a riziko je malé (drift pohledu ±4 dlaždice); dvouframové zpoždění je vlastnost `SubViewport` + `UPDATE_ONCE`, ne vada | Až bude R6 hotové (obojí sahá do téhož souboru, ať se neměří dvakrát) |
| R8 | **M9 4d: `app.config` se ptají jen `app.main` a testy**; `sim.movement` a `sim.skill_gain` čtou `data/balance.json` samy | **Zůstává to tak.** Vrstvy se nemění | Přesun `app.config` do `core/` by byl zásah do **hotové** granule a do `owns` v `.forge/roadmap.json`; `sim/` dnes čte `data/balance.json` **měřeným precedensem** (`skill_gain.gd`) a `sim/` nesmí volat `app/` (docs/04 §4.1) — což je přesně to, co drží `check-layers` zelené | Až vznikne **třetí** konzument nebo potřeba **validovat** hodnoty i z `sim/`, založit novou granuli `core.config` (aditivně, `app.config` zůstane) |
| R9 | **Váha předmětů v setinách stones** (zlato `0,02`; dnes `int` stones → zlato 0) | **Zůstává `int` stones.** Přesnost na setiny se nezavádí | Změna jednotky je zásah do `core/const.gd`, `world.tiledata`, `entity.container`, `docs/05 §5.4` a testů; **dokud není nosnost/obtížení**, nemá co měřit. `docs/05 §5.4` i hlavička `sim/entity/item.gd` to vedou jako **vědomé omezení** (ne jako nevědomost) | Až přijde banka/obtížení (M3+): jednotka `int` v setinách + přepočet `CONTAINER_MAX_WEIGHT`; do té doby se zlato chová jako 0 stones |
| R10 | **Svahy se kreslí bez osvětlení rohů** (ClassicUO `CalculateNormal`) | **Odloženo na `render.light`** (M9+), ne na tuhle session | Svah je dnes rovnoměrně barevný `draw_polygon`; osvětlení patří k světelné vrstvě, která ještě neexistuje. Zapsané v kódu i v `docs/03` | Zadání `render.light` musí obsahovat `CalculateNormal` (`Land.cs`) a měřitelný rozdíl na snímku (stínování svahu), ne dojem |
| R11 | **Brány na chování v čase i v CI?** (`REVIZE-POHYB §5`) | **Ano pro část bez assetů** (kadence a rozestup kroků, pravidla chůze na fixture mapě), **ne pro vizuální část** (snímek zůstává lokální sonda) | CI neobsahuje `assets/uo`, takže sonda nad reálnou mapou by v CI hlásila `NEMĚŘENO` — zelená nad prázdnem je přesně to, co docs/08 §8.6 zakazuje | Až se R6 dodělá: kadence kroků patří do `tests/cases/movement.gd` (deterministicky, bez assetů), časový důkaz zůstane v `_analyza/` |
| R12 | **`sim.enhance`** (zpackaná dýka) | **Až po `sim.craft`** — samostatný cíl | Nejdřív musí řemeslo fungovat (16. session); `enhance` je druhá vrstva nad ním (`Enhance.cs:303-326`) | Session po dokončení `sim.craft` |
| R13 | **Směr projektu: singleplayer / cizí shardy / vlastní server** | **(a) singleplayer teď, (c) vlastní server jako držená opce, (b) custom klient na cizí shardy jako samostatný produkt** | Analýza s čísly je v `REVIZE-SMER-2026-10-07.md`; pět ze šesti oprav pohybu má cenu ve všech třech variantách, takže práce na klonu není vsazená | Rozhodnutí neblokuje nic; mění se, až uživatel zvolí jinak |
| R14 | **Nová měřená zjištění 14. session** (`z + výška/2` na schodu s flagem `Bridge`; `GetAverageZ` u osamocené dlaždice = 0; sondy z 13. session měřily opis pravidla) | **Přijato jako vlastnosti reference, nic se nemění** | Všechno tři jsou **měřené** (`tests/cases/walk.gd` 1c, `TileData.cs:112-125`) a `walk` je hotová granule; kdo z nich bude citovat, musí říct, která reference to je | Kdo dělá `render.anim` vrstvy nebo souboj, počítá s `z + výška/2` |

## 4. Co z rozhodnutí plyne pro plán

- **Do cíle 16. session patří** (a je v něm): `sim.harvest`, `sim.craft`,
  `ui.journal` — řemeslo je odblokované (`sim.skill_gain` i `data.recipes`
  hotové) a R1 mu dává „růst i při neúspěchu" **měřený**, ne tvrzený.
- **Nejbližší další cíl (17. session), podle R5/R6:** nejdřív **R6** (zásek
  53,8 ms → cíl „žádný frame > 8 ms"), protože je to nejcitelnější vada
  a uživatel si na ni stěžoval; **R5** (první frame < 300 ms) hned po něm,
  obojí se měří stejnou sondou `_analyza/m9-vykon-po.gd`.
- **Nic z rozhodnutí nezměnilo trvalá pravidla stanice** (`~/.dsh/AGENTS.md`)
  ani `docs/01`–`docs/11` kromě R3 (oprava jednoho čísla v `docs/06`) a R1
  (nový klíč v `data/balance.json` + jeho zdroj v `sources`).

## 5. Co zůstává na uživateli

**Nic neblokuje práci.** Jediné dvě věci jsou **nepovinné** a agent je nemůže
udělat sám (jsou to cizí/publikované výstupy):

1. **Přenést barvu pozadí do `project.godot`** (R2) — `project.godot` je
   bootstrap granule a jeho změna patří uživateli. **Není to potřeba**: kód
   dělá totéž. Když to uživatel udělá, řádek v `app/main.gd` se smí smazat.
2. **Změnit trvalá pravidla stanice** (`~/.dsh/AGENTS.md`) — pokud by chtěl
   některé rozhodnutí výš povýšit na pravidlo (např. „váha v setinách až
   s nosností"). Dnes to pravidlo **není** a nikde se to netvrdí.
