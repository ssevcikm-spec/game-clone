# 5. Mechaniky — co musí hra dělat

> **Normativní zdroj čísel:** `research/01-core-mechanics.md`,
> `03-combat-magic-items.md`, `04-gathering-crafting.md`, `02-skills.md`,
> `06-world-content-npcs.md`. Tenhle oddíl říká **co platí pro klon**
> (a když se zdroje rozcházejí, který jsme vybrali a proč).
> Číslo bez zdroje je `UNVERIFIED` — a to se v kódu nesmí objevit jako fakt.

## 5.1 Pohyb (§ V2)

### 5.1.1 Rychlosti (ověřeno ve třech nezávislých kódech)

| Stav | Prodleva na krok | Zdroj |
|---|---|---|
| Chůze pěšky | **400 ms** | ServUO `Server/Mobile.cs:3063`, ModernUO `…/Movement.cs:33`, ClassicUO `…/MovementSpeed.cs:12` |
| Běh pěšky | **200 ms** | totéž |
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

### 5.1.2 Algoritmus průchodnosti (jádro věrnosti)

Konstanty: `PERSON_HEIGHT = 16`, `STEP_HEIGHT = 2`.

1. **Výchozí `z`** se počítá z dlaždic pod cílovou pozicí (land + statiky,
   které mají `Surface`) — bere se nejvyšší povrch, na který se vejde postava.
2. **Blokuje se**, když se výškový interval cíle `[z, z + výška_dlaždice)`
   protne s `[z_postavy, z_postavy + 16)` — s povoleným krokem `STEP_HEIGHT = 2`.
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

**Zákaz:** „pohyb je plynulý" (lerp mezi dlaždicemi jako moderní hry).
Pohyb je **diskrétní krok** — to je poznávací znamení UO.

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
| dveře (`world.doors.is_door`) | otevřít/zavřít (přepni art podle kategorie), zvuk, změna průchodnosti |
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
| **Archery** | stání na místě 1000/500/250 ms dle éry, munice se spotřebuje **při každém** výstřelu, 40 % návratnost, dostřel 7–10 |
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
| Shoda dlaždice | `(ItemID & 0x3FFF) | 0x4000` — přesně tohle pravidlo určuje, které dlaždice jsou „hora" |
| **Lumberjacking** | buckety 4×3, 10–45 logů, **10 logů za sek** (20 ve Felucci), 7 druhů dřeva, **1 log → 1 prkno**; bonus k damage sekerou `(LJ × 0.2 + (LJ ≥ 100 ? 10 : 0)) / 100` |
| **Fishing** | **8 s na pokus**, hluboká voda od **75** skillu; speciální úlovky (síť 1,12 %, mapa 1,11 %, láhev 2,99 %) |
| **Kůže** | stažení zvířete nožem (Healing/Anatomy gate), druhy kůží dle zvířete |
| Nástroje | opotřebení **jen při úspěšném** skill checku (1 use) |

**Přijímací kritérium:** `mine(m, x, y)` se špatným `z`/dlaždicí vrátí
`{ok:false, reason:"not_ore"}`; se správnou horou a pickaxe vrátí rudu;
**respawn** žíly se po vyčerpání obnoví za 10–20 min (test s posunem času).

## 5.8 Výroba (§ V9)

**Zdroj receptů:** `research/04-craft-data.json` — **1150 receptů**
(Blacksmithy 196, Tailoring 198, Carpentry 223, Tinkering 165, Cooking 88,
Masonry 59, Alchemy 51, BowFletching 27, Glassblowing 22, Inscription 16 +
97 svitků, Cartography 8). Do klonu se dostanou **generátorem** do
`data/recipes.json`, ne ručním opisem.

| Věc | Vzorec / pravidlo (ověřeno) |
|---|---|
| Šance na úspěch | `floor + (val − min) / (max − min) × (1 − floor)`; `floor` podle systému (Tailoring/Carpentry 0.5); při `max` skillu 100 % |
| Exceptional | tři režimy: kovářství/krejčovství/truhlařina/tinkering/vaření `−0.60` slábnoucí k `−0.45`; lukovství `chance/2 − 0.10`; default `−0.60` |
| Dvojitý hod | exceptionalita z **1. hodu**, úspěch z **2. hodu** |
| Značka výrobce | jen když `quality == 2` **a** `MainSkill >= 100` |
| Nástroj | **−1 use na pokus** (úspěch i neúspěch) |
| Neúspěch | spotřebuje **plný materiál** (kromě 18 položek ve výjimkách); u `UseAllRes` polovinu |
| Exceptional efekt | +14/+15 resist, +20 % trvanlivosti, zbraň +35 WeaponDamage, nástroje 2× uses |
| Tavení rudy | ore → ingot **1:1**, skill gate podle kovu 50–99; neúspěch půlí hromádku |
| Zpětné tavení | `floor(66 %)` ceny předmětu v ingotech; koupené = 1 ingot; jen když primární cena ≥ 2 |
| Oprava | šance oslabit `40 + (max − cur) − skill/10` %; obtížnost `((max − cur) × 1250 / max) − 250` desetin; `CheckSkill(diff ± 25)` |
| Ekonomika | plná plátová zbroj = **100 ingotů** (= 100 rudy); ringmail 58; chainmail 48; smelt ztráta 34 %/cyklus |

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
| Item insurance | implementováno, **default vypnuto** | v single-playeru trivializuje smrt |
| Blessed/newbie předměty | **zapnuto** | patří k pocitu hry |
| Notoriety a flagy | **pre-AoS sémantika** (Felucca), Trammel pravidla implementovaná, ale neaktivní | ve hře není jiný hráč, takže „bezpečná faceta" nemá smysl |
| Skilly | 58 id, **mechanicky implementováno 48 klasických** (0–47) + `Remove Trap`; Necromancy/Bushido/Ninjitsu/Spellweaving/Throwing/Imbuing/Mysticism/Chivalry/Focus = `implemented: false` | drží id kompatibility, ale neslibuje nefunkční obsah |
| Recepty | **klasické** (z `research/04-craft-data.json`, označené érou) | bez runic/reforging (vypnuto) |
| Loot | **pre-AoS `LootPack.Old*`** + magic item chance | odpovídá obsahu |
| BOD, runic, reforging, imbuing | **mimo rozsah** | samostatné systémy |
