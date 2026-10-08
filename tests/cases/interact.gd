extends RefCounted
# OBECNA INTERAKCE - `Command{t:"interact"}` end-to-end (20. session, pokyn
# uzivatele 2026-10-08: "tlacitko je nejen na tezbu, ale vseobecne interaktivni").
#
# MERI SE CELA CESTA, ne pritomnost metod:
#   klient (`app.input.interact_command`) -> `sim.commands.dispatch` ->
#   `sim.interaction.interact` (vybere NASTROJ z batohu podle PÁROVÉ TABULKY
#   docs/05 §5.2.3) -> `sim.harvest.mine/chop/fish` -> predmet v batohu + hlaska.
#
# Co je na tom testu DULEZITE (a co by jinde nevyslo):
#   * "vsechny nastroje v batohu" znamena, ze volba nastroje je ROZHODNUTI.
#     Test proto dava krumpac do batohu DRIV nez sekeru a na stromu pozaduje
#     SEKERU (kdyby se bral "prvni par v tabulce", vysel by krumpac a test
#     spadne - to je jeho hlavni smysl),
#   * hlášky: kazda vetev, ktera neuspeje, musi byt VIDET (docs/05 §5.2.2).
#     Do teto session vracely `not_ore`/`too_far`/`empty` jen slovnik a hrac
#     nevidel nic - proto se tu kontroluji texty, ne jen `reason`,
#   * "co neni pripravene, proste neprobehne": cil bez pary (travnik, prazdny
#     batoh) nesmi zmenit stav ANI tise mlcet,
#   * predmetovy cil (vyhen) jde DYNAMICKYM routingem do systemu - test to
#     dokazuje stubem, ktery si zapise argumenty (`smelt(m, ore, forge)`).
#
# Cesty k merenym modulum jsou VSTUP (`-- --interaction-script=`,
# `-- --harvest-script=`) - stejny vzor jako `tests/cases/harvest.gd`, aby se
# daly mutovat.

const Lib = preload("res://tests/lib.gd")
const SimScript = preload("res://sim/sim_world.gd")
const CommandsScript = preload("res://sim/commands.gd")
const ContainerScript = preload("res://sim/entity/container.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const Iso = preload("res://core/iso.gd")

const INTERACTION_SCRIPT := "res://sim/systems/interaction.gd"
const HARVEST_SCRIPT := "res://sim/systems/harvest.gd"
const ITEMS_DATA := "res://data/items.json"
const PLAYER_SCRIPT := "res://app/player_controller.gd"
const INPUT_SCRIPT := "res://app/input_map.gd"

const SERIAL := 0x40000042
const PACK := 0x00000099
const TRAVNIK := 9999           # land id, ktery NENI v zadnem seznamu uzlu
const HORA := 220               # prvni land id hor (research/04 §1.2)
const VODA := 0x00A8            # prvni land id vody (research/04 §1.4)
const STROM := 0x4CCA           # prvni art ze seznamu stromu (research/04 §1.3)
const MESSAGE_NIC := "You see nothing special."


class StubMap:
	var land: Dictionary = {}
	var statics: Dictionary = {}

	func land_at(x: int, y: int) -> int:
		return int(land.get(Vector2i(x, y), TRAVNIK))

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x, y), [])


class StubSkill:
	# Vzdy uspeje - test meri ROUTING a volbu nastroje, ne hod (ten ma vlastni
	# sadu v `tests/cases/harvest.gd` a `skill_gain.gd`).
	func check(_m: int, _skill: int, _difficulty: int, _span: int = -1) -> Dictionary:
		return {"success": true, "gained": false, "new_value": 0, "reason": ""}


class StubTiledata:
	# Kontejner potrebuje vahu a flagy; `generic` (0x800) tu NENI, aby se
	# hromady neslucovaly a dalo se pocitat, kolik predmetu opravdu vzniklo.
	func weight(_tile: int) -> int:
		return 1

	func flags(_tile: int) -> int:
		return 0


