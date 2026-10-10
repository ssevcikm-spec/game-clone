# Návrh — „moderní UO": design, který se ptá na technologie (2026-10-10)

> **Co je tenhle soubor:** **návrh k rozhodnutí** (diskusní podklad). Není to
> stav projektu a není to záznam o provedení — **nic nemění**.
> **Stav projektu** se bere z [`HANDOFF.md`](HANDOFF.md) (přepisuje se každou
> session), **směr** z [`ROZHODNUTI-2026-10-09-SMER.md`](ROZHODNUTI-2026-10-09-SMER.md)
> (D1–D9) a [`ROZHODNUTI-2026-10-09-VECER-DEMO.md`](ROZHODNUTI-2026-10-09-VECER-DEMO.md) (D10).
> Co z tohohle dokumentu uživatel potvrdí, se zapíše jako `ROZHODNUTI-…`
> a **teprve pak** se mění `docs/` a plán.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

---

## 0. Krátká odpověď (kdo nechce číst všechno)

1. **Čtyři věci, na které se ptáš (pohyb, grafika, boj, síť), nejsou v projektu
   rozhodnuté.** Jsou to **zděděné defaulty** z původní premisy „věrný klon":
   `docs/02` §2.1 jen *tvrdí* „hra je 2D", pohyb a boj jsou popsané jako norma
   převzatá z UO. Nikde není záznam, že se zvažovala alternativa — protože se
   tehdy zvažovat nemusela.
2. **Rozděluji je na „tvar" a „číslo".** Tvar (mřížka vs. volno, zásah vs.
   projektil, 2D vs. 3D, jeden hráč vs. sdílený svět) se **rozhodnout musí**.
   Číslo a vzhled (tempo kroku, ceny, regenerace, světlo, health bar, rozložení
   UI) se ladí za běhu — a velká část už takovými daty je (`data/balance.json`).
3. **Z těch čtyř jsou drahé dvě a odložitelné dvě.** Pohyb a boj je **levné
   rozhodnout teď a drahé později** (sahají na simulaci, AI, ukládání, replaye).
   Grafiku a síť lze odložit: simulace na vykreslování nezávisí (drží to brána
   `G2`) a hranice pro síť (`Command`/`Event`) už existuje.
4. **Automatizace se nedělá teď a nedělala se „místo hry".** Je hotová z
   2026-10-09 (session D, commit `228ecdc`) a **D10 ji týž den odstavil** jako
   prioritu; paralelní session dnes píše hru (obchod, regenerace, seznam
   skillů) — naměřeno na souborech z 19:34–19:40.
5. **Co z „věrné kopie" opravdu nedědíme, je v §8** — audit našel **11 rozporů
   k opravě hned** (mj. non-goal „žádná síť" vs. rozhodnutí D9 + milník `MP`;
   „prodleva kroku se nesmí měnit" vs. cíl „bez omezení staré hry"),
   **23 paritních granulí z 122 (18,9 %)**, které budou bojovat proti záměrné
   modernizaci, a **22 dobových čísel vydávaných za pravidla**. Zbytek plánu je
   na věrnosti nezávislý — a naměřená znalost (průchodnost, formáty, pasti) je
   **majetek, který zůstává**.
6. **Grafika má dvě překvapení:** (B) 3D **nevyřeší „hráče za zdí"** (to je
   dnes Z-pásmo + fade a řeší to i reference s hloubkovým bufferem) — opraví
   jen „statik za kopec"; a 3D varianta má v projektu **už své místo**:
   samostatný klientský projekt (D5).

---

## 1. Co je dnes naměřeno (než jsem něco navrhl)

| Co | Naměřeno | Kde to je doložené |
|---|---|---|
| Hra dnes **jde hrát**: chodit, dveře, batoh, žurnál, sběr rudy, tavení, kování | 624 rudy → 624 ingotů → dýka, Mining 0 → 75,0 | `HANDOFF.md` (16. session), `_analyza/vlna16-sber-vyroba.gd` |
| **Svět se zobrazuje** — budovy, statiky, hráč | snímek 1280×720 z 2026-10-09 23:36 | `_analyza/p33-panel-ve-hre.png` (pohledem ověřeno dnes) |
| **Souboj neexistuje** | `sim/systems/combat.gd` **není** (výpis `sim/`) | měřeno dnes; v plánu `M5` = **11 granulí** (měřeno z `.forge/roadmap.json`; `docs/07:162` uvádí zastaralých 9, `docs/07:170` už správných 11) |
| **Obchod právě vzniká** | `data/vendors.json` (115 343 B), `sim/systems/vendor.gd`, `ui/vendor_gump.gd` — necommitnuté, mtime 19:34–19:39 | `git status`, časové značky souborů |
| Automatizace hotová, ale odstavená | `sim/policy.gd`, `sim/executor.gd`, `sim/decision_log.gd`, `ui/policy_panel.gd` | commit `228ecdc` (2026-10-09), `ROZHODNUTI-…VECER-DEMO.md` (D10) |
| Brány | **12 OK / 0 vad**, `G13 vision` neimplementováno (poradní) | `.cache/gates/summary.json` (běh 2026-10-10 19:34) |
| Kód (stav pracovního stromu **včetně necommitnuté práce** paralelní session) | `sim/` 7 473 ř. / 30 souborů, `render/` 2 674, `app/` 3 591, `ui/` 1 365, `tests/` 16 098 | měřeno dnes auditem Pythonem (`splitlines()`); čísla **zastarají každou session** |
| Pathfinding hotový, ale s mezerami | A* nad dlaždicemi; **neumí jiné moby** (dveře a schody už řeší — přes `walk.can_step`) | `sim/world/pathfind.gd:107`, `sim/world/walk.gd:344-353,385-391`; komentář `pathfind.gd:45-48` je zastaralý |
| Klient dostává stav i události | `app/loop.gd:71` volá `sim.snapshot()`, který **sám** vydá i `events` (`sim_world.gd:191`); `drain_events()` zvlášť nikdo nevolá | `app/loop.gd:67-79`, `sim/sim_world.gd:179-192` |
| **Souboj je „zapojený", ale není** | příkaz `attack` se routuje do systému `combat`, který **není zaregistrovaný** → hráč dostane „Not available yet"; registrováno je 6 systémů z 15 | `sim/commands.gd:42,119-122,149-153`, `app/main.gd:530-561`, `sim/sim_world.gd:44-47` |
| **Hotový kód bez konzumenta** | `sim.pathfind` (176 ř., test 227 ř.) **nemá žádného produkčního volajícího** — v `app/` je jen komentář | `sim/world/pathfind.gd`, `app/player_controller.gd:128` |
| Laditelné hodnoty už jako data | `SKILL_CAP` 7000, `STAT_CAP` 225, éra po složkách, stat gain, drain staminy, startovní staty/skilly | `data/balance.json` (každý klíč má `sources`) |
| **Rozhodnutí o pohybu / grafice / boji / síti nikde není** | hledáno v `docs/` (vzory `3D`, `2D`, `izo`): jediné nálezy jsou **tvrzení**, ne rozhodnutí | `docs/02:11,13,78`, `docs/05:190` |

