# 5. Mechaniky — co musí hra dělat

> **Normativní zdroj čísel:** `research/01-core-mechanics.md`,
> `03-combat-magic-items.md`, `04-gathering-crafting.md`, `02-skills.md`,
> `06-world-content-npcs.md`. Tenhle oddíl říká **co platí pro klon**
> (a když se zdroje rozcházejí, který jsme vybrali a proč).
> Číslo bez zdroje je `UNVERIFIED` — a to se v kódu nesmí objevit jako fakt.

## 5.1 Pohyb (§ V2)

### 5.1.1 Rychlosti (ověřeno ve třech nezávislých kódech)

> **DOPLNĚNO 2026-10-10 (`M1`): hodnoty v tabulce jsou VÝCHOZÍ, ne zamrzlé.**
> Chůze a běh se čtou z `data/balance.json` (`movement.walk_ms` / `run_ms`),
> výchozí 400/200 ms; co v datech není, platí z `core/const.gd`. Mount
> (200/100 ms) do dat patří, až bude mount existovat. Důvod, proč tempo není
> zákon: `docs/05` §5.1.4 a `ROZHODNUTI-2026-10-10-MODERNI-UO.md` (M1).

| Stav | Prodleva na krok | Zdroj |
|---|---|---|
| Chůze pěšky | **400 ms** (výchozí) | ServUO `Server/Mobile.cs:3063`, ModernUO `…/Movement.cs:33`, ClassicUO `…/MovementSpeed.cs:12` |
| Běh pěšky | **200 ms** (výchozí) | totéž |
| Chůze na mountu | **200 ms** | totéž |
| Běh na mountu | **100 ms** | totéž |
| Otočení na místo | **80 ms** (klient) / **0 ms** (server) | ClassicUO `Constants.cs:17`, ModernUO `Movement.cs:32` |
| Frame animace postavy | **80 ms** | ClassicUO `Constants.cs:13` |

Mount = přesně 2× rychlost pěšky. To se v žádné éře neměnilo.

**⚠ DOPLNĚNO 2026-10-06 — pravidlo je SERVEROVÉ a klient má jinou konstantu téhož
jména.** Prodleva kroku **400 ms je pravidlo serveru** (ServUO `Server/Mobile.cs:3063`,
ModernUO `Movement.cs:33`); klient ho jen respektuje. ClassicUO má ale **dvě různé
věci**, které se pletou:

- `src/ClassicUO.Client/Game/Data/MovementSpeed.cs:12` — `STEP_DELAY_WALK = 400`,
  tj. **jak často klient smí poslat krok** (totéž pravidlo na straně klienta),
- `src/ClassicUO.Client/Game/Constants.cs:19` — `WALKING_DELAY = 150`,
  tj. **tempo lokální animace** (v kódu s komentářem `// 750`), **ne** pravidlo pohybu.

**Kdo si vezme 150 jako prodlevu kroku, udělá krok 2,7× rychlejší** (400 / 150 = 2,67).
Stejná past jako u otočení a animace: `Constants.cs:17 TURN_DELAY = 80` (otočení na
místě) a `Constants.cs:13 CHARACTER_ANIMATION_DELAY = 80` (frame animace) jsou dvě
různé věci se stejnou hodnotou — proto je tabulka výš uvádí jako dva řádky.

### 5.1.2 Algoritmus průchodnosti (jádro shody s referencí)

Konstanty: `PERSON_HEIGHT = 16`, `STEP_HEIGHT = 2`.

1. **Povrch a stojná výška se berou z HORNÍCH HRAN, ne z jednoho `z`.**
   Kandidátem na povrch cílové dlaždice je land a statiky se `Surface` **bez**
   `Impassable`; vyhrává ten, jehož stojná výška je postavě **výškově nejblíž**
   (rovnost → nižší). Stojná výška landu je `landCenter` (průměr dvojice rohů
   s větším absolutním rozdílem, celočíselně dolů; `Map.GetAverageZ`,
   `_src/servuo` `Server/Map.cs:552-607`), u statiku `z + CalcHeight`
   (`CalcHeight` = `Bridge` ? výška/2 : výška, `TileData.cs:112-125`).
2. **Blokuje se**, když `stepTop = startTop + STEP_HEIGHT` (kde `startTop` je
   **nejvyšší roh** dlaždice, na které postava stojí) nepřekročí horní hranu cíle
   — u landu `landLow` (**nejnižší** roh), u statiku `itemTop` (`z + (Bridge ?
   0 : výška)`). Navíc blokuje statik se `Impassable`/`Container`/zavřené dveře,
   jehož pásmo `[z, z + max(výška, 1))` se protne s pásmem postavy. **Dolů
   žádný limit není** (`Movement.cs` dolní mez nezná).
   > ⚠ **PŘEPIS 2026-10-07 (14. session, vady V4 a V5).** Dřív tu stálo „bere se
   > nejvyšší povrch" a „blokuje se, když se interval `[z, z + výška_dlaždice)`
   > protne s `[z_postavy, z_postavy + 16)` — s povoleným krokem 2". To bylo
   > **měřením vyvráceno jako přísnější než UO**: 4 013 z 165 985 kroků do kopce
   > (2,4 %) reference povolí a my je blokovali (`_analyza/vada-svah.py`), a most
   > nad vodou byl nedosažitelný (`_analyza/vada-most-mapa.py`). Nové znění je
   > přepsané podle `_src/servuo` `Movement.cs:170-171`, `:211-343`,
   > `Map.cs:552-607`, `TileData.cs:112-125`; důkaz: `_analyza/vlna14-svah-most.gd`
   > (před: 14 965 kroků blokovaných, které reference povolí; po: **0**).
3. Z **všech** flagů dlaždice mají na pohyb vliv jen **`Impassable`, `Surface`,
   `Wet`** (a výjimečně `Door` a `Container`). `Wall`, `Window`, `Roof`,
   `Foliage`, `NoShoot`, `StairBack`, `StairRight` pohyb **neovlivňují**.
4. **Diagonála je asymetrická:** hráč potřebuje průchodné **obě** ortogonální
   sousední dlaždice, NPC/GM **jen jednu**. To je důvod, proč se hráč zasekává
   o rohy a monstra je hladce obcházejí. **Tohle musí být v kódu výslovně**
   (parametr `is_player`), jinak se „podivné zasekávání" nebude dát vysvětlit.

### 5.1.3 Predikce a potvrzení (proč to musí být klient/server i v single-playeru)

Klient **posune sprite okamžitě** a pošle záměr; simulace odpoví
**potvrzením** nebo **odmítnutím**, a při odmítnutí klient **vrátí postavu
zpět** (snap-back). Fronta povolených kroků = **4** (fastwalk stack).
Důsledek pro implementaci: `Command{t:"move"}` se **nezamítá v UI**, ale
v simulaci; UI drží „predikovanou" pozici, dokud nedorazí událost.

