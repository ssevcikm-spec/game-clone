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
| 5.1 | **Zoom: jeden převodní pár `svět ↔ obrazovka`** (`screen_to_world`/`world_to_screen` s zoomem) a přes něj `_camera_offset`, `click_at`, `interact_command`, `center_for`/`player_screen`, `mouse_run` | `pick` v overlayi == skutečný střed postavy na obrazovce pro zoom 0,5 / 0,75 / 1,0 / 1,5 / 2,0; test na tři různé směry kliku |
| 5.2 | **Rozhled oknem, ne zoomem < 1** (rozhodnutí uživatele, §7): zvětšit canvas (`project.godot`) a držet zoom 1,0 jako výchozí | při zoomu 1,0 je obraz jen posunutý (0,00 % převzorkování — měřeno 19. session); při 0,75 je 0,23 %, při 0,5 92,45 % |
| 5.3 | **Z-pásma podle hráče** (`playerZ ± 14/16`, strop 150) v `render.chunk_renderer`/`render.sort` | snímek místa, kde je vidět zeď z podkroví: se stejným pravidlem se nezobrazí; číslo `maxZ` v overlayi |
| 5.4 | **Střechy: fade na alfu 0** místo vyhození (dnešní stav je binární vidím/nevidím → „krok stranou a je to jinak") | dva snímky téhož místa s hráčem pod střechou a vedle |
| 5.5 | **Záseky**: dokončit cestu „runtime atlas bez překreslení na GPU" (známá z R6) | 2 → 0 framů > 33 ms z 2300; `peak` v overlayi |

**Cena, kterou je fér říct:** 5.1 je zásah do tří souborů v `app/` (kamera,
vstup, výstup na obrazovku) a musí projít existujícími testy vstupu
(`tests/cases/input.gd`, `player_controller.gd`, `world_view.gd`) — odhadem
1 session; 5.3/5.4 jsou změny v `render/` s paritní branou, také ~1 session.

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

## 9. Otázky pro uživatele (rozhodují o rozsahu)

1. **Rozsah**: (a) dodělat fází 1 a pak se rozhodnout, (b) pustit rovnou
   1 + 2 + 3, (c) jen fáze 1.
2. **Okno a černý pás**: dnešní okno 1280×720 má **320 px vpravo + 120 px dole**
   černý pás pro GUI (rozhodnutí z 18. session) → svět má 960×600, což je
   **27 % okna pryč**. (a) zvětšit okno na 1600×900 a pás zmenšit,
   (b) 1920×1080, (c) nechat jak je.
3. **Měřítko „hotového vizuálu"**: (a) na první pohled stejné jako originál,
   (b) i se světlem/počasím, (c) „líbí se mi to" (bez oracle).
4. **Smím měnit spec test, když se rozhodnutí změní?** (dnes: jedna hodnota
   v `tests/cases/balance.gd`; bez toho by „vypnout staminu" nešlo zapsat).
