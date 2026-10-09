extends RefCounted
# sim.policy - pravidla s podminkami (granule `sim.policy`, milnik MK).
#
# KRITERIUM (smlouva `provides`): `load(json)`, `evaluate(state) -> [rozhodnuti]`,
# `priority_of(rule)`. Pravidla jsou DATA, vyhodnoceni je deterministicke,
# rozhodnuti jsou serazena a NESPLNENA podminka je videt i s DUVODEM.
#
# ⚠ Co tenhle case NEMERI: prevod rozhodnuti na `Command` (to je `sim.executor`)
# a zapojeni do sveta (to je `tests/cases/policy_hook.gd`).
#
# Merena cesta je VSTUP (`-- --policy-script=<cesta>`), aby mutacni harness
# dokazal, ze test meri opravdu ten soubor (docs/09 §9.6 bod 3).

const Lib = preload("res://tests/lib.gd")
const POLICY_SCRIPT := "res://sim/policy.gd"

var _data: Dictionary = {
	"version": 1,
	"rules": [
		{"id": "sell_full", "priority": 80,
		 "when": {"kind": "inventory_full", "args": {}},
		 "then": {"kind": "say", "args": {"text": "full"}}},
		{"id": "buy_pickaxe", "priority": 50,
		 "when": {"kind": "item_below", "args": {"item": "3717", "count": 1}},
		 "then": {"kind": "vendor", "args": {"action": "buy", "vendor": 7, "lines": []}}},
		{"id": "mine", "priority": 50,
		 "when": {"kind": "item_at_least", "args": {"item": "3717", "count": 1}},
		 "then": {"kind": "move", "args": {"dir": 2, "run": false}}},
		{"id": "night_home", "priority": 10,
		 "when": {"kind": "time_between", "args": {"from_hour": 22, "to_hour": 6}},
		 "then": {"kind": "move", "args": {"dir": 4}}},
	],
}


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _state(inv: int = 0, full: bool = false, ms: int = 12 * 300000) -> Dictionary:
	return {
		"world_time_ms": ms,
		"player": 400100,
		"inventory": {"3717": inv},
		"backpack": {"count": 10 if full else 3, "max": 10},
		"skills": {"45": 100},
		"flags": {},
	}


func _ids(decisions: Array) -> Array:
	var out: Array = []
	for d in decisions:
		out.append(str(d.get("rule_id", "")))
	return out


