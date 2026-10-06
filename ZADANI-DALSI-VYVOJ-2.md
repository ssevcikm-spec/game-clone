# ZADÁNÍ pro další vývoj — etapa 2 (UO-klon, 2026-10-06)

> **Co je tenhle soubor:** **zadání** pro další pracovní session (etapa 2).
> Je to záznam o tom, co se zadalO — **nepřepisuje se**; co se z něj provede,
> patří do `HANDOFF.md` (stav) a `LESSONS.md` (ponaučení).
> **Současný stav je v `HANDOFF.md`** (ten se přepisuje celý).
> **Naměřený stav plánu je v `REVIZE-PLANU-2026-10-06.md`** (revize, provedená
> část je v její hlavičce) a **stav granul měří** `python tools/plan-status.py`.
> **Kam pro co v referencích** je `research/REJSTRIK-REFERENCI.md`.
> **Předchozí etapa (1) je hotová** — její zadání je `ZADANI-DALSI-VYVOJ.md`;
> výjimkou je §8 bod 3, který etapě 2 zůstal (a je níž vyřešený).

---

## 0. Než začneš psát (povinné)

1. Přečti **`HANDOFF.md`** (stav) a **`REVIZE-PLANU-2026-10-06.md`** (co je
   v plánu špatně a co se z něj už provedlo).
2. Spusť **předletovou kontrolu** z `HANDOFF.md` a **napiš, co jsi naměřil**.
   Nově k tomu patří: `python tools/plan-status.py` (stav granul) a
   `python tools/roadmap-gen.py --check` (DAG + milníky + aktuálnost roadmapy).
3. Přečti `docs/09` (pravidla, **§9.7 má pravidlo pro paralelní session**)
   a smlouvy v `docs/04 §4.2` — bez nich nevymýšlej jména API.
4. **Než začneš psát kód, řekni uživateli, co budeš dělat první a proč.**

**Prostředí:** práce potřebuje **plný přístup** (sandbox `workspace-write`
blokuje zápis do `.cache` → brány hlásí falešné vady). Klony v `_src/` jsou
**pinované** — kdo je aktualizuje, rozjede tím citace `soubor:řádek`.

---

## 1. Cíl etapy 2 jednou větou

**Dokončit integraci a M1/M2 tak, aby hra měla uzavřené smyčky (cesta, čas, dveře,
předměty), a zároveň zavést M9 (modernizaci) jako trať, která neubírá měření.**

Konkrétně: hráč **dojde na místo po kliknutí** (cesta), **svět má čas a světlo**,
**dveře se dají otevřít**, **předmět se dá zvednout a nasadit** — a každý krok má
bránu, která se dá zopakovat.

## 2. Naměřená fakta (z čeho zadání vychází; nic z toho neověřuj znovu)

| # | Fakt | Čím je doložený |
|---|---|---|
| F1 | Demo chodí: mapa Britainu, **barevná** postava (tělo 400 + `hue` sada), 8 směrů, animace chůze, kamera sleduje | `HANDOFF.md` (session 2 a 3), snímky v `.cache/render/` |
| F2 | Testy: **455 kontrol, 0 selhání**; brány **11/0/0**, `exit 0`; self-testy **19/0** | `run_tests.gd`, `run-all.py` (2026-10-06) |
| F3 | Plán má **111 granul**; měřitelně hotových **39**; **0 rozporů** milník vs závislost | `python tools/plan-status.py`, `roadmap-gen.py --check` |
| F4 | `render.sort` **už není** v seznamu neintegrovaných (`sort_key` volá `app/world_view.gd`) | `check-wiring.py` (`volanych_z_produkce: 56`) |
| F5 | `world.time` **je napojený** na `sim.clock()` (vada F6 z etapy 1 zavřená), test `tests/cases/time_clock.gd` | `app/main.gd`, `sim/world/time.gd` |
| F6 | Soubory bez vlastníka v roadmapě: **0** (dřív 3) — `app.scene`, `app.player_view`, `app.player_controller` je mají | `plan-status.py` |
| F7 | **`sim.entity_registry` neexistuje**, ale potřebují ho `sim.movement` (drží si mobily sám) i `render.anim` (`play(serial, …)` bere serial jako číslo těla) | hlavičky `movement.gd`, `anim_player.gd`; revize N6 |
| F8 | **`sim.pathfind` neexistuje** → click-to-move a `sim.ai` nemají jak najít cestu | revize N6; rejstřík (vzory v ClassicUO/ServUO) |
| F9 | `world.doors` **existuje**, ale `world.walk` ho **nevolá** (dveře neblokují, otevřené dveře nejsou) a **výška schodů se nepočítá** | `sim/world/walk.gd` (hlavička), revize N6 |
| F10 | **Světlo je nedořešené**: `docs/05 §5.11` + `ZADANI §10` uvádějí „den 12“, `research/01 §4.2` má `DayLevel = 0` / `NightLevel = 12`; `render.light` **není** a `world.time.light_level()` vrací v noci denní hodnotu (a přiznává to) | `sim/world/time.gd`, revize N10 |
| F11 | **Éra není rozhodnutá**: `docs/05 §5.16` uvádí `implemented: false` u **9** skillů, zadání granule `data.skills` u **7**; pořadí 55–57 se rozchází mezi `skills.mul` (55 Throwing / 56 Imbuing / 57 Mysticism) a `research/02` (55 Mysticism … 57 Throwing) | `data/skills.json`, `research/02`, revize N10 |
| F12 | `size_lines` je **orientační**: 29 deklarací překročeno (max `assets.anim` 884/150) | `plan-status.py` (rozhodnutí uživatele: měřit, ne přepisovat) |
| F13 | Tři mutační harnessy jsou **lokální** (`mutace-anim.py`, `mutace-render-anim.py` chtějí UO instalaci / `assets/uo/anim`), v CI běží `mutace-tests.py` a `mutace-skills.py` | `ci.yml`, revize C2 |

