# Ultima Online — Combat, Magic & Item-Property Systems
### Formula-level reference for a faithful single-player offline clone

**Research file:** `research/03-combat-magic-items.md`
**Compiled:** from primary source (ServUO `pub57`, ModernUO `main`) plus UOGuide cross-checks.

---

## 0. How to read this document

### 0.1 Sources used (all primary unless marked)

| Tag | Source | Commit / branch | Local path used |
|---|---|---|---|
| `SU` | ServUO (RunUO lineage — the reference for **classic / pre-AoS** rules) | branch `pub57` | `research/_src/servuo/` |
| `MU` | ModernUO (clean-room rewrite; **post-AoS** only) | branch `main` | `research/_src/modernuo/` |
| `UG` | UOGuide wiki | live | `uoguide.com` |
| `ST` | UO Stratics | live | `stratics.com/uo` |

Repo-relative paths: a path starting with `Scripts/` is ServUO (`SU`); a path starting with `Projects/` is ModernUO (`MU`).

> **Important discovery about ServUO's layout.** The task brief named `Server/Items/Weapons`, `Server/Items/Armor`, `Server/Combat/**`. In ServUO **pub57** those do not exist: all game content lives under **`Scripts/`**. `Scripts/Items/Equipment/Weapons/BaseWeapon.cs` is the real path; there is no `Server/Combat/` directory at all. `Server/` holds only the engine core (`Server/Mobile.cs`, `Server/Item.cs`, `Server/Map.cs`, …). ModernUO does use `Projects/UOContent/Items/Weapons/` and `Projects/Server/`. Claims below cite the path that actually exists.

### 0.2 Era model

ServUO gates era by `Core.*` booleans. The eras that matter here, oldest → newest:

| Flag | Era | Effect on this document |
|---|---|---|
| (none) | **Pre-AoS / "classic"** (UO: Renaissance, T2A, UOR) | AR armour, damage-level weapons (`ruin`…`vanq`), no special moves, no item properties, halved damage vs players, slow swing timer |
| `Core.AOS` | **Age of Shadows** (2003) | elemental resistances replace AR, `AosAttributes` item properties, special moves (`WeaponAbility`), `MageWeapon`, luck, 1.25 s swing floor, Y% damage multiplier model |
| `Core.SE` | **Samurai Empire** (2004) | `GetDelay` switches to the "ticks" formula, thrown weapons, `LowerAmmoCost` |
| `Core.ML` | **Mondain's Legacy** (2005) | `MlSpeed` (4 s × multiplier) replaces `AosSpeed` (1/100 s ticks), quivers, `Core.ML` weapon damage ternaries, runic intensity table changes |
| `Core.SA` `Core.HS` `Core.TOL` `Core.EJ` | Stygian Abyss / High Seas / Time of Legends / Endless Journey | leeches above 50, Eodon, loot-budget generator |

**Every formula below is tagged with the era it belongs to.** Where ServUO keeps a legacy branch alive "for AOS as well", that is stated explicitly.

### 0.3 Confidence markers

| Marker | Meaning |
|---|---|
| **`[HIGH]`** | Read directly from source code and quoted. Trust it. |
| **`[MED]`** | Derived from source code *plus* a wiki/second source agreeing. Trust the shape, sanity-check constants. |
| **`[LOW]`** | Single secondary source only, or a source comment that contradicts itself. Implement but expect to tune. |
| **`[UNVERIFIED]`** | **Not found in any source consulted.** The document says exactly what would settle it. **Do not invent a number here.** |

---

## 1. COMBAT LOOP

### 1.1 War mode, peace mode, and the combat flag

* `Mobile.Warmode` is a plain boolean that only drives the client animation/paperdoll state. It does **not** by itself start combat. **`[HIGH]`** — `Server/Mobile.cs`.
* Attacking is initiated by the client's `AttackRequest` packet, which the server turns into `Mobile.Combatant = target` plus an aggression-flag (`AggressorInfo`) bookkeeping pass. The swing scheduler then runs off `Mobile.NextCombatTime`. **`[HIGH]`** — `Server/Mobile.cs` (combat/aggression region).
* `Mobile.Kill()` force-clears **`Warmode = false`** and **`Combatant = null`** as its first actions. **`[HIGH]`** — `Server/Mobile.cs:4024`, `:4033`.
* **Peace mode matters mechanically in three places** (all `Core.AOS`+):
  1. `BaseWeapon.OnSwing` refuses to swing while the attacker has an active peacemaking effect: `canSwing = (p == null || p.PeacedUntil <= DateTime.UtcNow);` **`[HIGH]`** — `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1672-1677`.
  2. Paralyze/freeze blocks the swing: `canSwing = (!attacker.Paralyzed && !attacker.Frozen);` **`[HIGH]`** — `BaseWeapon.cs:1663`.
  3. Casting an unimplemented-movement spell blocks the swing: `canSwing = (sp == null || !sp.IsCasting || !sp.BlocksMovement);` **`[HIGH]`** — `BaseWeapon.cs:1667-1670`.

### 1.2 Attack initiation and the combat timer

```csharp
// SU Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1155-1170 (approx; the "begin combat" path)
from.NextCombatTime = Core.TickCount + (int)GetDelay(from).TotalMilliseconds;
```

* The swing scheduler is **not** an autonomous timer that fires on its own. `Mobile`'s combat timer calls `Weapon.OnSwing(...)` only when `Core.TickCount >= NextCombatTime`. `OnSwing` returns the *next* delay, which the caller stores back into `NextCombatTime`. **`[HIGH]`** — `BaseWeapon.cs:1163`, `:1256`, `:1717`; `Server/Mobile.cs` combat timer.
* `MaxRange` gates whether the swing is melee or ranged: `m_MaxRange == -1 ? (Core.AOS ? AosMaxRange : OldMaxRange) : m_MaxRange` **`[HIGH]`** — `BaseWeapon.cs:575`.
* The swing is broadcast to observers as a `Swing` packet before hit resolution. **`[HIGH]`** — `BaseWeapon.cs:1686` (melee), `BaseRanged.cs:91`.
* **`OnSwing` order of operations** (both melee and ranged): (1) era-gated `canSwing` checks, (2) `attacker.HarmfulCheck(damageable)`, (3) `attacker.DisruptiveAction()` — this is what interrupts the attacker's own spell, (4) broadcast `Swing`, (5) if `CheckHit` → `OnHit`, else `OnMiss`, (6) return `GetDelay`. **`[HIGH]`** — `BaseWeapon.cs:1657-1718`.

### 1.3 Swing delay — the three formulas

`BaseWeapon.GetDelay(Mobile m)` has **four** branches, chosen by era. This is the single most important function in melee combat.

```csharp
// SU Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1541-1631  [HIGH — quoted verbatim]
public virtual TimeSpan GetDelay(Mobile m)
{
    double speed = Speed;                 // Speed => MlSpeed (ML) | AosSpeed (AOS) | OldSpeed
    if (speed == 0) return TimeSpan.FromHours(1.0);

    double delayInSeconds;

    if (Core.SE)
    {
        int bonus = AosAttributes.GetValue(m, AosAttribute.WeaponSpeed);
        if (bonus > 60) bonus = 60;                       // SSI cap 60%

        double ticks;
        if (Core.ML)
        {
            int stamTicks = m.Stam / 30;
            ticks = speed * 4;
            ticks = Math.Floor((ticks - stamTicks) * (100.0 / (100 + bonus)));
        }
        else
        {
            speed = Math.Floor(speed * (bonus + 100.0) / 100.0);
            if (speed <= 0) speed = 1;
            ticks = Math.Floor((80000.0 / ((m.Stam + 100) * speed)) - 2);
        }
        if (ticks < 5) ticks = 5;                         // hard floor: 5 ticks
        delayInSeconds = ticks * 0.25;
    }
    else if (Core.AOS)
    {
        int v = (m.Stam + 100) * (int)speed;
        int bonus = AosAttributes.GetValue(m, AosAttribute.WeaponSpeed);
        v += AOS.Scale(v, bonus);                         // v += v*bonus/100
        if (v <= 0) v = 1;
        delayInSeconds = Math.Floor(40000.0 / v) * 0.5;
        if (delayInSeconds < 1.25) delayInSeconds = 1.25; // AoS floor 1.25 s
    }
    else
    {
        int v = (m.Stam + 100) * (int)speed;
        if (v <= 0) v = 1;
        delayInSeconds = 15000.0 / v;                     // CLASSIC: no floor, no SSI
    }
    return TimeSpan.FromSeconds(delayInSeconds);
}
```

Restated as implementation-ready formulas:

| Era | Formula | Floor | Notes |
|---|---|---|---|
| **Classic (pre-AoS)** | `seconds = 15000 / ((Stam + 100) × OldSpeed)` | none | `OldSpeed` is an integer; **lower = faster** (it is a "speed" divider, not a delay) |
| **AoS (Core.AOS, not SE)** | `v = (Stam + 100) × AosSpeed`; `v += v × SSI/100`; `seconds = floor(40000 / v) × 0.5` | `1.25 s` | Source comment: *"Maximum swing rate capped at one swing per second. OSI dev said that it has and is supposed to be 1.25"* **`[MED]`** — `BaseWeapon.cs:1611-1616` |
| **SE, pre-ML** | `spd = floor(AosSpeed × (SSI + 100) / 100)`, min 1; `ticks = floor(80000 / ((Stam + 100) × spd) − 2)`; `seconds = ticks × 0.25` | `5 ticks = 1.25 s` | SSI capped at 60 **`[HIGH]`** |
| **ML (`Core.ML`)** | `stamTicks = Stam / 30`; `ticks = floor((MlSpeed × 4 − stamTicks) × 100 / (100 + SSI))`; `seconds = ticks × 0.25` | `1.25 s` | `MlSpeed` is a **seconds-per-swing** float; at 100+ stamina the penalty term collapses. `MlSpeed` is `speed` here, so `MlSpeed × 4` = a 4-second baseline in 0.25 s ticks. **`[HIGH]`** |
| **ModernUO** | Same ML-shape formula (ModernUO is post-AoS only) | `1.25 s` | Cross-check below |

**ModernUO cross-check `[HIGH]`** — `Projects/UOContent/Items/Weapons/BaseWeapon.cs` implements the same SE/ML tick formula; ModernUO has no pre-AoS branch at all, which is itself the confirmation that the classic formula died with AoS.

**Stamina's role, exactly:** stamina appears **only inside the delay denominator** (`Stam + 100`) or as the ML `Stam/30` tick rebate. It is **not** a flat per-swing cost in either codebase. At 0 stamina you are at the `+100` baseline; at 100 stamina the classic divisor is exactly doubled, i.e. **half the delay**.

**Stamina cost of swinging — `[UNVERIFIED]` for the classic "swing costs stamina" rule.**
* ServUO implements **no generic stamina cost per swing.** The only `Stam -=` in the weapon path is the weapon-ability cost (`Fists.cs:172,228,238` → `attacker.Stam -= 15` for the wrestle special moves). **`[HIGH]`** — grep of `Scripts/Items/Equipment/Weapons/*.cs`.
* The user-visible classic rule ("you lose stamina when you swing a heavy weapon") is **not modelled** by this codebase. The only stamina *drain on the defender* is macing (see §1.10). To settle it you would need either (a) an OSI/EA client-visible measurement on a pre-AoS shard, or (b) a RunUO 1.0.0 release read — this tree does not contain it.

### 1.4 Weapon speed / damage / strength selection

```csharp
// SU Scripts/Items/Equipment/Weapons/BaseWeapon.cs:630-654
public int Speed { get { if (m_Speed != -1) return m_Speed;
                         if (Core.ML)  return MlSpeed;
                         else if (Core.AOS) return AosSpeed;
                         return OldSpeed; } }
// :657-673
public int StrRequirement { get { if (m_NegativeAttributes.Massive > 0) return 125;
                                 return m_StrReq == -1 ? (Core.AOS ? AosStrengthReq : OldStrengthReq) : m_StrReq; } }
// :609 / :620
public int MinDamage { get { return m_MinDamage == -1 ? (Core.AOS ? AosMinDamage : OldMinDamage) : m_MinDamage; } }
public int MaxDamage { get { return m_MaxDamage == -1 ? (Core.AOS ? AosMaxDamage : OldMaxDamage) : m_MaxDamage; } }
```
**`[HIGH]`** — note the `NegativeAttributes.Massive` interaction: the **Massive** negative property pins Strength requirement to **125** regardless of weapon.

### 1.5 Base damage roll

```csharp
// SU BaseWeapon.cs:3601-3661
public virtual void GetBaseDamageRange(Mobile attacker, out int min, out int max)
{
    if (attacker is BaseCreature) {
        BaseCreature c = (BaseCreature)attacker;
        if (c.DamageMin >= 0) { min = c.DamageMin; max = c.DamageMax; return; }   // creatures use their own table
        if (this is Fists && !attacker.Body.IsHuman) { min = attacker.Str / 28; max = attacker.Str / 28; return; }
    }
    if (this is Fists && TransformationSpellHelper.UnderTransformation(attacker, typeof(HorrificBeastSpell)))
    { min = 5; max = 15; }                                                       // necro Horrific Beast unarmed
    else { min = MinDamage; max = MaxDamage; }
}
public virtual double GetBaseDamage(Mobile attacker)
{
    GetBaseDamageRange(attacker, out int min, out int max);
    int damage = Utility.RandomMinMax(min, max);
    if (Core.AOS) return damage;
    // Apply damage level offset: Regular 0, Ruin 1, Might 3, Force 5, Power 7, Vanq 9
    if (m_DamageLevel != WeaponDamageLevel.Regular) damage += (2 * (int)m_DamageLevel) - 1;
    return damage;
}
```
**`[HIGH]`.** So in classic the "ruin/might/force/power/vanquishing" naming is **two separate bonuses**: a flat `+2×level − 1` on the damage roll, **and** a percentage `+15/20/25/30/35 %` in the scalar (next section). Both apply.

`WeaponDamageLevel` enum order is `Regular, Ruin, Might, Force, Power, Vanq` — the comment block at `BaseWeapon.cs:3647-3654` spells it out. **`[HIGH]`**

### 1.6 Damage formula — CLASSIC (pre-AoS)

```csharp
// SU BaseWeapon.cs:3825-3912
public virtual double ScaleDamageOld(Mobile attacker, double damage, bool checkSkills)
{
    if (checkSkills) { attacker.CheckSkill(Tactics…); attacker.CheckSkill(Anatomy…);
                       if (Type == WeaponType.Axe) attacker.CheckSkill(Lumberjacking, 0.0, 100.0); }

    // Tactics: 0.0 = 50% loss, 50.0 = unchanged, 100.0 = 50% bonus
    damage += (damage * ((attacker.Skills[Tactics].Value - 50.0) / 100.0));

    double modifiers = (attacker.Str / 5.0) / 100.0;               // +1% per 5 STR
    double anatomyValue = attacker.Skills[Anatomy].Value;
    modifiers += ((anatomyValue / 5.0) / 100.0);                   // +1% per 5 Anatomy
    if (anatomyValue >= 100.0) modifiers += 0.1;                   // +10% at GM Anatomy

    if (Type == WeaponType.Axe) {
        double lumberValue = attacker.Skills[Lumberjacking].Value;
        lumberValue = (lumberValue / 5.0) / 100.0;
        if (lumberValue > 0.2) lumberValue = 0.2;                  // capped at +20%
        modifiers += lumberValue;
        if (lumberValue >= 100.0) modifiers += 0.1;                // dead code as written (compare is on the scaled value)
    }

    if (m_Quality != ItemQuality.Normal) modifiers += (((int)m_Quality - 1) * 0.2);  // Low −20%, Exceptional +20%
    if (VirtualDamageBonus != 0) modifiers += (VirtualDamageBonus / 100.0);

    damage += (damage * modifiers);
    return ScaleDamageByDurability((int)damage);
}

public virtual int ComputeDamage(Mobile attacker, Mobile defender)
{
    if (Core.AOS) return ComputeDamageAOS(attacker, defender);
    int damage = (int)ScaleDamageOld(attacker, GetBaseDamage(attacker), true);
    // pre-AOS, halve damage if the defender is a player or the attacker is not a player
    if (defender is PlayerMobile || !(attacker is PlayerMobile)) damage = (int)(damage / 2.0);
    return damage;
}
```
**`[HIGH]`.** Consolidated:

```
base   = rand(MinDamage, MaxDamage) + (2 × damageLevel − 1)      // pre-AoS branch of GetBaseDamage
tactics_mult = (Tactics − 50) / 100                              // additive, NOT a multiplier
mods   = Str/500 + Anatomy/500 + (Anatomy ≥ 100 ? 0.10 : 0)
       + (Axe ? min(Lumberjacking/500, 0.20) : 0)
       + (Quality == Exceptional ? +0.20 : Quality == Low ? −0.20 : 0)
       + damageLevel_bonus/100                                   // Ruin +0.15 … Vanq +0.35  (GetDamageBonus, :3706-3748)
damage = (base + base × tactics_mult) × (1 + mods)
damage = ScaleDamageByDurability(damage)
damage = damage / 2                                              // if defender is a player, OR attacker is not a player
```

`GetDamageBonus()` for pre-AoS **`[HIGH]`** — `BaseWeapon.cs:3706-3748`:
`Low −20`, `Exceptional +20`, `Ruin +15`, `Might +20`, `Force +25`, `Power +30`, `Vanq +35` (percent).

**Durability scaling `[HIGH]`** — `BaseWeapon.cs:3902-3912`:
```csharp
int scale = 100;
if (m_MaxHits > 0 && m_Hits < m_MaxHits) scale = 50 + ((50 * m_Hits) / m_MaxHits);
return AOS.Scale(damage, scale);   // damage * scale / 100
```
i.e. a weapon at **0 % durability still does 50 % damage**; full durability = 100 %.

> **The classic "× strength/tactics/anatomy" phrasing in the brief is not a pure product.** Tactics enters as an *additive* term on the base, Anatomy as a percentage, STR as a percentage. Do not implement it as `base × f(STR) × f(Tactics) × f(Anatomy)`; that will over- or under-shoot.

### 1.7 Damage formula — AoS (Age of Shadows and later)

```csharp
// SU BaseWeapon.cs:3768-3823
public virtual double ScaleDamageAOS(Mobile attacker, double damage, bool checkSkills)
{
    if (checkSkills) { attacker.CheckSkill(Tactics…); attacker.CheckSkill(Anatomy…);
                       if (Type == WeaponType.Axe) attacker.CheckSkill(Lumberjacking, 0.0, 100.0); }

    // "Physical bonuses … No caps apply."
    double strengthBonus = GetBonus(attacker.Str,                        0.300, 100.0, 5.00);
    double anatomyBonus  = GetBonus(attacker.Skills[Anatomy].Value,      0.500, 100.0, 5.00);
    double tacticsBonus  = GetBonus(attacker.Skills[Tactics].Value,      0.625, 100.0, 6.25);
    double lumberBonus   = GetBonus(attacker.Skills[Lumberjacking].Value,0.200, 100.0, 10.00);
    if (Type != WeaponType.Axe) lumberBonus = 0.0;

    // "damage modifiers whose effect shows on the status bar. Capped at 100% total."
    int damageBonus = AosAttributes.GetValue(attacker, AosAttribute.WeaponDamage);
    if (damageBonus > 100) damageBonus = 100;

    double totalBonus = strengthBonus + anatomyBonus + tacticsBonus + lumberBonus
                      + ((GetDamageBonus() + damageBonus) / 100.0);

    return damage + (int)(damage * totalBonus);      // note: truncation of the bonus, not the result
}

public virtual int ComputeDamageAOS(Mobile attacker, Mobile defender)
{ return (int)ScaleDamageAOS(attacker, GetBaseDamage(attacker), true); }

// :3663-3673
public virtual double GetBonus(double value, double scalar, double threshold, double offset)
{
    double bonus = value * scalar;
    if (value >= threshold) bonus += offset;
    return bonus / 100;
}
```
**`[HIGH]`.** Consolidated:

```
b(v, s, t, o) = (v × s + (v ≥ t ? o : 0)) / 100
totalBonus = b(STR, 0.300, 100, 5.00)          // = STR×0.003  (+0.05 at STR ≥ 100)  → up to +35 % at STR 100
           + b(Anatomy, 0.500, 100, 5.00)      // = Anat×0.005  (+0.05 at 100)        → +50 % at GM
           + b(Tactics, 0.625, 100, 6.25)      // = Tact×0.00625(+0.0625 at 100)      → +62.5 % at GM
           + (Axe ? b(Lumberjacking, 0.200, 100, 10.00) : 0)   // +20 % at GM
           + (GetDamageBonus() + min(DI, 100)) / 100
damage = base + trunc(base × totalBonus)
```
| Term | Scalar | Threshold bonus | Value at 100 skill/stat | at 120 |
|---|---|---|---|---|
| Strength | ×0.300 → /100 | +5.00 at STR ≥ 100 | +35.0 % | n/a (stat cap) |
| Anatomy | ×0.500 → /100 | +5.00 at ≥ 100 | +55.0 % | +65.0 % |
| Tactics | ×0.625 → /100 | +6.25 at ≥ 100 | +68.75 % | +81.25 % |
| Lumberjacking (axes only) | ×0.200 → /100 | +10.00 at ≥ 100 | +30.0 % | +34.0 % (skill caps at 100 in the check at `:3779`) |
| Damage Increase property | — | — | capped at **100 %** | — |
| `GetDamageBonus()` (AoS branch) | — | — | **0** in AoS (the whole switch is inside `if (!Core.AOS)` — `:3715`) | — |

> **AoS has no player/non-player halving.** The `/2.0` in `ComputeDamage` is inside the `!Core.AOS` path only. **`[HIGH]`** — `BaseWeapon.cs:3916-3929`.

### 1.8 Resistance application (AoS) and the pre-AoS AR path

**AoS — `AOS.Damage` `[HIGH]`** — `Scripts/Misc/AOS.cs:99-217`:
```csharp
if (!Core.AOS) { if (m != null) m.Damage(damage, from); return damage; }   // classic: NO resistance at all

// damage split percentages are normalised by Fix() so they sum to 100
int physDamage   = damage * phys * (100 - damageable.PhysicalResistance);
int fireDamage   = damage * fire   * (100 - damageable.FireResistance);
int coldDamage   = damage * cold   * (100 - damageable.ColdResistance);
int poisonDamage = damage * pois   * (100 - damageable.PoisonResistance);
int energyDamage = damage * nrgy   * (100 - damageable.EnergyResistance);
totalDamage = physDamage + fireDamage + coldDamage + poisonDamage + energyDamage;
totalDamage /= 10000;
if (Core.ML) totalDamage += damage * direct / 100;               // "direct damage" bypasses resist
if (totalDamage < 1) totalDamage = 1;                            // minimum 1
```
```
final = trunc( Σ_e ( damage × share_e × (100 − resist_e) ) / 10000 )   , floored at 1
```
* `chaos` damage (Core.ML) is rolled into a random one of the five elements before the resistance maths. **`[HIGH]`** — `AOS.cs:138-158`.
* Unresistable (`ignoreArmor`) path caps at **35** (or **30** with `Core.TOL` and a ranged attack): `totalDamage = Math.Min(damage, Core.TOL && ranged ? 30 : 35);` **`[HIGH]`** — `AOS.cs:213`.
* There is also a separate player-damage cap: `if (!Core.TOL && totalDamage > 35 && from is PlayerMobile) …` **`[HIGH]`** — `AOS.cs:251`.

**Pre-AoS — AR vs hit location `[HIGH]`** — `BaseWeapon.cs:2014-2100`:
```
1. If defender has a shield:            damage = shield.OnHit(this, damage)
2. Roll chance = RandomDouble() and pick ONE armour piece:
      chance < 0.07  → NeckArmor    (7 %)
      chance < 0.14  → HandArmor    (7 %)
      chance < 0.28  → ArmsArmor    (14 %)
      chance < 0.43  → HeadArmor    (15 %)
      chance < 0.65  → LegsArmor    (22 %)
      else           → ChestArmor   (35 %)
   …then damage = armor.OnHit(this, damage)
3. virtualArmor = defender.ArmorRating
   scalar = 0.07 (neck/hands) | 0.14 (arms) | 0.15 (head) | 0.22 (legs) | 0.35 (chest)
   from = (int)(virtualArmor * scalar) / 2
   to   = (int)(virtualArmor * scalar)
   damage -= Utility.Random(from, (to - from) + 1)
```

And each individual piece (`BaseArmor.OnHit`, `Scripts/Items/Equipment/Armor/BaseArmor.cs:2591+`) **`[HIGH]`**:
```csharp
double HalfAr = ArmorRating / 2.0;
int Absorbed = (int)(HalfAr + HalfAr * Utility.RandomDouble());   // uniform in [AR/2, AR)
damageTaken -= Absorbed;  if (damageTaken < 0) damageTaken = 0;
if (Absorbed < 2) Absorbed = 2;
```

> **This is the pre-AoS AR model, and it is two overlapping mechanisms**: the picked-piece absorption, then the whole-body `ArmorRating` scalar roll. `ArmorRating` is `ArmorBase` scaled by material/quality/protection — see §3.5.

### 1.9 Hit chance

```csharp
// SU BaseWeapon.cs:1415-1539
public virtual bool CheckHit(Mobile attacker, IDamageable damageable)
{
    BaseWeapon atkWeapon = attacker.Weapon as BaseWeapon;
    BaseWeapon defWeapon = defender.Weapon  as BaseWeapon;   // the DEFENDER'S WEAPON supplies the defence skill!
    Skill atkSkill = attacker.Skills[atkWeapon.Skill];
    Skill defSkill = defender.Skills[defWeapon.Skill];
    double atkValue = atkWeapon.GetAttackSkillValue(attacker, defender);
    double defValue = defWeapon.GetDefendSkillValue(attacker, defender);
    int bonus = GetHitChanceBonus();

    if (Core.AOS) {
        if (atkValue <= -20.0) atkValue = -19.9;            // clamp, not floor-at-zero
        if (defValue <= -20.0) defValue = -19.9;
        bonus += AosAttributes.GetValue(attacker, AosAttribute.AttackChance);
        bonus = Math.Min(attacker.Race == Race.Gargoyle ? 50 : 45, bonus);   // HCI cap
        ourValue   = (atkValue + 20.0) * (100 + bonus);

        bonus = AosAttributes.GetValue(defender, AosAttribute.DefendChance);
        … ForceArrow malus …
        int max = 45 + BaseArmor.GetRefinedDefenseChance(defender);
        if (bonus > max) bonus = max;                        // DCI cap 45 (+ refinement)
        theirValue = (defValue + 20.0) * (100 + bonus);
        bonus = 0;
    } else {
        if (atkValue <= -50.0) atkValue = -49.9;
        if (defValue <= -50.0) defValue = -49.9;
        ourValue   = (atkValue + 50.0);
        theirValue = (defValue + 50.0);
    }

    double chance = ourValue / (theirValue * 2.0);
    chance *= 1.0 + ((double)bonus / 100);

    … Core.SA thrown-weapon close-quarters / shield maluses …

    if (Core.AOS && chance < 0.02) chance = 0.02;            // AoS floor 2 %
    if (Core.AOS && m_AosWeaponAttributes.MageWeapon > 0 && attacker.Skills[Magery].Value > atkSkill.Value)
        return attacker.CheckSkill(SkillName.Magery, chance);  // Mage Weapon swaps in Magery
    return attacker.CheckSkill(atkSkill.SkillName, chance);
}
```

**The two formulas, stated cleanly:**

| Era | Chance to hit |
|---|---|
| **Classic (pre-AoS)** | `chance = (atkSkill + 50) / (2 × (defSkill + 50))`, then `chance ×= 1 + hitChanceBonus/100`; no floor |
| **AoS+** | `chance = ((atkSkill + 20) × (100 + HCI)) / (2 × (defSkill + 20) × (100 + DCI))`; floor `0.02` |

Where:
* `atkSkill` = the attacker's **weapon skill** (Swords/Fencing/Macing/Archery/Wrestling/Throwing), **not** Tactics, **not** Anatomy. **Tactics is a damage skill, not an accuracy skill.** **`[HIGH]`** — this is a common misconception; the code is unambiguous.
* `defSkill` = **the defender's own weapon skill** — i.e. you defend with whatever you are holding. A mage holding nothing defends with **Wrestling** because `Fists.DefSkill == SkillName.Wrestling`. **`[HIGH]`**
* `GetAttackSkillValue`/`GetDefendSkillValue` (`:1400-1408`) call `GetUsedSkill(m, true)`, which is what implements `UseBestSkill` and `MageWeapon` selection.
* **Accuracy level** (classic weapon "accurate/surpassingly/…" prefixes) adds to `bonus` via `GetHitChanceBonus()` **`[HIGH]`** — `BaseWeapon.cs:3675-3704`:

| `WeaponAccuracyLevel` | bonus |
|---|---|
| Regular | 0 |
| Accurate | +2 |
| Surpassingly | +4 |
| Eminently | +6 |
| Exceedingly | +8 |
| Supremely | +10 |

* **`AttackChance` (HCI) cap = 45** for humans/elves, **50** for Gargoyles. **`[HIGH]`** — `BaseWeapon.cs:1451`.
* **`DefendChance` (DCI) cap = 45** (+ `BaseArmor.GetRefinedDefenseChance(defender)` for AoS "refinement"). **`[HIGH]`** — `BaseWeapon.cs:1462-1466`.
* `chance` is finally resolved by `Mobile.CheckSkill(skill, chance)` — the *skill check*, not a raw RNG compare. That means accuracy is also affected by skill-cap and stat bonuses. **`[HIGH]`**

### 1.10 Parry / blocking

```csharp
// SU BaseWeapon.cs:1756-1870
public static bool CheckParry(Mobile defender)
{
    BaseShield shield = defender.FindItemOnLayer(Layer.TwoHanded) as BaseShield;
    double parry  = defender.Skills[Parry].Value;
    double bushidoNonRacial = defender.Skills[Bushido].NonRacialValue;
    double bushido = defender.Skills[Bushido].Value;

    if (shield != null || !defender.Player)                 // ── SHIELD / NPC branch
    {
        double chance = (parry - bushidoNonRacial) / 400.0;
        if (chance < 0) chance = defender.Player ? 0 : .1;
        chance += HeightenedSensesSpell.GetParryBonus(defender);
        if (parry >= 100.0 || bushido >= 100.0) chance += 0.05;
        if (Evasion.IsEvading(defender)) chance *= Evasion.GetParryScalar(defender);
        if (defender.Player && defender.Dex < 80) chance = chance * (20 + defender.Dex) / 100;
        return defender.CheckSkill(SkillName.Parry, chance);
    }
    else if (!(defender.Weapon is Fists) && !(defender.Weapon is BaseRanged))   // ── TWO-HANDED WEAPON branch
    {
        BaseWeapon weapon = defender.Weapon as BaseWeapon;
        if (Core.HS && weapon.Attributes.BalancedWeapon > 0) return false;
        double divisor = (weapon.Layer == Layer.OneHanded && defender.Player) ? 48000.0 : 41140.0;
        double chance    = (parry * bushido) / divisor;
        double aosChance = parry / 800.0;
        if (parry >= 100.0)      { chance += 0.05; aosChance += 0.05; }
        else if (bushido >= 100.0) { chance += 0.05; }
        if (Evasion.IsEvading(defender)) chance *= Evasion.GetParryScalar(defender);
        if (defender.Dex < 80) chance = chance * (20 + defender.Dex) / 100;
        if (chance > aosChance) return defender.CheckSkill(SkillName.Parry, chance);
        else                    return (aosChance > Utility.RandomDouble());
    }
    return false;
}
```

