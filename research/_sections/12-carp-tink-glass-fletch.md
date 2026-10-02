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
