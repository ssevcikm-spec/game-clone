## 3. Skill gain & stat gain

Sources: **ServUO `pub57`** (primary, all mechanics below are literal from the checkout) and **ModernUO `main`** (differences flagged). Citation shorthand used in this section (every `ServUO:<path>:<line>` expands to the GitHub URL form shown here):

| Shorthand | Expands to |
|---|---|
| `ServUO:Scripts/Misc/SkillCheck.cs:221` | `https://github.com/ServUO/ServUO/blob/pub57/Scripts/Misc/SkillCheck.cs#L221` |
| `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:108` | `https://github.com/modernuo/ModernUO/blob/main/Projects/UOContent/Skills/SkillCheck.cs#L108` |

Files read in full for this section: `ServUO:Scripts/Misc/SkillCheck.cs` (808 lines), `ServUO:Server/Skills.cs` (1109 lines), `ServUO:Scripts/Gumps/SkillsGump.cs` (555 lines), `ServUO:Server/Mobile.cs` (selected ranges), `ServUO:Scripts/Mobiles/PlayerMobile.cs` (selected ranges), `ModernUO:Projects/UOContent/Skills/SkillCheck.cs` (505 lines), `ModernUO:Projects/UOContent/Skills/AntiMacroSystem.cs` (270 lines), `ModernUO:Projects/Server/Skills.cs`, `ModernUO:Distribution/Data/skills.json` (930 lines).

---

### 3.0 Call graph & units (read this first)

| Fact | Value | Source |
|---|---|---|
| Skill storage | `ushort` fixed point, 1/10 skill point | `ServUO:Server/Skills.cs:95` |
| `Skill.Base` | `m_Base / 10.0` (double) | `ServUO:Server/Skills.cs:322` |
| `Skills.Total` / `Skills.Cap` | **fixed points** (7000 = 700.0) | `ServUO:Server/Skills.cs:844,853` |
| Individual skill cap | `m_Cap` fixed point, default `1000` = 100.0 | `ServUO:Server/Skills.cs:124,874` |
| Total skill cap default | `Config.Get("PlayerCaps.TotalSkillCap", 7000)` | `ServUO:Server/Skills.cs:996` |
| Entry points | `Mobile.CheckSkill` / `Mobile.CheckTargetSkill` → static handler delegates | `ServUO:Server/Mobile.cs:12598-12644`, delegates declared `:508-511,625-632` |
| Handler wiring | `SkillCheck.Initialize()` installs `XmlSpawnerSkillCheck.*`, which calls straight back into `SkillCheck.*` then fires XML-spawner skill triggers | `ServUO:Scripts/Misc/SkillCheck.cs:125-132`, `ServUO:Scripts/Services/XmlSpawner/XmlSpawner Core/XmlSpawnerSkillCheck.cs:26-88` |
| Region gain multiplier | `Region.SkillGain(from) => 0.1` (virtual, **no overrides exist in the tree**) | `ServUO:Server/Region.cs:973-976` |
| Therefore `toGain` | `(int)(from.Region.SkillGain(from) * 10)` = `(int)(0.1*10)` = **1 fixed point = 0.1 skill** | `ServUO:Scripts/Misc/SkillCheck.cs:361` |

Flow: `CheckSkill()` → difficulty `chance` → **success roll** → `GetGainChance()` → `AllowGain()` → `Gain()` → `CheckReduceSkill()` → cap gate → `Skill.BaseFixedPoint +=` → `UpdateGGS()` → stat-gain branch.

[SRC] for the whole table.

---

### 3.1 `GetGainChance` decomposed term by term

There are **two** private `GetGainChance` overloads plus one public bulk variant. Do not conflate them.

#### (a) The main overload — `SkillCheck.cs:261-284` (used by every normal `CheckSkill`)

```csharp
private static double GetGainChance(Mobile from, Skill skill, double chance, bool success)   // :261
{
    var gc = (double)(from.Skills.Cap - from.Skills.Total) / from.Skills.Cap;   // :263  T
    gc += (skill.Cap - skill.Base) / skill.Cap;                                // :265  S
    gc /= 2;                                                                   // :266
    gc += (1.0 - chance) * (success ? 0.5 : (Core.AOS ? 0.0 : 0.2));           // :268  D
    gc /= 2;                                                                   // :269
    gc *= skill.Info.GainFactor;                                              // :271  G
    if (gc < 0.01) gc = 0.01;                                                  // :273-274  floor
    if (from is BaseCreature && ((BaseCreature)from).Controlled) gc += gc * 1.00; // :277-278 pet +100 %
    if (gc > 1.00) gc = 1.00;                                                  // :280-281  clamp
    return gc;
}
```

Algebra (all quantities in **fixed points** where `Cap`/`Total` are used, i.e. 7000/3500-scale):

```
T = (Skills.Cap - Skills.Total) / Skills.Cap          # total-cap head-room, 1.0 when Total = 0
S = (skill.Cap - skill.Base)   / skill.Cap            # per-skill head-room, 1.0 when Base = 0
D = (1 - chance) * k         where k = 0.5 if success
                                     = 0.0 if !success and Core.AOS
                                     = 0.2 if !success and !Core.AOS
G = skill.Info.GainFactor                            # 1.0 for all 58 skills (see §3.9)

gc_raw = ( ( (T + S) / 2 ) + D ) / 2 * G
gc     = clamp( max(gc_raw, 0.01), min..1.00 )
gc_pet = clamp( gc * 2.00 , min..1.00 )              # only if from is a CONTROLLED BaseCreature
```

Term-by-term:

| Term | Expression | Range | Meaning | Source |
|---|---|---|---|---|
| Total-cap term `T` | `(Cap - Total)/Cap` | 0 → 1 | 1.0 at zero total skill, 0.0 at 700.0 total | `SkillCheck.cs:263` |
| Per-skill-cap term `S` | `(skill.Cap - skill.Base)/skill.Cap` | 0 → 1 | 1.0 at base 0, 0.0 at the skill's own cap | `SkillCheck.cs:265` |
| Averaging | `(T + S) / 2` | 0 → 1 | the two head-rooms count equally | `SkillCheck.cs:266` |
| Difficulty/success term `D` | `(1 - chance) * k` | 0 → 0.5 (AoS) | **easier checks give *less* gain chance**; `chance` is the pre-roll ratio `(value-min)/(max-min)`, not the success flag | `SkillCheck.cs:268` |
| Failure weight `k` | `0.5` success / `0.0` AoS-failure / `0.2` pre-AoS failure | — | in AoS+ a **failed** use contributes **no** gain term at all | `SkillCheck.cs:268` |
| `GainFactor` | `skill.Info.GainFactor` | 1.0 for all 58 | per-skill multiplier hook, unused in this table | `SkillCheck.cs:271`, `Server/Skills.cs:586` |
| Floor | `if (gc < 0.01) gc = 0.01` | min 1 % | applied **before** the pet bonus | `SkillCheck.cs:273-274` |
| Pet bonus | `gc += gc * 1.00` → `×2` | — | **only** `BaseCreature && Controlled`; tamed/controlled pets gain at twice the rate | `SkillCheck.cs:277-278` |
| Clamp | `if (gc > 1.00) gc = 1.00` | max 100 % | applied **after** the pet bonus | `SkillCheck.cs:280-281` |

#### (b) The bulk/craft-all overload — `SkillCheck.cs:221-237`

Used only by `CheckSkill(from, SkillName, minSkill, maxSkill, amount)` (`:187-219`), whose sole caller is `UseAllRes` in `CraftItem.cs` ("Craft All Gains" region, `:178-238`).

```csharp
private static double GetGainChance(Mobile from, Skill skill, double gains, double chance)  // :221
{
    var gc = (double)(from.Skills.Cap - (from.Skills.Total + (gains * 10))) / from.Skills.Cap;  // :223
    gc += (skill.Cap - (skill.Base + (gains * 10))) / skill.Cap;                                // :225
    gc /= 4;                                                                                    // :226
    gc *= skill.Info.GainFactor;                                                                // :228
    if (gc < 0.01) gc = 0.01;                                                                   // :230-231
    if (gc > 1.00) gc = 1.00;                                                                   // :233-234
    return gc;
}
```

Call site: `GetGainChance(from, skill, (value - minSkill) / (maxSkill - minSkill), value)` (`:198`). So the parameter **named** `gains` receives the normalised difficulty ratio (0…1) and the parameter **named** `chance` (4th) is **never read** — dead parameter. Consequences vs. the main overload: divisor `4` instead of `2`, **no** difficulty/success term, **no** pet bonus, and a per-iteration penalty of `gains*10` fixed points (≤ 10 fixed points, i.e. ≤ 1.0 skill, since `gains ≤ 1`).

The returned value is divided by `10` at the call site (`:198`) to become the **per-iteration** probability, because the loop runs `amount` times (`:196`), incrementing a local `value += 0.1` counter; at the end the accumulated count is applied in **one** call: `if (gains > 0) { Gain(from, skill, gains); EventSink.InvokeSkillCheck(..., true); return true; }` (`:211-216`). So `amount = 100` yields ~100 independent rolls each at `gc/10`, applied as a single bulk `toGain` — which then runs through the normal `Gain()` (§3.3) including `CheckReduceSkill` and the total-cap gate exactly once.

[SRC] for (a) and (b). The naming mismatch is a literal source quirk, not an interpretation.

---

### 3.2 `chance`, the short-circuits, and how `success` feeds gain

`Mobile_SkillCheckLocation` (`SkillCheck.cs:134-158`):

```csharp
if (value < minSkill)  return false;                       // :147-148  "Too difficult" — NO gain roll at all
if (value >= maxSkill) return true;                        // :150-151  "No challenge"  — NO gain roll at all
var chance = (value - minSkill) / (maxSkill - minSkill);   // :153
return CheckSkill(from, skill, new Point2D(from.Location.X / LocationSize,
                                           from.Location.Y / LocationSize), chance);  // :157
```

| Step | Constant / literal | Source |
|---|---|---|
| `value` | `skill.Value` (stat-modified, see §3.10) | `:141` |
| Fishing special case | `if (skillName == Fishing && BaseGalleon.FindGalleonAt(from, from.Map) is TokunoGalleon) value += 1;` | `:144-145` |
| Too difficult | `value < minSkill` → return `false`, **no** `AllowGain`, **no** `Gain` | `:147-148` |
| No challenge | `value >= maxSkill` → return `true`, **no** `AllowGain`, **no** `Gain` | `:150-151` |
| `chance` | `(value - minSkill) / (maxSkill - minSkill)` — 0.0 at `minSkill`, 1.0 at `maxSkill` | `:153` |
| Difficulty feedback item | `CrystalBallOfKnowledge.TellSkillDifficulty(from, skillName, chance)` — messages `1078457` Too Challenging … `1078463` Too Easy, bands 0.0 / ≤0.1 / ≤0.25 / ≤0.75 / ≤0.9 / ≤1.0 | `:155`, `Scripts/Items/Quest/CrystalBallOfKnowledge.cs:102-124` |
| Direct-chance variants | `chance < 0.0` → false, `chance >= 1.0` → true, else roll | `:160-176` (location), `:313-329` (target) |
| Target variant | identical maths, `obj` = the target instead of a `Point2D` | `:286-311` |

