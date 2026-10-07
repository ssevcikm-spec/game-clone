# Kam s projektem: singleplayer, cizí shardy, vlastní server — a co k tomu patří

> **Co je tenhle soubor:** **analytický záznam** k dotazu uživatele (13. session):
> „má hodnotu (a) dělat hru singleplayer, (b) jako custom klienta na cizí UO
> shardy, (c) klienta + vlastní server?" — plus NPC/AI, moderní organizace
> objektů a QoL. **Není to zadání** (to je `ZADANI-DALSI-VYVOJ-2.md`) **ani stav**
> (to je `HANDOFF.md`). **Datum vzniku:** 2026-10-07 (13. session).
> **Datum spotřeby:** **žádné** — nic z toho se neprovádělo; **rozhodnutí a/b/c
> čeká na uživatele**. Až se rozhodne, patří sem (co) a do `docs/01`/`HANDOFF.md`.
>
> **Značky důkazů:** **[M]** = naměřeno dnes (sonda/příkaz, výstup v `_analyza/`),
> **[K]** = kód tohoto repa, **[D]** = dokumenty projektu, **[R]** = referenční
> zdroje v `_src/` a `research/`, **[O]** = **odhad** (není měřený — nesmí se
> číst jako fakt).

---

## 0. Otázky uživatele (doslova)

> „a) dělat celou hru singleplayer; b) napsat hru jako custom klienta, který se
> může připojovat na libovolné servery UO; c) napsat hru jako klienta a
> separovat ji s vlastním custom serverem. … Jak funguje správa NPC a jejich
> umělé inteligence, kolik jich zvládne singleplayer hra a jak bychom mohli
> efektivně naplnit svět, aby „žil"? … Jaká je nákladová cena …? … existují
> moderní systémy jak psát organizaci objektů a jejich parametrů (EPS?) a také
> jak mají fungovat herní aktivity a běh … určitě stojím o quality of life
> zlepšení (automatizace, chytřejší ovládání, krásnější a plynulejší hraní,
> prohloubení herních systémů)."

---

## 1. Tři varianty: co která je, co stojí a co zahodí

### 1.1 Velikosti, ze kterých se dá počítat [M]

| Co | Řádků | Souborů | Jak měřeno |
|---|---:|---:|---|
| **ClassicUO** (referenční klient, hotový a používaný) | **158 068** C# | 455 | součet řádků `_src/classicuo/**/*.cs` |
| z toho `Network/` (protokol) | 17 238 | 17 | totéž, jen složka |
| z toho `Network/Encryption` | 2 111 | 5 | totéž |
| z toho `Game/UI` (gumpy a okna) | 50 978 | 117 | totéž |
| z toho `ClassicUO.Assets` (art/anim/mapa) | 11 672 | 23 | totéž |
| registrovaných příchozích packetů (`Handler.Add(`) | **119** | — | počet výskytů v `PacketHandlers.cs` |
| odchozích packetů (`public static void Send_`) | **123** | — | počet výskytů v `OutgoingPackets.cs` |
| **ServUO** (server) | 1 178 838 C# | 6 323 | součet řádků |
| **ModernUO** (server) | 560 674 C# | 4 214 | součet řádků |
| **Náš projekt — herní kód** | **5 185** GDScript | 37 | `sim` 2 907 + `app` 974 + `render` 846 + `core` 339 + `ui` 119 |
| náš projekt — testy | 6 898 | 40 | `tests/**/*.gd` |
| náš projekt — nástroje (Python) | 13 520 | 66 | `tools/**/*.py` |
| granul hotových / chybí | **53 / 54** | 111 | `python tools/plan-status.py` |

**Poměr, který rozhoduje:** hotový UO klient je **30× větší než celý náš
projekt** a jen jeho síťová část + gumpy dohromady (**~66 000 řádků**) jsou
**13× náš projekt**.

### 1.2 (a) Singleplayer — co to je dnes

* Zadání to tak má: „jedna hratelná, offline, single-player hra … nemá server,
  nemá síťový protokol" (`docs/01` §1.1) a non-goal #1 to zakazuje [D].
