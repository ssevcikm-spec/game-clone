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
