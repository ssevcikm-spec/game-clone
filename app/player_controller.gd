extends Node
# Ovladani hrace a kamera (krok "zapojeni do sceny", ZADANI-DALSI-VYVOJ §3 ukol 5).
#
# NEMA GRANULI ANI VLASTNIKA v .forge/roadmap.json - presne to pojmenovava
# ZADANI-DALSI-VYVOJ §3 ukol 5 (`app/player_controller.gd` = kamera +
# `queue_redraw` + vazby klaves). Je to tedy VADA ZADANI, ne hotova granule:
# agent roadmapu needituje.
#
# ⚠⚠ V2 (2026-10-07, 14. session) - POSUN A ANIMACE V JEDNE FAZI:
#   Do teto session si klient vsimal kroku AZ PO ZMENE DLAZDICE: `player.pos`
#   se prepsal na konci kroku (`sim.movement.apply_step`) a teprve tehdy se
#   zapnula animace chuze (`_action = ACTION_WALK`) - uzivatel to videl jako
#   "prvne posune postavu a az potom zobrazi animaci chuze". Reference to dela
#   opacne (`_src/classicuo` `Mobile.cs:776-782` + `:836-844`): dlazdici
#   COMMITNE az na konci kroku, ale do te doby kresli postavu POSUNUTOU
#   v pixelech o `Offset`, ktery roste s casem kroku (`x = delay / 80`,
#   `steps = maxDelay / 80`), a jeden casovac ridi i framy animace (80 ms).
#   Proto dnes:
#     * `sim.movement.pending_step(serial)` vraci prave bezici krok (stav,
#       ktery klient do teto session nikdy nectl - `mobile_anim` take nikdo
#       neodebiral),
#     * `update_step(krok)` ridi STAV (akce walk/run/idle) - animace tedy
#       startuje v okamziku ZAMERU, ne az po skoku,
#     * `player_pixel_offset()` vraci posun mezi dlazdicemi v pixelech (roste
#       po 80ms framech, nejvyse o jednu dlazdici) a `app/world_view` ho
#       pricte ke kresleni - svet se hybe po dlazdicich, postava plynule.
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

# Akce animace: 0 = walk, 1 = run, 4 = idle (zmEReno v anim.mul: akce 0 i 1 maji
# 10 framu, akce 4 ma 1 frame; jmena jsou v `assets/uo/anim/anim-sheets.json`).
const ACTION_WALK: int = 0
const ACTION_RUN: int = 1
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

# MYS: akce v InputMap -> tlacitko. DRZENE PRAVE TLACITKO = chuze kursoru
# (uzivatel 2026-10-07: "chůze držením klávesy (včetně pravého tlačítka myši)");
# UO to ma v `GameSceneInputHandler.cs:41`. LEVY klik tady ZAMERNE neni:
# klik-to-move patri `sim.pathfind` + jeho vojákovi (HANDOFF "Další kroky" 11),
# a levy klik bude potrebovat i UI (vyber predmetu).
const MOUSE := {
	"walk_to_cursor": MOUSE_BUTTON_RIGHT,
}

# Doba jednoho animacniho framu (docs/05 §5.1.1 = `core/const.gd` TURN_MS).
# Je to ZAROVEN krok pixeloveho posunu: ClassicUO `Mobile.cs:776-782` pocita
# `x = delay / 80` a `steps = maxDelay / 80`, takze se postava posune
# v peti skocich za krok (400 ms), ne plynule kazdy frame.
const ANIM_FRAME_MS := 80

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
var _step: Dictionary = {}      # prave bezici krok z `sim.movement.pending_step`


static func default_bindings() -> Dictionary:
	# Logicky smer (docs/04 §4.3) -> akce v InputMap. Klic `east`..`se` je to,
	# co `app/input_map.gd` preklada na `Command{t:"move", dir}`.
	# `walk_to` je DRZENE PRAVE TLACITKO (chuze kursoru) - viz hlavicka.
	return {
		"east": "move_east", "ne": "move_ne", "north": "move_north", "nw": "move_nw",
		"west": "move_west", "sw": "move_sw", "south": "move_south", "se": "move_se",
		"walk_to": "walk_to_cursor",
	}


static func register_actions() -> int:
	# Vraci pocet PRIDANYCH vazeb (0 znamena, ze uz vsechny byly) - cislo se
	# hodi do logu, aby "nic se nedeje" nebylo tiche. Klavesy i mys.
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
	for action in MOUSE.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var klik := InputEventMouseButton.new()
		klik.button_index = MOUSE[action]
		if not InputMap.action_has_event(action, klik):
			InputMap.action_add_event(action, klik)
			added += 1
	return added


func _ready() -> void:
	_iso = Iso.new()
	if camera == null and get_parent() != null:
		camera = get_parent().get_node_or_null("Camera") as Camera2D