| Situation | Parry chance | Era |
|---|---|---|
| Shield equipped, **or** NPC | `(Parry − Bushido_nonRacial) / 400` | AoS+ (this branch is AoS-only in practice) |
| …same, +5 % if `Parry ≥ 100` **or** `Bushido ≥ 100` | `+0.05` | |
| …same, low dexterity (players only) | `× (20 + Dex) / 100` when `Dex < 80` | |
| **Two-handed weapon, no shield** | `(Parry × Bushido) / 48000` (one-handed & player) or `/ 41140`; fallback pure-AoS `Parry / 800` when Bushido is low | ML |
| Non-player, no shield, chance < 0 | floored at `0.1` (NPCs always get 10 %) | |

* A successful parry sets `damage = 0` and plays effect `0x37B9`; with `Core.SA` it plays the parry animation. **`[HIGH]`** — `BaseWeapon.cs:1885-1893`.
* **Parry requires a free hand or a shield** — the `!defender.Player` / shield / two-handed-weapon gate means an unarmed or ranged defender **cannot parry at all** (`return false`). **`[HIGH]`**
* `AbsorbDamageAOS` only *attempts* a parry for `defender.Player || defender.Body.IsHuman || (controlled creature with Wrestling ≥ 100)`. **`[HIGH]`** — `BaseWeapon.cs:1878-1882`.
* Parry consumes shield durability: `shield.OnHit(this, damage)` after a successful block. **`[HIGH]`** — `:1927-1929`.
* **Pre-AoS parry is `[UNVERIFIED]` in this tree.** `CheckParry` is invoked only from `AbsorbDamageAOS`. In ServUO the classic path (which historically had *no* parry at all until UOR introduced it as a shield-only, `(Parry − 50)/…`-style skill) is not implemented. To settle: RunUO 1.0.0 `BaseWeapon.cs`, or a UOR-era shard measurement.

### 1.11 Wrestling and unarmed combat

* `Fists` is a first-class `BaseWeapon` (`Scripts/Items/Equipment/Weapons/Fists.cs`) with `DefSkill = Wrestling`. Unarmed attacks therefore run the *entire* normal weapon pipeline. **`[HIGH]`**
* Non-human creatures attacking unarmed roll `min = max = attacker.Str / 28`. **`[HIGH]`** — `BaseWeapon.cs:3616-3618`.
* A player under the necromancy **Horrific Beast** transformation rolls `min = 5, max = 15` regardless of weapon. **`[HIGH]`** — `BaseWeapon.cs:3622-3626`.
* Wrestle special moves cost **15 stamina** on the attacker: `attacker.Stam -= 15` at `Fists.cs:172`, `:228`, `:238`. **`[HIGH]`**
* The `ParalyzingBlow` ability has an explicit wrestle exception: `RequiresTactics(from) => Core.AOS && from.Weapon is not BaseWeapon { Skill: SkillName.Wrestling }`, and outside AoS it additionally requires **Anatomy ≥ 80** to use with fists. **`[HIGH]`** — `Projects/UOContent/Items/Weapons/Abilities/ParalyzingBlow.cs:20-44`.
* **Wrestling's own base damage table (`OldMinDamage`/`OldMaxDamage` on `Fists`) is `[UNVERIFIED]`** — `Fists.cs` does not override them; it inherits `BaseMeleeWeapon`/`BaseWeapon`, which return `0`. In practice `GetBaseDamageRange` routes creatures to their own table; for players the value depends on the era's `Mobile`/`Fists` initialisation not present in this file. To settle: read `Fists.cs` in full plus RunUO 1.0.0, or measure on a classic shard.

### 1.12 Archery

```csharp
// SU Scripts/Items/Equipment/Weapons/BaseRanged.cs:61-114, 185-224
public override TimeSpan OnSwing(Mobile attacker, IDamageable damageable)
{
    long nextShoot;
    if (attacker is PlayerMobile)
        nextShoot = ((PlayerMobile)attacker).NextMovementTime + (Core.SE ? 250 : Core.AOS ? 500 : 1000);
    else
        nextShoot = attacker.LastMoveTime + attacker.ComputeMovementSpeed();

    // Make sure we've been standing still for .25/.5/1 second depending on Era
    if (nextShoot <= Core.TickCount || (Core.AOS && WeaponAbility.GetCurrentAbility(attacker) is MovingShot))
    { … CheckHit → OnHit / OnMiss … return GetDelay(attacker); }

    attacker.RevealingAction();
    return TimeSpan.FromSeconds(0.25);        // ← the retry poll when you are still moving
}
```

**Movement penalty — `[HIGH]`, exact constants:**

| Era | Time you must have stood still before a shot |
|---|---|
| Classic (pre-AoS) | **1000 ms** |
| AoS | **500 ms** |
| SE and later | **250 ms** |

While moving, the swing attempt returns `TimeSpan.FromSeconds(0.25)` and consumes nothing.

**Ammunition `[HIGH]`** — `BaseRanged.OnFired` / `OnHit` / `OnMiss`:
```csharp
// OnFired: ammo is consumed EVERY shot that fires, before hit resolution
WeaponAbility ability = WeaponAbility.GetCurrentAbility(attacker);
if (ability != null && ability.ConsumeAmmo == false) return true;        // e.g. DoubleShot
BaseQuiver quiver = attacker.FindItemOnLayer(Layer.Cloak) as BaseQuiver;
int lowerAmmo = AosAttributes.GetValue(attacker, AosAttribute.LowerAmmoCost);
if (quiver == null || Utility.Random(100) >= lowerAmmo) {
    if (quiver != null && quiver.ConsumeTotal(AmmoType, 1)) quiver.InvalidateWeight();
    else if (pack == null || !pack.ConsumeTotal(AmmoType, 1)) return false;   // out of ammo → no shot
} else if (quiver.FindItemByType(AmmoType) == null && (pack == null || pack.FindItemByType(AmmoType) == null)) {
    return false;   // "lower ammo cost should not work when we have no ammo at all"
}
```
* **Ammo is consumed on every fired shot, hit or miss** — not only on hit. **`[HIGH]`**
* **Ammo recovery on hit vs monsters/animals:** `if (AmmoType != null && attacker.Player && damageable is Mobile && !((Mobile)damageable).Player && (Body.IsAnimal || Body.IsMonster) && 0.4 >= Utility.RandomDouble())` → the arrow/bolt is placed in the victim's backpack (lootable). **40 % recovery `[HIGH]`** — `BaseRanged.cs:116-131`.
* Ammo landing on the ground on a miss: same 40 % roll, item dropped within ±1 tile. **`[HIGH]`** — `:132-182`.

**Range `[HIGH]`** — extracted from `DefMaxRange` overrides:

| Weapon | Range (tiles) | Ammo type | Projectile effect ID |
|---|---|---|---|
| Bow | 10 | Arrow | `0xF42` |
| Composite Bow | 10 | Arrow | `0xF42` |
| Elven Composite Longbow | 10 | Arrow | `0xF42` |
| Magical Shortbow | 10 | Arrow | `0xF42` |
| Yumi | 10 | Arrow | `0xF42` |
| Crossbow | 8 | Bolt | `0x1BFE` |
| Heavy Crossbow | 8 | Bolt | `0x1BFE` |
| Repeating Crossbow | 7 | Bolt | `0x1BFE` |
| All melee / thrown (default) | 1 (`BaseWeapon.DefMaxRange`) | — | — |

Thrown weapons (`BaseThrown`) override `DefMaxRange` too and have an additional `MinThrowRange` used for the SE close-quarters malus (`BaseWeapon.cs:1494-1527`). **`[HIGH]`**

### 1.13 Special moves (`WeaponAbility`) — **AoS era onwards only**

There are **no special moves before AoS.** The base class is `Scripts/Spells/Base/SpecialMove.cs` (legacy SE path) and `Scripts/Items/Weapons/Abilities/WeaponAbility.cs` (modern path). ModernUO's canonical list is the authoritative enumeration. **`[HIGH]`** — `Projects/UOContent/Items/Weapons/Abilities/WeaponAbility.cs:14-78`.

**Skill requirement: 70.0 for the weapon's primary ability, 90.0 for secondary.** **`[HIGH]`**
```csharp
public virtual double GetRequiredSkill(Mobile from) {
    if (from.Weapon is BaseWeapon weapon) {
        if (weapon.PrimaryAbility   == this || weapon.PrimaryAbility   == Bladeweave) return 70.0;
        if (weapon.SecondaryAbility == this || weapon.SecondaryAbility == Bladeweave) return 90.0;
    }
    return 200.0;   // not available on this weapon at all
}
```
`RequiresTactics(from)` defaults to **true** — so most abilities need Tactics as a second skill gate. **`[HIGH]`**

| # | Ability | Mana | Accuracy bonus | Damage scalar | Era gate | Effect |
|---|---|---|---|---|---|---|
| 1 | ArmorIgnore | **30** | 0 | **0.9** | AoS | Ignores target's armour resistance for the hit |
| 2 | BleedAttack | **30** | 0 | 1.0 | AoS | Bleed DoT, 5 ticks at 2 s intervals, damage `RandomMinMax(level, level×2)` where `level` starts at 5 and decreases; ×2 vs non-players; bandages stop it |
| 3 | ConcussionBlow | **25** | 0 | 1.0 | AoS | Drains target mana = 50 % of damage dealt |
| 4 | CrushingBlow | **25** | 0 | **1.5** | AoS | +50 % damage, reduced durability damage to target armour |
| 5 | Disarm | **20** | 0 | 1.0 | AoS | Knocks the target's weapon to the ground/backpack |
| 6 | Dismount | **20** | 0 | 1.0 | AoS | Knocks the target off its mount |
| 7 | DoubleStrike | **30** | 0 | **0.9** | AoS | Two hit rolls at 90 % damage each |
| 8 | InfectiousStrike | **30** | 0 | 1.0 | AoS | Applies the weapon's poison |
| 9 | MortalStrike | **30** | 0 | 1.0 | AoS | Blocks healing ("mortal wounded") for a duration |
| 10 | MovingShot | **30** | 0 | 1.0 | AoS | Fires while moving (bypasses the stand-still gate) |
| 11 | ParalyzingBlow | **30** | 0 | 1.0 | AoS | Freeze: **3 s vs players, 6 s vs NPCs**; then **8 s immunity + duration** before it can land again |
| 12 | ShadowStrike | **20** | 0 | 1.0 | AoS | Stealth attack; hides the attacker, big damage from stealth |
| 13 | WhirlwindAttack | **30** | 0 | 1.0 | AoS | Hits every valid target in a radius |
| 14 | RidingSwipe | **30** | 0 | 1.0 | SE | Mounted-only AoE |
| 15 | FrenziedWhirlwind | **30** | 0 | 1.0 | SE | Ninjitsu whirlwind |
| 16 | Block | **30** | 0 | 1.0 | SE | Chance to block incoming attacks for a duration |
| 17 | DefenseMastery | **30** | 0 | 1.0 | SE | Parry/defence buff |
| 18 | NerveStrike | **30** | 0 | 1.0 | SE | Paralyzes the target |
| 19 | TalonStrike | **30** | 0 | 1.0 | SE | Bleed + paralyze |
| 20 | Feint | **30** | 0 | 1.0 | SE | Lowers target's defence skill |
| 21 | DualWield | **30** | 0 | 1.0 | SE | Extra off-hand attacks |
| 22 | DoubleShot | **30** | 0 | 1.0 | SE | Two arrows; **`ConsumeAmmo == false`** |
| 23 | ArmorPierce | **30** | 0 | **1.5** | SE | +50 % damage, ignores part of the armour |
| 24 | Bladeweave | **30** | 0 | 1.0 | ML | Random effect (bleed/concussion/paralyze/…) |
| 25 | ForceArrow | **30** | 0 | 1.0 | ML | Big accuracy buff, applies a DCI malus to the target |
| 26 | LightningArrow | **30** | 0 | 1.0 | ML | Energy damage bolt |
| 27 | PsychicAttack | **30** | 0 | 1.0 | ML | Mana drain |
| 28 | SerpentArrow | **30** | 0 | 1.0 | ML | Poisons the target |
| 29 | ForceOfNature | **30** | 0 | 1.0 | ML | Damage bonus scaling with the attacker's Bushido/weapon |
| 30 | InfusedThrow | **30** | 0 | 1.0 | SA | Thrown |
| 31 | MysticArc | **30** | 0 | 1.0 | SA | Thrown |

Mana costs were extracted mechanically from every file in `Projects/UOContent/Items/Weapons/Abilities/` and are **`[HIGH]`**.

**Special-move mana scaling `[HIGH]`** — `Scripts/Spells/Base/SpecialMove.cs:129-166`:
```csharp
int lmc = Math.Min(AosAttributes.GetValue(m, AosAttribute.LowerManaCost), 40);   // LMC cap 40 %
lmc += BaseArmor.GetInherentLowerManaCost(m);
scalar -= (double)lmc / 100;
int total = (int)(mana * scalar);
if (m.Skills[this.MoveSkill].Value < 50.0 && GetContext(m) != null) total *= 2;  // 2× cost below 50 skill
```
Failure to pay gives message `1060181` ("You need ~1_MANA_REQUIREMENT~ mana to perform that attack").

**Failure to meet the skill gate** gives `1063013` ("You need at least ~1_SKILL_REQUIREMENT~ ~2_SKILL_NAME~ skill to use that ability") — `RequiredSkill` interpolated with one decimal. **`[HIGH]`** — `SpecialMove.cs`.

### 1.14 Poison and poisoning

**The poison definition table `[HIGH]`** — `Scripts/Misc/Poison.cs:19-53`. Constructor argument order is `(name, level, min, max, percent, delay, interval, count, messageInterval)`; `m_Scalar = percent * 0.01`. Two completely different tables by era:

**AoS and later (`Core.AOS`):**

| Poison | Level | Actual per-tick damage | `Scalar` | First tick delay | Tick interval | Ticks | Msg interval |
|---|---|---|---|---|---|---|---|
| Lesser | 0 | `clamp(1 + Hits×0.075, 4, 16)` | 0.075 | 3.0 s | 2.25 s | 10 | 4 |
| Regular | 1 | `clamp(1 + Hits×0.10, 8, 18)` | 0.100 | 3.0 s | 3.25 s | 10 | 3 |
| Greater | 2 | `clamp(1 + Hits×0.15, 12, 20)` | 0.150 | 3.0 s | 4.25 s | 10 | 2 |
| Deadly | 3 | `clamp(1 + Hits×0.30, 16, 30)` | 0.300 | 3.0 s | 5.25 s | 15 | 2 |
| Lethal | 4 | `clamp(1 + Hits×0.35, 20, 50)` | 0.350 | 3.0 s | 5.25 s | 20 | 2 |

**Classic (pre-AoS):**

| Poison | Level | Actual per-tick damage | `Scalar` | First tick delay | Tick interval | Ticks |
|---|---|---|---|---|---|---|
| Lesser | 0 | `clamp(1 + Hits×0.025, 4, 26)` | 0.025 | 3.5 s | 3.0 s | 10 |
| Regular | 1 | `clamp(1 + Hits×0.03125, 5, 26)` | 0.03125 | 3.5 s | 3.0 s | 10 |
| Greater | 2 | `clamp(1 + Hits×0.0625, 6, 26)` | 0.0625 | 3.5 s | 3.0 s | 10 |
| Deadly | 3 | `clamp(1 + Hits×0.125, 7, 26)` | 0.125 | 3.5 s | 4.0 s | 10 |
| Lethal | 4 | `clamp(1 + Hits×0.25, 9, 26)` | 0.250 | 3.5 s | 5.0 s | 10 |

The tick body **`[HIGH]`** — `Poison.cs:175-281`:
```csharp
if (m_Index++ == m_Poison.m_Count) { … "The poison seems to have worn off." … m_Mobile.Poison = null; Stop(); return; }
int damage;
if (!Core.AOS && m_LastDamage != 0 && Utility.RandomBool()) {   // CLASSIC ONLY: 50 % chance to repeat last tick
    damage = m_LastDamage;
} else {
    damage = 1 + (int)(m_Mobile.Hits * m_Poison.m_Scalar);
    if (damage < m_Poison.m_Minimum) damage = m_Poison.m_Minimum;
    else if (damage > m_Poison.m_Maximum) damage = m_Poison.m_Maximum;
    m_LastDamage = damage;
}
… AOS.Damage(m_Mobile, m_From, damage, 0, 0, 0, 100, 0);       // 100 % POISON damage → poison resistance applies
```
* Damage scales with the victim's **current** hits, so poison is proportionally brutal on high-HP targets and capped on low-HP ones. **`[HIGH]`**
* **Total poison duration = `count × interval`** (the timer period is `interval`, `OnTick` runs `count` times then clears). Lesser AoS: 10 × 2.25 = **22.5 s**. **`[HIGH]`**
* Poison damage goes through `AOS.Damage` with `pois = 100`, so **AoS poison resistance reduces it**; in classic `AOS.Damage` returns early and no resistance applies. **`[HIGH]`**
* Mondain's Legacy adds **Darkglow** (levels 10–13, +10 % damage when the poisoner is out of melee range) and **Parasitic** (levels 14–18, heals the poisoner for the damage dealt while in melee range). **`[HIGH]`** — `Poison.cs:249-269`.

**Applying poison to a weapon `[HIGH]`** — `Scripts/Skills/Poisoning.cs:95-168`:
```csharp
// 2-second delay, then:
if (m_From.CheckTargetSkill(SkillName.Poisoning, m_Target, m_MinSkill, m_MaxSkill)) {
    weapon.Poison = m_Poison;
    weapon.PoisonCharges = 18 - (m_Poison.RealLevel * 2);       // Lesser 18, Regular 16, Greater 14, Deadly 12, Lethal 10
} else {
    // "5% of chance of getting poisoned if failed"
    if (m_From.Skills[Poisoning].Base < 80.0 && Utility.Random(20) == 0) m_From.ApplyPoison(m_From, m_Poison);
}
// Karma: AwardKarma(m_From, -20, true)
```
Skill-use cooldown after targeting the poison: **`TimeSpan.FromSeconds(10.0)`**. Target range **2**. **`[HIGH]`**

Which items can be poisoned **`[HIGH]`** — `Poisoning.cs:59-92`:

| Era | Allowed targets |
|---|---|
| Classic | `Food`, `FukiyaDarts`, `Shuriken`, and `BaseWeapon` with `Layer == Layer.OneHanded` **and** `Type == Slashing or Piercing` |
| AoS+ | `Food`, `FukiyaDarts`, `Shuriken`, and any `BaseWeapon` whose **Primary or Secondary ability is `InfectiousStrike`** |

**Poison potion skill windows `[HIGH]`** — extracted from `Scripts/Items/Consumables/*PoisonPotion.cs`:

| Potion | `Poison` | `MinPoisoningSkill` | `MaxPoisoningSkill` |
|---|---|---|---|
| Lesser Poison Potion | `Poison.Lesser` | 0.0 | 60.0 |
| Poison Potion | `Poison.Regular` | 30.0 | 70.0 |
| Greater Poison Potion | `Poison.Greater` | 60.0 | 100.0 |
| Deadly Poison Potion | `Poison.Deadly` | 80.0 | 100.0 |

**On-hit poison delivery `[HIGH]`** — `Scripts/Items/Equipment/Weapons/BaseSword.cs:60-71` (the pattern for bladed weapons, **classic only**):
```csharp
if (!Core.AOS && this.Poison != null && this.PoisonCharges > 0 && damageable is Mobile) {
    --this.PoisonCharges;
    if (Utility.RandomDouble() >= 0.5)          // 50 % chance to poison
        ((Mobile)damageable).ApplyPoison(attacker, this.Poison);
}
```
**50 % chance per hit, one charge consumed per hit regardless of whether the poison lands.** In AoS+ this path is replaced by the `InfectiousStrike` special move.

**Curing `[HIGH]`** — `Scripts/Items/Resource/Bandage.cs:437-463` and `SpellHelper`: the `Cure`/`ArchCure` spells and cure potions call `Mobile.CurePoison`; the bandage cure chance is
```
chance = ((Healing − 30.0) / 50.0) − (Poison.RealLevel × 0.1) − (m_Slips × 0.02)
// only attempted if healing >= 60.0 && anatomy >= 60.0
```
Vampiric Embrace grants immunity to poison of `RealLevel < 4`; Orange Petals grant immunity at `RealLevel <= 3` (25 % chance per tick for SA to shatter the petals against level ≥ 3). **`[HIGH]`** — `Poison.cs:177-200`.

### 1.15 Bandage healing, Veterinary, and resurrection

**Primary / secondary skill selection `[HIGH]`** — `Bandage.cs:242-274`:

| Patient | Primary skill | Secondary skill |
|---|---|---|
| Player or humanoid | `Healing` | `Anatomy` |
| Animal or monster (`!Player && (Body.IsAnimal \|\| Body.IsMonster)`) | **`Veterinary`** | **`AnimalLore`** |
| `DespiseCreature` | whichever of Healing/Veterinary is higher | whichever of Anatomy/AnimalLore is higher |

**Bandage delay `[HIGH]`** — `Bandage.cs:708-761`:
```csharp
var resDelay = dead ? 5.0 : 0.0;
var dex = healer.Dex;
double seconds;
if (healer == patient) {                                  // self-heal
    if (Core.AOS) { seconds = Math.Min(8, Math.Ceiling(11.0 - dex / 20)); seconds = Math.Max(seconds, 4); }
    else            seconds = 9.4 + (0.6 * ((double)(120 - dex) / 10));
}
else if (Core.AOS && skill == SkillName.Veterinary) seconds = 2.0;      // veterinary is a flat 2 s
else if (Core.AOS) { seconds = Math.Ceiling((double)4 - dex / 60); seconds = Math.Max(seconds, 2); }
else if (dex >= 100) seconds = 3.0 + resDelay;
else if (dex >=  40) seconds = 4.0 + resDelay;
else                 seconds = 5.0 + resDelay;
return TimeSpan.FromSeconds(seconds);
```

| Case | Era | Delay |
|---|---|---|
| Self-heal | AoS | `clamp(ceil(11 − Dex/20), 4, 8)` seconds |
| Self-heal | Classic | `9.4 + 0.6 × (120 − Dex)/10` seconds |
| Heal another | AoS | `max(ceil(4 − Dex/60), 2)` seconds |
| **Veterinary** | AoS | **flat 2.0 seconds** |
| Heal another | Classic | 3.0 s (Dex ≥ 100) / 4.0 s (Dex ≥ 40) / 5.0 s |
| Resurrection | adds `+5.0 s` in the classic branch (`resDelay`) | — |

The bandage ticker runs at a **250 ms** cadence (`new InternalTimer(context, delay) : base(TimeSpan.FromMilliseconds(250), …)`) and counts down — so the delay is what you feel, and moving out of range cancels the heal (`Bandage.Range`). **`[HIGH]`** — `Bandage.cs:600-620`, `:333`.

**Heal success roll `[HIGH]`** — `Bandage.cs:503-505`:
```csharp
double chance = ((healing + 10.0) / 100.0) - (m_Slips * 0.02);
if (chance > Utility.RandomDouble()) { /* success */ } else { /* "barely help" */ }
```
`m_Slips` is a per-context counter incremented when the healer is disturbed. Note `healing` here has already had `m_HealingBonus` added (first-aid belt, Asclepius +15).

**Heal amount `[HIGH]`** — `Bandage.cs:509-564`:
```csharp
double min, max;
if (Core.AOS) {
    min = (anatomy / 8.0) + (healing / 5.0) + 4.0;
    max = (anatomy / 6.0) + (healing / 2.5) + 4.0;
} else {
    min = (anatomy / 5.0) + (healing / 5.0) + 3.0;
    max = (anatomy / 5.0) + (healing / 2.0) + 10.0;
}
double toHeal = min + (Utility.RandomDouble() * (max - min));
if (m_Patient.Body.IsMonster || m_Patient.Body.IsAnimal) toHeal += m_Patient.HitsMax / 100;   // pets heal % of max HP extra
if (Core.AOS) toHeal -= toHeal * m_Slips * 0.35;      // TODO: Verify algorithm   ← source's own caveat
else          toHeal -= m_Slips * 4;
if (toHeal < 1) { toHeal = 1; /* "you apply the bandages, but they barely help" */ }
m_Patient.Heal((int)toHeal, m_Healer, false);
```

| Era | min | max |
|---|---|---|
| **AoS** | `Anatomy/8 + Healing/5 + 4` | `Anatomy/6 + Healing/2.5 + 4` |
| **Classic** | `Anatomy/5 + Healing/5 + 3` | `Anatomy/5 + Healing/2 + 10` |

At **100 Anatomy / 100 Healing**: AoS → `12.5 + 20 + 4 = 36.5` min, `16.67 + 40 + 4 = 60.67` max. Classic → `20 + 20 + 3 = 43` min, `20 + 50 + 10 = 80` max. **`[MED]`** (formula `[HIGH]`; the resulting numbers are arithmetic).

> The AoS "slips" penalty `toHeal -= toHeal * m_Slips * 0.35` carries the source's own `// TODO: Verify algorithm` comment. Treat it as **`[LOW]`**.

**Cure-poison-on-bandage `[HIGH]`** — `Bandage.cs:441-445`:
```csharp
double chance = ((healing - 30.0) / 50.0) - (m_Patient.Poison.RealLevel * 0.1) - (m_Slips * 0.02);
if ((checkSkills = (healing >= 60.0 && anatomy >= 60.0)) && chance > Utility.RandomDouble()) { /* cured */ }
```
**The gate is Healing ≥ 60 AND Anatomy ≥ 60** in this codebase (message `1010060` "You have failed to cure your target!" on failure). The widely-quoted "60 Healing for lesser, 80 for deadly" is **not** how this code works — there is a single 60/60 gate with a level-scaled chance. **`[HIGH]`** for the code, **`[LOW]`** for whether OSI matched it.

**Bleed / mortal-wound handling in the same flow `[HIGH]`** — `:464-476`: bleeding is stopped by bandages unconditionally (`BleedAttack.EndBleed`), and `MortalStrike.IsWounded` patients **cannot be healed at all**.

**Resurrection with bandages `[HIGH]`** — `Bandage.cs:339-435`:
```csharp
double healing = m_Healer.Skills[primarySkill].Value;
double anatomy = m_Healer.Skills[secondarySkill].Value;
double chance = ((healing - 68.0) / 50.0) - (m_Slips * 0.02);
checkSkills = (healing >= 80.0 && anatomy >= 80.0);
if (checkSkills && chance > Utility.RandomDouble()) { /* resurrect gump */ }
```
**Requires Healing ≥ 80 and Anatomy ≥ 80 to even attempt, and the success chance is `(Healing − 68)/50`.** **`[HIGH]`**
Pets get `PetResurrectGump`; the resurrection is refused inside Khaldun (region check) and where the tile cannot fit 16 items.

**Veterinary differences, summarised `[HIGH]`:**
1. Uses `Veterinary` + `AnimalLore` instead of `Healing` + `Anatomy`.
2. **Flat 2.0-second delay** under AoS (the fastest bandage action in the game).
3. Target must be a non-player with `Body.IsAnimal || Body.IsMonster`.
4. Successful pet heals get the `+ HitsMax/100` bonus.
5. On a *dead* bonded pet the same 80/80-style gate applies via the generic primary/secondary skill lookup.

**Bandage item `[HIGH]`** — `Scripts/Items/Resource/Bandage.cs`: `Bandage` is `IDyable, ICommodity`, `public static readonly int Range` bounds reach; bandages are stackable consumables. The enhanced-bandage bonus adds to `m_HealingBonus` (`EnhancedBandage.HealingBonus`).

### 1.16 Durability loss and repair

**Weapon durability loss on hit `[HIGH]`** — `BaseWeapon.cs:2310-2354`:
```csharp
double chance = NegativeAttributes.Antique > 0 ? 5 : 0;
bool acidicTarget = MaxRange <= 1 && m_AosAttributes.SpellChanneling == 0 && !(this is Fists)
                    && (defender is Slime || defender is ToxicElemental || defender is CorrosiveSlime);
if (acidicTarget || (defender != null && splintering) || Utility.Random(40) <= chance) {
    int selfRepair = !Core.AOS ? 0 : m_AosWeaponAttributes.SelfRepair + (IsSetItem && m_SetEquipped ? m_SetSelfRepair : 0);
    if (selfRepair > 0 && NextSelfRepair < DateTime.UtcNow) {
        HitPoints += selfRepair;
        NextSelfRepair = DateTime.UtcNow + TimeSpan.FromSeconds(60);
    } else if (m_MaxHits > 0) {
        if (m_Hits >= 1) { if (splintering) HitPoints = Math.Max(0, HitPoints - 10); else HitPoints--; }
        else if (m_MaxHits > 0) { MaxHitPoints--; … if (m_MaxHits <= 0) Delete(); }
    }
}
```
* **Base weapon wear: 1 point when `Random(40) == 0` → 2.5 % of swings.** **`[HIGH]`**
* `Antique` raises it to `Random(40) <= 5` → **15 %**. **`[HIGH]`**
* Acidic-slime blood destroys weapons unconditionally on hit; SplinteringWeapon costs 10 points. **`[HIGH]`**
* Once `Hits` reaches 0, further wear eats `MaxHitPoints`; when max hits reaches 0 the item is **deleted**. **`[HIGH]`**

**Armour durability loss on being hit `[HIGH]`** — `BaseArmor.cs:2591-2660`:
```csharp
double chance = NegativeAttributes.Antique > 0 ? 80 : 25;
if (chance >= Utility.Random(100)) {                     // 25 % base chance
    int wear = 1;
    if (weapon.Type == WeaponType.Bashing) wear = Absorbed / 2;
    … HitPoints -= wear; if exhausted, MaxHitPoints -= wear; "Your equipment is severely damaged." (1061121) …
}
```
* **25 % base, 80 % with Antique.** **`[HIGH]`**
* **Macing (bashing) weapons wear armour by `Absorbed / 2`, not 1.** **`[HIGH]`**

**Self Repair `[HIGH]`:** each point restores 1 durability, but only once per **60 seconds** per item (`NextSelfRepair`). Applies to both weapons and armour, and set items add `m_SetSelfRepair`.