### 5.1.4 Stamina

| Věc | Rozhodnutí | Poznámka |
|---|---|---|
| Spotřeba při běhu | **1 bod za každý krok běhu**, chůze zdarma | doporučení výzkumu; **v emulatech je to jinak** (1 za 16 kroků včetně chůze) → `UNVERIFIED`, měřit |
| Konfigurace | `data/balance.json: stamina_drain_model: "run_only" | "emulator"` | obojí implementované, default `run_only` |
| Regenerace | podle DEX a hladu (`sim.regen`) | čísla z `research/01` §1.4 |
| Váha (encumbrance) | nad nosnost se pohyb zpomalí/znemožní | `research/01` §1.5 |

**Pravidlo (PŘEPSÁNO 2026-10-07 — dřív tu byl zákaz, naměřeno jako věcně
nesprávný; DOPLNĚNO 2026-10-10 rozhodnutím `M1`):** pohyb je **diskrétní krok**
(400 ms chůze / 200 ms běh) a **prodleva kroku je výchozí hodnota v datech**, ne
zamrzlé pravidlo — kdo mění dojem z tempa, mění `data/balance.json`, ne
mechaniku. **Klient ale SMÍ vykreslit posun mezi dlaždicemi plynule:**
referenční klient to přesně tak dělá (ClassicUO `Mobile.cs:776-782`
a `MovementSpeed.GetPixelOffset` — dlaždici potvrdí až na **konci** kroku, do té
doby kreslí postavu posunutou o pixely, a **týž 80ms clock řídí i framy
animace**). Původní zákaz („lerp mezi dlaždicemi jako moderní hry") vycházel
z omylu o tom, co UO dělá, a jeho důsledkem bylo, že animace chůze byla
**v protifázi s pohybem** (doklad: `REVIZE-POHYB-2026-10-07.md` §2.2).

**Proč se 2026-10-10 změnilo „to je pravidlo simulace a nemění se":** prodleva
kroku je v referenci **anti-cheat throttling, ne design** — ServUO má fastwalk
detekci výslovně **vypnutou** s odůvodněním, že ji nahradilo „movement packet
throttling" (`_src/servuo/Scripts/Misc/Fastwalk.cs:5-6,10`) a ModernUO má na
totéž `MovementThrottle` s prahy a detekcí speedhacku
(`_src/modernuo/Projects/Server/Network/MovementThrottle.cs:23-28,42-51`).
Doložení pro „400 ms je designový záměr" → **NENALEZENO**. Rozhodnutí a ceny:
`ROZHODNUTI-2026-10-10-MODERNI-UO.md` (M1).

**Co zůstává pravidlem (a mění se jen se zápisem v `docs/`):** **průchodnost**,
**dosah** a **spotřeba staminy**. Plynulost je věc **vykreslení**, ne mechaniky.

## 5.2 Interakce mezi objekty (§ V3)

### 5.2.1 Sémantika kliknutí (musí být přesně tahle)

| Akce | Výsledek |
|---|---|
| Levý klik na objekt | vybere cíl, zobrazí jméno (single click = label) |
| **Dvojklik** | „use" — otevře/použije/promluví (routing níže) |
| Pravý klik na objekt | kontextové menu (AoS+) — seznam akcí, čísla ≥ `0x64` pro vlastní |
| Pravý klik / klik na sebe | kontextové menu postavy (paperdoll, status, skills, …) |
| Levý klik do světa | chůze k dlaždici (click-to-move); s „always run" běh |
| Tažení předmětu | zvednutí (drag) → kurzor nese předmět → položení (drop) |
| Esc | zruší kurzor cíle / zavře menu |

### 5.2.2 Routing „use" — jediná tabulka rozhodování

`sim.interaction.use(m, serial)` rozhoduje v tomto pořadí (a každá větev má
test):

| Cíl | Akce |
|---|---|
| dveře (`world.doors.is_door`) | otevřít/zavřít: `toggle` přepne art na `art + 1` (otevřeno) a zpět, zvuk, změna průchodnosti |
| kontejner (batoh, truhla, tělo, banka) | otevřít gump s obsahem (`event container_contents`) |
| vendor (NPC s `vendor` flagem) | otevřít obchodní gump (buy/sell) |
| nástroj (pickaxe, kladivo, jehla, …) | přepni do „čekám na cíl" → `target_request` |
| svitek / spellbook | sesli kouzlo / otevři knihu |
| lektvar / jídlo | vypij / sněz (spotřeba, efekt) |
| zbraň / zbroj | nasaď (drop na vrstvu) |
| runa | otevři menu (mark/recall) |
| uzel suroviny (hora, strom, voda) | spusť sběr (pokud má hráč nástroj) |
| monstrum/NPC | promluv (NPC) nebo útoč (monstrum) |
| tělo (corpse) | otevři loot |
| **neznámý předmět** | hláška „You see nothing special." — **nikdy ticho** |

### 5.2.3 „Použij na cíl" (use-on) — párové kombinace

Tohle je **kontrolní seznam z `Tilehelp.enu`** (originální nápověda klienta).
Každý řádek musí mít v klonu protějšek:

| Použiji | na cíl | Výsledek |
|---|---|---|
| ore (dvojklik) | forge | tavení na ingoty (Mining) |
| ore | další ore | spojení hromádek |
| ryba | nůž/sekera | rozporcování na steaky |
| vlna / len | kolovrat | nit/příze |
| nit / příze | stav (loom) | látka (bolt of cloth) |
| látka | nůž | obvazy (bandages) |
| obvazy | zraněný člověk / zvíře | Healing / Veterinary |
| klíč | dveře / kontejner | odemkni/zamkni |
| key blank | klíč | kopie klíče (Tinkering) |
| lockpick | dveře / truhla | Lockpicking |
| lucerna | lucerna (druhá) | doplnění oleje |
| pochodeň | oheň | zapálení |
| svitek | spellbook | přepis kouzla do knihy |
| pero a inkoust | svitek | Inscription (výroba svitku) |
| hmoždíř | reagent | přidání do hmoždíře (alchymie) |
| láhev (empty) | hmoždíř s hotovým lektvarem | naplnění |
| těsto | voda / mísa / med | těsto, sladké těsto, cake mix |
| mouka (sack) | mlýn | flour |
| pšenice (sheaf) | mlýn | flour |
| zrno | mlýn | flour |
| nůž | mrtvola zvířete | stažení kůže, maso, peří |
| nůž | strom/kláda | carve arrow shafts / bow (Bowcraft) |
| nůž | ovce | stříhání vlny |
| kladivo | kovadlina (s ingoty) | kovářství (gump) |
| jehla a nit | kůže/látka | krejčovství (gump) |
| pila / dláto | dřevo | truhlařina (gump) |
| tinker tools | kov | tinkering (gump) |
| tavicí tyglík (mortar) | — | alchymie |
| lopata | písek/hlína | kopání |
| srp | obilí | sklizeň |
| vědro | studna/sudy | voda |
| pochodeň/lucerna | — | světlo (změna `light_level`) |
| měch (bellows) | oheň | rozdmýchání (zvuk, efekt) |
| runa | moongate | označení/teleport |
| sextant | — | souřadnice v žurnálu |
| hodiny | — | herní čas |

**Přijímací kritérium pro tenhle oddíl:** každý řádek tabulky má v kódu
větev **a** test. Když větev chybí, hra na použití odpoví hláškou
(ne tichem) — a chybějící řádek se počítá jako nehotová práce.

## 5.3 Ovládání a UI (§ V1)

| Prvek | Podoba |
|---|---|
| Pohled | izometrický, kamera sleduje postavu; okraje obrazovky posouvají pohled |
| Rozlišení | 1280×720 default, zoom 1×/2× celočíselně |
| Lišta | `paperdoll` (postava, vrstvy, war/peace), `status bar` (HP/Stam/Mana, váha, zlato) |
| Batoh | gump batohu; dvojklik otevře; drag & drop mezi batchem, kontejnerem a tělem |
| Skill list | 58 skillů, hodnota v desetinném formátu (0.0–100.0/120.0), zámek `up/down/lock`, tlačítko „use" |
| Spellbook | 8 kruhů × 8 kouzel; ikony lze přetáhnout na lištu |
| Žurnál | textové zprávy (systém/mluv/boj/výroba) s barvami; scroll |
| Kurzor cíle | vizuálně odlišný (object / ground / self), časový limit, Esc ruší |
| Makra | poslední cíl, použij poslední předmět, obvaz sebe, war/peace, čísla kouzel |
| Klávesy | výchozí sada jako UO (F1 help, Alt+P paperdoll, Alt+S status, Alt+K skills, Alt+B spellbook…) — přesná sada je **rozhodnutí**, zapsané v `docs/` (ClassicUO bindings jsou konfigurovatelné, ne protokol) |

**Pravidlo UI:** UI je „tenký klient". Nikdy nepočítá pravidla (cenu, damage,
úspěch výroby) — ta počítá simulace a UI je jen zobrazí.

