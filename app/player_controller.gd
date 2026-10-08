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
#
# ⚠⚠ ZADANI 19 (2026-10-08) - v tomhle souboru pribyly TRI veci:
#   * V14: `_publish_center()` posila `input_map.player_screen` PRESNOU pozici
#     hrace na obrazovce (`player_ground_position() - camera_offset`) - klient
#     jako jediny zna `gui_odsazeni` i posun kroku; namEReno 4 473 z 11 163
#     pozic kurzoru vracelo kvuli stredove chybe jiny smer,
#   * V15a: `TURN_KEYS` (Ctrl + smer) - vstup pro otoceni na miste; modifikator
#     je zmereny (`_analyza/p22-pohyb-ctrl.gd`), bez nej by se otaceni a krok
#     spoustely obe (nebo ani jedno),
#   * V4: `CANCEL_KEYS` (Esc) - tvrdy stop auto-runu (auto-run sam rusi novy
#     stisk praveho tlacitka, reference `GameSceneInputHandler.cs:827-828`).

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

# ⚠ PREPINAC CHUZE/BEH (18. session, vada "chybi beh jako rychlost pohybu"):
# UO ma beh jako vychozi pohyb a makro `AlwaysRun` ho prepina
# (`MacroManager.cs:1189-1192`). Klavesa je volba KLIENTA (granule `ui.hotkeys`
# jeste neexistuje), proto je tady - a je videt v konzoli pri kazdem prepnuti.
const TOGGLE_KEYS := {
	"run_toggle": [KEY_SHIFT],
}

# OTOCENI NA MISTE (V15, zadani 19): Ctrl + smerova klavesa. Smer v prikazu je
# ABSOLUTNI (0..7), takze staci stejne klavesy jako pro pohyb - Ctrl je odlisuje.
# Ze to takhle jde, je NAMERENE (`_analyza/p22-pohyb-ctrl.gd`): akce vazana na
# `KEY_RIGHT` BEZ modifikatoru je stisknuta i s drzenym Ctrl, kdezto akce
# s `ctrl_pressed = true` jen tehdy, kdyz Ctrl opravdu drzi. Bez toho by se
# "otocit" a "krocit" spoustely obe (nebo ani jedno).
const TURN_KEYS := {
	"turn_east": [KEY_RIGHT, KEY_KP_6],
	"turn_ne": [KEY_KP_9],
	"turn_north": [KEY_UP, KEY_KP_8],
	"turn_nw": [KEY_KP_7],
	"turn_west": [KEY_LEFT, KEY_KP_4],
	"turn_sw": [KEY_KP_1],
	"turn_south": [KEY_DOWN, KEY_KP_2],
	"turn_se": [KEY_KP_3],
}

# TVRDY STOP AUTO-RUNU (V4, zadani 19): Esc. Auto-run jinak rusi PRAVY klik
# (reference `GameSceneInputHandler.cs:827-828`) - ale hrac, ktery se rozbehne
# a nevi jak zastavit, potrebuje i klavesu. Vlastni ji granule `ui.hotkeys`
# (jeste neexistuje), proto je tady.
const CANCEL_KEYS := {
	"auto_run_cancel": [KEY_ESCAPE],
}

