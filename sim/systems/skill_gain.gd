extends RefCounted
# Rust skillu a statu (granule `sim.skill_gain`, docs/04 §4.2, docs/05 §5.10,
# research/01 §3.3; zdrojovy kod `_src/servuo/Scripts/Misc/SkillCheck.cs`).
#
# TVRZENI, KTERE MUSI DRZET (rozhodnuti uzivatele 2026-10-07, merene v UO):
#   Skill roste i pri NEUSPECHU. V UO se `CheckSkill(skill, min, max)` vola jako
#   "passive check" PRED hodem na uspech
#   (`_src/servuo/Scripts/Services/Craft/Core/CraftItem.cs:1400-1403`), takze hod
#   na uspech a hod na rust jsou DVA NEZAVISLE hody. Proto `check()` pocita
#   `success` a `_gain()` zvlast a `success` do rozhodnuti o rustu vstupuje jen
#   jako VAHA v `_gain_chance` (AoS dava neuspechu 0.0 - viz ERA nize).
#
# ODKUD CISLA (nevymyslena, kazde ma zdroj):
#   * krok +0,1 = `Const.SKILL_STEP` (1 desetina) - docs/05 §5.10,
#   * celkovy strop 7000 desetin = `Const.SKILL_CAP` - NEOPSANO,
#   * jednotlivy strop z `entity.skills.cap(skill)` (1000; 1200 se svitkem),
#   * sance na rust = ServUO `GetGainChance` (`SkillCheck.cs:286-300`),
#   * "pod 10.0 roste vzdy" = `skill.Base < 10.0` (`SkillCheck.cs:246`),
#   * GGS tabulka = `GGSTable` (`SkillCheck.cs:798-806`), 24 radku x 3 sloupce,
#   * "too difficult" / "no challenge" hranice = `Mobile_SkillCheckLocation`
#     (`SkillCheck.cs:143-147`),
#   * staty: prodleva a sance z `data/balance.json` (`stat_gain.*`, rozhodnuti
#     2026-10-06: 2 s / 25 %), capy `Const.STAT_CAP` (225) a 125,
#   * poradi statu = `enum Stat { Str, Dex, Int }` (`SkillCheck.cs:351-356`).
#
# ERA (docs/05 §5.16): AoS - neuspech prispiva do sance na rust 0.0
# (`Core.AOS ? 0.0 : 0.2`, `SkillCheck.cs:295`). Pre-AoS vetev tu ZAMERNE neni:
# je to jeden vyraz a doplni se, az to `era.*` v `data/balance.json` bude chtit
# (docs/05 §5.16.3, pravidlo 2 - jedno misto, ne dvacet `if`).
#
# STAV JE CELE CISLO (docs/09 §9.10.3): hodnoty skillu v desetinach, cas v ms.
# Float je tu jen v LOKALNIM vypoctu pravdepodobnosti (`rng.chance(p:float)`);
# do stavu se nikdy neuklada. Nahoda jde z `core.rng` (vlozena zavislost),
# `sim/` nesmi volat `randf()`/`Time`/`OS`/`Input` (docs/09 §9.10.4).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * vyznam `difficulty`: je to `minSkill` v DESETINACH a `maxSkill` je
#     `difficulty + SKILL_SPAN` (500 desetin = 50.0). NamEReno: 183 z 196
#     Blacksmithy receptu ma `max_skill - min_skill = 50.0`
#     (`research/04-craft-data.json`),
#   * `reason` ve vracenem slovniku - smlouva zadava jen `{success, gained,
#     new_value}` (stejne rozsireni jako `reason` u `sim.movement`),
#   * `_init(registry, rng, clock, events)` - zavislosti KONSTRUKTOREM (jako
#     `world.walk` a `sim.movement`), aby sel `check` merit bez `SimWorld`;
#     bez registru si system zalozi vlastni,
#   * `gain_stat` se v UO vola UVNITR `Gain()`; smlouva klonu ho ma jako
#     SAMOSTATNE volani, takze ho `check()` sam nevola (jinak dvojity zisk).
#     Kdo chce tok UO, zavola po `check` s `gained == true` `gain_stat(m, ...)`
#     se statem ze `data/skills.json` (`stat_primary` / `stat_secondary`),
#   * hlaska na stropu: emulatory na teto ceste hlasku NEposilaji (hledano
#     v ServUO i ModernUO, 0 nalezu) - docs/05 §5.10 ji ale zadava, proto se
#     posila `message`; text je ROZHODNUTI KLONU a patri do docs/05,
#   * `entity.stats` NEMA zamky statu (`str_lock`/`dex_lock`/`int_lock`), ktere
#     UO atrofie vyzaduje (`CanLower`, `SkillCheck.cs:565-577`) - atrofie tu
#     proto ubira NEJSLABSI stat > 10; bez upravy smlouvy `entity.stats`
#     (nebo `ui.paperdoll`, kde se zamky prepinaji) to verne nejde,
#   * `GainFactor` je v UO konstanta KAZDEHO skillu; tady je 1.0, protoze
#     `data/skills.json` ji nema (chybejici pole, patri granule `data.skills`).

