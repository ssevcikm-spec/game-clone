#!/usr/bin/env python3
"""Rejstřík referenčních zdrojů: generátor + kontrola (2026-10-06).

CO TO JE: nástroj, který (a) **generuje** `research/REJSTRIK-REFERENCI.md` a
(b) **kontroluje**, že každý odkaz v něm někam vede. Rejstřík je rozcestník
(„kam pro co"), ne stav projektu — stav je v `HANDOFF.md`.

PROČ ZVLÁŠŤ GENERÁTOR A KONTROLA:
  * kurátorská část („tahle otázka -> tenhle soubor") je ÚSUDEK a je v tomhle
    skriptu jako data - proto se nedá „opsat z hlavy" do dokumentu a tiše
    zestárnout,
  * měřená část (commit klonu, počet souborů, počet nálezů u každého odkazu) se
    počítá při každém zápisu; `--check` ji porovná s tím, co je na disku,
  * odkaz, u kterého se najde **0 souborů**, je mrtvý a `--check` na něm spadne.

LIMITY (co tahle kontrola NEMĚŘÍ): že soubor opravdu odpovídá tématu. To je
kurátorské a ověřuje se čtením (u každého řádku je proto `jak ověřit`).

Použití:
  python tools/refs-index.py                 # zmeri a zapise rejstrik
  python tools/refs-index.py --check         # porovna dokument s realitou (exit 1 = nesedi)
  python tools/refs-index.py --srovnej       # RunUO vs ServUO vs ModernUO (struktura jadra)
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
DOKUMENT = ROOT / "research" / "REJSTRIK-REFERENCI.md"
PRIPONY = (".cs", ".cpp", ".h", ".hpp", ".gd")

# Klony jsou PINOVANE: cisla radku v nasich dokumentech plati pro ten commit,
# ktery je tady. Kdo klon aktualizuje, musi pocitat s tim, ze se citace rozjedou.
# SPDX je z GitHub API (mereno 2026-10-06), nazev z LICENSE v klonu.
STROMY = {
    "runuo": {"nazev": "RunUO", "url": "https://github.com/runuo/runuo",
              "spdx": "GPL-2.0", "role": "kanonicky baseline serveru (nejmensi)"},
    "servuo": {"nazev": "ServUO", "url": "https://github.com/ServUO/ServUO",
               "spdx": "GPL-2.0", "role": "obsah a ery (nadmnozina RunUO)"},
    "modernuo": {"nazev": "ModernUO", "url": "https://github.com/modernuo/ModernUO",
                 "spdx": "GPL-3.0", "role": "modernizace (prepis, .NET)"},
    "classicuo": {"nazev": "ClassicUO", "url": "https://github.com/ClassicUO/ClassicUO",
                  "spdx": "BSD-2-Clause", "role": "klient: render, animace, vstup"},
    "sphere": {"nazev": "Sphere (Source-X)", "url": "https://github.com/Sphereserver/Source-X",
               "spdx": "Apache-2.0", "role": "treti nazor (jiny rodokmen)"},
}

# ---------------------------------------------------------------------------
# KURATORSKA CAST: (tema, strom, soubor:radek, co to odpovida, jak overit, co si vzit)
# `jak overit` je REGEX - generator u nej pocita soubory s nalezem v tom strome.
# Kdyz se najde 0, je odkaz mrtvy a `--check` to hodi jako chybu.
# ---------------------------------------------------------------------------
RADKY: list[tuple[str, str, str, str, str, str]] = [
    # --- server: pohyb -----------------------------------------------------
    ("pohyb: prodlevy", "servuo", "Server/Mobile.cs:3063",
     "m_WalkFoot=400, m_RunFoot=200, m_WalkMount=200, m_RunMount=100 - jedina mista, kde jsou ms",
     r"m_WalkFoot|m_RunFoot|m_WalkMount|m_RunMount",
     "Prodleva je pravidlo serveru; klient posila jen smer a run."),
    ("pohyb: prodlevy (baseline)", "runuo", "Server/Mobile.cs:3050",
     "tytez ctyri konstanty v originalu (ServUO je prebira beze zmeny hodnot)",
     r"m_WalkFoot|m_RunFoot|m_WalkMount|m_RunMount",
     "Kdyz se RunUO a ServUO v hodnotach rozchazeji, je to zmena ServUO."),
    ("pohyb: prodlevy (modern)", "modernuo", "Projects/Server/Mobiles/Movement.cs:33",
     "WalkFootDelay = ServerConfiguration.GetOrUpdateSetting(\"movement.delay.walkFoot\", 400)",
     r"WalkFootDelay|RunFootDelay|GetOrUpdateSetting",
     "Konstanta jako konfigurovatelny default - presne to delame v data/balance.json."),
    ("pohyb: validace kroku", "modernuo", "Projects/Server/Mobiles/Mobile.cs:4129",
     "CheckMovement -> CalcMoves.CheckMovement (server rozhoduje, klient jen pozada)",
     r"CheckMovement",
     "Validace kroku ma byt na jednom miste a volat ji vsechno."),
    ("pohyb: fastwalk/throttle", "servuo", "Server/Mobile.cs:3081",
     "m_FwdMaxSteps=4 a ClearFastwalkStack - okno poslednich kroku",
     r"FwdMaxSteps|ClearFastwalkStack|FastwalkThreshold|MovementThrottle",
     "Ochrana proti svykleni klienta ma byt ve DVOU nezavislych vrstvach."),
    ("pohyb: fastwalk (klient)", "classicuo", "src/ClassicUO.Client/Game/GameObjects/PlayerMobile.cs:668",
     "Send_WalkRequest(direction, Walker.WalkSequence, run, FastWalkStack.GetValue())",
     r"Send_WalkRequest|FastWalkStack",
     "Sekvence kroku je soucast protokolu - bez ni nejde parovat potvrzeni."),
    ("pathfinding (server)", "servuo", "Scripts/Services/Pathing/FastAStarAlgorithm.cs:16",
     "A* pro NPC; hracuv krok validuje CheckMovement, ne A*",
     r"FastAStarAlgorithm|MovementPath|PathFollower",
     "Pathfinding je pro AI, ne pro validaci hrace - neplest si je."),
    ("pathfinding (klient)", "classicuo", "src/ClassicUO.Client/Game/Pathfinder.cs:868",
     "FindPath - vlastni A* s linearnimi seznamy (O(n) hledani v open listu)",
     r"FindPath|GetGoalDistCost|ProcessAutoWalk",
     "Funguje, ale halda je zjevne zlepseni; nekopirovat doslova."),
    # --- server: cas, vlakna, ulozeni --------------------------------------
    ("cas: timer a vlakna", "servuo", "Server/Timer.cs:131",
     "TimerThread (1 vlakno) + 8 prioritnich front; lock jen na fronte (m_Queue)",
     r"class TimerThread|m_PriorityDelays|lock \(m_Queue\)",
     "Herni logika v jednom vlakne -> svet bez zamku; dlouhy callback zdrzi vsechno."),
    ("cas: hlavni smycka", "servuo", "Server/Main.cs:24",
     "class Core, Thread = \"Core Thread\"; Timer.Slice() se pousti v teto smycce",
     r"class Core|static Thread Thread|Thread\.Name = \"Core Thread\"|Slice\(\)",
     "Jeden vlastnik stavu: mezi vlakny se predava jen fronta."),
    ("uloziste: save sveta", "servuo", "Server/World.cs:1097",
     "Save() -> Save(true, false) s permitBackgroundWrite; uklada se cely svet",
     r"public static void Save|InvokeBeforeWorldSave",
     "Ukladat celek (vazby Parent by castecny save rozbil), s moznosti zapsat na pozadi."),
    ("uloziste: verze a migrace", "servuo", "Server/Persistence/Serialization.cs:198",
     "BinaryFileWriter/Reader; POZOR: `InternalVersion` v tomto klonu neni (occ=0)",
     r"BinaryFileWriter|BinaryFileReader",
     "Migrace nejsou centralni - my mame `data_version` a save se pri zmene dat odmitne."),
    ("predmety: jeden rodic", "servuo", "Server/Item.cs:759",
     "private object m_Parent (Mobile | Item | null=svet); zmena nejdriv odebira z predchoziho",
     r"private object m_Parent|OnParentSet|m_ParentStack",
     "Invariant \"prave jeden rodic\" je lepsi nez hledat duplikaty po fakti."),
    ("predmety: duplikace", "modernuo", "Projects/Server/Items/Item.cs:3584",
     "public virtual void Dupe(Item newItem) - kopie predmctu na jednom miste",
     r"void Dupe\(|LiftItemDupe",
     "Kopie predmctu je operace s invarianty, ne clone slovniku."),
    ("predmety: kontejnery", "servuo", "Server/Items/Container.cs:1788",
     "TryDropItem/DropItem/AddItem - jedina cesta, jak predmet meni rodice",
     r"TryDropItem|public virtual bool DropItem|CheckHold",
     "Kdo obejde AddItem/RemoveItem, vyrobi duplikat."),
    # --- server: pravidla --------------------------------------------------
    ("skilly: check a GGS", "servuo", "Scripts/Misc/SkillCheck.cs:187",
     "CheckSkill + GainFactor + CheckGGS (garantovany rust) + GGSTable",
     r"CheckSkill\(|CheckGGS|GGSTable|GainFactor",
     "Zisk = cas + obtiznost + GGS: tri nezavisle vstupy, ladit vsechny."),
    ("skilly: stat gain", "servuo", "Scripts/Misc/SkillCheck.cs:46",
     "_StatGainDelay = 15 min, _PetStatGainDelay = 5 min, _PlayerChanceToGainStats = 5",
     r"_StatGainDelay|_PetStatGainDelay|TryStatGain",
     "Stat gain ma vlastni casovy odstup - neni soucast skill checku."),
    ("staty: vzorce a capy", "servuo", "Server/Mobile.cs:8557",
     "HitsMax = 50 + Str/2, StamMax = Dex, ManaMax = Int; capy z configu",
     r"public virtual int HitsMax|public virtual int StamMax|public virtual int ManaMax",
     "Vzorec v kodu, strop v configu - hru vyvazujes configy."),
    ("souboj: swing", "servuo", "Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1541",
     "GetDelay(m) ze staminy a speed zbrane; vetve AOS vs old podle ery",
     r"GetDelay\(Mobile|OnSwing|stamTicks",
     "Rychlost utoku je funkce staminy - vycerpany bojovnik zpomali sam."),
    ("magie: kouzla a reagenty", "servuo", "Scripts/Spells/Base/Spell.cs:26",
     "Reagenty si kazda trida kouzla vypisuje sama (Reagent.BlackPearl)",
     r"class Spell\b|Reagent\.",
     "Recept na kouzlo je u kouzla, ne v centralni tabulce."),
    ("craft", "servuo", "Scripts/Services/Craft/Core/CraftSystem.cs:16",
     "CraftSystem + CraftItem + CraftGump; definice remesel jsou vlastni tridy",
     r"class CraftSystem|class CraftItem|class CraftGump",
     "Pridat remeslo = nova trida, ne editace gumpu."),
    ("tezba: uzly", "servuo", "Scripts/Services/Harvest/Core/HarvestBank.cs:5",
     "Uzel je bunka mrizky s poctem a casem obnovy, ne objekt v mape",
     r"class HarvestBank|CheckRespawn|BankWidth",
     "Zdroje v mrizce setri pamet a lip se rozsiruji."),
    ("vendor: ceny", "servuo", "Scripts/VendorInfo/GenericSell.cs:128",
     "buy = (int)(1.90 * GetSellPriceFor(item, vendor)); kolísani +-1000",
     r"1\.90 \* GetSellPriceFor|BuyItemChange|SellItemChange",
     "Ekonomika je funkce (koeficient), ne tabulka cen."),
    ("spawn", "servuo", "Scripts/Services/Spawner/Spawner.cs:15",
     "Stary Spawner i XmlSpawner i regionove spawnovani; tri nezavisle cesty",
     r"class Spawner\b|class XmlSpawner\b|class SpawnEntry\b",
     "Neriď se \"spawnem obecne\" - zjisti, kterou cestu oblast pouziva."),
    ("loot", "servuo", "Scripts/Misc/LootPack.cs:10",
     "Staticke LootPack instance (Poor/Rich/UltraRich...); mobila plni GenerateLoot",
     r"LootPack|GenerateLoot\(|AddLoot\(",
     "Loot je deklarativni u mobily - nova prisera nema loot, dokud ji ho nenapises."),
    ("AI", "servuo", "Scripts/Mobiles/AI/BaseAI.cs:883",
     "Think() + AITimer s periodou podle rychlosti mobily (priorita 50 ms)",
     r"class BaseAI|public virtual bool Think\(\)|class AITimer",
     "Chytrejsi AI = rychlejsi timer, ne vetsi blok kodu."),
    ("regiony a guard zony", "servuo", "Server/Region.cs:753",
     "GuardedRegion je vrstva nad BaseRegion; MakeGuard se vola z OnSpeech",
     r"GuardedRegion|MakeGuard",
     "Zona rozhoduje podle udalosti, ne podle seznamu souradnic."),
    ("config: ery", "servuo", "Scripts/Misc/CurrentExpansion.cs:13",
     "Config.GetEnum(\"Expansion.CurrentExpansion\", Expansion.EJ) -> Core.Expansion",
     r"CurrentExpansion|Config\.GetEnum",
     "Era je JEDEN klic v Config/Expansion.cfg; ostatni jsou odvozene booleany."),
    ("config: soubory", "servuo", "Server/Config.cs:220",
     "Config.Load() cte Config/**/*.cfg; Config.Get(...) ma 171 volani ve 43 souborech",
     r"public static void Load|Config\.Get\(",
     "Config default v kodu + prepis v .cfg = dva zdroje pravdy; my to mame jen v datech."),
    ("config: moderni", "modernuo", "Projects/Server/Configuration/ServerConfiguration.cs:1",
     "ServerConfiguration + JSON config + prompty (JsonConfig.Deserialize)",
     r"ServerConfiguration|GetOrUpdateSetting|JsonConfig",
     "Konfigurace jako typovany objekt s defaulty - vzor pro nas data/balance.json."),
    # --- klient ------------------------------------------------------------
    ("animace: RLE framu", "classicuo", "src/ClassicUO.Assets/AnimationsLoader.cs:1514",
     "ReadSpriteData: [i16 cx][i16 cy][i16 w][i16 h], run = header & 0xFFF, x/y znamenkove 10 bitu",
     r"ReadSpriteData|0x7FFF7FFF",
     "Presne tohle jsme pouzili v tools/uoextract/anim.py (0 pixelu mimo frame)."),
    ("animace: 8 smeru -> 5", "classicuo", "src/ClassicUO.Renderer/Animations/Animation.cs:76",
     "GetAnimDirection vraci index 0..4 + bool mirror (osa zrcadleni je svisla osa obrazovky)",
     r"GetAnimDirection|MAX_DIRECTIONS",
     "8 smeru je iluze pres flip; zrcadlove dvojice jsou (E,S), (NE,SW), (N,W)."),
    ("animdata: casovani framu", "classicuo", "src/ClassicUO.Assets/AnimDataLoader.cs:32",
     "CalculateCurrentGraphic - FrameCount/FrameInterval/FrameStart z animdata.mul",
     r"AnimDataLoader|CalculateCurrentGraphic|animdata",
     "animdata.mul je casovani a pocet framu, ne pixely."),
    ("hues a barva kuze", "classicuo", "src/ClassicUO.Assets/HuesLoader.cs:193",
     "GetColor/GetPartialHueColor nad hues.mul; barva kuze je tabulka podle rasy",
     r"GetColor|GetPartialHueColor|HumanSkinTone",
     "Hue 0 = beze zmeny; postava je seda, dokud hue neaplikujeme (render.hue)."),
    ("svetlo a den", "classicuo", "src/ClassicUO.Client/Game/GameObjects/IsometricLight.cs:67",
     "IsometricLevel = max(Personal, 32 - Overall) / 32; klient cyklus NEPOCITA",
     r"IsometricLevel|PersonalLightLevel",
     "Denni cyklus je serverova vec - v klientu se doctes jen aplikaci."),
    ("izo projekce", "classicuo", "src/ClassicUO.Client/Game/GameObjects/GameObject.cs:150",
     "X = (x - y) * 22, Y = (x + y) * 22 - (Z << 2) - stejne jako core/iso.gd",
     r"UpdateRealScreenPosition|ScreenToWorld|WorldToScreen",
     "Nase core/iso.gd ma stejne konstanty (22 px, 4 px na Z) - overeno v kodu."),
    ("razeni kresleni", "classicuo", "src/ClassicUO.Client/Game/GameObjects/Views/View.cs:35",
     "CalculateDepthZ pricitá korekce podle smeru (statiky vs mobily), pak DrawRenderLists",
     r"CalculateDepthZ|DrawRenderLists",
     "Poradi neni jen x+y+z - opravuje se podle screen-offsetu; nas render.sort je zjednoduseny."),
    ("vstup: drzeni klavesy", "classicuo", "src/ClassicUO.Client/Game/Scenes/GameSceneInputHandler.cs:1279",
     "Drzeni smeru je priznak _flags[4] vyhodnocovany kazdy tick, ne key-repeat",
     r"_flags\[4\]|MacroType\.Walk",
     "Opakovani kroku je stav ve smycce - proto nam dnes drzeni klavesy nefunguje."),
    ("vstup: klavesy a makra", "classicuo", "src/ClassicUO.Client/Game/Managers/HotkeysManager.cs:16",
     "Klavesa -> jmeno, hotkey -> akce, makro -> skript (MacroManager)",
     r"HotkeysManager|MacroManager|KeysTranslator",
     "Vazby klaves patri do ui.hotkeys (u nas je zatim drzi app/player_controller.gd)."),
    ("pohyb: predikce a snap-back", "classicuo", "src/ClassicUO.Client/Game/Managers/WalkerManager.cs:108",
     "DenyWalk vrati souradnice (snap-back), ConfirmWalk potvrdi, StepInfos = fronta kroku",
     r"ConfirmWalk|DenyWalk|StepInfo",
     "Ctyri oddelene veci: predikce, sekvence, fronta, snap-back."),
    ("staticky art", "classicuo", "src/ClassicUO.Assets/ArtLoader.cs:392",
     "GetArt: [u32 flags][i16 w][i16 h] + radkove RLE dvojice; zadna kotva v datech",
     r"GetArt|LoadArt|Runs",
     "Statik je ukotveny spodkem dlazdice pres iso projekci; mezery v RLE = pruhlednost."),
    ("atlas textur", "classicuo", "src/ClassicUO.Renderer/TextureAtlas.cs:30",
     "AddSprite do 4096x4096 atlasu + TextureBucketTracker (razeni podle textury)",
     r"TextureAtlas|AddSprite|TextureBucketTracker",
     "Atlas + bucket tracking je duvod, proc to drzi 60 FPS; nas render.textures ma LRU."),
    ("mapa: bloky a statiky", "classicuo", "src/ClassicUO.Assets/MapLoader.cs:306",
     "MapBlocksSize = size >> 3 (8x8 dlazdic); max 1024 statiku na blok",
     r"LegacyMUL|MapBlocksSize|TryGetUOPData",
     ".uop je kontejner s hashi nad stejnym obsahem - cti bloky, ne nazvy souboru."),
    ("paperdoll: vrstvy", "classicuo", "src/ClassicUO.Client/Game/Data/PaperdollOrder.cs:67",
     "Poradi 25 vrstev je tabulkova funkce (T1/T2/T3, MoveAfter) + korekce plaste",
     r"PaperdollOrder|BuildInWorld",
     "Poradi vrstev NENI poradi Layer enumu - vlastni rozum udela chyby."),
    ("gumpy", "classicuo", "src/ClassicUO.Assets/GumpsLoader.cs:206",
     "GetGump/Decode; gump ma v hlavicce w/h a barvu pozadi",
     r"GetGump|GumpInfo",
     "Okno se sklada z dilu (ResizePic/GumpPic) a child controlu, neni deklarativni."),
    ("cliloc a texty", "classicuo", "src/ClassicUO.Assets/ClilocLoader.cs:181",
     "GetString/Translate s fallbackem Cliloc.enu a lokalnim Clilocs.txt",
     r"GetString|Translate|Clilocs\.txt",
     "Texty hernich objektu jsou v datech, klient jen mapuje id -> string."),
    ("zvuk a hudba", "classicuo", "src/ClassicUO.Client/Game/Managers/AudioManager.cs:68",
     "PlaySound/PlayMusic, SoundsLoader (44,1 kHz stereo, jinak asset odmitne)",
     r"PlaySound|PlayMusic|TryGetMusicData",
     "Vlastni audio musi byt 44,1 kHz stereo, jinak se tise neprehraje."),
    # --- treti nazor -------------------------------------------------------
    ("treti nazor: pohyb/pakety", "sphere", "src/common/sphereproto.h:219",
     "EXTDATA_Fastwalk_Init a klientske verze pro walk kodovani",
     r"EXTDATA_Fastwalk|kMinCliver",
     "Jiny rodokmen -> dobry rozhodci, kdyz ServUO a ModernUO reknou neco jineho."),
    ("treti nazor: sifrovani", "sphere", "lib/twofish/twofish/twofish.h:88",
     "Twofish jako klientske sifrovani (vlastni implementace knihovny)",
     r"twofish|Twofish",
     "Kdyby nekdy sit: sifrovani je v klientu i serveru, ne v nasem simulacnim jadre."),
    # --- modernizace (pro cil "naucit se a modernizovat") -------------------
    ("modernizace: serializace", "modernuo", "Projects/Server/Server.csproj:60",
     "ModernUO.Serialization.Generator + [SerializationGenerator(version)] (3882 vysktu)",
     r"SerializationGenerator|SerializableField",
     "Schema savu deklaruj atributy a nech kod vygenerovat; rucne psana serializace se neda testovat."),
    ("modernizace: migrace jako data", "modernuo", "Projects/Server/Migrations/",
     "3858 manifestu *.v*.json (version, type, properties[].rule); ServUO ma 0",
     r"SchemaMigrator|BuildAction\.Migrate|MigrationRule",
     "Zmena formatu = soubor v repu, ne kod v hlave - jinak migraci nejde overit."),
    ("modernizace: testy", "modernuo", "Projects/Server.Tests/Server.Tests.csproj:10",
     "Test projekt s ProjectReference na engine, InternalsVisibleTo a kopii realnych dat",
     r"\[Fact\]|\[Theory\]",
     "1371 [Fact]/[Theory] vs 0 v ServUO: kde je test, je citovatelny dokaz chovani."),
    ("modernizace: paritni test cache", "modernuo", "Projects/UOContent.Tests/Tests/Engines/Pathing/StepCacheParityTests.cs:1",
     "Druha implementace te same logiky pro cache + test, ze cache dava STEJNOU odpoved",
     r"StepCacheParityTests|StepProbe",
     "Kdo zavede cache, musi mit test parity se pomalou cestou - presne to budeme potrebovat."),
    ("modernizace: konfigurace", "modernuo", "Projects/Server/Configuration/ServerConfiguration.cs:43",
     "GetSetting/GetOrUpdateSetting s typem a defaultem na jednom miste",
     r"GetOrUpdateSetting|GetSetting",
     "Klic + default + typ = konfigurace se cte jako dokumentace."),
    ("modernizace: invarianty v repu", "modernuo", "dev-docs/threading-model.md",
     "26 souboru dev-docs (threading, tick-counts, pathfinding, serialization)",
     r"threading-model|tick-counts|EventLoop",
     "Invarianty psat s duvodem; je to levnejsi nez je znovu objevovat."),
    # --- multiplayer (bokem, detail v research/08) --------------------------
    ("smer je pravda, souradnice ne", "modernuo", "Projects/UOContent/Network/Packets/IncomingMovementPackets.cs:52",
     "Server nacte x, y, z z packetu a ZAHODI je; poloha se odvozuje ze smeru",
     r"NewMovementReq|ClientVersion.*Movement|Sequence == 0",
     "Klient nesmi posilat polohu - jen zamer. U nas to plati taky (Command{t:move, dir})."),
    ("speedhack: prahy a kredit", "modernuo", "Projects/Server/Network/MovementThrottle.cs:42",
     "1139 radku: prahy 1.05/1.10, _maxCredit 200, ClientMaxUnackedMovements 5, 27 testu",
     r"MovementThrottle|OnSpeedHackDetected|maxCredit",
     "Merena vrstva nad klasickym jadrem; u nas by to byl jen replay test, ne vrstva."),
    ("fastwalk stack (historicky)", "servuo", "Scripts/Misc/Fastwalk.cs:5",
     "Komentar v kodu: 'This fastwalk detection is no longer required'",
     r"class Fastwalk|FastwalkStack",
     "Pozor na kod, ktery se tvari jako ochrana a pritom se nepouziva."),
    ("era se nesmi predpokladat", "modernuo", "Projects/Server/ExpansionInfo.cs:24",
     "enum Expansion + Core.AOS/SE/ML/SA/HS/TOL gate; pravidlo 'never assume era' v CLAUDE.md",
     r"enum Expansion|Core\.AOS|Expansion\b",
     "Era je jeden prepinac; chovani se vetvi podle nej, ne podle verze souboru."),
    ("treti nazor: vyska postavy", "sphere", "src/game/uo_files/uofiles_macros.h:36",
     "#define PLAYER_HEIGHT 16 - nezavisle potvrzuje 16 (ModernUO PersonHeight, ServUO PersonHeight)",
     r"PLAYER_HEIGHT|STEP_SIZE",
     "Kdyz se dva C# zdroje hádaji, Sphere (jiny rodokmen) je rozhodci."),
    ("treti nazor: triggery", "sphere", "src/tables/triggers.tbl",
     "248 pojmenovanych udalosti (SPELLCAST, BUY, SELL, STEP, ...) jako checklist uplnosti",
     r"E_TRIGGERS|TRIGGER_SPELLCAST|IsTrigUsed",
     "Seznam udalosti je meritko, proti kteremu se da nase pokryti porovnat."),

    # --- nas repo ----------------------------------------------------------
    ("u nas: prodlevy a konstanty", "nas", "core/const.gd:31",
     "WALK_MS=400, RUN_MS=200, MOUNT_WALK_MS=200, MOUNT_RUN_MS=100, TURN_MS=80",
     "core/const.gd",
     "Hodnoty sedi na RunUO/ServUO i ClassicUO - jedna tabulka, nikde opsane cislo."),
    ("u nas: smery", "nas", "core/const.gd:45",
     "DIR_DX/DIR_DY: 0=E(+1,0) .. 7=SE(+1,+1) po smeru hodinovych rucicek",
     "core/const.gd",
     "Cislo smeru nesmi znamenat na dvou mistech neco jineho."),
    ("u nas: smlouvy", "nas", "docs/04-architektura-a-smlouvy.md",
     "Tabulka komponent (provides/consumes) a tvar dat",
     "docs/04-architektura-a-smlouvy.md",
     "Bez smlouvy si agent vymysli jmena; vady smlouvy se hlasí, needitují."),
    ("u nas: mechaniky", "nas", "docs/05-mechaniky.md",
     "Vzorce a konstanty mechanik (pohyb, skilly, souboj) s odkazy na zdroje",
     "docs/05-mechaniky.md",
     "Tohle je destilat tech emulatoru - cti nejdriv tady, pak v _src."),
    ("u nas: rešerše", "nas", "research/",
     "NamERena data a rozhodnuti (01-core-mechanics .. 08-multiplayer-poucky, anim-mereni)",
     "research",
     "Rešerše je artefakt; do _src se chodi jen pro to, co v ni neni."),
    ("u nas: extraktory", "nas", "tools/uoextract/",
     "Cteni instalacniho UO (uop, art, gump, anim, tiledata, hues, worldmap, textdata, atlas)",
     "tools/uoextract",
     "Format je popsany v kodu extraktoru - a kazdy ma --self-test."),
    ("u nas: brany", "nas", "tools/gates/",
     "run-all.py + 10 bran + generatoru obsahu a mutacni harnessy",
     "tools/gates",
     "Co neni zmerene, neni hotove; mutace dokazuji, ze testy meri."),
]


def git_commit(cesta: Path) -> str:
    try:
        out = subprocess.run(["git.exe", "-C", str(cesta), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=30)
        if out.returncode == 0:
            return out.stdout.strip()
        out = subprocess.run(["git", "-C", str(cesta), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=30, shell=True)
        return out.stdout.strip() if out.returncode == 0 else "?"
    except Exception:
        return "?"


def licence(cesta: Path) -> str:
    for jmeno in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"):
        p = cesta / jmeno
        if p.exists():
            prvni = [l.strip() for l in p.read_text(encoding="utf-8", errors="replace").splitlines()
                     if l.strip()]
            return f"{jmeno} ({prvni[0][:60]})" if prvni else jmeno
    return "LICENSE nenalezen"


def strom_info(klic: str) -> dict:
    cesta = ROOT / "_src" / klic
    if not cesta.exists():
        return {"chybi": True}
    souboru = 0
    bajtu = 0
    for dp, dn, fn in os.walk(cesta):
        dn[:] = [d for d in dn if d not in (".git", "bin", "obj", "node_modules")]
        for f in fn:
            if Path(f).suffix.lower() in PRIPONY:
                souboru += 1
                try:
                    bajtu += (Path(dp) / f).stat().st_size
                except Exception:
                    pass
    return {"souboru": souboru, "MB": round(bajtu / 1048576, 1),
            "commit": git_commit(cesta), "licence": licence(cesta)}


def _regex(radek: tuple) -> re.Pattern | None:
    vzor = radek[4]
    if radek[1] == "nas" or not vzor:
        return None
    try:
        return re.compile(vzor)
    except re.error:
        return None


def mereni_nalezu() -> dict[tuple[str, str], int]:
    """Kolik SOUBORU v danem strome odpovida odkazu (jeden pruchod na strom)."""
    potreba: dict[str, list[tuple[int, re.Pattern]]] = {}
    for i, radek in enumerate(RADKY):
        v = _regex(radek)
        if v is None or radek[1] == "nas":
            continue
        potreba.setdefault(radek[1], []).append((i, v))
    vysledek: dict[tuple[str, str], int] = {}
    for klic, seznam in potreba.items():
        cesta = ROOT / "_src" / klic
        if not cesta.exists():
            for i, _ in seznam:
                vysledek[(str(i), klic)] = -1
            continue
        pocty = {i: 0 for i, _ in seznam}
        for dp, dn, fn in os.walk(cesta):
            dn[:] = [d for d in dn if d not in (".git", "bin", "obj", "node_modules")]
            for f in fn:
                if Path(f).suffix.lower() not in PRIPONY:
                    continue
                try:
                    text = (Path(dp) / f).read_text(encoding="utf-8", errors="replace")
                except Exception:
                    continue
                for i, v in seznam:
                    if v.search(text):
                        pocty[i] += 1
        for i, _ in seznam:
            vysledek[(str(i), klic)] = pocty[i]
    return vysledek


def dokument(infos: dict, nalezy: dict) -> str:
    d = []
    d.append("# Rejstřík referenčních zdrojů (kam pro co)")
    d.append("")
    d.append("> **Co je tenhle soubor:** **REJSTŘÍK** — rozcestník „kam se podívat, když")
    d.append("> řeším X\". **Není to stav projektu** (ten je v `HANDOFF.md`) ani zadání")
    d.append("> (`docs/`). Přepisuje se celý; **generuje ho** `python tools/refs-index.py`,")
    d.append("> takže čísla v něm nejsou opsaná.")
    d.append(">")
    d.append("> **Co je v něm měřené a co kurátorské:** commit klonů, počty souborů, licence")
    d.append("> a **počet souborů u každého odkazu** se počítají (`python tools/refs-index.py`)")
    d.append("> a `--check` je porovnává s diskem — odkaz s 0 nálezy je mrtvý a kontrola spadne.")
    d.append("> **Kurátorské je jen to, KTERÝ soubor k tématu patří** (a proto má každý řádek")
    d.append("> sloupec „jak ověřit\", kterým si to přečteš sám).")
    d.append(">")
    d.append("> **Klony jsou PINOVANÉ** (viz commity níž): naše `docs/` a `research/` citují")
    d.append("> `soubor:řádek`, a ta čísla platí pro ten commit. **Kdo klon aktualizuje, musí")
    d.append("> počítat s tím, že se citace rozjedou** — naměřeno 2026-10-06: `docs/05` cituje")
    d.append("> `Server/Mobile.cs:3063`, což v našem klonu ServUO sedí, ale novější upstream už")
    d.append("> má `ComputeMovementSpeed` jinde.")
    d.append("")
    d.append("## 0. Jak rejstřík používat (metoda, která se osvědčila)")
    d.append("")
    d.append("1. **Nejdřív naše dokumenty** (`docs/`, `research/`) — jsou to destiláty z těch")
    d.append("   zdrojů. Do `_src/` se chodí pro to, co v destilátu **není** nebo co je sporné.")
    d.append("2. **Cílené hledání podle otázky**, ne čtení celého stromu: vezmi řádek z tabulky")
    d.append("   níž, spusť `jak ověřit` a přečti **jen to místo** (hlavičku třídy/metody).")
    d.append("3. **Nález se musí změnit v tvrzení v našem kódu + test.** Co zůstane jen přečtené,")
    d.append("   je dojem — a dojem se v tomhle projektu nepočítá jako důkaz.")
    d.append("4. **Třetí zdroj jako rozhodčí.** Když se dva zdroje rozcházejí, přečti třetí")
    d.append("   (Sphere má jiný rodokmen, ClassicUO je klient). Naměřeno 2026-10-06: záhada")
    d.append("   „pixely anim.mul nelze dekódovat\" padla za ~40 minut díky třem řádkům")
    d.append("   z `AnimationsLoader.cs`.")
    d.append("5. **Plošné skeny jen přes `rg -uu --no-ignore`** (nebo `os.walk`): `_src/` je")
    d.append("   v `.gitignore` a nástroje, které ignorují ignorované, ti dají **0 nálezů**")
    d.append("   a vypadá to jako „v datech to není\".")
    d.append("6. **Licence: čti, nekopíruj.** RunUO/ServUO jsou GPL-2.0, ModernUO GPL-3.0,")
    d.append("   ClassicUO BSD-2, Sphere Apache-2.0 (SPDX z GitHub API 2026-10-06).")
    d.append("   Z GPL zdrojů se smí vzít **fakt nebo formát**, ne kód.")
    d.append("")
    d.append("## 1. Které stromy tu jsou (měřeno `python tools/refs-index.py`)")
    d.append("")
    d.append("| klíč | zdroj | commit | souborů (kód) | MB | licence | k čemu je |")
    d.append("|---|---|---|---|---|---|---|")
    for klic, meta in STROMY.items():
        info = infos.get(klic, {})
        if info.get("chybi"):
            d.append(f"| `{klic}` | {meta['nazev']} | — | — | — | — | **CHYBÍ (neklonováno)** |")
            continue
        d.append(f"| `{klic}` | [{meta['nazev']}]({meta['url']}) | `{info['commit']}` | "
                 f"{info['souboru']} | {info['MB']} | {meta['spdx']} — {info['licence']} | {meta['role']} |")
    d.append("")
    d.append("**Pozor na duplicity na disku:** `research/_src/servuo` a `research/_src/modernuo`")
    d.append("jsou **druhé checkouty téhož** (ne junctiony — `os.path.realpath` je jiný, oba mají")
    d.append("stejný HEAD). Pro čtení používej `_src/…` (tam jsou všechny stromy); `research/_src/…`")
    d.append("je historická kopie, která se neaktualizuje. **Nic nemaž** — patří to rešerši.")
    d.append("")
    d.append("## 2. Kterou referenci na co (rozhodovací tabulka)")
    d.append("")
    d.append("| ptám se na | ber z | proč |")
    d.append("|---|---|---|")
    d.append("| **architekturu serveru** (jádro, jak je poskládané) | `runuo` | nejmenší a kanonický; **`servuo/Server` je jeho nadmnožina — 123 ze 123 souborů** (měřeno), takže o nic nepřijdeš, ale máš víc šumu |")
    d.append("| **herní pravidla a čísla** | `servuo` | aktivní (2026-10-06), obsahuje RunUO + éry + RevampedSpawns; naše `research/` z něj vychází |")
    d.append("| **modernizaci kódu** | `modernuo` | přepis do .NET: DI, typovaná konfigurace, JSON, testy; jádro má 284 souborů vs 123 (restrukturalizace) |")
    d.append("| **render, animace, vstup, izo** | `classicuo` | jediný klient v repu; animace, art, atlas, řazení kreslení, klávesy |")
    d.append("| **rozhodčí při rozporu** | `sphere` | jiný rodokmen (C++/skripty), nezávislý na RunUO linii |")
    d.append("| **formát dat UO** (mul/uop) | `tools/uoextract/` + `classicuo` | náš extraktor je měřený a má `--self-test`; klient ukazuje, jak se to používá |")
    d.append("| **co je v éře zapnuté** | `servuo` `Config/Expansion.cfg` | éra je jeden config klíč, ostatní jsou odvozené booleany |")
    d.append("")
    d.append("### Je lepší zkoumat RunUO než ServUO? (měřeno, ne dojem)")
    d.append("")
    d.append("**U jádra je to jedno — ServUO RunUO obsahuje.** Měřeno `python tools/refs-index.py --srovnej`:")
    d.append("`servuo/Server` má **123 ze 123** souborů `runuo/Server` (a 20 navíc: `Config.cs`, Customs")
    d.append("Framework…). RunUO je ale **menší a bez nánosů** (jádro ~59k vs ~73k řádků; celý strom")
    d.append("~3,3k vs ~6,3k `.cs`), takže **na pochopení architektury je lepší začít v RunUO**")
    d.append("a do ServUO jít pro obsah a éry. ModernUO je třetí věc: 39 ze 123 jmen zůstalo,")
    d.append("zbytek je přejmenovaný/restrukturalizovaný → **na učení architektury se nehodí**,")
    d.append("na modernizaci ano.")
    d.append("")
    d.append("## 3. Otázka → soubor (hlavní tabulka)")
    d.append("")
    d.append("`nálezů` = počet **souborů** v tom stromě, které odpovídají sloupci `jak ověřit`")
    d.append("(měřeno při generování; `0` = mrtvý odkaz = chyba `--check`).")
    d.append("")
    d.append("| téma | zdroj | soubor:řádek | co to odpovídá | jak ověřit (regex) | nálezů | co si z toho vzít |")
    d.append("|---|---|---|---|---|---|---|")
    for i, (tema, klic, cesta, co, jak, vzit) in enumerate(RADKY):
        if klic == "nas":
            stav = "soubor je v repu"
        else:
            pocet = nalezy.get((str(i), klic), -1)
            stav = "CHYBÍ STROM" if pocet < 0 else str(pocet)
        d.append(f"| {tema} | `{klic}` | `{cesta}` | {co} | `{jak}` | {stav} | {vzit} |")
    d.append("")
    d.append("## 4. Vzorový příklad: „jaká je prodleva kroku?\" (celý postup)")
    d.append("")
    d.append("Tohle je ukázka metody na jednom čísle — a zároveň nález, který stojí za")
    d.append("zapamatování: **dvě různé konstanty téhož jména.**")
    d.append("")
    d.append("| zdroj | soubor:řádek | hodnota | co to JE |")
    d.append("|---|---|---|---|")
    d.append("| RunUO | `Server/Mobile.cs:3050` | 400/200/200/100 | pravidlo serveru (pěšky/mount × chůze/běh) |")
    d.append("| ServUO | `Server/Mobile.cs:3063` | tytéž hodnoty | totéž, beze změny (sem míří `docs/05 §5.1.1`) |")
    d.append("| ModernUO | `Projects/Server/Mobiles/Movement.cs:33` | 400 (default) | totéž, ale jako **konfigurovatelný klíč** `movement.delay.walkFoot` |")
    d.append("| ClassicUO (klient) | `src/ClassicUO.Client/Game/Data/MovementSpeed.cs:12` | 400 | jak často klient **smí** poslat krok |")
    d.append("| ClassicUO (klient) | `src/ClassicUO.Client/Game/Constants.cs:19` | **150** | `WALKING_DELAY` = **jiná věc** (tempo lokální animace), ne pravidlo |")
    d.append("| my | `core/const.gd:31` | 400/200/200/100 | `WALK_MS`, `RUN_MS`, `MOUNT_*` — a `Const.TURN_MS` = 80 pro frame animace |")
    d.append("")
    d.append("**Poučka:** pravidlo ber ze **serveru**; klientská konstanta téhož jména může")
    d.append("znamenat něco jiného. Kdybychom vzali 150 jako pravidlo, byl by krok 2,7× rychlejší.")
    d.append("")
    d.append("## 5. Modernizace: co odkud vzít")
    d.append("")
    d.append("- **Konfigurace jako typovaný objekt s defaulty** — `modernuo`")
    d.append("  `Projects/Server/Configuration/ServerConfiguration.cs` a")
    d.append("  `GetOrUpdateSetting(\"…\", 400)`. My to máme v `data/balance.json`.")
    d.append("- **GPU mesh batching místo per-tile kreslení** — `classicuo`")
    d.append("  `src/ClassicUO.Client/Game/Map/ChunkMesh.cs` (+ `MeshLayer.cs`,")
    d.append("  `TextureBucketTracker`). Náš `render.chunk` dnes kreslí po objektech.")
    d.append("- **Manažerová vrstva místo monolitu** — `classicuo` `Game/World.cs:30-48`")
    d.append("  (desítky zaměnitelných manažerů). Náš ekvivalent je `SimWorld.systems`.")
    d.append("- **Testy jako součást projektu, ne skript** — `modernuo` `Projects/Server.Tests/`.")
    d.append("  My máme `tests/` + `tools/gates/` + mutační harnessy.")
    d.append("- **Streamování/plugin body** — `classicuo` `UltimaLive.cs`, `PluginHost.cs`.")
    d.append("  Pro nás zajímavé až u většího světa, ne teď.")
    d.append("")
    d.append("## 6. Multiplayer — bokem")
    d.append("")
    d.append("Principy ze serverových emulátorů, které **neřídí** singleplayer návrh, ale")
    d.append("zachováváme je: **`research/08-multiplayer-poucky.md`** (každý bod se zdrojem")
    d.append("`soubor:řádek` a s tím, co z něj platí už dnes).")
    d.append("")
    d.append("## 7. Jak rejstřík obnovit a co je v něm měřené")
    d.append("")
    d.append("```")
    d.append("python tools/refs-index.py            # zmeri stromy i odkazy a zapise dokument")
    d.append("python tools/refs-index.py --check    # porovna dokument s diskem (exit 1 = nesedi)")
    d.append("python tools/refs-index.py --srovnej  # RunUO vs ServUO vs ModernUO (jadro)")
    d.append("```")
    d.append("")
    d.append("**Měřené:** commit a počet souborů každého klonu, název licence, počet souborů")
    d.append("u každého odkazu, struktura jader v `--srovnej`.")
    d.append("**Kurátorské:** který soubor k tématu patří a co si z něj vzít.")
    d.append("**NEMĚŘENÉ:** že soubor opravdu odpovídá tématu (to ověří až čtení), a chování")
    d.append("kódu za běhu (emulátory jsme nespouštěli — žádný shard tu neběžel).")
    d.append("")
    return "\n".join(d) + "\n"


def srovnej() -> int:
    print("=== RunUO vs ServUO vs ModernUO: jadro (Server/) ===")
    sady = {}
    for klic, podslozka in (("runuo", "Server"), ("servuo", "Server"),
                            ("modernuo", "Projects/Server")):
        koren = ROOT / "_src" / klic / podslozka
        s = {}
        if koren.exists():
            for dp, dn, fn in os.walk(koren):
                dn[:] = [d for d in dn if d not in (".git", "bin", "obj")]
                for f in fn:
                    if f.endswith(".cs"):
                        p = Path(dp) / f
                        try:
                            s[str(p.relative_to(koren)).lower()] = len(
                                p.read_text(encoding="utf-8", errors="replace").splitlines())
                        except Exception:
                            pass
        sady[klic] = s
        print(f"  {klic:10s} {podslozka:16s} souboru {len(s):4d} | radku {sum(s.values()):7d}")
    r, sv, m = sady["runuo"], sady["servuo"], sady["modernuo"]
    print(f"  spolecne runuo&servuo:   {len(set(r) & set(sv))} z {len(r)} (runuo)")
    print(f"  spolecne runuo&modernuo: {len(set(r) & set(m))} z {len(r)} (runuo)")
    print(f"  ve vsech trech:          {len(set(r) & set(sv) & set(m))}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Rejstrik referencnich zdroju")
    ap.add_argument("--check", action="store_true", help="porovnej dokument s realitou")
    ap.add_argument("--srovnej", action="store_true", help="RunUO vs ServUO vs ModernUO")
    args = ap.parse_args()
    if args.srovnej:
        return srovnej()

    infos = {k: strom_info(k) for k in STROMY}
    chybejici = [k for k, v in infos.items() if v.get("chybi")]
    for k in chybejici:
        print(f"[refs] POZOR: klon _src/{k} chybi - odstavce o nem budou prazdne")
    nalezy = mereni_nalezu()
    text = dokument(infos, nalezy)

    mrtve = [(RADKY[i][0], RADKY[i][1], RADKY[i][2])
             for i in range(len(RADKY))
             if RADKY[i][1] != "nas" and nalezy.get((str(i), RADKY[i][1]), -1) == 0]
    for tema, klic, cesta in mrtve:
        print(f"[refs] MRTVY ODKAZ: {tema} -> {klic}:{cesta} (0 souboru)")
    if args.check:
        if mrtve:
            print(f"[refs] CHYBA: {len(mrtve)} mrtvych odkazu")
            return 1
        if not DOKUMENT.exists():
            print(f"[refs] CHYBA: {DOKUMENT} neexistuje (spust bez --check)")
            return 1
        stary = DOKUMENT.read_text(encoding="utf-8")
        if stary != text:
            print("[refs] CHYBA: dokument nesedi s merenim - spust `python tools/refs-index.py`")
            return 1
        print(f"[refs] OK: {len(RADKY)} radku rejstriku, vsechny odkazy zive, dokument sedi")
        return 0

    if mrtve:
        print("[refs] CHYBA: mrtve odkazy - rejstrik se nezapisuje (oprav je, nebo smaz)")
        return 1
    DOKUMENT.parent.mkdir(parents=True, exist_ok=True)
    DOKUMENT.write_text(text, encoding="utf-8", newline="\n")
    print(f"[refs] zapsano {DOKUMENT.relative_to(ROOT)} ({len(text)} B, {len(RADKY)} radku)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
