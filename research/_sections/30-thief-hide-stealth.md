## 5. Hide / Stealth / Thief package

Primary source: `ServUO` @ `pub57` = `E:\Workspaces\game-clone\.research-src\servuo` (cited `ServUO:<path>:<line>`, URL form
`https://github.com/ServUO/ServUO/blob/pub57/<path>#L<line>`). Secondary: `ModernUO` = `.research-src\modernuo`
(cited `ModernUO:Projects/<path>:<line>`, URL form `https://github.com/modernuo/ModernUO/blob/main/Projects/<path>#L<line>`).
`[WEB]` prose is UOGuide. Every number below is a literal read out of source or an explicit derivation that shows its arithmetic.

### 5.0 Files read end-to-end + the one shared primitive

| File | Lines | Role |
|---|---|---|
| `ServUO:Scripts/Skills/Hiding.cs` | 129 | Hiding skill callback |
| `ServUO:Scripts/Skills/Stealth.cs` | 131 | Stealth skill callback + armor table |
| `ServUO:Scripts/Skills/Snooping.cs` | 100 | `Container.SnoopHandler` |
| `ServUO:Scripts/Skills/Stealing.cs` | 646 | Stealing callback, target, `StolenItem` |
| `ServUO:Scripts/Skills/DetectHidden.cs` | 211 | active + passive detect, `CanDetect` |
| `ServUO:Scripts/Skills/Tracking.cs` | 394 | tracking gumps, stalking bonus |
| `ServUO:Scripts/Skills/RemoveTrap.cs` | 411 | trap disarm + chest timer |
| `ServUO:Scripts/Skills/ForensicEval.cs` | 173 | corpse/mobile/lock forensics |
| `ServUO:Server/Mobile.cs` | 12821 | Hidden / Warmode / Criminal / step engine / RevealingAction |
| `ServUO:Scripts/Mobiles/PlayerMobile.cs` | 6990 | step engine for players, PermaFlags, buff icon |
| `ServUO:Scripts/Misc/SkillCheck.cs` | 808 | success roll + skill gain |
| `ServUO:Scripts/Misc/Notoriety.cs` | 569 | notoriety + hues |
| `ServUO:Scripts/Regions/GuardedRegion.cs` | 470 | criminal → guard response |

**Skill-check primitive** `[SRC]` `ServUO:Scripts/Misc/SkillCheck.cs:286-311` (`Mobile_SkillCheckTarget`):

```
value = skill.Value                       // CURRENT value incl. modifiers, not Base
if (value <  minSkill) return false       // Too difficult
if (value >= maxSkill) return true        // No challenge
chance = (value - minSkill) / (maxSkill - minSkill)
```

`[SRC]` `ServUO:Scripts/Misc/SkillCheck.cs:240-259` (`CheckSkill`): `success = Utility.Random(100) <= (int)(chance * 100);`
`[SRC]` `ServUO:Server/Utility.cs:921-924` `Random(count) => RandomImpl.Next(count)` ⇒ range `[0, count-1]`.
⇒ **ServUO effective success probability = `((int)(chance*100) + 1) / 100`** (floor-quantised, +1 % bias). Derived, `[SRC]`.
`[SRC]` `ServUO:Server/Utility.cs:889-903` `RandomMinMax(min,max) => min + Next((max-min)+1)` ⇒ inclusive both ends.
`[SRC]` `ServUO:Server/Utility.cs:931-934` `RandomDouble() => NextDouble()` ⇒ `[0,1)`.
`ModernUO` differs: `success = chance >= Utility.RandomDouble()` ⇒ probability exactly `chance` (`ModernUO:Projects/UOContent/Skills/SkillCheck.cs:115`) and it adds `|| minSkill >= maxSkill` to the "no challenge" test (`:65`). **A clone must pick one; they are not equal.**

**Skill-use plumbing** `[SRC]` `ServUO:Server/Skills.cs:886-932`: `UseSkill` calls `from.DisruptiveAction()` (`:914`) then
`from.NextSkillTime = Core.TickCount + (int)(info.Callback(from)).TotalMilliseconds` (`:916`). The `TimeSpan` each `OnUse`
returns **is** the reuse delay. If `info.Callback == null` the client is told `500014` "That skill cannot be used directly."
⇒ **Snooping has no `Callback` at all** (see 5.3).

**Expansion gates** `[SRC]` `ServUO:Server/Main.cs:140-154`: `AOS/SE/ML/SA/HS/TOL/EJ` are `Expansion >= Expansion.X`.
`[ERA]` Mapping used below (classic 1997 → AoS 2003 → SE 2005 → ML 2007 → SA 2009 → HS 2015 → EJ 2020s) per `_BRIEF.md`.

**Skill info rows** `[SRC]` `ServUO:Server/Skills.cs:594-653` (id, name, stat gain weights, GainFactor, primary/secondary):

| Skill | ID | Row | StrGain/DexGain/IntGain | GainFactor | Primary / Secondary |
|---|---|---|---|---|---|
| Detect Hidden | 14 | `ServUO:Server/Skills.cs:610` | 0.0 / 0.4 / 0.6 | 1.0 | Int / Dex |
| Forensic Evaluation | 19 | `ServUO:Server/Skills.cs:615` | 0.0 / 0.2 / 0.8 | 1.0 | Int / Dex |
| Hiding | 21 | `ServUO:Server/Skills.cs:617` | 0.0 / 0.8 / 0.2 | 1.0 | Dex / Int |
| Snooping | 28 | `ServUO:Server/Skills.cs:624` | 0.0 / 2.5 / 0.0 | 1.0 | Dex / Int |
| Stealing | 33 | `ServUO:Server/Skills.cs:629` | 0.0 / 1.0 / 0.0 | 1.0 | Dex / Int |
| Tracking | 38 | `ServUO:Server/Skills.cs:634` | 0.0 / 1.25 / 1.25 | 1.0 | Int / Dex |
| Stealth | 47 | `ServUO:Server/Skills.cs:643` | 0.0 / 0.0 / 0.0 | 1.0 | Dex / Int |
| Remove Trap | 48 | `ServUO:Server/Skills.cs:644` | 0.0 / 0.0 / 0.0 | 1.0 | Dex / Int |

`[SRC]` `ServUO:Scripts/Misc/SkillCheck.cs:59-123` — anti-macro flag `true` for DetectHidden(14), Forensics(19), Hiding(21),
Snooping(28), Stealing(33), Tracking(38), Stealth(47), RemoveTrap(48); `Allowance = 3` uses per location, `AntiMacroExpire = 5 min`,
`LocationSize = 4` (`:28,33,38`).

---

### 5.1 HIDING — `ServUO:Scripts/Skills/Hiding.cs`

Callback registered at `:23` (`SkillInfo.Table[21]`). `CombatOverride` static at `:9-20` bypasses every "watched" test.

**Preconditions / early exits** `[SRC]`

| Order | Condition | Line | Effect | Returned delay |
|---|---|---|---|---|
| 1 | `m.Spell != null` | `Hiding.cs:28-32` | `501238` "You are busy doing something else and cannot hide." | `1.0 s` |
| 2 | `VvV.ManaSpike.UnderEffects(m)` | `Hiding.cs:34-37` | *no message* | `1.0 s` |
| 3 | `Core.ML && m.Target != null` | `Hiding.cs:39-42` | `Targeting.Target.Cancel(m)` | (continues) |

**House bonus (the free-hide cases)** `[SRC]` `Hiding.cs:44-68`

| Case | Line | `bonus` | Resulting window | Outcome |
|---|---|---|---|---|
| Standing in a house where `IsFriend(m)` | `:46-51` | `100.0` | `CheckSkill(Hiding, -100.0, 0.0)` | `value >= 0` ⇒ `maxSkill` branch returns **true unconditionally** = FACE-HIDE |
| `!Core.AOS` and a house is found at `(x±1, y, 127)` or `(x, y±1, 127)` within 16 of the mobile's `Map` | `:52-68` | `50.0` | `CheckSkill(Hiding, -50.0, 50.0)` | `Hiding.Value >= 50.0` ⇒ auto-success; else `chance = (value+50)/100` |
| otherwise | — | `0.0` | `CheckSkill(Hiding, 0.0, 100.0)` | `chance = value/100` |

