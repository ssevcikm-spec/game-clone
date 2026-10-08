extends RefCounted
# Vyroba, taveni a oprava (granule `sim.craft`; smlouva docs/04 §4.2, pravidla
# docs/05 §5.8, cisla research/04-gathering-crafting.md §6-§7 a zdrojovy kod
# `_src/servuo/Scripts/Services/Craft/`).
#
# ODKUD CISLA (nevymyslena, kazde ma zdroj):
#   * sance na uspech = `floor + (val - min)/(max - min) * (1 - floor)`, kde
#     `floor` je `GetChanceAtMin` systemu; pri `val == max` je to 1.0
#     (`CraftItem.cs:1410-1411`, `:1433-1436`),
#   * `floor` (GetChanceAtMin): BowFletching/Carpentry/Tailoring **0.5**,
#     ostatni 0.0 (`DefBowFletching.cs:61`, `DefCarpentry.cs:83`,
#     `DefTailoring.cs:103-110`);
#   * exceptionalita: `ChanceMinusSixtyToFourtyFive` (offset 0.60 -> 0.45 podle
#     skillu, clamp) pro Blacksmithy, Carpentry, Cooking, Tailoring, Tinkering;
#     `chance*0.5-0.10` pro BowFletching; default `chance-0.60` pro Alchemy,
#     Cartography, Glassblowing, Inscription, Masonry (`CraftItem.cs:1310-1332`),
#   * DVOJITY HOD: `chance = GetSuccessChance(...)` (hod na exceptionalitu),
#     pak zvlast hod na uspech - exceptionalita je z PRVNIHO hodu, uspech
#     z DRUHEHO (`CraftItem.cs:1352-1359`),
#   * neuspech spotrebuje CELY material (u `use_all_res` polovinu, floor 1);
#     vyjimka je 25 typu v `_GlobalNoConsume` (`CraftSystem.cs:268-293`,
#     `CraftItem.cs:1099-1109`),
#   * `use_all_res`: misto `count` se vezme cela hromada - `maxAmount = min(have/need)`
#     (`CraftItem.cs:992-1046`),
#   * znacka vyrobce: `quality == 2` **a** hlavni skill >= 100.0
#     (`CraftItem.cs:2158-2163`); nase `entity.item` pole `maker` NEMA, proto
#     jde do `props["maker"]`,
#   * taveni rudy: 1:1 pro stredni hromadu (0x19B8), malá (0x19B7) pUlí, velka
#     (0x19B9) dvojnasobi; obtiznost podle kovu (iron 50, pak 65..99) a skill
#     gate `difficulty > 50 && Mining < difficulty`; neuspech hromadku pUlí
#     (`Ore.cs:324-437`),
#   * zpetne taveni: `floor(0.66 * puvodni cena v ingotech)`, jen kov a jen
#     predmet, ktery ma `ingot_cost` (nase obdoba `PlayerConstructed`,
#     `Resmelt.cs:113-172`),
#   * oprava: sance oslabit `(40 + (max-cur)) - skill/10` %, obtiznost
#     `((max-cur)*1250/max) - 250` v desetinach, hod `CheckSkill(diff-25, diff+25)`,
#     uspech = plna trvanlivost; oslabeni se aplikuje PRED hodem
#     (`Repair.cs:71-141`, `:288-301`).
#
# ⚠ CO JE NAMERENA ODDYCHLKA OD ZADANI:
#   * `craft()` NEPOUZIVA `skill_gain.check().success` jako uspech - to by bylo
#     spatne: `SKILL_SPAN` je 500 desetin, ale recepty maji spread 50.0 (509x),
#     25.0 (349x) i jiny (194x) - namEReno. Uspech se pocita VLASTNIM vzorcem
#     vyse a `check()` se vola JEN kvuli rustu skillu (pasivni check, ktery
#     reference dela PRED hodem, `CraftItem.cs:1400-1403`),
#   * kvalita `Low (0)` se v referenci z vyroby NEDOSTANE: `quality` startuje
#     na 1 a jedine prirazeni v ceste je `quality = 2`
#     (`CraftItem.cs:1354-1356`; `PlayEndingEffect` sice vetev pro 0 ma, ale
#     nikdo ji nenastavi). Klon proto vyrabi **fail / normal / exceptional**;
#     `quality = 0` zustava v modelu predmetu (loot, budouci zdroje), ale
#     vyroba ho nevyda. Test to MERI (ze 0 nikdy neprijde), ne predpoklada,
#   * `result.tile` je TILEDATA ID a `entity.item.tile` je ART ID -> `+0x4000`
#     (`sim/entity/item.gd:19-23`),
#   * 699 z 1053 receptu nema `tile` u vysledku (namEReno); `craft` na ne vraci
#     `{ok:false, reason:"no_result"}` - nikdy fiktivni tile (docs/06 §6.3),
#   * kovadlina/vyhen se z `world.tiledata` poznat NEDAJI (nema `role`); role
#     bere tenhle modul z `data/items.json` (stejne jako `sim.interaction`),
#   * `repair` nema volajiciho v parove tabulce `sim.interaction` - zatim se
#     vola z testu/sondy; par "nastroj na predmet" do ni nepatri, dokud neni
#     `ui.craft_gump`,
#   * naradi (`-1 use` na pokus) se neopotrebuje: predmet, kterym hrac vyrabi,
#     dostava jen nazev role (`_skill_of_tool`), ne jeho serial. Je to VEDOME
#     omezeni - `entity.equipment` (docs/04 §4.2).
#
# ZAVISLOSTI KONSTRUKTOREM (vzor `sim.skill_gain`): `container` (jedina instance
# sveta!), `items` (`{serial: Item}` nebo objekt s `get_item`), `map`
# (kovadlina/vyhen), `tiledata`, `skill_gain`, `serials`, `rng`, `events`.
# Float je jen v LOKALNIM vypoctu pravdepodobnosti; stav je cely.

