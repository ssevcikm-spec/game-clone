extends Node
# Ovladani hrace a kamera (krok "zapojeni do sceny", ZADANI-DALSI-VYVOJ §3 ukol 5).
#
# NEMA GRANULI ANI VLASTNIKA v .forge/roadmap.json - presne to pojmenovava
# ZADANI-DALSI-VYVOJ §3 ukol 5 (`app/player_controller.gd` = kamera +
# `queue_redraw` + vazby klaves). Je to tedy VADA ZADANI, ne hotova granule:
# agent roadmapu needituje.
#
# CO TU JE A PATRIT SEM NEBUDE:
#   * VYCHOZI KLAVESY patří granuli `ui.hotkeys` (ta jeste neexistuje).
#     Dokud neni, drzi je integrace - bez nich se hra neda ovladat vubec.
#     `InputMap` akce se zakladaji ZA BEHU (`register_actions`), protoze
#     `project.godot` vlastni granule `boot.project` a agent ho needituje.
#   * Kamera sleduje hrace po DLAZDICICH, ne plynule: pohyb v UO je diskretni
#     krok, "plynuly lerp" je v docs/05 §5.1.4 vyslovne zakazany.
#
# VADA ZADANI, KTEROU JE POTREBA OPRAVIT V TEXTU: ZADANI-DALSI-VYVOJ §3 ukol 5
# pise, ze se `input_map.poll()` "nikdy nezavola", protoze `main.gd` prida do
# stromu jen `loop`. To NENI pravda: `loop.input_map` je reference a `poll()`
# se z `app/loop.gd:32` opravdu vola. `input_map` je navic `RefCounted`, takze
# do stromu pridat NELZE. Skutecna pricina, proc klavesy nic nedelaly, je jina:
# `bindings` byl prazdny slovnik a v `InputMap` nebyly zadne akce (namEReno
# 2026-10-06).

const Const = preload("res://core/const.gd")
const Iso = preload("res://core/iso.gd")

# Akce animace: 0 = walk, 4 = idle (zmEReno v anim.mul: akce 0 ma 10 framu,
# akce 4 ma 1 frame; jmena jsou v `assets/uo/anim/anim-sheets.json`).
const ACTION_WALK: int = 0
const ACTION_IDLE: int = 4

# Nazev akce v InputMap -> klavesy. Numpad je v UO klasika (1-9 = 8 smeru).
const KEYS := {
	"move_east": [KEY_RIGHT, KEY_KP_6],
	"move_ne": [KEY_KP_9],
	"move_north": [KEY_UP, KEY_KP_8],
	"move_nw": [KEY_KP_7],
	"move_west": [KEY_LEFT, KEY_KP_4],
	"move_sw": [KEY_KP_1],
	"move_south": [KEY_DOWN, KEY_KP_2],
	"move_se": [KEY_KP_3],
}

var sim = null
var input_map = null
var movement = null
var player = null
var view: Node2D = null
var loop = null            # app/loop.gd - jen kvuli `player_tile` a `camera_offset`
var camera: Camera2D = null

var _iso
var _last_tile: Vector2i = Vector2i(-9999, -9999)
var _action: int = ACTION_IDLE
var _walk_until_ms: int = 0


static func default_bindings() -> Dictionary:
	# Logicky smer (docs/04 §4.3) -> akce v InputMap. Klic `east`..`se` je to,
	# co `app/input_map.gd` preklada na `Command{t:"move", dir}`.
	return {
		"east": "move_east", "ne": "move_ne", "north": "move_north", "nw": "move_nw",
		"west": "move_west", "sw": "move_sw", "south": "move_south", "se": "move_se",
	}


static func register_actions() -> int:
	# Vraci pocet PRIDANYCH klavesovych vazeb (0 znamena, ze uz vsechny byly) -
	# cislo se hodi do logu, aby "nic se nedeje" nebylo tiche.
	var added: int = 0
	for action in KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in KEYS[action]:
			var event := InputEventKey.new()
			event.keycode = code
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
				added += 1
	return added


func _ready() -> void:
	_iso = Iso.new()
	if camera == null and get_parent() != null:
		camera = get_parent().get_node_or_null("Camera") as Camera2D


func setup(player_mobile, sim_world, input_mapper, movement_system, world_view, loop_node = null) -> void:
	player = player_mobile
	sim = sim_world
	input_map = input_mapper
	movement = movement_system
	view = world_view
	loop = loop_node
	var added: int = register_actions()
	if input_map != null:
		input_map.bindings = default_bindings()
	print("[controller] klavesy: ", added, " novych vazeb, smeru ",
		default_bindings().size(), ", hrac serial ", player.serial if player != null else -1)
	_follow()


func player_tile() -> Vector2i:
	return Vector2i(player.pos.x, player.pos.y) if player != null else Vector2i.ZERO


func _process(_delta: float) -> void:
	if player == null:
		return
	# Kamera se posune jen kdyz se zmeni DLAZDICE (diskretni krok), ale kresli
	# se kazdy frame - bezi animace (80 ms na frame, docs/05 §5.1.1).
	var tile := player_tile()
	if tile != _last_tile:
		_follow()
		# Chuze se hraje po dobu jednoho kroku (WALK_MS), pak se prejde do idle.
		_action = ACTION_WALK
		_walk_until_ms = Time.get_ticks_msec() + Const.WALK_MS
	elif _action != ACTION_IDLE and Time.get_ticks_msec() >= _walk_until_ms:
		_action = ACTION_IDLE
	if view != null:
		view.set_action(_action)
		view.queue_redraw()


func action() -> int:
	return _action


func _follow() -> void:
	_last_tile = player_tile()
	if view != null and view.has_method("look_at_tile"):
		# Vyska jde s sebou: jinak by kamera stala na `z = 0` a postava na kopci
		# by utekla nahoru (viz `app/world_view.look_at_tile`).
		view.look_at_tile(_last_tile, int(player.pos.z))
	elif camera != null:
		camera.position = _iso.to_screen(_last_tile.x, _last_tile.y, int(player.pos.z)) \
			+ Vector2(Const.ISO_STEP, Const.TILE_H / 2)
	if loop != null:
		loop.player_tile = _last_tile
		loop.camera_offset = _camera_offset()


func _camera_offset() -> Vector2:
	# Levy horni roh sveta na obrazovce - `app/input_map.click_at` pocita
	# `world = screen + camera_offset`.
	if camera == null:
		return Vector2.ZERO
	var size: Vector2 = get_viewport().get_visible_rect().size
	return camera.position - size / 2.0
