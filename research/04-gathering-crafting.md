# 04 — Resource Gathering & Crafting (UO faithful-clone data tables)

**Purpose.** Directly implementable data tables + formulas for a single-player offline Ultima Online clone.
**Primary sources (all read from a local shallow clone of the repos, master branch, fetched 2026-02):**

| Source | URL | Local clone path used |
|---|---|---|
| ServUO | https://github.com/ServUO/ServUO | `C:\Users\Ssevc\AppData\Local\Temp\uo-src\ServUO` |
| ModernUO | https://github.com/modernuo/ModernUO | `C:\Users\Ssevc\AppData\Local\Temp\uo-src\ModernUO` |

Repo-relative paths in this document resolve against the ServUO clone unless prefixed with `ModernUO:`.
Every table row in §3–§5 was **machine-extracted** from the ServUO `Def*.cs` files with a parser (all 1056
`AddCraft(...)` entries, including follow-up `AddRes` / `AddSkill` / `AddRecipe` / `ForceNonExceptional` /
`SetUseAllRes` / `SetUseSubRes2` calls position-matched to their `AddCraft`). Nothing in the recipe tables is
hand-typed from memory.

**Era warning (read first).** ServUO master models the *modern* game (AoS → Time of Legends). A faithful
single-player clone of an early era must **filter by the `era` note column** (era tags come from the
`if (Core.XX)` guard that encloses the recipe in source). The pre-AoS/T2A shape of the craft UI and the T2A
category tree are documented in §5.0 from `ModernUO: dev-docs/t2a-crafting.md` and
`ModernUO: Projects/UOContent/Engines/Craft/T2A/*Menu.cs`, which contain literal (non-cliloc) menu strings.

**Cliloc caveat.** ServUO names items and gump categories by *cliloc number*, not text. This document shows
`⟨cliloc⟩` next to each resolved category name. Category names in `GROUP_NAMES` are either (a) taken from the
ModernUO T2A menu literals, or (b) inferred from the member items of the group — inferred ones are flagged in
§9. Item names are the server class names rendered as words (e.g. `RingmailGloves` → "Ringmail Gloves");
where the client display name differs, the cliloc number is the authority and is stated.

---

## 1. HARVESTING SYSTEMS

### 1.1 The harvest engine (exact algorithm)

Files: `Scripts/Services/Harvest/HarvestSystem.cs`, `Core/HarvestDefinition.cs`, `Core/HarvestBank.cs`,
`Core/HarvestVein.cs`, `Core/HarvestResource.cs`, `Core/HarvestTimer.cs`, `Core/HarvestSoundTimer.cs`,
`Core/HarvestTarget.cs`, `Core/BonusHarvestResource.cs`.

**Data model**

| Concept | Meaning | Key fields |
|---|---|---|
| `HarvestDefinition` | one harvestable resource system (ore+stone, sand, wood, fish) | `BankWidth/Height`, `MinTotal/MaxTotal`, `MinRespawn/MaxRespawn`, `Tiles`, `SpecialTiles`, `RangedTiles`, `MaxRange`, `ConsumedPerHarvest`, `ConsumedPerFeluccaHarvest`, `Skill`, `EffectActions/Sounds/Counts`, `EffectDelay`, `EffectSoundDelay`, `Resources[]`, `Veins[]`, `BonusResources[]`, `RaceBonus`, `RandomizeVeins` |
| `HarvestBank` | the finite pool of resource in one map cell | `Maximum = RandomMinMax(MinTotal, MaxTotal)`, `Current`, `Vein`, `NextRespawn` |
| `HarvestVein` | a weighted ore/wood type inside a bank | `VeinChance` (%), `ChanceToFallback` (0–1), `PrimaryResource`, `FallbackResource` |
| `HarvestResource` | one concrete resource type + its skill window | `ReqSkill`, `MinSkill`, `MaxSkill`, `Types[]`, `SuccessMessage` |
| `BonusHarvestResource` | rare side-drop | `ReqSkill`, `Chance` (%), `Type`, `RequiredMap` |

**Bucket / bank addressing** (`HarvestDefinition.GetBank`, `HarvestDefinition.cs`):
`bankX = floor(x / BankWidth)`, `bankY = floor(y / BankHeight)` → the whole bucket shares one
`Current` counter and one vein. Vein selection:

```
if (Veins.Length == 1) return Veins[0];
if (RandomizeVeins) r = RandomDouble();                    // ML+ ore & wood
else r = new Random(bx*17 + by*11 + map.MapID*3).NextDouble();   // deterministic per bucket, pre-ML
r *= 100; for each vein: if (r <= vein.VeinChance) return vein; r -= vein.VeinChance;
```

So **pre-ML (T2A/UOR) ore type is a deterministic function of the bucket coordinates** — the same hill
always gives the same metal, and it never rerolls. That is the classic "static ore locations" behaviour.

**Per-swing algorithm** (`HarvestSystem.OnHarvesting` → `HarvestSoundTimer` → `FinishHarvesting`):

1. `GetHarvestDetails`: for a static tile `tileID = (ItemID & 0x3FFF) | 0x4000`; for a land tile
   `tileID = LandTile.ID` unchanged. This is how resource tiles are recognised: the definition's `Tiles`
   array is compared against that id (`Validate`, exact match, or range pairs when `RangedTiles`).
2. Gates, in order: tool not worn out → tile validates (or `ValidateSpecial`) → `CheckRange`
   (`MaxRange` tiles and same map) → `CheckResources` (bank `Current >= ConsumedPerHarvest`) →
   system-specific `CheckHarvest` (e.g. mining while mounted/polymorphed is refused).
3. Resource choice: `vein = MutateVein(...)`; then `MutateResource`:
   ```
   racialBonus = def.RaceBonus && from.Race == Elf;      // ML only
   if (vein.ChanceToFallback > RandomDouble() + (racialBonus ? 0.20 : 0)) return vein.FallbackResource;
   if (fallback != null && (skillValue < primary.ReqSkill || skillValue < primary.MinSkill)) return fallback;
   return vein.PrimaryResource;
   ```
4. **Skill check** (`CheckHarvestSkill`): `from.Skills[def.Skill].Value >= resource.ReqSkill` **AND**
   `from.CheckSkill(def.Skill, resource.MinSkill, resource.MaxSkill)`. This is the *only* success roll.
