extends SceneTree
# Driver pro brany G7 (save round-trip), G8 (determinismus) a G9 (replaye).
# Spousti ho Python, nikdy hrac:
#   godot --headless --path . --script res://tools/gates/sim_probe.gd -- --mode=save
#
# Vypisuje strojove citelne radky `PROBE <klic>=<hodnota>`, ktere brana cte.
# Pouziva jen API ze smlouvy docs/04 §4.2 (SimWorld: new(seed, data), enqueue(c),
# tick(ms), state_hash(), save(path), load(path)) - nic vlastniho si nevymysli.
#
# Stav: CUKA NA sim.world_loop (M0). Dokud sim/sim_world.gd neexistuje, brany
# tento skript vubec nespousti a hlasi NEMERENO.

const PROBE_SCRIPT := "res://tools/gates/sim_probe.gd"

var _mode: String = "save"
var _replay: String = ""
var _ticks: int = 20000
var _seed: int = 1234


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

	var script: GDScript = load("res://sim/sim_world.gd")
	if script == null:
		print("PROBE chyba=sim_world.gd se neda nacist")
		quit(1)
		return

	match _mode:
		"save":
			_probe_save(script)
		"determinism":
			_probe_determinism(script)
		"replay":
			_probe_replay(script)
		_:
			print("PROBE chyba=neznamy rezim ", _mode)
			quit(1)


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
	quit(0)


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
