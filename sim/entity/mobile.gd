extends RefCounted
# Mobil = postava (granule entity.mobile, docs/04 §4.2 a tvar dat §4.5).
#
# TVAR DAT je dany smlouvou - `int` je v GDScriptu klicove slovo, proto se
# staty drzi v `stats` (trida `Stats`, ktera ma `int_`) a tady se jen prekladaji.
# `hp`/`stam`/`mana` maji i svuj `max_*` (docs/04 §4.5).
#
# CO SMLOUVA NEPINUJE / CO CHYBI (patri do docs/04 §4.2, agent docs/ needituje):
#   * smlouva uvadi `equipment: Equipment`, ale granule `entity.equipment`
#     (a `entity.item`, `entity.container`) jeste nejsou - proto je tu
#     `equip: Dictionary` (layer -> serial) presne podle tvaru z §4.5,
#   * `skills: Skills` je instance (tabulka komponent), zatimco §4.5 pise
#     `skills: PackedInt32Array` - hodnoty jsou uvnitr instance,
#   * `name`, `hunger`, `hunger` a `ai` jsou v §4.5, ale ne v tabulce komponent,
#   * `alive()` neni ve smlouve vubec - pridano, aby se smrt dala zjistit
#     jednim volanim (pouzije `sim.death`, az bude).
#
# Serial se NEDOSTAVA odtud: vydava ho `core.serial` (`SimWorld.next_serial`),
# aby dva mobily nikdy nemely stejny.

const StatsScript = preload("res://sim/entity/stats.gd")
const SkillsScript = preload("res://sim/entity/skills.gd")

var serial: int = 0
var body: int = 400              # 400 = muz, 401 = zena (anim.mul, docs/03 §3.5.1)
var hue: int = 0
var name: String = ""
var pos: Vector3i = Vector3i.ZERO
var dir: int = 0                 # 0..7, viz core/const.gd DIR_DX/DIR_DY
var flags: int = 0

var hp: int = 0
var max_hp: int = 0
var stam: int = 0
var max_stam: int = 0
var mana: int = 0
var max_mana: int = 0

var stats
var skills
var equip: Dictionary = {}       # layer:int -> serial:int
var backpack: int = 0
var notoriety: int = 0
var fame: int = 0
var karma: int = 0
var hunger: int = 0
var ai: Dictionary = {"state": "idle", "target": 0, "home": Vector3i.ZERO, "timer_ms": 0}


func _init(serial_value: int = 0, body_value: int = 400, pos_value: Vector3i = Vector3i.ZERO) -> void:
	serial = serial_value
	body = body_value
	pos = pos_value
	stats = StatsScript.new()
	skills = SkillsScript.new()
	# Maxima jdou ze statu (docs/04 §4.2 `entity.stats`), ne z opsanych cisel.
	max_hp = stats.hits_max()
	max_stam = stats.stam_max()
	max_mana = stats.mana_max()
	hp = max_hp
	stam = max_stam
	mana = max_mana


func alive() -> bool:
	return hp > 0


# -- stav (od 2026-10-09 JE mobil stavovy zdroj; granule `sim.offline`, MK) --
#
# PROC: do 2026-10-09 se mobily neukladaly - `sim/save.gd` to mel pojmenovane
# jako dluh ("entity zdrojem nejsou"). Save je CELEK (research/08 bod 13), takze
# stav musi dat kazdy, kdo ho ma; mobil ho ma.
#
# TVAR je JSON-safe a CELOCISELNY (docs/09 §9.10 bod 3):
#   * `Vector3i` se rozklada na `[x, y, z]` (JSON by z nej udelal TEXT a stav
#     by po nacteni vypadal jako posunuty),
#   * `equip` je SERAZENY seznam dvojic `[layer, serial]`, ne slovnik s int
#     klici (na poradi klicu slovniku nesmi zaviset stav - jako `registry.all()`),
#   * `skills` se cte VEREJNYM API `entity.skills` (`cap`), ne z jeho `_caps`:
#     `entity.skills` je cizi granule a jeji vnitrek se neopisuje.
# Poradi klicu ve vracenem slovniku nevadi - `core/hash` si je radi samo.
#
# CO TENHLE STAV NENESE (pojmenovane, ne tichy dluh): nic z `render`/`ui`.

