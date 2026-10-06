# Rejstřík referenčních zdrojů (kam pro co)

> **Co je tenhle soubor:** **REJSTŘÍK** — rozcestník „kam se podívat, když
> řeším X". **Není to stav projektu** (ten je v `HANDOFF.md`) ani zadání
> (`docs/`). Přepisuje se celý; **generuje ho** `python tools/refs-index.py`,
> takže čísla v něm nejsou opsaná.
>
> **Co je v něm měřené a co kurátorské:** commit klonů, počty souborů, licence
> a **počet souborů u každého odkazu** se počítají (`python tools/refs-index.py`)
> a `--check` je porovnává s diskem — odkaz s 0 nálezy je mrtvý a kontrola spadne.
> **Kurátorské je jen to, KTERÝ soubor k tématu patří** (a proto má každý řádek
> sloupec „jak ověřit", kterým si to přečteš sám).
>
> **Klony jsou PINOVANÉ** (viz commity níž): naše `docs/` a `research/` citují
> `soubor:řádek`, a ta čísla platí pro ten commit. **Kdo klon aktualizuje, musí
> počítat s tím, že se citace rozjedou** — naměřeno 2026-10-06: `docs/05` cituje
> `Server/Mobile.cs:3063`, což v našem klonu ServUO sedí, ale novější upstream už
> má `ComputeMovementSpeed` jinde.

## 0. Jak rejstřík používat (metoda, která se osvědčila)

1. **Nejdřív naše dokumenty** (`docs/`, `research/`) — jsou to destiláty z těch
   zdrojů. Do `_src/` se chodí pro to, co v destilátu **není** nebo co je sporné.
2. **Cílené hledání podle otázky**, ne čtení celého stromu: vezmi řádek z tabulky
   níž, spusť `jak ověřit` a přečti **jen to místo** (hlavičku třídy/metody).
3. **Nález se musí změnit v tvrzení v našem kódu + test.** Co zůstane jen přečtené,
   je dojem — a dojem se v tomhle projektu nepočítá jako důkaz.
4. **Třetí zdroj jako rozhodčí.** Když se dva zdroje rozcházejí, přečti třetí
   (Sphere má jiný rodokmen, ClassicUO je klient). Naměřeno 2026-10-06: záhada
   „pixely anim.mul nelze dekódovat" padla za ~40 minut díky třem řádkům
   z `AnimationsLoader.cs`.
5. **Plošné skeny jen přes `rg -uu --no-ignore`** (nebo `os.walk`): `_src/` je
   v `.gitignore` a nástroje, které ignorují ignorované, ti dají **0 nálezů**
   a vypadá to jako „v datech to není".
6. **Licence: čti, nekopíruj.** RunUO/ServUO jsou GPL-2.0, ModernUO GPL-3.0,
   ClassicUO BSD-2, Sphere Apache-2.0 (SPDX z GitHub API 2026-10-06).
   Z GPL zdrojů se smí vzít **fakt nebo formát**, ne kód.

## 1. Které stromy tu jsou (měřeno `python tools/refs-index.py`)

| klíč | zdroj | commit | souborů (kód) | MB | licence | k čemu je |
|---|---|---|---|---|---|---|
| `runuo` | [RunUO](https://github.com/runuo/runuo) | `71b2794` | 3348 | 13.4 | GPL-2.0 — LICENSE (GNU GENERAL PUBLIC LICENSE) | kanonicky baseline serveru (nejmensi) |
| `servuo` | [ServUO](https://github.com/ServUO/ServUO) | `d76bf44` | 6323 | 34.3 | GPL-2.0 — LICENSE (GNU GENERAL PUBLIC LICENSE) | obsah a ery (nadmnozina RunUO) |
| `modernuo` | [ModernUO](https://github.com/modernuo/ModernUO) | `d4531cd` | 4214 | 16.6 | GPL-3.0 — LICENSE (Copyright 2019-2020 ModernUO Development Team (Kamron Batman) | modernizace (prepis, .NET) |
| `classicuo` | [ClassicUO](https://github.com/ClassicUO/ClassicUO) | `ee79d7e` | 455 | 5.0 | BSD-2-Clause — LICENSE.md (BSD 2-Clause License) | klient: render, animace, vstup |
| `sphere` | [Sphere (Source-X)](https://github.com/Sphereserver/Source-X) | `dd28a0a` | 531 | 8.2 | Apache-2.0 — LICENSE (Apache License) | treti nazor (jiny rodokmen) |

**Pozor na duplicity na disku:** `research/_src/servuo` a `research/_src/modernuo`
jsou **druhé checkouty téhož** (ne junctiony — `os.path.realpath` je jiný, oba mají
stejný HEAD). Pro čtení používej `_src/…` (tam jsou všechny stromy); `research/_src/…`
je historická kopie, která se neaktualizuje. **Nic nemaž** — patří to rešerši.

## 2. Kterou referenci na co (rozhodovací tabulka)

| ptám se na | ber z | proč |
|---|---|---|
| **architekturu serveru** (jádro, jak je poskládané) | `runuo` | nejmenší a kanonický; **`servuo/Server` je jeho nadmnožina — 123 ze 123 souborů** (měřeno), takže o nic nepřijdeš, ale máš víc šumu |
| **herní pravidla a čísla** | `servuo` | aktivní (2026-10-06), obsahuje RunUO + éry + RevampedSpawns; naše `research/` z něj vychází |
| **modernizaci kódu** | `modernuo` | přepis do .NET: DI, typovaná konfigurace, JSON, testy; jádro má 284 souborů vs 123 (restrukturalizace) |
| **render, animace, vstup, izo** | `classicuo` | jediný klient v repu; animace, art, atlas, řazení kreslení, klávesy |
| **rozhodčí při rozporu** | `sphere` | jiný rodokmen (C++/skripty), nezávislý na RunUO linii |
| **formát dat UO** (mul/uop) | `tools/uoextract/` + `classicuo` | náš extraktor je měřený a má `--self-test`; klient ukazuje, jak se to používá |
| **co je v éře zapnuté** | `servuo` `Config/Expansion.cfg` | éra je jeden config klíč, ostatní jsou odvozené booleany |

### Je lepší zkoumat RunUO než ServUO? (měřeno, ne dojem)

**U jádra je to jedno — ServUO RunUO obsahuje.** Měřeno `python tools/refs-index.py --srovnej`:
`servuo/Server` má **123 ze 123** souborů `runuo/Server` (a 20 navíc: `Config.cs`, Customs
Framework…). RunUO je ale **menší a bez nánosů** (jádro ~59k vs ~73k řádků; celý strom
~3,3k vs ~6,3k `.cs`), takže **na pochopení architektury je lepší začít v RunUO**
a do ServUO jít pro obsah a éry. ModernUO je třetí věc: 39 ze 123 jmen zůstalo,
zbytek je přejmenovaný/restrukturalizovaný → **na učení architektury se nehodí**,
na modernizaci ano.

## 3. Otázka → soubor (hlavní tabulka)

`nálezů` = počet **souborů** v tom stromě, které odpovídají sloupci `jak ověřit`
(měřeno při generování; `0` = mrtvý odkaz = chyba `--check`).

| téma | zdroj | soubor:řádek | co to odpovídá | jak ověřit (regex) | nálezů | co si z toho vzít |
|---|---|---|---|---|---|---|
| pohyb: prodlevy | `servuo` | `Server/Mobile.cs:3063` | m_WalkFoot=400, m_RunFoot=200, m_WalkMount=200, m_RunMount=100 - jedina mista, kde jsou ms | `m_WalkFoot|m_RunFoot|m_WalkMount|m_RunMount` | 1 | Prodleva je pravidlo serveru; klient posila jen smer a run. |
| pohyb: prodlevy (baseline) | `runuo` | `Server/Mobile.cs:3050` | tytez ctyri konstanty v originalu (ServUO je prebira beze zmeny hodnot) | `m_WalkFoot|m_RunFoot|m_WalkMount|m_RunMount` | 1 | Kdyz se RunUO a ServUO v hodnotach rozchazeji, je to zmena ServUO. |
| pohyb: prodlevy (modern) | `modernuo` | `Projects/Server/Mobiles/Movement.cs:33` | WalkFootDelay = ServerConfiguration.GetOrUpdateSetting("movement.delay.walkFoot", 400) | `WalkFootDelay|RunFootDelay|GetOrUpdateSetting` | 37 | Konstanta jako konfigurovatelny default - presne to delame v data/balance.json. |
| pohyb: validace kroku | `modernuo` | `Projects/Server/Mobiles/Mobile.cs:4129` | CheckMovement -> CalcMoves.CheckMovement (server rozhoduje, klient jen pozada) | `CheckMovement` | 13 | Validace kroku ma byt na jednom miste a volat ji vsechno. |
| pohyb: fastwalk/throttle | `servuo` | `Server/Mobile.cs:3081` | m_FwdMaxSteps=4 a ClearFastwalkStack - okno poslednich kroku | `FwdMaxSteps|ClearFastwalkStack|FastwalkThreshold|MovementThrottle` | 4 | Ochrana proti svykleni klienta ma byt ve DVOU nezavislych vrstvach. |
| pohyb: fastwalk (klient) | `classicuo` | `src/ClassicUO.Client/Game/GameObjects/PlayerMobile.cs:668` | Send_WalkRequest(direction, Walker.WalkSequence, run, FastWalkStack.GetValue()) | `Send_WalkRequest|FastWalkStack` | 4 | Sekvence kroku je soucast protokolu - bez ni nejde parovat potvrzeni. |
| pathfinding (server) | `servuo` | `Scripts/Services/Pathing/FastAStarAlgorithm.cs:16` | A* pro NPC; hracuv krok validuje CheckMovement, ne A* | `FastAStarAlgorithm|MovementPath|PathFollower` | 8 | Pathfinding je pro AI, ne pro validaci hrace - neplest si je. |
| pathfinding (klient) | `classicuo` | `src/ClassicUO.Client/Game/Pathfinder.cs:868` | FindPath - vlastni A* s linearnimi seznamy (O(n) hledani v open listu) | `FindPath|GetGoalDistCost|ProcessAutoWalk` | 2 | Funguje, ale halda je zjevne zlepseni; nekopirovat doslova. |
| cas: timer a vlakna | `servuo` | `Server/Timer.cs:131` | TimerThread (1 vlakno) + 8 prioritnich front; lock jen na fronte (m_Queue) | `class TimerThread|m_PriorityDelays|lock \(m_Queue\)` | 1 | Herni logika v jednom vlakne -> svet bez zamku; dlouhy callback zdrzi vsechno. |
| cas: hlavni smycka | `servuo` | `Server/Main.cs:24` | class Core, Thread = "Core Thread"; Timer.Slice() se pousti v teto smycce | `class Core|static Thread Thread|Thread\.Name = \"Core Thread\"|Slice\(\)` | 31 | Jeden vlastnik stavu: mezi vlakny se predava jen fronta. |
| uloziste: save sveta | `servuo` | `Server/World.cs:1097` | Save() -> Save(true, false) s permitBackgroundWrite; uklada se cely svet | `public static void Save|InvokeBeforeWorldSave` | 29 | Ukladat celek (vazby Parent by castecny save rozbil), s moznosti zapsat na pozadi. |
| uloziste: verze a migrace | `servuo` | `Server/Persistence/Serialization.cs:198` | BinaryFileWriter/Reader; POZOR: `InternalVersion` v tomto klonu neni (occ=0) | `BinaryFileWriter|BinaryFileReader` | 11 | Migrace nejsou centralni - my mame `data_version` a save se pri zmene dat odmitne. |
| predmety: jeden rodic | `servuo` | `Server/Item.cs:759` | private object m_Parent (Mobile | Item | null=svet); zmena nejdriv odebira z predchoziho | `private object m_Parent|OnParentSet|m_ParentStack` | 1 | Invariant "prave jeden rodic" je lepsi nez hledat duplikaty po fakti. |
| predmety: duplikace | `modernuo` | `Projects/Server/Items/Item.cs:3584` | public virtual void Dupe(Item newItem) - kopie predmctu na jednom miste | `void Dupe\(|LiftItemDupe` | 10 | Kopie predmctu je operace s invarianty, ne clone slovniku. |
| predmety: kontejnery | `servuo` | `Server/Items/Container.cs:1788` | TryDropItem/DropItem/AddItem - jedina cesta, jak predmet meni rodice | `TryDropItem|public virtual bool DropItem|CheckHold` | 151 | Kdo obejde AddItem/RemoveItem, vyrobi duplikat. |
| skilly: check a GGS | `servuo` | `Scripts/Misc/SkillCheck.cs:187` | CheckSkill + GainFactor + CheckGGS (garantovany rust) + GGSTable | `CheckSkill\(|CheckGGS|GGSTable|GainFactor` | 65 | Zisk = cas + obtiznost + GGS: tri nezavisle vstupy, ladit vsechny. |
| skilly: stat gain | `servuo` | `Scripts/Misc/SkillCheck.cs:46` | _StatGainDelay = 15 min, _PetStatGainDelay = 5 min, _PlayerChanceToGainStats = 5 | `_StatGainDelay|_PetStatGainDelay|TryStatGain` | 1 | Stat gain ma vlastni casovy odstup - neni soucast skill checku. |
| staty: vzorce a capy | `servuo` | `Server/Mobile.cs:8557` | HitsMax = 50 + Str/2, StamMax = Dex, ManaMax = Int; capy z configu | `public virtual int HitsMax|public virtual int StamMax|public virtual int ManaMax` | 1 | Vzorec v kodu, strop v configu - hru vyvazujes configy. |
| souboj: swing | `servuo` | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1541` | GetDelay(m) ze staminy a speed zbrane; vetve AOS vs old podle ery | `GetDelay\(Mobile|OnSwing|stamTicks` | 17 | Rychlost utoku je funkce staminy - vycerpany bojovnik zpomali sam. |
| magie: kouzla a reagenty | `servuo` | `Scripts/Spells/Base/Spell.cs:26` | Reagenty si kazda trida kouzla vypisuje sama (Reagent.BlackPearl) | `class Spell\b|Reagent\.` | 104 | Recept na kouzlo je u kouzla, ne v centralni tabulce. |
| craft | `servuo` | `Scripts/Services/Craft/Core/CraftSystem.cs:16` | CraftSystem + CraftItem + CraftGump; definice remesel jsou vlastni tridy | `class CraftSystem|class CraftItem|class CraftGump` | 6 | Pridat remeslo = nova trida, ne editace gumpu. |
| tezba: uzly | `servuo` | `Scripts/Services/Harvest/Core/HarvestBank.cs:5` | Uzel je bunka mrizky s poctem a casem obnovy, ne objekt v mape | `class HarvestBank|CheckRespawn|BankWidth` | 8 | Zdroje v mrizce setri pamet a lip se rozsiruji. |
| vendor: ceny | `servuo` | `Scripts/VendorInfo/GenericSell.cs:128` | buy = (int)(1.90 * GetSellPriceFor(item, vendor)); kolísani +-1000 | `1\.90 \* GetSellPriceFor|BuyItemChange|SellItemChange` | 3 | Ekonomika je funkce (koeficient), ne tabulka cen. |
| spawn | `servuo` | `Scripts/Services/Spawner/Spawner.cs:15` | Stary Spawner i XmlSpawner i regionove spawnovani; tri nezavisle cesty | `class Spawner\b|class XmlSpawner\b|class SpawnEntry\b` | 5 | Neriď se "spawnem obecne" - zjisti, kterou cestu oblast pouziva. |
| loot | `servuo` | `Scripts/Misc/LootPack.cs:10` | Staticke LootPack instance (Poor/Rich/UltraRich...); mobila plni GenerateLoot | `LootPack|GenerateLoot\(|AddLoot\(` | 537 | Loot je deklarativni u mobily - nova prisera nema loot, dokud ji ho nenapises. |
| AI | `servuo` | `Scripts/Mobiles/AI/BaseAI.cs:883` | Think() + AITimer s periodou podle rychlosti mobily (priorita 50 ms) | `class BaseAI|public virtual bool Think\(\)|class AITimer` | 1 | Chytrejsi AI = rychlejsi timer, ne vetsi blok kodu. |
| regiony a guard zony | `servuo` | `Server/Region.cs:753` | GuardedRegion je vrstva nad BaseRegion; MakeGuard se vola z OnSpeech | `GuardedRegion|MakeGuard` | 23 | Zona rozhoduje podle udalosti, ne podle seznamu souradnic. |
| config: ery | `servuo` | `Scripts/Misc/CurrentExpansion.cs:13` | Config.GetEnum("Expansion.CurrentExpansion", Expansion.EJ) -> Core.Expansion | `CurrentExpansion|Config\.GetEnum` | 4 | Era je JEDEN klic v Config/Expansion.cfg; ostatni jsou odvozene booleany. |
| config: soubory | `servuo` | `Server/Config.cs:220` | Config.Load() cte Config/**/*.cfg; Config.Get(...) ma 171 volani ve 43 souborech | `public static void Load|Config\.Get\(` | 63 | Config default v kodu + prepis v .cfg = dva zdroje pravdy; my to mame jen v datech. |
| config: moderni | `modernuo` | `Projects/Server/Configuration/ServerConfiguration.cs:1` | ServerConfiguration + JSON config + prompty (JsonConfig.Deserialize) | `ServerConfiguration|GetOrUpdateSetting|JsonConfig` | 96 | Konfigurace jako typovany objekt s defaulty - vzor pro nas data/balance.json. |
| animace: RLE framu | `classicuo` | `src/ClassicUO.Assets/AnimationsLoader.cs:1514` | ReadSpriteData: [i16 cx][i16 cy][i16 w][i16 h], run = header & 0xFFF, x/y znamenkove 10 bitu | `ReadSpriteData|0x7FFF7FFF` | 1 | Presne tohle jsme pouzili v tools/uoextract/anim.py (0 pixelu mimo frame). |
| animace: 8 smeru -> 5 | `classicuo` | `src/ClassicUO.Renderer/Animations/Animation.cs:76` | GetAnimDirection vraci index 0..4 + bool mirror (osa zrcadleni je svisla osa obrazovky) | `GetAnimDirection|MAX_DIRECTIONS` | 7 | 8 smeru je iluze pres flip; zrcadlove dvojice jsou (E,S), (NE,SW), (N,W). |
| animdata: casovani framu | `classicuo` | `src/ClassicUO.Assets/AnimDataLoader.cs:32` | CalculateCurrentGraphic - FrameCount/FrameInterval/FrameStart z animdata.mul | `AnimDataLoader|CalculateCurrentGraphic|animdata` | 4 | animdata.mul je casovani a pocet framu, ne pixely. |
| hues a barva kuze | `classicuo` | `src/ClassicUO.Assets/HuesLoader.cs:193` | GetColor/GetPartialHueColor nad hues.mul; barva kuze je tabulka podle rasy | `GetColor|GetPartialHueColor|HumanSkinTone` | 11 | Hue 0 = beze zmeny; postava je seda, dokud hue neaplikujeme (render.hue). |
| svetlo a den | `classicuo` | `src/ClassicUO.Client/Game/GameObjects/IsometricLight.cs:67` | IsometricLevel = max(Personal, 32 - Overall) / 32; klient cyklus NEPOCITA | `IsometricLevel|PersonalLightLevel` | 3 | Denni cyklus je serverova vec - v klientu se doctes jen aplikaci. |
| izo projekce | `classicuo` | `src/ClassicUO.Client/Game/GameObjects/GameObject.cs:150` | X = (x - y) * 22, Y = (x + y) * 22 - (Z << 2) - stejne jako core/iso.gd | `UpdateRealScreenPosition|ScreenToWorld|WorldToScreen` | 11 | Nase core/iso.gd ma stejne konstanty (22 px, 4 px na Z) - overeno v kodu. |
| razeni kresleni | `classicuo` | `src/ClassicUO.Client/Game/GameObjects/Views/View.cs:35` | CalculateDepthZ pricitá korekce podle smeru (statiky vs mobily), pak DrawRenderLists | `CalculateDepthZ|DrawRenderLists` | 16 | Poradi neni jen x+y+z - opravuje se podle screen-offsetu; nas render.sort je zjednoduseny. |
| vstup: drzeni klavesy | `classicuo` | `src/ClassicUO.Client/Game/Scenes/GameSceneInputHandler.cs:1279` | Drzeni smeru je priznak _flags[4] vyhodnocovany kazdy tick, ne key-repeat | `_flags\[4\]|MacroType\.Walk` | 2 | Opakovani kroku je stav ve smycce - proto nam dnes drzeni klavesy nefunguje. |
| vstup: klavesy a makra | `classicuo` | `src/ClassicUO.Client/Game/Managers/HotkeysManager.cs:16` | Klavesa -> jmeno, hotkey -> akce, makro -> skript (MacroManager) | `HotkeysManager|MacroManager|KeysTranslator` | 9 | Vazby klaves patri do ui.hotkeys (u nas je zatim drzi app/player_controller.gd). |
| pohyb: predikce a snap-back | `classicuo` | `src/ClassicUO.Client/Game/Managers/WalkerManager.cs:108` | DenyWalk vrati souradnice (snap-back), ConfirmWalk potvrdi, StepInfos = fronta kroku | `ConfirmWalk|DenyWalk|StepInfo` | 4 | Ctyri oddelene veci: predikce, sekvence, fronta, snap-back. |
| staticky art | `classicuo` | `src/ClassicUO.Assets/ArtLoader.cs:392` | GetArt: [u32 flags][i16 w][i16 h] + radkove RLE dvojice; zadna kotva v datech | `GetArt|LoadArt|Runs` | 22 | Statik je ukotveny spodkem dlazdice pres iso projekci; mezery v RLE = pruhlednost. |
| atlas textur | `classicuo` | `src/ClassicUO.Renderer/TextureAtlas.cs:30` | AddSprite do 4096x4096 atlasu + TextureBucketTracker (razeni podle textury) | `TextureAtlas|AddSprite|TextureBucketTracker` | 9 | Atlas + bucket tracking je duvod, proc to drzi 60 FPS; nas render.textures ma LRU. |
| mapa: bloky a statiky | `classicuo` | `src/ClassicUO.Assets/MapLoader.cs:306` | MapBlocksSize = size >> 3 (8x8 dlazdic); max 1024 statiku na blok | `LegacyMUL|MapBlocksSize|TryGetUOPData` | 10 | .uop je kontejner s hashi nad stejnym obsahem - cti bloky, ne nazvy souboru. |
| paperdoll: vrstvy | `classicuo` | `src/ClassicUO.Client/Game/Data/PaperdollOrder.cs:67` | Poradi 25 vrstev je tabulkova funkce (T1/T2/T3, MoveAfter) + korekce plaste | `PaperdollOrder|BuildInWorld` | 4 | Poradi vrstev NENI poradi Layer enumu - vlastni rozum udela chyby. |
| gumpy | `classicuo` | `src/ClassicUO.Assets/GumpsLoader.cs:206` | GetGump/Decode; gump ma v hlavicce w/h a barvu pozadi | `GetGump|GumpInfo` | 60 | Okno se sklada z dilu (ResizePic/GumpPic) a child controlu, neni deklarativni. |
| cliloc a texty | `classicuo` | `src/ClassicUO.Assets/ClilocLoader.cs:181` | GetString/Translate s fallbackem Cliloc.enu a lokalnim Clilocs.txt | `GetString|Translate|Clilocs\.txt` | 47 | Texty hernich objektu jsou v datech, klient jen mapuje id -> string. |
| zvuk a hudba | `classicuo` | `src/ClassicUO.Client/Game/Managers/AudioManager.cs:68` | PlaySound/PlayMusic, SoundsLoader (44,1 kHz stereo, jinak asset odmitne) | `PlaySound|PlayMusic|TryGetMusicData` | 17 | Vlastni audio musi byt 44,1 kHz stereo, jinak se tise neprehraje. |
| treti nazor: pohyb/pakety | `sphere` | `src/common/sphereproto.h:219` | EXTDATA_Fastwalk_Init a klientske verze pro walk kodovani | `EXTDATA_Fastwalk|kMinCliver` | 3 | Jiny rodokmen -> dobry rozhodci, kdyz ServUO a ModernUO reknou neco jineho. |
| treti nazor: sifrovani | `sphere` | `lib/twofish/twofish/twofish.h:88` | Twofish jako klientske sifrovani (vlastni implementace knihovny) | `twofish|Twofish` | 4 | Kdyby nekdy sit: sifrovani je v klientu i serveru, ne v nasem simulacnim jadre. |
| modernizace: serializace | `modernuo` | `Projects/Server/Server.csproj:60` | ModernUO.Serialization.Generator + [SerializationGenerator(version)] (3882 vysktu) | `SerializationGenerator|SerializableField` | 2432 | Schema savu deklaruj atributy a nech kod vygenerovat; rucne psana serializace se neda testovat. |
| modernizace: migrace jako data | `modernuo` | `Projects/Server/Migrations/` | 3858 manifestu *.v*.json (version, type, properties[].rule); ServUO ma 0 | `SchemaMigrator|BuildAction\.Migrate|MigrationRule` | 2 | Zmena formatu = soubor v repu, ne kod v hlave - jinak migraci nejde overit. |
| modernizace: testy | `modernuo` | `Projects/Server.Tests/Server.Tests.csproj:10` | Test projekt s ProjectReference na engine, InternalsVisibleTo a kopii realnych dat | `\[Fact\]|\[Theory\]` | 212 | 1371 [Fact]/[Theory] vs 0 v ServUO: kde je test, je citovatelny dokaz chovani. |
| modernizace: paritni test cache | `modernuo` | `Projects/UOContent.Tests/Tests/Engines/Pathing/StepCacheParityTests.cs:1` | Druha implementace te same logiky pro cache + test, ze cache dava STEJNOU odpoved | `StepCacheParityTests|StepProbe` | 9 | Kdo zavede cache, musi mit test parity se pomalou cestou - presne to budeme potrebovat. |
| modernizace: konfigurace | `modernuo` | `Projects/Server/Configuration/ServerConfiguration.cs:43` | GetSetting/GetOrUpdateSetting s typem a defaultem na jednom miste | `GetOrUpdateSetting|GetSetting` | 58 | Klic + default + typ = konfigurace se cte jako dokumentace. |
| modernizace: invarianty v repu | `modernuo` | `dev-docs/threading-model.md` | 26 souboru dev-docs (threading, tick-counts, pathfinding, serialization) | `threading-model|tick-counts|EventLoop` | 12 | Invarianty psat s duvodem; je to levnejsi nez je znovu objevovat. |
| smer je pravda, souradnice ne | `modernuo` | `Projects/UOContent/Network/Packets/IncomingMovementPackets.cs:52` | Server nacte x, y, z z packetu a ZAHODI je; poloha se odvozuje ze smeru | `NewMovementReq|ClientVersion.*Movement|Sequence == 0` | 2 | Klient nesmi posilat polohu - jen zamer. U nas to plati taky (Command{t:move, dir}). |
| speedhack: prahy a kredit | `modernuo` | `Projects/Server/Network/MovementThrottle.cs:42` | 1139 radku: prahy 1.05/1.10, _maxCredit 200, ClientMaxUnackedMovements 5, 27 testu | `MovementThrottle|OnSpeedHackDetected|maxCredit` | 7 | Merena vrstva nad klasickym jadrem; u nas by to byl jen replay test, ne vrstva. |
| fastwalk stack (historicky) | `servuo` | `Scripts/Misc/Fastwalk.cs:5` | Komentar v kodu: 'This fastwalk detection is no longer required' | `class Fastwalk|FastwalkStack` | 4 | Pozor na kod, ktery se tvari jako ochrana a pritom se nepouziva. |
| era se nesmi predpokladat | `modernuo` | `Projects/Server/ExpansionInfo.cs:24` | enum Expansion + Core.AOS/SE/ML/SA/HS/TOL gate; pravidlo 'never assume era' v CLAUDE.md | `enum Expansion|Core\.AOS|Expansion\b` | 280 | Era je jeden prepinac; chovani se vetvi podle nej, ne podle verze souboru. |
| treti nazor: vyska postavy | `sphere` | `src/game/uo_files/uofiles_macros.h:36` | #define PLAYER_HEIGHT 16 - nezavisle potvrzuje 16 (ModernUO PersonHeight, ServUO PersonHeight) | `PLAYER_HEIGHT|STEP_SIZE` | 10 | Kdyz se dva C# zdroje hádaji, Sphere (jiny rodokmen) je rozhodci. |
| treti nazor: triggery | `sphere` | `src/tables/triggers.tbl` | 248 pojmenovanych udalosti (SPELLCAST, BUY, SELL, STEP, ...) jako checklist uplnosti | `E_TRIGGERS|TRIGGER_SPELLCAST|IsTrigUsed` | 39 | Seznam udalosti je meritko, proti kteremu se da nase pokryti porovnat. |
| u nas: prodlevy a konstanty | `nas` | `core/const.gd:31` | WALK_MS=400, RUN_MS=200, MOUNT_WALK_MS=200, MOUNT_RUN_MS=100, TURN_MS=80 | `core/const.gd` | soubor je v repu | Hodnoty sedi na RunUO/ServUO i ClassicUO - jedna tabulka, nikde opsane cislo. |
| u nas: smery | `nas` | `core/const.gd:45` | DIR_DX/DIR_DY: 0=E(+1,0) .. 7=SE(+1,+1) po smeru hodinovych rucicek | `core/const.gd` | soubor je v repu | Cislo smeru nesmi znamenat na dvou mistech neco jineho. |
| u nas: smlouvy | `nas` | `docs/04-architektura-a-smlouvy.md` | Tabulka komponent (provides/consumes) a tvar dat | `docs/04-architektura-a-smlouvy.md` | soubor je v repu | Bez smlouvy si agent vymysli jmena; vady smlouvy se hlasí, needitují. |
| u nas: mechaniky | `nas` | `docs/05-mechaniky.md` | Vzorce a konstanty mechanik (pohyb, skilly, souboj) s odkazy na zdroje | `docs/05-mechaniky.md` | soubor je v repu | Tohle je destilat tech emulatoru - cti nejdriv tady, pak v _src. |
| u nas: rešerše | `nas` | `research/` | NamERena data a rozhodnuti (01-core-mechanics .. 08-multiplayer-poucky, anim-mereni) | `research` | soubor je v repu | Rešerše je artefakt; do _src se chodi jen pro to, co v ni neni. |
| u nas: extraktory | `nas` | `tools/uoextract/` | Cteni instalacniho UO (uop, art, gump, anim, tiledata, hues, worldmap, textdata, atlas) | `tools/uoextract` | soubor je v repu | Format je popsany v kodu extraktoru - a kazdy ma --self-test. |
| u nas: brany | `nas` | `tools/gates/` | run-all.py + 10 bran + generatoru obsahu a mutacni harnessy | `tools/gates` | soubor je v repu | Co neni zmerene, neni hotove; mutace dokazuji, ze testy meri. |

## 4. Vzorový příklad: „jaká je prodleva kroku?" (celý postup)

Tohle je ukázka metody na jednom čísle — a zároveň nález, který stojí za
zapamatování: **dvě různé konstanty téhož jména.**

| zdroj | soubor:řádek | hodnota | co to JE |
|---|---|---|---|
| RunUO | `Server/Mobile.cs:3050` | 400/200/200/100 | pravidlo serveru (pěšky/mount × chůze/běh) |
| ServUO | `Server/Mobile.cs:3063` | tytéž hodnoty | totéž, beze změny (sem míří `docs/05 §5.1.1`) |
| ModernUO | `Projects/Server/Mobiles/Movement.cs:33` | 400 (default) | totéž, ale jako **konfigurovatelný klíč** `movement.delay.walkFoot` |
| ClassicUO (klient) | `src/ClassicUO.Client/Game/Data/MovementSpeed.cs:12` | 400 | jak často klient **smí** poslat krok |
| ClassicUO (klient) | `src/ClassicUO.Client/Game/Constants.cs:19` | **150** | `WALKING_DELAY` = **jiná věc** (tempo lokální animace), ne pravidlo |
| my | `core/const.gd:31` | 400/200/200/100 | `WALK_MS`, `RUN_MS`, `MOUNT_*` — a `Const.TURN_MS` = 80 pro frame animace |

**Poučka:** pravidlo ber ze **serveru**; klientská konstanta téhož jména může
znamenat něco jiného. Kdybychom vzali 150 jako pravidlo, byl by krok 2,7× rychlejší.

## 5. Modernizace: co odkud vzít

- **Konfigurace jako typovaný objekt s defaulty** — `modernuo`
  `Projects/Server/Configuration/ServerConfiguration.cs` a
  `GetOrUpdateSetting("…", 400)`. My to máme v `data/balance.json`.
- **GPU mesh batching místo per-tile kreslení** — `classicuo`
  `src/ClassicUO.Client/Game/Map/ChunkMesh.cs` (+ `MeshLayer.cs`,
  `TextureBucketTracker`). Náš `render.chunk` dnes kreslí po objektech.
- **Manažerová vrstva místo monolitu** — `classicuo` `Game/World.cs:30-48`
  (desítky zaměnitelných manažerů). Náš ekvivalent je `SimWorld.systems`.
- **Testy jako součást projektu, ne skript** — `modernuo` `Projects/Server.Tests/`.
  My máme `tests/` + `tools/gates/` + mutační harnessy.
- **Streamování/plugin body** — `classicuo` `UltimaLive.cs`, `PluginHost.cs`.
  Pro nás zajímavé až u většího světa, ne teď.

## 6. Multiplayer — bokem

Principy ze serverových emulátorů, které **neřídí** singleplayer návrh, ale
zachováváme je: **`research/08-multiplayer-poucky.md`** (každý bod se zdrojem
`soubor:řádek` a s tím, co z něj platí už dnes).

## 7. Jak rejstřík obnovit a co je v něm měřené

```
python tools/refs-index.py            # zmeri stromy i odkazy a zapise dokument
python tools/refs-index.py --check    # porovna dokument s diskem (exit 1 = nesedi)
python tools/refs-index.py --srovnej  # RunUO vs ServUO vs ModernUO (jadro)
```

**Měřené:** commit a počet souborů každého klonu, název licence, počet souborů
u každého odkazu, struktura jader v `--srovnej`.
**Kurátorské:** který soubor k tématu patří a co si z něj vzít.
**NEMĚŘENÉ:** že soubor opravdu odpovídá tématu (to ověří až čtení), a chování
kódu za běhu (emulátory jsme nespouštěli — žádný shard tu neběžel).

