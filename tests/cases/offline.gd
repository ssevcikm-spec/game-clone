extends RefCounted
# sim.offline - svet jde dal i bez hrace (granule `sim.offline`, milnik MK).
#
# Kriterium: dobeh sveta je FUNKCE CASU - bez hrace se stav zmeni, dvakrat
# totéž dá totéž, druhy dobeh na tyz cas nic nemeni, je jedno, jak se davkuje,
# a behem dobehu se NETIKUJE svet (agentni systemy maji zustat na nule).
#
# ⚠ Co tenhle case NEMERI: co s naplanovanymi udalostmi dela `world.spawn`
# (M5) a `sim.vendor` (MK) - konzumenty zatim nejsou, je to pojmenovane
# v hlavicce `sim/offline.gd`.

const Lib = preload("res://tests/lib.gd")
const OFFLINE_SCRIPT := "res://sim/offline.gd"
const WORLD_SCRIPT := "res://sim/sim_world.gd"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const MAP_SCRIPT := "res://sim/world/map.gd"
const MAP_PREFIX := "res://tests/fixtures/world/map0"

const START: int = 1700000000
const HOURS: int = 48            # 48 hernich hodin = 2 herni dny
const HOUR_S: int = 300          # 1 herni hodina = 300 s (DAY_LENGTH_MS/24 = 300 000 ms)
const HOUR_MS: int = 300000
const BLOKY_FIXTURE: int = 6     # tests/fixtures/world/map0 = 2 x 3 bloky 8x8


class Pocitadlo extends RefCounted:
	# Agentni system, ktery si POCITA ticky. Kdyby dobeh tikoval svet, tohle
	# cislo vyroste - a to je presne to, co kontrola 3 brany F1 hlida.
	var ticku: int = 0

	func tick(_ms: int = 0) -> void:
		ticku += 1


func _arg(name: String, fallback: String) -> String:
	# Cesta k souboru je VSTUP (`-- --offline-script=<cesta>`), aby mutacni
	# harness dokazal, ze test meri opravdu ten soubor (docs/09 §9.6).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _sestav(world_script, map, offline_script, mobil_serial: int = 400100):
	# Svět se jednou mobilnou postavou a jednim "agentnim" systemem.
	var svet = world_script.new(11, {})
	var pocitadlo = Pocitadlo.new()
	svet.systems["ai"] = pocitadlo
	if mobil_serial > 0:
		var mobile_script = Lib.script_at(MOBILE_SCRIPT)
		if mobile_script != null:
			var m = mobile_script.new(mobil_serial, 400, Vector3i(100, 100, 0))
			svet.registry.register(m)
	return {"svet": svet, "pocitadlo": pocitadlo,
		"offline": offline_script.new(svet, START, map)}