## 5.4 Manipulace: předměty, kontejnery, výbava (§ V4)

| Věc | Hodnota (ověřeno) | Poznámka |
|---|---|---|
| Dosah zvednutí i položení | **2 dlaždice** (server) | klient dovolí gesto na 3 — to je jen UI |
| Max. hromada (stack) | **60 000** | |
| Kontejner | **125 předmětů / 400 stones**; batoh **400** (550 v ML+) | banka bez limitu |
| Zlato | předmět `0x0EED`, váha **0.02 stones** | ano, zlato váží |
| Rozpad na zemi | **60 minut** | |
| Tělo (corpse) | rozpad **7 min**, právo na loot **2 min** | |
| Vrstvy výbavy | 0x00–0x1F (viz slovník §11.7); vrstva `0x1E` = neviditelnost pro ostatní | |
| Blessed / newbie | `blessed` zůstává po smrti; `newbie` též | |
| Zamčené kontejnery | `flags & 0x04` — nelze otevřít bez klíče/lockpicku | |
| Trvanlivost | opotřebení zbraně ~2,5 %/zásah, zbroje ~25 %/zásah (macing jinak) | `research/03` |
| Oprava | skill check, možnost **snížit max. trvanlivost** | `research/04` §repair |
| Váha a nosnost | `40 + STR` (nosnost), přetížení blokuje běh a postupně i chůzi | `research/01` §1.5 |

**Pravidlo stackování:** stejný `tile` + stejná `hue` + `stackable` flag
(v tiledata) = sloučí se do `MAX_STACK`; jinak nový předmět.

## 5.5 Souboj (§ V5)

### 5.5.1 Vybrané vzorce (a proč)

| Věc | Rozhodnutí klonu |
|---|---|
| **Swing delay** | **AoS**: `floor(40000 / swiftness) × 0.5 s`, dolní mez **1.25 s**; SSI (Swing Speed Increase) strop **60 %** |
| **Hit chance** | **AoS**: `((atk + 20) × (100 + HCI)) / (2 × (def + 20) × (100 + DCI))`, HCI/DCI strop **45** |
| **Kdo je `atk`/`def`** | **zbraňový skill** útočníka vs **zbraňový skill** obránce. **`Tactics` je damage skill, ne přesnost** (častý omyl!) |
| **Damage** | **AoS**: `base + base × součet bonusů` (STR 0.300/+5@100, Anatomy 0.500/+5, Tactics 0.625/+6.25, Lumber 0.200/+10), DI strop **100 %**, **bez půlení** proti hráčům |
| **Obrana** | **AoS**: `Σ(dmg × podíl × (100 − resist)) / 10000`, minimum 1, strop přímého damage 35 |
| **Parry** | štít `(Parry − Bushido)/400`; obouruční zbraň `Parry × Bushido / 48000` |
| **Archery** | stání na místě 1000/500/250 ms dle éry, munice se spotřebuje **při každém** výstřelu, 40 % návratnost, dostřel 7–10. **DOPLNĚNO 2026-10-10 (`M2`): zásah se počítá v okamžiku výstřelu, let šípu je jen VIZUÁLNÍ efekt** — přesně tak to dělá reference (`_src/servuo/Scripts/Items/Equipment/Weapons/BaseRanged.cs:91-102` = `Swing` → `OnFired` → `CheckHit` → `OnHit`, let je `MovingEffect` na `:221`). Projektil, který rozhoduje o zásahu, je **odchylka** (nová smlouva, +3–6 granulí) |
| **Healing obvazy** | vzorce AoS i klasika + prodlevy + podmínky `60/60` pro vyléčení a `80/80` pro vzkříšení (v `research/03`) |
| **Zvláštní útoky** | 31 útoků s přesnou cenou many a branami 70/90 skillu |

**Proč AoS a ne klasika:** klon má věrné **rozhraní** (AoS UI, kontextová
menu) a **soubojové vzorce AoS**, protože data z instalace jsou moderní
(resisty, vlastnosti předmětů, `ItemPropertyInfo`) — míchat klasický damage
s AoS itemizací by dalo nekonzistentní ekonomiku. **Klasické vzorce jsou
v `research/03` popsané také** — přepnutí je konstanta
(`data/balance.json: combat_era`), ne přepis kódu.

### 5.5.2 Co musí být vidět a slyšet

- Animace útoku (frame podle směru), zvuk zásahu, číslo damage v žurnálu,
  jméno cíle a jeho HP pruh po kliku, smrt a tělo s lootem.
- **Let projektilu je vidět, ale nerozhoduje** (`M2`): zásah se počítá při akci,
  let je efekt — kdyby let rozhodoval, mění se balanc (uhýbání) i smysl
  automatizace (`D3`).
