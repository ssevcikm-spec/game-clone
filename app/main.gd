extends Node2D
# Scena a start hry (docs/02 §2.5): vytvori sim, nacte data a preda rizeni
# `app/loop.gd`. HERNI PRAVIDLA TU NEJSOU (prompt granule) - jen slozeni.
#
# `SimWorld` ma sice `class_name`, ale ten je známy jen pres cache importu
# (.godot/global_script_class_cache.cfg) - v cerstvem stromu spadne parse
# ("Identifier SimWorld not declared", namEReno 2026-10-02). Proto preload
# s vlastnim jmenem, ktere s globalnim nekoliduje (docs/02 §2.6.2).
const SimScript = preload("res://sim/sim_world.gd")
const Loop = preload("res://app/loop.gd")
const InputMapScript = preload("res://app/input_map.gd")
const MapScript = preload("res://sim/world/map.gd")
const TextureCache = preload("res://render/texture_cache.gd")
const WalkScript = preload("res://sim/world/walk.gd")
const MovementScript = preload("res://sim/systems/movement.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")

const DEFAULT_SEED: int = 1234
const BRITAIN := Vector2i(1495, 1630)   # namesti Britainu (docs/01 §1.4)
const PLAYER_BODY: int = 400            # 400 = muz (tělo je jen v anim.mul)
# Co se nacita na start. Zbytek dat (items, recipes, monsters...) pribude
# s granulemi M1+; kdyz soubor chybi, hra se musi ozvat, ne mlcet.
const DATA_FILES := {
	"balance": "res://data/balance.json",
}

var sim = null
var loop = null
var player = null
var movement = null
var map = null
var controller = null


func _ready() -> void:
	var data: Dictionary = _load_data()
	sim = SimScript.new(DEFAULT_SEED, data)
	loop = Loop.new()
	loop.sim = sim
	loop.input_map = InputMapScript.new()
	add_child(loop)
	_setup_world()
	print("[main] sim spusten (seed ", DEFAULT_SEED, ", datovych souboru ", data.size(), ")")


func _setup_world() -> void:
	# Klient (mapa + textury) je ODDELENY od simulace: `main` je jedine misto,
	# kde se potkavaji (docs/02 §2.2). Kdyz uzel ve scene chybi, rekne se to -
	# tiche "nic se nekresli" je presne vada, kterou mel projekt 2026-10-06.
	var view := get_node_or_null("WorldView")
	if view == null:
		push_warning("app.main: ve scene chybi uzel WorldView - mapa se nevykresli")
		return
	map = MapScript.new()
	var textures = TextureCache.new()
	view.setup(map, textures)
	print("[main] svet: ", view.visible_count(), " objektu (", view.counts(), "), textury ",
		textures.stats())
	_setup_player(view)


func _setup_player(view) -> void:
	# Poradi je dane zavislostmi (ZADANI-DALSI-VYVOJ §3 ukol 6):
	# world.walk -> entity.mobile -> sim.movement -> registrace v SimWorld.
	# Systemy se registruji TADY (integraci misto), protoze `sim/sim_world.gd`
	# je granule `sim.world_loop` a agent ji needituje.
	var walk = WalkScript.new(map)
	var serial: int = sim.next_serial()
	player = MobileScript.new(serial, PLAYER_BODY, Vector3i(BRITAIN.x, BRITAIN.y, 0))
	player.pos = Vector3i(BRITAIN.x, BRITAIN.y, walk.surface_z(BRITAIN.x, BRITAIN.y))
	player.dir = 0
	sim.player_serial = serial

	movement = MovementScript.new(walk, sim.clock(), sim.events())
	movement.player_serial = serial
	movement.register(player)
	sim.systems["movement"] = movement

	view.set_player(player)
	controller = get_node_or_null("PlayerController")
	if controller == null:
		push_warning("app.main: ve scene chybi uzel PlayerController - hrac se nepohne")
		return
	controller.setup(player, sim, loop.input_map, movement, view, loop)
	print("[main] hrac: serial ", serial, " na ", player.pos, " (", map.land_at(player.pos.x, player.pos.y),
		" land), systemu v sim: ", sim.systems.keys())


func _load_data() -> Dictionary:
	var out: Dictionary = {}
	for key in DATA_FILES.keys():
		var path: String = DATA_FILES[key]
		if not FileAccess.file_exists(path):
			push_warning("app.main: chybi datovy soubor " + path)
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			push_warning("app.main: " + path + " se neda precist jako JSON")
			continue
		out[key] = parsed
	return out
