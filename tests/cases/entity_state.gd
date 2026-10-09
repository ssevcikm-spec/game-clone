extends RefCounted
# entity.mobile + sim.entity_registry jako STAVOVY ZDROJ (granule `sim.offline`, MK).
#
# Kriterium: stav mobila (a tim i registry) se da vypsat, prenest pres JSON
# a vratit PRESNE - vcetne toho, ze se dostane do `state_hash()` a do save.
# Do 2026-10-09 se mobily neukladaly vubec (`sim/save.gd` to mel pojmenovane).
#
# ⚠ Co tenhle case NEMERI: predmety (`entity.item`, `entity.container`) - ty
# stavovym zdrojem nejsou a je to pojmenovane v `sim/save.gd`.

const Lib = preload("res://tests/lib.gd")
const SAVE_PATH := "user://test_entity_state.sav"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const REGISTRY_SCRIPT := "res://sim/entity/registry.gd"
const WORLD_SCRIPT := "res://sim/sim_world.gd"


func _arg(name: String, fallback: String) -> String:
	# Cesta k souboru je VSTUP (`-- --mobile-script=<cesta>`), aby mutacni
	# harness (tools/gates/mutace-tests.py) dokazal, ze test meri opravdu ten
	# soubor - a ne vychozi, kdyz mu nekdo preda jinou cestu (docs/09 §9.6).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _mobil(mobile_script, serial: int, x: int, y: int):
	var m = mobile_script.new(serial, 401, Vector3i(x, y, 7))
	m.hue = 3377
	m.name = "Testovac"
	m.dir = 5
	m.flags = 17
	m.hp = 61
	m.max_hp = 87
	m.stam = 99
	m.max_stam = 130
	m.mana = 4
	m.max_mana = 20
	m.stats.str_ = 75
	m.stats.dex = 130
	m.stats.int_ = 20
	m.backpack = serial + 1000
	m.notoriety = 3
	m.fame = 1234
	m.karma = -560
	m.hunger = 9
	m.skills.set_value(0, 305)
	m.skills.set_value(7, 1000)
	m.skills.set_lock(7, m.skills.LOCK_LOCKED)
	m.skills.raise_cap(7, 200)
	m.equip = {1: 400001, 3: 400002}
	m.ai = {"state": "wander", "target": 400009, "home": Vector3i(x + 1, y + 2, 3),
		"timer_ms": 2500}
	return m