func state() -> Dictionary:
	return {
		"serial": serial,
		"body": body,
		"hue": hue,
		"name": name,
		"pos": [pos.x, pos.y, pos.z],
		"dir": dir,
		"flags": flags,
		"hp": hp,
		"max_hp": max_hp,
		"stam": stam,
		"max_stam": max_stam,
		"mana": mana,
		"max_mana": max_mana,
		"stats": [stats.str_, stats.dex, stats.int_],
		"skills": _skills_state(),
		"equip": _equip_state(),
		"backpack": backpack,
		"notoriety": notoriety,
		"fame": fame,
		"karma": karma,
		"hunger": hunger,
		"ai": [str(ai.get("state", "idle")), int(ai.get("target", 0))] + _home_parts() \
			+ [int(ai.get("timer_ms", 0))],
	}


func restore(d: Dictionary) -> void:
	# Opak `state()`: co se ulozilo, se musi vratit PRESNE (kontroluje to
	# round-trip v `tests/cases/entity_state.gd` a brana G7).
	if d == null or d.is_empty():
		return
	serial = int(d.get("serial", serial))
	body = int(d.get("body", body))
	hue = int(d.get("hue", hue))
	name = str(d.get("name", name))
	var p = d.get("pos", [])
	if p is Array and p.size() >= 3:
		pos = Vector3i(int(p[0]), int(p[1]), int(p[2]))
	dir = int(d.get("dir", dir))
	flags = int(d.get("flags", flags))
	hp = int(d.get("hp", hp))
	max_hp = int(d.get("max_hp", max_hp))
	stam = int(d.get("stam", stam))
	max_stam = int(d.get("max_stam", max_stam))
	mana = int(d.get("mana", mana))
	max_mana = int(d.get("max_mana", max_mana))
	var st = d.get("stats", [])
	if st is Array and st.size() >= 3:
		stats = StatsScript.new(int(st[0]), int(st[1]), int(st[2]))
	_restore_skills(d.get("skills", {}))
	_restore_equip(d.get("equip", []))
	backpack = int(d.get("backpack", backpack))
	notoriety = int(d.get("notoriety", notoriety))
	fame = int(d.get("fame", fame))
	karma = int(d.get("karma", karma))
	hunger = int(d.get("hunger", hunger))
	var a = d.get("ai", [])
	if a is Array and a.size() >= 6:
		ai = {
			"state": str(a[0]),
			"target": int(a[1]),
			"home": Vector3i(int(a[2]), int(a[3]), int(a[4])),
			"timer_ms": int(a[5]),
		}


func _home_parts() -> Array:
	# `ai.home` je `Vector3i`, ale po `restore()` z JSONu muze prijit i pole -
	# obe podoby musi `state()` zapsat stejne (jinak by se stav po round-tripu
	# rozešel a hash by se zmenil).
	var h = ai.get("home", Vector3i.ZERO)
	if h is Vector3i:
		return [h.x, h.y, h.z]
	if h is Array and h.size() >= 3:
		return [int(h[0]), int(h[1]), int(h[2])]
	return [0, 0, 0]


func _equip_state() -> Array:
	var layers: Array = equip.keys()
	layers.sort()
	var out: Array = []
	for layer in layers:
		out.append([int(layer), int(equip[layer])])
	return out


func _skills_state() -> Dictionary:
	var caps: Array = []
	for i in skills.values.size():
		caps.append(skills.cap(i) - SkillsScript.CAP_DEFAULT)
	return {
		"values": Array(skills.values),
		"locks": Array(skills.locks),
		"caps": caps,
	}


func _restore_skills(d) -> void:
	if not (d is Dictionary):
		return
	var values = d.get("values", [])
	if not (values is Array):
		return
	var caps = d.get("caps", [])
	# STropy PRED hodnotami: `set_value` clampuje na strop, takze opacne poradi
	# by legendarni svitek (1200) tise snizilo na 1000.
	if caps is Array:
		for i in mini(caps.size(), skills.values.size()):
			skills.raise_cap(i, int(caps[i]))
	for i in mini(values.size(), skills.values.size()):
		skills.set_value(i, int(values[i]))
	var locks = d.get("locks", [])
	if locks is Array:
		for i in mini(locks.size(), skills.locks.size()):
			skills.set_lock(i, int(locks[i]))


func _restore_equip(d) -> void:
	equip = {}
	if not (d is Array):
		return
	for row in d:
		if row is Array and row.size() >= 2:
			equip[int(row[0])] = int(row[1])
