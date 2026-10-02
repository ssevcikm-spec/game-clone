## 2. Skill use model (per skill)

Scope: the **non-craft, non-bard, non-thief** skills whose behaviour lives in `Scripts/Skills/*.cs`
plus the item-triggered skills Healing / Veterinary (bandage), Camping (kindling + campfire +
bedroll) and Herding (shepherd's crook). Every literal below was read out of the ServUO `pub57`
checkout at `E:\Workspaces\game-clone\.research-src\servuo`; citations are `ServUO:<path>:<line>`
with the matching GitHub URL on the block's source line. Numbers that do **not** exist in source are
marked `[PARTIAL]` / `[UNVERIFIED]` with the measurement that would resolve them.

---

### 2.0 Shared machinery (applies to every block below)

| Mechanism | Code | Constant / formula |
|---|---|---|
| Skill button → server | `ServUO:Server/Network/PacketHandlers.cs:851-862` — speech command `0x24` "Use skill" → `Skills.UseSkill(m, skillIndex)` | index = `(int)SkillName` |
| API entry | `ServUO:Server/Mobile.cs:3951` / `:3956` → `Skills.UseSkill(this, …)` | — |
| Use gate | `ServUO:Server/Skills.cs:886-932` | `CheckAlive` → `Region.OnSkillUse` → `AllowSkillUse` → `Core.TickCount - from.NextSkillTime >= 0 && (info.UseWhileCasting \|\| from.Spell == null)` (`:912`) |
| Cooldown write | `ServUO:Server/Skills.cs:916` | `from.NextSkillTime = Core.TickCount + (int)(info.Callback(from)).TotalMilliseconds` |
| Busy message | `ServUO:Server/Skills.cs:922` → `from.SendSkillMessage()`; `:927` → cliloc `500014` "That skill cannot be used directly." | — |
| No callback | `SkillInfo.Table` entries with `null` callback (Camping `Server/Skills.cs:606`, Healing `:613`, Herding `:616`, Veterinary `:635`) can never be fired from the skill button — they are item-triggered only | — |
| Window check (location) | `ServUO:Scripts/Misc/SkillCheck.cs:134-158` | `chance = (value - minSkill) / (maxSkill - minSkill)` (`:153`); `value < minSkill → false` (`:147`); `value >= maxSkill → true` (`:150`) |
| Window check (target) | `ServUO:Scripts/Misc/SkillCheck.cs:286-311` (`Mobile_SkillCheckTarget`) | same formula at `:306`; used by every `CheckTargetSkill(skill, target, min, max)` below |
| Direct-chance variant | `ServUO:Scripts/Misc/SkillCheck.cs:160-176` / `:313-329` | `chance < 0 → false`, `chance >= 1 → true`; `CheckSkill(skill, chance)` |
| Success roll | `ServUO:Scripts/Misc/SkillCheck.cs:245` | `success = Utility.Random(100) <= (int)(chance * 100)` |
| Gain roll | `ServUO:Scripts/Misc/SkillCheck.cs:261-284` | `gc = ((Cap - Total)/Cap + (skill.Cap - skill.Base)/skill.Cap)/2; gc = (gc + (1-chance)*(success ? 0.5 : AoS?0.0:0.2))/2; gc *= GainFactor; clamp 0.01..1.00; pets ×2` |
| `Skill.Value` vs `Base` | `ServUO:Server/Skills.cs:91-98` | `Value` includes item/skillmod bonuses; `Base` does not. Blocks below state which one each formula reads |
| Anti-macro gate | `ServUO:Scripts/Misc/SkillCheck.cs:59-123` + `:331` | `UseAntiMacro[]` false for Parry/Blacksmith/Fletching/Carpentry/Cartography/Cooking/Inscribe/Tactics/Archery/Tailoring/Tinkering/weapon skills/Focus/Throwing; **true** for Anatomy/AnimalLore/ItemID/ArmsLore/Begging/Peacemaking/**Camping**/DetectHidden/Discordance/EvalInt/**Healing**/Fishing/Forensics/**Herding**/Hiding/Provocation/Lockpicking/Magery/MagicResist/Snooping/Musicianship/Poisoning/SpiritSpeak/Stealing/AnimalTaming/TasteID/Tracking/**Veterinary**/Lumberjacking/Mining/Meditation/Stealth/RemoveTrap/Necromancy/Chivalry/Bushido/Ninjitsu/Spellweaving/Mysticism/Imbuing |
| GGS | `ServUO:Scripts/Misc/SkillCheck.cs:774-806` (table at `:798`) | `GGSTable[skill.Base/5][Total>=7000?2:Total>=3500?1:0]` minutes; disabled on Siege (`:40`) |
| `Utility.Random(from, count)` | `ServUO:Server/Utility.cs:905-919` | returns `from + [0, count-1]` — **count is exclusive**, relevant for the taming tick count and the "unreachable" begging branches |
| `Utility.RandomMinMax(min, max)` | `ServUO:Server/Utility.cs:889-903` | inclusive both ends |
| Skill button delays | see table below | `[SRC]` |

| Skill | Slot | Callback (file:line) | Delay returned to `NextSkillTime` |
|---|---|---|---|
| Anatomy | 1 | `Scripts/Skills/Anatomy.cs:15` | 1.0 s (`:21`) |
| Animal Lore | 2 | `Scripts/Skills/AnimalLore.cs:15` | 1.0 s (`:27`) |
| Item Identification | 3 | `Scripts/Skills/ItemIdentification.cs:17` | 1.0 s (`:22`) |
| Arms Lore | 4 | `Scripts/Skills/ArmsLore.cs:16` | 1.0 s (`:22`) |
| Begging | 6 | `Scripts/Skills/Begging.cs:19` | 1 hour (`:27`); reset to "now" on target finish (`:42`), +10 s after a completed attempt (`:331`) |
| Camping | 10 | none (`Server/Skills.cs:606`) | n/a — item only |
| Detect Hidden | 14 | `Scripts/Skills/DetectHidden.cs:35` | 10.0 s (`:40`) |
| Evaluating Intelligence | 16 | `Scripts/Skills/EvalInt.cs:15` | 1.0 s (`:21`) |
| Healing | 17 | none — `Scripts/Items/Resource/Bandage.cs:73` | n/a — item only |
| Forensic Evaluation | 19 | `Scripts/Skills/ForensicEval.cs:22` | 1.0 s (`:29`) |
| Herding | 20 | none — `Scripts/Items/Equipment/Weapons/ShepherdsCrook.cs:130` | n/a — item only |
| Inscription | 23 | `Scripts/Skills/Inscribe.cs:16` | 1.0 s (`:23`) |
| Poisoning | 30 | `Scripts/Skills/Poisoning.cs:14` | 10.0 s (`:20`) |
| Spirit Speak | 32 | `Scripts/Skills/SpiritSpeak.cs:22` | AoS: 5.0 s (`:32`), pre-AoS: 1.0 s (`:66`), AoS while casting: 0 (`:35`) |
| Animal Taming | 35 | `Scripts/Skills/AnimalTaming.cs:34` | 40.0 s (`:53`) |
| Taste Identification | 36 | `Scripts/Skills/TasteID.cs:15` | 1.0 s (`:21`) |
| Tracking | 38 | `Scripts/Skills/Tracking.cs:20` | 10.0 s (`:28`) |
| Veterinary | 39 | none — bandage | n/a — item only |
| Meditation | 46 | `Scripts/Skills/Meditation.cs:30` | 10.0 s (`:102`); 5.0 s busy/low-HP (`:38`,`:44`); pre-AoS full mana 5.0 s (`:50`); 2.5 s hands-full (`:75`) |
| Remove Trap | 48 | `Scripts/Skills/RemoveTrap.cs:27` | 10.0 s (`:44`) |

`[SRC]` for the whole table. Note the asymmetry: `NextSkillTime` is only written when the callback
returns through `Skills.UseSkill`; handlers that return early (e.g. `Meditation` busy branch) still
consume the delay. Handlers that set `m_SetSkillTime = false` (Animal Taming `:240`, Begging `:89`)
suppress the `OnTargetFinish` reset so the *long* delay stays.

---

### 2.1 Anatomy

Source: `ServUO:Scripts/Skills/Anatomy.cs` (93 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Anatomy.cs

| Field | Value |
|---|---|
| Trigger | Skill button (callback `Anatomy.cs:12`), then 1.0 s cooldown |
| Target requirements | `Target(8, false, TargetFlags.None)` — 8 tiles, ground not allowed (`:27`) |
| Skill check window | `from.CheckTargetSkill(SkillName.Anatomy, targ, 0, 100)` (`:74`) — 0 %–100 % of the window, so chance = `Anatomy.Value / 100` |
| Delay / cooldown | 1.0 s (`:21`) |
| Success outcome | `PrivateOverheadMessage(0x3B2, 1038045 + (strMod * 11) + dexMod)` (`:76`); if `Anatomy.Base >= 65.0` a second line `1038303 + stmMod` (`:79`) |
| Failure outcome | cliloc `1042666` "You can not quite get a sense of their physical characteristics." (`:83`) — **no information at all**, not a fuzzy value |
| Resource consumed | none |
| Messages / gumps | `500321` "Whom shall I examine?" (`:19`); self `500324` (`:35`); TownCrier `500322` (`:39`); invulnerable vendor `500326` (`:43`); item `500323` "Only living things have anatomies!" (`:88`) |
| Interactions | passive Anatomy gain on every melee swing (`Scripts/Items/Equipment/Weapons/BaseWeapon.cs:3831` pre-AoS, `:3775` AoS-classic path); Achery/… weapon damage bonus; pre-AoS 2-handed special blow; Cu Sidhe lore gump shows creature Anatomy |
| [ERA] | `1038045`/`1038303`/`1042666` set is the AoS-era "physical characteristics" text set; pre-AoS Clients read the older "You see…" line. ServUO does not branch on era here |
| Confidence | `[SRC]` for all numbers; exact cliloc **strings** for the 1038xxx/1042666 range are `[PARTIAL]` (they live in `cliloc.enu`, not in C#) |

**Anatomy damage bonus (physical characteristics of the attacker)**

| Era | Formula | Citation |
|---|---|---|
| AoS/ML+ (`ScaleDamageAOS`) | `anatomyBonus = GetBonus(Anatomy.Value, 0.500, 100.0, 5.00)` where `GetBonus = (value*scalar + (value>=threshold ? offset : 0)) / 100` ⇒ **+0.5 % per point, +5 % extra at exactly ≥100.0** (max +55 % at 100; uncapped above 100 because no clamp) | `BaseWeapon.cs:3789` + `:3663-3673` |
| Total AoS bonus | `totalBonus = strengthBonus + anatomyBonus + tacticsBonus + lumberBonus + ((GetDamageBonus()+damageBonus)/100)`; `damage += (int)(damage * totalBonus)` | `BaseWeapon.cs:3812-3815` |
| Pre-AoS (`ScaleDamageOld`) | `modifiers += ((Anatomy.Value / 5.0) / 100.0)` ⇒ **+1 % per 5.0 points (0.2 %/pt)**; `if (anatomyValue >= 100.0) modifiers += 0.1` ⇒ **+10 % at GM** | `BaseWeapon.cs:3856-3862` |
| Pre-AoS 2-handed special blow | `Anatomy.Value / 400.0 >= Utility.RandomDouble()` ⇒ 25 % at 100 Anatomy (Bashing `BaseBashing.cs:78`, Axe `:147`, PoleArm `:123`, Spear `:70`) — applied only when `!Core.AOS` | as cited |
| Wrestling special (pre-AoS) | `attacker.Skills[Anatomy].Value >= 80.0 && attacker.Skills[Wrestling].Value >= 80.0` | `Scripts/Items/Equipment/Weapons/Fists.cs:168` |
| Confidence | `[SRC]` | |

**"You see" output index map** — the gump text is chosen purely by the cliloc offset, never by prose
in the C# file, so the *thresholds* are the two clamps below:

| Index | Computation | Range |
|---|---|---|
| `marginOfError` | `Math.Max(0, 25 - (int)(from.Skills[Anatomy].Value / 4))` | 25 at 0 skill → 0 at ≥100 skill (`Anatomy.cs:49`) |
| `str` / `dex` | `targ.Str / Dex + RandomMinMax(-margin, +margin)` | raw stat ±error (`:51-52`) |
| `stm` | `((targ.Stam * 100) / Math.Max(targ.StamMax, 1)) + RandomMinMax(-margin, +margin)` | stamina **as a percentage**, clamped 0..10 after `/10` (`:53`,`:69-72`) |
| `strMod` / `dexMod` / `stmMod` | `value / 10`, clamped to `0..10` | 11 bands each (`:55-72`) |
| Success line | `1038045 + (strMod * 11) + dexMod` | 121 consecutive clilocs `1038045`–`1038165` |
| Stamina line (only `Base >= 65.0`) | `1038303 + stmMod` | 11 clilocs `1038303`–`1038313` |

`[PARTIAL]`: the 132 English strings for `1038045+` and the 11 strings for `1038303+` are not in
source. To reproduce them exactly, read `cliloc.enu` entries `1038045`–`1038165` and
`1038303`–`1038313` from the client files (measurement: dump those ids from a UO installation or
from `ClassicUO`'s cliloc loader).

---

### 2.2 Animal Lore

Source: `ServUO:Scripts/Skills/AnimalLore.cs` (428 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/AnimalLore.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`AnimalLore.cs:12`); if the ToL pet-training gump is already open → `500118` "You must wait a few moments to use another skill." (`:19`) instead of a target |
| Target requirements | `Target(8, false, TargetFlags.None)` (`:59`), must be a live `BaseCreature` whose `Body.IsAnimal \|\| IsMonster \|\| IsSea` (`:75`); dead pets and ghosts refused |
| Skill check window | Two-stage. Gate check in `Check()`: `CheckTargetSkill(AnimalLore, c, min, 120.0)` where `min` = **80.0** for tameable wild or (skill ≥110) non-tameable, **100.0** for non-tameable at skill ≥110 (`:90`,`:99`,`:101`). Gump display re-rolls `CheckTargetSkill(AnimalLore, c, 0.0, 120.0)` purely for **gain** (`:34`) |
| Delay / cooldown | 1.0 s (`:27`) |
| Success outcome | `AnimalLoreGump(c)` (`:46`) — or `NewAnimalLoreGump` when `PetTrainingHelper.Enabled` (`:40`) |
| Failure outcome | cliloc `500334` "You can't think of anything you know offhand." (`:55`) |
| Resource consumed | none |
| Messages / gumps | `500328` "What animal should I look at?" (`:24`); `500331` dead/ghost (`:67`,`:111`); `500329` "That's not an animal!" (`:106`,`:116`); `1049674` "At your skill level, you can only lore tamed creatures."; `1049675` "…tamed or tameable creatures." |
| Interactions | Animal Taming passively rolls `CheckTargetSkill(AnimalLore, creature, 0.0, 120.0)` on every taming tick (`AnimalTaming.cs:378`,`:399`); Animal Lore is the **secondary skill** for veterinary bandaging (`Bandage.cs:268`) and feeds the pet control chance (`BaseCreature.cs:1534`); the gump prints the creature's Barding Difficulty used by the bard skills |
| [ERA] | Gump has **5 pages when `Core.AOS`, else 3** (`:197`); Loyalty Rating is on page 1 for AoS (`:241-244`) and on the last page pre-AoS (`:415-421`); Barding Difficulty row only `Core.SE` (`:228-238`); Base Damage row only `Core.ML` (`:311-315`); Cu Sidhe shows Healing instead of Poisoning (`:342-351`) |
| Confidence | `[SRC]` |

**Skill → readability gate**

| `AnimalLore.Value` | Controlled creature | Wild + `Tamable` | Wild + not tameable |
|---|---|---|---|
| `< 100.0` | gump | `1049674` "At your skill level, you can only lore tamed creatures." | same |
| `100.0 – 109.9` | gump | `Check(80.0)` | `1049675` "…only lore tamed or tameable creatures." |
| `>= 110.0` | gump | `Check(80.0)` | `Check(100.0)` |

`[SRC]` — `AnimalLore.cs:77-102`.

**Gump contents (`AnimalLoreGump`)**

| Page | Rows | Source |
|---|---|---|
| 1 Attributes | Hits (cur/max), Stamina, Mana, Strength, Dexterity, Intelligence; AoS+ adds Barding Difficulty (SE) and **Loyalty Rating** | `:201-256` |
| 2 Resistances (AoS only) | Physical / Fire / Cold / Poison / Energy | `:260-284` |
| 3 Damage (AoS only) | Physical / Fire / Cold / Poison / Energy; + Base Damage if `Core.ML` | `:288-320` |
| 4 Combat Ratings / Lore & Knowledge | Wrestling, Tactics, Magic Resistance, Anatomy, Poisoning (or Healing for Cu Sidhe); Magery, Evaluating Intelligence, Meditation | `:324-367` |
| 5 Misc | Preferred Foods (Meat/Fish/Grains/Fruits/Eggs), Pack Instincts (Canine/Ostard/Feline/Arachnid/Daemon/Bear/Equine/Bull); pre-AoS adds Loyalty Rating | `:371-424` |

| Formatting rule | Code |
|---|---|
| Skill `< 10.0` → `---`, else `{0:F1}` | `:124-132` |
| Attribute with `max == 0` → `---` | `:134-140` |
| Stat `0` → `---` | `:142-148` |
| Resistance/Damage `<= 0` → `---`, else `{0}%` | `:158-164` |
| Damage range `min<=0 or max<=0` → `---`, else `{0}-{1}` | `:167-173` |
| **Loyalty line** | `(!c.Controlled \|\| c.Loyalty == 0) ? 1061643 : 1049595 + (c.Loyalty / 10)` (`:244`, `:420`) ⇒ 11 bands `1049595`–`1049605`; `Loyalty` is `0..100` (`BaseCreature.cs:204`,`:1727`) |
| Barding Difficulty | `Items.BaseInstrument.GetBaseDifficulty(c)`, forced to `0` when `c.Uncalmable` (`:230-235`) |

`[SRC]`. `[PARTIAL]`: the English wording of `1049595`–`1049605` (loyalty bands) and `1061643`
("wonderfully happy") is cliloc-side; measure by dumping those ids.

---

### 2.3 Arms Lore

Source: `ServUO:Scripts/Skills/ArmsLore.cs` (167 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/ArmsLore.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`ArmsLore.cs:13`), 1.0 s |
| Target requirements | `Target(2, false, TargetFlags.None)` with `AllowNonlocal = true` (`:29-31`), annotated `[PlayerVendorTarget]`; accepts `BaseWeapon`, `BaseArmor`, `SwampDragon` with barding |
| Skill check window | `CheckTargetSkill(ArmsLore, targeted, 0, 100)` — separate roll for weapon (`:38`), armor (`:99`), barding (`:144`) ⇒ chance = `ArmsLore.Value/100` |
| Delay / cooldown | 1.0 s (`:22`) |
| Success outcome | Durability line + damage/AR band line (+ poison line for weapons) |
| Failure outcome | `500353` "You are not certain…" (`:94`,`:137`,`:157`) |
| Resource consumed | none |
| Messages / gumps | `500349` "What item do you wish to get information about?" (`:20`); `500352` "This is neither weapon nor armor." (`:162`) |
| Interactions | none coded (Arms Lore is informational only); Swamp Dragon barding result feeds the barding armour system |
| [ERA] | Text set `1038285`/`1038216`–`1038224`/`1038295` is AoS-era. The old hard-coded `if/else` ladder is **commented out** in source (`:61-74`, `:116-133`) and replaced by arithmetic. `[ERA]` = the arithmetic form is what this shard ships |
| Confidence | `[SRC]` |

**Identification output tables**

| Target | Formula | Output cliloc |
|---|---|---|
| Weapon durability | `hp = (int)((HitPoints / (double)MaxHitPoints) * 10)`, clamped `0..9` (only if `MaxHitPoints != 0`) | `1038285 + hp` → 10 bands (`:42-52`) |
| Weapon damage band | `d = (MaxDamage + MinDamage) / 2`; `d < 3 → 0`; else `d = (int)Math.Ceiling(Math.Min(d, 30) / 5.0)` | 0,1,2,3,4,5,6 (`:54-60`) |
| Weapon hand flag | `hand = (weap.Layer == Layer.OneHanded ? 0 : 1)` | distinguishes 1H/2H text (`:55`) |
| Ranged | `1038224 + (damage * 9)` | `1038224, 1038233, … 1038278` (`:79`) |
| Piercing | `1038218 + hand + (damage * 9)` | `1038218`–`1038281` (`:81`) |
| Slashing | `1038220 + hand + (damage * 9)` | `1038220`–`1038283` (`:83`) |
| Bashing | `1038222 + hand + (damage * 9)` | `1038222`–`1038285` (`:85`) |
| Other/unknown weapon type | `1038216 + hand + (damage * 9)` | `1038216`–`1038279` (`:87`) |
| Poisoned weapon | `weap.Poison != null && weap.PoisonCharges > 0` → `1038284` "It appears to have poison smeared on it." | `:89-90` |
| Armor durability | same `hp` formula, clamped `0..9` | `1038285 + hp` (`:103-112`) |
| Armor rating band | `1038295 + (int)Math.Ceiling(Math.Min(arm.ArmorRating, 35) / 5.0)` | 8 bands `1038295`–`1038302` (0..7) (`:115`) |
| Swamp Dragon barding | `perc = (4 * BardingHP) / BardingMaxHP`, clamped `0..4` | `1053021 - perc` → 5 bands (`:146-153`) |

`[SRC]` for every arithmetic constant. `[PARTIAL]`: the commented-out ladder at `:116-133` documents
the *original* OSI thresholds (`<1`, `<6`, `<11`, `<16`, `<21`, `<26`, `<31`, else) — these are dead
code in `pub57` and are **not** what the server sends; they are useful only as era reference.

---

### 2.4 Evaluating Intelligence

Source: `ServUO:Scripts/Skills/EvalInt.cs` (93 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/EvalInt.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[16]` (`EvalInt.cs:12`), 1.0 s |
| Target requirements | `Target(8, false, TargetFlags.None)` (`:27`); Mobile only for the stat read-out |
| Skill check window | `CheckTargetSkill(EvalInt, targ, 0.0, 120.0)` (`:74`) |
| Delay / cooldown | 1.0 s (`:21`) |
| Success outcome | `1038169 + intMod + body` (`:76`); if `EvalInt.Base >= 76.0` a second line `1038202 + mnMod` (`:79`) |
| Failure outcome | `1038166 + (body / 11)` (`:83`) |
| Resource consumed | none |
| Messages / gumps | `500906` "What do you wish to evaluate?" (`:19`); self `500910`; TownCrier `500907`; invulnerable vendor `500909`; item `500908` |
| Interactions | EvalInt is `DamageSkill` for **all** Magery spells (`Scripts/Spells/Base/Spell.cs:53`) and therefore scales spell damage; `Protection` uses `EvalInt + Meditation + Inscribe` for its resist malus (`Scripts/Spells/Second/Protection.cs:145`); Paralyze Field duration uses `EvalInt/10 - MagicResist/10` (`Scripts/Spells/Sixth/ParalyzeField.cs:188`); weapon Paralyze/Concussion blow durations use EvalInt too (`BaseWeapon.cs:1934`,`:1948`) |
| [ERA] | AoS damage path uses `evalScale`; pre-AoS uses the `casterEI vs targetRS` scalar. No era gate on the lore read-out itself |
| Confidence | `[SRC]` for formulas; `[PARTIAL]` for cliloc text |

**Lore output thresholds**

| Index | Computation | Range |
|---|---|---|
| `marginOfError` | `Math.Max(0, 20 - (int)(EvalInt.Value / 5))` | 20 at 0 → 0 at ≥100 (`:49`) |
| `intel` / `mana` | `targ.Int + RandomMinMax(-m,+m)`; `((targ.Mana*100)/Math.Max(targ.ManaMax,1)) + RandomMinMax(-m,+m)` | mana is a **percent** (`:51-52`) |
| `intMod` / `mnMod` | `value / 10`, clamped `0..10` | 11 bands (`:54-65`) |
| `body` | `targ.Body.IsHuman ? (targ.Female ? 11 : 0) : 22` | 0 = human male, 11 = human female, 22 = non-human (`:67-72`) |
| Success line 1 | `1038169 + intMod + body` | 33 clilocs `1038169`–`1038201` |
| Success line 2 (requires `Base >= 76.0`) | `1038202 + mnMod` | 11 clilocs `1038202`–`1038212` |
| Failure line | `1038166 + (body / 11)` | `1038166` (male), `1038167` (female), `1038168` (non-human) |

**Magery interaction (the "circle gating" claim)** `[SRC]`:

| Question | What the source actually contains |
|---|---|
| Is EvalInt a cast requirement? | **No.** Casting is gated by `Caster.CheckSkill(CastSkill, minSkill, maxSkill)` where `CastSkill` = the spell's own skill (`Scripts/Spells/Base/Spell.cs:919-943`); `GetCastSkills(out min, out max)` is overridden **per spell** and defaults to `min = max = 0` (`:919-922`). There is **no** code path anywhere in `pub57` that maps EvalInt to a spell circle |
| What EvalInt *does* do at cast time | `CheckFizzle()` also rolls `Caster.CheckSkill(DamageSkill, 0.0, Caster.Skills[DamageSkill].Cap)` when `DamageSkill != CastSkill` — i.e. EvalInt gains passively on every magery cast (`:935-938`) |
| AoS damage scaling | `int evalSkill = GetDamageFixed(m_Caster); int evalScale = 30 + ((9 * evalSkill) / 100); damage = AOS.Scale(damage, evalScale)` (`:231-234`) — at 100.0 EvalInt (`evalSkill = 1000`) ⇒ **×1.20**; at 120.0 ⇒ ×1.408 |
| AoS extra bonus | `damageBonus` also includes `Caster.Int/10` and `scribeBonus = inscribeSkill >= 1000 ? 10 : inscribeSkill/200` (`:224-229`) |
| Pre-AoS damage scalar | `casterEI > targetRS ? 1.0 + (casterEI - targetRS)/500 : 1.0 + (casterEI - targetRS)/200`; plus `(Magery - 100)/400`; **×2 vs non-human, non-player targets when `!Core.AOS`** (`:451-478`) |

`[UNVERIFIED]`: if the delivery target requires the classic "circle = (Magery + EvalInt)/20" rule,
it does **not** exist in ServUO. To confirm what the retail client shows, measure on a live shard:
cast a 4th-circle spell with `Magery 30 / EvalInt 100` and observe whether the client refuses.

---

### 2.5 Item Identification

Source: `ServUO:Scripts/Skills/ItemIdentification.cs` (195 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/ItemIdentification.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[(int)SkillName.ItemID]` (`:14`), 1.0 s |
| Target requirements | `Target(8, false, TargetFlags.None)` + `AllowNonlocal` (`:29-32`), `[PlayerVendorTarget]`; accepts `Item` **or** `Mobile` |
| Skill check window | `CheckTargetSkill(ItemID, o, 0, 100)` (`:45`) → chance = `ItemID.Value/100` |
| Delay / cooldown | 1.0 s (`:22`) |
| Success outcome | Item: name (custom name or `LabelNumber`) shown as Emote to the user **and** as a Label over the item (`:57-66`). Mobile: `1041349` + name (`:53`). AoS adds value + unravel info; pre-AoS sets `Identified = true` and calls `OnSingleClick` |
| Failure outcome | AoS: `1041352` "You have no idea how much it might be worth." (`:47`); pre-AoS: `500353` (`:159`); non-item/non-mobile target: `500353` (`:41`) |
| Resource consumed | none |
| Messages / gumps | `500343` "What do you wish to appraise and identify?" (`:19`); Meteorite special text `1158697` (polished) / `1158696` (raw), which short-circuits everything else (`:70-82`) |
| Interactions | **Imbuing**: `Imbuing.TimesImbued`, `Imbuing.GetTotalWeight`, `Imbuing.CanUnravelItem` decide the unravel ingredient text and are gated on the *reader's* `Imbuing.Base` (`:88-138`). XmlSpawner attachments are revealed last (`:171`) |
| [ERA] | `if (Core.AOS)` value/unravel branch (`:68`); pre-AoS branch only sets `Identified` and single-clicks (`:145-161`) |
| Confidence | `[SRC]` |

**Value + unravel thresholds**

| Condition | Result | Citation |
|---|---|---|
| Type present in `GenericBuyInfo.BuyPrices` | price = `BuyPrices[type] * item.Amount` | `:178-181` |
| Otherwise | `Utility.RandomMinMax(2, 7)`, cached per `Type` in `TypeCostCache` for the process lifetime | `:183-192` |
| Display | `1041351` "You guess the value of that item at:" + `"  " + GetPriceFor(item)` | `:84` |
| `Imbuing.TimesImbued(item) > 0` | `1111877` "…cannot be magically unraveled. The magic in that item has been weakened…" | `:88-90` |
| weight `1..200` | `Magical Residue` | `:104-107` |
| weight `201..479` | `Enchanted Essence`; if `Imbuing.Base < 45.0` → `1111875` "Your Imbuing skill is not high enough to identify the imbuing ingredient." | `:108-114` |
| weight `>= 480` | `Relic Fragment`; if `Imbuing.Base < 95.0` → `1111875` | `:115-121` |
| weight `0` / not unravelable | `1111876` "…appears to possess little to no magic." | `:134-137` |
| Item not weapon/armor/jewel/hat (AoS) | `1111878` "You conclude that item cannot be magically unraveled." | `:140-143` |
| Unravel message | `1111874` "You conclude that item will magically unravel into: ~1_ingredient~" | `:131` |

`[SRC]`. `[PARTIAL]`: the canonical *pre-AoS* Item ID price ladder (weapon/armor tiers) is not
implemented — pre-AoS simply toggles `Identified`. Measure the classic tier text client-side if the
clone needs it.

---

### 2.6 Taste Identification

Source: `ServUO:Scripts/Skills/TasteID.cs` (95 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/TasteID.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:12`), 1.0 s |
| Target requirements | `Target(2, false, TargetFlags.None)` + `AllowNonlocal` (`:28-31`), `[PlayerVendorTarget]`; `Food`, `BasePotion`, `PotionKeg` |
| Skill check window | `CheckTargetSkill(TasteID, food, 0, 100)` — **only rolled for `Food`** (`:43`). Potions and kegs are always identified with no roll |
| Delay / cooldown | 1.0 s (`:21`) |
| Success outcome | Food with `food.Poison != null` → `1038284` "It appears to have poison smeared on it." (`:47`); clean food → `1010600` "You detect nothing unusual about this substance." (`:52`). Potion → `502813` + `potion.LabelNumber` (`:65-66`). Keg with contents → `502229` + `keg.LabelNumber` (`:78-79`) |
| Failure outcome | `502823` "You cannot discern anything about this substance." (`:58`) — poison is **not** falsely reported, it is simply unknown |
| Resource consumed | none (the food is not eaten) |
| Messages / gumps | `502807` "What would you like to taste?" (`:19`); Mobile target `502816` "You feel that such an action would be inappropriate." (`:37`); empty keg `502228` (`:74`); other item `502820` "That's not something you can taste." (`:85`); out of range `502815` (`:91`) |
| Interactions | the only player-facing poison detector for food; pairs with Poisoning (`Scripts/Skills/Poisoning.cs:120` sets `Food.Poison`) and with the "poisoned food" mechanic; `label 1038284` shared with Arms Lore |
| [ERA] | No era gate — the `1038284`/`1010600` set is AoS-era text; pre-AoS shards showed a generic message. `[PARTIAL]` |
| Confidence | `[SRC]` |

---

### 2.7 Forensic Evaluation

Source: `ServUO:Scripts/Skills/ForensicEval.cs` (173 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/ForensicEval.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:19`) + `m.RevealingAction()` (`:25`), 1.0 s |
| Target requirements | `Target(10, false, TargetFlags.None)` (`:35`); accepts `Corpse`, `Mobile`, `ILockpickable`, and (SA) `Item` with `IForensicTarget` or an `HonestyItemSocket` |
| Skill check window | Per target type — see table below. `skill = from.Skills[Forensics].Value` (`:41`) |
| Delay / cooldown | 1.0 s (`:29`) |
| Success outcome | See table; also stamps `c.m_Forensicist = from.Name` if unset (`:59`) |
| Failure outcome | `501001` "You cannot determain anything useful." *(sic)* — and for under-skill targets `501003` "You notice nothing unusual." |
| Resource consumed | none |
| Messages / gumps | `501000` "Show me the crime." (`:27`); corpse outcomes `1042750`/`1042751`/`1042752`/`501002`; thief `501004` "That individual is a thief!"; lock `1042749` "This lock was opened by ~1_PICKER_NAME~"; Honesty `1151521`/`1151522` |
| Interactions | shares the `ILockpickable.Picker` field with Lockpicking; shares `Corpse.Killer` with the murder/justice system and `Corpse.Looters` (updated by looting); `NpcGuild.ThievesGuild` is set by the thief guild system; Honesty virtue socket (SA) assigns an owner on first forensic use (`:153`) |
| [ERA] | `ILockpickable` and `Mobile` branches are base; the `Item`/Honesty branch is `Core.SA` (`:134`) and the 61.0 skill tier (`:159`) is SA-era. The 55.0 upper bound for corpses is pre-AoS-shaped |
| Confidence | `[SRC]` |

| Target | Min skill gate | `CheckTargetSkill` window | Success message | Citation |
|---|---|---|---|---|
| `Corpse` | `skill < 30.0` → `501003` | `(Forensics, target, 30.0, 55.0)` | already examined → `1042750` + forensicist name; human body → `1042751` "This person was killed by ~1_KILLER_NAME~" (`"no one"` if `Killer == null`); looted → `1042752` list of `Looters`; else `501002` "The corpse has not be desecrated." | `:44-81` |
| `Mobile` | `skill < 36.0` → `501003` | `(Forensics, target, 36.0, 100.0)` | `501004` if `PlayerMobile.NpcGuild == ThievesGuild`, else `501003` | `:88-108` |
| `ILockpickable` | `skill < 41.0` → `501003` | `(Forensics, target, 41.0, 100.0)` | `1042749` + `p.Picker.Name` if set, else `501003` | `:110-133` |
| `Item` (`Core.SA`) | `skill < 41.0` (and not `IForensicTarget`) → `501001` | `(Forensics, target, 41.0, 100.0)` on the Honesty socket | `skill >= 61.0` → `1151521` "This item belongs to ~1_val~ who lives in ~2_val~." else `1151522` "…~1_val~" (region only) | `:134-168` |

---

### 2.8 Tracking

Source: `ServUO:Scripts/Skills/Tracking.cs` (394 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Tracking.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:17`) → `1011350` "What do you wish to track?" + `TrackWhatGump` (`:22-26`), 10.0 s |
| Target requirements | No world target — a 4-button gump picks the **category**; the follow-up `TrackWhoGump` picks the individual |
| Skill check window | Rolled **once when the gump is built**: `from.CheckSkill(Tracking, 0.0, 21.1)` stored as `m_Success` (`:87`). A second, purely-for-gain roll `from.CheckSkill(Tracking, 21.1, 100.0)` fires when a category is chosen (`:189`) |
| Delay / cooldown | 10.0 s (`:28`) |
| Success outcome | `TrackWhoGump` listing up to 12 candidates + `1018093` "Select the one you would like to track." (`:208-209`) |
| Failure outcome | `1018092` "You see no evidence of those in the area." (`:178`); empty-but-successful category → `502991` / `502993` / `502995` (`:213-218`) |
| Resource consumed | none |
| Messages / gumps | gump title buttons `1018087` Animals, `1018088` Monsters, `1018089` Human NPCs, `1018090` Players (`:98-110`); arrow lost `503177` "You have lost your quarry." (`:349`) |
| Interactions | **Detect Hidden** — contested vs `Hiding`+`Stealth` for players; **Hiding/Stealth** of the target; **Ninjitsu** — the stalking bonus is consumed by `Backstab` (`Backstab.cs:44`), `Death Strike` (`DeathStrike.cs:125`), `Surprise Attack` (`SurpriseAttack.cs:103`); **Necromancy** transformations alter the divisor |
| [ERA] | `Core.SE` changes the difficulty formula (`:264-267`) and enables `Tracking.AddInfo` for the stalking bonus (`:232-233`); `Core.ML` halves an elf's effective Tracking (`:246-247`) and **caps** the stalking bonus (`:52-53`); pre-AoS `CheckDifficulty` returns `true` unconditionally (`:240`) |
| Confidence | `[SRC]` |

| Element | Formula / constant | Citation |
|---|---|---|
| Range | `int range = 10 + (int)(from.Skills[Tracking].Value / 10)` ⇒ **10 tiles at 0, 20 at 100, 22 at 120** | `:191` |
| Candidate filter | `m != from && (!Core.AOS \|\| m.Alive) && (!m.Hidden \|\| m.IsPlayer() \|\| from.AccessLevel > m.AccessLevel) && check(m) && CheckDifficulty(from, m)` — **ghosts can never be tracked** | `:199` |
| Categories | Animals = `!Player && Body.IsAnimal`; Monsters = `!Player && Body.IsMonster`; Human NPCs = `!Player && Body.IsHuman`; Players = `Player` | `:275-293` |
| Step rules | gump lists ≤12 (`:162`); 4 per row (`:166`); sorted **closest first** by `GetDistanceToSqrt` | `:295-314` |
| Arrow lifetime | `TrackArrow(..., m_Range * 2)` → arrow radius = **2× the track range** | `:230` |
| Arrow tick | timer delay 0.25 s, interval 2.5 s (`:362`); stops on: no `NetState`, deleted, map mismatch, `!InRange(target, m_Range)`, or hidden target with higher `AccessLevel` (`:378`) |
| Cancel | right-click → `Tracking.ClearTrackingInfo` + stop (`:329-339`) |

**Player-vs-player difficulty (`CheckDifficulty`, `:238-273`)**

| Step | Literal |
|---|---|
| `tracking` | `from.Skills[Tracking].Fixed` (×10 fixed-point) |
| `detectHidden` | `from.Skills[DetectHidden].Fixed` |
| Elf penalty | `if (Core.ML && m.Race == Race.Elf) tracking /= 2` |
| `divisor` | `m.Skills[Hiding].Fixed + m.Skills[Stealth].Fixed` |
| Horrific Beast target | `divisor -= 200` |
| Vampiric Embrace target | `if (divisor < 500) divisor = 500` |
| Wraith Form target | `if (divisor <= 2000) divisor += 200` |
| `Core.SE` chance | `chance = 50 * (tracking * 2 + detectHidden) / divisor` |
| pre-SE chance | `chance = 50 * (tracking + detectHidden + 10 * Utility.RandomMinMax(1, 20)) / divisor` |
| `divisor <= 0` | `chance = 100` |
| Result | `return chance > Utility.Random(100)` |

**Stalking bonus** (`:37-56`)

| Step | Literal |
|---|---|
| Validity | stored `TrackingInfo` must exist, `info.m_Target == target`, `info.m_Map == target.Map`, else `0.0` |
| Bonus | `Math.Sqrt(xDelta*xDelta + yDelta*yDelta)` — the **straight-line distance from the position recorded at track time to the target's current position** |
| Consumption | `m_Table.Remove(tracker)` — one-shot ("Reset as of Pub 40, counting it as bug for Core.SE", in-source comment `:50`) |
| `Core.ML` cap | `Math.Min(bonus, 10 + tracker.Skills.Tracking.Value / 10)` ⇒ cap 20 at 100 Tracking |

`[SRC]`. Divergence with ModernUO: `ModernUO:Projects/UOContent/Skills/Tracking/Tracking.cs:166` uses
`10 + (int)from.Skills.Tracking.Value / 10 * 10` (range quantised to multiples of 10) — ServUO's
per-point range is not reproduced there.

---

### 2.9 Begging

Source: `ServUO:Scripts/Skills/Begging.cs` (336 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Begging.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:16`) + `RevealingAction` (`:21`) + deferred target (`:25`) |
| Target requirements | `Target(12, false, TargetFlags.None)` (`:35`) — 12 tiles, but the *actual* range gate is `from.InRange(targ, 2)` (`:64`) |
| Skill check window | `CheckTargetSkill(Begging, m_Target, 0.0, 100.0)` (`:131`) → chance = `Begging.Value / 100` |
| Delay / cooldown | Callback returns **1 hour** (`:27`); if the target resolves, `OnTargetFinish` sets `NextSkillTime = Core.TickCount` (`:42`) so the real cooldown is **10 s** written at `:331`. If the target is cancelled, the 1-hour penalty stays |
| Success outcome | Gold or an item handed over (tables below), karma loss |
| Failure outcome | `m_Target.SendLocalizedMessage(500404)` "They seem unwilling to give you any money." (`:327`) — note it is sent to the **NPC**, not the beggar |
| Resource consumed | none of the beggar's; the NPC's gold is decremented |
| Messages / gumps | `500397` "To whom do you wish to grovel?" (`:23`); player target `500398` "Perhaps just asking would work better."; non-human `500399` "There is little chance of getting money from that!"; too far `500401` (male) / `500402` (female); mounted (pre-ML) `500404`; low karma `500406` "Thou dost not look trustworthy... no gold for thee today!"; success `500405` "I feel sorry for thee..."; poor NPC `500407` "I have not enough money to give thee any!"; elf path `1074854` "Here, take this..." + `1074853` "You have been given ~1_name~" |
| Interactions | Karma system (`Titles.AwardKarma`), `Fame` scales the gold cap; `Core.ML` removes the mounted restriction (`:75`); elf NPCs use a completely different reward path (`:133`) |
| [ERA] | `!Core.ML && from.Mounted` → refuse (`:75`) is the pre-ML rule with an in-source `TODO: guessed it's removed since ML`; the elf reward path and `1074853`/`1074854` are ML-era |
| Confidence | `[SRC]`; `[PARTIAL]` for the elf item names (in-code strings only, see below) |

**Pre-check refusals** (`:52-95`)

| Condition | Message |
|---|---|
| `targ.Player` | `500398` |
| `!targ.Body.IsHuman` | `500399` |
| `!from.InRange(targ, 2)` | `500401` (target male) / `500402` (target female) |
| `!Core.ML && from.Mounted` | `500404` |
| target is not a `Mobile` | `500399` |

**Resolution timer (2.0 s, `:109`)**

| Step | Literal | Citation |
|---|---|---|
| `badKarmaChance` | `0.5 - ((double)m_From.Karma / 8570)` | `:120` |
| No backpack and not elf | `500404` | `:122-125` |
| `Karma < 0 && badKarmaChance > RandomDouble()` | `500406` (no gold) | `:126-130` |
| Skill success, **non-elf** | `toConsume = pack gold / 10`; `max = 10 + (Fame / 2500)` clamped to `10..14`; `toConsume = min(toConsume, max)`; `ConsumeUpTo(typeof(Gold), toConsume)` | `:135-154` |
| Gold actually consumed | `500405` "I feel sorry for thee...", new `Gold(consumed)` added to the beggar's pack, drop sound played | `:156-164` |
| Nothing consumed | `500407` | `:180-188` |
| Karma loss (both paths) | `if (Karma > -3000) { toLose = Karma + 3000; if (toLose > 40) toLose = 40; Titles.AwardKarma(-toLose, true); }` | `:166-176`, `:310-320` |
| Skill success, **elf** | item table by `Utility.RandomDouble()` | `:192-308` |
| Final write | `m_From.NextSkillTime = Core.TickCount + 10000` (always, success or fail) | `:331` |

**Elf NPC reward table**

| `chance` | `Utility.Random(n)` | Item | In-code name string | Reachable? |
|---|---|---|---|---|
| `>= .99` | `Random(8)` → 0..7 | `BegBedRoll`, `BegCookies`, `BegFishSteak`, `BegFishingPole`, `BegFlowerGarland`, `BegSake`, `BegTurnip`, `BegWine` | "a bedroll", "a plate of cookies.", "a fish steak.", "a fishing pole.", "a flower garland.", "a bottle of Sake.", "a turnip.", "a Bottle of wine." | yes, all 8 |
| `>= .99` | `rand == 8` | `BegWinePitcher` | "a Pitcher of wine." | **no** — `Random(8)` never returns 8 (`Utility.cs:921-924`) |
| `>= .76` | `Random(6)` → 0..5 | `BegStew`, `BegCheeseWedge`, `BegDates`, `BegLantern`, `BegLiquorPitcher`, `BegPizza` | "a bowl of stew.", "a wedge of cheese.", "a bunch of dates.", "a lantern.", "a Pitcher of liquor", "pizza" | yes, all 6 |
| `>= .76` | `rand == 6` | `BegShirt` | "a shirt." | **no** — `Random(6)` never returns 6 |
| `>= .25` | `Random(1)` → 0 always | `BegFrenchBread` | "french bread." | yes |
| `>= .25` | `else` | `BegWaterPitcher` | "a Pitcher of water." | **no** — dead branch |
| `< .25` (and any `reward == null`) | — | `new Gold(1)` | — | yes (`:301-304`) |

`[SRC]` — the unreachable branches are a genuine source quirk (three of the sixteen elf rewards can
never be granted). A faithful clone should reproduce the reachable set unless it intends to fix the
quirk. `[PARTIAL]`: whether retail OSI used `Random(8)`/`Random(6)` inclusively is not determinable
from source — measure by begging an elf NPC N≥2000 times and recording the observed item histogram.

---

### 2.10 Herding

Source: `ServUO:Scripts/Items/Equipment/Weapons/ShepherdsCrook.cs:130-257` (+ `Scripts/Mobiles/AI/BaseAI.cs:1433-1453`) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Equipment/Weapons/ShepherdsCrook.cs

| Field | Value |
|---|---|
| Trigger | **Item double-click** on a `ShepherdsCrook` (`:130`) — Herding has no skill callback (`Server/Skills.cs:616` callback = `null`), so the skill button answers `500014` |
| Target requirements | Stage 1 `Target(10, false, TargetFlags.None)` must be a `BaseCreature` that `IsHerdable` (`:155-182`); stage 2 `Target(10, true, TargetFlags.None)` accepts a **ground point** (`:219`) |
| Skill check window | `min = m_Creature.CurrentTameSkill - 30`; `max = m_Creature.CurrentTameSkill + 30 + Utility.Random(10)` (`:229-230`); `CheckTargetSkill(Herding, m_Creature, min, max)` (`:235`) |
| Delay / cooldown | none coded — no `NextSkillTime` write, so herding is limited only by the target cursor and the creature's AI |
| Success outcome | `m_Creature.TargetLocation = p` + `502479` "The animal walks where it was instructed to." (`:242-243`) |
| Failure outcome | `502472` "You don't seem to be able to persuade that to move." (`:252`) |
| Resource consumed | none; on a Siege shard the crook's `IUsesRemaining` is checked (`:245-248`) |
| Messages / gumps | `502464` "Target the animal you wish to herd." (`:132`); `502467` "That animal looks tame already." (`:165`); `502468` "That is not a herdable animal." (`:175`); `502472` for non-creature (`:180`); `502475` "Click where you wish the animal to go." (`:169`); `502471` "That wasn't even challenging." (`:233`) |
| Interactions | keyed to **Animal Taming** via `CurrentTameSkill`; champions — champion-spawn creatures in `m_ChampTamables` are herdable even when not tameable (`:138-145`, `:194-208`); paragons are never herdable (`:186-187`) |
| [ERA] | `CurrentTameSkill` is ToL-era (pet training) but falls back to `MinTameSkill` when training is off (`BaseCreature.cs:739-754`); the champion tamables list is SE/ML-era |
| Confidence | `[SRC]` |

| Herdable test | Rule | Citation |
|---|---|---|
| IsParagon | `false` immediately | `:186-187` |
| `bc.Tamable` | `true` | `:189-190` |
| Champion spawn + type in list | `StrongMongbat, Imp, Scorpion, GiantSpider, Snake, LavaLizard, Drake, Dragon, Kirin, Unicorn, GiantRat, Slime, DireWolf, HellHound, DeathwatchBeetle, LesserHiryu, Hiryu` | `:138-145`, `:196-208` |
| else | `false` | `:210` |
| "Wasn't even challenging" | `if (max <= from.Skills[Herding].Value)` — message only, the check still runs | `:232-233` |

**Creature movement behaviour after a successful herd** (`BaseAI.cs:1433-1453`):

| Step | Rule |
|---|---|
| No target | `TargetLocation == null` → `CheckHerding()` returns `false` (creature resumes normal AI) |
| Arrived / too far | `distance < 1 \|\| distance > 15` → clear `TargetLocation`, return `false` |
| Otherwise | `DoMove(m_Mobile.GetDirectionTo(target))` and return `true` — the AI **walks one step per AI tick toward the point and stops when within 1 tile or beyond 15 tiles** |
| Priority | `CheckHerding()` is consulted from `DoOrderFollow` (`:1457`) and before wander/idle decisions (`:994`, `:1080`, `:1103`, `:1857`) — an active herd target overrides follow/wander |

---

### 2.11 Detect Hidden

Source: `ServUO:Scripts/Skills/DetectHidden.cs` (211 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/DetectHidden.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:32`) → `500819` "Where will you search?" + target; 10.0 s |
| Target requirements | `Target(12, true, TargetFlags.None)` — **ground is allowed** (`:46`); the target may be a Mobile, Item or `IPoint3D`, else the searcher's own location is used (`:54-62`) |
| Skill check window | `src.CheckSkill(DetectHidden, 0.0, 100.0)` (`:67`) — a **failed roll halves the radius** rather than aborting (`:68`) |
| Delay / cooldown | 10.0 s (`:40`) |
| Success outcome | Each hidden mobile within the radius is re-rolled individually and, on success, `RevealingAction()` + `500814` "You have been revealed!" to the target (`:96-99`); revealable items (`IRevealableItem`) are triggered (`:121-126`) |
| Failure outcome | Radius halved; then if nothing at all was found → `500817` "You can see nothing hidden there." (`:135`) |
| Resource consumed | none |
| Messages / gumps | `500819` (prompt), `500814` (revealed), `500817` (nothing found), `1153493` "Your keen senses detect something hidden in the area…" (passive, items only) |
| Interactions | **Hiding + Stealth** of the target (contested), **Tracking** (DetectHidden feeds the player-tracking formula, `Tracking.cs:244`), **Shadow Spell** mastery (`ShadowSpell.GetDifficultyFactor`), **Remove Trap** (requires `DetectHidden >= 50`, `RemoveTrap.cs:33`), **Lockpicking** (same gate), **Forensics** (`ILockpickable.Picker` is what Detect Hidden/Forensics read) |
| [ERA] | `Core.ML`-era elf +20 passive bonus (`:162-163`); `ShadowKnight` (VvV/ToL) special-cased; Felucca ruleset widens `CanDetect` (`:208`) |
| Confidence | `[SRC]` |

**Radius formula (active search)**

| Step | Literal | Citation |
|---|---|---|
| Base | `double srcSkill = src.Skills[DetectHidden].Value` | `:64` |
| Radius | `int range = Math.Max(2, (int)(srcSkill / 10.0))` ⇒ **2 tiles at 0–19, 5 at 50, 10 at 100, 12 at 120** | `:65` |
| Failed check | `range /= 2` (integer division, floor) | `:67-68` |
| House bonus | `BaseHouse.FindHouseAt(p, src.Map, 16)`; if `house.IsFriend(src)` → `range = 22` (flat override, **not** additive) | `:70-75` |
| Search | `src.Map.GetMobilesInRange(p, range)` then `src.Map.GetItemsInRange(p, range)` | `:79`, `:106` |

**Who gets revealed (active)**

| Condition | Citation |
|---|---|
| `trg.Hidden && src != trg` | `:83` |
| `ss = srcSkill + Utility.Random(21) - 10` (i.e. −10..+10) | `:85` |
| `ts = trg.Skills[Hiding].Value + Utility.Random(21) - 10` | `:86` |
| `shadow = SkillMasteries.ShadowSpell.GetDifficultyFactor(trg)` must be **beaten**: `Utility.RandomDouble() > shadow` | `:87`, `:90` |
| `src.AccessLevel >= trg.AccessLevel && (ss >= ts \|\| houseCheck)` | `:90` |
| `houseCheck = inHouse && house.IsInside(trg)` bypasses the skill comparison | `:88` |
| `ShadowKnight` skipped unless it is standing on the targeted tile | `:92-93` |
| `CanDetect(src, trg)` must be true outside a friendly house | `:93`, `:187-209` |

`CanDetect` (`:187-209`) requires: both maps valid, `src.CanBeHarmful(target, false)`, neither side
`Blessed`/invulnerable (`BaseCreature.IsInvulnerable`), `SpellHelper.ValidIndirectTarget`, and finally
either an existing aggressor/aggressed relation **or** `src.Map.Rules == MapRules.FeluccaRules`.

**Passive detect** (`DoPassiveDetect`, `:140-185`; driven from `Scripts/Mobiles/PlayerMobile.cs:2097`)

| Step | Literal | Citation |
|---|---|---|
| Guards | `src == null \|\| src.Map == null \|\| src.Location == Point3D.Zero \|\| src.IsStaff()` → return | `:142-143` |
| Skill | `double ss = src.Skills[DetectHidden].Value`; `ss <= 0` → return | `:145-148` |
| Mobile radius | `src.Map.GetMobilesInRange(src.Location, 4)` — **fixed 4 tiles** | `:150` |
| Target difficulty | `ts = (m.Skills[Hiding].Value + m.Skills[Stealth].Value) / 2` | `:160` |
| Elf | `if (src.Race == Race.Elf) ss += 20` | `:162-163` |
| **Passive chance** | `Utility.Random(1000) < (ss - ts) + 1` ⇒ probability = `((ss - ts) + 1) / 1000` per tick, i.e. **1 % per 10 points of DetectHidden advantage** | `:165` |
| Exclusions | `m == src`, `m is ShadowKnight`, `!CanDetect(src, m)` | `:157` |
| Item radius | `GetItemsInRange(src.Location, 8)` — **fixed 8 tiles**; a hit prints `1153493` | `:174-181` |

`[SRC]`. `[UNVERIFIED]`: the *tick source* of `DoPassiveDetect` is the player's own step/movement
handler; the exact cadence is not a constant in `DetectHidden.cs`. To nail the per-second passive
detect probability, measure on a live shard: log reveals per in-game second while standing still vs
walking.

---

### 2.12 Remove Trap

Source: `ServUO:Scripts/Skills/RemoveTrap.cs` (411 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/RemoveTrap.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:24`), gated **before** the target cursor; 10.0 s |
| Target requirements | `Target(2, false, TargetFlags.None)` (`:50`); accepts `TrapableContainer`, `BaseFactionTrap`, `VvVTrap`, `GoblinFloorTrap`, `IRemoveTrapTrainingKit` |
| Skill check window | `CheckTargetSkill(RemoveTrap, targ, targ.TrapPower, targ.TrapPower + 10)` (`:111`) — **dynamic window driven by the trap**, not a fixed constant |
| Delay / cooldown | 10.0 s (`:44`); the treasure-chest path also re-arms `NextSkillTime` when the player is out of range (`:238-243`) |
| Success outcome | `targ.TrapPower = 0; targ.TrapLevel = 0; targ.TrapType = TrapType.None; InvalidateProperties()` + `502377` "You successfully render the trap harmless" (`:113-117`) |
| Failure outcome | `502372` "You fail to disarm the trap... but you don't set it off" (`:121`) — the skill **never** triggers the trap; only `VvVTrap` and the treasure-chest guardian path can hurt you |
| Resource consumed | Faction traps: one `FactionTrapRemovalKit` charge (`:167-168`). Treasure chests: none |
| Messages / gumps | Skill gate `502366` "You do not know enough about locks…" / `502367` "You are not perceptive enough…"; prompt `502368` "Wich trap will you attempt to disarm?" *(sic)*; Mobile target `502816`; locked container `501283`; untrapped `502373`; faction messages `1010538`/`1010537`/`1042530`; VvV `1155496`; chest `1159010`/`1159059`/`1159063`/`1159060`/`1159057`/`1159058`/`1159061`/`1159009` |
| Interactions | **Lockpicking ≥ 50.0 and Detect Hidden ≥ 50.0 are hard prerequisites** (`:29-36`); **Tinkering 80–100** is required *in addition* for faction traps (`:148`); **Magery** — the 2nd-circle `Remove Trap` spell clears traps with **no** Remove Trap skill at all (see below); Forensics reads `ILockpickable.Picker` |
| [ERA] | `!Core.EJ` guards the Lockpicking/Detect Hidden prerequisites (`:29`,`:33`) — Endless Journey accounts skip them; `Core.ML && isOwner` lets the faction-trap owner disarm for free (`:148`); the treasure-chest manipulation minigame is SA/TreasureMap-revamp (`TreasureMapInfo.NewSystem`, `:78`); VvV (`:171`) is ToL-era |
| Confidence | `[SRC]` |

**Pre-target gates** (`OnUse`, `:27-45`)

| Condition | Result |
|---|---|
| `!Core.EJ && Lockpicking.Value < 50` | `502366`, **no cursor**, 10 s cooldown |
| `!Core.EJ && DetectHidden.Value < 50` | `502367`, **no cursor**, 10 s cooldown |
| else | `502368` + `InternalTarget` |

**Trap types (`TrapType`)** — `Scripts/Items/Containers/TrapableContainer.cs:5-12`:

| Value | Name | Effect on open (`ExecuteTrap`) | Citation |
|---|---|---|---|
| 0 | `None` | nothing | `:74` |
| 1 | `MagicTrap` | `from.Damage(TrapPower)` if `InRange(loc, 1)`; 5 explosion effects + sound `0x307` | `:111-128` |
| 2 | `ExplosionTrap` | if `InRange(loc, 3)`: `damage = TrapLevel > 0 ? RandomMinMax(10,30) * TrapLevel : TrapPower`, applied as 100 % fire | `:87-110` |
| 3 | `DartTrap` | if `InRange(loc, 3)`: `damage = TrapLevel > 0 ? RandomMinMax(5,15) * TrapLevel : TrapPower`, 100 % physical; sound `0x223` | `:129-151` |
| 4 | `PoisonTrap` | if `InRange(loc, 3)`: `TrapLevel > 0 ? Poison.GetPoison(clamp(TrapLevel-1, 0, 4)) : Poison.Greater` + `ApplyPoison` | `:152-180` |
| — | After firing | `TrapType = None; TrapPower = 0; TrapLevel = 0` (trap is consumed) | `:183-185` |

**Handler branches**

| Target | Behaviour | Citation |
|---|---|---|
| `Mobile` | `502816` "You feel that such an action would be inappropriate" | `:56-59` |
| `IRemoveTrapTrainingKit` | delegates to `OnRemoveTrap(from)` | `:60-63` |
| `LockableContainer && Locked` | `501283` "That is locked." | `:64-67` |
| `TrapableContainer`, `TrapType == None` | `502373` "That doesn't appear to be trapped" | `:74-77` |
| `TreasureMapChest` (new t-map system) | owner check `1159010`; `IsDisarming` → `1159059`; `IsBeingDisarmed` → `1159063`; live `AncientGuardians` → `1159060` + fail; else `1159057` + `StartChestDisarmTimer` | `:78-106` |
| `TrapableContainer` (normal) | `CheckTargetSkill(RemoveTrap, targ, TrapPower, TrapPower + 10)`; success zeroes the trap, failure `502372` | `:107-123` |
| `BaseFactionTrap` | `faction == null` → `1010538`; own faction & !owner → `1010537`; !owner & no kit → `1042530`; else `(Core.ML && isOwner) \|\| (RemoveTrap 80–100 && Tinkering 80–100)` → `DisarmMessage` + faction silver + `trap.Delete()`; failure `502372`; kit charge consumed | `:125-170` |
| `VvVTrap` | must be a VvV participant (`1155496`); success condition `from == trap.Owner \|\| ((RemoveTrap.Value - 80.0) / 20.0) > Utility.RandomDouble()` (⇒ **0 % at 80, 100 % at 100, linear between**); produces a `VvVTrapKit`; else `if (.1 > Utility.RandomDouble()) trap.Detonate(from)` | `:171-208` |
| `GoblinFloorTrap` | `InRange(3)` → optional `FloorTrapComponent` if unowned, `targ.Delete()`, `502377` | `:209-228` |
| anything else | `502373` | `:229-232` |

**Treasure chest manipulation minigame** (`RemoveTrapTimer`, `:303-410`)

| Element | Literal | Citation |
|---|---|---|
| Timer | `base(TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(10))`, started in ctor | `:313-314`, `:337` |
| "GM remover" | `from.Skills[RemoveTrap].Value >= 100` (passed as `gmRemover`) | `:263` |
| Safety window (GM remover) | `Stash 20 s, Supply 60 s, Cache 180 s, Hoard 420 s, Trove 540 s` added to `Chest.DigTime` | `:324-334` |
| GM remover roll | after the safety window: `CheckTargetSkill(RemoveTrap, Chest, 80, 120 + (Chest.Level * 10))`; inside the window a success disarms, a failure spawns an `AncientGuardian` | `:356-374` |
| Normal remover | `min = (double)Math.Ceiling(From.Skills[RemoveTrap].Value * .75)`; window `(min, min > 50 ? min + 50 : 100)` | `:382-384` |
| Failure | `Chest.SpawnAncientGuardian(From)` + `1159057` if still alive | `:391-396` |
| Abort conditions | chest deleted; `!From.Alive` → `1159061`; `!InRange(GetWorldLocation(), 16)` → `1159058` | `:342-355` |
| Disarm | `TrapPower = 0; TrapLevel = 0; TrapType = None; InvalidateProperties()` + `1159009` "You successfully disarm the trap!" | `:401-409` |

**Magery interaction (the `Remove Trap` spell, 2nd circle)** — `Scripts/Spells/Second/RemoveTrap.cs`:

| Element | Value | Citation |
|---|---|---|
| Reagents | `Reagent.Bloodmoss`, `Reagent.SulfurousAsh` | `:13-14` |
| Circle | `SpellCircle.Second` | `:20-26` |
| Target | `TrapableContainer` within `Core.ML ? 10 : 12` tiles | `:63`, `:70-72` |
| Restriction | `item.TrapType != TrapType.None && item.TrapType != TrapType.MagicTrap` → **`DoFizzle()`** — the spell only works on `MagicTrap` (and no-ops on `None`) | `:38-41` |
| Effect | `TrapType = None; TrapPower = 0; TrapLevel = 0` — no Remove Trap skill check, no skill gain | `:51-53` |
| Non-container | `501856` "That isn't trapped." | `:76` |

`[SRC]`. There is **no** code path where Magery increases the Remove Trap skill check; the only
Magery synergy is the separate spell above. `[PARTIAL]`: the classic claim that the spell requires
`Detect Hidden` is not in this source.

---

### 2.13 Poisoning

Source: `ServUO:Scripts/Skills/Poisoning.cs` (172 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Poisoning.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:11`) → `502137` "Select the poison you wish to use"; 10.0 s |
| Target requirements | Stage 1 `Target(2, false, TargetFlags.None)` must be a `BasePoisonPotion` (`:32`); stage 2 `Target(2, false, TargetFlags.None)` must be `Food`, `FukiyaDarts`, `Shuriken`, or a weapon that qualifies (`:52-76`) |
| Skill check window | `CheckTargetSkill(Poisoning, m_Target, potion.MinPoisoningSkill, potion.MaxPoisoningSkill)` (`:116`) — window comes from the **potion class**, see table below |
| Delay / cooldown | 10.0 s (`:20`); plus a **2.0 s application timer** before the roll (`:104`) |
| Success outcome | `Food.Poison = m_Poison`; `BaseWeapon.Poison` + `PoisonCharges = 18 - (m_Poison.RealLevel * 2)`; darts/shuriken charges `Math.Min(18 - RealLevel*2, UsesRemaining)`; `1010517` "You apply the poison"; **Karma −20** | `:118-140` |
| Failure outcome | At `Poisoning.Base < 80.0`, a **5 % chance** (`Utility.Random(20) == 0`) to poison yourself: `502148` "You make a grave mistake while applying the poison." + `ApplyPoison(self, m_Poison)`. Otherwise `1010516` (slashing weapon) or `1010518` (everything else) | `:143-165` |
| Resource consumed | **The potion is consumed when the 2-second timer starts** (`:83`) — i.e. a failed skill check still costs the potion. A `Bottle` is added to the backpack (`:84`). Sound `0x4F` |
| Messages / gumps | `502137`, `502142` "To what do you wish to apply the poison?", `502139` "That is not a poison potion.", `502145` (pre-AoS) / `1060204` (AoS) "You cannot poison that!…", `1010517`, `1010516`, `1010518`, `502148` |
| Interactions | **Taste ID** detects the result (`TasteID.cs:47`); **Arms Lore** shows `1038284` when `PoisonCharges > 0`; **Infectious Strike** weapon ability is the AoS gate for poisoning a weapon (`:69`); poison levels/messages come from `Server/Poison.cs`; `AwardKarma` from `Scripts/Misc/Titles.cs` |
| [ERA] | AoS: only weapons whose `PrimaryAbility`/`SecondaryAbility` is `InfectiousStrike` can be poisoned and the refusal text is `1060204` (`:67-69`, `:88-89`). Pre-AoS: **any one-handed Slashing or Piercing** weapon (`:71-75`) and text `502145` |
| Confidence | `[SRC]` |

**Poison-level-from-skill table (which potion you can apply at which skill)**

| Potion class | `Poison` | `MinPoisoningSkill` | `MaxPoisoningSkill` | Citation |
|---|---|---|---|---|
| `LesserPoisonPotion` | `Poison.Lesser` | `0.0` | `60.0` | `LesserPoisonPotion.cs:22`,`:29`,`:36` |
| `PoisonPotion` | `Poison.Regular` | `30.0` | `70.0` | `PoisonPotion.cs:22`,`:29`,`:36` |
| `GreaterPoisonPotion` | `Poison.Greater` | `60.0` | `100.0` | `GreaterPoisonPotion.cs:22`,`:29`,`:36` |
| `DeadlyPoisonPotion` | `Poison.Deadly` | `80.0` | `100.0` | `DeadlyPoisonPotion.cs:22`,`:29`,`:36` |
| `DarkglowPotion` / `ParasiticPotion` | `Poison.DarkGlow` / `Poison.Parasitic` | declared as overrides at `DarkglowPotion.cs:26`,`:33` and `ParasiticPotion.cs:26`,`:33` — **values not read in this pass** (`[PARTIAL]`; read those two files before transcribing the window) | as cited |
| (no `LethalPoisonPotion` exists in `pub57` — `Poison.Lethal` is spell/monster-only) | — | — | — | `[SRC]` grep of `: BasePoisonPotion` |

**Effective success chance** = `(Poisoning.Value - Min) / (Max - Min)` (`SkillCheck.cs:306`), with the
two short-circuits: `< Min` → automatic fail, `>= Max` → automatic success.

**Poison charges on a weapon** = `18 - (poison.RealLevel * 2)`:

| Poison | `RealLevel` | Charges |
|---|---|---|
| Lesser | 0 | 18 |
| Regular | 1 | 16 |
| Greater | 2 | 14 |
| Deadly | 3 | 12 |
| Lethal | 4 | 10 |

`RealLevel` mapping is `Level` for 0–9, `Level - 10` for 10–13 (Darkglow), `Level - 14` for ≥14
(Parasitic) — `Scripts/Misc/Poison.cs:89-105`.

**Poison damage model (for reference)** — `Scripts/Misc/Poison.cs:21-36`:

| Era | Poison | Level | min | max | scalar (% of target Hits) | delay | interval | count | messageInterval |
|---|---|---|---|---|---|---|---|---|---|
| AoS | Lesser | 0 | 4 | 16 | 7.5 | 3.0 | 2.25 | 10 | 4 |
| AoS | Regular | 1 | 8 | 18 | 10.0 | 3.0 | 3.25 | 10 | 3 |
| AoS | Greater | 2 | 12 | 20 | 15.0 | 3.0 | 4.25 | 10 | 2 |
| AoS | Deadly | 3 | 16 | 30 | 30.0 | 3.0 | 5.25 | 15 | 2 |
| AoS | Lethal | 4 | 20 | 50 | 35.0 | 3.0 | 5.25 | 20 | 2 |
| pre-AoS | Lesser | 0 | 4 | 26 | 2.500 | 3.5 | 3.0 | 10 | 2 |
| pre-AoS | Regular | 1 | 5 | 26 | 3.125 | 3.5 | 3.0 | 10 | 2 |
| pre-AoS | Greater | 2 | 6 | 26 | 6.250 | 3.5 | 3.0 | 10 | 2 |
| pre-AoS | Deadly | 3 | 7 | 26 | 12.500 | 3.5 | 4.0 | 10 | 2 |
| pre-AoS | Lethal | 4 | 9 | 26 | 25.000 | 3.5 | 5.0 | 10 | 2 |
| ML Darkglow | 10–13 | 10–13 | as AoS Lesser..Deadly | | | | | | 4/3/2/2 |
| ML Parasitic | 14–18 | 14–18 | as AoS Lesser..Lethal | | | | | | 4/3/2/2/2 |

Per-tick damage: `damage = 1 + (int)(target.Hits * scalar)`, clamped to `[min, max]`; pre-AoS
re-uses the previous tick's damage 50 % of the time (`Scripts/Misc/Poison.cs:216-230`).
Darkglow ×1.1 when the poisoner is >1 tile away (`:252-256`); Parasitic heals the poisoner when
adjacent (`:258-267`).

---

### 2.14 Meditation

Source: `ServUO:Scripts/Skills/Meditation.cs` (106 lines) + `ServUO:Scripts/Misc/RegenRates.cs` (315 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Meditation.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[46]` (`Meditation.cs:10`); **no target** |
| Target requirements | none; the branch order is the whole behaviour (see below) |
| Skill check window | `m.CheckSkill(SkillName.Meditation, 0.0, 100.0)` (`:86`) — only reached if the **direct chance** roll passes |
| Delay / cooldown | 10.0 s on the normal path (`:102`); 5.0 s if busy (`:38`) or pre-AoS low HP (`:44`); 5.0 s pre-AoS / 10.0 s AoS when already full (`:50`); 10.0 s if AoS armour blocks (`:56`); 2.5 s if hands are full (`:75`) |
| Success outcome | `501851` "You enter a meditative trance."; `m.Meditating = true`; `BuffInfo` `BuffIcon.ActiveMeditation` / `1075657`; sound `0xF9`; `m.ResetStatTimers()` (`:88-95`) |
| Failure outcome | `501850` "You cannot focus your concentration." (`:99`) |
| Resource consumed | none |
| Messages / gumps | `501845` "You are busy doing something else and cannot focus."; `501849` "The mind is strong but the body is weak."; `501846` "You are at peace."; `500135` "Regenative forces cannot penetrate your armor!"; `502626` "Your hands must be free to cast spells or meditate."; `500134` "You stop meditating." (`Server/Mobile.cs:12651`) |
| Interactions | **Focus** synergy in every regen formula; **armour** (`GetArmorOffset`); **Spell Channeling / Mage Armor** properties; `DisruptiveAction()` breaks the trance on any skill use (`Server/Skills.cs:914` → `Server/Mobile.cs:12646-12653`); AoS `CheckOkayHolding` allows `Spellbook`/`Runebook` and (AoS) Spell-Channelling weapons/armour (`Meditation.cs:13-28`) |
| [ERA] | The **entire** mana-regen formula forks on `Core.ML` → `Core.AOS` → pre-AoS (`RegenRates.cs:121`,`:154`,`:179`); pre-AoS low-HP gate exists only `!Core.AOS` (`:40`); the hands-full behaviour differs (AoS auto-stows items, pre-AoS refuses) (`:63-76`) |
| Confidence | `[SRC]` |

**Branch order and the trance chance**

| Step | Condition | Result |
|---|---|---|
| 1 | `m.Target != null` | `501845`, 5.0 s |
| 2 | `!Core.AOS && m.Hits < (m.HitsMax / 10)` | `501849`, 5.0 s |
| 3 | `m.Mana >= m.ManaMax` | `501846`, `Core.AOS ? 10.0 : 5.0` s |
| 4 | `Core.AOS && RegenRates.GetArmorOffset(m) > 0` | `500135`, 10.0 s |
| 5 | AoS player with a non-allowed item in `Layer.OneHanded`/`TwoHanded` | item is moved to the backpack (no penalty) |
| 6 | pre-AoS and either hand holds a disallowed item | `502626`, 2.5 s |
| 7 | **trance chance** `chance = (50.0 + ((skillVal - (m.ManaMax - m.Mana)) * 2)) / 100` where `skillVal = Skills[Meditation].Value` | if `chance > Utility.RandomDouble()` → success path; else `501850`; **always 10.0 s** |

`[SRC]` — `Meditation.cs:34-103`. The chance formula is `:79`; `CrystalBallOfKnowledge.TellSkillDifficultyActive` is fed the raw chance (`:82`).

**Armour malus (`GetArmorOffset`)** — `RegenRates.cs:36-51`, `:298-313`:

| Step | Rule |
|---|---|
| Slots summed | shield **only when `!Core.AOS`**, then Neck, Gloves, Helm, Arms, Legs, Chest |
| Per-piece (`GetArmorMeditationValue`) | `MageArmor != 0` **or** `SpellChanneling != 0` → `0.0`; `MeditationAllowance.None` → `BaseArmorRatingScaled`; `.Half` → `BaseArmorRatingScaled / 2.0`; `.All` → `0.0` |
| Total | `return rating / 4` |

**Mana regeneration rate — exact code, all three eras** (`RegenRates.cs:110-209`; the returned value
is a `TimeSpan` = seconds **per mana point**, so smaller = faster):

Pre-AoS (`:179-201`):
```
medPoints = (Int + Meditation.Value) * 0.5
if medPoints <= 0        rate = 7.0
else if medPoints <= 100 rate = 7.0 - (239 * medPoints / 2400) + (19 * medPoints * medPoints / 48000)
else if medPoints < 120  rate = 1.0
else                     rate = 0.75
rate += armorPenalty
if Meditating  rate *= 0.5
clamp rate to [0.5, 7.0]
```

AoS (`:154-178`):
```
medPoints = Int + (Meditation.Value * 3)
medPoints *= (Meditation.Value < 100.0) ? 0.025 : 0.0275
focusPoints = Focus.Value * 0.05
if armorPenalty > 0  medPoints = 0            // any blocking armour removes the meditation bonus entirely
totalPoints = focusPoints + medPoints + (Meditating ? min(medPoints, 13.0) : 0.0)
totalPoints += ManaRegen(from)                // item property + creature base + form bonuses
if totalPoints < -1  totalPoints = -1
rate = 1.0 / (0.1 * (2 + totalPoints))
```

ML (`:121-153`):
```
focusBonus = Focus.Value / 200
if armorPenalty == 0:
    medBonus = (0.0075 * Meditation.Value) + (0.0025 * Int)
    if medBonus >= 100.0  medBonus *= 1.1
    if Meditating         medBonus *= 2
itemBase     = ((((Meditation.Value / 2) + (Focus.Value / 4)) / 90) * .65) + 2.35
intensity    = min(sqrt(ManaRegen(from)), 5.5)
itemBonus    = ((itemBase * intensity) - (itemBase - 1)) / 10
rate = 1.0 / (0.2 + focusBonus + medBonus + itemBonus)
```

| Supporting constant | Value | Citation |
|---|---|---|
| `Mobile.DefaultManaRate` | 7.0 s | `RegenRates.cs:25` |
| Passive gain while **not** meditating | `CheckBonusSkill(from, from.Mana, from.ManaMax, SkillName.Meditation)` → `CheckSkill(Meditation, n)` where `n = (Mana/ManaMax) * (1 - sqrt(Meditation*0.005)) + sqrt(Meditation*0.005)` | `:115-116`, `:53-65` |
| `ManaRegen(from)` item/creature points | `AosAttributes.GetValue(RegenMana)` + creature `DefaultManaRegen` + Vampiric Embrace `+3` / Lich Form `+13` + gargoyle `+2`; capped at 18 (`!Core.ML`) | `:274-296` |
| NaN guard | any NaN rate → `DefaultManaRate` | `:203-206` |

`[SRC]` for every expression above. `[ERA]`: pre-AoS has **no** Focus term at all (Focus is an AoS
skill) — the AoS/ML branches add it. `[PARTIAL]`: the classic retail "meditation must be re-toggled"
behaviour is not modelled; the trance is a server flag cleared by `DisruptiveAction`.

---

### 2.15 Spirit Speak

Source: `ServUO:Scripts/Skills/SpiritSpeak.cs` (242 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/SpiritSpeak.cs

| Field | Value |
|---|---|
| Trigger | Skill button — `SkillInfo.Table[32]` (`:17`); **no target** |
| Target requirements | none by cursor. AoS path scans `Caster.GetObjectsInRange(3)` for a `Corpse` that is `!Channeled && !Animated` — first match wins (`:163-171`) |
| Skill check window | AoS: `CheckSkill(SpiritSpeak, 0.0, 120.0)` (`:209`). pre-AoS: `CheckSkill(SpiritSpeak, 0, 100)` (`:40`) |
| Delay / cooldown | AoS: 5.0 s (`:32`), or 0 if already in a trance/casting (`:35`). pre-AoS: 1.0 s (`:66`) |
| Success outcome | AoS: heals `Utility.RandomMinMax(min, max)` with `min = 1 + (int)(Value * 0.25)`, `max = min + 4` (`:190-197`, `:231`); corpse is marked `Channeled = true` and hued `0x835` (`:219-220`); particles `0x375A` layer Waist (`:233`). pre-AoS: `CanHearGhosts = true` for 15 s–3 min (`:42-58`) |
| Failure outcome | AoS: `502443` "You fail your attempt at contacting the netherworld." (`:213`). Not enough mana: `1061285` "You lack the mana required to use this skill." (`:205`). pre-AoS: `502443` + `CanHearGhosts = false` (`:62-63`) |
| Resource consumed | AoS: **10 mana** if no corpse in range (`:199`), **0 mana** if a corpse is in range (`:193`); the corpse is "spent" (`Channeled = true`) |
| Messages / gumps | `1062074` "Anh Mi Sah Ko" (overhead, `:94`); `1061287` "You channel energy from a nearby corpse to heal your wounds."; `1061286` "You channel your own spiritual energy to heal your wounds."; `502444` "You contact the neitherworld."; `502443`; `502445` "You feel your contact with the neitherworld fading."; `502642` "You are already casting a spell."; `500641` "Your concentration is disturbed, thus ruining thy spell." |
| Interactions | **Necromancy** — Spirit Speak *is* the damage skill of every necromancy spell (`Scripts/Spells/Necromancy/NecromancerSpell.cs:26`); it gates familiar strength (`SummonFamiliar.cs:181`,`:209`), `AnimateDead` (`AnimateDeadSpell.cs:330`), `Strangle` (`:120`,`:179`), `Evil Omen` duration (`EvilOmen.cs:132`), `Curse Weapon` duration (`CurseWeapon.cs:67`), `Revenant` summon scalar (`Revenant.cs:22`); **ghost speech** — see below; **Skill Masteries** `Conduit` (`Scripts/Spells/Skill Masteries/Conduit.cs:30`) and `Command Undead` (`CommandUndead.cs:27`) declare `DamageSkill = SpiritSpeak` |
| [ERA] | `Core.AOS` completely replaces the skill: the pre-AoS "hear ghosts for a while" path is dead on AoS+ (`:24-36` returns before it). The trance heal (self-heal from a corpse) is the AoS+ behaviour. `Core.ML && SpiritSpeak >= 100.0` lets a **dead** player speak normally (`PlayerMobile.cs:4223`) |
| Confidence | `[SRC]` |

**AoS trance timer (1 s, one shot)** — `SpiritSpeakTimerNew` (`:148-240`):

| Step | Literal | Citation |
|---|---|---|
| Freeze on begin | `m.Freeze(TimeSpan.FromSeconds(1))`, `Animate(AnimationType.Spell, 1)`, sound `0x24A` | `:91-95` |
| Re-entry guard | `_Table.ContainsKey(m)` → `BeginSpiritSpeak` returns false, no mana spent | `:89`, `:104` |
| min/max heal | `min = 1 + (int)(Value * 0.25)`; `max = min + 4` (0 skill → 1..5; 100 → 26..30; 120 → 31..35) | `:190-191`, `:197-198` |
| Mana cost | `0` with corpse, `10` without | `:193`, `:199` |
| Failure roll | `if (Utility.RandomDouble() > (Value / 100.0))` → fail ⇒ **success probability = SpiritSpeak.Value / 100** (0 % at 0, 100 % at ≥100) | `:211` |
| Heal clamp | `if (min > max) min = max;` then `Caster.Hits += RandomMinMax(min, max)` | `:226-231` |
| Disruption | on damage: `500641`, effect `0x3735`/`0x5C`, `NextSkillTime = Core.TickCount`, trance removed | `:127-146` |

**pre-AoS "hear ghosts" duration** — `secs = (SpiritSpeak.Base / 50) * 90`, floored at 15 s
(`:45-52`) ⇒ **15 s at ≤8.3 skill, 90 s at 50, 180 s at 100, 216 s at 120** (the timer's declared
default of 2 min at `:74` is overwritten by `t.Delay = …` at `:52`).

**Speak-with-the-dead behaviour**

| Rule | Code | Citation |
|---|---|---|
| A living mobile hears ghost speech only if `CanHearGhosts` | `CheckHearsMutatedSpeech`: `return (m.Alive && !m.CanHearGhosts)` | `Server/Mobile.cs:4956-4964` |
| `CanHearGhosts` source | `m_CanHearGhosts \|\| IsStaff()` | `Server/Mobile.cs:12798` |
| Dead player's own speech is not mutated (i.e. everyone hears it normally) if `Core.ML && SpiritSpeak >= 100.0` | `PlayerMobile.MutateSpeech` | `PlayerMobile.cs:4223-4226` |
| On AoS, a **hearer** with `SpiritSpeak >= 100.0` un-mutates the ghost's speech | `PlayerMobile.cs:4228-4239` | as cited |
| pre-AoS | no 100-skill exemption; instead `CanHearGhosts` is the only channel | `SpiritSpeak.cs:38-66` |

`[SRC]`. `[ERA]` summary: pre-AoS = timed `CanHearGhosts` buff, 100-skill exemption absent;
AoS = corpse-channel self-heal, ghost speech still gated on the flag; ML = 100 Spirit Speak grants
permanent ghost speech.

---

### 2.16 Animal Taming

Source: `ServUO:Scripts/Skills/AnimalTaming.cs` (490 lines) + `Scripts/Mobiles/Normal/BaseCreature.cs` · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/AnimalTaming.cs

| Field | Value |
|---|---|
| Trigger | Skill button (`:31`) + `RevealingAction` (`:36`) → `502789` "Tame which animal?"; the target is installed via `Timer.DelayCall` when `DeferredTarget` (default `true`, `:25`, `:43-50`) |
| Target requirements | `Target(Core.AOS ? 3 : 2, false, TargetFlags.None)` with a **30 s** `BeginTimeout` (`:122-126`) |
| Skill check window | `CheckTargetSkill(AnimalTaming, m_Creature, minSkill - 25.0, minSkill + 25.0)` where `minSkill = CurrentTameSkill + Owners.Count * 6.0`, then `minSkill += 24.9` (`:402-413`) |
| Delay / cooldown | 40.0 s from the callback (`:53`); the target attempt itself suppresses the `NextSkillTime` reset (`m_SetSkillTime = false`, `:240`) so the 40 s survives a successful start. Every abort path explicitly writes `NextSkillTime = Core.TickCount` (`:298`,`:306`,`:314`,`:322`,`:330`,`:338`,`:346`,`:354`,`:389`) |
| Success outcome | Creature scaled (table below), `SetControlMaster(tamer)`, `IsBonded = false`, `Owners.Add(tamer)`, `OnAfterTame`, `PetTrainingHelper…OnTame()`, `EventSink.InvokeTameCreature` (`:437-459`); `502799` "It seems to accept you as master." — or `502797` "That wasn't even challenging." for an already-owned pet (`:439-444`) |
| Failure outcome | `502798` "You fail to tame the creature." (`:464`); the creature keeps its tame difficulty and the tame skill is rolled again on the next attempt |
| Resource consumed | none (no item); the attempt occupies the 40 s skill timer |
| Messages / gumps | `502789`, `1010597` "You start to tame the creature." (local) + `1010598` "*begins taming a creature.*" (nonlocal) (`:244-245`); the mid-tame chatter set `502790+0..3`, `1005608+0..5`, `1010593+0..3` (`:363-374`); aborts `502795` too far, `502796` dead, `1049654` no path, `1049655` not tamable, `502804` already tame, `1005615` too many owners, `1054025` must subdue, `502794` too angry, `502802` someone else is taming, `502805` "You seem to anger the beast!", `502806` no chance, `1049653`/`1049652` gender-locked, `502801` can't tame that, `1049611` too many followers, `1042590` faction mismatch |
| Interactions | **Animal Lore** gains passively on every tick and on the final roll (`:376-379`, `:397-400`); **Necromancy** `DarkWolfFamiliar.CheckMastery` sets the required skill to −24.9 (i.e. success at 0.0) (`:184`, `:403-410`); **Bard** pacification is cancelled on anger (`:212-224`); **Honor** / Spellweaving `Ethereal Voyage` suppress the aggro response (`:231-236`); Followers/`FollowersMax` gate (`:170-173`) |
| [ERA] | Target range 2 pre-AoS / 3 AoS (`:123`); tame **range to continue** 6 pre-AoS / 7 AoS (`:295`); `Core.SA` skips the bard-pacify juggling (`:212`); `Core.TOL` changes skill scaling (`:104`); `Core.SE` `MaxOwners` (`:174`); rideable-creature subdue rules |
| Confidence | `[SRC]` |

**Pre-flight rejections (`OnTarget`, `:140-266`)**

| Order | Condition | Message | Citation |
|---|---|---|---|
| 1 | `!creature.Tamable` (i.e. `m_bTamable == false` **or Paragon**, `BaseCreature.cs:3818`) | `1049655` "That creature cannot be tamed." | `:146-150` |
| 2 | `creature.Controlled` | `502804` "That animal looks tame already." | `:151-155` |
| 3 | `from.Female && !creature.AllowFemaleTamer` | `1049653` "…can only be tamed by males." | `:156-160` |
| 4 | `!from.Female && !creature.AllowMaleTamer` | `1049652` "…can only be tamed by females." | `:161-165` |
| 5 | `creature is CuSidhe && from.Race != Race.Elf` | `502801` "You can't tame that!" | `:166-169` |
| 6 | `from.Followers + creature.ControlSlots > from.FollowersMax` | `1049611` "You have too many followers to tame that creature." | `:170-173` |
| 7 | `Owners.Count >= BaseCreature.MaxOwners` (5) and not already an owner | `1005615` "This animal has had too many owners…" | `:174-178` |
| 8 | `MustBeSubdued(creature)` | `1054025` "You must subdue this creature before you can tame it!" | `:179-183` |
| 9 | `Taming.Value < creature.CurrentTameSkill` and no necro mastery | `502806` "You have no chance of taming this creature." | `:184`, `:250-254` |
| 10 | `FactionWarHorse` with wrong/absent faction | `1042590` "You cannot tame this creature." | `:186-198` |
| 11 | already in `m_BeingTamed` | `502802` "Someone else is already taming this." | `:200-204` |
| 12 | `CanAngerOnTame && 0.95 >= RandomDouble()` | `502805` "You seem to anger the beast!" + aggro (see below) | `:205-237` |
| 13 | non-`BaseCreature` Mobile | `502469` "That being cannot be tamed." | `:256-260` |
| 14 | not a Mobile | `502801` | `:262-265` |

`MustBeSubdued` = `Owners.Count == 0 && SubdueBeforeTame && Hits > (HitsMax / 10)` (`:56-63`).
`CanAngerOnTame` defaults `false` (`BaseCreature.cs:3287`) and is overridden `true` by BloodFox,
ColdDrake, CuSidhe, Dragon, DragonWolf, DreadSpider, DreadWarhorse, FrostDragon, FrostMite,
GreaterDragon, Hiryu, LesserHiryu, Lion, Nightmare, OsseinRam, Phoenix, Reptalon, RuneBeetle,
SabertoothedTiger, SerpentineDragon, ShadowWyrm, Skree, StygianDrake, SwampDragon, Triceratops,
TsukiWolf, WhiteWyrm.
`SubdueBeforeTame` is `true` for Beetle, FireBeetle, GiantIceWorm, IronBeetle (5–10 % HP first).

**Taming timer** (`InternalTimer`, `:268-487`)

| Element | Literal | Citation |
|---|---|---|
| Timer | `base(TimeSpan.FromSeconds(3.0), TimeSpan.FromSeconds(3.0), count)` — one roll window every 3 s | `:278` |
| `count` | `Utility.Random(3, 2)` ⇒ **3 or 4** (never 2) ⇒ total attempt 9–12 s | `:247`, `Utility.cs:905` |
| Range | `m_Tamer.InRange(m_Creature, Core.AOS ? 7 : 6)` | `:295` |
| Chatter | `Utility.Random(3)` selects one of three overhead banks; each bank id is `Random(base, count)` | `:363-374` |
| Passive Animal Lore | `if (!alreadyOwned) CheckTargetSkill(AnimalLore, creature, 0.0, 120.0)` on every tick and once at the end | `:376-379`, `:397-400` |
| Final window | `minSkill = CurrentTameSkill + (Owners.Count * 6.0)`; if necro mastery and `minSkill > -24.9` → `minSkill = -24.9`; then `minSkill += 24.9` ⇒ a **50-point-wide window centred on the adjusted requirement** | `:402-413` |

**Re-tame / ownership scaling** — the `minSkill` used for the roll includes
`Owners.Count * 6.0`, i.e. **each previous owner adds +6.0 to the effective taming requirement**
(`:402`; also `BaseCreature.MaxOwners = 5` at `:1176`, so up to +24.0).

**Stat/skill scaling applied on a successful tame** (`:415-435`, `ScaleStats :65-93`, `ScaleSkills :95-116`):

| Case | Scalar | Citation |
|---|---|---|
| `GreaterDragon`, first tame | `ScaleSkills(0.72, capScalar 0.90, firstTame)` + `Magery.Base = Magery.Cap` | `:417-422` |
| Creature was paralyzed at any tick and this is the first tame | `ScaleSkills(0.86, true)` | `:423-426` |
| Otherwise first tame | `ScaleSkills(0.90, true)` | `:427-430` |
| Re-tame (already in `Owners`) | `ScaleSkills(0.90, false)` | `:432-435` |
| Effect on stats | `RawStr/RawDex/RawInt/HitsMaxSeed/StamMaxSeed *= scalar`, each floored at 1 | `:65-93` |
| Effect on skills | `Cap = max(100.0, Base * capScalar)` then `Base *= scalar`; if `Base > Cap` then `Cap = Base` | `:100-116` |

**Tame difficulty / control slots / mount flag per creature** — `[SRC]`, one row per creature that
sets `MinTameSkill` in `Scripts/Mobiles/Normal` (default `ControlSlots = 1`,
`BaseCreature.cs:281`; "Mount" = the class is declared `: BaseMount`). All `MinTameSkill` values are
`<file>.cs:<line>` with line numbers from the grep of `MinTameSkill\s*=`; `ControlSlots` line
numbers are from the grep of `ControlSlots\s*=` in the same folder.

| Creature | MinTameSkill | ControlSlots | Mount | Source |
|---|---|---|---|---|
| Dog | −21.3 | 1 | — | `Dog.cs:41`, `:40` |
| Ferret | −21.3 | 1 | — | `Ferret.cs:45`, `:44` |
| Squirrel | −21.3 | 1 | — | `Squirrel.cs:37`, `:36` |
| Gorilla | −18.9 | 1 | — | `Gorilla.cs:42`, `:41` |
| JackRabbit | −18.9 | 1 | — | `JackRabbit.cs:41`, `:40` |
| Mongbat | −18.9 | 1 | — | `Mongbat.cs:40`, `:39` |
| Rabbit | −18.9 | 1 | — | `Rabbit.cs:42`, `:41` |
| SkitteringHopper | −12.9 | 1 | — | `SkitteringHopper.cs:39`, `:38` |
| Bird | −6.9 | 1 | — | `Bird.cs:57`/`:138`, `:56`/`:137` |
| Cat | −0.9 | 1 | — | `Cat.cs:43`, `:42` |
| Chicken | −0.9 | 1 | — | `Chicken.cs:40`, `:39` |
| ClanRibbonPlagueRat | −0.9 | 1 | — | `ClanRibbonPlagueRat.cs:46`, `:45` |
| MountainGoat | −0.9 | 1 | — | `MountainGoat.cs:44`, `:43` |
| Rat | −0.9 | 1 | — | `Rat.cs:41`, `:40` |
| SewerRat | −0.9 | 1 | — | `SewerRat.cs:42`, `:41` |
| Turkey | −0.9 | 1 | — | `Turkey.cs:46`, `:45` |
| BattleChickenLizard | 0.0 | 1 | — | `BattleChickenLizard.cs:34`, `:33` |
| ChickenLizard | 0.0 | 1 | — | `ChickenLizard.cs:42`, `:41` |
| HungryCoconutCrab | 0.0 | 1 | — | `HungryCoconutCrab.cs:90`, `:89` |
| ThirdDawnParrot | 0.0 | 1 | — | `ThirdDawnParrot.cs:27`, `:26` |
| SkeletalMount | 0.0 (deserialization only) | 0 | yes | `SkeletalMount.cs:80`, `:81` |
| Cow | 11.1 | 1 | — | `Cow.cs:42`, `:41` |
| Goat | 11.1 | 1 | — | `Goat.cs:40`, `:39` |
| Pig | 11.1 | 1 | — | `Pig.cs:40`, `:39` |
| Sheep | 11.1 | 1 | — | `Sheep.cs:44`, `:43` |
| Eagle | 17.1 | 1 | — | `Eagle.cs:44`, `:43` |
| LowlandBoura | 19.1 | 3 | — | `LowlandBoura.cs:41`, `:40` |
| RuddyBoura | 19.1 | 2 | — | `RuddyBoura.cs:43`, `:42` |
| BullFrog | 23.1 | 1 | — | `BullFrog.cs:42`, `:41` |
| CorrosiveSlime | 23.1 | 1 | — | `CorrosiveSlime.cs:45`, `:44` |
| Hind | 23.1 | 1 | — | `Hind.cs:40`, `:39` |
| Slime | 23.1 | 1 | — | `Slime.cs:43`, `:42` |
| TimberWolf | 23.1 | 1 | — | `TimberWolf.cs:45`, `:44` |
| Beetle | 29.1 (98.7 after ToL upgrade, `:220`) | 3 → 1 | yes | `Beetle.cs:69`, `:68`/`:222` |
| Boar | 29.1 | 1 | — | `Boar.cs:42`, `:41` |
| DesertOstard | 29.1 | 1 | yes | `DesertOstard.cs:43`, `:42` |
| ForestOstard | 29.1 | 1 | yes | `ForestOstard.cs:44`, `:43` |
| GiantRat | 29.1 | 1 | — | `GiantRat.cs:43`, `:42` |
| Horse | 29.1 | 1 | yes | `Horse.cs:54`, `:53` |
| PackHorse | 29.1 | 1 | — | `PackHorse.cs:48`, `:47` |
| PackLlama | 29.1 | 1 | — | `PackLlama.cs:48`, `:47` |
| PalaminoHorse | 29.1 | 1 | yes | `PalaminoHorse.cs:41`, `:40` |
| RidableLlama | 29.1 | 1 | yes | `RidableLlama.cs:46`, `:45` |
| CoconutCrab | 30.0 | 1 | yes | `CoconutCrab.cs:85`, `:84` |
| Eowmu | 30.0 | 1 | yes | `Eowmu.cs:85`, `:84` |
| SkeletalCat | 30.0 | 2 | yes | `SkeletalCat.cs:85`, `:84` |
| BlackBear | 35.1 | 1 | — | `BlackBear.cs:43`, `:42` |
| Llama | 35.1 | 1 | — | `Llama.cs:40`, `:39` |
| PolarBear | 35.1 | 1 | — | `PolarBear.cs:44`, `:43` |
| Walrus | 35.1 | 1 | — | `Walrus.cs:44`, `:43` |
| BrownBear | 41.1 | 1 | — | `BrownBear.cs:42`, `:41` |
| Cougar | 41.1 | 1 | — | `Cougar.cs:43`, `:42` |
| DeathWatchBeetle | 41.1 | 1 | — | `DeathWatchBeetle.cs:68`, `:69` |
| Alligator | 47.1 | 1 | — | `Alligator.cs:43`, `:42` |
| HighPlainsBoura | 47.1 | 3 | — | `HighPlainsBoura.cs:42`, `:41` |
| Scorpion | 47.1 | 1 | — | `Scorpion.cs:47`, `:46` |
| GreyWolf | 53.1 | 1 | — | `GreyWolf.cs:45`, `:44` |
| Panther | 53.1 | 1 | — | `Panther.cs:44`, `:43` |
| SnowLeopard | 53.1 | 1 | — | `SnowLeopard.cs:45`, `:44` |
| CoralSnake | 59.1 | 1 | — | `CoralSnake.cs:47`, `:46` |
| GiantSpider | 59.1 | 1 | — | `GiantSpider.cs:43`, `:42` |
| GreatHart | 59.1 | 1 | — | `GreatHart.cs:41`, `:40` |
| GrizzlyBear | 59.1 | 1 | — | `GrizzlyBear.cs:44`, `:43` |
| Snake | 59.1 | 1 | — | `Snake.cs:43`, `:42` |
| WolfSpider | 59.1 | 2 | — | `WolfSpider.cs:46`, `:45` |
| StoneSlith | 65.1 | 2 | — | `StoneSlith.cs:41`, `:40` |
| WhiteWolf | 65.1 | 1 | — | `WhiteWolf.cs:45`, `:44` |
| Gaman | 68.7 | 1 | — | `Gaman.cs:42`, `:41` |
| Bull | 71.1 | 1 | — | `Bull.cs:44`, `:43` |
| GiantIceWorm | 71.1 | 1 | — | `GiantIceWorm.cs:45`, `:44` |
| GreaterMongbat | 71.1 | 1 | — | `GreaterMongbat.cs:42`, `:41` |
| HellCat | 71.1 | 1 | — | `HellCat.cs:47`, `:46` |
| IronBeetle | 71.1 | 4 | — | `IronBeetle.cs:49`, `:50` |
| StrongMongbat | 71.1 | 1 | — | `StrongMongbat.cs:40`, `:39` |
| BloodFox | 72.0 | 2 | — | `BloodFox.cs:39`, `:38` |
| OsseinRam | 72.0 | 2 | — | `OsseinRam.cs:44`, `:43` |
| FrostSpider | 74.7 | 1 | — | `FrostSpider.cs:49`, `:48` |
| FrenziedOstard | 77.1 | 1 | yes | `FrenziedOstard.cs:47`, `:46` |
| GiantToad | 77.1 | 1 | — | `GiantToad.cs:43`, `:42` |
| BakeKitsune | 80.7 | 2 | — | `BakeKitsune.cs:45`, `:44` |
| LavaLizard | 80.7 | 1 | — | `LavaLizard.cs:46`, `:45` |
| Slith | 80.7 | 1 | — | `Slith.cs:35`, `:34` |
| DireWolf | 83.1 | 1 | — | `DireWolf.cs:47`, `:46` |
| Imp | 83.1 | 2 | — | `Imp.cs:66`, `:65` |
| Ridgeback | 83.1 | 1 | yes | `Ridgeback.cs:46`, `:45` |
| SavageRidgeback | 83.1 | 1 | yes | `SavageRidgeback.cs:46`, `:45` |
| Drake | 84.3 | 2 | — | `Drake.cs:44`, `:43` |
| CrimsonDrake | 85.0 | 2 | — | `CrimsonDrake.cs:88`, `:87` |
| PlatinumDrake | 85.0 | 2 | — | `PlatinumDrake.cs:88`, `:87` |
| StygianDrake | 85.0 | 4 | — | `StygianDrake.cs:48`, `:47` |
| HellHound | 85.5 | 1 | — | `HellHound.cs:47`, `:46` |
| Icehound | 85.5 | 1 | — | `Icehound.cs:43`, `:42` |
| PredatorHellCat | 90.0 | 2 | — | `PredatorHellCat.cs:47`, `:46` |
| Dragon | 93.9 | 3 | — | `Dragon.cs:45`, `:44` |
| FireBeetle | 93.9 (98.7 post-ToL, `:188`) | 3 → 1 | yes | `FireBeetle.cs:40`, `:39`/`:190` |
| RuneBeetle | 93.9 | 3 | — | `RuneBeetle.cs:54`, `:53` |
| ScaledSwampDragon | 93.9 | 1 | yes | `ScaledSwampDragon.cs:45`, `:44` |
| SwampDragon | 93.9 | 1 | yes | `SwampDragon.cs:56`, `:55` |
| Kirin | 95.1 | 2 | yes | `Kirin.cs:53`, `:52` |
| Nightmare | 95.1 | 2 | yes | `Nightmare.cs:52`, `:51` |
| Skree | 95.1 | 4 | — | `Skree.cs:44`, `:43` |
| Unicorn | 95.1 | 2 | yes | `Unicorn.cs:50`, `:49` |
| WildTiger | 95.1 | 2 | yes | `WildTiger.cs:61`, `:60` |
| ColdDrake | 96.0 | 3 | — | `ColdDrake.cs:49`, `:48` |
| DreadSpider | 96.0 | 3 | — | `DreadSpider.cs:54`, `:53` |
| Lion | 96.0 | 2 | — | `Lion.cs:46`, `:45` |
| Triton | 96.0 | 2 | — | `Triton.cs:106`, `:105` |
| TsukiWolf | 96.0 | 3 | — | `TsukiWolf.cs:65`, `:64` |
| WhiteWyrm | 96.3 | 3 | — | `WhiteWyrm.cs:48`, `:47` |
| Hiryu | 98.7 | 4 | yes | `Hiryu.cs:43`, `:42` |
| LesserHiryu | 98.7 | 3 → 1 | yes | `LesserHiryu.cs:43`, `:42`/`:226` |
| CuSidhe | 101.1 | 4 | yes | `CuSidhe.cs:59`, `:58` |
| Reptalon | 101.1 | 4 | yes | `Reptalon.cs:40`, `:39` |
| DragonWolf | 102.0 | 4 | — | `DragonWolf.cs:43`, `:42` |
| FrostMite | 102.0 | 3 | — | `FrostMite.cs:42`, `:41` |
| Phoenix | 102.0 | 4 | — | `Phoenix.cs:47`, `:46` |
| SabertoothedTiger | 102.0 | 2 | — | `SabertoothedTiger.cs:46`, `:45` |
| Triceratops | 102.0 | 3 | — | `Triceratops.cs:44`, `:43` |
| SilverSteed | 103.1 | 1 | yes | `SilverSteed.cs:25`, `:23` |
| GreaterDragon | 104.7 | 5 | — | `GreaterDragon.cs:49`, `:48` |
| FrostDragon | 105.0 | 5 | — | `FrostDragon.cs:50`, `:49` |
| ShadowWyrm | 105.0 | 5 | — | `ShadowWyrm.cs:50`, `:49` |
| FireSteed | 106.0 | 2 | yes | `FireSteed.cs:48`, `:47` |
| Raptor | 107.1 | 2 | — | `Raptor.cs:55`, `:56` |
| DreadWarhorse | 108.0 | 3 | yes | `DreadWarhorse.cs:54`, `:53` |
| SerpentineDragon | 108.0 | 3 | — | `SerpentineDragon.cs:51`, `:50` |
| BaneDragon (event) | 107.1 | 3 | — | `Scripts/Mobiles/Event/BaneDragon.cs:70`, `:69` |
| FactionWarHorse | 29.1 | 1 | — | `Scripts/Mobiles/Factions/BaseWarHorse.cs:41`, `:40` |
| GargoylePet (summon) | 65.1 | 2 | — | `Scripts/Mobiles/Summons/GargoylePet.cs:37`, `:36` |

Minimum tameable = **−21.3** (Dog/Ferret/Squirrel) and maximum requirement is clamped by
`BaseCreature.MaxTameRequirement = 108.0` (`BaseCreature.cs:575`).

**`CurrentTameSkill` vs `MinTameSkill` (pet training)**

| Rule | Code | Citation |
|---|---|---|
| Default | `CurrentTameSkill = MinTameSkill` when `ControlSlots <= ControlSlotsMin` | `BaseCreature.cs:741-744` |
| Above-minimum slots | `CurrentTameSkill = ((ControlSlots - ControlSlotsMin) * 21) + 1` | `:747` |
| Clamp | `if (CurrentTameSkill > MaxTameRequirement) CurrentTameSkill = MaxTameRequirement` (108.0) | `:750-753` |
| Applied | on world load when `Tamable && CurrentTameSkill == 0` | `:3013-3016` |
| `MinTameSkill` setter keeps the delta | `adjusted = CurrentTameSkill - old; CurrentTameSkill = adjusted > 0 ? value + adjusted : value` | `:3790-3812` |

**Loyalty / obedience rules**

| Rule | Literal | Citation |
|---|---|---|
| Loyalty range | `MaxLoyalty = 100`, stored value clamped `0..100` | `BaseCreature.cs:204`, `:1727` |
| On a fresh tame | `Loyalty = MaxLoyalty` | `:2376`, `:7987` |
| Successful command | `Loyalty += 1` | `:1490` |
| Failed command | `Loyalty -= 3` + anger sound + animation | `:1505` |
| Decay | `LoyaltyTimer` internal delay **5 min** but the body only runs once per hour (`m_NextHourlyCheck = now + 1 h`, early-return otherwise); each run: `Loyalty -= (MaxLoyalty / 10)` = **−10/hour** for every controlled, commandable pet on a map | `:7870-7893`, `:7944` |
| Warning | when `Loyalty < 10`: `1043270` "* ~1_NAME~ looks around desperately *" | `:7946-7950` |
| Release | `Loyalty <= 0` → `toRelease`, then `1043255` "~1_NAME~ appears to have decided that is better off without a master!", `Loyalty = MaxLoyalty`, `IsBonded = false`, `BondingBegin = MinValue` | `:7952-7989` |
| Mounted pets exempt | `if (m is BaseMount && ((BaseMount)m).Rider != null) OwnerAbandonTime = MinValue` (skips the decay branch) | `:7908-7911` |
| Control chance | `GetControlChance(m)` | `:1519-1588` |

**`GetControlChance` exactly as coded** (`:1519-1588`):

```
if (CurrentTameSkill <= 29.1 || Summoned || AccessLevel >= GM) return 1.0
dMin = CurrentTameSkill; if (dMin > -24.9 && DarkWolfFamiliar.CheckMastery(m, this)) dMin = -24.9
taming = (int)(Taming.Value * 10); lore = (int)(AnimalLore.Value * 10)
chance = 700
if (Core.ML):
    SkillBonus = taming - (int)(dMin*10);  LoreBonus = lore - (int)(dMin*10)
    SkillMod = SkillBonus < 0 ? 28 : 6;    LoreMod = LoreBonus < 0 ? 14 : 6
    bonus = ((SkillBonus*SkillMod) + (LoreBonus*LoreMod)) / 2
else:
    weighted = ((taming*4) + lore) / 5;  bonus = weighted - (int)(dMin*10)
    bonus *= (bonus <= 0 ? 14 : 6)
chance += bonus
if (chance >= 0 && chance < 200) chance = 200
else if (chance > 990) chance = 990
chance -= (MaxLoyalty - Loyalty) * 10
return chance / 1000.0
```

`[SRC]`. `[PARTIAL]`: the exact **skill-gain** that "you fail to tame" produces is not a separate
path — the final failure branch only prints `502798` and returns; the gain comes from
`CheckTargetSkill` itself (`SkillCheck.cs:240-259`). `[UNVERIFIED]`: the retail break-out of
"you fail to tame" vs "you anger the beast" probabilities cannot be derived from a single file —
measure over N≥1000 tame attempts per creature type.

---

### 2.17 Inscription (skill-use side only)

Source: `ServUO:Scripts/Skills/Inscribe.cs` (171 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Skills/Inscribe.cs · **scroll scribing belongs to section 4d**

| Field | Value |
|---|---|
| Trigger | Skill button (`:13`) → `1046295` "Target the book you wish to copy."; 1.0 s |
| Target requirements | Stage 1 `Target(3, false, TargetFlags.None)` = source `BaseBook` (`:78`); stage 2 `Target(3, false, TargetFlags.None)` = destination book (`:122`). **Both stages time out after 1 minute** (`:21`, `:96`) |
| Skill check window | `CheckTargetSkill(Inscribe, bookDst, 0, 50)` (`:145`) — deliberately capped at 50, so a 100-skill scribe always auto-succeeds (`value >= maxSkill → true`, `SkillCheck.cs:150`) |
| Delay / cooldown | 1.0 s (`:23`) |
| Success outcome | Title, author and page lines copied (`Copy`, `:44-62`); `501618` "You make a copy of the book."; sound `0x249` (`:147-150`) |
| Failure outcome | `501617` "You fail to make a copy of the book." (`:154`) |
| Resource consumed | none coded (no blank scroll, no mana) — the copy is a straight text copy onto an existing writable book |
| Messages / gumps | `501611` "Can't copy an empty book."; `501621` "Someone else is inscribing that item."; `501612` "Select a book to copy this to."; `501616` "Cannot copy a book onto itself."; `501614` "Cannot write into that book."; `1046296` "That is not a book"; `501619` timeout |
| Interactions | `Server.Engines.Khaldun.MysteriousBook.OnInscribeTarget` short-circuit (`:100-103`); **Magery** uses Inscribe for scroll-cast bonuses (scribe damage bonus `Spell.cs:224-225`, `Protection`/`Reactive Armor`/`Magic Reflect` use `Inscribe/20`, and casting focus uses `Inscribe >= 50` → `Spell.cs:277`); scroll scribing itself is the craft system |
| [ERA] | `Core.SA`-era Khaldun hook; the per-book copy behaviour is era-neutral |
| Confidence | `[SRC]` |

**Scroll scribing (brief — full treatment in §4d)** — `Scripts/Services/Craft/DefInscription.cs`:

| Circle | `minSkill` | `maxSkill` | Mana per scroll | Citation |
|---|---|---|---|---|
| 0 (1st) | −25.0 | 25.0 | 4 | `DefInscription.cs:170`, `:243-244` |
| 1 (2nd) | −10.8 | 39.2 | 6 | `:171`, `:255-256` |
| 2 (3rd) | 3.5 | 53.5 | 9 | `:172`, `:267-268` |
| 3 (4th) | 17.8 | 67.8 | 11 | `:173`, `:279-280` |
| 4 (5th) | 32.1 | 82.1 | 14 | `:174`, `:291-292` |
| 5 (6th) | 46.4 | 96.4 | 20 | `:175`, `:303-304` |
| 6 (7th) | 60.7 | 110.7 | 40 | `:176`, `:315-316` |
| 7 (8th) | 75.0 | 125.0 | 50 | `:177`, `:327-328` |

Every scroll also requires `BlankScroll ×1` plus the spell's reagents (`:180-187`); the skill-info
row for Inscription is `SkillInfo(23, "Inscription", 0.0, 2.0, 8.0, "Scribe", null, 0.0, 0.2, 0.8,
1.0, Int, Dex)` (`Server/Skills.cs:619`) — i.e. **Str +0 %, Dex +2 %, Int +8 %** stat gain weights.

---

### 2.18 Camping (kindling, campfire, bedroll, secure logout)

Sources: `ServUO:Scripts/Items/Consumables/Kindling.cs`, `Scripts/Items/Functional/Campfire.cs`,
`Scripts/Items/Tools/Bedroll.cs` · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Functional/Campfire.cs

| Field | Value |
|---|---|
| Trigger | **Item double-click on `Kindling`** (`Kindling.cs:47`). Camping has **no skill callback** (`Server/Skills.cs:606` passes `null`), so the skill button replies `500014` "That skill cannot be used directly." |
| Target requirements | none — the fire is placed at a computed adjacent tile. Requires `VerifyMove(from)` and `InRange(GetWorldLocation(), 2)` (`:49-56`) |
| Skill check window | `from.CheckSkill(SkillName.Camping, 0.0, 100.0)` (`Kindling.cs:64`) ⇒ chance = `Camping.Value / 100` |
| Delay / cooldown | none — no `NextSkillTime` write; limited only by the kindling supply. The campfire itself lives 100 s |
| Success outcome | `Consume()` the kindling; a `Campfire` is placed at the fire location (`:70-75`) |
| Failure outcome | `501696` "You fail to ignite the campfire." — **kindling is not consumed** (`:64-67`) |
| Resource consumed | 1 `Kindling` (weight 1.0, item id `0xDE1`, stackable) **only on success** |
| Messages / gumps | `1019045` "I can't reach that."; `501695` "There is not a spot nearby to place your campfire."; `501696`; campfire `500620` "You feel it would take a few moments to secure your camp."; `500621` "The camp is now secure."; bedroll gump `1011015` / `1011016` |
| Interactions | none coded — Camping does not read any other skill; the resulting `CampfireEntry.Safe` flag is what the **Bedroll logout** consumes |
| [ERA] | No `Core.*` gate anywhere in these three files — the campfire/bedroll mechanics are pre-AoS-era and unchanged through SA |
| Confidence | `[SRC]` |

**Campfire placement rules (`Kindling.GetFireLocation`, `:79-121`)**

| Rule | Literal |
|---|---|
| Dungeon | `if (from.Region.IsPartOf<DungeonRegion>()) return Point3D.Zero;` ⇒ `501695`, no fire |
| Kindling on the ground | `if (Parent == null) return Location;` — lights where it lies |
| Candidate tiles | exactly four offsets, in this order: `(0,−1)`, `(−1,0)`, `(0,+1)`, `(+1,0)` (`:89-92`) |
| Tile validity | `map.CanFit(loc, 1) && from.InLOS(loc)`, retried at `map.GetAverageZ(x, y)` if the first Z fails (`:110-120`) |
| Selection | `Utility.Random(list.Count)` — uniformly random among the valid candidates (`:97-98`) |

**Campfire lifecycle (`Campfire.cs`)**

| Constant | Value | Citation |
|---|---|---|
| Item id / light | `0xDE3`, `LightType.Circle300`, `Movable = false` | `:23-25` |
| Tick | `Timer.DelayCall(1.0 s, 1.0 s, OnTick)` | `:31` |
| Extinguishing | `age >= 60 s` → id `0xDE9`, `Circle150` | `:131-132`, `:75-78` |
| Off | `age >= 90 s` → id `0xDEA`, `LightType.ArchedWindowEast`, all entries cleared | `:129-130`, `:79-83` |
| Deleted | `age >= 100 s` → `Delete()` | `:127-128` |
| Secure radius | `public static readonly int SecureRange = 7` | `:17` |
| Entry creation | every `PlayerMobile` within `SecureRange` with no existing entry → `500620` | `:150-165` |
| Secure timer | `!entry.Safe && now - entry.Start >= 30 s` → `entry.Safe = true` + `500621` | `:143-147` |
| Entry validity | `!Fire.Deleted && Fire.Status != Off && Player.Map == Fire.Map && Player.InRange(Fire, SecureRange)` | `:217-223` |
| Serialization | `Deserialize` calls `this.Delete()` — campfires never persist across a restart | `:113-120` |

**Bedroll + secure logout (`Bedroll.cs`)**

| Step | Rule | Citation |
|---|---|---|
| Double-click | requires `Parent == null`, `VerifyMove(from)`, `InRange(this, 2)` | `:25-32` |
| Roll direction | `ItemID == 0xA57` (rolled): `GetDirection4` N/S → `0xA55`, else `0xA56` | `:34-42` |
| Unroll | any other id → back to `0xA57`; then, if no `LogoutGump` is open and `Campfire.GetEntry(from) != null && entry.Safe`, open `LogoutGump` | `:43-54` |
| Gump | `400 × 350`, background `0xA28`, title `1011015` "<center>Logging out via camping</center>", body `1011016`, CONTINUE button id `1`, CANCEL id `0` | `:84-100` |
| Auto-close | `Timer.DelayCall(10.0 s, CloseGump)` — "The camp will remain secure for 10 seconds…" | `:82`, comment `:91-93` |
| CONTINUE requirements | `info.ButtonID == 1 && entry.Safe && bedroll.Parent == null && bedroll.IsAccessibleTo(pm) && bedroll.VerifyMove(pm) && bedroll.Map == pm.Map && pm.InRange(bedroll, 2)` | `:112-113` |
| CONTINUE effect | bedroll into backpack, `pm.BedrollLogout = true`, **`sender.Dispose()`** (immediate disconnect) | `:115-118` |
| Either button | `Campfire.RemoveEntry(entry)` | `:121` |
| Logout delay | `PlayerMobile.GetLogoutDelay()` returns `TimeSpan.Zero` when `Young \|\| BedrollLogout \|\| BlanketOfDarknessLogout \|\| TestCenter.Enabled`, else `base.GetLogoutDelay()` (the normal combat/flag delay) | `PlayerMobile.cs:6177-6185` |
| Reset | `BedrollLogout = false` on login | `PlayerMobile.cs:1649`, `:5482` |

`[SRC]`. `[ERA]`: the secure-logout-camp mechanic is the classic (pre-AoS) design; no expansion gate
is present in code. `[PARTIAL]`: the exact `base.GetLogoutDelay()` value (the non-camp delay) lives
in `Server/Mobile.cs` and is not part of this section — see the logout/flag section.

---

### 2.19 Healing and Veterinary (bandage use model)

Source: `ServUO:Scripts/Items/Resource/Bandage.cs` (778 lines) · https://github.com/ServUO/ServUO/blob/pub57/Scripts/Items/Resource/Bandage.cs

| Field | Value |
|---|---|
| Trigger | **Item double-click on a `Bandage`** (`:73`) → `500948` "Who will you use the bandages on?"; also the `EventSink.BandageTargetRequest` path used by the enhanced client / macros (`:20`, `:89-118`) |
| Target requirements | `Target(Bandage.Range, false, TargetFlags.Beneficial)` (`:125`), `Bandage.Range = Core.AOS ? 2 : 1` (`:23`); target must be a `Mobile` (or `PlagueBeastInnard`) and the *bandage* must be within range (`:139`) |
| Skill check window | No `min/max` window — all healing rolls are **direct-chance** (`CheckSkill(skill, chance)` at the end of the action, `:590-591`) |
| Delay / cooldown | `BandageContext.GetDelay` (table below); the timer ticks every **250 ms** and ends the action at `m_Expires` (`:618-640`). No `NextSkillTime` write, so bandaging does not block the skill timer |
| Success outcome | Heal / cure / stop bleed / resurrect — see tables. Sound `0x57` on the patient (`:585`) |
| Failure outcome | `500968` "You apply the bandages, but they barely help." (`:568`) for the heal path; `500966`/`503256` for resurrection; `1010060` for cure |
| Resource consumed | **1 bandage** consumed the moment `BeginHeal` returns a context (`:141-145`); `EnhancedBandage` adds `HealingBonus = 10` (`FountainOfLife.cs:28-34`, applied at `Bandage.cs:214-215`) |
| Messages / gumps | `500948`, `500295` "You are too far away to do that.", `500970` "Bandages can not be used on that.", `500951` "You cannot heal that.", `500955` "That being is not damaged!", `501042` "Target cannot be resurrected at that location.", `500956` "You begin applying the bandages.", `1008078` " : Attempting to heal you.", `500969` "You finish applying the bandages.", `500968`, `500967` "You heal what little damage your patient had.", `500961` "Your fingers slip!", `500962` "You were unable to finish your work before you died.", `500963` "You did not stay close enough to heal your target.", `500965` "You are able to resurrect your patient.", `500966`, `502391` "Thou can not be resurrected there!", `1049658`, `1049659`, `503256`, `1010395`, `1010058`, `1010059`, `1010060`, `1060088`, `1060167`, `1005000`/`1010398` (mortal strike), `1151178` (searing wounds), `1151400` buff text |
| Interactions | **Anatomy** (human) / **Animal Lore** (creature) is the secondary skill in *every* formula; `Poison` level of the patient; `BleedAttack`; `MortalStrike`; **Spirituality virtue** on cross-heals (`:559-562`); **City Loyalty** Guild of Healers trade deal (`:538-541`); ToL **Searing Wounds**; `FirstAidBelt` and `Asclepius`/`GargishAsclepius` add healing (`:490-501`); `PetResurrectGump` for dead pets |
| [ERA] | `Core.AOS` selects the modern heal amounts (`:511-520`), the AoS delay curve (`:738-746`) and the slips-ratio penalty (`:529-536`); `Core.SA` enables the half-way poison/bleed check (`:611-616`); `Core.SE` lets a `FactionWarHorse`'s own master always resurrect it (`:346`); `Core.ML`-era `MortalStrike`/bleed branches |
| Confidence | `[SRC]` |

**Skill selection (`GetPrimarySkill` / `GetSecondarySkill`, `:242-274`)**

| Patient | Primary | Secondary |
|---|---|---|
| `DespiseCreature` | `Healing` if `Healing.Value > Veterinary.Value`, else `Veterinary` | `Anatomy` if the same comparison holds, else `AnimalLore` |
| `!Player && (Body.IsMonster \|\| Body.IsAnimal)` | `Veterinary` | `AnimalLore` |
| everything else (including players) | `Healing` | `Anatomy` |

**Wait delay by skill and dex (`GetDelay`, `:708-761`)** — `resDelay = dead ? 5.0 : 0.0` where
`dead = !patient.Alive || patient.IsDeadBondedPet` (`:710`, `:720`):

| Case | Formula | Citation |
|---|---|---|
| AoS, self-heal | `seconds = min(8, ceil(11.0 - dex / 20))`, then `max(seconds, 4)` ⇒ **dex 0–59 → 8 s, 60–79 → 7, 80–99 → 6, 100–119 → 5, 120+ → 4** | `:728-732` |
| pre-AoS, self-heal | `seconds = 9.4 + (0.6 * ((120 - dex) / 10))` ⇒ **11.8 s at dex 80, 9.4 s at dex 120** | `:733-736` |
| AoS, Veterinary on a creature | `seconds = 2.0` (flat) | `:738-741` |
| AoS, other target | `seconds = ceil(4 - dex / 60)`, then `max(seconds, 2)` | `:742-746` |
| pre-AoS, other target | `dex >= 100 → 3.0 + resDelay`; `dex >= 40 → 4.0 + resDelay`; else `5.0 + resDelay` | `:747-758` |
| Resurrection | adds **+5.0 s** to every branch (only the pre-AoS "other target" branch adds `resDelay` in code; the AoS branches do **not** add it — see the divergence note) | `:720`, `:747-758` |

`[SRC]` note: in `pub57` the `resDelay` is only *used* by the pre-AoS branches, so on AoS a
resurrection takes exactly the same time as a heal. This looks like a bug; the clone must decide
whether to reproduce it.

**Divergence with ModernUO (same function)** — `ModernUO:Projects/UOContent/Items/Skill Items/Misc/Bandage.cs:483-526`:

| Case | ServUO `pub57` | ModernUO `main` |
|---|---|---|
| AoS self | `min(8, ceil(11 - dex/20))`, floor 4 | `5.0 + 0.5 * ((120 - dex) / 10)` with an in-source `// TODO: Verify algorithm` |
| pre-AoS self | `9.4 + 0.6*((120-dex)/10)` | identical |
| AoS Veterinary | `2.0` | `2.0` |
| AoS other | `max(ceil(4 - dex/60), 2)` | `dex < 204 ? 3.2 - sin(dex/130)*2.5 + resDelay : 0.7 + resDelay` |
| pre-AoS other | `3.0/4.0/5.0 + resDelay` | identical |

**Heal amount (`EndHeal`, `:482-571`)**

| Step | AoS | pre-AoS |
|---|---|---|
| Base chance | `chance = ((healing + 10.0) / 100.0) - (m_Slips * 0.02)` (`:503`) | same |
| `min` | `(anatomy / 8.0) + (healing / 5.0) + 4.0` (`:513`) | `(anatomy / 5.0) + (healing / 5.0) + 3.0` (`:518`) |
| `max` | `(anatomy / 6.0) + (healing / 2.5) + 4.0` (`:514`) | `(anatomy / 5.0) + (healing / 2.0) + 10.0` (`:519`) |
| Roll | `toHeal = min + (RandomDouble() * (max - min))` (`:522`) | same |
| Monster/animal bonus | `toHeal += m_Patient.HitsMax / 100` (`:524-527`) | same |
| Slip penalty | `toHeal -= toHeal * m_Slips * 0.35` (in-source `// TODO: Verify algorithm`) (`:531`) | `toHeal -= m_Slips * 4` (`:535`) |
| City Loyalty | `toHeal += (int)Math.Ceiling(toHeal * 0.05)` with Guild of Healers trade deal (`:539-540`) | same |
| After cure/bleed | `toHeal /= m_HealedPoisonOrBleed` (`:543-546`) | same |
| Searing Wounds | `toHeal /= 2` + `1151178` (`:548-552`) | same |
| Floor | `toHeal < 1` → `1` and message `500968` (`:554-558`) | same |
| Apply | `m_Patient.Heal((int)toHeal, m_Healer, false)` (`:564`) | same |
| Healing bonus sources | `FirstAidBelt.HealingBonus` (`:490-493`), `Asclepius`/`GargishAsclepius` `+15` (`:495-498`), `EnhancedBandage` `+10` (`:214-215`); the sum is added to `healing` when `> 0` (`:500-501`) | same |

**Cure-poison chance (`m_Patient.Poisoned` branch, `:437-463`)** — gated on `Healing/primary >= 60.0
&& Anatomy/secondary >= 60.0` (`:445`):

```
chance = ((healing - 30.0) / 50.0) - (m_Patient.Poison.RealLevel * 0.1) - (m_Slips * 0.02)
if (checkSkills && chance > Utility.RandomDouble()):
    CurePoison -> healer 1010058 (only if healer != patient) / patient 1010059
    else:      healer -1, patient -1        (silent)
else:          healer 1010060 "You have failed to cure your target!"
```

| Poison | `RealLevel` | Chance penalty |
|---|---|---|
| Lesser | 0 | 0.0 |
| Regular | 1 | 0.1 |
| Greater | 2 | 0.2 |
| Deadly | 3 | 0.3 |
| Lethal | 4 | 0.4 |

**Resurrection requirement (`:339-435`)** — when `!m_Patient.Alive` (or a dead pet):

```
chance = ((healing - 68.0) / 50.0) - (m_Slips * 0.02)
success requires: (checkSkills = (healing >= 80.0 && anatomy >= 80.0)) && chance > RandomDouble()
  -- or -- Core.SE && patient is FactionWarHorse && ControlMaster == healer
  -- or -- VvV enabled && patient is VvVMount && ControlMaster == healer
```

| Success sub-case | Messages |
|---|---|
| Location cannot fit 16 items | healer `501042`, patient `502391` |
| Region is part of `"Khaldun"` | healer `1010395` |
| Normal success | healer `500965`, patient sound `0x214`, effect `0x376A`/10/16, patient gets `ResurrectGump` |
| Dead pet, healer is the master | `ResurrectPet()` and **every skill drops 0.1** (`:376-379`) |
| Dead pet, master within 3 | `1049658` + `PetResurrectGump` to the master |
| Dead pet, a friend within 3 | `1049658` + `PetResurrectGump` to the friend |
| Dead pet, nobody near | `1049659` |
| Failure | `503256` (dead pet) / `500966` (player) |

**Mid-bandage poison/bleed check (`CheckPoisonOrBleed`, `:276-312`)** — only possible when
`Core.SA && healer == patient && Healing.Value >= 80 && Anatomy.Value >= 80` (`:606-616`), executed
once at **half** the bandage duration (`:635`):

```
chance = ((Healing.Value + Anatomy.Value) - 120) * 25
if (poisoned) chance /= patient.Poison.RealLevel * 20
else          chance /= 3 * 20                    // bleed only
if (chance >= Utility.Random(100)):
    m_HealedPoisonOrBleed = poisoned ? Poison.RealLevel : 3
    CurePoison -> patient 1010059
    else stop bleeding -> 1060088 / 1060167
```

`[SRC]` — note this is a **second, independent** cure roll on top of the end-of-bandage cure, and it
reduces the eventual heal by dividing by `RealLevel` (or 3 for bleed) at `:543-546`.

**Other branches handled at the end of the bandage**

| Patient state | Message(s) | Citation |
|---|---|---|
| Healer died | `500962` | `:327-332` |
| Healer out of range | `500963` | `:333-338` |
| Patient bleeding | `1060088` (healer) / `1060167` (patient) + `EndBleed` | `:464-470` |
| Patient under Mortal Strike | `1005000` (self) / `1010398` | `:471-476` |
| Patient at full HP | `500967` "You heal what little damage your patient had." | `:477-481` |
| Skill gain | `CheckSkill(secondarySkill, 0.0, 120.0)` then `CheckSkill(primarySkill, 0.0, 120.0)`, only when the branch set `checkSkills = true` | `:588-592` |
| Buff cleanup | `BuffInfo.RemoveBuff(healer, BuffIcon.Healing)` for players, `Veterinary` otherwise | `:594-597` |
| Enhanced-client timer packet | `BandageTimerPacket(0xBF, 0x31, 0xE21, seconds)` | `:697-700`, `:764-777` |

`[ERA]`: the **entire** `1002082`/`1002167` buff pair, the ICON split, and the enhanced-client timer
packet are SA/EC-era; the heal, cure and resurrect formulas are AoS-shaped with pre-AoS branches as
tabulated. `[PARTIAL]`: the retail bandage delay curve for AoS non-self healing is *not* what
ServUO ships (see the ModernUO divergence table) — to decide which one a clone should use, measure
bandage completion time on a live shard at dex 10/60/120 and compare against both curves.

---

### 2.20 Cross-skill interaction summary (this section only)

| Skill | Reads / is read by | Effect |
|---|---|---|
| Anatomy | weapon damage (AoS `BaseWeapon.cs:3789`, pre-AoS `:3856`), pre-AoS 2H special (`BaseAxe.cs:147` etc.), bandage primary/secondary pair, Animal Lore gump | +0.5 %/pt (AoS) or +0.2 %/pt + 10 % at GM (pre-AoS) melee damage; heal formula + cure/resurrect gate |
| Animal Lore | Animal Taming (passive gain + control chance `BaseCreature.cs:1534`), bandage secondary for creatures | control chance, gump detail |
| Arms Lore | none | informational |
| EvalInt | Magery damage (`Spell.cs:53`, `:231-234`, `:451-478`), Protection, Paralyze Field, weapon paralyze duration | spell damage, durations |
| ItemID | Imbuing (`CanUnravelItem`, `GetTotalWeight`) | unravel ingredient preview |
| TasteID | Poisoning output | detects `Food.Poison` |
| Forensics | Lockpicking (`ILockpickable.Picker`), corpse/justice data, Honesty virtue | criminal/lock forensics |
| Tracking | Detect Hidden (`Tracking.cs:244`), Hiding/Stealth of the target, Ninjitsu stalking bonus | PvP tracking difficulty, ninjitsu damage |
| Begging | Karma, Fame | gold cap and karma loss |
| Herding | Animal Taming (`CurrentTameSkill`) | creature movement |
| Detect Hidden | Hiding/Stealth, Tracking, Remove Trap (≥50 gate), Lockpicking (≥50 gate), Shadow Spell mastery | reveals |
| Remove Trap | Lockpicking ≥50, Detect Hidden ≥50, Tinkering 80–100 (faction traps), Magery `Remove Trap` spell | disarms |
| Poisoning | TasteID, Arms Lore (`PoisonCharges`), Infectious Strike (AoS), poison levels in `Server/Poison.cs` | weapon/food poison |
| Meditation | Focus, armour, Spell Channeling/Mage Armor, mana regen (`RegenRates.cs`) | mana regen rate |
| Spirit Speak | all Necromancy spells (`NecromancerSpell.cs:26`), ghost speech, Conduit/Command Undead masteries | necro damage/duration, speech |
| Animal Taming | Animal Lore, necro Dark Wolf mastery, Followers/Fame, bard pacification | pet acquisition |
| Inscription | scroll crafting (§4d), Magery scroll/scribe bonuses | copy books, scribe scrolls |
| Camping | Bedroll logout | secure logout |
| Healing / Veterinary | Anatomy / Animal Lore, Poison, BleedAttack, MortalStrike, Spirituality, City Loyalty, Searing Wounds | heal/cure/resurrect |

---

### 2.21 Open items for this section

| # | Gap | Marker | How to resolve |
|---|---|---|---|
| 1 | English text for clilocs `1038045`–`1038165`, `1038303`–`1038313` (Anatomy), `1038166`–`1038212` (EvalInt), `1038285`–`1038302` (Arms Lore), `1049595`–`1049605` (loyalty) | `[PARTIAL]` | dump those ids from `cliloc.enu` (client files) or from `ClassicUO`'s cliloc reader |
| 2 | Whether retail gates spell circles on EvalInt | `[UNVERIFIED]` | no such code in `pub57`; measure client behaviour with `Magery 30 / EvalInt 100` |
| 3 | Retail AoS non-self bandage delay curve | `[PARTIAL]` | ServUO and ModernUO disagree; measure completion time at dex 10/60/120 on a live shard |
| 4 | Passive-detect cadence (per step vs per timer) | `[UNVERIFIED]` | instrument `DoPassiveDetect` on a live shard and count calls/second standing vs walking |
| 5 | Elf begging reward histogram (`Random(8)`/`Random(6)` are exclusive, 3 branches dead) | `[PARTIAL]` | N≥2000 begs on an elf NPC, record item counts |
| 6 | AoS resurrection not adding `resDelay` (5 s) | `[PARTIAL]` | read `pub57` `Bandage.cs:720` vs `:728-746`; decide reproduce vs fix |
| 7 | „you fail to tame" vs „you anger the beast" probabilities per creature | `[UNVERIFIED]` | N≥1000 tame attempts per creature type on a live shard |
| 8 | Remove Trap trap **placement** difficulty values (`TrapPower`) written by Tinkering/t-map/chest spawners | `[PARTIAL]` | `Scripts/Services/Craft/DefTinkering.cs:919`, `Services/TreasureMaps/TreasureMapInfo.cs:661-681`, `TreasureMapChest.cs:174` — covered in the trap/craft sections |