**Co z toho plyne pro tvoji premisu:** „hra nemá funkční interakce ani
zobrazování objektů světa" **platilo dřív, dnes ne** (`HANDOFF.md:1671` to
říká o stavu před 12. session; od té doby přibyl batoh, žurnál, dveře, sběr
a výroba). Co dnes **chybí**, je **náplň a čitelnost**: NPC, obchod (vzniká),
souboj, seznam skillů (vzniká). To je rozdíl mezi „technickým demem"
a „hratelnou hrou" — a je to přesně to, co D10 zvolilo jako prioritu.

---

## 2. „Moderní UO" = tři vrstvy a jedno kritérium

Tvoje věta — *„filozofie tehdejší doby, moderní technologie a přístupy"* — se
dá rozložit takhle. Rozdíl mezi vrstvami 2 a 3 je jádro celého rozhodování:

| Vrstva | Co do ní patří | Jak s ní zacházet |
|---|---|---|
| **1. Filosofie** | sandbox bez levelů; moc roste dovednostmi a **přípravou**; riziko se čte z kontextu; svět žije i beze mě; ekonomika je hráčská (nic není odpad); svoboda má následky | **neměnit** — to je to, co chceš |
| **2. Pravidla a čísla z éry** | krok 400 ms, 8 směrů, zásah na cíl, swing timer, capy 700/225, spread 1,90×, váha předmětů | **orákulum**: dokud není důvod, ber naměřené — a **každé číslo musí být laditelné** |
| **3. Technologie** | engine, determinismus, oddělení klienta od simulace, streaming mapy, nástroje, brány, možnost sítě | **modernizovat bez sentimentu** — tady žádná věrnost nemá cenu |

**Kritérium, které z toho dělá použitelné pravidlo** (a které navrhuji potvrdit):

> **Omezení, které nutí hráče rozhodovat, je design — zůstává. Omezení, které
> jen zdržuje nebo je následkem techniky své doby, je výchozí hodnota — ladí se.**

