extends RefCounted
# Herni hodiny a timery (docs/04 §4.2, docs/02 §2.3).
#
# Cas je v ms (int) a plyne JEN pres `advance(ms)` - simulace nikdy necte
# systemovy cas (docs/09 §9.10.4). Timery se vybiraji podle (cas, id), takze
# tick je deterministicky i kdyz ma vic timeru stejny cas; nad nesetridenym
# poradim klicu slovniku se nikdy nerozhoduje (docs/02 §2.3).
#
# `advance` spousti i timery, ktere si callback naplanoval na stejny okamzik -
# dokud nejaky splatny existuje. Pojistka proti smycce je jen na ochranu pred
# timerem, ktery si planuje 0 ms donekonecna.

const Const = preload("res://core/const.gd")
const MAX_TIMERS_PER_ADVANCE: int = 100000

var _now: int = 0
var _next_id: int = 1
var _timers: Dictionary = {}


func now_ms() -> int:
	return _now


func after(delay_ms: int, cb: Callable) -> int:
	var id: int = _next_id
	_next_id += 1
	_timers[id] = {"at": _now + maxi(delay_ms, 0), "cb": cb}
	return id


func cancel(id: int) -> void:
	_timers.erase(id)


func advance(ms: int) -> void:
	_now += maxi(ms, 0)
	var fired: int = 0
	while true:
		var id: int = _earliest_due()
		if id == 0:
			return
		fired += 1
		if fired > MAX_TIMERS_PER_ADVANCE:
			push_warning("Clock.advance: prilis mnoho splatnych timeru v jednom kroku")
			return
		var entry: Dictionary = _timers[id]
		_timers.erase(id)
		var cb: Callable = entry["cb"]
		if cb.is_valid():
			cb.call()


func _earliest_due() -> int:
	# Vybira se minimum podle (cas, id) - poradi klicu slovniku nerozhoduje.
	var best_id: int = 0
	var best_at: int = 0
	for id in _timers.keys():
		var at: int = _timers[id]["at"]
		if at > _now:
			continue
		if best_id == 0 or at < best_at or (at == best_at and id < best_id):
			best_id = id
			best_at = at
	return best_id