## 3. ÚKOLY — v tomto pořadí (podle DAG a podle toho, co blokuje ostatní)

### Úkol 1 — `sim.entity_registry` (nová granule, M2)
Jedno místo, kde se hledá mobil podle serialu: `register(m)`, `get(serial)`,
`all()`, `remove(serial)`. **Soubor:** `sim/entity/registry.gd` (nový).
**Musí zavřít dvě díry:** `sim.movement` ať mobily bere z registru (ne si je drží
sám) a `render.anim.play(serial, …)` ať si tělo vyzvedne tam. Když bude hotové,
**aktualizuj smlouvy** (`docs/04 §4.2` u `sim.movement` a `render.anim`).
**Přijímací kritérium:** test volá `register`/`get`/`all`, neexistující serial
vrací `null` (ne pád), a `render.anim` dostane tělo z registru.

### Úkol 2 — `sim.pathfind` (nová granule, M2)
A* nad dlaždicemi; průchodnost se **ptá `world.walk.can_step`** (nikdy vlastní
kopie pravidel). **Soubor:** `sim/world/pathfind.gd` (nový).
**Vzory:** ClassicUO `src/ClassicUO.Client/Game/Pathfinder.cs:868`, ServUO
`Scripts/Services/Pathing/FastAStarAlgorithm.cs:16` (viz rejstřík).
**Přijímací kritérium:** cesta z A do B na fixture mapě má správný počet kroků,
cesta přes vodu vrátí prázdno, `next_step` vrátí sousední dlaždici.

### Úkol 3 — dveře a schody ve `world.walk` (M2)
Doplnit `Door` (zavřené blokuje, otevřené ne — stav dveří drží `world.doors`)
a **výšku schodů** (dnes se schody chovají jako `Surface`). **Soubor:**
`sim/world/walk.gd`. **Přijímací kritérium:** test se zavřenými a otevřenými
dveřmi, test kroku na schod nahoru/výš.

### Úkol 4 — `sim.interaction` (M2, v roadmapě `strong` ≤ 150 řádků)
`use`, `use_on`, `context_menu`, `context_action` podle `docs/05 §5.2.2` a párové
tabulky §5.2.3. Routing do `sim.craft`/`sim.magic` je **dynamický** (když systém
v `SimWorld.systems` není, vrátí `{ok:false, reason:"not_available"}`).
**Přijímací kritérium:** `use` na anvil nic neudělá (a řekne to), `use_on`
s neexistujícím systémem vrátí `not_available`, neznámý předmět → hláška.

### Úkol 5 — M1 dokončit: `render.light` + `render.names`
**Až po rozhodnutí o světle (viz §5).** `render/light_layer.gd` a
`render/name_plates.gd`. Bez rozhodnutí smí vzniknout jen to, co je nezávislé
(jména nad postavami na dosah/po kliku).

### Úkol 6 — M2 dokončit: `entity.item` → `entity.container` → `entity.equipment`
→ `entity.notoriety`
Tvar dat přesně podle `docs/04 §4.5` (a **opravit rozpory** v té tabulce, které
revize našla). Invariant „**právě jeden rodič**“ (`Item.m_Parent` v ServUO
`Server/Item.cs:759`) — kdo ho obejde, vyrobí duplikát.
**Přijímací kritérium:** předmět nemůže být ve dvou kontejnerech; váha a stacky
sedí; `equip` vrátí, co je na vrstvě.

