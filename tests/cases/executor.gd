extends RefCounted
# sim.executor - vykonavatel politiky (granule `sim.executor`, milnik MK).
#
# KRITERIUM (smlouva `provides`): `step(state) -> [Command]`, `status()`.
# Vykonavatel meni ROZHODNUTI na `Command`, NIKDY nesaha na stav, vysle jen
# platny prikaz a kdyz nemuze pokracovat, ZASTAVI SE s DUVODEM (ticho je vada).
#
# ⚠ Co tenhle case NEMERI: zapojeni do `SimWorld` (to je
# `tests/cases/policy_hook.gd`) a pravidla (`tests/cases/policy.gd`).
#
# Merena cesta je VSTUP (`-- --executor-script=<cesta>`), aby mutacni harness
# dokazal, ze test meri opravdu ten soubor (docs/09 §9.6 bod 3).

const Lib = preload("res://tests/lib.gd")
const EXECUTOR_SCRIPT := "res://sim/executor.gd"
const POLICY_SCRIPT := "res://sim/policy.gd"
const LOG_SCRIPT := "res://sim/decision_log.gd"
const COMMANDS_SCRIPT := "res://sim/commands.gd"


class FakePolicy extends RefCounted:
	# "Politika", ktera neni `sim.policy` - dokazuje, ze vykonavatel odmitne
	# i rozhodnuti z jineho zdroje (a nezavisi na konkretni tride).
	var rozhodnuti: Array = []

	func evaluate(_state) -> Array:
		return rozhodnuti

	func last_skipped() -> Array:
		return []


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _policy(script, rules: Array):
	var p = script.new()
	if not p.load({"version": 1, "rules": rules}):
		return null
	return p


func _rule(id: String, priority: int, when_kind: String, then_kind: String,
		when_args: Dictionary = {}, then_args: Dictionary = {}) -> Dictionary:
	return {
		"id": id, "priority": priority,
		"when": {"kind": when_kind, "args": when_args},
		"then": {"kind": then_kind, "args": then_args},
	}


