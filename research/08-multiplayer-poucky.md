# Multiplayer a server — poučky BOKEM (2026-10-06)

> **Co je tenhle soubor:** **POUČKY** (odvozené principy), odložené **stranou**.
> Odpovídá na otázku „co se ze serverových emulátorů dá naučit, i když děláme
> singleplayer" — a co z toho platí **už teď** a co **až s multiplayrem**.
> **NEŘÍDÍ** návrh singleplayer hry: primární zdroje zadání jsou `docs/`
> a `ZADANI-*.md`. Tenhle soubor je paměť, ne zadání.
>
> **Odkud to je (měřeno 2026-10-06, klony pinované):** RunUO `71b2794`,
> ServUO `d76bf44`, ModernUO `d4531cd`, ClassicUO `ee79d7e`, Sphere `dd28a0a`.
> Rozcestník „kam pro co" je v `research/REJSTRIK-REFERENCI.md`; každý bod níž
> má `soubor:řádek`, ale **číslo řádku platí pro ten commit** (a klony jsou jen
> `--depth 1`, takže historii nevidíš).
>
> **Datum spotřeby:** až se bude navrhat síťová/LAN/co-op vrstva, nebo až se
> bude zvedat multiplayerová část našeho serveru. **Zatím se z něj nic
> neprovádělo** — u každého bodu je proto sloupec „u nás dnes" s tím, co už
> v repu je (a co ne).

## 0. Proč to má smysl číst i v singleplayeru

Singleplayer **není** „multiplayer bez sítě". Ale tři věci z těch emulátorů platí
beze zbytku, protože jsou o **vlastnictví stavu a času**, ne o paketech:

1. stav se mění na **jednom místě** (autorita) a všechno ostatní ho jen čte,
2. čas jde v **pevných krocích** a události se plánují, ne že by je někdo čekal,
3. **vstup zvenčí je nedůvěryhodný** — i když je to jen soubor nebo klávesa.

## 1. Principy (každý: zdroj → u nás → co z toho platí kdy)