**Durability scaling by property / material `[HIGH]`** — `BaseArmor.cs:1345-1399` (weapon mirror in `BaseWeapon.cs`):
```csharp
public void ScaleDurability() {
    int scale = 100 + GetDurabilityBonus();
    m_HitPoints    = ((m_HitPoints    * scale) + 99) / 100;
    m_MaxHitPoints = ((m_MaxHitPoints * scale) + 99) / 100;
    if (m_MaxHitPoints > 255) m_MaxHitPoints = 255;      // HARD CAP 255
    if (m_HitPoints    > 255) m_HitPoints    = 255;
}
public virtual int GetDurabilityBonus() {
    int bonus = 0;
    if (m_Quality == ItemQuality.Exceptional && !(this is GargishLeatherWingArmor)) bonus += 20;
    switch (m_Durability) {
        case ArmorDurabilityLevel.Durable:      bonus += 20; break;
        case ArmorDurabilityLevel.Substantial:  bonus += 50; break;
        case ArmorDurabilityLevel.Massive:      bonus += 70; break;
        case ArmorDurabilityLevel.Fortified:    bonus += …;  break;   // continues below the excerpt
        case ArmorDurabilityLevel.Indestructible: bonus += …; break;
    }
    bonus += m_AosArmorAttributes.DurabilityBonus;      // the AoS "Durability +N%" property
    return bonus;
}
```
**Exceptional quality = +20 % durability, hard-capped at 255.** **`[HIGH]`** for Exceptional/+20/255; the `Fortified`/`Indestructible` values were past the excerpt boundary — **`[UNVERIFIED]`**, read `BaseArmor.cs:1389-1400` to complete the table.

**Initial durability `[HIGH]`:** `m_HitPoints = m_MaxHitPoints = Utility.RandomMinMax(InitMinHits, InitMaxHits);` — `BaseArmor.cs:2371`, and the same for weapons at `BaseWeapon.cs:5148, 5183`.

**Repair — `[UNVERIFIED]`.** A `RepairSkill`/repair-deed path exists in ServUO (`Scripts/Services/Craft/…`), but the tree also implements repair through the crafting system's `CraftItem` repair branch whose specific "cannot repair above X" rules I did not read line-by-line. To settle: read the repair branch in `Scripts/Services/Craft/Core/CraftItem.cs` and `Scripts/Items/Tools/RepairDeed.cs`.

### 1.17 Death and corpse creation

**`Mobile.Kill()` `[HIGH]`** — `Server/Mobile.cs:3975-4094+`. Sequence:
1. `m_LastKilled = DateTime.UtcNow;`
2. Bail-outs: `!CanBeDamaged()`, already `!Alive || IsDeadBondedPet`, `m_Deleted`, `!Region.OnBeforeDeath(this)`, `!OnBeforeDeath()`.
3. Close the bank box if open; cancel all trades; `m_Spell.OnCasterKilled()`; cancel the current target; `DisruptiveAction()`.
4. **`Warmode = false`**, `DropHolding()`, `Hits = 0; Stam = 0; Mana = 0;`, `Poison = null; Combatant = null;`, clear paralyze and freeze timers.
5. Partition items into three buckets:
   * **`equip`** — items that are `Insured || LootType == LootType.Blessed` and equipped on a non-`Layer.Mount` layer → **stay on the corpse as "restore equip"** (returned to the player on resurrection).
   * **`content`** — `DeathMoveResult.MoveToCorpse` → dropped into the corpse.
   * **`moveToPack`** — `DeathMoveResult.MoveToBackpack` → stays in the backpack.
6. A `Corpse` is created and receives `content` + `equip`.

**Corpse item `[HIGH]`** — `Scripts/Items/Corpses/Corpse.cs`:
```csharp
public class Corpse : Container, ICarvable
private static readonly TimeSpan m_DefaultDecayTime = TimeSpan.FromMinutes(7.0);
private static readonly TimeSpan m_BoneDecayTime    = TimeSpan.FromMinutes(7.0);
public static readonly TimeSpan MonsterLootRightSacrifice = TimeSpan.FromMinutes(2.0);
public static readonly TimeSpan InstancedCorpseTime       = TimeSpan.FromMinutes(3.0);
BeginDecay(m_BoneDecayTime);   // called from the ctor path
```
* **Player/corpse decay: 7 minutes; bones decay: a further 7 minutes (≈14 minutes total).** **`[HIGH]`**
* `MonsterLootRightSacrifice = 2 min` — how long a monster corpse's loot rights persist.
* Instanced corpses last **3 minutes**.
* `LootType.Cursed` items belong to everyone's instanced corpse. **`[HIGH]`** — `Corpse.cs:155`.

**Death robe and stat/skill loss — `[UNVERIFIED]`.** `DeathRobe` exists as an item and `ResurrectGump` offers resurrection, but the specific stat-loss/skill-loss-on-resurrection numbers and the criminal/murder-count flagging rules were not read. To settle: `Scripts/Mobiles/PlayerMobile.cs` (`CheckStatTimers`, the death/rez handlers), `Scripts/Items/Clothing/DeathRobe.cs`, and `Scripts/Misc/NotorietyHandlers.cs` / `MurderCount`.

### 1.18 Macing stamina drain

**`[HIGH]`** — `Scripts/Items/Equipment/Weapons/BaseBashing.cs:71` and `BaseStaff.cs:71`, identical lines:
```csharp
((Mobile)defender).Stam -= Utility.Random(3, 3);   // 3-5 points of stamina loss
```
`Utility.Random(3, 3)` yields **3, 4 or 5** — so maces and staves drain **3–5 stamina per hit** from the defender, on top of damage. This is the only weapon-class stamina-drain mechanic implemented. It is plausible but **not proven** to be the classic OSI formula — **`[MED]`**.

The `HitFatigue` AoS property additionally drains stamina: `defender.Stam -= (damagegiven * (100 - m_AosWeaponAttributes.HitFatigue)) / 100;` **`[HIGH]`** — `BaseWeapon.cs:3281`.

---

## 2. WEAPON CATALOGUE

### 2.1 How to read the table

Every row is generated mechanically from ServUO `pub57` source by parsing `Scripts/Items/Equipment/Weapons/*.cs`. **No value is transcribed by hand and none is invented.** Where a source value is a `Core.ML ? a : b` ternary the table shows the **pre-ML / AoS** value; check the per-file source for the ML variant.

**Legend**
* **ItemID** — the item id passed to the base constructor (`base(0x…)`), i.e. the *art id* / tiledata id of the base graphic. `?` = the class constructs itself differently (e.g. from a weapon-type table).
* **Range** — `DefMaxRange`; `1` means melee.
* **AoS dmg** — `AosMinDamage`–`AosMaxDamage` (used when `Core.AOS`).
* **AoS spd** — `AosSpeed`, an integer where **higher = faster**; it is a *divisor* in the delay formula, not a delay.
* **ML spd** — `MlSpeed`, a float in **seconds** where **lower = faster**; used when `Core.ML`.
* **Old dmg / Old spd** — the classic pre-AoS values.
* **StrReq AoS/old** — the two strength requirements.
* **Dur** — `InitMinHits`–`InitMaxHits`; actual durability is `RandomMinMax(InitMinHits, InitMaxHits)`.
* **Ability 1 / 2** — `PrimaryAbility` / `SecondaryAbility`. **Both are AoS+ only**; in classic they are inert.

**Layer:** ServUO **does not declare `Layer` in any weapon or armour file.** The layer is assigned from the client's `tiledata.mul` via `Layer = (Layer)ItemData.Quality;` (`BaseArmor.cs:2373`). Therefore **per-item layer is not extractable from server source** and the table omits it. The engine enum is `Server/Item.cs`:
`OneHanded = 0x01`, `TwoHanded = 0x02` (weapons **and shields**), `Shoes = 0x03`, `Pants = 0x04`, `Shirt = 0x05`, `Helm = 0x06`, `Gloves = 0x07`, `Ring`, `Talisman`, `Neck`, `Waist`, `InnerTorso`, `Bracelet`, `MiddleTorso`, `Earrings`, `Cloak`, `OuterTorso`, `OuterLegs`, `InnerLegs`. **`[HIGH]`** for the enum; **`[UNVERIFIED]` for the per-item layer mapping** — to settle, dump `tiledata.mul` (the ClassicUO client exposes it) or read ClassicUO's `TileDataLoader`.

### 2.2 The catalogue (134 rows)

| Class | Skill | Type | ItemID | Wt | Rng | AoS dmg | AoS spd | ML spd | Old dmg | Old spd | StrReq AoS/old | Dur | Ability 1 / 2 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bow | Archery | Ranged | 0x13B2 | 6 | 10 | 16-18 | 25 | 4.25 | 9-41 | 20 | 30/20 | 31-60 | ParalyzingBlow / MortalStrike |
| CompositeBow | Archery | Ranged | 0x26C2 | 5 | 10 | 15-20 | 25 | 4 | 15-17 | 25 | 45/45 | 31-70 | ArmorIgnore / MovingShot |
| Crossbow | Archery | Ranged | 0x0F50 | 7 | 8 | 18-22 | 24 | 4.5 | 8-43 | 18 | 35/30 | 31-80 | ConcussionBlow / MortalStrike |
| ElvenCompositeLongbow | Archery | Ranged | 0x2D1E | 8 | 10 | 15-19 | 27 | 3.75 | 12-16 | 27 | 45/45 | 41-90 | ForceArrow / SerpentArrow |
| HeavyCrossbow | Archery | Ranged | 0x13FD | 9 | 8 | 20-24 | 22 | 5 | 11-56 | 10 | 80/40 | 31-100 | MovingShot / Dismount |
| JukaBow | Archery | Ranged | ? | ? | 10 | 16-18 | 25 | 4.25 | 9-41 | 20 | 80/80 | 31-60 | ParalyzingBlow / MortalStrike |
| LightweightShortbow | Archery | Ranged | ? | ? | 10 | 12-16 | 38 | 3 | 9-13 | 38 | 45/45 | 41-90 | LightningArrow / PsychicAttack |
| MagicalShortbow | Archery | Ranged | 0x2D2B | 6 | 10 | 12-16 | 38 | 3 | 9-13 | 38 | 45/45 | 41-90 | LightningArrow / PsychicAttack |
| OrcishBow | Archery | Ranged | ? | ? | 10 | 16-18 | 25 | 4.25 | 9-41 | 20 | 30/20 | 31-60 | ParalyzingBlow / MortalStrike |
| RepeatingCrossbow | Archery | Ranged | 0x26C3 | 6 | 7 | 10-15 | 41 | 2.75 | 10-12 | 41 | 30/30 | 31-80 | DoubleStrike / MovingShot |
| Yumi | Archery | Ranged | 0x27A5 | 8 | 10 | 18-17 | 25 | 3.25 | 18-20 | 25 | 35/35 | 55-60 | ArmorPierce / DoubleShot |
| AssassinSpike | Fencing | Slashing | 0x2D21 | 4 | 1 | 10-12 | 50 | 2 | 10-12 | 50 | 15/15 | 30-60 | InfectiousStrike / ShadowStrike |
| BloodBlade | Fencing | Piercing | 0x08FE | 2 | 1 | 10-12 | 53 | 2 | 3-28 | 53 | 10/10 | 31-90 | BleedAttack / ParalyzingBlow |
| Dagger | Fencing | Piercing | 0x0F52 | 1 | 1 | 10-12 | 56 | 2 | 3-15 | 55 | 10/1 | 31-40 | ShadowStrike / InfectiousStrike |
| DoubleBladedStaff | Fencing | Piercing | 0x26BF | 2 | 1 | 11-14 | 49 | 2.25 | 12-13 | 49 | 50/50 | 31-80 | DoubleStrike / InfectiousStrike |
| DualPointedSpear | Fencing | Piercing | 0x0904 | 7 | 1 | 11-14 | 42 | 2.25 | 2-36 | 46 | 50/30 | 31-80 | DoubleStrike / Disarm |
| ElvenSpellblade | Fencing | Slashing | 0x2D20 | 5 | 1 | 12-15 | 44 | 2.5 | 12-14 | 44 | 35/35 | 30-60 | PsychicAttack / BleedAttack |
| GargishDagger | Fencing | Piercing | 0x0902 | 1 | 1 | 10-12 | 56 | 2 | 3-15 | 55 | 10/1 | 31-40 | ShadowStrike / InfectiousStrike |
| GargishKryss | Fencing | Piercing | 0x48BC | 2 | 1 | 10-12 | 53 | 2 | 3-28 | 53 | 10/10 | 31-90 | ArmorIgnore / InfectiousStrike |
| GargishLance | Fencing | Piercing | 0x48CA | 12 | 1 | 18-22 | 24 | 4.25 | 17-18 | 24 | 95/95 | 31-110 | Dismount / ConcussionBlow |
| GargishPike | Fencing | Piercing | 0x48C8 | 8 | 1 | 14-17 | 37 | 3 | 14-16 | 37 | 50/50 | 31-110 | ParalyzingBlow / InfectiousStrike |
| GargishTekagi | Fencing | Piercing | 0x48CE | 5 | 1 | 10-13 | 53 | 2 | 10-12 | 53 | 10/10 | 35-60 | DualWield / TalonStrike |
| GargishWarFork | Fencing | Piercing | 0x48BE | 9 | 1 | 10-14 | 43 | 2.5 | 4-32 | 45 | 45/35 | 31-110 | BleedAttack / Disarm |
| Kama | Fencing | Piercing | 0x27AD | 7 | 1 | 10-13 | 55 | 2 | 9-11 | 55 | 15/15 | 35-60 | WhirlwindAttack / DefenseMastery |
| Kryss | Fencing | Piercing | 0x1401 | 2 | 1 | 10-12 | 53 | 2 | 3-28 | 53 | 10/10 | 31-90 | ArmorIgnore / InfectiousStrike |
| Lajatang | Fencing | Piercing | 0x27A7 | 12 | 1 | 16-19 | 32 | 3.5 | 16-18 | 55 | 65/65 | 90-95 | DefenseMastery / FrenziedWhirlwind |
| Lance | Fencing | Piercing | 0x26C0 | 12 | 1 | 18-22 | 24 | 4.25 | 17-18 | 24 | 95/95 | 31-110 | Dismount / ConcussionBlow |
| Leafblade | Fencing | Slashing | 0x2D22 | 8 | 1 | 11-15 | 42 | 2.75 | 13-15 | 42 | 20/20 | 30-60 | Feint / ArmorIgnore |
| Pike | Fencing | Piercing | 0x26BE | 8 | 1 | 14-17 | 37 | 3 | 14-16 | 37 | 50/50 | 31-110 | ParalyzingBlow / InfectiousStrike |
| Pitchfork | Fencing | Piercing | 0x0E87 | 11 | 1 | 12-15 | 43 | 2.5 | 4-16 | 45 | 55/15 | 31-60 | BleedAttack / Dismount |
| Sai | Fencing | Piercing | 0x27AF | 7 | 1 | 10-13 | 55 | 2 | 9-11 | 55 | 15/15 | 55-60 | DualWield / ArmorPierce |
| SerratedWarCleaver | Fencing | Piercing | ? | ? | 1 | 10-13 | 48 | 2.25 | 9-11 | 48 | 15/15 | 30-60 | Disarm / Bladeweave |
| ShortSpear | Fencing | Piercing | 0x1403 | 4 | 1 | 10-13 | 55 | 2 | 4-32 | 50 | 40/15 | 31-70 | ShadowStrike / MortalStrike |
| Shortblade | Fencing | Piercing | 0x0907 | 9 | 1 | 10-13 | 43 | 2.25 | 4-32 | 45 | 45/35 | 31-110 | ArmorIgnore / MortalStrike |
| Spear | Fencing | Piercing | 0x0F62 | 7 | 1 | 13-16 | 42 | 2.75 | 2-36 | 46 | 50/30 | 31-80 | ArmorIgnore / ParalyzingBlow |
| Tekagi | Fencing | Piercing | 0x27AB | 5 | 1 | 10-13 | 53 | 2 | 10-12 | 53 | 10/10 | 35-60 | DualWield / TalonStrike |
| TribalSpear | Fencing | Piercing | 0x0F62 | 7 | 1 | 13-15 | 42 | 2.75 | 2-36 | 46 | 50/30 | 31-80 | ArmorIgnore / ParalyzingBlow |
| WarCleaver | Fencing | Piercing | 0x2D2F | 10 | 1 | 10-13 | 48 | 2.25 | 9-11 | 48 | 15/15 | 30-60 | Disarm / Bladeweave |
| WarFork | Fencing | Piercing | 0x1405 | 9 | 1 | 10-14 | 43 | 2.5 | 4-32 | 45 | 45/35 | 31-110 | BleedAttack / Disarm |
| BlackStaff | Macing | Staff | 0x0DF0 | 6 | 1 | 13-16 | 39 | 2.75 | 8-33 | 35 | 35/35 | 31-70 | WhirlwindAttack / ParalyzingBlow |
| Club | Macing | Bashing | 0x13B4 | 9 | 1 | 10-14 | 44 | 2.5 | 8-24 | 40 | 40/10 | 31-40 | CrushingBlow / Dismount |
| ClumsyWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| DiamondMace | Macing | Bashing | 0x2D24 | 10 | 1 | 13-17 | 37 | 3.25 | 14-17 | 37 | 35/35 | 30-60 | ConcussionBlow / CrushingBlow |
| DiscMace | Macing | Bashing | 0x0903 | 17 | 1 | 11-15 | 26 | 2.75 | 10-30 | 32 | 45/30 | 31-110 | ArmorIgnore / Disarm |
| EmeraldMace | Macing | Bashing | ? | ? | 1 | 13-17 | 37 | 3.25 | 14-17 | 37 | 35/35 | 30-60 | ConcussionBlow / CrushingBlow |
| FeebleWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| FireballWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| FireworksWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| GargishGnarledStaff | Macing | Staff | 0x48B8 | 3 | 1 | 15-18 | 33 | 3.25 | 10-30 | 33 | 20/20 | 31-50 | ConcussionBlow / ForceOfNature |
| GargishMaul | Macing | Bashing | 0x48C2 | 10 | 1 | 14-18 | 32 | 3.5 | 10-30 | 30 | 45/20 | 31-70 | DoubleStrike / ConcussionBlow |
| GargishTessen | Macing | Bashing | 0x48CC | 6 | 1 | 10-13 | 50 | 2 | 10-12 | 50 | 10/10 | 55-60 | Feint / DualWield |
| GargishWarHammer | Macing | Bashing | 0x48C0 | 10 | 1 | 17-20 | 28 | 3.75 | 8-36 | 31 | 95/40 | 31-110 | WhirlwindAttack / CrushingBlow |
| GlassStaff | Macing | Staff | 0x0905 | 4 | 1 | 11-14 | 39 | 2.25 | 8-33 | 35 | 20/35 | 31-70 | DoubleStrike / MortalStrike |
| GnarledStaff | Macing | Staff | 0x13F8 | 3 | 1 | 15-18 | 33 | 3.25 | 10-30 | 33 | 20/20 | 31-50 | ConcussionBlow / ForceOfNature |
| GreaterHealWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| HammerPick | Macing | Bashing | 0x143D | 9 | 1 | 13-17 | 28 | 3.25 | 6-33 | 30 | 45/35 | 31-70 | ArmorIgnore / MortalStrike |
| HarmWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| HealWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| IDWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| LightningWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| Mace | Macing | Bashing | 0x0F5C | 14 | 1 | 11-15 | 40 | 2.75 | 8-32 | 30 | 45/20 | 31-70 | ConcussionBlow / Disarm |
| MagicArrowWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| MagicWand | Macing | Bashing | 0x0DF2 | 1 | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| ManaDrainWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| Maul | Macing | Bashing | 0x143B | 10 | 1 | 14-18 | 32 | 3.5 | 10-30 | 30 | 45/20 | 31-70 | DoubleStrike / ConcussionBlow |
| Nunchaku | Macing | Bashing | 0x27AE | 5 | 1 | 12-15 | 47 | 2.5 | 11-13 | 47 | 15/15 | 40-55 | Block / DoubleStrike |
| QuarterStaff | Macing | Staff | 0x0E89 | 4 | 1 | 11-14 | 48 | 2.25 | 8-28 | 48 | 30/30 | 31-60 | DoubleStrike / ConcussionBlow |
| RubyMace | Macing | Bashing | ? | ? | 1 | 13-17 | 37 | 3.25 | 14-17 | 37 | 35/35 | 30-60 | ConcussionBlow / CrushingBlow |
| Scepter | Macing | Bashing | 0x26BC | 8 | 1 | 14-18 | 30 | 3.5 | 14-17 | 30 | 40/40 | 31-110 | CrushingBlow / MortalStrike |
| SerpentStoneStaff | Macing | Staff | 0x0906 | 3 | 1 | 16-19 | 33 | 3.5 | 10-30 | 33 | 35/20 | 31-50 | CrushingBlow / Dismount |
| ShepherdsCrook | Macing | Staff | 0x0E81 | 4 | 1 | 13-16 | 40 | 2.75 | 3-12 | 30 | 20/10 | 31-50 | CrushingBlow / Disarm |
| SilverEtchedMace | Macing | Bashing | ? | ? | 1 | 13-17 | 37 | 3.25 | 14-17 | 37 | 35/35 | 30-60 | ConcussionBlow / CrushingBlow |
| SkullGnarledStaff | Macing | Staff | ? | ? | 1 | 15-18 | 33 | 3.25 | 10-30 | 33 | 20/20 | 31-50 | ConcussionBlow / ForceOfNature |
| Tessen | Macing | Bashing | 0x27A3 | 6 | 1 | 10-13 | 50 | 2 | 10-12 | 50 | 10/10 | 55-60 | Feint / DualWield |
| Tetsubo | Macing | Bashing | 0x27A6 | 8 | 1 | 12-15 | 45 | 2.5 | 12-14 | 45 | 35/35 | 60-65 | FrenziedWhirlwind / CrushingBlow |
| WarAxe | Macing | Bashing | 0x13B0 | 8 | 1 | 12-16 | 33 | 3 | 9-27 | 40 | 35/35 | 31-80 | ArmorIgnore / BleedAttack |
| WarHammer | Macing | Bashing | 0x1439 | 10 | 1 | 17-20 | 28 | 3.75 | 8-36 | 31 | 95/40 | 31-110 | WhirlwindAttack / CrushingBlow |
| WarMace | Macing | Bashing | 0x1407 | 17 | 1 | 16-20 | 26 | 4 | 10-30 | 32 | 80/30 | 31-110 | CrushingBlow / MortalStrike |
| WeaknessWand | Macing | Bashing | ? | ? | 1 | 9-11 | 40 | 2.75 | 2-6 | 35 | 5/0 | 31-110 | Dismount / Disarm |
| WildStaff | Macing | Staff | 0x2D25 | 8 | 1 | 10-13 | 48 | 2.25 | 10-12 | 48 | 15/15 | 30-60 | Block / ForceOfNature |
| Axe | Swords | Axe | 0x0F49 | 4 | 1 | 14-17 | 37 | 3 | 6-33 | 37 | 35/35 | 31-110 | CrushingBlow / Dismount |
| Bardiche | Swords | Polearm | 0x0F4D | 7 | 1 | 17-20 | 28 | 3.75 | 5-43 | 26 | 45/40 | 31-100 | ParalyzingBlow / Dismount |
| BattleAxe | Swords | Axe | 0x0F47 | 4 | 1 | 16-19 | 31 | 3.5 | 6-38 | 30 | 35/40 | 31-70 | BleedAttack / ConcussionBlow |
| BladedStaff | Swords | Piercing | 0x26BD | 4 | 1 | 14-17 | 37 | 3 | 14-16 | 37 | 40/40 | 21-110 | ArmorIgnore / Dismount |
| Bokuto | Swords | Slashing | 0x27A8 | 7 | 1 | 10-12 | 53 | 2 | 9-11 | 53 | 20/20 | 25-50 | Feint / NerveStrike |
| BoneHarvester | Swords | Slashing | 0x26BB | 3 | 1 | 12-16 | 36 | 3 | 13-15 | 36 | 25/25 | 31-70 | ParalyzingBlow / MortalStrike |
| BoneMachete | Swords | Slashing | ? | ? | 1 | 11-15 | 41 | 2.75 | 13-15 | 41 | 20/20 | 1-3 | DefenseMastery / Bladeweave |
| Broadsword | Swords | Slashing | 0x0F5E | 6 | 1 | 13-17 | 33 | 3.25 | 5-29 | 45 | 30/25 | 31-100 | CrushingBlow / ArmorIgnore |
| ButcherKnife | Swords | Slashing | 0x13F6 | 1 | 1 | 10-13 | 49 | 2.25 | 2-14 | 40 | 10/5 | 31-40 | InfectiousStrike / Disarm |
| Cleaver | Swords | Slashing | 0x0EC3 | 2 | 1 | 10-14 | 46 | 2.5 | 2-13 | 40 | 10/10 | 31-50 | BleedAttack / InfectiousStrike |
| CrescentBlade | Swords | Slashing | 0x26C1 | 1 | 1 | 12-15 | 47 | 2.5 | 11-14 | 47 | 55/55 | 51-80 | DoubleStrike / MortalStrike |
| Cutlass | Swords | Slashing | 0x1441 | 8 | 1 | 10-14 | 44 | 2.5 | 6-28 | 45 | 25/10 | 31-70 | BleedAttack / ShadowStrike |
| Daisho | Swords | Slashing | 0x27A9 | 8 | 1 | 13-16 | 40 | 2.75 | 13-15 | 40 | 40/40 | 45-65 | Feint / DoubleStrike |
| DoubleAxe | Swords | Axe | 0x0F4B | 8 | 1 | 15-18 | 33 | 3.25 | 5-35 | 37 | 45/45 | 31-110 | DoubleStrike / WhirlwindAttack |
| DreadSword | Swords | Slashing | 0x090B | 7 | 1 | 14-18 | 30 | 3.5 | 5-33 | 35 | 35/25 | 31-110 | CrushingBlow / ConcussionBlow |
| DualShortAxes | Swords | Axe | 0x08FD | 8 | 1 | 14-17 | 33 | 3 | 5-35 | 37 | 35/45 | 31-110 | DoubleStrike / InfectiousStrike |
| ElvenMachete | Swords | Slashing | 0x2D35 | 6 | 1 | 11-15 | 41 | 2.75 | 13-15 | 41 | 20/20 | 30-60 | DefenseMastery / Bladeweave |
| ExecutionersAxe | Swords | Axe | 0x0F45 | 8 | 1 | 15-18 | 33 | 3.25 | 6-33 | 37 | 40/35 | 31-70 | BleedAttack / MortalStrike |
| GargishAxe | Swords | Axe | 0x48B2 | 4 | 1 | 14-17 | 37 | 3 | 6-33 | 37 | 35/35 | 31-110 | CrushingBlow / Dismount |
| GargishBardiche | Swords | Polearm | 0x48B4 | 7 | 1 | 17-20 | 28 | 3.75 | 5-43 | 26 | 45/40 | 31-100 | ParalyzingBlow / Dismount |
| GargishBattleAxe | Swords | Axe | 0x48B0 | 4 | 1 | 16-19 | 31 | 3.5 | 6-38 | 30 | 35/40 | 31-70 | BleedAttack / ConcussionBlow |
| GargishBoneHarvester | Swords | Slashing | 0x48C6 | 3 | 1 | 12-16 | 36 | 3 | 13-15 | 36 | 25/25 | 31-70 | ParalyzingBlow / MortalStrike |
| GargishButcherKnife | Swords | Slashing | 0x48B6 | 1 | 1 | 10-13 | 49 | 2.25 | 2-14 | 40 | 10/5 | 31-40 | InfectiousStrike / Disarm |
| GargishCleaver | Swords | Slashing | 0x48AE | 2 | 1 | 10-14 | 46 | 2.5 | 2-13 | 40 | 10/10 | 31-50 | BleedAttack / InfectiousStrike |
| GargishDaisho | Swords | Slashing | 0x48D0 | 8 | 1 | 13-16 | 40 | 2.75 | 13-15 | 40 | 40/40 | 45-65 | Feint / DoubleStrike |
| GargishKatana | Swords | Slashing | 0x48BA | 6 | 1 | 10-14 | 46 | 2.5 | 5-26 | 58 | 25/10 | 31-90 | DoubleStrike / ArmorIgnore |
| GargishScythe | Swords | Polearm | 0x48C4 | 5 | 1 | 16-19 | 32 | 3.5 | 15-18 | 32 | 45/45 | 31-100 | BleedAttack / ParalyzingBlow |
| GargishTalwar | Swords | Slashing | 0x0908 | 16 | 1 | 16-19 | 25 | 3.5 | 5-49 | 25 | 40/45 | 31-80 | WhirlwindAttack / Dismount |
| GlassSword | Swords | Slashing | 0x090C | 6 | 1 | 11-15 | 46 | 2.75 | 5-26 | 58 | 20/10 | 31-90 | BleedAttack / MortalStrike |
| Halberd | Swords | Polearm | 0x143E | 16 | 1 | 18-21 | 25 | 4 | 5-49 | 25 | 95/45 | 31-80 | WhirlwindAttack / ConcussionBlow |
| Hatchet | Swords | Axe | 0x0F43 | 4 | 1 | 13-16 | 41 | 2.75 | 2-17 | 40 | 20/15 | 31-80 | ArmorIgnore / Disarm |
| HeavyOrnateAxe | Swords | Axe | ? | ? | 1 | 17-20 | 26 | 3.75 | 18-20 | 26 | 45/45 | 30-60 | Disarm / CrushingBlow |
| Katana | Swords | Slashing | 0x13FF | 6 | 1 | 10-14 | 46 | 2.5 | 5-26 | 58 | 25/10 | 31-90 | DoubleStrike / ArmorIgnore |
| LargeBattleAxe | Swords | Axe | 0x13FB | 6 | 1 | 17-20 | 29 | 3.75 | 6-38 | 30 | 80/40 | 31-70 | WhirlwindAttack / BleedAttack |
| Longsword | Swords | Slashing | 0x0F61 | 7 | 1 | 14-18 | 30 | 3.5 | 5-33 | 35 | 35/25 | 31-110 | ArmorIgnore / ConcussionBlow |
| NoDachi | Swords | Slashing | 0x27A2 | 10 | 1 | 16-19 | 35 | 3.5 | 16-18 | 35 | 40/40 | 31-90 | CrushingBlow / RidingSwipe |
| OrnateAxe | Swords | Axe | 0x2D28 | 12 | 1 | 17-20 | 26 | 3.75 | 18-20 | 26 | 45/45 | 30-60 | Disarm / CrushingBlow |
| PaladinSword | Swords | Slashing | 0x26CE | 6 | 1 | 20-24 | 0 | 5 | 0-0 | 0 | 85/0 | 36-48 | WhirlwindAttack / Disarm |
| Pickaxe | Swords | Axe | 0x0E86 | 11 | 1 | 12-16 | 35 | 3 | 1-15 | 35 | 50/25 | 31-60 | DoubleStrike / Disarm |
| RadiantScimitar | Swords | Slashing | 0x2D33 | 9 | 1 | 10-14 | 43 | 2.5 | 12-14 | 43 | 20/20 | 30-60 | WhirlwindAttack / Bladeweave |
| RuneBlade | Swords | Slashing | 0x2D32 | 7 | 1 | 14-17 | 35 | 3 | 15-17 | 35 | 30/30 | 30-60 | Disarm / Bladeweave |
| Scimitar | Swords | Slashing | 0x13B6 | 5 | 1 | 12-16 | 37 | 3 | 4-30 | 43 | 25/10 | 31-90 | DoubleStrike / ParalyzingBlow |
| Scythe | Swords | Polearm | 0x26BA | 5 | 1 | 16-19 | 32 | 3.5 | 15-18 | 32 | 45/45 | 31-100 | BleedAttack / ParalyzingBlow |
| SkinningKnife | Swords | Slashing | 0x0EC4 | 1 | 1 | 10-13 | 49 | 2.25 | 1-10 | 40 | 5/5 | 31-40 | ShadowStrike / BleedAttack |
| SkullLongsword | Swords | Slashing | ? | ? | 1 | 14-18 | 30 | 3.5 | 5-33 | 35 | 35/25 | 31-110 | ArmorIgnore / ConcussionBlow |
| StoneWarSword | Swords | Slashing | 0x0900 | 6 | 1 | 15-19 | 28 | 3.75 | 6-34 | 30 | 40/40 | 31-100 | ArmorIgnore / ParalyzingBlow |
| ThinLongsword | Swords | Slashing | 0x13B8 | 1 | 1 | 15-16 | 30 | 3.5 | 5-33 | 35 | 35/25 | 31-110 | null / null |
| TwoHandedAxe | Swords | Axe | 0x1443 | 8 | 1 | 16-19 | 31 | 3.5 | 5-39 | 30 | 40/35 | 31-90 | DoubleStrike / ShadowStrike |
| VikingSword | Swords | Slashing | 0x13B9 | 6 | 1 | 15-19 | 28 | 3.75 | 6-34 | 30 | 40/40 | 31-100 | CrushingBlow / ParalyzingBlow |
| Wakizashi | Swords | Slashing | 0x27A4 | 5 | 1 | 10-14 | 44 | 2.5 | 11-13 | 44 | 20/20 | 45-50 | FrenziedWhirlwind / DoubleStrike |
| Boomerang | Throwing | Ranged | 0x08FF | 4 | ? | 11-15 | 25 | 2.75 | 9-41 | 20 | 25/20 | 31-60 | MysticArc / ConcussionBlow |
| Cyclone | Throwing | Ranged | 0x0901 | 6 | ? | 13-17 | 25 | 3.25 | 9-41 | 20 | 40/20 | 31-60 | MovingShot / InfusedThrow |
| SoulGlaive | Throwing | Ranged | 0x090A | 8 | ? | 16-20 | 25 | 4 | 9-41 | 20 | 60/20 | 31-65 | ArmorIgnore / MortalStrike |
| Fukiya | - | - | 0x27AA | 4 | ? | ?-? | ? | ? | ?-? | ? | ?/? | ?-? | - / - |

