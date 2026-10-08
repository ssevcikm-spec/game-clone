extends RefCounted
# IDENTITA PREDMETU: `type` (20. session, rozhodnuti uzivatele "typ je identita,
# art je jeho projev").
#
# Co se tu meri - a proc zrovna takhle:
#   1. DATA: kazdy zaznam ma `type`; jeden typ = jedna role a jedna kategorie;
#      plural se nesmi rozpadnout na dva typy (`board%s` vs `boards`);
#   2. `sim/entity/item.gd`: `type_of`/`role_of`/`arts_of`, `Item.type`,
#      `same_pile` = TYP + hue (art se u tehoz predmetu meni);
#   3. ZISK CELY ZMENY: recept najde material i tehdy, kdyz hrac ma JEHO JINY ART
#      (do 20. session se parovalo podle artu, takze se hromada s jinou grafikou
#      do receptu NEPOCITALA). To je jedina cast, ktera se neda dokazat nad daty -
#      proto se tu pousti REALNY `sim.craft.craft()` pres realne recepty.
#
# Cesta k merenym modulum je VSTUP (mutacni harness): `-- --item-script=`,
# `-- --craft-script=`.

const Lib = preload("res://tests/lib.gd")
const SimScript = preload("res://sim/sim_world.gd")
const ContainerScript = preload("res://sim/entity/container.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const ITEM_SCRIPT := "res://sim/entity/item.gd"
const CRAFT_SCRIPT := "res://sim/systems/craft.gd"
const ITEMS_DATA := "res://data/items.json"
const RECIPES_DATA := "res://data/recipes.json"
const PACK := 0x00000099
const SERIAL := 0x40000042
const POKUSU_MAX := 30        # kolikrat zkusit vyrobit (RNG je deterministicky)


class StubTiledata:
	func weight(_tile: int) -> int:
		return 1

	func flags(_tile: int) -> int:
		return 0


class StubSkill:
	func check(_m: int, _skill: int, _difficulty: int, _span: int = -1) -> Dictionary:
		return {"success": true, "gained": false, "new_value": 0, "reason": ""}


class StubMap:
	func land_at(_x: int, _y: int) -> int:
		return 9999

	func statics_at(_x: int, _y: int) -> Array:
		return []


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _sestav_craft(t, item_script) -> Dictionary:
	# Craft + mobil + kontejner; vse realne (jen `tiledata` je stub, aby vaha
	# nezavislela na assetech). Vraci {} = NEMERENO (a to je selhani).
	var craft_script = Lib.script_at(_arg("craft-script", CRAFT_SCRIPT))
	if craft_script == null:
		t._pending("sim.craft NENI K DISPOZICI: " + CRAFT_SCRIPT)
		return {}
	var sim = SimScript.new(1234, {})
	var mob = MobileScript.new(SERIAL, 400, Vector3i(100, 100, 0))
	mob.backpack = PACK
	mob.skills.set_value(7, 1000)      # Blacksmithy
	mob.skills.set_value(11, 1000)     # Carpentry
	mob.skills.set_value(37, 1000)     # Tinkering
	var registry = RegistryScript.new()
	registry.register(mob)
	var container = ContainerScript.new(StubTiledata.new())
	var items: Dictionary = {}
	var craft = craft_script.new(container, items, StubMap.new(), true, StubSkill.new(),
		sim, sim.rng(), sim.clock(), sim.events(), registry)
	return {"craft": craft, "sim": sim, "mob": mob, "container": container, "items": items}


func _pridej(sestava, item_script, art: int, amount: int = 1):
	var item = item_script.new(sestava["sim"].next_serial(), art, amount)
	if not sestava["container"].add(PACK, item):
		return null
	sestava["items"][int(item.serial)] = item
	return item


func _vyber_recept(t, craft, item_script) -> Dictionary:
	# Recept, na kterem jde dokazat zisk: stanice zadna (system `station: []`),
	# vysledek ma art, VSECHNY materialy maji `item_type` a aspon jeden material
	# ma typ s VIC ARTY (jinak by "jiny art" nebylo co vzit).
	var systems: Dictionary = Lib.consts_at(_arg("craft-script", CRAFT_SCRIPT)).get("SYSTEMS", {})
	var recepty = Lib.json_at(RECIPES_DATA)
	if not (recepty is Array):
		t._pending("data/recipes.json nejde precist")
		return {}
	for i in recepty.size():
		var r: Dictionary = recepty[i]
		var system: Dictionary = systems.get(str(r.get("skill", "")), {})
		if system.is_empty() or not (system.get("station", []) as Array).is_empty():
			continue
		if not (r.get("result", {}) is Dictionary) or not r["result"].has("tile"):
			continue
		var mat: Array = r.get("materials", [])
		if mat.is_empty():
			continue
		var vsechny_typy: bool = true
		var ma_vic_artu: bool = false
		for m in mat:
			if not (m is Dictionary) or str(m.get("item_type", "")) == "":
				vsechny_typy = false
				break
			if item_script.arts_of(str(m["item_type"])).size() > 1:
				ma_vic_artu = true
		if vsechny_typy and ma_vic_artu:
			return {"id": i, "recipe": r}
	return {}


func run(t) -> void:
	var item_script = Lib.script_at(_arg("item-script", ITEM_SCRIPT))
	if item_script == null:
		t._pending("sim.entity.item NENI K DISPOZICI: " + ITEM_SCRIPT)
		return

	# -- 1) DATA: typ je vsude, jeden typ = jedna role/kategorie -------------
	var data = Lib.json_at(ITEMS_DATA)
	if not (data is Array):
		t._pending("data/items.json nejde precist")
		return
	var bez_typu: int = 0
	var role_podle_typu: Dictionary = {}
	var kat_podle_typu: Dictionary = {}
	var typy: Dictionary = {}
	var arty_podle_typu: Dictionary = {}
	for rec in data:
		if not (rec is Dictionary):
			continue
		var typ: String = str(rec.get("type", ""))
		if typ == "":
			bez_typu += 1
			continue
		typy[typ] = true
		arty_podle_typu[typ] = int(arty_podle_typu.get(typ, 0)) + 1
		var role: String = str(rec.get("role", ""))
		if role != "" and role_podle_typu.has(typ) and str(role_podle_typu[typ]) != role:
			role_podle_typu[typ] = "ROZPOR:" + role
		elif role != "":
			role_podle_typu[typ] = role
		var kat: String = str(rec.get("category", ""))
		if kat != "" and kat_podle_typu.has(typ) and str(kat_podle_typu[typ]) != kat:
			kat_podle_typu[typ] = "ROZPOR:" + kat
		elif kat != "":
			kat_podle_typu[typ] = kat
	t._check(bez_typu == 0, "data.items: kazdy zaznam ma `type` (bez nej: %d)" % bez_typu)
	var rozpory: Array = []
	for typ in role_podle_typu.keys():
		if str(role_podle_typu[typ]).begins_with("ROZPOR:"):
			rozpory.append(typ)
	for typ in kat_podle_typu.keys():
		if str(kat_podle_typu[typ]).begins_with("ROZPOR:") and not rozpory.has(typ):
			rozpory.append(typ)
	t._check(rozpory.is_empty(),
		"data.items: jeden typ = jedna role a jedna kategorie (rozporu: %d, %s)"
			% [rozpory.size(), str(rozpory.slice(0, 5))])
	# Plural nesmi rozdelit jednu vec na dva typy (`board%s` vs `boards`).
	var rozdelene: Array = []
	for typ in typy.keys():
		if str(typ).ends_with("s") and typy.has(str(typ).substr(0, str(typ).length() - 1)):
			rozdelene.append(typ)
	t._check(rozdelene.is_empty(),
		"data.items: plural nedeli typ na dva (`X` a `Xs`) - rozdelene: %s" % str(rozdelene.slice(0, 5)))
	t._check(int(arty_podle_typu.get("iron_ore", 0)) >= 4,
		"data.items: typ `iron_ore` ma vsechny 4 arty rudy (namEReno %d)"
			% int(arty_podle_typu.get("iron_ore", 0)))
	t._check(int(arty_podle_typu.get("board", 0)) > 1 and not typy.has("boards"),
		"data.items: `board` je jeden typ s vic arty a `boards` uz neexistuje (artu %d)"
			% int(arty_podle_typu.get("board", 0)))

	# -- 2) ENTITA: typ z artu, role z typu, slucovani podle typu ------------
	var ore_art: int = int(item_script.arts_of("iron_ore")[0])
	t._check(str(item_script.type_of(ore_art)) == "iron_ore"
			and str(item_script.role_of(ore_art)) == "iron ore",
		"entity.item: art 0x%04X -> typ '%s' -> role '%s'"
			% [ore_art, str(item_script.type_of(ore_art)), str(item_script.role_of(ore_art))])
	var arty: Array = item_script.arts_of("iron_ore")
	var role_vsech: Array = []
	for art in arty:
		role_vsech.append(str(item_script.role_of(int(art))))
	t._check(role_vsech.size() >= 4 and role_vsech.all(func(r): return r == "iron ore"),
		"entity.item: VSECHNY arty rudy maji roli 'iron ore' (namEReno %s)" % str(role_vsech))
	var a = item_script.new(1, int(arty[0]), 3)
	var b = item_script.new(2, int(arty[arty.size() - 1]), 2)
	t._check(str(a.type) == "iron_ore" and str(b.type) == "iron_ore"
			and a.same_pile(b) and b.same_pile(a),
		"entity.item: hromady tehoz typu s JINYM artem se sliji (art %d vs %d, typ '%s')"
			% [a.tile, b.tile, a.type])
	a.hue = 0x973
	b.hue = 0x973
	t._check(a.same_pile(b), "entity.item: stejna hue u ruznych artu = slouci se")
	b.hue = 0x966
	t._check(not a.same_pile(b),
		"entity.item: jina hue (jiny kov) se NESLUCUJE (namEReno %d vs %d)" % [a.hue, b.hue])

	# -- 3) ZISK: recept najde material podle TYPU, ne podle artu ----------
	var sestava := _sestav_craft(t, item_script)
	if sestava.is_empty():
		return
	var vyber: Dictionary = _vyber_recept(t, sestava["craft"], item_script)
	if vyber.is_empty():
		t._pending("nenasel se recept bez stanice s materialy, ktere maji `item_type` a vic artu")
		return
	var recept: Dictionary = vyber["recipe"]
	# Skill se nastavuje AZ PODLE VYBRANEHO RECEPTU: system ma vlastni `skill_id`
	# (Alchemy 0, Carpentry 11, Tinkering 37...) a bez toho by craft vratil
	# `skill` - coz je spravne chovani, ale test by pak nemeril to, co ma.
	var systems_vse: Dictionary = Lib.consts_at(_arg("craft-script", CRAFT_SCRIPT)).get("SYSTEMS", {})
	var vybrany_system: Dictionary = systems_vse.get(str(recept.get("skill", "")), {})
	sestava["mob"].skills.set_value(int(vybrany_system.get("skill_id", 0)), 1000)
	var jine_arty: Array = []
	for m in recept["materials"]:
		var typ: String = str(m["item_type"])
		var kandidati: Array = item_script.arts_of(typ)
		var jiny: int = int(m["tile"]) + 0x4000
		for art in kandidati:
			if int(art) != int(m["tile"]) + 0x4000:
				jiny = int(art)
				break
		jine_arty.append({"typ": typ, "art": jiny, "puvodni": int(m["tile"]) + 0x4000})
	var uspech: bool = false
	var vysledek: Dictionary = {}
	for pokus in POKUSU_MAX:
		for m in jine_arty:
			_pridej(sestava, item_script, int(m["art"]), int(recept["materials"][0].get("amount", 1)))
		vysledek = sestava["craft"].craft(SERIAL, int(vyber["id"]), 1)
		if bool(vysledek.get("ok", false)) and int(vysledek.get("made", 0)) > 0:
			uspech = true
			break
	t._check(uspech,
		"sim.craft: recept '%s' (#%d) se vyrobi z materialu s JINYM artem tehoz typu (%s) - do 20. session se parovalo podle artu a vyslo '%s'"
			% [str(recept.get("result", {}).get("name", "?")), int(vyber["id"]),
				str(jine_arty), str(vysledek.get("reason", ""))])
	if uspech:
		var predmet = vysledek.get("item")
		var cekany: String = str(recept["result"].get("item_type", ""))
		t._check(predmet != null and cekany != "" and str(predmet.type) == cekany,
			"sim.craft: vyrobek ma typ z receptu ('%s', namEReno '%s')"
				% [cekany, str(predmet.type) if predmet != null else "?"])
