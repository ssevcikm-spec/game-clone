# ROZHODNUTÍ 2026-10-10 — „MODERNÍ UO": POHYB, BOJ, KRITÉRIUM, PRO KOHO

> **Co je tenhle soubor:** **záznam o rozhodnutí** (co se rozhodlo a proč).
> **Nepřepisuje se** — doplňuje se. Vznikl 2026-10-10 na základě odpovědí
> uživatele na [`NAVRH-MODERNI-UO-2026-10-10.md`](NAVRH-MODERNI-UO-2026-10-10.md)
> (Pět otázek, §10).
> **Stav projektu** se bere z [`HANDOFF.md`](HANDOFF.md) — tenhle soubor je
> rozhodnutí, ne stav. **Směr** je dál v
> [`ROZHODNUTI-2026-10-09-SMER.md`](ROZHODNUTI-2026-10-09-SMER.md) (D1–D9)
> a [`ROZHODNUTI-2026-10-09-VECER-DEMO.md`](ROZHODNUTI-2026-10-09-VECER-DEMO.md) (D10).
> Rozhodnutí níž **nic z D1–D10 neruší**; kde se dotýkají, je to výslovně
> uvedené.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

## 1. Co uživatel odpověděl (2026-10-10)

| # | Otázka | Odpověď |
|---|---|---|
| Q1 | Grafika: 2,5D, nebo 3D? | **vlastními slovy:** „Stejně bude potřeba změnit art, aby nebyl půjčený, a pak je otázka, na co máme ekonomiku a co vypadá dobře." → **art se bude nahrazovat** (není to volba, je to důsledek Q4) |
| Q2 | Pohyb: dlaždice, nebo volně? | **A) dlaždice + plynulý obraz a laditelné tempo** |
| Q3 | Boj: zásah, nebo projektil? | **B) hybrid — mechanika UO + viditelný let šípu** |
| Q4 | Pro koho hra je? | **C) pro lidi, ať si to zahrají** |
| Q5 | Kritérium „co nutí rozhodovat, zůstává" | **A) souhlasím** |

## 2. Rozhodnutí (M1–M5)

### M1 — Pohyb zůstává diskrétní; tempo se stěhuje z „zákona" do dat

**Rozhodnutí:** pohyb je **krok po dlaždicích** (dnešní model), obraz **smí být
plynulý** (interpolace), a **prodleva kroku 400 ms / běh 200 ms přestává být
pravidlo, které se nesmí měnit** — stává se **výchozí hodnotou v datech**.

**Důvod (měřeno):** prodleva je **anti-cheat throttling** — ServUO má fastwalk
detekci výslovně vypnutou s odůvodněním, že ji nahradilo „movement packet
throttling" (`_src/servuo/Scripts/Misc/Fastwalk.cs:5-6,10`), ModernUO má
`MovementThrottle` s prahy a detekcí speedhacku
(`_src/modernuo/Projects/Server/Network/MovementThrottle.cs:23-28,42-51`).
Pro „400 ms je designový záměr" → **NENALEZENO**. Naproti tomu **tempo švihu
design JE** (viz M2) — ne všechna dobová čísla jsou stejné povahy.

**Co to znamená:** `docs/05` §5.1.4 (`:91-102`) obsahuje zákaz „měnit kvůli
dojmu z plynulosti pravidla — prodlevu kroku, průchodnost, dosah ani spotřebu
staminy". **Průchodnost, dosah a spotřeba zůstávají pravidla**; **prodleva
kroku** se přesouvá mezi laditelné hodnoty (`data/balance.json`, kde už je
`stamina_drain_model`, `era.*`, capy a `stat_gain.*`).

**Cesta zpět:** zákaz v `docs/05` se dá vrátit; hodnota v datech se dá nastavit
na 400/200 a chování je totožné.

### M2 — Boj: mechanika UO + viditelný let (hybrid)

**Rozhodnutí:** zásah se **rozhoduje v okamžiku akce** (jako UO), ale **let
projektilu je vidět**. Projektil **není rozhodující objekt simulace**.

