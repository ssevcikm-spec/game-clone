# Ultima Online — Core Simulation & Client Interaction Model

**Document 01 of the UO faithful-clone research series.**
Purpose: enough precise, cited detail to reimplement UO's core simulation and client interaction
**without ever launching the original client**.

Local source checkouts used for verification (shallow clones, read-only):

| Repo | Local path | Commit source |
|---|---|---|
| ServUO | `E:\Workspaces\game-clone\_src\servuo` | `github.com/ServUO/ServUO` (main) |
| ModernUO | `E:\Workspaces\game-clone\_src\modernuo` | `github.com/modernuo/ModernUO` (main) |
| ClassicUO | `E:\Workspaces\game-clone\_src\classicuo` | `github.com/ClassicUO/ClassicUO` (main) |
| SphereServer Source-X | `E:\Workspaces\game-clone\_src\sphere` | `github.com/Sphereserver/Source-X` |

> **Paths inside this document are relative to those checkouts.** A citation such as
> `servuo/Server/Mobile.cs:3063` means `E:\Workspaces\game-clone\_src\servuo\Server\Mobile.cs`
> line 3063. Wiki/web citations are full URLs.

---

## 0. How to read this document

### 0.1 Source-confidence legend

Every non-obvious number carries one of these tags:

| Tag | Meaning |
|---|---|
| **SC** — source-code-verified | Read directly out of ServUO / ModernUO / ClassicUO source. Two independent emulators agreeing is noted as **SC×2**. |
| **SC-C** — client-code-verified | Verified in ClassicUO (an *open-source reimplementation* of the client, not the original binary). It reproduces original behaviour but is not the original. |
| **WIKI** | From UOGuide / UO Stratics / uo.com patch notes. Not code-verified. |
| **UNCERTAIN** | Present in code but the code itself is a community approximation of EA behaviour. |
| **UNVERIFIED** | Could not be established from any source. What would have to be measured is stated. |

### 0.2 Era model used throughout

| Era key | Expansion | Launch | Flags (ServUO `Expansion` enum) |
|---|---|---|---|
| **Pre-T2A** | Ultima Online (original) | Sep 1997 | `Expansion.None` |
| **T2A** | The Second Age | Oct 1998 | `T2A` |
| **UOR / Renaissance** | Ultima Online: Renaissance | Apr 2000 | `UOR` |
| **UOTD / LBR** | Third Dawn / Lord Blackthorn's Revenge | 2001 / 2002 | `UOTD`, `LBR` |
| **AoS** | Age of Shadows | Feb 2003 | `AOS` |
| **SE** | Samurai Empire | Nov 2004 | `SE` |
| **ML** | Mondain's Legacy | Aug 2005 | `ML` |
| **SA** | Stygian Abyss | Sep 2009 | `SA` |
| **HS / ToL / EJ** | High Seas / Time of Legends / Endless Journey | 2010 / 2015 / 2018 | `HS`, `TOL`, `EJ` |

Reference: `servuo/Server/ExpansionInfo.cs:7-21` (**SC**).

ServUO gates behaviour at runtime through `Core.AOS`, `Core.SE`, `Core.ML`, `Core.SA`, `Core.HS`,
`Core.TOL` and `Core.Expansion` (`servuo/Server/ExpansionInfo.cs`, `servuo/Scripts/Misc/CurrentExpansion.cs`).

### 0.3 What "T2A/Renaissance + AoS hybrid" means for the clone

The project brief says the clone defaults to a **T2A/Renaissance + AoS hybrid**. Concretely, this
document recommends the hybrid be defined as:

| System | Hybrid choice | Rationale |
|---|---|---|
| Movement / step timing / Z rules | **Pre-AoS** (identical in every era; the algorithm never changed) | No era cost — same numbers everywhere |
| Felucca/Trammel split | **AoS** (both facets exist, mirror) | Trammel is the single biggest quality-of-life change; without it a single-player clone has no safe play space |
| Notoriety / flagging | **Pre-AoS Felucca semantics** as the default, but the Trammel rule set implemented and switchable | Preserves the "red = danger" feel |
| Context menus (right-click / click-on-self) | **AoS** | The interaction model the clone must "feel" like is fundamentally the AoS-and-later client |
| Item insurance | **Off by default, implemented** (AoS mechanic, config toggle) | Insurance trivialises death in single-player; keep the code, ship the switch off |
| Blessed / newbied flags | **Present** (pre-AoS origin, kept in all eras) | Newbie items are core to the feel |
| Skill/stat caps | **700.0 / 225** base, **720 / 250** via scrolls | Universal since AoS; power scrolls exist from AoS |
| GGS (guaranteed gain) | **On** | Introduced in an AoS-era publish; makes offline single-player progression sane |
| BODs, runic crafting, AoS resist types / LMC / etc. | **Omit initially** | AoS *itemisation* is not required by the interaction model; only the AoS *interface* is |
| Malas / Ilshenar / Tokuno / Ter Mur | **Optional content packs** — the core simulation must not depend on them | Ter Mur is post-SA and drags in Gargoyles, Imbuing, Mysticism |

Everything in this document states both the pre-AoS and AoS+ value wherever the code branches.

---

# 1. MOVEMENT

## 1.1 Step timing — the canonical numbers

The single most important table in this document. **All three code bases agree exactly.**

| Motion state | Delay per step (ms) | Source |
|---|---|---|
| Walk, on foot | **400** | **SC×3**: `servuo/Server/Mobile.cs:3063` (`m_WalkFoot = 400`); `modernuo/Projects/Server/Mobiles/Movement.cs:33` (`movement.delay.walkFoot` default `400`); `classicuo/src/ClassicUO.Client/Game/Data/MovementSpeed.cs:12` (`STEP_DELAY_WALK = 400`) |
| Run, on foot | **200** | **SC×3**: `servuo/Server/Mobile.cs:3064`; `modernuo/.../Movement.cs:34`; `classicuo/.../MovementSpeed.cs:11` |
| Walk, mounted | **200** | **SC×3**: `servuo/Server/Mobile.cs:3065`; `modernuo/.../Movement.cs:35`; `classicuo/.../MovementSpeed.cs:10` |
| Run, mounted | **100** | **SC×3**: `servuo/Server/Mobile.cs:3066`; `modernuo/.../Movement.cs:36`; `classicuo/.../MovementSpeed.cs:9` |
| Turn in place (no step) | **0 ms server-side**, **80 ms client-side** (45 ms with "fast rotation") | **SC**: `modernuo/.../Movement.cs:32` (`movement.delay.turn` default `0`); **SC-C**: `classicuo/src/ClassicUO.Client/Game/Constants.cs:17-18` (`TURN_DELAY = 80`, `TURN_DELAY_FAST = 45`) |
| Character animation frame | 80 ms | **SC-C**: `classicuo/.../Constants.cs:13` (`CHARACTER_ANIMATION_DELAY = 80`) |

Interpretation: **walk = 2.5 tiles/s, run = 5 tiles/s, mounted walk = 5 tiles/s, mounted run = 10 tiles/s**
(1 tile per step). A mount is exactly a 2× speed multiplier on top of foot speed. This has been
constant since 1997 and is the same in every era.

An era note: these delays are *minimum* inter-step spacing enforced by the server's fast-walk
detector, not a physics tick. The original client computes its own step cadence and the server
validates it (see §1.10).

## 1.2 Direction encoding

| Value | Direction | delta (x, y) |
|---|---|---|
| 0x00 | North | (0, −1) |
| 0x01 | Right (NE) | (+1, −1) |
| 0x02 | East | (+1, 0) |
| 0x03 | Down (SE) | (+1, +1) |
| 0x04 | South | (0, +1) |
| 0x05 | Left (SW) | (−1, +1) |
| 0x06 | West | (−1, 0) |
| 0x07 | Up (NW) | (−1, −1) |
| 0x80 | `Running` flag (OR-ed onto the above) | — |
| 0x07 | `Mask` | — |

**SC**: `servuo/Server/Mobile.cs` `enum Direction : byte` (line 380ff) and `servuo/Server/Movement.cs:31-64`
(`Offset`); cross-checked **SC-C** at `classicuo/src/ClassicUO.Client/Game/Data/Direction.cs:8-22`.

Note the counter-intuitive "screen-space" naming: direction values are derived from the *isometric
screen* mapping, so `Left` is screen-down-left and equals world (+x, −y) inverted. The numeric
values are what goes on the wire and must be reproduced exactly.

**Diagonal test:** a direction is diagonal iff `((int)d & 0x1) == 0x1` — i.e. odd values 1, 3, 5, 7.
**SC**: `servuo/Scripts/Services/Pathing/Movement.cs:380`.

## 1.3 Stamina cost of movement

### 1.3.1 The per-step drain (RunUO/ServUO/ModernUO model)

Implemented in `servuo/Scripts/Misc/WeightOverloading.cs:59-107` (**SC**), hooked to the movement
event. Per accepted step, for a player who is alive and not staff:

| Rule | Pre-SA | SA+ |
|---|---|---|
| Stamina lost per N steps on foot | **1 per 16 steps** | **1 per 10 steps** |
| Stamina lost per N steps mounted | **1 per 48 steps** | **1 per 10 steps** |
| Extra drain when stamina is below 10 % of max | **−1 stamina per step** (on top) | none |
| Movement blocked entirely | when `Stam == 0` | when `Stam == 0` |

Exact code (`WeightOverloading.cs:98-106`):

```csharp
var pm = from as PlayerMobile;
if (pm != null)
{
    int amt = Core.SA ? 10 : (from.Mounted ? 48 : 16);
    if ((++pm.StepsTaken % amt) == 0)
        --from.Stam;
}
```

and (`WeightOverloading.cs:86-96`):

```csharp
if (!Core.SA && ((from.Stam * 100) / Math.Max(from.StamMax, 1)) < 10)
{
    --from.Stam;
}

if (from.Stam == 0)
{
    from.SendLocalizedMessage(from.Mounted ? 500108 : 500110);
    // "Your mount is too fatigued to move." / "You are too fatigued to move."
    e.Blocked = true;
    return;
}
```

Localised messages: `500108` = "Your mount is too fatigued to move.",
`500110` = "You are too fatigued to move.", `500109` = "You are too fatigued to move, because you
are carrying too much weight!" — **SC** (`WeightOverloading.cs:80,93`).

> ⚠ **Era conflict / important caveat.** This per-step model charges stamina for **walking as well
> as running**. That is the *emulator's* approximation. The original EA client is widely believed to
> charge stamina only while running (and to be client-authoritative about it), which is why
> "stamina hacking" was a known cheat class. Neither ServUO, ModernUO nor ClassicUO implements a
> client-side run-only drain: ClassicUO only *reads* stamina and uses it to forbid running
> (`classicuo/.../GameObjects/PlayerMobile.cs:532`: `if (SpeedMode >= CharacterSpeedType.CantRun || Stamina <= 1 && !IsDead || ...) run = false;`).
> **Clone recommendation:** implement the run-only drain (1 stamina per step while running,
> 0 while walking, 0.5× while mounted) as the default because that is what players remember, and
> keep the emulator's step-counter model behind a flag. The precise original rate is **UNVERIFIED** —
> it would need to be measured by running the original client and counting running steps until the
> stamina bar empties at a fixed DEX.

### 1.3.2 Pushing another mobile

| Rule | Value | Source |
|---|---|---|
| You may only shove if `Stam == StamMax` (full stamina) | — | **SC**: `servuo/Server/Mobile.cs:3541` |
| Stamina cost of a successful shove | **10** | **SC**: `servuo/Server/Mobile.cs:3544` |
| Reveals the pusher | yes | **SC**: `servuo/Server/Mobile.cs:3546` |
| Message | `1019042` "You shove your way past." / `1019043` (hidden variant) / `1019040`,`1019041` (staff) | **SC**: `servuo/Server/Mobile.cs:3537,3543` |
| Disabled when map has `MapRules.FreeMovement` (Trammel) | yes | **SC**: `servuo/Server/Mobile.cs:3518` |

### 1.3.3 Fatigue from damage

`servuo/Scripts/Misc/WeightOverloading.cs:19-57` (**SC**), `DFAlgorithm.Standard`:

```
fatigue = damage * (HitsMax / Hits) * (Stam / StamMax) - 5
```

Then, EA-quirk guard: if `Stam - fatigue <= 10`, the loss is scaled by `Hits / HitsMax`
(so you are not knocked straight to 0). `DFAlgorithm.PainSpike` uses a different formula
(`WeightOverloading.cs:33`). Inherent stamina-loss reduction from armour divides the fatigue.

## 1.4 Stamina regeneration

| Parameter | Value | Source |
|---|---|---|
| Default stamina regen interval (fallback) | **7.0 s** | **SC**: `servuo/Scripts/Misc/RegenRates.cs:24` (`Mobile.DefaultStamRate = TimeSpan.FromSeconds(7.0)`) |
| Pre-SA stamina regen interval | `1 / (0.1 * (2 + bonus))` seconds → **5 s at bonus = 0**; +1 stamina per tick | **SC**: `servuo/Scripts/Misc/RegenRates.cs:106` |
| `bonus` term | `Focus × 0.1 + StamRegen(from)` (item `RegenStam` property) | **SC**: `RegenRates.cs:89-91` |
| SA+ stamina regen interval | `1 / (1.42 + bonus/100)` s; **×1.95 slower for monsters** | **SC**: `RegenRates.cs:95-102` |
| Regen only while `CanRegenStam` (i.e. alive) | — | **SC**: `servuo/Server/Mobile.cs:1909` |
| Stamina also refills to max on resurrect | `Stam = StamMax` | **SC**: `servuo/Server/Mobile.cs:3674` |

Regen is an integer +1 per tick; there is no fractional accumulation. ModernUO models this
identically (`modernuo/Projects/Server/Mobiles/Mobile.cs:9039-9052`, `StamTimer` → `m_Owner.Stam++`).

Related, for completeness (**SC**: `servuo/Scripts/Misc/RegenRates.cs:23-25,77-108,110-208`):

| Resource | Default interval | Formula |
|---|---|---|
| Hits | 11.0 s | `1 / (0.1 * (1 + HitPointRegen))` → 10 s at 0 bonus; +1 HP/tick |
| Mana | 7.0 s | Pre-AoS: piecewise in `medPoints = (INT + Meditation) * 0.5` — `7.0 - 239*mp/2400 + 19*mp²/48000` for `mp ≤ 100`, then `1.0` for `mp < 120`, else `0.75`; **+armour penalty**; **×0.5 while meditating**; clamped `[0.5, 7.0]` |
| Mana (AoS branch) | — | `1 / (0.1 * (2 + totalPoints))`, `totalPoints = Focus*0.05 + medPoints + (meditating ? min(medPoints,13) : 0) + ManaRegen` |
| Mana (ML branch) | — | `1 / (0.2 + focusBonus + medBonus + itemBonus)` |

## 1.5 Encumbrance

| Parameter | Value | Source |
|---|---|---|
| Player maximum weight | `40 + (int)(3.5 * STR)` (pre-ML) / `100 + (int)(3.5 * STR)` (ML **and** Human) | **SC**: `servuo/Scripts/Mobiles/PlayerMobile.cs:1101` |
| Body weight of the character itself | counted via `Mobile.BodyWeight` | **SC**: `WeightOverloading.cs:72` |
| Overload allowance before fatigue | **4 stones** | **SC**: `WeightOverloading.cs:11` (`OverloadAllowance = 4`) |
| Overweight stamina loss per step | `5 + (overWeight / 25)`, then **÷3 if mounted**, **×2 if running** | **SC**: `WeightOverloading.cs:109-120` |
| Overweight blocks movement | only when stamina reaches 0 | **SC**: `WeightOverloading.cs:78-83` |
| Backpack capacity (player, ML+) | 550 stones; otherwise the global container default 400 | **SC**: `servuo/Scripts/Items/Containers/Container.cs:451-472`; global default `servuo/Server/Items/Container.cs:1673` |
| Global container default capacity | **125 items / 400 stones** | **SC**: `servuo/Server/Items/Container.cs:1672-1673` (`m_GlobalMaxItems = 125`, `m_GlobalMaxWeight = 400`) |
| A container with `MaxWeight == 0` | unlimited weight (bank box, vendor packs) | **SC**: `servuo/Server/Items/Container.cs:151-164`, `servuo/Server/Items/Containers.cs:20` |

There is **no** pre-AoS "you cannot run while overweight" rule in the code. Overweight is purely a
stamina drain. **UNVERIFIED** whether the original client blocked running while overweight; the
ClassicUO condition for running is stamina-only (§1.3.1).

## 1.6 Z / height handling and step legality — the walkability algorithm

This is the core algorithm. Reproduce `servuo/Scripts/Services/Pathing/Movement.cs` (**SC**;
ModernUO's port at `modernuo/Projects/UOContent/Engines/Pathing/Movement.cs` is line-for-line
equivalent — **SC×2**).

### 1.6.1 Constants

| Constant | Value | Meaning |
|---|---|---|
| `PersonHeight` | **16** | the Z-extent of a mobile's body, in world units |
| `StepHeight` | **2** | how much higher a surface may be and still be *stepped onto* |
| `ImpassableSurface` | `TileFlag.Impassable \| TileFlag.Surface` | the flag combination that blocks |

**SC**: `servuo/Scripts/Services/Pathing/Movement.cs:10-13`; identical in
`modernuo/Projects/UOContent/Engines/Pathing/Movement.cs:11-12`.

### 1.6.2 Computing the starting Z (`GetStartZ`)

Given current tile `(x,y)` and the mobile's `loc.Z`:

1. Read the land tile. If the land tile is `Impassable` the land does not contribute
   (unless the mobile `CanSwim` and the land is `Wet`).
2. `map.GetAverageZ(x, y, out landZ, out landCenter, out landTop)` gives three Z values for the
   land: lowest corner, average, highest corner.
3. Land contributes `zLow = landZ`, `zCenter = landCenter`, `zTop = landTop` **only if
   `loc.Z >= landCenter`**.
4. For every static tile at `(x,y)` with `Surface` (or `Wet` for swimmers) whose
   `tile.Z + itemData.CalcHeight <= loc.Z`: it is a candidate; keep the one with the greatest
   `calcTop` (ties broken by iteration order).
5. For every *item* at `(x,y)` the same rule is applied.
6. If nothing qualified, `zLow = zTop = loc.Z`.

**SC**: `servuo/Scripts/Services/Pathing/Movement.cs:585-672`.
`CalcHeight` is `ItemData.CalcHeight` — the average of the tile's four corner heights, precomputed
from `tiledata.mul` (`servuo/Server/TileData.cs`, `ItemData` struct).

### 1.6.3 Testing the destination tile (`Check`)

For the destination tile, the candidate surface Z values are collected from land, statics and items
using the **same** "highest surface at or below the mobile's current Z" rule, with the important
refinement that candidates are ranked by **`|candidateZ - currentZ|`** (closest wins; ties go to the
higher Z):

```csharp
if (moveIsOk)
{
    int cmp = Math.Abs(ourZ - p.Z) - Math.Abs(newZ - p.Z);
    if (cmp > 0 || (cmp == 0 && ourZ > newZ)) continue;
}
```

**SC**: `servuo/Scripts/Services/Pathing/Movement.cs:222-228` (statics), `:283-289` (items),
`:330-336` (land).

A candidate surface is accepted only if **all** of the following hold:

| Condition | Code | Meaning |
|---|---|---|
| `stepTop >= itemTop` | `:236` | you can step up onto it: `startTop + StepHeight >= itemZ + itemData.Height` (with `itemTop = itemZ` for `Bridge` tiles, i.e. **bridges are walk-under, not stepped onto**) |
| Land sanity check | `:238-246` | the candidate must not be buried below the land's average Z |
| `IsOk(...)` | `:248` | **nothing impassable overlaps the mobile's Z extent** |

`IsOk` is the fundamental blocking test (`Movement.cs:74-132`):

```csharp
if ((itemData.Flags & ImpassableSurface) != 0)   // Impassable OR Surface
{
    int checkZ   = tile.Z;
    int checkTop = checkZ + itemData.CalcHeight;
    if (checkTop > ourZ && ourTop > checkZ)      // Z-extent overlap
        return false;
}
```

i.e. **an impassable-or-surface object blocks iff its `[Z, Z+CalcHeight)` band overlaps the
mobile's `[ourZ, ourZ+16)` band.**