func run(t) -> void:
	var executor_script = Lib.script_at(_arg("executor-script", EXECUTOR_SCRIPT))
	if executor_script == null:
		t._pending("sim.executor NENI HOTOVA: " + _arg("executor-script", EXECUTOR_SCRIPT)
			+ " chybi nebo nejde nacist")
		return
	var policy_script = Lib.script_at(_arg("policy-script", POLICY_SCRIPT))
	if policy_script == null:
		t._pending("sim.executor: chybi sim/policy.gd (vykonavatel nema co vykonat)")
		return
	var log_script = Lib.script_at(_arg("log-script", LOG_SCRIPT))
	if log_script == null:
		t._pending("sim.executor: chybi sim/decision_log.gd (duvod by nebyl videt)")
		return
	var commands_script = Lib.script_at(_arg("commands-script", COMMANDS_SCRIPT))
	if commands_script == null:
		t._pending("sim.executor: chybi sim/commands.gd (neni cim prikaz overit)")
		return
	var commands = commands_script.new()

	# -- 1) bez politiky: zadny prikaz a DUVOD je videt
	var prazdny = executor_script.new()
	t._check(prazdny.step({"world_time_ms": 0}).is_empty(),
		"sim.executor: bez politiky neposle zadny prikaz")
	t._check(str(prazdny.status()["reason"]) == "no policy loaded",
		"sim.executor: bez politiky rekne duvod (namEReno '%s')" % str(prazdny.status()["reason"]))
	t._check(bool(prazdny.status()["running"]) == false,
		"sim.executor: bez politiky nehlasi 'bezi' (namEReno %s)" % str(prazdny.status()["running"]))

	# -- 2) rozhodnuti -> Command (a jen platny)
	var skript = _policy(policy_script, [_rule("go", 5, "skill_below", "move",
		{"skill": 45, "value": 200}, {"dir": 2, "run": false})])
	if skript == null:
		t._pending("sim.executor: testovaci politika se nenacetla (vada testu, ne kodu)")
		return
	var log = log_script.new()
	var ex = executor_script.new(skript, log)
	var stav: Dictionary = {"world_time_ms": 500, "skills": {"45": 100}}
	var pred: String = JSON.stringify(stav)
	var cmds: Array = ex.step(stav)
	t._check(cmds.size() == 1, "sim.executor: jedno rozhodnuti = jeden prikaz (namEReno %d)"
		% cmds.size())
	t._check(str(cmds[0].get("t", "")) == "move" and int(cmds[0].get("dir", -1)) == 2,
		"sim.executor: akce 'move dir 2' da prikaz move/dir 2 (namEReno %s)" % str(cmds[0]))
	t._check(int(cmds[0].get("seq", 0)) == 1,
		"sim.executor: prikaz dostane vlastni seq (namEReno %d)" % int(cmds[0].get("seq", 0)))
	t._check(bool(commands.validate(cmds[0]).get("ok", false)) == true,
		"sim.executor: vyslany prikaz projde sim.commands.validate (namEReno %s)"
		% str(commands.validate(cmds[0])))
	t._check(JSON.stringify(stav) == pred,
		"sim.executor: vykonavatel NEMENI stav (pred == po)")
	t._check(str(ex.status()["rule"]) == "go" and int(ex.status()["commands_sent"]) == 1,
		"sim.executor: status() vi, ktere pravidlo rozhodlo (namEReno %s)" % str(ex.status()))

	# -- 3) druhy krok = druhy seq (a poradi jde z vykonavatele, ne z nahody)
	var cmds2: Array = ex.step(stav)
	t._check(int(cmds2[0].get("seq", 0)) == 2,
		"sim.executor: druhy prikaz ma seq 2 (namEReno %d)" % int(cmds2[0].get("seq", 0)))

	# -- 4) nizsi priorita se zahodi S DUVODEM
	var dve = _policy(policy_script, [
		_rule("vyssi", 90, "always", "say", {}, {"text": "ahoj"}),
		_rule("nizsi", 10, "always", "move", {}, {"dir": 1}),
	])
	var log2 = log_script.new()
	var ex2 = executor_script.new(dve, log2)
	var cmds3: Array = ex2.step({"world_time_ms": 0})
	t._check(cmds3.size() == 1 and str(cmds3[0].get("t", "")) == "say",
		"sim.executor: provede se jen nejvyssi priorita (namEReno %s)" % str(cmds3))
	var duvod_nizsi: String = ""
	for e in log2.entries():
		if str(e.get("rule_id", "")) == "nizsi" and str(e.get("kind", "")) == "skipped":
			duvod_nizsi = str(e.get("why", ""))
	t._check(duvod_nizsi.contains("lower priority"),
		"sim.executor: nizsi priorita je v logu s duvodem (namEReno '%s')" % duvod_nizsi)

	# -- 5) nesplnena podminka = zastaveni s duvodem, ale PRECHODNE
	var cekaci = _policy(policy_script, [_rule("cekej", 5, "skill_below", "say",
		{"skill": 45, "value": 200}, {"text": "jdu"})])
	var ex3 = executor_script.new(cekaci, log_script.new())
	t._check(ex3.step({"skills": {"45": 500}}).is_empty(),
		"sim.executor: nesplnena podminka neposle prikaz")
	t._check(str(ex3.status()["reason"]) == "no rule matched",
		"sim.executor: zastaveni rekne 'no rule matched' (namEReno '%s')"
		% str(ex3.status()["reason"]))
	t._check(bool(ex3.status()["stopped"]) == false,
		"sim.executor: 'neni co delat' NENI trvale zastaveni (namEReno %s)"
		% str(ex3.status()["stopped"]))
	var pozdeji: Array = ex3.step({"skills": {"45": 100}})
	t._check(pozdeji.size() == 1,
		"sim.executor: kdyz podminka pozdeji plati, prikaz se posle (namEReno %d)" % pozdeji.size())

	# -- 6) neplatny prikaz se NEPOSLE a duvod je videt
	var vadna = _policy(policy_script, [_rule("kup", 5, "always", "vendor", {},
		{"action": "teleport", "vendor": 3, "lines": []})])
	var ex4 = executor_script.new(vadna, log_script.new())
	var cmds4: Array = ex4.step({"world_time_ms": 0})
	t._check(cmds4.is_empty(), "sim.executor: neplatny prikaz se neposle (namEReno %d)"
		% cmds4.size())
	t._check(str(ex4.status()["reason"]).contains("invalid command"),
		"sim.executor: duvod je 'invalid command' (namEReno '%s')" % str(ex4.status()["reason"]))

	# -- 7) rozhodnuti z JINEHO zdroje (ne `sim.policy`) se taky odmitne
	var fake = FakePolicy.new()
	fake.rozhodnuti = [{"rule_id": "cizi", "priority": 1, "why": "test",
		"action": {"kind": "teleport", "args": {}}}]
	var ex5 = executor_script.new(fake, log_script.new())
	t._check(ex5.step({}).is_empty(),
		"sim.executor: neznama akce z ciziho zdroje se neposle (jen platny Command)")
	t._check(str(ex5.status()["reason"]).contains("invalid command"),
		"sim.executor: i cizi zdroj dostane duvod (namEReno '%s')" % str(ex5.status()["reason"]))

	# -- 8) `stop` je TRVALE zastaveni (a duvod zustava)
	var konec = _policy(policy_script, [
		_rule("konc", 90, "flag", "stop", {"name": "hotovo", "is": true}, {"why": "hotovo"}),
		_rule("jed", 10, "always", "say", {}, {"text": "jdu"}),
	])
	var ex6 = executor_script.new(konec, log_script.new())
	ex6.step({"flags": {"hotovo": true}})
	t._check(bool(ex6.status()["stopped"]) == true and str(ex6.status()["reason"]) == "hotovo",
		"sim.executor: akce stop zastavi s duvodem (namEReno %s)" % str(ex6.status()))
	t._check(ex6.step({}).is_empty() and int(ex6.status()["commands_sent"]) == 0,
		"sim.executor: zastaveny vykonavatel uz nic neposle")
	# Zastaveni se musi poznat na CHOVANI: i kdyz by jine pravidlo platilo,
	# zastaveny vykonavatel se nepta (jinak by "stop" byl jen popisek).
	t._check(ex6.step({"flags": {"hotovo": false}}).is_empty(),
		"sim.executor: zastaveny vykonavatel nevyhodi ani jine pravidlo")
	ex6.resume()
	t._check(bool(ex6.status()["stopped"]) == false,
		"sim.executor: resume() zastaveni zrusi (namEReno %s)" % str(ex6.status()["stopped"]))
	var po_resume: Array = ex6.step({"flags": {"hotovo": false}})
	t._check(po_resume.size() == 1 and str(po_resume[0].get("t", "")) == "say",
		"sim.executor: po resume() se vyhodnocuje znovu (namEReno %s)" % str(po_resume))

	# -- 9) `wait` neni ticho: rekne, na co ceka (a dalsi krok jede dal)
	var cekani = _policy(policy_script, [
		_rule("pockej", 90, "flag", "wait", {"name": "cekej", "is": true}, {"ms": 2500}),
		_rule("jed", 10, "always", "say", {}, {"text": "jdu"}),
	])
	var ex7 = executor_script.new(cekani, log_script.new())
	t._check(ex7.step({"flags": {"cekej": true}}).is_empty(),
		"sim.executor: akce wait neposle prikaz")
	t._check(str(ex7.status()["reason"]) == "waiting: 2500 ms",
		"sim.executor: wait rekne, na co ceka (namEReno '%s')" % str(ex7.status()["reason"]))
	var po_cekani: Array = ex7.step({"flags": {"cekej": false}})
	t._check(po_cekani.size() == 1 and str(po_cekani[0].get("t", "")) == "say",
		"sim.executor: po cekani se vyhodnoti dalsi pravidlo (namEReno %s)" % str(po_cekani))

	# -- 10) log dostane DUVOD i OTISK stavu (a otisk se meni se stavem)
	var vzdy = _policy(policy_script, [_rule("vzdy", 5, "always", "say", {}, {"text": "x"})])
	var log3 = log_script.new()
	var ex8 = executor_script.new(vzdy, log3)
	ex8.step({"world_time_ms": 100})
	ex8.step({"world_time_ms": 900})
	var otisky: Array = []
	var duvody: Array = []
	for e in log3.entries():
		if str(e.get("kind", "")) == "decision":
			otisky.append(str(e.get("state_ref", "")))
			duvody.append(str(e.get("why", "")))
	t._check(otisky.size() == 2 and otisky[0].length() == 16,
		"sim.executor: rozhodnuti ma otisk stavu (namEReno %s)" % str(otisky))
	t._check(otisky.size() == 2 and otisky[0] != otisky[1],
		"sim.executor: jiny stav = jiny otisk (namEReno %s)" % str(otisky))
	t._check(duvody.size() == 2 and duvody[0] != "",
		"sim.executor: rozhodnuti nese i duvod (namEReno %s)" % str(duvody))