* Hotovo je **53 z 111 granul** [M]: mapa, dlaždice, řazení, kreslení, pohyb,
  průchodnost, dveře, schody, teleporty, čas, skilly, staty, předměty,
  kontejnery, interakce, první UI.
* Chybí celý **M3–M8**: souboj, AI, řemeslo, sběr, magie, vendory, spawn,
  žurnál, drag & drop, světlo [M].
* **Cena dalšího kroku:** přesně to, co je v roadmapě. Žádná nová architektura.

### 1.3 (b) Vlastní klient na cizí shardy — co to znamená

**Co by se muselo napsat** (proti tomu, co máme): protokol (119 příchozích +
123 odchozích packetů, šifrování, komprese, login → herní server), **gump
systém** (server posílá rozvržení oken; v ClassicUO 47 086 řádků v 81 gump
souborech, celá složka `Game/UI` 50 978) a celý „server-driven" svět
(kontejnery, target kurzor, obchody, chat). Řádový odhad **[O]**:
**desítky tisíc řádků**, tedy několikanásobek všeho, co jsme udělali.

**Naměřená cena po částech [M]** (ClassicUO = 158 068 řádků C#):

| Kategorie | Řádků | % klienta | Máme ji? |
|---|---:|---:|---|
| síť/protokoly (`Network/`) | 17 238 | 11,0 % | ne |
| gump systém a okna (`Game/UI`) | 50 978 | 32,6 % | ne (naše `ui/` = **119 řádků**) |
| načítání assetů | 13 874 | 8,9 % | **částečně** (extrakce v Pythonu) |
| animace | 4 502 | 2,9 % | **částečně** (`render/anim_player.gd`) |
| herní logika (pathfinding, targeting, pohyb) | 3 478 | 2,2 % | **ano** (naše predikční jádro) |
| vykreslování | 7 247 | 4,6 % | **částečně** (`render/`) |
| zbytek (manažeři, objekty, klientské tabulky) | 60 000+ | ~38 % | ne |

**„Umět se připojit" je 11 %, „být klient" je zbylých 140 830 řádků.**

**A „libovolný shard" neexistuje — jsou to čtyři osy, které se násobí [M]:**

| Osa | Naměřeno |
|---|---|
| verze klienta | **26 opkódů mění délku podle verze** (54 přiřazení v 11 větvích); tři **různé** kopie `ProtocolChanges` (RunUO 14 příznaků / ServUO 16 / ModernUO 16 a zahazuje `Unpack`) |
| expanze | **12 hodnot** u všech C# serverů, Sphere má vlastních 10 |
| vendor rozšíření | **0xF0** (Krrios/Razor), **0x3F/0x40** (UltimaLive), **0xBF** s 17–20 subkomandami (klientský handler má 610 řádků) |
| vlastní obsah shardu | art, cliloc, statiky, mapy — klient je musí umět načíst z disku |

Doklad, že to není teorie: `MapLoader.cs:464-476` vysvětluje, že čtení
„land first" **tiše rozbilo patchování proti každému serveru, který ten packet
posílá** — i tři „stejné" servery se shodují jen proto, že se ClassicUO
přizpůsobil. A klient má v kódu zmínky o konkrétních serverech (sphere, POL,
Outlands).

**Co by se naopak ZAHODILO [M]:** `sim/` = **2 907 řádků = 56,1 % našeho
GDScriptu** (autorita je server) — přežije z ní jen predikční jádro
`walk.gd` + `pathfind.gd` + `map.gd` = **608 řádků (21 %)**. Z `data/`
(**2 751 089 B**) přežije **12 955 B (0,5 %)** — `skills.json` +
`skill_groups.json`, protože 58 skillů je pevných v protokolu — plus
`items.json` (73 % bajtů) **jen jako metadata pro kreslení**. Živé zůstane
**~23–31 % našeho kódu [O]**.

**Ironie, která stojí za zapsání:** (b) by v runtime **muselo** číst
`.mul`/`.uop` z instalace UO — což si náš projekt výslovně zakázal
(`docs/01` §1.5 bod 4) [D].

**Co to přinese:** možnost hrát na cizích shardech — tedy **s jinými lidmi** —
a hotový obsah, který jsme nepsali. **Co to nepřinese:** nic z „UO aparátu",
který si uživatel chce nechat (item properties, řemeslnictví, vlastní ekonomika).

### 1.4 (c) Vlastní klient + vlastní server

**Tohle už z poloviny máme a je to nejdůležitější zjištění téhle analýzy.**
Rozhraní klient/server je v projektu udělané a **vynucené branou**
(`docs/02` §2.2; `tools/gates/check-layers.py`) [D+K]:

| Vlastnost serveru | U nás dnes |
|---|---|
| jediná autorita stavu | `sim/sim_world.gd` (jediný vlastník), klient jen posílá `Command` [K] |
| klient neposílá polohu, jen směr | `Command{t:"move", dir, run}` — poloha v příkazu **není** [K], stejně jako ModernUO [R] |
| `sim/` nesahá na `Input`/`Time`/`OS`/`randf()` | naměřeno: v `sim/` je **0 skutečných** výskytů (jen 2 zmínky v komentářích) [M] |
| pevný tik, deterministický hash, replaye | `sim.tick(50)`, `state_hash()`, `tests/replays/` [K] |
| save s verzí dat (odmítne se při změně dat) | `sim_world.gd::save/load` [K] |

`research/08-multiplayer-poucky.md` §3 už obsahuje **šest kroků k síti** a říká,
které z nich mají cenu i bez multiplayeru (body 1, 5, 6: oddělení vstupu,
save jako transakce s migracemi, testy s reálnými daty) [D].

**Co by (c) navíc potřebovalo [O]:** serializaci `Command`/`Event`, streamování
snapshotů, zájem o okolí (interest management), predikci klienta + snap-back,
samostatný serverový proces a perzistenci světa — tedy práci navíc, ale
**přidanou**, ne náhradní.

### 1.5 Doporučení

1. **Zůstat u (a)** a dodělat hru — protože (a) a (c) sdílejí **100 % UO aparátu**
   a liší se jen dopravou.
2. **Držet (c) jako opci** a nepodkopávat ji: klient má číst **události** a stav
   replikovat, ne sahat na živé objekty simulace. Dnes sahá
   (`app/main.gd` předává `player` přímo do `view.set_player(player)`
   a `controller.setup(player, …)`) — to je **jediná skutečná překážka** pro (c)
   a zároveň něco, co zlepší i (a) (viz oprava B v `REVIZE-POHYB`).
3. **(b) je jiný produkt, ne jiná varianta téhož.** Zahodil by to, co je hotové
   a zdravé, a vyžadoval by to, co je nejtěžší (protokol + gumpy). Kdyby o to
   uživatel stál, patří to jako **samostatný projekt** vedle tohoto, ne místo něj.
4. **Jednosměrnost rozhodnutí:** (a) → (c) je aditivní (nic se nezahazuje),
   (a) → (b) je destruktivní. Proto je správné pořadí „(a) teď, (c) připravené".

---

## 2. NPC, AI a „živý svět"

### 2.1 Kolik NPC mělo UO — naměřeno z jejich vlastních dat [R]

`research/06-world-content-npcs.md` §4.4 (ze `servuo/Spawns/felucca.xml`) a
nové měření spawn dat obou serverů (13. session) — **pozor, jsou to tři různé
čítače téhož slova „NPC"**:

| Faceta | Spawn bodů | Objektů v datech | **Cap (max živých naráz)** |
|---|---:|---:|---:|
| **Felucca** | 2 256 | 9 907 | **16 854** |
| Trammel | 2 572 | — | 18 692 |
| Ilshenar | 472 | — | 2 051 |
| Tokuno | 476 | — | 2 396 |
| Malas | 293 | — | 1 366 |
| TerMur | 124 | — | 1 116 |
| **všechny facety (ServUO)** | **6 465** | — | **43 473** |
| ModernUO (5 612 spawnerů) | | | 58 494, z toho 19 200 reagentů → **~39 294 mobilů** |

**Kolik NPC má jedno město** (ModernUO, obdélníky regionů; cap = součet `count`):

| Město | Celkem v obdélníku | z toho Vendors | TownsLife | TownsPeople |
|---|---:|---:|---:|---:|
| **Britain** | **1 422** | 244 | 314 | 18 |
| Yew | 712 | 40 | 262 | 8 |
| Vesper | 616 | 106 | 160 | 30 |
| Trinsic | 512 | 80 | 96 | 16 |
| Minoc | 166 | 60 | 104 | 2 |
| Cove | 50 | 14 | 34 | 2 |

Tedy: **město má řádově 50–1 400 entit, z toho 14–244 obchodníků**. (Britain
1 422 zahrnuje i pole a les za hradbami — 640 reagentů a 168 plodin.) Omezení
nebylo v datech, ale v tom, že to byl server pro stovky hráčů na procesoru
z roku 1997 — a v tom, že **AI se nikdy nespouštěla pro celý svět** (níže).

### 2.1b Jak UO drželo svět „živý" za pár procent CPU

**Klíčový mechanismus: aktivace podle sektorů** [R]

| Věc | Hodnota | Zdroj |
|---|---|---|
| Velikost sektoru | **16×16 dlaždic** (`SectorSize = 16`) | `Server/Map.cs:397-399` |
| Aktivní okno kolem hráče | `SectorActiveRange = 2` → **5×5 sektorů = 80×80 dlaždic** | tamtéž |
| Kolik to je z mapy | Felucca má 114 688 sektorů → hráč „rozsvítí" **0,022 %** | dopočet |
| Co to znamená | **AI mimo okno úplně stojí** (`m_Timer.Stop()`), nezpomaluje se | `BaseAI.cs:2978-2982, 3072-3079` |
| Návrat domů | spawnutá kreatura se po **15–59 s** teleportuje domů | `BaseCreature.cs:7812` |

**Časování AI** [R]: každé NPC má vlastní `AITimer` s intervalem `CurrentSpeed`
— default **0,2 s v boji / 0,4 s v klidu**, vendor **5 s**, start rozhozen
náhodně 0–1 000 ms (aby netikla všechna naráz). ModernUO navíc periodu
**rozchází jitterem** (`period >> 3`), aby NPC nezůstala v zámku.

**Tři brzdy, které drží cenu na jednom NPC** [R]:

| Operace | Brzda |
|---|---|
| hledání cíle (`GetMobilesInRange` + LOS) | `ReacquireDelay` = **10 s** |
| hledání cesty (A*) | `RepathDelay` = **2 s**, `AreaSize` = **38 dlaždic** (delší cestu vůbec nepočítá), `MaxDepth` = 300 |
| dohled (LOS) | max **25 dlaždic**, bez cache |

**Přepočet pro naši hru [O, odvozený]:** hráč v Britainu → aktivní okno 6 400
dlaždic, v něm řádově **~37 tikajících NPC = ~90–95 `Think()`/s**. Bez
sektorové aktivace by to bylo 43 473 NPC → **~108 000 `Think()`/s**. Rozdíl
tří řádů je celý trik „živého světa" — a je to **design, ne výkon**.

**A co z toho platí i pro jednoho hráče:** sektorová aktivace, rozptyl startu
timerů, brzdy `Reacquire`/`Repath`/`AreaSize`, a doplňování světa spawnerem
s `ReturnOnDeactivate`. Co odpadá: referenční počítání hráčů v sektoru
(`Sector.m_Players`), slicing fronty kvůli mnoha klientům a škálování
update-range podle počtu spojení.

**Referenční časovač, který má cenu okopírovat** [R]: ModernUO má
**hierarchické timer wheel** (4096 slotů, rozlišení **8 ms**, O(1) vložení
i zrušení, `Slice()` zpracuje jen řetěz aktuálního slotu, a hlavní smyčka
**spí**, když není co dělat — `Timer.TimerWheel.cs:30-131`, `Main.cs:757-763`).
ServUO naproti tomu prochází **celý** seznam prioritního bucketu každých
10/25/50/250/1000 ms (`Timer.cs:332-350`) — to je přesně ten rozdíl, který
má náš budoucí `sim.scheduler` řešit.

### 2.2 Jak to UO dělalo (mechanismy, které se mají okopírovat)

| Mechanismus | Hodnota | Zdroj |
|---|---|---|
| Spawner: prodleva | `DefaultMinSpawnTime` **2 min**, `DefaultMaxSpawnTime` **5 min** | `SpawnEntry.cs:12-13` [R] |
| Doplnění při deficitu | `max((Max − live)/3, 1)` — **třetina deficitu za tik** | `SpawnEntry.cs:536` [R] |
| Kreatury se vrací domů | `ReturnOnDeactivate = true` (když AI u hráče není, jdou na `home`) | `SpawnEntry.cs:58-62` [R] |
| AI se vypíná podle vzdálenosti | `PlayerRangeSensitive` | `research/08` bod 8 [D] |
| Priorita AI timeru | `TimerPriority.FiftyMS` | `BaseAI.cs:3057` [R] |
| Nesmrtelné odpadky se mažou | nekrotivované, nezkrocené po **20 h** | `SpawnEntry.cs:74-80` [R] |
| Stráže se vytváří na požádání | `MakeGuard` znovupoužije existující, jinak vytvoří | `GuardedRegion.cs:124-158` [R] |

### 2.3 Co už máme rozhodnuté (a je to moderní)

`docs/05 §5.12` [D]: „regionální spawn tabulky + **jeden world tick** (místo
tisíce spawner objektů)", prodlevy 5–10 min, doplnění 1/3, AI stavy
`idle → wander → aggro → attack → flee → dead` (+ vendor/guard/escort), a
„NPC se nikdy nesmí zaseknout — po timeoutu se vrátí na `home`".

`research/06 §4.7` [D] má navržený **kompletní model pro singleplayer**:

| Věc | Originál | Doporučeno pro nás |
|---|---|---|
| Objekt spawneru | 2 256 objektů na Felucce | **žádný** — statická tabulka `{regionId, rect, spawnGroupId, maxCount, homeRange, respawnSec}` |
| Časovače | jeden timer na spawner | **jeden world tick** (např. 10 s) nad ~1 500 řádky regionů |
| Daleké regiony | — | **zmrazit časovače** a při přiblížení je **dorovnat** (`while (nextSpawnAt < now)`), strop `maxCount` |
| Perzistence | serializuje každý spawner | jen `{regionId, liveEntityIds, nextSpawnAt}` |
| Vendors | spawnuté, restock 60 min | **postavit staticky do světa**, restock na světovém čase |
| Hustota | — | 3–6 nepřátel na 100×100 region; dungeon L1 4–8, hlouběji −1 max ale +1 tier; **vždy nechat bezpečný koridor 8 dlaždic od brány/vchodu/moongate** |

### 2.4 Kolik toho singleplayer zvládne — řádové číslo a jak ho ověřit

**Naměřená kotva [R]:** v UO tiká v Britainu řádově **~37 NPC** (~90–95
`Think()`/s), protože AI mimo 80×80 dlaždic kolem hráče **vůbec neběží**
(§2.1b). To je zvládnutelné i na notebooku a je to hlavně **důsledek návrhu**.

**Odhad pro nás [O]:** se stejnou sektorovou aktivací + brzdami (`Reacquire`
10 s, `Repath` 2 s, A* do 38 dlaždic) je stovka tikajících NPC v GDScriptu
bezpečně v rozpočtu — a **~40 000 rezidentních objektů** je pro paměť nic
(řádově MB). Drahé nejsou počty, ale **pathfinding a LOS** — a ty mají rozpočty
(`MaxSearchNodes = 1000` v ModernUO [R], náš `sim.pathfind` má taky rozpočet [K]).

**Jak to nahradit měřením (návrh, jedna sonda):** headless spustit 500 NPC s AI
na 10 000 tiků a změřit ms/tik proti rozpočtu ze zadání — `docs/01` §1.6 žádá
**simulaci ≤ 2 ms/tick** [D]. Tím se „kolik zvládne" přestane být dohad.

### 2.5 Aby svět „žil" — čtyři vrstvy, každá jinak drahá

1. **Trvalý stav světa** (co hráč udělal, zůstává: mrtví zůstanou mrtví, vybraný
   loot chybí, ceny se hýbou) — nutné pro dojem, že svět není kulisa.
2. **Rozvrhy místo AI** pro městské NPC: domov → práce → hospoda → noc. Mimo
   obrazovku je to jen funkce hodin (skoro zdarma), na obrazovce to vypadá živě.
3. **Ekonomika jako funkce** (`buy = 1,90 × sell`) + reakce na hráče (prodáš
   hodně kůží → cena klesne). Data na to máme.
4. **Události světa**: městský vyvolávač, karavany, počasí, svátky — časovač
   + text, minimální cena, velký efekt.

**A jedno rozhodnutí, které je potřeba udělat:** **žije svět i když je hra
zavřená?** Dnes ne — čas jde jen se zapnutou hrou (`core/clock.gd` + `sim.tick`),
herní den = 2 h [D]. Uložit časovou značku a při načtení svět **dorovnat**
(„co se stalo, než jsi přišel") je pár řádků a mění to pocit ze hry výrazně.
Je to ale rozhodnutí o **mechanice**, ne o kódu.

---

## 3. Moderní organizace objektů a běhu (ECS a spol.)

### 3.1 Co uživatel nejspíš myslí a co to je

„EPS" = **ECS** (Entity–Component–System): entity jsou jen identifikátory,
vlastnosti žijí v komponentách (sloupcích polí) a logika v systémech, které
iterují nad komponentami. Přínos: skládání bez dědičnosti a **cache locality**
(u velkých počtů entit řádově rychlejší iterace).

**Pozor na past v pojmech:** `docs/04` má „100 komponent" — to jsou **moduly**
(granule), ne ECS komponenty. Dvě různé věci se stejným slovem.

### 3.2 Mělo by smysl ECS zavést teď? Ne — a je to měřitelné

| Proti migraci | Číslo |
|---|---|
| Přepsat by se musel celý `sim/` | **2 907 řádků** v 18 souborech [M] |
| Testy jsou psané na dnešní tvar (a jsou to naše brány) | **6 898 řádků** v 40 souborech [M]; 94+ mutačních vzorů [D] |
| GDScript nemá struktury ani SoA pole bez režie | jazyk [K] |
| Determinismus by šel do rizika (pořadí iterace, floaty) | `docs/02` §2.3 to zakazuje [D] |
| Zisk (cache locality) je při ~10³ entitách neměřitelný | [O] |

**Závěr:** ECS teď **nezavádět**. Kdyby jednou entit na 20 Hz bylo >10 000,
správný krok není „ECS v GDScriptu", ale **přesunout `sim/` do C#/GDExtension**
(rychlost i typy) — a to je jiné rozhodnutí než ECS.

### 3.3 Co z „moderních metod" má cenu vzít hned

| Co | Proč | Cena |
|---|---|---|
| **Scheduler (priority queue timerů)** místo „tiká všechno" | spawn, AI, restock, decay, hlad — všechny jsou **řídké události**; dnes tiká všech 15 systémů každých 50 ms. Vzor je hotový a naměřený: ModernUO **timer wheel 4096 slotů, rozlišení 8 ms, O(1) vložení i zrušení**, prázdný slot nestojí nic, smyčka navíc **spí**, když není co dělat (`Timer.TimerWheel.cs:31-131`, `Main.cs:702-763`) [R] | ~100 řádků + testy |
| **Sektorový index** (64×64 dlaždic nad naším 8×8 blokem) | „kdo je v dosahu", aktivace AI, `GetMobilesInRange` bez prohledávání světa | ~100 řádků + testy |
| **Chování NPC jako data** (stavový automat / behavior tree v JSON) | `docs/05 §5.12` už stavy definuje; data = dá se ladit bez zásahu do kódu a testovat | součást `sim.ai` (M5) |
| **Zůstat deterministický** (hash, replaye, žádné `randf`) | už platí a je to naše nejsilnější zbraň | 0 |

### 3.4 Co Godot nabízí místo ručně psaného a co s tím

| Godot | Použití u nás | Verdikt |
|---|---|---|
| `TileMapLayer` | rovná land dlaždice místo `_draw` smyčky | zvážit v rámci `render.chunk_mesh` (M9) |
| `MultiMeshInstance2D` | dávkové kreslení statiků (dnes 1 516 draw callů) | **doporučeno** (M9) |
| `Resource` | data předmětů/receptů | máme JSON — měnit netřeba |
| `AStarGrid2D` | pathfinding | **neměnit**: náš `sim.pathfind` se ptá `walk.can_step`, takže pravidla nejsou duplikovaná (a má na to test) [K] |
| `Node`/`CharacterBody2D` pro pohyb | — | **zakázáno** zadáním (non-goal #2); správně |

---

## 4. Quality of life

### 4.1 Co už mělo samo UO (a patří to k „věrnosti", ne k vylepšením)

Makra a aliasy, „poslední cíl", „použij poslední předmět", obvaz sebe, war/peace,
kouzla na klávesách, `Alt+P/S/K/B` okna, **autorun** a „always run"
(ClassicUO `_continueRunning`, `AlwaysRun` [R]), **klik-to-move s pathfindingem**
(`Pathfinder.AutoWalking` [R]), `[organize` na kontejner. `docs/05 §5.3` je má
vypsané [D].

### 4.2 Co je moderní, levné a mělo by to být

| Návrh | Kde to je dnes | Cena |
|---|---|---|
| **Klik-to-move s cestou a vyznačením trasy** | `sim.pathfind` je **hotový a testovaný**, ale **nikdo ho nevolá** (v `app/` není ani jedna zmínka) [M] | zapojení, malá |
| Fronta příkazů viditelná v UI + „zruš poslední" | `sim.commands` frontu má [K] | malá |
| Tooltip s vlastnostmi předmětu | granule `ui.tooltip` (M2) | plánováno |
| Hledání a třídění v kontejneru/backpacku | chybí | střední |
| Přemapování kláves, UI scale, velikost fontu | granule `app.config`, `ui.options` (M9/M2) | plánováno |
| Cílení: cyklus cílů, HP pruhy, jména | granule `ui.target_cursor`, `render.names` | plánováno |
| Automatizace typu UO Assist/Razor (buy agent, sell agent, scavenger, restock, dress) | chybí; `ui.macros` (M8) je základ | větší, ale **tohle je ta „chytřejší automatizace"**, kterou uživatel chce |
| Přístupnost: barvy nebezpečnosti bez rozlišení červená/zelená, větší kurzor | chybí | malá |

### 4.3 Hranice, kterou je potřeba napsat do `docs/`

Dnešní zadání říká „**žádné „vylepšování" mechanik**" (`docs/01` §1.5 bod 8) [D]
— a uživatel teď QoL výslovně chce. Rozpor se musí rozhodnout, ne obejít.
Navržené pravidlo:

> **QoL smí zkracovat klikání a zlepšovat čitelnost. Nesmí měnit výsledek
> pravidel** (žádný automatický souboj, žádné zkrácení časovačů, žádný loot
> navíc proti tomu, co umělo UO Assist). Kde si nejsme jistí, rozhoduje
> otázka: *„Dostal by hráč tuhle výhodu i v UO s Razorem/UO Assist?"*

**„Krásnější a plynulejší"** není nová práce: je to `render.chunk_mesh` (M9),
`render.light`, `render.effects` a **interpolace pohybu** (oprava B
v `REVIZE-POHYB-2026-10-07.md`) — tedy to, co už je v plánu, jen dřív.

### 4.4 „Prohloubení systémů" — kde je největší efekt za nejmenší práci

Nejlevnější hloubka je tam, kde **už máme data**: 1 053 receptů
(`data/recipes.json`), 8 748 předmětů (`data/items.json`), 1 495 typů těl
(`data/mobtypes.json`), 58 skillů. Konkrétně: rozšířit `sim.craft` o kvalitu
a neúspěch (materiál se ztrácí), **krotitelství a mounty** (data máme), **knihy
a psaní** (UO klasika, skoro zdarma), **rybolov a treasure mapy**, **NPC rozvrhy
a ekonomika, která reaguje**. Naopak **housing a lodě** jsou vyloučené
(`docs/01` §1.4) a byly by to nové systémy, ne hloubka.

---

## 5. Co bych ještě vypíchl (osm bodů, na které se neptal)

1. **Právní stav se nemění ani v jedné variantě — ale u (b) je jiný, než by
   člověk čekal** [M]. Assety z UO jsou EA a v repu nejsou (`.gitignore`) [D];
   ClassicUO to má stejně („nedistribuujeme žádné chráněné assety, hru si
   legálně pořiďte") a navíc **výslovně zakazuje** připojení vlastním klientem
   na **oficiální** servery — cílem jsou free shardy. Pozor na dvě věci
   v jejich repu: `LICENSE.md` říká **BSD-2**, ale `README.md` na jiném místě
   **BSD-4** (vnitřní rozpor téhož repa) a hlavičku SPDX má **374 z 455**
   souborů. Licence serverů: **RunUO GPLv2, ServUO GPLv2, ModernUO GPLv3,
   Sphere Apache-2.0** — a v našem `ZADANI-UO-KLON.md:113-115` **RunUO v tom
   seznamu chybí** (drobná vada dokumentu, patří doplnit).
2. **Perzistence je ta pravá práce „živého světa".** Save dnes ukládá jen
   obálku simulace (`mobiles: []`, `items: []`) [K]. Až přijdou předměty a NPC,
   save poroste a bude potřebovat **migrace** (`research/08` bod 5) [D].
3. **Obsah, ne engine, je zbytek projektu.** Přijímací kritéria C1–C9
   (`docs/06` §6.8) chtějí ≥250 předmětů, ≥600 receptů, 64 kouzel, ≥40 monster,
   ≥25 vendorů, 3 dungeony [D]. To je **datová práce**, která se dá dobře
   paralelizovat — a je to ta „levná" část, kterou uživatel chce nechat.
4. **„Živý svět" se musí měřit, ne obdivovat.** Návrh bran: headless 24 h
   světového času → (a) populace v každém regionu zůstane v rozpočtu,
   (b) žádné NPC nezůstane v neplatném stavu (dnes je jen slib v `docs/05 §5.12`),
   (c) restock proběhl N×, (d) dva běhy se stejným seedem dají stejný hash.
   Bez toho skončíme u „vypadá to živě".
5. **Rozpočet na AI už existuje:** `docs/01` §1.6 žádá **simulaci ≤ 2 ms/tick**
   [D] — AI, spawn i ekonomika se do něj musí vejít. To je lepší kotva než
   „kolik NPC zvládneme".
6. **Žádné nové závislosti** (non-goal #5) [D]: ECS knihovny, behavior tree
   pluginy a podobně potřebují zápis do `docs/`, jinak vznikne druhý zdroj pravdy.
7. **Determinismus je naše konkurenční výhoda**, ne omezení: replaye, hash,
   testy bez okna. Multiplayer by ho potřeboval ještě víc (predikce a snap-back
   se ladí jen proti deterministické simulaci).
8. **Největší riziko projektu není architektura, ale to, že se „hotovo" měří
   špatně.** Šest vad pohybu prošlo 954 kontrolami, protože všechny měřily
   *přítomnost*, ne *průběh v čase* (`REVIZE-POHYB-2026-10-07.md` §4).
   Ať se rozhodne (a)/(b)/(c) jakkoli, **brány na chování v čase** budou
   potřeba všude.

---

## 6. Co to mění v odsouhlaseném plánu oprav

| Oprava (z `REVIZE-POHYB-2026-10-07.md` §5) | Platí pro (a) | pro (c) | pro (b) |
|---|---|---|---|
| **A** kadence kroku | ano | ano | **ano** |
| **B** interpolace + animace v jedné fázi + klient čte události | ano | ano (a je to **krok k (c)**) | **ano** |
| **C** pravidla chůze (most, kopec, Bridge) | ano | ano | **zbytečné** (autorita je server) |
| **D** směr z myši (obrazovkové pravidlo) | ano | ano | **ano** |
| **E** `PriorityZ` v řazení | ano | ano | **ano** |
| **F** `render.chunk_mesh` (M9) dopředu | ano | ano | **ano** |

**Tedy:** pět ze šesti oprav má cenu ve všech třech variantách. **Začít se dá
hned** a rozhodnutí a/b/c nemusí nic blokovat — kromě opravy **C**, která má
smysl jen tam, kde jsme autorita (a) a (c).