Success roll and gain application (`CheckSkill(Mobile, Skill, object, double)`, `:240-259`):

```csharp
if (from.Skills.Cap == 0) return false;                                  // :242-243
var success = Utility.Random(100) <= (int)(chance * 100);                 // :245
var gc = GetGainChance(from, skill, chance, success);                     // :246
if (AllowGain(from, skill, obj))                                          // :248
    if (from.Alive && (skill.Base < 10.0 || Utility.RandomDouble() <= gc || CheckGGS(from, skill)))
        Gain(from, skill);                                                // :250-253
EventSink.InvokeSkillCheck(new SkillCheckEventArgs(from, skill, success)); // :256
return success;                                                           // :258
```

| Behaviour | Literal | Source |
|---|---|---|
| Cap-0 shard guard | `if (from.Skills.Cap == 0) return false;` | `:242-243` |
| `success` roll | `Utility.Random(100) <= (int)(chance * 100)` → **P(success) = ((int)(chance*100)+1)/100**, i.e. `chance = 0.5` succeeds 51 % of the time (`Utility.Random(n)` = `Next(n)` ∈ 0..n-1, `Server/Utility.cs:921-924`) | `:245` |
| `success` → gc | only through `k` in term `D` (0.5 vs 0.0/0.2). It does **not** gate whether a gain is attempted | `:268` |
| Free gain below 10.0 | `skill.Base < 10.0` ⇒ the random roll and GGS are short-circuited, gain is automatic | `:250` |
| Random gain | `Utility.RandomDouble() <= gc` (P = gc, `RandomDouble ∈ [0,1)`) | `:250`, `Server/Utility.cs:931` |
| GGS override | `|| CheckGGS(from, skill)` — evaluated only when the roll above failed; guarantees one gain | `:250`, `:774-785` |
| Alive requirement | `from.Alive` — dead mobiles/players never gain | `:250` |
| Event | `EventSink.InvokeSkillCheck(...)` fires **even when no gain happened and even when `AllowGain` returned false** | `:256` |
| Return value | `success` — the caller's skill-use result is *independent* of whether the skill grew | `:258` |

---

### 3.3 `Gain()` in full

```csharp
public static void Gain(Mobile from, Skill skill)                            // :359
    => Gain(from, skill, (int)(from.Region.SkillGain(from) * 10));           // :361  → toGain = 1

public static void Gain(Mobile from, Skill skill, int toGain)                // :364
{
  if (from.Region.IsPartOf<Jail>()) return;                                  // :366-367
  if (from is BaseCreature && ((BaseCreature)from).IsDeadPet) return;         // :369-370
  if (skill.SkillName == SkillName.Focus && from is BaseCreature &&
      (!PetTrainingHelper.Enabled || !((BaseCreature)from).Controlled)) return; // :372-374

  if (skill.Base < skill.Cap && skill.Lock == SkillLock.Up)                   // :376
  {
      var skills = from.Skills;
      if (from is PlayerMobile && Siege.SiegeShard) { ...ROT gate...; return; }  // :380-398
      if (toGain == 1 && skill.Base <= 10.0) toGain = Utility.Random(4) + 1;     // :400-401
      if (from is PlayerMobile && QuestHelper.EnhancedSkill((PlayerMobile)from, skill))
          toGain *= Utility.RandomMinMax(2, 4);                                  // :404-407
      if (from is PlayerMobile && skill.SkillName == ((PlayerMobile)from).AcceleratedSkill &&
          ((PlayerMobile)from).AcceleratedStart > DateTime.UtcNow)
      { SendLocalizedMessage(1077956); toGain = Utility.RandomMinMax(2, 5); }     // :411-418
      else if (from is BaseCreature && !DespiseCreature && (Controlled || Summoned)) {
          var master = ((BaseCreature)from).GetMaster();
          var spell = SkillMasterySpell.GetSpell(master, typeof(WhisperingSpell)) as WhisperingSpell;
          if (spell != null && master.InRange(from.Location, spell.PartyRange) &&
              master.Map == from.Map && spell.EnhancedGainChance >= Utility.Random(100))
              toGain = Utility.RandomMinMax(2, 5); }                              // :422-436
      if (from is PlayerMobile) CheckReduceSkill(skills, toGain, skill);          // :439-442
      if (!from.Player || (skills.Total + toGain <= skills.Cap)) {                // :444
          skill.BaseFixedPoint = Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain); // :446
          EventSink.InvokeSkillGain(new SkillGainEventArgs(from, skill, toGain)); // :448
          if (from is PlayerMobile) UpdateGGS(from, skill);                       // :450-451
      }
  }
  if (from is PlayerMobile) QuestHelper.CheckSkill((PlayerMobile)from, skill);    // :456-457
  if (skill.Lock == SkillLock.Up && (!Siege.SiegeShard || !(from is PlayerMobile) ||
      Siege.CanGainStat((PlayerMobile)from))) { ...stat gain... }                 // :460-481
}
```

| Mechanic | Exact behaviour | Source |
|---|---|---|
| Unit | `toGain` is in **fixed points**; 1 = 0.1 skill | `Server/Skills.cs:285-319` |
| Base increment | `skill.BaseFixedPoint = Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain)` — clamped at the *individual* skill cap | `:446` |
| Jail | whole `Gain()` returns early inside a `Jail` region | `:366-367` |
| Dead pet | `BaseCreature.IsDeadPet` never gains | `:369-370` |
| Focus (pet) | `Focus` gain suppressed for creatures unless `PetTrainingHelper.Enabled` **and** controlled | `:372-374` |
| Preconditions | `skill.Base < skill.Cap` **and** `skill.Lock == SkillLock.Up` | `:376` |
| Low-skill boost | only when `toGain == 1 && skill.Base <= 10.0` → `Utility.Random(4) + 1` = **1…4** fixed points (uniform) | `:400-401` |
| ML Apprentice quest | `QuestHelper.EnhancedSkill` true → `toGain *= RandomMinMax(2, 4)` = **×2…×4** — requires an incomplete `ApprenticeObjective` whose `Region` contains the player and whose `Skill` matches | `:404-407`, `Scripts/Services/MondainsLegacyQuests/Helpers/QuestHelper.cs:802-829` |
| Scroll of Alacrity | player's `AcceleratedSkill` matches **and** `AcceleratedStart > UtcNow` → message `1077956` + `toGain = RandomMinMax(2, 5)` = **2…5** (assignment, *replaces* the low-skill boost) | `:411-418`; scroll sets 15 min: `Scripts/Items/Consumables/ScrollofAlacrity.cs:59,122` |
| Whispering mastery | *`else if`* branch: controlled/summoned non-Despise creature, master within `PartyRange` (12, `SkillMasterySpell.cs:36`) on the same map, and `spell.EnhancedGainChance >= Utility.Random(100)` → `toGain = RandomMinMax(2, 5)`. `EnhancedGainChance = (int)(BaseSkillBonus / 1.26)`, duration 600 s | `:422-436`, `Scripts/Spells/Skill Masteries/Whispering.cs:88,84` |
| Event | `EventSink.InvokeSkillGain` fires **only when the base actually increased** | `:448` |
| GGS timer refresh | `UpdateGGS` only for `PlayerMobile`, only after a real gain | `:450-451` |
| ML quest hook | `QuestHelper.CheckSkill` for players regardless of whether the gain landed | `:456-457` |
| Stat gain gate | runs whenever `skill.Lock == SkillLock.Up` (i.e. also on *failed* skill uses and when the total-cap gate denied the skill point) | `:460-481` |

**Dead / missing in ServUO `pub57`:** there is **no** `Mobile.DisableSkill` method anywhere in the tree (grepped whole checkout). The equivalent gates are `Mobile.AllowSkillUse` (virtual, base returns `true`, `Server/Mobile.cs:3944-3947`), the `PlayerMobile` override (animal-form restricted skills + `DesignContext.Check`, `Scripts/Mobiles/PlayerMobile.cs:2238-2262`), `Region.OnSkillUse` (`Server/Region.cs:963-971`; `Jail` override returns `from.IsStaff()`, `Scripts/Regions/Jail.cs:55-61`), and the `SkillInfo.UseWhileCasting` / `from.Spell == null` gate inside `Skills.UseSkill` (`Server/Skills.cs:912-923`).

`SendSkillMessage` / `NextSkillTime`: `Skills.UseSkill` requires `Core.TickCount - from.NextSkillTime >= 0`; on failure it calls `from.SendSkillMessage()` → localized `500118` "You must wait a few moments to use another skill.", itself rate-limited by `ActionMessageDelay = 125` ms (`Server/Mobile.cs:1855-1865`); `NextSkillTime = Core.TickCount + (int)callback(from).TotalMilliseconds` (`Server/Skills.cs:916`). "That skill cannot be used directly" = `500014` (`Server/Skills.cs:927`). [SRC]

---

### 3.4 Total-cap arbitration at 700.0 (and `CheckReduceSkill`)

```csharp
// SkillCheck.cs:439-452 (order is significant)
if (from is PlayerMobile) CheckReduceSkill(skills, toGain, skill);
if (!from.Player || (skills.Total + toGain <= skills.Cap)) { ...apply gain... }

// SkillCheck.cs:484-497
private static void CheckReduceSkill(Skills skills, int toGain, Skill gainSKill) {
    if (skills.Total / skills.Cap >= Utility.RandomDouble())          // :486  roll ≈ Total/Cap
        foreach (var toLower in skills)                                // :488  enumeration order = skill id 0..57
            if (toLower != gainSKill && toLower.Lock == SkillLock.Down &&
                toLower.BaseFixedPoint >= toGain) {                    // :490
                toLower.BaseFixedPoint -= toGain; break;               // :492  FIRST match only
            }
}
```

