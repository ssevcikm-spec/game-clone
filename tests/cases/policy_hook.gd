extends RefCounted
# sim.policy + sim.executor + sim.decision_log ZAPOJENE DO SVETA (zadani §4.2).
#
# KRITERIUM: vykonavatel je DOSAZITELNY Z PRODUKCE, ne mrtvy kod. `SimWorld`
# ho tickuje JEN kdyz je politika nactena (bez politiky = no-op), vyrobene
# `Command` jdou do STEJNE fronty jako hrac a jsou OZNACENE (`src`). Zapojeni
# nesmi zmenit `state_hash()` - politika ani log nejsou stavove zdroje, takze
# replaye (G9) zustavaji beze zmeny.
#
# Merena cesta je VSTUP (`-- --world-script=<cesta>`), aby mutacni harness
# dokazal, ze test meri opravdu `sim/sim_world.gd` (docs/09 §9.6 bod 3).

const Lib = preload("res://tests/lib.gd")
const WORLD_SCRIPT := "res://sim/sim_world.gd"
const POLICY_SCRIPT := "res://sim/policy.gd"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const POLICY_FILE := "user://test_policy_hook.json"
const PLAYER_SERIAL: int = 400100


class FakeMovement extends RefCounted:
	# System, ktery si pozna, ze dostal prikaz pres dispatcher (stejna cesta
	# jako prikaz hrace). Bez nej by se "prikaz prosel frontou" nedalo zmerit.
	var calls: Array = []

	func request_step(serial: int, dir: int, run: bool) -> void:
		calls.append([serial, dir, run])


class FakeExecutor extends RefCounted:
	# Vykonavatel, ktery vraci PRESNE zadany slovnik - diky tomu se da zmerit,
	# ze ho `SimWorld` oznaci (`src = policy`), protoze markuje tyz objekt.
	var prikazy: Array = []
	var volat: int = 0

	func step(_state) -> Array:
		volat += 1
		return prikazy


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _svet(world_script, mobile_script) -> Dictionary:
	var svet = world_script.new(7, {})
	svet.player_serial = PLAYER_SERIAL
	var m = mobile_script.new(PLAYER_SERIAL, 400, Vector3i(10, 10, 0))
	svet.registry.register(m)
	m.skills.set_value(45, 100)
	var fake = FakeMovement.new()
	svet.systems["movement"] = fake
	return {"svet": svet, "pohyb": fake}


