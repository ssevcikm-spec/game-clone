extends RefCounted
# Pohyb (granule sim.movement, docs/04 §4.2 a tok §4.6.1, docs/05 §5.1).
#
# TOK (doslovne ze smlouvy):
#   Command{t:"move"} -> request_step(m, dir, run)
#     -> world.walk.can_step()   # z, StepHeight, flagy, diagonala
#     -> kdyz ok: apply_step za `delay_ms` (400 chuze / 200 beh)
#     -> event `mobile_moved` + `mobile_anim`
#     -> kdyz ne: event message{"You cannot move there."}
#
# PRODLEVY jsou z `core/const.gd` (WALK_MS/RUN_MS/MOUNT_*), ne opsane.
# Prijimaci kriterium: `request_step(m, 0, false).delay_ms == 400` a po
# `apply_step` se `pos.x += 1` (smer 0 = vychod, `Const.DIR_DX`).
#
# STAMINA (docs/05 §5.1.4): dva modely z `data/balance.json`
# (`stamina_drain_model`): "run_only" (1 bod za krok BEHU, chuze zdarma;
# vychozi) a "emulator" (1 bod za 16 kroku vcetne chuze).
#
# ODKUD MOBILY (do 2026-10-06 to bylo otevrene, dnes ne): z granule
# `sim.entity_registry` - system si je sam NEDRZI. `register`/`mobile` jsou jen
# pruchod do registru (kdo ho nezada, dostane vlastni prazdny), takze existuje
# JEDEN zdroj pravdy; `SimWorld` dostane system z integracniho mista
# (`app/main.gd`). `sim_world.snapshot()` mobily porad nevraci (`mobiles: []`) -
# to je otevrena vec granule `sim.world_loop`, ne teto.
#
# ⚠⚠ STOJNA VYSKA SE MUSI ZAPSAT (2026-10-07, 14. session - vada V4):
#   `can_step` vraci `z` (stojnou vysku povrchu), ale `apply_step` ji do
#   `mob.pos.z` NIKDY nezapsal - postava tedy mela `z` porad z prvniho kroku.
#   Namerene dusledky: (a) na svahu se `from.z` neposunul, takze kazdy dalsi
#   krok nahoru se meril proti stare vysce a cesta do kopce se po par
#   dlazdicich zablokovala, (b) kamera i kresleni pouzivaji `pos.z`
#   (`app/player_controller.gd:160`, `app/world_view.gd:358`), takze postava
#   zustala ve vysce prvniho kroku. `z` se proto bere z `_pending` (kde ho
#   ulozil `request_step`) - `apply_step` ho dostane i tehdy, kdyz se vola
#   pozdeji v ticku bez vysledku `can_step`.
#
# ⚠ KLIENT POTREBUJE ROZJETY KROK (2026-10-07, 14. session - vada V2):
#   `pending_step(serial)` vraci prave bezici krok (`{}` kdyz zadny neni):
#   `{dir, run, start_ms, delay_ms, due_ms, z}`. Klient z nej pocita posun
#   postavy MEZI dlazdicemi (`app/player_controller.step_offset_px`) a start
#   animace v okamziku zamERu - do teto session si klient vse domyslel az po
#   zmene dlazdice (`app/player_controller.gd:_process`).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `_init(walk, clock, events, drain_model, registry)` - peti argument (registr)
#     smlouva neuvadi; bez nej si system zalozi vlastni (testy tim meri obe cesty),
#   * `player_serial` (kdo je hrac) - rozhoduje o asymetricke diagonele
#     v `world.walk.can_step(is_player)`,
#   * drzeni klavesy neopakuje krok: `app/input_map.gd` cte jen
#     `is_action_just_pressed` (vlastni granule `app.input`, agent ji needituje),
#   * mounty (MOUNT_WALK_MS/MOUNT_RUN_MS) tu jsou pripravene, ale `entity.mount`
#     neexistuje.

