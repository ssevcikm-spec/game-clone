extends SceneTree
# Driver pro brany G7 (save round-trip), G8 (determinismus), G9 (replaye)
# a F1 (svet ma vlastni cas). Spousti ho Python, nikdy hrac:
#   godot --headless --path . --script res://tools/gates/sim_probe.gd -- --mode=save
#
# Vypisuje strojove citelne radky `PROBE <klic>=<hodnota>`, ktere brana cte.
# Pouziva jen API ze smlouvy docs/04 §4.2 (SimWorld: new(seed, data), enqueue(c),
# tick(ms), state_hash(), save(path), load(path), advance_offline(ms)) - nic
# vlastniho si nevymysli.
#
# ⚠ CESTY JSOU VSTUP, NE KONSTANTA (smlouva o vstupu, docs/09 §9.6 bod 3):
# `--world-script=`, `--offline-script=`, `--map-script=` se predavaji z brany.
# Diky tomu umi F1 merit i MUTANTA (kopii v `.cache/gates/mutace/`), a kdyz
# cesta neexistuje, probe to REKNE (ne tichy beh nad vychozim souborem).
#
# Stav: G7/G8/G9 cekaji na `sim.world_loop` (M0) - dokud `sim/sim_world.gd`
# neexistuje, brany tenhle skript vubec nespousti a hlasi NEMERENO.

const PROBE_SCRIPT := "res://tools/gates/sim_probe.gd"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const DEFAULT_WORLD := "res://sim/sim_world.gd"
const DEFAULT_OFFLINE := "res://sim/offline.gd"
const DEFAULT_MAP := "res://sim/world/map.gd"
const DEFAULT_MAP_PREFIX := "res://tests/fixtures/world/map0"
# 1 herni hodina = `Const.DAY_LENGTH_MS / 24` = 300 000 ms sveta = 300 s casu,
# ktery predava volajici. Dobeh se tim da merit v hernich hodinach.
const HOUR_MS: int = 300000
const HOUR_UNIX: int = 300
const AGENTNI_SYSTEMY: Array[String] = ["ai", "vendor", "loot"]


class Counter extends RefCounted:
	# "Agentni" system, ktery si POCITA ticky. Dobeh sveta (`advance_offline`)
	# ho nesmi zavolat ani jednou - jinak by svet mimo obrazovku simuloval
	# vsechno (kontrola 3 brany F1).
	var ticku: int = 0

	func tick(_ms: int = 0) -> void:
		ticku += 1


var _mode: String = "save"
var _replay: String = ""
var _ticks: int = 20000
var _seed: int = 1234
var _world_path: String = DEFAULT_WORLD
var _offline_path: String = DEFAULT_OFFLINE
var _map_path: String = DEFAULT_MAP
var _map_prefix: String = DEFAULT_MAP_PREFIX
var _hours: int = 720
var _start: int = 1700000000
var _mobiles: int = 200


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
		elif arg.begins_with("--replay="):
			_replay = arg.substr(9)
		elif arg.begins_with("--ticks="):
			_ticks = int(arg.substr(8))
		elif arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
		elif arg.begins_with("--world-script="):
			_world_path = arg.substr(15)
		elif arg.begins_with("--offline-script="):
			_offline_path = arg.substr(17)
		elif arg.begins_with("--map-script="):
			_map_path = arg.substr(13)
		elif arg.begins_with("--map-prefix="):
			_map_prefix = arg.substr(13)
		elif arg.begins_with("--hours="):
			_hours = int(arg.substr(8))
		elif arg.begins_with("--start="):
			_start = int(arg.substr(8))
		elif arg.begins_with("--mobiles="):
			_mobiles = int(arg.substr(10))

	var script: GDScript = _nacti(_world_path)
	if script == null:
		print("PROBE chyba=world_script se neda nacist: ", _world_path)
		quit(1)
		return

	match _mode:
		"save":
			_probe_save(script)
		"determinism":
			_probe_determinism(script)
		"replay":
			_probe_replay(script)
		"offline":
			_probe_offline(script)
		_:
			print("PROBE chyba=neznamy rezim ", _mode)
			quit(1)