func run(t) -> void:
	var world_script = Lib.script_at(_arg("world-script", WORLD_SCRIPT))
	if world_script == null:
		t._pending("sim.policy_hook NENI HOTOVA: " + _arg("world-script", WORLD_SCRIPT)
			+ " chybi nebo nejde nacist")
		return
	var policy_script = Lib.script_at(_arg("policy-script", POLICY_SCRIPT))
	if policy_script == null:
		t._pending("sim.policy_hook: chybi sim/policy.gd")
		return
	var mobile_script = Lib.script_at(_arg("mobile-script", MOBILE_SCRIPT))
	if mobile_script == null:
		t._pending("sim.policy_hook: chybi sim/entity/mobile.gd (neni koho ridit)")
		return

	# -- 1) BEZ politiky je krok no-op: zadny prikaz, zadna zprava od politiky
	var a = _svet(world_script, mobile_script)
	t._check(a["svet"].executor == null, "sim.policy_hook: bez politiky neni vykonavatel")
	a["svet"].tick(50)
	t._check(a["pohyb"].calls.is_empty(),
		"sim.policy_hook: bez politiky svet neposle zadny prikaz politiky (namEReno %s)"
		% str(a["pohyb"].calls))
	var zpravy: Array = []
	for e in a["svet"].snapshot()["events"]:
		zpravy.append(str(e.get("data", {}).get("text", "")))
	t._check(not zpravy.any(func(x): return x.begins_with("policy:")),
		"sim.policy_hook: bez politiky nejsou v zurnalu zpravy politiky (namEReno %s)" % str(zpravy))

	# -- 2) neexistujici soubor politiku NEZAPNE (a rekne to)
	t._check(a["svet"].load_policy("user://neexistuje-policy.json") == false,
		"sim.policy_hook: load_policy neexistujiciho souboru vraci false")
	t._check(a["svet"].executor == null,
		"sim.policy_hook: po neuspesnem nacteni vykonavatel NEBEZI (zadna ticha aktivace)")

	# -- 3) politika je DATA: nacte se z JSONu a vykonavatel se zapne
	var soubor = FileAccess.open(POLICY_FILE, FileAccess.WRITE)
	t._check(soubor != null, "sim.policy_hook: testovaci politiku jde zapsat do user://")
	if soubor == null:
		return
	soubor.store_string(JSON.stringify({"version": 1, "rules": [
		{"id": "tez", "priority": 5,
		 "when": {"kind": "skill_below", "args": {"skill": 45, "value": 200}},
		 "then": {"kind": "move", "args": {"dir": 2, "run": false}}}]}))
	soubor.close()
	var hash_pred: String = a["svet"].state_hash()
	var zdroje_pred: String = str(a["svet"].state_source_names())
	t._check(a["svet"].load_policy(POLICY_FILE) == true,
		"sim.policy_hook: load_policy nacte pravidla z JSONu (user://policy.json)")
	t._check(a["svet"].executor != null and int(a["svet"].policy.rule_count()) == 1,
		"sim.policy_hook: po nacteni je vykonavatel zapnuty a pravidlo nactene (namEReno %s)"
		% str(a["svet"].policy.rule_count()))
	# Zapojeni NESMI zmenit hash ani stavove zdroje (jinak padaji replaye, G9).
	t._check(a["svet"].state_hash() == hash_pred,
		"sim.policy_hook: nacteni politiky samo NEMENI state_hash (politika neni stav)")
	t._check(str(a["svet"].state_source_names()) == zdroje_pred,
		"sim.policy_hook: politika ani log nejsou stavove zdroje (namEReno %s)"
		% str(a["svet"].state_source_names()))

	# -- 4) vykonavatel je v ticku: rozhodnuti -> Command -> dispatcher
	a["svet"].tick(50)
	t._check(str(a["pohyb"].calls) == str([[PLAYER_SERIAL, 2, false]]),
		"sim.policy_hook: prikaz politiky dosel pres dispatcher do systemu (namEReno %s)"
		% str(a["pohyb"].calls))
	var zpravy2: Array = []
	for e in a["svet"].snapshot()["events"]:
		zpravy2.append(str(e.get("data", {}).get("text", "")))
	t._check(zpravy2.any(func(x): return x.begins_with("policy:")),
		"sim.policy_hook: rozhodnuti je videt v udalostech pro zurnal (namEReno %s)" % str(zpravy2))
	t._check(int(a["svet"].decision_log.size()) > 0,
		"sim.policy_hook: log rozhodnuti ma zaznam (namEReno %d)" % int(a["svet"].decision_log.size()))

	# -- 5) OZNACENI PUVODU: prikazy politiky i hrace jdou stejnou frontou,
	#       ale musi se dat rozlisit (`src`).
	a["svet"].enqueue({"t": "move", "dir": 0, "run": false, "seq": 9})
	var fronta: Array = a["svet"].get("_queue")
	t._check(fronta.size() == 1 and str(fronta[0].get("src", "")) == "player",
		"sim.policy_hook: prikaz hrace je ve fronte oznaceny 'player' (namEReno %s)" % str(fronta))
	var fake_ex = FakeExecutor.new()
	var prikaz: Dictionary = {"t": "say", "text": "ahoj"}
	fake_ex.prikazy = [prikaz]
	a["svet"].executor = fake_ex
	a["svet"].tick(50)
	t._check(int(fake_ex.volat) == 1,
		"sim.policy_hook: tick zavola vykonavatele (namEReno %d volani)" % int(fake_ex.volat))
	t._check(str(prikaz.get("src", "")) == "policy",
		"sim.policy_hook: prikaz politiky je oznaceny 'policy' (namEReno '%s')"
		% str(prikaz.get("src", "")))

	# -- 6) vypnuti politiky: svet je zase bez vykonavatele (a nic neposila)
	a["svet"].clear_policy()
	t._check(a["svet"].executor == null, "sim.policy_hook: clear_policy() vypne vykonavatele")
	var pred: int = a["pohyb"].calls.size()
	a["svet"].tick(50)
	t._check(a["pohyb"].calls.size() == pred,
		"sim.policy_hook: po vypnuti politiky uz zadny prikaz nechodi (namEReno %d)"
		% a["pohyb"].calls.size())
