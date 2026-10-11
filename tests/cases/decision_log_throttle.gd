extends RefCounted
# sim.decision_log - THROTTLE PODLE PRAVIDLA (oprava 2026-10-10, pokyn uzivatele
# „vypnul bych ve hře automatizaci, spamuje to hru“).
#
# PROC TENHLE TEST EXISTUJE: puvodni throttle porovnaval jen JEDEN posledni text.
# Dve pravidla, ktera se v tiku STRIDAJI, ho minou - a do zurnalu tece
# ~10 radku za sekundu, dokud se `MAX_LINES` nenaplni. Presne to se delo ve hre
# (`HANDOFF.md` to vedl jako otevreny bod 5 ze session D).
#
# Test meri CHOVANI s konkretnimi hodnotami (docs/09 §9.5):
#   * stridani dvou pravidel (A, B, A, B, ...) NESMI publikovat nic dalsiho,
#   * zmena duvodu u jednoho pravidla se publikuje PRAVE JEDNOU,
#   * `clear()` zrusi i pamet throttle (jinak by se po vycisteni mlcelo),
#   * `decision` a `skipped` tehoz pravidla jsou dva RŮZNÉ texty (kind je v klíči).
#
# Cesta k souboru je VSTUP: `-- --decision-log-script=<cesta>`.

const Lib = preload("res://tests/lib.gd")

const LOG_SCRIPT := "res://sim/decision_log.gd"


class Sink:
	# Nahrazuje `core/events.gd` (smlouva: `push_event(name, data)`).
	var udalosti: Array = []

	func push_event(name: String, data: Dictionary) -> void:
		udalosti.append({"name": name, "data": data})

	func texty() -> Array:
		var out: Array = []
		for e in udalosti:
			out.append(str(e["data"].get("text", "")))
		return out


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("decision-log-script", LOG_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		# SELHAT, ne jen `_pending` (docs/09 §9.5): chybějící soubor je vada
		# a mutační harness to pozná jen podle FAIL řádku s prefixem.
		t._check(false, "sim.decision_log NENI HOTOVY: " + cesta + " chybi")
		return

	# 1) Stridani dvou pravidel: prvni dve zpravy projdou, zbytek je ticho.
	var sink = Sink.new()
	var log = script.new(sink)
	log.set_tick(100)
	log.skipped("kup_krumpac", "stav nezna: inventory")
	log.skipped("cekej_na_skill", "skill 45: 300 < 200")
	var po_prvnich: int = sink.udalosti.size()
	t._check(po_prvnich == 2,
		"sim.decision_log: dve ruzna pravidla = dve zpravy (namEReno %d)" % po_prvnich)
	for i in 5:
		log.set_tick(150 + i)
		log.skipped("kup_krumpac", "stav nezna: inventory")
		log.skipped("cekej_na_skill", "skill 45: 300 < 200")
	t._check(sink.udalosti.size() == po_prvnich,
		"sim.decision_log: STRIDANI pravidel se neopakuje do zurnalu (namEReno %d, cekano %d)"
			% [sink.udalosti.size(), po_prvnich])

	# 2) Zmena duvodu u jednoho pravidla = prave jedna nova zprava.
	log.set_tick(200)
	log.skipped("kup_krumpac", "item 3717: 0 >= 1")
	t._check(sink.udalosti.size() == po_prvnich + 1,
		"sim.decision_log: zmena duvodu se publikuje prave jednou (namEReno %d)"
			% sink.udalosti.size())
	log.set_tick(201)
	log.skipped("kup_krumpac", "item 3717: 0 >= 1")
	t._check(sink.udalosti.size() == po_prvnich + 1,
		"sim.decision_log: stejny novy duvod se podruhe neopakuje (namEReno %d)"
			% sink.udalosti.size())

	# 3) `decision` a `skipped` tehoz pravidla jsou RUZNE zpravy (kind je v klici).
	log.set_tick(210)
	log.decision("kup_krumpac", "item 3717: 0 < 1", "otisk")
	t._check(sink.udalosti.size() == po_prvnich + 2,
		"sim.decision_log: decision a skipped tehoz pravidla jsou dve zpravy (namEReno %d)"
			% sink.udalosti.size())

	# 4) `clear()` zrusi i pamet throttle - jinak by se po vycisteni mlcelo.
	log.clear()
	log.set_tick(220)
	log.skipped("kup_krumpac", "item 3717: 0 >= 1")
	t._check(sink.udalosti.size() == po_prvnich + 3,
		"sim.decision_log: po clear() se stejna zprava publikuje znovu (namEReno %d)"
			% sink.udalosti.size())

	# 5) Text zpravy nese jmeno pravidla i duvod (na tom stoji citelnost zurnalu).
	var texty: Array = sink.texty()
	t._check(texty.size() > 0 and str(texty[0]).contains("kup_krumpac")
			and str(texty[0]).contains("inventory"),
		"sim.decision_log: text zpravy nese pravidlo i duvod (namEReno '%s')"
			% (str(texty[0]) if texty.size() > 0 else ""))
