extends RefCounted
# S1b - CESTA K DATUM JE PARAMETR, ne zapeena konstanta (NAVRH-MODDING §4 S1b).
#
# Co tenhle case meri (a cim): u kazde z 9 modulovych konstant, ktere driv
# cetly cestu PRIMO z konstanty, se modul postavi s JINOU cestou (fixture
# v `user://`) a overi se, ze soubor OPRAVDU vzal odtud. Staticka metrika
# (`tools/check-data-paths.py`) je jen orientacni - chovani meri tenhle
# case (docs/09 §9.4: "brana, ktera se pta na pritomnost, nemeri chovani").
#
# KAZDA kontrola ma dve strany: fixture se MUSI projevit A ZAKLAD se od ni
# musi lisit. Kdyby modul cetl konstantu, fixture by se neprojevila - a kdyby
# zaklad nahodou obsahoval tyz zaznam, "projevilo se to" by nic nedokazalo.
#
# Fixture se pisi do `user://test-content-paths` (ne do produktovych dat) a na
# konci se uklidi; staticka cache `sim.entity.item` se vrati na zaklad.

const Lib = preload("res://tests/lib.gd")
const DIR := "user://test-content-paths"
const ITEM_OFFSET := 0x4000

# Klicova id fixture: jsou zamerne MIMO realna data (art 1234 neni v UO artu
# na zadne pouzite dlazdici; kategorie dveri 9 a schodu 3 s temito arty ne).
const FX_TILE := 1234
const FX_DOOR_ART := 100
const FX_STAIR_ART := 555


