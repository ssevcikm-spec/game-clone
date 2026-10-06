# Revize vývojového plánu (2026-10-06)

> **Co je tenhle soubor:** **ANALÝZA + NÁVRH ZMĚN PLÁNU** (snapshot). Není to
> stav projektu (`HANDOFF.md`) ani zadání (`docs/`, `ZADANI-*.md`) — je to
> revize: co v plánu chybí, co je zastaralé a co si odporuje.
>
> **Datum vzniku:** 2026-10-06 (noc).
> **Datum spotřeby:** až se podle sekce 5 upraví plán (`docs/`, `tools/roadmap-gen.py`,
> `.forge/roadmap.json`, nové zadání etapy 2). **Stav: NEPROVEDENO** — `docs/`
> a `.forge/` agent needituje bez výslovného rozhodnutí uživatele.
>
> ---
> ## ⚠ DOPLNĚNO 2026-10-06 (po rozhodnutí uživatele: „b" + „a")
>
> Uživatel povolil **(b)** editovat i `docs/` a `.forge/roadmap.json` a zvolil
> **(a)** u `size_lines`: měřit a nechat deklarace jako orientační. Podle toho
> se část revize **provedla** a **dvě tvrzení v ní byla chybná**:
>
> | # | Chyba / změna stavu | Naměřeno |
> |---|---|---|
> | **C1** | N6 tvrdilo, že `ui.hotkeys` nemá granuli. **Není pravda** — `ui.hotkeys` v roadmapě je (`owns: ui/hotkeys.gd`, W9). Souborů bez vlastníka jsou **přesně 3**: `app/main.tscn`, `app/player_controller.gd`, `app/world_view.gd` | `python tools/plan-status.py` (0 souborů bez vlastníka po opravě) |
> | **C2** | Z10 tvrdilo „doplnit 3 mutační harnessy do CI". V CI může běžet **jen `mutace-skills.py`** (vstup `data/skills.json` je v gitu). `mutace-anim.py` chce instalaci UO (`D:\Games\…`) a `mutace-render-anim.py` chce `assets/uo/anim/*.png` — obojí je gitignore, takže **lokálně** (dokud nedostanou fixture) | `ci.yml` (komentář u kroku) |
>
> **Provedeno:** Z1 (stav plánu se měří + `--check` + krok v CI) · Z2 (kontrola
> „milník vs závislost" v `roadmap-gen.py`; **6 rozporů opraveno**) · Z3
> (`size_lines` zůstává orientační, překročení hlásí `plan-status.py`) · Z4
> (acceptance `selftest` u 10 extraktorů) · Z5 (**10 nových granul**: `app.scene`,
> `app.player_view`, `app.player_controller`, `sim.entity_registry`, `sim.pathfind`,
> `assets.sounds`, `audio.playback`, `app.config`, `app.metrics`, `render.chunk_mesh`)
> · Z6 (`world_view` řadí přes `render.sort.sort_key` — **`check-wiring` už
> `render.sort` nehlásí jako neintegrovaný**; `world.time` napojen na clock, vada F6
> zavřená, nový test `tests/cases/time_clock.gd`) · Z7 (vlny W10/W11 + pravidlo
> „granule bez vlny se nesmí vydat") · Z9 (**M9 Modernizace** v milnících a v `docs/07`)
> · Z11 (pravidlo pro paralelní session v `docs/09 §9.7`) · Z12 (`ZADANI-DALSI-VYVOJ-2.md`).
> **Zbývá:** Z8 (smlouvy v `docs/04`+`docs/05` — řeší se zvlášť) a rozhodnutí
> uživatele 1–6 (hlavně **éra** a **světlo**).
>
> ---
> ## ⚠ DOPLNĚNO 2026-10-06 (podruhé) — co přinesly dvě rešerše a co se ještě našlo
>
> **Z8 je hotové** (smlouvy v `docs/04 §4.2`, nový §4.2.1 a `docs/05 §5.1.1`/§5.11;
> `check-docs-refs.py` 139 odkazů, `exit 0`). Nová měření přinesla další nálezy —
> a **dvě z nich byly chyby v mojí práci**:
>
> | # | Nález | Naměřeno / kde |
> |---|---|---|
> | **N14** | **Moje citace byla off-by-one**: rejstřík uváděl `MovementSpeed.cs:13`, hodnota `STEP_DELAY_WALK = 400` je na **ř. 12** (ř. 13 je prázdný) | `_src/classicuo/.../Data/MovementSpeed.cs:12`; opraveno v `tools/refs-index.py` (a rejstřík se přegeneroval) |
> | **N15** | **Světlo je v referencích OVĚŘENÉ, ne „UNVERIFIED"**: ServUO i ModernUO `LightCycle.cs:13-16` mají `DayLevel = 0`, `NightLevel = 12`, `DungeonLevel = 26`, `JailLevel = 9`, rozsah 0–30 a **0 = nejjasnější** (ClassicUO `IsometricLight.cs:69` to říká slovem). `data/balance.json:25` přesto tvrdí, že světelný cyklus ověřený není — neověřené je jen chování **originálního OSI klienta** (to je `docs/11 §11.6` O6) | `_src/servuo/Scripts/Misc/LightCycle.cs:13-16,70-82`, `_src/modernuo/.../LightCycle.cs:13-16` |
> | **N16** | **Náš kód nesl špatné číslo i test, který ho „ověřoval"**: `sim/world/time.gd` měl `LIGHT_DAY = 12` (12 je `NightLevel`!) a `tests/cases/time.gd:49` tvrdil `light_level() == 12` — zelená brána nad nesprávným číslem. **Můj nový test** `time_clock.gd` se navíc ptal konstanty proti sobě. Obojí je teď označené jako otevřené rozhodnutí (`NEMĚŘENO` v logu), chování jsem **neměnil** | `sim/world/time.gd`, `tests/cases/time_clock.gd`, `tests/cases/time.gd` |
> | **N17** | **`render/light_layer.gd` neexistuje**, ale `docs/04 §4.2` ho vede jako komponentu `render.light` (a `CanvasModulate`/`PointLight2D` v `render/`+`app/` = 0 nálezů) | `docs/04` ř. 130 vs `Test-Path` |
> | **N18** | **Stat gain: dokument si odporuje sám se sebou** — `docs/05 §5.10` uvádí interval 15 min jako ověřený, `§5.10.1` bod 2 říká, že se má teprve zvolit a zapsat do `data/balance.json`; klíč tam **není** | `docs/05 §5.10` vs §5.10.1 |
> | **N19** | **`docs/05 §5.16` míchá čtyři éry a zamlčuje dvě odchylky**: (a) deklaruje AoS vzorce i AoS item properties, ale vyřazuje **AoS spell schools** (Necromancy/Chivalry/Focus jsou AoS — `BaseCreature.cs:4255`, `Initializer.cs:89`) bez věty, že jde o vědomý řez; (b) kombinuje AoS properties s **pre-AoS lootem** — v emulátorech jsou to dvě větve téhož přepínače (`LootPack.cs:496-502`), takže ten stav tam **nikdy nenastane**; (c) `data/balance.json` to zplošťuje na jediné `combat_era: "aos"`. Chybí zmínka o **Siege** (GGS/insurance off), `ActionDelay` a že **tooltipy jsou AoS+** (`ObjectPropertyList.Enabled = Core.AOS`) | `docs/05 §5.16` ř. 399–408 vs `_src/servuo/Scripts/Misc/CurrentExpansion.cs:27-46`, `LootPack.cs:496-502` |
>
> **Nový návrh Z13 (M9 se musí měřit):** M9 slibuje „modernizace nesmí ubrat
> měření" — a to je tvrzení, které musí mít bránu: `plan-status.py` ať umí
> vypsat **počty měření** (testy, self-testy, mutace, brány) a `ci.yml` ať je
> u artefaktu; při modernizaci se pak porovná „před/po", ne dojmem.
>
> **Rozhodnutí uživatele se tím rozšiřuje** (viz §6): k éře a světlu přibývá
> **stat gain** (N18) a **éra po složkách** (N19c).

>
> **Naměřený stav po provedení:** 111 granul (bylo 101), **39 měřitelně hotových**,
> 10 soubor-je-bez-testu, 62 chybí; **0 rozporů** milník vs závislost;
> `roadmap-gen.py --check` hlídá i to, že `.forge/roadmap.json` není zestaralá.

>
> **Čím je každé číslo měřeno:** `python tools/plan-status.py` (stav granul,
> rozpory závislostí, `size_lines`, pokrytí vlnami), `python tools/refs-index.py
> --srovnej` (reference), `python tools/gates/run-all.py` a testy. Nic v tomhle
> dokumentu není odhad; kde měření chybí, je to napsané.

---

## 1. Co dnes tvoří „plán" a kdo ho smí měnit

| Dokument | Čím je | Kdo ho smí měnit | Stav (měřeno 2026-10-06) |
|---|---|---|---|
| `ZADANI-DALSI-VYVOJ.md` | **zadání etapy 1** (7 úkolů + 7 required výstupů + 7 otázek k rozhodnutí) | člověk (zadání se nepřepisuje) | **vyčerpané** — všech 7 úkolů je hotových, 6 ze 7 výstupů splněno (viz N1) |
| `.forge/roadmap.json` | **DAG 101 granul** (generovaný) | generuje `tools/roadmap-gen.py` | `done: true` u **0** granul, ačkoli **36** je měřitelně hotových (N2) |
| `tools/roadmap-gen.py` | **zdroj pravdy roadmapy** (skript s `g(...)` záznamy) | agent smí (je to nástroj) | `--check` prochází; hlídá ale jen existenci závislostí a cykly (N3, N4) |
| `docs/07-granule-a-milniky.md` | milníky M0–M8 a vlny | **ne** (docs = zadání) | §7.3 pokrývá **62 z 101** granul (N7) |
| `docs/04`–`docs/06`, `docs/09` | smlouvy, mechaniky, obsah, pravidla | **ne** | obsahují **6 děr ve smlouvě**, které blokují konkrétní granule (N9) |
| `research/REJSTRIK-REFERENCI.md` | kam pro co v referencích | agent (generované) | hotové 2026-10-06, `--check` zelený |
| `HANDOFF.md` + `LESSONS.md` | stav a ponaučení | agent | aktuální |

**Pozor:** „plán" nejsou jen granule. Zadání etapy říká, **co teď**, roadmapa
**v jakém pořadí**, `docs/` **podle jakých smluv** a milníky **jak daleko jsme**.
Revize proto prochází všechny čtyři vrstvy.

## 2. Měřený stav plánu (`python tools/plan-status.py`)

```
granul: 101 | `done: true` v roadmapě: 0
  MĚŘENĚ HOTOVÉ (soubor v gitu + test): 36
  soubor je, test není:                 10
  soubor chybí:                         55
```

| Milník | hotové | soubor je, test není | soubor chybí |
|---|---|---|---|
| M0 (bootstrap, jádro, klient) | **16** | 1 | 0 |
| M1 (assety, render, mapa) | **11** | 8 | 4 |
| M2 (pohyb, entity, svět) | **8** | 0 | 17 |
| M3 (interakce, předměty) | 0 | 0 | 5 |
| M4 (data: skilly, recepty) | **1** | 1 | 5 |
| M5 (souboj, magie) | 0 | 0 | 9 |
| M6 (obchod, ekonomika) | 0 | 0 | 3 |
| M7 (svět, regiony, AI) | 0 | 0 | 9 |
| M8 (UI, zvuk) | 0 | 0 | 3 |

**Měřeně hotové (36):** M0 celý (16) · M1: `assets.{anim,art,hues,textdata,tiledata,worldmap}`,
`data.items`, `render.{anim,sort}`, `world.{map,tiledata}` (11) · M2:
`entity.{mobile,skills,stats}`, `sim.movement`, `world.{doors,stairs,time,walk}` (8) ·
M4: `data.skills` (1).

**Co je hotové proti plánu nad rámec etapy 1:** celý M2 pohybový řetěz
(`world.walk` → `entity.mobile` → `sim.movement`), dekódované pixely animací,
`render.anim`, `data.skills` a rejstřík referencí. **`render.hue`** běží
v paralelní session (soubor na disku, v době měření **ještě není v gitu** — proto
ho nástroj počítá jako „soubor je, test není").

## 3. Nálezy

### N1 — Zadání etapy 1 je vyčerpané, ale jeden required výstup splněn NENÍ
Všech 7 úkolů je hotových (CI běh #14 `success`; atlas `--verify` 0 chyb;
`render.textures`/`render.chunk` existují; zapojení do scény hotové; pohyb
hotový; testy `render.sort`/`world.map` hotové).
**Ale required výstup §8 bod 3** („`check-wiring` bez `render.sort` v seznamu
neintegrovaných") **neplatí**: `python tools/gates/check-wiring.py` dnes hlásí
`render.sort.sort_key: volá ho jen tests/ - čeká na integraci` (měřeno:
`neintegrovano: 10`, `jen_z_testu: 32`, `volanych_z_produkce: 55`).
**A zhoršil to můj vlastní kód:** `app/world_view.gd` (tato session) porovnává
`x + y` pro vložení postavy mezi statiky **místo volání `render.sort.sort_key`** —
tedy duplikuje řadicí logiku, kterou má granule `render.sort` poskytovat
(v docs/04 §4.2 je `render.sort` „**jediná** funkce řazení"). Oprava je malá
(viz Z6) a je to zároveň důkaz, proč má plán hlídat integraci, ne jen existenci.

### N2 — Roadmapa nemá stav: `done: false` u všech 101
Měřeno: 36 granul je hotových (soubor v gitu + test), ale roadmapa to neví.
Důsledek: **plán se nedá číst jako fronta.** Kdokoli (agent/orchestrátor) podle
něj začne znovu dělat hotovou práci — přesně to se v tomhle projektu už jednou
stalo (`render.sort` byl hotový a neměl volajícího).
**Návrh (Z1):** stav se nemá psát ručně (zestárne), má se **měřit**:
`tools/plan-status.py` už to umí; `--check` ať hlídá jen jednu věc, která je
vada: **granule označená `done: true`, která měřitelně hotová není** (dnes 0 případů).

### N3 — Šest rozporů „závislost je v plánu později než závislý"
`python tools/plan-status.py` (měřeno, celý výpis):

| granule (milník) | čeká na | ten je v |
|---|---|---|
| `render.light` (M1) | `world.time` | M2 |
| `entity.skills` (M2) | `data.skills` | **M4** |
| `world.teleport` (M2) | `data.regions` | **M7** |
| `world.regions` (M2) | `data.regions` | **M7** |
| `sim.interaction` (M2) | `sim.craft` | **M4** |
| `sim.interaction` (M2) | `sim.magic` | **M6** |

To nejsou chyby kódu — to je **nekonzistence plánu**: buď je špatně milník
(granule patří později), nebo je špatně deklarace (závislost je volitelnější,
než se tváří). Bez rozhodnutí se DAG nedá spustit po milnících.
**Návrh (Z2):** dát tuhle kontrolu do `roadmap-gen.py --check` (je to 15 řádků,
měřeno výše) a rozpory buď opravit, nebo u nich **napsat důvod** (`depends_on`
zůstává pravda, ale milník se posune).

### N4 — `size_lines` je deklarace, která systematicky neplatí
Měřeno: **27 deklarací překročeno**, nejvíc:
`assets.art` 365/60 (6,1×), `assets.anim` **884/150** (5,9×), `assets.textdata`
304/60, `assets.gump` 284/60, `render.hue` 268/60, `data.gen_content` 659/150,
`sim.world_loop` 232/60, `assets.atlas` 506/150 … a `data.skills` (JSON) má
`<= 60`, přitom má **640 řádků**.
Deklarace, která nikdy neplatila, **není plán — je to šum**, a vede k tomu, že se
podle ní „měří" velikost granul (a brány auto-merge by velké granule blokovaly).
**Návrh (Z3):** `size_lines` **změřit** (generátor zapíše `size_now`) a v `--check`
hlásit **překročení jako nález**, ne jako tiché selhání očekávání. Zároveň rozhodnout
politiku (viz §6 otázka 1).

### N5 — Acceptance kritéria neodpovídají tomu, co se opravdu měří
Měřeno: `tests` má 64 granul, `schema` 15, `content` 19, `assets` 12, `render` 10,
`replay` 8, `smoke` 5, `wiring` 4, `determinism` 4, `save` 1 — a **37 granul
nemá `tests` vůbec** (např. všech 12 extraktorů a `app.main`).
Přitom **extraktory měřené JSOU**: `run-all.py --self-test` pouští **19 self-testů**
(10 bran + 9 extrakčních nástrojů) a každý z nich hlásí `N kontrol, 0 chyb`.
Plán tedy tvrdí „nemá testy" o něčem, co testy má — jen jiného druhu.
**Návrh (Z4):** zavést typ acceptance **`selftest`** a přiřadit ho extraktorům
(`assets.*`, `boot.*`) + v `run-all.py` ho brát jako splněný, když nástroj
`--self-test` projde. Nesnižovat laťku: `tests` zůstává tam, kde je.

### N6 — Tři soubory nemá žádná granule (a čtyři nové potřeby taky ne)
Měřeno (`own` žádné granule): `app/main.tscn`, `app/player_controller.gd`,
`app/world_view.gd`. To je známá díra (ZADANI §3 úkol 5) a **není jediná**;
z této session navíc víme o **čtyřech potřebách bez vlastníka**:
1. **registr mobilů** (`serial → mobil`): `sim.movement` si mobily drží sám
   a `render.anim` bere `serial` jako **číslo těla** — obojí je díra ve smlouvě
   (docs/04 §4.2), kterou vyřeší jediná granule „registr entit“,
2. **`ui.hotkeys`** (výchozí vazby kláves): dnes je drží `app/player_controller.gd`,
3. **pathfinding** (0 granul v plánu; rejstřík má vzory: ServUO
   `Scripts/Services/Pathing/FastAStarAlgorithm.cs:16`, ClassicUO
   `Game/Pathfinder.cs:868`),
4. **zvuk/hudba** (0 granul; rejstřík má ClassicUO `AudioManager.cs:68`,
   `SoundsLoader.cs:320` + **naměřené omezení: jen 44,1 kHz stereo**).
**Návrh (Z5):** doplnit 4 granule (+ 3 soubory přiřadit stávajícím, nebo založit
`app.scene`/`app.player_view`).

### N7 — Vlny pokrývají 62 z 101 granul
Měřeno na `docs/07 §7.3`: **62** granul zmíněno, **39** ne. Plán tedy pro 39
granul neříká, ve které vlně se mají dělat (a které můžou běžet paralelně).
**Návrh (Z7):** buď vlny doplnit, nebo explicitně napsat, že zbytek jsou
„samostatné listy“ (a proč).

### N8 — F6 z etapy 1 je pořád otevřené a komentář v kódu lže
Měřeno: `sim/world/time.gd:23` deklaruje `world_time_ms` s komentářem
„(`world_time_ms` nastavuje SimWorld kazdy tick)“, ale **nikdo ho v produkci
nenastavuje** — zapisuje ho jen `tests/cases/time.gd`. Takže `hour()` vrací
v hře pořád 0 (to je přesně vada F6 z etapy 1).
**Návrh (Z6):** napojit `world.time` na `SimWorld._clock` (jedna vložená
závislost) a opravit komentář; patří to do etapy 2 jako první úklid.

### N9 — Šest děr ve smlouvách, které blokují konkrétní granule
Z této session (každá má jmenovitě soubor, kde je díra popsaná v hlavičce):
1. `docs/04 §4.2` `render.anim`: **tvar návratu `play(...)`** a **odkud se bere
   tělo pro `serial`** (dnes: serial = číslo těla),
2. `docs/04 §4.2` `sim.movement`: **kde systém vezme mobily** (dnes `register`),
3. `docs/04 §4.5` vs `§4.2` u mobila: `skills` (array vs instance),
   `equip` vs `equipment`, `name`/`hunger`/`ai` jen v §4.5,
4. `docs/04 §4.2` `world.map.statics_at` vrací **celý blok** (dnes si `world.walk`
   filtruje sám; vada č. 15 v předání),
5. `docs/04 §4.2` `world.walk`: **vstupy se předávají konstruktorem** (jinak
   se průchodnost nedá měřit bez assetů, což je v CI nutnost),
6. `docs/05 §5.1.1`: **dvě konstanty téhož jména** — `Constants.WALKING_DELAY = 150`
   (tempo animace) vs `MovementSpeed.STEP_DELAY_WALK = 400` (pravidlo). Dokument
   musí říct, že **pravidlo je serverové**; jinak si příští session vezme 150.
**Návrh (Z8):** tyhle čtyři odstavce v `docs/04`/`docs/05` přepsat (to je práce
pro člověka nebo pro agenta s výslovným svolením).

### N10 — Dvě rozhodnutí o éře blokují konkrétní granule
Měřeno v této session: `docs/05 §5.16` uvádí `implemented: false` u **9** skillů,
zadání granule `data.skills` u **7** (chybí Chivalry a Focus); `skills.mul` této
instalace má pořadí 55 Throwing / 56 Imbuing / 57 Mysticism, kdežto `research/02`
a ClassicUO mají 55 Mysticism / … / 57 Throwing. Data se řídí dokumentem a rozchod
hlásí, ale **dokud se nerozhodne, nemůže `sim.skill_gain` (M2/M4) tvrdit, že je věrný.**
Totéž světlo („den 12“ vs `DayLevel = 0`) — dnes brzdí `render.light` (M1).
**Návrh:** zařadit do §6 jako rozhodnutí 2–4 a v plánu je označit jako **blokátory
konkrétních granul**, ne jako „otázky k zamyšlení“.

### N11 — „Modernizovat hru" nemá v plánu žádnou stopu
Cíl uživatele je **naučit se ze hry a pak ji modernizovat**. Plán má milníky
M0–M8 (obsah hry) — **modernizace v něm není**. Rejstřík už přitom má konkrétní
vzory: typovaná konfigurace s defaulty (ModernUO `ServerConfiguration.GetOrUpdateSetting`),
GPU mesh batching po chuncích (ClassicUO `ChunkMesh.cs`), **paritní test cache**
(`StepCacheParityTests.cs`), test projekt, který umí reálná data (`Server.Tests`),
invarianty jako dokument (`dev-docs/threading-model.md`).
**Návrh (Z9):** založit **M9 „modernizace"** (nebo samostatnou trať) s pravidlem:
modernizace **nesmí zmenšit počet měření** (každá změna musí mít stejnou nebo
silnější bránu) — jinak se „modernizace" stane cestou, jak obejít testy.

### N12 — Tři mutační harnessy a kontrola rejstříku nejsou v CI
`ci.yml` pouští `mutace-tests.py`, ale **ne** `mutace-anim.py`,
`mutace-skills.py`, `mutace-render-anim.py` ani `refs-index.py --check`.
Důsledek: nové důkazy (59 mutací) se v CI neopakují a rejstřík může tiše zestárnout.
**Návrh (Z10):** doplnit kroky do `ci.yml` (u rejstříku pozor: bez klonů `_src/`
hlásí chybějící stromy — buď klony v CI nemít a `--check` tam nepouštět, nebo
pouštět jen nad existujícími).

### N13 — Proces: v jednom workspace běžely dvě session současně
Naměřeno 2026-10-06 ~22:21: během psaní rejstříku vznikaly soubory `render/hue_cache.gd`,
`tests/cases/render_hue.gd`, `tools/gates/mutace-render-hue.py` a změny `app/`.
Nebylo to nic rozbité (testy 444/0, brány 11/0/0), ale **hrozí, že jeden commitne
práci druhého** a že se dvě session přepíšou v `HANDOFF.md`.
**Návrh (Z11):** pravidlo do `docs/09`/`LESSONS`: *před psaním zkontroluj
`git status` a `LastWriteTime` souborů, které nejsou tvoje; commituj jen své cesty.*

## 4. Co v plánu naopak sedí (a nemá se přepisovat)

- **DAG je zdravý:** `roadmap-gen.py --check` prochází (žádná chybějící závislost,
  kolize `owns` ani cyklus) — měřeno dnes.
- **Milníky M0–M8 dávají smysl** (jádro → assety/render → pohyb/entity → obsah →
  souboj → ekonomika → svět → UI/zvuk) a stavba po vrstvách se osvědčila: dnešní
  demo stálo na hotovém M0/M1.
- **62 granul ve vlnách** je pořád nadpoloviční pokrytí.
- **Reference jsou pinované a rejstřík je kontrolovaný** (`refs-index.py --check`
  68 řádků, 0 mrtvých odkazů) — plán se tím dá doložit, ne jen tvrdit.
- **Zadání etapy 1 mělo správný tvar** (cíl, naměřená fakta, required výstup,
  co nedělat) — proto se dalo dokončit a poznat, že je hotové.

## 5. Navržené změny (konkrétně)

| # | Soubor | Co změnit | Proč (nález) | Jak ověřit |
|---|---|---|---|---|
| **Z1** | `tools/plan-status.py` + `run-all.py` | stav granul **měřit**; `--check` ať spadne jen na „`done: true`, ale neměřeno“ | N2 | `python tools/plan-status.py` |
| **Z2** | `tools/roadmap-gen.py` | do `--check` přidat kontrolu **milník vs závislost** | N3 | `python tools/roadmap-gen.py --check` |
| **Z3** | `tools/roadmap-gen.py` | zapsat **`size_now`** (měřený počet řádků) a hlásit překročení `size_lines` | N4 | tamtéž |
| **Z4** | `tools/roadmap-gen.py`, `run-all.py`, `docs/08` | nový typ acceptance **`selftest`** pro extraktory | N5 | `run-all.py --self-test` (19/0) |
| **Z5** | `tools/roadmap-gen.py`, `docs/07` | doplnit vlastníky: 3 soubory bez granule + **registr entit**, **`ui.hotkeys`**, **pathfinding**, **zvuk** | N6 | `plan-status.py` (0 souborů bez vlastníka) |
| **Z6** | `app/world_view.gd`, `app/main.gd` | `world_view` ať řadí přes **`render.sort.sort_key`**; napojit **`world.time`** na clock (F6) + opravit komentář | N1, N8 | `check-wiring` (sort_key z produkce), testy |
| **Z7** | `docs/07` | doplnit vlny pro 39 granul, nebo říct, proč tam nejsou | N7 | `plan-status.py` (pokrytí) |
| **Z8** | `docs/04 §4.2/§4.5`, `docs/05 §5.1.1` | 6 děr ve smlouvách (tvar `play`, registr mobilů, tvar mobila, `statics_at`, vstupy `walk`, dvě konstanty 150/400) | N9 | `python tools/check-docs-refs.py` |
| **Z9** | `docs/07` + roadmapa | **M9 „modernizace“** s pravidlem „nesmí ubrat měření“ | N11 | ruční kontrola + brány |
| **Z10** | `.github/workflows/ci.yml` | doplnit 3 mutační harnessy (+ rozhodnutí o `refs-index --check`) | N12 | CI běh |
| **Z11** | `docs/09`, `LESSONS.md` | pravidlo pro **paralelní session** v jednom workspace | N13 | — |
| **Z12** | nové `ZADANI-DALSI-VYVOJ-2.md` | **zadání etapy 2** ze stavu, který je naměřený (viz níže) | N1 | `check-zadani.py` |

**Návrh etapy 2 (do Z12), v pořadí podle DAG a podle toho, co je blokované:**
1. **úklid a smlouvy:** Z6 (sort_key, čas), Z8 (dokumentace) — odblokuje integraci,
2. **registr entit** (nová granule) → odblokuje `render.anim.play` a `sim.movement`,
3. **M1 dokončit:** `render.light` (+ rozhodnutí o světle), `render.names`,
   `assets.extract_cli`/`assets.verify` (dnes chybí),
4. **M2 dokončit:** `entity.item` → `entity.container` → `entity.equipment` →
   `entity.notoriety`, `world.regions`/`world.teleport` (+ `data.regions`),
5. **dveře a schody v `world.walk`** (`Door` flag, výška schodů) — dnes je
   `world.doors` hotové, ale `walk` ho nevolá,
6. **`sim.pathfind`** (nová granule) → teprve pak má smysl click-to-move a `sim.ai`,
7. **`ui.hotkeys`** (vazby kláves z controlleru) + držení klávesy (dnes chybí),
8. **M9 modernizace** jako samostatná trať (typovaná konfigurace, paritní testy
   cache, dev-docs invariantů).

## 6. Co potřebuje rozhodnutí uživatele

| # | Otázka | Dnešní stav (měřeno) | Na co to má dopad |
|---|---|---|---|
| 1 | **`size_lines`**: zrušit deklarace, nebo je změřit a dělit granule? | 27 překročení, max 6,1× (`assets.art`), `assets.anim` 884/150 | brány auto-merge, plánování |
| 2 | **Světlo:** „den 12“ vs `DayLevel = 0`? | rozpor trvá; `render.light` kvůli tomu není | M1, vzhled hry |
| 3 | **Éra:** které `implemented` platí (7 vs 9) a jaké pořadí skillů 55–57? | `docs/05 §5.16` (9) vs zadání (7); `skills.mul` vs `research/02` | `sim.skill_gain`, `data.skills`, souboj |
| 4 | **Pathfinding:** nová granule (`sim.pathfind`)? | v plánu 0 granul, v rejstříku 2 vzory | click-to-move, `sim.ai` |
| 5 | **Zvuk/hudba:** vlastní milník, nebo do M8? | 0 granul; rejstřík zná omezení (44,1 kHz stereo) | M8, obsah |
| 6 | **Modernizace:** milník M9, nebo samostatná trať? | v plánu není | cíl uživatele |
| 7 | **Smím upravit `docs/` a `.forge/roadmap.json`?** | agent je needituje bez svolení | Z2–Z5, Z7–Z9 |

## 7. Jak revizi ověřit (a zopakovat)

```powershell
python tools/plan-status.py                 # stav, rozpory, size_lines, pokrytí vlnami
python tools/refs-index.py --check          # rejstřík sedí s diskem
python tools/gates/run-all.py               # 11/0/0
python tools/gates/run-all.py --self-test   # 19 self-testů, 0 chyb
$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
```

**Co tenhle dokument NEMĚŘIL:** chování hry za běhu (jen statická měření a brány),
a „správnost“ obsahu M3–M8 — ty jsou zatím jen deklarované v plánu.