| # | Princip | Zdroj (měřeno) | U nás dnes | Platí už teď? |
|---|---|---|---|---|
| 1 | **Autorita stavu je jedna.** Klient pošle *záměr* (směr, akci), server rozhodne a pošle výsledek. | `classicuo` `WalkerManager.cs:108` `DenyWalk` (vrátí souřadnice), `:125` `ConfirmWalk`; 10 nálezů `ConfirmWalk\|DenyWalk` | `sim/commands.gd` (klient → `Command`), `sim/sim_world.gd` (jediný vlastník stavu), `app/loop.gd` (jen pumpuje ticky) | **ANO** — a je to důvod, proč je simulace testovatelná bez okna |
| 2 | **Klient nesmí posílat polohu, jen směr.** ModernUO x/y/z z packetu **načte a zahodí**. | `modernuo` `Projects/UOContent/Network/Packets/IncomingMovementPackets.cs:52-55` (`// x`, `// y`, `// z`), `:57` kontrola sekvence | `Command{t:"move", dir, run}` — poloha v commandu **není** | **ANO** — kdyby tam byla, měl by klient možnost teleportovat |
| 3 | **Krok se potvrzuje po sekvencích.** Klient drží frontu kroků a umí *snap-back*, když server odmítne. | `classicuo` `WalkerManager.cs:29` `StepInfo`, `:42` `FastWalkStack`; `PlayerMobile.cs:523` `Walk`, `:668` `Send_WalkRequest` | `sim.movement` plánuje `apply_step` za 400/200 ms a **odmítá druhý krok v letu** (`reason:"busy"`); klient (Godot) predikci nemá | **NE** (a nevadí): predikce má smysl až s latencí; dnes je krok potvrzený do 400 ms |
| 4 | **Ochrana proti svévoli klienta má DVĚ nezávislé vrstvy.** Okno posledních kroků + throttler paketů. | `servuo` `Server/Mobile.cs:3081` `m_FwdMaxSteps=4`, `:3303` kontrola; `Scripts/Mobiles/PlayerMobile.cs:5925` `FastwalkThreshold=400`, `:5965` `MovementThrottle_Callback` | jen jedna vrstva: `sim.movement` (`busy` + 400 ms) | **ČÁSTEČNĚ** — druhá vrstva by byla měření času mezi kroky u vstupu |
| 5 | **Fastwalk stack je historie, ne ochrana.** V kódu je soubor, ale komentář říká, že už není potřeba. | `servuo`/`runuo` `Scripts/Misc/Fastwalk.cs:5` *„This fastwalk detection is no longer required"*; `modernuo` `IncomingMovementPackets.cs:94` *„FastWalkStack key - not used (not on EA servers)"* | nemáme (a nemáme ho zavádět) | **ANO jako past:** kód, který se tváří jako kontrola a přitom se nepoužívá, mate |
| 6 | **Prodlevy jsou pravidlo serveru; klientská konstanta téhož jména znamená něco jiného.** | RunUO `Mobile.cs:3050` (400/200/200/100) = ServUO `:3063`; `classicuo` `MovementSpeed.cs:13` `STEP_DELAY_WALK=400` vs `Constants.cs:19` `WALKING_DELAY=150` | `core/const.gd:31` `WALK_MS=400` — jedna tabulka, nikde opsané číslo | **ANO** — kdybychom vzali 150, byl by krok 2,7× rychlejší |
| 7 | **Herní logika v jednom vlákně, mezi vlákny jen fronta.** Zámek je na frontě, ne na světě. | `servuo` `Server/Main.cs:24` `class Core`, `:431` vlákno `"Timer Thread"`, `Timer.cs:131` `TimerThread`, `:354` `lock (m_Queue) m_Queue.Enqueue(t)`, `:391` `Slice()` | `sim` je jednovláknový `RefCounted`; čas jde z `core/clock.gd` (`advance`), žádné thready | **ANO** — a je to invariant, který se nesmí rozbít (žádné `await`/thread ve stavu) |
| 8 | **Dlouhý callback zdrží všechno.** Priorita 50 ms u AI a `m_BreakCount=20000` brání hladovění, ne dlouhé práci. | `servuo` `Scripts/Mobiles/AI/BaseAI.cs:3057` (`TimerPriority.FiftyMS`), `Server/Timer.cs:383` | tick je 50 ms (`Const.TICK_MS`) a `app/loop.gd` dohání max 5 ticků na frame | **ANO** — práce v ticku musí být krátká; `render` patří mimo tick |
| 9 | **„Právě jeden rodič" je invariant, ne kontrola po fakti.** Předmět nejdřív odebere z předchozího rodiče, pak přidá. | `servuo` `Server/Item.cs:759` `private object m_Parent // Mobile, Item, or null=World`, `:1536-1545`; `Container.cs:1788` `TryDropItem` | `entity.item`/`container` **ještě nejsou** — tenhle bod je pro ně zadáním | **AŽ S ITEMY** |
| 10 | **Zisk (skill/stat) se nepočítá z toho, co tvrdí klient.** Obtížnost, `GainFactor` a čas posledního zisku jsou na serveru. | `servuo` `Scripts/Misc/SkillCheck.cs:187` `CheckSkill`, `:228` `GainFactor`, `:774` `CheckGGS`, `:46` `_StatGainDelay=15 min` | `sim/entity/skills.gd` (hodnoty) + `Const.SKILL_CAP=7000`; `sim.skill_gain` ještě není | **AŽ SE SKILL GAINEM** |
| 11 | **Uzly a zdroje nemusí být objekty ve světě** — stačí buňka mřížky s počítadlem a časem obnovy. | `servuo` `Scripts/Services/Harvest/Core/HarvestBank.cs:57` `CheckRespawn`, `:72` `Consume`, `HarvestDefinition.cs:59` `x /= BankWidth` | `sim.harvest` ještě není | **AŽ S TĚŽBOU** — ušetří tisíce objektů v mapě |
| 12 | **Ekonomika je funkce, ne tabulka.** `buy = 1,90 × sell` + kolísání ±1000. | `servuo` `Scripts/VendorInfo/GenericSell.cs:128`, `Scripts/Mobiles/NPCs/BaseVendor.cs:34-35` | `sim.vendor` ještě není; `data/items.json` má `value` | **AŽ S VENDORY** |
| 13 | **Uložení světa je hranice konzistence.** Ukládá se celek (částečný save by rozbil vazby `Parent`), a má verzi dat. | `servuo` `Server/World.cs:1097` `Save()`, `:1102` `Save(bool,bool permitBackgroundWrite)`; **`InternalVersion` v tomto klonu není (0 nálezů)** | `sim_world.gd::save/load` — JSON+gzip, `version`, `data_version`, při změně dat se save **odmítne** | **ANO** — a náš `data_version` je silnější než to, co má ServUO |
| 14 | **Éra je jeden přepínač, ne roztroušené podmínky.** A „nikdy nepředpokládej éru". | `servuo` `Scripts/Misc/CurrentExpansion.cs:13` `Config.GetEnum("Expansion.CurrentExpansion", Expansion.EJ)` + `Config/Expansion.cfg:15`; `modernuo` `Projects/Server/ExpansionInfo.cs:24` + `CLAUDE.md` („never assume era") | `data/balance.json` (`stamina_drain_model`), `docs/05 §5.16` (implemented: false) | **ANO pro rozhodnutí éry** — viz otevřené rozpory v `HANDOFF.md` (skillů `implemented`) |
| 15 | **Konfigurace: klíč + default + typ na jednom místě.** | `modernuo` `Projects/Server/Configuration/ServerConfiguration.cs:43` `GetSetting(...)`, `Mobiles/Movement.cs:33` `GetOrUpdateSetting("movement.delay.walkFoot", 400)` | `data/balance.json` + konstanty v `core/const.gd` | **ANO** — ale pozor: ServUO má **dva zdroje pravdy** (default v kódu + `.cfg`); my máme hodnoty v datech a meze v kódu |
| 16 | **Vstup zvenčí se validuje, throttluje a loguje.** | `servuo` `Scripts/Accounting/AccountAttackLimiter.cs:18` `PacketHandlers.RegisterThrottler(0x80, …)`; `modernuo` `Projects/Server/Network/MovementThrottle.cs:42` (prahy 1.05/1.10, `ClientMaxUnackedMovements = 5`), 27 testů | `sim/commands.gd::validate` (typ + rozsah), `core/events.gd` (žurnál) | **ANO** jako postoj: neplatný příkaz se zahodí s hláškou, nikdy nespadne |
| 17 | **Když zavedeš cache, měj test parity se pomalou cestou.** | `modernuo` `Projects/UOContent.Tests/Tests/Engines/Pathing/StepCacheParityTests.cs` + `Engines/Pathing/Cache/StepProbe.cs` (druhá implementace téže logiky) | `render.chunk` má cache (`invalidate`), `tests/cases/render_sort.gd`; paritní test nemáme | **ANO, AŽ BUDE CACHE V SIM** — dnes je cache jen v renderu |

