extends RefCounted
# entity.skills - skilly v desetinach (docs/04 §4.2, docs/05 §5.10).
# Testy meri PRESNA cisla: 58 hodnot, strop 1000 (1200 s legendarnim svitkem),
# celkovy strop 7000 a to, ze `set_value` na stropu zustane (zadani roadmapy).

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/entity/skills.gd")
	if script == null:
		t._pending("entity.skills NENI HOTOVA: sim/entity/skills.gd chybi")
		return
	var consts: Dictionary = Lib.consts_at("res://core/const.gd")
	var sk = script.new()

	t._check(sk.values.size() == 58, "entity.skills: 58 hodnot (namEReno %d)" % sk.values.size())
	t._check(sk.value(0) == 0 and sk.total() == 0, "entity.skills: novy skill je 0 a total 0")
	t._check(sk.cap(0) == 1000, "entity.skills: vychozi strop je 1000 (0.0-100.0 v desetinach)")
	t._check(int(consts.get("SKILL_CAP", 0)) == 7000,
		"entity.skills: SKILL_CAP v core/const.gd je 7000 (namEReno %s)" % str(consts.get("SKILL_CAP")))

	# Prijimaci kriterium roadmapy: hodnota 1000 + pokus o rust = zustane 1000.
	sk.set_value(3, 1000)
	t._check(sk.value(3) == 1000, "entity.skills: hodnota 1000 se ulozi (namEReno %d)" % sk.value(3))
	sk.set_value(3, 1500)
	t._check(sk.value(3) == 1000,
		"entity.skills: pokus o rust nad strop zustane na 1000 (namEReno %d)" % sk.value(3))
	sk.set_value(3, -5)
	t._check(sk.value(3) == 0, "entity.skills: zaporna hodnota se clampuje na 0 (namEReno %d)" % sk.value(3))

	# Legendarni svitek: strop JEDNOHO skillu na 1200 (docs/05 §5.10).
	sk.set_value(4, 1200)
	t._check(sk.value(4) == 1000, "entity.skills: bez svitku se nad 1000 nedostane ani 1200")
	sk.raise_cap(4)
	t._check(sk.cap(4) == 1200, "entity.skills: raise_cap zvedne strop na 1200 (namEReno %d)" % sk.cap(4))
	sk.set_value(4, 1200)
	t._check(sk.value(4) == 1200, "entity.skills: se svitkem se 1200 ulozi (namEReno %d)" % sk.value(4))
	sk.set_value(4, 1300)
	t._check(sk.value(4) == 1200, "entity.skills: ani se svitkem se pres 1200 nedostane")
	t._check(sk.cap(5) == 1000, "entity.skills: raise_cap jednoho skillu nezvysi strop jinemu")

	# total() scita vsechny; slouzi k hlidani celkoveho stropu 700 (docs/05 §5.10)
	sk.set_value(3, 1000)
	sk.set_value(0, 700)
	sk.set_value(1, 300)
	t._check(sk.total() == 1000 + 1200 + 700 + 300,
		"entity.skills: total() scita hodnoty (namEReno %d)" % sk.total())

	# zamky: 0=up, 1=down, 2=locked (docs/05 §5.10)
	t._check(sk.lock(0) == 0, "entity.skills: vychozi zamek je up")
	sk.set_lock(0, 2)
	t._check(sk.lock(0) == 2, "entity.skills: set_lock ulozi hodnotu")
	t._check(sk.lock(999) == 0 and sk.value(999) == 0 and sk.cap(999) == 1000,
		"entity.skills: neznamy index vraci nulu a vychozi strop (ne pád)")
	sk.set_value(999, 500)
	t._check(sk.total() == 1000 + 1200 + 700 + 300,
		"entity.skills: zapis mimo rozsah nic nezmeni")

	# typy: do stavu nesmi proniknout float (docs/09 §9.10 bod 3)
	t._check(typeof(sk.value(0)) == TYPE_INT and typeof(sk.total()) == TYPE_INT,
		"entity.skills: value i total vraci int (zadny float ve stavu)")
	t._check(sk.values.size() == sk.locks.size(),
		"entity.skills: hodnoty a zamky maji stejny pocet")