func run(t) -> void:
	var offline_script = Lib.script_at(_arg("offline-script", OFFLINE_SCRIPT))
	if offline_script == null:
		t._pending("sim.offline NENI HOTOVA: " + _arg("offline-script", OFFLINE_SCRIPT)
			+ " chybi nebo nejde nacist")
		return
	var world_script = Lib.script_at(_arg("world-script", WORLD_SCRIPT))
	if world_script == null:
		t._pending("sim.offline: chybi sim/sim_world.gd (svet, ktery se dobehuje)")
		return
	var map_script = Lib.script_at(_arg("map-script", MAP_SCRIPT))
	var map = null if map_script == null else map_script.new(MAP_PREFIX)

	# -- 1) dobeh pohne svetem a je to VIDET (hash + udalosti)
	var a = _sestav(world_script, map, offline_script)
	var hash_pred: String = a["svet"].state_hash()
	var report: Dictionary = a["offline"].advance_to(START + HOURS * HOUR_S)
	var hash_po: String = a["svet"].state_hash()
	t._check(hash_po != hash_pred,
		"sim.offline: svet se bez hrace pohnul (hash %s -> %s)"
		% [hash_pred.substr(0, 12), hash_po.substr(0, 12)])
	t._check(int(report.get("advanced_ms", -1)) == HOURS * HOUR_MS,
		"sim.offline: dobeh posune hodiny presne o %d ms (namEReno %s)"
		% [HOURS * HOUR_MS, str(report.get("advanced_ms"))])
	t._check(int(report.get("events", 0)) > 0,
		"sim.offline: dobeh naplanuje casove udalosti (namEReno %s)" % str(report.get("events")))
	t._check(int(report.get("steps", 0)) > 0,
		"sim.offline: dobeh jde po krocich (namEReno %s)" % str(report.get("steps")))
	t._check(int(report.get("map_blocks", 0)) == BLOKY_FIXTURE,
		"sim.offline: rozvrh zna rozmery mapy z FIXTURE (namEReno %s, cekano %d)"
		% [str(report.get("map_blocks")), BLOKY_FIXTURE])
	t._check(int(report.get("mobiles", -1)) == 1,
		"sim.offline: report vi, kolik je ve svete entit (namEReno %s)"
		% str(report.get("mobiles")))
	t._check(a["offline"].elapsed_report().get("events") == report.get("events"),
		"sim.offline: elapsed_report() vraci tyz report jako advance_to()")

	# -- 2) agentni systemy se pri dobehu NETIKUJI (a pocitadlo opravdu meri)
	var b = _sestav(world_script, map, offline_script)
	b["offline"].advance_to(START + HOURS * HOUR_S)
	t._check(int(b["pocitadlo"].ticku) == 0,
		"sim.offline: dobeh netikuje agentni systemy (namEReno %d ticku)"
		% int(b["pocitadlo"].ticku))
	b["svet"].tick(50)
	t._check(int(b["pocitadlo"].ticku) == 1,
		"sim.offline: pocitadlo ticku opravdu meri - bezny tick ho zvysi (namEReno %d)"
		% int(b["pocitadlo"].ticku))

	# -- 3) reprodukovatelnost: tyz seed a tyz vstup = tyz hash
	var c = _sestav(world_script, map, offline_script)
	c["offline"].advance_to(START + HOURS * HOUR_S)
	t._check(c["svet"].state_hash() == hash_po,
		"sim.offline: dva behy se stejnym vstupem daji stejny hash (%s vs %s)"
		% [c["svet"].state_hash().substr(0, 12), hash_po.substr(0, 12)])
	t._check(int(c["pocitadlo"].ticku) == 0, "sim.offline: ani druhy beh nic netiknul")

	# -- 4) idempotence: druhy dobeh na tyz cas nic nemeni
	var druhy: Dictionary = a["offline"].advance_to(START + HOURS * HOUR_S)
	t._check(int(druhy.get("advanced_ms", -1)) == 0,
		"sim.offline: druhy dobeh na tyz cas posune hodiny o 0 ms (namEReno %s)"
		% str(druhy.get("advanced_ms")))
	t._check(a["svet"].state_hash() == hash_po,
		"sim.offline: druhy dobeh na tyz cas nezmeni hash")

	# -- 5) nezalezi na davkovani: po hodinach == jednim krokem
	var d = _sestav(world_script, map, offline_script)
	for k in range(1, HOURS + 1):
		d["offline"].advance_to(START + k * HOUR_S)
	t._check(d["svet"].state_hash() == hash_po,
		"sim.offline: dobeh po davkach da tyz hash jako jednim krokem (%s vs %s)"
		% [d["svet"].state_hash().substr(0, 12), hash_po.substr(0, 12)])
	t._check(int(d["offline"].elapsed_report().get("events_total", 0)) == int(report.get("events", -1)),
		"sim.offline: po davkach se naplanuje tyz pocet udalosti (%s vs %s)"
		% [str(d["offline"].elapsed_report().get("events_total")), str(report.get("events"))])
	t._check(int(d["pocitadlo"].ticku) == 0, "sim.offline: ani davkovany dobeh netiknul svet")

	# -- 6) strop: rocni absence se dobehne jen po `MAX_CATCHUP_MS`
	var e = _sestav(world_script, map, offline_script)
	var strop: Dictionary = e["offline"].advance_to(START + 365 * 24 * 3600)
	t._check(bool(strop.get("capped", false)) == true,
		"sim.offline: rocni absence se ohlasí jako `capped` (namEReno %s)"
		% str(strop.get("capped")))
	t._check(int(strop.get("advanced_ms", 0)) <= offline_script.MAX_CATCHUP_MS,
		"sim.offline: dobeh nikdy nepresahne MAX_CATCHUP_MS (namEReno %s, strop %d)"
		% [str(strop.get("advanced_ms")), offline_script.MAX_CATCHUP_MS])
	t._check(int(strop.get("advanced_ms", 0)) > 0,
		"sim.offline: i omezenej dobeh neco udela (namEReno %s)" % str(strop.get("advanced_ms")))
	t._check(int(e["pocitadlo"].ticku) == 0, "sim.offline: ani strop netikne svet")
