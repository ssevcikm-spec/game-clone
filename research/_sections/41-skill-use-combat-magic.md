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
