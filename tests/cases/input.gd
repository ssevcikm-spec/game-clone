extends RefCounted
# app.input - mapovani vstupu na Command (docs/04 §4.2, docs/05 §5.3).
# Kriterium z promptu: simulovany klik na dlazdici vytvori move/use prikaz.
# Testy kontroluji i to, ze vzniky prikaz projde validaci sim.commands -
# samotny tvar by jinak mohl "vypadat spravne" a sim by ho zahodil.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://app/input_map.gd")
	if script == null:
		t._pending("app.input NENI HOTOVA: app/input_map.gd chybi")
		return
	var commands = Lib.script_at("res://sim/commands.gd")
	if commands == null:
		t._pending("app.input: chybi sim/commands.gd (validace prikazu)")
		return
	var validator = commands.new()
	var mapper = script.new()

	# 1) smer: dir 0 = vychod (docs/04 §4.8), vsech 8 smeru proti tabulce v core/const.gd
	var consts: Dictionary = Lib.consts_at("res://core/const.gd")
	t._check(mapper.direction_between(Vector2i(5, 5), Vector2i(6, 5)) == 0,
		"app.input: vychod je dir 0 (docs/04 §4.8)")
	t._check(mapper.direction_between(Vector2i(5, 5), Vector2i(5, 5)) == -1,
		"app.input: klik na vlastni dlazdici nema smer")
	var dirs_ok: bool = true
	for dir in 8:
		var delta := Vector2i(consts["DIR_DX"][dir], consts["DIR_DY"][dir])
		if mapper.direction_between(Vector2i(100, 100), Vector2i(100, 100) + delta) != dir:
			dirs_ok = false
	t._check(dirs_ok, "app.input: vsech 8 smeru odpovida tabulce DIR_DX/DIR_DY")

	# 2) klik-to-move: klik na dlazdici vedle hrace = jeden krok tim smerem
	var command: Dictionary = mapper.step_command(Vector2i(10, 10), Vector2i(11, 11))
	t._check(command.get("t") == "move", "app.input: klik vytvori prikaz move")
	t._check(command.get("dir") == 7, "app.input: klik na jihovychod je dir 7 (namEReno %s)" % str(command.get("dir")))
	t._check(validator.validate(command).get("ok") == true,
		"app.input: vzniky prikaz projde validaci sim.commands (%s)" % str(validator.validate(command)))
	t._check(mapper.step_command(Vector2i(10, 10), Vector2i(10, 10)).is_empty(),
		"app.input: klik na vlastni dlazdici nedela zadny prikaz")

	# 3) seq roste, takze si sim muze prikazy rozlišit
	var first: Dictionary = mapper.step_command(Vector2i(0, 0), Vector2i(1, 0))
	var second: Dictionary = mapper.step_command(Vector2i(0, 0), Vector2i(1, 0))
	t._check(second.get("seq") > first.get("seq"),
		"app.input: seq u dalsiho prikazu roste (%s -> %s)" % [str(first.get("seq")), str(second.get("seq"))])

	# 4) dvojklik na predmet = use (a projde validaci), jednoduchý klik ne
	var use_command: Dictionary = mapper.object_command(0x40000005, true)
	t._check(use_command.get("t") == "use" and use_command.get("serial") == 0x40000005,
		"app.input: dvojklik na predmet vytvori use (namEReno %s)" % str(use_command))
	t._check(validator.validate(use_command).get("ok") == true, "app.input: use projde validaci")
	t._check(mapper.object_command(0x40000005, false).is_empty(),
		"app.input: jednoduchy klik na predmet zadny prikaz nedela")

	# 5) klavesy: pohyb, war/peace, zruseni kurzoru; bez vazeb se nic nevymysli
	t._check(validator.validate(mapper.key_command("east")).get("ok") == true, "app.input: klavesa east = platny move")
	var war: Dictionary = mapper.key_command("war")
	t._check(war.get("t") == "war" and war.get("on") == true, "app.input: klavesa war zapne boj")
	var peace: Dictionary = mapper.key_command("peace")
	t._check(peace.get("t") == "war" and peace.get("on") == false, "app.input: klavesa peace vypne boj")
	t._check(validator.validate(mapper.key_command("cancel_target")).get("ok") == true,
		"app.input: zruseni kurzoru je platny target_reply")
	t._check(mapper.key_command("use", 0).is_empty(), "app.input: use bez serialu zadny prikaz nedela")
	t._check(mapper.key_command("nesmysl").is_empty(), "app.input: nezname akci neudela nic")

	# 6) klik na obrazovce se prevede na dlazdici pres izometrii
	var iso = Lib.new_at("res://core/iso.gd")
	var screen: Vector2 = iso.to_screen(11, 10, 0)
	var from_click: Dictionary = mapper.click_at(Vector2i(10, 10), screen, Vector2.ZERO, 0)
	t._check(from_click.get("t") == "move" and from_click.get("dir") == 0,
		"app.input: klik na obrazovku vpravo od hrace = krok na vychod (namEReno %s)" % str(from_click))