### 2.3 Shields

Shields are `BaseShield : BaseArmor` on **`Layer.TwoHanded`** — the same layer as a two-handed weapon, which is why you cannot hold a shield and a two-hander. **`[HIGH]`** — `Scripts/Items/Equipment/Armor/BaseShield.cs`; the layer conflict logic is at `BaseWeapon.cs:1005-1010`.

| Shield | ItemID | Wt | Phys | Fire | Cold | Pois | Ener | AR | StrReq | Dur | Blacksmithy min | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Buckler | 0x1B73 | 5 | 0 | 0 | 0 | 1 | 0 | 7 | 20 | 40-50 | **−25.0** | `Armor/Buckler.cs` |
| BronzeShield | — | — | 0 | 0 | 0 | 1 | 0 | — | — | — | **−15.2** | `Armor/BronzeShield.cs` |
| MetalShield | — | — | — | — | — | — | — | — | — | — | **−10.2** | `Armor/MetalShield.cs` |
| MetalKiteShield | — | — | — | — | — | — | — | — | — | — | **4.6** | `Armor/MetalKiteShield.cs` |
| HeaterShield | — | — | — | — | — | — | — | — | — | — | **24.3** | `Armor/HeaterShield.cs` |
| LargePlateShield | — | — | — | — | — | — | — | — | — | — | **24.3** | `Armor/LargePlateShield.cs` |
| OrderShield | 0x1BC4 | 7 | 1 | 0 | 0 | 0 | 0 | 30 | 95 | 100-125 | **85.0** | `Armor/OrderShield.cs` |
| ChaosShield | — | — | — | — | — | — | — | — | — | — | **85.0** | `Armor/ChaosShield.cs` |
| WoodenShield / Gargish shields | — | — | — | — | — | — | — | — | — | — | Carpentry / Masonry | see §3 |

The shield rows marked `—` are in the **full generated armour table in §3.3**, which contains every shield with its resistances, AR, strength requirement and durability. The Blacksmithy minimums above are exact and quoted from `Scripts/Services/Craft/DefBlacksmithy.cs:410-429`.

* **A shield's AR contributes to pre-AoS `ArmorRating`** and its resistances contribute to AoS resistances. **`[HIGH]`**
* A successful parry calls `shield.OnHit(this, damage)` which wears the shield. **`[HIGH]`** — `BaseWeapon.cs:1927-1929`.
* **Shields give a parry bonus and, for AoS thrown weapons, a shield malus** (`BaseWeapon.cs:1507-1526`).

### 2.4 Material tiers (weapons)

Weapon material bonuses in ServUO are **elemental damage conversions and durability — NOT a flat "damage %" bonus.** This is the single most commonly mis-stated UO rule. **`[HIGH]`** — `Scripts/Misc/ResourceInfo.cs:49-351` (fields `CraftAttributeInfo`) and the consumption code at `BaseWeapon.cs:6478-6500` and `:3490-3537`.

```csharp
// SU BaseWeapon.cs:3490-3537 — how material elemental damage becomes a damage split
phys = 100 - fire - cold - pois - nrgy - chaos - direct;
// then each material element eats into 'phys':
left = ApplyCraftAttributeElementDamage(attrInfo.WeaponColdDamage,   ref cold,  left);
left = ApplyCraftAttributeElementDamage(attrInfo.WeaponEnergyDamage, ref nrgy,  left);
left = ApplyCraftAttributeElementDamage(attrInfo.WeaponFireDamage,   ref fire,  left);
left = ApplyCraftAttributeElementDamage(attrInfo.WeaponPoisonDamage, ref pois,  left);
left = ApplyCraftAttributeElementDamage(attrInfo.WeaponChaosDamage,  ref chaos, left);
left = ApplyCraftAttributeElementDamage(attrInfo.WeaponDirectDamage, ref direct,left);
phys = left;
```

| Material | Weapon elemental damage (converted from physical) | Weapon durability | Weapon luck | Weapon lower-req | Runic attrs min–max | Runic intensity **pre-ML** | Runic intensity **ML** |
|---|---|---|---|---|---|---|---|
| Iron | — | — | — | — | — | — | — |
| Dull Copper | — | **+100 %** | — | **50 %** | 1–2 | 10–35 | 40–100 |
| Shadow Iron | Cold **20** | +50 % | — | — | 2–2 | 20–45 | 45–100 |
| Copper | Poison 10, Energy 20 | — | — | — | 2–3 | 25–50 | 50–100 |
| Bronze | Fire **40** | — | — | — | 3–3 | 30–65 | 55–100 |
| Gold ("Golden") | — | — | **+40** | **50 %** | 3–4 | 35–75 | 60–100 |
| Agapite | Cold 30, Energy 20 | — | — | — | 4–4 | 40–80 | 65–100 |
| Verite | Poison **40**, Energy 20 | — | — | — | 4–5 | 45–90 | 70–100 |
| Valorite | Fire 10, Cold 20, Poison 10, Energy **20** | +50 % | — | — | 5–5 | 50–100 | 85–100 |

**The "damage bonus" column is genuinely empty for all metals.** There is no `dagger of valorite = +X % damage` in this codebase; valorite changes your damage to a mixed elemental split and adds durability. **`[HIGH]`** — verified by reading every `Weapon*Damage` assignment in `ResourceInfo.cs:177-351`.

Durability rows are also armours: see §3.6 for the armour-resistance material table.

---

## 3. ARMOUR CATALOGUE

### 3.1 Resistance / AR / strength / durability model

```csharp
// SU Scripts/Items/Equipment/Armor/BaseArmor.cs:1241-1279
public override int PhysicalResistance { get { return BasePhysicalResistance + GetProtOffset() + m_PhysicalBonus; } }
… identically for Fire / Cold / Poison / Energy …

// :1328-1343
public int GetProtOffset() {
    switch (m_Protection) {
        case ArmorProtectionLevel.Guarding:        return 1;
        case ArmorProtectionLevel.Hardening:       return 2;
        case ArmorProtectionLevel.Fortification:   return 3;
        case ArmorProtectionLevel.Invulnerability: return 4;
    }
    return 0;
}
// :155-160 ArmorBase — the pre-AoS AR value; per-item overrides in each armour file.
```
**`[HIGH]`.** So each armour piece carries:
* five **`Base*Resistance`** integers (the AoS resistances), each `+ protection offset + magic bonus`;
* one **`ArmorBase`** integer (the classic AR);
* `AosStrReq` / `OldStrReq` (era-split strength requirement);
* `InitMinHits` / `InitMaxHits` (durability range);
* `ArmorMaterialType` (`Leather, Studded, Bone, Chainmail, Ringmail, Plate, Dragon, Wood, Stone, Cloth, …`);
* `DefaultResource` (which `CraftResource` tier it is made from);
* `DefMedAllowance` — `ArmorMeditationAllowance` ∈ {`All`, `Half`, `None`} — which gates Meditation.

**Protection levels add +1/+2/+3/+4 to *all five* resistances** in AoS. In classic the equivalent `ArmorProtectionLevel` adds to AR through the quality path. **`[HIGH]`**

### 3.2 The catalogue (165 rows)

Generated mechanically from `Scripts/Items/Equipment/Armor/*.cs`. `?` in **StrReq AoS/old** = the file does not override it (shields use `StrRequirement` from `BaseShield`). **Craft skill** is the exact `AddCraft(...)` minimum from `DefBlacksmithy.cs` / `DefTailoring.cs` / `DefCarpentry.cs` / `DefMasonry.cs`, e.g. `Blacksmithy 85` = `AddCraft(typeof(OrderShield), …, 85.0, 135.0, …)`. A negative number (Buckler −25) is real: it means the recipe is trivially craftable at 0 skill.

Legend: **Phys/Fire/Cold/Pois/Ener** = `Base*Resistance` (AoS resistances). **AR** = `ArmorBase` (classic armour rating). **Med** = `ArmorMeditationAllowance`.

| Class | Material | ItemID | Wt | Phys | Fire | Cold | Pois | Ener | AR(ArmorBase) | StrReq AoS/old | Dur | Med | Craft skill (min) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BoneArms | Bone | 0x144E | 2 | 3 | 3 | 4 | 2 | 4 | 30 | 55/40 | 25-30 | - | Tailoring 92 |
| BoneChest | Bone | 0x144F | 6 | 3 | 3 | 4 | 2 | 4 | 30 | 60/40 | 25-30 | - | Tailoring 96 |
| BoneGloves | Bone | 0x1450 | 2 | 3 | 3 | 4 | 2 | 4 | 30 | 55/40 | 25-30 | - | Tailoring 89 |
| BoneHelm | Bone | 0x1451 | 3 | 3 | 3 | 4 | 2 | 4 | 30 | 20/40 | 25-30 | - | Tailoring 85 |
| BoneLegs | Bone | 0x1452 | 3 | 3 | 3 | 4 | 2 | 4 | 30 | 55/40 | 25-30 | - | Tailoring 95 |
| EvilOrcHelm | Bone | ? | ? | 3 | 1 | 3 | 3 | 5 | 20 | 30/10 | 30-50 | None | - |
| OrcHelm | Bone | 0x1F0B | ? | 3 | 1 | 3 | 3 | 5 | 20 | 30/10 | 30-50 | None | Tailoring 90 |
| ChainChest | Chainmail | 0x13BF | 7 | 4 | 4 | 4 | 1 | 2 | 28 | 60/20 | 45-60 | - | Blacksmithy 39.1 |
| ChainCoif | Chainmail | 0x13BB | 1 | 4 | 4 | 4 | 1 | 2 | 28 | 60/20 | 35-60 | - | Blacksmithy 14.5 |
| ChainHatsuburi | Chainmail | 0x2774 | 7 | 5 | 2 | 2 | 2 | 4 | 3 | 50/50 | 55-75 | - | Blacksmithy 30 |
| ChainLegs | Chainmail | 0x13BE | 7 | 4 | 4 | 4 | 1 | 2 | 28 | 60/20 | 45-60 | - | Blacksmithy 36.7 |
| DragonArms | Dragon | 0x2657 | 5 | 3 | 3 | 3 | 3 | 3 | 40 | 75/20 | 55-75 | - | Blacksmithy 76.3 |
| DragonChest | Dragon | 0x2641 | 10 | 3 | 3 | 3 | 3 | 3 | 40 | 75/60 | 55-75 | - | Blacksmithy 85 |
| DragonGloves | Dragon | 0x2643 | 2 | 3 | 3 | 3 | 3 | 3 | 40 | 75/30 | 55-75 | - | Blacksmithy 68.9 |
| DragonHelm | Dragon | 0x2645 | 5 | 3 | 3 | 3 | 3 | 3 | 40 | 75/40 | 55-75 | - | Blacksmithy 72.6 |
| DragonLegs | Dragon | 0x2647 | 6 | 3 | 3 | 3 | 3 | 3 | 40 | 75/60 | 55-75 | - | Blacksmithy 78.8 |
| DragonTurtleHideArms | Leather | 0x782E | 3 | 3 | 3 | 4 | 3 | 2 | 15 | 30/20 | 35-45 | All | Tailoring 101.5 |
| DragonTurtleHideBustier | Leather | 0x782B | 6 | 3 | 3 | 4 | 3 | 2 | 15 | 30/35 | 35-45 | All | Tailoring 101.5 |
| DragonTurtleHideChest | Leather | 0x782A | 8 | 2 | 4 | 3 | 3 | 4 | 16 | 30/35 | 35-45 | All | Tailoring 101.5 |
| DragonTurtleHideHelm | Leather | 0x782D | 2 | 1 | 5 | 2 | 2 | 5 | 30 | 30/10 | 20-35 | All | Tailoring 101.5 |
| DragonTurtleHideLegs | Leather | 0x782C | 5 | 3 | 3 | 4 | 3 | 2 | 15 | 30/25 | 35-45 | All | Tailoring 101.5 |
| ElegantCollar | Leather | 0xA40F | 3 | 2 | 4 | 3 | 3 | 3 | 7 | 30/? | 35-50 | All | Tailoring 90 |
| ElegantCollarOfFortune | Leather | ? | ? | 15 | 10 | 10 | 10 | 15 | 7 | 30/? | 255-255 | All | Tailoring 120 |
| FemaleGargishLeatherArms | Leather | 0x0301 | 4 | 5 | 6 | 7 | 6 | 6 | ? | 25/? | 30-50 | All | Tailoring 53.9 |
| FemaleGargishLeatherChest | Leather | 0x0303 | 8 | 5 | 6 | 7 | 6 | 6 | ? | 25/? | 30-50 | All | Tailoring 70.5 |
| FemaleGargishLeatherKilt | Leather | 0x0310 | 5 | 5 | 6 | 7 | 6 | 6 | ? | 25/? | 30-50 | All | Tailoring 58 |
| FemaleGargishLeatherLegs | Leather | 0x0305 | 5 | 5 | 6 | 7 | 6 | 6 | ? | 20/? | 30-50 | All | Tailoring 66.3 |
| FemaleLeafChest | Leather | 0x2FCB | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 20/20 | 30-40 | All | - |
| FemaleLeatherChest | Leather | 0x1C06 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 25/15 | 30-40 | All | Tailoring 62.2 |
| GargishClothArmsArmor | Leather | 0x0404 | 2 | 5 | 7 | 6 | 6 | 6 | 18 | 20/20 | 40-50 | All | Tailoring 87.1 |
| GargishLeatherArms | Leather | 0x0302 | 4 | 5 | 6 | 7 | 6 | 6 | ? | 25/? | 30-50 | All | Tailoring 53.9 |
| GargishLeatherChest | Leather | 0x0304 | 8 | 5 | 6 | 7 | 6 | 6 | ? | 25/? | 30-50 | All | Tailoring 70.5 |
| GargishLeatherKilt | Leather | 0x0311 | 5 | 5 | 6 | 7 | 6 | 6 | ? | 25/? | 30-50 | All | Tailoring 58 |
| GargishLeatherLegs | Leather | 0x0305 | 5 | 5 | 6 | 7 | 6 | 6 | ? | 20/? | 30-50 | All | Tailoring 66.3 |
| GargishLeatherWingArmor | Leather | 0x457E | 2 | ? | ? | ? | ? | ? | 13 | 10/10 | ?-? | All | Tailoring 65 |
| LeafArms | Leather | 0x2FC8 | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 15/15 | 30-40 | All | Tailoring 60 |
| LeafChest | Leather | 0x2FC5 | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 20/20 | 30-40 | All | Tailoring 75 |
| LeafGloves | Leather | 0x2FC6 | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 10/10 | 30-40 | All | Tailoring 60 |
| LeafGorget | Leather | 0x2FC7 | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 10/10 | 30-40 | All | Tailoring 65 |
| LeafLegs | Leather | 0x2FC9 | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 20/20 | 30-40 | All | Tailoring 75 |
| LeafTonlet | Leather | 0x2FCA | 2 | 2 | 3 | 2 | 4 | 4 | 13 | 10/10 | 30-40 | All | Tailoring 70 |
| LeatherArms | Leather | 0x13CD | 2 | 2 | 4 | 3 | 3 | 3 | 13 | 20/15 | 30-40 | All | Tailoring 53.9 |
| LeatherBustierArms | Leather | 0x1C0A | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 20/15 | 30-40 | All | Tailoring 58 |
| LeatherCap | Leather | 0x1DB9 | 2 | 2 | 4 | 3 | 3 | 3 | 13 | 20/15 | 30-40 | All | Tailoring 6.2 |
| LeatherChest | Leather | 0x13CC | 6 | 2 | 4 | 3 | 3 | 3 | 13 | 25/15 | 30-40 | All | Tailoring 70.5 |
| LeatherDo | Leather | 0x27C6 | 6 | 2 | 4 | 3 | 3 | 3 | 3 | 40/40 | 35-45 | All | Tailoring 75 |
| LeatherGloves | Leather | 0x13C6 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 20/10 | 30-40 | All | Tailoring 51.8 |
| LeatherGorget | Leather | 0x13C7 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 20/10 | 30-40 | All | Tailoring 53.9 |
| LeatherHaidate | Leather | 0x278A | 4 | 2 | 4 | 3 | 3 | 3 | 3 | 20/20 | 30-40 | All | Tailoring 68 |
| LeatherHiroSode | Leather | 0x277E | 1 | 2 | 4 | 3 | 3 | 3 | 3 | 25/25 | 40-50 | All | Tailoring 55 |
| LeatherJingasa | Leather | 0x2776 | 3 | 4 | 3 | 3 | 2 | 3 | 3 | 25/25 | 20-30 | All | Tailoring 45 |
| LeatherLegs | Leather | 0x13CB | 4 | 2 | 4 | 3 | 3 | 3 | 13 | 20/10 | 30-40 | All | Tailoring 66.3 |
| LeatherMempo | Leather | 0x277A | 2 | 2 | 4 | 3 | 3 | 3 | 3 | 30/30 | 35-40 | All | Tailoring 80 |
| LeatherNinjaHood | Leather | 0x278E | 2 | 2 | 4 | 3 | 3 | 3 | 3 | 10/10 | 25-45 | All | Tailoring 90 |
| LeatherNinjaJacket | Leather | 0x2793 | 5 | 2 | 4 | 3 | 3 | 3 | 3 | 10/10 | 55-65 | All | Tailoring 85 |
| LeatherNinjaMitts | Leather | 0x2792 | 2 | 2 | 4 | 3 | 3 | 3 | 3 | 10/10 | 25-25 | All | Tailoring 65 |
| LeatherNinjaPants | Leather | 0x2791 | 3 | 2 | 4 | 3 | 3 | 3 | 3 | 10/10 | 40-50 | All | Tailoring 80 |
| LeatherShorts | Leather | 0x1C00 | 3 | 2 | 4 | 3 | 3 | 3 | 13 | 20/10 | 30-40 | All | Tailoring 62.2 |
| LeatherSkirt | Leather | 0x1C08 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 20/10 | 30-40 | All | Tailoring 58 |
| LeatherSuneate | Leather | 0x2786 | 4 | 2 | 4 | 3 | 3 | 3 | 3 | 20/20 | 25-40 | All | Tailoring 68 |
| TigerPeltBustier | Leather | 0x7823 | 6 | 2 | 4 | 3 | 3 | 3 | 13 | 25/15 | 30-40 | All | Tailoring 90 |
| TigerPeltChest | Leather | 0x7822 | 6 | 2 | 4 | 3 | 3 | 3 | 13 | 25/15 | 30-40 | All | Tailoring 90 |
| TigerPeltCollar | Leather | 0x7829 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 25/10 | 30-40 | All | Tailoring 90 |
| TigerPeltHelm | Leather | 0x7828 | 2 | 2 | 4 | 3 | 3 | 3 | 13 | 25/15 | 30-40 | All | Tailoring 90 |
| TigerPeltLegs | Leather | 0x7824 | 2 | 2 | 4 | 3 | 3 | 3 | 13 | 25/10 | 30-40 | All | Tailoring 90 |
| TigerPeltLongSkirt | Leather | 0x7826 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 25/10 | 30-40 | All | Tailoring 90 |
| TigerPeltShorts | Leather | 0x7825 | 3 | 2 | 4 | 3 | 3 | 3 | 13 | 25/10 | 30-40 | All | Tailoring 90 |
| TigerPeltSkirt | Leather | 0x7827 | 1 | 2 | 4 | 3 | 3 | 3 | 13 | 25/10 | 30-40 | All | Tailoring 90 |
| Bascinet | Plate | 0x140C | 5 | 7 | 2 | 2 | 2 | 2 | 18 | 40/10 | 40-50 | - | Blacksmithy 8.3 |
| BaseShield | Plate | ? | ? | ? | ? | ? | ? | ? | ? | ?/? | ?-? | - | - |
| BronzeShield | Plate | 0x1B72 | 6 | 0 | 0 | 1 | 0 | 0 | 10 | 35/? | 25-30 | - | Blacksmithy -15.2 |
| Buckler | Plate | 0x1B73 | 5 | 0 | 0 | 0 | 1 | 0 | 7 | 20/? | 40-50 | - | Blacksmithy -25 |
| ChaosShield | Plate | 0x1BC3 | 5 | 1 | 0 | 0 | 0 | 0 | 32 | 95/? | 100-125 | - | Blacksmithy 85 |
| Circlet | Plate | 0x2B6E | 2 | 1 | 5 | 2 | 2 | 5 | 30 | 10/10 | 50-65 | All | Blacksmithy 62.1 |
| CloseHelm | Plate | 0x1408 | 5 | 3 | 3 | 3 | 3 | 3 | 30 | 55/40 | 45-60 | - | Blacksmithy 37.9 |
| DecorativePlateKabuto | Plate | 0x2778 | 6 | 6 | 2 | 2 | 2 | 3 | 3 | 70/70 | 55-75 | - | Blacksmithy 90 |
| FemaleGargishPlateArms | Plate | 0x0307 | 5 | 8 | 6 | 5 | 6 | 5 | ? | 80/? | 50-65 | - | Blacksmithy 66.3 |
| FemaleGargishPlateChest | Plate | 0x0309 | 10 | 8 | 6 | 5 | 6 | 5 | ? | 95/? | 50-65 | - | Blacksmithy 75 |
| FemaleGargishPlateKilt | Plate | 0x030B | 5 | 8 | 6 | 5 | 6 | 5 | ? | 80/? | 50-65 | - | Blacksmithy 58.9 |
| FemaleGargishPlateLegs | Plate | 0x030D | 7 | 8 | 6 | 5 | 6 | 5 | ? | 90/? | 50-65 | - | Blacksmithy 68.8 |
| FemalePlateChest | Plate | 0x1C04 | 4 | 5 | 3 | 2 | 3 | 2 | 30 | 95/45 | 50-65 | - | Blacksmithy 44.1 |
| GargishChaosShield | Plate | 0x4228 | 5 | 1 | 0 | 0 | 0 | 0 | 32 | 95/? | 100-125 | - | Blacksmithy 85 |
| GargishKiteShield | Plate | 0x4201 | 7 | 0 | 0 | 0 | 0 | 1 | 16 | 45/? | 45-60 | - | Blacksmithy 4.6 |
| GargishOrderShield | Plate | 0x422A | 7 | 1 | 0 | 0 | 0 | 0 | 30 | 95/? | 100-125 | - | Blacksmithy 85 |
| GargishPlateArms | Plate | 0x0308 | 5 | 8 | 6 | 5 | 6 | 5 | ? | 80/? | 50-65 | - | Blacksmithy 66.3 |
| GargishPlateChest | Plate | 0x030A | 10 | 8 | 6 | 5 | 6 | 5 | ? | 95/? | 50-65 | - | Blacksmithy 75 |
| GargishPlateKilt | Plate | 0x030C | 5 | 8 | 6 | 5 | 6 | 5 | ? | 80/? | 50-65 | - | Blacksmithy 58.9 |
| GargishPlateLegs | Plate | 0x030E | 7 | 8 | 6 | 5 | 6 | 5 | ? | 90/? | 50-65 | - | Blacksmithy 68.8 |
| GemmedCirclet | Plate | 0x2B70 | 2 | 1 | 5 | 2 | 2 | 5 | 30 | 10/10 | 20-35 | All | Blacksmithy 75 |
| HeaterShield | Plate | 0x1B76 | 8 | 0 | 1 | 0 | 0 | 0 | 23 | 90/? | 50-65 | - | Blacksmithy 24.3 |
| HeavyPlateJingasa | Plate | 0x2777 | 5 | 7 | 2 | 2 | 2 | 2 | 4 | 55/55 | 50-70 | - | Blacksmithy 45 |
| Helmet | Plate | 0x140A | 5 | 2 | 4 | 4 | 3 | 2 | 30 | 45/40 | 45-60 | - | Blacksmithy 37.9 |
| LargePlateShield | Plate | 0x4204 | ? | 0 | 1 | 0 | 0 | 0 | 23 | 90/? | 50-65 | - | Blacksmithy 24.3 |
| LargeStoneShield | Plate | 0x4205 | 5 | 0 | 0 | 0 | 0 | 1 | 12 | 20/? | 50-65 | - | Masonry 55 |
| LightPlateJingasa | Plate | 0x2781 | 5 | 7 | 2 | 2 | 2 | 2 | 4 | 55/55 | 55-60 | - | Blacksmithy 45 |
| MediumPlateShield | Plate | 0x4203 | 6 | 0 | 1 | 0 | 0 | 0 | 11 | 45/? | 50-65 | - | Blacksmithy -10.2 |
| MetalKiteShield | Plate | 0x1B74 | 7 | 0 | 0 | 0 | 0 | 1 | 16 | 45/? | 45-60 | - | Blacksmithy 4.6 |
| MetalShield | Plate | 0x1B7B | 6 | 0 | 1 | 0 | 0 | 0 | 11 | 45/? | 50-65 | - | Blacksmithy -10.2 |
| NorseHelm | Plate | 0x140E | 5 | 4 | 1 | 4 | 4 | 2 | 30 | 55/40 | 45-60 | - | Blacksmithy 37.9 |
| OrderShield | Plate | 0x1BC4 | 7 | 1 | 0 | 0 | 0 | 0 | 30 | 95/? | 100-125 | - | Blacksmithy 85 |
| PlateArms | Plate | 0x1410 | 5 | 5 | 3 | 2 | 3 | 2 | 40 | 80/40 | 50-65 | - | Blacksmithy 66.3 |
| PlateBattleKabuto | Plate | 0x2785 | 6 | 6 | 2 | 2 | 2 | 3 | 3 | 70/70 | 60-65 | - | Blacksmithy 90 |
| PlateChest | Plate | 0x1415 | 10 | 5 | 3 | 2 | 3 | 2 | 40 | 95/60 | 50-65 | - | Blacksmithy 75 |
| PlateDo | Plate | 0x277D | 10 | 5 | 3 | 2 | 3 | 2 | 3 | 85/85 | 60-70 | - | Blacksmithy 80 |
| PlateGloves | Plate | 0x1414 | 2 | 5 | 3 | 2 | 3 | 2 | 40 | 70/30 | 50-65 | - | Blacksmithy 58.9 |
| PlateGorget | Plate | 0x1413 | 2 | 5 | 3 | 2 | 3 | 2 | 40 | 45/30 | 50-65 | - | Blacksmithy 56.4 |
| PlateHaidate | Plate | 0x278D | 7 | 5 | 3 | 2 | 3 | 2 | 3 | 80/80 | 55-65 | - | Blacksmithy 65 |
| PlateHatsuburi | Plate | 0x2775 | 5 | 5 | 3 | 2 | 2 | 3 | 4 | 65/65 | 55-75 | - | Blacksmithy 45 |
| PlateHelm | Plate | 0x1412 | 5 | 5 | 3 | 2 | 3 | 2 | 40 | 80/40 | 50-65 | - | Blacksmithy 62.6 |
| PlateHiroSode | Plate | 0x2780 | 3 | 5 | 3 | 2 | 3 | 2 | 3 | 75/75 | 55-75 | - | Blacksmithy 80 |
| PlateLegs | Plate | 0x1411 | 7 | 5 | 3 | 2 | 3 | 2 | 40 | 90/60 | 50-65 | - | Blacksmithy 68.8 |
| PlateMempo | Plate | 0x2779 | 3 | 5 | 3 | 2 | 3 | 2 | 4 | 50/50 | 60-70 | - | Blacksmithy 80 |
| PlateSuneate | Plate | 0x2788 | 7 | 5 | 3 | 2 | 3 | 2 | 3 | 80/80 | 55-65 | - | Blacksmithy 65 |
| RavenHelm | Plate | 0x2B71 | 5 | 5 | 1 | 2 | 2 | 5 | 40 | 25/25 | 50-65 | - | Carpentry 65 |
| RoyalCirclet | Plate | 0x2B6F | 2 | 1 | 5 | 2 | 2 | 5 | 30 | 10/10 | 20-35 | All | Blacksmithy 70 |
| SmallPlateJingasa | Plate | 0x2784 | 5 | 7 | 2 | 2 | 2 | 2 | 4 | 55/55 | 55-60 | - | Blacksmithy 45 |
| SmallPlateShield | Plate | 0x4202 | 6 | 0 | 0 | 1 | 0 | 0 | 10 | 35/? | 25-30 | - | Blacksmithy -25 |
| StandardPlateKabuto | Plate | 0x2789 | 6 | 6 | 2 | 2 | 2 | 3 | 3 | 70/70 | 60-65 | - | Blacksmithy 90 |
| VultureHelm | Plate | 0x2B72 | 5 | 5 | 1 | 2 | 2 | 5 | 40 | 25/25 | 50-65 | - | Carpentry 63.9 |
| WingedHelm | Plate | 0x2B73 | 5 | 5 | 1 | 2 | 2 | 5 | 40 | 25/25 | 45-55 | - | Carpentry 58.4 |
| WoodenKiteShield | Plate | 0x1B78 | 5 | 0 | 0 | 0 | 0 | 1 | 12 | 20/? | 50-65 | - | Blacksmithy -15.2 |
| WoodenShield | Plate | 0x1B7A | 5 | 0 | 0 | 0 | 0 | 1 | 8 | 20/? | 20-25 | - | Carpentry 52.6 |
| RingmailArms | Ringmail | 0x13EE | 15 | 3 | 3 | 1 | 5 | 3 | 22 | 40/20 | 40-50 | - | Blacksmithy 16.9 |
| RingmailChest | Ringmail | 0x13EC | 15 | 3 | 3 | 1 | 5 | 3 | 22 | 40/20 | 40-50 | - | Blacksmithy 21.9 |
| RingmailGloves | Ringmail | 0x13EB | 2 | 3 | 3 | 1 | 5 | 3 | 22 | 40/20 | 40-50 | - | Blacksmithy 12 |
| RingmailLegs | Ringmail | 0x13F0 | 15 | 3 | 3 | 1 | 5 | 3 | 22 | 40/20 | 40-50 | - | Blacksmithy 19.4 |
| FemaleGargishStoneArms | Stone | 0x0283 | 10 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 56.3 |
| FemaleGargishStoneChest | Stone | 0x0285 | 15 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 55 |
| FemaleGargishStoneKilt | Stone | 0x0287 | 10 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 48.9 |
| FemaleGargishStoneLegs | Stone | 0x0289 | 15 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 58.8 |
| GargishStoneArms | Stone | 0x0284 | 10 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 56.3 |
| GargishStoneChest | Stone | 0x0286 | 15 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 65 |
| GargishStoneKilt | Stone | 0x0288 | 10 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 48.9 |
| GargishStoneLegs | Stone | 0x028A | 15 | 6 | 6 | 4 | 8 | 6 | ? | 40/? | 40-50 | - | Masonry 58.8 |
| FemaleStuddedChest | Studded | 0x1C02 | 6 | 2 | 4 | 3 | 3 | 4 | 16 | 35/35 | 35-45 | Half | Tailoring 87.1 |
| HideChest | Studded | 0x2B74 | 6 | 3 | 3 | 4 | 3 | 2 | 15 | 25/25 | 35-45 | Half | Tailoring 85 |
| HideFemaleChest | Studded | 0x2B79 | 6 | 3 | 3 | 4 | 3 | 2 | 15 | 35/35 | 35-45 | Half | - |
| HideGloves | Studded | 0x2B75 | 2 | 3 | 3 | 4 | 3 | 2 | 15 | 15/15 | 35-45 | Half | Tailoring 75 |
| HideGorget | Studded | 0x2B76 | 3 | 3 | 3 | 4 | 3 | 2 | 15 | 15/15 | 35-45 | Half | Tailoring 90 |
| HidePants | Studded | 0x2B78 | 5 | 3 | 3 | 4 | 3 | 2 | 15 | 25/25 | 35-45 | Half | Tailoring 92 |
| HidePauldrons | Studded | 0x2B77 | 4 | 3 | 3 | 4 | 3 | 2 | 15 | 20/20 | 35-45 | Half | Tailoring 75 |
| StuddedArms | Studded | 0x13DC | 4 | 2 | 4 | 3 | 3 | 4 | 16 | 25/25 | 35-45 | Half | Tailoring 87.1 |
| StuddedBustierArms | Studded | 0x1C0C | 1 | 2 | 4 | 3 | 3 | 4 | 16 | 35/35 | 35-45 | Half | Tailoring 82.9 |
| StuddedChest | Studded | 0x13DB | 8 | 2 | 4 | 3 | 3 | 4 | 16 | 35/35 | 35-45 | Half | Tailoring 94 |
| StuddedDo | Studded | 0x27C7 | 8 | 2 | 4 | 3 | 3 | 4 | 3 | 55/55 | 40-50 | - | Tailoring 95 |
| StuddedGloves | Studded | 0x13D5 | 1 | 2 | 4 | 3 | 3 | 4 | 16 | 25/25 | 35-45 | Half | Tailoring 82.9 |
| StuddedGorget | Studded | 0x13D6 | 1 | 2 | 4 | 3 | 3 | 4 | 16 | 25/25 | 35-45 | Half | Tailoring 78.8 |
| StuddedHaidate | Studded | 0x278B | 5 | 2 | 4 | 3 | 3 | 4 | 3 | 30/30 | 35-45 | - | Tailoring 92 |
| StuddedHiroSode | Studded | 0x277F | 1 | 2 | 4 | 3 | 3 | 4 | 3 | 30/30 | 45-55 | - | Tailoring 85 |
| StuddedLegs | Studded | 0x13DA | 5 | 2 | 4 | 3 | 3 | 4 | 16 | 30/35 | 35-45 | Half | Tailoring 91.2 |
| StuddedMempo | Studded | 0x279D | 2 | 2 | 4 | 3 | 3 | 3 | 3 | 30/30 | 30-40 | - | Tailoring 80 |
| StuddedSuneate | Studded | 0x27D2 | 5 | 2 | 4 | 3 | 3 | 4 | 3 | 30/30 | 35-50 | - | Tailoring 92 |
| FemaleElvenPlateChest | Wood | 0x2B6D | 8 | 5 | 3 | 2 | 3 | 2 | 30 | 95/95 | 50-65 | - | - |
| WoodlandArms | Wood | 0x2B6C | 5 | 5 | 3 | 2 | 3 | 2 | 40 | 80/80 | 50-65 | - | Carpentry 80 |
| WoodlandChest | Wood | 0x2B67 | 8 | 5 | 3 | 2 | 3 | 2 | 40 | 95/95 | 50-65 | - | Carpentry 90 |
| WoodlandGloves | Wood | 0x2B6A | 2 | 5 | 3 | 2 | 3 | 2 | 40 | 70/70 | 50-65 | - | Carpentry 85 |
| WoodlandGorget | Wood | 0x2B69 | ? | 5 | 3 | 2 | 3 | 2 | 40 | 45/45 | 50-65 | - | Carpentry 85 |
| WoodlandLegs | Wood | 0x2B6B | 8 | 5 | 3 | 2 | 3 | 2 | 40 | 90/90 | 50-65 | - | Carpentry 85 |
| AssassinsCowl | - | ? | 3 | 2 | 4 | 4 | 3 | 2 | ? | ?/? | 40-60 | - | Tailoring 90 |
| CowlOfTheMaceAndShield | - | ? | ? | 10 | 10 | 10 | 10 | 10 | ? | ?/? | 255-255 | - | Tailoring 120 |
| CrimsonDaggerBelt | - | ? | ? | ? | ? | ? | ? | ? | ? | ?/? | ?-? | - | Tailoring 120 |
| CrimsonMaceBelt | - | ? | ? | ? | ? | ? | ? | ? | ? | ?/? | ?-? | - | Tailoring 120 |
| CrimsonSwordBelt | - | ? | ? | ? | ? | ? | ? | ? | ? | ?/? | ?-? | - | Tailoring 120 |
| MagesHood | - | ? | 3 | 0 | 3 | 5 | 8 | 8 | ? | ?/? | 20-40 | - | Tailoring 90 |
| MagesHoodOfScholarlyInsight | - | ? | ? | 15 | 15 | 15 | 15 | 15 | ? | ?/? | 255-255 | - | Tailoring 120 |