Note the subtlety: `Surface` alone is enough to trigger the overlap test, because a *floor* you are
standing inside of must block. `Impassable` alone also triggers it, which is how walls block.

### 1.6.4 The practical consequences (what a developer must know)

| Situation | Behaviour | Why |
|---|---|---|
| Walking up a staircase | works | each stair static is ≤ 2 units higher than the previous surface; `stepTop >= itemTop` passes |
| Walking up a 3-unit ledge | **blocked** | `StepHeight = 2` |
| Walking off a cliff | **allowed** — you fall to the lower surface | the "closest Z" rule picks the low surface; there is no fall damage in the base algorithm |
| Walking under a bridge | allowed | `Bridge` flag zeroes `itemTop`, so the bridge is not a step target from below |
| Walking under an archway | allowed iff the archway's `CalcHeight` band does not intersect `[Z, Z+16)` |
| Standing under a low ceiling | blocked if the ceiling's `[Z, Z+CalcHeight)` overlaps `[Z, Z+16)` |
| Doors | `TileFlag.Door` items are **ignored** by `IsOk` when `ignoreDoors` is true | `Movement.cs:100-110` |
| Spell fields (fire/poison/paralyze) | ignored when `ignoreSpellFields` | `Movement.cs:112-115`; only for players **not on Felucca** (`Movement.cs:174`) |
| Hidden containers | ignored (`TileFlag.Container` + `!item.Visible`) — EA behaviour | `Movement.cs:118-121` |
| Extra door IDs treated as doors | `0x692, 0x846, 0x873, 0x6F5–0x6F6` | `Movement.cs:100` |
| Spell-field IDs | `0x82, 0x3946, 0x3956` | `Movement.cs:112` |
| Stygian Dragon "hover over" flying | uses `TileFlag.HoverOver` / tile name `"hover over"` | `Movement.cs:184-187` |

`ignoreDoors` is true when: `AlwaysIgnoreDoors` global, or the mover is not a `Mobile`, or is dead,
or is body `0x3DB` (a boat), or is a dead bonded pet (**SC**: `Movement.cs:173`). For a real living
player, doors **are** checked, and a `BaseHouseDoor` the player has no access to blocks
(`Movement.cs:102-105`).

### 1.6.5 Diagonal movement

```csharp
bool checkDiagonals = ((int)d & 0x1) == 0x1;
...
if (moveIsOk && checkDiagonals)
{
    if (m != null && m.Player && m.AccessLevel < AccessLevel.GameMaster)
    {
        if (!Check(... xLeft, yLeft ...) || !Check(... xRight, yRight ...))
            moveIsOk = false;     // BOTH orthogonal neighbours must be walkable
    }
    else
    {
        if (!Check(... xLeft ...) && !Check(... xRight ...))
            moveIsOk = false;     // only ONE needs to be walkable
    }
}
```

**SC**: `servuo/Scripts/Services/Pathing/Movement.cs:546-560`. So **players cannot squeeze through a
diagonal gap; NPCs and GMs can.** This is a load-bearing detail: it is why players bump on corners
that monsters slide around.

The offset helpers used (`xLeft = d − 1 mod 8`, `xRight = d + 1 mod 8`) are at `Movement.cs:382-384`.

## 1.7 "Cannot move through" rules and pushing

| Rule | Value / source |
|---|---|
| Two mobiles overlap-block iff `(mobA.Z + 15) > mobB.Z && (mobB.Z + 15) > mobA.Z` | **SC**: `Movement.cs:352`; also `servuo/Server/Mobile.cs:3195,3216,3239,3243` |
| Net effect | the vertical "personal space" around a mobile is **±15 world units**, one unit less than `PersonHeight` |
| You may **not** be blocked by a dead mobile, a dead bonded pet, or by your own self | **SC**: `Movement.cs:361-364` (`CanMoveOver`), `:363` |
| Hidden staff are not blocking | **SC**: `Movement.cs:363` |
| `IgnoreMovableImpassables` setting | skips `Movable` items with `ImpassableSurface`, i.e. lets players walk through *movable* blockers | **SC**: `Movement.cs:441,487,505,519` |
| Shoving requires full stamina and costs 10 stamina | **SC**: `Mobile.cs:3541-3544` |
| Shoving is disabled entirely on `FreeMovement` maps (Trammel) | **SC**: `Mobile.cs:3518` |
| `OnMoveOver` / `OnMoveOff` veto hooks | **SC**: `Mobile.cs:3195,3206,3216,3227` — items and mobiles may refuse entry/exit |
| Region veto (`Region.CanMove`) after the zone check | **SC**: `Mobile.cs:3266` |

## 1.8 Movement while hidden / stealth

| Parameter | Pre-AoS | AoS+ | Source |
|---|---|---|---|
| Steps allowed while stealthed | `floor(Stealth / 10)`, min 1 | `floor(Stealth / 5)`, min 1 | **SC**: `servuo/Scripts/Skills/Stealth.cs:106-109` |
| Armour rating at which stealth is impossible | **26** | **42** | **SC**: `Stealth.cs:98` |
| Hiding skill required to begin stealth | **80.0** | **50.0** (SE) / **30.0** (ML+) | **SC**: `Stealth.cs:24-30` |
| Stealth check range | `[-20 + AR*2, (AoS ? 60 : 80) + AR*2]` | — | **SC**: `Stealth.cs:104` |
| Stealth skill cooldown | **10 s** | — | **SC**: `Stealth.cs:118,128` |
| Reveal triggers | running a step, mounting, or exhausting steps | **SC**: `servuo/Server/Mobile.cs:3044-3050` |
| `AllowedStealthSteps` decrements per step | yes | **SC**: `Mobile.cs:3046` |

The exact reveal rule (`servuo/Server/Mobile.cs:3042-3053`):

```csharp
protected virtual bool OnMove(Direction d)
{
    if (m_Hidden && m_AccessLevel == AccessLevel.Player)
    {
        if (m_AllowedStealthSteps-- <= 0 || (d & Direction.Running) != 0 || Mounted)
            RevealingAction();
    }
    return true;
}
```

So: **hidden + walk = stays hidden indefinitely in the base rule**, but the stealth *step budget*
decrements on every step and reveals you when it hits zero. Note the counter decrements even when
you are merely hidden (not stealthed), which in practice means a hidden character who never used
the Stealth skill is revealed after `AllowedStealthSteps` steps (which starts at 0 → reveals on the
first step). This is a known emulator behaviour; **UNCERTAIN** whether it matches EA exactly.

## 1.9 Doors, teleporters, stairs, and sea/boat movement

### 1.9.1 Doors

- A door is a `TileFlag.Door` item. Toggling it changes the item ID between closed and open
  graphics, which changes `ItemData.CalcHeight` and therefore walkability.
- A door occupying a tile is ignored by the movement check only when `ignoreDoors` is set (§1.6.4);
  for players it is normally **checked**, and house doors additionally run
  `BaseHouseDoor.CheckAccess(mobile)` (**SC**: `Movement.cs:102-105`).
- **UNVERIFIED:** the exact original-client animation delay between clicking a door and the tile
  becoming passable. ClassicUO sends the use request and waits for the server's item-update packet;
  there is no client-side prediction for doors. `/ `servuo/Scripts/Items/Functional/Door.cs` (door
  open/close, lock pick, key use). Would need to be measured as "ms between double-click and the
  item-update packet arriving".
- Locked doors: a `BaseDoor` with `Locked = true` rejects use unless the mobile holds the matching
  `Key` or succeeds at Lockpicking/Magery Unlock.

### 1.9.2 Teleporters, moongates, stairs

- Teleporters are `Item`s with an `OnMoveOver` override that relocates the mobile
  (`servuo/Scripts/Items/Functional/Teleporter.cs` pattern). Movement into them is not special —
  the relocation happens in the `OnMoveOver` callback invoked from `Mobile.Move`
  (**SC**: `servuo/Server/Mobile.cs:3222-3231`).
- Moongates (`PublicMoongate`) are items with notoriety `Innocent`
  (**SC**: `servuo/Scripts/Misc/Notoriety.cs:324-327`).
- Stairs are ordinary `Surface` statics with `StairBack` / `StairRight` flags — the flags are
  *client rendering* hints (which way the stair sprite faces), not simulation state. The clone can
  ignore them for physics.

### 1.9.3 Boats and sea movement

| Parameter | Value | Source |
|---|---|---|
| Fast movement interval | **250 ms** | **SC**: `servuo/Scripts/Multis/Boats/BaseBoat.cs:872` |
| Normal movement interval | **500 ms** | **SC**: `BaseBoat.cs:875` |
| Slow movement interval | **1000 ms** | **SC**: `BaseBoat.cs:878` |
| Speed values | `SlowSpeed = 1`, `FastSpeed = 1` (new movement) or `3` (legacy) | **SC**: `BaseBoat.cs:866-867` |
| Client speed codes sent to the client | `0x2` = slow, `0x3` = drift, `0x4` = fast | **SC**: `BaseBoat.cs:3210-3241` |
| Boat decay (unused) | **13 days** | **SC**: `BaseBoat.cs:292` (`BoatDecayDelay`) |
| Emergency repair duration | 6 minutes | **SC**: `BaseBoat.cs:1166` |
| Rowboat "tick" | 5 minutes | **SC**: `BaseBoat.cs:319` |

Boat movement is **not** the mobile algorithm: a boat is a `BaseMulti` that moves its whole
multi-component list one tile per interval along a `Direction`, carrying mobiles on deck. The
`m_ClientSpeed` codes (`0x2/0x3/0x4`) are sent to the client so it can animate the hull at the
matching rate. Sea tiles are simply land tiles with the `Wet` flag; a mobile can only enter them if
`CanSwim` is set (`Movement.cs:159-162`).

## 1.10 Client prediction vs server authority

This is the part that determines whether the clone *feels* like UO. The model is:

```
CLIENT                                    SERVER
  |                                         |
  |-- 0x02 MoveRequest (dir, seq, key) ---->|
  |   client moves its sprite IMMEDIATELY   |  Movement.Movement.CheckMovement(...)
  |   and starts the 400/200 ms timer       |  + Region.CanMove + OnMoveOver hooks
  |                                         |  + fastwalk stack check
  |<-- 0x22 MovementAck (seq, notoriety) ---|  if accepted
  |<-- 0x21 MovementRej (seq) --------------|  if rejected -> client snaps back
```

Verified implementation details:

| Behaviour | Detail | Source |
|---|---|---|
| Client enforces its own step timer before sending | `Walker.LastStepRequestTime > Time.Ticks` blocks a new step | **SC-C**: `classicuo/.../GameObjects/PlayerMobile.cs:525` |
| Client keeps a step queue of unacknowledged steps | `Walker.Steps` (`Step` = x, y, z, direction) | **SC-C**: `PlayerMobile.cs:551-560` |
| Client refuses to start a run when stamina ≤ 1 | yes | **SC-C**: `PlayerMobile.cs:532` |
| Client max outstanding steps | `MAX_STEP_COUNT = 5` | **SC-C**: `classicuo/.../Game/Constants.cs:16` |
| Server detects "fast walk" | rolling queue of movement records; if `m_MoveRecords.Count >= FwdMaxSteps` an event may block the step | **SC**: `servuo/Server/Mobile.cs:3289-3312` |
| `FwdMaxSteps` | **4** | **SC**: `servuo/Server/Mobile.cs:3081` |
| `FwdAccessOverride` | `AccessLevel.Counselor` and above are exempt | **SC**: `Mobile.cs:3078` |
| Server caps queued movement time | each queued step adds `delay` to `m_EndQueue`, so a burst drains at the legal rate | **SC**: `Mobile.cs:3314-3329` |
| Server sends ack | `m_NetState.Send(MovementAck.Instantiate(m_NetState.Sequence, this))` | **SC**: `Mobile.cs:3344` |
| Ack packet is `0x22`, 3 bytes | `servuo/Server/Network/Packets.cs:4511` | |

**Clone recommendation:** implement exactly this. Client-predicts-and-server-confirms with a
snap-back on rejection is the source of UO's characteristic "rubber-band on lag" feel and cannot be
replaced by a purely server-authoritative model without changing how the game feels.

---

# 2. INTERACTION MODEL

## 2.1 Click semantics

### 2.1.1 Single left click

| Behaviour | Detail | Source |
|---|---|---|
| Wire action | client sends packet **`0x09` "ClickRequest"** (`LookReq`) carrying the target serial | **SC-C**: `classicuo/.../Game/GameActions.cs:325-336` (`Socket.Send_ClickRequest(serial)`); **SC**: `servuo/Server/Network/PacketHandlers.cs:75` (`Register(0x09, 5, true, LookReq)`) |
| Server response | the server generates the object's label and sends it as an overhead/localised message | **SC**: `servuo/Server/Network/PacketHandlers.cs:1680-1730` (`HandleSingleClick`) |
| Two modes | legacy `OnSingleClick` ("a backpack", "a sword") vs AoS `OnAosSingleClick` (the OPL tooltip) | **SC**: `PacketHandlers.cs:1695-1699` — switched by `SingleClickProps` global and the player's `ViewOPL` flag |
| Click on **yourself** | opens the context menu (AoS+). The client sends `0x09` on self, and the server's `ContextMenuRequest` path handles it | **SC**: `PacketHandlers.cs:2233-2245`; **SC-C**: `classicuo` sends `Send_ClickRequest` and the server replies with a `0xF0`/`0xBF` context-menu packet |
| Name/label tooltip delay | ClassicUO default `TooltipDelayBeforeDisplay = 250` ms | **SC-C**: `classicuo/src/ClassicUO.Client/Configuration/Profile.cs:141`, used at `Game/UI/Tooltip.cs:208,286` |
| Era | context menus were introduced with **AoS** (Feb 2003). Pre-AoS clients had no right-click menus; clicking yourself simply did nothing useful | **SC**: `servuo/Server/ExpansionInfo.cs:96,111-116` — `CharacterListFlags.ContextMenus` is set even for `ExpansionNone`, but `ExpansionInfo` only *sends* menus for AoS+ |

### 2.1.2 Double left click ("use")

| Behaviour | Detail | Source |
|---|---|---|
| Wire action | packet **`0x06` UseRequest**, 5 bytes | **SC**: `servuo/Server/Network/PacketHandlers.cs:72` (`Register(0x06, 5, true, UseReq)`) |
| Item | "use" = open (container), equip, drink, read, or the item's `OnDoubleClick` | **SC**: `servuo/Server/Items/Item.cs` `OnDoubleClick` |
| Mobile | "use" = the mobile's `OnDoubleClick` (vendors open their shop, quest NPCs open dialogue) | — |
| Combat shortcut | in **war mode**, double-clicking another mobile issues an **attack request** instead of a use | **SC-C**: `classicuo/.../GameActions.cs:299-309` |
| Client records "last object" | double-clicking a usable item/mobile sets `World.LastObject = serial`, which is what the **Use Last Object** macro replays | **SC-C**: `GameActions.cs:311-322` |
| Two-handed/equip semantics | dropping onto a mobile sends `0x13` EquipReq; the server validates `AllowEquipFrom` then `EquipItem`, else `item.Bounce(from)` | **SC**: `servuo/Server/Network/PacketHandlers.cs:1091-1119` |

### 2.1.3 Right click

| Behaviour | Detail |
|---|---|
| Context menu | AoS+. ClassicUO drives it through `TargetManager`/`PopupMenu`; the server side is `ContextMenuRequest`/`ContextMenuResponse`. |
| Closing a gump | right-click closes the gump the cursor is over. |
| Right-double-click | ClassicUO binds this to "open the container's own context menu" — **SC-C**: `GameSceneInputHandler.cs:855`. |

### 2.1.4 Click-to-walk, hold-to-walk, always-run

| Behaviour | Detail | Source |
|---|---|---|
| Walking | held **right mouse button** walks toward the cursor; the *left* button is reserved for interaction/drag | **SC-C / WIKI** |
| Auto-run toggle | the `AlwaysRun` macro | **SC-C**: `MacroType.AlwaysRun` in `classicuo/.../Managers/MacroManager.cs:2303` |
| Always-run while hidden is forced off by default | `AlwaysRunUnlessHidden` profile option | **SC-C**: `classicuo/.../GameObjects/PlayerMobile.cs:532` |
| Keyboard walking | arrow keys; the client converts 8-way key combos to directions | **SC-C**: `classicuo/.../Game/Data/Direction.cs:140-184` |

### 2.1.5 Modifier-click conventions

| Binding | Behaviour | Confidence |
|---|---|---|
| **Alt + click** | In *original* UO there is **no** Alt-click auto-open-corpse binding. Alt-click is a **Razor/UOAssist/ClassicUO** extension. In ClassicUO, `Alt` is used by the drag-select modifier and by "auto-open corpse" only when the user enables the Razor-style option. | **UNCERTAIN** — see note below |
| **Ctrl + Shift** | ClassicUO uses `Ctrl+Shift` as the drag-select modifier (bulk item selection) — **SC-C**: `GameSceneInputHandler.cs:364` (`DragSelectModifierActive()`) | **SC-C** |
| **Shift + double-click** | opens a container **inside** the currently open container rather than at the default screen position — ClassicUO behaviour | **SC-C / WIKI** |
| **Ctrl + click** on an item inside a container | moves it directly to the parent container ("quick move") — ClassicUO / Razor | **SC-C / UNCERTAIN** for original |

> ⚠ **Honest note.** The exact modifier semantics of the *original EA client* are not recoverable from
> these repos, because ClassicUO is a reimplementation whose modifier bindings are configurable
> defaults, not protocol facts. What **is** protocol-level is: which packets get sent. The clone
> should implement the *packet* semantics above and treat modifier bindings as user-configurable.

## 2.2 Drag & drop

### 2.2.1 The protocol

| Step | Packet | Payload |
|---|---|---|
| Lift (pick up) | **`0x07` LiftReq**, 7 bytes | `serial:int32`, `amount:uint16` — **SC**: `servuo/Server/Network/PacketHandlers.cs:73,1079-1089` |
| Drop | **`0x08` DropReq**, 14 bytes (15 from client 6.0.1.7) | `serial:int32` (ignored), `x:int16`, `y:int16`, `z:sbyte`, `gridloc:byte`, `destSerial:int32` — **SC**: `PacketHandlers.cs:74,1121-1166` |
| Equip from cursor | **`0x13` EquipReq** | target mobile serial — **SC**: `PacketHandlers.cs:1091-1119` |

`gridloc` is the item's position within a container **grid** (added for the SA-era "grid loot"
container view); pre-SA it is always 0.

### 2.2.2 Range limits — the number that matters most

**Lift and drop range is 2 tiles, everywhere, for players.** Staff (`AccessLevel >= GameMaster`)
are exempt.

| Operation | Limit | Source |
|---|---|---|
| Lift an item | `from.InRange(item.GetWorldLocation(), 2)` | **SC**: `servuo/Server/Mobile.cs:4500` |
| Drop onto/into an item | `from.InRange(target.GetWorldLocation(), 2)` | **SC**: `servuo/Server/Item.cs:5081` (`OnDroppedOnto`), `:5117` (`DropToItem`) |
| Drop onto a mobile | `from.InRange(target.Location, 2)` | **SC**: `servuo/Server/Item.cs:5034` (`DropToMobile`) |
| Drop on the ground | `from.InRange(p, 2)` | **SC**: `servuo/Server/Item.cs:5171` (`DropToWorld`) |
| Also required | `CanSee` **and** `InLOS` on both ends | **SC**: `Item.cs:5038,5085,5121` |

The **client-side** limit is different and larger: ClassicUO refuses the *drag gesture* beyond
`DRAG_ITEMS_DISTANCE = 3` tiles — **SC-C**: `classicuo/src/ClassicUO.Client/Game/Constants.cs:76`,
enforced at `Game/UI/Gumps/ContainerGump.cs:271` and `NameOverheadGump.cs:382`.

**Practical rule to reproduce:** client lets you start dragging within 3 tiles; server rejects any
lift/drop beyond 2 tiles. The visible effect in real UO is that you can *begin* dragging something
slightly out of range but the lift silently fails.

### 2.2.3 Drop resolution order

`DropReq` dispatches on the destination serial (`PacketHandlers.cs:1143-1165`):

1. `dest.IsMobile` → `from.Drop(mobile, loc)` → `item.DropToMobile` → `target.OnDragDrop(from, item)`
   (vendor sell, trade window, pack animal, another player's paperdoll).
2. `dest.IsItem`:
   - if it is a `BaseMulti` with `AllowsRelativeDrop` (a boat/house), the drop coordinates are
     **offset by the multi's origin** and treated as a world drop;
   - otherwise `from.Drop(item, loc)` → `item.DropToItem` → `target.OnDragDropInto(from, item, loc)`.
3. Anything else → `from.Drop(loc)` → `item.DropToWorld(from, p)`.

A rejected drop calls `item.Bounce(from)`, which returns the item to where it came from and sends a
`0x27` bounce packet.

`DropToWorld` computes the landing Z with `FindDropPoint(p, map, from.Z + 17)` — **the maximum Z an
item may be dropped to is the thrower's Z + 17** (one more than `PersonHeight`)
(**SC**: `servuo/Server/Item.cs:5189,5225-5290`). Dropping onto a table taller than that is
impossible.

### 2.2.4 Stacking and stack limits

| Rule | Value | Source |
|---|---|---|
| Max amount in a single stack | **60000** | **SC**: `servuo/Server/Item.cs:2132` (`if (item.Amount + Amount > 60000)`) |
| Merge precondition | both items `Stackable` and `WillStack(from, item)` | **SC**: `servuo/Server/Item.cs:2107`, `Item.WillStack` |
| Merge outcome | `Amount += dropped.Amount`, dropped item deleted | **SC**: `Item.cs:2079` |
| Unstacking | lifting `amount < oldAmount` calls `LiftItemDupe(item, amount)` — a clone is created for the cursor | **SC**: `servuo/Server/Mobile.cs:4570-4577` |
| Quest items cannot be unstacked | `LRReason` + cliloc `1074868` | **SC**: `Mobile.cs:4512-4516` |
| `Stackable` is an `ImplFlag` bit (`0x00008000` serialised), not a tile flag | — | **SC**: `servuo/Server/Item.cs:894,2208,2585` |

### 2.2.5 Container fill rules

`Container.CheckHold` (`servuo/Server/Items/Container.cs:230-291`):

1. `IsDecoContainer` (immovable, not locked down, not secure, no parent) → always refuses.
2. **Item count:** `TotalItems + plusItems + item.TotalItems + (item.IsVirtualItem ? 0 : 1) > MaxItems` → refuse.
   (Note: `item.TotalItems` means nested contents count against the *outer* container too.)
3. **Weight:** `TotalWeight + plusWeight + item.TotalWeight + item.PileWeight > MaxWeight`, and only
   if `MaxWeight != 0` (0 = unlimited).
4. Then the check **recurses up the parent chain**, so a bag inside a backpack inside... all must accept.

`PileWeight` is `ceil(Weight * Amount)` (`servuo/Server/Item.cs:3854`).

**Backpack is special:** a player's backpack is created with item ID `0xE75`, weight 3.0, layer
`Backpack` (0x15); its max weight is 550 in ML+, else the global 400
(**SC**: `servuo/Scripts/Items/Containers/Container.cs:436-472`).

Items inside a container are auto-positioned inside the container's `Bounds` rectangle when the
server has no client-supplied position (`Container.DropItem`, `Container.cs:1845-1875`): if the item
is wider than the container it is centred, otherwise placed at a random offset.

## 2.3 Target cursor

### 2.3.1 The protocol

`0x6C` TargetCursor, 19 bytes (**SC**: `servuo/Server/Network/Packets.cs:2784-2808`):

| Offset | Size | Field |
|---|---|---|
| 0 | 1 | **allowGround** (bool) — 1 = the player may target a map location, 0 = must target an object |
| 1 | 4 | **targetID** (int32) — an opaque counter; the client echoes it back |
| 5 | 1 | **flags** (byte) |
| 6 | 13 | zero fill |

`CancelTarget` is the same packet with `allowGround = 0`, `targetID = 0`, `flags = 3`.

**Flag values** — ServUO's own enum is minimal (**SC**: `servuo/Server/Targeting/TargetFlags.cs:3-8`):

| Value | Name |
|---|---|
| 0x00 | `None` |
| 0x01 | `Harmful` |
| 0x02 | `Beneficial` |

The client interprets them for the "criminal action query" prompt
(**SC-C**: `classicuo/.../Managers/TargetManager.cs:274-278`): with `Harmful`, targeting an
`Innocent` may prompt "this will flag you a criminal"; with `Beneficial`, targeting a
`Criminal`/`Murderer`/`Gray` may prompt too. Both prompts are configurable and off by default.

### 2.3.2 Cursor types

ClassicUO's internal target-state machine (**SC-C**: `classicuo/.../Managers/TargetManager.cs:16-41`):

| `CursorTarget` | Value | Meaning |
|---|---|---|
| `Invalid` | −1 | no cursor |
| `Object` | 0 | server-requested object target |
| `Position` | 1 | server-requested ground target |
| `MultiPlacement` | 2 | placing a house/boat multi |
| `SetTargetClientSide` | 3 | purely client-side target (e.g. "select a bag") |
| `Grab`, `SetGrabBag`, `HueCommandTarget`, `IgnorePlayerTarget`, `CallbackTarget` | — | client-only variants |

| `TargetType` | Value | Used for |
|---|---|---|
| `Neutral` | 0 | normal cursor |
| `Harmful` | 1 | "attack" cursor |
| `Beneficial` | 2 | "heal/buff" cursor |
| `Cancel` | 3 | cursor is cancelled |

Target cursor graphic ID: **`6983686`** (`CursorType.Target`, **SC-C**: `TargetManager.cs:30-33`).

### 2.3.3 Target timeout

| Delay | Timer priority |
|---|---|
| ≥ 30 s | `FiveSeconds` |
| ≥ 10 s | `OneSecond` |
| ≥ 1 s | `TwoFiftyMS` |
| < 1 s | `TwentyFiveMS` |

**SC**: `servuo/Server/Targeting/Target.cs:88-119`. The classic "target cursor times out" behaviour
is a server-side timer that sends `CancelTarget` and calls `OnTargetCancel(from, Timeout)`.

### 2.3.4 Range checks

`Target.CheckTarget` (**SC**: `servuo/Server/Targeting/Target.cs:240-252`):

```csharp
if (map == null || map != from.Map || (m_Range != -1 && !from.InRange(loc, m_Range)))
    OnTargetOutOfRange(from, targeted);
