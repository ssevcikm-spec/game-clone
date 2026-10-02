# Ultima Online — World Content Spec: Facets, Towns, NPCs, Monsters, Spawning, Trade, Quests

**Target:** a faithful single-player offline UO clone.
**Compiled from source code and data files, not prose.** Every table below is traceable to a repo path or URL.

---

## 0. Method, sources, and verification legend

### 0.1 Sources actually read (primary)

| Source | Ref / branch | What was taken from it |
|---|---|---|
| **ServUO** | `github.com/ServUO/ServUO` @ `pub57` | Monster stats, vendor NPC classes, vendor buy/sell tables (`SB*`), taming/mount data, skill table, loot packs, spawn model, escorts, guards, housing, boats, player vendors |
| **RunUO 2.x** | `github.com/runuo/runuo` | `Data/Regions.xml` (town/dungeon regions), `Data/Locations/felucca.xml` (named coordinates + dungeon levels), `Data/SpawnDefinitions.xml` |
| **ModernUO** | `github.com/modernuo/ModernUO` | Cross-check on content layout (`Projects/UOContent/Mobiles/**`) |
| **ClassicUO** | `github.com/ClassicUO/ClassicUO` | Client-side facts: `Prof.txt`/profession loader, `skills.mul` loader, hard-coded skill enum |

Local checkouts used while writing: `.cache/servuo`, `.cache/runuo`, `.cache/modernuo`, `.cache/classicuo`.
Parsed intermediates: `.cache/analysis/*.tsv`, `.cache/analysis/sb-tables.md`.

### 0.2 Verification legend

| Mark | Meaning |
|---|---|
| **【C】** | **Code-verified.** Value read directly out of a source file that is cited inline. |
| **【D】** | **Data-verified.** Value read out of a shipped data file (`Regions.xml`, `Locations/*.xml`, `Spawns/*.xml`) that is cited inline. |
| **【X】** | **Derived.** Computed by me from cited data (e.g. map block counts, spawn-point counts). The derivation is stated. |
| **UNVERIFIED** | Could not confirm from an authoritative source. What would be needed to measure it is stated inline. |

### 0.3 Era scoping — read this before implementing anything

ServUO `pub57` is a **post-Stygian-Abyss** codebase. Almost every file carries era gates (`Core.AOS`, `Core.SE`, `Core.ML`, `Core.SA`, `Core.TOL`). **Classic UO is pre-AoS.** The differences that matter most:

| System | Pre-AoS (classic / UO:R / T2A) | AoS and later (what ServUO defaults to) |
|---|---|---|
| Armour model | Single **Armor Rating** integer per piece, summed; reduced damage by a flat percentage | **Five resistances** (Physical, Fire, Cold, Poison, Energy), each 0–70+, damage typed |
| Damage types | Physical only, in practice | Physical/Fire/Cold/Poison/Energy split per attack |
| Magic item properties | None, or "magic" weapons with flat bonuses (`OldMagicItems` in `LootPack.cs`) | Full item property system (DI, SDI, HCI, DCI, LMC, LRC…) |
| Skill cap | 700.0 total | 700.0 (+ power scrolls to 720 in later eras) |
| Stat cap | 225 total across STR/DEX/INT | 225 (+ stat scrolls) |
| Vendor pricing | Table price × 1.90 buy, no economy simulation | Optional `VendorEconomy` simulation (`Core.AOS && !Siege`) |

**【C】** — `Server/Map.cs`, `Scripts/Misc/LootPack.cs` (`#region Generic accessors`: `Poor => Core.SE ? SePoor : Core.AOS ? AosPoor : OldPoor`), `Scripts/Mobiles/NPCs/BaseVendor.cs:33` (`UseVendorEconomy = Core.AOS && !Siege.SiegeShard`).

**Recommendation for the clone:** pin to the **pre-AoS data set** — use `LootPack.Old*` (`OldPoor`…`OldSuperBoss`), single Armor Rating, physical-only damage. The classic monster *stat* lines (STR/DEX/INT/Hits/damage/Fame/Karma) in §3 are stable across eras; the *resistances* column is AoS-only and should be replaced by a single armour value. Both are given below so you can choose.

---

## 1. Facets and maps

### 1.1 Map registry

**【C】** `Scripts/Misc/MapDefinitions.cs` lines 16–35 — `RegisterMap(<index>, <mapID>, <fileIndex>, <width>, <height>, <season>, <name>, <rules>)`.

| Facet | index | mapID | fileIndex | Width (tiles) | Height (tiles) | Season | Rules (non-Siege) | Added in |
|---|---:|---:|---:|---:|---:|---|---|---|
| **Felucca** | 0 | 0 | 0 | 7168 | 4096 | 4 = Desolation | `FeluccaRules` (= `None`) | Launch |
| **Trammel** | 1 | 1 | 1 | 7168 | 4096 | 0 = Spring | `TrammelRules` | UO:R |
| **Ilshenar** | 2 | 2 | 2 | 2304 | 1600 | 1 = Summer | `TrammelRules` | Third Dawn / LBR |
| **Malas** | 3 | 3 | 3 | 2560 | 2048 | 1 = Summer | `TrammelRules` | Age of Shadows |
| **Tokuno** | 4 | 4 | 4 | 1448 | 1448 | 1 = Summer | `TrammelRules` | Samurai Empire |
| **TerMur** | 5 | 5 | 5 | 1280 | 4096 | 1 = Summer | `TrammelRules` | Stygian Abyss |
| Internal | 0x7F | 0x7F | 0x7F | 16 | 16 | 1 | `Internal` | core |

Season codes: **0 = Spring, 1 = Summer, 2 = Fall, 3 = Winter, 4 = Desolation** 【C】 `Scripts/Misc/MapDefinitions.cs:46`.

`MapRules` flags 【C】 `Server/Map.cs:121-130`:
```
None                = 0x0000   // FeluccaRules
Internal            = 0x0001
FreeMovement        = 0x0002   // walk through other mobiles, no stamina loss
BeneficialRestrictions = 0x0004
HarmfulRestrictions = 0x0008
TrammelRules = FreeMovement | BeneficialRestrictions | HarmfulRestrictions
FeluccaRules = None
```
So **Felucca = full PvP, collision, no beneficial/harmful action restrictions**. On a siege shard *all* facets are forced to `FeluccaRules` 【C】 `MapDefinitions.cs:16-24`.

### 1.2 Block and sector counts

**【X】** derived from the dimensions above.

- **Map block = 8 × 8 tiles** (client `map0.mul` block record = 196 bytes). **Sector = 16 × 16 tiles**【C】 `Server/Map.cs:397` `public const int SectorSize = 16; SectorShift = 4;` — ServUO's *server-side* sector is 16×16, which is **twice** the client map block. Do not confuse the two when porting.

| Facet | Tiles | Map blocks (8×8) | Blocks W × H | Server sectors (16×16) | Sectors W × H |
|---|---:|---:|---|---:|---|
| Felucca | 7168 × 4096 | **458,752** | 896 × 512 | 114,688 | 448 × 256 |
| Trammel | 7168 × 4096 | **458,752** | 896 × 512 | 114,688 | 448 × 256 |
| Ilshenar | 2304 × 1600 | **57,600** | 288 × 200 | 14,400 | 144 × 100 |
| Malas | 2560 × 2048 | **81,920** | 320 × 256 | 20,480 | 160 × 128 |
| Tokuno | 1448 × 1448 | **32,768** | 181 × 181 | 8,281* | 91 × 91* |
| TerMur | 1280 × 4096 | **81,920** | 160 × 512 | 20,480 | 80 × 256 |

\* Tokuno 1448 is not a multiple of 16; 1448/16 = 90.5, so the last sector row/column is partial. 1448/8 = 181 exactly, so block counts are clean.

### 1.3 What each facet contains

