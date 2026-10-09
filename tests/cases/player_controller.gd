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

# Cesta k modulu je VSTUP - mutacni harness pousti test nad mutantem.
const CONTROLLER_SCRIPT := "res://app/player_controller.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var script = Lib.script_at(_arg("controller-script", CONTROLLER_SCRIPT))
	if script == null:
		t._pending("app/player_controller NENI HOTOV: app/player_controller.gd chybi")
		return
	var mapper_script = Lib.script_at("res://app/input_map.gd")
	if mapper_script == null:
		t._pending("app.input NENI HOTOVA: app/input_map.gd chybi")
		return
	var consts: Dictionary = Lib.consts_at("res://core/const.gd")
	var bindings: Dictionary = script.default_bindings()
	const SMERY := ["east", "ne", "north", "nw", "west", "sw", "south", "se"]

	# ⚠ 20. session: 19 -> 20 - pribyla OBECNA INTERAKCE ("interact"), kterou
	# si vyzadal uzivatel 2026-10-08 ("tlacitko je nejen na tezbu, ale vseobecne
	# interaktivni"). Vazba je to, co `app/input_map.poll` spousti - bez ni by
	# klavesa E/T nic neposlala (vstup si vazbu nevymysli).
	t._check(bindings.size() == 20,
		"player_controller: vazeb je 8 smeru + drzene prave tlacitko + prepinac behu "
		+ "+ 8 otoceni na miste + stop auto-runu + obecna interakce (namEReno %d)" % bindings.size())
	for smer in SMERY:
		t._check(bindings.has(smer), "player_controller: vazba pro smer '%s' existuje" % smer)
	# ⚠ V15 (2026-10-08): OTOCENI NA MISTE ma vlastni vazbu (Ctrl + smer).
	# Kdyby vazba chybela, `app/input_map.poll` vetev "turn_" vubec nespusti
	# (vstup si vazbu nevymysli) a otoceni zustane mrtve.
	var bez_turn: Array = []
	for smer in SMERY:
		if str(bindings.get("turn_" + smer, "")) != "turn_" + smer:
			bez_turn.append(smer)
	t._check(bez_turn.is_empty(),
		"player_controller: vsech 8 smeru ma vazbu 'turn_*' (chybi %s)" % str(bez_turn))
	# ⚠ 18. session: prepinac chuze/beh (vada "chybi beh jako rychlost pohybu")
	t._check(str(bindings.get("run_toggle", "")) == "run_toggle",
		"player_controller: vazba 'run_toggle' -> 'run_toggle' (namEReno '%s')"
			% str(bindings.get("run_toggle", "")))
	# DRZENE PRAVE TLACITKO (uzivatel 2026-10-07: "chůze držením klávesy (včetně
	# pravého tlačítka myši)") - `app/input_map.poll()` ho zpracuje vetví
	# "walk_to"; kdyz vazba chybi, mys nikdy nechodi.
	t._check(str(bindings.get("walk_to", "")) == "walk_to_cursor",
		"player_controller: vazba 'walk_to' -> 'walk_to_cursor' (namEReno '%s')"
		% str(bindings.get("walk_to", "")))
	# OBECNA INTERAKCE (20. session): jedno tlacitko na cokoliv. Klient posle
	# JEN cil (`Command{t:"interact"}`) a nastroj vybira simulace - kdyby vazba
	# chybela, tlacitko E/T by nedelalo nic a vypadalo by to jako hotova funkce.
	t._check(str(bindings.get("interact", "")) == "interact",
		"player_controller: vazba 'interact' -> 'interact' (namEReno '%s')"
		% str(bindings.get("interact", "")))

	# 2) akce se zakladaji ZA BEHU (project.godot vlastni jina granule)
	var added: int = script.register_actions()
	t._check(added >= 9, "player_controller: register_actions pridal vazby (namEReno %d)" % added)
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
	# ...a ta prave-tlacitkova musi byt opravdu PRAVE tlacitko (ne klavesa)
	var ma_prave: bool = false
	for event in InputMap.action_get_events("walk_to_cursor"):
		if event is InputEventMouseButton \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			ma_prave = true
	t._check(ma_prave,
		"player_controller: 'walk_to_cursor' ma v InputMap prave tlacitko mysi")
	# ...a vazba otoceni musi mit v InputMap MODIFIKATOR Ctrl (jinak je to táž
	# vazba jako pohyb a otoceni se spusti i bez nej; namEReno
	# `_analyza/p22-pohyb-ctrl.gd`).
	var s_ctrl: int = 0
	var bez_ctrl: Array = []
	for smer in SMERY:
		var akce: String = "turn_" + smer
		var ma: bool = false
		for event in InputMap.action_get_events(akce):
			if event is InputEventKey and (event as InputEventKey).ctrl_pressed:
				ma = true
		if ma:
			s_ctrl += 1
		else:
			bez_ctrl.append(akce)
	t._check(s_ctrl == 8 and bez_ctrl.is_empty(),
		"player_controller: vsech 8 akci 'turn_*' ma v InputMap Ctrl (namEReno %d, chybi %s)"
			% [s_ctrl, str(bez_ctrl)])

	# ⚠ 2026-10-09 (D3 jako HUD): UI klavesy (`UI_KEYS`) se zakladaji v `InputMap`
	# a NEEJSOU v `default_bindings()` (nejsou to prikazy pro sim). Kdyby se
	# nezakladaly, klavesa by nic nedelala - a okno pravidel by bylo jen mrtvy
	# kod v HUDu. Kontroluje se KONKRETNI klavesa `P` u `policy_toggle`.
	script.register_actions()
	t._check(InputMap.has_action("policy_toggle"),
		"player_controller: akce 'policy_toggle' je v InputMap (okno pravidel, D3)")
	var ma_p: bool = false
	for event in InputMap.action_get_events("policy_toggle"):
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_P:
			ma_p = true
	t._check(ma_p, "player_controller: 'policy_toggle' je na klavese P")

	# 3) smer z vazby musi dat stejne cislo jako `core/const.gd` a `input_map`
	#    ⚠ 18. session: BEH JE VYCHOZI (`app/input_map.always_run = true`, UO ma
	#    beh jako vychozi pohyb) - proto se meri OBA rezimy. Kdyby se meril jen
	#    jeden, rozbita vetev by prosla.
	var mapper = mapper_script.new(bindings)
	var dir_dx: Array = consts.get("DIR_DX", [])
	t._check(dir_dx.size() == 8, "player_controller: DIR_DX ma 8 směru (namEReno %d)" % dir_dx.size())
	mapper.always_run = false
	for smer in SMERY:
		var command: Dictionary = mapper.key_command(str(smer))
		var dir: int = int(command.get("dir", -1))
		var ok: bool = str(command.get("t", "")) == "move" and dir >= 0 and dir < 8 \
			and command.get("run") == false
		t._check(ok, "player_controller: '%s' -> Command{t:move, dir:%d, run:false} v chuzi (namEReno %s)"
			% [smer, dir, str(command)])
	mapper.always_run = true
	var bez_behu: int = 0
	for smer in SMERY:
		if mapper.key_command(str(smer)).get("run") != true:
			bez_behu += 1
	t._check(bez_behu == 0,
		"player_controller: pri behu (vychozi stav) maji vsechny smery run:true (chybi %d)"
			% bez_behu)
	mapper.always_run = false

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
	# PORADI VE FRAMU (V2): controller musi bezet AZ PO `app.loop`, jinak v ramci
	# commitu pricte posun k jiz posunute dlazdici (namEReno 37,33 px skok).
	# `setup` to nastavuje; tady se meri, ze to po `setup` opravdu plati.
	var MobileScript = Lib.script_at("res://sim/entity/mobile.gd")
	if MobileScript != null:
		var c2 = script.new()
		c2.setup(MobileScript.new(0x40000002, 400, Vector3i(0, 0, 0)), null, null, null, null, null)
		t._check(int(c2.get("process_priority")) > 0,
			"player_controller: po setup() bezi AZ po `app.loop` (process_priority %s)"
				% str(c2.get("process_priority")))
		c2.free()
	if MobileScript != null:
		controller.player = MobileScript.new(0x40000001, 400, Vector3i(1495, 1630, 0))
		t._check(controller.player_tile() == Vector2i(1495, 1630),
			"player_controller: player_tile() bere pozici z mobila (namEReno %s)"
				% str(controller.player_tile()))
	else:
		print("[test]      NEMERENO: player_controller nad mobilem - chybi sim/entity/mobile.gd")

	# 5) ⚠ V2 (2026-10-07): POSUN A ANIMACE V JEDNE FAZI. `update_step` dostane
	#    bezici krok (`sim.movement.pending_step`) a HNED z nej udela stav:
	#    animace chuze zacina v okamziku ZAMERU, ne az po zmene dlazdice
	#    (uzivatel: "prvne posune postavu a az potom zobrazi animaci chuze").
	var krok := {"dir": 0, "run": false, "start_ms": 1000, "delay_ms": 400,
		"due_ms": 1400, "z": 0}
	controller.update_step(krok)
	t._check(controller.action() == 0,
		"player_controller: krok v letu = animace CHUZE hned (akce %d, cekano 0)"
			% controller.action())
	controller.update_step({"dir": 0, "run": true, "start_ms": 1000, "delay_ms": 200,
		"due_ms": 1200, "z": 0})
	t._check(controller.action() == 1,
		"player_controller: bezici krok s `run` = animace BEHU (akce %d, cekano 1)"
			% controller.action())
	controller.update_step({})
	t._check(controller.action() == 4,
		"player_controller: zadny krok = idle (akce %d, cekano 4)" % controller.action())

	# 6) POSUN V PIXELECH: ⚠ 18. session - krok roste PLYNULE (reference
	#    `x = delay / 80f`, `Mobile.cs:776-782`), na konci kroku je presne jedna
	#    dlazdice a posun se zaokrouhluje na CELY PIXEL (`round`), aby obraz
	#    zustal ostry (reference kresli na cela cisla, `GameObject.cs:152-153`).
	#    Do 18. session se `elapsed` zaokrouhloval na 80 ms (5 skoku za krok) -
	#    presne to uzivatel videl jako "trhavost, ktera je plynula".
	var iso_step: int = int(consts.get("ISO_STEP", 22))
	var tabulka := [[0, 0.0], [79, 0.1975], [80, 0.2], [160, 0.4], [200, 0.5],
		[240, 0.6], [320, 0.8], [400, 1.0], [9999, 1.0], [-5, 0.0]]
	var chyby: Array = []
	for radek in tabulka:
		var f: float = script.step_fraction(int(radek[0]), 400)
		if absf(f - float(radek[1])) > 0.0001:
			chyby.append("%d ms -> %.4f (cekano %.4f)" % [int(radek[0]), f, float(radek[1])])
	t._check(chyby.is_empty(),
		"player_controller: krok roste plynule v case (odchylky: %s)" % str(chyby))
	controller.update_step(krok)
	var o0: Vector2 = controller.player_pixel_offset(1000)
	var o80: Vector2 = controller.player_pixel_offset(1080)
	var o320: Vector2 = controller.player_pixel_offset(1320)
	var o400: Vector2 = controller.player_pixel_offset(1400)
	t._check(o0 == Vector2.ZERO,
		"player_controller: na zacatku kroku je posun nulovy (namEReno %s)" % str(o0))
	# 0,2 dlazdice = 4,4 px -> zaokrouhleno na 4 (cely pixel)
	t._check(absf(o80.x - roundf(float(iso_step) * 0.2)) < 0.001
		and absf(o80.y - roundf(float(iso_step) * 0.2)) < 0.001,
		"player_controller: po 80 ms je posun 0,2 dlazdice na cely pixel (%s, ISO_STEP %d)"
			% [str(o80), iso_step])
	t._check(absf(o320.x - roundf(float(iso_step) * 0.8)) < 0.001,
		"player_controller: po 320 ms je posun 0,8 dlazdice (%s)" % str(o320))
	t._check(absf(o400.x - float(iso_step)) < 0.001 and absf(o400.y - float(iso_step)) < 0.001,
		"player_controller: na konci kroku je posun PRESNE jedna dlazdice (%s)" % str(o400))
	# smer 1 = NE: v izometrii je to (2*ISO_STEP, 0) - jina velikost nez vychod.
	# 200 ms = 0,5 kroku (plynule, ne "frame 2 z 5").
	controller.update_step({"dir": 1, "run": false, "start_ms": 1000, "delay_ms": 400,
		"due_ms": 1400, "z": 0})
	var one: Vector2 = controller.player_pixel_offset(1200)
	t._check(absf(one.x - roundf(float(iso_step) * 2.0 * 0.5)) < 0.001 and absf(one.y) < 0.001,
		"player_controller: smer NE se posouva po 2*ISO_STEP na ose X (namEReno %s)" % str(one))
	# krok nahoru se kresli jako krok nahoru: cilove `z` meni i svislou slozku
	controller.update_step({"dir": 0, "run": false, "start_ms": 1000, "delay_ms": 400,
		"due_ms": 1400, "z": 8})
	var nahoru: Vector2 = controller.player_pixel_offset(1400)
	t._check(absf(nahoru.y - (float(iso_step) - 8.0 * float(consts.get("Z_SCALE", 4)))) < 0.001,
		"player_controller: posun pocita i s vyskou cile z=8 (namEReno %s)" % str(nahoru))
	controller.update_step({})
	t._check(controller.player_pixel_offset(1400) == Vector2.ZERO,
		"player_controller: bez kroku je posun nulovy")

	# 7) ⚠ 17. session (2026-10-08) - SMER KRESLENI SE MENI HNED SE ZAMEREM.
	#    Uzivatel: "kdyz se zmeni smer chuze v prubehu animace, postava se sice
	#    posouva spravne, ale animace nezmeni orientaci, takaze postava jakoby
	#    klouze do strany". Pricina (namERena): `mob.dir` zapisuje
	#    `sim.movement.apply_step` az na KONCI kroku (400 ms), takze se kreslil
	#    stary smer. Kreslici smer je proto stav KLIENTA (`view_dir`).
	var sv = StubView.new()
	controller.view = sv
	controller.update_step({"dir": 4, "run": false, "start_ms": 1000, "delay_ms": 400,
		"due_ms": 1400, "z": 0})
	t._check(controller.view_dir() == 4,
		"player_controller: smer KRESLENI se zmeni hned se zamerem kroku (namEReno %d, cekano 4)"
			% controller.view_dir())
	t._check(sv.smer == 4,
		"player_controller: novy smer se posle do kreslice (world_view), namEReno %d" % sv.smer)
	# a mobil pritom jeste stoji na starem smeru - presne to je ta vada
	if controller.player != null:
		controller.player.dir = 0
		controller.update_step({"dir": 4, "run": false, "start_ms": 1000,
			"delay_ms": 400, "due_ms": 1400, "z": 0})
		t._check(controller.view_dir() == 4 and int(controller.player.dir) == 0,
			"player_controller: kresleny smer jde PRED simulaci (kresleni %d, mobil %d)"
				% [controller.view_dir(), int(controller.player.dir)])
		# ⚠⚠ 19. session (V15) - OTOCENI NA MISTE SE MUSI NAKRESLIT. Prikaz
		# `turn` NEVYTVARI zadny krok, takze `pending_step` je prazdny - a do teto
		# session klient v te chvili smer vubec neresil (event `mobile_turned`
		# nemel v `app/` konzumenta), takze se otoceni v obraze neprojevilo.
		# Kontrola je na OBA smery: smer se musi ZMENIT, kdyz se mobil otoci
		# (nahore), a zustat, kdyz se neotoci (dole) - jinak by test prosel i pro
		# klienta, ktery smer prebira z neceho jineho.
		controller.player.dir = 6
		controller.update_step({})
		t._check(controller.view_dir() == 6 and sv.smer == 6,
			"player_controller: pri prazdnem kroku se kresleny smer prevezme z mobilu "
			+ "(kresleni %d, kreslic %d, mobil %d)"
				% [controller.view_dir(), sv.smer, int(controller.player.dir)])
		# Druhy smer: stejny smer mobilu nic nemeni (zadne zbytecne posilani).
		sv.zaznamy = []
		controller.update_step({})
		t._check(controller.view_dir() == 6 and sv.zaznamy.is_empty(),
			"player_controller: stejny smer mobilu se znovu neposila (zaznamu %d)"
				% sv.zaznamy.size())

	# 8) ⚠ 17. session - KAMERA SE POSOUVA KAZDY FRAME (ne jen po dlazdici).
	#    Uzivatel: "obraz se pohybuje skokove, ne plynule - jakmile je postava
	#    na novem tile, poskoci i obrazovka". NamEReno pred opravou: skok kamery
	#    **44,00 px** na frame (cela dlazdice); po opravě 6,23 px.
	#    Kontroluje se SMLOUVA: `look_at_tile` dostane posun kroku, takze se
	#    stred kamery hybe plynule a hrac zustava ve stredu.
	var sv2 = StubView.new()
	controller.view = sv2
	controller._last_tile = Vector2i(1495, 1630)
	if controller.player != null:
		controller.player.pos = Vector3i(1495, 1630, 0)
	controller.update_step({"dir": 0, "run": false, "start_ms": 1000, "delay_ms": 400,
		"due_ms": 1400, "z": 0})
	var posun_80: Vector2 = controller.player_pixel_offset(1080)
	sv2.zaznamy = []
	# rucni volani posunu kamery bez sceny: `_process` potrebuje viewport - proto
	# se kontroluje jen to, co smi klient udelat: predat posun do `look_at_tile`.
	controller._follow(posun_80)
	var druhy: Dictionary = sv2.zaznamy[-1] if sv2.zaznamy.size() > 0 else {}
	t._check(not druhy.is_empty() and druhy["offset"] == posun_80 \
			and druhy["offset"] != Vector2.ZERO,
		"player_controller: kamera dostava posun kroku (posun %s, predano %s)"
			% [str(posun_80), str(druhy.get("offset", null))])
	controller.view = null

	# 9) ⚠⚠ V14 (2026-10-08, zadani 19): KLIENT POSILA PRESNOU POZICI HRACE pro
	#    smer z mysi. `app/input_map` do te doby skladal stred z `z = 0`
	#    (`app/loop.gd:39`), ale kamera je na `z * Z_SCALE` - na namesti
	#    Britainu (z = 10) vysel stred o 40 px niz, nez kde hrac stoji
	#    (namEReno: 4 473 z 11 163 pozic kurzoru vratilo jiny smer; sonda
	#    `_analyza/p22-mys-sonda.gd`). Klient tu hodnotu zna presne:
	#    `view.player_ground_position() - camera_offset`. Test meri tu IDENTITU
	#    (ne konkretni cislo sceny) - kdyby se nekde pricetlo `gui_odsazeni`
	#    dvakrat nebo se vynechal posun kroku, vyjde jina hodnota.
	var sv3 = StubView.new()
	sv3.pozice = Vector2(1470.0, 1690.0)
	var kam := Camera2D.new()
	kam.position = Vector2(1500.0, 1700.0)
	var mapper3 = mapper_script.new()
	controller.view = sv3
	controller.camera = kam
	controller.input_map = mapper3
	controller._publish_center()
	# Test bez sceny: `get_viewport()` je null, takze se velikost okna bere jako
	# nula a `camera_offset == camera.position` (viz `_camera_offset`).
	t._check(mapper3.player_screen == sv3.pozice - kam.position,
		"player_controller: posila pozici hrace pro smer z mysi (%s, ocekavano %s)"
			% [str(mapper3.player_screen), str(sv3.pozice - kam.position)])
	# Bez kamery (klient bez sceny) se stred NEPOSLE - vymyslena hodnota by byla
	# horsi nez "nevim" (v `input_map` pak plati zalozni vypocet).
	var mapper4 = mapper_script.new()
	controller.view = sv3
	controller.camera = null
	controller.input_map = mapper4
	controller._publish_center()
	t._check(mapper4.player_screen == Vector2.INF,
		"player_controller: bez kamery stred neposila a nechava 'nevim' (namEReno %s)"
			% str(mapper4.player_screen))
	# ⚠ 19. session - STATICKA CAST DOKLADU (a proc jen staticka): `_process`
	# MUSI `_publish_center()` volat, ale test bez sceny `_process` nespusti
	# (potrebuje viewport). Chovani proto meri sonda `_analyza/p22-mys-sonda.gd`
	# a tady se overuje to, co staticky overit lze: volani je V TĚLE `_process`.
	# ⚠⚠ Cesta se bere ze STEJNEHO vstupu jako mereny skript (`_arg`), ne
	# natvrdo `res://app/player_controller.gd` - jinak by se cetl ORIGINAL
	# a mutacni test by tuhle kontrolu nikdy nechytil (namEReno 2026-10-08:
	# s natvrdo zapsanou cestou vyslo "PROSLA - TEST JE SLEPY").
	var cesta: String = _arg("controller-script", CONTROLLER_SCRIPT)
	var zdroj: String = FileAccess.get_file_as_string(cesta)
	var od: int = zdroj.find("func _process(")
	var do_: int = zdroj.find("\nfunc ", od + 1)
	var telo: String = zdroj.substr(od, (do_ - od) if do_ > od else -1)
	t._check(od >= 0 and telo.contains("_publish_center()"),
		"player_controller: `_process` vola `_publish_center()` (jinak by stred pro "
		+ "smer z mysi nikdy neodesel; telo _process ma %d znaku)" % telo.length())
	controller.view = null
	kam.free()
	controller.free()          # Node, ne RefCounted - jinak zustane viset


class StubView extends Node2D:
	# Nahrazuje `app/world_view` v testu (bez sceny a bez atlasu): zapisuje, co
	# mu controller poslal. Test tak meri SMLOUVU, ne cizi modul.
	var smer: int = -1
	var zaznamy: Array = []
	# Kde se hrac kresli (vstup pro test V14).
	var pozice: Vector2 = Vector2.ZERO

	func player_ground_position() -> Vector2:
		return pozice

	func set_view_dir(dir: int) -> void:
		smer = dir

	func look_at_tile(tile: Vector2i, z: int = 0, offset: Vector2 = Vector2.ZERO) -> void:
		zaznamy.append({"tile": tile, "z": z, "offset": offset})

	func set_player_offset(_offset: Vector2) -> void:
		pass

	func set_action(_action: int) -> void:
		pass


func command_je_novy(mapper) -> bool:
	# `seq` musi rust: dva prikazy se stejnym `seq` by v sim vypadaly jako duplikat.
	var a: Dictionary = mapper.key_command("east")
	var b: Dictionary = mapper.key_command("east")
	return int(b.get("seq", 0)) > int(a.get("seq", 0))
