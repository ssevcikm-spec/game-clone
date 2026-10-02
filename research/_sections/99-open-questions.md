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