| Příklad | Co to je | Návrh |
|---|---|---|
| Nosnost a váha předmětů | nutí rozhodovat („co si vzít") | **design** — zůstává |
| Váha zlata | jen otravuje, nerozhoduje o ničem | **dobová vada** — ladit |
| Skill cap 700 | nutí specializovat se | **design** — zůstává (laditelné číslo) |
| Smrt a ztráta věcí | nutí nést riziko | **design** — zůstává |
| Krok 400 ms | **měřeno: je to anti-cheat throttling** („fastwalk"), ne design — ServUO to má výslovně **vypnuté** s komentářem „no longer required … movement packet throttling" | **výchozí hodnota** (ne zákon) |
| Tempo švihu ve souboji | naopak **měřeně design**: komentář v ServUO cituje vývojáře OSI („it has and is supposed to be 1.25") | **zůstává** |
| Zásah bez letícího objektu | měřeno: zásah se počítá v okamžiku švihu, let je jen vizuální efekt | **dobová vada** — viz §6, varianta (c) je to, co reference dělá u luku |
| Gumpová okna a drag & drop | **měřeno: rozvržení skládá a posílá server** (paket `0xB0`, `Gump.cs:408-412`); že je to „vada" je **interpretace** — odůvodnění v referenci NENALEZENO, ale je to důsledek modelu klient/server, který my nemáme | **modernizovat postupně** (architektura je doložená, „vada" je úsudek) |
| 8 směrů vs. 5 směrů v animacích | 8 směrů je **model** (maska v protokolu), 5 je **art a uložení animací** | **dáno artem** — neměnit, dokud je art původní |

---

## 3. Jak design rozhoduje technologii (matice dopadů)

Tohle je odpověď na „jak to ovlivní použité technologie". Každá osa se
propisuje jinam — a to je důvod, proč se nedají rozhodovat ve stejném kole:

| Rozhodnutí | Co určuje v kódu | Co dělá s bránami a testy | Co to znamená pro síť | Jak drahé vzít zpět |
|---|---|---|---|---|
| **Pohyb: mřížka vs. volno** | `sim/systems/movement.gd`, `sim/world/walk.gd`, `pathfind`, dosah, AI | `state_hash` (int vs. float), replaye, determinismus, ukládání | volný pohyb = spojitá pozice → predikce a korekce, víc dat po drátě | **velmi drahé** (sahá na sim, AI, save, replaye) |
| **Boj: zásah vs. projektil** | nový `sim/systems/combat.gd` (dnes není), AI, loot | nové testy, balanc, replaye | projektil = další entity v replikaci | **střední** (M5 má **11** granulí, ještě nezačal) |
| **Grafika: 2,5D vs. 3D** | `render/*` (2 674 ř.) + `app/world_view.gd` (1 116 ř.) | `G10` (proxy metriky vzhledu), paritní sonda, **`G1`** (relace 44/22/4) | jen to, co klient kreslí — sim se nemění | **nízké pro simulaci, střední pro měření** — výměna renderu zneplatní **522 z 1 628 kontrol (32,1 %)** a bránu `G1` |
| **Síť: singleplayer vs. sdílený svět** | replikační vrstva nad `Command`/`Event`, `mp.contract` | `G8`/`G9` (determinismus, replaye) zůstávají | celé | **střední** (hranice je hotová, chybí replikace) |
| **Automatizace (D3)** | `sim/policy.gd`, `sim/executor.gd` | determinismus, replaye | politika běží v simulaci = u hostitele | **nízké** (hotové, odstavené) |
| **Modding** (SMER §3: dnes chybí) | švy, stabilní ID, verzované ukládání, sandbox skriptů | nové brány (verze dat, kolize ID) | na síti nezávislé | **vysoké** (dělat včas, ne dodatečně) |

---

## 4. Osa A — Pohyb: po dlaždicích, nebo volně?

**Dnešní stav (měřeno):** simulace zná **celočíselné dlaždice** a osm směrů;
krok 400 ms (běh 200 ms) je převzaté **serverové** pravidlo UO, ověřené ve
třech nezávislých kódech (`docs/05` §5.1.1). Klient ale **už dnes kreslí
plynule** — interpoluje mezi dlaždicemi, a to je od 2026-10-07 výslovně
povolené (`docs/05` §5.1.4). Průchodnost je port ze ServUO ověřený měřením
(14 965 blokovaných kroků, které reference povolí → 0).

**Proč to není kosmetika:** dlaždice a volný pohyb nejsou dvě verze téhož, ale
**dvě různé hry světa**. V mřížce se rozhoduje v diskrétním prostoru (dosah
jedna dlaždice, únik o dlaždici, dveře jako stav) — a **reference k tomu dává
orákulum**: měřené algoritmy, se kterými se dá srovnávat. V souvislém prostoru
se rozhoduje v centimetrech (únik o krok stranou, kolize s hranou statiku) —
pocit je modernější, ale **přestáváme mít s čím srovnávat** a mění se práce
v AI, dosahu, spawnu, ukládání i síti.

| Varianta | Co to znamená | Cena (odhad `[O]`) |
|---|---|---|
| **(a) Zůstat: dlaždice + plynulý obraz** | dnešní stav; doladit interpolaci a kadenci animace (naměřeno: max skok obrazu **6,23 px**, dřív 31,11; 38 framů nakreslených mezi dlaždicemi) | **0 granulí**, jen doladění |
| **(b) Dlaždice + cesta, po které se jde plynule** (klik-to-move s A*) | pathfinding **už je** (`sim/world/pathfind.gd`) a **dveře i schody řeší** (přes `walk.can_step`); **neumí jen jiné moby**. Dnes: **levý klik = jeden krok**, **držené pravé tlačítko = plynulá chůze za kursorem** (`app/input_map.gd:420-425` vs `:434-451`) — chybí napojení cesty a **fronta 4 kroků** (`docs/05` §5.1.3) | **2–3 granule** (nový soubor pro sledování cesty v `app/`; do `input_map.gd` ne — má 502 ř. a 8,4× víc, než deklaruje plán) |
| **(c) Volný pohyb s kolizí** | pozice mimo celá čísla → padá invarianta „žádné floaty ve stavu", `state_hash`, replaye; nová kolizní vrstva nad dlaždicovými daty; dosah z čtverce dlaždic na euklidovskou vzdálenost; A* nad spojitou pozicí je jiný algoritmus; spojitá pozice po drátě | **10–16 granulí** `[O]` (`walk.gd` 436 ř., `movement.gd` 297, `pathfind.gd` 176, `map.gd` 210; testy `walk` 621 + `movement` 358 + `pathfind` 227 k přepsání) + re-pin replayů s dokladem + **ztráta orákula** |

**Vazba na dlaždici je dnes naměřená šířka, ne dojem:** **62 souborů / 681
řádků** (z toho `tests/cases/` 35 ze 72 souborů) — a to je `[O]` základ ceny (c).

**⚠ A jedna věc, kterou je potřeba vědět předem:** invarianta „žádné floaty ve
stavu" **nemá vlastní bránu**. `check-layers.py` zakazuje jen cesty a
`Input./Time./OS./randf(/randi(`, a `core/hash.gd:33-36` float **záměrně
zpracuje** (`"f:" + roundi(v*1e6)`), aby vada „neshodila běh". Takže volba (c)
by **prošla zelenými branami** a projevila se až v replayi nebo v uložené hře.
To je nejdražší vlastnost té volby — a důvod, proč by k ní patřila **nová brána**
(§11).

**Doporučení:** (a) + (b). A hlavně: **prodlevu kroku přestat brát jako zákon**
a udělat z ní výchozí hodnotu v `data/balance.json` (dnes ji `docs/05` §5.1.4
zakazuje měnit „kvůli dojmu z plynulosti" — to je věta z éry věrné kopie).
Rozhodnutí „mřížka ano/ne" tím **zůstává otevřené** a je vratné: dokud je
pozice dlaždice, dá se volný pohyb přidat později; opačně to neplatí.

**Doložení, že tempo je technický artefakt (ne design):** prodleva kroku je
**anti-cheat throttling** — ServUO má fastwalk detekci výslovně **vypnutou**
s odůvodněním, že ji nahradilo právě „movement packet throttling"
(`_src/servuo/Scripts/Misc/Fastwalk.cs:5-6,10`), drží frontu kroků
(`_src/servuo/Server/Mobile.cs:3081,3303-3312`) a ModernUO má na totéž
`MovementThrottle` s prahy a detekcí speedhacku
(`_src/modernuo/Projects/Server/Network/MovementThrottle.cs:23-28,42-51`).
**Doložení pro opak („400 ms je designové rozhodnutí") → NENALEZENO.**
Proto: výchozí hodnota ano, zákon ne. **Pozor na rozdíl:** tempo **švihu** ve
souboji design *je* (doloženo, viz §6) — ne všechna dobová čísla jsou stejná.

---

## 5. Osa B — Grafika: 2,5D izo, nebo 3D?

**Dnešní stav (měřeno):** 2D izometrické plátno s **původním artem UO**
(dlaždice 44×44, `ISO_STEP` 22, `Z_SCALE` 4), vlastní painter's algoritmus
s klíčem řazení, chunkový renderer, který skládá dlaždice na GPU
(`SubViewport`). `render/` má 2 399 řádků + `app/world_view.gd` ~1 300 řádků.
**Dnešní stav (měřeno, audit 2026-10-10):** kreslí se **výhradně 2D plátnem** —
v celém projektu je **nula** výskytů `Node3D`, `Camera3D`, `MeshInstance3D`,
`MultiMesh`, `Light2D` nebo `CanvasModulate` (jediné „3D" je `Vector3(` jako
matematika normál svahu). `render/` = 6 souborů / 2 674 řádků + `app/world_view.gd`
1 116 řádků = **3 790 řádků, 12,1 % kódu projektu**. Na projekci a řazení se
odvolává **19 souborů / 181 výskytů** (produkce 8 souborů / 51, testy 11 / 130;
`sort_key` sám 65×).

**Co rozhoduje, není engine, ale art.** Generátor vyrobil **49 705 spritů**
(předměty 39 326, land 4 244, texmap 4 116, gump 2 019) na 77 stránkách 2048²,
**274 MB**, negitovaných. Ten art je 2D, předrenderovaný s vlastním světlem
a **pěti směry v datech animací** (osm směrů je model, pět je art — `docs/03`
§3.5). Je zdarma a je to nejdražší jednotková položka celého projektu (SMER §3).

| Varianta | Co to přinese | Cena (odhad `[O]`) |
|---|---|---|
| **(a) Zůstat u 2,5D** | dnešní vzhled; vady se řeší cíleně | **0 granulí za rozhodnutí** (zbytková práce je plán, ne cena volby: ~37–56 granulí, 10–16 session) |
| **(b) 3D scéna + ortografická izo kamera a UO sprity jako billboardy** | **vyřeší jedinou doloženou vadu: „statik za kopcem"**; zmizí řazení neprůhledné geometrie; zoom a kamera triviální | **20–30 granulí, 4–7 session** + přepsání **522 z 1 628 kontrol (32,1 %)** + přepojení brány `G1` |
| **(c) Plné 3D modely** | jiná hra (a modely mohou do gitu → hra přestane záviset na instalaci UO) | **7 519 objektů** k vymodelování (1 496 land + 6 023 statik na celé facetě) + ~120 animovaných těl; [O] ~1 250 h jen při 10 min/model, kontrola pohledem je úzké hrdlo |

**Tři věci, které je potřeba říct poctivě:**

1. **3D NEVYŘEŠÍ „hráče za zdí"** — a je to měřené, ne názor. „Hráč za zdí" se
   dnes neřeší pořadím, ale **Z-pásmem `playerZ ± 14/16` a fadem na alfu 0**
   (`render/chunk_renderer.gd:105-106,142-148,294`). Strop nebo patro nad hráčem
   je **i ve 3D blíž kameře než hráč**, takže ho hloubkový buffer pořád překryje
   — a **reference to dělá stejně, přestože hloubkový buffer MÁ**
   (`VIZUAL-PARITA-2026-10-09.md:60-73,370-378`). Varianta (b) tedy řeší
   **jedinou** doloženou vadu: „statik za kopcem" (`render/sort.gd:28-32`).
   Devět dalších doložených vad vzhledu (fade prodleva, `nodraw` dlaždice,
   chybějící art, zrnění, pixelatost, voda v lese, lámání dlaždic, čas framu)
   je na volbě 2D/3D **nezávislých**.
2. **Skrytá past u (b):** sprity UO mají alfu a **alfa-blendovaný materiál se
   hloubkovým bufferem neřadí** — pořadí průhledných objektů se vrátí jako
   problém, který dnes řeší právě `render/sort.gd`. 3D nezruší painter's
   algoritmus, jen mu vezme půdu u neprůhledné geometrie.
3. **Sprity mají zapečené světlo.** Dynamická světla a stíny na nich vypadají
   rozbitě, dokud se art nevymění — „moderní osvětlení" je s původním artem jen
   částečně dosažitelné.

**Doporučení:** **(a) teď, (b) jako vratnou opci — a možná v jiném projektu.**
Grafika je ze všech čtyř os **nejlépe odložitelná** (simulace na vykreslování
nezávisí, výměna renderu **neshodí replaye ani determinismus** — jen 32 % testů
a bránu `G1`) a projekt už pro (b) má místo: **D5 rozhodl, že „moderní klient"
je samostatný projekt** (`godot-uo-client`) a bere si **data a naměřená
pravidla, ne kód klonu**.

Jedno rozhodnutí se ale odložit nedá: **zůstáváme u původního artu UO (osobní
hraní), nebo jdeme na vlastní art (distribuce)?** Assety z instalace jsou
autorská díla EA/Broadsword a `assets/uo/` je proto v `.gitignore`
(`README.md` §Právní poznámka) — hru s nimi **rozdávat nelze**. Varianta (c) je
mimo jiné cesta, jak tenhle blokátor jednou odstranit (modely jsou vaše dílo) —
ale za cenu, že to už není UO.

---

## 6. Osa C — Boj: „zacílit = zasáhnout", nebo letící projektil?

**Dnešní stav (měřeno):** `sim/systems/combat.gd` **neexistuje** (souboj je
jen v plánu jako `M5`, **11 granulí** — měřeno z `.forge/roadmap.json`) a v zadání
je **model UO**: swing timer podle DEX a zbraně, šance na zásah, damage, parry,
luk s municí (`docs/01` V5, `docs/05` §5.5).

| Varianta | Co to znamená | Cena (odhad `[O]`) |
|---|---|---|
| **(a) Zacílit = zasáhnout** (jako UO) | deterministická výměna timerů; rozhoduje se **„na koho"**, *jak* dělá simulace; nízké riziko pro determinismus (časy v ms, hody z `SimRng`, celočíselný stav) | **dnešní plán** (`M5`, 11 granulí; bez spawnu, smrti a lootu 5–6) + **1–2 granule** na rozšíření slovníku politiky (viz níž) |
| **(b) Projektil letí a má dopad** | lze uhýbat krokem stranou; boj je prostorový; AI musí mířit na pohyblivý cíl | **+3–6 granulí** (smlouva, `projectile.gd` jako stavový zdroj → hash/save/replay s dokladem, AI + kreslení letu, testy) a změna `docs/05` §5.5 |
| **(c) Hybrid: mechanika (a) + viditelný let jako efekt** | dopad se rozhodne v cíli, ale let je vidět | **+1–2 granule** |

**Dvě věci, které k (b) patří a nejsou vidět na první pohled:**

1. **Projektil potřebuje pod-dlaždicovou pozici.** To znamená buď pevnou řádovou
   čárku v intech (nový tvar stavu a nová pravidla zaokrouhlování), nebo float —
   a to je **rozpor s invariantou** (`docs/01` §1.5 bod 3) a s hashem. Navíc se
   **pořadí v rámci tiku stává součástí specifikace** (posune se první projektil,
   nebo cíl?). To je jiná třída rizika než u (a).
2. **Je to odchylka od reference** — UO má u luku dostřel 7–10 dlaždic a munici
   na výstřel, ale **žádný letící projektil jako rozhodující objekt**
   (`docs/05` §5.5.1). Orákulum tedy u (b) mizí, stejně jako u volného pohybu.

**Co je na tom doložené z reference (a mění to zadání variant):**

- **Zásah se počítá v okamžiku švihu, ne v okamžiku dopadu.** U luku je pořadí
  `Swing` → `OnFired` → `CheckHit` → `OnHit` a „let" je **jen vizuální efekt**
  (`MovingEffect`) — `_src/servuo/Scripts/Items/.../BaseRanged.cs:91-102,221`.
  To znamená, že **varianta (c) není modernizace ani odklon: je to popis
  reference.** Původní UO mělo viditelný let šípu *a* UO mechaniku zároveň.
- **Tempo švihu naopak design je** — komentář v `BaseWeapon.cs:1611-1616`
  cituje vývojáře OSI („it has and is supposed to be 1.25"). Takže „zrušit
  swing timer" by byla změna **designu**, kdežto „přidat letící projektil jako
  rozhodující objekt" by byla změna **techniky** (a dražší).

**Co se snadno přehlédne — dopad na automatizaci (D3), a je to naměřené:**
tvrdil jsem, že „zacílit = zasáhnout" je politikou zapsatelné rovnou. **Není.**
Dnešní slovník politiky `attack` **vůbec nezná**:

| Kde | Co tam je | Co tam chybí |
|---|---|---|
| `sim/policy.gd:58-60` | `ACTION_KINDS = [move, use, interact, craft, vendor, say, wait, stop]` | **`attack`** |
| `sim/policy.gd:47-55` | `CONDITION_KINDS = [always, item_below, item_at_least, inventory_full, skill_below, flag, time_between]` | podmínka o **cíli, vzdálenosti nebo cizím HP** |
| `sim_world.gd:354-377` | `policy_state()` vydává čas, `flags` a **stav hráče** (`pos/dir/hp/skills`) | **cokoli o jiné entitě** |
| `sim/executor.gd:32-39` | 6 mapování akce → `Command` | mapování pro `attack` |

Takže varianta (a) je politikou zapsatelná **až po třech rozšířeních** —
`ACTION_KINDS += "attack"` (+ mapování), nová podmínka typu „cíl existuje / je do
N dlaždic / má HP > 0" a `policy_state()` s cílem. To je **[O] 1–2 granule**
a zásah do **hotových** granulí `sim.policy`/`sim.executor` (milník `MK`), tedy
změna specu hotové práce — ne „zdarma" a ne nová práce na zelené louce.

**Varianta (b) je kvalitativně jinde:** politika by musela rozhodovat i **„kam
a kdy"** — mířit na pohyblivý cíl znamená **předpovídat**, a to je rozhodnutí
o budoucnosti, tedy **za hranicí D3**. Obchází se to jen tím, že by **míření
dělala simulace** (auto-aim na aktuální dlaždici cíle); pak (b) zůstane
„provedením", ale **uhýbání se stane asymetrickým**: hráč s myší uhne, automatika
ne (ledaže jí hráč napíše ruční pravidlo „uhni, když…", a to je zase politika,
která dnes o projektiku neumí nic).

**Pravidlo, které z toho plyne:** *„půjde to automatizovat?" je kritérium pro
volbu boje* — ne dodatečná úvaha. Čím akčnější boj, tím menší prostor pro
automatizaci (a naopak); D3 stojí na odpovědi „tvoje dovednost je plánování
a rozhodnutí".

---

## 7. Osa D — Síť a sdílený svět

**Dnešní stav (měřeno):** `docs/01` §1.5 bod 1 říká **„Žádná síť, žádný server,
žádný protokol"** — a přitom D9 rozhodl **session u hostitele** a plán má
milník `MP` (4 granule, `docs/07`:61,91–98). **To je přímý rozpor uvnitř
zadání** a je potřeba ho vyřešit, ať se rozhodne jakkoli.

**Co je pro síť už hotové** (a je to víc, než se zdá): autorita je v `sim/`,
vstup jde jen přes `Command` (19 typů, **validace typu a rozsahu už na serveru
je**, `sim/commands.gd:76-94`), klient posílá **jen záměr** — poloha v příkazu
není a klíč `src` („player"/„policy") už existuje; simulace je deterministická
(20 Hz), mobily i registry mají JSON-safe `state()`/`restore()`, `save` umí
verze a migrace, `advance_offline` umí doběh — a **tik na telefonu je změřený**
(prázdný 1,42 ms; ~25 mobilů do 2 ms; 37 entit 2,27 ms;
`MERENI-TELEFON-2026-10-09.md`).

**Co dnes pro session u hostitele chybí (měřeno, 11 položek):**

| # | Co | Stav |
|---|---|---|
| 1 | Serializace stavu světa | **částečně** — mobily ano, **předměty nejsou stavový zdroj** (`sim/save.gd:21-25`) |
| 2 | `mobiles`/`items` ve snímku | **prázdné** (`sim/sim_world.gd:189-190`); klient čte **živé reference** na objekty |
| 3 | Delta stavu (replikace) | **neexistuje** — `docs/02:146` ji slibuje, kód ji nemá |
| 4 | Zájem o okolí (interest management) | **neexistuje** (culling je jen pro kreslení) |
| 5 | Frekvence snímků | **neexistuje** (snímek každý frame, žádné slévání) |
| 6 | Predikce klienta a snap-back | **neexistuje** (klient vyhlazuje **už potvrzený** krok) |
| 7 | Ověření vstupu: throttle tempa | **neexistuje** (jen „jeden krok v letu" + 400 ms) |
| 8 | **Identita hráče / víc hráčů** | **tvrdý blokátor:** `_player()` vrací **jediný** `player_serial` pro **každý** příkaz (`sim/commands.gd:137-139`) |
| 9 | Headless server (vstupní bod) | **neexistuje** (`app/server.gd` není; simulace headless běžet umí) |
| 10 | Připojení / reconnect / chat | **neexistuje** (`say` je ve smlouvě, ale nemá větev v dispatchi) |
| 11 | Serializace událostí | **částečně** — bez schématu a verze události, bez filtru pro klienta |

**Cena:** plán má **4 granule** (`host.model`, `mp.contract`, `mp.server_loop`,
`mp.host_probe` — dvě jsou jen dokumenty `docs/12`, `docs/13`, které **ještě
neexistují**, proto je `MP` dnes **0/4**) a k tomu **[O] 5–9 implementačních
granulí** z těch 11 mezer; **trvalý svět 24/7** = totéž **+ [O] 3–6** a navíc
provoz, protože `save()` stojí **78–115 ms** na ~2 kB (plné ukládání v intervalu
nejde → potřebuje přírůstkové) a soak **24 h není změřený**. Pozor: „cena nula"
(`HANDOFF.md:725`) platí o **provozu** session u hostitele, **ne o vývoji**.

**Technická pravda, která práci zlevňuje:** **síť nevyžaduje determinismus.**
Server je autorita a klient dostává snímky; determinismus potřebujeme pro
replaye a offline doběh. Multiplayer tedy **není přepis**, ale přidání
replikační vrstvy nad hotovou hranicí — a to je zároveň důvod, proč se dá
**odložit**: nic z toho neblokuje demo ani hru pro jednoho.

**Designová otázka je dražší než protokol: je svět sdílený?** UO filosofie
stojí na tom, že ekonomika a reputace jsou mezi hráči. Když je svět jen můj,
pak „svět jde dál beze mě" (`F1`) znamená offline doběh. Když je sdílený, mění
se ekonomika, spawn, PvP, moderace — a hlavně **co znamená „nejsem tam"**.

**Poznámka k „moderním přístupům":** klient v prohlížeči (sdílení odkazem)
je technologicky jiná práce než desktopový Godot klient. D5 už rozhodl klienta
jako **samostatný projekt**, takže je to cesta otevřená — ale není zdarma
a nemá smysl ji otevírat dřív, než je co hrát.

---

## 8. Co z „věrné kopie" nedědíme

Tohle je **odpověď na tvou obavu** („nedědíme nic, co není relevantní").
Rozděluji nálezy do čtyř kategorií. **Co jsem ověřil čtením sám**, je tady;
hloubkový audit (běží paralelně) doplní citace a případně další položky.

**A — přímý rozpor s novějším rozhodnutím (opravit hned, ať se neplánuje podle
dvou pravd):**

| Kde | Co tam stojí | S čím si to odporuje |
|---|---|---|
| `docs/01` §1.5 bod 1 | „**Žádná síť, žádný server, žádný protokol**" | `D9` (session u hostitele) + milník `MP` v `docs/07:61,91-98` + granule `mp.contract` |
| `docs/01` §1.1 (`:34`) | „Hra **není** MMO, nemá server, nemá síťový protokol" | totéž (o 100 řádků výš než předchozí bod — rozpor je i **uvnitř jednoho oddílu**) |
| `docs/05` §5.1.4 | „Co **zůstává zakázané**: měnit kvůli dojmu z plynulosti **prodlevu kroku**, průchodnost, dosah ani spotřebu staminy" | `D2` („bez technologických omezení staré hry") — měřeno jako anti-cheat throttling (§4) |
| `docs/01` §1.2 V2 | „diskrétní krok za **400 ms** (běh 200 ms)" jako smluvní bod | totéž: jako **orákulum** je to správně, jako **závazné pravidlo** to blokuje ladění |

**A2 — „drift" uvnitř zadání (audit jich našel 10; tohle jsou ty, které matou
plánování):** `docs/05:281` tvrdí, že se nástroj neopotřebuje, „dokud není
`entity.equipment`" — a `sim/entity/equipment.gd` **už v pracovním stromě je**
(navíc V8 trvanlivost nástrojů žádá); `docs/07` uvádí počet granulí `M5` jako
**9** i **11** (správně 11); `docs/11:82` a `docs/08:129` uvádějí **1150
receptů**, naměřeno je **1053** (`docs/06:78`); `docs/06:105-108` se odvolává
na nevyřešený `tiledata.mul`, který je **vyřešený** (`docs/11:124`); `docs/08`
slibuje, že početní kontroly `C1–C10` měří brána `check-content` — ta sama
píše, že je **neměří** („SCHÉMA NEURČENO"). **To není dědictví kopie, to je
běžné stárnutí zadání** — ale je to přesně to, co se čte jako dnešní stav.

**B — pravidla a brány, které budou bojovat proti záměrné modernizaci**
(potřebují pravidlo „vědomá re-baseline", ne „někdo to spraví"): audit jich
našel **23**. Nejdůležitější tři:

1. **Geometrie éry je zamčená branou.** `G1` vynucuje nejen stejná čísla v
   dokumentaci, kódu a datech, ale i **relace** (`ISO_STEP == TILE_W/2`,
   `TILE_H == TILE_W`) a zákaz literálů 44/22/4 v rendereru
   (`tools/gates/check-schema.py:42,53,56`) — změna měřítka nebo artu je
   červená brána, ne rozhodnutí. **Navíc past:** funkce
   `magic_numbers_in_renderer()` vrací prázdný seznam, když soubor
   `render/chunk_renderer.gd` neexistuje (`:110-113`) → po výměně renderu
   brána **tiše zezelená**.
2. **Vzhled je pinovaný dvakrát:** `G10` počítá pixely přesné shody s 32 barvami
   skin sady (`KUZE_MIN = 500`) a paritní sonda drží **stejný hash** obrazu ve
   třech scénách (`docs/04:456-459`, `_analyza/m9-parita.gd`).
3. **⚠ A procesní mezera, která je horší než obojí:** `docs/09` zakazuje
   agentům editovat `tests/**`, `tools/gates/**`, `project.godot`, `.forge/**`
   a `docs/**` — takže **modernizace nemá procesní cestu, jak měření
   přebaselovat**. Jediný hotový vzor „vědomé re-baseline" je pro hash replayů
   (`tests/replays/README.md:34-60` + sondy `_analyza/p30-*`, `p31-*`); na
   `G10` a paritní sondu se musí **zkopírovat** (§11 bod 6).

**A kolik toho je:** audit spočítal, že **23 ze 122 granulí (18,9 %)** je
vázaných na shodu s referencí — 13 má `render` v `acceptance` (`render.sort`,
`render.chunk`, `render.anim`, `render.names`, `render.light`, `ui.paperdoll`,
`ui.backpack`, `ui.container_window`, `ui.spellbook`, `render.effects`,
`app.player_view`, `app.metrics`, `render.chunk_mesh`), 5 pinuje kadenci
v milisekundách (`core.const`, `core.clock`, `sim.world_loop`, `render.anim`,
`sim.movement`) a 6 pinuje éru (`data.balance`, `ui.tooltip`,
`data.item_properties`, `sim.combat`, `sim.poison`, `sim.loot`); `render.anim`
je v obou skupinách. **To je ta část plánu, kterou je potřeba projít, když se
„věrnost" mění na „orákulum"** — a je to **pětina**, ne většina: zbytek plánu
je na věrnosti nezávislý.

**C — dobová věc vydávaná za vlastnost (má být laditelná, nebo se modernizovat).**
Audit jich našel **22**; tabulka níž jsou ty, které se týkají rozhodnutí v tomhle
dokumentu. Vzorová skupina: **tik 50 ms** (`docs/02:68`), **geometrie 44/22/4**
(`docs/02:82-88`, zamčená `G1`), **dosahy** (`docs/05:208-214`), **tempo kroku
ve smlouvě toku** (`docs/04:602-609`), **ceny 1,90×**, **spawn 5–10 min**,
**den 7200 s**, **capy a přírůstky**, **rozpočty výkonu** (`docs/02:215-220`).
Dobrá zpráva: **cíl, kam je uklidit, už existuje** — `data/balance.json` +
schéma v `app/config.gd`.

| Kde | Co tam stojí | Návrh |
|---|---|---|
| `docs/02` §2.1 | „hra je **2D**, použij `CanvasItem` a `_draw()`" — **tvrzení bez záznamu o rozhodnutí** | dopsat jako rozhodnutí **s důvodem** (art) a s tím, co by znamenala změna |
| `docs/01` §1.2 V1 | ovládání „jako UO" včetně gumpové logiky | gumpové postupy jsou dobová UI; modernizovat postupně, hranice `D3` to dovoluje |
| `docs/01` §1.6 | „anglické názvy a UI texty anglicky" | důvod je správný (60 000 jmen z dat), ale **české UI** je jedna vrstva navíc — rozhodnout později |
| `docs/01` §1.5 bod 7 | „**Žádné překladání názvů předmětů**" | totéž z druhé strany — je to **zákaz**, ne jen volba; zmírnit na „názvy z dat, UI lokalizovatelné" |
| `README.md`, název repa | „UO klon", „věrná kopie" | popisek je dnes nepřesný; přejmenování repa má cenu (CI, orchestrace) — stačí **přerámovat dokumenty** |
| `docs/06` §… (`:97`) | „Recepty z pozdějších ér (runic, reforging, imbuing) se **nezahrnou**" | moderní obsah je vyloučen **pravidlem generátoru**; u „moderního UO" je to kandidát na přehodnocení |
| `docs/05:277` | seznam těžených dlaždic je **v kódu**, „v `data/` nejsou" | jde proti „modifikovatelná a rozšiřitelná" (`SMER` §3) — kandidát na data |
| `docs/01` §1.4 | „housing mimo rozsah", „lodě mimo rozsah" | **není to dědictví, je to rozsah** — ale stavění domů je jeden z pilířů UO; držet jako pojmenovanou opci, ne mrtvý bod |

**D — dědictví, které má zůstat (je to majetek, ne zátěž):** naměřená
průchodnost a výšky (`docs/05` §5.1.2) · formáty dat UO a extrakční pipeline
(`docs/03`, 43 760 záznamů artu) · 23 naměřených pastí (`docs/10`) a 13 záznamů
typu `vada-zadani` (`LESSONS.md`) · determinismus, `state_hash`, replaye ·
hranice `Command`/`Event` mezi klientem a simulací · brány a mutační testy ·
„jmenovky předmětů nejsou klasické" (naměřené omezení instalace, `docs/03`
§3.3.1b) · smlouvy `docs/04` jako **nástroj paralelní práce** (to, že nejsou
návrhem pro moddery, je **nová práce**, ne důvod je zahodit).

**Jedna věta k tomu:** z „věrné kopie" nedědíme **cíl**, ale dědíme
**znalost** — a ta je nejcennější, co projekt má. Co je potřeba zahodit, jsou
**formulace, které z cíle zbyly** (kategorie A a B), ne práce, kterou někdo
naměřil.

---

## 9. Co jde ladit za běhu — a co je „tvar"

**Ladit za běhu (číslo a vzhled) — nic z toho neblokuje rozhodnutí:**

- tempo pohybu (400/200 ms), drain a regenerace staminy — `data/balance.json`
  (klíče už existují a mají `sources`),
- capy a přírůstky (skill cap, stat cap, stat gain 2 s / 25 %) — tamtéž,
- éra po složkách (`combat`, `loot`, `content`, `ui`, `movement`, `skill_gain`)
  — tamtéž; přepíná se **jedním klíčem**, ne přepisem dat,
- ceny, spread, restock — `data/vendors.json` + balance,
- světelný cyklus, délka dne — `sim/world/time.gd`,
- hustota spawnu, obsah regionů — `data/`,
- zobrazení zdraví, rozložení UI, pozice oken, zoom — konfigurace klienta
  (`docs/01` §1.8: health bar je **odložené a vratné** rozhodnutí uživatele),
- zvuk, animace, částicové efekty — kdykoli později.

**Tvar (rozhodnout, nejde „doladit"):** mřížka vs. volný pohyb · zásah vs.
projektil · 2,5D vs. 3D · jeden hráč vs. sdílený svět · původní art vs. vlastní
art · míra moddingu.

---

## 10. Pět otázek, které potřebuju rozhodnout

Odpovídat jde zkráceně (`A`, `B`, `vlastní: …`). Co je pod čarou, **není**
zapomenuté — je to zařazené na později.

| # | Otázka | Varianty | Moje doporučení |
|---|---|---|---|
| **Q1** | **Grafika: čím se to má kreslit?** | (A) zůstat 2,5D s původním artem · (B) 3D scéna + UO sprity jako billboardy · (C) plné 3D modely | **(A) teď, (B) jako vratná opce** — grafiku lze měnit později, simulace na ní nezávisí |
| **Q2** | **Pohyb: po dlaždicích, nebo volně?** | (A) dlaždice + plynulý obraz a **laditelné tempo** · (B) dlaždice + cesta, po které se jde plynule · (C) volný pohyb s kolizí | **(A)+(B)**; (C) jen když po hraní zjistíš, že ti vadí **mřížka**, ne trhanost (ta je opravená) |
| **Q3** | **Boj: zacílit = zasáhnout, nebo letící projektil?** | (A) zásah na cíl jako UO · (B) projektil s dopadem v simulaci · (C) hybrid (mechanika A + viditelný let) | **(A) nebo (C)**; pozor — „postava to udělá za mě" dnes **neumí ani (A)**: politika nezná `attack` (§6), takže k obojímu patří **1–2 granule** do slovníku politiky |
| **Q4** | **Pro koho ta hra je?** (na tom visí licence artu i hosting) | (A) pro mě · (B) pro mě a pár lidí na session · (C) pro lidi, ať si to zahrají | **(B)** — drží D9 a nemění art |
| **Q5** | **Souhlasíš s kritériem z §2?** („co nutí rozhodovat, zůstává; co jen zdržuje, je laditelná výchozí hodnota") | (A) ano · (B) ano, ale u X jinak · (C) chci to řešit případ od případu | **(A)** — jedním pravidlem se zavře desítka budoucích otázek |

**Co je zařazené, ne ztracené:** modding (švy, verzované ukládání, sandbox) ·
klient v prohlížeči · trvalý svět 24/7 · LLM v roli autora politiky nebo NPC
(otevřené téma `SMER` §6.5) · housing a lodě (dnes mimo rozsah) · druhá faceta ·
lokalizace.

---

## 11. Co se po odpovědích změní

Až odpovíš, zapíše se `ROZHODNUTI-2026-10-10-MODERNI-UO.md` (záznam
o rozhodnutí, needituje se) a teprve pak se mění:

1. **`docs/01` §1.1–1.2** — „moderní UO" místo „klon"; V1–V12 zůstávají jako
   **orákulum**, ne cíl.
2. **`docs/01` §1.5 bod 1** („žádná síť") vs. **D9 + milník `MP`** — rozporné
   místo, musí se přepsat na „síť je odložená, hranice `Command`/`Event` je
   závazná už dnes".
3. **`docs/05` §5.1.4** — zrušit zákaz měnit prodlevu kroku; tempo je výchozí
   hodnota v `data/balance.json`.
4. **`docs/02` §2.1/§2.4** — dopsat, že „2D izo" je **rozhodnutí s důvodem**
   (art), ne vlastnost enginu; a co by znamenalo ho změnit.
5. **`docs/05` §5.5** — podle Q3 (projektil ano/ne).
6. **`docs/08`** — pravidlo pro **vědomou re-baseline** vzhledových měření:
   když se vzhled změní záměrně, `G10` a paritní sonda se přebaselují
   s dokladem, ne „někdo je spraví". **A k tomu procesní krok, který dnes
   chybí:** `docs/09` zakazuje agentům editovat `tests/**`, `tools/gates/**`,
   `docs/**` a `.forge/**` — takže re-baseline musí mít **vlastní postup**
   (vzor: `tests/replays/README.md:34-60`), jinak se modernizace zastaví
   o bránu, kterou nikdo nesmí opravit.
7. **Nová brána na „float ve stavu"** (pokud padne Q2 = (C)): dnes invariantu
   z §1.5 bodu 3 **nikdo neměří** (`check-layers.py` zakazuje jiné věci a
   `core/hash.gd` floaty zpracuje) — volný pohyb by prošel zelenými branami.
8. **`.forge/roadmap.json` + `docs/07`** — jen když se změní tvar (Q2/Q3):
   jinak se plán nemění. Projít **23 paritních granulí** (§8 B) a rozhodnout
   u každé: zůstává jako regrese, nebo se přerámuje.
9. **Nezávisle na rozhodnutích (drobné, ale naměřené vady dokumentace):**
   `docs/07` uvádí počet granulí `M5` na dvou místech různě (**9** na `:162`,
   **11** na `:170` — správně je 11 podle `.forge/roadmap.json`), a komentář
   v `sim/world/pathfind.gd:45-48` tvrdí, že pathfind neumí dveře a schody —
   **kód je už umí** (`pathfind.gd:107` → `walk.gd:344-353,385-391`).

---

## 12. Co tenhle dokument nedělá

- **Nemění žádný soubor v zadání ani v plánu** — je podklad k rozhodnutí.
- **Netvrdí, že „věrná kopie" byla chyba.** Naměřené znalosti (průchodnost,
  formáty dat, pasti) jsou nejcennější část projektu; mění se **cíl**, ne
  hodnota té práce.
- **Nerozhoduje o vkusu** (barvy, názvy, konkrétní čísla) — to patří ladění.