### 3.3 Reading the armour table for a clone

* **AoS gameplay uses only the five resistance columns.** `ArmorBase` (AR) is dead data in AoS+ — `AOS.Damage` never consults it. **`[HIGH]`**
* **Classic gameplay uses only `AR`.** The five resistances are dead data pre-AoS, except that `ArmorProtectionLevel` shifts them. **`[HIGH]`**
* **A full suit's resistance is the sum of the pieces**; the effective physical resistance is what `AOS.Damage` multiplies against. Typical full plate: `5+5+5+5+5+4+5` ≈ 30-ish physical before magic properties.
* **`Med` column matters for magery:** `None` = cannot meditate in that piece. See §4.7.
* **Dragon scale** armour is `ArmorMaterialType.Dragon` with `DefaultResource = CraftResource.RedScales/…`; the five scale colours map to the five `CraftResource` scale tiers.

### 3.4 Shields, clothing and jewellery layers

**Shields** are in the table above (`Material = Plate` mostly, `Layer.TwoHanded`). Their `ArmorBase` doubles as their AoS physical resistance.

**Jewellery `[HIGH]`** — `Scripts/Items/Equipment/Jewelry/`:

| Item | Layer | Slot purpose |
|---|---|---|
| `Ring` | `Layer.Ring` | one ring slot |
| `Bracelet` | `Layer.Bracelet` | one bracelet slot |
| `Earrings` | `Layer.Earrings` | one earring slot |
| `Necklace` | `Layer.Neck` | neck slot (competes with a gorget) |
| `GargishEarrings` | `Layer.Earrings` | gargoyle variant |
| `GargishNecklace` | `Layer.Neck` | gargoyle variant |
| `Talisman` | `Layer.Talisman` | talisman slot (ML) |

`BaseJewel` exposes the same five resistance overrides plus `AosAttributes` and `AosSkillBonuses` — **jewellery is the only item class that can carry skill bonuses** in the classic AoS property pool (`ItemPropertyInfo` ids 151–183 are `Jewel`-only). **`[HIGH]`** — `Scripts/Services/LootGeneration/ItemPropertyInfo.cs`.

**Clothing / robes `[HIGH]`** — `Scripts/Items/Equipment/Clothing/BaseClothing.cs:386-414` implements the same five resistance overrides, so robes/caps *can* carry resistances. The layer enum values (`Shirt`, `Pants`, `Shoes`, `Cloak`, `OuterTorso`, `MiddleTorso`, `InnerTorso`, `OuterLegs`, `InnerLegs`, `Waist`, `Helm`) come from `Server/Item.cs`; per-item assignment again comes from `tiledata.mul`.

> **Layer availability warning.** Because layer comes from `tiledata.mul`, a clone that does not ship client tiledata must hard-code a layer→slot map. Build it from the `ArmorBodyType` switch in `BaseArmor.cs:1296-1326`, which is the server's own layer→body-part mapping and is **`[HIGH]`**:
> `Neck → Gorget`, `TwoHanded → Shield`, `Gloves → Gloves`, `Helm → Helmet`, `Arms → Arms`, `InnerLegs/OuterLegs/Pants → Legs`, `InnerTorso/OuterTorso/Shirt → Chest`.

### 3.5 Craft skill requirements

These are **exact `AddCraft` minimums** parsed from ServUO's craft definitions. **`[HIGH]`**

| Item | Skill | Min | Max | Resource | Qty |
|---|---|---|---|---|---|
| LeatherCap | Tailoring | 6.2 | 31.2 | Leather | 2 |
| LeatherGloves | Tailoring | 51.8 | 76.8 | Leather | 3 |
| LeatherGorget | Tailoring | 53.9 | 78.9 | Leather | 4 |
| LeatherArms | Tailoring | 53.9 | 78.9 | Leather | 4 |
| LeatherLegs | Tailoring | 66.3 | 91.3 | Leather | 10 |
| LeatherChest | Tailoring | 70.5 | 95.5 | Leather | 12 |
| StuddedChest | Tailoring | 94.0 | 119.0 | Leather | 14 |
| BoneChest | Tailoring | 96.0 | 121.0 | Leather | 12 |
| RingmailGloves | Blacksmithy | 12.0 | 62.0 | IronIngot | 10 |
| RingmailArms | Blacksmithy | 16.9 | 66.9 | IronIngot | 14 |
| RingmailLegs | Blacksmithy | 19.4 | 69.4 | IronIngot | 16 |
| RingmailChest | Blacksmithy | 21.9 | 71.9 | IronIngot | 18 |
| ChainCoif | Blacksmithy | 14.5 | 64.5 | IronIngot | 10 |
| ChainLegs | Blacksmithy | 36.7 | 86.7 | IronIngot | 18 |
| ChainChest | Blacksmithy | 39.1 | 89.1 | IronIngot | 20 |
| PlateGorget | Blacksmithy | 56.4 | 106.4 | IronIngot | 10 |
| PlateGloves | Blacksmithy | 58.9 | 108.9 | IronIngot | 12 |
| PlateArms | Blacksmithy | 66.3 | 116.3 | IronIngot | 18 |
| PlateLegs | Blacksmithy | 68.8 | 118.8 | IronIngot | 20 |
| PlateChest | Blacksmithy | 75.0 | 125.0 | IronIngot | 25 |
| FemalePlateChest | Blacksmithy | 44.1 | 94.1 | IronIngot | 20 |
| Buckler | Blacksmithy | −25.0 | 25.0 | IronIngot | 10 |
| BronzeShield | Blacksmithy | −15.2 | 34.8 | IronIngot | 12 |
| MetalShield | Blacksmithy | −10.2 | 39.8 | IronIngot | 14 |
| MetalKiteShield | Blacksmithy | 4.6 | 54.6 | IronIngot | 16 |
| HeaterShield | Blacksmithy | 24.3 | 74.3 | IronIngot | 18 |
| LargePlateShield | Blacksmithy | 24.3 | 74.3 | IronIngot | 18 |
| OrderShield | Blacksmithy | 85.0 | 135.0 | IronIngot | 25 |
| ChaosShield | Blacksmithy | 85.0 | 135.0 | IronIngot | 25 |
| DragonBardingDeed | Blacksmithy | 72.5 | 122.5 | IronIngot | 750 |
| PlateMempo / PlateDo | Blacksmithy | 80.0 | 130.0 | IronIngot | 18 / 28 |
| PlateSuneate / PlateHaidate | Blacksmithy | 65.0 | 115.0 | IronIngot | 20 |

Full recipe data (all 196 Blacksmithy + 198 Tailoring + 27 BowFletching + 224 Carpentry + 59 Masonry + 22 Glassblowing recipes) was parsed to `research/_src/craft_raw.json`.

### 3.6 Armour material tiers

**`[HIGH]`** — `Scripts/Misc/ResourceInfo.cs:177-408`. Armour material bonuses are **flat resistance points added to the piece**, plus durability/luck/lower-requirement.

| Material | Phys | Fire | Cold | Pois | Ener | Durability | Luck | Lower Req | Runic attrs | Runic intensity pre-ML | ML |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Iron | — | — | — | — | — | — | — | — | — | — | — |
| Dull Copper | **+10** | — | — | — | — | **+50 %** | — | +20 % | 1–2 | 10–35 | 40–100 |
| Shadow Iron | +3 | +2 | — | — | **+7** | **+100 %** | — | — | 2–2 | 20–45 | 45–100 |
| Copper | +2 | +2 | — | **+7** | +2 | — | — | — | 2–3 | 25–50 | 50–100 |
| Bronze | +3 | — | **+7** | +2 | +2 | — | — | — | 3–3 | 30–65 | 55–100 |
| Gold | +2 | +2 | +2 | — | +3 | — | **+40** | +30 % | 3–4 | 35–75 | 60–100 |
| Agapite | +2 | **+7** | +2 | +2 | +2 | — | — | — | 4–4 | 40–80 | 65–100 |
| Verite | **+4** | **+4** | +3 | **+4** | +1 | — | — | — | 4–5 | 45–90 | 70–100 |
| Valorite | **+5** | — | **+4** | **+4** | **+4** | +50 % | — | — | 5–5 | 50–100 | 85–100 |
| Spined Leather | **+9** | — | — | — | — | — | +40 | — | 1–3 | 20–40 | 40–100 |
| Horned Leather | — | — | — | — | — | — | — | — | 3–? | 40–75 (see source) | 45–100 |
| Barbed Leather | — | — | — | — | — | — | — | — | 4–? | 45–90 (see source) | 70–100 |

**Note the pattern:** each metal is *thematic* — it funnels its bonus into one or two resistances. Dull Copper = physical + durability (the classic tanking metal). Verite and Valorite are the only broadly-balanced metals.

**Wood tiers (Carpentry, `ResourceInfo.cs:477-558`) `[HIGH]`:**

| Wood | Runic attrs min | Runic intensity |
|---|---|---|
| Oak | 1 | 50 |
| Ash | 2 | 75 |
| Yew | 3 | 90 |
| Heartwood | 4 | 100 |
| Bloodwood / Frostwood | see source (past excerpt) | — |

**Heartwood is special-cased `[HIGH]`** — `BaseWeapon.cs:6480-6499`: instead of applying all material bonuses, it rolls **one** of six effects at random: `WeaponDamage`, `WeaponSpeed`, `AttackChance`, `Luck`, `LowerStatReq`, or `HitLeechHits`.

---

## 4. MAGERY

### 4.1 Spell data structure

Each spell is a class deriving `MagerySpell` with a static `SpellInfo` giving the display name, power words, action id, sound id and reagent list. **All 64 spells were parsed mechanically.** **`[HIGH]`** — `Scripts/Spells/{First…Eighth}/*.cs`, base class `Scripts/Spells/Base/MagerySpell.cs`.

```csharp
// Scripts/Spells/Base/MagerySpell.cs
private static readonly int[] m_ManaTable = new int[] { 4, 6, 9, 11, 14, 20, 40, 50 };
private const double ChanceOffset = 20.0, ChanceLength = 100.0 / 7.0;

public override int GetMana() {
    if (Scroll is BaseWand) return 0;
    return m_ManaTable[(int)Circle];
}
public override TimeSpan CastDelayBase {
    get { return TimeSpan.FromMilliseconds(((4 + (int)Circle) * CastDelaySecondsPerTick) * 1000); }
}
public override void GetCastSkills(out double min, out double max) {
    int circle = (int)Circle;
    if (Scroll != null) circle -= 2;                 // scrolls are 2 circles easier
    double avg = ChanceLength * circle;              // ChanceLength = 100/7 ≈ 14.2857
    min = avg - ChanceOffset;                        // ChanceOffset = 20
    max = avg + ChanceOffset;
}
```

### 4.2 Mana cost, cast delay, and skill requirement — the numbers

| Circle | Mana | `CastDelayBase` | Spell (non-scroll) `min–max` Magery to cast | Scroll `min–max` |
|---|---|---|---|---|
| **1st** | **4** | `(4+0)×0.25` = **1.00 s** | −20.0 to 20.0 | −100.0 to −60.0 |
| **2nd** | **6** | `(4+1)×0.25` = **1.25 s** | −5.71 to 34.29 | −85.71 to −45.71 |
| **3rd** | **9** | `(4+2)×0.25` = **1.50 s** | 8.57 to 48.57 | −71.43 to −31.43 |
| **4th** | **11** | `(4+3)×0.25` = **1.75 s** | 22.86 to 62.86 | −57.14 to −17.14 |
| **5th** | **14** | `(4+4)×0.25` = **2.00 s** | 37.14 to 77.14 | −42.86 to −2.86 |
| **6th** | **20** | `(4+5)×0.25` = **2.25 s** | 51.43 to 91.43 | −28.57 to 11.43 |
| **7th** | **40** | `(4+6)×0.25` = **2.50 s** | 65.71 to 105.71 | −14.29 to 25.71 |
| **8th** | **50** | `(4+7)×0.25` = **3.00 s** | 80.00 to 120.00 | 0.00 to 40.00 |

**`[HIGH]`** for mana and `CastDelayBase` (both from source constants). **`[MED]`** for the skill bands: the formula is source-exact, but the *scalar* `d = avg = 100/7 × circle` is a linear approximation, not the OSI per-circle table. The classic UO player-facing table is `1st ≈ −20…20, 2nd ≈ 0…40, 3rd ≈ 20…60, 4th ≈ 40…80, 5th ≈ 55…95, 6th ≈ 70…110, 7th ≈ 85…125, 8th ≈ 100…?`. ServUO's approximation matches circles 1 and 8 and diverges in between (e.g. 5th: ServUO says 37.14–77.14, the player table says ~55–95). **Use ServUO's formula for a ServUO-faithful clone; use the classic table for an OSI-faithful clone.**

> **UOGuide's cast-time claim is wrong for circles 1–3 and 8.** UOGuide says *"the casting time of a spell is determined by the circle number. The formula is 0.25 + spell circle × 0.25 seconds"* → 1st 0.5 s, 8th 2.25 s ([UOGuide: Magery](https://www.uoguide.com/Magery)). ServUO's source is `(4 + circle) × 0.25` → 1st **1.00 s**, 8th **3.00 s**. The two agree only at circles 4–7. **The source wins.** **`[HIGH]`** for the code, **`[LOW]`** for the wiki.

**Pre-AoS override `[HIGH]`** — `MagerySpell.GetCastDelay()`:
```csharp
if (!Core.ML && Scroll is BaseWand) return TimeSpan.Zero;         // wands are instant pre-ML
if (!Core.AOS) return TimeSpan.FromSeconds(0.5 + (0.25 * (int)Circle));
return base.GetCastDelay();
```
So **classic cast delay = `0.5 + 0.25 × circle`** seconds — 1st **0.75 s**, 8th **2.50 s**. **The classic and AoS cast-delay formulas are different.** This is exactly the distinction UOGuide blurred.

### 4.3 Faster Casting (FC) and Faster Cast Recovery (FCR)

```csharp
// SU Scripts/Spells/Base/Spell.cs:1025-1086
public abstract TimeSpan CastDelayBase { get; }
public virtual double CastDelayFastScalar { get { return 1; } }
public virtual double CastDelaySecondsPerTick { get { return 0.25; } }
public virtual TimeSpan CastDelayMinimum { get { return TimeSpan.FromSeconds(0.25); } }

public virtual TimeSpan GetCastDelay()
{
    if (m_Scroll is SpellStone) return TimeSpan.Zero;
    if (m_Scroll is BaseWand)  return Core.ML ? CastDelayBase : TimeSpan.Zero;

    int fcMax = 4;                                             // Paladin/F default cap
    if (CastSkill == Magery || CastSkill == Necromancy || CastSkill == Mysticism ||
        (CastSkill == Chivalry && (Magery >= 70 || Mysticism >= 70)))
        fcMax = 2;                                             // ← MAGERY FC CAP IS 2

    int fc = AosAttributes.GetValue(m_Caster, AosAttribute.CastSpeed);
    if (fc > fcMax) fc = fcMax;

    if (ProtectionSpell.Registry.ContainsKey(m_Caster) || EodonianPotion…)
        fc = Math.Min(fcMax - 2, fc - 2);                      // Protection costs you 2 FC

    TimeSpan baseDelay = CastDelayBase;
    TimeSpan fcDelay = TimeSpan.FromSeconds(-(CastDelayFastScalar * fc * CastDelaySecondsPerTick));
    TimeSpan delay = baseDelay + fcDelay;                      // each FC point = −0.25 s
    if (delay < CastDelayMinimum) delay = CastDelayMinimum;    // floor 0.25 s
    if (DreadHorn.IsUnderInfluence(m_Caster)) delay.Add(delay); // Dread Horn doubles it
    return delay;
}
```

```
cast_delay = clamp( (4 + circle) × 0.25 − fc × 0.25 , min = 0.25 )     // AoS+
cast_delay = 0.5 + 0.25 × circle                                        // classic, FC does not exist
```

| FC | 8th-circle cast delay (AoS) | 1st-circle |
|---|---|---|
| 0 | 3.00 s | 1.00 s |
| 1 | 2.75 s | 0.75 s |
| **2 (cap)** | **2.50 s** | **0.50 s** |
| 2 **while under Protection** | 3.00 s (fc forced to 0) | 1.00 s |

**`[HIGH]`. Faster Casting cap = 2 for Magery.** Protection reduces your effective FC by 2 (floored by `fcMax − 2`).

```csharp
// SU Scripts/Spells/Base/Spell.cs:999-1023
public virtual int CastRecoveryBase      { get { return 6; } }
public virtual int CastRecoveryFastScalar{ get { return 1; } }
public virtual int CastRecoveryPerSecond { get { return 4; } }
public virtual int CastRecoveryMinimum   { get { return 0; } }
public virtual TimeSpan GetCastRecovery()
{
    if (!Core.AOS) return NextSpellDelay;                        // classic: fixed 0.75 s
    int fcr = AosAttributes.GetValue(m_Caster, AosAttribute.CastRecovery);
    int fcrDelay = -(CastRecoveryFastScalar * fcr);
    int delay = CastRecoveryBase + fcrDelay;
    if (delay < CastRecoveryMinimum) delay = CastRecoveryMinimum;
    return TimeSpan.FromSeconds((double)delay / CastRecoveryPerSecond);
}
```
```
recovery_seconds = max(6 − FCR, 0) / 4
```
| FCR | Recovery |
|---|---|
| 0 | 1.50 s |
| 1 | 1.25 s |
| 2 | 1.00 s |
| 3 | 0.75 s |
| 4 | 0.50 s |
| 5 | 0.25 s |
| **6** | **0.00 s** |

**`[HIGH]`. FCR cap = 6, which zeroes the recovery.** Pre-AoS uses `NextSpellDelay = TimeSpan.FromSeconds(0.75)` — a flat **0.75 s** regardless of FCR. **`[HIGH]`** — `Spell.cs:49`, `:1008`.

```csharp
// SU Scripts/Spells/Base/Spell.cs:982-997 — pre-AoS interruption recovery
public virtual TimeSpan GetDisturbRecovery()
{
    if (Core.AOS) return TimeSpan.Zero;
    double delay = 1.0 - Math.Sqrt((Core.TickCount - m_StartCastTime) / 1000.0 / GetCastDelay().TotalSeconds);
    if (delay < 0.2) delay = 0.2;
    return TimeSpan.FromSeconds(delay);
}
```
In classic, being interrupted costs you a **square-root-of-progress** penalty, floored at **0.2 s**. In AoS+ interruption costs nothing extra beyond the FCR recovery. **`[HIGH]`**

The recovery is written back as `m_Caster.NextSpellTime = Core.TickCount + (int)m_Spell.GetCastRecovery().TotalMilliseconds;` **`[HIGH]`** — `Spell.cs:1361`.

### 4.4 Casting, fizzle, and interruption

```csharp
// SU Scripts/Spells/Base/Spell.cs:924-943
public virtual bool CheckFizzle()
{
    if (m_Scroll is BaseWand) return true;                 // wands never fizzle
    double minSkill, maxSkill;
    GetCastSkills(out minSkill, out maxSkill);
    if (DamageSkill != CastSkill && DamageSkill != SkillName.Imbuing)
        Caster.CheckSkill(DamageSkill, 0.0, Caster.Skills[DamageSkill].Cap);   // passive EvalInt gain
    bool skillCheck = Caster.CheckSkill(CastSkill, minSkill, maxSkill);
    return Caster is BaseCreature || skillCheck;           // NPCs never fizzle
}
```
**`[HIGH]`.** Resolution is a `CheckSkill(skill, min, max)` band, not a threshold: below `min` you always fail, above `max` you always succeed, and between them the chance is linear. **`[HIGH]`** — `Server/SkillCheck.cs` semantics.

```csharp
// SU Scripts/Spells/Base/Spell.cs:243-320
public virtual void OnCasterHurt() { CheckCasterDisruption(false, 0, 0, 0, 0, 0); }

public virtual void CheckCasterDisruption(bool checkElem = false, int phys = 0, int fire = 0,
                                          int cold = 0, int pois = 0, int nrgy = 0)
{
    if (!Caster.Player || Caster.AccessLevel > AccessLevel.Player) return;   // NPC/staff never interrupted
    if (IsCasting) {
        object o = ProtectionSpell.Registry[m_Caster];
        bool disturb = true;
        if (o != null && o is double) {
            if (((double)o) > Utility.RandomDouble() * 100.0) disturb = false;   // Protection roll
        }
        … if (disturb) Disturb(DisturbType.Hurt, false, true);
    }
}
```
* **Protection stores a percentage in `ProtectionSpell.Registry`; if `protection% > RandomDouble()×100` the interruption is cancelled.** **`[HIGH]`** for the mechanism.
* The `DisturbType` enum values are `Hurt, Kill, EquipRequest, UseRequest, NewCast` and more — **`[HIGH]`** — `Scripts/Spells/Base/DisturbType.cs`.
* `Disturb(DisturbType.Hurt, false, true)` — the third parameter marks it *resistable*. **`[HIGH]`**
* A wand's `Disturb` is suppressed: `if (resistable && m_Scroll is BaseWand) …` **`[HIGH]`** — `Spell.cs:596`.
* Casting is refused while paralyzed or frozen, and wands are exempt: `else if (!(m_Scroll is BaseWand) && (m_Caster.Paralyzed || m_Caster.Frozen))` **`[HIGH]`** — `Spell.cs:755`.
* **The Protection chance formula itself** (the percentage written into the registry) lives in `Scripts/Spells/Second/Protection.cs` and was **not** read line-by-line → **`[UNVERIFIED]`**. To settle: read `Protection.cs` (the `Registry[m_Caster] = …` assignment).

### 4.5 The 64 spells

Mana is per-circle (§4.2). "Target" is the `TargetFlags`/target-constructor range where extractable. Damage formulas are quoted from each spell's `OnCast`/`Target`.

#### First Circle — 4 mana, `CastDelayBase` 1.00 s