class StubCraft:
	# Zaznamena volani - dokazuje dynamicky routing na predmetovy cil.
	var volani: Array = []

	func smelt(m: int, ore: int, forge: int) -> Dictionary:
		volani.append({"m": m, "ore": ore, "forge": forge})
		return {"ok": true, "action": "smelt", "reason": ""}


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _art_role(role: String) -> int:
	# ART ID z `data/items.json` podle role (data maji TILEDATA ID, `+0x4000`).
	# Cisla se odsud neopisuji - jediny zdroj je datovy soubor.
	var data = Lib.json_at(ITEMS_DATA)
	if not (data is Array):
		return 0
	for rec in data:
		if rec is Dictionary and str(rec.get("role", "")) == role:
			return int(rec["tile"]) + 0x4000
	return 0


func _statik(mapa, x: int, y: int, tile: int) -> void:
	var seznam: Array = mapa.statics.get(Vector2i(x, y), [])
	seznam.append({"tile": tile, "x": x % 8, "y": y % 8, "z": 0, "hue": 0})
	mapa.statics[Vector2i(x, y)] = seznam


func _sestav(t, land: Dictionary, statiky: Dictionary, nastroje: Array) -> Dictionary:
	# Vraci slovnik s celym svetem testu, nebo {} (a to je SELHANI, ne zelena).
	var harvest_script = Lib.script_at(_arg("harvest-script", HARVEST_SCRIPT))
	if harvest_script == null:
		t._pending("sim.harvest NENI K DISPOZICI: " + HARVEST_SCRIPT)
		return {}
	var interaction_script = Lib.script_at(_arg("interaction-script", INTERACTION_SCRIPT))
	if interaction_script == null:
		t._pending("sim.interaction NENI K DISPOZICI: " + INTERACTION_SCRIPT)
		return {}
	var sim = SimScript.new(1234, {})
	var mob = MobileScript.new(SERIAL, 400, Vector3i(100, 100, 0))
	mob.backpack = PACK
	var registry = RegistryScript.new()
	registry.register(mob)
	sim.player_serial = SERIAL
	var container = ContainerScript.new(StubTiledata.new())
	var items: Dictionary = {}
	var mapa := StubMap.new()
	mapa.land = land
	mapa.statics = statiky
	var harvest = harvest_script.new(mapa, true, registry, sim.rng(), sim.clock(),
		sim.events(), StubSkill.new(), container, sim, items)
	sim.systems["harvest"] = harvest
	var interaction = interaction_script.new(sim, sim.events(), null, container, registry, items)
	sim.systems["interaction"] = interaction
	var dane: Array = []
	for art in nastroje:
		var nastroj = ItemScript.new(sim.next_serial(), int(art), 1)
		if container.add(PACK, nastroj):
			items[int(nastroj.serial)] = nastroj
			dane.append(int(nastroj.serial))
	var commands = CommandsScript.new()
	return {"sim": sim, "mob": mob, "mapa": mapa, "container": container, "items": items,
		"harvest": harvest, "interaction": interaction, "commands": commands,
		"nastroje": dane}


func _texty(sim) -> Array[String]:
	# Texty hlasek z udalosti `message` (frontu vyprázdní).
	var out: Array[String] = []
	for event in sim.drain_events():
		if event is Dictionary and str(event.get("name", "")) == "message":
			out.append(str(event.get("data", {}).get("text", "")))
	return out


func _obsah(sestava) -> Array:
	return sestava["container"].contents(PACK)


func _art_v_batohu(sestava, art: int) -> bool:
	for serial in _obsah(sestava):
		var predmet = sestava["items"].get(int(serial))
		if predmet != null and int(predmet.tile) == art:
			return true
	return false


func _posli(sestava, x: int, y: int) -> Array[String]:
	# Jeden pokyn "interaguj s dlazdici" + hlášky, ktere na nej prisly.
	sestava["commands"].dispatch(sestava["sim"],
		{"t": "interact", "target": {"kind": "tile", "x": x, "y": y, "z": 0}})
	return _texty(sestava["sim"])


