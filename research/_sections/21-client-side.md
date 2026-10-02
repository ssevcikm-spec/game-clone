## 1b. Client-side skill list, groups, gumps & wire format

Client = **ClassicUO `main` @ `ee79d7eb`**, server = **ServUO `pub57` @ `d76bf444`**, cross-check = **ModernUO `main` @ `d4531cd9`** (all three read from disk with `read`/`grep`).

### 0. Citation legend (tokens used in the tables below)

| Token | Expands to (repo-relative path) | URL prefix |
|---|---|---|
| `SK` | ClassicUO:`src/ClassicUO.Client/Game/Data/Skill.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `SL` | ClassicUO:`src/ClassicUO.Assets/SkillsLoader.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `PL` | ClassicUO:`src/ClassicUO.Assets/ProfessionLoader.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `SGM` | ClassicUO:`src/ClassicUO.Client/Game/Managers/SkillsGroupManager.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `SSG` | ClassicUO:`src/ClassicUO.Client/Game/UI/Gumps/StandardSkillsGump.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `SGA` | ClassicUO:`src/ClassicUO.Client/Game/UI/Gumps/SkillGumpAdvanced.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `SBG` | ClassicUO:`src/ClassicUO.Client/Game/UI/Gumps/SkillButtonGump.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `PH` | ClassicUO:`src/ClassicUO.Client/Network/PacketHandlers.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `OP` | ClassicUO:`src/ClassicUO.Client/Network/OutgoingPackets.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `GA` | ClassicUO:`src/ClassicUO.Client/Game/GameActions.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `MM` | ClassicUO:`src/ClassicUO.Client/Game/Managers/MacroManager.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `HM` | ClassicUO:`src/ClassicUO.Client/Game/Managers/HotkeysManager.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `PMb` | ClassicUO:`src/ClassicUO.Client/Game/GameObjects/PlayerMobile.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `PR` | ClassicUO:`src/ClassicUO.Client/Configuration/Profile.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `W` | ClassicUO:`src/ClassicUO.Client/Game/World.cs` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `RG` | ClassicUO:`src/ClassicUO.Client/Resources/ResGeneral.resx` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `RGU` | ClassicUO:`src/ClassicUO.Client/Resources/ResGumps.resx` | https://github.com/ClassicUO/ClassicUO/blob/main/ |
| `SS` | ServUO:`Server/Skills.cs` | https://github.com/ServUO/ServUO/blob/pub57/ |
| `SP` | ServUO:`Server/Network/Packets.cs` | https://github.com/ServUO/ServUO/blob/pub57/ |
| `SPH` | ServUO:`Server/Network/PacketHandlers.cs` | https://github.com/ServUO/ServUO/blob/pub57/ |
| `SM` | ServUO:`Server/Mobile.cs` | https://github.com/ServUO/ServUO/blob/pub57/ |
| `SGS` | ServUO:`Scripts/Gumps/SkillsGump.cs` | https://github.com/ServUO/ServUO/blob/pub57/ |
| `SPM` | ServUO:`Scripts/Mobiles/PlayerMobile.cs` | https://github.com/ServUO/ServUO/blob/pub57/ |
| `MUS` | ModernUO:`Projects/Server/Skills.cs` | https://github.com/modernuo/ModernUO/blob/main/ |
| `MUSI` | ModernUO:`Projects/UOContent/Skills/SkillsInfo.cs` | https://github.com/modernuo/ModernUO/blob/main/ |
| `MUJ` | ModernUO:`Distribution/Data/skills.json` | https://github.com/modernuo/ModernUO/blob/main/ |

Example expansion: `SS:912` = https://github.com/ServUO/ServUO/blob/pub57/Server/Skills.cs#L912

### 1. Where the client's skill data comes from (load order) [SRC]

| # | Step | Evidence |
|---|---|---|
| 1 | Loader registered once per install | `Skills = new SkillsLoader(this)` ClassicUO:`src/ClassicUO.Assets/UOFileManager.cs:41` |
| 2 | Names come from **`skills.mul` + `Skills.idx`** (indexed MUL), *never* from code | `SL:31-32`, `SL:37-38` |
| 3 | Per entry: `ReadInt8()` = `hasAction` flag, then `entry.Length - 1` ASCII bytes = name, `TrimEnd('\0')` | `SL:47`, `SL:51-52` |
| 4 | Skill id = **positional counter** `count++` (nothing in the file stores an id) | `SL:54` |
| 5 | A second list `SortedSkills` = all skills sorted by name, `StringComparison.InvariantCulture` | `SL:57-58` |
| 6 | Player skill array is sized **once** to `SkillsCount` and never resized | `PMb:22-28` |
| 7 | Grouping is a separate file: **`skillgrp.mul`**, copied into `<profile>/skillsgroups.xml` | `SGM:280`, `SGM:199`, `SGM:253` |
| 8 | Optional: server may *replace* the whole name table at runtime via packet `0x3A` type `0xFE` | `PH:1932-1954` |

Consequence: the client has **no compile-time skill count** and **no compiled skill name table** — only the 58-member enum used for profession-config name matching (`PL:263`, see §3.2). [SRC]

### 2. Client skill GROUPS

#### 2.1 Where group ordering/membership comes from [SRC]

| Aspect | Source of truth | Evidence |
|---|---|---|
| Group count + group names (except index 0) | **`skillgrp.mul`** — `(count-1)` fixed 17-byte ASCII names | `SGM:475`, `SGM:494-520` |
| Group index 0 name | **code**: forced to `ResGeneral.Miscellaneous` ("Miscellaneous"), name is not stored in the file | `SGM:488-492` |
| Skill→group assignment | **`skillgrp.mul`** trailing `int32` per skill, in skill-id order | `SGM:522-532` |
| Group order in the window | order of `Groups` list = file order (`groups[0..count-1]`), or code order on fallback | `SGM:534-537`, `SGM:282-288` |
| Order *inside* a group | re-sorted **alphabetically by skill name** (`SortedSkills`), not by id | `SGM:98-122`, `SGM:291-294` |
| Fallback when no/invalid `skillgrp.mul` | **code-hardcoded** 7 groups | `SGM:280-289`, `SGM:542` |
| Persistence | `<profile>/skillsgroups.xml`, `<group name="…"><skillids><skill id="…"/>` | `SGM:134-154`, `SGM:229-246` |
| Max members per group | fixed `byte[60]` | `SGM:19`, `SGM:100` |

Grouping is therefore **client data first, code fallback** — not code-hardcoded, except for the 7 names/contents below. [SRC]

#### 2.2 The 7 fallback groups, in code/file order (exact name literals) [SRC]