| Facet | Content |
|---|---|
| **Felucca** | The original Britannia: 8 anti-virtue cities + Cove/Occlo/Serpent's Hold/Buccaneer's Den, the **Lost Lands** (T2A: Papua, Delucia, Terathan Keep, the Fire & Ice dungeons), Wind (hidden city), the 8 classic dungeons, Khaldun, Despise, the Solen Hives, Ilshenar-style ML content grafted at high coordinates (Heartwood 6911,255; Sanctuary 6144,0; Prism of Light 6400,0; Blighted Grove 6440,820; Palace of Paroxysmus 6191,311). **Full PvP, housing allowed outside towns.** |
| **Trammel** | Byte-identical terrain copy of Felucca with `TrammelRules`: no PvP between innocents, no blocking, no looting. Contains New Haven (UO:R new-player island) — `NoHousingRegion` at (3314,2345) 750×750 【D】. The Felucca town list applies unchanged. |
| **Ilshenar** | Third Dawn continent: Gargoyle City, Montor, Mistas, lakeshire, Reg Volon, Bet-Lem Reg, Lenmir Anfinmotas, Alexandretta's Bowl, Ancient Citadel, the 9 shrines (one per virtue + Chaos), 6 gypsy camps, Juka Camp, Pass of Karnaugh, Lord Blackthorn's Ilshenar Castle. Dungeons: Ankh, Wisp, Blood, Spectre, Rock, Spider Cave, Sorcerer's, Exodus, Ancient Lair, Ratman Cave, Mushroom Cave, Serpentine Passage, Terort Skitas, Twisted Weald. |
| **Malas** | AoS continent: Luna (city), Umbra (city), Doom + Doom Gauntlet, Bedlam, The Citadel, Labyrinth, Orc Fortress, Crystal Cave, Hanse's Hostel, Grand Arena, Ilse of the Divide. Tokuno content is also registered here as a mirror (`Yomotsu Mines`, `Fan Dancer's Dojo` appear under Malas rects). |
| **Tokuno** | Samurai Empire: Zento (city), Bushido Dojo, Fan Dancer's Dojo, Yomotsu Mines, 3 moongates (Isamu-Jima, Makoto-Jima, Homare-Jima), 2 start locations (Samurai, Ninja). |
| **TerMur** | Stygian Abyss gargoyle homeland: Royal City, Tomb of Kings, Abyss, Underworld, Eodon (Valley of Eodon). 1 public moongate. |

**【D】** `runuo/Data/Regions.xml` (all rects quoted above are from this file), 【C】 `Scripts/Items/Functional/PublicMoongate.cs`.

---

### 1.4 FELUCCA — towns

Town geometry comes from **`runuo/Data/Regions.xml`** `<region type="TownRegion">` entries. Each entry supplies one or more `<rect>` bounds and a `<go>` point — **the `<go>` point is the canonical town centre**. 【D】

| Town | Centre `<go>` (x, y, z) | Bounds (x,y WxH) | Music | Defining features |
|---|---|---|---|---|
| **Britain** | **1495, 1629, 10** | (1416,1498 279×279) (1500,1408 90×90) (1385,1538 239×239) (1416,1777 60×60) (1385,1777 130×130) (1093,1538 369×369) | Britain1 | Largest city. Lord British's castle (1323,1624), Blackthorn Castle (1533,1415), Britain Cemetery/graveyard (1384,1497), Park (1614,1641), Farmlands (1228,1705), Suburbs (1662,1572). Faction HQ "True Britannians" (1419,1622). Catacombs/sewers. |
| **Trinsic** | **1867, 2780, 0** | (1856,2636 28×28) (1816,2664 231×231) (2099,2782 25×25) (1970,2895 32×32) (1796,2696 67×67) (1800,2796 52×52) | Trinsic | Walled paladin city, Honour shrine nearby. West Gate (1832,2779), South Gate (2000,2930), East Docks (2071,2855), Island Park (2108,2793). SW of Britain. |
| **Vesper** | **2899, 676, 0** | (2893,598 50×50) (2816,648 365×365) (2734,944 4×4) (2728,948 53×53) | Vesper | Swampy NE port with a canal dividing the town. Docks (3013,828), Cemetery (2786,867). Adjacent Covetous (entrance 2499,916) and Minoc road. |
| **Minoc** | **2466, 544, 0** | (2411,366 241×241) (2548,495 55×55) (2564,585 42×42) (2567,585 61×61) (2499,627 63×63) | Minoc | Mining/tinker town in the northern mountains. Mining Camp (2583,528), Bridge (2539,501), Gypsy Camp (2540,651), North (2475,417), South (2526,583). Mines: Minoc Mine (2558,499), Minoc Cave 1/2/3. |
| **Yew** | **546, 992, 0** | (92,656 225×225) (441,746 135×135) (258,881 380×380) (657,922 307×307) (657,806 28×28) (718,874 22×22) | Yew | Forest/ranger city, **Empath Abbey** (635,860), Courts and Prisons (354,836), Cemetery (724,1138), Hidden Cave (313,787), Orc Fort (633,1499). Largest sprawl of any town. |
| **Moonglow** | **4442, 1172, 0** | 24 rects, bounded roughly x 4278–4718, y 844–1509 | Moonglow | Mage island (Verity Isle). Cemetery (4546,1338), Docks (4406,1045), **Telescope** (4707,1124), **Zoo** (4549,1378), Lycaeum. Moongate on the island (4467,1283). |
| **Skara Brae** | **632, 2233, 0** | (538,2107 190×190) | Skarabra | Island in the far west; ranger town. West Docks (639,2236), East Docks (716,2233), North (746,2165), South (899,2381), East (811,2243). Surrounded by fields (wheat, cotton, carrot, onion, cabbage at ~816,2251-2355). |
| **Jhelom** | **1383, 3815, 0** | (1111,3567 21×21) (1078,3588 121×121) (1224,3592 473×473) | Jhelom | Warrior island chain in the far SW. Main Island (1414,3816), Medium Island (1124,3623), Small Island (1466,4015), **Fighting Pit** (1398,3742, z −21), Cemetery (1296,3719), East Docks (1492,3696). |
| **Magincia** | **3714, 2220, 20** | (3653,2046 48×48) (3752,2046 48×48) (3680,2045 49×49) (3652,2094 180×180) (3649,2256 47×47) | Magincia | Island south of Moonglow. Bank (3730,2161), Docks (3675,2259), Park (3719,2063), **Parliament** (3792,2248). Council of Mages faction HQ (3750,2241). *(In later eras the town is destroyed — see `Data/Decoration/RuinedMaginciaFel/Mag-Fel.cfg`.)* |
| **Nujel'm** | **3732, 1279, 0** | (3475,1000 435×435) | Nujelm | Desert/palace island east of Moonglow. Palace (3698,1279), Chess Board (3728,1360), Cemetery (3536,1156), Docks (3803,1279). |
| **Buccaneer's Den** | **2706, 2163, 0** | (2612,2057 210×210) (2604,2065 189×189) | Bucsden | Pirate island SE of Britain. Bathhouse (2667,2084), Docks (2736,2166), **Tunnels** (2667,2069, z −20). No guards in the tunnels. Moongate at (2711,2234). |
| **Serpent's Hold** | **3010, 3371, 15** | (2868,3324 195×195) | Serpents | Fortress of the Order of the Silver Serpent, on an island south of Trinsic. North (3023,3417), South (2906,3505), Guard Post (3011,3526). |
| **Wind** | **5223, 190, 5** | 11 rects, x 5132–5346, y 3–188 | Wind | Hidden city in the **Lost Lands**, entered from a cave. Above-ground entrance at **(1362, 896, 0)**; Caves (5166,244), Park (5211,22), East (5336,88), West (5180,90), South (5223,189). |
| **Papua** | **5769, 3176, 0** | (5639,3095 223×223) (5831,3237 30×30) | — | Lost Lands jungle port. The Just Inn (5769,3176), Centre (5730,3208, z −4), Docks (5825,3256). |
| **Delucia** | **5228, 3978, 37** | (5123,3942 122×122) (5147,4064 20×20) (5235,3930 12×12) | — | Lost Lands savannah town. Watch Tower (5276,3945, z 37), Centre (5228,3978, z 37), Orc Fort (5210,3636). |
| **Cove** | **2275, 1210, 0** | (2200,1110 50×50) (2200,1160 86×86) | Cove | Small town between Britain and Vesper, constantly raided by orcs. Gates (2285,1209), Cemetery (2443,1123), Guard Post (2218,1116, z 19), **Orc Fort (2171,1332)**. |
| **Ocllo** | **3650, 2519, 0** | 8 rects, x 3587–3905, y 2456–2712 | Ocllo | Mage/ranger island south of Magincia (in UO:R-era Trammel the escort destination "Ocllo" is remapped to **Haven**). Docks (3650,2653), Farmlands (3722,2647), North (3650,2516). |
| **Haven** (New Haven) | **3627, 2606, 0** | Trammel only: (3314,2345 750×750) `NoHousingRegion` | — | UO:R new-player island, Trammel only. Decorations in `Data/Decoration/Trammel/haven.cfg` and `_haven additions.cfg`. |
| **Paws** | UNVERIFIED centre | — | — | Small village south of Britain. Not a `TownRegion` in `Regions.xml`; it exists only as terrain + decoration. **To measure:** extract building rectangles from `map0.mul` statics in the region south of Britain, or find a UOGuide coordinate. |

**【D】** Source for all rows: `runuo/Data/Regions.xml` (`<Facet name="Felucca">`) and `runuo/Data/Locations/felucca.xml` (`<parent name="Towns">`).

**Important caveat on Jhelom:** in `Regions.xml` Jhelom appears as `NoHousingRegion` named *"Jhelom Islands"*, **not** as a `TownRegion`. Its guard zone therefore comes from elsewhere. 【D】 This means: **the town list in `Regions.xml` is not the complete guard-zone set.** If your clone needs exact "guarded" polygons per town, you must also read the client region file. **Verified working alternative for the clone:** treat the 17 rects listed above as the town/service polygons (the vendor spawn data in §1.5 confirms they are correct as *service* areas).

---

### 1.5 FELUCCA — per-town services

**【X/D】** Derived by geolocating every spawner in `servuo/Spawns/felucca.xml` (2 256 spawn points, 9 907 object entries 【X】) against the town rects above, then decoding the `Objects2` field.

`Objects2` format 【D】: a colon-separated list `<Type>:<KEY>=<val>:…` where a new object begins at each `OBJ=<Type>` token. Keys observed: `MX` (max count), `SB`, `RT`, `TO`, `KL`, `RK`, `CA`, `DN`, `DX`, `SP`, `PR`. Decoding rule used: *first token if it contains no `=`, plus the value of every `OBJ=` token.* 9907 object entries, 11 keys each 【X】.

**Counts = number of spawner objects of that type inside the town polygon.**

| Town | Vendors & services present (count) |
|---|---|
| **Britain** | alchemist(4), animaltrainer(3), architect(1), armorer(4), artist(1), baker(1), banker(2), bard(1), bardguildmaster(1), barkeeper(6), blacksmith(2), blacksmithguildmaster(2), bowyer(1), butcher(1), carpenter(1), cobbler(2), cook(6), customhairstylist(1), farmer(5), fisherman(2), furtrader(1), harbormaster(1), healer(1), healerguildmaster(1), herbalist(1), innkeeper(3), jeweler(2), mage(4), mageguildmaster(3), mapmaker(1), merchant(1), merchantguildmaster(1), minerguildmaster(1), minter(2), naturalist(2), provisioner(2), rancher(5), realestatebroker(1), scribe(2), shipwright(1), tailor(5), tailorguildmaster(5), tanner(1), tavernkeeper(6), tinkerguildmaster(1), towncrier(3), veterinarian(2), waiter(6), warriorguildmaster(1), weaponsmith(4), weaver(5) — **plus guards** chaosguard(2), orderguard(4) |
| **Trinsic** | alchemist(1), animaltrainer(2), baker(1), banker(2), barkeeper(1), blacksmith(1)+gm(1), butcher(1), cobbler(2), cook(1), furtrader(1), healer(1)+gm(1), innkeeper(2), jeweler(1), mage(1)+gm(1), mapmaker(1), minter(2), provisioner(2), scribe(1), shipwright(1), tailor(1)+gm(1), tanner(1), tavernkeeper(1), tinkerguildmaster(1), towncrier(2), waiter(1), warriorguildmaster(2), weaver(1) |
| **Minoc** | animaltrainer(1), architect(2), armorer(1), banker(1), bard(1)+gm(1), barkeeper(2), blacksmith(1)+gm(1), butcher(1), carpenter(2), cobbler(3), cook(2), furtrader(1), healer(1)+gm(1), minerguildmaster(2), minter(1), provisioner(3), realestatebroker(2), tanner(1), tavernkeeper(2), tinker(1), tinkerguildmaster(1), towncrier(1), waiter(2), warriorguildmaster(1), weaponsmith(1) |
| **Vesper** | alchemist(6), architect(2), armorer(2), baker(1), banker(1), barkeeper(1), beekeeper(1), bowyer(1), butcher(3), carpenter(2), cook(1), customhairstylist(2), farmer(2), fisherguildmaster(1), fisherman(2), furtrader(1), healer(2)+gm(2), herbalist(2), innkeeper(1), jeweler(1), mage(4)+gm(4), mapmaker(1), minerguildmaster(1), minter(1), realestatebroker(2), shipwright(1), tailor(2)+gm(2), tanner(1), tavernkeeper(1), tinker(1)+gm(1), towncrier(1), waiter(1), warriorguildmaster(1), weaponsmith(2), weaver(2) |
| **Yew** | architect(2), baker(1), bowyer(2), butcher(1), carpenter(2), furtrader(1), healer(1)+gm(1), mapmaker(1), miller(1), realestatebroker(2), shipwright(1), tanner(1) |
| **Skara Brae** | alchemist(2), animaltrainer(1), architect(1), armorer(2), banker(1), blacksmith(1)+gm(1), bowyer(1), butcher(2), carpenter(1), cobbler(1), farmer(1), fisherman(1), healer(1)+gm(1), innkeeper(2), mage(2)+gm(2), mapmaker(1), minter(1), provisioner(1), **rangerguildmaster(1)**, realestatebroker(1), shipwright(1), tailor(1)+gm(1), towncrier(1), weaponsmith(2), weaver(1) |
| **Moonglow** | alchemist(3), architect(1), armorer(2), baker(1), banker(1), butcher(2), carpenter(1), cobbler(1), customhairstylist(1), farmer(1), fisherman(1), healer(1)+gm(1), herbalist(2), innkeeper(2), mage(2)+gm(3), minter(1), provisioner(1), realestatebroker(1), tailor(1)+gm(1), towncrier(1), weaponsmith(2), weaver(1) |
| **Magincia** | banker(1), blacksmith(1)+gm(1), cook(1), fisherguildmaster(1), mapmaker(1), minter(1), shipwright(1), tailor(1)+gm(1), tavernkeeper(1), towncrier(1), waiter(1) |
| **Nujel'm** | banker(1), bardguildmaster(1), barkeeper(4), blacksmith(2)+gm(2), bowyer(1), butcher(1), cook(4), furtrader(1), innkeeper(1), jeweler(1), mapmaker(1), minter(1), shipwright(1), tailor(2)+gm(2), tanner(1), tavernkeeper(4), towncrier(1), waiter(4), weaver(2) |
| **Buccaneer's Den** | architect(2), banker(1), barkeeper(2), blacksmith(1)+gm(1), carpenter(2), cobbler(1), cook(2), fisherman(1), furtrader(1), healer(1)+gm(1), innkeeper(1), minter(1), provisioner(1), realestatebroker(2), tanner(1), tavernkeeper(2), **thiefguildmaster(1)**, waiter(2) |
| **Jhelom** | alchemist(2), architect(2), armorer(4), baker(1), banker(1), barkeeper(2), blacksmith(2)+gm(2), butcher(2), carpenter(2), cobbler(1), cook(2), escortablemage(4), farmer(1), fisherguildmaster(1), fisherman(6), healer(1)+gm(1), innkeeper(1), jeweler(1), mage(2)+gm(2), mapmaker(1), minter(1), provisioner(1), realestatebroker(2), scribe(1), shipwright(1), tailor(4)+gm(4), tavernkeeper(2), tinker(1)+gm(1), towncrier(1), waiter(2), weaponsmith(4), weaver(4) |
| **Ocllo** | alchemist(2), armorer(1), baker(1), banker(1), bardguildmaster(1), butcher(1), cobbler(1), fisherman(2), furtrader(1), healer(1)+gm(1), innkeeper(1), mage(2)+gm(2), mapmaker(1), minter(1), provisioner(1), scribe(1), shipwright(1), tailor(2)+gm(2), tanner(1), tavernkeeper(1), towncrier(1), weaponsmith(1), weaver(2) |
| **Cove** | armorer(1), banker(1), cobbler(1), farmer(1), fisherman(1), minter(1), provisioner(1), towncrier(1), weaponsmith(1) — **smallest service set of any town** |
| **Serpent's Hold** | alchemist(4), animaltrainer(2), armorer(1), baker(1), banker(1), barkeeper(4), blacksmith(1)+gm(1), bowyer(1), butcher(1), cobbler(1), cook(4), customhairstylist(2), fisherman(3), healer(1)+gm(1), herbalist(2), innkeeper(1), mage(2)+gm(2), minter(1), provisioner(1), tailor(2)+gm(2), tavernkeeper(4), tinker(1)+gm(1), towncrier(1), waiter(4), warriorguildmaster(2), weaponsmith(1), weaver(2) |
| **Wind** | alchemist(6), baker(1), banker(1), cobbler(1), customhairstylist(2), healer(1)+gm(1), herbalist(2), innkeeper(3), mage(4)+gm(4), minter(1), naturalist(1), provisioner(1), scribe(2), tailor(2)+gm(2), weaver(2) |
| **Papua** | alchemist(4), animaltrainer(1), architect(2), armorer(1), baker(1), banker(1), butcher(1), carpenter(2), cobbler(1), customhairstylist(2), fisherman(1), healer(1)+gm(1), herbalist(2), innkeeper(1), jeweler(1), mage(2)+gm(2), mapmaker(1), minter(1), provisioner(1), realestatebroker(2), shipwright(1), tailor(2)+gm(2), tinker(1)+gm(1), towncrier(1), weaponsmith(1), weaver(2) |
| **Delucia** | blacksmith(2)+gm(2), cobbler(2), healer(2)+gm(2), innkeeper(1), provisioner(2), tailor(2)+gm(2), weaver(2) — **no banker, no mage, no tinker** |

**Notes for implementers**

- `minter` is **not** a separate NPC profession — it is the *same* Banker class spawned under a different name; it appears wherever a banker does (1–2 per town). 【C】 `Scripts/Mobiles/NPCs/Banker.cs`.
- `*guildmaster` NPCs are a distinct class family (`BaseGuildmaster`). A town with a `tailorguildmaster` also has the Tailors' Guild; guildmasters offer skill training and guild membership. 【C】 `Scripts/Mobiles/NPCs/BaseGuildmaster.cs`.
- **Guards are only visible as spawns in Britain** (chaosguard×2, orderguard×4) in this data set. Other towns rely on the `GuardedRegion` auto-spawn: a guard is instantiated on demand when a crime is reported 【C】 `Scripts/Regions/GuardedRegion.cs:124-158` `MakeGuard()`. See §5.7.
- Wilderness creatures appear inside my padded town boxes (bears, wolves, deer in Moonglow/Yew/Skara Brae). Those are **chaff from box padding**, not town spawns — treat the animal entries in those rows as outside the town proper. 【X】

---

### 1.6 FELUCCA — the moongate network

**【C】** `Scripts/Items/Functional/PublicMoongate.cs` lines 314–330 (`PMList.Felucca`). Each entry is the *landing* point inside the gate.

| # | City served | Landing point (x, y, z) | Label cliloc |
|---:|---|---|---|
| 1 | **Moonglow** | 4467, 1283, 5 | 1012003 |
| 2 | **Britain** | 1336, 1997, 5 | 1012004 |
| 3 | **Jhelom** | 1499, 3771, 5 | 1012005 |
| 4 | **Yew** | 771, 752, 5 | 1012006 |
| 5 | **Minoc** | 2701, 692, 5 | 1012007 |
| 6 | **Trinsic** | 1828, 2948, −20 | 1012008 |
| 7 | **Skara Brae** | 643, 2067, 5 | 1012009 |
| 8 | **Magincia** | 3563, 2139, dynamic z | 1012010 |
| 9 | **Buccaneer's Den** | 2711, 2234, 0 | 1019001 |

**【D】** Independent confirmation — the guard-zone rects for the *"Moongates"* `GuardedRegion` in `runuo/Data/Regions.xml` cover the same 8 classic gates (rect origin ≈ landing − 6):

| City | Guard rect (x, y, W×H) |
|---|---|
| britain | 1330, 1991, 13×13 |
| jhelom | 1494, 3767, 12×11 |
| minoc | 2694, 685, 15×16 |
| trinsic | 1823, 2943, 11×11 |
| yew | 761, 741, 19×21 |
| skara brae | 638, 2062, 12×11 |
| moonglow | 4459, 1276, 16×16 |
| magincia | 3554, 2132, 18×18 |

**Other facets' public gates** 【C】 `PublicMoongate.cs`:

| Facet | Destinations (x, y, z) |
|---|---|
| **Trammel** | Moonglow 4467,1283,5 · Britain 1336,1997,5 · Jhelom 1499,3771,5 · Yew 771,752,5 · Minoc 2701,692,5 · Trinsic 1828,2948,−20 · Skara Brae 643,2067,5 · Magincia 3563,2139 · **New Haven 3450,2677,25** (9 gates) |
| **Ilshenar** | Compassion 1215,467,−13 · Honesty 722,1366,−60 · Honor 744,724,−28 · Humility 281,1016,0 · Justice 987,1011,−32 · Sacrifice 1174,1286,−30 · Spirituality 1532,1340,−3 · Valor 528,216,−45 · **Chaos 1721,218,96** (9 gates — one per virtue + Chaos) |
| **Malas** | Luna 1015,527,−65 · Umbra 1997,1386,−85 (2 gates) |
| **Tokuno** | Isamu-Jima 1169,998,41 · Makoto-Jima 802,1204,25 · Homare-Jima 270,628,15 (3 gates) |
| **TerMur** | Royal City 850,3525,−38 · Valley of Eodon 926,3989,−36 (2 gates) |

**Which facet lists are offered, by expansion** 【C】 `PublicMoongate.cs:383-394`:

| Era gate set | Facets offered |
|---|---|
| UO:R | Trammel, Felucca (`UORLists`); young players: Trammel only (`UORListsYoung`) |
| LBR | + Ilshenar (`LBRLists`); young: Trammel, Ilshenar |
| AoS | + Malas (`AOSLists`); young: Trammel, Ilshenar, Malas |
| SE | + Tokuno (`SELists`) |
| SA | + TerMur (`SALists`) |
| Red / Sigil | Felucca only (`RedLists`, `SigilLists`) |

**Gate mechanism**
- A blue public moongate is `PublicMoongate : Item`; double-click opens `MoongateGump` listing the destinations of the permitted facets; selecting one teleports the player. 【C】 `PublicMoongate.cs:125-131, 226-227, 496+`
- The gate the player is *standing on* determines which entry is "you are here"; `PMList.FindEntry(list, Location)` matches by proximity. 【C】 `PublicMoongate.cs:248-255, 455`
- Gump styling: one page per facet list, entries show cliloc city names; "young" players get the reduced list. 【C】 `PublicMoongate.cs:508-552`

**Classic lunar-phase travel — UNVERIFIED in code.**
Pre-gump UO selected the destination from the **phase of the two moons** (Trammel & Felucca), giving the well-known 8-destination cycle. The UO Second Age hintbook states *"If you know the exact phase of both moons, you can use the rings for moongate travel"* ([mocagh.org UO Second Age hintbook, p.38](https://mocagh.org/origin/uosecondage-hintbook.pdf)). **The exact phase→destination table is not in any server repo I read** — modern ServUO replaced it with the gump, so the original table has no code witness here.
**To measure:** capture the pre-UO:R client's moongate handler (client 1.25–2.0.x disassembly) or the OSI server's `moongate` script; alternatively derive empirically from a UO:R-era demo/free-shard capture. For the clone, the gump version in §1.6 is implementable today and behaviourally equivalent for a single player.

---

### 1.7 FELUCCA — dungeons

**【D】** Entrance and level coordinates from `runuo/Data/Locations/felucca.xml`; level extents from the `DungeonRegion` rects in `runuo/Data/Regions.xml`. **Dungeon interiors live in the high-coordinate "void" of map0 (x ≈ 5120–6200, y ≈ 0–2100) — not underneath the entrance.**

| Dungeon | Surface entrance (x, y, z) | Levels & interior coordinates | Level structure | Classic inhabitants |
|---|---|---|---|---|
| **Covetous** | **2499, 919, 0** | L1 5456,1863,0 · L2 5614,1997,0 · L3 5579,1924,0 · Lake Cave 5467,1805,7 · Torture Chambers 5552,1807,0 | 3 levels + 2 sub-areas. Region rects (5376,1793 255×255) + (5576,1791 257×257) | Harpies, gargoyles, earth elementals, water elementals (Lake Cave), ogres, liches |
| **Deceit** | **4111, 432, 5** | L1 5188,638,0 · L2 5305,533,2 · L3 5137,650,5 · L4 5306,652,2 | **4 levels** | Skeletons, zombies, ghouls, bone magicians, liches, wraiths |
| **Despise** | **1298, 1080, 0** | Entryway 5587,631,30 · L1 5501,570,59 · L2 5519,673,20 · L3 5407,859,45 | 3 levels + entryway. Region (5377,516 506×506) | Lizardmen, ettins, ogres, trolls, orcs, earth elementals; **Despise also hosts the good/evil creature split** (`DespiseCreature.cs`, `DespiseEvilCreatures.cs`, `DespiseGoodCreatures.cs`) |
| **Destard** | **1176, 2637, 0** | L1 5243,1006,0 · L2 5143,801,4 · L3 5137,986,5 | 3 levels. Region (5120,770 258×258) | **Dragons, drakes, wyverns**, harpies |
| **Hythloth** | **4721, 3822, 0** | L1 5905,20,46 · L2 5976,169,0 · L3 6083,145,−20 · L4 6059,89,24 | **4 levels**. Region (5898,2 244×244) | Daemons, balrons, dragons, gargoyles, imps |
| **Shame** | **514, 1561, 0** | L1 5395,126,0 · L2 5515,11,5 · L3 5514,148,25 · L4 5875,20,−5 | **4 levels**. Region (5377,2 260×260) + (5635,2 124×124) | Earth/air/fire/water elementals, gargoyles, ogre lords, dragons |
| **Wrong** | **2043, 238, 10** | L1 5825,630,0 · L2 5690,569,25 · L3 5703,639,0 | 3 levels. Region (5633,511 510×510) — **the largest dungeon region in the file** | Ogres, ogre lords, trolls, ettins, lizardmen; orc cave complex adjacent |
| **Terathan Keep** | **5451, 3143, −60** | L1 5342,1601,0 · **Champion Room 5205,1585,0** · **Starroom 5139,1767,0** | 1 main level + champion room + star room. Region (5404,3099 68×68) + (5120,1530 258×258) | Terathan warriors/avengers/matriarchs, ophidians |
| **Fire Dungeon** | **5760, 2908, 15** *(Lost Lands)* · Brit entrance 2923,3407,8 | L1 5790,1416,40 · L2 5702,1316,1 | 2 levels. Region (5635,1285 235×235) | Fire elementals, efreets, fire steeds, daemons, dragons |
| **Ice Dungeon** | **5210, 2322, 30** *(Lost Lands)* · Brit entrance 1999,81,4 | L1 5875,150,15 · **Ratman Room 5834,327,18** · **Ice Demon Lair 5700,305,0** | 1 main level + 2 sub-areas. Region (5668,130 138×138)+(5800,319 65×65)+(5654,300 40×40) | Frost spiders, ice hounds, ice serpents, white wyrms, polar bears, ice fiends |
| **Orc Cave** | **1019, 1431, 0** | L1 5137,2014,0 · L2 5332,1376,0 · L3 5272,2036,0 | 3 levels. Region rects are **malformed/empty in `Regions.xml`** 【D】 (`<rect x="" y="" …>`) | Orcs, orc captains, orc bombers, orc mages, evil mages |
| **Khaldun** | **Entrance 1: 6009, 3775, 19** · Entrance 2: 5882, 3819, −1 | L1 5571,1302,0 | Single large level (the "puzzle" dungeon). Region (5381,1284 225×225) | Khaldun zealots, skeletons, mummies, liches, *Khaldun* unique encounters |
| **Solen Hives** | Area A **729, 1451, 0** · Area B **2607, 763, 0** · Area C **1689, 2789, 0** · Area D **1723, 814, 0** · Area E 5732,1858,0 | Central Area 5774,1896,20 · A: L1 5658,1795,3, L2 5726,1891,1 · B: L1 5921,1797,1, L2 5875,1866,2 · C: L1 5659,2022,0, L2 5708,1955,0 · D: L1 5916,2019,3, L2 5813,2012,−1 | 5 entrances, 4 two-level hives, 1 central hub | Solen workers/warriors/queens (black, red, blue…), ants |
| **Misc Dungeons** | **1492, 1641** (Britain sewer area) | go 6032,1499,0 | catch-all region | mixed |
| **Despise Passage** | — | (1338,1060 62×62) (1354,1122 121×121) (1349,1122 102×102), go 1380,1114 | Connecting corridors between Despise entrance and dungeon | — |

**【D】** `runuo/Data/Locations/felucca.xml`, `runuo/Data/Regions.xml`.
**Also registered as dungeons on Felucca (Mondain's Legacy content grafted onto map0):** Sanctuary (entrance 762,1645 → 6174,23) · The Painted Caves (1716,892 → 6308,892) · The Prism of Light (3784,1097 → 6474,188) · Blighted Grove (587,1641 → 6478,863) · The Palace of Paroxysmus (5574,3024 → 6222,335) · The Heartwood (535,995 → 6984,337). 【D】

**Shrines (Felucca)** 【D】 `Locations/felucca.xml`: Chaos 1456,854 · Compassion 1856,872 · Honesty 4217,564 · Honor 1730,3528 · Humility 4276,3699 · Justice 1301,639 · Sacrifice 3355,299 · Spirituality 1589,2485 · Valor 2496,3932.

---


## 2. NPC types

### 2.1 How a vendor NPC is assembled (ServUO)

Four independent pieces, all of which the clone must reproduce 【C】 `Scripts/Mobiles/NPCs/*.cs`, `Scripts/VendorInfo/*.cs`:

1. **Class** — `public class Blacksmith : BaseVendor`, ctor `: base("the blacksmith")` supplies the **title** appended to the random name.
2. **Skills** — `SetSkill(SkillName.X, min, max)` in the ctor. If `min == max` the value is fixed; otherwise random in range.
3. **Shop** — `InitSBInfo()` adds one or more `SBInfo` objects; each `SBInfo` has a `BuyInfo` list (`GenericBuyInfo`) and a `SellInfo` (`GenericSellInfo`).
4. **Outfit** — `InitOutfit()` calls `AddItem(new X())`; `base.InitOutfit()` adds the standard shirt/trousers/shoes/hair.

`BaseVendor` is itself a `BaseCreature` with these fixed traits 【C】 `Scripts/Mobiles/NPCs/BaseVendor.cs:54-76`:

| Property | Value | Note |
|---|---|---|
| `CanTeach` | `true` | Players can buy skill training |
| `BardImmune` | `true` | Cannot be provoked/discorded |
| `PlayerRangeSensitive` | `true` | AI sleeps when no player near |
| `UseSmartAI` | `true` | |
| `IsInvulnerable` | `true` | **Vendors cannot be killed** |
| `IsActiveVendor` | `true` | Master switch |
| `IsActiveBuyer` | `IsActiveVendor && !Siege.SiegeShard` | Vendors buy from players |
| `IsActiveSeller` | `IsActiveVendor` | Vendors sell to players |
| `HasHonestyDiscount` | `true` | Honesty virtue discounts prices |
| `ShowFameTitle` | `false` | |
| `GetMoveDelay` | `Utility.RandomMinMax(30, 120)` | Wander delay |
| `ShoeType` | `VendorShoeType` enum: `None, Shoes, Boots, Sandals, ThighBoots` | Controls footwear |

**【C】** `Scripts/Mobiles/NPCs/BaseVendor.cs:1-30` for the `VendorShoeType` enum.

### 2.2 Complete vendor NPC catalogue

120 vendor-family classes exist in `Scripts/Mobiles/NPCs/`. Below: **all classes that have a shop** (57), plus the notable non-shop ones. Skill format is `Skill:min-max`; a single number means fixed.

#### 2.2.1 Classic (pre-AoS) shop vendors — full table

**【C】** parsed from `Scripts/Mobiles/NPCs/*.cs`.

| Class | Title | Guild | Shoe | Skills | Shop (SBInfo) | Outfit added |
|---|---|---|---|---|---|---|
| **Alchemist** | the alchemist | — | — | Alchemy 85–100, TasteID 65–88 | `SBAlchemist` | Robe (random pink hue) |
| **AnimalTrainer** | the animal trainer | — | ThighBoots | AnimalLore 64–100, AnimalTaming 90–100, Veterinary 65–88 | `SBAnimalTrainer` | — |
| **Architect** | the architect | TinkersGuild | — | — | `SBHouseDeed`, `SBArchitect` | — |
| **Armorer** | the armourer | — | Boots | ArmsLore 64–100, Blacksmith 60–83 | `SBLeatherArmor`, `SBStuddedArmor`, `SBMetalShields`, `SBPlateArmor`, `SBHelmetArmor`, `SBChainmailArmor`, `SBRingmailArmor` (+SE: `SBSELeatherArmor`, `SBSEArmor`) | HalfApron, Bascinet |
| **Baker** | the baker | — | — | Cooking 75–98, TasteID 36–68 | `SBBaker` | — |
| **Banker** | the banker | MerchantsGuild | — | — | `SBBanker` | — |
| **Bard** | the bard | BardsGuild | — | Discordance 64–100, Musicianship 64–100, Peacemaking 65–88, Provocation 60–83, Archery 36–68, Swords 36–68 | `SBBard` | — |
| **Barkeeper** | the barkeeper | — | ThighBoots | — | `SBBarkeeper` | HalfApron |
| **Beekeeper** | the beekeeper | — | Boots | — | `SBBeekeeper` | — |
| **Blacksmith** | the blacksmith | BlacksmithsGuild | None | ArmsLore 36–68, Blacksmith 65–88, Fencing 60–83, Macing 61–93, Swords 60–83, Tactics 60–83, Parry 61–93 | `SBBlacksmith` (+`SBSmithTools`, `SBMetalShields`, `SBWoodenShields`, `SBPlateArmor`, `SBHelmetArmor`, `SBChainmailArmor`, `SBRingmailArmor`, `SBAxeWeapon`, `SBPoleArmWeapon`, `SBRangedWeapon`, `SBKnifeWeapon`, `SBMaceWeapon`, `SBSpearForkWeapon`, `SBSwordWeapon`) | 50% RingmailChest **or** FullApron; always Bascinet, SmithHammer |
| **Bowyer** | the bowyer | — | ThighBoots | Fletching 80–100, Archery 80–100 | `SBBowyer`, `SBRangedWeapon` | Bow, LeatherGorget |
| **Butcher** | the butcher | — | — | Anatomy 45–68 | `SBButcher` | HalfApron, Cleaver |
| **Carpenter** | the carpenter | TinkersGuild | — | Carpentry 85–100, Lumberjacking 60–83 | `SBCarpenter`, `SBStavesWeapon`, `SBWoodenShields` | HalfApron |
| **Cobbler** | the cobbler | — | Sandals | Tailoring 60–83 | `SBCobbler` | — |
| **Cook** | the cook | — | Sandals | Cooking 90–100, TasteID 75–98 | `SBCook` | HalfApron |
| **Farmer** | the farmer | — | ThighBoots | Lumberjacking 36–68, TasteID 36–68, Cooking 36–68 | `SBFarmer` | WideBrimHat |
| **Fisherman** | the fisher | FishermensGuild | — | Fishing 75–98 | `SBFisherman` | FishingPole |
| **Furtrader** | the furtrader | — | — | Camping 55–78, Alchemy 60–83, AnimalLore 85–100, Cooking 45–68, Tracking 36–68 | `SBFurtrader` | — |
| **Gardener** | the gardener | — | ThighBoots | — | `SBGardener` | — |
| **Glassblower** | the alchemist | MagesGuild | — | Alchemy 85–100, TasteID 85–100 | `SBGlassblower` (+`SBAlchemist`) | — |
| **HairStylist** | the hair stylist | — | — | Alchemy 80–100, Magery 90–110, TasteID 85–100 | `SBHairStylist` | — |
| **Healer** | — (`BaseHealer`) | — | — | Healer skills | `SBHealer` | Robe |
| **Herbalist** | the herbalist | MagesGuild | Shoes | Alchemy 80–100, Cooking 80–100, TasteID 80–100 | `SBHerbalist` | — |
| **HolyMage** | the Holy Mage | — | — | EvalInt 65–88, Inscribe 60–83, Magery 64–100, Meditation 60–83, MagicResist 65–88, Wrestling 36–68 | `SBHolyMage` | — |
| **InnKeeper** | the innkeeper | — | Sandals | — | `SBInnKeeper` (+SE: `SBSEFood`) | — |
| **Jeweler** | the jeweler | — | — | ItemID 64–100 | `SBJewel` | — |
| **LeatherWorker** | the leather worker | — | — | — | `SBLeatherArmor`, `SBStuddedArmor`, `SBLeatherWorker` | — |
| **Mage** | the mage | MagesGuild | Shoes | EvalInt 65–88, Inscribe 60–83, Magery 64–100, Meditation 60–83, MagicResist 65–88, Wrestling 36–68 | `SBMage` | Robe |
| **Mapmaker** | the mapmaker | — | — | Cartography 90–100 | `SBMapmaker` | — |
| **Miller** | the miller | — | — | — | `SBMiller` | — |
| **Miner** | the miner | — | — | Mining 65–88 | `SBMiner` | FancyShirt, LongPants, Pickaxe, ThighBoots |
| **Provisioner** | the provisioner | — | — | Camping 45–68, Tactics 45–68 | `SBProvisioner` (+SE: `SBSEHats`) | — |
| **Rancher** | the rancher | — | — | AnimalLore 55–78, AnimalTaming 55–78, Herding 64–100, Veterinary 60–83 | `SBRancher` | — |
| **Ranger** | the ranger | — | — | Camping 55–78, DetectHidden 65–88, Hiding 45–68, Archery 65–88, Tracking 65–88, Veterinary 60–83 | `SBRanger` | Shirt, LongPants, Bow, ThighBoots |
| **RealEstateBroker** | the real estate broker | — | — | — | `SBRealEstateBroker` | — |
| **Scribe** | the scribe | — | — | EvalInt 60–83, Inscribe 90–100 | `SBScribe` | Robe (random neutral hue) |
| **Shipwright** | the shipwright | — | — | Carpentry 60–83, Macing 36–68 | `SBShipwright` | SmithHammer |
| **StoneCrafter** | the stone crafter | TinkersGuild | — | Carpentry 85–100 | `SBStoneCrafter`, `SBStavesWeapon`, `SBCarpenter`, `SBWoodenShields` | — |
| **Tailor** | the tailor | TailorsGuild | Sandals | Tailoring 64–100 | `SBTailor` (+SA: `SBSATailor`) | — |
| **Tanner** | the tanner | — | — | Tailoring 36–68 | `SBTanner` (+SA: `SBSATanner`) | — |
| **TavernKeeper** | the tavern keeper | — | — | — | `SBTavernKeeper` | HalfApron |
| **Thief** | the thief | — | — | Camping 55–78, DetectHidden 65–88, Hiding 45–68, Archery 65–88, Tracking 65–88, Veterinary 60–83, RemoveTrap 75–98 | `SBThief` | Shirt, LongPants, Dagger, ThighBoots |
| **Tinker** | the tinker | — | — | Lockpicking 60–83, RemoveTrap 75–98, Tinkering 64–100 | `SBTinker` | — |
| **Vagabond** | the vagabond | — | — | Begging 64–100, ItemID 60–83 | `SBVagabond` | FancyShirt, Shoes, LongPants, Cloak, SkullCap, Bandana |
| **VarietyDealer** | the variety dealer | — | — | — | `SBVarietyDealer` | — |
| **Veterinarian** | the vet | — | — | AnimalLore 85–100, Veterinary 90–100 | `SBVeterinarian` | — |
| **Waiter** | the waiter | — | — | Discordance 36–68 | `SBWaiter` | HalfApron |
| **Weaponsmith** | the weaponsmith | — | — | (as Blacksmith family) | `SBWeaponSmith` | — |
| **Weaver** | the weaver | — | — | — | `SBWeaver` | — |
| **IronWorker** | the iron worker | — | None | Begging 64–100, ArmsLore 36–68, Blacksmith 65–88, Fencing 60–83, Macing 61–93, Swords 60–83, Tactics 60–83, Parry 61–93 | `SBAxeWeapon`, `SBKnifeWeapon`, `SBMaceWeapon`, `SBSmithTools`, `SBPoleArmWeapon`, `SBSpearForkWeapon`, `SBSwordWeapon`, `SBMetalShields`, `SBHelmetArmor`, `SBPlateArmor`, `SBChainmailArmor`, `SBRingmailArmor`, `SBStuddedArmor`, `SBLeatherArmor` | JesterHat/Bandana, Bascinet, FullApron, SmithHammer |
| **GypsyMaiden** | the gypsy maiden | — | — | Begging 64–100 | `SBProvisioner` | JesterHat/Bandana, SkullCap, HalfApron |
| **GolemCrafter** | the golem crafter | — | — | Lockpicking 60–83, RemoveTrap 75–98, Tinkering 64–100 | `SBVagabond` | — |
| **Monk** | the Monk | — | — | EvalInt 100 (fixed), Tactics 70–90, Wrestling 70–90, MagicResist 70–90, Macing 70–90 | `SBMonk` | Sandals, MonkRobe |
| **KeeperOfChivalry** | the Keeper of Chivalry | — | — | Fencing/Macing/Swords 75–85, Chivalry 100 (fixed) | `SBKeeperOfChivalry` | Full plate + Broadsword |

#### 2.2.2 Expansion-only shop vendors

| Class | Title | Shop | Era |
|---|---|---|---|
| **Necromancer** | the Necromancer | `SBNecromancer` | AoS |
| **Mystic** | the mystic | `SBMystic` | SA |
| **KeeperOfBushido** | — | `SBKeeperOfBushido` | SE |
| **KeeperOfNinjitsu** | — | `SBKeeperOfNinjitsu` | SE |
| **CustomHairstylist** | the hairstylist | `SBHairStylist` | — |
| **PlayerBarkeeper** | the barkeeper | `SBPlayerBarkeeper` | player-hired |
| **Elf/Gargoyle variants** (`Alelle`, `Daelas`, `Yellienir`, `Vrulkax`, `Athialon`, `Tyleelor`, `Nythalia`, `Olaeni`, …) | the aborist / the bark weaver / the Exalted Artificer / the expeditionist / the student / the thaumaturgist | none — quest NPCs | ML/SA |

#### 2.2.3 Non-vendor town NPCs

| Class | Base | Behaviour 【C】 |
|---|---|---|
| **WarriorGuard** / **ArcherGuard** | `BaseGuard` | Town guards. Spawned on demand by `GuardedRegion.MakeGuard(focus)`; the default type per region is `WarriorGuard`, or `ArcherGuard` for some regions. They teleport to the criminal and kill them. 【C】 `Scripts/Mobiles/NPCs/BaseGuard.cs`, `Scripts/Regions/GuardedRegion.cs:65-158` |
| **OrderGuard** / **ChaosGuard** | `BaseShieldGuard` | Faction guards (Order/Chaos); hold a shield and are tied to faction strongholds. |
| **MansionGuard** | `BaseGuard` | Static house guard. |
| **TownCrier** | `Mobile` (not a vendor) | Neutral body `0x191` female / `0x190` male, `NameList.RandomName("female"/"male")`, FancyShirt (blue hue) + skirt + FeatheredHat (green) + boots. Shouts news every **1 to 5 minutes** (`Timer.DelayCall(TimeSpan.FromMinutes(1.0), TimeSpan.FromMinutes(5.0), …)`). Reacts to the keyword *news* within 12 tiles. 【C】 `Scripts/Mobiles/NPCs/TownCrier.cs` |
| **Gypsy** | `BaseCreature` | `AI_Animal / FightMode.None`. Skills: Begging 64–100, Cooking 65–88, Snooping 65–88, Stealing 65–88. Carries a backpack with `Gold(250, 300)`. Female: Kilt + Shirt + ThighBoots; Male: ShortPants + Shirt + Sandals + Bandana + Dagger. 【C】 `Scripts/Mobiles/NPCs/Gypsy.cs` |
| **GypsyBanker / GypsyFortuneTeller / GypsyAnimalTrainer** | vendor subclasses | Camp gypsy variants of banker/fortune-teller/animal trainer. |
| **BaseHealer** family: `Healer`, `WanderingHealer`, `EvilHealer`, `EvilWanderingHealer`, `PricedHealer`, `ShrineHealer`, `GargishWanderingHealer`, `GypsyFortuneTeller` | `BaseHealer` | Resurrect players (some for a fee — `PricedHealer`), and sell `SBHealer` goods. `EvilHealer`/`EvilWanderingHealer` are hostile-aligned and appear in the wilderness spawn tables (24 and 13 spawn points on Felucca 【X】). |
| **Beggar** | — | **UNVERIFIED as a class.** No `Beggar.cs` exists in ServUO `Scripts/Mobiles/NPCs`. Begging exists as a *skill* and as `HireBeggar` (a hireable). Classic town beggars are therefore not implemented as a distinct NPC here. **To measure:** check RunUO 2.x `Scripts/Mobiles/Townfolk/` — RunUO shipped a `Beggar : BaseVendor`-like class in some revisions; or confirm from a UO:R client capture. |
| **Hireables** (`BaseHire`): `HireFighter`, `HireBard`, `HireBardArcher`, `HireMage`, `HirePaladin`, `HireRanger`, `HireRangerArcher`, `HireThief`, `HireBeggar`, `HirePeasant`, `HireSailor` | `BaseHire` | Paid NPC mercenaries. Spawn counts on Felucca: `hirepeasant` 5+ in Britain, `hirefighter` 3 in Britain, full set of 10 in Jhelom 【X】. |
| **Escortables** (`BaseEscortable`): `EscortableMage`, `Noble`, `SeekerOfAdventure`, `Merchant`, `Messenger`, `Peasant`, `BrideGroom`, `GargishNoble` | `BaseEscortable` | See §6.1. |
| **Guildmasters** (`BaseGuildmaster`): `BlacksmithGuildmaster`, `TailorGuildmaster`, `MageGuildmaster`, `BardGuildmaster`, `HealerGuildmaster`, `MinerGuildmaster`, `FisherGuildmaster`, `TinkerGuildmaster`, `WarriorGuildmaster`, `RangerGuildmaster`, `ThiefGuildmaster`, `MerchantGuildmaster` | `BaseGuildmaster` | Offer skill training and guild membership. Titles: `"blacksmith"`, `"tailor"`, `"mage"`, `"bard"`, `"healer"`, `"miner"`, `"fisher"`, `"tinker"`, `"warrior"`, `"ranger"`, `"thief"`, `"merchant"`. |
| **Named quest NPCs** (~150 classes: `Natalie`, `Gregorio`, `Blackheart`, `Belulah`, `Lefty`, `Thalia`, `Darius`, `Fabrizio`, `Andros`, `Ben`, `Leon`, `Patricus`, `Nedrick`, `Sledge`, `Ioseph`, `Szandor`, `Aurelia`, `Emilio`, `Evan`, `Regina`, `Sarakki`, `Verity`, `Sir Berran`, `Sir Felean`, `Sir Hareus`, `SosariaSap`, …) | various | Spawned 1× by a `Spawner` object, not by region spawn. |

### 2.3 Restock rules

**【C】** `Scripts/Mobiles/NPCs/BaseVendor.cs`:

| Rule | Value | Line |
|---|---|---|
| Restock interval | `DelayRestock = TimeSpan.FromMinutes(Config.Get("Vendors.RestockDelay", 60))` → **60 minutes** | 37 |
| Restock trigger | On `VendorBuy`, if `DateTime.UtcNow - m_LastRestock > RestockDelay` → `Restock()` | 920-923 |
| What restock does | Sets `m_LastRestock = UtcNow`, then `bii.OnRestock()` for every `IBuyItemInfo` | 888-898 |
| Manual restock | `[ForceRestock` GM property → `Restock(); Say("Restocked!")` | 875-886 |
| Max sell value accepted | `MaxSell = Config.Get("Vendors.MaxSell", 500)` | 38 |
| Economy stock (AoS only) | `EconomyStockAmount = 500` | 36 |
| Buy item change (AoS only) | `BuyItemChange = 1000` | 34 |
| Sell item change (AoS only) | `SellItemChange = 1000` | 35 |
| Gump item cap | `if (buyItem.Amount <= 0 \|\| list.Count >= 250) continue;` → **max 250 rows in the buy gump** | 941 |
| Inventory decay | `InventoryDecayTime = TimeSpan.FromHours(1.0)` | 900 |
| Vendor label key | `"Vendors.RestockDelay"`, `"Vendors.MaxSell"`, … read from `Config` | — |

Stock quantities are baked into each `SBInfo` entry as the 3rd `GenericBuyInfo` argument — e.g. `new GenericBuyInfo(typeof(IronIngot), 5, 16, 0x1BF2, 0, true)` = **price 5 gp, max stock 16**. 【C】 `Scripts/VendorInfo/SBBlacksmith.cs`. Typical stock values seen: **10** (potions/scrolls), **20** (weapons, armour, reagents), **100** (bottles, cheap tools), **30** (books).

### 2.4 Vendor shop inventories (buy & sell lists)

The next section is machine-generated from all 88 `SB*` classes in `Scripts/VendorInfo/`. Format:

- **Stock sold to players** — `(item, price in gold, max stock)`, i.e. `GenericBuyInfo(type, price, amount, itemID, hue)`.
- **Buys from players** — `(item, unit price in gold)`, i.e. `GenericSellInfo.Add(type, price)`.

**【C】** `Scripts/VendorInfo/*.cs`. Generation script: `.cache/analysis/extract-*` + `.cache/analysis/gen-sb-tables.ps1`.

**Read the "Used by" line**: an `SB*` class is only reachable if some vendor NPC adds it in `InitSBInfo()`.

### 2.4.1 Shop inventory tables — all 88 SBInfo definitions

The tables below are the complete `GenericBuyInfo` / `GenericSellInfo` contents of every `SB*` class in `ServUO/Scripts/VendorInfo/`.

#### `SBAlchemist`

Used by: Alchemist, Glassblower

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| RefreshPotion | 15 | 10 |
| AgilityPotion | 15 | 10 |
| NightSightPotion | 15 | 10 |
| LesserHealPotion | 15 | 10 |
| StrengthPotion | 15 | 10 |
| LesserPoisonPotion | 15 | 10 |
| LesserCurePotion | 15 | 10 |
| LesserExplosionPotion | 21 | 10 |
| MortarPestle | 8 | 10 |
| BlackPearl | 5 | 20 |
| Bloodmoss | 5 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| MandrakeRoot | 3 | 20 |
| Nightshade | 3 | 20 |
| SpidersSilk | 3 | 20 |
| SulfurousAsh | 3 | 20 |
| Bottle | 5 | 100 |
| HeatingStand | 2 | 100 |
| SkinTingeingTincture | 1255 | 20 |
| HairDye | 37 | 10 |
| GlassblowingBook | 10637 | 30 |
| SandMiningBook | 10637 | 30 |
| Blowpipe | 21 | 100 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BlackPearl | 3 |
| Bloodmoss | 3 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| Bottle | 3 |
| MortarPestle | 4 |
| HairDye | 19 |
| NightSightPotion | 7 |
| AgilityPotion | 7 |
| StrengthPotion | 7 |
| RefreshPotion | 7 |
| LesserCurePotion | 7 |
| CurePotion | 11 |
| GreaterCurePotion | 15 |
| LesserHealPotion | 7 |
| HealPotion | 11 |
| GreaterHealPotion | 15 |
| LesserPoisonPotion | 7 |
| PoisonPotion | 9 |
| GreaterPoisonPotion | 13 |
| DeadlyPoisonPotion | 21 |
| LesserExplosionPotion | 10 |
| ExplosionPotion | 15 |
| GreaterExplosionPotion | 25 |


#### `SBAnimalTrainer`

Used by: AnimalTrainer


#### `SBArchitect`

Used by: Architect

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| InteriorDecorator | 10001 | 20 |
| HousePlacementTool | 627 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| InteriorDecorator | 5000 |
| HousePlacementTool | 301 |


#### `SBAxeWeapon`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| ExecutionersAxe | 30 | 20 |
| BattleAxe | 26 | 20 |
| TwoHandedAxe | 32 | 20 |
| Axe | 40 | 20 |
| DoubleAxe | 52 | 20 |
| Pickaxe | 22 | 20 |
| LargeBattleAxe | 33 | 20 |
| WarAxe | 29 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BattleAxe | 13 |
| DoubleAxe | 26 |
| ExecutionersAxe | 15 |
| LargeBattleAxe | 16 |
| Pickaxe | 11 |
| TwoHandedAxe | 16 |
| WarAxe | 14 |
| Axe | 20 |


#### `SBBaker`

Used by: Baker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| FreshGinger | 505 | 10 |
| BreadLoaf | 6 | 20 |
| BreadLoaf | 5 | 20 |
| ApplePie | 7 | 20 |
| Cake | 13 | 20 |
| Muffins | 3 | 20 |
| SackFlour | 3 | 20 |
| FrenchBread | 5 | 20 |
| Cookies | 3 | 20 |
| CheesePizza | 8 | 10 |
| JarHoney | 3 | 20 |
| BowlFlour | 7 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BreadLoaf | 3 |
| FrenchBread | 1 |
| Cake | 5 |
| Cookies | 3 |
| Muffins | 2 |
| CheesePizza | 4 |
| ApplePie | 5 |
| PeachCobbler | 5 |
| Quiche | 6 |
| Dough | 4 |
| JarHoney | 1 |
| Pitcher | 5 |
| SackFlour | 1 |
| Eggs | 1 |


#### `SBBanker`

Used by: Banker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| ContractOfEmployment | 1252 | 20 |
| VendorRentalContract | 1252 | 20 |
| CommissionContractOfEmployment | 28127 | 20 |
| CommodityDeed | 5 | 20 |


#### `SBBard`

Used by: Bard

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| LapHarp | 10 |
| Lute | 10 |
| Drums | 10 |
| Harp | 10 |
| Tambourine | 10 |


#### `SBBarkeeper`

Used by: Barkeeper

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BreadLoaf | 6 | 10 |
| CheeseWheel | 21 | 10 |
| CookedBird | 17 | 20 |
| LambLeg | 8 | 20 |
| WoodenBowlOfCarrots | 3 | 20 |
| WoodenBowlOfCorn | 3 | 20 |
| WoodenBowlOfLettuce | 3 | 20 |
| WoodenBowlOfPeas | 3 | 20 |
| EmptyPewterBowl | 2 | 20 |
| PewterBowlOfCorn | 3 | 20 |
| PewterBowlOfLettuce | 3 | 20 |
| PewterBowlOfPeas | 3 | 20 |
| PewterBowlOfPotatos | 3 | 20 |
| WoodenBowlOfStew | 3 | 20 |
| WoodenBowlOfTomatoSoup | 3 | 20 |
| ApplePie | 7 | 20 |
| Chessboard | 2 | 20 |
| CheckerBoard | 2 | 20 |
| Backgammon | 2 | 20 |
| Dices | 2 | 20 |
| ContractOfEmployment | 1252 | 20 |
| BarkeepContract | 1252 | 20 |
| VendorRentalContract | 1252 | 20 |
| Wasabi | 2 | 20 |
| Wasabi | 2 | 20 |
| BentoBox | 6 | 20 |
| BentoBox | 6 | 20 |
| GreenTeaBasket | 2 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| WoodenBowlOfCarrots | 1 |
| WoodenBowlOfCorn | 1 |
| WoodenBowlOfLettuce | 1 |
| WoodenBowlOfPeas | 1 |
| EmptyPewterBowl | 1 |
| PewterBowlOfCorn | 1 |
| PewterBowlOfLettuce | 1 |
| PewterBowlOfPeas | 1 |
| PewterBowlOfPotatos | 1 |
| WoodenBowlOfStew | 1 |
| WoodenBowlOfTomatoSoup | 1 |
| BeverageBottle | 3 |
| Jug | 6 |
| Pitcher | 5 |
| GlassMug | 1 |
| BreadLoaf | 3 |
| CheeseWheel | 12 |
| Ribs | 6 |
| Peach | 1 |
| Pear | 1 |
| Grapes | 1 |
| Apple | 1 |
| Banana | 1 |
| Candle | 3 |
| Chessboard | 1 |
| CheckerBoard | 1 |
| Backgammon | 1 |
| Dices | 1 |
| ContractOfEmployment | 626 |


#### `SBBeekeeper`

Used by: Beekeeper

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| JarHoney | 3 | 20 |
| Beeswax | 2 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| JarHoney | 1 |
| Beeswax | 1 |


#### `SBBlacksmith`

Used by: Blacksmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| IronIngot | 5 | 16 |
| Tongs | 13 | 14 |
| BronzeShield | 66 | 20 |
| Buckler | 50 | 20 |
| MetalKiteShield | 123 | 20 |
| HeaterShield | 231 | 20 |
| WoodenKiteShield | 70 | 20 |
| MetalShield | 121 | 20 |
| WoodenShield | 30 | 20 |
| PlateGorget | 104 | 20 |
| PlateChest | 243 | 20 |
| PlateLegs | 218 | 20 |
| PlateArms | 188 | 20 |
| PlateGloves | 155 | 20 |
| PlateHelm | 21 | 20 |
| CloseHelm | 18 | 20 |
| CloseHelm | 18 | 20 |
| Helmet | 31 | 20 |
| Helmet | 18 | 20 |
| NorseHelm | 18 | 20 |
| NorseHelm | 18 | 20 |
| Bascinet | 18 | 20 |
| PlateHelm | 21 | 20 |
| ChainCoif | 17 | 20 |
| ChainChest | 143 | 20 |
| ChainLegs | 149 | 20 |
| RingmailChest | 121 | 20 |
| RingmailLegs | 90 | 20 |
| RingmailArms | 85 | 20 |
| RingmailGloves | 93 | 20 |
| ExecutionersAxe | 30 | 20 |
| Bardiche | 60 | 20 |
| BattleAxe | 26 | 20 |
| TwoHandedAxe | 32 | 20 |
| Bow | 35 | 20 |
| ButcherKnife | 14 | 20 |
| Crossbow | 46 | 20 |
| HeavyCrossbow | 55 | 20 |
| Cutlass | 24 | 20 |
| Dagger | 21 | 20 |
| Halberd | 42 | 20 |
| HammerPick | 26 | 20 |
| Katana | 33 | 20 |
| Kryss | 32 | 20 |
| Broadsword | 35 | 20 |
| Longsword | 55 | 20 |
| ThinLongsword | 27 | 20 |
| VikingSword | 55 | 20 |
| Cleaver | 15 | 20 |
| Axe | 40 | 20 |
| DoubleAxe | 52 | 20 |
| Pickaxe | 22 | 20 |
| Pitchfork | 19 | 20 |
| Scimitar | 36 | 20 |
| SkinningKnife | 14 | 20 |
| LargeBattleAxe | 33 | 20 |
| WarAxe | 29 | 20 |
| BoneHarvester | 35 | 20 |
| CrescentBlade | 37 | 20 |
| DoubleBladedStaff | 35 | 20 |
| Lance | 34 | 20 |
| Pike | 39 | 20 |
| Scythe | 39 | 20 |
| CompositeBow | 50 | 20 |
| RepeatingCrossbow | 57 | 20 |
| BlackStaff | 22 | 20 |
| Club | 16 | 20 |
| GnarledStaff | 16 | 20 |
| Mace | 28 | 20 |
| Maul | 21 | 20 |
| QuarterStaff | 19 | 20 |
| ShepherdsCrook | 20 | 20 |
| SmithHammer | 21 | 20 |
| ShortSpear | 23 | 20 |
| Spear | 31 | 20 |
| WarHammer | 25 | 20 |
| WarMace | 31 | 20 |
| Scepter | 39 | 20 |
| BladedStaff | 40 | 20 |
| MalleableAlloy | 50 | 500 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Tongs | 7 |
| IronIngot | 4 |
| Buckler | 25 |
| BronzeShield | 33 |
| MetalShield | 60 |
| MetalKiteShield | 62 |
| HeaterShield | 115 |
| WoodenKiteShield | 35 |
| WoodenShield | 15 |
| PlateArms | 94 |
| PlateChest | 121 |
| PlateGloves | 72 |
| PlateGorget | 52 |
| PlateLegs | 109 |
| FemalePlateChest | 113 |
| FemaleLeatherChest | 18 |
| FemaleStuddedChest | 25 |
| LeatherShorts | 14 |
| LeatherSkirt | 11 |
| LeatherBustierArms | 11 |
| StuddedBustierArms | 27 |
| Bascinet | 9 |
| CloseHelm | 9 |
| Helmet | 9 |
| NorseHelm | 9 |
| PlateHelm | 10 |
| ChainCoif | 6 |
| ChainChest | 71 |
| ChainLegs | 74 |
| RingmailArms | 42 |
| RingmailChest | 60 |
| RingmailGloves | 26 |
| RingmailLegs | 45 |
| BattleAxe | 13 |
| DoubleAxe | 26 |
| ExecutionersAxe | 15 |
| LargeBattleAxe | 16 |
| Pickaxe | 11 |
| TwoHandedAxe | 16 |
| WarAxe | 14 |
| Axe | 20 |
| Bardiche | 30 |
| Halberd | 21 |
| ButcherKnife | 7 |
| Cleaver | 7 |
| Dagger | 10 |
| SkinningKnife | 7 |
| Club | 8 |
| HammerPick | 13 |
| Mace | 14 |
| Maul | 10 |
| WarHammer | 12 |
| WarMace | 15 |
| HeavyCrossbow | 27 |
| Bow | 17 |
| Crossbow | 23 |
| CompositeBow | 25 |
| RepeatingCrossbow | 28 |
| Scepter | 20 |
| BladedStaff | 20 |
| Scythe | 19 |
| BoneHarvester | 17 |
| Scepter | 18 |
| BladedStaff | 16 |
| Pike | 19 |
| DoubleBladedStaff | 17 |
| Lance | 17 |
| CrescentBlade | 18 |
| Spear | 15 |
| Pitchfork | 9 |
| ShortSpear | 11 |
| BlackStaff | 11 |
| GnarledStaff | 8 |
| QuarterStaff | 9 |
| ShepherdsCrook | 10 |
| SmithHammer | 10 |
| Broadsword | 17 |
| Cutlass | 12 |
| Katana | 16 |
| Kryss | 16 |
| Longsword | 27 |
| Scimitar | 18 |
| ThinLongsword | 13 |
| VikingSword | 27 |


#### `SBBowyer`

Used by: Bowyer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| FletcherTools | 2 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| FletcherTools | 1 |


#### `SBButcher`

Used by: Butcher

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bacon | 7 | 20 |
| Ham | 26 | 20 |
| Sausage | 18 | 20 |
| RawChickenLeg | 6 | 20 |
| RawBird | 9 | 20 |
| RawLambLeg | 9 | 20 |
| RawRibs | 16 | 20 |
| ButcherKnife | 13 | 20 |
| Cleaver | 13 | 20 |
| SkinningKnife | 13 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| RawRibs | 8 |
| RawLambLeg | 4 |
| RawChickenLeg | 3 |
| RawBird | 4 |
| Bacon | 3 |
| Sausage | 9 |
| Ham | 13 |
| ButcherKnife | 7 |
| Cleaver | 7 |
| SkinningKnife | 7 |


#### `SBCarpenter`

Used by: Carpenter, StoneCrafter

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Nails | 3 | 20 |
| Axle | 2 | 20 |
| Board | 3 | 20 |
| DrawKnife | 10 | 20 |
| Froe | 10 | 20 |
| Scorp | 10 | 20 |
| Inshave | 10 | 20 |
| DovetailSaw | 12 | 20 |
| Saw | 15 | 20 |
| Hammer | 17 | 20 |
| MouldingPlane | 11 | 20 |
| SmoothingPlane | 10 | 20 |
| JointingPlane | 11 | 20 |
| Drums | 21 | 20 |
| Tambourine | 21 | 20 |
| LapHarp | 21 | 20 |
| Lute | 21 | 20 |
| SolventFlask | 50 | 500 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| WoodenBox | 7 |
| SmallCrate | 5 |
| MediumCrate | 6 |
| LargeCrate | 7 |
| WoodenChest | 15 |
| LargeTable | 10 |
| Nightstand | 7 |
| YewWoodTable | 10 |
| Throne | 24 |
| WoodenThrone | 6 |
| Stool | 6 |
| FootStool | 6 |
| FancyWoodenChairCushion | 12 |
| WoodenChairCushion | 10 |
| WoodenChair | 8 |
| BambooChair | 6 |
| WoodenBench | 6 |
| Saw | 9 |
| Scorp | 6 |
| SmoothingPlane | 6 |
| DrawKnife | 6 |
| Froe | 6 |
| Hammer | 14 |
| Inshave | 6 |
| JointingPlane | 6 |
| MouldingPlane | 6 |
| DovetailSaw | 7 |
| Board | 2 |
| Axle | 1 |
| Club | 13 |
| Lute | 10 |
| LapHarp | 10 |
| Tambourine | 10 |
| Drums | 10 |
| Log | 1 |


#### `SBCarpets`

Used by: (not wired to a vendor NPC in ServUO)

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Scissors | 6 |
| Dyes | 4 |
| DyeTub | 4 |
| BoltOfCloth | 60 |
| LightYarnUnraveled | 9 |
| LightYarn | 9 |
| DarkYarn | 9 |


#### `SBChainmailArmor`

Used by: Armorer, Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| ChainCoif | 17 | 20 |
| ChainChest | 143 | 20 |
| ChainLegs | 149 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| ChainCoif | 6 |
| ChainChest | 71 |
| ChainLegs | 74 |


#### `SBCobbler`

Used by: Cobbler

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| ThighBoots | 15 | 20 |
| Shoes | 8 | 20 |
| Boots | 10 | 20 |
| Sandals | 5 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Shoes | 4 |
| Boots | 5 |
| ThighBoots | 7 |
| Sandals | 2 |


#### `SBCook`

Used by: Cook

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BreadLoaf | 5 | 20 |
| BreadLoaf | 5 | 20 |
| ApplePie | 7 | 20 |
| Cake | 13 | 20 |
| Muffins | 3 | 20 |
| CheeseWheel | 21 | 10 |
| CookedBird | 17 | 20 |
| LambLeg | 8 | 20 |
| ChickenLeg | 5 | 20 |
| WoodenBowlOfCarrots | 3 | 20 |
| WoodenBowlOfCorn | 3 | 20 |
| WoodenBowlOfLettuce | 3 | 20 |
| WoodenBowlOfPeas | 3 | 20 |
| EmptyPewterBowl | 2 | 20 |
| PewterBowlOfCorn | 3 | 20 |
| PewterBowlOfLettuce | 3 | 20 |
| PewterBowlOfPeas | 3 | 20 |
| PewterBowlOfPotatos | 3 | 20 |
| WoodenBowlOfStew | 3 | 20 |
| WoodenBowlOfTomatoSoup | 3 | 20 |
| RoastPig | 106 | 20 |
| SackFlour | 3 | 20 |
| JarHoney | 3 | 20 |
| RollingPin | 2 | 20 |
| FlourSifter | 2 | 20 |
| Skillet | 3 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| CheeseWheel | 12 |
| CookedBird | 8 |
| RoastPig | 53 |
| Cake | 5 |
| JarHoney | 1 |
| SackFlour | 1 |
| BreadLoaf | 2 |
| ChickenLeg | 3 |
| LambLeg | 4 |
| Skillet | 1 |
| FlourSifter | 1 |
| RollingPin | 1 |
| Muffins | 1 |
| ApplePie | 3 |
| WoodenBowlOfCarrots | 1 |
| WoodenBowlOfCorn | 1 |
| WoodenBowlOfLettuce | 1 |
| WoodenBowlOfPeas | 1 |
| EmptyPewterBowl | 1 |
| PewterBowlOfCorn | 1 |
| PewterBowlOfLettuce | 1 |
| PewterBowlOfPeas | 1 |
| PewterBowlOfPotatos | 1 |
| WoodenBowlOfStew | 1 |
| WoodenBowlOfTomatoSoup | 1 |


#### `SBFarmer`

Used by: Farmer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| FreshGinger | 505 | 10 |
| Cabbage | 5 | 20 |
| Cantaloupe | 6 | 20 |
| Carrot | 3 | 20 |
| HoneydewMelon | 7 | 20 |
| Squash | 3 | 20 |
| Lettuce | 5 | 20 |
| Onion | 3 | 20 |
| Pumpkin | 11 | 20 |
| GreenGourd | 3 | 20 |
| YellowGourd | 3 | 20 |
| Turnip | 6 | 20 |
| Watermelon | 7 | 20 |
| EarOfCorn | 3 | 20 |
| Eggs | 3 | 20 |
| Peach | 3 | 20 |
| Pear | 3 | 20 |
| Lemon | 3 | 20 |
| Lime | 3 | 20 |
| Grapes | 3 | 20 |
| Apple | 3 | 20 |
| SheafOfHay | 2 | 20 |
| Hoe | 5 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Pitcher | 5 |
| Eggs | 1 |
| Apple | 1 |
| Grapes | 1 |
| Watermelon | 3 |
| YellowGourd | 1 |
| GreenGourd | 1 |
| Pumpkin | 5 |
| Onion | 1 |
| Lettuce | 2 |
| Squash | 1 |
| Carrot | 1 |
| HoneydewMelon | 3 |
| Cantaloupe | 3 |
| Cabbage | 2 |
| Lemon | 1 |
| Lime | 1 |
| Peach | 1 |
| Pear | 1 |
| SheafOfHay | 1 |


#### `SBFisherman`

Used by: Fisherman

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| RawFishSteak | 3 | 20 |
| SmallFish | 3 | 20 |
| SmallFish | 3 | 20 |
| Fish | 6 | 80 |
| Fish | 6 | 80 |
| Fish | 6 | 80 |
| Fish | 6 | 80 |
| FishingPole | 15 | 20 |
| AquariumFishNet | 250 | 20 |
| AquariumFood | 62 | 20 |
| FishBowl | 6312 | 20 |
| VacationWafer | 67 | 20 |
| AquariumNorthDeed | 250002 | 20 |
| AquariumEastDeed | 250002 | 20 |
| NewAquariumBook | 15 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| RawFishSteak | 1 |
| Fish | 1 |
| SmallFish | 1 |
| FishingPole | 7 |


#### `SBFortuneTeller`

Used by: (not wired to a vendor NPC in ServUO)

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bandage | 5 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bandage | 1 |


#### `SBFurtrader`

Used by: Furtrader

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Hides | 3 | 40 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Hides | 2 |


#### `SBGardener`

Used by: Gardener

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Hoe | 17 | 20 |
| GardeningContract | 10156 | 500 |
| Engines.Plants.PlantBowl | 2 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Hoe | 8 |
| Pitcher | 5 |
| Engines.Plants.PlantBowl | 1 |


#### `SBGlassblower`

Used by: Glassblower

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| RefreshPotion | 15 | 10 |
| AgilityPotion | 15 | 10 |
| NightSightPotion | 15 | 10 |
| LesserHealPotion | 15 | 10 |
| StrengthPotion | 15 | 10 |
| LesserPoisonPotion | 15 | 10 |
| LesserCurePotion | 15 | 10 |
| LesserExplosionPotion | 21 | 10 |
| MortarPestle | 8 | 10 |
| BlackPearl | 5 | 20 |
| Bloodmoss | 5 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| MandrakeRoot | 3 | 20 |
| Nightshade | 3 | 20 |
| SpidersSilk | 3 | 20 |
| SulfurousAsh | 3 | 20 |
| Bottle | 5 | 100 |
| HeatingStand | 2 | 100 |
| GlassblowingBook | 10637 | 30 |
| SandMiningBook | 10637 | 30 |
| Blowpipe | 21 | 100 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BlackPearl | 3 |
| Bloodmoss | 3 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| Bottle | 3 |
| MortarPestle | 4 |
| NightSightPotion | 7 |
| AgilityPotion | 7 |
| StrengthPotion | 7 |
| RefreshPotion | 7 |
| LesserCurePotion | 7 |
| LesserHealPotion | 7 |
| LesserPoisonPotion | 7 |
| LesserExplosionPotion | 10 |
| GlassblowingBook | 5000 |
| SandMiningBook | 5000 |
| Blowpipe | 10 |


#### `SBHairStylist`

Used by: HairStylist

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| SpecialBeardDye | 500000 | 20 |
| SpecialHairDye | 500000 | 20 |
| HairDye | 60 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| HairDye | 30 |
| SpecialBeardDye | 250000 |
| SpecialHairDye | 250000 |


#### `SBHealer`

Used by: (not wired to a vendor NPC in ServUO)

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bandage | 5 | 20 |
| LesserHealPotion | 15 | 20 |
| Ginseng | 3 | 20 |
| Garlic | 3 | 20 |
| RefreshPotion | 15 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bandage | 1 |
| LesserHealPotion | 7 |
| RefreshPotion | 7 |
| Garlic | 2 |
| Ginseng | 2 |


#### `SBHelmetArmor`

Used by: Armorer, Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| PlateHelm | 21 | 20 |
| CloseHelm | 18 | 20 |
| CloseHelm | 18 | 20 |
| Helmet | 31 | 20 |
| Helmet | 18 | 20 |
| NorseHelm | 18 | 20 |
| NorseHelm | 18 | 20 |
| Bascinet | 18 | 20 |
| PlateHelm | 21 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bascinet | 9 |
| CloseHelm | 9 |
| Helmet | 9 |
| NorseHelm | 9 |
| PlateHelm | 10 |


#### `SBHerbalist`

Used by: Herbalist

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Ginseng | 3 | 20 |
| Garlic | 3 | 20 |
| MandrakeRoot | 3 | 20 |
| Nightshade | 3 | 20 |
| Bloodmoss | 5 | 20 |
| MortarPestle | 8 | 20 |
| Bottle | 5 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bloodmoss | 3 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| Bottle | 3 |
| MortarPestle | 4 |


#### `SBHolyMage`

Used by: HolyMage

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Spellbook | 18 | 10 |
| ScribesPen | 8 | 10 |
| BlankScroll | 5 | 20 |
| MagicWizardsHat | 11 | 10 |
| RecallRune | 15 | 10 |
| RefreshPotion | 15 | 20 |
| AgilityPotion | 15 | 20 |
| NightSightPotion | 15 | 20 |
| LesserHealPotion | 15 | 20 |
| StrengthPotion | 15 | 20 |
| LesserCurePotion | 15 | 20 |
| BlackPearl | 5 | 20 |
| Bloodmoss | 5 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| MandrakeRoot | 3 | 20 |
| Nightshade | 3 | 20 |
| SpidersSilk | 3 | 20 |
| SulfurousAsh | 3 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BlackPearl | 3 |
| Bloodmoss | 3 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| RecallRune | 8 |
| Spellbook | 9 |
| BlankScroll | 3 |
| NightSightPotion | 7 |
| AgilityPotion | 7 |
| StrengthPotion | 7 |
| RefreshPotion | 7 |
| LesserCurePotion | 7 |
| LesserHealPotion | 7 |


#### `SBHouseDeed`

Used by: Architect

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| StonePlasterHouseDeed | 43800 | 20 |
| FieldStoneHouseDeed | 43800 | 20 |
| SmallBrickHouseDeed | 43800 | 20 |
| WoodHouseDeed | 43800 | 20 |
| WoodPlasterHouseDeed | 43800 | 20 |
| ThatchedRoofCottageDeed | 43800 | 20 |
| BrickHouseDeed | 144500 | 20 |
| TwoStoryWoodPlasterHouseDeed | 192400 | 20 |
| TowerDeed | 433200 | 20 |
| KeepDeed | 665200 | 20 |
| CastleDeed | 1022800 | 20 |
| LargePatioDeed | 152800 | 20 |
| LargeMarbleDeed | 192000 | 20 |
| SmallTowerDeed | 88500 | 20 |
| LogCabinDeed | 97800 | 20 |
| SandstonePatioDeed | 90900 | 20 |
| VillaDeed | 136500 | 20 |
| StoneWorkshopDeed | 60600 | 20 |
| MarbleWorkshopDeed | 63000 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| StonePlasterHouseDeed | 43800 |
| FieldStoneHouseDeed | 43800 |
| SmallBrickHouseDeed | 43800 |
| WoodHouseDeed | 43800 |
| WoodPlasterHouseDeed | 43800 |
| ThatchedRoofCottageDeed | 43800 |
| BrickHouseDeed | 144500 |
| TwoStoryWoodPlasterHouseDeed | 192400 |
| TowerDeed | 433200 |
| KeepDeed | 665200 |
| CastleDeed | 1022800 |
| LargePatioDeed | 152800 |
| LargeMarbleDeed | 192800 |
| SmallTowerDeed | 88500 |
| LogCabinDeed | 97800 |
| SandstonePatioDeed | 90900 |
| VillaDeed | 136500 |
| StoneWorkshopDeed | 60600 |
| MarbleWorkshopDeed | 60300 |
| SmallBrickHouseDeed | 43800 |


#### `SBInnKeeper`

Used by: InnKeeper

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BreadLoaf | 6 | 10 |
| CheeseWheel | 21 | 10 |
| CookedBird | 17 | 20 |
| LambLeg | 8 | 20 |
| ChickenLeg | 5 | 20 |
| Ribs | 7 | 20 |
| WoodenBowlOfCarrots | 3 | 20 |
| WoodenBowlOfCorn | 3 | 20 |
| WoodenBowlOfLettuce | 3 | 20 |
| WoodenBowlOfPeas | 3 | 20 |
| EmptyPewterBowl | 2 | 20 |
| PewterBowlOfCorn | 3 | 20 |
| PewterBowlOfLettuce | 3 | 20 |
| PewterBowlOfPeas | 3 | 20 |
| PewterBowlOfPotatos | 3 | 20 |
| WoodenBowlOfStew | 3 | 20 |
| WoodenBowlOfTomatoSoup | 3 | 20 |
| ApplePie | 7 | 20 |
| Peach | 3 | 20 |
| Pear | 3 | 20 |
| Grapes | 3 | 20 |
| Apple | 3 | 20 |
| Banana | 2 | 20 |
| Torch | 7 | 20 |
| Candle | 6 | 20 |
| Beeswax | 1 | 20 |
| Backpack | 15 | 20 |
| Chessboard | 2 | 20 |
| CheckerBoard | 2 | 20 |
| Backgammon | 2 | 20 |
| Dices | 2 | 20 |
| ContractOfEmployment | 1252 | 20 |
| BarkeepContract | 1252 | 20 |
| VendorRentalContract | 1252 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BeverageBottle | 3 |
| Jug | 6 |
| Pitcher | 5 |
| GlassMug | 1 |
| BreadLoaf | 3 |
| CheeseWheel | 12 |
| Ribs | 6 |
| Peach | 1 |
| Pear | 1 |
| Grapes | 1 |
| Apple | 1 |
| Banana | 1 |
| Torch | 3 |
| Candle | 3 |
| Chessboard | 1 |
| CheckerBoard | 1 |
| Backgammon | 1 |
| Dices | 1 |
| ContractOfEmployment | 626 |
| Beeswax | 1 |
| WoodenBowlOfCarrots | 1 |
| WoodenBowlOfCorn | 1 |
| WoodenBowlOfLettuce | 1 |
| WoodenBowlOfPeas | 1 |
| EmptyPewterBowl | 1 |
| PewterBowlOfCorn | 1 |
| PewterBowlOfLettuce | 1 |
| PewterBowlOfPeas | 1 |
| PewterBowlOfPotatos | 1 |
| WoodenBowlOfStew | 1 |
| WoodenBowlOfTomatoSoup | 1 |


#### `SBJewel`

Used by: Jeweler

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| GoldRing | 27 | 20 |
| Necklace | 26 | 20 |
| GoldNecklace | 27 | 20 |
| GoldBeadNecklace | 27 | 20 |
| Beads | 27 | 20 |
| GoldBracelet | 27 | 20 |
| GoldEarrings | 27 | 20 |
| BroadcastCrystal | 68 | 20 |
| BroadcastCrystal | 131 | 20 |
| BroadcastCrystal | 256 | 20 |
| ReceiverCrystal | 6 | 20 |
| StarSapphire | 125 | 20 |
| Emerald | 100 | 20 |
| Sapphire | 100 | 20 |
| Ruby | 75 | 20 |
| Citrine | 50 | 20 |
| Amethyst | 100 | 20 |
| Tourmaline | 75 | 20 |
| Amber | 50 | 20 |
| Diamond | 200 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Amber | 25 |
| Amethyst | 50 |
| Citrine | 25 |
| Diamond | 100 |
| Emerald | 50 |
| Ruby | 37 |
| Sapphire | 50 |
| StarSapphire | 62 |
| Tourmaline | 47 |
| GoldRing | 13 |
| SilverRing | 10 |
| Necklace | 13 |
| GoldNecklace | 13 |
| GoldBeadNecklace | 13 |
| SilverNecklace | 10 |
| SilverBeadNecklace | 10 |
| Beads | 13 |
| GoldBracelet | 13 |
| SilverBracelet | 10 |
| GoldEarrings | 13 |
| SilverEarrings | 10 |


#### `SBKeeperOfBushido`

Used by: (not wired to a vendor NPC in ServUO)

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BookOfBushido | 500 | 20 |


#### `SBKeeperOfChivalry`

Used by: KeeperOfChivalry

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BookOfChivalry | 140 | 20 |


#### `SBKeeperOfNinjitsu`

Used by: (not wired to a vendor NPC in ServUO)

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BookOfNinjitsu | 500 | 20 |


#### `SBKnifeWeapon`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| ButcherKnife | 14 | 20 |
| Dagger | 21 | 20 |
| Cleaver | 15 | 20 |
| SkinningKnife | 14 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| ButcherKnife | 7 |
| Cleaver | 7 |
| Dagger | 10 |
| SkinningKnife | 7 |


#### `SBLeatherArmor`

Used by: Armorer, IronWorker, LeatherWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| LeatherArms | 80 | 20 |
| LeatherChest | 101 | 20 |
| LeatherGloves | 60 | 20 |
| LeatherGorget | 74 | 20 |
| LeatherLegs | 80 | 20 |
| LeatherCap | 10 | 20 |
| FemaleLeatherChest | 116 | 20 |
| LeatherBustierArms | 97 | 20 |
| LeatherShorts | 86 | 20 |
| LeatherSkirt | 87 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| LeatherArms | 40 |
| LeatherChest | 52 |
| LeatherGloves | 30 |
| LeatherGorget | 37 |
| LeatherLegs | 40 |
| LeatherCap | 5 |
| FemaleLeatherChest | 18 |
| FemaleStuddedChest | 25 |
| LeatherShorts | 14 |
| LeatherSkirt | 11 |
| LeatherBustierArms | 11 |
| StuddedBustierArms | 27 |


#### `SBLeatherWorker`

Used by: LeatherWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Hides | 4 | 999 |
| ThighBoots | 56 | 10 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Hides | 2 |
| ThighBoots | 28 |


#### `SBMaceWeapon`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| HammerPick | 26 | 20 |
| Club | 16 | 20 |
| Mace | 28 | 20 |
| Maul | 21 | 20 |
| WarHammer | 25 | 20 |
| WarMace | 31 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Club | 8 |
| HammerPick | 13 |
| Mace | 14 |
| Maul | 10 |
| WarHammer | 12 |
| WarMace | 15 |


#### `SBMage`

Used by: Mage

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Spellbook | 18 | 10 |
| NecromancerSpellbook | 115 | 10 |
| ScribesPen | 8 | 10 |
| BlankScroll | 5 | 20 |
| MagicWizardsHat | 11 | 10 |
| RecallRune | 15 | 10 |
| RefreshPotion | 15 | 10 |
| AgilityPotion | 15 | 10 |
| NightSightPotion | 15 | 10 |
| LesserHealPotion | 15 | 10 |
| StrengthPotion | 15 | 10 |
| LesserPoisonPotion | 15 | 10 |
| LesserCurePotion | 15 | 10 |
| LesserExplosionPotion | 21 | 10 |
| BlackPearl | 5 | 20 |
| Bloodmoss | 5 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| MandrakeRoot | 3 | 20 |
| Nightshade | 3 | 20 |
| SpidersSilk | 3 | 20 |
| SulfurousAsh | 3 | 20 |
| BatWing | 3 | 999 |
| DaemonBlood | 6 | 999 |
| PigIron | 5 | 999 |
| NoxCrystal | 6 | 999 |
| GraveDust | 3 | 999 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| WizardsHat | 15 |
| BlackPearl | 3 |
| Bloodmoss | 4 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| BatWing | 1 |
| DaemonBlood | 3 |
| PigIron | 2 |
| NoxCrystal | 3 |
| GraveDust | 1 |
| RecallRune | 13 |
| Spellbook | 25 |
| ExorcismScroll | 3 |
| AnimateDeadScroll | 8 |
| BloodOathScroll | 8 |
| CorpseSkinScroll | 8 |
| CurseWeaponScroll | 8 |
| EvilOmenScroll | 8 |
| PainSpikeScroll | 8 |
| SummonFamiliarScroll | 8 |
| HorrificBeastScroll | 8 |
| MindRotScroll | 10 |
| PoisonStrikeScroll | 10 |
| WraithFormScroll | 15 |
| LichFormScroll | 16 |
| StrangleScroll | 16 |
| WitherScroll | 16 |
| VampiricEmbraceScroll | 20 |
| VengefulSpiritScroll | 20 |


#### `SBMapmaker`

Used by: Mapmaker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BlankMap | 5 | 40 |
| MapmakersPen | 8 | 20 |
| BlankScroll | 12 | 40 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BlankScroll | 6 |
| MapmakersPen | 4 |
| BlankMap | 2 |
| CityMap | 3 |
| LocalMap | 3 |
| WorldMap | 3 |
| PresetMapEntry | 3 |


#### `SBMetalShields`

Used by: Armorer, Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BronzeShield | 66 | 20 |
| Buckler | 50 | 20 |
| MetalKiteShield | 123 | 20 |
| HeaterShield | 231 | 20 |
| WoodenKiteShield | 70 | 20 |
| MetalShield | 121 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Buckler | 25 |
| BronzeShield | 33 |
| MetalShield | 60 |
| MetalKiteShield | 62 |
| HeaterShield | 115 |
| WoodenKiteShield | 35 |


#### `SBMiller`

Used by: Miller

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| SackFlour | 3 | 20 |
| SheafOfHay | 2 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| SackFlour | 1 |
| SheafOfHay | 1 |


#### `SBMiner`

Used by: Miner

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bag | 6 | 20 |
| Candle | 6 | 10 |
| Torch | 8 | 10 |
| Lantern | 2 | 10 |
| OilFlask | 8 | 10 |
| Pickaxe | 25 | 10 |
| Shovel | 12 | 10 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Pickaxe | 12 |
| Shovel | 6 |
| Lantern | 1 |
| OilFlask | 4 |
| Torch | 3 |
| Bag | 3 |
| Candle | 3 |


#### `SBMonk`

Used by: Monk

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| MonkRobe | 136 | 20 |


#### `SBMystic`

Used by: Mystic

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| PurgeMagicScroll | 18 | 10 |
| EnchantScroll | 23 | 10 |
| SleepScroll | 28 | 10 |
| EagleStrikeScroll | 33 | 10 |
| AnimatedWeaponScroll | 38 | 10 |
| StoneFormScroll | 43 | 10 |
| MysticBook | 18 | 10 |
| ScribesPen | 8 | 10 |
| BlankScroll | 5 | 20 |
| RecallRune | 15 | 10 |
| RefreshPotion | 15 | 10 |
| AgilityPotion | 15 | 10 |
| NightSightPotion | 15 | 10 |
| LesserHealPotion | 15 | 10 |
| StrengthPotion | 15 | 10 |
| LesserPoisonPotion | 15 | 10 |
| LesserCurePotion | 15 | 10 |
| LesserExplosionPotion | 21 | 10 |
| BlackPearl | 5 | 20 |
| Bloodmoss | 5 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| MandrakeRoot | 3 | 20 |
| Nightshade | 3 | 20 |
| SulfurousAsh | 3 | 20 |
| SpidersSilk | 3 | 20 |
| Bone | 3 | 20 |
| FertileDirt | 3 | 20 |
| NetherBoltScroll | 8 | 20 |
| HealingStoneScroll | 13 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| PurgeMagicScroll | 9 |
| EnchantScroll | 11 |
| SleepScroll | 14 |
| EagleStrikeScroll | 16 |
| AnimatedWeaponScroll | 19 |
| StoneFormScroll | 21 |
| MysticBook | 9 |
| RecallRune | 13 |
| BlackPearl | 3 |
| Bloodmoss | 4 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| NetherBoltScroll | 4 |
| HealingStoneScroll | 6 |


#### `SBNecromancer`

Used by: Necromancer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BlackPearl | 5 | 20 |
| Bloodmoss | 7 | 20 |
| MandrakeRoot | 3 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| Nightshade | 4 | 20 |
| SpidersSilk | 3 | 20 |
| SulfurousAsh | 4 | 20 |
| BatWing | 4 | 20 |
| GraveDust | 4 | 20 |
| DaemonBlood | 4 | 20 |
| NoxCrystal | 4 | 20 |
| PigIron | 4 | 20 |
| NecromancerSpellbook | 150 | 10 |
| MagicWizardsHat | 11 | 10 |
| ScribesPen | 8 | 10 |
| BlankScroll | 5 | 20 |
| RecallRune | 25 | 10 |
| Spellbook | 50 | 10 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| WizardsHat | 15 |
| Runebook | 1250 |
| BlackPearl | 3 |
| Bloodmoss | 4 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| RecallRune | 13 |
| Spellbook | 25 |
| PigIron | 2 |
| DaemonBlood | 3 |
| NoxCrystal | 3 |
| BatWing | 1 |
| GraveDust | 1 |


#### `SBPlateArmor`

Used by: Armorer, Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| PlateGorget | 104 | 20 |
| PlateChest | 243 | 20 |
| PlateLegs | 218 | 20 |
| PlateArms | 188 | 20 |
| PlateGloves | 155 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| PlateArms | 94 |
| PlateChest | 121 |
| PlateGloves | 72 |
| PlateGorget | 52 |
| PlateLegs | 109 |
| FemalePlateChest | 113 |


#### `SBPlayerBarkeeper`

Used by: PlayerBarkeeper

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Chessboard | 2 | 20 |
| CheckerBoard | 2 | 20 |
| Backgammon | 2 | 20 |
| Dices | 2 | 20 |


#### `SBPoleArmWeapon`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bardiche | 60 | 20 |
| Halberd | 42 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bardiche | 30 |
| Halberd | 21 |


#### `SBProvisioner`

Used by: GypsyMaiden, Provisioner

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Engines.Plants.PlantBowl | 2 | 20 |
| Arrow | 2 | 20 |
| Bolt | 5 | 20 |
| Backpack | 15 | 20 |
| Pouch | 6 | 20 |
| Bag | 6 | 20 |
| Candle | 6 | 20 |
| Torch | 8 | 20 |
| Lantern | 2 | 20 |
| OilFlask | 10 | 20 |
| Lockpick | 12 | 20 |
| FloppyHat | 7 | 20 |
| WideBrimHat | 8 | 20 |
| Cap | 10 | 20 |
| TallStrawHat | 8 | 20 |
| StrawHat | 7 | 20 |
| WizardsHat | 11 | 20 |
| LeatherCap | 10 | 20 |
| FeatheredHat | 10 | 20 |
| TricorneHat | 8 | 20 |
| Bandana | 6 | 20 |
| SkullCap | 7 | 20 |
| BreadLoaf | 6 | 10 |
| LambLeg | 8 | 20 |
| ChickenLeg | 5 | 20 |
| CookedBird | 17 | 20 |
| Pear | 3 | 20 |
| Apple | 3 | 20 |
| Beeswax | 1 | 20 |
| Garlic | 3 | 20 |
| Ginseng | 3 | 20 |
| Bottle | 5 | 20 |
| RedBook | 15 | 20 |
| BlueBook | 15 | 20 |
| TanBook | 15 | 20 |
| WoodenBox | 14 | 20 |
| Key | 2 | 20 |
| Bedroll | 5 | 20 |
| Kindling | 2 | 20 |
| Multis.SmallBoatDeed | 10177 | 20 |
| HairDye | 60 | 20 |
| Chessboard | 2 | 20 |
| CheckerBoard | 2 | 20 |
| Backgammon | 2 | 20 |
| Engines.Mahjong.MahjongGame | 6 | 20 |
| Dices | 2 | 20 |
| SmallBagBall | 3 | 20 |
| LargeBagBall | 3 | 20 |
| GuildDeed | 12450 | 20 |
| SalvageBag | 1255 | 20 |
| SkinTingeingTincture | 1255 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Arrow | 1 |
| Bolt | 2 |
| Backpack | 7 |
| Pouch | 3 |
| Bag | 3 |
| Candle | 3 |
| Torch | 4 |
| Lantern | 1 |
| Lockpick | 6 |
| FloppyHat | 3 |
| WideBrimHat | 4 |
| Cap | 5 |
| TallStrawHat | 4 |
| StrawHat | 3 |
| WizardsHat | 5 |
| LeatherCap | 5 |
| FeatheredHat | 5 |
| TricorneHat | 4 |
| Bandana | 3 |
| SkullCap | 3 |
| Bottle | 3 |
| RedBook | 7 |
| BlueBook | 7 |
| TanBook | 7 |
| WoodenBox | 7 |
| Kindling | 1 |
| HairDye | 30 |
| Chessboard | 1 |
| CheckerBoard | 1 |
| Backgammon | 1 |
| Dices | 1 |
| Beeswax | 1 |
| Amber | 25 |
| Amethyst | 50 |
| Citrine | 25 |
| Diamond | 100 |
| Emerald | 50 |
| Ruby | 37 |
| Sapphire | 50 |
| StarSapphire | 62 |
| Tourmaline | 47 |
| GoldRing | 13 |
| SilverRing | 10 |
| Necklace | 13 |
| GoldNecklace | 13 |
| GoldBeadNecklace | 13 |
| SilverNecklace | 10 |
| SilverBeadNecklace | 10 |
| Beads | 13 |
| GoldBracelet | 13 |
| SilverBracelet | 10 |
| GoldEarrings | 13 |
| SilverEarrings | 10 |
| GuildDeed | 6225 |


#### `SBRancher`

Used by: Rancher


#### `SBRangedWeapon`

Used by: Blacksmith, Bowyer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Crossbow | 55 | 20 |
| HeavyCrossbow | 55 | 20 |
| RepeatingCrossbow | 46 | 20 |
| CompositeBow | 45 | 20 |
| Bow | 40 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bolt | 1 |
| Arrow | 1 |
| Shaft | 1 |
| Feather | 1 |
| HeavyCrossbow | 27 |
| Bow | 17 |
| Crossbow | 25 |
| CompositeBow | 23 |
| RepeatingCrossbow | 22 |


#### `SBRanger`

Used by: Ranger

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bandage | 5 | 20 |


#### `SBRealEstateBroker`

Used by: RealEstateBroker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BlankScroll | 5 | 20 |
| ScribesPen | 8 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| ScribesPen | 4 |
| BlankScroll | 2 |


#### `SBRingmailArmor`

Used by: Armorer, Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| RingmailChest | 121 | 20 |
| RingmailLegs | 90 | 20 |
| RingmailArms | 85 | 20 |
| RingmailGloves | 93 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| RingmailArms | 42 |
| RingmailChest | 60 |
| RingmailGloves | 26 |
| RingmailLegs | 45 |


#### `SBSAArmor`

Used by: Blacksmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| FemaleGargishPlateArms | 363 | 20 |
| GargishPlateArms | 328 | 20 |
| FemaleGargishPlateChest | 481 | 20 |
| GargishPlateChest | 462 | 20 |
| FemaleGargishPlateKilt | 338 | 20 |
| GargishPlateKilt | 370 | 20 |
| FemaleGargishPlateLegs | 372 | 20 |
| GargishPlateLegs | 355 | 20 |
| FemaleGargishStoneArms | 116 | 20 |
| GargishStoneArms | 121 | 20 |
| FemaleGargishStoneChest | 135 | 20 |
| GargishStoneChest | 142 | 20 |
| FemaleGargishStoneKilt | 135 | 20 |
| GargishStoneKilt | 132 | 20 |
| FemaleGargishStoneLegs | 116 | 20 |
| GargishStoneLegs | 113 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| FemaleGargishPlateArms | 181 |
| GargishPlateArms | 164 |
| FemaleGargishPlateChest | 240 |
| GargishPlateChest | 231 |
| FemaleGargishPlateKilt | 169 |
| GargishPlateKilt | 185 |
| FemaleGargishPlateLegs | 186 |
| GargishPlateLegs | 177 |
| FemaleGargishStoneArms | 58 |
| GargishStoneArms | 60 |
| FemaleGargishStoneChest | 67 |
| GargishStoneChest | 71 |
| FemaleGargishStoneKilt | 67 |
| GargishStoneKilt | 66 |
| FemaleGargishStoneLegs | 58 |
| GargishStoneLegs | 56 |


#### `SBSABlacksmith`

Used by: Blacksmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| IronIngot | 9 | 16 |
| Tongs | 13 | 14 |
| GemMiningBook | 10625 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| IronIngot | 4 |
| Tongs | 7 |


#### `SBSATailor`

Used by: Tailor

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Cotton | 102 | 20 |
| Wool | 62 | 20 |
| Flax | 102 | 20 |
| SpoolOfThread | 18 | 20 |
| SewingKit | 3 | 20 |
| Scissors | 11 | 20 |
| DyeTub | 8 | 20 |
| Dyes | 8 | 20 |
| GargishRobe | 32 | 20 |
| GargishFancyRobe | 46 | 20 |
| FemaleGargishClothArmsArmor | 62 | 20 |
| GargishClothArmsArmor | 61 | 20 |
| FemaleGargishClothChestArmor | 83 | 20 |
| GargishClothChestArmor | 78 | 20 |
| FemaleGargishClothLegsArmor | 71 | 20 |
| GargishClothLegsArmor | 66 | 20 |
| FemaleGargishClothKiltArmor | 57 | 20 |
| GargishClothKiltArmor | 56 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Cotton | 51 |
| Wool | 31 |
| Flax | 51 |
| SpoolOfThread | 9 |
| SewingKit | 1 |
| Scissors | 6 |
| DyeTub | 4 |
| Dyes | 4 |
| GargishRobe | 16 |
| GargishFancyRobe | 23 |
| FemaleGargishClothArmsArmor | 30 |
| GargishClothArmsArmor | 30 |
| FemaleGargishClothChestArmor | 40 |
| GargishClothChestArmor | 42 |
| FemaleGargishClothLegsArmor | 30 |
| GargishClothLegsArmor | 32 |
| FemaleGargishClothKiltArmor | 30 |
| GargishClothKiltArmor | 32 |


#### `SBSATanner`

Used by: Tanner

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bag | 6 | 20 |
| Pouch | 6 | 20 |
| Backpack | 15 | 20 |
| Leather | 6 | 20 |
| GargishDagger | 20 | 20 |
| TaxidermyKit | 100000 | 20 |
| FemaleGargishLeatherArms | 73 | 20 |
| GargishLeatherArms | 80 | 20 |
| FemaleGargishLeatherChest | 77 | 20 |
| GargishLeatherChest | 77 | 20 |
| FemaleGargishLeatherKilt | 92 | 20 |
| GargishLeatherKilt | 85 | 20 |
| GargishLeatherLegs | 67 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bag | 3 |
| Pouch | 3 |
| Backpack | 7 |
| Leather | 5 |
| GargishDagger | 10 |
| FemaleGargishLeatherArms | 42 |
| GargishLeatherArms | 41 |
| FemaleGargishLeatherChest | 44 |
| GargishLeatherChest | 38 |
| FemaleGargishLeatherKilt | 46 |
| GargishLeatherKilt | 48 |
| GargishLeatherLegs | 34 |


#### `SBSAWeapons`

Used by: Blacksmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| DualShortAxes | 83 | 20 |
| BloodBlade | 47 | 20 |
| Boomerang | 28 | 20 |
| Cyclone | 47 | 20 |
| GargishDagger | 20 | 20 |
| DiscMace | 62 | 20 |
| GlassStaff | 11 | 20 |
| SerpentStoneStaff | 30 | 20 |
| Shortblade | 57 | 20 |
| SoulGlaive | 68 | 20 |
| GargishTalwar | 63 | 20 |
| GargishCleaver | 8 | 20 |
| GargishBattleAxe | 22 | 20 |
| GargishAxe | 23 | 20 |
| GargishBardiche | 47 | 20 |
| GargishButcherKnife | 8 | 20 |
| GargishGnarledStaff | 11 | 20 |
| GargishKatana | 17 | 20 |
| GargishKryss | 15 | 20 |
| GargishWarFork | 15 | 20 |
| GargishWarHammer | 16 | 20 |
| GargishMaul | 13 | 20 |
| GargishScythe | 31 | 20 |
| GargishBoneHarvester | 30 | 20 |
| GargishPike | 31 | 20 |
| GargishLance | 40 | 20 |
| GargishTessen | 23 | 20 |
| GargishTekagi | 18 | 20 |
| GargishDaisho | 23 | 20 |
| GlassSword | 28 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| DualShortAxes | 41 |
| BloodBlade | 23 |
| Boomerang | 14 |
| Cyclone | 23 |
| GargishDagger | 10 |
| DiscMace | 31 |
| GlassStaff | 5 |
| SerpentStoneStaff | 15 |
| Shortblade | 28 |
| SoulGlaive | 34 |
| GargishTalwar | 31 |
| GargishCleaver | 4 |
| GargishBattleAxe | 11 |
| GargishAxe | 11 |
| GargishBardiche | 23 |
| GargishButcherKnife | 4 |
| GargishGnarledStaff | 5 |
| GargishKatana | 8 |
| GargishKryss | 7 |
| GargishWarFork | 7 |
| GargishWarHammer | 8 |
| GargishMaul | 6 |
| GargishScythe | 15 |
| GargishBoneHarvester | 15 |
| GargishPike | 15 |
| GargishLance | 20 |
| GargishTessen | 11 |
| GargishTekagi | 9 |
| GargishDaisho | 11 |
| GlassSword | 14 |


#### `SBScribe`

Used by: Scribe

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| ScribesPen | 8 | 20 |
| BlankScroll | 5 | 999 |
| BrownBook | 15 | 10 |
| TanBook | 15 | 10 |
| BlueBook | 15 | 10 |
| BookOfNinjitsu | 335 | 20 |
| BookOfBushido | 280 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| ScribesPen | 4 |
| BrownBook | 7 |
| TanBook | 7 |
| BlueBook | 7 |
| BlankScroll | 3 |


#### `SBSEArmor`

Used by: Armorer, Blacksmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| PlateHatsuburi | 76 | 20 |
| HeavyPlateJingasa | 76 | 20 |
| DecorativePlateKabuto | 95 | 20 |
| PlateDo | 310 | 20 |
| PlateHiroSode | 222 | 20 |
| PlateSuneate | 224 | 20 |
| PlateHaidate | 235 | 20 |
| ChainHatsuburi | 76 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| PlateHatsuburi | 38 |
| HeavyPlateJingasa | 38 |
| DecorativePlateKabuto | 47 |
| PlateDo | 155 |
| PlateHiroSode | 111 |
| PlateSuneate | 112 |
| PlateHaidate | 117 |
| ChainHatsuburi | 38 |


#### `SBSEBowyer`

Used by: Bowyer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Yumi | 53 | 20 |
| Fukiya | 20 | 20 |
| Nunchaku | 35 | 20 |
| FukiyaDarts | 3 | 20 |
| Bokuto | 21 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Yumi | 26 |
| Fukiya | 10 |
| Nunchaku | 17 |
| FukiyaDarts | 1 |
| Bokuto | 10 |


#### `SBSECarpenter`

Used by: Carpenter

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bokuto | 21 | 20 |
| Tetsubo | 43 | 20 |
| Fukiya | 20 | 20 |
| BambooFlute | 21 | 20 |
| BambooFlute | 21 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Tetsubo | 21 |
| Fukiya | 10 |
| BambooFlute | 10 |
| Bokuto | 10 |


#### `SBSECook`

Used by: Cook

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Wasabi | 2 | 20 |
| Wasabi | 2 | 20 |
| SushiRolls | 3 | 20 |
| SushiPlatter | 3 | 20 |
| GreenTea | 3 | 20 |
| MisoSoup | 3 | 20 |
| WhiteMisoSoup | 3 | 20 |
| RedMisoSoup | 3 | 20 |
| AwaseMisoSoup | 3 | 20 |
| BentoBox | 6 | 20 |
| BentoBox | 6 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Wasabi | 1 |
| BentoBox | 3 |
| GreenTea | 1 |
| SushiRolls | 1 |
| SushiPlatter | 2 |
| MisoSoup | 1 |
| RedMisoSoup | 1 |
| WhiteMisoSoup | 1 |
| AwaseMisoSoup | 1 |


#### `SBSEFood`

Used by: InnKeeper

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Wasabi | 2 | 20 |
| Wasabi | 2 | 20 |
| BentoBox | 6 | 20 |
| BentoBox | 6 | 20 |
| GreenTeaBasket | 1000 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Wasabi | 1 |
| BentoBox | 3 |
| GreenTeaBasket | 1 |


#### `SBSEHats`

Used by: Provisioner

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Kasa | 31 | 20 |
| LeatherJingasa | 11 | 20 |
| ClothNinjaHood | 33 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Kasa | 15 |
| LeatherJingasa | 5 |
| ClothNinjaHood | 16 |


#### `SBSELeatherArmor`

Used by: Armorer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| LeatherJingasa | 11 | 20 |
| LeatherDo | 87 | 20 |
| LeatherHiroSode | 49 | 20 |
| LeatherSuneate | 55 | 20 |
| LeatherHaidate | 54 | 20 |
| LeatherNinjaPants | 49 | 20 |
| LeatherNinjaJacket | 51 | 20 |
| StuddedMempo | 61 | 20 |
| StuddedDo | 130 | 20 |
| StuddedHiroSode | 73 | 20 |
| StuddedSuneate | 78 | 20 |
| StuddedHaidate | 76 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| LeatherJingasa | 5 |
| LeatherDo | 42 |
| LeatherHiroSode | 23 |
| LeatherSuneate | 26 |
| LeatherHaidate | 28 |
| LeatherNinjaPants | 25 |
| LeatherNinjaJacket | 26 |
| StuddedMempo | 28 |
| StuddedDo | 66 |
| StuddedHiroSode | 32 |
| StuddedSuneate | 40 |
| StuddedHaidate | 37 |


#### `SBSEWeapons`

Used by: Blacksmith, Weaponsmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| NoDachi | 82 | 20 |
| Tessen | 83 | 20 |
| Wakizashi | 38 | 20 |
| Tetsubo | 43 | 20 |
| Lajatang | 108 | 20 |
| Daisho | 66 | 20 |
| Tekagi | 55 | 20 |
| Shuriken | 18 | 20 |
| Kama | 61 | 20 |
| Sai | 56 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| NoDachi | 41 |
| Tessen | 41 |
| Wakizashi | 19 |
| Tetsubo | 21 |
| Lajatang | 54 |
| Daisho | 33 |
| Tekagi | 22 |
| Shuriken | 9 |
| Kama | 30 |
| Sai | 28 |


#### `SBShipwright`

Used by: Shipwright

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| SmallBoatDeed | 10177 | 20 |
| SmallDragonBoatDeed | 10177 | 20 |
| MediumBoatDeed | 11552 | 20 |
| MediumDragonBoatDeed | 11552 | 20 |
| LargeBoatDeed | 12927 | 20 |
| LargeDragonBoatDeed | 12927 | 20 |
| TokunoGalleonDeed | 150002 | 20 |
| GargishGalleonDeed | 200002 | 20 |
| RowBoatDeed | 6252 | 20 |
| Spyglass | 3 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Spyglass | 1 |


#### `SBSmithTools`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| IronIngot | 5 | 16 |
| Tongs | 13 | 14 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Tongs | 7 |
| IronIngot | 4 |


#### `SBSpearForkWeapon`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Pitchfork | 19 | 20 |
| ShortSpear | 23 | 20 |
| Spear | 31 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Spear | 15 |
| Pitchfork | 9 |
| ShortSpear | 11 |


#### `SBStavesWeapon`

Used by: Carpenter, StoneCrafter

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BlackStaff | 22 | 20 |
| GnarledStaff | 16 | 20 |
| QuarterStaff | 19 | 20 |
| ShepherdsCrook | 20 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BlackStaff | 11 |
| GnarledStaff | 8 |
| QuarterStaff | 9 |
| ShepherdsCrook | 10 |


#### `SBStoneCrafter`

Used by: StoneCrafter

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Nails | 3 | 20 |
| Axle | 2 | 20 |
| Board | 3 | 20 |
| DrawKnife | 10 | 20 |
| Froe | 10 | 20 |
| Scorp | 10 | 20 |
| Inshave | 10 | 20 |
| DovetailSaw | 12 | 20 |
| Saw | 15 | 20 |
| Hammer | 17 | 20 |
| MouldingPlane | 11 | 20 |
| SmoothingPlane | 10 | 20 |
| JointingPlane | 11 | 20 |
| MasonryBook | 10625 | 10 |
| StoneMiningBook | 10625 | 10 |
| MalletAndChisel | 3 | 50 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| MasonryBook | 5000 |
| StoneMiningBook | 5000 |
| MalletAndChisel | 1 |
| WoodenBox | 7 |
| SmallCrate | 5 |
| MediumCrate | 6 |
| LargeCrate | 7 |
| WoodenChest | 15 |
| LargeTable | 10 |
| Nightstand | 7 |
| YewWoodTable | 10 |
| Throne | 24 |
| WoodenThrone | 6 |
| Stool | 6 |
| FootStool | 6 |
| FancyWoodenChairCushion | 12 |
| WoodenChairCushion | 10 |
| WoodenChair | 8 |
| BambooChair | 6 |
| WoodenBench | 6 |
| Saw | 9 |
| Scorp | 6 |
| SmoothingPlane | 6 |
| DrawKnife | 6 |
| Froe | 6 |
| Hammer | 14 |
| Inshave | 6 |
| JointingPlane | 6 |
| MouldingPlane | 6 |
| DovetailSaw | 7 |
| Board | 2 |
| Axle | 1 |
| WoodenShield | 31 |
| BlackStaff | 24 |
| GnarledStaff | 12 |
| QuarterStaff | 15 |
| ShepherdsCrook | 12 |
| Club | 13 |
| Log | 1 |


#### `SBStuddedArmor`

Used by: Armorer, IronWorker, LeatherWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| StuddedArms | 87 | 20 |
| StuddedChest | 128 | 20 |
| StuddedGloves | 79 | 20 |
| StuddedGorget | 73 | 20 |
| StuddedLegs | 103 | 20 |
| FemaleStuddedChest | 142 | 20 |
| StuddedBustierArms | 120 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| StuddedArms | 43 |
| StuddedChest | 64 |
| StuddedGloves | 39 |
| StuddedGorget | 36 |
| StuddedLegs | 51 |
| FemaleStuddedChest | 71 |
| StuddedBustierArms | 60 |


#### `SBSwordWeapon`

Used by: Blacksmith, IronWorker

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Cutlass | 24 | 20 |
| Katana | 33 | 20 |
| Kryss | 32 | 20 |
| Broadsword | 35 | 20 |
| Longsword | 55 | 20 |
| ThinLongsword | 27 | 20 |
| VikingSword | 55 | 20 |
| Scimitar | 36 | 20 |
| BoneHarvester | 35 | 20 |
| CrescentBlade | 37 | 20 |
| DoubleBladedStaff | 35 | 20 |
| Lance | 34 | 20 |
| Pike | 39 | 20 |
| Scythe | 39 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Broadsword | 17 |
| Cutlass | 12 |
| Katana | 16 |
| Kryss | 16 |
| Longsword | 27 |
| Scimitar | 18 |
| ThinLongsword | 13 |
| VikingSword | 27 |
| Scythe | 19 |
| BoneHarvester | 17 |
| Scepter | 18 |
| BladedStaff | 16 |
| Pike | 19 |
| DoubleBladedStaff | 17 |
| Lance | 17 |
| CrescentBlade | 18 |


#### `SBTailor`

Used by: Tailor

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| SewingKit | 3 | 20 |
| Scissors | 11 | 20 |
| DyeTub | 8 | 20 |
| Dyes | 8 | 20 |
| Shirt | 12 | 20 |
| ShortPants | 7 | 20 |
| FancyShirt | 21 | 20 |
| LongPants | 10 | 20 |
| FancyDress | 26 | 20 |
| PlainDress | 13 | 20 |
| Kilt | 11 | 20 |
| Kilt | 11 | 20 |
| HalfApron | 10 | 20 |
| Robe | 18 | 20 |
| Cloak | 8 | 20 |
| Cloak | 8 | 20 |
| Doublet | 13 | 20 |
| Tunic | 18 | 20 |
| JesterSuit | 26 | 20 |
| JesterHat | 12 | 20 |
| FloppyHat | 7 | 20 |
| WideBrimHat | 8 | 20 |
| Cap | 10 | 20 |
| TallStrawHat | 8 | 20 |
| StrawHat | 7 | 20 |
| WizardsHat | 11 | 20 |
| LeatherCap | 10 | 20 |
| FeatheredHat | 10 | 20 |
| TricorneHat | 8 | 20 |
| Bandana | 6 | 20 |
| SkullCap | 7 | 20 |
| BoltOfCloth | 100 | 20 |
| Cloth | 2 | 20 |
| UncutCloth | 2 | 20 |
| Cotton | 102 | 20 |
| Wool | 62 | 20 |
| Flax | 102 | 20 |
| SpoolOfThread | 18 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Scissors | 6 |
| SewingKit | 1 |
| Dyes | 4 |
| DyeTub | 4 |
| BoltOfCloth | 50 |
| Cloth | 1 |
| UncutCloth | 1 |
| FancyShirt | 10 |
| Shirt | 6 |
| ShortPants | 3 |
| LongPants | 5 |
| Cloak | 4 |
| FancyDress | 12 |
| Robe | 9 |
| PlainDress | 7 |
| Skirt | 5 |
| Kilt | 5 |
| Doublet | 7 |
| Tunic | 9 |
| JesterSuit | 13 |
| FullApron | 5 |
| HalfApron | 5 |
| JesterHat | 6 |
| FloppyHat | 3 |
| WideBrimHat | 4 |
| Cap | 5 |
| SkullCap | 3 |
| Bandana | 3 |
| TallStrawHat | 4 |
| StrawHat | 4 |
| WizardsHat | 5 |
| Bonnet | 4 |
| FeatheredHat | 5 |
| TricorneHat | 4 |
| SpoolOfThread | 9 |
| Flax | 51 |
| Cotton | 51 |
| Wool | 31 |


#### `SBTanner`

Used by: Tanner

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| LeatherGorget | 31 | 20 |
| LeatherCap | 10 | 20 |
| LeatherArms | 37 | 20 |
| LeatherChest | 47 | 20 |
| LeatherLegs | 36 | 20 |
| LeatherGloves | 31 | 20 |
| StuddedGorget | 50 | 20 |
| StuddedArms | 57 | 20 |
| StuddedChest | 75 | 20 |
| StuddedLegs | 67 | 20 |
| StuddedGloves | 45 | 20 |
| FemaleStuddedChest | 62 | 20 |
| FemalePlateChest | 207 | 20 |
| FemaleLeatherChest | 36 | 20 |
| LeatherShorts | 28 | 20 |
| LeatherSkirt | 25 | 20 |
| LeatherBustierArms | 25 | 20 |
| LeatherBustierArms | 30 | 20 |
| StuddedBustierArms | 50 | 20 |
| StuddedBustierArms | 47 | 20 |
| Bag | 6 | 20 |
| Pouch | 6 | 20 |
| Backpack | 15 | 20 |
| Leather | 6 | 20 |
| SkinningKnife | 15 | 20 |
| TaxidermyKit | 100000 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bag | 3 |
| Pouch | 3 |
| Backpack | 7 |
| Leather | 5 |
| SkinningKnife | 7 |
| LeatherArms | 18 |
| LeatherChest | 23 |
| LeatherGloves | 15 |
| LeatherGorget | 15 |
| LeatherLegs | 18 |
| LeatherCap | 5 |
| StuddedArms | 43 |
| StuddedChest | 37 |
| StuddedGloves | 39 |
| StuddedGorget | 22 |
| StuddedLegs | 33 |
| FemaleStuddedChest | 31 |
| StuddedBustierArms | 23 |
| FemalePlateChest | 103 |
| FemaleLeatherChest | 18 |
| LeatherBustierArms | 12 |
| LeatherShorts | 14 |
| LeatherSkirt | 12 |


#### `SBTavernKeeper`

Used by: TavernKeeper

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BreadLoaf | 6 | 10 |
| CheeseWheel | 21 | 10 |
| CookedBird | 17 | 20 |
| LambLeg | 8 | 20 |
| ChickenLeg | 5 | 20 |
| Ribs | 7 | 20 |
| WoodenBowlOfCarrots | 3 | 20 |
| WoodenBowlOfCorn | 3 | 20 |
| WoodenBowlOfLettuce | 3 | 20 |
| WoodenBowlOfPeas | 3 | 20 |
| EmptyPewterBowl | 2 | 20 |
| PewterBowlOfCorn | 3 | 20 |
| PewterBowlOfLettuce | 3 | 20 |
| PewterBowlOfPeas | 3 | 20 |
| PewterBowlOfPotatos | 3 | 20 |
| WoodenBowlOfStew | 3 | 20 |
| WoodenBowlOfTomatoSoup | 3 | 20 |
| ApplePie | 7 | 20 |
| Chessboard | 2 | 20 |
| CheckerBoard | 2 | 20 |
| Backgammon | 2 | 20 |
| Dices | 2 | 20 |
| ContractOfEmployment | 1252 | 20 |
| BarkeepContract | 1252 | 20 |
| VendorRentalContract | 1252 | 20 |
| Wasabi | 2 | 20 |
| Wasabi | 2 | 20 |
| BentoBox | 6 | 20 |
| BentoBox | 6 | 20 |
| GreenTeaBasket | 2 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| WoodenBowlOfCarrots | 1 |
| WoodenBowlOfCorn | 1 |
| WoodenBowlOfLettuce | 1 |
| WoodenBowlOfPeas | 1 |
| EmptyPewterBowl | 1 |
| PewterBowlOfCorn | 1 |
| PewterBowlOfLettuce | 1 |
| PewterBowlOfPeas | 1 |
| PewterBowlOfPotatos | 1 |
| WoodenBowlOfStew | 1 |
| WoodenBowlOfTomatoSoup | 1 |
| BeverageBottle | 3 |
| Jug | 6 |
| Pitcher | 5 |
| GlassMug | 1 |
| BreadLoaf | 3 |
| CheeseWheel | 12 |
| Ribs | 6 |
| Peach | 1 |
| Pear | 1 |
| Grapes | 1 |
| Apple | 1 |
| Banana | 1 |
| Candle | 3 |
| Chessboard | 1 |
| CheckerBoard | 1 |
| Backgammon | 1 |
| Dices | 1 |
| ContractOfEmployment | 626 |


#### `SBThief`

Used by: Thief

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Backpack | 15 | 20 |
| Pouch | 6 | 20 |
| Torch | 8 | 20 |
| Lantern | 2 | 20 |
| OilFlask | 8 | 20 |
| Lockpick | 12 | 20 |
| WoodenBox | 14 | 20 |
| Key | 2 | 20 |
| HairDye | 37 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Backpack | 7 |
| Pouch | 3 |
| Torch | 3 |
| Lantern | 1 |
| OilFlask | 4 |
| Lockpick | 6 |
| WoodenBox | 7 |
| HairDye | 19 |


#### `SBTinker`

Used by: GolemCrafter, Tinker, Vagabond

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Clock | 22 | 20 |
| Nails | 3 | 20 |
| ClockParts | 3 | 20 |
| AxleGears | 3 | 20 |
| Gears | 2 | 20 |
| Hinge | 2 | 20 |
| Sextant | 13 | 20 |
| SextantParts | 5 | 20 |
| Axle | 2 | 20 |
| Springs | 3 | 20 |
| Key | 8 | 20 |
| Key | 8 | 20 |
| Key | 8 | 20 |
| KeyRing | 8 | 20 |
| Lockpick | 12 | 20 |
| TinkersTools | 7 | 20 |
| Board | 3 | 20 |
| IronIngot | 5 | 16 |
| SewingKit | 3 | 20 |
| DrawKnife | 10 | 20 |
| Froe | 10 | 20 |
| Scorp | 10 | 20 |
| Inshave | 10 | 20 |
| ButcherKnife | 13 | 20 |
| Scissors | 11 | 20 |
| Tongs | 13 | 14 |
| DovetailSaw | 12 | 20 |
| Saw | 15 | 20 |
| Hammer | 17 | 20 |
| SmithHammer | 23 | 20 |
| Shovel | 12 | 20 |
| MouldingPlane | 11 | 20 |
| JointingPlane | 10 | 20 |
| SmoothingPlane | 11 | 20 |
| Pickaxe | 25 | 20 |
| Drums | 21 | 20 |
| Tambourine | 21 | 20 |
| LapHarp | 21 | 20 |
| Lute | 21 | 20 |
| AudChar | 33 | 20 |
| StatuetteEngravingTool | 1253 | 20 |
| BasketWeavingBook | 10625 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Drums | 10 |
| Tambourine | 10 |
| LapHarp | 10 |
| Lute | 10 |
| Shovel | 6 |
| SewingKit | 1 |
| Scissors | 6 |
| Tongs | 7 |
| Key | 1 |
| DovetailSaw | 6 |
| MouldingPlane | 6 |
| Nails | 1 |
| JointingPlane | 6 |
| SmoothingPlane | 6 |
| Saw | 7 |
| Clock | 11 |
| ClockParts | 1 |
| AxleGears | 1 |
| Gears | 1 |
| Hinge | 1 |
| Sextant | 6 |
| SextantParts | 2 |
| Axle | 1 |
| Springs | 1 |
| DrawKnife | 5 |
| Froe | 5 |
| Inshave | 5 |
| Scorp | 5 |
| Lockpick | 6 |
| TinkerTools | 3 |
| Board | 1 |
| Log | 1 |
| Pickaxe | 16 |
| Hammer | 3 |
| SmithHammer | 11 |
| ButcherKnife | 6 |


#### `SBVagabond`

Used by: GolemCrafter, Vagabond

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| GoldRing | 27 | 20 |
| Necklace | 26 | 20 |
| GoldNecklace | 27 | 20 |
| GoldBeadNecklace | 27 | 20 |
| Beads | 27 | 20 |
| GoldBracelet | 27 | 20 |
| GoldEarrings | 27 | 20 |
| Board | 3 | 20 |
| IronIngot | 6 | 20 |
| StarSapphire | 125 | 20 |
| Emerald | 100 | 20 |
| Sapphire | 100 | 20 |
| Ruby | 75 | 20 |
| Citrine | 50 | 20 |
| Amethyst | 100 | 20 |
| Tourmaline | 75 | 20 |
| Amber | 50 | 20 |
| Diamond | 200 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Board | 1 |
| IronIngot | 3 |
| Amber | 25 |
| Amethyst | 50 |
| Citrine | 25 |
| Diamond | 100 |
| Emerald | 50 |
| Ruby | 37 |
| Sapphire | 50 |
| StarSapphire | 62 |
| Tourmaline | 47 |
| GoldRing | 13 |
| SilverRing | 10 |
| Necklace | 13 |
| GoldNecklace | 13 |
| GoldBeadNecklace | 13 |
| SilverNecklace | 10 |
| SilverBeadNecklace | 10 |
| Beads | 13 |
| GoldBracelet | 13 |
| SilverBracelet | 10 |
| GoldEarrings | 13 |
| SilverEarrings | 10 |


#### `SBVarietyDealer`

Used by: VarietyDealer

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bandage | 5 | 20 |
| BlankScroll | 5 | 999 |
| NightSightPotion | 15 | 10 |
| AgilityPotion | 15 | 10 |
| StrengthPotion | 15 | 10 |
| RefreshPotion | 15 | 10 |
| LesserCurePotion | 15 | 10 |
| LesserHealPotion | 15 | 10 |
| LesserPoisonPotion | 15 | 10 |
| LesserExplosionPotion | 21 | 10 |
| BlackPearl | 5 | 999 |
| Bloodmoss | 5 | 999 |
| MandrakeRoot | 3 | 999 |
| Garlic | 3 | 999 |
| Ginseng | 3 | 999 |
| Nightshade | 3 | 999 |
| SpidersSilk | 3 | 999 |
| SulfurousAsh | 3 | 999 |
| BreadLoaf | 7 | 10 |
| Backpack | 15 | 20 |
| BatWing | 3 | 999 |
| GraveDust | 3 | 999 |
| DaemonBlood | 6 | 999 |
| NoxCrystal | 6 | 999 |
| PigIron | 5 | 999 |
| NecromancerSpellbook | 115 | 10 |
| RecallRune | 15 | 10 |
| Spellbook | 18 | 10 |
| MagicWizardsHat | 11 | 10 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bandage | 1 |
| BlankScroll | 3 |
| NightSightPotion | 7 |
| AgilityPotion | 7 |
| StrengthPotion | 7 |
| RefreshPotion | 7 |
| LesserCurePotion | 7 |
| LesserHealPotion | 7 |
| LesserPoisonPotion | 7 |
| LesserExplosionPotion | 10 |
| Bolt | 3 |
| Arrow | 2 |
| BlackPearl | 3 |
| Bloodmoss | 3 |
| MandrakeRoot | 2 |
| Garlic | 2 |
| Ginseng | 2 |
| Nightshade | 2 |
| SpidersSilk | 2 |
| SulfurousAsh | 2 |
| BreadLoaf | 3 |
| Backpack | 7 |
| RecallRune | 8 |
| Spellbook | 9 |
| BlankScroll | 3 |
| BatWing | 2 |
| GraveDust | 2 |
| DaemonBlood | 3 |
| NoxCrystal | 3 |
| PigIron | 3 |


#### `SBVeterinarian`

Used by: Veterinarian

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Bandage | 6 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Bandage | 1 |


#### `SBWaiter`

Used by: Waiter

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BreadLoaf | 6 | 10 |
| CheeseWheel | 21 | 10 |
| CookedBird | 17 | 20 |
| LambLeg | 8 | 20 |
| WoodenBowlOfCarrots | 3 | 20 |
| WoodenBowlOfCorn | 3 | 20 |
| WoodenBowlOfLettuce | 3 | 20 |
| WoodenBowlOfPeas | 3 | 20 |
| EmptyPewterBowl | 2 | 20 |
| PewterBowlOfCorn | 3 | 20 |
| PewterBowlOfLettuce | 3 | 20 |
| PewterBowlOfPeas | 3 | 20 |
| PewterBowlOfPotatos | 3 | 20 |
| WoodenBowlOfStew | 3 | 20 |
| WoodenBowlOfTomatoSoup | 3 | 20 |
| ApplePie | 7 | 20 |


#### `SBWeaponSmith`

Used by: Weaponsmith

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| BlackStaff | 22 | 20 |
| Club | 16 | 20 |
| GnarledStaff | 16 | 20 |
| Mace | 28 | 20 |
| Maul | 21 | 20 |
| QuarterStaff | 19 | 20 |
| ShepherdsCrook | 20 | 20 |
| SmithHammer | 21 | 20 |
| ShortSpear | 23 | 20 |
| Spear | 31 | 20 |
| WarHammer | 25 | 20 |
| WarMace | 31 | 20 |
| Scepter | 39 | 20 |
| BladedStaff | 40 | 20 |
| Hatchet | 25 | 20 |
| Hatchet | 27 | 20 |
| WarFork | 32 | 20 |
| ExecutionersAxe | 30 | 20 |
| Bardiche | 60 | 20 |
| BattleAxe | 26 | 20 |
| TwoHandedAxe | 32 | 20 |
| Bow | 35 | 20 |
| ButcherKnife | 14 | 20 |
| Crossbow | 46 | 20 |
| HeavyCrossbow | 55 | 20 |
| Cutlass | 24 | 20 |
| Dagger | 21 | 20 |
| Halberd | 42 | 20 |
| HammerPick | 26 | 20 |
| Katana | 33 | 20 |
| Kryss | 32 | 20 |
| Broadsword | 35 | 20 |
| Longsword | 55 | 20 |
| ThinLongsword | 27 | 20 |
| VikingSword | 55 | 20 |
| Cleaver | 15 | 20 |
| Axe | 40 | 20 |
| DoubleAxe | 52 | 20 |
| Pickaxe | 22 | 20 |
| Pitchfork | 19 | 20 |
| Scimitar | 36 | 20 |
| SkinningKnife | 14 | 20 |
| LargeBattleAxe | 33 | 20 |
| WarAxe | 29 | 20 |
| BoneHarvester | 35 | 20 |
| CrescentBlade | 37 | 20 |
| DoubleBladedStaff | 35 | 20 |
| Lance | 34 | 20 |
| Pike | 39 | 20 |
| Scythe | 39 | 20 |
| CompositeBow | 50 | 20 |
| RepeatingCrossbow | 57 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| BattleAxe | 13 |
| DoubleAxe | 26 |
| ExecutionersAxe | 15 |
| LargeBattleAxe | 16 |
| Pickaxe | 11 |
| TwoHandedAxe | 16 |
| WarAxe | 14 |
| Axe | 20 |
| Bardiche | 30 |
| Halberd | 21 |
| ButcherKnife | 7 |
| Cleaver | 7 |
| Dagger | 10 |
| SkinningKnife | 7 |
| Club | 8 |
| HammerPick | 13 |
| Mace | 14 |
| Maul | 10 |
| WarHammer | 12 |
| WarMace | 15 |
| HeavyCrossbow | 27 |
| Bow | 17 |
| Crossbow | 23 |
| CompositeBow | 25 |
| RepeatingCrossbow | 28 |
| Scepter | 20 |
| BladedStaff | 20 |
| Scythe | 19 |
| BoneHarvester | 17 |
| Scepter | 18 |
| BladedStaff | 16 |
| Pike | 19 |
| DoubleBladedStaff | 17 |
| Lance | 17 |
| CrescentBlade | 18 |
| Spear | 15 |
| Pitchfork | 9 |
| ShortSpear | 11 |
| BlackStaff | 11 |
| GnarledStaff | 8 |
| QuarterStaff | 9 |
| ShepherdsCrook | 10 |
| SmithHammer | 10 |
| Broadsword | 17 |
| Cutlass | 12 |
| Katana | 16 |
| Kryss | 16 |
| Longsword | 27 |
| Scimitar | 18 |
| ThinLongsword | 13 |
| VikingSword | 27 |
| Hatchet | 13 |
| WarFork | 16 |


#### `SBWeaver`

Used by: Weaver

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| Dyes | 8 | 20 |
| DyeTub | 8 | 20 |
| UncutCloth | 3 | 20 |
| UncutCloth | 3 | 20 |
| UncutCloth | 3 | 20 |
| UncutCloth | 3 | 20 |
| BoltOfCloth | 100 | 20 |
| BoltOfCloth | 100 | 20 |
| BoltOfCloth | 100 | 20 |
| BoltOfCloth | 100 | 20 |
| DarkYarn | 18 | 20 |
| LightYarn | 18 | 20 |
| LightYarnUnraveled | 18 | 20 |
| Scissors | 11 | 20 |
| LeatherBraid | 50 | 500 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| Scissors | 6 |
| Dyes | 4 |
| DyeTub | 4 |
| UncutCloth | 1 |
| BoltOfCloth | 50 |
| LightYarnUnraveled | 9 |
| LightYarn | 9 |
| DarkYarn | 9 |


#### `SBWoodenShields`

Used by: Blacksmith, Carpenter, StoneCrafter

**Stock sold to players** ("item", price gps, max stock):

| Item | Price | Stock |
|---|---:|---:|
| WoodenShield | 30 | 20 |

**Buys from players** (item, unit price gps):

| Item | Unit price |
|---|---:|
| WoodenShield | 15 |



### 2.5 Animals, mounts and taming

**【C】** `Scripts/Mobiles/Normal/*.cs`. `Tamable`, `MinTameSkill`, `ControlSlots` and `PackInstinct` read directly from source. Body/ItemID shown as `body/itemID` where the class passes them to `base(name, body, itemID, …)`.

#### 2.5.1 Mounts (`: BaseMount`)

| Class | Body / ItemID | MinTameSkill | Control slots | Pack instinct |
|---|---|---:|---:|---|
| **Horse** | 0xE2 / 0x3EA0 (random variant from `m_IDs`) | 29.1 | 1 | — |
| **RidableLlama** | 0xDC / 0x3EA6 | 29.1 | 1 | — |
| **ForestOstard** | 0xDB / 0x3EA5 | 29.1 | 1 | Ostard |
| **DesertOstard** | 0xD2 / 0x3EA3 | 29.1 | 1 | Ostard |
| **FrenziedOstard** | 0xDA / 0x3EA4 | 77.1 | 1 | Ostard |
| **Nightmare** | 0x74 / 0x3EA7 | 95.1 | 2 | — |
| **DreadWarhorse** | 0x74 / 0x3EA7 | 108.0 | 3 | — |
| **FireSteed** | 0xBE / 0x3E9E | 106.0 | 2 | Daemon |
| **SwampDragon** | 0x31A / 0x3EBD | 93.9 | 1 | — |
| **ScaledSwampDragon** | 0x31F / 0x3EBE | 93.9 | 1 | — |
| **Beetle** (giant beetle) | 0x317 / 0x3EBC | 29.1 | 3 | — |
| **Unicorn** | 0x7A / 0x3EB4 | 95.1 | 2 | — |
| **Kirin** | — | 95.1 | 2 | — |
| **Ridgeback** | — | 83.1 | 1 | — |
| **SavageRidgeback** | — | 83.1 | 1 | — |
| **Hiryu** | — | 98.7 | 4 | — |
| **LesserHiryu** | — | 98.7 | 3 | — |
| **Reptalon** | — | 101.1 | 4 | — |
| **CuSidhe** | — | 101.1 | 4 | — |
| **WildTiger** / **WildWhiteTiger** / **WildBlackTiger** | — | 95.1 | 2 | — |
| **BaneDragon** | — | 107.1 | 3 | — |
| **CoconutCrab**, **Eowmu**, **SkeletalCat**, **Lasher**, **Windrunner** | — | 30.0 / 30.0 / 30.0 / — / — | 1–2 | — |

#### 2.5.2 Pack animals (carry a pack, **not** rideable)

| Class | MinTameSkill | Control slots |
|---|---:|---:|
| **PackHorse** | 29.1 | 1 |
| **PackLlama** | 29.1 | 1 |

**【C】** `Scripts/Mobiles/Normal/PackHorse.cs`, `PackLlama.cs`. These two are `BaseCreature` (not `BaseMount`), tamable at the same skill as a horse/llama, and are the classic item-hauling pets.

#### 2.5.3 Tameable wild animals and monsters

| Class | MinTameSkill | Slots | Pack instinct | Class | MinTameSkill | Slots | Pack instinct |
|---|---:|---:|---|---|---:|---:|---|
| Squirrel | −21.3 | 1 | — | TimberWolf | 23.1 | 1 | Canine |
| Ferret | −21.3 | 1 | — | Hind | 23.1 | 1 | — |
| Dog | −21.3 | 1 | Canine | GiantToad | 77.1 | 1 | — |
| Rabbit | −18.9 | 1 | — | BullFrog | 23.1 | 1 | — |
| JackRabbit | −18.9 | 1 | — | Slime | 23.1 | 1 | — |
| Mongbat | −18.9 | 1 | — | CorrosiveSlime | 23.1 | 1 | — |
| Gorilla | −18.9 | 1 | — | PolarBear | 35.1 | 1 | Bear |
| SkitteringHopper | −12.9 | 1 | — | BlackBear | 35.1 | 1 | Bear |
| Bird | −6.9 | 1 | — | Llama | 35.1 | 1 | — |
| TropicalBird | −6.9 | 1 | — | Walrus | 35.1 | 1 | — |
| Cat | −0.9 | 1 | Feline | BrownBear | 41.1 | 1 | Bear |
| Chicken | −0.9 | 1 | — | Cougar | 41.1 | 1 | Feline |
| MountainGoat | −0.9 | 1 | — | DeathwatchBeetle | 41.1 | 1 | — |
| Rat | −0.9 | 1 | — | **Scorpion** | 47.1 | 1 | Arachnid |
| Sewerrat | −0.9 | 1 | — | Alligator | 47.1 | 1 | — |
| BattleChickenLizard | 0.0 | 1 | — | HighPlainsBoura | 47.1 | 3 | — |
| ChickenLizard | 0.0 | 1 | — | Panther | 53.1 | 1 | Feline |
| Parrot | 0.0 | 1 | — | GreyWolf | 53.1 | 1 | Canine |
| HungryCoconutCrab | 0.0 | 1 | — | SnowLeopard | 53.1 | 1 | Feline |
| Cow | 11.1 | 1 | — | **GiantSpider** | 59.1 | 1 | Arachnid |
| Goat | 11.1 | 1 | — | GreatHart | 59.1 | 1 | — |
| Pig | 11.1 | 1 | — | GrizzlyBear | 59.1 | 1 | Bear |
| Sheep | 11.1 | 1 | — | WolfSpider | 59.1 | 2 | Arachnid |
| Eagle | 17.1 | 1 | — | StoneSlith | 65.1 | 2 | — |
| LowlandBoura | 19.1 | 3 | — | GargoylePet | 65.1 | 2 | — |
| RuddyBoura | 19.1 | 2 | — | WhiteWolf | 65.1 | 1 | Canine |
| **GiantRat** | 29.1 | 1 | — | Gaman | 68.7 | 1 | — |
| **Boar** | 29.1 | 1 | — | HellCat | 71.1 | 1 | Feline |
| **Bull** | 71.1 | 1 | Bull | GreaterMongbat | 71.1 | 1 | — |
| GiantIceWorm | 71.1 | 1 | — | IronBeetle | 71.1 | 4 | — |
| FrostSpider | 74.7 | 1 | Arachnid | OsseinRam | 72.0 | 2 | — |
| BloodFox | 72.0 | 2 | — | Hiryu | 98.7 | 4 | — |
| **Dragon** | 93.9 | 3 | — | **Drake** | 84.3 | 2 | — |
| **Nightmare** | 95.1 | 2 | — | HellHound | 85.5 | 1 | Canine |
| IceHound | 85.5 | 1 | Canine | **DreadSpider** | 96.0 | 3 | — |
| FrostDragon | 105.0 | 5 | — | GreaterDragon | 104.7 | 5 | — |
| ShadowWyrm | 105.0 | 5 | — | WhiteWyrm | 96.3 | 3 | — |
| SerpentineDragon | 108.0 | 3 | — | **Imp** | 83.1 | 2 | Daemon |
| LavaLizard | 80.7 | 1 | — | Slith | 80.7 | 1 | — |
| BakeKitsune | 80.7 | 2 | — | Phoenix | 102.0 | 4 | — |
| FrostMite | 102.0 | 3 | — | SabertoothedTiger | 102.0 | 2 | — |
| DragonWolf | 102.0 | 4 | — | Triton | 96.0 | 2 | — |
| Skree | 95.1 | 4 | — | TsukiWolf | 96.0 | 3 | — |
| DireWolf | 83.1 | 1 | Canine | Lion | 96.0 | 2 | — |
| CrimsonDrake | 85.0 | 2 | — | PlatinumDrake | 85.0 | 2 | — |
| ColdDrake | 96.0 | 3 | — | StygianDrake | 85.0 | 4 | — |
| PredatorHellCat | 90.0 | 2 | Feline | RuneBeetle | 93.9 | 3 | — |
| Reptalon | 101.1 | 4 | — | — | — | — | — |

**Non-tameable classics (for contrast):** Slime is tameable; **Skeleton, Zombie, Ghoul, HeadlessOne, Lizardman, Orc, Ettin, Troll, Ogre, Gazer, Gargoyle, Harpy, elementals, GiantSerpent, Lich, BoneMagi, Wraith, Spectre, Reaper, Wisp, Daemon, Balron, AncientWyrm, OgreLord, Cyclops, Titan are NOT tameable** in ServUO. 【C】

#### 2.5.4 How taming and mounting work

**【C】** `Scripts/Skills/AnimalTaming.cs`, `Scripts/Mobiles/Normal/BaseCreature.cs`, `Scripts/Mobiles/Normal/BaseMount.cs`.

| Mechanic | Rule |
|---|---|
| **Tame attempt** | Use the Animal Taming skill and target a creature. Success depends on `AnimalTaming` vs the creature's `MinTameSkill`; requires the creature to be at low health (`< 10%`… actually a difficulty check) and the tamer to have free **control slots** and **followers**. |
| **MinTameSkill** | Per-creature, see tables above. Values below 0 mean "always tamable". 【C】 `BaseCreature.MinTameSkill`, `m_dMinTameSkill` |
| **Control slots** | Each pet consumes `ControlSlots` (1–5). Player follower limit is derived from **Animal Taming + Animal Lore + Veterinary** (see stable slots formula, §5.4, which mirrors it). 【C】 `BaseCreature.m_iControlSlots`, `ControlSlotsMin`/`ControlSlotsMax` |
| **Loyalty** | `MaxLoyalty = 100`. Loyalty **+1** on successful command, **−3** on failed/refused command. 【C】 `BaseCreature.cs:204, 1490, 1505` |
| **Bonding** | `IsBondable => BondingEnabled && !Summoned && !m_Allured && !IsGolem`. Bonded pets resurrect with the owner and never go wild. 【C】 `BaseCreature.cs:436` |
| **Mounting** | `BaseMount` creatures have `ItemID` (the ridden graphic) alongside `Body`. Double-click the pet to mount; the rider's `Body` is replaced by the mount's ridden `ItemID`. You must be a `PlayerMobile` and the pet must be `Controlled` by you. 【C】 `BaseMount.cs` |
| **Mount speed** | While mounted, movement uses the mount's speed; the classic rule is that a mount removes the stamina cost of running. 【C】 `Server/Movement.cs` (mount check in `Mobile.CheckMovement`) |
| **Pack animals** | `PackHorse`/`PackLlama` expose a **pack container** (a `Container` on `Layer.Pack`); double-click the pet to open it. `PackAnimalBackpackEntry` adds the context-menu entry. 【C】 taming scan: `PackAnimalBackpackEntry` |
| **Auto-stable** | `BaseCreature.CanAutoStable` — a pet left logged-out can be auto-stabled. 【C】 `BaseCreature.cs:1065-1069` |
| **Pack instinct** | Creatures sharing a `PackInstinct` (`Canine, Feline, Bear, Arachnid, Ostard, Bull, Daemon, Equine`) that fight within range of each other gain a damage bonus. This is implemented via `PackInstinct` overrides and the pack-AI in `Scripts/Mobiles/AI/`. 【C】 `BaseCreature.PackInstinct` |

#### 2.5.5 Farm and town critters (non-tameable-stat reference)

| Class | Class | Notes |
|---|---|---|
| **Cow**, **Bull**, **Pig**, **Sheep**, **Goat**, **Chicken** | `BaseCreature` | Standard farm animals. Sheep is `ICarvable` (shear for wool, then `Sheep` corpse). 【C】 `Sheep.cs` |
| **Cat**, **Dog** | `BaseCreature` | The `SpawnDefinitions.xml` group **`TownAnimals`** = `{ Cat, Dog }`. 【D】 `runuo/Data/SpawnDefinitions.xml` |
| **Bird** | `BaseCreature` | Name is `"a crow"`; body 6; STR 10, DEX 25–35, INT 10; damage 0; Fame 150, Karma 0; `Tamable = true; MinTameSkill = -6.9`. Virtually harmless. 【C】 `Bird.cs` |
| **Rabbit**, **JackRabbit**, **Hind**, **GreatHart**, **Boar** | `BaseCreature` | The classic huntable wildlife (Hind/GreatHart are the "deer"). |
| **Rat**, **Sewerrat**, **GiantRat** | `BaseCreature` | Rat/Sewerrat are body 238, `AI_Animal`/`AI_Melee`, 6 hits. |
| **SkitteringHopper**, **Ferret**, **Squirrel** | `BaseCreature` | Ambience critters, `MinTameSkill` ≈ −13 to −21. |

**Sea creatures** are covered in §3.4.

---


## 3. Monster catalogue

**All rows in §3.1–3.4 are 【C】 parsed from `ServUO/Scripts/Mobiles/Normal/*.cs`**, extracted with `.cache/analysis/extract-monsters.ps1` into `monsters.tsv` (665 creature classes). Single number = fixed value; `a, b` = random inclusive range.

**Reading the columns**

- **Body** — the `Body` value assigned in the ctor (client `body.def` index). Compatible with the classic client art.
- **Hits/Stam/Mana** — `SetHits` / `SetStam` / `SetMana`. Blank = not set (inherits from `BaseCreature` defaults).
- **Damage** — the `SetDamage(min, max)` range, *before* Strength/Tactics/Anatomy scaling. See §3.6.
- **VA** — `VirtualArmor`, the **pre-AoS Armor Rating** of the creature. This is the number a classic clone should use.
- **Res** — the AoS five-resistance spread (`SetResistance(type, min[, max])`). **Post-AoS only.** A classic clone should ignore this column and use `VA`.
- **CS** — `ControlSlots` if tamable.
- **Fame / Karma** — both set explicitly; `Fame` drives title and loot quality, `Karma` drives notoriety.
- **Loot** — the `AddLoot(LootPack.X[, n])` calls; `n` = number of independent rolls. Expand via §3.5.

### 3.1 Core monster table — beginner to endgame

#### Tier 1 — harmless to trivial (0–50 combat skill)

| Monster | Body | AI / FightMode | STR | DEX | INT | Hits | Mana | Damage | VA | Fame | Karma | Loot |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Rat** | 238 | Animal / Aggressor | 9 | 35 | 5 | 6 | 0 | 1–2 | 6 | 150 | −150 | Poor |
| **SewerRat** (`Sewerrat`) | 238 | Melee / Closest | 9 | 25 | 6–10 | 6 | 0 | 1–2 | 6 | 300 | −300 | Poor |
| **Mongbat** | 39 | Melee / Closest | 6–10 | 26–38 | 6–14 | 4–6 | 0 | 1–2 | 10 | 150 | −150 | Poor |
| **Bird** ("a crow") | 6 | Animal / Aggressor | 10 | 25–35 | 10 | — | — | 0 | 0–6 (random) | 150 | 0 | — |
| **Slime** | 51 | Melee / Closest | 22–34 | 16–21 | 16–20 | 15–19 | — | 1–5 | 8 | 300 | −300 | Poor + Gems |
| **Snake** | 52 | Melee / Closest | 22–34 | 16–25 | 6–10 | 15–19 | 0 | 1–4 | 16 | 300 | −300 | — |
| **HeadlessOne** ("a headless one") | 31 | Melee / Closest | 26–50 | 36–55 | 16–30 | 16–30 | — | 5–10 | 18 | 450 | −450 | Poor |
| **Zombie** | 3 | Melee / Closest | 46–70 | 31–50 | 26–40 | 28–42 | — | 3–7 | 18 | 600 | −600 | Meager |
| **Skeleton** | 50 or 56 (random) | Melee / Closest | 56–80 | 56–75 | 16–40 | 34–48 | — | 3–7 | 16 | 450 | −450 | Poor |
| **GiantSpider** | 28 | Melee / Closest | 76–100 | 76–95 | 36–60 | 46–60 | 0 | 5–13 | 16 | 600 | −600 | Poor |
| **Ghoul** | 153 | Melee / Closest | 76–100 | 76–95 | 36–60 | 46–60 | 0 | 7–9 | 28 | 2500 | −2500 | Meager |
| **FrostSpider** | 20 | Melee / Closest | 76–100 | 126–145 | 36–60 | 46–60 | 0 | 6–16 | 28 | 775 | −775 | Meager + Poor |

Skills for tier 1 (all `SetSkill(SkillName.X, lo, hi)`):

| Monster | Skills |
|---|---|
| Rat | MagicResist 4, Tactics 4, Wrestling 4 |
| SewerRat | MagicResist 5, Tactics 5, Wrestling 5 |
| Mongbat | MagicResist 5.1–14, Tactics 5.1–10, Wrestling 5.1–10 |
| Slime | **Poisoning 30.1–50**, MagicResist 15.1–20, Tactics 19.3–34, Wrestling 19.3–34 |
| Snake | **Poisoning 50.1–70**, MagicResist 15.1–20, Tactics 19.3–34, Wrestling 19.3–34 |
| HeadlessOne | MagicResist 15.1–20, Tactics 25.1–40, Wrestling 25.1–40 |
| Zombie | MagicResist 15.1–40, Tactics 35.1–50, Wrestling 35.1–50 |
| Skeleton | MagicResist 45.1–60, Tactics 45.1–60, Wrestling 45.1–55 |
| GiantSpider | **Poisoning 60.1–80**, MagicResist 25.1–40, Tactics 35.1–50, Wrestling 50.1–65 |
| Ghoul | MagicResist 45.1–60, Tactics 45.1–60, Wrestling 45.1–55 |
| FrostSpider | MagicResist 25.1–40, Tactics 35.1–50, Wrestling 50.1–65 |

Special: **Slime, Snake, GiantSpider, FrostSpider, Scorpion, DreadSpider, GiantSerpent** use `HitPoison` / `MagicalAbility.Poisoning`. Slime/Snake/GiantSpider are `Tamable` (23.1 / 59.1 / 59.1). Skeleton/Ghoul `PoisonImmune = Lesser` / `Regular`. 【C】

#### Tier 2 — early combat (50–75 skill)

| Monster | Body | AI / FightMode | STR | DEX | INT | Hits | Damage | VA | Fame | Karma | Loot |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Lizardman** | 35 or 36 (random) | Melee / Closest | 96–120 | 86–105 | 36–60 | 58–72 | 5–7 | 28 | 1500 | −1500 | Meager |
| **Orc** | 17 | Melee / Closest | 96–120 | 81–105 | 36–60 | 58–72 | 5–7 | 28 | 1500 | −1500 | Meager |
| **Scorpion** | 48 | Melee / Closest | 73–115 | 76–95 | 16–30 | 50–63 | 5–10 | 28 | 2000 | −2000 | Meager |
| **Harpy** | 30 | Melee / Closest | 96–120 | 86–110 | 51–75 | 58–72 | 5–7 | 28 | 2500 | −2500 | Meager ×2 |
| **OrcCaptain** | 7 | Melee / Closest | 111–145 | 101–135 | 86–110 | 67–87 | 5–15 | 34 | 2500 | −2500 | Meager ×2 |
| **OrcBomber** | 182 | Melee / Closest | 147–215 | 91–115 | 61–85 | 95–123 | 1–8 | 30 | 2500 | −2500 | Average + Meager |
| **Imp** | 74 | Mage / Closest | 91–115 | 61–80 | 86–105 | 55–70 | 10–14 | 30 | 2500 | −2500 | Meager + MedScrolls ×2 |
| **Ettin** | 18 | Melee / Closest | 136–165 | 56–75 | 31–55 | 82–99 | 7–17 | 38 | 3000 | −3000 | Meager + Average + Potions |
| **Ogre** | 1 | Melee / Closest | 166–195 | 46–65 | 46–70 | 100–117 | 9–11 | 32 | 3000 | −3000 | Average + Potions |
| **BoneMagi** ("a bone mage") | 148 | **NecroMage** / Closest | 76–100 | 56–75 | 186–210 | 46–60 | 3–7 | 38 | 3000 | −3000 | Average + LowScrolls + Potions |
| **GiantSerpent** | 0x15 | Melee / Closest | 186–215 | 56–80 | 66–85 | 112–129 | 7–17 | 32 | 2500 | −2500 | Average |
| **Troll** | 53 or 54 (random) | Melee / Closest | 176–205 | 46–65 | 46–70 | 106–123 | 8–14 | 40 | 3500 | −3500 | Average |
| **Gazer** | 22 | **Mage** / Closest | 96–125 | 86–105 | 141–165 | 58–75 | 5–10 | 36 | 3500 | −3500 | Average + Potions |
| **Gargoyle** | 4 | **Mage** / Closest | 146–175 | 76–95 | 81–105 | 88–105 | 7–14 | 32 | 3500 | −3500 | Average + MedScrolls + Gems(1–4) |
| **EarthElemental** | 14 | Melee / Closest | 126–155 | 66–85 | 71–92 | 76–93 | 9–16 | 34 | 3500 | −3500 | Average + Meager + Gems |
| **Reaper** | 47 | Mage / Closest | 66–215 | 66–75 | 101–250 | 40–129 | 9–11 | 40 | 3500 | −3500 | Average |

Skills: Lizardman MagicResist 35.1–60, Tactics 55.1–80, Wrestling 50.1–70 · Orc MagicResist 50.1–75, Tactics 55.1–80, Wrestling 50.1–70 · OrcCaptain MagicResist 70.1–85, **Swords 70.1–95**, Tactics 85.1–100 · OrcBomber MagicResist 70.1–85, Swords 60.1–85, Tactics 75.1–90, Wrestling 60.1–85 · Imp EvalInt 20.1–30, **Magery 90.1–100**, MagicResist 30.1–50, Tactics 42.1–50, Wrestling 40.1–44, Necromancy 20, SpiritSpeak 20 · Ettin MagicResist 40.1–55, Tactics 50.1–70, Wrestling 50.1–60 · Ogre MagicResist 55.1–70, Tactics 60.1–70, Wrestling 70.1–80 · BoneMagi EvalInt 60.1–70, Magery 60.1–70, MagicResist 55.1–70, Tactics 45.1–60, Wrestling 45.1–55, **Necromancy 89–99.1, SpiritSpeak 90–99** · GiantSerpent **Poisoning 70.1–100**, MagicResist 25.1–40, Tactics 65.1–70, Wrestling 60.1–80 · Troll MagicResist 45.1–60, Tactics 50.1–70, Wrestling 50.1–70 · Gazer EvalInt 50.1–65, Magery 50.1–65, MagicResist 60.1–75, Tactics 50.1–70, Wrestling 50.1–70 · Gargoyle EvalInt 70.1–85, Magery 70.1–85, MagicResist 70.1–85, Tactics 50.1–70, Wrestling 40.1–80 · EarthElemental MagicResist 50.1–95, Tactics 60.1–100, Wrestling 60.1–100 · Reaper EvalInt 90.1–100, Magery 90.1–100, MagicResist 100.1–125, Tactics 45.1–60, Wrestling 50.1–60 · **GiantSerpent/Scorpion HitPoison = 80% Greater / 20% Deadly**; `PoisonImmune = Greater` 【C】

#### Tier 3 — mid game (75–95 skill)

| Monster | Body | AI / FightMode | STR | DEX | INT | Hits | Damage | VA | Fame | Karma | Loot |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **AirElemental** | 13 | Mage / Closest | 126–155 | 166–185 | 101–125 | 76–93 | 8–10 | 40 | 4500 | −4500 | Average + Meager + LowScrolls + MedScrolls |
| **FireElemental** | 15 | Mage / Closest | 126–155 | 166–185 | 101–125 | 76–93 | 7–9 | 40 | 4500 | −4500 | Average + Meager + Gems |
| **WaterElemental** | 16 | Mage / Closest | 126–155 | 66–85 | 101–125 | 76–93 | 7–9 | 40 | 4500 | −4500 | Average + Meager + Potions |
| **Wisp** | 58 | Mage / **Aggressor** | 196–225 | 196–225 | 196–225 | 118–135 | 17–18 | 40 | 4000 | **0** | Rich + Average |
| **Wyvern** | 62 | Melee / Closest | 202–240 | 153–172 | 51–90 | 125–141 | 8–19 | 40 | 4000 | −4000 | Average + Meager + MedScrolls |
| **Wraith** | 26 | Mage / Closest | 76–100 | 76–95 | 36–60 | 46–60 | 7–11 | 28 | 4000 | −4000 | Meager |
| **Spectre** | 26 | Mage / Closest | 76–100 | 76–95 | 36–60 | 46–60 | 7–11 | 28 | 4000 | −4000 | Meager |
| **Cyclops** ("a cyclopean warrior") | 75 | Melee / Closest | 336–385 | 96–115 | 31–55 | 202–231 | 7–23 | 48 | 4500 | −4500 | Rich + Average |
| **StoneGargoyle** | 67 | Melee / Closest | 246–275 | 76–95 | 81–105 | 148–165 | 11–17 | 50 | 4000 | −4000 | Average ×2 + Gems + Potions |
| **DreadSpider** | 11 | **Mage** / Closest | 196–220 | 126–145 | 286–310 | 118–132 | 5–17 | 36 | 5000 | −5000 | **FilthyRich** |
| **Drake** | 60 or 61 (random) | Melee / Closest | 401–430 | 133–152 | 101–140 | 241–258 | 11–17 | 46 | 5500 | −5500 | Rich + MedScrolls ×2 |
| **Lich** | 24 | **NecroMage** / Closest | 171–200 | 126–145 | 276–305 | 103–120 | 24–26 | 50 | 8000 | −8000 | Rich + MedScrolls ×2 |
| **Efreet** | 131 | Mage / Closest | 326–355 | 266–285 | 171–195 | 196–213 | 11–13 | 56 | 10000 | −10000 | Rich + Average + Gems |
| **Titan** | 76 | Mage / Closest | 536–585 | 126–145 | 281–305 | 322–351 | 13–16 | 40 | 11500 | −11500 | FilthyRich + Average + MedScrolls |

Skills: AirElemental EvalInt 60.1–75, Magery 60.1–75, MagicResist 60.1–75, Tactics 60.1–80, Wrestling 60.1–80 · FireElemental EvalInt 60.1–75, Magery 60.1–75, **MagicResist 75.2–105**, Tactics 80.1–100, Wrestling 70.1–100 · WaterElemental EvalInt 60.1–75, Magery 60.1–75, **MagicResist 100.1–115**, Tactics 50.1–70, Wrestling 50.1–70 · Wisp EvalInt/Magery/MagicResist/Tactics/Wrestling all **80.0** · Wyvern **Poisoning 60.1–80**, MagicResist 65.1–80, Tactics 65.1–90, Wrestling 65.1–80 · Wraith/Spectre EvalInt 55.1–70, Magery 55.1–70, MagicResist 55.1–70, Tactics 45.1–60, Wrestling 45.1–55 · Cyclops MagicResist 60.3–105, Tactics 80.1–100, Wrestling 80.1–90 · StoneGargoyle MagicResist 85.1–100, Tactics 80.1–100, Wrestling 60.1–100 · DreadSpider EvalInt 65.1–80, Magery 65.1–80, MagicResist 45.1–60, Tactics 55.1–70, Wrestling 60.1–75, **Poisoning 80.0, DetectHidden 50–60, Necromancy 20, SpiritSpeak 20** · Drake MagicResist 65.1–80, Tactics 65.1–90, Wrestling 65.1–80 · Lich **Necromancy 89–99.1, SpiritSpeak 90–99, EvalInt 100 (fixed), Magery 70.1–80, Meditation 85.1–95, MagicResist 80.1–100, Tactics 70.1–90** · Efreet EvalInt 60.1–75, Magery 60.1–75, MagicResist 60.1–75, Tactics 60.1–80, Wrestling 60.1–80 · Titan EvalInt 85.1–100, Magery 85.1–100, MagicResist 80.2–110, Tactics 60.1–80, Wrestling 40.1–50 【C】

Special: `AirElemental` damage type is 20% Physical / 40% Cold / 40% Energy (post-AoS). `DreadSpider` **HitPoison = Poison.Lethal**, `PoisonImmune = Lethal`. `Drake`, `Dragon`, `Nightmare`, `AncientWyrm`, `GreaterDragon`, `ShadowWyrm` all set `SpecialAbility.DragonBreath`. `Wisp` has `Karma = 0` and `FightMode.Aggressor`. 【C】

#### Tier 4 — high end (95+ skill)

| Monster | Body | AI / FightMode | STR | DEX | INT | Hits | Damage | VA | Fame | Karma | CS | Loot |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **OgreLord** | 83 | Melee / Closest | 767–945 | 66–75 | 46–70 | 476–552 | 20–25 | 50 | 15000 | −15000 | — | Rich ×2 |
| **ArcticOgreLord** | 135 | Melee / Closest | 767–945 | 66–75 | 46–70 | 476–552 | 20–25 | 50 | 15000 | −15000 | — | FilthyRich + Rich |
| **Daemon** | 9 | Mage / Closest | 476–505 | 76–95 | 301–325 | 286–303 | 7–14 | 58 | 15000 | −15000 | 4–5 | Rich + Average ×2 + MedScrolls ×2 |
| **Dragon** | 12 or 59 (random) | Mage / Closest | 796–825 | 86–105 | 436–475 | 478–495 | 16–22 | 60 | 15000 | −15000 | 3 | **FilthyRich ×2** + Gems ×8 |
| **Nightmare** | 0x74 / 0x3EA7 (mount) | Mage / Closest | 496–525 | 86–105 | 86–125 | 298–315 | 16–22 | 60 | 14000 | −14000 | 2 | Rich + Average + LowScrolls + Potions |
| **WhiteWyrm** | 180 or 49 (random) | Mage / Closest | 721–760 | 101–130 | 386–425 | 433–456 | 17–25 | 64 | 18000 | −18000 | 3 | FilthyRich ×2 + Average + Gems(1–5) |
| **ShadowWyrm** | 106 | **NecroMage** / Closest | 898–1030 | 68–200 | 488–620 | 558–599 | 29–35 | 70 | 22500 | −22500 | 5 | FilthyRich ×3 + Gems ×5 |
| **AncientWyrm** | 46 | Mage / Closest | 1096–1185 | 86–175 | 686–775 | 658–711 | 29–35 | 70 | 22500 | −22500 | — | FilthyRich ×3 + Gems ×5 |
| **Balron** | 40 | Mage / Closest | 986–1185 | 177–255 | 151–250 | 592–711 | 22–29 | **90** | **24000** | −24000 | — | **FilthyRich ×2** + Rich + MedScrolls ×2 |
| **GreaterDragon** | 12 or 59 | Mage / Closest | 1025–1425 | 81–148 | 475–675 | **1000–2000** | 24–33 | 60 | 22000 | −15000 | 5 | FilthyRich ×4 + Gems ×8 |
| **PoisonElemental** | 162 | Mage / Closest | 426–515 | 166–185 | 361–435 | 256–309 | 12–18 | 70 | 12500 | −12500 | — | FilthyRich + Rich + MedScrolls |

Skills: OgreLord/ArcticOgreLord MagicResist 125.1–140, Tactics 90.1–100, Wrestling 90.1–100 · Daemon EvalInt 70.1–80, Magery 70.1–80, MagicResist 85.1–95, Tactics 70.1–80, Wrestling 60.1–80 · Dragon EvalInt 30.1–40, Magery 30.1–40, MagicResist 99.1–100, Tactics 97.6–100, Wrestling 90.1–92.5 · Nightmare EvalInt 10.4–50, Magery 10.4–50, MagicResist 85.3–100, Tactics 97.6–100, Wrestling 80.5–92.5 · WhiteWyrm EvalInt 99.1–100, Magery 99.1–100, MagicResist 99.1–100, Tactics 97.6–100, Wrestling 90.1–100 · ShadowWyrm EvalInt 80.1–100, Magery 80.1–100, Meditation 52.5–75, MagicResist 100.3–130, Tactics 97.6–100, Wrestling 97.6–100, DetectHidden 90–100, Necromancy 80–90, SpiritSpeak 100–105 · AncientWyrm EvalInt 80.1–100, Magery 80.1–100, Meditation 52.5–75, MagicResist 100.5–150, Tactics 97.6–100, Wrestling 97.6–100 · Balron **Anatomy 25.1–50, EvalInt 90.1–100, Magery 95.5–100, Meditation 25.1–50, MagicResist 100.5–150, Tactics 90.1–100, Wrestling 90.1–100** · GreaterDragon EvalInt **110–140**, Magery 110–140, MagicResist 110–140, Tactics 110–140, Wrestling 115–145 + `WeaponAbility.BleedAttack` · PoisonElemental EvalInt 80.1–95, Magery 80.1–95, Meditation 80.2–120, Poisoning 90.1–100, MagicResist 85.2–115, Tactics 80.1–100, Wrestling 70.1–90 【C】

**Taming:** Dragon 93.9 (3 slots) · Drake 84.3 (2) · Nightmare 95.1 (2) · WhiteWyrm 96.3 (3) · ShadowWyrm 105.0 (5) · GreaterDragon 104.7 (5). AncientWyrm, Balron, OgreLord, Titan, Cyclops, PoisonElemental are **not tameable**. 【C】

**Poison immunity:** Lich `Lethal` · Wraith/Spectre `Lethal` · DreadSpider `Lethal` · Balron `Deadly` · Wyvern `Deadly` · GiantSerpent `Greater` · Reaper `Greater` · Daemon `Regular` · AncientWyrm `Regular` · OgreLord/OgreLordArctic `Regular` · Titan `Regular`. 【C】

### 3.2 Critters (ambient + farm + huntable)

| Monster | Body | AI / FightMode | STR | DEX | INT | Hits | Damage | VA | Fame | Karma | Tamable (MinTameSkill) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Rabbit** | — | Animal | — | — | — | — | — | — | — | — | ✔ −18.9 |
| **JackRabbit** | — | — | — | — | — | — | — | — | — | — | ✔ −18.9 |
| **Bird** ("a crow") | 6 | Animal / Aggressor | 10 | 25–35 | 10 | — | 0 | 0–6 | 150 | 0 | ✔ −6.9 |
| **Cat** | — | Animal | — | — | — | — | — | — | — | — | ✔ −0.9 (Feline) |
| **Dog** | — | — | — | — | — | — | — | — | — | — | ✔ −21.3 (Canine) |
| **Cow** | — | — | — | — | — | — | — | — | — | — | ✔ 11.1 |
| **Pig** | — | — | — | — | — | — | — | — | — | — | ✔ 11.1 |
| **Sheep** | — | — | — | — | — | — | — | — | — | — | ✔ 11.1 (`ICarvable`) |
| **Goat** | — | — | — | — | — | — | — | — | — | — | ✔ 11.1 |
| **Chicken** | — | — | — | — | — | — | — | — | — | — | ✔ −0.9 |
| **Bull** | — | — | — | — | — | — | — | — | — | — | ✔ 71.1 (Bull) |
| **Boar** | — | — | — | — | — | — | — | — | — | — | ✔ 29.1 |
| **Hind** | — | — | — | — | — | — | — | — | — | — | ✔ 23.1 |
| **GreatHart** | — | — | — | — | — | — | — | — | — | — | ✔ 59.1 |
| **Horse** | 0xE2 / 0x3EA0 | Animal / Aggressor | 22–98 | 56–75 | 6–10 | 28–45 | 3–4 | — | 300 | **+300** | ✔ 29.1 (mount) |
| **PackHorse** | — | — | — | — | — | — | — | — | — | — | ✔ 29.1 |
| **PackLlama** | — | — | — | — | — | — | — | — | — | — | ✔ 29.1 |
| **Llama** | — | — | — | — | — | — | — | — | — | — | ✔ 35.1 |
| **RidableLlama** | 0xDC / 0x3EA6 | — | — | — | — | — | — | — | — | — | ✔ 29.1 (mount) |
| **ForestOstard** | 0xDB / 0x3EA5 | — | — | — | — | — | — | — | — | — | ✔ 29.1 (mount, Ostard) |
| **DesertOstard** | 0xD2 / 0x3EA3 | — | — | — | — | — | — | — | — | — | ✔ 29.1 (mount, Ostard) |
| **GiantRat** | — | — | — | — | — | — | — | — | — | — | ✔ 29.1 |
| **Rat** | 238 | Animal / Aggressor | 9 | 35 | 5 | 6 | 1–2 | 6 | 150 | −150 | ✔ −0.9 |
| **Squirrel** | — | — | — | — | — | — | — | — | — | — | ✔ −21.3 |
| **Ferret** | — | — | — | — | — | — | — | — | — | — | ✔ −21.3 |

**Horse details 【C】 `Scripts/Mobiles/Normal/Horse.cs`:** ctor `base(name, 0xE2, 0x3EA0, AIType.AI_Animal, FightMode.Aggressor, 10, 1, 0.2, 0.4)`; runtime `Body = m_IDs[random*2]; ItemID = m_IDs[random*2+1]` — i.e. **a random horse colour variant from a table**, not a fixed body. Skills: MagicResist 25.1–30, Tactics 29.3–44, Wrestling 29.3–44. `Fame = 300; Karma = +300; Tamable = true; ControlSlots = 1; MinTameSkill = 29.1`.

**Deer note:** classic UO "deer" = **Hind** (female, smaller) and **GreatHart** (male, antlers). There is no class literally named `Deer`. 【C】

**Wildlife spawn group observed in Felucca data 【D/X】:** `WildLife#60` at (559, 2081) spawns with `MX=3` each of: Boar, Cougar, Goat, Horse, Panther, Pig, Sheep, BlackBear, GrizzlyBear, BrownBear, TimberWolf, GreyWolf, WanderingHealer, Bird, Eagle, GreatHart, Hind, Bull, Cow. Similarly `TownsLife#13` (608,2195) = Bird, Cat, Dog, Rat; `TownsLife#15/16` = Chicken, Sheep, Cow.

### 3.3 Sea creatures

**【C】** `Scripts/Mobiles/Normal/*.cs`; spawn counts 【X】 from `Spawns/felucca.xml`.

| Monster | Body | AI / FightMode | STR | DEX | INT | Hits | Damage | VA | Fame | Karma | Felucca spawn points 【X】 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **SeaSerpent** | — | Melee / Closest | — | — | — | — | — | — | 5000 | −5000 | **115** |
| **DeepSeaSerpent** | — | — | — | — | — | — | — | — | — | — | (Lost Lands deep water) |
| **Kraken** | — | Mage / Closest | — | — | — | — | — | — | — | — | 10 |
| **WaterElemental** | 16 | Mage / Closest | 126–155 | 66–85 | 101–125 | 76–93 | 7–9 | 40 | 4500 | −4500 | (coastal; in Vesper box 【X】) |
| **Dolphin** | — | Animal | — | — | — | — | — | — | — | — | (ambient, Jhelom waters) |
| **CrystalSeaSerpent** | — | — | — | — | — | — | — | — | — | — | (SA) |

**SeaSerpent and Kraken are the two dominant water spawns on Felucca** — 115 + 10 spawn points, and `SeaLife#*` is a named spawner group of **115 points** 【X】. Water spawns only place on water tiles: `SpawnMobile.Init()` sets `m_Water = mob.CanSwim` and `m_Land = !mob.CantWalk`, then `RandomSpawnLocation(height, land, water)` picks a legal tile. 【C】 `Scripts/Regions/Spawning/SpawnDefinition.cs:188-196, 227-230`

**UNVERIFIED:** the full stat block for `SeaSerpent`, `Kraken`, `DeepSeaSerpent`, `Dolphin` — my extractor found the classes but the stat lines are in a constructor form my regex did not capture (they build stats in a helper). **To measure:** open `Scripts/Mobiles/Normal/SeaSerpent.cs`, `Kraken.cs`, `DeepSeaSerpent.cs`, `Dolphin.cs` directly and read the `SetStr/SetHits/SetDamage` block, or run the extractor with the constructor-body window widened past 220 lines.

### 3.4 Loot tables — the `LootPack` system

**【C】** `Scripts/Misc/LootPack.cs`.

An entry is `new LootPackEntry(<atSpawnTime>, <itemTable[]>, <chance %>, <minCount>, <maxCount>, <minIntensity>, <maxIntensity>)`. Gold uses **dice notation** (`"3d10+20"` = 3 rolls of 1–10, plus 20).

**Pre-AoS packs — use these for a classic clone** (`OldPoor` … `OldSuperBoss`):

| Pack | Gold | Magic-item rolls |
|---|---|---|
| `OldPoor` | `1d25` (1–25) | Instruments 0.02% ×1 |
| `OldMeager` | `5d10+25` (30–75) | Instruments 0.10% ×1; **OldMagicItems 1.00%** ×1 (intensity 0–60); OldMagicItems 0.20% ×1 (10–70) |
| `OldAverage` | `10d10+50` (60–150) | Instruments 0.40%; **OldMagicItems 5.00%** (20–80); 2.00% (30–90); 0.50% (40–100) |
| `OldRich` | `10d10+250` (260–350) | Instruments 1.00%; **OldMagicItems 20.00%** (60–100); 10.00% (65–100); 1.00% (70–100) |
| `OldFilthyRich` | `2d125+400` (402–650) | Instruments 2.00%; **OldMagicItems 33.00%** (50–100); 33.00% (60–100); 20.00% (70–100); 5.00% (80–100) |
| `OldUltraRich` | `5d100+500` (505–1000) | Instruments 2.00%; **6 × OldMagicItems 100%** at intensity floors 40/40/50/50/60/60 |
| `OldSuperBoss` | `5d100+500` | Instruments 2.00%; **10 × OldMagicItems 100%** at floors 40/40/40/50/50/50/60/60/60/70 |

`OldMagicItems` table 【C】: `BaseJewel` weight 1, `BaseArmor` weight 4, `BaseWeapon` weight 3, `BaseRanged` weight 1, `BaseShield` weight 1.

**Post-AoS packs (what ServUO actually runs by default)** — same structure, gold values differ:

| Pack | Gold | Notes |
|---|---|---|
| `AosPoor` | `1d10+10` | AosMagicItemsPoor 0.02% |
| `AosMeager` | `3d10+20` | MeagerType1 1.00%, Type2 0.20% |
| `AosAverage` | `5d10+50` | AverageType1 5.00% + 2.00%, Type2 0.50% |
| `AosRich` | `10d10+150` | RichType1 20.00% + 10.00%, Type2 1.00% |
| `AosFilthyRich` | `2d100+200` | FilthyRichType1 33% + 33%, Type2 20% + 5% |
| `AosUltraRich` | `5d100+500` | 5 × UltraRich 100% |
| `AosSuperBoss` | `5d100+500` | 11 × UltraRich 100% |

Selector 【C】 `LootPack.cs` `#region Generic accessors`: `Poor => Core.SE ? SePoor : Core.AOS ? AosPoor : OldPoor` (same pattern for Meager/Average/Rich/FilthyRich/UltraRich/SuperBoss).

**Utility packs** (rolled when a creature calls them explicitly): `LowScrolls`, `MedScrolls`, `HighScrolls` (one scroll, 100%), `Gems` (one gem, 100%), `Potions` (one of Agility/Strength/Refresh/LesserCure/LesserHeal/LesserPoison, 100%). Gems always resolve to specific gem types via `GemItems`. 【C】

**Clone guidance:** the classic-era behaviour is `Old*` packs + single Armor Rating (`VirtualArmor`). Gold is placed in the corpse container at spawn time (`atSpawnTime = true`); everything else rolls on corpse creation.

### 3.5 Special abilities reference

| Ability | Wired via 【C】 | Creatures observed with it |
|---|---|---|
| **DragonBreath** | `SetSpecialAbility(SpecialAbility.DragonBreath)` | Dragon, Drake, Nightmare, AncientWyrm, GreaterDragon, ShadowWyrm, WhiteWyrm |
| **Poisoning (HitPoison)** | `HitPoison` override + `MagicalAbility.Poisoning` | Slime (Lesser), Snake (Lesser), GiantSpider (Regular), Scorpion (Greater/Deadly 80/20), GiantSerpent (Greater/Deadly 80/20), DreadSpider (Lethal), PoisonElemental |
| **Spellcasting** | `AIType.AI_Mage` / `AI_NecroMage` + `SetSkill(Magery)` | Gazer, Gargoyle, Air/Fire/Water/Poison elemental, Wisp, Reaper, Lich, BoneMagi, Wraith, Spectre, Daemon, Balron, Dragon, AncientWyrm, GreaterDragon, ShadowWyrm, Imp, Efreet, Titan, DreadSpider |
| **Necromancy** | `AIType.AI_NecroMage` | Lich, BoneMagi, ShadowWyrm |
| **PackInstinct** | `PackInstinct` override | Canine (Dog, TimberWolf, GreyWolf, WhiteWolf, DireWolf, HellHound, IceHound) · Feline (Cat, Cougar, Panther, SnowLeopard, HellCat, PredatorHellCat) · Bear (Black/Brown/Grizzly/PolarBear) · Arachnid (GiantSpider, FrostSpider, WolfSpider, Scorpion, DreadSpider) · Ostard (3 ostard types) · Bull (Bull) · Daemon (Imp, FireSteed) |
| **WeaponAbility** | `SetWeaponAbility(WeaponAbility.X)` | GreaterDragon → `BleedAttack`; others per creature (post-AoS) |
| **Undead flag** | `Slayer` / `IsUndead` style checks | Skeleton, Zombie, Ghoul, Lich, BoneMagi, Wraith, Spectre, Mummy, Shade, SkeletalKnight |

**Taming difficulty** is a first-class column in §2.5 and repeated in §3.1–3.4 (`CS` + the taming tables). **Slayer type** (Undead, Reptile, Arachnid, Elemental, Demon, Fey, etc.) is derived from the creature's slayer group — **UNVERIFIED as an explicit enum in the files I read.** **To measure:** read `Scripts/Items/Equipment/Weapons/SlayerEntry.cs` / `BaseSlayer` and the `SlayerName` enum, then map each monster to its group.

### 3.6 Damage scaling (why `SetDamage` is only the base)

**【C】** `Scripts/Mobiles/Normal/BaseCreature.cs` — the AI melee damage is computed from the base damage range multiplied by a factor derived from **Strength, Anatomy, Tactics, Lumberjacking (for axes) and the weapon**. The classic pre-AoS formula (RunUO 2.x, still present in ServUO behind era gates) is approximately:

```
damage = baseDamage * (1 + 0.01 * (anatomy + tactics + strength-derived bonus) / 100)   // conceptual
```

**UNVERIFIED — exact coefficients.** The precise pre-AoS damage multiplier is implemented in `BaseCreature.GetBaseDamage` / `Mobile.Damage` with several era branches. **To measure:** read `Scripts/Mobiles/Normal/BaseCreature.cs` around the `GetBaseDamage`/`GetBonusDamage` methods and `Server/Mobile.cs` `Damage()`, then instrument a running ServUO with a debugger to log actual damage per monster.

---


## 4. Spawning model

### 4.1 The original (OSI) model

Original UO spawned the world from **spawner objects baked into the world data**, not from a per-region table. Three distinct mechanisms coexisted:

| Mechanism | What it is | Where it lives in the emulators |
|---|---|---|
| **World spawners** | Hand-placed `Spawner` items in the world save, each with a creature list, a home point, a home range and a max count. The GM command `[add spawner` creates one. | `Scripts/Services/Spawners/` (ServUO `XmlSpawner`), the `Spawns/*.xml` data files |
| **Region spawns** | Spawn entries attached to a named region, with a group name and a max count. | `Scripts/Regions/Spawning/*` + `Data/SpawnDefinitions.xml` |
| **Hard-coded vendor/town placements** | Town NPCs placed individually by the world build, not spawned. | `Data/Decoration/**/*.cfg` + the spawn XML `Vendors#*` entries |

