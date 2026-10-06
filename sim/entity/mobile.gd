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
