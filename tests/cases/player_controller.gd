extends RefCounted
# app/player_controller - vazby klaves a stav hrace (ZADANI-DALSI-VYVOJ §3 ukol 5).
#
# Tenhle soubor NEMA granuli (vada zadani), ale to neznamena, ze se nema merit:
# bez vazeb klaves se hrac nehne a `bindings` je prazdny slovnik - presne to
# byla namERena pricina, proc hra na klavesy nereagovala (2026-10-06).
#
# Test meri TRI veci, ktere musi ladit dohromady:
#   1. `app/player_controller.default_bindings()` (logicky smer -> akce InputMap),
#   2. `register_actions()` (akce v InputMap + klavesy na nich, idempotentne),
#   3. `app/input_map.key_command()` (logicky smer -> `Command{t:"move", dir}`),
#      kde cislo smeru musi sedet na `core/const.gd`.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://app/player_controller.gd")
	if script == null:
		t._pending("app/player_controller NENI HOTOV: app/player_controller.gd chybi")
		return
	var mapper_script = Lib.script_at("res://app/input_map.gd")
	if mapper_script == null:
		t._pending("app.input NENI HOTOVA: app/input_map.gd chybi")
		return
	var consts: Dictionary = Lib.consts_at("res://core/const.gd")
	var bindings: Dictionary = script.default_bindings()

	t._check(bindings.size() == 8,
		"player_controller: vazeb je 8 smeru (namEReno %d)" % bindings.size())
	for smer in ["east", "ne", "north", "nw", "west", "sw", "south", "se"]:
		t._check(bindings.has(smer), "player_controller: vazba pro smer '%s' existuje" % smer)

	# 2) akce se zakladaji ZA BEHU (project.godot vlastni jina granule)
	var added: int = script.register_actions()
	t._check(added >= 8, "player_controller: register_actions pridal vazby (namEReno %d)" % added)
	t._check(script.register_actions() == 0,
		"player_controller: druhe volani uz nic nepridava (idempotentni)")
	var bez_klavesy: Array = []
	for smer in bindings.keys():
		var akce: String = str(bindings[smer])
		if not InputMap.has_action(akce):
			bez_klavesy.append(akce)
			continue
		if InputMap.action_get_events(akce).is_empty():
			bez_klavesy.append(akce)
	t._check(bez_klavesy.is_empty(),
		"player_controller: kazda akce ma klavesu (bez klavesy: %s)" % str(bez_klavesy))

	# 3) smer z vazby musi dat stejne cislo jako `core/const.gd` a `input_map`
	var mapper = mapper_script.new(bindings)
	var dir_dx: Array = consts.get("DIR_DX", [])
	t._check(dir_dx.size() == 8, "player_controller: DIR_DX ma 8 směru (namEReno %d)" % dir_dx.size())
	for smer in bindings.keys():
		var command: Dictionary = mapper.key_command(str(smer))
		var dir: int = int(command.get("dir", -1))
		var ok: bool = str(command.get("t", "")) == "move" and dir >= 0 and dir < 8 \
			and command.get("run") == false
		t._check(ok, "player_controller: '%s' -> Command{t:move, dir:%d, run:false} (namEReno %s)"
			% [smer, dir, str(command)])

	# konkretni cisla smeru ze `core/const.gd` (0 = vychod, 2 = sever, 4 = zapad)
	var vychod: Dictionary = mapper.key_command("east")
	var sever: Dictionary = mapper.key_command("north")
	var zapad: Dictionary = mapper.key_command("west")
	t._check(int(vychod.get("dir", -1)) == 0 and int(sever.get("dir", -1)) == 2
		and int(zapad.get("dir", -1)) == 4,
		"player_controller: east=0, north=2, west=4 (namEReno %d/%d/%d)"
			% [int(vychod.get("dir", -1)), int(sever.get("dir", -1)), int(zapad.get("dir", -1))])
	t._check(command_je_novy(mapper), "player_controller: kazdy prikaz ma nove 'seq' (ne stejne)")

	# 4) stav hrace: controller bez hrace nesmi spadnout a ma vychozi idle
	var controller = script.new()
	t._check(controller.player_tile() == Vector2i.ZERO,
		"player_controller: bez hrace vraci player_tile() (0,0), ne pád")
	t._check(controller.action() == 4,
		"player_controller: vychozi akce je 4 = idle (namEReno %d)" % controller.action())
	var MobileScript = Lib.script_at("res://sim/entity/mobile.gd")
	if MobileScript != null:
		controller.player = MobileScript.new(0x40000001, 400, Vector3i(1495, 1630, 0))
		t._check(controller.player_tile() == Vector2i(1495, 1630),
			"player_controller: player_tile() bere pozici z mobila (namEReno %s)"
				% str(controller.player_tile()))
	else:
		print("[test]      NEMERENO: player_controller nad mobilem - chybi sim/entity/mobile.gd")
	controller.free()          # Node, ne RefCounted - jinak zustane viset


func command_je_novy(mapper) -> bool:
	# `seq` musi rust: dva prikazy se stejnym `seq` by v sim vypadaly jako duplikat.
	var a: Dictionary = mapper.key_command("east")
	var b: Dictionary = mapper.key_command("east")
	return int(b.get("seq", 0)) > int(a.get("seq", 0))
