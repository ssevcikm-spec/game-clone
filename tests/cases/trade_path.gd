extends RefCounted
# CESTA HRACE K OBCHODU (session D, 2026-10-11).
#
# PROC TENHLE TEST EXISTUJE: kritérium dema je "hráč projde krátkou smyčku
# (těžba -> výroba -> PRODEJ)". Do session D se prodej dal sehrát JEN SONDou
# (`_analyza/p34-smycka.gd` volala `Command{t:"use"}` přímo), protože:
#   1. `app/input_map` sice má `object_command()` pro `use`, ale v produkci ho
#      NIKDO nevolal - hráč tedy neměl jak prodejce "použít",
#   2. `ui/vendor_gump` uměl jen NAKUPOVAT: `nastav_smer("sell")` volal pouze
#      test, v okně na to nebylo tlačítko.
# Test měří PRÁVĚ TYHLE DVĚ VĚCI NA CHOVÁNÍ (ne přítomnost metody):
#   A) `app/input_map.interact_command()` pošle u bytosti cíl `{kind:"mobile"}`,
#      u prázdné dlaždice dál `{kind:"tile"}` - a `area_mobile` (útok) prodejce
#      pořád PŘESKAKUJE (to je rozdíl "použij" vs "zaútoč"),
#   B) `sim.interaction.interact()` na bytost ZAVOLÁ `use` (prodejce ->
#      `gump_open{gump:"vendor"}`, monstrum -> `combat.attack`),
#   C) `ui/vendor_gump` má v UZLECH tlačítko, kterým hráč přepne na prodej.

const Lib = preload("res://tests/lib.gd")

const INPUT_SCRIPT := "res://app/input_map.gd"
const INTERACTION_SCRIPT := "res://sim/systems/interaction.gd"
const VENDOR_GUMP_SCRIPT := "res://ui/vendor_gump.gd"
const REGISTRY_SCRIPT := "res://sim/entity/registry.gd"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const EVENTS_SCRIPT := "res://core/events.gd"
const ISO_SCRIPT := "res://core/iso.gd"

const HRAC := 0x40000001
const NPC := 0x40000002
const Z := 10


class StubWorld extends RefCounted:
	var systems: Dictionary = {}


class StubVendor extends RefCounted:
	# Nahrazuje `sim.vendor` - `sim.interaction` z nej vola jen tyhle dve metody.
	var gump: Dictionary = {"gump": "vendor", "data": {"vendor": 0, "id": "blacksmith",
		"buy": [], "sell": []}}

	func vendor_of_serial(_serial: int) -> int:
		return 0

	func gump_data(_m: int, v: int) -> Dictionary:
		var out: Dictionary = gump.duplicate(true)
		(out["data"] as Dictionary)["vendor"] = v
		return out


class StubCombat extends RefCounted:
	var utoky: Array = []

	func attack(m: int, cil: int) -> Dictionary:
		utoky.append({"m": m, "cil": cil})
		return {"ok": true, "action": "attack", "reason": ""}