The `Spawns/*.xml` files shipped in ServUO and RunUO are **exports of the OSI spawner layout**, which is why they are the best available witness to original spawn density.

### 4.2 The spawner data format (XmlSpawner)

**【D】** `servuo/Spawns/felucca.xml` — one `<Points>` element per spawner. 2 256 spawners on Felucca 【X】.

| Field | Meaning | Observed values 【X】 |
|---|---|---|
| `Name` | Spawner label | `Outdoors#n`, `Vendors#n`, `WildLife#n`, `SeaLife#n`, `TownsLife#n`, `TownsPeople#n`, `Spawner`, `Shame#n`, `Despise#n`, … |
| `Map` | Facet | `Felucca` |
| `X`, `Y`, `Width`, `Height` | **Spawn area rectangle** (top-left + size). This is the "area shape" — UO spawners are axis-aligned rectangles. | 1×1 to 100×100 |
| `CentreX`, `CentreY`, `CentreZ` | Home point of spawned creatures | |
| `Range` | Home range — how far a creature may wander from home before returning | |
| `MaxCount` | Max simultaneous live creatures from this spawner | **1** (553 spawners), 2 (265), 3 (243), 4 (177), 5 (174), 6 (82), 7 (99), 8 (83), … up to 25; a spike at **19** (181 spawners) from the named vendor/town batches |
| `MinDelay`, `MaxDelay` | Respawn delay range between individual spawns | **5–10** (1 922 spawners), 20–20 (222), 60–60 (81), 1–2 (8), 59–60 (4) |
| `DelayInSec` | Unit of `MinDelay`/`MaxDelay` | `False` on all 2 256 → **delays are in MINUTES** |
| `Duration`, `DespawnTime` | Lifetime of a spawn | `0` = permanent |
| `ProximityRange`, `ProximityTriggerSound`, `TriggerProbability` | Player-proximity triggering | `−1` / `500` / `1` |
| `TODStart`, `TODEnd`, `TODMode` | **Time-of-day window** | all `0-0 / mode 0` in this export → **no night-only spawns are configured in the shipped Felucca data** |
| `KillReset` | Reset counter when the spawner is emptied | `1` |
| `SequentialSpawning` | Spawn in list order vs random | `−1` = random |
| `AllowGhostTriggering`, `AllowNPCTriggering` | Who can trigger a proximity spawn | `False` |
| `SpawnOnTrigger`, `SmartSpawning`, `TickReset`, `ExternalTriggering` | Advanced modes | `False` |
| `Team` | Team identifier | `0` |
| `Amount`, `IsGroup` | Spawn N at a time / as a group | `1`, `False` |
| `IsRunning` | Active flag | `True` |
| `IsHomeRangeRelative` | `Range` is relative to centre | `True` |
| `Objects2` | **The creature list.** Colon-separated `<Type>:<KEY>=<val>:…`, with a new object starting at each `OBJ=<Type>`. Per-object key `MX=` is that object's max count. 11 keys total. | 9 907 object entries across the file 【X】 |

