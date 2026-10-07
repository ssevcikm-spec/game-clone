extends RefCounted
# app.input - mapovani vstupu na Command (docs/04 §4.2, docs/05 §5.3).
# Kriterium z promptu: simulovany klik na dlazdici vytvori move/use prikaz.
# Testy kontroluji i to, ze vzniky prikaz projde validaci sim.commands -
# samotny tvar by jinak mohl "vypadat spravne" a sim by ho zahodil.

const Lib = preload("res://tests/lib.gd")

# Cesta k modulu je VSTUP (jako u ostatnich case souboru): mutacni harness
# (`tools/gates/mutace-tests.py`) pousti test nad mutantem a bez prepinace by
# meril porad original - tedy nic.
const INPUT_SCRIPT := "res://app/input_map.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var script = Lib.script_at(_arg("input-script", INPUT_SCRIPT))
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

	# 7) CHUZE DRZENIM (rozhodnuti uzivatele 2026-10-07: "mys i klavesa").
	#    Drzena klavesa krokuje po WALK_MS; pusteni prodlevu vynuluje, takze
	#    dalsi zmacknuti krokuje HNED. Cas je VSTUP (`now_ms`), takze se test
	#    nerozjede podle zatizeni stroje - a meri se PRESNY interval.
	#    Vstup se do `Input` posila programove (`Input.action_press`) - v headless
	#    to funguje (zmereno sondou `_analyza/vlna4-input-sonda.gd`).
	var walk_ms: int = int(consts["WALK_MS"])
	var drzeny = script.new({"east": "test_drzeni_east", "war": "test_drzeni_war",
		"walk_to": "test_drzeni_mys"})
	for akce in ["test_drzeni_east", "test_drzeni_war", "test_drzeni_mys"]:
		if not InputMap.has_action(akce):
			InputMap.add_action(akce)
	drzeny.view_size = Vector2(1280, 720)
	var stred := Vector2(640, 360)
	Input.action_press("test_drzeni_east")
	var h0: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred, 0)
	var h1: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred, walk_ms / 2)
	var h2: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred, walk_ms - 1)
	var h3: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred, walk_ms)
	Input.action_release("test_drzeni_east")
	var h4: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred, walk_ms + 50)
	Input.action_press("test_drzeni_east")
	var h5: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred, walk_ms + 50)
	Input.action_release("test_drzeni_east")
	t._check(h0.size() == 1 and h0[0].get("t") == "move" and h0[0].get("dir") == 0,
		"app.input: DRZENI - stisk krokuje hned (namEReno %s)" % str(h0))
	t._check(h1.is_empty() and h2.is_empty() and h3.size() == 1,
		"app.input: DRZENI - krok se opakuje az po %d ms (v %d a %d nic, v %d %d)"
		% [walk_ms, walk_ms / 2, walk_ms - 1, walk_ms, h3.size()])
	t._check(h4.is_empty(), "app.input: DRZENI - pustena klavesa nekrokuje (namEReno %d)" % h4.size())
	t._check(h5.size() == 1,
		"app.input: DRZENI - po pusteni krokuje nove zmacknuti HNED (namEReno %d)" % h5.size())

	# 7b) jednorazove akce se drzenim NEOPAKUJI (war/peace/use)
	var w1: Dictionary = drzeny.hold_command("war", 0)
	var w2: Dictionary = drzeny.hold_command("war", walk_ms * 2)
	t._check(w1.is_empty() and w2.is_empty(),
		"app.input: DRZENI - 'war' se hold_command neopakuje (%s, %s)" % [str(w1), str(w2)])

	# 8) DRZENE PRAVE TLACITKO = chuze kursoru; `run` podle vzdalenosti od stredu
	#    obrazovky (ClassicUO `GameSceneInputHandler.cs:66`: mouseRange >= 190).
	#    Presna hranice se meri na obou stranach - jinak by proslo i "<=" vs "<".
	t._check(not drzeny.mouse_run(stred + Vector2(189, 0))
		and drzeny.mouse_run(stred + Vector2(190, 0)),
		"app.input: prave tlacitko - 189 px = chuze, 190 px = beh (ClassicUO 190)")
	var prazdna = script.new({"walk_to": "test_drzeni_mys"})
	var vzdy = script.new({"walk_to": "test_drzeni_mys"})
	vzdy.always_run = true
	t._check(prazdna.mouse_run(stred) == false and vzdy.mouse_run(stred) == true,
		"app.input: prave tlacitko - bez velikosti okna rozhoduje `always_run` (%s / %s)"
		% [str(prazdna.mouse_run(stred)), str(vzdy.mouse_run(stred))])
	Input.action_press("test_drzeni_mys")
	var daleko: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred + Vector2(400, 0), 0)
	var blizko: Array = drzeny.poll(Vector2i(10, 10), Vector2.ZERO, 0, stred + Vector2(50, 0), walk_ms)
	Input.action_release("test_drzeni_mys")
	t._check(daleko.size() == 1 and daleko[0].get("t") == "move" and daleko[0].get("run") == true,
		"app.input: DRZENE PRAVE TLACITKO - daleko od hrace = BEH (namEReno %s)" % str(daleko))
	t._check(blizko.size() == 1 and blizko[0].get("run") == false,
		"app.input: DRZENE PRAVE TLACITKO - blizko stredu = CHUZE (namEReno %s)" % str(blizko))
