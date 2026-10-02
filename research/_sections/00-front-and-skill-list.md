# Ultima Online — The Complete Skill System (research dossier for a faithful offline clone)

**Deliverable:** `research/02-skills.md` · **Status:** source-derived, era-annotated, gaps marked
**Primary target of the clone:** ServUO `pub57` mechanics (RunUO lineage = the OSI server model), with
ModernUO used as an independent second reading of the same constants, and ClassicUO for everything the
*client* owns (skill list, groups, gumps, caps display, packet formats).

---

## 0. How to read this document

### 0.1 Source checkouts (all local, all greppable, all revisions recorded)

| Key used in citations | Repository | Revision checked out | Role |
|---|---|---|---|
| `ServUO:` | https://github.com/ServUO/ServUO | branch `pub57` | **primary** mechanics source (RunUO lineage) |
| `ModernUO:` | https://github.com/modernuo/ModernUO | `main` | independent re-reading; divergences shown explicitly |
| `ClassicUO:` | https://github.com/ClassicUO/ClassicUO | `main` | client-side skill list/groups/gumps/packets |
| `[WEB]` | UOGuide / uo.com publish notes | fetched this session | era dates, published tables, cross-checks |

URL forms: `https://github.com/ServUO/ServUO/blob/pub57/<path>#L<line>` ·
`https://github.com/modernuo/ModernUO/blob/main/Projects/<path>#L<line>` ·
`https://github.com/ClassicUO/ClassicUO/blob/main/src/<path>#L<line>`.
A local evidence cache of every successfully fetched web page is kept in
`E:\Workspaces\game-clone\.research-src\uoguide\` (raw `*.html` + tag-stripped `txt\*.txt`).

### 0.2 Confidence markers (applied per formula, per table, per row where it matters)

| Marker | Meaning |
|---|---|
| `[SRC]` | read directly out of server/client source, cited `path:LINE` |
| `[WEB]` | authoritative prose only (UOGuide, uo.com patch/publish notes), URL given |
| `[SRC+WEB]` | code and published prose agree exactly |
| `[DERIVED from SRC]` | arithmetic performed by this research on source constants; the arithmetic is shown |
| `[PARTIAL]` | partially evidenced — the missing part is named |
| `[ERA]` | expansion-gated (classic / AoS / SE / ML / SA / HS / ToL); says which |
| `[UNVERIFIED]` | **no number is invented**; the doc says what would have to be measured |

### 0.3 Era anchors (used for every `[ERA]` note)

| Era | Date | Source |
|---|---|---|
| UO launch (classic) | 1997-09-24 | [UOGuide — Ultima Online](https://www.uoguide.com/Ultima_Online) |
| T2A | 1998-10-24 | [UOGuide — The Second Age](https://www.uoguide.com/Ultima_Online:_The_Second_Age) |
| UO:R (skill lock + stat lock) | 2000-05-04 | [UOGuide — Renaissance](https://www.uoguide.com/Ultima_Online:_Renaissance) |
| Publish 16 (GGS, stat/power scrolls, Enticement→Discordance) | 2002-07-23 | [uo.com — Publish 16 part 2](https://uo.com/wiki/ultima-online-wiki/technical/previous-publishes/2002-2/2002-publish-16-part-2-23rd-july/) |
| AoS (Necromancy, Focus, Chivalry) | 2003-02-11 | [UOGuide — Age of Shadows](https://www.uoguide.com/Age_of_Shadows) |
| SE (Bushido, Ninjitsu) | 2004-11-02 | [UOGuide — Samurai Empire](https://www.uoguide.com/Samurai_Empire) |
| ML (Spellweaving, skill masteries) | 2005-08-30 | [UOGuide — Mondain's Legacy](https://www.uoguide.com/Mondain%27s_Legacy) |
| SA (Mysticism, Imbuing, Throwing) | 2009-09-08 | [UOGuide — Stygian Abyss](https://www.uoguide.com/Stygian_Abyss) |

Server-side era gates are code, not prose: `ServUO:Server/Main.cs:147-150` (`Core.AOS/SE/ML/SA`),
`ServUO:Server/ExpansionInfo.cs:7-21,159-245`. ServUO's **shipped default is `CurrentExpansion=EJ`**
(`ServUO:Config/Expansion.cfg`) — i.e. every `Core.AoS`-and-later branch is active unless reconfigured.

### 0.4 Document map

| § | Content | Origin |
|---|---|---|
| 1 | The complete skill list: ids, groups, stats, active/passive, mechanics, check type | this section (below) |
| 1b | Client side: groups from `skillgrp.mul`, all 58 client names, caps display, gumps, packet wire format | ClassicUO + ServUO packets |
| 2 | Skill use model per skill (trigger, target, delay, outcomes, messages, resources) | ServUO `Scripts/Skills/**`, items |
| 2b | Combat & magery skill formulas (swing delay, hit, damage, parry, resist, cast, meditate) | ServUO combat/spell code |
| 3 | Skill gain & stat gain (GGS, anti-macro, caps arbitration, stat locks) | `Scripts/Misc/SkillCheck.cs` + `Server/Skills.cs` |
| 4 | Crafting engine core (success, exceptional, resources, tools, gump, make-last/number) | `Scripts/Services/Craft/Core/**` |
| 4b-4d | Crafting menus as data tables, per system | `Def*.cs` |
| 5 | Hide / Stealth / Thief package (+ flagging consequences) | `Scripts/Skills/{Hiding,Stealth,Snooping,Stealing}.cs` |
| 6 | Bard skills (Musicianship, Provocation, Discordance, Peacemaking) + instruments + tiers | `Scripts/Skills/**`, `BaseInstrument.cs` |
| 7 | Era matrix + published-number cross-check + failed sources | UOGuide / uo.com vs code |
| 8 | Consolidated open questions (what is UNVERIFIED and how to measure it) | all sections |

---

## 1. The complete skill list

### 1.1 How a skill is represented (numbers a clone must fix first)

| Fact | Value / formula | Evidence |
|---|---|---|
| Skill id space | `0..57`, dense, no holes; `SkillName` enum in id order | `ServUO:Server/Skills.cs:28-88` |
| Table size | `SkillInfo[] m_Table = new SkillInfo[58]` (58 entries, no placeholder rows; entries at `:596-653`) | `ServUO:Server/Skills.cs:594` |
| Internal storage | **fixed point**: `ushort m_Base` where `1000 == 100.0` skill; `BaseFixedPoint`, `CapFixedPoint` | `ServUO:Server/Skills.cs:95,285-347` |
| Displayed value | `Base` = `m_Base / 10.0`; `Cap` = `m_Cap / 10.0` | `ServUO:Server/Skills.cs:322,350-364` |
| Default per-skill cap | `1000` fixed point = **100.0** for a new skill (`new Skill(this, SkillInfo.Table[skillID], 0, 1000, SkillLock.Up)`) | `ServUO:Server/Skills.cs:874`; config `SkillCap=1000` in `Config/PlayerCaps.cfg` |
| Cap ceiling | power scrolls 105/110/115/120 set `Skills[skill].Cap` | `ServUO:Scripts/Items/Consumables/PowerScroll.cs:206-222` |
| Default total cap | `Config.Get("PlayerCaps.TotalSkillCap", 7000)` = **700.0** | `ServUO:Server/Skills.cs:996`; `Config/PlayerCaps.cfg: TotalSkillCap=7000` |
| Lock states | `enum SkillLock : byte { Up = 0, Down = 1, Locked = 2 }`, default `Up` | `ServUO:Server/Skills.cs:21-26,125` |
| "Effective" value | `NonRacialValue` = `Base` + stat offset + skill mods, where stat offset = `(Str*StrScale + Dex*DexScale + Int*IntScale) * (100-Base)/100`, clamped to `StatTotal * (100-Base)/100`, then racial bonus floors it, then relative/absolute skill mods (cap-obeying vs cap-ignoring) are applied | `ServUO:Server/Skills.cs:392-468` |
| Stat influence is **off** by default | `AOS.DisableStatInfluences()` zeroes `StrScale/DexScale/IntScale/StatTotal` for all 58 skills and is called whenever `Core.AOS` | `ServUO:Scripts/Misc/AOS.cs:36-49`, `ServUO:Scripts/Misc/CurrentExpansion.cs:32-39` |
| ⚠ clone consequence | On an AoS+ shard (ServUO default = EJ) **skill value == base skill**; the `StrScale/DexScale/IntScale` columns in the table below are dead weight unless a pre-AoS/T2A clone explicitly re-enables them (`UseStatMods` is declared but never assigned in ServUO: `Server/Skills.cs:366-368`) |
| Stat gain weights | `StrGain/DexGain/IntGain` per skill (declared `:580-582`) — **note:** the `TryStatGain` code uses only `Primary`/`Secondary`, *not* these weights | `ServUO:Server/Skills.cs:580-582` vs `Scripts/Misc/SkillCheck.cs:544-563` |
| Mastery flag | `SkillInfo.IsMastery` = the skill has an ML **skill mastery** (era-later); `VolumeLearned` 0-3 | `ServUO:Server/Skills.cs:470-507,588` |
| Skill title / cliloc | each skill has a profession `Title` ("Alchemist", …) and `Localization => 1044060 + SkillID` | `ServUO:Server/Skills.cs:592,596-653` |

### 1.2 There are FIVE different "skill group" lists — do not conflate them

The task brief asked for "the client's skill group file ordering: Combat, Magery, Bardic, Crafting,
Wilderness, Lore/Knowledge, Misc". **That list is not any single real list.** Three real lists exist
(client data file, server gump, server scroll-books) plus two published ones. All are documented here.

#### (A) Client skill window — `skillgrp.mul` (data file; ClassicUO fallback shown)

`ClassicUO:src/ClassicUO.Client/Game/Managers/SkillsGroupManager.cs:299-455` (fallback groups) and
`:457-548` (the `skillgrp.mul` parser: int32 group count, fixed-width group-name table, then one int32
group id per skill index). Group 0 is implicit, non-deletable, named `Miscellaneous`
(`:174-178,282,489`). Real names live in the data file; the names below are ClassicUO's literals.

| # | Group (literal name) | Skills (ids) | Count |
|---|---|---|---|
| 0 | `Miscellaneous` | 4 ArmsLore, 6 Begging, 10 Camping, 12 Cartography, 19 Forensics, 3 ItemID, 36 TasteID | 7 |
| 1 | `Combat` | 1 Anatomy, 31 Archery, 42 Fencing, 17 Healing, 41 Macing, 5 Parry, 40 Swords, 27 Tactics, [57 Throwing], 43 Wrestling, [50 Focus], [51 Chivalry], [52 Bushido], [53 Ninjitsu] | 8-14 |
| 2 | `Trade Skills` | 0 Alchemy, 7 Blacksmith, 8 Fletching, 11 Carpentry, 13 Cooking, 23 Inscribe, 44 Lumberjacking, 45 Mining, 34 Tailoring, 37 Tinkering | 10 |
| 3 | `Magic` | 16 EvalInt, [56 Imbuing], 25 Magery, 46 Meditation, [55 Mysticism], 26 MagicResist, [54 Spellweaving], 32 SpiritSpeak, [49 Necromancy] | 4-9 |
| 4 | `Wilderness` | 2 AnimalLore, 35 AnimalTaming, 18 Fishing, 20 Herding, 38 Tracking, 39 Veterinary | 6 |
| 5 | `Thieving` | 14 DetectHidden, 21 Hiding, 24 Lockpicking, 30 Poisoning, 48 RemoveTrap, 28 Snooping, 33 Stealing, 47 Stealth | 8 |
| 6 | `Bard` | 15 Discordance, 29 Musicianship, 9 Peacemaking, 22 Provocation | 4 |

Bracketed ids are added only when the loaded `skills.mul` has that many entries
(`count > 49/50/51/52/53/54/55/56/57` guards at `:329,336,341,346,351,385,393,400,407`) — proof that the
client is data-driven and expects older data files that stop short of 58. `[SRC]`

#### (B) ServUO server-side skills gump — `SkillsGumpGroup`

`ServUO:Scripts/Gumps/SkillsGump.cs:421-504`. This is the list that produced the brief's
"Crafting / Bardic / Lore & Knowledge" names. Order as coded:

| # | Group (literal name) | Skills |
|---|---|---|
| 1 | `Crafting` | Alchemy, Blacksmith, Cartography, Carpentry, Cooking, Fletching, Inscribe, Tailoring, Tinkering, Imbuing |
| 2 | `Bardic` | Discordance, Musicianship, Peacemaking, Provocation |
| 3 | `Magical` | Chivalry, EvalInt, Magery, MagicResist, Meditation, Necromancy, SpiritSpeak, Ninjitsu, Bushido, Spellweaving, Mysticism |
| 4 | `Miscellaneous` | Camping, Fishing, Focus, Healing, Herding, Lockpicking, Lumberjacking, Mining, Snooping, Veterinary |
| 5 | `Combat Ratings` | Archery, Fencing, Macing, Parry, Swords, Tactics, Wrestling, Throwing |
| 6 | `Actions` | AnimalTaming, Begging, DetectHidden, Hiding, RemoveTrap, Poisoning, Stealing, Stealth, Tracking |
| 7 | `Lore & Knowledge` | Anatomy, AnimalLore, ArmsLore, Forensics, ItemID, TasteID |

Inside each group the entries are **sorted alphabetically by `SkillInfo.Name`**
(`SkillsGump.cs:512,537-551`), not by id. `[SRC]`

#### (C) Server `SkillCat` enum (used by power-scroll / alacrity / transcendence books)

`ServUO:Scripts/Skills/SkillCat.cs:5-15`: `None, Miscellaneous, Combat, TradeSkills, Magic, Wilderness,
Thievery, Bard` — same seven buckets as the client, used with real membership lists in
`PowerScrollBook.cs:55-61`, `ScrollOfAlacrityBook.cs:55-61`, `ScrollOfTranscendenceBook.cs:55-61`
(e.g. `TradeSkills` for power scrolls = **only** Blacksmith + Tailoring; `Thievery` for alacrity =
DetectHidden, Hiding, Lockpicking, Poisoning, RemoveTrap, Snooping, Stealing, Stealth). `[SRC]`

#### (D) UOGuide directory | #### (E) Jewelry skill-bonus groups

| List | Groups | Source |
|---|---|---|
| UOGuide skill directory | Combat, Magical, Bardic, Rogue, Creatures & Sensing, Crafting, Resource Gathering | [UOGuide — Skills](https://www.uoguide.com/Skills) |
| Jewelry skill-bonus groups (1 skill per group per item) | G1 Fencing, Mace Fighting, Swordsmanship, Musicianship, Magery · G2 Wrestling, Animal Taming, Spirit Speak, Tactics, Provocation · G3 Focus, Parrying, Stealth, Meditation, Animal Lore, Discordance · G4 Mysticism, Bushido, Necromancy, Veterinary, Stealing, Anatomy, Evaluating Intelligence · G5 Peacemaking, Throwing, Ninjitsu, Chivalry, Archery, Resisting Spells, Healing | [UOGuide — Skill Groups](https://www.uoguide.com/Skill_Groups) (= redirect to Skill Bonuses) |

Note: `uoguide.com/Skill_Groups` is **not** the client window grouping — it is the jewelry
bonus-group rule. That is the most likely origin of the "skill group" confusion in a clone spec.

### 1.3 The 58 skills — identity, stats, activation, trigger, check type

Column meanings:
`Pri/Sec` = `StatCode primary, secondary` from `SkillInfo` (`ServUO:Server/Skills.cs:596-653`; the
ctor itself is at `:525-559` and its arg order is `strGain, dexGain, intGain, gainFactor, primary, secondary`).
`Gain wts` = `StrGain/DexGain/IntGain` (stored, unused by `TryStatGain`).
`Act` = **A**ctive = has `SkillInfo.Table[id].Callback` (skill button works); **P** = passive/indirect
(no callback → server answers cliloc `500014` "That skill cannot be used directly"
`ServUO:Server/Skills.cs:927`). The 23 callbacks are enumerated in §1.4.
`Check` = the specific server-side check type (`CheckSkill` = location-keyed anti-macro,
`CheckTargetSkill` = target-keyed) and the literal window found in source.

| id | Server name (`SkillInfo.Name`) | Client name (`skills.mul`) | Client group | Pri | Sec | Gain wts S/D/I | GF | Act | Trigger | Check (type · window · site) |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Alchemy | Alchemy | Trade Skills | Int | Dex | 0/0.5/0.5 | 1.0 | P | mortar & pestle → craft gump | craft system `DefAlchemy` (§4d) |
| 1 | Anatomy | Anatomy | Combat | Int | Str | 0.15/0.15/0.7 | 1.0 | A | skill button → target mobile | `CheckTargetSkill(Anatomy, targ, 0, 100)` `Scripts/Skills/Anatomy.cs:74` |
| 2 | Animal Lore | AnimalLore | Wilderness | Int | Str | 0/0/1.0 | 1.0 | A | skill button → target creature | `CheckTargetSkill(AnimalLore, c, 0.0, 120.0)` `AnimalLore.cs:34,52` |
| 3 | Item Identification | ItemID | Miscellaneous | Int | Dex | 0/0/1.0 | 1.0 | A | skill button → target item | `CheckTargetSkill(ItemID, o, 0, 100)` `ItemIdentification.cs:45,147` |
| 4 | Arms Lore | ArmsLore | Miscellaneous | Int | Str | 0.75/0.15/0.1 | 1.0 | A | skill button → target weapon/armor/clothing | `CheckTargetSkill(ArmsLore, t, 0, 100)` `ArmsLore.cs:38,99,144`; `BaseArmor.cs:3198`, `BaseWeapon.cs:6373`, `BaseClothing.cs:1964` |
| 5 | Parrying | Parrying | Combat | Dex | Str | 0.75/0.25/0 | 1.0 | P | automatic when a shield/weapon is equipped | `CheckSkill(Parry, chance)` `BaseWeapon.cs:1800,1852`; `BaseShield.cs:159` (§2b) |
| 6 | Begging | Begging | Miscellaneous | Dex | Int | 0/0/0 | 1.0 | A | skill button → target NPC | `CheckTargetSkill(Begging, m_Target, 0.0, 100.0)` `Begging.cs:131` |
| 7 | Blacksmithy | Blacksmith | Trade Skills | Str | Dex | 1.0/0/0 | 1.0 | P | hammer/tongs + forge/anvil → craft gump | craft system `DefBlacksmithy` (§4b) |
| 8 | Bowcraft/Fletching | Bowcraft | Trade Skills | Dex | Str | 0.6/1.6/0 | 1.0 | P | fletcher's tools → craft gump | craft system `DefBowFletching` (§4c) |
| 9 | Peacemaking | Peacemaking | Bard | Int | Dex | 0/0/0 | 1.0 | A | skill button → area, or instrument | `CheckSkill(Peacemaking, 0.0, 120.0)` `:92`; `CheckTargetSkill(…, diff-25, diff+25)` `:187` (§6) |
| 10 | Camping | Camping | Miscellaneous | Dex | Int | 2.0/1.5/1.5 | 1.0 | P | double-click kindling | `CheckSkill(Camping, 0.0, 100.0)` `Scripts/Items/Consumables/Kindling.cs:64` |
| 11 | Carpentry | Carpentry | Trade Skills | Str | Dex | 2.0/0.5/0 | 1.0 | P | saw + boards → craft gump | craft system `DefCarpentry` (§4c) |
| 12 | Cartography | Cartography | Miscellaneous | Int | Dex | 0/0.75/0.75 | 1.0 | P | mapmaker's pen → craft gump; also map decoding | craft system `DefCartography` (§4d); decode `TreasureMap.cs:947,955` |
| 13 | Cooking | Cooking | Trade Skills | Int | Dex | 0/2.0/3.0 | 1.0 | P | skillet/flour sifter → craft gump; raw food on fire | craft system `DefCooking` (§4d); `CookableFood.cs:192` `CheckSkill(Cooking, level, 100)` |
| 14 | Detecting Hidden | DetectHidden | Thieving | Int | Dex | 0/0.4/0.6 | 1.0 | A | skill button (radius) | `CheckSkill(DetectHidden, 0.0, 100.0)` `DetectHidden.cs:67`; trapped items `CheckTargetSkill(…, 50/80, 100)` |
| 15 | Discordance | **Enticement** (client enum) | Bard | Dex | Int | 0/0.25/0.25 | 1.0 | A | skill button → target creature (instrument in hand) | `CheckTargetSkill(Discordance, target, diff-25, diff+25)` `Discordance.cs:201`; passive gain `:293` [ERA: renamed Publish 16] |
| 16 | Evaluating Intelligence | EvaluateIntelligence | Magic | Int | Str | 0/0/1.0 | 1.0 | A | skill button → target | `CheckTargetSkill(EvalInt, targ, 0.0, 120.0)` `EvalInt.cs:74` |
| 17 | Healing | Healing | Combat | Int | Dex | 0.6/0.6/0.8 | 1.0 | P | double-click bandage → target | `Bandage.cs` (§2); NPC AI `CheckSkill(Healing, 0.0, 60.0 + poison*10)` `BaseCreature.cs:6890` |
| 18 | Fishing | Fishing | Wilderness | Dex | Str | 0.5/0.5/0 | 1.0 | P | fishing pole → water | harvest system `Scripts/Services/Harvest/Fishing.cs:58`; `LobsterTrap.cs:250` |
| 19 | Forensic Evaluation | ForensicEvaluation | Miscellaneous | Int | Dex | 0/0.2/0.8 | 1.0 | A | skill button → corpse/item | `CheckTargetSkill(Forensics, target, minSkill, 55.0)` `ForensicEval.cs:52`; also `36/100`, `41/100` `:94,116,155` |
| 20 | Herding | Herding | Wilderness | Int | Dex | 1.625/0.625/0.25 | 1.0 | P | shepherd's crook → creature, then target tile | `CheckTargetSkill(Herding, m_Creature, min, max)` `ShepherdsCrook.cs:235` |
| 21 | Hiding | Hiding | Thieving | Dex | Int | 0/0.8/0.2 | 1.0 | A | skill button | `CheckSkill(Hiding, 0.0 - bonus, 100.0 - bonus)` `Hiding.cs:96` (§5) |
| 22 | Provocation | Provocation | Bard | Int | Dex | 0/0.45/0.05 | 1.0 | A | skill button → creature, then second creature | `CheckTargetSkill(Provocation, target, diff-25, diff+25)` `Provocation.cs:155` (§6) |
| 23 | Inscription | Inscription | Trade Skills | Int | Dex | 0/0.2/0.8 | 1.0 | A | skill button (copy book) / scribe's pen (craft) | `CheckTargetSkill(Inscribe, bookDst, 0, 50)` `Inscribe.cs:145`; craft system `DefInscription` (§4d) |
| 24 | Lockpicking | Lockpicking | Thieving | Dex | Int | 0/2.0/0 | 1.0 | P | lockpick → locked container/door | `CheckTargetSkill(Lockpicking, lockpickable, minLevel, maxlevel)` `LockPick.cs:142`; `QuestItems.cs:393` |
| 25 | Magery | Magery | Magic | Int | Str | 0/0/1.5 | 1.0 | P | spellbook cast (per-spell skill gate) | per-spell `GetCastSkills` gate + fizzle band (§2b) |
| 26 | Resisting Spells | ResistingSpells | Magic | Str | Dex | 0.25/0.25/0.5 | 1.0 | P | automatic when targeted by a spell | `CheckResisted` (§2b); gain sites `MagerySpell.cs:71`, `SpellHelper.cs:467`, `FireField.cs:222` |
| 27 | Tactics | Tactics | Combat | Str | Dex | 0/0/0 | 1.0 | P | automatic on every swing | damage multiplier (§2b); gain `BaseWeapon.cs:3772,3829` |
| 28 | Snooping | Snooping | Thieving | Dex | Int | 0/2.5/0 | 1.0 | P | double-click another mobile's container | `CheckTargetSkill(Snooping, cont, 0.0, 100.0)` `Snooping.cs:79` (§5) |
| 29 | Musicianship | Musicanship (sic) | Bard | Dex | Int | 0/0.8/0.2 | 1.0 | P | instrument in hand, any bard skill attempt | `CheckSkill(Musicianship, 0.0, 120.0)` `BaseInstrument.cs:710`; `FireHorn.cs:55` (§6) |
| 30 | Poisoning | Poisoning | Thieving | Int | Dex | 0/0.4/1.6 | 1.0 | A | skill button → poison potion → target item/food | `CheckTargetSkill(Poisoning, m_Target, m_MinSkill, m_MaxSkill)` `Poisoning.cs:116` (§2) |
| 31 | Archery | Archery | Combat | Dex | Str | 0.25/0.75/0 | 1.0 | P | bow/crossbow equipped + attack | combat (§2b) [ERA: gargoyle-restricted gain, `SkillCheck.cs:339`] |
| 32 | Spirit Speak | SpiritSpeak | Magic | Int | Str | 0/0/1.0 | 1.0 | A | skill button | `CheckSkill(SpiritSpeak, 0, 100)` `:40`; `CheckSkill(…, 0.0, 120.0)` `:209` (§2) |
| 33 | Stealing | Stealing | Thieving | Dex | Int | 0/1.0/0 | 1.0 | A | skill button → item (in a container) | `CheckTargetSkill(Stealing, toSteal, pileWeight-22.5, pileWeight+27.5)` `Stealing.cs:343` (§5) |
| 34 | Tailoring | Tailoring | Trade Skills | Dex | Int | 0.38/1.63/0.5 | 1.0 | P | sewing kit + cloth/leather → craft gump | craft system `DefTailoring` (§4b) |
| 35 | Animal Taming | AnimalTaming | Wilderness | Str | Int | 1.4/0.2/0.4 | 1.0 | A | skill button → creature | `CheckTargetSkill(AnimalTaming, c, minSkill-25, minSkill+25)` `AnimalTaming.cs:413` (§2) |
| 36 | Taste Identification | TasteIdentification | Miscellaneous | Int | Str | 0.2/0/0.8 | 1.0 | A | skill button → food/potion | `CheckTargetSkill(TasteID, food, 0, 100)` `TasteID.cs:43` |
| 37 | Tinkering | Tinkering | Trade Skills | Dex | Int | 0.5/0.2/0.3 | 1.0 | P | tinker's tools → craft gump | craft system `DefTinkering` (§4c); also key-making `Key.cs:510`, `LockableContainer.cs:473` |
| 38 | Tracking | Tracking | Wilderness | Int | Dex | 0/1.25/1.25 | 1.0 | A | skill button → tracking gump | `CheckSkill(Tracking, 0.0, 21.1)` `:87`; passive `CheckSkill(Tracking, 21.1, 100.0)` `:189` |
| 39 | Veterinary | Veterinary | Wilderness | Int | Dex | 0.8/0.4/0.8 | 1.0 | P | double-click bandage → animal | `Bandage.cs:246-263` (§2) |
| 40 | Swordsmanship | Swordsmanship | Combat | Str | Dex | 0.75/0.25/0 | 1.0 | P | sword-class weapon + attack | combat (§2b) |
| 41 | Mace Fighting | MaceFighting | Combat | Str | Dex | 0.9/0.1/0 | 1.0 | P | mace-class weapon + attack | combat (§2b) |
| 42 | Fencing | Fencing | Combat | Dex | Str | 0.45/0.55/0 | 1.0 | P | fencing-class weapon + attack | combat (§2b) |
| 43 | Wrestling | Wrestling | Combat | Str | Dex | 0.9/0.1/0 | 1.0 | P | unarmed / no weapon skill match | combat (§2b) |
| 44 | Lumberjacking | Lumberjacking | Trade Skills | Str | Dex | 2.0/0/0 | 1.0 | P | axe/hatchet → tree | harvest `Scripts/Services/Harvest/Lumberjacking.cs:54`; passive gain `BaseWeapon.cs:3779,3836` |
| 45 | Mining | Mining | Trade Skills | Str | Dex | 2.0/0/0 | 1.0 | P | pickaxe/shovel → cave floor | harvest `Scripts/Services/Harvest/Mining.cs:49,143`; ore smelt `Ore.cs:370` |
| 46 | Meditation | Meditation | Magic | Int | Str | 0/0/0 | 1.0 | A | skill button (must be still) | `CheckSkill(Meditation, 0.0, 100.0)` `Meditation.cs:86` (§2b) |
| 47 | Stealth | Stealth | Thieving | Dex | Int | 0/0/0 | 1.0 | A | skill button while hidden (or auto-move) | `CheckSkill(Stealth, -20.0 + AR*2, (AoS ? 60 : 80) + AR*2)` `Stealth.cs:104` (§5) |
| 48 | Remove Trap | **Disarm** (client enum) | Thieving | Dex | Int | 0/0/0 | 1.0 | A | skill button → trapped item/chest | `CheckTargetSkill(RemoveTrap, targ, TrapPower, TrapPower+10)` `RemoveTrap.cs:111`; `80,100` `:148`; `80, 120+level*10` `:366` |
| 49 | Necromancy | Necromancy | Magic | Int | Str | 0/0/0 | 1.0 | P | necromancer spellbook cast | spell code [ERA: AoS] |
| 50 | Focus | Focus | Combat | Dex | Int | 0/0/0 | 1.0 | P | automatic (regen/parry synergy) | regen formulas (§2b) [ERA: AoS] |
| 51 | Chivalry | Chivalry | Combat | Str | Int | 0/0/0 | 1.0 | P | paladin spellbook cast | spell code [ERA: AoS] |
| 52 | Bushido | Bushido | Combat | Str | Int | 0/0/0 | 1.0 | P | bushido spellbook cast | spell code [ERA: SE] |
| 53 | Ninjitsu | Ninjitsu | Combat | Dex | Int | 0/0/0 | 1.0 | P | ninjitsu spellbook cast | e.g. `CheckSkill(Ninjitsu, ReqSkill, ReqSkill+37.5)` `AnimalForm.cs:216` [ERA: SE] |
| 54 | Spellweaving | Spellweaving | Magic | Int | Str | 0/0/0 | 1.0 | P | arcane circle / spellbook | spell code [ERA: ML] |
| 55 | Mysticism | Mysticism | Magic | Str | Int | 0/0/0 | 1.0 | P | mystic spellbook cast | spell code [ERA: SA] |
| 56 | Imbuing | Imbuing | Magic | Int | Str | 0/0/0 | 1.0 | A | skill button (imbuing gump, soul forge) | `CheckSkill(Imbuing, 90.1, 120.0)` / `45..95` / `0..45` `Imbuing.cs:782,788,808,814,823` [ERA: SA] |
| 57 | Throwing | Throwing | Combat | Dex | Str | 0/0/0 | 1.0 | P | throwing weapon + attack | combat (§2b) [ERA: SA, gargoyles only: gain blocked for non-gargoyles `SkillCheck.cs:342`] |

> Client-name note: the names in the `Client name` column are ClassicUO's `SkillEntry.HardCodedName`
> enum (`ClassicUO:src/ClassicUO.Assets/SkillsLoader.cs:90-150`) — the enum preserves the *original*
> client spellings, including the two real renames (`Enticement`→Discordance, `Disarm`→Remove Trap)
> and the client's own typo `Musicanship`. The 16 genuine server/client name differences are tabulated
> in §1b.

### 1.4 The 23 directly-invocable skills (the `Callback` set) and the rest

Server: `Skills.UseSkill` refuses with cliloc `500014` when `info.Callback == null`
(`ServUO:Server/Skills.cs:910-927`), and enforces the cooldown `from.NextSkillTime` (cliloc `500118`)
plus `UseWhileCasting`. Registrations found in source:

| Skill (id) | Registration site | Notes |
|---|---|---|
| Anatomy (1) | `Scripts/Skills/Anatomy.cs:12` | |
| Animal Lore (2) | `AnimalLore.cs:12` | |
| Item ID (3) | `ItemIdentification.cs:14` | |
| Arms Lore (4) | `ArmsLore.cs:13` | |
| Begging (6) | `Begging.cs:16` | |
| Peacemaking (9) | `Peacemaking.cs:16` | |
| Detect Hidden (14) | `DetectHidden.cs:32` | |
| Discordance (15) | `Discordance.cs:40` | |
| Eval Int (16) | `EvalInt.cs:12` | registered by literal id `Table[16]` |
| Forensics (19) | `ForensicEval.cs:19` | |
| Hiding (21) | `Hiding.cs:23` | registered by literal id `Table[21]` |
| Provocation (22) | `Provocation.cs:17` | |
| Inscription (23) | `Inscribe.cs:13` | skill-button use = copy a spellbook/scroll |
| Poisoning (30) | `Poisoning.cs:11` | |
| Spirit Speak (32) | `SpiritSpeak.cs:17` | registered by literal id `Table[32]` |
| Stealing (33) | `Stealing.cs:25` | registered by literal id `Table[33]` |
| Animal Taming (35) | `AnimalTaming.cs:31` | |
| Taste ID (36) | `TasteID.cs:12` | |
| Tracking (38) | `Tracking.cs:17` | |
| Meditation (46) | `Meditation.cs:10` | registered by literal id `Table[46]` |
| Stealth (47) | `Stealth.cs:40` | |
| Remove Trap (48) | `RemoveTrap.cs:24` | |
| Imbuing (56) | `Scripts/Services/LootGeneration/Imbuing/Core/Imbuing.cs:22` | `[ERA]` SA |

Everything else is reached **through the world**, which is exactly what the client's `hasAction` byte
says (`skills.mul` byte 0 per entry, `ClassicUO:Assets/SkillsLoader.cs:47`):
craft skills → tool double-click; Magery/necromancy/chivalry/bushido/ninjitsu/spellweaving/mysticism →
spellbooks; Musicianship → instrument; Healing/Veterinary → bandage; Camping → kindling;
Lockpicking → lockpick; Mining/Lumberjacking/Fishing → harvest tools; Snooping → container;
combat skills → swinging; Parry/Tactics/Resist/Focus → automatic. `[SRC]`

### 1.5 Per-skill mechanics, interactions and check formula (dossier)

One block per skill. `Check` cites the exact site; `Interacts` lists real code-level couplings;
`§` points at the section that carries the full formula/table.

| Skill | Mechanically does | Interacts with | Check formula / type | § |
|---|---|---|---|---|
| Alchemy | Crafts potions; alchemy skill scales potion strength/duration (`BasePotion.cs:236` `Alchemy.Fixed/330*10`) | Taste ID (identify), Poisoning (poison potions), Inscription? no | craft success ramp + exceptional (§4) | 4, 4d |
| Anatomy | Reveals target's stats/HP band; adds to **damage** and to **healing**; gates bandage cure/res | Healing, Veterinary, weapon damage, Wrestling | target check `0..100`; damage bonus formula | 2, 2b |
| Animal Lore | Loyalty/stat gump for pets; needed with Taming to control | Animal Taming, Veterinary, pet training | `0..120` target check; readability gates by skill | 2 |
| Item Identification | Identifies unknown items, item ID/price knowledge | Arms Lore, Taste ID, Inscription (scroll ID) | `0..100` target check | 2 |
| Arms Lore | Reads weapon/armor damage + durability; Exceptional-craft identification | Blacksmithy/Tailoring (crafted items), Item ID | `0..100` target check (3 call sites) | 2 |
| Parrying | Chance to block with shield (or weapon parry) | weapon skill, Bushido, Meditation? no | `CheckSkill(Parry, chance)` in combat | 2b |
| Begging | Begs gold/items from NPCs; karma-dependent | Karma, NPC karma | `0..100` target check, 10-14 gp cap | 2 |
| Blacksmithy | Smelts ore, crafts metal items, repairs, enhances | Mining, Tinkering (tools), Arms Lore, Carpentry (some items) | craft ramp, ECA `ChanceMinusSixtyToFourtyFive` | 4, 4b |
| Bowcraft/Fletching | Boards→shafts→bows/arrows/bolts | Carpentry (boards), Lumberjacking, Archery | craft ramp | 4, 4c |
| Peacemaking | Area/target pacify of creatures | Musicianship, Discordance/Provocation (same instrument), Barding Difficulty | `0..120` area check + `diff±25` targeted | 6 |
| Camping | Kindling → campfire (secure logout), bedroll | Hiding? no; logout rules | `0..100` check at kindling | 2 |
| Carpentry | Wood items, furniture, instruments, containers, ship deeds | Lumberjacking, Tinkering, Musicianship (instruments), Bowcraft | craft ramp | 4, 4c |
| Cartography | Blank map → world/treasure maps; decodes treasure maps | Mining (digging), Lockpicking (chest), Treasure maps | craft ramp; decode `CheckSkill(Cartography, minSkill-10, minSkill+30)` `TreasureMap.cs:955` | 4d |
| Cooking | Raw→cooked food, flour, dough; burn chance | Fishing, Camping (fire), Taste ID | `CheckSkill(Cooking, CookingLevel, 100)` `CookableFood.cs:192` | 4d |
| Detect Hidden | Reveals hidden mobs in a radius; passive detection; finds trapped items | Hiding, Stealth, Remove Trap, Tracking | active `0..100`; passive `Random(1000)` roll | 2, 5 |
| Discordance | Debuffs a creature's skills/resistances for a duration | Musicianship, Barding Difficulty, instrument slayer type | `diff±25` target check | 6 |
| Eval Int | Reads target's INT/mana; scales **spell damage** | Magery, spell damage, Inscription bonus | `0..120` target check | 2b |
| Healing | Bandage heal/cure/res; timer from Dex; Anatomy synergy | Anatomy, Veterinary, Dexterity, Enhanced Bandage | healing/cure/res gates + heal formulas | 2 |
| Fishing | Catches fish/items by water; special nets/traps | Cooking, High Seas content | harvest `HarvestDefinition` skill/min/max, +1 with Tokuno galleon | 2 |
| Forensic Evaluation | Murder counts, killer identity, thief-guild info on corpses | Detect Hidden, Stealing (thief guild), karma | `minSkill..55`, `36..100`, `41..100` variants | 2, 5 |
| Herding | Moves a creature one tile per success with a crook | Animal Taming, Animal Lore | `CheckTargetSkill(Herding, creature, min, max)` | 2 |
| Hiding | Sets `Hidden`; enables stealth/steal bonus/peace | Stealth, Detect Hidden, Stealing, Snooping, Tracking | `(0-bonus)..(100-bonus)`; watcher range formula | 5 |
| Provocation | Makes two creatures fight | Musicianship, Discordance, Peacemaking, Barding Difficulty | `diff±25` target check, 30 s flat timer | 6 |
| Inscription | Writes scrolls/spellbooks; +spell damage at 100+ | Magery, spell circles, Eval Int, Meditation? | `0..50` book-copy check; per-circle scribe gates | 4d, 2b |
| Lockpicking | Opens locked containers/doors; deciphers some traps | Remove Trap, Tinkering (lockpicks), Detect Hidden | `CheckTargetSkill(Lockpicking, item, minLevel, maxlevel)` | 2 |
| Magery | Casts spells 1-8th circle; gates circle by skill | Eval Int (damage), Inscription, Meditation (mana), Resisting Spells, Parry? no | per-spell `GetCastSkills` band + fizzle formula | 2b |
| Resisting Spells | Reduces incoming spell damage/effects | Magery, Eval Int, Protection, cursed effects | `CheckResisted` resist % per circle | 2b |
| Tactics | Damage multiplier on every hit | weapon skill, Anatomy, Lumberjacking | damage formula | 2b |
| Snooping | Opens another's container unseen | Stealing, Hiding, Detect Hidden, karma/criminal | `0..100` target check; victim notify roll | 5 |
| Musicianship | Gates and scales all three bard skills; instrument use | Provocation, Discordance, Peacemaking, instruments | `CheckSkill(Musicianship, 0.0, 120.0)` `BaseInstrument.cs:710` | 6 |
| Poisoning | Applies poison potions to weapons/food; poison level from skill | Alchemy, weapon hits, Taste ID, Detecting? | per-potion `CheckTargetSkill(Poisoning, target, min, max)`; 5 % self-poison below 80 | 2 |
| Archery | Bow/crossbow combat skill | Tactics, Anatomy, ammo, Bowcraft | combat formulas | 2b |
| Spirit Speak | Ghost interaction, trance heal, necromancy synergy | Necromancy, ghosts, mana | `0..100` / `0..120` checks | 2 |
| Stealing | Takes items from containers/mobiles | Snooping, Hiding, Stealth, Detect Hidden, flagging | weight-driven window `pileWeight-22.5 … +27.5` | 5 |
| Tailoring | Cloth/leather items, bandages from cloth, repairs | Bowcraft? no; Blacksmithy (same craft UI), Tinkering (sewing kit) | craft ramp, ECA `ChanceMinusSixtyToFourtyFive` | 4, 4b |
| Animal Taming | Tames/controls creatures; control slots and loyalty | Animal Lore, Veterinary, Herding, pet training | `minSkill-25 .. minSkill+25` target check | 2 |
| Taste Identification | Identifies potions/food, detects poison | Alchemy, Poisoning, Cooking | `0..100` target check | 2 |
| Tinkering | Tools, parts, traps, keys, mechanisms | every craft skill (tools), Remove Trap, Lockpicking | craft ramp | 4, 4c |
| Tracking | Detects players/creatures in a radius; tracking gump | Detect Hidden, Stealth (stalkers), Barding? no | active `0..21.1`, passive `21.1..100` | 2 |
| Veterinary | Bandage-heals pets | Animal Lore, Animal Taming, Healing | same bandage engine as Healing, animal branch | 2 |
| Swordsmanship | Sword-class weapons | Tactics, Parry, Anatomy, weapon specials | combat formulas | 2b |
| Mace Fighting | Mace-class weapons (stamina damage) | Tactics, Parry, Anatomy | combat formulas | 2b |
| Fencing | Fencing-class weapons (fast, low damage) | Tactics, Parry, Anatomy | combat formulas | 2b |
| Wrestling | Unarmed combat; also the fallback defence skill | Parry (weapon parry), specials (stun/disarm pre-AoS) | combat formulas | 2b |
| Lumberjacking | Harvests logs; adds a damage bonus with axes | Carpentry, Bowcraft, axe damage bonus | harvest definitions + passive gain on hit | 2, 2b |
| Mining | Harvests ore/stone/sand/gems; smelts ore into ingots | Blacksmithy, Tinkering, Glassblowing (sand), Cartography (dig) | harvest definitions (`Mining.cs:49,143`); smelt `Ore.cs:370` | 2, 4c |
| Meditation | Active mana regen; needs no armour penalty | Magery, Focus, Intelligence, armour | `0..100` check + regen formula | 2b |
| Stealth | Silent movement while hidden; steps per check | Hiding, Stealing, Snooping, armour (MageArmor) | `(-20+2·AR) … ((AoS?60:80)+2·AR)` | 5 |
| Remove Trap | Disarms trapped chests/items; failure damages | Lockpicking (50+ prereq for dungeon chests), Detect Hidden, Tinkering, Magery | `TrapPower .. TrapPower+10` etc. | 2 |
| Necromancy | Undead spells, forms, curses | Spirit Speak, Magery? no; Resisting Spells | spell gates [ERA AoS] | 2b |
| Focus | Passive stamina/mana regen and parry synergy | Meditation, Parry, weapon specials | regen formulas [ERA AoS] | 2b |
| Chivalry | Paladin spells (tithing, buffs, heals) | Karma, tithing points, Tactics | spell gates [ERA AoS] | 2b |
| Bushido | Samurai stances, parry/evasion | Parry, weapon skills | spell gates [ERA SE] | 2b |
| Ninjitsu | Ninja forms, stealth-adjacent spells | Stealth, Hiding, Animal Form | e.g. `ReqSkill..ReqSkill+37.5` [ERA SE] | 2b |
| Spellweaving | Arcane circle spells (needs others/circle) | Magery? no; arcane focus | spell gates [ERA ML] | 2b |
| Mysticism | Mystic spells (heals, curses, summons) | Focus, Imbuing? | spell gates [ERA SA] | 2b |
| Imbuing | Adds magic properties to items via soul forge | Item properties, residue/essence, Tinkering? | tiered `CheckSkill(Imbuing, 0..45/45..95/90.1..120)` [ERA SA] | 7 |
| Throwing | Gargoyle ranged combat skill | Tactics, Anatomy, gargoyle race gate | combat formulas [ERA SA] | 2b |

### 1.6 The "3 future / unused skill slots" — resolved

**Finding: there is no evidence of three named, pre-reserved slots.** The last three ids are simply the
three skills added together by Stygian Abyss; the client tolerates fewer entries than 58.

| Claim | Evidence | Verdict |
|---|---|---|
| 58 skills exist today, 1 was removed | "Ultima Online has 58 different Skills currently in game (and 1 removed)" — [UOGuide — Skills](https://www.uoguide.com/Skills); the removed one is *Enticement*, whose slot 15 became Discordance | `[SRC+WEB]` |
| Server table is dense, no placeholder rows | `SkillInfo[58]`, 58 initialised entries, none null | `[SRC] ServUO:Server/Skills.cs:588-648` |
| Client skill table is data-driven and expects short files | `SkillsLoader` counts only `skills.mul` entries with `length > 0`; `SkillsGroupManager` guards every post-classic id with `count > 49/50/…/57` | `[SRC] ClassicUO:src/ClassicUO.Assets/SkillsLoader.cs:41-55`, `…/SkillsGroupManager.cs:329-407` |
| SA added exactly three skills | Imbuing, Mysticism, Throwing — [UOGuide — Stygian Abyss](https://www.uoguide.com/Stygian_Abyss); server ids 55/56/57 | `[SRC+WEB]` |
| Were 55/56/57 *blank-but-present* in pre-SA `skills.mul`? | **No source on disk or reachable web states a reserved-slot count** | `[UNVERIFIED]` — measure by reading a pre-2009-09-08 `skills.idx` (16-byte records) and counting `length > 0` records: 55 ⇒ the "3 blank slots" story is false; 58 with blank names ⇒ they existed |

Era-correct answer for a **classic-era** clone: implement ids `0..48` (the 49 classic skills, of which
id 15 was *Enticement* until Publish 16 renamed it to Discordance), treat `49..54` as later-era
(AoS/SE/ML) and `55..57` as the three SA "future" slots that do not exist in a classic client.
Careful: id 48 was *Disarm* in the original client data and is **Remove Trap** in game terms.

---
