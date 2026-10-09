extends RefCounted
# sim.executor - VYKONAVATEL POLITIKY (granule `sim.executor`, milnik MK).
#
# CO TO JE (treti vrstva z D3, `ROZHODNUTI-2026-10-09-SMER.md` §2): `sim.policy`
# vi, KTERE pravidlo plati; vykonavatel z nej dela `Command` pro simulaci.
# Rozhrani jsou dve veci: `step(state) -> [Command]` a `status()`.
#
# TVRDE PRAVIDLO (docs/04 §4.1): vykonavatel NIKDY nesaha na stav. Stav jen
# CTE (preda ho politice, ze stavu udela otisk pro log) a vsechno, co se ma
# stat, vyjde jako `Command` do fronty sveta. Kdyby menil stav primo, prestal
# by platit replay i hash a hra by "rozhodla za hrace" (D3).
#
# ZASTAVENI JE VYSLEDEK, NE TICHO: kdyz neni co delat nebo to nejde, `step()`
# vrati prazdny seznam a `status()` rekne DUVOD (`no policy loaded`,
# `no rule matched`, `waiting: ... ms`, `invalid command (...)`). Prechodne
# duvody ("nic se nema delat", "ceka se") se v dalsim kroku vyhodnocuji znovu;
# trvale zastavi jen akce `stop` (nebo `stop()` zvenci). Vse se duplikuje do
# `sim.decision_log`, aby to bylo videt i v zurnalu.
#
# KDO TO VOLA: `SimWorld.tick()` - ale JEN kdyz je politika nactena (bez ni je
# cely krok no-op, takze se nic nemeni na replayich). Vykonavatel sam o svete
# nevi; dostava stav argumentem, proto ho jde testovat bez sceny.
#
# CO ZATIM NENI (pojmenovane, ne tichy dluh): akce se prevadi 1:1 na `Command`
# (zadne plánovani cesty - `move` je jeden krok, ne "dojdi tam"); `seq` je
# vlastni pocitadlo vykonavatele (smlouva `sim.commands` ho jinak nepouziva).

const SimCommands = preload("res://sim/commands.gd")
const SimHash = preload("res://core/hash.gd")

# Akce politiky -> `Command` (jmena musi sedet s tabulkou v `sim/commands.gd`).
const ACTION_COMMAND: Dictionary = {
	"move": "move",
	"use": "use",
	"interact": "interact",
	"craft": "craft",
	"vendor": "vendor",
	"say": "say",
}
# Akce, ktere prikaz NEVYROBI, ale musi se rict, co znamenaji (`stop`/`wait`
# nejsou tiche cekani - `wait` rekne, na co se ceka).
const CONTROL_ACTIONS: Array[String] = ["wait", "stop"]

var _policy = null
var _log = null
var _commands
var _hash
var _seq: int = 0
var _sent: int = 0
var _stopped: bool = false
var _stop_reason: String = ""
var _last_rule: String = ""
var _last_why: String = ""


func _init(policy = null, log = null) -> void:
	_policy = policy
	_log = log
	_commands = SimCommands.new()
	_hash = SimHash.new()


func set_policy(policy) -> void:
	# Vymena politiky za behu (nacteni jinych pravidel) - stav zastaveni se tim
	# maze, protoze duvod se vztahoval k predchozim pravidlum.
	_policy = policy
	_stopped = false
	_stop_reason = ""