else if (...) ...
else if (m_CheckLOS && !from.InLOS(targeted))
    OnTargetOutOfLOS(from, targeted);
```

`m_Range == -1` means unlimited range (used by e.g. the insurance toggle). `CheckLOS` defaults to
`true` (`Target.cs:32`).

## 2.4 Context menus

| Parameter | Value | Source |
|---|---|---|
| Request packet | `0xBF` subcommand **`0x13`** (`ContextMenuRequest`) | **SC**: `servuo/Server/Network/PacketHandlers.cs:150` |
| Response packet | `0xBF` subcommand **`0x15`** (`ContextMenuResponse`) | **SC**: `PacketHandlers.cs:151` |
| Server dispatch | `ContextMenu.Display(mobile, target)` | **SC**: `PacketHandlers.cs:2233-2245` |
| Context menu also triggers single-click labelling on the target | yes — `ContextMenuRequest` calls `HandleSingleClick` first | **SC**: `PacketHandlers.cs:2238-2242` |
| Range gate | `Utility.InUpdateRange(m, target)` — a **square (Chebyshev) range check**: `|dx| <= R && |dy| <= R`, where `R` is the **player's own negotiated `NetState.UpdateRange`**, which defaults to `Core.GlobalUpdateRange` = **18** and may be raised by the client up to `Core.GlobalMaxUpdateRange` = **24** | **SC**: `servuo/Server/ContextMenus/ContextMenu.cs:126-131`; `servuo/Server/Utility.cs:701-728`; `servuo/Server/Main.cs:652-654`; client negotiation at `PacketHandlers.cs:1758-1767` |
| Client index for custom entries | **must be ≥ `0x64`** | **SC**: `ContextMenu.cs:170,261` |

Built-in entry numbers (`servuo/Server/ContextMenus/ContextMenu.cs:178-256`) — these are the numbers
the client knows natively:

| Number | Meaning |
|---|---|
| `0x0078` | Open Backpack (self) |
| `0x0193` | Paperdoll (self) |
| `0x01A3` | ? |
| `0x032A` / `0x032B` | ? |
| `0x012D` | ? |
| `0x082`–`0x087` | item-storage / house-related entries |
| `0x089` | ? |
| `0x0140` | ? |
| `0x025A` / `0x025C` | ? |
| `0x0196`, `0x0194`, `0x0195` | ? |
| `0x0321`, `0x01A0`, `0x01A2` | ? |
| `0x0396`, `0x0393` | ? |
| `0x0134` | ? |
| `0x03F2`, `0x03F5`, `0x03F6` | ? |
| `0x0334` | ? |

> The names of most of these are **UNVERIFIED** from the emulator source (they are client-side
> strings). What matters for the clone: **entry numbers 0x64 and above are free for custom entries**,
> which is how every UO expansion added its own menu items. `ContextMenuEntry` also takes a name
> cliloc and a `Range` (**SC**: `servuo/Server/ContextMenus/ContextMenuEntry.cs:30-93`).

Classic entries that must exist for the clone to feel right: **Open Backpack**, **Paperdoll**,
**Open Bank** (bankers), **Buy/Sell** (vendors), **Talk** (quest NPCs), **Open** (containers),
**Lock Down / Release / Secure** (house items), **Add Friend / Remove Friend**.

## 2.5 Container gumps

| Parameter | Value | Source |
|---|---|---|
| Default container gump ID | **`0x3C`** | **SC**: `servuo/Server/Items/Container.cs:2085` (`m_Default = new ContainerData(0x3C, new Rectangle2D(44, 65, 142, 94), 0x48)`) |
| Default drop sound | **`0x48`** | same line |
| Default inner bounds | rectangle `(44, 65, 142, 94)` | same line |
| Per-item-ID gump data | loaded from `containers` (client data file); ServUO reads a `ContainerData` table keyed by item ID | **SC**: `Container.cs:2125-2160` |
| Backpack item ID / gump | `0xE75`, container gump `0x3C` | **SC**: `servuo/Scripts/Items/Containers/Container.cs:440` |
| Bank box item ID | `0xE7C`, layer `Bank` (0x1D) | **SC**: `servuo/Server/Items/Containers.cs:29-34` |
| Container "grid" positions | `gridloc` byte in `DropReq` / `GridLocation` property | **SC**: `servuo/Server/Network/PacketHandlers.cs:1127,1139` |
| Client container scaling | `Profile.ContainersScale / 100f` | **SC-C**: `classicuo/.../GameScenes/GameScene.cs:128` |

Pre-SA, containers had **no grid view** — items sat at arbitrary pixel offsets inside the gump and
that was the entire spatial model. The clone should support free-position items as the default and
treat grid view as an optional AoS/SA-era UI.

## 2.6 Paperdoll and the equipped-item layer list

The single source of truth is `servuo/Server/Item.cs:25-197` (**SC**), cross-checked against
`classicuo/src/ClassicUO.Client/Game/Data/Layers.cs` (**SC-C**).

| # | ServUO name | ClassicUO name | Notes |
|---|---|---|---|
| 0x00 | `Invalid` | `Invalid` | |
| 0x01 | `OneHanded` | `OneHanded` | weapon / spellbook in hand |
| 0x02 | `TwoHanded` | `TwoHanded` | two-handed weapon **or shield** |
| 0x03 | `Shoes` | `Shoes` | |
| 0x04 | `Pants` | `Pants` | inner legs, pre-AoS naming |
| 0x05 | `Shirt` | `Shirt` | |
| 0x06 | `Helm` | `Helmet` | |
| 0x07 | `Gloves` | `Gloves` | |
| 0x08 | `Ring` | `Ring` | |
| 0x09 | `Talisman` | `Talisman` | **added in ML** (2005) |
| 0x0A | `Neck` | `Necklace` | gorget / necklace |
| 0x0B | `Hair` | `Hair` | |
| 0x0C | `Waist` | `Waist` | half apron |
| 0x0D | `InnerTorso` | `Torso` | |
| 0x0E | `Bracelet` | `Bracelet` | |
| 0x0F | `Face` | `Face` | |
| 0x10 | `FacialHair` | `Beard` | |
| 0x11 | `MiddleTorso` | `Tunic` | |
| 0x12 | `Earrings` | `Earrings` | |
| 0x13 | `Arms` | `Arms` | |
| 0x14 | `Cloak` | `Cloak` | |
| 0x15 | `Backpack` | `Backpack` | |
| 0x16 | `OuterTorso` | `Robe` | |
| 0x17 | `OuterLegs` | `Skirt` | |
| 0x18 | `InnerLegs` | `Legs` | `Layer.LastUserValid` — last layer a player may equip to |
| 0x19 | `Mount` | `Mount` | |
| 0x1A | `ShopBuy` | `ShopBuyRestock` | vendor buy pack |
| 0x1B | `ShopResale` | `ShopBuy` | vendor resale pack |
| 0x1C | `ShopSell` | `ShopSell` | vendor sell pack |
| 0x1D | `Bank` | `Bank` | bank box |
| 0x1E | `Reserved_1` | — | ServUO comment: *"Unused, using this layer makes you invisible to other players. Strange."* |
| 0x1F | `SecureTrade` | — | the trade window |

> ⚠ **Naming conflict at 0x1A/0x1B.** ServUO calls 0x1A `ShopBuy` and 0x1B `ShopResale`; ClassicUO
> calls 0x1A `ShopBuyRestock` and 0x1B `ShopBuy`. The **wire values are correct and identical**; only
> the names differ. Use the numbers.

`Layer.FirstValid = 0x01`, `Layer.LastUserValid = 0x18`
(**SC**: `servuo/Server/Item.cs:35,160`).

**Death shroud:** on death a player gets an immovable item `0x204E` on layer `OuterTorso` (0x16)
(**SC**: `servuo/Server/Mobile.cs:4243-4251`).

## 2.7 Status bar / status gump

The status gump is populated from the **`0x11` MobileStatus** packet. ServUO writes, in order
(**SC**: `servuo/Server/Network/Packets.cs:3600-3760`):

| Order | Field |
|---|---|
| 1 | serial |
| 2 | name |
| 3 | current hits |
| 4 | max hits |
| 5 | name change flag |
| 6 | **`m.StatCap`** |
| 7–9 | gender, STR, DEX |
| 10–11 | INT, current stamina |
| 12–13 | max stamina, current mana |
| 14–15 | max mana, **gold** |
| 16–17 | **armor rating**, **weight** |
| 18–22 | (AoS+) damage min/max, tithing points, resistances ×5 |
| 23+ | (AoS+) stat caps for Str/Dex/Int (125 each), status flags |

The status **request** is packet `0x34` (`StatusRequest`), sent by the client whenever the gump opens
or refreshes. Fields shown by ClassicUO's `StatusGump`
(**SC-C**: `classicuo/.../Game/UI/Gumps/StatusGump.cs:452,513,764-775`): name, hit/stam/mana bars and
values, STR/DEX/INT, weight, gold, armour, tithing points, resistances, stat and skill caps,
followers, luck — the exact set is era-gated by which fields the server sends.

## 2.8 Vendor buy/sell gumps

| Aspect | Detail | Source |
|---|---|---|
| Trigger | double-click a vendor → use request → server sends the buy list or sell list |
| **Buy list packet (server → client)** | **`0x74` `VendorBuyList`** | **SC**: `servuo/Server/Network/Packets.cs:377-380` (`: base(0x74)`) |
| Buy **content** packet(s) | **`0x3C`** `VendorBuyContent` (and a 6.0.1.7 variant `VendorBuyContent6017`) | **SC**: `Packets.cs:297,326` |
| **Buy reply packet (client → server)** | **`0x3B` `VendorBuyReply`**, variable length | **SC**: `servuo/Server/Network/PacketHandlers.cs:84` (`Register(0x3B, 0, true, VendorBuyReply)`), handler at `:440` |
| **Sell list packet (server → client)** | **`0x9E` `VendorSellList`** | **SC**: `Packets.cs:408-411` (`: base(0x9E)`) |
| **Sell reply packet (client → server)** | **`0x9F` `VendorSellReply`**, variable length | **SC**: `PacketHandlers.cs:107` (`Register(0x9F, 0, true, VendorSellReply)`), handler at `:493` |
| Termination packets | `EndVendorBuy` / `EndVendorSell` sent when the transaction finishes | **SC**: `PacketHandlers.cs:454,504` |
| Buy list contents | item name, graphic, hue, **price**, and (AoS+) the current quantity in stock | **SC**: `servuo/Scripts/Mobiles/NPCs/BaseVendor.cs:1014,1670` |
| Sell list contents | `SellItemState(item, ssi.GetSellPriceFor(item, this), ssi.GetNameFor(item))` | **SC**: `BaseVendor.cs:1156` |
| Sell proceeds | `Banker.Deposit(from, gold, true)` — **sell proceeds go to the bank box, not the backpack** | **SC**: `BaseVendor.cs:1263,1274` |
| Fame award on selling | `Titles.AwardFame(from, sellPrice * amount, true)` | **SC**: `BaseVendor.cs:1342` |
| Haggling | **There is no haggling mechanic anywhere in RunUO/ServUO/ModernUO.** Price is `base × scalar`, period | **SC** (absence) |

Full price model in §5.3.

## 2.9 Crafting / skill gumps

The crafting UI is a three-level tree driven by server-side gumps
(**SC**: `servuo/Scripts/Services/Craft/Core/CraftGump.cs`, `CraftGumpItem.cs`).

| Level | Gump | Contents |
|---|---|---|
| 1 | `CraftGump` | list of **categories/groups** for the craft system, plus a shortcut list of the **last ten items made** (`lastTen`), plus a **Repair** button if `craftSystem.Repair` is true | 
| 2 | `CraftGumpItem` | one recipe: resource requirements and quantities, the success chance, the required skill, a **"make number"** button, and a **"make max"/"make all"** button |
| 3 | `MakeNumberCraftPrompt` | a text prompt asking how many to make | **SC**: `AutoCraft.cs:9-128` |

Key button IDs verified: `case 5: // Repair item` (`CraftGump.cs:698-701`), and
`m_From.Prompt = new MakeNumberCraftPrompt(...)` (`CraftGumpItem.cs:332`).

Craft systems and their era entry points (**SC**):

| System | File | Repair option since |
|---|---|---|
| Blacksmithy | `DefBlacksmithy.cs` | always (`Repair = true`, :965) |
| Carpentry | `DefCarpentry.cs` | AoS (:979) |
| Tailoring | `DefTailoring.cs` | AoS (:840) |
| Tinkering | `DefTinkering.cs` | always (:799) |
| Bowcraft/Fletching | `DefBowFletching.cs` | AoS (:259) |
| Glassblowing | `DefGlassblowing.cs` | SA (:158) |
| Masonry | `DefMasonry.cs` | SA (:328) |

Crafting into a full pack is refused: `if (ourPack.TotalItems >= ourPack.MaxItems || ourPack.TotalWeight >= ourPack.MaxWeight)`
(**SC**: `CraftItem.cs:894`).

## 2.10 Backpack / bank / sub-container nesting and reach limits

| Rule | Value | Source |
|---|---|---|
| Nesting depth | **unlimited** — but every container in the chain must pass `CheckHold` | **SC**: `servuo/Server/Items/Container.cs:272-290` |
| Reach limit for *any* interaction | **2 tiles** from the mobile to the item's **world** location | **SC**: `servuo/Server/Mobile.cs:4500`, `Item.cs:5081,5117,5171` |
| Access check | `item.IsAccessibleTo(from)` — walks the parent chain (`Item.cs:5089,5125`, `Mobile.cs:4517`) | **SC** |
| LOS check | `from.CanSee(item) && from.InLOS(item)` | **SC**: `Mobile.cs:4504` |
| Deco container | immovable, not locked down, not secure, no parent → **nothing can be placed in it or used from it** | **SC**: `servuo/Server/Items/Container.cs:181,198-218,232-242` |
| Bank box | virtual item, `MaxWeight = 0` (unlimited), opened via banker NPC or the `OpenBank` path; **closes automatically** when the mobile moves or dies | **SC**: `servuo/Server/Items/Containers.cs:20-35`; `Mobile.cs:3110-3115` (movement), `:3662-3667` (resurrect), `:4000-4005` (death) |
| Bank box cannot be emptied on death | contents are never moved to the corpse | **SC**: `Mobile.cs:4067` (`if (item == pack) continue;` — only the backpack is processed) |