const Const = preload("res://core/const.gd")
const WalkScript = preload("res://sim/world/walk.gd")
const ClockScript = preload("res://core/clock.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const BALANCE_PATH := "res://data/balance.json"
const ACTION_WALK := 0            # anim akce 0 = walk, 1 = run (mereno v anim.mul)
const ACTION_RUN := 1
const EMULATOR_STEPS_PER_POINT := 16

var player_serial: int = 0

var _walk = null
var _clock = null
var _events = null
var _registry = null              # sim.entity_registry: JEDINE misto pro mobily
var _pending: Dictionary = {}     # serial -> {dir, run, due_ms}
var _carry: Dictionary = {}       # serial -> zbytek kroku pro model "emulator"
var _drain_model: String = "run_only"


func _init(walk = null, clock = null, events = null, drain_model: String = "", registry = null) -> void:
	_walk = walk if walk != null else WalkScript.new()
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	# Kdo registr nezada, dostane vlastni - `register`/`mobile` pak funguji
	# stejne, jen si mobil drzi tenhle system (starsi chovani z 2026-10-06).
	_registry = registry if registry != null else RegistryScript.new()
	# `drain_model` je vstup pro test (aby se daly zmerit OBA modely staminy);
	# kdyz je prazdny, rozhoduje `data/balance.json` (docs/05 §5.1.4).
	_read_balance()
	if drain_model != "":
		_drain_model = drain_model


func _read_balance() -> void:
	if not FileAccess.file_exists(BALANCE_PATH):
		return                        # vychozi "run_only" (docs/05 §5.1.4)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if parsed is Dictionary and parsed.has("stamina_drain_model"):
		_drain_model = str(parsed["stamina_drain_model"])


func register(mobile) -> void:
	_registry.register(mobile)


func mobile(serial: int):
	return _registry.get_mobile(serial)


func pending_count() -> int:
	return _pending.size()


func pending_step(serial: int) -> Dictionary:
	# PRAVE BEZICI krok (docs/04 §4.2): klient z nej kresli postavu mezi
	# dlazdicemi a startuje animaci v okamziku zameru (vada V2). Prazdny
	# slovnik = zadny krok v letu; kopie, aby si klient nemohl prepsat stav.
	if not _pending.has(serial):
		return {}
	return (_pending[serial] as Dictionary).duplicate()


func request_step(m: int, dir: int, run: bool) -> Dictionary:
	var mob = _registry.get_mobile(m)
	if mob == null:
		return _no(0, "no_mobile")
	if _pending.has(m):
		# Jeden krok v letu staci (fronta 4 kroku z docs/05 §5.1.3 je na klientu).
		return _no(0, "busy")
	var use_run: bool = run
	if use_run and mob.stam <= 0:
		use_run = false               # bez staminy se jde (beh se nezkrati potichu)
	var result: Dictionary = _walk.can_step(mob.pos, dir, Const.PERSON_HEIGHT, m == player_serial)
	if not result["ok"]:
		_message("You cannot move there.")
		return _no(0, str(result["reason"]))
	var delay: int = delay_ms_for(use_run)
	var start: int = _now()
	# `z` = stojna vyska povrchu, na ktery se dojde - `apply_step` ji zapise.
	_pending[m] = {"dir": dir, "run": use_run, "due_ms": start + delay,
		"start_ms": start, "delay_ms": delay, "z": int(result["z"])}
	_events_push("mobile_anim", {"serial": m,
		"action": ACTION_RUN if use_run else ACTION_WALK, "frame_ms": Const.TURN_MS})
	return {"ok": true, "delay_ms": delay, "reason": ""}


func apply_step(m: int, dir: int) -> void:
	var mob = _registry.get_mobile(m)
	if mob == null:
		return
	var run: bool = false
	var z: int = int(mob.pos.z)
	if _pending.has(m):
		run = bool(_pending[m]["run"])
		z = int(_pending[m]["z"])       # stojna vyska z `can_step` (vada V4)
		_pending.erase(m)
	mob.pos = Vector3i(mob.pos.x + Const.DIR_DX[dir], mob.pos.y + Const.DIR_DY[dir], z)
	mob.dir = dir
	# Model "emulator" pocita i chuzi (1 bod za 16 kroku), "run_only" jen beh.
	if run or _drain_model == "emulator":
		consume_stamina(m, 1)
	_events_push("mobile_moved", {"serial": m, "x": mob.pos.x, "y": mob.pos.y,
		"z": mob.pos.z, "dir": dir, "run": run})


func consume_stamina(m: int, steps: int) -> void:
	var mob = _registry.get_mobile(m)
	if mob == null or steps <= 0:
		return
	if _drain_model == "emulator":
		# 1 bod za 16 kroku VCNETNE chuze - pocita se prirustkem, takze 15 kroku
		# jeste nic nezaplati a 16. krok stoji bod (docs/05 §5.1.4). Zbytek se
		# musi prenaset, jinak by se "1 za 16" zaokrouhlilo na "1 za kazdy krok".
		var celkem: int = int(_carry.get(m, 0)) + steps
		var body: int = celkem / EMULATOR_STEPS_PER_POINT
		_carry[m] = celkem % EMULATOR_STEPS_PER_POINT
		mob.stam = maxi(0, mob.stam - body)
	else:
		mob.stam = maxi(0, mob.stam - steps)    # "run_only": bod za kazdy krok behu


func delay_ms_for(run: bool) -> int:
	return Const.RUN_MS if run else Const.WALK_MS


func tick(_ms: int) -> void:
	# SimWorld tickuje systemy po `advance(ms)`, takze `_now()` je uz posunuty.
	if _pending.is_empty():
		return
	var ready: Array = []
	for m in _pending.keys():
		if int(_pending[m]["due_ms"]) <= _now():
			ready.append(m)
	ready.sort()
	for m in ready:
		apply_step(int(m), int(_pending[m]["dir"]))


func _now() -> int:
	return int(_clock.now_ms())


func _no(delay: int, reason: String) -> Dictionary:
	return {"ok": false, "delay_ms": delay, "reason": reason}


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)


func _message(text: String) -> void:
	_events_push("message", {"text": text, "kind": "system"})
