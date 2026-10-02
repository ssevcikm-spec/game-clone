extends RefCounted
# entity.stats - staty postavy (docs/04 §4.2). Testy meri PRESNE vzorce ze
# zadani: hits_max = 50 + STR/2, stam_max = DEX, mana_max = INT a stat cap 225.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/entity/stats.gd")
	if script == null:
		t._pending("entity.stats NENI HOTOVA: sim/entity/stats.gd chybi")
		return
	var consts: Dictionary = Lib.consts_at("res://core/const.gd")

	var stats = script.new()
	t._check(stats.str_ == 10 and stats.dex == 10 and stats.int_ == 10,
		"entity.stats: vychozi staty jsou 10/10/10 (namEReno %d/%d/%d)" % [stats.str_, stats.dex, stats.int_])
	t._check(stats.hits_max() == 55, "entity.stats: hits_max pri STR 10 je 55 (namEReno %d)" % stats.hits_max())
	t._check(stats.stam_max() == 10 and stats.mana_max() == 10,
		"entity.stats: stam_max == DEX a mana_max == INT")
	t._check(stats.stat_total() == 30, "entity.stats: stat_total je soucet (namEReno %d)" % stats.stat_total())
	t._check(stats.at_cap() == false, "entity.stats: 30 neni na stropu")

	# klicovy vzorec ze zadani: STR 100 -> hits_max 100
	var strong = script.new(100, 50, 25)
	t._check(strong.hits_max() == 100, "entity.stats: hits_max = 50 + STR/2, STR 100 -> 100 (namEReno %d)" % strong.hits_max())
	t._check(strong.stam_max() == 50, "entity.stats: stam_max = DEX = 50")
	t._check(strong.mana_max() == 25, "entity.stats: mana_max = INT = 25")
	t._check(strong.stat_total() == 175, "entity.stats: stat_total = 175 (namEReno %d)" % strong.stat_total())

	# liche STR: celociselne deleni dolu (soucast vzorce, ne chyba)
	var odd = script.new(101, 0, 0)
	t._check(odd.hits_max() == 100, "entity.stats: STR 101 -> hits_max 100 (deleni dolu, namEReno %d)" % odd.hits_max())
	t._check(odd.stam_max() == 0 and odd.mana_max() == 0, "entity.stats: nulove staty vraci 0")

	# stat cap je z core/const.gd, ne opsany v tomto souboru (docs/08 G1)
	t._check(int(consts.get("STAT_CAP", 0)) == 225,
		"entity.stats: STAT_CAP v core/const.gd je 225 (namEReno %s)" % str(consts.get("STAT_CAP")))
	var capped = script.new(75, 75, 75)
	t._check(capped.stat_total() == 225 and capped.at_cap(),
		"entity.stats: 225/225/225 je presne na stropu (namEReno %d, at_cap %s)" % [capped.stat_total(), str(capped.at_cap())])
	var over = script.new(100, 100, 100)
	t._check(over.at_cap(), "entity.stats: 300 je nad stropem")
	t._check(over.hits_max() == 100 and over.stam_max() == 100,
		"entity.stats: strop nemeni samotne vzorce (hits 100, stam 100)")

	# typy: do stavu nesmi proniknout float
	t._check(typeof(stats.hits_max()) == TYPE_INT and typeof(stats.stat_total()) == TYPE_INT,
		"entity.stats: hits_max i stat_total vraci int (zadny float ve stavu)")
