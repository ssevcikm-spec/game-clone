extends RefCounted
# sim.commands - prikazy klient -> simulace (docs/04 §4.3).
# Kriterium z promptu: neznamy typ prikazu vraci {ok:false} a nic nezmeni.
# Testy meri i to, ze dispatch opravdu NECO ZAVOLA (ne jen ze nespadne).

const Lib = preload("res://tests/lib.gd")


class FakeMovement extends RefCounted:
	var calls: Array = []

	func request_step(m: int, dir: int, run: bool) -> Dictionary:
		calls.append([m, dir, run])
		return {"ok": true, "delay_ms": 400, "reason": ""}


class FakeSim extends RefCounted:
	var player_serial: int = 0x40000000
	var movement = null
	var events: Array = []

	func _init(with_movement: bool = false) -> void:
		if with_movement:
			movement = FakeMovement.new()

	func push_event(name: String, data: Dictionary) -> void:
		events.append({"name": name, "data": data})


func run(t) -> void:
	var script = Lib.script_at("res://sim/commands.gd")
	if script == null:
		t._pending("sim.commands NENI HOTOVA: sim/commands.gd chybi")
		return
	var commands = script.new()

	# 1) kriteria z promptu: neznamy typ
	var unknown: Dictionary = commands.validate({"t": "teleport_to_moon"})
	t._check(unknown.get("ok") == false, "sim.commands: neznamej typ vraci ok=false")
	t._check(unknown.get("reason") == "unknown_command",
		"sim.commands: duvod u neznamEho typu je 'unknown_command' (namEReno %s)" % str(unknown.get("reason")))

	# 2) chybejici pole, spatny typ, rozsah
	t._check(commands.validate({"t": "move", "run": false, "seq": 1}).get("reason") == "missing:dir",
		"sim.commands: chybejici pole -> missing:dir")
	t._check(commands.validate({"t": "move", "dir": "0", "run": false, "seq": 1}).get("reason") == "type:dir",
		"sim.commands: spatny typ -> type:dir")
	t._check(commands.validate({"t": "move", "dir": 8, "run": false, "seq": 1}).get("reason") == "range:dir",
		"sim.commands: dir mimo 0..7 -> range:dir")
	t._check(commands.validate({"t": "vendor", "action": "steal", "vendor": 1, "lines": []}).get("reason") == "range:action",
		"sim.commands: vendor action mimo buy/sell -> range:action")
	t._check(commands.validate({"t": "save", "slot": 1}).get("reason") == "not_in_sim",
		"sim.commands: save je mimo simulaci (docs/04 §4.3) -> not_in_sim")

	# 3) platny prikaz
	var ok_result: Dictionary = commands.validate({"t": "move", "dir": 0, "run": false, "seq": 1})
	t._check(ok_result.get("ok") == true, "sim.commands: platny move vraci ok=true")
	t._check(commands.validate({"t": "turn", "dir": 7}).get("ok") == true, "sim.commands: turn s dir=7 je platny")
	t._check(commands.validate({"t": "cast", "spell": 1}).get("ok") == true, "sim.commands: cast je platny")

	# 4) parse: jen pole ze smlouvy (+ volitelna), nic vymysleneho
	var parsed: Dictionary = commands.parse({"t": "move", "dir": 3, "run": true, "seq": 9, "hack": 1})
	t._check(not parsed.has("hack"), "sim.commands: parse zahodi pole, ktere neni ve smlouve")
	t._check(parsed.get("dir") == 3 and parsed.get("run") == true and parsed.get("seq") == 9,
		"sim.commands: parse zachova pole ze smlouvy")
	t._check(commands.parse({"t": "skill", "skill": 7, "target": {"x": 1}}).has("target"),
		"sim.commands: parse zachova volitelny target")
	t._check(commands.parse({"t": "nesmysl"}).get("t") == "", "sim.commands: parse neznamEho typu vrati prazdny typ")

	# 5) dispatch: neplatny prikaz nic nezmeni a hodi hlasku do zurnalu
	var sim := FakeSim.new()
	commands.dispatch(sim, {"t": "nesmysl"})
	t._check(sim.movement == null, "sim.commands: neplatny prikaz nezavola zadny system")
	t._check(sim.events.size() == 1 and sim.events[0]["name"] == "message",
		"sim.commands: neplatny prikaz hodi hlasku do zurnalu (namEReno %d udalosti)" % sim.events.size())
	if sim.events.size() == 1:
		t._check(str(sim.events[0]["data"]["text"]).contains("unknown_command"),
			"sim.commands: hlaska nese duvod (namEReno %s)" % str(sim.events[0]["data"]["text"]))

	# 6) dispatch opravdu vola system, kdyz existuje (ne jen "nespadne")
	var sim_ok := FakeSim.new(true)
	commands.dispatch(sim_ok, {"t": "move", "dir": 2, "run": true, "seq": 5})
	t._check(sim_ok.movement.calls == [[0x40000000, 2, true]],
		"sim.commands: dispatch zavola movement.request_step(player, dir, run) (namEReno %s)" % str(sim_ok.movement.calls))
	t._check(sim_ok.events.is_empty(), "sim.commands: pri uspesnem prikazu se do zurnalu nic neposila")

	# 7) dispatch bez systemu to rekne nahlas (nezustane ticho)
	var sim_missing := FakeSim.new(false)
	commands.dispatch(sim_missing, {"t": "move", "dir": 0, "run": false, "seq": 1})
	t._check(sim_missing.events.size() == 1
		and str(sim_missing.events[0]["data"]["text"]).contains("Not available yet"),
		"sim.commands: chybejici system se ohlasi hlaskou (namEReno %s)" % str(sim_missing.events))