## 2.11 Item flags: blessed / newbie / cursed / insured

`LootType` enum (**SC**: `servuo/Server/Item.cs:536-557`):

| Value | Name | Stealable? | Lootable? |
|---|---|---|---|
| 0 | `Regular` | yes | yes |
| 1 | `Newbied` | **no** | **no, unless the corpse's owner is a murderer** |
| 2 | `Blessed` | no | **never** |
| 3 | `Cursed` | yes | **always** (even if the wearer is innocent) |

Gating code: `servuo/Server/Item.cs:1729,1757`
(`else if (CheckNewbied() && parent.Kills < 5)`) — this is exactly the "newbied items become
lootable from a murderer's corpse" rule.

| Flag | Behaviour | Source |
|---|---|---|
| `Insured` | an `ImplFlag` bit `0x20`; when `InsuranceEnabled` an insured item returns to the backpack on death | **SC**: `Item.cs:6076-6081`, `:896`; `Mobile.InsuranceEnabled = Core.AOS && !Siege` (`servuo/Scripts/Misc/CurrentExpansion.cs:29`) |
| `BlessedFor` (a specific mobile) | item is effectively blessed for that one character | **SC**: `Item.cs:6088-6128`, `:1655` |
| `CheckBlessed()` | `LootType == Blessed || (Mobile.InsuranceEnabled && Insured)` | **SC**: `Item.cs:6123` |
| `CheckNewbied()` | `LootType == Newbied` | **SC**: `Item.cs:6131-6133` |
| `DisplayLootType` property list entries | "blessed" / "cursed" / "insured" appended to the tooltip | **SC**: `Item.cs:1262-1275` |

**Death transfer logic** (`Mobile.OnDeath`, **SC**: `servuo/Server/Mobile.cs:4063-4126`):

```
for each item directly on the mobile (not the backpack):
    if (item.Insured || item.LootType == Blessed) && item.Layer != Mount:  equip.Add(item)   // stays
    switch GetParentMoveResultFor(item):
        MoveToCorpse   -> content.Add(item); equip.Add(item)   // goes to corpse
        MoveToBackpack -> moveToPack.Add(item)                 // stays on the ghost
for each item in the backpack:
    GetInventoryMoveResultFor(item)  -> corpse or backpack
```

`PlayerMobile.GetParentMoveResultFor` returns `MoveToBackpack` when insurance was paid, and
`Young` status forces **everything movable** into the backpack (**SC**: `PlayerMobile.cs:3857-3884`).
`PlayerMobile.RetainPackLocsOnDeath` is `Core.AOS` (**SC**: `servuo/Server/Mobile.cs:3973`), so in
AoS+ the ghost's backpack keeps items at their original pixel positions.

**Mount is never kept as equipped on death** (`item.Layer != Layer.Mount` guard, `Mobile.cs:4072`).

## 2.12 Item decay on the ground

| Parameter | Value | Source |
|---|---|---|
| Default ground decay time | **60 minutes** | **SC**: `servuo/Server/Item.cs:2017` (`TimeSpan.FromMinutes(Config.Get("General.DefaultItemDecayTime", 60))`) |
| Per-item multiplier | `DecayMultiplier` virtual property, default 1 | **SC**: `Item.cs:2022-2028` |
| Conditions for decay | `DefaultDecaySetting && Movable && Visible && !HonestyItem` | **SC**: `Item.cs:2031-2036` |
| Decay requires the item to be on the map (not in a container) | `Parent == null && Map != Map.Internal` | **SC**: `Item.cs:2049-2051` |
| Timer tick | items are checked once per minute (`TickDuration = TimeSpan.FromMinutes(1)`) | **SC**: `servuo/Server/Mobile.cs:6342` (and the item timer registered in `Item.cs`) |
| `LastMoved` | updated on every successful lift/drop; the decay clock resets | **SC**: `Item.cs:2036-2045`, `SetLastMoved()` |

| Corpse decay | Value | Source |
|---|---|---|
| Default corpse decay | **7 minutes** | **SC**: `servuo/Scripts/Items/Corpses/Corpse.cs:421` (`m_DefaultDecayTime = TimeSpan.FromMinutes(7.0)`) |
| Bone decay (after looting) | **7 minutes** | **SC**: `Corpse.cs:422` (`m_BoneDecayTime`) |
| Loot rights window | **2 minutes** | **SC**: `Corpse.cs:118` (`MonsterLootRightSacrifice = TimeSpan.FromMinutes(2.0)`) |
| Instanced corpse lifetime | 3 minutes | **SC**: `Corpse.cs:120` |

## 2.13 Houses, secures, keys and locks — basics

| Concept | Detail | Source |
|---|---|---|
| `SecureLevel` | `Owner`, `CoOwners`, `Friends`, `Anyone`, `Guild` — **in that order** | **SC**: `servuo/Scripts/Multis/BaseHouse.cs:4361-4368` |
| Secure container | a container "locked down + secured" inside a house; only the `SecureLevel` can open it | **SC**: `BaseHouse.cs:2499-2515,2720` |
| Lock down | makes an item immovable (`Movable = false`) at its spot; contributes to the house's lockdown count | **SC**: `BaseHouse.cs` (`LockDown`/`Release`) |
| House door | a `BaseHouseDoor`; movement into it checks `CheckAccess(mobile)` | **SC**: `servuo/Scripts/Services/Pathing/Movement.cs:102-105` |
| Keys | a `Key` item carries a `KeyValue`; a door's `KeyValue` must match to unlock | **SC**: `servuo/Scripts/Items/Functional/Key.cs`, `BaseDoor.cs` |
| House placement | `HousePlacementEntry` table gives size, price and lockdown/max-secure counts per house type | **SC**: `servuo/Scripts/Multis/HousePlacementTool.cs:360-527` |
| Example entry | `SmallOldHouse, 425×212 → 489×244, 10 lockdowns, 35 000 gp` | **SC**: `HousePlacementTool.cs:360` |
| Example entry | `Castle, 4076×2038 → 4688×2344, 78 lockdowns, 865 000 gp` | **SC**: `HousePlacementTool.cs:376` |
| Vendor rental durations | 7 / 14 / 21 / 28 days | **SC**: `servuo/Scripts/Mobiles/NPCs/RentedVendor.cs:17-20` |

## 2.14 Keyboard and macro conventions

The authoritative list of *what a UO macro can do* is ClassicUO's `MacroType` enum
(**SC-C**: `classicuo/src/ClassicUO.Client/Game/Managers/MacroManager.cs:2270-2352`). Reproduced in
full because it is effectively the interaction spec:

```
None, Say, Emote, Whisper, Yell, Walk, WarPeace, Paste, Open, Close, Minimize, Maximize,
OpenDoor, UseSkill, LastSkill, CastSpell, LastSpell, LastObject, Bow, Salute, QuitGame,
AllNames, LastTarget, TargetSelf, ArmDisarm, WaitForTarget, TargetNext, AttackLast, Delay,
CircleTrans, CloseGump, AlwaysRun, SaveDesktop, KillGumpOpen, PrimaryAbility, SecondaryAbility,
EquipLastWeapon, SetUpdateRange, ModifyUpdateRange, IncreaseUpdateRange, DecreaseUpdateRange,
MaxUpdateRange, MinUpdateRange, DefaultUpdateRange, EnableRangeColor, DisableRangeColor,
ToggleRangeColor, InvokeVirtue, SelectNext, SelectPrevious, SelectNearest,
AttackSelectedTarget, UseSelectedTarget, CurrentTarget, TargetSystemOnOff, ToggleBuffIconGump,
BandageSelf, BandageTarget, ToggleGargoyleFly, Zoom, ToggleChatVisibility, INVALID,
Aura=62, AuraOnOff, Grab, SetGrabBag, NamesOnOff, UseItemInHand, UsePotion,
CloseAllHealthBars, RazorMacro, ToggleDrawRoofs, ToggleTreeStumps, ToggleVegetation,
ToggleCaveTiles, CloseInactiveHealthBars, CloseCorpses, UseObject, LookAtMouse,
UseCounterBarSlot
```

The **canonical default bindings** that the clone must ship (these are the ones referenced in the
brief). Where the binding is *client-side only* it is marked:

| Action | Conventional default | Notes |
|---|---|---|
| F1–F12 | user-assignable macro slots | original client: 12 macro keys per "page", several pages |
| `Alt` + click | **not an original binding** — ClassicUO/Razor extension | **UNCERTAIN for original** |
| War/Peace toggle | `MacroType.WarPeace`; conventionally bound to a letter key | server-side: warmode spam guard, see below |
| Last target | `MacroType.LastTarget` — retargets `TargetManager.LastTargetInfo` | **SC-C** |
| Target next | `MacroType.TargetNext` — cycles hostile mobiles in range in a spiral | **SC-C** |
| Target self | `MacroType.TargetSelf` | **SC-C** |
| Bandage self | `MacroType.BandageSelf` — uses a bandage on yourself | **SC-C** |
| Use last object | `MacroType.LastObject` — re-sends `0x06` with `World.LastObject` | **SC-C**: `GameActions.cs:317,321` |
| Use item in hand | `MacroType.UseItemInHand` | **SC-C** |
| Always run | `MacroType.AlwaysRun` | **SC-C** |
| All names | `MacroType.AllNames` / `NamesOnOff` | **SC-C** |
| Circle of transparency | `MacroType.CircleTrans` | **SC-C** |
| Open door | `MacroType.OpenDoor` | **SC-C** |
| Close gump | `MacroType.CloseGump` | **SC-C** |
| Primary/secondary ability | `MacroType.PrimaryAbility`, `SecondaryAbility` | **SC-C** |
| Invoke virtue | `MacroType.InvokeVirtue` | **SC-C** |

**Warmode spam guard (server-side — the clone must reproduce this or warmode flickering is
exploitable)** (**SC**: `servuo/Server/Mobile.cs:830-831`):

| Era | Catch window | Delay after toggling |
|---|---|---|
| SE+ | **1.0 s** | **4.0 s** |
| Pre-SE | **0.5 s** | **2.0 s** |

---

# 3. CHARACTER MODEL

## 3.1 Stats: STR / DEX / INT

### 3.1.1 Derived maxima

| Derived value | Formula | Source |
|---|---|---|
| `HitsMax` | **`50 + (STR / 2)`** (integer division) | **SC**: `servuo/Server/Mobile.cs:8557` (`public virtual int HitsMax { get { return 50 + (Str / 2); } }`); identical in ModernUO `modernuo/Projects/Server/Mobiles/Mobile.cs` |
| `StamMax` | **`DEX`** | **SC**: `servuo/Server/Mobile.cs:8621`; ModernUO `Mobile.cs:2114` |
| `ManaMax` | **`INT`** | **SC**: `servuo/Server/Mobile.cs:8691` |
| `RawStatTotal` | `RawStr + RawDex + RawInt` | **SC**: `Mobile.cs:12801` |
| `StatTotal` | `Str + Dex + Int` (with modifiers) | **SC**: `Mobile.cs:12804` |

So a 100/100/25 character has 100 HP, 100 stamina, 25 mana. There is **no** hidden multiplier —
this formula is identical in every era and both emulators.

### 3.1.2 Caps

