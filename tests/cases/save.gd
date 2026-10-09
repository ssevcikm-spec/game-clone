extends RefCounted
# sim.save - ukladani sveta: verze, migrace a stavove zdroje (granule `sim.save`, MK).
#
# Kriterium z promptu granule: save/load sveta vcetne BUDOUCNOSTI (fronta
# planovace), migrace stare obalky a odmítnuti novejsi verze.
#
# ⚠ Co tenhle case NEMERI: ze by se ukladaly i entity (mobily, predmety) -
# ty `state()`/`restore()` zatim nemaji a je to pojmenovane v `sim/save.gd`.

const Lib = preload("res://tests/lib.gd")
const SAVE_PATH := "user://test_save_grain.sav"


class FakeSource extends RefCounted:
	var hodnota: int = 0

	func state() -> Dictionary:
		return {"hodnota": hodnota}

	func restore(d: Dictionary) -> void:
		hodnota = int(d.get("hodnota", 0))


class SourceBezRestore extends RefCounted:
	func state() -> Dictionary:
		return {"x": 1}


func run(t) -> void:
	var save_script = Lib.script_at("res://sim/save.gd")
	if save_script == null:
		t._pending("sim.save NENI HOTOVA: sim/save.gd chybi")
		return
	var world_script = Lib.script_at("res://sim/sim_world.gd")
	if world_script == null:
		t._pending("sim.save: chybi sim/sim_world.gd (svet, ktery se uklada)")
		return

	var saver = save_script.new()

	# -- verze a migrace
	t._check(saver.version() == 2, "sim.save: verze schematu je 2 (obalka + stavove zdroje), namEReno %d" % saver.version())
	var stara: Dictionary = {"version": 1, "seed": 5, "mobily": [], "items": []}
	var migrovana: Dictionary = saver.migrate(stara, 1)
	t._check(not migrovana.is_empty(), "sim.save: migrace z verze 1 nesmi vratit prazdno")
	t._check(int(migrovana.get("version", 0)) == 2, "sim.save: migrace 1 -> 2 prepise verzi")
	t._check(migrovana.get("sources") is Dictionary, "sim.save: migrace 1 -> 2 doplni prazdne stavove zdroje")
	t._check(int(migrovana.get("seed", 0)) == 5, "sim.save: migrace neztrati ostatni pole")
	var budouci: Dictionary = saver.migrate({"version": 99}, 99)
	t._check(budouci.is_empty(), "sim.save: novejsi verze se odmitne (ne tichy nesmysl)")
	var stejna: Dictionary = saver.migrate({"version": 2, "sources": {}}, 2)
	t._check(not stejna.is_empty(), "sim.save: soucasna verze projde bez zmeny")

	# -- stavove zdroje
	t._check(saver.collect({}).is_empty(), "sim.save: bez zdroju je stav prazdny")
	var src = FakeSource.new()
	src.hodnota = 7
	var stav: Dictionary = saver.collect({"a": src})
	t._check(stav.get("a", {}).get("hodnota", -1) == 7,
		"sim.save: collect() vezme stav zdroje (namEReno %s)" % str(stav))

	var cil = FakeSource.new()
	var pouzito: int = saver.apply({"a": cil}, {"a": {"hodnota": 42}})
	t._check(pouzito == 1 and cil.hodnota == 42,
		"sim.save: apply() vrati stav do zdroje (pocet %d, hodnota %d)" % [pouzito, cil.hodnota])
	var bez = SourceBezRestore.new()
	t._check(saver.apply({"b": bez}, {"b": {"x": 1}}) == 0,
		"sim.save: zdroj bez restore() se preskoci a NEPOCITA se jako uspech")
	t._check(saver.apply({"a": cil}, {}) == 0, "sim.save: chybejici stav pro zdroj se nevykazuje jako uspech")

	# -- svet: budoucnost (fronta planovace) prezije save/load
	var svet = world_script.new(1, {})
	var jmena: Array = svet.state_source_names()
	t._check(jmena.has("scheduler"), "sim.save: svet ma zaregistrovany stavovy zdroj `scheduler` (namEReno %s)" % str(jmena))
	svet.scheduler().schedule("test_udalost", 5000)
	t._check(svet.scheduler().pending() == 1, "sim.save: udalost je naplanovana")
	t._check(svet.save(SAVE_PATH) == true, "sim.save: save() vraci true")

	var druhy = world_script.new(1, {})
	t._check(druhy.load(SAVE_PATH) == true, "sim.save: load() vraci true")
	t._check(druhy.scheduler().pending() == 1,
		"sim.save: fronta planovace prezije save/load (namEReno %d)" % druhy.scheduler().pending())
	t._check(druhy.state_hash() == svet.state_hash(), "sim.save: hash pred ulozenim == hash po nacteni")
	var vyrizeno: Array = druhy.scheduler().advance_to(5000)
	t._check(vyrizeno.size() == 1 and vyrizeno[0]["kind"] == "test_udalost",
		"sim.save: nactena udalost se v pravem case vyrize (namEReno %s)" % str(vyrizeno))

	# -- budouci verze se odmitne i pres load() sveta
	saver.write(SAVE_PATH, {"version": 99, "data_version": svet.data_version})
	var treti = world_script.new(1, {})
	t._check(treti.load(SAVE_PATH) == false, "sim.save: svet odmitne save z budouci verze")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