const Const = preload("res://core/const.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const BALANCE_PATH := "res://data/balance.json"

# zamky skillu (docs/04 §4.2 `entity.skills`: 0 up, 1 down, 2 locked)
const LOCK_UP := 0
const LOCK_DOWN := 1
# staty: poradi z `enum Stat { Str, Dex, Int }` (`SkillCheck.cs:351-356`)
const STAT_STR := 0
const STAT_DEX := 1
const STAT_INT := 2
const STAT_INDIVIDUAL_CAP := 125
const STAT_MIN_GAIN := 10          # UO `CanLower`: stat <= 10 se neubira

const SKILL_SPAN := 500            # maxSkill - minSkill v desetinach (50.0)
const EARLY_GAIN_BELOW := 100      # `skill.Base < 10.0` -> rust vzdy (desetiny)
const MS_PER_MINUTE := 60000
const STAT_DEFAULT_DELAY_MS := 2000  # nez se nacte `data/balance.json`
const STAT_DEFAULT_CHANCE := 25

# GGS tabulka: 24 radku (jedna na 5.0 skillu) x 3 sloupce podle celkoveho
# skillu (< 350.0 / < 700.0 / >= 700.0), hodnoty v MINUTACH
# (`SkillCheck.cs:798-806`; stejna tabulka je v research/01 §3.3.5).
const GGS_TABLE: Array = [
	[1, 3, 5], [4, 10, 18], [7, 17, 30], [9, 24, 44], [12, 31, 57],
	[14, 38, 90], [17, 45, 84], [20, 52, 96], [23, 60, 106], [25, 66, 120],
	[27, 72, 138], [33, 90, 162], [55, 150, 264], [78, 216, 390],
	[114, 294, 540], [144, 384, 708], [180, 492, 900], [228, 606, 1116],
	[276, 744, 1356], [336, 894, 1620], [396, 1056, 1920], [468, 1242, 2280],
	[540, 1440, 2580], [618, 1662, 3060],
]

var _registry = null
var _rng = null
var _clock = null
var _events = null
var _ggs_on: bool = true
var _stat_delay_ms: int = STAT_DEFAULT_DELAY_MS
var _stat_chance_percent: int = STAT_DEFAULT_CHANCE
var _next_ggs_ms: Dictionary = {}        # skill -> ms, kdy je rust garantovany
var _last_stat_gain_ms: Dictionary = {}  # "serial:stat" -> ms posledniho zisku


func _init(registry = null, rng = null, clock = null, events = null) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_rng = rng if rng != null else RngScript.new(0)
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_read_balance()


func _read_balance() -> void:
	# GGS a stat gain jsou DATA, ne konstanty v kode (docs/05 §5.16.3).
	if not FileAccess.file_exists(BALANCE_PATH):
		return                       # vychozi hodnoty z docs/05 §5.16
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if not (parsed is Dictionary):
		return
	if parsed.has("ggs_on"):
		_ggs_on = bool(parsed["ggs_on"])
	var stat_gain = parsed.get("stat_gain")
	if stat_gain is Dictionary:
		_stat_delay_ms = int(stat_gain.get("delay_ms", _stat_delay_ms))
		_stat_chance_percent = int(stat_gain.get("chance_percent", _stat_chance_percent))


func register(mobile) -> void:
	_registry.register(mobile)


func mobile(serial: int):
	return _registry.get_mobile(serial)


func check(m: int, skill: int, difficulty: int) -> Dictionary:
	# Vraci `{success, gained, new_value, reason}` - prvni tri klice zadava
	# smlouva, `reason` je rozsireni (viz hlavicka).
	var mob = _mobile(m)
	if mob == null:
		return _result(false, false, 0, "no_mobile")
	if mob.skills.lock(skill) != LOCK_UP:
		# `SkillLock.Up` je v UO PODMINKA rustu (`SkillCheck.cs:376`);
		# `down` i `locked` rust blokuji (docs/05 §5.10).
		return _result(false, false, mob.skills.value(skill), "locked")
	var value: int = mob.skills.value(skill)
	if value < difficulty:
		# UO `Mobile_SkillCheckLocation`: "too difficult" vraci false PRED
		# hodem i PRED gain checkem (`SkillCheck.cs:143-144`).
		return _result(false, false, value, "too_difficult")
	if value >= mob.skills.cap(skill):
		# docs/05 §5.10: na stropu se nezvysi a hrac dostane hlasku.
		_message("Your skill cannot advance further.")
		return _result(true, false, value, "cap")
	if value >= difficulty + SKILL_SPAN:
		# "no challenge": UO vraci true a gain check VYNECHAVA (`:146-147`).
		return _result(true, false, value, "no_challenge")
	var chance := float(value - difficulty) / float(SKILL_SPAN)
	var success: bool = _rng.chance(chance)          # 1. hod: uspech
	var gained: bool = _gain(mob, skill, value, chance, success)  # 2. hod: rust
	return _result(success, gained, mob.skills.value(skill), "")


func gain_stat(m: int, stat: int) -> void:
	# Rust statu z pouzivani skillu (docs/05 §5.10 a §5.16.2): prodleva
	# a sance jsou z `data/balance.json` (`stat_gain.*`).
	var mob = _mobile(m)
	if mob == null or stat < STAT_STR or stat > STAT_INT:
		return                       # neznameho statu se nedotykame (jako skills)
	var key := "%d:%d" % [m, stat]
	var now := _now()
	if not _rng.chance(float(_stat_chance_percent) / 100.0):
		return                       # UO: pri minuti hodu se prodleva NEnastavuje
	if now - int(_last_stat_gain_ms.get(key, now - _stat_delay_ms)) < _stat_delay_ms:
		return
	_last_stat_gain_ms[key] = now
	_increase_stat(mob, stat)


# -- vnitrni ---------------------------------------------------------------

func _gain(mob, skill: int, value: int, chance: float, success: bool) -> bool:
	# Rust nastane, kdyz plati ALESPON jedno (UO `SkillCheck.cs:246`):
	#   * skill je pod 10.0 (rychly start; tady PEVNY krok, viz hlavicka),
	#   * padne hod na sanci rustu (nezavisly na hodu na uspech!),
	#   * GGS ma po terminu (garantovany rust).
	var gc: float = _gain_chance(mob, skill, value, chance, success)
	if not (value < EARLY_GAIN_BELOW or _rng.chance(gc) or _check_ggs(skill)):
		return false
	# Celkovy strop 7000: rust se zaplati skillem se zamkem `down`
	# (UO `CheckReduceSkill`, `SkillCheck.cs:484-497`); kdyz neni z ceho,
	# rust se zahodi (`skills.Total + toGain > skills.Cap`).
	var paid: bool = false
	if _rng.chance(float(mob.skills.total()) / float(Const.SKILL_CAP)):
		paid = _reduce_down(mob, skill)
	if mob.skills.total() + Const.SKILL_STEP > Const.SKILL_CAP and not paid:
		_message("Your skill cannot advance further.")
		return false
	mob.skills.set_value(skill, value + Const.SKILL_STEP)
	_next_ggs_ms[skill] = _now() + _ggs_delay_ms(mob.skills.value(skill), mob.skills.total())
	# Event `skill_changed` je ve smlouve udalosti (docs/04 §4.2).
	_events_push("skill_changed", {
		"skill": skill,
		"value": mob.skills.value(skill),
		"total": mob.skills.total(),
		"cap": mob.skills.cap(skill),
	})
	return true


func _gain_chance(mob, skill: int, value: int, chance: float, success: bool) -> float:
	# ServUO `GetGainChance` (`SkillCheck.cs:286-300`): prostor v celkovem
	# stropu + prostor v individualnim stropu, puleny; pak vaha neuspechu
	# (AoS: 0.0, pre-AoS: 0.2) a opet puleno; nakonec clamp 0.01..1.00.
	# `GainFactor` je 1.0 (viz hlavicka).
	var gc := float(Const.SKILL_CAP - mob.skills.total()) / float(Const.SKILL_CAP)
	gc += float(mob.skills.cap(skill) - value) / float(mob.skills.cap(skill))
	gc /= 2.0
	gc += (1.0 - chance) * (0.5 if success else 0.0)
	gc /= 2.0
	return clampf(gc, 0.01, 1.0)


func _check_ggs(skill: int) -> bool:
	if not _ggs_on:
		return false
	# Nezaznamenany skill je "po terminu": v UO je `NextGGSGain` na
	# `DateTime.MinValue`, takze PRVNI check ma garantovany rust
	# (`Skills.cs:195,279`; `CheckGGS`, `SkillCheck.cs:774-786`).
	return _now() >= int(_next_ggs_ms.get(skill, 0))


func _ggs_delay_ms(value: int, total: int) -> int:
	# UO `UpdateGGS` (`SkillCheck.cs:788-796`): radek = Base / 5 (jedna radka
	# na 5.0 skillu; v desetinach tedy value / 50), sloupec podle celkoveho
	# skillu (< 350.0 / < 700.0 / >= 700.0).
	var row: int = mini(GGS_TABLE.size() - 1, value / 50)
	var column: int = 2 if total >= Const.SKILL_CAP else (1 if total * 2 >= Const.SKILL_CAP else 0)
	return int(GGS_TABLE[row][column]) * MS_PER_MINUTE


func _reduce_down(mob, skill: int) -> bool:
	# UO `CheckReduceSkill` bere PRVNI skill se zamkem `down`, kteremu to
	# nesnizi hodnotu pod nulu.
	for i in range(mob.skills.values.size()):
		if i == skill or mob.skills.lock(i) != LOCK_DOWN:
			continue
		var v: int = mob.skills.value(i)
		if v >= Const.SKILL_STEP:
			mob.skills.set_value(i, v - Const.SKILL_STEP)
			return true
	return false


func _increase_stat(mob, stat: int) -> void:
	# UO `IncreaseStat` (`SkillCheck.cs:629-647`): stat se zveda do
	# individualniho capu; na CELKOVEM capu se staty PRESOUVAJI (atrofie).
	# Zamky statu `entity.stats` nema - ubira se nejslabsi stat > 10.
	if _stat_value(mob, stat) >= STAT_INDIVIDUAL_CAP:
		return
	if mob.stats.stat_total() >= Const.STAT_CAP and not _lower_weakest(mob, stat):
		return
	_set_stat(mob, stat, _stat_value(mob, stat) + 1)
	# Maxima jdou ze statu (docs/04 §4.2 `entity.stats`); bez prepoctu by
	# status bar lhal. Aktualni hp/stam/mana se NEMENI - to je vec sim.regen.
	mob.max_hp = mob.stats.hits_max()
	mob.max_stam = mob.stats.stam_max()
	mob.max_mana = mob.stats.mana_max()


func _lower_weakest(mob, stat: int) -> bool:
	var best: int = -1
	var best_value: int = 0
	for s in [STAT_STR, STAT_DEX, STAT_INT]:
		if s == stat:
			continue
		var v: int = _stat_value(mob, s)
		if v <= STAT_MIN_GAIN:
			continue
		if best < 0 or v < best_value:
			best = s
			best_value = v
	if best < 0:
		return false
	_set_stat(mob, best, best_value - 1)
	return true


func _stat_value(mob, stat: int) -> int:
	if stat == STAT_DEX:
		return mob.stats.dex
	if stat == STAT_INT:
		return mob.stats.int_
	return mob.stats.str_


func _set_stat(mob, stat: int, v: int) -> void:
	if stat == STAT_DEX:
		mob.stats.dex = v
	elif stat == STAT_INT:
		mob.stats.int_ = v
	else:
		mob.stats.str_ = v


func _mobile(m: int):
	return _registry.get_mobile(m)


func _now() -> int:
	return int(_clock.now_ms())


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)


func _message(text: String) -> void:
	_events_push("message", {"text": text, "kind": "system"})


func _result(success: bool, gained: bool, new_value: int, reason: String) -> Dictionary:
	return {"success": success, "gained": gained, "new_value": new_value, "reason": reason}