### Úkol 7 — `ui.hotkeys` (M2/W9) + držení klávesy
Vazby kláves přesunout z `app/player_controller.gd` (kde jsou dočasně) do
`ui/hotkeys.gd`, a doplnit **držení klávesy** (dnes jedno zmáčknutí = jeden krok;
UO opakuje krok, dokud je klávesa držená — vzor: ClassicUO
`GameSceneInputHandler.cs:1279`, příznak `_flags[4]`). Patří to do `app/input_map.gd`
(`app.input`), ale jen po dohodě s uživatelem (vlastník souboru je jiná granule).

### Úkol 8 — M9: modernizace (bez ubrání měření)
`app/config.gd` (typovaná konfigurace: klíč + typ + default + rozsah, neznámý klíč
se hlásí), `app/metrics.gd` (fps, frame ms, počet kreslených objektů, cache),
`render/chunk_mesh.gd` (dávkové kreslení bloků místo per-tile draw callů; vzor
ClassicUO `ChunkMesh.cs:121`). **Pravidlo M9: každá modernizace musí mít stejnou
nebo silnější bránu** — u meshů **paritní test a snímek** (že obraz je stejný).

### Úkol 9 — údržba plánu (průběžně)
Když granule doopravdy dohotovíš, **neměň `done` ručně** — spusť
`python tools/plan-status.py` a `python tools/roadmap-gen.py --check`; stav se
měří (soubor v gitu + test). Když najdeš rozpor v plánu, **patří do
`REVIZE-PLANU-<datum>.md`**, ne tichého přepsání.

## 4. Required výstup etapy 2

1. **Cesta funguje:** klik do světa → postava dojde po dlaždicích (snímek + test
   na fixture mapě).
2. **Dveře a schody:** testy, které by spadly, kdyby `walk` dveře ignoroval.
3. **Předměty:** zvednutí, položení, nasazení, batoh — s testy na invariant
   „právě jeden rodič“.
4. **M9 zavedeno:** `app/config.gd`, `app/metrics.gd`, `render/chunk_mesh.gd`
   s paritním testem a snímkem (obraz stejný jako před optimalizací).
5. **Plán:** `plan-status.py` bez rozporů, `roadmap-gen.py --check` zelené,
   stav měřitelně **vyšší** než 39 hotových granul.
6. **Testy a brány:** `run_tests.gd` (0 selhání), `run-all.py` (0 vad),
   self-testy (0 chyb), mutační důkaz u každé nové kontroly.
7. **`HANDOFF.md` přepsaný** a **`LESSONS.md`** s novými záznamy (i o tom, co
   nevyšlo).

## 5. Otázky k rozhodnutí (agent je nerozhoduje) — co zbývá z revize

1. **Éra** (blokuje `sim.skill_gain`, `data.skills`, souboj): `docs/05 §5.16`
   (9 skillů `implemented: false`) vs zadání granule (7)? A jaké pořadí skillů
   55–57 (`skills.mul` vs `research/02`)? **Bez toho nemá smysl tvrdit věrnost.**
2. **Světlo** (blokuje `render.light`): „den 12“ z `ZADANI §10` a `docs/05 §5.11`
   vs `DayLevel = 0` / `NightLevel = 12` z `research/01 §4.2`. Které číslo je
   „den“? (Revize N10; podklady se měří v referencích.)
3. **Zvuk:** patří do M8 (dnes tam `audio.playback` je), nebo vlastní trať?
4. **`ui.hotkeys` vs `app.input`:** smí session sáhnout do `app/input_map.gd`
   (držení klávesy), i když patří jiné granuli?

## 6. Co NEDĚLAT

- **Neměnit `docs/` bez svolení** — výjimka z 2026-10-06 (revize plánu) byla
  jednorázová; další změny smluv se hlásí.
- **Nepřepisovat `research/`** (je to záznam měření) a **nemazat** `_src/` klony
  ani `research/_src/` (druhé checkouty).
- **Neaktualizovat klony v `_src/`** — citace `soubor:řádek` v `docs/` a
  v rejstříku platí pro pinované commity.
- **Nepřidávat `done: true` ručně** do roadmapy.
- **Nesnižovat počet měření** (pravidlo M9) a **nepřejmenovávat soubory kvůli
  zelené bráně**.
- **Nepushovat bez vyžádání** (uživatel push povolil pro session 2026-10-06;
  nová session ať se zeptá).