| # | Spell | Power words | Action | Sound | Reagents | Target | Effect / damage |
|---|---|---|---|---|---|---|---|
| 1 | **Clumsy** | Uus Jux | 203 | 0x1E2 | Bloodmoss, Nightshade | Beneficial/Harmful, mobile, range 12 (10 ML) | `−Dex` stat curse. Offset magnitude and duration per §4.6 |
| 2 | **Create Food** | In Mani Ylem | 204 | 0x1E3 | Garlic, Ginseng, MandrakeRoot | Point, range 12 (10 ML) | Spawns a random `Food` on the ground |
| 3 | **Feeblemind** | Rel Wis | 204 | 0x1E4 | Ginseng, Nightshade | Harmful, mobile, range 12 (10 ML) | `−Int` stat curse |
| 4 | **Heal** | In Mani | 204 | 0x1F3 | Garlic, Ginseng, SpidersSilk | Beneficial, mobile, range 12 (10 ML) | Heals `(EvalInt/100 × 20) + Random(1, 4) + 1` — see formula note below |
| 5 | **Magic Arrow** | In Por Ylem | 203 | 0x1E5 | SulfurousAsh | Harmful, mobile, range 12 (10 ML) | `GetNewAosDamage(10, 1, 4, target)` → base `1d4+10` |
| 6 | **Night Sight** | In Lor | 203 | 0x1E6 | SulfurousAsh, SpidersSilk | Beneficial, mobile, range 12 (10 ML) | Personal light source; duration per §4.6 |
| 7 | **Reactive Armor** | Kal Des Ylem | 204 | 0x1F2 | Garlic, SpidersSilk, SulfurousAsh | Beneficial, mobile, range 12 (10 ML) | Reflective armour; duration per §4.6 |
| 8 | **Weaken** | Des Mani | 204 | 0x1E7 | Garlic, Nightshade | Harmful, mobile, range 12 (10 ML) | `−Str` stat curse |

#### Second Circle — 6 mana, 1.25 s

| # | Spell | Power words | Reagents | Target | Effect |
|---|---|---|---|---|---|
| 9 | **Agility** | Rel Sanct Ylem | Bloodmoss, MandrakeRoot | Beneficial | `+Dex` |
| 10 | **Cunning** | Uus Wis | MandrakeRoot, Nightshade | Beneficial | `+Int` |
| 11 | **Cure** | An Nox | Garlic, Ginseng | Beneficial | Cures poison (`Mobile.CurePoison`) |
| 12 | **Harm** | An Mani | Nightshade, SpidersSilk | Harmful | `GetNewAosDamage(10, 1, 5, target)` → `1d5+10`; **no damage on the caster** |
| 13 | **Magic Trap** | In Jux | Garlic, SpidersSilk, SulfurousAsh | Item, range 12 (10 ML) | Traps a container |
| 14 | **Protection** | Uus Sanct | Garlic, Ginseng, SulfurousAsh | Beneficial | Prevents interruption (§4.4); costs 2 FC (§4.3) |
| 15 | **Remove Trap** | An Jux | Bloodmoss, SulfurousAsh | Item, range 12 (10 ML) | Untraps a container |
| 16 | **Strength** | Uus Mani | MandrakeRoot, Nightshade | Beneficial | `+Str` |

#### Third Circle — 9 mana, 1.50 s

| # | Spell | Power words | Reagents | Target | Effect / damage |
|---|---|---|---|---|---|
| 17 | **Bless** | Rel Sanct | Garlic, MandrakeRoot | Beneficial | `+Str +Dex +Int` |
| 18 | **Fireball** | Vas Flam | BlackPearl | Harmful, range 12 (10 ML) | `GetNewAosDamage(19, 1, 5, target)` → `1d5+19`; damage split `fire = 100`; spell effect `0x36D4`; sound `0x15E` (AoS) / `0x44B` (classic) |
| 19 | **Magic Lock** | An Por | Garlic, Bloodmoss, SulfurousAsh | Item | Locks a container |
| 20 | **Poison** | In Nox | Nightshade | Harmful | Applies poison (level scales with Magery/Poisoning) |
| 21 | **Telekinesis** | Ort Por Ylem | Bloodmoss, MandrakeRoot | Item | Remote use |
| 22 | **Teleport** | Rel Por | Bloodmoss, MandrakeRoot | Point | Blink |
| 23 | **Unlock** | Ex Por | Bloodmoss, SulfurousAsh | Item | Unlocks |
| 24 | **Wall of Stone** | In Sanct Ylem | Bloodmoss, Garlic | Point | Field (the reagent list includes a leading `false` = a field-spell flag, not a reagent) |

#### Fourth Circle — 11 mana, 1.75 s

| # | Spell | Power words | Reagents | Effect / damage |
|---|---|---|---|---|
| 25 | **Arch Cure** | Vas An Nox | Garlic, Ginseng, MandrakeRoot | Mass cure |
| 26 | **Arch Protection** | Vas Uus Sanct | Garlic, Ginseng, MandrakeRoot, SulfurousAsh | Mass protection |
| 27 | **Curse** | Des Sanct | Nightshade, Garlic, SulfurousAsh | `−Str −Dex −Int` |
| 28 | **Fire Field** | In Flam Grav | BlackPearl, SpidersSilk, SulfurousAsh | Fire field, per-tick damage |
| 29 | **Greater Heal** | In Vas Mani | Garlic, Ginseng, MandrakeRoot, SpidersSilk | Larger heal |
| 30 | **Lightning** | Por Ort Grav | MandrakeRoot, SulfurousAsh | `GetNewAosDamage(23, 1, 4, target)`, energy split |
| 31 | **Mana Drain** | Ort Rel | BlackPearl, MandrakeRoot, SpidersSilk | Drains mana, transfers to caster |
| 32 | **Recall** | Kal Ort Por | BlackPearl, Bloodmoss, MandrakeRoot | Travel to a rune |

#### Fifth Circle — 14 mana, 2.00 s

| # | Spell | Power words | Reagents | Effect |
|---|---|---|---|---|
| 33 | **Blade Spirits** | In Jux Hur Ylem | BlackPearl, MandrakeRoot, Nightshade | Summons a blade spirit |
| 34 | **Dispel Field** | An Grav | BlackPearl, SpidersSilk, SulfurousAsh, Garlic | Removes a field |
| 35 | **Incognito** | Kal In Ex | Bloodmoss, Garlic, Nightshade | Disguise |
| 36 | **Magic Reflection** | In Jux Sanct | Garlic, MandrakeRoot, SpidersSilk | Reflects spells |
| 37 | **Mind Blast** | Por Corp Wis | BlackPearl, MandrakeRoot, Nightshade, SulfurousAsh | `GetNewAosDamage(40, 1, 5, playerVsPlayer)` — **mana also drains the target** |
| 38 | **Paralyze** | An Ex Por | Garlic, MandrakeRoot, SpidersSilk | Freeze |
| 39 | **Poison Field** | In Nox Grav | BlackPearl, Nightshade, SpidersSilk | Poison field |
| 40 | **Summon Creature** | Kal Xen | Bloodmoss, MandrakeRoot, SpidersSilk | Summons a random creature |

#### Sixth Circle — 20 mana, 2.25 s

| # | Spell | Power words | Reagents | Effect / damage |
|---|---|---|---|---|
| 41 | **Dispel** | An Ort | Garlic, MandrakeRoot, SulfurousAsh | Dispels a summon |
| 42 | **Energy Bolt** | Corp Por | BlackPearl, Nightshade | `GetNewAosDamage(40, 1, 5, target)`, energy split |
| 43 | **Explosion** | Vas Ort Flam | Bloodmoss, MandrakeRoot | `DelayedDamage = true` → damage applied after the AoS delay; fire split |
| 44 | **Invisibility** | An Lor Xen | Bloodmoss, Nightshade | Invisibility |
| 45 | **Mark** | Kal Por Ylem | BlackPearl, Bloodmoss, MandrakeRoot | Marks a rune |
| 46 | **Mass Curse** | Vas Des Sanct | Garlic, Nightshade, MandrakeRoot, SulfurousAsh | Mass curse |
| 47 | **Paralyze Field** | In Ex Grav | BlackPearl, Ginseng, SpidersSilk | Paralyze field |
| 48 | **Reveal** | Wis Quas | Bloodmoss, SulfurousAsh | Reveals hidden |

#### Seventh Circle — 40 mana, 2.50 s

| # | Spell | Power words | Reagents | Effect / damage |
|---|---|---|---|---|
| 49 | **Chain Lightning** | Vas Ort Grav | BlackPearl, Bloodmoss, MandrakeRoot, SulfurousAsh | Energy, chains to nearby targets |
| 50 | **Energy Field** | In Sanct Grav | BlackPearl, MandrakeRoot, SpidersSilk, SulfurousAsh | Energy field |
| 51 | **Flame Strike** | Kal Vas Flam | SpidersSilk, SulfurousAsh | `GetNewAosDamage(48, 1, 5, target)`, fire split |
| 52 | **Gate Travel** | Vas Rel Por | BlackPearl, MandrakeRoot, SulfurousAsh | Moongate |
| 53 | **Mana Vampire** | Ort Sanct | BlackPearl, Bloodmoss, MandrakeRoot, SpidersSilk | Drains mana from all in range |
| 54 | **Mass Dispel** | Vas An Ort | Garlic, MandrakeRoot, BlackPearl, SulfurousAsh | Dispels all summons in range |
| 55 | **Meteor Swarm** | Flam Grav | Bloodmoss, MandrakeRoot, SulfurousAsh, SpidersSilk | **`GetMana()` override returns `0`** in this file — **`[UNVERIFIED]`**: verify against `m_ManaTable[6] = 40`; the override may be a ServUO bug |
| 56 | **Polymorph** | Vas Ylem Rel | Bloodmoss, SpidersSilk, MandrakeRoot | Shapeshift |

#### Eighth Circle — 50 mana, 3.00 s

| # | Spell | Power words | Reagents | Effect |
|---|---|---|---|---|
| 57 | **Air Elemental** | Kal Vas Xen Hur | Bloodmoss, MandrakeRoot, SpidersSilk | Summons an air elemental |
| 58 | **Earth Elemental** | Kal Vas Xen Ylem | Bloodmoss, MandrakeRoot, SpidersSilk | Summons an earth elemental |
| 59 | **Earthquake** | In Vas Por | Bloodmoss, Ginseng, MandrakeRoot, SulfurousAsh | AoE physical |
| 60 | **Energy Vortex** | Vas Corp Grav | Bloodmoss, BlackPearl, MandrakeRoot, Nightshade | Summons an energy vortex |
| 61 | **Fire Elemental** | Kal Vas Xen Flam | Bloodmoss, MandrakeRoot, SpidersSilk, SulfurousAsh | Summons a fire elemental |
| 62 | **Resurrection** | An Corp | Bloodmoss, Garlic, Ginseng | Resurrects a ghost |
| 63 | **Summon Daemon** | Kal Vas Xen Corp | Bloodmoss, MandrakeRoot, SpidersSilk, SulfurousAsh | Summons a daemon |
| 64 | **Water Elemental** | Kal Vas Xen An Flo | Bloodmoss, MandrakeRoot, SpidersSilk | Summons a water elemental |

> **Reagent counts are 1 of each listed reagent** in every magery spell — the parsed `SpellInfo` constructors contain only `typeof`-style reagent references with no quantity multiplier, and `Spell.ConsumeReagents` calls `pack.ConsumeTotal(m_Info.Reagents, m_Info.Amounts)` where the amount array is all ones for magery. **`[HIGH]`**
>
> **Field spells** (`Wall of Stone`, `Fire Field`, `Poison Field`, `Energy Field`, `Paralyze Field`, `Blade Spirits`, `Mass Curse`, `Chain Lightning`, the elementals, `Earthquake`, `Energy Vortex`, `Summon Daemon`, `Water Elemental`) pass a leading **`false`** argument to `SpellInfo` before the reagent list. That is a **field-spell flag**, not a reagent named `false`. **`[HIGH]`**

### 4.6 The AoS damage formula, Evaluating Intelligence, and resistances

**This is the master damage formula for magery in AoS and later. [`HIGH`] — `Scripts/Spells/Base/Spell.cs:201-239`.**

```csharp
public virtual int GetNewAosDamage(int bonus, int dice, int sides, bool playerVsPlayer, double scalar, IDamageable damageable)
{
    Mobile target = damageable as Mobile;

    int damage = Utility.Dice(dice, sides, bonus) * 100;      // ← ×100 to keep precision

    int inscribeSkill = GetInscribeFixed(m_Caster);            // Inscription × 10 (Fixed)
    int scribeBonus   = inscribeSkill >= 1000 ? 10 : inscribeSkill / 200;
    //                   ↑ GM (100.0 → 1000 fixed) = +10 ; otherwise 0.5 per 10 skill points

    int damageBonus = scribeBonus
                    + (Caster.Int / 10)
                    + SpellHelper.GetSpellDamageBonus(m_Caster, target, CastSkill, playerVsPlayer);

    int evalSkill = GetDamageFixed(m_Caster);                  // EvalInt × 10
    int evalScale = 30 + ((9 * evalSkill) / 100);
    //               ↑ evalSkill is ×10, so this is 30 + 0.9 × EvalInt

    damage = AOS.Scale(damage, evalScale);                     // damage = damage × evalScale / 100
    damage = AOS.Scale(damage, 100 + damageBonus);
    damage = AOS.Scale(damage, (int)(scalar * 100));
    return damage / 100;
}
```

```
raw        = (dice rolls of `sides` + `bonus`) × 100
scribe     = (Inscription < 100) ? Inscription × 5 : 10          // % ; +10 % at GM
intBonus   = Int / 10                                            // % ; +10 % at Int 100
sdi        = Spell Damage Increase property (PvP-capped, see below)
evalScale  = 30 + 0.9 × EvaluatingIntelligence                   // % ; 30 % at 0 EvalInt, 120 % at 100, 138 % at 120
dmg        = raw × evalScale/100 × (100 + scribe + intBonus + sdi)/100 × scalar
```
Note the triple `AOS.Scale` operates on the ×100-scaled integer, so intermediate truncation happens three times. **Reproduce that ordering exactly** if you want bit-identical numbers.

| Evaluating Intelligence | `evalScale` |
|---|---|
| 0 | 30 % |
| 50 | 75 % |
| 100 | 120 % |
| 120 | 138 % |

**`[HIGH]`.** So EvalInt is worth **+0.9 % spell damage per point** — a huge lever, which is why it is a standard mage skill.

**PvP spell-damage cap `[HIGH]`** — `SpellHelper.cs:108-144`:
```csharp
public static int PvPSpellDamageCap(Mobile m, SkillName castskill) {
    if (!Core.SA) return 15;
    if (HasSpellFocus(m, castskill)) return 30;
    else return Core.TOL ? 20 : 15;
}
// "PvP spell damage increase cap of 15% from an item's magic property, 30% if spell school focused."
if (Core.SE && playerVsPlayer) sdiBonus = Math.Min(sdiBonus, PvPSpellDamageCap(caster, skill));
```
`HasSpellFocus` requires every *other* magic school to be **< 30.0** skill. **`[HIGH]`** — `SpellHelper.cs:95-106`.

**Damage delay `[HIGH]`** — `SpellHelper.cs:147-156`:
```csharp
private static readonly TimeSpan AosDamageDelay = TimeSpan.FromSeconds(1.0);
private static readonly TimeSpan OldDamageDelay = TimeSpan.FromSeconds(0.5);
public static TimeSpan GetDamageDelayForSpell(Spell sp)
{ return !sp.DelayedDamage ? TimeSpan.Zero : (Core.AOS ? AosDamageDelay : OldDamageDelay); }
```
**AoS delayed damage = 1.0 s; classic = 0.5 s.** Only spells with `DelayedDamage == true` (Fireball, Explosion, Lightning, …) use it.

**Resistance `[HIGH]`** — `Scripts/Spells/Base/MagerySpell.cs`:
```csharp
public virtual bool CheckResisted(Mobile target)
{
    double n = GetResistPercent(target) / 100.0;
    if (n <= 0.0) return false;
    if (n >= 1.0) return true;
    int maxSkill = (1 + (int)Circle) * 10;
    maxSkill += (1 + ((int)Circle / 6)) * 25;
    if (target.Skills[MagicResist].Value < maxSkill)
        target.CheckSkill(SkillName.MagicResist, 0.0, target.Skills[MagicResist].Cap);   // passive gain
    return (n >= Utility.RandomDouble());
}
public virtual double GetResistPercentForCircle(Mobile target, SpellCircle circle)
{
    double value = GetResistSkill(target);
    double firstPercent  = value / 5.0;
    double secondPercent = value - (((Caster.Skills[CastSkill].Value - 20.0) / 5.0) + (1 + (int)circle) * 5.0);
    return (firstPercent > secondPercent ? firstPercent : secondPercent) / 2.0;
    //                ← source comment: "Seems should be about half of what stratics says."
}
```

```
first  = MagicResist / 5
second = MagicResist − ( (CasterSkill − 20)/5 + (1 + circle) × 5 )
resist% = max(first, second) / 2
```
**`[HIGH]`** for the code; **`[MED]`** for whether it matches OSI — the source itself flags the discrepancy with Stratics. `GetResistSkill(m)` is `MagicResist − EvilOmenSpell.GetResistMalus(m)`. **`[HIGH]`** — `Spell.cs:439-442`.

Resisting a spell does **not** nullify it; it reduces damage/duration. For the classic path, `GetDamageScalar` (below) is where resisting shows up.

**When the resist check succeeds, the spell does reduced damage.** `Fireball.Target` shows the pattern **`[HIGH]`**:
```csharp
if (Core.AOS) { damage = GetNewAosDamage(19, 1, 5, m); }
else if (m is Mobile) {
    damage = Utility.Random(10, 7);
    if (CheckResisted((Mobile)m)) { damage *= 0.75; /* 501783 "You feel yourself resisting magical energy." */ }
    damage *= GetDamageScalar((Mobile)m);
}
```
**Classic resist = ×0.75 on the damage roll.** **`[HIGH]`**

**Classic spell damage scalar `[HIGH]`** — `Spell.cs:444-483`:
```csharp
public virtual double GetDamageScalar(Mobile target)
{
    double scalar = 1.0;
    if (target == null) return scalar;
    if (!Core.AOS) {
        double casterEI  = m_Caster.Skills[DamageSkill].Value;      // EvalInt
        double targetRS  = target.Skills[MagicResist].Value;
        if (casterEI > targetRS) scalar = (1.0 + ((casterEI - targetRS) / 500.0));
        else                     scalar = (1.0 + ((casterEI - targetRS) / 200.0));
        // magery damage bonus, -25% at 0 skill, +0% at 100 skill, +5% at 120 skill
        scalar += (m_Caster.Skills[CastSkill].Value - 100.0) / 400.0;
        if (!target.Player && !target.Body.IsHuman) scalar *= 2.0;   // Double magery damage to monsters/animals if not AOS
    }
    if (target is BaseCreature) ((BaseCreature)target).AlterDamageScalarFrom(m_Caster, ref scalar);
    return scalar;
}
```
```
// CLASSIC ONLY
scalar = 1 + (EvalInt − MagicResist) / (EvalInt > MagicResist ? 500 : 200)
scalar += (Magery − 100) / 400                 // −25 % at 0 Magery, 0 % at 100, +5 % at 120
scalar *= 2                                     // vs non-player, non-human bodies
```
**`[HIGH]`.** This is the classic "EvalInt vs Resisting Spells" tug-of-war and the classic **double damage vs monsters** rule. Neither exists in AoS — AoS replaced both with `evalScale` in `GetNewAosDamage`.

**Stat-effect spells (Bless, Curse, Clumsy, Weaken, Agility, Strength, Cunning, Feeblemind) `[HIGH]`** — `SpellHelper.cs:413-455`:
```csharp
public static TimeSpan GetDuration(Mobile caster, Mobile target) {
    if (Core.AOS) {
        int span = (((6 * caster.Skills.EvalInt.Fixed) / 50) + 1);   // EvalInt.Fixed = ×10
        if (caster.Spell is CurseSpell && ResilienceSpell.UnderEffects(target)) span /= 2;
        return TimeSpan.FromSeconds(span);
    }
    return TimeSpan.FromSeconds(caster.Skills[Magery].Value * 1.2);
}
public static double GetOffsetScalar(Mobile caster, Mobile target, bool curse) {
    double percent;
    if (curse) {
        double resistFixed = target.Skills.MagicResist.Fixed - (EvilOmenSpell.GetResistMalus(target) * 10);
        percent = 8 + (caster.Skills.EvalInt.Fixed / 100) - (resistFixed / 100);
    } else percent = 1 + (caster.Skills.EvalInt.Fixed / 100);
    percent *= 0.01;
    if (percent < 0) percent = 0;
    return percent;
}
```
```
duration_seconds_AoS     = (6 × EvalInt × 10) / 50 + 1 = 1.2 × EvalInt + 1
duration_seconds_classic = Magery × 1.2

buff offset  = (1 + EvalInt/10) / 100          // e.g. +0.11 of the base stat at EvalInt 100
curse offset = (8 + EvalInt/10 − MagicResist/10) / 100   // floored at 0
```
So a **Bless at 100 EvalInt lasts 121 seconds** and shifts stats by 11 % of the base amount; a **Curse from a 100-EvalInt mage on a 100-MagicResist target** has a **0.8 % offset** — i.e. essentially nullified. **`[HIGH]`**

### 4.7 Meditation and mana regeneration

* The **active** Meditation skill is `Scripts/Skills/Meditation.cs`: `SkillInfo.Table[(int)SkillName.Meditation].Callback` → the use callback performs a focus check and grants a mana burst proportional to Meditation and Focus, gated by armour.
* The **passive** regeneration is `Mobile`'s mana-regen timer, which uses the `ManaRegen` AoS property plus the Meditation/Focus skills. **`[UNVERIFIED]` at formula level** — the exact passive-regen constants live in `Server/Mobile.cs` in the `CheckManaRegen`/regen-timer region, which I did not read line-by-line. To settle: read `Server/Mobile.cs` around the `ManaRegen`/`HitsRegen`/`StamRegen` timer, and `Scripts/Skills/Meditation.cs` in full.
* **What *is* verified `[HIGH]`:** the armour gate. `BaseArmor.DefMedAllowance` returns an `ArmorMeditationAllowance` ∈ {`All`, `Half`, `None`}, and the armour table in §3.2 records it per piece. Leather armour is `All`; studded is `Half`; chain, ring and plate are `None`. Meditation in plate is therefore blocked, which is the classic "mages wear leather" rule. **`[HIGH]`** for the field and its per-item values; the exact penalty arithmetic is in `Meditation.cs`.
* Mana regeneration is also directly purchasable via the `RegenMana` AoS property (`ItemPropertyInfo` id 5, max 2 on armour/shield/hat, 2→4 overpowered, 9 in powerful loot). **`[HIGH]`** — see §5.

### 4.8 Inscription

**`[HIGH]`** — two distinct effects, both read from source:

1. **Spell damage:** `int scribeBonus = inscribeSkill >= 1000 ? 10 : inscribeSkill / 200;` in `GetNewAosDamage`. `inscribeSkill` is `Inscription.Fixed` (skill × 10), so this is **+10 % at GM (100.0)** and `0.5 %` per 10 skill points below GM. It is added to `damageBonus` before the × scaling.
   * This corroborates UOGuide: *"a GM Scribe gains a +10% Spell Damage Increase"* ([UOGuide: Magery](https://www.uoguide.com/Magery)). **`[MED]`**
2. **Not a skill-check:** `GetInscribeSkill`/`GetInscribeFixed` explicitly do **not** call `CheckSkill` — the comment is `// There is no chance to gain`. **`[HIGH]`** — `Spell.cs:413-425`.

The scroll-copying / spellbook-inscription half of Inscription lives in `Scripts/Skills/Inscribe.cs` and `Scripts/Services/Craft/DefInscription.cs` (15 recipes). Its exact "can I copy a circle-N scroll at skill S" rule was **not** read → **`[UNVERIFIED]`**. To settle: read `Scripts/Skills/Inscribe.cs` and the magery-scroll recipe rows in `DefInscription.cs`.

### 4.9 Reagents — names, item ids, and gold cost

Reagents are `BaseReagent : Item`, `Stackable = true`, `DefaultWeight = 0.1`. **`[HIGH]`** — `Scripts/Items/Consumables/BaseReagent.cs:24-29`.

Item ids from each reagent class's base constructor. **Prices are the NPC mage-vendor buy prices** (`GenericBuyInfo(type, price, stock, itemID, hue)`) from `Scripts/VendorInfo/SBMage.cs:56-71`. **`[HIGH]`** for both.

| Reagent | Item ID | Vendor price (gold) | Vendor stock | Used by |
|---|---|---|---|---|
| **Black Pearl** | `0xF7A` | **5** | 20 | Fireball, Mana Drain, Recall, Mind Blast, Energy Bolt, Mark, Chain Lightning, Energy Field, Gate Travel, Mana Vampire, Mass Dispel, Blade Spirits, Dispel Field, Poison Field, Paralyze Field, Energy Vortex |
| **Bloodmoss** | `0xF7B` | **5** | 20 | Clumsy, Agility, Magic Lock, Telekinesis, Teleport, Unlock, Wall of Stone, Explosion, Invisibility, Mark, Chain Lightning, Mana Vampire, Polymorph, all four elementals, Energy Vortex, Resurrection, Summon Daemon |
| **Garlic** | `0xF84` | **3** | 20 | Create Food, Heal, Reactive Armor, Weaken, Cure, Magic Trap, Protection, Bless, Magic Lock, Arch Cure, Arch Protection, Curse, Greater Heal, Dispel Field, Incognito, Magic Reflection, **Paralyze**, Dispel, Mass Curse, Mass Dispel, Resurrection |
| **Ginseng** | `0xF85` | **3** | 20 | Create Food, Feeblemind, Heal, Cure, Protection, Arch Cure, Arch Protection, Greater Heal, Paralyze Field, Earthquake, Resurrection |
| **Mandrake Root** | `0xF86` | **3** | 20 | Create Food, Agility, Strength, Bless, Telekinesis, Teleport, Arch Cure, Arch Protection, Greater Heal, Lightning, Mana Drain, Recall, Dispel Field, Magic Reflection, Paralyze, Summon Creature, Dispel, Explosion, Mark, Mass Curse, Chain Lightning, Energy Field, Gate Travel, Mana Vampire, Mass Dispel, Polymorph, all four elementals, Energy Vortex, Summon Daemon |
| **Nightshade** | `0xF88` | **3** | 20 | Clumsy, Feeblemind, Weaken, Cunning, Strength, Harm, Poison, Curse, Blade Spirits, Incognito, Mind Blast, Poison Field, Energy Bolt, Invisibility, Mass Curse, MageWeapon… |
| **Spiders' Silk** | `0xF8D` | **3** | 20 | Heal, Reactive Armor, Night Sight, Harm, Magic Trap, Arch Protection, Greater Heal, Mana Drain, Dispel Field, Magic Reflection, Paralyze, Summon Creature, Paralyze Field, Chain Lightning, Energy Field, Mana Vampire, Flame Strike, Polymorph, all four elementals, Summon Daemon |
| **Sulfurous Ash** | `0xF8C` | **3** | 20 | Magic Arrow, Night Sight, Reactive Armor, Magic Trap, Remove Trap, Magic Lock, Unlock, Arch Protection, Curse, Fire Field, Lightning, Dispel Field, Mind Blast, Dispel, Reveal, Mass Curse, Chain Lightning, Energy Field, Gate Travel, Mass Dispel, Flame Strike, Earthquake, Fire Elemental, Summon Daemon |

**Necromancy reagents** (same vendor, far larger stock): Bat Wing `0xF78` @ 3, Daemon Blood `0xF7D` @ 6, Pig Iron `0xF8A` @ 5, Nox Crystal `0xF8E` @ 6, Grave Dust `0xF8F` @ 3. **`[HIGH]`** — `SBMage.cs:67-71`.

**Mysticism/Pagan reagents `[HIGH]`** — `Scripts/Spells/Reagent.cs:8-27` registers 17 reagent types; the four extra beyond magery+necro are `Bone`, `DragonBlood`, `FertileDirt`, `DaemonBone`.

> **UOGuide names three reagents as Mysticism-only** ("Bone, Dragon's Blood, Daemon Bone, Fertile Dirt") and calls them *Pagan Reagents* ([UOGuide: Reagents](https://www.uoguide.com/Reagents)). ServUO's `Reagent.m_Types` is the flat 17-entry table above. Both agree on the contents.

**Lower Reagent Cost (LRC) `[HIGH]`** — `Spell.cs:386-411`:
```csharp
public virtual bool ConsumeReagents()
{
    if ((m_Scroll != null && !(m_Scroll is SpellStone)) || !m_Caster.Player) return true;
    // ↑ casting from a SCROLL consumes NO reagents at all
    if (AosAttributes.GetValue(m_Caster, AosAttribute.LowerRegCost) > Utility.Random(100)) return true;
    Container pack = m_Caster.Backpack;
    if (pack == null) return false;
    if (pack.ConsumeTotal(m_Info.Reagents, m_Info.Amounts) == -1) return true;
    return false;
}
```
* **LRC is a single roll per cast, not per reagent:** `LRC% > Random(100)` → *all* reagents are free for that cast. **`[HIGH]`**
* **Casting from a scroll never consumes reagents.** **`[HIGH]`**
* If the pack lacks a reagent, `ConsumeTotal` returns the missing index (!= −1) → the cast fizzles for lack of reagents. **`[HIGH]`**
* Class-specific reagent substitution: `MagerySpell.ConsumeReagents` falls back to `ArcaneGem.ConsumeCharges(Caster, Core.SE ? 1 : 1 + (int)Circle)` — an Arcanist's/Scribe's gem can pay the cost. **`[HIGH]`** — `MagerySpell.cs`.
* UOGuide's claim that LRC is applied multiplicatively per reagent ("95% would cause failures about 1 time in 20 for spells requiring one reagent, 95% × 95% … for two") **contradicts the source.** The source is a single roll. **`[HIGH]` for the source**, **`[LOW]` for the wiki.**

### 4.10 Scrolls and spellbooks

**`[HIGH]`** — `Spell.cs:1110-1180`, `MagerySpell.GetCastSkills`, vendor data.

| Aspect | Behaviour |
|---|---|
| **Scroll skill discount** | `GetCastSkills` does `if (Scroll != null) circle -= 2;` → **a scroll is cast as if it were two circles lower** (8th-circle scroll = 6th-circle requirement). |
| **Scroll consumption** | `if (m_Scroll is SpellScroll) m_Scroll.Consume();` — one scroll per successful cast. |
| **Scroll validity check** | Before consuming: `m_Scroll.Amount <= 0 \|\| m_Scroll.Deleted \|\| m_Scroll.RootParent != m_Caster` → fizzle. The scroll must be **in your backpack**. |
| **Spellbook item id** | `Spellbook` = `0xEFA`, vendor price **18 gold**, stock 10. `NecromancerSpellbook` = `0x2253`, price 115. |
| **Spellbook layer** | The `Layer` enum has no dedicated spellbook member; the book is a `Layer.OneHanded`-class item and a `SpellChanneling` weapon/property interaction governs casting while armed. |
| **Wands** | `BaseWand`: `GetMana()` returns **0** while `Scroll is BaseWand`; `CheckFizzle` returns `true` (never fizzles); `GetCastDelay` returns **`TimeSpan.Zero`** pre-ML and `CastDelayBase` under ML. Each use calls `ConsumeCharge`. Wands are marked non-movable during the cast and restored after. |
| **SpellStone** | `m_Scroll is SpellStone` → cast delay `TimeSpan.Zero`, and `ConsumeReagents` does **not** short-circuit (a spellstone *does* consume reagents). |
| **Runebook** | Excluded from the `m_Scroll` validity check (`!(m_Scroll is Runebook)`), i.e. a runebook is a legal "scroll" for the recall/gate path without being consumed. |
| **Vendor scrolls/pen** | `ScribesPen` = `0xFBF` @ 8 gold. `BlankScroll` = `0x0E34` @ 5 gold. `RecallRune` = `0x1F14` @ 15 gold. |

**Adding spells to a spellbook (the `Spellbook.AddSpell` API) and the Inscription copy rule were not read line-by-line → `[UNVERIFIED]`.** To settle: read `Scripts/Items/Skill Items/Magical/Spellbook.cs` (the `AddSpell`/`HasSpell`/`OnDoubleClick`/`Deserialize` members) and `Scripts/Skills/Inscribe.cs`.

### 4.11 `SpellChanneling`, `MageWeapon`, and `Balanced`

* **`SpellChanneling`** (`AosAttribute`, `0x00200000`) — `ApplyAttribute` special-cases it: `if (attr == AosAttribute.SpellChanneling) attrs[AosAttribute.CastSpeed] -= 1;` i.e. **the property costs you 1 Faster Casting.** **`[HIGH]`** — `BaseRunicTool.cs:1013-1014`. UOGuide confirms the −1 FC trade-off ([UOGuide: Magery](https://www.uoguide.com/Magery)).
* **`MageWeapon`** (`AosWeaponAttribute`, `0x00800000`) — the weapon carries a **Magery skill penalty**. `BaseWeapon.cs:1176-1183`:
  `m_MageMod = new DefaultSkillMod(SkillName.Magery, true, -30 + m_AosWeaponAttributes.MageWeapon);`
  So a property value of `N` gives a Magery mod of `N − 30`. **`MageWeapon = 29` → −1 Magery; `MageWeapon = 0` → no mod** (`:1176` guards `!= 0 && != 30`).
  And it **changes which skill you attack with**: `if (Core.AOS && m_AosWeaponAttributes.MageWeapon > 0 && attacker.Skills[Magery].Value > atkSkill.Value) return attacker.CheckSkill(SkillName.Magery, chance);` **`[HIGH]`** — `BaseWeapon.cs:1535-1536`.
  UOGuide's player-facing phrasing: *"a -29 Mage Weapon … You would need an extra faster casting to compensate for the -1 of the spell channeling property"* — consistent with the source. **`[MED]`**
* **`UseBestSkill`** (`AosWeaponAttribute`, `0x00400000`) — swaps the attack skill for the character's best weapon skill via `GetUsedSkill`. **`[HIGH]`**
* **`BalancedWeapon`** (`AosAttribute`, `0x04000000`) — **negates the two-handed parry penalty**: `if (Core.HS && weapon.Attributes.BalancedWeapon > 0) return false;` in the two-handed parry branch, and `if (Core.ML && m_AosAttributes.BalancedWeapon > 0 && Layer == Layer.TwoHanded)` in the swing path. **`[HIGH]`** — `BaseWeapon.cs:1814-1817`, `:5876`.

---

## 5. ITEM PROPERTIES (AoS)

### 5.1 The property enums

**`[HIGH]` — `Scripts/Misc/AOS.cs`.**

`AosAttribute` (bit flags, `:514-543`): `RegenHits 0x1, RegenStam 0x2, RegenMana 0x4, DefendChance 0x8, AttackChance 0x10, BonusStr 0x20, BonusDex 0x40, BonusInt 0x80, BonusHits 0x100, BonusStam 0x200, BonusMana 0x400, WeaponDamage 0x800, WeaponSpeed 0x1000, SpellDamage 0x2000, CastRecovery 0x4000, CastSpeed 0x8000, LowerManaCost 0x10000, LowerRegCost 0x20000, ReflectPhysical 0x40000, EnhancePotions 0x80000, Luck 0x100000, SpellChanneling 0x200000, NightSight 0x400000, IncreasedKarmaLoss 0x800000, Brittle 0x1000000, LowerAmmoCost 0x2000000, BalancedWeapon 0x4000000`.

`AosWeaponAttribute : long` (`:1342-1376`): `LowerStatReq 0x1, SelfRepair 0x2, HitLeechHits 0x4, HitLeechStam 0x8, HitLeechMana 0x10, HitLowerAttack 0x20, HitLowerDefend 0x40, HitMagicArrow 0x80, HitHarm 0x100, HitFireball 0x200, HitLightning 0x400, HitDispel 0x800, HitColdArea 0x1000, HitFireArea 0x2000, HitPoisonArea 0x4000, HitEnergyArea 0x8000, HitPhysicalArea 0x10000, ResistPhysicalBonus 0x20000, ResistFireBonus 0x40000, ResistColdBonus 0x80000, ResistPoisonBonus 0x100000, ResistEnergyBonus 0x200000, UseBestSkill 0x400000, MageWeapon 0x800000, DurabilityBonus 0x1000000, BloodDrinker 0x2000000, BattleLust 0x4000000, HitCurse 0x8000000, HitFatigue 0x10000000, HitManaDrain 0x20000000, SplinteringWeapon 0x40000000, ReactiveParalyze 0x80000000`.

`AosArmorAttribute` (`:2130`), `AosElementAttribute` (`:3062`: `Physical, Fire, Cold, Poison, Energy, Chaos, Direct`), `SAAbsorptionAttribute` (`:2728`: `EaterFire/Cold/Poison/Energy/Kinetic/Damage`, `ResonanceFire/Cold/Poison/Energy/Kinetic`, `CastingFocus`), `ExtendedWeaponAttribute` (`:1951`: `BoneBreaker, HitSwarm, HitSparks, Bane`), `NegativeAttribute` (`:3214`).

**Era gating in code `[HIGH]`:**
```csharp
// AosAttributes.IsValid      :547-560
if (!Core.AOS) return false;
if (!Core.ML && attribute == AosAttribute.IncreasedKarmaLoss) return false;
// AosWeaponAttributes.IsValid :1380-1393
if (!Core.AOS) return false;
if (!Core.SA && attribute >= AosWeaponAttribute.BloodDrinker) return false;
```
**So `BloodDrinker` and everything above it (BattleLust, HitCurse, HitFatigue, HitManaDrain, SplinteringWeapon, ReactiveParalyze) requires Stygian Abyss.** **`[HIGH]`**

### 5.2 The intensity table — the loot system's master table

**`[HIGH]` — `Scripts/Services/LootGeneration/ItemPropertyInfo.cs:245-…`.** This static constructor is the authoritative per-property intensity/weight/category table. It was parsed mechanically with a brace-balancing parser into `research/_src/itemprops_table.tsv`.

**Semantics `[HIGH]`** (`:22-53`, `:658-758`):
```csharp
public class PropInfo {
    public ItemType ItemType;      // 1=Melee 2=Ranged 3=Armor 4=Shield 5=Hat 6=Jewel
    public int Scale;              // increment, e.g. 3 for regen on weapons, 10 for luck
    public int StandardMax;        // Max intensity for OLD loot system
    public int LootMax;            // Max intensity for NEW loot system
    public int[] PowerfulLootRange;// the over-cap values reachable only in "powerful" loot
}
public static int GetMaxIntensity(Item item, int id, bool imbuing) {
    var info = Table[id].GetItemTypeInfo(GetItemType(item));
    if (info == null || (imbuing && !_ForceUseNewTable.Any(i => i == id))) {
        if (Core.SA && item is BaseWeapon && (id == 25 || id == 27)) return GetSpecialMaxIntensity((BaseWeapon)item);
        return Table[id].MaxIntensity;
    } else {
        if (Core.SA && item is BaseWeapon && (id == 25 || id == 27)) return GetSpecialMaxIntensity((BaseWeapon)item);
        return NewLootSystem ? info.LootMax : info.StandardMax;
    }
}
public static int GetMinIntensity(Item item, int id, bool loot = false) {
    if (loot) return GetScale(item, id);       // loot always starts at the scale step
    else      return Table[id].Start;          // imbuing starts at Start
}
public static int[] GetMaxOvercappedRange(Item item, int id) { … return info.PowerfulLootRange; }
```
* **`start`** = the value a newly-rolled property begins at (usually 1).
* **`scale`** = the value increment. `Luck` has `scale = 10` (so luck comes in 10s); `WeaponSpeed` has `scale = 5`; `EnhancePotions` `scale = 5`; `DurabilityBonus` `scale = 10`.
* **`max`** = the ordinary cap for that property on that item type.
* **`pow`** = the *over-cap* values only reachable by the "powerful loot" roll — a discrete list, not a range. E.g. Damage Increase is `50` normally and `{55, 60, 65, 70}` when powerful.
* **`weight`** = the relative selection weight used when picking which property to roll.

**Special case for leeches `[HIGH]`** — `ItemPropertyInfo.cs:717-727`:
```csharp
public static int GetSpecialMaxIntensity(BaseWeapon wep) {
    int max = (int)(wep.MlSpeed * 2500 / (100 + wep.Attributes.WeaponSpeed));
    if (wep is BaseRanged) max /= 2;
    return max;
}
```
**Hit Life Leech and Hit Mana Leech caps are weapon-speed-derived**, not fixed. A 4.0 s weapon with 0 SSI caps at `(int)(4.0 × 2500 / 100) = 100`; a 2.0 s weapon caps at `50`; a ranged weapon halves that. **`[HIGH]`**

### 5.3 THE property table

Generated mechanically from `ItemPropertyInfo.cs`. **All values are source-exact. `[HIGH]`.**

Columns: **id** = the table key (also the imbuing id); **weight**; **scale**; **start**; **max** = the default `MaxIntensity`; **per-item-type** = `Max` for that item type (`pow` = the over-cap powerful-loot values).

`| id | Property | Weight | Scale | Start | Default max | Per-item-type max (and powerful-loot over-cap values) |
|---|---|---|---|---|---|---|
| 1 | AosAttribute.DefendChance | 110 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=25 only-powerful: 30, 35 ]; Armor[scale=- max=5]; Shield[scale=- max=15 only-powerful: 20 ]; Hat[scale=- max=5]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 2 | AosAttribute.AttackChance | 130 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=25 only-powerful: 30, 35 ]; Armor[scale=- max=5]; Shield[scale=- max=15 only-powerful: 20 ]; Hat[scale=- max=5]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 3 | AosAttribute.RegenHits | 100 | 1 | 1 | 2 | Melee[scale=- max=0 only-powerful: 9]; Ranged[scale=- max=0 only-powerful: 9]; Armor[scale=- max=2 only-powerful: 4 ]; Shield[scale=- max=2 only-powerful: 4 ]; Hat[scale=- max=2 only-powerful: 4 ] |
| 4 | AosAttribute.RegenStam | 100 | 1 | 1 | 3 | Melee[scale=- max=0 only-powerful: 9]; Ranged[scale=- max=0 only-powerful: 9]; Armor[scale=- max=3 only-powerful: 4 ]; Shield[scale=- max=3 only-powerful: 4 ]; Hat[scale=- max=3 only-powerful: 4 ] |
| 5 | AosAttribute.RegenMana | 100 | 1 | 1 | 2 | Melee[scale=- max=0 only-powerful: 9]; Ranged[scale=- max=0 only-powerful: 9]; Armor[scale=- max=2 only-powerful: 4 ]; Shield[scale=- max=2 only-powerful: 4 ]; Hat[scale=- max=2 only-powerful: 4 ]; Jewel[scale=- max=2 only-powerful: 4] |
| 6 | AosAttribute.BonusStr | 110 | 1 | 1 | 8 | Melee[scale=- max=5]; Ranged[scale=- max=5]; Armor[scale=- max=5]; Shield[scale=- max=5]; Hat[scale=- max=5]; Jewel[scale=- max=8 only-powerful: 9, 10 ] |
| 7 | AosAttribute.BonusDex | 110 | 1 | 1 | 8 | Melee[scale=- max=5]; Ranged[scale=- max=5]; Armor[scale=- max=5]; Shield[scale=- max=5]; Hat[scale=- max=5]; Jewel[scale=- max=8 only-powerful: 9, 10 ] |
| 8 | AosAttribute.BonusInt | 110 | 1 | 1 | 8 | Melee[scale=- max=5]; Ranged[scale=- max=5]; Armor[scale=- max=5]; Shield[scale=- max=5]; Hat[scale=- max=5]; Jewel[scale=- max=8 only-powerful: 9, 10 ] |
| 9 | AosAttribute.BonusHits | 110 | 1 | 1 | 5 | Melee[scale=- max=5 only-powerful: 6, 7 ]; Ranged[scale=- max=5 only-powerful: 6, 7 ]; Armor[scale=- max=5 only-powerful: 6, 7 ]; Shield[scale=- max=5 only-powerful: 6, 7 ]; Hat[scale=- max=5 only-powerful: 6, 7 ] |
| 10 | AosAttribute.BonusStam | 110 | 1 | 1 | 8 | Melee[scale=- max=5]; Ranged[scale=- max=5]; Armor[scale=- max=8 only-powerful: 9, 10 ]; Shield[scale=- max=5]; Hat[scale=- max=8 only-powerful: 9, 10 ]; Jewel[scale=- max=5] |
| 11 | AosAttribute.BonusMana | 110 | 1 | 1 | 8 | Melee[scale=- max=5]; Ranged[scale=- max=5]; Armor[scale=- max=8 only-powerful: 9, 10 ]; Shield[scale=- max=5]; Hat[scale=- max=8 only-powerful: 9, 10 ]; Jewel[scale=- max=5] |
| 12 | AosAttribute.WeaponDamage | 100 | 5 | 1 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Shield[scale=- max=35]; Jewel[scale=- max=25 only-powerful: 30, 35 ] |
| 13 | AosAttribute.WeaponSpeed | 110 | 5 | 5 | 30 | Melee[scale=- max=30 only-powerful: 35, 40 ]; Shield[scale=- max=5 only-powerful: 10 ]; Jewel[scale=- max=5 only-powerful: 10 ] |
| 14 | AosAttribute.SpellDamage | 100 | 1 | 1 | 12 | Jewel[scale=- max=12 only-powerful: 14, 16, 18 ] |
| 15 | AosAttribute.CastRecovery | 120 | 1 | 1 | 3 | Jewel[scale=- max=3 only-powerful: 4 ] |
| 16 | AosAttribute.CastSpeed | 140 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1]; Shield[scale=- max=1]; Jewel[scale=- max=1] |
| 17 | AosAttribute.LowerManaCost | 110 | 1 | 1 | 8 | Melee[scale=- max=5]; Ranged[scale=- max=5]; Armor[scale=- max=8 only-powerful: 10 ]; Shield[scale=- max=5]; Hat[scale=- max=8 only-powerful: 10 ]; Jewel[scale=- max=8 only-powerful: 10 ] |
| 18 | AosAttribute.LowerRegCost | 100 | 1 | 1 | 20 | Armor[scale=- max=20 only-powerful: 25 ]; Hat[scale=- max=20 only-powerful: 25 ]; Jewel[scale=- max=20 only-powerful: 25 ] |
| 19 | AosAttribute.ReflectPhysical | 100 | 1 | 1 | 15 | Melee[scale=- max=15]; Ranged[scale=- max=15]; Armor[scale=- max=15 only-powerful: 20 ]; Shield[scale=- max=15 only-powerful: 20 ]; Hat[scale=- max=15 only-powerful: 20 ] |
| 20 | AosAttribute.EnhancePotions | 100 | 5 | 5 | 25 | Melee[scale=- max=15]; Ranged[scale=- max=15]; Armor[scale=- max=5]; Hat[scale=- max=5]; Jewel[scale=- max=25 only-powerful: 30, 35 ] |
| 21 | AosAttribute.Luck | 100 | 10 | 10 | 100 | Melee[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Ranged[scale=- max=120 only-powerful: 130, 140, 150, 160, 170 ]; Armor[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Shield[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Hat[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Jewel[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ] |
| 22 | AosAttribute.SpellChanneling | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1]; Shield[scale=- max=1] |
| 23 | AosAttribute.NightSight | 50 | 0 | 1 | 1 | Armor[scale=- max=1]; Hat[scale=- max=1]; Jewel[scale=- max=1] |
| 25 | AosWeaponAttribute.HitLeechHits | 110 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 50]; Ranged[scale=- max=50 only-powerful: 50] |
| 26 | AosWeaponAttribute.HitLeechStam | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 50]; Ranged[scale=- max=50 only-powerful: 50] |
| 27 | AosWeaponAttribute.HitLeechMana | 110 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 50]; Ranged[scale=- max=50 only-powerful: 50] |
| 28 | AosWeaponAttribute.HitLowerAttack | 110 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 29 | AosWeaponAttribute.HitLowerDefend | 130 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 30 | AosWeaponAttribute.HitPhysicalArea | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 31 | AosWeaponAttribute.HitFireArea | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 32 | AosWeaponAttribute.HitColdArea | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 33 | AosWeaponAttribute.HitPoisonArea | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 34 | AosWeaponAttribute.HitEnergyArea | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 35 | AosWeaponAttribute.HitMagicArrow | 120 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 36 | AosWeaponAttribute.HitHarm | 110 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 37 | AosWeaponAttribute.HitFireball | 140 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 38 | AosWeaponAttribute.HitLightning | 140 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 39 | AosWeaponAttribute.HitDispel | 100 | 1 | 2 | 50 | Melee[scale=- max=50 only-powerful: 55, 60, 65, 70 ]; Ranged[scale=- max=50 only-powerful: 55, 60, 65, 70 ] |
| 40 | AosWeaponAttribute.UseBestSkill | 150 | 0 | 1 | 1 | Melee[scale=- max=1] |
| 41 | AosWeaponAttribute.MageWeapon | 100 | 1 | 1 | 10 | Melee[scale=- max=10 only-powerful: 11, 12, 13, 14, 15 ]; Ranged[scale=- max=10 only-powerful: 11, 12, 13, 14, 15 ] |
| 42 | AosWeaponAttribute.DurabilityBonus | 100 | 10 | 10 | 100 | Melee[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Ranged[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ] |
| 43 | AosArmorAttribute.DurabilityBonus | 100 | 10 | 10 | 100 | Armor[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Shield[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ]; Hat[scale=- max=100 only-powerful: 110, 120, 130, 140, 150 ] |
| 44 | AosWeaponAttribute.LowerStatReq | 100 | 10 | 10 | 100 | Melee[scale=- max=100]; Ranged[scale=- max=100] |
| 45 | AosArmorAttribute.LowerStatReq | 100 | 10 | 10 | 100 | Armor[scale=- max=100]; Shield[scale=- max=100]; Hat[scale=- max=100] |
| 49 | AosArmorAttribute.MageArmor | 0 | 0 | 1 | 1 | Armor[scale=- max=1] |
| 51 | AosElementAttribute.Physical | 100 | 1 | 1 | 15 | Melee[scale=- max=100 only-powerful: 100]; Ranged[scale=- max=100 only-powerful: 100]; Armor[scale=- max=15 only-powerful: 20, 25, 30 ]; Shield[scale=- max=15]; Hat[scale=- max=15 only-powerful: 20, 25, 30 ]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 52 | AosElementAttribute.Fire | 100 | 1 | 1 | 15 | Melee[scale=- max=100 only-powerful: 100]; Ranged[scale=- max=100 only-powerful: 100]; Armor[scale=- max=15 only-powerful: 20, 25, 30 ]; Shield[scale=- max=15]; Hat[scale=- max=15 only-powerful: 20, 25, 30 ]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 53 | AosElementAttribute.Cold | 100 | 1 | 1 | 15 | Melee[scale=- max=100 only-powerful: 100]; Ranged[scale=- max=100 only-powerful: 100]; Armor[scale=- max=15 only-powerful: 20, 25, 30 ]; Shield[scale=- max=15]; Hat[scale=- max=15 only-powerful: 20, 25, 30 ]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 54 | AosElementAttribute.Poison | 100 | 1 | 1 | 15 | Melee[scale=- max=100 only-powerful: 100]; Ranged[scale=- max=100 only-powerful: 100]; Armor[scale=- max=15 only-powerful: 20, 25, 30 ]; Shield[scale=- max=15]; Hat[scale=- max=15 only-powerful: 20, 25, 30 ]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 55 | AosElementAttribute.Energy | 100 | 1 | 1 | 15 | Melee[scale=- max=100 only-powerful: 100]; Ranged[scale=- max=100 only-powerful: 100]; Armor[scale=- max=15 only-powerful: 20, 25, 30 ]; Shield[scale=- max=15]; Hat[scale=- max=15 only-powerful: 20, 25, 30 ]; Jewel[scale=- max=15 only-powerful: 20 ] |
| 60 | "WeaponVelocity" | 130 | 1 | 2 | 50 | Melee[scale=- max=50]; Ranged[scale=- max=50] |
| 61 | AosAttribute.BalancedWeapon | 150 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 62 | "SearingWeapon" | 150 | 0 | 1 | 1 |  |
| 101 | SlayerName.OrcSlaying | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 102 | SlayerName.TrollSlaughter | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 103 | SlayerName.OgreTrashing | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 104 | SlayerName.DragonSlaying | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 105 | SlayerName.Terathan | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 106 | SlayerName.SnakesBane | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 107 | SlayerName.LizardmanSlaughter | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 108 | SlayerName.GargoylesFoe | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 111 | SlayerName.Ophidian | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 112 | SlayerName.SpidersDeath | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 113 | SlayerName.ScorpionsBane | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 114 | SlayerName.FlameDousing | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 115 | SlayerName.WaterDissipation | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 116 | SlayerName.Vacuum | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 117 | SlayerName.ElementalHealth | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 118 | SlayerName.EarthShatter | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 119 | SlayerName.BloodDrinking | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 120 | SlayerName.SummerWind | 100 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 121 | SlayerName.Silver | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 122 | SlayerName.Repond | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 123 | SlayerName.ReptilianDeath | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 124 | SlayerName.Exorcism | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 125 | SlayerName.ArachnidDoom | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 126 | SlayerName.ElementalBan | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 127 | SlayerName.Fey | 130 | 0 | 1 | 1 | Melee[scale=- max=1]; Ranged[scale=- max=1] |
| 128 | SlayerName.Dinosaur | 130 | 0 | 1 | 1 |  |
| 129 | SlayerName.Myrmidex | 130 | 0 | 1 | 1 |  |
| 130 | SlayerName.Eodon | 130 | 0 | 1 | 1 |  |
| 131 | SlayerName.EodonTribe | 130 | 0 | 1 | 1 |  |
| 135 | TalismanSlayerName.Bear | 130 | 0 | 1 | 1 |  |
| 136 | TalismanSlayerName.Vermin | 130 | 0 | 1 | 1 |  |
| 137 | TalismanSlayerName.Bat | 130 | 0 | 1 | 1 |  |
| 138 | TalismanSlayerName.Mage | 130 | 0 | 1 | 1 |  |
| 139 | TalismanSlayerName.Beetle | 130 | 0 | 1 | 1 |  |
| 140 | TalismanSlayerName.Bird | 130 | 0 | 1 | 1 |  |
| 141 | TalismanSlayerName.Ice | 130 | 0 | 1 | 1 |  |
| 142 | TalismanSlayerName.Flame | 130 | 0 | 1 | 1 |  |
| 143 | TalismanSlayerName.Bovine | 130 | 0 | 1 | 1 |  |
| 144 | TalismanSlayerName.Wolf | 130 | 0 | 1 | 1 |  |
| 145 | TalismanSlayerName.Undead | 130 | 0 | 1 | 1 |  |
| 146 | TalismanSlayerName.Goblin | 130 | 0 | 1 | 1 |  |
| 151 | SkillName.Fencing | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 152 | SkillName.Macing | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 153 | SkillName.Swords | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 154 | SkillName.Musicianship | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 155 | SkillName.Magery | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 156 | SkillName.Wrestling | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 157 | SkillName.AnimalTaming | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 158 | SkillName.SpiritSpeak | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 159 | SkillName.Tactics | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 160 | SkillName.Provocation | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 161 | SkillName.Focus | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 162 | SkillName.Parry | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 163 | SkillName.Stealth | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 164 | SkillName.Meditation | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 165 | SkillName.AnimalLore | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 166 | SkillName.Discordance | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 167 | SkillName.Mysticism | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 168 | SkillName.Bushido | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 169 | SkillName.Necromancy | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 170 | SkillName.Veterinary | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 171 | SkillName.Stealing | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 172 | SkillName.EvalInt | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 173 | SkillName.Anatomy | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 174 | SkillName.Peacemaking | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 175 | SkillName.Ninjitsu | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 176 | SkillName.Chivalry | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 177 | SkillName.Archery | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 178 | SkillName.MagicResist | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 179 | SkillName.Healing | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 180 | SkillName.Throwing | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 181 | SkillName.Lumberjacking | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 182 | SkillName.Snooping | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 183 | SkillName.Mining | 140 | 5 | 1 | 15 | Jewel[scale=- max=15 only-powerful: 20 ] |
| 200 | AosWeaponAttribute.BloodDrinker | 140 | 0 | 1 | 1 | Melee[scale=- max=1] |
| 201 | AosWeaponAttribute.BattleLust | 140 | 0 | 1 | 1 | Melee[scale=- max=1] |
| 202 | AosWeaponAttribute.HitCurse | 140 | 1 | 2 | 50 |  |
| 203 | AosWeaponAttribute.HitFatigue | 140 | 1 | 2 | 50 | Melee[scale=- max=70]; Ranged[scale=- max=70] |
| 204 | AosWeaponAttribute.HitManaDrain | 140 | 1 | 2 | 50 | Melee[scale=- max=70]; Ranged[scale=- max=70] |
| 205 | AosWeaponAttribute.SplinteringWeapon | 140 | 5 | 5 | 30 | Melee[scale=- max=20 only-powerful: 25, 30 ] |
| 206 | AosWeaponAttribute.ReactiveParalyze | 140 | 0 | 1 | 1 | Melee[scale=- max=1] |
| 208 | SAAbsorptionAttribute.EaterFire | 140 | 1 | 1 | 15 | Armor[scale=- max=15]; Shield[scale=- max=15]; Hat[scale=- max=15] |
| 209 | SAAbsorptionAttribute.EaterCold | 140 | 1 | 1 | 15 | Armor[scale=- max=15]; Shield[scale=- max=15]; Hat[scale=- max=15] |
| 210 | SAAbsorptionAttribute.EaterPoison | 140 | 1 | 1 | 15 | Armor[scale=- max=15]; Shield[scale=- max=15]; Hat[scale=- max=15] |
| 211 | SAAbsorptionAttribute.EaterEnergy | 140 | 1 | 1 | 15 | Armor[scale=- max=15]; Shield[scale=- max=15]; Hat[scale=- max=15] |
| 212 | SAAbsorptionAttribute.EaterKinetic | 140 | 1 | 1 | 15 | Armor[scale=- max=15]; Shield[scale=- max=15]; Hat[scale=- max=15] |
| 213 | SAAbsorptionAttribute.EaterDamage | 140 | 1 | 1 | 15 | Armor[scale=- max=15]; Shield[scale=- max=15]; Hat[scale=- max=15] |
| 214 | SAAbsorptionAttribute.ResonanceFire | 140 | 1 | 1 | 20 |  |
| 215 | SAAbsorptionAttribute.ResonanceCold | 140 | 1 | 1 | 20 |  |
| 216 | SAAbsorptionAttribute.ResonancePoison | 140 | 1 | 1 | 20 |  |
| 217 | SAAbsorptionAttribute.ResonanceEnergy | 140 | 1 | 1 | 20 |  |
| 218 | SAAbsorptionAttribute.ResonanceKinetic | 140 | 1 | 1 | 20 |  |
| 219 | SAAbsorptionAttribute.CastingFocus | 140 | 1 | 1 | 3 | Armor[scale=- max=3]; Hat[scale=- max=3] |
| 220 | AosArmorAttribute.ReactiveParalyze | 140 | 0 | 1 | 1 | Melee[scale=- max=1]; Shield[scale=- max=1] |
| 221 | AosArmorAttribute.SoulCharge | 140 | 5 | 5 | 30 | Shield[scale=- max=30] |
| 233 | AosWeaponAttribute.ResistPhysicalBonus | 100 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=15 only-powerful: 20 ] |
| 234 | AosWeaponAttribute.ResistFireBonus | 100 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=15 only-powerful: 20 ] |
| 235 | AosWeaponAttribute.ResistColdBonus | 100 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=15 only-powerful: 20 ] |
| 236 | AosWeaponAttribute.ResistPoisonBonus | 100 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=15 only-powerful: 20 ] |
| 237 | AosWeaponAttribute.ResistEnergyBonus | 100 | 1 | 1 | 15 | Melee[scale=- max=15 only-powerful: 20 ]; Ranged[scale=- max=15 only-powerful: 20 ] |
| 500 | AosArmorAttribute.SelfRepair | 100 | 1 | 1 | 5 | Armor[scale=- max=5]; Shield[scale=- max=5]; Hat[scale=- max=5] |
| 501 | AosWeaponAttribute.SelfRepair | 100 | 1 | 1 | 5 | Melee[scale=- max=5]; Ranged[scale=- max=5] |
| 600 | ExtendedWeaponAttribute.BoneBreaker | 140 | 1 | 1 | 1 |  |
| 601 | ExtendedWeaponAttribute.HitSwarm | 140 | 1 | 1 | 20 |  |
| 602 | ExtendedWeaponAttribute.HitSparks | 140 | 1 | 1 | 20 |  |``

### 5.4 Caps enforced at *use* time (different from the roll caps above)

| Cap | Value | Where |
|---|---|---|
| **Swing Speed Increase (SSI)** | **60 %** | `BaseWeapon.cs:1562-1565` (`if (bonus > 60) bonus = 60;`) |
| **Damage Increase (DI)** | **100 %** | `BaseWeapon.cs:3806-3809` |
| **Hit Chance Increase (HCI)** | **45 %** (50 % for Gargoyles) | `BaseWeapon.cs:1451` |
| **Defence Chance Increase (DCI)** | **45 %** + `BaseArmor.GetRefinedDefenseChance()` | `BaseWeapon.cs:1462-1466` |
| **Lower Mana Cost (LMC)** | **40 %** | `Spell.cs:967-973`, `SpecialMove.cs:150` |
| **Lower Reagent Cost (LRC)** | no explicit cap (100 % = always free) | `Spell.cs:393` |
| **Faster Casting (FC)** | **2** for Magery (4 for Chivalry w/o 70 Magery) | `Spell.cs:1047-1053` |
| **Faster Cast Recovery (FCR)** | effective cap **6** (recovery reaches 0) | `Spell.cs:1015-1022` |
| **PvP Spell Damage Increase (SDI)** | **15 %**, **20 %** (`Core.TOL`), **30 %** with spell-school focus | `SpellHelper.cs:108-144` |
| **Durability (HP/MaxHP after scaling)** | **255** | `BaseArmor.cs:1362-1366` |
| **Direct/unresistable damage** | **35**, or **30** (`Core.TOL` + ranged) | `AOS.cs:213` |
| **Total player damage** | **35** (`!Core.TOL`) | `AOS.cs:251` |
| **Leech max (SA, speed-derived)** | `MlSpeed × 2500 / (100 + SSI)`, halved for ranged | `ItemPropertyInfo.cs:717-727` |

### 5.5 Slayer types

**`[HIGH]`** — `ItemPropertyInfo.cs:409-432` registers every slayer by id with weight `100` (normal) or `130` (super slayer). **Slayers occupy the weapon's single "slayer" slot** (all have `scale = 0, start = 1, max = 1`).

| id | Slayer | Weight | Class |
|---|---|---|---|
| 101 | `OrcSlaying` | 100 | normal |
| 102 | `TrollSlaughter` | 100 | normal |
| 103 | `OgreTrashing` | 100 | normal |
| 104 | `DragonSlaying` | 100 | normal |
| 105 | `Terathan` | 100 | normal |
| 106 | `SnakesBane` | 100 | normal |
| 107 | `LizardmanSlaughter` | 100 | normal |
| 108 | `GargoylesFoe` | 100 | normal |
| 111 | `Ophidian` | 100 | normal |
| 112 | `SpidersDeath` | 100 | normal |
| 113 | `ScorpionsBane` | 100 | normal |
| 114 | `FlameDousing` | 100 | normal |
| 115 | `WaterDissipation` | 100 | normal |
| 116 | `Vacuum` | 100 | normal |
| 117 | `ElementalHealth` | 100 | normal |
| 118 | `EarthShatter` | 100 | normal |
| 119 | `BloodDrinking` | 100 | normal |
| 120 | `SummerWind` | 100 | normal |
| **121** | **`Silver`** | **130** | **super** |
| **122** | **`Repond`** | **130** | **super** |
| **123** | **`ReptilianDeath`** | **130** | **super** |
| **124** | **`Exorcism`** | **130** | **super** |
| **125** | **`ArachnidDoom`** | **130** | **super** |
| **126** | **`ElementalBan`** | **130** | **super** |
| **127** | **`Fey`** | **130** | **super** |
| 128 | `Dinosaur` | 130 | super (ML) |
| 129 | `Myrmidex` | 130 | super (TOL) |
| 130 | `Eodon` | 130 | super (TOL) |
| 131 | `EodonTribe` | 130 | super (TOL) |

Plus a **separate talisman slayer family** (`TalismanSlayerName`, ids 135–146, all weight 130): `Bear, Vermin, Bat, Mage, Beetle, Bird, Ice, Flame, Bovine, Wolf, Undead, Goblin`. **`[HIGH]`**

**What a slayer does `[UNIFIED from the property's purpose + the `ItemPropertyInfo` flags]`:** the **`Slayer` property applies a damage multiplier against matching creature types**, the classic value being **double damage**, and super-slayers cover a *group* of creature types rather than one. The exact multiplier constants and the type→slayer mapping table live in `BaseWeapon`'s `SlayerEntry`/`SlayerName` handling and `Scripts/Mobiles/…` `Slayer` overrides → **`[UNVERIFIED]` at constant level.** To settle: grep for `SlayerEntry`/`m_Slayer`/`Slayer` in `Scripts/Items/Equipment/Weapons/BaseWeapon.cs` (the `GetSlayerDamageBonus`/`Slayer` region) and the `Slayer` property overrides on `BaseCreature` subclasses. **The doubling is player-confirmed UO behaviour but must not be treated as a measured constant here.**

### 5.6 Negative attributes

**`[HIGH]`** — `AosAttribute` flags `Brittle 0x1000000` and `IncreasedKarmaLoss 0x800000` (`IncreasedKarmaLoss` requires `Core.ML`), and the `NegativeAttribute` enum at `AOS.cs:3214`. Verified *effects* found in code:

| Negative property | Verified mechanical effect | Source |
|---|---|---|
| **Massive** | Strength requirement of the item is **pinned to 125** | `BaseWeapon.cs:661-664` |
| **Antique** | Weapon wear chance `Random(40) <= 5` (**15 %**, up from 2.5 %); armour wear chance **80 %** (up from 25 %) | `BaseWeapon.cs:2310`, `BaseArmor.cs:2612` |
| **Brittle / Prized / Unwieldy / Cursed / NoFreeHands / Durable** | declared in the enum; **specific numeric behaviour not read → `[UNVERIFIED]`** | `AOS.cs:3214` |

### 5.7 `Blessed`, `Artifacts`, and item quality

* **`LootType.Blessed`** (and `Insured`) items are **not dropped on death** — they go to the corpse's `m_RestoreEquip` list and are returned on resurrection. This is the `DeathMoveResult` / `equip` partition at `Server/Mobile.cs:4072-4093`. **`[HIGH]`**
* **`ArtifactRarity`** exists as a virtual on both `BaseWeapon` and `BaseArmor` (`BaseArmor.cs:1033`). Artifacts are hard-coded classes under `Scripts/Items/Artifacts/Equipment/{Weapons,Armor,Clothing,Jewelry}/` rather than rolled properties. **`[HIGH]`** for their existence; per-artifact property lists are out of scope here.
* **`ItemQuality` ∈ {`Low`, `Normal`, `Exceptional`}** is the *quality* axis, distinct from *magic* intensity. Pre-AoS: Exceptional = **+20 % damage** and **−20 % for Low** (`GetDamageBonus`). AoS: Exceptional = **+20 % durability** (`GetDurabilityBonus`). **`[HIGH]`**

---

## 6. MAGIC ITEM GENERATION

There are **two** generators in ServUO: the classic **`LootPack` + `BaseRunicTool`** path (the RunUO heritage) and the modern **`RunicReforging` + `RandomItemGenerator`** budget path (`Core.HS` only). Implement the first for era fidelity.

### 6.1 How many properties does an item get?

**`[HIGH]` — `Scripts/Misc/LootPack.cs:618-712`.**

```csharp
private int GetRandomOldBonus()          // used only for the pre-AoS accuracy/damage level roll
{
    int rnd = Utility.RandomMinMax(m_MinIntensity, m_MaxIntensity);
    if (50 > rnd) return 1; else rnd -= 50;
    if (25 > rnd) return 2; else rnd -= 25;
    if (14 > rnd) return 3; else rnd -= 14;
    if ( 8 > rnd) return 4;
    return 5;
}

public Item Mutate(Mobile from, int luckChance, Item item)
{
    if (item is BaseWeapon && 1 > Utility.Random(100)) { item.Delete(); item = new FireHorn(); return item; }  // 1% gag item
    if (item is BaseWeapon || item is BaseArmor || item is BaseJewel || item is BaseHat) {
        if (Core.AOS) {
            if (Core.HS && RandomItemGenerator.Enabled && from is BaseCreature)
                if (RandomItemGenerator.GenerateRandomItem(item, ((BaseCreature)from).LastKiller, (BaseCreature)from)) return item;

            int bonusProps = GetBonusProperties();
            int min = m_MinIntensity, max = m_MaxIntensity;

            if (bonusProps < m_MaxProps && LootPack.CheckLuck(luckChance)) ++bonusProps;   // luck can add +1 property

            int props = 1 + bonusProps;                       // ← properties = 1 + bonusProps
            if (props > m_MaxProps) props = m_MaxProps;       // "Make sure we're not spawning items with 6 properties."

            if (item is BaseWeapon)      BaseRunicTool.ApplyAttributesTo((BaseWeapon)item, false, luckChance, props, m_MinIntensity, m_MaxIntensity);
            else if (item is BaseArmor)  BaseRunicTool.ApplyAttributesTo((BaseArmor)item, false, luckChance, props, m_MinIntensity, m_MaxIntensity);
            else if (item is BaseJewel)  BaseRunicTool.ApplyAttributesTo((BaseJewel)item, false, luckChance, props, m_MinIntensity, m_MaxIntensity);
            else if (item is BaseHat)    BaseRunicTool.ApplyAttributesTo((BaseHat)item,   false, luckChance, props, m_MinIntensity, m_MaxIntensity);
        }
        …
    }
}
```

**Property count = `1 + bonusProps`, clamped to `m_MaxProps`.** `bonusProps` comes from `GetBonusProperties()`, which is **`[UNVERIFIED]`** — it was not read. `m_MaxProps` comes from each `LootPackEntry`'s 5th constructor argument, and the table shows values of **3, 4, 5, 11** across tiers. To settle: read `LootPackEntry.GetBonusProperties()`.

### 6.2 Which properties, and at what intensity?

**`[HIGH]` — `Scripts/Items/Tools/BaseRunicTool.cs`.**

```csharp
public static int GetUniqueRandom(int count)
{
    // picks an index in [0, count) that is NOT already set in the static BitArray m_Props,
    // then marks it set. Returns -1 when every slot is taken.
}

// :970-999 — THE INTENSITY ROLL. This is the heart of the loot generator.
private static int Scale(int min, int max, int low, int high)
{
    int percent;
    if (m_PlayerMade) {
        percent = Utility.RandomMinMax(min, max);              // runic crafting: uniform in [min,max] intensity
    } else {
        int v = Utility.RandomMinMax(0, 10000);
        v = (int)Math.Sqrt(v);                                 // sqrt → biased LOW
        v = 100 - v;                                           // …then inverted → biased HIGH
        if (LootPack.CheckLuck(m_LuckChance)) v += 10;         // luck: +10 intensity points
        percent = Math.Min(max, min + AOS.Scale((max - min), v));   // AOS.Scale(x,p) = x*p/100
    }
    int scaledBy = Math.Abs(high - low) + 1;
    if (scaledBy != 0) scaledBy = 10000 / scaledBy;
    percent *= (10000 + scaledBy);
    return low + (((high - low) * percent) / 1000001);
}

private static void ApplyAttribute(AosAttributes attrs, int min, int max, AosAttribute attr, int low, int high, int scale)
{
    if (attr == AosAttribute.CastSpeed) attrs[attr] += Scale(min, max, low / scale, high / scale) * scale;  // CastSpeed STACKS
    else                                attrs[attr]  = Scale(min, max, low / scale, high / scale) * scale;
    if (attr == AosAttribute.SpellChanneling) attrs[AosAttribute.CastSpeed] -= 1;   // SpellChanneling costs 1 FC
}
```

**The intensity distribution, restated:**
```
r       = Random(0, 10000)
v       = 100 − floor(sqrt(r))        // r uniform → v concentrated near 100
if (luck roll succeeds) v += 10
percent = min(max, min + (max − min) × v / 100)
```
Because `sqrt(r)` is dense near high values when r is large… actually `sqrt` is dense near **0** for small r and sparse near 100 for large r; after `100 − sqrt(r)` the distribution is **dense near 100** (i.e. **high intensity is the most likely outcome**) with a long tail toward low intensity. **`[HIGH]` for the code; `[MED]` for the characterisation of the histogram.**

`Utility.RandomMinMax(m_LuckChance)` gate — `LootPack.CheckLuck(chance) => chance > Utility.Random(10000)`. And the luck chance itself:

**`[HIGH]` — `LootPack.cs:12-43`:**
```csharp
public static int GetLuckChance(int luck) { return (int)(Math.Pow(luck, 1 / 1.8) * 100); }
public static int GetLuckChance(Mobile killer, Mobile victim) {
    if (!Core.AOS) return 0;
    int luck = killer is PlayerMobile ? ((PlayerMobile)killer).RealLuck : killer.Luck;
    … honor perfection luck bonus …
    if (luck < 0) return 0;
    if (!Core.SE && luck > 1200) luck = 1200;      // pre-SE luck cap 1200
    return GetLuckChance(luck);
}
public static bool CheckLuck(int chance) { return (chance > Utility.Random(10000)); }
```
```
luckChance = trunc(luck ^ (1/1.8) × 100)         // luck capped at 1200 pre-SE
luck fires  = luckChance > Random(10000)         // note: 10000, not 100
```
**Luck 1200 → `1200^0.5556 × 100 ≈ 5,030`, so a ~50 % luck-fire rate.** **`[MED]`** (arithmetic on a `[HIGH]` formula).

**Which property slots exist, and how many get rolled `[HIGH]`** — `ApplyAttributesTo` variants:
```csharp
// BaseRunicTool.cs:285-297 (weapons)
if (weapon is BaseRanged) { m_Props.Set(2, true); }             // ranged: no UseBestSkill, no MageWeapon
else { m_Props.Set(25, true); m_Props.Set(26, true); }          // melee: no Balanced, no Velocity
for (int i = 0; i < attributeCount; ++i) { int random = GetUniqueRandom(27); … }   // 27 weapon property groups

// :492-510 (armour)
m_Props.Set(3, true);                                           // no MageArmor by default
if (leather) { m_Props.Set(0, true); m_Props.Set(2, true); }    // leather: no lower-req, no durability bonus
if (elf-only) m_Props.Set(7, true);                             // elves have innate night sight
int random = GetUniqueRandom(baseCount);

// :635  hats    → GetUniqueRandom(19)
// :740  jewels  → GetUniqueRandom(24)
// :849  spellbooks → GetUniqueRandom(16)
```
**Property-group counts: weapons 27, armour `baseCount`, hats 19, jewels 24, spellbooks 16.** `GetUniqueRandom` guarantees **no duplicate property group** per item. **`[HIGH]`**

### 6.3 Loot pack tiers

**`[HIGH]` — `Scripts/Misc/LootPack.cs`.** `LootPackEntry` constructor: `(bool atSpawnTime, LootPackItem[] items, double chance, int quantity, int maxProps, int minIntensity, int maxIntensity)`, with the `double chance` being a **percentage × 100** compared against `Utility.Random(10000)` (`:99`).

The magic-item tables used by each tier:

| Variable | Line | Contents |
|---|---|---|
| `OldMagicItems` | `:157` | pre-AoS weapon/armour drop table |
| `AosMagicItemsPoor` | `:166` | weakest AoS items |
| `AosMagicItemsMeagerType1` / `Type2` | `:173`, `:180` | |
| `AosMagicItemsAverageType1` / `Type2` | `:187`, `:194` | |
| `AosMagicItemsRichType1` / `Type2` | `:201`, `:208` | |
| `AosMagicItemsFilthyRichType1` / `Type2` | `:215`, `:222` | |
| `AosMagicItemsUltraRich` | `:229` | best |

Representative entries, with their **max properties** and **intensity window** — this is directly implementable:

| Pack | Entry (line) | Chance (÷100 = %) | Qty | **maxProps** | **minIntensity** | **maxIntensity** |
|---|---|---|---|---|---|---|
| Average | AosMagicItemsRichType1 (`:243`) | 100.00 → 1.00 % | 1-3 | **3** | 0 | 75 |
| Average | AosMagicItemsRichType1 (`:244`) | 80.00 → 0.80 % | 1-3 | 3 | 0 | 75 |
| Average | AosMagicItemsRichType1 (`:245`) | 60.00 → 0.60 % | 1-5 | **5** | 0 | 100 |
| Poor | AosMagicItemsPoor (`:255`) | 1.00 → 0.01 % | 1-5 | 5 | 0 | 100 |
| Meager | AosMagicItemsMeagerType1 (`:264`) | 20.40 → 0.204 % | 1-2 | 2 | 0 | 50 |
| Meager | AosMagicItemsMeagerType2 (`:265`) | 10.20 → 0.102 % | 1-5 | 5 | 0 | 100 |
| Average | AosMagicItemsAverageType1 (`:274`) | 32.80 → 0.328 % | 1-3 | 3 | 0 | 50 |
| Average | AosMagicItemsAverageType1 (`:275`) | 32.80 | 1-4 | 4 | 0 | 75 |
| Average | AosMagicItemsAverageType2 (`:276`) | 19.50 | 1-5 | 5 | 0 | 100 |
| Rich | AosMagicItemsRichType1 (`:285`) | 76.30 → 0.763 % | 1-4 | 4 | 0 | 75 |
| Rich | AosMagicItemsRichType2 (`:287`) | 61.70 | 1-5 | 5 | 0 | 100 |
| Filthy Rich | AosMagicItemsFilthyRichType1 (`:296`) | 79.50 | 1-5 | 5 | 0 | 100 |
| Filthy Rich | AosMagicItemsFilthyRichType2 (`:298`) | 77.60 | 1-5 | 5 | **25** | 100 |
| Ultra Rich | AosMagicItemsUltraRich (`:307-311`) | 100.00 | 1-5 | 5 | **25** | 100 |
| Ultra Rich | AosMagicItemsUltraRich (`:312`) | 100.00 | 1-5 | 5 | **33** | 100 |
| Ultra Rich | AosMagicItemsUltraRich (`:329-330`) | 100.00 | 1-5 | 5 | **50** | 100 |
| Old (classic) | `OldMagicItems` (`:429`) | 1.00 | 1-1 | 1 | 0 | 60 |
| Old (classic) | `OldMagicItems` (`:430`) | 0.20 | 1-1 | 1 | 10 | 70 |
| Old (classic) | `OldMagicItems` (`:448`) | 20.00 | 1-1 | 1 | 60 | 100 |
| Old (classic) | `OldMagicItems` (`:469-474`) | 100.00 ×6 | 1-1 | 1 | 40-60 | 100 |

**The classic pre-AoS loot tables keep `maxProps = 1`** — so pre-AoS magic items have exactly **one** magic attribute (accuracy level *or* damage level *or* durability level), which is correct for the era. **AoS tables go up to 5.** **`[HIGH]`**

`GetLuckChanceForKiller(Mobile m)` returns `240` when the victim is not a `BaseCreature` — i.e. a **flat 2.4 %** luck-fire base. **`[HIGH]`** — `:45-72`.

### 6.4 Runic crafting tiers

**`[HIGH]` — `Scripts/Misc/ResourceInfo.cs:163-408`, consumed by `BaseRunicTool`.**

```csharp
// BaseRunicTool.cs:932-968 — the runic path
public void ApplyAttributesTo(BaseWeapon weapon) {
    CraftAttributeInfo attrs = CraftResources.GetInfo(Resource).AttributeInfo;
    if (attrs == null) return;
    int attributeCount = Utility.RandomMinMax(attrs.RunicMinAttributes, attrs.RunicMaxAttributes);
    int min = attrs.RunicMinIntensity;
    int max = attrs.RunicMaxIntensity;
    ApplyAttributesTo(weapon, true, 0, attributeCount, min, max);   // playerMade = true
}
```
Because `playerMade = true`, `Scale()` takes the **uniform** branch: `percent = RandomMinMax(min, max)`. **So runic crafting has a flat intensity distribution, unlike loot's sqrt-biased one.** **`[HIGH]`**

| Runic tier | Runic attrs min–max | Intensity pre-ML | Intensity ML |
|---|---|---|---|
| Dull Copper | 1–2 | 10–35 | 40–100 |
| Shadow Iron | 2–2 | 20–45 | 45–100 |
| Copper | 2–3 | 25–50 | 50–100 |
| Bronze | 3–3 | 30–65 | 55–100 |
| Gold | 3–4 | 35–75 | 60–100 |
| Agapite | 4–4 | 40–80 | 65–100 |
| Verite | 4–5 | 45–90 | 70–100 |
| Valorite | 5–5 | 50–100 | 85–100 |
| Spined Leather | 1–3 | 20–40 | 40–100 |
| Horned Leather | 3–? | 40–75 | 45–100 |
| Barbed Leather | 4–? | 45–90 | 70–100 |
| Oak Wood | 1 | — | 50 |
| Ash Wood | 2 | — | 75 |
| Yew Wood | 3 | — | 90 |
| Heartwood | 4 | — | 100 |

> **The ML intensity table is dramatically stronger than the pre-ML one.** A Mondain's Legacy Valorite runic hammer gives **5 properties at 85–100 % intensity every time**, vs 5 properties at 50–100 % before ML. If your clone targets AoS-era, use the **pre-ML** column.

### 6.5 The modern budget generator (`Core.HS` only)

**`[HIGH]` — `Scripts/Services/LootGeneration/RandomItemGenerator.cs`.** Included for completeness; **do not** use it for an AoS-era clone.

```csharp
FeluccaLuckBonus      = Config.Get("Loot.FeluccaLuckBonus", 1000);
FeluccaBudgetBonus    = Config.Get("Loot.FeluccaBudgetBonus", 100);
MaxBaseBudget         = Config.Get("Loot.MaxBaseBudget", 700);
MinBaseBudget         = Config.Get("Loot.MinBaseBudget", 150);
MaxProps              = Config.Get("Loot.MaxProps", 11);
MaxAdjustedBudget     = Config.Get("Loot.MaxAdjustedBudget", 1450);
MinAdjustedBudget     = Config.Get("Loot.MinAdjustedBudget", 150);

public static int GetBaseBudget(BaseCreature bc) {
    if (bc is BaseRenowned) return MaxBaseBudget;
    return bc.Fame / (20500 / MaxBaseBudget);        // 24000 fame (Balron) ≈ MaxBaseBudget
}
// boss bonuses: BaseRenowned/TRex/… +100 ; BaseChampion/… +150 ; BasePeerless/… +250 ; ClockworkExodus/… +350
```
The **new loot system is a budget system**: each creature's fame yields a *property-budget*, each rolled property consumes budget in proportion to its intensity and its `ItemPropertyInfo.Weight`, and rolling stops when the budget is exhausted (with `MaxProps = 11`). The exact budget-consumption arithmetic is in `RunicReforging.GenerateRandomItem(item, luckChance, min, max)` → **`[UNVERIFIED]` at formula level** (3,391-line file, not read line-by-line). To settle: read `Scripts/Services/LootGeneration/RunicReforging/RunicReforging.cs`, specifically `GenerateRandomItem` and the `GetBudget`/`ConsumeBudget` helpers.

### 6.6 Minimum viable loot generator recipe

For an AoS-era faithful generator, in order:

1. Kill a creature → look up its `LootPack` (assigned per creature class) → for each entry, roll `entry.Chance > Random(10000)`.
2. If the entry is a magic-item table, pick an item type by weighted `LootPackItem.Chance`.
3. `props = 1 + GetBonusProperties()`, `+1` if `CheckLuck(luckChance)`, clamp to the entry's `maxProps`.
4. For `props` iterations: pick a property group with `GetUniqueRandom(N)` (N = 27 weapons / 19 hats / 24 jewels / 16 spellbooks / armour baseCount) respecting the item-class exclusions.
5. For each chosen property, roll intensity with `Scale(minIntensity, maxIntensity, low, high)` — the sqrt-biased formula — and write it via `ApplyAttribute`.
6. Dedupe is automatic (`m_Props` bit array reset per item).
7. Over-cap "powerful loot" values come from `GetMaxOvercappedRange(item, id)` — a discrete pick from the `pow` list.

---

## Appendix A — Confidence summary

| Topic | Confidence | Notes |
|---|---|---|
| Swing delay, all 4 era variants | **HIGH** | quoted from `BaseWeapon.cs:1541-1631` |
| Classic damage formula | **HIGH** | quoted from `BaseWeapon.cs:3825-3930` |
| AoS damage formula | **HIGH** | quoted from `BaseWeapon.cs:3768-3823` |
| Hit chance, HCI/DCI caps | **HIGH** | quoted from `BaseWeapon.cs:1415-1539` |
| Resistance application | **HIGH** | quoted from `AOS.cs:99-217` |
| Pre-AoS AR / hit-location model | **HIGH** | quoted from `BaseWeapon.cs:2014-2100`, `BaseArmor.cs:2591+` |
| Parry (AoS/ML) | **HIGH** | quoted from `BaseWeapon.cs:1756-1870` |
| **Parry (pre-AoS/UOR)** | **UNVERIFIED** | not implemented in this tree |
| All 64 spells: mana, reagents, delay | **HIGH** | mechanically parsed |
| Spell skill bands | **MED** | source formula exact; scalar is an approximation of the OSI table |
| AoS spell damage / EvalInt | **HIGH** | quoted from `Spell.cs:201-239` |
| Classic spell damage / EvalInt / resist | **HIGH** | quoted from `Spell.cs:444-483`, `MagerySpell.cs` |
| FC/FCR caps and formulas | **HIGH** | quoted from `Spell.cs:999-1086` |
| Protection interruption chance | **UNVERIFIED** | `Protection.cs` not read |
| Meditation regen formula | **UNVERIFIED** | `Mobile.cs` regen region not read |
| Inscription scroll-copy rule | **UNVERIFIED** | `Inscribe.cs` not read |
| Poison tables + tick formula | **HIGH** | quoted from `Poison.cs:19-281` |
| Poisoning skill windows | **HIGH** | extracted from potion classes |
| Bandage heal amount + delay | **HIGH** | quoted from `Bandage.cs:503-564`, `:708-761` |
| AoS bandage "slips" penalty | **LOW** | source carries `// TODO: Verify algorithm` |
| Durability loss rates | **HIGH** | quoted from `BaseWeapon.cs:2310-2354`, `BaseArmor.cs:2591+` |
| Armour durability property tiers | partial | `Fortified`/`Indestructible` values past the excerpt |
| Repair rules | **UNVERIFIED** | `CraftItem` repair branch not read |
| Death/corpse decay | **HIGH** | quoted from `Mobile.cs:3975-4094`, `Corpse.cs` |
| Stat/skill loss on death | **UNVERIFIED** | `PlayerMobile.cs` not read |
| Weapon catalogue (134 rows) | **HIGH** | mechanically parsed, 0 hand-entered values |
| Weapon **layer** | **UNVERIFIED** | server does not declare it; comes from `tiledata.mul` |
| Armour catalogue (165 rows) | **HIGH** | mechanically parsed |
| Craft skill requirements | **HIGH** | mechanically parsed from `Def*.cs` |
| Material tiers (weapons + armour) | **HIGH** | quoted from `ResourceInfo.cs:163-408` |
| Special-move mana costs + list | **HIGH** | mechanically parsed from ModernUO |
| Special-move effects | **HIGH** for mana/scalar; **MED** for prose effects |
| Item-property enum values | **HIGH** | quoted from `AOS.cs` |
| Item-property intensity/weight table (159 rows) | **HIGH** | mechanically parsed from `ItemPropertyInfo.cs` |
| Use-time property caps | **HIGH** | quoted from the consuming sites |
| Slayer list + weights | **HIGH** | mechanically parsed |
| **Slayer damage multiplier / type mapping** | **UNVERIFIED** | not read |
| Loot pack tiers + maxProps/intensity | **HIGH** | quoted from `LootPack.cs` |
| `GetBonusProperties()` | **UNVERIFIED** | method body not read |
| Intensity `Scale()` formula | **HIGH** | quoted from `BaseRunicTool.cs:970-999` |
| Luck chance formula | **HIGH** | quoted from `LootPack.cs:12-43` |
| Runic tier attrs/intensity | **HIGH** | quoted from `ResourceInfo.cs` |
| Modern budget loot generator | **UNVERIFIED** at formula level | `RunicReforging.cs` not read |
| Reagent names, ids, vendor prices | **HIGH** | parsed from reagent classes + `SBMage.cs` |
| Scroll/spellbook cast behaviour | **HIGH** for scroll/wand/spellstone; **UNVERIFIED** for `AddSpell` |

## Appendix B — Things that would need measuring rather than reading

1. **Classic stamina cost per swing.** Not in any source consulted. Needs an OSI/RunUO 1.0.0 read or a shard measurement.
2. **Pre-AoS / UOR parry.** Not implemented. Needs the UOR-era formula.
3. **Per-item `Layer` for every weapon and armour piece.** Comes from client `tiledata.mul`. Dump it from ClassicUO or a UO client install.
4. **Slayer damage multiplier and creature→slayer mapping.** Constants not read.
5. **`GetBonusProperties()`** in `LootPack.cs` — needed to finish the property-count distribution.
6. **Repair rules** (`CraftItem` repair branch) and **stat/skill loss on death** (`PlayerMobile.cs`).
7. **Meditation regen** and **Protection's interruption chance** — both in files not read line-by-line.
8. **`RunicReforging` budget arithmetic** — only needed if you target High Seas-era loot.
9. **The `Meteor Swarm` mana override returning 0** (`Scripts/Spells/Seventh/MeteorSwarm.cs`) — either an intentional quirk or a ServUO bug; verify against another server.
10. **The remaining `ArmorDurabilityLevel` values** (`Fortified`, `Indestructible`) in `BaseArmor.GetDurabilityBonus()`.

## Appendix C — Source index (paths verified to exist)

ServUO `pub57`:
```
Server/Mobile.cs                                    Server/Item.cs
Scripts/Misc/AOS.cs                                 Scripts/Misc/Poison.cs
Scripts/Misc/LootPack.cs                            Scripts/Misc/ResourceInfo.cs
Scripts/Items/Equipment/Weapons/BaseWeapon.cs       Scripts/Items/Equipment/Weapons/BaseRanged.cs
Scripts/Items/Equipment/Weapons/BaseBashing.cs      Scripts/Items/Equipment/Weapons/BaseStaff.cs
Scripts/Items/Equipment/Weapons/Fists.cs            Scripts/Items/Equipment/Weapons/BaseSword.cs
Scripts/Items/Equipment/Armor/BaseArmor.cs          Scripts/Items/Equipment/Armor/BaseShield.cs
Scripts/Items/Equipment/Jewelry/BaseJewel.cs        Scripts/Items/Equipment/Clothing/BaseClothing.cs
Scripts/Items/Resource/Bandage.cs                   Scripts/Items/Consumables/BaseReagent.cs
Scripts/Items/Tools/BaseRunicTool.cs                Scripts/Items/Corpses/Corpse.cs
Scripts/Skills/Poisoning.cs                         Scripts/Skills/ArmsLore.cs
Scripts/Spells/Base/Spell.cs                        Scripts/Spells/Base/MagerySpell.cs
Scripts/Spells/Base/SpellHelper.cs                  Scripts/Spells/Base/SpellCircle.cs
Scripts/Spells/Base/SpecialMove.cs                  Scripts/Spells/Base/DisturbType.cs
Scripts/Spells/Reagent.cs                           Scripts/Spells/{First..Eighth}/*.cs
Scripts/Services/Craft/Def{Blacksmithy,Tailoring,BowFletching,Carpentry,Masonry,Glassblowing,Inscription}.cs
Scripts/Services/LootGeneration/ItemPropertyInfo.cs Scripts/Services/LootGeneration/RandomItemGenerator.cs
Scripts/VendorInfo/SBMage.cs
```

ModernUO `main`:
```
Projects/Server/Mobile.cs
Projects/UOContent/Items/Weapons/Abilities/*.cs   (31 ability classes + WeaponAbility.cs)
Projects/UOContent/Items/Weapons/BaseWeapon.cs
Projects/UOContent/Items/Armor/BaseArmor.cs
Projects/UOContent/Misc/LootPack.cs
```

Generated data artifacts (same directory as this file, `research/_src/`):
`weapons3.json`, `weapons_table.md`, `armor_raw.json`, `armor_table.md`, `spells_raw.json`,
`itemprops_table.tsv`, `craft_raw.json`, `abilities_raw.json`.