5. On success: `type = GetResourceType(...)` (random pick from `resource.Types`, or overridden: mining stone/gem
   toggles, lumberjacking Harvester's Axe → boards, fishing rare-fish table), then `MutateType`
   (`from.Region.GetResource(type)`), then item creation.
6. **Yield**: `item.Amount = ConsumedPerHarvest`; if `map == Map.Felucca && !Siege.SiegeShard` **and**
   `bank.Current >= ConsumedPerFeluccaHarvest` → `Amount = ConsumedPerFeluccaHarvest`. With `RaceBonus` (ML),
   a **Human** gets `ceil(amount * 1.1)` at 10 % chance; an **Elf** instead shortens the bucket respawn timer
   by 25 % and gets +0.20 on the vein fallback roll (step 3). Granite forces the Felucca amount to 3.
   `bank.Consume(ConsumedPerHarvest)` (only for `AccessLevel.Player`).
7. Bonus drop: `GetBonusResource()` rolls `RandomDouble()*100` against each `BonusResources[i].Chance`
   cumulatively; drop requires `skillBase >= bonus.ReqSkill` (and map match). Note the first entry of the ML
   tables is a "nothing" entry with a large chance (99.2 / 82.0 / 97.0).
8. **Tool wear**: only inside the skill-check-success branch, and only if
   `tool is BaseHarvestTool || Pickaxe || SturdyPickaxe || GargoylesPickaxe || Siege.SiegeShard`:
   `--UsesRemaining; if (UsesRemaining < 1) { Delete(); "You have worn out your tool!" }`.
   **A failed skill check consumes no tool use.** Ordinary axes therefore never wear out on a non-siege shard.
9. Failure message = `def.FailMessage` when `type == null`.

**Timing** (`HarvestTimer`, `HarvestSoundTimer`): a `HarvestTimer(TimeSpan.Zero, def.EffectDelay)` performs
`RandomList(def.EffectCounts)` swings; each swing starts a `HarvestSoundTimer(def.EffectSoundDelay)` that plays
the sound and, on the **last** swing, calls `FinishHarvesting` — i.e. one resource is produced per swing.
Net per-swing time ≈ `EffectSoundDelay` (the final sound timer), with swings spaced by `EffectDelay`:

| system | EffectDelay | EffectSoundDelay | EffectCounts | animation | sound |
|---|---|---|---|---|---|
| Mining (ore/stone) | 1.6 s | 0.9 s | `{1}` | 11 (pre-SA) / 3 (SA+) | 0x125, 0x126 |
| Mining (sand) | 1.6 s | 0.9 s | `{6}` | 11 / 3 | 0x125, 0x126 |
| Lumberjacking | 1.6 s | 0.9 s | `{1}` (AoS+) / `{1,2,2,2,3}` (pre-AoS) | 13 / 7 | 0x13E |
| Fishing | 0 s | **8.0 s** | `{1}` | 12 / 6 | — |

Concurrency: `GetLock` returns `this` for Mining/Lumberjacking (one harvest at a time per system) and
`Fishing` reports "You are already fishing." (cliloc 500972).

### 1.2 MINING

`Scripts/Services/Harvest/Mining.cs`. Two definitions on one system: `OreAndStone` and `Sand`.
Mining requires a **Pickaxe** / **Sturdy Pickaxe** / **Gargoyles Pickaxe** (or a shovel for sand).
Restrictions: not while mounted (501864), not while polymorphed (501865), target must be a valid mountain/cave
tile (501862 "You can't mine there.").

**Bank / yield parameters** (`OreAndStone`): `BankWidth/Height = 8/8` (one pool per 8×8 tile block),
`MinTotal/MaxTotal = 10/34` ore per pool, respawn 10–20 min (elf ×0.75), `MaxRange = 2`,
`ConsumedPerHarvest = 1`, `ConsumedPerFeluccaHarvest = 2`, `PlaceAtFeetIfFull` false.

**Ore table + skill gates** (constructor of `Mining`, `Mining.cs`):

| ore (class) | `ReqSkill` (vein gate) | `MinSkill` (gain window lo) | `MaxSkill` (gain window hi) | vein chance % | fallback chance | success msg cliloc | bonus spawn type (Gargoyle's Pickaxe) |
|---|---|---|---|---|---|---|---|
| Iron (`IronOre`) | 0.0 | 0.0 | 100.0 | 49.6 | 0.0 | 1007072 | — |
| Dull Copper (`DullCopperOre`) | 65.0 | 25.0 | 105.0 | 11.2 | 0.5 | 1007073 | `DullCopperElemental` |
| Shadow Iron (`ShadowIronOre`) | 70.0 | 30.0 | 110.0 | 9.8 | 0.5 | 1007074 | `ShadowIronElemental` |
| Copper (`CopperOre`) | 75.0 | 35.0 | 115.0 | 8.4 | 0.5 | 1007075 | `CopperElemental` |
| Bronze (`BronzeOre`) | 80.0 | 40.0 | 120.0 | 7.0 | 0.5 | 1007076 | `BronzeElemental` |
| Gold (`GoldOre`) | 85.0 | 45.0 | 125.0 | 5.6 | 0.5 | 1007077 | `GoldenElemental` |
| Agapite (`AgapiteOre`) | 90.0 | 50.0 | 130.0 | 4.2 | 0.5 | 1007078 | `AgapiteElemental` |
| Verite (`VeriteOre`) | 95.0 | 55.0 | 135.0 | 2.8 | 0.5 | 1007079 | `VeriteElemental` |
| Valorite (`ValoriteOre`) | 99.0 | 59.0 | 139.0 | 1.4 | 0.5 | 1007080 | `ValoriteElemental` |

Reading the table: the **vein** is decided first (chances above, sum 100.0). If the vein is a coloured one,
there is a **50 % chance to fall back to iron** *unless* `skillValue >= ReqSkill` **and**
`skillValue >= MinSkill` — the classic "you need 65 Mining before you can even see dull copper" gate. The
success roll is then `CheckSkill(Mining, MinSkill, MaxSkill)`.

- Era note: **which publish introduced the coloured ores is UNVERIFIED** (§9 item U3). The source only proves
  that coloured veins are a `Core.ML`-independent part of the table. If the clone targets pre-UOR, ship only the
  iron row (`ChanceToFallback = 0`, veins = one 100 % iron vein), which is exactly what a pre-ore-colour shard
  behaves like.
- **Mountains vs caves vs valleys**: the code does **not** distinguish them — only the tile-id list decides.
  Valleys are simply tiles that are not in the list, so they yield nothing. Cave/mountain "richness" in
  folklore maps onto `MinTotal/MaxTotal = 10..34` per 8×8 bucket, everywhere.

**Harvestable mining tiles** (`m_MountainAndCaveTiles`): 220–231, 236–247, 252–263, 268–279, 286–297 (with 296
twice), 321–324, 467–487, 492–495, 543–601, 610–613, 1010, 1741–1757, 1771–1790, 1801–1824, 1831–1854,
1861–1884, 1981–2004, 2028–2033, 2100–2105, plus statics `0x453B`–`0x454F`.

**Sand** (`Mining.Sand`): `BankWidth/Height = 8/8`, `MinTotal/MaxTotal = 6/13`,
respawn 10–20 min, `MaxRange = 2`, `ConsumedPerHarvest = 1`, `ConsumedPerFeluccaHarvest = 2`,
`EffectCounts = {6}`, resource `Sand` with `ReqSkill = 100.0, MinSkill = 70.0, MaxSkill = 100.0`, single vein
100 %. Gated by `PlayerMobile.SandMining` **and** `Mining.Base >= 100.0` (`CheckHarvest` override).
Sand tiles: 22–62, 68–75, 286–301, 402, 424–427, 441–465, 642–645, 650–657, 821–828, 833–836, 845–852,
857–860, 951–958, 967–970, 1447–1458, 1611–1618, 1623–1626, 1635–1642, 1647–1650.

**Granite (ML+)**: when stone mining is toggled (Mining ≥ 100), `GetResourceType` returns
`resource.Types[1]` (the matching `*Granite`) with 15 % chance (50 % with a Rock Hammer). Granite always
yields 3 per swing (`if (item is BaseGranite) feluccaAmount = 3`).

**Gems (ML+)**: `PlayerMobile.GemMining && ToggleMiningGem && Mining.Base >= 100` → 10 % chance to return a
gem from `Loot.GemTypes` instead of ore.

**Gargoyle's Pickaxe**: `MutateVein` promotes the vein one step up the list (iron→dull copper→shadow…);
`OnHarvestFinished` has a 10 % chance to spawn the vein's third `Types` entry (the matching elemental,
constructed with amount 25) next to the miner.

**ML bonus drops** (per successful swing, `skillBase >= 100`): BlueDiamond, DarkSapphire, EcruCitrine,
FireRuby, PerfectEmerald, Turquoise, SmallPieceofBlackrock each 0.1 % (plus 0.1 % CrystallineBlackrock on
TerMur); the 99.2 % "nothing" entry comes first.

**Blackrock/Niter (High Seas)**: `SpecialHarvest` — on a boat or in a dungeon,
`bonus = Mining.Value/9999 + luck/150000`, on a boat `bonus *= 0.67`; if `RandomDouble() < bonus` a
`NiterDeposit` of size 1–5 (6 if `luck/2500 > RandomDouble()`) appears; mining it gives saltpeter.

### 1.3 LUMBERJACKING

`Scripts/Services/Harvest/Lumberjacking.cs`. `BankWidth/Height = 4/3`, `MinTotal/MaxTotal = 20/45` logs per
bucket, respawn 20–30 min, `MaxRange = 2`, `ConsumedPerHarvest = 10`, `ConsumedPerFeluccaHarvest = 20`.
Axe must be in the backpack or equipped (1080058 "This must be in your backpack to use it.").
Note: **10 logs per swing (20 in Felucca) is the current ServUO value**; whether the original era yielded
fewer logs per swing is UNVERIFIED (measure on a reference shard, or compare with a pre-AoS emulator fork).
The pre-ML branch of this same file (`else` of `if (Core.ML)`) still has a single ordinary-log resource with
a 100 % vein, which is the correct shape for a T2A clone.

**Wood table** (ML branch — the pre-ML branch has a single `Log` row with `ReqSkill/MinSkill/MaxSkill = 0/0/100`
and one vein at 100 %):

| wood | ReqSkill | MinSkill | MaxSkill | vein chance % | fallback % | success cliloc |
|---|---|---|---|---|---|---|
| Normal (`Log`) | 0.0 | 0.0 | 100.0 | 49.0 | — | 1072540 |
| Oak (`OakLog`) | 65.0 | 25.0 | 105.0 | 30.0 | 0.5 | 1072541 |
| Ash (`AshLog`) | 80.0 | 40.0 | 120.0 | 10.0 | 0.5 | 1072542 |
| Yew (`YewLog`) | 95.0 | 55.0 | 135.0 | 5.0 | 0.5 | 1072543 |
| Heartwood (`HeartwoodLog`) | 100.0 | 60.0 | 140.0 | 3.0 | 0.5 | 1072544 |
| Bloodwood (`BloodwoodLog`) | 100.0 | 60.0 | 140.0 | 2.0 | 0.5 | 1072545 |
| Frostwood (`FrostwoodLog`) | 100.0 | 60.0 | 140.0 | 1.0 | 0.5 | 1072546 |

ML bonus drops per swing (skill ≥ 100): BarkFragment 10 %, LuminescentFungi 3 %, SwitchItem 2 %,
ParasiticPlant 1 %, BrilliantAmber 1 %, CrystalShards 1 % (TerMur only); 82 % nothing.

**Harvestable tree tiles** (`m_TreeTiles`, sorted at init): `0x4CCA–0x4CCD, 0x4CD0, 0x4CD3, 0x4CD6, 0x4CD8,
0x4CDA, 0x4CDD, 0x4CE0, 0x4CE3, 0x4CE6, 0x4CF8, 0x4CFB, 0x4CFE, 0x4D01, 0x4D41–0x4D44, 0x4D57–0x4D5B,
0x4D6E–0x4D72, 0x4D84–0x4D86, 0x52B5–0x52BD, 0x4CCE, 0x4CCF, 0x4CD1, 0x4CD2, 0x4CD4, 0x4CD5, 0x4CD7,
0x4CD9, 0x4CDB, 0x4CDC, 0x4CDE, 0x4CDF, 0x4CE1, 0x4CE2, 0x4CE4, 0x4CE5, 0x4CE7, 0x4CE8, 0x4CF9, 0x4CFA,
0x4CFC, 0x4CFD, 0x4CFF, 0x4D00, 0x4D02, 0x4D03, 0x4D45–0x4D53, 0x4D5C–0x4D69, 0x4D73–0x4D7F,
0x4D87–0x4D90, 0x4D95–0x4D97, 0x4D99–0x4D9B, 0x4D9D–0x4D9F, 0x4DA1–0x4DA3, 0x4DA5–0x4DA7, 0x4DA9–0x4DAB,
0x52BE–0x52C7`. Tool must not be used on a mobile ("You can only skin dead creatures.") or on furniture
(`IChopable` / `FurnitureAttribute` gives wood back).

**Log → board**: not a carpentry menu entry in ServUO master. It is `BaseLog.TryCreateBoards` →
`Item.ScissorHelper(from, new Board(), 1, false)` (`Scripts/Items/Resource/Log.cs:88`,
`Server/Item.cs:5990`), i.e. **the whole stack converts 1 log → 1 board, no skill check, no loss**, capped at
60000 boards. Coloured wood requires `Carpentry.Value >= skill || Lumberjacking.Value >= skill`
(1072652 "You cannot work this strange and unusual wood."). `Harvester's Axe` with charges converts the
harvested log directly into the matching board.

**Damage bonus while lumberjacking** (`Scripts/Items/Equipment/Weapons/BaseWeapon.cs:3791`):

```csharp
double lumberBonus = GetBonus(attacker.Skills[SkillName.Lumberjacking].Value, 0.200, 100.0, 10.00);
if (Type != WeaponType.Axe) lumberBonus = 0.0;
// GetBonus(value, scalar, threshold, offset) => (value*scalar + (value>=threshold ? offset : 0)) / 100
```
→ axe-only bonus `= (LJ × 0.20 + (LJ ≥ 100 ? 10 : 0)) / 100`: 0.00 at 0 LJ, 0.10 at 50 LJ, **0.30 at 100 LJ**
(added to `percentageBonus`). Lumberjacking is also passively checked for gain on every axe swing against the
same weapon (`BaseWeapon.cs:3777`).

### 1.4 FISHING

`Scripts/Services/Harvest/Fishing.cs`. `BankWidth/Height = 8/8`, `MinTotal/MaxTotal = 5/15` fish per bucket,
respawn 10–20 min, `MaxRange = 4`, `ConsumedPerHarvest = ConsumedPerFeluccaHarvest = 1`,
`RangedTiles = true` (the `Tiles` array holds *pairs*: lo, hi), 8 s per attempt.

**Water tiles** (`m_WaterTiles`, interpreted as ranges because of `RangedTiles = true`):
`0x00A8–0x00AB`, `0x0136–0x0137`, `0x5797–0x579C`, `0x746E–0x7485`, `0x7490–0x74AB`, `0x74B5–0x75D5`.
**Lava tiles** (`m_LavaTiles`, High Seas / lava fishing hook): `0x1F4–0x1F7`, `4846–4850`, `4852–4859`,
`4560–4562`, `4864–4868`, `4870–4874`, `4876–4880`, `4882–4886`, `4888–4892`
(the `4560–4562` entries look like a typo for `4860–4862` in source).

**Base catch**: `HarvestResource(ReqSkill 0.0, MinSkill 0.0, MaxSkill 120.0, cliloc 1043297, typeof(Fish))`,
single vein 100 %. So *any* Fishing skill can catch a fish, and skill above 120 gives no further gain window.

**Skill check** (`CheckHarvestSkill` override):
```
deepWater = SpecialFishingNet.ValidateDeepWater(map,x,y) && map in {Trammel, Felucca, Tokuno}
if (deepWater && Fishing.Value < 75.0)  return Fishing.Value >= res.ReqSkill;   // no roll: deep water refuses you
if (!deepWater && Fishing.Value >= 75.0) return true;                            // roll auto-succeeds, no gains
return base.CheckHarvestSkill(...);                                             // CheckSkill(0,120)
```

**Special-catch table** (`m_MutateTable`, evaluated top-down; first hit wins). Chance formula
`chance = (skillValue - MinSkill) / (MaxSkill - MinSkill)` with a hard gate `skillBase >= ReqSkill`,
and `deepWater` rows are skipped in shallow water:

| # | catch | ReqSkill | MinSkill | MaxSkill | chance at 100 skill (value form) | deep water only |
|---|---|---|---|---|---|---|
| 0 | Special Fishing Net (`SpecialFishingNet`) | 80 | 80 | 1865 | (100−80)/1785 = **1.12 %** | yes |
| 1 | Treasure Map (`TreasureMap`) | 90 | 80 | 1875 | 20/1795 = **1.11 %** | yes |
| 2 | Message in a Bottle (`MessageInABottle`) | 100 | 80 | 750 | 20/670 = **2.99 %** | yes |
| 3 | Big Fish (`BigFish`) | 80 | 80 | 4080 | 20/4000 = **0.49 %** | yes |
| 4 | Prized/Wondrous/TrulyRare/Peculiar fish | 0 | 125 | −2375 | negative → **never fires** | no |
| 5 | Boots / Shoes / Sandals / ThighBoots | 0 | 125 | −420 | negative → **never fires** | no |
| 6 | MudPuppy / RedHerring (Underworld region only) | 80 | 80 | 2500 | 20/2420 = **0.83 %** | no |
| 7 | nothing (`null`) | 0 | 200 | −200 | negative → never | no |

The siege variant `m_SiegeMutateTable` is the same minus the treasure-map row and with footwear at
`MinSkill 105`. Treasure map level is **always 1** (level 0 for Young players on Haven);
Message in a Bottle / SOS uses the current facet.
Implementation note: because rows 4, 5 and 7 have `MinSkill > MaxSkill`, they can never fire in ServUO —
if the clone wants the classic "old boot / rare fish" catches, they must be re-derived (see §9 item U4).
`IsDeepWater` = `SpecialFishingNet.ValidateDeepWater(map,x,y)` and facet Trammel/Felucca/Tokuno.
**No sea-serpent roll lives in Fishing.cs**; the only serpent reference is `DeepSeaSerpent` constructed by
`SpecialFishingNet` / SOS handling (`Fishing.cs:448` area). See §9 item U5.

**Lava fishing** (`m_LavaMutateTable`, needs a lava hook): StoneFootwear `(0, 80, 333)`,
CrackedLavaRockEast/South `(80, 80, 333)`, StonePaver `(85, 80, 333)`,
a random **Searing weapon** `(80, 80, 4080)`; in Felucca rules the chance is multiplied by 1.5.

**Bonus drops (ML+)**: DelicateScales 2 %, WhitePearl 1 % (gate skillBase ≥ 80), 97 % nothing.

**SOS / shipwreck loot**: if the fisher has an `SOS` in the pack and is within 60 tiles of its target
location, `CheckResources` returns true even when the bucket is empty, and `Construct` builds one of 16
(17 with High Seas) shipwreck items: body parts (`0x1CDD/0x1CE5` arm, `0x1CE0/0x1CE8` torso, `0x1CE1/0x1CE9`
head, `0x1CE2/0x1CEC` leg), etc.

### 1.5 CAMPING

`Scripts/Items/Functional/Campfire.cs`, `Scripts/Items/Tools/Bedroll.cs`. Camping is a *logout-safety* skill,
not a resource producer:

- Use a **Bedroll** (`Bedroll`, in `Scripts/Items/Tools/Bedroll.cs`) → `Campfire.GetEntry(from)`; if inside a
  valid campfire the `LogoutGump` ("Logging out via camping", cliloc 1011015) offers safe logout.
- Campfire art/light: `0xDE3` with `LightType.Circle300`; variants `0xDE9` (Circle150) and `0xDEA`.
- The Camping **skill check** itself happens when the fire is created from kindling + the skill-use action;
  in ServUO the check is `SkillName.Camping` against the fire-creation target (see `Campfire.cs` and
  `Kindling.cs`). A failed check simply produces no fire. **[UNVERIFIED — the exact camping skill window is
  not spelled out in the files inspected; see §9 item U6.]**
- No recipe consumes Camping; it is listed in `SkillCat.Miscellaneous` alongside ArmsLore, Begging,
  Cartography, Forensics, ItemID, TasteID (`Scripts/Items/Books/SpecialScrollBooks/ScrollOfAlacrityBook.cs`).

### 1.6 FORENSIC EVALUATION

`Scripts/Skills/ForensicEval.cs` — pure information skill, no resources. Target range 10, one second reuse
delay, "Show me the crime." (501000). Exact gates:

| target | hard skill floor | skill window | result |
|---|---|---|---|
| `Corpse` | 30.0 | `CheckTargetSkill(Forensics, 30, 55)` | killer name (1042751), looter list (1042752), "not desecrated" (501002); records the forensicist |
| `Mobile` | 36.0 | `CheckTargetSkill(Forensics, 36, 100)` | "That individual is a thief!" (501004) only if `PlayerMobile.NpcGuild == NpcGuild.ThievesGuild` |
| `ILockpickable` (door/container) | 41.0 | `CheckTargetSkill(Forensics, 41, 100)` | name of the last picker (1042749) |
| `Item` (SA+) | 41.0 | `CheckTargetSkill(Forensics, 41, 100)` | Honesty-item owner/region; owner name + region at Forensics ≥ 61, else region only (1151521/1151522) |

Below the floor the message is 501003 "You notice nothing unusual."; a failed roll is 501001
"You cannot determine anything useful."

### 1.7 CARTOGRAPHY & TREASURE MAPS

**Blank map / cartography craft**: `DefCartography` recipes are §5.8; the *skill-use* path creates a map by
targeting (the map classes `LocalMap`, `CityMap`, `SeaChart`, `WorldMap` in `Scripts/Items/Tools/` all read
`from.Skills[SkillName.Cartography].Value`). `BlankMap` (0x14EC) by itself just says
"It appears to be blank." (500208). **[UNVERIFIED — the exact cartography target skill windows live in the
map classes; not read line-by-line. See §9 item U7.]**

**Treasure maps** (`Scripts/Services/TreasureMaps/TreasureMap.cs`):

- Map levels: `Level = Math.Min(value, TreasureMapInfo.NewSystem ? 4 : 7)`; classic levels are **1–6**
  (name cliloc `1041516 + level`), level 7 + the Stash/Supply/Cache/Hoard/Trove ladder is the modern
  `NewSystem`.
- Digging requires a digging tool in the pack (`TreasureMap.HasDiggingTool`), the map in the pack, and the
  spot marked by the map; a `TreasureMapChest` is created and guarded by `m_SpawnTypes[level]` spawns
  (level 1: HeadlessOne/Skeleton; level 2: Mongbat/Ratman/…; level 3: OrcishMage/Gargoyle/…).
- `AssignChestQuality(digger, chest)` uses **Cartography** value against a difficulty of
  `Stash 100, Supply 200, Cache 300, Hoard 400, Trove 500`:
  `Random(dif) <= skill` → Gold chest; else `Random(dif) <= skill*2` → Standard; else Rusty.
  For classic levels 1–6 the modern ladder does not apply as written — treat chest quality per level as
  **[UNVERIFIED]** for pre-SA eras.
- Fishing can produce a level-1 treasure map (see §1.4 row 1) or, from a Message in a Bottle, an SOS.

---

## 2. RESOURCE ITEM TABLE

### 2.1 Raw / intermediate resources

Weight column: explicit server value where the class sets one; otherwise `tiledata` = the client's
`tiledata.mul` value, which the server inherits (see §9 item U1 for how to measure it).
**Global stack cap is 60000** (`Server/Item.cs`: `if (item.Amount + Amount > 60000) return false;`
and `if (amount > (60000 / amountPerOldItem))` in `ScissorHelper`).

| item | server class | ItemID (hex) | weight | stackable | source file | notes |
|---|---|---|---|---|---|---|
| Iron ore (normal pile) | `IronOre` | 0x19B8 | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | pile ids 0x19B7 small / 0x19B8 normal / 0x19B9 large |
| Dull copper ore | `DullCopperOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Shadow iron ore | `ShadowIronOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Copper ore | `CopperOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Bronze ore | `BronzeOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Gold ore | `GoldOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Agapite ore | `AgapiteOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Verite ore | `VeriteOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Valorite ore | `ValoriteOre` | inherits BaseOre | tiledata | yes | `Scripts/Items/Resource/Ore.cs` | — |
| Granite (stone from mining) | `Granite` | 0x1779 | tiledata | only if Core.ML | `Scripts/Items/Resource/Granite.cs` | coloured granite classes 1:1 with ore types |
| Iron ingot | `IronIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | DefaultWeight 0.1 (Ingots.cs:43) |
| Dull copper ingot | `DullCopperIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Shadow iron ingot | `ShadowIronIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Copper ingot | `CopperIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Bronze ingot | `BronzeIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Gold ingot | `GoldIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Agapite ingot | `AgapiteIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Verite ingot | `VeriteIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Valorite ingot | `ValoriteIngot` | 0x1BF2 | 0.1 | yes | `Scripts/Items/Resource/Ingots.cs` | — |
| Log (normal wood) | `Log` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | Weight = 2.0 (Log.cs:37) |
| Oak log | `OakLog` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | — |
| Ash log | `AshLog` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | — |
| Yew log | `YewLog` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | — |
| Heartwood log | `HeartwoodLog` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | — |
| Bloodwood log | `BloodwoodLog` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | — |
| Frostwood log | `FrostwoodLog` | 0x1BDD | 2.0 | yes | `Scripts/Items/Resource/Log.cs` | — |
| Board (plank) | `Board` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | 1 log -> 1 board (Log.cs TryCreateBoards -> ScissorHelper amount=1) |
| Oak board | `OakBoard` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | — |
| Ash board | `AshBoard` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | — |
| Yew board | `YewBoard` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | — |
| Heartwood board | `HeartwoodBoard` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | — |
| Bloodwood board | `BloodwoodBoard` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | — |
| Frostwood board | `FrostwoodBoard` | 0x1BD7 | tiledata | yes | `Scripts/Items/Resource/Board.cs` | — |
| Hides (regular) | `Hides` | 0x1079 | 5.0 | yes | `Scripts/Items/Resource/Hides.cs` | Weight = 5.0 (Hides.cs:20) |
| Spined hides | `SpinedHides` | 0x1079 | 5.0 | yes | `Scripts/Items/Resource/Hides.cs` | — |
| Horned hides | `HornedHides` | 0x1079 | 5.0 | yes | `Scripts/Items/Resource/Hides.cs` | — |
| Barbed hides | `BarbedHides` | 0x1079 | 5.0 | yes | `Scripts/Items/Resource/Hides.cs` | — |
| Leather (regular) | `Leather` | 0x1081 | 1.0 | yes | `Scripts/Items/Resource/Leathers.cs` | Weight = 1.0 (Leathers.cs:20) |
| Spined leather | `SpinedLeather` | 0x1081 | 1.0 | yes | `Scripts/Items/Resource/Leathers.cs` | — |
| Horned leather | `HornedLeather` | 0x1081 | 1.0 | yes | `Scripts/Items/Resource/Leathers.cs` | — |
| Barbed leather | `BarbedLeather` | 0x1081 | 1.0 | yes | `Scripts/Items/Resource/Leathers.cs` | — |
| Cloth | `Cloth` | 0x1766 | 0.1 | yes | `Scripts/Items/Resource/Cloth.cs` | DefaultWeight 0.1 (Cloth.cs:28) |
| Uncut cloth | `UncutCloth` | 0x1767 | 0.1 | yes | `Scripts/Items/Resource/Cloth.cs` | cloth<->uncut cloth and bolt conversion recipes |
| Bolt of cloth | `BoltOfCloth` | 0xF95 | 5.0 | yes | `Scripts/Items/Resource/BoltOfCloth.cs` | Weight = 5.0 |
| Wool | `Wool` | 0x0DF8 | 4.0 | yes | `Scripts/Items/Resource/Wool.cs` | — |
| Cotton | `Cotton` | 0x0DF9 | 4.0 | yes | `Scripts/Items/Resource/Cotton.cs` | — |
| Flax | `Flax` | 0x1A9C | 1.0 | yes | `Scripts/Items/Resource/Flax.cs` | — |
| Spool of thread | `SpoolOfThread` | 0x0FA0 | tiledata | yes | `Scripts/Items/Resource/YarnsAndThreads.cs` | — |
| Dark yarn | `DarkYarn` | 0x0E1D | tiledata | yes | `Scripts/Items/Resource/YarnsAndThreads.cs` | alchemy fuse/matchcord ingredient |
| Light yarn | `LightYarn` | 0x0E1E | tiledata | yes | `Scripts/Items/Resource/YarnsAndThreads.cs` | — |
| Feather | `Feather` | 0x1BD1 | 0.1 | yes | `Scripts/Items/Resource/Feather.cs` | DefaultWeight 0.1 (Feather.cs:26) |
| Arrow | `Arrow` | 0x0F3F | 0.1 | yes | `Scripts/Items/Resource/Arrow.cs` | DefaultWeight 0.1 (Arrow.cs:26) |
| Crossbow bolt | `Bolt` | 0x1BFB | 0.1 | yes | `Scripts/Items/Resource/Bolt.cs` | DefaultWeight 0.1 (Bolt.cs:10) |
| Arrow shaft | `Shaft` | 0x1BD4 | 0.1 | yes | `Scripts/Items/Resource/Shaft.cs` | DefaultWeight 0.1 (Shaft.cs:26) |
| Kindling | `Kindling` | 0x0DE1 | 1.0 | no | `Scripts/Items/Consumables/Kindling.cs` | campfire fuel; made from 1 board |
| Bottle (empty) | `Bottle` | 0x0F0E | 1.0 | yes | `Scripts/Items/Resource/Bottle.cs` | every potion recipe needs 1 |
| Blank scroll | `BlankScroll` | 0x0EF3 | 1.0 | yes | `Scripts/Items/Resource/BlankScroll.cs` | 1 per inscribed scroll |
| Sand | `Sand` | 0x423A | 0.1 | yes | `Scripts/Items/Resource/Sand.cs` | DefaultWeight 0.1; mined (Mining 100 + SandMining flag) |
| Seed | `Seed` | 0x0DCF | 1.0 | only if Core.SA | `Scripts/Items/Resource/Seed.cs` | — |
| Fish (fish steak source) | `Fish` | 0x09CC-0x09CF | 1.0 | yes | `Scripts/Items/Resource/Fish.cs` | random art 0x09CC+0..3; carved into fish steaks |
| Bone | `Bone` | 0x0F7E | 1.0 | yes | `Scripts/Items/Resource/Bone.cs` | bone armour + BoneMachete ingredient |
| Black pearl | `BlackPearl` | 0x0F7A | tiledata | yes | `Scripts/Items/Resource/BlackPearl.cs` | reagent; stackable from BaseReagent |
| Bloodmoss | `Bloodmoss` | 0x0F7B | tiledata | yes | `Scripts/Items/Resource/Bloodmoss.cs` | reagent |
| Garlic | `Garlic` | 0x0F84 | tiledata | yes | `Scripts/Items/Resource/Garlic.cs` | reagent |
| Ginseng | `Ginseng` | 0x0F85 | tiledata | yes | `Scripts/Items/Resource/Ginseng.cs` | reagent |
| Mandrake root | `MandrakeRoot` | 0x0F86 | tiledata | yes | `Scripts/Items/Resource/MandrakeRoot.cs` | reagent |
| Nightshade | `Nightshade` | 0x0F88 | tiledata | yes | `Scripts/Items/Resource/Nightshade.cs` | reagent |
| Sulfurous ash | `SulfurousAsh` | 0x0F8C | tiledata | yes | `Scripts/Items/Resource/SulfurousAsh.cs` | reagent |
| Spider's silk | `SpidersSilk` | 0x0F8D | tiledata | yes | `Scripts/Items/Resource/SpidersSilk.cs` | reagent |
| Bat wing | `BatWing` | 0x0F78 | tiledata | yes | `Scripts/Items/Resource/BatWing.cs` | necro reagent |
| Grave dust | `GraveDust` | 0x0F8F | tiledata | yes | `Scripts/Items/Resource/GraveDust.cs` | necro reagent |
| Daemon blood | `DaemonBlood` | 0x0F7D | tiledata | yes | `Scripts/Items/Resource/DaemonBlood.cs` | necro reagent |
| Nox crystal | `NoxCrystal` | 0x0F8E | tiledata | yes | `Scripts/Items/Resource/NoxCrystal.cs` | necro reagent |
| Pig iron | `PigIron` | 0x0F8A | tiledata | yes | `Scripts/Items/Resource/PigIron.cs` | necro reagent |
| Red dragon scales | `RedScales` | 0x26B4 | tiledata | yes | `Scripts/Items/Resource/Scales.cs` | dragon armour sub-res 2 |
| Yellow scales | `YellowScales` | 0x26B4 | tiledata | yes | `Scripts/Items/Resource/Scales.cs` | — |
| Black scales | `BlackScales` | 0x26B4 | tiledata | yes | `Scripts/Items/Resource/Scales.cs` | — |
| Green scales | `GreenScales` | 0x26B4 | tiledata | yes | `Scripts/Items/Resource/Scales.cs` | — |
| White scales | `WhiteScales` | 0x26B4 | tiledata | yes | `Scripts/Items/Resource/Scales.cs` | — |
| Blue scales | `BlueScales` | 0x26B4 | tiledata | yes | `Scripts/Items/Resource/Scales.cs` | — |
| Granite block (coloured) | `DullCopperGranite..ValoriteGranite` | 0x1779 | tiledata | only if Core.ML | `Scripts/Items/Resource/Granite.cs` | masonry sub-res, skill gates 65/70/75/80/85/90/95/99 |

### 2.2 Resource identity tables (hue / cliloc / name / item classes)

These are the authoritative `CraftResource` → item-class → hue mappings used by the crafting engine to colour
and name crafted goods (source `Scripts/Misc/ResourceInfo.cs`).


**`CraftResources` table: m_MetalInfo** — hue, cliloc, display name, resource enum, resource item classes (@ `Scripts/Misc/ResourceInfo.cs`)

| hue | cliloc | resource name | enum | item classes (ResourceTypes) |
|---|---|---|---|---|
| 0x000 | 1053109 | Iron | `CraftResource.Iron` | IronIngot, IronOre, Granite |
| 0x973 | 1053108 | Dull Copper | `CraftResource.DullCopper` | DullCopperIngot, DullCopperOre, DullCopperGranite |
| 0x966 | 1053107 | Shadow Iron | `CraftResource.ShadowIron` | ShadowIronIngot, ShadowIronOre, ShadowIronGranite |
| 0x96D | 1053106 | Copper | `CraftResource.Copper` | CopperIngot, CopperOre, CopperGranite |
| 0x972 | 1053105 | Bronze | `CraftResource.Bronze` | BronzeIngot, BronzeOre, BronzeGranite |
| 0x8A5 | 1053104 | Gold | `CraftResource.Gold` | GoldIngot, GoldOre, GoldGranite |
| 0x979 | 1053103 | Agapite | `CraftResource.Agapite` | AgapiteIngot, AgapiteOre, AgapiteGranite |
| 0x89F | 1053102 | Verite | `CraftResource.Verite` | VeriteIngot, VeriteOre, VeriteGranite |
| 0x8AB | 1053101 | Valorite | `CraftResource.Valorite` | ValoriteIngot, ValoriteOre, ValoriteGranite |

**`CraftResources` table: m_ScaleInfo** — hue, cliloc, display name, resource enum, resource item classes (@ `Scripts/Misc/ResourceInfo.cs`)

| hue | cliloc | resource name | enum | item classes (ResourceTypes) |
|---|---|---|---|---|
| 0x66D | 1053129 | Red Scales | `CraftResource.RedScales` | RedScales |
| 0x8A8 | 1053130 | Yellow Scales | `CraftResource.YellowScales` | YellowScales |
| 0x455 | 1053131 | Black Scales | `CraftResource.BlackScales` | BlackScales |
| 0x851 | 1053132 | Green Scales | `CraftResource.GreenScales` | GreenScales |
| 0x8FD | 1053133 | White Scales | `CraftResource.WhiteScales` | WhiteScales |
| 0x8B0 | 1053134 | Blue Scales | `CraftResource.BlueScales` | BlueScales |

**`CraftResources` table: m_LeatherInfo** — hue, cliloc, display name, resource enum, resource item classes (@ `Scripts/Misc/ResourceInfo.cs`)

| hue | cliloc | resource name | enum | item classes (ResourceTypes) |
|---|---|---|---|---|
| 0x000 | 1049353 | Normal | `CraftResource.RegularLeather` | Leather, Hides |
| 0x283 | 1049354 | Spined | `CraftResource.SpinedLeather` | SpinedLeather, SpinedHides |
| 0x227 | 1049355 | Horned | `CraftResource.HornedLeather` | HornedLeather, HornedHides |
| 0x1C1 | 1049356 | Barbed | `CraftResource.BarbedLeather` | BarbedLeather, BarbedHides |

**`CraftResources` table: m_AOSLeatherInfo** — hue, cliloc, display name, resource enum, resource item classes (@ `Scripts/Misc/ResourceInfo.cs`)

| hue | cliloc | resource name | enum | item classes (ResourceTypes) |
|---|---|---|---|---|
| 0x000 | 1049353 | Normal | `CraftResource.RegularLeather` | Leather, Hides |
| 0x8AC | 1049354 | Spined | `CraftResource.SpinedLeather` | SpinedLeather, SpinedHides |
| 0x845 | 1049355 | Horned | `CraftResource.HornedLeather` | HornedLeather, HornedHides |
| 0x851 | 1049356 | Barbed | `CraftResource.BarbedLeather` | BarbedLeather, BarbedHides |

**`CraftResources` table: m_WoodInfo** — hue, cliloc, display name, resource enum, resource item classes (@ `Scripts/Misc/ResourceInfo.cs`)

| hue | cliloc | resource name | enum | item classes (ResourceTypes) |
|---|---|---|---|---|
| 0x000 | 1011542 | Normal | `CraftResource.RegularWood` | Log, Board |
| 0x7DA | 1072533 | Oak | `CraftResource.OakWood` | OakLog, OakBoard |
| 0x4A7 | 1072534 | Ash | `CraftResource.AshWood` | AshLog, AshBoard |
| 0x4A8 | 1072535 | Yew | `CraftResource.YewWood` | YewLog, YewBoard |
| 0x4A9 | 1072536 | Heartwood | `CraftResource.Heartwood` | HeartwoodLog, HeartwoodBoard |
| 0x4AA | 1072538 | Bloodwood | `CraftResource.Bloodwood` | BloodwoodLog, BloodwoodBoard |
| 0x47F | 1072539 | Frostwood | `CraftResource.Frostwood` | FrostwoodLog, FrostwoodBoard |

### 2.3 Sub-resource skill gates (which material needs which skill)

Each craft system declares an ordered sub-resource list; a sub-resource may only be *selected* when the main
skill is at or above its gate (`CraftItem.ConsumeRes`: `if (from.Skills[MainSkill].Base < subResource.RequiredSkill)
{ message = subResource.Message; return false; }`).

| skill | sub-resource list (gate) |
|---|---|
| Blacksmithy | IronIngot 0, DullCopperIngot 65, ShadowIronIngot 70, CopperIngot 75, BronzeIngot 80, GoldIngot 85, AgapiteIngot 90, VeriteIngot 95, ValoriteIngot 99 |
| Blacksmithy (2nd list) | RedScales / YellowScales / BlackScales / GreenScales / WhiteScales / BlueScales — all gate 0 |
| Tinkering | identical ingot list as Blacksmithy |
| Tailoring | Leather 0, SpinedLeather 65, HornedLeather 80, BarbedLeather 99 |
| Carpentry | Board 0, OakBoard 65, AshBoard 75, YewBoard 85, HeartwoodBoard 95, BloodwoodBoard 95, FrostwoodBoard 95 |
| Bowcraft/Fletching | Board 0, OakBoard 65, AshBoard 75, YewBoard 85, HeartwoodBoard 95, BloodwoodBoard 95, FrostwoodBoard 95 |
| Masonry | Granite 0, DullCopperGranite 65, ShadowIronGranite 70, CopperGranite 75, BronzeGranite 80, GoldGranite 85, AgapiteGranite 90, VeriteGranite 95, ValoriteGranite 99 |

### 2.4 Tools

`BaseTool` gives every tool `UsesRemaining = RandomMinMax(25, 75)` unless the class overrides it, and
**exceptional quality doubles the uses** (`GetUsesScalar() == 200` → `ScaleUses()`). A tool is destroyed when
uses drop below 1 and `BreakOnDepletion` is true (default true).

| tool | ItemID | uses | weight | governs (CraftSystem / HarvestSystem) | source |
|---|---|---|---|---|---|
| Pickaxe | see weapon file | | | | `Scripts/Items/Equipment/Weapons/Pickaxe.cs` |
| Shovel (`Shovel`) | inherited | 25–75 (random) | 5.0 | BaseHarvestTool | `Scripts/Items/Tools/Shovel.cs` |
| Sturdy Pickaxe (`SturdyPickaxe`) | 0xE86 | 25–75 (random) | 11.0 | BaseAxe, IUsesRemaining | `Scripts/Items/Tools/SturdyPickaxe.cs` |
| Sturdy Shovel (`SturdyShovel`) | inherited | 25–75 (random) | 5.0 | BaseHarvestTool | `Scripts/Items/Tools/SturdyShovel.cs` |
| Gargoyles Pickaxe (`GargoylesPickaxe`) | 0xE85 | 25–75 (random) | 11.0 | BaseAxe, IUsesRemaining | `Scripts/Items/Tools/GargoylesPickaxe.cs` |
| Smith Hammer (`SmithHammer`) | 0x13E3 | 25–75 (random) | 8.0 | BaseTool | `Scripts/Items/Tools/SmithHammer.cs` |
| Tongs (`Tongs`) | 0xFBB | 25–75 (random) | 2.0 | BaseTool | `Scripts/Items/Tools/Tongs.cs` |
| Hammer (`Hammer`) | 0x102A | 25–75 (random) | 2.0 | BaseTool | `Scripts/Items/Tools/Hammer.cs` |
| Sewing Kit (`SewingKit`) | 0xF9D | 25–75 (random) | 2.0 | BaseTool | `Scripts/Items/Tools/SewingKit.cs` |
| Scissors (`Scissors`) | 0xF9F, 2 | 2 | 1.0 | Item, ICraftable, IQuality, IUsesRemaining | `Scripts/Items/Tools/Scissors.cs` |
| Saw (`Saw`) | 0x1034 | 25–75 (random) | 2.0 | BaseTool | `Scripts/Items/Tools/Saw.cs` |
| Dovetail Saw (`DovetailSaw`) | 0x1028 | 25–75 (random) | 2.0 | BaseTool | `Scripts/Items/Tools/DovetailSaw.cs` |
| Tinker Tools (`TinkerTools`) | 0x1EB8, 1157040 | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/TinkerTools.cs` |
| Mortar Pestle (`MortarPestle`) | 0xE9B | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/MortarPestle.cs` |
| Scribes Pen (`ScribesPen`) | 0x0FBF | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/ScribesPen.cs` |
| Mapmakers Pen (`MapmakersPen`) | 0x0FBF | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/MapmakersPen.cs` |
| Fletcher Tools (`FletcherTools`) | 0x1022 | 25–75 (random) | 2.0 | BaseTool | `Scripts/Items/Tools/FletcherTools.cs` |
| Skillet (`Skillet`) | 0x97F | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/Skillet.cs` |
| Flour Sifter (`FlourSifter`) | 0x103E | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/FlourSifter.cs` |
| Rolling Pin (`RollingPin`) | 0x1043 | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/RollingPin.cs` |
| Mallet And Chisel (`MalletAndChisel`) | 0x12B3 | 25–75 (random) | 1.0 | BaseTool | `Scripts/Items/Tools/MalletAndChisel.cs` |
| Fishing Pole (`FishingPole`) | 0x0DC0 | 25–75 (random) | 8.0 | Item, ICraftable, IUsesRemaining, IResource, IQuality | `Scripts/Items/Tools/FishingPole.cs` |
| Sledge Hammer (`SledgeHammer`) | 0xFB5 | 25–75 (random) | tiledata default | BaseTool | `Scripts/Items/Tools/SledgeHammer.cs` |
| Prospectors Tool (`ProspectorsTool`) | 0xFB4, 2 | 2 | 10.0 | BaseBashing | `Scripts/Items/Tools/ProspectorsTool.cs` |

Pickaxe source detail: `public class Pickaxe : BaseAxe, IUsesRemaining, IHarvestTool { [Constructable] public Pickaxe() : base(0xE86) { Weight = 11.0; UsesRemaining = 50; ShowUsesRemaining = true; } public Pickaxe(Serial serial) : base(serial) { } public override HarvestSystem HarvestSystem { get { return Mining.System; } } public override WeaponAbility PrimaryAbility { get { return WeaponAbility.DoubleStrike; } } public override WeaponAb`

---

## 3. BLACKSMITHY RECIPE TABLE

System facts: `DefBlacksmithy : CraftSystem`, main skill `Blacksmith`, gump title cliloc 1044002,
`base(MinCraftEffect 1, MaxCraftEffect 1, Delay 1.25 s)`, `ECA = ChanceMinusSixtyToFourtyFive`,
`GetChanceAtMin = 0.0` (except BritchesOfWarding / GlovesOfFeudalGrip = 0.05),
`Resmelt = true`, `Repair = true`, `MarkOption = true`, `CanEnhance = Core.AOS`, `CanAlter = Core.SA`.
**Station requirement** (`CheckAnvilAndForge`, radius 2): an anvil AND a forge; anvil ids
`4015, 4016, 0x2DD5, 0x2DD6, 0xA102–0xA10D`, forge ids `4017, 6522–6569, 0x2DD8, 0xA531, 0xA535`;
`|Δz| < 16` and line of sight required. Tool must be a blacksmith tool with uses left.
Craft sound 0x2A.

`Source: Scripts/Services/Craft/DefBlacksmithy.cs`

### Blacksmithy — 196 recipes

Source: `Scripts/Services/Craft/DefBlacksmithy.cs`

System config: `Resmelt` = true; `Repair` = true; `MarkOption` = true; `CanEnhance` = Core.AOS; `CanAlter` = Core.SA; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Ringmail Gloves | 12 | 10 × IronIngot (sub-res) | 100% at 62 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Ringmail Legs | 19.4 | 16 × IronIngot (sub-res) | 100% at 69.4 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Ringmail Arms | 16.9 | 14 × IronIngot (sub-res) | 100% at 66.9 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Ringmail Chest | 21.9 | 18 × IronIngot (sub-res) | 100% at 71.9 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Chain Coif | 14.5 | 10 × IronIngot (sub-res) | 100% at 64.5 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Chain Legs | 36.7 | 18 × IronIngot (sub-res) | 100% at 86.7 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Chain Chest | 39.1 | 20 × IronIngot (sub-res) | 100% at 89.1 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Arms | 66.3 | 18 × IronIngot (sub-res) | 100% at 116.3 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Gloves | 58.9 | 12 × IronIngot (sub-res) | 100% at 108.9 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Gorget | 56.4 | 10 × IronIngot (sub-res) | 100% at 106.4 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Legs | 68.8 | 20 × IronIngot (sub-res) | 100% at 118.8 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Chest | 75 | 25 × IronIngot (sub-res) | 100% at 125 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Female Plate Chest | 44.1 | 20 × IronIngot (sub-res) | 100% at 94.1 |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Dragon Barding Deed | 72.5 | 750 × IronIngot (sub-res) | 100% at 122.5; era: AoS |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Mempo | 80 | 18 × IronIngot (sub-res) | 100% at 130; era: Samurai Empire |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Do | 80 | 28 × IronIngot (sub-res) | 100% at 130; era: Samurai Empire |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Hiro Sode | 80 | 16 × IronIngot (sub-res) | 100% at 130; era: Samurai Empire |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Suneate | 65 | 20 × IronIngot (sub-res) | 100% at 115; era: Samurai Empire |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Plate Haidate | 65 | 20 × IronIngot (sub-res) | 100% at 115; era: Samurai Empire |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Female Gargish Plate Arms | 66.3 | 18 × IronIngot (sub-res) | 100% at 116.3; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Female Gargish Plate Chest | 75 | 25 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Female Gargish Plate Legs | 68.8 | 20 × IronIngot (sub-res) | 100% at 118.8; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Female Gargish Plate Kilt | 58.9 | 12 × IronIngot (sub-res) | 100% at 108.9; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Gargish Plate Arms | 66.3 | 18 × IronIngot (sub-res) | 100% at 116.3; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Gargish Plate Chest | 75 | 25 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Gargish Plate Legs | 68.8 | 20 × IronIngot (sub-res) | 100% at 118.8; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Gargish Plate Kilt | 58.9 | 12 × IronIngot (sub-res) | 100% at 108.9; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Gargish Amulet | 60 | 3 × IronIngot (sub-res) | 100% at 110; era: Stygian Abyss |
| Blacksmithy ▸ Metal Armor ⟨1111704⟩ | Britches Of Warding | 120 | 18 × IronIngot (sub-res); 1 × LeggingsOfBane; 4 × Turquoise; 5 × BloodOfTheDarkFather | 100% at 120.1; era: Stygian Abyss; recipe (int)SmithRecipes.BritchesOfWarding; never exceptional |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Bascinet | 8.3 | 15 × IronIngot (sub-res) | 100% at 58.3 |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Close Helm | 37.9 | 15 × IronIngot (sub-res) | 100% at 87.9 |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Helmet | 37.9 | 15 × IronIngot (sub-res) | 100% at 87.9 |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Norse Helm | 37.9 | 15 × IronIngot (sub-res) | 100% at 87.9 |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Plate Helm | 62.6 | 15 × IronIngot (sub-res) | 100% at 112.6 |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Chain Hatsuburi | 30 | 20 × IronIngot (sub-res) | 100% at 80; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Plate Hatsuburi | 45 | 20 × IronIngot (sub-res) | 100% at 95; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Heavy Plate Jingasa | 45 | 20 × IronIngot (sub-res) | 100% at 95; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Light Plate Jingasa | 45 | 20 × IronIngot (sub-res) | 100% at 95; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Small Plate Jingasa | 45 | 20 × IronIngot (sub-res) | 100% at 95; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Decorative Plate Kabuto | 90 | 25 × IronIngot (sub-res) | 100% at 140; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Plate Battle Kabuto | 90 | 25 × IronIngot (sub-res) | 100% at 140; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Standard Plate Kabuto | 90 | 25 × IronIngot (sub-res) | 100% at 140; era: Samurai Empire |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Circlet | 62.1 | 6 × IronIngot (sub-res) | 100% at 112.1; era: Mondain's Legacy |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Royal Circlet | 70 | 6 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Helmets ⟨1011079⟩ | Gemmed Circlet | 75 | 6 × IronIngot (sub-res); 1 × Tourmaline; 1 × Amethyst; 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Buckler | -25 | 10 × IronIngot (sub-res) | 100% at 25 |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Bronze Shield | -15.2 | 12 × IronIngot (sub-res) | 100% at 34.8 |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Heater Shield | 24.3 | 18 × IronIngot (sub-res) | 100% at 74.3 |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Metal Shield | -10.2 | 14 × IronIngot (sub-res) | 100% at 39.8 |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Metal Kite Shield | 4.6 | 16 × IronIngot (sub-res) | 100% at 54.6 |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Wooden Kite Shield | -15.2 | 8 × IronIngot (sub-res) | 100% at 34.8 |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Chaos Shield | 85 | 25 × IronIngot (sub-res) | 100% at 135; era: AoS |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Order Shield | 85 | 25 × IronIngot (sub-res) | 100% at 135; era: AoS |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Small Plate Shield | -25 | 12 × IronIngot (sub-res) | 100% at 25; era: Stygian Abyss |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Gargish Kite Shield | 4.6 | 16 × IronIngot (sub-res) | 100% at 54.6; era: Stygian Abyss |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Large Plate Shield | 24.3 | 18 × IronIngot (sub-res) | 100% at 74.3; era: Stygian Abyss |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Medium Plate Shield | -10.2 | 14 × IronIngot (sub-res) | 100% at 39.8; era: Stygian Abyss |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Gargish Chaos Shield | 85 | 25 × IronIngot (sub-res) | 100% at 135; era: Stygian Abyss |
| Blacksmithy ▸ Shields ⟨1011080⟩ | Gargish Order Shield | 85 | 25 × IronIngot (sub-res) | 100% at 135; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Bone Harvester | 33 | 10 × IronIngot (sub-res) | 100% at 83; era: AoS |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Broadsword | 35.4 | 10 × IronIngot (sub-res) | 100% at 85.4 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Crescent Blade | 45 | 14 × IronIngot (sub-res) | 100% at 95; era: AoS |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Cutlass | 24.3 | 8 × IronIngot (sub-res) | 100% at 74.3 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Dagger | -0.4 | 3 × IronIngot (sub-res) | 100% at 49.6 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Katana | 44.1 | 8 × IronIngot (sub-res) | 100% at 94.1 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Kryss | 36.7 | 8 × IronIngot (sub-res) | 100% at 86.7 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Longsword | 28 | 12 × IronIngot (sub-res) | 100% at 78 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Scimitar | 31.7 | 10 × IronIngot (sub-res) | 100% at 81.7 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Viking Sword | 24.3 | 14 × IronIngot (sub-res) | 100% at 74.3 |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | No Dachi | 75 | 18 × IronIngot (sub-res) | 100% at 125; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Wakizashi | 50 | 8 × IronIngot (sub-res) | 100% at 100; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Lajatang | 80 | 25 × IronIngot (sub-res) | 100% at 130; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Daisho | 60 | 15 × IronIngot (sub-res) | 100% at 110; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Tekagi | 55 | 12 × IronIngot (sub-res) | 100% at 105; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Shuriken | 45 | 5 × IronIngot (sub-res) | 100% at 95; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Kama | 40 | 14 × IronIngot (sub-res) | 100% at 90; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Sai | 50 | 12 × IronIngot (sub-res) | 100% at 100; era: Samurai Empire |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Radiant Scimitar | 75 | 15 × IronIngot (sub-res) | 100% at 125; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | War Cleaver | 70 | 18 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Elven Spellblade | 70 | 14 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Assassin Spike | 70 | 9 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Leafblade | 70 | 12 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Rune Blade | 70 | 15 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Elven Machete | 70 | 14 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Rune Carving Knife | 70 | 9 × IronIngot (sub-res); 1 × DreadHornMane; 10 × Putrefaction; 10 × Muculent | 100% at 120; era: Mondain's Legacy; recipe (int)SmithRecipes.RuneCarvingKnife; never exceptional |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Cold Forged Blade | 70 | 18 × IronIngot (sub-res); 1 × GrizzledBones; 10 × Taint; 10 × Blight | 100% at 120; era: Mondain's Legacy; recipe (int)SmithRecipes.ColdForgedBlade; never exceptional |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Overseer Sundered Blade | 70 | 15 × IronIngot (sub-res); 1 × GrizzledBones; 10 × Blight; 10 × Scourge | 100% at 120; era: Mondain's Legacy; recipe (int)SmithRecipes.OverseerSunderedBlade; never exceptional |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Luminous Rune Blade | 70 | 15 × IronIngot (sub-res); 1 × GrizzledBones; 10 × Corruption; 10 × Putrefaction | 100% at 120; era: Mondain's Legacy; recipe (int)SmithRecipes.LuminousRuneBlade; never exceptional |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | True Spellblade | 75 | 14 × IronIngot (sub-res); 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.TrueSpellblade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Icy Spellblade | 75 | 14 × IronIngot (sub-res); 1 × Turquoise | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.IcySpellblade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Fiery Spellblade | 75 | 14 × IronIngot (sub-res); 1 × FireRuby | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.FierySpellblade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Spellblade Of Defense | 75 | 18 × IronIngot (sub-res); 1 × WhitePearl | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.SpellbladeOfDefense |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | True Assassin Spike | 75 | 9 × IronIngot (sub-res); 1 × DarkSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.TrueAssassinSpike |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Charged Assassin Spike | 75 | 9 × IronIngot (sub-res); 1 × EcruCitrine | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.ChargedAssassinSpike |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Magekiller Assassin Spike | 75 | 9 × IronIngot (sub-res); 1 × BrilliantAmber | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.MagekillerAssassinSpike |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Wounding Assassin Spike | 75 | 9 × IronIngot (sub-res); 1 × PerfectEmerald | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.WoundingAssassinSpike |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | True Leafblade | 75 | 12 × IronIngot (sub-res); 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.TrueLeafblade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Luckblade | 75 | 12 × IronIngot (sub-res); 1 × WhitePearl | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.Luckblade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Magekiller Leafblade | 75 | 12 × IronIngot (sub-res); 1 × FireRuby | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.MagekillerLeafblade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Leafblade Of Ease | 75 | 12 × IronIngot (sub-res); 1 × PerfectEmerald | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.LeafbladeOfEase |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Knights War Cleaver | 75 | 18 × IronIngot (sub-res); 1 × PerfectEmerald | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.KnightsWarCleaver |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Butchers War Cleaver | 75 | 18 × IronIngot (sub-res); 1 × Turquoise | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.ButchersWarCleaver |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Serrated War Cleaver | 75 | 18 × IronIngot (sub-res); 1 × EcruCitrine | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.SerratedWarCleaver |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | True War Cleaver | 75 | 18 × IronIngot (sub-res); 1 × BrilliantAmber | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.TrueWarCleaver |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Adventurers Machete | 75 | 14 × IronIngot (sub-res); 1 × WhitePearl | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.AdventurersMachete |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Orcish Machete | 75 | 14 × IronIngot (sub-res); 1 × Scourge | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.OrcishMachete |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Machete Of Defense | 75 | 14 × IronIngot (sub-res); 1 × BrilliantAmber | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.MacheteOfDefense |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Diseased Machete | 75 | 14 × IronIngot (sub-res); 1 × Blight | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.DiseasedMachete |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Runesabre | 75 | 15 × IronIngot (sub-res); 1 × Turquoise | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.Runesabre |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Mages Rune Blade | 75 | 15 × IronIngot (sub-res); 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.MagesRuneBlade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Rune Blade Of Knowledge | 75 | 15 × IronIngot (sub-res); 1 × EcruCitrine | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.RuneBladeOfKnowledge |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Corrupted Rune Blade | 75 | 15 × IronIngot (sub-res); 1 × Corruption | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.CorruptedRuneBlade |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | True Radiant Scimitar | 75 | 15 × IronIngot (sub-res); 1 × BrilliantAmber | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.TrueRadiantScimitar |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Darkglow Scimitar | 75 | 15 × IronIngot (sub-res); 1 × DarkSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.DarkglowScimitar |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Icy Scimitar | 75 | 15 × IronIngot (sub-res); 1 × DarkSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.IcyScimitar |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Twinkling Scimitar | 75 | 15 × IronIngot (sub-res); 1 × DarkSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.TwinklingScimitar |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Bone Machete | 45 | 20 × IronIngot (sub-res); 6 × Bone | 100% at 95; era: Mondain's Legacy; recipe (int)SmithRecipes.BoneMachete |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Katana | 44.1 | 8 × IronIngot (sub-res) | 100% at 94.1; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Kryss | 36.7 | 8 × IronIngot (sub-res) | 100% at 86.7; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Bone Harvester | 33 | 10 × IronIngot (sub-res) | 100% at 83; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Tekagi | 55 | 12 × IronIngot (sub-res) | 100% at 105; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Daisho | 60 | 15 × IronIngot (sub-res) | 100% at 110; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Dread Sword | 75 | 14 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Talwar | 75 | 18 × IronIngot (sub-res) | 100% at 150; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Gargish Dagger | 0 | 3 × IronIngot (sub-res) | 100% at 100; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Blood Blade | 44.1 | 8 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Bladed ⟨1011081⟩ | Shortblade | 28 | 12 × IronIngot (sub-res) | 100% at 100; era: Stygian Abyss |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Axe | 34.2 | 14 × IronIngot (sub-res) | 100% at 84.2 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Battle Axe | 30.5 | 14 × IronIngot (sub-res) | 100% at 80.5 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Double Axe | 29.3 | 12 × IronIngot (sub-res) | 100% at 79.3 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Executioners Axe | 34.2 | 14 × IronIngot (sub-res) | 100% at 84.2 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Large Battle Axe | 28 | 12 × IronIngot (sub-res) | 100% at 78 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Two Handed Axe | 33 | 16 × IronIngot (sub-res) | 100% at 83 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | War Axe | 39.1 | 16 × IronIngot (sub-res) | 100% at 89.1 |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Ornate Axe | 70 | 18 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Guardian Axe | 75 | 15 × IronIngot (sub-res); 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.GuardianAxe |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Singing Axe | 75 | 15 × IronIngot (sub-res); 1 × BrilliantAmber | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.SingingAxe |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Thundering Axe | 75 | 15 × IronIngot (sub-res); 1 × EcruCitrine | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.ThunderingAxe |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Heavy Ornate Axe | 75 | 15 × IronIngot (sub-res); 1 × Turquoise | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.HeavyOrnateAxe |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Gargish Battle Axe | 30.5 | 14 × IronIngot (sub-res) | 100% at 80.5; era: Stygian Abyss |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Gargish Axe | 34.2 | 14 × IronIngot (sub-res) | 100% at 84.2; era: Stygian Abyss |
| Blacksmithy ▸ Axes ⟨1011082⟩ | Dual Short Axes | 75 | 24 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Bardiche | 31.7 | 18 × IronIngot (sub-res) | 100% at 81.7 |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Bladed Staff | 40 | 12 × IronIngot (sub-res) | 100% at 90; era: AoS |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Double Bladed Staff | 45 | 16 × IronIngot (sub-res) | 100% at 95; era: AoS |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Halberd | 39.1 | 20 × IronIngot (sub-res) | 100% at 89.1 |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Lance | 48 | 20 × IronIngot (sub-res) | 100% at 98; era: AoS |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Pike | 47 | 12 × IronIngot (sub-res) | 100% at 97; era: AoS |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Short Spear | 45.3 | 6 × IronIngot (sub-res) | 100% at 95.3 |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Scythe | 39 | 14 × IronIngot (sub-res) | 100% at 89; era: AoS |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Spear | 49 | 12 × IronIngot (sub-res) | 100% at 99 |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | War Fork | 42.9 | 12 × IronIngot (sub-res) | 100% at 92.9 |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Gargish Bardiche | 31.7 | 18 × IronIngot (sub-res) | 100% at 81.7; era: Stygian Abyss |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Gargish War Fork | 42.9 | 12 × IronIngot (sub-res) | 100% at 92.9; era: Stygian Abyss |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Gargish Scythe | 39 | 14 × IronIngot (sub-res) | 100% at 89; era: Stygian Abyss |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Gargish Pike | 47 | 12 × IronIngot (sub-res) | 100% at 97; era: Stygian Abyss |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Gargish Lance | 48 | 20 × IronIngot (sub-res) | 100% at 98; era: Stygian Abyss |
| Blacksmithy ▸ Pole Arms ⟨1011083⟩ | Dual Pointed Spear | 47 | 16 × IronIngot (sub-res) | 100% at 97; era: Stygian Abyss |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Hammer Pick | 34.2 | 16 × IronIngot (sub-res) | 100% at 84.2 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Mace | 14.5 | 6 × IronIngot (sub-res) | 100% at 64.5 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Maul | 19.4 | 10 × IronIngot (sub-res) | 100% at 69.4 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Scepter | 21.4 | 10 × IronIngot (sub-res) | 100% at 71.4; era: AoS |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | War Mace | 28 | 14 × IronIngot (sub-res) | 100% at 78 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | War Hammer | 34.2 | 16 × IronIngot (sub-res) | 100% at 84.2 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Tessen | 85 | 16 × IronIngot (sub-res); 10 × Cloth | 100% at 135; era: Samurai Empire; also needs Tailoring 50–55 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Diamond Mace | 70 | 20 × IronIngot (sub-res) | 100% at 120; era: Mondain's Legacy |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Shard Thrasher | 70 | 20 × IronIngot (sub-res); 1 × EyeOfTheTravesty; 10 × Muculent; 10 × Corruption | 100% at 120; era: Mondain's Legacy; recipe (int)SmithRecipes.ShardTrasher; never exceptional |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Ruby Mace | 75 | 20 × IronIngot (sub-res); 1 × FireRuby | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.RubyMace |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Emerald Mace | 75 | 20 × IronIngot (sub-res); 1 × PerfectEmerald | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.EmeraldMace |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Sapphire Mace | 75 | 20 × IronIngot (sub-res); 1 × DarkSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.SapphireMace |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Silver Etched Mace | 75 | 20 × IronIngot (sub-res); 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy; recipe (int)SmithRecipes.SilverEtchedMace |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Gargish War Hammer | 34.2 | 16 × IronIngot (sub-res) | 100% at 84.2; era: Stygian Abyss |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Gargish Maul | 19.4 | 10 × IronIngot (sub-res) | 100% at 69.4; era: Stygian Abyss |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Gargish Tessen | 85 | 16 × IronIngot (sub-res); 10 × Cloth | 100% at 135; era: Stygian Abyss; also needs Tailoring 50–55 |
| Blacksmithy ▸ Bashing ⟨1011084⟩ | Disc Mace | 70 | 20 × IronIngot (sub-res) | 100% at 120; era: Stygian Abyss |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Cannonball | 10 | 12 × IronIngot (sub-res) | 100% at 60; era: Endless Journey; consumes whole stack (batch) |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Light Cannonball | 0 | 6 × IronIngot (sub-res) | 100% at 50; era: High Seas |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Heavy Cannonball | 10 | 12 × IronIngot (sub-res) | 100% at 60; era: High Seas |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Grapeshot | 15 | 12 × IronIngot (sub-res); 2 × Cloth | 100% at 70; era: Endless Journey; consumes whole stack (batch) |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Light Grapeshot | 0 | 6 × IronIngot (sub-res); 1 × Cloth | 100% at 50; era: High Seas |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Heavy Grapeshot | 15 | 12 × IronIngot (sub-res); 2 × Cloth | 100% at 70; era: High Seas |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Light Ship Cannon Deed | 65 | 900 × IronIngot (sub-res); 50 × Board | 100% at 120; era: High Seas; also needs Carpentry 65–100 |
| Blacksmithy ▸ Cannons (High Seas) ⟨1116354⟩ | Heavy Ship Cannon Deed | 70 | 1800 × IronIngot (sub-res); 75 × Board | 100% at 120; era: High Seas; also needs Carpentry 70–100 |
| Blacksmithy ▸ Throwing (gargoyle) ⟨1079508⟩ | Boomerang | 75 | 5 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Throwing (gargoyle) ⟨1079508⟩ | Cyclone | 75 | 9 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Throwing (gargoyle) ⟨1079508⟩ | Soul Glaive | 75 | 9 × IronIngot (sub-res) | 100% at 125; era: Stygian Abyss |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Dragon Gloves | 68.9 | 16 × RedScales (sub-res) | 100% at 118.9; uses 2nd sub-res list (dragon scales) |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Dragon Helm | 72.6 | 20 × RedScales (sub-res) | 100% at 122.6; uses 2nd sub-res list (dragon scales) |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Dragon Legs | 78.8 | 28 × RedScales (sub-res) | 100% at 128.8; uses 2nd sub-res list (dragon scales) |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Dragon Arms | 76.3 | 24 × RedScales (sub-res) | 100% at 126.3; uses 2nd sub-res list (dragon scales) |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Dragon Chest | 85 | 36 × RedScales (sub-res) | 100% at 135; uses 2nd sub-res list (dragon scales) |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Crushed Glass | 110 | 1 × BlueDiamond; 5 × GlassSword | 100% at 135; era: Stygian Abyss |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Powdered Iron | 110 | 1 × WhitePearl; 20 × IronIngot | 100% at 135; era: Stygian Abyss |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Metal Keg | 85 | 25 × IronIngot (sub-res) | 100% at 100 |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Exodus Sacrifical Dagger | 95 | 12 × IronIngot (sub-res); 2 × BlueDiamond; 2 × FireRuby; 10 × SmallPieceofBlackrock | 100% at 120; era: Stygian Abyss; never exceptional |
| Blacksmithy ▸ Miscellaneous ⟨1011173⟩ | Gloves Of Feudal Grip | 120 | 18 × RedScales (sub-res); 4 × BlueDiamond; 1 × GauntletsOfNobility; 5 × BloodOfTheDarkFather | 100% at 120.1; era: Stygian Abyss; recipe (int)SmithRecipes.GlovesOfFeudalGrip; never exceptional; uses 2nd sub-res list (dragon scales) |


---

## 4. TAILORING RECIPE TABLE

System facts: main skill `Tailoring`, gump title cliloc 1044003, `base(1, 1, 1.25)`,
`ECA = ChanceMinusSixtyToFourtyFive`, `GetChanceAtMin = 0.5` (50 % floor for all recipes except four
artefacts at 0.05), `MarkOption = true`, `Repair = Core.AOS`, `CanEnhance = Core.ML`,
`CanAlter = Core.SA`, no station requirement (only a sewing kit / scissors-type tool with uses).
Sub-resources: leather grades (§2.3).

`Source: Scripts/Services/Craft/DefTailoring.cs`

### Tailoring — 198 recipes

Source: `Scripts/Services/Craft/DefTailoring.cs`

System config: `Repair` = Core.AOS; `MarkOption` = true; `CanEnhance` = Core.ML; `CanAlter` = Core.SA; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Tailoring ▸ Materials ⟨1044457⟩ | Cut Up Cloth | 0 | 1 × BoltOfCloth | 100% at 0 |
| Tailoring ▸ Materials ⟨1044457⟩ | Combine Cloth | 0 | 1 × Cloth | 100% at 0 |
| Tailoring ▸ Materials ⟨1044457⟩ | Powder Charge | 0 | 1 × Cloth; 4 × BlackPowder | 100% at 50; era: Endless Journey; consumes whole stack (batch) |
| Tailoring ▸ Materials ⟨1044457⟩ | Light Powder Charge | 0 | 1 × Cloth; 1 × BlackPowder | 100% at 50; era: High Seas |
| Tailoring ▸ Materials ⟨1044457⟩ | Heavy Powder Charge | 0 | 1 × Cloth; 4 × BlackPowder | 100% at 50; era: High Seas |
| Tailoring ▸ Materials ⟨1044457⟩ | Abyssal Cloth | 110 | 50 × Cloth; 1 × CrystallineBlackrock | 100% at 160; era: Stygian Abyss; ih=2075 |
| Tailoring ▸ Hats ⟨1011375⟩ | Skull Cap | 0 | 2 × Cloth | 100% at 25 |
| Tailoring ▸ Hats ⟨1011375⟩ | Bandana | 0 | 2 × Cloth | 100% at 25 |
| Tailoring ▸ Hats ⟨1011375⟩ | Floppy Hat | 6.2 | 11 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Cap | 6.2 | 11 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Wide Brim Hat | 6.2 | 12 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Straw Hat | 6.2 | 10 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Tall Straw Hat | 6.7 | 13 × Cloth | 100% at 31.7 |
| Tailoring ▸ Hats ⟨1011375⟩ | Wizards Hat | 7.2 | 15 × Cloth | 100% at 32.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Bonnet | 6.2 | 11 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Feathered Hat | 6.2 | 12 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Tricorne Hat | 6.2 | 12 × Cloth | 100% at 31.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Jester Hat | 7.2 | 15 × Cloth | 100% at 32.2 |
| Tailoring ▸ Hats ⟨1011375⟩ | Flower Garland | 10 | 5 × Cloth | 100% at 35; era: AoS |
| Tailoring ▸ Hats ⟨1011375⟩ | Cloth Ninja Hood | 80 | 13 × Cloth | 100% at 105; era: Samurai Empire |
| Tailoring ▸ Hats ⟨1011375⟩ | Kasa | 60 | 12 × Cloth | 100% at 85; era: Samurai Empire |
| Tailoring ▸ Hats ⟨1011375⟩ | Orc Mask | 75 | 12 × Cloth | 100% at 100 |
| Tailoring ▸ Hats ⟨1011375⟩ | Bear Mask | 77.5 | 15 × Cloth | 100% at 102.5 |
| Tailoring ▸ Hats ⟨1011375⟩ | Deer Mask | 77.5 | 15 × Cloth | 100% at 102.5 |
| Tailoring ▸ Hats ⟨1011375⟩ | Tribal Mask | 82.5 | 12 × Cloth | 100% at 107.5 |
| Tailoring ▸ Hats ⟨1011375⟩ | Horned Tribal Mask | 82.5 | 12 × Cloth | 100% at 107.5 |
| Tailoring ▸ Hats ⟨1011375⟩ | Chefs Toque | 6.2 | 11 × Cloth | 100% at 21.2; era: Time of Legends; recipe (int)TailorRecipe.ChefsToque |
| Tailoring ▸ Hats ⟨1011375⟩ | Krampus Minion Hat | 100 | 8 × Cloth | 100% at 500; recipe (int)TailorRecipe.KrampusMinionHat |
| Tailoring ▸ Hats ⟨1011375⟩ | Assassins Cowl | 90 | 5 × Cloth; 5 × Leather; 5 × VileTentacles | 100% at 110; era: Endless Journey; recipe (int)TailorRecipe.AssassinsCowl |
| Tailoring ▸ Hats ⟨1011375⟩ | Mages Hood | 90 | 5 × Cloth; 5 × Leather; 5 × VoidCore | 100% at 110; era: Endless Journey; recipe (int)TailorRecipe.MagesHood |
| Tailoring ▸ Hats ⟨1011375⟩ | Cowl Of The Mace And Shield | 120 | 5 × Cloth; 5 × Leather; 1 × MaceAndShieldGlasses; 10 × VileTentacles | 100% at 215; era: Endless Journey; recipe (int)TailorRecipe.CowlOfTheMaceAndShield; always exceptional |
| Tailoring ▸ Hats ⟨1011375⟩ | Mages Hood Of Scholarly Insight | 120 | 5 × Cloth; 5 × Leather; 1 × TheScholarsHalo; 10 × VoidCore | 100% at 215; era: Endless Journey; recipe (int)TailorRecipe.MagesHoodOfScholarlyInsight; always exceptional |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Doublet | 0 | 8 × Cloth | 100% at 25 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Shirt | 20.7 | 8 × Cloth | 100% at 45.7 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Fancy Shirt | 24.8 | 8 × Cloth | 100% at 49.8 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Tunic | 0 | 12 × Cloth | 100% at 25 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Surcoat | 8.2 | 14 × Cloth | 100% at 33.2 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Plain Dress | 12.4 | 10 × Cloth | 100% at 37.4 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Fancy Dress | 33.1 | 12 × Cloth | 100% at 58.1 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Cloak | 41.4 | 14 × Cloth | 100% at 66.4 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Robe | 53.9 | 16 × Cloth | 100% at 78.9 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Jester Suit | 8.2 | 24 × Cloth | 100% at 33.2 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Fur Cape | 35 | 13 × Cloth | 100% at 60; era: AoS |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Gilded Dress | 37.5 | 16 × Cloth | 100% at 62.5; era: AoS |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Formal Shirt | 26 | 16 × Cloth | 100% at 51; era: AoS |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Cloth Ninja Jacket | 75 | 12 × Cloth | 100% at 100; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Kamishimo | 75 | 15 × Cloth | 100% at 100; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Hakama Shita | 40 | 14 × Cloth | 100% at 65; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Male Kimono | 50 | 16 × Cloth | 100% at 75; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Female Kimono | 50 | 16 × Cloth | 100% at 75; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Jin Baori | 30 | 12 × Cloth | 100% at 55; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Short Pants | 24.8 | 6 × Cloth | 100% at 49.8 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Long Pants | 24.8 | 8 × Cloth | 100% at 49.8 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Kilt | 20.7 | 8 × Cloth | 100% at 45.7 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Skirt | 29 | 10 × Cloth | 100% at 54 |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Fur Sarong | 35 | 12 × Cloth | 100% at 60; era: AoS |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Hakama | 50 | 16 × Cloth | 100% at 75; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Tattsuke Hakama | 50 | 16 × Cloth | 100% at 75; era: Samurai Empire |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Elven Shirt | 80 | 10 × Cloth | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Elven Dark Shirt | 80 | 10 × Cloth | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Elven Pants | 80 | 12 × Cloth | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Male Elven Robe | 80 | 30 × Cloth | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Female Elven Robe | 80 | 30 × Cloth | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Woodland Belt | 80 | 10 × Cloth | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Gargish Robe | 53.9 | 16 × Cloth | 100% at 78.9; era: Stygian Abyss |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Gargish Fancy Robe | 53.9 | 16 × Cloth | 100% at 78.9; era: Stygian Abyss |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Robeof Rite | 101.5 | 6 × Leather (sub-res); 1 × FireRuby; 5 × GoldDust; 6 × AbyssalCloth | 100% at 120; era: Stygian Abyss; never exceptional |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Guilded Kilt | 82.8 | 8 × Cloth | 100% at 97.8; era: Time of Legends; recipe (int)TailorRecipe.GuildedKilt |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Checkered Kilt | 41.4 | 8 × Cloth | 100% at 56.4; era: Time of Legends; recipe (int)TailorRecipe.CheckeredKilt |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Fancy Kilt | 20.7 | 8 × Cloth | 100% at 25.7; era: Time of Legends; recipe (int)TailorRecipe.FancyKilt |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Flowered Dress | 75 | 18 × Cloth | 100% at 90; era: Time of Legends; recipe (int)TailorRecipe.FloweredDress |
| Tailoring ▸ Cloth (clothing) ⟨1111747⟩ | Evening Gown | 75 | 18 × Cloth | 100% at 90; era: Time of Legends; recipe (int)TailorRecipe.EveningGown |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Body Sash | 4.1 | 4 × Cloth | 100% at 29.1 |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Half Apron | 20.7 | 6 × Cloth | 100% at 45.7 |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Full Apron | 29 | 10 × Cloth | 100% at 54 |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Obi | 20 | 6 × Cloth | 100% at 45; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Elven Quiver | 65 | 28 × Leather (sub-res) | 100% at 115; era: Mondain's Legacy; recipe (int)TailorRecipe.ElvenQuiver |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Quiver Of Fire | 65 | 28 × Leather (sub-res); 15 × FireRuby | 100% at 115; era: Mondain's Legacy; recipe (int)TailorRecipe.QuiverOfFire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Quiver Of Ice | 65 | 28 × Leather (sub-res); 15 × WhitePearl | 100% at 115; era: Mondain's Legacy; recipe (int)TailorRecipe.QuiverOfIce |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Quiver Of Blight | 65 | 28 × Leather (sub-res); 10 × Blight | 100% at 115; era: Mondain's Legacy; recipe (int)TailorRecipe.QuiverOfBlight |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Quiver Of Lightning | 65 | 28 × Leather (sub-res); 10 × Corruption | 100% at 115; era: Mondain's Legacy; recipe (int)TailorRecipe.QuiverOfLightning |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Leather Container Engraver | 75 | 1 × Bone; 6 × Leather; 2 × SpoolOfThread; 1 × Dyes | 100% at 100; era: Mondain's Legacy |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Gargoyle Half Apron | 20.7 | 6 × Cloth | 100% at 45.7; era: Stygian Abyss |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Gargish Sash | 4.1 | 4 × Cloth | 100% at 29.1; era: Stygian Abyss |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Oil Cloth | 74.6 | 1 × Cloth | 100% at 99.6 |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Goza Mat East Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Goza Mat South Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Square Goza Mat East Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Square Goza Mat South Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Brocade Goza Mat East Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Brocade Goza Mat South Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Brocade Square Goza Mat East Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Brocade Square Goza Mat South Deed | 55 | 25 × Cloth | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Mace Belt | 90 | 5 × Cloth; 5 × Leather; 5 × Lodestone | 100% at 110; era: Endless Journey; recipe (int)TailorRecipe.MaceBelt |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Sword Belt | 90 | 5 × Cloth; 5 × Leather; 5 × Lodestone | 100% at 110; era: Endless Journey; recipe (int)TailorRecipe.SwordBelt |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Dagger Belt | 90 | 5 × Cloth; 5 × Leather; 5 × Lodestone | 100% at 110; era: Endless Journey; recipe (int)TailorRecipe.DaggerBelt |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Elegant Collar | 90 | 5 × Cloth; 5 × Leather; 5 × FeyWings | 100% at 110; era: Endless Journey; recipe (int)TailorRecipe.ElegantCollar |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Crimson Mace Belt | 120 | 5 × Cloth; 5 × Leather; 1 × CrimsonCincture; 10 × Lodestone | 100% at 215; era: Endless Journey; recipe (int)TailorRecipe.CrimsonMaceBelt; always exceptional |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Crimson Sword Belt | 120 | 5 × Cloth; 5 × Leather; 1 × CrimsonCincture; 10 × Lodestone | 100% at 215; era: Endless Journey; recipe (int)TailorRecipe.CrimsonSwordBelt; always exceptional |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Crimson Dagger Belt | 120 | 5 × Cloth; 5 × Leather; 1 × CrimsonCincture; 10 × Lodestone | 100% at 215; era: Endless Journey; recipe (int)TailorRecipe.CrimsonDaggerBelt; always exceptional |
| Tailoring ▸ Miscellaneous ⟨1015283⟩ | Elegant Collar Of Fortune | 120 | 5 × Cloth; 5 × Leather; 1 × LeurociansMempoOfFortune; 10 × FeyWings | 100% at 215; era: Endless Journey; recipe (int)TailorRecipe.ElegantCollarOfFortune; always exceptional |
| Tailoring ▸ Footwear ⟨1015288⟩ | Elven Boots | 80 | 15 × Leather (sub-res) | 100% at 105; era: Mondain's Legacy |
| Tailoring ▸ Footwear ⟨1015288⟩ | Fur Boots | 50 | 12 × Cloth | 100% at 75; era: AoS |
| Tailoring ▸ Footwear ⟨1015288⟩ | Ninja Tabi | 70 | 10 × Cloth | 100% at 95; era: Samurai Empire |
| Tailoring ▸ Footwear ⟨1015288⟩ | Samurai Tabi | 20 | 6 × Cloth | 100% at 45; era: Samurai Empire |
| Tailoring ▸ Footwear ⟨1015288⟩ | Sandals | 12.4 | 4 × Leather (sub-res) | 100% at 37.4 |
| Tailoring ▸ Footwear ⟨1015288⟩ | Shoes | 16.5 | 6 × Leather (sub-res) | 100% at 41.5 |
| Tailoring ▸ Footwear ⟨1015288⟩ | Boots | 33.1 | 8 × Leather (sub-res) | 100% at 58.1 |
| Tailoring ▸ Footwear ⟨1015288⟩ | Thigh Boots | 41.4 | 10 × Leather (sub-res) | 100% at 66.4 |
| Tailoring ▸ Footwear ⟨1015288⟩ | Leather Talons | 40.4 | 6 × Leather (sub-res) | 100% at 65.4; era: Stygian Abyss |
| Tailoring ▸ Footwear ⟨1015288⟩ | Jester Shoes | 20 | 6 × Cloth | 100% at 35; era: Time of Legends; recipe (int)TailorRecipe.JesterShoes |
| Tailoring ▸ Footwear ⟨1015288⟩ | Krampus Minion Boots | 100 | 6 × Leather (sub-res); 4 × Cloth | 100% at 500; recipe (int)TailorRecipe.KrampusMinionBoots |
| Tailoring ▸ Footwear ⟨1015288⟩ | Krampus Minion Talons | 100 | 6 × Leather (sub-res); 4 × Cloth | 100% at 500; recipe (int)TailorRecipe.KrampusMinionTalons |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Spell Woven Britches | 92.5 | 15 × Leather (sub-res); 1 × EyeOfTheTravesty; 10 × Putrefaction; 10 × Scourge | 100% at 117.5; era: Mondain's Legacy; recipe (int)TailorRecipe.SpellWovenBritches; never exceptional |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Song Woven Mantle | 92.5 | 15 × Leather (sub-res); 1 × EyeOfTheTravesty; 10 × Blight; 10 × Muculent | 100% at 117.5; era: Mondain's Legacy; recipe (int)TailorRecipe.SongWovenMantle; never exceptional |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Stitchers Mittens | 92.5 | 15 × Leather (sub-res); 1 × CapturedEssence; 10 × Corruption; 10 × Taint | 100% at 117.5; era: Mondain's Legacy; recipe (int)TailorRecipe.StitchersMittens; never exceptional |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Gorget | 53.9 | 4 × Leather (sub-res) | 100% at 78.9 |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Cap | 6.2 | 2 × Leather (sub-res) | 100% at 31.2 |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Gloves | 51.8 | 3 × Leather (sub-res) | 100% at 76.8 |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Arms | 53.9 | 4 × Leather (sub-res) | 100% at 78.9 |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Legs | 66.3 | 10 × Leather (sub-res) | 100% at 91.3 |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Chest | 70.5 | 12 × Leather (sub-res) | 100% at 95.5 |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Jingasa | 45 | 4 × Leather (sub-res) | 100% at 70; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Mempo | 80 | 8 × Leather (sub-res) | 100% at 105; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Do | 75 | 12 × Leather (sub-res) | 100% at 100; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Hiro Sode | 55 | 5 × Leather (sub-res) | 100% at 80; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Suneate | 68 | 12 × Leather (sub-res) | 100% at 93; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Haidate | 68 | 12 × Leather (sub-res) | 100% at 93; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Ninja Pants | 80 | 13 × Leather (sub-res) | 100% at 105; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Ninja Jacket | 85 | 13 × Leather (sub-res) | 100% at 110; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Ninja Belt | 50 | 5 × Leather (sub-res) | 100% at 75; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Ninja Mitts | 65 | 12 × Leather (sub-res) | 100% at 90; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leather Ninja Hood | 90 | 14 × Leather (sub-res) | 100% at 115; era: Samurai Empire |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leaf Chest | 75 | 15 × Leather (sub-res) | 100% at 100; era: Mondain's Legacy |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leaf Arms | 60 | 12 × Leather (sub-res) | 100% at 85; era: Mondain's Legacy |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leaf Gloves | 60 | 10 × Leather (sub-res) | 100% at 85; era: Mondain's Legacy |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leaf Legs | 75 | 15 × Leather (sub-res) | 100% at 100; era: Mondain's Legacy |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leaf Gorget | 65 | 12 × Leather (sub-res) | 100% at 90; era: Mondain's Legacy |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Leaf Tonlet | 70 | 12 × Leather (sub-res) | 100% at 95; era: Mondain's Legacy |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Gargish Leather Arms | 53.9 | 8 × Leather (sub-res) | 100% at 78.9; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Gargish Leather Chest | 70.5 | 8 × Leather (sub-res) | 100% at 95.5; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Gargish Leather Legs | 66.3 | 10 × Leather (sub-res) | 100% at 91.3; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Gargish Leather Kilt | 58 | 6 × Leather (sub-res) | 100% at 83; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Female Gargish Leather Arms | 53.9 | 8 × Leather (sub-res) | 100% at 78.9; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Female Gargish Leather Chest | 70.5 | 8 × Leather (sub-res) | 100% at 95.5; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Female Gargish Leather Legs | 66.3 | 10 × Leather (sub-res) | 100% at 91.3; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Female Gargish Leather Kilt | 58 | 6 × Leather (sub-res) | 100% at 83; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Gargish Leather Wing Armor | 65 | 12 × Leather (sub-res) | 100% at 90; era: Stygian Abyss |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Tiger Pelt Chest | 90 | 8 × Leather (sub-res); 4 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltChest |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Tiger Pelt Legs | 90 | 8 × Leather (sub-res); 4 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltLegs |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Tiger Pelt Shorts | 90 | 4 × Leather (sub-res); 2 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltShorts |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Tiger Pelt Helm | 90 | 2 × Leather (sub-res); 1 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltHelm |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Tiger Pelt Collar | 90 | 2 × Leather (sub-res); 1 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltCollar |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Dragon Turtle Hide Chest | 101.5 | 8 × Leather (sub-res); 2 × DragonTurtleScute | 100% at 116.5; era: Time of Legends; recipe (int)TailorRecipe.DragonTurtleHideChest |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Dragon Turtle Hide Legs | 101.5 | 8 × Leather (sub-res); 4 × DragonTurtleScute | 100% at 116.5; era: Time of Legends; recipe (int)TailorRecipe.DragonTurtleHideLegs |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Dragon Turtle Hide Helm | 101.5 | 2 × Leather (sub-res); 1 × DragonTurtleScute | 100% at 116.5; era: Time of Legends; recipe (int)TailorRecipe.DragonTurtleHideHelm |
| Tailoring ▸ Leather Armor ⟨1015293⟩ | Dragon Turtle Hide Arms | 101.5 | 4 × Leather (sub-res); 2 × DragonTurtleScute | 100% at 116.5; era: Time of Legends; recipe (int)TailorRecipe.DragonTurtleHideArms |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Gargish Cloth Arms Armor | 87.1 | 8 × Cloth | 100% at 137.1; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Gargish Cloth Chest Armor | 94 | 8 × Cloth | 100% at 144; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Gargish Cloth Legs Armor | 91.2 | 10 × Cloth | 100% at 141.2; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Gargish Cloth Kilt Armor | 82.9 | 6 × Cloth | 100% at 132.9; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Female Gargish Cloth Arms Armor | 87.1 | 8 × Cloth | 100% at 137.1; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Female Gargish Cloth Chest Armor | 94 | 8 × Cloth | 100% at 144; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Female Gargish Cloth Legs Armor | 91.2 | 10 × Cloth | 100% at 141.2; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Female Gargish Cloth Kilt Armor | 82.9 | 6 × Cloth | 100% at 132.9; era: Stygian Abyss |
| Tailoring ▸ Gargish Cloth Armor ⟨1111748⟩ | Gargish Cloth Wing Armor | 65 | 12 × Cloth | 100% at 90; era: Stygian Abyss |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Gorget | 78.8 | 6 × Leather (sub-res) | 100% at 103.8 |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Gloves | 82.9 | 8 × Leather (sub-res) | 100% at 107.9 |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Arms | 87.1 | 10 × Leather (sub-res) | 100% at 112.1 |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Legs | 91.2 | 12 × Leather (sub-res) | 100% at 116.2 |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Chest | 94 | 14 × Leather (sub-res) | 100% at 119 |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Mempo | 80 | 8 × Leather (sub-res) | 100% at 105; era: Samurai Empire |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Do | 95 | 14 × Leather (sub-res) | 100% at 120; era: Samurai Empire |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Hiro Sode | 85 | 8 × Leather (sub-res) | 100% at 110; era: Samurai Empire |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Suneate | 92 | 14 × Leather (sub-res) | 100% at 117; era: Samurai Empire |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Studded Haidate | 92 | 14 × Leather (sub-res) | 100% at 117; era: Samurai Empire |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Hide Chest | 85 | 15 × Leather (sub-res) | 100% at 110; era: Mondain's Legacy |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Hide Pauldrons | 75 | 12 × Leather (sub-res) | 100% at 100; era: Mondain's Legacy |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Hide Gloves | 75 | 10 × Leather (sub-res) | 100% at 100; era: Mondain's Legacy |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Hide Pants | 92 | 15 × Leather (sub-res) | 100% at 117; era: Mondain's Legacy |
| Tailoring ▸ Studded Armor ⟨1015300⟩ | Hide Gorget | 90 | 12 × Leather (sub-res) | 100% at 115; era: Mondain's Legacy |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Leather Shorts | 62.2 | 8 × Leather (sub-res) | 100% at 87.2 |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Leather Skirt | 58 | 6 × Leather (sub-res) | 100% at 83 |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Leather Bustier Arms | 58 | 6 × Leather (sub-res) | 100% at 83 |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Studded Bustier Arms | 82.9 | 8 × Leather (sub-res) | 100% at 107.9 |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Female Leather Chest | 62.2 | 8 × Leather (sub-res) | 100% at 87.2 |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Female Studded Chest | 87.1 | 10 × Leather (sub-res) | 100% at 112.1 |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Tiger Pelt Bustier | 90 | 6 × Leather (sub-res); 3 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltBustier |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Tiger Pelt Long Skirt | 90 | 4 × Leather (sub-res); 2 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltLongSkirt |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Tiger Pelt Skirt | 90 | 4 × Leather (sub-res); 2 × TigerPelt | 100% at 115; era: Time of Legends; recipe (int)TailorRecipe.TigerPeltSkirt |
| Tailoring ▸ Female Armor ⟨1015306⟩ | Dragon Turtle Hide Bustier | 101.5 | 6 × Leather (sub-res); 3 × DragonTurtleScute | 100% at 116.5; era: Time of Legends; recipe (int)TailorRecipe.DragonTurtleHideBustier |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Bone Helm | 85 | 4 × Leather (sub-res); 2 × Bone | 100% at 110 |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Bone Gloves | 89 | 6 × Leather (sub-res); 2 × Bone | 100% at 114 |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Bone Arms | 92 | 8 × Leather (sub-res); 4 × Bone | 100% at 117 |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Bone Legs | 95 | 10 × Leather (sub-res); 6 × Bone | 100% at 120 |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Bone Chest | 96 | 12 × Leather (sub-res); 10 × Bone | 100% at 121 |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Orc Helm | 90 | 6 × Leather (sub-res); 4 × Bone | 100% at 115 |
| Tailoring ▸ Bone Armor ⟨1049149⟩ | Cuffs Of The Archmage | 120 | 8 × Cloth; 1 × MidnightBracers; 5 × BloodOfTheDarkFather; 5 × DarkSapphire | 100% at 120.1; era: Stygian Abyss; recipe (int)TailorRecipe.CuffsOfTheArchmage; never exceptional |


---

## 5. OTHER CRAFTING SKILLS

### 5.0 T2A / pre-AoS craft menu structure (for an era-faithful clone)

`ModernUO: dev-docs/t2a-crafting.md` documents the packet-based (`0x7C`/`0x7D`) item-list crafting UI used
before Publish 14 (2001-11-30). Key mechanical facts that differ from the modern gump:

| rule | T2A behaviour |
|---|---|
| Resource selection | player targets the resource **before** the menu opens; menu shows only craftable rows |
| Failure | resources are reduced by **half** per stack (`amounts[i] -= amounts[i]/2`, integer division) — reconstruction, not OSI-confirmed |
| Scribing | each reagent + the single blank scroll is fully consumed on failure (amount-1 resources halve to 0) |
| Colour | only **coloured ingots** colour the product; leather/cloth/wood never do pre-AoS |
| Weapons | `BaseWeapon` takes its resource colour only when `Core.AOS`; pre-AoS weapons are uncoloured |
| Maker's mark | always prompts; no auto/never toggle |
| Make last | NOT part of T2A (Publish 14 feature), retained in ModernUO as QoL |
| Tool-less skills | Inscription and Cartography (`RequiresTool => !T2ACraftSystem.Enabled`) |
| Cooking | no T2A crafting menu existed |

Literal T2A category trees (from `ModernUO: Projects/UOContent/Engines/Craft/T2A/*Menu.cs`):

| skill | T2A tree (exact menu strings) |
|---|---|
| Blacksmithy | "What would you like to do?" → Repair, Smelt, Build Armor → (Build Ring Armor / Build Chain Armor / Build Plate Armor), Build Shield, Build Weapons → (Build Blades / Build Axes / Build Pole Arms / Build Bludgeoning Weapons) |
| Tailoring | Main → Build Hats, Build Shirts, Build Pants, Build Misc, / Build Shoes, Build Leather Armor, Build Studded Armor, Build Female Armor |
| Carpentry | Main → Furniture, Containers, Weapons, Instruments, Miscellaneous, Add-Ons |
| Tinkering | Main → Wooden Items, Tools, Parts, Utensils, Traps, Miscellaneous, Jewelry |
| Alchemy | "What kind of potion?" → Refresh, Agility, Night Sight, Heal, Strength, Poison, Cure, Explosion |
| Inscription | "Which circle of spells?" → Runebook, First … Eighth Circle |
| Cartography | map size ladder: "A map of the local environs." / "A map suitable for cities." / "A moderately sized sea chart." / "A map of the world." |
| Blacksmithy item names | menus render `type.Name` with spaces inserted, lowercase, plus `" (N ingots)"` |

### 5.1 Carpentry

`DefCarpentry`, main skill `Carpentry`, gump title cliloc 1044004, `base(1,1,1.25)`,
`MarkOption = true`, `Repair = Core.AOS`, `CanEnhance = Core.ML`. Station: a **saw / dovetail saw / draw
knife / froe / inshave / jointing plane / moulding plane / smoothing plane** class tool with uses.
Sub-resources: the 7 wood grades (§2.3).

`Source: Scripts/Services/Craft/DefCarpentry.cs`

### Carpentry — 223 recipes

Source: `Scripts/Services/Craft/DefCarpentry.cs`

System config: `Repair` = Core.AOS; `MarkOption` = true; `CanEnhance` = Core.ML; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Barrel Staves | 0 | 5 × Board (sub-res) | 100% at 25 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Barrel Lid | 11 | 4 × Board (sub-res) | 100% at 36 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Short Music Stand Left | 78.9 | 15 × Board (sub-res) | 100% at 103.9 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Short Music Stand Right | 78.9 | 15 × Board (sub-res) | 100% at 103.9 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Tall Music Stand Left | 81.5 | 20 × Board (sub-res) | 100% at 106.5 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Tall Music Stand Right | 81.5 | 20 × Board (sub-res) | 100% at 106.5 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Easle South | 86.8 | 20 × Board (sub-res) | 100% at 111.8 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Easle East | 86.8 | 20 × Board (sub-res) | 100% at 111.8 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Easle North | 86.8 | 20 × Board (sub-res) | 100% at 111.8 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Red Hanging Lantern | 65 | 5 × Board (sub-res); 10 × BlankScroll | 100% at 90; era: Samurai Empire |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | White Hanging Lantern | 65 | 5 × Board (sub-res); 10 × BlankScroll | 100% at 90; era: Samurai Empire |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Shoji Screen | 80 | 75 × Board (sub-res); 60 × Cloth | 100% at 105; era: Samurai Empire; also needs Tailoring 50–55 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Bamboo Screen | 80 | 75 × Board (sub-res); 60 × Cloth | 100% at 105; era: Samurai Empire; also needs Tailoring 50–55 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Fishing Pole | 68.4 | 5 × Board (sub-res); 5 × Cloth | 100% at 93.4; era: AoS; also needs Tailoring 40–45 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Wooden Container Engraver | 75 | 4 × Board (sub-res); 2 × IronIngot | 100% at 100; era: Mondain's Legacy |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Runed Switch | 70 | 2 × Board (sub-res); 1 × EnchantedSwitch; 1 × RunedPrism; 1 × JeweledFiligree | 100% at 120; era: Mondain's Legacy |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Arcanist Statue South Deed | 0 | 250 × Board (sub-res) | 100% at 35; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Arcanist Statue East Deed | 0 | 250 × Board (sub-res) | 100% at 35; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Warrior Statue South Deed | 0 | 250 × Board (sub-res) | 100% at 35; era: Mondain's Legacy; recipe (int)CarpRecipes.WarriorStatueSouth; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Warrior Statue East Deed | 0 | 250 × Board (sub-res) | 100% at 35; era: Mondain's Legacy; recipe (int)CarpRecipes.WarriorStatueEast; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Squirrel Statue South Deed | 0 | 250 × Board (sub-res) | 100% at 35; era: Mondain's Legacy; recipe (int)CarpRecipes.SquirrelStatueSouth; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Squirrel Statue East Deed | 0 | 250 × Board (sub-res) | 100% at 35; era: Mondain's Legacy; recipe (int)CarpRecipes.SquirrelStatueEast; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Giant Replica Acorn | 80 | 35 × Board (sub-res) | 100% at 105; era: Mondain's Legacy |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Mounted Dread Horn | 90 | 50 × Board (sub-res); 1 × PristineDreadHorn | 100% at 115; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Acid Proof Rope | 80 | 2 × GreaterStrengthPotion; 1 × ProtectionScroll; 1 × SwitchItem | 100% at 130; era: Mondain's Legacy; recipe (int)CarpRecipes.AcidProofRope; never exceptional |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Gargish Banner | 94.7 | 50 × Board (sub-res); 50 × Cloth | 100% at 115; era: Stygian Abyss; also needs Tailoring 75–105 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Incubator | 90 | 100 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Chicken Coop | 90 | 150 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Exodus Summoning Alter | 95 | 100 × Board (sub-res); 10 × Granite; 10 × SmallPieceofBlackrock; 1 × NexusCore | 100% at 120; era: Stygian Abyss; also needs Magery 75–120 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Craftable House Item | 42.1 | 5 × Board (sub-res) | 100% at 77.7; era: Time of Legends; did=2967 |
| Carpentry ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Craftable House Item | 42.1 | 5 × Board (sub-res) | 100% at 77.7; era: Time of Legends; did=2969 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Foot Stool | 11 | 9 × Board (sub-res) | 100% at 36 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Stool | 11 | 9 × Board (sub-res) | 100% at 36 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Bamboo Chair | 21 | 13 × Board (sub-res) | 100% at 46 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Wooden Chair | 21 | 13 × Board (sub-res) | 100% at 46 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Fancy Wooden Chair Cushion | 42.1 | 15 × Board (sub-res) | 100% at 67.1 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Wooden Chair Cushion | 42.1 | 13 × Board (sub-res) | 100% at 67.1 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Wooden Bench | 52.6 | 17 × Board (sub-res) | 100% at 77.6 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Wooden Throne | 52.6 | 17 × Board (sub-res) | 100% at 77.6 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Throne | 73.6 | 19 × Board (sub-res) | 100% at 98.6 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Nightstand | 42.1 | 17 × Board (sub-res) | 100% at 67.1 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Writing Table | 63.1 | 17 × Board (sub-res) | 100% at 88.1 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Large Table | 84.2 | 27 × Board (sub-res) | 100% at 109.2 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Yew Wood Table | 63.1 | 23 × Board (sub-res) | 100% at 88.1 |
| Carpentry ▸ Furniture ⟨1044291⟩ | Elegant Low Table | 80 | 35 × Board (sub-res) | 100% at 105; era: Samurai Empire |
| Carpentry ▸ Furniture ⟨1044291⟩ | Plain Low Table | 80 | 35 × Board (sub-res) | 100% at 105; era: Samurai Empire |
| Carpentry ▸ Furniture ⟨1044291⟩ | Ornate Elven Table South Deed | 85 | 60 × Board (sub-res) | 100% at 110; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Furniture ⟨1044291⟩ | Ornate Elven Table East Deed | 85 | 60 × Board (sub-res) | 100% at 110; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Furniture ⟨1044291⟩ | Fancy Elven Table South Deed | 80 | 50 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Furniture ⟨1044291⟩ | Fancy Elven Table East Deed | 80 | 50 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Furniture ⟨1044291⟩ | Elven Podium | 80 | 20 × Board (sub-res) | 100% at 105; era: Mondain's Legacy |
| Carpentry ▸ Furniture ⟨1044291⟩ | Ornate Elven Chair | 80 | 30 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; recipe (int)CarpRecipes.OrnateElvenChair |
| Carpentry ▸ Furniture ⟨1044291⟩ | Big Elven Chair | 85 | 40 × Board (sub-res) | 100% at 110; era: Mondain's Legacy |
| Carpentry ▸ Furniture ⟨1044291⟩ | Elven Reading Chair | 80 | 30 × Board (sub-res) | 100% at 105; era: Mondain's Legacy |
| Carpentry ▸ Furniture ⟨1044291⟩ | Ter Mur Style Chair | 85 | 40 × Board (sub-res) | 100% at 110; era: Stygian Abyss |
| Carpentry ▸ Furniture ⟨1044291⟩ | Ter Mur Style Table | 75 | 50 × Board (sub-res) | 100% at 100; era: Stygian Abyss |
| Carpentry ▸ Furniture ⟨1044291⟩ | Upholstered Chair Deed | 70 | 40 × Board (sub-res); 12 × Cloth | 100% at 110; also needs Tailoring 55–60 |
| Carpentry ▸ Containers ⟨1044292⟩ | Wooden Box | 21 | 10 × Board (sub-res) | 100% at 46 |
| Carpentry ▸ Containers ⟨1044292⟩ | Small Crate | 10 | 8 × Board (sub-res) | 100% at 35 |
| Carpentry ▸ Containers ⟨1044292⟩ | Medium Crate | 31 | 15 × Board (sub-res) | 100% at 56 |
| Carpentry ▸ Containers ⟨1044292⟩ | Large Crate | 47.3 | 18 × Board (sub-res) | 100% at 72.3 |
| Carpentry ▸ Containers ⟨1044292⟩ | Wooden Chest | 73.6 | 20 × Board (sub-res) | 100% at 98.6 |
| Carpentry ▸ Containers ⟨1044292⟩ | Empty Bookcase | 31.5 | 25 × Board (sub-res) | 100% at 56.5 |
| Carpentry ▸ Containers ⟨1044292⟩ | Fancy Armoire | 84.2 | 35 × Board (sub-res) | 100% at 109.2 |
| Carpentry ▸ Containers ⟨1044292⟩ | Armoire | 84.2 | 35 × Board (sub-res) | 100% at 109.2 |
| Carpentry ▸ Containers ⟨1044292⟩ | Plain Wooden Chest | 90 | 30 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Ornate Wooden Chest | 90 | 30 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Gilded Wooden Chest | 90 | 30 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Wooden Foot Locker | 90 | 30 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Finished Wooden Chest | 90 | 30 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Tall Cabinet | 90 | 35 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Short Cabinet | 90 | 35 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Red Armoire | 90 | 40 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Elegant Armoire | 90 | 40 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Maple Armoire | 90 | 40 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Cherry Armoire | 90 | 40 × Board (sub-res) | 100% at 115; era: Samurai Empire |
| Carpentry ▸ Containers ⟨1044292⟩ | Keg | 57.8 | 3 × BarrelStaves; 1 × BarrelHoops; 1 × BarrelLid | 100% at 82.8; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Arcane Book Shelf Deed South | 94.7 | 80 × Board (sub-res) | 100% at 119.7; era: Mondain's Legacy; recipe (int)CarpRecipes.ArcaneBookshelfSouth; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Arcane Book Shelf Deed East | 94.7 | 80 × Board (sub-res) | 100% at 119.7; era: Mondain's Legacy; recipe (int)CarpRecipes.ArcaneBookshelfEast; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Ornate Elven Chest South Deed | 94.7 | 40 × Board (sub-res) | 100% at 119.7; era: Mondain's Legacy; recipe (int)CarpRecipes.OrnateElvenChestSouth; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Ornate Elven Chest East Deed | 94.7 | 40 × Board (sub-res) | 100% at 119.7; era: Mondain's Legacy; recipe (int)CarpRecipes.OrnateElvenChestEast; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Elven Wash Basin South With Drawer Deed | 70 | 40 × Board (sub-res) | 100% at 95; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Elven Wash Basin East With Drawer Deed | 70 | 40 × Board (sub-res) | 100% at 95; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Elven Dresser Deed South | 75 | 45 × Board (sub-res) | 100% at 100; era: Mondain's Legacy; recipe (int)CarpRecipes.ElvenDresserSouth; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Elven Dresser Deed East | 75 | 45 × Board (sub-res) | 100% at 100; era: Mondain's Legacy; recipe (int)CarpRecipes.ElvenDresserEast; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Fancy Elven Armoire | 80 | 60 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; recipe (int)CarpRecipes.FancyElvenArmoire; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Simple Elven Armoire | 80 | 60 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Containers ⟨1044292⟩ | Rarewood Chest | 80 | 30 × Board (sub-res) | 100% at 105; era: Mondain's Legacy |
| Carpentry ▸ Containers ⟨1044292⟩ | Decorative Box | 80 | 25 × Board (sub-res) | 100% at 105; era: Mondain's Legacy |
| Carpentry ▸ Containers ⟨1044292⟩ | Academic Book Case | 60 | 25 × Board (sub-res); 1 × AcademicBooksArtifact | 100% at 85 |
| Carpentry ▸ Containers ⟨1044292⟩ | Gargish Chest | 80 | 30 × Board (sub-res) | 100% at 105; era: Stygian Abyss |
| Carpentry ▸ Containers ⟨1044292⟩ | Liquor Barrel | 60 | 50 × Board (sub-res) | 100% at 90 |
| Carpentry ▸ Weapons ⟨1044566⟩ | Shepherds Crook | 78.9 | 7 × Board (sub-res) | 100% at 103.9 |
| Carpentry ▸ Weapons ⟨1044566⟩ | Quarter Staff | 73.6 | 6 × Board (sub-res) | 100% at 98.6 |
| Carpentry ▸ Weapons ⟨1044566⟩ | Gnarled Staff | 78.9 | 7 × Board (sub-res) | 100% at 103.9 |
| Carpentry ▸ Weapons ⟨1044566⟩ | Bokuto | 70 | 6 × Board (sub-res) | 100% at 95; era: Samurai Empire |
| Carpentry ▸ Weapons ⟨1044566⟩ | Fukiya | 60 | 6 × Board (sub-res) | 100% at 85; era: Samurai Empire |
| Carpentry ▸ Weapons ⟨1044566⟩ | Tetsubo | 80 | 10 × Board (sub-res) | 100% at 105; era: Samurai Empire |
| Carpentry ▸ Weapons ⟨1044566⟩ | Wild Staff | 63.8 | 16 × Board (sub-res) | 100% at 113.8; era: Mondain's Legacy |
| Carpentry ▸ Weapons ⟨1044566⟩ | Phantom Staff | 90 | 16 × Board (sub-res); 1 × DiseasedBark; 10 × Putrefaction; 10 × Taint | 100% at 130; era: Mondain's Legacy; recipe (int)CarpRecipes.PhantomStaff; never exceptional |
| Carpentry ▸ Weapons ⟨1044566⟩ | Arcanists Wild Staff | 63.8 | 16 × Board (sub-res); 1 × WhitePearl | 100% at 113.8; era: Mondain's Legacy; recipe (int)CarpRecipes.ArcanistsWildStaff |
| Carpentry ▸ Weapons ⟨1044566⟩ | Ancient Wild Staff | 63.8 | 16 × Board (sub-res); 1 × PerfectEmerald | 100% at 113.8; era: Mondain's Legacy; recipe (int)CarpRecipes.AncientWildStaff |
| Carpentry ▸ Weapons ⟨1044566⟩ | Thorned Wild Staff | 63.8 | 16 × Board (sub-res); 1 × FireRuby | 100% at 113.8; era: Mondain's Legacy; recipe (int)CarpRecipes.ThornedWildStaff |
| Carpentry ▸ Weapons ⟨1044566⟩ | Hardened Wild Staff | 63.8 | 16 × Board (sub-res); 1 × Turquoise | 100% at 113.8; era: Mondain's Legacy; recipe (int)CarpRecipes.HardenedWildStaff |
| Carpentry ▸ Weapons ⟨1044566⟩ | Serpent Stone Staff | 63.8 | 16 × Board (sub-res); 1 × EcruCitrine | 100% at 113.8; era: Stygian Abyss |
| Carpentry ▸ Weapons ⟨1044566⟩ | Gargish Gnarled Staff | 78.9 | 16 × Board (sub-res); 1 × EcruCitrine | 100% at 128.9; era: Stygian Abyss |
| Carpentry ▸ Weapons ⟨1044566⟩ | Club | 65 | 9 × Board (sub-res) | 100% at 90 |
| Carpentry ▸ Weapons ⟨1044566⟩ | Black Staff | 81.5 | 9 × Board (sub-res) | 100% at 106.5 |
| Carpentry ▸ Weapons ⟨1044566⟩ | Kotl Black Rod | 100 | 20 × Board (sub-res); 1 × BlackrockMoonstone; 1 × StaffOfTheMagi | 100% at 160; era: Time of Legends; recipe (int)CarpRecipes.KotlBlackRod |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Wooden Shield | 52.6 | 9 × Board (sub-res) | 100% at 77.6 |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Woodland Chest | 90 | 20 × Board (sub-res); 6 × BarkFragment | 100% at 115; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Woodland Arms | 80 | 15 × Board (sub-res); 4 × BarkFragment | 100% at 105; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Woodland Gloves | 85 | 15 × Board (sub-res); 4 × BarkFragment | 100% at 110; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Woodland Legs | 85 | 15 × Board (sub-res); 4 × BarkFragment | 100% at 110; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Woodland Gorget | 85 | 15 × Board (sub-res); 4 × BarkFragment | 100% at 110; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Raven Helm | 65 | 10 × Board (sub-res); 4 × BarkFragment; 25 × Feather | 100% at 115; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Vulture Helm | 63.9 | 10 × Board (sub-res); 4 × BarkFragment; 25 × Feather | 100% at 113.9; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Winged Helm | 58.4 | 10 × Board (sub-res); 4 × BarkFragment; 60 × Feather | 100% at 108.4; era: Mondain's Legacy |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Ironwood Crown | 85 | 10 × Board (sub-res); 1 × DiseasedBark; 10 × Corruption; 10 × Putrefaction | 100% at 120; era: Mondain's Legacy; recipe (int)CarpRecipes.IronwoodCrown; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Bramble Coat | 85 | 10 × Board (sub-res); 1 × DiseasedBark; 10 × Taint; 10 × Scourge | 100% at 120; era: Mondain's Legacy; recipe (int)CarpRecipes.BrambleCoat; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Darkwood Crown | 85 | 10 × Board (sub-res); 1 × LardOfParoxysmus; 10 × Blight; 10 × Taint | 100% at 120; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Darkwood Chest | 85 | 20 × Board (sub-res); 1 × DreadHornMane; 10 × Corruption; 10 × Muculent | 100% at 120; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Darkwood Gorget | 85 | 15 × Board (sub-res); 1 × DiseasedBark; 10 × Blight; 10 × Scourge | 100% at 120; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Darkwood Legs | 85 | 15 × Board (sub-res); 1 × GrizzledBones; 10 × Corruption; 10 × Putrefaction | 100% at 120; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Darkwood Pauldrons | 85 | 15 × Board (sub-res); 1 × EyeOfTheTravesty; 10 × Scourge; 10 × Taint | 100% at 120; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Darkwood Gloves | 85 | 15 × Board (sub-res); 1 × CapturedEssence; 10 × Putrefaction; 10 × Muculent | 100% at 120; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Shields / Woodland Armor ⟨1062760⟩ | Gargish Wooden Shield | 52.6 | 9 × Board (sub-res) | 100% at 77.6 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Lap Harp | 63.1 | 20 × Board (sub-res); 10 × Cloth | 100% at 88.1; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Harp | 78.9 | 35 × Board (sub-res); 15 × Cloth | 100% at 103.9; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Drums | 57.8 | 20 × Board (sub-res); 10 × Cloth | 100% at 82.8; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Lute | 68.4 | 25 × Board (sub-res); 10 × Cloth | 100% at 93.4; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Tambourine | 57.8 | 15 × Board (sub-res); 10 × Cloth | 100% at 82.8; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Tambourine Tassel | 57.8 | 15 × Board (sub-res); 15 × Cloth | 100% at 82.8; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Bamboo Flute | 80 | 15 × Board (sub-res) | 100% at 105; era: Samurai Empire; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Aud Char | 78.9 | 35 × Board (sub-res); 3 × Granite | 100% at 103.9; era: Stygian Abyss; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Snake Charmer Flute | 80 | 15 × Board (sub-res); 3 × LuminescentFungi | 100% at 105; era: Stygian Abyss; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Cello Deed | 75 | 15 × Board (sub-res); 5 × Cloth | 100% at 105; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Wall Mounted Bell South Deed | 75 | 50 × Board (sub-res); 50 × IronIngot | 100% at 105; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Wall Mounted Bell East Deed | 75 | 50 × Board (sub-res); 50 × IronIngot | 100% at 105; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Trumpet Deed | 85 | 10 × Board (sub-res); 15 × IronIngot | 100% at 105; also needs Musicianship 45–50 |
| Carpentry ▸ Instruments ⟨1044293⟩ | Cow Bell Deed | 85 | 10 × Board (sub-res); 15 × IronIngot | 100% at 105; also needs Musicianship 45–50 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Player BB East | 85 | 50 × Board (sub-res) | 100% at 110; era: AoS |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Player BB South | 85 | 50 × Board (sub-res) | 100% at 110; era: AoS |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Parrot Perch Addon Deed | 50 | 100 × Board (sub-res) | 100% at 85; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Arcane Circle Deed | 94.7 | 100 × Board (sub-res); 2 × BlueDiamond; 2 × PerfectEmerald; 2 × FireRuby | 100% at 119.7; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Tall Elven Bed South Deed | 94.7 | 200 × Board (sub-res); 100 × Cloth | 100% at 119.7; era: Mondain's Legacy; also needs Tailoring 75–80; recipe (int)CarpRecipes.TallElvenBedSouth; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Tall Elven Bed East Deed | 94.7 | 200 × Board (sub-res); 100 × Cloth | 100% at 119.7; era: Mondain's Legacy; also needs Tailoring 75–80; recipe (int)CarpRecipes.TallElvenBedEast; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Elven Bed South Deed | 94.7 | 100 × Board (sub-res); 100 × Cloth | 100% at 119.7; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Elven Bed East Deed | 94.7 | 100 × Board (sub-res); 100 × Cloth | 100% at 119.7; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Elven Loveseat South Deed | 80 | 50 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; did=0x2DDF; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Elven Loveseat East Deed | 80 | 50 × Board (sub-res) | 100% at 105; era: Mondain's Legacy; did=0x2DE0; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Alchemist Table South Deed | 85 | 70 × Board (sub-res) | 100% at 110; era: Mondain's Legacy; did=0x2DD4; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Alchemist Table East Deed | 85 | 70 × Board (sub-res) | 100% at 110; era: Mondain's Legacy; did=0x2DD3; never exceptional |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Small Bed South Deed | 94.7 | 100 × Board (sub-res); 100 × Cloth | 100% at 119.8; also needs Tailoring 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Small Bed East Deed | 94.7 | 100 × Board (sub-res); 100 × Cloth | 100% at 119.8; also needs Tailoring 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Large Bed South Deed | 94.7 | 150 × Board (sub-res); 150 × Cloth | 100% at 119.8; also needs Tailoring 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Large Bed East Deed | 94.7 | 150 × Board (sub-res); 150 × Cloth | 100% at 119.8; also needs Tailoring 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Dart Board South Deed | 15.7 | 5 × Board (sub-res) | 100% at 40.7 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Dart Board East Deed | 15.7 | 5 × Board (sub-res) | 100% at 40.7 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Ballot Box Deed | 47.3 | 5 × Board (sub-res) | 100% at 72.3 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Pentagram Deed | 100 | 100 × Board (sub-res); 40 × IronIngot | 100% at 125; also needs Magery 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Abbatoir Deed | 100 | 100 × Board (sub-res); 40 × IronIngot | 100% at 125; also needs Magery 50–55 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Gargish Couch East Deed | 90 | 75 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Gargish Couch South Deed | 90 | 75 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Long Table South Deed | 90 | 80 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Long Table East Deed | 90 | 80 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Ter Mur Dresser East Deed | 90 | 60 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Ter Mur Dresser South Deed | 90 | 60 × Board (sub-res) | 100% at 115; era: Stygian Abyss |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Rustic Bench South Deed | 94.7 | 35 × Board (sub-res) | 100% at 119.8 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Rustic Bench East Deed | 94.7 | 35 × Board (sub-res) | 100% at 119.8 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Plain Wooden Shelf South Deed | 40 | 15 × Board (sub-res) | 100% at 90 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Plain Wooden Shelf East Deed | 40 | 15 × Board (sub-res) | 100% at 90 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Wooden Shelf South Deed | 40 | 15 × Board (sub-res) | 100% at 90 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Wooden Shelf East Deed | 40 | 15 × Board (sub-res) | 100% at 90 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Loveseat South Deed | 70 | 80 × Board (sub-res); 24 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Loveseat East Deed | 70 | 80 × Board (sub-res); 24 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Couch South Deed | 70 | 80 × Board (sub-res); 48 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Couch East Deed | 70 | 80 × Board (sub-res); 48 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Plush Loveseat South Deed | 70 | 80 × Board (sub-res); 24 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Plush Loveseat East Deed | 70 | 80 × Board (sub-res); 24 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Plant Tapestry South Deed | 85 | 12 × Board (sub-res); 50 × Cloth | 100% at 110; also needs Tailoring 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Plant Tapestry East Deed | 85 | 12 × Board (sub-res); 50 × Cloth | 100% at 110; also needs Tailoring 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Metal Table South Deed | 80 | 20 × Board (sub-res); 15 × IronIngot | 100% at 105; also needs Tinkering 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Metal Table East Deed | 80 | 20 × Board (sub-res); 15 × IronIngot | 100% at 105; also needs Tinkering 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Long Metal Table South Deed | 80 | 40 × Board (sub-res); 30 × IronIngot | 100% at 105; also needs Tinkering 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Long Metal Table East Deed | 80 | 40 × Board (sub-res); 30 × IronIngot | 100% at 105; also needs Tinkering 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Wooden Table South Deed | 80 | 20 × Board (sub-res) | 100% at 105 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Wooden Table East Deed | 80 | 20 × Board (sub-res) | 100% at 105 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Long Wooden Table South Deed | 80 | 80 × Board (sub-res) | 100% at 105 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Long Wooden Table East Deed | 80 | 80 × Board (sub-res) | 100% at 105 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Small Display Case South Deed | 95 | 40 × Board (sub-res); 10 × IronIngot | 100% at 120; also needs Tinkering 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Small Display Case East Deed | 95 | 40 × Board (sub-res); 10 × IronIngot | 100% at 120; also needs Tinkering 75–80 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Loveseat North Deed | 70 | 80 × Board (sub-res); 48 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Loveseat West Deed | 70 | 80 × Board (sub-res); 48 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Couch North Deed | 70 | 80 × Board (sub-res); 48 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-On Deeds ⟨1044290⟩ | Fancy Couch West Deed | 70 | 80 × Board (sub-res); 48 × Cloth | 100% at 120; also needs Tailoring 55–60 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Dressform Front | 63.1 | 25 × Board (sub-res); 10 × Cloth | 100% at 88.1; also needs Tailoring 65–70 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Dressform Side | 63.1 | 25 × Board (sub-res); 10 × Cloth | 100% at 88.1; also needs Tailoring 65–70 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Elven Spinningwheel East Deed | 75 | 60 × Board (sub-res); 40 × Cloth | 100% at 100; era: Mondain's Legacy; also needs Tailoring 65–85; never exceptional |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Elven Spinningwheel South Deed | 75 | 60 × Board (sub-res); 40 × Cloth | 100% at 100; era: Mondain's Legacy; also needs Tailoring 65–85; never exceptional |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Elven Stove South Deed | 85 | 80 × Board (sub-res) | 100% at 110; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Elven Stove East Deed | 85 | 80 × Board (sub-res) | 100% at 110; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Spinningwheel East Deed | 73.6 | 75 × Board (sub-res); 25 × Cloth | 100% at 98.6; also needs Tailoring 65–70 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Spinningwheel South Deed | 73.6 | 75 × Board (sub-res); 25 × Cloth | 100% at 98.6; also needs Tailoring 65–70 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Loom East Deed | 84.2 | 85 × Board (sub-res); 25 × Cloth | 100% at 109.2; also needs Tailoring 65–70 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Loom South Deed | 84.2 | 85 × Board (sub-res); 25 × Cloth | 100% at 109.2; also needs Tailoring 65–70 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Stone Oven East Deed | 68.4 | 85 × Board (sub-res); 125 × IronIngot | 100% at 93.4; also needs Tinkering 50–55 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Stone Oven South Deed | 68.4 | 85 × Board (sub-res); 125 × IronIngot | 100% at 93.4; also needs Tinkering 50–55 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Flour Mill East Deed | 94.7 | 100 × Board (sub-res); 50 × IronIngot | 100% at 119.7; also needs Tinkering 50–55 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Flour Mill South Deed | 94.7 | 100 × Board (sub-res); 50 × IronIngot | 100% at 119.7; also needs Tinkering 50–55 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Water Trough East Deed | 94.7 | 150 × Board (sub-res) | 100% at 119.7 |
| Carpentry ▸ Add-Ons (craft stations) ⟨1044298⟩ | Water Trough South Deed | 94.7 | 150 × Board (sub-res) | 100% at 119.7 |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Elven Forge Deed | 94.7 | 200 × Board (sub-res) | 100% at 119.7; era: Mondain's Legacy; never exceptional |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Soul Forge Deed | 100 | 150 × Board (sub-res); 150 × IronIngot; 1 × RelicFragment | 100% at 200; era: Stygian Abyss; also needs Imbuing 75–80; never exceptional |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Small Forge Deed | 73.6 | 5 × Board (sub-res); 75 × IronIngot | 100% at 98.6; also needs Blacksmith 75–80 |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Large Forge East Deed | 78.9 | 5 × Board (sub-res); 100 × IronIngot | 100% at 103.9; also needs Blacksmith 80–85 |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Large Forge South Deed | 78.9 | 5 × Board (sub-res); 100 × IronIngot | 100% at 103.9; also needs Blacksmith 80–85 |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Anvil East Deed | 73.6 | 5 × Board (sub-res); 150 × IronIngot | 100% at 98.6; also needs Blacksmith 75–80 |
| Carpentry ▸ Forge & Anvil Deeds ⟨1111809⟩ | Anvil South Deed | 73.6 | 5 × Board (sub-res); 150 × IronIngot | 100% at 98.6; also needs Blacksmith 75–80 |
| Carpentry ▸ Training Deeds ⟨1044297⟩ | Training Dummy East Deed | 68.4 | 55 × Board (sub-res); 60 × Cloth | 100% at 93.4; also needs Tailoring 50–55 |
| Carpentry ▸ Training Deeds ⟨1044297⟩ | Training Dummy South Deed | 68.4 | 55 × Board (sub-res); 60 × Cloth | 100% at 93.4; also needs Tailoring 50–55 |
| Carpentry ▸ Training Deeds ⟨1044297⟩ | Pickpocket Dip East Deed | 73.6 | 65 × Board (sub-res); 60 × Cloth | 100% at 98.6; also needs Tailoring 50–55 |
| Carpentry ▸ Training Deeds ⟨1044297⟩ | Pickpocket Dip South Deed | 73.6 | 65 × Board (sub-res); 60 × Cloth | 100% at 98.6; also needs Tailoring 50–55 |


### 5.2 Tinkering

`DefTinkering`, main skill `Tinkering`, gump title cliloc 1044005, `base(1,1,1.25)`,
`Resmelt = true`, `Repair = true`, `MarkOption = true`, `CanEnhance = Core.AOS`, `CanAlter = Core.SA`.
Station: tinker tools / hammer / tongs / screwdriver-type tool with uses. Sub-resources: ingot grades.

`Source: Scripts/Services/Craft/DefTinkering.cs`

### Tinkering — 165 recipes

Source: `Scripts/Services/Craft/DefTinkering.cs`

System config: `Repair` = true; `MarkOption` = true; `CanEnhance` = Core.AOS; `CanAlter` = Core.SA; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Ring | 40 | 2 × IronIngot (sub-res); 1 × player-targeted gem | 100% at 90 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Silver Bead Necklace | 40 | 2 × IronIngot (sub-res); 1 × player-targeted gem | 100% at 90 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Necklace | 40 | 2 × IronIngot (sub-res); 1 × player-targeted gem | 100% at 90 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Earrings | 40 | 2 × IronIngot (sub-res); 1 × player-targeted gem | 100% at 90 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Bead Necklace | 40 | 2 × IronIngot (sub-res); 1 × player-targeted gem | 100% at 90 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Bracelet | 40 | 2 × IronIngot (sub-res); 1 × player-targeted gem | 100% at 90 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Ring | 65 | 3 × IronIngot (sub-res) | 100% at 115 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gold Bracelet | 55 | 3 × IronIngot (sub-res) | 100% at 105 |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gargish Necklace | 60 | 3 × IronIngot (sub-res) | 100% at 110; era: Stygian Abyss |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gargish Bracelet | 55 | 3 × IronIngot (sub-res) | 100% at 105; era: Stygian Abyss |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gargish Ring | 65 | 3 × IronIngot (sub-res) | 100% at 115; era: Stygian Abyss |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Gargish Earrings | 55 | 3 × IronIngot (sub-res) | 100% at 105; era: Stygian Abyss |
| Tinkering ▸ Jewelry ⟨1044049⟩ | Krampus Minion Earrings | 100 | 3 × IronIngot (sub-res) | 100% at 500; recipe (int)TinkerRecipes.KrampusMinionEarrings |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Nunchaku | 70 | 3 × IronIngot (sub-res); 8 × Board | 100% at 120; era: Samurai Empire |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Jointing Plane | 0 | 4 × Board (sub-res) | 100% at 50 |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Moulding Plane | 0 | 4 × Board (sub-res) | 100% at 50 |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Smoothing Plane | 0 | 4 × Board (sub-res) | 100% at 50 |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Clock Frame | 0 | 6 × Board (sub-res) | 100% at 50 |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Axle | -25 | 2 × Board (sub-res) | 100% at 25 |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Rolling Pin | 0 | 5 × Board (sub-res) | 100% at 50 |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Ramrod | 0 | 8 × Board (sub-res) | 100% at 50; era: High Seas |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Swab | 0 | 1 × Cloth; 4 × Board | 100% at 50; era: NOT Endless Journey |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Softened Reeds | 75 | 1 × DryReeds; 2 × ScouringToxin | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Round Basket | 75 | 2 × SoftenedReeds; 3 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Round Basket Handles | 75 | 2 × SoftenedReeds; 3 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Small Bushel | 75 | 1 × SoftenedReeds; 2 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Picnic Basket 2 | 75 | 1 × SoftenedReeds; 2 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Winnowing Basket | 75 | 2 × SoftenedReeds; 3 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Square Basket | 75 | 2 × SoftenedReeds; 3 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Basket Craftable | 75 | 2 × SoftenedReeds; 3 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Tall Round Basket | 75 | 3 × SoftenedReeds; 4 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Small Square Basket | 75 | 1 × SoftenedReeds; 2 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Tall Basket | 75 | 3 × SoftenedReeds; 4 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Small Round Basket | 75 | 1 × SoftenedReeds; 2 × Shaft | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Wooden Items ⟨1044042⟩ | Enchanted Picnic Basket | 75 | 2 × SoftenedReeds; 3 × Shaft | 100% at 100; era: Stygian Abyss; recipe (int)TinkerRecipes.EnchantedPicnicBasket |
| Tinkering ▸ Tools ⟨1044046⟩ | Scissors | 5 | 2 × IronIngot (sub-res) | 100% at 55 |
| Tinkering ▸ Tools ⟨1044046⟩ | Mortar Pestle | 20 | 3 × IronIngot (sub-res) | 100% at 70 |
| Tinkering ▸ Tools ⟨1044046⟩ | Scorp | 30 | 2 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Tinker Tools | 10 | 2 × IronIngot (sub-res) | 100% at 60 |
| Tinkering ▸ Tools ⟨1044046⟩ | Hatchet | 30 | 4 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Draw Knife | 30 | 2 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Sewing Kit | 10 | 2 × IronIngot (sub-res) | 100% at 70 |
| Tinkering ▸ Tools ⟨1044046⟩ | Saw | 30 | 4 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Dovetail Saw | 30 | 4 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Froe | 30 | 2 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Shovel | 40 | 4 × IronIngot (sub-res) | 100% at 90 |
| Tinkering ▸ Tools ⟨1044046⟩ | Hammer | 30 | 1 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Tongs | 35 | 1 × IronIngot (sub-res) | 100% at 85 |
| Tinkering ▸ Tools ⟨1044046⟩ | Smithy Hammer | 40 | 4 × IronIngot (sub-res) | 100% at 90 |
| Tinkering ▸ Tools ⟨1044046⟩ | Sledge Hammer Weapon | 40 | 4 × IronIngot (sub-res) | 100% at 90 |
| Tinkering ▸ Tools ⟨1044046⟩ | Inshave | 30 | 2 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Pickaxe | 40 | 4 × IronIngot (sub-res) | 100% at 90 |
| Tinkering ▸ Tools ⟨1044046⟩ | Lockpick | 45 | 1 × IronIngot (sub-res) | 100% at 95 |
| Tinkering ▸ Tools ⟨1044046⟩ | Skillet | 30 | 4 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Tools ⟨1044046⟩ | Flour Sifter | 50 | 3 × IronIngot (sub-res) | 100% at 100 |
| Tinkering ▸ Tools ⟨1044046⟩ | Fletcher Tools | 35 | 3 × IronIngot (sub-res) | 100% at 85 |
| Tinkering ▸ Tools ⟨1044046⟩ | Mapmakers Pen | 25 | 1 × IronIngot (sub-res) | 100% at 75 |
| Tinkering ▸ Tools ⟨1044046⟩ | Scribes Pen | 25 | 1 × IronIngot (sub-res) | 100% at 75 |
| Tinkering ▸ Tools ⟨1044046⟩ | Clippers | 50 | 4 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Tools ⟨1044046⟩ | Metal Container Engraver | 75 | 4 × IronIngot (sub-res); 1 × Springs; 2 × Gears; 1 × Diamond | 100% at 100; era: Mondain's Legacy |
| Tinkering ▸ Tools ⟨1044046⟩ | Pitchfork | 40 | 4 × IronIngot (sub-res) | 100% at 90 |
| Tinkering ▸ Parts ⟨1044047⟩ | Gears | 5 | 2 × IronIngot (sub-res) | 100% at 55 |
| Tinkering ▸ Parts ⟨1044047⟩ | Clock Parts | 25 | 1 × IronIngot (sub-res) | 100% at 75 |
| Tinkering ▸ Parts ⟨1044047⟩ | Barrel Tap | 35 | 2 × IronIngot (sub-res) | 100% at 85 |
| Tinkering ▸ Parts ⟨1044047⟩ | Springs | 5 | 2 × IronIngot (sub-res) | 100% at 55 |
| Tinkering ▸ Parts ⟨1044047⟩ | Sextant Parts | 30 | 4 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Parts ⟨1044047⟩ | Barrel Hoops | -15 | 5 × IronIngot (sub-res) | 100% at 35 |
| Tinkering ▸ Parts ⟨1044047⟩ | Hinge | 5 | 2 × IronIngot (sub-res) | 100% at 55 |
| Tinkering ▸ Parts ⟨1044047⟩ | Bola Ball | 45 | 10 × IronIngot (sub-res) | 100% at 95 |
| Tinkering ▸ Parts ⟨1044047⟩ | Jeweled Filigree | 70 | 2 × IronIngot (sub-res); 1 × StarSapphire; 1 × Ruby | 100% at 110; era: Mondain's Legacy |
| Tinkering ▸ Utensils ⟨1044048⟩ | Butcher Knife | 25 | 2 × IronIngot (sub-res) | 100% at 75 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Spoon Left | 0 | 1 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Spoon Right | 0 | 1 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Plate | 0 | 2 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Fork Left | 0 | 1 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Fork Right | 0 | 1 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Cleaver | 20 | 3 × IronIngot (sub-res) | 100% at 70 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Knife Left | 0 | 1 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Knife Right | 0 | 1 × IronIngot (sub-res) | 100% at 50 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Goblet | 10 | 2 × IronIngot (sub-res) | 100% at 60 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Pewter Mug | 10 | 2 × IronIngot (sub-res) | 100% at 60 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Skinning Knife | 25 | 2 × IronIngot (sub-res) | 100% at 75 |
| Tinkering ▸ Utensils ⟨1044048⟩ | Gargish Cleaver | 20 | 3 × IronIngot (sub-res) | 100% at 70; era: Stygian Abyss |
| Tinkering ▸ Utensils ⟨1044048⟩ | Gargish Butcher Knife | 25 | 2 × IronIngot (sub-res) | 100% at 75; era: Stygian Abyss |
| Tinkering ▸ Glassware ⟨1044050⟩ | Key Ring | 10 | 2 × IronIngot (sub-res) | 100% at 60 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Candelabra | 55 | 4 × IronIngot (sub-res) | 100% at 105 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Scales | 60 | 4 × IronIngot (sub-res) | 100% at 110 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Key | 20 | 3 × IronIngot (sub-res) | 100% at 70 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Globe | 55 | 4 × IronIngot (sub-res) | 100% at 105 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Spyglass | 60 | 4 × IronIngot (sub-res) | 100% at 110 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Lantern | 30 | 2 × IronIngot (sub-res) | 100% at 80 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Heating Stand | 60 | 4 × IronIngot (sub-res) | 100% at 110 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Shoji Lantern | 65 | 10 × IronIngot (sub-res); 5 × Board | 100% at 115; era: Samurai Empire |
| Tinkering ▸ Glassware ⟨1044050⟩ | Paper Lantern | 65 | 10 × IronIngot (sub-res); 5 × Board | 100% at 115; era: Samurai Empire |
| Tinkering ▸ Glassware ⟨1044050⟩ | Round Paper Lantern | 65 | 10 × IronIngot (sub-res); 5 × Board | 100% at 115; era: Samurai Empire |
| Tinkering ▸ Glassware ⟨1044050⟩ | Wind Chimes | 80 | 15 × IronIngot (sub-res) | 100% at 130; era: Samurai Empire |
| Tinkering ▸ Glassware ⟨1044050⟩ | Fancy Wind Chimes | 80 | 15 × IronIngot (sub-res) | 100% at 130; era: Samurai Empire |
| Tinkering ▸ Glassware ⟨1044050⟩ | Ter Mur Style Candelabra | 55 | 4 × IronIngot (sub-res) | 100% at 105; era: Stygian Abyss |
| Tinkering ▸ Glassware ⟨1044050⟩ | Matches | 15 | 10 × Matchcord; 4 × Board | 100% at 70; era: High Seas |
| Tinkering ▸ Glassware ⟨1044050⟩ | Broadcast Crystal | 80 | 20 × IronIngot (sub-res); 10 × Emerald; 10 × Ruby; 1 × CopperWire | 100% at 130 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Gorgon Lense | 90 | 2 × MedusaDarkScales (sub-res); 3 × CrystalDust | 100% at 120; era: Stygian Abyss; ih=1266; never exceptional |
| Tinkering ▸ Glassware ⟨1044050⟩ | Scale Collar | 50 | 4 × RedScales (sub-res); 1 × Scourge | 100% at 100; era: Stygian Abyss |
| Tinkering ▸ Glassware ⟨1044050⟩ | Dragon Lamp | 75 | 8 × IronIngot (sub-res); 1 × Candelabra; 1 × WorkableGlass | 100% at 125 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Stained Glass Lamp | 75 | 8 × IronIngot (sub-res); 1 × Candelabra; 1 × WorkableGlass | 100% at 125 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Tall Double Lamp | 75 | 8 × IronIngot (sub-res); 1 × Candelabra; 1 × WorkableGlass | 100% at 125 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable House Item | 40 | 8 × IronIngot (sub-res) | 100% at 90; era: Time of Legends; did=2971 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable House Item | 40 | 8 × IronIngot (sub-res) | 100% at 90; era: Time of Legends; did=2973 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable House Item | 40 | 8 × IronIngot (sub-res) | 100% at 90; era: Time of Legends; did=2975 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable House Item | 40 | 8 × IronIngot (sub-res) | 100% at 90; era: Time of Legends; did=2977 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1653 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1659 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1660 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1663 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Wall Safe Deed | 0 | 20 × IronIngot (sub-res) | 100% at 0; era: Time of Legends; never exceptional |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1660 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1663 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1653 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Craftable Metal House Door | 85 | 50 × IronIngot (sub-res) | 100% at 135; era: Time of Legends; did=1659 |
| Tinkering ▸ Glassware ⟨1044050⟩ | Kotl Power Core | 85 | 5 × WorkableGlass; 5 × CopperWire; 100 × IronIngot; 5 × MoonstoneCrystalShard | 100% at 135; era: Time of Legends; recipe (int)TinkerRecipes.KotlPowerCore |
| Tinkering ▸ Glassware ⟨1044050⟩ | Weathered Bronze Globe Sculpture Deed | 85 | 200 × BronzeIngot (sub-res) | 100% at 135; recipe (int)TinkerRecipes.WeatheredBronzeGlobeSculpture |
| Tinkering ▸ Glassware ⟨1044050⟩ | Weathered Bronze Man On A Bench Deed | 85 | 200 × IronIngot (sub-res) | 100% at 135; recipe (int)TinkerRecipes.WeatheredBronzeManOnABench |
| Tinkering ▸ Glassware ⟨1044050⟩ | Weathered Bronze Fairy Sculpture Deed | 85 | 200 × IronIngot (sub-res) | 100% at 135; recipe (int)TinkerRecipes.WeatheredBronzeFairySculpture |
| Tinkering ▸ Glassware ⟨1044050⟩ | Weathered Bronze Archer Deed | 85 | 200 × IronIngot (sub-res) | 100% at 135; recipe (int)TinkerRecipes.WeatheredBronzeArcherSculpture |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Axle Gears | 0 | 1 × Axle; 1 × Gears | 100% at 0 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Clock Parts | 0 | 1 × AxleGears; 1 × Springs | 100% at 0 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Sextant Parts | 0 | 1 × AxleGears; 1 × Hinge | 100% at 0 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Clock Right | 0 | 1 × ClockFrame; 1 × ClockParts | 100% at 0 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Clock Left | 0 | 1 × ClockFrame; 1 × ClockParts | 100% at 0 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Sextant | 0 | 1 × SextantParts | 100% at 0 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Bola | 60 | 4 × BolaBall; 3 × Leather | 100% at 80 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Potion Keg | 75 | 1 × Keg; 10 × Bottle; 1 × BarrelLid; 1 × BarrelTap | 100% at 100 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Modified Clockwork Assembly | 65 | 1 × ClockworkAssembly; 1 × PowerCrystal; 1 × VoidEssence | 100% at 115; era: Stygian Abyss; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Modified Clockwork Assembly | 65 | 1 × ClockworkAssembly; 1 × PowerCrystal; 2 × VoidEssence | 100% at 115; era: Stygian Abyss; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Modified Clockwork Assembly | 65 | 1 × ClockworkAssembly; 1 × PowerCrystal; 3 × VoidEssence | 100% at 115; era: Stygian Abyss; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Hitching Rope | 60 | 1 × Rope; 1 × ResolvesBridle | 100% at 120; era: Mondain's Legacy; also needs AnimalLore 15–100 |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Hitching Post | 90 | 50 × IronIngot (sub-res); 1 × AnimalPheromone; 2 × HitchingRope; 1 × PhillipsWoodenSteed | 100% at 160; era: Mondain's Legacy |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Arcanic Rune Stone | 90 | 1 × CrystalShards; 5 × PowerCrystal | 100% at 140; era: Stygian Abyss; also needs Magery 80–85; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Void Orb | 90 | 1 × DarkSapphire; 50 × BlackPearl | 100% at 104.3; era: Stygian Abyss; also needs Magery 80–100; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Advanced Training Dummy South Deed | 90 | 1 × TrainingDummySouthDeed; 1 × PlateChest; 1 × CloseHelm; 1 × Broadsword | 100% at 120; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Advanced Training Dummy East Deed | 90 | 1 × TrainingDummyEastDeed; 1 × PlateChest; 1 × CloseHelm; 1 × Broadsword | 100% at 120; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Distillery South Addon Deed | 90 | 2 × MetalKeg; 4 × HeatingStand; 1 × CopperWire | 100% at 110; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Distillery East Addon Deed | 90 | 2 × MetalKeg; 4 × HeatingStand; 1 × CopperWire | 100% at 110; never exceptional |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Kotl Automaton Head | 100 | 300 × IronIngot (sub-res); 1 × AutomatonActuator; 1 × StasisChamberPowerCore; 1 × InoperativeAutomatonHead | 100% at 580; era: Time of Legends; recipe (int)TinkerRecipes.KotlAutomatonHead |
| Tinkering ▸ Assemblies ⟨1044051⟩ | Personal Telescope | 95 | 25 × IronIngot (sub-res); 1 × WorkableGlass; 1 × SextantParts | 100% at 196; era: Time of Legends; recipe (int)TinkerRecipes.Telescope |
| Tinkering ▸ Traps ⟨1044052⟩ | Dart Trap Craft | 30 | 1 × IronIngot (sub-res); 1 × Bolt | 100% at 80 |
| Tinkering ▸ Traps ⟨1044052⟩ | Poison Trap Craft | 30 | 1 × IronIngot (sub-res); 1 × BasePoisonPotion | 100% at 80 |
| Tinkering ▸ Traps ⟨1044052⟩ | Explosion Trap Craft | 55 | 1 × IronIngot (sub-res); 1 × BaseExplosionPotion | 100% at 105 |
| Tinkering ▸ Traps ⟨1044052⟩ | Faction Gas Trap Deed | 65 | UNVERIFIED × Silver; 10 × IronIngot; 1 × BasePoisonPotion | 100% at 115 |
| Tinkering ▸ Traps ⟨1044052⟩ | Faction Explosion Trap Deed | 65 | UNVERIFIED × Silver; 10 × IronIngot; 1 × BaseExplosionPotion | 100% at 115 |
| Tinkering ▸ Traps ⟨1044052⟩ | Faction Saw Trap Deed | 65 | UNVERIFIED × Silver; 10 × IronIngot; 1 × Gears | 100% at 115 |
| Tinkering ▸ Traps ⟨1044052⟩ | Faction Spike Trap Deed | 65 | UNVERIFIED × Silver; 10 × IronIngot; 1 × Springs | 100% at 115 |
| Tinkering ▸ Traps ⟨1044052⟩ | Faction Trap Removal Kit | 90 | 500 × Silver; 10 × IronIngot | 100% at 115 |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Brilliant Amber Bracelet | 75 | 5 × IronIngot (sub-res); 20 × Amber; 10 × BrilliantAmber | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Fire Ruby Bracelet | 75 | 5 × IronIngot (sub-res); 20 × Ruby; 10 × FireRuby | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Dark Sapphire Bracelet | 75 | 5 × IronIngot (sub-res); 20 × Sapphire; 10 × DarkSapphire | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | White Pearl Bracelet | 75 | 5 × IronIngot (sub-res); 20 × Tourmaline; 10 × WhitePearl | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Ecru Citrine Ring | 75 | 5 × IronIngot (sub-res); 20 × Citrine; 10 × EcruCitrine | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Blue Diamond Ring | 75 | 5 × IronIngot (sub-res); 20 × Diamond; 10 × BlueDiamond | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Perfect Emerald Ring | 75 | 5 × IronIngot (sub-res); 20 × Emerald; 10 × PerfectEmerald | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Turqouise Ring | 75 | 5 × IronIngot (sub-res); 20 × Amethyst; 10 × Turquoise | 100% at 125; era: Mondain's Legacy |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Resilient Bracer | 100 | 2 × IronIngot (sub-res); 1 × CapturedEssence; 10 × BlueDiamond; 50 × Diamond | 100% at 125; era: Mondain's Legacy; recipe (int)TinkerRecipes.ResilientBracer; never exceptional |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Essence Of Battle | 100 | 2 × IronIngot (sub-res); 1 × CapturedEssence; 10 × FireRuby; 50 × Ruby | 100% at 125; era: Mondain's Legacy; recipe (int)TinkerRecipes.EssenceOfBattle; never exceptional |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Pendant Of The Magi | 100 | 2 × IronIngot (sub-res); 1 × EyeOfTheTravesty; 5 × WhitePearl; 50 × StarSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)TinkerRecipes.PendantOfTheMagi; never exceptional |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Dr Spectors Lenses | 100 | 20 × IronIngot (sub-res); 1 × BlackrockMoonstone; 1 × HatOfTheMagi | 100% at 580; era: Time of Legends; recipe (int)TinkerRecipes.DrSpectorLenses; never exceptional |
| Tinkering ▸ Jewelry (gem, later era) ⟨1073107⟩ | Bracelet Of Primal Consumption | 100 | 3 × IronIngot (sub-res); 1 × RingOfTheElements; 5 × BloodOfTheDarkFather; 4 × WhitePearl | 100% at 580; era: Time of Legends; recipe (int)TinkerRecipes.BraceletOfPrimalConsumption; never exceptional |


### 5.3 Bowcraft / Fletching

`DefBowFletching`, main skill `Fletching`, gump title cliloc 1044006, `base(1,1,1.25)`,
**`ECA = FiftyPercentChanceMinusTenPercent`**, `GetChanceAtMin = 0.5` (50 % floor!),
`MarkOption = true`, `Repair = Core.AOS`, `CanEnhance = Core.ML`. Station: fletcher tools
(or any tool whose CraftSystem is this). Sub-resources: the 7 wood grades.
Note the 1:1 chain: 1 board → 1 shaft (`SetUseAllRes` = whole stack), 1 shaft + 1 feather → 1 arrow/bolt
(whole stack), 1 board → 1 kindling (no skill, always succeeds).

`Source: Scripts/Services/Craft/DefBowFletching.cs`

### BowFletching — 27 recipes

Source: `Scripts/Services/Craft/DefBowFletching.cs`

System config: `Repair` = Core.AOS; `MarkOption` = true; `CanEnhance` = Core.ML; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| BowFletching ▸ Materials ⟨1044457⟩ | Elven Fletching | 90 | 20 × Feather; 1 × FaeryDust | 100% at 130; era: Stygian Abyss |
| BowFletching ▸ Materials ⟨1044457⟩ | Kindling | 0 | 1 × Board (sub-res) | 100% at 0 |
| BowFletching ▸ Materials ⟨1044457⟩ | Shaft | 0 | 1 × Board (sub-res) | 100% at 40; consumes whole stack (batch) |
| BowFletching ▸ Ammunition ⟨1044565⟩ | Arrow | 0 | 1 × Shaft; 1 × Feather | 100% at 40; consumes whole stack (batch) |
| BowFletching ▸ Ammunition ⟨1044565⟩ | Bolt | 0 | 1 × Shaft; 1 × Feather | 100% at 40; consumes whole stack (batch) |
| BowFletching ▸ Ammunition ⟨1044565⟩ | Fukiya Darts | 50 | 1 × Board (sub-res) | 100% at 73.8; era: Samurai Empire; consumes whole stack (batch) |
| BowFletching ▸ Weapons ⟨1044566⟩ | Bow | 30 | 7 × Board (sub-res) | 100% at 70 |
| BowFletching ▸ Weapons ⟨1044566⟩ | Crossbow | 60 | 7 × Board (sub-res) | 100% at 100 |
| BowFletching ▸ Weapons ⟨1044566⟩ | Heavy Crossbow | 80 | 10 × Board (sub-res) | 100% at 120 |
| BowFletching ▸ Weapons ⟨1044566⟩ | Composite Bow | 70 | 7 × Board (sub-res) | 100% at 110; era: AoS |
| BowFletching ▸ Weapons ⟨1044566⟩ | Repeating Crossbow | 90 | 10 × Board (sub-res) | 100% at 130; era: AoS |
| BowFletching ▸ Weapons ⟨1044566⟩ | Yumi | 90 | 10 × Board (sub-res) | 100% at 130; era: Samurai Empire |
| BowFletching ▸ Weapons ⟨1044566⟩ | Elven Composite Longbow | 95 | 20 × Board (sub-res) | 100% at 145; era: Mondain's Legacy |
| BowFletching ▸ Weapons ⟨1044566⟩ | Magical Shortbow | 85 | 15 × Board (sub-res) | 100% at 135; era: Mondain's Legacy |
| BowFletching ▸ Weapons ⟨1044566⟩ | Blight Gripped Longbow | 75 | 20 × Board (sub-res); 1 × LardOfParoxysmus; 10 × Blight; 10 × Corruption | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.BlightGrippedLongbow; never exceptional |
| BowFletching ▸ Weapons ⟨1044566⟩ | Faerie Fire | 75 | 20 × Board (sub-res); 1 × LardOfParoxysmus; 10 × Putrefaction; 10 × Taint | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.FaerieFire; never exceptional |
| BowFletching ▸ Weapons ⟨1044566⟩ | Silvanis Feywood Bow | 75 | 20 × Board (sub-res); 1 × LardOfParoxysmus; 10 × Scourge; 10 × Muculent | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.SilvanisFeywoodBow; never exceptional |
| BowFletching ▸ Weapons ⟨1044566⟩ | Mischief Maker | 75 | 15 × Board (sub-res); 1 × DreadHornMane; 10 × Corruption; 10 × Putrefaction | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.MischiefMaker; never exceptional |
| BowFletching ▸ Weapons ⟨1044566⟩ | The Night Reaper | 75 | 10 × Board (sub-res); 1 × DreadHornMane; 10 × Blight; 10 × Scourge | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.TheNightReaper; never exceptional |
| BowFletching ▸ Weapons ⟨1044566⟩ | Barbed Longbow | 75 | 20 × Board (sub-res); 1 × FireRuby | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.BarbedLongbow |
| BowFletching ▸ Weapons ⟨1044566⟩ | Slayer Longbow | 75 | 20 × Board (sub-res); 1 × BrilliantAmber | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.SlayerLongbow |
| BowFletching ▸ Weapons ⟨1044566⟩ | Frozen Longbow | 75 | 20 × Board (sub-res); 1 × Turquoise | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.FrozenLongbow |
| BowFletching ▸ Weapons ⟨1044566⟩ | Longbow Of Might | 75 | 10 × Board (sub-res); 1 × BlueDiamond | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.LongbowOfMight |
| BowFletching ▸ Weapons ⟨1044566⟩ | Rangers Shortbow | 75 | 15 × Board (sub-res); 1 × PerfectEmerald | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.RangersShortbow |
| BowFletching ▸ Weapons ⟨1044566⟩ | Lightweight Shortbow | 75 | 15 × Board (sub-res); 1 × WhitePearl | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.LightweightShortbow |
| BowFletching ▸ Weapons ⟨1044566⟩ | Mystical Shortbow | 75 | 15 × Board (sub-res); 1 × EcruCitrine | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.MysticalShortbow |
| BowFletching ▸ Weapons ⟨1044566⟩ | Assassins Shortbow | 75 | 15 × Board (sub-res); 1 × DarkSapphire | 100% at 125; era: Mondain's Legacy; recipe (int)BowRecipes.AssassinsShortbow |


### 5.4 Alchemy

`DefAlchemy`, main skill `Alchemy`, gump title cliloc 1044007, `base(1,1,1.25)`, no repair, no resmelt.
Station: **mortar and pestle** with uses. **Every potion recipe additionally consumes 1 empty `Bottle`**
(also true for the potion-derived reagents).

`Source: Scripts/Services/Craft/DefAlchemy.cs`

### Alchemy — 51 recipes

Source: `Scripts/Services/Craft/DefAlchemy.cs`

System config: `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Refresh Potion | -25 | 1 × BlackPearl; 1 × Bottle | 100% at 25 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Total Refresh Potion | 25 | 5 × BlackPearl; 1 × Bottle | 100% at 75 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Lesser Heal Potion | -25 | 1 × Ginseng; 1 × Bottle | 100% at 25 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Heal Potion | 15 | 3 × Ginseng; 1 × Bottle | 100% at 65 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Greater Heal Potion | 55 | 7 × Ginseng; 1 × Bottle | 100% at 105 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Lesser Cure Potion | -10 | 1 × Garlic; 1 × Bottle | 100% at 40 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Cure Potion | 25 | 3 × Garlic; 1 × Bottle | 100% at 75 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Greater Cure Potion | 65 | 6 × Garlic; 1 × Bottle | 100% at 115 |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Elixir Of Rebirth | 65 | 1 × MedusaBlood; 3 × SpidersSilk; 1 × Bottle | 100% at 115; era: Stygian Abyss |
| Alchemy ▸ Potions: refresh / heal / cure ⟨1116348⟩ | Barrab Hemolymph Concentrate | 51 | 1 × Bottle; 20 × Ginseng; 5 × PlantClippings; 5 × MyrmidexEggsac | 100% at 151; era: Time of Legends; recipe (int)AlchemyRecipes.BarrabHemolymphConcentrate |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Agility Potion | 15 | 1 × Bloodmoss; 1 × Bottle | 100% at 65 |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Greater Agility Potion | 35 | 3 × Bloodmoss; 1 × Bottle | 100% at 85 |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Night Sight Potion | -25 | 1 × SpidersSilk; 1 × Bottle | 100% at 25 |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Strength Potion | 25 | 2 × MandrakeRoot; 1 × Bottle | 100% at 75 |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Greater Strength Potion | 45 | 5 × MandrakeRoot; 1 × Bottle | 100% at 95 |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Invisibility Potion | 65 | 1 × Bottle; 4 × Bloodmoss; 3 × Nightshade | 100% at 115; era: Mondain's Legacy; recipe (int)TinkerRecipes.InvisibilityPotion |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Jukari Burn Poiltice | 51 | 1 × Bottle; 20 × BlackPearl; 10 × Vanilla; 5 × LavaBerry | 100% at 151; era: Time of Legends; recipe (int)AlchemyRecipes.JukariBurnPoiltice |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Kurak Ambushers Essence | 51 | 1 × Bottle; 20 × Bloodmoss; 1 × BlueDiamond; 10 × TigerPelt | 100% at 151; era: Time of Legends; recipe (int)AlchemyRecipes.KurakAmbushersEssence |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Barako Draft Of Might | 51 | 1 × Bottle; 20 × SpidersSilk; 10 × BaseBeverage; 5 × PerfectBanana | 100% at 151; era: Time of Legends; recipe (int)AlchemyRecipes.BarakoDraftOfMight; Beverage=BeverageType.Liquor |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Urali Trance Tonic | 51 | 1 × Bottle; 20 × MandrakeRoot; 10 × YellowScales; 5 × RiverMoss | 100% at 151; era: Time of Legends; recipe (int)AlchemyRecipes.UraliTranceTonic |
| Alchemy ▸ Potions: agility / nightsight / strength / invisibility ⟨1116349⟩ | Sakkhra Prophylaxis Potion | 51 | 1 × Bottle; 20 × Nightshade; 10 × BaseBeverage; 5 × BlueCorn | 100% at 151; era: Time of Legends; recipe (int)AlchemyRecipes.SakkhraProphylaxisPotion; Beverage=BeverageType.Wine |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Lesser Poison Potion | -5 | 1 × Nightshade; 1 × Bottle | 100% at 45 |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Poison Potion | 15 | 2 × Nightshade; 1 × Bottle | 100% at 65 |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Greater Poison Potion | 55 | 4 × Nightshade; 1 × Bottle | 100% at 105 |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Deadly Poison Potion | 90 | 8 × Nightshade; 1 × Bottle | 100% at 140 |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Parasitic Potion | 65 | 1 × Bottle; 5 × ParasiticPlant | 100% at 115; era: Mondain's Legacy; recipe (int)TinkerRecipes.ParasiticPotion |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Darkglow Potion | 65 | 1 × Bottle; 5 × LuminescentFungi | 100% at 115; era: Mondain's Legacy; recipe (int)TinkerRecipes.DarkglowPotion |
| Alchemy ▸ Potions: poison ⟨1116350⟩ | Scouring Toxin | 75 | 1 × ToxicVenomSac; 1 × Bottle | 100% at 100; era: Mondain's Legacy |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Lesser Explosion Potion | 5 | 3 × SulfurousAsh; 1 × Bottle | 100% at 55 |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Explosion Potion | 35 | 5 × SulfurousAsh; 1 × Bottle | 100% at 85 |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Greater Explosion Potion | 65 | 10 × SulfurousAsh; 1 × Bottle | 100% at 115 |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Conflagration Potion | 55 | 1 × Bottle; 5 × GraveDust | 100% at 105; era: Mondain's Legacy |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Greater Conflagration Potion | 70 | 1 × Bottle; 10 × GraveDust | 100% at 120; era: Mondain's Legacy |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Confusion Blast Potion | 55 | 1 × Bottle; 5 × PigIron | 100% at 105; era: Mondain's Legacy |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Greater Confusion Blast Potion | 70 | 1 × Bottle; 10 × PigIron | 100% at 120; era: Mondain's Legacy |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Black Powder | 65 | 1 × SulfurousAsh; 6 × Saltpeter; 1 × Charcoal | 100% at 115; era: Stygian Abyss; consumes whole stack (batch) |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Matchcord | 25 | 1 × DarkYarn; 1 × BaseBeverage; 1 × Saltpeter; 1 × Potash | 100% at 80; era: NOT Endless Journey |
| Alchemy ▸ Potions: explosion / combat ⟨1116351⟩ | Fuse Cord | 55 | 1 × DarkYarn; 1 × BlackPowder; 1 × Potash | 100% at 105; era: Stygian Abyss; NeedWater |
| Alchemy ▸ Alchemy misc ⟨1116353⟩ | Smoke Bomb | 90 | 1 × Eggs; 3 × Ginseng | 100% at 120; era: Samurai Empire |
| Alchemy ▸ Alchemy misc ⟨1116353⟩ | Hovering Wisp | 75 | 4 × CapturedEssence | 100% at 125; era: Mondain's Legacy; recipe (int)TinkerRecipes.HoveringWisp |
| Alchemy ▸ Alchemy misc ⟨1116353⟩ | Natural Dye | 75 | 1 × PlantPigment; 1 × ColorFixative | 100% at 100; era: Stygian Abyss; ih=2101 |
| Alchemy ▸ Alchemy misc ⟨1116353⟩ | Nexus Core | 90 | 10 × MandrakeRoot; 10 × SpidersSilk; 5 × DarkSapphire; 5 × CrushedGlass | 100% at 120; era: Stygian Abyss; never exceptional |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Plant Pigment | 33 | 1 × PlantClippings; 1 × Bottle | 100% at 83; era: Stygian Abyss; ih=2101 |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Color Fixative | 75 | 1 × SilverSerpentVenom; 1 × BaseBeverage | 100% at 100; era: Stygian Abyss; Beverage=BeverageType.Wine |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Crystal Granules | 75 | 1 × ShimmeringCrystals | 100% at 100; era: Stygian Abyss; ih=2625 |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Crystal Dust | 75 | 4 × CrystallineFragments | 100% at 100; era: Stygian Abyss; ih=2103 |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Softened Reeds | 75 | 1 × DryReeds; 2 × ScouringToxin | 100% at 100; era: Stygian Abyss |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Vial Of Vitriol | 90 | 1 × ParasiticPotion; 30 × Nightshade | 100% at 100; era: Stygian Abyss; also needs Magery 75–100 |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Bottle Ichor | 90 | 1 × DarkglowPotion; 1 × SpidersSilk | 100% at 100; era: Stygian Abyss; also needs Magery 75–100 |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Potash | 0 | 1 × Board (sub-res); 1 × BaseBeverage | 100% at 50; era: High Seas; consumes whole stack (batch); NeedWater |
| Alchemy ▸ Ingredients / preparation ⟨1044495⟩ | Gold Dust | 90 | 1000 × Gold | 100% at 120; era: Stygian Abyss; never exceptional |


**Classic potion list with base reagents** (the "primary" reagent column is the `AddCraft` resource; the
remaining reagents are `AddRes` rows, 1 each — these are the *base* potions that pre-AoS shards should keep):

| potion | min skill | 100 % at | primary reagent | extra reagents | era |
|---|---|---|---|---|---|
| Lesser Heal | −25.0 | 25.0 | 1 Ginseng | 1 Bottle | classic |
| Heal | 15.0 | 65.0 | 3 Ginseng | 1 Bottle | classic |
| Greater Heal | 55.0 | 105.0 | 7 Ginseng | 1 Bottle | classic |
| Lesser Cure | −10.0 | 40.0 | 1 Garlic | 1 Bottle | classic |
| Cure | 25.0 | 75.0 | 3 Garlic | 1 Bottle | classic |
| Greater Cure | 65.0 | 115.0 | 6 Garlic | 1 Bottle | classic |
| Refresh | −25.0 | 25.0 | 1 Black Pearl | 1 Bottle | classic |
| Total Refresh | 25.0 | 75.0 | 5 Black Pearl | 1 Bottle | classic (AoS name) |
| Agility | 15.0 | 65.0 | 1 Bloodmoss | 1 Bottle | classic |
| Greater Agility | 35.0 | 85.0 | 3 Bloodmoss | 1 Bottle | classic |
| Night Sight | −25.0 | 25.0 | 1 Spider's Silk | 1 Bottle | classic |
| Strength | 25.0 | 75.0 | 2 Mandrake Root | 1 Bottle | classic |
| Greater Strength | 45.0 | 95.0 | 5 Mandrake Root | 1 Bottle | classic |
| Lesser Poison | −5.0 | 45.0 | 1 Nightshade | 1 Bottle | classic |
| Poison | 15.0 | 65.0 | 2 Nightshade | 1 Bottle | classic |
| Greater Poison | 55.0 | 105.0 | 4 Nightshade | 1 Bottle | classic |
| Deadly Poison | 90.0 | 140.0 | 8 Nightshade | 1 Bottle | classic |
| Lesser Explosion | 5.0 | 55.0 | 3 Sulfurous Ash | 1 Bottle | classic |
| Explosion | 35.0 | 85.0 | 5 Sulfurous Ash | 1 Bottle | classic |
| Greater Explosion | 65.0 | 115.0 | 10 Sulfurous Ash | 1 Bottle | classic |
| Invisibility | 65.0 | 115.0 | 1 Bottle | 4 Bloodmoss + 3 Nightshade | ML gated in ServUO |

### 5.5 Inscription

`DefInscription`, main skill `Inscription`, gump title cliloc 1044008, `base(1,1,1.25)`,
`MarkOption = true`; **`RequiresTool => !T2ACraftSystem.Enabled`** (no tool in T2A; scribe's pen otherwise),
and `CanCraft` additionally requires that the scribe already **knows the spell in a spellbook**
(`Spellbook.Find(from, id).HasSpell(id)`), else cliloc 1042404.
Scroll recipes are generated by `AddSpell(...)` inside `InitCraftList`; the gump group is the **circle**
(1111691 circle 0/1, 1111692 circle 2/3, 1111693 circle 4/5, 1111694 circle 6/7), plus group 1044294 for
runebooks/spellbooks/blank scrolls, 1061677 for necromancy and 1111671 for mysticism.
Every scroll also consumes **1 BlankScroll** (`AddRes(index, typeof(BlankScroll), 1044377, 1, 1044378)`).
A failed scroll inscription **ruins the blank scroll** (501630 — "You fail to inscribe the scroll, and the
scroll is ruined."), and non-scroll inscription failures follow the generic rule.

`Source: Scripts/Services/Craft/DefInscription.cs`

**Magery scrolls — skill window per circle** (identical `AddSpell` skill window for every spell in the circle;
last column is the mana requirement set by `SetManaReq`):

| circle | min skill | 100 % at | mana | spells |
|---|---|---|---|---|
| 1st (0) | −25.0 | 25.0 | 4 | Reactive Armor, Clumsy, Create Food, Feeblemind, Heal, Magic Arrow, Night Sight, Weaken |
| 2nd (1) | −10.8 | 39.2 | 6 | Agility, Cunning, Cure, Harm, Magic Trap, Magic Untrap, Protection, Strength |
| 3rd (2) | 3.5 | 53.5 | 9 | Bless, Fireball, Magic Lock, Poison, Telekinesis, Teleport, Unlock, Wall of Stone |
| 4th (3) | 17.8 | 67.8 | 11 | Arch Cure, Arch Protection, Curse, Fire Field, Greater Heal, Lightning, Mana Drain, Recall |
| 5th (4) | 32.1 | 82.1 | 14 | Blade Spirits, Dispel Field, Incognito, Magic Reflect, Mind Blast, Paralyze, Poison Field, Summon Creature |
| 6th (5) | 46.4 | 96.4 | 20 | Dispel, Energy Bolt, Explosion, Invisibility, Mark, Mass Curse, Paralyze Field, Reveal |
| 7th (6) | 60.7 | 110.7 | 40 | Chain Lightning, Energy Field, Flame Strike, Gate Travel, Mana Vampire, Mass Dispel, Meteor Swarm, Polymorph |
| 8th (7) | 75.0 | 125.0 | 50 | Earthquake, Energy Vortex, Resurrection, Summon Air Elemental, Summon Daemon, Summon Earth Elemental, Summon Fire Elemental, Summon Water Elemental |

**Exact reagent combinations (magery, 1 of each listed + 1 blank scroll):**

| circle | scroll | reagents |
|---|---|---|
| 1 | Reactive Armor | Garlic, Spider's Silk, Sulfurous Ash |
| 1 | Clumsy | Bloodmoss, Nightshade |
| 1 | Create Food | Garlic, Ginseng, Mandrake Root |
| 1 | Feeblemind | Nightshade, Ginseng |
| 1 | Heal | Garlic, Ginseng, Spider's Silk |
| 1 | Magic Arrow | Sulfurous Ash |
| 1 | Night Sight | Spider's Silk, Sulfurous Ash |
| 1 | Weaken | Garlic, Nightshade |
| 2 | Agility | Bloodmoss, Mandrake Root |
| 2 | Cunning | Nightshade, Mandrake Root |
| 2 | Cure | Garlic, Ginseng |
| 2 | Harm | Nightshade, Spider's Silk |
| 2 | Magic Trap | Garlic, Spider's Silk, Sulfurous Ash |
| 2 | Magic Untrap | Bloodmoss, Sulfurous Ash |
| 2 | Protection | Garlic, Ginseng, Sulfurous Ash |
| 2 | Strength | Nightshade, Mandrake Root |
| 3 | Bless | Garlic, Mandrake Root |
| 3 | Fireball | Black Pearl |
| 3 | Magic Lock | Bloodmoss, Garlic, Sulfurous Ash |
| 3 | Poison | Nightshade |
| 3 | Telekinesis | Bloodmoss, Mandrake Root |
| 3 | Teleport | Bloodmoss, Mandrake Root |
| 3 | Unlock | Bloodmoss, Sulfurous Ash |
| 3 | Wall of Stone | Bloodmoss, Garlic |
| 4 | Arch Cure | Garlic, Ginseng, Mandrake Root |
| 4 | Arch Protection | Garlic, Ginseng, Mandrake Root, Sulfurous Ash |
| 4 | Curse | Garlic, Nightshade, Sulfurous Ash |
| 4 | Fire Field | Black Pearl, Spider's Silk, Sulfurous Ash |
| 4 | Greater Heal | Garlic, Spider's Silk, Mandrake Root, Ginseng |
| 4 | Lightning | Mandrake Root, Sulfurous Ash |
| 4 | Mana Drain | Black Pearl, Spider's Silk, Mandrake Root |
| 4 | Recall | Black Pearl, Bloodmoss, Mandrake Root |
| 5 | Blade Spirits | Black Pearl, Nightshade, Mandrake Root |
| 5 | Dispel Field | Black Pearl, Garlic, Spider's Silk, Sulfurous Ash |
| 5 | Incognito | Bloodmoss, Garlic, Nightshade |
| 5 | Magic Reflect | Garlic, Mandrake Root, Spider's Silk |
| 5 | Mind Blast | Black Pearl, Mandrake Root, Nightshade, Sulfurous Ash |
| 5 | Paralyze | Garlic, Mandrake Root, Spider's Silk |
| 5 | Poison Field | Black Pearl, Nightshade, Spider's Silk |
| 5 | Summon Creature | Bloodmoss, Mandrake Root, Spider's Silk |
| 6 | Dispel | Garlic, Mandrake Root, Sulfurous Ash |
| 6 | Energy Bolt | Black Pearl, Nightshade |
| 6 | Explosion | Bloodmoss, Mandrake Root |
| 6 | Invisibility | Bloodmoss, Nightshade |
| 6 | Mark | Bloodmoss, Black Pearl, Mandrake Root |
| 6 | Mass Curse | Garlic, Mandrake Root, Nightshade, Sulfurous Ash |
| 6 | Paralyze Field | Black Pearl, Ginseng, Spider's Silk |
| 6 | Reveal | Bloodmoss, Sulfurous Ash |
| 7 | Chain Lightning | Black Pearl, Bloodmoss, Mandrake Root, Sulfurous Ash |
| 7 | Energy Field | Black Pearl, Mandrake Root, Spider's Silk, Sulfurous Ash |
| 7 | Flame Strike | Spider's Silk, Sulfurous Ash |
| 7 | Gate Travel | Black Pearl, Mandrake Root, Sulfurous Ash |
| 7 | Mana Vampire | Black Pearl, Bloodmoss, Mandrake Root, Spider's Silk |
| 7 | Mass Dispel | Black Pearl, Garlic, Mandrake Root, Sulfurous Ash |
| 7 | Meteor Swarm | Bloodmoss, Mandrake Root, Sulfurous Ash, Spider's Silk |
| 7 | Polymorph | Bloodmoss, Mandrake Root, Spider's Silk |
| 8 | Earthquake | Bloodmoss, Mandrake Root, Ginseng, Sulfurous Ash |
| 8 | Energy Vortex | Black Pearl, Bloodmoss, Mandrake Root, Nightshade |
| 8 | Resurrection | Bloodmoss, Garlic, Ginseng |
| 8 | Summon Air Elemental | Bloodmoss, Mandrake Root, Spider's Silk |
| 8 | Summon Daemon | Bloodmoss, Mandrake Root, Spider's Silk, Sulfurous Ash |
| 8 | Summon Earth Elemental | Bloodmoss, Mandrake Root, Spider's Silk |
| 8 | Summon Fire Elemental | Bloodmoss, Mandrake Root, Spider's Silk, Sulfurous Ash |
| 8 | Summon Water Elemental | Bloodmoss, Mandrake Root, Spider's Silk |

**Necromancy scrolls (Core.SE)** — group 1061677, window is `[minSkill, minSkill + 1.0]` (OSI-accurate: a
1.0-wide window), +1 blank scroll each:

| scroll | min skill | 100 % at | mana | reagents |
|---|---|---|---|---|
| Animate Dead | 39.6 | 40.6 | 23 | Grave Dust, Daemon Blood |
| Blood Oath | 19.6 | 20.6 | 13 | Daemon Blood |
| Corpse Skin | 19.6 | 20.6 | 11 | Bat Wing, Grave Dust |
| Curse Weapon | 19.6 | 20.6 | 7 | Pig Iron |
| Evil Omen | 19.6 | 20.6 | 11 | Bat Wing, Nox Crystal |
| Horrific Beast | 39.6 | 40.6 | 11 | Bat Wing, Daemon Blood |
| Lich Form | 69.6 | 70.6 | 23 | Grave Dust, Daemon Blood, Nox Crystal |
| Mind Rot | 29.6 | 30.6 | 17 | Bat Wing, Daemon Blood, Pig Iron |
| Pain Spike | 19.6 | 20.6 | 5 | Grave Dust, Pig Iron |
| Poison Strike | 49.6 | 50.6 | 17 | Nox Crystal |
| Strangle | 64.6 | 65.6 | 29 | Daemon Blood, Nox Crystal |
| Summon Familiar | 29.6 | 30.6 | 17 | Bat Wing, Grave Dust, Daemon Blood |
| Vampiric Embrace | 98.6 | 99.6 | 23 | Bat Wing, Nox Crystal, Pig Iron |
| Vengeful Spirit | 79.6 | 80.6 | 41 | Bat Wing, Grave Dust, Pig Iron |
| Wither | 59.6 | 60.6 | 23 | Grave Dust, Nox Crystal, Pig Iron |
| Wraith Form | 19.6 | 20.6 | 17 | Nox Crystal, Pig Iron |
| Exorcism | 79.6 | 80.6 | 40 | Nox Crystal, Grave Dust |

**Mysticism scrolls (Core.SA)** — group 1111671, window `[minSkill, minSkill + 1.0]`, +1 blank scroll each:

| scroll | min skill | 100 % at | mana | reagents |
|---|---|---|---|---|
| Nether Bolt | 0.0 | 1.0 | 4 | Sulfurous Ash, Black Pearl |
| Healing Stone | 0.0 | 1.0 | 4 | Bone, Garlic, Ginseng, Spider's Silk |
| Purge Magic | 0.0 | 1.0 | 6 | Fertile Dirt, Garlic, Mandrake Root, Sulfurous Ash |
| Enchant | 0.0 | 1.0 | 6 | Spider's Silk, Mandrake Root, Sulfurous Ash |
| Sleep | 3.5 | 4.5 | 9 | Spider's Silk, Black Pearl, Nightshade |
| Eagle Strike | 3.5 | 4.5 | 9 | Spider's Silk, Bloodmoss, Mandrake Root, Bone |
| Animated Weapon | 17.8 | 18.8 | 11 | Bone, Black Pearl, Mandrake Root, Nightshade |
| Stone Form | 17.8 | 18.8 | 11 | Bloodmoss, Fertile Dirt, Garlic |
| Spell Trigger | 32.1 | 33.1 | 14 | Spider's Silk, Mandrake Root, Garlic, Dragon Blood |
| Mass Sleep | 32.1 | 33.1 | 14 | Spider's Silk, Nightshade, Ginseng |
| Cleansing Winds | 46.4 | 47.4 | 20 | Ginseng, Garlic, Dragon Blood, Mandrake Root |
| Bombard | 46.4 | 47.4 | 20 | Garlic, Dragon Blood, Sulfurous Ash, Bloodmoss |
| Spell Plague | 60.7 | 61.7 | 40 | Daemon Bone ×2, Dragon Blood, Mandrake Root, Nightshade, Sulfurous Ash |
| Hail Storm | 60.7 | 61.7 | 40 | Dragon Blood, Black Pearl, Mandrake Root, Bloodmoss |
| Nether Cyclone | 75.0 | 76.0 | 50 | Bloodmoss, Nightshade, Sulfurous Ash, Mandrake Root |
| Rising Colossus | 75.0 | 76.0 | 50 | Daemon Bone, Fertile Dirt, Dragon Blood, Nightshade, Mandrake Root |

**Inscription misc recipes** (group 1044294):

### Inscription — 16 recipes

Source: `Scripts/Services/Craft/DefInscription.cs`

System config: `MarkOption` = true; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Enchanted Switch | 45 | 1 × BlankScroll; 1 × SpidersSilk; 1 × BlackPearl; 1 × SwitchItem | 100% at 95; era: Mondain's Legacy; never exceptional |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Runed Prism | 45 | 1 × BlankScroll; 1 × SpidersSilk; 1 × BlackPearl; 1 × HollowPrism | 100% at 95; era: Mondain's Legacy; never exceptional |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Runebook | 45 | 8 × BlankScroll; 1 × RecallScroll; 1 × GateTravelScroll | 100% at 95 |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Runic Atlas | 45 | 24 × BlankScroll; 3 × RecallRune; 3 × RecallScroll; 3 × GateTravelScroll | 100% at 95; era: Time of Legends; recipe (int)InscriptionRecipes.RunicAtlas |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Engines.Bulk Orders.Bulk Order Book | 65 | 10 × BlankScroll | 100% at 115; era: AoS |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Spellbook | 50 | 10 × BlankScroll | 100% at 126; era: Samurai Empire |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Scrappers Compendium | 75 | 100 × BlankScroll; 1 × DreadHornMane; 10 × Taint; 10 × Corruption | 100% at 125; era: Mondain's Legacy; recipe (int)TinkerRecipes.ScrappersCompendium; never exceptional |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Spellbook Engraver | 75 | 1 × Feather; 7 × BlackPearl | 100% at 100; era: Mondain's Legacy |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Necromancer Spellbook | 50 | 10 × BlankScroll | 100% at 100; era: Mondain's Legacy |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Mystic Book | 50 | 10 × BlankScroll | 100% at 100; era: Mondain's Legacy |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Exodus Summoning Rite | 95 | 5 × DaemonBlood; 1 × Taint; 5 × DaemonBone; 1 × SummonDaemonScroll | 100% at 120; era: Stygian Abyss |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Prophetic Manuscript | 90 | 10 × AncientParchment; 1 × AntiqueDocumentsKit; 10 × WoodPulp; 5 × Beeswax | 100% at 115; era: Stygian Abyss |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Blank Scroll | 50 | 1 × WoodPulp | 100% at 100; era: Stygian Abyss |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Scroll Binder Deed | 75 | 1 × WoodPulp | 100% at 125; era: Stygian Abyss; ih=1641 |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Gargoyle Book 100 | 60 | 40 × BlankScroll; 2 × Beeswax | 100% at 100; era: Stygian Abyss |
| Inscription ▸ Miscellaneous (scrolls, books, runebook) ⟨1044294⟩ | Gargoyle Book 200 | 72 | 40 × BlankScroll; 4 × Beeswax | 100% at 100; era: Stygian Abyss |


### 5.6 Cooking

`DefCooking`, main skill `Cooking`, gump title cliloc 1044009, `base(1,1,1.25)`. Station: **skillet / flour
sifter / rolling pin** type tool with uses; several recipes additionally require a heat source
(`SetNeedHeat`), an oven (`SetNeedOven`), water (`SetNeedWater`) or a mill (`SetNeedMill`) — those flags are
listed in the notes column. `RequiresBeverage` defaults to `BeverageType.Water`.

`Source: Scripts/Services/Craft/DefCooking.cs`

### Cooking — 88 recipes

Source: `Scripts/Services/Craft/DefCooking.cs`

System config: `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Sack Flour | 0 | 2 × WheatSheaf | 100% at 100; NeedMill |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Dough | 0 | 1 × SackFlourOpen; 1 × BaseBeverage | 100% at 100 |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Sweet Dough | 0 | 1 × Dough; 1 × JarHoney | 100% at 100 |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Cake Mix | 0 | 1 × SackFlourOpen; 1 × SweetDough | 100% at 100 |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Cookie Mix | 0 | 1 × JarHoney; 1 × SweetDough | 100% at 100 |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Cocoa Butter | 0 | 1 × CocoaPulp | 100% at 100; era: Mondain's Legacy; ih=0x457; NeedOven |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Cocoa Liquor | 0 | 1 × CocoaPulp; 1 × EmptyPewterBowl | 100% at 100; era: Mondain's Legacy; ih=0x46A; NeedOven |
| Cooking ▸ Ingredients / preparation ⟨1044495⟩ | Wheat Wort | 30 | 1 × Bottle; 1 × BaseBeverage; 1 × SackFlourOpen | 100% at 100; ih=1281 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Unbaked Quiche | 0 | 1 × Dough; 1 × Eggs | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Unbaked Meat Pie | 0 | 1 × Dough; 1 × RawRibs | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Uncooked Sausage Pizza | 0 | 1 × Dough; 1 × Sausage | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Uncooked Cheese Pizza | 0 | 1 × Dough; 1 × CheeseWheel | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Unbaked Fruit Pie | 0 | 1 × Dough; 1 × Pear | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Unbaked Peach Cobbler | 0 | 1 × Dough; 1 × Peach | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Unbaked Apple Pie | 0 | 1 × Dough; 1 × Apple | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Unbaked Pumpkin Pie | 0 | 1 × Dough; 1 × Pumpkin | 100% at 100 |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Green Tea | 80 | 1 × GreenTeaBasket; 1 × BaseBeverage | 100% at 130; era: Samurai Empire; NeedOven |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Wasabi Clumps | 70 | 1 × BaseBeverage; 3 × WoodenBowlOfPeas | 100% at 120; era: Samurai Empire |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Sushi Rolls | 90 | 1 × BaseBeverage; 10 × RawFishSteak | 100% at 120; era: Samurai Empire |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Sushi Platter | 90 | 1 × BaseBeverage; 10 × RawFishSteak | 100% at 120; era: Samurai Empire |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Tribal Paint |  | 1 × SackFlourOpen; 1 × TribalBerry | — |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Egg Bomb | 90 | 1 × Eggs; 3 × SackFlourOpen | 100% at 120; era: Samurai Empire |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Parrot Wafer | 37.5 | 1 × Dough; 1 × JarHoney; 10 × RawFishSteak | 100% at 87.5; era: Mondain's Legacy |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Plant Pigment | 75 | 1 × PlantClippings; 1 × Bottle | 100% at 100; era: Stygian Abyss |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Natural Dye | 65 | 1 × PlantPigment; 1 × ColorFixative | 100% at 115; era: Stygian Abyss |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Color Fixative | 75 | 1 × BaseBeverage; 1 × SilverSerpentVenom | 100% at 100; era: Stygian Abyss; Beverage=BeverageType.Wine |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Wood Pulp | 60 | 1 × BarkFragment; 1 × BaseBeverage | 100% at 100; era: Stygian Abyss |
| Cooking ▸ Uncooked / uncooked dishes ⟨1044496⟩ | Charcoal | 0 | 1 × Board (sub-res) | 100% at 50; era: High Seas; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Baked goods ⟨1044497⟩ | Bread Loaf | 0 | 1 × Dough | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Cookies | 0 | 1 × CookieMix | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Cake | 0 | 1 × CakeMix | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Muffins | 0 | 1 × SweetDough | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Quiche | 0 | 1 × UnbakedQuiche | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Meat Pie | 0 | 1 × UnbakedMeatPie | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Sausage Pizza | 0 | 1 × UncookedSausagePizza | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Cheese Pizza | 0 | 1 × UncookedCheesePizza | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Fruit Pie | 0 | 1 × UnbakedFruitPie | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Peach Cobbler | 0 | 1 × UnbakedPeachCobbler | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Apple Pie | 0 | 1 × UnbakedApplePie | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Pumpkin Pie | 0 | 1 × UnbakedPumpkinPie | 100% at 100; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Miso Soup | 60 | 1 × RawFishSteak; 1 × BaseBeverage | 100% at 110; era: Samurai Empire; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | White Miso Soup | 60 | 1 × RawFishSteak; 1 × BaseBeverage | 100% at 110; era: Samurai Empire; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Red Miso Soup | 60 | 1 × RawFishSteak; 1 × BaseBeverage | 100% at 110; era: Samurai Empire; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Awase Miso Soup | 60 | 1 × RawFishSteak; 1 × BaseBeverage | 100% at 110; era: Samurai Empire; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Ginger Bread Cookie | 35 | 1 × CookieMix; 1 × FreshGinger | 100% at 85; recipe (int)CookRecipes.GingerbreadCookie; NeedOven |
| Cooking ▸ Baked goods ⟨1044497⟩ | Three Tiered Cake | 60 | 3 × CakeMix | 100% at 110; recipe (int)CookRecipes.ThreeTieredCake; NeedOven |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Cooked Bird | 0 | 1 × RawBird | 100% at 100; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Chicken Leg | 0 | 1 × RawChickenLeg | 100% at 100; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Fish Steak | 0 | 1 × RawFishSteak | 100% at 100; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Fried Eggs | 0 | 1 × Eggs | 100% at 100; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Lamb Leg | 0 | 1 × RawLambLeg | 100% at 100; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Ribs | 0 | 1 × RawRibs | 100% at 100; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Bowl Of Rotworm Stew | 0 | 1 × RawRotwormMeat | 100% at 100; era: Stygian Abyss; recipe (int)CookRecipes.RotWormStew; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Bowl Of Blackrock Stew | 30 | 1 × BowlOfRotwormStew; 1 × SmallPieceofBlackrock | 100% at 70; era: Stygian Abyss; recipe (int)CookRecipes.BlackrockStew; ih=1954; never exceptional; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Khaldun Tasty Treat | 60 | 40 × RawFishSteak | 100% at 100; era: Endless Journey; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Hamburger | 40 | 1 × BreadLoaf; 1 × RawRibs; 1 × Lettuce | 100% at 80; era: Time of Legends; recipe (int)CookRecipes.Hamburger; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Hot Dog | 40 | 1 × BreadLoaf; 1 × Sausage | 100% at 80; era: Time of Legends; recipe (int)CookRecipes.HotDog; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Prepared food (meat / fish) ⟨1044498⟩ | Cookable Sausage | 30 | 1 × Ham; 1 × DriedHerbs | 100% at 70; era: Time of Legends; recipe (int)CookRecipes.Sausage; consumes whole stack (batch); NeedHeat |
| Cooking ▸ Special foods ⟨1073108⟩ | Food Engraver | 75 | 1 × Dough; 1 × JarHoney | 100% at 100; era: Mondain's Legacy |
| Cooking ▸ Special foods ⟨1073108⟩ | Enchanted Apple | 60 | 1 × Apple; 1 × GreaterHealPotion | 100% at 85; era: Mondain's Legacy; never exceptional |
| Cooking ▸ Special foods ⟨1073108⟩ | Grapes Of Wrath | 95 | 1 × Grapes; 1 × GreaterStrengthPotion | 100% at 120; era: Mondain's Legacy; never exceptional |
| Cooking ▸ Special foods ⟨1073108⟩ | Fruit Bowl | 55 | 1 × EmptyWoodenBowl; 3 × Pear; 3 × Apple; 3 × Banana | 100% at 105; era: Mondain's Legacy |
| Cooking ▸ Chocolate ⟨1080001⟩ | Sweet Cocoa Butter | 15 | 1 × SackOfSugar; 1 × CocoaButter | 100% at 100; era: Time of Legends; ih=0x457; NeedOven |
| Cooking ▸ Chocolate ⟨1080001⟩ | Dark Chocolate | 15 | 1 × SackOfSugar; 1 × CocoaButter; 1 × CocoaLiquor | 100% at 100; era: Mondain's Legacy; ih=0x465 |
| Cooking ▸ Chocolate ⟨1080001⟩ | Milk Chocolate | 32.5 | 1 × SackOfSugar; 1 × CocoaButter; 1 × CocoaLiquor; 1 × BaseBeverage | 100% at 107.5; era: Mondain's Legacy; ih=0x461; Beverage=BeverageType.Milk |
| Cooking ▸ Chocolate ⟨1080001⟩ | White Chocolate | 52.5 | 1 × SackOfSugar; 1 × CocoaButter; 1 × Vanilla; 1 × BaseBeverage | 100% at 127.5; era: Mondain's Legacy; ih=0x47E; Beverage=BeverageType.Milk |
| Cooking ▸ Chocolate ⟨1080001⟩ | Chocolate Nutcracker | 15 | 1 × SweetCocoaButter; 1 × SweetCocoaButter; 1 × CocoaLiquor | 100% at 100; era: Time of Legends; recipe (int)CookRecipes.DarkChocolateNutcracker |
| Cooking ▸ Chocolate ⟨1080001⟩ | Chocolate Nutcracker | 32.5 | 1 × SweetCocoaButter; 1 × SweetCocoaButter; 1 × CocoaLiquor | 100% at 107.5; era: Time of Legends; recipe (int)CookRecipes.MilkChocolateNutcracker |
| Cooking ▸ Chocolate ⟨1080001⟩ | Chocolate Nutcracker | 52.5 | 1 × SweetCocoaButter; 1 × SweetCocoaButter; 1 × CocoaLiquor | 100% at 127.5; era: Time of Legends; recipe (int)CookRecipes.WhiteChocolateNutcracker |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Great Barracuda Pie | 61 | 1 × GreatBarracudaSteak; 1 × MentoSeasoning; 1 × ZoogiFungus | 100% at 110; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Giant Koi Pie | 61 | 1 × GiantKoiSteak; 1 × MentoSeasoning; 1 × WoodenBowlOfPeas; 1 × Dough | 100% at 110; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Fire Fish Pie | 55 | 1 × FireFishSteak; 1 × Dough; 1 × Carrot; 1 × SamuelsSecretSauce | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Stone Crab Pie | 55 | 1 × StoneCrabMeat; 1 × Dough; 1 × Cabbage; 1 × SamuelsSecretSauce | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Blue Lobster Pie | 55 | 1 × BlueLobsterMeat; 1 × Dough; 1 × TribalBerry; 1 × SamuelsSecretSauce | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Reaper Fish Pie | 55 | 1 × ReaperFishSteak; 1 × Dough; 1 × Pumpkin; 1 × SamuelsSecretSauce | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Crystal Fish Pie | 55 | 1 × CrystalFishSteak; 1 × Dough; 1 × Apple; 1 × SamuelsSecretSauce | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Bull Fish Pie | 55 | 1 × BullFishSteak; 1 × Dough; 1 × Squash; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Summer Dragonfish Pie | 55 | 1 × SummerDragonfishSteak; 1 × Dough; 1 × Onion; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Fairy Salmon Pie | 55 | 1 × FairySalmonSteak; 1 × Dough; 1 × EarOfCorn; 1 × DarkTruffle | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Lava Fish Pie | 55 | 1 × LavaFishSteak; 1 × Dough; 1 × CheeseWheel; 1 × DarkTruffle | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Autumn Dragonfish Pie | 55 | 1 × AutumnDragonfishSteak; 1 × Dough; 1 × Pear; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Spider Crab Pie | 55 | 1 × SpiderCrabMeat; 1 × Dough; 1 × Lettuce; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Yellowtail Barracuda Pie | 55 | 1 × YellowtailBarracudaSteak; 1 × Dough; 1 × BaseBeverage; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Holy Mackerel Pie | 55 | 1 × HolyMackerelSteak; 1 × Dough; 1 × JarHoney; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Fish pies (High Seas) ⟨1116340⟩ | Unicorn Fish Pie | 55 | 1 × UnicornFishSteak; 1 × Dough; 1 × FreshGinger; 1 × MentoSeasoning | 100% at 105; era: Stygian Abyss; NeedOven |
| Cooking ▸ Beverage mugs ⟨1155736⟩ | Coffee Mug | 0 | 1 × CoffeeGrounds; 1 × BaseBeverage | 100% at 28.58; never exceptional; NeedMaker; Beverage=BeverageType.Water |
| Cooking ▸ Beverage mugs ⟨1155736⟩ | Basket Of Green Tea Mug | 0 | 1 × GreenTeaBasket; 1 × BaseBeverage | 100% at 28.58; never exceptional; NeedMaker; Beverage=BeverageType.Water |
| Cooking ▸ Beverage mugs ⟨1155736⟩ | Hot Cocoa Mug | 0 | 1 × CocoaLiquor; 1 × SackOfSugar; 1 × BaseBeverage | 100% at 28.58; never exceptional; NeedMaker; Beverage=BeverageType.Milk |


### 5.7 Cartography

`DefCartography`, main skill `Cartography`, gump title cliloc 1044010 (map maker's pen / mapmaker's pen for
non-T2A). `GetChanceAtMin` = default, no repair/resmelt.

`Source: Scripts/Services/Craft/DefCartography.cs`

### Cartography — 8 recipes

Source: `Scripts/Services/Craft/DefCartography.cs`

System config: `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Cartography ▸ Maps ⟨1044448⟩ | Local Map | 10 | 1 × BlankMap | 100% at 70 |
| Cartography ▸ Maps ⟨1044448⟩ | City Map | 25 | 1 × BlankMap | 100% at 85 |
| Cartography ▸ Maps ⟨1044448⟩ | Sea Chart | 35 | 1 × BlankMap | 100% at 95 |
| Cartography ▸ Maps ⟨1044448⟩ | World Map | 39.5 | 1 × BlankMap | 100% at 99.5 |
| Cartography ▸ Maps ⟨1044448⟩ | Tattered Wall Map South | 90 | 10 × TreasureMap; 5 × TreasureMap; 3 × TreasureMap; 1 × TreasureMap | 100% at 150 |
| Cartography ▸ Maps ⟨1044448⟩ | Tattered Wall Map East | 90 | 10 × TreasureMap; 5 × TreasureMap; 3 × TreasureMap; 1 × TreasureMap | 100% at 150 |
| Cartography ▸ Maps ⟨1044448⟩ | Eodonian Wall Map | 65 | 50 × BlankMap; 1 × UnabridgedAtlasOfEodon | 100% at 125; recipe (int)CartographyRecipes.EodonianWallMap |
| Cartography ▸ Maps ⟨1044448⟩ | Star Chart | 0 | 1 × BlankMap | 100% at 60 |


### 5.8 Glassblowing (SA)

`DefGlassblowing`, **main skill = `Alchemy`** (`DefGlassblowing.cs:29`) with
`GumpTitleNumber` 1111745-ish group; `MarkOption = Core.SA`, `Repair = Core.SA`. Requires a **blowpipe**,
**sand**, and the character flag `PlayerMobile.Glassblowing && Alchemy.Base >= 100.0`
(`DefGlassblowing.cs:58`). 22 recipes.

`Source: Scripts/Services/Craft/DefGlassblowing.cs`

### Glassblowing — 22 recipes

Source: `Scripts/Services/Craft/DefGlassblowing.cs`

System config: `Repair` = Core.SA; `MarkOption` = Core.SA; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Glassblowing ▸ Glassware ⟨1044050⟩ | Bottle | 52.5 | 1 × Sand | 100% at 102.5; consumes whole stack (batch) |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Small Flask | 52.5 | 2 × Sand | 100% at 102.5 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Medium Flask | 52.5 | 3 × Sand | 100% at 102.5 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Curved Flask | 55 | 2 × Sand | 100% at 105 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Long Flask | 57.5 | 4 × Sand | 100% at 107.5 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Large Flask | 60 | 5 × Sand | 100% at 110 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Ani Small Blue Flask | 60 | 5 × Sand | 100% at 110 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Ani Large Violet Flask | 60 | 5 × Sand | 100% at 110 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Ani Red Ribbed Flask | 60 | 7 × Sand | 100% at 110 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Empty Vials W Rack | 65 | 8 × Sand | 100% at 115 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Full Vials W Rack | 65 | 9 × Sand | 100% at 115 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Spinning Hourglass | 75 | 10 × Sand | 100% at 125 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Hollow Prism | 100 | 8 × Sand | 100% at 150; era: Mondain's Legacy |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Gargoyle Floor Mirror | 75 | 20 × Sand | 100% at 125; era: Stygian Abyss |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Gargoyle Wall Mirror | 70 | 10 × Sand | 100% at 120; era: Stygian Abyss |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Soulstone Fragment | 70 | 2 × CrystalGranules; 2 × VoidEssence | 100% at 120; era: Stygian Abyss; ih=1150 |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Empty Venom Vial | 52.5 | 1 × Sand | 100% at 102.5; era: Stygian Abyss |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Empty Oil Flask | 60 | 5 × Sand | 100% at 110; era: Stygian Abyss |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Workable Glass | 55 | 10 × Sand | 100% at 105; era: Stygian Abyss |
| Glassblowing ▸ Glassware ⟨1044050⟩ | Ethereal Soulbinder | 100 | 20 × Sand; 5 × EtherealSand | 100% at 190; era: Endless Journey |
| Glassblowing ▸ Glass weapons ⟨1111745⟩ | Glass Sword | 55 | 14 × Sand | 100% at 105; era: Stygian Abyss |
| Glassblowing ▸ Glass weapons ⟨1111745⟩ | Glass Staff | 53.6 | 10 × Sand | 100% at 103.6; era: Stygian Abyss |


### 5.9 Masonry (SA)

`DefMasonry`, **main skill = `Carpentry`** (`DefMasonry.cs:19`), `MarkOption = true`, `Repair = Core.SA`,
`CanEnhance = Core.SA`. Requires **mallet and chisel**, the character flag
`PlayerMobile.Masonry && Carpentry.Base >= 100.0` (`DefMasonry.cs:67`) and granite sub-resources (§2.3).
Four stone-armour recipes additionally need `Tailoring 70–75`. 59 recipes.

`Source: Scripts/Services/Craft/DefMasonry.cs`

### Masonry — 59 recipes

Source: `Scripts/Services/Craft/DefMasonry.cs`

System config: `Repair` = Core.SA; `MarkOption` = true; `CanEnhance` = Core.SA; `base_ctor` = 1, 1, 1.25

| category path (gump group) | item | min skill | materials (qty) | notes |
|---|---|---|---|---|
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Vase | 52.5 | 1 × Granite | 100% at 102.5 |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Large Vase | 52.5 | 3 × Granite | 100% at 102.5 |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Small Urn | 82 | 3 × Granite | 100% at 132; era: Samurai Empire |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Small Tower Sculpture | 82 | 3 × Granite | 100% at 132; era: Samurai Empire |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Gargoyle Painting | 83 | 3 × Granite | 100% at 133; era: Stygian Abyss |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Gargish Sculpture | 82 | 3 × Granite | 100% at 132; era: Stygian Abyss |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Gargoyle Vase | 80 | 3 × Granite | 100% at 126; era: Stygian Abyss |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Anniversary Vase Tall | 60 | 6 × Granite | 100% at 110; era: Time of Legends; recipe (int)MasonryRecipes.AnniversaryVaseTall |
| Masonry ▸ Sculptures & vases ⟨1044501⟩ | Anniversary Vase Short | 60 | 6 × Granite | 100% at 110; era: Time of Legends; recipe (int)MasonryRecipes.AnniversaryVaseShort |
| Masonry ▸ Stone furniture ⟨1044502⟩ | Stone Chair | 55 | 4 × Granite | 100% at 105 |
| Masonry ▸ Stone furniture ⟨1044502⟩ | Medium Stone Table East Deed | 65 | 6 × Granite | 100% at 115 |
| Masonry ▸ Stone furniture ⟨1044502⟩ | Medium Stone Table South Deed | 65 | 6 × Granite | 100% at 115 |
| Masonry ▸ Stone furniture ⟨1044502⟩ | Large Stone Table East Deed | 75 | 9 × Granite | 100% at 125 |
| Masonry ▸ Stone furniture ⟨1044502⟩ | Large Stone Table South Deed | 75 | 9 × Granite | 100% at 125 |
| Masonry ▸ Stone furniture ⟨1044502⟩ | Ritual Table Deed | 94.7 | 8 × Granite | 100% at 103.5 |
| Masonry ▸ Statues ⟨1044503⟩ | Statue South | 60 | 3 × Granite | 100% at 110 |
| Masonry ▸ Statues ⟨1044503⟩ | Statue North | 60 | 3 × Granite | 100% at 110 |
| Masonry ▸ Statues ⟨1044503⟩ | Statue East | 60 | 3 × Granite | 100% at 110 |
| Masonry ▸ Statues ⟨1044503⟩ | Statue Pegasus South | 70 | 4 × Granite | 100% at 120 |
| Masonry ▸ Statues ⟨1044503⟩ | Statue Gargoyle East | 54.5 | 20 × Granite | 100% at 104.5 |
| Masonry ▸ Statues ⟨1044503⟩ | Statue Gryphon East | 54.5 | 15 × Granite | 100% at 104.5 |
| Masonry ▸ Add-On Deeds ⟨1044290⟩ | Stone Anvil South Deed | 78 | 20 × Granite | 100% at 128; era: Mondain's Legacy; recipe (int)CarpRecipes.StoneAnvilSouth |
| Masonry ▸ Add-On Deeds ⟨1044290⟩ | Stone Anvil East Deed | 78 | 20 × Granite | 100% at 128; era: Mondain's Legacy; recipe (int)CarpRecipes.StoneAnvilEast |
| Masonry ▸ Add-On Deeds ⟨1044290⟩ | Large Gargoyle Bed South Deed | 76 | 3 × Granite; 100 × Cloth | 100% at 126; era: Stygian Abyss; also needs Tailoring 70–75 |
| Masonry ▸ Add-On Deeds ⟨1044290⟩ | Large Gargoyle Bed East Deed | 76 | 3 × Granite; 100 × Cloth | 100% at 126; era: Stygian Abyss; also needs Tailoring 70–75 |
| Masonry ▸ Add-On Deeds ⟨1044290⟩ | Gargish Cot East Deed | 76 | 3 × Granite; 100 × Cloth | 100% at 126; era: Stygian Abyss; also needs Tailoring 70–75 |
| Masonry ▸ Add-On Deeds ⟨1044290⟩ | Gargish Cot South Deed | 76 | 3 × Granite; 100 × Cloth | 100% at 126; era: Stygian Abyss; also needs Tailoring 70–75 |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Female Gargish Stone Arms | 56.3 | 8 × Granite | 100% at 106.3; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Female Gargish Stone Chest | 55 | 12 × Granite | 100% at 105; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Female Gargish Stone Legs | 58.8 | 10 × Granite | 100% at 108.8; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Female Gargish Stone Kilt | 48.9 | 6 × Granite | 100% at 98.9; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Gargish Stone Arms | 56.3 | 8 × Granite | 100% at 106.3; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Gargish Stone Chest | 65 | 12 × Granite | 100% at 115; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Gargish Stone Legs | 58.8 | 10 × Granite | 100% at 108.8; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Gargish Stone Kilt | 48.9 | 6 × Granite | 100% at 98.9; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Large Stone Shield | 55 | 16 × Granite | 100% at 105; era: Stygian Abyss |
| Masonry ▸ Stone (gargish) armor ⟨1111705⟩ | Gargish Stone Amulet | 60 | 3 × Granite | 100% at 110; era: Stygian Abyss |
| Masonry ▸ Stone weapons ⟨1111719⟩ | Stone War Sword | 55 | 18 × Granite | 100% at 105; era: Stygian Abyss |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=464 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=467 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=469 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=474 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=475 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=480 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=486 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable House Item | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=488 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable Stone House Door | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=804 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable Stone House Door | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=805 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable Stone House Door | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=804 |
| Masonry ▸ Eodon house items ⟨1155792⟩ | Craftable Stone House Door | 60 | 10 × Granite | 100% at 110; era: Time of Legends; did=805 |
| Masonry ▸ Eodon house items ⟨1155820⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1928 |
| Masonry ▸ Eodon house items ⟨1155820⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1929 |
| Masonry ▸ Eodon house items ⟨1155820⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1934 |
| Masonry ▸ Eodon house items ⟨1155820⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1938 |
| Masonry ▸ Eodon house items ⟨1155820⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1941 |
| Masonry ▸ Eodon house items ⟨1155820⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1945 |
| Masonry ▸ Eodon house items ⟨1155877⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1305 |
| Masonry ▸ Eodon house items ⟨1155877⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1309 |
| Masonry ▸ Eodon house items ⟨1155877⟩ | Craftable House Item | 60 | 5 × Granite | 100% at 110; era: Time of Legends; did=1313 |


---

## 6. CRAFTING ENGINE

### 6.1 Per-system configuration

| craft system | main skill | gump title cliloc | `base(min,max,delay)` | `ECA` | `GetChanceAtMin` | station requirement |
|---|---|---|---|---|---|---|
| Blacksmithy | Blacksmith | 1044002 | 1, 1, 1.25 | ChanceMinusSixtyToFourtyFive | 0.0 (0.05 for 2 artefacts) | anvil + forge within 2 tiles |
| Tailoring | Tailoring | 1044003 | 1, 1, 1.25 | ChanceMinusSixtyToFourtyFive | **0.5** (0.05 for 4 artefacts) | tool only |
| Carpentry | Carpentry | 1044004 | 1, 1, 1.25 | ChanceMinusSixtyToFourtyFive | **0.5** | tool only |
| Tinkering | Tinkering | 1044005 | 1, 1, 1.25 | ChanceMinusSixtyToFourtyFive | 0.0 (0.5 for potion keg & faction trap removal kit) | tool only |
| Bowcraft/Fletching | Fletching | 1044006 | 1, 1, 1.25 | FiftyPercentChanceMinusTenPercent | 0.5 | tool only |
| Alchemy | Alchemy | 1044007 | 1, 1, 1.25 | ChanceMinusSixty (default) | 0.0 | mortar & pestle |
| Inscription | Inscription | 1044008 | 1, 1, 1.25 | ChanceMinusSixty (default) | 0.0 | none in T2A, scribe's pen later |
| Cooking | Cooking | 1044009 | 1, 1, 1.25 | ChanceMinusSixtyToFourtyFive | 0.0 (0.5 for Grapes of Wrath / Enchanted Apple) | skillet etc. + heat/oven/water/mill flags |
| Cartography | Cartography | 1044010 | 1, 1, 1.25 | ChanceMinusSixty (default) | 0.0 | none in T2A, mapmaker's pen later |
| Glassblowing | **Alchemy** | — | 1, 1, 1.25 | default | 0.0 (0.5 HollowPrism, 0.1 EtherealSoulbinder) | blowpipe + sand + flag |
| Masonry | **Carpentry** | — | 1, 1, 1.25 | default | 0.0 | mallet & chisel + flag |

`MinCraftEffect = MaxCraftEffect = 1`, `Delay = 1.25 s` for every system (verified from every `Def*.cs`
constructor). Craft animation: `iRandom = Random(MaxCraftEffect - MinCraftEffect + 1) + MinCraftEffect + 1`
= 2 effect ticks spaced 1.25 s → the item is produced ≈2.5 s after the button press.

### 6.2 Success chance — exact formula

`CraftItem.GetSuccessChance` (`Scripts/Services/Craft/Core/CraftItem.cs:1367`):

```
if (ForceSuccessChance > -1) return ForceSuccessChance / 100.0;     // per-recipe override
allRequiredSkills = true
for each CraftSkill s in item.Skills:
    minSkill = s.MinSkill - MinSkillOffset          // MinSkillOffset default 0
    maxSkill = s.MaxSkill
    valSkill = from.Skills[s.SkillToMake].Value
    if (valSkill < minSkill) allRequiredSkills = false
    if (s.SkillToMake == system.MainSkill) { minMainSkill = minSkill; maxMainSkill = maxSkill; valMainSkill = valSkill }
    if (gainSkills && !UseAllRes) from.CheckSkill(s.SkillToMake, minSkill, maxSkill)   // passive gain
chance = allRequiredSkills
         ? GetChanceAtMin(item) + ((valMainSkill - minMainSkill) / (maxMainSkill - minMainSkill))
                                   * (1.0 - GetChanceAtMin(item))
         : 0.0
if (allRequiredSkills && talisman is BaseTalisman && talisman.CheckSkill(system)) chance += SuccessBonus / 100.0
if (WoodworkersBench.HasBonus(from, system.MainSkill)) chance += 0.5
if (allRequiredSkills && valMainSkill == maxMainSkill) chance = 1.0          // hard 100 % at max skill
roll: success = chance > Utility.RandomDouble()
```

Consequences to replicate exactly:
- Linear interpolation between the recipe's `min`/`max` skill, offset by the system's floor
  (0 %, or **50 % for Carpentry and Fletching**).
- Having *any* secondary skill below its minimum forces the chance to 0 ("You don't have the required skills
  to attempt this item.", cliloc 1044153) — that is how e.g. Tessen (Tailoring 50) or ButcherKnife
  (Animal Lore) gate blacksmith/tinker recipes.
- Recipes with `min > 100` (e.g. many ML artefacts at 75/125) are reachable only above 100 via
  **powerscrolls**; the final row `valMainSkill == maxMainSkill` turns them into 100 % crafts at exactly 125.
- A talisman `Success Bonus` property and the Woodworker's Bench (+0.5) are additive on top.
- `ForceSuccessChance` (set in source by `SetForceSuccess`) short-circuits everything.

### 6.3 Exceptional-quality chance — exact formula

`CraftItem.GetExceptionalChance` (`CraftItem.cs:1268`):

```
if (ForceNonExceptional) return 0.0
if (ForceExceptional && allRequiredSkills) return 1.0                     // 100 %
bonus = 0
if (talisman is BaseTalisman && talisman.CheckSkill(system)) bonus += talisman.ExceptionalBonus / 100.0
if (MasterChefsApron worn) bonus += apron.Bonus / 100.0
if (WoodworkersBench.HasBonus(from, system.MainSkill)) bonus += 0.3
switch (system.ECA):
  ChanceMinusSixty                     : chance -= 0.60
  FiftyPercentChanceMinusTenPercent    : chance  = chance * 0.50 - 0.10
  ChanceMinusSixtyToFourtyFive         : offset = 0.60 - (MainSkill.Value - 95.0) * 0.03
                                         offset = clamp(offset, 0.45, 0.60); chance -= offset
return (chance > 0) ? chance + bonus : chance
```

So with `ChanceMinusSixtyToFourtyFive` (Blacksmithy, Tailoring, Carpentry, Tinkering, Cooking) the
exceptional penalty is **−0.60 below 95 skill, tapering linearly to −0.45 at 100+**; with
`FiftyPercentChanceMinusTenPercent` (Fletching) it is `chance/2 − 10 %`; the default is a flat −60 %.
**This is the formula that makes exceptional items impossible before ~60–65 skill.**

### 6.4 The craft pipeline and its consequences

`CraftItem.Craft` → `InternalTimer` (2 ticks × 1.25 s) → `InternalTimer.OnTick` (`CraftItem.cs:2092`):

1. `CanCraft(from, tool, ItemType)` — tool present, not worn out, accessible, station in range.
2. `quality = 1; CheckSkills(from, res, system, ref quality, ref allRequiredSkills, gainSkills: false, 1)`
   → **roll #1**: sets `quality = 2` if the exceptional roll succeeds, returns success/failure.
3. Maker's mark decision: `if (quality == 2 && from.Skills[MainSkill].Base >= 100.0)
   makersMark = IsMarkable(ItemType)` — **only a 100.0-base crafter can mark**, and only exceptional items.
   If `context.MarkOption == PromptForMark && !autoCraft` → `QueryMakersMarkGump` (Yes/No prompt);
   `DoNotMark` forces `makersMark = false`; `AlwaysMark` proceeds silently.
4. `CompleteCraft(quality, makersMark, ...)`:
   a. `ConsumeRes(..., ConsumeType.None, ...)` — dry-run availability check, no consumption.
   b. `ConsumeAttributes` — mana/hits/stamina requirement (`SetManaReq`), dry run.
   c. `CheckSkills(..., gainSkills: true, ...)` → **roll #2**; *this* roll decides success. (The `quality`
      that reaches `OnCraft` is the one from roll #1 — the two rolls are independent, a genuine ServUO quirk.)
   d. On success: `ConsumeRes(..., ConsumeType.All)` (or `Half` for `UseAllRes`), `ConsumeAttributes(..., true)`,
      create the item, `OnCraft(quality, makersMark, ...)`.
   e. On failure: `ConsumeRes(..., UseAllRes ? Half : All, ..., isFailure: true)`, then the failure message.
   f. **Both paths** do `tool.UsesRemaining--;` and delete the tool when `UsesRemaining < 1 &&
      BreakOnDepletion`.
5. `PlayEndingEffect` messages: 1044154 "You create the item.", 1044155 exceptional, 1044156 exceptional with
   maker's mark, 502785 "barely able to make this item" (quality 0), 1044157 failure without loss,
   1044043 failure with loss, 1044038 tool worn out, 501630 scroll ruined (Inscription).

**Resources consumed on failure.** `ConsumeRes` (`CraftItem.cs:877`) applies, per resource type:

```csharp
if (isFailure && (talisman != null || !craftSystem.ConsumeOnFailure(from, types[i][0], this, ref talisman)))
    amounts[i] = 0;                       // resource is NOT consumed
```
`CraftSystem.ConsumeOnFailure` returns `!_GlobalNoConsume.Any(t => t == resourceType)` — i.e. **by default a
failed craft destroys the full material cost**, and only these resource types survive a failure
(`CraftSystem.cs`, `_GlobalNoConsume`): `CapturedEssence`, `EyeOfTheTravesty`, `DiseasedBark`,
`LardOfParoxysmus`, `GrizzledBones`, `DreadHornMane`, `Blight`, `Corruption`, `Muculent`, `Scourge`,
`Putrefaction`, `Taint`, `MidnightBracers`, `CrimsonCincture`, `GargishCrimsonCincture`,
`LeurociansMempoOfFortune`, `LeggingsOfBane`, `GauntletsOfNobility` (+ a carpentry list).
A charged **Master Craftsman Talisman** is spent instead of the materials (one charge per failed craft) and
prevents the loss.
For `UseAllRes` recipes (arrows, bolts, shafts, powder charges, cannonballs) the failure path uses
`ConsumeType.Half`: `amounts[i] /= 2` with a floor of 1, so half the stack is destroyed.
T2A-era note: ModernUO's reconstruction halves *every* resource on failure pre-UO:TD
(`dev-docs/t2a-crafting.md`); ServUO implements the modern all-or-nothing rule with the no-consume list.

**Tool requirement and durability.** Every craft costs exactly **1 use**, win or lose
(`tool.UsesRemaining--` in both branches, `CraftItem.cs:1915` and `:2036`). Tools are created with
`RandomMinMax(25, 75)` uses; exceptional tools have 200 % of that (`BaseTool.GetUsesScalar`), and
`HammerOfHephaestus` floors at 0 uses instead of breaking. An equipped `AncientSmithyHammer` /
`HammerOfHephaestus` in `Layer.OneHanded` **also** loses a use on every blacksmith craft
(`CraftItem.cs:1711`), on top of the tool itself.

**Skill gain hooks.**
- `gainSkills: true` in `CheckSkills` → `from.CheckSkill(skill, minSkill, maxSkill)` **for every skill in the
  recipe's skill list**, and this happens *before* the success roll, and only when `!UseAllRes`
  ("This is a passive check. Success chance is entirely dependent on the main skill").
- `UseAllRes` recipes instead call `MultipleSkillCheck(from, maxAmount)` on success (one check per unit
  produced) and `MultipleSkillCheck(from, 1)` on failure.
- `CraftItem.Craft` performs an extra `GetSuccessChance(..., gainSkills: false, ...)` before the timer purely
  to validate, so no skill is gained at button-press time.
- Lumberjacking is passively trained by swinging any axe (`BaseWeapon.cs:3777`); Alchemy-style "use skill"
  paths do not train.

### 6.5 "Make last" and "make number" batching

- `CraftContext.LastMade` / `LastResourceIndex` / `LastResourceIndex2` persist per mobile
  (`Scripts/Services/Craft/Core/CraftContext.cs`); `context.OnMade(item)` stores the recipe.
  "Make Last" (button in `CraftGump`, and in ModernUO's T2A flow "target the tool" to repeat) re-runs the
  stored `CraftItem` with the remembered resource index (and remembered hue); tinkered jewelry re-prompts for
  the gem instead of silently consuming it.
- "Make Number" (`Scripts/Services/Craft/Core/AutoCraft.cs`): the prompt accepts **1–100** (anything else →
  cliloc 1112587 "Invalid Entry."); `context.MakeTotal = amount`; an `AutoCraftTimer` is started with
  `delay = interval = Delay * MaxCraftEffect + 1.0 s` = **2.25 s** for every current system, one craft attempt
  per tick, stopped after `amount` ticks, when the player loses `NetState`, or on any error path
  (`AutoCraftTimer.EndTimer`). Each attempt re-runs the full pipeline (station check, resource availability,
  skill roll), so batching never bypasses the rules, and auto-crafted items never trigger the maker's-mark
  prompt (`!m_AutoCraft`).
- `SetUseAllRes` recipes have no "make number": one click converts the entire eligible stack
  (`maxAmount = min over resources of GetAmount / cost`, then `item.Amount = maxAmount`), which is the
  arrow/bolt/shaft/powder/cannonball economy.

### 6.6 Exceptional-quality effects

| effect | formula | source |
|---|---|---|
| Armour resists | `DistributeExceptionalBonuses(from, tool is BaseRunicTool ? 6 : (Core.SE ? 15 : 14))` — the point budget is thrown `Random(5)` times at physical/fire/cold/poison/energy, +1 each | `Scripts/Items/Equipment/Armor/BaseArmor.cs` (`OnCraft`) |
| Armour durability | `GetDurabilityBonus()` includes **+20** when `Quality == Exceptional`, plus durability-level bonuses (Durable +20, Substantial +50, Massive +70, Fortified +100, Indestructible +120); `ScaleDurability()` multiplies `HitPoints`/`MaxHitPoints` by `(100+bonus)/100`, capped at 255 | `BaseArmor.cs` |
| Weapon damage | `Attributes.WeaponDamage += 35` on an exceptional weapon (AoS+) | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs` (`OnCraft`) |
| Weapon durability | same `GetDurabilityBonus` scheme as armour (exceptional +20 %, durability levels +20…+120) | `BaseWeapon.cs` |
| Tool durability | exceptional tools get **2× uses** (`GetUsesScalar() == 200`) | `Scripts/Items/Tools/BaseTool.cs` |
| Maker's mark | `Crafter = from` on the item when `makersMark` was accepted; requires `quality == 2` **and** `MainSkill.Base >= 100.0` **and** `IsMarkable(ItemType)`; `MarkOption` may be Prompt / Always / Never | `CraftItem.cs:2160`, `QueryMakersMarkGump.cs` |
| Arms Lore (ML+) | exceptional armour: `bonus = ArmsLore.Value / 20` additional resist points randomly distributed (Siege: `/12.5`); exceptional weapons: `WeaponDamage += ArmsLore.Value / 20`; in both cases `from.CheckSkill(ArmsLore, 0, 100)` for a passive gain | `BaseArmor.DistributeExceptionalBonuses`, `BaseWeapon.OnCraft` |
| Coloured material | `Resource = CraftResources.GetFromType(typeRes)`; armour/clothing hue follows the resource in all eras, weapons only when `Core.AOS` | `BaseArmor/BaseWeapon.OnCraft` (also `ModernUO: dev-docs/t2a-crafting.md`) |
| Runic tools | `BaseRunicTool.ApplyAttributesTo(item)` distributes runic property budget; the exceptional budget drops to **6** points | `BaseArmor.OnCraft`, `Scripts/Items/Tools/BaseRunicTool.cs` |
| `ForceNonExceptional` | recipes flagged in §3–§5 can never be exceptional: no resists, no damage, no mark | `CraftItem.GetExceptionalChance` |

`PlayerConstructed = true` is set on every crafted item — this flag drives the smelt yield (§7.1), bulk-order
counting and "made by" naming.

---

## 7. SMELTING, REPAIR, IDENTIFICATION

### 7.1 Smelting ore → ingots (`Scripts/Items/Resource/Ore.cs:216-438`)

| rule | value |
|---|---|
| action | double-click a pile of ore → target a **forge** (`0xFA9`-family ids 4017, 6522–6569, or any `ForgeAttribute` item) or another ore pile (to combine) |
| range | 2 tiles to the ore and to the forge |
| skill gate | `if (difficulty > 50.0 && difficulty > Mining.Value && !smeltersTalisman) → 501986 "You have no idea how to smelt this strange ore!"` — iron (difficulty 50) is always allowed |
| difficulty per metal | iron/default **50**, dull copper 65, shadow iron 70, copper 75, bronze 80, gold 85, agapite 90, verite 95, valorite 99 |
| success roll | `CheckTargetSkill(Mining, forge, difficulty − 25, difficulty + 25)` — or automatic with a **Smelter's Talisman** matching the ore (spends 1 charge, cliloc 1152620) |
| yield (normal pile `0x19B8`) | `ingots = oreAmount` (**1 ore = 1 ingot**) |
| yield (small pile `0x19B7`) | `ingots = oreAmount / 2` (odd amount: consume amount−1); needs ≥ 2 ore (501987) |
| yield (large pile `0x19B9`) | `ingots = oreAmount × 2` |
| cap | at most 30000 ore converted per action |
| failure | ore is **halved** (`Amount /= 2`), or a pile of 1 is downgraded one size (`0x19B9→0x19B8→0x19B7`); message 501990 "You burn away the impurities but are left with less useable metal." |
| ore pile combining | worth = amount × (small 2 / normal 4 / large 8); caps 30000/60000/120000 by pile id; different metals cannot combine (501979) |

### 7.2 Smelting crafted items back into ingots (`Scripts/Services/Craft/Core/Resmelt.cs`)

| rule | value |
|---|---|
| eligible targets | `BaseArmor`, `BaseWeapon`, `DragonBardingDeed` only (1044272 otherwise) |
| resource type | must be `CraftResourceType.Metal` |
| minimum metal | the recipe's **primary** resource amount must be **≥ 2**, otherwise "Not enough metal to resmelt" |
| skill gate | `skill = max(Mining.Value, Blacksmith.Value)` must be ≥ the metal difficulty (iron 0, dull copper 65, shadow iron 70, copper 75, bronze 80, gold 85, agapite 90, verite 95, valorite 99); otherwise 1044269 "You have no idea how to work this metal." |
| **yield** | `ingot.Amount = (int)(craftItem.Resources[0].Amount * 0.66)` when the item is `PlayerConstructed` (or a DragonBardingDeed) — **66 % of the original ingot cost, truncated**; a store-bought item yields exactly **1** ingot |
| failure chance | none beyond the skill gate — smelting never destroys the item on a pass |
| blocked | imbued items (`Ethics.Ethic.IsImbued`) cannot be smelted |
| station | anvil + forge required, same check as blacksmithing |
| salvage bag | `Scripts/Items/Containers/SalvageBag.cs` re-implements the same 66 % rule for bulk salvage and reports 1079975 "You failed to smelt some metal for lack of skill." |

Economy consequence: **a crafted-then-smelted item returns 66 %, so the material loop loses 34 % per cycle**;
combined with a full-cost failure (§6.4) the intended economy is strongly deflationary.

### 7.3 Repair (`Scripts/Services/Craft/Core/Repair.cs`)

Repair is started from the craft gump's Repair button (`Repair.Do(from, system, tool)`) or from a
**Repair Deed** / **Repair Bench addon**, and targets an item; range 2.

| rule | formula / value |
|---|---|
| eligible item | `craftSystem.CraftItems.SearchForSubclass(item.GetType()) != null` or `IRepairable` with a matching `RepairSystem`; otherwise 1044277 |
| location | must be in the backpack (`!Core.ML` also allows being worn) — 1044275 |
| full repair | `HitPoints == MaxHitPoints` → 1044281 |
| destroyed | `MaxHitPoints <= toWeaken` → 1044278 "That item has been repaired many times, and will break if repairs are attempted again." |
| weapon poison (pre-AoS) | poisoned weapons cannot be repaired (1005012) |
| **max-durability loss (`toWeaken`)** | `Core.AOS` → **1**; pre-AoS and skill ≠ Tailoring → 3 if skill < 70, 2 if 70 ≤ skill < 90, 1 if ≥ 90; Tailoring → 0 |
| **weaken chance** | `GetWeakenChance = 40 + (maxHits − curHits) − (int)(skillValue / 10)` percent; `CheckWeaken = chance > Random(100)` |
| **repair difficulty** | `GetRepairDifficulty = ((maxHits − curHits) * 1250 / max(maxHits,1)) − 250` (in tenths) → `difficulty = that * 0.1` |
| **skill check** | `mob.CheckSkill(skill, difficulty − 25.0, difficulty + 25.0)` (Tinkering is temporarily locked during the check so it gains nothing) |
| deed / bench path | `value = deed.SkillLevel` (or bench tool skill); `< difficulty − 25` → automatic fail, `>= difficulty + 25` → automatic success, else `chance = (value − (difficulty−25)) / 50` |
| success effect | `item.HitPoints = item.MaxHitPoints` (full restore) + craft sound; failure → 1044280, and a repair deed is destroyed (1061137) |
| durability after | the weaken step is applied **before** the check, so a failed repair still permanently costs `toWeaken` max durability |

Worked example: a plate chest (MaxHitPoints 60) at 20 hits, 100 Blacksmithing (AoS rules):
`weakenChance = 40 + 40 − 10 = 70 %` to lose 1 max HP; `difficulty = ((60−20)*1250/60 − 250)/10 = 58.3`;
`CheckSkill(Blacksmith, 33.3, 83.3)` → ≈ 100 % at 100 skill (since value ≥ max). Repairing a *nearly broken*
item is therefore cheap in skill but expensive in permanent durability.

### 7.4 Item identification / Arms Lore

`Scripts/Skills/ArmsLore.cs` — target a weapon, `CheckTargetSkill(ArmsLore, target, 0, 100)`; on success it
reports the weapon's damage tier and handedness via cliloc `1038224 + damage*9` etc., where
`damage = (MaxDamage + MinDamage) / 2` bucketed as: `<3 → 0`, `<6 → 1`, `<11 → 2`, `<16 → 3`, `<21 → 4`,
`<26 → 5`, else `6` (AoS branch uses `ceil(min(damage,30)/5)` instead). `Scripts/Skills/ItemIdentification.cs`
provides the generic item appraisal (identified flag, magical properties), used by `Item.Identified` /
`BaseWeapon.Identified` which runic crafting sets automatically (see runic tables in `BaseWeapon.OnCraft`).
Arms Lore additionally feeds exceptional quality when `Core.ML` (§6.6). Pre-AoS Arms Lore also granted a
weapon damage bonus in the original game; **ServUO does not implement that** (§9 item U8).

---

## 8. RESOURCE-TO-ITEM ECONOMY RATIOS (anti-inflation reference)

| suit | pieces | ingots |
|---|---|---|
| Full platemail (chest/legs/arms/gloves/gorget/helm) | 6 | 100.0 |
| Full ringmail | 4 | 58.0 |
| Full chainmail | 3 | 48.0 |

Full material chains (each row is what a player must actually gather), all values extracted from §3–§5:

| product | conversion chain | net material cost |
|---|---|---|
| 1 iron ingot | 1 iron ore → forge smelt (1:1) | 1 ore, ~1 mining swing |
| 1 board | 1 log → axe/carpentry (1:1) | 1 log = 1 lumberjacking swing (yields 10 logs, 20 in Felucca) |
| 1 arrow / 1 bolt | 1 board → 1 shaft → 1 shaft + 1 feather | 1 board + 1 feather |
| 1 full platemail suit (6 pieces) | 100 ingots (chest 25, legs 20, arms 18, gloves 12, gorget 10, helm 15) | **100 ore** |
| full ringmail suit (4 pieces) | 58 ingots | 58 ore |
| full chainmail suit (3 pieces) | 48 ingots | 48 ore |
| 1 potion of any classic type | 1 empty bottle + 1–10 reagents of one kind | 1 bottle + N reagents |
| 1 inscribed scroll | 1 blank scroll + 1–4 reagents | 1 blank scroll + reagents |
| 1 smelted-back plate chest | 66 % of 25 = **16** ingots (floor) | loses 9 ingots |
| mining one 8×8 bucket | 10–34 ore, respawn 10–20 min | a plate suit ≈ 3–10 buckets ≈ 30–200 min of respawn time |
| lumberjacking one 4×3 bucket | 20–45 logs, respawn 20–30 min | 10 logs/swing → ~1 suit of wood gear per bucket |

Failure-cost multipliers (from §6.4): a failed craft consumes the **full** recipe cost (except the
`_GlobalNoConsume` artefact reagents), and a failed `UseAllRes` craft consumes **half the stack**. A failed
forge smelt halves the ore pile. A repair costs up to `toWeaken` (1–3) permanent max-durability points with a
40–~70 % chance of applying. Together these mean the clone should *not* multiply yields per swing: the
1 ore → 1 ingot → 1/25-of-a-chest chain plus 34 % smelt loss plus failure loss is the intended sink.

---

## 9. UNVERIFIED ITEMS AND HOW TO MEASURE THEM

| id | item | what is unverified | what is needed to measure it |
|---|---|---|---|
| U1 | **Weights / DefaultWeight** for most resources | ServUO omits `Weight` for many classes and inherits the client's tiledata value, which is not in the repos (`tiledata` values in §2.1 marked "tiledata" are placeholders) | read the client `tiledata.mul` (art → weight/height/quality/flags) with a UO tiledata reader (e.g. UOFiddler / `ClassicUO` data loader) for each art id in §2.1 |
| U2 | **Craft-gump category names** | ServUO names groups by cliloc only; §3–§5 names are taken from ModernUO's T2A menu literals or derived from the group's member items. Not all are the exact modern client strings | read `cliloc.enu` (client data file) and resolve the `⟨cliloc⟩` values listed per group |
| U3 | **Coloured ore / wood era split** | which publish introduced dull copper…valorite, and oak…frostwood, is not stated in the source; only `if (Core.ML)` guards are visible | UOGuide "Mining"/"Lumberjacking" publish history, or patch notes ("Ore colour" patch); not measurable from source |
| U4 | **Fishing junk/rare-fish rows** | `m_MutateTable` rows for footwear (Boots/Shoes/Sandals/ThighBoots) and Prized/Wondrous/TrulyRare/Peculiar fish have `MinSkill 125 > MaxSkill`, so they can never fire; the original pre-AoS chances are unknown | ClassicUO/OSI-era fishing table (UOGuide "Fishing"), or live-sphere measurement on a reference shard |
| U5 | **Sea serpents while fishing** | no serpent roll exists in `Scripts/Services/Harvest/Fishing.cs`; only `DeepSeaSerpent` construction in the SOS/shipwreck path. Whether the classic "sea serpent attacks the fisher" exists elsewhere is unconfirmed | search `Scripts/Mobiles/Normal`+`Scripts/Services/Fishing*` for spawn logic; measure on a reference shard |
| U6 | **Camping skill window** | the exact `CheckSkill(Camping, min, max)` window used when lighting a fire was not located in `Campfire.cs`/`Bedroll.cs` | read `Scripts/Items/Consumables/Kindling.cs` + the `Campfire` creation target end to end |
| U7 | **Cartography skill-use windows** | map-making target skill windows live in `LocalMap/CityMap/SeaChart/WorldMap`; only the crafted-map recipes are in §5.7 | read those four classes and `MapItem.cs` |
| U8 | **Pre-AoS Arms Lore damage bonus** | ServUO's damage pipeline (`BaseWeapon.GetBonus` calls) adds Str 0.30, Anatomy 0.50, Tactics 0.625, Lumberjacking 0.20 — **no Arms Lore term**; the classic pre-AoS "+1 % damage per 10 Arms Lore" is not modelled | UOGuide "Arms Lore" / pre-AoS Stratics warrior tables |
| U9 | **OSI-accurate harvest timing** | ServUO's `EffectDelay`/`EffectSoundDelay` produce ≈0.9 s per mining swing and 8 s per fishing attempt; OSI's exact swing cadence is not derivable from these values | packet capture on a reference client, or Stratics mining timer tables |
| U10 | **Consecutive-craft success streaks** | ServUO rolls exceptionality once (roll #1) and success again (roll #2) per craft — this double roll may be an implementation artefact rather than OSI behaviour | compare with a reference shard's observed exceptional rate at known skill |
| U11 | **Treasure-map chest quality per classic level 1–6** | `AssignChestQuality` only models the modern Stash…Trove ladder (difficulty 100…500) | UOGuide "Treasure Map" loot tables per level |
| U12 | **Item art ids for craftables** | §2 covers raw/intermediate resources only; each crafted item's `ItemID` comes from its own class in `Scripts/Items/**` (`CraftItem.ItemIDOf` resolves it by constructing the item) | run `CraftItem.ItemIDOf(type)` for every type in §3–§5 (the server can print it), or read each item class constructor |

### Extraction provenance (so the tables can be re-verified)

- Recipe tables: parser over `Scripts/Services/Craft/Def{Alchemy,Blacksmithy,BowFletching,Carpentry,Cartography,Cooking,Glassblowing,Inscription,Masonry,Tailoring,Tinkering}.cs`;
  every `AddCraft(...)` plus its following `AddRes`/`AddSkill`/`AddRecipe`/`ForceNonExceptional`/
  `SetUseAllRes`/`SetUseSubRes2`/`SetManaReq`/`SetNeed*` calls matched by the assignment variable in scope.
  1053 real recipes were emitted; all 1056 `AddCraft` call sites were parsed (the 3 extra are the single call
  sites inside the Inscription `AddSpell` / `AddNecroSpell` / `AddMysticSpell` helper bodies, which expand to
  97 scroll recipes transcribed by hand in §5.5 — 64 magery + 17 necromancy + 16 mysticism). 0 unparsed calls.
- Era tags: nearest enclosing `if (Core.XX)` block for each `AddCraft`, computed by brace matching.
- `UNVERIFIED` marks in the tables themselves: only the 8-argument `AddCraft` shape flag and any
  `? ×` resource amount (a resource whose amount is computed at runtime).