| Cap | Default | Config key | Source |
|---|---|---|---|
| Total stat cap | **225** | `PlayerCaps.TotalStatCap` | **SC**: `servuo/Server/Mobile.cs:11128` (`m_StatCap = Config.Get("PlayerCaps.TotalStatCap", 225)`); ModernUO `Mobile.cs:7826` (`m_StatCap = 225`) |
| Individual stat cap (per stat) | **125** | `PlayerCaps.StrCap` / `DexCap` / `IntCap` | **SC**: `Mobile.cs:11129-11131` |
| Absolute individual maximum (scrolls can't exceed) | **150** | `PlayerCaps.StrMaxCap` / `DexMaxCap` / `IntMaxCap` | **SC**: `Mobile.cs:11132-11134` |
| Stat cap with +25 stat scrolls | 250 | — | **SC**: `servuo/Scripts/Items/Consumables/StatScroll.cs` |
| Test-centre stat cap | 250 | — | **SC**: `servuo/Scripts/Services/TestCenter.cs:201` |

**Stat scrolls** (`StatCapScroll`): named by bonus, +5 … +25 (**SC**:
`servuo/Scripts/Items/Consumables/StatScroll.cs:36-71`). `CanUse` refuses if
`from.StatCap >= value` (**SC**: `StatScroll.cs:96-100`). Veteran rewards add a further +5 each for
`HasStatReward` and `HasValiantStatReward` (**SC**: `StatScroll.cs:90-94,114-122`).

> ⚠ **Individual stat cap era note.** 100 was the individual cap in pre-AoS; AoS raised the
> individual cap to 125 only via **stat scrolls** from champion spawns, and the AoS-era hard maximum
> became 125. ServUO's defaults encode the *post-AoS/ML* reality (125 base cap, 150 absolute).
> For a **T2A/Renaissance** target, set `StrCap = DexCap = IntCap = 100` and
> `StrMaxCap = DexMaxCap = IntMaxCap = 100`, `TotalStatCap = 225` (Renaissance raised the total
> from 200 to 225). Confidence on the pre-AoS individual cap of 100: **WIKI** (widely documented);
> the pre-AoS cap is **not** encoded in ServUO because ServUO targets modern eras.

### 3.1.3 Stat gain, individual stat locks

There are **two distinct stat-gain algorithms**, gated on `Core.ML`
(**SC**: `servuo/Scripts/Misc/SkillCheck.cs:460-481`):

**A. Pre-ML ("old gain mechanic")** — a gain roll happens on every successful skill check, for each
stat whose lock is `Up`, using the skill's per-stat gain weight:

```csharp
if (from.StrLock == StatLockType.Up && (info.StrGain / 33.3) * scalar > Utility.RandomDouble())
    GainStat(from, Stat.Str);
else if (from.DexLock == StatLockType.Up && (info.DexGain / 33.3) * scalar > Utility.RandomDouble())
    GainStat(from, Stat.Dex);
else if (from.IntLock == StatLockType.Up && (info.IntGain / 33.3) * scalar > Utility.RandomDouble())
    GainStat(from, Stat.Int);
```

`info.StrGain` / `DexGain` / `IntGain` are per-skill constants in `SkillInfo.Table`
(`servuo/Server/Skills.cs`), and the divisor **33.3** converts them to a probability.

**B. ML+ ("stat gain system")** — `SkillCheck.TryStatGain` (**SC**: `SkillCheck.cs:499-564`):

1. Roll `chance` = `_PlayerChanceToGainStats / 100.0`. Default **5 %** for players, **5 %** for pets
   (`Config` keys `PlayerCaps.PlayerChanceToGainStats`, `PlayerCaps.PetChanceToGainStats`;
   **SC**: `SkillCheck.cs:49-50`).
2. Look at the skill's `Primary` and `Secondary` stat.
3. If **both** are locked `Up`: 25 % chance to gain the secondary (`Utility.Random(4) == 0`), else the primary.
4. If only one is `Up`, gain that one.
5. If neither is `Up`, nothing.

| Stat gain timer | Value | Source |
|---|---|---|
| Player stat-gain minimum interval | **15 minutes** (config `PlayerCaps.PlayerStatTimeDelay`) | **SC**: `SkillCheck.cs:46` |
| Controlled pet stat-gain interval | **5 minutes** | **SC**: `SkillCheck.cs:47` |
| If `EnablePlayerStatTimeDelay` is false | interval becomes **0.5 s** | **SC**: `SkillCheck.cs:52-56` |

### 3.1.4 Total-cap arbitration and stat lowering

When `RawStatTotal >= StatCap` and you gain a stat, the server **lowers another stat by 1**
(**SC**: `SkillCheck.IncreaseStat`, `SkillCheck.cs:629-717`). Which stat is lowered depends on
priority rules:

- Gaining STR: lower DEX if `CanLower(DEX) && (RawDex < RawInt || !CanLower(INT))`, else lower INT.
- Gaining DEX: lower STR if `CanLower(STR) && (RawStr < RawInt || !CanLower(INT))`, else lower INT.
- Gaining INT: lower STR if `CanLower(STR) && (RawStr < RawDex || !CanLower(DEX))`, else lower DEX.

`CanLower` requires the target stat's lock to be **`Down`** and `Raw > 10`
(**SC**: `SkillCheck.cs:566-579`). **You can never go below 10 in a stat.**

`StatLockType`: `Up`, `Down`, `Locked` (`servuo/Server/Mobile.cs:1780-1822` property docs).

### 3.1.5 Starting stats by profession

From `servuo/Scripts/Misc/CharacterCreation.cs:389-420` (**SC**). Values before the +10 baseline
adjustment; a valid new character must have `str + dex + int == 80` (old client) or **`90`**
(`NewCharacterCreation` flag) (`CharacterCreation.cs:344`), with each stat in `[10, 60]`
(`:348`). Invalid input falls back to 10/10/10.

| # | Profession | STR | DEX | INT |
|---|---|---|---|---|
| 1 | Warrior | **45** | **35** | **10** |
| 2 | Magician | **25** | **20** | **45** |
| 3 | Blacksmith | **60** | **15** | **15** |
| 4 | Necromancer | **25** | **20** | **45** |
| … | (further professions follow the same table at `CharacterCreation.cs:420+`) | | | |

Starting skills: up to 4 skills, each ≤ 50, total exactly **100** (old) or **120**
(`ValidSkills`, `CharacterCreation.cs:368-387`).

Starting hunger: `newChar.Hunger = 20` (**SC**: `CharacterCreation.cs:201`).

Startup item: a **New Player Ticket placed in the bank box** (`CharacterCreation.cs:276`).

## 3.2 Skills

| Parameter | Default | Config key | Source |
|---|---|---|---|
| Total skill cap | **7000 fixed-point = 700.0** | `PlayerCaps.TotalSkillCap` | **SC**: `servuo/Server/Skills.cs:996` (`m_Cap = Config.Get("PlayerCaps.TotalSkillCap", 7000)`) |
| Individual skill cap | **1000 = 100.0** | — | **SC**: `servuo/Server/Skills.cs:874` (`new Skill(this, SkillInfo.Table[skillID], 0, 1000, SkillLock.Up)`) |
| With a 105–120 power scroll | cap becomes the scroll's value | — | **SC**: `servuo/Scripts/Items/Consumables/PowerScroll.cs:222` (`from.Skills[this.Skill].Cap = this.Value`) |
| Veteran-reward skill-cap bonus | **+200 = +20.0** total, in **4** steps of +5 | `VetRewards.SkillCapBonus`, `SkillCapBonusLevels` | **SC**: `servuo/Scripts/Services/VeteranRewards/RewardSystem.cs:17-21,650-673` |
| Skills stored internally as **fixed-point tenths** | `BaseFixedPoint`; `Base = BaseFixedPoint / 10.0` | — | **SC**: `servuo/Server/Skills.cs:285,322` |
| `BaseFixedPoint` limits | `[0, 0x10000)` | — | **SC**: `Skills.cs:294` |
| `SkillLock` values | `Up`, `Down`, `Locked` | — | **SC**: `servuo/Server/Skills.cs` |

**The +5 power-scroll ladder**: `100 + n*5` for `n ∈ {1,2,3,4}` giving **105 / 110 / 115 / 120**
(**SC**: `PowerScroll.cs:154,170`). Names by level (**SC**: `PowerScroll.cs:127-141,173-184`):

| Value | Scroll name |
|---|---|
| 105 | *a wonderous scroll of X* |
| 110 | *an exalted scroll of X* |
| 115 | *a mythical scroll of X* |
| 120 | *a legendary scroll of X* |

Which skills have power scrolls is era-gated (**SC**: `PowerScroll.cs:8-116`):
pre-AoS = 22 skills; AoS adds Chivalry, Focus, Necromancy, Stealing, Stealth, SpiritSpeak;
SE adds Ninjitsu, Bushido; ML adds Spellweaving; SA adds Throwing, Mysticism, Imbuing.

Power-scroll loot type: 105 scrolls, plus **Blacksmith** and **Tailoring** scrolls of any level, are
`Regular`; every other power scroll is `Cursed` and `Insured = false`
(**SC**: `PowerScroll.cs:76-77,249-257`).

## 3.3 Skill gain mechanics

### 3.3.1 The difficulty check and gain chance

Two entry points, both in `servuo/Scripts/Misc/SkillCheck.cs` (**SC**):

**Location/target skills with explicit min/max** (`Mobile_SkillCheckLocation`, `:134-158`):

```csharp
if (value <  minSkill) return false;               // too difficult: auto-fail
if (value >= maxSkill) return true;                // no challenge: auto-succeed
var chance = (value - minSkill) / (maxSkill - minSkill);
return CheckSkill(from, skill, new Point2D(from.Location.X / 4, from.Location.Y / 4), chance);
```

Note `LocationSize = 4` (`SkillCheck.cs:38`): the anti-macro location key is the world tile
**divided by 4** — i.e. a **4×4 tile** region.

**The core check** (`CheckSkill(Mobile, Skill, object, double chance)`, `:240-259`):

```csharp
var success = Utility.Random(100) <= (int)(chance * 100);
var gc      = GetGainChance(from, skill, chance, success);

if (AllowGain(from, skill, obj))
    if (from.Alive && (skill.Base < 10.0 || Utility.RandomDouble() <= gc || CheckGGS(from, skill)))
        Gain(from, skill);

return success;
```

**The gain-chance formula** (`GetGainChance`, `:261-284`):

```
gc  = (Skills.Cap - Skills.Total) / Skills.Cap           // headroom in the 700 budget
gc += (skill.Cap - skill.Base)  / skill.Cap              // headroom in the individual cap
gc /= 2
gc += (1.0 - chance) * (success ? 0.5 : (Core.AOS ? 0.0 : 0.2))   // ← era difference!
gc /= 2
gc *= skill.Info.GainFactor                              // per-skill constant
gc  = clamp(gc, 0.01, 1.00)
if (from is BaseCreature && Controlled) gc += gc * 1.00  // pets get +100 %
```

**Era difference at the marked line:** in **pre-AoS**, *failed* attempts still contribute to gain
chance at 0.2 weight. In **AoS+**, failures contribute **0**. This is why pre-AoS UO allowed
"gain by spamming and failing" and AoS largely removed it.

### 3.3.2 The 0.1 step

`Gain(from, skill)` → `Gain(from, skill, (int)(from.Region.SkillGain(from) * 10))`
(**SC**: `SkillCheck.cs:359-362`) — the region's `SkillGain` multiplier times 10 gives the number of
**fixed-point tenths** gained. Default region multiplier is 1.0, so the default gain is
**+10 fixed-point = +0.1 skill**.

Exceptions (**SC**: `SkillCheck.cs:400-437`):

| Condition | Gain |
|---|---|
| `toGain == 1 && skill.Base <= 10.0` | `Utility.Random(4) + 1` → **+0.1 … +0.4** (fast early gains) |
| Mondain's Legacy enhanced skill quest | ×`RandomMinMax(2, 4)` |
| Scroll of Alacrity active for this skill | `RandomMinMax(2, 5)` fixed-point → **+0.2 … +0.5** |
| Whispering mastery on a controlled pet | `RandomMinMax(2, 5)` |

### 3.3.3 Cap enforcement and total-cap arbitration

```csharp
if (from is PlayerMobile) CheckReduceSkill(skills, toGain, skill);
if (!from.Player || (skills.Total + toGain <= skills.Cap))
    skill.BaseFixedPoint = Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain);
```

**SC**: `SkillCheck.cs:439-452`. `CheckReduceSkill` (`:484-497`):

```csharp
if (skills.Total / skills.Cap >= Utility.RandomDouble())   // probability = total/cap
    foreach (var toLower in skills)
        if (toLower != gainSkill && toLower.Lock == SkillLock.Down && toLower.BaseFixedPoint >= toGain)
        { toLower.BaseFixedPoint -= toGain; break; }
```

So at 700.0/700.0 total, a gain is *always* paid for by lowering a **Down**-locked skill. Below
700 total, the probability of a sacrifice is `total/cap`. If no Down-locked skill can pay, the gain
is **silently dropped** (`skills.Total + toGain > skills.Cap`).

`SkillLock.Up` is required for a skill to gain at all (`SkillCheck.cs:376`).

### 3.3.4 Anti-macro code (era: Opt-in, default **off**)

ServUO ships the anti-macro code **disabled by default**: `_AntiMacroCode = Config.Get("PlayerCaps.EnableAntiMacro", false)`
(**SC**: `SkillCheck.cs:44`).

| Parameter | Value | Source |
|---|---|---|
| Memory of targets/locations | **5 minutes** | **SC**: `SkillCheck.cs:28` (`AntiMacroExpire = TimeSpan.FromMinutes(5.0)`) |
| Uses allowed per location/target | **3** | **SC**: `SkillCheck.cs:33` (`Allowance = 3`) |
| Location granularity | world tile **divided by 4** (4×4 tiles) | **SC**: `SkillCheck.cs:38` |
| Which skills use it | a 58-entry `bool[] UseAntiMacro` table, one flag per skill | **SC**: `SkillCheck.cs:59-123` |

The table is worth reproducing because it defines which skills the original's anti-macro applied to
(**SC**: `SkillCheck.cs:59-123`; `true` = anti-macro applies):

`Alchemy false`, `Anatomy true`, `AnimalLore true`, `ItemID true`, `ArmsLore true`, `Parry false`,
`Begging true`, `Blacksmith false`, `Fletching false`, `Peacemaking true`, `Camping true`,
`Carpentry false`, `Cartography false`, `Cooking false`, `DetectHidden true`, `Discordance true`,
`EvalInt true`, `Healing true`, `Fishing true`, `Forensics true`, `Herding true`, `Hiding true`,
`Provocation true`, `Inscribe false`, `Lockpicking true`, `Magery true`, `MagicResist true`,
`Tactics false`, `Snooping true`, `Musicianship true`, `Poisoning true`, `Archery false`,
`SpiritSpeak true`, `Stealing true`, `Tailoring false`, `AnimalTaming true`, `TasteID true`,
`Tinkering false`, `Tracking true`, `Veterinary true`, `Swords false`, `Macing false`,
`Fencing false`, `Wrestling false`, `Lumberjacking true`, `Mining true`, `Meditation true`,
`Stealth true`, `RemoveTrap true`, `Necromancy true`, `Focus false`, `Chivalry true`,
`Bushido true`, `Ninjitsu true`, `Spellweaving true`, `Mysticism true`, `Imbuing true`,
`Throwing false`.

### 3.3.5 GGS — Guaranteed Gain System

`CheckGGS` / `UpdateGGS` (**SC**: `servuo/Scripts/Misc/SkillCheck.cs:774-806`). Active unless the
shard is a Siege shard (`GGSActive { get { return !Siege.SiegeShard; } }`, `:40`).

```csharp
private static bool CheckGGS(Mobile from, Skill skill)
{
    if (!GGSActive) return false;
    if (from is PlayerMobile && skill.NextGGSGain < DateTime.UtcNow) return true;
    return false;
}

public static void UpdateGGS(Mobile from, Skill skill)
{
    var list   = (int)Math.Min(GGSTable.Length - 1, skill.Base / 5);   // one row per 5.0 skill
    var column = from.Skills.Total >= 7000 ? 2 : from.Skills.Total >= 3500 ? 1 : 0;
    skill.NextGGSGain = DateTime.UtcNow + TimeSpan.FromMinutes(GGSTable[list][column]);
}
```

The full table (`GGSTable`, `SkillCheck.cs:798-806`), in **minutes**:

| Skill range | Total < 350 (col 0) | 350 ≤ Total < 700 (col 1) | Total ≥ 700 (col 2) |
|---|---|---|---|
| 0.0 – 4.9 | 1 | 3 | 5 |
| 5.0 – 9.9 | 4 | 10 | 18 |
| 10.0 – 14.9 | 7 | 17 | 30 |
| 15.0 – 19.9 | 9 | 24 | 44 |
| 20.0 – 24.9 | 12 | 31 | 57 |
| 25.0 – 29.9 | 14 | 38 | 90 |
| 30.0 – 34.9 | 17 | 45 | 84 |
| 35.0 – 39.9 | 20 | 52 | 96 |
| 40.0 – 44.9 | 23 | 60 | 106 |
| 45.0 – 49.9 | 25 | 66 | 120 |
| 50.0 – 54.9 | 27 | 72 | 138 |
| 55.0 – 59.9 | 33 | 90 | 162 |
| 60.0 – 64.9 | 55 | 150 | 264 |
| 65.0 – 69.9 | 78 | 216 | 390 |
| 70.0 – 74.9 | 114 | 294 | 540 |
| 75.0 – 79.9 | 144 | 384 | 708 |
| 80.0 – 84.9 | 180 | 492 | 900 |
| 85.0 – 89.9 | 228 | 606 | 1116 |
| 90.0 – 94.9 | 276 | 744 | 1356 |
| 95.0 – 99.9 | 336 | 894 | 1620 |
| 100.0 – 104.9 | 396 | 1056 | 1920 |
| 105.0 – 109.9 | 468 | 1242 | 2280 |
| 110.0 – 114.9 | 540 | 1440 | 2580 |
| 115.0 – 120.0 | 618 | 1662 | 3060 |

Read as: *"if this much real time has elapsed since your last gain in this skill, your next attempt
gains automatically."* `UpdateGGS` is called only after a **successful** gain
(`SkillCheck.cs:450-451`).

## 3.4 Fame and karma

### 3.4.1 Ranges

| Value | ServUO constant | Source |
|---|---|---|
| Minimum fame | **0** | **SC**: `servuo/Scripts/Misc/Titles.cs:13` (`MinFame = 0`) |
| Maximum fame | **32 000** | **SC**: `Titles.cs:14` (`MaxFame = 32000`) |
| Minimum karma | **−32 000** | **SC**: `Titles.cs:69` (`MinKarma = -32000`) |
| Maximum karma | **+32 000** | **SC**: `Titles.cs:70` (`MaxKarma = 32000`) |

> ⚠ **MAJOR ERA/IMPLEMENTATION CONFLICT.** The commonly documented UO values are
> **fame 0 … 10 000** and **karma −10 000 … +10 000** (**WIKI**). RunUO/ServUO use ±32 000 as the
> *internal* clamp. The **title table below uses the 10 000 thresholds** — i.e. the original client's
> title ladder tops out at 10 000 — so the practical, observable range is 0…10 000 even though the
> server will happily hold 32 000. **For the clone: clamp at 10 000** (matching the original and the
> title table), and keep the internal headroom only if a formula needs it.

### 3.4.2 Award formulas

`Titles.AwardFame` (**SC**: `Titles.cs:16-67`):

```
if offset > 0:
    if fame >= MaxFame: return
    offset -= fame / 100          // diminishing returns at high fame
    if offset < 0: offset = 0
elif offset < 0:
    if fame <= MinFame: return
    offset -= fame / 100          // scales the loss with current fame
    if offset > 0: offset = 0
clamp offset so fame stays within [MinFame, MaxFame]
m.Fame += offset
```

Message thresholds (**SC**: `Titles.cs:48-66`): gain > 40 → "a lot of fame"; > 20 → "a good amount";
> 10 → "some fame"; > 0 → "a little fame". Loss mirrors this at −40 / −20 / −10.

`Titles.AwardKarma` (**SC**: `Titles.cs:72-151`) uses the same shape (minus the `/100` term) plus:

| Modifier | Effect | Source |
|---|---|---|
| Talisman `KarmaLoss` | scales the offset | **SC**: `Titles.cs:76-84` |
| AoS `IncreasedKarmaLoss` attribute | amplifies negative offsets | **SC**: `Titles.cs:86-91` |
| `KarmaLocked` (player) | **blocks all positive karma awards** | **SC**: `Titles.cs:95-96` |
| Karma crossing 0 from + to − (pre-AoS) | **auto-locks karma** with message `1042511`: *"Karma is locked. A mantra spoken at a shrine will unlock it again."* | **SC**: `Titles.cs:146-150` |

**Karma gain/loss from a kill** (**SC**: `servuo/Scripts/Gumps/ReportMurderer.cs:65-90`):

```
fameAward  = victim.Fame / 200
if victim was Innocent to me:  karmaAward = (myKarma > -2500 ? -850 : -110 - (victim.Karma / 100))
else if victim was Criminal/Murderer: karmaAward = +50
```

So **murdering an innocent costs −850 karma** (or `−110 − victimKarma/100` if you are already below
−2500) and awards `victimFame / 200` fame.

### 3.4.3 Titles by fame and karma

The complete table (**SC**: `servuo/Scripts/Misc/Titles.cs:395-467`). `{0}` is the character name;
`{1}` is `Lord` / `Lady` (gender-dependent). The fame rows are *upper bounds*; a character uses the
first row whose threshold is ≥ their fame (the last row, 10 000, is the "Lord/Lady" tier).

**Fame 0 – 1249:**

| Karma ≥ | Title |
|---|---|
| −10000 | The Outcast {0} |
| −5000 | The Despicable {0} |
| −2500 | The Scoundrel {0} |
| −1250 | The Unsavory {0} |
| −625 | The Rude {0} |
| 624 | {0} |
| 1249 | The Fair {0} |
| 2499 | The Kind {0} |
| 4999 | The Good {0} |
| 9999 | The Honest {0} |
| 10000 | The Trustworthy {0} |

**Fame 1250 – 2499:**

| Karma ≥ | Title |
|---|---|
| −10000 | The Wretched {0} |
| −5000 | The Dastardly {0} |
| −2500 | The Malicious {0} |
| −1250 | The Dishonorable {0} |
| −625 | The Disreputable {0} |
| 624 | The Notable {0} |
| 1249 | The Upstanding {0} |
| 2499 | The Respectable {0} |
| 4999 | The Honorable {0} |
| 9999 | The Commendable {0} |
| 10000 | The Estimable {0} |

**Fame 2500 – 4999:**

| Karma ≥ | Title |
|---|---|
| −10000 | The Nefarious {0} |
| −5000 | The Wicked {0} |
| −2500 | The Vile {0} |
| −1250 | The Ignoble {0} |
| −625 | The Notorious {0} |
| 624 | The Prominent {0} |
| 1249 | The Reputable {0} |
| 2499 | The Proper {0} |
| 4999 | The Admirable {0} |
| 9999 | The Famed {0} |
| 10000 | The Great {0} |

**Fame 5000 – 9999:**

| Karma ≥ | Title |
|---|---|
| −10000 | The Dread {0} |
| −5000 | The Evil {0} |
| −2500 | The Villainous {0} |
| −1250 | The Sinister {0} |
| −625 | The Infamous {0} |
| 624 | The Renowned {0} |
| 1249 | The Distinguished {0} |
| 2499 | The Eminent {0} |
| 4999 | The Noble {0} |
| 9999 | The Illustrious {0} |
| 10000 | The Glorious {0} |

**Fame 10 000+ (Lord/Lady tier — `{1}` = Lord or Lady):**

| Karma ≥ | Title |
|---|---|
| −10000 | The Dread {1} {0} |
| −5000 | The Evil {1} {0} |
| −2500 | The Dark {1} {0} |
| −1250 | The Sinister {1} {0} |
| −625 | The Dishonored {1} {0} |
| 624 | {1} {0} |
| 1249 | The Distinguished {1} {0} |
| 2499 | The Eminent {1} {0} |
| 4999 | The Noble {1} {0} |
| 9999 | The Illustrious {1} {0} |
| 10000 | The Glorious {1} {0} |

**Display rule:** another player only sees your fame/karma title if **your fame ≥ 5000**; you always
see your own (**SC**: `Titles.cs:218`: `beheld.ShowFameTitle && ((beholder == beheld) || (beheld.Fame >= 5000))`).

`ShowFameTitle` is `true` by default and can be toggled by the player
(**SC**: `servuo/Server/Mobile.cs:12488`).

**Skill titles** are separate: a 4-tier ladder per skill at skill values 30.0 / 50.0 / 70.0 / 90.0
(**SC**: `Titles.cs:386-393`, `GetTableIndex`: `(BaseFixedPoint - 300) / 100`, clamped to 120.0).
Titles are also granted by champion spawns (**SC**: `Titles.cs:183`, `HarrowerTitles`) and by
veteran reward years (**SC**: `Titles.cs:471-479`, 9 levels at 2/4/6/…/18 years).

## 3.5 Notoriety

### 3.5.1 Levels and hues

**SC**: `servuo/Server/Notoriety.cs:7-17`, cross-checked **SC-C** at
`classicuo/src/ClassicUO.Client/Game/Data/NotorietyFlag.cs:7-17`.

| Value | Name | Default hue (ServUO) | ClassicUO name | Colour |
|---|---|---|---|---|
| 0 | (unused / `Unknown`) | 0x000 | `Unknown` | — |
| 1 | `Innocent` | **0x059** | `Innocent` | cyan / blue |
| 2 | `Ally` | **0x03F** | `Ally` | green |
| 3 | `CanBeAttacked` | **0x3B2** | `Gray` | gray |
| 4 | `Criminal` | **0x3B2** | `Criminal` | gray |
| 5 | `Enemy` | **0x090** | `Enemy` | orange |
| 6 | `Murderer` | **0x022** | `Murderer` | red |
| 7 | `Invulnerable` | **0x035** | `Invulnerable` | yellow |

ServUO's defaults are re-set in `servuo/Scripts/Misc/Notoriety.cs:25-31`. Note that ServUO maps
**both** `CanBeAttacked` (3) and `Criminal` (4) to the same hue 0x3B2, which is why "gray" covers
both "attackable" and "criminal" in practice. ClassicUO's `Invulnerable` client hue is `0x0034`.

### 3.5.2 Flagging rules — the decision order

`MobileNotoriety(source, target)` (**SC**: `servuo/Scripts/Misc/Notoriety.cs:322-495`) checks, in
order:

1. Target is a `PublicMoongate` → **Innocent**.
2. Non-mobile → **CanBeAttacked**.
3. **AoS+:** target `Blessed` → **Invulnerable**; invulnerable vendor → **Invulnerable**;
   `PlayerVendor` or `TownCrier` → **Invulnerable**.
4. `EnemyOfOne` context → **Enemy**.
5. PvP arena enemy/friendly → **Enemy** / **Ally**.
6. Target is staff → **CanBeAttacked**.
7. **ML+:** a controlled pet inherits its master's notoriety (`MobileNotoriety(source, master)`).
8. Target `Murderer` → **Murderer**.
9. Summoned monster body (not familiar / arcane fey / golem) → **Murderer**.
10. `BaseCreature` with `AlwaysMurderer` or animated dead → **Murderer**.
11. Source is a player and target is a `BaseEscort` → **Innocent**.
12. Target `Criminal` → **Criminal**.
13. Guild relations → **Ally** / **Ally (allied guild)** / **Enemy**.
14. Faction / VvV enemy → **Enemy**.
15. Stealing classic-mode perma-flag → **CanBeAttacked**.
16. `AlwaysAttackable` creature → **CanBeAttacked**.
17. House-flag: a friend's-house intruder → **CanBeAttacked**
    (`CheckHouseFlag`, `Notoriety.cs:497-513`).
18. Non-human, non-ghost, non-pet, non-player → **CanBeAttacked**.
19. Recent aggressor / aggressed → **CanBeAttacked**.
20. Otherwise → **Innocent**.

**Corpse notoriety** is a separate function (`CorpseNotoriety`, `Notoriety.cs:209-320`): a corpse is
**Innocent** (blue, unlootable) for 2 minutes to anyone who was not an aggressor, unless the dead
was a murderer / summoned / animated dead, in which case it is **Murderer** (red, lootable)
immediately.

### 3.5.3 Guard zones / town rules

A town region's guards attack players flagged `Criminal` or `Murderer` on sight. Region-level
behaviour lives in `servuo/Scripts/Regions/` (`GuardedRegion`) and in
`Region.OnDeath` / `Region.OnResurrect`. **UNVERIFIED:** the exact guard "instant kill" delay and the
guard-call range. ServUO's `GuardedRegion` implements instant-kill teleport for murderers; the
precise EA numbers are not in these repos.

## 3.6 Criminal flag, murder counts, stat loss

### 3.6.1 Criminal flag

| Parameter | Value | Source |
|---|---|---|
| Criminal timer duration | **2 minutes** (`TimeSpan.FromMinutes(2.0)`) | **SC**: `servuo/Server/Mobile.cs:2102` (`m_ExpireCriminalDelay`) |
| Timer re-starts on every new criminal action | yes — `m_ExpireCriminal.Stop(); m_ExpireCriminal.Start();` | **SC**: `Mobile.cs:11827-11839` |
| Attacks expiry check | every 5 s | **SC**: `Mobile.cs:2123-2145` (`ExpireAggressorsTimer`) |

Actions that flag you criminal (`Mobile.CriminalAction`, **SC**: `servuo/Server/Mobile.cs:3571-3579`
and callers throughout `Scripts/`): attacking an innocent, looting an innocent's corpse, stealing
(from `Stealing.cs`), using a harmful spell/potion on an innocent, snooping, etc.

### 3.6.2 Murder counts

Two counters exist (**SC**: `servuo/Server/Mobile.cs:11766-11812`):

| Counter | Meaning | Decay |
|---|---|---|
| `Kills` (a.k.a. long-term murder count) | permanent record; drives the **Murderer** flag at **≥ 5** | **1 count per 40 hours** of in-game time |
| `ShortTermMurders` | short-term count used by some systems | **1 count per 8 hours** |

Decay code (**SC**: `servuo/Scripts/Mobiles/PlayerMobile.cs:5151-5176`):

```csharp
public void CheckKillDecay()
{
    if (m_ShortTermElapse < GameTime) { m_ShortTermElapse += TimeSpan.FromHours(8);  if (ShortTermMurders > 0) --ShortTermMurders; }
    if (m_LongTermElapse  < GameTime) { m_LongTermElapse  += TimeSpan.FromHours(40); if (Kills > 0)            --Kills; }
}
```

Note `GameTime` only advances while the player is **logged in**
(`GameTime = m_GameTime + (UtcNow - m_SessionStart)`, `PlayerMobile.cs:5182-5195`) — murder counts
do not decay offline. Both timers are **reset** to "now" whenever a new murder is reported
(`ResetKillTime()`, `PlayerMobile.cs:5172-5176`).

`Murderer` is simply `Kills >= 5` (**SC**: `servuo/Server/Mobile.cs:11849`).

### 3.6.3 The murder-report flow

`servuo/Scripts/Gumps/ReportMurderer.cs` (**SC**):

1. On player death, the server collects attackers who are players, are flagged
   `CanReportMurder`, have not been reported yet, and (SE+) are not in the victim's
   `RecentlyReported` list (`:41-57`).
2. It also computes `toGive` — everyone who damaged the victim within the **last 30 seconds**
   (`TimeSpan.FromSeconds(30.0)`, `:55,61`) — and awards fame/karma to them (§3.4.2).
3. **4 seconds after death** (`GumpTimer`, `:212`) a "Would you like to report this murder?"
   gump appears **once per killer, in sequence** (`m_Idx`).
4. **Yes** → `killer.Kills++; killer.ShortTermMurders++; killer.ResetKillTime()`;
   killer gets cliloc `1049067` "You have been reported for murder!".
   On the killer's **5th** kill they additionally get cliloc `502134` "You are now known as a murderer!"
   and are banished (`:138-143`).
5. **No** → nothing.
6. Thieves' Guild members are exempt from the reporting gump (`:92-93`).

**Murderer banishment** (`CheckMurderer`, `ReportMurderer.cs:163-176`): a red player who is on a map
whose rules are **not** `FeluccaRules` and where `SpellHelper.RestrictRedTravel` is on is moved
(after 1 second) to **Felucca `(1458, 844, 5)` ± 5 tiles** with message `1005524`
*"Murderers aren't allowed here, you are banished!"*.

### 3.6.4 Stat loss

> ⚠ **NOT IMPLEMENTED IN SERVUO / RUNUO / MODERNUO.** A full-source search for
> `StatLoss`, `statloss`, `StatLossSkill` finds **only** unrelated hits: taming stat loss
> (`BaseCreature.StatLossAfterTame`), the Factions buff icon `FactionStatLoss`, and a
> VvV `StatLossRemovalPotion`. **There is no implementation of the classic "5+ murders → stat/skill
> loss on death" rule.** This is a genuine gap in the emulator lineage (RunUO never implemented it).

For the clone, the classic rule is **WIKI**-level, not code-verified:

| Rule | Classic value | Confidence |
|---|---|---|
| Stat loss threshold | **5 or more long-term murder counts** | WIKI |
| Effect | on death, **20 % of every skill is lost** (some sources say a 1/3 loss in the earliest era, reduced over time to 20 %) | WIKI / **UNCERTAIN** — the numbers conflict between sources |
| Duration | permanent until re-earned | WIKI |
| Stat loss only applies on the **Felucca** ruleset | yes | WIKI |

**UNVERIFIED — what to measure:** the exact percentage and whether it is applied at the moment of
death or on resurrection. To measure you would need an original-client capture on a shard with the
murder system enabled, reading the character's skill values before/after death at ≥ 5 counts.
**Clone recommendation:** implement it as `-20 % of all skills, floor at 10.0`, behind a config flag,
and document it as an approximation.

## 3.7 Death, corpse, and resurrection

### 3.7.1 Death sequence

`Mobile.Kill()` → `Mobile.OnDeath(Container c)` (**SC**: `servuo/Server/Mobile.cs:3975-4268`):

1. Set `Hits = Stam = Mana = 0`; clear poison, combatant, paralysis, frozen, warmode.
2. `DropHolding()` — anything on the cursor is dropped.
3. Cancel trades, cancel the current spell, cancel the target cursor.
4. Sort every item: keep / move-to-corpse / move-to-backpack (see §2.11).
5. Create the corpse via `Mobile.CreateCorpseHandler` with the sorted content and the equipment list.
6. Broadcast the death animation packet.
7. `Region.OnDeath(this)`, then `OnDeath(c)`:
   - **NPCs**: `Delete()` — the mobile is removed entirely.
   - **Players**:
     - `Send(DeathStatus.Instantiate(true))` (the "you are dead" status)
     - `Warmode = false`
     - `BodyMod = 0`
     - **`Body = Race.GhostBody(this)`** — the commented-out legacy line is
       `Body = this.Female ? 0x193 : 0x192`, i.e. the classic ghost body IDs are
       **0x192 (male) / 0x193 (female)**. `Race.GhostBody(this)` returns these for humans.
     - Equip an immovable **death shroud, item ID `0x204E`**, on layer `OuterTorso` (0x16), inserted
       at index 0 of the item list.
     - `Send(DeathStatus.Instantiate(false))`
     - `CheckStatTimers()`

**SC**: `servuo/Server/Mobile.cs:4229-4267`.

### 3.7.2 Corpse

| Parameter | Value | Source |
|---|---|---|
| Corpse is a `Container` holding the dead's items | — | `servuo/Scripts/Items/Corpses/Corpse.cs` |
| Default decay | **7 minutes** | **SC**: `Corpse.cs:421` |
| Bone decay after emptying | **7 minutes** | **SC**: `Corpse.cs:422` |
| Loot rights (monster corpses) | **2 minutes** | **SC**: `Corpse.cs:118` |
| Instanced corpse lifetime | 3 minutes | **SC**: `Corpse.cs:120` |
| Corpse of a player | persists for the full decay time; notoriety per §3.5.2 | — |

### 3.7.3 Ghost state

| Aspect | Behaviour | Source |
|---|---|---|
| Body | `Race.GhostBody` → `0x192` male, `0x193` female | **SC**: `Mobile.cs:4240-4241` |
| Movement | ghosts move normally; they cannot be attacked and cannot attack | — |
| Speech | ghosts' speech is mutated for the living; `CanHearGhosts` lets staff/veterans hear it | **SC**: `servuo/Server/Mobile.cs:4896+` (`MutateSpeech`), `:12798` (`CanHearGhosts`) |
| Items | the ghost keeps insured/blessed/newbied items and (AoS+) everything in its backpack at its pack positions | **SC**: `Mobile.cs:4072-4113`, `:3973` |
| Bank panel | closes automatically on death | **SC**: `Mobile.cs:4000-4005` |

### 3.7.4 Resurrection

`Mobile.Resurrect()` (**SC**: `servuo/Server/Mobile.cs:3646-3704`):

| Step | Effect |
|---|---|
| Gate | `Region.OnResurrect(this)` and `CheckResurrect()` must allow it |
| `Poison = null` | |
| `Warmode = false` | |
| **`Hits = 10`** | you come back at **10 HP**, not at full |
| **`Stam = StamMax`** | stamina is fully restored |
| **`Mana = 0`** | mana is **empty** |
| Body | `Race.AliveBody(this)` |
| Death shroud | the item with ID `8270` (`0x204E`) is deleted |
| Packets | `SendIncomingPacket()` is called **twice** (to force the world to re-stream) |

**Healer NPCs** (`servuo/Scripts/Mobiles/NPCs/BaseHealer.cs`, **SC**):

| Parameter | Value |
|---|---|
| Resurrection offer delay | **2 seconds** (`ResurrectDelay = TimeSpan.FromSeconds(2.0)`, `:10`) |
| Trigger | the ghost walks within **2 tiles** and has LOS, having been outside 2 tiles before (`:149`) |
| Criminals | `CheckResurrect(m)` refuses criminals |
| Gump | `ResurrectGump(m, ResurrectMessage.Healer)` — a simple CONTINUE / CANCEL dialog |

**Paid resurrection** (`ResurrectGump(owner, healer, int price)`, **SC**:
`servuo/Scripts/Gumps/ResurrectGump.cs:94-148,181-200`):

| Parameter | Detail |
|---|---|
| Gump title | cliloc `1060017`: *"Wishing to rejoin the living, are you? I can restore your body... for a price of course..."* |
| Options | "Grudgingly pay the money" (`1060015`) / "I'd rather stay dead, you scoundrel!!!" (`1060016`) |
| Payment | **withdrawn from the bank box**, message `1060398` "~1_AMOUNT~ gold has been withdrawn from your bank box." |
| Failure | message `1060020` "Unfortunately, you do not have enough cash in your bank to cover the cost of the healing." |
| Refusal | message `1060019` "You decide against paying the healer, and thus remain dead." |
| Location check | `from.Map.CanFit(from.Location, 16, false, false)` must pass, else `502391` "Thou can not be resurrected there!" |

**The price is data-driven** — supplied by the calling healer NPC. The classic fee is
**WIKI**-level; ServUO does not hard-code a default. `WanderingHealer` and the town healers pass
their own prices. **UNVERIFIED:** the exact original fee schedule per healer type.

**Ankhs**: ServUO has no dedicated `Ankh.cs` in the Scripts tree (search returns nothing) — the
resurrection ankh is handled through the same `ResurrectGump` path with
`ResurrectMessage` variants. **UNVERIFIED:** whether the original ankh charged gold or was free, and
its exact reuse cooldown. Measure: click an ankh in the original client and observe the gump text.

`ResurrectMessage` enum (`ResurrectGump.cs:10-18`) selects the flavour text: `Generic`, `Healer`,
`ChaosShrine`, `SilverSapling`, etc.

## 3.8 Hunger and food

| Parameter | Value | Source |
|---|---|---|
| Hunger range | 0 … (max) — `Mobile.Hunger` | **SC**: `servuo/Server/Mobile.cs:1577-1588` |
| Thirst | also exists — `Mobile.Thirst` | **SC**: `servuo/Scripts/Misc/FoodDecay.cs:34-38` |
| Starving rate | **−1 hunger every 5 minutes** | **SC**: `servuo/Scripts/Misc/FoodDecay.cs:9` (`base(TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(5))`), `:28-38` |
| Starting hunger | **20** | **SC**: `servuo/Scripts/Misc/CharacterCreation.cs:201` |
| Passive decay applies to **all logged-in mobiles** | yes — iterates `NetState.Instances` | **SC**: `FoodDecay.cs:19-26` |
| Food `FillFactor` | per-food item; restores `Hunger += FillFactor` with a "you are simply too full" cap | ServUO `Scripts/Items/Consumables/Food.cs` |

**Starvation effects:** ServUO's `FoodDecay` only decrements hunger; **there is no code that makes
hunger gate hit-point regeneration or cause damage.** `CanRegenHits` is `Alive && (RegenThroughPoison || !Poisoned)`
(**SC**: `servuo/Server/Mobile.cs:1908`) with no hunger term.

> ⚠ **Era conflict.** In original UO, hunger *did* gate passive regeneration (a starving character
> stopped regenerating HP). This is **not** modelled in ServUO/RunUO. **UNCERTAIN** on the original
> threshold. **Clone recommendation:** implement hunger as a regeneration gate — `Hunger == 0` →
> hits regen rate ×2 slower or disabled — and mark it as a design choice rather than a cited number,
> because the exact original rule is **UNVERIFIED**. To measure: set hunger to 0 in a controlled
> environment and observe the HP regen tick interval.

---

# 4. TIME AND WORLD

## 4.1 The in-game clock and day/night cycle

| Parameter | Value | Source |
|---|---|---|
| **Real seconds per in-game minute** | **5.0 s** | **SC**: `servuo/Scripts/Items/Tools/Clocks.cs:28` (`SecondsPerUOMinute = 5.0`) |
| **Real seconds per in-game day** | **120 s = 2 real minutes** | **SC**: `Clocks.cs:29` (`MinutesPerUODay = SecondsPerUOMinute * 24` = 120) |
| World epoch | **1 September 1997** | **SC**: `Clocks.cs:31` (`WorldStart = new DateTime(1997, 9, 1)`) |
| Time formula | `totalMinutes = (UtcNow - WorldStart).TotalSeconds / 5.0` | **SC**: `Clocks.cs:95-97` |
| Per-facet offset | `totalMinutes += map.MapIndex * 320` | **SC**: `Clocks.cs:99-102` |
| Per-longitude offset | `totalMinutes += x / 16` | **SC**: `Clocks.cs:105` — each 16 world tiles east = 1 in-game minute |
| Hour/minute | `hours = (totalMinutes / 60) % 24; minutes = totalMinutes % 60` | **SC**: `Clocks.cs:107-108` |
| Moon phase | `totalMinutes /= 10 + (MapIndex * 20)`, then `totalMinutes % 8` | **SC**: `Clocks.cs:72-84` |

**Day/night cycle: a full UO day is 2 real hours** (120 real minutes × 60 = 7200 real seconds → 1440
in-game minutes). Day and night are each therefore roughly 1 real hour. This is one of the most
distinctive UO facts and must be reproduced exactly: the world clock runs **24× faster than real time**.

`MoonPhase` enum order (`Clocks.cs:13-23`): `WaxingCrescent, FirstQuarter, WaxingGibbous, Full,
WaningGibbous, LastQuarter, WaningCrescent, New`.

Time-of-day naming (`Clocks.cs:127-135` comments):
`00:00–00:59` Witching hour · `01:00–03:59` Middle of night · `04:00–07:59` Early morning ·
`08:00–11:59` Late morning · … (continues for afternoon/evening).

## 4.2 Light levels

`servuo/Scripts/Misc/LightCycle.cs` (**SC**):

| Constant | Value |
|---|---|
| `DayLevel` | **0** |
| `NightLevel` | **12** |
| `DungeonLevel` | **26** |
| `JailLevel` | **9** |
| Light-level value range | **0 (brightest) … ~31 (pitch black)** — client-enforced; 26 is "dungeon dark" |

`ComputeLevelFor(Mobile)` (`LightCycle.cs:48-83`) — **note this is RunUO's variant, which differs
from OSI's**:

```
hours < 4                       -> NightLevel (12)
4 <= hours < 6                  -> 12 + (((h-4)*60 + m) * (0 - 12)) / 120     // linear fade 12 -> 0
6 <= hours < 22                 -> DayLevel (0)
22 <= hours < 24                -> 0 + (((h-22)*60 + m) * (12 - 0)) / 120     // linear fade 0 -> 12
```

The source file documents the difference explicitly (`LightCycle.cs:57-68`):

```
/* OSI times:
 *   Midnight ->  3:59 AM : Night
 *    4:00 AM -> 11:59 PM : Day
 *
 * RunUO times:
 *   10:00 PM -> 11:59 PM : Scale to night
 *   Midnight ->  3:59 AM : Night
 *    4:00 AM ->  5:59 AM : Scale to day
 *    6:00 AM ->  9:59 PM : Day
 */
```

> ⚠ **Era/source conflict.** **OSI's actual model is a hard binary day/night with no dusk/dawn
> ramp** (night 00:00–03:59, day 04:00–23:59). RunUO/ServUO added a 2-hour fade at each boundary to
> make the transition less jarring. **Clone recommendation:** ship the OSI binary model as
> `--light=osi` and the RunUO ramp as the default (it looks better), and document the difference.
> The OSI behaviour is **WIKI/comment-verified**, not code-verified.

| Related | Value | Source |
|---|---|---|
| Light update cadence | every `Clock.SecondsPerUOMinute` = **5 s** | **SC**: `LightCycle.cs:33` (`new LightCycleTimer(Clock.SecondsPerUOMinute).Start()`) |
| Timer priority | `OneSecond` | **SC**: `LightCycle.cs:148` |
| Dungeon override | `DungeonRegion.AlterLightLevel` sets `global = LightCycle.DungeonLevel` (26) | **SC**: `servuo/Scripts/Regions/DungeonRegion.cs:65` |
| Jail override | `global = LightCycle.JailLevel` (9) | **SC**: `servuo/Scripts/Regions/Jail.cs:41` |
| Night Sight spell | `targ.LightLevel = LightCycle.DungeonLevel / 2` (i.e. **13**), duration `Utility.Random(15, 25)` **minutes** | **SC**: `servuo/Scripts/Items/Consumables/NightSight.cs:34-37`; `LightCycle.cs:127` |
| Global light packet | `0x4F` GlobalLightLevel, cached per level (`GlobalLightLevel.Instantiate(level)`), array size `0x100` | **SC**: `servuo/Server/Network/Packets.cs:910-933` |
| Personal light packet | `0x4E` PersonalLightLevel, plus `PersonalLightLevelZero` | **SC**: `Packets.cs:935-951` |

The final global light the client renders is `min(regionLight, computedDayNightLight)` with the
personal light (e.g. Night Sight, a light source) applied on top
(**SC**: `servuo/Scripts/Mobiles/PlayerMobile.cs:1113,1153`).

## 4.3 Seasons and weather

### 4.3.1 Seasons

Seasons are a **per-map** property, not a global one (**SC**: `servuo/Server/Map.cs:428` `public int Season { get; set; }`,
set in `MapDefinitions.RegisterMap`).

| Value | Season |
|---|---|
| 0 | Spring |
| 1 | Summer |
| 2 | Autumn / Fall |
| 3 | Winter |
| 4 | Desolation |

**SC**: `servuo/Scripts/Misc/MapDefinitions.cs:46` (documented in the `RegisterMap` parameter comment).

The season is sent to the client with packet **`0xBC` SeasonChange**, cached in a 5×2 table indexed
`[season][playSound]` (**SC**: `servuo/Server/Network/Packets.cs:3260-3296`). It is re-sent on login
and on request (`PacketHandlers.cs:2574`, `Mobile.cs:7739,10014`).

The per-map default seasons from `MapDefinitions` (**SC**: `MapDefinitions.cs:27-32`):
Felucca **4** (Desolation), Trammel **0** (Spring), Ilshenar/Malas/Tokuno/TerMur **1** (Summer).

> Note: UO's retail Felucca ships as season 4 but this is overridden by the "seasons" feature in the
> client's options; the server value is what the client is told.

### 4.3.2 Weather

`servuo/Scripts/Misc/Weather.cs` (**SC**):

| Parameter | Value | Source |
|---|---|---|
| Weather tick interval | **30 seconds** | **SC**: `Weather.cs:199,209` (`TimeSpan.FromSeconds(30.0)`) |
| First tick | a random 20 %–100 % of the interval | **SC**: `Weather.cs:37` (`(0.2 + RandomDouble() * 0.8) * interval.TotalSeconds`) |
| Precipitation on/off | `m_Active = (m_ChanceOfPercipitation > Utility.Random(100))` — a **percentage** | **SC**: `Weather.cs:341` |
| Extreme temperature | `m_ChanceOfExtremeTemperature > Utility.Random(100)` | **SC**: `Weather.cs:342` |
| Storm density ramp | `density = m_Stage * 5`, clamped to `[10, 70]` | **SC**: `Weather.cs:365-377` |
| Weather packet | server → client `0x65` Weather(type, density, temperature) | **SC**: `Weather.cs:405`; ModernUO `modernuo/Projects/Server/Network/Packets/OutgoingPlayerPackets.cs:95` |
| Weather regions | each `Weather` instance owns a `Rectangle2D[]` area per facet | **SC**: `Weather.cs:24-37,199-209` |

Weather is **purely cosmetic** — no gameplay effect in ServUO. Rain/snow is randomly positioned in
tile-sized patches inside the weather region (`Weather.cs:288-305`).

## 4.4 Facets / maps

**Definitive table** (**SC**: `servuo/Scripts/Misc/MapDefinitions.cs:16-35`;
ModernUO equivalent at `modernuo/Projects/Server/Maps/MapLoader.cs`):

| Map index | Map ID | File index | Name | Width × Height (tiles) | Season | Rules | Introduced |
|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | **Felucca** | **7168 × 4096** | 4 | `FeluccaRules` (None) | launch (1997) |
| 1 | 1 | 1 | **Trammel** | **7168 × 4096** | 0 | `TrammelRules` | **AoS (Feb 2003)** |
| 2 | 2 | 2 | **Ilshenar** | **2304 × 1600** | 1 | `TrammelRules` | **Third Dawn (2001)** |
| 3 | 3 | 3 | **Malas** | **2560 × 2048** | 1 | `TrammelRules` | **AoS (Feb 2003)** |
| 4 | 4 | 4 | **Tokuno** | **1448 × 1448** | 1 | `TrammelRules` | **Samurai Empire (Nov 2004)** |
| 5 | 5 | 5 | **Ter Mur** | **1280 × 4096** | 1 | `TrammelRules` | **Stygian Abyss (Sep 2009)** |
| 0x7F | 0x7F | 0x7F | *Internal* | `Map.SectorSize × Map.SectorSize` | 1 | `Internal` | — |

Notes:

- Felucca and Trammel are **exact mirrors** of one another — same dimensions, same static geography.
- The client's advertised facet availability is the `ClientFlags` bitmask
  (**SC**: `servuo/Server/ExpansionInfo.cs:32-44`): `Felucca=0x1, Trammel=0x2, Ilshenar=0x4,
  Malas=0x8, Tokuno=0x10, TerMur=0x20, Unk1=0x40, Unk2=0x80, UOTD=0x100`.
- Map files on disk: `map{0..5}.mul` (legacy) or `map{0..5}LegacyMUL.uop` (client 7.0.0+), plus
  `staidx{n}.mul` / `statics{n}.mul` for statics and `tiledata.mul` for flags. ServUO's `TileData`
  reader switches on file length `>= 3188736` to detect the 7.0.9.0+ `tiledata.mul` format
  (**SC**: `servuo/Server/TileData.cs:206-244`).
- `MultiComponentList.PostHSFormat = true` ((**SC**: `MapDefinitions.cs:53`)) — the High Seas
  multi format (OSI client patch 7.0.9.0).
- `TileMatrixPatch.Enabled = false` (**SC**: `MapDefinitions.cs:51`) — OSI client patch 6.0.0.0
  added per-map terrain patches; ServUO disables them.

### 4.4.1 Map rules — what "Trammel" actually means mechanically

`MapRules` (**SC**: `servuo/Server/Map.cs:120-130`):

| Flag | Value | Meaning |
|---|---|---|
| `None` | 0x0000 | |
| `Internal` | 0x0001 | internal map (dragging, commodity deeds) |
| `FreeMovement` | 0x0002 | **anyone can move over anyone else without taking stamina loss** (no shoving) |
| `BeneficialRestrictions` | 0x0004 | **beneficial actions on criminals/murderers are disallowed** |
| `HarmfulRestrictions` | 0x0008 | **harmful actions on innocents are disallowed** |
| `TrammelRules` | `FreeMovement \| BeneficialRestrictions \| HarmfulRestrictions` | |
| `FeluccaRules` | `None` | full PvP, shoving enabled |

`FreeMovement` is checked at `servuo/Server/Mobile.cs:3518` (shove disabled) and
`Movement.cs` — it removes the push-through stamina cost. `BeneficialRestrictions` and
`HarmfulRestrictions` are checked in `Mobile_AllowBeneficial` / `Mobile_AllowHarmful`
(**SC**: `servuo/Scripts/Misc/Notoriety.cs:90-91,128-129`).

### 4.4.2 Siege (Siege Perilous) variant

`MapDefinitions.cs:16-24`: on a Siege shard, **all** maps use `FeluccaRules`, i.e. Trammel is not a
safe zone. This is the single-flag way to make the whole world PvP.

## 4.5 Regions and towns

A `Region` is a named area on a map with hooks. `Region` subclasses that matter
(**SC**: `servuo/Server/Region.cs`, `servuo/Scripts/Regions/`):

| Region type | Hooks used |
|---|---|
| `GuardedRegion` | guards attack criminals/murderers |
| `DungeonRegion` | `AlterLightLevel` → `DungeonLevel` (26); no recall/mark |
| `TownRegion` | town rules; no PvP between innocents |
| `Jail` | `AlterLightLevel` → `JailLevel` (9); `SkillCheck.Gain` returns early inside a jail (**SC**: `SkillCheck.cs:366-367`) |
| `NoTeleportRegion`, house regions, etc. | |

Region hooks invoked by the simulation (**SC**):

| Hook | Called from |
|---|---|
| `Region.CanMove(m, d, newLocation, oldLocation, map)` | `Mobile.Move`, `Mobile.cs:3266` |
| `Region.OnMoveOver` / `OnMoveOff` | `Mobile.Move` |
| `Region.OnDeath(m)` | `Mobile.Kill`, `Mobile.cs:4171` |
| `Region.OnResurrect(m)` | `Mobile.Resurrect`, `Mobile.cs:3650` |
| `Region.OnBeforeDeath(m)` | `Mobile.Kill`, `Mobile.cs:3991` |
| `Region.AlterLightLevel` | `Mobile.ComputeLightLevels`, `Mobile.cs:911-918` |
| `Region.SkillGain(m)` | `SkillCheck.Gain`, `SkillCheck.cs:361` |
| `Region.OnDecay(item)` | `Item.OnDecay`, `Item.cs:2051` |
| `Region.OnSingleClick(m, item)` | `PacketHandlers.HandleSingleClick`, `PacketHandlers.cs:1699` |
| `Region.InsuranceMultiplier` | `PlayerMobile.GetInsuranceCost`, `PlayerMobile.cs:2660-2661` |

### 4.5.1 Visibility and update ranges (needed for "what can I see / click")

| Parameter | Value | Source |
|---|---|---|
| Default update range | **18 tiles** | **SC**: `servuo/Server/Main.cs:652` (`GlobalUpdateRange = 18`) |
| Maximum the client may negotiate | **24 tiles** | **SC**: `Main.cs:653` (`GlobalMaxUpdateRange = 24`) |
| Radar range | **40 tiles** | **SC**: `Main.cs:654` (`GlobalRadarRange = 40`) |
| Range test shape | **square / Chebyshev** (`|dx| <= R && |dy| <= R`), *not* Euclidean | **SC**: `servuo/Server/Utility.cs:701-728` |
| LOS max distance | `GlobalMaxUpdateRange + 1` = **25** | **SC**: `servuo/Server/Map.cs:2865` (`m_MaxLOSDistance`) |
| Client-negotiated range | client sends its desired range; server clamps to `min(requested, GlobalMaxUpdateRange)` and stores it on the `NetState` | **SC**: `servuo/Server/Network/PacketHandlers.cs:1758-1767`, `NetState.cs:630` |

The square range test is a detail worth reproducing: UO's "in range" is a box, which is why
diagonal interactions work at visibly longer Euclidean distances than cardinal ones.

## 4.6 Tile flags and how walkability is derived

### 4.6.1 The complete `TileFlag` enum

**SC**: `servuo/Server/TileData.cs:128-164`; identical in ModernUO
`modernuo/Projects/Server/TileData.cs:216-250` (ModernUO adds `NoDiagonal = 0x02000000` where
ServUO has `HoverOver = 0x02000000`, plus HS33–HS44 extension bits at 0x1_0000_0000+).

| Bit | Value | Name | Relevance to simulation |
|---|---|---|---|
| 0 | `0x00000001` | `Background` | rendering |
| 1 | `0x00000002` | `Weapon` | item classification |
| 2 | `0x00000004` | `Transparent` | rendering |
| 3 | `0x00000008` | `Translucent` | rendering |
| 4 | `0x00000010` | `Wall` | rendering / LOS hint |
| 5 | `0x00000020` | `Damaging` | **movement**: tiles with this flag damage on contact |
| 6 | `0x00000040` | `Impassable` | **movement**: part of `ImpassableSurface` |
| 7 | `0x00000080` | `Wet` | **movement**: water; swimmable; blocks `CantWalk` mobiles |
| 8 | `0x00000100` | `Unknown1` | — |
| 9 | `0x00000200` | `Surface` | **movement**: you can stand on it |
| 10 | `0x00000400` | `Bridge` | **movement**: `itemTop` is not extended by `Height`, so you can walk under it |
| 11 | `0x00000800` | `Generic` | — |
| 12 | `0x00001000` | `Window` | rendering / LOS |
| 13 | `0x00002000` | `NoShoot` | **combat**: blocks ranged attacks through this tile |
| 14 | `0x00004000` | `ArticleA` | **naming**: "a sword" vs "an axe" |
| 15 | `0x00008000` | `ArticleAn` | naming |
| 16 | `0x00010000` | `Internal` | — |
| 17 | `0x00020000` | `Foliage` | rendering (client can hide) |
| 18 | `0x00040000` | `PartialHue` | rendering |
| 19 | `0x00080000` | `Unknown2` | — |
| 20 | `0x00100000` | `Map` | item is a map |
| 21 | `0x00200000` | `Container` | **movement**: hidden containers don't block (EA) |
| 22 | `0x00400000` | `Wearable` | equipment |
| 23 | `0x00800000` | `LightSource` | **lighting** |
| 24 | `0x01000000` | `Animation` | **rendering**: animated static |
| 25 | `0x02000000` | `HoverOver` (ServUO) / `NoDiagonal` (ModernUO) | **⚠ conflict — see below** |
| 26 | `0x04000000` | `Unknown3` | — |
| 27 | `0x08000000` | `Armor` | item classification |
| 28 | `0x10000000` | `Roof` | **rendering**: hidden when "draw roofs" is off |
| 29 | `0x20000000` | `Door` | **movement**: skipped when `ignoreDoors` |
| 30 | `0x40000000` | `StairBack` | rendering: stair sprite orientation |
| 31 | `0x80000000` | `StairRight` | rendering: stair sprite orientation |

> ⚠ **Bit 25 conflict — IMPORTANT.** ServUO names `0x02000000` **`HoverOver`** (used for the Stygian
> Abyss flying mechanic, `Movement.cs:184`). ModernUO names the same bit **`NoDiagonal`**. These are
> two different readings of the same bit. The likely truth: bit 25 was unused in the original
> `tiledata.mul` and different projects repurposed it. **For a faithful clone: do not assign
> gameplay meaning to bit 25** unless you have verified it in the actual `tiledata.mul` your client
> data uses. Also note the SA "hover over" check in ServUO *also* matches on the tile's **name
> string** being exactly `"hover over"`, which is a data-file convention, not a flag.

**Flags that do NOT affect walkability:** `Wall`, `Window`, `Roof`, `Foliage`, `NoShoot`,
`StairBack`, `StairRight`, `Bridge`, `Generic`, `LightSource`. Of these, only `NoShoot` (ranged
attacks) and `Bridge` (step height) have any simulation role at all. **The walkability test uses
exactly three flags: `Impassable`, `Surface`, `Wet`, plus `Door` and `Container` as exceptions**
(§1.6). This is the single most important simplification for the clone.

### 4.6.2 The land-vs-static distinction

| Concept | Detail | Source |
|---|---|---|
| Land tile | exactly one per map cell, ID range `[0, 0x4000)`, from `map{n}.mul` | `TileData.cs:209` (`m_LandData = new LandData[0x4000]`) |
| Static tile | zero or more per cell, ID range `[0, 0x10000)`, from `statics{n}.mul` indexed by `staidx{n}.mul` | `TileData.cs:224` (`m_ItemData = new ItemData[0x10000]`) |
| `MaxLandValue` | `0x4000` − 1 = **16383** | `TileData.cs:174-178` |
| `MaxItemValue` | `0x10000` − 1 = **65535** | `TileData.cs:175-178` |
| Per-cell average Z | `map.GetAverageZ(x, y, out zLow, out zCenter, out zTop)` — three values from the four land corners | `Movement.cs:166,599,1238` |
| `ItemData.Height` | the tile's "tallest" height field from `tiledata.mul` | `TileData.cs:242` |
| `ItemData.CalcHeight` | the averaged standing height — **this is what movement uses** | `Movement.cs:84,218,279` |

`ItemData` fields read from `tiledata.mul` per item (**SC**: `TileData.cs:233-244`):
`flags:uint64`, `weight:byte`, `quality:byte`, `unknown:uint16`, `unknown:byte`,
`quantity:byte`, `unknown:int32`, `unknown:byte`, `value:byte`, `height:byte`, then a 20-byte
null-terminated ASCII name.

### 4.6.3 Z when standing on statics — the algorithm in one table
| Step | Rule |
|---|---|
| 1. Candidate surfaces | land (if not impassable at the relevant Z) + every static + every non-multi item with `Surface` (or `Wet` if the mobile can swim) at that cell |
| 2. Eligibility | a candidate qualifies if `candidateTop <= mobile.Z` — i.e. **you can only stand on a surface at or below your current Z** |
| 3. Ranking | pick the candidate **closest in Z to your current Z**; ties go to the higher one |
| 4. Resulting Z | `candidate.Z + itemData.CalcHeight` |
| 5. Falling | walking off a ledge simply picks a lower candidate; there is **no fall damage** in the base algorithm |
| 6. Bridging | a `Bridge` tile does not extend `itemTop` by its `Height`, so you can pass under it from a lower Z |
| 7. Drops | dropping an *item* onto the world uses `maxZ = thrower.Z + 17` and requires a `Surface` with `top <= maxZ` |

**SC**: `servuo/Scripts/Services/Pathing/Movement.cs:211-343` (movement) and `:585-672` (`GetStartZ`)
and `servuo/Server/Item.cs:5225-5290` (`FindDropPoint`).

## 4.7 Spawn and respawn timers

### 4.7.1 The classic `Spawner` item

**SC**: `servuo/Scripts/Services/Spawner/Spawner.cs`.

| Parameter | Default | Source |
|---|---|---|
| Default constructor `Spawner(string spawnName)` | `this(1, 5, 10, 0, 4, spawnName)` — **1 creature, min 5 min, max 10 min, team 0, spawn range 4** | **SC**: `Spawner.cs:41` |
| Min delay | `TimeSpan.FromMinutes(minDelay)` | `Spawner.cs:54` |
| Max delay | `TimeSpan.FromMinutes(maxDelay)` | `Spawner.cs:54` |
| Actual delay | `Utility.RandomMinMax(minSeconds, maxSeconds)` — **uniform random between min and max, recomputed after every spawn** | **SC**: `Spawner.cs:623-626` |
| Timer tick granularity | `OneSecond` if `MaxDelay < 1 min`, else `FiveSeconds` | **SC**: `Spawner.cs:1114-1120` |
| Respawn trigger | when the spawner is not full | `Spawner.cs:414,432` |
| Spawner item ID | `0x1F13` (a "spawner" graphic) | `Spawner.cs:47` |

### 4.7.2 The XML spawner (the one almost every shard actually uses)

| Parameter | Default | Source |
|---|---|---|
| `defMinDelay` | **5 minutes** | **SC**: `servuo/Scripts/Services/XmlSpawner/XmlSpawner Core/XmlSpawner2.cs:127` |
| `defMaxDelay` | **10 minutes** | **SC**: `XmlSpawner2.cs:128` |
| Values in `.xmlspawner` files | `MinDelay` / `MaxDelay`, in **seconds** if the value is small, **minutes** otherwise | `XmlSpawner2.cs:2536-2541,6341-6356` |
| Per-spawn-entry override | each `SpawnObject` may carry its own `MinDelay`/`MaxDelay` (`-1` = inherit) | `XmlSpawner2.cs:12492-12538` |

### 4.7.3 Vendor restock

Vendors restock on a separate timer — see §5.2.

---

# 5. ECONOMY BASICS

## 5.1 Gold as an item

| Parameter | Value | Source |
|---|---|---|
| Class | `Server.Items.Gold : Item` | `servuo/Scripts/Items/Consumables/Gold.cs:7` |
| Weight per coin | **0.02 stones** (pre-ML); **0.02 / 3 ≈ 0.00667 stones** (ML+) | **SC**: `Gold.cs:34-38` (`Core.ML ? (0.02 / 3) : 0.02`) |
| Stackable | yes | `Gold.cs` |
| Max stack | 60 000 (implicit, the global stack cap, §2.2.4) | **SC**: `servuo/Server/Item.cs:2132` |
| Practical consequence | 60 000 gold weighs **1 200 stones** pre-ML — far beyond any player's capacity, so gold must be banked | derived |
| Bank checks | `Server.Items.BankCheck` — a non-stackable item representing a gold amount | **SC**: `servuo/Server/Items/Containers.cs:13` |

## 5.2 NPC vendor restock

| Parameter | Value | Source |
|---|---|---|
| Restock interval | **60 minutes** | **SC**: `servuo/Scripts/Mobiles/NPCs/BaseVendor.cs:37` (`DelayRestock = TimeSpan.FromMinutes(Config.Get("Vendors.RestockDelay", 60))`) |
| Per-vendor override | vendors may override `RestockDelay` | **SC**: `BaseVendor.cs:363` |
| Restock check | on the vendor's periodic tick: `if (DateTime.UtcNow - m_LastRestock > RestockDelay) Restock();` | **SC**: `BaseVendor.cs:920-922` |
| Inventory decay (unsold stock) | **1 hour** | **SC**: `BaseVendor.cs:900` (`InventoryDecayTime = TimeSpan.FromHours(1.0)`) |
| Restock algorithm | `GenericBuyInfo.Restock` (`servuo/Scripts/VendorInfo/GenericBuy.cs:328-353`): if the amount hit 0, **`MaxAmount *= 2` capped at 999**; otherwise the max amount is **halved** back toward the baseline; then `Amount = MaxAmount` | **SC** |
| Economy stock amount | **500** (config `Vendors.EconomyStockAmount`) | **SC**: `BaseVendor.cs:36` |
| Force restock | `[restock` command / `ForceRestock` property | **SC**: `BaseVendor.cs:875-896` |

The doubling/halving rule is a genuine UO "supply and demand" mechanic: selling a vendor out of an
item causes its stock ceiling to **double** on the next restock (up to 999), and buying it out
causes the ceiling to **halve**.

## 5.3 Vendor price formulas

### 5.3.1 The core relation

```csharp
public int GetBuyPriceFor(Item item, BaseVendor vendor)
{
    return (int)(1.90 * GetSellPriceFor(item, vendor));
}
```

**SC**: `servuo/Scripts/VendorInfo/GenericSell.cs:126-129`.

**Buy price = 1.90 × sell price.** There is **no quantity discount and no haggling** in any
RunUO-lineage emulator (full-source absence check). The 1.90 multiplier plus truncation toward zero
is the whole model.

### 5.3.2 Sell price derivation

`GenericSellInfo.GetSellPriceFor` (**SC**: `GenericSell.cs:40-119`):

1. Look the item **type** up in the vendor's `Dictionary<Type,int>` base-price table.
2. If the vendor uses the **economy** (`BaseVendor.UseVendorEconomy`, default `Core.AOS && !Siege`,
   **SC**: `BaseVendor.cs:33`) and the item type is a tracked `EconomyItem`, the sell price is
   **`(int)(buyInfo.Price * 0.75)`**, minimum 1.
3. Otherwise adjust by quality:
   - `ItemQuality.Low` → **× 0.60**
   - `ItemQuality.Exceptional` → **× 1.25**
   - normal → × 1.00
4. Armour additionally: `+ 100 × (int)Durability + 100 × (int)ProtectionLevel`
5. Weapons additionally: `+ 100 × (int)DurabilityLevel + 100 × (int)DamageLevel`
6. Beverages have hard-coded per-container prices: `Pitcher` 3 (empty) / 5 (full),
   `BeverageBottle` 3 / 3, `Jug` 6 / 6.

`PriceScalar` is a per-vendor percentage (`GetPriceScalar()`, `BaseVendor.cs:104`), applied as
`((price * scalar) + 50) / 100` (i.e. rounded to nearest), floored at 2 for economy items
(**SC**: `GenericBuy.cs:146-200`).

### 5.3.3 Vendor economy (price drift)

**SC**: `servuo/Scripts/VendorInfo/GenericBuy.cs:146-200` + `BaseVendor.cs:34-36`:

```
ecoInc = 0
if TotalBought >= BuyItemChange:  ecoInc += TotalBought / BuyItemChange
if TotalSold   >= SellItemChange: ecoInc -= TotalSold   / SellItemChange
price  = base + ecoInc
```

| Parameter | Default | Config key |
|---|---|---|
| `BuyItemChange` | **1000** | `Vendors.BuyItemChange` |
| `SellItemChange` | **1000** | `Vendors.SellItemChange` |
| `EconomyStockAmount` | **500** | `Vendors.EconomyStockAmount` |

So buying 1000 units of an economy item from a vendor raises its price by **+1 gold**; selling 1000
units to the vendor lowers it by 1. Siege shards inflate all vendor prices by **× 3**
(**SC**: `GenericBuy.cs:60-63`).

### 5.3.4 Era note

`UseVendorEconomy` is **AoS+** (it is `Core.AOS && !Siege.SiegeShard`). In a strict pre-AoS target,
vendors have fixed, infinite prices and the `ecoInc` term is always 0. **The 1.90 × ratio itself is
era-independent** in the RunUO lineage.

## 5.4 Bulk order deeds (AoS+)

| Aspect | Detail | Source |
|---|---|---|
| Availability | AoS+ (bulk order system) | `servuo/Scripts/Services/BulkOrders/` |
| Reward gold tables | nine-tier arrays per BOD size/type, from ~3 000 to 200 000 gp | **SC**: `servuo/Scripts/Services/BulkOrders/Rewards/Rewards.cs:542-598,901-1166` |
| BOD turn-in cooldown | 2 seconds | **SC**: `servuo/Scripts/Mobiles/NPCs/BaseVendor.cs:1284` (`pm.NextBODTurnInTime = DateTime.UtcNow + TimeSpan.FromSeconds(2.0)`) |

Not required for a T2A/Renaissance target.

## 5.5 Bank box

| Parameter | Value | Source |
|---|---|---|
| Item ID | `0xE7C` | **SC**: `servuo/Server/Items/Containers.cs:29` |
| Layer | `Layer.Bank` = **0x1D** | **SC**: `Containers.cs:34` |
| `DefaultMaxWeight` | **0** = unlimited | **SC**: `Containers.cs:20` |
| Max items | the global default **125** unless the shard raises it | derived from `servuo/Server/Items/Container.cs:1672` |
| Opened via | banker NPC, or `Mobile.OpenBank`; also the "Open Bank" context menu | — |
| Auto-closes on: move, resurrect, death | | **SC**: `Mobile.cs:3110-3115`, `:3662-3667`, `:4000-4005` |
| Sell proceeds and healer fees | go through `Banker.Deposit` / `Banker.Withdraw` | **SC**: `BaseVendor.cs:1263`; `ResurrectGump.cs:185` |
| Account-level gold (a later option) | `AccountGold.Enabled` allows gold stored as an account number rather than an item | **SC**: `servuo/Scripts/Mobiles/NPCs/Banker.cs:151-154` |
| Starting item | a **New Player Ticket** is placed in the bank box on character creation | **SC**: `servuo/Scripts/Misc/CharacterCreation.cs:276` |

## 5.6 Item insurance (AoS+)

| Parameter | Value | Source |
|---|---|---|
| Enabled when | **`Core.AOS && !Siege.SiegeShard`** | **SC**: `servuo/Scripts/Misc/CurrentExpansion.cs:29` (`Mobile.InsuranceEnabled = Core.AOS && !Siege.SiegeShard`) |
| Default per item | **600 gp** ("this handles old items, set items, etc") | **SC**: `servuo/Scripts/Mobiles/PlayerMobile.cs:2644` |
| Faction items | **800 gp** | **SC**: `PlayerMobile.cs:2646-2647` |
| Imbued items | `clamp(imbueWeight, 10, 800)` | **SC**: `PlayerMobile.cs:2648-2649` |
| Vendor-priced items | `clamp(GenericBuyInfo.BuyPrices[type], 10, 800)` | **SC**: `PlayerMobile.cs:2650-2651` |
| Newbied items | **10 gp** | **SC**: `PlayerMobile.cs:2652-2653` |
| "Prized" negative-attribute items | **× 2** | **SC**: `PlayerMobile.cs:2655-2658` |
| Region multiplier | `cost *= Region.InsuranceMultiplier` | **SC**: `PlayerMobile.cs:2660-2661` |
| Auto-renew on death | if enabled, the cost is withdrawn from the bank; the killer receives **half** the cost as a deposit | **SC**: `PlayerMobile.cs:3816-3849` |
| Not auto-renewing | the item's `Insured` flag is **cleared** and `PayedInsurance = false` — insurance lapses | **SC**: `PlayerMobile.cs:3834-3838` |
| Insufficient funds | `item.Insured = false`, message `1061079` "You lack the funds to purchase the insurance" | **SC**: `PlayerMobile.cs:3826-3832` |
| Young players | never pay insurance; instead **everything movable** goes to the backpack | **SC**: `PlayerMobile.cs:3809-3810,3859,3866-3869,3876,3883` |
| Insured items on death | moved to the **backpack**, not the corpse | **SC**: `PlayerMobile.cs:3859-3861` |
| Toggling | `ToggleItemInsurance` context-menu entry (cliloc `6201`); auto-renew entries `6200` / `6202`; the full menu is `1114299` and only appears when able to insure | **SC**: `PlayerMobile.cs:2353-2371` |
| The insured target may be at **unlimited range** | `BeginTarget(-1, false, TargetFlags.None, ...)` | **SC**: `PlayerMobile.cs:2525,2588,2600,2607,2635` |

## 5.7 Player vendors (present in all eras; mechanised differently by era)

**Pre-AoS / classic (`BaseHouse.NewVendorSystem == false`)**: one vendor per house, flat fee paid
from the house owner's bank, no commission.

**AoS+ ("new vendor system")**: a house owner may place several vendors and **rent** them.

| Parameter | Value | Source |
|---|---|---|
| Commission (commission vendors) | **5.25 %** | **SC**: `servuo/Scripts/Mobiles/NPCs/PlayerVendor.cs:285` (`public double CommissionPerc { get { return 5.25; } }`) |
| Rental durations | **7 / 14 / 21 / 28 days** | **SC**: `servuo/Scripts/Mobiles/NPCs/RentedVendor.cs:15-20` |
| Deposit handling | sale proceeds accumulate in `HoldGold` and are deposited to the owner's bank on `Collect` / contract end | **SC**: `PlayerVendor.cs:697,731,1039-1109` |
| Vendor pack capacity | unlimited weight (`DefaultMaxWeight = 0`) | **SC**: `PlayerVendor.cs:98` |
| Landlord vs renter | `RentedVendor` tracks `Landlord`, `RentalGold`, `LandlordRenew`, `RentalDuration` | **SC**: `RentedVendor.cs:63-92` |
| Rental contract price cap | 5 000 000 gp | **SC**: `servuo/Scripts/Gumps/VendorRentalGumps.cs:286-288,510-512` |
| Haggling | **none** | **SC** (absence) |

Player-vendor listing gumps: `VendorInventoryGump` (owner view), `VendorRentalGumps` (contract UI).

---

# 6. Summary table: numbers the clone cannot get wrong

| # | Number | Value | Confidence |
|---|---|---|---|
| 1 | Foot walk step | 400 ms | SC×3 |
| 2 | Foot run step | 200 ms | SC×3 |
| 3 | Mounted walk step | 200 ms | SC×3 |
| 4 | Mounted run step | 100 ms | SC×3 |
| 5 | Full in-game day | 120 real seconds | SC |
| 6 | Real seconds per in-game minute | 5.0 | SC |
| 7 | `PersonHeight` | 16 | SC×2 |
| 8 | `StepHeight` | 2 | SC×2 |
| 9 | Mobile Z-overlap threshold | 15 | SC |
| 10 | Lift / drop range | 2 tiles | SC |
| 11 | Client drag-gesture range | 3 tiles | SC-C |
| 12 | Max stack | 60 000 | SC |
| 13 | Backpack cap | 400 stones (550 ML+) | SC |
| 14 | Global container cap | 125 items / 400 stones | SC |
| 15 | HitsMax | `50 + STR/2` | SC×2 |
| 16 | StamMax | `DEX` | SC×2 |
| 17 | ManaMax | `INT` | SC×2 |
| 18 | Stat cap | 225 | SC×2 |
| 19 | Individual stat cap | 125 (100 pre-AoS, WIKI) | SC / WIKI |
| 20 | Skill cap | 700.0 (720 with vet rewards) | SC |
| 21 | Individual skill cap | 100.0 (120 with a legendary scroll) | SC |
| 22 | Skill gain step | +0.1 | SC |
| 23 | Stat gain interval | 15 min (player) / 5 min (pet) | SC |
| 24 | Criminal timer | 2 min | SC |
| 25 | Murderer threshold | 5 long-term kills | SC |
| 26 | Murder count decay | 1 per 40 h (long) / 1 per 8 h (short), **online time only** | SC |
| 27 | Fame / karma displayed range | 0…10 000 / −10 000…+10 000 (internal clamp ±32 000) | WIKI / SC |
| 28 | Resurrect HP | 10 | SC |
| 29 | Corpse decay | 7 min | SC |
| 30 | Corpse loot-rights window | 2 min | SC |
| 31 | Ground item decay | 60 min | SC |
| 32 | Hunger decay | −1 per 5 min | SC |
| 33 | Vendor restock | 60 min | SC |
| 34 | Buy price | 1.90 × sell price | SC |
| 35 | Gold weight | 0.02 stones | SC |
| 36 | Commission vendor fee | 5.25 % | SC |
| 37 | Insurance default | 600 gp | SC |
| 38 | Default spawner delay | 5–10 min | SC×2 |
| 39 | Felucca / Trammel size | 7168 × 4096 | SC |
| 40 | `NightLevel` / `DungeonLevel` | 12 / 26 | SC |

---

# 7. UNVERIFIED items and how to measure them

| # | Open question | What would resolve it |
|---|---|---|
| 1 | **Stamina cost of running in the ORIGINAL client.** Is it 1 per running step? Is it 0 while walking? Is the client authoritative? | Instrument an original-client session: fix DEX and STR, record the exact number of *running* steps between full and zero stamina, on foot and mounted. Compare against the UOAssist/Razor stamina counters. |
| 2 | **Run-only vs all-steps drain.** Emulators charge every step; players remember run-only. | Same measurement as #1 with a walking-only traverse. |
| 3 | **Murderer stat loss.** Threshold, percentage, timing (on death vs on resurrect), and whether it is Felucca-only. | Cannot be derived from these repos (not implemented). Needs a packet/skill-value capture on a live shard at ≥ 5 counts. Classic figure is 20 %; earlier figures of 33 % exist. |
| 4 | **Healer / ankh resurrection fees.** Per-healer price, ankh reuse cooldown, whether ankhs are free. | Read the gump text and bank delta from an original client at every town healer and ankh. |
| 5 | **OSI light cycle.** Binary day/night vs RunUO's 2-hour ramp. | ServUO's own comment states OSI is binary; the exact minute boundaries are asserted in a comment, not code. Verify by screenshotting the client at 03:55 and 04:05 in-game. |
| 6 | **Pre-AoS individual stat cap of 100.** ServUO defaults to 125/150. | ServUO has no pre-AoS branch. Needs a Renaissance-era client capture of the stats gump. |
| 7 | **TileFlag bit 25.** ServUO says `HoverOver`; ModernUO says `NoDiagonal`. | Inspect the raw `tiledata.mul` value for a known tile in both readings. The clone should simply ignore bit 25. |
| 8 | **Context-menu entry numbers 0x01A3, 0x012D, 0x0140, 0x0194-0x0196, 0x025A/0x025C, 0x0321, 0x03F2/0x03F5/0x03F6, 0x0334.** Their meanings. | They are client-side clilocs. Resolve by reading the client's `cliloc.enu` at those numbers. |
| 9 | **Alt+click / Ctrl+click / Shift+click semantics in the ORIGINAL client.** | ClassicUO's bindings are configurable defaults, not protocol. Needs original-client UI documentation or a capture. |
| 10 | **Hunger gating of regeneration.** | Original behaviour believed to slow/stop regen at hunger 0; not modelled in any emulator. Needs a controlled regen-tick measurement at hunger 0. |
| 11 | **Guard behaviour:** call range, response delay, instant-kill rule. | `GuardedRegion` in ServUO is a community implementation; no EA numbers available. |
| 12 | **Door open/close animation delay** and whether the client predicts door state. | Timing capture. |

---

# 8. Source map — where each subsystem lives

Every path in this table was verified to exist on disk (2019–2026 `main` branches of each repo).

| Subsystem | ServUO | ModernUO | ClassicUO |
|---|---|---|---|
| Movement algorithm (Z/height) | `Scripts/Services/Pathing/Movement.cs` | `Projects/UOContent/Engines/Pathing/Movement.cs` | `src/ClassicUO.Client/Game/Pathfinder.cs` |
| Step timing | `Server/Mobile.cs:3063-3071` | `Projects/Server/Mobiles/Movement.cs:30-37` | `src/ClassicUO.Client/Game/Data/MovementSpeed.cs` |
| Direction encoding / offsets | `Server/Movement.cs` | `Projects/Server/Mobiles/Movement.cs:61-121` | `src/ClassicUO.Client/Game/Data/Direction.cs` |
| Movement throttle (server) | `Server/Mobile.cs:3281-3346` | `Projects/Server/Network/MovementThrottle.cs` | — |
| Stamina & encumbrance | `Scripts/Misc/WeightOverloading.cs` | (regen in `Projects/Server/Mobiles/Mobile.cs`) | `src/ClassicUO.Client/Game/GameObjects/PlayerMobile.cs` |
| Regen rates | `Scripts/Misc/RegenRates.cs` | `Projects/Server/Mobiles/Mobile.cs:1800-1810,2072-2114,9039-9052` | — |
| Layers | `Server/Item.cs:25-197` | `Projects/Server/Items/Layer.cs` | `src/ClassicUO.Client/Game/Data/Layers.cs` |
| Tile flags | `Server/TileData.cs:128-164` | `Projects/Server/TileData.cs:216-263` | `src/ClassicUO.Client/Game/Data/StaticFilters.cs` |
| Maps / facets | `Server/Map.cs`, `Scripts/Misc/MapDefinitions.cs` | `Projects/Server/Maps/Map.cs`, `Maps/MapLoader.cs` | `src/ClassicUO.Client/Game/Map/Map.cs` |
| Light cycle | `Scripts/Misc/LightCycle.cs` | (client computes; server sends `OutgoingLightPackets.cs`) | `src/ClassicUO.Client/Game/Data/LightColors.cs`, `Game/GameObjects/IsometricLight.cs` |
| Clock | `Scripts/Items/Tools/Clocks.cs` | — | — |
| Weather | `Scripts/Misc/Weather.cs` | `Projects/Server/Network/Packets/OutgoingPlayerPackets.cs:95` | `src/ClassicUO.Client/Game/Weather.cs` |
| Spawners | `Scripts/Services/Spawner/Spawner.cs`, `Scripts/Services/XmlSpawner/…` | `Projects/UOContent/Engines/Spawners/` | — |
| Skill check / gain / GGS | `Scripts/Misc/SkillCheck.cs` | `Projects/UOContent/Skills/SkillCheck.cs` | `src/ClassicUO.Client/Game/Data/Skill.cs` (display only) |
| Skill table | `Server/Skills.cs` | `Projects/Server/Skills.cs` | — |
| Stats | `Server/Mobile.cs:8229-8700,12720-12805` | `Projects/Server/Mobiles/Mobile.cs:1752-1762,2072-2114` | `src/ClassicUO.Client/Game/UI/Gumps/StatusGump.cs` |
| Titles / fame / karma | `Scripts/Misc/Titles.cs` | `Projects/UOContent/Misc/Titles.cs` | — |
| Notoriety | `Server/Notoriety.cs` (consts) + `Scripts/Misc/Notoriety.cs` (handlers) | `Projects/Server/Mobiles/Notoriety.cs` (consts) + `Projects/UOContent/Misc/Notoriety.cs` (handlers) | `src/ClassicUO.Client/Game/Data/NotorietyFlag.cs` |
| Targeting | `Server/Targeting/Target.cs`, `TargetFlags.cs` | `Projects/Server/Targeting/` (`Target.cs`, `TargetFlags.cs`, `LandTarget.cs`, `StaticTarget.cs`, `MultiTarget.cs`) | `src/ClassicUO.Client/Game/Managers/TargetManager.cs` |
| Context menus | `Server/ContextMenus/ContextMenu.cs`, `ContextMenuEntry.cs` | `Projects/Server/ContextMenus/`; content in `Projects/UOContent/Context Menus/ContextMenuSystem.cs` | `src/ClassicUO.Client/Game/UI/Controls/ContextMenuControl.cs` |
| Packets — outgoing | `Server/Network/Packets.cs` | `Projects/Server/Network/Packets/` (`OutgoingMobilePackets.cs`, `OutgoingItemPackets.cs`, `OutgoingContainerPackets.cs`, `OutgoingLightPackets.cs`, …) | `src/ClassicUO.Client/Network/OutgoingPackets.cs` |
| Packets — incoming handlers | `Server/Network/PacketHandlers.cs` | `Projects/Server/Network/Packets/IncomingPackets.cs`; content in `Projects/UOContent/Network/Packets/IncomingTargetingPackets.cs` | `src/ClassicUO.Client/Network/PacketHandlers.cs` |
| Vendors & prices | `Scripts/Mobiles/NPCs/BaseVendor.cs`, `Scripts/VendorInfo/GenericBuy.cs`, `GenericSell.cs` | `Projects/UOContent/Mobiles/Vendors/` | `src/ClassicUO.Client/Game/UI/Gumps/ShopGump.cs` |
| Player vendors | `Scripts/Mobiles/NPCs/PlayerVendor.cs`, `RentedVendor.cs`, `Gumps/VendorRentalGumps.cs` | `Projects/UOContent/Mobiles/Vendors/` | — |
| Crafting | `Scripts/Services/Craft/` (`Core/CraftGump.cs`, `Core/CraftItem.cs`, `Def*.cs`) | `Projects/UOContent/Engines/Craft/` | — |
| Houses | `Scripts/Multis/BaseHouse.cs`, `Scripts/Multis/HousePlacementTool.cs` | `Projects/UOContent/Multis/Houses/` | `src/ClassicUO.Client/Game/Managers/HouseManager.cs`, `HouseCustomizationManager.cs` |
| Boats | `Scripts/Multis/Boats/BaseBoat.cs` | `Projects/UOContent/Multis/Boats/` | — |
| Corpses | `Scripts/Items/Corpses/Corpse.cs` | `Projects/UOContent/Items/Misc/Corpses/` | `src/ClassicUO.Client/Game/UI/Gumps/GridLootGump.cs` |
| Containers / gumps | `Server/Items/Container.cs`, `Scripts/Items/Containers/Container.cs` | `Projects/Server/Items/Container.cs` | `src/ClassicUO.Client/Game/UI/Gumps/ContainerGump.cs` |
| Insurance | `Scripts/Mobiles/PlayerMobile.cs:2517-3050,3807-3884` | `Projects/UOContent/Mobiles/PlayerMobile.cs` | — |
| Murder reporting | `Scripts/Gumps/ReportMurderer.cs` | `Projects/UOContent/…` | — |
| Resurrection | `Server/Mobile.cs:3646-3704`, `Scripts/Gumps/ResurrectGump.cs`, `Scripts/Mobiles/NPCs/BaseHealer.cs` | `Projects/UOContent/Mobiles/Healers/` | — |
| Macros | — | — | `src/ClassicUO.Client/Game/Managers/MacroManager.cs` |
| Expansion / era gates | `Server/ExpansionInfo.cs`, `Scripts/Misc/CurrentExpansion.cs` | `Projects/Server/ExpansionInfo.cs`, `Projects/UOContent/Configuration/ExpansionConfiguration.cs` | `src/ClassicUO.Client/Game/Data/ClientFeatures.cs`, `LockedFeatures.cs` |

---

*End of document 01.*
