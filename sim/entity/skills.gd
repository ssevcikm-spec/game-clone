extends RefCounted
# Skilly v desetinach (granule entity.skills, docs/04 §4.2, docs/05 §5.10).
#
# Vsechno je CELE CISLO v desetinach: 0..1000 = 0.0..100.0, strop 1200 po
# legendarnim svitku, celkovy strop 7000 (= 700.0, `Const.SKILL_CAP`).
# Float ve stavu je drift (docs/09 §9.10 bod 3) - proto tu nikdy float neni.
#
# Data: `data/skills.json` (58 skillu, producent granule `data.skills`). Kdyz
# soubor chybi, HLASI se to a hodnoty zustanou nuly - ticha nula by vypadala
# jako "hotovo" (docs/08 §8.6).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `raise_cap` - legendarni svitek zveda strop JEDNOHO skillu na 1200
#     (docs/05 §5.10); tabulka komponent s tim nepocita,
#   * `set_value` CLAMPUJE na strop - zadani to chce ("hodnota 1000 + pokus
#     o rust = zustane 1000"), ale smlouva to nepise,
#   * kdo hlida CELKOVY strop 7000 (docs/05 §5.10) - dnes jen `total()`,
#     rozhoduje `sim.skill_gain` (granule M2, jeste neni).

const Const = preload("res://core/const.gd")

const SKILLS_PATH := "res://data/skills.json"
const SKILL_COUNT := 58
const CAP_DEFAULT := 1000
const CAP_LEGENDARY := 1200
const LOCK_UP := 0
const LOCK_DOWN := 1
const LOCK_LOCKED := 2

var values: PackedInt32Array
var locks: PackedInt32Array

var _caps: PackedInt32Array


func _init(skill_count: int = SKILL_COUNT) -> void:
	values = PackedInt32Array()
	values.resize(skill_count)
	locks = PackedInt32Array()
	locks.resize(skill_count)
	_caps = PackedInt32Array()
	_caps.resize(skill_count)
	_check_data()


func _check_data() -> void:
	if not FileAccess.file_exists(SKILLS_PATH):
		push_warning("entity.skills: chybi " + SKILLS_PATH
			+ " - hodnoty skillu zustavaji nuly (spust `python tools/gates/gen-content.py --only skills`)")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	var pocet: int = (parsed as Array).size() if parsed is Array else -1
	if pocet != values.size():
		push_warning("entity.skills: %s ma %d skillu, ocekavano %d"
			% [SKILLS_PATH, pocet, values.size()])


func _index(skill: int) -> int:
	# Neznamy index se hlasi jako -1; hodnoty mimo rozsah se chovaji jako nula
	# (hra se nesmi zastavit kvuli jednomu cislu z dat).
	return skill if skill >= 0 and skill < values.size() else -1


func value(skill: int) -> int:
	var i := _index(skill)
	return 0 if i < 0 else values[i]


func set_value(skill: int, v: int) -> void:
	# Clamp na strop: nad strop se nikdy nedostane (docs/05 §5.10).
	var i := _index(skill)
	if i < 0:
		return
	values[i] = clampi(v, 0, cap(skill))


func cap(skill: int) -> int:
	var i := _index(skill)
	return CAP_DEFAULT if i < 0 else CAP_DEFAULT + _caps[i]


func raise_cap(skill: int, amount: int = CAP_LEGENDARY - CAP_DEFAULT) -> void:
	var i := _index(skill)
	if i >= 0:
		_caps[i] = maxi(_caps[i], amount)


func total() -> int:
	var out: int = 0
	for v in values:
		out += v
	return out


func lock(skill: int) -> int:
	var i := _index(skill)
	return LOCK_UP if i < 0 else locks[i]


func set_lock(skill: int, l: int) -> void:
	var i := _index(skill)
	if i >= 0:
		locks[i] = l