`[WEB]` "Hiding is always successful within a player's own house." — [UOGuide — Hiding](https://www.uoguide.com/Hiding) ⇒ `[SRC+WEB]`.
`[ERA]` The 4-tile house scan exists only pre-AoS (`!Core.AOS`); the friend bonus survived into live UO. `[SRC]`

**"Being watched" penalty** — it is a hard block, not a skill penalty `[SRC]` `Hiding.cs:70-97`

```
skill = Math.Min(100, (int)m.Skills[Hiding].Value)                        // Hiding.cs:71
range = Math.Min((int)((100 - skill) / 2) + 8, 18)                        // Hiding.cs:72  ("Cap of 18 not OSI-exact, intentional difference")
badCombat = !CombatOverride && m.Combatant is Mobile
            && m.InRange(m.Combatant.Location, range)
            && ((Mobile)m.Combatant).InLOS(m.Combatant)                   // Hiding.cs:74  <-- argument is the COMBATANT, not the hider
```

Then, if not already bad, a second sweep at `:81-93`: **any** mobile within `range` with `check.InLOS(m) && check.Combatant == m` sets
`badCombat = true` and aborts the check. Only if neither fired does `CheckSkill` run (`:96`).

| Hiding skill | `range` (tiles) | line |
|---|---|---|
| 0 – 80 | 18 | `Hiding.cs:72` |
| 81 – 82 | 17 | derived |
| 84 | 16 | derived |
| 90 | 13 | derived |
| 96 | 10 | derived |
| 100 | 8 | derived |

`[WEB]` "At GM Hiding, a character may hide in plain sight of a hostile monster or other player only 8 tiles away." —
[UOGuide — Hiding](https://www.uoguide.com/Hiding) ⇒ `[SRC+WEB]` for the 8-tile GM value.

**Message / hue table** `[SRC]`

| Clue | Text | Hue | Line |
|---|---|---|---|
| `501237` | You can't seem to hide right now. | `0x22` `MessageType.Regular` | `Hiding.cs:103` |
| `501238` | You are busy doing something else and cannot hide. | (SendLocalizedMessage) | `Hiding.cs:30` |
| `501240` | You have hidden yourself well. | `0x1F4` | `Hiding.cs:116` |
| `501241` | You can't seem to hide here. | `0x22` | `Hiding.cs:122` |

**Delays / outcomes** `[SRC]`

| Branch | Lines | Effects | Delay |
|---|---|---|---|
| `badCombat` | `:99-107` | `m.RevealingAction()` + `501237` | **`TimeSpan.Zero`** (no cooldown at all) |
| success | `:110-117` | `m.Hidden = true`; `m.Warmode = false`; `Sixth.InvisibilitySpell.RemoveTimer(m)`; `Items.InvisibilityPotion.RemoveTimer(m)`; `501240` | `10.0 s` |
| failure | `:118-125` | `m.RevealingAction()` + `501241` | `10.0 s` |

**Side effects of `Hidden = true`** `[SRC]`

| Effect | Line |
|---|---|
| `Mobile.Hidden` setter: if `m_Hidden` becomes true → `Warmode = false` if in warmode, else `Combatant = null` | `ServUO:Server/Mobile.cs:8963-8973` |
| `OnHiddenChanged()` → `m_AllowedStealthSteps = 0` + resend `RemovePacket`/`MobileIncoming`/OPL to every client in range | `ServUO:Server/Mobile.cs:8980-9012` |
| `PlayerMobile.OnHiddenChanged()` → removes `BuffIcon.Invisibility`; if hidden adds `BuffInfo(BuffIcon.HidingAndOrStealth, 1075655)` else removes it | `ServUO:Scripts/Mobiles/PlayerMobile.cs:1735-1749` |
| `BuffIcon.HidingAndOrStealth` enum member | `ServUO:Scripts/Misc/BuffIcons.cs:257` |
| `RevealingAction()` → `if (m_Hidden && IsPlayer()) Hidden = false; m_IsStealthing = false; DisruptiveAction();` | `ServUO:Server/Mobile.cs:7153-7163` |

### 5.2 STEALTH — `ServUO:Scripts/Skills/Stealth.cs`

**Preconditions, exact order** `[SRC]` `Stealth.cs:70-126`

| # | Test | Line | Message | Extra | Return |
|---|---|---|---|---|---|
| 1 | `!m.Hidden` | `:72-75` | `502725` "You must hide first" | *no reveal* | 10.0 s |
| 2 | `m.Flying` | `:76-81` | `1113415` "You cannot use this ability while flying." | `RevealingAction()` + remove HidingAndOrStealth buff | 10.0 s |
| 3 | `m.Skills[Hiding].Base < HidingRequirement` | `:82-87` | `502726` "You are not hidden well enough.  Become better at hiding." | reveal + buff removal | 10.0 s |
| 4 | `!m.CanBeginAction(typeof(Stealth))` | `:88-93` | `1063086` "You cannot use this skill right now." | reveal + buff removal | 10.0 s |
| 5 | `armorRating >= (Core.AOS ? 42 : 26)` | `:98-103` | `502727` "You could not hope to move quietly wearing this much armor." | reveal + buff removal | 10.0 s |
| 6 | `CheckSkill` fails | `:120-125` | `502731` "You fail in your attempt to move unnoticed." | reveal + buff removal | 10.0 s |
| 7 | `CheckSkill` succeeds | `:104-119` | `502730` "You begin to move quietly." | steps, `IsStealthing = true`, `BuffInfo(HidingAndOrStealth, 1044107, 1075655)` | 10.0 s |

**Hiding requirement** `[SRC]` `Stealth.cs:24-30`: `Core.ML ? 30.0 : (Core.SE ? 50.0 : 80.0)`.
`[ERA]` 80 → 50 (SE) → 30 (ML). `[WEB]` "A character must have at least 30.0 in Hiding to be able to use Stealth." —
[UOGuide — Stealth](https://www.uoguide.com/Stealth) ⇒ `[SRC+WEB]` for the ML-era value. The `50`/`80` values are `[SRC]` only.

**Exact success formula** `[SRC]` `Stealth.cs:104`

```
CheckSkill(Stealth, -20.0 + (armorRating * 2), (Core.AOS ? 60.0 : 80.0) + (armorRating * 2))
⇒ chance = (Stealth.Value - (2*AR - 20)) / ((AoS?60:80) + 2*AR - (2*AR - 20))
         = (Stealth.Value - 2*AR + 20) / (AoS ? 80 : 100)
```

So the denominator is a **constant** (80 AoS / 100 non-AoS); every point of armor rating shifts the *minimum* by +2, i.e. costs
2 skill points of headroom. Derived `[SRC]`.

| `armorRating` | AoS window | non-AoS window | `chance` at Stealth 25 (AoS) |
|---|---|---|---|
| 0 | `-20.0 .. 60.0` | `-20.0 .. 80.0` | `(25+20)/80 = 0.5625` |
| 5 | `-10.0 .. 70.0` | `-10.0 .. 90.0` | `(25+10)/80 = 0.4375` |
| 10 | `0.0 .. 80.0` | `0.0 .. 100.0` | `(25-0)/80 = 0.3125` |
| 20 | `20.0 .. 100.0` | `20.0 .. 120.0` | `(25-20)/80 = 0.0625` |
| 21 (AoS) | `22.0 .. 102.0` | `22.0 .. 122.0` | `25 < 22`? no → `0.0375` |
| ≥ 42 AoS / ≥ 26 non-AoS | — | — | blocked by precondition 5 |

**Armor restriction table (verbatim)** `[SRC]` `Stealth.cs:9-23` — `m_ArmorTable[materialType, bodyPosition]`

```
//      Gorget  Gloves  Helmet  Arms  Legs  Chest  Shield
/* Cloth   */ { 0, 0,  0,  0,  0,  0,  0 },
/* Leather */ { 0, 0,  0,  0,  0,  0,  0 },
/* Studded */ { 2, 2,  0,  4,  6, 10,  0 },
/* Bone    */ { 0, 5, 10, 10, 15, 25,  0 },
/* Spined  */ { 0, 0,  0,  0,  0,  0,  0 },
/* Horned  */ { 0, 0,  0,  0,  0,  0,  0 },
/* Barbed  */ { 0, 0,  0,  0,  0,  0,  0 },
/* Ring    */ { 0, 5,  0, 10, 15, 25,  0 },
/* Chain   */ { 0, 0, 10,  0, 15, 25,  0 },
/* Plate   */ { 5, 5, 10, 10, 15, 25,  0 },
/* Dragon  */ { 0, 5, 10, 10, 15, 25,  0 }
```

Index meaning `[SRC]`: `ArmorMaterialType` order = `Cloth, Leather, Studded, Bone, Spined, Horned, Barbed, Ringmail, Chainmail,
Plate, Dragon, Wood, Stone` (`ServUO:Scripts/Items/Equipment/Armor/ArmorEnums.cs:36-51`);
`ArmorBodyType` order = `Gorget, Gloves, Helmet, Arms, Legs, Chest, Shield` (`ArmorEnums.cs:25-34`).
`[SRC]` `BaseArmor.BodyPosition` maps layers → column: `Layer.Neck→Gorget`, `Layer.TwoHanded→Shield`, `Layer.Gloves→Gloves`,
`Layer.Helm→Helmet`, `Layer.Arms→Arms`, `Layer.InnerLegs/OuterLegs/Pants→Legs`, `Layer.InnerTorso/OuterTorso/Shirt→Chest`
(`ServUO:Scripts/Items/Equipment/Armor/BaseArmor.cs:1297-1326`).
⇒ **Shields (column 7) are 0 for every material — a shield never blocks stealth.** Derived `[SRC]`.
⇒ **Wood and Stone (rows 12/13) do not exist in the ServUO table**; `GetArmorRating` skips them via the length guard (see below). `[SRC]`

**Exact predicate** `[SRC]` `Stealth.cs:43-68`

| Step | Line | Code |
|---|---|---|
| non-AoS shortcut | `:45-46` | `if (!Core.AOS) return (int)m.ArmorRating;` |
| iterate worn items | `:50-52` | `BaseArmor armor = m.Items[i] as BaseArmor; if (armor == null) continue;` |
| bounds guard | `:60-61` | `if (materialType >= m_ArmorTable.GetLength(0) \|\| bodyPosition >= m_ArmorTable.GetLength(1)) continue;` |
| **the MageArmor exclusion** | `:63-64` | `if (armor.ArmorAttributes.MageArmor == 0) ar += m_ArmorTable[materialType, bodyPosition];` |

`[SRC]` `PlayerMobile.ArmorRating` (used by the non-AoS branch) sums `ArmsArmor/NeckArmor/HandArmor/HeadArmor/ArmsArmor/
LegsArmor/ChestArmor/ShieldArmor` with the **same** `!Core.AOS || ar.ArmorAttributes.MageArmor == 0` predicate and returns
`VirtualArmor + VirtualArmorMod + rating` (`ServUO:Scripts/Mobiles/PlayerMobile.cs:1919-1946`).
`Mobile.ArmorRating` base is `0.0` (`ServUO:Server/Mobile.cs:3729`).
`ArmorAttributes` property: `ServUO:Scripts/Items/Equipment/Armor/BaseArmor.cs:1078`; `MageArmor` is set automatically for
mage-armor-capable types only under `Core.SA` (`:3211-3213`, `IsMageArmorType` `:3289-3304`).
`MageArmor` property display hook `:3021`.

> **Naming correction:** the brief asked for `Medable` on `BaseArmor.cs` / `BaseClothing.cs`. **There is no `Medable` member
> anywhere in `ServUO` (grep over `Scripts/Items/Equipment` = 0 hits) nor in `ModernUO`.** The stealth-relevant predicate in both
> codebases is `BaseArmor.ArmorAttributes.MageArmor == 0`. `BaseClothing` never enters the stealth calculation at all because
> `Stealth.GetArmorRating` only casts to `BaseArmor` (`Stealth.cs:52`) — clothing weight/layer/medable-ness is irrelevant here. `[SRC]`

**Derived full-suit ratings** (sum of the 6 non-shield columns, derived from the table above) `[SRC]`-derived:

| Suit | AoS sum | vs AoS cap 42 | non-AoS sum | vs non-AoS cap 26 |
|---|---|---|---|---|
| Cloth / Leather / Spined / Horned / Barbed | 0 | OK | 0 | OK |
| Studded | 24 | OK | 24 | OK |
| Chainmail | 50 | BLOCKED | 50 | BLOCKED |
| Ringmail | 55 | BLOCKED | 55 | BLOCKED |
| Bone | 65 | BLOCKED | 65 | BLOCKED |
| Dragon (ServUO) | 65 | BLOCKED | 65 | BLOCKED |
| Plate | 70 | BLOCKED | 70 | BLOCKED |
| Full plate **all MageArmor** | 0 | OK | 0 | OK |
| Two pieces plate (Gorget 5 + Helm 10) | 15 | OK | 15 | OK |
| Four pieces plate (Gorget+Gloves+Helm+Arms) | 30 | OK | 30 | BLOCKED |

**The STEP mechanic** `[SRC]`

| Item | Value | Line |
|---|---|---|
| steps granted after a successful check | `int steps = (int)(m.Skills[Stealth].Value / (Core.AOS ? 5.0 : 10.0)); if (steps < 1) steps = 1;` | `Stealth.cs:106-109` |
| stored on | `m.AllowedStealthSteps = steps;` | `Stealth.cs:111` |
| flag | `m.IsStealthing = true;` | `Stealth.cs:113` |
| decrement (generic mobile) | `if (m_AllowedStealthSteps-- <= 0 \|\| (d & Direction.Running) != 0 \|\| Mounted) RevealingAction();` | `ServUO:Server/Mobile.cs:3044-3050` |
| decrement (players, `Core.SE`) | `if (!Mounted && Skills.Stealth.Value >= 25.0) { if (running) { if ((AllowedStealthSteps -= 2) <= 0) RevealingAction(); } else if (AllowedStealthSteps-- <= 0) Stealth.OnUse(this); }` | `ServUO:Scripts/Mobiles/PlayerMobile.cs:5448-5469` |
| decrement (creature pets with `CanStealth`) | same algorithm, gated on `CanStealth` (`virtual bool CanStealth => false`) | `ServUO:Scripts/Mobiles/Normal/BaseCreature.cs:4858,4861-4888` |
| reset on hidden change | `m_AllowedStealthSteps = 0;` | `ServUO:Server/Mobile.cs:8982` |

Decrement semantics: **post-decrement**, so a value of `N` permits exactly `N` steps; step `N+1` tests `0 <= 0` and fires. `[SRC]`
`AllowedStealthSteps` field/property: `ServUO:Server/Mobile.cs:803,1626`. `IsStealthing`: `ServUO:Server/Mobile.cs:3059,7073-7076`.

**Steps by skill** (derived from `Stealth.cs:106`):

| Stealth | AoS/SE+ steps (÷5) | pre-AoS steps (÷10) |
|---|---|---|
| 0 – 4.9 | 1 (floor of `value/5`, clamped to 1) | 1 |
| 25 | 5 | 2 |
| 50 | 10 | 5 |
| 80 | 16 | 8 |
| 100 | 20 | 10 |
| 120 | 24 | 12 |

`[WEB]` "Every 5 levels of Stealth increases the distance a character may walk before a skill check (e.g. 80 Stealth = 16 safe
steps per successful skill check.)" — [UOGuide — Stealth](https://www.uoguide.com/Stealth) ⇒ `[SRC+WEB]` for the AoS-era ÷5 rule.

**Per-tile behaviour and re-hide** `[SRC]` `ServUO:Scripts/Mobiles/PlayerMobile.cs:5431-5480`

| Trigger | Line | Behaviour |
|---|---|---|
| `!Core.SE` | `:5438-5441` | falls through to `base.OnMove` = the generic decrement+reveal (`Mobile.cs:3044-3050`) |
| `IsStaff()` | `:5443-5446` | `return true` — staff never lose stealth |
| `Hidden && DesignContext.Find(this) == null` (i.e. hidden and **not** in house-design mode) | `:5448` | enters the step engine |
| `Mounted` **or** `Stealth.Value < 25.0` | `:5450,5466-5469` | `RevealingAction()` — you cannot stealth mounted, and <25.0 Stealth cannot auto-stealth |
| walking, steps exhausted | `:5461-5464` | **calls `Stealth.OnUse(this)`** — a fresh skill check + fresh step allotment, silently (no message if it fails except `502731` from the handler) |
| running | `:5452-5460` | `AllowedStealthSteps -= 2`; when `<= 0` → `RevealingAction()` with **no** re-check |
| `InvisibilityPotion.HasTimer(this)` | `:5472-5477` | `InvisibilityPotion.Iterrupt(this)` |

`[WEB]` "Running while in stealth state will halve the number of safe steps and will -always- fail the stealth check afterward."
([UOGuide — Stealth](https://www.uoguide.com/Stealth)) — ServUO only *halves* the pool (`-= 2`) and reveals when it hits 0; there is
no separate "always fail" roll. **Divergence: `[WEB]` vs `[SRC]`, ServUO is the authority for the clone.**

Ninjitsu consumers of the step pool `[SRC]`: `SurpriseAttack.cs:55`, `Backstab.cs:49` require `Hidden && AllowedStealthSteps > 0`;
`KiAttack.cs:66` uses `Hidden && AllowedStealthSteps > 0`; `ShadowJump.cs:50-51,81-83` requires `pm.IsStealthing`.

### 5.3 SNOOPING — `ServUO:Scripts/Skills/Snooping.cs`

**Trigger** `[SRC]`: there is **no skill callback**. `Snooping.Configure()` installs `Container.SnoopHandler` (`Snooping.cs:12-15`).
`Container.OnSnoop(from)` invokes it (`ServUO:Server/Items/Container.cs:190-196`; delegate `:17`, field/property `:84-86`).
`Mobile.OnDoubleClick` reaches it only when the container's root parent is a mobile that considers the clicker a snoop:
`else if (root != null && root is Mobile && ((Mobile)root).IsSnoop(this)) item.OnSnoop(this);` (`ServUO:Server/Mobile.cs:4418-4421`),
and `Mobile.IsSnoop(from) => from != this` (`ServUO:Server/Mobile.cs:3618-3621`).
⇒ Consequence `[SRC]`: `SkillInfo.Table[28].Callback` stays `null`, so using Snooping from the skill list yields `500014`
"That skill cannot be used directly." (`ServUO:Server/Skills.cs:925-928`). `[WEB]` "there is no cool down timer for this skill's use"
([UOGuide — Snooping](https://www.uoguide.com/Snooping)) ⇒ `[SRC+WEB]`.

**Container ownership / eligibility cases, in order** `[SRC]` `Snooping.cs:40-98`

| # | Test | Line | Result |
|---|---|---|---|
| 1 | `from.IsStaff() \|\| from.InRange(cont.GetWorldLocation(), 1)` | `:42` | else `500446` "That is too far away." (**1 tile**) |
| 2 | `root != null && !root.Alive` | `:46-47` | silently `return` |
| 3 | `from.IsPlayer() && root is BaseCreature && !(cont is StrongBackpack)` | `:49-50` | silently `return` (players may only open pack-animal packs) |
| 4 | `root.IsStaff() && from.IsPlayer()` | `:52-56` | `500209` "You can not peek into the container." |
| 5 | `from.IsPlayer() && !CheckSnoopAllowed(from, root)` | `:58-62` | `1001018` "You cannot perform negative acts on your target." |
| 6 | `from.IsPlayer() && Snooping.Value < Utility.Random(100)` | `:64-74` | victim is notified (below) |
| 7 | `from.IsPlayer()` | `:76-77` | `Titles.AwardKarma(from, -4, true)` — **always**, success or fail |
| 8 | `from.IsStaff() \|\| from.CheckTargetSkill(Snooping, cont, 0.0, 100.0)` | `:79` | success path |
| 8a | success + `cont is TrapableContainer && ExecuteTrap(from)` | `:81-82` | `return` (never displays) |
| 8b | success | `:84` | `cont.DisplayTo(from)` |
| 8c | failure | `:88-91` | `500210` "You failed to peek into the container." then `if (Hiding.Value/2 < Utility.Random(100)) RevealingAction();` |

`CheckSnoopAllowed` `[SRC]` `Snooping.cs:17-38`:

| Target | Result | Line |
|---|---|---|
| `to.Player` | `from.CanBeHarmful(to, false, true)` (normal rules) | `:21-22` |
| map without `MapRules.HarmfulRestrictions` (Felucca rules) | `true` — "felucca you can snoop anybody" | `:24-25` |
| not inside a `GuardedRegion` (or region disabled) | `true` | `:27-30` |
| `to.Body.IsHuman` and (`cret == null \|\| (!AlwaysAttackable && !AlwaysMurderer)`) | `false` — cannot snoop blue human NPCs in town | `:32-35` |
| otherwise | `true` | `:37` |

**Victim detection message** `[SRC]` `Snooping.cs:64-74` — formula `Snooping.Value < Utility.Random(100)` ⇒ detection probability
= `1 - (int)(min(100,Snooping.Value)+1)/100`… precisely: the victim sees it when the roll `r ∈ [0,99]` satisfies `r > value`;
probability = `(99 - (int)value)/100` for `value ≤ 99`, and 0 at `value ≥ 99`. Derived `[SRC]`. Payload:
`root.Send(new AsciiMessage(-1, -1, MessageType.Label, 946, 3, "", "You notice {0} peeking into your belongings!"))` — hue **946**,
font **3**, `from.Name` substituted. The **victim only** is told; there is no bystander broadcast (contrast Stealing 5.4).

**Skill window** `[SRC]` `Snooping.cs:79` `CheckTargetSkill(Snooping, cont, 0.0, 100.0)` ⇒ `chance = Snooping.Value / 100`;
`value >= 100.0` ⇒ auto-success. Derived.

**Delay** `[SRC]`: **none** — there is no `NextSkillTime` write on this path.

**Criminal consequences** `[SRC]`: **none.** No `CriminalAction`, no `Criminal = true`, no guard call anywhere in `Snooping.cs`.
Only the karma loss at `:77`. `[WEB]` "You cannot be Guard Wacked for Snooping nor will you be flagged as a criminal. Snooping
_will_ lower your karma." — [UOGuide — Snooping](https://www.uoguide.com/Snooping) ⇒ `[SRC+WEB]`, karma delta `-4` is `[SRC]`.

### 5.4 STEALING — `ServUO:Scripts/Skills/Stealing.cs`

Callback `:25` (`SkillInfo.Table[33]`). Two global switches: `ClassicMode = false` (`:30`) and `SuspendOnMurder = false` (`:31`) —
**both hard-coded `readonly` in ServUO**, so the `502706` guild-suspension branch (`:75-78`) and the `PermaFlags` notoriety branch
(`Scripts/Misc/Notoriety.cs:431-432`, `PlayerMobile.cs:4411`) are **dead code in ServUO**. `[SRC]`
`IsInGuild(m)` = `m is PlayerMobile && ((PlayerMobile)m).NpcGuild == NpcGuild.ThievesGuild` (`Stealing.cs:33-36`; enum
`ServUO:Scripts/Mobiles/PlayerMobile.cs:101-106`). `IsInnocentTo(from,to)` = `Notoriety.Compute(from,to) == Notoriety.Innocent`
(`Stealing.cs:38-41`).

**Use / target acquisition** `[SRC]`

| Step | Line | Detail |
|---|---|---|
| hands must be empty | `:512-517` | `IsEmptyHanded` = no `Layer.OneHanded` **and** no `Layer.TwoHanded` item (`:497-510`); else `1005584` "Both hands must be free to steal." |
| open target | `:520-523` | `m.Target = new StealingTarget(m); m.RevealingAction(); 502698` "Which item do you want to steal?" |
| returned delay | `:526` | **`10.0 s`** |
| target range | `:48` | `base(1, false, TargetFlags.None)`, `AllowNonlocal = true` (`:52`) ⇒ 1 tile |
| reveal on target | `:396` | `from.RevealingAction()` runs **first**, before any check ⇒ **a successful steal always breaks hiding/stealth** |
| target = Mobile | `:407-417` | picks `pack.Items[Utility.Random(pack.Items.Count)]` — one random item, not a choice |
| target = neither Item nor Mobile | `:426-429` | `502710` "You can't steal that!" |

`[WEB]` "Attempting to steal an item will reveal you if you are Hidden or Invisible." and "will need to wait ten seconds before you
can use another skill" — [UOGuide — Stealing](https://www.uoguide.com/Stealing) ⇒ `[SRC+WEB]`.

**Pre-check rejection chain (`TryStealItem`)** `[SRC]` `Stealing.cs:67-286`

| # | Test | Line | Message |
|---|---|---|---|
| 1 | `!IsEmptyHanded(m_Thief)` | `:67-70` | `1005584` Both hands must be free to steal. |
| 2 | `root is Mobile && ((Mobile)root).Player && !IsInGuild(m_Thief)` | `:71-74` | `1005596` You must be in the thieves guild to steal from other players. |
| 3 | `SuspendOnMurder && root is Mobile && Player && IsInGuild && Kills > 0` | `:75-78` | `502706` (dead: `SuspendOnMurder == false`) |
| 4 | `root is BaseVendor && ((BaseVendor)root).IsInvulnerable` | `:79-82` | `1005598` You can't steal from shopkeepers. |
| 5 | `root is PlayerVendor` | `:83-86` | `502709` You can't steal from vendors. |
| 6 | `!m_Thief.CanSee(toSteal)` | `:87-90` | `500237` Target can not be seen. |
| 7 | `Backpack == null \|\| !Backpack.CheckHold(...)` | `:91-94` | `1048147` Your backpack can't hold anything else. |
| 8 | `toSteal is Sigil` (faction) | `:96-183` | see sigil sub-table |
| 9 | `toSteal is VvVSigil && ViceVsVirtueSystem.Instance != null` | `:186-246` | see sigil sub-table |
| 10 | `si == null && (Parent == null \|\| !Movable) && !ItemFlags.GetStealable(toSteal)` | `:249-252` | `502710` You can't steal that! (non-movable world decoration) |
| 11 | `LootType == LootType.Newbied \|\| CheckBlessed(root)` **and** `!ItemFlags.GetStealable` | `:253-256` | `502710` You can't steal that! |
| 12 | `Core.AOS && si == null && toSteal is Container` **and** `!ItemFlags.GetStealable` | `:257-260` | `502710` You can't steal that! |
| 13 | `!m_Thief.InRange(toSteal.GetWorldLocation(), 1)` | `:261-264` | `502703` You must be standing next to an item to steal it. |
| 14 | `si != null && Stealing.Value < 100.0` | `:265-268` | `1060025` hue `0x66D` You're not skilled enough to attempt the theft of this item. |
| 15 | `toSteal.Parent is Mobile` (worn) | `:269-272` | `1005585` You cannot steal items which are equiped. |
| 16 | `root == m_Thief` | `:273-276` | `502704` You catch yourself red-handed. |
| 17 | `root is Mobile && ((Mobile)root).IsStaff()` | `:277-280` | `502710` You can't steal that! |
| 18 | `root is Mobile && !m_Thief.CanBeHarmful((Mobile)root)` | `:281-282` | **empty block — nothing is sent, nothing happens** |
| 19 | `root is Corpse` | `:283-286` | `502710` You can't steal that! |
| 20 | `w > 10` | `:291-294` | `m_Thief.SendMessage("That is too heavy to steal.")` — **an ASCII string, not a cliloc** |

**Blessed / Insured / Newbied / Cursed** `[SRC]` `ServUO:Server/Item.cs:6116-6134`:
`CheckBlessed(m)` returns true when `m_LootType == LootType.Blessed` **or** (`Mobile.InsuranceEnabled && Insured`) **or** (`m != null && m == BlessedFor`).
`CheckNewbied()` = `LootType == LootType.Newbied`. `LootType` enum: `Regular = 0, Newbied = 1, Blessed = 2, Cursed = 3`
(`ServUO:Server/Item.cs:536-557`, with the doc comments "Unstealable. Unlootable, unless owned by a murderer" / "Unstealable. Unlootable, always" / "Stealable. Lootable, always").
⇒ **Cursed items are stealable**; insured items are unstealable **only while `Mobile.InsuranceEnabled`**; `BlessedFor` protects the item only from *that* mobile (stealing by a third party from a blessed-for owner's pack passes `CheckBlessed(root)` where `root` is the owner ⇒ still blocked; from a *different* holder it is not). Derived `[SRC]`.

**The FULL weight formula** `[SRC]` `Stealing.cs:287-347`

```
w  = toSteal.Weight + toSteal.TotalWeight                                  // Stealing.cs:289
if (w > 10) -> "That is too heavy to steal."                               // Stealing.cs:291-294   HARD CAP = 10 stones
```

`Weight` = per-item weight (`ServUO:Server/Item.cs:3816-3828`, default from tiledata `:3795-3813`);
`TotalWeight` = `GetTotal(TotalType.Weight)` (`Item.cs:3793`) which for a `Container` is the accumulated contents weight
(`ServUO:Server/Items/Container.cs:1688-1702`, accumulated at `:1756`) ⇒ **a container's `w` includes everything inside it.** `[SRC]`

| Branch | Line | Arithmetic |
|---|---|---|
| `Stackable && Amount > 1` | `:297-336` | `maxAmount = (int)((Stealing.Value / 10.0) / toSteal.Weight)`, clamped: `<1 → 1`, `>Amount → Amount` (`:299-308`) |
| ↳ `amount = Utility.RandomMinMax(1, maxAmount)` | `:310` | inclusive `[1, maxAmount]` (`Utility.cs:889-903`) |
| ↳ if `amount >= toSteal.Amount` (whole pile) | `:312-321` | `pileWeight = (int)Math.Ceiling(toSteal.Weight * toSteal.Amount) * 10`; `CheckTargetSkill(Stealing, toSteal, pileWeight - 22.5, pileWeight + 27.5)`; `stolen = toSteal` |
| ↳ else (partial pile) | `:323-336` | `pileWeight = (int)Math.Ceiling(toSteal.Weight * amount) * 10`; same window; `stolen = Mobile.LiftItemDupe(toSteal, toSteal.Amount - amount)` (`:329`), falling back to `toSteal` if `null` (`:331-334`) |
| non-stackable | `:340-346` | `iw = (int)Math.Ceiling(w) * 10`; `CheckTargetSkill(Stealing, toSteal, iw - 22.5, iw + 27.5)`; `stolen = toSteal` |

⇒ **Unified window (derived `[SRC]`):**
`chance = (Stealing.Value - (10*W - 22.5)) / 50`, where `W = ceil(weight-of-the-pile-actually-grabbed)`.
`Stealing.Value < 10*W - 22.5` ⇒ automatic failure; `Stealing.Value >= 10*W + 27.5` ⇒ automatic success.

**Max-stealable-weight-by-skill rules** (derived `[SRC]` from the two literals above):

| Rule | Formula | Consequence |
|---|---|---|
| absolute cap | `w ≤ 10` (`:291`) | nothing heavier than 10 stones is ever stealable, at any skill |
| stack amount cap | `maxAmount = (int)((Stealing.Value/10) / Weight)` (`:299`) | the *pile* you can grab weighs at most `Stealing.Value/10` stones |
| zero-chance floor | `Stealing.Value ≥ 10*W - 22.5` | a 10-stone item needs 77.5 Stealing just to have a chance |
| guaranteed-success ceiling | `Stealing.Value ≥ 10*W + 27.5` | 7-stone items are 100 % at 97.5 Stealing; 10-stone items are never 100 % (would need 127.5) |

| Item weight `w` | `iw` | window | chance @ Stealing 100 | success prob (ServUO roll) |
|---|---|---|---|---|
| 1 | 10 | `-12.5 .. 37.5` | auto (`100 ≥ 37.5`) | 100 % |
| 3 | 30 | `7.5 .. 57.5` | auto | 100 % |
| 5 | 50 | `27.5 .. 77.5` | auto | 100 % |
| 7 | 70 | `47.5 .. 97.5` | auto | 100 % |
| 8 | 80 | `57.5 .. 107.5` | `(100-57.5)/50 = 0.85` | 86 % (`Random(100) <= 85`) |
| 9 | 90 | `67.5 .. 117.5` | `0.65` | 66 % |
| 10 | 100 | `77.5 .. 127.5` | `0.45` | 46 % |
| > 10 | — | — | blocked at `:291` | 0 % |

`[WEB]` "You may not take items that weigh more then your skill level divided by 10" —
[UOGuide — Stealing](https://www.uoguide.com/Stealing) ⇒ `[SRC+WEB]` for the `Stealing/10` pile-weight rule; the 10-stone hard cap
is `[SRC]` only. UOGuide's training table ("30-40 → 3 stones … 100-110 → 10 stones") is consistent with that rule ⇒ `[WEB]`.

**Worked gold example** `[SRC]`-derived. `Gold.DefaultWeight = Core.ML ? (0.02/3) : 0.02` (`ServUO:Scripts/Items/Consumables/Gold.cs:34-40`),
`Gold` is `Stackable = true` (`:25`). At `Stealing = 100.0`:
pre-ML `maxAmount = (int)((100/10.0)/0.02) = 500` coins; ML `maxAmount = (int)(10/0.0066667) = 1500` coins.
Both then clamped by `toSteal.Amount`; `amount = RandomMinMax(1, maxAmount)`; `pileWeight = ceil(0.02*amount)*10`
(e.g. `amount = 500` → `ceil(10.0)*10 = 100` → window `77.5 .. 127.5` → 45 % at GM).

**Caught / witness roll** `[SRC]` `Stealing.cs:349-366` — only runs when `stolen != null && (root is FillableContainer || stolen.Movable)`;
otherwise `caught = false` ("Non-movable stealable (not in fillable container) items cannot result in the stealer getting caught", `:349`).

| Source container | Line | Formula | Probability |
|---|---|---|---|
| `root is FillableContainer` | `:354-356` | `caught = (Utility.Random((int)(skillValue / 2.5)) == 0)` | `1/(int)(Stealing/2.5)` = **1 in 48 at Stealing 120** (comment at `:356`); **always true when `Stealing < 2.5`** because `Random(0) = 0` (`Utility.cs:921-924`) |
| anything else | `:358-361` | `caught = (skillValue < Utility.Random(150))` | `(149 - (int)Stealing)/150`; ≈ **32.7 % at Stealing 100** (rolls 101..149 of 0..149), **0 % at Stealing ≥ 149**, **99.3 % at Stealing 0** |
| non-movable world item | `:363-366` | `caught = false` | 0 % |

**Success / failure messages** `[SRC]`

| Clue | Text | Line |
|---|---|---|
| `502724` | You succesfully steal the item. *(sic)* | `Stealing.cs:370` |
| `502723` | You fail to steal the item. | `Stealing.cs:386` |
| ASCII | `You notice {thief} trying to steal from {victim}.` sent to every client within **8** tiles except the thief | `Stealing.cs:470-478` |

On success `[SRC]` `:372-382`: `ItemFlags.SetTaken(stolen, true)`, `ItemFlags.SetStealable(stolen, false)`, `stolen.Movable = true`,
`InvokeItemStoken(...)` event, and for stealable-artifact instances `toSteal.Movable = true; si.Item = null;`.
Flags live in the XmlSpawner core: `StealableFlag = 0x00200000`, `TakenFlag = 0x00100000`
(`ServUO:Scripts/Services/XmlSpawner/XmlSpawner Core/ItemFlags.cs:12-13`, accessors `:21-49`) — `[SRC]` **the stealing handler has a
hard compile-time dependency on the XmlSpawner service**; a clone must either implement those two saved flags or drop the checks.
On target, `:431-449`: `AddonComponent` → `addon.Deed` to backpack + `addon.Delete()`; else `from.AddToBackpack(stolen)`;
`StolenItem.Add(stolen, thief, root as Mobile)` only for non-`Container`, non-`Stackable` items (`:444-448`).

**Delay** `[SRC]`: `10.0 s` (`Stealing.cs:526`).

**Player vs NPC** `[SRC]`: players require the Thieves Guild (`:71-74`, `1005596`); all roots additionally pass through
`CanBeHarmful` (`:281`) and the town rules below. **There is no Felucca-facet requirement in the source** — UOGuide states
"make all attempts within the Felucca facet" ([UOGuide — Stealing](https://www.uoguide.com/Stealing)); `[SRC]` vs `[WEB]`
divergence: **ServUO does not enforce a facet**; the only facet-sensitive input is `MapRules.HarmfulRestrictions` through
`CanBeHarmful` / `CheckSnoopAllowed`.

**Town / guard-zone rules** `[SRC]`

| Rule | Line |
|---|---|
| invulnerable shopkeepers cannot be stolen from (`1005598`) | `Stealing.cs:79-82` |
| `PlayerVendor` cannot be stolen from (`502709`) | `Stealing.cs:83-86` |
| equipped items cannot be stolen (`1005585`) | `Stealing.cs:269-272` |
| corpses: `502710` when the corpse root is targeted directly; but a **caught** steal whose `root is Corpse && IsCriminalAction(thief)` sets the criminal flag | `:283-286`, `:457-460` |
| any `CriminalAction` inside a guarded region calls `CheckGuardCandidate` ⇒ guards | `GuardedRegion.cs:225-233` |

**`StolenItem` bookkeeping** `[SRC]` `Stealing.cs:538-633`: `StealTime = TimeSpan.FromMinutes(2.0)` (`:540`); queue-based
(`:563-570`); `IsStolen(item, ref victim)` (`:579-593`); `ReturnOnDeath(killed, corpse)` returns the item to the victim on death
within the window with `1010464` "the item that was stolen is returned to you." or `1010463` "…falls to the ground." (`:595-615`).

**Faction / VvV sigil sub-rules** `[SRC]` `Stealing.cs:96-246`

| Requirement | Line | Message |
|---|---|---|
| adjacent (1 tile) | `:103-106` | `502703` |
| must be on the ground (`root == null`) | `:107-110` | `502710` |
| must be in a faction | `:111-182` | `1005588` You must join a faction to do that |
| not incognito / not disguised / not polymorphed / no transformation / not animal form | `:113-132` | `1010581`, `1010583`, `1010582`, `1061622`, `1063222` |
| not leaving the faction / not your own sigil / not purifying | `:133-144` | `1005589`, `1005590`, `1005592` |
| **skill check** | `:145` | `CheckTargetSkill(Stealing, toSteal, 80.0, 80.0)` ⇒ `Stealing.Value < 80` ⇒ `1005594`; `>= 80` ⇒ auto |
| already carrying a sigil / pack full | `:147-155` | `1010258`, `1010259` |
| success | `:156-172` | `1010586` YOU STOLE THE SIGIL!!! |
| VvV sigil (participants only) | `:186-246` | `CheckTargetSkill(Stealing, toSteal, 100.0, 120.0)` (`:222`); non-participant `1155415` |

### 5.5 FLAGGING — the criminal path, guards, colour, reveal interactions

**Exact code path that sets `Criminal`** `[SRC]`

```
Stealing.OnTarget            Stealing.cs:455/459/467/483   m_Thief.CriminalAction(false);
  Mobile.CriminalAction      Mobile.cs:3571-3581           Criminal = true; Region.OnCriminalAction(this, message);
    Mobile.Criminal setter   Mobile.cs:11814-11846         Delta(MobileDelta.Noto); InvalidateProperties(); (re)start ExpireCriminalTimer
      ExpireCriminalTimer    Mobile.cs:2106-2121           OnTick -> m_Mobile.Criminal = false;
    Region.OnCriminalAction  Region.cs:904-914             bubbles to parent; if (message) 1005040 "You've committed a criminal act!!"
      GuardedRegion override GuardedRegion.cs:225-233      if (!IsDisabled()) CheckGuardCandidate(m);
```

Every steal call passes `message: false` (`Stealing.cs:455,459,467,483`) ⇒ **the thief is never shown `1005040` by the steal path.**
The only player-visible feedback is the radius-8 ASCII line to *others* (`:470-478`). `[SRC]`

**Flag duration constant** `[SRC]`: `private static TimeSpan m_ExpireCriminalDelay = TimeSpan.FromMinutes(2.0);`
(`ServUO:Server/Mobile.cs:2102`), exposed as `Mobile.ExpireCriminalDelay` (`:2104`), applied by `ExpireCriminalTimer`
(`:2106-2121`, `Priority = TimerPriority.FiveSeconds`). Each new `Criminal = true` **restarts** the timer (`:11827-11839`).

**Notoriety colour and value** `[SRC]`: `Notoriety.Criminal = 4` (`ServUO:Server/Notoriety.cs:10`);
hue table `m_Hues = {0x000, 0x059, 0x03F, 0x3B2, 0x3B2, 0x090, 0x022, 0x035}` indexed by notoriety value
(`ServUO:Server/Notoriety.cs:17`, accessor `:21-29`), re-asserted in `NotorietyHandlers.Initialize()`:
`Notoriety.Hues[Notoriety.Criminal] = 0x3B2` (`ServUO:Scripts/Misc/Notoriety.cs:28`).
`MobileNotoriety` returns `Notoriety.Criminal` for `target.Criminal` (`ServUO:Scripts/Misc/Notoriety.cs:401-402`).
`Notoriety.Compute` falls back to `CanBeAttacked` (3) when no handler is installed (`ServUO:Server/Notoriety.cs:31-34`).

**PermaFlags** `[SRC]` `Stealing.cs:486-493`: when the root is a **player**, the thief is a `PlayerMobile`, `IsInnocentTo(thief, root)`
and `!IsInGuild(root)` → `pm.PermaFlags.Add(root); pm.Delta(MobileDelta.Noto);`. Property: `PlayerMobile.PermaFlags`
(`ServUO:Scripts/Mobiles/PlayerMobile.cs:4393`, list field `:4044`, cleared on death handling `:3949-3951`). Its **only** consumers
are gated on `Stealing.ClassicMode`, which is `false` in ServUO ⇒ no notoriety effect in a stock ServUO build
(`ServUO:Scripts/Misc/Notoriety.cs:431-432`, `ServUO:Scripts/Mobiles/PlayerMobile.cs:4411`). `[SRC]`

**Guard response** `[SRC]`

| Step | Line | Detail |
|---|---|---|
| `CheckGuardCandidate(m)` | `GuardedRegion.cs:235-313` | runs only if `!IsDisabled()` |
| `IsGuardCandidate(m)` | `GuardedRegion.cs:354-363` | false for `BaseGuard`, `GuardImmune`, dead, staff, `Blessed`, invulnerable creature, disabled region; true for `(!AllowReds && Murderer) \|\| Criminal \|\| aggressive monster` |
| `AllowReds` | `GuardedRegion.cs:63` | `Core.AOS` ⇒ **pre-AoS reds are guard candidates on sight** |
| timer | `GuardedRegion.cs:446-468` | `GuardTimer : base(TimeSpan.FromSeconds(15.0))`, `TimerPriority.TwoFiftyMS` |
| on flag | `GuardedRegion.cs:269` | `m.SendLocalizedMessage(502275); // Guards can now be called on you!` |
| fake guard call | `GuardedRegion.cs:271-305` | nearest non-candidate human within **8** tiles says one of `1007037, 501603, 1013037, 1013038, 1013039, 1013041, 1013042, 1013043, 1013052` then `MakeGuard(m)` + `502276` |
| timer expiry | `GuardedRegion.cs:465` | `502276; // Guards can no longer be called on you.` |
| speech trigger | `GuardedRegion.cs:192-195` | `*guards*` keyword (`0x0007`) and `Alive` → `CallGuards(m.Location)` |
| `CallGuards` | `GuardedRegion.cs:315-352` | scans **14** tiles; acts if the candidate already has a timer or (`!AllowReds && Murderer`); aggressive monsters get guards too |
| `MakeGuard(focus)` | `GuardedRegion.cs:124-160` | reuse an idle `BaseGuard` within **8** tiles, else `Activator.CreateInstance(m_GuardType, …)` |
| guard type | `GuardedRegion.cs:65-78` | `ArcherGuard` on Ilshenar/Malas, else `WarriorGuard` |
| aggression path | `GuardedRegion.cs:198-206` | `OnAggressed(..., criminal: true)` within **12** tiles also calls `CheckGuardCandidate`; auto-calls guards when the aggressor is an aggressive monster |
| beneficial path | `GuardedRegion.cs:208-223` | helping a `Criminal`/`Murderer` notoriety target flags the helper |

**Aggression bookkeeping used by DetectHidden** `[SRC]`: `Mobile.AggressiveAction(aggressor, criminal)` sets
`info.CriminalAggression = criminal; info.CanReportMurder = criminal;` (`ServUO:Server/Mobile.cs:2300-2337`);
`CheckAggressed` ignores `CriminalAggression` entries (`ServUO:Scripts/Misc/Notoriety.cs:536-545`);
`DoHarmful` computes `IsHarmfulCriminal` (default: `Notoriety.Compute(this,target) == Notoriety.Innocent`, `Mobile.cs:8003-8011`),
calls `OnHarmfulAction` → `CriminalAction(false)` (`:8016-8022`) and `AggressiveAction(this, isCriminal)` (`:8036-8041`).

**Detect Hidden — active search** `[SRC]` `DetectHidden.cs`

| Element | Value | Line |
|---|---|---|
| callback / skill id | `SkillInfo.Table[14]` | `:32` |
| prompt + cooldown | `500819` "Where will you search?" ; `TimeSpan.FromSeconds(10.0)` | `:37-40` |
| target | `base(12, true, TargetFlags.None)` (12 tiles) | `:46` |
| range | `Math.Max(2, (int)(srcSkill / 10.0))` where `srcSkill = DetectHidden.Value` | `:64-65` |
| failed check halves it | `if (!src.CheckSkill(DetectHidden, 0.0, 100.0)) range /= 2;` | `:67-68` |
| house bonus | `house.IsFriend(src)` ⇒ `range = 22` | `:70-75` |
| detection roll | `ss = srcSkill + Utility.Random(21) - 10; ts = trg.Skills[Hiding].Value + Utility.Random(21) - 10;` | `:85-86` |
| skill-mastery shadow | `double shadow = SkillMasteries.ShadowSpell.GetDifficultyFactor(trg);` used as `Utility.RandomDouble() > shadow` | `:87-90` |
| success condition | `src.AccessLevel >= trg.AccessLevel && (ss >= ts \|\| houseCheck) && RandomDouble() > shadow`, then `!(ShadowKnight off-tile) && (houseCheck \|\| CanDetect(src,trg))` | `:90-94` |
| messages | `500814` "You have been revealed!" to the target (both `SendLocalizedMessage` and `PrivateOverheadMessage(MessageType.Regular, 0x3B2, 500814, …)`) | `:97-98` |
| nothing found | `500817` "You can see nothing hidden there." | `:135` |
| item revealables | `IRevealableItem.CheckReveal/CheckPassiveDetect/OnRevealed/CheckWhenHidden` (`Server.Items` interface `:16-23`) | `:116-127` |

**Detect Hidden — passive** `[SRC]` `DetectHidden.cs:140-185`, driven from `PlayerMobile` every movement tick capped to once per
**2 s** (`ServUO:Scripts/Mobiles/PlayerMobile.cs:2095-2099`):

| Element | Value | Line |
|---|---|---|
| guards | `src == null \|\| Map == null \|\| Location == Point3D.Zero \|\| IsStaff()` | `:142-143` |
| zero-skill guard | `ss = DetectHidden.Value; if (ss <= 0) return;` | `:145-148` |
| radius / mobile filter | `GetMobilesInRange(src.Location, 4)`; skips `null`, self, `ShadowKnight`, `!CanDetect` — **does not test `m.Hidden`** | `:150-158` |
| target skill | `ts = (Hiding.Value + Stealth.Value) / 2` | `:160` |
| elf bonus | `if (src.Race == Race.Elf) ss += 20;` — accumulated **inside** the loop, so it compounds per candidate (quirk) | `:162-163` |
| roll | `Utility.Random(1000) < (ss - ts) + 1` ⇒ probability `clamp((ss-ts+1)/1000, 0, 1)` | `:165` |
| reveal | `m.RevealingAction(); m.SendLocalizedMessage(500814);` | `:167-168` |
| hidden items | `GetItemsInRange(src.Location, 8)` → `1153493` "Your keen senses detect something hidden in the area..." | `:174-181` |

**`CanDetect(src, target)`** `[SRC]` `DetectHidden.cs:187-209`: false if either map is null, `!src.CanBeHarmful(target, false)`,
`src.Blessed` / invulnerable creature, `target.Blessed` / invulnerable creature, `!SpellHelper.ValidIndirectTarget(target, src)`
(pet owner, guild/alliance, party); true if `src.Aggressed.Any(x => x.Defender == target) || src.Aggressors.Any(x => x.Attacker == target)`;
otherwise `src.Map.Rules == MapRules.FeluccaRules` ⇒ **passive/active detection of unrelated blues only on Felucca rules.**

**Forensic Evaluation — full gate table** `[SRC]` `ForensicEval.cs` (callback `:19`, `501000` "Show me the crime." `:27`,
`RevealingAction()` `:25`, delay `1.0 s` `:29`, target `base(10, false, TargetFlags.None)` `:35`)

| Target | Pre-gate (skill `<`) | Line | Check window | Lines | Success messages | Fail |
|---|---|---|---|---|---|---|
| `Corpse` | `30.0` → `501003` "You notice nothing unusual." | `:42,46-50` | `CheckTargetSkill(Forensics, target, 30.0, 55.0)` | `:52` | `1042750` already-forensicist `~1_NAME~`, `1042751` killed by `~1_KILLER_NAME~`, `1042752` disturbed by `~1_PLAYER_NAMES~`, else `501002` "The corpse has not be desecrated." | `501001` "You cannot determain anything useful." (`:85`) |
| `Mobile` | `36.0` → `501003` | `:90-93` | `CheckTargetSkill(Forensics, target, 36.0, 100.0)` | `:94` | `501004` "That individual is a thief!" when `target is PlayerMobile && NpcGuild == NpcGuild.ThievesGuild`, else `501003` | `501001` (`:107`) |
| `ILockpickable` | `41.0` → `501003` | `:112-115` | `CheckTargetSkill(Forensics, target, 41.0, 100.0)` | `:116` | `1042749` "This lock was opened by ~1_PICKER_NAME~" when `p.Picker != null`, else `501003` | `501001` (`:131`) |
| `Item` (only `Core.SA`) | `41.0` → `501001` | `:134-146` | `41.0 .. 100.0` for `HonestyItemSocket` | `:155` | `1151521` if `Forensics.Value >= 61.0`, else `1151522` | — |
| `IForensicTarget` | — | `:138-141` | delegated | — | — | — |

Corpse support fields: `m_Forensicist` (`ServUO:Scripts/Items/Corpses/Corpse.cs:116`), `m_Killer` (`:84`), `m_Looters` (`:87`,
appended on loot `:1077-1079,1102-1104`), `Looters/Killer` accessors (`:379-382`), `IsCriminalAction` (`:1002-1025`) which returns
`NotorietyHandlers.CorpseNotoriety(from, this) == Notoriety.Innocent` and respects `CorpseFlag.LootCriminal` (`:1009-1010`).
**Forensics never sets the criminal flag on the user** — the only flag interaction is the reveal at `:25` and the `101000` prompt. `[SRC]`

**Tracking — thief-relevant constants** `[SRC]` `Tracking.cs`

| Element | Value | Line |
|---|---|---|
| callback / prompt / delay | `SkillInfo.Table[38]`; `1011350` "What do you wish to track?"; `10.0 s` | `:17,22,28` |
| entry check (gump ctor) | `from.CheckSkill(Tracking, 0.0, 21.1)` | `:87` |
| no evidence | `1018092` "You see no evidence of those in the area." | `:178` |
| passive gain | `from.CheckSkill(Tracking, 21.1, 100.0)` | `:189` |
| search range | `10 + (int)(from.Skills[Tracking].Value / 10)` ⇒ 10–20 tiles | `:191` |
| candidate filter | `m != from && (!Core.AOS \|\| m.Alive) && (!m.Hidden \|\| m.IsPlayer() \|\| from.AccessLevel > m.AccessLevel) && type && CheckDifficulty` | `:199` |
| empty-category messages | `502991` animals / `502993` creatures / `502995` people | `:214-218` |
| arrow radius | `m_Range * 2` | `:230` |
| stalking info only from SE | `if (Core.SE) Tracking.AddInfo(...)` | `:232-233` |
| player-vs-player difficulty | `tracking = Tracking.Fixed`, `detectHidden = DetectHidden.Fixed`; elf (ML) `tracking /= 2`; `divisor = Hiding.Fixed + Stealth.Fixed`; HorrificBeast `divisor -= 200`; VampiricEmbrace `divisor = max(divisor,500)`; WraithForm `divisor += 200` if `<= 2000`; SE `chance = 50 * (tracking*2 + detectHidden) / divisor`, else `chance = 50 * (tracking + detectHidden + 10*RandomMinMax(1,20)) / divisor`; `divisor <= 0 ⇒ 100`; success `chance > Utility.Random(100)` | `:238-273` |
| arrow refresh | `TrackTimer : base(TimeSpan.FromSeconds(0.25), TimeSpan.FromSeconds(2.5))` | `:362` |
| lost quarry | `503177` "You have lost your quarry." | `:349` |
| stalking bonus | `sqrt(dx²+dy²)`, table entry removed on use ("Reset as of Pub 40, counting it as bug for Core.SE"); ML caps at `Math.Min(bonus, 10 + Tracking.Value/10)` | `:37-56` |

**Remove Trap — thief-relevant constants** `[SRC]` `RemoveTrap.cs`

| Element | Value | Line |
|---|---|---|
| callback | `SkillInfo.Table[48]` | `:24` |
| prereqs (skipped under `Core.EJ`) | `Lockpicking.Value < 50` → `502366`; `DetectHidden.Value < 50` → `502367` | `:29-36` |
| prompt / delay / range | `502368` "Wich trap will you attempt to disarm?"; `10.0 s`; `base(2, false, TargetFlags.None)` | `:41,44,50` |
| container window | `CheckTargetSkill(RemoveTrap, targ, targ.TrapPower, targ.TrapPower + 10)` | `:111` |
| success / fail | `502377` "You successfully render the trap harmless"; `502372` "You fail to disarm the trap... but you don't set it off"; success zeroes `TrapPower`, `TrapLevel`, `TrapType` | `:113-121` |
| other targets | `Mobile` → `502816`; locked → `501283`; untrapped → `502373` | `:58,66,76` |
| faction trap | `RemoveTrap 80..100 && Tinkering 80..100` (or `Core.ML && isOwner`); messages `1010538`/`1010537`/`1042530`/`1008113` | `:134-158` |
| VvV trap | `(RemoveTrap.Value - 80.0) / 20.0 > Utility.RandomDouble()`; else `0.1 > Utility.RandomDouble()` detonates | `:181,203` |
| treasure chest (new system) | 10 s repeating timer (`:314`); GM remover (`RemoveTrap >= 100`, `:263`) uses a per-level safety window (`Stash 20 s, Supply 60 s, Cache 180 s, Hoard 420 s, Trove 540 s`, `:324-332`) then `CheckTargetSkill(RemoveTrap, Chest, 80, 120 + Chest.Level*10)` (`:366`), else guardian; sub-100 uses `min = ceil(RemoveTrap.Value * 0.75)`, `max = min > 50 ? min + 50 : 100` (`:382-384`); range check **16** tiles (`:351`) | `:256-409` |

### 5.6 ModernUO cross-check (diffs only; identical constants listed as "same")

| Constant / behaviour | ServUO (pub57) | ModernUO (main) | Diff |
|---|---|---|---|
| Hiding busy message/delay | `501238`, `1.0 s` `Hiding.cs:30-31` | same `Hiding.cs:21-22` | **same** |
| Hiding VvV ManaSpike gate | present `Hiding.cs:34-37` | **absent** `Hiding.cs:17-28` | ModernUO removed |
| Hiding house-friend bonus | `100.0` `Hiding.cs:50` | `100.0` `Hiding.cs:36` | **same** |
| Hiding adjacent-house bonus | `50.0` `Hiding.cs:67` | `50.0` `Hiding.cs:47` | **same** |
| Hiding range | `Math.Min((int)((100-skill)/2)+8, 18)` `Hiding.cs:72` | same literal `Hiding.cs:53` | **same** |
| Hiding watched test | `((Mobile)m.Combatant).InLOS(m.Combatant)` `Hiding.cs:74` | `m.Combatant.InLOS(m)` `Hiding.cs:55-56` | **different LOS subject** |
| Hiding unwatched sweep | `foreach (GetMobilesInRange(range))` + `check.InLOS(m) && check.Combatant == m` → `badCombat = true; break;` `Hiding.cs:81-94` | identical `Hiding.cs:63-70` | **same** |
| Hiding `badCombat` cooldown | `TimeSpan.Zero` `Hiding.cs:105` | `TimeSpan.FromSeconds(1.0)` `Hiding.cs:82` | **different** |
| Hiding success extras | removes `Sixth.InvisibilitySpell` + `InvisibilityPotion` timers `Hiding.cs:114-115` | only `InvisibilitySpell.StopTimer(m)` `Hiding.cs:90` | **different** |
| Stealth `HidingRequirement` | `ML 30.0 / SE 50.0 / else 80.0` `Stealth.cs:28` | same `Stealth.cs:11-12` | **same** |
| Stealth armor table rows | 11 (no Wood/Stone) `Stealth.cs:12-22` | 13 rows incl. Wood/Stone `Stealth.cs:18-30` | **different table** |
| `Dragon` row (Gorget) | `{ 0, 5, 10, 10, 15, 25, 0 }` `Stealth.cs:22` | `{ 5, 5, 10, 10, 15, 25, 0 }` `Stealth.cs:28` | **0 vs 5** |
| `Wood` / `Stone` rows | absent (skipped by length guard) | `{ 5, 5, 10, 10, 15, 25, 0 }` `Stealth.cs:29-30` | ModernUO blocks wood/stone armour |
| Stealth MageArmor predicate | `armor.ArmorAttributes.MageArmor == 0` `Stealth.cs:63` | same `Stealth.cs:62` | **same** |
| Stealth flying gate | `1113415` + reveal `Stealth.cs:76-81` | **absent** `Stealth.cs:71-95` | ModernUO removed |
| Stealth armor cap | `Core.AOS ? 42 : 26` `Stealth.cs:98` | same `Stealth.cs:91` | **same** |
| Stealth check window | `-20.0 + AR*2 .. (AOS?60:80) + AR*2` `Stealth.cs:104` | same `Stealth.cs:96-100` | **same** |
| Stealth steps | `(int)(Stealth.Value / (AOS?5.0:10.0))`, min 1 `Stealth.cs:106-109` | `Math.Max((int)(Stealth.Value / (AOS?5.0:10.0)), 1)` `Stealth.cs:102` | **equivalent** |
| `IsStealthing` home | `Mobile` `Server/Mobile.cs:3059` | `PlayerMobile` `Projects/UOContent/Mobiles/PlayerMobile.cs:409` | **moved** |
| Stealth buff icon | `BuffInfo(HidingAndOrStealth, 1044107, 1075655)` `Stealth.cs:117` | **absent** | ModernUO removed |
| Snooping range / far message | `InRange(...,1)` / `500446` `Snooping.cs:42,96` | `InRange(...,1)` + `AccessLevel <= Player` / `500446` `Snooping.cs:41-44` | **equivalent** |
| Snooping NPC-pack block | `root is BaseCreature && !(cont is StrongBackpack)` `Snooping.cs:49-50` | **absent** | ModernUO allows snooping any NPC pack |
| Snooping staff-container message | `500209` `Snooping.cs:54` | folded into `1001018` `Snooping.cs:54-57` | **different id** |
| Snooping victim notify | victim only, ASCII hue `946` `Snooping.cs:70-72` | **radius-8 broadcast**, `"You notice {from} attempting to peek into {root}'s belongings."` `Snooping.cs:69-78` | **different audience + text** |
| Snooping victim-notify gate | `Snooping.Value < Utility.Random(100)` `Snooping.cs:64` | `snooping < 100.0 && snooping < Utility.RandomDouble()*100` `Snooping.cs:63` | **different (adds a <100 gate)** |
| Snooping karma | `-4` `Snooping.cs:77` | `-4` `Snooping.cs:81` | **same** |
| Snooping window / fail reveal | `0.0..100.0`; `Hiding.Value/2 < Random(100)` `Snooping.cs:79,90` | `0.0..100.0`; `Hiding.Value/2 < RandomDouble()*100` `Snooping.cs:84,97` | **same logic, different RNG** |
| Stealing use delay | `10.0 s` `Stealing.cs:526` | `30.0 s` `Stealing.cs:69`, then re-derived to a 10 s skill cooldown minus targeter elapsed time (`:424-430`) | **different** |
| `ClassicMode` / `SuspendOnMurder` | `readonly false` / `readonly false` `Stealing.cs:30-31` | config-driven, default `!Core.AOS` `Stealing.cs:30-31` | **different** |
| Container stealing | always blocked under AoS unless `ItemFlags.GetStealable` `Stealing.cs:257-260` | `CanStealContainers` config, default `!Core.AOS` `Stealing.cs:32,223` | **different** |
| Weight cap | `w > 10` → ASCII `SendMessage("That is too heavy to steal.")` `Stealing.cs:291-293` | `w > MaxWeightToSteal` (config default `10`) → cliloc `502722` `Stealing.cs:33,263-267` | **same number, different text** |
| `maxAmount` | `(int)((Stealing.Value/10.0)/Weight)` clamped by two `if`s `Stealing.cs:299-308` | `Math.Clamp((int)(Stealing.Value/10.0/Weight), 1, Amount)` `Stealing.cs:272-276` | **equivalent** |
| Stack window | `pileWeight = ceil(Weight*amount)*10`; `-22.5 .. +27.5` `Stealing.cs:314-327` | identical `Stealing.cs:282-305` | **same** |
| Non-stack window | `iw = ceil(w)*10`; `-22.5 .. +27.5` `Stealing.cs:340-343` | identical `Stealing.cs:313-316` | **same** |
| Stealable-artifact gate | `si != null && Stealing.Value < 100.0` → `1060025` `Stealing.cs:265-268` | same `Stealing.cs:231-235` | **same** |
| Flag bookkeeping on success | `ItemFlags.SetTaken/SetStealable`, `stolen.Movable = true` `Stealing.cs:372-374` | **absent** (only `si.Item = null`) `Stealing.cs:322-331` | **different (XmlSpawner decoupled)** |
| `AddonComponent` handling | converts to `addon.Deed` `Stealing.cs:433-438` | **absent** | ModernUO removed |
| **Caught chance** | FillableContainer `Random((int)(Stealing/2.5)) == 0`; else `Stealing < Random(150)` `Stealing.cs:354-361` | **always** `Stealing < Random(150)` `Stealing.cs:337` | **ModernUO dropped the 1/48 branch** |
| Caught-message audience | radius **8** colleagues, `"You notice {0} trying to steal from {1}."` `Stealing.cs:470-478` | same `Stealing.cs:401-409` | **same** |
| Karma on steal | **none** | `Titles.AwardKarma(from, -50, true)` executed **unconditionally** `Stealing.cs:372` | **different** |
| Young-player restrictions | none | `502700` (thief Young), `502699` (victim Young) `Stealing.cs:107-122` | ModernUO only |
| Safe-zone block | none | `Region.IsPartOf<SafeZone>()` → `"You may not steal in this area."` `Stealing.cs:57-60,103-106` | ModernUO only |
| Locked-container check | none | `IsInLockedContainer` → `501747` `Stealing.cs:48-49,255-258` | ModernUO only |
| `StolenItem.StealTime` | `2.0 min` `Stealing.cs:540` | `2.0 min` `Stealing.cs:437` | **same** |
| `ExpireCriminalDelay` | `TimeSpan.FromMinutes(2.0)` `Server/Mobile.cs:2102` | `TimeSpan.FromMinutes(2.0)` `Projects/Server/Mobiles/Mobile.cs:1813` | **same** |
| `Hidden` setter side effects | forces `Warmode=false` / `Combatant=null` `Server/Mobile.cs:8963-8973` | **none** — only `OnHiddenChanged()` `Projects/Server/Mobiles/Mobile.cs:1249-1262` | **different** |
| `RevealingAction` | clears `m_IsStealthing` `Server/Mobile.cs:7160` | no such field on `Mobile`; `PlayerMobile.RevealingAction` clears `IsStealthing` `Projects/UOContent/Mobiles/PlayerMobile.cs:1592-1604` | **moved** |
| `OnMove` step decrement | `m_AllowedStealthSteps-- <= 0 \|\| (d & Direction.Running) != 0 \|\| Mounted` `Server/Mobile.cs:3044-3050` | identical `Projects/Server/Mobiles/Mobile.cs:4116-4127` | **same** |
| Player step engine | `if (!Core.SE) return base.OnMove(d);` then `Stealth.Value >= 25.0`, running `-= 2`, walk `Stealth.OnUse(this)` `PlayerMobile.cs:5431-5480` | identical incl. the `!Core.SE` early-out `Projects/UOContent/Mobiles/PlayerMobile.cs:3408-3445` | **same** |
| Passive Detect Hidden | time-sliced 2 s from PlayerMobile, radius 4, `Random(1000) < (ss-ts)+1`, elf `+20` inside loop, **no `Hidden` test** `DetectHidden.cs:140-185`, `PlayerMobile.cs:2095-2099` | new `TryDetectStealther` — **Felucca-only**, `Random(21)-10` variance on both sides, `ss >= ts` ⇒ reveal, party/guild/alliance exclusions, 3 s debounce, **no elf bonus**, triggered from `OnMovement` `Projects/UOContent/Mobiles/PlayerMobile.cs:3447-3464`, `DetectHidden.cs:61-128` | **substantially different** |
| Active Detect Hidden range | `Math.Max(2, (int)(Value/10.0))`, halved on failed check, `22` in a friend's house `DetectHidden.cs:64-75` | `(int)(Value/10.0)` (**no `Math.Max(2,…)`**), halved on failure, `22` in house `DetectHidden.cs:145-186` | **different floor** |
| Active Detect Hidden extras | mobiles + `IRevealableItem`s; `CanDetect` incl. Felucca rule `DetectHidden.cs:187-209` | adds direct container targeting `[trapped]` `500813`, faction traps (`80..100`), `BaseTrap` reveal gated on `Core.HS && skill >= 75.0`, 10 s re-hide timer, no `CanDetect` `DetectHidden.cs:147-253` | **different** |
| Detect Hidden cooldowns | `10.0 s` (`DetectHidden.cs:40`) | `30.0 s` on use, then 10 s after target `DetectHidden.cs:35,262-265` | **different** |
| Forensics: corpse | pre-gate `30.0`; `CheckTargetSkill(30.0, 55.0)` `ForensicEval.cs:42-52` | **no pre-gate**; `CheckTargetSkill(0.0, 100.0)` `ForensicEval.cs:54` | **different** |
| Forensics: mobile | pre-gate `36.0`; `CheckTargetSkill(36.0, 100.0)` `ForensicEval.cs:90-94` | **no pre-gate**; `CheckTargetSkill(40.0, 100.0)` `ForensicEval.cs:36` | **different** |
| Forensics: lock | pre-gate `41.0`; `CheckTargetSkill(41.0, 100.0)` `ForensicEval.cs:112-116` | **no skill check at all** `ForensicEval.cs:107-117` | **different** |
| Tracking range | `10 + (int)(Tracking.Value / 10)` ⇒ 10–20 `Tracking.cs:191` | `10 + (int)Tracking.Value / 10 * 10` ⇒ 10–110 tiles `Tracking/Tracking.cs:166` | **different by 10×** |
| Tracking difficulty | `chance > Utility.Random(100)` `Tracking.cs:272` | `chance >= 100 \|\| chance > Utility.Random(100)` `Tracking/Tracking.cs:354` | **equivalent at 100** |
| Tracking hidden filter | `!m.Hidden \|\| m.IsPlayer() \|\| from.AccessLevel > m.AccessLevel` `Tracking.cs:199` | `m.Hidden && m.AccessLevel != Player && from.AccessLevel <= m.AccessLevel` ⇒ skip `Tracking/Tracking.cs:247` | **equivalent for players** |
| Remove Trap window | `TrapPower .. TrapPower + 10` `RemoveTrap.cs:111` | `TrapPower .. TrapPower + 30` `RemoveTrap.cs:61` | **different** |
| Remove Trap prereqs | gated on `!Core.EJ`, `502366`/`502367` `RemoveTrap.cs:29-36` | **not gated** `RemoveTrap.cs:17-24` | **different** |
| Notoriety hues | `{0x000,0x059,0x03F,0x3B2,0x3B2,0x090,0x022,0x035}` `Server/Notoriety.cs:17` and `NotorietyHandlers` `Scripts/Misc/Notoriety.cs:25-31` | identical values `Projects/UOContent/Misc/Notoriety.cs:18-24` | **same** |
| Skill-check roll | `Random(100) <= (int)(chance*100)` `Scripts/Misc/SkillCheck.cs:245` | `chance >= Utility.RandomDouble()` `Projects/UOContent/Skills/SkillCheck.cs:115` | **different (see 5.0)** |

### 5.7 Clone-implementation table — every number a clone must reproduce

`S` = ServUO pub57 value (authoritative for this clone), `M` = ModernUO value, `[ERA]` = expansion gate.

| # | Constant | Value | Gate | Src |
|---|---|---|---|---|
| 1 | Hiding skill id / callback slot | `21` | — | `Hiding.cs:23` |
| 2 | Hiding busy (spell) message | `501238` | — | `Hiding.cs:30` |
| 3 | Hiding busy cooldown | `1.0 s` | — | `Hiding.cs:31` |
| 4 | Hiding under ManaSpike cooldown (silent) | `1.0 s` | VvV | `Hiding.cs:36` |
| 5 | Cancel current target on hide | yes | `Core.ML` | `Hiding.cs:39-42` |
| 6 | Hiding house-friend bonus | `100.0` | — | `Hiding.cs:50` |
| 7 | Hiding adjacent-house bonus | `50.0` | `!Core.AOS` `[ERA]` | `Hiding.cs:67` |
| 8 | House probe offsets / height | `(x±1,y,127)`, `(x,y±1,127)`, range `16` | `!Core.AOS` | `Hiding.cs:55-64` |
| 9 | Hiding skill clamp | `Math.Min(100, (int)Hiding.Value)` | — | `Hiding.cs:71` |
| 10 | Hiding watch range formula | `Math.Min((int)((100-skill)/2) + 8, 18)` | — | `Hiding.cs:72` |
| 11 | Hiding watch range at GM | `8` tiles | — | derived |
| 12 | Hiding check window | `0.0 - bonus .. 100.0 - bonus` | — | `Hiding.cs:96` |
| 13 | Hiding watched messages | `501237` (hue `0x22`) | — | `Hiding.cs:103` |
| 14 | Hiding watched cooldown | `TimeSpan.Zero` | — | `Hiding.cs:105` |
| 15 | Hiding success message / hue | `501240` / `0x1F4` | — | `Hiding.cs:116` |
| 16 | Hiding failure message / hue | `501241` / `0x22` | — | `Hiding.cs:122` |
| 17 | Hiding cooldown (success **and** failure) | `10.0 s` | — | `Hiding.cs:125` |
| 18 | Hiding success clears invis timers | `Sixth.InvisibilitySpell.RemoveTimer` + `Items.InvisibilityPotion.RemoveTimer` | — | `Hiding.cs:114-115` |
| 19 | `Hidden=true` ⇒ step pool | `0` | — | `Mobile.cs:8982` |
| 20 | `Hidden=true` ⇒ warmode/combatant | `Warmode=false` else `Combatant=null` | — | `Mobile.cs:8963-8973` |
| 21 | Hiding buff | `BuffIcon.HidingAndOrStealth`, cliloc `1075655` | — | `PlayerMobile.cs:1747` |
| 22 | Stealth hiding requirement | `30.0` / `50.0` / `80.0` | ML / SE / else `[ERA]` | `Stealth.cs:28` |
| 23 | Stealth already-hidden message | `502725` | — | `Stealth.cs:74` |
| 24 | Stealth flying message | `1113415` | — | `Stealth.cs:78` |
| 25 | Stealth requirement message | `502726` | — | `Stealth.cs:84` |
| 26 | Stealth busy message | `1063086` | — | `Stealth.cs:90` |
| 27 | Stealth armor cap | `42` / `26` | AoS / else | `Stealth.cs:98` |
| 28 | Stealth armor-cap message | `502727` | — | `Stealth.cs:100` |
| 29 | Stealth check window | `-20.0 + AR*2 .. (60.0\|80.0) + AR*2` | AoS / else | `Stealth.cs:104` |
| 30 | Stealth steps | `(int)(Stealth.Value / (5.0\|10.0))`, min `1` | AoS / else | `Stealth.cs:106-109` |
| 31 | Stealth success message | `502730` | — | `Stealth.cs:115` |
| 32 | Stealth failure message | `502731` | — | `Stealth.cs:122` |
| 33 | Stealth cooldown (all branches) | `10.0 s` | — | `Stealth.cs:118,128` |
| 34 | Step decrement condition | `--AllowedStealthSteps <= 0 \|\| Running \|\| Mounted` | — | `Mobile.cs:3046` |
| 35 | Player auto-stealth threshold | `Stealth.Value >= 25.0 && !Mounted` | `Core.SE` | `PlayerMobile.cs:5450` |
| 36 | Running step cost | `-2` | `Core.SE` | `PlayerMobile.cs:5456` |
| 37 | Exhausted walk behaviour | re-call `Stealth.OnUse(this)` | `Core.SE` | `PlayerMobile.cs:5463` |
| 38 | Stealthing consumers require | `Hidden && AllowedStealthSteps > 0` | Ninjitsu | `Backstab.cs:49` etc. |
| 39 | Snooping range | `1` tile (`500446` otherwise) | — | `Snooping.cs:42,96` |
| 40 | Snooping staff-container message | `500209` | — | `Snooping.cs:54` |
| 41 | Snooping illegal-target message | `1001018` | — | `Snooping.cs:60` |
| 42 | Snooping victim-notify roll | `Snooping.Value < Utility.Random(100)` | — | `Snooping.cs:64` |
| 43 | Snooping victim-notify text/hue | `"You notice {0} peeking into your belongings!"`, hue `946`, font `3`, `AsciiMessage` | — | `Snooping.cs:70-72` |
| 44 | Snooping karma delta | `-4` (title award, always) | — | `Snooping.cs:77` |
| 45 | Snooping check window | `0.0 .. 100.0` | — | `Snooping.cs:79` |
| 46 | Snooping fail message | `500210` | — | `Snooping.cs:88` |
| 47 | Snooping fail-reveal roll | `Hiding.Value / 2 < Utility.Random(100)` | — | `Snooping.cs:90` |
| 48 | Snooping criminal flag | **none** | — | (absent) |
| 49 | Stealing skill id / slot | `33` | — | `Stealing.cs:25` |
| 50 | Stealing target range | `1` (`base(1,false,TargetFlags.None)`, `AllowNonlocal`) | — | `Stealing.cs:48,52` |
| 51 | Stealing use message / cooldown | `502698` / `10.0 s` | — | `Stealing.cs:523,526` |
| 52 | Empty-hands requirement | `Layer.OneHanded` and `Layer.TwoHanded` both null | — | `Stealing.cs:497-510` |
| 53 | `1005584` both hands | yes | — | `Stealing.cs:69,516` |
| 54 | `1005596` thieves guild | required for player roots | — | `Stealing.cs:73` |
| 55 | `1005598` shopkeepers | `BaseVendor.IsInvulnerable` | — | `Stealing.cs:81` |
| 56 | `502709` PlayerVendor | yes | — | `Stealing.cs:85` |
| 57 | `500237` not visible | yes | — | `Stealing.cs:89` |
| 58 | `1048147` backpack full | `Backpack.CheckHold(m, item, false, true)` | — | `Stealing.cs:93` |
| 59 | Weight cap | `w = Weight + TotalWeight ; w > 10` → `"That is too heavy to steal."` | — | `Stealing.cs:289-293` |
| 60 | Stack `maxAmount` | `(int)((Stealing.Value / 10.0) / toSteal.Weight)`, clamp `[1, Amount]` | — | `Stealing.cs:299-308` |
| 61 | Stack amount roll | `Utility.RandomMinMax(1, maxAmount)` | — | `Stealing.cs:310` |
| 62 | Pile weight (full / partial) | `(int)Math.Ceiling(Weight * Amount) * 10` / `(int)Math.Ceiling(Weight * amount) * 10` | — | `Stealing.cs:314,324` |
| 63 | Non-stack item weight | `iw = (int)Math.Ceiling(w) * 10` | — | `Stealing.cs:340-341` |
| 64 | Stealing check window | `iw - 22.5 .. iw + 27.5` (`+22.5` margin, `50` span) | — | `Stealing.cs:317,327,343` |
| 65 | Partial-stack split | `Mobile.LiftItemDupe(toSteal, toSteal.Amount - amount)` | — | `Stealing.cs:329` |
| 66 | Non-movable / non-stealable → `502710` | unless `ItemFlags.GetStealable` | — | `Stealing.cs:249-252` |
| 67 | Newbied / blessed / insured → `502710` | `LootType.Newbied \|\| CheckBlessed(root)` unless flagged stealable | — | `Stealing.cs:253-256` |
| 68 | Containers → `502710` | `Core.AOS` only, unless flagged stealable | `[ERA]` | `Stealing.cs:257-260` |
| 69 | Adjacency → `502703` | `InRange(...,1)` | — | `Stealing.cs:263` |
| 70 | Artifact skill gate → `1060025` (hue `0x66D`) | `Stealing.Value < 100.0` when `si != null` | — | `Stealing.cs:267` |
| 71 | Equipped → `1005585` | `toSteal.Parent is Mobile` | — | `Stealing.cs:271` |
| 72 | Self → `502704` | `root == thief` | — | `Stealing.cs:275` |
| 73 | Staff root → `502710` | yes | — | `Stealing.cs:279` |
| 74 | `CanBeHarmful` false | **silent no-op** | — | `Stealing.cs:281-282` |
| 75 | Corpse root → `502710` | yes | — | `Stealing.cs:285` |
| 76 | Success → `502724` + `SetTaken(true)` + `SetStealable(false)` + `Movable = true` | yes | — | `Stealing.cs:370-374` |
| 77 | Fail → `502723` | yes | — | `Stealing.cs:386` |
| 78 | Caught (fillable container) | `Utility.Random((int)(Stealing.Value/2.5)) == 0` ⇒ `1/48` at 120 | — | `Stealing.cs:356` |
| 79 | Caught (other movable) | `Stealing.Value < Utility.Random(150)` ⇒ `(149-Stealing)/150` | — | `Stealing.cs:360` |
| 80 | Caught (non-movable, non-fillable) | `false` | — | `Stealing.cs:365` |
| 81 | Bystander broadcast radius | `8` | — | `Stealing.cs:472` |
| 82 | Bystander text | `"You notice {0} trying to steal from {1}."` (thief, victim) | — | `Stealing.cs:470` |
| 83 | Criminal on caught, ground root | `CriminalAction(false)` | — | `Stealing.cs:455` |
| 84 | Criminal on caught, innocent player/NPC root | `CriminalAction(false)` when `!IsInGuild(root) && IsInnocentTo(thief, root)` | — | `Stealing.cs:465-468` |
| 85 | Criminal on looting a criminal corpse | `CriminalAction(false)` whether or not caught | — | `Stealing.cs:457-460,481-484` |
| 86 | `PermaFlags.Add(root)` | player root + innocent + `!IsInGuild(root)` (dead code: `ClassicMode == false`) | — | `Stealing.cs:486-493` |
| 87 | Criminal flag duration | `2.0 minutes`, restarted on every new flag | — | `Server/Mobile.cs:2102,11827-11839` |
| 88 | Criminal notoriety value / hue | `4` / `0x3B2` | — | `Server/Notoriety.cs:10,17`; `Scripts/Misc/Notoriety.cs:28` |
| 89 | Criminal-action message (never sent by stealing) | `1005040` | — | `Server/Region.cs:912` |
| 90 | Guard-candidate delay before guards may be called | `15.0 s` | — | `GuardedRegion.cs:452` |
| 91 | Guard-candidate announce / expiry | `502275` / `502276` | — | `GuardedRegion.cs:269,465` |
| 92 | Fake guard call radius / lines | `8` tiles / `1007037, 501603, 1013037-1013043, 1013052` | — | `GuardedRegion.cs:278,299` |
| 93 | `*guards*` keyword / call radius | `0x0007` / `14` tiles | — | `GuardedRegion.cs:192,322` |
| 94 | Guard reuse radius | `8` tiles, else spawn `WarriorGuard` (`ArcherGuard` on Ilshenar/Malas) | — | `GuardedRegion.cs:127,65-78` |
| 95 | `AllowReds` (reds auto-flagged on entry/sight) | `Core.AOS` | `[ERA]` | `GuardedRegion.cs:63,169-172` |
| 96 | Aggression guard radius | `12` tiles | — | `GuardedRegion.cs:202` |
| 97 | Detect Hidden prompt / cooldown | `500819` / `10.0 s` | — | `DetectHidden.cs:37,40` |
| 98 | Detect Hidden target range | `12` | — | `DetectHidden.cs:46` |
| 99 | Detect Hidden search radius | `Math.Max(2, (int)(DetectHidden.Value / 10.0))` | — | `DetectHidden.cs:65` |
| 100 | Failed-check radius penalty | `range /= 2` | — | `DetectHidden.cs:67-68` |
| 101 | Friend-of-house radius | `22` | — | `DetectHidden.cs:75` |
| 102 | Active detection variance | `±10` via `Utility.Random(21) - 10` on **both** sides | — | `DetectHidden.cs:85-86` |
| 103 | Active detection success | `ss >= ts \|\| houseCheck`, plus `RandomDouble() > shadow` (Shadow mastery) and `CanDetect` | — | `DetectHidden.cs:90-94` |
| 104 | Reveal message to target | `500814`, overhead hue `0x3B2` | — | `DetectHidden.cs:97-98` |
| 105 | Nothing-found message | `500817` | — | `DetectHidden.cs:135` |
| 106 | Passive detect cadence / mobile radius | every `2 s` of movement / `4` tiles | — | `PlayerMobile.cs:2095-2099`, `DetectHidden.cs:150` |
| 107 | Passive target skill | `(Hiding.Value + Stealth.Value) / 2` | — | `DetectHidden.cs:160` |
| 108 | Elf passive bonus | `+20` to detector skill | — | `DetectHidden.cs:162-163` |
| 109 | Passive roll | `Utility.Random(1000) < (ss - ts) + 1` | — | `DetectHidden.cs:165` |
| 110 | Passive item radius / message | `8` tiles / `1153493` | — | `DetectHidden.cs:174-181` |
| 111 | Forensics callback / prompt / cooldown / target range | `19` / `501000` / `1.0 s` / `10` | — | `ForensicEval.cs:19,27,29,35` |
| 112 | Forensics corpse windows | pre-gate `30.0`; `CheckTargetSkill(30.0, 55.0)` | — | `ForensicEval.cs:42,52` |
| 113 | Forensics mobile windows | pre-gate `36.0`; `CheckTargetSkill(36.0, 100.0)`; thief → `501004` | — | `ForensicEval.cs:90,94,98` |
| 114 | Forensics lock windows | pre-gate `41.0`; `CheckTargetSkill(41.0, 100.0)`; `1042749` | — | `ForensicEval.cs:112,116,122` |
| 115 | Forensics SA item gate / messages | `41.0`; `1151521` at `Forensics.Value >= 61.0` else `1151522` | `Core.SA` | `ForensicEval.cs:142,159-165` |
| 116 | Tracking callback / prompt / cooldown | `38` / `1011350` / `10.0 s` | — | `Tracking.cs:17,22,28` |
| 117 | Tracking entry window / passive gain | `0.0 .. 21.1` / `21.1 .. 100.0` | — | `Tracking.cs:87,189` |
| 118 | Tracking search range | `10 + (int)(Tracking.Value / 10)` | — | `Tracking.cs:191` |
| 119 | Tracking PvP difficulty | `50 * (Tracking*2 + DetectHidden) / (Hiding + Stealth)` | `Core.SE` | `Tracking.cs:265` |
| 120 | Tracking elf divisor | `tracking /= 2` | `Core.ML` | `Tracking.cs:246-247` |
| 121 | Necromancy form modifiers | HorrificBeast `-200`; VampiricEmbrace `= 500` if `< 500`; WraithForm `+200` if `<= 2000` | — | `Tracking.cs:254-259` |
| 122 | Stalking bonus | `sqrt(dx²+dy²)`, capped at `10 + Tracking.Value/10` | `Core.ML` cap | `Tracking.cs:48-53` |
| 123 | Remove Trap callback / prereqs | `48`; Lockpicking `>= 50` else `502366`; DetectHidden `>= 50` else `502367` | `!Core.EJ` | `RemoveTrap.cs:24,29-36` |
| 124 | Remove Trap prompt / cooldown / range | `502368` / `10.0 s` / `2` | — | `RemoveTrap.cs:41,44,50` |
| 125 | Remove Trap window | `CheckTargetSkill(RemoveTrap, targ, TrapPower, TrapPower + 10)` | — | `RemoveTrap.cs:111` |
| 126 | Remove Trap success / fail | `502377` / `502372` | — | `RemoveTrap.cs:117,121` |
| 127 | Faction trap window | `RemoveTrap 80..100 && Tinkering 80..100` | — | `RemoveTrap.cs:148` |
| 128 | VvV trap chance / detonate | `(RemoveTrap.Value - 80.0)/20.0 > RandomDouble()`; detonate on `0.1 > RandomDouble()` | VvV | `RemoveTrap.cs:181,203` |
| 129 | Chest disarm windows | GM (100+): `80 .. 120 + Level*10`; else `min = ceil(RemoveTrap*0.75)`, `max = min > 50 ? min+50 : 100`; safety `20/60/180/420/540 s` by level | new treasure system | `RemoveTrap.cs:324-332,366,382-384` |
| 130 | Chest disarm timer / range | `10 s` repeat / `16` tiles | — | `RemoveTrap.cs:314,351` |
| 131 | Skill-check roll | `Utility.Random(100) <= (int)(chance * 100)` | — | `SkillCheck.cs:245` |
| 132 | Anti-macro allowance / window / tile size | `3` uses / `5 min` / `4` tiles | — | `SkillCheck.cs:28,33,38` |

### 5.8 Gaps / UNVERIFIED

| Gap | Why | What would resolve it |
|---|---|---|
| OSI's *real* stealing success formula | UOGuide documents a completely different, witness-based formula (`Difficulty = itemWeight * targetingFactor * 2000 / (100 + Stealing*10)`; `Percent Chance = (500 + 2*(Stealing*10 - Difficulty))/10`) — [UOGuide — Stealing](https://www.uoguide.com/Stealing). ServUO uses the flat `±22.5/27.5` window instead. **`[PARTIAL]`** | live-shard packet capture or Leurocian's original publish notes; the clone must state which formula it implements |
| ServUO `caught` probability fidelity | the `Stealing < Random(150)` literal is a ServUO/RunUO artefact with no OSI citation; no web source gives the witness-check constant | measure catch-rate over N=1000 steals at fixed skill/container |
| Exact `Utility.Random` implementation | `RandomImpl.Next` is abstracted (`Server/Utility.cs:921-924`); the concrete RNG is chosen at runtime | read the `RandomImpl` implementation actually compiled into the target build |
| `ShadowSpell.GetDifficultyFactor` constants | used by active Detect Hidden (`DetectHidden.cs:87`); not in the requested file set | read `Scripts/Spells/SkillMasteries/ShadowSpell.cs` |
| `Mobile.InsuranceEnabled` default | gates the "Insured ⇒ unstealable" branch (`Item.cs:6123`) | read the static initialiser / config |
| Hiding behaviour on *non-SE* shards | `PlayerMobile.OnMove` bypasses the step engine when `!Core.SE`, so `Mobile.OnMove` reveals at `AllowedStealthSteps <= 0` with no re-check | choose a target expansion; the clone's `[ERA]` decision determines which of the two step engines to port |
| Whether a clone needs the XmlSpawner `ItemFlags` | `Stealing.cs:249,253,257,372-373` depend on `Server.Items.ItemFlags` which lives in the XmlSpawner service, not `Server/` | decide whether to port `StealableFlag = 0x00200000` / `TakenFlag = 0x00100000` or drop those checks |
| Exact client-side stealth icon timing | client `ClassicUO` was not read for this section | read `.research-src\classicuo` for the buff-icon/step display logic |
