extends RefCounted
# sim.entity_registry - registr bytosti (docs/04 §4.2 a §4.2.1).
#
# Test meri, ze registr je JEDNO misto pro hledani mobila podle serialu:
#   * `register`/`get`/`all`/`remove` delaji, co rika smlouva,
#   * neznamy serial vraci null (ne pad) - na tom stoji `request_step` i `play`,
#   * `all()` je serazene podle serialu (na poradi vlozeni nesmi zaviset stav),
#   * mobil bez kladneho serialu se neprijme (serial 0 je vychozi hodnota),
#   * `render.anim` si z TOHOTO registru bere cislo tela (`body_of`), a to
#     i v CI, kde nejsou assety: `play()` by manifest potreboval a vyslo by
#     NEMERENO (assets/uo/ je v .gitignore).
#
# Cesta k souboru je VSTUP: `-- --registry-script=<cesta>`, aby mutacni harness
# (tools/gates/mutace-tests.py) dokazal, ze test meri opravdu ten soubor.

const Lib = preload("res://tests/lib.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")

const REGISTRY_SCRIPT := "res://sim/entity/registry.gd"
const ANIM_SCRIPT := "res://render/anim_player.gd"
const PRAZDNY_MANIFEST := "res://assets/uo/anim/neexistuje.json"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("registry-script", REGISTRY_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.entity_registry NENI HOTOVA: " + cesta + " chybi")
		return
	var reg = script.new()
	var a = MobileScript.new(0x40000001, 400, Vector3i(5, 5, 0))
	var b = MobileScript.new(0x40000002, 401, Vector3i(6, 5, 0))

	# 1) prazdny registr a neznamy serial
	t._check(reg.size() == 0, "sim.entity_registry: novy registr je prazdny")
	t._check(reg.get_mobile(0x40000001) == null and reg.all() is Array and reg.all().is_empty(),
		"sim.entity_registry: neznamy serial vraci null a all() je prazdne (ne pad)")

	# 2) registrace: nejdriv vyssi serial, aby sel poznat rozdil proti poradi vlozeni
	reg.register(b)
	reg.register(a)
	t._check(reg.size() == 2, "sim.entity_registry: po dvou registracich ma 2 mobily")
	t._check(reg.get_mobile(a.serial) == a and reg.get_mobile(b.serial) == b,
		"sim.entity_registry: get(serial) vraci TENTYZ objekt (ne kopii)")

	# 3) all() je serazene podle serialu, ne podle poradi vlozeni
	var vsechny: Array = reg.all()
	t._check(vsechny.size() == 2 and vsechny[0] == a and vsechny[1] == b,
		"sim.entity_registry: all() je serazene podle serialu (vyslo %s)"
		% str([vsechny[0].serial if vsechny.size() > 0 else -1,
			vsechny[1].serial if vsechny.size() > 1 else -1]))

	# 4) mobil bez kladneho serialu a null se neprijmou (serial 0 = "zadny")
	reg.register(MobileScript.new(0, 400, Vector3i.ZERO))
	reg.register(null)
	t._check(reg.size() == 2 and reg.get_mobile(0) == null,
		"sim.entity_registry: mobil se serialem 0 se neprijme (size %d)" % reg.size())

	# 5) remove maze prave jeden serial a zbytek zustava
	reg.remove(a.serial)
	t._check(reg.size() == 1 and reg.get_mobile(a.serial) == null and reg.get_mobile(b.serial) == b,
		"sim.entity_registry: remove(serial) maze jen ten jeden (size %d)" % reg.size())
	reg.remove(0x40009999)
	t._check(reg.size() == 1, "sim.entity_registry: remove neexistujiciho serialu nic nezmeni")

	# 6) registrace stejneho serialu podruhe PREPISE (jeden mobil = jeden zaznam)
	var novy = MobileScript.new(b.serial, 400, Vector3i(7, 7, 0))
	reg.register(novy)
	t._check(reg.size() == 1 and reg.get_mobile(b.serial) == novy,
		"sim.entity_registry: druha registrace téhož serialu prepise mobil")

	# 7) `render.anim` si z registru bere CISLO TELA (druha dira ze smlouvy).
	#    `body_of` je bez assetu, takze se to meri i v CI.
	var anim_script = Lib.script_at(ANIM_SCRIPT)
	if anim_script == null:
		t._check(false, "sim.entity_registry: render/anim_player.gd chybi - telo nema komu predat")
	else:
		var hrac = anim_script.new(PRAZDNY_MANIFEST, reg)
		t._check(hrac.body_of(b.serial) == 400,
			"sim.entity_registry: render.anim.body_of(serial) = %d, v registru telo %d"
			% [hrac.body_of(b.serial), novy.body])
		t._check(hrac.body_of(0x40009999) == -1,
			"sim.entity_registry: serial, ktery v registru NENI, vraci -1 (vyslo %d)"
			% hrac.body_of(0x40009999))
		var bez = anim_script.new(PRAZDNY_MANIFEST)
		t._check(bez.body_of(400) == 400,
			"sim.entity_registry: bez registru je serial cislo tela (starsi chovani, vyslo %d)"
			% bez.body_of(400))