const Const = preload("res://core/const.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const RECIPES_PATH := "res://data/recipes.json"
const ITEMS_PATH := "res://data/items.json"
const ITEM_OFFSET := 0x4000
const MAX_MAKE_NUMBER := 100          # "make number" prijima 1-100
const STATION_RANGE := 2              # kovadlina/vyhen do 2 dlazdic (docs/05 §5.8)
const LIFT_RANGE := 2                 # taveni: ruda i vyhen do 2 dlazdic

const SKILL_MINING := 45
const SKILL_BLACKSMITHY := 7
const SKILL_TAILORING := 34
const SKILL_TINKERING := 37

# System vyroby podle `skill` v `data/recipes.json`. `floor` = GetChanceAtMin,
# `eca` = rezim exceptionality, `station` = co musi byt v dosahu, `skill_id` =
# id v `data/skills.json` (Glassblowing jede na Alchemy a Masonry na Carpentry,
# research §6.1).
const SYSTEMS: Dictionary = {
	"Alchemy": {"skill_id": 0, "floor": 0.0, "eca": "minus_sixty", "station": []},
	"Blacksmithy": {"skill_id": 7, "floor": 0.0, "eca": "to_forty_five", "station": ["anvil", "forge"]},
	"BowFletching": {"skill_id": 8, "floor": 0.5, "eca": "half_minus_ten", "station": []},
	"Carpentry": {"skill_id": 11, "floor": 0.5, "eca": "to_forty_five", "station": []},
	"Cartography": {"skill_id": 12, "floor": 0.0, "eca": "minus_sixty", "station": []},
	"Cooking": {"skill_id": 13, "floor": 0.0, "eca": "to_forty_five", "station": []},
	"Glassblowing": {"skill_id": 0, "floor": 0.0, "eca": "minus_sixty", "station": []},
	"Inscription": {"skill_id": 23, "floor": 0.0, "eca": "minus_sixty", "station": []},
	"Masonry": {"skill_id": 11, "floor": 0.0, "eca": "minus_sixty", "station": []},
	"Tailoring": {"skill_id": 34, "floor": 0.5, "eca": "to_forty_five", "station": []},
	"Tinkering": {"skill_id": 37, "floor": 0.0, "eca": "to_forty_five", "station": []},
}

# Recept `skill` -> jmena v `data/skills.json`. `Bowcraft/Fletching` je v
# receptech jako `BowFletching`; Glassblowing a Masonry v `skills.json` NEJSOU
# (jedou na rodicovsky skill, research §6.1) - proto se hledaji pod svym
# systemem, ne pod id.
const SKILL_NAMES: Dictionary = {
	0: ["Alchemy", "Glassblowing"], 7: ["Blacksmithy"], 8: ["BowFletching"],
	11: ["Carpentry", "Masonry"], 12: ["Cartography"], 13: ["Cooking"],
	23: ["Inscription"], 34: ["Tailoring"], 37: ["Tinkering"],
}

# Material, ktery se pri NEUSPECHU nespotrebuje (`_GlobalNoConsume`, 25 typu,
# `CraftSystem.cs:268-288`). V nasich receptech se vyskytuji prevazne v ML
# receptech, ktere stejne nemaji `tile` vysledku - seznam je tu proto, aby se
# pravidlo nezkratilo na "vsechno se spali".
const NO_CONSUME: Array = ["CapturedEssence", "EyeOfTheTravesty", "DiseasedBark",
	"LardOfParoxysmus", "GrizzledBones", "DreadHornMane", "Blight", "Corruption",
	"Muculent", "Scourge", "Putrefaction", "Taint", "MidnightBracers",
	"CrimsonCincture", "GargishCrimsonCincture", "LeurociansMempoOfFortune",
	"LeggingsOfBane", "GauntletsOfNobility", "StaffOfTheMagi", "BlackrockMoonstone",
	"Silver", "RingOfTheElements", "HatOfTheMagi", "AutomatonActuator",
	"AntiqueDocumentsKit"]

# Taveni: obtiznost podle kovu (`Ore.cs:324-353`) a art ingotu. Iron ma
# obtiznost 50 a NEMA skill gate; barevne kovy 65..99.
const METAL_DIFFICULTY: Dictionary = {
	0x000: 50, 0x973: 65, 0x966: 70, 0x96D: 75, 0x972: 80,
	0x8A5: 85, 0x979: 90, 0x89F: 95, 0x8AB: 99,
}
const INGOT_ARTS: Dictionary = {0x000: 0x5BEF, 0x96D: 0x5BE3, 0x8A5: 0x5BE9}
const INGOT_ART_DEFAULT := 0x5BF2      # kanonicky ingot (`Ingots.cs:16`), barvu nese hue
const ORE_ARTS: Array = [0x59B7, 0x59B8, 0x59B9]

const MESSAGE_FAIL := "You fail to create the item, and some of your materials are lost."
const MESSAGE_MATERIALS := "You do not have enough materials to craft that."
const MESSAGE_ANVIL := "You need an anvil and a forge to do this."
const MESSAGE_SMELT_FAIL := "You burn away the impurities but are left with less useable metal."
const MESSAGE_NO_SKILL := "You have no idea how to smelt this strange ore!"
const MESSAGE_TOOL := "You need the right tool in your backpack."

var _container = null
var _items = null                    # {serial: Item} nebo objekt s `get_item`
var _map = null
var _tiledata = null
var _skill_gain = null
var _serials = null
var _rng = null
var _clock = null
var _events = null
var _registry = null

var _recipes: Array = []             # recepty podle id (index == id)
var _by_skill: Dictionary = {}       # jmeno systemu -> Array id
var _role_by_tile: Dictionary = {}   # tiledata id -> role (data/items.json)
var _tile_by_name: Dictionary = {}   # nazev -> tiledata id (data/items.json)
var _made: int = 0


func _init(container = null, items = null, map = null, tiledata = null, skill_gain = null,
		serials = null, rng = null, clock = null, events = null, registry = null) -> void:
	_container = container
	_items = items
	_map = map
	_tiledata = tiledata
	_skill_gain = skill_gain
	_serials = serials
	_rng = rng if rng != null else RngScript.new(0)
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_registry = registry if registry != null else RegistryScript.new()
	_load_items()
	_load_recipes()


# -- rozhrani podle smlouvy ------------------------------------------------

func recipes_for(m: int, skill: int) -> Array[Dictionary]:
	# Seznam receptu pro gump: nedostupny recept je VIDET (`available: false`),
	# ne zmizely (docs/05 §5.8). Recept bez `tile` vysledku ma `craftable: false`.
	var out: Array[Dictionary] = []
	var mob = _mobile(m)
	for jmeno in SKILL_NAMES.get(skill, []):
		for id in _by_skill.get(jmeno, []):
			out.append(_recipe_info(_recipes[id], mob, str(jmeno)))
	return out


func craft(m: int, recipe_id: int, count: int = 1) -> Dictionary:
	# `count` = "make number" (1-100, kazdy pokus je CELY craft vcetne hodu).
	var mob = _mobile(m)
	if mob == null:
		return _fail("no_mobile")
	if recipe_id < 0 or recipe_id >= _recipes.size():
		return _fail("no_recipe")
	var recipe: Dictionary = _recipes[recipe_id]
	var jmeno: String = str(recipe.get("skill", ""))
	if not SYSTEMS.has(jmeno):
		return _fail("no_system")
	var system: Dictionary = SYSTEMS[jmeno]
	var result_tile: int = _tile_of(recipe.get("result", {}))
	if result_tile < 0:
		return _fail("no_result")
	var station: String = _missing_station(mob, system)
	if station != "":
		return _fail(station)
	var materialy: Array = _materials(recipe)
	if materialy.is_empty() or _has_unknown(materialy):
		return _fail("materials")
	var use_all: bool = bool(recipe.get("use_all_res", false))
	var pokusu: int = 1 if use_all else clampi(count, 1, MAX_MAKE_NUMBER)
	var davka: int = 1
	if use_all:
		davka = _max_amount(mob, materialy)
		if davka <= 0:
			return _fail("materials")
	var vysledek: Dictionary = {
		"ok": true, "reason": "", "action": "craft", "recipe": recipe_id,
		"skill": jmeno, "attempts": 0, "made": 0, "quality": 1, "exceptional": false,
		"consumed": [], "item": null, "serial": 0, "gained": false, "chance": 0.0,
	}
	for _pokus in pokusu:
		var hodnota: int = mob.skills.value(int(system["skill_id"]))
		var min_d: int = int(round(float(recipe.get("min_skill", 0.0)) * 10.0))
		var max_d: int = int(round(float(recipe.get("max_skill", 0.0)) * 10.0))
		if max_d < min_d:
			max_d = min_d
		if hodnota < min_d:
			# Recept, na ktery skill nestaci, se ODMITNE a nic nespotrebuje
			# (v gumpu je zesedly, ale videt - docs/05 §5.8).
			return _fail("skill")
		if not _has_materials(mob, materialy, davka):
			# Dostupnost se overuje PRED hodem (reference `ConsumeRes` dela
			# nejdriv suchej beh) - jinak by craft vyrobil predmet z niceho.
			return _fail("materials")
		var sance: float = _chance(system, hodnota, min_d, max_d)
		vysledek["chance"] = sance
		# Pasivni rust skillu jde PRED hodem (reference `CraftItem.cs:1400-1403`).
		if not use_all and _skill_gain != null:
			var rust = _skill_gain.check(m, int(system["skill_id"]), min_d, max_d - min_d)
			if rust is Dictionary and bool(rust.get("gained", false)):
				vysledek["gained"] = true
		var exceptionalni: bool = _rng.chance(_exceptional_chance(system, hodnota, sance))
		var uspech: bool = _rng.chance(sance)
		vysledek["attempts"] = int(vysledek["attempts"]) + 1
		var mnozstvi: int = davka if use_all else 1
		if not uspech:
			# Neuspech spotrebuje CELY material; jen u `use_all_res` polovinu
			# (`CraftItem.cs:2009` + `:1099-1109`).
			vysledek["consumed"] = _consume(mob, materialy, mnozstvi, false, use_all)
			_message(MESSAGE_FAIL)
			vysledek["ok"] = false
			vysledek["reason"] = "failed"
			continue
		vysledek["consumed"] = _consume(mob, materialy, mnozstvi, true, use_all)
		var predmet = _make(mob, recipe, result_tile, exceptionalni, system, hodnota, mnozstvi)
		if predmet == null:
			vysledek["ok"] = false
			vysledek["reason"] = "pack_full"
			continue
		vysledek["made"] = int(vysledek["made"]) + 1
		vysledek["item"] = predmet
		vysledek["serial"] = int(predmet.serial)
		vysledek["quality"] = int(predmet.quality)
		vysledek["exceptional"] = exceptionalni
		_message("You create an exceptional quality item." if exceptionalni else "You create the item.")
	if int(vysledek["made"]) > 0:
		vysledek["ok"] = true
		vysledek["reason"] = ""
	return vysledek


func smelt(m: int, ore: int, forge: int) -> Dictionary:
	# Taveni rudy na ingoty (a zpetne taveni vyrobku, kdyz ma `ingot_cost`).
	var mob = _mobile(m)
	if mob == null:
		return _fail("no_mobile")
	var predmet = _item(ore)
	if predmet == null:
		return _fail("no_ore")
	var vyhen = _item(forge)
	if vyhen == null:
		return _fail("no_forge")
	if not _near(mob, vyhen, LIFT_RANGE):
		return _fail("too_far")
	var hu: int = int(predmet.hue)
	var je_ruda: bool = int(predmet.tile) in ORE_ARTS
	if not je_ruda:
		return _resmelt(mob, predmet)
	var obtiznost: int = int(METAL_DIFFICULTY.get(hu, 50))
	var hodnota: int = mob.skills.value(SKILL_MINING)
	if obtiznost > 50 and hodnota < obtiznost * 10:
		_message(MESSAGE_NO_SKILL)
		return _fail("no_skill")
	var hod = null
	if _skill_gain != null:
		hod = _skill_gain.check(m, SKILL_MINING, (obtiznost - 25) * 10, 500)
	var uspech: bool = bool(hod.get("success", false)) if hod is Dictionary else false
	var mnozstvi: int = int(predmet.amount)
	if not uspech:
		# Neuspech hromadku pUlí (`Ore.cs:433`) - nikdy na nulu.
		var zbyde: int = maxi(1, mnozstvi / 2)
		_odeber(mob, predmet, mnozstvi - zbyde)
		_message(MESSAGE_SMELT_FAIL)
		return {"ok": false, "reason": "failed", "action": "smelt", "ingots": 0,
			"left": zbyde, "gained": bool(hod.get("gained", false)) if hod is Dictionary else false}
	var ingotu: int = mnozstvi
	_odeber(mob, predmet, mnozstvi)
	var art: int = int(INGOT_ARTS.get(hu, INGOT_ART_DEFAULT))
	var ingot = _add(mob, art, ingotu, hu)
	_message("You smelt the ore and get %d ingots." % ingotu)
	return {"ok": true, "reason": "", "action": "smelt", "ingots": ingotu, "left": 0,
		"serial": int(ingot.serial) if ingot != null else 0, "item": ingot,
		"gained": bool(hod.get("gained", false)) if hod is Dictionary else false}


func repair(m: int, tool: int, target: int) -> Dictionary:
	# Oprava predmetu v batohu (`Repair.cs`).
	var mob = _mobile(m)
	if mob == null:
		return _fail("no_mobile")
	var nastroj = _item(tool)
	if nastroj == null:
		return _fail("no_tool")
	var cil = _item(target)
	if cil == null:
		return _fail("no_target")
	if int(cil.parent) != int(mob.backpack):
		return _fail("not_in_pack")
	var skill: int = _skill_of_tool(nastroj)
	if skill < 0:
		return _fail("no_tool")
	var maximum: int = int(cil.max_durability)
	var soucasne: int = int(cil.durability)
	if maximum <= 0:
		return _fail("not_repairable")
	if soucasne >= maximum:
		return _fail("full")
	var hodnota: int = mob.skills.value(skill)
	if maximum <= 1:
		# AoS `toWeaken = 1` (`Repair.cs:317-319`): neni co ubrat.
		return _fail("destroyed")
	# Sance oslabit: `(40 + (max-cur)) - skill/10` % (`Repair.cs:71-95`).
	var sance_oslabit: int = (40 + (maximum - soucasne)) - int(hodnota / 10)
	if _rng.chance(float(sance_oslabit) / 100.0):
		cil.max_durability = maximum - 1
	var obtiznost: int = ((maximum - soucasne) * 1250) / maximum - 250
	var hod = null
	if _skill_gain != null:
		hod = _skill_gain.check(m, skill, obtiznost - 250, 500)
	if hod is Dictionary and bool(hod.get("success", false)):
		cil.durability = int(cil.max_durability)
		_message("You repair the item.")
		return {"ok": true, "reason": "", "action": "repair", "skill": skill,
			"weakened": maximum != int(cil.max_durability),
			"durability": int(cil.durability), "max_durability": int(cil.max_durability)}
	_message("You fail to repair the item.")
	return {"ok": false, "reason": "failed", "action": "repair", "skill": skill,
		"weakened": maximum != int(cil.max_durability),
		"durability": soucasne, "max_durability": int(cil.max_durability)}


# -- mereni (co test a sonda potrebuji videt) ------------------------------

func recipe_count() -> int:
	return _recipes.size()


func chances_for(recipe_id: int, value: int) -> Dictionary:
	# Sance pro dane cislo skillu - aby se dala merit bez hodu.
	if recipe_id < 0 or recipe_id >= _recipes.size():
		return {}
	var recipe: Dictionary = _recipes[recipe_id]
	var system: Dictionary = SYSTEMS.get(str(recipe.get("skill", "")), {})
	if system.is_empty():
		return {}
	var min_d: int = int(round(float(recipe.get("min_skill", 0.0)) * 10.0))
	var max_d: int = int(round(float(recipe.get("max_skill", 0.0)) * 10.0))
	var sance: float = _chance(system, value, min_d, max_d)
	return {"chance": sance, "exceptional_chance": _exceptional_chance(system, value, sance),
		"min_tenths": min_d, "max_tenths": max_d, "floor": float(system.get("floor", 0.0))}


func material_tile(recipe_id: int, index: int = 0) -> int:
	if recipe_id < 0 or recipe_id >= _recipes.size():
		return -1
	var materialy: Array = _materials(_recipes[recipe_id])
	return int(materialy[index]["art"]) if index < materialy.size() else -1


func stats() -> Dictionary:
	return {"recipes": _recipes.size(), "made": _made, "systems": SYSTEMS.size()}


# -- vnitrni: vypocet sanci -------------------------------------------------

func _chance(system: Dictionary, value: int, min_d: int, max_d: int) -> float:
	# `GetChanceAtMin + (val-min)/(max-min) * (1 - GetChanceAtMin)`; pri
	# `val == max` je to 1.0 (`CraftItem.cs:1410-1411`, `:1433-1436`).
	if value < min_d:
		return 0.0            # `allRequiredSkills = false` -> 0.0 a odmitnuti
	if value >= max_d:
		return 1.0
	var floor_chance: float = float(system.get("floor", 0.0))
	if max_d <= min_d:
		return floor_chance
	return floor_chance + (float(value - min_d) / float(max_d - min_d)) * (1.0 - floor_chance)


func _exceptional_chance(system: Dictionary, value: int, chance: float) -> float:
	# `GetExceptionalChance` (`CraftItem.cs:1268-1332`).
	match str(system.get("eca", "minus_sixty")):
		"to_forty_five":
			var offset: float = 0.60 - (float(value) / 10.0 - 95.0) * 0.03
			return chance - clampf(offset, 0.45, 0.60)
		"half_minus_ten":
			return chance * 0.5 - 0.10
	return chance - 0.60


# -- vnitrni: materialy ----------------------------------------------------

func _materials(recipe: Dictionary) -> Array:
	# Materiál se bere podle `tile` z dat (`+0x4000` = art); kdyz `tile` neni,
	# hleda se podle jmena v `data/items.json`. Co se nedohleda, ma `art: -1`
	# a craft vraci `materials` - nikdy fiktivni predmet.
	var out: Array = []
	for m in recipe.get("materials", []):
		if not (m is Dictionary):
			continue
		var tile: int = _tile_of(m)
		out.append({"type": str(m.get("type", "")), "name": str(m.get("name", "")),
			"amount": maxi(1, int(m.get("amount", 1))), "art": (tile + ITEM_OFFSET) if tile >= 0 else -1})
	return out


func _has_materials(mob, materialy: Array, nasobek: int) -> bool:
	for m in materialy:
		if int(m["art"]) < 0:
			return false
		if _count(mob, int(m["art"])) < int(m["amount"]) * nasobek:
			return false
	return true


func _max_amount(mob, materialy: Array) -> int:
	# `use_all_res`: cela hromada = min(have/need) (`CraftItem.cs:992-1021`).
	var maximum: int = -1
	for m in materialy:
		if int(m["art"]) < 0:
			return 0
		var mam: int = _count(mob, int(m["art"]))
		var kus: int = mam / int(m["amount"])
		maximum = kus if maximum < 0 else mini(maximum, kus)
	return maxi(maximum, 0)


func _consume(mob, materialy: Array, nasobek: int, uspech: bool, use_all: bool) -> Array:
	# Vraci, co se opravdu spotrebovalo. Pravidla: uspech = vse; neuspech = vse
	# (krome `NO_CONSUME`), u `use_all_res` polovina s podlahou 1.
	var spotreba: Array = []
	for m in materialy:
		if int(m["art"]) < 0:
			continue
		if not uspech and str(m["type"]) in NO_CONSUME:
			continue
		var chtit: int = int(m["amount"]) * nasobek
		if not uspech and use_all:
			chtit = maxi(1, chtit / 2)
		var vzato: int = _odeber(mob, null, chtit, int(m["art"]))
		spotreba.append({"type": str(m["type"]), "art": int(m["art"]), "amount": vzato})
	return spotreba


func _count(mob, art: int) -> int:
	var soucet: int = 0
	for serial in _contents(int(mob.backpack)):
		var item = _item(serial)
		if item != null and int(item.tile) == art:
			soucet += int(item.amount)
	return soucet


func _odeber(mob, predmet, mnozstvi: int, art: int = -1) -> int:
	# Odebira z batohu; `predmet` (kdyz neni null) ma prednost podle serialu.
	if _container == null or int(mob.backpack) <= 0:
		return 0
	if predmet != null:
		return int(_container.remove(int(mob.backpack), int(predmet.serial), mnozstvi))
	if art < 0:
		return 0
	var zbyva: int = mnozstvi
	for serial in _contents(int(mob.backpack)):
		if zbyva <= 0:
			break
		var item = _item(serial)
		if item == null or int(item.tile) != art:
			continue
		zbyva -= int(_container.remove(int(mob.backpack), int(item.serial), zbyva))
	return mnozstvi - zbyva


func _has_unknown(materialy: Array) -> bool:
	for m in materialy:
		if int(m["art"]) < 0:
			return true
	return false


# -- vnitrni: vyroba predmetu ---------------------------------------------

func _make(mob, recipe: Dictionary, result_tile: int, exceptionalni: bool,
		system: Dictionary, hodnota: int, nasobek: int) -> Object:
	var vysledek: Dictionary = recipe.get("result", {})
	var amount: int = maxi(1, int(vysledek.get("amount", 1))) * nasobek
	var item = _add(mob, result_tile + ITEM_OFFSET, amount, 0)
	if item == null:
		return null
	item.quality = 2 if exceptionalni else 1
	# Značka výrobce: exceptional A ZAKLADNI skill >= 100.0 (`CraftItem.cs:2158-2163`).
	# `entity.item` pole `maker` nema - jde do `props` (a je to zapsane nahore).
	if exceptionalni and hodnota >= 1000:
		item.props["maker"] = int(mob.serial)
	# Cena v ingotech pro zpetne taveni (`Resmelt.cs`): prvni material receptu
	# u kovovych systemu. Jinde by `ingot_cost` tvrdil neco, co neplati.
	var system_skill: int = int(system.get("skill_id", -1))
	if system_skill == SKILL_BLACKSMITHY or system_skill == SKILL_TINKERING:
		var materialy: Array = _materials(recipe)
		if not materialy.is_empty():
			item.props["ingot_cost"] = int(materialy[0]["amount"]) * nasobek
	_made += 1
	return item


func _add(mob, art: int, amount: int, hue: int):
	if _container == null or _serials == null or int(mob.backpack) <= 0:
		_message(MESSAGE_MATERIALS)
		return null
	var item = ItemScript.new(int(_serials.next_serial()), art, amount)
	item.hue = hue
	item.pos = Vector3i(int(mob.pos.x), int(mob.pos.y), int(mob.pos.z))
	if not _container.add(int(mob.backpack), item):
		_message("Your backpack cannot hold anything else.")
		return null
	if _items is Dictionary:
		_items[int(item.serial)] = item
	return item


func _resmelt(mob, predmet) -> Dictionary:
	# Zpetne taveni vyrobku: `floor(0.66 * cena v ingotech)` (`Resmelt.cs:169-172`).
	var cena: int = int(predmet.props.get("ingot_cost", 0))
	if cena < 2:
		return _fail("not_metal")
	var hu: int = int(predmet.hue)
	var obtiznost: int = int(METAL_DIFFICULTY.get(hu, 50))
	var skill: int = maxi(mob.skills.value(SKILL_MINING), mob.skills.value(SKILL_BLACKSMITHY))
	if obtiznost > 0 and skill < obtiznost * 10:
		return _fail("no_skill")
	var ingotu: int = int(float(cena) * 0.66)
	_odeber(mob, predmet, int(predmet.amount))
	var ingot = _add(mob, int(INGOT_ARTS.get(hu, INGOT_ART_DEFAULT)), ingotu, hu)
	return {"ok": true, "reason": "", "action": "resmelt", "ingots": ingotu, "left": 0,
		"serial": int(ingot.serial) if ingot != null else 0, "item": ingot}


# -- vnitrni: stanice, naradi, data ---------------------------------------

func _missing_station(mob, system: Dictionary) -> String:
	var potreba: Array = system.get("station", [])
	if potreba.is_empty():
		return ""
	for role in potreba:
		if not _station_near(mob, str(role)):
			return str(role)     # "anvil" nebo "forge" (docs/05 §5.8)
	return ""


func _station_near(mob, role: String) -> bool:
	# Kovadlina/vyhen: (1) STATIKY v mape (role z `data/items.json`, protoze
	# `world.tiledata` `role` nema - stejne jako `sim.interaction`),
	# (2) PREDMETY, ktere svet drzi v `_items` - server ma kovadlinu jako
	# PREDMET (`map.statics_at` je klientsky obraz sveta) a bez tehle vetve by
	# v mape, kde kovadlina jako statik neni, neslo vyrabet vubec.
	if _map != null and _map.has_method("statics_at"):
		var x: int = int(mob.pos.x)
		var y: int = int(mob.pos.y)
		for dx in range(-STATION_RANGE, STATION_RANGE + 1):
			for dy in range(-STATION_RANGE, STATION_RANGE + 1):
				var tx: int = x + dx
				var ty: int = y + dy
				var lokalni_x: int = tx % Const.BLOCK_SIZE
				var lokalni_y: int = ty % Const.BLOCK_SIZE
				for s in _map.statics_at(tx, ty):
					if int(s.get("x", -1)) != lokalni_x or int(s.get("y", -1)) != lokalni_y:
						continue
					if _role_of_tile(int(s["tile"])) == role:
						return true
	if _items is Dictionary:
		for serial in _items:
			var item = _items[serial]
			if item != null and _role_of_tile(int(item.tile)) == role \
					and _near(mob, item, STATION_RANGE):
				return true
	return false


func _role_of_tile(tile: int) -> String:
	# Static muze byt v tiledata prostoru i v art prostoru - zkusi se oba.
	if _role_by_tile.has(tile):
		return str(_role_by_tile[tile])
	if tile >= ITEM_OFFSET and _role_by_tile.has(tile - ITEM_OFFSET):
		return str(_role_by_tile[tile - ITEM_OFFSET])
	return ""


func _skill_of_tool(nastroj) -> int:
	var role: String = _role_of_tile(int(nastroj.tile))
	match role:
		"smith hammer", "tongs":
			return SKILL_BLACKSMITHY
		"sewing kit", "scissors":
			return SKILL_TAILORING
		"tinker tools", "saw":
			return SKILL_TINKERING
	return -1


func _near(mob, item, range_max: int) -> bool:
	return absi(int(mob.pos.x) - int(item.pos.x)) <= range_max \
		and absi(int(mob.pos.y) - int(item.pos.y)) <= range_max


func _tile_of(spec) -> int:
	if not (spec is Dictionary):
		return -1
	if spec.has("tile") and int(spec["tile"]) > 0:
		return int(spec["tile"])
	var jmeno: String = str(spec.get("name", "")).to_lower()
	if _tile_by_name.has(jmeno):
		return int(_tile_by_name[jmeno])
	return -1


func _recipe_info(recipe: Dictionary, mob, jmeno: String) -> Dictionary:
	var min_d: int = int(round(float(recipe.get("min_skill", 0.0)) * 10.0))
	var max_d: int = int(round(float(recipe.get("max_skill", 0.0)) * 10.0))
	var hodnota: int = 0 if mob == null else int(mob.skills.value(int(SYSTEMS[jmeno]["skill_id"])))
	var materialy: Array = _materials(recipe)
	var result_tile: int = _tile_of(recipe.get("result", {}))
	var znane: bool = result_tile >= 0
	for m in materialy:
		if int(m["art"]) < 0:
			znane = false
	return {"id": int(recipe.get("id", -1)), "skill": jmeno, "type": str(recipe.get("type", "")),
		"group": str(recipe.get("group", "")), "name": str(recipe.get("result", {}).get("name", "")),
		"min_skill": min_d, "max_skill": max_d, "materials": materialy,
		"result_tile": result_tile, "use_all_res": bool(recipe.get("use_all_res", false)),
		"available": hodnota >= min_d, "craftable": znane,
		"chance": _chance(SYSTEMS[jmeno], hodnota, min_d, max_d)}


func _load_recipes() -> void:
	if not FileAccess.file_exists(RECIPES_PATH):
		push_warning("sim.craft: chybi " + RECIPES_PATH + " - vyroba nebude fungovat")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RECIPES_PATH))
	if not (parsed is Array):
		push_warning("sim.craft: " + RECIPES_PATH + " neni seznam")
		return
	for rec in parsed:
		if not (rec is Dictionary):
			continue
		var id: int = int(rec.get("id", -1))
		if id < 0:
			continue
		while _recipes.size() <= id:
			_recipes.append({})
		_recipes[id] = rec
		var jmeno: String = str(rec.get("skill", ""))
		if not _by_skill.has(jmeno):
			_by_skill[jmeno] = []
		_by_skill[jmeno].append(id)