| idx | exact name string | skill count (58-skill client) | member skill ids (as added in code, then alpha-sorted for display) |
|---|---|---|---|
| 0 | `Miscellaneous` (`RG:260-262`, value line 261) | 7 | 4, 6, 10, 12, 19, 3, 36 — `SGM:303-309` |
| 1 | `Combat` (`RG:242-244`) | 14 | 1, 31, 42, 17, 41, 5, 40, 27, 57*, 43, 50*, 51*, 52*, 53* — `SGM:320-354` |
| 2 | `Trade Skills` (`RG:245-247`, resx key `TradeSkills`, C# ident `ResGeneral.TradeSkills` `SGM:362`) | 10 | 0, 7, 8, 11, 13, 23, 44, 45, 34, 37 — `SGM:363-372` |
| 3 | `Magic` (`RG:248-250`) | 9 | 16, 56*, 25, 46, 55*, 26, 54*, 32, 49* — `SGM:383-410` |
| 4 | `Wilderness` (`RG:251-253`) | 6 | 2, 35, 18, 20, 38, 39 — `SGM:419-424` |
| 5 | `Thieving` (`RG:254-256`) | 8 | 14, 21, 24, 30, 48, 28, 33, 47 — `SGM:433-440` |
| 6 | `Bard` (`RG:257-259`) | 4 | 15, 29, 9, 22 — `SGM:449-452` |
| | **total** | **58** | 7+14+10+9+6+8+4 = 58 ✓ (no id duplicated, none missing) |

`*` = added only if `SkillsCount` passes a threshold: id 49 needs `count > 49` (`SGM:407`), 50 `> 50` (`SGM:336`), 51 `> 51` (`SGM:341`), 52 `> 52` (`SGM:346`), 53 `> 53` (`SGM:351`), 54 `> 54` (`SGM:400`), 55 `> 55` (`SGM:393`), 56 `> 56` (`SGM:385`), 57 `> 57` (`SGM:329`). So on a small/old `skills.mul` the client silently drops those ids. [SRC]

#### 2.3 `skillgrp.mul` binary layout as the client reads it [SRC] — `SGM:457-548`

| offset | size | field | note |
|---|---|---|---|
| 0 | 4 | `int32` group count | if value == `-1` → **unicode variant**: re-read `int32` count, `start = 8`, `strlen = 34` (`SGM:475-483`) |
| 4 (or 8) | 17 (or 34) × (count-1) | group names 1..count-1 | 17 bytes at `start + i*17`, NUL-terminated ASCII (or `short` chars if unicode) (`SGM:494-520`) |
| `start + (count-1)*strlen` | 4 × N skills | group index per skill | one `int32` per skill **in skill-id order**; skill id is implicit (`SGM:522-532`) |

Quirks proven by the code: index 0 is never named in the file (`SGM:488-492`); `if (grp < groups.Length && skillidx < SkillsCount)` — an out-of-range `grp` is skipped **without** advancing `skillidx`, desynchronising every later skill (`SGM:528-531`); a negative `grp` throws and the whole file falls back to CUO defaults with `"Error while reading skillgrp.mul, using CUO defaults!"` (`SGM:540-545`). Whether a real `skillgrp.mul` uses the ASCII or unicode form, and its exact stored English names, is **[UNVERIFIED]** — measurement: hexdump the 4-byte header of a real `skillgrp.mul` (expect `7`, or `-1` then `7`). [UNVERIFIED]

#### 2.4 Server-side groupings for comparison (do **not** confuse with client groups)

**ServUO `SkillsGump` (staff gump) groups, in file order** — `SGS:421-504`, members re-sorted by `SkillInfo.Table[i].Name` (`SGS:512`, `SGS:537-553`): [SRC]

| idx | name string | count | members (SkillName) |
|---|---|---|---|
| 0 | `Crafting` (`SGS:425`) | 10 | Alchemy, Blacksmith, Cartography, Carpentry, Cooking, Fletching, Inscribe, Tailoring, Tinkering, Imbuing |
| 1 | `Bardic` (`SGS:438`) | 4 | Discordance, Musicianship, Peacemaking, Provocation |
| 2 | `Magical` (`SGS:445`) | 11 | Chivalry, EvalInt, Magery, MagicResist, Meditation, Necromancy, SpiritSpeak, Ninjitsu, Bushido, Spellweaving, Mysticism |
| 3 | `Miscellaneous` (`SGS:459`) | 10 | Camping, Fishing, Focus, Healing, Herding, Lockpicking, Lumberjacking, Mining, Snooping, Veterinary |
| 4 | `Combat Ratings` (`SGS:472`) | 8 | Archery, Fencing, Macing, Parry, Swords, Tactics, Wrestling, Throwing |
| 5 | `Actions` (`SGS:483`) | 9 | AnimalTaming, Begging, DetectHidden, Hiding, RemoveTrap, Poisoning, Stealing, Stealth, Tracking |
| 6 | `Lore & Knowledge` (`SGS:495`) | 6 | Anatomy, AnimalLore, ArmsLore, Forensics, ItemID, TasteID |

ModernUO's gump uses **the same 7 names and the same members** (ModernUO:`Projects/UOContent/Gumps/SkillsGump.cs:370-465`), sorted with `string.CompareOrdinal` (ibid.:474). So the user-guessed names `Combat/Magery/Bardic/Crafting/Wilderness/Lore|Knowledge/Misc` are the **server** gump names, and only `Bardic`/`Crafting`/`Miscellaneous`/`Lore & Knowledge` exist there — there is no `Wilderness` or `Magery` group in the server gump. [SRC]

**ServUO `SkillCat` enum = the *client* `skillgrp` categories** — `ServUO:Scripts/Skills/SkillCat.cs:5-15`: `None, Miscellaneous, Combat, TradeSkills, Magic, Wilderness, Thievery, Bard` (7 real categories + `None`), filled in ModernUO/ServUO by `Scripts/Items/Books/SpecialScrollBooks/ScrollOfAlacrityBook.cs:55-61`. [SRC]

| `SkillCat` name | count | members (ids) | identical to client group #? |
|---|---|---|---|
| `Miscellaneous` | 7 | 4, 6, 10, 12, 19, 3, 36 | **yes** = client group 0 |
| `Combat` | 11 | 1, 31, 42, 50, 17, 41, 5, 40, 27, 57, 43 | no — missing 51, 52, 53 |
| `TradeSkills` | 10 | 0, 7, 8, 11, 13, 23, 44, 45, 34, 37 | **yes** = client group 2 |
| `Magic` | 12 | 52, 51, 16, 56, 25, 46, 55, 49, 53, 26, 54, 32 | no — has extra 51, 52, 53 |
| `Wilderness` | 6 | 2, 35, 18, 20, 38, 39 | **yes** = client group 4 |
| `Thievery` | 8 | 14, 21, 24, 30, 48, 28, 33, 47 | **yes** = client group 5 (name spelled *Thieving* in client) |
| `Bard` | 4 | 15, 29, 9, 22 | **yes** = client group 6 |

Only divergence: **Chivalry (51), Bushido (52), Ninjitsu (53)** are `Combat` in the client's defaults (`SGM:341-354`) but `Magic` in `SkillCat` (`ScrollOfAlacrityBook.cs:58`). [SRC]

### 3. Skill ids 0..57 — master table

#### 3.1 The 58 rows [SRC]

Client "name as shown" = `SkillEntry.Name` read from `skills.mul` (`SL:52-54`) → `Skill.Name` (`SK:39`) → gump `Label(skill.Name, …)` (`SSG:819`, `SBG:65-84`). There is **no separate client short name** anywhere in ClassicUO; the single display string is that byte string. The column *CUO code name* is the code-side canonical enum (`SL:90-149`) which the client itself uses only for profession-config matching (`PL:263`). ModernUO `ProfessionSkillName` is the server's copy of that legacy/client name (`MUJ` per-id line, formula `16*id+14`).

| # | CUO code name (`SL:92-149`) | CUO macro list (`MM:31-37`) | ServUO Callback set (`Scripts/Skills/*`) | ServUO `SkillName` (`SS:28-88`) | ServUO `SkillInfo.Name` (`SS:596-653`) | ModernUO Name / ProfessionSkillName (`MUJ`) |
|---|---|---|---|---|---|---|
| 0 | Alchemy | – | – | Alchemy | Alchemy | Alchemy / Alchemy (`MUJ:4,14`) |
| 1 | Anatomy | Y | Y | Anatomy | Anatomy | Anatomy / Anatomy (`MUJ:20,30`) |
| 2 | AnimalLore | Y | Y | AnimalLore | Animal Lore | Animal Lore / AnimalLore (`MUJ:36,46`) |
| 3 | ItemID | Y | Y | ItemID | Item Identification | Item Identification / ItemID (`MUJ:52,62`) |
| 4 | ArmsLore | Y | Y | ArmsLore | Arms Lore | Arms Lore / ArmsLore (`MUJ:68,78`) |
| 5 | Parrying | – | – | Parry | Parrying | Parrying / Parrying (`MUJ:84,94`) |
| 6 | Begging | Y | Y | Begging | Begging | Begging / Begging (`MUJ:100,110`) |
| 7 | Blacksmith | – | – | Blacksmith | Blacksmithy | Blacksmithy / Blacksmith (`MUJ:116,126`) |
| 8 | Bowcraft | – | – | Fletching | Bowcraft/Fletching | Bowcraft/Fletching / Bowcraft (`MUJ:132,142`) |
| 9 | Peacemaking | Y | Y | Peacemaking | Peacemaking | Peacemaking / Peacemaking (`MUJ:148,158`) |
| 10 | Camping | – | – | Camping | Camping | Camping / Camping (`MUJ:164,174`) |
| 11 | Carpentry | – | – | Carpentry | Carpentry | Carpentry / Carpentry (`MUJ:180,190`) |
| 12 | Cartography | Y | **–** | Cartography | Cartography | Cartography / Cartography (`MUJ:196,206`) |
| 13 | Cooking | – | – | Cooking | Cooking | Cooking / Cooking (`MUJ:212,222`) |
| 14 | DetectHidden | Y | Y | DetectHidden | Detecting Hidden | Detecting Hidden / DetectingHidden (`MUJ:228,238`) |
| 15 | **Enticement** | Y | Y | Discordance | Discordance | Discordance / Enticement (`MUJ:244,254`) |
| 16 | EvaluateIntelligence | Y | Y | EvalInt | Evaluating Intelligence | Evaluating Intelligence / EvaluateIntelligence (`MUJ:260,270`) |
| 17 | Healing | – | – | Healing | Healing | Healing / Healing (`MUJ:276,286`) |
| 18 | Fishing | – | – | Fishing | Fishing | Fishing / Fishing (`MUJ:292,302`) |
| 19 | ForensicEvaluation | Y | Y | Forensics | Forensic Evaluation | Forensic Evaluation / ForensicEvaluation (`MUJ:308,318`) |
| 20 | Herding | – | – | Herding | Herding | Herding / Herding (`MUJ:324,334`) |
| 21 | Hiding | Y | Y | Hiding | Hiding | Hiding / Hiding (`MUJ:340,350`) |
| 22 | Provocation | Y | Y | Provocation | Provocation | Provocation / Provocation (`MUJ:356,366`) |
| 23 | Inscription | Y | Y | Inscribe | Inscription | Inscription / Inscription (`MUJ:372,382`) |
| 24 | Lockpicking | – | – | Lockpicking | Lockpicking | Lockpicking / Lockpicking (`MUJ:388,398`) |
| 25 | Magery | – | – | Magery | Magery | Magery / Magery (`MUJ:404,414`) |
| 26 | ResistingSpells | – | – | MagicResist | Resisting Spells | Resisting Spells / ResistingSpells (`MUJ:420,430`) |
| 27 | Tactics | – | – | Tactics | Tactics | Tactics / Tactics (`MUJ:436,446`) |
| 28 | Snooping | – | – | Snooping | Snooping | Snooping / Snooping (`MUJ:452,462`) |
| 29 | **Musicanship** (sic) | – | – | Musicianship | Musicianship | Musicianship / Musicianship (`MUJ:468,478`) |
| 30 | Poisoning | Y | Y | Poisoning | Poisoning | Poisoning / Poisoning (`MUJ:484,494`) |
| 31 | Archery | – | – | Archery | Archery | Archery / Archery (`MUJ:500,510`) |
| 32 | SpiritSpeak | Y | Y | SpiritSpeak | Spirit Speak | Spirit Speak / SpiritSpeak (`MUJ:516,526`) |
| 33 | Stealing | Y | Y | Stealing | Stealing | Stealing / Stealing (`MUJ:532,542`) |
| 34 | Tailoring | – | – | Tailoring | Tailoring | Tailoring / Tailoring (`MUJ:548,558`) |
| 35 | AnimalTaming | Y | Y | AnimalTaming | Animal Taming | Animal Taming / AnimalTaming (`MUJ:564,574`) |
| 36 | TasteIdentification | Y | Y | TasteID | Taste Identification | Taste Identification / TasteIdentification (`MUJ:580,590`) |
| 37 | Tinkering | – | – | Tinkering | Tinkering | Tinkering / Tinkering (`MUJ:596,606`) |
| 38 | Tracking | Y | Y | Tracking | Tracking | Tracking / Tracking (`MUJ:612,622`) |
| 39 | Veterinary | – | – | Veterinary | Veterinary | Veterinary / Veterinary (`MUJ:628,638`) |
| 40 | Swordsmanship | – | – | Swords | Swordsmanship | Swordsmanship / Swordsmanship (`MUJ:644,654`) |
| 41 | MaceFighting | – | – | Macing | Mace Fighting | Mace Fighting / MaceFighting (`MUJ:660,670`) |
| 42 | Fencing | – | – | Fencing | Fencing | Fencing / Fencing (`MUJ:676,686`) |
| 43 | Wrestling | – | – | Wrestling | Wrestling | Wrestling / Wrestling (`MUJ:692,702`) |
| 44 | Lumberjacking | – | – | Lumberjacking | Lumberjacking | Lumberjacking / Lumberjacking (`MUJ:708,718`) |
| 45 | Mining | – | – | Mining | Mining | Mining / Mining (`MUJ:724,734`) |
| 46 | Meditation | Y | Y | Meditation | Meditation | Meditation / Meditation (`MUJ:740,750`) |
| 47 | Stealth | Y | Y | Stealth | Stealth | Stealth / Stealth (`MUJ:756,766`) |
| 48 | **Disarm** | Y | Y | RemoveTrap | Remove Trap | Remove Trap / Disarm (`MUJ:772,782`) |
| 49 | Necromancy | – | – | Necromancy | Necromancy | Necromancy / Necromancy (`MUJ:788,798`) |
| 50 | Focus | – | – | Focus | Focus | Focus / Focus (`MUJ:804,814`) |
| 51 | Chivalry | – | – | Chivalry | Chivalry | Chivalry / Chivalry (`MUJ:820,830`) |
| 52 | Bushido | – | – | Bushido | Bushido | Bushido / Bushido (`MUJ:836,846`) |
| 53 | Ninjitsu | – | – | Ninjitsu | Ninjitsu | Ninjitsu / Ninjitsu (`MUJ:852,862`) |
| 54 | Spellweaving | – | – | Spellweaving | Spellweaving | Spellweaving / Spellweaving (`MUJ:868,878`) |
| 55 | Mysticism | – | – | Mysticism | Mysticism | Mysticism / Mysticism (`MUJ:884,894`) |
| 56 | Imbuing | Y (`MM:34` comment `/*imbuing*/`) | Y | Imbuing | Imbuing | Imbuing / Imbuing (`MUJ:900,910`) |
| 57 | Throwing | – | – | Throwing | Throwing | Throwing / Throwing (`MUJ:916,926`) |

`sentinel` **CUO macro list** = the 24 ids in `MM:31-37` = `{1,2,35,4,6,12,14,15,16,19,21,56,23,3,46,9,30,22,48,32,33,47,36,38}` — the client's "Use Skill" macro dropdown, paired 1:1 with `MacroSubType` `Anatomy … Tracking` (`MM:2389-2412`). **ServUO Callback set** = 23 ids registered by `Scripts/Skills/*.cs` and `Scripts/Services/LootGeneration/Imbuing/Core/Imbuing.cs:22`. Difference = **id 12 Cartography** (client offers it, ServUO has no callback → cliloc 500014, see §6). [SRC]

#### 3.2 Does the client reserve "future"/unused slots beyond 57? — what the code proves [SRC]

| Question | Verdict | Evidence |
|---|---|---|
| Does CUO hardcode a count of 58 anywhere? | **No.** `grep -w 58` over all of `src/` finds no skill-related hit; the only skill-size constant is the group array `byte[60]` | `SGM:19`, `SGM:100`; grep result empty |
| Where does the count come from? | Number of valid entries in `skills.mul` (`SkillsCount`), or a server `0x3A`/type `0xFE` list | `SL:20`, `SL:41-55`, `PH:1932-1954` |
| Is there a code-side upper bound? | Only the 58-member enum `SkillEntry.HardCodedName` (0..57, `SL:92-149`); casting an id ≥ 58 to it yields a bogus name ⇒ profession matching silently fails | `SL:90-150`, `PL:263` |
| Are 55/56/57 special-cased as "future"? | They are gated like the other AoS/SE/ML/SA ids (`>55`,`>56`,`>57`), i.e. codes 49–57 are treated as *era-optional*, not as reserved blanks | `SGM:329-410` |
| Can the client store >58 entries if a server sends them? | Names are re-loaded (unbounded list), but `PlayerMobile.Skills` keeps its original length and the loop guards `id < world.Player.Skills.Length`, so extras are dropped | `PMb:22`, `PH:2019` |
| Do classic (pre-AoS) era bounds exist in code? | ModernUO proves the intended boundaries: `>= SA → 58`, `>= ML → 55`, `SE → 54`, `AOS → 52`, else **49** ("<= RemoveTrap") | `MUSI:10-17` |
| Are the last 3 slots really Mysticism/Imbuing/Throwing (SA 2009)? | Yes server-side: they are `PowerScroll.m_SASkills` gated by `Core.SA` | ServUO:`Scripts/Items/Consumables/PowerScroll.cs:52-57`, `:101-104` [ERA] |
| Exact content of a real `skills.mul` (58 entries? trailing blanks?) | **[UNVERIFIED]** — measurement: iterate `Skills.idx` valid entries and dump each name, or log `Client.Game.UO.FileManager.Skills.SkillsCount` (`SL:20`) once at login on a real install; alternatively send the `0xFE` list request against the shard | — |
| Were ids 55/56/57 present-but-unnamed in pre-SA clients? | **[UNVERIFIED]** — same measurement (inspect a pre-2009 `skills.mul`) | — |

Era mapping for ids 49–57 (from ModernUO's switch + ServUO's powerscroll gating) [ERA]: 49 Necromancy / 50 Focus / 51 Chivalry = **AoS (2003)**; 52 Bushido / 53 Ninjitsu = **SE (2005)**; 54 Spellweaving = **ML (2007)**; 55 Mysticism / 56 Imbuing / 57 Throwing = **SA (2009)**; 0–48 = classic. `PowerScroll.cs:33-57` literally labels the groups `m_AOSSkills`, `m_SESkills`, `m_MLSkills`, `m_SASkills`. Note the one era comment inside the client enum: `ItemID, // T2A` (`SL:95`) — **[PARTIAL]** (comment only, no gating in client code).

### 4. Cap display

#### 4.1 Where the displayed cap comes from

| Item | Value | Evidence |
|---|---|---|
| Client cap field | `Skill.CapFixed` (`ushort`), displayed as `Cap => CapFixed / 10.0f` | `SK:29`, `SK:35` |
| Default when the packet carries no cap | `ushort cap = 1000;` → **100.0** | `PH:2012`, `PH:2014-2017` |
| Which packet types carry a cap | `haveCap = type != 0 && type <= 0x03 \|\| type == 0xDF` | `PH:1929` |
| Server default per-skill cap | `1000` fixed point (= 100.0), also the "is default" sentinel for serialization | `SS:874`, `SS:195`, `SS:1049` |
| Server config | `SkillCap=1000` (individual), `TotalSkillCap=7000` (=700.0 total) | ServUO:`Config/PlayerCaps.cfg:9,13`; applied `Scripts/Misc/CharacterCreation.cs:211-217` |
| Powerscroll → 120.0 | `from.Skills[this.Skill].Cap = this.Value` where Value ∈ {105,110,115,120}; titles "Wonderous/Exalted/Mythical/Legendary" (`1049635 + level`) | ServUO:`Scripts/Items/Consumables/PowerScroll.cs:222`, `:127-141`, `:8-57` [ERA] |
| Client powerscroll special-casing | **none** — the client just prints `cap/10` with `F1`, so 120.0 shows as `120.0` and nothing marks it as scroll-raised | `SK:35`, `SSG:903-908` |
| Total-skill **cap** in the client | **never sent and never displayed.** No `SkillsCap` anywhere in `src/` (grep); the total cap lives only server-side (`m_Cap = Config.Get("PlayerCaps.TotalSkillCap", 7000)`) and is not present in any outgoing packet (`grep SkillsCap Server/Network` → only unrelated `StatCap`) | `SS:993-996`, `SM:1462-1472`, grep results |

#### 4.2 Total skill line

| Gump | Line shown | Literal | Evidence |
|---|---|---|---|
| Standard (OSI-style) | bottom comment area, one value | `_skillsLabelSum.Text = World.Player.Skills.Sum(s => _checkReal.IsChecked ? s.Base : s.Value).ToString("F1")` | `SSG:81-89`, `SSG:353-356` |
| Advanced | `"Total: "` + Real column sum + Value column sum | `ResGumps.Total` = `"Total: "` (`RGU:1024-1026`), `_totalReal.ToString("F1")` at X=220, `_totalValue.ToString("F1")` at X=300, no cap total | `SGA:176-177`, `SGA:197-199` |

There is **no "total/cap" fraction** (e.g. `700.0/700.0`) anywhere in ClassicUO. [SRC]

#### 4.3 Lock arrows (up / down / locked) and colours

| Gump | Up (0) | Down (1) | Locked (2) | Evidence |
|---|---|---|---|---|
| Standard gump button art | `0x0984` | `0x0986` | `0x082C` | `SSG:913-924` |
| Advanced gump `GumpPic` art | `0x983` | `0x985` | `0x82C` | `SGA:304-317` |
| Advanced gump *sort-order* indicator (different meaning!) | asc `0x983` | desc `0x985` | – | `SGA:117`, `SGA:140-145` |
| ServUO staff gump buttons (for comparison) | `0x983` | `0x985` | `0x82C` | `SGS:278-301` |

| Other presentation facts | Detail | Evidence |
|---|---|---|
| Click cycle (both client gumps) | Up → Down → Locked → Up (`newStatus++` in the standard gump, explicit case ladder in the advanced gump) | `SSG:857-873`, `SGA:319-344` |
| Arrow colour | arrows are gump **art** drawn with **hue 0** (`GumpPic(…, 0)` / `Button` with no hue argument) — no runtime colour | `SGA:304-315`, `SSG:807-816` |
| Text hues (standard) | name + value `0x0288`, font 9; group-name textbox font 6; total label hue `600` font 3 | `SSG:819`, `SSG:822`, `SSG:401`, `SSG:83-87` |
| Text hues (advanced) | name / Real / Base / Cap labels `1153` (= `0x481`), font 3 | `SGA:179-182`, `SGA:197` |
| Row highlight colours | drag-source row `Color.Wheat`; group header `Color.Beige` (rename state) / `Color.Bisque` | `SSG:983`, `SSG:725`, `SSG:748` |
| Gump art ids | window `0x82D`, minimised `0x839`, scroll `0x1F40`, title `0x834`, lines `0x82B`, comment `0x836`, tiled `0x0835`, new-group button `0x083A`, group collapse `0x0827`/`0x826`, use button `0x0837`/`0x0838`, checkboxes `0x938`/`0x939` (text `0x0386`) | `SSG:46-59`, `SSG:96`, `SSG:107-129`, `SSG:165`, `SSG:387`, `SSG:500`, `SSG:796` |
| Floating skill button art | `ResizePic(0x24B8)`, size 88×44, centered `Label` of the skill name | `SBG:47-85` |

#### 4.4 Gump selection, toggles and sort modes

| Feature | Detail | Evidence |
|---|---|---|
| Which skills window is used | profile `StandardSkillsGump` **default `true`**; `false` → `SkillGumpAdvanced`. Both report `GumpType.SkillMenu` | `PR:251`, `PH:1960-1988`, `PR:594-601`, `SSG:154`, `SGA:121` |
| Show-Real / Show-Caps toggles | **standard gump only**: two checkboxes `" - Show Real"` (`RGU:1049-1051`) and `" - Show Caps"` (`RGU:1052-1054`); mutually exclusive (setting one clears the other) | `SSG:107-132`, `SSG:316-338` |
| Show-Real semantics | `val = skill.Base` = the packet's `baseVal` field (server writes `s.BaseFixedPoint`) | `SSG:899-902`, `PH:2010`, `PH:2057`, `SP:2548` |
| Show-Caps semantics | `val = skill.Cap` (packet cap field) | `SSG:903-906` |
| Value formatting | standard `$"{val:F1}"` right-aligned at x = `250 - width` | `SSG:908-909` |
| Advanced gump toggles | **none** — all four columns are always visible: name, `skill.Base`, `skill.Value`, `skill.Cap`; values printed with bare `ToString()` (so `25` not `25.0`) | `SGA:179-182`, `SGA:293-302` |
| Advanced sort buttons | `"Name:"`(`RGU:1012-1013`, x40), `"Real"`(`RGU:1015-1016`, x220), `"Base"`(`RGU:1018-1019`, x300), `"Cap"`(`RGU:1021-1022`, x380); button ids `SortName=1, SortReal=2, SortBase=3, SortCap=4` | `SGA:76-111`, `SGA:247-253` |
| Sort field mapping (note the inversion) | button `Real` → property **`"Base"`**; button `Base` → property **`"Value"`**; reflection `typeof(Skill).GetProperty(_sortField)` | `SGA:22-31`, `SGA:164-167` |
| Sort direction | first click on a new field = ascending; clicking the current field toggles `_sortAsc`, and `_sortAsc == true` → `sortSkills.Reverse()` | `SGA:126-133`, `SGA:169-172` |
| Indicator | `GumpPic` `0x983` when `!_sortAsc`, `0x985` when `_sortAsc` | `SGA:140-145` |
| Default state | `OnButtonClick(SortName)` at the end of the ctor → sorted by name, indicator `0x983` | `SGA:118` |
| Per-skill quick-use button | `0x837`/`0x838` in both gumps, present only if `skill.IsClickable` | `SSG:794-802`, `SGA:281-291` |
| Skill-change feedback gate | profile `ShowSkillsChangedMessage` (default `true`) + `ShowSkillsChangedDeltaValue` (default `1`): prints `"Your skill in {0} has {1} by {2:F1}.  It is now {3:F1}."` (note the two spaces), hue `0x58` | `PR:233-234`, `PH:2029-2054`, `RG:425-433` |
| Profile `EnableSkillReport` | declared (`PR:109`) but referenced nowhere else in `src/` (grep) — dead in this revision | **[PARTIAL]** |

### 5. Use-skill flow, end to end

#### 5.1 Flow [SRC]

| # | Step | Evidence |
|---|---|---|
| 1a | Trigger: Standard gump use button `OnButtonClick(0)` | `SSG:844-849` |
| 1b | Trigger: Advanced gump use button (`Buttons.ActiveSkillUse = 1`) | `SGA:380-389`, `SGA:391-394` |
| 1c | Trigger: floating `SkillButtonGump` — single click if `CastSpellsByOneClick`, else double click (Alt suppresses) | `SBG:88-108`, `PR:186` |
| 1d | Trigger: macro `MacroType.UseSkill` → 24-entry table lookup (`skill = subCode - MacroSubType.Anatomy`, `0 <= skill < 24`), or `MacroType.LastSkill` → `LastSkillIndex` | `MM:906-924`, `MM:2127-2131`, `MM:2270,2285-2286`, `GA:22` |
| 1e | Trigger: paperdoll `Buttons.Skills` → `OpenSkills` (this only *opens the gump*: sends `0x34`) | ClassicUO:`src/ClassicUO.Client/Game/UI/Gumps/PaperdollGump.cs:611-614`, `GA:134-147` |
| 1f | Not wired: `HotkeyAction.UseSkillAnatomy … UseSkillTracking` are declared but **no** `Add(HotkeyAction.UseSkill*, …)` entry exists in the action dictionary (only `Cast*`) → `TryExecuteIfBinded` can never fire them | `HM:526-549`, `HM:24-221`, `HM:262-292` |
| 2 | `GameActions.UseSkill(index)`: `if (index >= 0) { LastSkillIndex = index; Socket.Send_UseSkill(index); }` | `GA:666-673` |
| 3 | Client packet `0x12` (see §5.2) | `OP:1134-1164` |
| 4 | Server: `Register(0x12, 0, true, TextCommand)` → `case 0x24 // Use skill` → `int.TryParse(command.Split(' ')[0])` → `Skills.UseSkill(m, skillIndex)` | `SPH:77`, `SPH:851-863` |
| 5 | Gate 1 `from.CheckAlive()`, gate 2 `from.Region.OnSkillUse(from, skillID)`, gate 3 `from.AllowSkillUse((SkillName)skillID)` — each returns `false` **silently** (no message) | `SS:893-904`; override `SPM:2238-2262` (animal form → cliloc `1070771`) |
| 6 | Range check `skillID >= 0 && skillID < SkillInfo.Table.Length` (58) | `SS:906` |
| 7 | If `info.Callback == null` → `SendLocalizedMessage(500014)` (see §6) | `SS:910`, `SS:927` |
| 8 | Delay gate: `Core.TickCount - from.NextSkillTime >= 0 && (info.UseWhileCasting \|\| from.Spell == null)`; on failure → `SendSkillMessage()` = cliloc **500118** throttled by `m_ActionMessageDelay = 125` ms | `SS:912`, `SS:922`, `SM:1855-1865`, `SM:1851` |
| 9 | `from.DisruptiveAction()` then `from.NextSkillTime = Core.TickCount + (int)(info.Callback(from)).TotalMilliseconds;` — **the delay is whatever the skill callback returns**, it is not a global constant | `SS:914-916` |
| 10 | Callback body usually sets a target, e.g. Anatomy: `m.Target = new InternalTarget(); m.SendLocalizedMessage(500321); return TimeSpan.FromSeconds(1.0);` | ServUO:`Scripts/Skills/Anatomy.cs:15-22` |
| 11 | Server → client target cursor: `Target.GetPacketFor` → `new TargetReq(this)` (packet `0x6C`, 19 bytes: allowGround, targetID, flags) | ServUO:`Server/Targeting/Target.cs:138-141`, `SP:2798-2808` |
| 12 | Client `0x6C` handler → `world.TargetManager.SetTargeting((CursorTarget)type, cursorId, (TargetType)cursorType)` → targeting cursor shown | `PH:227`, `PH:359-373` |
| 13 | Player clicks: client replies `0x6C` type `0x00` (object: `OP:1711-1718`) or type `0x01` (xyz: `OP:1758-1765`); server `TargetResponse` reads type/targetID/flags/serial/x/y/z/graphic | `OP:1686-1732`, `OP:1734-1779`, `SPH:1238-1246` |
| 14 | Result → any skill gains are pushed as `0x3A` `SkillChange` (`SS:1075-1097`, `SS:1092`) → client applies value/base/cap/lock and prints the gain message | `PH:2057-2063`, `PH:2027-2054` |

`Send_SkillsStatusRequest` (`OP:791-812`, 0x3A sender) has **no callers** in `src/` (grep) — the lock is sent through `GA:575-578` → `OP:3159-3189` instead. **[PARTIAL]** (dead in this revision)

#### 5.2 Wire layouts, in field order

**C→S `0x12` UseSkillRequest** (variable length; no dedicated ServUO class — handled in `TextCommand`) — [SRC]

| off | size | field | literal |
|---|---|---|---|
| 0 | 1 | id | `0x12` (`OP:1136`) |
| 1 | 2 | length BE (variable packet only) | patched to bytes written (`OP:1152-1156`); `Register(0x12, 0, true, …)` = length 0 ⇒ variable (`SPH:77`) |
| 3 | 1 | sub-command | `0x24` = use skill (`OP:1149`, `SPH:851`) |
| 4 | n | CP1252/ASCII argument, **NUL-terminated** | `$"{idx} 0"` — skill id, space, literal `0` (`OP:1150`); `WriteASCII(string)` appends `0x00` (`ClassicUO:src/ClassicUO.IO/StackDataWriter.cs:282-293`); server takes token 0 (`SPH:855`; ModernUO tokenizer `Projects/UOContent/Network/Packets/IncomingPlayerPackets.cs:147-148`) |

Variable-length confirmed by the client's own packet table: `-1 // 0x12` (`ClassicUO:src/ClassicUO.Client/Network/PacketsTable.cs:30`).
Sizes (incl. NUL): id 0 → `"0 0\0"` → **8 bytes** total; id 57 → `"57 0\0"` → **9 bytes**. [SRC]

**C→S `0x3A` SkillLockChange** (ServUO name: `ChangeSkillLock`) — [SRC]

| off | size | field | literal |
|---|---|---|---|
| 0 | 1 | id | `0x3A` (`OP:3161`, `OP:793`) |
| 1 | 2 | length BE | `6` (`OP:3177-3181`); variable-length per client table `-1 // 0x3A` (`ClassicUO:src/ClassicUO.Client/Network/PacketsTable.cs:70`) and `Register(0x3A, 0, true, …)` (`SPH:83`) |
| 3 | 2 | skill id | `WriteUInt16BE(skillindex)` (`OP:3174`) |
| 5 | 1 | lock state | `WriteUInt8(lockstate)`; `Lock.Up=0, Down=1, Locked=2` (`SK:7-12`) == `SkillLock.Up/Down/Locked` (`SS:21-26`) |

Server read order: `pvSrc.ReadInt16()` then `(SkillLock)pvSrc.ReadByte()` → `s.SetLockNoRelay(...)` (`SPH:1223-1231`; ModernUO identical at `Projects/UOContent/Network/Packets/IncomingPlayerPackets.cs:344-349`). `SetLockNoRelay` validates `Up..Locked` and **does not echo anything back** (`SS:183-191`), so the client updates its own copy optimistically (`SSG:869-872`, `SGA:323-343`). [SRC]

**C→S `0x34` skills request (MobileQuery type 5)** — [SRC]

| off | size | field | literal |
|---|---|---|---|
| 0 | 1 | id | `0x34` (`OP:761`) |
| 1 | 4 | magic | `0xEDEDEDED` (`OP:773`) |
| 5 | 1 | query type | `0x05` = skills (`OP:774`, `SPH:2317`) |
| 6 | 4 | serial | `serial` (`OP:775`) |

Fixed length 10 (`SPH:82`; client table `0x000A // 0x34` = `ClassicUO:src/ClassicUO.Client/Network/PacketsTable.cs:64`, so no length field is written), server reads Int32/Byte/Serial (`SPH:2290-2293`) and answers only for self: `if (from == this) Send(new SkillUpdate(m_Skills));` (`SM:12412-12418`).

**S→C `0x3A` SkillUpdate (full list, ServUO class `SkillUpdate`)** — [SRC] `SP:2521-2555`

| off | size | field | value |
|---|---|---|---|
| 0 | 1 | id | `0x3A` |
| 1 | 2 | length BE | computed |
| 3 | 1 | type | `0x02` = "absolute, capped" (`SP:2528`) |
| 4 | 9×N | per skill | `skillId + 1` (2) · `NonRacialValue*10` clamped `0..0xFFFF` (2) · `BaseFixedPoint` (2) · `Lock` (1) · `CapFixedPoint` (2) (`SP:2546-2550`) |
| … | 2 | terminator | `(short)0` (`SP:2553`) |

Capacity formula `6 + skills.Length * 9` (`SP:2526`). ModernUO is byte-identical (`Projects/Server/Network/Packets/OutgoingPlayerPackets.cs:130-148`) and is unit-tested (`Projects/UOContent.Tests/Tests/Skills/SkillPacketsTests.cs:34-50`). [SRC]

**S→C `0x3A` SkillChange (single, class `SkillChange`)** — [SRC] `SP:2566-2597`

| off | size | field | value |
|---|---|---|---|
| 0 | 1 | id | `0x3A` |
| 1 | 2 | length BE | `13` (`EnsureCapacity(13)`, ModernUO writes literal 13 at OutgoingPlayerPackets.cs:163) |
| 3 | 1 | type | `0xDF` = "delta, capped" (`SP:2585`) |
| 4 | 2 | skill id | **not** +1 (`SP:2586`) |
| 6 | 2 | value | `NonRacialValue*10` clamped (`SP:2563-2583`) |
| 8 | 2 | base | `BaseFixedPoint` (`SP:2588`) |
| 10 | 1 | lock | `skill.Lock` (`SP:2589`) |
| 11 | 2 | cap | `CapFixedPoint` (`SP:2590`) |

**Client decode of `0x3A`** (`PH:1921-2073`) — the authority for the clone: [SRC]

| type | meaning | decode |
|---|---|---|
| `0xFE` | server-provided **skill name table** | `count = ReadUInt16BE`; per entry: `bool haveButton` (1) + `nameLength` (1) + ASCII name; replaces `skills.mul` names and rebuilds `SortedSkills`. No sender found in ServUO (grep `0xFE` in `Server/Network` hits only the unrelated `Idle = 0xFE`, `SP:4959`) nor in ModernUO — shard/custom feature **[PARTIAL]** |
| `0x00` | absolute, **no** cap (`haveCap=false`) | per skill: `id` (then `id--`), value, base, lock; loop ends at `id == 0` |
| `0x01`, `0x02`, `0x03` | absolute + cap | as above + cap; `type==0x02` also does `id--` |
| `0xDF` | single/delta + cap | `isSingleUpdate` → applies one entry and `break` |
| `0xFF` | single/delta, **no** cap | `isSingleUpdate`, cap left at 1000 |
| any other | treated as multi-entry; gump is opened when `type == 1 \|\| type == 3 \|\| world.SkillsRequested` | `PH:1969-1988` |

Per-entry field order decoded: `id (2) · realVal (2) · baseVal (2) · lock (1) · cap (2, only if haveCap)`, then `skill.BaseFixed = baseVal; skill.ValueFixed = realVal; skill.CapFixed = cap; skill.Lock = locked;` and gump refresh (`PH:2009-2063`). Delta message computed as `float change = realVal / 10.0f - skill.Value;` gated by `Math.Abs(change * 10) >= ShowSkillsChangedDeltaValue` (`PH:2027-2035`). [SRC]

**S→C `0x6C` TargetReq** (target cursor) and **`0xC1` MessageLocalized** (the text path used by 500014/500118): [SRC]

| packet | fields in order |
|---|---|
| `0x6C` TargetReq, fixed 19 | `allowGround` (1) · `targetID` (4) · `flags` (1) · fill — `SP:2798-2808`; client table `0x0013 // 0x6C` = 19 fixed (`ClassicUO:src/ClassicUO.Client/Network/PacketsTable.cs:120`), so neither side writes a length field |
| `0x6C` TargetResponse, fixed 19 | `type` (1) · `targetID` (4) · `flags` (1) · `serial` (4) · `x` (2) · `y` (2) · `z` (2) · `graphic` (2) — `SPH:1238-1246` |
| `0xC1` MessageLocalized, variable | `serial` (4) · `graphic` (2) · `type` (1) · `hue` (2) · `font` (2) · `cliloc` (4) · `name` (30 byte ASCII fixed) · `args` (little-endian unicode, NUL-terminated) — `SP:2662-2690`; generic (arg-less) form: serial `Serial.MinusOne`, graphic `-1`, type Regular, hue `0x3B2`, font `3`, name `"System"`, args `""` — `SP:2650-2656` |

Client side: `0xC1`/`0xCC` → `DisplayClilocString` → `Clilocs.Translate((int)cliloc, arguments)` (`PH:269`, `PH:277`, `PH:4737`, `PH:4782`).

### 6. Skills the client cannot use directly (and the message)

| Layer | Rule | Evidence |
|---|---|---|
| Client: is a use-button drawn? | `skill.IsClickable`, i.e. the `hasAction` byte read from `skills.mul` (`SL:47`, `SL:54`, `SK:37`). If false: no use button in standard gump, no use button in advanced gump, and the row cannot be dragged into a floating `SkillButtonGump` | `SSG:794`, `SSG:935-946`, `SGA:281`, `SGA:349` |
| Client: macro dropdown | only the 24 hardcoded ids in `MM:31-37` can be picked as a "Use Skill" macro | `MM:906-917` |
| Client: floating button | created only from rows where `IsClickable` is true; on restore it disposes itself if the id is outside the player's skill array | `SSG:935-946`, `SGA:347-365`, `SBG:116-130` |
| Client: message text | the client has no skill-specific refusal text of its own; it renders whatever cliloc the server sends (path in §5.2) | `PH:4782` |
| Server: no callback | `SendLocalizedMessage(500014)` → comment in source `// That skill cannot be used directly.` | `SS:925-928` |
| Server: on cooldown | cliloc **500118** comment `// You must wait a few moments to use another skill.` | `SM:1864` |
| Server: dead / region veto / skill blocked | silent `false`, **no** cliloc | `SS:893-904` |
| Exact rendered English of 500014 / 500118 | **[UNVERIFIED]** — both strings live in the client's `cliloc` files, not in the repos; measurement: look up 500014 and 500118 in the client cliloc table (`Clilocs.GetString`), or observe the journal | — |

**ServUO skills with a non-null `Callback` in `SkillInfo.Table`** (set by `Scripts/**`; full enumeration by grep `\.Callback\s*=` and `SkillInfo\.Table\[`, 23 registrations): ids **1, 2, 3, 4, 6, 9, 14, 15, 16, 19, 21, 22, 23, 30, 32, 33, 35, 36, 38, 46, 47, 48, 56**. [SRC]

| id | skill | registration |
|---|---|---|
| 1 | Anatomy | `Scripts/Skills/Anatomy.cs:12` |
| 2 | Animal Lore | `Scripts/Skills/AnimalLore.cs:12` |
| 3 | Item Identification | `Scripts/Skills/ItemIdentification.cs:14` |
| 4 | Arms Lore | `Scripts/Skills/ArmsLore.cs:13` |
| 6 | Begging | `Scripts/Skills/Begging.cs:16` |
| 9 | Peacemaking | `Scripts/Skills/Peacemaking.cs:16` |
| 14 | Detecting Hidden | `Scripts/Skills/DetectHidden.cs:32` |
| 15 | Discordance | `Scripts/Skills/Discordance.cs:40` |
| 16 | Evaluating Intelligence | `Scripts/Skills/EvalInt.cs:12` |
| 19 | Forensic Evaluation | `Scripts/Skills/ForensicEval.cs:19` |
| 21 | Hiding | `Scripts/Skills/Hiding.cs:23` |
| 22 | Provocation | `Scripts/Skills/Provocation.cs:17` |
| 23 | Inscription | `Scripts/Skills/Inscribe.cs:13` |
| 30 | Poisoning | `Scripts/Skills/Poisoning.cs:11` |
| 32 | Spirit Speak | `Scripts/Skills/SpiritSpeak.cs:17` |
| 33 | Stealing | `Scripts/Skills/Stealing.cs:25` |
| 35 | Animal Taming | `Scripts/Skills/AnimalTaming.cs:31` |
| 36 | Taste Identification | `Scripts/Skills/TasteID.cs:12` |
| 38 | Tracking | `Scripts/Skills/Tracking.cs:17` |
| 46 | Meditation | `Scripts/Skills/Meditation.cs:10` |
| 47 | Stealth | `Scripts/Skills/Stealth.cs:40` |
| 48 | Remove Trap | `Scripts/Skills/RemoveTrap.cs:24` |
| 56 | Imbuing | `Scripts/Services/LootGeneration/Imbuing/Core/Imbuing.cs:22` |

**Therefore, on stock ServUO, "That skill cannot be used directly." (500014) applies to the other 35 ids**: 0, 5, 7, 8, 10, 11, 12, 13, 17, 18, 20, 24, 25, 26, 27, 28, 29, 31, 34, 37, 39, 40, 41, 42, 43, 44, 45, 49, 50, 51, 52, 53, 54, 55, 57. These are the craft/tool/spell/weapon skills used through items or spellbooks instead. Note this is an *emergent* list (null callback), not a declared one — and it depends on the script set loaded. [SRC] / **[PARTIAL]** for "stock ServUO" (verified against the 23 registrations found in this checkout; a custom shard can add more).

### 7. Name-mismatch diff table (server vs client)

Comparison basis: ServUO `SkillInfo.Table[i].Name` (`SS:596-653`, what the server's own gump prints at `SGS:265`) vs the client's code-side canonical name `SkillEntry.HardCodedName` (`SL:92-149`) and the ModernUO `ProfessionSkillName` copy of the legacy client name (`MUJ`). **42 of 58 ids are character-identical; 16 differ** (the 16 are listed). [SRC]

| id | ServUO `SkillInfo.Name` | ClassicUO `HardCodedName` | ModernUO `ProfessionSkillName` | Class of difference |
|---|---|---|---|---|
| 2 | Animal Lore (`SS:598`) | AnimalLore (`SL:94`) | AnimalLore (`MUJ:46`) | space only |
| 3 | Item Identification (`SS:599`) | **ItemID** (`SL:95`, comment `// T2A`) | ItemID (`MUJ:62`) | abbreviation; the only era comment in the client enum |
| 4 | Arms Lore (`SS:600`) | ArmsLore (`SL:96`) | ArmsLore (`MUJ:78`) | space only |
| 7 | **Blacksmithy** (`SS:603`) | **Blacksmith** (`SL:99`) | Blacksmith (`MUJ:126`) | real name difference (client keeps pre-AoS trade title) |
| 8 | **Bowcraft/Fletching** (`SS:604`) | **Bowcraft** (`SL:100`) | Bowcraft (`MUJ:142`) | client uses short legacy name |
| 14 | Detecting Hidden (`SS:610`) | DetectHidden (`SL:106`) | DetectingHidden (`MUJ:238`) | space only |
| 15 | **Discordance** (`SS:611`) | **Enticement** (`SL:107`) | Enticement (`MUJ:254`) | **real name difference** — legacy/client name *Enticement* vs current server + CUO macro name *Discordance* (`MM:2396`); era attribution [PARTIAL], see §3.2 |
| 16 | Evaluating Intelligence (`SS:612`) | **Evaluate**Intelligence (`SL:108`) | EvaluateIntelligence (`MUJ:270`) | spelling: *Evaluating* vs *Evaluate* |
| 19 | Forensic Evaluation (`SS:613`) | ForensicEvaluation (`SL:111`) | ForensicEvaluation (`MUJ:318`) | space only |
| 26 | Resisting Spells (`SS:622`) | ResistingSpells (`SL:118`) | ResistingSpells (`MUJ:430`) | space only |
| 29 | Musicianship (`SS:625`) | **Musicanship** (`SL:121`) | Musicianship (`MUJ:478`) | **typo in ClassicUO source** (enum only; display comes from `skills.mul`) |
| 32 | Spirit Speak (`SS:628`) | SpiritSpeak (`SL:124`) | SpiritSpeak (`MUJ:526`) | space only |
| 35 | Animal Taming (`SS:631`) | AnimalTaming (`SL:127`) | AnimalTaming (`MUJ:574`) | space only |
| 36 | Taste Identification (`SS:632`) | TasteIdentification (`SL:128`) | TasteIdentification (`MUJ:590`) | space only |
| 41 | Mace Fighting (`SS:637`) | MaceFighting (`SL:133`) | MaceFighting (`MUJ:670`) | space only |
| 48 | **Remove Trap** (`SS:644`) | **Disarm** (`SL:140`) | Disarm (`MUJ:782`) | **real name difference** (id 48's legacy/client name is *Disarm*) |

Additional client-internal inconsistencies worth mirroring deliberately in a clone: `SL:106` `DetectHidden` vs `MM:2395` `DetectingHidden`; `SL:95` `ItemID` vs `MM:2402` `ItemIdentification`; `SL:107` `Enticement` vs `MM:2396` `Discordance` and `HM:533` `UseSkillEnticement`; and the `MacroSubType` skill block (`MM:2389-2412`) is ordered **alphabetically** (Anatomy, AnimalLore, AnimalTaming, ArmsLore, Begging, Cartography, DetectingHidden, …), not by skill id — the id is recovered positionally through `MM:31-37`. [SRC]

### 8. Open gaps (what a clone cannot copy blindly)

| # | Gap | Marker | Measurement that would settle it |
|---|---|---|---|
| 1 | Exact group names/bytes in a real `skillgrp.mul` (ASCII vs unicode header) | [UNVERIFIED] | hexdump header; expect `7` or `-1,7` |
| 2 | Exact count/name bytes of a real `skills.mul` (58? trailing blanks?) | [UNVERIFIED] | iterate `Skills.idx` entries + dump names; or log `SkillsCount` (`SL:20`) |
| 3 | Whether pre-SA client files carried unnamed slots at 55/56/57 | [UNVERIFIED] | inspect a pre-2009 `skills.mul` |
| 4 | English text of cliloc 500014 / 500118 as the client renders it | [UNVERIFIED] | `Clilocs.GetString(500014/500118)` on a real install |
| 5 | `Send_SkillsStatusRequest` (`OP:791-812`) is defined but never called | [PARTIAL] | grep callers in a future revision / confirm with upstream |
| 6 | `HotkeyAction.UseSkill*` enum members have no bound action | [SRC] | verified by absence of `Add(HotkeyAction.UseSkill…` in `HM:24-221` |
| 7 | `Profile.EnableSkillReport` unused | [PARTIAL] | grep in a future revision |
| 8 | ModernUO's callback set (ModernUO moves `SkillInfo` to `Distribution/Data/skills.json`, which has **no** callback field, so callbacks are registered in `UOContent/Skills/**`) — not enumerated here | [PARTIAL] | grep `Callback` in `ModernUO/Projects/UOContent/Skills/**` |
| 9 | Client-side clamping of ids ≥ 58 | [SRC] | `PH:2019` guard + `PMb:22` fixed array prove silent drop |