class StubHarvest extends RefCounted:
	# Nahrazuje `sim.harvest` - `sim.interaction` z nej bere jen to, co je na
	# dlazdici za uzel ("ore"/"wood"/"fish"). Tim se meri PRIORITA: uzel pred
	# bytosti.
	func resource_kind(_x: int, _y: int) -> String:
		return "ore"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var input_script = Lib.script_at(_arg("input-script", INPUT_SCRIPT))
	var interaction_script = Lib.script_at(_arg("interaction-script", INTERACTION_SCRIPT))
	var registry_script = Lib.script_at(REGISTRY_SCRIPT)
	var mobile_script = Lib.script_at(MOBILE_SCRIPT)
	var events_script = Lib.script_at(EVENTS_SCRIPT)
	var iso_script = Lib.script_at(ISO_SCRIPT)
	if input_script == null or interaction_script == null or registry_script == null \
			or mobile_script == null or events_script == null or iso_script == null:
		t._pending("cesta hrace NEMERENA: chybi app/input_map, sim.interaction, "
			+ "sim.entity_registry, entity.mobile, core.events nebo core.iso")
		return

	# -- A) KLIENT: cil pod kurzorem je BYTOST, ne dlazdice -------------------
	var registry = registry_script.new()
	var kovar = mobile_script.new(NPC, 400, Vector3i(1496, 1630, Z))
	kovar.name = "Blacksmith"
	kovar.hp = 100
	kovar.ai = {"state": "vendor"}
	registry.register(kovar)
	# ⚠ P2 (2026-10-12): HRÁČ MUSÍ BÝT V REGISTRU. Do tohoto datumu tu byl jen
	# prodejce a `use` vzdálenost neřešil. Dnes je dosah kontrakt
	# (`data/balance.json: range.use`) a "nevím, kde hráč je" = "není na dosah" -
	# tedy SPRÁVNÉ odmítnutí, které by test bez hráče měřil jako vadu.
	registry.register(mobile_script.new(HRAC, 400, Vector3i(1495, 1630, Z)))
	var iso = iso_script.new()
	var dlazdice := Vector2i(int(kovar.pos.x), int(kovar.pos.y))
	var svet: Vector2 = iso.to_screen(dlazdice.x, dlazdice.y, Z)
	var mapper = input_script.new({"interact": "interact"}, registry, null)
	# `camera_offset = ZERO` a `zoom = 1` => `_na_svet(screen) == screen`.
	var prikaz: Dictionary = mapper.interact_command(svet, Vector2.ZERO, Z)
	var cil: Dictionary = prikaz.get("target", {})
	# ⚠⚠ KLIENT POSILA VZDY JEN DLAZDICI - i kdyz na ni nekdo stoji. Zkouselo se,
	# ze klient vybere bytost podle registru; tim ale rozhodoval "co je na
	# dlazdici" a monstrum, ktere se projde pres rudu, vzalo hracovi moznost
	# tezit (namEReno: 0 rudy po 60 pokusech, sonda p58). Rozhoduje SIM.
	t._check(str(cil.get("kind", "")) == "tile"
			and int(cil.get("x", -1)) == dlazdice.x and int(cil.get("y", -1)) == dlazdice.y,
		"app.input: `interact_command` posle VZDY {kind:tile} na dlazdici pod kurzorem (vyslo %s)"
			% str(prikaz))
	# ROZDIL "pouzij" vs "zautoc": utok prodejce PRESKAKUJE (interakce ho pouzije).
	t._check(mapper.area_mobile(dlazdice) == 0,
		"app.input: `area_mobile` (utok) prodejce PRESKOCI (namEReno %d)"
			% mapper.area_mobile(dlazdice))
	# Mrtva bytost neni cil utoku (hp <= 0).
	kovar.hp = 0
	t._check(mapper.area_mobile(dlazdice) == 0,
		"app.input: mrtva bytost neni cil (namEReno %d)" % mapper.area_mobile(dlazdice))
	kovar.hp = 100

	# -- B) SIM: dlazdice s bytosti se prevede na `use` ---------------------
	var world := StubWorld.new()
	var events = events_script.new()
	var vendor := StubVendor.new()
	var combat := StubCombat.new()
	world.systems = {"vendor": vendor, "combat": combat}
	var modul = interaction_script.new(world, events, null, null, registry, null)
	var dlazdice_cil: Dictionary = {"kind": "tile", "x": dlazdice.x, "y": dlazdice.y, "z": Z}
	var vysledek: Dictionary = modul.interact(HRAC, dlazdice_cil)
	var gump: Dictionary = {}
	for u in events.drain():
		if str(u["name"]) == "gump_open":
			gump = u["data"]
	t._check(bool(vysledek.get("ok", false)) and str(vysledek.get("action", "")) == "open_vendor",
		"sim.interaction: `interact` na dlazdici S PRODEJCEM otevre obchod (vyslo %s)" % str(vysledek))
	t._check(str(gump.get("gump", "")) == "vendor",
		"sim.interaction: `interact` na dlazdici s prodejcem posle `gump_open{gump:'vendor'}` (vyslo %s)"
			% str(gump))
	# OPACNA PRIORITA: kdyz je na dlazdici UZEL SUROVINY, bytost se NEpouzije
	# (presne vada, ktera se namERila: monstrum pres rudu = 0 rudy).
	var world2 := StubWorld.new()
	var harvest := StubHarvest.new()
	world2.systems = {"vendor": vendor, "combat": combat, "harvest": harvest}
	var modul2 = interaction_script.new(world2, events, null, null, registry, null)
	events.clear()
	var vysledek3: Dictionary = modul2.interact(HRAC, dlazdice_cil)
	var gump2: Dictionary = {}
	for u in events.drain():
		if str(u["name"]) == "gump_open":
			gump2 = u["data"]
	t._check(gump2.is_empty() and str(vysledek3.get("reason", "")) == "no_pair",
		"sim.interaction: na dlazdici s RUDOU vyhraje uzel, ne bytost (vyslo %s)" % str(vysledek3))
	# Ne-prodejce: `interact` na dlazdici s monstrem je UTOCNY prikaz.
	var monstrum = mobile_script.new(0x40000009, 50, Vector3i(1500, 1630, Z))
	monstrum.hp = 30
	monstrum.ai = {"state": "idle"}
	registry.register(monstrum)
	var vysledek2: Dictionary = modul.interact(HRAC,
		{"kind": "tile", "x": 1500, "y": 1630, "z": Z})
	t._check(combat.utoky.size() == 1 and int((combat.utoky[0] as Dictionary).get("cil", 0)) == 0x40000009,
		"sim.interaction: `interact` na dlazdici s monstrem zavola `combat.attack` (volani %s)"
			% str(combat.utoky))
	t._check(bool(vysledek2.get("ok", false)),
		"sim.interaction: `interact` na dlazdici s monstrem neni ticha nula (vyslo %s)" % str(vysledek2))

	# -- C) OKNO OBCHODU: hrac ma v UZLECH cestu k PRODEJI -------------------
	var gump_script = Lib.script_at(_arg("vendor-gump-script", VENDOR_GUMP_SCRIPT))
	if gump_script == null:
		t._pending("ui.vendor_gump NENI K DISPOZICI: " + VENDOR_GUMP_SCRIPT)
		return
	var okno = gump_script.new()
	okno.nastav(0, "blacksmith", [{"item": 0x1BF2, "type": "iron_ingot", "name": "iron ingot",
		"amount": 10, "price": 8}], [{"item": 0x0F52, "type": "dagger", "name": "dagger",
		"amount": 1, "price": 10}])
	okno.flush()
	t._check(okno.smer() == "buy",
		"ui.vendor_gump: okno se otevira v NAKUPU (namEReno '%s')" % okno.smer())
	var box = okno.get_node_or_null("Obchod")
	var prepinac = null
	if box != null:
		for uzel in box.get_children():
			if uzel is Button and str(uzel.name).begins_with("Smer"):
				prepinac = uzel
	t._check(prepinac != null,
		"ui.vendor_gump: v UZLECH je tlacitko pro prepnuti smeru (uzlu %d)"
			% (box.get_child_count() if box != null else -1))
	if prepinac != null:
		(prepinac as Button).pressed.emit()
		t._check(okno.smer() == "sell",
			"ui.vendor_gump: kliknuti na tlacitko prepne na PRODEJ (namEReno '%s')" % okno.smer())
		okno.flush()
		var texty: Array = []
		if box != null:
			for uzel in box.get_children():
				if uzel is Button:
					texty.append(str(uzel.text))
		t._check(texty.size() == 3 and str(texty[0]).begins_with("Sell"),
			"ui.vendor_gump: v prodeji je v okne 'Sell' + radek + potvrzeni (texty %s)" % str(texty))
		# A prodej se opravdu posle jako pozadavek (hra z nej dela Command).
		var prodano: bool = false
		if box != null:
			for uzel in box.get_children():
				if uzel is Button and str(uzel.text).contains("dagger"):
					(uzel as Button).pressed.emit()
					prodano = true
		var potvrzeno: bool = okno.stiskni_potvrzeni("sell")
		var pozadavek: Dictionary = okno.odeber_pozadavek()
		t._check(prodano and potvrzeno and str(pozadavek.get("action", "")) == "sell",
			"ui.vendor_gump: kliknuti na radek + potvrzeni posle `{action:'sell'}` (vyslo %s)"
				% str(pozadavek))
	okno.free()

	# -- D) STAVOVY PRUH NELZE: hodnoty se POCITAJI, ne opisuji ---------------
	# `app/main.gd` do session D posilal do stavoveho pruhu `"weight": 0,
	# "gold": 0` NATVRDO (komentar tvrdil "hrac dnes nic nema" - a hrac mel
	# 60 zlata a 16 nastroju). Staticka kontrola tu neni formalita: kdyby se
	# nula vratila, hrac po prodeji neuvidi, ze neco vydelal.
	# ⚠ CTE SE KOD, NE KOMENTARE (docs/09 §9.6 bod 2) - jinak by kontrola
	# prosla i s vracenou vadou, protoze ji popisuje komentar.
	var main_path: String = _arg("main-script", "res://app/main.gd")
	var kod: String = _odstran_komentare(Lib.text_at(main_path))
	t._check(kod != "",
		"app.main: zdroj pro kontrolu stavoveho pruhu jde precist (%s)" % main_path)
	t._check(not kod.contains("\"weight\": 0") and not kod.contains("\"gold\": 0"),
		"app.main: stavovy pruh NEPOSILA natvrdo `weight/gold = 0`")
	t._check(kod.contains("weight_of(") and kod.contains("gold_of("),
		"app.main: stavovy pruh bere vahu z `container.weight_of` a zlato z `vendor.gold_of`")


func _odstran_komentare(text: String) -> String:
	# Vyreze `#`-komentare (i na konci radku), ale NESAHÁ na `#` uvnitr
	# retezce - jinak by kontrola hledala vzor v textu, ktery v kódu neni.
	# Funguje na uvozovky obojiho druhu vcetne escapovani.
	var out: Array[String] = []
	for line in text.split("\n"):
		var v_retezci: bool = false
		var znak_retezce: String = ""
		var konec: int = line.length()
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if v_retezci:
				if c == "\\":
					i += 2
					continue
				if c == znak_retezce:
					v_retezci = false
			elif c == "\"" or c == "'":
				v_retezci = true
				znak_retezce = c
			elif c == "#":
				konec = i
				break
			i += 1
		out.append(line.substr(0, konec))
	return "\n".join(PackedStringArray(out))