**Důvod (měřeno):** přesně tak se chová reference — u luku je pořadí
`Swing` → `OnFired` → `CheckHit` → `OnHit` a „let" je jen vizuální efekt
`MovingEffect` (`_src/servuo/Scripts/Items/.../BaseRanged.cs:91-102,221`).
Zvolená varianta tedy **není odklon od reference** — orákulum zůstává a
`docs/05` §5.5 se nemusí přepisovat, jen doplnit o vizuální let.

**Co to znamená pro automatizaci (D3):** politika **dnes neumí ani útok** —
`ACTION_KINDS` neobsahuje `attack` (`sim/policy.gd:58-60`), žádná podmínka
o cíli (`:47-55`), `policy_state()` vidí jen hráče (`sim_world.gd:354-377`).
K tomu, aby „postava provedla, co jsem zadal" i v boji, patří **[O] 1–2 granule**
— a je to **změna hotových** granulí `sim.policy`/`sim.executor` (milník `MK`),
ne práce na zelené louce. **To je samostatné rozhodnutí k pozdějšímu zadání**,
ne součást M2.

**Co M2 nedělá:** nezavádí pod-dlaždicovou pozici, nemění determinismus
a nezavádí uhýbání jako mechaniku. Kdyby se to někdy měnilo, je to **[O] +3–6
granulí** a nová smlouva (`NAVRH-MODERNI-UO-2026-10-10.md` §6).

### M3 — Kritérium „design vs. dobová vada" platí

**Rozhodnutí (potvrzeno uživatelem):** *Omezení, které nutí hráče rozhodovat,
je design — zůstává. Omezení, které jen zdržuje nebo je následkem techniky své
doby, je výchozí hodnota — ladí se.*

**Důsledek:** audit našel **22 míst**, kde je dobové číslo psané jako pravidlo
(výčet: `NAVRH-MODERNI-UO-2026-10-10.md` §8 C) — patří do `data/balance.json`,
jehož **schéma už existuje** (`app/config.gd`, klíč → typ, default, rozsah).
Nejsou to vady k opravě „hned"; jsou to **kandidáti na ladění**, až se to bude
hrát.

### M4 — Hra je pro lidi, kteří si ji zahrají

**Rozhodnutí:** cílem je **hratelná hra pro ostatní**, ne jen pro autora.

**Co z toho plyne (a co to mění proti dnešnímu stavu):**

1. **Art z instalace UO se NEDÁ distribuovat** (autorská díla EA/Broadsword;
   `README.md` §Právní poznámka, `assets/uo/` je v `.gitignore`). **Výměna artu
   je tím povinná**, ne volitelná — a stává se **milníkem**, ne „až bude čas".
2. **Dokud art není náš, hra je lokální prototyp** — to je v pořádku, ale nesmí
   se to zaměnit s „hotovo pro lidi".
3. **Hosting a trvalý svět tím dostávají smysl** (D9 zůstává: session
   u hostitele první, `always-on` odložený) — pro hru „pro lidi" je session
   u hostitele schod, ne cíl.