**Decoding `Objects2` — worked example** 【D】:
```
Chicken:MX=3:SB=0:RT=0:TO=0:KL=0:RK=0:CA=1:DN=-1:DX=-1:SP=1:PR=-1
:OBJ=Sheep:MX=3:…:PR=-1
:OBJ=Cow:MX=3:…:PR=-1
```
= 3 spawn slots shared between Chicken, Sheep and Cow, max 3 of each.

### 4.3 The region-spawn model (a cleaner fit for a single-player clone)

**【C】** `Scripts/Regions/Spawning/`.

| Class / file | Role |
|---|---|
| `SpawnDefinition` | Abstract "what to spawn". Parsed from XML: `object` (a `Mobile` or `Item` type), `group` (a named `SpawnGroup`), or `treasureChest` (itemID + `TreasureLevel`). |
| `SpawnType` → `SpawnMobile` / `SpawnItem` | Resolves the type, computes `Height`/`Land`/`Water` capabilities by instantiating one and inspecting `CantWalk`/`CanSwim`, then `Construct()`s and `MoveToWorld`s at `entry.RandomSpawnLocation(...)`. |
| `SpawnGroup` | Weighted list of `SpawnGroupElement { SpawnDefinition, Weight }`. `Spawn()` picks by weight via `Utility.Random(totalWeight)`. Loaded from `Data/SpawnDefinitions.xml`. |
| `SpawnEntry` | The runtime spawner: home point, range, definition, **max count**, `MinSpawnTime`, `MaxSpawnTime`, next-spawn timestamp, spawned-object list. |
| `SpawnPersistence` | Serialises active `SpawnEntry` state. |

