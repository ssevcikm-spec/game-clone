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