| Rule | Exact behaviour | Source |
|---|---|---|
| Who is subject to reduction | `PlayerMobile` only (called inside `if (from is PlayerMobile)`) | `:439-442` |
| Reduction trigger | `skills.Total / skills.Cap >= Utility.RandomDouble()` — integer division of fixed points by fixed points, so this is `Total/Cap` as an **integer** (0 or 1 in practice) compared with a double: at `Total = 7000`, `Cap = 7000` → `1 >= r` ⇒ always true; at `Total = 3500` → `0 >= r` is true only when `RandomDouble()` returns exactly `0.0` ⇒ effectively never | `:486` |
| Which skill is reduced | the **first** skill in `Skills` enumeration order whose `Lock == SkillLock.Down` and whose `BaseFixedPoint >= toGain`; `break` after the first hit | `:488-494` |
| Enumeration order | `Skills.GetEnumerator()` = `m_Skills.Where(s => s != null)` → array order = **skill id ascending 0…57** | `Server/Skills.cs:1099-1107` |
| Self-exclusion | the skill being raised is skipped (`toLower != gainSKill`) | `:490` |
| Up-locked / Locked skills | **never** reduced — only `SkillLock.Down` | `:490` |
| Insufficient points | a Down skill with `BaseFixedPoint < toGain` is skipped entirely (no partial drain) | `:490` |
| Ordering vs. the cap gate | reduction happens **before** the `Total + toGain <= Cap` test, and `BaseFixedPoint`'s setter keeps `Skills.Total` in sync (`Server/Skills.cs:305`), so the drain can make room for the gain in the same call | `:439-446` |
| Net-loss case | if the drain happens but `Total + toGain` still exceeds `Cap`, the skill point is **not** granted and the reduction is **not** refunded → a net 0.1 loss | `:444-452` |
| Non-players | `from.Player == false` (creatures) bypass the cap gate entirely: `!from.Player || …` → creatures can exceed `Skills.Cap` | `:444` |
| Final clamp | `Math.Min(skill.CapFixedPoint, skill.BaseFixedPoint + toGain)` — the 100.0 (or powerscroll-raised) individual cap always wins over the total cap | `:446` |
| Default values | `TotalSkillCap = 7000` fixed points = 700.0; individual default `1000` = 100.0 | `Server/Skills.cs:996,874`; `Config/PlayerCaps.cfg:9,13` |
| Per-character override | at creation, if `Config.Get("PlayerCaps.SkillCap", 1000.0)/10 != 100.0` every skill's `Cap` is set from that config value | `Scripts/Misc/CharacterCreation.cs:211-217` |

**ModernUO difference:** the reduction uses `skills.Total / (double)skills.Cap >= Utility.RandomDouble()` (no integer truncation, so the roll really is `Total/Cap`), and the cap gate is `skills.Total < skills.Cap` — so ModernUO can overshoot the total cap by up to `toGain-1` fixed points. `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:259-271,278`.

---

### 3.5 `SkillLock`

```csharp
public enum SkillLock : byte { Up = 0, Down = 1, Locked = 2 }   // Server/Skills.cs:21-26
```

| Aspect | Detail | Source |
|---|---|---|
| Client → server packet | `0x3A`, handler `ChangeSkillLock`: `state.Mobile.Skills[pvSrc.ReadInt16()].SetLockNoRelay((SkillLock)pvSrc.ReadByte())` | `Server/Network/PacketHandlers.cs:83,1223-1231` |
| `SetLockNoRelay` | ignores values `< Up` or `> Locked`, sets `m_Lock` **without** invalidating/relaying | `Server/Skills.cs:183-191` |
| Public `Lock` property | **get-only** — only `SetLockNoRelay` can change it | `Server/Skills.cs:268-269` |
| Server → client: full list | `SkillUpdate` packet `0x3A`, type byte `0x02` ("absolute, capped"), per skill: `id+1` (ushort), `NonRacialValue*10`, `BaseFixedPoint`, `Lock`, `CapFixedPoint` | `Server/Network/Packets.cs:2521-2555` |
| Server → client: single skill | `SkillChange` `0x3A`, type `0xDF` ("delta, capped"), same fields but `SkillID` (no +1) | `Server/Network/Packets.cs:2566-2596` |
| When sent | `Skills.OnSkillChange` sends `SkillChange` + `MobileDelta.Skills` on every base/cap change | `Server/Skills.cs:1075-1097` |
| When the whole list is sent | `Mobile.OnSkillsQuery` (client query `0x34`, sub-type `0x05`) | `Server/Mobile.cs:12412-12418`, `Server/Network/PacketHandlers.cs:2317-2321` |
| Client parse | ClassicUO `Handler.Add(0x3A, UpdateSkills)`; `type == 0x02` ⇒ `id--`; `Lock locked = (Lock)p.ReadUInt8()` | `ClassicUO:src/ClassicUO.Client/Network/PacketHandlers.cs:217,1921-2017` |
| Client → server lock change | ClassicUO `GameActions.ChangeSkillLockStatus` sends `0x3A` with `skillindex` + `lockstate` | `ClassicUO:src/ClassicUO.Client/Game/GameActions.cs:575`, `Network/OutgoingPackets.cs:791-805` |
| Persistence | lock serialized only when `!= SkillLock.Up` (flag `0x4`); default is `Up` | `Server/Skills.cs:213-216,240-243,125` |
| Sanity check on load | `if (m_Lock < SkillLock.Up || m_Lock > SkillLock.Locked) { Console.WriteLine("Bad skill lock -> …"); m_Lock = SkillLock.Up; }` | `Server/Skills.cs:167-171` |
| Staff gump icons | `Up` = `0x983`, `Down` = `0x985`, `Locked` = `0x82C` | `Scripts/Gumps/SkillsGump.cs:278-299` |
| Staff gump cycling | Up → Down → Locked → Up, **game-master access only**; non-staff get "You may not change that." | `Scripts/Gumps/SkillsGump.cs:385-404` |

**Behavioural consequences of the lock:**

| Lock | Effect | Source |
|---|---|---|
| `Up` | required for any skill gain (`skill.Lock == SkillLock.Up` in `Gain`) **and** required for the stat-gain branch to run at all | `SkillCheck.cs:376,460` |
| `Down` | never gains; is the only lock that `CheckReduceSkill` may drain; also required for `CanLower` (stat drain) | `SkillCheck.cs:490`, `:571-575` |
| `Locked` | neither gains nor drains; blocks the corresponding stat from raising (stat locks, `StatLockType`, `Server/Mobile.cs:372-377`) | `SkillCheck.cs:376,490,559-562` |
| Alacrity / transcendence | both refuse to work unless `Lock == SkillLock.Up` | `ScrollofAlacrity.cs:110`, `ScrollofTranscendence.cs:120` |
| Repair system | force-sets `Tinkering` to `SkillLock.Locked` | `Scripts/Services/Craft/Core/Repair.cs:139,718` |
| Teaching (pet/player) | a pupil must be `Up`; teaching consumes points from the teacher's `Down`-locked skills | `Scripts/Mobiles/Normal/BaseCreature.cs:4323-4397` |

---

### 3.6 Anti-macro system

```csharp
public static TimeSpan AntiMacroExpire = TimeSpan.FromMinutes(5.0);  // :28  remember targets/locations for 5 min
public const int Allowance = 3;                                      // :33  uses of the same location/target
private const int LocationSize = 4;                                  // :38  location grid cell edge, in tiles
_AntiMacroCode = Config.Get("PlayerCaps.EnableAntiMacro", false);   // :44  DEFAULT = false (OFF)
```

| Constant | Value | Source |
|---|---|---|
| `AntiMacroExpire` | `TimeSpan.FromMinutes(5.0)` | `ServUO:Scripts/Misc/SkillCheck.cs:28` |
| `Allowance` | `3` (const int) | `:33` |
| `LocationSize` | `4` (private const int) | `:38` |
| Master switch | `PlayerCaps.EnableAntiMacro`, code default **`false`**, shipped cfg `False` | `:44`, `Config/PlayerCaps.cfg:63` |
| Config comment claim | "If left to default value, this will be true if the ML era flag is not on." — **the code does not implement this**; the literal default passed to `Config.Get` is `false` | `Config/PlayerCaps.cfg:61-63` vs `:44` |

**Location-key arithmetic** (`:157`, `:175`, `:200`):

```csharp
new Point2D(from.Location.X / LocationSize, from.Location.Y / LocationSize)   // integer division
// LocationSize = 4  →  a 4x4-tile grid cell, e.g. (1234,5678) → (308,1419)
```

`Point2D` is a struct with value `Equals`/`GetHashCode` (`Server/Geometry.cs:78-99`), so a `Hashtable` keyed by it compares by cell. Target-based skills pass the **target object** instead (`Mobile`/`Item` reference identity — neither overrides `Equals`/`GetHashCode`).

**Target-key path** — `AllowGain` → `((PlayerMobile)from).AntiMacroCheck(skill, obj)` (`:346-347`), where `obj` is the `Point2D` for location checks or the raw target for `CheckTargetSkill`:

```csharp
public bool AntiMacroCheck(Skill skill, object obj) {                     // PlayerMobile.cs:4441
    if (obj == null || m_AntiMacroTable == null || IsStaff()) return true; // :4443-4446  staff & null-object bypass
    Hashtable tbl = (Hashtable)m_AntiMacroTable[skill];                    // :4448  outer key = Skill object
    if (tbl == null) m_AntiMacroTable[skill] = tbl = new Hashtable();      // :4449-4452
    CountAndTimeStamp count = (CountAndTimeStamp)tbl[obj];                 // :4454  inner key = location/target
    if (count != null) {
        if (count.TimeStamp + SkillCheck.AntiMacroExpire <= DateTime.UtcNow) { count.Count = 1; return true; } // :4457-4461 expired → reset to 1
        else { ++count.Count; return count.Count <= SkillCheck.Allowance; }  // :4464-4472  allow while count <= 3
    } else { tbl[obj] = count = new CountAndTimeStamp(); count.Count = 1; return true; } // :4477-4480
}
```

`CountAndTimeStamp` is a private nested class whose `Count` setter also refreshes `m_Stamp` to `DateTime.UtcNow` (`Scripts/Mobiles/PlayerMobile.cs:206-222`) — so the 5-minute window is measured from the **last** use, not the first.

Table cleanup: on serialize, entries older than `AntiMacroExpire` are removed from every inner table (`PlayerMobile.cs:4946-4964`).

**What happens when the allowance is used up:** 4th use of the same `(skill, location)` (or `(skill, target)`) within 5 minutes ⇒ `AntiMacroCheck` returns `false` ⇒ `AllowGain` returns `false` ⇒ the `if (AllowGain(...))` block in `CheckSkill` is skipped ⇒ **no gain attempt, and no player-visible message**. `EventSink.InvokeSkillCheck` still fires with `success` (`:256`). The only messages anywhere near this path are `500118` ("You must wait a few moments to use another skill.") and `500014` ("That skill cannot be used directly."), which come from `SendSkillMessage` / `Skills.UseSkill` — **not** from the anti-macro path. [SRC] for the silence; a claim that OSI printed something here is `[UNVERIFIED]` (would require live-shard packet capture).

**Full 58-entry `UseAntiMacro[]` table** (`SkillCheck.cs:59-123`; rows 0-54 are on lines 62-116 consecutively, then the `#region Stygian Abyss` block puts rows 55/56/57 on lines 119/120/121):

