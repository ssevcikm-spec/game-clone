extends RefCounted
# entity.mobile - tvar dat mobila (docs/04 §4.2 a §4.5).
# Testy meri, ze data maji TVAR ze smlouvy a ze se maxima berou ze statu
# (`hits_max = 50 + STR/2`), ne z opsanych cisel.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/entity/mobile.gd")
	if script == null:
		t._pending("entity.mobile NENI HOTOVA: sim/entity/mobile.gd chybi")
		return
	var mob = script.new(0x40000001, 400, Vector3i(1495, 1630, 0))

	t._check(mob.serial == 0x40000001 and mob.body == 400,
		"entity.mobile: serial a body se ulozi (serial %d, body %d)" % [mob.serial, mob.body])
	t._check(mob.pos == Vector3i(1495, 1630, 0), "entity.mobile: pos je Vector3i (namEReno %s)" % str(mob.pos))
	t._check(mob.dir == 0 and mob.hue == 0 and mob.backpack == 0,
		"entity.mobile: dir/hue/backpack zacinaji na 0")

	# Maxima ze statu: vychozi 10/10/10 -> hp 55 (50 + 10/2), stam 10, mana 10.
	t._check(mob.max_hp == 55 and mob.hp == 55,
		"entity.mobile: hp = max_hp = 55 pri STR 10 (namEReno %d/%d)" % [mob.hp, mob.max_hp])
	t._check(mob.max_stam == 10 and mob.stam == 10, "entity.mobile: stam = DEX = 10")
	t._check(mob.max_mana == 10 and mob.mana == 10, "entity.mobile: mana = INT = 10")
	t._check(mob.alive(), "entity.mobile: plne zdrava postava je alive()")

	# Vazby na ostatni granule: stats a skills jsou INSTANCE (smlouva komponent)
	t._check(mob.stats != null and mob.stats.hits_max() == 55,
		"entity.mobile: stats je instance Stats a pocita hits_max")
	t._check(mob.skills != null and mob.skills.value(0) == 0 and mob.skills.values.size() == 58,
		"entity.mobile: skills je instance Skills s 58 hodnotami")

	# Staty jdou menit a maxima se prepocitaji jen tim, kdo je nastavi
	mob.stats.str_ = 100
	t._check(mob.stats.hits_max() == 100, "entity.mobile: stats.str_ 100 -> hits_max 100")
	mob.max_hp = mob.stats.hits_max()
	t._check(mob.max_hp == 100, "entity.mobile: max_hp se da prenastavit podle statu")

	# Tvar ze §4.5: equip (layer -> serial), ai slovnik, fame/karma/hunger
	t._check(mob.equip is Dictionary and mob.equip.is_empty(),
		"entity.mobile: equip je slovnik layer -> serial (prazdny)")
	mob.equip[1] = 0x40000002
	t._check(mob.equip[1] == 0x40000002, "entity.mobile: equip drzi vrstvu 1 -> serial")
	t._check(mob.ai is Dictionary and mob.ai.has("state") and mob.ai.has("home"),
		"entity.mobile: ai ma tvar {state, target, home, timer_ms}")
	t._check(mob.fame == 0 and mob.karma == 0 and mob.hunger == 0 and mob.notoriety == 0,
		"entity.mobile: fame/karma/hunger/notoriety zacinaji na 0")

	# Smrt: hp 0 -> alive() false (pouzije sim.death)
	mob.hp = 0
	t._check(not mob.alive(), "entity.mobile: hp 0 znamena alive() == false")

	# typy: pozice ani hp nesmi byt float
	t._check(typeof(mob.pos.x) == TYPE_INT and typeof(mob.hp) == TYPE_INT,
		"entity.mobile: pos.x i hp jsou int (zadny float ve stavu)")