func run(t) -> void:
	_smaz(DIR)

	var fx_items: String = DIR + "/items.json"
	var fx_skills: String = DIR + "/skills.json"
	var fx_recipes: String = DIR + "/recipes.json"
	var fx_balance: String = DIR + "/balance.json"
	var fx_doors: String = DIR + "/doors.json"
	var fx_stairs: String = DIR + "/stairs.json"

	t._check(_zapis(fx_items,
		'[{"tile": %d, "type": "mod_ore", "role": "ore", "category": "resource", "name": "mod ingot", "value": 7}]'
			% FX_TILE),
		"fixture: items.json (mod) zapsan")
	t._check(_zapis(fx_skills, '[{"id": 7, "name": "ModSkill"}]'),
		"fixture: skills.json (mod) zapsan")
	t._check(_zapis(fx_recipes,
		'[{"id": 0, "skill": "Blacksmithy", "result": {"name": "mod vec", "tile": 3900}, "materials": [{"name": "mod ingot", "amount": 1}]}]'),
		"fixture: recipes.json (mod) zapsan")
	t._check(_zapis(fx_balance,
		'{"ggs_on": true, "era": {"skill_gain": "pre-aos"}, "stat_gain": {"delay_ms": 1234, "chance_percent": 7}}'),
		"fixture: balance.json (mod) zapsan")
	t._check(_zapis(fx_doors,
		'{"rows": [{"category": 9, "comment": "MOD", "piece1": %d, "piece2": 0, "piece3": 0, "piece4": 0, "piece5": 0, "piece6": 0, "piece7": 0, "piece8": 0}]}'
			% FX_DOOR_ART),
		"fixture: doors.json (mod) zapsan")
	t._check(_zapis(fx_stairs,
		'{"rows": [{"category": 3, "comment": "MOD", "North": %d}]}' % FX_STAIR_ART),
		"fixture: stairs.json (mod) zapsan")

	# -- 1) data/items.json -> sim.entity.item -----------------------------
	var ItemScript = Lib.script_at("res://sim/entity/item.gd")
	if ItemScript == null:
		t._pending("S1b: sim/entity/item.gd NELZE NACIST (parse error?)")
	else:
		ItemScript.reset_data()
		t._check(ItemScript.nacti_data(fx_items),
			"S1b items: modul nacetl fixture (vraci true)")
		t._check(ItemScript.loaded_path() == fx_items,
			"S1b items: `loaded_path()` je FIXTURE, ne konstanta (namEReno '%s')"
				% ItemScript.loaded_path())
		t._check(ItemScript.type_of(FX_TILE + ITEM_OFFSET) == "mod_ore",
			"S1b items: typ z fixture je videt (namEReno '%s')"
				% ItemScript.type_of(FX_TILE + ITEM_OFFSET))
		# Uklid: cache je pro cely proces, takze se MUSI vratit zaklad.
		ItemScript.reset_data()
		t._check(ItemScript.nacti_data(), "S1b items: zaklad se nacte znovu (uklid)")
		t._check(ItemScript.loaded_path() == "res://data/items.json",
			"S1b items: po uklidu je cesta zakladni (namEReno '%s')" % ItemScript.loaded_path())
		t._check(ItemScript.type_of(FX_TILE + ITEM_OFFSET) == "",
			"S1b items: v ZAKLADE ten art typ nema - fixture se nepletla se zakladem")

	# -- 2) data/skills.json -> sim.entity.skills --------------------------
	var SkillsScript = Lib.script_at("res://sim/entity/skills.gd")
	if SkillsScript == null:
		t._pending("S1b: sim/entity/skills.gd NELZE NACIST (parse error?)")
	else:
		var sk_fx = SkillsScript.new(1, fx_skills)
		t._check(sk_fx.data_skill_count() == 1,
			"S1b skills: z fixture nactl 1 skill (namEReno %d)" % sk_fx.data_skill_count())
		var sk_zaklad = SkillsScript.new()
		t._check(sk_zaklad.data_skill_count() == 58,
			"S1b skills: ze zakladu nactl 58 skillu (namEReno %d)" % sk_zaklad.data_skill_count())

	# -- 3) data/recipes.json + data/items.json -> sim.systems.craft -------
	var CraftScript = Lib.script_at("res://sim/systems/craft.gd")
	if CraftScript == null:
		t._pending("S1b: sim/systems/craft.gd NELZE NACIST (parse error?)")
	else:
		var c_fx = CraftScript.new(null, null, null, null, null, null, null, null, null, null,
			fx_recipes, fx_items)
		t._check(c_fx.recipe_count() == 1,
			"S1b craft: z fixture receptu je 1 recept (namEReno %d)" % c_fx.recipe_count())
		t._check(c_fx.material_tile(0, 0) == FX_TILE + ITEM_OFFSET,
			"S1b craft: material se dohledal v items FIXTURE (art %d, ocekavano %d)"
				% [c_fx.material_tile(0, 0), FX_TILE + ITEM_OFFSET])
		var c_zaklad = CraftScript.new()
		t._check(c_zaklad.recipe_count() > 100,
			"S1b craft: zaklad ma vic nez 100 receptu (namEReno %d)" % c_zaklad.recipe_count())
		t._check(c_zaklad.material_tile(0, 0) != FX_TILE + ITEM_OFFSET,
			"S1b craft: v zaklade se material z fixture NENAJDE (art %d)"
				% c_zaklad.material_tile(0, 0))

	# -- 4) data/skills.json -> sim.systems.interaction --------------------
	var InteractionScript = Lib.script_at("res://sim/systems/interaction.gd")
	if InteractionScript == null:
		t._pending("S1b: sim/systems/interaction.gd NELZE NACIST (parse error?)")
	else:
		var i_fx = InteractionScript.new(null, null, null, null, null, null, fx_skills)
		t._check(i_fx.skill_id("ModSkill") == 7,
			"S1b interaction: skill z fixture ma id 7 (namEReno %d)" % i_fx.skill_id("ModSkill"))
		var i_zaklad = InteractionScript.new()
		t._check(i_zaklad.skill_id("ModSkill") == -1,
			"S1b interaction: v zaklade `ModSkill` NENI (namEReno %d)"
				% i_zaklad.skill_id("ModSkill"))

	# -- 5) data/balance.json -> sim.systems.skill_gain --------------------
	var SkillGainScript = Lib.script_at("res://sim/systems/skill_gain.gd")
	if SkillGainScript == null:
		t._pending("S1b: sim/systems/skill_gain.gd NELZE NACIST (parse error?)")
	else:
		var sg_fx = SkillGainScript.new(null, null, null, null, fx_balance)
		var st: Dictionary = sg_fx.stats()
		t._check(int(st["stat_delay_ms"]) == 1234 and int(st["stat_chance_percent"]) == 7,
			"S1b skill_gain: hodnoty z fixture (delay %d, chance %d)"
				% [int(st["stat_delay_ms"]), int(st["stat_chance_percent"])])
		t._check(absf(float(st["failure_weight"]) - 0.2) < 0.0001,
			"S1b skill_gain: `era.skill_gain = pre-aos` z fixture (vaha %.3f)"
				% float(st["failure_weight"]))
		var sg_zaklad = SkillGainScript.new()
		var st2: Dictionary = sg_zaklad.stats()
		t._check(int(st2["stat_delay_ms"]) != 1234 and int(st2["stat_chance_percent"]) != 7,
			"S1b skill_gain: v zaklade hodnoty z fixture NEJSOU (delay %d, chance %d)"
				% [int(st2["stat_delay_ms"]), int(st2["stat_chance_percent"])])

	# -- 6) data/doors.json -> sim.world.doors -----------------------------
	var DoorsScript = Lib.script_at("res://sim/world/doors.gd")
	if DoorsScript == null:
		t._pending("S1b: sim/world/doors.gd NELZE NACIST (parse error?)")
	else:
		var d_fx = DoorsScript.new(fx_doors)
		t._check(d_fx.category_count() == 1,
			"S1b doors: z fixture je 1 kategorie dveri (namEReno %d)" % d_fx.category_count())
		t._check(d_fx.is_door(FX_DOOR_ART),
			"S1b doors: art %d je z fixture dvere" % FX_DOOR_ART)
		t._check(d_fx.name_of(0) == "MOD",
			"S1b doors: prvni kategorie je z fixture (nazev '%s')" % d_fx.name_of(0))
		var d_zaklad = DoorsScript.new()
		t._check(not d_zaklad.is_door(FX_DOOR_ART),
			"S1b doors: v zaklade art %d dvere NEJSOU" % FX_DOOR_ART)

	# -- 7) data/stairs.json -> sim.world.stairs ---------------------------
	var StairsScript = Lib.script_at("res://sim/world/stairs.gd")
	if StairsScript == null:
		t._pending("S1b: sim/world/stairs.gd NELZE NACIST (parse error?)")
	else:
		var st_fx = StairsScript.new(fx_stairs)
		t._check(st_fx.group_count() == 1,
			"S1b stairs: z fixture je 1 skupina schodu (namEReno %d)" % st_fx.group_count())
		t._check(st_fx.is_stair(FX_STAIR_ART) and st_fx.role(FX_STAIR_ART) == "North",
			"S1b stairs: art %d je z fixture schod s roli '%s'"
				% [FX_STAIR_ART, st_fx.role(FX_STAIR_ART)])
		var st_zaklad = StairsScript.new()
		t._check(not st_zaklad.is_stair(FX_STAIR_ART),
			"S1b stairs: v zaklade art %d schod NENI" % FX_STAIR_ART)

	# -- 8) data/items.json -> sim.world.tiledata (hodnoty predmetu) -------
	var TiledataScript = Lib.script_at("res://sim/world/tiledata.gd")
	if TiledataScript == null:
		t._pending("S1b: sim/world/tiledata.gd NELZE NACIST (parse error?)")
	else:
		var td_fx = TiledataScript.new(fx_items)
		t._check(td_fx.value(FX_TILE + ITEM_OFFSET) == 7,
			"S1b tiledata: hodnota z fixture (namEReno %d)" % td_fx.value(FX_TILE + ITEM_OFFSET))
		var td_zaklad = TiledataScript.new()
		t._check(td_zaklad.value(FX_TILE + ITEM_OFFSET) != 7,
			"S1b tiledata: v zaklade hodnota z fixture NENI (namEReno %d)"
				% td_zaklad.value(FX_TILE + ITEM_OFFSET))

	# -- uklid -------------------------------------------------------------
	if ItemScript != null:
		ItemScript.reset_data()
		ItemScript.nacti_data()
	_smaz(DIR)
	t._check(not DirAccess.dir_exists_absolute(DIR),
		"S1b: fixture po testu v `user://` nezustala")


func _zapis(cesta: String, text: String) -> bool:
	var idx: int = cesta.rfind("/")
	if idx > 0:
		DirAccess.make_dir_recursive_absolute(cesta.substr(0, idx))
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _smaz(cesta: String) -> void:
	var d := DirAccess.open(cesta)
	if d == null:
		return
	for jmeno in d.get_files():
		DirAccess.remove_absolute(cesta + "/" + str(jmeno))
	for jmeno in d.get_directories():
		_smaz(cesta + "/" + str(jmeno))
	DirAccess.remove_absolute(cesta)
