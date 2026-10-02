extends RefCounted
# sim.world_loop - jadro simulace (docs/04 §4.2 a §4.7).
# Kriterium: sim jde spustit bez sceny, tick 50 ms, save/load round-trip
# (hash pred == hash po) a dva behy se stejnym seedem daji stejny hash.

const Lib = preload("res://tests/lib.gd")
const SAVE_PATH := "user://test_sim_world.sav"


class FakeSystem extends RefCounted:
	var jmeno: String
	var log: Array

	func _init(name: String, shared_log: Array) -> void:
		jmeno = name
		log = shared_log

	func tick(ms: int) -> void:
		log.append([jmeno, ms])


class ZeroArgSystem extends RefCounted:
	var jmeno: String
	var log: Array

	func _init(name: String, shared_log: Array) -> void:
		jmeno = name
		log = shared_log

	func tick() -> void:
		log.append([jmeno, 0])


func run(t) -> void:
	var script = Lib.script_at("res://sim/sim_world.gd")
	if script == null:
		t._pending("sim.world_loop NENI HOTOVA: sim/sim_world.gd chybi")
		return

	# 1) bezi bez sceny a tick plyne
	var sim = script.new(1234, {})
	t._check(sim.world_time() == 0, "sim.world_loop: novy sim ma cas 0")
	sim.tick(50)
	t._check(sim.world_time() == 50, "sim.world_loop: tick(50) posune cas na 50 (namEReno %d)" % sim.world_time())
	for i in 79:
		sim.tick(50)
	t._check(sim.world_time() == 4000, "sim.world_loop: 80 ticku po 50 ms = 4000 ms (namEReno %d)" % sim.world_time())

	# 2) determinismus: stejny seed + stejne prikazy = stejny hash
	var commands: Array = [
		{"t": "move", "dir": 0, "run": false, "seq": 1},
		{"t": "move", "dir": 1, "run": true, "seq": 2},
		{"t": "cast", "spell": 4},
	]
	var a = script.new(99, {})
	var b = script.new(99, {})
	for c in commands:
		a.enqueue(c)
		b.enqueue(c)
	for i in 100:
		a.tick(50)
		b.tick(50)
	t._check(a.state_hash() == b.state_hash(), "sim.world_loop: dva behy se stejnym seedem maji stejny hash")
	t._check(a.state_hash().length() == 64, "sim.world_loop: state_hash() je SHA-256 (64 znaku)")
	var other = script.new(100, {})
	for i in 100:
		other.tick(50)
	t._check(a.state_hash() != other.state_hash(), "sim.world_loop: jiny seed = jiny hash")

	# 3) neplatny prikaz stav nemeni a je videt v udalostech
	var with_bad = script.new(7, {})
	var without_bad = script.new(7, {})
	with_bad.enqueue({"t": "teleport_to_moon"})
	with_bad.tick(50)
	without_bad.tick(50)
	t._check(with_bad.state_hash() == without_bad.state_hash(),
		"sim.world_loop: neplatny prikaz nemENÍ stav (hash jako bez nej)")
	var snap: Dictionary = with_bad.snapshot()
	t._check(snap["events"].size() == 1, "sim.world_loop: neplatny prikaz je videt v udalostech (namEReno %d)" % snap["events"].size())
	t._check(with_bad.snapshot()["events"].is_empty(), "sim.world_loop: snapshot udalosti vyda a frontu vyprázdní")

	# 4) pevne poradi systemu (ne poradi, v jakem byly vlozeny)
	var log: Array = []
	var ordered = script.new(1, {})
	ordered.systems["regen"] = FakeSystem.new("regen", log)
	ordered.systems["movement"] = FakeSystem.new("movement", log)
	ordered.systems["poison"] = ZeroArgSystem.new("poison", log)
	ordered.tick(50)
	t._check(log == [["movement", 50], ["poison", 0], ["regen", 50]],
		"sim.world_loop: systemy jdou v pevnem poradi a dostanou spravny tick (namEReno %s)" % str(log))
	t._check(str(ordered.snapshot()["systems"]) == str(["movement", "poison", "regen"]),
		"sim.world_loop: snapshot vraci systemy serazene")

	# 5) save/load round-trip (kriterium brany G7)
	var saver = script.new(4242, {"items": 1})
	saver.player_serial = 0x40000001
	saver.next_serial()
	saver.next_serial()
	saver.enqueue({"t": "move", "dir": 3, "run": false, "seq": 1})
	for i in 20:
		saver.tick(50)
	var hash_before: String = saver.state_hash()
	t._check(saver.save(SAVE_PATH) == true, "sim.world_loop: save() vraci true")
	var loader = script.new(1, {"items": 1})
	t._check(loader.load(SAVE_PATH) == true, "sim.world_loop: load() vraci true")
	t._check(loader.state_hash() == hash_before,
		"sim.world_loop: round-trip hash pred == hash po (%s vs %s)" % [hash_before, loader.state_hash()])
	t._check(loader.world_time() == saver.world_time(), "sim.world_loop: cas se obnovil")
	t._check(loader.player_serial == 0x40000001, "sim.world_loop: player_serial se obnovil")
	t._check(loader.next_serial() == saver.next_serial_value(),
		"sim.world_loop: pocitadlo serialu pokracuje po nacteni (namEReno %d vs %d)" % [loader.next_serial_value() - 1, saver.next_serial_value()])

	# 6) load odmitne jina data a neexistujici soubor (docs/04 §4.7)
	var other_data = script.new(1, {"items": 2})
	t._check(other_data.load(SAVE_PATH) == false, "sim.world_loop: load odmitne save s jinymi daty")
	t._check(script.new(1, {"items": 1}).load("user://neexistuje.sav") == false,
		"sim.world_loop: load neexistujiciho souboru vraci false")