- `war/peace` režim (v klidu hráč neútočí omylem).
- Combat timer: po posledním zásahu se cíl „zapomene" po známé prodlevě.

## 5.6 Magie (§ V6)

| Věc | Hodnota (ověřeno) |
|---|---|
| Kouzel | **64** (8 kruhů × 8) |
| Mana podle kruhu | `{4, 6, 9, 11, 14, 20, 40, 50}` |
| Prodleva sesílání | **AoS**: `(4 + kruh) × 0.25 − FC × 0.25`, min **0.25 s**; klasika: `0.5 + 0.25 × kruh` |
| Faster Casting (FC) | strop **2** pro Magery |
| Faster Cast Recovery (FCR) | strop **6**, zotavení `max(6 − FCR, 0) / 4` |
| Skill pásmo kouzla | `100 / 7 × kruh ± 20` (zdrojový vzorec; OSI tabulka je aproximace — obojí v `research/03`) |
| Reagenty | **1 od každého** dle `SpellInfo` daného kouzla; Lower Reagent Cost = **jeden hod na seslání** (ne per reagent!) |
| Přerušení | zásah během sesílání přeruší (mimo `Protection`) |
| Spellbook | 64 slotů; přepis ze svitku tažením; při smrti zůstává duchovi |

**Přijímací kritérium:** `cast` bez reagent → `{ok:false, reason:"reagents"}`
a **žádná mana se neodečte**; `cast` s many i reagenty → po `delay_ms`
proběhne efekt, reagenty zmizí, `skill_gain.check(Magery, …)`.

## 5.7 Sběr surovin (§ V8)