# OBECNA INTERAKCE (20. session, pokyn uzivatele 2026-10-08: "tlacitko je nejen
# na tezbu, ale vseobecne interaktivni"): jedno tlacitko posle CIL pod kurzorem
# a sim rozhodne, co se s nim da delat (`Command{t:"interact"}`).
# DVE KLAVESY ZAMERNE: `E` je dnes bezny "interaguj" ve hrach a `T` jsem uz
# uzivateli rekl u prvniho navrhu - dve vazby na jednu akci nikomu nevadi
# (stejne jako sipky + numpad u pohybu). Presna sada patri granuli `ui.hotkeys`.
const INTERACT_KEYS := {
	"interact": [KEY_E, KEY_T],
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
# ⚠ SMER KRESLENI vs SMER SIMULACE (17. session, 2026-10-08) - VADA
# "animace nezmeni orientaci, postava klouze do strany": `sim.movement` zapise
# `mob.dir` az v `apply_step` na KONCI kroku (400 ms), takze kdyz hrac zmeni
# smer UPROSTRED kroku, kreslil se jeste 400 ms stary smer - a postava se
# mezitim posouvala novym smerem (namEReno: 1 295 framu, kdy `player.dir` !=
# `pending_step.dir`, sonda `_analyza/p20-hlubka.gd`). Smer kresleni je proto
# stav KLIENTA: nastavi se hned se zamerem kroku (`update_step`).
var _view_dir: int = 0


static func default_bindings() -> Dictionary:
	# Logicky smer (docs/04 §4.3) -> akce v InputMap. Klic `east`..`se` je to,
	# co `app/input_map.gd` preklada na `Command{t:"move", dir}`.
	# `walk_to` je DRZENE PRAVE TLACITKO (chuze kursoru) - viz hlavicka.
	return {
		"east": "move_east", "ne": "move_ne", "north": "move_north", "nw": "move_nw",
		"west": "move_west", "sw": "move_sw", "south": "move_south", "se": "move_se",
		"walk_to": "walk_to_cursor", "run_toggle": "run_toggle",
		"turn_east": "turn_east", "turn_ne": "turn_ne", "turn_north": "turn_north",
		"turn_nw": "turn_nw", "turn_west": "turn_west", "turn_sw": "turn_sw",
		"turn_south": "turn_south", "turn_se": "turn_se",
		"auto_run_cancel": "auto_run_cancel",
		# OBECNA INTERAKCE (20. session): klient posle jen cil, nástroj vybira sim.
		"interact": "interact",
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
	for action in TOGGLE_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in TOGGLE_KEYS[action]:
			var prepinac := InputEventKey.new()
			prepinac.keycode = code
			if not InputMap.action_has_event(action, prepinac):
				InputMap.action_add_event(action, prepinac)
				added += 1
	# OTOCENI NA MISTE (V15): stejne klavesy jako pohyb, ale s Ctrl
	# (`ctrl_pressed = true`). Kdyby se modifikator neuvedl, byla by to táž
	# vazba jako pohyb a otoceni by se spustilo i bez Ctrl (namEReno sondou
	# `_analyza/p22-pohyb-ctrl.gd`).
	for action in TURN_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in TURN_KEYS[action]:
			var otoc := InputEventKey.new()
			otoc.keycode = code
			otoc.ctrl_pressed = true
			if not InputMap.action_has_event(action, otoc):
				InputMap.action_add_event(action, otoc)
				added += 1
	for action in CANCEL_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in CANCEL_KEYS[action]:
			var stop := InputEventKey.new()
			stop.keycode = code
			if not InputMap.action_has_event(action, stop):
				InputMap.action_add_event(action, stop)
				added += 1
	# OBECNA INTERAKCE (20. session): klavesy E a T na jednu akci.
	for action in INTERACT_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in INTERACT_KEYS[action]:
			var inter := InputEventKey.new()
			inter.keycode = code
			if not InputMap.action_has_event(action, inter):
				InputMap.action_add_event(action, inter)
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
		# ⚠ 20. session: CERNY PAS GUI je mimo svet - klient vi, kde konci
		# viditelna plocha sveta (`gui_odsazeni` je POLOVINA pasu, proto 2x).
		# Bez toho by obecna interakce (E/T) sahala i na dlazdici POD zurnalem.
		if view != null:
			input_map.gui_pas = view.gui_odsazeni * 2.0
	# Krok v letu ridi STAV (akce) i posun v pixelech - viz hlavicka (V2).
	update_step(_pending_of_player())
	# ⚠⚠ KAMERA SE POSOUVA KAZDY FRAME (17. session, 2026-10-08) - VADA
	# "obraz se pohybuje skokove, ne plynule": do teto session se stred kamery
	# prepsal JEN kdyz se zmenila DLAZDICE (`if tile != _last_tile: _follow()`),
	# takze svet stal a pak skocil o celou dlazdici - namEReno **44,00 px na
	# frame** (sonda `_analyza/p20-kadence.gd`). Postava se pritom posouvala
	# plynule, takze se postava a svet rozesly presne o ten skok.
	# Reference drzi hrace ve stredu a posouva SVET (`_src/classicuo`
	# `Mobile.cs:776-782`, `:836-844`), takze kamera dostava STEJNY posun jako
	# postava. `_follow()` se tim nemeni - jen se k nemu pricte posun kroku.
	var offset: Vector2 = player_pixel_offset()
	var tile := player_tile()
	if view != null:
		view.set_action(_action)
		if view.has_method("set_player_offset"):
			view.set_player_offset(offset)
	if tile != _last_tile:
		_follow(offset)
	elif view != null and view.has_method("look_at_tile"):
		# Same-slide: stred se nemeni, jen se pricte posun v pixelech.
		view.look_at_tile(tile, int(player.pos.z), offset)
	if view != null:
		view.queue_redraw()
	# `loop.camera_offset` se musi obnovit i na framech BEZ zmeny dlazdice: kamera
	# se od 17. session posouva kazdy frame (o posun kroku), takze stara hodnota
	# by pri prepocitavani svet<->obrazovka (`app.input.click_at`) chybovala.
	if loop != null:
		loop.camera_offset = _camera_offset()
	# ⚠ V14 (2026-10-08, zadani 19): PRESNA POZICE HRACE NA OBRAZOVCE pro smer
	# z mysi. Smer se pocita z kurzoru VULCI hraci, ale klient ho do teto
	# session skladal z `z = 0` (`app/loop.gd:39`) - na vysce (Britain z = 10)
	# vysel stred o 40 px niz, nez kde hrac stoji (namEReno sondou
	# `_analyza/p22-mys-sonda.gd`: 4 473 z 11 163 pozic kurzoru vratilo jiny
	# smer). `player_ground_position() - camera_offset` je to, co hrac VIDI:
	# `gui_odsazeni` i posun beziciho kroku jsou v obou clenech, takze se
	# vykrati (`world_view.set_player_offset` i `look_at_tile` dostavaji tyz
	# posun) a hodnota se v case nemeni.
	_publish_center()


func _publish_center() -> void:
	# Vlastni metoda (ne jen radek v `_process`): test tak muze zmerit, ze
	# klient stred opravdu posila - `_process` viewport v testu nema.
	if input_map == null or view == null or camera == null:
		return
	if not view.has_method("player_ground_position"):
		return
	input_map.player_screen = view.player_ground_position() - _camera_offset()


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
		# ⚠⚠ 19. session (2026-10-08) - V15: OTOCENI NA MISTE SE MUSI NAKRESLIT.
		# Nezavislym overenim (task-4, `_analyza/p22-overeni-*`) se naměřilo, ze
		# v `app/` NEBYL ZADNY konzument eventu `mobile_turned` - klient kreslil
		# smer jen z `_pending` kroku (`update_step`). Prikaz `turn` ale zadny
		# krok nevytvari, takze by se `mob.dir` zmenil a postava by se porad
		# kreslila starym smerem (uzivatel: "postava se neumi otocit").
		# Kdyz krok NENI v letu, je `player.dir` jedINY zdroj pravdy o smeru -
		# klient ho proto PREBIRA (ne aby si ho pocital sam; tim se drzi
		# rozdeleni "sim vlastni stav, klient ho kresli").
		if player != null and _view_dir != int(player.dir):
			_view_dir = ((int(player.dir) % 8) + 8) % 8
			if view != null and view.has_method("set_view_dir"):
				view.set_view_dir(_view_dir)
			_follow(player_pixel_offset())
		return
	_action = ACTION_RUN if bool(_step["run"]) else ACTION_WALK
	# SMER KRESLENI SE MENI HNED SE ZAMEREM (17. session): `player.dir` se
	# prepise az na konci kroku, takze by postava 400 ms "klouzala do strany".
	var dir: int = int(_step.get("dir", _view_dir))
	if _view_dir != dir:
		_view_dir = dir
		if view != null and view.has_method("set_view_dir"):
			view.set_view_dir(dir)
		_follow(player_pixel_offset())


func view_dir() -> int:
	# Smer, kterym se postava KRESLI (mobil ma jeste stary - viz `_view_dir`).
	return _view_dir


static func step_fraction(elapsed_ms: int, delay_ms: int) -> float:
	# Jak daleko je krok v CASE (0..1).
	#
	# ⚠⚠ 18. session (2026-10-08) - VADA "POHYB OBRAZU NENI PLYNUY, TRHAVE ALE
	# PRAVIDELNE" (uzivatel: "vnímám trhavost, ale plynulou, ne náhodnou").
	# Do teto session se `elapsed` zaokrouhloval DOLU na 80 ms
	# (`(elapsed / ANIM_FRAME_MS) * ANIM_FRAME_MS`), takze se posun zmenil jen
	# 5x za krok (400/80) - na 75 FPS to znamena ~6 framu BEZ pohybu a pak skok
	# ~8,8 px. Presne to je "trhavost, ktera je plynula": neni nahodna, je
	# periodicka. Reference pocita `x = delay / 80f` (FLOAT) a `GetPixelOffset`
	# jím NASOBI (`Mobile.cs:776-782`, `MovementSpeed`), takze posun roste
	# plynule kazdy frame. Na cely pixel ho zaokrouhluje az kresleni
	# (`player_pixel_offset`) - reference kresli na celociselne pozice
	# (`GameObject.cs:152-153`), takze je obraz plynuly A ostry zaroven.
	if delay_ms <= 0:
		return 1.0
	return clampf(float(maxi(elapsed_ms, 0)) / float(delay_ms), 0.0, 1.0)


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
	# ⚠ ZAOKROUHLENI NA CELY PIXEL (18. session): reference kresli vse na
	# celociselne pozice (`GameObject.cs:152-153`: `(X - Y) * 22`, `int`), takze
	# se svet hybe po JEDNOM pixelu. Subpixelovy posun u pixel-artu meni vzorkovani
	# kazdeho pixelu (sonda `_analyza/p21-teren-sonda.gd`: pri posunu o 0,5 px se
	# zmeni 91,55 % pixelu obrazu!) - krajina pak "sumi" a hrany dlazdic se
	# rozjizdeji. Zaokrouhleny posun je plynuly (1 px) a pritom ostry.
	var posun: Vector2 = (kam_px - od) * f
	return Vector2(roundf(posun.x), roundf(posun.y))


func _follow(offset: Vector2 = Vector2.ZERO) -> void:
	_last_tile = player_tile()
	if view != null and view.has_method("look_at_tile"):
		# Vyska jde s sebou: jinak by kamera stala na `z = 0` a postava na kopci
		# by utekla nahoru (viz `app/world_view.look_at_tile`). `offset` drzi
		# hrace ve stredu i UPROSTRED kroku (viz `_process`).
		view.look_at_tile(_last_tile, int(player.pos.z), offset)
	elif camera != null:
		camera.position = _iso.to_screen(_last_tile.x, _last_tile.y, int(player.pos.z)) \
			+ Vector2(Const.ISO_STEP, Const.TILE_H / 2) + offset
	if loop != null:
		loop.player_tile = _last_tile
		loop.player_z = int(player.pos.z)
		loop.camera_offset = _camera_offset()


func _camera_offset() -> Vector2:
	# Levy horni roh sveta na obrazovce - `app/input_map.click_at` pocita
	# `world = screen + camera_offset`.
	if camera == null:
		return Vector2.ZERO
	# Testy tvori uzel bez sceny (N8) - viewport pak neni a velikost okna
	# neznáme; bere se nula, ne vymysleny stred.
	var vp := get_viewport()
	var size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2.ZERO
	return camera.position - size / 2.0