| id | Skill | UseAntiMacro | line | id | Skill | UseAntiMacro | line |
|---|---|---|---|---|---|---|---|
| 0 | Alchemy | `false` | 62 | 29 | Musicianship | `true` | 91 |
| 1 | Anatomy | `true` | 63 | 30 | Poisoning | `true` | 92 |
| 2 | Animal Lore | `true` | 64 | 31 | Archery | `false` | 93 |
| 3 | Item Identification | `true` | 65 | 32 | Spirit Speak | `true` | 94 |
| 4 | Arms Lore | `true` | 66 | 33 | Stealing | `true` | 95 |
| 5 | Parrying | `false` | 67 | 34 | Tailoring | `false` | 96 |
| 6 | Begging | `true` | 68 | 35 | Animal Taming | `true` | 97 |
| 7 | Blacksmithy | `false` | 69 | 36 | Taste Identification | `true` | 98 |
| 8 | Bowcraft/Fletching | `false` | 70 | 37 | Tinkering | `false` | 99 |
| 9 | Peacemaking | `true` | 71 | 38 | Tracking | `true` | 100 |
| 10 | Camping | `true` | 72 | 39 | Veterinary | `true` | 101 |
| 11 | Carpentry | `false` | 73 | 40 | Swordsmanship | `false` | 102 |
| 12 | Cartography | `false` | 74 | 41 | Mace Fighting | `false` | 103 |
| 13 | Cooking | `false` | 75 | 42 | Fencing | `false` | 104 |
| 14 | Detecting Hidden | `true` | 76 | 43 | Wrestling | `false` | 105 |
| 15 | Discordance | `true` | 77 | 44 | Lumberjacking | `true` | 106 |
| 16 | Evaluating Intelligence | `true` | 78 | 45 | Mining | `true` | 107 |
| 17 | Healing | `true` | 79 | 46 | Meditation | `true` | 108 |
| 18 | Fishing | `true` | 80 | 47 | Stealth | `true` | 109 |
| 19 | Forensic Evaluation | `true` | 81 | 48 | Remove Trap | `true` | 110 |
| 20 | Herding | `true` | 82 | 49 | Necromancy | `true` | 111 |
| 21 | Hiding | `true` | 83 | 50 | Focus | `false` | 112 |
| 22 | Provocation | `true` | 84 | 51 | Chivalry | `true` | 113 |
| 23 | Inscription | `false` | 85 | 52 | Bushido | `true` | 114 |
| 24 | Lockpicking | `true` | 86 | 53 | Ninjitsu | `true` | 115 |
| 25 | Magery | `true` | 87 | 54 | Spellweaving | `true` | 116 |
| 26 | Resisting Spells | `true` | 88 | 55 | Mysticism | `true` | 119 |
| 27 | Tactics | `false` | 89 | 56 | Imbuing | `true` | 120 |
| 28 | Snooping | `true` | 90 | 57 | Throwing | `false` | 121 |

Indexing is `UseAntiMacro[skill.Info.SkillID]` — a raw array index, so the table must have exactly 58 entries or the shard throws. Totals: **40 `true`, 18 `false`**. [SRC]

**Gargoyle race gates** live in the same `AllowGain` (`:339-343`), inside `if (from is PlayerMobile)`: `Archery` is refused for gargoyles, `Throwing` is refused for non-gargoyles — i.e. a gargoyle cannot gain Archery and a human/elf cannot gain Throwing. `[ERA]` SA (2009) introduced Throwing for gargoyles (`SkillInfo.Table` comment `// Throwing = 57` in the SA region, `:118-122`).

**ModernUO differences:** anti-macro lives in `ModernUO:Projects/UOContent/Skills/AntiMacroSystem.cs`; settings come from `Configuration/antimacro.json` (auto-written on first run, `:84-105`) with defaults `Enabled = false`, `Allowance = 3`, **`LocationSize = 5`** (not 4), `Expire = 5 min`, same 58-bit skill mask (`:16-76`). Its counter increments **before** the comparison, so only **2** successful gains per location per window instead of 3: `if (!exists || expired || _count < Allowance) return true; return false;` (`:242-248`). Reference-equality keys become a `Dictionary<(Skill, object), …>` (`:229`). ModernUO keeps the gargoyle gates out of the gain path (only character creation restricts them: `Projects/UOContent/Engines/Character Creation/CharacterCreation.cs:451-452`).

---

### 3.7 GGS — Guaranteed Gain System

```csharp
public static bool GGSActive { get { return !Siege.SiegeShard; } }   // :40

private static bool CheckGGS(Mobile from, Skill skill) {              // :774
    if (!GGSActive) return false;                                     // :776-777
    if (from is PlayerMobile && skill.NextGGSGain < DateTime.UtcNow) return true;  // :779-782
    return false;
}

public static void UpdateGGS(Mobile from, Skill skill) {              // :787
    if (!GGSActive) return;                                           // :789-790
    var list   = (int)Math.Min(GGSTable.Length - 1, skill.Base / 5);    // :792
    var column = from.Skills.Total >= 7000 ? 2 : from.Skills.Total >= 3500 ? 1 : 0;  // :793
    skill.NextGGSGain = DateTime.UtcNow + TimeSpan.FromMinutes(GGSTable[list][column]); // :795
}
```

| Rule | Exact behaviour | Source |
|---|---|---|
| Active? | `GGSActive == !Siege.SiegeShard`; `Siege.IsSiege` config default `false` | `:40`, `Scripts/Misc/Siege.cs:18`, `Config/Siege.cfg:3` |
| Row selection | `(int)Math.Min(23, skill.Base / 5)` — `Math.Min(int,double)` so this is `floor(Base/5)` capped at 23 ⇒ **row `r` covers `Base ∈ [5r, 5r+5)`**, i.e. 5r … 5r+4.9 | `:792` |
| Column selection | `Total >= 7000` → col 2; else `Total >= 3500` → col 1; else col 0. `Total` is in fixed points ⇒ thresholds are **350.0 and 700.0 displayed skill** | `:793` |
| Timer value | `GGSTable[row][col]` **minutes** | `:795` |
| Timestamp update point | only after a real skill point was granted, only for `PlayerMobile`, and it reads `skill.Base` **after** the increment | `:450-451`, `:446` |
| Guarantee trigger | `CheckGGS` is the 3rd operand of the `||` chain in `CheckSkill`, so GGS is consulted **only when the random roll failed** | `:250` |
| GGS gain amount | unchanged — the normal `Gain()` path applies (§3.3), so 0.1 / 1-4 / 2-5 etc. | `:250-253` |
| Persistence | `Skill.NextGGSGain` is a `DateTime` auto-property; serialized with flag `0x10`, read back at version bit `0x10` | `Server/Skills.cs:278-283,157-160,223-226,250-253` |
| Fresh-character artefact | neither `Skill` constructor sets `NextGGSGain`, so it defaults to `DateTime.MinValue` ⇒ `CheckGGS` returns **true** for every skill that has never gained. The first failed gain roll after `Base >= 10.0` therefore always succeeds, then `UpdateGGS` installs the real timer | `Server/Skills.cs:174-181,104-172` + `SkillCheck.cs:779-782` |
| Non-players | never: the `from is PlayerMobile` test excludes creatures | `:779` |

**Full `GGSTable`** — 24 rows × 3 columns, verbatim, `SkillCheck.cs:798-806`:

| Row | Skill band (`Base`) | col0: Total < 350.0 | col1: Total ≥ 350.0 | col2: Total ≥ 700.0 |
|---|---|---|---|---|
| 0 | 0.0 – 4.9 | 1 | 3 | 5 |
| 1 | 5.0 – 9.9 | 4 | 10 | 18 |
| 2 | 10.0 – 14.9 | 7 | 17 | 30 |
| 3 | 15.0 – 19.9 | 9 | 24 | 44 |
| 4 | 20.0 – 24.9 | 12 | 31 | 57 |
| 5 | 25.0 – 29.9 | 14 | 38 | 90 |
| 6 | 30.0 – 34.9 | 17 | 45 | 84 |
| 7 | 35.0 – 39.9 | 20 | 52 | 96 |
| 8 | 40.0 – 44.9 | 23 | 60 | 106 |
| 9 | 45.0 – 49.9 | 25 | 66 | 120 |
| 10 | 50.0 – 54.9 | 27 | 72 | 138 |
| 11 | 55.0 – 59.9 | 33 | 90 | 162 |
| 12 | 60.0 – 64.9 | 55 | 150 | 264 |
| 13 | 65.0 – 69.9 | 78 | 216 | 390 |
| 14 | 70.0 – 74.9 | 114 | 294 | 540 |
| 15 | 75.0 – 79.9 | 144 | 384 | 708 |
| 16 | 80.0 – 84.9 | 180 | 492 | 900 |
| 17 | 85.0 – 89.9 | 228 | 606 | 1116 |
| 18 | 90.0 – 94.9 | 276 | 744 | 1356 |
| 19 | 95.0 – 99.9 | 336 | 894 | 1620 |
| 20 | 100.0 – 104.9 | 396 | 1056 | 1920 |
| 21 | 105.0 – 109.9 | 468 | 1242 | 2280 |
| 22 | 110.0 – 114.9 | 540 | 1440 | 2580 |
| 23 | 115.0 – 120.0 (power-scroll max) | 618 | 1662 | 3060 |

All values are **minutes**. Notes: row 6 col2 (`84`) is **lower than** row 5 col2 (`90`) — a non-monotonic literal in the source, reproduced verbatim, not a transcription error. All three columns are monotonic increasing everywhere else. Rows 20-23 are only reachable with power scrolls (individual cap > 100.0).

**ModernUO:** GGS does **not exist**. Grepping the whole `Projects/` tree for `GGSTable`, `NextGGSGain`, `UpdateGGS`, `CheckGGS`, `GGSActive`, and `guaranteedGain` returns **zero matches**; `Skill` has no GGS field (`ModernUO:Projects/Server/Skills.cs:86-393`). Equivalently: guaranteed-gain behaviour must be re-implemented from the ServUO table for a faithful clone.

---

### 3.8 Stat gain

Constants and configuration (`SkillCheck.cs:17-57`):

