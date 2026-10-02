extends RefCounted
# Prikazy klient -> simulace (docs/04 §4.3). Jedina cesta, jak menit stav.
#
# Neplatny prikaz se ZAHODI s hláškou do žurnálu - nikdy nespadne (prompt
# granule). Tabulka nize je doslovny prepis §4.3; nic se nepridava.
#
# CO SMLOUVA NEPOKRYVA (nalezeno pri implementaci, patri do docs/04):
#   * `turn`, `skill`, `target_reply`, `drag`, `drop`, `equip`, `say` nemaji
#     v §4.2 zadnou metodu systemu, ktera by je vyridila - dispatch je proto
#     hlasi jako "zatim nedostupne" (VIDITELNE, ne tise),
#   * `resurrect` ma jen `accept:bool`, ale `sim.death.resurrect(m, hp)` chce hp,
#   * `save`/`load` jsou v §4.3 oznacene "mimo simulaci (app)" - sim je odmita.

const Const = preload("res://core/const.gd")

const SERIAL_ONLY := {"serial": TYPE_INT}
const SLOT_ONLY := {"slot": TYPE_INT}

const REQUIRED := {
	"move": {"dir": TYPE_INT, "run": TYPE_BOOL, "seq": TYPE_INT},
	"turn": {"dir": TYPE_INT},
	"use": SERIAL_ONLY,
	"use_on": {"serial": TYPE_INT, "target": TYPE_DICTIONARY},
	"skill": {"skill": TYPE_INT},
	"target_reply": {"cursor": TYPE_INT},
	"drag": {"serial": TYPE_INT, "amount": TYPE_INT},
	"drop": {"serial": TYPE_INT, "to": TYPE_DICTIONARY},
	"equip": SERIAL_ONLY,
	"attack": SERIAL_ONLY,
	"war": {"on": TYPE_BOOL},
	"cast": {"spell": TYPE_INT},
	"craft": {"recipe": TYPE_INT, "count": TYPE_INT},
	"vendor": {"action": TYPE_STRING, "vendor": TYPE_INT, "lines": TYPE_ARRAY},
	"context": {"serial": TYPE_INT, "entry": TYPE_INT},
	"say": {"text": TYPE_STRING},
	"resurrect": {"accept": TYPE_BOOL},
	"save": SLOT_ONLY,
	"load": SLOT_ONLY,
}

const OPTIONAL := {
	"skill": {"target": TYPE_DICTIONARY},
	"target_reply": {"ref": TYPE_DICTIONARY},
}

const NOT_IN_SIM := ["save", "load"]


func parse(d: Dictionary) -> Dictionary:
	# Z klientova slovniku udela kanonicky prikaz: jen pole ze smlouvy.
	var t: String = str(d.get("t", ""))
	if not REQUIRED.has(t):
		return {"t": ""}
	var out: Dictionary = {"t": t}
	for key in REQUIRED[t].keys():
		out[key] = d.get(key)
	for key in OPTIONAL.get(t, {}).keys():
		if d.has(key):
			out[key] = d[key]
	return out


func validate(c: Dictionary) -> Dictionary:
	var t: String = str(c.get("t", ""))
	if not REQUIRED.has(t):
		return {"ok": false, "reason": "unknown_command"}
	for key in REQUIRED[t].keys():
		if not c.has(key):
			return {"ok": false, "reason": "missing:" + key}
		if typeof(c[key]) != REQUIRED[t][key]:
			return {"ok": false, "reason": "type:" + key}
	for key in OPTIONAL.get(t, {}).keys():
		if c.has(key) and typeof(c[key]) != OPTIONAL[t][key]:
			return {"ok": false, "reason": "type:" + key}
	if t in ["move", "turn"] and (c["dir"] < 0 or c["dir"] > 7):
		return {"ok": false, "reason": "range:dir"}
	if t == "vendor" and not (c["action"] in ["buy", "sell"]):
		return {"ok": false, "reason": "range:action"}
	if t in NOT_IN_SIM:
		return {"ok": false, "reason": "not_in_sim"}
	return {"ok": true, "reason": ""}


func dispatch(sim, c: Dictionary) -> void:
	var result: Dictionary = validate(c)
	if not result["ok"]:
		_message(sim, "Invalid command (" + str(result["reason"]) + ").")
		return
	var t: String = c["t"]
	match t:
		"move":
			_route(sim, t, "movement", "request_step", [_player(sim), c["dir"], c["run"]])
		"use":
			_route(sim, t, "interaction", "use", [_player(sim), c["serial"]])
		"use_on":
			_route(sim, t, "interaction", "use_on", [_player(sim), c["serial"], c["target"]])
		"attack":
			_route(sim, t, "combat", "attack", [_player(sim), c["serial"]])
		"war":
			_route(sim, t, "combat", "set_war", [_player(sim), c["on"]])
		"cast":
			_route(sim, t, "magic", "cast", [_player(sim), c["spell"]])
		"craft":
			_route(sim, t, "craft", "craft", [_player(sim), c["recipe"], c["count"]])
		"context":
			_route(sim, t, "interaction", "context_action", [_player(sim), c["serial"], c["entry"]])
		"vendor":
			var method: String = "buy" if c["action"] == "buy" else "sell"
			_route(sim, t, "vendor", method, [_player(sim), c["vendor"], c["lines"]])
		_:
			# Typ zname (validace prosla), ale smlouva k nemu nema metodu systemu.
			_message(sim, "Not available yet: " + t + ".")


func _player(sim) -> int:
	var serial = sim.get("player_serial")
	return 0 if serial == null else int(serial)


func _system(sim, name: String):
	var target = sim.get(name)
	if target == null and sim.get("systems") is Dictionary:
		target = sim.get("systems").get(name)
	return target


func _route(sim, command: String, system: String, method: String, args: Array) -> void:
	var target = _system(sim, system)
	if target == null or not target.has_method(method):
		_message(sim, "Not available yet: " + command + " -> " + system + "." + method + ".")
		return
	target.callv(method, args)


func _message(sim, text: String) -> void:
	if sim.has_method("push_event"):
		sim.push_event("message", {"text": text, "kind": "system"})
