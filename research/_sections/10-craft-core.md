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