func _nacti(cesta: String):
	# Vraci `null` i pro skript s parse errorem - brana to musí vidět jako
	# "neměřeno", ne jako běh nad něčím jiným.
	if not FileAccess.file_exists(cesta):
		return null
	var s = load(cesta)
	if s == null or not (s is GDScript) or not s.can_instantiate():
		return null
	return s


func _new_sim(script: GDScript):
	# Data se predavaji jako slovnik; prazdny je platny vstup pro mechaniky,
	# ktere data nepotrebuji (docs/04 §4.8 spousti sim bez assetu).
	return script.new(_seed, {})


func _scripted_commands(count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append({"t": "move", "dir": i % 8, "run": i % 3 == 0, "seq": i})
	return out


func _probe_save(script: GDScript) -> void:
	var sim = _new_sim(script)
	# ⚠ Od 2026-10-09 se uklada i STAV ENTIT (`entities` je stavovy zdroj).
	# Bez osidleni by round-trip meril jen prazdny svet a "mobily prezily save"
	# by nebylo merene vubec (brána G7 to od teto zmeny vyzaduje).
	_osidl(sim, 3)
	for cmd in _scripted_commands(50):
		sim.enqueue(cmd)
	for i in 200:
		sim.tick(50)
	var before: String = sim.state_hash()
	var path := "user://probe.sav"
	var saved: bool = sim.save(path)
	var sim2 = _new_sim(script)
	var loaded: bool = sim2.load(path)
	print("PROBE hash_before=", before)
	print("PROBE hash_after=", sim2.state_hash())
	print("PROBE save=", saved, " load=", loaded)
	print("PROBE mobiles_before=", sim.registry.size())
	print("PROBE mobiles_after=", sim2.registry.size())
	var m = sim2.registry.get_mobile(400001)
	if m != null:
		print("PROBE pos_x=", m.pos.x, " pos_y=", m.pos.y, " pos_z=", m.pos.z)
		print("PROBE telo=", m.body)
	quit(0)


func _osidl(sim, count: int) -> void:
	var mobile = _nacti(MOBILE_SCRIPT)
	if mobile == null:
		return
	for i in count:
		var m = mobile.new(400001 + i, 400 + i, Vector3i(100 + i, 200 + i, 3))
		sim.registry.register(m)


func _probe_determinism(script: GDScript) -> void:
	var sim = _new_sim(script)
	for cmd in _scripted_commands(200):
		sim.enqueue(cmd)
	for i in _ticks:
		sim.tick(50)
	print("PROBE ticks=", _ticks)
	print("PROBE hash=", sim.state_hash())
	quit(0)


func _probe_replay(script: GDScript) -> void:
	if not FileAccess.file_exists(_replay):
		print("PROBE chyba=replay ", _replay, " neexistuje")
		quit(1)
		return
	var text := FileAccess.get_file_as_string(_replay)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or not (parsed.get("commands") is Array):
		print("PROBE chyba=replay nema tvar {commands: [...], ticks: int, hash: String}")
		quit(1)
		return
	var sim = _new_sim(script)
	var index: int = 0
	var commands: Array = parsed["commands"]
	var ticks: int = int(parsed.get("ticks", 0))
	# prikazy se rozlozi po ticich, aby byl replay reprodukovatelny
	for t in ticks:
		while index < commands.size() and int(commands[index].get("at", 0)) <= t:
			sim.enqueue(commands[index])
			index += 1
		sim.tick(50)
	print("PROBE ticks=", ticks)
	print("PROBE prikazu=", commands.size())
	print("PROBE hash=", sim.state_hash())
	print("PROBE expected=", str(parsed.get("hash", "")))
	quit(0)


# -- F1: svet ma vlastni cas --------------------------------------------------

func _probe_offline(world_script: GDScript) -> void:
	# Pet scenaru = pet kontrol brany F1. Vsechno se deje BEZ prikazu hrace
	# (fronta je prazdna) a na FIXTURE mape - v CI zadna `assets/uo/` neni.
	var offline_script = _nacti(_offline_path)
	if offline_script == null:
		print("PROBE chyba=offline_script se neda nacist: ", _offline_path)
		quit(1)
		return
	var map_script = _nacti(_map_path)
	if map_script == null:
		print("PROBE chyba=map_script se neda nacist: ", _map_path)
		quit(1)
		return
	var map = map_script.new(_map_prefix)
	if map.width() <= 0 or map.height() <= 0:
		print("PROBE chyba=mapa se nenacetla (prefix ", _map_prefix, ")")
		quit(1)
		return
	var end: int = _start + _hours * HOUR_UNIX

	# A) jeden dobeh: svet se pohnul? (kontrola 1)
	var a: Dictionary = _svet_s_agenty(world_script, map)
	var hash_start: String = a["world"].state_hash()
	var off = offline_script.new(a["world"], _start, map)
	var rep: Dictionary = off.advance_to(end)
	print("PROBE hash_start=", hash_start)
	print("PROBE hash_end=", a["world"].state_hash())
	print("PROBE events=", int(rep.get("events", 0)))
	print("PROBE steps=", int(rep.get("steps", 0)))
	print("PROBE agent_ticks=", _agent_ticks(a))
	print("PROBE agent_systemu=", (a["counters"] as Array).size())
	print("PROBE advanced_ms=", int(rep.get("advanced_ms", 0)))
	print("PROBE expected_ms=", _hours * HOUR_MS)
	print("PROBE mobiles=", a["world"].registry.size())
	print("PROBE map_blocks=", int(rep.get("map_blocks", 0)))
	print("PROBE events_total=", int(off.elapsed_report().get("events_total", 0)))
	print("PROBE pending=", int(rep.get("pending", -1)))

	# B) tyz vstup a tyz seed znovu (kontrola 2)
	var b: Dictionary = _svet_s_agenty(world_script, map)
	var offb = offline_script.new(b["world"], _start, map)
	var repb: Dictionary = offb.advance_to(end)
	print("PROBE hash_again=", b["world"].state_hash())
	print("PROBE events_again=", int(repb.get("events", 0)))

	# C) dobeh po davkach (kontrola 5)
	var c: Dictionary = _svet_s_agenty(world_script, map)
	var offc = offline_script.new(c["world"], _start, map)
	for k in range(1, _hours + 1):
		offc.advance_to(_start + k * HOUR_UNIX)
	print("PROBE hash_batch=", c["world"].state_hash())
	print("PROBE events_batch=", int(offc.elapsed_report().get("events_total", 0)))
	print("PROBE agent_ticks_batch=", _agent_ticks(c))

	# D) druhy dobeh na tyz cas (kontrola 4)
	var d: Dictionary = _svet_s_agenty(world_script, map)
	var offd = offline_script.new(d["world"], _start, map)
	offd.advance_to(end)
	print("PROBE hash_after_first=", d["world"].state_hash())
	var rep_d: Dictionary = offd.advance_to(end)
	print("PROBE hash_repeat=", d["world"].state_hash())
	print("PROBE advanced_ms_repeat=", int(rep_d.get("advanced_ms", -1)))

	# E) strop: rok absence
	var e: Dictionary = _svet_s_agenty(world_script, map)
	var offe = offline_script.new(e["world"], _start, map)
	var rep_cap: Dictionary = offe.advance_to(_start + 365 * 24 * 3600)
	print("PROBE capped=", 1 if bool(rep_cap.get("capped", false)) else 0)
	print("PROBE advanced_capped_ms=", int(rep_cap.get("advanced_ms", 0)))
	print("PROBE cap_ms=", int(offline_script.MAX_CATCHUP_MS))
	quit(0)


func _svet_s_agenty(world_script: GDScript, map) -> Dictionary:
	# Svět s `--mobiles` entitami a se tremi "agentnimi" systemy, ktere si
	# pocitaji ticky. Jsou tam schvalne: bez entit by kontrola 3 ("netika cely
	# svet") nemela co merit (nula by byla prazdna, ne namerena).
	var world = world_script.new(_seed, {})
	var counters: Array = []
	for name in AGENTNI_SYSTEMY:
		var c = Counter.new()
		counters.append(c)
		world.systems[name] = c
	var mobile = _nacti(MOBILE_SCRIPT)
	if mobile != null:
		for i in _mobiles:
			world.registry.register(
				mobile.new(400001 + i, 400, Vector3i(i % 100, i / 100, 0)))
	return {"world": world, "counters": counters}


func _agent_ticks(sestava: Dictionary) -> int:
	var out: int = 0
	for c in sestava["counters"]:
		out += int(c.ticku)
	return out