| Systém | Klíčová čísla (ověřeno) |
|---|---|
| **Mining** | 9 rud s požadavkem skillu **0/65/70/75/80/85/90/95/99**; šance žíly 49,6 % → 1,4 %; 50% fallback na iron; „buckety" 8×8 dlaždic, 10–34 rudy; respawn **10–20 min**; písek, žula, drahokamy, niter |
| Shoda dlaždice | `(ItemID & 0x3FFF) | 0x4000` — přesně tohle pravidlo určuje, které dlaždice jsou „hora". **Kód je v `sim/systems/harvest.gd` (2026-10-08)** a seznam dlaždic je v něm (316 id hor, 149 id stromů, 6 párů vodních id) — v `data/` nejsou |
| **Lumberjacking** | buckety 4×3, **20–45 logů** (`Lumberjacking.cs:46-47`; dřív tu stálo 10–45 — měřeno špatně), **10 logů za ÚDER** (dřív tu stálo „za sek"), respawn **20–30 min** (v dokumentu chybělo), 7 druhů dřeva, **1 log → 1 prkno**; bonus k damage sekerou `(LJ × 0.2 + (LJ ≥ 100 ? 10 : 0)) / 100` |
| **Fishing** | **8 s na pokus**, hluboká voda od **75** skillu; mělká voda: `Fishing ≥ 75` uspěje **bez hodu** (`CheckHarvestSkill` v `Fishing.cs`); speciální úlovky (síť 1,12 %, mapa 1,11 %, láhev 2,99 %) |
| **Kůže** | stažení zvířete nožem, druhy kůží dle zvířete. **⚠ UNVERIFIED:** v `HarvestSystemu` žádný Healing/Anatomy gate není (jediný nález `BaseCreature.cs:2223`, `cutHides`) — kdo to bude dělat, ať to nejdřív změří |
| Nástroje | opotřebení **jen při úspěšném** skill checku (1 use). **⚠ V klonu se neopotřebuje — stav 2026-10-10:** `mine/chop/fish` mají 3 argumenty a nástroj se do nich neposílá. `sim/entity/equipment.gd` **už existuje** (commit `36cbe5c`), takže **překážka zmizela**: opotřebení je teď **neudělaná práce (nová granule)**, ne chybějící základ. Do té doby platí, že nástroj vydrží věčně |

**Přijímací kritérium:** `mine(m, x, y)` se špatnou dlaždicí vrátí
`{ok:false, reason:"not_ore"}`; se správnou horou vrátí rudu;
**respawn** žíly se po vyčerpání obnoví za 10–20 min (test s posunem času).
**⚠ Opraveno 2026-10-08:** dřív tu stálo „se špatným `z`" — to je nesplnitelné,
smlouva `z` nemá a `sim.interaction` ho zahazuje (`interaction.gd:323`).

## 5.8 Výroba (§ V9)

**Zdroj receptů:** `research/04-craft-data.json` — **1053 receptů**
(Blacksmithy 196, Tailoring 198, Carpentry 223, Tinkering 165, Cooking 88,
Masonry 59, Alchemy 51, BowFletching 27, Glassblowing 22, Inscription 16,
Cartography 8). Do klonu se dostanou **generátorem** do `data/recipes.json`,
ne ručním opisem.
**⚠ Naměřeno 2026-10-08 (16. session):** dokument dřív tvrdil **1150**; rozdíl
97 jsou **svitky kouzel** (64 Magery + 17 Necromancy + 16 Mysticism), které
`research/04-gathering-crafting.md` §5.5 má jen jako **markdown tabulky** —
`research/04-craft-data.json` je neobsahuje, takže je generátor nemůže vyrobit.
Do `data/recipes.json` se dostanou, až se §5.5 převede na data (samostatná
práce); dokud ne, je správné číslo **1053**.

| Věc | Vzorec / pravidlo (ověřeno) |
|---|---|
| Šance na úspěch | `floor + (val − min) / (max − min) × (1 − floor)`; `floor` = `GetChanceAtMin` systému: **Tailoring/Carpentry/BowFletching 0.5**, ostatní 0.0 (`Def*.cs`); při `max` skillu 100 % |
| Exceptional | tři režimy: kovářství/krejčovství/truhlařina/tinkering/vaření `−0.60` slábnoucí k `−0.45`; lukovství `chance/2 − 0.10`; default `−0.60` |
| Dvojitý hod | exceptionalita z **1. hodu**, úspěch z **2. hodu** (`CraftItem.cs:1352-1359`; **reference je ServUO, ne ClassicUO** — klientský `CraftItem.cs` v `_src/classicuo` neexistuje, ověřeno 2026-10-08) |
| Kvalita | `Low 0 / Normal 1 / Exceptional 2`. **⚠ Naměřeno 2026-10-08: `Low` z výroby NIKDY nevznikne** — `quality` startuje na 1 a jediné přiřazení v cestě je `quality = 2` (`CraftItem.cs:1354-1356`); `PlayEndingEffect` větev pro 0 má, ale nikdo ji nenastaví. Klon proto vyrábí fail/normal/exceptional a test to měří (60 pokusů, 0× Low) |
| Značka výrobce | jen když `quality == 2` **a** `MainSkill >= 100`; `entity.item` pole `maker` nemá → `props["maker"]` |
| Nástroj | **−1 use na pokus** (úspěch i neúspěch) |
| Neúspěch | spotřebuje **plný materiál** (kromě **25** typů v `_GlobalNoConsume`, `CraftSystem.cs:268-288`; dřív tu stálo 18); u `UseAllRes` polovinu (floor 1) |
| `UseAllRes` | místo `count` se vezme celá hromada: `maxAmount = min(have/need)`; při neúspěchu se **půlí** |
| Exceptional efekt | +14/+15 resist, +20 % trvanlivosti, zbraň +35 WeaponDamage, nástroje 2× uses |
| Tavení rudy | **není paušálně 1:1**: střední hromada (0x19B8) 1:1, malá (0x19B7) **půlí**, velká (0x19B9) **×2** (`Ore.cs:385-399`); skill gate podle kovu 50–99 (iron gate nemá); neúspěch půlí hromádku |
| Zpětné tavení | `floor(66 %)` ceny předmětu v ingotech; koupené = 1 ingot; jen když primární cena ≥ 2 |
| Oprava | šance oslabit `40 + (max − cur) − skill/10` %; obtížnost `((max − cur) × 1250 / max) − 250` desetin; `CheckSkill(diff ± 25)` |
| Ekonomika | plná plátová zbroj = **100 ingotů** (= 100 rudy); ringmail 58; chainmail 48; smelt ztráta 34 %/cyklus |
| Zpracování | `sim/systems/craft.gd` (**hotové 2026-10-08**): `recipes_for` vrací i recepty nedostupné (`available: false`) a nevyrobitelné (`craftable: false`); **699 z 1053 receptů nemá `tile` výsledku** (generátor to hlásí do `content-report.json`) a `craft` na ně vrací `{ok:false, reason:"no_result"}` — nikdy fiktivní tile |

**Přijímací kritérium:** `craft(dagger, count=1)` se 3 ingoty a dostatkem
skilu → v batohu dagger (nebo hláška o neúspěchu) a **ingoty spotřebovány**;
bez kovadliny `{ok:false, reason:"anvil"}`; neverejný recept (málo skillu)
je v gumpu **zešedlý**, ale viditelný.

## 5.9 Obchod a ekonomika (§ V7)

| Věc | Hodnota (ověřeno) |
|---|---|
| Vztah cen | **`buy_price = 1.90 × sell_price`** (žádné smlouvání, žádné slevy za množství v této éře) |
| Základ ceny | z tiledata `value` (předmětu) — **závisí na vyřešení O1** |
| Restock | **60 min**, líně (až při otevření gumpu) |
| Gump | max **250 řádků** |
| Zlato | předmět, váha 0,02; platí se z batohu |
| Banka | box `0x0E7C`, neomezená váha, jen majitel |
| Stable | **30 gp / zvíře / týden**, sloty dle skillu Animal Taming |
| Krádež/flag | kriminální flag **2 min**, vrah od **5 vražd**, odečet 1 za 40 h (online) |
| Guard zóny | města; útok v zóně → guard (chování `UNVERIFIED`, viz O-výzkum) |

**Přijímací kritérium:** prodej 10 kusů předmětu X vrátí
`10 × sell_price(X)` zlata; nákup odečte `amount × buy_price` a přidá
předmět; bez zlata `{ok:false, reason:"gold"}` a **žádná změna stavu**.

## 5.10 Skilly a jejich vývoj (§ V10)

| Věc | Hodnota (ověřeno) |
|---|---|
| Reprezentace | **desetiny** (`int`): 0–1000 = 0.0–100.0; strop 1200 s legendárním svitkem |
| Růst | pevný krok **+0.1**; šance dle obtížnosti a rozdílu skillu (tabulka v `research/01` §3.3.1) |
| Celkový strop | **700.0** (720 s odměnami) |
| Zámky | `up / down / locked` na každý skill; při dosažení stropu se ubírá skills označeným `down` |
| GGS | garantovaný růst **zapnutý** (offline hraní bez něj není rozumné) |
| Stat gain | z používání skillu, interval **15 min** (hráč) / 5 min (pet); stat cap **225**, individuální **125** |
| Anti-macro | **vypnuté** (v single-playeru nemá smysl); konstanta pro zapnutí |

**Přijímací kritérium:** 100 pokusů `check(skill=Blacksmithy, difficulty=0)`
při hodnotě 0 → hodnota > 0; při hodnotě na stropu se **nezvýší** a hráč
dostane hlášku; `state_hash` po 10 000 pokusech je stejný ve dvou bězích.

### 5.10.1 Tři věci, které se v této oblasti pletou (ověřeno v `research/02`)

1. **Vliv statů na hodnotu skillu je v AoS+ vypnutý** (`AOS.DisableStatInfluences()`
   vynuluje `StrScale`/`DexScale`/`IntScale`) → **efektivní skill == základní
   skill**. Klon tedy žádné „skilly ovlivněné staty" neimplementuje; staty
   ovlivňují jen životy, staminu, manu a váhu.
2. **Prodleva stat gainu je v konfiguraci vypnutá.** ServUO má
   `EnablePlayerStatTimeDelay = false` → interval **0,5 s**, ne 15 minut.
   Klasická hodnota 15 min je jen jedna z možností; klon ji má **zvolit
   a zapsat do `data/balance.json`** (doporučení: 15 min, protože single-player).
3. **Éry skillů (oprava zažitého pořadí):** `Bushido` + `Ninjitsu` přišly
   s **SE (2004)**, `Spellweaving` s **ML (2005)**, `Mysticism`/`Imbuing`/
   `Throwing` s **SA (2009)**. Klon je vede jako `implemented: false` (§5.16)
   — a protože jde o pozdní obsah, nic se tím neztrácí.

## 5.11 Svět, čas a světlo (§ V12)

| Věc | Hodnota (ověřeno) |
|---|---|
| Délka dne | `SecondsPerUOMinute = 5.0` → herní den = 1440 × 5 s = **7200 s (2 h)** |
| Světlo | **den 0**, **noc 12**, dungeon **26** (0 = nejjasnější; `LightCycle.cs:13-16`); průběh dne **V1** = dvouhodinové rampy 4–6 a 22–24 (`LightCycle.cs:70-82`) |
| Roční období | 4 období (vliv na vegetaci) — mimo základ, ale data jsou |
| Počasí | déšť/sníh/bouře — mimo základ (jen efekt, ne mechanika) |
| Faceta | **0 (Felucca)**, 7168 × 4096; start Britain |
| Regiony | města, divočina, dungeony; určují hudbu, spawn tabulku a guard zónu |
| Teleporty | moongate (9 bran s přesnými souřadnicemi v `research/06`) + teleport dlaždice z `teleprts.txt` |
| Dveře/schody | z `doors.txt` / `stairs.txt` (§3.6) |

**✅ ROZHODNUTO 2026-10-06 — světlo je varianta V1 (a je v kódu):**
řádek výš uváděl „úroveň dne **12**" a stejné číslo měly **dva další zdroje**:
`ZADANI-UO-KLON.md` §10 bod 20 („Světlo: den / dungeon — 12 / 26") a kód
(`sim/world/time.gd`: `LIGHT_DAY = 12`). **Naměřený zdroj říká něco jiného:**
`research/01-core-mechanics.md` §4.2 i přímé měření `_src/servuo/Scripts/Misc/LightCycle.cs:13-16`
(a shodně `_src/modernuo/.../Misc/LightCycle.cs:13-16`) dávají **`DayLevel = 0`**
(0 = nejjasnější) a **`NightLevel = 12`** — 12 je tedy úroveň **noci**, ne dne.
`DungeonLevel = 26` sedí ve všech zdrojích, `JailLevel = 9` existuje jen tam
(u nás ho záměrně nemáme jako konstantu — věznice nejsou).

**Uživatel 2026-10-06 zvolil variantu V1** („přesně to, co dělají emulátory"):
`den = 0`, `noc = 12`, `dungeon = 26` a **dvouhodinové přechodové rampy**
(22:00 → 0:00 se stmívá na 12, 4:00 → 6:00 se rozednívá na 0), tedy
`h < 4 → 12`; `4 ≤ h < 6 → 12 + ((h−4)·60+m)·(0−12)/120`; `6 ≤ h < 22 → 0`;
`22 ≤ h ≤ 23:59 → 0 + ((h−22)·60+m)·(12−0)/120`. Přesný přepis je
v `sim/world/time.gd::_day_night_level` a měří ho `tests/cases/time.gd`
a `tests/cases/time_clock.gd`.

**Co z toho zůstává otevřené (a mění se jen v datech):**
- **`light.mul`** (per-dlaždicové osvětlení terénu) — doplňuje globální úroveň, nenahrazuje ji;
  obsah souboru je `NEMĚŘENO` (ověřil by ho extraktor + 5 dlaždic). `docs/11 §11.6` (O6)
  se tím **neuzavírá**: O6 se ptá na chování **originálního OSI klienta**, ne na server.
- **Osobní světlo** (louče, Night Sight): `personal = 21` při `AosAttributes.NightSight > 0`
  nebo `Core.ML && Race == Elf` (`Scripts/Mobiles/PlayerMobile.cs:1111-1125`), Night Sight
  dává `13` (`Scripts/Items/Consumables/NightSight.cs:37`); klient bere `max(personal, 32 − global)`.
  Patří do `render.light` (granule v M7) až s osobním světlem.
- **Kdo světlo aplikuje:** hodnotu počítá **simulace** (`world.time.light_level()`), klient ji
  jen zobrazuje — do té doby, než vznikne `render.light`, se v naší hře **nevykresluje**.

## 5.12 Spawn, NPC a AI

| Věc | Rozhodnutí |
|---|---|
| Model spawnu | **regionální spawn tabulky + jeden world tick** (místo tisíce spawner objektů); tabulky v `data/spawns.json` |
| Prodleva | default **5–10 min** (klasický spawner), `SpawnEntry` 2–5 min; doplnění při deficitu **1/3** |
| Monstra | **88 tabulek** v `research/06` (tělo, staty, damage, resisty, skilly, fame/karma, loot) |
| AI stavy | `idle → wander → aggro → attack → flee → dead` (+ `vendor`, `guard`, `escort`) |
| Vendors | 120 tříd, 88 shop definic; seznam zboží a restock v `data/vendors.json` |
| Rozsah základu | **3 dungeony** (Deceit, Despise, Shame) + divočina kolem Britainu; zbytek světa existuje geometricky, ale spawn hustě jen tam |
| Chování v nouzi | NPC se nikdy nesmí „zaseknout" v neplatném stavu — po timeoutu se vrátí na `home` |

## 5.13 Smrt, duch, vzkříšení

| Věc | Hodnota (ověřeno) |
|---|---|
| Smrt | `hp <= 0` → tělo (corpse) s obsahem kromě `blessed`; hráč je **duch** (nevidí ho monstra, nemůže útočit) |
| Tělo | rozpad 7 min, právo na loot 2 min |
| Vzkříšení | léčitel/ankh/`resurrect` → **hp = 10**; equip se vrací dle `blessed`/`insured` |
| Ztráty | stat/skill loss `UNVERIFIED` (O5) → `config` flag, default vypnuto |

## 5.14 Hlad, regenerace, jed

| Věc | Hodnota |
|---|---|
| Hlad | **−1 za 5 min**; hlad ovlivňuje regeneraci (`UNVERIFIED` detail, konfigurovatelné) |
| Regenerace | hp/stam/mana podle statů; meditace sedíc (`Meditation`) |
| Jed | 5 úrovní; tiká v intervalech, `cure` podle úrovně; `Poisoning` na zbraně a jídlo |

## 5.15 Ukládání

Viz §4.7. Navíc: **auto-save každých 5 minut** a při ukončení; dvě verze
souboru (`.sav` a `.sav.bak`), aby pád neznamenal ztrátu hry.

## 5.16 Éra: která pravidla platí (jednoznačně)

**Tohle je rozhodnutí s největším dopadem — bez něj klon „zdědí AoS omylem".**

| Systém | Volba | Důvod |
|---|---|---|
| Pohyb, `z`, průchodnost, dveře, schody | **pre-AoS** (= všechny éry stejné) | žádný rozpor |
| Swing delay, hit chance, damage, obrana | **AoS** | konzistence s moderními daty a itemizací |
| Item properties (AoS) | **AoS** (resisty, DI, HCI/DCI, LMC/LRC, luck) | jsou v datech instalace |
| **Tooltipy (OPL)** | **ZAPNUTÉ i v klasice** (rozhodnutí uživatele 2026-10-06) | moderní UI; vanilla by je v pre-AoS měla vypnuté (`ObjectPropertyList.Enabled = Core.AOS`), ModernUO to má jako config `opl.enable` (`ExpansionConfiguration.cs:10`) |
| **Magie zbraní „kov + úroveň"** | **odloženo** (rozhodnutí uživatele 2026-10-06); zatím platí AoS atributy, ale jen když bude vrstva **modulární** | v žádné referenci neexistuje (viz §5.16.1) — je to naše datová vrstva a musí jít přidat bez přepisu souboje |
| Item insurance | implementováno, **default vypnuto** | v single-playeru trivializuje smrt |
| Blessed/newbie předměty | **zapnuto** | patří k pocitu hry |
| Notoriety a flagy | **pre-AoS sémantika** (Felucca), Trammel pravidla implementovaná, ale neaktivní | ve hře není jiný hráč, takže „bezpečná faceta" nemá smysl |
| Skilly | 58 id, **mechanicky implementováno 48 klasických** (0–47) + `Remove Trap`; Necromancy/Bushido/Ninjitsu/Spellweaving/Throwing/Imbuing/Mysticism/Chivalry/Focus = `implemented: false` | drží id kompatibility, ale neslibuje nefunkční obsah |
| **Stat gain** | **prodleva 2 s, šance 25 %** (rozhodnutí uživatele 2026-10-06, pásmo 1–3 s / 20–30 %) — hodnoty v `data/balance.json` (`stat_gain.*`), **laditelné** | UO default je 500 ms / 5 % (`SkillCheck.cs:52-53`, `:49`); vypnutá prodleva hru nezrychlí, jen zruší pojistku — viz §5.16.2 |
| **Růst skillu při neúspěchu** | **pre-AoS** (`era.skill_gain`, rozhodnutí 2026-10-08 — 16. session): neúspěch přispívá do šance na růst **0,2**, v AoS **0,0** | `Core.AOS ? 0.0 : 0.2` (`SkillCheck.cs:295`); uživatel 11. session zvolil řemeslo jako „BIG WIN č. 1" a u něj jde o pocit z výzvy („učit se z chyb"), takže AoS by mu vzal přesně to, co chce. `combat`/`loot`/`content` zůstávají AoS — mění se jeden klíč, ne éra celku |
| Recepty | **klasické** (z `research/04-craft-data.json`, označené érou) | bez runic/reforging (vypnuto) |
| Loot | **pre-AoS `LootPack.Old*`** + magic item chance | odpovídá obsahu |
| BOD, runic, reforging, imbuing | **mimo rozsah** | samostatné systémy |

**Éra je od 2026-10-06 zapsaná PO SLOŽKÁCH** v `data/balance.json` (klíč `era.*`:
`combat`, `loot`, `content`, `ui`, `movement`, `skill_gain`, `tooltips`) — tabulka
výš je lidské čtení téhož. Kdo mění éru, mění **jeden klíč**, ne kód (viz §5.16.3).

### 5.16.1 Podklad pro rozhodnutí „T2A vs AoS" (DOPLNĚNO 2026-10-06, měřeno)

Tabulka výš **není rozhodnutí o éře jako celku** — je to směs (pohyb a notoriety
pre-AoS, souboj a itemizace AoS, loot pre-AoS). Naměřená fakta, ze kterých se dá
vybírat (vše `_src/…`, piny v `research/REJSTRIK-REFERENCI.md`):

| Co | T2A (klasika) | AoS („The Big Divide") |
|---|---|---|
| **Přepínač** | `Core.T2A` = `Expansion >= T2A`: **2 nálezy v 1 souboru** (ServUO; jen `StrangeContraption.cs`) | `Core.AOS`: **633 nálezů ve 262 souborech** (ServUO), 581/242 (ModernUO) |
| **Tooltipy / item properties** | **vypnuté** (`ObjectPropertyList.Enabled = Core.AOS`, `Scripts/Misc/CurrentExpansion.cs:27`); AoS atributy mají `IsValid == false` bez `Core.AOS` | zapnuté: 27 `AosAttribute`, 31 `AosWeaponAttribute`, 6 `AosArmorAttribute` (`Scripts/Misc/AOS.cs:514,1342,2130`) + resisty (`AosElementAttribute`) |
| **Magie zbraní** | **pojmenované úrovně** (`WeaponEnums.cs:17-45`, `ArmorEnums.cs:5-23`): poškození `Ruin/Might/Force/Power/Vanq`, přesnost `Accurate…Supremely`, odolnost `Defense…Invulnerability`; bonus `+15/+20/+25/+30/+35` **jen když `!Core.AOS`** (`BaseWeapon.cs:3715-3744`) | pojmenované **atributy s číslem v tooltipu** (DI/HCI/DCI/LMC…), runic reforging, imbuing |
| **Základní staty zbraní** | staré hodnoty (`OldX`) | **přepočítané** (`Core.AOS ? AosX : OldX`, `BaseWeapon.cs:575-676`) — pro hráče nejcitelnější rozdíl |
| **Speciální útoky** | ne (starý `SpecialMove` chce `Core.SE`; `WeaponAbility` chce `Core.AOS`, `Scripts/Abilities/WeaponAbility.cs:412`) | ano, 33 ability (13 základních + ML/SA) |
| **Svět** | Felucca (Trammel je v datech vždy, ale bez rozdělení) | Trammel/Felucca rozdělení, Malas, Ilshenar |
| **Ostatní** | `ActionDelay = 500 ms`, klikací hlášky guild/ascii zapnuté | `ActionDelay = 1000 ms`, pojištění (`Core.AOS && !Siege`), BOD s jiným artem i odměnami, `VisibleDamageType = Related` |

**Co z toho plyne pro náš klon (a pro „+1 +3 +5 +7 +9" z Dark Paradise):**

1. **Číselný „+N" zápis v žádné referenci NENÍ** (měřeno: `"+1"` → 0 nálezů
   v ServUO/ModernUO/RunUO; ve Sphere jen v SQLite). Je to **vlastní datová
   vrstva** — nad kteroukoli érou.
2. **Kov mění vlastnosti jen za `Core.AOS`** (`BaseWeapon.cs:909-932`,
   `GetLowerStatReq():939`); v pre-AoS mění kov jen **hue a jméno** (a jméno je
   v tooltipu, který je pre-AoS vypnutý). Chceme-li „zbraně z různých kovů, které
   na něčem záleží", je to **naše vrstva**, ne přepínač éry.
3. `RunicReforging.cs` a `Imbuing` **neobsahují ani jeden `Core.*`** (0 nálezů) —
   v pre-AoS světě by zůstaly dostupné; kdo je nechce, musí je vypnout **sám**.
4. **Rozhodnout teď je levné, později drahé:** `sim.combat` ještě není napsaný,
   takže volba „pre-AoS damage/obrana" dnes znamená jen jinou tabulku v `docs/05`
   a `data/balance.json`; po M5 by to byl přepis hotového systému.

**K rozhodnutí uživateli (otevřené):** (a) éra **obsahu předmětů a souboje**
(T2A klasika vs AoS itemizace), (b) zda zapnout **tooltipy** i v klasice
(ModernUO to má jako config `opl.enable`, `ExpansionConfiguration.cs:10`),
(c) zda vlastní vrstva „kov + úroveň" bude **místo** AoS atributů, nebo **vedle**
nich (pozor na dvojí započtení do `GetDamageBonus()`, `BaseWeapon.cs:3706`);
(d) zda éru zapsat **po složkách** do `data/balance.json` (`combat_era`, `loot_era`,
`ui_era`, `movement_era`) — dnes je tam jen `combat_era: "aos"`.

**✅ ROZHODNUTO 2026-10-06 (uživatel):** (a) **zatím zůstává AoS** jako základ
(combat_era = `aos`), ale s tím, že volba **musí zůstat přepínatelná** (§5.16.3);
(b) **tooltipy zapnuté** i v klasice; (c) vlastní vrstva „kov + úroveň" se
**odkládá** — smí se přidat, jen když bude **modulární** (nesmí si vynutit přepis
souboje ani dvojí započtení); (d) **éra zapsaná po složkách** — je v
`data/balance.json` v klíči `era.*`; (e) stat gain = **2 s / 25 %**, laditelné.

### 5.16.3 Je volba éry break point? (DOPLNĚNO 2026-10-06 — měřeno)

**Krátká odpověď: dnes ne, a zůstane to levné, pokud dodržíme tři pravidla.
Drahé to začne být daty a testy, ne kódem.**

**Proč to v emulátorech jde přepnout:** jejich datový model nese **obě složky
současně** — zbraň má zároveň `DamageLevel`/`AccuracyLevel`/`DurabilityLevel`
(pojmenované úrovně, `Scripts/Items/Equipment/Weapons/WeaponEnums.cs:17-45`)
**i** `AosWeaponAttributes` (`Scripts/Misc/AOS.cs:1378`). Éra rozhoduje jen
o tom, **která se použije**: `AosAttributes.IsValid` vrátí `false`, když
`!Core.AOS` (`AOS.cs:547-552`), ale **serializovaná data zůstávají**
(`BaseWeapon.cs:4212-4214`, `:4250-4262`). Přepnutí éry je tedy **změna
chování, ne migrace dat** — a proto se v ServUO udržuje **633 nálezů
`Core.AOS` ve 262 souborech**: to je cena za to, že *podporují obojí*.

**Tři pravidla, která drží přepínatelnost (a jejich cena):**

| Pravidlo | Co to znamená | Cena |
|---|---|---|
| **1. Data nesou obojí** | předmět uloží `damage_level` **i** `aos_attributes`; ukládání/save nesmí záviset na éře | ~0 (dvě pole místo jednoho) |
| **2. Jeden klíč na rozhodnutí** | éra se čte z `data/balance.json` (`era.*`), **ne** z konstant rozesetých po kódu; každý systém má **jedno** místo, kde se ptá (`_damage_bonus(item)`, `loot_pack()`, …) | malá; jinak vznikne 20 `if` a přepnutí je přepis |
| **3. Rozdíl musí být pojmenovaný** | co éra mění, je v `docs/05 §5.16` (tabulka) **a** v `data/balance.json` (`era.*`) — dvě místa, obě ověřitelná | malá |

**Co je i tak drahé (a proč rozhodnout brzy):**
1. **Vygenerovaná data.** Jakmile se do `data/items.json`/lootu zapíšou AoS
   atributy jako *jediná* pravda, pre-AoS režim z nich nemá co číst → migrace.
   (Proto pravidlo 1.)
2. **Resisty.** AoS dělí poškození na 5 typů a obrana je AR + resisty; pre-AoS má
   **jedno číslo AR**. Když naše data o tvorech a zbrojích vzniknou v AoS tvaru,
   pre-AoS režim potřebuje **převodní funkci** (součet → AR). Je to jedno místo,
   ale musí být napsané **dřív**, než se data vygenerují.
3. **Testy.** Testy, které tvrdí AoS čísla, jsou při přepnutí k nepotřebě —
   práce navíc, ale **viditelná** (to je ta lepší varianta).
4. **Save soubory.** Rozdělaná hra s AoS předměty se po přepnutí nečte správně
   (řeší se až u `sim.world_loop`, M8).

**Co je naopak levné:** tooltipy (`era.tooltips`), loot packy
(`LootPack.Old*` vs `Aos*`), `ActionDelay` (500 vs 1000 ms), klikací hlášky,
damage formule (`ScaleDamageOld` vs `ScaleDamageAOS`), ability (33 vs 0),
pojištění, stat gain — **všechno to jsou hodnoty nebo jedna funkce**.

**Praktický závěr pro tento klon:** AoS zůstává základem (rozhodnutí výš), ale
`sim.combat`, `entity.item` a loot se **musí** ptát jednoho místa (pravidla 1–3),
jinak se z „později to přepneme" stane přepis. Kdo to poruší, porušil smlouvu
`docs/04 §4.2` (jediná funkce pro rozhodnutí), ne jen styl.

### 5.16.2 Stat gain — naměřené hodnoty a co od nich čekat (DOPLNĚNO 2026-10-06)

Stat gain = **zvyšování STR/DEX/INT** ze skillů (není to totéž co skill gain).
Naměřeno v `_src/servuo/Scripts/Misc/SkillCheck.cs`:

| Veličina | ServUO default | Kde |
|---|---|---|
| Prodleva mezi zisky statu | **15 min** *jen když je zapnutá* | `:46` `PlayerStatTimeDelay` z `PlayerCaps.cfg:50` |
| Přepínač prodlevy | **`false`** → prodleva se přepíše na **0,5 s** | `:52-53`; `PlayerCaps.cfg:45` (OSI to vypnulo v Publishe 45) |
| Šance na zisk statu | **5 %** | `:49` `PlayerChanceToGainStats` |
| Stat se zvedá | jen uvnitř **úspěšného** skill gainu | `:460-481` |
| Capy | total **225**, jednotlivý **125** (max 150) | `Mobile.cs:11128-11129`; `PlayerCaps.cfg:16-34` |
| Na total capu | staty se **přesouvají** (atrofie), nepřidávají | `IncreaseStat` `:629-647` |

**Co od toho čekat (výpočet ze konstant, ne stopky):** varianta **A** (0,5 s, 5 %)
≈ **180 stat pointů/hod** při jednom vyhodnocení skillu za sekundu (strop 7200/h
je teoretický); varianta **B** (15 min) = max **4/h na stat** ≈ 12/h celkem;
varianta **C** (3 s, 30 %) ≈ **360/h na stat** ≈ 1080/h.
**ModernUO** má default **3 s** (ML) / **10 min** (před ML), 5 %, primary:secondary
**75:25** — a `_statGainDelay` pro hráče **vůbec nepoužívá** (používá jen
`_petStatGainDelay`) a **GGS nemá** (`GGSTable` = 0 nálezů).

**Doporučení pro singleplayer (a proč):** zapnout prodlevu na **1–3 s** a šanci
**20–30 %**. Vypnutá prodleva hru nezrychlí — jen zruší pojistku proti exploitu;
skutečným limitem zůstává 5% hod. Krátká prodleva dělá růst **předvídatelným**
(≈1000/h), což je v jednohráčovi čitelnější než náhodné skoky. **Rozhodnutí
uživatele je otevřené** — hodnota patří do `data/balance.json`.