## 2. Co z multiplayeru pro nás **NEPLATÍ** (aby se to nepletlo)

- **Pakety, šifrování, verze klienta.** `servuo` `Server/Network/NetState.cs`, `PacketHandlers.cs`,
  `sphere` `lib/twofish/` — my máme jednu instanci klienta ve stejném procesu.
- **Účty, shardy, přihlašování, více klientů.** Není co synchronizovat.
- **Škálování podle počtu CPU.** `servuo` `Server/Main.cs:453` `ProcessorCount` ovlivňuje
  *strategii ukládání* — u nás se ukládá jeden svět a rychlost disku není kritická.
- **Guard zóny a stráže jako protiváha hráčům.** `servuo` `Server/Region.cs:753` `MakeGuard`
  existuje kvůli hráčům proti hráčům; pro nás je to jen pravidlo světa (a možná atmosféra).
- **DB/paralelní save, spawny podle regionů, domy.** Obsah, ne architektura.

## 3. Kdybychom někdy dělali LAN/co-op (startovní bod, ne plán)

Kdyby to jednou přišlo, tenhle seznam je odrazový můstek — **v tomhle pořadí**:

1. **oddělit vstup od sim** (už je: `Command` slovník) a **zakázat sim sáhnout na `Input`/`OS`/`Time`**
   (už platí, `docs/09 §9.10.4`),
2. **udělat z sim server** (autorita) a z klienta jen *predikci*: krok se aplikuje okamžitě
   a po potvrzení se případně vrátí (`classicuo` `DenyWalk`),
3. **zavést sekvence kroků** (`classicuo` `Walker.WalkSequence`) a frontu 4 kroků
   (`docs/05 §5.1.3` to už zmiňuje jako vlastnost klienta),
4. **měřit čas mezi kroky** na vstupu (druhá vrstva ochrany, `servuo` `FwdMaxSteps`,
   `modernuo` `MovementThrottle`) — teprve tehdy má smysl,
5. **save/load jako transakci** s verzí formátu a migracemi jako daty
   (`modernuo` `Migrations/*.v*.json` — 3858 manifestů vs. 0 v ServUO),
6. **testy, které umí spustit engine s reálnými daty** (`modernuo` `Server.Tests`
   s `InternalsVisibleTo` a kopií `Distribution/Data`).

**Co z toho udělat dřív, i kdyby multiplayer nikdy nepřišel:** body 1, 5 a 6.
Jsou to investice do *testovatelnosti a konzistence*, ne do sítě.