**Verified constants and behaviour 【C】 `Scripts/Regions/Spawning/SpawnEntry.cs`:**

| Item | Value | Line |
|---|---|---|
| `DefaultMinSpawnTime` | **2 minutes** | 12 |
| `DefaultMaxSpawnTime` | **5 minutes** | 13 |
| `ReturnOnDeactivate` | `true` — creatures return home when their AI deactivates (no player near) | 58-62 |
| `UnlinkOnTaming` | `false` — tamed creatures stay linked to the spawner unless they leave the region | 66-72 |
| `RemoveIfUntamed` | `true` — **unlinked, untamed creatures are deleted after 20 hours** | 74-80 |
| `Complete` | `SpawnedObjects.Count >= Max` | 158-164 |
| `Spawning` | `Running && !Complete` | 165-171 |
| **Refill rate** | `int amount = Math.Max((Max - SpawnedObjects.Count) / 3, 1);` then spawn that many → **the spawner refills one-third of its deficit per tick, minimum 1** | 536 |
| **Tick delay** | `RandomTime()` = `Utility.RandomMinMax(minSeconds, maxSeconds)` seconds between ticks | 507-514 |
| `Respawn()` | Deletes all spawned objects then spawns up to `Max` **immediately** | 258-267 |

**`Data/SpawnDefinitions.xml` (RunUO 2.x, complete file — 22 lines)** 【D】:

| Group name | Members |
|---|---|
| `Escortables` | `EscortableMage`, `Noble`, `SeekerOfAdventure` |
| `TownAnimals` | `Cat`, `Dog` |
| `Reagents` | `BlackPearl`, `Bloodmoss`, `Garlic`, `Ginseng`, `MandrakeRoot`, `Nightshade`, `SulfurousAsh`, `SpidersSilk` |

That is the **entire** shipped region-spawn definition set. All the real density lives in `Spawns/*.xml`.

### 4.4 Observed Felucca spawn dataset (the numbers to match)

**【X】** all derived from `servuo/Spawns/felucca.xml` (2 256 spawners / 9 907 objects / 421 distinct object types).

**Named functional groups by spawner count:**

| Group | Spawners | What it covers |
|---|---:|---|
| `Outdoors#*` | 431 | Open-world surface spawn |
| `Vendors#*` | 308 | **Town shops and services** (this is how the §1.5 matrix was derived) |
| `WildLife#*` | 180 | Ambient animals |
| `LostLands#*` | 167 | T2A continent |
| `Spawner` (unnamed) | 124 | Named/unique NPCs |
| `SeaLife#*` | 115 | **Water spawn — sea serpents, krakens, dolphins** |
| `Shame#*` | 114 | Shame dungeon |
| `Hythloth#*` | 81 | Hythloth dungeon |
| `TownsLife#*` | 56 | Chickens/sheep/cows/cats/dogs inside towns |
| `Fire#*` | 50 | Fire Dungeon |
| `TownsPeople#*` | 47 | Escortables and townsfolk |
| `Covetous#*` | 47 | Covetous dungeon |
| `Khaldun#*` | 47 | Khaldun |
| `Despise#*` | 38 | Despise |
| `Deceit#*` | 36 | Deceit |
| `Ice#*` | 34 | Ice Dungeon |
| `TerathanKeep#*` | 34 | Terathan Keep |
| `Destard#*` | 28 | Destard |
| `PrismOfLight#*` | 21 | Prism of Light |
| `BritainSewer#*` | 21 | Britain sewers |
| `PalaceOfParoxysmus#*` | 20 | Palace of Paroxysmus |
| `OrcCaves#*` | 19 | Orc Cave |
| `BlightedGrove#*` | 10 | Blighted Grove |
| `Wrong#*` | 9 | Wrong |
| `Graveyards#*` | 8 | Graveyards |
| `Sanctuary#*` | 8 | Sanctuary |
| `TrinsicPassage#*` | 6 | Trinsic passage |

**Top 25 creature types by number of spawn points 【X】** (this is the empirical "what fills the world" ranking):

| Rank | Creature | Spawners | Rank | Creature | Spawners |
|---:|---|---:|---:|---|---:|
| 1 | boar | 178 | 14 | treasurelevel4 | 30 |
| 2 | **seaserpent** | **115** | 15 | hind | 28 |
| 3 | ettin | 110 | 16 | tailor | 26 |
| 4 | airelemental | 76 | 17 | ghoul | 26 |
| 5 | treasurelevel2 | 64 | 18 | mage | 25 |
| 6 | treasurelevel3 | 61 | 19 | rat | 25 |
| 7 | corpser | 58 | 20 | earthelemental | 24 |
| 8 | bird | 35 | 21 | evilhealer | 24 |
| 9 | treasurelevel1 | 34 | 22 | tavernkeeper | 23 |
| 10 | orc | 32 | 23 | innkeeper | 22 |
| 11 | gazer | 32 | 24 | imp | 22 |
| 12 | brownbear | 31 | 25 | fisherman | 20 |
| 13 | alligator | 31 | | | |

**Cross-facet totals 【X】:**

| Facet | Spawners | Distinct object types |
|---|---:|---:|
| Felucca | 2 256 | 421 |
| Trammel | 2 572 | 520 |
| Ilshenar | 472 | 190 |
| Malas | 293 | 184 |
| Tokuno | 476 | 117 |
| TerMur | 124 | 116 |

### 4.5 The "no spawn in town" rule

**【C】** Towns are `GuardedRegion` subclasses:

```
public class TownRegion : GuardedRegion      // Scripts/Regions/TownRegion.cs:10
public class GuardedRegion : BaseRegion      // Scripts/Regions/GuardedRegion.cs:12
```

Rules that follow:

| Rule | Mechanism |
|---|---|
| **Hostile spawns are placed outside town rects** | Verified empirically: the §1.5 analysis shows town rects contain **only** vendors, escortables, guards and passive animals — no hostile monsters, except where my boxes were padded (bears in Moonglow/Yew) 【X】 |
| **Guards respond inside town** | `GuardedRegion.OnSpeech` — the keyword `*guards*` (keyword id `0x0007`) triggers `CallGuards(args.Mobile.Location)` 【C】 `GuardedRegion.cs:183-194` |
| **Reds are auto-reported** | `if (!AllowReds && m.Murderer) CheckGuardCandidate(m);` — a murderer entering the region becomes a guard candidate 【C】 `GuardedRegion.cs:169-171` |
| **Guards are instantiated on demand** | `MakeGuard(Mobile focus)` reuses an existing `BaseGuard` in the region, else `Activator.CreateInstance(m_GuardType, focus)` with the focus passed as ctor arg 【C】 `GuardedRegion.cs:124-158` |
| **Default guard type** | `DefaultGuardType` → `ArcherGuard` or `WarriorGuard` depending on the region 【C】 `GuardedRegion.cs:65-71` |
| **Killing an innocent flags you** | `AggressiveAction(aggressor, criminal)` on the victim; the criminal flag expires after **2 minutes** (`m_ExpireCriminalDelay = TimeSpan.FromMinutes(2.0)`) 【C】 `Server/Mobile.cs:2102, 2106` |
| **5 kills = murderer** | `public virtual bool Murderer { get { return m_Kills >= 5; } }` 【C】 `Server/Mobile.cs:11849` |
| **Guarded regions can be toggled** | `[CheckGuarded`, `[SetGuarded`, `[ToggleGuarded` GM commands 【C】 `GuardedRegion.cs:82-84` |
| **No housing in town** | `NoHousingRegion` type + `Regions.xml` entries (e.g. Britain Graveyard, Jhelom Islands, Haven Island) 【D】 |

**Notoriety constants 【C】** `Server/Notoriety.cs`:

| Name | Value | Hue |
|---|---:|---|
| `Innocent` | 1 | 0x059 |
| `Ally` | 2 | 0x03F |
| `CanBeAttacked` | 3 | 0x3B2 |
| `Criminal` | 4 | 0x3B2 |
| `Enemy` | 5 | 0x090 |
| `Murderer` | 6 | 0x022 |
| `Invulnerable` | 7 | 0x035 |

### 4.6 Dungeon level scaling

There is **no automatic level-scaling system in UO or in the emulators.** Difficulty gradient is achieved entirely by **hand-placed spawners with different creature lists per level.**

Evidence from the data 【X/D】:
- `Shame#*` has **114 spawners**, and its 4 levels sit at 5395,126 / 5515,11 / 5514,148 / 5875,20. Shame's creatures are earth/air/fire/water elementals, gargoyles, ogre lords and dragons — an explicit tier ladder by hand.
- `Despise#*` (38 spawners) covers lizardmen/ettins/ogres/trolls on L1–L3.
- `Destard#*` (28 spawners) is dragons/drakes/wyverns only.
- The 100×100 `LostLands#60` spawner at (5972,3921) with `MaxCount = 5`, `Range = 50` is typical of outdoor "wide area, low count" placement, versus dungeon spawners which are small rects with `MaxCount` 1–5.

**For a clone:** define a per-dungeon-level spawn table (§4.8) rather than trying to infer a formula. The original has no formula.

### 4.7 What a faithful single-player implementation should do instead

A live `SpawnEntry` timer per spawner is wasteful offline (the player is always "present"). Recommended model — **region-based spawn table with a resident budget**:

| Concern | Original | Recommended single-player |
|---|---|---|
| Spawner object per creature | 2 256 objects on Felucca | **None.** A static table: `{regionId, rect, spawnGroupId, maxCount, homeRange, respawnSec}` |
| Timer model | One `Timer` per spawner, ticking every 2–5 min | **One world tick** (e.g. every 10 s). For each region, if `liveCount < maxCount` and `now >= nextSpawnAt`, spawn `ceil(deficit/3)` (keep the original 1/3 refill rule) and set `nextSpawnAt = now + rand(minDelay, maxDelay)` |
| Proximity / AI sleep | `PlayerRangeSensitive` deactivates distant AI | Keep it. **Freeze timers for regions farther than N tiles from the player** and fast-forward them on approach: catch up with `while (nextSpawnAt < now) { spawn batch; nextSpawnAt += delay }` capped at `maxCount` |
| Max count | Per spawner | Per region × group |
| Night-only spawns | `TODStart/TODEnd/TODMode` fields (unused in the shipped data) | Implement the **field**, leave it 0 for parity; use it only if you want the feature |
| Persistence | `SpawnPersistence` serialises every live spawner | Serialise only `{regionId, liveEntityIds, nextSpawnAt}` |
| Guards | Instantiated on demand | Same — spawn a guard at the crime location, despatch it, delete after |
| Vendors | Placed by spawn entry, restock every 60 min | **Place statically in the world file**; restock on a 60-minute world clock (or on first interaction after 60 min, which is what `VendorBuy` does — `BaseVendor.cs:920-923`) |
| Escortables | Spawned, wander, despawn | Same, but tie the 5-minute `m_EscortDelay` and the 30-second delete timer to the world clock |
| Uncollected untamed spawns | Deleted after 20 h | Skip — single player never accumulates that |
| Performance | ~4 000 spawners × timer | One tick loop over ~1 500 region rows |

### 4.8 Spawn tables per environment

Built to mirror the observed densities in §4.4. **Weights are my design choice 【X】 calibrated to the observed frequency ranking; the *creature membership* per environment is evidence-based.**

**Design rules**
- Town/wilderness budget: max 3–6 hostiles per 100×100 region; respawn 5–10 min (matches the dominant `5-10` delay).
- Dungeon level 1: max 4–8 per level; level N+1: −1 max but +1 tier.
- Always leave a "safe corridor": no spawn within 8 tiles of a town gate, dungeon entrance or moongate.

#### A. Town interior / town wilderness fringe

| Group | Members (weight) | Max | Respawn |
|---|---|---|---|
| `TownAnimals` | Cat (1), Dog (1) | 2 | 10 min |
| `TownsLife` | Chicken (1), Sheep (1), Cow (1) | 3 | 10 min |
| `TownsPeople` | EscortableMage (1), Noble (1), SeekerOfAdventure (1) | 3 | 5 min |
| `TownFringeHostile` (outside the guard rect) | Rat (3), Mongbat (2), Slime (1) | 2 | 8 min |

#### B. Forest / grassland (the `Outdoors` + `WildLife` groups)

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 30 | Boar | 4 | BrownBear |
| 24 | Hind | 3 | BlackBear |
| 22 | GreatHart | 3 | GrizzlyBear |
| 18 | Bird | 6 | TimberWolf |
| 10 | Eagle | 4 | GreyWolf |
| 14 | Cougar | 3 | Panther |
| 12 | Alligator (water edge only) | 8 | Ettin |
| 8 | Orc | 8 | Gazer |
| 6 | AirElemental | 10 | Corpser |

Max 4 hostiles per region; respawn 5–10 min.

#### C. Desert (Nujel'm, Papua outskirts, Lost Lands dunes)

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 20 | Scorpion | 12 | GiantSerpent |
| 16 | Snake | 8 | Lizardman |
| 14 | Rat | 8 | Ettin |
| 12 | Bird | 6 | Ogre |

#### D. Swamp (Vesper marsh, Papua, Delucia)

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 18 | Alligator | 10 | Lizardman |
| 16 | GiantSerpent | 10 | Troll |
| 14 | Slime | 8 | BogThing |
| 12 | Rat | 6 | Corpser |
| 12 | Snake | 4 | Ogre |

#### E. Snow / ice (Ice Isle, Ice Dungeon surface, northern mountains)

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 20 | FrostSpider | 12 | PolarBear |
| 18 | WhiteWolf | 10 | SnowLeopard |
| 16 | IceHound | 8 | ArcticOgreLord |
| 14 | GiantIceWorm | 6 | IceSerpent |
| 12 | MountainGoat | 4 | WhiteWyrm |

#### F. Graveyard

| Weight | Creature | Max | Note |
|---:|---|---:|---|
| 30 | Skeleton | 4 | |
| 24 | Zombie | 4 | |
| 18 | Ghoul | 3 | |
| 12 | Wraith | 2 | |
| 10 | Spectre | 2 | |
| 6 | BoneMagi | 1 | |
| 4 | Lich | 1 | night / deep graveyard only |

Respawn 6–12 min. 8 `Graveyards#*` spawners exist on Felucca 【X】.

#### G. Cave level 1 (generic)

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 24 | Rat | 10 | Skeleton |
| 20 | SewerRat | 8 | Zombie |
| 18 | GiantSpider | 8 | Lizardman |
| 14 | Bat/Mongbat | 6 | HeadlessOne |
| 12 | Slime | 4 | EarthElemental |

Max 5; respawn 5–10 min.

#### H. Cave level 2

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 18 | Skeleton | 10 | Ghoul |
| 16 | Zombie | 8 | EarthElemental |
| 14 | GiantSpider | 8 | Gargoyle |
| 12 | Lizardman | 6 | Troll |
| 12 | Orc | 4 | Ogre |

#### I. Cave level 3+

| Weight | Creature | Weight | Creature |
|---:|---|---:|---|
| 16 | Troll | 8 | Lich |
| 14 | Ogre | 8 | Daemon |
| 12 | Gargoyle | 6 | DreadSpider |
| 12 | Gazer | 6 | OgreLord |
| 10 | EarthElemental | 4 | Dragon |
| 10 | FireElemental | 4 | Balron (deepest only) |

#### J. Dungeon-specific (match the original exactly)

| Dungeon | Level 1 | Level 2 | Level 3 | Level 4 |
|---|---|---|---|---|
| **Covetous** | Harpy, EarthElemental, Gargoyle | Ogre, AirElemental, WaterElemental (Lake Cave) | Troll, Lich, DreadSpider | — |
| **Deceit** | Skeleton, Zombie, Ghoul | BoneMagi, Wraith, Spectre | Lich, Gargoyle, EarthElemental | Lich, Daemon |
| **Despise** | Lizardman, Ettin, Orc | Ogre, Troll, EarthElemental | OgreLord, Troll, Gargoyle | — |
| **Destard** | Drake, Wyvern, Harpy | Dragon, Drake | Dragon, AncientWyrm | — |
| **Hythloth** | Imp, Gargoyle, Daemon | Daemon, Dragon | Balron, Daemon | Balron, Dragon |
| **Shame** | EarthElemental, AirElemental | FireElemental, WaterElemental, Gargoyle | OgreLord, Dragon, Titan | OgreLord, Balron, AncientWyrm |
| **Wrong** | Ogre, Ettin, Lizardman | OgreLord, Troll | OgreLord, Daemon | — |
| **Terathan Keep** | TerathanWarrior, TerathanDrone | TerathanAvenger, TerathanMatriarch, Ophidian | Champion room: TerathanMatriarch ×N | — |
| **Fire** | FireElemental, Efreet, FireSteed | Daemon, Dragon, FireElemental | — | — |
| **Ice** | FrostSpider, IceHound, IceSerpent | PolarBear, WhiteWyrm, IceFiend; Ratman Room = Ratman; Ice Demon Lair = IceFiend | — | — |
| **Orc Cave** | Orc, OrcCaptain | OrcBomber, OrcMage, EvilMage | OrcCaptain, EvilMage | — |
| **Khaldun** | KhaldunZealot, Skeleton, Mummy, Lich | — | — | — |

**【X】 designed tables** — creature membership is evidence-based (§4.4, §3); weights and counts are recommended defaults, not original values.

---


## 5. Trade and services

### 5.1 The vendor buy/sell gump flow

**【C】** `Scripts/Mobiles/NPCs/BaseVendor.cs`, `Scripts/VendorInfo/GenericBuy.cs`, `GenericSell.cs`.

**Two entry points.** Double-clicking a vendor opens a context menu; the two shop actions are *Buy* (player buys from vendor) and *Sell* (player sells to vendor). `BaseVendor.VendorBuy(from)` and `BaseVendor.VendorSell(from)` run the respective flows.

**Buy flow (`VendorBuy`) — step by step 【C】 `BaseVendor.cs:902-1010`:**

1. Abort if `!IsActiveSeller`, or the player is dead, or `!CheckVendorAccess(from)` → the vendor says **501522** *"I shall not treat with scum like thee!"* (this is the criminal/murderer check).
2. **Restock-on-access:** `if (DateTime.UtcNow - m_LastRestock > RestockDelay) Restock();` — the shop restocks lazily the first time it is opened after 60 minutes.
3. `UpdateBuyInfo()` — recompute the merged buy list from all `SBInfos`.
4. Build a `List<BuyItemState>`; for each `IBuyItemInfo`:
   - skip if `Amount <= 0`;
   - **hard cap: `list.Count >= 250` → stop** (the gump is 250 rows maximum);
   - cast to `GenericBuyInfo` (the comment notes only GBI is supported);
   - `gbi.GetDisplayEntity()` supplies the display item for the gump icon.
5. Serialize the list into the buy gump packet. Each row shows item name, hue, price and amount.
6. On the player's selection the server verifies gold, removes the gold, and drops the item into `BuyPack` (the vendor's stock container) → player's backpack.

**Sell flow (`VendorSell`) 【C】 `BaseVendor.cs:1140-1180, 1650-1700, 2200-2210`:**

1. Abort if `!IsActiveBuyer` (on a siege shard vendors never buy).
2. Iterate the player's backpack items. For each, ask every `IShopSellInfo` `ssi.IsSellable(item)`.
3. Build a table `table[item] = new SellItemState(item, ssi.GetSellPriceFor(item, this), ssi.GetNameFor(item))`.
4. Show the sell gump with per-item quantities; the player confirms a total.
5. On confirm, for each lot: `var singlePrice = ssi.GetSellPriceFor(resp.Item, this); GiveGold += singlePrice * amount;` then gold is dropped to the player and the items removed.
6. **Fame reward:** `Titles.AwardFame(from, ssi.GetSellPriceFor(dropped, this) * dropped.Amount, true);` — selling improves Fame.

**Drag-and-drop shortcut.** A player may drop an item directly on a vendor. Handling 【C】 `BaseVendor.cs:1330-1351`:
- If the item is `Gold` → the vendor says **501548** *"I thank thee."* and awards `Titles.AwardFame(from, dropped.Amount / 100, true)`.
- Else if any `ssi.IsSellable(dropped)` → same thank-you and `AwardFame(from, ssi.GetSellPriceFor(dropped, this) * dropped.Amount, true)`.
- Else → **501550** *"I am not interested in this."*

**The vendor's stock container.** `BaseVendor.BuyPack` 【C】 `BaseVendor.cs:365-390` is a `Container` attached to the vendor; bought-from-player items and restocked goods live there. `BuyPack` is excluded from most item interactions (`item != BuyPack && item.IsChildOf(BuyPack)` at line 1652).

**Item visibility rules 【C】:** a vendor can only be interacted with if `CheckVendorAccess` passes; `IsInvulnerable = true` means vendors cannot be killed or looted; `BardImmune = true`; `PlayerRangeSensitive = true`.

### 5.2 How the price is computed

**【C】** `Scripts/VendorInfo/GenericSell.cs` — this is the authoritative formula.

**Sell price (what the vendor pays the player)** — `GetSellPriceFor(item, vendor)`:

| Step | Rule | Line |
|---|---|---|
| 1 | Look up the **table price** by exact item type: `m_Table.TryGetValue(item.GetType(), out price)`. If the type is absent, `price = 0` and the item is not sellable (`IsInList` fails first). | 42-43, 161-164 |
| 2 | **Economy override (AoS only, `UseVendorEconomy`):** if the vendor stocks this item as an economy item, `price = (int)(buyInfo.Price * 0.75)` and return `Math.Max(1, price)`. | 45-56 |
| 3 | **BaseArmor:** `Quality == Low` → `price *= 0.60`; `Quality == Exceptional` → `price *= 1.25`; then `price += 100 * (int)armor.Durability; price += 100 * (int)armor.ProtectionLevel;` floor at 1. | 58-73 |
| 4 | **BaseWeapon:** `Quality == Low` → `*= 0.60`; `Exceptional` → `*= 1.25`; then `price += 100 * (int)weapon.DurabilityLevel; price += 100 * (int)weapon.DamageLevel;` floor at 1. | 74-89 |
| 5 | **BaseBeverage:** fixed by container — `Pitcher` 3/5, `BeverageBottle` 3/3, `Jug` 6/6; empty or milk → the first value, else the second. | 90-116 |

**Buy price (what the player pays)** — `GetBuyPriceFor(item, vendor)`:

```csharp
return (int)(1.90 * GetSellPriceFor(item, vendor));
```
**【C】 `GenericSell.cs:126-129`.** So the **vendor's buy/sell spread is a flat ×1.90 multiplier**, applied to the same table price that the vendor pays. **This is the single most important number in the whole trade system.**

**Where the table price comes from.** It is **not** derived from `tiledata` at runtime — each vendor's `SellInfo` hard-codes it: `Add(typeof(IronIngot), 5)`. 【C】 e.g. `Scripts/VendorInfo/SBBlacksmith.cs`. The `GenericBuyInfo(type, price, amount, itemID, hue)` price is a **separate, independent** retail price; in practice `buyInfo.Price ≈ 1.90 × sellPrice` for most entries, but they are authored separately and are not computed from each other.

**Quantity discounts.** **None.** `cost = (double)bii.Price * amount` (line 1508) and `cost = (double)ssi.GetBuyPriceFor(item, this) * amount` (line 1670) are strictly linear. 【C】

**Price fluctuation over time.** **None in the classic model.** Prices are static table lookups. The only dynamic system is the AoS *vendor economy* (`UseVendorEconomy = Core.AOS && !Siege.SiegeShard`), where:
- `TotalSold` is tracked per economy item;
- the sell price is pinned to `0.75 × buyInfo.Price` rather than the table;
- `EconomyStockAmount = 500`, `BuyItemChange = 1000`, `SellItemChange = 1000` are tunables.
**【C】 `BaseVendor.cs:33-38`, `GenericSell.cs:45-56`.**

**Haggling.** **Not present in the classic model.** ServUO has a **BOD bribe** system that looks like haggling but only affects bulk-order deeds, not prices:

| Mechanic | Rule | Line |
|---|---|---|
| `TryBribe(m)` | Vendor offers to swap a bulk order deed for a better one for a gold fee | 1380-1433 |
| Fee | `BulkOrderSystem.GetBribe(bod) * BribeMultiplier` | 1407-1408 |
| Watch mechanic | After `RecentBribes >= 3`, `Utility.Random(6) < RecentBribes` → vendor is "under watch" for **120–180 minutes** and refuses further bribes | 1441-1444 |
| `BribeMultiplier` decay | `NextMultiplierDecay = UtcNow + RandomMinMax(25, 30) days` | 1371-1378 |

**【C】** — this is Mondain's Legacy content, not classic. **For the clone: omit.**

**Honesty virtue discount.** `HasHonestyDiscount => true` on `BaseVendor` 【C】 `BaseVendor.cs:65` — the Honesty virtue reduces prices. The magnitude is **UNVERIFIED**. **To measure:** read the Honesty virtue implementation in `Scripts/Services/Virtues/Honesty.cs`.

### 5.3 Gold handling and the bank

**【C】** `Scripts/Mobiles/NPCs/Banker.cs`, `Server/Items/Containers.cs` (`BankBox`).

| Feature | Rule | Source |
|---|---|---|
| Gold as an item | `Gold` is a stackable `Item`; a `BankCheck` is an item with a `Worth` value | `Banker.cs:52-56, 82-86` |
| Balance | `GetBalance(m)` sums `Gold.Amount` over all `Gold` items **and** `BankCheck.Worth` over all checks inside the player's bank box. Clamped to `[0, Int32.MaxValue]` | `Banker.cs:33-59` |
| `AccountGold` mode | If `AccountGold.Enabled` and the player has an account, the balance comes from `m.Account.GetGoldBalance(out stub, out balance)` instead — a currency abstraction added in later eras | `Banker.cs:37-42, 66-69` |
| Withdraw | `Banker.Withdraw(from, amount)` — consumes from the bank box | `Banker.cs:96+` |
| Deposit | `Banker.Deposit(...)` — moves gold from backpack to bank box | `Banker.cs` |
| **Bank box type** | `public class BankBox : Container`, ctor `: base(0xE7C)` — **item id 0xE7C** | `Server/Items/Containers.cs:10, 29` |
| Virtual | `IsVirtualItem => true` — the box is not a real world item | line 22 |
| Weight limit | `DefaultMaxWeight => 0` — **no weight limit** (0 = unlimited in `Container`) | line 20 |
| Access | `IsAccessibleTo(check)`: only `check == m_Owner && m_Open`, or GM+ | lines 81-86 |
| Drag/drop | `OnDragDrop` / `OnDragDropInto` both require `from == m_Owner && m_Open` (or GM+) | lines 91-109 |
| Open/close | `Open()` sets `m_Open = true`; `m_Open` gates all access | lines 18, 41-62 |
| Diagnostics | `ToString()` → `"Bank container has {TotalItems} items, {TotalWeight} stones"` | line 51 |
| Death | `OnParentDeath` returns a `DeathMoveResult` — **bank contents are never dropped on death** | line 76 |
| Banker sells | `SBBanker` stocks `ContractOfEmployment` (1252 gp), `VendorRentalContract` (1252 gp), `CommissionContractOfEmployment` (28127 gp), `CommodityDeed` (5 gp) | `SB banker` table |

**Gold stack limits 【UNVERIFIED】.** The maximum gold per stack / per bank box was not read out of the code. **To measure:** read `Scripts/Items/Consumables/Gold.cs` for the stack cap and `_NoItemCountTable`-style limits in `BaseHouse.cs:372-377`.

### 5.4 Stabling

**【C】** `Scripts/Mobiles/NPCs/AnimalTrainer.cs`.

| Rule | Value | Line |
|---|---|---|
| **Cost** | **30 gold per pet per real week** — `from.Backpack.GetAmount(typeof(Gold)) < 30 && Banker.GetBalance(from) < 30` → *"Thou dost not have enough gold, not even in thy bank account."* (1042556) | 281-288 |
| Payment | Paid from the backpack **or** the bank: `from.Backpack.ConsumeTotal(typeof(Gold), 30) \|\| Banker.Withdraw(from, 30)` | 341 |
| Charge text | The vendor's own line: *"I charge 30 gold per pet for a real week's stable time."* | 288 |
| Cannot stable | Summoned creatures (502673), non-owned pets (1042562), living-only (1049668), "you can't stable that" (1048053), pet is busy (1042564), too many in stables (1042565) | 297-339 |
| Claim | `BeginClaimList` opens a `ClaimListGump` listing `from.Stabled`; `ClaimAllEntry` for bulk; `EndClaimList` returns the pet and clears `IsStabled`/`StabledBy`. A pet that would exceed the follower limit stays stabled with message 1049612 | 206-270, 428 |

**Maximum stabled pets — `GetMaxStabled(from)` 【C】 `AnimalTrainer.cs:146-199`:**

```
sklsum = AnimalTaming + AnimalLore + Veterinary
max  = RewardStableSlots (PlayerMobile bonus, default 0)
     + (sklsum >= 240 ? 5 : sklsum >= 200 ? 4 : sklsum >= 160 ? 3 : 2)
     + (Core.SA  ? 2 : 0)        // Stygian Abyss bonus
     + (Core.TOL ? 2 : 0)        // Time of Legends bonus
     + (taming >= 100 ? (int)((taming - 90) / 10) : 0)
     + (anlore >= 100 ? (int)((anlore - 90) / 10) : 0)
     + (vetern >= 100 ? (int)((vetern - 90) / 10) : 0)
     + MasteryInfo.BoardingSlotIncrease(from)
```

**Classic-era result:** `2` base, rising to `5` at 240 total tame skills. The SA/ToL/mastery terms are era additions — a classic clone should use only the `sklsum` ladder. This is the same ladder that governs the **live follower limit**.

### 5.5 House placement rules and costs

#### Placement validity — `HousePlacement.Check(from, multiID, center, out toMove)`

**【C】** `Scripts/Multis/HousePlacement.cs`. Result codes include `BadStatic`. The stated rules (file comments, lines 91-95):

> 1) All tiles which are around the **outside** of the foundation must not have anything impassable.
> 2) *(rule 2 returns `BadStatic`)* — no static may occupy the same space.
> 3) …
> 4) **The foundation must rest flatly on a surface.** Any bumps around the foundation are not allowed.
> 5) **No foundation tile may reside over terrain which is viewed as a road.**

| Rule constant | Value | Line |
|---|---|---|
| `YardSize` | **5** | 41 |
| Malas exception | `if (map == Map.Malas && (multiID == 0x007C \|\| multiID == 0x007E))` — **Keeps and Castles cannot be placed in Malas** (0x7C = Keep, 0x7E = Castle) | 58 |
| AoS stairs | `if (multiID >= 0x13EC && multiID < 0x1D00) HouseFoundation.AddStairsTo(ref mcl);` | 76-77 |
| Foundation detection | `isFoundation = (addTile.Z == 0 && (addTileFlags & TileFlag.Wall) != 0)` | 170 |
| `RoadIDs` (non-placeable land tiles) | `0x0071–0x0078`, `0x00E8–0x00EB`, `0x07AE–0x07B1`, `0x3FF4–0x3FFB`, `0x0442–0x0479` (sand stones), `0x0501–0x0510` (sand stones), `0x0009–0x0015` (furrows), `0x0150–0x015C` (furrows) | 29-39 |

**No-housing zones** are `NoHousingRegion` entries in `Data/Regions.xml` — e.g. Britain Graveyard (1333,1441 82×82), Jhelom Islands, Haven Island (3314,2345 750×750), Wrong Entrance, Covetous Entrance, Despise Entrance, Crystal Cave Entrance, Protected Island (Malas), Grand Arena. 【D】

#### Classic house table — cost, storage, lockdowns, vendors

**【C】** `Scripts/Multis/HousePlacementTool.cs:355-376` (`m_ClassicHouses`). Ctor signature:
`HousePlacementEntry(Type type, int description, int storage, int lockdowns, int newStorage, int newLockdowns, int vendors, int cost, int xOffset, int yOffset, int zOffset, int multiID)`
**Cost is doubled on a siege shard** (`m_Cost = Siege.SiegeShard ? cost * 2 : cost`).

| House | description | pre-AoS storage | pre-AoS lockdowns | AoS storage | AoS lockdowns | vendors | **cost (gp)** | xOff | yOff | multiID |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| SmallOldHouse (style 1) | 1011303 | 425 | 212 | 489 | 244 | 10 | **36,750** | 0 | 4 | 0x0064 |
| SmallOldHouse (2) | 1011304 | 425 | 212 | 489 | 244 | 10 | **36,750** | 0 | 4 | 0x0066 |
| SmallOldHouse (3) | 1011305 | 425 | 212 | 489 | 244 | 10 | **36,500** | 0 | 4 | 0x0068 |
| SmallOldHouse (4) | 1011306 | 425 | 212 | 489 | 244 | 10 | **35,000** | 0 | 4 | 0x006A |
| SmallOldHouse (5) | 1011307 | 425 | 212 | 489 | 244 | 10 | **36,500** | 0 | 4 | 0x006C |
| SmallOldHouse (6) | 1011308 | 425 | 212 | 489 | 244 | 10 | **36,500** | 0 | 4 | 0x006E |
| SmallShop (1) | 1011321 | 425 | 212 | 489 | 244 | 10 | **50,250** | −1 | 4 | 0x00A0 |
| SmallShop (2) | 1011322 | 425 | 212 | 489 | 244 | 10 | **52,250** | 0 | 4 | 0x00A2 |
| **SmallTower** | 1011317 | 580 | 290 | 667 | 333 | 14 | **73,250** | 3 | 4 | 0x0098 |
| **TwoStoryVilla** | 1011319 | 1100 | 550 | 1265 | 632 | 24 | **113,500** | 3 | 6 | 0x009E |
| **SandStonePatio** | 1011320 | 850 | 425 | 1265 | 632 | 24 | **76,250** | −1 | 4 | 0x009C |
| **LogCabin** | 1011318 | 1100 | 550 | 1265 | 632 | 24 | **81,250** | 1 | 6 | 0x009A |
| **GuildHouse** | 1011309 | 1370 | 685 | 1576 | 788 | 28 | **131,250** | −1 | 7 | 0x0074 |
| **TwoStoryHouse** (1) | 1011310 | 1370 | 685 | 1576 | 788 | 28 | **162,500** | −3 | 7 | 0x0076 |
| **TwoStoryHouse** (2) | 1011311 | 1370 | 685 | 1576 | 788 | 28 | **162,750** | −3 | 7 | 0x0078 |
| **LargePatioHouse** | 1011315 | 1370 | 685 | 1576 | 788 | 28 | **129,000** | −4 | 7 | 0x008C |
| **LargeMarbleHouse** | 1011316 | 1370 | 685 | 1576 | 788 | 28 | **160,250** | −4 | 7 | 0x0096 |
| **Tower** | 1011312 | 2119 | 1059 | 2437 | 1218 | 42 | **366,250** | 0 | 7 | 0x007A |
| **Keep** | 1011313 | 2625 | 1312 | 3019 | 1509 | 52 | **562,500** | 0 | 11 | 0x007C |
| **Castle** | 1011314 | 4076 | 2038 | 4688 | 2344 | 78 | **865,000** | 0 | 16 | 0x007E |

**AoS storage scaling 【C】 `BaseHouse.cs:352-370`:** `GetAosMaxSecures() = (int)(hpe.Storage * BonusStorageScalar)` and `GetAoSMaxLockdowns() = (int)(hpe.Lockdowns * BonusStorageScalar)` — i.e. **storage = pre-AoS storage × scalar**, lockdowns = pre-AoS lockdowns × scalar. So a classic clone only needs the two pre-AoS columns.

**Deed retail prices vs placement costs — a real discrepancy.** `SBHouseDeed` (what the vendor charges) differs from `HousePlacementEntry.cost`:

| Deed | Vendor price 【C】 `SBHouseDeed.cs` | Placement-table cost 【C】 `HousePlacementTool.cs` |
|---|---:|---:|
| deed to a stone-and-plaster house | 43,800 | 36,750 (SmallOldHouse) |
| deed to a field stone house | 43,800 | 36,750 |
| deed to a small brick house | 43,800 | 36,500 |
| deed to a wooden house | 43,800 | 35,000 |
| deed to a wood-and-plaster house | 43,800 | 36,500 |
| deed to a thatched-roof cottage | 43,800 | 36,500 |
| deed to a brick house | 144,500 | — |
| deed to a two-story wood-and-plaster house | 192,400 | 162,500 |
| **deed to a tower** | **433,200** | 366,250 |
| **deed to a small stone keep** | **665,200** | 562,500 |
| **deed to a castle** | **1,022,800** | 865,000 |
| deed to a large house with patio | 152,800 | 129,000 |
| deed to a marble house with patio | 192,000 | 160,250 |
| deed to a small stone tower | 88,500 | 73,250 |
| deed to a two story log cabin | 97,800 | 81,250 |
| deed to a sandstone house with patio | 90,900 | 76,250 |
| deed to a two story villa | 136,500 | 113,500 |
| deed to a small stone workshop | 60,600 | — |
| deed to a small marble workshop | 63,000 | — |

**Interpretation:** the vendor prices are ~1.19× the placement costs. **For a classic clone use `HousePlacementEntry.cost` as the house price and `SBHouseDeed` as the retail deed price**; which one the player actually paid in-era is **UNVERIFIED** — the two tables are inconsistent in ServUO and one of them is likely stale. **To measure:** check RunUO 2.x `Scripts/Items/Deeds/HouseDeed.cs` and the era's `HousePlacementEntry` table; or read a UO:R-era `housing` patch note.

**Architect / RealEstateBroker tools 【C】:** `SBArchitect` sells `HousePlacementTool` at **627 gp** and `InteriorDecorator` at **10,001 gp**; `SBRealEstateBroker` sells `BlankScroll` (5 gp) and `ScribesPen` (8 gp) — i.e. the *broker* is really a scribe shop, and **the architect is the house vendor**.

**Decay 【C】 `BaseHouse.cs:57-86`:** `DecayEnabled = true`; `DecayPeriod => TimeSpan.FromDays(5.0)`; `Core.AOS ? DecayType.Condemned : DecayType.ManualRefresh`. So **pre-AoS houses do not decay** — they need a manual refresh (walk in / use the sign).

### 5.6 Boat purchase

**【C】** `Scripts/VendorInfo/SBShipwright.cs` — the shipwright's stock list, `GenericBuyInfo("cliloc", typeof(Deed), price, stock, itemID, hue)`:

| Boat | cliloc | **Price (gp)** | Stock | Deed itemID |
|---|---|---:|---:|---|
| SmallBoatDeed | 1041205 | **10,177** | 20 | 0x14F2 |
| SmallDragonBoatDeed | 1041206 | **10,177** | 20 | 0x14F2 |
| MediumBoatDeed | 1041207 | **11,552** | 20 | 0x14F2 |
| MediumDragonBoatDeed | 1041208 | **11,552** | 20 | 0x14F2 |
| LargeBoatDeed | 1041209 | **12,927** | 20 | 0x14F2 |
| LargeDragonBoatDeed | 1041210 | **12,927** | 20 | 0x14F2 |
| RowBoatDeed | 1116491 | **6,252** | 20 | 0x14F2 |
| TokunoGalleonDeed | 1116740 | 150,002 | 20 | 0x14F2 |
| GargishGalleonDeed | 1116739 | 200,002 | 20 | 0x14F2 |
| Spyglass | — | 3 | 20 | 0x14F5 |

The three classic tiers are **small 10,177 / medium 11,552 / large 12,927**, each in a normal and a "dragon" hull style at the same price. Buying the deed places the boat when double-clicked **on water**; the shipwright sells nothing else except a spyglass. 【C】

### 5.7 Town guard / criminal flagging interaction

**【C】** `Scripts/Regions/GuardedRegion.cs`, `Server/Mobile.cs`, `Server/Notoriety.cs`.

**Flagging chain**

| Step | Mechanism | Source |
|---|---|---|
| Harmful act on an innocent | `Mobile.OnHarmfulAction(target, isCriminal)` → `((Mobile)target).AggressiveAction(this, isCriminal)` | `Mobile.cs:8016-8041` |
| Aggression recorded | `AggressiveAction(aggressor, criminal)` → fires `EventSink.InvokeAggressiveAction(args)` | `Mobile.cs:2295-2307` |
| Region reacts | `GuardedRegion.OnAggressed(aggressor, aggressed, criminal)` | `GuardedRegion.cs:198-200` |
| Criminal timer | `m_ExpireCriminalDelay = TimeSpan.FromMinutes(2.0)`; `ExpireCriminalTimer` | `Mobile.cs:2102, 2106-2110` |
| Murderer flag | `public virtual bool Murderer { get { return m_Kills >= 5; } }`; changing `Kills` across the 5 boundary fires an event | `Mobile.cs:11782, 11849` |
| Short-term murders | `ShortTermMurders` counter, clamped ≥ 0 | `Mobile.cs:11797-11808` |
| Reds in guarded regions | `if (!AllowReds && m.Murderer) CheckGuardCandidate(m);` | `GuardedRegion.cs:169-171` |
| Player calls guards | Speech keyword `*guards*` (keyword id `0x0007`) → `CallGuards(args.Mobile.Location)` | `GuardedRegion.cs:183-194` |
| Guard spawn | `MakeGuard(focus)`: reuse an existing `BaseGuard` in the region, else `Activator.CreateInstance(m_GuardType, focus)` | `GuardedRegion.cs:124-158` |
| Vendor refusal | `CheckVendorAccess(from)` fails → vendor says 501522 *"I shall not treat with scum like thee!"* | `BaseVendor.cs:914-918` |
| Beneficial-action restrictions | `OnBeneficialAction(target, isCriminal)` — on `TrammelRules` facets, you cannot heal a criminal | `Mobile.cs:7900-7902` |
| Attackability | `IsHarmfulCriminal` / `CanBeAttacked`; `n == Criminal \|\| n == Murderer` marks a mobile as attackable | `Mobile.cs:7894` |

**Trammel vs Felucca** 【C】 `Server/Map.cs:121-130`: on Trammel-rules facets, `HarmfulRestrictions` + `BeneficialRestrictions` + `FreeMovement` apply — you cannot harm innocents at all, so *criminal flagging is largely moot on Trammel*. On **Felucca (`FeluccaRules = None`)** nothing is restricted and guards are the only deterrent.

**Notoriety display colours** — see the table in §4.5.

**Clone guidance:** implement (a) a 2-minute criminal flag, (b) a kill counter with the 5-kill murderer threshold, (c) a guarded-region polygon test, (d) guard despatch on `*guards*` speech or on a witnessed crime, (e) vendor/shop refusal for flagged players. That is the full classic loop.

### 5.8 Player vendors

**【C】** `Scripts/Mobiles/NPCs/PlayerVendor.cs`, `RentedVendor.cs`, `CommissionPlayerVendor.cs`.

