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

### Table of contents (generated)

- **0. How to read this document**
  - 0.1 Source checkouts (all local, all greppable, all revisions recorded)
  - 0.2 Confidence markers (applied per formula, per table, per row where it matters)
  - 0.3 Era anchors (used for every `[ERA]` note)
  - 0.4 Document map
- **1. The complete skill list**
  - 1.1 How a skill is represented (numbers a clone must fix first)
  - 1.2 There are FIVE different "skill group" lists — do not conflate them
  - 1.3 The 58 skills — identity, stats, activation, trigger, check type
  - 1.4 The 23 directly-invocable skills (the `Callback` set) and the rest
  - 1.5 Per-skill mechanics, interactions and check formula (dossier)
  - 1.6 The "3 future / unused skill slots" — resolved
- **1b. Client-side skill list, groups, gumps & wire format**
  - 0. Citation legend (tokens used in the tables below)
  - 1. Where the client's skill data comes from (load order) [SRC]
  - 2. Client skill GROUPS
  - 3. Skill ids 0..57 — master table
  - 4. Cap display
  - 5. Use-skill flow, end to end
  - 6. Skills the client cannot use directly (and the message)
  - 7. Name-mismatch diff table (server vs client)
  - 8. Open gaps (what a clone cannot copy blindly)
- **2. Skill use model (per skill)**
  - 2.0 Shared machinery (applies to every block below)
  - 2.1 Anatomy
  - 2.2 Animal Lore
  - 2.3 Arms Lore
  - 2.4 Evaluating Intelligence
  - 2.5 Item Identification
  - 2.6 Taste Identification
  - 2.7 Forensic Evaluation
  - 2.8 Tracking
  - 2.9 Begging
  - 2.10 Herding
  - 2.11 Detect Hidden
  - 2.12 Remove Trap
  - 2.13 Poisoning
  - 2.14 Meditation
  - 2.15 Spirit Speak
  - 2.16 Animal Taming
  - 2.17 Inscription (skill-use side only)
  - 2.18 Camping (kindling, campfire, bedroll, secure logout)
  - 2.19 Healing and Veterinary (bandage use model)
  - 2.20 Cross-skill interaction summary (this section only)
  - 2.21 Open items for this section
- **2b. Skill use model — combat & magery formulas**
  - 2b.0 Source index (URL prefix for every `path:LINE` below)
  - 2b.1 The one primitive every skill check goes through `[SRC]`
  - 2b.2 (1) SWING SPEED — `BaseWeapon.GetDelay` `[SRC]`
  - 2b.3 (2) TO-HIT — `BaseWeapon.CheckHit` `[SRC]`
  - 2b.4 (3) DAMAGE — base range, skill bonuses, AoS resist pipeline `[SRC]`
  - 2b.5 (4) PARRY — `BaseWeapon.CheckParry` `[SRC]`
  - 2b.6 (5) RESISTING SPELLS — resist check, damage reduction, passive gains `[SRC]`
  - 2b.7 (6) WEAPON SKILLS, Archery, Throwing, Wrestling, Tactics `[SRC]`
  - 2b.8 (7) WEAPON SPECIAL MOVES & SKILL MASTERIES `[SRC]`
  - 2b.9 (7) MAGERY — cast flow end to end `[SRC]`
  - 2b.10 (8) MEDITATION & MANA REGENERATION `[SRC]`
  - 2b.11 (9) EVALUATING INTELLIGENCE `[SRC]`
  - 2b.12 (10) ARMS LORE — output thresholds `[SRC]`
  - 2b.13 (11) SUMMARY TABLE
  - 2b.14 Discrepancies, era notes and gaps
- **3. Skill gain & stat gain**
  - 3.0 Call graph & units (read this first)
  - 3.1 `GetGainChance` decomposed term by term
  - 3.2 `chance`, the short-circuits, and how `success` feeds gain
  - 3.3 `Gain()` in full
  - 3.4 Total-cap arbitration at 700.0 (and `CheckReduceSkill`)
  - 3.5 `SkillLock`
  - 3.6 Anti-macro system
  - 3.7 GGS — Guaranteed Gain System
  - 3.8 Stat gain
  - 3.9 Full 58-row `SkillInfo.Table` (`Server/Skills.cs:594-654`)
  - 3.10 `StrScale` / `DexScale` / `IntScale` and the effective skill value
  - 3.11 Worked numeric examples of `gc` per band
  - 3.12 Every `PlayerCaps` (skill/stat-related) config key
  - 3.13 ServUO vs ModernUO — consolidated difference table
  - 3.14 Gaps / what is NOT verifiable from source
- **4. Crafting engine — core formulas**
  - 4.0 Source map
  - 4.1 How the player starts crafting — `ITool` / `BaseTool`
  - 4.2 Success chance — `GetSuccessChance` (exact)
  - 4.3 Exceptional chance, quality, maker's mark, exceptional budget
  - 4.4 Resource consumption — `CraftRes`, `CraftSubRes`, `ConsumeRes`
  - 4.5 Sub-resource selection (the "which metal/wood/leather" prompt)
  - 4.6 Tool requirement per system — `CanCraft`
  - 4.7 Per-craft delay, animation, sound, throttle
  - 4.8 Gump structure
  - 4.9 The full craft pipeline, in order
  - 4.10 "Make last" / "Make number" / "Make max" and `AutoCraftTimer`
  - 4.11 `CustomCraft`, `TryCraft`, `CreateItem` delegates
  - 4.12 Recipes (`Recipes.cs`)
  - 4.13 `Enhance.cs` — special-material enhancement
  - 4.14 `Repair.cs` — formulas
  - 4.15 `Resmelt.cs` and ore → ingot smelting
  - 4.16 `CraftItem` flags — meaning and effect
  - 4.17 Every craft system in `Scripts/Services/Craft/Def*.cs`
  - 4.18 Client-side / era notes
  - 4.19 Confidence and UNVERIFIED gaps
- **4b. Crafting menus — Blacksmithy & Tailoring**
  - 4b.0 How the columns map to the C# arguments
  - 4b.1 System header table
  - 4b.2 DefBlacksmithy — group index
  - 4b.3 DefTailoring — group index
  - 4b.4 Resource catalogue — Blacksmithy
  - 4b.5 Resource catalogue — Tailoring
  - 4b.6 Recipe-gated entries (`AddRecipe` → `CraftItem.Recipe`, requires a recipe scroll)
  - 4b.7 Era gating — every `[ERA]` line
  - 4b.8 Non-`AddCraft` menu behaviour worth porting
  - 4b.9 Divergences: ServUO `pub57` vs ModernUO `main`
  - 4b.10 Gaps / what is not verifiable from these sources
- **4c. Crafting menus — Carpentry, Tinkering, Fletching, Glassblowing**
  - 4c.0 Citation bases and call semantics
  - 4c.1 Carpentry — `DefCarpentry`
  - 4c.2 Tinkering — `DefTinkering`
  - 4c.3 Bowcraft & Fletching — `DefBowFletching`
  - 4c.4 Glassblowing + sand mining
  - 4c.5 (c) Crafted tools → which skill they unlock
  - 4c.6 ServUO vs ModernUO (divergences relevant to these four menus) `[SRC]`
  - 4c.7 Row-count summary and gaps
- **4d. Crafting menus — Alchemy, Inscription, Cooking, Cartography**
  - 4d.0 Citation key
  - 4d.1 Shared crafting machinery (applies to all five menus) `[SRC]`
  - 4d.2 ALCHEMY — `DefAlchemy.cs`, gump cliloc 1044001
  - 4d.3 INSCRIPTION — `DefInscription.cs`, gump cliloc 1044009
  - 4d.4 COOKING — `DefCooking.cs`, gump cliloc 1044003
  - 4d.5 CARTOGRAPHY — `DefCartography.cs`, gump cliloc 1044008
  - 4d.6 MASONRY (stonecrafting) — `DefMasonry.cs`, gump cliloc 1044500 `[ERA]`
  - 4d.7 Row-count reconciliation
  - 4d.8 Confidence and gaps
- **5. Hide / Stealth / Thief package**
  - 5.0 Files read end-to-end + the one shared primitive
  - 5.1 HIDING — `ServUO:Scripts/Skills/Hiding.cs`
  - 5.2 STEALTH — `ServUO:Scripts/Skills/Stealth.cs`
  - 5.3 SNOOPING — `ServUO:Scripts/Skills/Snooping.cs`
  - 5.4 STEALING — `ServUO:Scripts/Skills/Stealing.cs`
  - 5.5 FLAGGING — the criminal path, guards, colour, reveal interactions
  - 5.6 ModernUO cross-check (diffs only; identical constants listed as "same")
  - 5.7 Clone-implementation table — every number a clone must reproduce
  - 5.8 Gaps / UNVERIFIED
- **6. Bard skills**
  - 6.1 Skill identities
  - 6.2 MUSICIANSHIP
  - 6.3 Instruments — full item table
  - 6.4 Creature barding difficulty — exact computation
  - 6.5 Difficulty → required player skill (arithmetic)
  - 6.6 PROVOCATION
  - 6.7 DISCORDANCE
  - 6.8 PEACEMAKING
  - 6.9 Difficulty tiers per bard skill `[DERIVED from SRC]`
  - 6.10 Published difficulty/tier references `[WEB]`
  - 6.11 Era notes `[ERA]`
  - 6.12 ModernUO constant diffs
  - 6.13 Bard Masteries `[ERA]` — Mondain's Legacy
  - 6.14 Open items / `[UNVERIFIED]`
- **7. Era matrix & web verification**
  - 7.1 Era matrix (all 58 skill ids)
  - 7.2 The "3 future/unused skill slots" question — explicit answer
  - 7.3 Skill list cross-check (id · stats · client group · active flag)
  - 7.4 Published numbers vs ServUO code
  - 7.5 What is *not* published anywhere (measurements instead)
  - 7.6 Poison levels (published vs code)
  - 7.7 Published bard difficulty tiers
  - 7.8 The three different "skill group" lists (do not conflate)
  - 7.9 Sources that failed (and what to use instead)
  - 7.10 Confidence summary for this section
- **8. Consolidated open questions (UNVERIFIED register + measurement plan)**
  - 8.1 What is *not* in doubt (highest-confidence core, safe to implement first)

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

## 2. Skill use model (per skill)

Scope: the **non-craft, non-bard, non-thief** skills whose behaviour lives in `Scripts/Skills/*.cs`
plus the item-triggered skills Healing / Veterinary (bandage), Camping (kindling + campfire +
bedroll) and Herding (shepherd's crook). Every literal below was read out of the ServUO `pub57`
checkout at `E:\Workspaces\game-clone\.research-src\servuo`; citations are `ServUO:<path>:<line>`
with the matching GitHub URL on the block's source line. Numbers that do **not** exist in source are
marked `[PARTIAL]` / `[UNVERIFIED]` with the measurement that would resolve them.

---

### 2.0 Shared machinery (applies to every block below)

| Mechanism | Code | Constant / formula |
|---|---|---|
| Skill button → server | `ServUO:Server/Network/PacketHandlers.cs:851-862` — speech command `0x24` "Use skill" → `Skills.UseSkill(m, skillIndex)` | index = `(int)SkillName` |
| API entry | `ServUO:Server/Mobile.cs:3951` / `:3956` → `Skills.UseSkill(this, …)` | — |
| Use gate | `ServUO:Server/Skills.cs:886-932` | `CheckAlive` → `Region.OnSkillUse` → `AllowSkillUse` → `Core.TickCount - from.NextSkillTime >= 0 && (info.UseWhileCasting \|\| from.Spell == null)` (`:912`) |
| Cooldown write | `ServUO:Server/Skills.cs:916` | `from.NextSkillTime = Core.TickCount + (int)(info.Callback(from)).TotalMilliseconds` |
| Busy message | `ServUO:Server/Skills.cs:922` → `from.SendSkillMessage()`; `:927` → cliloc `500014` "That skill cannot be used directly." | — |
| No callback | `SkillInfo.Table` entries with `null` callback (Camping `Server/Skills.cs:606`, Healing `:613`, Herding `:616`, Veterinary `:635`) can never be fired from the skill button — they are item-triggered only | — |
| Window check (location) | `ServUO:Scripts/Misc/SkillCheck.cs:134-158` | `chance = (value - minSkill) / (maxSkill - minSkill)` (`:153`); `value < minSkill → false` (`:147`); `value >= maxSkill → true` (`:150`) |
| Window check (target) | `ServUO:Scripts/Misc/SkillCheck.cs:286-311` (`Mobile_SkillCheckTarget`) | same formula at `:306`; used by every `CheckTargetSkill(skill, target, min, max)` below |
| Direct-chance variant | `ServUO:Scripts/Misc/SkillCheck.cs:160-176` / `:313-329` | `chance < 0 → false`, `chance >= 1 → true`; `CheckSkill(skill, chance)` |
| Success roll | `ServUO:Scripts/Misc/SkillCheck.cs:245` | `success = Utility.Random(100) <= (int)(chance * 100)` |
| Gain roll | `ServUO:Scripts/Misc/SkillCheck.cs:261-284` | `gc = ((Cap - Total)/Cap + (skill.Cap - skill.Base)/skill.Cap)/2; gc = (gc + (1-chance)*(success ? 0.5 : AoS?0.0:0.2))/2; gc *= GainFactor; clamp 0.01..1.00; pets ×2` |
| `Skill.Value` vs `Base` | `ServUO:Server/Skills.cs:91-98` | `Value` includes item/skillmod bonuses; `Base` does not. Blocks below state which one each formula reads |
| Anti-macro gate | `ServUO:Scripts/Misc/SkillCheck.cs:59-123` + `:331` | `UseAntiMacro[]` false for Parry/Blacksmith/Fletching/Carpentry/Cartography/Cooking/Inscribe/Tactics/Archery/Tailoring/Tinkering/weapon skills/Focus/Throwing; **true** for Anatomy/AnimalLore/ItemID/ArmsLore/Begging/Peacemaking/**Camping**/DetectHidden/Discordance/EvalInt/**Healing**/Fishing/Forensics/**Herding**/Hiding/Provocation/Lockpicking/Magery/MagicResist/Snooping/Musicianship/Poisoning/SpiritSpeak/Stealing/AnimalTaming/TasteID/Tracking/**Veterinary**/Lumberjacking/Mining/Meditation/Stealth/RemoveTrap/Necromancy/Chivalry/Bushido/Ninjitsu/Spellweaving/Mysticism/Imbuing |
| GGS | `ServUO:Scripts/Misc/SkillCheck.cs:774-806` (table at `:798`) | `GGSTable[skill.Base/5][Total>=7000?2:Total>=3500?1:0]` minutes; disabled on Siege (`:40`) |
| `Utility.Random(from, count)` | `ServUO:Server/Utility.cs:905-919` | returns `from + [0, count-1]` — **count is exclusive**, relevant for the taming tick count and the "unreachable" begging branches |
| `Utility.RandomMinMax(min, max)` | `ServUO:Server/Utility.cs:889-903` | inclusive both ends |
| Skill button delays | see table below | `[SRC]` |

| Skill | Slot | Callback (file:line) | Delay returned to `NextSkillTime` |
|---|---|---|---|
| Anatomy | 1 | `Scripts/Skills/Anatomy.cs:15` | 1.0 s (`:21`) |
| Animal Lore | 2 | `Scripts/Skills/AnimalLore.cs:15` | 1.0 s (`:27`) |
| Item Identification | 3 | `Scripts/Skills/ItemIdentification.cs:17` | 1.0 s (`:22`) |
| Arms Lore | 4 | `Scripts/Skills/ArmsLore.cs:16` | 1.0 s (`:22`) |
| Begging | 6 | `Scripts/Skills/Begging.cs:19` | 1 hour (`:27`); reset to "now" on target finish (`:42`), +10 s after a completed attempt (`:331`) |
| Camping | 10 | none (`Server/Skills.cs:606`) | n/a — item only |
| Detect Hidden | 14 | `Scripts/Skills/DetectHidden.cs:35` | 10.0 s (`:40`) |
| Evaluating Intelligence | 16 | `Scripts/Skills/EvalInt.cs:15` | 1.0 s (`:21`) |
| Healing | 17 | none — `Scripts/Items/Resource/Bandage.cs:73` | n/a — item only |
| Forensic Evaluation | 19 | `Scripts/Skills/ForensicEval.cs:22` | 1.0 s (`:29`) |
| Herding | 20 | none — `Scripts/Items/Equipment/Weapons/ShepherdsCrook.cs:130` | n/a — item only |
| Inscription | 23 | `Scripts/Skills/Inscribe.cs:16` | 1.0 s (`:23`) |
| Poisoning | 30 | `Scripts/Skills/Poisoning.cs:14` | 10.0 s (`:20`) |
| Spirit Speak | 32 | `Scripts/Skills/SpiritSpeak.cs:22` | AoS: 5.0 s (`:32`), pre-AoS: 1.0 s (`:66`), AoS while casting: 0 (`:35`) |
| Animal Taming | 35 | `Scripts/Skills/AnimalTaming.cs:34` | 40.0 s (`:53`) |
| Taste Identification | 36 | `Scripts/Skills/TasteID.cs:15` | 1.0 s (`:21`) |
| Tracking | 38 | `Scripts/Skills/Tracking.cs:20` | 10.0 s (`:28`) |
| Veterinary | 39 | none — bandage | n/a — item only |
| Meditation | 46 | `Scripts/Skills/Meditation.cs:30` | 10.0 s (`:102`); 5.0 s busy/low-HP (`:38`,`:44`); pre-AoS full mana 5.0 s (`:50`); 2.5 s hands-full (`:75`) |
| Remove Trap | 48 | `Scripts/Skills/RemoveTrap.cs:27` | 10.0 s (`:44`) |

`[SRC]` for the whole table. Note the asymmetry: `NextSkillTime` is only written when the callback
returns through `Skills.UseSkill`; handlers that return early (e.g. `Meditation` busy branch) still
consume the delay. Handlers that set `m_SetSkillTime = false` (Animal Taming `:240`, Begging `:89`)
suppress the `OnTargetFinish` reset so the *long* delay stays.

---

### 2.1 Anatomy

Source: `ServUO:Scripts/Skills/Anatomy.cs` (93 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Anatomy.cs

| Field | Value |
|---|---|
| Trigger | Skill button (callback `Anatomy.cs:12`), then 1.0 s cooldown |
| Target requirements | `Target(8, false, TargetFlags.None)` — 8 tiles, ground not allowed (`:27`) |
| Skill check window | `from.CheckTargetSkill(SkillName.Anatomy, targ, 0, 100)` (`:74`) — 0 %–100 % of the window, so chance = `Anatomy.Value / 100` |
| Delay / cooldown | 1.0 s (`:21`) |
| Success outcome | `PrivateOverheadMessage(0x3B2, 1038045 + (strMod * 11) + dexMod)` (`:76`); if `Anatomy.Base >= 65.0` a second line `1038303 + stmMod` (`:79`) |
| Failure outcome | cliloc `1042666` "You can not quite get a sense of their physical characteristics." (`:83`) — **no information at all**, not a fuzzy value |
| Resource consumed | none |
| Messages / gumps | `500321` "Whom shall I examine?" (`:19`); self `500324` (`:35`); TownCrier `500322` (`:39`); invulnerable vendor `500326` (`:43`); item `500323` "Only living things have anatomies!" (`:88`) |
| Interactions | passive Anatomy gain on every melee swing (`Scripts/Items/Equipment/Weapons/BaseWeapon.cs:3831` pre-AoS, `:3775` AoS-classic path); Achery/… weapon damage bonus; pre-AoS 2-handed special blow; Cu Sidhe lore gump shows creature Anatomy |
| [ERA] | `1038045`/`1038303`/`1042666` set is the AoS-era "physical characteristics" text set; pre-AoS Clients read the older "You see…" line. ServUO does not branch on era here |
| Confidence | `[SRC]` for all numbers; exact cliloc **strings** for the 1038xxx/1042666 range are `[PARTIAL]` (they live in `cliloc.enu`, not in C#) |

**Anatomy damage bonus (physical characteristics of the attacker)**

| Era | Formula | Citation |
|---|---|---|
| AoS/ML+ (`ScaleDamageAOS`) | `anatomyBonus = GetBonus(Anatomy.Value, 0.500, 100.0, 5.00)` where `GetBonus = (value*scalar + (value>=threshold ? offset : 0)) / 100` ⇒ **+0.5 % per point, +5 % extra at exactly ≥100.0** (max +55 % at 100; uncapped above 100 because no clamp) | `BaseWeapon.cs:3789` + `:3663-3673` |
| Total AoS bonus | `totalBonus = strengthBonus + anatomyBonus + tacticsBonus + lumberBonus + ((GetDamageBonus()+damageBonus)/100)`; `damage += (int)(damage * totalBonus)` | `BaseWeapon.cs:3812-3815` |
| Pre-AoS (`ScaleDamageOld`) | `modifiers += ((Anatomy.Value / 5.0) / 100.0)` ⇒ **+1 % per 5.0 points (0.2 %/pt)**; `if (anatomyValue >= 100.0) modifiers += 0.1` ⇒ **+10 % at GM** | `BaseWeapon.cs:3856-3862` |
| Pre-AoS 2-handed special blow | `Anatomy.Value / 400.0 >= Utility.RandomDouble()` ⇒ 25 % at 100 Anatomy (Bashing `BaseBashing.cs:78`, Axe `:147`, PoleArm `:123`, Spear `:70`) — applied only when `!Core.AOS` | as cited |
| Wrestling special (pre-AoS) | `attacker.Skills[Anatomy].Value >= 80.0 && attacker.Skills[Wrestling].Value >= 80.0` | `Scripts/Items/Equipment/Weapons/Fists.cs:168` |
| Confidence | `[SRC]` | |

**"You see" output index map** — the gump text is chosen purely by the cliloc offset, never by prose
in the C# file, so the *thresholds* are the two clamps below:

| Index | Computation | Range |
|---|---|---|
| `marginOfError` | `Math.Max(0, 25 - (int)(from.Skills[Anatomy].Value / 4))` | 25 at 0 skill → 0 at ≥100 skill (`Anatomy.cs:49`) |
| `str` / `dex` | `targ.Str / Dex + RandomMinMax(-margin, +margin)` | raw stat ±error (`:51-52`) |
| `stm` | `((targ.Stam * 100) / Math.Max(targ.StamMax, 1)) + RandomMinMax(-margin, +margin)` | stamina **as a percentage**, clamped 0..10 after `/10` (`:53`,`:69-72`) |
| `strMod` / `dexMod` / `stmMod` | `value / 10`, clamped to `0..10` | 11 bands each (`:55-72`) |
| Success line | `1038045 + (strMod * 11) + dexMod` | 121 consecutive clilocs `1038045`–`1038165` |
| Stamina line (only `Base >= 65.0`) | `1038303 + stmMod` | 11 clilocs `1038303`–`1038313` |

`[PARTIAL]`: the 132 English strings for `1038045+` and the 11 strings for `1038303+` are not in
source. To reproduce them exactly, read `cliloc.enu` entries `1038045`–`1038165` and
`1038303`–`1038313` from the client files (measurement: dump those ids from a UO installation or
from `ClassicUO`'s cliloc loader).

---

### 2.2 Animal Lore

Source: `ServUO:Scripts/Skills/AnimalLore.cs` (428 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/AnimalLore.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`AnimalLore.cs:12`); if the ToL pet-training gump is already open → `500118` "You must wait a few moments to use another skill." (`:19`) instead of a target |
| Target requirements | `Target(8, false, TargetFlags.None)` (`:59`), must be a live `BaseCreature` whose `Body.IsAnimal \|\| IsMonster \|\| IsSea` (`:75`); dead pets and ghosts refused |
| Skill check window | Two-stage. Gate check in `Check()`: `CheckTargetSkill(AnimalLore, c, min, 120.0)` where `min` = **80.0** for tameable wild or (skill ≥110) non-tameable, **100.0** for non-tameable at skill ≥110 (`:90`,`:99`,`:101`). Gump display re-rolls `CheckTargetSkill(AnimalLore, c, 0.0, 120.0)` purely for **gain** (`:34`) |
| Delay / cooldown | 1.0 s (`:27`) |
| Success outcome | `AnimalLoreGump(c)` (`:46`) — or `NewAnimalLoreGump` when `PetTrainingHelper.Enabled` (`:40`) |
| Failure outcome | cliloc `500334` "You can't think of anything you know offhand." (`:55`) |
| Resource consumed | none |
| Messages / gumps | `500328` "What animal should I look at?" (`:24`); `500331` dead/ghost (`:67`,`:111`); `500329` "That's not an animal!" (`:106`,`:116`); `1049674` "At your skill level, you can only lore tamed creatures."; `1049675` "…tamed or tameable creatures." |
| Interactions | Animal Taming passively rolls `CheckTargetSkill(AnimalLore, creature, 0.0, 120.0)` on every taming tick (`AnimalTaming.cs:378`,`:399`); Animal Lore is the **secondary skill** for veterinary bandaging (`Bandage.cs:268`) and feeds the pet control chance (`BaseCreature.cs:1534`); the gump prints the creature's Barding Difficulty used by the bard skills |
| [ERA] | Gump has **5 pages when `Core.AOS`, else 3** (`:197`); Loyalty Rating is on page 1 for AoS (`:241-244`) and on the last page pre-AoS (`:415-421`); Barding Difficulty row only `Core.SE` (`:228-238`); Base Damage row only `Core.ML` (`:311-315`); Cu Sidhe shows Healing instead of Poisoning (`:342-351`) |
| Confidence | `[SRC]` |

**Skill → readability gate**

| `AnimalLore.Value` | Controlled creature | Wild + `Tamable` | Wild + not tameable |
|---|---|---|---|
| `< 100.0` | gump | `1049674` "At your skill level, you can only lore tamed creatures." | same |
| `100.0 – 109.9` | gump | `Check(80.0)` | `1049675` "…only lore tamed or tameable creatures." |
| `>= 110.0` | gump | `Check(80.0)` | `Check(100.0)` |

`[SRC]` — `AnimalLore.cs:77-102`.

**Gump contents (`AnimalLoreGump`)**

| Page | Rows | Source |
|---|---|---|
| 1 Attributes | Hits (cur/max), Stamina, Mana, Strength, Dexterity, Intelligence; AoS+ adds Barding Difficulty (SE) and **Loyalty Rating** | `:201-256` |
| 2 Resistances (AoS only) | Physical / Fire / Cold / Poison / Energy | `:260-284` |
| 3 Damage (AoS only) | Physical / Fire / Cold / Poison / Energy; + Base Damage if `Core.ML` | `:288-320` |
| 4 Combat Ratings / Lore & Knowledge | Wrestling, Tactics, Magic Resistance, Anatomy, Poisoning (or Healing for Cu Sidhe); Magery, Evaluating Intelligence, Meditation | `:324-367` |
| 5 Misc | Preferred Foods (Meat/Fish/Grains/Fruits/Eggs), Pack Instincts (Canine/Ostard/Feline/Arachnid/Daemon/Bear/Equine/Bull); pre-AoS adds Loyalty Rating | `:371-424` |

| Formatting rule | Code |
|---|---|
| Skill `< 10.0` → `---`, else `{0:F1}` | `:124-132` |
| Attribute with `max == 0` → `---` | `:134-140` |
| Stat `0` → `---` | `:142-148` |
| Resistance/Damage `<= 0` → `---`, else `{0}%` | `:158-164` |
| Damage range `min<=0 or max<=0` → `---`, else `{0}-{1}` | `:167-173` |
| **Loyalty line** | `(!c.Controlled \|\| c.Loyalty == 0) ? 1061643 : 1049595 + (c.Loyalty / 10)` (`:244`, `:420`) ⇒ 11 bands `1049595`–`1049605`; `Loyalty` is `0..100` (`BaseCreature.cs:204`,`:1727`) |
| Barding Difficulty | `Items.BaseInstrument.GetBaseDifficulty(c)`, forced to `0` when `c.Uncalmable` (`:230-235`) |

`[SRC]`. `[PARTIAL]`: the English wording of `1049595`–`1049605` (loyalty bands) and `1061643`
("wonderfully happy") is cliloc-side; measure by dumping those ids.

---

### 2.3 Arms Lore

Source: `ServUO:Scripts/Skills/ArmsLore.cs` (167 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/ArmsLore.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`ArmsLore.cs:13`), 1.0 s |
| Target requirements | `Target(2, false, TargetFlags.None)` with `AllowNonlocal = true` (`:29-31`), annotated `[PlayerVendorTarget]`; accepts `BaseWeapon`, `BaseArmor`, `SwampDragon` with barding |
| Skill check window | `CheckTargetSkill(ArmsLore, targeted, 0, 100)` — separate roll for weapon (`:38`), armor (`:99`), barding (`:144`) ⇒ chance = `ArmsLore.Value/100` |
| Delay / cooldown | 1.0 s (`:22`) |
| Success outcome | Durability line + damage/AR band line (+ poison line for weapons) |
| Failure outcome | `500353` "You are not certain…" (`:94`,`:137`,`:157`) |
| Resource consumed | none |
| Messages / gumps | `500349` "What item do you wish to get information about?" (`:20`); `500352` "This is neither weapon nor armor." (`:162`) |
| Interactions | none coded (Arms Lore is informational only); Swamp Dragon barding result feeds the barding armour system |
| [ERA] | Text set `1038285`/`1038216`–`1038224`/`1038295` is AoS-era. The old hard-coded `if/else` ladder is **commented out** in source (`:61-74`, `:116-133`) and replaced by arithmetic. `[ERA]` = the arithmetic form is what this shard ships |
| Confidence | `[SRC]` |

**Identification output tables**

| Target | Formula | Output cliloc |
|---|---|---|
| Weapon durability | `hp = (int)((HitPoints / (double)MaxHitPoints) * 10)`, clamped `0..9` (only if `MaxHitPoints != 0`) | `1038285 + hp` → 10 bands (`:42-52`) |
| Weapon damage band | `d = (MaxDamage + MinDamage) / 2`; `d < 3 → 0`; else `d = (int)Math.Ceiling(Math.Min(d, 30) / 5.0)` | 0,1,2,3,4,5,6 (`:54-60`) |
| Weapon hand flag | `hand = (weap.Layer == Layer.OneHanded ? 0 : 1)` | distinguishes 1H/2H text (`:55`) |
| Ranged | `1038224 + (damage * 9)` | `1038224, 1038233, … 1038278` (`:79`) |
| Piercing | `1038218 + hand + (damage * 9)` | `1038218`–`1038281` (`:81`) |
| Slashing | `1038220 + hand + (damage * 9)` | `1038220`–`1038283` (`:83`) |
| Bashing | `1038222 + hand + (damage * 9)` | `1038222`–`1038285` (`:85`) |
| Other/unknown weapon type | `1038216 + hand + (damage * 9)` | `1038216`–`1038279` (`:87`) |
| Poisoned weapon | `weap.Poison != null && weap.PoisonCharges > 0` → `1038284` "It appears to have poison smeared on it." | `:89-90` |
| Armor durability | same `hp` formula, clamped `0..9` | `1038285 + hp` (`:103-112`) |
| Armor rating band | `1038295 + (int)Math.Ceiling(Math.Min(arm.ArmorRating, 35) / 5.0)` | 8 bands `1038295`–`1038302` (0..7) (`:115`) |
| Swamp Dragon barding | `perc = (4 * BardingHP) / BardingMaxHP`, clamped `0..4` | `1053021 - perc` → 5 bands (`:146-153`) |

`[SRC]` for every arithmetic constant. `[PARTIAL]`: the commented-out ladder at `:116-133` documents
the *original* OSI thresholds (`<1`, `<6`, `<11`, `<16`, `<21`, `<26`, `<31`, else) — these are dead
code in `pub57` and are **not** what the server sends; they are useful only as era reference.

---

### 2.4 Evaluating Intelligence

Source: `ServUO:Scripts/Skills/EvalInt.cs` (93 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/EvalInt.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[16]` (`EvalInt.cs:12`), 1.0 s |
| Target requirements | `Target(8, false, TargetFlags.None)` (`:27`); Mobile only for the stat read-out |
| Skill check window | `CheckTargetSkill(EvalInt, targ, 0.0, 120.0)` (`:74`) |
| Delay / cooldown | 1.0 s (`:21`) |
| Success outcome | `1038169 + intMod + body` (`:76`); if `EvalInt.Base >= 76.0` a second line `1038202 + mnMod` (`:79`) |
| Failure outcome | `1038166 + (body / 11)` (`:83`) |
| Resource consumed | none |
| Messages / gumps | `500906` "What do you wish to evaluate?" (`:19`); self `500910`; TownCrier `500907`; invulnerable vendor `500909`; item `500908` |
| Interactions | EvalInt is `DamageSkill` for **all** Magery spells (`Scripts/Spells/Base/Spell.cs:53`) and therefore scales spell damage; `Protection` uses `EvalInt + Meditation + Inscribe` for its resist malus (`Scripts/Spells/Second/Protection.cs:145`); Paralyze Field duration uses `EvalInt/10 - MagicResist/10` (`Scripts/Spells/Sixth/ParalyzeField.cs:188`); weapon Paralyze/Concussion blow durations use EvalInt too (`BaseWeapon.cs:1934`,`:1948`) |
| [ERA] | AoS damage path uses `evalScale`; pre-AoS uses the `casterEI vs targetRS` scalar. No era gate on the lore read-out itself |
| Confidence | `[SRC]` for formulas; `[PARTIAL]` for cliloc text |

**Lore output thresholds**

| Index | Computation | Range |
|---|---|---|
| `marginOfError` | `Math.Max(0, 20 - (int)(EvalInt.Value / 5))` | 20 at 0 → 0 at ≥100 (`:49`) |
| `intel` / `mana` | `targ.Int + RandomMinMax(-m,+m)`; `((targ.Mana*100)/Math.Max(targ.ManaMax,1)) + RandomMinMax(-m,+m)` | mana is a **percent** (`:51-52`) |
| `intMod` / `mnMod` | `value / 10`, clamped `0..10` | 11 bands (`:54-65`) |
| `body` | `targ.Body.IsHuman ? (targ.Female ? 11 : 0) : 22` | 0 = human male, 11 = human female, 22 = non-human (`:67-72`) |
| Success line 1 | `1038169 + intMod + body` | 33 clilocs `1038169`–`1038201` |
| Success line 2 (requires `Base >= 76.0`) | `1038202 + mnMod` | 11 clilocs `1038202`–`1038212` |
| Failure line | `1038166 + (body / 11)` | `1038166` (male), `1038167` (female), `1038168` (non-human) |

**Magery interaction (the "circle gating" claim)** `[SRC]`:

| Question | What the source actually contains |
|---|---|
| Is EvalInt a cast requirement? | **No.** Casting is gated by `Caster.CheckSkill(CastSkill, minSkill, maxSkill)` where `CastSkill` = the spell's own skill (`Scripts/Spells/Base/Spell.cs:919-943`); `GetCastSkills(out min, out max)` is overridden **per spell** and defaults to `min = max = 0` (`:919-922`). There is **no** code path anywhere in `pub57` that maps EvalInt to a spell circle |
| What EvalInt *does* do at cast time | `CheckFizzle()` also rolls `Caster.CheckSkill(DamageSkill, 0.0, Caster.Skills[DamageSkill].Cap)` when `DamageSkill != CastSkill` — i.e. EvalInt gains passively on every magery cast (`:935-938`) |
| AoS damage scaling | `int evalSkill = GetDamageFixed(m_Caster); int evalScale = 30 + ((9 * evalSkill) / 100); damage = AOS.Scale(damage, evalScale)` (`:231-234`) — at 100.0 EvalInt (`evalSkill = 1000`) ⇒ **×1.20**; at 120.0 ⇒ ×1.408 |
| AoS extra bonus | `damageBonus` also includes `Caster.Int/10` and `scribeBonus = inscribeSkill >= 1000 ? 10 : inscribeSkill/200` (`:224-229`) |
| Pre-AoS damage scalar | `casterEI > targetRS ? 1.0 + (casterEI - targetRS)/500 : 1.0 + (casterEI - targetRS)/200`; plus `(Magery - 100)/400`; **×2 vs non-human, non-player targets when `!Core.AOS`** (`:451-478`) |

`[UNVERIFIED]`: if the delivery target requires the classic "circle = (Magery + EvalInt)/20" rule,
it does **not** exist in ServUO. To confirm what the retail client shows, measure on a live shard:
cast a 4th-circle spell with `Magery 30 / EvalInt 100` and observe whether the client refuses.

---

### 2.5 Item Identification

Source: `ServUO:Scripts/Skills/ItemIdentification.cs` (195 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/ItemIdentification.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[(int)SkillName.ItemID]` (`:14`), 1.0 s |
| Target requirements | `Target(8, false, TargetFlags.None)` + `AllowNonlocal` (`:29-32`), `[PlayerVendorTarget]`; accepts `Item` **or** `Mobile` |
| Skill check window | `CheckTargetSkill(ItemID, o, 0, 100)` (`:45`) → chance = `ItemID.Value/100` |
| Delay / cooldown | 1.0 s (`:22`) |
| Success outcome | Item: name (custom name or `LabelNumber`) shown as Emote to the user **and** as a Label over the item (`:57-66`). Mobile: `1041349` + name (`:53`). AoS adds value + unravel info; pre-AoS sets `Identified = true` and calls `OnSingleClick` |
| Failure outcome | AoS: `1041352` "You have no idea how much it might be worth." (`:47`); pre-AoS: `500353` (`:159`); non-item/non-mobile target: `500353` (`:41`) |
| Resource consumed | none |
| Messages / gumps | `500343` "What do you wish to appraise and identify?" (`:19`); Meteorite special text `1158697` (polished) / `1158696` (raw), which short-circuits everything else (`:70-82`) |
| Interactions | **Imbuing**: `Imbuing.TimesImbued`, `Imbuing.GetTotalWeight`, `Imbuing.CanUnravelItem` decide the unravel ingredient text and are gated on the *reader's* `Imbuing.Base` (`:88-138`). XmlSpawner attachments are revealed last (`:171`) |
| [ERA] | `if (Core.AOS)` value/unravel branch (`:68`); pre-AoS branch only sets `Identified` and single-clicks (`:145-161`) |
| Confidence | `[SRC]` |

**Value + unravel thresholds**

| Condition | Result | Citation |
|---|---|---|
| Type present in `GenericBuyInfo.BuyPrices` | price = `BuyPrices[type] * item.Amount` | `:178-181` |
| Otherwise | `Utility.RandomMinMax(2, 7)`, cached per `Type` in `TypeCostCache` for the process lifetime | `:183-192` |
| Display | `1041351` "You guess the value of that item at:" + `"  " + GetPriceFor(item)` | `:84` |
| `Imbuing.TimesImbued(item) > 0` | `1111877` "…cannot be magically unraveled. The magic in that item has been weakened…" | `:88-90` |
| weight `1..200` | `Magical Residue` | `:104-107` |
| weight `201..479` | `Enchanted Essence`; if `Imbuing.Base < 45.0` → `1111875` "Your Imbuing skill is not high enough to identify the imbuing ingredient." | `:108-114` |
| weight `>= 480` | `Relic Fragment`; if `Imbuing.Base < 95.0` → `1111875` | `:115-121` |
| weight `0` / not unravelable | `1111876` "…appears to possess little to no magic." | `:134-137` |
| Item not weapon/armor/jewel/hat (AoS) | `1111878` "You conclude that item cannot be magically unraveled." | `:140-143` |
| Unravel message | `1111874` "You conclude that item will magically unravel into: ~1_ingredient~" | `:131` |

`[SRC]`. `[PARTIAL]`: the canonical *pre-AoS* Item ID price ladder (weapon/armor tiers) is not
implemented — pre-AoS simply toggles `Identified`. Measure the classic tier text client-side if the
clone needs it.

---

### 2.6 Taste Identification

Source: `ServUO:Scripts/Skills/TasteID.cs` (95 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/TasteID.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:12`), 1.0 s |
| Target requirements | `Target(2, false, TargetFlags.None)` + `AllowNonlocal` (`:28-31`), `[PlayerVendorTarget]`; `Food`, `BasePotion`, `PotionKeg` |
| Skill check window | `CheckTargetSkill(TasteID, food, 0, 100)` — **only rolled for `Food`** (`:43`). Potions and kegs are always identified with no roll |
| Delay / cooldown | 1.0 s (`:21`) |
| Success outcome | Food with `food.Poison != null` → `1038284` "It appears to have poison smeared on it." (`:47`); clean food → `1010600` "You detect nothing unusual about this substance." (`:52`). Potion → `502813` + `potion.LabelNumber` (`:65-66`). Keg with contents → `502229` + `keg.LabelNumber` (`:78-79`) |
| Failure outcome | `502823` "You cannot discern anything about this substance." (`:58`) — poison is **not** falsely reported, it is simply unknown |
| Resource consumed | none (the food is not eaten) |
| Messages / gumps | `502807` "What would you like to taste?" (`:19`); Mobile target `502816` "You feel that such an action would be inappropriate." (`:37`); empty keg `502228` (`:74`); other item `502820` "That's not something you can taste." (`:85`); out of range `502815` (`:91`) |
| Interactions | the only player-facing poison detector for food; pairs with Poisoning (`Scripts/Skills/Poisoning.cs:120` sets `Food.Poison`) and with the "poisoned food" mechanic; `label 1038284` shared with Arms Lore |
| [ERA] | No era gate — the `1038284`/`1010600` set is AoS-era text; pre-AoS shards showed a generic message. `[PARTIAL]` |
| Confidence | `[SRC]` |

---

### 2.7 Forensic Evaluation

Source: `ServUO:Scripts/Skills/ForensicEval.cs` (173 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/ForensicEval.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:19`) + `m.RevealingAction()` (`:25`), 1.0 s |
| Target requirements | `Target(10, false, TargetFlags.None)` (`:35`); accepts `Corpse`, `Mobile`, `ILockpickable`, and (SA) `Item` with `IForensicTarget` or an `HonestyItemSocket` |
| Skill check window | Per target type — see table below. `skill = from.Skills[Forensics].Value` (`:41`) |
| Delay / cooldown | 1.0 s (`:29`) |
| Success outcome | See table; also stamps `c.m_Forensicist = from.Name` if unset (`:59`) |
| Failure outcome | `501001` "You cannot determain anything useful." *(sic)* — and for under-skill targets `501003` "You notice nothing unusual." |
| Resource consumed | none |
| Messages / gumps | `501000` "Show me the crime." (`:27`); corpse outcomes `1042750`/`1042751`/`1042752`/`501002`; thief `501004` "That individual is a thief!"; lock `1042749` "This lock was opened by ~1_PICKER_NAME~"; Honesty `1151521`/`1151522` |
| Interactions | shares the `ILockpickable.Picker` field with Lockpicking; shares `Corpse.Killer` with the murder/justice system and `Corpse.Looters` (updated by looting); `NpcGuild.ThievesGuild` is set by the thief guild system; Honesty virtue socket (SA) assigns an owner on first forensic use (`:153`) |
| [ERA] | `ILockpickable` and `Mobile` branches are base; the `Item`/Honesty branch is `Core.SA` (`:134`) and the 61.0 skill tier (`:159`) is SA-era. The 55.0 upper bound for corpses is pre-AoS-shaped |
| Confidence | `[SRC]` |

| Target | Min skill gate | `CheckTargetSkill` window | Success message | Citation |
|---|---|---|---|---|
| `Corpse` | `skill < 30.0` → `501003` | `(Forensics, target, 30.0, 55.0)` | already examined → `1042750` + forensicist name; human body → `1042751` "This person was killed by ~1_KILLER_NAME~" (`"no one"` if `Killer == null`); looted → `1042752` list of `Looters`; else `501002` "The corpse has not be desecrated." | `:44-81` |
| `Mobile` | `skill < 36.0` → `501003` | `(Forensics, target, 36.0, 100.0)` | `501004` if `PlayerMobile.NpcGuild == ThievesGuild`, else `501003` | `:88-108` |
| `ILockpickable` | `skill < 41.0` → `501003` | `(Forensics, target, 41.0, 100.0)` | `1042749` + `p.Picker.Name` if set, else `501003` | `:110-133` |
| `Item` (`Core.SA`) | `skill < 41.0` (and not `IForensicTarget`) → `501001` | `(Forensics, target, 41.0, 100.0)` on the Honesty socket | `skill >= 61.0` → `1151521` "This item belongs to ~1_val~ who lives in ~2_val~." else `1151522` "…~1_val~" (region only) | `:134-168` |

---

### 2.8 Tracking

Source: `ServUO:Scripts/Skills/Tracking.cs` (394 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Tracking.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:17`) → `1011350` "What do you wish to track?" + `TrackWhatGump` (`:22-26`), 10.0 s |
| Target requirements | No world target — a 4-button gump picks the **category**; the follow-up `TrackWhoGump` picks the individual |
| Skill check window | Rolled **once when the gump is built**: `from.CheckSkill(Tracking, 0.0, 21.1)` stored as `m_Success` (`:87`). A second, purely-for-gain roll `from.CheckSkill(Tracking, 21.1, 100.0)` fires when a category is chosen (`:189`) |
| Delay / cooldown | 10.0 s (`:28`) |
| Success outcome | `TrackWhoGump` listing up to 12 candidates + `1018093` "Select the one you would like to track." (`:208-209`) |
| Failure outcome | `1018092` "You see no evidence of those in the area." (`:178`); empty-but-successful category → `502991` / `502993` / `502995` (`:213-218`) |
| Resource consumed | none |
| Messages / gumps | gump title buttons `1018087` Animals, `1018088` Monsters, `1018089` Human NPCs, `1018090` Players (`:98-110`); arrow lost `503177` "You have lost your quarry." (`:349`) |
| Interactions | **Detect Hidden** — contested vs `Hiding`+`Stealth` for players; **Hiding/Stealth** of the target; **Ninjitsu** — the stalking bonus is consumed by `Backstab` (`Backstab.cs:44`), `Death Strike` (`DeathStrike.cs:125`), `Surprise Attack` (`SurpriseAttack.cs:103`); **Necromancy** transformations alter the divisor |
| [ERA] | `Core.SE` changes the difficulty formula (`:264-267`) and enables `Tracking.AddInfo` for the stalking bonus (`:232-233`); `Core.ML` halves an elf's effective Tracking (`:246-247`) and **caps** the stalking bonus (`:52-53`); pre-AoS `CheckDifficulty` returns `true` unconditionally (`:240`) |
| Confidence | `[SRC]` |

| Element | Formula / constant | Citation |
|---|---|---|
| Range | `int range = 10 + (int)(from.Skills[Tracking].Value / 10)` ⇒ **10 tiles at 0, 20 at 100, 22 at 120** | `:191` |
| Candidate filter | `m != from && (!Core.AOS \|\| m.Alive) && (!m.Hidden \|\| m.IsPlayer() \|\| from.AccessLevel > m.AccessLevel) && check(m) && CheckDifficulty(from, m)` — **ghosts can never be tracked** | `:199` |
| Categories | Animals = `!Player && Body.IsAnimal`; Monsters = `!Player && Body.IsMonster`; Human NPCs = `!Player && Body.IsHuman`; Players = `Player` | `:275-293` |
| Step rules | gump lists ≤12 (`:162`); 4 per row (`:166`); sorted **closest first** by `GetDistanceToSqrt` | `:295-314` |
| Arrow lifetime | `TrackArrow(..., m_Range * 2)` → arrow radius = **2× the track range** | `:230` |
| Arrow tick | timer delay 0.25 s, interval 2.5 s (`:362`); stops on: no `NetState`, deleted, map mismatch, `!InRange(target, m_Range)`, or hidden target with higher `AccessLevel` (`:378`) |
| Cancel | right-click → `Tracking.ClearTrackingInfo` + stop (`:329-339`) |

**Player-vs-player difficulty (`CheckDifficulty`, `:238-273`)**

| Step | Literal |
|---|---|
| `tracking` | `from.Skills[Tracking].Fixed` (×10 fixed-point) |
| `detectHidden` | `from.Skills[DetectHidden].Fixed` |
| Elf penalty | `if (Core.ML && m.Race == Race.Elf) tracking /= 2` |
| `divisor` | `m.Skills[Hiding].Fixed + m.Skills[Stealth].Fixed` |
| Horrific Beast target | `divisor -= 200` |
| Vampiric Embrace target | `if (divisor < 500) divisor = 500` |
| Wraith Form target | `if (divisor <= 2000) divisor += 200` |
| `Core.SE` chance | `chance = 50 * (tracking * 2 + detectHidden) / divisor` |
| pre-SE chance | `chance = 50 * (tracking + detectHidden + 10 * Utility.RandomMinMax(1, 20)) / divisor` |
| `divisor <= 0` | `chance = 100` |
| Result | `return chance > Utility.Random(100)` |

**Stalking bonus** (`:37-56`)

| Step | Literal |
|---|---|
| Validity | stored `TrackingInfo` must exist, `info.m_Target == target`, `info.m_Map == target.Map`, else `0.0` |
| Bonus | `Math.Sqrt(xDelta*xDelta + yDelta*yDelta)` — the **straight-line distance from the position recorded at track time to the target's current position** |
| Consumption | `m_Table.Remove(tracker)` — one-shot ("Reset as of Pub 40, counting it as bug for Core.SE", in-source comment `:50`) |
| `Core.ML` cap | `Math.Min(bonus, 10 + tracker.Skills.Tracking.Value / 10)` ⇒ cap 20 at 100 Tracking |

`[SRC]`. Divergence with ModernUO: `ModernUO:Projects/UOContent/Skills/Tracking/Tracking.cs:166` uses
`10 + (int)from.Skills.Tracking.Value / 10 * 10` (range quantised to multiples of 10) — ServUO's
per-point range is not reproduced there.

---

### 2.9 Begging

Source: `ServUO:Scripts/Skills/Begging.cs` (336 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Begging.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:16`) + `RevealingAction` (`:21`) + deferred target (`:25`) |
| Target requirements | `Target(12, false, TargetFlags.None)` (`:35`) — 12 tiles, but the *actual* range gate is `from.InRange(targ, 2)` (`:64`) |
| Skill check window | `CheckTargetSkill(Begging, m_Target, 0.0, 100.0)` (`:131`) → chance = `Begging.Value / 100` |
| Delay / cooldown | Callback returns **1 hour** (`:27`); if the target resolves, `OnTargetFinish` sets `NextSkillTime = Core.TickCount` (`:42`) so the real cooldown is **10 s** written at `:331`. If the target is cancelled, the 1-hour penalty stays |
| Success outcome | Gold or an item handed over (tables below), karma loss |
| Failure outcome | `m_Target.SendLocalizedMessage(500404)` "They seem unwilling to give you any money." (`:327`) — note it is sent to the **NPC**, not the beggar |
| Resource consumed | none of the beggar's; the NPC's gold is decremented |
| Messages / gumps | `500397` "To whom do you wish to grovel?" (`:23`); player target `500398` "Perhaps just asking would work better."; non-human `500399` "There is little chance of getting money from that!"; too far `500401` (male) / `500402` (female); mounted (pre-ML) `500404`; low karma `500406` "Thou dost not look trustworthy... no gold for thee today!"; success `500405` "I feel sorry for thee..."; poor NPC `500407` "I have not enough money to give thee any!"; elf path `1074854` "Here, take this..." + `1074853` "You have been given ~1_name~" |
| Interactions | Karma system (`Titles.AwardKarma`), `Fame` scales the gold cap; `Core.ML` removes the mounted restriction (`:75`); elf NPCs use a completely different reward path (`:133`) |
| [ERA] | `!Core.ML && from.Mounted` → refuse (`:75`) is the pre-ML rule with an in-source `TODO: guessed it's removed since ML`; the elf reward path and `1074853`/`1074854` are ML-era |
| Confidence | `[SRC]`; `[PARTIAL]` for the elf item names (in-code strings only, see below) |

**Pre-check refusals** (`:52-95`)

| Condition | Message |
|---|---|
| `targ.Player` | `500398` |
| `!targ.Body.IsHuman` | `500399` |
| `!from.InRange(targ, 2)` | `500401` (target male) / `500402` (target female) |
| `!Core.ML && from.Mounted` | `500404` |
| target is not a `Mobile` | `500399` |

**Resolution timer (2.0 s, `:109`)**

| Step | Literal | Citation |
|---|---|---|
| `badKarmaChance` | `0.5 - ((double)m_From.Karma / 8570)` | `:120` |
| No backpack and not elf | `500404` | `:122-125` |
| `Karma < 0 && badKarmaChance > RandomDouble()` | `500406` (no gold) | `:126-130` |
| Skill success, **non-elf** | `toConsume = pack gold / 10`; `max = 10 + (Fame / 2500)` clamped to `10..14`; `toConsume = min(toConsume, max)`; `ConsumeUpTo(typeof(Gold), toConsume)` | `:135-154` |
| Gold actually consumed | `500405` "I feel sorry for thee...", new `Gold(consumed)` added to the beggar's pack, drop sound played | `:156-164` |
| Nothing consumed | `500407` | `:180-188` |
| Karma loss (both paths) | `if (Karma > -3000) { toLose = Karma + 3000; if (toLose > 40) toLose = 40; Titles.AwardKarma(-toLose, true); }` | `:166-176`, `:310-320` |
| Skill success, **elf** | item table by `Utility.RandomDouble()` | `:192-308` |
| Final write | `m_From.NextSkillTime = Core.TickCount + 10000` (always, success or fail) | `:331` |

**Elf NPC reward table**

| `chance` | `Utility.Random(n)` | Item | In-code name string | Reachable? |
|---|---|---|---|---|
| `>= .99` | `Random(8)` → 0..7 | `BegBedRoll`, `BegCookies`, `BegFishSteak`, `BegFishingPole`, `BegFlowerGarland`, `BegSake`, `BegTurnip`, `BegWine` | "a bedroll", "a plate of cookies.", "a fish steak.", "a fishing pole.", "a flower garland.", "a bottle of Sake.", "a turnip.", "a Bottle of wine." | yes, all 8 |
| `>= .99` | `rand == 8` | `BegWinePitcher` | "a Pitcher of wine." | **no** — `Random(8)` never returns 8 (`Utility.cs:921-924`) |
| `>= .76` | `Random(6)` → 0..5 | `BegStew`, `BegCheeseWedge`, `BegDates`, `BegLantern`, `BegLiquorPitcher`, `BegPizza` | "a bowl of stew.", "a wedge of cheese.", "a bunch of dates.", "a lantern.", "a Pitcher of liquor", "pizza" | yes, all 6 |
| `>= .76` | `rand == 6` | `BegShirt` | "a shirt." | **no** — `Random(6)` never returns 6 |
| `>= .25` | `Random(1)` → 0 always | `BegFrenchBread` | "french bread." | yes |
| `>= .25` | `else` | `BegWaterPitcher` | "a Pitcher of water." | **no** — dead branch |
| `< .25` (and any `reward == null`) | — | `new Gold(1)` | — | yes (`:301-304`) |

`[SRC]` — the unreachable branches are a genuine source quirk (three of the sixteen elf rewards can
never be granted). A faithful clone should reproduce the reachable set unless it intends to fix the
quirk. `[PARTIAL]`: whether retail OSI used `Random(8)`/`Random(6)` inclusively is not determinable
from source — measure by begging an elf NPC N≥2000 times and recording the observed item histogram.

---

### 2.10 Herding

Source: `ServUO:Scripts/Items/Equipment/Weapons/ShepherdsCrook.cs:130-257` (+ `Scripts/Mobiles/AI/BaseAI.cs:1433-1453`) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Equipment/Weapons/ShepherdsCrook.cs

| Field | Value |
|---|---|
| Trigger | **Item double-click** on a `ShepherdsCrook` (`:130`) — Herding has no skill callback (`Server/Skills.cs:616` callback = `null`), so the skill button answers `500014` |
| Target requirements | Stage 1 `Target(10, false, TargetFlags.None)` must be a `BaseCreature` that `IsHerdable` (`:155-182`); stage 2 `Target(10, true, TargetFlags.None)` accepts a **ground point** (`:219`) |
| Skill check window | `min = m_Creature.CurrentTameSkill - 30`; `max = m_Creature.CurrentTameSkill + 30 + Utility.Random(10)` (`:229-230`); `CheckTargetSkill(Herding, m_Creature, min, max)` (`:235`) |
| Delay / cooldown | none coded — no `NextSkillTime` write, so herding is limited only by the target cursor and the creature's AI |
| Success outcome | `m_Creature.TargetLocation = p` + `502479` "The animal walks where it was instructed to." (`:242-243`) |
| Failure outcome | `502472` "You don't seem to be able to persuade that to move." (`:252`) |
| Resource consumed | none; on a Siege shard the crook's `IUsesRemaining` is checked (`:245-248`) |
| Messages / gumps | `502464` "Target the animal you wish to herd." (`:132`); `502467` "That animal looks tame already." (`:165`); `502468` "That is not a herdable animal." (`:175`); `502472` for non-creature (`:180`); `502475` "Click where you wish the animal to go." (`:169`); `502471` "That wasn't even challenging." (`:233`) |
| Interactions | keyed to **Animal Taming** via `CurrentTameSkill`; champions — champion-spawn creatures in `m_ChampTamables` are herdable even when not tameable (`:138-145`, `:194-208`); paragons are never herdable (`:186-187`) |
| [ERA] | `CurrentTameSkill` is ToL-era (pet training) but falls back to `MinTameSkill` when training is off (`BaseCreature.cs:739-754`); the champion tamables list is SE/ML-era |
| Confidence | `[SRC]` |

| Herdable test | Rule | Citation |
|---|---|---|
| IsParagon | `false` immediately | `:186-187` |
| `bc.Tamable` | `true` | `:189-190` |
| Champion spawn + type in list | `StrongMongbat, Imp, Scorpion, GiantSpider, Snake, LavaLizard, Drake, Dragon, Kirin, Unicorn, GiantRat, Slime, DireWolf, HellHound, DeathwatchBeetle, LesserHiryu, Hiryu` | `:138-145`, `:196-208` |
| else | `false` | `:210` |
| "Wasn't even challenging" | `if (max <= from.Skills[Herding].Value)` — message only, the check still runs | `:232-233` |

**Creature movement behaviour after a successful herd** (`BaseAI.cs:1433-1453`):

| Step | Rule |
|---|---|
| No target | `TargetLocation == null` → `CheckHerding()` returns `false` (creature resumes normal AI) |
| Arrived / too far | `distance < 1 \|\| distance > 15` → clear `TargetLocation`, return `false` |
| Otherwise | `DoMove(m_Mobile.GetDirectionTo(target))` and return `true` — the AI **walks one step per AI tick toward the point and stops when within 1 tile or beyond 15 tiles** |
| Priority | `CheckHerding()` is consulted from `DoOrderFollow` (`:1457`) and before wander/idle decisions (`:994`, `:1080`, `:1103`, `:1857`) — an active herd target overrides follow/wander |

---

### 2.11 Detect Hidden

Source: `ServUO:Scripts/Skills/DetectHidden.cs` (211 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/DetectHidden.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:32`) → `500819` "Where will you search?" + target; 10.0 s |
| Target requirements | `Target(12, true, TargetFlags.None)` — **ground is allowed** (`:46`); the target may be a Mobile, Item or `IPoint3D`, else the searcher's own location is used (`:54-62`) |
| Skill check window | `src.CheckSkill(DetectHidden, 0.0, 100.0)` (`:67`) — a **failed roll halves the radius** rather than aborting (`:68`) |
| Delay / cooldown | 10.0 s (`:40`) |
| Success outcome | Each hidden mobile within the radius is re-rolled individually and, on success, `RevealingAction()` + `500814` "You have been revealed!" to the target (`:96-99`); revealable items (`IRevealableItem`) are triggered (`:121-126`) |
| Failure outcome | Radius halved; then if nothing at all was found → `500817` "You can see nothing hidden there." (`:135`) |
| Resource consumed | none |
| Messages / gumps | `500819` (prompt), `500814` (revealed), `500817` (nothing found), `1153493` "Your keen senses detect something hidden in the area…" (passive, items only) |
| Interactions | **Hiding + Stealth** of the target (contested), **Tracking** (DetectHidden feeds the player-tracking formula, `Tracking.cs:244`), **Shadow Spell** mastery (`ShadowSpell.GetDifficultyFactor`), **Remove Trap** (requires `DetectHidden >= 50`, `RemoveTrap.cs:33`), **Lockpicking** (same gate), **Forensics** (`ILockpickable.Picker` is what Detect Hidden/Forensics read) |
| [ERA] | `Core.ML`-era elf +20 passive bonus (`:162-163`); `ShadowKnight` (VvV/ToL) special-cased; Felucca ruleset widens `CanDetect` (`:208`) |
| Confidence | `[SRC]` |

**Radius formula (active search)**

| Step | Literal | Citation |
|---|---|---|
| Base | `double srcSkill = src.Skills[DetectHidden].Value` | `:64` |
| Radius | `int range = Math.Max(2, (int)(srcSkill / 10.0))` ⇒ **2 tiles at 0–19, 5 at 50, 10 at 100, 12 at 120** | `:65` |
| Failed check | `range /= 2` (integer division, floor) | `:67-68` |
| House bonus | `BaseHouse.FindHouseAt(p, src.Map, 16)`; if `house.IsFriend(src)` → `range = 22` (flat override, **not** additive) | `:70-75` |
| Search | `src.Map.GetMobilesInRange(p, range)` then `src.Map.GetItemsInRange(p, range)` | `:79`, `:106` |

**Who gets revealed (active)**

| Condition | Citation |
|---|---|
| `trg.Hidden && src != trg` | `:83` |
| `ss = srcSkill + Utility.Random(21) - 10` (i.e. −10..+10) | `:85` |
| `ts = trg.Skills[Hiding].Value + Utility.Random(21) - 10` | `:86` |
| `shadow = SkillMasteries.ShadowSpell.GetDifficultyFactor(trg)` must be **beaten**: `Utility.RandomDouble() > shadow` | `:87`, `:90` |
| `src.AccessLevel >= trg.AccessLevel && (ss >= ts \|\| houseCheck)` | `:90` |
| `houseCheck = inHouse && house.IsInside(trg)` bypasses the skill comparison | `:88` |
| `ShadowKnight` skipped unless it is standing on the targeted tile | `:92-93` |
| `CanDetect(src, trg)` must be true outside a friendly house | `:93`, `:187-209` |

`CanDetect` (`:187-209`) requires: both maps valid, `src.CanBeHarmful(target, false)`, neither side
`Blessed`/invulnerable (`BaseCreature.IsInvulnerable`), `SpellHelper.ValidIndirectTarget`, and finally
either an existing aggressor/aggressed relation **or** `src.Map.Rules == MapRules.FeluccaRules`.

**Passive detect** (`DoPassiveDetect`, `:140-185`; driven from `Scripts/Mobiles/PlayerMobile.cs:2097`)

| Step | Literal | Citation |
|---|---|---|
| Guards | `src == null \|\| src.Map == null \|\| src.Location == Point3D.Zero \|\| src.IsStaff()` → return | `:142-143` |
| Skill | `double ss = src.Skills[DetectHidden].Value`; `ss <= 0` → return | `:145-148` |
| Mobile radius | `src.Map.GetMobilesInRange(src.Location, 4)` — **fixed 4 tiles** | `:150` |
| Target difficulty | `ts = (m.Skills[Hiding].Value + m.Skills[Stealth].Value) / 2` | `:160` |
| Elf | `if (src.Race == Race.Elf) ss += 20` | `:162-163` |
| **Passive chance** | `Utility.Random(1000) < (ss - ts) + 1` ⇒ probability = `((ss - ts) + 1) / 1000` per tick, i.e. **1 % per 10 points of DetectHidden advantage** | `:165` |
| Exclusions | `m == src`, `m is ShadowKnight`, `!CanDetect(src, m)` | `:157` |
| Item radius | `GetItemsInRange(src.Location, 8)` — **fixed 8 tiles**; a hit prints `1153493` | `:174-181` |

`[SRC]`. `[UNVERIFIED]`: the *tick source* of `DoPassiveDetect` is the player's own step/movement
handler; the exact cadence is not a constant in `DetectHidden.cs`. To nail the per-second passive
detect probability, measure on a live shard: log reveals per in-game second while standing still vs
walking.

---

### 2.12 Remove Trap

Source: `ServUO:Scripts/Skills/RemoveTrap.cs` (411 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/RemoveTrap.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:24`), gated **before** the target cursor; 10.0 s |
| Target requirements | `Target(2, false, TargetFlags.None)` (`:50`); accepts `TrapableContainer`, `BaseFactionTrap`, `VvVTrap`, `GoblinFloorTrap`, `IRemoveTrapTrainingKit` |
| Skill check window | `CheckTargetSkill(RemoveTrap, targ, targ.TrapPower, targ.TrapPower + 10)` (`:111`) — **dynamic window driven by the trap**, not a fixed constant |
| Delay / cooldown | 10.0 s (`:44`); the treasure-chest path also re-arms `NextSkillTime` when the player is out of range (`:238-243`) |
| Success outcome | `targ.TrapPower = 0; targ.TrapLevel = 0; targ.TrapType = TrapType.None; InvalidateProperties()` + `502377` "You successfully render the trap harmless" (`:113-117`) |
| Failure outcome | `502372` "You fail to disarm the trap... but you don't set it off" (`:121`) — the skill **never** triggers the trap; only `VvVTrap` and the treasure-chest guardian path can hurt you |
| Resource consumed | Faction traps: one `FactionTrapRemovalKit` charge (`:167-168`). Treasure chests: none |
| Messages / gumps | Skill gate `502366` "You do not know enough about locks…" / `502367` "You are not perceptive enough…"; prompt `502368` "Wich trap will you attempt to disarm?" *(sic)*; Mobile target `502816`; locked container `501283`; untrapped `502373`; faction messages `1010538`/`1010537`/`1042530`; VvV `1155496`; chest `1159010`/`1159059`/`1159063`/`1159060`/`1159057`/`1159058`/`1159061`/`1159009` |
| Interactions | **Lockpicking ≥ 50.0 and Detect Hidden ≥ 50.0 are hard prerequisites** (`:29-36`); **Tinkering 80–100** is required *in addition* for faction traps (`:148`); **Magery** — the 2nd-circle `Remove Trap` spell clears traps with **no** Remove Trap skill at all (see below); Forensics reads `ILockpickable.Picker` |
| [ERA] | `!Core.EJ` guards the Lockpicking/Detect Hidden prerequisites (`:29`,`:33`) — Endless Journey accounts skip them; `Core.ML && isOwner` lets the faction-trap owner disarm for free (`:148`); the treasure-chest manipulation minigame is SA/TreasureMap-revamp (`TreasureMapInfo.NewSystem`, `:78`); VvV (`:171`) is ToL-era |
| Confidence | `[SRC]` |

**Pre-target gates** (`OnUse`, `:27-45`)

| Condition | Result |
|---|---|
| `!Core.EJ && Lockpicking.Value < 50` | `502366`, **no cursor**, 10 s cooldown |
| `!Core.EJ && DetectHidden.Value < 50` | `502367`, **no cursor**, 10 s cooldown |
| else | `502368` + `InternalTarget` |

**Trap types (`TrapType`)** — `Scripts/Items/Containers/TrapableContainer.cs:5-12`:

| Value | Name | Effect on open (`ExecuteTrap`) | Citation |
|---|---|---|---|
| 0 | `None` | nothing | `:74` |
| 1 | `MagicTrap` | `from.Damage(TrapPower)` if `InRange(loc, 1)`; 5 explosion effects + sound `0x307` | `:111-128` |
| 2 | `ExplosionTrap` | if `InRange(loc, 3)`: `damage = TrapLevel > 0 ? RandomMinMax(10,30) * TrapLevel : TrapPower`, applied as 100 % fire | `:87-110` |
| 3 | `DartTrap` | if `InRange(loc, 3)`: `damage = TrapLevel > 0 ? RandomMinMax(5,15) * TrapLevel : TrapPower`, 100 % physical; sound `0x223` | `:129-151` |
| 4 | `PoisonTrap` | if `InRange(loc, 3)`: `TrapLevel > 0 ? Poison.GetPoison(clamp(TrapLevel-1, 0, 4)) : Poison.Greater` + `ApplyPoison` | `:152-180` |
| — | After firing | `TrapType = None; TrapPower = 0; TrapLevel = 0` (trap is consumed) | `:183-185` |

**Handler branches**

| Target | Behaviour | Citation |
|---|---|---|
| `Mobile` | `502816` "You feel that such an action would be inappropriate" | `:56-59` |
| `IRemoveTrapTrainingKit` | delegates to `OnRemoveTrap(from)` | `:60-63` |
| `LockableContainer && Locked` | `501283` "That is locked." | `:64-67` |
| `TrapableContainer`, `TrapType == None` | `502373` "That doesn't appear to be trapped" | `:74-77` |
| `TreasureMapChest` (new t-map system) | owner check `1159010`; `IsDisarming` → `1159059`; `IsBeingDisarmed` → `1159063`; live `AncientGuardians` → `1159060` + fail; else `1159057` + `StartChestDisarmTimer` | `:78-106` |
| `TrapableContainer` (normal) | `CheckTargetSkill(RemoveTrap, targ, TrapPower, TrapPower + 10)`; success zeroes the trap, failure `502372` | `:107-123` |
| `BaseFactionTrap` | `faction == null` → `1010538`; own faction & !owner → `1010537`; !owner & no kit → `1042530`; else `(Core.ML && isOwner) \|\| (RemoveTrap 80–100 && Tinkering 80–100)` → `DisarmMessage` + faction silver + `trap.Delete()`; failure `502372`; kit charge consumed | `:125-170` |
| `VvVTrap` | must be a VvV participant (`1155496`); success condition `from == trap.Owner \|\| ((RemoveTrap.Value - 80.0) / 20.0) > Utility.RandomDouble()` (⇒ **0 % at 80, 100 % at 100, linear between**); produces a `VvVTrapKit`; else `if (.1 > Utility.RandomDouble()) trap.Detonate(from)` | `:171-208` |
| `GoblinFloorTrap` | `InRange(3)` → optional `FloorTrapComponent` if unowned, `targ.Delete()`, `502377` | `:209-228` |
| anything else | `502373` | `:229-232` |

**Treasure chest manipulation minigame** (`RemoveTrapTimer`, `:303-410`)

| Element | Literal | Citation |
|---|---|---|
| Timer | `base(TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(10))`, started in ctor | `:313-314`, `:337` |
| "GM remover" | `from.Skills[RemoveTrap].Value >= 100` (passed as `gmRemover`) | `:263` |
| Safety window (GM remover) | `Stash 20 s, Supply 60 s, Cache 180 s, Hoard 420 s, Trove 540 s` added to `Chest.DigTime` | `:324-334` |
| GM remover roll | after the safety window: `CheckTargetSkill(RemoveTrap, Chest, 80, 120 + (Chest.Level * 10))`; inside the window a success disarms, a failure spawns an `AncientGuardian` | `:356-374` |
| Normal remover | `min = (double)Math.Ceiling(From.Skills[RemoveTrap].Value * .75)`; window `(min, min > 50 ? min + 50 : 100)` | `:382-384` |
| Failure | `Chest.SpawnAncientGuardian(From)` + `1159057` if still alive | `:391-396` |
| Abort conditions | chest deleted; `!From.Alive` → `1159061`; `!InRange(GetWorldLocation(), 16)` → `1159058` | `:342-355` |
| Disarm | `TrapPower = 0; TrapLevel = 0; TrapType = None; InvalidateProperties()` + `1159009` "You successfully disarm the trap!" | `:401-409` |

**Magery interaction (the `Remove Trap` spell, 2nd circle)** — `Scripts/Spells/Second/RemoveTrap.cs`:

| Element | Value | Citation |
|---|---|---|
| Reagents | `Reagent.Bloodmoss`, `Reagent.SulfurousAsh` | `:13-14` |
| Circle | `SpellCircle.Second` | `:20-26` |
| Target | `TrapableContainer` within `Core.ML ? 10 : 12` tiles | `:63`, `:70-72` |
| Restriction | `item.TrapType != TrapType.None && item.TrapType != TrapType.MagicTrap` → **`DoFizzle()`** — the spell only works on `MagicTrap` (and no-ops on `None`) | `:38-41` |
| Effect | `TrapType = None; TrapPower = 0; TrapLevel = 0` — no Remove Trap skill check, no skill gain | `:51-53` |
| Non-container | `501856` "That isn't trapped." | `:76` |

`[SRC]`. There is **no** code path where Magery increases the Remove Trap skill check; the only
Magery synergy is the separate spell above. `[PARTIAL]`: the classic claim that the spell requires
`Detect Hidden` is not in this source.

---

### 2.13 Poisoning

Source: `ServUO:Scripts/Skills/Poisoning.cs` (172 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Poisoning.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:11`) → `502137` "Select the poison you wish to use"; 10.0 s |
| Target requirements | Stage 1 `Target(2, false, TargetFlags.None)` must be a `BasePoisonPotion` (`:32`); stage 2 `Target(2, false, TargetFlags.None)` must be `Food`, `FukiyaDarts`, `Shuriken`, or a weapon that qualifies (`:52-76`) |
| Skill check window | `CheckTargetSkill(Poisoning, m_Target, potion.MinPoisoningSkill, potion.MaxPoisoningSkill)` (`:116`) — window comes from the **potion class**, see table below |
| Delay / cooldown | 10.0 s (`:20`); plus a **2.0 s application timer** before the roll (`:104`) |
| Success outcome | `Food.Poison = m_Poison`; `BaseWeapon.Poison` + `PoisonCharges = 18 - (m_Poison.RealLevel * 2)`; darts/shuriken charges `Math.Min(18 - RealLevel*2, UsesRemaining)`; `1010517` "You apply the poison"; **Karma −20** | `:118-140` |
| Failure outcome | At `Poisoning.Base < 80.0`, a **5 % chance** (`Utility.Random(20) == 0`) to poison yourself: `502148` "You make a grave mistake while applying the poison." + `ApplyPoison(self, m_Poison)`. Otherwise `1010516` (slashing weapon) or `1010518` (everything else) | `:143-165` |
| Resource consumed | **The potion is consumed when the 2-second timer starts** (`:83`) — i.e. a failed skill check still costs the potion. A `Bottle` is added to the backpack (`:84`). Sound `0x4F` |
| Messages / gumps | `502137`, `502142` "To what do you wish to apply the poison?", `502139` "That is not a poison potion.", `502145` (pre-AoS) / `1060204` (AoS) "You cannot poison that!…", `1010517`, `1010516`, `1010518`, `502148` |
| Interactions | **Taste ID** detects the result (`TasteID.cs:47`); **Arms Lore** shows `1038284` when `PoisonCharges > 0`; **Infectious Strike** weapon ability is the AoS gate for poisoning a weapon (`:69`); poison levels/messages come from `Server/Poison.cs`; `AwardKarma` from `Scripts/Misc/Titles.cs` |
| [ERA] | AoS: only weapons whose `PrimaryAbility`/`SecondaryAbility` is `InfectiousStrike` can be poisoned and the refusal text is `1060204` (`:67-69`, `:88-89`). Pre-AoS: **any one-handed Slashing or Piercing** weapon (`:71-75`) and text `502145` |
| Confidence | `[SRC]` |

**Poison-level-from-skill table (which potion you can apply at which skill)**

| Potion class | `Poison` | `MinPoisoningSkill` | `MaxPoisoningSkill` | Citation |
|---|---|---|---|---|
| `LesserPoisonPotion` | `Poison.Lesser` | `0.0` | `60.0` | `LesserPoisonPotion.cs:22`,`:29`,`:36` |
| `PoisonPotion` | `Poison.Regular` | `30.0` | `70.0` | `PoisonPotion.cs:22`,`:29`,`:36` |
| `GreaterPoisonPotion` | `Poison.Greater` | `60.0` | `100.0` | `GreaterPoisonPotion.cs:22`,`:29`,`:36` |
| `DeadlyPoisonPotion` | `Poison.Deadly` | `80.0` | `100.0` | `DeadlyPoisonPotion.cs:22`,`:29`,`:36` |
| `DarkglowPotion` / `ParasiticPotion` | `Poison.DarkGlow` / `Poison.Parasitic` | declared as overrides at `DarkglowPotion.cs:26`,`:33` and `ParasiticPotion.cs:26`,`:33` — **values not read in this pass** (`[PARTIAL]`; read those two files before transcribing the window) | as cited |
| (no `LethalPoisonPotion` exists in `pub57` — `Poison.Lethal` is spell/monster-only) | — | — | — | `[SRC]` grep of `: BasePoisonPotion` |

**Effective success chance** = `(Poisoning.Value - Min) / (Max - Min)` (`SkillCheck.cs:306`), with the
two short-circuits: `< Min` → automatic fail, `>= Max` → automatic success.

**Poison charges on a weapon** = `18 - (poison.RealLevel * 2)`:

| Poison | `RealLevel` | Charges |
|---|---|---|
| Lesser | 0 | 18 |
| Regular | 1 | 16 |
| Greater | 2 | 14 |
| Deadly | 3 | 12 |
| Lethal | 4 | 10 |

`RealLevel` mapping is `Level` for 0–9, `Level - 10` for 10–13 (Darkglow), `Level - 14` for ≥14
(Parasitic) — `Scripts/Misc/Poison.cs:89-105`.

**Poison damage model (for reference)** — `Scripts/Misc/Poison.cs:21-36`:

| Era | Poison | Level | min | max | scalar (% of target Hits) | delay | interval | count | messageInterval |
|---|---|---|---|---|---|---|---|---|---|
| AoS | Lesser | 0 | 4 | 16 | 7.5 | 3.0 | 2.25 | 10 | 4 |
| AoS | Regular | 1 | 8 | 18 | 10.0 | 3.0 | 3.25 | 10 | 3 |
| AoS | Greater | 2 | 12 | 20 | 15.0 | 3.0 | 4.25 | 10 | 2 |
| AoS | Deadly | 3 | 16 | 30 | 30.0 | 3.0 | 5.25 | 15 | 2 |
| AoS | Lethal | 4 | 20 | 50 | 35.0 | 3.0 | 5.25 | 20 | 2 |
| pre-AoS | Lesser | 0 | 4 | 26 | 2.500 | 3.5 | 3.0 | 10 | 2 |
| pre-AoS | Regular | 1 | 5 | 26 | 3.125 | 3.5 | 3.0 | 10 | 2 |
| pre-AoS | Greater | 2 | 6 | 26 | 6.250 | 3.5 | 3.0 | 10 | 2 |
| pre-AoS | Deadly | 3 | 7 | 26 | 12.500 | 3.5 | 4.0 | 10 | 2 |
| pre-AoS | Lethal | 4 | 9 | 26 | 25.000 | 3.5 | 5.0 | 10 | 2 |
| ML Darkglow | 10–13 | 10–13 | as AoS Lesser..Deadly | | | | | | 4/3/2/2 |
| ML Parasitic | 14–18 | 14–18 | as AoS Lesser..Lethal | | | | | | 4/3/2/2/2 |

Per-tick damage: `damage = 1 + (int)(target.Hits * scalar)`, clamped to `[min, max]`; pre-AoS
re-uses the previous tick's damage 50 % of the time (`Scripts/Misc/Poison.cs:216-230`).
Darkglow ×1.1 when the poisoner is >1 tile away (`:252-256`); Parasitic heals the poisoner when
adjacent (`:258-267`).

---

### 2.14 Meditation

Source: `ServUO:Scripts/Skills/Meditation.cs` (106 lines) + `ServUO:Scripts/Misc/RegenRates.cs` (315 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Meditation.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[46]` (`Meditation.cs:10`); **no target** |
| Target requirements | none; the branch order is the whole behaviour (see below) |
| Skill check window | `m.CheckSkill(SkillName.Meditation, 0.0, 100.0)` (`:86`) — only reached if the **direct chance** roll passes |
| Delay / cooldown | 10.0 s on the normal path (`:102`); 5.0 s if busy (`:38`) or pre-AoS low HP (`:44`); 5.0 s pre-AoS / 10.0 s AoS when already full (`:50`); 10.0 s if AoS armour blocks (`:56`); 2.5 s if hands are full (`:75`) |
| Success outcome | `501851` "You enter a meditative trance."; `m.Meditating = true`; `BuffInfo` `BuffIcon.ActiveMeditation` / `1075657`; sound `0xF9`; `m.ResetStatTimers()` (`:88-95`) |
| Failure outcome | `501850` "You cannot focus your concentration." (`:99`) |
| Resource consumed | none |
| Messages / gumps | `501845` "You are busy doing something else and cannot focus."; `501849` "The mind is strong but the body is weak."; `501846` "You are at peace."; `500135` "Regenative forces cannot penetrate your armor!"; `502626` "Your hands must be free to cast spells or meditate."; `500134` "You stop meditating." (`Server/Mobile.cs:12651`) |
| Interactions | **Focus** synergy in every regen formula; **armour** (`GetArmorOffset`); **Spell Channeling / Mage Armor** properties; `DisruptiveAction()` breaks the trance on any skill use (`Server/Skills.cs:914` → `Server/Mobile.cs:12646-12653`); AoS `CheckOkayHolding` allows `Spellbook`/`Runebook` and (AoS) Spell-Channelling weapons/armour (`Meditation.cs:13-28`) |
| [ERA] | The **entire** mana-regen formula forks on `Core.ML` → `Core.AOS` → pre-AoS (`RegenRates.cs:121`,`:154`,`:179`); pre-AoS low-HP gate exists only `!Core.AOS` (`:40`); the hands-full behaviour differs (AoS auto-stows items, pre-AoS refuses) (`:63-76`) |
| Confidence | `[SRC]` |

**Branch order and the trance chance**

| Step | Condition | Result |
|---|---|---|
| 1 | `m.Target != null` | `501845`, 5.0 s |
| 2 | `!Core.AOS && m.Hits < (m.HitsMax / 10)` | `501849`, 5.0 s |
| 3 | `m.Mana >= m.ManaMax` | `501846`, `Core.AOS ? 10.0 : 5.0` s |
| 4 | `Core.AOS && RegenRates.GetArmorOffset(m) > 0` | `500135`, 10.0 s |
| 5 | AoS player with a non-allowed item in `Layer.OneHanded`/`TwoHanded` | item is moved to the backpack (no penalty) |
| 6 | pre-AoS and either hand holds a disallowed item | `502626`, 2.5 s |
| 7 | **trance chance** `chance = (50.0 + ((skillVal - (m.ManaMax - m.Mana)) * 2)) / 100` where `skillVal = Skills[Meditation].Value` | if `chance > Utility.RandomDouble()` → success path; else `501850`; **always 10.0 s** |

`[SRC]` — `Meditation.cs:34-103`. The chance formula is `:79`; `CrystalBallOfKnowledge.TellSkillDifficultyActive` is fed the raw chance (`:82`).

**Armour malus (`GetArmorOffset`)** — `RegenRates.cs:36-51`, `:298-313`:

| Step | Rule |
|---|---|
| Slots summed | shield **only when `!Core.AOS`**, then Neck, Gloves, Helm, Arms, Legs, Chest |
| Per-piece (`GetArmorMeditationValue`) | `MageArmor != 0` **or** `SpellChanneling != 0` → `0.0`; `MeditationAllowance.None` → `BaseArmorRatingScaled`; `.Half` → `BaseArmorRatingScaled / 2.0`; `.All` → `0.0` |
| Total | `return rating / 4` |

**Mana regeneration rate — exact code, all three eras** (`RegenRates.cs:110-209`; the returned value
is a `TimeSpan` = seconds **per mana point**, so smaller = faster):

Pre-AoS (`:179-201`):
```
medPoints = (Int + Meditation.Value) * 0.5
if medPoints <= 0        rate = 7.0
else if medPoints <= 100 rate = 7.0 - (239 * medPoints / 2400) + (19 * medPoints * medPoints / 48000)
else if medPoints < 120  rate = 1.0
else                     rate = 0.75
rate += armorPenalty
if Meditating  rate *= 0.5
clamp rate to [0.5, 7.0]
```

AoS (`:154-178`):
```
medPoints = Int + (Meditation.Value * 3)
medPoints *= (Meditation.Value < 100.0) ? 0.025 : 0.0275
focusPoints = Focus.Value * 0.05
if armorPenalty > 0  medPoints = 0            // any blocking armour removes the meditation bonus entirely
totalPoints = focusPoints + medPoints + (Meditating ? min(medPoints, 13.0) : 0.0)
totalPoints += ManaRegen(from)                // item property + creature base + form bonuses
if totalPoints < -1  totalPoints = -1
rate = 1.0 / (0.1 * (2 + totalPoints))
```

ML (`:121-153`):
```
focusBonus = Focus.Value / 200
if armorPenalty == 0:
    medBonus = (0.0075 * Meditation.Value) + (0.0025 * Int)
    if medBonus >= 100.0  medBonus *= 1.1
    if Meditating         medBonus *= 2
itemBase     = ((((Meditation.Value / 2) + (Focus.Value / 4)) / 90) * .65) + 2.35
intensity    = min(sqrt(ManaRegen(from)), 5.5)
itemBonus    = ((itemBase * intensity) - (itemBase - 1)) / 10
rate = 1.0 / (0.2 + focusBonus + medBonus + itemBonus)
```

| Supporting constant | Value | Citation |
|---|---|---|
| `Mobile.DefaultManaRate` | 7.0 s | `RegenRates.cs:25` |
| Passive gain while **not** meditating | `CheckBonusSkill(from, from.Mana, from.ManaMax, SkillName.Meditation)` → `CheckSkill(Meditation, n)` where `n = (Mana/ManaMax) * (1 - sqrt(Meditation*0.005)) + sqrt(Meditation*0.005)` | `:115-116`, `:53-65` |
| `ManaRegen(from)` item/creature points | `AosAttributes.GetValue(RegenMana)` + creature `DefaultManaRegen` + Vampiric Embrace `+3` / Lich Form `+13` + gargoyle `+2`; capped at 18 (`!Core.ML`) | `:274-296` |
| NaN guard | any NaN rate → `DefaultManaRate` | `:203-206` |

`[SRC]` for every expression above. `[ERA]`: pre-AoS has **no** Focus term at all (Focus is an AoS
skill) — the AoS/ML branches add it. `[PARTIAL]`: the classic retail "meditation must be re-toggled"
behaviour is not modelled; the trance is a server flag cleared by `DisruptiveAction`.

---

### 2.15 Spirit Speak

Source: `ServUO:Scripts/Skills/SpiritSpeak.cs` (242 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/SpiritSpeak.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[32]` (`:17`); **no target** |
| Target requirements | none by cursor. AoS path scans `Caster.GetObjectsInRange(3)` for a `Corpse` that is `!Channeled && !Animated` — first match wins (`:163-171`) |
| Skill check window | AoS: `CheckSkill(SpiritSpeak, 0.0, 120.0)` (`:209`). pre-AoS: `CheckSkill(SpiritSpeak, 0, 100)` (`:40`) |
| Delay / cooldown | AoS: 5.0 s (`:32`), or 0 if already in a trance/casting (`:35`). pre-AoS: 1.0 s (`:66`) |
| Success outcome | AoS: heals `Utility.RandomMinMax(min, max)` with `min = 1 + (int)(Value * 0.25)`, `max = min + 4` (`:190-197`, `:231`); corpse is marked `Channeled = true` and hued `0x835` (`:219-220`); particles `0x375A` layer Waist (`:233`). pre-AoS: `CanHearGhosts = true` for 15 s–3 min (`:42-58`) |
| Failure outcome | AoS: `502443` "You fail your attempt at contacting the netherworld." (`:213`). Not enough mana: `1061285` "You lack the mana required to use this skill." (`:205`). pre-AoS: `502443` + `CanHearGhosts = false` (`:62-63`) |
| Resource consumed | AoS: **10 mana** if no corpse in range (`:199`), **0 mana** if a corpse is in range (`:193`); the corpse is "spent" (`Channeled = true`) |
| Messages / gumps | `1062074` "Anh Mi Sah Ko" (overhead, `:94`); `1061287` "You channel energy from a nearby corpse to heal your wounds."; `1061286` "You channel your own spiritual energy to heal your wounds."; `502444` "You contact the neitherworld."; `502443`; `502445` "You feel your contact with the neitherworld fading."; `502642` "You are already casting a spell."; `500641` "Your concentration is disturbed, thus ruining thy spell." |
| Interactions | **Necromancy** — Spirit Speak *is* the damage skill of every necromancy spell (`Scripts/Spells/Necromancy/NecromancerSpell.cs:26`); it gates familiar strength (`SummonFamiliar.cs:181`,`:209`), `AnimateDead` (`AnimateDeadSpell.cs:330`), `Strangle` (`:120`,`:179`), `Evil Omen` duration (`EvilOmen.cs:132`), `Curse Weapon` duration (`CurseWeapon.cs:67`), `Revenant` summon scalar (`Revenant.cs:22`); **ghost speech** — see below; **Skill Masteries** `Conduit` (`Scripts/Spells/Skill Masteries/Conduit.cs:30`) and `Command Undead` (`CommandUndead.cs:27`) declare `DamageSkill = SpiritSpeak` |
| [ERA] | `Core.AOS` completely replaces the skill: the pre-AoS "hear ghosts for a while" path is dead on AoS+ (`:24-36` returns before it). The trance heal (self-heal from a corpse) is the AoS+ behaviour. `Core.ML && SpiritSpeak >= 100.0` lets a **dead** player speak normally (`PlayerMobile.cs:4223`) |
| Confidence | `[SRC]` |

**AoS trance timer (1 s, one shot)** — `SpiritSpeakTimerNew` (`:148-240`):

| Step | Literal | Citation |
|---|---|---|
| Freeze on begin | `m.Freeze(TimeSpan.FromSeconds(1))`, `Animate(AnimationType.Spell, 1)`, sound `0x24A` | `:91-95` |
| Re-entry guard | `_Table.ContainsKey(m)` → `BeginSpiritSpeak` returns false, no mana spent | `:89`, `:104` |
| min/max heal | `min = 1 + (int)(Value * 0.25)`; `max = min + 4` (0 skill → 1..5; 100 → 26..30; 120 → 31..35) | `:190-191`, `:197-198` |
| Mana cost | `0` with corpse, `10` without | `:193`, `:199` |
| Failure roll | `if (Utility.RandomDouble() > (Value / 100.0))` → fail ⇒ **success probability = SpiritSpeak.Value / 100** (0 % at 0, 100 % at ≥100) | `:211` |
| Heal clamp | `if (min > max) min = max;` then `Caster.Hits += RandomMinMax(min, max)` | `:226-231` |
| Disruption | on damage: `500641`, effect `0x3735`/`0x5C`, `NextSkillTime = Core.TickCount`, trance removed | `:127-146` |

**pre-AoS "hear ghosts" duration** — `secs = (SpiritSpeak.Base / 50) * 90`, floored at 15 s
(`:45-52`) ⇒ **15 s at ≤8.3 skill, 90 s at 50, 180 s at 100, 216 s at 120** (the timer's declared
default of 2 min at `:74` is overwritten by `t.Delay = …` at `:52`).

**Speak-with-the-dead behaviour**

| Rule | Code | Citation |
|---|---|---|
| A living mobile hears ghost speech only if `CanHearGhosts` | `CheckHearsMutatedSpeech`: `return (m.Alive && !m.CanHearGhosts)` | `Server/Mobile.cs:4956-4964` |
| `CanHearGhosts` source | `m_CanHearGhosts \|\| IsStaff()` | `Server/Mobile.cs:12798` |
| Dead player's own speech is not mutated (i.e. everyone hears it normally) if `Core.ML && SpiritSpeak >= 100.0` | `PlayerMobile.MutateSpeech` | `PlayerMobile.cs:4223-4226` |
| On AoS, a **hearer** with `SpiritSpeak >= 100.0` un-mutates the ghost's speech | `PlayerMobile.cs:4228-4239` | as cited |
| pre-AoS | no 100-skill exemption; instead `CanHearGhosts` is the only channel | `SpiritSpeak.cs:38-66` |

`[SRC]`. `[ERA]` summary: pre-AoS = timed `CanHearGhosts` buff, 100-skill exemption absent;
AoS = corpse-channel self-heal, ghost speech still gated on the flag; ML = 100 Spirit Speak grants
permanent ghost speech.

---

### 2.16 Animal Taming

Source: `ServUO:Scripts/Skills/AnimalTaming.cs` (490 lines) + `Scripts/Mobiles/Normal/BaseCreature.cs` · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/AnimalTaming.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:31`) + `RevealingAction` (`:36`) → `502789` "Tame which animal?"; the target is installed via `Timer.DelayCall` when `DeferredTarget` (default `true`, `:25`, `:43-50`) |
| Target requirements | `Target(Core.AOS ? 3 : 2, false, TargetFlags.None)` with a **30 s** `BeginTimeout` (`:122-126`) |
| Skill check window | `CheckTargetSkill(AnimalTaming, m_Creature, minSkill - 25.0, minSkill + 25.0)` where `minSkill = CurrentTameSkill + Owners.Count * 6.0`, then `minSkill += 24.9` (`:402-413`) |
| Delay / cooldown | 40.0 s from the callback (`:53`); the target attempt itself suppresses the `NextSkillTime` reset (`m_SetSkillTime = false`, `:240`) so the 40 s survives a successful start. Every abort path explicitly writes `NextSkillTime = Core.TickCount` (`:298`,`:306`,`:314`,`:322`,`:330`,`:338`,`:346`,`:354`,`:389`) |
| Success outcome | Creature scaled (table below), `SetControlMaster(tamer)`, `IsBonded = false`, `Owners.Add(tamer)`, `OnAfterTame`, `PetTrainingHelper…OnTame()`, `EventSink.InvokeTameCreature` (`:437-459`); `502799` "It seems to accept you as master." — or `502797` "That wasn't even challenging." for an already-owned pet (`:439-444`) |
| Failure outcome | `502798` "You fail to tame the creature." (`:464`); the creature keeps its tame difficulty and the tame skill is rolled again on the next attempt |
| Resource consumed | none (no item); the attempt occupies the 40 s skill timer |
| Messages / gumps | `502789`, `1010597` "You start to tame the creature." (local) + `1010598` "*begins taming a creature.*" (nonlocal) (`:244-245`); the mid-tame chatter set `502790+0..3`, `1005608+0..5`, `1010593+0..3` (`:363-374`); aborts `502795` too far, `502796` dead, `1049654` no path, `1049655` not tamable, `502804` already tame, `1005615` too many owners, `1054025` must subdue, `502794` too angry, `502802` someone else is taming, `502805` "You seem to anger the beast!", `502806` no chance, `1049653`/`1049652` gender-locked, `502801` can't tame that, `1049611` too many followers, `1042590` faction mismatch |
| Interactions | **Animal Lore** gains passively on every tick and on the final roll (`:376-379`, `:397-400`); **Necromancy** `DarkWolfFamiliar.CheckMastery` sets the required skill to −24.9 (i.e. success at 0.0) (`:184`, `:403-410`); **Bard** pacification is cancelled on anger (`:212-224`); **Honor** / Spellweaving `Ethereal Voyage` suppress the aggro response (`:231-236`); Followers/`FollowersMax` gate (`:170-173`) |
| [ERA] | Target range 2 pre-AoS / 3 AoS (`:123`); tame **range to continue** 6 pre-AoS / 7 AoS (`:295`); `Core.SA` skips the bard-pacify juggling (`:212`); `Core.TOL` changes skill scaling (`:104`); `Core.SE` `MaxOwners` (`:174`); rideable-creature subdue rules |
| Confidence | `[SRC]` |

**Pre-flight rejections (`OnTarget`, `:140-266`)**

| Order | Condition | Message | Citation |
|---|---|---|---|
| 1 | `!creature.Tamable` (i.e. `m_bTamable == false` **or Paragon**, `BaseCreature.cs:3818`) | `1049655` "That creature cannot be tamed." | `:146-150` |
| 2 | `creature.Controlled` | `502804` "That animal looks tame already." | `:151-155` |
| 3 | `from.Female && !creature.AllowFemaleTamer` | `1049653` "…can only be tamed by males." | `:156-160` |
| 4 | `!from.Female && !creature.AllowMaleTamer` | `1049652` "…can only be tamed by females." | `:161-165` |
| 5 | `creature is CuSidhe && from.Race != Race.Elf` | `502801` "You can't tame that!" | `:166-169` |
| 6 | `from.Followers + creature.ControlSlots > from.FollowersMax` | `1049611` "You have too many followers to tame that creature." | `:170-173` |
| 7 | `Owners.Count >= BaseCreature.MaxOwners` (5) and not already an owner | `1005615` "This animal has had too many owners…" | `:174-178` |
| 8 | `MustBeSubdued(creature)` | `1054025` "You must subdue this creature before you can tame it!" | `:179-183` |
| 9 | `Taming.Value < creature.CurrentTameSkill` and no necro mastery | `502806` "You have no chance of taming this creature." | `:184`, `:250-254` |
| 10 | `FactionWarHorse` with wrong/absent faction | `1042590` "You cannot tame this creature." | `:186-198` |
| 11 | already in `m_BeingTamed` | `502802` "Someone else is already taming this." | `:200-204` |
| 12 | `CanAngerOnTame && 0.95 >= RandomDouble()` | `502805` "You seem to anger the beast!" + aggro (see below) | `:205-237` |
| 13 | non-`BaseCreature` Mobile | `502469` "That being cannot be tamed." | `:256-260` |
| 14 | not a Mobile | `502801` | `:262-265` |

`MustBeSubdued` = `Owners.Count == 0 && SubdueBeforeTame && Hits > (HitsMax / 10)` (`:56-63`).
`CanAngerOnTame` defaults `false` (`BaseCreature.cs:3287`) and is overridden `true` by BloodFox,
ColdDrake, CuSidhe, Dragon, DragonWolf, DreadSpider, DreadWarhorse, FrostDragon, FrostMite,
GreaterDragon, Hiryu, LesserHiryu, Lion, Nightmare, OsseinRam, Phoenix, Reptalon, RuneBeetle,
SabertoothedTiger, SerpentineDragon, ShadowWyrm, Skree, StygianDrake, SwampDragon, Triceratops,
TsukiWolf, WhiteWyrm.
`SubdueBeforeTame` is `true` for Beetle, FireBeetle, GiantIceWorm, IronBeetle (5–10 % HP first).

**Taming timer** (`InternalTimer`, `:268-487`)

| Element | Literal | Citation |
|---|---|---|
| Timer | `base(TimeSpan.FromSeconds(3.0), TimeSpan.FromSeconds(3.0), count)` — one roll window every 3 s | `:278` |
| `count` | `Utility.Random(3, 2)` ⇒ **3 or 4** (never 2) ⇒ total attempt 9–12 s | `:247`, `Utility.cs:905` |
| Range | `m_Tamer.InRange(m_Creature, Core.AOS ? 7 : 6)` | `:295` |
| Chatter | `Utility.Random(3)` selects one of three overhead banks; each bank id is `Random(base, count)` | `:363-374` |
| Passive Animal Lore | `if (!alreadyOwned) CheckTargetSkill(AnimalLore, creature, 0.0, 120.0)` on every tick and once at the end | `:376-379`, `:397-400` |
| Final window | `minSkill = CurrentTameSkill + (Owners.Count * 6.0)`; if necro mastery and `minSkill > -24.9` → `minSkill = -24.9`; then `minSkill += 24.9` ⇒ a **50-point-wide window centred on the adjusted requirement** | `:402-413` |

**Re-tame / ownership scaling** — the `minSkill` used for the roll includes
`Owners.Count * 6.0`, i.e. **each previous owner adds +6.0 to the effective taming requirement**
(`:402`; also `BaseCreature.MaxOwners = 5` at `:1176`, so up to +24.0).

**Stat/skill scaling applied on a successful tame** (`:415-435`, `ScaleStats :65-93`, `ScaleSkills :95-116`):

| Case | Scalar | Citation |
|---|---|---|
| `GreaterDragon`, first tame | `ScaleSkills(0.72, capScalar 0.90, firstTame)` + `Magery.Base = Magery.Cap` | `:417-422` |
| Creature was paralyzed at any tick and this is the first tame | `ScaleSkills(0.86, true)` | `:423-426` |
| Otherwise first tame | `ScaleSkills(0.90, true)` | `:427-430` |
| Re-tame (already in `Owners`) | `ScaleSkills(0.90, false)` | `:432-435` |
| Effect on stats | `RawStr/RawDex/RawInt/HitsMaxSeed/StamMaxSeed *= scalar`, each floored at 1 | `:65-93` |
| Effect on skills | `Cap = max(100.0, Base * capScalar)` then `Base *= scalar`; if `Base > Cap` then `Cap = Base` | `:100-116` |

**Tame difficulty / control slots / mount flag per creature** — `[SRC]`, one row per creature that
sets `MinTameSkill` in `Scripts/Mobiles/Normal` (default `ControlSlots = 1`,
`BaseCreature.cs:281`; "Mount" = the class is declared `: BaseMount`). All `MinTameSkill` values are
`<file>.cs:<line>` with line numbers from the grep of `MinTameSkill\s*=`; `ControlSlots` line
numbers are from the grep of `ControlSlots\s*=` in the same folder.

| Creature | MinTameSkill | ControlSlots | Mount | Source |
|---|---|---|---|---|
| Dog | −21.3 | 1 | — | `Dog.cs:41`, `:40` |
| Ferret | −21.3 | 1 | — | `Ferret.cs:45`, `:44` |
| Squirrel | −21.3 | 1 | — | `Squirrel.cs:37`, `:36` |
| Gorilla | −18.9 | 1 | — | `Gorilla.cs:42`, `:41` |
| JackRabbit | −18.9 | 1 | — | `JackRabbit.cs:41`, `:40` |
| Mongbat | −18.9 | 1 | — | `Mongbat.cs:40`, `:39` |
| Rabbit | −18.9 | 1 | — | `Rabbit.cs:42`, `:41` |
| SkitteringHopper | −12.9 | 1 | — | `SkitteringHopper.cs:39`, `:38` |
| Bird | −6.9 | 1 | — | `Bird.cs:57`/`:138`, `:56`/`:137` |
| Cat | −0.9 | 1 | — | `Cat.cs:43`, `:42` |
| Chicken | −0.9 | 1 | — | `Chicken.cs:40`, `:39` |
| ClanRibbonPlagueRat | −0.9 | 1 | — | `ClanRibbonPlagueRat.cs:46`, `:45` |
| MountainGoat | −0.9 | 1 | — | `MountainGoat.cs:44`, `:43` |
| Rat | −0.9 | 1 | — | `Rat.cs:41`, `:40` |
| SewerRat | −0.9 | 1 | — | `SewerRat.cs:42`, `:41` |
| Turkey | −0.9 | 1 | — | `Turkey.cs:46`, `:45` |
| BattleChickenLizard | 0.0 | 1 | — | `BattleChickenLizard.cs:34`, `:33` |
| ChickenLizard | 0.0 | 1 | — | `ChickenLizard.cs:42`, `:41` |
| HungryCoconutCrab | 0.0 | 1 | — | `HungryCoconutCrab.cs:90`, `:89` |
| ThirdDawnParrot | 0.0 | 1 | — | `ThirdDawnParrot.cs:27`, `:26` |
| SkeletalMount | 0.0 (deserialization only) | 0 | yes | `SkeletalMount.cs:80`, `:81` |
| Cow | 11.1 | 1 | — | `Cow.cs:42`, `:41` |
| Goat | 11.1 | 1 | — | `Goat.cs:40`, `:39` |
| Pig | 11.1 | 1 | — | `Pig.cs:40`, `:39` |
| Sheep | 11.1 | 1 | — | `Sheep.cs:44`, `:43` |
| Eagle | 17.1 | 1 | — | `Eagle.cs:44`, `:43` |
| LowlandBoura | 19.1 | 3 | — | `LowlandBoura.cs:41`, `:40` |
| RuddyBoura | 19.1 | 2 | — | `RuddyBoura.cs:43`, `:42` |
| BullFrog | 23.1 | 1 | — | `BullFrog.cs:42`, `:41` |
| CorrosiveSlime | 23.1 | 1 | — | `CorrosiveSlime.cs:45`, `:44` |
| Hind | 23.1 | 1 | — | `Hind.cs:40`, `:39` |
| Slime | 23.1 | 1 | — | `Slime.cs:43`, `:42` |
| TimberWolf | 23.1 | 1 | — | `TimberWolf.cs:45`, `:44` |
| Beetle | 29.1 (98.7 after ToL upgrade, `:220`) | 3 → 1 | yes | `Beetle.cs:69`, `:68`/`:222` |
| Boar | 29.1 | 1 | — | `Boar.cs:42`, `:41` |
| DesertOstard | 29.1 | 1 | yes | `DesertOstard.cs:43`, `:42` |
| ForestOstard | 29.1 | 1 | yes | `ForestOstard.cs:44`, `:43` |
| GiantRat | 29.1 | 1 | — | `GiantRat.cs:43`, `:42` |
| Horse | 29.1 | 1 | yes | `Horse.cs:54`, `:53` |
| PackHorse | 29.1 | 1 | — | `PackHorse.cs:48`, `:47` |
| PackLlama | 29.1 | 1 | — | `PackLlama.cs:48`, `:47` |
| PalaminoHorse | 29.1 | 1 | yes | `PalaminoHorse.cs:41`, `:40` |
| RidableLlama | 29.1 | 1 | yes | `RidableLlama.cs:46`, `:45` |
| CoconutCrab | 30.0 | 1 | yes | `CoconutCrab.cs:85`, `:84` |
| Eowmu | 30.0 | 1 | yes | `Eowmu.cs:85`, `:84` |
| SkeletalCat | 30.0 | 2 | yes | `SkeletalCat.cs:85`, `:84` |
| BlackBear | 35.1 | 1 | — | `BlackBear.cs:43`, `:42` |
| Llama | 35.1 | 1 | — | `Llama.cs:40`, `:39` |
| PolarBear | 35.1 | 1 | — | `PolarBear.cs:44`, `:43` |
| Walrus | 35.1 | 1 | — | `Walrus.cs:44`, `:43` |
| BrownBear | 41.1 | 1 | — | `BrownBear.cs:42`, `:41` |
| Cougar | 41.1 | 1 | — | `Cougar.cs:43`, `:42` |
| DeathWatchBeetle | 41.1 | 1 | — | `DeathWatchBeetle.cs:68`, `:69` |
| Alligator | 47.1 | 1 | — | `Alligator.cs:43`, `:42` |
| HighPlainsBoura | 47.1 | 3 | — | `HighPlainsBoura.cs:42`, `:41` |
| Scorpion | 47.1 | 1 | — | `Scorpion.cs:47`, `:46` |
| GreyWolf | 53.1 | 1 | — | `GreyWolf.cs:45`, `:44` |
| Panther | 53.1 | 1 | — | `Panther.cs:44`, `:43` |
| SnowLeopard | 53.1 | 1 | — | `SnowLeopard.cs:45`, `:44` |
| CoralSnake | 59.1 | 1 | — | `CoralSnake.cs:47`, `:46` |
| GiantSpider | 59.1 | 1 | — | `GiantSpider.cs:43`, `:42` |
| GreatHart | 59.1 | 1 | — | `GreatHart.cs:41`, `:40` |
| GrizzlyBear | 59.1 | 1 | — | `GrizzlyBear.cs:44`, `:43` |
| Snake | 59.1 | 1 | — | `Snake.cs:43`, `:42` |
| WolfSpider | 59.1 | 2 | — | `WolfSpider.cs:46`, `:45` |
| StoneSlith | 65.1 | 2 | — | `StoneSlith.cs:41`, `:40` |
| WhiteWolf | 65.1 | 1 | — | `WhiteWolf.cs:45`, `:44` |
| Gaman | 68.7 | 1 | — | `Gaman.cs:42`, `:41` |
| Bull | 71.1 | 1 | — | `Bull.cs:44`, `:43` |
| GiantIceWorm | 71.1 | 1 | — | `GiantIceWorm.cs:45`, `:44` |
| GreaterMongbat | 71.1 | 1 | — | `GreaterMongbat.cs:42`, `:41` |
| HellCat | 71.1 | 1 | — | `HellCat.cs:47`, `:46` |
| IronBeetle | 71.1 | 4 | — | `IronBeetle.cs:49`, `:50` |
| StrongMongbat | 71.1 | 1 | — | `StrongMongbat.cs:40`, `:39` |
| BloodFox | 72.0 | 2 | — | `BloodFox.cs:39`, `:38` |
| OsseinRam | 72.0 | 2 | — | `OsseinRam.cs:44`, `:43` |
| FrostSpider | 74.7 | 1 | — | `FrostSpider.cs:49`, `:48` |
| FrenziedOstard | 77.1 | 1 | yes | `FrenziedOstard.cs:47`, `:46` |
| GiantToad | 77.1 | 1 | — | `GiantToad.cs:43`, `:42` |
| BakeKitsune | 80.7 | 2 | — | `BakeKitsune.cs:45`, `:44` |
| LavaLizard | 80.7 | 1 | — | `LavaLizard.cs:46`, `:45` |
| Slith | 80.7 | 1 | — | `Slith.cs:35`, `:34` |
| DireWolf | 83.1 | 1 | — | `DireWolf.cs:47`, `:46` |
| Imp | 83.1 | 2 | — | `Imp.cs:66`, `:65` |
| Ridgeback | 83.1 | 1 | yes | `Ridgeback.cs:46`, `:45` |
| SavageRidgeback | 83.1 | 1 | yes | `SavageRidgeback.cs:46`, `:45` |
| Drake | 84.3 | 2 | — | `Drake.cs:44`, `:43` |
| CrimsonDrake | 85.0 | 2 | — | `CrimsonDrake.cs:88`, `:87` |
| PlatinumDrake | 85.0 | 2 | — | `PlatinumDrake.cs:88`, `:87` |
| StygianDrake | 85.0 | 4 | — | `StygianDrake.cs:48`, `:47` |
| HellHound | 85.5 | 1 | — | `HellHound.cs:47`, `:46` |
| Icehound | 85.5 | 1 | — | `Icehound.cs:43`, `:42` |
| PredatorHellCat | 90.0 | 2 | — | `PredatorHellCat.cs:47`, `:46` |
| Dragon | 93.9 | 3 | — | `Dragon.cs:45`, `:44` |
| FireBeetle | 93.9 (98.7 post-ToL, `:188`) | 3 → 1 | yes | `FireBeetle.cs:40`, `:39`/`:190` |
| RuneBeetle | 93.9 | 3 | — | `RuneBeetle.cs:54`, `:53` |
| ScaledSwampDragon | 93.9 | 1 | yes | `ScaledSwampDragon.cs:45`, `:44` |
| SwampDragon | 93.9 | 1 | yes | `SwampDragon.cs:56`, `:55` |
| Kirin | 95.1 | 2 | yes | `Kirin.cs:53`, `:52` |
| Nightmare | 95.1 | 2 | yes | `Nightmare.cs:52`, `:51` |
| Skree | 95.1 | 4 | — | `Skree.cs:44`, `:43` |
| Unicorn | 95.1 | 2 | yes | `Unicorn.cs:50`, `:49` |
| WildTiger | 95.1 | 2 | yes | `WildTiger.cs:61`, `:60` |
| ColdDrake | 96.0 | 3 | — | `ColdDrake.cs:49`, `:48` |
| DreadSpider | 96.0 | 3 | — | `DreadSpider.cs:54`, `:53` |
| Lion | 96.0 | 2 | — | `Lion.cs:46`, `:45` |
| Triton | 96.0 | 2 | — | `Triton.cs:106`, `:105` |
| TsukiWolf | 96.0 | 3 | — | `TsukiWolf.cs:65`, `:64` |
| WhiteWyrm | 96.3 | 3 | — | `WhiteWyrm.cs:48`, `:47` |
| Hiryu | 98.7 | 4 | yes | `Hiryu.cs:43`, `:42` |
| LesserHiryu | 98.7 | 3 → 1 | yes | `LesserHiryu.cs:43`, `:42`/`:226` |
| CuSidhe | 101.1 | 4 | yes | `CuSidhe.cs:59`, `:58` |
| Reptalon | 101.1 | 4 | yes | `Reptalon.cs:40`, `:39` |
| DragonWolf | 102.0 | 4 | — | `DragonWolf.cs:43`, `:42` |
| FrostMite | 102.0 | 3 | — | `FrostMite.cs:42`, `:41` |
| Phoenix | 102.0 | 4 | — | `Phoenix.cs:47`, `:46` |
| SabertoothedTiger | 102.0 | 2 | — | `SabertoothedTiger.cs:46`, `:45` |
| Triceratops | 102.0 | 3 | — | `Triceratops.cs:44`, `:43` |
| SilverSteed | 103.1 | 1 | yes | `SilverSteed.cs:25`, `:23` |
| GreaterDragon | 104.7 | 5 | — | `GreaterDragon.cs:49`, `:48` |
| FrostDragon | 105.0 | 5 | — | `FrostDragon.cs:50`, `:49` |
| ShadowWyrm | 105.0 | 5 | — | `ShadowWyrm.cs:50`, `:49` |
| FireSteed | 106.0 | 2 | yes | `FireSteed.cs:48`, `:47` |
| Raptor | 107.1 | 2 | — | `Raptor.cs:55`, `:56` |
| DreadWarhorse | 108.0 | 3 | yes | `DreadWarhorse.cs:54`, `:53` |
| SerpentineDragon | 108.0 | 3 | — | `SerpentineDragon.cs:51`, `:50` |
| BaneDragon (event) | 107.1 | 3 | — | `Scripts/Mobiles/Event/BaneDragon.cs:70`, `:69` |
| FactionWarHorse | 29.1 | 1 | — | `Scripts/Mobiles/Factions/BaseWarHorse.cs:41`, `:40` |
| GargoylePet (summon) | 65.1 | 2 | — | `Scripts/Mobiles/Summons/GargoylePet.cs:37`, `:36` |

Minimum tameable = **−21.3** (Dog/Ferret/Squirrel) and maximum requirement is clamped by
`BaseCreature.MaxTameRequirement = 108.0` (`BaseCreature.cs:575`).

**`CurrentTameSkill` vs `MinTameSkill` (pet training)**

| Rule | Code | Citation |
|---|---|---|
| Default | `CurrentTameSkill = MinTameSkill` when `ControlSlots <= ControlSlotsMin` | `BaseCreature.cs:741-744` |
| Above-minimum slots | `CurrentTameSkill = ((ControlSlots - ControlSlotsMin) * 21) + 1` | `:747` |
| Clamp | `if (CurrentTameSkill > MaxTameRequirement) CurrentTameSkill = MaxTameRequirement` (108.0) | `:750-753` |
| Applied | on world load when `Tamable && CurrentTameSkill == 0` | `:3013-3016` |
| `MinTameSkill` setter keeps the delta | `adjusted = CurrentTameSkill - old; CurrentTameSkill = adjusted > 0 ? value + adjusted : value` | `:3790-3812` |

**Loyalty / obedience rules**

| Rule | Literal | Citation |
|---|---|---|
| Loyalty range | `MaxLoyalty = 100`, stored value clamped `0..100` | `BaseCreature.cs:204`, `:1727` |
| On a fresh tame | `Loyalty = MaxLoyalty` | `:2376`, `:7987` |
| Successful command | `Loyalty += 1` | `:1490` |
| Failed command | `Loyalty -= 3` + anger sound + animation | `:1505` |
| Decay | `LoyaltyTimer` internal delay **5 min** but the body only runs once per hour (`m_NextHourlyCheck = now + 1 h`, early-return otherwise); each run: `Loyalty -= (MaxLoyalty / 10)` = **−10/hour** for every controlled, commandable pet on a map | `:7870-7893`, `:7944` |
| Warning | when `Loyalty < 10`: `1043270` "* ~1_NAME~ looks around desperately *" | `:7946-7950` |
| Release | `Loyalty <= 0` → `toRelease`, then `1043255` "~1_NAME~ appears to have decided that is better off without a master!", `Loyalty = MaxLoyalty`, `IsBonded = false`, `BondingBegin = MinValue` | `:7952-7989` |
| Mounted pets exempt | `if (m is BaseMount && ((BaseMount)m).Rider != null) OwnerAbandonTime = MinValue` (skips the decay branch) | `:7908-7911` |
| Control chance | `GetControlChance(m)` | `:1519-1588` |

**`GetControlChance` exactly as coded** (`:1519-1588`):

```
if (CurrentTameSkill <= 29.1 || Summoned || AccessLevel >= GM) return 1.0
dMin = CurrentTameSkill; if (dMin > -24.9 && DarkWolfFamiliar.CheckMastery(m, this)) dMin = -24.9
taming = (int)(Taming.Value * 10); lore = (int)(AnimalLore.Value * 10)
chance = 700
if (Core.ML):
    SkillBonus = taming - (int)(dMin*10);  LoreBonus = lore - (int)(dMin*10)
    SkillMod = SkillBonus < 0 ? 28 : 6;    LoreMod = LoreBonus < 0 ? 14 : 6
    bonus = ((SkillBonus*SkillMod) + (LoreBonus*LoreMod)) / 2
else:
    weighted = ((taming*4) + lore) / 5;  bonus = weighted - (int)(dMin*10)
    bonus *= (bonus <= 0 ? 14 : 6)
chance += bonus
if (chance >= 0 && chance < 200) chance = 200
else if (chance > 990) chance = 990
chance -= (MaxLoyalty - Loyalty) * 10
return chance / 1000.0
```

`[SRC]`. `[PARTIAL]`: the exact **skill-gain** that "you fail to tame" produces is not a separate
path — the final failure branch only prints `502798` and returns; the gain comes from
`CheckTargetSkill` itself (`SkillCheck.cs:240-259`). `[UNVERIFIED]`: the retail break-out of
"you fail to tame" vs "you anger the beast" probabilities cannot be derived from a single file —
measure over N≥1000 tame attempts per creature type.

---

### 2.17 Inscription (skill-use side only)

Source: `ServUO:Scripts/Skills/Inscribe.cs` (171 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Inscribe.cs · **scroll scribing belongs to section 4d**

| Field | Value |
|---|---|
| Trigger | Skill button (`:13`) → `1046295` "Target the book you wish to copy."; 1.0 s |
| Target requirements | Stage 1 `Target(3, false, TargetFlags.None)` = source `BaseBook` (`:78`); stage 2 `Target(3, false, TargetFlags.None)` = destination book (`:122`). **Both stages time out after 1 minute** (`:21`, `:96`) |
| Skill check window | `CheckTargetSkill(Inscribe, bookDst, 0, 50)` (`:145`) — deliberately capped at 50, so a 100-skill scribe always auto-succeeds (`value >= maxSkill → true`, `SkillCheck.cs:150`) |
| Delay / cooldown | 1.0 s (`:23`) |
| Success outcome | Title, author and page lines copied (`Copy`, `:44-62`); `501618` "You make a copy of the book."; sound `0x249` (`:147-150`) |
| Failure outcome | `501617` "You fail to make a copy of the book." (`:154`) |
| Resource consumed | none coded (no blank scroll, no mana) — the copy is a straight text copy onto an existing writable book |
| Messages / gumps | `501611` "Can't copy an empty book."; `501621` "Someone else is inscribing that item."; `501612` "Select a book to copy this to."; `501616` "Cannot copy a book onto itself."; `501614` "Cannot write into that book."; `1046296` "That is not a book"; `501619` timeout |
| Interactions | `Server.Engines.Khaldun.MysteriousBook.OnInscribeTarget` short-circuit (`:100-103`); **Magery** uses Inscribe for scroll-cast bonuses (scribe damage bonus `Spell.cs:224-225`, `Protection`/`Reactive Armor`/`Magic Reflect` use `Inscribe/20`, and casting focus uses `Inscribe >= 50` → `Spell.cs:277`); scroll scribing itself is the craft system |
| [ERA] | `Core.SA`-era Khaldun hook; the per-book copy behaviour is era-neutral |
| Confidence | `[SRC]` |

**Scroll scribing (brief — full treatment in §4d)** — `Scripts/Services/Craft/DefInscription.cs`:

| Circle | `minSkill` | `maxSkill` | Mana per scroll | Citation |
|---|---|---|---|---|
| 0 (1st) | −25.0 | 25.0 | 4 | `DefInscription.cs:170`, `:243-244` |
| 1 (2nd) | −10.8 | 39.2 | 6 | `:171`, `:255-256` |
| 2 (3rd) | 3.5 | 53.5 | 9 | `:172`, `:267-268` |
| 3 (4th) | 17.8 | 67.8 | 11 | `:173`, `:279-280` |
| 4 (5th) | 32.1 | 82.1 | 14 | `:174`, `:291-292` |
| 5 (6th) | 46.4 | 96.4 | 20 | `:175`, `:303-304` |
| 6 (7th) | 60.7 | 110.7 | 40 | `:176`, `:315-316` |
| 7 (8th) | 75.0 | 125.0 | 50 | `:177`, `:327-328` |

Every scroll also requires `BlankScroll ×1` plus the spell's reagents (`:180-187`); the skill-info
row for Inscription is `SkillInfo(23, "Inscription", 0.0, 2.0, 8.0, "Scribe", null, 0.0, 0.2, 0.8,
1.0, Int, Dex)` (`Server/Skills.cs:619`) — i.e. **Str +0 %, Dex +2 %, Int +8 %** stat gain weights.

---

### 2.18 Camping (kindling, campfire, bedroll, secure logout)

Sources: `ServUO:Scripts/Items/Consumables/Kindling.cs`, `Scripts/Items/Functional/Campfire.cs`,
`Scripts/Items/Tools/Bedroll.cs` · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Functional/Campfire.cs

| Field | Value |
|---|---|
| Trigger | **Item double-click on `Kindling`** (`Kindling.cs:47`). Camping has **no skill callback** (`Server/Skills.cs:606` passes `null`), so the skill button replies `500014` "That skill cannot be used directly." |
| Target requirements | none — the fire is placed at a computed adjacent tile. Requires `VerifyMove(from)` and `InRange(GetWorldLocation(), 2)` (`:49-56`) |
| Skill check window | `from.CheckSkill(SkillName.Camping, 0.0, 100.0)` (`Kindling.cs:64`) ⇒ chance = `Camping.Value / 100` |
| Delay / cooldown | none — no `NextSkillTime` write; limited only by the kindling supply. The campfire itself lives 100 s |
| Success outcome | `Consume()` the kindling; a `Campfire` is placed at the fire location (`:70-75`) |
| Failure outcome | `501696` "You fail to ignite the campfire." — **kindling is not consumed** (`:64-67`) |
| Resource consumed | 1 `Kindling` (weight 1.0, item id `0xDE1`, stackable) **only on success** |
| Messages / gumps | `1019045` "I can't reach that."; `501695` "There is not a spot nearby to place your campfire."; `501696`; campfire `500620` "You feel it would take a few moments to secure your camp."; `500621` "The camp is now secure."; bedroll gump `1011015` / `1011016` |
| Interactions | none coded — Camping does not read any other skill; the resulting `CampfireEntry.Safe` flag is what the **Bedroll logout** consumes |
| [ERA] | No `Core.*` gate anywhere in these three files — the campfire/bedroll mechanics are pre-AoS-era and unchanged through SA |
| Confidence | `[SRC]` |

**Campfire placement rules (`Kindling.GetFireLocation`, `:79-121`)**

| Rule | Literal |
|---|---|
| Dungeon | `if (from.Region.IsPartOf<DungeonRegion>()) return Point3D.Zero;` ⇒ `501695`, no fire |
| Kindling on the ground | `if (Parent == null) return Location;` — lights where it lies |
| Candidate tiles | exactly four offsets, in this order: `(0,−1)`, `(−1,0)`, `(0,+1)`, `(+1,0)` (`:89-92`) |
| Tile validity | `map.CanFit(loc, 1) && from.InLOS(loc)`, retried at `map.GetAverageZ(x, y)` if the first Z fails (`:110-120`) |
| Selection | `Utility.Random(list.Count)` — uniformly random among the valid candidates (`:97-98`) |

**Campfire lifecycle (`Campfire.cs`)**

| Constant | Value | Citation |
|---|---|---|
| Item id / light | `0xDE3`, `LightType.Circle300`, `Movable = false` | `:23-25` |
| Tick | `Timer.DelayCall(1.0 s, 1.0 s, OnTick)` | `:31` |
| Extinguishing | `age >= 60 s` → id `0xDE9`, `Circle150` | `:131-132`, `:75-78` |
| Off | `age >= 90 s` → id `0xDEA`, `LightType.ArchedWindowEast`, all entries cleared | `:129-130`, `:79-83` |
| Deleted | `age >= 100 s` → `Delete()` | `:127-128` |
| Secure radius | `public static readonly int SecureRange = 7` | `:17` |
| Entry creation | every `PlayerMobile` within `SecureRange` with no existing entry → `500620` | `:150-165` |
| Secure timer | `!entry.Safe && now - entry.Start >= 30 s` → `entry.Safe = true` + `500621` | `:143-147` |
| Entry validity | `!Fire.Deleted && Fire.Status != Off && Player.Map == Fire.Map && Player.InRange(Fire, SecureRange)` | `:217-223` |
| Serialization | `Deserialize` calls `this.Delete()` — campfires never persist across a restart | `:113-120` |

**Bedroll + secure logout (`Bedroll.cs`)**

| Step | Rule | Citation |
|---|---|---|
| Double-click | requires `Parent == null`, `VerifyMove(from)`, `InRange(this, 2)` | `:25-32` |
| Roll direction | `ItemID == 0xA57` (rolled): `GetDirection4` N/S → `0xA55`, else `0xA56` | `:34-42` |
| Unroll | any other id → back to `0xA57`; then, if no `LogoutGump` is open and `Campfire.GetEntry(from) != null && entry.Safe`, open `LogoutGump` | `:43-54` |
| Gump | `400 × 350`, background `0xA28`, title `1011015` "<center>Logging out via camping</center>", body `1011016`, CONTINUE button id `1`, CANCEL id `0` | `:84-100` |
| Auto-close | `Timer.DelayCall(10.0 s, CloseGump)` — "The camp will remain secure for 10 seconds…" | `:82`, comment `:91-93` |
| CONTINUE requirements | `info.ButtonID == 1 && entry.Safe && bedroll.Parent == null && bedroll.IsAccessibleTo(pm) && bedroll.VerifyMove(pm) && bedroll.Map == pm.Map && pm.InRange(bedroll, 2)` | `:112-113` |
| CONTINUE effect | bedroll into backpack, `pm.BedrollLogout = true`, **`sender.Dispose()`** (immediate disconnect) | `:115-118` |
| Either button | `Campfire.RemoveEntry(entry)` | `:121` |
| Logout delay | `PlayerMobile.GetLogoutDelay()` returns `TimeSpan.Zero` when `Young \|\| BedrollLogout \|\| BlanketOfDarknessLogout \|\| TestCenter.Enabled`, else `base.GetLogoutDelay()` (the normal combat/flag delay) | `PlayerMobile.cs:6177-6185` |
| Reset | `BedrollLogout = false` on login | `PlayerMobile.cs:1649`, `:5482` |

`[SRC]`. `[ERA]`: the secure-logout-camp mechanic is the classic (pre-AoS) design; no expansion gate
is present in code. `[PARTIAL]`: the exact `base.GetLogoutDelay()` value (the non-camp delay) lives
in `Server/Mobile.cs` and is not part of this section — see the logout/flag section.

---

### 2.19 Healing and Veterinary (bandage use model)

Source: `ServUO:Scripts/Items/Resource/Bandage.cs` (778 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Resource/Bandage.cs

| Field | Value |
|---|---|
| Trigger | **Item double-click on a `Bandage`** (`:73`) → `500948` "Who will you use the bandages on?"; also the `EventSink.BandageTargetRequest` path used by the enhanced client / macros (`:20`, `:89-118`) |
| Target requirements | `Target(Bandage.Range, false, TargetFlags.Beneficial)` (`:125`), `Bandage.Range = Core.AOS ? 2 : 1` (`:23`); target must be a `Mobile` (or `PlagueBeastInnard`) and the *bandage* must be within range (`:139`) |
| Skill check window | No `min/max` window — all healing rolls are **direct-chance** (`CheckSkill(skill, chance)` at the end of the action, `:590-591`) |
| Delay / cooldown | `BandageContext.GetDelay` (table below); the timer ticks every **250 ms** and ends the action at `m_Expires` (`:618-640`). No `NextSkillTime` write, so bandaging does not block the skill timer |
| Success outcome | Heal / cure / stop bleed / resurrect — see tables. Sound `0x57` on the patient (`:585`) |
| Failure outcome | `500968` "You apply the bandages, but they barely help." (`:568`) for the heal path; `500966`/`503256` for resurrection; `1010060` for cure |
| Resource consumed | **1 bandage** consumed the moment `BeginHeal` returns a context (`:141-145`); `EnhancedBandage` adds `HealingBonus = 10` (`FountainOfLife.cs:28-34`, applied at `Bandage.cs:214-215`) |
| Messages / gumps | `500948`, `500295` "You are too far away to do that.", `500970` "Bandages can not be used on that.", `500951` "You cannot heal that.", `500955` "That being is not damaged!", `501042` "Target cannot be resurrected at that location.", `500956` "You begin applying the bandages.", `1008078` " : Attempting to heal you.", `500969` "You finish applying the bandages.", `500968`, `500967` "You heal what little damage your patient had.", `500961` "Your fingers slip!", `500962` "You were unable to finish your work before you died.", `500963` "You did not stay close enough to heal your target.", `500965` "You are able to resurrect your patient.", `500966`, `502391` "Thou can not be resurrected there!", `1049658`, `1049659`, `503256`, `1010395`, `1010058`, `1010059`, `1010060`, `1060088`, `1060167`, `1005000`/`1010398` (mortal strike), `1151178` (searing wounds), `1151400` buff text |
| Interactions | **Anatomy** (human) / **Animal Lore** (creature) is the secondary skill in *every* formula; `Poison` level of the patient; `BleedAttack`; `MortalStrike`; **Spirituality virtue** on cross-heals (`:559-562`); **City Loyalty** Guild of Healers trade deal (`:538-541`); ToL **Searing Wounds**; `FirstAidBelt` and `Asclepius`/`GargishAsclepius` add healing (`:490-501`); `PetResurrectGump` for dead pets |
| [ERA] | `Core.AOS` selects the modern heal amounts (`:511-520`), the AoS delay curve (`:738-746`) and the slips-ratio penalty (`:529-536`); `Core.SA` enables the half-way poison/bleed check (`:611-616`); `Core.SE` lets a `FactionWarHorse`'s own master always resurrect it (`:346`); `Core.ML`-era `MortalStrike`/bleed branches |
| Confidence | `[SRC]` |

**Skill selection (`GetPrimarySkill` / `GetSecondarySkill`, `:242-274`)**

| Patient | Primary | Secondary |
|---|---|---|
| `DespiseCreature` | `Healing` if `Healing.Value > Veterinary.Value`, else `Veterinary` | `Anatomy` if the same comparison holds, else `AnimalLore` |
| `!Player && (Body.IsMonster \|\| Body.IsAnimal)` | `Veterinary` | `AnimalLore` |
| everything else (including players) | `Healing` | `Anatomy` |

**Wait delay by skill and dex (`GetDelay`, `:708-761`)** — `resDelay = dead ? 5.0 : 0.0` where
`dead = !patient.Alive || patient.IsDeadBondedPet` (`:710`, `:720`):

| Case | Formula | Citation |
|---|---|---|
| AoS, self-heal | `seconds = min(8, ceil(11.0 - dex / 20))`, then `max(seconds, 4)` ⇒ **dex 0–59 → 8 s, 60–79 → 7, 80–99 → 6, 100–119 → 5, 120+ → 4** | `:728-732` |
| pre-AoS, self-heal | `seconds = 9.4 + (0.6 * ((120 - dex) / 10))` ⇒ **11.8 s at dex 80, 9.4 s at dex 120** | `:733-736` |
| AoS, Veterinary on a creature | `seconds = 2.0` (flat) | `:738-741` |
| AoS, other target | `seconds = ceil(4 - dex / 60)`, then `max(seconds, 2)` | `:742-746` |
| pre-AoS, other target | `dex >= 100 → 3.0 + resDelay`; `dex >= 40 → 4.0 + resDelay`; else `5.0 + resDelay` | `:747-758` |
| Resurrection | adds **+5.0 s** to every branch (only the pre-AoS "other target" branch adds `resDelay` in code; the AoS branches do **not** add it — see the divergence note) | `:720`, `:747-758` |

`[SRC]` note: in `pub57` the `resDelay` is only *used* by the pre-AoS branches, so on AoS a
resurrection takes exactly the same time as a heal. This looks like a bug; the clone must decide
whether to reproduce it.

**Divergence with ModernUO (same function)** — `ModernUO:Projects/UOContent/Items/Skill Items/Misc/Bandage.cs:483-526`:

| Case | ServUO `pub57` | ModernUO `main` |
|---|---|---|
| AoS self | `min(8, ceil(11 - dex/20))`, floor 4 | `5.0 + 0.5 * ((120 - dex) / 10)` with an in-source `// TODO: Verify algorithm` |
| pre-AoS self | `9.4 + 0.6*((120-dex)/10)` | identical |
| AoS Veterinary | `2.0` | `2.0` |
| AoS other | `max(ceil(4 - dex/60), 2)` | `dex < 204 ? 3.2 - sin(dex/130)*2.5 + resDelay : 0.7 + resDelay` |
| pre-AoS other | `3.0/4.0/5.0 + resDelay` | identical |

**Heal amount (`EndHeal`, `:482-571`)**

| Step | AoS | pre-AoS |
|---|---|---|
| Base chance | `chance = ((healing + 10.0) / 100.0) - (m_Slips * 0.02)` (`:503`) | same |
| `min` | `(anatomy / 8.0) + (healing / 5.0) + 4.0` (`:513`) | `(anatomy / 5.0) + (healing / 5.0) + 3.0` (`:518`) |
| `max` | `(anatomy / 6.0) + (healing / 2.5) + 4.0` (`:514`) | `(anatomy / 5.0) + (healing / 2.0) + 10.0` (`:519`) |
| Roll | `toHeal = min + (RandomDouble() * (max - min))` (`:522`) | same |
| Monster/animal bonus | `toHeal += m_Patient.HitsMax / 100` (`:524-527`) | same |
| Slip penalty | `toHeal -= toHeal * m_Slips * 0.35` (in-source `// TODO: Verify algorithm`) (`:531`) | `toHeal -= m_Slips * 4` (`:535`) |
| City Loyalty | `toHeal += (int)Math.Ceiling(toHeal * 0.05)` with Guild of Healers trade deal (`:539-540`) | same |
| After cure/bleed | `toHeal /= m_HealedPoisonOrBleed` (`:543-546`) | same |
| Searing Wounds | `toHeal /= 2` + `1151178` (`:548-552`) | same |
| Floor | `toHeal < 1` → `1` and message `500968` (`:554-558`) | same |
| Apply | `m_Patient.Heal((int)toHeal, m_Healer, false)` (`:564`) | same |
| Healing bonus sources | `FirstAidBelt.HealingBonus` (`:490-493`), `Asclepius`/`GargishAsclepius` `+15` (`:495-498`), `EnhancedBandage` `+10` (`:214-215`); the sum is added to `healing` when `> 0` (`:500-501`) | same |

**Cure-poison chance (`m_Patient.Poisoned` branch, `:437-463`)** — gated on `Healing/primary >= 60.0
&& Anatomy/secondary >= 60.0` (`:445`):

```
chance = ((healing - 30.0) / 50.0) - (m_Patient.Poison.RealLevel * 0.1) - (m_Slips * 0.02)
if (checkSkills && chance > Utility.RandomDouble()):
    CurePoison -> healer 1010058 (only if healer != patient) / patient 1010059
    else:      healer -1, patient -1        (silent)
else:          healer 1010060 "You have failed to cure your target!"
```

| Poison | `RealLevel` | Chance penalty |
|---|---|---|
| Lesser | 0 | 0.0 |
| Regular | 1 | 0.1 |
| Greater | 2 | 0.2 |
| Deadly | 3 | 0.3 |
| Lethal | 4 | 0.4 |

**Resurrection requirement (`:339-435`)** — when `!m_Patient.Alive` (or a dead pet):

```
chance = ((healing - 68.0) / 50.0) - (m_Slips * 0.02)
success requires: (checkSkills = (healing >= 80.0 && anatomy >= 80.0)) && chance > RandomDouble()
  -- or -- Core.SE && patient is FactionWarHorse && ControlMaster == healer
  -- or -- VvV enabled && patient is VvVMount && ControlMaster == healer
```

| Success sub-case | Messages |
|---|---|
| Location cannot fit 16 items | healer `501042`, patient `502391` |
| Region is part of `"Khaldun"` | healer `1010395` |
| Normal success | healer `500965`, patient sound `0x214`, effect `0x376A`/10/16, patient gets `ResurrectGump` |
| Dead pet, healer is the master | `ResurrectPet()` and **every skill drops 0.1** (`:376-379`) |
| Dead pet, master within 3 | `1049658` + `PetResurrectGump` to the master |
| Dead pet, a friend within 3 | `1049658` + `PetResurrectGump` to the friend |
| Dead pet, nobody near | `1049659` |
| Failure | `503256` (dead pet) / `500966` (player) |

**Mid-bandage poison/bleed check (`CheckPoisonOrBleed`, `:276-312`)** — only possible when
`Core.SA && healer == patient && Healing.Value >= 80 && Anatomy.Value >= 80` (`:606-616`), executed
once at **half** the bandage duration (`:635`):

```
chance = ((Healing.Value + Anatomy.Value) - 120) * 25
if (poisoned) chance /= patient.Poison.RealLevel * 20
else          chance /= 3 * 20                    // bleed only
if (chance >= Utility.Random(100)):
    m_HealedPoisonOrBleed = poisoned ? Poison.RealLevel : 3
    CurePoison -> patient 1010059
    else stop bleeding -> 1060088 / 1060167
```

`[SRC]` — note this is a **second, independent** cure roll on top of the end-of-bandage cure, and it
reduces the eventual heal by dividing by `RealLevel` (or 3 for bleed) at `:543-546`.

**Other branches handled at the end of the bandage**

| Patient state | Message(s) | Citation |
|---|---|---|
| Healer died | `500962` | `:327-332` |
| Healer out of range | `500963` | `:333-338` |
| Patient bleeding | `1060088` (healer) / `1060167` (patient) + `EndBleed` | `:464-470` |
| Patient under Mortal Strike | `1005000` (self) / `1010398` | `:471-476` |
| Patient at full HP | `500967` "You heal what little damage your patient had." | `:477-481` |
| Skill gain | `CheckSkill(secondarySkill, 0.0, 120.0)` then `CheckSkill(primarySkill, 0.0, 120.0)`, only when the branch set `checkSkills = true` | `:588-592` |
| Buff cleanup | `BuffInfo.RemoveBuff(healer, BuffIcon.Healing)` for players, `Veterinary` otherwise | `:594-597` |
| Enhanced-client timer packet | `BandageTimerPacket(0xBF, 0x31, 0xE21, seconds)` | `:697-700`, `:764-777` |

`[ERA]`: the **entire** `1002082`/`1002167` buff pair, the ICON split, and the enhanced-client timer
packet are SA/EC-era; the heal, cure and resurrect formulas are AoS-shaped with pre-AoS branches as
tabulated. `[PARTIAL]`: the retail bandage delay curve for AoS non-self healing is *not* what
ServUO ships (see the ModernUO divergence table) — to decide which one a clone should use, measure
bandage completion time on a live shard at dex 10/60/120 and compare against both curves.

---

### 2.20 Cross-skill interaction summary (this section only)

| Skill | Reads / is read by | Effect |
|---|---|---|
| Anatomy | weapon damage (AoS `BaseWeapon.cs:3789`, pre-AoS `:3856`), pre-AoS 2H special (`BaseAxe.cs:147` etc.), bandage primary/secondary pair, Animal Lore gump | +0.5 %/pt (AoS) or +0.2 %/pt + 10 % at GM (pre-AoS) melee damage; heal formula + cure/resurrect gate |
| Animal Lore | Animal Taming (passive gain + control chance `BaseCreature.cs:1534`), bandage secondary for creatures | control chance, gump detail |
| Arms Lore | none | informational |
| EvalInt | Magery damage (`Spell.cs:53`, `:231-234`, `:451-478`), Protection, Paralyze Field, weapon paralyze duration | spell damage, durations |
| ItemID | Imbuing (`CanUnravelItem`, `GetTotalWeight`) | unravel ingredient preview |
| TasteID | Poisoning output | detects `Food.Poison` |
| Forensics | Lockpicking (`ILockpickable.Picker`), corpse/justice data, Honesty virtue | criminal/lock forensics |
| Tracking | Detect Hidden (`Tracking.cs:244`), Hiding/Stealth of the target, Ninjitsu stalking bonus | PvP tracking difficulty, ninjitsu damage |
| Begging | Karma, Fame | gold cap and karma loss |
| Herding | Animal Taming (`CurrentTameSkill`) | creature movement |
| Detect Hidden | Hiding/Stealth, Tracking, Remove Trap (≥50 gate), Lockpicking (≥50 gate), Shadow Spell mastery | reveals |
| Remove Trap | Lockpicking ≥50, Detect Hidden ≥50, Tinkering 80–100 (faction traps), Magery `Remove Trap` spell | disarms |
| Poisoning | TasteID, Arms Lore (`PoisonCharges`), Infectious Strike (AoS), poison levels in `Server/Poison.cs` | weapon/food poison |
| Meditation | Focus, armour, Spell Channeling/Mage Armor, mana regen (`RegenRates.cs`) | mana regen rate |
| Spirit Speak | all Necromancy spells (`NecromancerSpell.cs:26`), ghost speech, Conduit/Command Undead masteries | necro damage/duration, speech |
| Animal Taming | Animal Lore, necro Dark Wolf mastery, Followers/Fame, bard pacification | pet acquisition |
| Inscription | scroll crafting (§4d), Magery scroll/scribe bonuses | copy books, scribe scrolls |
| Camping | Bedroll logout | secure logout |
| Healing / Veterinary | Anatomy / Animal Lore, Poison, BleedAttack, MortalStrike, Spirituality, City Loyalty, Searing Wounds | heal/cure/resurrect |

---

### 2.21 Open items for this section

| # | Gap | Marker | How to resolve |
|---|---|---|---|
| 1 | English text for clilocs `1038045`–`1038165`, `1038303`–`1038313` (Anatomy), `1038166`–`1038212` (EvalInt), `1038285`–`1038302` (Arms Lore), `1049595`–`1049605` (loyalty) | `[PARTIAL]` | dump those ids from `cliloc.enu` (client files) or from `ClassicUO`'s cliloc reader |
| 2 | Whether retail gates spell circles on EvalInt | `[UNVERIFIED]` | no such code in `pub57`; measure client behaviour with `Magery 30 / EvalInt 100` |
| 3 | Retail AoS non-self bandage delay curve | `[PARTIAL]` | ServUO and ModernUO disagree; measure completion time at dex 10/60/120 on a live shard |
| 4 | Passive-detect cadence (per step vs per timer) | `[UNVERIFIED]` | instrument `DoPassiveDetect` on a live shard and count calls/second standing vs walking |
| 5 | Elf begging reward histogram (`Random(8)`/`Random(6)` are exclusive, 3 branches dead) | `[PARTIAL]` | N≥2000 begs on an elf NPC, record item counts |
| 6 | AoS resurrection not adding `resDelay` (5 s) | `[PARTIAL]` | read `pub57` `Bandage.cs:720` vs `:728-746`; decide reproduce vs fix |
| 7 | „you fail to tame" vs „you anger the beast" probabilities per creature | `[UNVERIFIED]` | N≥1000 tame attempts per creature type on a live shard |
| 8 | Remove Trap trap **placement** difficulty values (`TrapPower`) written by Tinkering/t-map/chest spawners | `[PARTIAL]` | `Scripts/Services/Craft/DefTinkering.cs:919`, `Services/TreasureMaps/TreasureMapInfo.cs:661-681`, `TreasureMapChest.cs:174` — covered in the trap/craft sections |

## 2b. Skill use model — combat & magery formulas

Primary source: **ServUO `pub57`**. Secondary/verification: **ModernUO `main`**.
Every constant below is quoted from source with `path:LINE`. Numbers that exist only in
prose sources are marked `[WEB]`; anything that was not found is marked `[UNVERIFIED]` and
says what would have to be measured.

**Naming corrections (important, affects the whole section):**
- `Mobile.CheckHit` / `Mobile.CheckParry` **do not exist** in ServUO `pub57`. The melee
  attack pipeline lives on `BaseWeapon` (`Scripts/Items/Equipment/Weapons/BaseWeapon.cs`).
  `Server/Mobile.cs` only supplies `CheckAttack` (line 2174), the combat timer (line 2038),
  `Weapon`/`DefaultWeapon` (line 10459) and `HarmfulCheck` (line 8067).
- `OnSwingHit` **does not exist** anywhere in `pub57` (`grep OnSwingHit` → 0 hits). The hooks
  are `OnBeforeSwing` → `OnSwing` → (`CheckHit` → `OnHit` | `OnMiss`) → `GetDelay`.
- `CastSkillRequired` **does not exist** in `pub57` (`grep CastSkillRequired` → 0 hits). The
  equivalent is `MagerySpell.GetCastSkills(out double min, out double max)` consumed by
  `Spell.CheckFizzle()`. There is **no hard circle gate** — see §9.3.
- `MaxSwingSpeed` **does not exist** (`grep MaxSwingSpeed` → 0 hits). The only swing-rate
  clamp is the 5-tick floor in `GetDelay`.
- `Scripts/Spells/**/Magery.cs` **does not exist** in `pub57`; the Magery spell base class is
  `Scripts/Spells/Base/MagerySpell.cs`, and the per-circle spells live in
  `Scripts/Spells/First/**` … `Eighth/**` (registered in `Scripts/Spells/Initializer.cs`).

### 2b.0 Source index (URL prefix for every `path:LINE` below)

| Cite as | Repository URL prefix |
|---|---|
| `ServUO:<path>:<L>` | `https://github.com/ServUO/ServUO/blob/pub57/<path>#L<L>` |
| `ModernUO:<path>:<L>` | `https://github.com/modernuo/ModernUO/blob/main/<path>#L<L>` |

| Short name used below | Full path |
|---|---|
| `BaseWeapon.cs` | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs` |
| `BaseRanged.cs` | `Scripts/Items/Equipment/Weapons/BaseRanged.cs` |
| `Fists.cs` | `Scripts/Items/Equipment/Weapons/Fists.cs` |
| `WeaponEnums.cs` | `Scripts/Items/Equipment/Weapons/WeaponEnums.cs` |
| `BaseArmor.cs` | `Scripts/Items/Equipment/Armor/BaseArmor.cs` |
| `BaseShield.cs` | `Scripts/Items/Equipment/Armor/BaseShield.cs` |
| `SkillCheck.cs` | `Scripts/Misc/SkillCheck.cs` |
| `AOS.cs` | `Scripts/Misc/AOS.cs` |
| `RegenRates.cs` | `Scripts/Misc/RegenRates.cs` |
| `Spell.cs` | `Scripts/Spells/Base/Spell.cs` |
| `MagerySpell.cs` | `Scripts/Spells/Base/MagerySpell.cs` |
| `SpellHelper.cs` | `Scripts/Spells/Base/SpellHelper.cs` |
| `SpecialMove.cs` | `Scripts/Spells/Base/SpecialMove.cs` |
| `WeaponAbility.cs` | `Scripts/Abilities/WeaponAbility.cs` |
| `PlayerMobile.cs` | `Scripts/Mobiles/PlayerMobile.cs` |

---

### 2b.1 The one primitive every skill check goes through `[SRC]`

All combat/magery skill rolls end in `Mobile.CheckSkill` → `SkillCheck.CheckSkill`.

| Item | Value / formula | Cite |
|---|---|---|
| Roll | `success = Utility.Random(100) <= (int)(chance * 100)` | `SkillCheck.cs:245` |
| Chance source (targeted) | `chance = (value - minSkill) / (maxSkill - minSkill)`; `value < minSkill` → `false` (auto-fail, no roll); `value >= maxSkill` → `true` (auto-success) | `SkillCheck.cs:300-306`, `147-151` |
| Direct-chance variant | `chance < 0.0` → false; `chance >= 1.0` → true | `SkillCheck.cs:169-176` |
| Location bucket | `LocationSize = 4`; bucket = `(X/4, Y/4)` | `SkillCheck.cs:38`, `157`, `175` |
| Anti-macro | `AntiMacroExpire = 5 min`, `Allowance = 3` uses per location | `SkillCheck.cs:28`, `33` |
| Gain chance (single) | `gc = (Cap - Total)/Cap; gc += (skill.Cap - skill.Base)/skill.Cap; gc /= 2; gc += (1-chance)*(success ? 0.5 : (Core.AOS ? 0.0 : 0.2)); gc /= 2; gc *= GainFactor; clamp 0.01..1.00` | `SkillCheck.cs:261-284` |
| Pet bonus | controlled creature: `gc += gc * 1.00` (i.e. double) | `SkillCheck.cs:277-278` |
| Free gains | `skill.Base < 10.0` → always gains | `SkillCheck.cs:250` |
| Gain step | `toGain = (int)(from.Region.SkillGain(from) * 10)` (1/10 skill = 1 fixed-point unit) | `SkillCheck.cs:361` |
| Low-skill burst | `if (toGain == 1 && skill.Base <= 10.0) toGain = Utility.Random(4) + 1` | `SkillCheck.cs:400-401` |
| Apply | `skill.BaseFixedPoint = Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain)` | `SkillCheck.cs:446` |
| GGS | `GGSTable[skill.Base/5][Total>=7000?2:Total>=3500?1:0]` minutes | `SkillCheck.cs:787-806` |
| Stat gain (pre-ML) | `(info.StrGain / 33.3) * scalar > Utility.RandomDouble()` (same for Dex/Int) | `SkillCheck.cs:470-475` |
| Stat gain (ML) | flat chance `_PlayerChanceToGainStats / 100.0`, default `5` → 5%; primary/secondary 3:1 split | `SkillCheck.cs:49`, `510-511`, `550-556` |
| Anti-macro skill table | combat skills **off**: Parry `67`, Tactics `89`, Archery `93`, Swords/Macing/Fencing/Wrestling `102-105`, Focus `112`; **on**: Anatomy `63`, ArmsLore `66`, EvalInt `78`, Magery `87`, MagicResist `88`, Lumberjacking `106`, Meditation `108` | `SkillCheck.cs:59-123` |
| Racial lock `[ERA SA]` | Archery gains denied to Gargoyles; Throwing gains denied to non-Gargoyles | `SkillCheck.cs:339-343` |

`[ERA]` `Core.AOS` changes the *failure* gain term from `0.2` to `0.0` (`SkillCheck.cs:268`);
`Core.ML` swaps the whole stat-gain model to a flat 5% roll (`SkillCheck.cs:466-480`).

---

### 2b.2 (1) SWING SPEED — `BaseWeapon.GetDelay` `[SRC]`

`GetDelay` is the **only** implementation (`grep "override TimeSpan GetDelay"` → 0 hits).

**Weapon base speed.** `Speed` returns `m_Speed` if set, else `MlSpeed` (ML+), `AosSpeed`
(AoS), or `OldSpeed` (pre-AoS):

```csharp
if (m_Speed != -1) return m_Speed;
if (Core.ML)  return MlSpeed;
else if (Core.AOS) return AosSpeed;
return OldSpeed;
```
`BaseWeapon.cs:629-648`. A speed of `0` returns `TimeSpan.FromHours(1.0)` (`BaseWeapon.cs:1545-1548`).

**Swing Speed Increase (SSI) source and cap.** `bonus = AosAttributes.GetValue(m, AosAttribute.WeaponSpeed)`;
`if (bonus > 60) bonus = 60;` → **SSI cap 60** (`BaseWeapon.cs:1560-1565`). The same 60 cap is
used when the property is reported to the client (`AOS.cs:481-482`), even though single items can
carry more (e.g. `TheBeserkersMaul` has `Attributes.WeaponSpeed = 75`,
`Scripts/Items/Artifacts/Equipment/Weapons/TheBeserkersMaul.cs:12`).

| Era | Formula (verbatim) | Cite |
|---|---|---|
| **ML** (`Core.ML`) | `int stamTicks = m.Stam / 30;`<br>`ticks = speed * 4;`<br>`ticks = Math.Floor((ticks - stamTicks) * (100.0 / (100 + bonus)));` | `BaseWeapon.cs:1571-1574` |
| **SE, pre-ML** (`Core.SE && !Core.ML`) | `speed = Math.Floor(speed * (bonus + 100.0) / 100.0);`<br>`if (speed <= 0) speed = 1;`<br>`ticks = Math.Floor((80000.0 / ((m.Stam + 100) * speed)) - 2);` | `BaseWeapon.cs:1578-1585` |
| **AoS, pre-SE** (`Core.AOS`) | `int v = (m.Stam + 100) * (int)speed; v += AOS.Scale(v, bonus); if (v <= 0) v = 1;`<br>`delayInSeconds = Math.Floor(40000.0 / v) * 0.5;`<br>`if (delayInSeconds < 1.25) delayInSeconds = 1.25;` | `BaseWeapon.cs:1596-1617` |
| **pre-AoS** | `int v = (m.Stam + 100) * (int)speed; if (v <= 0) v = 1;`<br>`delayInSeconds = 15000.0 / v;` | `BaseWeapon.cs:1618-1628` |

* SE/ML floor and tick size: `if (ticks < 5) ticks = 5; delayInSeconds = ticks * 0.25;`
  (`BaseWeapon.cs:1588-1594`). **There is no 0.25 s floor** — the tick size is 0.25 s and the
  real floor is **5 ticks = 1.25 s** (comment in source: *"Swing speed currently capped at one
  swing every 1.25 seconds (5 ticks)"*). The pre-AoS branch has **no floor at all**.
* `AOS.Scale(input, percent) = (input * percent) / 100` (`AOS.cs:428-431`).
* The AoS comment blocks the "1 swing per second" claim and notes OSI said 1.25
  (`BaseWeapon.cs:1611-1616`).

**ML formula restated:** `delay_s = max(5, floor((4·MlSpeed − floor(Stam/30)) · 100/(100+SSI%))) · 0.25`.
Only `MlSpeed` and current `Stam` and SSI enter; **Dexterity is not read** — Dex reaches the
formula indirectly because stamina regenerates from Dex (`RegenRates.cs:89`).

**Worked examples (`Stam = 100`, so `stamTicks = 3`)** `[SRC]` — all arithmetic from the ML branch:

| Weapon | `MlSpeed` | ticks @ SSI 0 | delay @ SSI 0 | ticks @ SSI 60 | delay @ SSI 60 |
|---|---|---|---|---|---|
| Dagger `Dagger.cs:68` | 2.00 | 5 | 1.25 s | 5 (floor) | 1.25 s |
| Quarter Staff `QuarterStaff.cs:66` | 2.25 | 6 | 1.50 s | 5 (floor) | 1.25 s |
| Fists `Fists.cs:63` | 2.50 | 7 | 1.75 s | 5 (floor) | 1.25 s |
| Katana `Katana.cs:68` | 2.50 | 7 | 1.75 s | 5 (floor) | 1.25 s |
| Mace `Mace.cs:68` | 2.75 | 8 | 2.00 s | 5 | 1.25 s |
| Longsword `Longsword.cs:68` | 3.50 | 11 | 2.75 s | 6 | 1.50 s |
| Maul `Maul.cs:68` | 3.50 | 11 | 2.75 s | 6 | 1.50 s |
| Bardiche `Bardiche.cs:68` | 3.75 | 12 | 3.00 s | 7 | 1.75 s |
| Halberd `Halberd.cs:68` | 4.00 | 13 | 3.25 s | 8 | 2.00 s |
| Bow `Bow.cs:88` | 4.25 | 14 | 3.50 s | 8 | 2.00 s |
| Crossbow `Crossbow.cs:88` | 4.50 | 15 | 3.75 s | 9 | 2.25 s |
| Heavy Crossbow `HeavyCrossbow.cs:88` | 5.00 | 17 | 4.25 s | 10 | 2.50 s |

Same weapons at `Stam = 0`: `stamTicks = 0` → Longsword 14 ticks = **3.50 s**, Heavy Crossbow
20 ticks = **5.00 s**. Stamina therefore matters more than SSI in the ML model.

**Weapon base-speed table** (all `[SRC]`, value lines cited):

| Weapon | Class → skill | AoS dmg | `AosMin/MaxDamage` | `AosSpeed` | `MlSpeed` | pre-AoS dmg | `OldSpeed` | `DefMaxRange` |
|---|---|---|---|---|---|---|---|---|
| Fists | `BaseMeleeWeapon`/Wrestling `Fists.cs:111-117` | 1–6 | `Fists.cs:38-51` | 50 | 2.50 | 1–8 `Fists.cs:74-87` | 30 | 1 |
| Dagger | `BaseKnife`→Swords? **no**: `Dagger.cs:113-117` overrides to Fencing | 10–12 | `Dagger.cs:43-56` | 56 | 2.00 | — | — | 1 |
| Kryss | Fencing `Kryss.cs:127-131` | 10–12 | `Kryss.cs:43-56` | 53 | 2.00 | — | — | 1 |
| Katana | `BaseSword`→Swords `BaseSword.cs:18-22` | 10–14 | `Katana.cs:43-56` | 46 | 2.50 | — | — | 1 |
| Longsword | Swords `BaseSword.cs:18-22` | 14–18 | `Longsword.cs:43-56` | 30 | 3.50 | 5–33 `Longsword.cs:78-91` | 35 | 1 |
| Mace | `BaseBashing`→Macing `BaseBashing.cs:31-35` | 11–15 | `Mace.cs:43-56` | 40 | 2.75 | — | — | 1 |
| Quarter Staff | `BaseStaff`→Macing `BaseStaff.cs:31-35` | 11–14 | `QuarterStaff.cs:41-54` | 48 | 2.25 | 8–28 `QuarterStaff.cs:76-89` | 48 | 1 |
| Maul | Macing `BaseBashing.cs:31-35` | 14–18 | `Maul.cs:43-56` | 32 | 3.50 | 10–30 `Maul.cs:78-91` | 30 | 1 |
| Bardiche | `BaseAxe`→Swords `BaseAxe.cs:41-45` | 17–20 | `Bardiche.cs:43-56` | 28 | 3.75 | 5–43 `Bardiche.cs:78-91` | 26 | 1 |
| Halberd | `BasePoleArm`→Swords `BasePoleArm.cs:34-38` | 18–21 | `Halberd.cs:43-56` | 25 | 4.00 | 5–49 `Halberd.cs:78-91` | 25 | 1 |
| Bow | `BaseRanged`→Archery `BaseRanged.cs:20` | 17–21 ML / 16–18 AoS | `Bow.cs:63-76` | 25 | 4.25 | 9–41 `Bow.cs:98-111` | 20 | **10** `Bow.cs:119-125` |
| Crossbow | Archery `BaseRanged.cs:20` | 18–22 | `Crossbow.cs:63-76` | 24 | 4.50 | 8–43 `Crossbow.cs:98-111` | 18 | **8** `Crossbow.cs:119-125` |
| Heavy Crossbow | Archery `BaseRanged.cs:20` | 20–24 | `HeavyCrossbow.cs:63-76` | 22 | 5.00 | 11–56 `HeavyCrossbow.cs:98-111` | 10 | **8** `HeavyCrossbow.cs:119-125` |

Damage-level offset for pre-AoS `GetBaseDamage`: `damage += (2 * (int)m_DamageLevel) - 1`,
i.e. Ruin +1, Might +3, Force +5, Power +7, Vanq +9 (`BaseWeapon.cs:3647-3658`).
`WeaponDamageLevel` enum order `Regular, Ruin, Might, Force, Power, Vanq` (`WeaponEnums.cs:17-25`).

**ModernUO agreement.** `ModernUO:Projects/UOContent/Items/Weapons/BaseWeapon.cs:1356-1440`
carries the *same* three branches with the *same* literals (`m.Stam / 30`, `speed * 4`,
`100.0 / (100 + bonus)`, `80000.0`, `40000.0`, `15000.0`, bonus cap `60`, tick floor `5`,
`* 0.25`). ModernUO only adds extra bonus sources (Divine Fury, Honorable Execution,
Dual Wield, Reaper Form, Discordance, Essence of Wind) at lines 1377-1405. **No disagreement
on the algebra.**

---

### 2b.3 (2) TO-HIT — `BaseWeapon.CheckHit` `[SRC]`

`ServUO:Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1415-1539`
(url `https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Equipment/Weapons/BaseWeapon.cs#L1415`).

Non-mobile targets short-circuit to `IDamageableItem.CheckHit` or `true` (`:1419-1425`).

| Term | Definition | Cite |
|---|---|---|
| `atkSkill` | `attacker.Weapon.Skill` | `:1430` |
| `defSkill` | `defender.Weapon.Skill` | `:1431` |
| `atkValue` | `GetAttackSkillValue` = `attacker.Skills[GetUsedSkill(attacker,true)].Value` | `:1400-1403`, `:1433` |
| `defValue` | `GetDefendSkillValue` = `defender.Skills[GetUsedSkill(defender,true)].Value` | `:1405-1408`, `:1434` |
| weapon accuracy bonus | `Accurate +02, Surpassingly +04, Eminently +06, Exceedingly +08, Supremely +10` (pre-AoS returns 0) | `:3675-3704` |

**AoS branch (`Core.AOS`)** — `:1440-1471`:

```
if (atkValue <= -20.0) atkValue = -19.9;      // :1442-1443
if (defValue <= -20.0) defValue = -19.9;      // :1445-1446
bonus += AosAttributes.GetValue(attacker, AosAttribute.AttackChance);   // :1448  (HCI)
bonus  = Math.Min(attacker.Race == Race.Gargoyle ? 50 : 45, bonus);     // :1451  (HCI cap)
ourValue = (atkValue + 20.0) * (100 + bonus);                           // :1453
bonus    = AosAttributes.GetValue(defender, AosAttribute.DefendChance); // :1455  (DCI)
bonus   -= ForceArrow info.DefenseChanceMalus;                          // :1459-1460
int max  = 45 + BaseArmor.GetRefinedDefenseChance(defender);            // :1462
if (bonus > max) bonus = max;                                           // :1465-1466
theirValue = (defValue + 20.0) * (100 + bonus);                         // :1468
```

**Pre-AoS branch** — `:1472-1486`: clamps at `-50.0` → `-49.9`, then
`ourValue = (atkValue + 50.0); theirValue = (defValue + 50.0);`

**Shared finish** — `:1488-1538`:
`chance = ourValue / (theirValue * 2.0); chance *= 1.0 + ((double)bonus / 100);`
Note `bonus` is reset to `0` at `:1470` and `GetHitChanceBonus()` returns `0` when
`!Core.AOS` (`:3677-3680`), so that multiplier is a **no-op in practice** — flag it as a
source quirk, not a modifier.

`[ERA SA]` Thrown-weapon modifiers (`:1492-1528`):

| Situation | Effect | Cite |
|---|---|---|
| attacker throws at range 1 (Close Quarters) | `chance -= (0.12 - Math.Min(12, (Throwing + RawDex) / 20) / 100)` | `:1497-1500` |
| attacker throws closer than `MinThrowRange` | `chance -= 0.12` | `:1501-1504` |
| attacker has a shield while throwing | `chance -= chance * (Math.Min(90, 1200 / Math.Max(1.0, Parry)) / 100)` | `:1507-1514` |
| defender is a thrower and has a shield | same malus applied **positively** to the attacker's chance | `:1517-1527` |

`MinThrowRange` values: `Boomerang 4`, `Cyclone 6`, `SoulGlaive 8`
(`Scripts/Items/Equipment/Weapons/Boomerang.cs:20`, `Cyclone.cs:20`, `SoulGlaive.cs:20`).

**Clamps / specials:**
- `if (Core.AOS && chance < 0.02) chance = 0.02;` → **2 % floor** (`:1530-1533`). No upper clamp.
- Mage Weapon property: `if (Core.AOS && m_AosWeaponAttributes.MageWeapon > 0 && attacker.Skills[Magery].Value > atkSkill.Value) return attacker.CheckSkill(SkillName.Magery, chance);` (`:1535-1536`).
- Final roll: `return attacker.CheckSkill(atkSkill.SkillName, chance);` (`:1538`) → §2b.1.
- Pre-AoS has **no** 2 % floor.

**Which skill is used** — `GetUsedSkill` (`:1339-1398`): `UseBestSkill` → highest of
Swords/Fencing/Macing (`:1343-1363`); `MageWeapon` → Magery if higher than weapon skill
(`:1364-1374`); `MysticWeapon` → Mysticism if higher (`:1375-1385`); otherwise the weapon's
`Skill`; non-player non-human creatures substitute Wrestling when it is higher (`:1390-1394`).

**Defender side needs no Parry.** `defValue` is the defender's *weapon* skill. Parry is a
separate, later roll (§2b.5). A shield-only or unarmed defender defends through
`Fists.GetDefendSkillValue` (`Fists.cs:146-160`):

```
incrValue = (Anatomy + EvalInt + 20.0) * 0.5;  if (incrValue > 120.0) incrValue = 120.0;
return max(Wrestling, incrValue);
```
So a pure mage with Anatomy 100 + EvalInt 100 defends at `(100+100+20)/2 = 110`, capped 120.

**Attack validity and the swing loop:**

| Step | Code | Cite |
|---|---|---|
| `CheckAttack` | `Utility.InUpdateRange(this, e.Location) && CanSee(e) && InLOS(e)` | `Server/Mobile.cs:2174-2177` |
| Combat timer | `Timer(0.0, 0.01, 0)`; fires when `Core.TickCount - NextCombatTime >= 0` | `Server/Mobile.cs:2042-2055` |
| Range gate | `if (!m_Mobile.InRange(combatant, weapon.MaxRange)) return;` | `Server/Mobile.cs:2070-2073` |
| LOS gate | `if (m_Mobile.InLOS(combatant))` | `Server/Mobile.cs:2075` |
| Next swing | `NextCombatTime = Core.TickCount + (int)weapon.OnSwing(...).TotalMilliseconds` | `Server/Mobile.cs:2079` |
| Swing body | `HarmfulCheck` → `DisruptiveAction()` → `Swing` packet → `CheckHit ? OnHit : OnMiss` → `return GetDelay(attacker)` | `BaseWeapon.cs:1680-1717` |
| AoS gates | not paralyzed/frozen, not casting a movement-blocking spell, not peacemaking | `BaseWeapon.cs:1661-1678` |

**ModernUO differences** (`ModernUO:Projects/UOContent/Items/Weapons/BaseWeapon.cs:1208-1341`):
same core `ourValue/(theirValue*2.0)`, same `-20.0 → -19.9` clamp, same `0.02` floor, but
(a) non-AoS uses `Math.Max(0.1, atkValue + 50.0)` instead of the `-49.9` clamp (`:1327-1328`);
(b) HCI is capped flat at `45` with **no Gargoyle 50 exception** (`:1266-1270`);
(c) it adds Divine Fury +10, Wolf/Bake-Kitsune form +20, Hit-Lower-Attack −25,
weapon-ability accuracy bonus, special-move accuracy bonus, Block, Surprise Attack and
Discordance maluses (`:1236-1313`), which `pub57` applies elsewhere. `[SRC]` both.

---

### 2b.4 (3) DAMAGE — base range, skill bonuses, AoS resist pipeline `[SRC]`

**Base damage range** — `GetBaseDamageRange` (`BaseWeapon.cs:3601-3632`):
`BaseCreature.DamageMin/Max` if set (`:3607-3612`); `Fists` on a non-human body →
`min = max = attacker.Str / 28` (`:3614-3619`); `Fists` under Horrific Beast → `5..15`
(`:3622-3626`); otherwise `MinDamage..MaxDamage` (`:3629-3631`), where
`MinDamage = m_MinDamage == -1 ? (Core.AOS ? AosMinDamage : OldMinDamage) : m_MinDamage`
and likewise for Max (`:607-624`).
`GetBaseDamage` = `Utility.RandomMinMax(min, max)` + pre-AoS damage-level offset
(`:3634-3661`).

**AoS damage scaling — verbatim** (`BaseWeapon.cs:3768-3816`):

```
strengthBonus = GetBonus(attacker.Str,                        0.300, 100.0,  5.00);
anatomyBonus  = GetBonus(attacker.Skills[Anatomy].Value,      0.500, 100.0,  5.00);
tacticsBonus  = GetBonus(attacker.Skills[Tactics].Value,      0.625, 100.0,  6.25);
lumberBonus   = GetBonus(attacker.Skills[Lumberjacking].Value,0.200, 100.0, 10.00);
if (Type != WeaponType.Axe) lumberBonus = 0.0;                       // :3793-3796
damageBonus   = AosAttributes.GetValue(attacker, AosAttribute.WeaponDamage);
if (damageBonus > 100) damageBonus = 100;                            // :3806-3809
totalBonus = strengthBonus + anatomyBonus + tacticsBonus + lumberBonus
           + ((GetDamageBonus() + damageBonus) / 100.0);             // :3812-3813
return damage + (int)(damage * totalBonus);                          // :3815
```

`GetBonus(value, scalar, threshold, offset) = (value * scalar + (value >= threshold ? offset : 0)) / 100`
(`:3663-3673`). Comment in source: *"No caps apply"* to the physical bonuses (`:3784-3787`).

| Bonus | Per point | Grandmaster (100) | 120 | 150 |
|---|---|---|---|---|
| Strength | `0.003` (0.3 %) | `0.350` (+35 %) | `0.410` (+41 %) | `0.500` (+50 %) |
| Anatomy | `0.005` (0.5 %) | `0.550` (+55 %) | `0.650` (+65 %) | `0.800` (+80 %) |
| Tactics | `0.00625` (0.625 %) | `0.6875` (+68.75 %) | `0.8125` (+81.25 %) | `1.0000` (+100 %) |
| Lumberjacking (**axes only**) | `0.002` (0.2 %) | `0.300` (+30 %) | `0.340` (+34 %) | `0.400` (+40 %) |
| `AosAttribute.WeaponDamage` (DI) | item property | capped at **100** | — | — |

`GetBonus` is linear with **no upper cap** — at Str 150 the bonus is `150·0.300 + 5.00 = 50.00 → 0.500`.
Anatomy/Tactics/Lumberjacking are also rolled **passively** for gain on every AoS damage
computation: `CheckSkill(Tactics, 0.0, cap)`, `CheckSkill(Anatomy, 0.0, cap)`,
`CheckSkill(Lumberjacking, 0.0, 100.0)` only for `WeaponType.Axe` (`:3770-3781`).

**Dexterity:** there is **no Dexterity multiplier** in either damage function. `ScaleDamageAOS`
reads `attacker.Str` only; `ScaleDamageOld` reads `attacker.Str` only. Dex influences combat
only via stamina (swing delay), the `Dex < 80` parry malus (§2b.5) and the thrown
close-quarters term (`BaseWeapon.cs:1499`). `[SRC]` — absence verified by reading both
functions end-to-end.

**Pre-AoS damage scaling — verbatim** (`BaseWeapon.cs:3825-3900`):

```
damage += (damage * ((attacker.Skills[Tactics].Value - 50.0) / 100.0));   // :3845  50 → unchanged
modifiers  = (attacker.Str / 5.0) / 100.0;                                // :3850  1% per 5 Str
modifiers += ((anatomyValue / 5.0) / 100.0);                              // :3857  1% per 5 Anat
if (anatomyValue >= 100.0) modifiers += 0.1;                              // :3859-3862  +10% at GM
if (Type == WeaponType.Axe) { lumberValue = (lumberValue/5.0)/100.0;
                              if (lumberValue > 0.2) lumberValue = 0.2;   // :3873-3874  capped 20%
                              modifiers += lumberValue; }
if (m_Quality != ItemQuality.Normal) modifiers += (((int)m_Quality - 1) * 0.2);  // :3885-3888
damage += (damage * modifiers);                                           // :3897
```
Quirk: the follow-up `if (lumberValue >= 100.0) modifiers += 0.1;` (`:3878-3881`) can never
fire because `lumberValue` was just clamped to `0.2` — the "GM lumberjacking +10 %" that the
comment promises is dead code. `[SRC]`, reported as-is.

`ScaleDamageByDurability`: `scale = 50 + ((50 * m_Hits) / m_MaxHits)` when damaged → a
0-durability weapon does 50 % damage (`:3902-3912`).
`ComputeDamage` (pre-AoS) halves the result when the defender is a player **or** the attacker
is not a player: `damage = (int)(damage / 2.0)` (`:3914-3930`).
`GetDamageBonus` supplies pre-AoS quality/damage-level bonuses: Low −20, Exceptional +20,
Ruin +15, Might +20, Force +25, Power +30, Vanq +35 (`:3706-3748`).

**Post-scale multipliers** (`BaseWeapon.cs:2385-2575`): special-move `DamageScalar`,
necrotic-form +25 %, Honor +25 %, perfection bonus, Block reduction, Battle Lust,
thrown-over-max-range −47, Runed Sash −10, talisman slayer bonus, Force of Nature,
Assassin Honed `(int)(146.0 / MlSpeed)`, Focus. Then
`percentageBonus = Math.Min(percentageBonus, 300);` → **+300 % cap (x4 total)**
(`:2570`), followed by an explicitly **uncapped** `StoneFormSpell.GetMaxResistBonus`
(`:2572-2573`) and `damage = AOS.Scale(damage, 100 + percentageBonus);` (`:2575`).

**Absorption before the resist pipeline:**
- AoS: `AbsorbDamageAOS` (`:1872-1977`) — `CheckParry(defender)`; on success `damage = 0`
  (`:1885-1888`), shield `OnHit` for durability (`:1929`), else a random worn item from
  `_DamageLayers` absorbs (`:1961-1974`, layer list `:1989-2012`).
- Pre-AoS: `AbsorbDamage` (`:2014-2100`) — shield `OnHit` first (`:2024`), then a body-part
  lottery with cumulative thresholds `0.07 / 0.14 / 0.28 / 0.43 / 0.65` mapping to
  Neck / Hands / Arms / Head / Legs / Chest (`:2031-2054`), then
  `virtualArmor = defender.ArmorRating` (`:2063`) and
  `damage -= Utility.Random((int)(virtualArmor*scalar)/2, ((int)(virtualArmor*scalar) - (int)(virtualArmor*scalar)/2) + 1)`
  with `scalar = 0.07 / 0.14 / 0.15 / 0.22 / 0.35` by the same thresholds (`:2068-2097`).
- `BaseArmor.OnHit` absorbs `Absorbed = (int)(HalfAr + HalfAr * RandomDouble())` where
  `HalfAr = ArmorRating / 2.0`, min absorbed 2, and wears on a 25 % roll (80 % if Antique)
  (`BaseArmor.cs:2591-2655`).

**The AoS resist pipeline — verbatim** (`Scripts/Misc/AOS.cs:99-221`):

```
Fix(ref phys); ... Fix(ref direct);                                  // :130-136  normalise to 100 total
if (Core.ML && chaos > 0) { random element += chaos }                // :138-158
int physDamage   = damage * phys * (100 - damageable.PhysicalResistance);
int fireDamage   = damage * fire * (100 - damageable.FireResistance);
int coldDamage   = damage * cold * (100 - damageable.ColdResistance);
int poisonDamage = damage * pois * (100 - damageable.PoisonResistance);
int energyDamage = damage * nrgy * (100 - damageable.EnergyResistance);
totalDamage = physDamage + fireDamage + coldDamage + poisonDamage + energyDamage;
totalDamage /= 10000;                                                // :170-177
if (Core.ML) { totalDamage += damage * direct / 100; ... }           // :179-185
if (totalDamage < 1) totalDamage = 1;                                // :205-206
```
Ignore-armor path: `totalDamage = Math.Min(damage, Core.TOL && ranged ? 30 : 35);`
→ **35 direct-damage cap (30 for TOL ranged)** (`:208-214`).
`!Core.AOS` short-circuits to `m.Damage(damage, from)` with **no resistance math**
(`:109-115`).
Damage element split for players: `phys = 100 - fire - cold - pois - nrgy - chaos - direct`
(`BaseWeapon.cs:3490-3534`); creatures supply their own element array (`:3493-3504`).
Downstream AoS modifiers: Evil Omen ×1.25 (`AOS.cs:230-233`), Blood Oath ×1.2 and
cap 35 (`:246-264`), Reflect Physical capped at 105 (`:267-281`), Damage Eaters
(`:286-291`), Spirituality reduction (`:297`), Feint reduction (`:307-308`).

---

### 2b.5 (4) PARRY — `BaseWeapon.CheckParry` `[SRC]`

`ServUO:Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1756-1870`.

**Shield branch** (or any non-player defender) — `:1769-1809`:
```
chance = (parry - bushidoNonRacial) / 400.0;                  // :1771
if (chance < 0) chance = defender.Player ? 0 : .1;            // :1774-1777
chance += HeightenedSensesSpell.GetParryBonus(defender);      // :1780  [ERA ML masteries]
if (parry >= 100.0 || bushido >= 100.0) chance += 0.05;       // :1783-1786
if (Evasion.IsEvading(defender)) chance *= Evasion.GetParryScalar(defender);  // :1789-1792
if (defender.Player && defender.Dex < 80) chance = chance * (20 + defender.Dex) / 100; // :1795-1798
success = defender.CheckSkill(SkillName.Parry, chance);       // :1800
```
`NonRacialValue` removes the racial Bushido bonus (comment `:1772`).

**Weapon branch** — only when the defender has **no shield**, is a **player**, and the weapon
is neither `Fists` nor `BaseRanged` — `:1810-1867`:
```
if (Core.HS && weapon.Attributes.BalancedWeapon > 0) return false;                 // :1814-1817
double divisor = (weapon.Layer == Layer.OneHanded && defender.Player) ? 48000.0 : 41140.0; // :1819
double chance    = (parry * bushido) / divisor;                                     // :1821
double aosChance = parry / 800.0;                                                   // :1823
if (parry >= 100.0) { chance += 0.05; aosChance += 0.05; }                          // :1826-1830
else if (bushido >= 100.0) { chance += 0.05; }                                      // :1831-1834
if (Evasion.IsEvading(defender)) chance *= Evasion.GetParryScalar(defender);        // :1837-1840
if (defender.Dex < 80) chance = chance * (20 + defender.Dex) / 100;                 // :1843-1846
success = (chance > aosChance) ? defender.CheckSkill(SkillName.Parry, chance)
                               : (aosChance > Utility.RandomDouble());              // :1850-1858
```

**Bushido inputs (`[ERA]` Samurai Empire, 2004/2005)** — `Scripts/Spells/Bushido/Evasion.cs`:
| Constant | Value | Cite |
|---|---|---|
| `Evasion.RequiredSkill` | `60.0` | `Evasion.cs:26-32` |
| `Evasion.RequiredMana` | `10` | `Evasion.cs:33-39` |
| Evade duration pre-ML | `8.0 s` | `Evasion.cs:139-140` |
| Evade duration ML | `3 s`, `+ (Bushido-60)/20` while `Bushido > 60`, `+1 s` if `Anatomy >= 100 && Tactics >= 100 && Bushido > 100` | `Evasion.cs:142-150` |
| `GetParryScalar` pre-ML | `1.5` | `Evasion.cs:163-164` |
| `GetParryScalar` ML | `1.0 + (Bushido>=60 ? ((Bushido-60)*0.004 + 0.16) : 0)`, `+0.10` for the GM-triple condition | `Evasion.cs:166-174` |
| Evasion re-use lockout | `BeginAction(typeof(Evasion))`, 20 s | `Evasion.cs:235-236` |
| Evasion also blocks spells | `CheckSpellEvasion` → `IsEvading && BaseWeapon.CheckParry(defender)` | `Evasion.cs:109-120` |
| `[ERA ML]` weapon requirement | `Core.ML`: weapon skill `Base < 50` → cannot evade | `Evasion.cs:52-59`, `98-102` |

**Heightened Senses (`[ERA ML]` masteries)** — `Scripts/Spells/Skill Masteries/HeightenSenses.cs`:
`CastSkill = Parry` (`:27`), `UpKeep = 10` (`:21`), `RequiredMana = 10` (`:22`),
`TickTime = 3` (`:23`), `CastDelayBase = 1.0 s` (`:25`),
`PropertyBonus() = (int)((Parry + weaponSkill + GetMasteryLevel()*40) / 3) / 10` (`:109-112`),
`GetParryBonus(m) = PropertyBonus() / 100.0` (`:114-121`) — i.e. **+0.3 … +0.8 flat parry chance**.

**Post-parry handling:** `AbsorbDamageAOS` zeroes the damage (`BaseWeapon.cs:1885-1888`),
removes Honorable Execution penalty (`:1896`), allows Counter Attack to swing back (`:1898-1912`),
and Confidence heals `Utility.RandomMinMax(1, (int)(bushido/12))` HP and
`Utility.RandomMinMax(1, (int)(bushido/5))` stamina (`:1914-1923`). A parried special move
still consumes no mana under SE, or rolls `CheckMana` otherwise (`:2584-2599`).

**Pre-AoS shield block** (`BaseShield.cs:141-190`) — the source carries the original formulas
as comments (`:152-158`):
```
chance = (owner.Skills[Parry].Value - (ar * 2.0)) / 100.0;  if (chance < 0.01) chance = 0.01;   // :147-151
FORMULA: Displayed AR = ((Parrying Skill * Base AR of Shield) / 200) + 1                        // :153
FORMULA: % Chance of Blocking = parry skill - (shieldAR * 2)                                    // :155
FORMULA: Melee Damage Absorbed = (AR of Shield) / 2 | Archery Damage Absorbed = AR of Shield    // :157
```
Implemented: `damage -= (weapon.Skill == SkillName.Archery) ? (int)ar : (int)(ar / 2.0)`
(`:161-164`); 25 % chance to lose durability (`:171`). `BaseShield.ArmorRating` =
`((Parry * ar) / 200.0) + 1.0` (`BaseShield.cs:26-38`).

**Defense Chance Increase refinement (AoS+):** `GetRefinedDefenseChance(from)` sums each worn
armour's `RefinedDefenseChance = -(m_RefinedPhysical + m_RefinedFire + m_RefinedCold + m_RefinedPoison + m_RefinedEnergy)`
(`BaseArmor.cs:500`, `:521-531`) and raises the DCI cap in `CheckHit` (`BaseWeapon.cs:1462`).

---

### 2b.6 (5) RESISTING SPELLS — resist check, damage reduction, passive gains `[SRC]`

**Resist chance** — `MagerySpell.CheckResisted` / `GetResistPercentForCircle`
(`Scripts/Spells/Base/MagerySpell.cs:55-88`):

```
double n = GetResistPercent(target) / 100.0;
if (n <= 0.0) return false;  if (n >= 1.0) return true;              // :61-65
int maxSkill = (1 + (int)Circle) * 10;
maxSkill += (1 + ((int)Circle / 6)) * 25;                            // :67-68
if (target.Skills[MagicResist].Value < maxSkill)
    target.CheckSkill(SkillName.MagicResist, 0.0, target.Skills[MagicResist].Cap);  // :70-71
return (n >= Utility.RandomDouble());                                // :73
```
```
GetResistPercentForCircle(target, circle):
  value         = GetResistSkill(target)                             // = MagicResist - EvilOmen malus
  firstPercent  = value / 5.0;
  secondPercent = value - (((Caster.Skills[CastSkill].Value - 20.0) / 5.0) + (1 + (int)circle) * 5.0);
  return (firstPercent > secondPercent ? firstPercent : secondPercent) / 2.0;   // :76-83
```
Source comment: *"Seems should be about half of what stratics says."* (`:82`).
`GetResistSkill(m) = m.Skills[MagicResist].Value - EvilOmenSpell.GetResistMalus(m)`
(`Spell.cs:439-442`).

`maxSkill` per circle (the value below which a **passive resist gain roll** is attempted):

| Circle (index) | 1 (0) | 2 (1) | 3 (2) | 4 (3) | 5 (4) | 6 (5) | 7 (6) | 8 (7) |
|---|---|---|---|---|---|---|---|---|
| `maxSkill` | 35 | 45 | 55 | 65 | 75 | 85 | 120 | 130 |

Worked example: MagicResist 100, caster Magery 100, 8th circle → `firstPercent = 20`,
`secondPercent = 100 - ((100-20)/5 + 8*5) = 44` → `44/2 = 22` → **22 % resist chance**.
`[SRC]`, arithmetic from `MagerySpell.cs:76-83`.

**Damage reduction.** In **pre-AoS** the resist roll cuts damage by 25 % and prints
501783 — e.g. `Magic Arrow`: `damage = Utility.Random(4, 4); if (CheckResisted(target)) damage *= 0.75;`
(`Scripts/Spells/First/MagicArrow.cs:81-88`), `Fireball`: `Utility.Random(10, 7)` then `*= 0.75`
(`Scripts/Spells/Third/Fireball.cs:67-74`). In **AoS+** damage spells do **not** call
`CheckResisted` at all (it survives only for status effects): e.g. `MagicArrow.cs:75-78` and
`Fireball.cs:61-64` go straight to `GetNewAosDamage(...)` and the resistances pipeline
(§2b.4) applies. `CheckResisted` is still used by `Poison`, `Paralyze`, `ManaDrain`,
`ManaVampire`, `MindBlast`, `Explosion` (delayed), Mysticism and Mastery spells
(`Scripts/Spells/Third/Poison.cs:49`, `Fifth/Paralyze.cs:72`, `Fourth/ManaDrain.cs:75`,
`Seventh/ManaVampire.cs:66`, `Fifth/MindBlast.cs:111`, `Sixth/Explosion.cs:107`).

**Other direct uses of MagicResist in ServUO:**

| Use | Formula | Cite |
|---|---|---|
| Curse stat offset (AoS) | `percent = 8 + (EvalInt.Fixed / 100) - (resistFixed / 100)`, `resistFixed = MagicResist.Fixed - EvilOmenMalus*10`, `*0.01` | `SpellHelper.cs:437-455` |
| Bless/curse offset roll | `target.CheckSkill(MagicResist, 0.0, 120.0)` when cursing | `SpellHelper.cs:466-467` |
| Player minimum elemental resistance (AoS+) | `magicResist = (int)(MagicResist.Value * 10)`; `>=1000` → `40 + (mr-1000)/50`; `>=400` → `(mr-400)/15`; clamped to `MinPlayerResistance..MaxPlayerResistance` = **−70 … 70** | `PlayerMobile.cs:1173-1188`, `Server/Mobile.cs:1023-1029` |
| Blood Oath self-damage | `1 - (((MagicResist.Value * .5) + 10) / 100)` | `AOS.cs:239-258` |
| Reactive Paralyze duration | `max(1, max(8, EvalInt/10) - MagicResist/10)` seconds | `BaseWeapon.cs:1932-1939`, `:1946-1953` |
| Paralyze Field duration | `2.0 + ((int)(EvalInt/10) - (int)(MagicResist/10))` | `Scripts/Spells/Sixth/ParalyzeField.cs:188` |
| Mastery spells | `maxSkill = (1 + volumeMod)*10 + (1 + volumeMod/6)*25`, `volumeMod = GetMasteryLevel()*2`; same percent formula | `Skill Masteries/Core/SkillMasterySpell.cs:335-366` |
| Mastery damage reduction | `reduce = 1.0 - ((casterSkill - resistSkill) / casterSkill)`, clamped 0..1 | `SkillMasterySpell.cs:322-333` |

**Magic reflection (`[ERA]` AoS+):** `SpellHelper.CheckReflect` — if `target.MagicDamageAbsorb > 0`
then `++circle; target.MagicDamageAbsorb -= circle; reflect = (target.MagicDamageAbsorb >= 0);`
(`SpellHelper.cs:1323-1341`); a depleted absorb ends the spell via `DefensiveSpell.Nullify`
(`:1336-1340`). Caster-side disruption avoidance uses the Protection registry value
(`Spell.cs:255-266`) and `CastingFocus` capped at 12 (`Spell.cs:269-283`).

**Passive gains summary `[SRC]`:** the *only* automatic MagicResist gain trigger in the
spell path is inside `CheckResisted`/`GetResistSkill` (below the per-circle `maxSkill`), plus
the curse-offset check above. There is **no** damage-triggered resist gain in
`Server/Mobile.cs` (`grep MagicResist Server/*.cs` → only the enum in `Server/Skills.cs:56`,
the accessor `:747` and a `Utility.cs:1186` list) — a claim that "being hit by spells trains
Resisting Spells" is **not** implemented as an `OnDamage` hook in `pub57`.

---

### 2b.7 (6) WEAPON SKILLS, Archery, Throwing, Wrestling, Tactics `[SRC]`

**Class → skill map** (derived from `DefSkill` overrides):

| Base class | `DefSkill` | Cite |
|---|---|---|
| `BaseSword` | `Swords` | `Scripts/.../BaseSword.cs:18-22` |
| `BaseAxe` | `Swords` | `BaseAxe.cs:41-45` |
| `BaseKnife` | `Swords` | `BaseKnife.cs:32-36` |
| `BasePoleArm` | `Swords` | `BasePoleArm.cs:34-38` |
| `BaseBashing` | `Macing` | `BaseBashing.cs:31-35` |
| `BaseStaff` | `Macing` | `BaseStaff.cs:31-35` |
| `BaseSpear` | `Fencing` | `BaseSpear.cs:31-35` |
| `BaseRanged` | `Archery` (`AccuracySkill = Archery`) | `BaseRanged.cs:20`, `:24` |
| `BaseThrown` (`[ERA SA]`) | `Throwing` | `BaseThrown.cs:100-121` |
| `Fists` | `Wrestling` | `Fists.cs:111-117` |
| `BaseWand` | inherits `BaseBashing` → `Macing` | `BaseWand.cs:25` + `BaseBashing.cs:31-35` |
| per-item overrides | `Dagger`, `Kryss`, `Kama`, `Sai`, `Tekagi`, `Lance`, `Leafblade`, `Shortblade`, `WarCleaver`, `Lajatang`, `AssassinSpike`, `BloodBlade`, `ElvenSpellblade`, Gargish dagger/kryss/lance/tekagi → `Fencing`; `WarAxe` → `Macing`; `BladedStaff` → `Swords` | `Dagger.cs:113-117`, `Kryss.cs:127-131`, `WarAxe.cs:128-132`, `BladedStaff.cs:113-117`, … |

`WeaponType` (`WeaponEnums.cs:5-15`): `Axe, Slashing, Staff, Bashing, Piercing, Polearm,
Ranged, Fists`. Only `WeaponType.Axe` receives the Lumberjacking damage bonus
(`BaseWeapon.cs:3793-3796`) and the passive Lumberjacking skill roll (`:3777-3780`).

**Tactics role.** Three separate jobs:
1. Damage bonus, `0.625 %/point` + `6.25` at 100 (AoS) — `BaseWeapon.cs:3790`;
   `(Tactics - 50)/100` multiplicative (pre-AoS) — `:3845`.
2. Secondary skill requirement for weapon special moves — default `SkillName.Tactics`
   (`WeaponAbility.cs:105-108`), required `70.0` primary / `90.0` secondary
   (`Core.TOL ? 30.0 : 70.0`, `Core.TOL ? 60.0 : 90.0`) (`WeaponAbility.cs:90-103`).
3. Accuracy-level skill mod: `new DefaultSkillMod(AccuracySkill, true, (int)m_AccuracyLevel * 5)`
   → +5 skill per accuracy level (`Regular 0 … Supremely 5`) on Tactics
   (`BaseWeapon.cs:704`, enum `WeaponEnums.cs:27-35`); Archery for bows (`BaseRanged.cs:24`),
   Throwing for thrown (`BaseThrown.cs:116`).

**Archery rules.**
| Rule | Value | Cite |
|---|---|---|
| Must have stood still | `SE 250 ms`, `AoS 500 ms`, pre-AoS `1000 ms` — `NextMovementTime + (Core.SE ? 250 : Core.AoS ? 500 : 1000)` | `BaseRanged.cs:66` |
| Moving exception | `WeaponAbility.GetCurrentAbility(attacker) is MovingShot` bypasses the standstill check | `BaseRanged.cs:71-73` |
| Ammo consumption | `OnFired`: quiver first, then backpack; `ConsumeTotal(AmmoType, 1)`; `LowerAmmoCost` % chance to skip, but only if ammo exists somewhere | `BaseRanged.cs:195-219` |
| Ammo-less specials | `if (ability != null && ability.ConsumeAmmo == false) return true;` | `BaseRanged.cs:187-193` |
| Range | `DefMaxRange` Bow 10, Crossbow 8, Heavy Crossbow 8; thrown weapons: `DefMaxRange = MaxThrowRange = MinThrowRange + 3` | `Bow.cs:119-125`, `Crossbow.cs:119-125`, `HeavyCrossbow.cs:119-125`, `BaseThrown.cs:22-34` |
| Range gate | combat timer refuses the swing unless `InRange(combatant, weapon.MaxRange)` | `Server/Mobile.cs:2070-2073` |
| Ammo recovery | attacker-player, 40 % roll: hit vs non-player animal/monster → ammo to the **victim's** pack (`:118-127`); SE miss → `PlayerMobile.RecoverableAmmo` counter + 10 s timer (`:132-166`); pre-SE miss → ammo drops on the ground (`:167-179`) | `BaseRanged.cs` |
| Paralysis/freeze | same `canSwing` gates as melee | `BaseRanged.cs:76-86` |
| Racial `[ERA SA]` | Gargoyles cannot gain Archery, non-Gargoyles cannot gain Throwing | `SkillCheck.cs:339-343` |

**Wrestling / unarmed.**
- `Fists` is the default weapon for every mobile: `Mobile.DefaultWeapon = new Fists()`
  (`Fists.cs:9-10`), returned when no `IWeapon` is worn (`Server/Mobile.cs:10459-10493`) —
  this is also how a shield-only defender is resolved.
- `AosMinDamage 1 / AosMaxDamage 6 / AosSpeed 50 / MlSpeed 2.50 / OldMin 1 / OldMax 8 / OldSpeed 30`
  (`Fists.cs:38-94`); `GetBaseDamageRange` overrides for non-human bodies to `Str / 28`
  (`BaseWeapon.cs:3614-3619`).
- Defensive value `max(Wrestling, (Anatomy + EvalInt + 20)*0.5 capped 120)` (`Fists.cs:146-160`).
- Special moves: `PrimaryAbility = Disarm`, `SecondaryAbility = ParalyzingBlow`
  (`Fists.cs:16-29`).
- Pre-AoS stun/disarm (`Fists.cs:162-261`, `297-376`): requires `Anatomy >= 80 && Wrestling >= 80`
  for stun, `ArmsLore >= 80 && Wrestling >= 80` for disarm, `Stam >= 15`, free hands
  (`:312-320`), 10 s re-use (`:378-401`); success chance
  `chance = (wresValue + scndValue) / 400.0` → source comment: *"40 % chance at 80, 80;
  50 % at 100, 100; 60 % at 120, 120"* (`:297-309`); stun freezes 4 s (`:183`).
  Both entry points exit immediately when `Core.AOS` (`:324-325`, `:352-353`).
- `[ERA ML]` Wrestling mastery passives: `Knockout` damage bonus by mastery level
  `1 → +25 %/+10 %`, `2 → +50 %/+25 %`, `3 → +100 %/+50 %` (PvM/PvP)
  (`Skill Masteries/Core/MasteryInfo.cs:504-518`).

---

### 2b.8 (7) WEAPON SPECIAL MOVES & SKILL MASTERIES `[SRC]`

**`WeaponAbility` (AoS special moves)** — `Scripts/Abilities/WeaponAbility.cs`:

| Rule | Value | Cite |
|---|---|---|
| Required weapon skill, primary ability | `70.0` | `:78-88` |
| Required weapon skill, secondary ability | `90.0` | `:78-88` |
| Required secondary (Tactics) skill | `Core.TOL ? 30.0 : 70.0` primary / `Core.TOL ? 60.0 : 90.0` secondary | `:90-103` |
| `UseBestSkill` bypass | Swords/Macing/Fencing `Base >= reqSkill` passes | `:180-183` |
| Ability table | 33 abilities, indices 1-33 (`ArmorIgnore … ColdWind`) | `:295-331` |
| Mana discount by skill total | `skillTotal >= 300 → −10`, `>= 200 → −5`; total = Swords+Macing+Fencing+Archery+Parry+Lumberjacking+Stealth+Throwing+Poisoning+Bushido+Ninjitsu | `:110-119`, `:217-223` |
| Mana scalar | `× (1 − LMC/100)` with `LMC = min(AosAttributes.GetValue(LowerManaCost), 40) + BaseArmor.GetInherentLowerManaCost`; MindRot and PurgeMagic raise the scalar | `:121-139` |
| Double mana | another special move within the 3 s context window → `mana *= 2` | `:141-143`, `Timer(3.0)` `:375-391` |
| Ability `BaseMana` (verbatim examples) | `Bladeweave 30`, `Block 20`, `DoubleStrike 30`, `DualWield 20`, `Feint 30`, `ForceArrow 20`, `FrenziedWhirlwind 30`, `ForceOfNature 35`, `InfusedThrow 25`, `PsychicAttack 30` | `Scripts/Abilities/*.cs` at `Bladeweave.cs:41`, `Block.cs:25`, `DoubleStrike.cs:9`, `DualWield.cs:18`, `Feint.cs:19`, `ForceArrow.cs:15`, `FrenziedWhirlwind.cs:27`, `ForceofNature.cs:13`, `InfusedThrow.cs:12`, `PsychicAttack.cs:12` |
| `ArmorIgnore` | `BaseMana 30`, `DamageScalar 0.9` | `ArmorIgnore.cs:16-29` |
| Validate gates | Honorable Execution penalty, Animal Form, `Core.ML && from.Spell != null` | `:280-290` |

**`SpecialMove` (`[ERA]` SE Bushido/Ninjitsu moves, and the same class backs ML masteries)** —
`Scripts/Spells/Base/SpecialMove.cs`:
`Minimum required skill = RequiredSkill` (`:29-35`, `:117-127`);
`ScaleMana` = `mana × (1 − LMC/100)`, doubled when `MoveSkill < 50 && context != null`
(`:129-162`); context window `3.0 s` (`:375-391`); `CheckGain` rolls
`m.CheckSkill(MoveSkill, RequiredSkill, RequiredSkill + 37.5)` (`:219-222`).

Bushido move constants (`Scripts/Spells/Bushido/`):

| Move | BaseMana | RequiredSkill | Effect constant | Cite |
|---|---|---|---|---|
| `LightningStrike` | `Core.SA ? 10 : 5` | `50.0` | `GetAccuracyBonus = 50`; crit `(bushido²)/72000.0` → armour ignore; UI crit % = `(bushido²)/720.0` | `LightningStrike.cs:12-18`, `:47-50`, `:66-71`, `:118-119` |
| `MomentumStrike` | `10` | `70.0` | `damageBonus = Bushido/100.0`, `×1.5` if the primary target died; `CheckGain(MoveSkill, 70.0, 120.0)` | `MomentumStrike.cs:13-26`, `:61-66`, `:104-107` |
| `Evasion` | `10` | `60.0` | see §2b.5 | `Evasion.cs:26-39` |
| `CounterAttack` | — | — | triggered inside `AbsorbDamageAOS` on a successful parry, requires `InRange(attacker,1)` | `BaseWeapon.cs:1898-1912` |
| `Confidence` | — | — | on parry: HP `RandomMinMax(1, bushido/12)`, Stam `RandomMinMax(1, bushido/5)`, plus `AnticipateHitBonus/10` | `BaseWeapon.cs:1914-1923` |
| Honorable Execution penalty removal on block | — | — | `HonorableExecution.RemovePenalty(defender)` | `BaseWeapon.cs:1895-1896` |

`SamuraiSpell` gates (`Scripts/Spells/Bushido/SamuraiSpell.cs`): `CastSkill = DamageSkill = Bushido`
(`:16-29`), `CastDelayFastScalar = 0` (no faster-casting benefit) (`:52-58`),
`CastRecoveryBase = 7` (`:59-65`), `CheckExpansion` requires `Core.SE` (`:66-78`),
`GetCastSkills: min = RequiredSkill - 12.5; max = RequiredSkill + 37.5` (`:139-143`),
`GetMana() = 0` (mana charged via `RequiredMana` in `CheckFizzle`) (`:116-148`).

**Skill Masteries (`[ERA]` post-SA; exact introducing publish [UNVERIFIED])** —
`Scripts/Spells/Skill Masteries/Core/`:

| Rule | Value | Cite |
|---|---|---|
| Minimum skill to learn any mastery | `MasteryInfo.MinSkillRequirement = 90` | `MasteryInfo.cs:33`, `:221-231` |
| Mastery skill list (19 skills) | Peacemaking, Provocation, Discordance, Magery, Mysticism, Necromancy, Spellweaving, Bushido, Chivalry, Ninjitsu, Fencing, Macing, Swords, Throwing, Parry, Poisoning, Wrestling, AnimalTaming, Archery | `MasteryInfo.cs:555-576` |
| Mastery spell IDs | 700-744 (2 masteries per mastery skill, 3 for Parry, plus 7 passive masteries) | `MasteryInfo.cs:41-118`, `Spells/Initializer.cs:184-231` |
| Passive masteries | `714 EnchantedSummoning`, `715 AnticipateHit`, `717 Intuition`, `732 SavingThrow`, `738 Potency`, `741 Knockout`, `744 Boarding` | `MasteryInfo.cs:244-247` |
| Base values | `RequiredSkill = 90.0`, `RequiredMana = 10`, `UpKeep = 0`, `PartyRange = 12`, `DamageThreshold = 45`, `TickTime = 2`, `ExpirationPeriod = 30 min`, `CastDelayBase = 2.25 s` | `SkillMasterySpell.cs:29-48` |
| `BaseSkillBonus` | `(CastSkill + DamageSkill + GetMasteryLevel()*40) / 3` | `SkillMasterySpell.cs:50-59` |
| Cast skill window | `min = RequiredSkill; max = RequiredSkill + 25.0` | `SkillMasterySpell.cs:120-124` |
| Mastery level source | `m.Skills[name].VolumeLearned` → 0..3 | `MasteryInfo.cs:216-219` |
| Passive bonus examples | `AnticipateHitBonus = (int)(Bushido * .67)`; `IntuitionBonus = (MasteryLevel*40)/8`; `EnchantedSummoningBonus = (skill + level*40)/16`; `NonPoisonConsumeChance = (Poisoning + Anatomy + level*20)/4.375` | `MasteryInfo.cs:457-502` |

---

### 2b.9 (7) MAGERY — cast flow end to end `[SRC]`

**9.1 Cast pipeline.** `Spell.Cast()` (`Scripts/Spells/Base/Spell.cs:725-868`) →
`CastTimer` (`:1330-1383`) → `CheckSequence()` (`:1110-1214`) → `OnCast()` (`:870`).

| Gate (in order) | Check | Cite |
|---|---|---|
| sequencing spell disturbed | previous spell in `SpellState.Sequencing` → `Disturb(NewCast)` (AoS) | `Spell.cs:729-732` |
| alive | `!m_Caster.CheckAlive()` → abort | `:734-737` |
| peacemaking | `Peaced` → 1072060 | `:738-741`, `:763-766` |
| already casting | 502642 | `:746-749` |
| forbidden form | Horrific Beast / Animal Form → 1061091 | `:750-754` |
| frozen/paralyzed (non-wand) | 502643 | `:755-758` |
| recovery timer | `Core.TickCount - m_Caster.NextSpellTime < 0` → **502644 "You have not yet recovered from casting a spell."** | `:759-762` |
| mana (pre-check) | `m_Caster.Mana >= ScaleMana(GetMana())` else 502625 with the shortfall | `:767`, `:862-865` |
| gargoyle flight `[ERA SA]` | may not cast over "precarious terrain" | `:769-785` |
| region/shard veto | `CheckSpellCast`, `CheckCast`, `Region.OnBeginSpellCast` | `:787-788` |
| start | `m_State = SpellState.Casting`, `m_Caster.Spell = this`, mantra, animation, `ClearHands()` | `:790-834` |
| cast timer | `castDelay = GetCastDelay() - 100 ms` (source comment: *"EA seems to use some type of spell variation, of -100 ms"*) | `:802-808`, `:841-853` |
| timer expiry | state → `Sequencing`, `NextSpellTime = TickCount + GetCastRecovery()` | `:1348-1361` |
| target timeout | new player target → `BeginTimeout(..., 30.0 s)` | `:1370-1373` |

**9.2 Mana, reagents, fizzle — `Spell.CheckSequence()` verbatim order** (`Spell.cs:1110-1214`):

```
int mana = ScaleMana(GetMana());                                  // :1112
1. caster deleted/dead, or caster.Spell != this, or state != Sequencing  → DoFizzle()      // :1114-1117
2. scroll invalid/deleted/not carried, or wand charges <= 0               → DoFizzle()      // :1118-1123
3. !ConsumeReagents()  → 502630 "More reagents are needed for this spell."  (NO mana, NO fizzle) // :1124-1127
4. m_Caster.Mana < mana → 502625 "Insufficient mana for this spell."        (NO mana spent)      // :1128-1131
5. Core.AOS && (Frozen || Paralyzed) → 502646 then DoFizzle()                                    // :1132-1136
6. PeacedUntil > now → 1072060 then DoFizzle()                                                   // :1137-1141
7. CheckFizzle() == false → DoFizzle()      (REAGENTS ALREADY CONSUMED at step 3)                // :1208-1211
8. success → m_Caster.Mana -= mana; scroll/wand consumed; ClearHands(); karma; garlic burn       // :1142-1206
```
So: **a skill fizzle costs reagents but not mana**; **missing reagents costs neither** but the
cast still ends (the delay was already spent). Immunity to disturbance comes from
`ProtectionSpell.Registry` (`:255-266`) or `CastingFocus` capped at 12 plus
`Inscribe >= 50 ? GetInscribeFixed/200 : 0` (`:269-283`).

**Mana cost** — `MagerySpell.GetMana` / `m_ManaTable` (`MagerySpell.cs:8`, `:47-53`):
`{ 4, 6, 9, 11, 14, 20, 40, 50 }` indexed by `(int)Circle`, returns `0` for `BaseWand`.
`Spell.ScaleMana` (`Spell.cs:947-980`):
```
ManaPhasingOrb active → 0
scalar = MindRot scalar (default 1.0); +0.5 under PurgeMagic curse
lmc = min(AosAttributes.GetValue(LowerManaCost), 40) + BaseArmor.GetInherentLowerManaCost(m)
scalar -= lmc / 100.0
return (int)(mana * scalar)
```
Inherent LMC `[ERA SA]` (`BaseArmor.cs:588-615`): Studded/Bone/Stone `+3`, Ringmail/Chainmail/Plate/Dragon
`+1` each, skipped for MageArmor / Wood / shields.

**Reagents** — `SpellInfo` stores `Type[] Reagents` with `Amounts[i] = 1` for every entry
(`SpellInfo.cs:44-59`). `Spell.ConsumeReagents` (`Spell.cs:386-411`):
```
if ((m_Scroll != null && !(m_Scroll is SpellStone)) || !m_Caster.Player) return true;
if (AosAttributes.GetValue(m_Caster, AosAttribute.LowerRegCost) > Utility.Random(100)) return true;  // LRC %
if (pack == null) return false;
return pack.ConsumeTotal(m_Info.Reagents, m_Info.Amounts) != -1;                                   // :405
```
`MagerySpell` adds the arcane-gem fallback: `ArcaneGem.ConsumeCharges(Caster, Core.SE ? 1 : 1 + (int)Circle)`
which scans worn `IArcaneEquip` items and deducts charges (`MagerySpell.cs:23-32`,
`Scripts/Items/Resource/ArcaneGem.cs:35-69`).

| Circle | Spell (registry id) | Mantra | Reagents | Cite |
|---|---|---|---|---|
| 1st | Magic Arrow (04) | In Por Ylem | SulfurousAsh | `First/MagicArrow.cs:8-12`, `Initializer.cs:14` |
| 2nd | Harm (11) | An Mani | Nightshade, SpidersSilk | `Second/Harm.cs:8-13`, `Initializer.cs:23` |
| 3rd | Fireball (17) | Vas Flam | BlackPearl | `Third/Fireball.cs:8-12`, `Initializer.cs:31` |
| 4th | Lightning (29) | Por Ort Grav | MandrakeRoot, SulfurousAsh | `Fourth/Lightning.cs:9-14`, `Initializer.cs:45` |
| 5th | Mind Blast (36) | Por Corp Wis | BlackPearl, MandrakeRoot, Nightshade, SulfurousAsh | `Fifth/MindBlast.cs:8-15`, `Initializer.cs:54` |
| 6th | Energy Bolt (41) | Corp Por | BlackPearl, Nightshade | `Sixth/EnergyBolt.cs:8-13`, `Initializer.cs:61` |
| 7th | Flame Strike (50) | Kal Vas Flam | SpidersSilk, SulfurousAsh | `Seventh/FlameStrike.cs:8-13`, `Initializer.cs:72` |
| 8th | Earthquake (56) | In Vas Por | Bloodmoss, Ginseng, MandrakeRoot, SulfurousAsh | `Eighth/Earthquake.cs:10-18`, `Initializer.cs:80` |

Full circle membership (8 spells each, ids 0-63) is in `Scripts/Spells/Initializer.cs:10-87`.

**Cast delay** — `MagerySpell.CastDelayBase` = `TimeSpan.FromMilliseconds(((4 + (int)Circle) * CastDelaySecondsPerTick) * 1000)`
with `CastDelaySecondsPerTick = 0.25` (`MagerySpell.cs:16-22`, `Spell.cs:1027-1029`):
`base = (4 + circleIndex) * 0.25 s`. Pre-AoS override:
`if (!Core.AOS) return TimeSpan.FromSeconds(0.5 + (0.25 * (int)Circle));` (`MagerySpell.cs:95-97`).
`Spell.GetCastDelay` (`Spell.cs:1031-1086`):
```
fcMax = 4;  if (CastSkill is Magery|Necromancy|Mysticism
                 || (Chivalry && (Magery >= 70 || Mysticism >= 70))) fcMax = 2;   // :1047-1053
fc = min(AosAttributes.GetValue(CastSpeed), fcMax);                                // :1055-1060
if (Protection active || Eodonian Urali potion) fc = Math.Min(fcMax - 2, fc - 2);  // :1062-1065
delay = CastDelayBase - (CastDelayFastScalar(1) * fc * 0.25 s);                    // :1069-1072
if (delay < CastDelayMinimum (0.25 s)) delay = CastDelayMinimum;                   // :1074-1077
wand: Core.ML ? CastDelayBase : TimeSpan.Zero;   SpellStone: TimeSpan.Zero           // :1033-1041
```

| Circle | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| AoS+ base (s) | 1.00 | 1.25 | 1.50 | 1.75 | 2.00 | 2.25 | 2.50 | 2.75 |
| with FC 2 (s) | 0.50 | 0.75 | 1.00 | 1.25 | 1.50 | 1.75 | 2.00 | 2.25 |
| with Protection active (no FC items, s) | 1.50 | 1.75 | 2.00 | 2.25 | 2.50 | 2.75 | 3.00 | 3.25 |
| pre-AoS (`0.5 + 0.25*circle`, s) | 0.50 | 0.75 | 1.00 | 1.25 | 1.50 | 1.75 | 2.00 | 2.25 |

**"You must wait" / recovery** — `Spell.GetCastRecovery` (`Spell.cs:999-1023`):
```
CastRecoveryBase = 6; CastRecoveryFastScalar = 1; CastRecoveryPerSecond = 4; CastRecoveryMinimum = 0;
!Core.AOS → NextSpellDelay = TimeSpan.FromSeconds(0.75)   // :49, :1006-1009
AoS      → delay = clamp(6 - FCR, min 0); return delay / 4.0 seconds   // :1011-1022
```
→ FCR 0: `1.50 s`, FCR 2: `1.00 s`, FCR 6: `0.00 s`. Disturbance recovery (pre-AoS only):
`delay = 1.0 - Math.Sqrt(elapsedSeconds / castDelaySeconds)`, floor `0.2 s`; AoS returns
`TimeSpan.Zero` (`:982-997`).

**9.3 Circle gating by skill (the fizzle curve).** There is **no hard gate**; the gate is the
`min` term of `CheckSkill(CastSkill, min, max)`, which auto-fails below `min`.
`MagerySpell.GetCastSkills` (`MagerySpell.cs:34-45`):
```
int circle = (int)Circle;
if (Scroll != null) circle -= 2;                 // scrolls shift the requirement down 2 circles
double avg = ChanceLength * circle;              // ChanceLength = 100.0 / 7.0        (:9)
min = avg - ChanceOffset;                        // ChanceOffset = 20.0               (:9)
max = avg + ChanceOffset;
```

| Circle | ServUO `min` (no scroll) | ServUO `max` | chance at 0 Magery | chance at 50 | chance at 100 | with scroll (−2) |
|---|---|---|---|---|---|---|
| 1 (0) | −20.00 | 20.00 | 50.0 % | 100 % (auto) | 100 % | −48.57 / −8.57 |
| 2 (1) | −5.71 | 34.29 | 14.3 % | 100 % (auto) | 100 % | −34.29 / 5.71 |
| 3 (2) | 8.57 | 48.57 | 0 % (auto-fail) | 100 % (auto) | 100 % | −20.00 / 20.00 |
| 4 (3) | 22.86 | 62.86 | 0 % | 67.9 % | 100 % | −5.71 / 34.29 |
| 5 (4) | 37.14 | 77.14 | 0 % | 32.1 % | 100 % | 8.57 / 48.57 |
| 6 (5) | 51.43 | 91.43 | 0 % | 0 % (auto-fail) | 100 % | 22.86 / 62.86 |
| 7 (6) | 65.71 | 105.71 | 0 % | 0 % | 85.4 % | 37.14 / 77.14 |
| 8 (7) | **80.00** | **120.00** | 0 % | 0 % | **50.0 %** | 51.43 / 91.43 |

Chance = `(Magery − min) / (max − min)`, from `SkillCheck.cs:153` / `:306`; `Magery < min`
auto-fails (`SkillCheck.cs:147-148`), `Magery >= max` auto-succeeds (`:150-151`).

**ModernUO disagrees — and says so in a comment** (`ModernUO:Projects/UOContent/Spells/Base/MagerySpell.cs:30-43`):
```
// Original RunUO algorithm for required skill
// const double chanceOffset = 20.0
// const double chanceLength = 100.0 / 7.0
// ...
// Correct algorithm according to OSI for UOR/UOML
// TODO: Verify this algorithm on OSI for latest expansion.
min = _requiredSkill[(int)(Scroll == null ? Circle + 2 : Circle)];
max = min + 40;
```
with
```
_requiredSkill = Core.ML
  ? new[] { -46.0, -32.0, -18.0, -4.0, 10.0, 24.0, 38.0, 52.0, 66.0, 80.0 }
  : new[] { -50.0, -30.0,  0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0 };   // :15-17
```

| Circle | ModernUO non-ML `min`/`max` | ModernUO ML `min`/`max` | ServUO `min`/`max` |
|---|---|---|---|
| 1 | 0.0 / 40.0 | −18.0 / 22.0 | −20.0 / 20.0 |
| 2 | 10.0 / 50.0 | −4.0 / 36.0 | −5.71 / 34.29 |
| 3 | 20.0 / 60.0 | 10.0 / 50.0 | 8.57 / 48.57 |
| 4 | 30.0 / 70.0 | 24.0 / 64.0 | 22.86 / 62.86 |
| 5 | 40.0 / 80.0 | 38.0 / 78.0 | 37.14 / 77.14 |
| 6 | 50.0 / 90.0 | 52.0 / 92.0 | 51.43 / 91.43 |
| 7 | 60.0 / 100.0 | 66.0 / 106.0 | 65.71 / 105.71 |
| 8 | **70.0 / 110.0** | **80.0 / 120.0** | **80.0 / 120.0** |

So the two servers agree on the 8th circle **only under ML**; on a non-ML shard ModernUO lets
8th circle start at 70 Magery where ServUO still auto-fails below 80. `[SRC]` both.
Scrolls: ModernUO indexes by `Circle` (no −2 offset in the array) → 8th-circle scroll min 50 /
max 90 (non-ML) or 66 / 106 (ML) (`MagerySpell.cs:15-17`, `:41`).

**Legacy `GetCastSkills` for other schools:** `SamuraiSpell` = `RequiredSkill − 12.5 … + 37.5`
(`SamuraiSpell.cs:139-143`); `SkillMasterySpell` = `RequiredSkill … + 25.0`
(`SkillMasterySpell.cs:120-124`); base `Spell.GetCastSkills` = `0, 0`
(`Spell.cs:919-922`), which makes non-overriding spells always succeed except when
`min == max == 0` → `value >= maxSkill` → auto-success (`SkillCheck.cs:150-151`).

**9.4 Fizzle chance and what EvalInt does *not* do.** `Spell.CheckFizzle` (`Spell.cs:924-943`):
```
if (m_Scroll is BaseWand) return true;                                     // wands never fizzle
GetCastSkills(out minSkill, out maxSkill);
if (DamageSkill != CastSkill && DamageSkill != SkillName.Imbuing)
    Caster.CheckSkill(DamageSkill, 0.0, Caster.Skills[DamageSkill].Cap);   // EvalInt: GAIN ROLL ONLY
bool skillCheck = Caster.CheckSkill(CastSkill, minSkill, maxSkill);        // the actual fizzle roll
return Caster is BaseCreature || skillCheck;                               // NPC casters never fizzle
```
**There is no EvalInt term in the fizzle formula** in `pub57`. `EvalInt` appears in the spell
code in exactly six places (`grep EvalInt Scripts/Spells`): the `DamageSkill` default
(`Spell.cs:53`), the pre-AoS damage scalar (`Spell.cs:451-473`), spell duration
(`SpellHelper.cs:413-426`), curse/bless offset percent (`SpellHelper.cs:437-455`),
`ParalyzeField` duration (`ParalyzeField.cs:188`), and the Protection spell value
(`Protection.cs:145-151`). A "EvalInt reduces fizzle chance" rule is therefore
`[WEB]-only` and contradicted by `pub57` → treat as **not implemented**.

**9.5 EvalInt inside AoS spell damage** — `Spell.GetNewAosDamage` (`Spell.cs:218-239`), verbatim:
```
int damage = Utility.Dice(dice, sides, bonus) * 100;
int inscribeSkill = GetInscribeFixed(m_Caster);                       // Inscribe * 10
int scribeBonus = inscribeSkill >= 1000 ? 10 : inscribeSkill / 200;   // 5 at GM, 10 at 100+
int damageBonus = scribeBonus + (Caster.Int / 10)
                + SpellHelper.GetSpellDamageBonus(m_Caster, target, CastSkill, playerVsPlayer);
int evalSkill = GetDamageFixed(m_Caster);                             // EvalInt * 10
int evalScale = 30 + ((9 * evalSkill) / 100);                         // == 30 + 0.9 * EvalInt
damage = AOS.Scale(damage, evalScale);
damage = AOS.Scale(damage, 100 + damageBonus);
damage = AOS.Scale(damage, (int)(scalar * 100));
return damage / 100;
```

| EvalInt | `evalScale` | damage multiplier |
|---|---|---|
| 0 | 30 | 0.30× |
| 50 | 75 | 0.75× |
| 100 | 120 | 1.20× |
| 120 | 138 | 1.38× |

`SpellHelper.GetSpellDamageBonus` (`SpellHelper.cs:123-144`): SDI from items, minus 10 under
Runed Sash of Warding, minus `Block.GetSpellReduction`, and in PvP capped by
`PvPSpellDamageCap` = `15` (`Core.SA` off) / `30` if spell-focused / `Core.TOL ? 20 : 15`
(`SpellHelper.cs:108-121`).
**Pre-AoS** (`GetDamageScalar`, `Spell.cs:444-479`):
```
if (casterEI > targetRS) scalar = 1.0 + ((casterEI - targetRS) / 500.0);
else                     scalar = 1.0 + ((casterEI - targetRS) / 200.0);
scalar += (Caster.Skills[CastSkill].Value - 100.0) / 400.0;   // -25% at 0, 0% at 100, +5% at 120
if (!target.Player && !target.Body.IsHuman) scalar *= 2.0;    // double magery vs monsters
```

**9.6 Other EvalInt effects (for completeness):**

| Effect | Formula | Cite |
|---|---|---|
| AoS spell duration (curses etc.) | `span = ((6 * EvalInt.Fixed) / 50) + 1` seconds = `1.2 * EvalInt + 1` s; pre-AoS `Magery * 1.2` s | `SpellHelper.cs:413-426` |
| Curse stat offset | `percent = (8 + EvalInt.Fixed/100 − MagicResist.Fixed/100) * 0.01` | `SpellHelper.cs:443-449` |
| Bless stat offset | `percent = (1 + EvalInt.Fixed/100) * 0.01` | `SpellHelper.cs:446-447` |
| Protection value | `(EvalInt + Meditation + Inscribe) / 4`, clamped `0..75`, used as % chance to ignore disruption | `Protection.cs:145-153`, `Spell.cs:255-266` |
| `[ERA ML]` Mastery damage skills | `DeathRay`/`EtherealBurst` set `DamageSkill = EvalInt` | `Skill Masteries/DeathRay.cs:42`, `EtherealBurst.cs:27` |
| Passive gain | every cast rolls `CheckSkill(EvalInt, 0.0, cap)` (anti-macro **on**, `SkillCheck.cs:78`) | `Spell.cs:935-938` |

---

### 2b.10 (8) MEDITATION & MANA REGENERATION `[SRC]`

**Entering the trance** — `Scripts/Skills/Meditation.cs:30-104`:
| Rule | Value | Cite |
|---|---|---|
| Busy targeting | 501845, 5 s cooldown | `:34-39` |
| pre-AoS low health | `Hits < HitsMax / 10` → 501849, 5 s | `:40-45` |
| already full | `Mana >= ManaMax` → 501846, retry `AoS ? 10 s : 5 s` | `:46-51` |
| AoS armour block | `RegenRates.GetArmorOffset(m) > 0` → 500135, 10 s | `:52-57` |
| AoS auto-unequip | non-meditation items moved to the backpack | `:63-70` |
| pre-AoS hands | must hold nothing (or spellbook/runebook/spell-channelling) → 502626, 2.5 s | `:71-76`, `:13-28` |
| **success chance** | `chance = (50.0 + ((skillVal - (ManaMax - Mana)) * 2)) / 100` | `:78-79` |
| on success | `CheckSkill(Meditation, 0.0, 100.0)`, `Meditating = true`, buff, sound 0xF9, `ResetStatTimers()` | `:84-96` |
| retry delay | 10 s | `:102` |

So the trance always succeeds once `Meditation >= 25 + (ManaMax − Mana)`, and is 50 % at
`skill == ManaMax − Mana`.

**Armour offset** — `RegenRates.GetArmorOffset(from) = rating / 4` (`RegenRates.cs:36-51`) where
each piece contributes (`GetArmorMeditationValue`, `:298-313`): `0` if `MageArmor != 0` or
`SpellChanneling != 0`; else `None → BaseArmorRatingScaled`, `Half → /2`, `All → 0`.
Pre-AoS also counts the shield; AoS+ does not (`:40-41`).

**Mana regeneration rate** — `RegenRates.Mobile_ManaRegenRate` (`:110-209`); the returned
`TimeSpan` is the delay between +1 mana ticks. Passive gain rolls:
`if (!from.Meditating) CheckBonusSkill(from, Mana, ManaMax, SkillName.Meditation)` (`:115-116`)
with `n = cur/max; v = Math.Sqrt(skill * 0.005); n = n*(1-v) + v; CheckSkill(skill, n)`
(`:53-65`); under ML the same roll is done for **Focus** instead (`:129`).

| Era | Formula (verbatim) | Cite |
|---|---|---|
| **ML** | `focusBonus = focus / 200;`<br>`if (armorPenalty == 0) { medBonus = (0.0075 * med) + (0.0025 * from.Int); if (medBonus >= 100.0) medBonus *= 1.1; if (from.Meditating) medBonus *= 2; }`<br>`itemBase = ((((med / 2) + (focus / 4)) / 90) * .65) + 2.35;`<br>`intensityBonus = Math.Sqrt(ManaRegen(from)); if (intensityBonus > 5.5) intensityBonus = 5.5;`<br>`itemBonus = ((itemBase * intensityBonus) - (itemBase - 1)) / 10;`<br>`rate = 1.0 / (0.2 + focusBonus + medBonus + itemBonus);` | `RegenRates.cs:121-153` |
| **AoS, pre-ML** | `medPoints = Int + (Meditation * 3);`<br>`medPoints *= (Meditation < 100.0) ? 0.025 : 0.0275;`<br>`focusPoints = Focus * 0.05;`<br>`if (armorPenalty > 0) medPoints = 0;`<br>`totalPoints = focusPoints + medPoints + (Meditating ? min(medPoints, 13.0) : 0.0) + ManaRegen(from);`<br>`if (totalPoints < -1) totalPoints = -1;`<br>`rate = 1.0 / (0.1 * (2 + totalPoints));` | `RegenRates.cs:154-178` |
| **pre-AoS** | `medPoints = (Int + Meditation) * 0.5;`<br>`<= 0 → rate 7.0; <= 100 → rate = 7.0 - (239*medPoints/2400) + (19*medPoints*medPoints/48000); < 120 → 1.0; else 0.75;`<br>`rate += armorPenalty; if (Meditating) rate *= 0.5; clamp 0.5 .. 7.0;` | `RegenRates.cs:179-201` |
| default rate | `Mobile.DefaultManaRate = 7.0 s` when `Skills == null` or the result is `NaN` | `RegenRates.cs:25`, `:112-113`, `:203-206` |

`ManaRegen(from)` item/mana-regen points (`:274-296`): `AosAttribute.RegenMana` + creature base
+ `VampiricEmbrace +3` / `LichForm +13` + Gargoyle `+2` + handlers; pre-ML players capped at
`18`. Mana regen buffs from masteries are added in the handler lists (`:234-235`, `:262`).

**Worked examples** (Int 100, Meditation 100, Focus 100, no items, ML, standing still):

| Case | Computation | `rate` (s per +1 mana) |
|---|---|---|
| no armour, not meditating | `focusBonus = 0.5`; `medBonus = 0.75 + 0.25 = 1.0`; `itemBase = ((50+25)/90)*0.65 + 2.35 = 2.8917`; `intensityBonus = sqrt(0) = 0`; `itemBonus = (0 - 1.8917)/10 = -0.1892`; `rate = 1/(0.2+0.5+1.0-0.1892)` | **0.663 s** |
| no armour, meditating | `medBonus *= 2 → 2.0`; `rate = 1/(0.2+0.5+2.0-0.1892)` | **0.398 s** |
| armour offset > 0 | `medBonus = 0` → `rate = 1/(0.2+0.5-0.1892)` | **1.958 s** |

AoS pre-ML equivalent (Int 100, Med 100, Focus 100, no armour, not meditating):
`medPoints = (100 + 300) * 0.0275 = 11.0`; `focusPoints = 5.0`; `totalPoints = 16.0`;
`rate = 1/(0.1 * 18) = 0.556 s`. Meditating: `+ min(11, 13) = 11` → `totalPoints = 27` →
`rate = 0.270 s`. `[SRC]` arithmetic from `RegenRates.cs:154-178`.

Companion rates: hits `1.0 / (0.1 * (1 + HitPointRegen))` (`:77-80`),
stamina `1.0 / (0.1 * (2 + Focus*0.1 + StamRegen))` (`:82-108`, `Core.SA` variant
`1.0 / (1.42 + bonus/100)` with `×1.95` for monsters).

---

### 2b.11 (9) EVALUATING INTELLIGENCE `[SRC]`

Two different jobs — **spell damage** (as `DamageSkill`) and **information** (as a targeted skill).

| Job | Formula / constant | Cite |
|---|---|---|
| Spell damage multiplier | `evalScale = 30 + ((9 * EvalInt.Fixed) / 100)` = `30 + 0.9 * EvalInt`; applied as `AOS.Scale(damage, evalScale)` | `Spell.cs:231-234` |
| Pre-AoS damage scalar | `1.0 + (EvalInt − MagicResist)/500` when EvalInt is higher, else `/200`; `%2` vs monsters | `Spell.cs:451-479` |
| Passive EvalInt gain | every cast where `DamageSkill != CastSkill` → `CheckSkill(EvalInt, 0, cap)` | `Spell.cs:935-938` |
| Curse duration | `1.2 * EvalInt + 1` seconds (AoS) | `SpellHelper.cs:415-422` |
| Curse offset | `(8 + EvalInt/10 − MagicResist/10) %` of the raw stat, `Math.Ceiling` | `SpellHelper.cs:443-479` |
| Protection value | `(EvalInt + Meditation + Inscribe)/4` clamped `0..75` | `Protection.cs:145-153` |
| Target reading | `marginOfError = Math.Max(0, 20 - (int)(EvalInt / 5))`; `intel = Int ± moe`; `mana% = (Mana*100)/max(ManaMax,1) ± moe`; bands `intMod = intel/10` clamped 0..10 | `Scripts/Skills/EvalInt.cs:49-79` |
| Reveal at | base `>= 76.0` shows the mana band 1038202+`mnMod` (needs a successful `CheckTargetSkill(EvalInt, targ, 0.0, 120.0)`) | `EvalInt.cs:74-79` |
| Skill check window | `CheckTargetSkill(SkillName.EvalInt, targ, 0.0, 120.0)` → `chance = value/120` | `EvalInt.cs:74`, `SkillCheck.cs:306` |
| Circle gating | **EvalInt plays no part** in `GetCastSkills`/`CheckFizzle`; `CastSkill` (Magery) and `DamageSkill` (EvalInt) are separate properties | `Spell.cs:52-53`, `MagerySpell.cs:34-45` |
| Reactive Paralyze duration | `max(1, max(8, EvalInt/10) − MagicResist/10)` s | `BaseWeapon.cs:1934`, `:1948` |
| Paralyze Field duration | `2.0 + ((int)(EvalInt/10) − (int)(MagicResist/10))` | `ParalyzeField.cs:188` |
| `[ERA ML]` masteries | `DeathRay.DamageSkill = EvalInt`, `EtherealBurst.DamageSkill = EvalInt`; `FistsOfFury` picks the higher of Anatomy/EvalInt as its damage skill | `DeathRay.cs:42`, `EtherealBurst.cs:27`, `FistsOfFury.cs:50` |

There is **no** EvalInt-based circle gate and **no** EvalInt-based fizzle reduction: the
"EvalInt lets you cast higher circles" claim is `[WEB]` and **not implemented** in `pub57`.

---

### 2b.12 (10) ARMS LORE — output thresholds `[SRC]`

`Scripts/Skills/ArmsLore.cs`; target range 2, `AllowNonlocal = true` (`:28-32`);
entry `CheckTargetSkill(ArmsLore, targeted, 0, 100)` on every branch (`:38`, `:99`, `:144`),
failure message 500353 *"You are not certain…"* (`:94`, `:137`, `:157`).

| Output | Formula | Cite |
|---|---|---|
| Weapon/armour condition band (10 levels) | `hp = (int)((HitPoints / (double)MaxHitPoints) * 10)` clamped `0..9` → cline `1038285 + hp`; skipped when `MaxHitPoints == 0` | `:42-52`, `:103-113` |
| Weapon damage band | `damage = (MaxDamage + MinDamage) / 2`; `if (damage < 3) damage = 0; else damage = (int)Math.Ceiling(Math.Min(damage, 30) / 5.0);` → 0,1,2,3,4,5,6 | `:54-60` |
| One/two-handed offset | `hand = (weap.Layer == Layer.OneHanded ? 0 : 1)` | `:55` |
| Weapon type text | Ranged `1038224 + damage*9`; Piercing `1038218 + hand + damage*9`; Slashing `1038220 + …`; Bashing `1038222 + …`; else `1038216 + …` | `:76-87` |
| Poison note | `weap.Poison != null && weap.PoisonCharges > 0` → 1038284 | `:89-90` |
| Armour rating band | `1038295 + (int)Math.Ceiling(Math.Min(arm.ArmorRating, 35) / 5.0)` → 0..7 | `:115` |
| Swamp dragon barding | `perc = (4 * BardingHP) / BardingMaxHP` clamped `0..4` → `1053021 - perc` | `:140-153` |
| Non-weapon/armour | 500352 *"This is neither weapon nor armor."* | `:160-163` |

The commented-out *legacy* brackets (`damage < 6 → 1`, `< 11 → 2`, … `< 26 → 5`, else 6;
armour `< 1, < 6, < 11, < 16, < 21, < 26, < 31, else`) are preserved in source
(`:61-74`, `:116-133`) and are **dead code** — the live implementation is the `Ceiling(min/5)`
form above. The band count (7 weapon bands `0..6`, 8 armour bands `0..7`) agrees with both
formulations. `[WEB]` UOGuide documents the same qualitative ladder
([UOGuide — Arms Lore](https://www.uoguide.com/Arms_Lore)); the exact cliloc strings are `[SRC]`.

---

### 2b.13 (11) SUMMARY TABLE

| Skill | Governs | Check function | Key formula | Clamps / caps |
|---|---|---|---|---|
| Swords / Macing / Fencing | melee attack roll; weapon special-move gate; defence roll of the *defender* | `BaseWeapon.CheckHit` `BaseWeapon.cs:1415`; `WeaponAbility.CheckWeaponSkill` `WeaponAbility.cs:148` | `chance = ourValue / (theirValue * 2.0)`, `ourValue = (atkValue+20)*(100+HCI)`, `theirValue = (defValue+20)*(100+DCI)` (AoS) / `atkValue+50`, `defValue+50` (pre-AoS) | AoS: values clamped at `−20 → −19.9`, `chance ≥ 0.02`; HCI cap `45` (`50` Gargoyle); DCI cap `45 + refined`; pre-AoS: `−50 → −49.9`, no floor |
| Archery | same attack roll + ammo + standstill | `BaseRanged.OnSwing` `BaseRanged.cs:61`; `BaseRanged.OnFired` `:185` | standstill `SE 250 / AoS 500 / pre-AoS 1000 ms`; ammo `ConsumeTotal(AmmoType,1)`; recovery 40 % | range Bow `10`, XBow `8`; `LowerAmmoCost` % skip; `MovingShot` bypasses standstill |
| Throwing `[ERA SA]` | same attack roll, Gargoyle-only gain | `BaseThrown` + `CheckHit` `:1492-1528` | close quarters `−0.12 + min(12,(Throwing+RawDex)/20)/100`; too close `−0.12`; shield malus `min(90, 1200/Parry)%` | `MinThrowRange` 4/6/8; over max range `−47 %` damage (`BaseWeapon.cs:2521-2528`) |
| Wrestling | unarmed attack + defence; pre-AoS stun/disarm | `Fists.GetDefendSkillValue` `Fists.cs:146-160` | defence `max(Wrestling, (Anatomy+EvalInt+20)*0.5)`; moves `(Wrestling+other)/400` | defence value cap `120`; moves require `80/80` and `Stam ≥ 15`, 10 s lockout |
| Parry | block roll in AoS damage absorb; pre-AoS shield block | `BaseWeapon.CheckParry` `BaseWeapon.cs:1756` | shield: `(Parry − BushidoNonRacial)/400`; weapon: `(Parry*Bushido)/48000` (1H) or `/41140` | `+0.05` at 100+; `Dex < 80` malus `(20+Dex)/100`; floor `0` (players) / `0.1` (NPCs); pre-AoS block `≥ 0.01` |
| Tactics | damage %, special-move prerequisite, accuracy-level skill mod | passive inside `ScaleDamageAOS` `:3790` | AoS `0.625 %/pt + 6.25 @100`; pre-AoS `(Tactics−50)/100` multiplicative | DI property capped `100`; total percentage bonus capped `300` |
| Anatomy | damage %, defence value, Anatomy read-out | `ScaleDamageAOS` `:3789`; `Skills/Anatomy.cs:49-79` | AoS `0.5 %/pt + 5 @100`; pre-AoS `1 %/5 pts + 10 % @100` | read-out error `max(0, 25 − Anatomy/4)`, stamina band at `Base ≥ 65` |
| Lumberjacking (axes) | damage % only on `WeaponType.Axe` | `ScaleDamageAOS` `:3791-3796` | AoS `0.2 %/pt + 10 @100`; pre-AoS `1 %/5 pts`, clamped `0.2` | pre-AoS hard cap `20 %`; the promised `+10 %` GM term is dead code (`:3878-3881`) |
| EvalInt | AoS spell damage multiplier, curse duration/offset, reading mobs | `Spell.GetNewAosDamage` `Spell.cs:218-239`; `Skills/EvalInt.cs` | `evalScale = 30 + 0.9 * EvalInt`; duration `1.2*EvalInt + 1` s | read-out error `max(0, 20 − EvalInt/5)`; mana band at `Base ≥ 76`; **no fizzle/circle effect** |
| Magery | cast roll, damage-skill pairing, mana, reagents, circle gating | `Spell.CheckFizzle` `Spell.cs:924`; `MagerySpell.GetCastSkills` `:34-45` | `min = (100/7)·circle′ − 20`, `max = +20`, `circle′ = circle − (scroll ? 2 : 0)`; chance `(Magery−min)/(max−min)` | mana `{4,6,9,11,14,20,40,50}`; cast delay `(4+circle)*0.25 s − FC*0.25 s`, floor `0.25 s`; FC cap `2` (0 under Protection); recovery `(6−FCR)/4 s`; LMC cap `40` (+armour inherent) |
| Resisting Spells | AoS: minimum resistances + status-effect saves; pre-AoS: `−25 %` spell damage | `MagerySpell.CheckResisted` `:55-74` | `n = max(MR/5, MR − ((CastSkill−20)/5 + (1+circle)*5)) / 2`; resist if `n/100 ≥ RandomDouble()` | `n ≤ 0` never resists, `n ≥ 1` always; passive gain only below `maxSkill = (1+circle)*10 + (1+circle/6)*25`; min resist `40 + (MR*10−1000)/50` above 100 MR, floor `−70`, ceiling `70` |
| Meditation | mana regen rate, trance, armour malus | `Skills/Meditation.cs:30-104`; `RegenRates.Mobile_ManaRegenRate` `:110-209` | trance chance `(50 + (Med − (ManaMax−Mana))*2)/100`; ML `rate = 1/(0.2 + Focus/200 + medBonus + itemBonus)` | armour offset blocks `medBonus` entirely when `> 0`; pre-AoS rate clamped `0.5 … 7.0 s`; default `7.0 s` |
| Focus | mana regen (`/200` ML, `*0.05` AoS) and stamina regen (`*0.1`) | `RegenRates.cs:89`, `:126`, `:162` | stamina `1/(0.1*(2 + Focus*0.1 + StamRegen))` | ML mana items: `intensityBonus` capped `5.5` |
| Arms Lore | item quality/condition text, pre-AoS disarm partner | `Skills/ArmsLore.cs:38` | `ceil(min(avgDamage,30)/5)`; `ceil(min(ArmorRating,35)/5)`; `(HitPoints/MaxHitPoints)*10` | bands clamped `0..6` (damage), `0..7` (armour), `0..9` (condition) |
| Bushido `[ERA SE]` | parry scaling, Lightning/Momentum strikes, Evasion | `Evasion.cs`, `LightningStrike.cs`, `MomentumStrike.cs` | parry scalar `1 + ((Bushido−60)*0.004 + 0.16)`; LS accuracy `+50`, crit `Bushido²/72000`; MS `Bushido/100` damage to a second target | moves require `50.0` (LS) / `70.0` (MS) Bushido; evasion lockout 20 s; `GetCastSkills = Req − 12.5 … Req + 37.5` |
| Skill Masteries `[ERA]` post-SA | active/passive combat abilities | `SkillMasterySpell.cs:76-124` | `min = RequiredSkill(90)`, `max = +25`; `BaseSkillBonus = (Cast + Damage + level*40)/3` | learn gate `Base >= 90`; `RequiredMana 10`, `UpKeep` per spell; upkeep cancels below cost |

---

### 2b.14 Discrepancies, era notes and gaps

**ServUO ↔ ModernUO disagreements (all `[SRC]`):**

| Topic | ServUO `pub57` | ModernUO `main` |
|---|---|---|
| Magery circle `min` skill | `(100/7)·circle − 20` (`MagerySpell.cs:34-45`) | OSI table `{0,10,…,70}` non-ML / `{−18,…,80}` ML (`MagerySpell.cs:15-17`) |
| Circle-8 non-ML threshold | `80.00` min / `120.00` max | `70.0` min / `110.0` max |
| Magery cast delay | `(4 + circle) * 0.25 s` (`MagerySpell.cs:20`) | `(3 + circle) * 0.25 s` (`MagerySpell.cs:25`) |
| HCI cap for Gargoyles | `50` (`BaseWeapon.cs:1451`) | `45` for everyone (`BaseWeapon.cs:1266-1270`) |
| Non-AoS to-hit floor | `atkValue <= -50 → -49.9` (`:1474-1486`) | `Math.Max(0.1, atkValue + 50.0)` (`:1327-1328`) |
| Hit-chance extra bonuses | applied by spells/abilities elsewhere | folded into `ModifyHitChance` and `CheckHit` |
| Where the passive resist-gain roll lives | inside `MagerySpell.CheckResisted` (`MagerySpell.cs:70-71`); `Spell.GetResistSkill` only returns `MagicResist − EvilOmen malus` (`Spell.cs:439-442`) | inside `MagerySpell.GetResistSkill` (`ModernUO:MagerySpell.cs:47-59`), `CheckResisted` re-rolls it (`:78-83`) |

**`[ERA]` markers used above:** pre-AoS/classic (three-branch `GetDelay` `else`, `ScaleDamageOld`,
shield-block formula, no HCI/DCI/DI/SSI properties, 25 % resist damage cut, `0.75 s` recovery);
AoS 2003 (`Core.AOS`: resist pipeline, HCI/DCI/DI/SDI/SSI/FC/FCR/LMC/LRC, `ourValue/(2·theirValue)`,
`ScaleDamageAOS`, spell-damage `evalScale`, MagicReflect);
SE 2004/2005 (`Core.SE`: the tick-based swing formula, Bushido/Ninjitsu special moves, `Throwing`
later, wand cast delay `0` until ML); ML 2007 (`Core.ML`: the `speed*4 − Stam/30` swing model,
Focus mana regen model, Masteries code paths, pet stat-gain model); SA 2009 (`Core.SA`:
`GetInherentLowerManaCost`, Gargoyle HCI 50, `ReactiveParalyze`, Archery/Throwing racial gain locks);
HS/TOL (`Core.HS` balanced-weapon parry veto, `Core.TOL` secondary-skill thresholds).

**`[UNVERIFIED]` — do not quote a number for these:**
1. **Which publish introduced Skill Masteries.** `pub57` gates them on skill `>= 90`, mastery
   volumes and `BookOfMasteries` (`MasteryInfo.cs:33`, `:221-231`, `:333-350`) but contains no
   expansion constant for the feature itself. To resolve: read UOGuide "Skill Masteries" /
   the publish notes and confirm the `Core.*` flag the OSI shard used.
2. **Hard circle gate on the client.** `pub57` has none server-side; whether the client's
   spellbook greys out circles is a ClassicUO question and was not measured here. To resolve:
   read `ClassicUO` spellbook gump code or capture the cast packet at low Magery.
3. **Whether OSI's live fizzle curve equals ServUO's `±20` band or ModernUO's `min..min+40`.**
   Two server codebases disagree; resolve by measuring fizzle counts over N casts per circle on
   a live shard (or by finding EA's own formula in an official publish note).
4. **Exact `AosAttribute.WeaponSpeed` effective cap outside `GetDelay`.** The delay path caps at
   `60` and the property display caps at `60` (`AOS.cs:481-482`), but items exist with `75`
   (`TheBeserkersMaul.cs:12`), so whether the *item* value is clamped before it reaches
   `AosAttributes.GetValue` was not traced through every equipment path.
5. **Base swing-speed values for the full weapon list.** This section quotes 12 weapons read
   directly; the remaining ~130 files were located but not read line-by-line. The `MlSpeed`
   value for any other weapon must be read from `<Weapon>.cs` before use.
6. **Arms Lore cliloc strings.** Only the arithmetic is proven here; the exact English text of
   bands `1038285+hp`, `1038216..1038224+…`, `1038295+…` lives in the client cliloc file.

## 3. Skill gain & stat gain

Sources: **ServUO `pub57`** (primary, all mechanics below are literal from the checkout) and **ModernUO `main`** (differences flagged). Citation shorthand used in this section (every `ServUO:<path>:<line>` expands to the GitHub URL form shown here):

| Shorthand | Expands to |
|---|---|
| `ServUO:Scripts/Misc/SkillCheck.cs:221` | `https://github.com/ServUO/ServUO/blob/pub57/Scripts/Misc/SkillCheck.cs#L221` |
| `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:108` | `https://github.com/modernuo/ModernUO/blob/main/Projects/UOContent/Skills/SkillCheck.cs#L108` |

Files read in full for this section: `ServUO:Scripts/Misc/SkillCheck.cs` (808 lines), `ServUO:Server/Skills.cs` (1109 lines), `ServUO:Scripts/Gumps/SkillsGump.cs` (555 lines), `ServUO:Server/Mobile.cs` (selected ranges), `ServUO:Scripts/Mobiles/PlayerMobile.cs` (selected ranges), `ModernUO:Projects/UOContent/Skills/SkillCheck.cs` (505 lines), `ModernUO:Projects/UOContent/Skills/AntiMacroSystem.cs` (270 lines), `ModernUO:Projects/Server/Skills.cs`, `ModernUO:Distribution/Data/skills.json` (930 lines).

---

### 3.0 Call graph & units (read this first)

| Fact | Value | Source |
|---|---|---|
| Skill storage | `ushort` fixed point, 1/10 skill point | `ServUO:Server/Skills.cs:95` |
| `Skill.Base` | `m_Base / 10.0` (double) | `ServUO:Server/Skills.cs:322` |
| `Skills.Total` / `Skills.Cap` | **fixed points** (7000 = 700.0) | `ServUO:Server/Skills.cs:844,853` |
| Individual skill cap | `m_Cap` fixed point, default `1000` = 100.0 | `ServUO:Server/Skills.cs:124,874` |
| Total skill cap default | `Config.Get("PlayerCaps.TotalSkillCap", 7000)` | `ServUO:Server/Skills.cs:996` |
| Entry points | `Mobile.CheckSkill` / `Mobile.CheckTargetSkill` → static handler delegates | `ServUO:Server/Mobile.cs:12598-12644`, delegates declared `:508-511,625-632` |
| Handler wiring | `SkillCheck.Initialize()` installs `XmlSpawnerSkillCheck.*`, which calls straight back into `SkillCheck.*` then fires XML-spawner skill triggers | `ServUO:Scripts/Misc/SkillCheck.cs:125-132`, `ServUO:Scripts/Services/XmlSpawner/XmlSpawner Core/XmlSpawnerSkillCheck.cs:26-88` |
| Region gain multiplier | `Region.SkillGain(from) => 0.1` (virtual, **no overrides exist in the tree**) | `ServUO:Server/Region.cs:973-976` |
| Therefore `toGain` | `(int)(from.Region.SkillGain(from) * 10)` = `(int)(0.1*10)` = **1 fixed point = 0.1 skill** | `ServUO:Scripts/Misc/SkillCheck.cs:361` |

Flow: `CheckSkill()` → difficulty `chance` → **success roll** → `GetGainChance()` → `AllowGain()` → `Gain()` → `CheckReduceSkill()` → cap gate → `Skill.BaseFixedPoint +=` → `UpdateGGS()` → stat-gain branch.

[SRC] for the whole table.

---

### 3.1 `GetGainChance` decomposed term by term

There are **two** private `GetGainChance` overloads plus one public bulk variant. Do not conflate them.

#### (a) The main overload — `SkillCheck.cs:261-284` (used by every normal `CheckSkill`)

```csharp
private static double GetGainChance(Mobile from, Skill skill, double chance, bool success)   // :261
{
    var gc = (double)(from.Skills.Cap - from.Skills.Total) / from.Skills.Cap;   // :263  T
    gc += (skill.Cap - skill.Base) / skill.Cap;                                // :265  S
    gc /= 2;                                                                   // :266
    gc += (1.0 - chance) * (success ? 0.5 : (Core.AOS ? 0.0 : 0.2));           // :268  D
    gc /= 2;                                                                   // :269
    gc *= skill.Info.GainFactor;                                              // :271  G
    if (gc < 0.01) gc = 0.01;                                                  // :273-274  floor
    if (from is BaseCreature && ((BaseCreature)from).Controlled) gc += gc * 1.00; // :277-278 pet +100 %
    if (gc > 1.00) gc = 1.00;                                                  // :280-281  clamp
    return gc;
}
```

Algebra (all quantities in **fixed points** where `Cap`/`Total` are used, i.e. 7000/3500-scale):

```
T = (Skills.Cap - Skills.Total) / Skills.Cap          # total-cap head-room, 1.0 when Total = 0
S = (skill.Cap - skill.Base)   / skill.Cap            # per-skill head-room, 1.0 when Base = 0
D = (1 - chance) * k         where k = 0.5 if success
                                     = 0.0 if !success and Core.AOS
                                     = 0.2 if !success and !Core.AOS
G = skill.Info.GainFactor                            # 1.0 for all 58 skills (see §3.9)

gc_raw = ( ( (T + S) / 2 ) + D ) / 2 * G
gc     = clamp( max(gc_raw, 0.01), min..1.00 )
gc_pet = clamp( gc * 2.00 , min..1.00 )              # only if from is a CONTROLLED BaseCreature
```

Term-by-term:

| Term | Expression | Range | Meaning | Source |
|---|---|---|---|---|
| Total-cap term `T` | `(Cap - Total)/Cap` | 0 → 1 | 1.0 at zero total skill, 0.0 at 700.0 total | `SkillCheck.cs:263` |
| Per-skill-cap term `S` | `(skill.Cap - skill.Base)/skill.Cap` | 0 → 1 | 1.0 at base 0, 0.0 at the skill's own cap | `SkillCheck.cs:265` |
| Averaging | `(T + S) / 2` | 0 → 1 | the two head-rooms count equally | `SkillCheck.cs:266` |
| Difficulty/success term `D` | `(1 - chance) * k` | 0 → 0.5 (AoS) | **easier checks give *less* gain chance**; `chance` is the pre-roll ratio `(value-min)/(max-min)`, not the success flag | `SkillCheck.cs:268` |
| Failure weight `k` | `0.5` success / `0.0` AoS-failure / `0.2` pre-AoS failure | — | in AoS+ a **failed** use contributes **no** gain term at all | `SkillCheck.cs:268` |
| `GainFactor` | `skill.Info.GainFactor` | 1.0 for all 58 | per-skill multiplier hook, unused in this table | `SkillCheck.cs:271`, `Server/Skills.cs:586` |
| Floor | `if (gc < 0.01) gc = 0.01` | min 1 % | applied **before** the pet bonus | `SkillCheck.cs:273-274` |
| Pet bonus | `gc += gc * 1.00` → `×2` | — | **only** `BaseCreature && Controlled`; tamed/controlled pets gain at twice the rate | `SkillCheck.cs:277-278` |
| Clamp | `if (gc > 1.00) gc = 1.00` | max 100 % | applied **after** the pet bonus | `SkillCheck.cs:280-281` |

#### (b) The bulk/craft-all overload — `SkillCheck.cs:221-237`

Used only by `CheckSkill(from, SkillName, minSkill, maxSkill, amount)` (`:187-219`), whose sole caller is `UseAllRes` in `CraftItem.cs` ("Craft All Gains" region, `:178-238`).

```csharp
private static double GetGainChance(Mobile from, Skill skill, double gains, double chance)  // :221
{
    var gc = (double)(from.Skills.Cap - (from.Skills.Total + (gains * 10))) / from.Skills.Cap;  // :223
    gc += (skill.Cap - (skill.Base + (gains * 10))) / skill.Cap;                                // :225
    gc /= 4;                                                                                    // :226
    gc *= skill.Info.GainFactor;                                                                // :228
    if (gc < 0.01) gc = 0.01;                                                                   // :230-231
    if (gc > 1.00) gc = 1.00;                                                                   // :233-234
    return gc;
}
```

Call site: `GetGainChance(from, skill, (value - minSkill) / (maxSkill - minSkill), value)` (`:198`). So the parameter **named** `gains` receives the normalised difficulty ratio (0…1) and the parameter **named** `chance` (4th) is **never read** — dead parameter. Consequences vs. the main overload: divisor `4` instead of `2`, **no** difficulty/success term, **no** pet bonus, and a per-iteration penalty of `gains*10` fixed points (≤ 10 fixed points, i.e. ≤ 1.0 skill, since `gains ≤ 1`).

The returned value is divided by `10` at the call site (`:198`) to become the **per-iteration** probability, because the loop runs `amount` times (`:196`), incrementing a local `value += 0.1` counter; at the end the accumulated count is applied in **one** call: `if (gains > 0) { Gain(from, skill, gains); EventSink.InvokeSkillCheck(..., true); return true; }` (`:211-216`). So `amount = 100` yields ~100 independent rolls each at `gc/10`, applied as a single bulk `toGain` — which then runs through the normal `Gain()` (§3.3) including `CheckReduceSkill` and the total-cap gate exactly once.

[SRC] for (a) and (b). The naming mismatch is a literal source quirk, not an interpretation.

---

### 3.2 `chance`, the short-circuits, and how `success` feeds gain

`Mobile_SkillCheckLocation` (`SkillCheck.cs:134-158`):

```csharp
if (value < minSkill)  return false;                       // :147-148  "Too difficult" — NO gain roll at all
if (value >= maxSkill) return true;                        // :150-151  "No challenge"  — NO gain roll at all
var chance = (value - minSkill) / (maxSkill - minSkill);   // :153
return CheckSkill(from, skill, new Point2D(from.Location.X / LocationSize,
                                           from.Location.Y / LocationSize), chance);  // :157
```

| Step | Constant / literal | Source |
|---|---|---|
| `value` | `skill.Value` (stat-modified, see §3.10) | `:141` |
| Fishing special case | `if (skillName == Fishing && BaseGalleon.FindGalleonAt(from, from.Map) is TokunoGalleon) value += 1;` | `:144-145` |
| Too difficult | `value < minSkill` → return `false`, **no** `AllowGain`, **no** `Gain` | `:147-148` |
| No challenge | `value >= maxSkill` → return `true`, **no** `AllowGain`, **no** `Gain` | `:150-151` |
| `chance` | `(value - minSkill) / (maxSkill - minSkill)` — 0.0 at `minSkill`, 1.0 at `maxSkill` | `:153` |
| Difficulty feedback item | `CrystalBallOfKnowledge.TellSkillDifficulty(from, skillName, chance)` — messages `1078457` Too Challenging … `1078463` Too Easy, bands 0.0 / ≤0.1 / ≤0.25 / ≤0.75 / ≤0.9 / ≤1.0 | `:155`, `Scripts/Items/Quest/CrystalBallOfKnowledge.cs:102-124` |
| Direct-chance variants | `chance < 0.0` → false, `chance >= 1.0` → true, else roll | `:160-176` (location), `:313-329` (target) |
| Target variant | identical maths, `obj` = the target instead of a `Point2D` | `:286-311` |

Success roll and gain application (`CheckSkill(Mobile, Skill, object, double)`, `:240-259`):

```csharp
if (from.Skills.Cap == 0) return false;                                  // :242-243
var success = Utility.Random(100) <= (int)(chance * 100);                 // :245
var gc = GetGainChance(from, skill, chance, success);                     // :246
if (AllowGain(from, skill, obj))                                          // :248
    if (from.Alive && (skill.Base < 10.0 || Utility.RandomDouble() <= gc || CheckGGS(from, skill)))
        Gain(from, skill);                                                // :250-253
EventSink.InvokeSkillCheck(new SkillCheckEventArgs(from, skill, success)); // :256
return success;                                                           // :258
```

| Behaviour | Literal | Source |
|---|---|---|
| Cap-0 shard guard | `if (from.Skills.Cap == 0) return false;` | `:242-243` |
| `success` roll | `Utility.Random(100) <= (int)(chance * 100)` → **P(success) = ((int)(chance*100)+1)/100**, i.e. `chance = 0.5` succeeds 51 % of the time (`Utility.Random(n)` = `Next(n)` ∈ 0..n-1, `Server/Utility.cs:921-924`) | `:245` |
| `success` → gc | only through `k` in term `D` (0.5 vs 0.0/0.2). It does **not** gate whether a gain is attempted | `:268` |
| Free gain below 10.0 | `skill.Base < 10.0` ⇒ the random roll and GGS are short-circuited, gain is automatic | `:250` |
| Random gain | `Utility.RandomDouble() <= gc` (P = gc, `RandomDouble ∈ [0,1)`) | `:250`, `Server/Utility.cs:931` |
| GGS override | `|| CheckGGS(from, skill)` — evaluated only when the roll above failed; guarantees one gain | `:250`, `:774-785` |
| Alive requirement | `from.Alive` — dead mobiles/players never gain | `:250` |
| Event | `EventSink.InvokeSkillCheck(...)` fires **even when no gain happened and even when `AllowGain` returned false** | `:256` |
| Return value | `success` — the caller's skill-use result is *independent* of whether the skill grew | `:258` |

---

### 3.3 `Gain()` in full

```csharp
public static void Gain(Mobile from, Skill skill)                            // :359
    => Gain(from, skill, (int)(from.Region.SkillGain(from) * 10));           // :361  → toGain = 1

public static void Gain(Mobile from, Skill skill, int toGain)                // :364
{
  if (from.Region.IsPartOf<Jail>()) return;                                  // :366-367
  if (from is BaseCreature && ((BaseCreature)from).IsDeadPet) return;         // :369-370
  if (skill.SkillName == SkillName.Focus && from is BaseCreature &&
      (!PetTrainingHelper.Enabled || !((BaseCreature)from).Controlled)) return; // :372-374

  if (skill.Base < skill.Cap && skill.Lock == SkillLock.Up)                   // :376
  {
      var skills = from.Skills;
      if (from is PlayerMobile && Siege.SiegeShard) { ...ROT gate...; return; }  // :380-398
      if (toGain == 1 && skill.Base <= 10.0) toGain = Utility.Random(4) + 1;     // :400-401
      if (from is PlayerMobile && QuestHelper.EnhancedSkill((PlayerMobile)from, skill))
          toGain *= Utility.RandomMinMax(2, 4);                                  // :404-407
      if (from is PlayerMobile && skill.SkillName == ((PlayerMobile)from).AcceleratedSkill &&
          ((PlayerMobile)from).AcceleratedStart > DateTime.UtcNow)
      { SendLocalizedMessage(1077956); toGain = Utility.RandomMinMax(2, 5); }     // :411-418
      else if (from is BaseCreature && !DespiseCreature && (Controlled || Summoned)) {
          var master = ((BaseCreature)from).GetMaster();
          var spell = SkillMasterySpell.GetSpell(master, typeof(WhisperingSpell)) as WhisperingSpell;
          if (spell != null && master.InRange(from.Location, spell.PartyRange) &&
              master.Map == from.Map && spell.EnhancedGainChance >= Utility.Random(100))
              toGain = Utility.RandomMinMax(2, 5); }                              // :422-436
      if (from is PlayerMobile) CheckReduceSkill(skills, toGain, skill);          // :439-442
      if (!from.Player || (skills.Total + toGain <= skills.Cap)) {                // :444
          skill.BaseFixedPoint = Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain); // :446
          EventSink.InvokeSkillGain(new SkillGainEventArgs(from, skill, toGain)); // :448
          if (from is PlayerMobile) UpdateGGS(from, skill);                       // :450-451
      }
  }
  if (from is PlayerMobile) QuestHelper.CheckSkill((PlayerMobile)from, skill);    // :456-457
  if (skill.Lock == SkillLock.Up && (!Siege.SiegeShard || !(from is PlayerMobile) ||
      Siege.CanGainStat((PlayerMobile)from))) { ...stat gain... }                 // :460-481
}
```

| Mechanic | Exact behaviour | Source |
|---|---|---|
| Unit | `toGain` is in **fixed points**; 1 = 0.1 skill | `Server/Skills.cs:285-319` |
| Base increment | `skill.BaseFixedPoint = Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain)` — clamped at the *individual* skill cap | `:446` |
| Jail | whole `Gain()` returns early inside a `Jail` region | `:366-367` |
| Dead pet | `BaseCreature.IsDeadPet` never gains | `:369-370` |
| Focus (pet) | `Focus` gain suppressed for creatures unless `PetTrainingHelper.Enabled` **and** controlled | `:372-374` |
| Preconditions | `skill.Base < skill.Cap` **and** `skill.Lock == SkillLock.Up` | `:376` |
| Low-skill boost | only when `toGain == 1 && skill.Base <= 10.0` → `Utility.Random(4) + 1` = **1…4** fixed points (uniform) | `:400-401` |
| ML Apprentice quest | `QuestHelper.EnhancedSkill` true → `toGain *= RandomMinMax(2, 4)` = **×2…×4** — requires an incomplete `ApprenticeObjective` whose `Region` contains the player and whose `Skill` matches | `:404-407`, `Scripts/Services/MondainsLegacyQuests/Helpers/QuestHelper.cs:802-829` |
| Scroll of Alacrity | player's `AcceleratedSkill` matches **and** `AcceleratedStart > UtcNow` → message `1077956` + `toGain = RandomMinMax(2, 5)` = **2…5** (assignment, *replaces* the low-skill boost) | `:411-418`; scroll sets 15 min: `Scripts/Items/Consumables/ScrollofAlacrity.cs:59,122` |
| Whispering mastery | *`else if`* branch: controlled/summoned non-Despise creature, master within `PartyRange` (12, `SkillMasterySpell.cs:36`) on the same map, and `spell.EnhancedGainChance >= Utility.Random(100)` → `toGain = RandomMinMax(2, 5)`. `EnhancedGainChance = (int)(BaseSkillBonus / 1.26)`, duration 600 s | `:422-436`, `Scripts/Spells/Skill Masteries/Whispering.cs:88,84` |
| Event | `EventSink.InvokeSkillGain` fires **only when the base actually increased** | `:448` |
| GGS timer refresh | `UpdateGGS` only for `PlayerMobile`, only after a real gain | `:450-451` |
| ML quest hook | `QuestHelper.CheckSkill` for players regardless of whether the gain landed | `:456-457` |
| Stat gain gate | runs whenever `skill.Lock == SkillLock.Up` (i.e. also on *failed* skill uses and when the total-cap gate denied the skill point) | `:460-481` |

**Dead / missing in ServUO `pub57`:** there is **no** `Mobile.DisableSkill` method anywhere in the tree (grepped whole checkout). The equivalent gates are `Mobile.AllowSkillUse` (virtual, base returns `true`, `Server/Mobile.cs:3944-3947`), the `PlayerMobile` override (animal-form restricted skills + `DesignContext.Check`, `Scripts/Mobiles/PlayerMobile.cs:2238-2262`), `Region.OnSkillUse` (`Server/Region.cs:963-971`; `Jail` override returns `from.IsStaff()`, `Scripts/Regions/Jail.cs:55-61`), and the `SkillInfo.UseWhileCasting` / `from.Spell == null` gate inside `Skills.UseSkill` (`Server/Skills.cs:912-923`).

`SendSkillMessage` / `NextSkillTime`: `Skills.UseSkill` requires `Core.TickCount - from.NextSkillTime >= 0`; on failure it calls `from.SendSkillMessage()` → localized `500118` "You must wait a few moments to use another skill.", itself rate-limited by `ActionMessageDelay = 125` ms (`Server/Mobile.cs:1855-1865`); `NextSkillTime = Core.TickCount + (int)callback(from).TotalMilliseconds` (`Server/Skills.cs:916`). "That skill cannot be used directly" = `500014` (`Server/Skills.cs:927`). [SRC]

---

### 3.4 Total-cap arbitration at 700.0 (and `CheckReduceSkill`)

```csharp
// SkillCheck.cs:439-452 (order is significant)
if (from is PlayerMobile) CheckReduceSkill(skills, toGain, skill);
if (!from.Player || (skills.Total + toGain <= skills.Cap)) { ...apply gain... }

// SkillCheck.cs:484-497
private static void CheckReduceSkill(Skills skills, int toGain, Skill gainSKill) {
    if (skills.Total / skills.Cap >= Utility.RandomDouble())          // :486  roll ≈ Total/Cap
        foreach (var toLower in skills)                                // :488  enumeration order = skill id 0..57
            if (toLower != gainSKill && toLower.Lock == SkillLock.Down &&
                toLower.BaseFixedPoint >= toGain) {                    // :490
                toLower.BaseFixedPoint -= toGain; break;               // :492  FIRST match only
            }
}
```

| Rule | Exact behaviour | Source |
|---|---|---|
| Who is subject to reduction | `PlayerMobile` only (called inside `if (from is PlayerMobile)`) | `:439-442` |
| Reduction trigger | `skills.Total / skills.Cap >= Utility.RandomDouble()` — integer division of fixed points by fixed points, so this is `Total/Cap` as an **integer** (0 or 1 in practice) compared with a double: at `Total = 7000`, `Cap = 7000` → `1 >= r` ⇒ always true; at `Total = 3500` → `0 >= r` is true only when `RandomDouble()` returns exactly `0.0` ⇒ effectively never | `:486` |
| Which skill is reduced | the **first** skill in `Skills` enumeration order whose `Lock == SkillLock.Down` and whose `BaseFixedPoint >= toGain`; `break` after the first hit | `:488-494` |
| Enumeration order | `Skills.GetEnumerator()` = `m_Skills.Where(s => s != null)` → array order = **skill id ascending 0…57** | `Server/Skills.cs:1099-1107` |
| Self-exclusion | the skill being raised is skipped (`toLower != gainSKill`) | `:490` |
| Up-locked / Locked skills | **never** reduced — only `SkillLock.Down` | `:490` |
| Insufficient points | a Down skill with `BaseFixedPoint < toGain` is skipped entirely (no partial drain) | `:490` |
| Ordering vs. the cap gate | reduction happens **before** the `Total + toGain <= Cap` test, and `BaseFixedPoint`'s setter keeps `Skills.Total` in sync (`Server/Skills.cs:305`), so the drain can make room for the gain in the same call | `:439-446` |
| Net-loss case | if the drain happens but `Total + toGain` still exceeds `Cap`, the skill point is **not** granted and the reduction is **not** refunded → a net 0.1 loss | `:444-452` |
| Non-players | `from.Player == false` (creatures) bypass the cap gate entirely: `!from.Player || …` → creatures can exceed `Skills.Cap` | `:444` |
| Final clamp | `Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain)` — the 100.0 (or powerscroll-raised) individual cap always wins over the total cap | `:446` |
| Default values | `TotalSkillCap = 7000` fixed points = 700.0; individual default `1000` = 100.0 | `Server/Skills.cs:996,874`; `Config/PlayerCaps.cfg:9,13` |
| Per-character override | at creation, if `Config.Get("PlayerCaps.SkillCap", 1000.0)/10 != 100.0` every skill's `Cap` is set from that config value | `Scripts/Misc/CharacterCreation.cs:211-217` |

**ModernUO difference:** the reduction uses `skills.Total / (double)skills.Cap >= Utility.RandomDouble()` (no integer truncation, so the roll really is `Total/Cap`), and the cap gate is `skills.Total < skills.Cap` — so ModernUO can overshoot the total cap by up to `toGain-1` fixed points. `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:259-271,278`.

---

### 3.5 `SkillLock`

```csharp
public enum SkillLock : byte { Up = 0, Down = 1, Locked = 2 }   // Server/Skills.cs:21-26
```

| Aspect | Detail | Source |
|---|---|---|
| Client → server packet | `0x3A`, handler `ChangeSkillLock`: `state.Mobile.Skills[pvSrc.ReadInt16()].SetLockNoRelay((SkillLock)pvSrc.ReadByte())` | `Server/Network/PacketHandlers.cs:83,1223-1231` |
| `SetLockNoRelay` | ignores values `< Up` or `> Locked`, sets `m_Lock` **without** invalidating/relaying | `Server/Skills.cs:183-191` |
| Public `Lock` property | **get-only** — only `SetLockNoRelay` can change it | `Server/Skills.cs:268-269` |
| Server → client: full list | `SkillUpdate` packet `0x3A`, type byte `0x02` ("absolute, capped"), per skill: `id+1` (ushort), `NonRacialValue*10`, `BaseFixedPoint`, `Lock`, `CapFixedPoint` | `Server/Network/Packets.cs:2521-2555` |
| Server → client: single skill | `SkillChange` `0x3A`, type `0xDF` ("delta, capped"), same fields but `SkillID` (no +1) | `Server/Network/Packets.cs:2566-2596` |
| When sent | `Skills.OnSkillChange` sends `SkillChange` + `MobileDelta.Skills` on every base/cap change | `Server/Skills.cs:1075-1097` |
| When the whole list is sent | `Mobile.OnSkillsQuery` (client query `0x34`, sub-type `0x05`) | `Server/Mobile.cs:12412-12418`, `Server/Network/PacketHandlers.cs:2317-2321` |
| Client parse | ClassicUO `Handler.Add(0x3A, UpdateSkills)`; `type == 0x02` ⇒ `id--`; `Lock locked = (Lock)p.ReadUInt8()` | `ClassicUO:src/ClassicUO.Client/Network/PacketHandlers.cs:217,1921-2017` |
| Client → server lock change | ClassicUO `GameActions.ChangeSkillLockStatus` sends `0x3A` with `skillindex` + `lockstate` | `ClassicUO:src/ClassicUO.Client/Game/GameActions.cs:575`, `Network/OutgoingPackets.cs:791-805` |
| Persistence | lock serialized only when `!= SkillLock.Up` (flag `0x4`); default is `Up` | `Server/Skills.cs:213-216,240-243,125` |
| Sanity check on load | `if (m_Lock < SkillLock.Up || m_Lock > SkillLock.Locked) { Console.WriteLine("Bad skill lock -> …"); m_Lock = SkillLock.Up; }` | `Server/Skills.cs:167-171` |
| Staff gump icons | `Up` = `0x983`, `Down` = `0x985`, `Locked` = `0x82C` | `Scripts/Gumps/SkillsGump.cs:278-299` |
| Staff gump cycling | Up → Down → Locked → Up, **game-master access only**; non-staff get "You may not change that." | `Scripts/Gumps/SkillsGump.cs:385-404` |

**Behavioural consequences of the lock:**

| Lock | Effect | Source |
|---|---|---|
| `Up` | required for any skill gain (`skill.Lock == SkillLock.Up` in `Gain`) **and** required for the stat-gain branch to run at all | `SkillCheck.cs:376,460` |
| `Down` | never gains; is the only lock that `CheckReduceSkill` may drain; also required for `CanLower` (stat drain) | `SkillCheck.cs:490`, `:571-575` |
| `Locked` | neither gains nor drains; blocks the corresponding stat from raising (stat locks, `StatLockType`, `Server/Mobile.cs:372-377`) | `SkillCheck.cs:376,490,559-562` |
| Alacrity / transcendence | both refuse to work unless `Lock == SkillLock.Up` | `ScrollofAlacrity.cs:110`, `ScrollofTranscendence.cs:120` |
| Repair system | force-sets `Tinkering` to `SkillLock.Locked` | `Scripts/Services/Craft/Core/Repair.cs:139,718` |
| Teaching (pet/player) | a pupil must be `Up`; teaching consumes points from the teacher's `Down`-locked skills | `Scripts/Mobiles/Normal/BaseCreature.cs:4323-4397` |

---

### 3.6 Anti-macro system

```csharp
public static TimeSpan AntiMacroExpire = TimeSpan.FromMinutes(5.0);  // :28  remember targets/locations for 5 min
public const int Allowance = 3;                                      // :33  uses of the same location/target
private const int LocationSize = 4;                                  // :38  location grid cell edge, in tiles
_AntiMacroCode = Config.Get("PlayerCaps.EnableAntiMacro", false);   // :44  DEFAULT = false (OFF)
```

| Constant | Value | Source |
|---|---|---|
| `AntiMacroExpire` | `TimeSpan.FromMinutes(5.0)` | `ServUO:Scripts/Misc/SkillCheck.cs:28` |
| `Allowance` | `3` (const int) | `:33` |
| `LocationSize` | `4` (private const int) | `:38` |
| Master switch | `PlayerCaps.EnableAntiMacro`, code default **`false`**, shipped cfg `False` | `:44`, `Config/PlayerCaps.cfg:63` |
| Config comment claim | "If left to default value, this will be true if the ML era flag is not on." — **the code does not implement this**; the literal default passed to `Config.Get` is `false` | `Config/PlayerCaps.cfg:61-63` vs `:44` |

**Location-key arithmetic** (`:157`, `:175`, `:200`):

```csharp
new Point2D(from.Location.X / LocationSize, from.Location.Y / LocationSize)   // integer division
// LocationSize = 4  →  a 4x4-tile grid cell, e.g. (1234,5678) → (308,1419)
```

`Point2D` is a struct with value `Equals`/`GetHashCode` (`Server/Geometry.cs:78-99`), so a `Hashtable` keyed by it compares by cell. Target-based skills pass the **target object** instead (`Mobile`/`Item` reference identity — neither overrides `Equals`/`GetHashCode`).

**Target-key path** — `AllowGain` → `((PlayerMobile)from).AntiMacroCheck(skill, obj)` (`:346-347`), where `obj` is the `Point2D` for location checks or the raw target for `CheckTargetSkill`:

```csharp
public bool AntiMacroCheck(Skill skill, object obj) {                     // PlayerMobile.cs:4441
    if (obj == null || m_AntiMacroTable == null || IsStaff()) return true; // :4443-4446  staff & null-object bypass
    Hashtable tbl = (Hashtable)m_AntiMacroTable[skill];                    // :4448  outer key = Skill object
    if (tbl == null) m_AntiMacroTable[skill] = tbl = new Hashtable();      // :4449-4452
    CountAndTimeStamp count = (CountAndTimeStamp)tbl[obj];                 // :4454  inner key = location/target
    if (count != null) {
        if (count.TimeStamp + SkillCheck.AntiMacroExpire <= DateTime.UtcNow) { count.Count = 1; return true; } // :4457-4461 expired → reset to 1
        else { ++count.Count; return count.Count <= SkillCheck.Allowance; }  // :4464-4472  allow while count <= 3
    } else { tbl[obj] = count = new CountAndTimeStamp(); count.Count = 1; return true; } // :4477-4480
}
```

`CountAndTimeStamp` is a private nested class whose `Count` setter also refreshes `m_Stamp` to `DateTime.UtcNow` (`Scripts/Mobiles/PlayerMobile.cs:206-222`) — so the 5-minute window is measured from the **last** use, not the first.

Table cleanup: on serialize, entries older than `AntiMacroExpire` are removed from every inner table (`PlayerMobile.cs:4946-4964`).

**What happens when the allowance is used up:** 4th use of the same `(skill, location)` (or `(skill, target)`) within 5 minutes ⇒ `AntiMacroCheck` returns `false` ⇒ `AllowGain` returns `false` ⇒ the `if (AllowGain(...))` block in `CheckSkill` is skipped ⇒ **no gain attempt, and no player-visible message**. `EventSink.InvokeSkillCheck` still fires with `success` (`:256`). The only messages anywhere near this path are `500118` ("You must wait a few moments to use another skill.") and `500014` ("That skill cannot be used directly."), which come from `SendSkillMessage` / `Skills.UseSkill` — **not** from the anti-macro path. [SRC] for the silence; a claim that OSI printed something here is `[UNVERIFIED]` (would require live-shard packet capture).

**Full 58-entry `UseAntiMacro[]` table** (`SkillCheck.cs:59-123`; rows 0-54 are on lines 62-116 consecutively, then the `#region Stygian Abyss` block puts rows 55/56/57 on lines 119/120/121):

| id | Skill | UseAntiMacro | line | id | Skill | UseAntiMacro | line |
|---|---|---|---|---|---|---|---|
| 0 | Alchemy | `false` | 62 | 29 | Musicianship | `true` | 91 |
| 1 | Anatomy | `true` | 63 | 30 | Poisoning | `true` | 92 |
| 2 | Animal Lore | `true` | 64 | 31 | Archery | `false` | 93 |
| 3 | Item Identification | `true` | 65 | 32 | Spirit Speak | `true` | 94 |
| 4 | Arms Lore | `true` | 66 | 33 | Stealing | `true` | 95 |
| 5 | Parrying | `false` | 67 | 34 | Tailoring | `false` | 96 |
| 6 | Begging | `true` | 68 | 35 | Animal Taming | `true` | 97 |
| 7 | Blacksmithy | `false` | 69 | 36 | Taste Identification | `true` | 98 |
| 8 | Bowcraft/Fletching | `false` | 70 | 37 | Tinkering | `false` | 99 |
| 9 | Peacemaking | `true` | 71 | 38 | Tracking | `true` | 100 |
| 10 | Camping | `true` | 72 | 39 | Veterinary | `true` | 101 |
| 11 | Carpentry | `false` | 73 | 40 | Swordsmanship | `false` | 102 |
| 12 | Cartography | `false` | 74 | 41 | Mace Fighting | `false` | 103 |
| 13 | Cooking | `false` | 75 | 42 | Fencing | `false` | 104 |
| 14 | Detecting Hidden | `true` | 76 | 43 | Wrestling | `false` | 105 |
| 15 | Discordance | `true` | 77 | 44 | Lumberjacking | `true` | 106 |
| 16 | Evaluating Intelligence | `true` | 78 | 45 | Mining | `true` | 107 |
| 17 | Healing | `true` | 79 | 46 | Meditation | `true` | 108 |
| 18 | Fishing | `true` | 80 | 47 | Stealth | `true` | 109 |
| 19 | Forensic Evaluation | `true` | 81 | 48 | Remove Trap | `true` | 110 |
| 20 | Herding | `true` | 82 | 49 | Necromancy | `true` | 111 |
| 21 | Hiding | `true` | 83 | 50 | Focus | `false` | 112 |
| 22 | Provocation | `true` | 84 | 51 | Chivalry | `true` | 113 |
| 23 | Inscription | `false` | 85 | 52 | Bushido | `true` | 114 |
| 24 | Lockpicking | `true` | 86 | 53 | Ninjitsu | `true` | 115 |
| 25 | Magery | `true` | 87 | 54 | Spellweaving | `true` | 116 |
| 26 | Resisting Spells | `true` | 88 | 55 | Mysticism | `true` | 119 |
| 27 | Tactics | `false` | 89 | 56 | Imbuing | `true` | 120 |
| 28 | Snooping | `true` | 90 | 57 | Throwing | `false` | 121 |

Indexing is `UseAntiMacro[skill.Info.SkillID]` — a raw array index, so the table must have exactly 58 entries or the shard throws. Totals: **40 `true`, 18 `false`**. [SRC]

**Gargoyle race gates** live in the same `AllowGain` (`:339-343`), inside `if (from is PlayerMobile)`: `Archery` is refused for gargoyles, `Throwing` is refused for non-gargoyles — i.e. a gargoyle cannot gain Archery and a human/elf cannot gain Throwing. `[ERA]` SA (2009) introduced Throwing for gargoyles (`SkillInfo.Table` comment `// Throwing = 57` in the SA region, `:118-122`).

**ModernUO differences:** anti-macro lives in `ModernUO:Projects/UOContent/Skills/AntiMacroSystem.cs`; settings come from `Configuration/antimacro.json` (auto-written on first run, `:84-105`) with defaults `Enabled = false`, `Allowance = 3`, **`LocationSize = 5`** (not 4), `Expire = 5 min`, same 58-bit skill mask (`:16-76`). Its counter increments **before** the comparison, so only **2** successful gains per location per window instead of 3: `if (!exists || expired || _count < Allowance) return true; return false;` (`:242-248`). Reference-equality keys become a `Dictionary<(Skill, object), …>` (`:229`). ModernUO keeps the gargoyle gates out of the gain path (only character creation restricts them: `Projects/UOContent/Engines/Character Creation/CharacterCreation.cs:451-452`).

---

### 3.7 GGS — Guaranteed Gain System

```csharp
public static bool GGSActive { get { return !Siege.SiegeShard; } }   // :40

private static bool CheckGGS(Mobile from, Skill skill) {              // :774
    if (!GGSActive) return false;                                     // :776-777
    if (from is PlayerMobile && skill.NextGGSGain < DateTime.UtcNow) return true;  // :779-782
    return false;
}

public static void UpdateGGS(Mobile from, Skill skill) {              // :787
    if (!GGSActive) return;                                           // :789-790
    var list   = (int)Math.Min(GGSTable.Length - 1, skill.Base / 5);    // :792
    var column = from.Skills.Total >= 7000 ? 2 : from.Skills.Total >= 3500 ? 1 : 0;  // :793
    skill.NextGGSGain = DateTime.UtcNow + TimeSpan.FromMinutes(GGSTable[list][column]); // :795
}
```

| Rule | Exact behaviour | Source |
|---|---|---|
| Active? | `GGSActive == !Siege.SiegeShard`; `Siege.IsSiege` config default `false` | `:40`, `Scripts/Misc/Siege.cs:18`, `Config/Siege.cfg:3` |
| Row selection | `(int)Math.Min(23, skill.Base / 5)` — `Math.Min(int,double)` so this is `floor(Base/5)` capped at 23 ⇒ **row `r` covers `Base ∈ [5r, 5r+5)`**, i.e. 5r … 5r+4.9 | `:792` |
| Column selection | `Total >= 7000` → col 2; else `Total >= 3500` → col 1; else col 0. `Total` is in fixed points ⇒ thresholds are **350.0 and 700.0 displayed skill** | `:793` |
| Timer value | `GGSTable[row][col]` **minutes** | `:795` |
| Timestamp update point | only after a real skill point was granted, only for `PlayerMobile`, and it reads `skill.Base` **after** the increment | `:450-451`, `:446` |
| Guarantee trigger | `CheckGGS` is the 3rd operand of the `||` chain in `CheckSkill`, so GGS is consulted **only when the random roll failed** | `:250` |
| GGS gain amount | unchanged — the normal `Gain()` path applies (§3.3), so 0.1 / 1-4 / 2-5 etc. | `:250-253` |
| Persistence | `Skill.NextGGSGain` is a `DateTime` auto-property; serialized with flag `0x10`, read back at version bit `0x10` | `Server/Skills.cs:278-283,157-160,223-226,250-253` |
| Fresh-character artefact | neither `Skill` constructor sets `NextGGSGain`, so it defaults to `DateTime.MinValue` ⇒ `CheckGGS` returns **true** for every skill that has never gained. The first failed gain roll after `Base >= 10.0` therefore always succeeds, then `UpdateGGS` installs the real timer | `Server/Skills.cs:174-181,104-172` + `SkillCheck.cs:779-782` |
| Non-players | never: the `from is PlayerMobile` test excludes creatures | `:779` |

**Full `GGSTable`** — 24 rows × 3 columns, verbatim, `SkillCheck.cs:798-806`:

| Row | Skill band (`Base`) | col0: Total < 350.0 | col1: Total ≥ 350.0 | col2: Total ≥ 700.0 |
|---|---|---|---|---|
| 0 | 0.0 – 4.9 | 1 | 3 | 5 |
| 1 | 5.0 – 9.9 | 4 | 10 | 18 |
| 2 | 10.0 – 14.9 | 7 | 17 | 30 |
| 3 | 15.0 – 19.9 | 9 | 24 | 44 |
| 4 | 20.0 – 24.9 | 12 | 31 | 57 |
| 5 | 25.0 – 29.9 | 14 | 38 | 90 |
| 6 | 30.0 – 34.9 | 17 | 45 | 84 |
| 7 | 35.0 – 39.9 | 20 | 52 | 96 |
| 8 | 40.0 – 44.9 | 23 | 60 | 106 |
| 9 | 45.0 – 49.9 | 25 | 66 | 120 |
| 10 | 50.0 – 54.9 | 27 | 72 | 138 |
| 11 | 55.0 – 59.9 | 33 | 90 | 162 |
| 12 | 60.0 – 64.9 | 55 | 150 | 264 |
| 13 | 65.0 – 69.9 | 78 | 216 | 390 |
| 14 | 70.0 – 74.9 | 114 | 294 | 540 |
| 15 | 75.0 – 79.9 | 144 | 384 | 708 |
| 16 | 80.0 – 84.9 | 180 | 492 | 900 |
| 17 | 85.0 – 89.9 | 228 | 606 | 1116 |
| 18 | 90.0 – 94.9 | 276 | 744 | 1356 |
| 19 | 95.0 – 99.9 | 336 | 894 | 1620 |
| 20 | 100.0 – 104.9 | 396 | 1056 | 1920 |
| 21 | 105.0 – 109.9 | 468 | 1242 | 2280 |
| 22 | 110.0 – 114.9 | 540 | 1440 | 2580 |
| 23 | 115.0 – 120.0 (power-scroll max) | 618 | 1662 | 3060 |

All values are **minutes**. Notes: row 6 col2 (`84`) is **lower than** row 5 col2 (`90`) — a non-monotonic literal in the source, reproduced verbatim, not a transcription error. All three columns are monotonic increasing everywhere else. Rows 20-23 are only reachable with power scrolls (individual cap > 100.0).

**ModernUO:** GGS does **not exist**. Grepping the whole `Projects/` tree for `GGSTable`, `NextGGSGain`, `UpdateGGS`, `CheckGGS`, `GGSActive`, and `guaranteedGain` returns **zero matches**; `Skill` has no GGS field (`ModernUO:Projects/Server/Skills.cs:86-393`). Equivalently: guaranteed-gain behaviour must be re-implemented from the ServUO table for a faithful clone.

---

### 3.8 Stat gain

Constants and configuration (`SkillCheck.cs:17-57`):

| Constant | Default | Config key | Source |
|---|---|---|---|
| `_StatGainDelay` | `15` min, then **overwritten to 0.5 s** unless the enable-flag is set | `PlayerCaps.PlayerStatTimeDelay` + `PlayerCaps.EnablePlayerStatTimeDelay` (`false`) | `:46,52-53` |
| `_PetStatGainDelay` | `5` min, then **0.5 s** unless the enable-flag is set | `PlayerCaps.PetStatTimeDelay` + `PlayerCaps.EnablePetStatTimeDelay` (`false`) | `:47,55-56` |
| `_PlayerChanceToGainStats` | `5` (⇒ `/100.0` = **5 %**) | `PlayerCaps.PlayerChanceToGainStats` | `:49,510` |
| `_PetChanceToGainStats` | `5` (⇒ **5 %**) | `PlayerCaps.PetChanceToGainStats` | `:50,506` |
| Enable flags in shipped cfg | `EnablePlayerStatTimeDelay=false`, `EnablePetStatTimeDelay=false` ⇒ delays are **0.5 s** by default | — | `Config/PlayerCaps.cfg:45,54` |
| One-shot forced delay | `if (!Config.Get("PlayerCaps.EnablePlayerStatTimeDelay", false)) _StatGainDelay = TimeSpan.FromSeconds(0.5);` | — | `:52-53` |

**Two mutually exclusive stat-gain paths** inside `Gain()` (`:460-481`):

```csharp
if (skill.Lock == SkillLock.Up && (!Siege.SiegeShard || !(from is PlayerMobile) || Siege.CanGainStat((PlayerMobile)from)))
{
    var info = skill.Info;
    if (!Core.ML) {                       // :466  "Old gain mechanic"
        var scalar = 1.0;                                                  // :468
        if (from.StrLock == StatLockType.Up && (info.StrGain / 33.3) * scalar > Utility.RandomDouble())
            GainStat(from, Stat.Str);                                      // :470-471
        else if (from.DexLock == StatLockType.Up && (info.DexGain / 33.3) * scalar > Utility.RandomDouble())
            GainStat(from, Stat.Dex);                                      // :472-473
        else if (from.IntLock == StatLockType.Up && (info.IntGain / 33.3) * scalar > Utility.RandomDouble())
            GainStat(from, Stat.Int);                                      // :474-475
    } else TryStatGain(info, from);                                        // :477-480
}
```

| Path | Era | Chance per stat | Per skill-gain call | Source |
|---|---|---|---|---|
| Legacy | `!Core.ML` (pre-Mondain's Legacy) | `info.XxxGain / 33.3` independently per stat, gated by that stat's `StatLockType.Up` | `else if` chain ⇒ **at most one** stat per call, evaluated Str → Dex → Int | `:466-476` |
| Modern | `Core.ML` | flat **5 %** (`_PlayerChanceToGainStats/100.0` or `_PetChanceToGainStats/100.0`) | at most one stat; 75/25 split | `:499-564` |

`TryStatGain` (`:499-564`) in full detail:

| Step | Behaviour | Source |
|---|---|---|
| Chance roll | `if (Utility.RandomDouble() >= chance) return;` — `chance = _PetChanceToGainStats/100.0` for **controlled** creatures, else `_PlayerChanceToGainStats/100.0` | `:504-516` |
| Lock lookup | `primaryLock` / `secondaryLock` initialised to `StatLockType.Locked` and only overwritten by a `switch` on `info.Primary` / `info.Secondary` (Str/Dex/Int) | `:519-546` |
| Both up | `if (primaryLock == Up && secondaryLock == Up) { if (Utility.Random(4) == 0) GainStat(Secondary) else GainStat(Primary); }` ⇒ **25 % secondary / 75 % primary** | `:550-556` |
| Only primary up | `GainStat(Primary)` | `:559-560` |
| Only secondary up | `GainStat(Secondary)` | `:561-562` |
| Neither up | nothing (comment: "Will not do anything if neither are selected to gain") | `:557-563` |

`GainStat` → `CheckStatTimer` (`:719-772`) — **per-stat timestamps**:

```csharp
public static void GainStat(Mobile from, Stat stat) { if (!CheckStatTimer(from, stat)) return; IncreaseStat(from, stat); }  // :719-725
// CheckStatTimer, Str branch (:731-743):
if (from is BaseCreature && ((BaseCreature)from).Controlled) { if (from.LastStrGain + _PetStatGainDelay >= DateTime.UtcNow) return false; }
else if (from.LastStrGain + _StatGainDelay >= DateTime.UtcNow) return false;
from.LastStrGain = DateTime.UtcNow; return true;
// Dex :744-756 uses LastDexGain, Int :757-769 uses LastIntGain — identical structure
```

`LastStrGain` / `LastDexGain` / `LastIntGain` are `DateTime` properties on `Mobile` (`Server/Mobile.cs:9388-9394`), serialized with `WriteDeltaTime` (`:6414-6416`) and read back at `:5870-5872`; `LastStatGain` (setter sets all three) at `:9398-9419`.

`IncreaseStat` and the **at-total-cap drain rule** (`:629-717`):

```csharp
bool atTotalCap = from.RawStatTotal >= from.StatCap;                       // :631
case Stat.Str:
  if (CanRaise(from, Stat.Str, atTotalCap)) {                              // :637
      if (atTotalCap) {                                                    // :639
          if (CanLower(from, Stat.Dex) && (from.RawDex < from.RawInt || !CanLower(from, Stat.Int))) --from.RawDex;  // :641-642
          else if (CanLower(from, Stat.Int)) --from.RawInt;                // :643-644
      }
      ++from.RawStr;                                                       // :647
      ... HitsMaxSeed++ for creatures, Siege.IncreaseStat for siege players ...   // :649-657
  }
// Dex :662-688 drains the lower of Str/Int;  Int :689-716 drains the lower of Str/Dex
```

| Rule | Exact behaviour | Source |
|---|---|---|
| `atTotalCap` | deterministic: `from.RawStatTotal >= from.StatCap` | `:631` |
| `CanRaise(from, stat, atTotalCap)` | first `stat < stat cap`; then, if `atTotalCap && from is PlayerMobile`, requires `CanLower` of **one of the other two** stats; **non-players at the cap return `true`** and may exceed `StatCap` | `:581-627` |
| `CanLower(from, stat)` | `stat.Lock == StatLockType.Down && RawXxx > 10` — the stat must be **Down-locked** and above the floor of 10 | `:566-579` |
| Drain choice (Str gain) | drain Dex if `CanLower(Dex) && (RawDex < RawInt || !CanLower(Int))`, else drain Int — i.e. drain the **lower** of the two others; on a tie (`RawDex == RawInt`, both lowerable) the first condition fails and **Int** is drained | `:641-644` |
| Drain choice (Dex gain) | drain Str if `CanLower(Str) && (RawStr < RawInt || !CanLower(Int))`, else drain Int | `:668-671` |
| Drain choice (Int gain) | drain Str if `CanLower(Str) && (RawStr < RawDex || !CanLower(Dex))`, else drain Dex | `:695-698` |
| Swap semantics | exactly 1 point drained, 1 point added per successful call — no partial or multi-point drain | `:641-647` |
| Creature side effects | `HitsMaxSeed++` on Str, `StamMaxSeed++` on Dex, `ManaMaxSeed++` on Int when the seed is `> -1` and below the respective cap | `:649-652,676-679,703-706` |
| Siege | extra `Siege.IncreaseStat(pm)` bookkeeping | `:654-657,681-684,708-711` |
| Per-stat caps | `Mobile.StrCap` / `DexCap` / `IntCap`, defaults **125** each (`PlayerCaps.StrCap/DexCap/IntCap`); `StrMaxCap`/`DexMaxCap`/`IntMaxCap` default **150** and cap the *effective* (equipment-boosted) stat from ML onwards | `Server/Mobile.cs:12747-12786,11129-11134`; `Config/PlayerCaps.cfg:19-34`; `Scripts/Mobiles/PlayerMobile.cs:2004-2050` |
| Total stat cap | `Mobile.StatCap` default **225** (`PlayerCaps.TotalStatCap`); `RawStatTotal = RawStr + RawDex + RawInt` | `Server/Mobile.cs:12725-12744,12801`; `Config/PlayerCaps.cfg:16` |
| Stat lock transmission | setting `StrLock`/`DexLock`/`IntLock` sends `StatLockInfo` packet `0xBF` sub-command `0x19` with a packed byte `StrLock<<4 | DexLock<<2 | IntLock` | `Server/Mobile.cs:1783-1840`, `Server/Network/Packets.cs:478-507` |
| Client → server stat lock | extended packet `0xBF` sub-command `0x1A` → `StatLockChange` | `Server/Network/PacketHandlers.cs:152,2121-2148` |
| Siege stat gating | stat gain requires `Siege.CanGainStat` (max `StatsPerDay = 15`); `MinutesPerGain` returns 0 below 70.0, else 5 / 8 / 12 / 15 minutes for ≤79.9 / ≤89.9 / ≤99.9 / above | `Scripts/Misc/Siege.cs:22,318-352,354-379,381-389` |
| Stat cap raise item | `StatCapScroll` uses `PlayerCaps.TotalStatCap` as its base | `Scripts/Items/Consumables/StatScroll.cs:8` |

**ModernUO differences** (`ModernUO:Projects/UOContent/Skills/SkillCheck.cs`):

| Aspect | ServUO | ModernUO | Source |
|---|---|---|---|
| Where | `TryStatGain()` called from `Gain()` when `Core.ML` | `Gain()` inline block, gated by `_usePub45StatGain` (default `Core.ML`) | `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:284-309` |
| Chance | `5 %`, `PetChanceToGainStats` separate | `0.05 * _statGainChanceMultiplier` (config `stats.gainChanceMultiplier`, default `1.0`); **no** separate pet chance | `:24,300` |
| Split | `Random(4) == 0` → secondary, else primary (75/25) | `primaryStatLock is Up && _primaryStatGainChance > RandomDouble()` → primary, else secondary; `stats.primaryStatGainChance` default **0.75** | `:25,303-305` |
| Delay | 15 min (config) but forced to 0.5 s by default | `stats.gainDelay` default `Core.ML ? 0.05 min (3 s) : 10 min`; `stats.petGainDelay` default 5 min | `:26-27` |
| Legacy path | pre-ML `info.XxxGain / 33.3` **else-if** chain called from `Gain()` | `LegacyGain()` called from `CheckSkill` **on success only**, three independent `if`s with `info.XxxGain > 0` guards (so up to 3 stats per call) | `:152-155,312-328` |
| Per-stat caps | `StrCap`/`DexCap`/`IntCap` per mobile, default 125 | single `_statMax` = config `stats.statMax`, default `Core.LBR ? 125 : 100`; also enforced with `Math.Min(..., _statMax)` | `:23,365-367,394` |
| Total-cap rule | `CanRaise` requires a drainable other stat; drain uses the deterministic `RawStatTotal >= StatCap` | `CanRaise` returns `false` outright when `RawStatTotal >= StatCap` (non-controlled); `IncreaseStat` drains **first** (so the total can drop below the cap before the raise test), and the drain also fires on a *random* atrophy roll `RawStatTotal / StatCap >= RandomDouble()` even when not at cap | `:352-370,372-442,501-503` |
| Stat cap | 225 default | 225 default | `ModernUO:Projects/Server/Mobiles/Mobile.cs:7826,6436` |

---

### 3.9 Full 58-row `SkillInfo.Table` (`Server/Skills.cs:594-654`)

Column notes: `StrScale`/`DexScale`/`IntScale` are the **raw constructor literals** — the constructor stores `StrScale = strScale / 100.0` (`Server/Skills.cs:545-547`), so raw `5.0` ⇒ effective scale `0.05`. `StatTotal = strScale + dexScale + intScale` using the **raw** values (`:558`), e.g. Alchemy `0+5+5 = 10`. `GainFactor` is **1.0 for all 58 rows** (`:596-653`). Line numbers are `596 + id`. [SRC]

| id | Skill | Primary | Secondary | StrGain | DexGain | IntGain | StrScale | DexScale | IntScale | GainFactor | line | mastery |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Alchemy | Int | Dex | 0.0 | 0.5 | 0.5 | 0.0 | 5.0 | 5.0 | 1.0 | 596 | — |
| 1 | Anatomy | Int | Str | 0.15 | 0.15 | 0.7 | 0.0 | 0.0 | 0.0 | 1.0 | 597 | — |
| 2 | Animal Lore | Int | Str | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 598 | — |
| 3 | Item Identification | Int | Dex | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 599 | — |
| 4 | Arms Lore | Int | Str | 0.75 | 0.15 | 0.1 | 0.0 | 0.0 | 0.0 | 1.0 | 600 | — |
| 5 | Parrying | Dex | Str | 0.75 | 0.25 | 0.0 | 7.5 | 2.5 | 0.0 | 1.0 | 601 | ✔ |
| 6 | Begging | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 602 | — |
| 7 | Blacksmithy | Str | Dex | 1.0 | 0.0 | 0.0 | 10.0 | 0.0 | 0.0 | 1.0 | 603 | — |
| 8 | Bowcraft/Fletching | Dex | Str | 0.6 | 1.6 | 0.0 | 6.0 | 16.0 | 0.0 | 1.0 | 604 | — |
| 9 | Peacemaking | Int | Dex | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 605 | ✔ |
| 10 | Camping | Dex | Int | 2.0 | 1.5 | 1.5 | 20.0 | 15.0 | 15.0 | 1.0 | 606 | — |
| 11 | Carpentry | Str | Dex | 2.0 | 0.5 | 0.0 | 20.0 | 5.0 | 0.0 | 1.0 | 607 | — |
| 12 | Cartography | Int | Dex | 0.0 | 0.75 | 0.75 | 0.0 | 7.5 | 7.5 | 1.0 | 608 | — |
| 13 | Cooking | Int | Dex | 0.0 | 2.0 | 3.0 | 0.0 | 20.0 | 30.0 | 1.0 | 609 | — |
| 14 | Detecting Hidden | Int | Dex | 0.0 | 0.4 | 0.6 | 0.0 | 0.0 | 0.0 | 1.0 | 610 | — |
| 15 | Discordance | Dex | Int | 0.0 | 0.25 | 0.25 | 0.0 | 2.5 | 2.5 | 1.0 | 611 | ✔ |
| 16 | Evaluating Intelligence | Int | Str | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 612 | — |
| 17 | Healing | Int | Dex | 0.6 | 0.6 | 0.8 | 6.0 | 6.0 | 8.0 | 1.0 | 613 | — |
| 18 | Fishing | Dex | Str | 0.5 | 0.5 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 614 | — |
| 19 | Forensic Evaluation | Int | Dex | 0.0 | 0.2 | 0.8 | 0.0 | 0.0 | 0.0 | 1.0 | 615 | — |
| 20 | Herding | Int | Dex | 1.625 | 0.625 | 0.25 | 16.25 | 6.25 | 2.5 | 1.0 | 616 | — |
| 21 | Hiding | Dex | Int | 0.0 | 0.8 | 0.2 | 0.0 | 0.0 | 0.0 | 1.0 | 617 | — |
| 22 | Provocation | Int | Dex | 0.0 | 0.45 | 0.05 | 0.0 | 4.5 | 0.5 | 1.0 | 618 | ✔ |
| 23 | Inscription | Int | Dex | 0.0 | 0.2 | 0.8 | 0.0 | 2.0 | 8.0 | 1.0 | 619 | — |
| 24 | Lockpicking | Dex | Int | 0.0 | 2.0 | 0.0 | 0.0 | 25.0 | 0.0 | 1.0 | 620 | — |
| 25 | Magery | Int | Str | 0.0 | 0.0 | 1.5 | 0.0 | 0.0 | 15.0 | 1.0 | 621 | ✔ |
| 26 | Resisting Spells | Str | Dex | 0.25 | 0.25 | 0.5 | 0.0 | 0.0 | 0.0 | 1.0 | 622 | — |
| 27 | Tactics | Str | Dex | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 623 | — |
| 28 | Snooping | Dex | Int | 0.0 | 2.5 | 0.0 | 0.0 | 25.0 | 0.0 | 1.0 | 624 | — |
| 29 | Musicianship | Dex | Int | 0.0 | 0.8 | 0.2 | 0.0 | 0.0 | 0.0 | 1.0 | 625 | — |
| 30 | Poisoning | Int | Dex | 0.0 | 0.4 | 1.6 | 0.0 | 4.0 | 16.0 | 1.0 | 626 | ✔ |
| 31 | Archery | Dex | Str | 0.25 | 0.75 | 0.0 | 2.5 | 7.5 | 0.0 | 1.0 | 627 | ✔ |
| 32 | Spirit Speak | Int | Str | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 628 | (UseWhileCasting) |
| 33 | Stealing | Dex | Int | 0.0 | 1.0 | 0.0 | 0.0 | 10.0 | 0.0 | 1.0 | 629 | — |
| 34 | Tailoring | Dex | Int | 0.38 | 1.63 | 0.5 | 3.75 | 16.25 | 5.0 | 1.0 | 630 | — |
| 35 | Animal Taming | Str | Int | 1.4 | 0.2 | 0.4 | 14.0 | 2.0 | 4.0 | 1.0 | 631 | ✔ |
| 36 | Taste Identification | Int | Str | 0.2 | 0.0 | 0.8 | 0.0 | 0.0 | 0.0 | 1.0 | 632 | — |
| 37 | Tinkering | Dex | Int | 0.5 | 0.2 | 0.3 | 5.0 | 2.0 | 3.0 | 1.0 | 633 | — |
| 38 | Tracking | Int | Dex | 0.0 | 1.25 | 1.25 | 0.0 | 12.5 | 12.5 | 1.0 | 634 | — |
| 39 | Veterinary | Int | Dex | 0.8 | 0.4 | 0.8 | 8.0 | 4.0 | 8.0 | 1.0 | 635 | — |
| 40 | Swordsmanship | Str | Dex | 0.75 | 0.25 | 0.0 | 7.5 | 2.5 | 0.0 | 1.0 | 636 | ✔ |
| 41 | Mace Fighting | Str | Dex | 0.9 | 0.1 | 0.0 | 9.0 | 1.0 | 0.0 | 1.0 | 637 | ✔ |
| 42 | Fencing | Dex | Str | 0.45 | 0.55 | 0.0 | 4.5 | 5.5 | 0.0 | 1.0 | 638 | ✔ |
| 43 | Wrestling | Str | Dex | 0.9 | 0.1 | 0.0 | 9.0 | 1.0 | 0.0 | 1.0 | 639 | ✔ |
| 44 | Lumberjacking | Str | Dex | 2.0 | 0.0 | 0.0 | 20.0 | 0.0 | 0.0 | 1.0 | 640 | — |
| 45 | Mining | Str | Dex | 2.0 | 0.0 | 0.0 | 20.0 | 0.0 | 0.0 | 1.0 | 641 | — |
| 46 | Meditation | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 642 | — |
| 47 | Stealth | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 643 | — |
| 48 | Remove Trap | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 644 | — |
| 49 | Necromancy | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 645 | ✔ |
| 50 | Focus | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 646 | — |
| 51 | Chivalry | Str | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 647 | ✔ |
| 52 | Bushido | Str | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 648 | ✔ |
| 53 | Ninjitsu | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 649 | ✔ |
| 54 | Spellweaving | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 650 | ✔ |
| 55 | Mysticism | Str | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 651 | ✔ |
| 56 | Imbuing | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 652 | — |
| 57 | Throwing | Dex | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 653 | ✔ |

Skills with **zero in all three gain columns** (no stat influence at all in the legacy path, and only the 5 % flat roll in the ML path with the listed primary/secondary): Begging, Peacemaking, Tactics, Meditation, Stealth, Remove Trap, Necromancy, Focus, Chivalry, Bushido, Ninjitsu, Spellweaving, Mysticism, Imbuing, Throwing.

**ModernUO** loads the same data from JSON, not code: `SkillInfo.Table = JsonConfig.Deserialize<SkillInfo[]>(Path.Combine(Core.BaseDirectory, "Data/skills.json"))` (`ModernUO:Projects/UOContent/Skills/SkillsInfo.cs:135`; model `Projects/Server/Skills.cs:395-452`; data `Distribution/Data/skills.json`, 58 entries lines 1-930). The JSON stores the already-divided scales (e.g. Alchemy `"StrScale": 0.05`) **and** the raw `StatTotal` (e.g. `"StatTotal": 10`) with the same primary/secondary columns. Diffing all 58 rows against ServUO: **identical values except skill 15 Discordance**, where ServUO has `Primary = Dex, Secondary = Int` (`Skills.cs:611`) and ModernUO has `"PrimaryStat": "Int", "SecondaryStat": "Dex"` (`skills.json:255-256`). [SRC]

---

### 3.10 `StrScale` / `DexScale` / `IntScale` and the effective skill value

`Skill.Value` = max(`NonRacialValue`, racial bonus), where `Mobile.GetRacialSkillBonus` supplies e.g. elf/gargoyle bonuses (`Server/Skills.cs:372-389`).

`Skill.NonRacialValue` (`Server/Skills.cs:391-468`), verbatim structure:

```csharp
double baseValue = Base;                                  // :396  fixed-point base / 10
double inv = 100.0 - baseValue;  if (inv < 0.0) inv = 0.0;  // :397-402
inv /= 100.0;                                             // :404   ← normalised 1.0 … 0.0

double statsOffset = ((m_UseStatMods ? Owner.Str  : Owner.RawStr) * Info.StrScale) +   // :406
                     ((m_UseStatMods ? Owner.Dex  : Owner.RawDex) * Info.DexScale) +   // :407
                     ((m_UseStatMods ? Owner.Int  : Owner.RawInt) * Info.IntScale);    // :408
double statTotal = Info.StatTotal * inv;                  // :409
statsOffset *= inv;                                       // :411
if (statsOffset > statTotal) statsOffset = statTotal;     // :413-416

double value = baseValue + statsOffset;                   // :418
Owner.ValidateSkillMods();                                // :420
// relative SkillMods: ObeyCap → bonusObey, else bonusNotObey; absolute mod REPLACES value  // :426-450
value += bonusNotObey;                                    // :452
if (value < Cap) { value += bonusObey; if (value > Cap) value = Cap; }  // :454-462
Owner.MutateSkill(SkillName, ref value);                  // :464
return value;                                             // :466
```

Formula, collapsed:

```
b   = Base                                   (0 … Cap, typically 0 … 1000/10)
inv = max(100 - b, 0) / 100                  (1.0 at b=0 → 0.0 at b>=100)
raw = RawStr*StrScale + RawDex*DexScale + RawInt*IntScale      (scales = literal/100)
off = min(raw, StatTotal) * inv               ← both sides scaled by inv
value = b + off + bonusNotObey  (+ bonusObey while value < Cap, clamped to Cap)
```

**Meaning of the scales:**

| Aspect | Detail | Source |
|---|---|---|
| What the scales do | they convert the mobile's Str/Dex/Int into a *skill bonus*, capped by `StatTotal` (the raw sum of the three literals) | `:406-416` |
| Cap on the bonus | `min(statsOffset, StatTotal) * inv` — so at 100 Str/Dex/Int a skill can receive at most `StatTotal` points, e.g. Blacksmithy raw 10/0/0 ⇒ `Str 100 × 0.10 = 10`, `StatTotal = 10` ⇒ **+10.0 Blacksmithy at 100 Str** | `:409-418`, `:603` |
| Fade-out | every bonus is multiplied by `inv = (100 - Base)/100`, so the stat bonus decays linearly and is **zero at Base ≥ 100.0** | `:397-411` |
| Full example | Blacksmithy Base 50, Str 100, Dex 100: `inv = 0.5`; `raw = 100*0.10 = 10`; `off = min(10, 10) * 0.5 = 5.0`; `value = 55.0` | [DERIVED from SRC] |
| `UseStatMods` | a static toggle (`Skill.UseStatMods`) choosing *effective* Str/Dex/Int over **raw**; grep shows it is **never assigned anywhere** in pub57 ⇒ always `false` ⇒ **raw** stats are used | `Server/Skills.cs:366-368,406-408` |
| Skill mods | absolute (`Relative == false`) mod **replaces** the value outright; relative mods split into obey-cap (`+` only while `value < Cap`, clamped to `Cap`) and non-obey-cap (always added) | `:426-462` |
| Side effect | reading a skill value calls `Mobile.ValidateSkillMods()` (`Server/Mobile.cs:1320-1335`), which **removes** mods whose `CheckCondition()` is false | `:420`, `Server/Mobile.cs:1320-1335` |
| AoS/era switch | `CurrentExpansion.Configure()` calls `AOS.DisableStatInfluences()` whenever `Core.AOS`; that sets `StrScale = DexScale = IntScale = StatTotal = 0.0` for **all 58 rows** ⇒ stat influence is **completely disabled** | `Server/Main.cs:147`, `Scripts/Misc/CurrentExpansion.cs:34-39`, `Scripts/Misc/AOS.cs:36-47` |
| Default expansion | `Config.GetEnum("Expansion.CurrentExpansion", Expansion.EJ)` and shipped `CurrentExpansion=EJ` ⇒ `Core.AOS == true` ⇒ **a stock ServUO pub57 has zero stat influence on skill values** | `Scripts/Misc/CurrentExpansion.cs:13`, `Config/Expansion.cfg:15` |

**ModernUO** uses the same idea with a different factorisation (`ModernUO:Projects/Server/Skills.cs:250-331`):

```
statsOffset = RawStr*StrScale + RawDex*DexScale + RawInt*IntScale      // JSON scales are already /100
inv = 100 - Base                                                        // NOT divided by 100
if (inv <= 0) statsOffset = 0
else { statsOffset *= inv;  if (StatTotal > 0) statsOffset = min(statsOffset, StatTotal*inv); }
value = Base + statsOffset
```

Because ModernUO does not divide `inv` by 100 (it divides in the constructor instead, `Projects/Server/Skills.cs:407-409`) and the JSON `StatTotal` is the raw sum, the two formulations are algebraically equivalent for the shipped data: ServUO `100 Str × 0.10 × 1.0 = +10` vs ModernUO `100 × 0.001 × 100 = +10`. ModernUO has **no** `UseStatMods` toggle (always `RawStr/Dex/Int`) and applies the same `DisableStatInfluences()` zeroing when `Core.AOS` (`ModernUO:Projects/UOContent/Skills/SkillsInfo.cs:137-140`, `Projects/UOContent/Misc/AOS.cs:15-26`). ModernUO also applies `min(statsOffset, StatTotal*inv)` only when `StatTotal > 0`, whereas ServUO always clamps (equivalent when the scales are non-zero). [SRC]

---

### 3.11 Worked numeric examples of `gc` per band

All arithmetic below is `[DERIVED from SRC]` — inputs are the literals in `SkillCheck.cs:261-284`; no value is invented. Assume a player (no pet bonus), `GainFactor = 1.0`, `Skills.Cap = 7000` (700.0), individual `skill.Cap = 1000` (100.0), `chance` from §3.2.

**Band A — mid skill, low total, successful use.** `Total = 3500` (350.0), `Base = 50.0`, `Cap = 100.0`, `chance = 0.5`, `success = true`:

```
T = (7000 - 3500) / 7000 = 0.5000
S = (1000 -  500) / 1000 = 0.5000
(T + S) / 2              = 0.5000
D = (1 - 0.5) * 0.5      = 0.2500
(0.5 + 0.25) / 2         = 0.3750
gc = 0.3750 * 1.0        = 0.3750   → 37.5 % per skill-use attempt
```

**Band B — same, but the use failed and the shard is AoS+ (`Core.AOS == true`, the stock EJ default).** Only `k` changes, `0.5 → 0.0`:

```
D = (1 - 0.5) * 0.0 = 0.0000
gc = (0.5000 + 0.0) / 2 * 1.0 = 0.2500   → 25.0 %
```

**Band C — same failure on a pre-AoS shard (`Core.AOS == false`).** `k = 0.2`:

```
D = (1 - 0.5) * 0.2 = 0.1000
gc = (0.5000 + 0.1000) / 2 = 0.3000   → 30.0 %
```

**Band D — at the 700.0 total cap, high skill.** `Total = 7000`, `Base = 90.0`, `Cap = 100.0`, `chance = 0.5`, `success = true`:

```
T = (7000 - 7000) / 7000 = 0.0000
S = (1000 -  900) / 1000 = 0.1000
(T + S) / 2              = 0.0500
D = (1 - 0.5) * 0.5      = 0.2500
gc = (0.05 + 0.25) / 2   = 0.1500   → 15.0 %
```

**Band E — the 0.01 floor takes over.** `Total = 7000`, `Base = 100.0` (= `Cap`), `chance = 1.0`, `success = true` (this state is normally unreachable because `Gain()` requires `Base < Cap`, but `gc` is still computed):

```
T = 0.0000 ; S = 0.0000 ; (T+S)/2 = 0.0000 ; D = (1-1.0)*0.5 = 0.0000
gc_raw = 0.0000  →  floor  →  gc = 0.0100   → 1.0 %
```

**Band F — controlled pet (the +100 % branch).** Take Band A's `gc = 0.3750` with `from` a controlled `BaseCreature`:

```
gc = 0.3750 ; gc += gc * 1.00 → 0.7500 ; 0.7500 <= 1.00 → gc = 0.7500   → 75.0 %
```

**Band G — the pet bonus hitting the clamp.** `Total = 0`, `Base = 0.0`, `chance = 0.0`. (In practice `Base < 10.0` bypasses `gc` entirely, so this is the formula's ceiling, not a live path):

```
T = 1.0 ; S = 1.0 ; (T+S)/2 = 1.0 ; D = (1-0.0)*0.5 = 0.5
gc = (1.0 + 0.5)/2 = 0.75 ; pet: 0.75*2 = 1.50 → clamp → gc = 1.00   → 100 %
```

**Band H — the bulk/craft-all overload (§3.1b) with `amount` iterations.** `Total = 3500`, `Base = 50.0`, `Cap = 100.0`, normalised difficulty `gains = 0.5`:

```
gc = (7000 - (3500 + 0.5*10)) / 7000 = 3495 / 7000 = 0.49928571
gc += (1000 - (500 + 5))   / 1000    =  495 / 1000 = 0.49500000
     sum = 0.99428571
gc /= 4                              = 0.24857143
gc *= 1.0                            = 0.24857143   → ~24.86 % per iteration
```

**GGS timers for the same states** (minutes, `§3.7`): `Total = 3500, Base = 50.0` ⇒ row `floor(50/5) = 10`, column 1 ⇒ **72 minutes**. `Total = 7000, Base = 90.0` ⇒ row 18, column 2 ⇒ **1356 minutes** (22.6 h). Both `[DERIVED from SRC]` (`SkillCheck.cs:792-795,798-806`).

---

### 3.12 Every `PlayerCaps` (skill/stat-related) config key

Grepped the whole `servuo` tree for `Config.Get("PlayerCaps…`. Complete list, with code default, shipped `Config/PlayerCaps.cfg` value, and meaning:

| Key | Code default | Cfg value | Read at | Meaning |
|---|---|---|---|---|
| `PlayerCaps.TotalSkillCap` | `7000` | `7000` | `Server/Skills.cs:996`; also `Scripts/Services/VeteranRewards/RewardSystem.cs:18`, `Scripts/Services/Reports/Reports.cs:157` | Total skill cap in **fixed points** (700.0). Applied to every new `Skills` instance |
| `PlayerCaps.SkillCap` | `1000.0` (double) | `1000` | `Scripts/Misc/CharacterCreation.cs:211` | Individual skill cap in fixed points, divided by 10 → 100.0; applied to all skills at creation only when ≠ 100.0 |
| `PlayerCaps.TotalStatCap` | `225` | `225` | `Server/Mobile.cs:11128`, `:6103`; `Scripts/Mobiles/Bosses/Harrower/Harrower.cs:12`; `Scripts/Items/Consumables/StatScroll.cs:8` | Total stat cap (Str+Dex+Int) |
| `PlayerCaps.StrCap` | `125` | `125` | `Server/Mobile.cs:11129`, `:6078` | Per-stat cap for raw Str |
| `PlayerCaps.DexCap` | `125` | `125` | `Server/Mobile.cs:11130`, `:6079` | Per-stat cap for raw Dex |
| `PlayerCaps.IntCap` | `125` | `125` | `Server/Mobile.cs:11131`, `:6080` | Per-stat cap for raw Int |
| `PlayerCaps.StrMaxCap` | `150` | `150` | `Server/Mobile.cs:11132`, `:6081` | Cap on **effective** (equipment-boosted) Str, ML+ (`PlayerMobile.cs:2004-2018`) |
| `PlayerCaps.DexMaxCap` | `150` | `150` | `Server/Mobile.cs:11133`, `:6082` | Cap on effective Dex, ML+ |
| `PlayerCaps.IntMaxCap` | `150` | `150` | `Server/Mobile.cs:11134`, `:6083` | Cap on effective Int, ML+ |
| `PlayerCaps.StatCap` | *(not read by any code)* | `125` | — | **Deprecated**; cfg comment says "Deprecated: The individual stat cap" (`PlayerCaps.cfg:40-41`). Dead key |
| `PlayerCaps.EnablePlayerStatTimeDelay` | `false` | `false` | `Scripts/Misc/SkillCheck.cs:52` | If **false**, `_StatGainDelay` is overwritten with `TimeSpan.FromSeconds(0.5)` |
| `PlayerCaps.PlayerStatTimeDelay` | `TimeSpan.FromMinutes(15.0)` | `00:00:15:00` | `Scripts/Misc/SkillCheck.cs:46` | Player stat-gain cooldown; ignored unless the enable-flag above is true |
| `PlayerCaps.EnablePetStatTimeDelay` | `false` | `false` | `Scripts/Misc/SkillCheck.cs:55` | If **false**, `_PetStatGainDelay` becomes 0.5 s |
| `PlayerCaps.PetStatTimeDelay` | `TimeSpan.FromMinutes(5.0)` | `00:00:05:00` | `Scripts/Misc/SkillCheck.cs:47` | Pet stat-gain cooldown; ignored unless enabled |
| `PlayerCaps.PlayerChanceToGainStats` | `5` (int) | `5.0` | `Scripts/Misc/SkillCheck.cs:49` | Percent chance per stat-gain roll, players (`/100.0`) |
| `PlayerCaps.PetChanceToGainStats` | `5` (int) | `5.0` | `Scripts/Misc/SkillCheck.cs:50` | Percent chance per stat-gain roll, controlled pets (`/100.0`) |
| `PlayerCaps.EnableAntiMacro` | `false` | `False` | `Scripts/Misc/SkillCheck.cs:44` | Master switch for the §3.6 anti-macro code |

Adjacent, non-`PlayerCaps` keys that change skill/stat behaviour:

| Key | Default | Read at | Effect |
|---|---|---|---|
| `Expansion.CurrentExpansion` | `Expansion.EJ` | `Scripts/Misc/CurrentExpansion.cs:13` | Drives `Core.AOS/SE/ML/SA/TOL`; `AOS` zeroes all stat scales, `ML` selects the 5 % stat-gain path and the 150 stat max-caps, `SE` makes `BaseCreature.SetSkill` grow `SkillsCap` |
| `Siege.IsSiege` | `false` | `Scripts/Misc/Siege.cs:18` | If true: `GGSActive == false`, per-skill ROT timers, `StatsPerDay = 15` stat cap, no Young status |

[SRC] for all rows.

---

### 3.13 ServUO vs ModernUO — consolidated difference table

Bare `:NNN` ranges in the **Sources** column are **ServUO `Scripts/Misc/SkillCheck.cs`** unless another file is named.

| # | Mechanic | ServUO `pub57` | ModernUO `main` | Sources |
|---|---|---|---|---|
| 1 | Gain formula | `((T+S)/2 + D)/2 * G`, `D = (1-chance)*(success?0.5:AOS?0.0:0.2)` | identical literals and divisors | `SkillCheck.cs:261-284` ↔ `ModernUO …/SkillCheck.cs:126-133` |
| 2 | `gc` floor / pet / clamp | floor 0.01 → pet `×2` → clamp 1.00 | floor 0.01 → pet `×2` → **no explicit 1.00 clamp** (only `gc >= RandomDouble()`), so the clamp is implicit | `:273-281` ↔ `:135-145` |
| 3 | Death/low-skill bypass ordering | `AllowGain` first, then `Base < 10.0 \|\| roll \|\| GGS` | `region.AllowGain` first; `Base < 10.0` gains **regardless** of `AllowGain` (anti-macro skipped below 10.0) | `:248-253` ↔ `:118-124` |
| 4 | Success roll | `Random(100) <= (int)(chance*100)` (+1 %) | `chance >= RandomDouble()` (exact) | `:245` ↔ `:115` |
| 5 | `minSkill >= maxSkill` | the two short-circuits make the degenerate case unreachable: `value < minSkill` → `false`, and `value >= minSkill` implies `value >= maxSkill` → `true`, so the division on `:153` is never reached with `maxSkill <= minSkill` | adds an explicit (redundant) `\|\| minSkill >= maxSkill` → `true`; same observable behaviour | `:147-153` ↔ `:60-70` |
| 6 | Low-skill boost | `toGain == 1 && Base <= 10.0` → `Random(4)+1` | `Base <= 10.0` → `Random(4)+1` (no `toGain == 1` guard) | `:400-401` ↔ `:252-255` |
| 7 | Total-cap gate | `!from.Player \|\| Total + toGain <= Cap` | `!from.Player \|\| Total < Cap` (may overshoot) | `:444` ↔ `:278` |
| 8 | Reduce-skill roll | `Total / Cap` (integer division) `>= RandomDouble()` | `Total / (double)Cap >= RandomDouble()` | `:486` ↔ `:259` |
| 9 | Reduce-skill target | first `Down`-locked skill with `>= toGain` | same, but clamp `Math.Max(…-toGain, 0)` | `:488-495` ↔ `:261-270` |
| 10 | Alacrity multiplier | `toGain = RandomMinMax(2, 5)` (assignment) | `toGain *= RandomMinMax(2, 5)` (multiplicative) | `:417` ↔ `:275` |
| 11 | ML Apprentice quest bonus | `toGain *= RandomMinMax(2, 4)` via `QuestHelper.EnhancedSkill` | absent (`EnhancedSkill` does not exist) | `:404-407` ↔ — |
| 12 | Whispering mastery pet bonus | `toGain = RandomMinMax(2, 5)` with `EnhancedGainChance` % gate | absent from the gain path | `:422-436` ↔ — |
| 13 | Focus-pet exclusion | creatures unless `PetTrainingHelper.Enabled && Controlled` | **all** `BaseCreature` | `:372-374` ↔ `:243-246` |
| 14 | Jail exclusion | inside `Gain()` (`Region.IsPartOf<Jail>`) | via `Region.AllowGain` (`JailRegion` override) | `:366-367` ↔ `UOContent/Systems/JailSystem/JailRegion.cs:23` |
| 15 | Gargoyle Archery/Throwing | refused in `AllowGain` | not in the gain path (creation only) | `:339-343` ↔ `CharacterCreation.cs:451-452` |
| 16 | GGS | 24×3 table, per-skill `NextGGSGain` | **does not exist** | `:774-806` ↔ (0 grep hits) |
| 17 | Anti-macro defaults | `Enabled=false`, `Allowance=3`, `LocationSize=4`, 5 min, code table | `Enabled=false`, `Allowance=3`, **`LocationSize=5`**, 5 min, `Configuration/antimacro.json` | `:28-44` ↔ `AntiMacroSystem.cs:94-101` |
| 18 | Anti-macro allowance | 3 successful uses per `(skill,key)` per window | **2** (counter incremented before the test) | `PlayerMobile.cs:4454-4481` ↔ `AntiMacroSystem.cs:232-249` |
| 19 | Stat-gain probability | `5 %` (player) / `5 %` (pet), `Random(4)==0` secondary | `0.05 * multiplier`, `primaryStatGainChance = 0.75` | `:499-556` ↔ `:284-309` |
| 20 | Stat-gain delay default | 15 min config, **forced to 0.5 s** | `stats.gainDelay` = 3 s (ML) / 10 min, `stats.petGainDelay` = 5 min | `:52-56` ↔ `:26-27` |
| 21 | Legacy stat path | `else if` chain from `Gain()` ⇒ ≤1 stat per gain | 3 independent `if`s from `CheckSkill` on success ⇒ up to 3 | `:466-476` ↔ `:152-155,312-328` |
| 22 | Atrophy drain | only when `RawStatTotal >= StatCap` | also on a random `RawStatTotal/StatCap` roll, drain before the raise test | `:631-644` ↔ `:374,501-503` |
| 23 | Per-stat cap | `StrCap/DexCap/IntCap` = 125 per mobile | single `stats.statMax` = `Core.LBR ? 125 : 100` | `Mobile.cs:11129-11131` ↔ `:23` |
| 24 | Discordance primary/secondary | `Dex / Int` | `Int / Dex` | `Skills.cs:611` ↔ `skills.json:255-256` |
| 25 | Skill table storage | C# array literal, 58 rows | `Data/skills.json`, 58 entries | `Skills.cs:594-654` ↔ `SkillsInfo.cs:135` |
| 26 | NonRacialValue `inv` | `inv = (100-Base)/100`, applied to both `statsOffset` and `StatTotal` | `inv = 100-Base` (undivided), applied to both | `Skills.cs:396-416` ↔ `Projects/Server/Skills.cs:250-278` |

---

### 3.14 Gaps / what is NOT verifiable from source

| Item | Status | What would resolve it |
|---|---|---|
| Any player-visible message when the anti-macro allowance is exhausted | `[UNVERIFIED]` — no `Send*` call exists on that path in `SkillCheck.cs` or `PlayerMobile.AntiMacroCheck` | capture packets on a live OSI/EA shard with the allowance exhausted |
| Exact OSI `gc` formula (ServUO is a RunUO reconstruction, not a decompile) | `[UNVERIFIED]` — the ServUO constants are the working definition for the clone | statistical measurement: N thousand skill-use attempts at fixed `Base`/`Total`, fit the observed gain rate |
| Whether OSI's GGS table matches ServUO's 24×3 literals | `[UNVERIFIED]` — ServUO's table is the only concrete source here | measured time-to-guaranteed-gain per skill band on a live shard |
| `PlayerCaps.EnableAntiMacro` era claim in the shipped cfg comment ("true if the ML era flag is not on") | `[SRC]` **contradicts** it: the code default literal is `false` | nothing — the code is authoritative for ServUO; OSI behaviour would need a live shard |
| `[ERA]` 700.0 / 100.0 / 225 caps, 0.1 gain step | `[SRC]` for ServUO defaults; era attribution to Classic/pre-AoS is from the brief and is `[PARTIAL]` here | UOGuide / patch-notes citation is out of scope for this section (source-only section) |
| AoS vs ML stat-path behaviour on a real EA shard | `[PARTIAL]` — both paths exist and are switch-selected by `Core.ML` | patch notes for Publish 45 ("Preparation for UOKR", quoted in `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:29`) |

## 4. Crafting engine — core formulas

All mechanics below are read out of the ServUO `pub57` checkout on disk. Unless a row says otherwise,
the citation `ServUO:<path>:<line>` resolves to
`https://github.com/ServUO/ServUO/blob/pub57/<path>#L<line>`; `ModernUO:<path>:<line>` resolves to
`https://github.com/modernuo/ModernUO/blob/main/Projects/<path>#L<line>`.

### 4.0 Source map

| File | Lines | Role |
|---|---|---|
| `Scripts/Services/Craft/Core/CraftItem.cs` | 2291 | recipes-as-code: success/exceptional roll, resource consumption, the craft timer, `CompleteCraft` |
| `Scripts/Services/Craft/Core/CraftSystem.cs` | 632 | abstract system, `CraftECA`, sub-resource containers, `ConsumeOnFailure` |
| `Scripts/Services/Craft/Core/CraftGump.cs` | 783 | category/item/resource gump, button codec, Options panel |
| `Scripts/Services/Craft/Core/CraftGumpItem.cs` | 342 | single-item info panel + MAKE NOW / MAKE NUMBER / MAKE MAX |
| `Scripts/Services/Craft/Core/CraftContext.cs` | 329 | per-mobile sticky state (last group/resource, mark option, make-total) |
| `Scripts/Services/Craft/Core/AutoCraft.cs` | 156 | `MakeNumberCraftPrompt` + `AutoCraftTimer` (1..100 / 9999 repeats) |
| `Scripts/Services/Craft/Core/Enhance.cs` | 435 | special-material enhancement |
| `Scripts/Services/Craft/Core/Repair.cs` | 787 | repair / repair deeds / repair bench / automaton repair |
| `Scripts/Services/Craft/Core/Resmelt.cs` | 189 | item → ingot recycling |
| `Scripts/Services/Craft/Core/Recipes.cs` | 135 | `Recipe` registry, GM learn/forget commands |
| `Scripts/Services/Craft/Core/CustomCraft.cs` | 70 | abstract hook for non-`Activator` item creation |
| `Scripts/Services/Craft/Core/QueryMakersMarkGump.cs` | 53 | "place your maker's mark?" yes/no |
| `Scripts/Services/Craft/Core/CraftItemIDAttribute.cs` | 22 | `[CraftItemID(n)]` gump art override |
| `Scripts/Items/Tools/BaseTool.cs` | 315 | `ITool` interface + `BaseTool` + `CheckTool`/`CheckAccessible` |
| `Scripts/Services/Craft/Def*.cs` (11 files) | 149–1014 | the 11 concrete craft systems |

Methods named in the task that do **not** exist under those names in ServUO (checked by grep):
`Tools` array, `RequiresBlacksmith`, `RequiresTool`, `RequiresRecipe`, `CanBeMarked`, `NextCraftTime`.
What actually implements each is given in the matching subsection. `ModernUO` *does* have
`RequiresTool` (`ModernUO:Projects/UOContent/Engines/Craft/Core/CraftSystem.cs:57`) — see §4.6.

---

### 4.1 How the player starts crafting — `ITool` / `BaseTool`

| Piece | Code | Note |
|---|---|---|
| `interface ITool : IEntity, IUsesRemaining` | `ServUO:Scripts/Items/Tools/BaseTool.cs:9` | members: `CraftSystem`, `BreakOnDepletion`, `CheckAccessible(from, ref num)` |
| `abstract class BaseTool : Item, ITool, IResource, IQuality` | `BaseTool.cs:18` | default `BreakOnDepletion => true` (`:108`), default uses `Utility.RandomMinMax(25, 75)` (`:113`) |
| gump open | `BaseTool.OnDoubleClick` `BaseTool.cs:219-247` | requires `IsChildOf(from.Backpack) \|\| Parent == from`, else `1042001` "That must be in your pack for you to use it." |
| pre-check | `BaseTool.cs:231-241` | `system.CanCraft(from, this, null)`; if `num > 0 && (num != 1044267 \|\| !Core.SE)` → `SendLocalizedMessage(num)`, **else** open gump. So after SE, blacksmithing shows the gump even without anvil/forge and fails later. |
| repair-mode tool | `BaseTool.cs:225-228` | `if (Core.TOL && m_RepairMode) Repair.Do(...)` |
| `SmithHammer` duplicate path | `Scripts/Items/Tools/SmithHammer.cs:152-173` | identical logic for the `CraftTool`-style class |
| `SmithyHammer` (a `BaseBashing` weapon implementing `ITool`) | `SmithHammer.cs:50-74` | `CraftSystem => DefBlacksmithy.CraftSystem`, `CheckAccessible` → `1044263` |
| addon tools (`AddonToolComponent`) | `Scripts/Items/Addons/Craft Addons/*.cs` | e.g. `SmithingPress.cs:11`, `SewingMachine.cs:11`, `GlassKiln.cs:10`; bypass the near-anvil check |

**Tool → system binding is per item class, not a table.** `ITool.CraftSystem` is abstract
(`BaseTool.cs:110`); there is no `Tools` array anywhere in ServUO's craft code. The binding table:

| Craft system | Tool item classes (`CraftSystem =>`) |
|---|---|
| Alchemy | `MortarPestle` `Scripts/Items/Tools/MortarPestle.cs:31`; addon `AlchemyStation.cs:11` |
| Blacksmithy | `SmithHammer.cs:32`, `SledgeHammer.cs:32`, `Tongs.cs:32`, `RunicHammer.cs:36`, `AncientSmithyHammer.cs:66`, `SmithHammer.cs:61` (`SmithyHammer` weapon); addon `SmithingPress.cs:11` |
| BowFletching | `FletcherTools.cs:9`, `RunicFletcherTool.cs:33`; addon `FletchingStation.cs:11` |
| Carpentry | `Hammer.cs:31`, `Saw.cs:32`, `DovetailSaw.cs:32`, `MouldingPlane.cs:32`, `JointingPlane.cs:32`, `SmoothingPlane.cs:32`, `Scorp.cs:31`, `Inshave.cs:31`, `Froe.cs:31`, `DrawKnife.cs:31`, `Nails.cs:32`, `RunicDovetailSaw.cs:33`; addon `SpinningLathe.cs:11` |
| Cartography | `MapmakersPen.cs:32` |
| Cooking | `Skillet.cs:38`, `RollingPin.cs:31`, `FlourSifter.cs:31`; addon `BBQSmoker.cs:11` |
| Glassblowing | `Blowpipe.cs:9`; addon `GlassKiln.cs:10` |
| Inscription | `ScribesPen.cs:9`; addon `WritingDesk.cs:11` |
| Masonry | `MalletAndChisel.cs:31`, `RunicMalletAndChisel.cs:9`; addon `EnchantedSculptingTool.cs:10` |
| Tailoring | `SewingKit.cs:31`, `RunicSewingKit.cs:33`; addon `SewingMachine.cs:11`. (`Scissors` is **not** a tool — `Scripts/Items/Tools/Scissors.cs:15` is a plain cloth-cutter.) |
| Tinkering | `TinkerTools.cs:33`, `Clippers.cs:155` (basket weaving); addon `TinkerBench.cs:10` |

`BaseTool.CheckTool(tool, from)` (`BaseTool.cs:192-210`) rejects the craft when the mobile has a
*different* `ITool` equipped in `Layer.OneHanded`/`Layer.TwoHanded` → cliloc `1048146`
"If you have a tool equipped, you must use that tool." `AncientSmithyHammer` is exempt (`:201`, `:206`).
`BaseTool.CheckAccessible` uses `RootParent != m` → `1044263` "The tool must be on your person to use."
(`BaseTool.cs:148-157`).

---

### 4.2 Success chance — `GetSuccessChance` (exact)

Real method names: **`CraftItem.GetSuccessChance(Mobile, Type typeRes, CraftSystem, bool gainSkills, ref bool allRequiredSkills[, int maxAmount])`**
(`ServUO:Scripts/Services/Craft/Core/CraftItem.cs:1362` and the 6-arg overload `:1367`).

```
if (ForceSuccessChance > -1)                      // CraftItem.cs:1369-1372
    return ForceSuccessChance / 100.0;            // int percent, per-item override

allRequiredSkills = true
for each CraftSkill in Skills:                    // CraftItem.cs:1380-1404
    minSkill = craftSkill.MinSkill - MinSkillOffset
    maxSkill = craftSkill.MaxSkill
    valSkill = from.Skills[craftSkill.SkillToMake].Value      // .Value, i.e. with skill items
    if (valSkill < minSkill) allRequiredSkills = false
    if (craftSkill.SkillToMake == craftSystem.MainSkill)
        { minMainSkill = minSkill; maxMainSkill = maxSkill; valMainSkill = valSkill }
    if (gainSkills && !UseAllRes) from.CheckSkill(skill, minSkill, maxSkill)   // skill GAIN roll

if (allRequiredSkills)                            // CraftItem.cs:1408-1416
    chance = GetChanceAtMin(item)
           + ((valMainSkill - minMainSkill) / (maxMainSkill - minMainSkill))
             * (1.0 - GetChanceAtMin(item))
else
    chance = 0.0

if (allRequiredSkills && from.Talisman is BaseTalisman t && t.CheckSkill(system))
    chance += t.SuccessBonus / 100.0              // CraftItem.cs:1418-1426
if (WoodworkersBench.HasBonus(from, system.MainSkill))
    chance += 0.5                                 // CraftItem.cs:1428-1431
if (allRequiredSkills && valMainSkill == maxMainSkill)
    chance = 1.0                                  // CraftItem.cs:1433-1436
return chance
```

* **The 0.0–1.0 window.** Every `CraftItem` in every `Def*.cs` declares its own
  `minSkill`/`maxSkill` through `AddCraft(..., minSkill, maxSkill, ...)` (`CraftSystem.cs:329-352`).
  The chance is a plain linear ramp from `GetChanceAtMin(item)` at `minSkill` to `1.0` at `maxSkill`.
  Example literals: `RingmailGloves 12.0/62.0` (`DefBlacksmithy.cs:299`), `PlateChest 75.0/125.0`
  (`DefBlacksmithy.cs:316`), `DragonBardingDeed 72.5/122.5` (`DefBlacksmithy.cs:321`),
  `SackFlour 0.0/100.0` (`DefCooking.cs:126`), `Kindling 0.0/0.0` (`DefBowFletching.cs:133`).
* **`GetChanceAtMin` is per system, abstract** (`CraftSystem.cs:114`). Values in §4.17.
* **Far below the window** (`valSkill < minSkill` for any declared skill, main or secondary):
  `allRequiredSkills = false` → `chance = 0.0`, and `CraftItem.Craft` refuses to even start:
  `if (allRequiredSkills && chance >= 0.0) … else SendGump(new CraftGump(..., 1044153))`
  (`CraftItem.cs:1461`, `1543`) → **1044153 "You don't have the required skills to attempt this item."**
  No materials are touched and no timer starts.
* **Far above the window** (skill > maxSkill, e.g. 120 vs max 100): the `==` guard at `:1433` does
  **not** fire, so the linear formula keeps extrapolating and `chance` exceeds `1.0` (e.g. `1.2`).
  There is **no clamp** on the returned value; the roll below is still `chance > RandomDouble()`, so
  >1.0 means guaranteed success.
* **Degenerate window** (`minSkill == maxSkill`, e.g. `Kindling 0.0/00.0` at `DefBowFletching.cs:133`):
  the denominator of the ramp is `0`. The literal code gives `0.0/0.0 = NaN`, and `NaN > x` is false
  for every `x`, which would make such an item unmakeable; the `==` guard at `:1433`
  (`valMainSkill == maxMainSkill → chance = 1.0`) would rescue it only for a skill of exactly `0.0`.
  This is **`[PARTIAL]`** — the arithmetic is stated from the source, the runtime behaviour was not
  measured. Resolve by logging `GetSuccessChance` for `Kindling` at skill 0 / 50 / 100 on a running
  shard (see §4.19).
* **The roll** — `CraftItem.CheckSkills` (`CraftItem.cs:1343-1360`):

```
chance = GetSuccessChance(from, typeRes, craftSystem, gainSkills, ref allRequiredSkills, maxAmount);
if (GetExceptionalChance(craftSystem, chance, from) > Utility.RandomDouble())
    quality = 2;                                   // exceptional flag, set BEFORE the success roll
return (chance > Utility.RandomDouble());          // the success roll
```
`Utility.RandomDouble()` is `RandomImpl.NextDouble()` → `[0.0, 1.0)` (`Server/Utility.cs:931-934`).
Exceptional is therefore rolled **first** and is derived from the *success* chance, not from a separate
skill window (§4.3).
* **Skill gain** happens inside `GetSuccessChance` only when `gainSkills == true` **and** `!UseAllRes`
  (`CraftItem.cs:1400-1403`). The pre-flight call from `Craft()` passes `gainSkills: false`
  (`CraftItem.cs:1459`); the real one goes through `CompleteCraft` → `CheckSkills(...)`
  (`CraftItem.cs:1658`), which defaults to `gainSkills: true` (`:1346`). For `UseAllRes` items the
  gain check is batched instead: `MultipleSkillCheck(from, maxAmount)` (`:1441-1449`, `:1706-1709`).
* **Failure message ids.** `PlayEndingEffect` is the only source of the end-of-craft cliloc, and it is
  called from exactly two places — success `(from, failed:false, lostMaterial:true, …)`
  (`CraftItem.cs:1941`) and failure `(from, failed:true, lostMaterial:true, …)` (`CraftItem.cs:2054`).
  Because `lostMaterial` is hard-coded `true` at both call sites, the "no materials were lost" branch is
  **dead code** in ServUO.
  | System branch | id | text |
  |---|---|---|
  | fail, `lostMaterial` (all systems) | `1044043` | You failed to create the item, and some of your materials are lost. |
  | fail, `!lostMaterial` (unreachable) | `1044157` | You failed to create the item, but no materials were lost. |
  | Alchemy, failed potion | `500287` (+ a `Bottle()` is added to the pack, `DefAlchemy.cs:88-92`) | You fail to create a useful potion. |
  | `quality == 0` | `502785` | You were barely able to make this item. It's quality is below average. |
  | `quality == 2 && makersMark` | `1044156` | You create an exceptional quality item and affix your maker's mark. |
  | `quality == 2` | `1044155` | You create an exceptional quality item. |
  | otherwise | `1044154` | You create the item. |
  | tool broken (sent in addition) | `1044038` | You have worn out your tool |
  | no resources | `502925` | You don't have the resources required to make that item. |
  | backpack full | `1048147` | Your backpack can't hold anything else. (`CraftItem.cs:896`) |
  | already crafting | `500119` | You must wait to perform another action (`CraftItem.cs:1556`) |

**ModernUO comparison** (`ModernUO:Projects/UOContent/Engines/Craft/Core/CraftItem.cs`):

| Aspect | ServUO | ModernUO |
|---|---|---|
| signature | `ref bool allRequiredSkills`, `maxAmount` overload | `out bool allRequiredSkills`, no `maxAmount` (`CraftItem.cs:860`) |
| `MinSkillOffset` | subtracted from `minSkill` (`:1384`) | absent |
| `ForceSuccessChance` | present (`:1369`) | absent |
| `WoodworkersBench` `+0.5` / `+0.3` | present | absent |
| `valMainSkill == maxMainSkill → 1.0` | present (`:1433`) | absent (`CraftItem.cs:897-911`) |
| `!allRequiredSkills` | returns `0.0` chance and is caught earlier | `return 0;` early (`CraftItem.cs:897-900`) |
| `UseAllRes` skill-gain skip | `if (gainSkills && !UseAllRes)` | `if (gainSkills)` (`CraftItem.cs:891`) |

---

### 4.3 Exceptional chance, quality, maker's mark, exceptional budget

`CraftItem.GetExceptionalChance(CraftSystem system, double chance, Mobile from)`
(`ServUO:Scripts/Services/Craft/Core/CraftItem.cs:1268-1341`):

```
if (ForceNonExceptional) return 0.0;                          // :1270
if (ForceExceptional) {                                       // :1275-1282
    GetSuccessChance(from, null, system, false, ref allRequiredSkills);
    if (allRequiredSkills) return 100.0;                      // (100.0, i.e. always exceptional)
}
bonus = 0.0
if (from.Talisman is BaseTalisman t && t.CheckSkill(system)) bonus  = t.ExceptionalBonus / 100.0   // :1286-1294
if ((from.FindItemOnLayer(Layer.MiddleTorso) as MasterChefsApron) is MasterChefsApron a) bonus += a.Bonus / 100.0  // :1296-1301
if (WoodworkersBench.HasBonus(from, system.MainSkill)) bonus += 0.3                                 // :1303-1306
switch (system.ECA) { … }                                     // :1308-1333
if (chance > 0) return chance + bonus;  else return chance;   // :1335-1340
```

**`CraftECA` — the three modes (`CraftSystem.cs:9-14`, default `ChanceMinusSixty` at `:104-110`):**

| `CraftECA` | Operation applied to the *success* chance | Source |
|---|---|---|
| `ChanceMinusSixty` | `chance -= 0.6` | `CraftItem.cs:1311-1313` |
| `FiftyPercentChanceMinusTenPercent` | `chance = chance * 0.5 - 0.1` | `CraftItem.cs:1314-1316` |
| `ChanceMinusSixtyToFourtyFive` | `offset = 0.60 - ((Skills[MainSkill].Value - 95.0) * 0.03)`, clamped to `[0.45, 0.60]`; `chance -= offset` | `CraftItem.cs:1317-1332` |

Worked arithmetic from the literals above (success chance 0.90 / 1.00 / 1.20 = skill 90 /
skill == maxSkill / skill 20 % above maxSkill, for an item with `GetChanceAtMin == 0`):

| ECA | @0.90 | @1.00 | @1.20 |
|---|---|---|---|
| `ChanceMinusSixty` | 0.30 | 0.40 | 0.60 |
| `FiftyPercentChanceMinusTenPercent` | 0.35 | 0.40 | 0.50 |
| `ChanceMinusSixtyToFourtyFive` (skill ≥100 ⇒ offset 0.45) | 0.30 | 0.55 | 0.75 |

The `ChanceMinusSixtyToFourtyFive` offset is `0.60` for `MainSkill ≤ 95`, drops `0.03` per point above
95, and is floored at `0.45` from skill 100 upward. `MasterChefsApron.Bonus` is a random
`BaseTalisman.GetRandomExceptional()` value (`Scripts/Services/BulkOrders/Items/MasterChefsApron.cs:20-21`).
`WoodworkersBench.HasBonus` is Carpentry-only (`Scripts/Items/StoreBought/WoodworkersBench.cs:89-92`).

**Roll:** `if (GetExceptionalChance(...) > Utility.RandomDouble()) quality = 2;`
(`CraftItem.cs:1354-1357`). `quality` starts at `1` (`CraftItem.cs:2124`), so `quality == 2` is the
only "exceptional" value. The value returned is **not clamped**; the gump clamps for display only.

**Item info panel display** (`CraftGumpItem.DrawSkill`, `CraftGumpItem.cs:171-215`): success chance is
clamped to `[0.0, 1.0]` (`:197-200`) and printed `{0:F1}%` of `chance * 100` (`:203`); the exceptional
line (`1044058`) is only shown when `m_ShowExceptionalChance`, i.e. when `IsMarkable(type)` **or** the
item implements `IQuality` (`CraftGumpItem.cs:160-168`), and is also clamped (`:207-213`).

**Maker's mark gating** (`CraftItem.InternalTimer.OnTick`, `CraftItem.cs:2158-2177`):

```
makersMark = false;
if (quality == 2 && from.Skills[craftSystem.MainSkill].Base >= 100.0)   // BASE skill, not Value
    makersMark = craftItem.IsMarkable(craftItem.ItemType);
if (makersMark && context.MarkOption == CraftMarkOption.PromptForMark && !m_AutoCraft)
    from.SendGump(new QueryMakersMarkGump(quality, from, craftItem, craftSystem, typeRes, tool));
else { if (context.MarkOption == CraftMarkOption.DoNotMark) makersMark = false;
       craftItem.CompleteCraft(quality, makersMark, …); }
```

| Piece | Value / behaviour | Source |
|---|---|---|
| `CraftMarkOption` | `MarkItem`, `DoNotMark`, `PromptForMark` | `CraftContext.cs:8-13` |
| default | `MarkItem` (enum default 0, not assigned in ctor) | `CraftContext.cs:174-189` |
| cycle on gump click | `MarkItem → DoNotMark → PromptForMark → MarkItem` | `CraftGump.cs:710-721` |
| gump label | `1044017 + (int)MarkOption` → `1044017`/`1044018`/`1044019` | `CraftGump.cs:90` |
| `IsMarkable` false early-out | `ForceNonExceptional` → never markable | `CraftItem.cs:463-468` |
| `m_MarkableTable` | `BaseArmor`, `BaseWeapon`, `BaseClothing`, `BaseInstrument`, `BaseTool`, `BaseHarvestTool`, `BaseQuiver`, `DragonBardingDeed`, `Spellbook`, `Runebook`, furniture set (`Stool`…`Throne`), `BaseContainer`/`CraftableFurniture` (ML), ML jewels, `KeyRing`, `BaseBeverage`, `Food`, … | `CraftItem.cs:419-443` |
| mark query gump | 220×170 at (100,200); CONTINUE `1011011` → `501808` "You mark the item."; CANCEL `1011012` → `501809` "Cancelled mark." | `QueryMakersMarkGump.cs:29-50` |
| auto-craft | never prompts (`!m_AutoCraft`) | `CraftItem.cs:2165` |
| ModernUO | `quality == 2 && Base >= 100.0` identical; T2A menus always prompt | `ModernUO:…/Core/CraftItem.cs:1927-1959`; `ModernUO:dev-docs/t2a-crafting.md:84` |

**Exceptional property budget** (what `quality == 2` actually buys on the item):

| Item family | Effect | Source |
|---|---|---|
| `BaseArmor` | `DistributeExceptionalBonuses(from, tool is BaseRunicTool ? 6 : Core.SE ? 15 : 14)` — N points each dropped into a random one of phys/fire/cold/poison/energy bonus; `+ (int)(ArmsLore/div)` extra points when `Core.ML`, `div = Siege ? 12.5 : 20` | `Scripts/Items/Equipment/Armor/BaseArmor.cs:3139`, `:3181-3199` |
| `BaseShield` | overrides `DistributeExceptionalBonuses` to a **no-op** | `Scripts/Items/Equipment/Armor/BaseShield.cs:227-229` |
| `BaseWeapon` | `Attributes.WeaponDamage += 35` (AoS+); `+ (int)(ArmsLore / div)` (ML) | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:6355-6374` |
| any `ForceNonExceptional` item | all of the above is skipped | `BaseArmor.cs:3137`, `BaseWeapon.cs:6348`, `CraftItem.cs:1270` |
| runic tool | `((BaseRunicTool)tool).ApplyAttributesTo(item)` | `BaseArmor.cs:3142-3143` |
| material bonus (ML) | `DistributeMaterialBonus(CraftResources.GetInfo(Resource).AttributeInfo)` | `BaseArmor.cs:3146-3159` |
| `Quality` tag | `Quality = (ItemQuality)quality` in every `OnCraft` | `BaseArmor.cs:3117`, `BaseWeapon.cs:6332`, `BaseTool.cs:306` |
| `Crafter` | `Crafter = from` only when `makersMark` | `BaseArmor.cs:3119-3120`, `BaseWeapon.cs:6334-6337` |

Enhancement refuses to touch an item whose `CraftItem.ForceNonExceptional` is set
(`Enhance.cs:102-104` → `EnhanceResult.BadItem`).

---

### 4.4 Resource consumption — `CraftRes`, `CraftSubRes`, `ConsumeRes`

**Data model**

| Type | Fields | Source |
|---|---|---|
| `CraftRes` | `ItemType`, `Amount`, `NameNumber`, `NameString`, `MessageNumber`, `MessageString`; `SendMessage` falls back to `502925` | `CraftRes.cs:5-79` |
| `CraftResCol` | bare `CollectionBase` with `Add`/`GetAt` | `CraftResCol.cs:5-31` |
| `CraftSubRes` | `ItemType`, `RequiredSkill`, `NameNumber`, `NameString`, `GenericNameNumber`, `Message` | `CraftSubRes.cs:5-70` |
| `CraftSubResCol` | `Init`, `ResType`, `NameString`, `NameNumber`, `Add`, `GetAt`, `SearchFor(Type)` | `CraftSubResCol.cs:5-93` |
| `CraftSkill` | `SkillToMake`, `MinSkill`, `MaxSkill` | `CraftSkill.cs:5-38` |
| `ConsumeType` | `All`, `Half`, `None` | `CraftItem.cs:15-20` |

**`CraftItem.ConsumeRes(Mobile, Type typeRes, CraftSystem, ref int resHue, ref int maxAmount, ConsumeType, ref object message[, bool isFailure])`**
— `ServUO:Scripts/Services/Craft/Core/CraftItem.cs:865` and `:877`.

| Step | Code | Source |
|---|---|---|
| backpack null | `return false` | `:887-892` |
| backpack full/overweight | `message = 1048147` | `:894-898` |
| per-item callback | `ConsumeResCallback(from, consumeType)`; `> 0` ⇒ message + `false` | `:900-909` |
| `NeedHeat` | near `m_HeatSources` else `1044487` | `:911-915`, ids `:313-328` |
| `NeedOven` | near `m_Ovens` else `1044493` | `:917-921`, ids `:330-335` |
| `NeedMaker` | near `m_Makers` (`0x9A96`) else `1155732` | `:923-927`, `:337-340` |
| `NeedMill` | near `m_Mills` else `1044491` | `:929-933`, `:342-346` |
| `NeedWater` | near `m_WaterSources` or a `KoiPond/DragonTurtleFountain/WaterWheel` addon else `1158882` | `:935-939`, `:348-358`, `:587-612` |
| `maxAmount` | initialised `int.MaxValue` | `:944` |
| sub-resource column | `UseSubRes2 ? CraftSubRes2 : CraftSubRes` | `:946` |
| `ForceTypeRes` conversion | `m_ResourceConversionTable[typeRes]` replaces the declared type | `:954-959`, table `:445-458` |
| **sub-resource mutation** | if `baseType == resCol.ResType && typeRes != null` → `baseType = typeRes`; if the chosen sub-resource needs `RequiredSkill > from.Skills[MainSkill].Base` → `message = subResource.Message; return false` | `:962-973` |
| type-group expansion | `ItemTypesTable` lookup by `[j][0]` | `:976-987`, table `:360-383` |
| `UseAllRes` | `maxAmount = min(maxAmount, pack.GetAmount(types[i]) / amounts[i])`; if `0` → res-specific message else `502925`, `return false` | `:992-1021` |
| **failure rule** | `if (isFailure && (talisman != null \|\| !craftSystem.ConsumeOnFailure(from, types[i][0], this, ref talisman))) amounts[i] = 0;` | `:1024-1027` |
| talisman charge | `talisman.Charges--` | `:1030-1033` |
| `UseAllRes` scaling | `amounts[i] *= maxAmount` **unless** `consumeType == ConsumeType.Half`; otherwise `maxAmount = -1` | `:1036-1046` |
| runebook special case | `NameNumber == 1041267` requires one unmarked `RecallRune`, else `1044253`; the rune is deleted on success | `:1050-1071`, `:1176-1180` |
| consume `All` | `ConsumeQuantity` / `ConsumeQuantityByPlantHue` / `pack.ConsumeTotalGrouped(types, amounts, true, ResourceValidator, OnResourceConsumed, CheckHueGrouping)` | `:1076-1097` |
| consume `Half` | each `amounts[i] /= 2`, **minimum 1** | `:1099-1109` |
| consume `None` | read-only availability test (`GetQuantity`, `GetPlantHueAmount`, `GetBestGroupAmount`) | `:1130-1170` |
| failure message | `res.MessageNumber` → `res.MessageString` → `502925` | `:1186-1199` |
| hue capture | `OnResourceConsumed` keeps the hue of the **largest** matching group; `m_ClothHue` kept separately for cloth | `:1217-1250` |
| grouping key | `CheckHueGrouping` compares `Hue` | `:1252-1255` |
| validator | VvV items and faction items cannot be used as resources | `:1257-1266` |
| Caddellite | `CaddelliteCraft` cleared unless the consumed item has the socket and Khaldun is in season | `:1246-1249`, `:1884-1887` |

**Where `ConsumeRes` is called in the pipeline (three times per craft):**

| Call | `consumeType` | `isFailure` | Purpose | Source |
|---|---|---|---|---|
| pre-flight in `Craft()` | `None` | (default false) | "do you have it at all?" before starting the timer | `CraftItem.cs:1484` |
| pre-flight in `CompleteCraft()` | `None` | false | re-check after the timer, before rolling | `:1612` |
| on success | `All` | false | real consumption | `:1667` |
| on failure | `UseAllRes ? Half : All` | **true** | real consumption | `:2009`, `:2016` |

**Does failure consume resources? — YES.** `CraftSystem.ConsumeOnFailure`
(`CraftSystem.cs:290-293`) returns `true` for every type except the `_GlobalNoConsume` blacklist
(`CraftSystem.cs:268-288`): `CapturedEssence`, `EyeOfTheTravesty`, `DiseasedBark`,
`LardOfParoxysmus`, `GrizzledBones`, `DreadHornMane`, `Blight`, `Corruption`, `Muculent`, `Scourge`,
`Putrefaction`, `Taint`, `MidnightBracers`, `CrimsonCincture`, `GargishCrimsonCincture`,
`LeurociansMempoOfFortune`, `LeggingsOfBane`, `GauntletsOfNobility`, `StaffOfTheMagi`,
`BlackrockMoonstone`, `Factions.Silver`, `RingOfTheElements`, `HatOfTheMagi`, `AutomatonActuator`,
`AntiqueDocumentsKit`. Note the quirk: on failure, `amounts[i]` is left **full** (not halved) unless
`UseAllRes`, in which case the `Half` branch halves it (min 1 each).
`MasterCraftsmanTalisman` with `Charges > 0` is consumed instead of the materials
(`CraftSystem.cs:295-314`). **Era conflict:** ModernUO halves every resource on failure when
`!Core.UOTD` (`amounts[i] -= amounts[i] / 2`, `ModernUO:…/Core/CraftItem.cs:685-688`) and does not
halve when `Core.UOTD` — documented at `ModernUO:dev-docs/t2a-crafting.md:77-78`.

**Boards vs logs, ingots vs ore, `ItemTypesTable`** (`CraftItem.cs:360-383`, consumed via `:976-987`):

| Group | Members | Interchangeable? |
|---|---|---|
| plain wood | `Board`, `Log` | **yes** (`:362`) |
| coloured wood | `HeartwoodBoard/Log`, `BloodwoodBoard/Log`, `FrostwoodBoard/Log`, `OakBoard/Log`, `AshBoard/Log`, `YewBoard/Log` | yes, per colour (`:363-368`) |
| leather | `Leather/Hides`, `SpinedLeather/SpinedHides`, `HornedLeather/HornedHides`, `BarbedLeather/BarbedHides` | yes, per tier (`:369-372`) |
| maps/scrolls | `BlankMap`, `BlankScroll` | yes (`:373`) — ModernUO gates this to non-T2A menus (`ModernUO:…/Core/CraftItem.cs:87-91`) |
| cloth | `Cloth`, `UncutCloth`, `AbyssalCloth` | yes (`:374`) |
| food / misc | `CheeseWheel/CheeseWedge`, `Pumpkin/SmallPumpkin`, `WoodenBowlOfPeas/PewterBowlOfPeas`, `Sausage/CookableSausage`, `Lettuce/FarmableLettuce`, `DarkYarn/LightYarn`, crystal & scale families | yes (`:375-382`) |
| **ingots ↔ ore** | — | **NO entry.** Ore is not a crafting input; it must be smelted at a forge first (§4.15). `CraftResources.GetType(resource) == Metal` is the resmelt key (`Resmelt.cs:113`). |

The item info panel resolves the alternate type for *display* purposes through
`CraftGump.GetAltType` (`CraftGump.cs:261-273`) with a duplicate table (`CraftGump.cs:275-288`), so
"Log (120 Available)" counts logs **and** boards.

**Attribute resources** — `CraftItem.ConsumeAttributes(Mobile, ref object message, bool consume)`
(`CraftItem.cs:235-310`), driven by `SetManaReq`/`SetStamReq`/`SetHitsReq` (`CraftSystem.cs:376-392`):

| Requirement | Check | Message |
|---|---|---|
| `Hits > 0 && from.Hits < Hits` | hard fail | `"You lack the required hit points to make that."` (`:243`) |
| `Mana > 0` (Inscription, `ChronicleOfTheGargoyleQueen1` charges) | charge consumed, returns true | — (`:253-263`) |
| `Mana > 0` (`ManaPhasingOrb.IsInManaPhase`) | orb removed from table, returns true | — (`:265-270`) |
| `Mana > 0 && from.Mana < Mana` | hard fail | `"You lack the required mana to make that."` (`:274`) |
| `Stam > 0 && from.Stam < Stam` | hard fail | `"You lack the required stamina to make that."` (`:286`) |

`ConsumeAttributes` is called twice: `consume:false` at `CraftItem.cs:1488` and `:1631`, `consume:true`
at `:1686`.

---

### 4.5 Sub-resource selection (the "which metal/wood/leather" prompt)

The sub-resource column is declared once per system with `SetSubRes(Type, name)`
(`CraftSystem.cs:560-572`) and populated with `AddSubRes(Type, name, reqSkill, genericName, message)`
(`:580-584`). Each `CraftRes` whose `ItemType` equals `CraftSubRes.ResType` is *mutated* at consume
time (`CraftItem.cs:962-973`) and in the info panel (`CraftGumpItem.cs:248-261`).

**Declared sub-resource ladders (all `[SRC]`):**

| System | Base | Ladder `Type @ RequiredSkill` | Source |
|---|---|---|---|
| Blacksmithy | `IronIngot` @0 | DullCopper 65, ShadowIron 70, Copper 75, Bronze 80, Gold 85, Agapite 90, Verite 95, Valorite 99 | `DefBlacksmithy.cs:941-953` |
| Blacksmithy (secondary) | `RedScales` @0 | Yellow/Black/Green/White/Blue scales, all `0.0` | `DefBlacksmithy.cs:955-962` |
| Tinkering | `IronIngot` @0 | identical ingot ladder | `DefTinkering.cs:784-796` |
| Carpentry | `Board` @0 | Oak 65, Ash 75, Yew 85, Heartwood 95, Bloodwood 95, Frostwood 95 | `DefCarpentry.cs:982-992` |
| Tailoring | `Leather` @0 | Spined 65, Horned 80, Barbed 99 | `DefTailoring.cs:830-837` |
| Masonry | `Granite` @0 | identical metal ladder on granite | `DefMasonry.cs:331-341` |
| Alchemy, BowFletching, Cartography, Cooking, Glassblowing, Inscription | — | no `SetSubRes` (single-resource systems) | grep over `Def*.cs` |

**Prompt path.** The gump only draws the resource button when `CraftSubRes.Init` is true
(`CraftGump.cs:162`). Clicking button `GetButtonID(6, 0)` re-sends the gump with
`CraftPage.PickResource` (`CraftGump.cs:649-655`), which renders `CreateResList(false, from)`
(`:290-343`), a 10-per-page list; selecting a row (`case 5`, `:604-623`) checks
`from.Skills[system.MainSkill].Base < res.RequiredSkill` → re-send gump with `res.Message`, else store
`context.LastResourceIndex = index`. `CraftSubRes2` ("for dragon scales") is the mirror image on
`GetButtonID(6, 7)` / `CraftPage.PickResource2` (`:214-248`, `:624-641`, `:727-733`).
`SetUseSubRes2(index, true)` (`CraftSystem.cs:518-522`) picks the second column per item.

**Dragon-scale / SA plant-hue prompt.** `RequiresResTarget` + `CraftItem.NeedsResTarget`
(`CraftItem.cs:2202-2245`) detect mixed plant/pigment hues in the pack and start
`CraftItem.ChooseResTarget` (`:2247-2288`), a target that sets `context.RequiredPlantHue` /
`RequiredPigmentHue` before re-entering `Craft`. Set via `SetRequireResTarget(index)`
(`CraftSystem.cs:454-458`), used at e.g. `DefAlchemy.cs:314`, `:330`, `:344`, `DefCooking.cs:224`, `:228`.
`context.DoNotColor` (toggled by the `*` button, `CraftGump.cs:687-697`) restores the original hue on
the finished item (`CraftItem.cs:1837-1840`).

---

### 4.6 Tool requirement per system — `CanCraft`

ServUO has **no `Tools` array**. The requirement is enforced in each system's
`public override int CanCraft(Mobile from, ITool tool, Type itemType)` (`CraftSystem.cs:630`), and the
tool *class* → system mapping is the `ITool.CraftSystem` property (§4.1).

| System | `CanCraft` gates (in order) | Message ids | Source |
|---|---|---|---|
| Alchemy | null/deleted/`UsesRemaining <= 0`; `CheckAccessible` | `1044038`, `1044263` | `DefAlchemy.cs:57-67` |
| Blacksmithy | tool checks; `AddonToolComponent` in range 2 → OK; else `CheckAnvilAndForge(from, 2, …)` must give anvil **and** forge | `1044038`, `1048146`, `1044263`; `1044267` "You must be near an anvil and a forge to smith items." | `DefBlacksmithy.cs:180-213`; ids `:104-178` |
| BowFletching | tool checks only | `1044038`, `1044263` | `DefBowFletching.cs:69-79` |
| Carpentry | tool checks only | `1044038`, `1044263` | `DefCarpentry.cs:91-101` |
| Cartography | tool checks only | `1044038`, `1044263` | `DefCartography.cs:49-59` |
| Cooking | tool checks only | `1044038`, `1044263` | `DefCooking.cs:80-90` |
| Glassblowing | tool checks; `BaseTool.CheckTool`; `PlayerMobile.Glassblowing && Alchemy.Base >= 100.0`; `CheckAccessible`; then `forge` must be present | `1044038`, `1048146`, `1044634` "You havent learned glassblowing.", `1044263`, `1044628` "You must be near a forge to blow glass." | `DefGlassblowing.cs:50-71` |
| Inscription | tool checks; then for `SpellScroll` subtypes, `Spellbook.Find(from, id)` must contain the spell | `1044038`, `1044263`, `1042404` "You don't have that spell!" | `DefInscription.cs:53-89` |
| Masonry | tool checks; `BaseTool.CheckTool`; `PlayerMobile.Masonry && Carpentry.Base >= 100.0`; `CheckAccessible` | `1044038`, `1048146`, `1044633` "You havent learned stonecraft." | `DefMasonry.cs:59-73` |
| Tailoring | tool checks only | `1044038`, `1044263` | `DefTailoring.cs:117-127` |
| Tinkering | tool checks; faction trap deed requires a faction (`1044573`); `ModifiedClockworkAssembly` requires `PlayerMobile.MechanicalLife` (`1113034`) | `1044038`, `1044263`, `1044573`, `1113034` | `DefTinkering.cs:93-107` |

Item-level gates that run **before** `CanCraft` inside `CraftItem.Craft`
(`CraftItem.cs:1455-1478`): `RequiredExpansion` vs `NetState.SupportsExpansion` (`:1455`),
`Recipe` vs `PlayerMobile.HasRecipe` (`:1463` → `1072847`), `RequiresBasketWeaving` vs
`PlayerMobile.BasketWeaving` (`:1465` → `1112253`), `RequiresMechanicalLife` vs
`PlayerMobile.MechanicalLife` (`:1467` → `1113034`), `RequiresResTarget` (`:1473`).

**Durability decrement per attempt = exactly 1, on success and on failure:**

| Path | Code | Source |
|---|---|---|
| success | `tool.UsesRemaining--;` after the item is created | `CraftItem.cs:1915` |
| success, `HammerOfHephaestus` | clamp to `0`, **never deleted** | `CraftItem.cs:1917-1925` |
| success, other tools | `if (UsesRemaining < 1 && BreakOnDepletion) toolBroken = true; if (toolBroken) tool.Delete();` | `CraftItem.cs:1926-1937` |
| failure | identical block | `CraftItem.cs:2036-2046` |
| off-hand `AncientSmithyHammer` while smithing | decremented in the success path when `hammer != tool`; `HammerOfHephaestus` → `PlaceInBackpack` instead of `Delete` | `CraftItem.cs:1711-1740` |
| enhancement (Blacksmithy) | off-hand `AncientSmithyHammer` `UsesRemaining--`, deleted at `< 1` | `Enhance.cs:128-137` |
| repair | **no** tool durability decrement; repair bench decrements its own `Charges` | `Repair.cs:625-634` |
| resmelt | no tool decrement | `Resmelt.cs:106-186` |

`BaseTool.BreakOnDepletion => true` (`BaseTool.cs:108`) — every system's `UsesRemaining--` therefore
leads to `Delete()` at zero. `ITool` implementors may override it (`SmithHammer.cs:62`).

**ModernUO difference:** `CraftSystem.RequiresTool => true` (`ModernUO:…/Core/CraftSystem.cs:57`)
lets a system opt out; `DefInscription`/`DefCartography` set `RequiresTool => !T2ACraftSystem.Enabled`
(`ModernUO:…/DefInscription.cs:43`, `DefCartography.cs:24`) so those skills are tool-less under T2A
packet menus. ModernUO's `TinkeringMenu.ToolTypes` (`ModernUO:…/T2A/TinkeringMenu.cs:33-41`) is a list
of *craftable* tool items in the "Tools" menu category — it is **not** a tool requirement.

---

### 4.7 Per-craft delay, animation, sound, throttle

**Constructor:** every one of the 11 systems calls `base(1, 1, 1.25)`
(`CraftSystem.cs:245-258`) — `MinCraftEffect = 1`, `MaxCraftEffect = 1`, `Delay = 1.25 s`
(the commented-out legacy values next to each call read e.g. `base( 1, 2, 1.7 )`).

**Timer arithmetic** (`CraftItem.Craft` → `InternalTimer`, `CraftItem.cs:1497-1501`, `:2067-2180`):

```
iMin    = craftSystem.MinCraftEffect                       // 1
iMax    = (craftSystem.MaxCraftEffect - iMin) + 1          // 1
iRandom = Utility.Random(iMax) + iMin + 1                  // 0 + 1 + 1 = 2
new InternalTimer(from, craftSystem, this, typeRes, tool, iRandom).Start();
// base(TimeSpan.Zero, TimeSpan.FromSeconds(craftSystem.Delay), iCountMax)   // :2080
```
`OnTick` plays `PlayCraftEffect` while `m_iCount < m_iCountMax`, then on the final tick calls
`from.EndAction(typeof(CraftSystem))`, re-runs `CanCraft`, rolls `CheckSkills`, resolves the maker's
mark and calls `CompleteCraft` (`CraftItem.cs:2092-2178`). With `(1,1,1.25)` the craft therefore costs
**two ticks ≈ 1.25 s** — one effect, then the result.

**Animations are disabled.** Every `PlayCraftEffect` has its `from.Animate(...)` call commented out;
only sounds remain (`DefBlacksmithy.cs:217-222`, `DefCarpentry.cs:103-109`,
`DefBowFletching.cs:81-87`, `DefGlassblowing.cs:73-79`).

| System | `PlayCraftEffect` sound(s) | `PlayEndingEffect` extra sounds | Source |
|---|---|---|---|
| Alchemy | `0x242` | `0x240` on success; failed potion also yields a `Bottle()` | `DefAlchemy.cs:69-114` |
| Blacksmithy | `0x2A` (dead `InternalTimer` at +0.7 s also `0x2A`) | — | `DefBlacksmithy.cs:215-239` |
| BowFletching | `0x55` | — | `DefBowFletching.cs:81-87` |
| Carpentry | `0x23D` | — | `DefCarpentry.cs:103-109` |
| Cartography | `0x249` | — | `DefCartography.cs:61-64` |
| Cooking | **none** (empty override) | — | `DefCooking.cs:92-94` |
| Glassblowing | `0x2B` (bellows) | `0x41` (glass breaking) on success | `DefGlassblowing.cs:73-106` |
| Inscription | `0x249` | — | `DefInscription.cs:93-96` |
| Masonry | **none** (empty override; dead `InternalTimer` uses `0x23D`) | — | `DefMasonry.cs:75-94` |
| Tailoring | `0x248` | — | `DefTailoring.cs:154` |
| Tinkering | `0x23B` | — | `DefTinkering.cs:147` |

**`NextSkillTime` / `NextCraftTime`.** `NextSkillTime` exists on `Mobile`
(`ServUO:Server/Mobile.cs:797`, `:2151`) but the crafting engine **never reads or writes it**, and
**`NextCraftTime` does not exist anywhere** in ServUO or ModernUO (grep over both trees returns no
member of that name). What actually throttles crafting is the generic per-mobile action lock:

| Mechanism | Code | Source |
|---|---|---|
| re-entrancy lock | `if (from.BeginAction(typeof(CraftSystem))) { … } else from.SendLocalizedMessage(500119);` | `CraftItem.cs:1453`, `:1556` |
| lock release | `from.EndAction(typeof(CraftSystem))` on every early-exit path and on the final timer tick | `CraftItem.cs:1506`, `:1512`, `:1518`, `:1524`, `:1530`, `:1536`, `:1542`, `:1549`, `:2104` |
| lock semantics | a `List<object>` membership test — no duration | `Server/Mobile.cs:1535-1571` |
| disrupt on tick | `m_From.DisruptiveAction()` each effect tick | `CraftItem.cs:2096` |
| auto-craft cadence | `Delay * MaxCraftEffect + 1.0` = **2.25 s** for all systems | `CraftGumpItem.cs:337`, `AutoCraft.cs:42` |

Note `MakeNumberCraftPrompt`/`AutoCraftTimer`'s 3 s default constructor overload
(`AutoCraft.cs:101-104`) is unused by gump code, which always passes the 2.25 s value.

---

### 4.8 Gump structure

**`CraftGump` — category + selection list + options** (`CraftGump.cs`, base position `(40, 40)` `:40`):

| Element | Coordinates / id | Source |
|---|---|---|
| background | `AddBackground(0, 0, 530, 497, 5054)` | `:54` |
| title | `GumpTitleNumber` as localized html, else `GumpTitleString` as plain html | `:63-66` |
| column headers | `1044010` CATEGORIES, `1044011` SELECTIONS, `1044012` NOTICES | `:68-70` |
| EXIT | button id `0` + `1011441` | `:72-73` |
| CANCEL MAKE | `GetButtonID(6, 11)` + `1112698` | `:75-76` |
| REPAIR ITEM | `GetButtonID(6, 5)` + `1044260`, only if `CraftSystem.Repair` | `:79-83` |
| MARK ITEM | `GetButtonID(6, 6)` + `1044017 + (int)context.MarkOption`, only if `MarkOption` | `:87-91` |
| ENHANCE ITEM | `GetButtonID(6, 8)` + `1061001`, only if `CanEnhance` | `:95-99` |
| ALTER ITEM (Gargoyle) | `GetButtonID(6, 9)` + `1094726`, only if `Core.SA && CanAlter` | `:104-108` |
| QUEST ITEM | `GetButtonID(6, 10)` + `1112534`/`1112533`, only if `Core.SA` | `:112-116` |
| MAKE LAST | `GetButtonID(6, 2)` + `1044013` | `:120-121` |
| progress | `1079443` `"{made}\t{total}" COMPLETED`, fed from the live `AutoCraftTimer` or `context.MakeTotal` | `:124-145` |
| SMELT ITEM | `GetButtonID(6, 1)` + `1044259`, only if `Resmelt` | `:149-153` |
| notice line | int → `AddHtmlLocalized`, string → white `<BASEFONT COLOR=#FFFFFF>` | `:156-159` |
| sub-resource button | `GetButtonID(6, 0)` + name/`resourceCount`, `*` prefix when `context.DoNotColor` | `:162-210` |
| sub-resource 2 button | `GetButtonID(6, 7)` | `:214-248` |
| category list | `CreateGroupList()` — `LAST TEN` `1044014` at `(15,60)`, then groups at `(15, 80 + i*20)` | `:446-466` |
| item list | `CreateItemList(group)`, 10 rows per page, page buttons `1044044` PREV / `1044045` NEXT | `:396-444` |
| "last ten" pseudo-group | `selectedGroup == 501` → `CreateMakeLastList()` (max 10 remembered items) | `:398-402`, `:345-394` |
| empty last-ten note | `1044165` "You haven't made anything yet." — flagged in-source as deliberately non-OSI | `:391-392` |

**Button codec:** `GetButtonID(type, index) => 1 + type + (index * 7)` (`CraftGump.cs:468-471`), decoded
as `buttonID = info.ButtonID - 1; type = buttonID % 7; index = buttonID / 7;` (`:511-513`).

| `type` | Meaning | Source |
|---|---|---|
| 0 | show group (`context.LastGroupIndex = index`) | `:533-545` |
| 1 | create item from current group | `:546-562` |
| 2 | item details → `new CraftGumpItem(...)` | `:563-579` |
| 3 | create item from last-ten | `:580-591` |
| 4 | details from last-ten | `:592-603` |
| 5 | sub-resource selected | `:604-644` |
| 6 | misc: 0=resource page, 1=smelt, 2=make last, 3=last ten, 4=toggle colour, 5=repair, 6=cycle mark, 7=resource2, 8=enhance, 9=alter, 10=quest toggle, 11=cancel make | `:645-779` |

When an `AutoCraftTimer` is live the gump reports `Locked == true` (`:21`) and `OnResponse` swallows
**every** button except CANCEL MAKE (`type == 6 && index == 11`) (`:520-528`).

**`CraftGumpItem` — the item info panel** (`CraftGumpItem.cs`, page 0, 530×417 at `(40,40)` `:38`):

| Field | Content | Source |
|---|---|---|
| ITEM art | `DisplayID` else `CraftItem.ItemIDOf(type)`; `ItemBounds.Table[id]` centring; tinted `m_CraftItem.ItemHue` | `:51`, `:152-158` |
| item name | `NameNumber` localized or `NameString` | `:84-87` |
| **Success Chance:** `1044057` | `String.Format("{0:F1}%", chance * 100)`, clamped `[0,1]` | `:202-203`, `:197-200` |
| **Exceptional Chance:** `1044058` | clamped `[0,1]`; only drawn when `m_ShowExceptionalChance` | `:205-213` |
| skill requirements | one row per `CraftSkill`: `AosSkillBonuses.GetLabel(skill)` + `"{0:F1}"` of `minSkill` (negatives clamped to 0) | `:173-183` |
| <CENTER>MATERIALS</CENTER> `1044055` | up to **4** resource rows; each shows name + `Amount`; resource-mutated rows use the chosen sub-resource's `GenericNameNumber` | `:52`, `:236-276` |
| retained colour | `1044152` "* The item retains the color of this material" + `*` marker at `x=500` | `:263-268` |
| <CENTER>OTHER</CENTER> `1044056` | stacked notes, 20 px apart | `:53`, `:89-113` |
| `UseAllRes` note | `1048176` "Makes as many as possible at once" | `:89-90` |
| maker's mark note | `1044059` "This item may hold its maker's mark" | `:160-163` |
| expansion note | `1063363`/`1072651`/`1094732`/`1116296`/`1155876`, red when the client does not support it | `:101-105`, `:116-133` |
| theme-pack note | `1154195`/`1150651`/`1150650` | `:107-110`, `:135-148` |
| recipe note | `1073620` "You have not learned this recipe." in red | `:112-113` |
| scroll note | `1044379` "Inscribing scrolls also requires a blank scroll and mana." | `:284-285` |
| runebook note | `1044447` + amount `1` | `:278-282` |
| MAKE NOW | button `1` (`1044151`) — becomes an inert page-0 button when the recipe is missing, label greyed | `:60-71` |
| MAKE NUMBER | button `2` (`1112623`) | `:74-75` |
| MAKE MAX | button `3` (`1112624`) | `:77-78` |
| BACK | button `0` (`1044150`) | `:81-82` |

**Colour rules.**

| Constant | Value | Where used | Source |
|---|---|---|---|
| `CraftGump.LabelHue` | `0x480` | `AddLabel` for groups, items, resource lines | `CraftGump.cs:17` |
| `CraftGump.LabelColor` | `0x7FFF` | all `AddHtmlLocalized` text | `CraftGump.cs:18` |
| `CraftGump.FontColor` | `0xFFFFFF` | plain-string notices | `CraftGump.cs:19`, `:159` |
| `CraftGumpItem.LabelHue` | `0x480` (comment "0x384") | normal labels | `CraftGumpItem.cs:16` |
| `CraftGumpItem.RedLabelHue` | `0x20` | unsupported expansion text | `CraftGumpItem.cs:17` |
| `CraftGumpItem.LabelColor` | `0x7FFF` | localized labels | `CraftGumpItem.cs:19` |
| `CraftGumpItem.RedLabelColor` | `0x6400` | missing recipe / unsupported expansion | `CraftGumpItem.cs:20`, `:104`, `:113` |
| `CraftGumpItem.GreyLabelColor` | `0x3DEF` | greyed MAKE NOW when the recipe is unknown | `CraftGumpItem.cs:22`, `:65` |
| Mark label | `1044017 + (int)MarkOption` | three-state MARK ITEM label | `CraftGump.cs:90` |
| colour toggle marker | literal `"*"` prefix when `context.DoNotColor` | main resource row | `CraftGump.cs:204`, `:209` |
| colour toggle inside the resource picker | label `1061591` (colour) vs `1061590` (do-not-colour) via `GetButtonID(6, 4)` | resource list header | `CraftGump.cs:312-313` |

**Collection / category construction.** `CraftGroup` holds a name (`TextDefinition`) plus a
`CraftItemCol` (`CraftGroup.cs:5-41`). `CraftSystem.AddCraft` builds a `CraftItem`, adds the primary
resource and the main skill, then `DoGroup` looks the group up by
`CraftGroupCol.SearchFor(TextDefinition)` — matching on `NameNumber != 0 && ==` **or**
`NameString != null && ==` (`CraftGroupCol.cs:32-46`) — and appends to the existing group or creates a
new one (`CraftSystem.cs:344-368`). `CraftItemCol.SearchFor(Type)` is exact-type;
`SearchForSubclass(Type)` also matches subclasses (`CraftItemCol.cs:32-56`) and is what repair and
enhancement use.

---

### 4.9 The full craft pipeline, in order

| # | Step | Code |
|---|---|---|
| 1 | `Gump.OnResponse` → `CraftGump.CraftItem(item)`; `item.TryCraft` short-circuits if set | `CraftGump.cs:473-479` |
| 2 | `CanCraft` gate | `CraftGump.cs:481-486` |
| 3 | resolve `typeRes` from `context.LastResourceIndex[2]` | `CraftGump.cs:491-500` |
| 4 | `CraftSystem.CreateItem` → verifies the type is in `CraftItems`, then `CraftItem.Craft` | `CraftSystem.cs:316-327` |
| 5 | `BeginAction(typeof(CraftSystem))` else `500119` | `CraftItem.cs:1453`, `:1556` |
| 6 | `RequiredExpansion` check | `CraftItem.cs:1455-1457` |
| 7 | `GetSuccessChance(gainSkills:false)`; `allRequiredSkills` gate → `1044153` | `CraftItem.cs:1459-1461`, `:1543` |
| 8 | recipe / basket-weaving / mechanical-life gates | `CraftItem.cs:1463-1532` |
| 9 | `CanCraft` again → `badCraft` gump | `CraftItem.cs:1469-1471`, `:1519` |
| 10 | optional `RequiresResTarget` target selection | `CraftItem.cs:1473-1478` |
| 11 | `ConsumeRes(..., None)` availability test | `CraftItem.cs:1484-1485` |
| 12 | `ConsumeAttributes(..., consume:false)` | `CraftItem.cs:1488` |
| 13 | `context.OnMade(this)` — push onto the last-10 list | `CraftItem.cs:1490-1495` |
| 14 | start `InternalTimer` with `iRandom = 2` | `CraftItem.cs:1497-1501` |
| 15 | **per tick** `from.DisruptiveAction()`, `PlayCraftEffect(from)` | `CraftItem.cs:2096-2101` |
| 16 | **final tick** `EndAction`, `CanCraft`, `CheckSkills` (skill gain + success + exceptional) | `CraftItem.cs:2104-2127` |
| 17 | `CompleteCraft` → `CanCraft`, `ConsumeRes(None)`, `ConsumeAttributes(false)` again | `CraftItem.cs:1590-1649` |
| 18 | `CheckSkills` → success? | `CraftItem.cs:1658` |
| 19 | **success:** `ConsumeRes(All)`, `ConsumeAttributes(true)`, `MultipleSkillCheck` if `UseAllRes`, off-hand smith hammer decrement, create item (`CustomCraft` → `IndecipherableMap` → `CreateItem` delegate → `Activator`), `ICraftable.OnCraft`, hue/resource assignment, `MutateAction`, `AddToBackpack`, `EventSink.InvokeCraftSuccess`, `tool.UsesRemaining--`, `PlayEndingEffect(false, true, …)` | `CraftItem.cs:1667-1992` |
| 20 | **failure:** `ConsumeRes(UseAllRes ? Half : All, …, isFailure:true)`, `tool.UsesRemaining--`, `MultipleSkillCheck(from, 1)` if `UseAllRes`, `PlayEndingEffect(true, true, …)` | `CraftItem.cs:2007-2064` |
| 21 | faction imbue prompt when applicable | `CraftItem.cs:1944-1984` |

---

### 4.10 "Make last" / "Make number" / "Make max" and `AutoCraftTimer`

| Feature | Behaviour | Source |
|---|---|---|
| **Make last** | `context.LastMade` (index 0 of a max-10 list) re-crafted with the remembered resource | `CraftGump.cs:663-676`, `CraftContext.cs:191-210` |
| **Last ten** | `context.LastGroupIndex = 501` → `CreateMakeLastList` | `CraftGump.cs:677-686`, `:398-402` |
| last-10 list upkeep | `OnMade` removes an existing entry, then trims to 9 entries and inserts at 0 → max 10 | `CraftContext.cs:202-210` |
| **Make number** | `MakeNumberCraftPrompt`; accepted range **1..100**, `Utility.ToInt32(text)`; outside → `1112587` "Invalid Entry." and re-show; prompt text `1112576` "Please type the amount you wish to create(1 - 100): <Escape to cancel>"; cancel → `501806` | `CraftGumpItem.cs:331-333`, `AutoCraft.cs:30-49`, `:24-28` |
| **Make max** | `new AutoCraftTimer(..., 9999, 2.25 s, 2.25 s)` | `CraftGumpItem.cs:335-338` |
| `context.MakeTotal` | stored so the progress label survives a gump rebuild | `AutoCraft.cs:44-47`, `CraftContext.cs:153-163` |
| `AutoCraftTimer` tick | closes `CraftGump`/`CraftGumpItem`, `m_Attempts++`, re-invokes `TryCraft` or `CraftSystem.CreateItem`, stops at `m_Ticks >= m_Amount` or when `NetState == null` | `AutoCraft.cs:106-140` |
| maker's mark | auto-crafting suppresses the prompt (`!m_AutoCraft`), so `DoNotMark` still applies | `CraftItem.cs:2165` |
| cancel | `AutoCraftTimer.EndTimer(from)` also called from `CraftItem.Craft` and `CompleteCraft` early-exits | `AutoCraft.cs:142-149`, `CraftItem.cs:1559`, `:1603`, `:1627`, `:1646`, `:1682`, `:1701`, `:2005`, `:2031`, `:2119` |
| ModernUO | **no `AutoCraftTimer` / `MakeNumberCraftPrompt` at all** (grep over `Projects/` returns nothing) — this is a ServUO-only convenience | — |

---

### 4.11 `CustomCraft`, `TryCraft`, `CreateItem` delegates

| Hook | Type | Purpose | Source |
|---|---|---|---|
| `CraftItem.TryCraft` | `Action<Mobile, CraftItem, ITool>` | replaces the *entire* craft flow (resource check + craft) for abnormal cases (cloth combining etc.); checked first in `CraftGump.CraftItem`, `CraftGumpItem` case 1 and `AutoCraftTimer` | `CraftItem.cs:37-42`; `CraftSystem.cs:548-552`; `CraftGump.cs:475-479`; `CraftGumpItem.cs:300-304`; `AutoCraft.cs:132-135` |
| `CraftItem.CreateItem` | `Func<Mobile, CraftItem, ITool, Item>` | builds the item when `Activator` cannot (ctor args) | `CraftItem.cs:44-48`; `CraftSystem.cs:554-558`; used at `CraftItem.cs:1754-1757` |
| `CraftItem.ConsumeResCallback` | `Func<Mobile, ConsumeType, int>` | per-item resource hook returning a message id | `CraftItem.cs:50`; `CraftSystem.cs:506-510`; called at `CraftItem.cs:900-909` |
| `CraftItem.MutateAction` | `Action<Mobile, Item, ITool>` | post-create mutation (one item type → many variants) | `CraftItem.cs:92`, `:1882`; `CraftSystem.cs:483-487` |
| `abstract class CustomCraft` | ctor `(from, craftItem, craftSystem, typeRes, tool, quality)`; `EndCraftAction()`, `CompleteCraft(out int message)` | instantiated reflectively when `typeof(CustomCraft).IsAssignableFrom(craftItem.ItemType)`; the timer then returns **without** the normal `CompleteCraft` | `CustomCraft.cs:6-69`; `CraftItem.cs:2136-2156`; used at `CraftItem.cs:1745-1748` |
| `ICraftable.OnCraft(quality, makersMark, from, craftSystem, typeRes, tool, craftItem, resHue)` | interface | item-side post-processing; returns the final quality | `CraftItem.cs:22-33`; invoked `CraftItem.cs:1818-1821` |
| `CraftItemIDAttribute` | `[CraftItemID(itemID)]` | overrides the gump art when the item cannot be instantiated for `ItemIDOf` | `CraftItemIDAttribute.cs:5-20`; used `CraftItem.cs:200-209` |
| `ItemIDOf` cache | `Dictionary<Type,int>`; hard-coded ids for faction traps and ML deed addons; else attribute; else `Activator` an instance, read `ItemID`, `Delete()` | `CraftItem.cs:139-233` |

---

### 4.12 Recipes (`Recipes.cs`)

| Piece | Detail | Source |
|---|---|---|
| `Recipe` | `ID`, `CraftSystem`, `CraftItem`, lazily built `TextDefinition` from the item name | `Recipes.cs:8-81` |
| registry | `Dictionary<int, Recipe>`; duplicate id throws; `LargestRecipeID` tracked | `Recipes.cs:10-27`, `:36-42` |
| attach | `CraftSystem.AddRecipe(index, id)` → `CraftItem.AddRecipe` (warns and refuses if one is already set) | `CraftSystem.cs:524-528`; `CraftItem.cs:94-104` |
| gating | `CraftItem.Craft` requires `Recipe == null \|\| !(from is PlayerMobile) \|\| HasRecipe(Recipe)` else gump `1072847`; the info panel marks unknown recipes with `1073620` and greys MAKE NOW | `CraftItem.cs:1463`, `:1537`; `CraftGumpItem.cs:60-71`, `:112-113` |
| player side | `PlayerMobile.HasRecipe(Recipe|int)`, `AcquireRecipe`, `ResetRecipes`, `KnownRecipes`, persisted as `Dictionary<int,bool>` | `Scripts/Mobiles/PlayerMobile.cs:6731-6789`, `:5045-5053` |
| GM commands | `[LearnAllRecipes`, `[ForgetAllRecipes` (GameMaster) | `Recipes.cs:82-133` |
| recipe id blocks in use | `CarpRecipes 100..171`, `BowRecipes 200..254`, `SmithRecipes 300..356`, `TinkerRecipes 400..465`, `TailorRecipe 501..1111`, `CookRecipes 500..607`, `MasonryRecipes 701..702`, `InscriptionRecipes 800`, `AlchemyRecipes 900..905`, `CartographyRecipes 1000` | enum headers of each `Def*.cs` |
| **era** | recipes are a Mondain's Legacy (2007) feature; `[ERA]` | enum headers; gating uses `Core.ML` in the `Def*.cs` files |

---

### 4.13 `Enhance.cs` — special-material enhancement

`Enhance.Invoke(from, craftSystem, tool, item, resource, resType, ref resMessage)`
(`ServUO:Scripts/Services/Craft/Core/Enhance.cs:52-313`).

**`EnhanceResult`** (`Enhance.cs:9-22`): `None, NotInBackpack, BadItem, BadResource, AlreadyEnhanced,
Success, Failure, Broken, NoResources, NoSkill, Enchanted`.

| Precondition | Result | Source |
|---|---|---|
| `item == null`; `GargishNecklace`/`GargishEarrings`; not `BaseArmor`/`BaseWeapon`/`FishingPole`/`IResource`; `IArcaneEquip.IsArcane`; `ExtendedWeaponAttributes.AssassinHoned > 0` | `BadItem` | `:54-73`, `:157-158` |
| not `item.IsChildOf(from.Backpack)` | `NotInBackpack` → `1061005` | `:60-61`, `:401-403` |
| weapon under `EnchantSpell` | `Enchanted` → `1080131` | `:75-76`, `:425-427` |
| `CraftResources.IsStandard(resource)` or no `AttributeInfo` | `BadResource` → `1061010` | `:78-79`, `:110-118`, `:410-412` |
| `craftSystem.CanCraft(...) > 0` | `None` with the CanCraft message | `:81-87` |
| no `CraftItem` or no resources | `BadItem` | `:96-99` |
| `craftItem.ForceNonExceptional` | `BadItem` | `:102-104` |
| `craftItem.GetSuccessChance(from, resType, craftSystem, false, ref allRequiredSkills) <= 0.0` | **`NoSkill` → `1044153`** | `:106-108`, `:422-424` |
| `craftItem.ConsumeRes(..., ConsumeType.None, ...)` false | `NoResources` | `:122-123` |
| item already has a non-standard `IResource.Resource` | `AlreadyEnhanced` → `1061012` | `:125-126`, `:404-406` |

**Success/failure model — `baseChance = 20` plus one independent roll per bonus type**
(`Enhance.cs:153-251`, `CheckResult` at `:315-326`):

```
static void CheckResult(ref EnhanceResult res, int chance) {
    if (res != EnhanceResult.Success) return;   // first non-success wins
    int random = Utility.Random(100);           // 0..99
    if (10 > random)      res = EnhanceResult.Failure;   // 10 % flat failure
    else if (chance > random) res = EnhanceResult.Broken; // catastrophic
}
```

| Item family | Base | Rolled checks (`chance` argument) | Source |
|---|---|---|---|
| `BaseWeapon` | 20 | `+fire`, `+cold`, `+energy`, `+poison` (only when the material grants that damage type); `+ (MaxHitPoints/40)`; `+10 + (Luck/2)`; `+ (LowerStatReq/4)`; `+ (WeaponDamage/4)` when `> 0` | `:153-176`, `:226-251` |
| `BaseArmor` | 20 | `+phys`, `+fire`, `+cold`, `+poison`, `+energy` resistances; `+ (MaxHitPoints/40)`; `+10 + (Luck/2)`; `+ (LowerStatReq/4)` | `:177-203` |
| `FishingPole` | 20 | `+10 + (Luck/2)`; `+ (ArmorLowerRequirements/4)` | `:204-215` |

Result order in code: `phys, fire, cold, nrgy, pois, dura, luck, lreq, dinc` — the first check to
produce a non-`Success` result freezes the outcome.
**Skill term:** `int skill = from.Skills[craftSystem.MainSkill].Fixed / 10;` and
`if (skill >= 100) baseChance -= (skill - 90) / 10;` (`Enhance.cs:217-220`) — i.e. GM+ enhancers get a
*smaller* break-chance budget. (`Fixed / 10` == the integer skill value.)
`PlayerMobile.NextEnhanceSuccess` overrides everything to `Success` and is cleared
(`Enhance.cs:253-258`).

**Resource multipliers per outcome** (`Enhance.cs:260-310`):

| Outcome | Consumption | Side effect |
|---|---|---|
| `Broken` | `ConsumeRes(..., ConsumeType.Half, ...)` | `item.Delete()` (→ `1061080`) |
| `Success` | `ConsumeRes(..., ConsumeType.All, ...)` | `((IResource)item).Resource = resource`; `DistributeMaterialBonus(attributes)` for weapon/armor/pole; weapon hue from `GetElementalDamageHue()`; `Caddellite.TryInfuse` if applicable (→ `1061008`) |
| `Failure` | `ConsumeRes(..., ConsumeType.Half, ...)` | none (→ `1061082`) |

`ConsumeType.Half` halves each declared `CraftRes` amount with a **minimum of 1** (`CraftItem.cs:1099-1109`).
Entering the target is `Enhance.BeginTarget` (`:328-374`), which requires a *non-standard* sub-resource
(`lastRes` valid + `from.Skills[MainSkill].Value >= res.RequiredSkill`) else gump `1061010`; the target
range is 2 (`:384`). Blacksmithy additionally burns the off-hand `AncientSmithyHammer` (`:128-137`).
ModernUO's `Enhance` uses the same `baseChance = 20`, the same `CheckResult(10 > random)` and the same
per-bonus divisors (`ModernUO:…/Core/Enhance.cs:135-237`); its `skill` term is
`(int)Skills[MainSkill].Value` rather than `.Fixed / 10` (`Enhance.cs:185-190`).

---

### 4.14 `Repair.cs` — formulas

Entry points: `Repair.Do(from, system, ITool)` range 10 (`Repair.cs:45-50`), `Repair.Do(..., RepairDeed)`
range 2 (`:52-57`), `Repair.Do(..., RepairBenchAddon)` range 2 (`:59-64`). The item must be within
`InRange(..., 2)` regardless (`:209`), and the "cannot repair" filter is `Repair.AllowsRepair`
(`:771-785`).

| Formula | Code | Source |
|---|---|---|
| weaken chance | `(40 + (maxHits - curHits)) - (int)(value / 10)` — note the **source comment says "40% - (1% per hp lost)" but the code adds the lost HP** | `Repair.cs:71-90` |
| weaken roll | `GetWeakenChance(...) > Utility.Random(100)` | `Repair.cs:92-95` |
| repair difficulty | `((maxHits - curHits) * 1250) / Math.Max(maxHits, 1) - 250` (integer math) | `Repair.cs:97-100` |
| skill window | `difficulty = GetRepairDifficulty(...) * 0.1`, then `minSkill = difficulty - 25.0`, `maxSkill = difficulty + 25` | `Repair.cs:104`, `:109-110` |
| roll, deed | `value < minSkill` → false; `value >= maxSkill` → true; else `(value - minSkill)/(maxSkill - minSkill) >= RandomDouble()` | `Repair.cs:106-120` |
| roll, bench addon | identical, `value = addon.Tools.Find(x => x.System == m_CraftSystem).SkillValue` | `Repair.cs:121-135` |
| roll, player | `mob.CheckSkill(skill, difficulty - 25.0, difficulty + 25.0)` with `Skills[Tinkering].Lock` temporarily forced to `Locked` and restored | `Repair.cs:137-146` |
| `value` source | deed `SkillLevel`, else addon `SkillValue`, else `from.Skills[craftSystem.MainSkill].Base` | `Repair.cs:172-192` |
| durability weaken (`toWeaken`) | `Core.AOS` → `1`; else non-Tailoring: `MainSkill >= 90` → `1`, `>= 70` → `2`, else `3`; Tailoring → `0` | `:246-260` (weapon), `:317-331` (armor), `:384-398` (jewel), `:451-465` (clothing), `:518-532` (talisman) |
| weaken application | `if CheckWeaken(...) { MaxHitPoints -= toWeaken; HitPoints = Math.Max(0, HitPoints - toWeaken); }` — applied **before** the repair roll | `:288-292`, `:355-359`, … |
| success | `HitPoints = MaxHitPoints`, `PlayCraftEffect`, `EventSink.InvokeRepairItem`, cliloc `1044279` | `:294-301` |
| failure | cliloc `1044280` (`1061137` when a deed/addon was used, and the deed is then deleted) | `:302-306`, `:639-640` |
| repair deed creation | target a `BlankScroll` with skill `>= 50.0` → consumes 1 blank scroll, creates `RepairDeed.GetTypeFor(system)` with `SkillLevel = from.Skills[skill].Value` (`500442`); below 50 → `1047005` | `:579-596` |
| blocked items | `1044275` not in pack; `1044281` item in full repair; `1044278` `MaxHitPoints <= toWeaken`; `1044277` not craftable by this system / `NegativeAttributes.NoRepair > 0`; `1005012` poison charges pre-AoS | `:266-285` |
| forge/anvil gate | `CanCraft(...) == 1044267` → `1044282` "You must be near a forge and and anvil to repair items." | `:229-232` |
| mobile repair (Tinkering) | `required = KotlAutomaton ? 80.0 : 0.1`; `damage = min(damage, (int)(skillValue * 0.6))`; one `CheckSkill(Tinkering, 0.0, 100.0)`, failure → `damage /= 6`; consumes `(damage + 4) / 5` of `m.RepairResource` (bronze ingots fallback for `Golem`); action delay `10 - (skillValue / 16.65)` s | `:653-768` |
| bench charges | decremented per repair; `0` → `1019073` "This item is out of charges." | `:180-185`, `:625-634` |

ModernUO reproduces `GetWeakenChance`, `CheckWeaken`, `GetRepairDifficulty` and the deed/bench roll
verbatim (`ModernUO:…/Core/Repair.cs:41-76`).

---

### 4.15 `Resmelt.cs` and ore → ingot smelting

**Item → ingot (`CraftGump` → SMELT ITEM → `Resmelt.Do`)** (`Resmelt.cs:20-33`):

| Rule | Value | Source |
|---|---|---|
| target types accepted | `BaseArmor`, `BaseWeapon`, `DragonBardingDeed` | `Resmelt.cs:72-86` |
| imbued items | `Ethics.Ethic.IsImbued(item)` → invalid | `:110-111` |
| resource class | must be `CraftResourceType.Metal` | `:113-114` |
| craft recipe lookup | `CraftItems.SearchFor(item.GetType())`; needs `Resources.Count > 0` | `:121-124` |
| minimum metal | `craftItem.Resources.GetAt(0).Amount < 2` → invalid ("Not enough metal to resmelt") | `:126-129` |
| difficulty per material | DullCopper 65, ShadowIron 70, Copper 75, Bronze 80, Gold 85, Agapite 90, Verite 95, Valorite 99, else `0.0` | `:131-159` |
| skill used | `Math.Max(from.Skills[Mining].Value, from.Skills[Blacksmith].Value)`; `difficulty > skill` → `NoSkill` (`1044269`) | `:161-164` |
| **yield** | player-constructed / dragon-barding: `ingot.Amount = (int)(craftResource.Amount * 0.66)`; otherwise `1` | `:169-172` |
| sounds | `0x2A`, `0x240` | `:177-178` |
| messages | `1044272` can't melt, `1044269` no idea how to work this metal, `500418` (store-bought) / `1044270` success | `:88-100` |

**ModernUO divergence:** skill check uses `from.Skills.Mining.Value` **only** (no Blacksmith fallback,
`ModernUO:…/Core/Resmelt.cs:90-93`) and the yield is `craftResource.Amount / 2` rather than `* 0.66`
(`:102`).

**Ore → ingot (`BaseOre.OnDoubleClick` → target a forge)** (`Scripts/Items/Resource/Ore.cs:168-440`):

| Rule | Value | Source |
|---|---|---|
| target | a forge (`ForgeAttribute`, itemID `4017`, or `6522..6569`); targeting another ore pile instead **combines** piles | `Ore.cs:198-214`, `:227-310` |
| pile sizes | `0x19B7` small (worth ×2), `0x19B8`/`0x19BA` medium (×4), `0x19B9` large (×8); random size distribution `0.12 / 0.18 / 0.25 / else` | `Ore.cs:100-112`, `:250-264` |
| difficulty | iron/default 50.0, DullCopper 65, ShadowIron 70, Copper 75, Bronze 80, Gold 85, Agapite 90, Verite 95, Valorite 99 | `Ore.cs:324-353` |
| skill window | `minSkill = difficulty - 25.0`, `maxSkill = difficulty + 25.0`, rolled with `from.CheckTargetSkill(SkillName.Mining, targeted, minSkill, maxSkill)` | `Ore.cs:355-356`, `:370` |
| hard skill gate | `difficulty > 50.0 && difficulty > Skills[Mining].Value && !SmeltersTalisman` → `501986` "You have no idea how to smelt this strange ore!" | `Ore.cs:358-362` |
| minimum pile | `0x19B7` with `Amount < 2` → `501987` | `Ore.cs:364-368` |
| **yield** | `0x19B7` → `toConsume / 2` (odd amount rounded down and one unit refunded); `0x19B9` → `toConsume * 2`; otherwise `toConsume`; hard cap `toConsume <= 30000` | `Ore.cs:380-402` |
| failure | `Amount < 2` → size drops one step (`0x19B9→0x19B8`, else `→0x19B7`); else `Amount /= 2`; message `501990` "You burn away the impurities but are left with less useable metal." | `Ore.cs:422-437` |
| talisman | `SmeltersTalisman` matching the resource guarantees success, spends one use, message `1152620` | `Ore.cs:317-322`, `:413-417` |
| combine cap | `0x19B9 > 120000`, `0x19B8/0x19BA > 60000`, `0x19B7 > 30000` → `1062844` "There is too much ore to combine." | `Ore.cs:288-292` |

---

### 4.16 `CraftItem` flags — meaning and effect

| Flag / property | Declared | Read at | Meaning |
|---|---|---|---|
| `RequiresMechanicalLife` | `CraftItem.cs:72` (`SetRequiresMechanicalLife`, `CraftSystem.cs:460-464`) | `CraftItem.cs:1467` | player must have read the Mechanical Life Manual (`PlayerMobile.MechanicalLife`); else gump `1113034`. `[ERA]` SA/TOL-era gump-mechanic content. |
| `RequiresBasketWeaving` | `CraftItem.cs:70` (`CraftSystem.cs:448-452`) | `CraftItem.cs:1465` | player must have `PlayerMobile.BasketWeaving`; else `1112253`. Used at `DefAlchemy.cs:345`. `[ERA]` SA. |
| `RequiresResTarget` | `CraftItem.cs:71` (`CraftSystem.cs:454-458`) | `CraftItem.cs:1473` | when the pack holds mixed plant/pigment hues, present a target to choose which hue to consume. `[ERA]` SA. |
| `UseAllRes` | `CraftItem.cs:82` (`SetUseAllRes`, `CraftSystem.cs:394-398`) | `CraftItem.cs:992-1021`, `:1036-1042`, `:1400`, `:1706-1709`, `:2048-2051`; `CraftGumpItem.cs:89-90` | craft as many as the materials allow at once: `maxAmount = min over resources of pack/needed`; item `Amount` (or `UsesRemaining` for non-stackable `IUsesRemaining`) is multiplied by `maxAmount`; skill gain is batched via `MultipleSkillCheck`; failure consumes `Half` instead of `All`. Set on Shaft/Arrow/Bolt/FukiyaDarts (`DefBowFletching.cs:136-150`), potions, cooking (`DefCooking.cs:243`, `:318+`), `DefGlassblowing.cs:111`. |
| `ForceNonExceptional` | `CraftItem.cs:65` (`CraftSystem.cs:530-534`) | `CraftItem.cs:465` (`IsMarkable`), `:1270` (`GetExceptionalChance`), `Enhance.cs:102`; `BaseArmor.cs:3123`, `:3132-3146`; `BaseWeapon.cs:6348`, `:6360`, `:6378` | never exceptional, never markable, never enhanceable, and material/resource bonus application is skipped. |
| `ForceExceptional` | `CraftItem.cs:66` (`CraftSystem.cs:536-540`) | `CraftItem.cs:1275-1282` | always exceptional **provided** `allRequiredSkills`; returns the literal `100.0`. Used for kilt/cowl/belt sets (`DefTailoring.cs:278`, `:285`, `:490-511`). |
| `ForceSuccessChance` | `CraftItem.cs:62`, default `-1` (`SetForceSuccess`, `CraftSystem.cs:489-493`) | `CraftItem.cs:1369-1372` | hard-overrides success chance as an integer percent. Used once: `DefCartography.cs:117` → `SetForceSuccess(index, 75)`. |
| `MinSkillOffset` | `CraftItem.cs:64` (`CraftSystem.cs:542-546`) | `CraftItem.cs:1384` | subtracts from every declared `MinSkill` for both the `allRequiredSkills` test and the ramp denominator. |
| `RequiredExpansion` | `CraftItem.cs:67` (`SetNeededThemePack` neighbour, gating at `CraftItem.cs:1455`) | `CraftItem.cs:1455-1457`, `:1562-1579`; `CraftGumpItem.cs:101-105` | client expansion gate with per-expansion clilocs. |
| `RequiredThemePack` | `CraftItem.cs:68` (`SetNeededThemePack`, `CraftSystem.cs:442-446`) | `CraftGumpItem.cs:107-110` | cosmetic gate; note it is **display-only** (no `Craft()` check). |
| `Recipe` / "RequiresRecipe" | `CraftItem.cs:76` | `CraftItem.cs:1463`; `CraftGumpItem.cs:60` | there is **no `RequiresRecipe` bool** — a non-null `Recipe` object plus `PlayerMobile.HasRecipe` *is* the mechanism (`1072847`). |
| `CanBeMarked` | — | — | does **not** exist. The equivalent is `CraftItem.IsMarkable(Type)` against `m_MarkableTable` (`CraftItem.cs:463-479`) plus the `Base >= 100.0` gate (`:2160`). |
| `RequiresBlacksmith` | — | — | does **not** exist in ServUO or ModernUO (grep over both trees). The closest concept is `DefBlacksmithy.CanCraft`'s anvil+forge requirement (`DefBlacksmithy.cs:204-212`). |
| `RequiresTool` | — | — | does **not** exist in ServUO. ModernUO-only virtual (`ModernUO:…/Core/CraftSystem.cs:57`). |
| `UseSubRes2` | `CraftItem.cs:81` (`CraftSystem.cs:518-522`) | `CraftItem.cs:946`, `CraftGump.cs:495-496`, `CraftGumpItem.cs:185` | selects `CraftSubRes2` (dragon scales) instead of `CraftSubRes`. |
| `ForceTypeRes` | `CraftItem.cs:83` (`CraftSystem.cs:400-404`) | `CraftItem.cs:954-959` | swaps the declared ingredient for `m_ResourceConversionTable[typeRes]`. |
| `NeedHeat` / `NeedOven` / `NeedMaker` / `NeedMill` / `NeedWater` | `CraftItem.cs:85-89` (`CraftSystem.cs:406-440`) | `CraftItem.cs:911-939` | proximity requirements with ids `1044487`, `1044493`, `1155732`, `1044491`, `1158882`. |
| `Mana` / `Hits` / `Stam` | `CraftItem.cs:78-80` (`CraftSystem.cs:376-392`) | `CraftItem.cs:235-310` | see §4.4 attribute table. |
| `RequiredBeverage` | `CraftItem.cs:60`, default `BeverageType.Water` (`:119`) | `CraftItem.cs:747`, `:788`, `:828` | which liquid counts for `IHasQuantity` resources. |
| `Data` / `DisplayID` / `ItemHue` | `CraftItem.cs:74`, `:75`, `:90` (`CraftSystem.cs:466-476`, `:370-374`) | `CraftGumpItem.cs:155-158` | free-form payload, gump art override, forced item hue. |
| `MutateAction` / `TryCraft` / `CreateItem` / `ConsumeResCallback` | `CraftItem.cs:92`, `:42`, `:48`, `:50` | §4.11 | behavioural hooks. |

---

### 4.17 Every craft system in `Scripts/Services/Craft/Def*.cs`

System persistence index = position in `CraftContext.Configure()`
(`CraftContext.cs:279-297`): 0 Alchemy … 10 Tinkering. All systems use `base(1, 1, 1.25)`.

| # | System | `MainSkill` | Gump title cliloc | `ECA` | `GetChanceAtMin` | Primary sub-resource ladder | Secondary skill(s) added via `AddSkill` | Source |
|---|---|---|---|---|---|---|---|---|
| 0 | `DefAlchemy` | `Alchemy` | `1044001` ALCHEMY MENU | `ChanceMinusSixty` (default) | `0.0` | — | `Magery 75.0–100.0` | `DefAlchemy.cs:18-55`, `:349`, `:353` |
| 1 | `DefBlacksmithy` | `Blacksmith` | `1044002` BLACKSMITHY MENU | `ChanceMinusSixtyToFourtyFive` | `0.05` for `1157349`/`1157345` (Gloves of Feudal Grip, Britches of Warding), else `0.0` | Iron→Valorite ingots (65/70/75/80/85/90/95/99) + dragon scales as `SubRes2` | `Tailoring 50.0–55.0` (×2), `Carpentry 65.0–100.0`, `Carpentry 70.0–100.0` | `DefBlacksmithy.cs:65-99`, `:941-962`, `:785`, `:829`, `:871`, `:875` |
| 2 | `DefBowFletching` | `Fletching` | `1044006` BOWCRAFT AND FLETCHING MENU | `FiftyPercentChanceMinusTenPercent` | `0.5` | — | — | `DefBowFletching.cs:28-67`, `:114-120` |
| 3 | `DefCarpentry` | `Carpentry` | `1044004` CARPENTRY MENU | `ChanceMinusSixtyToFourtyFive` | `0.5` | Board→Oak 65/Ash 75/Yew 85/Heartwood 95/Bloodwood 95/Frostwood 95 | `Tailoring 40–105`, `Magery 50–120`, `Tinkering 50–85`, `Blacksmith 75–85`, `Imbuing 75–80`, `Musicianship 45–50` | `DefCarpentry.cs:42-89`, `:982-992`; skills `:160-975` |
| 4 | `DefCartography` | `Cartography` | `1044008` CARTOGRAPHY MENU | `ChanceMinusSixty` (default) | `0.0` | — | — | `DefCartography.cs:12-47` |
| 5 | `DefCooking` | `Cooking` | `1044003` COOKING MENU | `ChanceMinusSixtyToFourtyFive` | `0.5` for `GrapesOfWrath`/`EnchantedApple`, else `0.0` | — | — | `DefCooking.cs:25-78` |
| 6 | `DefGlassblowing` | `Alchemy` | `1044622` Glassblowing MENU | `ChanceMinusSixty` (default) | `0.5` `HollowPrism`, `0.1` `EtherealSoulbinder`, else `0.0` | — | — (requires `PlayerMobile.Glassblowing` + `Alchemy.Base >= 100.0`) | `DefGlassblowing.cs:7-71` |
| 7 | `DefInscription` | `Inscribe` | `1044009` INSCRIPTION MENU | `ChanceMinusSixty` (default) | `0.0` | — | — (spellbook circle gates live in `CanCraft`) | `DefInscription.cs:12-89` |
| 8 | `DefMasonry` | `Carpentry` | `1044500` MASONRY MENU | `ChanceMinusSixty` (default) | `0.0` | Granite ladder (65…99) | `Tailoring 70.0–75.0` | `DefMasonry.cs:13-73`, `:331-341`, `:181-193` |
| 9 | `DefTailoring` | `Tailoring` | `1044005` TAILORING MENU | `ChanceMinusSixtyToFourtyFive` | `0.05` for seven named ML/SA artifacts, else **`0.5`** | Leather→Spined 65/Horned 80/Barbed 99 | — | `DefTailoring.cs:64-127`, `:830-837` |
| 10 | `DefTinkering` | `Tinkering` | `1044007` TINKERING MENU | `ChanceMinusSixtyToFourtyFive` | `0.5` for `1044258` (potion keg) and `1046445` (faction trap removal kit), else `0.0` | Iron→Valorite ingots (65…99) | `Magery 80.0–85.0`, `Magery 80.0–100.0`, `AnimalLore 15.0–100.0` | `DefTinkering.cs:39-107`, `:784-796`, `:603`, `:616`, `:620` |

**Per-system options set at the end of `InitCraftList`:**

| System | `Resmelt` | `Repair` | `MarkOption` | `CanEnhance` | `CanAlter` | `QuestOption` | Source |
|---|---|---|---|---|---|---|---|
| Blacksmithy | `true` | `true` | `true` | `Core.AOS` | `Core.SA` | — (gump shows Quest toggle whenever `Core.SA`) | `DefBlacksmithy.cs:964-968` |
| Tinkering | — | `true` | `true` | `Core.AOS` | `Core.SA` | — | `DefTinkering.cs:798-801` |
| Tailoring | — | `Core.AOS` | `true` | `Core.ML` | `Core.SA` | — | `DefTailoring.cs:839-842` |
| Carpentry | — | `Core.AOS` | `true` | `Core.ML` | — | — | `DefCarpentry.cs:978-980` |
| BowFletching | — | `Core.AOS` | `true` | `Core.ML` | — | — | `DefBowFletching.cs:258-260` |
| Masonry | — | `Core.SA` | `Core.SA` | `Core.SA` | — | — | `DefMasonry.cs:327-329` |
| Glassblowing | — | `Core.SA` | `Core.SA` | — | — | — | `DefGlassblowing.cs:158-159` |
| Inscription | — | — | `true` | — | — | — | `DefInscription.cs:466` |
| Alchemy | — | — | — | — | — | — (only `Resmelt/Repair/Mark/Enhance` absent; `QuestOption` gump button is `Core.SA`-gated globally) | `DefAlchemy.cs` (no such assignments) |
| Cartography | — | — | — | — | — | — | `DefCartography.cs` |
| Cooking | — | — | — | — | — | — | `DefCooking.cs` |

Only Blacksmithy sets `Resmelt = true`; only Blacksmithy/Tinkering/Masonry/Tailoring/Carpentry/
BowFletching/Inscription/Glassblowing set `Repair` and/or `MarkOption`.

**`[ERA]` notes on the 11 systems:**

| System | Era |
|---|---|
| Alchemy, Blacksmithy, BowFletching, Carpentry, Cartography, Cooking, Inscription, Tailoring, Tinkering | classic (launch 1997) — the nine original craft skills |
| Glassblowing | expansion content riding on `Alchemy`; `CanCraft` requires the `PlayerMobile.Glassblowing` flag and `Alchemy.Base >= 100.0` (`DefGlassblowing.cs:58-59`), and `Repair`/`MarkOption` are `Core.SA`-gated (`:158-159`) → **`[ERA]` SA (Stygian Abyss, 2009)** |
| Masonry | `CanCraft` requires the `PlayerMobile.Masonry` flag + `Carpentry.Base >= 100.0` (`DefMasonry.cs:67-68`); `Repair`/`MarkOption`/`CanEnhance` are `Core.SA`-gated (`:327-329`) → **`[ERA]` SA (2009)** |
| `SetSubRes2` dragon scales (Blacksmithy) | `[ERA]` AoS-era scale armour |
| recipes (`AddRecipe`) | `[ERA]` Mondain's Legacy (2007) |
| `ForceNonExceptional`, `CanAlter`, Alter Item gump button | `[ERA]` ML / SA respectively (`CraftGump.cs:104-108`) |

---

### 4.18 Client-side / era notes

| Item | Observation | Source |
|---|---|---|
| gump ids | `5054` background, `2624` tiled alpha, `4005/4007` radio, `4017/4019` and `4014/4016` nav, `4011/4012` info — the same art the ClassicUO client renders for `0xB0`/`0xDD` gumps | `CraftGump.cs:54-73`, `CraftGumpItem.cs:38-82` |
| T2A packet menus | pre-Publish-14 (before 2001-11-30) crafting used the `0x7C`/`0x7D` item-list menu, not a gump; ModernUO reconstructs it behind `T2ACraftSystem.Enabled` (`t2aCraftMenus` setting, default `!Core.UOTD`) | `ModernUO:dev-docs/t2a-crafting.md:5-17` |
| "Make Last" | a **Publish 14 gump** feature, *not* part of T2A packet menus; ModernUO keeps it as QoL only | `ModernUO:dev-docs/t2a-crafting.md:62` |
| "Make Number" / "Make Max" | SA-era gump buttons (`1112623`, `1112624`), gated in ServUO only by the `Core.SA` gump-region comment — the buttons themselves are drawn unconditionally | `CraftGumpItem.cs:73-79` |
| pre-AoS weapon colour | `BaseWeapon.OnCraft` only applies `Resource` colour under `Core.AOS`; `BaseArmor`/`BaseClothing` apply it in every era | `BaseWeapon.cs:6346-6351`; `ModernUO:dev-docs/t2a-crafting.md:70-72` |
| repair of items | `toWeaken = 1` under `Core.AOS`, otherwise 1/2/3 by skill — a real pre-AoS vs AoS divergence | `Repair.cs:246-260` |

---

### 4.19 Confidence and UNVERIFIED gaps

| Claim | Marker | What is missing / how to resolve |
|---|---|---|
| All formulas in §4.2, §4.3, §4.4, §4.13, §4.14, §4.15 | `[SRC]` | read directly from the files cited |
| Which `Def*.cs` literals exist (min/max windows, sub-resource skills, options) | `[SRC]` | exhaustive grep + reads; no sampling |
| ServUO vs ModernUO divergences | `[SRC]` | both trees read; divergences listed inline as required by the brief |
| T2A packet-menu history ("Publish 14 on 2001-11-30", `0x7C`/`0x7D`) | `[PARTIAL]` | taken from `ModernUO:dev-docs/t2a-crafting.md:7-9`, which is repo documentation, **not** an OSI patch note. Needs confirmation against official patch notes before it is asserted as history. |
| `Kindling 0.0/0.0` window arithmetic | `[PARTIAL]` | The declared window is `AddCraft(typeof(Kindling), …, 0.0, 00.0, …)` (`DefBowFletching.cs:133`), so `(maxSkill - minSkill) == 0` and the ramp divides by zero. ServUO's exact runtime behaviour (`NaN` propagation vs. the `valMainSkill == maxMainSkill` rescue at `CraftItem.cs:1433`) was **not** measured. Measure on a live shard: craft kindling at skill 0/50/100 and log `GetSuccessChance`. |
| Whether `lostMaterial == false` is reachable | `[SRC]` negative | Only two call sites exist and both pass `true` (`CraftItem.cs:1941`, `:2054`); the `1044157` branch is dead in this checkout. A custom `CustomCraft`/`TryCraft` could still call it. |
| Absolute wall-clock cost of one craft | `[PARTIAL]` | Derived: 2 ticks × 1.25 s. Not measured against a live client; the client also applies its own animation delay which ServUO no longer sends (`Animate` calls are commented out in every `PlayCraftEffect`). Measure by logging `Mobile.NextActionTime` deltas over N crafts. |
| `RequiresBlacksmith`, `CanBeMarked`, `RequiresRecipe`, `Tools` array, `NextCraftTime` | `[SRC]` negative | Grep over `servuo`, `modernuo` returns no such members. They appear to be names from an older RunUO/other-emulator lineage; do not implement them as flags. |
| Exceptional chance values in §4.3 worked table | `[SRC]`-derived | Arithmetic from the quoted literals; no invented constants. |
| BOD / bulk-order interactions with `quality` | not covered here | Out of scope for this section; `SmallSmithBOD.cs:137` etc. consume `CraftSystem` but are a separate subsystem. |

## 4b. Crafting menus — Blacksmithy & Tailoring

Complete transcription of the two crafting systems from **ServUO `pub57`**.
Every `AddCraft(...)` call in both definition files appears as exactly one row below.

| Fact | Value | Evidence |
|---|---|---|
| Primary file (blacksmithy) | `Scripts/Services/Craft/DefBlacksmithy.cs` (977 lines) | [ServUO DefBlacksmithy.cs](https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefBlacksmithy.cs) |
| Primary file (tailoring) | `Scripts/Services/Craft/DefTailoring.cs` (1014 lines) | [ServUO DefTailoring.cs](https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefTailoring.cs) |
| `AddCraft` calls, blacksmithy | **196** | `DefBlacksmithy.cs` L299–L929 `[SRC]` |
| `AddCraft` calls, tailoring | **198** | `DefTailoring.cs` L188–L820 `[SRC]` |
| Total rows in this section | **394** | `[SRC]` |
| Groups (blacksmithy) | 10 distinct group `TextDefinition` values | `[SRC]` |
| Groups (tailoring) | 10 distinct group `TextDefinition` values | `[SRC]` |

Confidence markers used: `[SRC]` read from source, `[WEB]` prose source, `[SRC+WEB]` both,
`[PARTIAL]` partially evidenced, `[UNVERIFIED]` not evidenced (never a guessed number),
`[ERA]` expansion-era note.

---

### 4b.0 How the columns map to the C# arguments

Base overloads, read directly (`Scripts/Services/Craft/Core/CraftSystem.cs`):

```
L329: AddCraft(Type typeItem, TextDefinition group, TextDefinition name, double minSkill, double maxSkill, Type typeRes, TextDefinition nameRes, int amount)
L334: AddCraft(..., TextDefinition message)                                    // same + missing-resource message
L339: AddCraft(..., SkillName skillToMake, double minSkill, double maxSkill, Type typeRes, TextDefinition nameRes, int amount)
L344: AddCraft(..., SkillName skillToMake, ..., TextDefinition message)         // the only real implementation
```

`L344-352` is the only body: it constructs `new CraftItem(typeItem, group, name)`, then
`craftItem.AddRes(typeRes, nameRes, amount, message)` (`CraftItem.cs:122-131`), then
`craftItem.AddSkill(skillToMake, minSkill, maxSkill)` (`CraftItem.cs:133-137`), then `DoGroup(group, craftItem)`.

| Column | Meaning | Source of the meaning |
|---|---|---|
| **Category** | Sub-block inside the group, taken from the `#region` marker in the file (the group itself is a separate cliloc) | `DefBlacksmithy.cs` L296-368, `DefTailoring.cs` L186-219 etc. `[SRC]` |
| **Item** | display-name cliloc (2nd/3rd arg) + the C# `Type` it will `Activator.CreateInstance` | `CraftItem.cs:52`, `CraftItem.ItemIDOf` `CraftItem.cs:141-233` `[SRC]` |
| **Min / Max** | literal `minSkill` / `maxSkill`, copied verbatim (note negative min values) | overload args `[SRC]` |
| **Resources** | base `typeRes × amount` plus one line per extra `AddRes(index, …)` | `CraftSystem.cs:495-504` `[SRC]` |
| **Sub-res** | `ING` = item uses the primary sub-resource selector (`SetSubRes` + `AddSubRes`); `SCL` = item sets `UseSubRes2` and uses the scale selector; `LTH` = tailoring leather selector; `—` = none | `CraftItem.cs:81,946-973`; `CraftSystem.cs:560-597` `[SRC]` |
| **Flags** | `recipe:N` = `AddRecipe(index, N)`; `non-exc` = `ForceNonExceptional(index)`; `force-exc` = `ForceExceptional(index)`; `useAllRes` = `SetUseAllRes(index,true)`; `hue:H` = `SetItemHue(index,H)`; `+SKILL a..b` = extra `AddSkill(index,…)` | `CraftSystem.cs:370-552` `[SRC]` |
| **Line** | line of that `AddCraft(...)` in the pub57 file | `[SRC]` |

Supporting classes read for the column meanings: `CraftItem.cs`, `CraftGroup.cs:5-42`
(group = `TextDefinition` + an ordered `CraftItemCol`), `CraftRes.cs:5-70` (Type, Amount,
NameNumber/String, MessageNumber/String), `CraftSubRes.cs:5-70` (Type, RequiredSkill,
Message), `CraftSkill.cs:5-38` (`SkillToMake`, `MinSkill`, `MaxSkill`).

**Per-group cliloc legend.** Within one group the base `(typeRes cliloc, message cliloc)`
pair is constant; only `amount` changes. Extra `AddRes` clilocs are written inline in the
Resources column. `×` = the literal `amount` integer from source.

---

### 4b.1 System header table

| Field | DefBlacksmithy | DefTailoring | Source |
|---|---|---|---|
| System index in `CraftContext._Systems[]` | `[1]` | `[9]` | `CraftContext.cs:284, 292` `[SRC]` |
| Class | `DefBlacksmithy : CraftSystem` | `DefTailoring : CraftSystem` | `DefBlacksmithy.cs:65`; `DefTailoring.cs:64` `[SRC]` |
| Singleton accessor | `DefBlacksmithy.CraftSystem` (lazy `m_CraftSystem ?? (…)`) | `DefTailoring.CraftSystem` (lazy `if (m_CraftSystem == null)`) | `DefBlacksmithy.cs:74-76`; `DefTailoring.cs:82-93` `[SRC]` |
| `MainSkill` | `SkillName.Blacksmith` | `SkillName.Tailoring` | `DefBlacksmithy.cs:67`; `DefTailoring.cs:66-72` `[SRC]` |
| `GumpTitleNumber` | `1044002` — source comment: `<CENTER>BLACKSMITHY MENU</CENTER>` | `1044005` — source comment: `<CENTER>TAILORING MENU</CENTER>` | `DefBlacksmithy.cs:69-72`; `DefTailoring.cs:74-80` `[SRC]` |
| Secondary skills present in the menu | **Yes, 3 distinct extra `CraftSkill` entries** (see 4b.1.1) | **None** — no `AddSkill` call exists anywhere in the file | `grep AddSkill(index` on both files `[SRC]` |
| `AddSkill` count | 4 calls (L785, L829, L871, L875) | 0 | `[SRC]` |
| `CraftECA ECA` | `CraftECA.ChanceMinusSixtyToFourtyFive` | `CraftECA.ChanceMinusSixtyToFourtyFive` (same) | `DefBlacksmithy.cs:78`; `DefTailoring.cs:95-101` `[SRC]` |
| `GetChanceAtMin(item)` | `0.0` — **except** `NameNumber == 1157349` (GlovesOfFeudalGrip) or `1157345` (BritchesOfWarding) → `0.05` | `0.5` — **except** `NameNumber ∈ {1157348, 1159225, 1159213, 1159212, 1159211, 1159228, 1159229}` → `0.05` | `DefBlacksmithy.cs:80-86`; `DefTailoring.cs:103-110` `[SRC]` |
| Ctor `base(minCraftEffect, maxCraftEffect, delay)` | `base(1, 1, 1.25)` (comment: `// base( 1, 2, 1.7 )`) | `base(1, 1, 1.25)` (comment: `// base( 1, 1, 4.5 )`) | `DefBlacksmithy.cs:88-99`; `DefTailoring.cs:112-115` `[SRC]` |
| Required tool (interface `ITool` returning this system) | `Tongs` (`Tongs.cs:32`), `SmithHammer` (`SmithHammer.cs:32`), `SledgeHammer` (`SledgeHammer.cs:32`), `RunicHammer` (`RunicHammer.cs:36`), `AncientSmithyHammer` (`AncientSmithyHammer.cs:66`), addon `SmithingPress` (`SmithingPress.cs:11`) | `SewingKit` (`SewingKit.cs:31`), `RunicSewingKit` (`RunicSewingKit.cs:33`), addon `SewingMachine` (`SewingMachine.cs:11`) | `[SRC]` |
| Extra environmental requirement | **Anvil + forge within range 2** (`CheckAnvilAndForge(from, 2, …)`), else `1044267` "You must be near an anvil and a forge to smith items."; addon tools bypass when `InRange(...,2)` | none beyond the tool | `DefBlacksmithy.cs:104-213` `[SRC]` |
| Tool checks | worn out → `1044038`; equipped different tool → `1048146`; not accessible → tool's own `num` | worn out → `1044038`; not accessible → `num` | `DefBlacksmithy.cs:180-213`; `DefTailoring.cs:117-127` `[SRC]` |
| Craft sound | `0x2A` (`PlayCraftEffect`), plus a 0.7 s `InternalTimer` that replays `0x2A` | `0x248` | `DefBlacksmithy.cs:215-239`; `DefTailoring.cs:152-155` `[SRC]` |
| `Resmelt` / `Repair` / `MarkOption` / `CanEnhance` / `CanAlter` (end of `InitCraftList`) | `true` / `true` / `true` / `Core.AOS` / `Core.SA` | *(Resmelt not set → default `false`)* / `Core.AOS` / `true` / `Core.ML` / `Core.SA` | `DefBlacksmithy.cs:964-968`; `DefTailoring.cs:839-842` `[SRC]` |

#### 4b.1.1 The secondary-skill (`CraftSkill`) list, in file order

| System | Item that carries it | `SkillToMake` | `MinSkill` | `MaxSkill` | Line |
|---|---|---|---|---|---|
| Blacksmithy | `Tessen` (`1030222`) | `Tailoring` | `50.0` | `55.0` | `DefBlacksmithy.cs:785` |
| Blacksmithy | `GargishTessen` (`1097508`) | `Tailoring` | `50.0` | `55.0` | `DefBlacksmithy.cs:829` |
| Blacksmithy | `LightShipCannonDeed` (`1095790`) | `Carpentry` | `65.0` | `100.0` | `DefBlacksmithy.cs:871` |
| Blacksmithy | `HeavyShipCannonDeed` (`1095794`) | `Carpentry` | `70.0` | `100.0` | `DefBlacksmithy.cs:875` |
| Tailoring | — none — | — | — | — | — |

#### 4b.1.2 Requirement scale and skill-check maths (both systems)

| Rule | Literal | Source |
|---|---|---|
| Effective min skill | `minSkill = craftSkill.MinSkill - MinSkillOffset` (`MinSkillOffset` default `0`, never set in either file) | `CraftItem.cs:1384`; `CraftItem.cs:64` `[SRC]` |
| `allRequiredSkills` | set `false` if **any** `CraftSkill`'s `from.Skills[skill].Value < minSkill`; then `chance = 0.0` and the craft is refused with cliloc `1044153` | `CraftItem.cs:1388-1416`; `CraftItem.cs:1543` `[SRC]` |
| Success chance across the min→max band | `chance = GetChanceAtMin(item) + ((valMainSkill - minMainSkill) / (maxMainSkill - minMainSkill) * (1.0 - GetChanceAtMin(item)))` | `CraftItem.cs:1410-1411` `[SRC]` |
| At/above max | `if (allRequiredSkills && valMainSkill == maxMainSkill) chance = 1.0;` | `CraftItem.cs:1433-1436` `[SRC]` |
| Skill gain while crafting | passive: `from.CheckSkill(craftSkill.SkillToMake, minSkill, maxSkill)` for **every** skill in `Skills`, but only `if (gainSkills && !UseAllRes)` — i.e. no passive gain on `SetUseAllRes` recipes | `CraftItem.cs:1400-1403` `[SRC]` |
| Exceptional roll | `if (GetExceptionalChance(craftSystem, chance, from) > Utility.RandomDouble()) quality = 2;` | `CraftItem.cs:1354-1357` `[SRC]` |
| Exceptional chance, ECA = `ChanceMinusSixtyToFourtyFive` | `offset = 0.60 - ((from.Skills[MainSkill].Value - 95.0) * 0.03)`, clamped to `[0.45, 0.60]`; `chance -= offset` | `CraftItem.cs:1317-1332` `[SRC]` |
| Other ECA modes (not used by these two systems) | `ChanceMinusSixty`: `chance -= 0.6`; `FiftyPercentChanceMinusTenPercent`: `chance = chance*0.5 - 0.1` | `CraftItem.cs:1311-1316` `[SRC]` |
| `ForceSuccessChance` override | if `> -1` then `return ForceSuccessChance / 100.0`; never set in either file | `CraftItem.cs:1369-1372` `[SRC]` |
| Expansion / recipe gates evaluated before crafting | `Recipe == null \|\| ((PlayerMobile)from).HasRecipe(Recipe)` else message `1072847` "You must learn that recipe from a scroll."; `RequiredExpansion` gate sends the expansion message | `CraftItem.cs:1455-1464,1562-1579` `[SRC]` |
| Sub-resource skill gate | when a coloured sub-resource is chosen: `if (from.Skills[MainSkill].Base < subResource.RequiredSkill) → subResource.Message` (**uses `.Base`, not `.Value`**) | `CraftItem.cs:966-972` `[SRC]` |

---

### 4b.2 DefBlacksmithy — group index

Group display name below is the `#region` label in the source; the gump itself renders the
cliloc (the English text is client data, not server source → `[PARTIAL]` on the label only).

| # | Group cliloc | Region label in source | `AddCraft` rows | First line | Last line |
|---|---|---|---|---|---|
| 1 | `1111704` | Metal Armor (Ringmail / Chainmail / Platemail / SE / SA) | 29 | L299 | L359 |
| 2 | `1011079` | Helmets | 16 | L371 | L401 |
| 3 | `1011080` | Shields | 14 | L410 | L435 |
| 4 | `1011081` | Bladed | 68 | L443 | L663 |
| 5 | `1011082` | Axes | 15 | L670 | L706 |
| 6 | `1011083` | Pole Arms | 16 | L714 | L762 |
| 7 | `1011084` | Bashing | 17 | L770 | L832 |
| 8 | `1116354` | High Seas Cannons | 8 | L845 | L873 |
| 9 | `1079508` | Throwing | 3 | L884 | L888 |
| 10 | `1011173` | Miscellaneous | 10 | L895 | L929 |
| | | **total** | **196** | | |

> **Runtime row count ≠ 196.** Two blocks are mutually exclusive at runtime:
> `if (Core.HS) { if (Core.EJ) {Cannonball} else {LightCannonball, HeavyCannonball} }` and the
> same shape for Grapeshot. With `Core.EJ` true → **192** rows; with `Core.HS` but not `Core.EJ` → **194** rows.
> `[SRC]` `DefBlacksmithy.cs:841-867`

#### 4b.2.1 Group `1111704` — Metal Armor — **29 rows** (L299–L359)

Cliloc legend: base `IronIngot` = `typeRes cliloc 1044036`, message cliloc `1044037` on every row of this group.

| # | Category | Item (type + name cliloc) | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | Ringmail (`#region` L298) | `RingmailGloves` `1025099` | 12.0 | 62.0 | `IronIngot` ×10 | ING | — | 299 |
| 2 | Ringmail | `RingmailLegs` `1025104` | 19.4 | 69.4 | `IronIngot` ×16 | ING | — | 300 |
| 3 | Ringmail | `RingmailArms` `1025103` | 16.9 | 66.9 | `IronIngot` ×14 | ING | — | 301 |
| 4 | Ringmail | `RingmailChest` `1025100` | 21.9 | 71.9 | `IronIngot` ×18 | ING | — | 302 |
| 5 | Chainmail (`#region` L305) | `ChainCoif` `1025051` | 14.5 | 64.5 | `IronIngot` ×10 | ING | — | 306 |
| 6 | Chainmail | `ChainLegs` `1025054` | 36.7 | 86.7 | `IronIngot` ×18 | ING | — | 307 |
| 7 | Chainmail | `ChainChest` `1025055` | 39.1 | 89.1 | `IronIngot` ×20 | ING | — | 308 |
| 8 | Platemail (`#region` L311) | `PlateArms` `1025136` | 66.3 | 116.3 | `IronIngot` ×18 | ING | — | 312 |
| 9 | Platemail | `PlateGloves` `1025140` | 58.9 | 108.9 | `IronIngot` ×12 | ING | — | 313 |
| 10 | Platemail | `PlateGorget` `1025139` | 56.4 | 106.4 | `IronIngot` ×10 | ING | — | 314 |
| 11 | Platemail | `PlateLegs` `1025137` | 68.8 | 118.8 | `IronIngot` ×20 | ING | — | 315 |
| 12 | Platemail | `PlateChest` `1046431` | 75.0 | 125.0 | `IronIngot` ×25 | ING | — | 316 |
| 13 | Platemail | `FemalePlateChest` `1046430` | 44.1 | 94.1 | `IronIngot` ×20 | ING | — | 317 |
| 14 | `if (Core.AOS)` L319 | `DragonBardingDeed` `1053012` | 72.5 | 122.5 | `IronIngot` ×750 | ING | — | 321 |
| 15 | `if (Core.SE)` L324 | `PlateMempo` `1030180` | 80.0 | 130.0 | `IronIngot` ×18 | ING | — | 326 |
| 16 | SE | `PlateDo` `1030184` | 80.0 | 130.0 | `IronIngot` ×28 | ING | — | 328 |
| 17 | SE | `PlateHiroSode` `1030187` | 80.0 | 130.0 | `IronIngot` ×16 | ING | — | 331 |
| 18 | SE | `PlateSuneate` `1030195` | 65.0 | 115.0 | `IronIngot` ×20 | ING | — | 333 |
| 19 | SE | `PlateHaidate` `1030200` | 65.0 | 115.0 | `IronIngot` ×20 | ING | — | 335 |
| 20 | `if (Core.SA)` L338 | `FemaleGargishPlateArms` `1095336` | 66.3 | 116.3 | `IronIngot` ×18 | ING | — | 341 |
| 21 | SA | `FemaleGargishPlateChest` `1095338` | 75.0 | 125.0 | `IronIngot` ×25 | ING | — | 343 |
| 22 | SA | `FemaleGargishPlateLegs` `1095342` | 68.8 | 118.8 | `IronIngot` ×20 | ING | — | 345 |
| 23 | SA | `FemaleGargishPlateKilt` `1095340` | 58.9 | 108.9 | `IronIngot` ×12 | ING | — | 347 |
| 24 | SA | `GargishPlateArms` `1095336` | 66.3 | 116.3 | `IronIngot` ×18 | ING | — | 349 |
| 25 | SA | `GargishPlateChest` `1095338` | 75.0 | 125.0 | `IronIngot` ×25 | ING | — | 351 |
| 26 | SA | `GargishPlateLegs` `1095342` | 68.8 | 118.8 | `IronIngot` ×20 | ING | — | 353 |
| 27 | SA | `GargishPlateKilt` `1095340` | 58.9 | 108.9 | `IronIngot` ×12 | ING | — | 355 |
| 28 | SA | `GargishAmulet` `1098595` | 60.0 | 110.0 | `IronIngot` ×3 | ING | — | 357 |
| 29 | SA | `BritchesOfWarding` `1157345` | 120.0 | 120.1 | `IronIngot` ×18 `[1044036]` + `LeggingsOfBane` ×1 `[1061100/1053098]` + `Turquoise` ×4 `[1032691/1053098]` + `BloodOfTheDarkFather` ×5 `[1157343/1053098]` | ING | `recipe:355` (`SmithRecipes.BritchesOfWarding`), `non-exc`, min-chance 5 % | 359 |

#### 4b.2.2 Group `1011079` — Helmets — **16 rows** (L371–L401)

Legend: base `IronIngot` `1044036` / msg `1044037`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base (no gate) | `Bascinet` `1025132` | 8.3 | 58.3 | `IronIngot` ×15 | ING | — | 371 |
| 2 | base | `CloseHelm` `1025128` | 37.9 | 87.9 | `IronIngot` ×15 | ING | — | 372 |
| 3 | base | `Helmet` `1025130` | 37.9 | 87.9 | `IronIngot` ×15 | ING | — | 373 |
| 4 | base | `NorseHelm` `1025134` | 37.9 | 87.9 | `IronIngot` ×15 | ING | — | 374 |
| 5 | base | `PlateHelm` `1025138` | 62.6 | 112.6 | `IronIngot` ×15 | ING | — | 375 |
| 6 | `if (Core.SE)` L377 | `ChainHatsuburi` `1030175` | 30.0 | 80.0 | `IronIngot` ×20 | ING | — | 379 |
| 7 | SE | `PlateHatsuburi` `1030176` | 45.0 | 95.0 | `IronIngot` ×20 | ING | — | 381 |
| 8 | SE | `HeavyPlateJingasa` `1030178` | 45.0 | 95.0 | `IronIngot` ×20 | ING | — | 383 |
| 9 | SE | `LightPlateJingasa` `1030188` | 45.0 | 95.0 | `IronIngot` ×20 | ING | — | 385 |
| 10 | SE | `SmallPlateJingasa` `1030191` | 45.0 | 95.0 | `IronIngot` ×20 | ING | — | 387 |
| 11 | SE | `DecorativePlateKabuto` `1030179` | 90.0 | 140.0 | `IronIngot` ×25 | ING | — | 389 |
| 12 | SE | `PlateBattleKabuto` `1030192` | 90.0 | 140.0 | `IronIngot` ×25 | ING | — | 391 |
| 13 | SE | `StandardPlateKabuto` `1030196` | 90.0 | 140.0 | `IronIngot` ×25 | ING | — | 393 |
| 14 | `if (Core.ML)` L395 | `Circlet` `1032645` | 62.1 | 112.1 | `IronIngot` ×6 | ING | — | 397 |
| 15 | ML | `RoyalCirclet` `1032646` | 70.0 | 120.0 | `IronIngot` ×6 | ING | — | 399 |
| 16 | ML | `GemmedCirclet` `1032647` | 75.0 | 125.0 | `IronIngot` ×6 + `Tourmaline` ×1 `[1044237/1044240]` + `Amethyst` ×1 `[1044236/1044240]` + `BlueDiamond` ×1 `[1032696/1044240]` | ING | — | 401 |

#### 4b.2.3 Group `1011080` — Shields — **14 rows** (L410–L435)

Legend: base `IronIngot` `1044036` / msg `1044037`. Note negative `minSkill` values are literal.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `Buckler` `1027027` | **-25.0** | 25.0 | `IronIngot` ×10 | ING | — | 410 |
| 2 | base | `BronzeShield` `1027026` | **-15.2** | 34.8 | `IronIngot` ×12 | ING | — | 411 |
| 3 | base | `HeaterShield` `1027030` | 24.3 | 74.3 | `IronIngot` ×18 | ING | — | 412 |
| 4 | base | `MetalShield` `1027035` | **-10.2** | 39.8 | `IronIngot` ×14 | ING | — | 413 |
| 5 | base | `MetalKiteShield` `1027028` | 4.6 | 54.6 | `IronIngot` ×16 | ING | — | 414 |
| 6 | base | `WoodenKiteShield` `1027032` | **-15.2** | 34.8 | `IronIngot` ×8 | ING | — | 415 |
| 7 | `if (Core.AOS)` L417 | `ChaosShield` `1027107` | 85.0 | 135.0 | `IronIngot` ×25 | ING | — | 419 |
| 8 | AOS | `OrderShield` `1027108` | 85.0 | 135.0 | `IronIngot` ×25 | ING | — | 420 |
| 9 | `if (Core.SA)` L423 | `SmallPlateShield` `1095770` | **-25.0** | 25.0 | `IronIngot` ×12 | ING | — | 425 |
| 10 | SA | `GargishKiteShield` `1095774` | 4.6 | 54.6 | `IronIngot` ×16 | ING | — | 427 |
| 11 | SA | `LargePlateShield` `1095772` | 24.3 | 74.3 | `IronIngot` ×18 | ING | — | 429 |
| 12 | SA | `MediumPlateShield` `1095771` | **-10.2** | 39.8 | `IronIngot` ×14 | ING | — | 431 |
| 13 | SA | `GargishChaosShield` `1095808` | 85.0 | 135.0 | `IronIngot` ×25 | ING | — | 433 |
| 14 | SA | `GargishOrderShield` `1095810` | 85.0 | 135.0 | `IronIngot` ×25 | ING | — | 435 |

#### 4b.2.4 Group `1011081` — Bladed — **68 rows** (L443–L663)

Legend: base `IronIngot` `1044036` / msg `1044037` on all 68 rows. Gem extras use
`103269x` / msg `1044240`; ML boss-reagent extras use msg `1042081`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | `if (Core.AOS)` L441 | `BoneHarvester` `1029915` | 33.0 | 83.0 | `IronIngot` ×10 | ING | — | 443 |
| 2 | base | `Broadsword` `1023934` | 35.4 | 85.4 | `IronIngot` ×10 | ING | — | 446 |
| 3 | AOS L448 | `CrescentBlade` `1029921` | 45.0 | 95.0 | `IronIngot` ×14 | ING | — | 450 |
| 4 | base | `Cutlass` `1025185` | 24.3 | 74.3 | `IronIngot` ×8 | ING | — | 453 |
| 5 | base | `Dagger` `1023921` | **-0.4** | 49.6 | `IronIngot` ×3 | ING | — | 454 |
| 6 | base | `Katana` `1025119` | 44.1 | 94.1 | `IronIngot` ×8 | ING | — | 455 |
| 7 | base | `Kryss` `1025121` | 36.7 | 86.7 | `IronIngot` ×8 | ING | — | 456 |
| 8 | base | `Longsword` `1023937` | 28.0 | 78.0 | `IronIngot` ×12 | ING | — | 457 |
| 9 | base | `Scimitar` `1025046` | 31.7 | 81.7 | `IronIngot` ×10 | ING | — | 458 |
| 10 | base | `VikingSword` `1025049` | 24.3 | 74.3 | `IronIngot` ×14 | ING | — | 459 |
| 11 | `if (Core.SE)` L461 | `NoDachi` `1030221` | 75.0 | 125.0 | `IronIngot` ×18 | ING | — | 463 |
| 12 | SE | `Wakizashi` `1030223` | 50.0 | 100.0 | `IronIngot` ×8 | ING | — | 465 |
| 13 | SE | `Lajatang` `1030226` | 80.0 | 130.0 | `IronIngot` ×25 | ING | — | 467 |
| 14 | SE | `Daisho` `1030228` | 60.0 | 110.0 | `IronIngot` ×15 | ING | — | 469 |
| 15 | SE | `Tekagi` `1030230` | 55.0 | 105.0 | `IronIngot` ×12 | ING | — | 471 |
| 16 | SE | `Shuriken` `1030231` | 45.0 | 95.0 | `IronIngot` ×5 | ING | — | 473 |
| 17 | SE | `Kama` `1030232` | 40.0 | 90.0 | `IronIngot` ×14 | ING | — | 475 |
| 18 | SE | `Sai` `1030234` | 50.0 | 100.0 | `IronIngot` ×12 | ING | — | 477 |
| 19 | `if (Core.ML)` L479 | `RadiantScimitar` `1031571` | 75.0 | 125.0 | `IronIngot` ×15 | ING | — | 481 |
| 20 | ML | `WarCleaver` `1031567` | 70.0 | 120.0 | `IronIngot` ×18 | ING | — | 483 |
| 21 | ML | `ElvenSpellblade` `1031564` | 70.0 | 120.0 | `IronIngot` ×14 | ING | — | 485 |
| 22 | ML | `AssassinSpike` `1031565` | 70.0 | 120.0 | `IronIngot` ×9 | ING | — | 487 |
| 23 | ML | `Leafblade` `1031566` | 70.0 | 120.0 | `IronIngot` ×12 | ING | — | 489 |
| 24 | ML | `RuneBlade` `1031570` | 70.0 | 120.0 | `IronIngot` ×15 | ING | — | 491 |
| 25 | ML | `ElvenMachete` `1031573` | 70.0 | 120.0 | `IronIngot` ×14 | ING | — | 493 |
| 26 | ML (artie) | `RuneCarvingKnife` `1072915` | 70.0 | 120.0 | `IronIngot` ×9 + `DreadHornMane` ×1 `[1032682/1053098]` + `Putrefaction` ×10 `[1032678/1053098]` + `Muculent` ×10 `[1032680/1053098]` | ING | `recipe:350`, `non-exc` | 495 |
| 27 | ML (artie) | `ColdForgedBlade` `1072916` | 70.0 | 120.0 | `IronIngot` ×18 + `GrizzledBones` ×1 `[1032684/1053098]` + `Taint` ×10 `[1032684/1053098]` + `Blight` ×10 `[1032675/1053098]` | ING | `recipe:351`, `non-exc` | 502 |
| 28 | ML (artie) | `OverseerSunderedBlade` `1072920` | 70.0 | 120.0 | `IronIngot` ×15 + `GrizzledBones` ×1 `[1032684/1053098]` + `Blight` ×10 `[1032675/1053098]` + `Scourge` ×10 `[1032677/1053098]` | ING | `recipe:352`, `non-exc` | 509 |
| 29 | ML (artie) | `LuminousRuneBlade` `1072922` | 70.0 | 120.0 | `IronIngot` ×15 + `GrizzledBones` ×1 `[1032684/1053098]` + `Corruption` ×10 `[1032676/1053098]` + `Putrefaction` ×10 `[1032678/1053098]` | ING | `recipe:353`, `non-exc` | 516 |
| 30 | ML recipe set | `TrueSpellblade` `1073513` | 75.0 | 125.0 | `IronIngot` ×14 + `BlueDiamond` ×1 `[1032696/1044240]` | ING | `recipe:300` | 523 |
| 31 | ML recipe set | `IcySpellblade` `1073514` | 75.0 | 125.0 | `IronIngot` ×14 + `Turquoise` ×1 `[1032691/1044240]` | ING | `recipe:301` | 527 |
| 32 | ML recipe set | `FierySpellblade` `1073515` | 75.0 | 125.0 | `IronIngot` ×14 + `FireRuby` ×1 `[1032695/1044240]` | ING | `recipe:302` | 531 |
| 33 | ML recipe set | `SpellbladeOfDefense` `1073516` | 75.0 | 125.0 | `IronIngot` ×18 + `WhitePearl` ×1 `[1032694/1044240]` | ING | `recipe:303` | 535 |
| 34 | ML recipe set | `TrueAssassinSpike` `1073517` | 75.0 | 125.0 | `IronIngot` ×9 + `DarkSapphire` ×1 `[1032690/1044240]` | ING | `recipe:304` | 539 |
| 35 | ML recipe set | `ChargedAssassinSpike` `1073518` | 75.0 | 125.0 | `IronIngot` ×9 + `EcruCitrine` ×1 `[1032693/1044240]` | ING | `recipe:305` | 543 |
| 36 | ML recipe set | `MagekillerAssassinSpike` `1073519` | 75.0 | 125.0 | `IronIngot` ×9 + `BrilliantAmber` ×1 `[1032697/1044240]` | ING | `recipe:306` | 547 |
| 37 | ML recipe set | `WoundingAssassinSpike` `1073520` | 75.0 | 125.0 | `IronIngot` ×9 + `PerfectEmerald` ×1 `[1032692/1044240]` | ING | `recipe:307` | 551 |
| 38 | ML recipe set | `TrueLeafblade` `1073521` | 75.0 | 125.0 | `IronIngot` ×12 + `BlueDiamond` ×1 | ING | `recipe:308` | 555 |
| 39 | ML recipe set | `Luckblade` `1073522` | 75.0 | 125.0 | `IronIngot` ×12 + `WhitePearl` ×1 | ING | `recipe:309` | 559 |
| 40 | ML recipe set | `MagekillerLeafblade` `1073523` | 75.0 | 125.0 | `IronIngot` ×12 + `FireRuby` ×1 | ING | `recipe:310` | 563 |
| 41 | ML recipe set | `LeafbladeOfEase` `1073524` | 75.0 | 125.0 | `IronIngot` ×12 + `PerfectEmerald` ×1 | ING | `recipe:311` | 567 |
| 42 | ML recipe set | `KnightsWarCleaver` `1073525` | 75.0 | 125.0 | `IronIngot` ×18 + `PerfectEmerald` ×1 | ING | `recipe:312` | 571 |
| 43 | ML recipe set | `ButchersWarCleaver` `1073526` | 75.0 | 125.0 | `IronIngot` ×18 + `Turquoise` ×1 | ING | `recipe:313` | 575 |
| 44 | ML recipe set | `SerratedWarCleaver` `1073527` | 75.0 | 125.0 | `IronIngot` ×18 + `EcruCitrine` ×1 | ING | `recipe:314` | 579 |
| 45 | ML recipe set | `TrueWarCleaver` `1073528` | 75.0 | 125.0 | `IronIngot` ×18 + `BrilliantAmber` ×1 | ING | `recipe:315` | 583 |
| 46 | ML recipe set | `AdventurersMachete` `1073533` | 75.0 | 125.0 | `IronIngot` ×14 + `WhitePearl` ×1 | ING | `recipe:316` | 587 |
| 47 | ML recipe set | `OrcishMachete` `1073534` | 75.0 | 125.0 | `IronIngot` ×14 + `Scourge` ×1 `[1072136/1042081]` | ING | `recipe:317` | 591 |
| 48 | ML recipe set | `MacheteOfDefense` `1073535` | 75.0 | 125.0 | `IronIngot` ×14 + `BrilliantAmber` ×1 | ING | `recipe:318` | 595 |
| 49 | ML recipe set | `DiseasedMachete` `1073536` | 75.0 | 125.0 | `IronIngot` ×14 + `Blight` ×1 `[1072134/1042081]` | ING | `recipe:319` | 599 |
| 50 | ML recipe set | `Runesabre` `1073537` | 75.0 | 125.0 | `IronIngot` ×15 + `Turquoise` ×1 | ING | `recipe:320` | 603 |
| 51 | ML recipe set | `MagesRuneBlade` `1073538` | 75.0 | 125.0 | `IronIngot` ×15 + `BlueDiamond` ×1 | ING | `recipe:321` | 607 |
| 52 | ML recipe set | `RuneBladeOfKnowledge` `1073539` | 75.0 | 125.0 | `IronIngot` ×15 + `EcruCitrine` ×1 | ING | `recipe:322` | 611 |
| 53 | ML recipe set | `CorruptedRuneBlade` `1073540` | 75.0 | 125.0 | `IronIngot` ×15 + `Corruption` ×1 `[1072135/1042081]` | ING | `recipe:323` | 615 |
| 54 | ML recipe set | `TrueRadiantScimitar` `1073541` | 75.0 | 125.0 | `IronIngot` ×15 + `BrilliantAmber` ×1 | ING | `recipe:324` | 619 |
| 55 | ML recipe set | `DarkglowScimitar` `1073542` | 75.0 | 125.0 | `IronIngot` ×15 + `DarkSapphire` ×1 | ING | `recipe:325` | 623 |
| 56 | ML recipe set | `IcyScimitar` `1073543` | 75.0 | 125.0 | `IronIngot` ×15 + `DarkSapphire` ×1 | ING | `recipe:326` | 627 |
| 57 | ML recipe set | `TwinklingScimitar` `1073544` | 75.0 | 125.0 | `IronIngot` ×15 + `DarkSapphire` ×1 | ING | `recipe:327` | 631 |
| 58 | ML recipe set | `BoneMachete` `1020526` | 45.0 | 95.0 | `IronIngot` ×20 + `Bone` ×6 `[1049064/1049063]` | ING | `recipe:336` | 635 |
| 59 | `if (Core.SA)` L641 | `GargishKatana` `1097490` | 44.1 | 94.1 | `IronIngot` ×8 | ING | — | 645 |
| 60 | SA | `GargishKryss` `1097492` | 36.7 | 86.7 | `IronIngot` ×8 | ING | — | 647 |
| 61 | SA | `GargishBoneHarvester` `1097502` | 33.0 | 83.0 | `IronIngot` ×10 | ING | — | 649 |
| 62 | SA | `GargishTekagi` `1097510` | 55.0 | 105.0 | `IronIngot` ×12 | ING | — | 651 |
| 63 | SA | `GargishDaisho` `1097512` | 60.0 | 110.0 | `IronIngot` ×15 | ING | — | 653 |
| 64 | SA | `DreadSword` `1095372` | 75.0 | 125.0 | `IronIngot` ×14 | ING | — | 655 |
| 65 | SA | `GargishTalwar` `1095373` | 75.0 | **150.0** | `IronIngot` ×18 | ING | — | 657 |
| 66 | SA | `GargishDagger` `1095362` | 0.0 | **100.0** | `IronIngot` ×3 | ING | — | 659 |
| 67 | SA | `BloodBlade` `1095370` | 44.1 | **125.0** | `IronIngot` ×8 | ING | — | 661 |
| 68 | SA | `Shortblade` `1095374` | 28.0 | **100.0** | `IronIngot` ×12 | ING | — | 663 |

#### 4b.2.5 Group `1011082` — Axes — **15 rows** (L670–L706)

Legend: base `IronIngot` `1044036` / msg `1044037`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `Axe` `1023913` | 34.2 | 84.2 | `IronIngot` ×14 | ING | — | 670 |
| 2 | base | `BattleAxe` `1023911` | 30.5 | 80.5 | `IronIngot` ×14 | ING | — | 671 |
| 3 | base | `DoubleAxe` `1023915` | 29.3 | 79.3 | `IronIngot` ×12 | ING | — | 672 |
| 4 | base | `ExecutionersAxe` `1023909` | 34.2 | 84.2 | `IronIngot` ×14 | ING | — | 673 |
| 5 | base | `LargeBattleAxe` `1025115` | 28.0 | 78.0 | `IronIngot` ×12 | ING | — | 674 |
| 6 | base | `TwoHandedAxe` `1025187` | 33.0 | 83.0 | `IronIngot` ×16 | ING | — | 675 |
| 7 | base | `WarAxe` `1025040` | 39.1 | 89.1 | `IronIngot` ×16 | ING | — | 676 |
| 8 | `if (Core.ML)` L678 | `OrnateAxe` `1031572` | 70.0 | 120.0 | `IronIngot` ×18 | ING | — | 680 |
| 9 | ML | `GuardianAxe` `1073545` | 75.0 | 125.0 | `IronIngot` ×15 + `BlueDiamond` ×1 `[1032696/1044240]` | ING | `recipe:328` | 682 |
| 10 | ML | `SingingAxe` `1073546` | 75.0 | 125.0 | `IronIngot` ×15 + `BrilliantAmber` ×1 | ING | `recipe:329` | 686 |
| 11 | ML | `ThunderingAxe` `1073547` | 75.0 | 125.0 | `IronIngot` ×15 + `EcruCitrine` ×1 | ING | `recipe:330` | 690 |
| 12 | ML | `HeavyOrnateAxe` `1073548` | 75.0 | 125.0 | `IronIngot` ×15 + `Turquoise` ×1 | ING | `recipe:331` | 694 |
| 13 | `if (Core.SA)` L700 | `GargishBattleAxe` `1097480` | 30.5 | 80.5 | `IronIngot` ×14 | ING | — | 702 |
| 14 | SA | `GargishAxe` `1097482` | 34.2 | 84.2 | `IronIngot` ×14 | ING | — | 704 |
| 15 | SA | `DualShortAxes` `1095360` | 75.0 | 125.0 | `IronIngot` ×24 | ING | — | 706 |

#### 4b.2.6 Group `1011083` — Pole Arms — **16 rows** (L714–L762)

Legend: base `IronIngot` `1044036` / msg `1044037`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `Bardiche` `1023917` | 31.7 | 81.7 | `IronIngot` ×18 | ING | — | 714 |
| 2 | `if (Core.AOS)` L716 | `BladedStaff` `1029917` | 40.0 | 90.0 | `IronIngot` ×12 | ING | — | 718 |
| 3 | `if (Core.AOS)` L721 | `DoubleBladedStaff` `1029919` | 45.0 | 95.0 | `IronIngot` ×16 | ING | — | 723 |
| 4 | base | `Halberd` `1025183` | 39.1 | 89.1 | `IronIngot` ×20 | ING | — | 726 |
| 5 | `if (Core.AOS)` L728 | `Lance` `1029920` | 48.0 | 98.0 | `IronIngot` ×20 | ING | — | 730 |
| 6 | `if (Core.AOS)` L733 | `Pike` `1029918` | 47.0 | 97.0 | `IronIngot` ×12 | ING | — | 735 |
| 7 | base | `ShortSpear` `1025123` | 45.3 | 95.3 | `IronIngot` ×6 | ING | — | 738 |
| 8 | `if (Core.AOS)` L740 | `Scythe` `1029914` | 39.0 | 89.0 | `IronIngot` ×14 | ING | — | 742 |
| 9 | base | `Spear` `1023938` | 49.0 | 99.0 | `IronIngot` ×12 | ING | — | 745 |
| 10 | base | `WarFork` `1025125` | 42.9 | 92.9 | `IronIngot` ×12 | ING | — | 746 |
| 11 | `if (Core.SA)` L750 | `GargishBardiche` `1097484` | 31.7 | 81.7 | `IronIngot` ×18 | ING | — | 752 |
| 12 | SA | `GargishWarFork` `1097494` | 42.9 | 92.9 | `IronIngot` ×12 | ING | — | 754 |
| 13 | SA | `GargishScythe` `1097500` | 39.0 | 89.0 | `IronIngot` ×14 | ING | — | 756 |
| 14 | SA | `GargishPike` `1097504` | 47.0 | 97.0 | `IronIngot` ×12 | ING | — | 758 |
| 15 | SA | `GargishLance` `1097506` | 48.0 | 98.0 | `IronIngot` ×20 | ING | — | 760 |
| 16 | SA | `DualPointedSpear` `1095365` | 47.0 | 97.0 | `IronIngot` ×16 | ING | — | 762 |

#### 4b.2.7 Group `1011084` — Bashing — **17 rows** (L770–L832)

Legend: base `IronIngot` `1044036` / msg `1044037`; `Tessen`/`GargishTessen` add `Cloth` `1044286` / msg `1044287`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `HammerPick` `1025181` | 34.2 | 84.2 | `IronIngot` ×16 | ING | — | 770 |
| 2 | base | `Mace` `1023932` | 14.5 | 64.5 | `IronIngot` ×6 | ING | — | 771 |
| 3 | base | `Maul` `1025179` | 19.4 | 69.4 | `IronIngot` ×10 | ING | — | 772 |
| 4 | `if (Core.AOS)` L774 | `Scepter` `1029916` | 21.4 | 71.4 | `IronIngot` ×10 | ING | — | 776 |
| 5 | base | `WarMace` `1025127` | 28.0 | 78.0 | `IronIngot` ×14 | ING | — | 779 |
| 6 | base | `WarHammer` `1025177` | 34.2 | 84.2 | `IronIngot` ×16 | ING | — | 780 |
| 7 | `if (Core.SE)` L782 | `Tessen` `1030222` | 85.0 | 135.0 | `IronIngot` ×16 + `Cloth` ×10 | ING | **`+Tailoring 50.0..55.0`** | 784 |
| 8 | `if (Core.ML)` L791 | `DiamondMace` `1031568` | 70.0 | 120.0 | `IronIngot` ×20 | ING | — | 793 |
| 9 | ML (artie) | `ShardThrasher` `1072918` | 70.0 | 120.0 | `IronIngot` ×20 + `EyeOfTheTravesty` ×1 `[1073126/1042081]` + `Muculent` ×10 `[1072139/1042081]` + `Corruption` ×10 `[1072135/1042081]` | ING | `recipe:354`, `non-exc` | 795 |
| 10 | ML recipe set | `RubyMace` `1073529` | 75.0 | 125.0 | `IronIngot` ×20 + `FireRuby` ×1 `[1032695/1044240]` | ING | `recipe:332` | 802 |
| 11 | ML recipe set | `EmeraldMace` `1073530` | 75.0 | 125.0 | `IronIngot` ×20 + `PerfectEmerald` ×1 | ING | `recipe:333` | 806 |
| 12 | ML recipe set | `SapphireMace` `1073531` | 75.0 | 125.0 | `IronIngot` ×20 + `DarkSapphire` ×1 | ING | `recipe:334` | 810 |
| 13 | ML recipe set | `SilverEtchedMace` `1073532` | 75.0 | 125.0 | `IronIngot` ×20 + `BlueDiamond` ×1 | ING | `recipe:335` | 814 |
| 14 | `if (Core.SA)` L822 | `GargishWarHammer` `1097496` | 34.2 | 84.2 | `IronIngot` ×16 | ING | — | 824 |
| 15 | SA | `GargishMaul` `1097498` | 19.4 | 69.4 | `IronIngot` ×10 | ING | — | 826 |
| 16 | SA | `GargishTessen` `1097508` | 85.0 | 135.0 | `IronIngot` ×16 + `Cloth` ×10 | ING | **`+Tailoring 50.0..55.0`** | 828 |
| 17 | SA | `DiscMace` `1095366` | 70.0 | 120.0 | `IronIngot` ×20 | ING | — | 832 |

> Row 6 `WarHammer` is a common transcription trap: the literal at `DefBlacksmithy.cs:780` is
> `IronIngot ×16`, **not** `×14` as its neighbours `WarMace` (L779) and `HammerPick` (L770) are.
> `[SRC]`

#### 4b.2.8 Group `1116354` — High Seas Cannons — **8 rows** (L845–L873)

Legend: base `IronIngot` `1044036` / msg `1044037`; `Cloth` `1044286` / msg `1044287`; `Board` `1044041` / msg `1044351`.
`if (Core.HS)` L841; the `Core.EJ` branches are mutually exclusive (`L843`, `L848`, `L854`, `L860`).

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | `if (Core.EJ)` L843 | `Cannonball` `1116029` | 10.0 | 60.0 | `IronIngot` ×12 | ING | `useAllRes` | 845 |
| 2 | `else` (HS, not EJ) | `LightCannonball` `1116266` | 0.0 | 50.0 | `IronIngot` ×6 | ING | — | 850 |
| 3 | `else` | `HeavyCannonball` `1116267` | 10.0 | 60.0 | `IronIngot` ×12 | ING | — | 851 |
| 4 | `if (Core.EJ)` L854 | `Grapeshot` `1116030` | 15.0 | 70.0 | `IronIngot` ×12 + `Cloth` ×2 | ING | `useAllRes` | 856 |
| 5 | `else` | `LightGrapeshot` `1116030` | 0.0 | 50.0 | `IronIngot` ×6 + `Cloth` ×1 | ING | — | 862 |
| 6 | `else` | `HeavyGrapeshot` `1116166` | 15.0 | 70.0 | `IronIngot` ×12 + `Cloth` ×2 | ING | — | 865 |
| 7 | HS | `LightShipCannonDeed` `1095790` | 65.0 | 120.0 | `IronIngot` ×900 + `Board` ×50 | ING | **`+Carpentry 65.0..100.0`** | 869 |
| 8 | HS | `HeavyShipCannonDeed` `1095794` | 70.0 | 120.0 | `IronIngot` ×1800 + `Board` ×75 | ING | **`+Carpentry 70.0..100.0`** | 873 |

> Note: `LightGrapeshot` and `Grapeshot` share the *same* name cliloc `1116030` (`L856`, `L862`). `[SRC]`

#### 4b.2.9 Group `1079508` — Throwing — **3 rows** (L884–L888)

`if (Core.SA)` L882. Base `IronIngot` `1044036` / msg `1044037`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | SA | `Boomerang` `1095359` | 75.0 | 125.0 | `IronIngot` ×5 | ING | — | 884 |
| 2 | SA | `Cyclone` `1095364` | 75.0 | 125.0 | `IronIngot` ×9 | ING | — | 886 |
| 3 | SA | `SoulGlaive` `1095363` | 75.0 | 125.0 | `IronIngot` ×9 | ING | — | 888 |

#### 4b.2.10 Group `1011173` — Miscellaneous — **10 rows** (L895–L929)

Message clilocs are **not** uniform in this group: dragon armour uses `1060884`, but
`MetalKeg`, `CrushedGlass`, `PowderedIron`, `ExodusSacrificalDagger` and `GlovesOfFeudalGrip`
use `1044253`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | Dragon armour (`RedScales` `1060883` / msg `1060884`) | `DragonGloves` `1029795` | 68.9 | 118.9 | `RedScales` ×16 | **SCL** (`SetUseSubRes2`) | — | 895 |
| 2 | Dragon armour | `DragonHelm` `1029797` | 72.6 | 122.6 | `RedScales` ×20 | SCL | — | 898 |
| 3 | Dragon armour | `DragonLegs` `1029799` | 78.8 | 128.8 | `RedScales` ×28 | SCL | — | 901 |
| 4 | Dragon armour | `DragonArms` `1029815` | 76.3 | 126.3 | `RedScales` ×24 | SCL | — | 904 |
| 5 | Dragon armour | `DragonChest` `1029793` | 85.0 | 135.0 | `RedScales` ×36 | SCL | — | 907 |
| 6 | `if (Core.SA)` L910 | `CrushedGlass` `1113351` | 110.0 | 135.0 | `BlueDiamond` ×1 `[1032696/1044253]` + `GlassSword` ×5 `[1095371/1044253]` | ING | — | 912 |
| 7 | SA | `PowderedIron` `1113353` | 110.0 | 135.0 | `WhitePearl` ×1 `[1026253/1044253]` + `IronIngot` ×20 `[1044036/1044037]` | ING | — | 915 |
| 8 | base | `MetalKeg` `1150675` | 85.0 | 100.0 | `IronIngot` ×25 `[1044036/1044253]` | ING | — | 919 |
| 9 | `if (Core.SA)` L921 | `ExodusSacrificalDagger` `1153500` | 95.0 | 120.0 | `IronIngot` ×12 `[1044036/1044253]` + `BlueDiamond` ×2 + `FireRuby` ×2 `[1032695/1044253]` + `SmallPieceofBlackrock` ×10 `[1150016/1044253]` | ING | `non-exc` | 923 |
| 10 | SA | `GlovesOfFeudalGrip` `1157349` | 120.0 | 120.1 | `RedScales` ×18 `[1060883/1060884]` + `BlueDiamond` ×4 `[1032696/1044253]` + `GauntletsOfNobility` ×1 `[1061092/1053098]` + `BloodOfTheDarkFather` ×5 `[1157343/1053098]` | **SCL** | `recipe:356`, `non-exc`, min-chance 5 % | 929 |

#### 4b.2.11 Blacksmithy sub-resource selectors (also part of the menu)

| Selector | Call | Entries | Required skill | Source |
|---|---|---|---|---|
| Primary (`m_CraftSubRes`) | `SetSubRes(typeof(IronIngot), 1044022)` | `IronIngot` `1044022` @ `00.0`; `DullCopperIngot` `1044023` @ `65.0`; `ShadowIronIngot` `1044024` @ `70.0`; `CopperIngot` `1044025` @ `75.0`; `BronzeIngot` `1044026` @ `80.0`; `GoldIngot` `1044027` @ `85.0`; `AgapiteIngot` `1044028` @ `90.0`; `VeriteIngot` `1044029` @ `95.0`; `ValoriteIngot` `1044030` @ `99.0` | `DefBlacksmithy.cs:941-953` `[SRC]` |
| Primary generic name / message clilocs | `AddSubRes(type, name, reqSkill, genericNameNumber, message)` → generic `1044036`, message `1044267` for Iron, `1044268` for the 8 coloured ingots | `DefBlacksmithy.cs:945-953` `[SRC]` |
| Secondary (`m_CraftSubRes2`) | `SetSubRes2(typeof(RedScales), 1060875)` | `RedScales` `1060875`, `YellowScales` `1060876`, `BlackScales` `1060877`, `GreenScales` `1060878`, `WhiteScales` `1060879`, `BlueScales` `1060880` — **all @ `0.0`**, generic `1053137`, message `1044268` | `DefBlacksmithy.cs:955-962` `[SRC]` |

---

### 4b.3 DefTailoring — group index

| # | Group cliloc | Region label in source | `AddCraft` rows | First line | Last line |
|---|---|---|---|---|---|
| 1 | `1044457` | Materials | 6 | L188 | L214 |
| 2 | `1011375` | Hats | 26 | L222 | L280 |
| 3 | `1111747` | Shirts/Pants | 40 | L293 | L388 |
| 4 | `1015283` | Misc | 29 | L396 | L506 |
| 5 | `1015288` | Footwear | 12 | L521 | L559 |
| 6 | `1015293` | Leather Armor | 44 | L570 | L700 |
| 7 | `1111748` | Cloth Armor | 9 | L711 | L727 |
| 8 | `1015300` | Studded Armor | 15 | L732 | L762 |
| 9 | `1015306` | Female Armor | 10 | L769 | L791 |
| 10 | `1049149` | Bone Armor | 7 | L800 | L820 |
| | | **total** | **198** | | |

> **Runtime row count ≠ 198.** The powder-charge block is exclusive:
> `if (Core.HS) { if (Core.EJ) {PowderCharge} else {LightPowderCharge, HeavyPowderCharge} }`
> → **197** rows with `Core.EJ`, **198** without. `[SRC]` `DefTailoring.cs:194-210`

#### 4b.3.1 Group `1044457` — Materials — **6 rows** (L188–L214)

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `CutUpCloth` `1044458` | 0.0 | 0.0 | `BoltOfCloth` ×1 `[1044453/1044253]` | — | **`AddCraftAction(CutUpCloth)`** (L189) | 188 |
| 2 | base | `CombineCloth` `1044459` | 0.0 | 0.0 | `Cloth` ×1 `[1044455/1044253]` | — | **`AddCraftAction(CombineCloth)`** (L192) | 191 |
| 3 | `if (Core.HS)`+`Core.EJ` L194/196 | `PowderCharge` `1116160` | 0.0 | 50.0 | `Cloth` ×1 `[1044455/1044253]` + `BlackPowder` ×4 `[1095826/1044253]` | — | `useAllRes` | 198 |
| 4 | `else` (HS, not EJ) | `LightPowderCharge` `1116159` | 0.0 | 50.0 | `Cloth` ×1 + `BlackPowder` ×1 | — | — | 204 |
| 5 | `else` | `HeavyPowderCharge` `1116160` | 0.0 | 50.0 | `Cloth` ×1 + `BlackPowder` ×4 | — | — | 207 |
| 6 | `if (Core.SA)` L212 | `AbyssalCloth` `1113350` | 110.0 | 160.0 | `Cloth` ×50 `[1044455/1044253]` + `CrystallineBlackrock` ×1 `[1077568/1044253]` | — | `hue:2075` | 214 |

> `LightPowderCharge` `1116159` and `HeavyPowderCharge` `1116160`: `HeavyPowderCharge` reuses
> `PowderCharge`'s cliloc. `PowderCharge` and `HeavyPowderCharge` therefore have the **same** name
> cliloc `1116160`. `[SRC]` `DefTailoring.cs:198, 207`

#### 4b.3.2 Group `1011375` — Hats — **26 rows** (L222–L280)

Legend: base `Cloth` `1044455` / msg `1044287`; extra `Leather` `1044462` / msg `1044463`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `SkullCap` `1025444` | 0.0 | 25.0 | `Cloth` ×2 | — | — | 222 |
| 2 | base | `Bandana` `1025440` | 0.0 | 25.0 | `Cloth` ×2 | — | — | 223 |
| 3 | base | `FloppyHat` `1025907` | 6.2 | 31.2 | `Cloth` ×11 | — | — | 224 |
| 4 | base | `Cap` `1025909` | 6.2 | 31.2 | `Cloth` ×11 | — | — | 225 |
| 5 | base | `WideBrimHat` `1025908` | 6.2 | 31.2 | `Cloth` ×12 | — | — | 226 |
| 6 | base | `StrawHat` `1025911` | 6.2 | 31.2 | `Cloth` ×10 | — | — | 227 |
| 7 | base | `TallStrawHat` `1025910` | 6.7 | 31.7 | `Cloth` ×13 | — | — | 228 |
| 8 | base | `WizardsHat` `1025912` | 7.2 | 32.2 | `Cloth` ×15 | — | — | 229 |
| 9 | base | `Bonnet` `1025913` | 6.2 | 31.2 | `Cloth` ×11 | — | — | 230 |
| 10 | base | `FeatheredHat` `1025914` | 6.2 | 31.2 | `Cloth` ×12 | — | — | 231 |
| 11 | base | `TricorneHat` `1025915` | 6.2 | 31.2 | `Cloth` ×12 | — | — | 232 |
| 12 | base | `JesterHat` `1025916` | 7.2 | 32.2 | `Cloth` ×15 | — | — | 233 |
| 13 | `if (Core.AOS)` L235 | `FlowerGarland` `1028965` | 10.0 | 35.0 | `Cloth` ×5 | — | — | 236 |
| 14 | `if (Core.SE)` L238 | `ClothNinjaHood` `1030202` | 80.0 | 105.0 | `Cloth` ×13 | — | — | 240 |
| 15 | SE | `Kasa` `1030211` | 60.0 | 85.0 | `Cloth` ×12 | — | — | 242 |
| 16 | base | `OrcMask` `1025147` | 75.0 | 100.0 | `Cloth` ×12 | — | — | 245 |
| 17 | base | `BearMask` `1025445` | 77.5 | 102.5 | `Cloth` ×15 | — | — | 246 |
| 18 | base | `DeerMask` `1025447` | 77.5 | 102.5 | `Cloth` ×15 | — | — | 247 |
| 19 | base | `TribalMask` `1025449` | 82.5 | 107.5 | `Cloth` ×12 | — | — | 248 |
| 20 | base | `HornedTribalMask` `1025451` | 82.5 | 107.5 | `Cloth` ×12 | — | — | 249 |
| 21 | `if (Core.TOL)` L252 | `ChefsToque` `1109618` | 6.2 | 21.2 | `Cloth` ×11 | — | `recipe:561` | 254 |
| 22 | base (no gate, `#region TOL` L251) | `KrampusMinionHat` `1125639` | 100.0 | **500.0** | `Cloth` ×8 | — | `recipe:586` | 258 |
| 23 | `if (Core.EJ)` L261 | `AssassinsCowl` `1126024` | 90.0 | 110.0 | `Cloth` ×5 + `Leather` ×5 + `VileTentacles` ×5 `[1113333/1044253]` | — | `recipe:1108` | 263 |
| 24 | EJ | `MagesHood` `1159227` | 90.0 | 110.0 | `Cloth` ×5 + `Leather` ×5 + `VoidCore` ×5 `[1113334/1044253]` | — | `recipe:1109` | 268 |
| 25 | EJ | `CowlOfTheMaceAndShield` `1159228` | 120.0 | **215.0** | `Cloth` ×5 + `Leather` ×5 + `MaceAndShieldGlasses` ×1 `[1073381/1044253]` + `VileTentacles` ×10 | — | `recipe:1110`, `force-exc`, min-chance 5 % | 273 |
| 26 | EJ | `MagesHoodOfScholarlyInsight` `1159229` | 120.0 | **215.0** | `Cloth` ×5 + `Leather` ×5 + `TheScholarsHalo` ×1 `[1157354/1044253]` + `VoidCore` ×10 | — | `recipe:1111`, `force-exc`, min-chance 5 % | 280 |

#### 4b.3.3 Group `1111747` — Shirts/Pants — **40 rows** (L293–L388)

Legend: base `Cloth` `1044455` / msg `1044287`, except `RobeofRite` (base `Leather` `1044462` / msg `1044253`).

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `Doublet` `1028059` | **0** | 25.0 | `Cloth` ×8 | — | — | 293 |
| 2 | base | `Shirt` `1025399` | 20.7 | 45.7 | `Cloth` ×8 | — | — | 294 |
| 3 | base | `FancyShirt` `1027933` | 24.8 | 49.8 | `Cloth` ×8 | — | — | 295 |
| 4 | base | `Tunic` `1028097` | **00.0** | 25.0 | `Cloth` ×12 | — | — | 296 |
| 5 | base | `Surcoat` `1028189` | 8.2 | 33.2 | `Cloth` ×14 | — | — | 297 |
| 6 | base | `PlainDress` `1027937` | 12.4 | 37.4 | `Cloth` ×10 | — | — | 298 |
| 7 | base | `FancyDress` `1027935` | 33.1 | 58.1 | `Cloth` ×12 | — | — | 299 |
| 8 | base | `Cloak` `1025397` | 41.4 | 66.4 | `Cloth` ×14 | — | — | 300 |
| 9 | base | `Robe` `1027939` | 53.9 | 78.9 | `Cloth` ×16 | — | — | 301 |
| 10 | base | `JesterSuit` `1028095` | 8.2 | 33.2 | `Cloth` ×24 | — | — | 302 |
| 11 | `if (Core.AOS)` L304 | `FurCape` `1028969` | 35.0 | 60.0 | `Cloth` ×13 | — | — | 306 |
| 12 | AOS | `GildedDress` `1028973` | 37.5 | 62.5 | `Cloth` ×16 | — | — | 307 |
| 13 | AOS | `FormalShirt` `1028975` | 26.0 | 51.0 | `Cloth` ×16 | — | — | 308 |
| 14 | `if (Core.SE)` L311 | `ClothNinjaJacket` `1030207` | 75.0 | 100.0 | `Cloth` ×12 | — | — | 313 |
| 15 | SE | `Kamishimo` `1030212` | 75.0 | 100.0 | `Cloth` ×15 | — | — | 315 |
| 16 | SE | `HakamaShita` `1030215` | 40.0 | 65.0 | `Cloth` ×14 | — | — | 317 |
| 17 | SE | `MaleKimono` `1030189` | 50.0 | 75.0 | `Cloth` ×16 | — | — | 319 |
| 18 | SE | `FemaleKimono` `1030190` | 50.0 | 75.0 | `Cloth` ×16 | — | — | 321 |
| 19 | SE | `JinBaori` `1030220` | 30.0 | 55.0 | `Cloth` ×12 | — | — | 323 |
| 20 | base | `ShortPants` `1025422` | 24.8 | 49.8 | `Cloth` ×6 | — | — | 326 |
| 21 | base | `LongPants` `1025433` | 24.8 | 49.8 | `Cloth` ×8 | — | — | 327 |
| 22 | base | `Kilt` `1025431` | 20.7 | 45.7 | `Cloth` ×8 | — | — | 328 |
| 23 | base | `Skirt` `1025398` | 29.0 | 54.0 | `Cloth` ×10 | — | — | 329 |
| 24 | `if (Core.AOS)` L331 | `FurSarong` `1028971` | 35.0 | 60.0 | `Cloth` ×12 | — | — | 332 |
| 25 | `if (Core.SE)` L334 | `Hakama` `1030213` | 50.0 | 75.0 | `Cloth` ×16 | — | — | 336 |
| 26 | SE | `TattsukeHakama` `1030214` | 50.0 | 75.0 | `Cloth` ×16 | — | — | 338 |
| 27 | `if (Core.ML)` L342 | `ElvenShirt` `1032661` | 80.0 | 105.0 | `Cloth` ×10 | — | — | 344 |
| 28 | ML | `ElvenDarkShirt` `1032662` | 80.0 | 105.0 | `Cloth` ×10 | — | — | 346 |
| 29 | ML | `ElvenPants` `1032665` | 80.0 | 105.0 | `Cloth` ×12 | — | — | 348 |
| 30 | ML | `MaleElvenRobe` `1032659` | 80.0 | 105.0 | `Cloth` ×30 | — | — | 350 |
| 31 | ML | `FemaleElvenRobe` `1032660` | 80.0 | 105.0 | `Cloth` ×30 | — | — | 352 |
| 32 | ML | `WoodlandBelt` `1032639` | 80.0 | 105.0 | `Cloth` ×10 | — | — | 354 |
| 33 | `if (Core.SA)` L359 | `GargishRobe` `1095256` | 53.9 | 78.9 | `Cloth` ×16 | — | — | 361 |
| 34 | SA | `GargishFancyRobe` `1095258` | 53.9 | 78.9 | `Cloth` ×16 | — | — | 363 |
| 35 | SA | `RobeofRite` `1153510` | 101.5 | 120.0 | `Leather` ×6 `[1044462/1044253]` + `FireRuby` ×1 `[1032695/1044253]` + `GoldDust` ×5 `[1098337/1044253]` + `AbyssalCloth` ×6 `[1113350/1044253]` | — | `non-exc` | 365 |
| 36 | `if (Core.TOL)` L374 | `GuildedKilt` `1109619` | 82.8 | 97.8 | `Cloth` ×8 | — | `recipe:562` | 376 |
| 37 | TOL | `CheckeredKilt` `1109620` | 41.4 | 56.4 | `Cloth` ×8 | — | `recipe:563` | 379 |
| 38 | TOL | `FancyKilt` `1109621` | 20.7 | 25.7 | `Cloth` ×8 | — | `recipe:564` | 382 |
| 39 | TOL | `FloweredDress` `1109622` | 75.0 | 90.0 | `Cloth` ×18 | — | `recipe:565` | 385 |
| 40 | TOL | `EveningGown` `1109625` | **75** | 90.0 | `Cloth` ×18 | — | `recipe:566` | 388 |

#### 4b.3.4 Group `1015283` — Misc — **29 rows** (L396–L506)

Legend: base `Cloth` `1044455` / msg `1044287` unless stated; quivers use `Leather` `1044462` / msg `1044463`
with reagent msg `1042081`; `LeatherContainerEngraver` uses `Bone` `1049064` / msg `1049063`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `BodySash` `1025441` | 4.1 | 29.1 | `Cloth` ×4 | — | — | 396 |
| 2 | base | `HalfApron` `1025435` | 20.7 | 45.7 | `Cloth` ×6 | — | — | 397 |
| 3 | base | `FullApron` `1025437` | 29.0 | 54.0 | `Cloth` ×10 | — | — | 398 |
| 4 | `if (Core.SE)` L400 | `Obi` `1030219` | 20.0 | 45.0 | `Cloth` ×6 | — | — | 402 |
| 5 | `if (Core.ML)` L405 | `ElvenQuiver` `1032657` | 65.0 | 115.0 | `Leather` ×28 | — | `recipe:501` | 407 |
| 6 | ML | `QuiverOfFire` `1073109` | 65.0 | 115.0 | `Leather` ×28 + `FireRuby` ×15 `[1032695/1042081]` | — | `recipe:502` | 410 |
| 7 | ML | `QuiverOfIce` `1073110` | 65.0 | 115.0 | `Leather` ×28 + `WhitePearl` ×15 `[1032694/1042081]` | — | `recipe:503` | 414 |
| 8 | ML | `QuiverOfBlight` `1073111` | 65.0 | 115.0 | `Leather` ×28 + `Blight` ×10 `[1032675/1042081]` | — | `recipe:504` | 418 |
| 9 | ML | `QuiverOfLightning` `1073112` | 65.0 | 115.0 | `Leather` ×28 + `Corruption` ×10 `[1032676/1042081]` | — | `recipe:505` | 422 |
| 10 | ML (`#region` L426) | `LeatherContainerEngraver` `1072152` | 75.0 | 100.0 | `Bone` ×1 `[1049064/1049063]` + `Leather` ×6 + `SpoolOfThread` ×2 `[1073462/1073463]` + `Dyes` ×1 `[1024009/1044253]` | — | — | 427 |
| 11 | `if (Core.SA)` L435 | `GargoyleHalfApron` `1099568` | 20.7 | 45.7 | `Cloth` ×6 | — | — | 437 |
| 12 | SA | `GargishSash` `1115388` | 4.1 | 29.1 | `Cloth` ×4 | — | — | 438 |
| 13 | base | `OilCloth` `1041498` | 74.6 | 99.6 | `Cloth` ×1 | — | — | 442 |
| 14 | `if (Core.SE)` L444 | `GozaMatEastDeed` `1030404` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 446 |
| 15 | SE | `GozaMatSouthDeed` `1030405` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 448 |
| 16 | SE | `SquareGozaMatEastDeed` `1030407` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 450 |
| 17 | SE | `SquareGozaMatSouthDeed` `1030406` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 452 |
| 18 | SE | `BrocadeGozaMatEastDeed` `1030408` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 454 |
| 19 | SE | `BrocadeGozaMatSouthDeed` `1030409` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 456 |
| 20 | SE | `BrocadeSquareGozaMatEastDeed` `1030411` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 458 |
| 21 | SE | `BrocadeSquareGozaMatSouthDeed` `1030410` | 55.0 | 80.0 | `Cloth` ×25 | — | — | 460 |
| 22 | `if (Core.EJ)` L463 | `MaceBelt` `1126020` | 90.0 | 110.0 | `Cloth` ×5 + `Leather` ×5 + `Lodestone` ×5 `[1113332/1044253]` | — | `recipe:1100` | 465 |
| 23 | EJ | `SwordBelt` `1126021` | 90.0 | 110.0 | `Cloth` ×5 + `Leather` ×5 + `Lodestone` ×5 | — | `recipe:1101` | 470 |
| 24 | EJ | `DaggerBelt` `1159210` | 90.0 | 110.0 | `Cloth` ×5 + `Leather` ×5 + `Lodestone` ×5 | — | `recipe:1102` | 475 |
| 25 | EJ | `ElegantCollar` `1159224` | 90.0 | 110.0 | `Cloth` ×5 + `Leather` ×5 + `FeyWings` ×5 `[1113332/1044253]` | — | `recipe:1103` | 480 |
| 26 | EJ | `CrimsonMaceBelt` `1159211` | 120.0 | 215.0 | `Cloth` ×5 + `Leather` ×5 + `CrimsonCincture` ×1 `[1075043/1044253]` + `Lodestone` ×10 `[1113348/1044253]` | — | `recipe:1104`, `force-exc`, min-chance 5 % | 485 |
| 27 | EJ | `CrimsonSwordBelt` `1159212` | 120.0 | 215.0 | `Cloth` ×5 + `Leather` ×5 + `CrimsonCincture` ×1 + `Lodestone` ×10 | — | `recipe:1105`, `force-exc`, min-chance 5 % | 492 |
| 28 | EJ | `CrimsonDaggerBelt` `1159213` | 120.0 | 215.0 | `Cloth` ×5 + `Leather` ×5 + `CrimsonCincture` ×1 + `Lodestone` ×10 | — | `recipe:1106`, `force-exc`, min-chance 5 % | 499 |
| 29 | EJ | `ElegantCollarOfFortune` `1159225` | 120.0 | 215.0 | `Cloth` ×5 + `Leather` ×5 + `LeurociansMempoOfFortune` ×1 `[1071460/1044253]` + `FeyWings` ×10 `[1113332/1044253]` | — | `recipe:1107`, `force-exc`, min-chance 5 % | 506 |

> `ElegantCollar` uses `FeyWings` with cliloc `1113332` — the *same* name cliloc that the
> `Lodestone` rows use. Literal source values; possible cliloc reuse (or a source bug).
> `[SRC]` `DefTailoring.cs:482, 467`

#### 4b.3.5 Group `1015288` — Footwear — **12 rows** (L521–L559)

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | `if (Core.ML)` L519 | `ElvenBoots` `1072902` | 80.0 | 105.0 | `Leather` ×15 `[1044462/1044463]` | LTH | — | 521 |
| 2 | `if (Core.AOS)` L525 | `FurBoots` `1028967` | 50.0 | 75.0 | `Cloth` ×12 `[1044455/1044287]` | — | — | 526 |
| 3 | `if (Core.SE)` L528 | `NinjaTabi` `1030210` | 70.0 | 95.0 | `Cloth` ×10 | — | — | 530 |
| 4 | SE | `SamuraiTabi` `1030209` | 20.0 | 45.0 | `Cloth` ×6 | — | — | 532 |
| 5 | base | `Sandals` `1025901` | 12.4 | 37.4 | `Leather` ×4 `[1044462/1044463]` | LTH | — | 535 |
| 6 | base | `Shoes` `1025904` | 16.5 | 41.5 | `Leather` ×6 | LTH | — | 536 |
| 7 | base | `Boots` `1025899` | 33.1 | 58.1 | `Leather` ×8 | LTH | — | 537 |
| 8 | base | `ThighBoots` `1025906` | 41.4 | 66.4 | `Leather` ×10 | LTH | — | 538 |
| 9 | `if (Core.SA)` L541 | `LeatherTalons` `1095728` | 40.4 | 65.4 | `Leather` ×6 — **message cliloc `1044453`** (not `1044463`) | LTH | — | 543 |
| 10 | `if (Core.TOL)` L548 | `JesterShoes` `1109617` | 20.0 | 35.0 | `Cloth` ×6 `[1044455/1044287]` | — | `recipe:560` | 550 |
| 11 | base (`#region Mondain's Legacy` block, no gate) | `KrampusMinionBoots` `1125637` | 100.0 | **500.0** | `Leather` ×6 `[1044462/1044463]` + `Cloth` ×4 `[1044455/1044287]` | LTH | `recipe:587` | 555 |
| 12 | base | `KrampusMinionTalons` `1125644` | 100.0 | **500.0** | `Leather` ×6 + `Cloth` ×4 | LTH | `recipe:588` | 559 |

> `LeatherTalons` (L543) passes `1044453` as the missing-resource message — the cliloc used
> elsewhere in the file for `BoltOfCloth`. Transcribed literally; looks like a source copy-paste. `[SRC]`

#### 4b.3.6 Group `1015293` — Leather Armor — **44 rows** (L570–L700)

Legend: base `Leather` `1044462` / msg `1044463`; ML reagent extras msg `1044253`;
TOL extras `TigerPelt` `1123908` / `DragonTurtleScute` `1123910`, msg `1044253`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | `if (Core.ML)` L568 | `SpellWovenBritches` `1072929` | 92.5 | 117.5 | `Leather` ×15 + `EyeOfTheTravesty` ×1 `[1032685/1044253]` + `Putrefaction` ×10 `[1032678/1044253]` + `Scourge` ×10 `[1032677/1044253]` | LTH | `recipe:551`, `non-exc` | 570 |
| 2 | ML | `SongWovenMantle` `1072931` | 92.5 | 117.5 | `Leather` ×15 + `EyeOfTheTravesty` ×1 + `Blight` ×10 `[1032675/1044253]` + `Muculent` ×10 `[1032680/1044253]` | LTH | `recipe:550`, `non-exc` | 577 |
| 3 | ML | `StitchersMittens` `1072932` | 92.5 | 117.5 | `Leather` ×15 + `CapturedEssence` ×1 `[1032686/1044253]` + `Corruption` ×10 `[1032676/1044253]` + `Taint` ×10 `[1032679/1044253]` | LTH | `recipe:552`, `non-exc` | 584 |
| 4 | base | `LeatherGorget` `1025063` | 53.9 | 78.9 | `Leather` ×4 | LTH | — | 593 |
| 5 | base | `LeatherCap` `1027609` | 6.2 | 31.2 | `Leather` ×2 | LTH | — | 594 |
| 6 | base | `LeatherGloves` `1025062` | 51.8 | 76.8 | `Leather` ×3 | LTH | — | 595 |
| 7 | base | `LeatherArms` `1025061` | 53.9 | 78.9 | `Leather` ×4 | LTH | — | 596 |
| 8 | base | `LeatherLegs` `1025067` | 66.3 | 91.3 | `Leather` ×10 | LTH | — | 597 |
| 9 | base | `LeatherChest` `1025068` | 70.5 | 95.5 | `Leather` ×12 | LTH | — | 598 |
| 10 | `if (Core.SE)` L600 | `LeatherJingasa` `1030177` | 45.0 | 70.0 | `Leather` ×4 | LTH | — | 602 |
| 11 | SE | `LeatherMempo` `1030181` | 80.0 | 105.0 | `Leather` ×8 | LTH | — | 604 |
| 12 | SE | `LeatherDo` `1030182` | 75.0 | 100.0 | `Leather` ×12 | LTH | — | 606 |
| 13 | SE | `LeatherHiroSode` `1030185` | 55.0 | 80.0 | `Leather` ×5 | LTH | — | 608 |
| 14 | SE | `LeatherSuneate` `1030193` | 68.0 | 93.0 | `Leather` ×12 | LTH | — | 610 |
| 15 | SE | `LeatherHaidate` `1030197` | 68.0 | 93.0 | `Leather` ×12 | LTH | — | 612 |
| 16 | SE | `LeatherNinjaPants` `1030204` | 80.0 | 105.0 | `Leather` ×13 | LTH | — | 614 |
| 17 | SE | `LeatherNinjaJacket` `1030206` | 85.0 | 110.0 | `Leather` ×13 | LTH | — | 616 |
| 18 | SE | `LeatherNinjaBelt` `1030203` | 50.0 | 75.0 | `Leather` ×5 | LTH | — | 618 |
| 19 | SE | `LeatherNinjaMitts` `1030205` | 65.0 | 90.0 | `Leather` ×12 | LTH | — | 620 |
| 20 | SE | `LeatherNinjaHood` `1030201` | 90.0 | 115.0 | `Leather` ×14 | LTH | — | 622 |
| 21 | `if (Core.ML)` L626 | `LeafChest` `1032667` | 75.0 | 100.0 | `Leather` ×15 | LTH | — | 628 |
| 22 | ML | `LeafArms` `1032670` | 60.0 | 85.0 | `Leather` ×12 | LTH | — | 630 |
| 23 | ML | `LeafGloves` `1032668` | 60.0 | 85.0 | `Leather` ×10 | LTH | — | 632 |
| 24 | ML | `LeafLegs` `1032671` | 75.0 | 100.0 | `Leather` ×15 | LTH | — | 634 |
| 25 | ML | `LeafGorget` `1032669` | 65.0 | 90.0 | `Leather` ×12 | LTH | — | 636 |
| 26 | ML | `LeafTonlet` `1032672` | 70.0 | 95.0 | `Leather` ×12 | LTH | — | 638 |
| 27 | `if (Core.SA)` L643 | `GargishLeatherArms` `1095327` | 53.9 | 78.9 | `Leather` ×8 | LTH | — | 645 |
| 28 | SA | `GargishLeatherChest` `1095329` | 70.5 | 95.5 | `Leather` ×8 | LTH | — | 647 |
| 29 | SA | `GargishLeatherLegs` `1095333` | 66.3 | 91.3 | `Leather` ×10 | LTH | — | 649 |
| 30 | SA | `GargishLeatherKilt` `1095331` | 58.0 | 83.0 | `Leather` ×6 | LTH | — | 651 |
| 31 | SA | `FemaleGargishLeatherArms` `1095327` | 53.9 | 78.9 | `Leather` ×8 | LTH | — | 653 |
| 32 | SA | `FemaleGargishLeatherChest` `1095329` | 70.5 | 95.5 | `Leather` ×8 | LTH | — | 655 |
| 33 | SA | `FemaleGargishLeatherLegs` `1095333` | 66.3 | 91.3 | `Leather` ×10 | LTH | — | 657 |
| 34 | SA | `FemaleGargishLeatherKilt` `1095331` | 58.0 | 83.0 | `Leather` ×6 | LTH | — | 659 |
| 35 | SA | `GargishLeatherWingArmor` `1096662` | 65.0 | 90.0 | `Leather` ×12 | LTH | — | 661 |
| 36 | `if (Core.TOL)` L666 | `TigerPeltChest` `1109626` | 90.0 | 115.0 | `Leather` ×8 + `TigerPelt` ×4 | LTH | `recipe:570` | 668 |
| 37 | TOL | `TigerPeltLegs` `1109628` | 90.0 | 115.0 | `Leather` ×8 + `TigerPelt` ×4 | LTH | `recipe:573` | 672 |
| 38 | TOL | `TigerPeltShorts` `1109629` | 90.0 | 115.0 | `Leather` ×4 + `TigerPelt` ×2 | LTH | `recipe:574` | 676 |
| 39 | TOL | `TigerPeltHelm` `1109632` | 90.0 | 115.0 | `Leather` ×2 + `TigerPelt` ×1 | LTH | `recipe:572` | 680 |
| 40 | TOL | `TigerPeltCollar` `1109633` | 90.0 | 115.0 | `Leather` ×2 + `TigerPelt` ×1 | LTH | `recipe:571` | 684 |
| 41 | TOL | `DragonTurtleHideChest` `1109634` | 101.5 | 116.5 | `Leather` ×8 + `DragonTurtleScute` ×2 | LTH | `recipe:581` | 688 |
| 42 | TOL | `DragonTurtleHideLegs` `1109636` | 101.5 | 116.5 | `Leather` ×8 + `DragonTurtleScute` ×4 | LTH | `recipe:583` | 692 |
| 43 | TOL | `DragonTurtleHideHelm` `1109637` | 101.5 | 116.5 | `Leather` ×2 + `DragonTurtleScute` ×1 | LTH | `recipe:582` | 696 |
| 44 | TOL | `DragonTurtleHideArms` `1109638` | 101.5 | 116.5 | `Leather` ×4 + `DragonTurtleScute` ×2 | LTH | `recipe:580` | 700 |

#### 4b.3.7 Group `1111748` — Cloth Armor — **9 rows** (L711–L727)

`if (Core.SA)` L709. Legend: base `Cloth` `1044455` / msg `1044287`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | SA | `GargishClothArmsArmor` `1021027` | 87.1 | 137.1 | `Cloth` ×8 | — | — | 711 |
| 2 | SA | `GargishClothChestArmor` `1021029` | 94.0 | 144.0 | `Cloth` ×8 | — | — | 713 |
| 3 | SA | `GargishClothLegsArmor` `1021033` | 91.2 | 141.2 | `Cloth` ×10 | — | — | 715 |
| 4 | SA | `GargishClothKiltArmor` `1021031` | 82.9 | 132.9 | `Cloth` ×6 | — | — | 717 |
| 5 | SA | `FemaleGargishClothArmsArmor` `1021027` | 87.1 | 137.1 | `Cloth` ×8 | — | — | 719 |
| 6 | SA | `FemaleGargishClothChestArmor` `1021029` | 94.0 | 144.0 | `Cloth` ×8 | — | — | 721 |
| 7 | SA | `FemaleGargishClothLegsArmor` `1021033` | 91.2 | 141.2 | `Cloth` ×10 | — | — | 723 |
| 8 | SA | `FemaleGargishClothKiltArmor` `1021031` | 82.9 | 132.9 | `Cloth` ×6 | — | — | 725 |
| 9 | SA | `GargishClothWingArmor` `1115393` | 65.0 | 90.0 | `Cloth` ×12 | — | — | 727 |

#### 4b.3.8 Group `1015300` — Studded Armor — **15 rows** (L732–L762)

Legend: base `Leather` `1044462` / msg `1044463`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `StuddedGorget` `1025078` | 78.8 | 103.8 | `Leather` ×6 | LTH | — | 732 |
| 2 | base | `StuddedGloves` `1025077` | 82.9 | 107.9 | `Leather` ×8 | LTH | — | 733 |
| 3 | base | `StuddedArms` `1025076` | 87.1 | 112.1 | `Leather` ×10 | LTH | — | 734 |
| 4 | base | `StuddedLegs` `1025082` | 91.2 | 116.2 | `Leather` ×12 | LTH | — | 735 |
| 5 | base | `StuddedChest` `1025083` | 94.0 | 119.0 | `Leather` ×14 | LTH | — | 736 |
| 6 | `if (Core.SE)` L738 | `StuddedMempo` `1030216` | 80.0 | 105.0 | `Leather` ×8 | LTH | — | 740 |
| 7 | SE | `StuddedDo` `1030183` | 95.0 | 120.0 | `Leather` ×14 | LTH | — | 742 |
| 8 | SE | `StuddedHiroSode` `1030186` | 85.0 | 110.0 | `Leather` ×8 | LTH | — | 744 |
| 9 | SE | `StuddedSuneate` `1030194` | 92.0 | 117.0 | `Leather` ×14 | LTH | — | 746 |
| 10 | SE | `StuddedHaidate` `1030198` | 92.0 | 117.0 | `Leather` ×14 | LTH | — | 748 |
| 11 | `if (Core.ML)` L752 | `HideChest` `1032651` | 85.0 | 110.0 | `Leather` ×15 | LTH | — | 754 |
| 12 | ML | `HidePauldrons` `1032654` | 75.0 | 100.0 | `Leather` ×12 | LTH | — | 756 |
| 13 | ML | `HideGloves` `1032652` | 75.0 | 100.0 | `Leather` ×10 | LTH | — | 758 |
| 14 | ML | `HidePants` `1032655` | 92.0 | 117.0 | `Leather` ×15 | LTH | — | 760 |
| 15 | ML | `HideGorget` `1032653` | 90.0 | 115.0 | `Leather` ×12 | LTH | — | 762 |

#### 4b.3.9 Group `1015306` — Female Armor — **10 rows** (L769–L791)

Legend: base `Leather` `1044462` / msg `1044463`.

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `LeatherShorts` `1027168` | 62.2 | 87.2 | `Leather` ×8 | LTH | — | 769 |
| 2 | base | `LeatherSkirt` `1027176` | 58.0 | 83.0 | `Leather` ×6 | LTH | — | 770 |
| 3 | base | `LeatherBustierArms` `1027178` | 58.0 | 83.0 | `Leather` ×6 | LTH | — | 771 |
| 4 | base | `StuddedBustierArms` `1027180` | 82.9 | 107.9 | `Leather` ×8 | LTH | — | 772 |
| 5 | base | `FemaleLeatherChest` `1027174` | 62.2 | 87.2 | `Leather` ×8 | LTH | — | 773 |
| 6 | base | `FemaleStuddedChest` `1027170` | 87.1 | 112.1 | `Leather` ×10 | LTH | — | 774 |
| 7 | `if (Core.TOL)` L777 | `TigerPeltBustier` `1109627` | 90.0 | 115.0 | `Leather` ×6 + `TigerPelt` ×3 `[1123908/1044253]` | LTH | `recipe:575` | 779 |
| 8 | TOL | `TigerPeltLongSkirt` `1109630` | 90.0 | 115.0 | `Leather` ×4 + `TigerPelt` ×2 | LTH | `recipe:576` | 783 |
| 9 | TOL | `TigerPeltSkirt` `1109631` | 90.0 | 115.0 | `Leather` ×4 + `TigerPelt` ×2 | LTH | `recipe:577` | 787 |
| 10 | TOL | `DragonTurtleHideBustier` `1109635` | 101.5 | 116.5 | `Leather` ×6 + `DragonTurtleScute` ×3 `[1123910/1044253]` | LTH | `recipe:584` | 791 |

#### 4b.3.10 Group `1049149` — Bone Armor — **7 rows** (L800–L820)

| # | Category | Item | Min | Max | Resources | Sub-res | Flags | Line |
|---|---|---|---|---|---|---|---|---|
| 1 | base | `BoneHelm` `1025206` | 85.0 | 110.0 | `Leather` ×4 `[1044462/1044463]` + `Bone` ×2 `[1049064/1049063]` | LTH | — | 800 |
| 2 | base | `BoneGloves` `1025205` | 89.0 | 114.0 | `Leather` ×6 + `Bone` ×2 | LTH | — | 803 |
| 3 | base | `BoneArms` `1025203` | 92.0 | 117.0 | `Leather` ×8 + `Bone` ×4 | LTH | — | 806 |
| 4 | base | `BoneLegs` `1025202` | 95.0 | 120.0 | `Leather` ×10 + `Bone` ×6 | LTH | — | 809 |
| 5 | base | `BoneChest` `1025199` | 96.0 | 121.0 | `Leather` ×12 + `Bone` ×10 | LTH | — | 812 |
| 6 | base | `OrcHelm` `1027947` | 90.0 | 115.0 | `Leather` ×6 + `Bone` ×4 | LTH | — | 815 |
| 7 | `if (Core.SA)` L818 | `CuffsOfTheArchmage` `1157348` | 120.0 | 120.1 | `Cloth` ×8 `[1044455/1044287]` + `MidnightBracers` ×1 `[1061093/1044253]` + `BloodOfTheDarkFather` ×5 `[1157343/1044253]` + `DarkSapphire` ×5 `[1032690/1044253]` | — | `non-exc`, `recipe:585`, min-chance 5 % | 820 |

> `OrcHelm` is also the single entry in `CraftItem.m_NeverColorTable` (`CraftItem.cs:460`). `[SRC]`

#### 4b.3.11 Tailoring sub-resource selector

| Selector | Call | Entries | Required skill | Source |
|---|---|---|---|---|
| Primary (`m_CraftSubRes`) | `SetSubRes(typeof(Leather), 1049150)` | `Leather` `1049150` @ `00.0`; `SpinedLeather` `1049151` @ `65.0`; `HornedLeather` `1049152` @ `80.0`; `BarbedLeather` `1049153` @ `99.0` — generic `1044462`, message `1049311` | `DefTailoring.cs:829-837` `[SRC]` |
| Secondary (`m_CraftSubRes2`) | **never called** — tailoring has no `SetSubRes2`/`AddSubRes2` | — | verified by grep over `DefTailoring.cs` `[SRC]` |

---

### 4b.4 Resource catalogue — Blacksmithy

Class definition line is the definitive citation; "obtained" is filled only where a producer
line was verified in this checkout, otherwise `[PARTIAL]`/`[UNVERIFIED]`.

| Resource class | cliloc as used in `AddCraft`/`AddRes` | Where obtained | Era |
|---|---|---|---|
| `IronIngot` | `1044036` | Ore → ingot: double-click ore, target a forge, `IsForge` (`Ore.cs:313`), per-resource `difficulty` (Iron = `50.0`, `Ore.cs:326-328`), then `m_Ore.GetIngot()` (`Ore.cs:401`) → `IronOre.GetIngot()` returns `new IronIngot()` (`Ore.cs:483-486`). Class `Scripts/Items/Resource/Ingots.cs:169` | classic |
| `DullCopperIngot` | `1044023` | same smelt path, `difficulty = 65.0` (`Ore.cs:329-331`); class `Ingots.cs:204` | classic (coloured ores: UOR-era mining) |
| `ShadowIronIngot` | `1044024` | `difficulty = 70.0` (`Ore.cs:332-334`); class `Ingots.cs:241` | classic |
| `CopperIngot` | `1044025` | `difficulty = 75.0` (`Ore.cs:335-337`); class `Ingots.cs:278` | classic |
| `BronzeIngot` | `1044026` | `difficulty = 80.0` (`Ore.cs:338-340`); class `Ingots.cs:315` | classic |
| `GoldIngot` | `1044027` | `difficulty = 85.0` (`Ore.cs:341-343`); class `Ingots.cs:352` | classic |
| `AgapiteIngot` | `1044028` | `difficulty` continues the same `switch` (Agapite `90.0`); class `Ingots.cs:389` | classic |
| `VeriteIngot` | `1044029` | same `switch` (`95.0`); class `Ingots.cs:426` | classic |
| `ValoriteIngot` | `1044030` | same `switch` (`99.0`); class `Ingots.cs:463` | classic |
| `RedScales` | `1060883` (base) / `1060875` (sub-res name) | Skinning a creature with `ScaleType.Red`: `list.Add(new RedScales(scales))` (`BaseCreature.cs:2265`), also `ScaleType.All` adds all six (`BaseCreature.cs:2271-2280`). Class `Scripts/Items/Resource/Scales.cs:101` | classic (dragon scales) |
| `YellowScales` `1060876` | as above | `BaseCreature.cs:2266`; class `Scales.cs:135` | classic |
| `BlackScales` `1060877` | as above | `BaseCreature.cs:2267`; class `Scales.cs:171` | classic |
| `GreenScales` `1060878` | as above | `BaseCreature.cs:2268`; class `Scales.cs:207` | classic |
| `WhiteScales` `1060879` | as above | `BaseCreature.cs:2269`; class `Scales.cs:243` | classic |
| `BlueScales` `1060880` | as above | `BaseCreature.cs:2270`; class `Scales.cs:279` | classic |
| `BlueDiamond` | `1032696` (also `1032694`-family gem set) | Loot/reagent; class `Scripts/Items/Resource/MiscMLResources.cs:800`. Producer line in this checkout: `[UNVERIFIED]` — no `new BlueDiamond(` outside TestCenter found; would require reading the ML loot tables | **ML** `[ERA]` |
| `FireRuby` | `1032695` | class `MiscMLResources.cs:755`; producer `[UNVERIFIED]` (TestCenter only) | **ML** `[ERA]` |
| `WhitePearl` | `1032694` / `1026253` (PowderedIron row) | class `MiscMLResources.cs:710`; producer `[UNVERIFIED]` | **ML** `[ERA]` |
| `DarkSapphire` | `1032690` | class `MiscMLResources.cs:575`; producer `[UNVERIFIED]` | **ML** `[ERA]` |
| `EcruCitrine` | `1032693` | class `MiscMLResources.cs:665`; producer `[UNVERIFIED]` | **ML** `[ERA]` |
| `BrilliantAmber` | `1032697` | class `MiscMLResources.cs:845`; producer `[UNVERIFIED]` | **ML** `[ERA]` |
| `PerfectEmerald` | `1032692` | class `MiscMLResources.cs:530`; producer `[UNVERIFIED]` | **ML** `[ERA]` |
| `Turquoise` | `1032691` | class `MiscMLResources.cs:620`; producer `[UNVERIFIED]` | **ML** `[ERA]` |
| `Tourmaline` | `1044237` | class `Scripts/Items/Resource/Tourmaline.cs:5`; producer `[UNVERIFIED]` | classic gem |
| `Amethyst` | `1044236` | class `Scripts/Items/Resource/Amethyst.cs:5`; producer `[UNVERIFIED]` | classic gem |
| `DreadHornMane` | `1032682` | `DreadHorn.cs:102` `c.DropItem(new DreadHornMane())`; class `MiscMLResources.cs:212` | **ML** `[ERA]` |
| `Putrefaction` | `1032678` | `BasePeerless.cs:276`, `Meraktus.cs:131`; class `MiscMLResources.cs:937` | **ML** `[ERA]` |
| `Muculent` | `1032680` / `1072139` | `BasePeerless.cs:282`, `Meraktus.cs:137`; class `MiscMLResources.cs:302` | **ML** `[ERA]` |
| `GrizzledBones` | `1032684` | `MonstrousInterredGrizzle.cs:107`; class `MiscMLResources.cs:437` | **ML** `[ERA]` |
| `Taint` | `1032679` / `1032684` (ColdForgedBlade row reuses GrizzledBones' cliloc) | `BasePeerless.cs:273`, `Meraktus.cs:128`; class `MiscMLResources.cs:983` | **ML** `[ERA]` |
| `Blight` | `1032675` / `1072134` | `BasePeerless.cs:267`, `Meraktus.cs:122`; class `MiscMLResources.cs:5` | **ML** `[ERA]` |
| `Scourge` | `1032677` / `1072136` | `BasePeerless.cs:270`, `Meraktus.cs:125`; class `MiscMLResources.cs:890` | **ML** `[ERA]` |
| `Corruption` | `1032676` / `1072135` | `BasePeerless.cs:279`, `Meraktus.cs:134`; class `MiscMLResources.cs:167` | **ML** `[ERA]` |
| `EyeOfTheTravesty` | `1073126` / `1032685` | `Travesty.cs:108`; class `MiscMLResources.cs:122` | **ML** `[ERA]` |
| `CapturedEssence` | `1032686` | `ShimmeringEffusion.cs:68`; class `MiscMLResources.cs:83` | **ML** `[ERA]` |
| `Bone` | `1049064` | class `Scripts/Items/Resource/Bone.cs:5`; producer line `[UNVERIFIED]` in this checkout (loot tables not traced) | classic |
| `Cloth` (used by Tessen/GargishTessen/Grapeshot) | `1044286` in blacksmithy, `1044455` in tailoring — **two different clilocs for the same type** | class `Scripts/Items/Resource/Cloth.cs:7`; from `BoltOfCloth` cut with scissors: `ScissorHelper(from, new Cloth(), 50)` (`BoltOfCloth.cs:72`) | classic |
| `Board` (cannon deeds) | `1044041` | class `Scripts/Items/Resource/Board.cs:123` | classic |
| `GlassSword` | `1095371` | class `Scripts/Items/Equipment/Weapons/GlassSword.cs:7` — consumed as a **resource** by `CrushedGlass`; the sword is itself a craftable/lootable weapon | **SA** `[ERA]` |
| `SmallPieceofBlackrock` | `1150016` | class `Scripts/Services/Revamped Dungeons/TheExodusEncounter/Resources/SmallPieceofBlackrock.cs:5` | **SA** `[ERA]` |
| `LeggingsOfBane` | `1061100` | class `Scripts/Items/Artifacts/Equipment/Armor/LeggingsOfBane.cs:5` (artifact used as ingredient) | **SA** `[ERA]` |
| `GauntletsOfNobility` | `1061092` | class `Scripts/Items/Artifacts/Equipment/Armor/GauntletsOfNobility.cs:5` | **SA** `[ERA]` |
| `BloodOfTheDarkFather` | `1157343` | class `Scripts/Items/Resource/BloodOfTheDarkFather.cs:5`; produced by `DemonKnight.cs:125/127/129` (`new BloodOfTheDarkFather(5|3|2)`) | **SA** `[ERA]` |

### 4b.5 Resource catalogue — Tailoring

| Resource class | cliloc as used | Where obtained | Era |
|---|---|---|---|
| `BoltOfCloth` | `1044453` | class `Scripts/Items/Resource/BoltOfCloth.cs:7`; created at a loom: yarn material consumed at `Phase >= 4` → `new BoltOfCloth()` (`YarnsAndThreads.cs:100-106`); also a starting item (`CharacterCreation.cs:1363`) | classic |
| `Cloth` | `1044455` (base) / `1044286` (Tessen in blacksmithy) | 1 bolt → 50 cloth via scissors (`BoltOfCloth.cs:72`); `CombineCloth` recipe re-stacks cloth by hue (`DefTailoring.cs:918-992`); recolor/merge routine `Cloth.cs:186-221` | classic |
| `UncutCloth` | — (produced, not consumed) | `CutUpCloth` action: `new UncutCloth(kvp.Value * 50)` (`DefTailoring.cs:891`); `CombineCloth`: `new UncutCloth(kvp.Value)` (`DefTailoring.cs:967`); class `Scripts/Items/Resource/UncutCloth.cs:7` | classic |
| `BlackPowder` | `1095826` | class `Scripts/Services/Expansions/High Seas/Items/Resources/BlackPowder.cs:6` | **HS** `[ERA]` |
| `CrystallineBlackrock` | `1077568` | class `Scripts/Items/Resource/CrystallineBlackrock.cs:5` | **SA** `[ERA]` |
| `Leather` | `1044462` (base) / `1049150` (sub-res) | Skinning with `HideType.Regular`: `leather = new Leather(hides)` when `cutHides`, else `new Hides(hides)` (`BaseCreature.cs:2229-2230`); if it does not fit in the pack it goes into the corpse with `500471` (`BaseCreature.cs:2246-2250`). Class `Scripts/Items/Resource/Leathers.cs:129` | classic |
| `SpinedLeather` | `1049151`, req `65.0` | `BaseCreature.cs:2233`; class `Leathers.cs:164` | classic (coloured leather) |
| `HornedLeather` | `1049152`, req `80.0` | `BaseCreature.cs:2237`; class `Leathers.cs:201` | classic |
| `BarbedLeather` | `1049153`, req `99.0` | `BaseCreature.cs:2241`; class `Leathers.cs:238` | classic |
| `Bone` | `1049064` | class `Bone.cs:5`; producer `[UNVERIFIED]` | classic |
| `FireRuby` | `1032695` | see blacksmithy table (`MiscMLResources.cs:755`) | **ML** `[ERA]` |
| `WhitePearl` | `1032694` | `MiscMLResources.cs:710` | **ML** `[ERA]` |
| `Blight` / `Corruption` | `1032675` / `1032676` | `MiscMLResources.cs:5` / `:167` | **ML** `[ERA]` |
| `EyeOfTheTravesty` | `1032685` | `Travesty.cs:108`; `MiscMLResources.cs:122` | **ML** `[ERA]` |
| `Putrefaction` / `Scourge` / `Muculent` | `1032678` / `1032677` / `1032680` | `BasePeerless.cs:276/270/282`; `MiscMLResources.cs:937/890/302` | **ML** `[ERA]` |
| `CapturedEssence` / `Taint` | `1032686` / `1032679` | `ShimmeringEffusion.cs:68` / `BasePeerless.cs:273`; `MiscMLResources.cs:83/983` | **ML** `[ERA]` |
| `SpoolOfThread` | `1073462` | class `Scripts/Items/Resource/YarnsAndThreads.cs:219`; from `Cotton.cs:33` `new SpoolOfThread(6)` and `Flax.cs:30` `new SpoolOfThread(6)` | **ML** `[ERA]` (ML recipe ingredient) |
| `Dyes` | `1024009` | class `Scripts/Items/Tools/Dyes.cs:7` | classic tool item |
| `GoldDust` | `1098337` | class `Scripts/Services/Revamped Dungeons/TheExodusEncounter/Resources/GoldDust.cs:5` | **SA** `[ERA]` |
| `AbyssalCloth` | `1113350` | class `Scripts/Items/Resource/AbyssalCloth.cs:7`; **itself craftable** in the Materials group (`DefTailoring.cs:214`) | **SA** `[ERA]` |
| `Lodestone` | `1113332` (×5 rows) / `1113348` (×10 rows) — **two clilocs, same type** | class `Scripts/Items/Decorative/Lodestone.cs:5` | **EJ** `[ERA]` |
| `FeyWings` | `1113332` | class `Scripts/Items/Resource/FeyWings.cs:5` | **EJ** `[ERA]` |
| `VileTentacles` | `1113333` | class `Scripts/Items/Resource/VileTentacles.cs:5`; produced by `MaddeningHorror.cs:61` `c.DropItem(new VileTentacles())` | **EJ** `[ERA]` |
| `VoidCore` | `1113334` | class `Scripts/Items/Resource/VoidCore.cs:5`; produced by `BaseVoidCreature.cs:189` and `Shame Revamped/Mobiles/Creatures.cs:1605` | **EJ** `[ERA]` |
| `TigerPelt` | `1123908` | class `Scripts/Services/Expansions/Time Of Legends/Items/Resources.cs:6`; produced via `WildTiger.GetPelt => new TigerPelt(4)` (`WildTiger.cs:13`) | **TOL** `[ERA]` |
| `DragonTurtleScute` | `1123910` | class `.../Time Of Legends/Items/Resources.cs:135`; `DragonTurtle.cs:74` `new DragonTurtleScute(18)`, `DragonTurtleHatchling.cs:81` `new DragonTurtleScute(4)` | **TOL** `[ERA]` |
| `CrimsonCincture` | `1075043` | class `Scripts/Items/Artifacts/Equipment/Clothing/CrimsonCincture.cs:7` (artifact used as ingredient) | **EJ** `[ERA]` |
| `LeurociansMempoOfFortune` | `1071460` | class `Scripts/Items/Artifacts/TOTLesserArtifacts.cs:975` (artifact used as ingredient) | **EJ** `[ERA]` |
| `MaceAndShieldGlasses` | `1073381` | class `Scripts/Items/Artifacts/Equipment/Glasses/CollectionsBritLibraryGlasses.cs:7` | **EJ** `[ERA]` |
| `TheScholarsHalo` | `1157354` | class `Scripts/Items/Artifacts/Equipment/Clothing/TheScholarsHalo.cs:5` | **EJ** `[ERA]` |
| `MidnightBracers` | `1061093` | class `Scripts/Items/Artifacts/Equipment/Armor/MidnightBracers.cs:5` | **SA** `[ERA]` |
| `BloodOfTheDarkFather` | `1157343` | `Scripts/Items/Resource/BloodOfTheDarkFather.cs:5`; `DemonKnight.cs:125` | **SA** `[ERA]` |
| `DarkSapphire` | `1032690` | `MiscMLResources.cs:575` | **ML** `[ERA]` |

> Consistency note: `Lodestone` is passed as `1113332` in the `MaceBelt`/`SwordBelt`/`DaggerBelt`
> rows (L467/472/477) but as `1113348` in the four 120-skill rows (L488/495/502/509). Two different
> name clilocs for one C# type in the same group. `[SRC]`

---

### 4b.6 Recipe-gated entries (`AddRecipe` → `CraftItem.Recipe`, requires a recipe scroll)

| System | Item | Recipe id | Enum name | `AddRecipe` line |
|---|---|---|---|---|
| Smith | `BritchesOfWarding` | 355 | `SmithRecipes.BritchesOfWarding` | `DefBlacksmithy.cs:363` |
| Smith | `RuneCarvingKnife` | 350 | `SmithRecipes.RuneCarvingKnife` | `DefBlacksmithy.cs:499` |
| Smith | `ColdForgedBlade` | 351 | `SmithRecipes.ColdForgedBlade` | `DefBlacksmithy.cs:506` |
| Smith | `OverseerSunderedBlade` | 352 | `SmithRecipes.OverseerSunderedBlade` | `DefBlacksmithy.cs:513` |
| Smith | `LuminousRuneBlade` | 353 | `SmithRecipes.LuminousRuneBlade` | `DefBlacksmithy.cs:520` |
| Smith | `TrueSpellblade` | 300 | `SmithRecipes.TrueSpellblade` | `DefBlacksmithy.cs:525` |
| Smith | `IcySpellblade` | 301 | `SmithRecipes.IcySpellblade` | `DefBlacksmithy.cs:529` |
| Smith | `FierySpellblade` | 302 | `SmithRecipes.FierySpellblade` | `DefBlacksmithy.cs:533` |
| Smith | `SpellbladeOfDefense` | 303 | `SmithRecipes.SpellbladeOfDefense` | `DefBlacksmithy.cs:537` |
| Smith | `TrueAssassinSpike` | 304 | `SmithRecipes.TrueAssassinSpike` | `DefBlacksmithy.cs:541` |
| Smith | `ChargedAssassinSpike` | 305 | `SmithRecipes.ChargedAssassinSpike` | `DefBlacksmithy.cs:545` |
| Smith | `MagekillerAssassinSpike` | 306 | `SmithRecipes.MagekillerAssassinSpike` | `DefBlacksmithy.cs:549` |
| Smith | `WoundingAssassinSpike` | 307 | `SmithRecipes.WoundingAssassinSpike` | `DefBlacksmithy.cs:553` |
| Smith | `TrueLeafblade` | 308 | `SmithRecipes.TrueLeafblade` | `DefBlacksmithy.cs:557` |
| Smith | `Luckblade` | 309 | `SmithRecipes.Luckblade` | `DefBlacksmithy.cs:561` |
| Smith | `MagekillerLeafblade` | 310 | `SmithRecipes.MagekillerLeafblade` | `DefBlacksmithy.cs:565` |
| Smith | `LeafbladeOfEase` | 311 | `SmithRecipes.LeafbladeOfEase` | `DefBlacksmithy.cs:569` |
| Smith | `KnightsWarCleaver` | 312 | `SmithRecipes.KnightsWarCleaver` | `DefBlacksmithy.cs:573` |
| Smith | `ButchersWarCleaver` | 313 | `SmithRecipes.ButchersWarCleaver` | `DefBlacksmithy.cs:577` |
| Smith | `SerratedWarCleaver` | 314 | `SmithRecipes.SerratedWarCleaver` | `DefBlacksmithy.cs:581` |
| Smith | `TrueWarCleaver` | 315 | `SmithRecipes.TrueWarCleaver` | `DefBlacksmithy.cs:585` |
| Smith | `AdventurersMachete` | 316 | `SmithRecipes.AdventurersMachete` | `DefBlacksmithy.cs:589` |
| Smith | `OrcishMachete` | 317 | `SmithRecipes.OrcishMachete` | `DefBlacksmithy.cs:593` |
| Smith | `MacheteOfDefense` | 318 | `SmithRecipes.MacheteOfDefense` | `DefBlacksmithy.cs:597` |
| Smith | `DiseasedMachete` | 319 | `SmithRecipes.DiseasedMachete` | `DefBlacksmithy.cs:601` |
| Smith | `Runesabre` | 320 | `SmithRecipes.Runesabre` | `DefBlacksmithy.cs:605` |
| Smith | `MagesRuneBlade` | 321 | `SmithRecipes.MagesRuneBlade` | `DefBlacksmithy.cs:609` |
| Smith | `RuneBladeOfKnowledge` | 322 | `SmithRecipes.RuneBladeOfKnowledge` | `DefBlacksmithy.cs:613` |
| Smith | `CorruptedRuneBlade` | 323 | `SmithRecipes.CorruptedRuneBlade` | `DefBlacksmithy.cs:617` |
| Smith | `TrueRadiantScimitar` | 324 | `SmithRecipes.TrueRadiantScimitar` | `DefBlacksmithy.cs:621` |
| Smith | `DarkglowScimitar` | 325 | `SmithRecipes.DarkglowScimitar` | `DefBlacksmithy.cs:625` |
| Smith | `IcyScimitar` | 326 | `SmithRecipes.IcyScimitar` | `DefBlacksmithy.cs:629` |
| Smith | `TwinklingScimitar` | 327 | `SmithRecipes.TwinklingScimitar` | `DefBlacksmithy.cs:633` |
| Smith | `BoneMachete` | 336 | `SmithRecipes.BoneMachete` | `DefBlacksmithy.cs:637` |
| Smith | `GuardianAxe` | 328 | `SmithRecipes.GuardianAxe` | `DefBlacksmithy.cs:684` |
| Smith | `SingingAxe` | 329 | `SmithRecipes.SingingAxe` | `DefBlacksmithy.cs:688` |
| Smith | `ThunderingAxe` | 330 | `SmithRecipes.ThunderingAxe` | `DefBlacksmithy.cs:692` |
| Smith | `HeavyOrnateAxe` | 331 | `SmithRecipes.HeavyOrnateAxe` | `DefBlacksmithy.cs:696` |
| Smith | `ShardThrasher` | 354 | `SmithRecipes.ShardTrasher` | `DefBlacksmithy.cs:799` |
| Smith | `RubyMace` | 332 | `SmithRecipes.RubyMace` | `DefBlacksmithy.cs:804` |
| Smith | `EmeraldMace` | 333 | `SmithRecipes.EmeraldMace` | `DefBlacksmithy.cs:808` |
| Smith | `SapphireMace` | 334 | `SmithRecipes.SapphireMace` | `DefBlacksmithy.cs:812` |
| Smith | `SilverEtchedMace` | 335 | `SmithRecipes.SilverEtchedMace` | `DefBlacksmithy.cs:816` |
| Smith | `GlovesOfFeudalGrip` | 356 | `SmithRecipes.GlovesOfFeudalGrip` | `DefBlacksmithy.cs:934` |
| Tailor | `ChefsToque` | 561 | `TailorRecipe.ChefsToque` | `DefTailoring.cs:255` |
| Tailor | `KrampusMinionHat` | 586 | `TailorRecipe.KrampusMinionHat` | `DefTailoring.cs:259` |
| Tailor | `AssassinsCowl` | 1108 | `TailorRecipe.AssassinsCowl` | `DefTailoring.cs:266` |
| Tailor | `MagesHood` | 1109 | `TailorRecipe.MagesHood` | `DefTailoring.cs:271` |
| Tailor | `CowlOfTheMaceAndShield` | 1110 | `TailorRecipe.CowlOfTheMaceAndShield` | `DefTailoring.cs:277` |
| Tailor | `MagesHoodOfScholarlyInsight` | 1111 | `TailorRecipe.MagesHoodOfScholarlyInsight` | `DefTailoring.cs:284` |
| Tailor | `GuildedKilt` | 562 | `TailorRecipe.GuildedKilt` | `DefTailoring.cs:377` |
| Tailor | `CheckeredKilt` | 563 | `TailorRecipe.CheckeredKilt` | `DefTailoring.cs:380` |
| Tailor | `FancyKilt` | 564 | `TailorRecipe.FancyKilt` | `DefTailoring.cs:383` |
| Tailor | `FloweredDress` | 565 | `TailorRecipe.FloweredDress` | `DefTailoring.cs:386` |
| Tailor | `EveningGown` | 566 | `TailorRecipe.EveningGown` | `DefTailoring.cs:389` |
| Tailor | `ElvenQuiver` | 501 | `TailorRecipe.ElvenQuiver` | `DefTailoring.cs:408` |
| Tailor | `QuiverOfFire` | 502 | `TailorRecipe.QuiverOfFire` | `DefTailoring.cs:412` |
| Tailor | `QuiverOfIce` | 503 | `TailorRecipe.QuiverOfIce` | `DefTailoring.cs:416` |
| Tailor | `QuiverOfBlight` | 504 | `TailorRecipe.QuiverOfBlight` | `DefTailoring.cs:420` |
| Tailor | `QuiverOfLightning` | 505 | `TailorRecipe.QuiverOfLightning` | `DefTailoring.cs:424` |
| Tailor | `MaceBelt` | 1100 | `TailorRecipe.MaceBelt` | `DefTailoring.cs:468` |
| Tailor | `SwordBelt` | 1101 | `TailorRecipe.SwordBelt` | `DefTailoring.cs:473` |
| Tailor | `DaggerBelt` | 1102 | `TailorRecipe.DaggerBelt` | `DefTailoring.cs:478` |
| Tailor | `ElegantCollar` | 1103 | `TailorRecipe.ElegantCollar` | `DefTailoring.cs:483` |
| Tailor | `CrimsonMaceBelt` | 1104 | `TailorRecipe.CrimsonMaceBelt` | `DefTailoring.cs:489` |
| Tailor | `CrimsonSwordBelt` | 1105 | `TailorRecipe.CrimsonSwordBelt` | `DefTailoring.cs:496` |
| Tailor | `CrimsonDaggerBelt` | 1106 | `TailorRecipe.CrimsonDaggerBelt` | `DefTailoring.cs:503` |
| Tailor | `ElegantCollarOfFortune` | 1107 | `TailorRecipe.ElegantCollarOfFortune` | `DefTailoring.cs:510` |
| Tailor | `JesterShoes` | 560 | `TailorRecipe.JesterShoes` | `DefTailoring.cs:551` |
| Tailor | `KrampusMinionBoots` | 587 | `TailorRecipe.KrampusMinionBoots` | `DefTailoring.cs:557` |
| Tailor | `KrampusMinionTalons` | 588 | `TailorRecipe.KrampusMinionTalons` | `DefTailoring.cs:561` |
| Tailor | `SpellWovenBritches` | 551 | `TailorRecipe.SpellWovenBritches` | `DefTailoring.cs:574` |
| Tailor | `SongWovenMantle` | 550 | `TailorRecipe.SongWovenMantle` | `DefTailoring.cs:581` |
| Tailor | `StitchersMittens` | 552 | `TailorRecipe.StitchersMittens` | `DefTailoring.cs:588` |
| Tailor | `TigerPeltChest` | 570 | `TailorRecipe.TigerPeltChest` | `DefTailoring.cs:670` |
| Tailor | `TigerPeltLegs` | 573 | `TailorRecipe.TigerPeltLegs` | `DefTailoring.cs:674` |
| Tailor | `TigerPeltShorts` | 574 | `TailorRecipe.TigerPeltShorts` | `DefTailoring.cs:678` |
| Tailor | `TigerPeltHelm` | 572 | `TailorRecipe.TigerPeltHelm` | `DefTailoring.cs:682` |
| Tailor | `TigerPeltCollar` | 571 | `TailorRecipe.TigerPeltCollar` | `DefTailoring.cs:686` |
| Tailor | `DragonTurtleHideChest` | 581 | `TailorRecipe.DragonTurtleHideChest` | `DefTailoring.cs:690` |
| Tailor | `DragonTurtleHideLegs` | 583 | `TailorRecipe.DragonTurtleHideLegs` | `DefTailoring.cs:694` |
| Tailor | `DragonTurtleHideHelm` | 582 | `TailorRecipe.DragonTurtleHideHelm` | `DefTailoring.cs:698` |
| Tailor | `DragonTurtleHideArms` | 580 | `TailorRecipe.DragonTurtleHideArms` | `DefTailoring.cs:702` |
| Tailor | `TigerPeltBustier` | 575 | `TailorRecipe.TigerPeltBustier` | `DefTailoring.cs:781` |
| Tailor | `TigerPeltLongSkirt` | 576 | `TailorRecipe.TigerPeltLongSkirt` | `DefTailoring.cs:785` |
| Tailor | `TigerPeltSkirt` | 577 | `TailorRecipe.TigerPeltSkirt` | `DefTailoring.cs:789` |
| Tailor | `DragonTurtleHideBustier` | 584 | `TailorRecipe.DragonTurtleHideBustier` | `DefTailoring.cs:793` |
| Tailor | `CuffsOfTheArchmage` | 585 | `TailorRecipe.CuffsOfTheArchmage` | `DefTailoring.cs:825` |

**Totals: 44 recipe-gated blacksmithy rows (`AddRecipe(index` count = 44) and 44 recipe-gated
tailoring rows (`AddRecipe(index` count = 44) = 88 recipe-gated entries total.**
Of the tailoring ids, `570–577` and `580–584` (TOL pelt/hide sets) and `1100–1111` (EJ items) are
only reachable when `Core.TOL` / `Core.EJ`; `586–588` (`KrampusMinion*`) are **ungated** but
require the recipe. `[SRC]`

Enforcement: `if (Recipe == null || !(from is PlayerMobile) || ((PlayerMobile)from).HasRecipe(Recipe))`
else cliloc `1072847` — "You must learn that recipe from a scroll." `CraftItem.cs:1463-1464, 1537`.
`Recipe` registration itself: `CraftSystem.AddRecipe(int index, int id)` → `CraftItem.AddRecipe(id, system)`
→ `new Recipe(id, system, this)` (`CraftSystem.cs:524-528`, `CraftItem.cs:94-104`, `Recipes.cs:8-20`).

---

### 4b.7 Era gating — every `[ERA]` line

The gates are literal `Core.<Flag>` checks. `Core.X` is true when the shard's `Expansion` value is
`>=` that expansion, so gates are **cumulative** (`Server/Main.cs:141-154`, enum order
`None, T2A, UOR, UOTD, LBR, AOS, SE, ML, SA, HS, TOL, EJ` at `Server/ExpansionInfo.cs:7-21`).

Counts below were produced by a brace-depth scan of both files (each `AddCraft` attributed to
its **innermost** enclosing `if (Core.X)` block), then manually corrected for the three
**brace-less single-statement gates** in `DefTailoring.cs` (L235→L236, L331→L332, L525→L526).

| `Core.` flag | Enum value | `ExpansionInfo` name | Release date `[WEB]` | Blacksmithy rows (innermost) | Tailoring rows (innermost) |
|---|---|---|---|---|---|
| `Core.AOS` | 5 | Age of Shadows | 2003-02-11 ([UOGuide](https://www.uoguide.com/Expansion)) | **11** — L321, L419, L420, L443, L450, L718, L723, L730, L735, L742, L776 | **6** — L306, L307, L308 (braced) + L236, L332, L526 (brace-less `if`) |
| `Core.SE` | 6 | Samurai Empire | 2004-11-02 ([UOGuide](https://www.uoguide.com/Expansion)) | **22** — L326, L328, L331, L333, L335, L379, L381, L383, L385, L387, L389, L391, L393, L463, L465, L467, L469, L471, L473, L475, L477, L784 | **37** — L240, L242, L313, L315, L317, L319, L321, L323, L336, L338, L402, L446, L448, L450, L452, L454, L456, L458, L460, L530, L532, L602, L604, L606, L608, L610, L612, L614, L616, L618, L620, L622, L740, L742, L744, L746, L748 |
| `Core.ML` | 7 | Mondain's Legacy | 2005-08-30 ([UOGuide](https://www.uoguide.com/Expansion)) | **54** — L397, L399, L401, L481, L483, L485, L487, L489, L491, L493, L495, L502, L509, L516, L523, L527, L531, L535, L539, L543, L547, L551, L555, L559, L563, L567, L571, L575, L579, L583, L587, L591, L595, L599, L603, L607, L611, L615, L619, L623, L627, L631, L635, L680, L682, L686, L690, L694, L793, L795, L802, L806, L810, L814 | **27** — L344, L346, L348, L350, L352, L354, L407, L410, L414, L418, L422, L427, L521, L570, L577, L584, L628, L630, L632, L634, L636, L638, L754, L756, L758, L760, L762 |
| `Core.SA` | 8 | Stygian Abyss | 2009-09-08 ([UOGuide](https://www.uoguide.com/Expansion)) | **46** — L341, L343, L345, L347, L349, L351, L353, L355, L357, L359, L425, L427, L429, L431, L433, L435, L645, L647, L649, L651, L653, L655, L657, L659, L661, L663, L702, L704, L706, L752, L754, L756, L758, L760, L762, L824, L826, L828, L832, L884, L886, L888, L912, L915, L923, L929 | **26** — L214, L361, L363, L365, L437, L438, L543, L645, L647, L649, L651, L653, L655, L657, L659, L661, L711, L713, L715, L717, L719, L721, L723, L725, L727, L820 |
| `Core.HS` (whole block, incl. nested) | 9 | High Seas | 2010-10-12 ([UOGuide](https://www.uoguide.com/Expansion)) | **8** — L845, L850, L851, L856, L862, L865, L869, L873 | **3** — L198, L204, L207 |
| …of which `Core.EJ` branch | 11 | Endless Journey | 2018-04 ([RPGSite](https://www.rpgsite.net/news/7090-ultima-online-endless-journey-lets-new-and-old-players-try-the-game-for-free)) | **2** — L845 (`Cannonball`, ×12 + `useAllRes`), L856 (`Grapeshot`, ×12 + `Cloth`×2 + `useAllRes`) | **1** — L198 (`PowderCharge`, `BlackPowder`×4 + `useAllRes`) |
| …of which non-EJ `else` branch | — | — | — | **4** — L850, L851 (light/heavy cannonball), L862, L865 (light/heavy grapeshot) | **2** — L204 (`LightPowderCharge`, `BlackPowder`×1), L207 (`HeavyPowderCharge`, `BlackPowder`×4) |
| …of which plain `Core.HS` (no inner test) | — | — | — | **2** — L869, L873 (ship cannon deeds) | **0** |
| `Core.EJ` outside the HS block | 11 | Endless Journey | 2018-04 | **0** | **12** — L263, L268, L273, L280, L465, L470, L475, L480, L485, L492, L499, L506 |
| `Core.TOL` | 10 | Time of Legends | 2015-10-09 ([UOGuide](https://www.uoguide.com/Expansion)) | **0** | **20** — L254, L376, L379, L382, L385, L388, L550, L668, L672, L676, L680, L684, L688, L692, L696, L700, L779, L783, L787, L791 |
| **no gate at all** (top level of `InitCraftList`) | — | — | — | **55** | **67** |

**Nesting that matters:**

| Nesting | Rows | Note |
|---|---|---|
| Blacksmithy `Core.SE` → `Core.ML` | **44** ML rows sit inside an SE block: L397, L399, L401 (Helmets, `if (Core.SE)` L377 → `if (Core.ML)` L395) and L481…L635 (Bladed, `if (Core.SE)` L461 → `if (Core.ML)` L479) | so the *enclosing* SE count for blacksmithy is `22 + 44 = 66` |
| Tailoring `Core.HS` → `Core.EJ` | L198 | only tailoring row nested inside another gate |
| Blacksmithy `Core.HS` → `Core.EJ`/`else` | L845, L856 / L850, L851, L862, L865 | see the HS rows above |

Arithmetic check: `55 + 11 + 22 + 54 + 46 + 2 + 4 + 2 = 196` (blacksmithy) and
`67 + 6 + 37 + 27 + 26 + 20 + 1 + 2 + 12 = 198` (tailoring). `[SRC]`

> **Era reference conflict.** The shared brief gives "SE (2005)" and "ML (2007)". UOGuide dates
> Samurai Empire to **2004-11-02** and Mondain's Legacy to **2005-08-30**; the 2007 date belongs to
> *Kingdom Reborn* (2007-06-27). ServUO's own `ExpansionInfo` table lists
> `"Samurai Empire"` before `"Mondain's Legacy"` and gives ML the client version `5.0.0a`
> (`ExpansionInfo.cs:203-216`). Use 2004/2005 unless the deliverable deliberately follows the brief.
> `[SRC+WEB]`
>
> `Core.EJ` is **not** an expansion in the retail sense — ServUO models the 2018 Endless Journey
> free-to-play account tier as `Expansion.EJ`, the *highest* enum value. Because the checks are
> cumulative, `Core.EJ == true` implies every earlier flag is true; this is why the `Core.HS`
> blocks can safely test `Core.EJ` to choose the newer recipe set. `[SRC]`
>
> Era coins for the ingot/leather/scale sub-resources are **not** gated in source at all: the
> coloured ingots, six scale types and four leather types are always registered; only the
> `RequiredSkill` on the sub-resource gates them (`DefBlacksmithy.cs:945-962`,
> `DefTailoring.cs:834-837`). `[SRC]`

---

### 4b.8 Non-`AddCraft` menu behaviour worth porting

| Behaviour | Literal | Source |
|---|---|---|
| `CutUpCloth` action (group `1044457`, cliloc `1044458`) | not a normal craft: deletes every `BoltOfCloth` in the pack, groups by `Hue`, then `new UncutCloth(kvp.Value * 50)` per hue, hue preserved; `tool.UsesRemaining--`; on empty pack → `1044253` | `DefTailoring.cs:188-189, 845-916` |
| `CombineCloth` action (cliloc `1044459`) | consumes every `UncutCloth`/`Cloth`/`CutUpCloth`, groups by hue, re-issues one `new UncutCloth(kvp.Value)` per hue; **note: it re-emits `UncutCloth`, not `Cloth`** | `DefTailoring.cs:191-192, 918-992` |
| Drop target for both actions | if the tool's parent is a container, try that container first, else the backpack (`DropItem`) | `DefTailoring.cs:994-1012` |
| `CutUpCloth`/`CombineCloth` both use `minSkill = 0.0, maxSkill = 0.0` and still consume a tool use | `L188`, `L191` | `[SRC]` |
| Blacksmithy "resmelt" | `Resmelt = true` | `DefBlacksmithy.cs:964` |
| Blacksmithy repair | `Repair = true` | `DefBlacksmithy.cs:965` |
| Tailoring repair | `Repair = Core.AOS` → off before AoS | `DefTailoring.cs:840` |
| Enhancer availability | blacksmithy `CanEnhance = Core.AOS`; tailoring `CanEnhance = Core.ML` | `DefBlacksmithy.cs:967`; `DefTailoring.cs:841` |
| Alter (alter-contract) availability | both `CanAlter = Core.SA` | `DefBlacksmithy.cs:968`; `DefTailoring.cs:842` |
| Tailoring hue retention | `RetainsColorFrom` returns true only for `Cloth`/`UncutCloth`/`AbyssalCloth` **and** only for the 8 Goza-mat deed types in `m_TailorColorables` | `DefTailoring.cs:129-150` |
| Blacksmithy `ToolBroken` text | `1044038` "You have worn out your tool" | `DefBlacksmithy.cs:244-247` |
| Failure texts (both) | lost material → `1044043`; no material lost → `1044157`; quality 0 → `502785`; exceptional + mark → `1044156`; exceptional → `1044155`; normal → `1044154` | `DefBlacksmithy.cs:249-274`; `DefTailoring.cs:157-180` `[SRC]` |
| `AncientSmithyHammer` extra wear | when crafting in `DefBlacksmithy`, a *second* smith hammer on `Layer.OneHanded` also loses a use; `HammerOfHephaestus` is moved to the pack at 0 uses instead of being deleted | `CraftItem.cs:1711-1740` |

---

### 4b.9 Divergences: ServUO `pub57` vs ModernUO `main`

Read from `Projects/UOContent/Engines/Craft/DefBlacksmithy.cs` and `DefTailoring.cs`
([ModernUO](https://github.com/modernuo/ModernUO/tree/main/Projects/UOContent/Engines/Craft)).

| Aspect | ServUO pub57 | ModernUO main | Verdict |
|---|---|---|---|
| Blacksmithy group for plate/ringmail/chainmail | `1111704` for **all** of Metal Armor | `1011076` Ringmail, `1011077` Chainmail, `1011078` Platemail/SE/SA plate (`DefBlacksmithy.cs:187-224`) | **real divergence** — different gump grouping |
| Blacksmithy group for dragon scale armour | `1011173` (Miscellaneous, shared with MetalKeg etc.) | `1053114` (own group, `DefBlacksmithy.cs:655-667`) | **real divergence** |
| Tailoring group for shirts/pants | `1111747` for Shirts **and** Pants | `1015269` for shirts/robes, `1015279` for pants (`DefTailoring.cs:143-201`) | **real divergence** |
| Blacksmithy `GetChanceAtMin` | `0.0`, except `0.05` for `BritchesOfWarding`/`GlovesOfFeudalGrip` | always `0.0` (`DefBlacksmithy.cs:28`) | ModernUO drops the 5 % special case |
| Tailoring `GetChanceAtMin` | `0.5`, except `0.05` for 7 clilocs | always `0.5` (`DefTailoring.cs:33`) | ModernUO drops the 5 % special case |
| Blacksmithy `AddCraft` rows | **196** | **144** (grep count) — no HS cannon block, no SA gargish plate/shield/axe/polearm/throwing block, no TOL/EJ rows | counts diverge; the ingot `AddSubRes` block is **identical** (`L687-695` vs ServUO `L945-953`) |
| Tailoring `AddCraft` rows | **198** | **102** (grep count) | large content divergence |
| `DiamondMace` name cliloc | `1031568` (`DefBlacksmithy.cs:793`) | `1031556` (`DefBlacksmithy.cs:623`) | **numeric divergence** |
| `Cloth` name cliloc in tailoring | `1044455` | `1044286` (e.g. `DefTailoring.cs:116`) | **literal value divergence** |
| Tailoring `CanEnhance` | `Core.ML` | `Core.AOS` (`DefTailoring.cs:676`) | divergence |
| ECA enum spelling | `ChanceMinusSixtyToFourtyFive` (typo in ServUO) | `ChanceMinusSixtyToFortyFive` | cosmetic |
| `GumpTitleNumber` | `1044002` / `1044005` | `GumpTitle { get; } = 1044002` / `= 1044005` (`// Tailoring Menu`) | identical values, different property name |
| Blacksmithy `PlateDo` skill | `80.0 / 130.0` (`DefBlacksmithy.cs:328`) | `87.0 / 137.0` (`DefBlacksmithy.cs:215`) | **numeric divergence** |
| Gargish leather/studded entries | 8+ typed `Gargish…` / `FemaleGargish…` classes | `…Type1` / `…Type2` class pairs with different clilocs (`1020769`, `1020770`, …) | structural divergence |
| Tailoring `BoltOfCloth` as a craftable | not in the menu (only via `CutUpCloth`) | `AddCraft(typeof(BoltOfCloth), 1015283, 1044286, 0.0, 25.0, typeof(Cloth), 1044286, 50, 1044287)` (`DefTailoring.cs:670`) | divergence |

---

### 4b.10 Gaps / what is not verifiable from these sources

| Gap | Why | What would resolve it |
|---|---|---|
| English text of every item/group cliloc (e.g. `1025099`, `1111704`, `1044455`) | cliloc tables are client data; no `cliloc.*` file exists anywhere in the three checkouts (verified by glob `**/*cliloc*`: only `classicuo/src/ClassicUO.Assets/ClilocLoader.cs`) | ship `Cliloc.enu` and resolve ids, or read them from the ClassicUO client at runtime |
| Whether `1044455` vs `1044286` vs `1044287` vs `1044253` vs `1044463` are semantically different "cloth/leather" strings | ids only, no strings | same as above |
| "Where obtained" for `BlueDiamond`, `FireRuby`, `WhitePearl`, `DarkSapphire`, `EcruCitrine`, `BrilliantAmber`, `PerfectEmerald`, `Turquoise`, `Bone` | only `TestCenter.cs` spawns them in this checkout; the real ML/Doom loot tables were not traced in this pass | read the creature loot packs under `Scripts/Mobiles/Monsters/ML/**` and `Scripts/Items/Resource/*` spawners |
| Retail-accurate min-skill/max-skill per item | the numbers here are **ServUO's** values; they are the ones a ServUO-like clone must reproduce, not necessarily OSI's | compare against a live shard / OSI-era data |
| `WarHammer` amount (`×16`, not `×14`) | verified twice: `DefBlacksmithy.cs:780` and the doc row 4b.2.7 #6 | resolved |
| `KrampusMinion*` era | the three rows sit inside the `#region Mondain's Legacy` block (`DefTailoring.cs:251`, `558`) but carry **no** `Core.*` check and a `100.0 / 500.0` skill band | Krampus is a *Treasures of Tokuno / Krampus* seasonal event; would need the event source or a patch note |
| `MaleElvenRobe`/`FemaleElvenRobe` etc. "ML" vs the `Core.ML` flag | source comment says Mondain's Legacy but the gate is `Core.ML`, and the brief's era table assigns ML to 2007 | resolved as 2005 by UOGuide; flagged in 4b.7 |

**Row-count reconciliation (must match the file):**

| File | `grep -c "AddCraft(typeof"` | Rows transcribed here | Sum of group tables |
|---|---|---|---|
| `DefBlacksmithy.cs` | 196 | 196 | 29+16+14+68+15+16+17+8+3+10 = 196 |
| `DefTailoring.cs` | 198 | 198 | 6+26+40+29+12+44+9+15+10+7 = 198 |
| **both** | **394** | **394** | **394** |

## 4c. Crafting menus — Carpentry, Tinkering, Fletching, Glassblowing

Transcribed from the ServUO `pub57` checkout at `.research-src/servuo`. Every `AddCraft` call in the four
system files is listed below; nothing is summarised away. Numbers are copied verbatim from source
(no rounding, no inference). Row counts and first/last line numbers are per craft **group**.

### 4c.0 Citation bases and call semantics

| Purpose | Path (ServUO = `https://github.com/ServUO/ServUO/blob/pub57/`) |
|---|---|
| Carpentry menu | `Scripts/Services/Craft/DefCarpentry.cs` |
| Tinkering menu | `Scripts/Services/Craft/DefTinkering.cs` |
| Bowcraft/Fletching menu | `Scripts/Services/Craft/DefBowFletching.cs` |
| Glassblowing menu | `Scripts/Services/Craft/DefGlassblowing.cs` |
| Craft framework | `Scripts/Services/Craft/Core/{CraftSystem,CraftItem,CraftGroup,CraftRes,CraftSubRes,CraftSkill,CraftGump,CraftGumpItem,CraftContext}.cs` |
| Sand harvest | `Scripts/Services/Harvest/Mining.cs` |
| Tools | `Scripts/Items/Tools/*.cs`, `Scripts/Items/Equipment/Weapons/{Hatchet,Pickaxe}.cs`, `Scripts/Items/Consumables/LockPick.cs` |
| Books/vendor | `Scripts/Items/Consumables/{GlassblowingBook,SandMiningBook}.cs`, `Scripts/VendorInfo/SBGlassblower.cs` |

`AddCraft` overloads (`CraftSystem.cs:329-352`) — argument order used by all four systems:

```
AddCraft(typeItem, group, name, minSkill, maxSkill, typeRes, nameRes, amount)              // :329
AddCraft(typeItem, group, name, minSkill, maxSkill, typeRes, nameRes, amount, message)     // :334
AddCraft(typeItem, group, name, skillToMake, minSkill, maxSkill, typeRes, nameRes, amount) // :339
AddCraft(typeItem, group, name, skillToMake, minSkill, maxSkill, typeRes, nameRes, amount, message) // :344
```

* `group` and `name` are `TextDefinition` → in these files always **cliloc numbers** (the client renders the
  localised string). The tables below therefore show the cliloc ID as "display"; no name is invented.
* `typeRes/nameRes/amount/message` become the **first** `CraftRes` (`CraftSystem.cs:346-347`); further
  resources are appended with `AddRes(index, type, name, amount, message)` (`CraftSystem.cs:495-504`).
* `CraftItem` keeps `CraftResCol Resources` and `CraftSkillCol Skills`; `AddSkill` adds a secondary
  skill requirement (`CraftItem.cs:133`, `CraftSystem.cs:512`). `CraftSkill` = `{SkillToMake, MinSkill, MaxSkill}` (`CraftSkill.cs:5-37`).
* Success chance `[SRC]` (`CraftItem.cs:1367-1438`):
  `chance = GetChanceAtMin + ((valMainSkill - (MinSkill-MinSkillOffset)) / (MaxSkill - (MinSkill-MinSkillOffset))) * (1 - GetChanceAtMin)`
  when **all** required skills are met, else `chance = 0`; then `+ talisman.SuccessBonus/100`, `+0.5` if
  `WoodworkersBench.HasBonus`, and forced to `1.0` when `valMainSkill == maxMainSkill`.
  `ForceSuccessChance` (from `SetForceSuccess`) short-circuits to `value/100`.
* Exceptional chance `[SRC]` (`CraftItem.cs:1268-1341`): `0.0` if `ForceNonExceptional`; otherwise `chance`
  shifted by the system `ECA`: `ChanceMinusSixty` → `chance-0.6`; `FiftyPercentChanceMinusTenPercent` →
  `chance*0.5-0.1`; `ChanceMinusSixtyToFourtyFive` → `chance - clamp(0.60-((skill-95.0)*0.03), 0.45, 0.60)`.
  Exceptional is rolled when the shifted value `> Utility.RandomDouble()` (`CraftItem.cs:1354`).
* `SetUseAllRes(index, true)` (`CraftSystem.cs:394`) = stackable batch craft: `maxAmount = min over resources
  of (packAmount / resAmount)` (`CraftItem.cs:992-1020`) and the produced item gets `Amount = maxAmount`
  (or `UsesRemaining *= maxAmount` for non-stackable `IUsesRemaining`, `CraftItem.cs:1842-1851`).
  Gump label for such rows: 1048176 "Makes as many as possible at once" (`CraftGumpItem.cs:89-90`);
  buttons "MAKE NUMBER" 1112623 / "MAKE MAX" 1112624 (`CraftGumpItem.cs:75-78`).
* Era gating: `Core.AOS/SE/ML/SA/HS/TOL/EJ` are `Expansion >= Expansion.X` (`Server/Main.cs:143-153`),
  enum order `None,T2A,UOR,UOTD,LBR,AOS,SE,ML,SA,HS,TOL,EJ` (`Server/ExpansionInfo.cs:7-21`).
  Theme packs `None,Kings,Rustic,Gothic` (`Server/ExpansionInfo.cs:23-29`).

---

### 4c.1 Carpentry — `DefCarpentry`

| Property | Value | Source |
|---|---|---|
| System class / singleton | `DefCarpentry` / `DefCarpentry.CraftSystem` | `DefCarpentry.cs:42,70-79` |
| Primary skill | `SkillName.Carpentry` | `DefCarpentry.cs:44-50` |
| Secondary skills referenced | `Tailoring`, `Musicianship`, `Magery`, `Tinkering`, `Blacksmith`, `Imbuing` (per-item via `AddSkill`) | `DefCarpentry.cs:160,171,573,716,797,934` |
| Min skill / max skill present | `0.0` / `125.0` (PentagramDeed, AbbatoirDeed) | `DefCarpentry.cs:186,715` |
| Effect timing | `base(1, 1, 1.25)` → MinCraftEffect 1, MaxCraftEffect 1, Delay 1.25 s (comment: `// base( 1, 1, 3.0 )`) | `DefCarpentry.cs:86-89` |
| `GetChanceAtMin` | `0.5` (50 %) for every item | `DefCarpentry.cs:81-84` |
| `ECA` | `ChanceMinusSixtyToFourtyFive` | `DefCarpentry.cs:60-66` |
| Gump title | cliloc `1044004` `// <CENTER>CARPENTRY MENU</CENTER>` | `DefCarpentry.cs:52-58` |
| `CanCraft` preconditions | tool non-null, not deleted, `UsesRemaining > 0`, `CheckAccessible` (tool must be on person/pack). No forge/anvil/proximity check. | `DefCarpentry.cs:91-101` |
| Craft sound | `0x23D` (no animation; animation code commented out) | `DefCarpentry.cs:103-109` |
| Tool family (`CraftSystem` property) | `Saw, DovetailSaw, DrawKnife, Froe, Inshave, JointingPlane, MouldingPlane, Scorp, SmoothingPlane, Hammer, Nails` → all `DefCarpentry.CraftSystem` | `Saw.cs:32`, `DovetailSaw.cs:32`, `DrawKnife.cs:31`, `Froe.cs:31`, `Inshave.cs:31`, `JointingPlane.cs:32`, `MouldingPlane.cs:32`, `Scorp.cs:31`, `SmoothingPlane.cs:32`, `Hammer.cs:31`, `Nails.cs:32` |
| Options | `MarkOption = true; Repair = Core.AOS; CanEnhance = Core.ML;` | `DefCarpentry.cs:978-980` |
| Sub-resource (wood type) | default `Board` cliloc 1072643; entries: `Board 0.0`, `OakBoard 65.0`, `AshBoard 75.0`, `YewBoard 85.0`, `HeartwoodBoard 95.0`, `BloodwoodBoard 95.0`, `FrostwoodBoard 95.0` (name cliloc 1044041, message 1072652) | `DefCarpentry.cs:982-992` |
| Log↔Board equivalence | gump counts `Log` and `Board` as the same resource (`m_TypesTable` pair) | `CraftGump.cs:277` |
| Recipe enum | `CarpRecipes` values `100-120` (ML furniture/statues), `150-152` (arties), `170-171` (Kotl) | `DefCarpentry.cs:7-39` |
| Total live `AddCraft` calls | **223** (224 textual matches; line 475 `GargishKotlBlackRod` is inside a `/* */` comment) | grep `AddCraft(` on `DefCarpentry.cs` |

#### Group 1044294 — "Other" (source comment `// Other`) — 31 rows, lines 141–248

| Item (cliloc) | C# type | Min | Max | Resources (item × n) | Secondary skill | Flags / recipe | Line |
|---|---|---|---|---|---|---|---|
| 1027857 | `BarrelStaves` | 0.0 | 25.0 | Board ×5 | – | – | 141 |
| 1027608 | `BarrelLid` | 11.0 | 36.0 | Board ×4 | – | – | 142 |
| 1044313 | `ShortMusicStandLeft` | 78.9 | 103.9 | Board ×15 | – | – | 143 |
| 1044314 | `ShortMusicStandRight` | 78.9 | 103.9 | Board ×15 | – | – | 144 |
| 1044315 | `TallMusicStandLeft` | 81.5 | 106.5 | Board ×20 | – | – | 145 |
| 1044316 | `TallMusicStandRight` | 81.5 | 106.5 | Board ×20 | – | – | 146 |
| 1044317 | `EasleSouth` | 86.8 | 111.8 | Board ×20 | – | – | 147 |
| 1044318 | `EasleEast` | 86.8 | 111.8 | Board ×20 | – | – | 148 |
| 1044319 | `EasleNorth` | 86.8 | 111.8 | Board ×20 | – | – | 149 |
| 1029412 | `RedHangingLantern` | 65.0 | 90.0 | Board ×5 + BlankScroll ×10 | – | `[ERA]` SE gate | 153 |
| 1029416 | `WhiteHangingLantern` | 65.0 | 90.0 | Board ×5 + BlankScroll ×10 | – | `[ERA]` SE | 156 |
| 1029423 | `ShojiScreen` | 80.0 | 105.0 | Board ×75 + Cloth ×60 | Tailoring 50–55 | `[ERA]` SE | 159 |
| 1029428 | `BambooScreen` | 80.0 | 105.0 | Board ×75 + Cloth ×60 | Tailoring 50–55 | `[ERA]` SE | 163 |
| 1023519 | `FishingPole` | 68.4 | 93.4 | Board ×5 + Cloth ×5 | Tailoring 40–45 | AOS duplicate entry to preserve era ordering (`//This is in the categor of Other during AoS`) | 170 |
| 1072153 | `WoodenContainerEngraver` | 75.0 | 100.0 | Board ×4 + IronIngot ×2 | – | `[ERA]` ML | 178 |
| 1072896 | `RunedSwitch` | 70.0 | 120.0 | Board ×2 + EnchantedSwitch ×1 + RunedPrism ×1 + JeweledFiligree ×1 | – | `[ERA]` ML | 181 |
| 1072885 | `ArcanistStatueSouthDeed` | 0.0 | 35.0 | Board ×250 | – | `ForceNonExceptional`; ML | 186 |
| 1072886 | `ArcanistStatueEastDeed` | 0.0 | 35.0 | Board ×250 | – | `ForceNonExceptional`; ML | 189 |
| 1072887 | `WarriorStatueSouthDeed` | 0.0 | 35.0 | Board ×250 | – | recipe 100 (`CarpRecipes.WarriorStatueSouth`), FNE; ML | 192 |
| 1072888 | `WarriorStatueEastDeed` | 0.0 | 35.0 | Board ×250 | – | recipe 101, FNE; ML | 196 |
| 1072884 | `SquirrelStatueSouthDeed` | 0.0 | 35.0 | Board ×250 | – | recipe 102, FNE; ML | 200 |
| 1073398 | `SquirrelStatueEastDeed` | 0.0 | 35.0 | Board ×250 | – | recipe 103, FNE; ML | 204 |
| 1072889 | `GiantReplicaAcorn` | 80.0 | 105.0 | Board ×35 | – | ML | 208 |
| 1032632 | `MountedDreadHorn` | 90.0 | 115.0 | Board ×50 + PristineDreadHorn ×1 | – | FNE; ML | 210 |
| 1074886 | `AcidProofRope` | 80.0 | 130.0 | GreaterStrengthPotion ×2 + ProtectionScroll ×1 + SwitchItem ×1 | – | recipe 104, FNE; ML | 214 |
| 1095312 | `GargishBanner` | 94.7 | 115.0 | Board ×50 + Cloth ×50 | Tailoring 75–105 | `[ERA]` SA | 225 |
| 1112479 | `Incubator` | 90.0 | 115.0 | Board ×100 | – | `[ERA]` SA | 229 |
| 1112570 | `ChickenCoop` | 90.0 | 115.0 | Board ×150 | – | `[ERA]` SA | 231 |
| 1153502 | `ExodusSummoningAlter` | 95.0 | 120.0 | Board ×100 + Granite ×10 + SmallPieceofBlackrock ×10 + NexusCore ×1 | Magery 75–120 | `[ERA]` SA | 233 |
| 1155849 | `CraftableHouseItem` | 42.1 | 77.7 | Board ×5 | – | `[ERA]` TOL; `SetData(CraftableItemType.DarkWoodenSignHanger)`, `SetDisplayID(2967)` | 244 |
| 1155850 | `CraftableHouseItem` | 42.1 | 77.7 | Board ×5 | – | `[ERA]` TOL; data `LightWoodenSignHanger`, displayID 2969 | 248 |

#### Group 1044291 — "Furniture" — 26 rows, lines 255–308

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1022910 | `FootStool` | 11.0 | 36.0 | Board ×9 | – | – | 255 |
| 1022602 | `Stool` | 11.0 | 36.0 | Board ×9 | – | – | 256 |
| 1044300 | `BambooChair` | 21.0 | 46.0 | Board ×13 | – | – | 257 |
| 1044301 | `WoodenChair` | 21.0 | 46.0 | Board ×13 | – | – | 258 |
| 1044302 | `FancyWoodenChairCushion` | 42.1 | 67.1 | Board ×15 | – | – | 259 |
| 1044303 | `WoodenChairCushion` | 42.1 | 67.1 | Board ×13 | – | – | 260 |
| 1022860 | `WoodenBench` | 52.6 | 77.6 | Board ×17 | – | – | 261 |
| 1044304 | `WoodenThrone` | 52.6 | 77.6 | Board ×17 | – | – | 262 |
| 1044305 | `Throne` | 73.6 | 98.6 | Board ×19 | – | – | 263 |
| 1044306 | `Nightstand` | 42.1 | 67.1 | Board ×17 | – | – | 264 |
| 1022890 | `WritingTable` | 63.1 | 88.1 | Board ×17 | – | – | 265 |
| 1044308 | `LargeTable` | 84.2 | 109.2 | Board ×27 | – | – | 266 |
| 1044307 | `YewWoodTable` | 63.1 | 88.1 | Board ×23 | – | – | 267 |
| 1030265 | `ElegantLowTable` | 80.0 | 105.0 | Board ×35 | – | `[ERA]` SE | 271 |
| 1030266 | `PlainLowTable` | 80.0 | 105.0 | Board ×35 | – | `[ERA]` SE | 273 |
| 1072869 | `OrnateElvenTableSouthDeed` | 85.0 | 110.0 | Board ×60 | – | FNE; ML | 279 |
| 1073384 | `OrnateElvenTableEastDeed` | 85.0 | 110.0 | Board ×60 | – | FNE; ML | 282 |
| 1073385 | `FancyElvenTableSouthDeed` | 80.0 | 105.0 | Board ×50 | – | FNE; ML | 285 |
| 1073386 | `FancyElvenTableEastDeed` | 80.0 | 105.0 | Board ×50 | – | FNE; ML | 288 |
| 1073399 | `ElvenPodium` | 80.0 | 105.0 | Board ×20 | – | ML | 291 |
| 1072870 | `OrnateElvenChair` | 80.0 | 105.0 | Board ×30 | – | recipe 105; ML | 293 |
| 1072872 | `BigElvenChair` | 85.0 | 110.0 | Board ×40 | – | ML | 296 |
| 1072873 | `ElvenReadingChair` | 80.0 | 105.0 | Board ×30 | – | ML | 298 |
| 1095291 | `TerMurStyleChair` | 85.0 | 110.0 | Board ×40 | – | `[ERA]` SA | 303 |
| 1095321 | `TerMurStyleTable` | 75.0 | 100.0 | Board ×50 | – | `[ERA]` SA | 305 |
| 1154173 | `UpholsteredChairDeed` | 70.0 | 110.0 | Board ×40 + Cloth ×12 | Tailoring 55–60 | ThemePack `Kings` (cliloc 1154195) | 308 |

#### Group 1044292 — "Containers" — 35 rows, lines 315–408

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags / recipe | Line |
|---|---|---|---|---|---|---|---|
| 1023709 | `WoodenBox` | 21.0 | 46.0 | Board ×10 | – | – | 315 |
| 1044309 | `SmallCrate` | 10.0 | 35.0 | Board ×8 | – | – | 316 |
| 1044310 | `MediumCrate` | 31.0 | 56.0 | Board ×15 | – | – | 317 |
| 1044311 | `LargeCrate` | 47.3 | 72.3 | Board ×18 | – | – | 318 |
| 1023650 | `WoodenChest` | 73.6 | 98.6 | Board ×20 | – | – | 319 |
| 1022718 | `EmptyBookcase` | 31.5 | 56.5 | Board ×25 | – | – | 320 |
| 1044312 | `FancyArmoire` | 84.2 | 109.2 | Board ×35 | – | – | 321 |
| 1022643 | `Armoire` | 84.2 | 109.2 | Board ×35 | – | – | 322 |
| 1030251 | `PlainWoodenChest` | 90.0 | 115.0 | Board ×30 | – | `[ERA]` SE | 326 |
| 1030253 | `OrnateWoodenChest` | 90.0 | 115.0 | Board ×30 | – | SE | 328 |
| 1030255 | `GildedWoodenChest` | 90.0 | 115.0 | Board ×30 | – | SE | 330 |
| 1030257 | `WoodenFootLocker` | 90.0 | 115.0 | Board ×30 | – | SE | 332 |
| 1030259 | `FinishedWoodenChest` | 90.0 | 115.0 | Board ×30 | – | SE | 334 |
| 1030261 | `TallCabinet` | 90.0 | 115.0 | Board ×35 | – | SE | 336 |
| 1030263 | `ShortCabinet` | 90.0 | 115.0 | Board ×35 | – | SE | 338 |
| 1030328 | `RedArmoire` | 90.0 | 115.0 | Board ×40 | – | SE | 340 |
| 1030330 | `ElegantArmoire` | 90.0 | 115.0 | Board ×40 | – | SE | 342 |
| 1030332 | `MapleArmoire` | 90.0 | 115.0 | Board ×40 | – | SE | 344 |
| 1030334 | `CherryArmoire` | 90.0 | 115.0 | Board ×40 | – | SE | 346 |
| 1023711 | `Keg` | 57.8 | 82.8 | BarrelStaves ×3 + BarrelHoops ×1 + BarrelLid ×1 | – | FNE | 349 |
| 1072871 | `ArcaneBookShelfDeedSouth` | 94.7 | 119.7 | Board ×80 | – | recipe 106, FNE; ML | 357 |
| 1073371 | `ArcaneBookShelfDeedEast` | 94.7 | 119.7 | Board ×80 | – | recipe 107, FNE; ML | 361 |
| 1072862 | `OrnateElvenChestSouthDeed` | 94.7 | 119.7 | Board ×40 | – | recipe 108, FNE; ML | 365 |
| 1073383 | `OrnateElvenChestEastDeed` | 94.7 | 119.7 | Board ×40 | – | recipe 120, FNE; ML | 369 |
| 1072865 | `ElvenWashBasinSouthWithDrawerDeed` | 70.0 | 95.0 | Board ×40 | – | FNE; ML | 373 |
| 1073387 | `ElvenWashBasinEastWithDrawerDeed` | 70.0 | 95.0 | Board ×40 | – | FNE; ML | 376 |
| 1072864 | `ElvenDresserDeedSouth` | 75.0 | 100.0 | Board ×45 | – | recipe 109, FNE; ML | 379 |
| 1073388 | `ElvenDresserDeedEast` | 75.0 | 100.0 | Board ×45 | – | recipe 110, FNE; ML | 383 |
| 1072866 | `FancyElvenArmoire` | 80.0 | 105.0 | Board ×60 | – | recipe 111, FNE; ML | 387 |
| 1073401 | `SimpleElvenArmoire` | 80.0 | 105.0 | Board ×60 | – | FNE; ML | 391 |
| 1073402 | `RarewoodChest` | 80.0 | 105.0 | Board ×30 | – | ML | 394 |
| 1073403 | `DecorativeBox` | 80.0 | 105.0 | Board ×25 | – | ML | 396 |
| 1071213 | `AcademicBookCase` | 60.0 | 85.0 | Board ×25 + AcademicBooksArtifact ×1 | – | (no Core gate in source) | 400 |
| 1095293 | `GargishChest` | 80.0 | 105.0 | Board ×30 | – | `[ERA]` SA | 405 |
| 1150816 | `LiquorBarrel` | 60.0 | 90.0 | Board ×50 | – | no Core gate (`[ERA]` HS-era label, ungated) | 408 |

#### Group 1044566 — "Weapons" — 17 rows, lines 411–470

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags / recipe | Line |
|---|---|---|---|---|---|---|---|
| 1023713 | `ShepherdsCrook` | 78.9 | 103.9 | Board ×7 | – | – | 411 |
| 1023721 | `QuarterStaff` | 73.6 | 98.6 | Board ×6 | – | – | 412 |
| 1025112 | `GnarledStaff` | 78.9 | 103.9 | Board ×7 | – | – | 413 |
| 1030227 | `Bokuto` | 70.0 | 95.0 | Board ×6 | – | `[ERA]` SE | 417 |
| 1030229 | `Fukiya` | 60.0 | 85.0 | Board ×6 | – | SE | 419 |
| 1030225 | `Tetsubo` | 80.0 | 105.0 | Board ×10 | – | SE | 421 |
| 1031557 | `WildStaff` | 63.8 | 113.8 | Board ×16 | – | ML | 427 |
| 1072919 | `PhantomStaff` | 90.0 | 130.0 | Board ×16 + DiseasedBark ×1 + Putrefaction ×10 + Taint ×10 | – | recipe 150, FNE; ML | 429 |
| 1073549 | `ArcanistsWildStaff` | 63.8 | 113.8 | Board ×16 + WhitePearl ×1 | – | recipe 112; ML | 436 |
| 1073550 | `AncientWildStaff` | 63.8 | 113.8 | Board ×16 + PerfectEmerald ×1 | – | recipe 113; ML | 440 |
| 1073551 | `ThornedWildStaff` | 63.8 | 113.8 | Board ×16 + FireRuby ×1 | – | recipe 114; ML | 444 |
| 1073552 | `HardenedWildStaff` | 63.8 | 113.8 | Board ×16 + Turquoise ×1 | – | recipe 115; ML | 448 |
| 1095367 | `SerpentStoneStaff` | 63.8 | 113.8 | Board ×16 + EcruCitrine ×1 | – | `[ERA]` SA | 457 |
| 1097488 | `GargishGnarledStaff` | 78.9 | 128.9 | Board ×16 + EcruCitrine ×1 | – | `[ERA]` SA | 460 |
| 1025043 | `Club` | 65.0 | 90.0 | Board ×9 | – | – | 465 |
| 1023568 | `BlackStaff` | 81.5 | 106.5 | Board ×9 | – | – | 466 |
| 1156990 | `KotlBlackRod` | 100.0 | 160.0 | Board ×20 + BlackrockMoonstone ×1 + StaffOfTheMagi ×1 | – | recipe 170; `[ERA]` TOL | 470 |
| (commented) | `GargishKotlBlackRod` | 100.0 | 160.0 | Board ×20 + BlackrockMoonstone ×1 + StaffOfTheMagi ×1 | – | **disabled** — inside `/* … */`, line 475-479 | 475 |

`[ERA]` note: `BlackrockMoonstone` and `StaffOfTheMagi` are in `CraftSystem._GlobalNoConsume`
(`Core/CraftSystem.cs:281`), i.e. **not** consumed on a failed KotlBlackRod craft.

#### Group 1062760 — "Armor" (source comment `// Armor`) — 18 rows, lines 483–568

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1027034 | `WoodenShield` | 52.6 | 77.6 | Board ×9 | – | – | 483 |
| 1031111 | `WoodlandChest` | 90.0 | 115.0 | Board ×20 + BarkFragment ×6 | – | ML | 488 |
| 1031116 | `WoodlandArms` | 80.0 | 105.0 | Board ×15 + BarkFragment ×4 | – | ML | 491 |
| 1031114 | `WoodlandGloves` | 85.0 | 110.0 | Board ×15 + BarkFragment ×4 | – | ML | 494 |
| 1031115 | `WoodlandLegs` | 85.0 | 110.0 | Board ×15 + BarkFragment ×4 | – | ML | 497 |
| 1031113 | `WoodlandGorget` | 85.0 | 110.0 | Board ×15 + BarkFragment ×4 | – | ML | 500 |
| 1031121 | `RavenHelm` | 65.0 | 115.0 | Board ×10 + BarkFragment ×4 + Feather ×25 | – | ML | 503 |
| 1031122 | `VultureHelm` | 63.9 | 113.9 | Board ×10 + BarkFragment ×4 + Feather ×25 | – | ML | 507 |
| 1031123 | `WingedHelm` | 58.4 | 108.4 | Board ×10 + BarkFragment ×4 + Feather ×60 | – | ML | 511 |
| 1072924 | `IronwoodCrown` | 85.0 | 120.0 | Board ×10 + DiseasedBark ×1 + Corruption ×10 + Putrefaction ×10 | – | recipe 151, FNE; ML | 515 |
| 1072925 | `BrambleCoat` | 85.0 | 120.0 | Board ×10 + DiseasedBark ×1 + Taint ×10 + Scourge ×10 | – | recipe 152, FNE; ML | 522 |
| 1073481 | `DarkwoodCrown` | 85.0 | 120.0 | Board ×10 + LardOfParoxysmus ×1 + Blight ×10 + Taint ×10 | – | FNE; ML | 529 |
| 1073482 | `DarkwoodChest` | 85.0 | 120.0 | Board ×20 + DreadHornMane ×1 + Corruption ×10 + Muculent ×10 | – | FNE; ML | 535 |
| 1073483 | `DarkwoodGorget` | 85.0 | 120.0 | Board ×15 + DiseasedBark ×1 + Blight ×10 + Scourge ×10 | – | FNE; ML | 541 |
| 1073484 | `DarkwoodLegs` | 85.0 | 120.0 | Board ×15 + GrizzledBones ×1 + Corruption ×10 + Putrefaction ×10 | – | FNE; ML | 547 |
| 1073485 | `DarkwoodPauldrons` | 85.0 | 120.0 | Board ×15 + EyeOfTheTravesty ×1 + Scourge ×10 + Taint ×10 | – | FNE; ML | 553 |
| 1073486 | `DarkwoodGloves` | 85.0 | 120.0 | Board ×15 + CapturedEssence ×1 + Putrefaction ×10 + Muculent ×10 | – | FNE; ML | 559 |
| 1095768 | `GargishWoodenShield` | 52.6 | 77.6 | Board ×9 | – | inside an `#region SA` block but **no** `Core.SA` check → always listed | 568 |

#### Group 1044293 — "Instruments" — 14 rows, lines 572–633

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1023762 | `LapHarp` | 63.1 | 88.1 | Board ×20 + Cloth ×10 | Musicianship 45–50 | – | 572 |
| 1023761 | `Harp` | 78.9 | 103.9 | Board ×35 + Cloth ×15 | Musicianship 45–50 | – | 576 |
| 1023740 | `Drums` | 57.8 | 82.8 | Board ×20 + Cloth ×10 | Musicianship 45–50 | – | 580 |
| 1023763 | `Lute` | 68.4 | 93.4 | Board ×25 + Cloth ×10 | Musicianship 45–50 | – | 584 |
| 1023741 | `Tambourine` | 57.8 | 82.8 | Board ×15 + Cloth ×10 | Musicianship 45–50 | – | 588 |
| 1044320 | `TambourineTassel` | 57.8 | 82.8 | Board ×15 + Cloth ×15 | Musicianship 45–50 | – | 592 |
| 1030247 | `BambooFlute` | 80.0 | 105.0 | Board ×15 | Musicianship 45–50 | `[ERA]` SE | 598 |
| 1095315 | `AudChar` | 78.9 | 103.9 | Board ×35 + Granite ×3 | Musicianship 45–50 | `[ERA]` SA | 604 |
| 1112174 | `SnakeCharmerFlute` | 80.0 | 105.0 | Board ×15 + LuminescentFungi ×3 | Musicianship 45–50 | SA | 608 |
| 1098390 | `CelloDeed` | 75.0 | 105.0 | Board ×15 + Cloth ×5 | Musicianship 45–50 | ThemePack `Kings` | 613 |
| 1154162 | `WallMountedBellSouthDeed` | 75.0 | 105.0 | Board ×50 + IronIngot ×50 | Musicianship 45–50 | Kings | 618 |
| 1154163 | `WallMountedBellEastDeed` | 75.0 | 105.0 | Board ×50 + IronIngot ×50 | Musicianship 45–50 | Kings | 623 |
| 1098388 | `TrumpetDeed` | 85.0 | 105.0 | Board ×10 + IronIngot ×15 | Musicianship 45–50 | Kings | 628 |
| 1098418 | `CowBellDeed` | 85.0 | 105.0 | Board ×10 + IronIngot ×15 | Musicianship 45–50 | Kings | 633 |

#### Group 1044290 — "Misc" — 55 rows, lines 641–851

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags / recipe | Line |
|---|---|---|---|---|---|---|---|
| 1062420 | `PlayerBBEast` | 85.0 | 110.0 | Board ×50 | – | `[ERA]` AOS gate | 641 |
| 1062421 | `PlayerBBSouth` | 85.0 | 110.0 | Board ×50 | – | AOS | 642 |
| 1072617 | `ParrotPerchAddonDeed` | 50.0 | 85.0 | Board ×100 | – | FNE; ML | 648 |
| 1072703 | `ArcaneCircleDeed` | 94.7 | 119.7 | Board ×100 + BlueDiamond ×2 + PerfectEmerald ×2 + FireRuby ×2 | – | FNE; ML | 651 |
| 1072858 | `TallElvenBedSouthDeed` | 94.7 | 119.7 | Board ×200 + Cloth ×100 | Tailoring 75–80 | recipe 116, FNE; ML | 657 |
| 1072859 | `TallElvenBedEastDeed` | 94.7 | 119.7 | Board ×200 + Cloth ×100 | Tailoring 75–80 | recipe 117, FNE; ML | 663 |
| 1072860 | `ElvenBedSouthDeed` | 94.7 | 119.7 | Board ×100 + Cloth ×100 | – | FNE; ML | 669 |
| 1072861 | `ElvenBedEastDeed` | 94.7 | 119.7 | Board ×100 + Cloth ×100 | – | FNE; ML | 673 |
| 1072867 | `ElvenLoveseatSouthDeed` | 80.0 | 105.0 | Board ×50 | – | FNE, `SetDisplayID(0x2DDF)`; ML | 677 |
| 1073372 | `ElvenLoveseatEastDeed` | 80.0 | 105.0 | Board ×50 | – | FNE, displayID `0x2DE0`; ML | 681 |
| 1073396 | `AlchemistTableSouthDeed` | 85.0 | 110.0 | Board ×70 | – | FNE, displayID `0x2DD4`; ML | 685 |
| 1073397 | `AlchemistTableEastDeed` | 85.0 | 110.0 | Board ×70 | – | FNE, displayID `0x2DD3`; ML | 689 |
| 1044321 | `SmallBedSouthDeed` | 94.7 | 119.8 | Board ×100 + Cloth ×100 | Tailoring 75–80 | – | 695 |
| 1044322 | `SmallBedEastDeed` | 94.7 | 119.8 | Board ×100 + Cloth ×100 | Tailoring 75–80 | – | 699 |
| 1044323 | `LargeBedSouthDeed` | 94.7 | 119.8 | Board ×150 + Cloth ×150 | Tailoring 75–80 | – | 703 |
| 1044324 | `LargeBedEastDeed` | 94.7 | 119.8 | Board ×150 + Cloth ×150 | Tailoring 75–80 | – | 707 |
| 1044325 | `DartBoardSouthDeed` | 15.7 | 40.7 | Board ×5 | – | – | 711 |
| 1044326 | `DartBoardEastDeed` | 15.7 | 40.7 | Board ×5 | – | – | 712 |
| 1044327 | `BallotBoxDeed` | 47.3 | 72.3 | Board ×5 | – | – | 713 |
| 1044328 | `PentagramDeed` | 100.0 | 125.0 | Board ×100 + IronIngot ×40 | Magery 75–80 | – | 715 |
| 1044329 | `AbbatoirDeed` | 100.0 | 125.0 | Board ×100 + IronIngot ×40 | Magery 50–55 | – | 719 |
| 1111776 | `GargishCouchEastDeed` | 90.0 | 115.0 | Board ×75 | – | `[ERA]` SA | 725 |
| 1111775 | `GargishCouchSouthDeed` | 90.0 | 115.0 | Board ×75 | – | SA | 727 |
| 1111781 | `LongTableSouthDeed` | 90.0 | 115.0 | Board ×80 | – | SA | 729 |
| 1111782 | `LongTableEastDeed` | 90.0 | 115.0 | Board ×80 | – | SA | 731 |
| 1111784 | `TerMurDresserEastDeed` | 90.0 | 115.0 | Board ×60 | – | SA | 733 |
| 1111783 | `TerMurDresserSouthDeed` | 90.0 | 115.0 | Board ×60 | – | SA | 735 |
| 1150593 | `RusticBenchSouthDeed` | 94.7 | 119.8 | Board ×35 | – | ThemePack `Rustic` (1150651) | 738 |
| 1150594 | `RusticBenchEastDeed` | 94.7 | 119.8 | Board ×35 | – | Rustic | 741 |
| 1154160 | `PlainWoodenShelfSouthDeed` | 40.0 | 90.0 | Board ×15 | – | Kings | 744 |
| 1154161 | `PlainWoodenShelfEastDeed` | 40.0 | 90.0 | Board ×15 | – | Kings | 747 |
| 1154158 | `FancyWoodenShelfSouthDeed` | 40.0 | 90.0 | Board ×15 | – | Kings | 750 |
| 1154159 | `FancyWoodenShelfEastDeed` | 40.0 | 90.0 | Board ×15 | – | Kings | 753 |
| 1154137 | `FancyLoveseatSouthDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×24 | Tailoring 55–60 | Kings | 756 |
| 1154138 | `FancyLoveseatEastDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×24 | Tailoring 55–60 | Kings | 761 |
| 1154139 | `FancyCouchSouthDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×48 | Tailoring 55–60 | Kings | 766 |
| 1154140 | `FancyCouchEastDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×48 | Tailoring 55–60 | Kings | 771 |
| 1154135 | `PlushLoveseatSouthDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×24 | Tailoring 55–60 | Kings | 776 |
| 1154136 | `PlushLoveseatEastDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×24 | Tailoring 55–60 | Kings | 781 |
| 1154146 | `PlantTapestrySouthDeed` | 85.0 | 110.0 | Board ×12 + Cloth ×50 | Tailoring 75–80 | Kings | 786 |
| 1154147 | `PlantTapestryEastDeed` | 85.0 | 110.0 | Board ×12 + Cloth ×50 | Tailoring 75–80 | Kings | 791 |
| 1154154 | `MetalTableSouthDeed` | 80.0 | 105.0 | Board ×20 + IronIngot ×15 | Tinkering 75–80 | Kings | 796 |
| 1154155 | `MetalTableEastDeed` | 80.0 | 105.0 | Board ×20 + IronIngot ×15 | Tinkering 75–80 | Kings | 801 |
| 1154164 | `LongMetalTableSouthDeed` | 80.0 | 105.0 | Board ×40 + IronIngot ×30 | Tinkering 75–80 | Kings | 806 |
| 1154165 | `LongMetalTableEastDeed` | 80.0 | 105.0 | Board ×40 + IronIngot ×30 | Tinkering 75–80 | Kings | 811 |
| 1154156 | `WoodenTableSouthDeed` | 80.0 | 105.0 | Board ×20 | – | Kings | 816 |
| 1154157 | `WoodenTableEastDeed` | 80.0 | 105.0 | Board ×20 | – | Kings | 819 |
| 1154166 | `LongWoodenTableSouthDeed` | 80.0 | 105.0 | Board ×80 | – | Kings | 822 |
| 1154167 | `LongWoodenTableEastDeed` | 80.0 | 105.0 | Board ×80 | – | Kings | 825 |
| 1155842 | `SmallDisplayCaseSouthDeed` | 95.0 | 120.0 | Board ×40 + IronIngot ×10 | Tinkering 75–80 | (no theme pack set) | 828 |
| 1155843 | `SmallDisplayCaseEastDeed` | 95.0 | 120.0 | Board ×40 + IronIngot ×10 | Tinkering 75–80 | – | 832 |
| 1156560 | `FancyLoveseatNorthDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×48 | Tailoring 55–60 | Kings | 836 |
| 1156561 | `FancyLoveseatWestDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×48 | Tailoring 55–60 | Kings | 841 |
| 1156582 | `FancyCouchNorthDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×48 | Tailoring 55–60 | Kings | 846 |
| 1156583 | `FancyCouchWestDeed` | 70.0 | 120.0 | Board ×80 + Cloth ×48 | Tailoring 55–60 | Kings | 851 |

#### Group 1044298 — "Tailoring and Cooking" (source comment) — 16 rows, lines 857–919

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1044339 | `DressformFront` | 63.1 | 88.1 | Board ×25 + Cloth ×10 | Tailoring 65–70 | – | 857 |
| 1044340 | `DressformSide` | 63.1 | 88.1 | Board ×25 + Cloth ×10 | Tailoring 65–70 | – | 861 |
| 1073393 | `ElvenSpinningwheelEastDeed` | 75.0 | 100.0 | Board ×60 + Cloth ×40 | Tailoring 65–85 | FNE; ML | 868 |
| 1072878 | `ElvenSpinningwheelSouthDeed` | 75.0 | 100.0 | Board ×60 + Cloth ×40 | Tailoring 65–85 | FNE; ML | 873 |
| 1073394 | `ElvenStoveSouthDeed` | 85.0 | 110.0 | Board ×80 | – | FNE; ML | 878 |
| 1073395 | `ElvenStoveEastDeed` | 85.0 | 110.0 | Board ×80 | – | FNE; ML | 881 |
| 1044341 | `SpinningwheelEastDeed` | 73.6 | 98.6 | Board ×75 + Cloth ×25 | Tailoring 65–70 | – | 886 |
| 1044342 | `SpinningwheelSouthDeed` | 73.6 | 98.6 | Board ×75 + Cloth ×25 | Tailoring 65–70 | – | 890 |
| 1044343 | `LoomEastDeed` | 84.2 | 109.2 | Board ×85 + Cloth ×25 | Tailoring 65–70 | – | 894 |
| 1044344 | `LoomSouthDeed` | 84.2 | 109.2 | Board ×85 + Cloth ×25 | Tailoring 65–70 | – | 898 |
| 1044345 | `StoneOvenEastDeed` | 68.4 | 93.4 | Board ×85 + IronIngot ×125 | Tinkering 50–55 | – | 902 |
| 1044346 | `StoneOvenSouthDeed` | 68.4 | 93.4 | Board ×85 + IronIngot ×125 | Tinkering 50–55 | – | 906 |
| 1044347 | `FlourMillEastDeed` | 94.7 | 119.7 | Board ×100 + IronIngot ×50 | Tinkering 50–55 | – | 910 |
| 1044348 | `FlourMillSouthDeed` | 94.7 | 119.7 | Board ×100 + IronIngot ×50 | Tinkering 50–55 | – | 914 |
| 1044349 | `WaterTroughEastDeed` | 94.7 | 119.7 | Board ×150 | – | – | 918 |
| 1044350 | `WaterTroughSouthDeed` | 94.7 | 119.7 | Board ×150 | – | – | 919 |

#### Group 1111809 — "Anvils and Forges" (source comment) — 7 rows, lines 925–957

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1072875 | `ElvenForgeDeed` | 94.7 | 119.7 | Board ×200 | – | FNE; ML | 925 |
| 1095827 | `SoulForgeDeed` | 100.0 | 200.0 | Board ×150 + IronIngot ×150 + RelicFragment ×1 | Imbuing 75–80 | FNE; `[ERA]` SA | 933 |
| 1044330 | `SmallForgeDeed` | 73.6 | 98.6 | Board ×5 + IronIngot ×75 | Blacksmith 75–80 | – | 941 |
| 1044331 | `LargeForgeEastDeed` | 78.9 | 103.9 | Board ×5 + IronIngot ×100 | Blacksmith 80–85 | – | 945 |
| 1044332 | `LargeForgeSouthDeed` | 78.9 | 103.9 | Board ×5 + IronIngot ×100 | Blacksmith 80–85 | – | 949 |
| 1044333 | `AnvilEastDeed` | 73.6 | 98.6 | Board ×5 + IronIngot ×150 | Blacksmith 75–80 | – | 953 |
| 1044334 | `AnvilSouthDeed` | 73.6 | 98.6 | Board ×5 + IronIngot ×150 | Blacksmith 75–80 | – | 957 |

#### Group 1044297 — "Training" (source comment `// Training`) — 4 rows, lines 962–974

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1044335 | `TrainingDummyEastDeed` | 68.4 | 93.4 | Board ×55 + Cloth ×60 | Tailoring 50–55 | – | 962 |
| 1044336 | `TrainingDummySouthDeed` | 68.4 | 93.4 | Board ×55 + Cloth ×60 | Tailoring 50–55 | – | 966 |
| 1044337 | `PickpocketDipEastDeed` | 73.6 | 98.6 | Board ×65 + Cloth ×60 | Tailoring 50–55 | – | 970 |
| 1044338 | `PickpocketDipSouthDeed` | 73.6 | 98.6 | Board ×65 + Cloth ×60 | Tailoring 50–55 | – | 974 |

---

### 4c.2 Tinkering — `DefTinkering`

| Property | Value | Source |
|---|---|---|
| System class / singleton | `DefTinkering` / `DefTinkering.CraftSystem` | `DefTinkering.cs:39,69-78` |
| Primary skill | `SkillName.Tinkering` | `DefTinkering.cs:51-57` |
| Secondary skills | `AnimalLore` (HitchingRope), `Magery` (ArcanicRuneStone, VoidOrb) | `DefTinkering.cs:603,616,620` |
| Min / max skill present | `-25.0` (`Axle`) / `580.0` (`KotlAutomatonHead`, `DrSpectorsLenses`, `BraceletOfPrimalConsumption`) | `DefTinkering.cs:243,651,766,773` |
| Effect timing | `base(1, 1, 1.25)` | `DefTinkering.cs:80-83` |
| `GetChanceAtMin` | `0.5` only for cliloc **1044258** (PotionKeg) and **1046445** (FactionTrapRemovalKit); `0.0` otherwise | `DefTinkering.cs:85-91` |
| `ECA` | `ChanceMinusSixtyToFourtyFive` | `DefTinkering.cs:42-48` |
| Gump title | cliloc `1044007` `// <CENTER>TINKERING MENU</CENTER>` | `DefTinkering.cs:59-65` |
| `CanCraft` preconditions | tool valid + accessible; `BaseFactionTrapDeed`/`FactionTrapRemovalKit` require `Faction.Find(from) != null`; `ModifiedClockworkAssembly` requires `PlayerMobile.MechanicalLife` | `DefTinkering.cs:93-107` |
| Craft sound | `0x23B` | `DefTinkering.cs:145-148` |
| Tool family | `TinkerTools`, `TinkersTools`, `Clippers` → `DefTinkering.CraftSystem` | `TinkerTools.cs:33,111`, `Clippers.cs:151-157` |
| Colour retention | `RetainsColorFrom` true for an explicit list (cutlery, plates, KeyRing, Candelabra, Scales, Key, Globe, Spyglass, Lantern, HeatingStand, BroadcastCrystal, TerMurStyleCandelabra, GorgonLense, scales, plant resources, KotlAutomatonHead) or any `BaseIngot` | `DefTinkering.cs:109-143` |
| Options | `MarkOption = true; Repair = true; CanEnhance = Core.AOS; CanAlter = Core.SA;` | `DefTinkering.cs:798-801` |
| Sub-resource (metal type) | default `IronIngot` 1044022; `IronIngot 0.0`, `DullCopperIngot 65.0`, `ShadowIronIngot 70.0`, `CopperIngot 75.0`, `BronzeIngot 80.0`, `GoldIngot 85.0`, `AgapiteIngot 90.0`, `VeriteIngot 95.0`, `ValoriteIngot 99.0` (name 1044036, message 1044268) | `DefTinkering.cs:784-796` |
| Recipe enum | `TinkerRecipes`: potions 400-402, arties 450-457, doom/event 458-465 | `DefTinkering.cs:9-37` |
| Total live `AddCraft` calls | **165** call sites (13 of them in the Jewelry region incl. the `AddJewelrySet` helper; that helper is invoked 9× so it yields 54 gump rows) | grep `AddCraft(` on `DefTinkering.cs` |

#### Group 1044049 — "Jewelry" — 13 call sites → 61 gump rows, lines 204–229 (helper 175–197)

Plain entries:

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1024234 | `GoldRing` | 65.0 | 115.0 | IronIngot ×3 | – | 204 |
| 1024230 | `GoldBracelet` | 55.0 | 105.0 | IronIngot ×3 | – | 205 |
| 1095784 | `GargishNecklace` | 60.0 | 110.0 | IronIngot ×3 | `[ERA]` SA | 209 |
| 1095785 | `GargishBracelet` | 55.0 | 105.0 | IronIngot ×3 | SA | 211 |
| 1095786 | `GargishRing` | 65.0 | 115.0 | IronIngot ×3 | SA | 213 |
| 1095787 | `GargishEarrings` | 55.0 | 105.0 | IronIngot ×3 | SA | 215 |
| 1125645 | `KrampusMinionEarrings` | 100.0 | 500.0 | IronIngot ×3 | recipe 463; **no Core gate in source** (event item) | 228 |

`AddJewelrySet(GemType, Type)` — 6 call sites (`DefTinkering.cs:175-197`), invoked 9× at lines 218-226
(`StarSapphire, Emerald, Sapphire, Ruby, Citrine, Amethyst, Tourmaline, Amber, Diamond`;
order taken from `GemType` in `BaseJewel.cs:10-22`, `offset = (int)gemType - 1` at `DefTinkering.cs:177`):

| Item (cliloc = base + offset) | C# type | Min | Max | Resources | Second resource (name cliloc) | Line |
|---|---|---|---|---|---|---|
| 1044176 + offset | `GoldRing` | 40.0 | 90.0 | IronIngot ×2 | gem ×1 (1044231 + offset, msg 1044240) | 179 |
| 1044185 + offset | `SilverBeadNecklace` | 40.0 | 90.0 | IronIngot ×2 | gem ×1 | 182 |
| 1044194 + offset | `GoldNecklace` | 40.0 | 90.0 | IronIngot ×2 | gem ×1 | 185 |
| 1044203 + offset | `GoldEarrings` | 40.0 | 90.0 | IronIngot ×2 | gem ×1 | 188 |
| 1044212 + offset | `GoldBeadNecklace` | 40.0 | 90.0 | IronIngot ×2 | gem ×1 | 191 |
| 1044221 + offset | `GoldBracelet` | 40.0 | 90.0 | IronIngot ×2 | gem ×1 | 194 |

#### Group 1044042 — "Wooden Items" — 22 rows, lines 235–319

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1030158 | `Nunchaku` | 70.0 | 120.0 | IronIngot ×3 + Board ×8 | – | `[ERA]` SE | 235 |
| 1024144 | `JointingPlane` | 0.0 | 50.0 | Board ×4 | – | – | 239 |
| 1024140 | `MouldingPlane` | 0.0 | 50.0 | Board ×4 | – | – | 240 |
| 1024146 | `SmoothingPlane` | 0.0 | 50.0 | Board ×4 | – | – | 241 |
| 1024173 | `ClockFrame` | 0.0 | 50.0 | Board ×6 | – | – | 242 |
| 1024187 | `Axle` | **-25.0** | 25.0 | Board ×2 | – | lowest MinSkill in the file | 243 |
| 1024163 | `RollingPin` | 0.0 | 50.0 | Board ×5 | – | – | 244 |
| 1095839 | `Ramrod` | 0.0 | 50.0 | Board ×8 | – | `[ERA]` HS | 248 |
| 1095840 | `Swab` | 0.0 | 50.0 | Cloth ×1 + Board ×4 | – | HS **and** `!Core.EJ` | 252 |
| 1112249 | `SoftenedReeds` | 75.0 | 100.0 | DryReeds ×1 + ScouringToxin ×2 | – | SA; `SetRequiresBasketWeaving`, `SetRequireResTarget` | 259 |
| 1112293 | `RoundBasket` | 75.0 | 100.0 | SoftenedReeds ×2 + Shaft ×3 | – | SA; basket-weaving + res target | 264 |
| 1112357 | `RoundBasketHandles` | 75.0 | 100.0 | SoftenedReeds ×2 + Shaft ×3 | – | SA; bw + rt | 269 |
| 1112337 | `SmallBushel` | 75.0 | 100.0 | SoftenedReeds ×1 + Shaft ×2 | – | SA; bw + rt | 274 |
| 1023706 | `PicnicBasket2` | 75.0 | 100.0 | SoftenedReeds ×1 + Shaft ×2 | – | SA; bw + rt | 279 |
| 1026274 | `WinnowingBasket` | 75.0 | 100.0 | SoftenedReeds ×2 + Shaft ×3 | – | SA; bw + rt | 284 |
| 1112295 | `SquareBasket` | 75.0 | 100.0 | SoftenedReeds ×2 + Shaft ×3 | – | SA; bw + rt | 289 |
| 1022448 | `BasketCraftable` | 75.0 | 100.0 | SoftenedReeds ×2 + Shaft ×3 | – | SA; bw + rt | 294 |
| 1112297 | `TallRoundBasket` | 75.0 | 100.0 | SoftenedReeds ×3 + Shaft ×4 | – | SA; bw + rt | 299 |
| 1112296 | `SmallSquareBasket` | 75.0 | 100.0 | SoftenedReeds ×1 + Shaft ×2 | – | SA; bw + rt | 304 |
| 1112299 | `TallBasket` | 75.0 | 100.0 | SoftenedReeds ×3 + Shaft ×4 | – | SA; bw + rt | 309 |
| 1112298 | `SmallRoundBasket` | 75.0 | 100.0 | SoftenedReeds ×1 + Shaft ×2 | – | SA; bw + rt | 314 |
| 1158333 | `EnchantedPicnicBasket` | 75.0 | 100.0 | SoftenedReeds ×2 + Shaft ×3 | – | SA; recipe 464; bw + rt | 319 |

#### Group 1044046 — "Tools" — 26 rows, lines 328–361

| Item (cliloc) | C# type | Min | Max | Resources | Craft system it opens | Flags | Line |
|---|---|---|---|---|---|---|---|
| 1023998 | `Scissors` | 5.0 | 55.0 | IronIngot ×2 | **none** — `Scissors : Item`, target-based (`IScissorable`) | – | 328 |
| 1023739 | `MortarPestle` | 20.0 | 70.0 | IronIngot ×3 | Alchemy | – | 329 |
| 1024327 | `Scorp` | 30.0 | 80.0 | IronIngot ×2 | Carpentry | – | 330 |
| 1044164 | `TinkerTools` | 10.0 | 60.0 | IronIngot ×2 | Tinkering | – | 331 |
| 1023907 | `Hatchet` | 30.0 | 80.0 | IronIngot ×4 | **none** — `Hatchet : BaseAxe` (Lumberjacking weapon) | – | 332 |
| 1024324 | `DrawKnife` | 30.0 | 80.0 | IronIngot ×2 | Carpentry | – | 333 |
| 1023997 | `SewingKit` | 10.0 | 70.0 | IronIngot ×2 | Tailoring | – | 334 |
| 1024148 | `Saw` | 30.0 | 80.0 | IronIngot ×4 | Carpentry | – | 335 |
| 1024136 | `DovetailSaw` | 30.0 | 80.0 | IronIngot ×4 | Carpentry | – | 336 |
| 1024325 | `Froe` | 30.0 | 80.0 | IronIngot ×2 | Carpentry | – | 337 |
| 1023898 | `Shovel` | 40.0 | 90.0 | IronIngot ×4 | **none** — `Shovel : BaseHarvestTool` (Mining) | – | 338 |
| 1024138 | `Hammer` | 30.0 | 80.0 | IronIngot ×1 | **Carpentry** (`Hammer.cs:31`) | – | 339 |
| 1024028 | `Tongs` | 35.0 | 85.0 | IronIngot ×1 | Blacksmithy | – | 340 |
| 1025091 | `SmithyHammer` if `Core.AOS`, else `SmithHammer` | 40.0 | 90.0 | IronIngot ×4 | Blacksmithy | era-conditional type | 341 |
| 1024021 | `SledgeHammerWeapon` if `Core.AOS`, else `SledgeHammer` | 40.0 | 90.0 | IronIngot ×4 | Blacksmithy | era-conditional type | 342 |
| 1024326 | `Inshave` | 30.0 | 80.0 | IronIngot ×2 | Carpentry | – | 343 |
| 1023718 | `Pickaxe` | 40.0 | 90.0 | IronIngot ×4 | **none** — `Pickaxe : BaseAxe, IHarvestTool` (Mining) | – | 344 |
| 1025371 | `Lockpick` | 45.0 | 95.0 | IronIngot ×1 | **none** — `Lockpick : Item` (`LockPick.cs:19`), target-based Lockpicking | – | 345 |
| 1044567 | `Skillet` | 30.0 | 80.0 | IronIngot ×4 | Cooking | – | 346 |
| 1024158 | `FlourSifter` | 50.0 | 100.0 | IronIngot ×3 | Cooking | – | 347 |
| 1044166 | `FletcherTools` | 35.0 | 85.0 | IronIngot ×3 | Bowcraft/Fletching | – | 348 |
| 1044167 | `MapmakersPen` | 25.0 | 75.0 | IronIngot ×1 | Cartography | – | 349 |
| 1044168 | `ScribesPen` | 25.0 | 75.0 | IronIngot ×1 | Inscription | – | 350 |
| 1112117 | `Clippers` | 50.0 | 50.0 | IronIngot ×4 | Tinkering (property) but double-click targets plants | min == max | 351 |
| 1072154 | `MetalContainerEngraver` | 75.0 | 100.0 | IronIngot ×4 + Springs ×1 + Gears ×2 + Diamond ×1 | – | `[ERA]` ML | 355 |
| 1023719 | `Pitchfork` | 40.0 | 90.0 | IronIngot ×4 | **none** — weapon | – | 361 |

`Clippers` also has no craft-gump use: `OnDoubleClick` opens a plant-clipping target (`Clippers.cs:174-243`).

#### Group 1044047 — "Parts" — 9 rows, lines 366–377

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1024179 | `Gears` | 5.0 | 55.0 | IronIngot ×2 | – | 366 |
| 1024175 | `ClockParts` | 25.0 | 75.0 | IronIngot ×1 | (same type also craftable in Assemblies) | 367 |
| 1024100 | `BarrelTap` | 35.0 | 85.0 | IronIngot ×2 | – | 368 |
| 1024189 | `Springs` | 5.0 | 55.0 | IronIngot ×2 | – | 369 |
| 1024185 | `SextantParts` | 30.0 | 80.0 | IronIngot ×4 | (same type also in Assemblies) | 370 |
| 1024321 | `BarrelHoops` | **-15.0** | 35.0 | IronIngot ×5 | – | 371 |
| 1024181 | `Hinge` | 5.0 | 55.0 | IronIngot ×2 | – | 372 |
| 1023699 | `BolaBall` | 45.0 | 95.0 | IronIngot ×10 | – | 373 |
| 1072894 | `JeweledFiligree` | 70.0 | 110.0 | IronIngot ×2 + StarSapphire ×1 + Ruby ×1 | `[ERA]` ML | 377 |

#### Group 1044048 — "Utensils" — 14 rows, lines 384–401

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1025110 | `ButcherKnife` | 25.0 | 75.0 | IronIngot ×2 | `ButcherKnife : BaseKnife` (no craft gump) | 384 |
| 1044158 | `SpoonLeft` | 0.0 | 50.0 | IronIngot ×1 | colour-retaining | 385 |
| 1044159 | `SpoonRight` | 0.0 | 50.0 | IronIngot ×1 | colour-retaining | 386 |
| 1022519 | `Plate` | 0.0 | 50.0 | IronIngot ×2 | colour-retaining | 387 |
| 1044160 | `ForkLeft` | 0.0 | 50.0 | IronIngot ×1 | colour-retaining | 388 |
| 1044161 | `ForkRight` | 0.0 | 50.0 | IronIngot ×1 | colour-retaining | 389 |
| 1023778 | `Cleaver` | 20.0 | 70.0 | IronIngot ×3 | `Cleaver : BaseKnife` | 390 |
| 1044162 | `KnifeLeft` | 0.0 | 50.0 | IronIngot ×1 | colour-retaining | 391 |
| 1044163 | `KnifeRight` | 0.0 | 50.0 | IronIngot ×1 | colour-retaining | 392 |
| 1022458 | `Goblet` | 10.0 | 60.0 | IronIngot ×2 | colour-retaining | 393 |
| 1024097 | `PewterMug` | 10.0 | 60.0 | IronIngot ×2 | colour-retaining | 394 |
| 1023781 | `SkinningKnife` | 25.0 | 75.0 | IronIngot ×2 | `SkinningKnife : BaseKnife` | 395 |
| 1097478 | `GargishCleaver` | 20.0 | 70.0 | IronIngot ×3 | `[ERA]` SA | 399 |
| 1097486 | `GargishButcherKnife` | 25.0 | 75.0 | IronIngot ×2 | SA | 401 |

#### Group 1044050 — "Misc" — 39 rows, lines 406–551

| Item (cliloc) | C# type | Min | Max | Resources | Secondary skill | Flags / recipe | Line |
|---|---|---|---|---|---|---|---|
| 1024113 | `KeyRing` | 10.0 | 60.0 | IronIngot ×2 | – | colour-retaining | 406 |
| 1022599 | `Candelabra` | 55.0 | 105.0 | IronIngot ×4 | – | colour-retaining | 407 |
| 1026225 | `Scales` | 60.0 | 110.0 | IronIngot ×4 | – | colour-retaining | 408 |
| 1024112 | `Key` | 20.0 | 70.0 | IronIngot ×3 | – | colour-retaining | 409 |
| 1024167 | `Globe` | 55.0 | 105.0 | IronIngot ×4 | – | colour-retaining | 410 |
| 1025365 | `Spyglass` | 60.0 | 110.0 | IronIngot ×4 | – | colour-retaining | 411 |
| 1022597 | `Lantern` | 30.0 | 80.0 | IronIngot ×2 | – | colour-retaining | 412 |
| 1026217 | `HeatingStand` | 60.0 | 110.0 | IronIngot ×4 | – | colour-retaining | 413 |
| 1029404 | `ShojiLantern` | 65.0 | 115.0 | IronIngot ×10 + Board ×5 | – | `[ERA]` SE | 417 |
| 1029406 | `PaperLantern` | 65.0 | 115.0 | IronIngot ×10 + Board ×5 | – | SE | 420 |
| 1029418 | `RoundPaperLantern` | 65.0 | 115.0 | IronIngot ×10 + Board ×5 | – | SE | 423 |
| 1030290 | `WindChimes` | 80.0 | 130.0 | IronIngot ×15 | – | SE | 426 |
| 1030291 | `FancyWindChimes` | 80.0 | 130.0 | IronIngot ×15 | – | SE | 428 |
| 1095313 | `TerMurStyleCandelabra` | 55.0 | 105.0 | IronIngot ×4 | – | `[ERA]` SA | 433 |
| 1096648 | `Matches` | 15.0 | 70.0 | Matchcord ×10 + Board ×4 | – | HS **and** `!Core.EJ` (`// Removed for Dark Tides Cannon Changes`) | 439 |
| 1153097 | `BroadcastCrystal` | 80.0 | 130.0 | IronIngot ×20 + Emerald ×10 + Ruby ×10 + CopperWire ×1 | – | colour-retaining | 443 |
| 1112625 | `GorgonLense` | 90.0 | 120.0 | MedusaDarkScales ×2 + CrystalDust ×3 | – | SA; FNE; `SetItemHue(1266)` | 450 |
| 1112480 | `ScaleCollar` | 50.0 | 100.0 | RedScales ×4 + Scourge ×1 | – | SA | 455 |
| 1098404 | `DragonLamp` | 75.0 | 125.0 | IronIngot ×8 + Candelabra ×1 + WorkableGlass ×1 | – | ThemePack `Kings`; consumes glassblowing output | 459 |
| 1098408 | `StainedGlassLamp` | 75.0 | 125.0 | IronIngot ×8 + Candelabra ×1 + WorkableGlass ×1 | – | Kings | 464 |
| 1098414 | `TallDoubleLamp` | 75.0 | 125.0 | IronIngot ×8 + Candelabra ×1 + WorkableGlass ×1 | – | Kings | 469 |
| 1155851 | `CraftableHouseItem` | 40.0 | 90.0 | IronIngot ×8 | – | `[ERA]` TOL; data `CurledMetalSignHanger`, displayID 2971 | 476 |
| 1155852 | `CraftableHouseItem` | 40.0 | 90.0 | IronIngot ×8 | – | TOL; `FlourishedMetalSignHanger`, displayID 2973 | 480 |
| 1155853 | `CraftableHouseItem` | 40.0 | 90.0 | IronIngot ×8 | – | TOL; `InwardCurledMetalSignHanger`, displayID 2975 | 484 |
| 1155854 | `CraftableHouseItem` | 40.0 | 90.0 | IronIngot ×8 | – | TOL; `EndCurledMetalSignHanger`, displayID 2977 | 488 |
| 1156080 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `DoorType.LeftMetalDoor_S_In`, displayID 1653, `AddCreateItem(CraftableMetalHouseDoor.Create)` | 492 |
| 1156081 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `RightMetalDoor_S_In`, displayID 1659 | 497 |
| 1156082 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `LeftMetalDoor_E_Out`, displayID 1660 | 502 |
| 1156083 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `RightMetalDoor_E_Out`, displayID 1663 | 507 |
| 1155860 | `WallSafeDeed` | 0.0 | 0.0 | IronIngot ×20 | – | TOL; FNE; min == max == 0 | 512 |
| 1156352 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `LeftMetalDoor_E_In`, displayID 1660 | 515 |
| 1156353 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `RightMetalDoor_E_In`, displayID 1663 | 520 |
| 1156350 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `LeftMetalDoor_S_Out`, displayID 1653 | 525 |
| 1156351 | `CraftableMetalHouseDoor` | 85.0 | 135.0 | IronIngot ×50 | – | TOL; `RightMetalDoor_S_Out`, displayID 1659 | 530 |
| 1124179 | `KotlPowerCore` | 85.0 | 135.0 | WorkableGlass ×5 + CopperWire ×5 + IronIngot ×100 + MoonstoneCrystalShard ×5 | – | TOL; recipe 455 | 535 |
| 1156881 | `WeatheredBronzeGlobeSculptureDeed` | 85.0 | 135.0 | BronzeIngot ×200 (name cliloc 1038039) | – | recipe 461; **no Core gate in source** | 542 |
| 1156882 | `WeatheredBronzeManOnABenchDeed` | 85.0 | 135.0 | IronIngot ×200 (name cliloc 1038039) | – | recipe 462; no Core gate | 545 |
| 1156883 | `WeatheredBronzeFairySculptureDeed` | 85.0 | 135.0 | IronIngot ×200 (name cliloc 1038039) | – | recipe 460; no Core gate | 548 |
| 1156884 | `WeatheredBronzeArcherDeed` | 85.0 | 135.0 | IronIngot ×200 (name cliloc 1038039) | – | recipe 459; no Core gate | 551 |

`[SRC]` literal warning: lines 545-551 pass `typeof(IronIngot)` with the resource-name cliloc `1038039`
(the bronze-ingot string) — transcribed as written; whether that is intended is not determinable from source.

#### Group 1044051 — "Assemblies" (multi-part items) — 21 rows, lines 557–658

| Item (cliloc) | C# type | Min | Max | Resources (all consumed parts) | Secondary skill | Flags / recipe | Line |
|---|---|---|---|---|---|---|---|
| 1024177 | `AxleGears` | 0.0 | 0.0 | Axle ×1 + Gears ×1 | – | – | 557 |
| 1024175 | `ClockParts` | 0.0 | 0.0 | AxleGears ×1 + Springs ×1 | – | – | 560 |
| 1024185 | `SextantParts` | 0.0 | 0.0 | AxleGears ×1 + Hinge ×1 | – | – | 563 |
| 1044257 | `ClockRight` | 0.0 | 0.0 | ClockFrame ×1 + ClockParts ×1 | – | – | 566 |
| 1044256 | `ClockLeft` | 0.0 | 0.0 | ClockFrame ×1 + ClockParts ×1 | – | – | 569 |
| 1024183 | `Sextant` | 0.0 | 0.0 | SextantParts ×1 | – | – | 572 |
| 1046441 | `Bola` | 60.0 | 80.0 | BolaBall ×4 + Leather ×3 | – | – | 574 |
| 1044258 | `PotionKeg` | 75.0 | 100.0 | Keg ×1 + Bottle ×10 + BarrelLid ×1 + BarrelTap ×1 | – | `GetChanceAtMin` = 0.5 for this cliloc | 577 |
| 1113031 | `ModifiedClockworkAssembly` | 65.0 | 115.0 | ClockworkAssembly ×1 + PowerCrystal ×1 + VoidEssence ×1 | – | SA; FNE; requires `MechanicalLife` | 584 |
| 1113032 | `ModifiedClockworkAssembly` | 65.0 | 115.0 | ClockworkAssembly ×1 + PowerCrystal ×1 + VoidEssence ×2 | – | SA; FNE | 589 |
| 1113033 | `ModifiedClockworkAssembly` | 65.0 | 115.0 | ClockworkAssembly ×1 + PowerCrystal ×1 + VoidEssence ×3 | – | SA; FNE | 594 |
| 1071124 | `HitchingRope` | 60.0 | 120.0 | Rope ×1 + ResolvesBridle ×1 | AnimalLore 15–100 | ML | 602 |
| 1071127 | `HitchingPost` | 90.0 | 160.0 | IronIngot ×50 + AnimalPheromone ×1 + HitchingRope ×2 + PhillipsWoodenSteed ×1 | – | ML | 606 |
| 1113352 | `ArcanicRuneStone` | 90.0 | 140.0 | CrystalShards ×1 + PowerCrystal ×5 | Magery 80–85 | SA; FNE | 614 |
| 1113354 | `VoidOrb` | 90.0 | **104.3** | DarkSapphire ×1 + BlackPearl ×50 | Magery 80–100 | SA; FNE; non-integer max | 619 |
| 1150595 | `AdvancedTrainingDummySouthDeed` | 90.0 | 120.0 | TrainingDummySouthDeed ×1 + PlateChest ×1 + CloseHelm ×1 + Broadsword ×1 | – | FNE; ThemePack `Gothic` (1150650) | 625 |
| 1150596 | `AdvancedTrainingDummyEastDeed` | 90.0 | 120.0 | TrainingDummyEastDeed ×1 + PlateChest ×1 + CloseHelm ×1 + Broadsword ×1 | – | FNE; Gothic | 632 |
| 1150663 | `DistillerySouthAddonDeed` | 90.0 | 110.0 | MetalKeg ×2 + HeatingStand ×4 + CopperWire ×1 | – | FNE | 639 |
| 1150664 | `DistilleryEastAddonDeed` | 90.0 | 110.0 | MetalKeg ×2 + HeatingStand ×4 + CopperWire ×1 | – | FNE | 644 |
| 1156998 | `KotlAutomatonHead` | 100.0 | **580.0** | IronIngot ×300 + AutomatonActuator ×1 + StasisChamberPowerCore ×1 + InoperativeAutomatonHead ×1 | – | TOL; recipe 458; `SetMinSkillOffset(25.0)` | 651 |
| 1125284 | `PersonalTelescope` | 95.0 | 196.0 | IronIngot ×25 + WorkableGlass ×1 + SextantParts ×1 | – | TOL; recipe 465 | 658 |

#### Group 1044052 — "Traps" — 8 rows, lines 667–699

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1024396 | `DartTrapCraft` | 30.0 | 80.0 | IronIngot ×1 + Bolt ×1 | custom `TrapCraft` (targets a `LockableContainer`) | 667 |
| 1044593 | `PoisonTrapCraft` | 30.0 | 80.0 | IronIngot ×1 + BasePoisonPotion ×1 | TrapCraft | 671 |
| 1044597 | `ExplosionTrapCraft` | 55.0 | 105.0 | IronIngot ×1 + BaseExplosionPotion ×1 | TrapCraft | 675 |
| 1044598 | `FactionGasTrapDeed` | 65.0 | 115.0 | Silver ×(AOS ? 250 : 1000) + IronIngot ×10 + BasePoisonPotion ×1 | faction membership required | 679 |
| 1044599 | `FactionExplosionTrapDeed` | 65.0 | 115.0 | Silver ×(AOS ? 250 : 1000) + IronIngot ×10 + BaseExplosionPotion ×1 | faction required | 684 |
| 1044600 | `FactionSawTrapDeed` | 65.0 | 115.0 | Silver ×(AOS ? 250 : 1000) + IronIngot ×10 + Gears ×1 | faction required | 689 |
| 1044601 | `FactionSpikeTrapDeed` | 65.0 | 115.0 | Silver ×(AOS ? 250 : 1000) + IronIngot ×10 + Springs ×1 | faction required | 694 |
| 1046445 | `FactionTrapRemovalKit` | 90.0 | 115.0 | Silver ×500 + IronIngot ×10 | faction required; `GetChanceAtMin` = 0.5 | 699 |

Trap completion logic `[SRC]` (`DefTinkering.cs:909-926`): `trapLevel = (int)(Tinkering.Value / 10)`,
`Container.TrapPower = trapLevel * 9`, `TrapLevel = trapLevel`, `TrapOnLockpick = true`;
target validation at `DefTinkering.cs:824-840` (lockable, in range 2, movable, accessible, unlocked, untrapped);
Siege shard failure damages 80–120 (`DefTinkering.cs:896-900`).

#### Group 1073107 — "Magic Jewelry" — 13 rows, lines 706–773

| Item (cliloc) | C# type | Min | Max | Resources | Flags / recipe | Line |
|---|---|---|---|---|---|---|
| 1073453 | `BrilliantAmberBracelet` | 75.0 | 125.0 | IronIngot ×5 + Amber ×20 + BrilliantAmber ×10 | ML | 706 |
| 1073454 | `FireRubyBracelet` | 75.0 | 125.0 | IronIngot ×5 + Ruby ×20 + FireRuby ×10 | ML | 710 |
| 1073455 | `DarkSapphireBracelet` | 75.0 | 125.0 | IronIngot ×5 + Sapphire ×20 + DarkSapphire ×10 | ML | 714 |
| 1073456 | `WhitePearlBracelet` | 75.0 | 125.0 | IronIngot ×5 + Tourmaline ×20 + WhitePearl ×10 | ML | 718 |
| 1073457 | `EcruCitrineRing` | 75.0 | 125.0 | IronIngot ×5 + Citrine ×20 + EcruCitrine ×10 | ML | 722 |
| 1073458 | `BlueDiamondRing` | 75.0 | 125.0 | IronIngot ×5 + Diamond ×20 + BlueDiamond ×10 | ML | 726 |
| 1073459 | `PerfectEmeraldRing` | 75.0 | 125.0 | IronIngot ×5 + Emerald ×20 + PerfectEmerald ×10 | ML | 730 |
| 1073460 | `TurqouiseRing` | 75.0 | 125.0 | IronIngot ×5 + Amethyst ×20 + Turquoise ×10 | ML | 734 |
| 1072933 | `ResilientBracer` | 100.0 | 125.0 | IronIngot ×2 + CapturedEssence ×1 + BlueDiamond ×10 + Diamond ×50 | recipe 452; `SetMinSkillOffset(25.0)`; FNE; ML | 738 |
| 1072935 | `EssenceOfBattle` | 100.0 | 125.0 | IronIngot ×2 + CapturedEssence ×1 + FireRuby ×10 + Ruby ×50 | recipe 450; min-skill offset 25; FNE; ML | 746 |
| 1072937 | `PendantOfTheMagi` | 100.0 | 125.0 | IronIngot ×2 + EyeOfTheTravesty ×1 + WhitePearl ×5 + StarSapphire ×50 | recipe 451; min-skill offset 25; FNE; ML | 755 |
| 1156991 | `DrSpectorsLenses` | 100.0 | **580.0** | IronIngot ×20 + BlackrockMoonstone ×1 + HatOfTheMagi ×1 | recipe 457; min-skill offset 25; FNE; TOL | 766 |
| 1157350 | `BraceletOfPrimalConsumption` | 100.0 | **580.0** | IronIngot ×3 + RingOfTheElements ×1 + BloodOfTheDarkFather ×5 + WhitePearl ×4 | recipe 456; min-skill offset 25; FNE; TOL | 773 |

---

### 4c.3 Bowcraft & Fletching — `DefBowFletching`

| Property | Value | Source |
|---|---|---|
| System class / singleton | `DefBowFletching` / `DefBowFletching.CraftSystem` | `DefBowFletching.cs:28,48-57` |
| Primary skill | `SkillName.Fletching` (client skill "Bowcraft & Fletching") | `DefBowFletching.cs:30-36` |
| Secondary skills | none (`AddSkill` never called) | `DefBowFletching.cs:122-261` |
| Min / max skill present | `0.0` (Kindling 0.0/0.0, Shaft, Arrow, Bolt) / `145.0` (`ElvenCompositeLongbow`) | `DefBowFletching.cs:133,172` |
| Effect timing | `base(1, 1, 1.25)` (comment: `// base( 1, 2, 1.7 )`) | `DefBowFletching.cs:64-67` |
| `GetChanceAtMin` | `0.5` for every item | `DefBowFletching.cs:59-62` |
| `ECA` | `FiftyPercentChanceMinusTenPercent` → exceptional roll uses `chance*0.5-0.1` | `DefBowFletching.cs:114-120`, `CraftItem.cs:1314-1316` |
| Gump title | cliloc `1044006` `// <CENTER>BOWCRAFT AND FLETCHING MENU</CENTER>` | `DefBowFletching.cs:38-44` |
| `CanCraft` preconditions | tool valid + accessible only (no forge) | `DefBowFletching.cs:69-79` |
| Craft sound | `0x55` | `DefBowFletching.cs:81-87` |
| Tool | `FletcherTools` → `DefBowFletching.CraftSystem` (label 1044559 "Fletcher's Tools", weight 2.0); runic variant `RunicFletcherTool` → same system | `FletcherTools.cs:9-10`, `RunicFletcherTool.cs:33` |
| Options | `MarkOption = true; Repair = Core.AOS; CanEnhance = Core.ML;` | `DefBowFletching.cs:258-260` |
| Sub-resource (wood type) | `Board 0.0`, `OakBoard 65.0`, `AshBoard 75.0`, `YewBoard 85.0`, `HeartwoodBoard 95.0`, `BloodwoodBoard 95.0`, `FrostwoodBoard 95.0`; default cliloc 1072643 | `DefBowFletching.cs:244-255` |
| Recipe enum | `BowRecipes`: magical 200-207, arties 250-254 | `DefBowFletching.cs:7-25` |
| Total live `AddCraft` calls | **27** | grep `AddCraft(` on `DefBowFletching.cs` |

#### Group 1044457 — "Materials" — 3 rows, lines 129–135

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1113346 | `ElvenFletching` | 90.0 | 130.0 | Feather ×20 + FaeryDust ×1 | `[ERA]` SA | 129 |
| 1023553 | `Kindling` | 0.0 | 0.0 | Board ×1 | – (Kindling used with Camping; `Kindling.cs:47-77`) | 133 |
| 1027124 | `Shaft` | 0.0 | 40.0 | Board ×1 | `SetUseAllRes(true)` | 135 |

#### Group 1044565 — "Ammunition" — 3 rows, lines 139–149

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1023903 | `Arrow` | 0.0 | 40.0 | Shaft ×1 + Feather ×1 | `SetUseAllRes(true)`; `Arrow : Item`, `Stackable = true`, weight 0.1 | 139 |
| 1027163 | `Bolt` | 0.0 | 40.0 | Shaft ×1 + Feather ×1 | `SetUseAllRes(true)` | 143 |
| 1030246 | `FukiyaDarts` | 50.0 | **73.8** | Board ×1 | `[ERA]` SE; `SetUseAllRes(true)` | 149 |

#### Group 1044566 — "Weapons" — 21 rows, lines 154–239

| Item (cliloc) | C# type | Min | Max | Resources | Flags / recipe | Line |
|---|---|---|---|---|---|---|
| 1025042 | `Bow` | 30.0 | 70.0 | Board ×7 | – | 154 |
| 1023919 | `Crossbow` | 60.0 | 100.0 | Board ×7 | – | 155 |
| 1025117 | `HeavyCrossbow` | 80.0 | 120.0 | Board ×10 | – | 156 |
| 1029922 | `CompositeBow` | 70.0 | 110.0 | Board ×7 | `[ERA]` AOS | 160 |
| 1029923 | `RepeatingCrossbow` | 90.0 | 130.0 | Board ×10 | AOS | 161 |
| 1030224 | `Yumi` | 90.0 | 130.0 | Board ×10 | `[ERA]` SE | 166 |
| 1031562 | `ElvenCompositeLongbow` | 95.0 | 145.0 | Board ×20 | ML; highest max skill in file | 172 |
| 1031551 | `MagicalShortbow` | 85.0 | 135.0 | Board ×15 | ML | 174 |
| 1072907 | `BlightGrippedLongbow` | 75.0 | 125.0 | Board ×20 + LardOfParoxysmus ×1 + Blight ×10 + Corruption ×10 | recipe 250, FNE; ML | 176 |
| 1072908 | `FaerieFire` | 75.0 | 125.0 | Board ×20 + LardOfParoxysmus ×1 + Putrefaction ×10 + Taint ×10 | recipe 251, FNE; ML | 183 |
| 1072955 | `SilvanisFeywoodBow` | 75.0 | 125.0 | Board ×20 + LardOfParoxysmus ×1 + Scourge ×10 + Muculent ×10 | recipe 252, FNE; ML | 190 |
| 1072910 | `MischiefMaker` | 75.0 | 125.0 | Board ×15 + DreadHornMane ×1 + Corruption ×10 + Putrefaction ×10 | recipe 253, FNE; ML | 197 |
| 1072912 | `TheNightReaper` | 75.0 | 125.0 | Board ×10 + DreadHornMane ×1 + Blight ×10 + Scourge ×10 | recipe 254, FNE; ML | 204 |
| 1073505 | `BarbedLongbow` | 75.0 | 125.0 | Board ×20 + FireRuby ×1 | recipe 200; ML | 211 |
| 1073506 | `SlayerLongbow` | 75.0 | 125.0 | Board ×20 + BrilliantAmber ×1 | recipe 201; ML | 215 |
| 1073507 | `FrozenLongbow` | 75.0 | 125.0 | Board ×20 + Turquoise ×1 | recipe 202; ML | 219 |
| 1073508 | `LongbowOfMight` | 75.0 | 125.0 | Board ×10 + BlueDiamond ×1 | recipe 203; ML | 223 |
| 1073509 | `RangersShortbow` | 75.0 | 125.0 | Board ×15 + PerfectEmerald ×1 | recipe 204; ML | 227 |
| 1073510 | `LightweightShortbow` | 75.0 | 125.0 | Board ×15 + WhitePearl ×1 | recipe 205; ML | 231 |
| 1073511 | `MysticalShortbow` | 75.0 | 125.0 | Board ×15 + EcruCitrine ×1 | recipe 206; ML | 235 |
| 1073512 | `AssassinsShortbow` | 75.0 | 125.0 | Board ×15 + DarkSapphire ×1 | recipe 207; ML | 239 |

#### Bowcraft chain: boards → bows / arrows / bolts (what the numbers actually imply)

1. **Board source**: the fletching menu draws `Board` (cliloc 1044041) and accepts `Log` as the same resource
   through the gump's `m_TypesTable` pair (`CraftGump.cs:277`); the sub-resource list also offers
   `OakBoard/AshBoard/YewBoard/HeartwoodBoard/BloodwoodBoard/FrostwoodBoard` (`DefBowFletching.cs:249-255`).
2. **Board → Shaft**: `Shaft` = Board ×1, min 0.0 / max 40.0, `UseAllRes` (`DefBowFletching.cs:135-136`).
   Shaft is stackable, weight 0.1 (`Shaft.cs:14-32`).
3. **Shaft + Feather → Arrow / Bolt**: `Shaft ×1 + Feather ×1`, min 0.0 / max 40.0, `UseAllRes`
   (`DefBowFletching.cs:139-145`). **Bundle size is not a constant in server source** — with `UseAllRes` the
   produced amount is computed at craft time as
   `maxAmount = min(floor(shafts_available / 1), floor(feathers_available / 1))` (`CraftItem.cs:992-1000`)
   and assigned via `item.Amount = maxAmount` (`CraftItem.cs:1842-1851`). One click therefore yields
   as many arrows as the scarcer of the two resources allows; the gump shows
   "Makes as many as possible at once" (1048176, `CraftGumpItem.cs:89-90`).
   `[UNVERIFIED]` — a *fixed* per-craft bundle count (e.g. a hard 10/20 arrows) does not exist in ServUO
   source; verifying client-side/vendor bundle conventions would require reading the ClassicUO client
   `Arrow`/`Bolt` handling or a live shard's vendor stock.
4. **Board → bows/crossbows**: `Board ×7` (Bow), `×7` (Crossbow), `×10` (HeavyCrossbow), plus the AOS/SE/ML
   entries above; ML bows additionally consume ML peerless reagents and a recipe.
5. **FletcherTools**: crafted in Tinkering (`DefTinkering.cs:348`, IronIngot ×3, 35.0–85.0), opens the
   fletching gump (`FletcherTools.cs:9`), `BaseTool` default uses 25–75 (`BaseTool.cs:112-115`);
   `RunicFletcherTool` (`RunicFletcherTool.cs:33`) uses the same system for runic crafting.
6. **Kindling** (Board ×1, 0.0/0.0) is not an arrow component: double-clicking it attempts a Camping check
   `CheckSkill(SkillName.Camping, 0.0, 100.0)` to light a `Campfire` (`Kindling.cs:47-77`).

---

### 4c.4 Glassblowing + sand mining

| Property | Value | Source |
|---|---|---|
| System class / singleton | `DefGlassblowing` / `DefGlassblowing.CraftSystem` | `DefGlassblowing.cs:7,15-24` |
| Primary skill | `SkillName.Alchemy` (glass items are made with **Alchemy**, not a separate skill) | `DefGlassblowing.cs:25-31` |
| Secondary skills | none | `DefGlassblowing.cs:108-160` |
| Min / max skill present | `52.5` (Bottle, SmallFlask, MediumFlask) / `190.0` (`EtherealSoulbinder`) | `DefGlassblowing.cs:110,148` |
| Effect timing | `base(1, 1, 1.25)` (comment: `// base( 1, 2, 1.7 )`) | `DefGlassblowing.cs:10-11` |
| `GetChanceAtMin` | `0.5` for `HollowPrism`; `0.1` for `EtherealSoulbinder`; `0.0` otherwise | `DefGlassblowing.cs:39-48` |
| `ECA` | not overridden → base default `ChanceMinusSixty` (`chance-0.6`) | `CraftSystem.cs:104-110`, `CraftItem.cs:1311-1313` |
| Gump title | cliloc `1044622` `// <CENTER>Glassblowing MENU</CENTER>` | `DefGlassblowing.cs:32-38` |
| `CanCraft` preconditions | tool valid+accessible; `from is PlayerMobile && pm.Glassblowing` **and** `Skills[Alchemy].Base >= 100.0`; and `DefBlacksmithy.CheckAnvilAndForge(from, 2, out anvil, out forge)` must report `forge == true` (range 2 tiles) else 1044628 "You must be near a forge to blow glass." | `DefGlassblowing.cs:50-71`, `DefBlacksmithy.cs:104` |
| Craft sounds | start `0x2B` (bellows), end `0x41` (glass breaking) | `DefGlassblowing.cs:73-79`, `DefGlassblowing.cs:95` |
| Tool | `Blowpipe : BaseTool` → `DefGlassblowing.CraftSystem`, label cliloc 1044609 "Blow Pipe", itemID 0xE8A, hue 0x3B9 | `Blowpipe.cs:6-24` |
| Options | `Repair = Core.SA; MarkOption = Core.SA;` | `DefGlassblowing.cs:158-159` |
| Sub-resource | **none** (no `SetSubRes`/`AddSubRes` call — sand has no quality tiers) | `DefGlassblowing.cs:108-156` |
| Total live `AddCraft` calls | **22** (20 in group 1044050 + 2 in group 1111745) | grep `AddCraft(` on `DefGlassblowing.cs` |

#### Group 1044050 — glassware (no source comment) — 20 rows, lines 110–148

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1023854 | `Bottle` | 52.5 | 102.5 | Sand ×1 | `SetUseAllRes(true)` | 110 |
| 1044610 | `SmallFlask` | 52.5 | 102.5 | Sand ×2 | – | 113 |
| 1044611 | `MediumFlask` | 52.5 | 102.5 | Sand ×3 | – | 114 |
| 1044612 | `CurvedFlask` | 55.0 | 105.0 | Sand ×2 | – | 115 |
| 1044613 | `LongFlask` | 57.5 | 107.5 | Sand ×4 | – | 116 |
| 1044623 | `LargeFlask` | 60.0 | 110.0 | Sand ×5 | – | 117 |
| 1044614 | `AniSmallBlueFlask` | 60.0 | 110.0 | Sand ×5 | – | 118 |
| 1044615 | `AniLargeVioletFlask` | 60.0 | 110.0 | Sand ×5 | – | 119 |
| 1044624 | `AniRedRibbedFlask` | 60.0 | 110.0 | Sand ×7 | – | 120 |
| 1044616 | `EmptyVialsWRack` | 65.0 | 115.0 | Sand ×8 | – | 121 |
| 1044617 | `FullVialsWRack` | 65.0 | 115.0 | Sand ×9 | – | 122 |
| 1044618 | `SpinningHourglass` | 75.0 | 125.0 | Sand ×10 | – | 123 |
| 1072895 | `HollowPrism` | 100.0 | 150.0 | Sand ×8 | `[ERA]` ML gate; `GetChanceAtMin` 0.5 | 127 |
| 1095314 | `GargoyleFloorMirror` | 75.0 | 125.0 | Sand ×20 | `[ERA]` SA gate | 132 |
| 1095324 | `GargoyleWallMirror` | 70.0 | 120.0 | Sand ×10 | SA | 134 |
| 1071000 | `SoulstoneFragment` | 70.0 | 120.0 | CrystalGranules ×2 + VoidEssence ×2 | SA; `SetItemHue(1150)`; resource name 1112329 / 1112327 | 136-138 |
| 1112215 | `EmptyVenomVial` | 52.5 | 102.5 | Sand ×1 | SA | 140 |
| 1150866 | `EmptyOilFlask` | 60.0 | 110.0 | Sand ×5 | SA (ModernUO differs — see 4c.6) | 142 |
| 1154170 | `WorkableGlass` | 55.0 | 105.0 | Sand ×10 | SA; label 1154170, itemID 19328, stackable, weight 1.0 | 144 |
| 1159167 | `EtherealSoulbinder` | 100.0 | 190.0 | Sand ×20 + EtherealSand ×5 | SA **and** `Core.EJ` gate (`if (Core.EJ)` nested inside `if (Core.SA)`); `GetChanceAtMin` 0.1 | 146-150 |

#### Group 1111745 — "Glass Weapons" (source comment `//Glass Weapons`) — 2 rows, lines 153–155

| Item (cliloc) | C# type | Min | Max | Resources | Flags | Line |
|---|---|---|---|---|---|---|
| 1022316 | `GlassSword` | 55.0 | 105.0 | Sand ×14 | `[ERA]` SA gate | 153 |
| 1095368 | `GlassStaff` | 53.6 | 103.6 | Sand ×10 | SA | 155 |

#### (a) Glassblowing whole chain: sand → glass → items

| Step | Mechanic | Source |
|---|---|---|
| 1. Learn sand mining | `SandMiningBook` ("Find Glass-Quality Sand", label 1153531, weight 2.0, itemID 0xFF4). Double-click: item must be in pack; requires `Skills[Mining].Base >= 100.0` (else 1080041 "Only a Grandmaster Miner can learn from this book."); sets `pm.SandMining = true`; book deletes itself | `SandMiningBook.cs:8,11-15,39-67` |
| 2. Learn glassblowing | `GlassblowingBook` ("Crafting glass with Glassblowing", label 1153528, weight 5.0). Requires `Skills[Alchemy].Base >= 100.0` (else 1080042); sets `pm.Glassblowing = true` (else 1080065) | `GlassblowingBook.cs:8,11-15,39-67` |
| 3. Vendor | `SBGlassblower` sells `GlassblowingBook` and `SandMiningBook` at 10637 gp each, `Blowpipe` at 21 gp, `Bottle` 5 gp; sells back books at 5000, Blowpipe 10 | `SBGlassblower.cs:54-60,88-90` |
| 4. Mine sand | `Mining.Sand` `HarvestDefinition`: bank 8×8 tiles, `MinTotal 6 / MaxTotal 13`, respawn 10–20 min, skill `Mining`, tiles `m_SandTiles`, range 2, `ConsumedPerHarvest 1` / `ConsumedPerFeluccaHarvest 2`, effect actions `Core.SA ? 3 : 11`, sounds `0x125/0x126`, `EffectCounts { 6 }`, delay 1.6 s. Resource: `HarvestResource(100.0, 70.0, 100.0, 1044631, typeof(Sand))`, single vein at 100.0. Messages 1044629/503041/500446/1044630/1044632/1044038 | `Mining.cs:128-183` |
| 5. Sand gate | Harvesting the `Sand` definition is refused unless `from is PlayerMobile && Skills[Mining].Base >= 100.0 && pm.SandMining` → otherwise "bad harvest target" | `Mining.cs:286-290` |
| 6. Sand item | `Sand : Item, ICommodity`, label 1044626 "sand", itemID 0x423A, hue 2413, stackable, weight 0.1 | `Sand.cs:5-23` |
| 7. Blow glass | `Blowpipe` + `DefGlassblowing` gump; requires GM Alchemy + `Glassblowing` flag + forge within 2 tiles (`DefGlassblowing.cs:50-71`). All items are made **directly from sand** — there is no intermediate "glass" resource in the finished-goods list | `DefGlassblowing.cs:108-156` |
| 8. Intermediate that *is* glass | `WorkableGlass` (SA, 10 sand, 55.0–105.0, `DefGlassblowing.cs:144`) is the only glass output consumed by another craft system: Tinkering `DragonLamp`/`StainedGlassLamp`/`TallDoubleLamp` ×1 (`DefTinkering.cs:461,466,471`), `KotlPowerCore` ×5 (`:535`), `PersonalTelescope` ×1 (`:659`) | `WorkableGlass.cs:6-24` |
| 9. Non-sand glass resources | `SoulstoneFragment` needs `CrystalGranules ×2` + `VoidEssence ×2` (`DefGlassblowing.cs:136-137`); `CrystalGranules` label 1112329 has **no** crafting recipe in the tree (no `new CrystalGranules` anywhere) → obtained outside the craft system; `EtherealSoulbinder` needs `EtherealSand ×5` (`:149`), which per the official wiki dropped from Corgul the Soulbinder during the Treasures of the Sea event | `MiscSAResources.cs:197-206`, grep `new CrystalGranules`; `[WEB]` [Glassblowing (uo.com)](https://uo.com/wiki/ultima-online-wiki/skills/alchemy/glassblowing/) |
| 10. Era | Base glassware rows carry **no Core gate** → available in every era in ServUO; all their clilocs sit in the 1044xxx AoS-era block (e.g. gump title 1044622, sand 1044625/1044626, Blow Pipe 1044609), and UOGuide notes pre-Publish-56 sand was unstackable, i.e. sand mining existed before Publish 56 (2008) and therefore before Stygian Abyss (2009). Exact expansion/publish that introduced the base system: **`[UNVERIFIED]`** — would need the uo.com publish-note archive or a cliloc-dating check; the era-gated additions are sourced: `HollowPrism` = ML (`DefGlassblowing.cs:125`), mirrors / venom vial / workable glass / glass weapons = SA (`:130-156`), `EtherealSoulbinder` = SA + EJ (`:146-150`). `[WEB]` [UOGuide — Sand](https://www.uoguide.com/Sand) states the books are bought from the Gargoyle Alchemist in Royal City, Ter Mur | `DefGlassblowing.cs:108-159` |
| 11. Sand tile list | `m_SandTiles` = 22-75, 286-301, 402, 424-427, 441-465, 642-645, 650-657, 821-836, 845-852, 857-860, 951-958, 967-970, 1447-1458, 1611-1618, 1623-1626, 1635-1642, 1647-1650 (beach/sand tiles) | `Mining.cs:544-565` |

---

### 4c.5 (c) Crafted tools → which skill they unlock

Every tool below is craftable **in the Tinkering menu** unless noted. "Opens" = the `CraftSystem` property
returned by the tool class (this is what a double-click sends as `new CraftGump(from, system, this, null)`,
`BaseTool.cs:219-247`).

| Crafted tool | Tinker craft (cliloc, min–max, cost) | Opens system | Tool source |
|---|---|---|---|
| `SewingKit` | 1023997, 10.0–70.0, IronIngot ×2 (`DefTinkering.cs:334`) | `DefTailoring.CraftSystem` | `SewingKit.cs:31` |
| `FletcherTools` | 1044166, 35.0–85.0, IronIngot ×3 (`:348`) | `DefBowFletching.CraftSystem` | `FletcherTools.cs:9` |
| `ScribesPen` | 1044168, 25.0–75.0, IronIngot ×1 (`:350`) | `DefInscription.CraftSystem` | `ScribesPen.cs:9` |
| `MortarPestle` | 1023739, 20.0–70.0, IronIngot ×3 (`:329`) | `DefAlchemy.CraftSystem` | `MortarPestle.cs:31` |
| `Saw` | 1024148, 30.0–80.0, IronIngot ×4 (`:335`) | `DefCarpentry.CraftSystem` | `Saw.cs:32` |
| `DovetailSaw` | 1024136, 30.0–80.0, IronIngot ×4 (`:336`) | Carpentry | `DovetailSaw.cs:32` |
| `DrawKnife` | 1024324, 30.0–80.0, IronIngot ×2 (`:333`) | Carpentry | `DrawKnife.cs:31` |
| `Froe` | 1024325, 30.0–80.0, IronIngot ×2 (`:337`) | Carpentry | `Froe.cs:31` |
| `Inshave` | 1024326, 30.0–80.0, IronIngot ×2 (`:343`) | Carpentry | `Inshave.cs:31` |
| `JointingPlane` | 1024144, 0.0–50.0, Board ×4 (`:239`) | Carpentry | `JointingPlane.cs:32` |
| `MouldingPlane` | 1024140, 0.0–50.0, Board ×4 (`:240`) | Carpentry | `MouldingPlane.cs:32` |
| `SmoothingPlane` | 1024146, 0.0–50.0, Board ×4 (`:241`) | Carpentry | `SmoothingPlane.cs:32` |
| `Scorp` | 1024327, 30.0–80.0, IronIngot ×2 (`:330`) | Carpentry | `Scorp.cs:31` |
| **`Hammer`** | 1024138, 30.0–80.0, IronIngot ×1 (`:339`) | **`DefCarpentry.CraftSystem`** — *not* Blacksmithy | `Hammer.cs:31` |
| `Nails` | not craftable in any of the four files (no `AddCraft(typeof(Nails)…)`) | Carpentry | `Nails.cs:32` |
| `Tongs` | 1024028, 35.0–85.0, IronIngot ×1 (`:340`) | `DefBlacksmithy.CraftSystem` | `Tongs.cs:32` |
| `SmithyHammer` (`Core.AOS`) / `SmithHammer` | 1025091, 40.0–90.0, IronIngot ×4 (`:341`) | Blacksmithy (`SmithyHammer : BaseBashing, ITool`) | `SmithHammer.cs:32,61` |
| `SledgeHammerWeapon` (`Core.AOS`) / `SledgeHammer` | 1024021, 40.0–90.0, IronIngot ×4 (`:342`) | Blacksmithy | `SledgeHammer.cs:32,61` |
| `MapmakersPen` | 1044167, 25.0–75.0, IronIngot ×1 (`:349`) | `DefCartography.CraftSystem` | `MapmakersPen.cs:32` |
| `Skillet` | 1044567, 30.0–80.0, IronIngot ×4 (`:346`) | `DefCooking.CraftSystem` | `Skillet.cs:38` |
| `FlourSifter` | 1024158, 50.0–100.0, IronIngot ×3 (`:347`) | Cooking | `FlourSifter.cs:31` |
| `RollingPin` | 1024163, 0.0–50.0, Board ×5 (`DefTinkering.cs:244`) | Cooking | `RollingPin.cs:31` |
| `TinkerTools` | 1044164, 10.0–60.0, IronIngot ×2 (`:331`) | `DefTinkering.CraftSystem` | `TinkerTools.cs:29-35` |
| `Clippers` | 1112117, 50.0–50.0, IronIngot ×4 (`:351`) | Tinkering property, but double-click opens a **plant target**, not a gump | `Clippers.cs:151-181` |
| `Blowpipe` | **not** craftable (vendor only, 21 gp; `SBGlassblower.cs:60`) | `DefGlassblowing.CraftSystem` | `Blowpipe.cs:9` |
| `MalletAndChisel` | **not** craftable in Craft (vendor `SBStoneCrafter.cs:50` at 3 gp, loot `FillableContainers.cs:1003`, `Meraktus.cs:156`; runic version from BOD rewards `Rewards.cs:1211-1230`) | `DefMasonry.CraftSystem` | `MalletAndChisel.cs:31` |
| `Lockpick` | 1025371, 45.0–95.0, IronIngot ×1 (`:345`) | **No craft system** — `Lockpick : Item` (`LockPick.cs:19`); double-click targets `ILockpickable` and resolves with `CheckTargetSkill(SkillName.Lockpicking, …)` (`LockPick.cs:142`), 25 % break chance on failure (`LockPick.cs:91-102`) | `LockPick.cs:60-64` |
| `Scissors` | 1023998, 5.0–55.0, IronIngot ×2 (`:328`) | **No craft system** — `Scissors : Item`; targets `IScissorable` (cloth/hides/armor), `Cloth.Scissor` produces `Bandage` ×1 (`Cloth.cs:80-88`); 50 base uses (`Scissors.cs:51`); no gump | `Scissors.cs:132-137` |
| `Hatchet` | 1023907, 30.0–80.0, IronIngot ×4 (`:332`) | **No craft system** — `Hatchet : BaseAxe` (Lumberjacking) | `Hatchet.cs:8` |
| `Pickaxe` | 1023718, 40.0–90.0, IronIngot ×4 (`:344`) | **No craft system** — `Pickaxe : BaseAxe, IHarvestTool`, `HarvestSystem = Mining.System`, 50 uses | `Pickaxe.cs:7-29` |
| `Shovel` | 1023898, 40.0–90.0, IronIngot ×4 (`:338`) | **No craft system** — `Shovel : BaseHarvestTool` (Mining), 50 default uses | `Shovel.cs:6`, `BaseHarvestTool.cs:103-113` |
| `ButcherKnife` / `Cleaver` / `SkinningKnife` / `Pitchfork` | utensils/weapons (`DefTinkering.cs:384,390,395,361`) | **No craft system** — `BaseKnife` / weapon classes | `ButcherKnife.cs:8`, `Cleaver.cs:8`, `SkinningKnife.cs:6` |
| `RunicSewingKit` / `RunicFletcherTool` / `RunicHammer` / `RunicDovetailSaw` / `RunicMalletAndChisel` | runic, **not** crafted (BOD reward / loot boxes) | Tailoring / Fletching / Blacksmithy / Carpentry / Masonry | `RunicSewingKit.cs:33`, `RunicFletcherTool.cs:33`, `RunicHammer.cs:36`, `RunicDovetailSaw.cs:33`, `RunicMalletAndChisel.cs:9` |

Note on the task's assumption: the prompt pairs "Tongs/Hammer → Blacksmithy" and "Lockpick → Lockpicking".
Source says otherwise for `Hammer` (→ Carpentry, `Hammer.cs:31`) and for `Lockpick` (no craft gump at all —
it is a Lockpicking *targeting* item, `LockPick.cs:19,142`). Both facts are `[SRC]` from the pub57 checkout.

---

### 4c.6 ServUO vs ModernUO (divergences relevant to these four menus) `[SRC]`

| Aspect | ServUO `pub57` | ModernUO (`Projects/UOContent/Engines/Craft/`) |
|---|---|---|
| `AddCraft` count | Carpentry 223, Tinkering 165, BowFletching 27, Glassblowing 22 | Carpentry 154, Tinkering 96, BowFletching 26, Glassblowing 13 |
| Resource type in the wood systems | `Board` (+ `Log` accepted via `CraftGump.cs:277`) | `Log` everywhere, plus an explicit Board-from-Log craft: `AddCraft(typeof(Board), 1044294, 1027127, 0.0, 0.0, typeof(Log), 1044466, 1, 1044465)` (`DefCarpentry.cs:95`) |
| Era-expansion enforcement | separate `if (Core.X)` blocks and `SetNeededThemePack` | additionally `SetNeededExpansion(index, Expansion.X)` per row (`DefGlassblowing.cs:124`, `DefBowFletching.cs:112`) |
| Glassblowing scope | 22 rows incl. full SA block (mirrors, venom vial, oil flask, workable glass, glass weapons) and EJ `EtherealSoulbinder` | 13 rows: ML `HollowPrism` only; **no** SA glass rows at all (`DefGlassblowing.cs:105-125`) |
| `GetChanceAtMin` (glass) | `HollowPrism 0.5`, `EtherealSoulbinder 0.1`, else `0.0` | `HollowPrism 0.5`, else `0.0` (`DefGlassblowing.cs:24`) |
| `EmptyOilFlask` | SA-gated, 60.0–110.0, Sand ×5 (`DefGlassblowing.cs:142`) | ungated, 70.0–120.0, Sand ×5 (`DefGlassblowing.cs:113`) |
| FukiyaDarts | 50.0–**73.8** (`DefBowFletching.cs:149`) | 50.0–**90.0** (`DefBowFletching.cs:110`) |
| ML bows | `FaerieFire` and `MischiefMaker` are live rows | both are commented-out `/* TODO */` blocks (`DefBowFletching.cs:152-160,180-188`) |
| Wood sub-resource skill tiers | Oak 65 / Ash 75 / Yew 85 / Heartwood 95 / Bloodwood 95 / Frostwood 95 (`DefBowFletching.cs:250-255`) | Oak 65 / Ash 80 / Yew 95 / Heartwood 100 / Bloodwood 100 / Frostwood 100 (`DefBowFletching.cs:265-270`) |
| ML bow recipe IDs | 200-207 `BowRecipes` | `AddRecipe(index, 205…212)` and `AddRareRecipe(index, 200…204)` (`DefBowFletching.cs:148,200-256`) |
| Carpentry group titles | hard-coded clilocs per group (e.g. weapons always `1044566`) | era-dependent group: `Core.ML ? 1044566 : 1044295` (`DefCarpentry.cs:305-307,318-322,356`), anvils group `1044296` vs ServUO `1111809` |
| Tinkering jewelry | 9 gem sets × 6 items via `AddJewelrySet` (54 rows) | plain-string rows only: `"gold necklace"`, `"silver necklace"`, `"gold earrings"`, `"silver earrings"`, `"gold ring"`, `"silver ring"`, `"wedding ring"` (`DefTinkering.cs:396-402`) |
| Tinkering SA/ML/TOL blocks | basket-weaving, ML magic jewelry, SA assemblies, TOL automaton/telescope all present | absent from that checkout (96 call sites end at traps + magic jewelry partially) |

---

### 4c.7 Row-count summary and gaps

| System (file) | Groups | Live `AddCraft` call sites | Gump rows at runtime | File lines |
|---|---|---|---|---|
| Carpentry `DefCarpentry.cs` | 10 | 223 (+1 commented at :475) | 223 | 995 |
| Tinkering `DefTinkering.cs` | 9 | 165 | **213** (152 direct sites + Jewelry 7 inline + 6 helper sites × 9 gems = 61) | 979 |
| Bowcraft/Fletching `DefBowFletching.cs` | 3 | 27 | 27 | 263 |
| Glassblowing `DefGlassblowing.cs` | 2 | 22 | 22 | 178 |

`[UNVERIFIED]` / open items (no number invented):

* Exact expansion/publish that introduced **base** glassblowing and **sand mining** — the base rows are not
  Core-gated in ServUO, all related clilocs are in the 1044xxx block, and UOGuide documents sand mining
  existing before Publish 56 (2008). Resolving it needs the uo.com publish-note archive or cliloc dating.
* Fixed arrow/bolt **bundle sizes** — ServUO computes them at craft time from available shafts/feathers
  (`CraftItem.cs:992-1000,1842-1851`); any fixed client/vendor convention would have to be measured in
  ClassicUO or on a live shard.
* cliloc **text** for every name/number used in the tables: the cliloc files are not part of the ServUO
  source tree, so table "display" columns show the numeric `TextDefinition` exactly as passed to `AddCraft`.
  Some strings are recoverable from in-source comments (e.g. 1044004 CARPENTRY MENU, 1044007 TINKERING MENU,
  1044006 BOWCRAFT AND FLETCHING MENU, 1044622 Glassblowing MENU, 1048176 "Makes as many as possible at once",
  1154195/1150651/1150650 theme-pack requirements), and those are quoted where present.
* Whether the `IronIngot`/cliloc-1038039 pairing on the four `WeatheredBronze*` deeds (`DefTinkering.cs:542-551`)
  is intended: transcribed literally, no source comment explains it.
* `small display case` rows (`DefTinkering.cs:828-832`) carry no `SetNeededThemePack` while their siblings do —
  flagged as-is; the reason is not in source.

## 4d. Crafting menus — Alchemy, Inscription, Cooking, Cartography

Source of truth: ServUO `pub57`. Every row below is one `AddCraft(...)` call. Nothing is paraphrased;
constants are quoted as literals. Where a display string lives only in a cliloc table that is **not**
present in the repo, the row carries the cliloc number and a class-derived English name marked `[PARTIAL]`.

### 4d.0 Citation key

| Short | Full path (relative to `E:\Workspaces\game-clone\.research-src\servuo`) | GitHub (branch `pub57`) |
|---|---|---|
| `DefAlchemy.cs` | `Scripts/Services/Craft/DefAlchemy.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefAlchemy.cs |
| `DefInscription.cs` | `Scripts/Services/Craft/DefInscription.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefInscription.cs |
| `DefCooking.cs` | `Scripts/Services/Craft/DefCooking.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefCooking.cs |
| `DefCartography.cs` | `Scripts/Services/Craft/DefCartography.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefCartography.cs |
| `DefMasonry.cs` | `Scripts/Services/Craft/DefMasonry.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefMasonry.cs |
| `CraftSystem.cs` | `Scripts/Services/Craft/Core/CraftSystem.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/Core/CraftSystem.cs |
| `CraftItem.cs` | `Scripts/Services/Craft/Core/CraftItem.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/Core/CraftItem.cs |
| `BasePotion.cs` | `Scripts/Items/Consumables/BasePotion.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Consumables/BasePotion.cs |
| `Inscribe.cs` | `Scripts/Skills/Inscribe.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Inscribe.cs |
| `CookableFood.cs` | `Scripts/Items/Consumables/CookableFood.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Consumables/CookableFood.cs |
| `TreasureMap.cs` | `Scripts/Services/TreasureMaps/TreasureMap.cs` | https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/TreasureMaps/TreasureMap.cs |
| `ModernUO BasePotion.cs` | `Projects/UOContent/Items/Skill Items/Magical/Potions/BasePotion.cs` | https://github.com/modernuo/ModernUO/blob/main/Projects/UOContent/Items/Skill%20Items/Magical/Potions/BasePotion.cs |

### 4d.1 Shared crafting machinery (applies to all five menus) `[SRC]`

**`AddCraft` argument order** — `CraftSystem.cs:329-352`:

```
AddCraft(Type typeItem, TextDefinition group, TextDefinition name,
         [SkillName skillToMake,] double minSkill, double maxSkill,
         Type typeRes, TextDefinition nameRes, int amount[, TextDefinition message])
```
- 8-arg and 9-arg overloads use `MainSkill` implicitly (`CraftSystem.cs:329,334`); the 9/10-arg forms take an explicit skill (`:339,344`).
- The call registers **exactly one** resource (`typeRes × amount`) and **exactly one** skill (`:346-348`). Everything else is added afterwards by index: `AddRes`, `AddSkill`, `SetManaReq`, `SetNeedHeat`, …
- The group object is created/deduplicated by cliloc via `DoGroup` (`:354-368`), so group order = first-appearance order in `InitCraftList`.
- Return value = index into `m_CraftItems`; `AddRes(index, …)` etc. address that index (`CraftSystem.cs:495-558`).
- `CraftRes` = `(Type, name TextDefinition, amount, message TextDefinition)` — `CraftRes.cs:13-27`. The message is sent verbatim when that resource is missing (`CraftRes.cs:71-79`).
- `CraftSubRes` = `(Type, name, double reqSkill, genericName, message)` — `CraftSubRes.cs:13-26`; `RequiredSkill` is enforced at `CraftItem.cs:968-972` (`from.Skills[craftSystem.MainSkill].Base < subResource.RequiredSkill` → abort with `subResource.Message`).
- `CraftGroup` is just `(TextDefinition groupName, CraftItemCol)` — `CraftGroup.cs:10-15,38-41`.

**Per-system constructor / header** `[SRC]`:

| System | `MainSkill` | Gump cliloc | `base(minEffect, maxEffect, delay)` | literal comment left in source | `GetChanceAtMin` |
|---|---|---|---|---|---|
| Alchemy | `SkillName.Alchemy` (`DefAlchemy.cs:18-24`) | 1044001 (`:26-32`) | `base(1, 1, 1.25)` (`:53`) | `// base( 1, 1, 3.1 )` | `0.0` (`:47-50`) |
| Inscription | `SkillName.Inscribe` (`DefInscription.cs:14-20`) | 1044009 (`:22-28`) | `base(1, 1, 1.25)` (`:49`) | `// base( 1, 1, 3.0 )` | `0.0` (`:43-46`) |
| Cooking | `SkillName.Cooking` (`DefCooking.cs:27-33`) | 1044003 (`:35-41`) | `base(1, 1, 1.25)` (`:76`) | `// base( 1, 1, 1.5 )` | `0.0`, except `GrapesOfWrath`/`EnchantedApple` → `.5` (`:64-73`) |
| Cartography | `SkillName.Cartography` (`DefCartography.cs:30-36`) | 1044008 (`:37-43`) | `base(1, 1, 1.25)` (`:16`) | `// base( 1, 1, 3.0 )` | `0.0` (`:44-47`) |
| Masonry | **`SkillName.Carpentry`** (`DefMasonry.cs:15-21`) | 1044500 (`:23-29`) | `base(1, 1, 1.25)` (`:50`) | `// base( 1, 2, 1.7 )` | `0.0` (`:44-47`) |

**Tool gate (`CanCraft`)** — identical simple form in Alchemy (`DefAlchemy.cs:57-67`), Inscription (`DefInscription.cs:53-89`), Cooking (`DefCooking.cs:80-90`), Cartography (`DefCartography.cs:49-59`):
`tool == null || tool.Deleted || tool.UsesRemaining <= 0` → `1044038` ("You have worn out your tool!"); else `!tool.CheckAccessible(from, ref num)` → `num` ("The tool must be on your person to use.").
Inscription adds the spellbook gate; Masonry adds the stonecraft gate (§4d.6).

**Success chance** — `CraftItem.cs:1367-1438` `[SRC]`:
```
ForceSuccessChance > -1                 → return ForceSuccessChance / 100.0          (:1369-1372)
minMainSkill = craftSkill.MinSkill - MinSkillOffset                                 (:1384)
maxMainSkill = craftSkill.MaxSkill                                                  (:1385)
valMainSkill = from.Skills[craftSkill.SkillToMake].Value                            (:1386)
allRequiredSkills = AND over all Skills[ ] of (valSkill >= minSkill)                (:1388-1391)
if allRequiredSkills:
    chance = GetChanceAtMin(item)
           + ((valMainSkill - minMainSkill) / (maxMainSkill - minMainSkill) * (1.0 - GetChanceAtMin(item)))   (:1410-1411)
else chance = 0.0                                                                   (:1415)
if allRequiredSkills && valMainSkill == maxMainSkill: chance = 1.0                  (:1433-1436)
+ talisman.SuccessBonus/100 (talisman.CheckSkill)                                   (:1418-1426)
+ 0.5 if WoodworkersBench.HasBonus                                                    (:1428-1431)
```
Roll: `CheckSkills` returns `chance > Utility.RandomDouble()` (`CraftItem.cs:1359`). Note `minSkill` here is compared against **`Value`** (skill + item bonuses), not `Base`.

**Exceptional ("quality" 2)** — `CraftItem.cs:1268-1341`:
`ForceNonExceptional` → `0.0`; `ForceExceptional` + allRequiredSkills → `100.0`; else take `chance` and apply `system.ECA`:
`ChanceMinusSixty` → `chance -= 0.6`; `FiftyPercentChanceMinusTenPercent` → `chance = chance*0.5 - 0.1`;
`ChanceMinusSixtyToFourtyFive` → `offset = 0.60 - ((from.Skills[MainSkill].Value - 95.0) * 0.03)` clamped to `[0.45, 0.60]`, then `chance -= offset` (`:1317-1332`).
Bonuses added after: talisman `ExceptionalBonus/100`, `MasterChefsApron.Bonus/100`, `+0.3` for WoodworkersBench (`:1284-1306`).
**Only Cooking overrides `ECA`** → `CraftECA.ChanceMinusSixtyToFourtyFive` (`DefCooking.cs:56-62`); the other four use the default `ChanceMinusSixty` (`CraftItem.cs:1310-1312`).

**Consumable-attribute cost** — `CraftItem.cs:235-310`: `Hits`, `Mana`, `Stam` must be available before the craft and are subtracted on success. Inscription is the only one of these five systems that sets `Mana` (via `SetManaReq`). Mana can be waived by `ChronicleOfTheGargoyleQueen1` charges or `ManaPhasingOrb` (`CraftItem.cs:253-270`).

**Station requirements** — `CraftItem.cs:313-358` + checks at `:911-939`:

| Flag | Setter | Required item IDs | Failure cliloc |
|---|---|---|---|
| `NeedHeat` | `SetNeedHeat` (`CraftSystem.cs:406-410`) | `0x461,0x48E,0x92B,0x96C,0xDE3,0xDE9,0xFAC,0x184A,0x184C,0x184E,0x1850,0x398C,0x399F,0x2DDB,0x2DDC,0x19AA,0x19BB,0x197A,0x19A9,0x0FB1,0x2DD8,0xA2A4,0xA2A5,0xA2A8,0xA2A9` (`:313-328`) | `1044487` "You must be near a fire source to cook." |
| `NeedOven` | `SetNeedOven` (`:412-416`) | `0x461,0x46F,0x92B,0x93F,0x2DDB,0x2DDC` (`:330-335`) | `1044493` "You must be near an oven to bake that." |
| `NeedMaker` | `SetNeedMaker` (`:418-422`) | `0x9A96` (`:337-340`) | `1155732` "You must be near a steam powered beverage maker…" |
| `NeedMill` | `SetNeedMill` (`:436-440`) | `0x1920,0x1921,0x1922,0x1923,0x1924,0x1295,0x1926,0x1928,0x192C,0x192D,0x192E,0x129F,0x1930,0x1931,0x1932,0x1934` (`:342-346`) | `1044491` "You must be near a flour mill to do that." |
| `NeedWater` | `SetNeedWater` (`:424-428`) | `0xB41,0xB44,0xE7B,0xFFA,0x154D,0x99CA,0x99CB,0x9A14,0x9A19,0xA2AF,0xA2B9,0x2AC0,0x2AC5` (`:348-358`) + `KoiPondAddon`/`DragonTurtleFountainAddon`/`WaterWheelAddon` (`:587-612`) | `1158882` "You must be near a water source…" |

Proximity = within 2 tiles of the mobile and Z-overlap `(item.Z+16) > from.Z && (from.Z+16) > item.Z` (`CraftItem.cs:528-573`).

**Resource equivalence groups (`ItemTypesTable`, `CraftItem.cs:360-383`)** — a resource declared as column 0 is satisfied by any type in its row. This is the "Sub-res" column in the tables below:
`Board≡Log`, `HeartwoodBoard≡HeartwoodLog`, `BloodwoodBoard≡BloodwoodLog`, `FrostwoodBoard≡FrostwoodLog`, `OakBoard≡OakLog`, `AshBoard≡AshLog`, `YewBoard≡YewLog`, `Leather≡Hides`, `SpinedLeather≡SpinedHides`, `HornedLeather≡HornedHides`, `BarbedLeather≡BarbedHides`, **`BlankMap≡BlankScroll`**, `Cloth≡UncutCloth≡AbyssalCloth`, `CheeseWheel≡CheeseWedge`, `Pumpkin≡SmallPumpkin`, `WoodenBowlOfPeas≡PewterBowlOfPeas`, `CrystallineFragments≡BrokenCrystals≡ShatteredCrystals≡ScatteredCrystals≡CrushedCrystals≡JaggedCrystals≡AncientPotteryFragments`, `MedusaDarkScales≡MedusaLightScales≡RedScales≡BlueScales≡BlackScales≡YellowScales≡GreenScales≡WhiteScales`, **`Sausage≡CookableSausage`**, `Lettuce≡FarmableLettuce`, `DarkYarn≡LightYarn`.

**`BaseBeverage` resources are content-filtered** `[SRC]`: `RequiredBeverage` defaults to `BeverageType.Water` (`CraftItem.cs:119`) and any `BaseBeverage` whose `Content != RequiredBeverage` is skipped (`CraftItem.cs:747-750, 788-791, 828-831`). `SetBeverageType(index, X)` (`CraftSystem.cs:430-434`) is therefore mandatory for non-water beverage costs. Each table below lists the beverage type in Flags where set.

**Craft sound / effect** `[SRC]`: Alchemy `from.PlaySound(0x242)` on start (`DefAlchemy.cs:69-72`), `0x240` on success (`:100`), and on failure of a *potion* it hands back `new Bottle()` with cliloc `500287` (`:86-92`). Inscription `0x249` (`:93-96`). Cartography `0x249` (`DefCartography.cs:61-64`). Cooking: none (`DefCooking.cs:92-94`). Masonry: none, plus a `0.7 s` `InternalTimer` that plays `0x23D` (`DefMasonry.cs:75-94`).

### 4d.2 ALCHEMY — `DefAlchemy.cs`, gump cliloc 1044001

`AlchemyRecipes` enum (`DefAlchemy.cs:6-14`): `BarrabHemolymphConcentrate=900, JukariBurnPoiltice=901, KurakAmbushersEssence=902, BarakoDraftOfMight=903, UraliTranceTonic=904, SakkhraProphylaxisPotion=905`.
Recipe ids reused from `TinkerRecipes`: `InvisibilityPotion` (`:182`), `ParasiticPotion` (`:237`), `DarkglowPotion` (`:241`), `HoveringWisp` (`:306`) — a literal oddity in the source, not a typo in this document.
Row count: **51 `AddCraft` calls** (`grep AddCraft\(` → 51 matches). Tools: `MortarPestle` (`Scripts/Items/Tools/MortarPestle.cs:31` → `DefAlchemy.CraftSystem`), `AlchemyStation` addon (`Scripts/Items/Addons/Craft Addons/AlchemyStation.cs:11`).

#### Group 1116348 — "Healing and Curative" (10 rows; source comment `// Healing and Curative` `DefAlchemy.cs:120`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources (type ×n) | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1116348 | refresh potion (1044538) | `RefreshPotion` | -25 | 25.0 | `BlackPearl`×1 | ≡— | — | 121 |
| 1116348 | total refresh potion (1044539) | `TotalRefreshPotion` | 25.0 | 75.0 | `BlackPearl`×5 | ≡— | — | 124 |
| 1116348 | lesser heal potion (1044543) | `LesserHealPotion` | -25.0 | 25.0 | `Ginseng`×1 | ≡— | — | 127 |
| 1116348 | heal potion (1044544) | `HealPotion` | 15.0 | 65.0 | `Ginseng`×3 | ≡— | — | 130 |
| 1116348 | greater heal potion (1044545) | `GreaterHealPotion` | 55.0 | 105.0 | `Ginseng`×7 | ≡— | — | 133 |
| 1116348 | lesser cure potion (1044552) | `LesserCurePotion` | -10.0 | 40.0 | `Garlic`×1 | ≡— | — | 136 |
| 1116348 | cure potion (1044553) | `CurePotion` | 25.0 | 75.0 | `Garlic`×3 | ≡— | — | 139 |
| 1116348 | greater cure potion (1044554) | `GreaterCurePotion` | 65.0 | 115.0 | `Garlic`×6 | ≡— | — | 142 |
| 1116348 | Elixir of Rebirth (1112762) | `ElixirOfRebirth` | 65.0 | 115.0 | `MedusaBlood`×1 + `SpidersSilk`×3 | ≡— | gate `Core.SA` | 147 |
| 1116348 | Barrab Hemolymph Concentrate (1156724) | `BarrabHemolymphConcentrate` | 51.0 | 151.0 | `Bottle`×1 + `Ginseng`×20 + `PlantClippings`×5 + `MyrmidexEggsac`×5 | ≡— | gate `Core.TOL`; `AddRecipe(900)` | 154 |

#### Group 1116349 — "Enhancement" (11 rows; comment `DefAlchemy.cs:161`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1116349 | agility potion (1044540) | `AgilityPotion` | 15.0 | 65.0 | `Bloodmoss`×1 | ≡— | — | 162 |
| 1116349 | greater agility potion (1044541) | `GreaterAgilityPotion` | 35.0 | 85.0 | `Bloodmoss`×3 | ≡— | — | 165 |
| 1116349 | nightsight potion (1044542) | `NightSightPotion` | -25.0 | 25.0 | `SpidersSilk`×1 | ≡— | — | 168 |
| 1116349 | strength potion (1044546) | `StrengthPotion` | 25.0 | 75.0 | `MandrakeRoot`×2 | ≡— | — | 171 |
| 1116349 | greater strength potion (1044547) | `GreaterStrengthPotion` | 45.0 | 95.0 | `MandrakeRoot`×5 | ≡— | — | 174 |
| 1116349 | Potion of Invisibility (1074860) | `InvisibilityPotion` | 65.0 | 115.0 | `Bottle`×1 + `Bloodmoss`×4 + `Nightshade`×3 | ≡— | gate `Core.ML`; `AddRecipe(TinkerRecipes.InvisibilityPotion)` | 179 |
| 1116349 | Jukari Burn Poiltice (1156726) | `JukariBurnPoiltice` | 51.0 | 151.0 | `Bottle`×1 + `BlackPearl`×20 + `Vanilla`×10 + `LavaBerry`×5 | ≡— | gate `Core.TOL`; recipe 901 | 187 |
| 1116349 | Kurak Ambusher's Essence (1156728) | `KurakAmbushersEssence` | 51.0 | 151.0 | `Bottle`×1 + `Bloodmoss`×20 + `BlueDiamond`×1 + `TigerPelt`×10 | ≡— | gate `Core.TOL`; recipe 902 | 193 |
| 1116349 | Barako Draft of Might (1156729) | `BarakoDraftOfMight` | 51.0 | 151.0 | `Bottle`×1 + `SpidersSilk`×20 + `BaseBeverage`×10 + `PerfectBanana`×5 | ≡— | gate `Core.TOL`; recipe 903; `SetBeverageType(Liquor)` | 199 |
| 1116349 | Urali Trance Tonic (1156734) | `UraliTranceTonic` | 51.0 | 151.0 | `Bottle`×1 + `MandrakeRoot`×20 + `YellowScales`×10 + `RiverMoss`×5 | ≡— | gate `Core.TOL`; recipe 904 | 206 |
| 1116349 | Sakkhra Prophylaxis Potion (1156732) | `SakkhraProphylaxisPotion` | 51.0 | 151.0 | `Bottle`×1 + `Nightshade`×20 + `BaseBeverage`×10 + `BlueCorn`×5 | ≡— | gate `Core.TOL`; recipe 905; `SetBeverageType(Wine)` | 212 |

#### Group 1116350 — "Toxic" (7 rows; comment `DefAlchemy.cs:220`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1116350 | lesser poison potion (1044548) | `LesserPoisonPotion` | -5.0 | 45.0 | `Nightshade`×1 | ≡— | — | 221 |
| 1116350 | poison potion (1044549) | `PoisonPotion` | 15.0 | 65.0 | `Nightshade`×2 | ≡— | — | 224 |
| 1116350 | greater poison potion (1044550) | `GreaterPoisonPotion` | 55.0 | 105.0 | `Nightshade`×4 | ≡— | — | 227 |
| 1116350 | deadly poison potion (1044551) | `DeadlyPoisonPotion` | 90.0 | 140.0 | `Nightshade`×8 | ≡— | — | 230 |
| 1116350 | Parasitic Poison (1072942) | `ParasiticPotion` | 65.0 | 115.0 | `Bottle`×1 + `ParasiticPlant`×5 | ≡— | gate `Core.ML`; `AddRecipe(TinkerRecipes.ParasiticPotion)` | 235 |
| 1116350 | Darkglow Poison (1072943) | `DarkglowPotion` | 65.0 | 115.0 | `Bottle`×1 + `LuminescentFungi`×5 | ≡— | gate `Core.ML`; `AddRecipe(TinkerRecipes.DarkglowPotion)` | 239 |
| 1116350 | scouring toxin (1112292) | `ScouringToxin` | 75.0 | 100.0 | `ToxicVenomSac`×1 + `Bottle`×1 | ≡— | gate `Core.ML` | 243 |

#### Group 1116351 — "Explosive" (10 rows; comment `DefAlchemy.cs:247`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1116351 | lesser explosion potion (1044555) | `LesserExplosionPotion` | 5.0 | 55.0 | `SulfurousAsh`×3 | ≡— | — | 248 |
| 1116351 | explosion potion (1044556) | `ExplosionPotion` | 35.0 | 85.0 | `SulfurousAsh`×5 | ≡— | — | 251 |
| 1116351 | greater explosion potion (1044557) | `GreaterExplosionPotion` | 65.0 | 115.0 | `SulfurousAsh`×10 | ≡— | — | 254 |
| 1116351 | Conflagration potion (1072096) | `ConflagrationPotion` | 55.0 | 105.0 | `Bottle`×1 + `GraveDust`×5 | ≡— | gate `Core.ML` | 259 |
| 1116351 | Greater Conflagration potion (1072099) | `GreaterConflagrationPotion` | 70.0 | 120.0 | `Bottle`×1 + `GraveDust`×10 | ≡— | gate `Core.ML` | 262 |
| 1116351 | Confusion Blast potion (1072106) | `ConfusionBlastPotion` | 55.0 | 105.0 | `Bottle`×1 + `PigIron`×5 | ≡— | gate `Core.ML` | 265 |
| 1116351 | Greater Confusion Blast potion (1072109) | `GreaterConfusionBlastPotion` | 70.0 | 120.0 | `Bottle`×1 + `PigIron`×10 | ≡— | gate `Core.ML` | 268 |
| 1116351 | black powder (1095826) | `BlackPowder` | 65.0 | 115.0 | `SulfurousAsh`×1 + `Saltpeter`×6 + `Charcoal`×1 | ≡— | gate `Core.SA`; `SetUseAllRes(true)` only if `Core.EJ` | 274 |
| 1116351 | matchcord (1095184) | `Matchcord` | 25.0 | 80.0 | `DarkYarn`×1 + `BaseBeverage`×1 + `Saltpeter`×1 + `Potash`×1 | ≡`DarkYarn≡LightYarn` | gate `Core.SA && !Core.EJ` ("Removed for Dark Tides Cannon Changes" `:279`); beverage default = Water | 282 |
| 1116351 | fuse cord (1116305) | `FuseCord` | 55.0 | 105.0 | `DarkYarn`×1 + `BlackPowder`×1 + `Potash`×1 | ≡`DarkYarn≡LightYarn` | gate `Core.SA`; `SetNeedWater(true)` | 288 |

#### Group 1116353 — "Strange Brew" (4 rows; comment `DefAlchemy.cs:294`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1116353 | smoke bomb (1030248) | `SmokeBomb` | 90.0 | 120.0 | `Eggs`×1 + `Ginseng`×3 | ≡— | gate `Core.SE` | 297 |
| 1116353 | hovering wisp (1072881) | `HoveringWisp` | 75.0 | 125.0 | `CapturedEssence`×4 | ≡— | gate `Core.ML`; `AddRecipe(TinkerRecipes.HoveringWisp)` only if `!Core.TOL` (`:305`) | 303 |
| 1116353 | natural dye (1112136) | `NaturalDye` | 75.0 | 100.0 | `PlantPigment`×1 + `ColorFixative`×1 | ≡— | gate `Core.SA`; `SetItemHue(2101)`; `SetRequireResTarget` | 311 |
| 1116353 | nexus core (1153501) | `NexusCore` | 90.0 | 120.0 | `MandrakeRoot`×10 + `SpidersSilk`×10 + `DarkSapphire`×5 + `CrushedGlass`×5 | ≡— | gate `Core.SA`; `ForceNonExceptional` | 316 |

#### Group 1044495 — "Ingredients" (9 rows; comment `// Ingrediants` `DefAlchemy.cs:323`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044495 | plant pigment (1112132) | `PlantPigment` | 33.0 | 83.0 | `PlantClippings`×1 + `Bottle`×1 | ≡— | gate `Core.SA`; `SetItemHue(2101)`; `SetRequireResTarget` | 327 |
| 1044495 | color fixative (1112135) | `ColorFixative` | 75.0 | 100.0 | `SilverSerpentVenom`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SA`; `SetBeverageType(Wine)` | 332 |
| 1044495 | crystal granules (1112329) | `CrystalGranules` | 75.0 | 100.0 | `ShimmeringCrystals`×1 | ≡— | gate `Core.SA`; `SetItemHue(2625)` | 336 |
| 1044495 | crystal dust (1112328) | `CrystalDust` | 75.0 | 100.0 | `CrystallineFragments`×4 | ≡ crystal-fragment group | gate `Core.SA`; `SetItemHue(2103)` | 339 |
| 1044495 | softened reeds (1112249) | `SoftenedReeds` | 75.0 | 100.0 | `DryReeds`×1 + `ScouringToxin`×2 | ≡— | gate `Core.SA`; `SetRequireResTarget`; `SetRequiresBasketWeaving` | 342 |
| 1044495 | vial of vitriol (1113331) | `VialOfVitriol` | 90.0 | 100.0 | `ParasiticPotion`×1 + `Nightshade`×30 | ≡— | gate `Core.SA`; **`AddSkill(Magery, 75.0, 100.0)`** | 347 |
| 1044495 | bottle of ichor (1113361) | `BottleIchor` | 90.0 | 100.0 | `DarkglowPotion`×1 + `SpidersSilk`×1 | ≡— | gate `Core.SA`; **`AddSkill(Magery, 75.0, 100.0)`** | 351 |
| 1044495 | potash (1116319) | `Potash` | 0.0 | 50.0 | `Board`×1 | ≡`Board≡Log` | gate `Core.HS`; if `Core.EJ` → `SetNeedWater(true)`+`SetUseAllRes(true)`, else `BaseBeverage`×1 (default Water) | 358 |
| 1044495 | gold dust (1153504) | `GoldDust` | 90.0 | 120.0 | `Gold`×1000 | ≡— | gate `Core.SA`; `ForceNonExceptional` | 373 |

#### 4d.2.1 Full potion list — effects, exact literals

`PotionEffect` enum order (`BasePotion.cs:7-49`) and `LabelNumber = 1041314 + (int)PotionEffect` (`BasePotion.cs:83-89`). All potions: `Weight = 1.0`, `Stackable = Core.ML` (`BasePotion.cs:91-98`); drink requires a free hand unless overridden (`:105-129`, `:146`); drink action is exclusive for 500 ms (`:136-142`).

| # | Enum | Drinker class | Effect (exact code) | Values | L |
|---|---|---|---|---|---|
| 0 | `Nightsight` | `NightSightPotion` | `new LightCycle.NightSightTimer(from).Start(); from.LightLevel = LightCycle.DungeonLevel / 2;` | `DungeonLevel = 26` → LightLevel **13**; timer = `Utility.Random(15, 25)` **minutes** | `NightSight.cs:32-49`; `LightCycle.cs:15,127` |
| 1 | `CureLesser` | `LesserCurePotion` | `BaseCurePotion.DoCure` → per-level `Scale(from, li.Chance) > Utility.RandomDouble()` | pre-AOS: Lesser .75 / Regular .50 / Greater .15; AOS: 1.00 / .35 / .15 / .10 / .05 | `LesserCurePotion.cs:7-20`; `BaseCurePotion.cs:59-88` |
| 2 | `Cure` | `CurePotion` | idem | pre-AOS: 1.00 / .75 / .50 / .15; AOS: 1.00 / .95 / .45 / .25 / .15 | `CurePotion.cs:7-21` |
| 3 | `CureGreater` | `GreaterCurePotion` | idem | pre-AOS: 1.00 / 1.00 / 1.00 / .75 / .25; AOS: 1.00 / 1.00 / .75 / .45 / .25 | `GreaterCurePotion.cs:7-22` |
| 4 | `Agility` | `AgilityPotion` | `SpellHelper.AddStatOffset(from, StatType.Dex, Scale(from, DexOffset), Duration)` | `DexOffset = 10`, `TimeSpan.FromMinutes(2.0)` | `AgilityPotion.cs:18-31`; `BaseAgilityPotion.cs:33-49` |
| 5 | `AgilityGreater` | `GreaterAgilityPotion` | idem | `DexOffset = 20`, 2.0 min | `GreaterAgilityPotion.cs:18-31` |
| 6 | `Strength` | `StrengthPotion` | `AddStatOffset(..., StatType.Str, Scale(from, StrOffset), Duration)` | `StrOffset = 10`, 2.0 min | `StrengthPotion.cs:18-31`; `BaseStrengthPotion.cs:33-49` |
| 7 | `StrengthGreater` | `GreaterStrengthPotion` | idem | `StrOffset = 20`, 2.0 min | `GreaterStrengthPotion.cs:18-31` |
| 8 | `PoisonLesser` | `LesserPoisonPotion` | `from.ApplyPoison(from, Poison.Lesser)` | `MinPoisoningSkill = 0.0`, `Max = 60.0` | `LesserPoisonPotion.cs:18-38`; `BasePoisonPotion.cs:34-44` |
| 9 | `Poison` | `PoisonPotion` | `Poison.Regular` | `Min = 30.0`, `Max = 70.0` | `PoisonPotion.cs:18-38` |
| 10 | `PoisonGreater` | `GreaterPoisonPotion` | `Poison.Greater` | `Min = 60.0`, `Max = 100.0` | `GreaterPoisonPotion.cs:18-38` |
| 11 | `PoisonDeadly` | `DeadlyPoisonPotion` | `Poison.Deadly` | `Min = 80.0`, `Max = 100.0` | `DeadlyPoisonPotion.cs:18-38` |
| 12 | `Refresh` | `RefreshPotion` | `from.Stam += Scale(from, (int)(Refresh * from.StamMax))` | `Refresh = 0.25` → +25 % of max stamina | `RefreshPotion.cs:18-24`; `BaseRefreshPotion.cs:32-45` |
| 13 | `RefreshTotal` | `TotalRefreshPotion` | idem | `Refresh = 1.0` → full stamina | `TotalRefreshPotion.cs:18-24` |
| 14 | `HealLesser` | `LesserHealPotion` | `from.Heal(Utility.RandomMinMax(Scale(from,MinHeal), Scale(from,MaxHeal)))` | AOS `6..8`, delay `3.0 s`; pre-AOS `3..10`, delay `10.0 s` | `LesserHealPotion.cs:18-38`; `BaseHealPotion.cs:35-41` |
| 15 | `Heal` | `HealPotion` | idem | AOS `13..16`, delay `8.0 s`; pre-AOS `6..20`, delay `10.0 s` | `HealPotion.cs:18-38` |
| 16 | `HealGreater` | `GreaterHealPotion` | idem | AOS `20..25`; pre-AOS `9..30`; delay `10.0 s` both | `GreaterHealPotion.cs:18-38` |
| 17 | `ExplosionLesser` | `LesserExplosionPotion` | thrown, `ExplosionRange = 2`, delayed detonation | `MinDamage = 5`, `MaxDamage = 10` | `LesserExplosionPotion.cs:18-31`; `BaseExplosionPotion.cs:15` |
| 18 | `Explosion` | `ExplosionPotion` | idem | `10..20` | `ExplosionPotion.cs:18-31` |
| 19 | `ExplosionGreater` | `GreaterExplosionPotion` | idem | AOS `20..40`; pre-AOS `15..30` | `GreaterExplosionPotion.cs:18-31` |
| 20 | `Conflagration` | `ConflagrationPotion` | thrown fire field, 5×5 tiles, 10 s | `MinDamage = 2`, `MaxDamage = 4`; label 1072095; `Hue = 0x489` | `ConflagrationPotion.cs:18-38`; `BaseConflagrationPotion.cs:22-26,104-113,241` |
| 21 | `ConflagrationGreater` | `GreaterConflagrationPotion` | idem | `4..8`; label 1072098 | `GreaterConflagrationPotion.cs:18-38` |
| 22 | `MaskOfDeath` | *(no class — comment: "not available in OSI but does exist in cliloc files")* | — | — | `BasePotion.cs:31` |
| 23 | `MaskOfDeathGreater` | *(no class — "included in enumeration for compatability")* | — | — | `BasePotion.cs:32` |
| 24 | `ConfusionBlast` | `ConfusionBlastPotion` | `mon.Pacify(from, DateTime.UtcNow + TimeSpan.FromSeconds(5.0))` on non-controlled, non-summoned `BaseCreature`s in radius | `Radius = 5`; label 1072105; hue `0x48D`; **60 s** reuse delay; **no damage** | `ConfusionBlastPotion.cs:18-31`; `BaseConfusionBlastPotion.cs:26,105-122,151` |
| 25 | `ConfusionBlastGreater` | `GreaterConfusionBlastPotion` | idem | `Radius = 7`; label 1072108 | `GreaterConfusionBlastPotion.cs:18-31` |
| 26 | `Invisibility` | `InvisibilityPotion` | 2 s delay → `m.Hidden = true`, `BuffInfo.AddBuff(..., BuffIcon.Invisibility, 1075825, 30 s)` | **30 s**; re-drink blocked while timer alive; label 1072941; `Hue = 0x48D` | `InvisibilityPotion.cs:28-41,71-88` |
| 27 | `Parasitic` | `ParasiticPotion` | `Poison.Parasitic` (levels 14-18) | `Min = 95.0`, `Max = 100.0`; label 1072848; `Hue = 0x17C` | `ParasiticPotion.cs:18-46`; `Poison.cs:46-50` |
| 28 | `Darkglow` | `DarkglowPotion` | `Poison.DarkGlow` (levels 10-13) | `Min = 95.0`, `Max = 100.0`; label 1072849; `Hue = 0x96` | `DarkglowPotion.cs:18-46`; `Poison.cs:41-44` |
| 29 | `ExplodingTarPotion` | `ExplodingTarPotion` | `ExplodingTarPotion : BaseExplodingTarPotion` | not in any craft menu | `ExplodingTarPotion.cs:6` |
| 30-35 | `Barrab, Jukari, Kurak, Barako, Urali, Sakkhra` | `EodonPotions.cs` | ToL publish 93 potions | `BasePotion.cs:39-46` |
| 36 | `Shatter` | `ShatterPotion` | `ShatterPotion.cs` | not in any craft menu | `ShatterPotion.cs` |
| 37 | `FearEssence` | *(enum only)* | — | — | `BasePotion.cs:48` |

`PotionEffect.Poison*` values map to `PoisonImpl` levels: Lesser=0, Regular=1, Greater=2, Deadly=3, Lethal=4, Darkglow=10-13, Parasitic=14-18 (`Poison.cs:21-51`). The `MinPoisoningSkill`/`MaxPoisoningSkill` pair is consumed by the Poisoning skill when coating a weapon with a potion: `m_MinSkill = potion.MinPoisoningSkill;` (`Scripts/Skills/Poisoning.cs:109`) and by the Injected Strike mastery (`Spells/Skill Masteries/InjectedStrike.cs:99,116`).

#### 4d.2.2 Reagents — exact class names, files, item IDs `[SRC]`

| Reagent | Class | File | ItemID | L (class / ctor) |
|---|---|---|---|---|
| Bloodmoss | `Bloodmoss : BaseReagent, ICommodity` | `Scripts/Items/Resource/Bloodmoss.cs` | `0xF7B` | 5 / 15 |
| Ginseng | `Ginseng : BaseReagent, ICommodity` | `Scripts/Items/Resource/Ginseng.cs` | `0xF85` | 5 / 15 |
| Garlic | `Garlic : BaseReagent, ICommodity` | `Scripts/Items/Resource/Garlic.cs` | `0xF84` | 5 / 15 |
| MandrakeRoot | `MandrakeRoot : BaseReagent, ICommodity` | `Scripts/Items/Resource/MandrakeRoot.cs` | `0xF86` | 5 / 15 |
| Nightshade | `Nightshade : BaseReagent, ICommodity` | `Scripts/Items/Resource/Nightshade.cs` | `0xF88` | 5 / 15 |
| BlackPearl | `BlackPearl : BaseReagent, ICommodity` | `Scripts/Items/Resource/BlackPearl.cs` | `0xF7A` | 5 / 15 |
| SpidersSilk | `SpidersSilk : BaseReagent, ICommodity` | `Scripts/Items/Resource/SpidersSilk.cs` | `0xF8D` | 5 / 15 |
| SulfurousAsh | `SulfurousAsh : BaseReagent, ICommodity` | `Scripts/Items/Resource/SulfurousAsh.cs` | `0xF8C` | 5 / 15 |
| GraveDust | `GraveDust : BaseReagent, ICommodity` | `Scripts/Items/Resource/GraveDust.cs` | `0xF8F` | 5 / 15 |
| NoxCrystal | `NoxCrystal : BaseReagent, ICommodity` | `Scripts/Items/Resource/NoxCrystal.cs` | `0xF8E` | 5 / 15 |
| PigIron | `PigIron : BaseReagent, ICommodity` | `Scripts/Items/Resource/PigIron.cs` | `0xF8A` | 5 / 15 |
| BatWing | `BatWing : BaseReagent, ICommodity` | `Scripts/Items/Resource/BatWing.cs` | `0xF78` | 5 / 15 |
| DaemonBlood | `DaemonBlood : BaseReagent, ICommodity` | `Scripts/Items/Resource/DaemonBlood.cs` | `0xF7D` | 5 / 15 |
| DaemonBone | `DaemonBone : BaseReagent` | `Scripts/Items/Resource/DaemonBone.cs` | `0xF80` | 6 / 16 |
| Bone | `Bone : Item, ICommodity` — **not** a `BaseReagent` | `Scripts/Items/Resource/Bone.cs` | `0xf7e` | 5 / 15 |
| DragonBlood | `DragonBlood : BaseReagent, ICommodity` | `Scripts/Items/Resource/DragonBlood.cs` | `0x4077` | 5 / 15 |
| FertileDirt | `FertileDirt : Item` — **not** a `BaseReagent` | `Scripts/Items/Resource/FertileDirt.cs` | `0xF81` | 5 / 23 |
| Bottle | `Bottle : Item, ICommodity` | `Scripts/Items/Resource/Bottle.cs` | `0xF0E` | 5 / 15 |

`BaseReagent` gives `Stackable = true`, `Amount = amount`, `DefaultWeight = 0.1` (`Scripts/Items/Consumables/BaseReagent.cs:12-30`). Note the split layout: the base class lives at `Scripts/Items/Consumables/BaseReagent.cs:5` while the concrete reagents live under `Scripts/Items/Resource/`.

#### 4d.2.3 WHERE ALCHEMY SKILL SCALES POTION EFFECT — exact formula

`[SRC]` **`BasePotion.EnhancePotions`** — `Scripts/Items/Consumables/BasePotion.cs:233-242`:
```csharp
public static int EnhancePotions(Mobile m)
{
    int EP = AosAttributes.GetValue(m, AosAttribute.EnhancePotions);
    int skillBonus = m.Skills.Alchemy.Fixed / 330 * 10;     // <-- line 236
    if (Core.ML && EP > 50 && m.IsPlayer()) EP = 50;
    return (EP + skillBonus);
}
```
`Skill.Fixed == Value * 10`, so at Alchemy 100.0 → `1000 / 330 = 3` (integer division) → `* 10` = **+30**; at 50.0 → `500/330 = 1` → **+10**; at 33.0 → `330/330 = 1` → +10; below 33.0 → **0**.
`Scale` — `BasePotion.cs:244-270`:
```csharp
public static int Scale(Mobile m, int v)  { if (!Core.AOS) return v; return AOS.Scale(v, 100 + EnhancePotions(m)); }
public static double Scale(Mobile m, double v) { if (!Core.AOS) return v; return v * (1.0 + 0.01 * EnhancePotions(m)); }
public static TimeSpan Scale(Mobile m, TimeSpan v) { if (!Core.AOS) return v; return TimeSpan.FromSeconds(v.TotalSeconds * (1.0 + 0.01*EnhancePotions(m))); }
```
→ **Alchemy only scales the potion at all when `Core.AOS` is on**; the scalar is `1.0 + 0.01*(EP + Alchemy.Fixed/330*10)`.

Call sites of `Scale` inside potion classes `[SRC]`:

| Potion family | Call site | Scaled quantity |
|---|---|---|
| Heal | `BaseHealPotion.cs:37-38` | `MinHeal`, `MaxHeal` |
| Cure | `BaseCurePotion.cs:70` | each `CureLevelInfo.Chance` |
| Agility | `BaseAgilityPotion.cs:36` | `DexOffset` (source comment: `// TODO: Verify scaled; is it offset, duration, or both?`) |
| Strength | `BaseStrengthPotion.cs:36` | `StrOffset` (same TODO) |
| Refresh | `BaseRefreshPotion.cs:36` | stamina restored |
| Explosion | `BaseExplosionPotion.cs:151-152` | `MinDamage`, `MaxDamage` on top of the flat bonus below |
| Conflagration | `BaseConflagrationPotion.cs:281-282` | `MinDamage`, `MaxDamage` on top of the flat bonus below |

**Extra flat alchemy damage bonus, explosions** — `BaseExplosionPotion.cs:144-149`:
```csharp
int alchemyBonus = 0;
if (direct) alchemyBonus = (int)(from.Skills.Alchemy.Value / (Core.AOS ? 5 : 10));   // line 148
```
`direct` is true only when the potion detonated in the thrower's own hand (`Explode(from, true, …)` at `:224`). At Alchemy 100.0: **+20** (AOS) or **+10** (pre-AOS). Then `damage = Utility.RandomMinMax(min,max) + alchemyBonus` (`:168-170`), pre-AOS hard cap `if (!Core.AOS && damage > 40) damage = 40;` (`:172-175`), AOS splash rule `else if (Core.AOS && list.Count > 2) damage /= list.Count - 1;` (`:176-179`), damage type = 100 % fire (`AOS.Damage(m, from, damage, 0, 100, 0, 0, 0, DamageType.SpellAOE)` — args are phys, fire, cold, pois, nrgy — `:181`). Explosion delay: ML `1.0 s` then `1.25 s` ×5 ticks (`:91-99`), otherwise `0.75 s` then `1.0 s` ×4 (`:100-108`); throw range 12 (`:263`).

**Extra flat alchemy damage bonus, conflagration** — `BaseConflagrationPotion.cs:267-283`:
```csharp
int alchemySkill = m_From.Skills.Alchemy.Fixed;             // line 278
int alchemyBonus = alchemySkill / 125 + alchemySkill / 250; // line 279  (source comment cites Stratics' calculator)
m_MinDamage = Scale(m_From, m_MinDamage + alchemyBonus);
m_MaxDamage = Scale(m_From, m_MaxDamage + alchemyBonus);
```
At Alchemy 100.0: `1000/125 = 8` + `1000/250 = 4` = **+12** to both min and max. Field: 5×5 tiles around the impact (`:104-113`), 10 s lifetime (`:241`), 1 s tick (`:331`), 30 s reuse (`:127`), self-damage only pre-AOS (`:314`), damage type 100 % fire (`:318`).

**ModernUO cross-check** `[SRC]` — `Projects/UOContent/Items/Skill Items/Magical/Potions/BasePotion.cs:207-218`:
```csharp
var skillBonus = (int)(m.Skills.Alchemy.Value * 10 / 33);
```
Same result as ServUO at every 0.1 boundary (100.0 → 30), different expression (`Value*10/33` vs `Fixed/330*10`). `Scale` is otherwise identical (`:220-242`). **No disagreement in value.**

#### 4d.2.4 Potion keg `[SRC]`

`PotionKeg` — `Scripts/Items/Resource/PotionKeg.cs`:
- `Base(0x1940)`, `TileData.ItemTable[0x1940].Height = 4` (`:11, 72-75`).
- `Held` clamped 0..100 in the weight formula: `Weight = 20 + ((held * 80) / 100);` (`:77-82`).
- `Type` is a `PotionEffect` (`:38-50`); label switches to dedicated clilocs for `Parasitic`(1080069) / `Darkglow`(1080070) / `Invisibility`(1080071) / `Conflagration`(1072658) / `ConflagrationGreater`(1072659) / `ConfusionBlast`(1072662) / `ConfusionBlastGreater`(1072663), else `1041620 + (int)Type`, empty keg = `1041641` (`:51-71`).
- Filling path — `BasePotion.OnCraft`, `BasePotion.cs:279-316`:
```csharp
if (craftSystem is DefAlchemy) {
    if ((int)this.PotionEffect >= (int)PotionEffect.Invisibility) return 1;   // line 287-288: Invisibility and later are never kegged
    foreach (PotionKeg keg in pack.FindItemsByType<PotionKeg>()) {
        if (keg.Held <= 0 || keg.Held >= 100) continue;                        // :299-300
        if (keg.Type != this.PotionEffect) continue;                           // :302-303
        ++keg.Held; this.Consume(); from.AddToBackpack(new Bottle());
        return -1;                                                             // :305-310 signal "placed in keg"
    }
}
```
- That `-1` return produces `PlayEndingEffect`'s `quality == -1` branch → cliloc `1048136` "You create the potion and pour it into a keg." (`DefAlchemy.cs:102-108`).
- Consequence: **PotionEffect index ≥ 26 (`Invisibility`, `Parasitic`, `Darkglow`, Eodon potions, `Shatter`, `FearEssence`) can never be stored in a keg** (`BasePotion.cs:287-288` vs enum order `:35-48`). Note `Conflagration`(20)/`ConfusionBlast`(24) *are* keggable.

### 4d.3 INSCRIPTION — `DefInscription.cs`, gump cliloc 1044009

`InscriptionRecipes` (`DefInscription.cs:7-10`): `RunicAtlas = 800`. `MarkOption = true` (`:466`).
Row count: **113 craft entries** = 64 magery scrolls + 17 necromancy scrolls + 16 mysticism scrolls + 16 non-scroll items (`grep AddCraft\(|AddSpell\(|AddNecroSpell\(|AddMysticSpell\(` → 119 lines = 113 entries + 3 helper signatures + 3 helper-internal `AddCraft`).
Tool: `ScribesPen : BaseTool`, itemID `0x0FBF`/`0x0FC0` flipable, label 1044168, `CraftSystem => DefInscription.CraftSystem` (`Scripts/Items/Tools/ScribesPen.cs:6-14, 9`).
**Resources per scroll = the reagents named in the table + `BlankScroll ×1` (cliloc 1044377 / message 1044378), added at `DefInscription.cs:185` (`AddSpell`), `:201` (`AddNecroSpell`), `:213` (`AddMysticSpell`).**
**Every scroll also consumes mana via `SetManaReq(index, m_Mana|mana)` (`:187, 203, 215`)** — see the per-circle mana column.

#### 4d.3.1 Skill needed per spell circle — `AddSpell`, `DefInscription.cs:162-188`

```csharp
switch (m_Circle) {                     // lines 167-178
  case 0: minSkill = -25.0; maxSkill =  25.0; cliloc = 1111691; break;
  case 1: minSkill = -10.8; maxSkill =  39.2; cliloc = 1111691; break;
  case 2: minSkill =  03.5; maxSkill =  53.5; cliloc = 1111692; break;
  case 3: minSkill =  17.8; maxSkill =  67.8; cliloc = 1111692; break;
  case 4: minSkill =  32.1; maxSkill =  82.1; cliloc = 1111693; break;
  case 5: minSkill =  46.4; maxSkill =  96.4; cliloc = 1111693; break;
  case 6: minSkill =  60.7; maxSkill = 110.7; cliloc = 1111694; break;
  case 7: minSkill =  75.0; maxSkill = 125.0; cliloc = 1111694; break;
}
```
`m_Mana` per circle, set in `InitCraftList`: circle 0 → 4, 1 → 6, 2 → 9, 3 → 11, 4 → 14, 5 → 20, 6 → 40, 7 → 50 (`DefInscription.cs:244, 256, 268, 280, 292, 304, 316, 328`).
Scroll name clilocs are assigned sequentially: `1044381 + m_Index++` (`:180`), starting at 0 → scroll #1 = 1044381; 64 scrolls = 1044381…1044444.
Reagent name/message cliloc = `1044353 + (int)reg` / `1044361 + (int)reg` (`:180,183`) with the `Reg` enum order `BlackPearl, Bloodmoss, Garlic, Ginseng, MandrakeRoot, Nightshade, SulfurousAsh, SpidersSilk, BatWing, GraveDust, DaemonBlood, NoxCrystal, PigIron, Bone, DragonBlood, FertileDirt, DaemonBone` (`:137`) — i.e. BlackPearl 1044353/…361, Bloodmoss 1044354/…362, Garlic …355/…363, Ginseng …356/…364, MandrakeRoot …357/…365, Nightshade …358/…366, SulfurousAsh …359/…367, SpidersSilk …360/…368. For regs 8..16 the name cliloc is overridden by `GetRegLocalization` (`:218-239`): BatWing 1023960, GraveDust 1023983, DaemonBlood 1023965, NoxCrystal 1023982, PigIron 1023978, Bone 1023966, DragonBlood 1023970, FertileDirt 1023969, DaemonBone 1023968.

#### Group 1111691 — Magery circle 1 (8 rows, `DefInscription.cs:243-253`) — min -25.0 / max 25.0, mana 4

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources (reagent×1 + `BlankScroll`×1) | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111691 | Reactive Armor scroll (1044381) | `ReactiveArmorScroll` | -25.0 | 25.0 | `Garlic` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 4` | 246 |
| 1111691 | Clumsy scroll (1044382) | `ClumsyScroll` | -25.0 | 25.0 | `Bloodmoss` + `Nightshade` | ≡— | `Mana 4` | 247 |
| 1111691 | Create Food scroll (1044383) | `CreateFoodScroll` | -25.0 | 25.0 | `Garlic` + `Ginseng` + `MandrakeRoot` | ≡— | `Mana 4` | 248 |
| 1111691 | Feeblemind scroll (1044384) | `FeeblemindScroll` | -25.0 | 25.0 | `Nightshade` + `Ginseng` | ≡— | `Mana 4` | 249 |
| 1111691 | Heal scroll (1044385) | `HealScroll` | -25.0 | 25.0 | `Garlic` + `Ginseng` + `SpidersSilk` | ≡— | `Mana 4` | 250 |
| 1111691 | Magic Arrow scroll (1044386) | `MagicArrowScroll` | -25.0 | 25.0 | `SulfurousAsh` | ≡— | `Mana 4` | 251 |
| 1111691 | Night Sight scroll (1044387) | `NightSightScroll` | -25.0 | 25.0 | `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 4` | 252 |
| 1111691 | Weaken scroll (1044388) | `WeakenScroll` | -25.0 | 25.0 | `Garlic` + `Nightshade` | ≡— | `Mana 4` | 253 |

#### Group 1111691 — Magery circle 2 (8 rows, `DefInscription.cs:255-265`) — min -10.8 / max 39.2, mana 6

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111691 | Agility scroll (1044389) | `AgilityScroll` | -10.8 | 39.2 | `Bloodmoss` + `MandrakeRoot` | ≡— | `Mana 6` | 258 |
| 1111691 | Cunning scroll (1044390) | `CunningScroll` | -10.8 | 39.2 | `Nightshade` + `MandrakeRoot` | ≡— | `Mana 6` | 259 |
| 1111691 | Cure scroll (1044391) | `CureScroll` | -10.8 | 39.2 | `Garlic` + `Ginseng` | ≡— | `Mana 6` | 260 |
| 1111691 | Harm scroll (1044392) | `HarmScroll` | -10.8 | 39.2 | `Nightshade` + `SpidersSilk` | ≡— | `Mana 6` | 261 |
| 1111691 | Magic Trap scroll (1044393) | `MagicTrapScroll` | -10.8 | 39.2 | `Garlic` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 6` | 262 |
| 1111691 | Magic Untrap scroll (1044394) | `MagicUnTrapScroll` | -10.8 | 39.2 | `Bloodmoss` + `SulfurousAsh` | ≡— | `Mana 6` | 263 |
| 1111691 | Protection scroll (1044395) | `ProtectionScroll` | -10.8 | 39.2 | `Garlic` + `Ginseng` + `SulfurousAsh` | ≡— | `Mana 6` | 264 |
| 1111691 | Strength scroll (1044396) | `StrengthScroll` | -10.8 | 39.2 | `Nightshade` + `MandrakeRoot` | ≡— | `Mana 6` | 265 |

#### Group 1111692 — Magery circle 3 (8 rows, `DefInscription.cs:267-277`) — min 3.5 / max 53.5, mana 9

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111692 | Bless scroll (1044397) | `BlessScroll` | 3.5 | 53.5 | `Garlic` + `MandrakeRoot` | ≡— | `Mana 9` | 270 |
| 1111692 | Fireball scroll (1044398) | `FireballScroll` | 3.5 | 53.5 | `BlackPearl` | ≡— | `Mana 9` | 271 |
| 1111692 | Magic Lock scroll (1044399) | `MagicLockScroll` | 3.5 | 53.5 | `Bloodmoss` + `Garlic` + `SulfurousAsh` | ≡— | `Mana 9` | 272 |
| 1111692 | Poison scroll (1044400) | `PoisonScroll` | 3.5 | 53.5 | `Nightshade` | ≡— | `Mana 9` | 273 |
| 1111692 | Telekinesis scroll (1044401) | `TelekinisisScroll` *(sic, source spelling)* | 3.5 | 53.5 | `Bloodmoss` + `MandrakeRoot` | ≡— | `Mana 9` | 274 |
| 1111692 | Teleport scroll (1044402) | `TeleportScroll` | 3.5 | 53.5 | `Bloodmoss` + `MandrakeRoot` | ≡— | `Mana 9` | 275 |
| 1111692 | Unlock scroll (1044403) | `UnlockScroll` | 3.5 | 53.5 | `Bloodmoss` + `SulfurousAsh` | ≡— | `Mana 9` | 276 |
| 1111692 | Wall of Stone scroll (1044404) | `WallOfStoneScroll` | 3.5 | 53.5 | `Bloodmoss` + `Garlic` | ≡— | `Mana 9` | 277 |

#### Group 1111692 — Magery circle 4 (8 rows, `DefInscription.cs:279-289`) — min 17.8 / max 67.8, mana 11

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111692 | Arch Cure scroll (1044405) | `ArchCureScroll` | 17.8 | 67.8 | `Garlic` + `Ginseng` + `MandrakeRoot` | ≡— | `Mana 11` | 282 |
| 1111692 | Arch Protection scroll (1044406) | `ArchProtectionScroll` | 17.8 | 67.8 | `Garlic` + `Ginseng` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 11` | 283 |
| 1111692 | Curse scroll (1044407) | `CurseScroll` | 17.8 | 67.8 | `Garlic` + `Nightshade` + `SulfurousAsh` | ≡— | `Mana 11` | 284 |
| 1111692 | Fire Field scroll (1044408) | `FireFieldScroll` | 17.8 | 67.8 | `BlackPearl` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 11` | 285 |
| 1111692 | Greater Heal scroll (1044409) | `GreaterHealScroll` | 17.8 | 67.8 | `Garlic` + `SpidersSilk` + `MandrakeRoot` + `Ginseng` | ≡— | `Mana 11` | 286 |
| 1111692 | Lightning scroll (1044410) | `LightningScroll` | 17.8 | 67.8 | `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 11` | 287 |
| 1111692 | Mana Drain scroll (1044411) | `ManaDrainScroll` | 17.8 | 67.8 | `BlackPearl` + `SpidersSilk` + `MandrakeRoot` | ≡— | `Mana 11` | 288 |
| 1111692 | Recall scroll (1044412) | `RecallScroll` | 17.8 | 67.8 | `BlackPearl` + `Bloodmoss` + `MandrakeRoot` | ≡— | `Mana 11` | 289 |

#### Group 1111693 — Magery circle 5 (8 rows, `DefInscription.cs:291-301`) — min 32.1 / max 82.1, mana 14

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111693 | Blade Spirits scroll (1044413) | `BladeSpiritsScroll` | 32.1 | 82.1 | `BlackPearl` + `Nightshade` + `MandrakeRoot` | ≡— | `Mana 14` | 294 |
| 1111693 | Dispel Field scroll (1044414) | `DispelFieldScroll` | 32.1 | 82.1 | `BlackPearl` + `Garlic` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 14` | 295 |
| 1111693 | Incognito scroll (1044415) | `IncognitoScroll` | 32.1 | 82.1 | `Bloodmoss` + `Garlic` + `Nightshade` | ≡— | `Mana 14` | 296 |
| 1111693 | Magic Reflect scroll (1044416) | `MagicReflectScroll` | 32.1 | 82.1 | `Garlic` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 14` | 297 |
| 1111693 | Mind Blast scroll (1044417) | `MindBlastScroll` | 32.1 | 82.1 | `BlackPearl` + `MandrakeRoot` + `Nightshade` + `SulfurousAsh` | ≡— | `Mana 14` | 298 |
| 1111693 | Paralyze scroll (1044418) | `ParalyzeScroll` | 32.1 | 82.1 | `Garlic` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 14` | 299 |
| 1111693 | Poison Field scroll (1044419) | `PoisonFieldScroll` | 32.1 | 82.1 | `BlackPearl` + `Nightshade` + `SpidersSilk` | ≡— | `Mana 14` | 300 |
| 1111693 | Summon Creature scroll (1044420) | `SummonCreatureScroll` | 32.1 | 82.1 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 14` | 301 |

#### Group 1111693 — Magery circle 6 (8 rows, `DefInscription.cs:303-313`) — min 46.4 / max 96.4, mana 20

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111693 | Dispel scroll (1044421) | `DispelScroll` | 46.4 | 96.4 | `Garlic` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 20` | 306 |
| 1111693 | Energy Bolt scroll (1044422) | `EnergyBoltScroll` | 46.4 | 96.4 | `BlackPearl` + `Nightshade` | ≡— | `Mana 20` | 307 |
| 1111693 | Explosion scroll (1044423) | `ExplosionScroll` | 46.4 | 96.4 | `Bloodmoss` + `MandrakeRoot` | ≡— | `Mana 20` | 308 |
| 1111693 | Invisibility scroll (1044424) | `InvisibilityScroll` | 46.4 | 96.4 | `Bloodmoss` + `Nightshade` | ≡— | `Mana 20` | 309 |
| 1111693 | Mark scroll (1044425) | `MarkScroll` | 46.4 | 96.4 | `Bloodmoss` + `BlackPearl` + `MandrakeRoot` | ≡— | `Mana 20` | 310 |
| 1111693 | Mass Curse scroll (1044426) | `MassCurseScroll` | 46.4 | 96.4 | `Garlic` + `MandrakeRoot` + `Nightshade` + `SulfurousAsh` | ≡— | `Mana 20` | 311 |
| 1111693 | Paralyze Field scroll (1044427) | `ParalyzeFieldScroll` | 46.4 | 96.4 | `BlackPearl` + `Ginseng` + `SpidersSilk` | ≡— | `Mana 20` | 312 |
| 1111693 | Reveal scroll (1044428) | `RevealScroll` | 46.4 | 96.4 | `Bloodmoss` + `SulfurousAsh` | ≡— | `Mana 20` | 313 |

#### Group 1111694 — Magery circle 7 (8 rows, `DefInscription.cs:315-325`) — min 60.7 / max 110.7, mana 40

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111694 | Chain Lightning scroll (1044429) | `ChainLightningScroll` | 60.7 | 110.7 | `BlackPearl` + `Bloodmoss` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 40` | 318 |
| 1111694 | Energy Field scroll (1044430) | `EnergyFieldScroll` | 60.7 | 110.7 | `BlackPearl` + `MandrakeRoot` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 40` | 319 |
| 1111694 | Flamestrike scroll (1044431) | `FlamestrikeScroll` | 60.7 | 110.7 | `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 40` | 320 |
| 1111694 | Gate Travel scroll (1044432) | `GateTravelScroll` | 60.7 | 110.7 | `BlackPearl` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 40` | 321 |
| 1111694 | Mana Vampire scroll (1044433) | `ManaVampireScroll` | 60.7 | 110.7 | `BlackPearl` + `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 40` | 322 |
| 1111694 | Mass Dispel scroll (1044434) | `MassDispelScroll` | 60.7 | 110.7 | `BlackPearl` + `Garlic` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 40` | 323 |
| 1111694 | Meteor Swarm scroll (1044435) | `MeteorSwarmScroll` | 60.7 | 110.7 | `Bloodmoss` + `MandrakeRoot` + `SulfurousAsh` + `SpidersSilk` | ≡— | `Mana 40` | 324 |
| 1111694 | Polymorph scroll (1044436) | `PolymorphScroll` | 60.7 | 110.7 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 40` | 325 |

#### Group 1111694 — Magery circle 8 (8 rows, `DefInscription.cs:327-337`) — min 75.0 / max 125.0, mana 50

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111694 | Earthquake scroll (1044437) | `EarthquakeScroll` | 75.0 | 125.0 | `Bloodmoss` + `MandrakeRoot` + `Ginseng` + `SulfurousAsh` | ≡— | `Mana 50` | 330 |
| 1111694 | Energy Vortex scroll (1044438) | `EnergyVortexScroll` | 75.0 | 125.0 | `BlackPearl` + `Bloodmoss` + `MandrakeRoot` + `Nightshade` | ≡— | `Mana 50` | 331 |
| 1111694 | Resurrection scroll (1044439) | `ResurrectionScroll` | 75.0 | 125.0 | `Bloodmoss` + `Garlic` + `Ginseng` | ≡— | `Mana 50` | 332 |
| 1111694 | Summon Air Elemental scroll (1044440) | `SummonAirElementalScroll` | 75.0 | 125.0 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 50` | 333 |
| 1111694 | Summon Daemon scroll (1044441) | `SummonDaemonScroll` | 75.0 | 125.0 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 50` | 334 |
| 1111694 | Summon Earth Elemental scroll (1044442) | `SummonEarthElementalScroll` | 75.0 | 125.0 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 50` | 335 |
| 1111694 | Summon Fire Elemental scroll (1044443) | `SummonFireElementalScroll` | 75.0 | 125.0 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` + `SulfurousAsh` | ≡— | `Mana 50` | 336 |
| 1111694 | Summon Water Elemental scroll (1044444) | `SummonWaterElementalScroll` | 75.0 | 125.0 | `Bloodmoss` + `MandrakeRoot` + `SpidersSilk` | ≡— | `Mana 50` | 337 |

#### Group 1061677 — Necromancy scrolls (17 rows, `DefInscription.cs:339-358`, gate `Core.SE`)

`AddNecroSpell(int spell, int mana, double minSkill, Type type, params Reg[] regs)` — `DefInscription.cs:190-204`: `minSkill … minSkill + 1.0`, name cliloc `1060509 + spell`, group cliloc 1061677, reg message cliloc `501627`, plus `BlankScroll`×1. Source comment at `:208`: `//Yes, on OSI it's only 1.0 skill diff'. Don't blame me, blame OSI.`

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources (each ×1 + `BlankScroll`×1) | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1061677 | Animate Dead scroll (1060509) | `AnimateDeadScroll` | 39.6 | 40.6 | `GraveDust` + `DaemonBlood` | ≡— | `Mana 23` | 341 |
| 1061677 | Blood Oath scroll (1060510) | `BloodOathScroll` | 19.6 | 20.6 | `DaemonBlood` | ≡— | `Mana 13` | 342 |
| 1061677 | Corpse Skin scroll (1060511) | `CorpseSkinScroll` | 19.6 | 20.6 | `BatWing` + `GraveDust` | ≡— | `Mana 11` | 343 |
| 1061677 | Curse Weapon scroll (1060512) | `CurseWeaponScroll` | 19.6 | 20.6 | `PigIron` | ≡— | `Mana 7` | 344 |
| 1061677 | Evil Omen scroll (1060513) | `EvilOmenScroll` | 19.6 | 20.6 | `BatWing` + `NoxCrystal` | ≡— | `Mana 11` | 345 |
| 1061677 | Horrific Beast scroll (1060514) | `HorrificBeastScroll` | 39.6 | 40.6 | `BatWing` + `DaemonBlood` | ≡— | `Mana 11` | 346 |
| 1061677 | Lich Form scroll (1060515) | `LichFormScroll` | 69.6 | 70.6 | `GraveDust` + `DaemonBlood` + `NoxCrystal` | ≡— | `Mana 23` | 347 |
| 1061677 | Mind Rot scroll (1060516) | `MindRotScroll` | 29.6 | 30.6 | `BatWing` + `DaemonBlood` + `PigIron` | ≡— | `Mana 17` | 348 |
| 1061677 | Pain Spike scroll (1060517) | `PainSpikeScroll` | 19.6 | 20.6 | `GraveDust` + `PigIron` | ≡— | `Mana 5` | 349 |
| 1061677 | Poison Strike scroll (1060518) | `PoisonStrikeScroll` | 49.6 | 50.6 | `NoxCrystal` | ≡— | `Mana 17` | 350 |
| 1061677 | Strangle scroll (1060519) | `StrangleScroll` | 64.6 | 65.6 | `DaemonBlood` + `NoxCrystal` | ≡— | `Mana 29` | 351 |
| 1061677 | Summon Familiar scroll (1060520) | `SummonFamiliarScroll` | 29.6 | 30.6 | `BatWing` + `GraveDust` + `DaemonBlood` | ≡— | `Mana 17` | 352 |
| 1061677 | Vampiric Embrace scroll (1060521) | `VampiricEmbraceScroll` | 98.6 | 99.6 | `BatWing` + `NoxCrystal` + `PigIron` | ≡— | `Mana 23` | 353 |
| 1061677 | Vengeful Spirit scroll (1060522) | `VengefulSpiritScroll` | 79.6 | 80.6 | `BatWing` + `GraveDust` + `PigIron` | ≡— | `Mana 41` | 354 |
| 1061677 | Wither scroll (1060523) | `WitherScroll` | 59.6 | 60.6 | `GraveDust` + `NoxCrystal` + `PigIron` | ≡— | `Mana 23` | 355 |
| 1061677 | Wraith Form scroll (1060524) | `WraithFormScroll` | 19.6 | 20.6 | `NoxCrystal` + `PigIron` | ≡— | `Mana 17` | 356 |
| 1061677 | Exorcism scroll (1060525) | `ExorcismScroll` | 79.6 | 80.6 | `NoxCrystal` + `GraveDust` | ≡— | `Mana 40` | 357 |

#### Group 1111671 — Mysticism scrolls (16 rows, `DefInscription.cs:447-462`, gate `Core.SA`)

`AddMysticSpell(int id, int mana, double minSkill, Type type, params Reg[] regs)` — `DefInscription.cs:206-216`: `minSkill … minSkill + 1.0`, group cliloc 1111671, name cliloc = `id`, reg message cliloc `501627`, plus `BlankScroll`×1.

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources (each ×1 + `BlankScroll`×1) | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111671 | Nether Bolt scroll (1031678) | `NetherBoltScroll` | 0.0 | 1.0 | `SulfurousAsh` + `BlackPearl` | ≡— | `Mana 4` | 447 |
| 1111671 | Healing Stone scroll (1031679) | `HealingStoneScroll` | 0.0 | 1.0 | `Bone` + `Garlic` + `Ginseng` + `SpidersSilk` | ≡— | `Mana 4` | 448 |
| 1111671 | Purge Magic scroll (1031680) | `PurgeMagicScroll` | 0.0 | 1.0 | `FertileDirt` + `Garlic` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 6` | 449 |
| 1111671 | Enchant scroll (1031681) | `EnchantScroll` | 0.0 | 1.0 | `SpidersSilk` + `MandrakeRoot` + `SulfurousAsh` | ≡— | `Mana 6` | 450 |
| 1111671 | Sleep scroll (1031682) | `SleepScroll` | 3.5 | 4.5 | `SpidersSilk` + `BlackPearl` + `Nightshade` | ≡— | `Mana 9` | 451 |
| 1111671 | Eagle Strike scroll (1031683) | `EagleStrikeScroll` | 3.5 | 4.5 | `SpidersSilk` + `Bloodmoss` + `MandrakeRoot` + `Bone` | ≡— | `Mana 9` | 452 |
| 1111671 | Animated Weapon scroll (1031684) | `AnimatedWeaponScroll` | 17.8 | 18.8 | `Bone` + `BlackPearl` + `MandrakeRoot` + `Nightshade` | ≡— | `Mana 11` | 453 |
| 1111671 | Stone Form scroll (1031685) | `StoneFormScroll` | 17.8 | 18.8 | `Bloodmoss` + `FertileDirt` + `Garlic` | ≡— | `Mana 11` | 454 |
| 1111671 | Spell Trigger scroll (1031686) | `SpellTriggerScroll` | 32.1 | 33.1 | `SpidersSilk` + `MandrakeRoot` + `Garlic` + `DragonBlood` | ≡— | `Mana 14` | 455 |
| 1111671 | Mass Sleep scroll (1031687) | `MassSleepScroll` | 32.1 | 33.1 | `SpidersSilk` + `Nightshade` + `Ginseng` | ≡— | `Mana 14` | 456 |
| 1111671 | Cleansing Winds scroll (1031688) | `CleansingWindsScroll` | 46.4 | 47.4 | `Ginseng` + `Garlic` + `DragonBlood` + `MandrakeRoot` | ≡— | `Mana 20` | 457 |
| 1111671 | Bombard scroll (1031689) | `BombardScroll` | 46.4 | 47.4 | `Garlic` + `DragonBlood` + `SulfurousAsh` + `Bloodmoss` | ≡— | `Mana 20` | 458 |
| 1111671 | Spell Plague scroll (1031690) | `SpellPlagueScroll` | 60.7 | 61.7 | `DaemonBone` + `DragonBlood` + `MandrakeRoot` + `Nightshade` + `SulfurousAsh` + **`DaemonBone` again** | ≡— | `Mana 40`; **source passes `Reg.DaemonBone` twice** (`:459`) ⇒ 2× DaemonBone per craft | 459 |
| 1111671 | Hail Storm scroll (1031691) | `HailStormScroll` | 60.7 | 61.7 | `DragonBlood` + `BlackPearl` + `MandrakeRoot` + `Bloodmoss` | ≡— | `Mana 40` | 460 |
| 1111671 | Nether Cyclone scroll (1031692) | `NetherCycloneScroll` | 75.0 | 76.0 | `Bloodmoss` + `Nightshade` + `SulfurousAsh` + `MandrakeRoot` | ≡— | `Mana 50` | 461 |
| 1111671 | Rising Colossus scroll (1031693) | `RisingColossusScroll` | 75.0 | 76.0 | `DaemonBone` + `FertileDirt` + `DragonBlood` + `Nightshade` + `MandrakeRoot` | ≡— | `Mana 50` | 462 |

#### Group 1044294 — Inscription items (16 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources (each ×n) | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044294 | enchanted switch (1072893) | `EnchantedSwitch` | 45.0 | 95.0 | `BlankScroll`×1 + `SpidersSilk`×1 + `BlackPearl`×1 + `SwitchItem`×1 | ≡`BlankMap≡BlankScroll` | gate `Core.ML`; `ForceNonExceptional` | 364 |
| 1044294 | runed prism (1073465) | `RunedPrism` | 45.0 | 95.0 | `BlankScroll`×1 + `SpidersSilk`×1 + `BlackPearl`×1 + `HollowPrism`×1 | ≡同上 | gate `Core.ML`; `ForceNonExceptional` | 370 |
| 1044294 | runebook (1041267) | `Runebook` | 45.0 | 95.0 | `BlankScroll`×8 + `RecallScroll`×1 + `GateTravelScroll`×1 | ≡同上 | **extra hidden cost**: 1 unmarked `RecallRune` — `CraftItem.cs:1050-1071` on `NameNumber == 1041267` | 378 |
| 1044294 | runic atlas (1156443) | `RunicAtlas` | 45.0 | 95.0 | `BlankScroll`×24 + `RecallRune`×3 + `RecallScroll`×3 + `GateTravelScroll`×3 | ≡同上 | gate `Core.TOL`; `AddRecipe(800)` | 385 |
| 1044294 | bulk order book (1028793) | `Engines.BulkOrders.BulkOrderBook` | 65.0 | 115.0 | `BlankScroll`×10 | ≡同上 | gate `Core.AOS` | 395 |
| 1044294 | spellbook (1023834) | `Spellbook` | 50.0 | **126** *(literal, not 126.0)* | `BlankScroll`×10 | ≡同上 | gate `Core.SE` | 400 |
| 1044294 | Scrapper's Compendium (1072940) | `ScrappersCompendium` | 75.0 | 125.0 | `BlankScroll`×100 + `DreadHornMane`×1 + `Taint`×10 + `Corruption`×10 | ≡同上 | gate `Core.ML`; recipe `TinkerRecipes.ScrappersCompendium`; `ForceNonExceptional` | 406 |
| 1044294 | spellbook engraver (1072151) | `SpellbookEngraver` | 75.0 | 100.0 | `Feather`×1 + `BlackPearl`×7 | ≡— | gate `Core.ML` | 413 |
| 1044294 | necromancer spellbook (1074909) | `NecromancerSpellbook` | 50.0 | 100.0 | `BlankScroll`×10 | ≡同上 | gate `Core.ML` | 417 |
| 1044294 | mystic book (1031677) | `MysticBook` | 50.0 | 100.0 | `BlankScroll`×10 | ≡同上 | gate `Core.ML` | 419 |
| 1044294 | Exodus summoning rite (1153498) | `ExodusSummoningRite` | 95.0 | 120.0 | `DaemonBlood`×5 + `Taint`×1 + `DaemonBone`×5 + `SummonDaemonScroll`×1 | ≡— | gate `Core.SA` | 426 |
| 1044294 | prophetic manuscript (1155631) | `PropheticManuscript` | 90.0 | 115.0 | `AncientParchment`×10 + `AntiqueDocumentsKit`×1 + `WoodPulp`×10 + `Beeswax`×5 | ≡— | gate `Core.SA`; `AntiqueDocumentsKit` never consumed (`CraftSystem.cs:287`) | 431 |
| 1044294 | blank scroll (1023636) | `BlankScroll` | 50.0 | 100.0 | `WoodPulp`×1 | ≡— | gate `Core.SA`; **yields `Amount = 5`** (`BlankScroll.cs:56-60`) | 436 |
| 1044294 | scroll binder deed (1113135) | `ScrollBinderDeed` | 75.0 | 125.0 | `WoodPulp`×1 | ≡— | gate `Core.SA`; `SetItemHue(1641)` | 438 |
| 1044294 | gargoyle book (100 pages, 1113290) | `GargoyleBook100` | 60.0 | 100.0 | `BlankScroll`×40 + `Beeswax`×2 | ≡同上 | gate `Core.SA`; string message "You do not have enough beeswax." (`:442`) | 441 |
| 1044294 | gargoyle book (200 pages, 1113291) | `GargoyleBook200` | 72.0 | 100.0 | `BlankScroll`×40 + `Beeswax`×4 | ≡同上 | gate `Core.SA`; string message "You do not have enough beeswax." (`:445`) | 444 |

#### 4d.3.2 `Inscribe.cs` mechanics — book copying, not scroll writing

`Scripts/Skills/Inscribe.cs` (`SkillInfo.Table[(int)SkillName.Inscribe].Callback`, `:13`):

| Step | Exact behaviour | L |
|---|---|---|
| Skill use | `OnUse` sets `InternalTargetSrc`, message `1046295` "Target the book you wish to copy.", target timeout `TimeSpan.FromMinutes(1.0)`, returns `TimeSpan.FromSeconds(1.0)` (skill delay) | 16-24 |
| Source validation | must be `BaseBook`, else `1046296` "That is not a book"; empty book → `501611`; already in use → `501621` | 81-99 |
| Second target | message `501612` "Select a book to copy this to."; timeout 1 min; `SetUser(bookSrc, from)` marks the source busy | 93-97 |
| Destination validation | `bookSrc.Deleted` → return; not a book → `1046296`; empty src → `501611`; same book → `501616`; `!bookDst.Writable` → `501614`; in use → `501621` | 126-142 |
| **Skill check** | **`from.CheckTargetSkill(SkillName.Inscribe, bookDst, 0, 50)`** | **145** |
| Success | `Inscribe.Copy(src, dst)` copies `Title`, `Author`, and page lines 1:1 (`:44-62`); message `501618`; `PlaySound(0x249)` | 147-150 |
| Failure | message `501617` "You fail to make a copy of the book." | 154 |
| Timeout (either target) | message `501619` | 112-114, 161-163 |
| Special case | targeting `Server.Engines.Khaldun.MysteriousBook` routes to `OnInscribeTarget(from)` | 100-103 |

So book copying uses a **fixed 0..50 window** and is independent of the scroll-craft menu. Scrolls are made only through `DefInscription` (menu) and require the spell to be in an owned spellbook:
`CanCraft` (`DefInscription.cs:62-86`) instantiates the `SpellScroll` to read `SpellID` (cached in `_Buffer`), then `Spellbook.Find(from, id)`; `book == null || !book.HasSpell(id)` → `1042404` **"You don't have that spell!"**.

#### 4d.3.3 Inscription → Magery damage bonus (exact formula)

`[SRC]` **`Spell.GetNewAosDamage`** — `Scripts/Spells/Base/Spell.cs:218-239`:
```csharp
int damage = Utility.Dice(dice, sides, bonus) * 100;                 // :222
int inscribeSkill = GetInscribeFixed(m_Caster);                      // :224  == m.Skills[SkillName.Inscribe].Fixed  (:420-425)
int scribeBonus = inscribeSkill >= 1000 ? 10 : inscribeSkill / 200;  // :225
int damageBonus = scribeBonus + (Caster.Int / 10)
                + SpellHelper.GetSpellDamageBonus(m_Caster, target, CastSkill, playerVsPlayer);   // :227-229
int evalSkill  = GetDamageFixed(m_Caster);                           // :231  (EvalInt .Fixed)
int evalScale  = 30 + ((9 * evalSkill) / 100);                       // :232
damage = AOS.Scale(damage, evalScale);                               // :234
damage = AOS.Scale(damage, 100 + damageBonus);                       // :235
damage = AOS.Scale(damage, (int)(scalar * 100));                     // :236
return damage / 100;                                                 // :238
```
`Fixed = Value*10`, so `inscribeSkill >= 1000` ⇔ **Inscribe ≥ 100.0 → +10 damage units** (`100 + 10 = 110 %` multiplier); at Inscribe 50.0 → `500/200 = 2` → `102 %`. Values below 20.0 give 0. `GetInscribeFixed` is `virtual` and can be overridden per spell (`Spell.cs:420-425`); note the commented-out `// m.CheckSkill( SkillName.Inscribe, 0.0, 120.0 );` — **inscription is not gained by casting**.

Other inscription-conditioned spell effects `[SRC]` (same file family):

| Spell | Effect | Formula | L |
|---|---|---|---|
| Reactive Armor | physical resistance mod | `15 + (int)(targ.Skills[Inscribe].Value / 20)` | `Spells/First/ReactiveArmor.cs:88,100` |
| Reactive Armor | duration scalar sum | `(int)(Magery.Value + Meditation.Value + Inscribe.Value)` | `:135` |
| Magic Reflect | physical resist mod | `-25 + (int)(targ.Skills[Inscribe].Value / 20)` | `Spells/Fifth/MagicReflect.cs:85` |
| Magic Reflect | duration scalar sum | `(int)(Magery.Value + Inscribe.Value)` | `:136` |
| Protection | physical resist loss / magic-resist loss | `-15 + Math.Min((int)(Inscribe.Value/20), 15)` and `-35 + Math.Min((int)(Inscribe.Value/20), 35)` | `Spells/Second/Protection.cs:55-56,65-66` |
| Protection | duration scalar sum | `(int)(EvalInt.Value + Meditation.Value + Inscribe.Value)` | `:145` |
| Any spell (SA) | casting focus vs. disruption | `focus += Inscribe.Value >= 50 ? GetInscribeFixed(m_Caster) / 200 : 0;` (focus capped at 12 before this add) | `Spells/Base/Spell.cs:269-277` |

### 4d.4 COOKING — `DefCooking.cs`, gump cliloc 1044003

`CookRecipes` (`DefCooking.cs:7-22`): `RotWormStew=500, GingerbreadCookie=599, DarkChocolateNutcracker=600, MilkChocolateNutcracker=601, WhiteChocolateNutcracker=602, ThreeTieredCake=603, BlackrockStew=604, Hamburger=605, HotDog=606, Sausage=607`.
Row count: **88 `AddCraft` calls**. Tools — all three map to `DefCooking.CraftSystem`:
`Skillet` (itemID `0x97F`, label 1044567, `Scripts/Items/Tools/Skillet.cs:10,27-33,34-40`), `FlourSifter` (itemID `0x103E`, `Scripts/Items/Tools/FlourSifter.cs:8,27-33`), `RollingPin` (itemID `0x1043`, `Scripts/Items/Tools/RollingPin.cs:10,27-33`).

#### Group 1044495 — Ingredients (8 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044495 | sack of flour (1024153) | `SackFlour` | 0.0 | 100.0 | `WheatSheaf`×2 | ≡— | `SetNeedMill(true)` — needs a flour mill | 126 |
| 1044495 | dough (1024157) | `Dough` | 0.0 | 100.0 | `SackFlourOpen`×1 + `BaseBeverage`×1 | ≡— | beverage default Water | 129 |
| 1044495 | sweet dough (1041340) | `SweetDough` | 0.0 | 100.0 | `Dough`×1 + `JarHoney`×1 | ≡— | — | 132 |
| 1044495 | cake mix (1041002) | `CakeMix` | 0.0 | 100.0 | `SackFlourOpen`×1 + `SweetDough`×1 | ≡— | — | 135 |
| 1044495 | cookie mix (1024159) | `CookieMix` | 0.0 | 100.0 | `JarHoney`×1 + `SweetDough`×1 | ≡— | — | 138 |
| 1044495 | cocoa butter (1079998) | `CocoaButter` | 0.0 | 100.0 | `CocoaPulp`×1 | ≡— | gate `Core.ML`; `SetItemHue(0x457)`; `SetNeedOven(true)` | 143 |
| 1044495 | cocoa liquor (1079999) | `CocoaLiquor` | 0.0 | 100.0 | `CocoaPulp`×1 + `EmptyPewterBowl`×1 | ≡— | gate `Core.ML`; `SetItemHue(0x46A)`; `SetNeedOven(true)` | 147 |
| 1044495 | wheat wort (1150275) | `WheatWort` | 30.0 | 100.0 | `Bottle`×1 + `BaseBeverage`×1 + `SackFlourOpen`×1 | ≡— | `SetItemHue(1281)`; beverage default Water | 153 |

#### Group 1044496 — Preparations (20 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044496 | unbaked quiche (1041339) | `UnbakedQuiche` | 0.0 | 100.0 | `Dough`×1 + `Eggs`×1 | ≡— | — | 160 |
| 1044496 | unbaked meat pie (1041338) | `UnbakedMeatPie` | 0.0 | 100.0 | `Dough`×1 + `RawRibs`×1 | ≡— | source TODO "must also support chicken and lamb legs" (`:163`) | 164 |
| 1044496 | uncooked sausage pizza (1041337) | `UncookedSausagePizza` | 0.0 | 100.0 | `Dough`×1 + `Sausage`×1 | ≡`Sausage≡CookableSausage` | — | 167 |
| 1044496 | uncooked cheese pizza (1041341) | `UncookedCheesePizza` | 0.0 | 100.0 | `Dough`×1 + `CheeseWheel`×1 | ≡`CheeseWheel≡CheeseWedge` | — | 170 |
| 1044496 | unbaked fruit pie (1041334) | `UnbakedFruitPie` | 0.0 | 100.0 | `Dough`×1 + `Pear`×1 | ≡— | — | 173 |
| 1044496 | unbaked peach cobbler (1041335) | `UnbakedPeachCobbler` | 0.0 | 100.0 | `Dough`×1 + `Peach`×1 | ≡— | — | 176 |
| 1044496 | unbaked apple pie (1041336) | `UnbakedApplePie` | 0.0 | 100.0 | `Dough`×1 + `Apple`×1 | ≡— | — | 179 |
| 1044496 | unbaked pumpkin pie (1041342) | `UnbakedPumpkinPie` | 0.0 | 100.0 | `Dough`×1 + `Pumpkin`×1 | ≡`Pumpkin≡SmallPumpkin` | — | 182 |
| 1044496 | green tea (1030316) | `GreenTea` | 80.0 | 130.0 | `GreenTeaBasket`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SE`; `SetNeedOven(true)` | 187 |
| 1044496 | wasabi clumps (1029451) | `WasabiClumps` | 70.0 | 120.0 | `BaseBeverage`×1 + `WoodenBowlOfPeas`×3 | ≡`WoodenBowlOfPeas≡PewterBowlOfPeas` | gate `Core.SE` | 191 |
| 1044496 | sushi rolls (1030303) | `SushiRolls` | 90.0 | 120.0 | `BaseBeverage`×1 + `RawFishSteak`×10 | ≡— | gate `Core.SE` | 194 |
| 1044496 | sushi platter (1030305) | `SushiPlatter` | 90.0 | 120.0 | `BaseBeverage`×1 + `RawFishSteak`×10 | ≡— | gate `Core.SE` | 197 |
| 1044496 | tribal paint (1040000) | `TribalPaint` | `Core.ML ? 55.0 : 80.0` | `Core.ML ? 105.0 : 80.0` | `SackFlourOpen`×1 + `TribalBerry`×1 | ≡— | **min/max ternary on `Core.ML`** (`:201`) | 201 |
| 1044496 | egg bomb (1030249) | `EggBomb` | 90.0 | 120.0 | `Eggs`×1 + `SackFlourOpen`×3 | ≡— | gate `Core.SE` | 206 |
| 1044496 | parrot wafer (1032246) | `ParrotWafer` | 37.5 | 87.5 | `Dough`×1 + `JarHoney`×1 + `RawFishSteak`×10 | ≡— | gate `Core.ML` | 213 |
| 1044496 | plant pigment (1112132) | `PlantPigment` | 75.0 | 100.0 | `PlantClippings`×1 + `Bottle`×1 | ≡— | gate `Core.SA`; `SetRequireResTarget` | 222 |
| 1044496 | natural dye (1112136) | `NaturalDye` | 65.0 | 115.0 | `PlantPigment`×1 + `ColorFixative`×1 | ≡— | gate `Core.SA`; `SetRequireResTarget` | 226 |
| 1044496 | color fixative (1112135) | `ColorFixative` | 75.0 | 100.0 | `BaseBeverage`×1 + `SilverSerpentVenom`×1 | ≡— | gate `Core.SA`; `SetBeverageType(Wine)` | 230 |
| 1044496 | wood pulp (1113136) | `WoodPulp` | 60.0 | 100.0 | `BarkFragment`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SA` | 234 |
| 1044496 | charcoal (1116303) | `Charcoal` | 0.0 | 50.0 | `Board`×1 | ≡`Board≡Log` | gate `Core.HS`; `SetUseAllRes(true)`; `SetNeedHeat(true)` | 242 |

#### Group 1044497 — Baking (18 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044497 | bread loaf (1024156) | `BreadLoaf` | 0.0 | 100.0 | `Dough`×1 | ≡— | `SetNeedOven(true)` | 250 |
| 1044497 | cookies (1025643) | `Cookies` | 0.0 | 100.0 | `CookieMix`×1 | ≡— | `SetNeedOven(true)` | 253 |
| 1044497 | cake (1022537) | `Cake` | 0.0 | 100.0 | `CakeMix`×1 | ≡— | `SetNeedOven(true)` | 256 |
| 1044497 | muffins (1022539) | `Muffins` | 0.0 | 100.0 | `SweetDough`×1 | ≡— | `SetNeedOven(true)` | 259 |
| 1044497 | quiche (1041345) | `Quiche` | 0.0 | 100.0 | `UnbakedQuiche`×1 | ≡— | `SetNeedOven(true)` | 262 |
| 1044497 | meat pie (1041347) | `MeatPie` | 0.0 | 100.0 | `UnbakedMeatPie`×1 | ≡— | `SetNeedOven(true)` | 265 |
| 1044497 | sausage pizza (1044517) | `SausagePizza` | 0.0 | 100.0 | `UncookedSausagePizza`×1 | ≡— | `SetNeedOven(true)` | 268 |
| 1044497 | cheese pizza (1044516) | `CheesePizza` | 0.0 | 100.0 | `UncookedCheesePizza`×1 | ≡— | `SetNeedOven(true)` | 271 |
| 1044497 | fruit pie (1041346) | `FruitPie` | 0.0 | 100.0 | `UnbakedFruitPie`×1 | ≡— | `SetNeedOven(true)` | 274 |
| 1044497 | peach cobbler (1041344) | `PeachCobbler` | 0.0 | 100.0 | `UnbakedPeachCobbler`×1 | ≡— | `SetNeedOven(true)` | 277 |
| 1044497 | apple pie (1041343) | `ApplePie` | 0.0 | 100.0 | `UnbakedApplePie`×1 | ≡— | `SetNeedOven(true)` | 280 |
| 1044497 | pumpkin pie (1041348) | `PumpkinPie` | 0.0 | 100.0 | `UnbakedPumpkinPie`×1 | ≡— | `SetNeedOven(true)` | 283 |
| 1044497 | miso soup (1030317) | `MisoSoup` | 60.0 | 110.0 | `RawFishSteak`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SE`; `SetNeedOven(true)` | 288 |
| 1044497 | white miso soup (1030318) | `WhiteMisoSoup` | 60.0 | 110.0 | `RawFishSteak`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SE`; `SetNeedOven(true)` | 292 |
| 1044497 | red miso soup (1030319) | `RedMisoSoup` | 60.0 | 110.0 | `RawFishSteak`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SE`; `SetNeedOven(true)` | 296 |
| 1044497 | awase miso soup (1030320) | `AwaseMisoSoup` | 60.0 | 110.0 | `RawFishSteak`×1 + `BaseBeverage`×1 | ≡— | gate `Core.SE`; `SetNeedOven(true)` | 300 |
| 1044497 | gingerbread cookie (1031233) | `GingerBreadCookie` | 35.0 | 85.0 | `CookieMix`×1 + `FreshGinger`×1 | ≡— | `AddRecipe(599)`; `SetNeedOven(true)` | 305 |
| 1044497 | three-tiered cake (1154465) | `ThreeTieredCake` | 60.0 | 110.0 | `CakeMix`×3 | ≡— | `AddRecipe(603)`; `SetNeedOven(true)` | 310 |

#### Group 1044498 — Barbecue (12 rows)

All six base rows carry **`SetNeedHeat(true)` + `SetUseAllRes(true)` + `ForceNonExceptional`** (source comment `// Barbecue` `:315`).

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044498 | cooked bird (1022487) | `CookedBird` | 0.0 | 100.0 | `RawBird`×1 | ≡— | Heat; UseAllRes; NonExc | 316 |
| 1044498 | chicken leg (1025640) | `ChickenLeg` | 0.0 | 100.0 | `RawChickenLeg`×1 | ≡— | Heat; UseAllRes; NonExc | 321 |
| 1044498 | fish steak (1022427) | `FishSteak` | 0.0 | 100.0 | `RawFishSteak`×1 | ≡— | Heat; UseAllRes; NonExc | 326 |
| 1044498 | fried eggs (1022486) | `FriedEggs` | 0.0 | 100.0 | `Eggs`×1 | ≡— | Heat; UseAllRes; NonExc | 331 |
| 1044498 | lamb leg (1025642) | `LambLeg` | 0.0 | 100.0 | `RawLambLeg`×1 | ≡— | Heat; UseAllRes; NonExc | 336 |
| 1044498 | ribs (1022546) | `Ribs` | 0.0 | 100.0 | `RawRibs`×1 | ≡— | Heat; UseAllRes; NonExc | 341 |
| 1044498 | bowl of rotworm stew (1031706) | `BowlOfRotwormStew` | 0.0 | 100.0 | `RawRotwormMeat`×1 | ≡— | gate `Core.SA`; Heat; UseAllRes; `AddRecipe(500)`; NonExc | 348 |
| 1044498 | bowl of blackrock stew (1115752) | `BowlOfBlackrockStew` | 30.0 | 70.0 | `BowlOfRotwormStew`×1 + `SmallPieceofBlackrock`×1 | ≡— | gate `Core.SA`; Heat; UseAllRes; `SetItemHue(1954)`; `AddRecipe(604)`; NonExc | 354 |
| 1044498 | Khaldun tasty treat (1158680) | `KhaldunTastyTreat` | 60.0 | 100.0 | `RawFishSteak`×40 | ≡— | gate `Core.EJ`; UseAllRes; Heat | 365 |
| 1044498 | hamburger (1125202) | `Hamburger` | 40.0 | 80.0 | `BreadLoaf`×1 + `RawRibs`×1 + `Lettuce`×1 | ≡`Lettuce≡FarmableLettuce` | gate `Core.TOL`; Heat; UseAllRes; `AddRecipe(605)` | 372 |
| 1044498 | hot dog (1125200) | `HotDog` | 40.0 | 80.0 | `BreadLoaf`×1 + `Sausage`×1 | ≡`Sausage≡CookableSausage` | gate `Core.TOL`; Heat; UseAllRes; `AddRecipe(606)` | 379 |
| 1044498 | cookable sausage (1125198) | `CookableSausage` | 30.0 | 70.0 | `Ham`×1 + `DriedHerbs`×1 | ≡— | gate `Core.TOL`; Heat; UseAllRes; `AddRecipe(607)` | 385 |

#### Group 1073108 — Enchanted (4 rows, gate `Core.ML`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1073108 | food engraver (1072951) | `FoodEngraver` | 75.0 | 100.0 | `Dough`×1 + `JarHoney`×1 | ≡— | — | 396 |
| 1073108 | enchanted apple (1072952) | `EnchantedApple` | 60.0 | 85.0 | `Apple`×1 + `GreaterHealPotion`×1 | ≡— | `ForceNonExceptional` | 399 |
| 1073108 | grapes of wrath (1072953) | `GrapesOfWrath` | 95.0 | 120.0 | `Grapes`×1 + `GreaterStrengthPotion`×1 | ≡— | `ForceNonExceptional` | 403 |
| 1073108 | fruit bowl (1072950) | `FruitBowl` | 55.0 | 105.0 | `EmptyWoodenBowl`×1 + `Pear`×3 + `Apple`×3 + `Banana`×3 | ≡— | — | 407 |

#### Group 1080001 — Chocolatiering (7 rows, gate `Core.ML`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1080001 | sweet cocoa butter (1156401) | `SweetCocoaButter` | 15.0 | 100.0 | `SackOfSugar`×1 + `CocoaButter`×1 | ≡— | gate `Core.TOL`; `SetItemHue(0x457)`; `SetNeedOven(true)` | 419 |
| 1080001 | dark chocolate (1079994) | `DarkChocolate` | 15.0 | 100.0 | `SackOfSugar`×1 + `CocoaButter`×1 + `CocoaLiquor`×1 | ≡— | `SetItemHue(0x465)` | 425 |
| 1080001 | milk chocolate (1079995) | `MilkChocolate` | 32.5 | 107.5 | `SackOfSugar`×1 + `CocoaButter`×1 + `CocoaLiquor`×1 + `BaseBeverage`×1 | ≡— | `SetBeverageType(Milk)`; `SetItemHue(0x461)` | 430 |
| 1080001 | white chocolate (1079996) | `WhiteChocolate` | 52.5 | 127.5 | `SackOfSugar`×1 + `CocoaButter`×1 + `Vanilla`×1 + `BaseBeverage`×1 | ≡— | `SetBeverageType(Milk)`; `SetItemHue(0x47E)` | 437 |
| 1080001 | dark chocolate nutcracker (1156390) | `ChocolateNutcracker` | 15.0 | 100.0 | `SweetCocoaButter`×1 + `SweetCocoaButter`×1 + `CocoaLiquor`×1 | ≡— | gate `Core.TOL`; `AddRecipe(600)`; `SetData(ChocolateType.Dark)`; note **`SweetCocoaButter` listed twice** (`:447-448`) ⇒ 2 per craft | 447 |
| 1080001 | milk chocolate nutcracker (1156391) | `ChocolateNutcracker` | 32.5 | 107.5 | `SweetCocoaButter`×1 + `SweetCocoaButter`×1 + `CocoaLiquor`×1 | ≡— | gate `Core.TOL`; `AddRecipe(601)`; `SetData(ChocolateType.Milk)` | 453 |
| 1080001 | white chocolate nutcracker (1156392) | `ChocolateNutcracker` | 52.5 | 127.5 | `SweetCocoaButter`×1 + `SweetCocoaButter`×1 + `CocoaLiquor`×1 | ≡— | gate `Core.TOL`; `AddRecipe(602)`; `SetData(ChocolateType.White)` | 459 |

#### Group 1116340 — Fish Pies (16 rows, gate `Core.SA`; every row `SetNeedOven(true)`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1116340 | great barracuda pie (1116214) | `GreatBarracudaPie` | 61.0 | 110.0 | `GreatBarracudaSteak`×1 + `MentoSeasoning`×1 + `ZoogiFungus`×1 | ≡— | Oven | 472 |
| 1116340 | giant koi pie (1116216) | `GiantKoiPie` | 61.0 | 110.0 | `GiantKoiSteak`×1 + `MentoSeasoning`×1 + `WoodenBowlOfPeas`×1 + `Dough`×1 | ≡ bowl-peas group | Oven | 477 |
| 1116340 | fire fish pie (1116217) | `FireFishPie` | 55.0 | 105.0 | `FireFishSteak`×1 + `Dough`×1 + `Carrot`×1 + `SamuelsSecretSauce`×1 | ≡— | Oven | 483 |
| 1116340 | stone crab pie (1116227) | `StoneCrabPie` | 55.0 | 105.0 | `StoneCrabMeat`×1 + `Dough`×1 + `Cabbage`×1 + `SamuelsSecretSauce`×1 | ≡— | Oven | 489 |
| 1116340 | blue lobster pie (1116228) | `BlueLobsterPie` | 55.0 | 105.0 | `BlueLobsterMeat`×1 + `Dough`×1 + `TribalBerry`×1 + `SamuelsSecretSauce`×1 | ≡— | Oven | 495 |
| 1116340 | reaper fish pie (1116218) | `ReaperFishPie` | 55.0 | 105.0 | `ReaperFishSteak`×1 + `Dough`×1 + `Pumpkin`×1 + `SamuelsSecretSauce`×1 | ≡`Pumpkin≡SmallPumpkin` | Oven | 501 |
| 1116340 | crystal fish pie (1116219) | `CrystalFishPie` | 55.0 | 105.0 | `CrystalFishSteak`×1 + `Dough`×1 + `Apple`×1 + `SamuelsSecretSauce`×1 | ≡— | Oven | 507 |
| 1116340 | bull fish pie (1116220) | `BullFishPie` | 55.0 | 105.0 | `BullFishSteak`×1 + `Dough`×1 + `Squash`×1 + `MentoSeasoning`×1 | ≡— | Oven | 513 |
| 1116340 | summer dragonfish pie (1116221) | `SummerDragonfishPie` | 55.0 | 105.0 | `SummerDragonfishSteak`×1 + `Dough`×1 + `Onion`×1 + `MentoSeasoning`×1 | ≡— | Oven | 519 |
| 1116340 | fairy salmon pie (1116222) | `FairySalmonPie` | 55.0 | 105.0 | `FairySalmonSteak`×1 + `Dough`×1 + `EarOfCorn`×1 + `DarkTruffle`×1 | ≡— | Oven | 525 |
| 1116340 | lava fish pie (1116223) | `LavaFishPie` | 55.0 | 105.0 | `LavaFishSteak`×1 + `Dough`×1 + `CheeseWheel`×1 + `DarkTruffle`×1 | ≡`CheeseWheel≡CheeseWedge` | Oven | 531 |
| 1116340 | autumn dragonfish pie (1116224) | `AutumnDragonfishPie` | 55.0 | 105.0 | `AutumnDragonfishSteak`×1 + `Dough`×1 + `Pear`×1 + `MentoSeasoning`×1 | ≡— | Oven | 537 |
| 1116340 | spider crab pie (1116229) | `SpiderCrabPie` | 55.0 | 105.0 | `SpiderCrabMeat`×1 + `Dough`×1 + `Lettuce`×1 + `MentoSeasoning`×1 | ≡`Lettuce≡FarmableLettuce` | Oven | 543 |
| 1116340 | yellowtail barracuda pie (1116098) | `YellowtailBarracudaPie` | 55.0 | 105.0 | `YellowtailBarracudaSteak`×1 + `Dough`×1 + `BaseBeverage`×1 + `MentoSeasoning`×1 | ≡— | Oven; `SetBeverageType(Wine)` (`:551` uses cliloc 1022503) | 549 |
| 1116340 | holy mackerel pie (1116225) | `HolyMackerelPie` | 55.0 | 105.0 | `HolyMackerelSteak`×1 + `Dough`×1 + `JarHoney`×1 + `MentoSeasoning`×1 | ≡— | Oven | 555 |
| 1116340 | unicorn fish pie (1116226) | `UnicornFishPie` | 55.0 | 105.0 | `UnicornFishSteak`×1 + `Dough`×1 + `FreshGinger`×1 + `MentoSeasoning`×1 | ≡— | Oven | 561 |

*(Note on row 549: the beverage resource at `DefCooking.cs:551` is declared with cliloc 1022503, the same cliloc the code pairs with `BeverageType.Wine` at `:230-232`; no explicit `SetBeverageType` call is present on this row, so the effective filter is the default `Water` unless the client/server cliloc mapping is relied upon. `[PARTIAL]` — resolving this requires reading the cliloc text, which is not in the repo.)*

#### Group 1155736 — Beverages (3 rows, gate: none — present in all eras)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1155736 | coffee mug (1155737) | `CoffeeMug` | 0.0 | **28.58** | `CoffeeGrounds`×1 + `BaseBeverage`×1 | ≡— | `SetBeverageType(Water)`; `SetNeedMaker(true)`; `ForceNonExceptional` | 570 |
| 1155736 | basket of green tea mug (1030315) | `BasketOfGreenTeaMug` | 0.0 | **28.58** | `GreenTeaBasket`×1 + `BaseBeverage`×1 | ≡— | `SetBeverageType(Water)`; `SetNeedMaker(true)`; `ForceNonExceptional` | 576 |
| 1155736 | hot cocoa mug (1155738) | `HotCocoaMug` | 0.0 | **28.58** | `CocoaLiquor`×1 + `SackOfSugar`×1 + `BaseBeverage`×1 | ≡— | `SetBeverageType(Milk)`; `SetNeedMaker(true)`; `ForceNonExceptional` | 582 |

#### 4d.4.1 Raw → cooked chain `[SRC]`

Two independent mechanisms exist in the codebase:

**(1) `CookableFood` — direct "use item on fire" path** (`Scripts/Items/Consumables/CookableFood.cs`). `CookableFood : Item, IQuality, ICommodity` (`:7`) with a `CookingLevel` (`:12-23`) and `public abstract Food Cook();` (`:59`). Activation is commented out in `OnDoubleClick` (`#if false`, `:94-102`) — the live path is `InternalTarget` (`:133-205`) targeting a heat source recognised by `IsHeatSource` (`:104-131`, **item-ID ranges only, no `NeedHeat` table**: Campfire `0xDE3-0xDE9`, sandstone `0x461-0x48E`, stone `0x92B-0x96C`, Firepit `0xFAC`, heating stands `0x184A-0x184C`/`0x184E-0x1850`, fire field `0x398C-0x399F`).

| Raw | C# raw type | itemID / CookingLevel | Produces | L |
|---|---|---|---|---|
| RawRibs | `RawRibs` | `0x9F1`, 10 | `Ribs` | 209-249 |
| RawLambLeg | `RawLambLeg` | `0x1609`, 10 | `LambLeg` | 252-294 |
| RawChickenLeg | `RawChickenLeg` | `0x1607`, 10 | `ChickenLeg` | 297-330 |
| RawBird | `RawBird` | `0x9B9`, 10 | `CookedBird` | 333-373 |
| RawFishSteak | `RawFishSteak` | `0x097A`, 10 (`DefaultWeight 0.1`) | `FishSteak` | 985-1035 |
| RawRotwormMeat | `RawRotwormMeat` | `0x2DB9`, 10 | **`null`** (`Cook()` returns null) | 1037-1077 |
| Eggs | `Eggs` | `0x9B5`, 15 | `FriedEggs` | 768-816 |
| BrightlyColoredEggs | `BrightlyColoredEggs` | `0x9B5`, 15, `Hue = 3 + (Utility.Random(20) * 5)` | `FriedEggs` | 819-860 |
| EasterEggs | `EasterEggs` | `0x9B5`, 15, same hue roll | `FriedEggs` | 863-904 |
| UnbakedQuiche | `UnbakedQuiche` | `0x1042`, 25 | `Quiche` | 725-765 |
| UnbakedMeatPie | `UnbakedMeatPie` | `0x1042`, 25 | `MeatPie` | 462-502 |
| UnbakedFruitPie | `UnbakedFruitPie` | `0x1042`, 25 | `FruitPie` | 419-459 |
| UnbakedPeachCobbler | `UnbakedPeachCobbler` | `0x1042`, 25 | `PeachCobbler` | 376-416 |
| UnbakedPumpkinPie | `UnbakedPumpkinPie` | `0x1042`, 25 | `PumpkinPie` | 505-545 |
| UnbakedApplePie | `UnbakedApplePie` | `0x1042`, 25 | `ApplePie` | 548-588 |
| UncookedCheesePizza | `UncookedCheesePizza` | `0x1083`, 20 (alias `Server.Items.UncookedPizza`) | `CheesePizza` | 590-638 |
| UncookedSausagePizza | `UncookedSausagePizza` | `0x1083`, 20 | `SausagePizza` | 640-681 |
| CookieMix | `CookieMix` | `0x103F`, 20 | `Cookies` | 906-940 |
| CakeMix | `CakeMix` | `0x103F`, 40 | `Cake` | 942-983 |

**(2) `DefCooking` menu rows** (the tables above) — the "official" path, gated by `NeedHeat`/`NeedOven`/`NeedMill`/`NeedMaker` and by the success formula, and it produces the cooked item directly from the raw one.

#### 4d.4.2 Burn / failure behaviour `[SRC]`

| Path | Failure condition | Message |
|---|---|---|
| `CookableFood.InternalTimer` (5.0 s delay) | moved > 3 tiles from the heat source → `500686` "You burn the food to a crisp! It's ruined."; the raw item was already consumed before the timer started (`:154`) | `CookableFood.cs:174-190` |
| `CookableFood.InternalTimer` | `!from.CheckSkill(SkillName.Cooking, m_CookableFood.CookingLevel, 100)` → `500686`, raw item lost | `CookableFood.cs:192-202` |
| `CookableFood.InternalTimer` success | `from.AddToBackpack(cookedFood)` then `PlaySound(0x57)` | `:194-198` |
| `SweetDough` → `Campfire` (legacy) | distance > 3 → `500686`; `!CheckSkill(Cooking, 0, 10)` → `500686`; success → `new Muffins()` + `0x57` | `Scripts/Items/Consumables/Cooking.cs:264-293` |
| Cooking craft menu | normal craft failure | `DefCooking.PlayEndingEffect`: `lostMaterial` → `1044043` "…and some of your materials are lost."; else `1044157` "…but no materials were lost." (`DefCooking.cs:96-107`) |
| Cooking craft menu quality | `quality == 0` → `502785` "barely able to make this item"; `quality == 2` (+mark) → `1044156` / `1044155`; else `1044154` | `DefCooking.cs:110-117` |

Resource-loss-on-failure rule: `CraftSystem.ConsumeOnFailure` returns false for a fixed no-consume list `CapturedEssence, EyeOfTheTravesty, DiseasedBark, LardOfParoxysmus, GrizzledBones, DreadHornMane, Blight, Corruption, Muculent, Scourge, Putrefaction, Taint, MidnightBracers, CrimsonCincture, GargishCrimsonCincture, LeurociansMempoOfFortune, LeggingsOfBane, GauntletsOfNobility, StaffOfTheMagi, BlackrockMoonstone, Factions.Silver, RingOfTheElements, HatOfTheMagi, AutomatonActuator, AntiqueDocumentsKit` (`CraftSystem.cs:268-293`).

#### 4d.4.3 Food effects `[SRC]`

Eating (`Food.cs:181-252`): refuses if `from.Hunger >= 20` (`500867` "You are simply too full to eat any more!"); else
```
iHunger = from.Hunger + fillFactor
if (from.Stam < from.StamMax) from.Stam += Utility.Random(6, 3) + fillFactor / 5;
Hunger = min(iHunger, 20)
```
messages at thresholds `<5` `500868`, `<10` `500869`, `<15` `500870`, else `500871`; stuffing to 20 → `500872` (`Food.cs:219-252`). Poison applied on eat if the food was poisoned (`:201-202`). `Food.WillStack` requires equal `PlayerConstructed` (`:166-169`).

| Food item (cooked result) | `FillFactor` | L |
|---|---|---|
| `BreadLoaf` | 3 | `Food.cs:348` |
| `Bacon` | 1 | `:384` |
| `SlabOfBacon` | 3 | `:420` |
| `FishSteak` | 3 | `:465` |
| `CheeseWheel` / `CheeseWedge` | 3 / 3 | `:508`, `:551` |
| `CheeseSlice` | 1 | `:594` |
| `FrenchBread` | 3 | `:630` |
| `FriedEggs` | 4 | `:668` |
| `CookedBird` | 5 | `:706` |
| `RoastPig` | 20 | `:742` |
| `Sausage` | 4 | `:778` |
| `Ham` | 5 | `:814` |
| `Cake` | 10 | `:845` |
| `Ribs` | 5 | `:883` |
| `Cookies` | 4 | `:914` |
| `Muffins` | 4 | `:945` |
| `CheesePizza` | 6 | `:988` |
| `SausagePizza` | 6 | `:1027` |
| `Pizza` | 6 | `:1058` |
| `FruitPie` | 5 | `:1097` |
| `MeatPie` | 5 | `:1136` |
| `PumpkinPie` | 5 | `:1175` |
| `ApplePie` | 5 | `:1214` |
| `PeachCobbler` | 5 | `:1253` |
| `Quiche` | 5 | `:1292` |
| `LambLeg` | 5 | `:1330` |
| `ChickenLeg` | 4 | `:1368` |
| `HoneydewMelon`, `YellowGourd`, `GreenGourd`, `EarOfCorn`, `Turnip` | 1 each | `:1405,1442,1479,1516,1552` |
| `Hamburger` | 2 | `:1709` |
| `HotDog` | 2 | `:1747` |
| `CookableSausage` | 2 | `:1779` |
| `PulledPorkPlatter` / `PulledPorkSandwich` | 5 / 3 | `:1810`, `:1842` |
| `WasabiClumps`, `BentoBox`, `SushiRolls`, `SushiPlatter`, `GreenTea`, `MisoSoup`, `WhiteMisoSoup`, `RedMisoSoup`, `AwaseMisoSoup` | 2 each | `Asian.cs:42,102,142,173,234,265,296,327,358` |
| `EnchantedApple`, `GrapesOfWrath` | `FillFactor = 0`, `Stackable = false` (magical food path) | `BaseMagicalFood.cs:18-24` |

**Magical food** (`BaseMagicalFood.cs`): does not use `FillHunger` — `Eat` checks `IsUnderInfluence`/`CoolingDown`, sends `EatMessage`, starts `Duration`/`Cooldown` timers, then consumes (`:133-151`). `MagicalFood` enum `None=0x0, GrapesOfWrath=0x1, EnchantedApple=0x2` (`:6-11`). Both are the only two cooking rows with a non-zero `GetChanceAtMin` (`.5`, `DefCooking.cs:64-73`).

### 4d.5 CARTOGRAPHY — `DefCartography.cs`, gump cliloc 1044008

`CartographyRecipes` (`DefCartography.cs:7-10`): `EodonianWallMap = 1000`.
Row count: **8 `AddCraft` calls, all in one group `1044448`.** Source uses explicit `this.AddCraft(...)` on the first four rows.
Tool: `MapmakersPen : BaseTool`, itemID `0x0FBF`/`0x0FC0` flipable, label 1044167, `CraftSystem => DefCartography.CraftSystem` (`Scripts/Items/Tools/MapmakersPen.cs:6-11,28-41`). `Weight = 1.0`.

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044448 | local map (1015230) | `LocalMap` | 10.0 | 70.0 | `BlankMap`×1 | ≡`BlankMap≡BlankScroll` | — | 95 |
| 1044448 | city map (1015231) | `CityMap` | 25.0 | 85.0 | `BlankMap`×1 | ≡同上 | — | 96 |
| 1044448 | sea chart (1015232) | `SeaChart` | 35.0 | 95.0 | `BlankMap`×1 | ≡同上 | — | 97 |
| 1044448 | world map (1015233) | `WorldMap` | 39.5 | 99.5 | `BlankMap`×1 | ≡同上 | — | 98 |
| 1044448 | tattered wall map (south) (1072891) | `TatteredWallMapSouth` | 90.0 | 150.0 | `TreasureMap`(1073494)×10 + `TreasureMap`(1073498)×5 + `TreasureMap`(1073500)×3 + `TreasureMap`(1073502)×1 | ≡— | `AddResCallback(ConsumeTatteredWallMapRes)` | 100 |
| 1044448 | tattered wall map (east) (1072892) | `TatteredWallMapEast` | 90.0 | 150.0 | same four TreasureMap stacks | ≡— | `AddResCallback(ConsumeTatteredWallMapRes)` | 106 |
| 1044448 | Eodonian wall map (1156690) | `EodonianWallMap` | 65.0 | 125.0 | `BlankMap`×50 + `UnabridgedAtlasOfEodon`×1 | ≡同上 | `AddRecipe(1000)` | 112 |
| 1044448 | star chart (1158493) | `StarChart` | 0.0 | 60.0 | `BlankMap`×1 | ≡同上 | **`SetForceSuccess(75)`** ⇒ success chance pinned to 0.75 (`CraftItem.cs:1369-1372`); `PlayEndingEffect` returns `1158494` for `StarChart` (`DefCartography.cs:86-87`) | 116 |

The four `TreasureMap` resources in the tattered-wall-map rows are **level-filtered in code, not by type**: `ConsumeTatteredWallMapRes` (`DefCartography.cs:120-189`) walks the crafter's backpack `TreasureMap`s and only accepts those with `map.CompletedBy == from`, counting levels `1 → 10`, `3 → 5`, `4 → 3`, `5 → 1`; on shortage it returns that row's message (`1073495`, `1073499`, `1073501`, `1073503` respectively), and only when `type == ConsumeType.All` and no shortage is found does it `Consume()` the collected maps (`:181-185`).
`CraftItem.ConsumeResCallback` is invoked first in `ConsumeRes` (`CraftItem.cs:900-909`), before heat/oven/water checks.

#### 4d.5.1 Blank map / blank scroll chain `[SRC]`

| Object | Class / file | Notes |
|---|---|---|
| `BlankMap` | `BlankMap : MapItem` — `Scripts/Items/Tools/BlankMap.cs:5` | double-click → `SendLocalizedMessageTo(from, 500208)` "It appears to be blank." (`:17-20`). Born from `MapItem()` default ctor → `Map.Trammel`, itemID `0x14EC`, `Weight = 1.0`, `Width = 200`, `Height = 200` (`Scripts/Items/Tools/MapItem.cs:66-80`) |
| `BlankScroll` | `BlankScroll : Item, ICommodity, ICraftable` — `Scripts/Items/Resource/BlankScroll.cs:6` | itemID `0xEF3`, `Stackable`, `Weight = 1.0` (`:14-21`); craftable from `WoodPulp`×1 in the Inscription menu (SA) and **`OnCraft` forces `Amount = 5`** (`:56-60`) |
| Interchangeability | `ItemTypesTable` row `new[] {typeof(BlankMap), typeof(BlankScroll)}` | `CraftItem.cs:373` — a Cartography `BlankMap` cost can be paid with `BlankScroll`, and an Inscription `BlankScroll` cost with `BlankMap`. This makes the two chains fungible. |
| Purchasable | — | `BlankMap`/`BlankScroll` vendor availability is not established by this section → `[UNVERIFIED]`; would need a grep over `Scripts/VendorInfo/*` for `typeof(BlankMap)`/`typeof(BlankScroll)`. |

#### 4d.5.2 Map quality / coverage levels — `CraftInit` formulas `[SRC]`

`MapItem.OnCraft` calls `CraftInit(from)` and returns quality 1 (`MapItem.cs:455-459`), so **Cartography maps are never exceptional and carry no quality tier**; "quality" here = how large an area the finished map displays, and it scales with the crafter's Cartography `Value` at craft time.

| Map | Bounds / display formula | Literal | L |
|---|---|---|---|
| `MapItem` base | `SetDisplay(x1,y1,x2,y2,w,h)` clamps `x1,y1 >= 0`, `x2 < 7164`, `y2 < 4096` | `MapItem.cs:98-116` | 98 |
| `LocalMap` | `dist = 64 + (int)(skillValue * 2)`; `SetDisplay(from.X-dist, from.Y-dist, from.X+dist, from.Y+dist, 200, 200)` | 64 + 2×skill | `LocalMap.cs:25-31` |
| `CityMap` | `dist = 64 + (int)(skillValue * 4)` (min 200); `size = 32 + (int)(skillValue * 2)` clamped `[200, 400]` | 64 + 4×skill; 32 + 2×skill | `CityMap.cs:25-41` |
| `SeaChart` | `dist = 64 + (int)(skillValue * 10)` (min 200); `size = 24 + (int)(skillValue * 3.3)` clamped `[200, 400]`; `Facet = from.Map`; non-Trammel/Felucca → `SetDisplayByFacet()` | 64 + 10×skill; 24 + 3.3×skill | `SeaChart.cs:14-35` |
| `WorldMap` | `x20 = (int)(skillValue * 20)`; `size = 25 + (int)(skillValue * 6.6)` clamped `[200, 400]`; T2A region → `Bounds = new Rectangle2D(5120, 2304, 1024, 1792)`; else `SetDisplay(1344-x20, 1600-x20, 1472+x20, 1728+x20, size, size)` | 20×skill; 25 + 6.6×skill | `WorldMap.cs:14-41` |
| `SetDisplayByFacet` | Tokuno `(0,0,1448,1430,400,400)`; Malas `(520,0,2580,2050,400,400)`; Ilshenar `(130,136,1927,1468,400,400)`; TerMur `(260,2780,1280,4090,400,400)` | — | `MapItem.cs:86-96` |
| `BlankMap` default display | none (never displays) | — | `BlankMap.cs:17-20` |
| Pins | `MaxUserPins = 50`; editable only if `ValidateEdit(from)` | 50 | `MapItem.cs:24, 142-151` |

#### 4d.5.3 Treasure maps — level vs. required Cartography skill and decode numbers `[SRC]`

`TreasureMap.GetMinSkillLevel()` — `Scripts/Services/TreasureMaps/TreasureMap.cs:1257-1278` (verbatim switch):

| Level | `Core.AOS` on | `Core.AOS` off | Notes |
|---|---|---|---|
| 1 | `27.0` | `-3.0` | level 1 is the only level that grants a skill check when under-skilled (`:945-948`) |
| 2 | `71.0` | `41.0` | |
| 3 | `81.0` | `51.0` | |
| 4 | `91.0` | `61.0` | |
| 5 | `100.0` | `70.0` | |
| 6 | `100.0` | `70.0` | |
| 7 | `100.0` | `100.0` | |
| default | `0.0` | `0.0` | level 0 = "young player" map |

`Level` setter clamps: `m_Level = Math.Min(value, TreasureMapInfo.NewSystem ? 4 : 7);` (`TreasureMap.cs:274`); `TreasureMapInfo.NewSystem => Core.EJ` (`TreasureMapInfo.cs:54`).

**Decode** — `TreasureMap.Decode(Mobile from)`, `TreasureMap.cs:924-971`:
```
if (m_Completed || m_Decoder != null) return;
if (m_Level == 0) { if (!CheckYoung(from)) { 1046447 "Only a young player may use this treasure map."; return; } }
else {
    double minSkill = GetMinSkillLevel();
    if (from.Skills[Cartography].Value < minSkill) {
        if (m_Level == 1) from.CheckSkill(Cartography, 0, minSkill);      // :947  gain attempt, then still tried
        else { 503013 "The map is too difficult to attempt to decode."; }  // :951  NOTE: no return -> falls through
    }
    if (!from.CheckSkill(Cartography, minSkill - 10, minSkill + 30)) {     // :955
        503018 "You fail to make anything of the map."; return;
    }
}
503019 "You successfully decode a treasure map!";  Decoder = from;         // :962-963
if (Core.AOS) LootType = LootType.Blessed;                                // :965-968
DisplayTo(from);
```
`[PARTIAL]` — at `:951` the "too difficult" branch sends the message but the source has **no `return`**, so the `CheckSkill(minSkill-10, minSkill+30)` roll at `:955` still runs. Behaviour beyond that (whether later in `DisplayTo` the map is hidden) is not asserted here.

**Digging** — `TreasureMap.DigTarget.OnTarget`, `TreasureMap.cs:1295-1370`:
```
if (m_Map.m_Completed)                                     -> 503028 already found
else if (m_Decoder != from && !m_Map.HasRequiredSkill(from)) -> 503031 "You did not decode this map and have no clue…"
else if (!from.CanBeginAction(typeof(TreasureMap)))        -> 503020 already digging
else if (!HasDiggingTool(from))                            -> "You must have a digging tool to dig for treasure."
else if (from.Map != map)                                  -> 1010479 wrong facet
else {
    double skillValue = TreasureMapInfo.NewSystem ? from.Skills[Cartography].Value
                                                  : from.Skills[Mining].Value;   // :1346
    if      (skillValue >= 100.0) maxRange = 4;
    else if (skillValue >=  81.0) maxRange = 3;
    else if (skillValue >=  51.0) maxRange = 2;
    else                          maxRange = 1;
    ... Utility.InRange(targ3D, chest3D0, maxRange) ...
}
```
`HasRequiredSkill` = `from.Skills[Cartography].Value >= GetMinSkillLevel()` (`TreasureMap.cs:1280-1283`).
`HasDiggingTool` requires a `BaseHarvestTool`-family tool whose `HarvestSystem == Mining.System` (`TreasureMap.cs:851-…`, match at `:862`). So with the **legacy system** (`!Core.EJ`) the *dig range* was a **Mining** check, while *decoding and access* were always Cartography.

| Quantity | Value | L |
|---|---|---|
| Dig target range | `base(6, true, TargetFlags.None)` — 6 tiles | `TreasureMap.cs:1290` |
| Range bonus thresholds | ≥100 → 4; ≥81 → 3; ≥51 → 2; else 1 | `:1348-1363` |
| Decode skill window | `CheckSkill(Cartography, minSkill - 10, minSkill + 30)` | `:955` |
| Level-1 under-skill gain | `CheckSkill(Cartography, 0, minSkill)` | `:947` |
| Reset cooldown | `NextReset = DateTime.UtcNow + ResetTime` | `:982` |
| Chest location source | `m_Map.ChestLocation`; digging on top of it → `503030` | `:1365, 1372-1375` |

### 4d.6 MASONRY (stonecrafting) — `DefMasonry.cs`, gump cliloc 1044500 `[ERA]`

**Which expansion** `[SRC+WEB]`: **Stygian Abyss (2009)**.
Evidence in-source:
1. `DefMasonry.CanCraft` gates on a player flag learned from a book bought **only from the gargoyle stone crafter**: `Scripts/VendorInfo/SBStoneCrafter.cs:48` sells `MasonryBook` ("Making Valuables With Stonecrafting", 10 625 gp) and `:50` sells `MalletAndChisel` (`0x12B3`, 3 gp). The label number is `1153527` (`Scripts/Items/Consumables/MasonryBook.cs:8`), in the `1153xxx` Stygian-Abyss cliloc block.
2. `DefMasonry` main skill is **Carpentry**, and the learning gate is `Carpentry.Base >= 100.0` → cliloc `1080043` "Only a Grandmaster Carpenter can learn from this book." (`MasonryBook.cs:35-38`).
3. The whole gargoyle stone armour / weapon / bed / cot / amulet block is `if (Core.SA)` (`DefMasonry.cs:134-141, 178-195, 198-219, 222-225`); the gargoyle stone crafter NPC is a Ter Mur (SA) vendor.
Web: "Stonecrafting is a supplementary skill for Grandmaster Carpenters, its does not cost any skill points, and has no effect on the skill cap. To learn how to craft stone a GM Carpenter must read the book 'Making Valuables With Stonecrafting' which can be bought from Gargoyle Stone Crafters in Royal City, Ter Mur at a cost of about 10,000 gold." — [UO.com — Stone Crafting](https://uo.com/wiki/ultima-online-wiki/skills/carpentry/stone-crafting/).
`[ERA]` caveat: the **four vase/chair/table/statue rows at `DefMasonry.cs:124-125, 153-166` carry no `Core.*` gate**, so the menu stub predates SA in the code even though the "learn stonecraft" gate + Ter Mur vendor do not. `[PARTIAL]` — this section does not establish whether a pre-SA shard could reach those rows; it would require checking the shard's `Expansion` config plus whether `MasonryBook` spawns anywhere outside `SBStoneCrafter`.

**Gate** — `DefMasonry.cs:59-73`: tool null/deleted/broken → `1044038`; equipped-tool mismatch → `1048146`; **`!(from is PlayerMobile && ((PlayerMobile)from).Masonry && from.Skills[SkillName.Carpentry].Base >= 100.0)`** → `1044633` "You havent learned stonecraft." (sic); else accessibility check. `PlayerFlag.Masonry = 0x00000002` (`Scripts/Mobiles/PlayerMobile.cs:61`), exposed as `public bool Masonry` (`:447`). Runic tool: `RunicMalletAndChisel` → `DefMasonry.CraftSystem` (`Scripts/Items/Tools/RunicMalletAndChisel.cs:9`); `MalletAndChisel` → `DefMasonry.CraftSystem` (`Scripts/Items/Tools/MalletAndChisel.cs:31`).
`MarkOption = true; Repair = Core.SA; CanEnhance = Core.SA;` (`DefMasonry.cs:327-329`). `RetainsColorFrom(item, type) => true` (`:54-57`).

**Sub-resource (granite colour)** — `SetSubRes(typeof(Granite), 1044525)` + `AddSubRes` (`DefMasonry.cs:331-341`). Every "Sub-res" cell below is `Granite`, optionally coloured. Each colour has a required Carpentry `Base`:

| Sub-resource type | cliloc | required skill | L |
|---|---|---|---|
| `Granite` | 1044525 | `0.0` | 333 |
| `DullCopperGranite` | 1044023 | 65.0 | 334 |
| `ShadowIronGranite` | 1044024 | 70.0 | 335 |
| `CopperGranite` | 1044025 | 75.0 | 336 |
| `BronzeGranite` | 1044026 | 80.0 | 337 |
| `GoldGranite` | 1044027 | 85.0 | 338 |
| `AgapiteGranite` | 1044028 | 90.0 | 339 |
| `VeriteGranite` | 1044029 | 95.0 | 340 |
| `ValoriteGranite` | 1044030 | 99.0 | 341 |

`Granite` base itemID `0x1779` (`Scripts/Items/Resource/Granite.cs:9`). Enforcement: `CraftItem.cs:966-972` (`from.Skills[MainSkill].Base < RequiredSkill` → `subResource.Message`). **Note `Base`, not `Value`** — item skill bonuses do not unlock coloured granite.

Row count: **59 `AddCraft` calls in 9 groups.**

#### Group 1044501 — Decorations (9 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044501 | vase (1022888) | `Vase` | 52.5 | 102.5 | `Granite`×1 | Granite colour | ungated | 124 |
| 1044501 | large vase (1022887) | `LargeVase` | 52.5 | 102.5 | `Granite`×3 | Granite colour | ungated | 125 |
| 1044501 | small urn (1029244) | `SmallUrn` | 82.0 | 132.0 | `Granite`×3 | Granite colour | gate `Core.SE` | 129 |
| 1044501 | small tower sculpture (1029242) | `SmallTowerSculpture` | 82.0 | 132.0 | `Granite`×3 | Granite colour | gate `Core.SE` | 131 |
| 1044501 | gargoyle painting (1095317) | `GargoylePainting` | 83.0 | 133.0 | `Granite`×3 | Granite colour | gate `Core.SA` | 136 |
| 1044501 | gargish sculpture (1095319) | `GargishSculpture` | 82.0 | 132.0 | `Granite`×3 | Granite colour | gate `Core.SA` | 138 |
| 1044501 | gargoyle vase (1095322) | `GargoyleVase` | 80.0 | 126.0 | `Granite`×3 | Granite colour | gate `Core.SA` | 140 |
| 1044501 | 18th anniversary tall vase (1156147) | `AnniversaryVaseTall` | 60.0 | 110.0 | `Granite`×6 | Granite colour | gate `Core.TOL`; `AddRecipe(702)` (`MasonryRecipes.AnniversaryVaseTall`) | 145 |
| 1044501 | 18th anniversary short vase (1156148) | `AnniversaryVaseShort` | 60.0 | 110.0 | `Granite`×6 | Granite colour | gate `Core.TOL`; `AddRecipe(701)` (`MasonryRecipes.AnniversaryVaseShort`) | 148 |

#### Group 1044502 — Furniture (6 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044502 | stone chair (1024635) | `StoneChair` | 55.0 | 105.0 | `Granite`×4 | Granite colour | ungated | 153 |
| 1044502 | medium stone table (east) (1044508) | `MediumStoneTableEastDeed` | 65.0 | 115.0 | `Granite`×6 | Granite colour | ungated | 154 |
| 1044502 | medium stone table (south) (1044509) | `MediumStoneTableSouthDeed` | 65.0 | 115.0 | `Granite`×6 | Granite colour | ungated | 155 |
| 1044502 | large stone table (east) (1044511) | `LargeStoneTableEastDeed` | 75.0 | 125.0 | `Granite`×9 | Granite colour | ungated | 156 |
| 1044502 | large stone table (south) (1044512) | `LargeStoneTableSouthDeed` | 75.0 | 125.0 | `Granite`×9 | Granite colour | ungated | 157 |
| 1044502 | ritual table (1097690) | `RitualTableDeed` | 94.7 | **103.5** *(max < value implied by other rows; literal)* | `Granite`×8 | Granite colour | ungated (menus only show it when the gargoyle SA art exists) | 158 |

#### Group 1044503 — Statues (6 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044503 | statue (south) (1044505) | `StatueSouth` | 60.0 | 110.0 | `Granite`×3 | Granite colour | ungated | 161 |
| 1044503 | statue (north) (1044506) | `StatueNorth` | 60.0 | 110.0 | `Granite`×3 | Granite colour | ungated | 162 |
| 1044503 | statue (east) (1044507) | `StatueEast` | 60.0 | 110.0 | `Granite`×3 | Granite colour | ungated | 163 |
| 1044503 | pegasus statue (1044510) | `StatuePegasusSouth` | 70.0 | 120.0 | `Granite`×4 | Granite colour | ungated | 164 |
| 1044503 | gargoyle statue (1097637) | `StatueGargoyleEast` | 54.5 | 104.5 | `Granite`×20 | Granite colour | ungated | 165 |
| 1044503 | gryphon statue (1097619) | `StatueGryphonEast` | 54.5 | 104.5 | `Granite`×15 | Granite colour | ungated | 166 |

#### Group 1044290 — Misc Addons / bedding (6 rows)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1044290 | stone anvil (south) (1072876) | `StoneAnvilSouthDeed` | 78.0 | 128.0 | `Granite`×20 | Granite colour | gate `Core.ML`; `AddRecipe(CarpRecipes.StoneAnvilSouth)` | 171 |
| 1044290 | stone anvil (east) (1073392) | `StoneAnvilEastDeed` | 78.0 | 128.0 | `Granite`×20 | Granite colour | gate `Core.ML`; `AddRecipe(CarpRecipes.StoneAnvilEast)` | 174 |
| 1044290 | large gargoyle bed (south) (1111761) | `LargeGargoyleBedSouthDeed` | 76.0 | 126.0 | `Granite`×3 + `Cloth`×100 | Granite colour | gate `Core.SA`; **`AddSkill(Tailoring, 70.0, 75.0)`** | 180 |
| 1044290 | large gargoyle bed (east) (1111762) | `LargeGargoyleBedEastDeed` | 76.0 | 126.0 | `Granite`×3 + `Cloth`×100 | Granite colour | gate `Core.SA`; Tailoring 70–75 | 184 |
| 1044290 | gargish cot (east) (1111921) | `GargishCotEastDeed` | 76.0 | 126.0 | `Granite`×3 + `Cloth`×100 | Granite colour | gate `Core.SA`; Tailoring 70–75 | 188 |
| 1044290 | gargish cot (south) (1111920) | `GargishCotSouthDeed` | 76.0 | 126.0 | `Granite`×3 + `Cloth`×100 | Granite colour | gate `Core.SA`; Tailoring 70–75 | 192 |

#### Group 1111705 — Stone Armor (10 rows, all gate `Core.SA`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111705 | female gargish stone arms (1020643) | `FemaleGargishStoneArms` | 56.3 | 106.3 | `Granite`×8 | Granite colour | SA | 200 |
| 1111705 | female gargish stone chest (1020645) | `FemaleGargishStoneChest` | 55.0 | 105.0 | `Granite`×12 | Granite colour | SA | 202 |
| 1111705 | female gargish stone legs (1020649) | `FemaleGargishStoneLegs` | 58.8 | 108.8 | `Granite`×10 | Granite colour | SA | 204 |
| 1111705 | female gargish stone kilt (1020647) | `FemaleGargishStoneKilt` | 48.9 | 98.9 | `Granite`×6 | Granite colour | SA | 206 |
| 1111705 | gargish stone arms (1020643) | `GargishStoneArms` | 56.3 | 106.3 | `Granite`×8 | Granite colour | SA | 208 |
| 1111705 | gargish stone chest (1020645) | `GargishStoneChest` | 65.0 | 115.0 | `Granite`×12 | Granite colour | SA | 210 |
| 1111705 | gargish stone legs (1020649) | `GargishStoneLegs` | 58.8 | 108.8 | `Granite`×10 | Granite colour | SA | 212 |
| 1111705 | gargish stone kilt (1020647) | `GargishStoneKilt` | 48.9 | 98.9 | `Granite`×6 | Granite colour | SA | 214 |
| 1111705 | large stone shield (1095773) | `LargeStoneShield` | 55.0 | 105.0 | `Granite`×16 | Granite colour | SA | 216 |
| 1111705 | gargish stone amulet (1098594) | `GargishStoneAmulet` | 60.0 | 110.0 | `Granite`×3 | Granite colour | SA; reforging table maps it to `DefMasonry.CraftSystem` (`Services/LootGeneration/RunicReforging/RunicReforging.cs:1139`) | 218 |

#### Group 1111719 — Stone Weapons (1 row, gate `Core.SA`)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1111719 | stone war sword (1022304) | `StoneWarSword` | 55.0 | 105.0 | `Granite`×18 | Granite colour | SA | 224 |

#### Group 1155792 — Stone Walls & Doors (12 rows, all gate `Core.TOL`, min 60.0 / max 110.0, `Granite`×10)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1155792 | rough windowless wall (1155794) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(CraftableItemType.RoughWindowless)`; `SetDisplayID(464)` | 230 |
| 1155792 | rough window (1155797) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(RoughWindow)`; `SetDisplayID(467)` | 234 |
| 1155792 | rough arch (1155799) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(RoughArch)`; `SetDisplayID(469)` | 238 |
| 1155792 | rough pillar (1155804) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(RoughPillar)`; `SetDisplayID(474)` | 242 |
| 1155792 | rough rounded arch (1155805) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(RoughRoundedArch)`; `SetDisplayID(475)` | 246 |
| 1155792 | rough small arch (1155810) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(RoughSmallArch)`; `SetDisplayID(480)` | 250 |
| 1155792 | rough angled pillar (1155814) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(RoughAngledPillar)`; `SetDisplayID(486)` | 254 |
| 1155792 | short rough (1155816) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(ShortRough)`; `SetDisplayID(488)` | 258 |
| 1155792 | stone door S-in (1156078) | `CraftableStoneHouseDoor` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(DoorType.StoneDoor_S_In)`; `SetDisplayID(804)`; `AddCreateItem(CraftableStoneHouseDoor.Create)` | 262 |
| 1155792 | stone door E-out (1156079) | `CraftableStoneHouseDoor` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(StoneDoor_E_Out)`; `SetDisplayID(805)`; `AddCreateItem(...)` | 267 |
| 1155792 | stone door S-out (1156348) | `CraftableStoneHouseDoor` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(StoneDoor_S_Out)`; `SetDisplayID(804)`; `AddCreateItem(...)` | 272 |
| 1155792 | stone door E-in (1156349) | `CraftableStoneHouseDoor` | 60.0 | 110.0 | `Granite`×10 | Granite colour | `SetData(StoneDoor_E_In)`; `SetDisplayID(805)`; `AddCreateItem(...)` | 277 |

#### Group 1155820 — Stone Stairs (6 rows, gate `Core.TOL`, 60.0 / 110.0, `Granite`×5)

| Cat | Item (cliloc) `[PARTIAL]` | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1155820 | rough block (1155821) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(RoughBlock)`; `SetDisplayID(1928)` | 286 |
| 1155820 | rough steps (1155822) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(RoughSteps)`; `SetDisplayID(1929)` | 290 |
| 1155820 | rough corner steps (1155826) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(RoughCornerSteps)`; `SetDisplayID(1934)` | 294 |
| 1155820 | rough rounded corner steps (1155830) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(RoughRoundedCornerSteps)`; `SetDisplayID(1938)` | 298 |
| 1155820 | rough inset steps (1155834) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(RoughInsetSteps)`; `SetDisplayID(1941)` | 302 |
| 1155820 | rough rounded inset steps (1155838) | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(RoughRoundedInsetSteps)`; `SetDisplayID(1945)` | 306 |

#### Group 1155877 — Stone Floors / pavers (3 rows, gate `Core.TOL`, 60.0 / 110.0, `Granite`×5)

These three rows use **`string` names**, not clilocs: `"Light Paver"`, `"Medium Paver"`, `"Dark Paver"` — `[SRC]` `DefMasonry.cs:314,318,322`.

| Cat | Item display | C# type | Min | Max | Resources | Sub-res | Flags | L |
|---|---|---|---|---|---|---|---|---|
| 1155877 | `"Light Paver"` | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(LightPaver)`; `SetDisplayID(1305)` | 314 |
| 1155877 | `"Medium Paver"` | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(MediumPaver)`; `SetDisplayID(1309)` | 318 |
| 1155877 | `"Dark Paver"` | `CraftableHouseItem` | 60.0 | 110.0 | `Granite`×5 | Granite colour | `SetData(DarkPaver)`; `SetDisplayID(1313)` | 322 |

### 4d.7 Row-count reconciliation

| Menu | `AddCraft` calls (grep-verified) | Groups | Ungated rows | Gated rows |
|---|---|---|---|---|
| Alchemy (`DefAlchemy.cs`) | **51** | 6 | **20** (8 healing + 5 enhancement + 4 toxic + 3 explosive) | **31** = 13 `Core.SA` (147,274,288,311,316,327,332,336,339,342,347,351,373) + 6 `Core.TOL` (154,187,193,199,206,212) + 9 `Core.ML` (179,235,239,243,259,262,265,268,303) + 1 `Core.SE` (297) + 1 `Core.HS` (358) + 1 `Core.SA && !Core.EJ` (282) |
| Inscription (`DefInscription.cs`) | **113** (64 magery + 17 necro + 16 mystic + 16 items) | 7 | **65** (64 magery scrolls + `Runebook` @378) | **48** = 17 `Core.SE` necro + 16 `Core.SA` mystic + 15 non-scroll items (1 `Core.AOS` @395, 1 `Core.SE` @400, 5 `Core.ML` @364,370,406,413,417,419, 1 `Core.TOL` @385, 6 `Core.SA` @426,431,436,438,441,444) |
| Cooking (`DefCooking.cs`) | **88** | 8 | **38** (6 ingredients + 9 preparations (incl. `TribalPaint`) + 14 baking (incl. `GingerBreadCookie`, `ThreeTieredCake`) + 6 barbecue + 3 beverages) | **50** = 10 `Core.ML` (143,147,213,396,399,403,407,425,430,437) + 4 `ML&&TOL` (419,447,453,459) + 9 `Core.SE` (187,191,194,197,206,288,292,296,300) + 22 `Core.SA` (222,226,230,234,348,354 + 16 fish pies) + 1 `Core.HS` (242) + 1 `Core.EJ` (365) + 3 `Core.TOL` (372,379,385) |
| Cartography (`DefCartography.cs`) | **8** | 1 | **8** | **0** |
| Masonry (`DefMasonry.cs`) | **59** | 9 | **14** (`:124,125,153,154,155,156,157,158,161,162,163,164,165,166` — vase ×2, chair, 4 tables, 6 statues) | **45** = 2 `Core.SE` (129,131) + 3 `Core.SA` decorations (136,138,140) + 2 `Core.ML` anvils (171,174) + 4 `Core.SA` beds/cots (180,184,188,192) + 10 `Core.SA` armor (200-218) + 1 `Core.SA` weapon (224) + 2 `Core.TOL` vases (145,148) + 12 `Core.TOL` walls/doors (230-277) + 6 `Core.TOL` stairs (286-306) + 3 `Core.TOL` floors (314,318,322) |
| **Total** | **319** | **31** | — | — |

Group cliloc inventory (every group used by these five menus):

| Menu | Group clilocs in order of first appearance |
|---|---|
| Alchemy | 1116348, 1116349, 1116350, 1116351, 1116353, 1044495 |
| Inscription | 1111691, 1111692, 1111693, 1111694, 1061677, 1044294, 1111671 |
| Cooking | 1044495, 1044496, 1044497, 1044498, 1073108, 1080001, 1116340, 1155736 |
| Cartography | 1044448 |
| Masonry | 1044501, 1044502, 1044503, 1044290, 1111705, 1111719, 1155792, 1155820, 1155877 |

### 4d.8 Confidence and gaps

- `[SRC]` for **every** number, resource amount, skill window, cliloc id, item id and formula in this section; each is quoted from a file:line listed in its own row.
- `[PARTIAL]` — the **English display text** of every menu entry and reagent is not verifiable offline because no `cliloc` table exists in the checkout (`glob **/*cliloc*` → no files). Rows give the cliloc number and a class-name-derived label. Resolving it requires `cliloc.enu` from a UO client install or a `LocalizedMessage` dump.
- `[PARTIAL]` — Cooking (`DefCooking.cs:549-551`) beverage row (Yellowtail Barracuda Pie): the resource carries cliloc 1022503 (the same one paired with `BeverageType.Wine` at `:230-232`) but no `SetBeverageType` call, so the effective filter is the default `Water`. Confirm against cliloc text or in-game.
- `[PARTIAL]` — Masonry era for the **ungated** vase/chair/table/statue rows (§4d.6).
- `[UNVERIFIED]` — vendor availability and prices of `BlankMap` / `BlankScroll` / `Bottle` / the eight classic reagents / `Granite`: not measured here. Resolve by grepping `Scripts/VendorInfo/*.cs` for each type.
- `[UNVERIFIED]` — `MaskOfDeath`, `MaskOfDeathGreater`, `FearEssence` `PotionEffect` values have **no implementing class** in the checkout (source comments at `BasePotion.cs:31-32`); `ShatterPotion` and `ExplodingTarPotion` exist as classes but appear in **no** craft menu. Confirm by grepping `AddCraft` for those types across all `Def*.cs`.
- `[UNVERIFIED]` — the practical effect of the missing `return` at `TreasureMap.cs:951` (whether a too-hard map can still be decoded by a low-skill character). Resolve by an in-game test: attempt decode of a level 3 map at Cartography 10 and observe the outcome distribution over N = 100 attempts.
- `[UNVERIFIED]` — `DefInscription.cs:459` passing `Reg.DaemonBone` twice (⇒ 2 DaemonBone per Spell Plague scroll) is asserted from the literal argument list; whether OSI intends this is not established.

## 5. Hide / Stealth / Thief package

Primary source: `ServUO` @ `pub57` = `E:\Workspaces\game-clone\.research-src\servuo` (cited `ServUO:<path>:<line>`, URL form
`https://github.com/ServUO/ServUO/blob/pub57/<path>#L<line>`). Secondary: `ModernUO` = `.research-src\modernuo`
(cited `ModernUO:Projects/<path>:<line>`, URL form `https://github.com/modernuo/ModernUO/blob/main/Projects/<path>#L<line>`).
`[WEB]` prose is UOGuide. Every number below is a literal read out of source or an explicit derivation that shows its arithmetic.

### 5.0 Files read end-to-end + the one shared primitive

| File | Lines | Role |
|---|---|---|
| `ServUO:Scripts/Skills/Hiding.cs` | 129 | Hiding skill callback |
| `ServUO:Scripts/Skills/Stealth.cs` | 131 | Stealth skill callback + armor table |
| `ServUO:Scripts/Skills/Snooping.cs` | 100 | `Container.SnoopHandler` |
| `ServUO:Scripts/Skills/Stealing.cs` | 646 | Stealing callback, target, `StolenItem` |
| `ServUO:Scripts/Skills/DetectHidden.cs` | 211 | active + passive detect, `CanDetect` |
| `ServUO:Scripts/Skills/Tracking.cs` | 394 | tracking gumps, stalking bonus |
| `ServUO:Scripts/Skills/RemoveTrap.cs` | 411 | trap disarm + chest timer |
| `ServUO:Scripts/Skills/ForensicEval.cs` | 173 | corpse/mobile/lock forensics |
| `ServUO:Server/Mobile.cs` | 12821 | Hidden / Warmode / Criminal / step engine / RevealingAction |
| `ServUO:Scripts/Mobiles/PlayerMobile.cs` | 6990 | step engine for players, PermaFlags, buff icon |
| `ServUO:Scripts/Misc/SkillCheck.cs` | 808 | success roll + skill gain |
| `ServUO:Scripts/Misc/Notoriety.cs` | 569 | notoriety + hues |
| `ServUO:Scripts/Regions/GuardedRegion.cs` | 470 | criminal → guard response |

**Skill-check primitive** `[SRC]` `ServUO:Scripts/Misc/SkillCheck.cs:286-311` (`Mobile_SkillCheckTarget`):

```
value = skill.Value                       // CURRENT value incl. modifiers, not Base
if (value <  minSkill) return false       // Too difficult
if (value >= maxSkill) return true        // No challenge
chance = (value - minSkill) / (maxSkill - minSkill)
```

`[SRC]` `ServUO:Scripts/Misc/SkillCheck.cs:240-259` (`CheckSkill`): `success = Utility.Random(100) <= (int)(chance * 100);`
`[SRC]` `ServUO:Server/Utility.cs:921-924` `Random(count) => RandomImpl.Next(count)` ⇒ range `[0, count-1]`.
⇒ **ServUO effective success probability = `((int)(chance*100) + 1) / 100`** (floor-quantised, +1 % bias). Derived, `[SRC]`.
`[SRC]` `ServUO:Server/Utility.cs:889-903` `RandomMinMax(min,max) => min + Next((max-min)+1)` ⇒ inclusive both ends.
`[SRC]` `ServUO:Server/Utility.cs:931-934` `RandomDouble() => NextDouble()` ⇒ `[0,1)`.
`ModernUO` differs: `success = chance >= Utility.RandomDouble()` ⇒ probability exactly `chance` (`ModernUO:Projects/UOContent/Skills/SkillCheck.cs:115`) and it adds `|| minSkill >= maxSkill` to the "no challenge" test (`:65`). **A clone must pick one; they are not equal.**

**Skill-use plumbing** `[SRC]` `ServUO:Server/Skills.cs:886-932`: `UseSkill` calls `from.DisruptiveAction()` (`:914`) then
`from.NextSkillTime = Core.TickCount + (int)(info.Callback(from)).TotalMilliseconds` (`:916`). The `TimeSpan` each `OnUse`
returns **is** the reuse delay. If `info.Callback == null` the client is told `500014` "That skill cannot be used directly."
⇒ **Snooping has no `Callback` at all** (see 5.3).

**Expansion gates** `[SRC]` `ServUO:Server/Main.cs:140-154`: `AOS/SE/ML/SA/HS/TOL/EJ` are `Expansion >= Expansion.X`.
`[ERA]` Mapping used below (classic 1997 → AoS 2003 → SE 2005 → ML 2007 → SA 2009 → HS 2015 → EJ 2020s) per `_BRIEF.md`.

**Skill info rows** `[SRC]` `ServUO:Server/Skills.cs:594-653` (id, name, stat gain weights, GainFactor, primary/secondary):

| Skill | ID | Row | StrGain/DexGain/IntGain | GainFactor | Primary / Secondary |
|---|---|---|---|---|---|
| Detect Hidden | 14 | `ServUO:Server/Skills.cs:610` | 0.0 / 0.4 / 0.6 | 1.0 | Int / Dex |
| Forensic Evaluation | 19 | `ServUO:Server/Skills.cs:615` | 0.0 / 0.2 / 0.8 | 1.0 | Int / Dex |
| Hiding | 21 | `ServUO:Server/Skills.cs:617` | 0.0 / 0.8 / 0.2 | 1.0 | Dex / Int |
| Snooping | 28 | `ServUO:Server/Skills.cs:624` | 0.0 / 2.5 / 0.0 | 1.0 | Dex / Int |
| Stealing | 33 | `ServUO:Server/Skills.cs:629` | 0.0 / 1.0 / 0.0 | 1.0 | Dex / Int |
| Tracking | 38 | `ServUO:Server/Skills.cs:634` | 0.0 / 1.25 / 1.25 | 1.0 | Int / Dex |
| Stealth | 47 | `ServUO:Server/Skills.cs:643` | 0.0 / 0.0 / 0.0 | 1.0 | Dex / Int |
| Remove Trap | 48 | `ServUO:Server/Skills.cs:644` | 0.0 / 0.0 / 0.0 | 1.0 | Dex / Int |

`[SRC]` `ServUO:Scripts/Misc/SkillCheck.cs:59-123` — anti-macro flag `true` for DetectHidden(14), Forensics(19), Hiding(21),
Snooping(28), Stealing(33), Tracking(38), Stealth(47), RemoveTrap(48); `Allowance = 3` uses per location, `AntiMacroExpire = 5 min`,
`LocationSize = 4` (`:28,33,38`).

---

### 5.1 HIDING — `ServUO:Scripts/Skills/Hiding.cs`

Callback registered at `:23` (`SkillInfo.Table[21]`). `CombatOverride` static at `:9-20` bypasses every "watched" test.

**Preconditions / early exits** `[SRC]`

| Order | Condition | Line | Effect | Returned delay |
|---|---|---|---|---|
| 1 | `m.Spell != null` | `Hiding.cs:28-32` | `501238` "You are busy doing something else and cannot hide." | `1.0 s` |
| 2 | `VvV.ManaSpike.UnderEffects(m)` | `Hiding.cs:34-37` | *no message* | `1.0 s` |
| 3 | `Core.ML && m.Target != null` | `Hiding.cs:39-42` | `Targeting.Target.Cancel(m)` | (continues) |

**House bonus (the free-hide cases)** `[SRC]` `Hiding.cs:44-68`

| Case | Line | `bonus` | Resulting window | Outcome |
|---|---|---|---|---|
| Standing in a house where `IsFriend(m)` | `:46-51` | `100.0` | `CheckSkill(Hiding, -100.0, 0.0)` | `value >= 0` ⇒ `maxSkill` branch returns **true unconditionally** = FACE-HIDE |
| `!Core.AOS` and a house is found at `(x±1, y, 127)` or `(x, y±1, 127)` within 16 of the mobile's `Map` | `:52-68` | `50.0` | `CheckSkill(Hiding, -50.0, 50.0)` | `Hiding.Value >= 50.0` ⇒ auto-success; else `chance = (value+50)/100` |
| otherwise | — | `0.0` | `CheckSkill(Hiding, 0.0, 100.0)` | `chance = value/100` |

`[WEB]` "Hiding is always successful within a player's own house." — [UOGuide — Hiding](https://www.uoguide.com/Hiding) ⇒ `[SRC+WEB]`.
`[ERA]` The 4-tile house scan exists only pre-AoS (`!Core.AOS`); the friend bonus survived into live UO. `[SRC]`

**"Being watched" penalty** — it is a hard block, not a skill penalty `[SRC]` `Hiding.cs:70-97`

```
skill = Math.Min(100, (int)m.Skills[Hiding].Value)                        // Hiding.cs:71
range = Math.Min((int)((100 - skill) / 2) + 8, 18)                        // Hiding.cs:72  ("Cap of 18 not OSI-exact, intentional difference")
badCombat = !CombatOverride && m.Combatant is Mobile
            && m.InRange(m.Combatant.Location, range)
            && ((Mobile)m.Combatant).InLOS(m.Combatant)                   // Hiding.cs:74  <-- argument is the COMBATANT, not the hider
```

Then, if not already bad, a second sweep at `:81-93`: **any** mobile within `range` with `check.InLOS(m) && check.Combatant == m` sets
`badCombat = true` and aborts the check. Only if neither fired does `CheckSkill` run (`:96`).

| Hiding skill | `range` (tiles) | line |
|---|---|---|
| 0 – 80 | 18 | `Hiding.cs:72` |
| 81 – 82 | 17 | derived |
| 84 | 16 | derived |
| 90 | 13 | derived |
| 96 | 10 | derived |
| 100 | 8 | derived |

`[WEB]` "At GM Hiding, a character may hide in plain sight of a hostile monster or other player only 8 tiles away." —
[UOGuide — Hiding](https://www.uoguide.com/Hiding) ⇒ `[SRC+WEB]` for the 8-tile GM value.

**Message / hue table** `[SRC]`

| Clue | Text | Hue | Line |
|---|---|---|---|
| `501237` | You can't seem to hide right now. | `0x22` `MessageType.Regular` | `Hiding.cs:103` |
| `501238` | You are busy doing something else and cannot hide. | (SendLocalizedMessage) | `Hiding.cs:30` |
| `501240` | You have hidden yourself well. | `0x1F4` | `Hiding.cs:116` |
| `501241` | You can't seem to hide here. | `0x22` | `Hiding.cs:122` |

**Delays / outcomes** `[SRC]`

| Branch | Lines | Effects | Delay |
|---|---|---|---|
| `badCombat` | `:99-107` | `m.RevealingAction()` + `501237` | **`TimeSpan.Zero`** (no cooldown at all) |
| success | `:110-117` | `m.Hidden = true`; `m.Warmode = false`; `Sixth.InvisibilitySpell.RemoveTimer(m)`; `Items.InvisibilityPotion.RemoveTimer(m)`; `501240` | `10.0 s` |
| failure | `:118-125` | `m.RevealingAction()` + `501241` | `10.0 s` |

**Side effects of `Hidden = true`** `[SRC]`

| Effect | Line |
|---|---|
| `Mobile.Hidden` setter: if `m_Hidden` becomes true → `Warmode = false` if in warmode, else `Combatant = null` | `ServUO:Server/Mobile.cs:8963-8973` |
| `OnHiddenChanged()` → `m_AllowedStealthSteps = 0` + resend `RemovePacket`/`MobileIncoming`/OPL to every client in range | `ServUO:Server/Mobile.cs:8980-9012` |
| `PlayerMobile.OnHiddenChanged()` → removes `BuffIcon.Invisibility`; if hidden adds `BuffInfo(BuffIcon.HidingAndOrStealth, 1075655)` else removes it | `ServUO:Scripts/Mobiles/PlayerMobile.cs:1735-1749` |
| `BuffIcon.HidingAndOrStealth` enum member | `ServUO:Scripts/Misc/BuffIcons.cs:257` |
| `RevealingAction()` → `if (m_Hidden && IsPlayer()) Hidden = false; m_IsStealthing = false; DisruptiveAction();` | `ServUO:Server/Mobile.cs:7153-7163` |

### 5.2 STEALTH — `ServUO:Scripts/Skills/Stealth.cs`

**Preconditions, exact order** `[SRC]` `Stealth.cs:70-126`

| # | Test | Line | Message | Extra | Return |
|---|---|---|---|---|---|
| 1 | `!m.Hidden` | `:72-75` | `502725` "You must hide first" | *no reveal* | 10.0 s |
| 2 | `m.Flying` | `:76-81` | `1113415` "You cannot use this ability while flying." | `RevealingAction()` + remove HidingAndOrStealth buff | 10.0 s |
| 3 | `m.Skills[Hiding].Base < HidingRequirement` | `:82-87` | `502726` "You are not hidden well enough.  Become better at hiding." | reveal + buff removal | 10.0 s |
| 4 | `!m.CanBeginAction(typeof(Stealth))` | `:88-93` | `1063086` "You cannot use this skill right now." | reveal + buff removal | 10.0 s |
| 5 | `armorRating >= (Core.AOS ? 42 : 26)` | `:98-103` | `502727` "You could not hope to move quietly wearing this much armor." | reveal + buff removal | 10.0 s |
| 6 | `CheckSkill` fails | `:120-125` | `502731` "You fail in your attempt to move unnoticed." | reveal + buff removal | 10.0 s |
| 7 | `CheckSkill` succeeds | `:104-119` | `502730` "You begin to move quietly." | steps, `IsStealthing = true`, `BuffInfo(HidingAndOrStealth, 1044107, 1075655)` | 10.0 s |

**Hiding requirement** `[SRC]` `Stealth.cs:24-30`: `Core.ML ? 30.0 : (Core.SE ? 50.0 : 80.0)`.
`[ERA]` 80 → 50 (SE) → 30 (ML). `[WEB]` "A character must have at least 30.0 in Hiding to be able to use Stealth." —
[UOGuide — Stealth](https://www.uoguide.com/Stealth) ⇒ `[SRC+WEB]` for the ML-era value. The `50`/`80` values are `[SRC]` only.

**Exact success formula** `[SRC]` `Stealth.cs:104`

```
CheckSkill(Stealth, -20.0 + (armorRating * 2), (Core.AOS ? 60.0 : 80.0) + (armorRating * 2))
⇒ chance = (Stealth.Value - (2*AR - 20)) / ((AoS?60:80) + 2*AR - (2*AR - 20))
         = (Stealth.Value - 2*AR + 20) / (AoS ? 80 : 100)
```

So the denominator is a **constant** (80 AoS / 100 non-AoS); every point of armor rating shifts the *minimum* by +2, i.e. costs
2 skill points of headroom. Derived `[SRC]`.

| `armorRating` | AoS window | non-AoS window | `chance` at Stealth 25 (AoS) |
|---|---|---|---|
| 0 | `-20.0 .. 60.0` | `-20.0 .. 80.0` | `(25+20)/80 = 0.5625` |
| 5 | `-10.0 .. 70.0` | `-10.0 .. 90.0` | `(25+10)/80 = 0.4375` |
| 10 | `0.0 .. 80.0` | `0.0 .. 100.0` | `(25-0)/80 = 0.3125` |
| 20 | `20.0 .. 100.0` | `20.0 .. 120.0` | `(25-20)/80 = 0.0625` |
| 21 (AoS) | `22.0 .. 102.0` | `22.0 .. 122.0` | `25 < 22`? no → `0.0375` |
| ≥ 42 AoS / ≥ 26 non-AoS | — | — | blocked by precondition 5 |

**Armor restriction table (verbatim)** `[SRC]` `Stealth.cs:9-23` — `m_ArmorTable[materialType, bodyPosition]`

```
//      Gorget  Gloves  Helmet  Arms  Legs  Chest  Shield
/* Cloth   */ { 0, 0,  0,  0,  0,  0,  0 },
/* Leather */ { 0, 0,  0,  0,  0,  0,  0 },
/* Studded */ { 2, 2,  0,  4,  6, 10,  0 },
/* Bone    */ { 0, 5, 10, 10, 15, 25,  0 },
/* Spined  */ { 0, 0,  0,  0,  0,  0,  0 },
/* Horned  */ { 0, 0,  0,  0,  0,  0,  0 },
/* Barbed  */ { 0, 0,  0,  0,  0,  0,  0 },
/* Ring    */ { 0, 5,  0, 10, 15, 25,  0 },
/* Chain   */ { 0, 0, 10,  0, 15, 25,  0 },
/* Plate   */ { 5, 5, 10, 10, 15, 25,  0 },
/* Dragon  */ { 0, 5, 10, 10, 15, 25,  0 }
```

Index meaning `[SRC]`: `ArmorMaterialType` order = `Cloth, Leather, Studded, Bone, Spined, Horned, Barbed, Ringmail, Chainmail,
Plate, Dragon, Wood, Stone` (`ServUO:Scripts/Items/Equipment/Armor/ArmorEnums.cs:36-51`);
`ArmorBodyType` order = `Gorget, Gloves, Helmet, Arms, Legs, Chest, Shield` (`ArmorEnums.cs:25-34`).
`[SRC]` `BaseArmor.BodyPosition` maps layers → column: `Layer.Neck→Gorget`, `Layer.TwoHanded→Shield`, `Layer.Gloves→Gloves`,
`Layer.Helm→Helmet`, `Layer.Arms→Arms`, `Layer.InnerLegs/OuterLegs/Pants→Legs`, `Layer.InnerTorso/OuterTorso/Shirt→Chest`
(`ServUO:Scripts/Items/Equipment/Armor/BaseArmor.cs:1297-1326`).
⇒ **Shields (column 7) are 0 for every material — a shield never blocks stealth.** Derived `[SRC]`.
⇒ **Wood and Stone (rows 12/13) do not exist in the ServUO table**; `GetArmorRating` skips them via the length guard (see below). `[SRC]`

**Exact predicate** `[SRC]` `Stealth.cs:43-68`

| Step | Line | Code |
|---|---|---|
| non-AoS shortcut | `:45-46` | `if (!Core.AOS) return (int)m.ArmorRating;` |
| iterate worn items | `:50-52` | `BaseArmor armor = m.Items[i] as BaseArmor; if (armor == null) continue;` |
| bounds guard | `:60-61` | `if (materialType >= m_ArmorTable.GetLength(0) \|\| bodyPosition >= m_ArmorTable.GetLength(1)) continue;` |
| **the MageArmor exclusion** | `:63-64` | `if (armor.ArmorAttributes.MageArmor == 0) ar += m_ArmorTable[materialType, bodyPosition];` |

`[SRC]` `PlayerMobile.ArmorRating` (used by the non-AoS branch) sums `ArmsArmor/NeckArmor/HandArmor/HeadArmor/ArmsArmor/
LegsArmor/ChestArmor/ShieldArmor` with the **same** `!Core.AOS || ar.ArmorAttributes.MageArmor == 0` predicate and returns
`VirtualArmor + VirtualArmorMod + rating` (`ServUO:Scripts/Mobiles/PlayerMobile.cs:1919-1946`).
`Mobile.ArmorRating` base is `0.0` (`ServUO:Server/Mobile.cs:3729`).
`ArmorAttributes` property: `ServUO:Scripts/Items/Equipment/Armor/BaseArmor.cs:1078`; `MageArmor` is set automatically for
mage-armor-capable types only under `Core.SA` (`:3211-3213`, `IsMageArmorType` `:3289-3304`).
`MageArmor` property display hook `:3021`.

> **Naming correction:** the brief asked for `Medable` on `BaseArmor.cs` / `BaseClothing.cs`. **There is no `Medable` member
> anywhere in `ServUO` (grep over `Scripts/Items/Equipment` = 0 hits) nor in `ModernUO`.** The stealth-relevant predicate in both
> codebases is `BaseArmor.ArmorAttributes.MageArmor == 0`. `BaseClothing` never enters the stealth calculation at all because
> `Stealth.GetArmorRating` only casts to `BaseArmor` (`Stealth.cs:52`) — clothing weight/layer/medable-ness is irrelevant here. `[SRC]`

**Derived full-suit ratings** (sum of the 6 non-shield columns, derived from the table above) `[SRC]`-derived:

| Suit | AoS sum | vs AoS cap 42 | non-AoS sum | vs non-AoS cap 26 |
|---|---|---|---|---|
| Cloth / Leather / Spined / Horned / Barbed | 0 | OK | 0 | OK |
| Studded | 24 | OK | 24 | OK |
| Chainmail | 50 | BLOCKED | 50 | BLOCKED |
| Ringmail | 55 | BLOCKED | 55 | BLOCKED |
| Bone | 65 | BLOCKED | 65 | BLOCKED |
| Dragon (ServUO) | 65 | BLOCKED | 65 | BLOCKED |
| Plate | 70 | BLOCKED | 70 | BLOCKED |
| Full plate **all MageArmor** | 0 | OK | 0 | OK |
| Two pieces plate (Gorget 5 + Helm 10) | 15 | OK | 15 | OK |
| Four pieces plate (Gorget+Gloves+Helm+Arms) | 30 | OK | 30 | BLOCKED |

**The STEP mechanic** `[SRC]`

| Item | Value | Line |
|---|---|---|
| steps granted after a successful check | `int steps = (int)(m.Skills[Stealth].Value / (Core.AOS ? 5.0 : 10.0)); if (steps < 1) steps = 1;` | `Stealth.cs:106-109` |
| stored on | `m.AllowedStealthSteps = steps;` | `Stealth.cs:111` |
| flag | `m.IsStealthing = true;` | `Stealth.cs:113` |
| decrement (generic mobile) | `if (m_AllowedStealthSteps-- <= 0 \|\| (d & Direction.Running) != 0 \|\| Mounted) RevealingAction();` | `ServUO:Server/Mobile.cs:3044-3050` |
| decrement (players, `Core.SE`) | `if (!Mounted && Skills.Stealth.Value >= 25.0) { if (running) { if ((AllowedStealthSteps -= 2) <= 0) RevealingAction(); } else if (AllowedStealthSteps-- <= 0) Stealth.OnUse(this); }` | `ServUO:Scripts/Mobiles/PlayerMobile.cs:5448-5469` |
| decrement (creature pets with `CanStealth`) | same algorithm, gated on `CanStealth` (`virtual bool CanStealth => false`) | `ServUO:Scripts/Mobiles/Normal/BaseCreature.cs:4858,4861-4888` |
| reset on hidden change | `m_AllowedStealthSteps = 0;` | `ServUO:Server/Mobile.cs:8982` |

Decrement semantics: **post-decrement**, so a value of `N` permits exactly `N` steps; step `N+1` tests `0 <= 0` and fires. `[SRC]`
`AllowedStealthSteps` field/property: `ServUO:Server/Mobile.cs:803,1626`. `IsStealthing`: `ServUO:Server/Mobile.cs:3059,7073-7076`.

**Steps by skill** (derived from `Stealth.cs:106`):

| Stealth | AoS/SE+ steps (÷5) | pre-AoS steps (÷10) |
|---|---|---|
| 0 – 4.9 | 1 (floor of `value/5`, clamped to 1) | 1 |
| 25 | 5 | 2 |
| 50 | 10 | 5 |
| 80 | 16 | 8 |
| 100 | 20 | 10 |
| 120 | 24 | 12 |

`[WEB]` "Every 5 levels of Stealth increases the distance a character may walk before a skill check (e.g. 80 Stealth = 16 safe
steps per successful skill check.)" — [UOGuide — Stealth](https://www.uoguide.com/Stealth) ⇒ `[SRC+WEB]` for the AoS-era ÷5 rule.

**Per-tile behaviour and re-hide** `[SRC]` `ServUO:Scripts/Mobiles/PlayerMobile.cs:5431-5480`

| Trigger | Line | Behaviour |
|---|---|---|
| `!Core.SE` | `:5438-5441` | falls through to `base.OnMove` = the generic decrement+reveal (`Mobile.cs:3044-3050`) |
| `IsStaff()` | `:5443-5446` | `return true` — staff never lose stealth |
| `Hidden && DesignContext.Find(this) == null` (i.e. hidden and **not** in house-design mode) | `:5448` | enters the step engine |
| `Mounted` **or** `Stealth.Value < 25.0` | `:5450,5466-5469` | `RevealingAction()` — you cannot stealth mounted, and <25.0 Stealth cannot auto-stealth |
| walking, steps exhausted | `:5461-5464` | **calls `Stealth.OnUse(this)`** — a fresh skill check + fresh step allotment, silently (no message if it fails except `502731` from the handler) |
| running | `:5452-5460` | `AllowedStealthSteps -= 2`; when `<= 0` → `RevealingAction()` with **no** re-check |
| `InvisibilityPotion.HasTimer(this)` | `:5472-5477` | `InvisibilityPotion.Iterrupt(this)` |

`[WEB]` "Running while in stealth state will halve the number of safe steps and will -always- fail the stealth check afterward."
([UOGuide — Stealth](https://www.uoguide.com/Stealth)) — ServUO only *halves* the pool (`-= 2`) and reveals when it hits 0; there is
no separate "always fail" roll. **Divergence: `[WEB]` vs `[SRC]`, ServUO is the authority for the clone.**

Ninjitsu consumers of the step pool `[SRC]`: `SurpriseAttack.cs:55`, `Backstab.cs:49` require `Hidden && AllowedStealthSteps > 0`;
`KiAttack.cs:66` uses `Hidden && AllowedStealthSteps > 0`; `ShadowJump.cs:50-51,81-83` requires `pm.IsStealthing`.

### 5.3 SNOOPING — `ServUO:Scripts/Skills/Snooping.cs`

**Trigger** `[SRC]`: there is **no skill callback**. `Snooping.Configure()` installs `Container.SnoopHandler` (`Snooping.cs:12-15`).
`Container.OnSnoop(from)` invokes it (`ServUO:Server/Items/Container.cs:190-196`; delegate `:17`, field/property `:84-86`).
`Mobile.OnDoubleClick` reaches it only when the container's root parent is a mobile that considers the clicker a snoop:
`else if (root != null && root is Mobile && ((Mobile)root).IsSnoop(this)) item.OnSnoop(this);` (`ServUO:Server/Mobile.cs:4418-4421`),
and `Mobile.IsSnoop(from) => from != this` (`ServUO:Server/Mobile.cs:3618-3621`).
⇒ Consequence `[SRC]`: `SkillInfo.Table[28].Callback` stays `null`, so using Snooping from the skill list yields `500014`
"That skill cannot be used directly." (`ServUO:Server/Skills.cs:925-928`). `[WEB]` "there is no cool down timer for this skill's use"
([UOGuide — Snooping](https://www.uoguide.com/Snooping)) ⇒ `[SRC+WEB]`.

**Container ownership / eligibility cases, in order** `[SRC]` `Snooping.cs:40-98`

| # | Test | Line | Result |
|---|---|---|---|
| 1 | `from.IsStaff() \|\| from.InRange(cont.GetWorldLocation(), 1)` | `:42` | else `500446` "That is too far away." (**1 tile**) |
| 2 | `root != null && !root.Alive` | `:46-47` | silently `return` |
| 3 | `from.IsPlayer() && root is BaseCreature && !(cont is StrongBackpack)` | `:49-50` | silently `return` (players may only open pack-animal packs) |
| 4 | `root.IsStaff() && from.IsPlayer()` | `:52-56` | `500209` "You can not peek into the container." |
| 5 | `from.IsPlayer() && !CheckSnoopAllowed(from, root)` | `:58-62` | `1001018` "You cannot perform negative acts on your target." |
| 6 | `from.IsPlayer() && Snooping.Value < Utility.Random(100)` | `:64-74` | victim is notified (below) |
| 7 | `from.IsPlayer()` | `:76-77` | `Titles.AwardKarma(from, -4, true)` — **always**, success or fail |
| 8 | `from.IsStaff() \|\| from.CheckTargetSkill(Snooping, cont, 0.0, 100.0)` | `:79` | success path |
| 8a | success + `cont is TrapableContainer && ExecuteTrap(from)` | `:81-82` | `return` (never displays) |
| 8b | success | `:84` | `cont.DisplayTo(from)` |
| 8c | failure | `:88-91` | `500210` "You failed to peek into the container." then `if (Hiding.Value/2 < Utility.Random(100)) RevealingAction();` |

`CheckSnoopAllowed` `[SRC]` `Snooping.cs:17-38`:

| Target | Result | Line |
|---|---|---|
| `to.Player` | `from.CanBeHarmful(to, false, true)` (normal rules) | `:21-22` |
| map without `MapRules.HarmfulRestrictions` (Felucca rules) | `true` — "felucca you can snoop anybody" | `:24-25` |
| not inside a `GuardedRegion` (or region disabled) | `true` | `:27-30` |
| `to.Body.IsHuman` and (`cret == null \|\| (!AlwaysAttackable && !AlwaysMurderer)`) | `false` — cannot snoop blue human NPCs in town | `:32-35` |
| otherwise | `true` | `:37` |

**Victim detection message** `[SRC]` `Snooping.cs:64-74` — formula `Snooping.Value < Utility.Random(100)` ⇒ detection probability
= `1 - (int)(min(100,Snooping.Value)+1)/100`… precisely: the victim sees it when the roll `r ∈ [0,99]` satisfies `r > value`;
probability = `(99 - (int)value)/100` for `value ≤ 99`, and 0 at `value ≥ 99`. Derived `[SRC]`. Payload:
`root.Send(new AsciiMessage(-1, -1, MessageType.Label, 946, 3, "", "You notice {0} peeking into your belongings!"))` — hue **946**,
font **3**, `from.Name` substituted. The **victim only** is told; there is no bystander broadcast (contrast Stealing 5.4).

**Skill window** `[SRC]` `Snooping.cs:79` `CheckTargetSkill(Snooping, cont, 0.0, 100.0)` ⇒ `chance = Snooping.Value / 100`;
`value >= 100.0` ⇒ auto-success. Derived.

**Delay** `[SRC]`: **none** — there is no `NextSkillTime` write on this path.

**Criminal consequences** `[SRC]`: **none.** No `CriminalAction`, no `Criminal = true`, no guard call anywhere in `Snooping.cs`.
Only the karma loss at `:77`. `[WEB]` "You cannot be Guard Wacked for Snooping nor will you be flagged as a criminal. Snooping
_will_ lower your karma." — [UOGuide — Snooping](https://www.uoguide.com/Snooping) ⇒ `[SRC+WEB]`, karma delta `-4` is `[SRC]`.

### 5.4 STEALING — `ServUO:Scripts/Skills/Stealing.cs`

Callback `:25` (`SkillInfo.Table[33]`). Two global switches: `ClassicMode = false` (`:30`) and `SuspendOnMurder = false` (`:31`) —
**both hard-coded `readonly` in ServUO**, so the `502706` guild-suspension branch (`:75-78`) and the `PermaFlags` notoriety branch
(`Scripts/Misc/Notoriety.cs:431-432`, `PlayerMobile.cs:4411`) are **dead code in ServUO**. `[SRC]`
`IsInGuild(m)` = `m is PlayerMobile && ((PlayerMobile)m).NpcGuild == NpcGuild.ThievesGuild` (`Stealing.cs:33-36`; enum
`ServUO:Scripts/Mobiles/PlayerMobile.cs:101-106`). `IsInnocentTo(from,to)` = `Notoriety.Compute(from,to) == Notoriety.Innocent`
(`Stealing.cs:38-41`).

**Use / target acquisition** `[SRC]`

| Step | Line | Detail |
|---|---|---|
| hands must be empty | `:512-517` | `IsEmptyHanded` = no `Layer.OneHanded` **and** no `Layer.TwoHanded` item (`:497-510`); else `1005584` "Both hands must be free to steal." |
| open target | `:520-523` | `m.Target = new StealingTarget(m); m.RevealingAction(); 502698` "Which item do you want to steal?" |
| returned delay | `:526` | **`10.0 s`** |
| target range | `:48` | `base(1, false, TargetFlags.None)`, `AllowNonlocal = true` (`:52`) ⇒ 1 tile |
| reveal on target | `:396` | `from.RevealingAction()` runs **first**, before any check ⇒ **a successful steal always breaks hiding/stealth** |
| target = Mobile | `:407-417` | picks `pack.Items[Utility.Random(pack.Items.Count)]` — one random item, not a choice |
| target = neither Item nor Mobile | `:426-429` | `502710` "You can't steal that!" |

`[WEB]` "Attempting to steal an item will reveal you if you are Hidden or Invisible." and "will need to wait ten seconds before you
can use another skill" — [UOGuide — Stealing](https://www.uoguide.com/Stealing) ⇒ `[SRC+WEB]`.

**Pre-check rejection chain (`TryStealItem`)** `[SRC]` `Stealing.cs:67-286`

| # | Test | Line | Message |
|---|---|---|---|
| 1 | `!IsEmptyHanded(m_Thief)` | `:67-70` | `1005584` Both hands must be free to steal. |
| 2 | `root is Mobile && ((Mobile)root).Player && !IsInGuild(m_Thief)` | `:71-74` | `1005596` You must be in the thieves guild to steal from other players. |
| 3 | `SuspendOnMurder && root is Mobile && Player && IsInGuild && Kills > 0` | `:75-78` | `502706` (dead: `SuspendOnMurder == false`) |
| 4 | `root is BaseVendor && ((BaseVendor)root).IsInvulnerable` | `:79-82` | `1005598` You can't steal from shopkeepers. |
| 5 | `root is PlayerVendor` | `:83-86` | `502709` You can't steal from vendors. |
| 6 | `!m_Thief.CanSee(toSteal)` | `:87-90` | `500237` Target can not be seen. |
| 7 | `Backpack == null \|\| !Backpack.CheckHold(...)` | `:91-94` | `1048147` Your backpack can't hold anything else. |
| 8 | `toSteal is Sigil` (faction) | `:96-183` | see sigil sub-table |
| 9 | `toSteal is VvVSigil && ViceVsVirtueSystem.Instance != null` | `:186-246` | see sigil sub-table |
| 10 | `si == null && (Parent == null \|\| !Movable) && !ItemFlags.GetStealable(toSteal)` | `:249-252` | `502710` You can't steal that! (non-movable world decoration) |
| 11 | `LootType == LootType.Newbied \|\| CheckBlessed(root)` **and** `!ItemFlags.GetStealable` | `:253-256` | `502710` You can't steal that! |
| 12 | `Core.AOS && si == null && toSteal is Container` **and** `!ItemFlags.GetStealable` | `:257-260` | `502710` You can't steal that! |
| 13 | `!m_Thief.InRange(toSteal.GetWorldLocation(), 1)` | `:261-264` | `502703` You must be standing next to an item to steal it. |
| 14 | `si != null && Stealing.Value < 100.0` | `:265-268` | `1060025` hue `0x66D` You're not skilled enough to attempt the theft of this item. |
| 15 | `toSteal.Parent is Mobile` (worn) | `:269-272` | `1005585` You cannot steal items which are equiped. |
| 16 | `root == m_Thief` | `:273-276` | `502704` You catch yourself red-handed. |
| 17 | `root is Mobile && ((Mobile)root).IsStaff()` | `:277-280` | `502710` You can't steal that! |
| 18 | `root is Mobile && !m_Thief.CanBeHarmful((Mobile)root)` | `:281-282` | **empty block — nothing is sent, nothing happens** |
| 19 | `root is Corpse` | `:283-286` | `502710` You can't steal that! |
| 20 | `w > 10` | `:291-294` | `m_Thief.SendMessage("That is too heavy to steal.")` — **an ASCII string, not a cliloc** |

**Blessed / Insured / Newbied / Cursed** `[SRC]` `ServUO:Server/Item.cs:6116-6134`:
`CheckBlessed(m)` returns true when `m_LootType == LootType.Blessed` **or** (`Mobile.InsuranceEnabled && Insured`) **or** (`m != null && m == BlessedFor`).
`CheckNewbied()` = `LootType == LootType.Newbied`. `LootType` enum: `Regular = 0, Newbied = 1, Blessed = 2, Cursed = 3`
(`ServUO:Server/Item.cs:536-557`, with the doc comments "Unstealable. Unlootable, unless owned by a murderer" / "Unstealable. Unlootable, always" / "Stealable. Lootable, always").
⇒ **Cursed items are stealable**; insured items are unstealable **only while `Mobile.InsuranceEnabled`**; `BlessedFor` protects the item only from *that* mobile (stealing by a third party from a blessed-for owner's pack passes `CheckBlessed(root)` where `root` is the owner ⇒ still blocked; from a *different* holder it is not). Derived `[SRC]`.

**The FULL weight formula** `[SRC]` `Stealing.cs:287-347`

```
w  = toSteal.Weight + toSteal.TotalWeight                                  // Stealing.cs:289
if (w > 10) -> "That is too heavy to steal."                               // Stealing.cs:291-294   HARD CAP = 10 stones
```

`Weight` = per-item weight (`ServUO:Server/Item.cs:3816-3828`, default from tiledata `:3795-3813`);
`TotalWeight` = `GetTotal(TotalType.Weight)` (`Item.cs:3793`) which for a `Container` is the accumulated contents weight
(`ServUO:Server/Items/Container.cs:1688-1702`, accumulated at `:1756`) ⇒ **a container's `w` includes everything inside it.** `[SRC]`

| Branch | Line | Arithmetic |
|---|---|---|
| `Stackable && Amount > 1` | `:297-336` | `maxAmount = (int)((Stealing.Value / 10.0) / toSteal.Weight)`, clamped: `<1 → 1`, `>Amount → Amount` (`:299-308`) |
| ↳ `amount = Utility.RandomMinMax(1, maxAmount)` | `:310` | inclusive `[1, maxAmount]` (`Utility.cs:889-903`) |
| ↳ if `amount >= toSteal.Amount` (whole pile) | `:312-321` | `pileWeight = (int)Math.Ceiling(toSteal.Weight * toSteal.Amount) * 10`; `CheckTargetSkill(Stealing, toSteal, pileWeight - 22.5, pileWeight + 27.5)`; `stolen = toSteal` |
| ↳ else (partial pile) | `:323-336` | `pileWeight = (int)Math.Ceiling(toSteal.Weight * amount) * 10`; same window; `stolen = Mobile.LiftItemDupe(toSteal, toSteal.Amount - amount)` (`:329`), falling back to `toSteal` if `null` (`:331-334`) |
| non-stackable | `:340-346` | `iw = (int)Math.Ceiling(w) * 10`; `CheckTargetSkill(Stealing, toSteal, iw - 22.5, iw + 27.5)`; `stolen = toSteal` |

⇒ **Unified window (derived `[SRC]`):**
`chance = (Stealing.Value - (10*W - 22.5)) / 50`, where `W = ceil(weight-of-the-pile-actually-grabbed)`.
`Stealing.Value < 10*W - 22.5` ⇒ automatic failure; `Stealing.Value >= 10*W + 27.5` ⇒ automatic success.

**Max-stealable-weight-by-skill rules** (derived `[SRC]` from the two literals above):

| Rule | Formula | Consequence |
|---|---|---|
| absolute cap | `w ≤ 10` (`:291`) | nothing heavier than 10 stones is ever stealable, at any skill |
| stack amount cap | `maxAmount = (int)((Stealing.Value/10) / Weight)` (`:299`) | the *pile* you can grab weighs at most `Stealing.Value/10` stones |
| zero-chance floor | `Stealing.Value ≥ 10*W - 22.5` | a 10-stone item needs 77.5 Stealing just to have a chance |
| guaranteed-success ceiling | `Stealing.Value ≥ 10*W + 27.5` | 7-stone items are 100 % at 97.5 Stealing; 10-stone items are never 100 % (would need 127.5) |

| Item weight `w` | `iw` | window | chance @ Stealing 100 | success prob (ServUO roll) |
|---|---|---|---|---|
| 1 | 10 | `-12.5 .. 37.5` | auto (`100 ≥ 37.5`) | 100 % |
| 3 | 30 | `7.5 .. 57.5` | auto | 100 % |
| 5 | 50 | `27.5 .. 77.5` | auto | 100 % |
| 7 | 70 | `47.5 .. 97.5` | auto | 100 % |
| 8 | 80 | `57.5 .. 107.5` | `(100-57.5)/50 = 0.85` | 86 % (`Random(100) <= 85`) |
| 9 | 90 | `67.5 .. 117.5` | `0.65` | 66 % |
| 10 | 100 | `77.5 .. 127.5` | `0.45` | 46 % |
| > 10 | — | — | blocked at `:291` | 0 % |

`[WEB]` "You may not take items that weigh more then your skill level divided by 10" —
[UOGuide — Stealing](https://www.uoguide.com/Stealing) ⇒ `[SRC+WEB]` for the `Stealing/10` pile-weight rule; the 10-stone hard cap
is `[SRC]` only. UOGuide's training table ("30-40 → 3 stones … 100-110 → 10 stones") is consistent with that rule ⇒ `[WEB]`.

**Worked gold example** `[SRC]`-derived. `Gold.DefaultWeight = Core.ML ? (0.02/3) : 0.02` (`ServUO:Scripts/Items/Consumables/Gold.cs:34-40`),
`Gold` is `Stackable = true` (`:25`). At `Stealing = 100.0`:
pre-ML `maxAmount = (int)((100/10.0)/0.02) = 500` coins; ML `maxAmount = (int)(10/0.0066667) = 1500` coins.
Both then clamped by `toSteal.Amount`; `amount = RandomMinMax(1, maxAmount)`; `pileWeight = ceil(0.02*amount)*10`
(e.g. `amount = 500` → `ceil(10.0)*10 = 100` → window `77.5 .. 127.5` → 45 % at GM).

**Caught / witness roll** `[SRC]` `Stealing.cs:349-366` — only runs when `stolen != null && (root is FillableContainer || stolen.Movable)`;
otherwise `caught = false` ("Non-movable stealable (not in fillable container) items cannot result in the stealer getting caught", `:349`).

| Source container | Line | Formula | Probability |
|---|---|---|---|
| `root is FillableContainer` | `:354-356` | `caught = (Utility.Random((int)(skillValue / 2.5)) == 0)` | `1/(int)(Stealing/2.5)` = **1 in 48 at Stealing 120** (comment at `:356`); **always true when `Stealing < 2.5`** because `Random(0) = 0` (`Utility.cs:921-924`) |
| anything else | `:358-361` | `caught = (skillValue < Utility.Random(150))` | `(149 - (int)Stealing)/150`; ≈ **32.7 % at Stealing 100** (rolls 101..149 of 0..149), **0 % at Stealing ≥ 149**, **99.3 % at Stealing 0** |
| non-movable world item | `:363-366` | `caught = false` | 0 % |

**Success / failure messages** `[SRC]`

| Clue | Text | Line |
|---|---|---|
| `502724` | You succesfully steal the item. *(sic)* | `Stealing.cs:370` |
| `502723` | You fail to steal the item. | `Stealing.cs:386` |
| ASCII | `You notice {thief} trying to steal from {victim}.` sent to every client within **8** tiles except the thief | `Stealing.cs:470-478` |

On success `[SRC]` `:372-382`: `ItemFlags.SetTaken(stolen, true)`, `ItemFlags.SetStealable(stolen, false)`, `stolen.Movable = true`,
`InvokeItemStoken(...)` event, and for stealable-artifact instances `toSteal.Movable = true; si.Item = null;`.
Flags live in the XmlSpawner core: `StealableFlag = 0x00200000`, `TakenFlag = 0x00100000`
(`ServUO:Scripts/Services/XmlSpawner/XmlSpawner Core/ItemFlags.cs:12-13`, accessors `:21-49`) — `[SRC]` **the stealing handler has a
hard compile-time dependency on the XmlSpawner service**; a clone must either implement those two saved flags or drop the checks.
On target, `:431-449`: `AddonComponent` → `addon.Deed` to backpack + `addon.Delete()`; else `from.AddToBackpack(stolen)`;
`StolenItem.Add(stolen, thief, root as Mobile)` only for non-`Container`, non-`Stackable` items (`:444-448`).

**Delay** `[SRC]`: `10.0 s` (`Stealing.cs:526`).

**Player vs NPC** `[SRC]`: players require the Thieves Guild (`:71-74`, `1005596`); all roots additionally pass through
`CanBeHarmful` (`:281`) and the town rules below. **There is no Felucca-facet requirement in the source** — UOGuide states
"make all attempts within the Felucca facet" ([UOGuide — Stealing](https://www.uoguide.com/Stealing)); `[SRC]` vs `[WEB]`
divergence: **ServUO does not enforce a facet**; the only facet-sensitive input is `MapRules.HarmfulRestrictions` through
`CanBeHarmful` / `CheckSnoopAllowed`.

**Town / guard-zone rules** `[SRC]`

| Rule | Line |
|---|---|
| invulnerable shopkeepers cannot be stolen from (`1005598`) | `Stealing.cs:79-82` |
| `PlayerVendor` cannot be stolen from (`502709`) | `Stealing.cs:83-86` |
| equipped items cannot be stolen (`1005585`) | `Stealing.cs:269-272` |
| corpses: `502710` when the corpse root is targeted directly; but a **caught** steal whose `root is Corpse && IsCriminalAction(thief)` sets the criminal flag | `:283-286`, `:457-460` |
| any `CriminalAction` inside a guarded region calls `CheckGuardCandidate` ⇒ guards | `GuardedRegion.cs:225-233` |

**`StolenItem` bookkeeping** `[SRC]` `Stealing.cs:538-633`: `StealTime = TimeSpan.FromMinutes(2.0)` (`:540`); queue-based
(`:563-570`); `IsStolen(item, ref victim)` (`:579-593`); `ReturnOnDeath(killed, corpse)` returns the item to the victim on death
within the window with `1010464` "the item that was stolen is returned to you." or `1010463` "…falls to the ground." (`:595-615`).

**Faction / VvV sigil sub-rules** `[SRC]` `Stealing.cs:96-246`

| Requirement | Line | Message |
|---|---|---|
| adjacent (1 tile) | `:103-106` | `502703` |
| must be on the ground (`root == null`) | `:107-110` | `502710` |
| must be in a faction | `:111-182` | `1005588` You must join a faction to do that |
| not incognito / not disguised / not polymorphed / no transformation / not animal form | `:113-132` | `1010581`, `1010583`, `1010582`, `1061622`, `1063222` |
| not leaving the faction / not your own sigil / not purifying | `:133-144` | `1005589`, `1005590`, `1005592` |
| **skill check** | `:145` | `CheckTargetSkill(Stealing, toSteal, 80.0, 80.0)` ⇒ `Stealing.Value < 80` ⇒ `1005594`; `>= 80` ⇒ auto |
| already carrying a sigil / pack full | `:147-155` | `1010258`, `1010259` |
| success | `:156-172` | `1010586` YOU STOLE THE SIGIL!!! |
| VvV sigil (participants only) | `:186-246` | `CheckTargetSkill(Stealing, toSteal, 100.0, 120.0)` (`:222`); non-participant `1155415` |

### 5.5 FLAGGING — the criminal path, guards, colour, reveal interactions

**Exact code path that sets `Criminal`** `[SRC]`

```
Stealing.OnTarget            Stealing.cs:455/459/467/483   m_Thief.CriminalAction(false);
  Mobile.CriminalAction      Mobile.cs:3571-3581           Criminal = true; Region.OnCriminalAction(this, message);
    Mobile.Criminal setter   Mobile.cs:11814-11846         Delta(MobileDelta.Noto); InvalidateProperties(); (re)start ExpireCriminalTimer
      ExpireCriminalTimer    Mobile.cs:2106-2121           OnTick -> m_Mobile.Criminal = false;
    Region.OnCriminalAction  Region.cs:904-914             bubbles to parent; if (message) 1005040 "You've committed a criminal act!!"
      GuardedRegion override GuardedRegion.cs:225-233      if (!IsDisabled()) CheckGuardCandidate(m);
```

Every steal call passes `message: false` (`Stealing.cs:455,459,467,483`) ⇒ **the thief is never shown `1005040` by the steal path.**
The only player-visible feedback is the radius-8 ASCII line to *others* (`:470-478`). `[SRC]`

**Flag duration constant** `[SRC]`: `private static TimeSpan m_ExpireCriminalDelay = TimeSpan.FromMinutes(2.0);`
(`ServUO:Server/Mobile.cs:2102`), exposed as `Mobile.ExpireCriminalDelay` (`:2104`), applied by `ExpireCriminalTimer`
(`:2106-2121`, `Priority = TimerPriority.FiveSeconds`). Each new `Criminal = true` **restarts** the timer (`:11827-11839`).

**Notoriety colour and value** `[SRC]`: `Notoriety.Criminal = 4` (`ServUO:Server/Notoriety.cs:10`);
hue table `m_Hues = {0x000, 0x059, 0x03F, 0x3B2, 0x3B2, 0x090, 0x022, 0x035}` indexed by notoriety value
(`ServUO:Server/Notoriety.cs:17`, accessor `:21-29`), re-asserted in `NotorietyHandlers.Initialize()`:
`Notoriety.Hues[Notoriety.Criminal] = 0x3B2` (`ServUO:Scripts/Misc/Notoriety.cs:28`).
`MobileNotoriety` returns `Notoriety.Criminal` for `target.Criminal` (`ServUO:Scripts/Misc/Notoriety.cs:401-402`).
`Notoriety.Compute` falls back to `CanBeAttacked` (3) when no handler is installed (`ServUO:Server/Notoriety.cs:31-34`).

**PermaFlags** `[SRC]` `Stealing.cs:486-493`: when the root is a **player**, the thief is a `PlayerMobile`, `IsInnocentTo(thief, root)`
and `!IsInGuild(root)` → `pm.PermaFlags.Add(root); pm.Delta(MobileDelta.Noto);`. Property: `PlayerMobile.PermaFlags`
(`ServUO:Scripts/Mobiles/PlayerMobile.cs:4393`, list field `:4044`, cleared on death handling `:3949-3951`). Its **only** consumers
are gated on `Stealing.ClassicMode`, which is `false` in ServUO ⇒ no notoriety effect in a stock ServUO build
(`ServUO:Scripts/Misc/Notoriety.cs:431-432`, `ServUO:Scripts/Mobiles/PlayerMobile.cs:4411`). `[SRC]`

**Guard response** `[SRC]`

| Step | Line | Detail |
|---|---|---|
| `CheckGuardCandidate(m)` | `GuardedRegion.cs:235-313` | runs only if `!IsDisabled()` |
| `IsGuardCandidate(m)` | `GuardedRegion.cs:354-363` | false for `BaseGuard`, `GuardImmune`, dead, staff, `Blessed`, invulnerable creature, disabled region; true for `(!AllowReds && Murderer) \|\| Criminal \|\| aggressive monster` |
| `AllowReds` | `GuardedRegion.cs:63` | `Core.AOS` ⇒ **pre-AoS reds are guard candidates on sight** |
| timer | `GuardedRegion.cs:446-468` | `GuardTimer : base(TimeSpan.FromSeconds(15.0))`, `TimerPriority.TwoFiftyMS` |
| on flag | `GuardedRegion.cs:269` | `m.SendLocalizedMessage(502275); // Guards can now be called on you!` |
| fake guard call | `GuardedRegion.cs:271-305` | nearest non-candidate human within **8** tiles says one of `1007037, 501603, 1013037, 1013038, 1013039, 1013041, 1013042, 1013043, 1013052` then `MakeGuard(m)` + `502276` |
| timer expiry | `GuardedRegion.cs:465` | `502276; // Guards can no longer be called on you.` |
| speech trigger | `GuardedRegion.cs:192-195` | `*guards*` keyword (`0x0007`) and `Alive` → `CallGuards(m.Location)` |
| `CallGuards` | `GuardedRegion.cs:315-352` | scans **14** tiles; acts if the candidate already has a timer or (`!AllowReds && Murderer`); aggressive monsters get guards too |
| `MakeGuard(focus)` | `GuardedRegion.cs:124-160` | reuse an idle `BaseGuard` within **8** tiles, else `Activator.CreateInstance(m_GuardType, …)` |
| guard type | `GuardedRegion.cs:65-78` | `ArcherGuard` on Ilshenar/Malas, else `WarriorGuard` |
| aggression path | `GuardedRegion.cs:198-206` | `OnAggressed(..., criminal: true)` within **12** tiles also calls `CheckGuardCandidate`; auto-calls guards when the aggressor is an aggressive monster |
| beneficial path | `GuardedRegion.cs:208-223` | helping a `Criminal`/`Murderer` notoriety target flags the helper |

**Aggression bookkeeping used by DetectHidden** `[SRC]`: `Mobile.AggressiveAction(aggressor, criminal)` sets
`info.CriminalAggression = criminal; info.CanReportMurder = criminal;` (`ServUO:Server/Mobile.cs:2300-2337`);
`CheckAggressed` ignores `CriminalAggression` entries (`ServUO:Scripts/Misc/Notoriety.cs:536-545`);
`DoHarmful` computes `IsHarmfulCriminal` (default: `Notoriety.Compute(this,target) == Notoriety.Innocent`, `Mobile.cs:8003-8011`),
calls `OnHarmfulAction` → `CriminalAction(false)` (`:8016-8022`) and `AggressiveAction(this, isCriminal)` (`:8036-8041`).

**Detect Hidden — active search** `[SRC]` `DetectHidden.cs`

| Element | Value | Line |
|---|---|---|
| callback / skill id | `SkillInfo.Table[14]` | `:32` |
| prompt + cooldown | `500819` "Where will you search?" ; `TimeSpan.FromSeconds(10.0)` | `:37-40` |
| target | `base(12, true, TargetFlags.None)` (12 tiles) | `:46` |
| range | `Math.Max(2, (int)(srcSkill / 10.0))` where `srcSkill = DetectHidden.Value` | `:64-65` |
| failed check halves it | `if (!src.CheckSkill(DetectHidden, 0.0, 100.0)) range /= 2;` | `:67-68` |
| house bonus | `house.IsFriend(src)` ⇒ `range = 22` | `:70-75` |
| detection roll | `ss = srcSkill + Utility.Random(21) - 10; ts = trg.Skills[Hiding].Value + Utility.Random(21) - 10;` | `:85-86` |
| skill-mastery shadow | `double shadow = SkillMasteries.ShadowSpell.GetDifficultyFactor(trg);` used as `Utility.RandomDouble() > shadow` | `:87-90` |
| success condition | `src.AccessLevel >= trg.AccessLevel && (ss >= ts \|\| houseCheck) && RandomDouble() > shadow`, then `!(ShadowKnight off-tile) && (houseCheck \|\| CanDetect(src,trg))` | `:90-94` |
| messages | `500814` "You have been revealed!" to the target (both `SendLocalizedMessage` and `PrivateOverheadMessage(MessageType.Regular, 0x3B2, 500814, …)`) | `:97-98` |
| nothing found | `500817` "You can see nothing hidden there." | `:135` |
| item revealables | `IRevealableItem.CheckReveal/CheckPassiveDetect/OnRevealed/CheckWhenHidden` (`Server.Items` interface `:16-23`) | `:116-127` |

**Detect Hidden — passive** `[SRC]` `DetectHidden.cs:140-185`, driven from `PlayerMobile` every movement tick capped to once per
**2 s** (`ServUO:Scripts/Mobiles/PlayerMobile.cs:2095-2099`):

| Element | Value | Line |
|---|---|---|
| guards | `src == null \|\| Map == null \|\| Location == Point3D.Zero \|\| IsStaff()` | `:142-143` |
| zero-skill guard | `ss = DetectHidden.Value; if (ss <= 0) return;` | `:145-148` |
| radius / mobile filter | `GetMobilesInRange(src.Location, 4)`; skips `null`, self, `ShadowKnight`, `!CanDetect` — **does not test `m.Hidden`** | `:150-158` |
| target skill | `ts = (Hiding.Value + Stealth.Value) / 2` | `:160` |
| elf bonus | `if (src.Race == Race.Elf) ss += 20;` — accumulated **inside** the loop, so it compounds per candidate (quirk) | `:162-163` |
| roll | `Utility.Random(1000) < (ss - ts) + 1` ⇒ probability `clamp((ss-ts+1)/1000, 0, 1)` | `:165` |
| reveal | `m.RevealingAction(); m.SendLocalizedMessage(500814);` | `:167-168` |
| hidden items | `GetItemsInRange(src.Location, 8)` → `1153493` "Your keen senses detect something hidden in the area..." | `:174-181` |

**`CanDetect(src, target)`** `[SRC]` `DetectHidden.cs:187-209`: false if either map is null, `!src.CanBeHarmful(target, false)`,
`src.Blessed` / invulnerable creature, `target.Blessed` / invulnerable creature, `!SpellHelper.ValidIndirectTarget(target, src)`
(pet owner, guild/alliance, party); true if `src.Aggressed.Any(x => x.Defender == target) || src.Aggressors.Any(x => x.Attacker == target)`;
otherwise `src.Map.Rules == MapRules.FeluccaRules` ⇒ **passive/active detection of unrelated blues only on Felucca rules.**

**Forensic Evaluation — full gate table** `[SRC]` `ForensicEval.cs` (callback `:19`, `501000` "Show me the crime." `:27`,
`RevealingAction()` `:25`, delay `1.0 s` `:29`, target `base(10, false, TargetFlags.None)` `:35`)

| Target | Pre-gate (skill `<`) | Line | Check window | Lines | Success messages | Fail |
|---|---|---|---|---|---|---|
| `Corpse` | `30.0` → `501003` "You notice nothing unusual." | `:42,46-50` | `CheckTargetSkill(Forensics, target, 30.0, 55.0)` | `:52` | `1042750` already-forensicist `~1_NAME~`, `1042751` killed by `~1_KILLER_NAME~`, `1042752` disturbed by `~1_PLAYER_NAMES~`, else `501002` "The corpse has not be desecrated." | `501001` "You cannot determain anything useful." (`:85`) |
| `Mobile` | `36.0` → `501003` | `:90-93` | `CheckTargetSkill(Forensics, target, 36.0, 100.0)` | `:94` | `501004` "That individual is a thief!" when `target is PlayerMobile && NpcGuild == NpcGuild.ThievesGuild`, else `501003` | `501001` (`:107`) |
| `ILockpickable` | `41.0` → `501003` | `:112-115` | `CheckTargetSkill(Forensics, target, 41.0, 100.0)` | `:116` | `1042749` "This lock was opened by ~1_PICKER_NAME~" when `p.Picker != null`, else `501003` | `501001` (`:131`) |
| `Item` (only `Core.SA`) | `41.0` → `501001` | `:134-146` | `41.0 .. 100.0` for `HonestyItemSocket` | `:155` | `1151521` if `Forensics.Value >= 61.0`, else `1151522` | — |
| `IForensicTarget` | — | `:138-141` | delegated | — | — | — |

Corpse support fields: `m_Forensicist` (`ServUO:Scripts/Items/Corpses/Corpse.cs:116`), `m_Killer` (`:84`), `m_Looters` (`:87`,
appended on loot `:1077-1079,1102-1104`), `Looters/Killer` accessors (`:379-382`), `IsCriminalAction` (`:1002-1025`) which returns
`NotorietyHandlers.CorpseNotoriety(from, this) == Notoriety.Innocent` and respects `CorpseFlag.LootCriminal` (`:1009-1010`).
**Forensics never sets the criminal flag on the user** — the only flag interaction is the reveal at `:25` and the `101000` prompt. `[SRC]`

**Tracking — thief-relevant constants** `[SRC]` `Tracking.cs`

| Element | Value | Line |
|---|---|---|
| callback / prompt / delay | `SkillInfo.Table[38]`; `1011350` "What do you wish to track?"; `10.0 s` | `:17,22,28` |
| entry check (gump ctor) | `from.CheckSkill(Tracking, 0.0, 21.1)` | `:87` |
| no evidence | `1018092` "You see no evidence of those in the area." | `:178` |
| passive gain | `from.CheckSkill(Tracking, 21.1, 100.0)` | `:189` |
| search range | `10 + (int)(from.Skills[Tracking].Value / 10)` ⇒ 10–20 tiles | `:191` |
| candidate filter | `m != from && (!Core.AOS \|\| m.Alive) && (!m.Hidden \|\| m.IsPlayer() \|\| from.AccessLevel > m.AccessLevel) && type && CheckDifficulty` | `:199` |
| empty-category messages | `502991` animals / `502993` creatures / `502995` people | `:214-218` |
| arrow radius | `m_Range * 2` | `:230` |
| stalking info only from SE | `if (Core.SE) Tracking.AddInfo(...)` | `:232-233` |
| player-vs-player difficulty | `tracking = Tracking.Fixed`, `detectHidden = DetectHidden.Fixed`; elf (ML) `tracking /= 2`; `divisor = Hiding.Fixed + Stealth.Fixed`; HorrificBeast `divisor -= 200`; VampiricEmbrace `divisor = max(divisor,500)`; WraithForm `divisor += 200` if `<= 2000`; SE `chance = 50 * (tracking*2 + detectHidden) / divisor`, else `chance = 50 * (tracking + detectHidden + 10*RandomMinMax(1,20)) / divisor`; `divisor <= 0 ⇒ 100`; success `chance > Utility.Random(100)` | `:238-273` |
| arrow refresh | `TrackTimer : base(TimeSpan.FromSeconds(0.25), TimeSpan.FromSeconds(2.5))` | `:362` |
| lost quarry | `503177` "You have lost your quarry." | `:349` |
| stalking bonus | `sqrt(dx²+dy²)`, table entry removed on use ("Reset as of Pub 40, counting it as bug for Core.SE"); ML caps at `Math.Min(bonus, 10 + Tracking.Value/10)` | `:37-56` |

**Remove Trap — thief-relevant constants** `[SRC]` `RemoveTrap.cs`

| Element | Value | Line |
|---|---|---|
| callback | `SkillInfo.Table[48]` | `:24` |
| prereqs (skipped under `Core.EJ`) | `Lockpicking.Value < 50` → `502366`; `DetectHidden.Value < 50` → `502367` | `:29-36` |
| prompt / delay / range | `502368` "Wich trap will you attempt to disarm?"; `10.0 s`; `base(2, false, TargetFlags.None)` | `:41,44,50` |
| container window | `CheckTargetSkill(RemoveTrap, targ, targ.TrapPower, targ.TrapPower + 10)` | `:111` |
| success / fail | `502377` "You successfully render the trap harmless"; `502372` "You fail to disarm the trap... but you don't set it off"; success zeroes `TrapPower`, `TrapLevel`, `TrapType` | `:113-121` |
| other targets | `Mobile` → `502816`; locked → `501283`; untrapped → `502373` | `:58,66,76` |
| faction trap | `RemoveTrap 80..100 && Tinkering 80..100` (or `Core.ML && isOwner`); messages `1010538`/`1010537`/`1042530`/`1008113` | `:134-158` |
| VvV trap | `(RemoveTrap.Value - 80.0) / 20.0 > Utility.RandomDouble()`; else `0.1 > Utility.RandomDouble()` detonates | `:181,203` |
| treasure chest (new system) | 10 s repeating timer (`:314`); GM remover (`RemoveTrap >= 100`, `:263`) uses a per-level safety window (`Stash 20 s, Supply 60 s, Cache 180 s, Hoard 420 s, Trove 540 s`, `:324-332`) then `CheckTargetSkill(RemoveTrap, Chest, 80, 120 + Chest.Level*10)` (`:366`), else guardian; sub-100 uses `min = ceil(RemoveTrap.Value * 0.75)`, `max = min > 50 ? min + 50 : 100` (`:382-384`); range check **16** tiles (`:351`) | `:256-409` |

### 5.6 ModernUO cross-check (diffs only; identical constants listed as "same")

| Constant / behaviour | ServUO (pub57) | ModernUO (main) | Diff |
|---|---|---|---|
| Hiding busy message/delay | `501238`, `1.0 s` `Hiding.cs:30-31` | same `Hiding.cs:21-22` | **same** |
| Hiding VvV ManaSpike gate | present `Hiding.cs:34-37` | **absent** `Hiding.cs:17-28` | ModernUO removed |
| Hiding house-friend bonus | `100.0` `Hiding.cs:50` | `100.0` `Hiding.cs:36` | **same** |
| Hiding adjacent-house bonus | `50.0` `Hiding.cs:67` | `50.0` `Hiding.cs:47` | **same** |
| Hiding range | `Math.Min((int)((100-skill)/2)+8, 18)` `Hiding.cs:72` | same literal `Hiding.cs:53` | **same** |
| Hiding watched test | `((Mobile)m.Combatant).InLOS(m.Combatant)` `Hiding.cs:74` | `m.Combatant.InLOS(m)` `Hiding.cs:55-56` | **different LOS subject** |
| Hiding unwatched sweep | `foreach (GetMobilesInRange(range))` + `check.InLOS(m) && check.Combatant == m` → `badCombat = true; break;` `Hiding.cs:81-94` | identical `Hiding.cs:63-70` | **same** |
| Hiding `badCombat` cooldown | `TimeSpan.Zero` `Hiding.cs:105` | `TimeSpan.FromSeconds(1.0)` `Hiding.cs:82` | **different** |
| Hiding success extras | removes `Sixth.InvisibilitySpell` + `InvisibilityPotion` timers `Hiding.cs:114-115` | only `InvisibilitySpell.StopTimer(m)` `Hiding.cs:90` | **different** |
| Stealth `HidingRequirement` | `ML 30.0 / SE 50.0 / else 80.0` `Stealth.cs:28` | same `Stealth.cs:11-12` | **same** |
| Stealth armor table rows | 11 (no Wood/Stone) `Stealth.cs:12-22` | 13 rows incl. Wood/Stone `Stealth.cs:18-30` | **different table** |
| `Dragon` row (Gorget) | `{ 0, 5, 10, 10, 15, 25, 0 }` `Stealth.cs:22` | `{ 5, 5, 10, 10, 15, 25, 0 }` `Stealth.cs:28` | **0 vs 5** |
| `Wood` / `Stone` rows | absent (skipped by length guard) | `{ 5, 5, 10, 10, 15, 25, 0 }` `Stealth.cs:29-30` | ModernUO blocks wood/stone armour |
| Stealth MageArmor predicate | `armor.ArmorAttributes.MageArmor == 0` `Stealth.cs:63` | same `Stealth.cs:62` | **same** |
| Stealth flying gate | `1113415` + reveal `Stealth.cs:76-81` | **absent** `Stealth.cs:71-95` | ModernUO removed |
| Stealth armor cap | `Core.AOS ? 42 : 26` `Stealth.cs:98` | same `Stealth.cs:91` | **same** |
| Stealth check window | `-20.0 + AR*2 .. (AOS?60:80) + AR*2` `Stealth.cs:104` | same `Stealth.cs:96-100` | **same** |
| Stealth steps | `(int)(Stealth.Value / (AOS?5.0:10.0))`, min 1 `Stealth.cs:106-109` | `Math.Max((int)(Stealth.Value / (AOS?5.0:10.0)), 1)` `Stealth.cs:102` | **equivalent** |
| `IsStealthing` home | `Mobile` `Server/Mobile.cs:3059` | `PlayerMobile` `Projects/UOContent/Mobiles/PlayerMobile.cs:409` | **moved** |
| Stealth buff icon | `BuffInfo(HidingAndOrStealth, 1044107, 1075655)` `Stealth.cs:117` | **absent** | ModernUO removed |
| Snooping range / far message | `InRange(...,1)` / `500446` `Snooping.cs:42,96` | `InRange(...,1)` + `AccessLevel <= Player` / `500446` `Snooping.cs:41-44` | **equivalent** |
| Snooping NPC-pack block | `root is BaseCreature && !(cont is StrongBackpack)` `Snooping.cs:49-50` | **absent** | ModernUO allows snooping any NPC pack |
| Snooping staff-container message | `500209` `Snooping.cs:54` | folded into `1001018` `Snooping.cs:54-57` | **different id** |
| Snooping victim notify | victim only, ASCII hue `946` `Snooping.cs:70-72` | **radius-8 broadcast**, `"You notice {from} attempting to peek into {root}'s belongings."` `Snooping.cs:69-78` | **different audience + text** |
| Snooping victim-notify gate | `Snooping.Value < Utility.Random(100)` `Snooping.cs:64` | `snooping < 100.0 && snooping < Utility.RandomDouble()*100` `Snooping.cs:63` | **different (adds a <100 gate)** |
| Snooping karma | `-4` `Snooping.cs:77` | `-4` `Snooping.cs:81` | **same** |
| Snooping window / fail reveal | `0.0..100.0`; `Hiding.Value/2 < Random(100)` `Snooping.cs:79,90` | `0.0..100.0`; `Hiding.Value/2 < RandomDouble()*100` `Snooping.cs:84,97` | **same logic, different RNG** |
| Stealing use delay | `10.0 s` `Stealing.cs:526` | `30.0 s` `Stealing.cs:69`, then re-derived to a 10 s skill cooldown minus targeter elapsed time (`:424-430`) | **different** |
| `ClassicMode` / `SuspendOnMurder` | `readonly false` / `readonly false` `Stealing.cs:30-31` | config-driven, default `!Core.AOS` `Stealing.cs:30-31` | **different** |
| Container stealing | always blocked under AoS unless `ItemFlags.GetStealable` `Stealing.cs:257-260` | `CanStealContainers` config, default `!Core.AOS` `Stealing.cs:32,223` | **different** |
| Weight cap | `w > 10` → ASCII `SendMessage("That is too heavy to steal.")` `Stealing.cs:291-293` | `w > MaxWeightToSteal` (config default `10`) → cliloc `502722` `Stealing.cs:33,263-267` | **same number, different text** |
| `maxAmount` | `(int)((Stealing.Value/10.0)/Weight)` clamped by two `if`s `Stealing.cs:299-308` | `Math.Clamp((int)(Stealing.Value/10.0/Weight), 1, Amount)` `Stealing.cs:272-276` | **equivalent** |
| Stack window | `pileWeight = ceil(Weight*amount)*10`; `-22.5 .. +27.5` `Stealing.cs:314-327` | identical `Stealing.cs:282-305` | **same** |
| Non-stack window | `iw = ceil(w)*10`; `-22.5 .. +27.5` `Stealing.cs:340-343` | identical `Stealing.cs:313-316` | **same** |
| Stealable-artifact gate | `si != null && Stealing.Value < 100.0` → `1060025` `Stealing.cs:265-268` | same `Stealing.cs:231-235` | **same** |
| Flag bookkeeping on success | `ItemFlags.SetTaken/SetStealable`, `stolen.Movable = true` `Stealing.cs:372-374` | **absent** (only `si.Item = null`) `Stealing.cs:322-331` | **different (XmlSpawner decoupled)** |
| `AddonComponent` handling | converts to `addon.Deed` `Stealing.cs:433-438` | **absent** | ModernUO removed |
| **Caught chance** | FillableContainer `Random((int)(Stealing/2.5)) == 0`; else `Stealing < Random(150)` `Stealing.cs:354-361` | **always** `Stealing < Random(150)` `Stealing.cs:337` | **ModernUO dropped the 1/48 branch** |
| Caught-message audience | radius **8** colleagues, `"You notice {0} trying to steal from {1}."` `Stealing.cs:470-478` | same `Stealing.cs:401-409` | **same** |
| Karma on steal | **none** | `Titles.AwardKarma(from, -50, true)` executed **unconditionally** `Stealing.cs:372` | **different** |
| Young-player restrictions | none | `502700` (thief Young), `502699` (victim Young) `Stealing.cs:107-122` | ModernUO only |
| Safe-zone block | none | `Region.IsPartOf<SafeZone>()` → `"You may not steal in this area."` `Stealing.cs:57-60,103-106` | ModernUO only |
| Locked-container check | none | `IsInLockedContainer` → `501747` `Stealing.cs:48-49,255-258` | ModernUO only |
| `StolenItem.StealTime` | `2.0 min` `Stealing.cs:540` | `2.0 min` `Stealing.cs:437` | **same** |
| `ExpireCriminalDelay` | `TimeSpan.FromMinutes(2.0)` `Server/Mobile.cs:2102` | `TimeSpan.FromMinutes(2.0)` `Projects/Server/Mobiles/Mobile.cs:1813` | **same** |
| `Hidden` setter side effects | forces `Warmode=false` / `Combatant=null` `Server/Mobile.cs:8963-8973` | **none** — only `OnHiddenChanged()` `Projects/Server/Mobiles/Mobile.cs:1249-1262` | **different** |
| `RevealingAction` | clears `m_IsStealthing` `Server/Mobile.cs:7160` | no such field on `Mobile`; `PlayerMobile.RevealingAction` clears `IsStealthing` `Projects/UOContent/Mobiles/PlayerMobile.cs:1592-1604` | **moved** |
| `OnMove` step decrement | `m_AllowedStealthSteps-- <= 0 \|\| (d & Direction.Running) != 0 \|\| Mounted` `Server/Mobile.cs:3044-3050` | identical `Projects/Server/Mobiles/Mobile.cs:4116-4127` | **same** |
| Player step engine | `if (!Core.SE) return base.OnMove(d);` then `Stealth.Value >= 25.0`, running `-= 2`, walk `Stealth.OnUse(this)` `PlayerMobile.cs:5431-5480` | identical incl. the `!Core.SE` early-out `Projects/UOContent/Mobiles/PlayerMobile.cs:3408-3445` | **same** |
| Passive Detect Hidden | time-sliced 2 s from PlayerMobile, radius 4, `Random(1000) < (ss-ts)+1`, elf `+20` inside loop, **no `Hidden` test** `DetectHidden.cs:140-185`, `PlayerMobile.cs:2095-2099` | new `TryDetectStealther` — **Felucca-only**, `Random(21)-10` variance on both sides, `ss >= ts` ⇒ reveal, party/guild/alliance exclusions, 3 s debounce, **no elf bonus**, triggered from `OnMovement` `Projects/UOContent/Mobiles/PlayerMobile.cs:3447-3464`, `DetectHidden.cs:61-128` | **substantially different** |
| Active Detect Hidden range | `Math.Max(2, (int)(Value/10.0))`, halved on failed check, `22` in a friend's house `DetectHidden.cs:64-75` | `(int)(Value/10.0)` (**no `Math.Max(2,…)`**), halved on failure, `22` in house `DetectHidden.cs:145-186` | **different floor** |
| Active Detect Hidden extras | mobiles + `IRevealableItem`s; `CanDetect` incl. Felucca rule `DetectHidden.cs:187-209` | adds direct container targeting `[trapped]` `500813`, faction traps (`80..100`), `BaseTrap` reveal gated on `Core.HS && skill >= 75.0`, 10 s re-hide timer, no `CanDetect` `DetectHidden.cs:147-253` | **different** |
| Detect Hidden cooldowns | `10.0 s` (`DetectHidden.cs:40`) | `30.0 s` on use, then 10 s after target `DetectHidden.cs:35,262-265` | **different** |
| Forensics: corpse | pre-gate `30.0`; `CheckTargetSkill(30.0, 55.0)` `ForensicEval.cs:42-52` | **no pre-gate**; `CheckTargetSkill(0.0, 100.0)` `ForensicEval.cs:54` | **different** |
| Forensics: mobile | pre-gate `36.0`; `CheckTargetSkill(36.0, 100.0)` `ForensicEval.cs:90-94` | **no pre-gate**; `CheckTargetSkill(40.0, 100.0)` `ForensicEval.cs:36` | **different** |
| Forensics: lock | pre-gate `41.0`; `CheckTargetSkill(41.0, 100.0)` `ForensicEval.cs:112-116` | **no skill check at all** `ForensicEval.cs:107-117` | **different** |
| Tracking range | `10 + (int)(Tracking.Value / 10)` ⇒ 10–20 `Tracking.cs:191` | `10 + (int)Tracking.Value / 10 * 10` ⇒ 10–110 tiles `Tracking/Tracking.cs:166` | **different by 10×** |
| Tracking difficulty | `chance > Utility.Random(100)` `Tracking.cs:272` | `chance >= 100 \|\| chance > Utility.Random(100)` `Tracking/Tracking.cs:354` | **equivalent at 100** |
| Tracking hidden filter | `!m.Hidden \|\| m.IsPlayer() \|\| from.AccessLevel > m.AccessLevel` `Tracking.cs:199` | `m.Hidden && m.AccessLevel != Player && from.AccessLevel <= m.AccessLevel` ⇒ skip `Tracking/Tracking.cs:247` | **equivalent for players** |
| Remove Trap window | `TrapPower .. TrapPower + 10` `RemoveTrap.cs:111` | `TrapPower .. TrapPower + 30` `RemoveTrap.cs:61` | **different** |
| Remove Trap prereqs | gated on `!Core.EJ`, `502366`/`502367` `RemoveTrap.cs:29-36` | **not gated** `RemoveTrap.cs:17-24` | **different** |
| Notoriety hues | `{0x000,0x059,0x03F,0x3B2,0x3B2,0x090,0x022,0x035}` `Server/Notoriety.cs:17` and `NotorietyHandlers` `Scripts/Misc/Notoriety.cs:25-31` | identical values `Projects/UOContent/Misc/Notoriety.cs:18-24` | **same** |
| Skill-check roll | `Random(100) <= (int)(chance*100)` `Scripts/Misc/SkillCheck.cs:245` | `chance >= Utility.RandomDouble()` `Projects/UOContent/Skills/SkillCheck.cs:115` | **different (see 5.0)** |

### 5.7 Clone-implementation table — every number a clone must reproduce

`S` = ServUO pub57 value (authoritative for this clone), `M` = ModernUO value, `[ERA]` = expansion gate.

| # | Constant | Value | Gate | Src |
|---|---|---|---|---|
| 1 | Hiding skill id / callback slot | `21` | — | `Hiding.cs:23` |
| 2 | Hiding busy (spell) message | `501238` | — | `Hiding.cs:30` |
| 3 | Hiding busy cooldown | `1.0 s` | — | `Hiding.cs:31` |
| 4 | Hiding under ManaSpike cooldown (silent) | `1.0 s` | VvV | `Hiding.cs:36` |
| 5 | Cancel current target on hide | yes | `Core.ML` | `Hiding.cs:39-42` |
| 6 | Hiding house-friend bonus | `100.0` | — | `Hiding.cs:50` |
| 7 | Hiding adjacent-house bonus | `50.0` | `!Core.AOS` `[ERA]` | `Hiding.cs:67` |
| 8 | House probe offsets / height | `(x±1,y,127)`, `(x,y±1,127)`, range `16` | `!Core.AOS` | `Hiding.cs:55-64` |
| 9 | Hiding skill clamp | `Math.Min(100, (int)Hiding.Value)` | — | `Hiding.cs:71` |
| 10 | Hiding watch range formula | `Math.Min((int)((100-skill)/2) + 8, 18)` | — | `Hiding.cs:72` |
| 11 | Hiding watch range at GM | `8` tiles | — | derived |
| 12 | Hiding check window | `0.0 - bonus .. 100.0 - bonus` | — | `Hiding.cs:96` |
| 13 | Hiding watched messages | `501237` (hue `0x22`) | — | `Hiding.cs:103` |
| 14 | Hiding watched cooldown | `TimeSpan.Zero` | — | `Hiding.cs:105` |
| 15 | Hiding success message / hue | `501240` / `0x1F4` | — | `Hiding.cs:116` |
| 16 | Hiding failure message / hue | `501241` / `0x22` | — | `Hiding.cs:122` |
| 17 | Hiding cooldown (success **and** failure) | `10.0 s` | — | `Hiding.cs:125` |
| 18 | Hiding success clears invis timers | `Sixth.InvisibilitySpell.RemoveTimer` + `Items.InvisibilityPotion.RemoveTimer` | — | `Hiding.cs:114-115` |
| 19 | `Hidden=true` ⇒ step pool | `0` | — | `Mobile.cs:8982` |
| 20 | `Hidden=true` ⇒ warmode/combatant | `Warmode=false` else `Combatant=null` | — | `Mobile.cs:8963-8973` |
| 21 | Hiding buff | `BuffIcon.HidingAndOrStealth`, cliloc `1075655` | — | `PlayerMobile.cs:1747` |
| 22 | Stealth hiding requirement | `30.0` / `50.0` / `80.0` | ML / SE / else `[ERA]` | `Stealth.cs:28` |
| 23 | Stealth already-hidden message | `502725` | — | `Stealth.cs:74` |
| 24 | Stealth flying message | `1113415` | — | `Stealth.cs:78` |
| 25 | Stealth requirement message | `502726` | — | `Stealth.cs:84` |
| 26 | Stealth busy message | `1063086` | — | `Stealth.cs:90` |
| 27 | Stealth armor cap | `42` / `26` | AoS / else | `Stealth.cs:98` |
| 28 | Stealth armor-cap message | `502727` | — | `Stealth.cs:100` |
| 29 | Stealth check window | `-20.0 + AR*2 .. (60.0\|80.0) + AR*2` | AoS / else | `Stealth.cs:104` |
| 30 | Stealth steps | `(int)(Stealth.Value / (5.0\|10.0))`, min `1` | AoS / else | `Stealth.cs:106-109` |
| 31 | Stealth success message | `502730` | — | `Stealth.cs:115` |
| 32 | Stealth failure message | `502731` | — | `Stealth.cs:122` |
| 33 | Stealth cooldown (all branches) | `10.0 s` | — | `Stealth.cs:118,128` |
| 34 | Step decrement condition | `--AllowedStealthSteps <= 0 \|\| Running \|\| Mounted` | — | `Mobile.cs:3046` |
| 35 | Player auto-stealth threshold | `Stealth.Value >= 25.0 && !Mounted` | `Core.SE` | `PlayerMobile.cs:5450` |
| 36 | Running step cost | `-2` | `Core.SE` | `PlayerMobile.cs:5456` |
| 37 | Exhausted walk behaviour | re-call `Stealth.OnUse(this)` | `Core.SE` | `PlayerMobile.cs:5463` |
| 38 | Stealthing consumers require | `Hidden && AllowedStealthSteps > 0` | Ninjitsu | `Backstab.cs:49` etc. |
| 39 | Snooping range | `1` tile (`500446` otherwise) | — | `Snooping.cs:42,96` |
| 40 | Snooping staff-container message | `500209` | — | `Snooping.cs:54` |
| 41 | Snooping illegal-target message | `1001018` | — | `Snooping.cs:60` |
| 42 | Snooping victim-notify roll | `Snooping.Value < Utility.Random(100)` | — | `Snooping.cs:64` |
| 43 | Snooping victim-notify text/hue | `"You notice {0} peeking into your belongings!"`, hue `946`, font `3`, `AsciiMessage` | — | `Snooping.cs:70-72` |
| 44 | Snooping karma delta | `-4` (title award, always) | — | `Snooping.cs:77` |
| 45 | Snooping check window | `0.0 .. 100.0` | — | `Snooping.cs:79` |
| 46 | Snooping fail message | `500210` | — | `Snooping.cs:88` |
| 47 | Snooping fail-reveal roll | `Hiding.Value / 2 < Utility.Random(100)` | — | `Snooping.cs:90` |
| 48 | Snooping criminal flag | **none** | — | (absent) |
| 49 | Stealing skill id / slot | `33` | — | `Stealing.cs:25` |
| 50 | Stealing target range | `1` (`base(1,false,TargetFlags.None)`, `AllowNonlocal`) | — | `Stealing.cs:48,52` |
| 51 | Stealing use message / cooldown | `502698` / `10.0 s` | — | `Stealing.cs:523,526` |
| 52 | Empty-hands requirement | `Layer.OneHanded` and `Layer.TwoHanded` both null | — | `Stealing.cs:497-510` |
| 53 | `1005584` both hands | yes | — | `Stealing.cs:69,516` |
| 54 | `1005596` thieves guild | required for player roots | — | `Stealing.cs:73` |
| 55 | `1005598` shopkeepers | `BaseVendor.IsInvulnerable` | — | `Stealing.cs:81` |
| 56 | `502709` PlayerVendor | yes | — | `Stealing.cs:85` |
| 57 | `500237` not visible | yes | — | `Stealing.cs:89` |
| 58 | `1048147` backpack full | `Backpack.CheckHold(m, item, false, true)` | — | `Stealing.cs:93` |
| 59 | Weight cap | `w = Weight + TotalWeight ; w > 10` → `"That is too heavy to steal."` | — | `Stealing.cs:289-293` |
| 60 | Stack `maxAmount` | `(int)((Stealing.Value / 10.0) / toSteal.Weight)`, clamp `[1, Amount]` | — | `Stealing.cs:299-308` |
| 61 | Stack amount roll | `Utility.RandomMinMax(1, maxAmount)` | — | `Stealing.cs:310` |
| 62 | Pile weight (full / partial) | `(int)Math.Ceiling(Weight * Amount) * 10` / `(int)Math.Ceiling(Weight * amount) * 10` | — | `Stealing.cs:314,324` |
| 63 | Non-stack item weight | `iw = (int)Math.Ceiling(w) * 10` | — | `Stealing.cs:340-341` |
| 64 | Stealing check window | `iw - 22.5 .. iw + 27.5` (`+22.5` margin, `50` span) | — | `Stealing.cs:317,327,343` |
| 65 | Partial-stack split | `Mobile.LiftItemDupe(toSteal, toSteal.Amount - amount)` | — | `Stealing.cs:329` |
| 66 | Non-movable / non-stealable → `502710` | unless `ItemFlags.GetStealable` | — | `Stealing.cs:249-252` |
| 67 | Newbied / blessed / insured → `502710` | `LootType.Newbied \|\| CheckBlessed(root)` unless flagged stealable | — | `Stealing.cs:253-256` |
| 68 | Containers → `502710` | `Core.AOS` only, unless flagged stealable | `[ERA]` | `Stealing.cs:257-260` |
| 69 | Adjacency → `502703` | `InRange(...,1)` | — | `Stealing.cs:263` |
| 70 | Artifact skill gate → `1060025` (hue `0x66D`) | `Stealing.Value < 100.0` when `si != null` | — | `Stealing.cs:267` |
| 71 | Equipped → `1005585` | `toSteal.Parent is Mobile` | — | `Stealing.cs:271` |
| 72 | Self → `502704` | `root == thief` | — | `Stealing.cs:275` |
| 73 | Staff root → `502710` | yes | — | `Stealing.cs:279` |
| 74 | `CanBeHarmful` false | **silent no-op** | — | `Stealing.cs:281-282` |
| 75 | Corpse root → `502710` | yes | — | `Stealing.cs:285` |
| 76 | Success → `502724` + `SetTaken(true)` + `SetStealable(false)` + `Movable = true` | yes | — | `Stealing.cs:370-374` |
| 77 | Fail → `502723` | yes | — | `Stealing.cs:386` |
| 78 | Caught (fillable container) | `Utility.Random((int)(Stealing.Value/2.5)) == 0` ⇒ `1/48` at 120 | — | `Stealing.cs:356` |
| 79 | Caught (other movable) | `Stealing.Value < Utility.Random(150)` ⇒ `(149-Stealing)/150` | — | `Stealing.cs:360` |
| 80 | Caught (non-movable, non-fillable) | `false` | — | `Stealing.cs:365` |
| 81 | Bystander broadcast radius | `8` | — | `Stealing.cs:472` |
| 82 | Bystander text | `"You notice {0} trying to steal from {1}."` (thief, victim) | — | `Stealing.cs:470` |
| 83 | Criminal on caught, ground root | `CriminalAction(false)` | — | `Stealing.cs:455` |
| 84 | Criminal on caught, innocent player/NPC root | `CriminalAction(false)` when `!IsInGuild(root) && IsInnocentTo(thief, root)` | — | `Stealing.cs:465-468` |
| 85 | Criminal on looting a criminal corpse | `CriminalAction(false)` whether or not caught | — | `Stealing.cs:457-460,481-484` |
| 86 | `PermaFlags.Add(root)` | player root + innocent + `!IsInGuild(root)` (dead code: `ClassicMode == false`) | — | `Stealing.cs:486-493` |
| 87 | Criminal flag duration | `2.0 minutes`, restarted on every new flag | — | `Server/Mobile.cs:2102,11827-11839` |
| 88 | Criminal notoriety value / hue | `4` / `0x3B2` | — | `Server/Notoriety.cs:10,17`; `Scripts/Misc/Notoriety.cs:28` |
| 89 | Criminal-action message (never sent by stealing) | `1005040` | — | `Server/Region.cs:912` |
| 90 | Guard-candidate delay before guards may be called | `15.0 s` | — | `GuardedRegion.cs:452` |
| 91 | Guard-candidate announce / expiry | `502275` / `502276` | — | `GuardedRegion.cs:269,465` |
| 92 | Fake guard call radius / lines | `8` tiles / `1007037, 501603, 1013037-1013043, 1013052` | — | `GuardedRegion.cs:278,299` |
| 93 | `*guards*` keyword / call radius | `0x0007` / `14` tiles | — | `GuardedRegion.cs:192,322` |
| 94 | Guard reuse radius | `8` tiles, else spawn `WarriorGuard` (`ArcherGuard` on Ilshenar/Malas) | — | `GuardedRegion.cs:127,65-78` |
| 95 | `AllowReds` (reds auto-flagged on entry/sight) | `Core.AOS` | `[ERA]` | `GuardedRegion.cs:63,169-172` |
| 96 | Aggression guard radius | `12` tiles | — | `GuardedRegion.cs:202` |
| 97 | Detect Hidden prompt / cooldown | `500819` / `10.0 s` | — | `DetectHidden.cs:37,40` |
| 98 | Detect Hidden target range | `12` | — | `DetectHidden.cs:46` |
| 99 | Detect Hidden search radius | `Math.Max(2, (int)(DetectHidden.Value / 10.0))` | — | `DetectHidden.cs:65` |
| 100 | Failed-check radius penalty | `range /= 2` | — | `DetectHidden.cs:67-68` |
| 101 | Friend-of-house radius | `22` | — | `DetectHidden.cs:75` |
| 102 | Active detection variance | `±10` via `Utility.Random(21) - 10` on **both** sides | — | `DetectHidden.cs:85-86` |
| 103 | Active detection success | `ss >= ts \|\| houseCheck`, plus `RandomDouble() > shadow` (Shadow mastery) and `CanDetect` | — | `DetectHidden.cs:90-94` |
| 104 | Reveal message to target | `500814`, overhead hue `0x3B2` | — | `DetectHidden.cs:97-98` |
| 105 | Nothing-found message | `500817` | — | `DetectHidden.cs:135` |
| 106 | Passive detect cadence / mobile radius | every `2 s` of movement / `4` tiles | — | `PlayerMobile.cs:2095-2099`, `DetectHidden.cs:150` |
| 107 | Passive target skill | `(Hiding.Value + Stealth.Value) / 2` | — | `DetectHidden.cs:160` |
| 108 | Elf passive bonus | `+20` to detector skill | — | `DetectHidden.cs:162-163` |
| 109 | Passive roll | `Utility.Random(1000) < (ss - ts) + 1` | — | `DetectHidden.cs:165` |
| 110 | Passive item radius / message | `8` tiles / `1153493` | — | `DetectHidden.cs:174-181` |
| 111 | Forensics callback / prompt / cooldown / target range | `19` / `501000` / `1.0 s` / `10` | — | `ForensicEval.cs:19,27,29,35` |
| 112 | Forensics corpse windows | pre-gate `30.0`; `CheckTargetSkill(30.0, 55.0)` | — | `ForensicEval.cs:42,52` |
| 113 | Forensics mobile windows | pre-gate `36.0`; `CheckTargetSkill(36.0, 100.0)`; thief → `501004` | — | `ForensicEval.cs:90,94,98` |
| 114 | Forensics lock windows | pre-gate `41.0`; `CheckTargetSkill(41.0, 100.0)`; `1042749` | — | `ForensicEval.cs:112,116,122` |
| 115 | Forensics SA item gate / messages | `41.0`; `1151521` at `Forensics.Value >= 61.0` else `1151522` | `Core.SA` | `ForensicEval.cs:142,159-165` |
| 116 | Tracking callback / prompt / cooldown | `38` / `1011350` / `10.0 s` | — | `Tracking.cs:17,22,28` |
| 117 | Tracking entry window / passive gain | `0.0 .. 21.1` / `21.1 .. 100.0` | — | `Tracking.cs:87,189` |
| 118 | Tracking search range | `10 + (int)(Tracking.Value / 10)` | — | `Tracking.cs:191` |
| 119 | Tracking PvP difficulty | `50 * (Tracking*2 + DetectHidden) / (Hiding + Stealth)` | `Core.SE` | `Tracking.cs:265` |
| 120 | Tracking elf divisor | `tracking /= 2` | `Core.ML` | `Tracking.cs:246-247` |
| 121 | Necromancy form modifiers | HorrificBeast `-200`; VampiricEmbrace `= 500` if `< 500`; WraithForm `+200` if `<= 2000` | — | `Tracking.cs:254-259` |
| 122 | Stalking bonus | `sqrt(dx²+dy²)`, capped at `10 + Tracking.Value/10` | `Core.ML` cap | `Tracking.cs:48-53` |
| 123 | Remove Trap callback / prereqs | `48`; Lockpicking `>= 50` else `502366`; DetectHidden `>= 50` else `502367` | `!Core.EJ` | `RemoveTrap.cs:24,29-36` |
| 124 | Remove Trap prompt / cooldown / range | `502368` / `10.0 s` / `2` | — | `RemoveTrap.cs:41,44,50` |
| 125 | Remove Trap window | `CheckTargetSkill(RemoveTrap, targ, TrapPower, TrapPower + 10)` | — | `RemoveTrap.cs:111` |
| 126 | Remove Trap success / fail | `502377` / `502372` | — | `RemoveTrap.cs:117,121` |
| 127 | Faction trap window | `RemoveTrap 80..100 && Tinkering 80..100` | — | `RemoveTrap.cs:148` |
| 128 | VvV trap chance / detonate | `(RemoveTrap.Value - 80.0)/20.0 > RandomDouble()`; detonate on `0.1 > RandomDouble()` | VvV | `RemoveTrap.cs:181,203` |
| 129 | Chest disarm windows | GM (100+): `80 .. 120 + Level*10`; else `min = ceil(RemoveTrap*0.75)`, `max = min > 50 ? min+50 : 100`; safety `20/60/180/420/540 s` by level | new treasure system | `RemoveTrap.cs:324-332,366,382-384` |
| 130 | Chest disarm timer / range | `10 s` repeat / `16` tiles | — | `RemoveTrap.cs:314,351` |
| 131 | Skill-check roll | `Utility.Random(100) <= (int)(chance * 100)` | — | `SkillCheck.cs:245` |
| 132 | Anti-macro allowance / window / tile size | `3` uses / `5 min` / `4` tiles | — | `SkillCheck.cs:28,33,38` |

### 5.8 Gaps / UNVERIFIED

| Gap | Why | What would resolve it |
|---|---|---|
| OSI's *real* stealing success formula | UOGuide documents a completely different, witness-based formula (`Difficulty = itemWeight * targetingFactor * 2000 / (100 + Stealing*10)`; `Percent Chance = (500 + 2*(Stealing*10 - Difficulty))/10`) — [UOGuide — Stealing](https://www.uoguide.com/Stealing). ServUO uses the flat `±22.5/27.5` window instead. **`[PARTIAL]`** | live-shard packet capture or Leurocian's original publish notes; the clone must state which formula it implements |
| ServUO `caught` probability fidelity | the `Stealing < Random(150)` literal is a ServUO/RunUO artefact with no OSI citation; no web source gives the witness-check constant | measure catch-rate over N=1000 steals at fixed skill/container |
| Exact `Utility.Random` implementation | `RandomImpl.Next` is abstracted (`Server/Utility.cs:921-924`); the concrete RNG is chosen at runtime | read the `RandomImpl` implementation actually compiled into the target build |
| `ShadowSpell.GetDifficultyFactor` constants | used by active Detect Hidden (`DetectHidden.cs:87`); not in the requested file set | read `Scripts/Spells/SkillMasteries/ShadowSpell.cs` |
| `Mobile.InsuranceEnabled` default | gates the "Insured ⇒ unstealable" branch (`Item.cs:6123`) | read the static initialiser / config |
| Hiding behaviour on *non-SE* shards | `PlayerMobile.OnMove` bypasses the step engine when `!Core.SE`, so `Mobile.OnMove` reveals at `AllowedStealthSteps <= 0` with no re-check | choose a target expansion; the clone's `[ERA]` decision determines which of the two step engines to port |
| Whether a clone needs the XmlSpawner `ItemFlags` | `Stealing.cs:249,253,257,372-373` depend on `Server.Items.ItemFlags` which lives in the XmlSpawner service, not `Server/` | decide whether to port `StealableFlag = 0x00200000` / `TakenFlag = 0x00100000` or drop those checks |
| Exact client-side stealth icon timing | client `ClassicUO` was not read for this section | read `.research-src\classicuo` for the buff-icon/step display logic |

## 6. Bard skills

Musicianship, Provocation, Discordance, Peacemaking, instruments (`BaseInstrument`), and the creature
barding-difficulty model, transcribed from ServUO `pub57` with ModernUO `main` diffs.

Citation shorthand used below: every `path:LINE` is a ServUO path relative to the repo root and maps to
`https://github.com/ServUO/ServUO/blob/pub57/<path>#L<LINE>`. `ModernUO:` paths are relative to `Projects/`
and map to `https://github.com/modernuo/ModernUO/blob/main/Projects/<path>#L<LINE>`.

### 6.1 Skill identities

| Skill | ID | SkillInfo title | Localization | Str/Dex/Int scale | GainFactor | Primary/Secondary | Mastery-capable |
|---|---|---|---|---|---|---|---|
| Peacemaking | 9 | Pacifier | 1044069 | 0 / 0 / 0 | 1.0 | Int / Dex | yes |
| Discordance | 15 | Demoralizer | 1044075 | 0 / 2.5 / 2.5 | 1.0 | Dex / Int | yes |
| Provocation | 22 | Rouser | 1044082 | 0 / 4.5 / 0.5 | 1.0 | Int / Dex | yes |
| Musicianship | 29 | Bard | 1044089 | 0 / 0 / 0 | 1.0 | Dex / Int | no |

- IDs: `Server/Skills.cs:39` (Peacemaking=9), `:45` (Discordance=15), `:52` (Provocation=22), `:59` (Musicianship=29).
- SkillInfo rows: `Server/Skills.cs:605` (Peacemaking), `:611` (Discordance), `:618` (Provocation), `:625` (Musicianship).
- `SkillInfo.Localization => 1044060 + SkillID` — `Server/Skills.cs:592`. Constructor `Server/Skills.cs:525-559`
  (the trailing `true` is the `mastery` flag, `:539`). Cross-check: the imbuing/loot property registry independently
  lists `SkillName.Musicianship, 1044089` (`Scripts/Services/LootGeneration/ItemPropertyInfo.cs:460`) and
  `Scripts/Services/Vendor Searching/VendorSearchCriteria.cs:211`.
- Bardic skill gump group: `Scripts/Gumps/SkillsGump.cs:438-444`.
- Client side has no bard logic at all: ClassicUO only enumerates the skill ids
  (`classicuo/src/ClassicUO.Assets/SkillsLoader.cs:101,114`) and exposes macro/hotkey entries
  (`HotkeysManager.cs:541,543`, `MacroManager.cs:2404,2406`). All bard rules are server-side.

**Skill `Value` used by every bard check** (`Server/Skills.cs:373-468`): `Value = clamp(Base + statOffset + skillMods, Cap)`
where `statOffset` is capped by `StatTotal * (100-Base)/100` (`:406-416`). Because all three scales are 0 for
Musicianship and Peacemaking, **Musicianship and Peacemaking `Value` == `Base` + item/bonus skill mods only**;
Discordance and Provocation get a small stat contribution (`StatTotal` 5.0 each, `Server/Skills.cs:558`).

**Skill-use plumbing** (`Server/Skills.cs:912-918`): a skill use is refused unless `Core.TickCount - NextSkillTime >= 0`;
on use, `NextSkillTime = Core.TickCount + (int)callback(from).TotalMilliseconds`. `Core.TickCount` is milliseconds
(`Server/Main.cs:98`, `(Stopwatch.GetTimestamp() - _TickOrigin) * 1000L / Stopwatch.Frequency`). Every "cooldown"
number below is therefore in **milliseconds**.

**Check semantics** (`Server/Misc/SkillCheck.cs:286-311`, dispatched by `Mobile.CheckTargetSkill`, `Server/Mobile.cs:12622-12631`):

```
value = Skills[skill].Value
if (value <  minSkill) return false;                       // "Too difficult"
if (value >= maxSkill) return true;                        // "No challenge"
chance = (value - minSkill) / (maxSkill - minSkill);
return CheckSkill(from, skill, target, chance);            // success = Utility.Random(100) <= (int)(chance*100)
```

All bard checks pass `minSkill = diff - 25.0`, `maxSkill = diff + 25.0`, so the arithmetic collapses to:

| Condition | Result |
|---|---|
| `skill < diff - 25` | automatic failure (0 %) |
| `diff - 25 <= skill < diff + 25` | `P(success) = (skill - (diff - 25)) / 50` |
| `skill >= diff + 25` | automatic success (100 %), and no skill gain (`Mobile_SkillCheckTarget` returns before `CheckSkill`) |

`[SRC]`. Note the exact-boundary quirk: at `skill == diff - 25` the code falls through to `chance = 0.0`, and
`Utility.Random(100) <= 0` is true 1 % of the time (`Server/Misc/SkillCheck.cs:245`), so the real "no chance"
floor is **`skill < diff - 25`**, one point lower. `[DERIVED from SRC]`

`[SRC+WEB]` UOGuide states the identical rule in prose: "If a bard's skill is 25 points below the Barding
Difficulty value, the bard has no chance of success. If a bard's skill is 25 points above the Barding Difficulty
value, the bard has 100% chance of success and cannot gain any skill points against that creature type."
— [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty)

### 6.2 MUSICIANSHIP

| Item | Value | Source |
|---|---|---|
| Gate formula | `return (m.Skills[Musicianship].Value / 100) > Utility.RandomDouble();` | `Scripts/Items/Equipment/Instruments/BaseInstrument.cs:708-713` |
| Gain call inside the gate | `m.CheckSkill(SkillName.Musicianship, 0.0, 120.0);` (always runs, before the roll) | `BaseInstrument.cs:710` |
| Implied pass probability | `Value / 100`, capped at 1.0 (any `Value >= 100.0` always passes) | `[DERIVED from SRC]` |
| Gate call sites | Provocation `Scripts/Skills/Provocation.cs:144`; Discordance `Scripts/Skills/Discordance.cs:195`; Peacemaking `Scripts/Skills/Peacemaking.cs:84,167` | — |
| Player-only guard | Provocation and Peacemaking guard the gate with `from.Player &&`; **Discordance does not** — any mobile (incl. NPC bards) must pass it | `Provocation.cs:144`, `Peacemaking.cs:84,167`, `Discordance.cs:195` |
| Second (difficulty) role | `music = from.Skills[Musicianship].Value`; if `music > 100.0` then `diff -= (music - 100.0) * 0.5` | `Provocation.cs:128,137-140`; `Discordance.cs:173,180-183`; `Peacemaking.cs:177,179-182` |
| Instrument double-click | `OnDoubleClick` → `SetInstrument` + 1000 ms `BeginAction(typeof(BaseInstrument))` lock → `CheckMusicianship` ? `PlayInstrumentWell` : `PlayInstrumentBadly` | `BaseInstrument.cs:682-706` |
| Non-bard use | Fire Horn success roll uses `Musicianship.Fixed`: `sucChance = 500 + (music - 775) * 2; dSucChance = sucChance / 1000.0` | `Scripts/Items/Equipment/Instruments/FireHorn.cs:50-55` |

`[SRC+WEB]` UOGuide: "It is required for any of the other Bard-related skills to even have a chance of success"
and "With 100.0 Musicianship, you will have a 100% chance to pass the first skill check when Provoking or
Peacemaking." — [UOGuide — Musicianship](https://www.uoguide.com/Musicianship),
[UOGuide — Provocation](https://www.uoguide.com/Provocation)

**Gating role summary** `[DERIVED from SRC]`: Musicianship is a *multiplicative* two-stage gate. Stage 1 is a flat
`Value/100` coin flip with no relation to the creature. Stage 2 subtracts `(music - 100) * 0.5` difficulty points
for every point of Musicianship above 100 — i.e. **+2 Musicianship above GM == -1 difficulty == +2 % success**
inside the ±25 window (`1 difficulty point = 1/50 = 2 %`).

**Instrument requirement.** No bard skill can run without a `BaseInstrument` in the user's backpack:

```
BaseInstrument.PickInstrument(m, OnPickedInstrument);      // Provocation.cs:24, Discordance.cs:47, Peacemaking.cs:23
```

| Step | Behaviour | Source |
|---|---|---|
| Cached instrument lookup | `m_Instruments[from]` hashtable, validated with `IsChildOf(from.Backpack)`; stale entry is dropped | `BaseInstrument.cs:278-294` |
| Nothing cached | `SendLocalizedMessage(500617)` "What instrument shall you play?" + `BeginTarget(1, false, TargetFlags.None, OnPickedInstrument)` — 1-tile target | `BaseInstrument.cs:301-315` |
| Target is not an instrument | `SendLocalizedMessage(500619)` "That is not a musical instrument." | `BaseInstrument.cs:317-334` |
| Instrument targeted | `SetInstrument(from, instrument)` then the callback fires | `BaseInstrument.cs:326-332` |
| Cursor still open on a real attempt | every handler re-validates `m_Instrument.IsChildOf(from.Backpack)`; if moved → `1062488` "The instrument you are trying to play is no longer in your backpack!" and the attempt aborts | `Provocation.cs:54,105`; `Discordance.cs:153`; `Peacemaking.cs:68` |
| Range to double-click / target an instrument | 1 tile (`OnDoubleClick`), 2 tiles (`InstrumentedAddonComponent`) | `BaseInstrument.cs:684`; `Scripts/Items/Addons/AddonComponent.cs:357` |

**Bard range literal** — one formula, used by all four skills and by NPC bards:

```
public static int GetBardRange(Mobile bard, SkillName skill)
{
    return 8 + (int)(bard.Skills[skill].Value / 15);
}
```
`BaseInstrument.cs:296-299`. `[DERIVED from SRC]`:

| Skill value of the skill being used | Target range (tiles) |
|---|---|
| 0.0 – 14.9 | 8 |
| 15.0 – 29.9 | 9 |
| 30.0 – 44.9 | 10 |
| 45.0 – 59.9 | 11 |
| 60.0 – 74.9 | 12 |
| 75.0 – 89.9 | 13 |
| 90.0 – 104.9 | 14 |
| 105.0 – 119.9 | 15 |
| 120.0 | 16 |

`[SRC+WEB]` UOGuide: "The base range of all bard abilities is 8 tiles, with each 15 points of skill in the
ability being used increasing this range by one tile." — [UOGuide — Discordance § Range](https://www.uoguide.com/Discordance#Range)

**Sounds.** Each instrument carries `SuccessSound` (`m_WellSound`) and `FailureSound` (`m_BadlySound`)
(`BaseInstrument.cs:16,23-47`), played via `PlayInstrumentWell` / `PlayInstrumentBadly`
(`BaseInstrument.cs:715-723`). `RandomInstrument()` picks one of three sound/art pairs (`BaseInstrument.cs:193-219`).
Full per-item table in §6.3.

**Timing / delay constants seen by the player:**

| Skill | Entered on skill use (callback return) | On instrument picked | On completion |
|---|---|---|---|
| Provocation | 1000 ms | unchanged | 10000 ms before the check; on musicianship or skill failure `10000 - ((masteryBonus/5)*1000)` ms | 
| Discordance | 1000 ms | 6000 ms | 1000 ms at target time; success `8000 - ((masteryBonus/5)*1000)` ms; failure 5000 ms |
| Peacemaking | 1000 ms | 21600000 ms (6 h — targeter lock) | cleared to `Core.TickCount` by `OnTargetFinish`; area success 5000 ms, area failure `10000 - ((masteryBonus/5)*1000)` ms; targeted success `5000 - ((masteryBonus/5)*1000)` ms, targeted failure `10000 - ((masteryBonus/5)*1000)` ms |

Sources: `Provocation.cs:20-27,125,146,157`; `Discordance.cs:43-58,151,288,303`; `Peacemaking.cs:19-34,52-58,90,98,102,170,193,200`.
`masteryBonus` is `0` for non-players and for players without a bard mastery (§6.13).
`OnTargetFinish` is invoked after a successful `Invoke` and on cancel/timeout — `Server/Targeting/Target.cs:143-149,152-162,276`.

**Message-id index (Musicianship/instrument layer):** 500617 (no instrument chosen), 500619 (not an instrument),
500446 (too far away), 500119 (must wait to perform another action), 502079 (instrument played its last tune),
500612 (you play poorly, no effect), 1070928 (Replenish Charges), 1060584 (uses remaining), 1060636 (exceptional),
1050043 (crafted by).

### 6.3 Instruments — full item table

All `BaseInstrument` subclasses share `InitMinUses = 350` / `InitMaxUses = 450` unless overridden
(`BaseInstrument.cs:122-135`), and `UsesRemaining = Utility.RandomMinMax(InitMinUses, InitMaxUses)` in the
constructor (`BaseInstrument.cs:472,481`).

| Class | File:LINE | ItemID | SuccessSound | FailureSound | Weight | Min/Max uses | Slayer | Era / craft gate |
|---|---|---|---|---|---|---|---|---|
| `Drums` | `Instruments/Drums.cs:9-12` | 0xE9C | 0x38 | 0x39 | 4.0 | 350/450 | none (craftable runic slayer) | classic |
| `Harp` (standing) | `Instruments/Harp.cs:9-12` | 0xEB1 | 0x43 | 0x44 | 35.0 | 350/450 | none | classic |
| `LapHarp` | `Instruments/LapHarp.cs:9-12` | 0xEB2 | 0x45 | 0x46 | 10.0 | 350/450 | none | classic |
| `Lute` | `Instruments/Lute.cs:9-12` | 0xEB3 | 0x4C | 0x4D | 5.0 | 350/450 | none | classic |
| `Tambourine` | `Instruments/Tambourine.cs:9-12` | 0xE9D | 0x52 | 0x53 | 1.0 | 350/450 | none | classic |
| `TambourineTassel` | `Instruments/TambourineTassel.cs:9-12` | 0xE9E | 0x52 | 0x53 | 1.0 | 350/450 | none | classic |
| `BambooFlute` | `Instruments/BambooFlute.cs:9-12` | 0x2805 | 0x504 | 0x503 | 2.0 | 350/450 | none | SE (`DefCarpentry.cs:596-600`) |
| `AudChar` | `Instruments/AudChar.cs:9-12` | 0x403B | 0x392 | 0x44 | 10.0 | 350/450 | none | SA (`DefCarpentry.cs:602-606`) |
| `SnakeCharmerFlute` (: `BambooFlute`) | `Instruments/SnakeCharmerFlute.cs:16-35` | 0x2805, hue 0x187 | 0x504 | 0x503 | 2.0 | **50/80** | none | SA (`DefCarpentry.cs:608-610`) |
| `DreadFlute` (artifact) | `Scripts/Items/Artifacts/Equipment/Instruments/DreadFlute.cs:10-16` | 0x315C/0x315D | 0x58B | 0x58C | 1.0 | **700/700**, `ReplenishesCharges`, 15 min/charge | none | ML-era artifact |
| `IolosLute` (: `Lute`, artifact) | `.../Instruments/IolosLute.cs:9-14` | 0xEB3, hue 0x47E | 0x4C | 0x4D | 5.0 | **1600/1600** | `Slayer = Silver`, `Slayer2 = Exorcism` | artifact |
| `GwennosHarp` (: `LapHarp`, artifact) | `.../Instruments/GwennosHarp.cs:9-14` | 0xEB2, hue 0x47E | 0x45 | 0x46 | 10.0 | **1600/1600** | `Slayer = Repond`, `Slayer2 = ReptilianDeath` | artifact |
| `FluteOfRenewal` (: `BambooFlute`, artifact) | `Scripts/Items/Artifacts/TOTLesserArtifacts.cs:1343-1379` | 0x2805 | 0x504 | 0x503 | 2.0 | **300/300**, `ReplenishesCharges` | `SlayerGroup.RandomSuperSlayerAOS()` (rolled at construction) | Tokuno lesser artifact |
| `CelloComponent` (addon) | `Instruments/Cello.cs:6-12` | 0x4C3E/0x4C3F | 0x66D | — (decor) | — | n/a | none | ThemePack.Kings |
| `TrumpetComponent` (addon) | `Instruments/Trumpet.cs:6-12` | 0x4C3C/0x4C3D | 0x66F | — | — | n/a | none | ThemePack.Kings |
| `CowBellComponent` (addon) | `Instruments/Cowbell.cs:6-12` | 0x4C5A/0x4C5B | 0x66E | — | — | n/a | none | ThemePack.Kings |
| `WallMountedBellSouth/East` (addon) | `Instruments/WallMountedBell.cs:42,100` | 0x4C5C / 0x4C5D | 0x66C | — | — | n/a | none | ThemePack.Kings |
| `FireHorn` (**not** a `BaseInstrument`) | `Instruments/FireHorn.cs:11-19` | 0xFC7, hue 0x466 | — | — | 1.0 | n/a (consumes sulfurous ash, breaks 1 % AoS / 16 % pre-AoS) | none | classic |

`InstrumentedAddonComponent` (`Scripts/Items/Addons/AddonComponent.cs:343-397`) is decorative-only: 2-tile reach,
1000 ms action lock, plays `SuccessSound`, no uses, no barding effect.

**Crafting / min Musicianship if coded.** Instruments are crafted by Carpentry under the group label 1044293.
The only Musicianship requirement is a **crafting skill requirement**, `AddSkill(index, SkillName.Musicianship, 45.0, 50.0)`,
i.e. 45.0 to attempt / 50.0 to craft at 100 % — **not** a playing requirement:

| Crafted item | Craft difficulty | Resources | Musicianship skill req | Source |
|---|---|---|---|---|
| LapHarp | 63.1 / 88.1 | 20 boards + 10 cloth | 45.0 / 50.0 | `Scripts/Services/Craft/DefCarpentry.cs:572-574` |
| Harp | 78.9 / 103.9 | 35 boards + 15 cloth | 45.0 / 50.0 | `DefCarpentry.cs:576-578` |
| Drums | 57.8 / 82.8 | 20 boards + 10 cloth | 45.0 / 50.0 | `DefCarpentry.cs:580-582` |
| Lute | 68.4 / 93.4 | 25 boards + 10 cloth | 45.0 / 50.0 | `DefCarpentry.cs:584-586` |
| Tambourine | 57.8 / 82.8 | 15 boards + 10 cloth | 45.0 / 50.0 | `DefCarpentry.cs:588-590` |
| TambourineTassel | 57.8 / 82.8 | 15 boards + 15 cloth | 45.0 / 50.0 | `DefCarpentry.cs:592-594` |
| BambooFlute (SE) | 80.0 / 105.0 | 15 boards | 45.0 / 50.0 | `DefCarpentry.cs:596-600` |
| AudChar (SA) | 78.9 / 103.9 | 35 boards + 3 granite | 45.0 / 50.0 | `DefCarpentry.cs:602-606` |
| SnakeCharmerFlute (SA) | 80.0 / 105.0 | 15 boards + 3 luminescent fungi | 45.0 / 50.0 | `DefCarpentry.cs:608-610` |
| CelloDeed (Kings) | 75.0 / 105.0 | 15 boards + 5 cloth | 45.0 / 50.0 | `DefCarpentry.cs:613-616` |
| TrumpetDeed (Kings) | 85.0 / 105.0 | 10 boards + 15 iron | 45.0 / 50.0 | `DefCarpentry.cs:628-631` |
| CowBellDeed (Kings) | 85.0 / 105.0 | 10 boards + 15 iron | 45.0 / 50.0 | `DefCarpentry.cs:633-636` |
| WallMountedBell S/E (Kings) | 75.0 / 105.0 | 50 boards + 50 iron | 45.0 / 50.0 | `DefCarpentry.cs:618-626` |

**No coded minimum Musicianship to *play* any instrument** — `BaseInstrument` has no per-item skill requirement
field, and `CheckMusicianship` is the only skill gate. `[SRC]`

**Loot-table instruments** (`Loot.RandomInstrument`, `Scripts/Misc/Loot.cs:915-923`): base set
`Drums, Harp, LapHarp, Lute, Tambourine, TambourineTassel` (`Loot.cs:235`), plus `BambooFlute` when `Core.SE`
(`Loot.cs:231,917-919`). `LootPack.Instruments` exposes the type as a random loot entry
(`Scripts/Misc/LootPack.cs:130`, dispatched at `:1026-1029`).

**Durability decrement and break message.**

```
public void ConsumeUse(Mobile from)
{
    if (UsesRemaining > 1) { --UsesRemaining; }
    else
    {
        if (from != null) from.SendLocalizedMessage(502079); // The instrument played its last tune.
        Delete();
    }
}
```
`BaseInstrument.cs:262-276`. Called on **every** bard attempt regardless of outcome — success, failure and
"played poorly" all consume a charge (`Provocation.cs:149,160,166`; `Discordance.cs:199,209,301`;
`Peacemaking.cs:88,96,104,172,191,198`). `UsesRemaining` getter calls `CheckReplenishUses()`
(`BaseInstrument.cs:146-158,221-241`): if `ReplenishesCharges` and `UsesRemaining < InitMaxUses`, each elapsed
`ChargeReplenishRate` (default 5 minutes, `:137-143`) adds `(int)(elapsed.Ticks / ChargeReplenishRate.Ticks)`
uses, capped at `InitMaxUses`.

Exceptional quality doubles the charge pool via `GetUsesScalar() == 200` and `ScaleUses`/`UnscaleUses`
(`BaseInstrument.cs:243-260,78-91`); the quality setter unscales then rescales so the percentage survives.

`SnakeCharmerFlute` uses a raw `UsesRemaining--` and its own break path (`SnakeCharmerFlute.cs:121-128`):
`1112177` "You broke your snake charmer flute." then `Delete()`; it does not go through `ConsumeUse`, so it never
prints 502079.

**Instrument effects on bard skills** — `BaseInstrument.GetDifficultyFor`:

| Modifier | Effect on `diff` | Comment in source | Net success-rate effect (±25 window) |
|---|---|---|---|
| `Quality == Exceptional` | `val -= 5.0` | `// 10%` | +10 % (`BaseInstrument.cs:418-419`) |
| `Slayer` present and `entry.Slays(targ)` | `val -= 10.0` | `// 20%` | +20 % (`:421-432`) |
| `Slayer` present and `entry.Group.OppositionSuperSlays(targ)` | `val += 10.0` | `// -20%` | −20 % (`:429-430`) |
| `Slayer2` identical logic | ±10.0 | `// 20%` / `// -20%` | ±20 % (`:434-445`) |
| No `Slayer`/`Slayer2` but a `SlayerSocket` on the item | same ±10.0 | `// 20%` | ±20 % (`:447-458`) |

`[SRC+WEB]` UOGuide matches: "A GM Carpenter created instrument adds 10% to your success chance.
A Slayer Instrument adds 20% to your success chance if the creature type matches, or removes 20% if it doesn't
match." — [UOGuide — Provocation](https://www.uoguide.com/Provocation)

Because the window is 50 points wide, `10 difficulty == 20 %` and `5 difficulty == 10 %` exactly. `[DERIVED from SRC]`
`SlayerSocket`-based slayers are attached at runtime (e.g. `TinctureOfSilver`, `Scripts/Services/Seasonal Events/TreasuresOfDoom/Items/TinctureOfSilver.cs:42`).

Instruments also serve as skill-bonus carriers for the bard skills, e.g. `SingingAxe` +5 Musicianship
(`Scripts/Items/Artifacts/Equipment/Weapons/SingingAxe.cs:11`), `SongWovenMantle` +10 Musicianship
(`Scripts/Items/Artifacts/Equipment/Armor/SongWovenMantle.cs:12`), and the bard skill-bonus pool for runic
crafting includes all four (`Scripts/Items/Tools/BaseRunicTool.cs:26-29`).

### 6.4 Creature barding difficulty — exact computation

Verbatim inner computation, `Scripts/Items/Equipment/Instruments/BaseInstrument.cs:374-412`:

```csharp
public static double GetBaseDifficulty(Mobile targ)
{
    /* Difficulty TODO: Add another 100 points for each of the following abilities:
    - Radiation or Aura Damage (Heat, Cold etc.)
    - Summoning Undead
    */
    double val = (targ.HitsMax * 1.6) + targ.StamMax + targ.ManaMax;

    val += targ.SkillsTotal / 10;

    BaseCreature bc = targ as BaseCreature;

    if (IsMageryCreature(bc))
        val += 100;

    if (IsFireBreathingCreature(bc))
        val += 100;

    if (IsPoisonImmune(bc))
        val += 100;

    if (targ is VampireBat || targ is VampireBatFamiliar)
        val += 100;

    val += GetPoisonLevel(bc) * 20;

    if (val > 700)
        val = 700 + (int)((val - 700) * (3.0 / 11));

    val /= 10;

    if (bc != null && bc.IsParagon)
        val += 40.0;

    if (Core.SE && val > MaxBardingDifficulty)
        val = MaxBardingDifficulty;

    return val;
}
```

Supporting predicates and the cap constant:

| Piece | Definition | Source |
|---|---|---|
| `MaxBardingDifficulty` | `public static readonly double MaxBardingDifficulty = 160.0;` | `BaseInstrument.cs:14` |
| `IsMageryCreature` | `bc != null && bc.AI == AIType.AI_Mage && bc.Skills[SkillName.Magery].Base > 5.0` | `BaseInstrument.cs:336-339` |
| `IsFireBreathingCreature` | `bc.AbilityProfile.HasAbility(SpecialAbility.DragonBreath)` | `BaseInstrument.cs:341-354` |
| `IsPoisonImmune` | `bc.PoisonImmune != null` | `BaseInstrument.cs:356-359` |
| `GetPoisonLevel` | `0` if `HitPoison == null`, else `HitPoison.Level + 1` | `BaseInstrument.cs:361-372` |
| `SkillsTotal` | `Skills.Total` = sum of `BaseFixedPoint` (10 × skill base), integer | `Server/Mobile.cs:1459`, `Server/Skills.cs:988` |
| Cache / accessor | `BaseCreature.BardingDifficulty => BaseInstrument.GetBaseDifficulty(this)` | `Scripts/Mobiles/Normal/BaseCreature.cs:587` |

**Order-of-operations facts that matter** `[SRC]`:
1. The `> 700` compression runs **before** `val /= 10` and **after** all +100 ability bonuses and the poison term.
   Raw inputs above 700 are compressed at `3/11 ≈ 0.2727` of the excess, so the model is very non-linear.
2. `targ.SkillsTotal / 10` is **integer division** (`int / int`), so a creature's total skill contributes
   `floor(SkillsTotal / 10)` = floor(sum of skill bases), truncating up to 0.9.
3. Paragon +40.0 is applied **after** `val /= 10`, so it is 40 difficulty points, not 4.
4. The 160 cap and everything downstream of it are `Core.SE`-gated (`Core.SE` is `Expansion >= Expansion.SE`,
   `Server/Main.cs:148`; expansion enum `Server/ExpansionInfo.cs:7-21`).
5. `[PARTIAL]` The source itself flags two unimplemented +100 abilities (radiation/aura damage, summoning undead,
   `BaseInstrument.cs:376-379`) — real OSI difficulty for such creatures is higher than this model returns.

**Public display of the value** (`Scripts/Skills/AnimalLore.cs`, shown only when `Core.AOS && Core.SE`):

```
double bd = Items.BaseInstrument.GetBaseDifficulty(c);
if (c.Uncalmable) bd = 0;
AddHtmlLocalized(153, 276, 160, 18, 1070793, LabelColor, false, false); // Barding Difficulty
AddHtml(320, y, 35, 18, FormatDouble(bd), false, false);
```
`AnimalLore.cs:228-235`. `FormatDouble(0)` renders `<div align=right>---</div>` (`AnimalLore.cs:150-156`).
`[SRC+WEB]` UOGuide: "If a creature is completely non-bardable, '---' will be the reported Barding Difficulty in
the Animal Lore gump." — [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty)

### 6.5 Difficulty → required player skill (arithmetic)

`[DERIVED from SRC]`. Let `D` = instrument-adjusted `GetDifficultyFor(target)` (§6.4 + §6.3 modifiers),
`M` = `Skills[Musicianship].Value`, `X` = bard mastery bonus (0, 5 or 10, §6.13), `S` = the bard skill's `Value`.

Per-skill `diff` construction (source lines cited in §6.6–6.8):

| Skill | `diff` before the ±25 window |
|---|---|
| Provocation (two creatures A,B) | `d0 = (D_A + D_B) * 0.5 - 5.0`; then `if (M > 100) d0 -= (M - 100) * 0.5`; then `if (X > 0) d0 -= d0 * (X / 100)` |
| Discordance | `d0 = D - 10.0`; then `if (M > 100) d0 -= (M - 100) * 0.5`; then `if (X > 0) d0 -= d0 * (X / 100)` |
| Peacemaking, targeted | `d0 = D - 10.0`; then `if (M > 100) d0 -= (M - 100) * 0.5`; then `if (X > 0) d0 -= d0 * (X / 100)` |
| Peacemaking, area (target self) | **no difficulty term at all** — `from.CheckSkill(SkillName.Peacemaking, 0.0, 120.0)` |

Resulting thresholds (`P` = the bard skill):

| Threshold | Provocation | Discordance / targeted Peacemaking |
|---|---|---|
| 0 % (auto-fail) below | `P < d0 - 25` | `P < d0 - 25` |
| 50 % at | `P = d0` | `P = d0` |
| 100 % (auto-success) at | `P >= d0 + 25` | `P >= d0 + 25` |

With `M = 100`, `X = 0`, no slayer and normal quality, and two identical creatures of difficulty `D`:
Provocation 50 % at `D - 5`, Discordance/targeted Peacemaking 50 % at `D - 10` — a fixed **5-point asymmetry**
caused solely by `Provocation.cs:127` subtracting `5.0`. `[DERIVED from SRC]`

Range/`mastery` notation: with `M >= 100`, define `Mh = (M - 100) * 0.5` and `k = 1 - X/100`:

| Skill | `d0` closed form (identical Provocation targets) |
|---|---|
| Provocation | `k * (D - 5 - Mh)` |
| Discordance / targeted Peacemaking | `k * (D - 10 - Mh)` |

Example at the 120 skill/skill cap with `M = 120` (`Mh = 10`), `X = 10` (`k = 0.9`), `D = 160` (SE cap):
Provocation `d0 = 0.9 * (160 - 15) = 130.5` → 50 % needs 130.5 (unreachable), at `P = 120` chance
`= (120 - (130.5 - 25)) / 50 = 14.5 / 50 = 29.0 %`. Discordance `d0 = 0.9 * (160 - 20) = 126.0` →
at `P = 120` chance `= (120 - 101)/50 = 38.0 %`, 50 % at 126.0. `[DERIVED from SRC]`

Reachable ceiling without masteries `[DERIVED from SRC]` — with `P = 120`, `M = 100`, `X = 0`:
Provocation auto-fails when `120 < (D - 5) - 25`, i.e. from `D = 151` upward, so `D = 150` is the highest
difficulty with any chance at all and only via the 1 % floor quirk (chance computes to exactly 0.0);
guaranteed success (`P >= d0 + 25`) needs `D <= 100`. For Discordance/targeted Peacemaking the same arithmetic
gives auto-fail from `D = 156` (`120 < (D - 10) - 25`), so `D = 155` is the last chance at all, and guaranteed
success needs `D <= 105`. With `M = 120` (`Mh = 10`) both boundaries move out by 10 (`D <= 160` never auto-fails:
`120 >= (D - 15) - 25` holds for every `D <= 160`).

`[WEB]` UOGuide frames the same model as: the value "indicates the skill level that a Bard must have for a 50 %
chance of success versus the creature in question", with ±25 the no-chance/100 %-chance edges
([UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty)). The ±25 edges match the code exactly.
The *50 % point* does not: code needs `P = D - 5` for Provocation and `P = D - 10` for Discordance/Peacemaking,
so the code is 5 respectively 10 skill points **more generous** than the published reading of the value.
`[SRC]` vs `[WEB]`

### 6.6 PROVOCATION

Dispatch: `SkillInfo.Table[(int)SkillName.Provocation].Callback = OnUse;` (`Scripts/Skills/Provocation.cs:17`).

**Two-target requirements**, in evaluation order:

| # | Requirement | Failure message | Source |
|---|---|---|---|
| 1 | First target must be a `BaseCreature` and `from.CanBeHarmful(target, true)` | 501589 "You can't incite that!" | `Provocation.cs:50,77` |
| 2 | Instrument still in the bard's backpack | 1062488 | `:54-57` |
| 3 | Player bards cannot provoke a `Controlled` creature | 501590 "They are too loyal to their master to be provoked." | `:58-61` |
| 4 | Not (`creature.IsParagon && GetBaseDifficulty(creature) >= 160.0`) | 1049446 "You have no chance of provoking those creatures." | `:62-65` |
| 5 | On success of step 4: play well + 1008085, second cursor opens | — | `:69-72` |
| 6 | Second target must be a `BaseCreature`, **or** the *bard* is a `BaseCreature` with `CanProvoke` (NPC bards) | 501589 | `:98-99,192` |
| 7 | Instrument still in backpack | 1062488 | `:105-108` |
| 8 | First creature `!Unprovokable` | 1049446 | `:109-112` |
| 9 | Second creature `!Unprovokable`, unless it is a `DemonKnight` or a quest target | 1049446 | `:113-116` |
| 10 | Same `Map` and `m_Creature.InRange(target, GetBardRange(from, Provocation))` | 1049450 "The creatures you are trying to provoke are too far away from each other for your music to have an effect." | `:117-122` |
| 11 | First creature != second creature | 501593 "You can't tell someone to attack themselves!" | `:123,185-188` |
| 12 | `questTargets \|\| (CanBeHarmful(first,true) && CanBeHarmful(second,true))` | silent no-op if false | `:142` |

Both `Target` instances use `BaseInstrument.GetBardRange(from, SkillName.Provocation)` — 8–16 tiles by
Provocation skill (`Provocation.cs:41,88`). Note requirement 10 measures **creature-to-creature** distance with the
same range, so the two targets must be within 8–16 tiles *of each other*, not of the bard. `[SRC]`

`questTargets` (`Provocation.cs:196-217`): true only when the *first* creature is a `Rabbit` or `JackRabbit`, the
second is a `WanderingHealer` or `EvilWanderingHealer`, and the bard is a `PlayerMobile` whose quest target has no
player master. It bypasses `Unprovokable` (req. 9) and `CanBeHarmful` (req. 12), then updates
`IndoctrinationOfABattleRouserQuest` objectives (`:169-180`).

**Difficulty formula** — verbatim, `Provocation.cs:123-161`:

```csharp
else if (m_Creature != target)
{
    from.NextSkillTime = Core.TickCount + 10000;

    double diff = ((m_Instrument.GetDifficultyFor(m_Creature) + m_Instrument.GetDifficultyFor(target)) * 0.5) - 5.0;
    double music = from.Skills[SkillName.Musicianship].Value;
    int masteryBonus = 0;

    if (from is PlayerMobile)
        masteryBonus = Spells.SkillMasteries.BardSpell.GetMasteryBonus((PlayerMobile)from, SkillName.Provocation);

    if (masteryBonus > 0)
        diff -= (diff * ((double)masteryBonus / 100));

    if (music > 100.0)
    {
        diff -= (music - 100.0) * 0.5;
    }

    if (questTargets || (from.CanBeHarmful(m_Creature, true) && from.CanBeHarmful(target, true)))
    {
        if (from.Player && !BaseInstrument.CheckMusicianship(from))
        {
            from.NextSkillTime = Core.TickCount + (10000 - ((masteryBonus / 5) * 1000));
            from.SendLocalizedMessage(500612); // You play poorly, and there is no effect.
            m_Instrument.PlayInstrumentBadly(from);
            m_Instrument.ConsumeUse(from);
        }
        else
        {
            if (!from.CheckTargetSkill(SkillName.Provocation, target, diff - 25.0, diff + 25.0))
            {
                from.NextSkillTime = Core.TickCount + (10000 - ((masteryBonus / 5) * 1000));
                from.SendLocalizedMessage(501599); // Your music fails to incite enough anger.
                m_Instrument.PlayInstrumentBadly(from);
                m_Instrument.ConsumeUse(from);
            }
            else
            {
                from.SendLocalizedMessage(501602); // Your music succeeds, as you start a fight.
                m_Instrument.PlayInstrumentWell(from);
                m_Instrument.ConsumeUse(from);
                m_Creature.Provoke(from, target, true);
                ...
            }
        }
    }
}
```

Modifiers, in the order applied: instrument quality/slayer (§6.3) → average of the two creatures minus `5.0` →
mastery percentage discount (`diff -= diff * X/100`) → `(Musicianship - 100) * 0.5`. Then the ±25 window.

**Provoke state — who attacks whom** (`Scripts/Mobiles/Normal/BaseCreature.cs:7590-7637`):

```csharp
public void Provoke(Mobile master, Mobile target, bool bSuccess)
{
    BardProvoked = true;

    if (!Core.ML)
    {
        PublicOverheadMessage(MessageType.Emote, EmoteHue, false, "*looks furious*");
    }

    if (bSuccess)
    {
        PlaySound(GetIdleSound());

        BardMaster = master;
        BardTarget = target;
        Combatant = target;
        BardEndTime = DateTime.UtcNow + TimeSpan.FromSeconds(30.0);

        if (target is BaseCreature)
        {
            BaseCreature t = (BaseCreature)target;

            if (t.Unprovokable || (t.IsParagon && BaseInstrument.GetBaseDifficulty(t) >= 160.0))
            {
                return;
            }

            t.BardProvoked = true;
            t.BardMaster = master;
            t.BardTarget = this;
            t.Combatant = this;
            t.BardEndTime = DateTime.UtcNow + TimeSpan.FromSeconds(30.0);
        }
        else if (target is PlayerMobile)
        {
            ((PlayerMobile)target).Combatant = this;
            Combatant = target;
        }
    }
    else
    {
        PlaySound(GetAngerSound());
        BardMaster = master;
        BardTarget = target;
    }
}
```

- **Only `bSuccess == true` is ever called by the skill handler** — grep for `.Provoke(` finds exactly one call
  site, `Provocation.cs:167` with `true`. The `else` branch (anger sound, no combatant change) is unreachable
  from the skill. `[SRC]`
- State fields: `BardProvoked` / `BardPacified` / `BardMaster` / `BardTarget` / `BardEndTime`
  (`BaseCreature.cs:3774-3787`); backing fields `m_bBardProvoked`, `m_bBardPacified`, `m_bBardMaster`,
  `m_bBardTarget` (`BaseCreature.cs:283-286`).
- Damage credit: `GetDamageMaster` returns `m_bBardMaster` when the provoked creature's victim is `m_bBardTarget`
  (`BaseCreature.cs:7572-7588`), so kills made by the provoked creature are credited to the bard.
- AI drive: `BaseAI.DoBardProvoked` (`Scripts/Mobiles/AI/BaseAI.cs:2172-2209`) forcibly re-sets
  `Combatant = BardTarget` and `ActionType.Combat` every tick while the link holds.

**Duration.** Flat **30.0 seconds**, identical for every creature tier — **there is no per-tier provoke timer in
ServUO**. `[SRC]` `Provocation.cs` and `BaseCreature.Provoke` contain no difficulty-indexed duration table.
The 30 s expiry is not absolute, because `BaseAI.DoBardProvoked` only drops the link when **both** conditions hold
(`BaseAI.cs:2174-2185`):

```
DateTime.UtcNow >= m_Mobile.BardEndTime
  && (BardMaster == null || BardMaster.Deleted || BardMaster.Map != m_Mobile.Map
      || m_Mobile.GetDistanceToSqrt(BardMaster) > m_Mobile.RangePerception)
```

So after 30 s the creature keeps fighting the provoke target for as long as the bard stays alive, on the same map
and within `RangePerception` (`DefaultRangePerception = 16`, `BaseCreature.cs:2353,3466`; perception 10 is
auto-upgraded to 16 at `:2371-2373`). The link also drops if the `BardTarget` is null/deleted/off-map/out of
`RangePerception` (`BaseAI.cs:2188-2198`). `[SRC+WEB]` UOGuide: "Once two creatures are fighting each other, they
will continue to do so until either the provoking bard leaves their line of sight or one is killed."
— [UOGuide — Provocation](https://www.uoguide.com/Provocation)

**Duration scaling.** None in code: no term in the 30.0 s constant depends on skill, difficulty or mastery.
`[UNVERIFIED]` — a per-tier or skill-scaled provoke duration would have to be introduced deliberately; to confirm
what OSI did, measure the time-to-reset on a live shard against creatures of several barding difficulties.

**Failure consequences — does the creature attack the bard?** `[SRC]` **No.** The failure path
(`Provocation.cs:155-161`) sends 501599, plays the failure sound, consumes a charge, and sets the cooldown. It does
**not** set `Combatant`, does **not** call `DoHarmful`, and does **not** call `Provoke(..., false)`. `[WEB]`
UOGuide claims the opposite — "Beware that if you fail the monsters will look for a new target, you." — so on this
point the published prose and ServUO `pub57` **disagree**; a faithful clone must pick one.
Revealing behaviour: every provocation step calls `from.RevealingAction()` (`Provocation.cs:22,31,48,68,96`), so a
hidden bard is exposed by the attempt.

**Immunity flags** (`BaseCreature.cs:1040-1043`):

```csharp
public virtual bool BardImmune     { get { return false; } }
public virtual bool Unprovokable   { get { return BardImmune || m_IsDeadPet; } }
public virtual bool Uncalmable     { get { return BardImmune || m_IsDeadPet; } }
public virtual bool AreaPeaceImmune{ get { return BardImmune || m_IsDeadPet; } }
```

Note the naming trap: the skill code checks `Unprovokable` (spelled without the second "o"), not `Unprovokeable`.
A grep of `Scripts/` for the whole immunity/difficulty flag family
(`BardImmune|Unprovokeable|Unprovokable|Uncalmable|BardPacified|AreaPeaceImmune|BardingDifficulty|GetBardingDifficulty`)
returns **129 matches across 60+ files**; selected overrides:

| Creature | Declaration | Source |
|---|---|---|
| `BaseVendor` | `BardImmune => true` | `Scripts/Mobiles/NPCs/BaseVendor.cs:56` |
| `BaseFamiliar` | `BardImmune => true` | `Scripts/Mobiles/Summons/BaseFamiliar.cs:49` |
| `OrderGuard`, `ChaosGuard`, `BaseFactionGuard` | `BardImmune => true` | `NPCs/OrderGuard.cs:47`, `NPCs/ChaosGuard.cs:47`, `Services/Factions/Mobiles/Guards/BaseFactionGuard.cs:49` |
| `Golem`, `Vollem` | `BardImmune => !Core.AOS \|\| !Controlled` / `!Core.AOS \|\| Controlled` | `Normal/Golem.cs:131`, `NPCs/Vollem.cs:52` |
| `VorpalBunny`, `Betrayer`, `Juggernaut`, `OrcBrute`, `BogThing`, `WhippingVine`, `StoneMonster`, `KhaldunRevenant` | `BardImmune => !Core.AOS` | `Normal/VorpalBunny.cs:62`, `Normal/Betrayer.cs:70`, `Normal/Juggernaut.cs:66`, `Normal/OrcBrute.cs:63`, `Normal/BogThing.cs:59`, `Normal/WhippingVine.cs:64`, `Normal/StoneMonster.cs:211`, `Normal/KhaldunRevenant.cs:83` |
| `TheButcher`, `DemonicJailor` | `BardImmune => !Core.SE` / `AreaPeaceImmune => Core.SE` | `Normal/TheButcher.cs:62,64`, `Services/Revamped Dungeons/WrongDungeon/Mobile/DemonicJailor.cs:159,161` |
| `Barracoon`, `LordOaks`, `Neira`, `CrimsonDragon` | `BardImmune` + `Uncalmable` overrides | `Bosses/Barracoon.cs:126,147`, `Bosses/LordOaks.cs:118,132`, `Bosses/Neira.cs:120,134`, `Bosses/CrimsonDragon.cs:76,98` |
| `Medusa`, `PumpkinHead`, `Meraktus`, `Ilhenir`, `StygianDragon` (`BardImmune => false`), `Revenant`, `Ronin`, `EliteNinja` | explicit overrides | `Bosses/Medusa.cs:91`, `Event/PumpkinHead.cs:58,60`, `Named/Meraktus.cs:247,261`, `Named/Ilhenir.cs:120`, `Bosses/StygianDragon.cs:90`, `Normal/Revenant.cs:78`, `Normal/Ronin.cs:102`, `Normal/EliteNinja.cs:118` |
| `Vasanord`, `ExodusSentinel`, `ExodusDrone`, `ExodusJuggernaut` | `BardImmune => !Core.AOS` | `Void Creatures/Vasanord.cs:68`; `Services/Revamped Dungeons/TheExodusEncounter/Mobiles/ExodusSentinel.cs:72`, `ExodusDrone.cs:71`, `ExodusJuggernaut.cs:71` |
| `DemonKnight` | `BardImmune` + `AreaPeaceImmune`, but explicitly exempted from the req. 9 second-target check | `Normal/DemonKnight.cs:79,93`; `Provocation.cs:113` |

Practical consequence `[DERIVED from SRC]`: a `BardImmune` creature is `Unprovokable`, `Uncalmable` **and**
`AreaPeaceImmune` by default, i.e. blanket bard immunity across all three skills unless the subclass overrides one
of the three individually.

**Provocation message table:**

| ID | Text | Trigger | Line |
|---|---|---|---|
| 501587 | Whom do you wish to incite? | instrument picked | `:32` |
| 1062488 | The instrument you are trying to play is no longer in your backpack! | instrument moved | `:56,107` |
| 501589 | You can't incite that! | non-creature target | `:77,192` |
| 501590 | They are too loyal to their master to be provoked. | `creature.Controlled` | `:60` |
| 1049446 | You have no chance of provoking those creatures. | paragon ≥160, `Unprovokable` (either target) | `:64,111,115` |
| 1008085 | You play your music and your target becomes angered. Whom do you wish them to attack? | first target accepted | `:70` |
| 1049450 | The creatures you are trying to provoke are too far away from each other for your music to have an effect. | map/range check | `:120` |
| 501593 | You can't tell someone to attack themselves! | same creature twice | `:187` |
| 500612 | You play poorly, and there is no effect. | Musicianship gate failed | `:147` |
| 501599 | Your music fails to incite enough anger. | `CheckTargetSkill` failed | `:158` |
| 501602 | Your music succeeds, as you start a fight. | success | `:164` |
| (emote) | `*looks furious*` | `Provoke()` when `!Core.ML` | `BaseCreature.cs:7596` |

### 6.7 DISCORDANCE

Dispatch: `Scripts/Skills/Discordance.cs:40`. State table `m_Table` keyed by target (`:18`).

**Target requirements**, in order (`Discordance.cs:148-200`):

| # | Requirement | Failure message | Line |
|---|---|---|---|
| 1 | Instrument in backpack | 1062488 | `:153-156` |
| 2 | Target is a `Mobile` | 1049535 "A song of discord would have no effect on that." | `:311-314` |
| 3 | `targ != from` **and** `from.CanBeHarmful(targ, false)` **and** not (`targ is BaseCreature && BardImmune && ControlMaster != from`) | 1049535 | `:161-165` |
| 4 | Target not already in `m_Table` | 1049537 "Your target is already in discord." | `:166-169` |
| 5 | `!targ.Player` **or** the bard is a `BaseCreature` with `CanDiscord` (NPC bard) **or** `Core.EJ && both players && CanDiscordPVP(from)` | silent — falls to `PlayInstrumentBadly` only | `:170-171,306-309` |
| 6 | `!BaseInstrument.CheckMusicianship(from)` | 500612 | `:195-200` |
| 7 | `from.CheckTargetSkill(SkillName.Discordance, target, diff - 25.0, diff + 25.0)` | 1049540 "You attempt to disrupt your target, but fail." | `:201,295` |

`CanDiscordPVP(m)` returns true only if the player has no *other* live PvP discord debuff applied by them
(`Discordance.cs:317-320`) — i.e. one PvP discord per bard at a time. `Core.EJ` = Endless Journey,
`Server/Main.cs:153`.

**Difficulty + magnitude formula** — verbatim, `Discordance.cs:172-267`:

```csharp
double diff = m_Instrument.GetDifficultyFor(targ) - 10.0;
double music = from.Skills[SkillName.Musicianship].Value;

if (from is BaseCreature)
    music = 120.0;

int masteryBonus = 0;

if (music > 100.0)
{
    diff -= (music - 100.0) * 0.5;
}

if (from is PlayerMobile)
{
    masteryBonus = Spells.SkillMasteries.BardSpell.GetMasteryBonus((PlayerMobile)from, SkillName.Discordance);
}

if (masteryBonus > 0)
{
    diff -= (diff * ((double)masteryBonus / 100));
}

if (!BaseInstrument.CheckMusicianship(from)) { ... }
else if (from.CheckTargetSkill(SkillName.Discordance, target, diff - 25.0, diff + 25.0))
{
    ...
    ArrayList mods = new ArrayList();
    int effect;
    double scalar;

    if (Core.AOS)
    {
        double discord = from.Skills[SkillName.Discordance].Value;

        effect = (int)Math.Max(-28.0, (discord / -4.0));

        if (Core.SE && BaseInstrument.GetBaseDifficulty(targ) >= 160.0)
        {
            effect /= 2;
        }

        scalar = (double)effect / 100;

        mods.Add(new ResistanceMod(ResistanceType.Physical, effect));
        mods.Add(new ResistanceMod(ResistanceType.Fire, effect));
        mods.Add(new ResistanceMod(ResistanceType.Cold, effect));
        mods.Add(new ResistanceMod(ResistanceType.Poison, effect));
        mods.Add(new ResistanceMod(ResistanceType.Energy, effect));

        for (int i = 0; i < targ.Skills.Length; ++i)
        {
            if (targ.Skills[i].Value > 0)
            {
                mods.Add(new DefaultSkillMod((SkillName)i, true, targ.Skills[i].Value * scalar));
            }
        }
    }
    else
    {
        effect = (int)(from.Skills[SkillName.Discordance].Value / -5.0);
        scalar = effect * 0.01;

        mods.Add(new StatMod(StatType.Str, "DiscordanceStr", (int)(targ.RawStr * scalar), TimeSpan.Zero));
        mods.Add(new StatMod(StatType.Int, "DiscordanceInt", (int)(targ.RawInt * scalar), TimeSpan.Zero));
        mods.Add(new StatMod(StatType.Dex, "DiscordanceDex", (int)(targ.RawDex * scalar), TimeSpan.Zero));

        for (int i = 0; i < targ.Skills.Length; ++i)
        {
            if (targ.Skills[i].Value > 0)
            {
                mods.Add(new DefaultSkillMod((SkillName)i, true, Math.Max(100, targ.Skills[i].Value) * scalar));
            }
        }
    }

    info = new DiscordanceInfo(from, targ, Math.Abs(effect), mods);
    ...
}
```

NPC-bard special case: `if (from is BaseCreature) music = 120.0;` (`:175-176`) — creature bards always get the
maximum Musicianship scaler regardless of their actual Musicianship.

**Effect magnitude table** `[DERIVED from SRC]` — AoS branch, `effect = (int)Math.Max(-28.0, discord / -4.0)`:

| Discordance `Value` | ServUO AoS `effect` (= resistance penalty, = % skill penalty) | After `Core.SE` halving at difficulty ≥160 |
|---|---|---|
| 0 | 0 | 0 |
| 25 | −6 | −3 |
| 50 | −12 | −6 |
| 75 | −18 | −9 |
| 100 | −25 | −12 |
| 105 | −26 | −13 |
| 110 | −27 | −13 |
| 112 | **−28 (cap reached)** | −14 |
| 120 | −28 (cap) | −14 |

Non-AoS branch `[DERIVED from SRC]`, `effect = (int)(discord / -5.0)`: 25 → −5, 50 → −10, 100 → −20, 120 → −24;
and the skill penalty base is `Math.Max(100, targetSkillValue) * scalar`, i.e. **flat −20 points at 100 Discordance
for every skill at or below 100**, and −24 at 120. Stats use `RawStr/RawInt/RawDex * scalar`.

**Stacking rules** `[SRC]`:
- Only one discord per target: `m_Table.ContainsKey(targ)` blocks a second application with 1049537 (`:166-169`).
  The entry is only removed when the effect ends (`DiscordanceInfo.RemoveDiscord`, `:436-447`).
- The mods are applied by name-tagged `ResistanceMod` / `StatMod("DiscordanceStr"/"Int"/"Dex")` /
  `DefaultSkillMod(..., true, ...)` (relative) and removed symmetrically in `Clear()` (`:397-434`), so a second
  bard cannot overwrite an existing debuff.
- The `DefaultSkillMod` constructor argument `true` is the *relative* flag, so the skill penalty is a percentage
  of the target's current skill `Value`, not a flat subtraction (except in the pre-AoS branch where the base is
  floored at 100). `[SRC]` (`Discordance.cs:247,264`)
- AoS branch applies **resistances + skills only — no stats**. Pre-AoS applies **stats + skills — no resistances**.
  `[SRC]`. `[WEB]` UOGuide says "your target will lose a percentage of its skills and stats"
  ([UOGuide — Discordance](https://www.uoguide.com/Discordance)); that matches the pre-AoS branch, not the AoS one.

**Duration / timer table:**

| Quantity | Value | Source |
|---|---|---|
| Tick period | `Timer.DelayCall(TimeSpan.Zero, TimeSpan.FromSeconds(1.25), ProcessDiscordance, info)` — every 1.25 s, first tick immediately | `Discordance.cs:285` |
| Grace period after break conditions appear | 15 seconds, set once at first detection (`info.m_Ending = true; info.m_EndTime = UtcNow + 15 s`) | `:122-126` |
| Actual end | first tick at/after that 15 s deadline → `RemoveDiscord` → `RemoveEffects` | `:116-119,436-447` |
| Effective end delay | 15.0 – 16.25 s after conditions break `[DERIVED from SRC]` | `:116-126,285` |
| Cancellation window | if conditions are restored before the 15 s elapse, `m_Ending = false; m_EndTime = UtcNow` and the effect continues | `:127-131` |
| While-active visual | `targ.FixedEffect(0x376A, 1, 32)` each tick | `:133` |
| Max duration | unbounded while the bard stays alive, unhidden, on the same map and within `GetBardRange(from, Discordance)` of the target | `:92-114` |
| PvP duration (`Core.EJ`, both players) | `6` seconds if `from.Skills.CurrentMastery == SkillName.Discordance`, else `4` seconds; `m_Expires` checked at the top of the tick | `:213-217,84-88,334,353-356` |

Break conditions (any one ends the effect after the 15 s grace, `Discordance.cs:92-114`):
`!targ.Alive`, `targ.Deleted`, `targ.IsDeadBondedPet`, `!from.Alive`, `from.Hidden`, `targ.Hidden`,
`from.IsDeadBondedPet`, `from.Map != targetMap`, `range > maxRange`. For a mounted target the distance is measured
from the **rider** (`:102-108`).
`[SRC+WEB]` source comment: "According to uoherald bard must remain alive, visible, and within range of the target
or the effect ends in 15 seconds." (`:90-91`); UOGuide says the effect ends if the bard "must remain alive, visible,
and within range of the target" ([UOGuide — Discordance § Continuation](https://www.uoguide.com/Discordance#Continuation)).

**PvP branch** (`Core.EJ`): no mods are applied at all. Instead `DiscordanceInfo.Apply()` strips AoS skill bonuses
from every item the target carries (`RunicReforging.GetAosSkillBonuses(item) → bonuses.Remove()`, `:361-374`), and
`Clear()` re-adds them (`:397-413`). Source comment: `// Pub 103 PVP Additions` (`:333`).

**Discordance message table:**

| ID | Text | Trigger | Line |
|---|---|---|---|
| 1049541 | Choose the target for your song of discordance. | instrument picked | `:55` |
| 1062488 | instrument no longer in backpack | `:155` |
| 1049535 | A song of discord would have no effect on that. | invalid mobile / self / `CanBeHarmful` false / `BardImmune` | `:164,313` |
| 1049537 | Your target is already in discord. | already in `m_Table` | `:168` |
| 500612 | You play poorly, and there is no effect. | Musicianship gate | `:197` |
| 1049539 | You play the song surpressing your targets strength *(sic)* | success | `:203` |
| 1072061 | You hear jarring music, suppressing your strength. | sent to a player target on success | `:206` |
| 1049540 | You attempt to disrupt your target, but fail. | `CheckTargetSkill` failed | `:295` |
| 1072064 | You hear jarring music, but it fails to disrupt you. | sent to a player target on failure | `:298` |

### 6.8 PEACEMAKING

Dispatch: `Scripts/Skills/Peacemaking.cs:16`. Two modes, chosen by what the cursor lands on: **target self =
area peace**, **target another mobile = targeted peace** (`:81` vs `:147-150`).

**Area radius literal.** `int range = BaseInstrument.GetBardRange(from, SkillName.Peacemaking);`
(`Peacemaking.cs:110`) → **8 + (int)(Peacemaking.Value / 15)** tiles, 8–16 (§6.2). The enumeration is
`from.GetMobilesInRange(range)` (`:113`), i.e. a circle of that radius centred on the bard.

**Target requirements and the check** — area mode (`Peacemaking.cs:84-102`):

```csharp
if (from.Player && !BaseInstrument.CheckMusicianship(from))      // 500612
else if (!from.CheckSkill(SkillName.Peacemaking, 0.0, 120.0))    // 500613 "You attempt to calm everyone, but fail."
else { /* success */ }
```

Area peace uses **no barding difficulty at all** — the check is `CheckSkill(Peacemaking, 0.0, 120.0)` in location
mode (`Server/Misc/SkillCheck.cs:134-158`): `value < 0` never happens, `value >= 120.0` is automatic success,
otherwise `chance = value / 120`. `[SRC]` This is why area peace can be trained on any creature and cannot be used
against high-difficulty creatures specifically.

Filter applied to each mobile in range (`Peacemaking.cs:117-121`) — skipped if:
`m is BaseCreature && Uncalmable`, or `m is BaseCreature && AreaPeaceImmune`, or `m == from`, or
`!from.CanBeHarmful(m, false)`. Everything else is affected: `calmed = true`, `m.SendLocalizedMessage(500616)`,
`m.Combatant = null`, `m.Warmode = false`, and **only if it is a `BaseCreature` and not already `BardPacified`**,
`Pacify(from, DateTime.UtcNow + TimeSpan.FromSeconds(1.0))` (`:125-132`). Area peace therefore gives creatures a
**flat 1.0-second** pacify flag while clearing combat for everyone in range (players included, subject to the
`CanBeHarmful` rules). `[SRC]`

Targeted mode (`Peacemaking.cs:152-246`):

| # | Requirement | Failure message | Line |
|---|---|---|---|
| 1 | `from.CanBeHarmful(targ, false)` | 1049528 "You cannot calm that!" (and skill time released) | `:152-156` |
| 2 | not (`targ is BaseCreature && Uncalmable`) | 1049526 "You have no chance of calming that creature." | `:157-161` |
| 3 | not (`targ is BaseCreature && BardPacified`) | 1049527 "That creature is already being calmed." | `:162-166` |
| 4 | `from.Player` → Musicianship gate | 500612, cooldown +5000 ms | `:167-173` |
| 5 | `from.CheckTargetSkill(SkillName.Peacemaking, targ, diff - 25.0, diff + 25.0)` | 1049531 "You attempt to calm your target, but fail." | `:187-194` |

```csharp
double diff = m_Instrument.GetDifficultyFor(targ) - 10.0;
double music = from.Skills[SkillName.Musicianship].Value;

if (music > 100.0)
{
    diff -= (music - 100.0) * 0.5;
}

if (masteryBonus > 0)
    diff -= (diff * ((double)masteryBonus / 100));
```
`Peacemaking.cs:176-185`. Identical shape to Discordance's difficulty, including the `- 10.0` offset and the
same ±25 window — **Provocation is the only one of the three with the extra `- 5.0` and the two-creature average.**

**Duration table.** `double seconds = 100 - (diff / 1.5);` clamped `> 120 → 120`, `< 10 → 10`
(`Peacemaking.cs:211-222`). `[DERIVED from SRC]` with `M = 100`, `X = 0`, normal instrument:

| Creature difficulty `D` | `diff = D - 10` | `seconds = 100 - diff/1.5` | Applied pacify |
|---|---|---|---|
| 0 | −10 | 106.67 | 106.67 s |
| 10 | 0 | 100.00 | 100.00 s |
| 25 | 15 | 90.00 | 90.00 s |
| 40 | 30 | 80.00 | 80.00 s |
| 55 | 45 | 70.00 | 70.00 s |
| 70 | 60 | 60.00 | 60.00 s |
| 85 | 75 | 50.00 | 50.00 s |
| 100 | 90 | 40.00 | 40.00 s |
| 115 | 105 | 30.00 | 30.00 s |
| 130 | 120 | 20.00 | 20.00 s |
| 145 | 135 | 10.00 | 10.00 s |
| 150 | 140 | 6.67 | **10.00 s (floor)** |
| 160 | 150 | 0.00 | **10.00 s (floor)** |

The 120-second ceiling is effectively unreachable in targeted mode: it needs `diff = -30`, but with `M >= 100`
and `X = 0` the minimum possible `diff` is `D - 10 >= -10` for a real creature (`[DERIVED from SRC]`).

**Failure / expiry consequences.**
- Failure: 1049531 + failure sound + one charge consumed (1049531 at `:189-191`); on an instrument-musicianship
  failure 500612 and a 5000 ms cooldown (`:169-172`).
- Expiry: pacified creatures are held by `BaseAI.DoBardPacified` (`Scripts/Mobiles/AI/BaseAI.cs:2155-2170`) — while
  `DateTime.UtcNow < BardEndTime` it clears `Combatant`/`Warmode` every tick; once past it, it sets
  `BardPacified = false`. `BaseAI` runs the pacify branch in preference to provoke and normal think
  (`BaseAI.cs:3095-3102`).
- Damage breaks pacification early: `if (BardPacified && (HitsMax - Hits) * 0.001 > Utility.RandomDouble()) Unpacify();`
  (`BaseCreature.cs:1979-1984`), and `Unpacify()` sets `BardEndTime = DateTime.UtcNow; BardPacified = false;`
  (`:1937-1941`). `[DERIVED from SRC]`: per-hit break probability = `(damage dealt / HitsMax) / 10` (e.g. a hit
  taking 20 % of max hits → 2 % chance).
- A pacified creature will not re-acquire a combatant: `else if (Combatant == null && !m_bBardPacified)`
  (`BaseCreature.cs:4539`).
- Pacified creatures still heal themselves: `if (Alive && !IsHealing && !BardPacified)` gates the healing tick
  (`BaseCreature.cs:6812`).
- Pacified creatures cannot use special abilities that require an un-pacified attacker
  (`Scripts/Services/Pet Training/SpecialAbility.cs:199`) and do not trigger area effects
  (`Services/Pet Training/AreaEffects.cs:65`).

**Immunity-after-peace rules.** There is no timed "immunity" window in ServUO. Instead:

| Rule | Mechanism | Source |
|---|---|---|
| Cannot re-peace an already-pacified creature | `BardPacified` flag → 1049527, target cursor released | `Peacemaking.cs:162-166` |
| Inherently immune creatures | `Uncalmable` → 1049526 | `Peacemaking.cs:157-161` |
| Area-peace immune (still targeted-peaceable if `Uncalmable` is false) | `AreaPeaceImmune`, skipped in the area loop | `Peacemaking.cs:118` |
| `Uncalmable => BardImmune \|\| m_IsDeadPet` by default | so `BardImmune` implies all three immunities | `BaseCreature.cs:1042-1043` |
| Peace is re-applicable immediately after expiry or damage-break | no cooldown flag beyond `BardPacified` | `BaseCreature.cs:1937-1941,1981-1984` |
| Taming a pacified creature (pre-SA only) | On an angering tame failure, `if (!Core.SA)`: with 76 % probability (`Utility.RandomDouble() > .24`) the pacify is re-applied 2 s later, otherwise `BardEndTime = DateTime.UtcNow`; `BardPacified` is set false either way | `Scripts/Skills/AnimalTaming.cs:212-224` |
| Peacemaking does not work in a guarded/safe zone | — ModernUO only, not in ServUO | `ModernUO:Projects/UOContent/Skills/Peacemaking.cs:56-63` |

**Peacemaking message table:**

| ID | Text | Trigger | Line |
|---|---|---|---|
| 1049525 | Whom do you wish to calm? | instrument picked | `:31` |
| 1049528 | You cannot calm that! | non-mobile target / `CanBeHarmful` false | `:66,154` |
| 1062488 | instrument no longer in backpack | `:70` |
| 500612 | You play poorly, and there is no effect. | Musicianship gate | `:86,169` |
| 500613 | You attempt to calm everyone, but fail. | area `CheckSkill` failed | `:94` |
| 1049648 | You play hypnotic music, but there is nothing in range for you to calm. | area success but `calmed == false` | `:138` |
| 500615 | You play your hypnotic music, stopping the battle. | area success | `:142` |
| 1049526 | You have no chance of calming that creature. | `Uncalmable` | `:159` |
| 1049527 | That creature is already being calmed. | `BardPacified` | `:164` |
| 1049531 | You attempt to calm your target, but fail. | targeted `CheckTargetSkill` failed | `:189` |
| 1049532 | You play hypnotic music, calming your target. | targeted success (creature and player branch) | `:206,239` |
| 500616 | You hear lovely music, and forget to continue battling! | sent to every mobile affected by area peace, and to a player targeted successfully | `:125,241` |

### 6.9 Difficulty tiers per bard skill `[DERIVED from SRC]`

Tables computed from the code arithmetic above (`M = 100` Musicianship, `X = 0` mastery, normal-quality
non-slayer instrument). "Difficulty `D`" is the `BaseInstrument.GetBaseDifficulty` output of the creature
(§6.4), capped at 160 when `Core.SE`. **These are derived from code, not published:**

| `D` | Provocation, 2 identical creatures: `diff` | Prov 0 % below | Prov 50 % at | Prov 100 % at | Discordance / targeted Peace: `diff` | Disc/Peace 0 % below | Disc/Peace 50 % at | Disc/Peace 100 % at |
|---|---|---|---|---|---|---|---|---|
| 10 | 5.0 | 0 | 5 | 30 | 0.0 | 0 | 0 | 25 |
| 20 | 15.0 | 0 | 15 | 40 | 10.0 | 0 | 10 | 35 |
| 30 | 25.0 | 0 | 25 | 50 | 20.0 | 0 | 20 | 45 |
| 40 | 35.0 | 10 | 35 | 60 | 30.0 | 5 | 30 | 55 |
| 50 | 45.0 | 20 | 45 | 70 | 40.0 | 15 | 40 | 65 |
| 60 | 55.0 | 30 | 55 | 80 | 50.0 | 25 | 50 | 75 |
| 70 | 65.0 | 40 | 65 | 90 | 60.0 | 35 | 60 | 85 |
| 80 | 75.0 | 50 | 75 | 100 | 70.0 | 45 | 70 | 95 |
| 90 | 85.0 | 60 | 85 | 110 | 80.0 | 55 | 80 | 105 |
| 100 | 95.0 | 70 | 95 | 120 | 90.0 | 65 | 90 | 115 |
| 110 | 105.0 | 80 | 105 | 130 | 100.0 | 75 | 100 | 125 |
| 120 | 115.0 | 90 | 115 | 140 | 110.0 | 85 | 110 | 135 |
| 130 | 125.0 | 100 | 125 | 150 | 120.0 | 95 | 120 | 145 |
| 140 | 135.0 | 110 | 135 | 160 | 130.0 | 105 | 130 | 155 |
| 150 | 145.0 | 120 | 145 | 170 | 140.0 | 115 | 140 | 165 |
| 160 | 155.0 | 130 | 155 | 180 | 150.0 | 125 | 150 | 175 |

Reading the table `[DERIVED from SRC]` (the "0 % below" column shows `0` whenever the auto-fail threshold
`diff - 25` falls at or below skill 0, i.e. every roll has at least the 1 % floor chance):
- At the classic 100.0 skill cap a bard can 100 %-provoke up to `D = 80` and has exactly a 50 % chance at `D = 105`
  (50 % is by definition `P = d0 = D - 5`).
- At the AoS/SE cap of 120.0 (no powerscrolls, no masteries) a bard can 100 %-provoke up to `D = 100` and
  100 %-discord up to `D = 105`; the 50 % points are `D = 125` (Provocation) and `D = 130` (Discordance/Peace).
- At `P = 120`, `M = 100` the last difficulty with any chance at all is `D = 150` for Provocation and `D = 155`
  for Discordance/targeted Peacemaking — and only through the 1 % floor.
- The `Core.SE` cap `D = 160` requires **155** Provocation (with `M = 100`) for a 50 % chance — unreachable without
  masteries, a +Musicianship bonus and/or a slayer instrument.
- Adding a matched slayer instrument (`diff -= 10`) shifts every "50 % at" and "100 % at" column 10 points down;
  adding 100→120 Musicianship (`Mh = 10`) shifts it another 10.

Area Peacemaking has a **single tier**: `CheckSkill(Peacemaking, 0.0, 120.0)` → `P = Value/120` regardless of `D`,
100 % at `Value >= 120.0`. `[DERIVED from SRC]`

Peacemaking targeted duration tiers (from §6.8, `M = 100`): `D <= 10` → ~100 s; `D = 70` → 60 s; `D = 100` → 40 s;
`D = 145` → 10 s; `D >= 145` → floored at 10 s. `[DERIVED from SRC]`

### 6.10 Published difficulty/tier references `[WEB]`

Kept strictly separate from §6.4–6.9. **UOGuide does not publish a per-creature difficulty number table**; the
numbers below are the only quantitative statements found:

| Claim | Value | Source |
|---|---|---|
| Meaning of the value | "the skill level that a Bard must have for a 50 % chance of success versus the creature in question" | [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) |
| No-chance edge | skill 25 below the value → no chance of success | [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) |
| 100 %-chance edge | skill 25 above the value → 100 % chance, no skill gain | [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) |
| Cap introduction | "In mid-January of 2005, via Publish 28 … Barding Difficulty was capped at 160." | [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) |
| Non-bardable display | "---" in the Animal Lore gump | [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) |
| Discordance magnitude | 50.0 skill → −12.5 %; 100.0 → −25 %; 120.0 → −28 %; difficulty 160 → halved (14 % at 120 discord) | [UOGuide — Discordance](https://www.uoguide.com/Discordance) |
| Discordance target class | "Does not affect player characters." | [UOGuide — Discordance](https://www.uoguide.com/Discordance) |
| Bard range | base 8 tiles, +1 tile per 15 points of the skill used | [UOGuide — Discordance § Range](https://www.uoguide.com/Discordance#Range) |
| Bard must stay in range | "the bard must remain alive, visible, and within range of the target or the effect ends" | [UOGuide — Discordance § Continuation](https://www.uoguide.com/Discordance#Continuation) |
| Provocation failure consequence | "if you fail the monsters will look for a new target, you" | [UOGuide — Provocation](https://www.uoguide.com/Provocation) |
| Instrument quality / slayer bonuses | GM-crafted +10 %; matching slayer +20 %; non-matching slayer −20 % | [UOGuide — Provocation](https://www.uoguide.com/Provocation) |
| Musicianship 100 → first check always passes | "With 100.0 Musicianship, you will have a 100 % chance to pass the first skill check when Provoking or Peacemaking." | [UOGuide — Provocation](https://www.uoguide.com/Provocation) |
| Area peace effect | "all aggression in the area will cease for a few moments. Players will have to re-attack their targets." | [UOGuide — Peacemaking](https://www.uoguide.com/Peacemaking) |
| Targeted peace break rule | "until a sufficient attack upon it breaks the trance or the bard loses line of sight for more than 10 seconds" | [UOGuide — Peacemaking](https://www.uoguide.com/Peacemaking) |
| Targeted peace era | "Targted Peacemaking was introduced with Publish 16." | [UOGuide — Peacemaking](https://www.uoguide.com/Peacemaking) |
| Instrument roster | Aud-Char, Bamboo Flute, Drum, Lap Harp, Lute, Standing Harp, Tambourine, Tambourine (tassel); artifacts Dread Flute, Flute of Renewal, Gwenno's Harp, Iolo's Lute; special Snake Charmer Flute | [UOGuide — Instrument](https://www.uoguide.com/Instrument) |
| Carpentry / Musicianship link | "A modest level of Musicianship is also required for a Carpenter to be able to produce musical instruments, which feature a 10 % success bonus over NPC-purchased instruments." | [UOGuide — Musicianship](https://www.uoguide.com/Musicianship) |

Discrepancies between §6.4–6.9 and §6.10, called out explicitly:

| Item | ServUO `pub57` `[SRC]` | UOGuide `[WEB]` |
|---|---|---|
| Discordance at 50 skill | −12 (12 %) | 12.5 % |
| Discordance at 100 skill | −25 (25 %) | 25 % — agrees |
| Discordance at 112–120 skill | −28 (cap reached at 112) | 28 % at 120 |
| Discordance affects stats on AoS | **no** — resistances + skills only | "skills and stats" |
| Discordance vs players | possible via `Core.EJ` PvP path (`Discordance.cs:170,213-217`) | "Does not affect player characters." |
| Peace break grace | 15 s (comment cites uoherald) | "more than 10 seconds" |
| Provocation failure aggro | no aggro change (`Provocation.cs:155-161`) | "the monsters will look for a new target, you" |
| Per-creature difficulty tier table | not published anywhere; must be derived per §6.4 | not published on UOGuide/Stratics |

`[UNVERIFIED]` — no published numeric per-creature barding-difficulty table was found on UOGuide for this section;
a table of per-creature values would have to be produced by running `GetBaseDifficulty` over each creature's
randomized stat ranges, or by reading the in-game Animal Lore gump for a spawn of each creature type.

### 6.11 Era notes `[ERA]`

| Feature | Era gate | Evidence |
|---|---|---|
| The four bard skills exist from classic (pre-AoS): ids 9 / 15 / 22 / 29 | classic | `Server/Skills.cs:39,45,52,59` |
| Instrument auto-double-click Musicianship roll + 1 s action lock | classic | `BaseInstrument.cs:682-706` |
| Discordance effect model switches wholesale on AoS | AoS | `Discordance.cs:224` (`if (Core.AOS)`) |
| Barding-difficulty cap of 160 | SE (`Core.SE`) in code; **Publish 28, mid-Jan 2005** per UOGuide | `BaseInstrument.cs:408-409`; [UOGuide — Barding Difficulty](https://www.uoguide.com/Barding_Difficulty) |
| Discordance halved against difficulty ≥160 | SE (`Core.SE`) in code | `Discordance.cs:230-233` |
| Barding Difficulty row visible in the Animal Lore gump | AoS **and** SE | `Scripts/Skills/AnimalLore.cs:224-238` |
| `*looks furious*` provoke emote removed | ML (`if (!Core.ML)`) | `BaseCreature.cs:7594-7597` |
| Bamboo Flute / SE instrument loot | SE | `Loot.cs:231,917-919`; `DefCarpentry.cs:596-600` |
| Aud-Char, Snake Charmer Flute | SA | `DefCarpentry.cs:602-611` |
| Cello / Trumpet / Cowbell / Wall-Mounted Bell (ThemePack.Kings) | ToL-era content pack | `DefCarpentry.cs:613-636`; `Server/ExpansionInfo.cs:23-29` |
| Taming a pacified creature preserves the pacify 76 % of the time | **removed** at SA (`if (!Core.SA)`) | `AnimalTaming.cs:212-224` |
| Discordance PvP (Pub 103) path | `Core.EJ` | `Discordance.cs:170,213-217,333` |
| Bard Masteries (six spells) | ML — see §6.13 | `Scripts/Spells/Skill Masteries/BardSpells/*` |
| `Unprovokable`/`Uncalmable`/`AreaPeaceImmune` `!Core.AOS` / `!Core.SE` flipping on many creatures | AoS / SE | e.g. `Normal/VorpalBunny.cs:62`, `Normal/Barracoon.cs`-equivalents `Bosses/Barracoon.cs:126,147` |

### 6.12 ModernUO constant diffs

Every difference found between ServUO `pub57` and ModernUO `main` for this subsystem:

| Topic | ServUO `pub57` | ModernUO `main` | ServUO line | ModernUO line |
|---|---|---|---|---|
| Instrument min/max uses | fixed `350` / `450` | `Core.UOR ? 350 : 100` / `Core.UOR ? 450 : 150` | `BaseInstrument.cs:122-135` | `ModernUO:.../Musical Instruments/BaseInstrument.cs:55-56` |
| Exceptional uses | `ScaleUses()` × 200 / 100 on the quality setter | `OnCraft` adds `+100` uses when `Core.LBR`, else `UsesRemaining * ((int)Quality - 1) * 0.1` | `BaseInstrument.cs:78-91,243-260,727-743` | `BaseInstrument.cs:118-144` |
| Instrument double-click lock | 1000 ms | 6000 ms ("Delay of 6 second before being able to play another instrument again") | `BaseInstrument.cs:692-695` | `BaseInstrument.cs:508-509` |
| Difficulty: HitsMax term | `HitsMax * 1.6` always | `HitsMax * (Core.LBR ? 1.6 : 0.625)` | `BaseInstrument.cs:380` | `BaseInstrument.cs:259` |
| Difficulty: skill term | `targ.SkillsTotal / 10` (integer division) | `targ.SkillsTotal / 10.0` (double) | `BaseInstrument.cs:382` | `BaseInstrument.cs:261` |
| Difficulty: `> 700` compression position | after the +100 ability bonuses and poison term | **before** the +100 ability bonuses and poison term | `BaseInstrument.cs:398-401` | `BaseInstrument.cs:263-266` |
| Difficulty: poison level | `HitPoison == null ? 0 : p.Level + 1` | `(bc?.HitPoison?.Level ?? -1) + 1` | `BaseInstrument.cs:361-372` | `BaseInstrument.cs:247` |
| Difficulty: 160 cap | `MaxBardingDifficulty` field (`:14`) | inline literal `160.0` | `BaseInstrument.cs:14,408-409` | `BaseInstrument.cs:299-302` |
| Difficulty: SlayerSocket fallback | present (`if both Slayer==None`, checks the item socket) | absent | `BaseInstrument.cs:447-458` | `BaseInstrument.cs:307-351` |
| `Quality` type | `ItemQuality` (shared enum) | dedicated `InstrumentQuality { Low, Regular, Exceptional }` | `BaseInstrument.cs:18,77-91` | `BaseInstrument.cs:13-18,86-99` |
| Provocation: innocent-target penalty | not present | `if (Notoriety.Compute(from, creature) == Notoriety.Innocent) { creature.Say(501591); Titles.AwardKarma(from, -75, true); }` | — | `Provocation.cs:55-61` |
| Provocation: second-target acceptance | `targeted is BaseCreature \|\| (from is BaseCreature && ((BaseCreature)from).CanProvoke)` | `targeted is BaseCreature` only (no NPC-bard path) | `Provocation.cs:98-99` | `Provocation.cs:106` |
| Provocation: second-target exemption | `creature.Unprovokable && !(creature is DemonKnight) && !questTargets` | `creature.Unprovokable && creature is not DemonKnight` (no quest targets) | `Provocation.cs:113` | `Provocation.cs:117` |
| Provocation: mastery bonus & quests | `BardSpell.GetMasteryBonus`, `IndoctrinationOfABattleRouserQuest` | absent | `Provocation.cs:129-135,169-180` | — |
| Provocation: failure cooldown | `10000 - ((masteryBonus/5)*1000)` ms | flat `5000` ms | `Provocation.cs:146,157` | `Provocation.cs:144,156` |
| Discordance: AoS magnitude | `effect = (int)Math.Max(-28.0, discord / -4.0)` | `if (discord > 100) effect = -20 + (int)((discord - 100) / -2.5); else effect = (int)(discord / -5.0);` | `Discordance.cs:228` | `Discordance.cs:181-188` |
| Discordance: NPC-bard music override | `if (from is BaseCreature) music = 120.0;` | absent | `Discordance.cs:175-176` | — |
| Discordance: skill-mod base | pre-AoS uses `Math.Max(100, targ.Skills[i].Value) * scalar` | `skill.Value * scalar` for both branches | `Discordance.cs:264` | `Discordance.cs:239` |
| Discordance: target gating | `!targ.Player \|\| (bard is BaseCreature && CanDiscord) \|\| (Core.EJ && PvP && CanDiscordPVP)` | `!targ.Player` only | `Discordance.cs:170` | `Discordance.cs:152` |
| Discordance: cooldown after the attempt | success `8000 - ((masteryBonus/5)*1000)`, failure `5000` | flat `12000` for both | `Discordance.cs:288,303` | `Discordance.cs:260` |
| Discordance: Pub 103 PvP branch | present (`Core.EJ`, `m_PVP`, 4/6 s, strips AoS skill bonuses) | absent | `Discordance.cs:213-217,333-374,397-413` | — |
| Discordance: end conditions | also checks `IsDeadBondedPet` (both), `targ.Hidden`, mount-rider distance | `!Alive`, `Deleted`, `!from.Alive`, `from.Hidden`, map, range | `Discordance.cs:92-114` | `Discordance.cs:54-67` |
| Peacemaking: targeter lock | `NextSkillTime = TickCount + 21600000` (6 h), released by `OnTargetFinish` | `+30000` (30 s), released by `OnTargetCancel` | `Peacemaking.cs:33,52-58` | `Peacemaking.cs:30,43-46` |
| Peacemaking: cooldowns | area success 5000; area fail `10000 - bonus`; targeted musicianship fail 5000; targeted skill fail `10000 - bonus`; targeted success `5000 - bonus` | area success 5000; area fail (from +10000 base) ; targeted musicianship fail 5000; targeted skill/success rely on the +10000 set at entry | `Peacemaking.cs:90,98,102,170,193,200` | `Peacemaking.cs:71,91,157,182` |
| Peacemaking: safe-zone block | absent | `from.Region.IsPartOf<SafeZone>()` / `targ.Region.IsPartOf<SafeZone>()` with custom messages | — | `Peacemaking.cs:56-63` |
| Peacemaking: mastery bonus / quests | `BardSpell.GetMasteryBonus`, `TheBeaconOfHarmonyQuest` | absent | `Peacemaking.cs:76-79,184-185`; `:224-235` | — |
| Creature-side NPC bard system | full region: `CanDiscord`/`CanPeace`/`CanProvoke`/`PlayInstrumentSound`, `DoDiscord`/`DoPeace`/`DoProvoke`, `CheckInstrument` (auto-creates an exceptional `Harp` with sounds 0x58B/0x58C), `GetBardTarget`, `GetSecondTarget`, random 5–12.5 s re-use windows, 33 % trigger chance per think | **entirely absent** — ModernUO has no `CanProvoke`/`CanPeace`/`CanDiscord`/`DoProvoke`/`DoPeace`/`DoDiscord` symbols | `BaseCreature.cs:7044-7256`, timers at `:7467-7481` | — (grep returns no matches) |
| `BaseCreature.Provoke` target branch | `else if (target is PlayerMobile)` also sets the player's `Combatant` | only `if (target is BaseCreature t)` | `BaseCreature.cs:7608-7628` | `BaseCreature.cs:4027-4040` |
| `GetDamageMaster` | uses `m_bBardProvoked && damagee == m_bBardTarget`, then `m_bControlled`/`m_bSummoned` | uses `BardProvoked && damagee == BardTarget`, then `GetMaster()` | `BaseCreature.cs:7572-7588` | `BaseCreature.cs:3992-4007` |
| Immunity flag backing field | `m_IsDeadPet` | `IsDeadPet` | `BaseCreature.cs:1041-1043` | `BaseCreature.cs:975-977` |
| `Uncalmable` exemption in the provoke second-target check | `DemonKnight` + mastery-quest targets | `DemonKnight` only | `Provocation.cs:113` | `Provocation.cs:117` |

ServUO-only NPC-bard timing literals (no ModernUO counterpart), for reference:
`DoDiscord` costs 25 mana and requires `MagicalAbility.Discordance` (`BaseCreature.cs:7067-7097`); the think loop
fires discord → peace → provoke in that priority at `0.33 > Utility.RandomDouble()` with
`m_NextX = tc + Utility.RandomMinMax(5000, 12500)` (`BaseCreature.cs:7467-7481`); `GetBardTarget(bool creaturesOnly)`
falls back to a random aggressor (`:7188-7220`); `GetSecondTarget(first)` picks a random harmful-capable mobile
within the provoke range of `first` (`:7227-7255`).

### 6.13 Bard Masteries `[ERA]` — Mondain's Legacy

`Scripts/Spells/Skill Masteries/BardSpells/` is ML content. It is the **only** place where the mastery bonus that
feeds §6.5 lives.

| Spell | Class | Cast skill | Required skill | Upkeep | Mana | Party effects | Slayer bonus |
|---|---|---|---|---|---|---|---|
| Inspire | `InspireSpell` | Provocation | 90 | 4 | 16 | yes | 1.5× |
| Invigorate | `InvigorateSpell` | Provocation | 90 | 5 | 22 | yes | 1.5× |
| Perseverance | `PerseveranceSpell` | Peacemaking | 90 | 5 | 18 | yes | 1.5× |
| Resilience | `ResilienceSpell` | Peacemaking | 90 | 4 | 16 | yes | 1.5× |
| Tribulation | `TribulationSpell` | Discordance | 90 | 10 | 24 | no | 1.5× |
| Despair | `DespairSpell` | Discordance | 90 | 12 | 26 | no | **3.0×** |

Sources: `BardSpell.cs:18,20-24`; `inspire.cs:20-24`; `invigorate.cs:27-31`; `Perseverance.cs:20-24`;
`Resilience.cs:20-24`; `Tribulation.cs:27-33`; `Despair.cs:23-28`.

**Mastery bonus used by the base bard skills** — `BardSpell.cs:131-142`:

```csharp
public static int GetMasteryBonus(PlayerMobile pm, SkillName useSkill)
{
    if (useSkill == pm.Skills.CurrentMastery)
        return 10;

    if (pm.Skills.CurrentMastery == SkillName.Provocation
        || pm.Skills.CurrentMastery == SkillName.Discordance
        || pm.Skills.CurrentMastery == SkillName.Peacemaking)
        return 5;

    return 0;
}
```

Effects on the base skills `[DERIVED from SRC]`: a mastery matching the skill being used reduces `diff` by
**10 %**; any other bard mastery reduces it by **5 %**; and the post-attempt cooldown is reduced by
`(masteryBonus / 5) * 1000` ms = **2000 ms** for a matching mastery, **1000 ms** for a non-matching one
(`Provocation.cs:135,146,157`; `Discordance.cs:192,288`; `Peacemaking.cs:79,90,98,193,200`).

Other ML-era facts: masteries require 90 skill (`SkillMasterySpell.cs:29`, `BardSpell.cs:20`), masteries cast with
`GetCastSkills(min = 90, max = 115)` (`BardSpell.cs:125-129`), the bard mastery quests require
`Musicianship >= 90` **and** the matching bard skill `>= 90`
(`Scripts/Quests/Bard Mastery Quests/SirHareus.cs:40` Provocation, `SirFelean.cs:40` Peacemaking,
`SirBerran.cs:38` Discordance), and `BardSpell.DamageSkill` is always Musicianship (`BardSpell.cs:64`).
`BaseSkillBonus = Math.Floor(2 + ((CastSkill.Base - 90)/10) + ((Musicianship.Base - 90)/10))` (`BardSpell.cs:26-32`).

### 6.14 Open items / `[UNVERIFIED]`

1. **Per-tier provoke duration.** ServUO has none — flat 30.0 s + bard-proximity continuation (§6.6). If OSI used
   a difficulty-scaled table, it is not in this source. Resolving it needs live-shard timing of
   time-to-reset across creatures of several `D` values, or a packet capture of the provoke effect.
2. **Published per-creature barding-difficulty table.** Not published on UOGuide for this section. A table would
   have to be generated from each creature's randomized stat range through §6.4 (or read from the Animal Lore gump).
3. **`Provoke` failure-aggro.** ServUO's failure path never aggros; UOGuide says it does (§6.6, §6.10). Which one
   shipped on OSI is unresolved from the code alone.
4. **AoS Discordance and stats.** ServUO's AoS branch does not debuff stats at all; UOGuide says stats and skills
   both drop. Confirming requires live measurement of a discorded creature's stat readout.
5. **Discordance 50-skill value.** ServUO computes −12, UOGuide states 12.5 %. Both are inside the same code path
   (`(int)` truncation of `-12.5`), so this is a rounding-visible difference rather than a formula difference.
6. **Peacemaking break grace.** Code uses 15 s, UOGuide says "more than 10 seconds". The 15 s is quoted in the
   source comment as coming from "uoherald", but the published page disagrees.
7. **Peacemaking targeter lock of 21600000 ms (6 h).** `[PARTIAL]` — it is released by `OnTargetFinish`, so the
   observable effect should be "no other skill while the peace target cursor is open". Whether the 6-hour value was
   ever observable (e.g. via a client that leaves the cursor open past a target timeout) was not measured.
8. **`MaxBardingDifficulty` reachability.** Paragon +40 is applied before the SE cap (`BaseInstrument.cs:405-410`),
   so a paragon of any creature with `D >= 120` is capped at 160 and becomes unprovokable by the paragon check in
   `Provocation.cs:62` (`GetBaseDifficulty >= 160.0`) — no measurement was done to confirm the in-game consequence.

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

## 8. Consolidated open questions (UNVERIFIED register + measurement plan)

Every row is something this dossier could **not** settle from code, published prose, or both. No number
in this document was invented; where a value is unknown it is marked `[UNVERIFIED]` in place and
repeated here with the measurement that would close it.

| # | Topic | What is unknown | Best available evidence | How to measure / resolve |
|---|---|---|---|---|
| 1 | Pre-SA skill slots | Did `skills.mul`/`skills.idx` carry 55 valid records, or 58 with three blank names? | Client loader is count-driven (`ClassicUO:Assets/SkillsLoader.cs:41-55`); SA added 55/56/57 | Dump a pre-2009-09-08 client's `skills.idx` (16-byte records) and count `length > 0` |
| 2 | Real client groups | `skillgrp.mul` group names/order (ClassicUO's lists are a fallback) | `SkillsGroupManager.cs:457-548` parser documented | Hexdump/parse a retail `skillgrp.mul`; read group id per skill index |
| 3 | `hasAction` byte per skill | Which skills the client marks clickable | Server side: 23 `Callback` registrations (§1.4) | Read byte 0 of each `skills.mul` entry |
| 4 | OSI barding difficulty per creature | ServUO's `GetBaseDifficulty` is a reconstruction | `BaseInstrument.cs:374-412`; wiki publishes scale + 160 cap only | Instrument a live client or read Animal Lore gumps per creature |
| 5 | Provocation failure aggro | ServUO never aggros on a failed provoke; UOGuide says it does | `Provocation.cs` has no `Provoke(..., false)` call site | Live-shard test: fail 100 provokes at 0 skill and record aggro |
| 6 | Per-tier provoke timers | ServUO uses a flat 30 s (+ perception continuation) | `BaseCreature.cs:7606,7622` | Compare against a live shard over many provokes/creature types |
| 7 | Stealing catch chance | `Stealing < Random(150)` has no OSI citation | `Stealing.cs` | N=1000 steal attempts at fixed skill/weight, record catch rate |
| 8 | OSI stealing difficulty formula | Wiki: `weight*targetingFactor*2000/(100+Stealing*10)`; ServUO: flat `±22.5/27.5` window | `Stealing.cs:315-343` vs [UOGuide — Stealing](https://www.uoguide.com/Stealing) | Live-shard success-rate sweep, or find the OSI formula in an archived Stratics essay |
| 9 | Stat-gain timer semantics per era | Three published answers (30 min/6 per day Publish 16; 15 min RoT; unlimited today) | `SkillCheck.cs:44-54`; config ships `EnablePlayerStatTimeDelay=false` | Set `EnablePlayerStatTimeDelay=true, PlayerStatTimeDelay=00:15:00` for classic-style behaviour; measure gains/hour |
| 10 | Anti-macro exhaustion feedback | Source sends **no** message when the 3-use allowance is spent | `PlayerMobile.cs:4441-4482`; `SkillCheck.cs:311-328` | Packet-capture a live/OSI client while macroing one spot |
| 11 | ServUO gain formula vs OSI | `GetGainChance` + `GGSTable` are RunUO-lineage, not a decompile | `SkillCheck.cs:241-264,760-768` | Statistical: N thousand attempts per skill band, compare gain/minute curves |
| 12 | GGS table typos | Rows 6 and 9, column 3 diverge from the published table (90 vs 72; 106 vs 108) | §7.4.1 | Decide per clone: published values or code values |
| 13 | Craft "Kindling" window | `DefBowFletching.cs:133` passes `0.0, 0.0` → division by zero in the ramp | `CraftItem.GetSuccessChance` ramp | Instrument `GetSuccessChance` at skill 0/50/100 for that recipe |
| 14 | Craft wall-clock delay | Derived from `base(1,1,1.25)` ticks; animations are commented out in source | `CraftSystem.cs`, `CraftGump.cs` | Time 100 crafts on a live shard with a stopwatch |
| 15 | Fixed arrow/bolt bundle size | ServUO computes `min(shafts, feathers)` at craft time; no constant exists | `DefBowFletching.cs` + `UseAllRes` | Client/vendor convention, or measure on a live shard |
| 16 | Glassblowing/sand-mining introduction | Base rows carry no `Core.*` gate; clilocs are in the 1044xxx block | §4c; [UOGuide — Glassblowing](https://www.uoguide.com/Glassblowing) | Read the uo.com publish archive for the SA-era publish that added sand mining |
| 17 | Cliloc English strings | No `cliloc.*` data file exists in any of the three checkouts | all message ids cited as numbers | Ship `Cliloc.enu`, or read from a client install |
| 18 | Casting fizzle curve | ServUO `(100/7)*circle - 20` vs ModernUO's `min..min+40` OSI table genuinely disagree (8th circle 80/120 vs 70/110) | §2b | Pick one, or measure fizzle rate per circle on a live shard |
| 19 | Eval Int → circle gating | **No such gate exists in ServUO** (gating is per-spell `GetCastSkills`); commonly repeated but false for this codebase | §2b | Client-side gump check or live test at low Eval Int |
| 20 | Swing-speed floor | Commonly claimed 0.25 s; source floor is the 1.25 s tick / 5 ticks | §2b `BaseWeapon.GetDelay` | Measure swing interval on a live shard with high SSI + stamina |
| 21 | `WeaponSpeed` > 60 clamp | Delay path caps at 60, but items exist with 75 | §2b | Instrument `GetDelay` with a 75-SSI item |
| 22 | Bandage heal table | The published UOGuide table fits `3+(H+A)/6 … 10+H/3+A/6`; neither code branch matches (AoS `A/8+H/5+4 … A/6+H/2.5+4`) | §7.4 row 32 | Decide which era curve the clone targets; measure live heals per (A,H) grid |
| 23 | Bandage interruption thresholds | 26 (monster) / 19 (player) thresholds not pinned to a code line (35 % penalty is) | §7.4 row 30 | Live test: take damage during a bandage and bisect the threshold |
| 24 | Discordance magnitude curve | Wiki 12.5/25/28 %; code has era-split tables and an int truncation (−12 at 50) | §6 | Live measurement of the debuff % per skill step |
| 25 | Peacemaking break grace | Code 15 s vs UOGuide "more than 10 seconds" | §6 | Live test with a stopwatch |
| 26 | Tracking tier numbers | UOGuide publishes none | `Tracking.cs` has the code table | Read the code table (§2) and verify radius in game |
| 27 | Animal Taming per-creature fail/anger probabilities | Not a constant in source | `AnimalTaming.cs` | N=200 tame attempts per creature type |
| 28 | Pet cap rules ("−10 % skill over 100", Dex cap 125) | `[WEB]` only, not verified in code this pass | [UOGuide — Animal Taming](https://www.uoguide.com/Animal_Taming) | Read `BaseCreature` taming/stat code paths |
| 29 | Strange source bugs | `TreasureMap.cs:951` missing `return`; `DefInscription.cs:459` double `DaemonBone`; two clilocs per type in one file | §4d | Decide per clone; test level-3 map decode at Cartography 10 (N=100) |
| 30 | Stratics prose | `uo.stratics.com` answers 403 to scripted fetches (5 URLs tried) | §7.9 | Fetch from a browser, or cite UOGuide mirrors |
| 31 | OSI vs ServUO min-skills in craft menus | Every table in §4b-4d is ServUO's numbers, not proven retail | `Def*.cs` | Live-shard comparison of the craft gump min-skill column |
| 32 | Insurance/Cursed/Blessed defaults for stealing | `Mobile.InsuranceEnabled` default not read in this pass | `Stealing.cs` body | Read the property + `Core.AOS` gate |

### 8.1 What is *not* in doubt (highest-confidence core, safe to implement first)

`[SRC]`/`[SRC+WEB]` constants that both code and published prose agree on: 58 dense skill ids; 700.0
total cap and 100.0 individual cap defaults; 105/110/115/120 power-scroll tiers; 225 stat cap with
125/150 per-stat caps; 0.1 skill-gain increment; the `GainFactor`-based gain-chance formula structure;
the 5 % / 75-25 stat-gain rule; the 15-minute (config-default) stat timer; 22/24 GGS cells; the bard
`±25` difficulty window and 8-tile + `skill/15` range; the 160 barding-difficulty cap; the stealth
`5 skill per step` rule (ML) and `stealth − 2·armorRating + 20` shape; bandage 60/60 cure and 80/80
resurrect gates; the crafting `min … min+50` gain window and the X+50 "no more gain" rule.

---
*End of document. Sections 1-8 + subsections 1b, 2b, 4b-4d as listed in the document map (§0.4).*