| Constant | Default | Config key | Source |
|---|---|---|---|
| `_StatGainDelay` | `15` min, then **overwritten to 0.5 s** unless the enable-flag is set | `PlayerCaps.PlayerStatTimeDelay` + `PlayerCaps.EnablePlayerStatTimeDelay` (`false`) | `:46,52-53` |
| `_PetStatGainDelay` | `5` min, then **0.5 s** unless the enable-flag is set | `PlayerCaps.PetStatTimeDelay` + `PlayerCaps.EnablePetStatTimeDelay` (`false`) | `:47,55-56` |
| `_PlayerChanceToGainStats` | `5` (⇒ `/100.0` = **5 %**) | `PlayerCaps.PlayerChanceToGainStats` | `:49,510` |
| `_PetChanceToGainStats` | `5` (⇒ **5 %**) | `PlayerCaps.PetChanceToGainStats` | `:50,506` |
| Enable flags in shipped cfg | `EnablePlayerStatTimeDelay=false`, `EnablePetStatTimeDelay=false` ⇒ delays are **0.5 s** by default | — | `Config/PlayerCaps.cfg:45,54` |
| One-shot forced delay | `if (!Config.Get("PlayerCaps.EnablePlayerStatTimeDelay", false)) _StatGainDelay = TimeSpan.FromSeconds(0.5);` | — | `:52-53` |

**Two mutually exclusive stat-gain paths** inside `Gain()` (`:460-481`):

```csharp
if (skill.Lock == SkillLock.Up && (!Siege.SiegeShard || !(from is PlayerMobile) || Siege.CanGainStat((PlayerMobile)from)))
{
    var info = skill.Info;
    if (!Core.ML) {                       // :466  "Old gain mechanic"
        var scalar = 1.0;                                                  // :468
        if (from.StrLock == StatLockType.Up && (info.StrGain / 33.3) * scalar > Utility.RandomDouble())
            GainStat(from, Stat.Str);                                      // :470-471
        else if (from.DexLock == StatLockType.Up && (info.DexGain / 33.3) * scalar > Utility.RandomDouble())
            GainStat(from, Stat.Dex);                                      // :472-473
        else if (from.IntLock == StatLockType.Up && (info.IntGain / 33.3) * scalar > Utility.RandomDouble())
            GainStat(from, Stat.Int);                                      // :474-475
    } else TryStatGain(info, from);                                        // :477-480
}
```