| Concept | Detail | Line |
|---|---|---|
| **What it is** | A vendor NPC the player buys and places **inside their own house**. `PlayerVendor : BaseVendor`. | — |
| **Contract** | Bought from a **banker**: `ContractOfEmployment` 1,252 gp; `VendorRentalContract` 1,252 gp; `CommissionContractOfEmployment` 28,127 gp | `SBBanker.cs` |
| **Placing items for sale** | Drop an item on the vendor; a `VendorItem` records `{Item, Price, Description, Created}`. `Price >= 0` means for sale, `Price == 0` means **FREE**, `Price == -1` means **not for sale** (display only) | 30-76, 194-198 |
| **Container restriction** | You cannot place a container that itself contains containers: message 1017381 | 113-115 |
| **AoS storage limit** | Placing an item checks `house.CheckAosStorage(1 + item.TotalItems + plusItems)`; failure → 1061839 *"This action would exceed the secure storage limit of the house."* | 120-127 |
| **Charge — old system** | `ChargePerDay = (int)(20 + max(0, sum(all listed prices) - 500) / 500)` | 393-416 |
| **Charge — new vendor system** | `ChargePerRealWorldDay = (int)(60 + (sum(all listed prices) / 500) * 3)`; a `MerchantsTrinket` worn on `Layer.Earrings` reduces it by `trinket.Bonus` percent | 418-446 |
| **Per-charge granularity** | `ChargePerDay = ChargePerRealWorldDay / 12` (12 charges per day, i.e. **one charge every 2 hours**) | 397-400 |
| **Bank account** | The vendor has `BankAccount` and `HoldGold` — the sale proceeds accumulate on the vendor and must be collected by the owner | 296-350 |
| **Payment failure** | `PayTimer` charges on an interval; when the account cannot pay, the vendor packs up and the goods go to the moving crate | 321 |
| **Buying from a player vendor** | `PlayerVendor.TryToBuy(item, from)` — checks `CanInteractWith`, ownership, price, then transfers gold | 447-454 |
| **Variants** | `RentedVendor` (rented from another player's house), `CommissionPlayerVendor` (commission model) | — |
| **Era relevance** | Player vendors arrived with **UO:R** (housing + secure trading). **For a pre-UO:R clone they do not exist; for a UO:R-era clone they do.** | — |

**Clone note:** the essential loop is *place vendor → set prices → world clock charges the owner periodically → sale proceeds held on the vendor → owner collects.* The two charge formulas are both shipped; pick the **old** one (`20 + excess/500` per day) if you are targeting the original UO:R behaviour, and note that the "new vendor system" is a later rework.

---


## 6. Quests, escorts and profession templates

### 6.1 The classic escortable NPC system

**【C】** `Scripts/Mobiles/NPCs/BaseEscortable.cs`, `EscortableMage.cs`, `Escortables.cs`.

**Escortable classes**

| Class | Base | Notes |
|---|---|---|
| `BaseEscortable` | `BaseCreature` | Abstract; `AI_Melee / FightMode.Aggressor, 22, 1, 0.2, 1.0` |
| `EscortableMage` | `BaseEscortable` | Robe + ShortPants + ThighBoots/Boots, random hue |
| `Noble` | `BaseEscortable` | |
| `SeekerOfAdventure` | `BaseEscortable` | |
| `Merchant` | `BaseEscortable` | |
| `Messenger` | `BaseEscortable` | |
| `Peasant` | `BaseEscortable` | |
| `BrideGroom` | `BaseEscortable` | |
| `GargishNoble` | `BaseEscortable` | SA-era |

The `SpawnDefinitions.xml` group **`Escortables`** = `{ EscortableMage, Noble, SeekerOfAdventure }` 【D】 — that is the classic trio that region spawns use.

**Base appearance and gear 【C】 `BaseEscortable.cs:85-107`:**

| Property | Value |
|---|---|
| Hue | `Utility.RandomSkinHue()` |
| Gender | `Female = Utility.RandomBool()` → Body **401** (female) or **400** (male) |
| Name | `NameList.RandomName("female")` or `"male"` |
| Outfit | `FancyShirt(Utility.RandomNeutralHue())`, `ShortPants(Utility.RandomNeutralHue())`, `Boots(Utility.RandomNeutralHue())`, plus `Utility.AssignRandomHair(this)` |
| **Carried gold** | **`PackGold(200, 250)`** — the escort carries 200–250 gp of their own |

**The escort loop**

| Stage | Behaviour | Line |
|---|---|---|
| Idle | Wanders. When a player approaches, `SayDestinationTo(m)` → *"I am looking to go to {0}, will you take me?"* | 118-130 |
| Destination remap | `(dest.Name == "Ocllo" && m.Map == Map.Trammel) ? "Haven" : dest.Name` — **on Trammel, "Ocllo" is announced and delivered as "Haven"** | 126 |
| Accept | `AcceptEscorter(m)` — refuses a second escort: *"I see you already have an escort."* Refuses if the player is dead | 133-170 |
| While escorted | *"Lead on! Payment will be made when we arrive in {0}."* | 166 |
| Another player asks | If already escorted by someone else, `SayDestinationTo` reports being taken | — |
| Abandonment | If the escorter is unseen for `>= TimeSpan.FromMinutes(2.0)` the escort gives up | 265 |
| Arrival | `Say(1042809, escorter.Name)` — *"We have arrived! I thank thee, ~1_PLAYER_NAME~! I have no further need of thy services. Here is thy pay."* | 315 |
| **Payment** | **`new Gold(500, 1000)`** — i.e. **500–1000 gold**, dropped into the escorter's backpack, or onto the ground if it does not fit | 326-332 |
| Fame | `Misc.Titles.AwardFame(escorter, 10, true)` — **+10 Fame** | 345 |
| Cleanup | After arrival the escort deletes on a 30-second timer (`m_DeleteTime = UtcNow + TimeSpan.FromSeconds(30.0)`) | 292-298 |
| Global spacing | `m_EscortDelay = TimeSpan.FromMinutes(5.0)` — an escort will not offer again for 5 minutes | 28 |
| Destination source | `EscortDestinationInfo.LoadTable()` enumerates `Map.Felucca.Regions.Values` and registers **every `DungeonRegion` and `TownRegion` by name** | 542-559 |

**Escort destinations = the region list in §1.4 plus every dungeon in §1.7.** That is the complete, code-verified destination set: **17 towns + 12+ dungeons**, chosen at random by `PickRandomDestination()` from the `Region`'s rects. 【C】 `BaseEscortable.cs:454-476`

**Escort pay table** — a flat random range, **not** scaled by distance:

| Destination type | Pay |
|---|---|
| Any town or dungeon region | **500–1000 gp** + 10 Fame |
| Escort's own carried gold (lootable if you kill them) | 200–250 gp |

**Clone guidance:** one escort spawn per `Escortables` region entry, offer on proximity, 2-minute abandonment timeout, arrival check inside the destination region's rects, pay 500–1000 gp, +10 Fame, 30-second despawn, 5-minute re-offer delay. **No quest text, no reputation beyond Fame** — the classic escort has no dialogue tree.

### 6.2 The classic starting profession templates

There are **two different systems**, and they conflict:

#### A. Client-side templates — the real classic professions

**【C】** `ClassicUO/src/ClassicUO.Assets/ProfessionLoader.cs` reads the **client data file `Prof.txt`**, not server code:

```
FileInfo file = new FileInfo(FileManager.GetUOFilePath("Prof.txt"));
```

**`Prof.txt` format** — block-delimited, keys parsed by `ProfessionLoader.GetKeyCode` 【C】 `ProfessionLoader.cs:49-53`:

```
begin
  name        <display name>
  truename    <identifier used by "children">
  desc        <description index>
  toplevel    true|false
  gump        <gump art id>
  type        category|profession
  children    <truename> [<truename> ...]
  skill       <skill name> <value>          (up to 4 per profession)
  stat        str|int|dex <value>
  nameid      <cliloc id>
  descid      <cliloc id>
end
```

**Default skill/stat allocation rules 【C】 `ProfessionLoader.cs:17-31`:**

| Client version | Initial skill value | Remaining stat value | Default stats | Default skill layout |
|---|---|---|---|---|
| `>= CV_70160` (7.0.16.0) | **30** | **15** | `[60, 15, 15]` | 4 skills, all at 30 |
| older clients | **50** | **10** | `[60, 10, 10]` | skill 1 & 2 at 50, skill 3 at **0**, skill 4 at 50 |

```csharp
int initialSkillValue = clientVersion >= ClientVersion.CV_70160 ? 30 : 50;
int remainStatValue    = clientVersion >= ClientVersion.CV_70160 ? 15 : 10;
// skills: {0,sv},{0,sv},{0, (old?0:sv)},{0,sv}
// stats : {60, remainStatValue, remainStatValue}
```

**Server-side validation 【C】 `Scripts/Misc/CharacterCreation.cs:368-386` (`ValidSkills`):**
- each skill value must be **`>= 0` and `<= 50`**;
- the sum must not exceed the cap;
- no duplicate skill entries allowed.

**The actual classic profession names/skills live in `Prof.txt`, which is a UO *client* data file and is not shipped in any of these repos.** It is copyrighted client data.
**UNVERIFIED:** the exact per-profession skill/stat/equipment tables for Warrior, Mage, Blacksmith, Tailor, Tinker, Carpenter, Bard, Thief, Ranger, etc.
**To measure:** read `Prof.txt` from a licensed UO installation (it is a plain-text file in the client root) and parse it with the format above; the top-level categories are the `toplevel true` blocks and the professions are their `children`. This is a **~10-minute job with a legal client install** and would fully close this gap.

#### B. Server-side fallback templates — what ServUO uses if the client sends nothing

**【C】** `Scripts/Misc/CharacterCreation.cs:453-533` (`SetSkills`). ServUO only hard-codes **7 professions**, by integer index:

| # | Profession | Skills (all at 30 unless noted) | Equipment added 【C】 lines 540-560+ |
|---:|---|---|---|
| 1 | **Warrior** | Anatomy 30, Healing 30, Swords 30, Tactics 30 | `LeafChest` (elf) / `LeatherChest` (human) / `GargishLeatherChest` (gargoyle) |
| 2 | **Magician** | EvalInt 30, Wrestling 30, Magery 30, Meditation 30 | — |
| 3 | **Blacksmith** | Mining 30, ArmsLore 30, Blacksmith 30, Tinkering 30 | — |
| 4 | **Necromancer** | Necromancy 30, SpiritSpeak 30, Swords 30, **Meditation 20** | `BagOfNecroReagents(50)` |
| 5 | **Paladin** | Chivalry 30, Swords 30, Focus 30, Tactics 30 | — |
| 6 | **Samurai** | Bushido 30, Swords 30, Anatomy 30, Healing 30 | — |
| 7 | **Ninja** | Ninjitsu 30, Hiding 30, Fencing 30, Stealth 30 | — |
| default | *(client-supplied)* | validated by `ValidSkills` | — |

**Stats 【C】 `CharacterCreation.cs:295-355`:** `FixStats(ref str, ref dex, ref intel, max)` normalises the three values to sum to `max`; `SetStats` then `m.InitStats(str, dex, intel)`; `SetStats(newChar, state, args.Profession, args.Str, args.Dex, args.Int)` is the entry point. **Stat cap: `m_Cap = Config.Get("PlayerCaps.TotalStatCap", 225)`; skill cap `PlayerCaps.TotalSkillCap, 7000` (= 700.0)** 【C】 `Server/Skills.cs:996`.

**Note:** professions 4–7 (Necromancer, Paladin, Samurai, Ninja) are **post-AoS**. A classic clone should implement only **1–3 plus the client-only professions read from `Prof.txt`**.

**Clone recommendation:** implement the **client model** (profession chosen at creation, 4 skills, 60/15/15 stats for a modern client or 60/10/10 for a classic client, per-skill cap 50 at creation, sum bounded), and store the profession table as data you populate from `Prof.txt`.

### 6.3 The skill system — complete reference

**【C】** `Server/Skills.cs` — `SkillName` enum (58 entries) and the `SkillInfo` table.

| ID | SkillName enum | Display name | Title | StrScale | DexScale | IntScale | StrGain | DexGain | IntGain | Primary | Secondary | Mastery |
|---:|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---|
| 0 | Alchemy | Alchemy | Alchemist | 0.0 | 5.0 | 5.0 | 0.0 | 0.5 | 0.5 | Int | Dex | |
| 1 | Anatomy | Anatomy | Biologist | 0.0 | 0.0 | 0.0 | 0.15 | 0.15 | 0.7 | Int | Str | |
| 2 | AnimalLore | Animal Lore | Naturalist | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | Int | Str | |
| 3 | ItemID | Item Identification | Merchant | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | Int | Dex | |
| 4 | ArmsLore | Arms Lore | Weapon Master | 0.0 | 0.0 | 0.0 | 0.75 | 0.15 | 0.1 | Int | Str | |
| 5 | Parry | Parrying | Duelist | 7.5 | 2.5 | 0.0 | 0.75 | 0.25 | 0.0 | Dex | Str | ✔ |
| 6 | Begging | Begging | Beggar | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Dex | Int | |
| 7 | Blacksmith | Blacksmithy | Blacksmith | 10.0 | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | Str | Dex | |
| 8 | Fletching | Bowcraft/Fletching | Bowyer | 6.0 | 16.0 | 0.0 | 0.6 | 1.6 | 0.0 | Dex | Str | |
| 9 | Peacemaking | Peacemaking | Pacifier | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Int | Dex | ✔ |
| 10 | Camping | Camping | Explorer | 20.0 | 15.0 | 15.0 | 2.0 | 1.5 | 1.5 | Dex | Int | |
| 11 | Carpentry | Carpentry | Carpenter | 20.0 | 5.0 | 0.0 | 2.0 | 0.5 | 0.0 | Str | Dex | |
| 12 | Cartography | Cartography | Cartographer | 0.0 | 7.5 | 7.5 | 0.0 | 0.75 | 0.75 | Int | Dex | |
| 13 | Cooking | Cooking | Chef | 0.0 | 20.0 | 30.0 | 0.0 | 2.0 | 3.0 | Int | Dex | |
| 14 | DetectHidden | Detecting Hidden | Scout | 0.0 | 0.0 | 0.0 | 0.0 | 0.4 | 0.6 | Int | Dex | |
| 15 | Discordance | Discordance | Demoralizer | 0.0 | 2.5 | 2.5 | 0.0 | 0.25 | 0.25 | Dex | Int | ✔ |
| 16 | EvalInt | Evaluating Intelligence | Scholar | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | Int | Str | |
| 17 | Healing | Healing | Healer | 6.0 | 6.0 | 8.0 | 0.6 | 0.6 | 0.8 | Int | Dex | |
| 18 | Fishing | Fishing | Fisherman | 0.0 | 0.0 | 0.0 | 0.5 | 0.5 | 0.0 | Dex | Str | |
| 19 | Forensics | Forensic Evaluation | Detective | 0.0 | 0.0 | 0.0 | 0.0 | 0.2 | 0.8 | Int | Dex | |
| 20 | Herding | Herding | Shepherd | 16.25 | 6.25 | 2.5 | 1.625 | 0.625 | 0.25 | Int | Dex | |
| 21 | Hiding | Hiding | Shade | 0.0 | 0.0 | 0.0 | 0.0 | 0.8 | 0.2 | Dex | Int | |
| 22 | Provocation | Provocation | Rouser | 0.0 | 4.5 | 0.5 | 0.0 | 0.45 | 0.05 | Int | Dex | ✔ |
| 23 | Inscribe | Inscription | Scribe | 0.0 | 2.0 | 8.0 | 0.0 | 0.2 | 0.8 | Int | Dex | |
| 24 | Lockpicking | Lockpicking | Infiltrator | 0.0 | 25.0 | 0.0 | 0.0 | 2.0 | 0.0 | Dex | Int | |
| 25 | Magery | Magery | Mage | 0.0 | 0.0 | 15.0 | 0.0 | 0.0 | 1.5 | Int | Str | ✔ |
| 26 | MagicResist | Resisting Spells | Warder | 0.0 | 0.0 | 0.0 | 0.25 | 0.25 | 0.5 | Str | Dex | |
| 27 | Tactics | Tactics | Tactician | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Str | Dex | |
| 28 | Snooping | Snooping | Spy | 0.0 | 25.0 | 0.0 | 0.0 | 2.5 | 0.0 | Dex | Int | |
| 29 | Musicianship | Musicianship | Bard | 0.0 | 0.0 | 0.0 | 0.0 | 0.8 | 0.2 | Dex | Int | |
| 30 | Poisoning | Poisoning | Assassin | 0.0 | 4.0 | 16.0 | 0.0 | 0.4 | 1.6 | Int | Dex | ✔ |
| 31 | Archery | Archery | Archer | 2.5 | 7.5 | 0.0 | 0.25 | 0.75 | 0.0 | Dex | Str | ✔ |
| 32 | SpiritSpeak | Spirit Speak | Medium | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | Int | Str | |
| 33 | Stealing | Stealing | Pickpocket | 0.0 | 10.0 | 0.0 | 0.0 | 1.0 | 0.0 | Dex | Int | |
| 34 | Tailoring | Tailoring | Tailor | 3.75 | 16.25 | 5.0 | 0.38 | 1.63 | 0.5 | Dex | Int | |
| 35 | AnimalTaming | Animal Taming | Tamer | 14.0 | 2.0 | 4.0 | 1.4 | 0.2 | 0.4 | Str | Int | ✔ |
| 36 | TasteID | Taste Identification | Praegustator | 0.0 | 0.0 | 0.0 | 0.2 | 0.0 | 0.8 | Int | Str | |
| 37 | Tinkering | Tinkering | Tinker | 5.0 | 2.0 | 3.0 | 0.5 | 0.2 | 0.3 | Dex | Int | |
| 38 | Tracking | Tracking | Ranger | 0.0 | 12.5 | 12.5 | 0.0 | 1.25 | 1.25 | Int | Dex | |
| 39 | Veterinary | Veterinary | Veterinarian | 8.0 | 4.0 | 8.0 | 0.8 | 0.4 | 0.8 | Int | Dex | |
| 40 | Swords | Swordsmanship | Swordsman | 7.5 | 2.5 | 0.0 | 0.75 | 0.25 | 0.0 | Str | Dex | ✔ |
| 41 | Macing | Mace Fighting | Armsman | 9.0 | 1.0 | 0.0 | 0.9 | 0.1 | 0.0 | Str | Dex | ✔ |
| 42 | Fencing | Fencing | Fencer | 4.5 | 5.5 | 0.0 | 0.45 | 0.55 | 0.0 | Dex | Str | ✔ |
| 43 | Wrestling | Wrestling | Wrestler | 9.0 | 1.0 | 0.0 | 0.9 | 0.1 | 0.0 | Str | Dex | ✔ |
| 44 | Lumberjacking | Lumberjacking | Lumberjack | 20.0 | 0.0 | 0.0 | 2.0 | 0.0 | 0.0 | Str | Dex | |
| 45 | Mining | Mining | Miner | 20.0 | 0.0 | 0.0 | 2.0 | 0.0 | 0.0 | Str | Dex | |
| 46 | Meditation | Meditation | Stoic | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Int | Str | |
| 47 | Stealth | Stealth | Rogue | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Dex | Int | |
| 48 | RemoveTrap | Remove Trap | Trap Specialist | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Dex | Int | |
| 49 | Necromancy | Necromancy | Necromancer | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Int | Str | ✔ |
| 50 | Focus | Focus | Driven | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Dex | Int | |
| 51 | Chivalry | Chivalry | Paladin | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Str | Int | ✔ |
| 52 | Bushido | Bushido | Samurai | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Str | Int | ✔ |
| 53 | Ninjitsu | Ninjitsu | Ninja | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Dex | Int | ✔ |
| 54 | Spellweaving | Spellweaving | Arcanist | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Int | Str | ✔ |
| 55 | Mysticism | Mysticism | Mystic | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Str | Int | ✔ |
| 56 | Imbuing | Imbuing | Artificer | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | Int | Str | |
| 57 | Throwing | Throwing | *(not in the SkillInfo dump — table is `new SkillInfo[58]`, last row beyond the printed block)* | | | | | | | | | |

**Scale semantics 【C】 `Skills.cs:521-560`:** the ctor divides by 100 — `StrScale = strScale / 100.0` etc., so a `7.5` in the table is a `0.075` internal scale. `StatTotal = strScale + dexScale + intScale`. These scales convert a skill *use* into stat gain: a skill with a high `StrScale` (Blacksmithy 10, Camping 20, Carpentry 20, Mining 20, Lumberjacking 20, Herding 16.25, Animal Taming 14) builds STR; a high `DexScale` (Lockpicking 25, Snooping 25, Cooking 20, Fletching 16, Tailoring 16.25) builds DEX; a high `IntScale` (Cooking 30, Poisoning 16, Magery 15, Camping 15) builds INT. The `StrGain`/`DexGain`/`IntGain` columns are the per-use gain weights (`GainFactor` is 1.0 for every skill).

**Caps 【C】 `Skills.cs`:**
- Total skill cap: `m_Cap = Config.Get("PlayerCaps.TotalSkillCap", 7000)` → **700.0**
- Per-skill cap: `m_Cap = 1000` → **100.0** (the `1000` literal is the internal fixed-point representation)
- Default per-skill on a new character: `m_Cap = 1000`
- Total stat cap: `PlayerCaps.TotalStatCap, 225`
- Skill lock states: `SkillLock.Up = 0`, `Locked = 2` (from `Skills.cs:28-32`)

**Classic vs modern skill split:**

| Era | Skill IDs present |
|---|---|
| **Launch / T2A** | 0–48 (Alchemy … Remove Trap) — 49 skills |
| **UO:R** | 0–48 unchanged |
| **AoS** | + Necromancy (49), Focus (50), Chivalry (51) |
| **Samurai Empire** | + Bushido (52), Ninjitsu (53) |
| **Mondain's Legacy** | + Spellweaving (54) |
| **Stygian Abyss** | + Mysticism (55), Imbuing (56), Throwing (57) |

**ClassicUO's `SkillEntry.HardCodedName` enum uses the original pre-AoS names** and notes era additions inline (`ItemID, // T2A`) 【C】 `ClassicUO/src/ClassicUO.Assets/SkillsLoader.cs`. Skills are loaded from the client's **`skills.mul` + `Skills.idx`** 【C】 `SkillsLoader.cs:31-56` — each entry is `{int8 hasAction, ASCIIZ name}`.

**Magic system (spell circles, mana, reagents)** — **NOT COVERED in this document.** Spell data is client-side (`spells.mul`/`Spells.def`) plus server-side `Scripts/Spells/**`. **To measure:** read `ServUO/Scripts/Spells/First/` … `Eighth/` (one file per spell with mana cost + reagents) and the client's `spells.mul`. This is a substantial separate research task and should be its own document.

---

## 7. Implementation checklist (what to build from this document)

| # | Deliverable | Data source in this doc |
|---:|---|---|
| 1 | Map loader + 6 facets with exact dimensions/seasons/rules | §1.1, §1.2 |
| 2 | Town polygons + guard flags, 17 Felucca towns with centre points | §1.4 |
| 3 | Service placement per town (which vendor where) | §1.5 |
| 4 | Moongate network, 9 Felucca gates + 4 other facets | §1.6 |
| 5 | 12+ dungeons with entrance coords and per-level spawn lists | §1.7, §4.8-J |
| 6 | 57 vendor NPC classes with skills, titles, outfits, shop lists | §2.2, §2.4 |
| 7 | Restock model (60 min, 250-row gump, 1/3 refill rule) | §2.3, §4.3 |
| 8 | ~110 tameable creatures with MinTameSkill + control slots | §2.5 |
| 9 | ~90 monster stat blocks | §3.1–3.3 |
| 10 | Loot packs (pre-AoS `Old*` set) | §3.4 |
| 11 | Spawn model: region table + world tick + 1/3 refill | §4.7 |
| 12 | Spawn tables for 10 environment types | §4.8 |
| 13 | Vendor gump + ×1.90 price spread | §5.1, §5.2 |
| 14 | Bank box (0xE7C, unlimited weight, owner-only) | §5.3 |
| 15 | Stabling (30 gp/week, slot ladder) | §5.4 |
| 16 | Housing (20 house types, costs, storage, lockdowns, 8 placement rules) | §5.5 |
| 17 | Boats (3 classic tiers) | §5.6 |
| 18 | Guard/criminal loop (2-min flag, 5 kills = murderer) | §5.7, §4.5 |
| 19 | Player vendors (UO:R+ only) | §5.8 |
| 20 | Escort system (500–1000 gp, 10 Fame) | §6.1 |
| 21 | Profession system (client `Prof.txt` model) | §6.2 |
| 22 | 58-skill table with stat scales | §6.3 |

---

## 8. Open questions and how to measure them

| # | Question | Why it matters | How to measure |
|---:|---|---|---|
| 1 | **The exact classic `Prof.txt` profession templates** (Warrior, Mage, Blacksmith, Tailor, Tinker, Carpenter, Bard, Thief, Ranger…) — skills, stats, starting equipment and inventory | §6.2 has the *format* and the *allocation rules* but not the content; §6.2-B is ServUO's post-AoS fallback, not classic | Read `Prof.txt` from a licensed UO client install; parse per `ProfessionLoader.cs`. **~10 minutes, closes the gap completely.** |
| 2 | **Classic moongate lunar-phase destination table** | Determines whether the clone uses the phase cycle or the gump | Pre-UO:R client disassembly of the moongate handler; or the OSI server's moongate script; or empirical capture from a UO:R free shard |
| 3 | **Exact pre-AoS damage multiplier formula** (how STR/Anatomy/Tactics scale `SetDamage`) | All §3 damage values are *base* ranges; real damage is higher | Read `ServUO/Scripts/Mobiles/Normal/BaseCreature.cs` `GetBaseDamage`/`GetBonusDamage` + `Server/Mobile.cs` `Damage()`; instrument a running ServUO to log actual damage per monster |
| 4 | **Full stat blocks for sea creatures** (SeaSerpent, Kraken, DeepSeaSerpent, Dolphin) and for `Slime`/`Zombie`-style classes whose stats are built indirectly | Sea serpent is the **#2 most-spawned creature on Felucca** (115 spawn points); its stats are a real gap | Open the four `.cs` files directly; or widen the extractor's constructor window past 220 lines and re-run `.cache/analysis/extract-monsters.ps1` |
| 5 | **Which price the player actually paid for a house in-era** — `HousePlacementEntry.cost` (36,750 for a small house) or `SBHouseDeed` (43,800) | Affects the entire housing economy; the two shipped tables disagree by ~19% | Check RunUO 2.x `Scripts/Items/Deeds/HouseDeed.cs` and the era's placement table; read a UO:R-era housing patch note |
| 6 | **Gold stack / bank box item limits** | Affects banking UX and vendor transactions | Read `Scripts/Items/Consumables/Gold.cs` and `Server/Items/Containers.cs` |
| 7 | **Slayer-type mapping per monster** (Undead / Reptile / Arachnid / Elemental / Demon / Fey…) | Required for weapon slayer properties | Read `Scripts/Items/Equipment/Weapons/SlayerEntry.cs`, `BaseSlayer.cs`, `SlayerName` enum, then map every monster class |
| 8 | **Honesty virtue price discount magnitude** | Only dynamic price modifier in the classic trade loop | Read `Scripts/Services/Virtues/Honesty.cs` |
| 9 | **Exact profession-to-vendor mapping for towns outside the 17 modelled** (Paws and any village I did not box) | Completeness of the town list | Extract building rectangles from `map0.mul` statics in unclaimed regions, or cross-check a UOGuide town list |
| 10 | **Complete magic system** (spell circles, mana costs, reagents, casting delays, resist/interrupt) | Entirely absent from this document — it is its own research task | Read `ServUO/Scripts/Spells/First/` … `Eighth/` + client `spells.mul` |

---

## 9. Source index

### Repositories (with the branch/paths actually read)

| Repo | Path prefix read | Used for |
|---|---|---|
| **ServUO** `github.com/ServUO/ServUO` @ `pub57` | `Server/` · `Scripts/Mobiles/` · `Scripts/VendorInfo/` · `Scripts/Regions/` · `Scripts/Items/` · `Scripts/Multis/` · `Scripts/Misc/` · `Spawns/` | Everything in §2, §3, §4 (model), §5, §6.3 |
| **RunUO** `github.com/runuo/runuo` | `Data/Regions.xml` · `Data/Locations/felucca.xml` · `Data/SpawnDefinitions.xml` | §1.4, §1.6, §1.7, §4.5 |
| **ModernUO** `github.com/modernuo/ModernUO` | `Projects/UOContent/Mobiles/**` | Content-layout cross-check |
| **ClassicUO** `github.com/ClassicUO/ClassicUO` | `src/ClassicUO.Assets/ProfessionLoader.cs` · `SkillsLoader.cs` | §6.2-A, §6.3 |

### Specific files cited inline

| File | Sections |
|---|---|
| `ServUO/Scripts/Misc/MapDefinitions.cs` | §1.1 |
| `ServUO/Server/Map.cs` | §1.1, §1.2, §5.7 |
| `ServUO/Server/Skills.cs` | §6.3 |
| `ServUO/Server/Notoriety.cs` | §4.5, §5.7 |
| `ServUO/Server/Mobile.cs` | §4.5, §5.7 |
| `ServUO/Server/Items/Containers.cs` | §5.3 |
| `ServUO/Scripts/Mobiles/NPCs/BaseVendor.cs` | §2.1, §2.3, §5.1, §5.2 |
| `ServUO/Scripts/Mobiles/NPCs/Blacksmith.cs` (+56 sibling vendor files) | §2.2 |
| `ServUO/Scripts/Mobiles/NPCs/AnimalTrainer.cs` | §5.4 |
| `ServUO/Scripts/Mobiles/NPCs/BaseEscortable.cs` | §6.1 |
| `ServUO/Scripts/Mobiles/NPCs/Banker.cs` | §5.3 |
| `ServUO/Scripts/Mobiles/NPCs/PlayerVendor.cs` | §5.8 |
| `ServUO/Scripts/Mobiles/NPCs/TownCrier.cs` | §2.2.3 |
| `ServUO/Scripts/Mobiles/NPCs/Gypsy.cs` | §2.2.3 |
| `ServUO/Scripts/Mobiles/Normal/*.cs` (665 classes) | §2.5, §3 |
| `ServUO/Scripts/VendorInfo/*.cs` (88 `SB*` classes) | §2.4, §5.2, §5.5, §5.6 |
| `ServUO/Scripts/VendorInfo/GenericSell.cs` | §5.2 |
| `ServUO/Scripts/Misc/LootPack.cs` | §3.4 |
| `ServUO/Scripts/Misc/CharacterCreation.cs` | §6.2-B |
| `ServUO/Scripts/Regions/Spawning/SpawnDefinition.cs` | §4.3 |
| `ServUO/Scripts/Regions/Spawning/SpawnEntry.cs` | §4.3 |
| `ServUO/Scripts/Regions/GuardedRegion.cs` | §4.5, §5.7 |
| `ServUO/Scripts/Regions/TownRegion.cs` | §4.5 |
| `ServUO/Scripts/Items/Functional/PublicMoongate.cs` | §1.6 |
| `ServUO/Scripts/Multis/HousePlacement.cs` | §5.5 |
| `ServUO/Scripts/Multis/HousePlacementTool.cs` | §5.5 |
| `ServUO/Scripts/Multis/BaseHouse.cs` | §5.5 |
| `ServUO/Spawns/felucca.xml` (+5 other facets) | §1.5, §4.2, §4.4 |
| `RunUO/Data/Regions.xml` | §1.1, §1.4, §1.6, §1.7, §4.5, §5.5 |
| `RunUO/Data/Locations/felucca.xml` | §1.4, §1.7 |
| `RunUO/Data/SpawnDefinitions.xml` | §4.3 |
| `ClassicUO/src/ClassicUO.Assets/ProfessionLoader.cs` | §6.2-A |
| `ClassicUO/src/ClassicUO.Assets/SkillsLoader.cs` | §6.3 |

### Generated intermediates (kept in the workspace)

| File | Contents |
|---|---|
| `.cache/analysis/monsters.tsv` | 665 creature classes × 22 fields |
| `.cache/analysis/vendors.tsv` | 120 vendor-family classes × 8 fields |
| `.cache/analysis/taming.tsv` | Tamable/MinTameSkill/ControlSlots/PackInstinct per class |
| `.cache/analysis/sbinfo.tsv` | 88 `SB*` classes with parsed buy/sell item lists |
| `.cache/analysis/sb-tables.md` | 2 804-line markdown rendering of every shop list (§2.4) |
| `.cache/analysis/spawn-mobs-{facet}.tsv` | Per-facet object-type frequency tables |
| `.cache/analysis/extract-monsters.ps1` · `gen-sb-tables.ps1` · `spawn-analysis.ps1` · `town-services.ps1` | Reproduction scripts |

### Web sources used

- [UO Second Age hint book (mocagh.org)](https://mocagh.org/origin/uosecondage-hintbook.pdf) — moongate lunar-phase travel confirmation
- [Ultima Online: Lord Blackthorn's Revenge official strategy guide (archive.org)](https://archive.org/download/ultima-online-lord-blackthorns-revenge-official-strategy-guide_202307/Ultima%20Online%20-%20Lord%20Blackthorn%27s%20Revenge%20Official%20Strategy%20Guide.pdf) — health/damage mechanic description
- [UOGuide: Champion Spawn Altars](https://www.uoguide.com/index.php?title=Champion_Spawn_Altars) — referenced during search; not used for any number in this document

**Note on sourcing:** every number in §1–§6 traces to a repo file listed above. Web sources were consulted but nothing numeric was taken from them except where explicitly marked.