4. **Modding je pro tuhle volbu důležitější** než pro hru pro jednoho
   (`SMER` §3: „modifikovatelnost dnes chybí, je to nová práce").
5. **Zvuk a hudba** musí být volné (CC0/CC-BY) — `README.md` to už říká;
   pro distribuci to přestává být poznámka a stává se to požadavkem.

### M5 — Grafika: formát zůstává, zdroj artu se mění (návrh k potvrzení, viz §4)

**Co je rozhodnuté:** nesaháme na renderer dřív, než je co hrát; **3D scéna se
sprity zůstává vratná opce** (a v projektu pro ni už je místo: samostatný
klientský projekt podle D5).

**Co je otevřené:** **odkud vezme vlastní art** — a to je otázka §4.

## 3. Naměřená fakta, o která se M1–M4 opírají

* **Pohyb a jeho cena:** dlaždicová vazba je 62 souborů / 681 řádků; volný pohyb
  je [O] 10–16 granulí + **ztráta orákula** (reference je dlaždicová) + **nová
  brána**, protože invariantu „žádné floaty ve stavu" dnes **nikdo neměří**
  (`check-layers.py` zakazuje jiné věci a `core/hash.gd:33-36` floaty zpracuje).
* **Plynulost už funguje:** max skok obrazu 6,23 px (dřív 31,11), 38 framů mezi
  dlaždicemi (`HANDOFF.md:1509`).
* **Boj:** `sim/systems/combat.gd` neexistuje, `M5` = **11 granulí**, 0 hotových
  (`.forge/roadmap.json`); příkaz `attack` se routuje do neregistrovaného
  systému → „Not available yet" (`sim/commands.gd:42,119-122`).
* **Síť (pro „pro lidi"):** hranice `Command`/`Event` existuje a vstup se
  validuje, ale chybí 11 věcí — z toho **tvrdý blokátor: `_player()` vrací jeden
  `player_serial` pro každý příkaz** (`sim/commands.gd:137-139`). Cena: 4 granule
  plánu (`MP`) + [O] 5–9 implementačních; `24/7` navíc [O] 3–6 + provoz
  (`save()` 78–115 ms na ~2 kB → potřebuje přírůstkové ukládání).
* **Art:** generátor vyrobil 49 705 spritů (274 MB, negitováno); celá faceta
  používá **1 496 land artů + 6 023 statiků** (audit 2026-10-10); referenční
  animace mají ~120 těl, hra má 2 056 gumpů (34 v archivu chybí).

## 4. Otevřená otázka (jediná) — odkud vlastní art

> **✅ VYŘEŠENO 2026-10-10 (druhé kolo) — viz M5 v §7.** Otázka tu zůstává
> i s variantami a cenami, protože bez nich není vidět, **proč** padlo
> rozhodnutí tak, jak padlo. *(Historický záznam se needituje.)*

**Co je na stanici k dispozici (ověřeno dnes, ne odhad):**
Blender **5.2.1 LTS** (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`,
`Test-Path` = True), **hotová pipeline** v `E:\Workspaces\uo-shadows\tools\blender\`
(`build_character.py` 13 kB + `postprocess.py` + **260 spritů**: tělo/nohy/trup/zbraň
× 4 směry × 8 framů, izo kamera, alfa), ComfyUI + SDXL lokálně (`imagegen-local`),
Gemini (`imagegen`), `read_image` na kontrolu pohledem, Pillow/numpy na postprocess.

| Varianta | Co to znamená | Cena `[O]` |
|---|---|---|
| **(A) Modelovat v 3D, renderovat do 2,5D spritů, zdroje (.blend) držet** | jednotné světlo a kamera napříč celou sadou; **renderer ani hra se nemění**; a protože zdroje zůstávají, **3D varianta se tím neuzavírá — naopak se tím začíná** | pipeline (1×) + model na třídu objektů; úzké hrdlo je **kontrola pohledem** |
| **(B) Generovat 2D sprity (SDXL lokálně / Gemini)** | nejrychlejší na jednotlivý obrázek, ale **animace a otočení se rozjíždějí** (konzistence mezi framy je přesně to, co generátor neumí) | nízká na kus, vysoká na **konzistenci** |
| **(C) Plné 3D modely + 3D renderer** | jiný produkt: k artu navíc **přepis rendereru** (20–30 granulí, 4–7 session, 522 z 1 628 kontrol) a **mapa** (statiky jsou 2D art id) | nejvyšší; dnes nedoporučuji |

**Pravidlo, které k tomu patří (ze skillu `game-assets`):** **jednu sadu dělá
jeden nástroj.** Terén (dlaždice) je jiná třída než postavy a předměty — smí se
lišit nástrojem, ale **ne v rámci jedné třídy**.

## 5. Co se podle M1–M4 změní (a co ne)

| Co | Změna | Stav |
|---|---|---|
| `docs/05` §5.1.4 | zákaz měnit prodlevu kroku → „výchozí hodnota v datech" | **k provedení** (M1) |
| `data/balance.json` | nové klíče pro tempo kroku (a další z §8 C podle potřeby) | **k provedení** (M1) |
| `docs/05` §5.5 | doplnit, že let projektilu je **vizuální**, zásah se počítá při akci | **k provedení** (M2) |
| `docs/01` §1.1/§1.5 bod 1 | „nemá server, nemá síťový protokol" vs. D9 + `MP` — rozporné místo | **k rozhodnutí** (čeká na textaci; 11 rozporů v `NAVRH` §8 A) |
| `docs/01` §1.5 bod 7 | „žádné překladání názvů" → „názvy z dat, UI lokalizovatelné" | návrh (M4) |
| Milník pro **vlastní art** | nový milník v plánu (rozsah podle §4) | **čeká na odpověď** |
| `docs/02` §2.1 | „2D izo" jako **rozhodnutí s důvodem** (art), ne vlastnost enginu | k provedení (M5) |
| Brány | **re-baseline** vzhledu s dokladem + **nová brána na float ve stavu** (jen kdyby se měnil pohyb) | návrh (`NAVRH` §11) |
| D1–D10, plán, simulace | **beze změny** | — |

## 6. Co tenhle soubor NEDĚLÁ

* **Nemění žádný soubor v `docs/`, plánu ani v kódu** — to je samostatný krok
  a u `docs/`/`.forge/` ho dělá člověk nebo integrační session
  (`docs/09` §… „zakázané soubory").
* **Nezapisuje art rozhodnutí** — §4 je otevřená otázka, ne rozhodnutí.
* **Netvrdí, že „věrná kopie" byla chyba** — naměřená znalost zůstává majetek.

## 7. Druhé kolo odpovědí (2026-10-10) — M6–M8

| # | Otázka | Odpověď |
|---|---|---|
| Q6 | Odkud vlastní art? | **A) modelovat v 3D, renderovat do spritů, zdroje (.blend) držet** |
| Q7 | Rozsah první vlastní sady? | **A) nejmenší hratelný vzorek** — ne celý katalog obsahu, ne celá faceta |
| Q7b | Kdy začít? | **B) hned paralelně jako druhá kolej** |

### M6 — Art se vyrábí v 3D a renderuje do 2,5D spritů; zdroje se drží

**Rozhodnutí:** vlastní art vzniká **modelem v Blenderu** a **renderem do spritů**
ve **stejném formátu, jaký hra už čte**. Soubory `.blend` (a skripty, které je
staví) se **drží** — jsou to zdroje, ze kterých se dá sada kdykoli vyrenderovat
znovu, a jsou to zároveň **vstup pro případného 3D klienta** (D5). Tím se
rozhodnutí M6 **nevylučuje s 3D variantou**: je to její první krok, ne opak.

**Proč (měřeno):** pipeline je na stanici hotová a ověřená jinde —
`E:\Workspaces\uo-shadows\tools\blender\` (`build_character.py` + `postprocess.py`,
**260 spritů**: tělo/nohy/trup/zbraň × 4 směry × 8 framů, izo kamera, alfa),
Blender **5.2.1 LTS** (`Test-Path` = True). Alternativa (B) „generovat 2D
sprity" padá na tom, co generátor neumí: **konzistence mezi framy a otočeními**.
Alternativa (C) „plné 3D modely" by k artu přidala **přepis rendereru**
(20–30 granulí, 4–7 session, **522 z 1 628 kontrol**) a převod mapy.

**Co to znamená konkrétně:** art se **nepřipojuje do `render/`** (to je
integrační krok, který patří plánu) — vyrábí se do **vlastního jmenného prostoru**
`assets/own/` se **stejným tvarem manifestu**, jaký má `assets/uo/`
(`id`, `kind`, `page`, `x`, `y`, `w`, `h`, `ox`, `oy`, `rect`; stránky 2048²,
pad 1). Výhoda: hra dnes běží dál s původním artem a **přepíná se po kusech**;
až bude seam hotový, stačí, aby pro dané `(kind, id)` vyhrál `assets/own/`.

**Geometrie se zatím NEMĚNÍ:** dlaždice **44×44**, kotvy podle konvence UO
(`land` 44×44 s `ox/oy = 0/0`, `item` s kotevním bodem ~`oy = 30`, `texmap` 64×64).
Změna velikosti dlaždice nebo počtu směrů by shodila bránu `G1` (relace
`ISO_STEP == TILE_W/2`) a celý renderer — **nejdřív se musí prokázat pipeline
uvnitř stávajícího kontraktu**, teprve pak se dá uvažovat o jiné geometrii.

### M7 — První sada = nejmenší hratelný vzorek

**Rozhodnutí:** první vlastní sada nepokrývá katalog obsahu ani facetu, ale
**to, co potřebuje krátká smyčka** (`K1`–`K6`): terén kolem Britainu, postava
(chůze/běh), krumpáč, ruda, ingot, výrobek, kovářské náčiní a prodejce.
Cíl: **snímek, na kterém je vlastní art vedle původního** — a změřený čas na
jeden kus.

**Proč:** celá faceta znamená **1 496 land artů + 6 023 statiků**; katalog
obsahu ~3 000 předmětů, 40+ monster, 2 056 gumpů. Nejdřív je potřeba **změřit,
kolik stojí jeden kus** (model + render + postprocess + kontrola pohledem) —
teprve z toho jde spočítat, co je reálné. **Kontrola pohledem je úzké hrdlo**
(`docs/08` §…: brána pozná „mince je 0,67× truhly", ne „tohle není truhla").

### M8 — Art jede jako druhá kolej, ale se **disjunktním zápisem**

**Rozhodnutí:** práce na vlastním artu **běží paralelně** s vývojem hry.

**Podmínka, bez které to nejde (a je to poučení z paralelních session):**
druhá kolej **nesmí zapsat do souborů, které vlastní běžící práce** — tedy
**ne** do `app/`, `render/`, `sim/`, `ui/`, `tests/`, `tools/gates/`, `data/`,
`docs/`, `.forge/` ani `assets/uo/`. Vlastní jen **nové** cesty
`tools/artgen/` a `assets/own/`. **Integrace** (renderer čte `assets/own/`)
je samostatná granule v plánu, ne součást artové koleje.

## 8. Co je hotové k tomuhle rozhodnutí (2026-10-10)

* **Zadání druhé koleje:** [`ZADANI-25-VLASTNI-ART.md`](ZADANI-25-VLASTNI-ART.md)
  — pilot (1 postava + 3 předměty + 1 dlaždice), kontrakt manifestu, měření
  času, co se nesmí zapisovat.
* **Změřený kontrakt atlasu** (`assets/uo/manifest.json`, dnes): 4 druhy spritů
  (`gump` 2 019, `item` 39 326, `land` 4 244, `texmap` 4 116), 77 stránek
  2048², pad 1; `land` **vždy 44×44** s `ox/oy = 0/0`; `item` medián 45×74
  s `oy` mediánem **30**; `texmap` 64×64; v `report` chybí 34 gumpů, 26 020
  item artů a 12 140 land artů (v archivu nejsou — to je důvod, proč vlastní
  sada není „nahrazení duplicit", ale **doplnění i náhrada**).
* **Nezměněné:** plán, brány, simulace i běžící práce na demu (D10) — artová
  kolej se jich nedotýká.

## 9. Provedení (2026-10-10) — co je hotové a co čeká

> **Co je tenhle oddíl:** **záznam o provedení** rozhodnutí M1–M8 — doplňuje se,
> nepřepisuje. Kdo hledá dnešní stav projektu, čte `HANDOFF.md`.

### Hotové (commit `933193a`, pushnuto, `ahead 0`)

| Co | Kde | Doklad |
|---|---|---|
| **M1 v zadání** — tempo kroku je výchozí hodnota v datech, ne zamrzlé pravidlo (s důvodem: naměřeno jako anti-cheat throttling) | `docs/05` §5.1.4, `docs/01` §1.2 V2 | `check-docs-refs` + `check-zadani` → exit 0 |
| **M2 v zadání** — let projektilu je vizuální, zásah se počítá při akci | `docs/05` §5.5.1 (archery) + §5.5.2 | totéž |
| **Síť: rozpor vyřešen** — „žádná síť, žádný protokol" → „síť odložená, hranice `Command`/`Event` závazná už dnes" | `docs/01` §1.1 + §1.5 bod 1 | totéž |
| **„2D" jako rozhodnutí s důvodem** (ne vlastnost enginu) + měřená cena změny | `docs/02` §2.1 | totéž |
| **Nová brána `G14` `check-state-float`** — hlídá float ve **stavu** simulace (ne ve výpočtu) | `tools/gates/check-state-float.py`, registrace v `run-all.py` za `G2`, popis v `docs/08` §8.2, mutace v §8.3 | **měřeno OK (exit 0)**; self-test **6 případů / 0 chyb**; na stromě: 30 souborů `sim/`, 71 řádků povoleného lokálního floatu, 1 povolený konfigurační člen, **0 vad** |
| **4 zastaralé údaje v `docs/`** | `docs/07` (aktuální počty granulí; historická tabulka zůstala nepřepsaná), `docs/11` (1150 je jiný čítač než 1053), `docs/04` (quality Low/Normal/Exceptional), `docs/01` | doc brány exit 0 |
| **M1 v kódu — tempo kroku je z DAT** (doděláno 2026-10-10 po commitu druhé session) | `data/balance.json` (`movement.walk_ms` 400 / `run_ms` 200 + `sources`), `app/config.gd` `SCHEMA` (typ/rozsah), `sim/systems/movement.gd` (`_read_balance` je načte, `delay_ms_for` je vrací, nový nepovinný vstup `balance_path` kvůli testu), `tests/cases/movement_tempo.gd` (5 měřených větví), mutace v `tools/gates/mutace-tests.py` (nový modul `movement_tempo`) | **testy 1 845 kontrol / 0 selhání** (73 case souborů); **mutace chycena** („tempo se čte z Const" → 5 selhání, návrat ověřen zelenou); brány `G1`, `G5`, `G14` a obě doc brány → exit 0 |

**Proč je `G14` úzká, a ne plošná:** naměřeno, že `sim/` **legitimně** používá
float ve výpočtech (71 řádků — `craft.gd` počítá šanci, `harvest.gd` rolluje,
`skill_gain.gd` vrací float ze `_gain_chance`, `regen.gd` má koeficient).
Plošný zákaz by hlásil vadu o **správném** kódu. Brána proto hlídá jen to, co
jde **do stavu** (člen, jehož jméno je v `state()`), a jakýkoli
`Vector2(`/`Vector3(` v `sim/`; co toleruje, **vypisuje do měření**.

### Čeká (pojmenované, s důvodem)

| Co | Proč to čeká | Přesný další krok |
|---|---|---|
| **Automatizace útoku** (`attack` do `ACTION_KINDS`, podmínka o cíli, `policy_state()` o cíli) — `[O]` 1–2 granule | sahá na `sim/policy.gd`, `sim/executor.gd`, `sim_world.gd`; je to **změna specu hotových modulů `MK`**, takže si zaslouží vlastní zadání, ne „přilepení" k jiné práci | zadat jako granuli k `MK` se změnou specu |
| **2× varianta artu** (88×44, `Z_SCALE 8`, slunce + AO + kontaktní stín) vedle 1× a původního spritu | běží **artový pilot** (`ZADANI-25`); 2× srovnání je jeho navazující krok | po pilotu vyrenderovat srovnávací list a rozhodnout geometrii **z obrázku**; zapojení do hry je samostatná granule |
| **Art v plánu** (granule pro pipeline a pro integraci `assets/own/`) | chybí **změřená cena** — pilot ji dává; plánovat podle dojmu je to, co `M7` odmítá | po `tools/artgen/MERENI.md` doplnit granule v `tools/roadmap-gen.py` + `docs/07` (patří uživateli / integrační session) |
| **Zbylých 7 rozporů z auditu** (`docs/08` F1/F4, `docs/06` C1–C10 vs `check-content`, `docs/05` trvanlivost nástrojů vs existující `entity.equipment`) | část se dotýká souborů, které druhá session **právě mění** (`harvest.gd`) — zapsané tvrzení o stavu by zestárlo dřív, než vznikne | po jejím commitu projít a doplnit |