func setup(player_mobile, sim_world, input_mapper, movement_system, world_view, loop_node = null) -> void:
	if _iso == null:
		_iso = Iso.new()
	# ⚠ PORADI VE FRAMU (V2, namEReno 2026-10-07): `app.loop` (ktery tickuje
	# simulaci) pridava `app/main.gd` AZ ZA timto uzlem, takze by controller
	# cetl stav PRED tickem. V ramci, kdy se krok commitne, by jeste jednou
	# pricetl posun k JIZ posunute dlazdici a obraz postavy by skocil
	# o 1,8 dlazdice (namEReno: 37,33 px misto 31,11 px u stareho klienta).
	# Priorita 1 = "az po uzlech s prioritou 0" (coz je `app.loop`).
	process_priority = 1
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
	if _iso == null:
		_iso = Iso.new()
	# Velikost okna pro DRZENE PRAVE TLACITKO: `app.input` pocita `run` ze
	# vzdalenosti kurzoru od STREDU obrazovky (ClassicUO 190 px) a viewport
	# sam nezna (je to RefCounted). Kdyz se okno zmeni, hodnota se obnovi.
	if input_map != null:
		input_map.view_size = get_viewport().get_visible_rect().size
	# Krok v letu ridi STAV (akce) i posun v pixelech - viz hlavicka (V2).
	update_step(_pending_of_player())
	# Kamera se posune jen kdyz se zmeni DLAZDICE (diskretni krok), ale kresli
	# se kazdy frame - bezi animace (80 ms na frame, docs/05 §5.1.1).
	var tile := player_tile()
	if tile != _last_tile:
		_follow()
	if view != null:
		view.set_action(_action)
		if view.has_method("set_player_offset"):
			view.set_player_offset(player_pixel_offset())
		view.queue_redraw()


func action() -> int:
	return _action


func step_state() -> Dictionary:
	# Kopie beziciho kroku (pro sondu a test) - prazdny slovnik = stojim.
	return _step.duplicate()


func _pending_of_player() -> Dictionary:
	if movement == null or player == null or not movement.has_method("pending_step"):
		return {}
	return movement.pending_step(player.serial)


func _sim_time() -> int:
	# Cas, ve kterem jsou `start_ms`/`delay_ms` kroku (cas SIMULACE, ne
	# nastenny): `app/loop.gd` posila vstupu `sim.world_time()`.
	if sim != null and sim.has_method("world_time"):
		return int(sim.world_time())
	return Time.get_ticks_msec()


func update_step(krok: Dictionary) -> void:
	# STAV podle beziciho kroku (V2): krok v letu = chuze/beh HNED (animace
	# startuje v okamziku zameru), zadny krok = idle. Vstup je vystup
	# `sim.movement.pending_step` - testy ho podavaji primo, aby se stav dal
	# merit bez realne smycky.
	_step = krok.duplicate()
	if _step.is_empty():
		_action = ACTION_IDLE
		return
	_action = ACTION_RUN if bool(_step["run"]) else ACTION_WALK


static func step_fraction(elapsed_ms: int, delay_ms: int) -> float:
	# Jak daleko je krok v CASE (0..1), po ANIMACNICH framech (80 ms) - presne
	# jako `delay / 80` v ClassicUO (`Mobile.cs:776-782`, `MovementSpeed.cs`).
	# Kdo by pocital plynule kazdy frame, dostane jiny pocet pixelu na frame
	# nez reference; kdo by nepocital vubec, dostane V2.
	if delay_ms <= 0:
		return 1.0
	var zaokrouhleno: int = (maxi(elapsed_ms, 0) / ANIM_FRAME_MS) * ANIM_FRAME_MS
	return clampf(float(zaokrouhleno) / float(delay_ms), 0.0, 1.0)


func player_pixel_offset(now_ms: int = -1) -> Vector2:
	# POSUN POSTAVY MEZI DLAZDICEMI v pixelech (V2). Dlazdice se jeste
	# necommitla (`player.pos` je porad stara), takze obraz postavy je
	# `to_screen(stara) + tento posun`; na konci kroku je posun presne jedna
	# dlazdice a `apply_step` prepise `pos` - obraz se tim nezmeni (neni skok).
	if _step.is_empty() or player == null:
		return Vector2.ZERO
	if _iso == null:
		_iso = Iso.new()
	var cas: int = _sim_time() if now_ms < 0 else now_ms
	var f: float = step_fraction(cas - int(_step["start_ms"]), int(_step["delay_ms"]))
	var dir: int = int(_step["dir"])
	var kam := Vector2i(player.pos.x + Const.DIR_DX[dir], player.pos.y + Const.DIR_DY[dir])
	var od: Vector2 = _iso.to_screen(player.pos.x, player.pos.y, int(player.pos.z))
	# Cilova vyska je ta z `can_step` (krok nahoru se kresli jako krok nahoru).
	var kam_px: Vector2 = _iso.to_screen(kam.x, kam.y, int(_step.get("z", player.pos.z)))
	return (kam_px - od) * f


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