| Path | Era | Chance per stat | Per skill-gain call | Source |
|---|---|---|---|---|
| Legacy | `!Core.ML` (pre-Mondain's Legacy) | `info.XxxGain / 33.3` independently per stat, gated by that stat's `StatLockType.Up` | `else if` chain ⇒ **at most one** stat per call, evaluated Str → Dex → Int | `:466-476` |
| Modern | `Core.ML` | flat **5 %** (`_PlayerChanceToGainStats/100.0` or `_PetChanceToGainStats/100.0`) | at most one stat; 75/25 split | `:499-564` |

`TryStatGain` (`:499-564`) in full detail:

| Step | Behaviour | Source |
|---|---|---|
| Chance roll | `if (Utility.RandomDouble() >= chance) return;` — `chance = _PetChanceToGainStats/100.0` for **controlled** creatures, else `_PlayerChanceToGainStats/100.0` | `:504-516` |
| Lock lookup | `primaryLock` / `secondaryLock` initialised to `StatLockType.Locked` and only overwritten by a `switch` on `info.Primary` / `info.Secondary` (Str/Dex/Int) | `:519-546` |
| Both up | `if (primaryLock == Up && secondaryLock == Up) { if (Utility.Random(4) == 0) GainStat(Secondary) else GainStat(Primary); }` ⇒ **25 % secondary / 75 % primary** | `:550-556` |
| Only primary up | `GainStat(Primary)` | `:559-560` |
| Only secondary up | `GainStat(Secondary)` | `:561-562` |
| Neither up | nothing (comment: "Will not do anything if neither are selected to gain") | `:557-563` |

`GainStat` → `CheckStatTimer` (`:719-772`) — **per-stat timestamps**:

```csharp
public static void GainStat(Mobile from, Stat stat) { if (!CheckStatTimer(from, stat)) return; IncreaseStat(from, stat); }  // :719-725
// CheckStatTimer, Str branch (:731-743):
if (from is BaseCreature && ((BaseCreature)from).Controlled) { if (from.LastStrGain + _PetStatGainDelay >= DateTime.UtcNow) return false; }
else if (from.LastStrGain + _StatGainDelay >= DateTime.UtcNow) return false;
from.LastStrGain = DateTime.UtcNow; return true;
// Dex :744-756 uses LastDexGain, Int :757-769 uses LastIntGain — identical structure
```

`LastStrGain` / `LastDexGain` / `LastIntGain` are `DateTime` properties on `Mobile` (`Server/Mobile.cs:9388-9394`), serialized with `WriteDeltaTime` (`:6414-6416`) and read back at `:5870-5872`; `LastStatGain` (setter sets all three) at `:9398-9419`.

`IncreaseStat` and the **at-total-cap drain rule** (`:629-717`):

```csharp
bool atTotalCap = from.RawStatTotal >= from.StatCap;                       // :631
case Stat.Str:
  if (CanRaise(from, Stat.Str, atTotalCap)) {                              // :637
      if (atTotalCap) {                                                    // :639
          if (CanLower(from, Stat.Dex) && (from.RawDex < from.RawInt || !CanLower(from, Stat.Int))) --from.RawDex;  // :641-642
          else if (CanLower(from, Stat.Int)) --from.RawInt;                // :643-644
      }
      ++from.RawStr;                                                       // :647
      ... HitsMaxSeed++ for creatures, Siege.IncreaseStat for siege players ...   // :649-657
  }
// Dex :662-688 drains the lower of Str/Int;  Int :689-716 drains the lower of Str/Dex
```

| Rule | Exact behaviour | Source |
|---|---|---|
| `atTotalCap` | deterministic: `from.RawStatTotal >= from.StatCap` | `:631` |
| `CanRaise(from, stat, atTotalCap)` | first `stat < stat cap`; then, if `atTotalCap && from is PlayerMobile`, requires `CanLower` of **one of the other two** stats; **non-players at the cap return `true`** and may exceed `StatCap` | `:581-627` |
| `CanLower(from, stat)` | `stat.Lock == StatLockType.Down && RawXxx > 10` — the stat must be **Down-locked** and above the floor of 10 | `:566-579` |
| Drain choice (Str gain) | drain Dex if `CanLower(Dex) && (RawDex < RawInt || !CanLower(Int))`, else drain Int — i.e. drain the **lower** of the two others; on a tie (`RawDex == RawInt`, both lowerable) the first condition fails and **Int** is drained | `:641-644` |
| Drain choice (Dex gain) | drain Str if `CanLower(Str) && (RawStr < RawInt || !CanLower(Int))`, else drain Int | `:668-671` |
| Drain choice (Int gain) | drain Str if `CanLower(Str) && (RawStr < RawDex || !CanLower(Dex))`, else drain Dex | `:695-698` |
| Swap semantics | exactly 1 point drained, 1 point added per successful call — no partial or multi-point drain | `:641-647` |
| Creature side effects | `HitsMaxSeed++` on Str, `StamMaxSeed++` on Dex, `ManaMaxSeed++` on Int when the seed is `> -1` and below the respective cap | `:649-652,676-679,703-706` |
| Siege | extra `Siege.IncreaseStat(pm)` bookkeeping | `:654-657,681-684,708-711` |
| Per-stat caps | `Mobile.StrCap` / `DexCap` / `IntCap`, defaults **125** each (`PlayerCaps.StrCap/DexCap/IntCap`); `StrMaxCap`/`DexMaxCap`/`IntMaxCap` default **150** and cap the *effective* (equipment-boosted) stat from ML onwards | `Server/Mobile.cs:12747-12786,11129-11134`; `Config/PlayerCaps.cfg:19-34`; `Scripts/Mobiles/PlayerMobile.cs:2004-2050` |
| Total stat cap | `Mobile.StatCap` default **225** (`PlayerCaps.TotalStatCap`); `RawStatTotal = RawStr + RawDex + RawInt` | `Server/Mobile.cs:12725-12744,12801`; `Config/PlayerCaps.cfg:16` |
| Stat lock transmission | setting `StrLock`/`DexLock`/`IntLock` sends `StatLockInfo` packet `0xBF` sub-command `0x19` with a packed byte `StrLock<<4 | DexLock<<2 | IntLock` | `Server/Mobile.cs:1783-1840`, `Server/Network/Packets.cs:478-507` |
| Client → server stat lock | extended packet `0xBF` sub-command `0x1A` → `StatLockChange` | `Server/Network/PacketHandlers.cs:152,2121-2148` |
| Siege stat gating | stat gain requires `Siege.CanGainStat` (max `StatsPerDay = 15`); `MinutesPerGain` returns 0 below 70.0, else 5 / 8 / 12 / 15 minutes for ≤79.9 / ≤89.9 / ≤99.9 / above | `Scripts/Misc/Siege.cs:22,318-352,354-379,381-389` |
| Stat cap raise item | `StatCapScroll` uses `PlayerCaps.TotalStatCap` as its base | `Scripts/Items/Consumables/StatScroll.cs:8` |

**ModernUO differences** (`ModernUO:Projects/UOContent/Skills/SkillCheck.cs`):

| Aspect | ServUO | ModernUO | Source |
|---|---|---|---|
| Where | `TryStatGain()` called from `Gain()` when `Core.ML` | `Gain()` inline block, gated by `_usePub45StatGain` (default `Core.ML`) | `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:284-309` |
| Chance | `5 %`, `PetChanceToGainStats` separate | `0.05 * _statGainChanceMultiplier` (config `stats.gainChanceMultiplier`, default `1.0`); **no** separate pet chance | `:24,300` |
| Split | `Random(4) == 0` → secondary, else primary (75/25) | `primaryStatLock is Up && _primaryStatGainChance > RandomDouble()` → primary, else secondary; `stats.primaryStatGainChance` default **0.75** | `:25,303-305` |
| Delay | 15 min (config) but forced to 0.5 s by default | `stats.gainDelay` default `Core.ML ? 0.05 min (3 s) : 10 min`; `stats.petGainDelay` default 5 min | `:26-27` |
| Legacy path | pre-ML `info.XxxGain / 33.3` **else-if** chain called from `Gain()` | `LegacyGain()` called from `CheckSkill` **on success only**, three independent `if`s with `info.XxxGain > 0` guards (so up to 3 stats per call) | `:152-155,312-328` |
| Per-stat caps | `StrCap`/`DexCap`/`IntCap` per mobile, default 125 | single `_statMax` = config `stats.statMax`, default `Core.LBR ? 125 : 100`; also enforced with `Math.Min(..., _statMax)` | `:23,365-367,394` |
| Total-cap rule | `CanRaise` requires a drainable other stat; drain uses the deterministic `RawStatTotal >= StatCap` | `CanRaise` returns `false` outright when `RawStatTotal >= StatCap` (non-controlled); `IncreaseStat` drains **first** (so the total can drop below the cap before the raise test), and the drain also fires on a *random* atrophy roll `RawStatTotal / StatCap >= RandomDouble()` even when not at cap | `:352-370,372-442,501-503` |
| Stat cap | 225 default | 225 default | `ModernUO:Projects/Server/Mobiles/Mobile.cs:7826,6436` |

---

### 3.9 Full 58-row `SkillInfo.Table` (`Server/Skills.cs:594-654`)

Column notes: `StrScale`/`DexScale`/`IntScale` are the **raw constructor literals** — the constructor stores `StrScale = strScale / 100.0` (`Server/Skills.cs:545-547`), so raw `5.0` ⇒ effective scale `0.05`. `StatTotal = strScale + dexScale + intScale` using the **raw** values (`:558`), e.g. Alchemy `0+5+5 = 10`. `GainFactor` is **1.0 for all 58 rows** (`:596-653`). Line numbers are `596 + id`. [SRC]

| id | Skill | Primary | Secondary | StrGain | DexGain | IntGain | StrScale | DexScale | IntScale | GainFactor | line | mastery |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Alchemy | Int | Dex | 0.0 | 0.5 | 0.5 | 0.0 | 5.0 | 5.0 | 1.0 | 596 | — |
| 1 | Anatomy | Int | Str | 0.15 | 0.15 | 0.7 | 0.0 | 0.0 | 0.0 | 1.0 | 597 | — |
| 2 | Animal Lore | Int | Str | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 598 | — |
| 3 | Item Identification | Int | Dex | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 599 | — |
| 4 | Arms Lore | Int | Str | 0.75 | 0.15 | 0.1 | 0.0 | 0.0 | 0.0 | 1.0 | 600 | — |
| 5 | Parrying | Dex | Str | 0.75 | 0.25 | 0.0 | 7.5 | 2.5 | 0.0 | 1.0 | 601 | ✔ |
| 6 | Begging | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 602 | — |
| 7 | Blacksmithy | Str | Dex | 1.0 | 0.0 | 0.0 | 10.0 | 0.0 | 0.0 | 1.0 | 603 | — |
| 8 | Bowcraft/Fletching | Dex | Str | 0.6 | 1.6 | 0.0 | 6.0 | 16.0 | 0.0 | 1.0 | 604 | — |
| 9 | Peacemaking | Int | Dex | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 605 | ✔ |
| 10 | Camping | Dex | Int | 2.0 | 1.5 | 1.5 | 20.0 | 15.0 | 15.0 | 1.0 | 606 | — |
| 11 | Carpentry | Str | Dex | 2.0 | 0.5 | 0.0 | 20.0 | 5.0 | 0.0 | 1.0 | 607 | — |
| 12 | Cartography | Int | Dex | 0.0 | 0.75 | 0.75 | 0.0 | 7.5 | 7.5 | 1.0 | 608 | — |
| 13 | Cooking | Int | Dex | 0.0 | 2.0 | 3.0 | 0.0 | 20.0 | 30.0 | 1.0 | 609 | — |
| 14 | Detecting Hidden | Int | Dex | 0.0 | 0.4 | 0.6 | 0.0 | 0.0 | 0.0 | 1.0 | 610 | — |
| 15 | Discordance | Dex | Int | 0.0 | 0.25 | 0.25 | 0.0 | 2.5 | 2.5 | 1.0 | 611 | ✔ |
| 16 | Evaluating Intelligence | Int | Str | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 612 | — |
| 17 | Healing | Int | Dex | 0.6 | 0.6 | 0.8 | 6.0 | 6.0 | 8.0 | 1.0 | 613 | — |
| 18 | Fishing | Dex | Str | 0.5 | 0.5 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 614 | — |
| 19 | Forensic Evaluation | Int | Dex | 0.0 | 0.2 | 0.8 | 0.0 | 0.0 | 0.0 | 1.0 | 615 | — |
| 20 | Herding | Int | Dex | 1.625 | 0.625 | 0.25 | 16.25 | 6.25 | 2.5 | 1.0 | 616 | — |
| 21 | Hiding | Dex | Int | 0.0 | 0.8 | 0.2 | 0.0 | 0.0 | 0.0 | 1.0 | 617 | — |
| 22 | Provocation | Int | Dex | 0.0 | 0.45 | 0.05 | 0.0 | 4.5 | 0.5 | 1.0 | 618 | ✔ |
| 23 | Inscription | Int | Dex | 0.0 | 0.2 | 0.8 | 0.0 | 2.0 | 8.0 | 1.0 | 619 | — |
| 24 | Lockpicking | Dex | Int | 0.0 | 2.0 | 0.0 | 0.0 | 25.0 | 0.0 | 1.0 | 620 | — |
| 25 | Magery | Int | Str | 0.0 | 0.0 | 1.5 | 0.0 | 0.0 | 15.0 | 1.0 | 621 | ✔ |
| 26 | Resisting Spells | Str | Dex | 0.25 | 0.25 | 0.5 | 0.0 | 0.0 | 0.0 | 1.0 | 622 | — |
| 27 | Tactics | Str | Dex | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 623 | — |
| 28 | Snooping | Dex | Int | 0.0 | 2.5 | 0.0 | 0.0 | 25.0 | 0.0 | 1.0 | 624 | — |
| 29 | Musicianship | Dex | Int | 0.0 | 0.8 | 0.2 | 0.0 | 0.0 | 0.0 | 1.0 | 625 | — |
| 30 | Poisoning | Int | Dex | 0.0 | 0.4 | 1.6 | 0.0 | 4.0 | 16.0 | 1.0 | 626 | ✔ |
| 31 | Archery | Dex | Str | 0.25 | 0.75 | 0.0 | 2.5 | 7.5 | 0.0 | 1.0 | 627 | ✔ |
| 32 | Spirit Speak | Int | Str | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 628 | (UseWhileCasting) |
| 33 | Stealing | Dex | Int | 0.0 | 1.0 | 0.0 | 0.0 | 10.0 | 0.0 | 1.0 | 629 | — |
| 34 | Tailoring | Dex | Int | 0.38 | 1.63 | 0.5 | 3.75 | 16.25 | 5.0 | 1.0 | 630 | — |
| 35 | Animal Taming | Str | Int | 1.4 | 0.2 | 0.4 | 14.0 | 2.0 | 4.0 | 1.0 | 631 | ✔ |
| 36 | Taste Identification | Int | Str | 0.2 | 0.0 | 0.8 | 0.0 | 0.0 | 0.0 | 1.0 | 632 | — |
| 37 | Tinkering | Dex | Int | 0.5 | 0.2 | 0.3 | 5.0 | 2.0 | 3.0 | 1.0 | 633 | — |
| 38 | Tracking | Int | Dex | 0.0 | 1.25 | 1.25 | 0.0 | 12.5 | 12.5 | 1.0 | 634 | — |
| 39 | Veterinary | Int | Dex | 0.8 | 0.4 | 0.8 | 8.0 | 4.0 | 8.0 | 1.0 | 635 | — |
| 40 | Swordsmanship | Str | Dex | 0.75 | 0.25 | 0.0 | 7.5 | 2.5 | 0.0 | 1.0 | 636 | ✔ |
| 41 | Mace Fighting | Str | Dex | 0.9 | 0.1 | 0.0 | 9.0 | 1.0 | 0.0 | 1.0 | 637 | ✔ |
| 42 | Fencing | Dex | Str | 0.45 | 0.55 | 0.0 | 4.5 | 5.5 | 0.0 | 1.0 | 638 | ✔ |
| 43 | Wrestling | Str | Dex | 0.9 | 0.1 | 0.0 | 9.0 | 1.0 | 0.0 | 1.0 | 639 | ✔ |
| 44 | Lumberjacking | Str | Dex | 2.0 | 0.0 | 0.0 | 20.0 | 0.0 | 0.0 | 1.0 | 640 | — |
| 45 | Mining | Str | Dex | 2.0 | 0.0 | 0.0 | 20.0 | 0.0 | 0.0 | 1.0 | 641 | — |
| 46 | Meditation | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 642 | — |
| 47 | Stealth | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 643 | — |
| 48 | Remove Trap | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 644 | — |
| 49 | Necromancy | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 645 | ✔ |
| 50 | Focus | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 646 | — |
| 51 | Chivalry | Str | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 647 | ✔ |
| 52 | Bushido | Str | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 648 | ✔ |
| 53 | Ninjitsu | Dex | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 649 | ✔ |
| 54 | Spellweaving | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 650 | ✔ |
| 55 | Mysticism | Str | Int | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 651 | ✔ |
| 56 | Imbuing | Int | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 652 | — |
| 57 | Throwing | Dex | Str | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 653 | ✔ |

Skills with **zero in all three gain columns** (no stat influence at all in the legacy path, and only the 5 % flat roll in the ML path with the listed primary/secondary): Begging, Peacemaking, Tactics, Meditation, Stealth, Remove Trap, Necromancy, Focus, Chivalry, Bushido, Ninjitsu, Spellweaving, Mysticism, Imbuing, Throwing.

**ModernUO** loads the same data from JSON, not code: `SkillInfo.Table = JsonConfig.Deserialize<SkillInfo[]>(Path.Combine(Core.BaseDirectory, "Data/skills.json"))` (`ModernUO:Projects/UOContent/Skills/SkillsInfo.cs:135`; model `Projects/Server/Skills.cs:395-452`; data `Distribution/Data/skills.json`, 58 entries lines 1-930). The JSON stores the already-divided scales (e.g. Alchemy `"StrScale": 0.05`) **and** the raw `StatTotal` (e.g. `"StatTotal": 10`) with the same primary/secondary columns. Diffing all 58 rows against ServUO: **identical values except skill 15 Discordance**, where ServUO has `Primary = Dex, Secondary = Int` (`Skills.cs:611`) and ModernUO has `"PrimaryStat": "Int", "SecondaryStat": "Dex"` (`skills.json:255-256`). [SRC]

---

### 3.10 `StrScale` / `DexScale` / `IntScale` and the effective skill value

`Skill.Value` = max(`NonRacialValue`, racial bonus), where `Mobile.GetRacialSkillBonus` supplies e.g. elf/gargoyle bonuses (`Server/Skills.cs:372-389`).

`Skill.NonRacialValue` (`Server/Skills.cs:391-468`), verbatim structure:

```csharp
double baseValue = Base;                                  // :396  fixed-point base / 10
double inv = 100.0 - baseValue;  if (inv < 0.0) inv = 0.0;  // :397-402
inv /= 100.0;                                             // :404   ← normalised 1.0 … 0.0

double statsOffset = ((m_UseStatMods ? Owner.Str  : Owner.RawStr) * Info.StrScale) +   // :406
                     ((m_UseStatMods ? Owner.Dex  : Owner.RawDex) * Info.DexScale) +   // :407
                     ((m_UseStatMods ? Owner.Int  : Owner.RawInt) * Info.IntScale);    // :408
double statTotal = Info.StatTotal * inv;                  // :409
statsOffset *= inv;                                       // :411
if (statsOffset > statTotal) statsOffset = statTotal;     // :413-416

double value = baseValue + statsOffset;                   // :418
Owner.ValidateSkillMods();                                // :420
// relative SkillMods: ObeyCap → bonusObey, else bonusNotObey; absolute mod REPLACES value  // :426-450
value += bonusNotObey;                                    // :452
if (value < Cap) { value += bonusObey; if (value > Cap) value = Cap; }  // :454-462
Owner.MutateSkill(SkillName, ref value);                  // :464
return value;                                             // :466
```

Formula, collapsed:

```
b   = Base                                   (0 … Cap, typically 0 … 1000/10)
inv = max(100 - b, 0) / 100                  (1.0 at b=0 → 0.0 at b>=100)
raw = RawStr*StrScale + RawDex*DexScale + RawInt*IntScale      (scales = literal/100)
off = min(raw, StatTotal) * inv               ← both sides scaled by inv
value = b + off + bonusNotObey  (+ bonusObey while value < Cap, clamped to Cap)
```

**Meaning of the scales:**

| Aspect | Detail | Source |
|---|---|---|
| What the scales do | they convert the mobile's Str/Dex/Int into a *skill bonus*, capped by `StatTotal` (the raw sum of the three literals) | `:406-416` |
| Cap on the bonus | `min(statsOffset, StatTotal) * inv` — so at 100 Str/Dex/Int a skill can receive at most `StatTotal` points, e.g. Blacksmithy raw 10/0/0 ⇒ `Str 100 × 0.10 = 10`, `StatTotal = 10` ⇒ **+10.0 Blacksmithy at 100 Str** | `:409-418`, `:603` |
| Fade-out | every bonus is multiplied by `inv = (100 - Base)/100`, so the stat bonus decays linearly and is **zero at Base ≥ 100.0** | `:397-411` |
| Full example | Blacksmithy Base 50, Str 100, Dex 100: `inv = 0.5`; `raw = 100*0.10 = 10`; `off = min(10, 10) * 0.5 = 5.0`; `value = 55.0` | [DERIVED from SRC] |
| `UseStatMods` | a static toggle (`Skill.UseStatMods`) choosing *effective* Str/Dex/Int over **raw**; grep shows it is **never assigned anywhere** in pub57 ⇒ always `false` ⇒ **raw** stats are used | `Server/Skills.cs:366-368,406-408` |
| Skill mods | absolute (`Relative == false`) mod **replaces** the value outright; relative mods split into obey-cap (`+` only while `value < Cap`, clamped to `Cap`) and non-obey-cap (always added) | `:426-462` |
| Side effect | reading a skill value calls `Mobile.ValidateSkillMods()` (`Server/Mobile.cs:1320-1335`), which **removes** mods whose `CheckCondition()` is false | `:420`, `Server/Mobile.cs:1320-1335` |
| AoS/era switch | `CurrentExpansion.Configure()` calls `AOS.DisableStatInfluences()` whenever `Core.AOS`; that sets `StrScale = DexScale = IntScale = StatTotal = 0.0` for **all 58 rows** ⇒ stat influence is **completely disabled** | `Server/Main.cs:147`, `Scripts/Misc/CurrentExpansion.cs:34-39`, `Scripts/Misc/AOS.cs:36-47` |
| Default expansion | `Config.GetEnum("Expansion.CurrentExpansion", Expansion.EJ)` and shipped `CurrentExpansion=EJ` ⇒ `Core.AOS == true` ⇒ **a stock ServUO pub57 has zero stat influence on skill values** | `Scripts/Misc/CurrentExpansion.cs:13`, `Config/Expansion.cfg:15` |

**ModernUO** uses the same idea with a different factorisation (`ModernUO:Projects/Server/Skills.cs:250-331`):

```
statsOffset = RawStr*StrScale + RawDex*DexScale + RawInt*IntScale      // JSON scales are already /100
inv = 100 - Base                                                        // NOT divided by 100
if (inv <= 0) statsOffset = 0
else { statsOffset *= inv;  if (StatTotal > 0) statsOffset = min(statsOffset, StatTotal*inv); }
value = Base + statsOffset
```

Because ModernUO does not divide `inv` by 100 (it divides in the constructor instead, `Projects/Server/Skills.cs:407-409`) and the JSON `StatTotal` is the raw sum, the two formulations are algebraically equivalent for the shipped data: ServUO `100 Str × 0.10 × 1.0 = +10` vs ModernUO `100 × 0.001 × 100 = +10`. ModernUO has **no** `UseStatMods` toggle (always `RawStr/Dex/Int`) and applies the same `DisableStatInfluences()` zeroing when `Core.AOS` (`ModernUO:Projects/UOContent/Skills/SkillsInfo.cs:137-140`, `Projects/UOContent/Misc/AOS.cs:15-26`). ModernUO also applies `min(statsOffset, StatTotal*inv)` only when `StatTotal > 0`, whereas ServUO always clamps (equivalent when the scales are non-zero). [SRC]

---

### 3.11 Worked numeric examples of `gc` per band

All arithmetic below is `[DERIVED from SRC]` — inputs are the literals in `SkillCheck.cs:261-284`; no value is invented. Assume a player (no pet bonus), `GainFactor = 1.0`, `Skills.Cap = 7000` (700.0), individual `skill.Cap = 1000` (100.0), `chance` from §3.2.

**Band A — mid skill, low total, successful use.** `Total = 3500` (350.0), `Base = 50.0`, `Cap = 100.0`, `chance = 0.5`, `success = true`:

```
T = (7000 - 3500) / 7000 = 0.5000
S = (1000 -  500) / 1000 = 0.5000
(T + S) / 2              = 0.5000
D = (1 - 0.5) * 0.5      = 0.2500
(0.5 + 0.25) / 2         = 0.3750
gc = 0.3750 * 1.0        = 0.3750   → 37.5 % per skill-use attempt
```

**Band B — same, but the use failed and the shard is AoS+ (`Core.AOS == true`, the stock EJ default).** Only `k` changes, `0.5 → 0.0`:

```
D = (1 - 0.5) * 0.0 = 0.0000
gc = (0.5000 + 0.0) / 2 * 1.0 = 0.2500   → 25.0 %
```

**Band C — same failure on a pre-AoS shard (`Core.AOS == false`).** `k = 0.2`:

```
D = (1 - 0.5) * 0.2 = 0.1000
gc = (0.5000 + 0.1000) / 2 = 0.3000   → 30.0 %
```

**Band D — at the 700.0 total cap, high skill.** `Total = 7000`, `Base = 90.0`, `Cap = 100.0`, `chance = 0.5`, `success = true`:

```
T = (7000 - 7000) / 7000 = 0.0000
S = (1000 -  900) / 1000 = 0.1000
(T + S) / 2              = 0.0500
D = (1 - 0.5) * 0.5      = 0.2500
gc = (0.05 + 0.25) / 2   = 0.1500   → 15.0 %
```

**Band E — the 0.01 floor takes over.** `Total = 7000`, `Base = 100.0` (= `Cap`), `chance = 1.0`, `success = true` (this state is normally unreachable because `Gain()` requires `Base < Cap`, but `gc` is still computed):

```
T = 0.0000 ; S = 0.0000 ; (T+S)/2 = 0.0000 ; D = (1-1.0)*0.5 = 0.0000
gc_raw = 0.0000  →  floor  →  gc = 0.0100   → 1.0 %
```

**Band F — controlled pet (the +100 % branch).** Take Band A's `gc = 0.3750` with `from` a controlled `BaseCreature`:

```
gc = 0.3750 ; gc += gc * 1.00 → 0.7500 ; 0.7500 <= 1.00 → gc = 0.7500   → 75.0 %
```

**Band G — the pet bonus hitting the clamp.** `Total = 0`, `Base = 0.0`, `chance = 0.0`. (In practice `Base < 10.0` bypasses `gc` entirely, so this is the formula's ceiling, not a live path):

```
T = 1.0 ; S = 1.0 ; (T+S)/2 = 1.0 ; D = (1-0.0)*0.5 = 0.5
gc = (1.0 + 0.5)/2 = 0.75 ; pet: 0.75*2 = 1.50 → clamp → gc = 1.00   → 100 %
```

**Band H — the bulk/craft-all overload (§3.1b) with `amount` iterations.** `Total = 3500`, `Base = 50.0`, `Cap = 100.0`, normalised difficulty `gains = 0.5`:

```
gc = (7000 - (3500 + 0.5*10)) / 7000 = 3495 / 7000 = 0.49928571
gc += (1000 - (500 + 5))   / 1000    =  495 / 1000 = 0.49500000
     sum = 0.99428571
gc /= 4                              = 0.24857143
gc *= 1.0                            = 0.24857143   → ~24.86 % per iteration
```

**GGS timers for the same states** (minutes, `§3.7`): `Total = 3500, Base = 50.0` ⇒ row `floor(50/5) = 10`, column 1 ⇒ **72 minutes**. `Total = 7000, Base = 90.0` ⇒ row 18, column 2 ⇒ **1356 minutes** (22.6 h). Both `[DERIVED from SRC]` (`SkillCheck.cs:792-795,798-806`).

---

### 3.12 Every `PlayerCaps` (skill/stat-related) config key

Grepped the whole `servuo` tree for `Config.Get("PlayerCaps…`. Complete list, with code default, shipped `Config/PlayerCaps.cfg` value, and meaning:

| Key | Code default | Cfg value | Read at | Meaning |
|---|---|---|---|---|
| `PlayerCaps.TotalSkillCap` | `7000` | `7000` | `Server/Skills.cs:996`; also `Scripts/Services/VeteranRewards/RewardSystem.cs:18`, `Scripts/Services/Reports/Reports.cs:157` | Total skill cap in **fixed points** (700.0). Applied to every new `Skills` instance |
| `PlayerCaps.SkillCap` | `1000.0` (double) | `1000` | `Scripts/Misc/CharacterCreation.cs:211` | Individual skill cap in fixed points, divided by 10 → 100.0; applied to all skills at creation only when ≠ 100.0 |
| `PlayerCaps.TotalStatCap` | `225` | `225` | `Server/Mobile.cs:11128`, `:6103`; `Scripts/Mobiles/Bosses/Harrower/Harrower.cs:12`; `Scripts/Items/Consumables/StatScroll.cs:8` | Total stat cap (Str+Dex+Int) |
| `PlayerCaps.StrCap` | `125` | `125` | `Server/Mobile.cs:11129`, `:6078` | Per-stat cap for raw Str |
| `PlayerCaps.DexCap` | `125` | `125` | `Server/Mobile.cs:11130`, `:6079` | Per-stat cap for raw Dex |
| `PlayerCaps.IntCap` | `125` | `125` | `Server/Mobile.cs:11131`, `:6080` | Per-stat cap for raw Int |
| `PlayerCaps.StrMaxCap` | `150` | `150` | `Server/Mobile.cs:11132`, `:6081` | Cap on **effective** (equipment-boosted) Str, ML+ (`PlayerMobile.cs:2004-2018`) |
| `PlayerCaps.DexMaxCap` | `150` | `150` | `Server/Mobile.cs:11133`, `:6082` | Cap on effective Dex, ML+ |
| `PlayerCaps.IntMaxCap` | `150` | `150` | `Server/Mobile.cs:11134`, `:6083` | Cap on effective Int, ML+ |
| `PlayerCaps.StatCap` | *(not read by any code)* | `125` | — | **Deprecated**; cfg comment says "Deprecated: The individual stat cap" (`PlayerCaps.cfg:40-41`). Dead key |
| `PlayerCaps.EnablePlayerStatTimeDelay` | `false` | `false` | `Scripts/Misc/SkillCheck.cs:52` | If **false**, `_StatGainDelay` is overwritten with `TimeSpan.FromSeconds(0.5)` |
| `PlayerCaps.PlayerStatTimeDelay` | `TimeSpan.FromMinutes(15.0)` | `00:00:15:00` | `Scripts/Misc/SkillCheck.cs:46` | Player stat-gain cooldown; ignored unless the enable-flag above is true |
| `PlayerCaps.EnablePetStatTimeDelay` | `false` | `false` | `Scripts/Misc/SkillCheck.cs:55` | If **false**, `_PetStatGainDelay` becomes 0.5 s |
| `PlayerCaps.PetStatTimeDelay` | `TimeSpan.FromMinutes(5.0)` | `00:00:05:00` | `Scripts/Misc/SkillCheck.cs:47` | Pet stat-gain cooldown; ignored unless enabled |
| `PlayerCaps.PlayerChanceToGainStats` | `5` (int) | `5.0` | `Scripts/Misc/SkillCheck.cs:49` | Percent chance per stat-gain roll, players (`/100.0`) |
| `PlayerCaps.PetChanceToGainStats` | `5` (int) | `5.0` | `Scripts/Misc/SkillCheck.cs:50` | Percent chance per stat-gain roll, controlled pets (`/100.0`) |
| `PlayerCaps.EnableAntiMacro` | `false` | `False` | `Scripts/Misc/SkillCheck.cs:44` | Master switch for the §3.6 anti-macro code |

Adjacent, non-`PlayerCaps` keys that change skill/stat behaviour:

| Key | Default | Read at | Effect |
|---|---|---|---|
| `Expansion.CurrentExpansion` | `Expansion.EJ` | `Scripts/Misc/CurrentExpansion.cs:13` | Drives `Core.AOS/SE/ML/SA/TOL`; `AOS` zeroes all stat scales, `ML` selects the 5 % stat-gain path and the 150 stat max-caps, `SE` makes `BaseCreature.SetSkill` grow `SkillsCap` |
| `Siege.IsSiege` | `false` | `Scripts/Misc/Siege.cs:18` | If true: `GGSActive == false`, per-skill ROT timers, `StatsPerDay = 15` stat cap, no Young status |

[SRC] for all rows.

---

### 3.13 ServUO vs ModernUO — consolidated difference table

Bare `:NNN` ranges in the **Sources** column are **ServUO `Scripts/Misc/SkillCheck.cs`** unless another file is named.

| # | Mechanic | ServUO `pub57` | ModernUO `main` | Sources |
|---|---|---|---|---|
| 1 | Gain formula | `((T+S)/2 + D)/2 * G`, `D = (1-chance)*(success?0.5:AOS?0.0:0.2)` | identical literals and divisors | `SkillCheck.cs:261-284` ↔ `ModernUO …/SkillCheck.cs:126-133` |
| 2 | `gc` floor / pet / clamp | floor 0.01 → pet `×2` → clamp 1.00 | floor 0.01 → pet `×2` → **no explicit 1.00 clamp** (only `gc >= RandomDouble()`), so the clamp is implicit | `:273-281` ↔ `:135-145` |
| 3 | Death/low-skill bypass ordering | `AllowGain` first, then `Base < 10.0 \|\| roll \|\| GGS` | `region.AllowGain` first; `Base < 10.0` gains **regardless** of `AllowGain` (anti-macro skipped below 10.0) | `:248-253` ↔ `:118-124` |
| 4 | Success roll | `Random(100) <= (int)(chance*100)` (+1 %) | `chance >= RandomDouble()` (exact) | `:245` ↔ `:115` |
| 5 | `minSkill >= maxSkill` | the two short-circuits make the degenerate case unreachable: `value < minSkill` → `false`, and `value >= minSkill` implies `value >= maxSkill` → `true`, so the division on `:153` is never reached with `maxSkill <= minSkill` | adds an explicit (redundant) `\|\| minSkill >= maxSkill` → `true`; same observable behaviour | `:147-153` ↔ `:60-70` |
| 6 | Low-skill boost | `toGain == 1 && Base <= 10.0` → `Random(4)+1` | `Base <= 10.0` → `Random(4)+1` (no `toGain == 1` guard) | `:400-401` ↔ `:252-255` |
| 7 | Total-cap gate | `!from.Player \|\| Total + toGain <= Cap` | `!from.Player \|\| Total < Cap` (may overshoot) | `:444` ↔ `:278` |
| 8 | Reduce-skill roll | `Total / Cap` (integer division) `>= RandomDouble()` | `Total / (double)Cap >= RandomDouble()` | `:486` ↔ `:259` |
| 9 | Reduce-skill target | first `Down`-locked skill with `>= toGain` | same, but clamp `Math.Max(…-toGain, 0)` | `:488-495` ↔ `:261-270` |
| 10 | Alacrity multiplier | `toGain = RandomMinMax(2, 5)` (assignment) | `toGain *= RandomMinMax(2, 5)` (multiplicative) | `:417` ↔ `:275` |
| 11 | ML Apprentice quest bonus | `toGain *= RandomMinMax(2, 4)` via `QuestHelper.EnhancedSkill` | absent (`EnhancedSkill` does not exist) | `:404-407` ↔ — |
| 12 | Whispering mastery pet bonus | `toGain = RandomMinMax(2, 5)` with `EnhancedGainChance` % gate | absent from the gain path | `:422-436` ↔ — |
| 13 | Focus-pet exclusion | creatures unless `PetTrainingHelper.Enabled && Controlled` | **all** `BaseCreature` | `:372-374` ↔ `:243-246` |
| 14 | Jail exclusion | inside `Gain()` (`Region.IsPartOf<Jail>`) | via `Region.AllowGain` (`JailRegion` override) | `:366-367` ↔ `UOContent/Systems/JailSystem/JailRegion.cs:23` |
| 15 | Gargoyle Archery/Throwing | refused in `AllowGain` | not in the gain path (creation only) | `:339-343` ↔ `CharacterCreation.cs:451-452` |
| 16 | GGS | 24×3 table, per-skill `NextGGSGain` | **does not exist** | `:774-806` ↔ (0 grep hits) |
| 17 | Anti-macro defaults | `Enabled=false`, `Allowance=3`, `LocationSize=4`, 5 min, code table | `Enabled=false`, `Allowance=3`, **`LocationSize=5`**, 5 min, `Configuration/antimacro.json` | `:28-44` ↔ `AntiMacroSystem.cs:94-101` |
| 18 | Anti-macro allowance | 3 successful uses per `(skill,key)` per window | **2** (counter incremented before the test) | `PlayerMobile.cs:4454-4481` ↔ `AntiMacroSystem.cs:232-249` |
| 19 | Stat-gain probability | `5 %` (player) / `5 %` (pet), `Random(4)==0` secondary | `0.05 * multiplier`, `primaryStatGainChance = 0.75` | `:499-556` ↔ `:284-309` |
| 20 | Stat-gain delay default | 15 min config, **forced to 0.5 s** | `stats.gainDelay` = 3 s (ML) / 10 min, `stats.petGainDelay` = 5 min | `:52-56` ↔ `:26-27` |
| 21 | Legacy stat path | `else if` chain from `Gain()` ⇒ ≤1 stat per gain | 3 independent `if`s from `CheckSkill` on success ⇒ up to 3 | `:466-476` ↔ `:152-155,312-328` |
| 22 | Atrophy drain | only when `RawStatTotal >= StatCap` | also on a random `RawStatTotal/StatCap` roll, drain before the raise test | `:631-644` ↔ `:374,501-503` |
| 23 | Per-stat cap | `StrCap/DexCap/IntCap` = 125 per mobile | single `stats.statMax` = `Core.LBR ? 125 : 100` | `Mobile.cs:11129-11131` ↔ `:23` |
| 24 | Discordance primary/secondary | `Dex / Int` | `Int / Dex` | `Skills.cs:611` ↔ `skills.json:255-256` |
| 25 | Skill table storage | C# array literal, 58 rows | `Data/skills.json`, 58 entries | `Skills.cs:594-654` ↔ `SkillsInfo.cs:135` |
| 26 | NonRacialValue `inv` | `inv = (100-Base)/100`, applied to both `statsOffset` and `StatTotal` | `inv = 100-Base` (undivided), applied to both | `Skills.cs:396-416` ↔ `Projects/Server/Skills.cs:250-278` |

---

### 3.14 Gaps / what is NOT verifiable from source

| Item | Status | What would resolve it |
|---|---|---|
| Any player-visible message when the anti-macro allowance is exhausted | `[UNVERIFIED]` — no `Send*` call exists on that path in `SkillCheck.cs` or `PlayerMobile.AntiMacroCheck` | capture packets on a live OSI/EA shard with the allowance exhausted |
| Exact OSI `gc` formula (ServUO is a RunUO reconstruction, not a decompile) | `[UNVERIFIED]` — the ServUO constants are the working definition for the clone | statistical measurement: N thousand skill-use attempts at fixed `Base`/`Total`, fit the observed gain rate |
| Whether OSI's GGS table matches ServUO's 24×3 literals | `[UNVERIFIED]` — ServUO's table is the only concrete source here | measured time-to-guaranteed-gain per skill band on a live shard |
| `PlayerCaps.EnableAntiMacro` era claim in the shipped cfg comment ("true if the ML era flag is not on") | `[SRC]` **contradicts** it: the code default literal is `false` | nothing — the code is authoritative for ServUO; OSI behaviour would need a live shard |
| `[ERA]` 700.0 / 100.0 / 225 caps, 0.1 gain step | `[SRC]` for ServUO defaults; era attribution to Classic/pre-AoS is from the brief and is `[PARTIAL]` here | UOGuide / patch-notes citation is out of scope for this section (source-only section) |
| AoS vs ML stat-path behaviour on a real EA shard | `[PARTIAL]` — both paths exist and are switch-selected by `Core.ML` | patch notes for Publish 45 ("Preparation for UOKR", quoted in `ModernUO:Projects/UOContent/Skills/SkillCheck.cs:29`) |