func step(state) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _policy == null:
		# Neni to "zastaveno" - politika muze prijit pozdeji; je to jen duvod.
		_note("no policy loaded")
		return out
	if _stopped:
		# Zastaveny vykonavatel se nepta znovu; duvod zustava ve `status()`.
		return out
	var decisions: Array = _policy.evaluate(state)
	_log_skipped()
	if decisions.is_empty():
		# PRECHODNY stav: pravidla se vyhodnoti znovu v dalsim kroku (podminka
		# se muze zmenit - napr. casove okno). Trvale zastaveni je jen `stop`.
		_note("no rule matched")
		return out
	var top: Dictionary = decisions[0]
	_last_rule = str(top.get("rule_id", ""))
	_last_why = str(top.get("why", ""))
	# Nizsi priorita se zahodi S DUVODEM - v logu musi byt videt, ze pravidlo
	# platilo a neprovedlo se kvuli vyssi priorite (ne ze neplatilo).
	for i in range(1, decisions.size()):
		_skip(str(decisions[i].get("rule_id", "")), "lower priority (decided: " + _last_rule + ")")
	var action = top.get("action", {})
	if not (action is Dictionary):
		_stop("action is not a dictionary")
		return out
	var kind: String = str(action.get("kind", ""))
	var args = action.get("args", {})
	if not (args is Dictionary):
		args = {}
	if kind in CONTROL_ACTIONS:
		_log_decision(state)
		if kind == "stop":
			_stop(str(args.get("why", "rule asked to stop")))
		else:
			# `wait` neni ticho: rekne se, na co se ceka (a v dalsim kroku se
			# vyhodnocuje znovu - cekani neni trvale zastaveni).
			_note("waiting: " + str(args.get("ms", 0)) + " ms")
		return out
	# Neznamou akci odmitne uz `sim.policy` pri `load()` (slovnik `ACTION_KINDS`).
	# Kdyby sem prisla z jineho zdroje, `_to_command` vrati prazdny prikaz
	# a `sim.commands.validate` ho odmitne - viditelne, ne tise.
	var command: Dictionary = _to_command(kind, args)
	# Vykonavatel vysle JEN platny `Command` - kontrola je tady, ne az ve svete
	# (`sim.commands.validate` vraci `ok` + duvod, ne vyjimku).
	var verdict: Dictionary = _commands.validate(command)
	if not bool(verdict.get("ok", false)):
		_stop("invalid command (" + str(verdict.get("reason", "")) + ")")
		_skip(_last_rule, "invalid command (" + str(verdict.get("reason", "")) + ")")
		return out
	_sent += 1
	_stop_reason = ""
	_log_decision(state)
	out.append(command)
	return out


func status() -> Dictionary:
	# Meritelny stav vykonavatele: co dela, proc stoji a kolik prikazu vydal.
	return {
		"running": _policy != null and not _stopped,
		"stopped": _stopped,
		"reason": _stop_reason,
		"rule": _last_rule,
		"why": _last_why,
		"commands_sent": _sent,
		"seq": _seq,
	}


func stop(reason: String) -> void:
	# Zastaveni zvenci (napr. hrac prevzal rizeni). Duvod se zapise i do logu.
	_stopped = true
	_stop_reason = reason
	_skip("executor", reason)


func resume() -> void:
	_stopped = false
	_stop_reason = ""


func commands_sent() -> int:
	return _sent


# -- vnitrni ---------------------------------------------------------------

func _to_command(kind: String, args: Dictionary) -> Dictionary:
	# Prevod akce na `Command` (tabulka `sim/commands.gd` §4.3). Hodnoty z JSONu
	# jsou float, proto se vsechno pretypovava - `validate` kontroluje typy.
	# Neznamy druh akce vraci PRAZDNY prikaz: `validate` ho odmitne a `step`
	# se zastavi s duvodem (zadna pulka prikazu se neposila).
	if not ACTION_COMMAND.has(kind):
		return {}
	match kind:
		"move":
			_seq += 1
			return {
				"t": "move",
				"dir": int(args.get("dir", 0)),
				"run": bool(args.get("run", false)),
				"seq": _seq,
			}
		"use":
			return {"t": "use", "serial": int(args.get("serial", 0))}
		"interact":
			return {"t": "interact", "target": args.get("target", {})}
		"craft":
			return {
				"t": "craft",
				"recipe": int(args.get("recipe", 0)),
				"count": int(args.get("count", 1)),
			}
		"vendor":
			return {
				"t": "vendor",
				"action": str(args.get("action", "buy")),
				"vendor": int(args.get("vendor", 0)),
				"lines": args.get("lines", []),
			}
		"say":
			return {"t": "say", "text": str(args.get("text", ""))}
	return {}


func _log_decision(state) -> void:
	if _log == null or not _log.has_method("decision"):
		return
	# `state_ref` = otisk stavu, ze ktereho se rozhodlo: v logu se da dohledat,
	# z ceho rozhodnuti vzniklo (a dva ruzne stavy maji dva otisky).
	var otisk: String = ""
	if state != null:
		otisk = _hash.of_state([state]).substr(0, 16)
	_log.decision(_last_rule, _last_why, otisk)


func _note(reason: String) -> void:
	# Prechodny duvod ("nic se nema delat", "ceka se"): vykonavatel zustava
	# zapnuty a v dalsim kroku se vyhodnocuje znovu. Trvale je jen `_stop()`.
	_stop_reason = reason
	_skip("executor", reason)


func _log_skipped() -> void:
	if _policy == null or not _policy.has_method("last_skipped"):
		return
	for row in _policy.last_skipped():
		if row is Dictionary:
			_skip(str(row.get("rule_id", "")), str(row.get("why", "")))


func _skip(rule_id: String, why: String) -> void:
	if _log != null and _log.has_method("skipped"):
		_log.skipped(rule_id, why)


func _stop(reason: String) -> void:
	_stopped = true
	_stop_reason = reason
	_skip("executor", reason)