func _load_items() -> void:
	# `role` a jmeno -> tiledata id (kovadlina, vyhen, nastroje, materialy).
	if not FileAccess.file_exists(ITEMS_PATH):
		push_warning("sim.craft: chybi " + ITEMS_PATH + " - role kovadliny/vyhne nebudou")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not (parsed is Array):
		push_warning("sim.craft: " + ITEMS_PATH + " neni seznam")
		return
	for rec in parsed:
		if not (rec is Dictionary) or not rec.has("tile"):
			continue
		var tile: int = int(rec["tile"])
		var role: String = str(rec.get("role", ""))
		if role != "":
			_role_by_tile[tile] = role
		var jmeno: String = str(rec.get("name", "")).replace("%s", "").to_lower().strip_edges()
		if jmeno != "" and not _tile_by_name.has(jmeno):
			_tile_by_name[jmeno] = tile


func _recipe_by_id(id: int) -> Dictionary:
	return _recipes[id] if id >= 0 and id < _recipes.size() else {}


# -- vnitrni: zaklad -------------------------------------------------------

func _contents(c: int) -> Array:
	if _container == null:
		return []
	return _container.contents(c)


func _item(serial: int):
	if _items == null or serial <= 0:
		return null
	if _items is Dictionary:
		return _items.get(serial)
	if _items is Object and _items.has_method("get_item"):
		return _items.get_item(serial)
	return null


func _mobile(m: int):
	return _registry.get_mobile(m)


func _fail(reason: String) -> Dictionary:
	# "Nic se nestalo" musi byt VIDET (hlaska), ale jen u duvodu, ktere
	# nehlasi volajici sam (`smelt`/`repair` si hlasku posilaji samy).
	match reason:
		"anvil", "forge":
			_message(MESSAGE_ANVIL)
		"materials":
			_message(MESSAGE_MATERIALS)
		"skill":
			_message("You don't have the required skills to attempt this item.")
		"no_result":
			_message("You don't know how to make that item yet.")
	return {"ok": false, "reason": reason, "action": "", "attempts": 0, "made": 0}


func _message(text: String) -> void:
	if _events != null:
		_events.push("message", {"text": text, "kind": "craft"})
