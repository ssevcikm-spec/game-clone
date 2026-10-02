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
