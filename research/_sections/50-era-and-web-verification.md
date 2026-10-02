## 7. Era matrix & web verification

Scope: authoritative **prose** cross-checks for the skill system (UOGuide, official uo.com publish notes, UO Stratics where reachable), matched against the local source checkouts. Every row carries `[SRC]` (file:line), `[WEB]` (URL), `[SRC+WEB]` (agree) or `[ERA]`/`[PARTIAL]`/`[UNVERIFIED]`. No number below is invented: where a wiki number could not be reproduced in code, both are printed and the verdict says so.

Checkouts used (branch verified from `.git/HEAD`): `ServUO` @ `pub57`, `ModernUO` @ `main`, `ClassicUO` @ `main`.
Citation bases: `ServUO:<path>` = https://github.com/ServUO/ServUO/blob/pub57/`<path>`#L`<line>` · `ModernUO:Projects/…` = https://github.com/modernuo/ModernUO/blob/main/Projects/… · `ClassicUO:src/…` = https://github.com/ClassicUO/ClassicUO/blob/main/src/…

### 7.1 Era matrix (all 58 skill ids)

Era anchors used below:

| Era | Date | Source |
|---|---|---|
| UO launch (classic) | 1997-09-24 | [UOGuide — Ultima Online](https://www.uoguide.com/Ultima_Online) `[WEB]` |
| T2A | 1998-10-24 | [UOGuide — The Second Age](https://www.uoguide.com/Ultima_Online:_The_Second_Age) `[WEB]` |
| UO:R (skill lock + stat lock introduced) | 2000-05-04 | [UOGuide — Renaissance](https://www.uoguide.com/Ultima_Online:_Renaissance) `[WEB]` |
| Publish 16 (GGS, stat scrolls, power scrolls, Enticement→Discordance) | 2002-07-23 | [uo.com — Publish 16 part 2](https://uo.com/wiki/ultima-online-wiki/technical/previous-publishes/2002-2/2002-publish-16-part-2-23rd-july/) `[WEB]` |
| AoS | 2003-02-11 | [UOGuide — Age of Shadows](https://www.uoguide.com/Age_of_Shadows) `[WEB]` |
| SE (Samurai Empire) | 2004-11-02 | [UOGuide — Samurai Empire](https://www.uoguide.com/Samurai_Empire) `[WEB]` |
| ML (Mondain's Legacy) | 2005-08-30 | [UOGuide — Mondain's Legacy](https://www.uoguide.com/Mondain%27s_Legacy) `[WEB]` |
| SA (Stygian Abyss) | 2009-09-08 | [UOGuide — Stygian Abyss](https://www.uoguide.com/Stygian_Abyss) `[WEB]` |

Code-side era gates: `ServUO:Server/Main.cs:147-150` (`AOS`/`SE`/`ML`/`SA`), `ServUO:Server/ExpansionInfo.cs:7-21` (enum), `:159-245` (table; ML requires client `5.0.0a`, SA uses the `TerMur` client flag, HS requires `7.0.9.0`). Client enum indices: `ClassicUO:src/ClassicUO.Assets/SkillsLoader.cs:90-150`; server names/ids: `ServUO:Server/Skills.cs:28-88`; ModernUO agrees through id 57 (`ModernUO:Projects/Server/Skills.cs:68-76`).

| id | Server name (`SkillName`) | Client enum name (`ClassicUO`) | Introduced | Renamed? | Evidence |
|---|---|---|---|---|---|
| 0 | Alchemy | Alchemy | classic 1997-09-24 | — | `ServUO:Server/Skills.cs:30`; `ClassicUO:…/SkillsLoader.cs:92` |
| 1 | Anatomy | Anatomy | classic | — | `:31` / `:93` |
| 2 | AnimalLore | AnimalLore | classic | — | `:32` / `:94` |
| 3 | ItemID | ItemID | classic (client comment `// T2A`) | client `ItemID` → server `Item Identification` | `:33` / `:95` `[PARTIAL]` era flagged T2A in client source |
| 4 | ArmsLore | ArmsLore | classic | display "Arms Lore" | `:34` / `:96` |
| 5 | Parry | Parrying | classic | server `Parry` → client/user "Parrying" | `:35` / `:97`; [UOGuide — Parrying](https://www.uoguide.com/Parrying) |
| 6 | Begging | Begging | classic | — | `:36` / `:98` |
| 7 | Blacksmith | Blacksmith | classic | "Blacksmithy" | `:37` / `:99`; [UOGuide — Blacksmithy](https://www.uoguide.com/Blacksmithy) |
| 8 | Fletching | Bowcraft | classic | "Bowcraft/Fletching" | `:38` / `:100`; [UOGuide — Bowcraft](https://www.uoguide.com/Bowcraft) |
| 9 | Peacemaking | Peacemaking | classic | — | `:39` / `:101` |
| 10 | Camping | Camping | classic | — | `:40` / `:102` |
| 11 | Carpentry | Carpentry | classic | — | `:41` / `:103` |
| 12 | Cartography | Cartography | classic | — | `:42` / `:104` |
| 13 | Cooking | Cooking | classic | — | `:43` / `:105` |
| 14 | DetectHidden | DetectHidden | classic | "Detecting Hidden" | `:44` / `:106` |
| 15 | Discordance | **Enticement** | classic (slot), **replaced Publish 16, 2002-07-23** | Enticement → Discordance; existing points converted | [UOGuide — Enticement](https://www.uoguide.com/Enticement) `[WEB]`; client enum still `Enticement` `ClassicUO:…/SkillsLoader.cs:107`; `SkillCheck.UseAntiMacro[15]` `ServUO:Scripts/Misc/SkillCheck.cs:77` |
| 16 | EvalInt | EvaluateIntelligence | classic | "Evaluating Intelligence" | `:46` / `:108` |
| 17 | Healing | Healing | classic | — | `:47` / `:109` |
| 18 | Fishing | Fishing | classic | — | `:48` / `:110` |
| 19 | Forensics | ForensicEvaluation | classic | "Forensic Evaluation" | `:49` / `:111` |
| 20 | Herding | Herding | classic | — | `:50` / `:112` |
| 21 | Hiding | Hiding | classic | — | `:51` / `:113` |
| 22 | Provocation | Provocation | classic | — | `:52` / `:114` |
| 23 | Inscribe | Inscription | classic | "Inscription" | `:53` / `:115` |
| 24 | Lockpicking | Lockpicking | classic | — | `:54` / `:116` |
| 25 | Magery | Magery | classic | — | `:55` / `:117` |
| 26 | MagicResist | ResistingSpells | classic | "Resisting Spells" | `:56` / `:118` |
| 27 | Tactics | Tactics | classic | — | `:57` / `:119` |
| 28 | Snooping | Snooping | classic | — | `:58` / `:120` |
| 29 | Musicianship | Musicanship (sic) | classic | — | `:59` / `:121` |
| 30 | Poisoning | Poisoning | classic | — | `:60` / `:122` |
| 31 | Archery | Archery | classic | — | `:61` / `:123` |
| 32 | SpiritSpeak | SpiritSpeak | classic | "Spirit Speak" | `:62` / `:124` |
| 33 | Stealing | Stealing | classic | — | `:63` / `:125` |
| 34 | Tailoring | Tailoring | classic | — | `:64` / `:126` |
| 35 | AnimalTaming | AnimalTaming | classic | "Animal Taming" | `:65` / `:127` |
| 36 | TasteID | TasteIdentification | classic | "Taste Identification" | `:66` / `:128` |
| 37 | Tinkering | Tinkering | classic | — | `:67` / `:129` |
| 38 | Tracking | Tracking | classic | — | `:68` / `:130` |
| 39 | Veterinary | Veterinary | classic | — | `:69` / `:131` |
| 40 | Swords | Swordsmanship | classic | "Swordsmanship" | `:70` / `:132` |
| 41 | Macing | MaceFighting | classic | "Mace Fighting" | `:71` / `:133` |
| 42 | Fencing | Fencing | classic | — | `:72` / `:134` |
| 43 | Wrestling | Wrestling | classic | — | `:73` / `:135` |
| 44 | Lumberjacking | Lumberjacking | classic | — | `:74` / `:136` |
| 45 | Mining | Mining | classic | — | `:75` / `:137` |
| 46 | Meditation | Meditation | classic | — | `:76` / `:138` |
| 47 | Stealth | Stealth | classic | — | `:77` / `:139` |
| 48 | RemoveTrap | **Disarm** | classic (slot) | client enum `Disarm` → "Remove Trap"; Publish 105 dropped the Detect Hidden requirement | `:78` / `:140`; [UOGuide — Remove Trap](https://www.uoguide.com/Remove_Trap) `[WEB]` `[ERA]` |
| 49 | Necromancy | Necromancy | **AoS 2003-02-11** | — | [UOGuide — AoS](https://www.uoguide.com/Age_of_Shadows) lists "The Necromancer profession" `[WEB]`; `ServUO:Scripts/Items/Consumables/PowerScroll.cs:33-41` (`m_AOSSkills`) `[SRC]` |
| 50 | Focus | Focus | **AoS 2003-02-11** | — | [UOGuide — Focus](https://www.uoguide.com/Focus) ("in Age of Shadows, these 10-second gains can now be increased by … the Focus skill") `[WEB]`; `PowerScroll.cs:33-41` `[SRC]` |
| 51 | Chivalry | Chivalry | **AoS 2003-02-11** | — | [UOGuide — AoS](https://www.uoguide.com/Age_of_Shadows) ("The chivalry skill") `[WEB]`; `PowerScroll.cs:33-41` `[SRC]` |
| 52 | Bushido | Bushido | **SE 2004-11-02** | — | [UOGuide — Samurai Empire](https://www.uoguide.com/Samurai_Empire) ("Two new skills were introduced: Bushido … and Ninjitsu") `[WEB]`; `PowerScroll.cs:42-46` (`m_SESkills`) `[SRC]` |
| 53 | Ninjitsu | Ninjitsu | **SE 2004-11-02** | — | same as 52 |
| 54 | Spellweaving | Spellweaving | **ML 2005-08-30** | — | [UOGuide — Spellweaving](https://www.uoguide.com/Spellweaving) ("a skill introduced with the Mondain's Legacy expansion") `[WEB]`; `PowerScroll.cs:47-50` (`m_MLSkills`) `[SRC]` |
| 55 | Mysticism | Mysticism | **SA 2009-09-08** | — | [UOGuide — Mysticism](https://www.uoguide.com/Mysticism) ("added with the Stygian Abyss expansion") `[WEB]`; `PowerScroll.cs:52-57` (`m_SASkills`) `[SRC]` |
| 56 | Imbuing | Imbuing | **SA 2009-09-08** | — | [UOGuide — Imbuing](https://www.uoguide.com/Imbuing) ("added with the release of Ultima Online: Stygian Abyss") `[WEB]`; same `[SRC]` |
| 57 | Throwing | Throwing | **SA 2009-09-08** (gargoyles only) | — | [UOGuide — Throwing](https://www.uoguide.com/Throwing) ("added during the … Stygian Abyss expansion and is available only to characters that are Gargoyles") `[WEB]`; SA list `PowerScroll.cs:52-57`; enforcement `ServUO:Scripts/Misc/SkillCheck.cs:342-343` ("if skill == Throwing && race != Gargoyle → no gain") and `ClassicUO:src/ClassicUO.Client/Game/UI/Gumps/CharCreation/CreateCharTradeGump.cs:155` ("Throwing for gargoyle only") `[SRC+WEB]` |

Answer to the explicit question — which of 49..57 are post-classic: **all nine**. Necromancy/Focus/Chivalry = AoS (2003-02-11); Bushido/Ninjitsu = SE (2004-11-02); Spellweaving = ML (2005-08-30); Mysticism/Imbuing/Throwing = SA (2009-09-08). `[SRC+WEB]`

Two corrections to `_BRIEF.md` §"Era reference" `[ERA]`:
1. The brief says "SE (2005): Spellweaving" — wrong. **SE is 2004-11-02 and added Bushido + Ninjitsu**; Spellweaving is **ML, 2005-08-30** ([Samurai Empire](https://www.uoguide.com/Samurai_Empire), [Mondain's Legacy](https://www.uoguide.com/Mondain%27s_Legacy)).
2. The brief says "ML (2007): Throwing for gargoyles only" — wrong. **Throwing is SA, 2009-09-08**; ML added no skill (only Spellweaving in 2005) ([Stygian Abyss](https://www.uoguide.com/Stygian_Abyss), corroborated by `PowerScroll.cs:47-57` which places Throwing in `m_SASkills`).

### 7.2 The "3 future/unused skill slots" question — explicit answer

**Finding: there is no evidence for three named, pre-reserved "future" slots. Slots 55/56/57 are simply the last three skills ever appended, and all three arrived together in Stygian Abyss (2009-09-08).** Evidence, in order of strength:

| Claim | Evidence | Verdict |
|---|---|---|
| 58 skills exist today; exactly 1 was removed | "Ultima Online has 58 different Skills currently in game (and 1 removed)" — [UOGuide — Skills](https://www.uoguide.com/Skills) `[WEB]`; the removed one is Enticement (slot 15) — [UOGuide — Enticement](https://www.uoguide.com/Enticement) | `[SRC+WEB]` |
| Server tables are dense 0..57, no holes, no placeholders | `ServUO:Server/Skills.cs:594` `private static SkillInfo[] m_Table = new SkillInfo[58]`; entries at `:596-653`; `ModernUO:Projects/Server/Skills.cs:68-76` same ids `[SRC]` | `[SRC]` |
| The client skill table is **data-driven** and tolerates fewer than 58 entries | `ClassicUO:src/ClassicUO.Assets/SkillsLoader.cs:41-55` walks `skills.idx`/`skills.mul`, skips entries with `entry.Length <= 0`, and assigns `count++` only for valid entries; `ClassicUO:src/ClassicUO.Client/Game/Managers/SkillsGroupManager.cs:329,336,341,346,351,385,393,400,407` guard every post-classic skill with `if (count > NN)` — i.e. the client expects older files that stop short of 58 `[SRC]` | `[SRC]` |
| Empty entries are a real, handled case | `ServUO:Ultima/Skills.cs:70-73` returns null when `length == 0` and `:22-30` **breaks** at the first null (assumes a dense prefix) `[SRC]` | `[SRC]` |
| SA added exactly three skills, in this order | [UOGuide — Stygian Abyss](https://www.uoguide.com/Stygian_Abyss) "New Skills": Imbuing, Mysticism, Throwing `[WEB]`; code order 55 Mysticism, 56 Imbuing, 57 Throwing (`ServUO:Server/Skills.cs:85-87`, `PowerScroll.cs:52-57`) `[SRC]` | `[SRC+WEB]` |
| Whether 55/56/57 were *blank-but-present* in pre-SA `skills.mul` | **Not determinable from any source on disk or reachable web page.** No wiki or code comment states a reserved-slot count | `[UNVERIFIED]` |

Measurement that would settle it `[UNVERIFIED]`: take a **pre-SA 2D client data set** (client ≤ 5.x, before 2009-09-08) and read `skills.idx` — 16-byte records; count records whose length field is `> 0`. If the count is 55, the "3 unused slots" story is false (the file simply ended at Spellweaving); if it is 58 with three zero-length/blank names, the slots genuinely existed as placeholders. The same read gives the `hasAction` byte (see 7.5).

### 7.3 Skill list cross-check (id · stats · client group · active flag)

Stat columns: `ServUO:Server/Skills.cs:596-653` (`StatCode primary, secondary` per `SkillInfo` ctor at `:525-559`) vs the published table on [UOGuide — Stats](https://www.uoguide.com/Stats) `[WEB]`. "Client grp" = `skillgrp.mul` group as reconstructed by `ClassicUO:src/ClassicUO.Client/Game/Managers/SkillsGroupManager.cs:299-455` (CUO's fallback defaults, used when `skillgrp.mul` is missing/unreadable; group 0 = Miscellaneous is implicit and non-deletable, `:174-178`). "Active" = the skill has an invocable skill-button action: `SkillInfo.Table[i].Callback != null` (23 skills, `ServUO:Scripts/Skills/*` + `Scripts/Services/LootGeneration/Imbuing/Core/Imbuing.cs:22`); the client's own blue-gem flag is the data byte `hasAction` (`ClassicUO:…/SkillsLoader.cs:47`, sent to the server at `ClassicUO:src/ClassicUO.Client/Network/OutgoingPackets.cs:4650`).

| id | Name | Primary | Secondary | Client grp | Active (server callback) | UOGuide slug (URL = https://www.uoguide.com/<slug>) |
|---|---|---|---|---|---|---|
| 0 | Alchemy | Int | Dex | Trade Skills | no | Alchemy |
| 1 | Anatomy | Int | Str | Combat | yes | Anatomy |
| 2 | Animal Lore | Int | Str | Wilderness | yes | Animal_Lore |
| 3 | Item Identification | Int | Dex | Miscellaneous | yes | Item_Identification |
| 4 | Arms Lore | Int | Str | Miscellaneous | yes | Arms_Lore |
| 5 | Parrying | Dex | Str | Combat | no | Parrying |
| 6 | Begging | Dex | Int | Miscellaneous | yes | Begging |
| 7 | Blacksmithy | Str | Dex | Trade Skills | no | Blacksmithy |
| 8 | Bowcraft/Fletching | Dex | Str | Trade Skills | no | Bowcraft |
| 9 | Peacemaking | Int | Dex | Bard | yes | Peacemaking |
| 10 | Camping | Dex | Int | Miscellaneous | no | Camping |
| 11 | Carpentry | Str | Dex | Trade Skills | no | Carpentry |
| 12 | Cartography | Int | Dex | Miscellaneous | no | Cartography |
| 13 | Cooking | Int | Dex | Trade Skills | no | Cooking |
| 14 | Detecting Hidden | Int | Dex | Thieving | yes | Detect_Hidden |
| 15 | Discordance | **Dex** | **Int** | Bard | yes | Discordance |
| 16 | Evaluating Intelligence | Int | Str | Magic | yes | Evaluating_Intelligence |
| 17 | Healing | Int | Dex | Combat | no | Healing |
| 18 | Fishing | Dex | Str | Wilderness | no | Fishing |
| 19 | Forensic Evaluation | Int | Dex | Miscellaneous | yes | Forensic_Evaluation |
| 20 | Herding | Int | Dex | Wilderness | no | Herding |
| 21 | Hiding | Dex | Int | Thieving | yes | Hiding |
| 22 | Provocation | Int | Dex | Bard | yes | Provocation |
| 23 | Inscription | Int | Dex | Trade Skills | yes | Inscription |
| 24 | Lockpicking | Dex | Int | Thieving | no | Lockpicking |
| 25 | Magery | Int | Str | Magic | no | Magery |
| 26 | Resisting Spells | Str | Dex | Magic | no | Resisting_Spells |
| 27 | Tactics | Str | Dex | Combat | no | Tactics |
| 28 | Snooping | Dex | Int | Thieving | no | Snooping |
| 29 | Musicianship | Dex | Int | Bard | no | Musicianship |
| 30 | Poisoning | Int | Dex | Thieving | yes | Poisoning |
| 31 | Archery | Dex | Str | Combat | no | Archery |
| 32 | Spirit Speak | Int | Str | Magic | yes | Spirit_Speak |
| 33 | Stealing | Dex | Int | Thieving | yes | Stealing |
| 34 | Tailoring | Dex | Int | Trade Skills | no | Tailoring |
| 35 | Animal Taming | Str | Int | Wilderness | yes | Animal_Taming |
| 36 | Taste Identification | Int | Str | Miscellaneous | yes | Taste_Identification |
| 37 | Tinkering | Dex | Int | Trade Skills | no | Tinkering |
| 38 | Tracking | Int | Dex | Wilderness | yes | Tracking |
| 39 | Veterinary | Int | Dex | Wilderness | no | Veterinary |
| 40 | Swordsmanship | Str | Dex | Combat | no | Swordsmanship |
| 41 | Mace Fighting | Str | Dex | Combat | no | Mace_Fighting |
| 42 | Fencing | Dex | Str | Combat | no | Fencing |
| 43 | Wrestling | Str | Dex | Combat | no | Wrestling |
| 44 | Lumberjacking | Str | Dex | Trade Skills | no | Lumberjacking |
| 45 | Mining | Str | Dex | Trade Skills | no | Mining |
| 46 | Meditation | Int | Str | Magic | yes | Meditation |
| 47 | Stealth | Dex | Int | Thieving | yes | Stealth |
| 48 | Remove Trap | Dex | Int | Thieving | yes | Remove_Trap |
| 49 | Necromancy | Int | Str | Magic | no | Necromancy |
| 50 | Focus | Dex | Int | Combat | no | Focus |
| 51 | Chivalry | Str | Int | Combat | no | Chivalry |
| 52 | Bushido | Str | Int | Combat | no | Bushido |
| 53 | Ninjitsu | Dex | Int | Combat | no | Ninjitsu |
| 54 | Spellweaving | Int | Str | Magic | no | Spellweaving |
| 55 | Mysticism | Str | Int | Magic | no | Mysticism |
| 56 | Imbuing | Int | Str | Magic | yes | Imbuing |
| 57 | Throwing | Dex | Str | Combat | no | Throwing |

Cross-check result `[SRC+WEB]`: 54 of 56 comparable rows match. Two exceptions:

| Row | Wiki (Stats) says | Code says | Verdict |
|---|---|---|---|
| 15 Discordance | Primary **Intelligence**, secondary **Dexterity** | `StatCode.Dex, StatCode.Int` — `ServUO:Server/Skills.cs:611` (Dex is the *primary* gain stat, `StatCode.StrGain/DexGain/IntGain = 0/0.25/0.25` at `:611`) | **Contradiction.** Code makes Dex primary. Note the stat *gain weights* are equal (0.25/0.25), so the practical difference is only which stat the 75/25 roll favours (`Scripts/Misc/SkillCheck.cs:552-555`). |
| 55 Mysticism, 56 Imbuing | **Absent** from the published Stats table | present in code (`:651-652`) | `[PARTIAL]` — wiki table is stale; it lists 56 of 58 skills. |

UOGuide does **not** publish a systematic active/passive field. Its only "Active"/"Passive" strings are *training-method* subheadings (found on exactly 7 pages: Animal_Lore, Anatomy, Arms_Lore, Evaluating_Intelligence, Meditation, Musicianship, Spirit_Speak) — e.g. "Animal Lore can also be raised by using the Animal Taming and Veterinary skills" (`Animal_Lore`). The nearest published classifications are (a) the 7 directory groups on [UOGuide — Skills](https://www.uoguide.com/Skills), and (b) prose such as "Provocation is difficulty-based skill" / "Musicianship … is required for any of the other Bard-related skills". `[PARTIAL]` — the authoritative active/passive list is the client `hasAction` byte (data, see 7.5) and the server's `Callback != null` set (23 skills above).

### 7.4 Published numbers vs ServUO code

| # | Quantity | Wiki says | Code says (path:line) | Verdict |
|---|---|---|---|---|
| 1 | Total skill cap, launch era | "Initially with the release of UO, the skill cap was 700 total skill points" — [Skill Cap](https://www.uoguide.com/Skill_Cap) | `Config.Get("PlayerCaps.TotalSkillCap", 7000)` → 700.0 (fixed point /10) — `ServUO:Server/Skills.cs:996` | `[SRC+WEB]` exact |
| 2 | Total skill cap, veteran tiers | Sep-2002 Veteran Rewards: 0-11 mo = 700, 12-23 = 705, 24-35 = 710, 36-47 = 715, 48+ = 720 — [Skill Cap](https://www.uoguide.com/Skill_Cap) | Config value only; no age-based tiering in code (`Scripts/Services/VeteranRewards/*` grants +5 **stat** cap, not skill) | `[WEB]` only; ServUO default stays 700 |
| 3 | Total skill cap, current | "In January 2013, skill cap of all players have been raised up to 720 points" — [Skill Cap](https://www.uoguide.com/Skill_Cap); "You can expend up to 720 points" — [Skills](https://www.uoguide.com/Skills) | default still `7000` (700.0) | **Deliberate divergence**: code default = classic era |
| 4 | Individual skill cap | "Each skill has an individual cap of 100 points, though in some cases this can be extended by using Power Scrolls" — [Skills](https://www.uoguide.com/Skills) | `new Skill(this, SkillInfo.Table[skillID], 0, 1000, SkillLock.Up)` → cap 1000 fixed = **100.0** — `ServUO:Server/Skills.cs:874`; map default `m_Cap = 1000` at `:124,144` | `[SRC+WEB]` |
| 5 | Individual cap ceiling | Power Scrolls come in 105 / 110 / 115 / 120, named Wondrous / Exalted / Mythical / Legendary — [Power Scrolls](https://www.uoguide.com/Power_Scroll) | `PowerScroll.Title` returns `1049635 + (Value-105)/5` for values 105/110/115/120 — `Scripts/Items/Consumables/PowerScroll.cs:131-137`; applied via `from.Skills[Skill].Cap = this.Value` at `:222`; cannot use if `skill.Cap >= Value` at `:206-210` | `[SRC+WEB]` exact |
| 6 | Power Scroll skill coverage | 35 skills listed as scroll-capable (incl. Fishing, Imbuing), plus an explicit "do not have Power Scrolls" list — [Power Scrolls](https://www.uoguide.com/Power_Scroll) | 34 skills: 22 base + 6 AoS + 2 SE + 1 ML + 3 SA — `PowerScroll.cs:8-57`; Fishing is **commented out** as `m_HSSkills` (`:58-63,105-109`) | **Close, off by one**: Fishing is wiki-yes / code-no (High Seas gated and disabled) |
| 7 | Stat cap (natural sum) | "the sum of the natural stat values for your character cannot exceed 225" — [Stats](https://www.uoguide.com/Stats) | `Config.Get("PlayerCaps.TotalStatCap", 225)` — `Server/Mobile.cs:6103,11128`; `StatCapScroll.m_StatCap = Config.Get(..., 225)` — `Scripts/Items/Consumables/StatScroll.cs:8` | `[SRC+WEB]` |
| 8 | Individual natural stat cap | "You can gain a maximum of 125 points in any particular stat naturally" — [Stats](https://www.uoguide.com/Stats) | `Config.Get("PlayerCaps.StrCap", 125)` / DexCap / IntCap — `Server/Mobile.cs:6078-6080,11129-11131`; enforced in `SkillCheck.CanRaise` — `Scripts/Misc/SkillCheck.cs:586,599,612` | `[SRC+WEB]` |
| 9 | Stat cap with items | "the sum of your natural stat points plus what you gain from any stat-altering items cannot exceed 150" — [Stats](https://www.uoguide.com/Stats) | `Config.Get("PlayerCaps.StrMaxCap", 150)` / DexMaxCap / IntMaxCap — `Server/Mobile.cs:6081-6083,11132-11134`, properties at `:12768-12785`; **enforced** as `return Math.Min(base.Str, StrMaxCap);` — `Scripts/Mobiles/PlayerMobile.cs:2012` (Int `:2027`, Dex `:2044`) | `[SRC+WEB]` (150 = max per-stat display value including item bonuses; note the raw `Mobile.Str` getter itself only clamps `1..65000` — `Server/Mobile.cs:8285-8292` — so the 150 limit is a `PlayerMobile` rule, not a `Mobile` rule) |
| 10 | Stat cap ceiling (scrolls) | 260 = 225 base + 5 veteran + 5 Scroll of Valiant Commendation + 25 scroll; otherwise 250 = 225 + 25 — [Stat Scrolls](https://www.uoguide.com/Stat_Scroll) | Stat scroll tiers +5/+10/+15/+20/+25 ("Wonderous…Ultimate") — `StatScroll.cs:40-47`; veteran `User.StatCap += 5` — `Scripts/Services/VeteranRewards/StatRewardGump.cs:40`; Valiant Commendation `from.StatCap += 5` — `Scripts/Services/Revamped Dungeons/TheExodusEncounter/Loot/ScrollofValiantCommendation.cs:62`; TC uses exactly 250 — `Scripts/Services/TestCenter.cs:201,657` | `[SRC+WEB]` |
| 11 | Stat gain chance per skill gain | "There is a 1 in 20 chance that you will receive a stat gain whenever a skill is advanced" — [Stats](https://www.uoguide.com/Stats) | `_PlayerChanceToGainStats = Config.Get("PlayerCaps.PlayerChanceToGainStats", 5)` (percent) — `Scripts/Misc/SkillCheck.cs:49`; rolled at `:513` | `[SRC+WEB]` (5 % = 1/20) |
| 12 | Which stat gains (75/25) | "the primary stat will increase 75% of the time, while secondary stats will increase 25%" — [Stats](https://www.uoguide.com/Stats) | `if (Utility.Random(4) == 0) GainStat(Secondary) else GainStat(Primary)` → 75/25 — `Scripts/Misc/SkillCheck.cs:552-555` | `[SRC+WEB]` exact |
| 13 | Stat gain timer | **Three different published answers:** (a) Publish 16, 2002: "up to 1 Stat point per 30 minutes … up to 6 Stat points per day" ([uo.com Publish 16 pt 2](https://uo.com/wiki/ultima-online-wiki/technical/previous-publishes/2002-2/2002-publish-16-part-2-23rd-july/)); (b) Siege/Mugen RoT: "One Stat will get a gain every 15 minutes" ([uo.com Skill Gain Systems](https://uo.com/wiki/ultima-online-wiki/technical/skill-gain-systems/)); (c) current: "You can gain an unlimited amount of stat points per day, with no fixed intervals between gains" ([Stats](https://www.uoguide.com/Stats)) | `_StatGainDelay = Config.Get("PlayerCaps.PlayerStatTimeDelay", TimeSpan.FromMinutes(15.0))` — `SkillCheck.cs:46`; **but** `if (!Config.Get("PlayerCaps.EnablePlayerStatTimeDelay", false)) _StatGainDelay = TimeSpan.FromSeconds(0.5)` — `:52-53`; enforced in `CheckStatTimer` — `:727-772`. Pet delay separate: 5 min default, disabled → 0.5 s (`:47,55-56`) | `[PARTIAL]` — "15 min" is real in code but **disabled by default**; the classic-era OSI figure is 30 min/6 per day; RoT's 15 min is the Siege-only rule. `EnablePlayerStatTimeDelay=false` reproduces modern (c) |
| 14 | Stat points per day (Siege/RoT) | "up to 6 Stat points per day" — Publish 16 `[WEB]` | `public static int StatsPerDay = 15;` — `Scripts/Misc/Siege.cs:22`, checked at `:388` (`StatsTable[m] < StatsPerDay`) | **Contradiction** 6 vs 15; code is 2.5× the published Publish 16 figure |
| 15 | Siege RoT skill timer | 70.0-79.9 → 0.1 per 5 min; 80.0-89.9 → 8 min; 90.0-99.9 → 12 min; 100.0-109.9 → 15 min — [uo.com Skill Gain Systems](https://uo.com/wiki/ultima-online-wiki/technical/skill-gain-systems/) | `MinutesPerGain`: `<70 → 0`, `<=79.9 → 5`, `<=89.9 → 8`, `<=99.9 → 12`, else `15` — `Scripts/Misc/Siege.cs:354-379`; used at `Scripts/Misc/SkillCheck.cs:382-397`; `GGSActive = !Siege.SiegeShard` — `SkillCheck.cs:40` | `[SRC+WEB]` exact (4/4 brackets) |
| 16 | GGS gain minimum | "award you a mandatory point (as in 0.0 to 0.1)" — [uo.com](https://uo.com/wiki/ultima-online-wiki/technical/skill-gain-systems/), [Guaranteed Gain System](https://www.uoguide.com/Guaranteed_Gain_System) | `Region.SkillGain(from) => 0.1` — `Server/Region.cs:973-976`, multiplied by 10 into fixed point at `SkillCheck.cs:361`; `CheckGGS` short-circuits the roll at `:250,774-785` | `[SRC+WEB]` |
| 17 | GGS timer table | 24 brackets × 3 columns (350 / 500 / 700 total skill points) — official table reproduced on [uo.com](https://uo.com/wiki/ultima-online-wiki/technical/skill-gain-systems/) and [UOGuide](https://www.uoguide.com/Guaranteed_Gain_System) | `GGSTable` 24 rows × 3 columns, minutes — `SkillCheck.cs:798-806`; row = `min(23, skill.Base/5)`, column = `Total >= 7000 ? 2 : Total >= 3500 ? 1 : 0` — `:792-795` | 22 of 24 rows exact; see 7.4.1 for the two mismatches and the column-threshold divergence |
| 18 | Gain increment at low skill | "0.0 to 0.1" mandatory GGS point; Scroll of Alacrity "gain 0.2 to 0.5 at each skill check instead of the normal 0.1" — [uo.com](https://uo.com/wiki/ultima-online-wiki/technical/skill-gain-systems/) | normal gain 0.1 (`Region.cs:975`); below 10.0 skill `toGain = Utility.Random(4) + 1` fixed point = **0.1-0.4** — `SkillCheck.cs:400-401`; Alacrity `toGain = Utility.RandomMinMax(2, 5)` = **0.2-0.5** — `:410-418`; quest accelerated `toGain *= RandomMinMax(2, 4)` — `:404-407` | `[SRC+WEB]` for 0.1 and 0.2-0.5; `[SRC]` only for the 0.1-0.4 newbie band |
| 19 | Craft-all gains | not published | `GetGainChance(...)/10` per unit, `value += 0.1` per gained unit — `SkillCheck.cs:187-219` | `[SRC]` only |
| 20 | Anti-macro (gains per spot/target) | not published on the pages fetched | `Allowance = 3` uses per location/target, remembered `AntiMacroExpire = 5 min`, location bucket `4` tiles — `SkillCheck.cs:28,33,38`; per-skill opt-in table `:59-123` | `[SRC]` only; `EnableAntiMacro` default **false** (`:44`) |
| 21 | Skill gain stops at 100 % success | "your skill gain ceases at the point where your chance to create the item reaches 100%, which corresponds to 50 points above the minimum skill needed … (X + 50)" — [Blacksmithy](https://www.uoguide.com/Blacksmithy) | `AddCraft(typeof(ChainCoif), 1111704, 1025051, 14.5, 64.5, …)`, `ChainLegs 36.7, 86.7`, `ChainChest 39.1, 89.1` — `Scripts/Services/Craft/DefBlacksmithy.cs:306-308`; each max = min + 50.0 exactly | `[SRC+WEB]` exact, including the item min-skills (wiki 14.5 / 36.7 / 39.1) and the ingot counts (wiki 10 / 18 / 20 vs code `10 / 18 / 20`) |
| 22 | Stealing weight limit | "You may not take items that weigh more then your skill level divided by 10" + training table 3 stones @30-40 … 11 stones @110-120 — [Stealing](https://www.uoguide.com/Stealing) | `maxAmount = (int)((Stealing.Value / 10.0) / toSteal.Weight)` — `Scripts/Skills/Stealing.cs:299`; difficulty window `pileWeight - 22.5 … pileWeight + 27.5` where `pileWeight = ceil(weight) * 10` — `:315-327` | `[SRC+WEB]` for skill/10; window constants `[SRC]` only |
| 23 | Hiding success chance | "The chance of hiding successfully is directly equal to that of the Hiding skill" — [Hiding](https://www.uoguide.com/Hiding) | `m.CheckSkill(SkillName.Hiding, 0.0 - bonus, 100.0 - bonus)` — `Scripts/Skills/Hiding.cs:96` | `[SRC+WEB]` |
| 24 | Hiding minimum distance | "At GM Hiding, a character may hide in plain sight of a hostile monster or other player only 8 tiles away" — [Hiding](https://www.uoguide.com/Hiding) | `range = Math.Min((int)((100 - skill) / 2) + 8, 18); //Cap of 18 not OSI-exact, intentional difference` — `Scripts/Skills/Hiding.cs:71-72`; the OSI formula is left commented: `//int range = 18 - (int)(Hiding.Value / 10);` — `:70` | `[SRC+WEB]` at GM (both give 8). **Divergence mid-range**: at 50 Hiding code gives 18 (capped) vs OSI-formula 13. Code itself flags the cap as non-OSI |
| 25 | Stealth requirements | "The character must have at least 30.0 Hiding"; "At 25.0 Stealth or higher, the effect will activate automatically"; "Every 5 levels of Stealth increases the distance a character may walk before a skill check (e.g. 80 Stealth = 16 safe steps)" — [Stealth](https://www.uoguide.com/Stealth) | `HidingRequirement => Core.ML ? 30.0 : (Core.SE ? 50.0 : 80.0)` — `Scripts/Skills/Stealth.cs:24-28`; `steps = (int)(Stealth.Value / (Core.AOS ? 5.0 : 10.0))`, minimum 1 — `:106-109` | `[SRC+WEB]` for the ML-era 30.0/5-step rule (80/5 = 16, exact). **Era divergence**: pre-AoS = 80.0 Hiding and 10 skill per step; SE = 50.0 |
| 26 | Meditation mana rate | "Rate from Med & Int = 2 + (Meditation * 3 + Intelligence) / 40"; "If you have a skill of 100 or better in Meditation you get a 10% bonus, making the GM+ formula: 2 + (1.1 * (Meditation * 3 + Intelligence) / 40)" — [Meditation](https://www.uoguide.com/Meditation) | `medPoints = (Int + Meditation*3) * (Meditation < 100.0 ? 0.025 : 0.0275)` — `Scripts/Misc/RegenRates.cs:156-158` (0.025 = 1/40, 0.0275 = 1.1/40) | `[SRC+WEB]` exact, including the ×1.1 at 100 |
| 27 | Meditation blocked by armour | "A character receives neither passive nor active Meditation bonuses while wearing non-medable armor unless it has Mage Armor" — [Meditation](https://www.uoguide.com/Meditation) | `if (armorPenalty > 0) medPoints = 0; // In AOS, wearing any meditation-blocking armor completely removes meditation bonus` — `RegenRates.cs:164-165`; `Core.AOS && GetArmorOffset(m) > 0` → "Regenerative forces cannot penetrate your armor!" — `Scripts/Skills/Meditation.cs:52-54` | `[SRC+WEB]` |
| 28 | Bandage cure threshold | "At 60.0 skill in Anatomy and Healing you will be able to cure poison" — [Healing](https://www.uoguide.com/Healing) | `checkSkills = (healing >= 60.0 && anatomy >= 60.0)` — `Scripts/Items/Resource/Bandage.cs:445` | `[SRC+WEB]` |
| 29 | Bandage resurrect threshold | "At 80.0 skill in Anatomy and Healing you will be able to resurrect dead players" — [Healing](https://www.uoguide.com/Healing) | `checkSkills = (healing >= 80.0 && anatomy >= 80.0)` — `Bandage.cs:345` (self-heal cure variant `:613-614`) | `[SRC+WEB]` |
| 30 | Bandage interruption penalty | "more than 26 damage by a monster or more than 19 damage by another player. The amount of damage healed will be reduced by 35% per interruption" — [Healing](https://www.uoguide.com/Healing) | `toHeal -= toHeal * m_Slips * 0.35; // TODO: Verify algorithm` — `Bandage.cs:531` (35 % per slip confirmed; the 26/19 thresholds live in the slip-detection path and were not pinned to a line in this pass) | `[SRC+WEB]` for 35 %; `[PARTIAL]` for 26/19 |
| 31 | Enhanced bandage bonus | "Using an Enhanced Bandage from the Fountain of Life will give a +10 boost to your healing skill" — [Healing](https://www.uoguide.com/Healing) | `m_HealingBonus += EnhancedBandage.HealingBonus` — `Bandage.cs:215`; `if (m_HealingBonus > 0) healing += m_HealingBonus;` — `:500-501`; `public static int HealingBonus { get { return 10; } }` — `Scripts/Items/Addons/FountainOfLife.cs:28-34` (literal at `:32`) | `[SRC+WEB]` exact (+10) |
| 32 | Bandage heal amount curve | Table "Minimum and Maximum Amount of Damage Healed", rows = Anatomy 0-120, cols = Healing 0-120 — [Healing](https://www.uoguide.com/Healing) | AoS: `min = Anatomy/8 + Healing/5 + 4`, `max = Anatomy/6 + Healing/2.5 + 4` — `Bandage.cs:513-514`; pre-AoS: `min = Anatomy/5 + Healing/5 + 3`, `max = Anatomy/5 + Healing/2 + 10` — `:518-519` | **Neither branch reproduces the table.** The printed table fits `min = 3 + (H+A)/6`, `max = 10 + H/3 + A/6` (verified at 4 corners and 1 interior cell: A120/H120 → 43-70; A0/H0 → 3-10; A0/H120 → 23-50; A120/H0 → 23-30; A60/H50 → 21-36). Code denominators differ (5/5 and 2 AoS-vs-classic mix). Treat the wiki table as a *different era's* curve; use `Bandage.cs` for mechanics |
| 33 | Poisoning self-poison risk | not published in this form | `if (Skills[Poisoning].Base < 80.0 && Utility.Random(20) == 0)` → 5 % self-poison below 80 — `Scripts/Skills/Poisoning.cs:145-148` | `[SRC]` only |
| 34 | Poisoning skill reuse delay | not published | `TimeSpan.FromSeconds(10.0)` — `Scripts/Skills/Poisoning.cs:20` | `[SRC]` only |
| 35 | Poison charges per application | not published | `PoisonCharges = 18 - (Poison.RealLevel * 2)` — `Scripts/Skills/Poisoning.cs:125,130,135` | `[SRC]` only |
| 36 | Tracking range/tiers | page has no numeric tier table; only "Humans have an inferred minimum of 20 skill points in Tracking, due to their Jack of all Trades trait" — [Tracking](https://www.uoguide.com/Tracking) | not verified in this pass | `[PARTIAL]` — the wiki simply does not publish tracking tiers; code table must be read from `Scripts/Skills/Tracking.cs` (see section 40) |
| 37 | Animal Taming pet caps | "Its skills cap will decrease 10% if the skill is higher than 100 before taming"; "The DEX cap for all new tamed pets is 125" — [Animal Taming](https://www.uoguide.com/Animal_Taming) | not verified in this pass | `[WEB]` only |
| 38 | Discordance debuff magnitude | 50.0 skill → 12.5 %; 100.0 → 25 %; 120.0 → 28 %; halved (14 %) against barding difficulty 160 — [Discordance](https://www.uoguide.com/Discordance), [Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) | bard difficulty cap `MaxBardingDifficulty = 160.0` — `ServUO:Scripts/Items/Equipment/Instruments/BaseInstrument.cs:14,408-409` | `[SRC+WEB]` for the 160 cap; `[WEB]` only for the 12.5/25/28 % curve |
| 39 | Bard range | "The base range of all bard abilities is 8 tiles, with each 15 points of skill in the ability being used increasing this range by one tile" — [Discordance](https://www.uoguide.com/Discordance) | `GetBardRange => 8 + (int)(bard.Skills[skill].Value / 15)` — `BaseInstrument.cs:296-299` | `[SRC+WEB]` exact |
| 40 | Bard success window | "Barding Difficulty … indicates the skill level that a Bard must have for a 50% chance of success … 25 points below → no chance … 25 points above → 100%" — [Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) | `from.CheckTargetSkill(SkillName.Provocation, target, diff - 25.0, diff + 25.0)` — `Scripts/Skills/Provocation.cs:155`; window-to-chance mapping `(value - min)/(max - min)` — `Scripts/Misc/SkillCheck.cs:153,306` | `[SRC+WEB]` exact |
| 41 | Instrument quality/slayer modifiers | "A GM Carpenter created instrument adds 10% to your success chance. A Slayer Instrument adds 20% … or removes 20% if it doesn't match" — [Provocation](https://www.uoguide.com/Provocation) | exceptional `val -= 5.0; // 10%`; slayer match `val -= 10.0; // 20%`; opposition `val += 10.0; // -20%` — `BaseInstrument.cs:418-431,434-457` | `[SRC+WEB]` on the 20 % rows; **`[PARTIAL]` on the exceptional row**: code subtracts 5.0 difficulty while its own comment says "10%", and the wiki says 10 % |
| 42 | Provocation between-attempt delay | not published on the page fetched | `from.NextSkillTime = Core.TickCount + 10000` (10 s) and `10000 - (masteryBonus/5)*1000` with mastery — `Scripts/Skills/Provocation.cs:125,146,157` | `[SRC]` only |
| 43 | Peacemaking mode/era | "Each time Targeted Peacemaking is attempted, a difficulty check is performed based on the creature's Barding Difficulty versus the … combined skill in Musicianship and Peacemaking"; "Targeted Peacemaking was introduced with Publish 16" — [Peacemaking](https://www.uoguide.com/Peacemaking) | code computes `diff` from instrument-vs-creature difficulty and adds `music > 100 ? -(music-100)*0.5 : 0` — `Provocation.cs:127-140`; `Musicianship` is checked separately via `BaseInstrument.CheckMusicianship` → `CheckSkill(Musicianship, 0.0, 120.0)` — `BaseInstrument.cs:708-710` | `[SRC+WEB]` on direction; exact combined-skill arithmetic `[SRC]` |
| 44 | Instrument bonus from crafting | "features a 10% success bonus over NPC-purchased musical instruments" — [Musicianship](https://www.uoguide.com/Musicianship) | same `-5.0 // 10%` exceptional path — `BaseInstrument.cs:418-419` | `[WEB]` vs code-comment 10 % (consistent), numeric constant 5.0 difficulty |
| 45 | Poison level damage/duration | Lesser ~4-7 % of current HP / 2 s / 30 s; Standard ~5-10 % max HP / 3 s / 30 s; Greater ~7-15 % / 4 s / 1 min; Deadly ~15-30 % / 5 s / 1 min; Lethal ~16-33 % / 5 s / 1 min 20 s — [Poison](https://www.uoguide.com/Poison) | see 7.6 (full code table) | `[SRC+WEB]` on shape and ordering; per-level numbers differ slightly (both printed in 7.6) |
| 46 | Poison skill needed per level | Poisoning training page: 30-40 Lesser, 40-70 Poison, 70-92 Greater, 92-100 Deadly — [Poisoning](https://www.uoguide.com/Poisoning); monsters "scaling up to Lethal at 120 skill" — [Poison](https://www.uoguide.com/Poison) | per-potion attempt windows: Lesser 0-60, Regular 30-70, Greater 60-100, Deadly 80-100, Darkglow 95-100, Parasitic 95-100 — `Scripts/Items/Consumables/{LesserPoisonPotion,PoisonPotion,GreaterPoisonPotion,DeadlyPoisonPotion,DarkglowPotion,ParasiticPotion}.cs:25-36` | **Different quantities**: wiki = training sweet spots, code = valid attempt windows. Only "Regular ends at 70" overlaps exactly |
| 47 | Cure potion tiers | "Cure Potion … come in three types, lesser, standard and greater"; "at least 60 Healing and Anatomy may attempt to cure Poison using Bandages" — [Poison](https://www.uoguide.com/Poison) | `LesserCurePotion` cure table `new CureLevelInfo(Poison.Regular, 0.35)` — `Scripts/Items/Consumables/LesserCurePotion.cs:16`; bandage cure 60/60 at `Bandage.cs:445` | `[SRC+WEB]` for 60/60; cure-chance constants `[SRC]` only |
| 48 | New-player skill purchase price | "1 GP per 1/10 of skill with the highest amount of skill costing 400 gold for 40 skill points" — [Skills](https://www.uoguide.com/Skills) | not verified in this pass | `[WEB]` only |
| 49 | Skill lock / stat lock | UO:R, 2000-05-04 "introduced the Skill lock and the Stat lock" — [Renaissance](https://www.uoguide.com/Ultima_Online:_Renaissance) | `enum SkillLock { Up = 0, Down = 1, Locked = 2 }` — `Server/Skills.cs:21-26`, default `SkillLock.Up` — `:125`; `StatLockType.Up` used at `Scripts/Misc/SkillCheck.cs:470-475` | `[SRC+WEB]` `[ERA]` |
| 50 | Skill count | "58 different Skills currently in game (and 1 removed)" — [Skills](https://www.uoguide.com/Skills) | `new SkillInfo[58]` — `Server/Skills.cs:594`; 58-member enums `:28-88` and `ClassicUO:…/SkillsLoader.cs:90-150` | `[SRC+WEB]` |

#### 7.4.1 GGS table, row by row (published vs `GGSTable`)

Published columns are labelled **350 / 500 / 700 total skill points**; code columns are threshold-banded `Total < 350` / `350 ≤ Total < 700` / `Total ≥ 700` (`SkillCheck.cs:793`). So the middle column's *label* differs (500 vs "350-699.9") even where every number matches.

| Skill bracket | published 350 / 500 / 700 (min) | code row (min) | verdict |
|---|---|---|---|
| 0.0-4.9 | 1 / 3 / 5 | 1, 3, 5 | exact |
| 5.0-9.9 | 4 / 10 / 18 | 4, 10, 18 | exact |
| 10.0-14.9 | 7 / 17 / 30 | 7, 17, 30 | exact |
| 15.0-19.9 | 9 / 24 / 44 | 9, 24, 44 | exact |
| 20.0-24.9 | 12 / 31 / 57 | 12, 31, 57 | exact |
| 25.0-29.9 | 14 / 38 / **72** (1.2 h) | 14, 38, **90** | **MISMATCH** (+18 min in code) |
| 30.0-34.9 | 17 / 45 / 84 | 17, 45, 84 | exact |
| 35.0-39.9 | 20 / 52 / 96 | 20, 52, 96 | exact |
| 40.0-44.9 | 23 / 60 / **108** (1.8 h) | 23, 60, **106** | **MISMATCH** (-2 min in code) |
| 45.0-49.9 | 25 / 66 / 120 | 25, 66, 120 | exact |
| 50.0-54.9 | 27 / 72 / 138 | 27, 72, 138 | exact |
| 55.0-59.9 | 33 / 90 / 162 | 33, 90, 162 | exact |
| 60.0-64.9 | 55 / 150 / 264 | 55, 150, 264 | exact |
| 65.0-69.9 | 78 / 216 / 390 | 78, 216, 390 | exact |
| 70.0-74.9 | 114 / 294 / 540 | 114, 294, 540 | exact |
| 75.0-79.9 | 144 / 384 / 708 | 144, 384, 708 | exact |
| 80.0-84.9 | 180 / 492 / 900 | 180, 492, 900 | exact (this is the wiki's own worked example: "82.3 Blacksmithy … 15.0 hours") |
| 85.0-89.9 | 228 / 606 / 1116 | 228, 606, 1116 | exact |
| 90.0-94.9 | 276 / 744 / 1356 | 276, 744, 1356 | exact |
| 95.0-99.9 | 336 / 894 / 1620 | 336, 894, 1620 | exact |
| 100.0-104.9 | 396 / 1056 / 1920 | 396, 1056, 1920 | exact |
| 105.0-109.9 | 468 / 1242 / 2280 | 468, 1242, 2280 | exact |
| 110.0-114.9 | 540 / 1440 / 2580 | 540, 1440, 2580 | exact |
| 115.0-120.0 | 618 / 1662 / 3060 | 618, 1662, 3060 | exact |

Verdict: `[SRC]` + `[WEB]` — 22/24 rows byte-identical to the official table; two cells were mistyped/diverged in code (row 6 col 3, row 9 col 3). If the clone targets OSI parity, use the published values and fix `SkillCheck.cs:801,802`.

### 7.5 What is *not* published anywhere (measurements instead)

| Item | Why it is unverifiable from prose | What to measure |
|---|---|---|
| Authoritative active/passive per skill | UOGuide has no such field (only 7 pages use Active/Passive as training subheads) | read byte 0 of each `skills.mul` entry (`hasAction`) — format documented in `ClassicUO:src/ClassicUO.Assets/SkillsLoader.cs:47` and `ServUO:Ultima/Skills.cs:75-80` |
| Real client skill-window groups | `skillgrp.mul` is data; ClassicUO's lists are a fallback (`SkillsGroupManager.cs:278-296`) | parse `skillgrp.mul` (group-name table + one int32 per skill, `:466-532`) and read the group id per skill index |
| Pre-SA slot count / blank slots | no source states it | count `length > 0` records in a pre-SA `skills.idx` (see 7.2) |
| Exact OSI barding difficulty per creature | wiki publishes the *scale* and the 160 cap only | `BaseInstrument.GetBaseDifficulty` (`:374-412`) is ServUO's approximation; to match OSI you must instrument a live client or trust the code |
| Stat timer semantics per era | three conflicting published rules (7.4 row 13) | set `PlayerCaps.EnablePlayerStatTimeDelay=true, PlayerStatTimeDelay=00:15:00` for classic-style behaviour; measure gains per hour on a live shard for OSI parity |
| Tracking range/tiers | [Tracking](https://www.uoguide.com/Tracking) publishes no numbers | read `Scripts/Skills/Tracking.cs` + measure reveal radius in game |
| Animal Taming control/mastery numbers | page gives training tiers and pet caps only | read `Scripts/Skills/AnimalTaming.cs` and `BaseCreature` taming difficulty values |

### 7.6 Poison levels (published vs code)

Published effect/damage table `[WEB]` — [UOGuide — Poison](https://www.uoguide.com/Poison):

| Type | Effect | Duration |
|---|---|---|
| Lesser | ~4-7 % current HP per 2 seconds | 30 s |
| Standard | ~5-10 % maximum HP per 3 seconds | 30 s |
| Greater | ~7-15 % maximum HP per 4 seconds | 1 min |
| Deadly | ~15-30 % maximum HP per 5 seconds | 1 min |
| Lethal | ~16-33 % maximum HP per 5 seconds | 1 min 20 s |

Code `[SRC]` — `ServUO:Scripts/Misc/Poison.cs`. Constructor signature at `:126-146`: `(name, level, min, max, percent, delay, interval, count, messageInterval)`; damage roll `damage = 1 + (int)(Hits * Scalar)` clamped to `[min, max]` at `:214-230`; `Scalar = percent * 0.01` at `:141`; timer built with `base(delay, interval)` and repeated `count` times.

| Level | Name | Wiki skill-to-apply | Code attempt window (potion) | min-max damage clamp | % of Hits | delay / interval (s) | ticks | msg interval |
|---|---|---|---|---|---|---|---|---|
| 0 | Lesser | 30-40 training | 0.0-60.0 (`LesserPoisonPotion.cs:29,36`) | 4-16 (AoS) / 4-26 (pre-AoS) `:23,31` | 7.5 / 2.5 | 3.0 / 2.25 (AoS) · 3.5 / 3.0 (pre-AoS) | 10 both | 4 (AoS) / 2 |
| 1 | Regular ("Standard" in wiki) | 40-70 | 30.0-70.0 (`PoisonPotion.cs:29,36`) | 8-18 / 5-26 `:24,32` | 10.0 / 3.125 | 3.0 / 3.25 · 3.5 / 3.0 | 10 both | 3 / 2 |
| 2 | Greater | 70-92 | 60.0-100.0 (`GreaterPoisonPotion.cs:29,36`) | 12-20 / 6-26 `:25,33` | 15.0 / 6.25 | 3.0 / 4.25 · 3.5 / 3.0 | 10 both | 2 / 2 |
| 3 | Deadly | 92-100 | 80.0-100.0 (`DeadlyPoisonPotion.cs:29,36`) | 16-30 / 7-26 `:26,34` | 30.0 / 12.5 | 3.0 / 5.25 · 3.5 / 4.0 | 15 both | 2 / 2 |
| 4 | Lethal | not stated (monsters "up to Lethal at 120") | no potion class (NPC/spell only) | 20-50 / 9-26 `:27,35` | 35.0 / 25.0 | 3.0 / 5.25 · 3.5 / 5.0 | 20 both | 2 / 2 |
| 10-13 | Darkglow (ML) | — | 95.0-100.0 (`DarkglowPotion.cs:30,37`) | as AoS Lesser…Deadly `:41-44` | as AoS | as AoS | as AoS | as AoS |
| 14-18 | Parasitic (ML) | — | 95.0-100.0 (`ParasiticPotion.cs:30,37`) | as AoS Lesser…Lethal `:46-50` | as AoS | as AoS | as AoS | as AoS |

Notes: `RealLevel` maps 10-13 → 0-3 and 14-18 → 0-4 (`Poison.cs:89-104`); the wiki's "Lesser is the only one that deals damage based on your current Hit Points level; the others deal the same range of damage regardless" matches the code's pre-AoS-only `m_LastDamage` reuse at `:216-219` plus the uniform `Hits * Scalar` formula for AoS. Poisoning also "grants a natural poison resistance which is 20% of the player's poisoning skill" ([Poisoning](https://www.uoguide.com/Poisoning)) — `[WEB]` only, not verified in code in this pass.

### 7.7 Published bard difficulty tiers

* Scale definition and window `[WEB]`: "Barding Difficulty is a value that indicates the skill level that a Bard must have for a 50% chance of success"; -25 → 0 %, +25 → 100 %; capped at 160 since Publish 28 (mid-January 2005) — [Barding Difficulty](https://www.uoguide.com/Barding_Difficulty). Code matches the window exactly (`Provocation.cs:155`, `SkillCheck.cs:153`) and the 160 cap (`BaseInstrument.cs:14,408-409`).
* Discordance tiers `[WEB]`: 50.0 → 12.5 %, 100.0 → 25 %, 120.0 → 28 %; halved to 14 % vs barding difficulty 160 — [Discordance](https://www.uoguide.com/Discordance), [Barding Difficulty](https://www.uoguide.com/Barding_Difficulty).
* Provocation training tiers as published `[WEB]` ([Provocation](https://www.uoguide.com/Provocation)): 0-30 birds/rabbits, 30-40 farm animals, 40-65 bulls/scorpions/great harts/polar bears, 65-90 giant beetles, 90-100 hiryu, 100-110 cu sidhe; "At 120 provo and gm music, you have 100% chance to provoke 2 dragons. At gm provo and music, you only have a 60% chance"; "With 100.0 Musicianship, you will have a 100% chance to pass the first skill check when Provoking or Peacemaking".
* Difficulty is computed from the creature, not published as a table: `GetBaseDifficulty` = `HitsMax*1.6 + StamMax + ManaMax + SkillsTotal/10`, +100 each for magery creature / fire breather / poison immune / vampire bat, `+ poisonLevel*20`, soft-knee at 700 (`val = 700 + (val-700)*3/11`), then `/10`, `+40` if paragon, clamped to 160 when `Core.SE` — `BaseInstrument.cs:374-412` `[SRC]`.

### 7.8 The three different "skill group" lists (do not conflate)

| List | Groups | Source |
|---|---|---|
| Client skill window (`skillgrp.mul`) | Miscellaneous (implicit, index 0), Combat, Trade Skills, Magic, Wilderness, Thieving, Bard | `ClassicUO:src/ClassicUO.Client/Game/Managers/SkillsGroupManager.cs:299-455` (CUO defaults), MUL parser `:457-548` `[SRC]` / `[PARTIAL]` (real names live in the data file) |
| UOGuide directory | Combat, Magical, Bardic, Rogue, Creatures & Sensing, Crafting, Resource Gathering | [UOGuide — Skills](https://www.uoguide.com/Skills) `[WEB]` |
| Jewelry skill-bonus groups (item property rule, 1 skill per group per item) | G1 Fencing, Mace Fighting, Swordsmanship, Musicianship, Magery · G2 Wrestling, Taming, Spirit Speak, Tactics, Provocation · G3 Focus, Parrying, Stealth, Meditation, Animal Lore, Discordance · G4 Mysticism, Bushido, Necromancy, Veterinary, Stealing, Anatomy, Evaluating Intelligence · G5 Peacemaking, Throwing, Ninjitsu, Chivalry, Archery, Resisting Spells, Healing | [UOGuide — Skill Groups](https://www.uoguide.com/Skill_Groups) (redirects to "Skill Bonuses") `[WEB]` |

Note: `https://www.uoguide.com/Skill_Groups` does **not** describe the client window groups — it is a redirect to the jewelry bonus-group page. That is the most likely source of "skill group" confusion in a clone spec.

### 7.9 Sources that failed (and what to use instead)

| URL tried | Failure | Substitute used |
|---|---|---|
| https://www.uoguide.com/Skill_Gain | HTTP 404 (twice, incl. via `Invoke-WebRequest`) | [uo.com — Skill Gain Systems](https://uo.com/wiki/ultima-online-wiki/technical/skill-gain-systems/) (offical EA copy) + [UOGuide — Guaranteed Gain System](https://www.uoguide.com/Guaranteed_Gain_System) (mirrors Stratics text) `[WEB]` |
| https://www.uoguide.com/Skill_Scroll | HTTP 404 | [Power Scrolls](https://www.uoguide.com/Power_Scroll), [Stat Scrolls](https://www.uoguide.com/Stat_Scroll), [Scroll of Alacrity](https://www.uoguide.com/Scroll_of_Alacrity), [Scroll of Transcendence](https://www.uoguide.com/Scroll_of_Transcendence) |
| https://www.uoguide.com/Greater_Poison | HTTP 404 | [Poison](https://www.uoguide.com/Poison) + `Scripts/Items/Consumables/GreaterPoisonPotion.cs` |
| https://www.uoguide.com/Skills_List, /Bard, /Bardic_Skills, /Skill_Group, /Skills_Window | HTTP 404 | [Skills](https://www.uoguide.com/Skills), [Skill Groups](https://www.uoguide.com/Skill_Groups) |
| `https://uo.stratics.com/` and every subpath tried — `content/basics/ggs_archive.shtml`, `content/guides/blacksmith/bs_ex2.shtml`, `content/skills/stealing.php`, `content/skills/index.php`, `skills/` | HTTP **403 Forbidden** to scripted fetches (all 5 URLs) | uo.com official copies (GGS) and UOGuide transcriptions. Stratics prose is *unverified in this session* — if Stratics parity matters (e.g. the classic blacksmith success-rate essay), fetch it from a browser or cite the UOGuide mirror |
| `https://uo.com/wiki/.../2002-publish-16-part-1-23rd-july/` and `.../2003-publish-21-1st-february/` | connection closed by remote (2 attempts) | Enticement→Discordance is cited from [UOGuide — Enticement](https://www.uoguide.com/Enticement) instead of Publish 16 part 1; Publish 16 **part 2** (GGS/stat rules) fetched fine |
| UOGuide search API (`api.php?action=query&list=search`) | returned empty result set (no error) | direct page fetches by slug |

Local mirrors of every successfully fetched page are kept at `E:\Workspaces\game-clone\.research-src\uoguide\` (`*.html` raw, `txt\*.txt` tag-stripped) so any number above can be re-checked without the network.

### 7.10 Confidence summary for this section

* `[SRC+WEB]` (both agree, exact constant): total cap 700.0 default, 100.0 individual cap, 105/110/115/120 power scroll tiers and names, +5/+10/+15/+20/+25 stat scroll tiers, 225 stat cap, 125 individual stat cap, 5 % stat-gain chance, 75/25 primary/secondary stat roll, 0.1 gain increment, X+50 craft-gain window, stealth 5-skill steps, meditation `2 + (Med*3+Int)/40` and ×1.1 at 100, bandage 60/60 cure and 80/80 resurrect, 35 % interruption, bard 8-tile range + `skill/15`, bard ±25 window, 160 barding cap, Siege RoT 5/8/12/15 min, 22/24 GGS rows.
* `[SRC]` only: GGS column thresholds (350/700 vs the published 350/500/700 labels), anti-macro allowance/expiry, craft-all gain divisor, provoke 10 s delay, poison charges and self-poison chance, barding difficulty formula internals.
* `[WEB]` only (needs code verification before use): skill purchase price rule, discord 12.5/25/28 % curve, poison level durations (30 s … 1 min 20 s), animal taming pet-cap rules, tracking tiers (absent).
* Contradictions flagged: Discordance primary stat (wiki Int vs code Dex); Discordance/Fishing in the power-scroll list (35 vs 34); Siege stat points per day (6 vs 15); GGS rows 6 and 9 col 3; bandage heal table (wiki curve `3+(H+A)/6 … 10+H/3+A/6` vs code `Anatomy/8+Healing/5+4 …`); hiding mid-range distance (code cap 18, self-declared non-OSI); exceptional-instrument 10 % vs the code's 5.0 difficulty constant; poisoning skill windows (training spot vs attempt window); the brief's own SE/ML era mix-up.
