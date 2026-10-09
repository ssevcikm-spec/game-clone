extends RefCounted
# sim.decision_log - videt do uvazovani postavy (granule `sim.decision_log`, MK).
#
# KRITERIUM (smlouva `provides`): `decision(rule_id, why, state_ref)`,
# `skipped(rule_id, why)`, `since(tick)`. Log zapisuje DUVOD (ne jen akci),
# umi rict, co se stalo od tiku, a neztrati to potichu (strop + `dropped()`).
#
# Merena cesta je VSTUP (`-- --decision-log-script=<cesta>`), aby mutacni
# harness dokazal, ze test meri opravdu ten soubor (docs/09 §9.6 bod 3).

const Lib = preload("res://tests/lib.gd")
const LOG_SCRIPT := "res://sim/decision_log.gd"


class FakeSink extends RefCounted:
	# Sink, ktery si pamatuje, co se publikovalo (v produkci je to SimWorld).
	var udalosti: Array = []

	func push_event(name: String, data: Dictionary) -> void:
		udalosti.append({"name": name, "data": data})


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var log_script = Lib.script_at(_arg("decision-log-script", LOG_SCRIPT))
	if log_script == null:
		t._pending("sim.decision_log NENI HOTOVA: "
			+ _arg("decision-log-script", LOG_SCRIPT) + " chybi nebo nejde nacist")
		return
	var strop: int = int(Lib.consts_at(_arg("decision-log-script", LOG_SCRIPT))
		.get("MAX_ENTRIES", 0))
	t._check(strop > 0, "sim.decision_log: strop MAX_ENTRIES je vyhlaseny (namEReno %d)" % strop)

	# -- 1) zapis rozhodnuti i preskoceni (s duvodem a tikem)
	var sink = FakeSink.new()
	var log = log_script.new(sink)
	log.set_tick(100)
	var e1: Dictionary = log.decision("kup_krumpac", "item 3717: 0 < 1", "otisk-a")
	t._check(str(e1.get("kind", "")) == "decision" and int(e1.get("tick", -1)) == 100,
		"sim.decision_log: rozhodnuti ma tik a druh (namEReno %s)" % str(e1))
	t._check(str(e1.get("why", "")) == "item 3717: 0 < 1",
		"sim.decision_log: zaznam nese DUVOD, ne jen akci (namEReno '%s')" % str(e1.get("why")))
	t._check(str(e1.get("state_ref", "")) == "otisk-a",
		"sim.decision_log: rozhodnuti nese odkaz na stav (namEReno '%s')"
		% str(e1.get("state_ref")))
	log.set_tick(150)
	var e2: Dictionary = log.skipped("tez", "stav nezna: inventory")
	t._check(str(e2.get("kind", "")) == "skipped" and int(e2.get("tick", -1)) == 150,
		"sim.decision_log: preskoceni je zaznamenane s tikem (namEReno %s)" % str(e2))
	t._check(str(e2.get("state_ref", "x")) == "",
		"sim.decision_log: preskoceni nema otisk stavu (namEReno '%s')"
		% str(e2.get("state_ref", "x")))

	# -- 2) `since(tick)` vraci zaznamy od tiku VCETNE
	var od_120: Array = log.since(120)
	var od_0: Array = log.since(0)
	t._check(od_120.size() == 1 and int(od_120[0].get("tick", -1)) == 150,
		"sim.decision_log: since(120) vraci jen pozdejsi zaznam (namEReno %d)" % od_120.size())
	t._check(od_0.size() == 2, "sim.decision_log: since(0) vraci vsechno (namEReno %d)"
		% od_0.size())
	t._check(log.size() == 2, "sim.decision_log: size() vraci 2 zaznamy (namEReno %d)" % log.size())

	# -- 3) publikace do zurnalu: co se ZMENI, jde jako udalost `message`
	t._check(sink.udalosti.size() == 2,
		"sim.decision_log: dve rozhodnuti = dve udalosti (namEReno %d)" % sink.udalosti.size())
	t._check(sink.udalosti.size() == 2 and str(sink.udalosti[0]["name"]) == "message",
		"sim.decision_log: publikuje se jako udalost `message` pro `ui.journal`")
	t._check(sink.udalosti.size() == 2
		and str(sink.udalosti[0]["data"].get("text", "")).contains("kup_krumpac"),
		"sim.decision_log: text udalosti nese jmeno pravidla (namEReno '%s')"
		% str(sink.udalosti[0]["data"].get("text", "")))
	var pred_pocet: int = sink.udalosti.size()
	log.set_tick(160)
	log.skipped("tez", "stav nezna: inventory")
	t._check(sink.udalosti.size() == pred_pocet,
		"sim.decision_log: stejna zprava se do zurnalu neopakuje (namEReno %d)" % sink.udalosti.size())
	log.skipped("tez", "item 3717: 0 >= 1")
	t._check(sink.udalosti.size() == pred_pocet + 1,
		"sim.decision_log: zmena duvodu se publikuje (namEReno %d)" % sink.udalosti.size())

	# -- 4) strop: log neroste bez omezeni a ztrata je VIDET
	var maly = log_script.new()
	for i in strop + 5:
		maly.skipped("r%d" % i, "duvod")
	t._check(maly.size() == strop,
		"sim.decision_log: log se drzi na stropu MAX_ENTRIES (namEReno %d z %d)"
		% [maly.size(), strop])
	t._check(maly.dropped() == 5,
		"sim.decision_log: ztracene zaznamy se pocitaji (namEReno %d, cekano 5)"
		% maly.dropped())
	t._check(int(maly.since(0)[0].get("tick", -1)) == 0, "sim.decision_log: strop nesmi rozhodit poradi")

	# -- 5) bez sinku log funguje (jen se nic nezobrazuje) + clear()
	var tichy = log_script.new()
	tichy.set_tick(7)
	tichy.decision("r", "proc", "ref")
	t._check(tichy.size() == 1, "sim.decision_log: bez sinku se zaznam ulozi (namEReno %d)"
		% tichy.size())
	var sink2 = FakeSink.new()
	var druhy = log_script.new(sink2)
	druhy.set_tick(1)
	druhy.decision("r", "proc", "ref")
	druhy.clear()
	t._check(druhy.size() == 0 and druhy.dropped() == 0,
		"sim.decision_log: clear() vyprázdní log i citac (namEReno %d/%d)"
		% [druhy.size(), druhy.dropped()])
	druhy.decision("r", "proc", "ref")
	t._check(sink2.udalosti.size() == 2,
		"sim.decision_log: po clear() se stejna zprava publikuje znovu (namEReno %d)"
		% sink2.udalosti.size())

	# -- 6) determinismus: stejna sekvence = stejne zaznamy
	var a = log_script.new()
	var b = log_script.new()
	for par in [["r1", "d1"], ["r2", "d2"], ["r3", "d3"]]:
		a.set_tick(10)
		b.set_tick(10)
		a.decision(str(par[0]), str(par[1]), "ref")
		b.decision(str(par[0]), str(par[1]), "ref")
	t._check(str(a.entries()) == str(b.entries()),
		"sim.decision_log: stejna sekvence da stejne zaznamy")
