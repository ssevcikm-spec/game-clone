extends RefCounted
# Mapovani vstupu na `Command` - JEDINE misto v projektu, ktere smi pouzivat
# `Input` (docs/02 §2.2, docs/04 §4.1).
#
# Prevod je rozdelene na dve casti, aby se dal testovat bez okna:
#   * `step_command`, `object_command`, `key_command` - cista logika,
#   * `poll(...)` - precte skutecny vstup a pouzije je.
#
# VYCHOZI SADU KLAVES TENHLE SOUBOR NEDEFINUJE: docs/05 §5.3 ji oznacuje za
# rozhodnuti a vlastni ji `ui.hotkeys` (docs/04 §4.2). Sem se predava slovnikem
# `bindings` (nazev akce -> akce v InputMap).
#
# Co smlouva nepinuje (patri do docs/04): nazvy logickych akci nize
# ("north".."se", "war", "peace", "cancel_target", "use") a to, ze pravy klik
# jen otevira kontextove menu (posila ho UI, ne sim).

const Const = preload("res://core/const.gd")
const Iso = preload("res://core/iso.gd")

const ACTION_DIR := {
	"east": 0, "ne": 1, "north": 2, "nw": 3,
	"west": 4, "sw": 5, "south": 6, "se": 7,
}

var bindings: Dictionary = {}
var always_run: bool = false
var _seq: int = 0
var _iso


func _init(binding_table: Dictionary = {}) -> void:
	bindings = binding_table
	_iso = Iso.new()


func next_seq() -> int:
	_seq += 1
	return _seq


func direction_between(from: Vector2i, to: Vector2i) -> int:
	# Vraci cislo smeru 0..7, nebo -1 kdyz jsme na miste (neni kam krocit).
	if from == to:
		return -1
	var dx: int = signi(to.x - from.x)
	var dy: int = signi(to.y - from.y)
	for dir in 8:
		if Const.DIR_DX[dir] == dx and Const.DIR_DY[dir] == dy:
			return dir
	return -1


func step_command(from: Vector2i, to: Vector2i) -> Dictionary:
	# Klik-to-move: UO krokuje po dlazdicich, takze klik na vzdalenou dlazdici
	# je pozadavek na JEDEN krok tim smerem (docs/01 V1).
	var dir: int = direction_between(from, to)
	if dir < 0:
		return {}
	return {"t": "move", "dir": dir, "run": always_run, "seq": next_seq()}


func click_at(player: Vector2i, screen: Vector2, camera_offset: Vector2, z: int = 0) -> Dictionary:
	var world: Vector2 = screen + camera_offset
	var tile: Vector2i = _iso.to_tile(world.x, world.y, z)
	return step_command(player, tile)


func object_command(serial: int, doubled: bool = false) -> Dictionary:
	if doubled:
		return {"t": "use", "serial": serial}
	return {}


func key_command(action: String, serial: int = 0) -> Dictionary:
	if ACTION_DIR.has(action):
		return {"t": "move", "dir": ACTION_DIR[action], "run": always_run, "seq": next_seq()}
	match action:
		"war":
			return {"t": "war", "on": true}
		"peace":
			return {"t": "war", "on": false}
		"cancel_target":
			return {"t": "target_reply", "cursor": 0}
		"use":
			return {"t": "use", "serial": serial} if serial > 0 else {}
	return {}


func poll(player: Vector2i, camera_offset: Vector2, z: int = 0,
		mouse_position: Vector2 = Vector2.ZERO) -> Array[Dictionary]:
	# Klavesy jdou pres `bindings` (vlastni je ui.hotkeys); mys jen kdyz je
	# na ni vazana akce - jinak by vstup vymyslel vazbu, kterou nikdo nerozhodl.
	# Pozici mysi predava smycka (viewport), ne tenhle mapper: `Input` v Godotu 4
	# pozici mysi nezna a RefCounted nema na strom pristup.
	var out: Array[Dictionary] = []
	for action in bindings.keys():
		var input_action: String = str(bindings[action])
		if not InputMap.has_action(input_action):
			continue
		if not Input.is_action_just_pressed(input_action):
			continue
		if str(action) == "click_move":
			out.append(click_at(player, mouse_position, camera_offset, z))
			continue
		var command: Dictionary = key_command(str(action))
		if not command.is_empty():
			out.append(command)
	return out