func _posli_na_predmet(sestava, serial: int) -> Array[String]:
	sestava["commands"].dispatch(sestava["sim"],
		{"t": "interact", "target": {"kind": "item", "serial": serial}})
	return _texty(sestava["sim"])


func run(t) -> void:
	var consts_h: Dictionary = Lib.consts_at(_arg("harvest-script", HARVEST_SCRIPT))
	if consts_h.is_empty():
		t._pending("sim.harvest: konstanty nejdou precist - test nemeri nic")
		return
	var ore_art: int = int(consts_h.get("ORE_ART", 0))
	var log_art: int = int(consts_h.get("LOG_ART", 0))
	var fish_arts: Array = consts_h.get("FISH_ARTS", [])
	var krumpac: int = _art_role("pickaxe")
	var sekera: int = _art_role("hatchet")
	var prut: int = _art_role("fishing pole")
	var vyhen: int = _art_role("forge")
	var ruda: int = _art_role("iron ore")
	t._check(krumpac > 0 and sekera > 0 and prut > 0 and vyhen > 0 and ruda > 0,
		"interact: role z `data/items.json` jdou prelozit na art (krumpac %d, sekera %d, prut %d, vyhen %d, ruda %d)"
			% [krumpac, sekera, prut, vyhen, ruda])

	# -- A) HORA + KRUMPAC -> RUDA ----------------------------------------
	var a := _sestav(t, {Vector2i(100, 100): HORA}, {}, [krumpac])
	if a.is_empty():
		return
	var pred_a: int = _obsah(a).size()
	var texty_a: Array[String] = _posli(a, 100, 100)
	t._check(_art_v_batohu(a, ore_art) and _obsah(a).size() == pred_a + 1,
		"interact: hora + krumpac v batohu -> ruda v batohu (art %d, predmetu %d -> %d, hlasky %s)"
			% [ore_art, pred_a, _obsah(a).size(), str(texty_a)])
	t._check(not texty_a.is_empty() and str(texty_a[0]).contains("iron"),
		"interact: uspesna tezba REKNE, co hrac ziskal (namEReno %s)" % str(texty_a))

	# -- B) TRAVNIK -> NIC SE NESTANE (a je to videt) ----------------------
	var b := _sestav(t, {Vector2i(100, 100): TRAVNIK}, {}, [krumpac])
	var pred_b: int = _obsah(b).size()
	var texty_b: Array[String] = _posli(b, 100, 100)
	t._check(_obsah(b).size() == pred_b and texty_b.has(MESSAGE_NIC),
		"interact: travnik -> zadna zmena a hlaska '%s' (zmena %d, hlasky %s)"
			% [MESSAGE_NIC, _obsah(b).size() - pred_b, str(texty_b)])

	# -- C) STROM: VYBERIE SE SEKERA, NE KRUMPAC ---------------------------
	# Krumpac jde do batohu PRVNI (nizsi serial) - kdyby se bral prvni par
	# v tabulce, byl by vybran krumpac a zadny log by nevznikl.
	var c := _sestav(t, {Vector2i(100, 100): TRAVNIK}, {}, [krumpac, sekera])
	_statik(c["mapa"], 100, 100, STROM)
	var texty_c: Array[String] = _posli(c, 100, 100)
	t._check(_art_v_batohu(c, log_art),
		"interact: na strom se vybere SEKERA (krumpac je v batohu driv) - log v batohu (art %d, hlasky %s)"
			% [log_art, str(texty_c)])

	# -- D) VODA + PRUT -> RYBOLOV (8 s na pokus) --------------------------
	var d := _sestav(t, {Vector2i(100, 100): VODA}, {}, [krumpac, prut])
	var texty_d: Array[String] = _posli(d, 100, 100)
	var ryba: bool = false
	for art in fish_arts:
		if _art_v_batohu(d, int(art)):
			ryba = true
	t._check(ryba, "interact: na vodu se vybere PRUT a chyti se ryba (art %s, hlasky %s)"
		% [str(fish_arts), str(texty_d)])
	t._check(d["harvest"].busy_until("fish") - d["sim"].clock().now_ms() == 8000,
		"interact: rybolov zamkne system na 8 s (namEReno %d ms)"
			% (d["harvest"].busy_until("fish") - d["sim"].clock().now_ms()))

	# -- E) PRAZDNY BATOH -> NIC (a hlaska) --------------------------------
	var e := _sestav(t, {Vector2i(100, 100): HORA}, {}, [])
	var pred_e: int = _obsah(e).size()
	var texty_e: Array[String] = _posli(e, 100, 100)
	t._check(_obsah(e).size() == pred_e and texty_e.has(MESSAGE_NIC),
		"interact: bez nastroje -> zadna zmena a hlaska (zmena %d, hlasky %s)"
			% [_obsah(e).size() - pred_e, str(texty_e)])

	# -- F) MIMO DOSAH (5 dlazdic) -> HLASKA, ZADNA ZMENA -------------------
	var f := _sestav(t, {Vector2i(105, 100): HORA}, {}, [krumpac])
	var pred_f: int = _obsah(f).size()
	var texty_f: Array[String] = _posli(f, 105, 100)
	t._check(_obsah(f).size() == pred_f and not texty_f.is_empty(),
		"interact: 5 dlazdic dal -> zadna zmena a hlaska (zmena %d, hlasky %s)"
			% [_obsah(f).size() - pred_f, str(texty_f)])

	# -- G) VYCERPANA ZILA -> HLASKA "no metal left" -----------------------
	var g := _sestav(t, {Vector2i(100, 100): HORA}, {}, [krumpac])
	var dob: int = 0
	while dob < 40 and int(g["harvest"].resource_left(100, 100)) > 0:
		_posli(g, 100, 100)
		g["sim"].tick(2000)          # uvolni `busy` (1,6 s) - cas je sim
		dob += 1
	var texty_g: Array[String] = _posli(g, 100, 100)
	t._check(dob > 0 and int(g["harvest"].resource_left(100, 100)) == 0 and not texty_g.is_empty(),
		"interact: vycerpana zila -> hlaska a prazdna banka (dob %d, hlasky %s)"
			% [dob, str(texty_g)])

	# -- H) PREDMETOVY CIL (VYHEN) -> DYNAMICKY ROUTING --------------------
	# ⚠ Ruda se bere jako ART, KTERY HRA OPRAVDU VYRABI (`sim.harvest.ORE_ART`
	# = 0x59B8), ne jak prvni shoda jmena v datech: do 20. session mela role
	# "iron ore" jen jedna ze ctyr artu rudy, takze prave vytezena ruda se
	# na vyhen NEDALA pouzit (`use_on` vracel `no_pair`). Tohle je regresni
	# kontrola te vady: kdyby generator prestal davat roli vsem nosonym artum,
	# spadne nejdriv tahle.
	var ore_art_h: int = int(consts_h.get("ORE_ART", 0))
	var h := _sestav(t, {Vector2i(100, 100): TRAVNIK}, {}, [ore_art_h])
	t._check(str(h["interaction"].role_of(ore_art_h)) == "iron ore",
		"data.items: art vytezene rudy 0x%04X ma roli 'iron ore' (namEReno '%s') - jinak ji hrac nemuze pouzit na vyhen"
			% [ore_art_h, str(h["interaction"].role_of(ore_art_h))])
	var vyhen_item = ItemScript.new(h["sim"].next_serial(), vyhen, 1)
	h["items"][int(vyhen_item.serial)] = vyhen_item
	var stub = StubCraft.new()
	h["sim"].systems["craft"] = stub
	var texty_h: Array[String] = _posli_na_predmet(h, int(vyhen_item.serial))
	t._check(stub.volani.size() == 1 and int(stub.volani[0]["forge"]) == int(vyhen_item.serial)
			and int(stub.volani[0]["ore"]) > 0,
		"interact: ruda na vyhen -> `smelt(m, ore, forge)` v systemu `craft` (volani %s, hlasky %s)"
			% [str(stub.volani), str(texty_h)])

	# -- I) JMENA DRUHU DLAZDICE: harvest a interaction se NESMI ROZEJIT ----
	# `interaction._method_for_tile` preklada "ore"/"wood"/"fish" na metody.
	# Kdyby je harvest prejmenoval, volba nastroje by se TISE rozbila (sběr by
	# fungoval dal) - proto se to tu pripichne.
	t._check(str(consts_h.get("KIND_ORE", "")) == "ore"
			and str(consts_h.get("KIND_WOOD", "")) == "wood"
			and str(consts_h.get("KIND_FISH", "")) == "fish",
		"interact: `KIND_*` v sim.harvest sedi s tim, co preklada interaction (%s/%s/%s)"
			% [str(consts_h.get("KIND_ORE", "")), str(consts_h.get("KIND_WOOD", "")),
				str(consts_h.get("KIND_FISH", ""))])
	var i := _sestav(t, {Vector2i(100, 100): HORA, Vector2i(101, 101): TRAVNIK},
		{}, [krumpac])
	_statik(i["mapa"], 102, 102, STROM)
	t._check(str(i["harvest"].resource_kind(100, 100)) == "ore"
			and str(i["harvest"].resource_kind(102, 102)) == "wood"
			and str(i["harvest"].resource_kind(101, 101)) == "",
		"sim.harvest: `resource_kind` rozpozna horu/strom/nic (namEReno %s/%s/%s)"
			% [str(i["harvest"].resource_kind(100, 100)),
				str(i["harvest"].resource_kind(102, 102)),
				str(i["harvest"].resource_kind(101, 101))])

	# -- M) POCATECNI SKILLY: hrac musi mit z ceho tezit --------------------
	# ⚠ NAMERENO (`_analyza/p23-interakce.gd`): se skilly 0 je sance sberu
	# `skill/1000` = 0 %, takze hrac za 30 uderu nevytěží NIC; se skillem 30.0
	# (sablona Blacksmith z `research/profese.json`) da zila rudu za 2 udery.
	# Test vola `app.main.start_skills()` (nazev -> id) na SKUTECNYCH datech:
	# kdyby se skill ve `data/skills.json` jmenoval jinak, Mining by se tise
	# nepridal a tezba by zustala mrtva.
	var main_script = Lib.script_at("res://app/main.gd")
	if main_script == null:
		t._pending("app.main NENI K DISPOZICI: app/main.gd chybi")
		return
	var balance = Lib.json_at("res://data/balance.json")
	var skills_data = Lib.json_at("res://data/skills.json")
	if not (balance is Dictionary) or not (skills_data is Array):
		t._pending("data/balance.json nebo data/skills.json nejdou precist - start skilly se nemeri")
		return
	var start_skilly: Dictionary = main_script.start_skills(
		balance.get("player_start_skills", {}), skills_data)
	var mining_id: int = -1
	for rec in skills_data:
		if rec is Dictionary and str(rec.get("name", "")) == "Mining":
			mining_id = int(rec["id"])
	t._check(mining_id >= 0 and int(start_skilly.get(mining_id, 0)) >= 100,
		"app.main: `player_start_skills` da hracovi Mining %s desetin (id %d) - bez toho je tezba nehratelna (namEReno %s)"
			% [str(start_skilly.get(mining_id, 0)), mining_id, str(start_skilly)])
	t._check(start_skilly.size() >= 4,
		"app.main: pocatecni skilly pokryvaji celou sablonu (Blacksmith, Tinkering, Mining, Tailoring) - namEReno %d"
			% start_skilly.size())

	# -- N) TYP JE IDENTITA, ART JE JEJI PROJEV (20. session, rozhodnuti B) ---
	# Co se tu hlida:
	#   1. kazdy zaznam v `data/items.json` ma `type` (jinak by identita chybela),
	#   2. vsechny arty rudy maji JEDEN typ a TEN ma roli (ne "art ma roli"),
	#   3. hromady tehoz typu s RŮZNOU grafikou se sliji (do 20. session rozhodoval
	#      art, takze by se ruda z ruzne velkych hromad neslila),
	#   4. `hue` uvnitr typu porad rozlisuje (zelezo vs dull copper).
	var item_script = Lib.script_at("res://sim/entity/item.gd")
	if item_script == null:
		t._pending("sim.entity.item NENI K DISPOZICI")
		return
	var bez_typu: int = 0
	for rec in Lib.json_at(ITEMS_DATA):
		if rec is Dictionary and str(rec.get("type", "")) == "":
			bez_typu += 1
	t._check(bez_typu == 0,
		"data.items: kazdy zaznam ma `type` (bez nej: %d)" % bez_typu)
	t._check(str(item_script.type_of(ore_art_h)) == "iron_ore"
			and str(item_script.role_of(ore_art_h)) == "iron ore"
			and item_script.arts_of("iron_ore").size() >= 4,
		"entity.item: art 0x%04X -> typ '%s' -> role '%s' (%d artu typu) - role patri TYPU"
			% [ore_art_h, str(item_script.type_of(ore_art_h)),
				str(item_script.role_of(ore_art_h)), item_script.arts_of("iron_ore").size()])
	var arty_rudy: Array = item_script.arts_of("iron_ore")
	var role_rudy: Array = []
	for art in arty_rudy:
		role_rudy.append(str(item_script.role_of(int(art))))
	t._check(role_rudy.size() >= 4 and role_rudy.all(func(r): return r == "iron ore"),
		"entity.item: VSECHNY arty rudy maji roli 'iron ore' (namEReno %s)" % str(role_rudy))
	# 3) slouceni hromad: dva arty TEHOZ typu (ruzne velikosti hromady) + stejna hue
	var hromada_a = ItemScript.new(1, int(arty_rudy[0]), 3)
	var hromada_b = ItemScript.new(2, int(arty_rudy[arty_rudy.size() - 1]), 2)
	hromada_a.hue = 0x973
	hromada_b.hue = 0x973
	t._check(hromada_a.same_pile(hromada_b),
		"entity.item: hromady tehoz typu s jinym artem se sliji (art %d vs %d, typ '%s')"
			% [hromada_a.tile, hromada_b.tile, hromada_a.type])
	hromada_b.hue = 0x966
	t._check(not hromada_a.same_pile(hromada_b),
		"entity.item: jina `hue` (jiny kov) se NESLUCUJE (namEReno hue %d vs %d)"
			% [hromada_a.hue, hromada_b.hue])

	# -- J) KLIENT: klik na dlazdici pod kurzorem --------------------------
	var input_script = Lib.script_at(INPUT_SCRIPT)
	if input_script == null:
		t._pending("app.input NENI K DISPOZICI: " + INPUT_SCRIPT)
		return
	# Vazbu bereme Z KLIENTA (`default_bindings`), ne z literalu: kdyby ji
	# `app/player_controller` prejmenoval, test to nesmi tise prekryt.
	var player_script = Lib.script_at(PLAYER_SCRIPT)
	if player_script == null:
		t._pending("app.player_controller NENI K DISPOZICI: " + PLAYER_SCRIPT)
		return
	var vazba: String = str(player_script.default_bindings().get("interact", ""))
	t._check(vazba == "interact",
		"player_controller: obecna interakce ma vazbu 'interact' (namEReno '%s')" % vazba)
	var mapper = input_script.new({"interact": vazba})
	var iso = Iso.new()
	var kamera := Vector2(100.0, 50.0)
	var z_hrace: int = 10                     # Britain stoji na z = 10
	var kurzor := Vector2(400.0, 300.0)       # uvnitr viditelneho sveta
	var ocekavana: Vector2i = iso.to_tile(kurzor.x + kamera.x, kurzor.y + kamera.y, z_hrace)
	var prikaz: Dictionary = mapper.interact_command(kurzor, kamera, z_hrace)
	var cil: Dictionary = prikaz.get("target", {})
	t._check(str(prikaz.get("t", "")) == "interact" and str(cil.get("kind", "")) == "tile"
			and int(cil.get("x", -1)) == ocekavana.x and int(cil.get("y", -1)) == ocekavana.y
			and int(cil.get("z", -1)) == z_hrace,
		"app.input: `interact_command` prelozi kurzor na dlazdici pod nim (vyslo %s, cekano %s)"
			% [str(prikaz), str(ocekavana)])
	# ⚠ VYSKA SE DO PREPOCTU PROMITA (vada V14 mela tyz koren): se `z = 0` vyjde
	# na vysce jina dlazdice nez se skutecnou vyskou hrace - `app/loop.gd` proto
	# posila `player_z` z `app/player_controller._follow()`.
	var bez_vysek: Dictionary = mapper.interact_command(kurzor, kamera, 0)
	t._check(int(bez_vysek["target"]["y"]) != ocekavana.y or int(bez_vysek["target"]["x"]) != ocekavana.x,
		"app.input: vyska hrace meni cil kliku (z=%d -> %s, z=0 -> %s)"
			% [z_hrace, str(ocekavana), str(bez_vysek["target"])])

	# -- K) KLIENT: cerny pas GUI neni svet ---------------------------------
	mapper.view_size = Vector2(1280, 720)
	mapper.gui_pas = Vector2(320, 120)
	t._check(mapper.is_over_gui(Vector2(1200, 300)) and mapper.is_over_gui(Vector2(400, 700))
			and not mapper.is_over_gui(kurzor),
		"app.input: `is_over_gui` rozpozna pravy a dolni pas (vpravo %s, dole %s, svet %s)"
			% [str(mapper.is_over_gui(Vector2(1200, 300))),
				str(mapper.is_over_gui(Vector2(400, 700))),
				str(mapper.is_over_gui(kurzor))])
	mapper.view_size = Vector2.ZERO
	t._check(not mapper.is_over_gui(Vector2(1200, 300)),
		"app.input: bez zname velikosti okna `is_over_gui` nic neblokuje (nevim != neinteraguj)")

	# -- L) KLIENT: stisknute tlacitko posle `interact` s cilem pod kurzorem -
	# ⚠ Akci zaklada `app/player_controller.register_actions()`, ale tenhle case
	# ji zaklada SAM (a jen ji): `tests/cases/player_controller.gd` si meri, kolik
	# vazeb `register_actions()` PŘIDALO, a case soubory jdou abecedne - volat ji
	# odsud by mu "ukradlo" prvni beh a jeho kontrola by spadla na 0.
	# Ze ji registruje opravdu `register_actions()`, hlida jeho vlastni sada
	# (kontroluje kazdou vazbu z `default_bindings()` proti `InputMap`).
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	mapper.view_size = Vector2(1280, 720)
	mapper.gui_pas = Vector2(320, 120)
	mapper.player_screen = kurzor
	Input.action_press("interact")
	var vydane: Array = mapper.poll(Vector2i(1234, 1567), kamera, z_hrace, kurzor, 0)
	Input.action_release("interact")
	var ma_interact: bool = false
	for vydany_prikaz in vydane:
		if vydany_prikaz is Dictionary and str(vydany_prikaz.get("t", "")) == "interact":
			ma_interact = true
	t._check(ma_interact,
		"app.input: stisknute tlacitko interakce posle `Command{t:\"interact\"}` (vydano %s)"
			% str(vydane))
	# A v cernem pasu se neposle nic (tam svet neni).
	var v_pasu: Vector2 = Vector2(1200, 300)
	mapper.player_screen = v_pasu
	Input.action_press("interact")
	var vydane_pas: Array = mapper.poll(Vector2i(1234, 1567), kamera, z_hrace, v_pasu, 100)
	Input.action_release("interact")
	var interact_v_pasu: bool = false
	for vydany_pas_prikaz in vydane_pas:
		if vydany_pas_prikaz is Dictionary and str(vydany_pas_prikaz.get("t", "")) == "interact":
			interact_v_pasu = true
	t._check(not interact_v_pasu,
		"app.input: v cernem pasu GUI se interakce nespusti (vydano %s)" % str(vydane_pas))
