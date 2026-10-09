# Vizuální parita s originálem — naměřené nálezy a návrh revize (2026-10-09)

> **Co je tenhle dokument:** **ANALÝZA + NÁVRH** (snapshot měření k 2026-10-09
> + plán revize). **Není to stav projektu** — současný stav se bere z
> `HANDOFF.md`, smlouvy z `docs/`. **Datum spotřeby: zatím žádné** — nic z
> návrhové části (§5–§7) se neprovádělo; fáze 0 (§4) provedená JE a je u ní
> zapsáno, co z ní platí.
>
> Vznikl v session, kterou uživatel 2026-10-09 požádal o **revizi toho, jak
> původní hra fungovala vizuálně, a jak to děláme my** („dávalo by smysl pustit
> tě s maximálním výkonem na revizi… dokončit celý vizuál jak nejlépe lze?").
> Session při tom naměřila příčiny 3 z 10 hlášených vad a opravila je.

---

## 1. Na co tenhle dokument odpovídá

Uživatel předal **10 pozorování ze hry** (stamina, animace běhu, zoom, okno,
kovárna/roh hradu přes vodu, voda v lese, chybějící debug info, zeď z podkroví,
2 záseky z ~2300 framů na ~130 ms, občasné probliknutí) a zeptal se, jestli dává
smysl pustit agenta na **revizi vizuálu podle originálu**.

**Krátká odpověď: ano — ale jako PARITNÍ REVIZI PODLE REFERENCE, ne jako
„udělat celý vizuál".** Důvod je měřený (§2): 8 z 10 pozorování nejsou
samostatné vady, ale **instance jedné třídy** — *pravidlo jsme uhodli, místo
abychom ho odvodili z originálu*. Reference přitom leží lokálně v `_src/`
(ClassicUO = klient, ServUO/RunUO = server) a je to **BSD kód, který se dá
citovat na řádek**.

---

## 2. Naměřené nálezy (co už víme — s postupem, ne dojmem)

### 2.1 Animace běhu neexistuje (UŽ OPRAVENO, §4.1)

| Co | Jak je to naměřené |
|---|---|
| Příčina | Číslo akce se bralo jako **číslo skupiny v `anim.mul`**. U člověka je ale `0 = WalkUnarmed, 1 = WalkArmed, 2 = RunUnarmed, 3 = RunArmed` — `_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs:1721` (`PeopleAnimationGroup`). „0 = walk, 1 = run" platí jen pro zvířata a monstra. |
| Doklad pohledem | `_analyza/p25-groups-montaz.py` → `_analyza/p25-groups-400-2.png`: skupiny 2 a 3 mají předklon a pokrčené paže (běh), 0 a 1 jsou chůze. |
| Doklad číslem | `_analyza/p25-walk-run.py`: dvojice (0,1) se liší na 25–35 % pixelů, (2,3) je jiný art; první frame skupiny 2 je 50×55 px, skupiny 0/1 40×58 px. |
| Doklad živě | `_analyza/p25-run-sprite.gd`: akce 1 → skupina 2, textura 44×57 px; akce 0 → skupina 0, 32×61 px. |

### 2.2 Stamina (UŽ OPRAVENO, §4.2)

| Co | Jak je to naměřené |
|---|---|
| Příčina tichého chování | `data/balance.json` mohl mít `never`, ale `sim.movement` znal jen `run_only`/`emulator` → **neznámá hodnota se chovala jako `run_only`** a stamina ubývala dál. |
| Jak to má originál | Běh sám staminu **nebere**; spotřebu váže až **přetížení**: `loss = 5 + overWeight / 25`, při běhu ×2, na mountu /3 — `_src/servuo/Scripts/Misc/WeightOverloading.cs:111`. Nepřetížená postava neztrací za krok **nic**. Regenerace je **1 bod za interval** (AoS bez bonusu ~5 s, default 7 s) — `_src/servuo/Server/Mobile.cs:1968-1976`. Práh „běžet jen když `Stam > 1`" je **klientský** (`PlayerMobile.cs:532`), ne serverový. |
| Co u nás chybí | `sim.regen` (doplnění staminy) **neexistuje** → každý ubranný bod byl nevratný. To je skutečná příčina uživatelova dojmu. |

### 2.3 Zoom rozhodí, kde hra „vidí" postavu (NEOpraveno, změřeno)

| Co | Jak je to naměřené |
|---|---|
| Symptom uživatele | „oddálení zvětšilo viditelné pole, ale středový bod zůstal ve stejném rozměru" |
| Měření | Debug overlay při zoomu 0,75 a okně 1280×720: **`pick=(426,280)`**, ale postava stojí na **(480,300)** (`_analyza/p25-overlay-run.png`). Chyba roste se vzdáleností od středu okna. |
| Příčina | `app/player_controller._camera_offset()` vrací `camera.position - viewport/2` (světové pixely) a `app/input_map.click_at`/`interact_command`/`center_for`/`mouse_run` z toho počítají `world = screen + offset` — **míchá obrazovkové a světové pixely a zoom nezohledňuje vůbec**. |
| Jak to má originál | Zoom jde na **celou matici světa** (`_src/classicuo/src/ClassicUO.Renderer/Camera.cs:162-184`, zoom je převrácený `1f/Zoom`) a vstup se převádí **zpět touž maticí** (`Camera.ScreenToWorld`, `:88-103`). UI se nezoomuje. |

### 2.4 Zeď z podkroví, střechy a „krok stranou" = Z-pásma (NEOpraveno, pravidla známe)

| Pravidlo originálu | Citace |
|---|---|
| Z-pásma vůči hráči | `playerZ + 14` a `playerZ + 16` (`GameSceneDrawingSorting.cs:87-88`); statik nad hlavou se zahodí podle `maxObjectZ > maxZ` (`:564-568`) |
| Absolutní stropy | sken do `Z = 150` (`GameScene.cs:669`), kreslení do `_maxGroundZ` (default 127, jindy `pz16`) — `RenderLists.cs:274` |
| Střecha se **nevyhazuje, ale faduje na alfu 0** | `GameSceneDrawingSorting.cs:176-187` a `:357-368`; párování podle Z s tolerancí ±6 (`Map.cs:192`) |
| Řazení do hloubky | `(x + y) + (127 + PriorityZ) * 0.01` (`Views/View.cs:83`), vrstvy jsou **pevné seznamy** (land → statiky → animace → efekty → průhledné), uvnitř rozhoduje depth buffer (`RenderLists.cs:183-191`) |

**To je odpověď na „kousek zdi z vyšší úrovně se zobrazuje, ale krok stranou
ne":** v originálu je to **hranice Z-pásma ±14/16 vůči hráči**, ne náhoda.
Náš `render.sort` (klíč) a `render.chunk_renderer` (střechy) tuhle hranici
aproximují — a dokud ji nebudou mít stejnou, bude se to „chovat divně jednou
za pár kroků".

### 2.5 Voda a statiky (kovárna, roh hradu, voda v lese) — NEMĚŘENO

Zatím **nevíme**, jestli je to naše vada, nebo vlastnost původní mapy: nemáme
souřadnice z uživatelových snímků. **Overlay to řeší** (§4.3) — od teď je
lokace na každém snímku. Postup, až souřadnice budou: přečíst buňku mapy
(`sim.world.map.land_at/z_at/statics_at`), `world.tiledata` (flagy, výška,
vrstva) a porovnat s pravidly §2.4 — pak je to buď naše vada (opravit), nebo
data originálu (zapsat jako *neškodné, ale matoucí*, ne „opravit").

### 2.6 Záseky a probliknutí — částečně naměřeno dřív, zbývá jedna cesta

`2 framy z ~2300 na ~130 ms` je **stav po R6** (18. session srazila 6 → 2);
známá zbývající příčina je **překreslení runtime atlasu na GPU** (zapsáno
v commitu `76d603a`). Overlay nyní ukazuje **špičku frame času** (`peak`),
kterou klouzavý průměr v `app.metrics` schovává — tím se dá zachytit
i „probliknutí" (1–2 framy) na snímku.

---

## 3. Co z toho plyne pro způsob práce (jádro odpovědi)

1. **Nemáme „málo informací", máme neodvozená pravidla.** Reference je lokálně,
   je citovatelná a je to klient, který hra opravdu byl.
2. **Každá vizuální změna se dá měřit dvakrát:** číslem (parita pixelů, frame
   čas, počet objektů, klíč řazení) a **pohledem** (`read_image` nad snímkem).
   Obojí projekt už umí (`tools/gates/check-render.py` G10, `_analyza/p22-sbs-*`).
3. **„Dokončit celý vizuál" je neměřitelný cíl.** Měřitelné je: *„pravidlo R
   z reference platí i u nás a je doložené snímkem + číslem"*. Proto návrh níž
   není „udělat vizuál", ale **seznam pravidel, která se mají srovnat**.

---

## 4. FÁZE 0 — co je hotové (commit `d858c8c`, 2026-10-09)

| # | Co | Doklad |
|---|---|---|
| 4.1 | **Běh má vlastní animaci**: export `tools/uoextract/anim.py --actions "0:walk,2:run,4:idle"`, klient má tabulku `render/anim_player.ACTION_GROUP` (abstraktní id 1 → skupina 2), `sim.movement.ACTION_RUN` zůstává 1 (spec test na něm stojí) | `_analyza/p25-run-sprite.gd` (živě), `_analyza/p25-hrac-srovnani.png` (pohledem: vlevo chůze, vpravo běh) |
| 4.2 | **Stamina vypnuta** (`stamina_drain_model: "never"`), všechny 4 modely implementované a testované | `tests/cases/stamina_model.gd` (nový), `tests/cases/balance.gd` (⚠ změna specu — viz §8) |
| 4.3 | **Debug overlay** (`F3`): lokace, zoom, stav, animace, fps + **špička frame času**; viditelný od startu, aby ho zachytil screenshot; `MOUSE_FILTER_IGNORE`, aby nepřekryl klikání | `ui/debug_overlay.gd` + `tests/cases/debug_overlay.gd`; snímky `_analyza/p25-overlay-walk.png` / `-run.png` |
| 4.4 | Testy **1372 → 1385 kontrol / 0 selhání**; brány `tools/gates/run-all.py` **11 měřeno / 0 chyb**; push ověřen (`origin/main = d858c8c`) | výstupy běhů |

**Co z fáze 0 platí dál:** 4.1–4.3 je v kódu a v gitu; nic z toho se nepočítá
jako „měření, které zestárne" (změny, ne analýza).

---

## 5. FÁZE 1 — „ať jde vady vůbec hlásit" (návrh, odhadem 1 session)

Pořadí je dané tím, co blokuje uživatelovo hlášení:

| # | Práce | Měřené zadání (co musí vyjít) |
|---|---|---|
| ~~5.1~~ | ~~**Zoom: jeden převodní pár `svět ↔ obrazovka`**~~ **HOTOVO 2026-10-09** — viz §5.1 níže | `pick` == skutečný střed postavy pro zoom 0,5 / 0,75 / 1,0 / 1,5 / 2,0 (naměřeno **0,00 px**) |
| ~~5.2~~ | ~~**Rozhled oknem, ne zoomem < 1**~~ **HOTOVO 2026-10-09** — viz §5.2 níže | `viewport == okno`, svět = okno − pás; fullsize = celé okno |
| ~~5.3~~ | ~~**Z-pásma podle hráče** (`playerZ ± 14/16`, strop 150)~~ **HOTOVO 2026-10-09** — viz §5.3 níže | rozdíl proti referenci **0** na 1369 místech; strop 150 měřeně 0 objektů |
| ~~5.4~~ | ~~**Střechy/patro: fade na alfu 0** místo vyhození~~ **HOTOVO 2026-10-09** — viz §5.4 níže | snímek v průběhu fade (`_analyza/p28-fade-5f.png`); frame časy během fade 20–25 ms |
| 5.5 | **Záseky**: dokončit cestu „runtime atlas bez překreslení na GPU" (známá z R6) | 2 → 0 framů > 33 ms z 2300; `peak` v overlayi |

### 5.1 HOTOVO (2026-10-09, commit `f606511`)

**Co bylo špatně:** převod obrazovka → svět se dělal jako `world = screen +
camera_offset`, což platí **jen při zoomu 1,0**; `camera_offset` navíc neznal
zoom. Při zoomu ≠ 1 má obrazový pixel jinou velikost než světový, takže klik,
obecná interakce, směr z myši i prah běhu mířily vedle — a chyba rostla se
vzdáleností od středu okna (přesně to uživatel popsal).

**Co je teď:** jedna dvojice `world_to_screen`/`screen_to_world` v
`app/world_view.gd` (kamera + zoom + viewport na jednom místě), jedno místo
převodu v `app/input_map._na_svet` (používá je klik i interakce), `mouse_run`
měří od **hráče** (prah 190 px z reference), záložní `player_screen_position`
se násobí zoomem.

| Důkaz | Číslo |
|---|---|
| Živá sonda `_analyza/p26-zoom-vstup.gd` (oracle = Godot `Camera2D.get_canvas_transform()`, tedy matice, kterou engine opravdu kreslí) | odchylka klient vs. engine **0,00 px** při zoomu 1,0 / 0,75 / 0,5 / 1,5 / 2,0; klik na obrazové místo východní dlaždice dal **vždy dir 0 (východ)** |
| Kolik byla vada | tyž klik starou matematikou: zoom 0,75 → dlaždice (1490, 1631) = **směr 5 (jihozápad)**, zoom 0,5 → taky JZ, zoom 1,5/2,0 → **směr 1 (severovýchod)** |
| Overlay (snímek `_analyza/p25-overlay-walk.png`) | `pick=(426,280)` → **`pick=(480,300)`** = přesný střed viditelného světa |
| Test `tests/cases/zoom_prevod.gd` (nový, 19 kontrol) | round-trip 80 dlaždic × 5 zoomů: **0 chyb**; interakce na touž dlaždici; prah 189/190 px od hráče; záložní střed |
| Mutační důkaz | vrácení vady do `_na_svet` (bez dělení zoomem) → **52 z 80** dlaždic vedle při zoomu 0,75, **64 z 80** při 0,5, 32 z 80 při 1,5 a 2,0; při zoomu 1,0 se neprojeví (proto vada přežila 19. session) |
| Testy / brány | **1385 → 1404 kontrol / 0 selhání**; `tools/gates/run-all.py` **11 měřeno / 0 chyb** |

**⚠ Změna ve spec testu (druhá v této práci, na schválení uživatele 2026-10-09):**
`tests/cases/input.gd` v bloku 8 dodává `player_screen` (pozici hráče), protože
`poll` od 2026-10-09 měří prah běhu **od hráče**, ne od středu okna — starý test
pinoval měření od středu okna (což byla ta vada). Měření od středu okna zůstává
pokryté jako záložní cesta v `zoom_prevod.gd`.

### 5.2 HOTOVO (2026-10-09, `app/window.gd` + `project.godot`)

**Co bylo špatně:** geometrie okna se počítala **jednou** v `app/main._setup_ui()`
a `project.godot` držel plátno napevno (`canvas_items` + `integer`), takže větší
okno nepřidalo ani dlaždici.

| Co | PŘED (okno 1600×900) | PO (okno 1600×900) | PO (fullsize, F2) |
|---|---|---|---|
| viewport (plátno) | 1280×720 | **1600×900** | 1600×900 |
| viditelný svět | 960×600 | **1280×780** | **1600×900** |
| kreslená plocha (a/b dlaždic) | 78×44 | **97×55** | 97×55 |
| černý pás | (320, 120) | (320, 120) | **(0, 0)** |
| `pick` (střed hráče) | (426,280) — vada 5.1 | **(640,390)** | **(799,450)** |

**Co je teď:** `app/window.gd` (granule `app.window`) je **jedno místo** pro
geometrii — čisté funkce (`pas`, `svet_obal`, `stred_sveta`, `pozice_oken`),
takže se dají měřit bez okna. `app/main._prepocitej_geometrii()` z nich staví
uzly a volá se při startu, **při každé změně velikosti okna**
(`Viewport.size_changed`) a při přepnutí fullsize. `project.godot` má
`stretch/mode="disabled"` (plátno = okno, obraz 1:1 bez převzorkování),
výchozí okno 1600×900; `F2` přepíná fullsize (svět = celé okno, pás zmizí) —
vzor `_src/classicuo/.../OptionsGump.cs:4113-4133`.

| Důkaz | Číslo |
|---|---|
| Živá sonda `_analyza/p26-okno.gd` (okno 1600×900 i 1280×720, s pásem i fullsize) | `viewport == okno` v obou případech; `svet = okno − pás`; ve fullsize `pás = (0,0)` a oba pásy **neviditelné**; **0 chyb** |
| Snímky pro oko | `_analyza/p26-okno-pas-1600x900.png` (svět 1280×780 + pás vpravo/dole) a `_analyza/p26-okno-fullsize-1600x900.png` (svět přes celé okno, stavový řádek a žurnál plavou nad světem) |
| Nový test `tests/cases/window.gd` (17 kontrol) | svět pro dva různé rozměry se liší **přesně o rozdíl okna**; fullsize; malé okno nedá záporný svět; střed světa; okna HUDu uvnitř okna; `world_view.nastav_gui_odsazeni` posune kameru o `pás/zoom` a **vynutí přestavbu seznamu** (jinak by po zvětšení okna zůstaly u okrajů díry) |
| Mutační důkaz (2 mutace) | (a) fullsize se ignoruje → **3 selhání**; (b) svět se počítá z pevného okna 1280×720 → **6 selhání** |
| ⚠ Nález o měřidle | první pokus o mutaci (b) jsem zavedl do `pas()` — a **test nic nehlásil**, protože šířka pásu na velikosti okna nezávisí (jen se ořezává). Mutace, která se tiše neprojeví, tvrdí totéž co mutace, která projde; správné místo je `svet_obal()` |
| Testy / brány | **1404 → 1422 kontrol / 0 selhání**; `run-all.py` **11 měřeno / 0 chyb** (G10 dál fotí snímek při `--resolution 1280x720`, takže mu změna výchozího okna nevadí) |

**Co zůstává (pojmenované):** tažení rámu myší za okraj (reference
`WorldViewportGump.cs:128-150`) se nedělá — velikost rámu se mění **velikostí
okna**; `fullsize` je klávesa, ne gump s tlačítkem. Rozložení oken HUDu ve
fullsize (stavový řádek u spodní hrany, žurnál vpravo nahoře) je **rozhodnutí
o rozložení**, ne pravidlo z reference — je tak popsané v `app/window.gd`.

**Cena, kterou je fér říct (pro 5.2–5.5):** 5.2 je zásah do `project.godot`,
`app/main.gd` (geometrie se dnes počítá jednou) a `ui/hud.gd` (pozice oken) —
odhadem 1 session; 5.3/5.4 jsou změny v `render/` s paritní branou, také
~1 session. Nic z toho se nezačalo.

### 5.3 HOTOVO (2026-10-09, `render/chunk_renderer.gd`)

**Co se měřilo:** uživatelovo pozorování č. 8 („zobrazuje se i kousek zdi
z vyšší úrovně, ale ne stále — krok nebo dva stranou už ne"). Sonda
`_analyza/p27-patra-sonda.gd` proskenovala **1369 dlaždic** okolo Britainu
(±18 od 1495,1630) a pro každou spočítala náš strop patra a **strop podle
reference** (vlastní přepis `Map.CalculateNearZ` jako druhý názor).

| Nález | Číslo |
|---|---|
| Míst s kandidátem na strop (střecha na dlaždici hráče nebo na (x+1,y+1)) | **85 z 1369** |
| **Odchylka od reference:** my brali `z` NALEZENÉ střechy (hřeben), reference `Map.CalculateNearZ` = **nejnižší `z` souvislé střechy (okap)** (`Map.cs:164-219`, tolerance ±6 na krok) — náš strop vyšel až o **9 jednotek výš** (49 místo 40 na 1477,1612) | opraveno: `near_z()` je doslovný přepis (iterativně, mřížka 64×64 jako reference, pojistka 20 000 dlaždic + počítadla `near_z_kroku`/`near_z_limit`) |
| Po opravě: rozdíl náš vs. referenční strop | **0 na všech 1369 místech** |
| ⚠ **Viditelný dopad v Británii: 0 objektů** — v pásu `[okap, hřeben)` na těch 85 místech nebyl ani jeden kreslený objekt. Oprava je tedy věrnost pravidla, ne viditelná změna na tom místě | naměřeno, ne zamlčeno |
| Strop **150** (`GameScene.cs:669`, `AddTileToRenderList(..., 150, ...)`) — náš kód ho nemá | objektů s horní hranou (`z + výška`) nad 150 v seznamu: **0** (mapa má `Z ≤ 127`, `core/const.gd`), takže chybějící strop je měřeně bez dopadu |
| **Cache** (`strop_patra` podle pozice hráče) | reference počítá `UpdateMaxDrawZ` jen při změně dlaždice/výšky (`:63-68`); nám se sem chodí každý frame a flood fill projde **161 dlaždic** (naměřeno v Británii) — bez cache by to byl flood fill na každý frame |
| Snímek (pohledem) | `_analyza/p27-strop-1477-1612.png` — strop 40, `holes=0`, nic nechybí (kontrola, že se neskrylo, co vidět má být) |
| Test + mutace | nový `tests/cases/near_z.gd` (10 kontrol: okap vs hřeben, nesouvislá střecha se nepočítá, bez střechy vstup beze změny, `pz+16` strop, cache); mutace „hřeben místo okapu" → **2 selhání** |
| Testy / brány | **1422 → 1433 kontrol / 0 selhání**; brány **11 měřeno / 0 chyb** |

**➡ Co z toho plyne pro uživatelovo pozorování:** „kousek zdi z vyšší úrovně,
krok stranou už ne" **je chování originálu**, ne naše vada: `_maxZ` zůstává
**127** (tj. nic se neskrývá), dokud na dlaždici hráče nebo na (x+1,y+1) není
střecha — a to se krokem mění. Naměřeno: **904 z 1369** pozic má nad hráčem
(+14) kreslené objekty patra, protože kandidát není. Co na tom působí divně,
je **tvrdý skok** (žádné prolínání) — a to je přesně bod 5.4: reference objekty
v úrovni stropu a výš **faduje na alfu 0** (`ProcessAlpha`, `:339-368`), nezahazuje.

### 5.4 HOTOVO (2026-10-09, `render/chunk_renderer.gd` + `app/world_view.gd`)

**Co je hotové:** objekty, které po přestavbě seznamu zmizely (strop patra /
střecha nad hráčem), se **zachytí a dohasínají** po 25 jednotkách alfy na tik
20 ms (`ALFA_KROK`/`ALFA_TIK_MS`, doslovný přepis `CalculateAlpha`,
`GameSceneDrawingSorting.cs:398-440` + `Constants.ALPHA_TIME = 20`), místo aby
zmizely skokem. Kreslí se **mimo dávku** (jako reference routuje fading objekty
mimo mesh, `ChunkMesh.cs:878-882`) — dávka je zapečená a alfa by v ní zamrzla.

| Důkaz | Číslo |
|---|---|
| Živá sonda `_analyza/p28-fade-sonda.gd` (posun (1490,1611) → (1491,1612), strop 127 → 40) | zachyceno **4725 objektů** (celé patro budovy), fade dohasíná **11 kroků**; frame časy během fade **20–25 ms** (žádný zásek) |
| Snímek pro oko | `_analyza/p28-fade-2f.png` (patro ještě plné) → **`_analyza/p28-fade-5f.png` (patro průhledné, uvnitř je vidět místnosti)** → `p28-fade-po.png` |
| Test + mutace | nový `tests/cases/fade_patra.gd` (12 kontrol: 255 → 230 → 205, tik 20 ms, po 11 ticcích vypadne, `fade_zapnuty=false`, objekt mimo nový pohled se nechytá, znovu viditelný z fade vypadne); mutace „skok místo fade" (`ALFA_KROK = 255`) → **2 selhání** |
| ⚠ NAMĚŘENÁ CESTA (dvě falešné starty, obojí zapsané) | (a) fade kreslený přes **starou dávku** nebyl vidět (objekt zůstal zapečený) — snímek `6f` ukazoval plné patro; (b) kreslit během fade **původní cestou** stojí při 1600×900 **~320 ms/frame** (19 485 objektů) → nepřijatelné. Řešení: fade **čeká na novou dávku** (`spust_fade()` až když je hotová) |
| Cena, kterou to má | mezi posunem a začátkem fade se čeká na stavbu nové dávky — naměřeno **811 ms** při 1600×900 (do té doby kreslí stará dávka, kde objekty ještě jsou). Reference tuhle prodlevu nemá (staví se každý frame) |
| Testy / brány | **1433 → 1450 kontrol / 0 selhání**; brány **11 měřeno / 0 chyb** |

**⚠ CO SE NEDĚLÁ (pojmenovaná odchylka):** **fade-in**. Objekt, který se znovu
objeví, nakreslí nová dávka **rovnou s alfou 255**; reference mu alfu
`CalculateAlpha` zase **zvyšuje** (`:425-435`). Je to vidět jako skok při
odchodu z budovy — zapsáno, ne zamlčeno.
**Citace z reference (k bodu 5.4):**

| Co reference dělá | Citace a čísla |
|---|---|
| Objekt v úrovni `_maxZ` a výš se **nevyhodí, ale faduje** na alfu 0 | `ProcessAlpha`, `GameSceneDrawingSorting.cs:339-356` (`obj.Z >= _maxZ` → `CalculateAlpha(ref obj.AlphaHue, 0)`); totéž pro `_noDrawRoofs && IsRoof` (`:357-368`) |
| Krok fade | `CalculateAlpha` (`:398-440`): alfa se mění po **25 jednotkách** na tik (255 → 0 je tedy ~11 tiků) |
| Délka tiku | `Constants.ALPHA_TIME = 20` ms (`Constants.cs:42`) → celý fade **~220 ms** |
| Fade se dá vypnout | `Profile.UseObjectsFading == false` → alfa se nastaví rovnou (`:400-408`) = náš `fade_zapnuty` |
| Fading objekty jdou **mimo mesh** | `ChunkMesh.cs:878-882` (`meshFadingOut` → do render queue) — u nás se dohasínající objekty kreslí zvlášť, protože dávka je zapečená |



---

## 6. FÁZE 2 — vizuální kontrakt + paritní harness (návrh, odhadem 1–2 sessions)

**Bez tohohle je fáze 3 hádání.** Výstupem je dokument (patří do `docs/`, tedy
na uživatele/novou session, ne do implementační) a nástroj:

1. **Kontrakt**: kamera a zoom (`Camera.cs:162-184`), výřez (`GameSceneDrawingSorting.cs:1236-1281`),
   Z-pásma a stropy (§2.4), řazení do hloubky (`View.cs:83`), střechy a fade,
   `CircleOfTransparency` (`GameScene.cs:567-578`), animace (skupiny, časování —
   **pozor: reference žádnou tabulku ms/frame nemá**, `CHARACTER_ANIMATION_DELAY = 80`
   je jen minimální krok, `Constants.cs:13`).
2. **Paritní harness**: pro souřadnici (x, y, z) vyfotit náš klient + změřit
   čísla (počet objektů, klíč řazení, barvy) a porovnat s očekáváním
   z kontraktu; dnes existuje `check-render.py` (G10) a ruční srovnání
   `_analyza/p22-sbs-*`.
3. **`sim.regen`** (doplnění staminy) + spotřeba podle váhy — tím se stamina
   vrátí z „vypnuto" na **věrný model** (§2.2) a `never` zmizí z dat.

---

## 7. FÁZE 3 — vlastní vizuál, po vlnách (odhad, neurčeno)

Teprve tady je smysl mluvit o „dokončení vizuálu": worn art (vrstvy výbavy),
předměty na zemi (dnes se **nekreslí** — 20. session to zapsala), jména a
tooltips, světlo a denní cyklus, počasí, multi (domy/lodě), gumpy, particles.
Každá vlna má stejný tvar: **pravidlo z reference → implementace → snímek +
číslo → brána**. Odhad je **3–5 sessions** (odvozeno z tempa posledních 20
sessions: ~10 vad na session včetně měření), ale je to **odhad, ne měření**.

---

## 8. Co je na tom drahé, co se ztratí a co to neumí

* **Nejdražší je fáze 2** — psát kontrakt z cizího kódu je pomalé a musí se
  citovat (jinak vznikne „pravidlo", které nikdo nedohledá). **Bez ní je ale
  fáze 3 dražší**, protože se každá vada řeší dvakrát.
* **Co se ztratí:** pokud se zoom < 1 zruší (§5.2), zmizí možnost „vidět víc
  světa" jedním kolečkem — nahradí ji větší okno. Originál zoom **neměl**.
* **Co to neumí:** nedostane do hry art, který v datech není; neudělá
  „hezčí" grafiku, jen věrnější; a **nezaručí, že vady zmizí samy** — fáze 1
  je pořád práce na konkrétních pravidlech.
* **⚠ Změna specu, kterou to už přineslo** (§4.2): `tests/cases/balance.gd`
  pinovalo `stamina_drain_model == "run_only"`, nyní pinuje `"never"`.
  Pravidlo `docs/09 §9.5` říká „agent nemění `tests/`" — **jediná výjimka
  v této session je tahle jedna hodnota**, vynucená přímým pokynem uživatele
  („Zatím bych to vypnul"). **Vrátit se to dá jedním řádkem** (a jedním
  v `data/balance.json`).

---

## 9. ROZHODNUTÍ UŽIVATELE (2026-10-09 — odpovědi na otázky §8 prvního kola)

| Otázka | Rozhodnutí |
|---|---|
| Rozsah | **Fáze 1 + kontrakt k pravidlům, která se v ní opravují.** Fáze 2 jako samostatný dokument až podle výsledku fáze 1. |
| Okno | **Zvětšit na 1600×900** — a hlavně: rám světa má být **volitelný** (§10). Uživatel hru neprovozuje fullscreen z našeho okna, ale zvětšuje si ji; prostoru je dost. |
| Zoom | **Výchozí zoom 1,0**, rozhled řešit oknem; zoom zůstává jen na klávesách pro ladění. |
| Spec testy | **Agent smí měnit hodnotu ve spec testu**, když se změní rozhodnutí uživatele — vždy s odůvodněním a datem přímo v testu. |

---

## 10. Rám světa je volitelný (odpověď na otázku uživatele + pravidlo originálu)

Uživatel se zeptal: *„předpokládám, že neumíš udělat okno světa volitelné?
V UO u některých klientů lze ten rám roztáhnout libovolně… možná mají zobrazení
světa třeba 1600×900, takže tolik vidí klient, ale hráč si z toho určuje výřez
volbou velikosti rámu?"* — **Ano, přesně tak to originál dělá, a jde to i u nás.**

| Co | Citace z reference |
|---|---|
| Svět se kreslí do **obdélníku `Camera.Bounds`**, ne do celého okna | `_src/classicuo/src/ClassicUO.Client/Game/Scenes/GameSceneDrawingSorting.cs:1196-1197` (`winGameWidth = Camera.Bounds.Width`) |
| Ten obdélník je **uložený a volitelný**: pozice + velikost | `GameScene.cs:102-105` (`Camera.Bounds` z `Profile.GameWindowPosition/GameWindowSize`), ukládá se zpět `:281-287` |
| Hráč ho mění **tažením za rám** | `Game/UI/Gumps/WorldViewportGump.cs:128-150` (drag mění `Camera.Bounds.Width/Height`) — a velikost se posílá i serveru (`:63`, `Send_GameWindowSize`) |
| A je i **„fullsize"** (rám = celé okno) | `Game/UI/Gumps/OptionsGump.cs:1617-1730` (pole pro šířku/výšku/pozici, lock, fullsize) a `:4113-4133` (přepínač nastaví rám na velikost okna) |
| **Kamera se centruje na rám, ne na okno** | `GameCursor.cs:655-656`, `GameSceneInputHandler.cs:48-49` — střed je `Bounds + Width/2` |

**Co z toho plyne pro nás:** naše `gui_odsazeni` (posun kamery o polovinu pásu)
je **správná myšlenka ze stejného pravidla** — chybí jí jen **volitelnost**.
Dnešní stav: plátno je napevno 1280×720 (`project.godot`) a `scale_mode=integer`
ho v cizím okně **nedovolí roztáhnout** (1920/1280 = 1,5 → celočíselný násobek 1
→ hra zůstane v obdélníku 1280×720 uprostřed). To je i důvod, proč „okno nejde
rozšířit".

**Návrh (fáze 1, bod 5.2):** `display/window/stretch/mode = disabled` (svět 1:1
bez převzorkování, jakmile okno není přesný násobek) + rám světa počítaný
z **aktuální velikosti okna** mínus pás GUI + `fullsize` přepínač (pás vypnout).
Přesně to dělá reference; měřený důvod, proč ne `canvas_items`: při okně
1300×740 se převzorkuje **96,74 %** pixelů (19. session, `_analyza/p22-teren-zrno.txt`).