func run(t) -> void:
	var mobile_script = Lib.script_at(_arg("mobile-script", MOBILE_SCRIPT))
	if mobile_script == null:
		t._pending("entity.mobile NENI HOTOVA: " + _arg("mobile-script", MOBILE_SCRIPT)
			+ " chybi nebo nejde nacist")
		return
	var registry_script = Lib.script_at(_arg("registry-script", REGISTRY_SCRIPT))
	if registry_script == null:
		t._pending("sim.entity_registry NENI HOTOVA: "
			+ _arg("registry-script", REGISTRY_SCRIPT) + " chybi")
		return
	var world_script = Lib.script_at(_arg("world-script", WORLD_SCRIPT))
	if world_script == null:
		t._pending("sim.offline: chybi sim/sim_world.gd (svet, ktery entity uklada)")
		return

	# -- 1) mobil umi vypsat stav a vratit ho (konkretni hodnoty, ne "neni null")
	var mob = _mobil(mobile_script, 400007, 1490, 1611)
	var stav: Dictionary = mob.state()
	t._check(int(stav.get("serial", 0)) == 400007,
		"entity.mobile: state() nese serial (namEReno %s)" % str(stav.get("serial")))
	t._check(stav.get("pos") == [1490, 1611, 7],
		"entity.mobile: state() nese pozici jako [x,y,z] (namEReno %s)" % str(stav.get("pos")))
	t._check(stav.get("equip") == [[1, 400001], [3, 400002]],
		"entity.mobile: equip je SERAZENY seznam dvojic (namEReno %s)" % str(stav.get("equip")))
	t._check(int(stav.get("hp", 0)) == 61 and int(stav.get("max_stam", 0)) == 130,
		"entity.mobile: state() nese hp/stam zvlášť (hp=%s max_stam=%s)"
		% [str(stav.get("hp")), str(stav.get("max_stam"))])
	t._check(stav.get("stats") == [75, 130, 20],
		"entity.mobile: state() nese staty (namEReno %s)" % str(stav.get("stats")))
	var sk: Dictionary = stav.get("skills", {})
	var vals: Array = sk.get("values", [])
	t._check(vals.size() >= 8 and int(vals[0]) == 305 and int(vals[7]) == 1000,
		"entity.mobile: state() nese skilly (namEReno %s)" % str(vals.slice(0, 8)))
	var caps: Array = sk.get("caps", [])
	t._check(caps.size() >= 8 and int(caps[7]) == 200,
		"entity.mobile: state() nese i STROP skillu (legendarni svitek; namEReno %s)"
		% str(caps.slice(0, 8)))
	t._check(stav.get("ai", []) == ["wander", 400009, 1491, 1613, 3, 2500],
		"entity.mobile: state() nese ai vcetne home (namEReno %s)" % str(stav.get("ai")))

	# -- 2) round-trip v pameti i PRES JSON (save je JSON - int se vrati jako float)
	var druhy = mobile_script.new()
	druhy.restore(stav)
	t._check(druhy.state() == stav,
		"entity.mobile: restore(state()) da tyz stav (pamet)")
	var pres_json = JSON.parse_string(JSON.stringify(stav))
	var treti = mobile_script.new()
	treti.restore(pres_json)
	t._check(treti.state() == stav,
		"entity.mobile: restore() z JSONu da tyz stav (pozor na float a PackedInt32Array)")
	t._check(str(treti.skills.cap(7)) == "1200",
		"entity.mobile: strop 1200 prezije JSON (namEReno %s)" % str(treti.skills.cap(7)))

	# -- 3) registry: stav je serazeny podle serialu, ne podle poradi vlozeni
	var a = registry_script.new()
	a.register(_mobil(mobile_script, 400020, 10, 10))
	a.register(_mobil(mobile_script, 400010, 20, 20))
	var b = registry_script.new()
	b.register(_mobil(mobile_script, 400010, 20, 20))
	b.register(_mobil(mobile_script, 400020, 10, 10))
	t._check(JSON.stringify(a.state()) == JSON.stringify(b.state()),
		"sim.entity_registry: stav nezavisi na poradi registrace (razeno podle serialu)")
	var rows: Array = a.state().get("mobiles", [])
	t._check(rows.size() == 2 and int(rows[0].get("serial", 0)) == 400010,
		"sim.entity_registry: state() vraci mobily serazene (namEReno %s)"
		% str(rows.map(func(r): return r.get("serial"))))
	var c = registry_script.new()
	c.restore(JSON.parse_string(JSON.stringify(a.state())))
	t._check(c.size() == 2 and c.get_mobile(400020).pos == Vector3i(10, 10, 7),
		"sim.entity_registry: restore() vrati mobily (size=%d)" % c.size())
	c.restore({})
	t._check(c.size() == 0, "sim.entity_registry: restore() prazdneho stavu vyprázdní registr")
	c.restore({"mobiles": "tohle neni seznam"})
	t._check(c.size() == 0,
		"sim.entity_registry: restore() s vadnym vstupem nenecha PULKU stavu (size=%d)" % c.size())

	# -- 4) svet: mobily jsou ve stavu (hash) i v save
	var svet = world_script.new(7, {})
	t._check(svet.state_source_names().has("entities"),
		"sim.world_loop: svet ma zaregistrovany zdroj `entities` (namEReno %s)"
		% str(svet.state_source_names()))
	svet.registry.register(_mobil(mobile_script, 400031, 100, 200))
	var hash_s_mobilem: String = svet.state_hash()
	var prazdny = world_script.new(7, {})
	t._check(hash_s_mobilem != prazdny.state_hash(),
		"sim.world_loop: mobil JE v state_hash() (jinak by se neukladal)")
	var jiny = world_script.new(7, {})
	jiny.registry.register(_mobil(mobile_script, 400031, 101, 200))
	t._check(jiny.state_hash() != hash_s_mobilem,
		"sim.world_loop: jina pozice mobila da jiny hash (hash meri TELA, ne jen pocet)")

	t._check(svet.save(SAVE_PATH) == true, "sim.world_loop: save() s mobily vraci true")
	var nacteny = world_script.new(7, {})
	t._check(nacteny.load(SAVE_PATH) == true, "sim.world_loop: load() vraci true")
	t._check(nacteny.state_hash() == hash_s_mobilem,
		"sim.world_loop: mobil prezije save/load (hash %s vs %s)"
		% [hash_s_mobilem.substr(0, 12), nacteny.state_hash().substr(0, 12)])
	var vraceny = nacteny.registry.get_mobile(400031)
	t._check(vraceny != null and vraceny.pos == Vector3i(100, 200, 7),
		"sim.world_loop: nacteny mobil ma pozici 100,200,7 (namEReno %s)"
		% (str(vraceny.pos) if vraceny != null else "null"))
	t._check(vraceny != null and int(vraceny.skills.cap(7)) == 1200,
		"sim.world_loop: nacteny mobil ma i strop skillu (namEReno %s)"
		% (str(vraceny.skills.cap(7)) if vraceny != null else "null"))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