func run(t) -> void:
	var policy_script = Lib.script_at(_arg("policy-script", POLICY_SCRIPT))
	if policy_script == null:
		t._pending("sim.policy NENI HOTOVA: " + _arg("policy-script", POLICY_SCRIPT)
			+ " chybi nebo nejde nacist")
		return

	# -- 1) pravidla jsou data: load z Dictionary i z TEXTU JSONu
	var p = policy_script.new()
	t._check(p.load(_data) == true, "sim.policy: load(Dictionary) vraci true")
	t._check(p.rule_count() == 4, "sim.policy: nactou se vsechna 4 pravidla (namEReno %d)"
		% p.rule_count())
	t._check(p.errors().is_empty(), "sim.policy: platna data nedaji zadnou chybu (namEReno %s)"
		% str(p.errors()))
	t._check(p.priority_of("buy_pickaxe") == 50,
		"sim.policy: priority_of(id) vraci 50 (namEReno %d)" % p.priority_of("buy_pickaxe"))
	t._check(p.priority_of({"id": "x", "priority": 7}) == 7,
		"sim.policy: priority_of(rule) vraci 7 (namEReno %d)"
		% p.priority_of({"id": "x", "priority": 7}))
	var z_textu = policy_script.new()
	t._check(z_textu.load(JSON.stringify(_data)) == true,
		"sim.policy: load(text JSON) vraci true (cisla z JSONu jsou float!)")
	t._check(z_textu.rule_count() == 4, "sim.policy: z textu se nactou 4 pravidla (namEReno %d)"
		% z_textu.rule_count())

	# -- 2) poradi podle priority (a u stejne priority podle id)
	var a = policy_script.new()
	a.load(_data)
	var d = a.evaluate(_state(0, true))     # plny batoh i chybejici krumpac
	t._check(str(_ids(d)) == str(["sell_full", "buy_pickaxe"]),
		"sim.policy: rozhodnuti jdou podle priority sestupne (namEReno %s)" % str(_ids(d)))
	t._check(int(d[0]["priority"]) == 80 and int(d[1]["priority"]) == 50,
		"sim.policy: u rozhodnuti je i priorita (namEReno %s)"
		% str([d[0]["priority"], d[1]["priority"]]))
	var b = policy_script.new()
	b.load(_data)
	var d2 = b.evaluate(_state(0, false))   # jen chybejici krumpac
	t._check(str(_ids(d2)) == str(["buy_pickaxe"]),
		"sim.policy: nesplnena podminka pravidlo nevyhodi (namEReno %s)" % str(_ids(d2)))
	t._check(int(d2[0]["priority"]) == 50 and str(d2[0]["action"]["kind"]) == "vendor",
		"sim.policy: rozhodnuti nese akci z pravidla (namEReno %s)"
		% str(d2[0]["action"]["kind"]))

	# -- 3) NESPLNENA podminka je videt i s duvodem (ne ticho)
	var proc = false
	for row in a.last_skipped():
		if str(row.get("rule_id", "")) == "mine":
			proc = str(row.get("why", "")).contains("3717")
	t._check(proc, "sim.policy: preskocena podminka ma duvod s cislem (namEReno %s)"
		% str(a.last_skipped()))
	t._check(str(d2[0]["why"]).contains("3717"),
		"sim.policy: i splnena podminka nese duvod (namEReno '%s')" % str(d2[0]["why"]))

	# -- 4) determinismus: stejny stav + stejna politika = stejna rozhodnuti
	var c = policy_script.new()
	c.load(_data)
	var d3 = c.evaluate(_state(0, true))
	t._check(str(d3) == str(d),
		"sim.policy: dva behy se stejnym vstupem daji stejna rozhodnuti")
	t._check(str(c.last_skipped()) == str(a.last_skipped()),
		"sim.policy: dva behy daji stejny seznam preskocenych (i s duvody)")
	# poradi v DATEch nesmi rozhodovat: prohozene pravice = tyz vysledek
	var obracene: Dictionary = {"version": 1, "rules": []}
	for i in range(_data["rules"].size() - 1, -1, -1):
		obracene["rules"].append(_data["rules"][i])
	var e = policy_script.new()
	e.load(obracene)
	t._check(str(_ids(e.evaluate(_state(0, true)))) == str(_ids(d)),
		"sim.policy: na poradi pravidel v datech nezalezi (namEReno %s)"
		% str(_ids(e.evaluate(_state(0, true)))))

	# -- 5) stav se NECTE a NEMENI: chybejici klic = "stav nezna", ne ticha nula
	var pred: String = JSON.stringify(_state(0, true))
	# 12:00: casove okno neplati, takze jedine, co muze rozhodnout, je stav -
	# a ten chybi (kdyby se chybejici stav cetl jako 0, pravidlo by se vyhodilo).
	var prazdny: Dictionary = {"world_time_ms": 12 * 300000}
	var hole = policy_script.new()
	hole.load(_data)
	t._check(hole.evaluate(prazdny).is_empty(),
		"sim.policy: bez inventare se pravidla nevyhodi (neni to ticha nula)")
	var vsechny_duvody: Array = []
	for row in hole.last_skipped():
		vsechny_duvody.append(str(row.get("why", "")))
	t._check(vsechny_duvody.any(func(w): return w.contains("stav nezna")),
		"sim.policy: chybejici stav je v duvodu pojmenovany (namEReno %s)"
		% str(vsechny_duvody))
	var ne_slovnik = policy_script.new()
	ne_slovnik.load(_data)
	t._check(ne_slovnik.evaluate([]).is_empty() and ne_slovnik.last_skipped().size() == 1,
		"sim.policy: stav, ktery neni slovnik, se ohlasí (namEReno %s)"
		% str(ne_slovnik.last_skipped()))
	t._check(JSON.stringify(_state(0, true)) == pred,
		"sim.policy: evaluate() stav NEMENI (pred == po)")
	# bezstavovost: druhy stav nema videt prvni
	var g = policy_script.new()
	g.load(_data)
	g.evaluate(_state(0, true))
	var jen_krumpac = _ids(g.evaluate(_state(1, false)))
	t._check(str(jen_krumpac) == str(["mine"]),
		"sim.policy: evaluate() je funkce stavu, ne pameti (namEReno %s)" % str(jen_krumpac))

	# -- 6) casove okno pres pulnoc (a ze se pocita z herniho casu)
	var hodiny = policy_script.new()
	hodiny.load({"version": 1, "rules": [{"id": "noc", "priority": 1,
		"when": {"kind": "time_between", "args": {"from_hour": 22, "to_hour": 6}},
		"then": {"kind": "stop", "args": {"why": "noc"}}}]})
	t._check(_ids(hodiny.evaluate({"world_time_ms": 23 * 300000})) == ["noc"],
		"sim.policy: okno 22-6 plati ve 23:00")
	t._check(_ids(hodiny.evaluate({"world_time_ms": 3 * 300000})) == ["noc"],
		"sim.policy: okno 22-6 plati ve 3:00")
	t._check(hodiny.evaluate({"world_time_ms": 12 * 300000}).is_empty(),
		"sim.policy: okno 22-6 neplati ve 12:00")

	# -- 7) vadna data se ODMITNOU VIDITELNE (prazdna politika neni "v poradku")
	var vadna = policy_script.new()
	var vysledek: bool = vadna.load({"version": 1, "rules": [
		{"id": "x", "priority": 1,
		 "when": {"kind": "neexistuje", "args": {}},
		 "then": {"kind": "move", "args": {"dir": 0}}}]})
	t._check(vysledek == false,
		"sim.policy: politika bez platneho pravidla se NENACTE (vrací false, namEReno %s)"
		% str(vysledek))
	t._check(str(vadna.errors()).contains("neexistuje"),
		"sim.policy: duvod odmitnuti je pojmenovany (namEReno %s)" % str(vadna.errors()))
	var duplicitni = policy_script.new()
	t._check(duplicitni.load({"version": 1, "rules": [
		{"id": "a", "priority": 1, "when": {"kind": "always", "args": {}},
		 "then": {"kind": "say", "args": {"text": "1"}}},
		{"id": "a", "priority": 2, "when": {"kind": "always", "args": {}},
		 "then": {"kind": "say", "args": {"text": "2"}}}]}) == true,
		"sim.policy: duplicitni id se odmitne, ale platne pravidlo zustane")
	t._check(duplicitni.rule_count() == 1 and str(duplicitni.errors()).contains("duplicitni"),
		"sim.policy: duplicita je videt v errors() (namEReno %s)" % str(duplicitni.errors()))
	var spatny_json = policy_script.new()
	t._check(spatny_json.load("tohle neni json") == false,
		"sim.policy: neplatny JSON vraci false (ne tichou prazdnou politiku)")
