class_name SimScheduler
extends RefCounted
# sim.scheduler - RIDKE UDALOSTI SVETA (granule `sim.scheduler`, milnik MK).
#
# ⚠ TENHLE MODUL NENI DRUHY TIMER. `core/clock.gd` timery MA (`after`,
# `cancel`, `advance`; otestovane v `tests/cases/clock.gd`). NamEReno
# 2026-10-09 PRED implementaci: zadny produkcni system je ale nevolal -
# `clock()` se v `sim/` pouzival jen pro `now_ms()` a vsech 5 existujicich
# systemu se tickuje kazdy frame. Tenhle modul je proto VARTA NAD CASEM:
#
#   * udalost je `kind` + `payload` (DATA, ne closure) - da se ulozit, obnovit
#     a zapsat do logu. Closure by budoucnost sveta schovala pred savem
#     i pred replayem; tady je videt,
#   * cas se bere z `clock.now_ms()` a udalosti se vyrizuji v `advance_to(now)`
#     v poradi (at_ms, id) - stejne pravidlo jako `core.clock._earliest_due`,
#     aby se dve stejne sekvence nerozesly (docs/02 §2.3),
#   * nikdy se necte `Time`, `OS`, `Input` ani `randf()` (docs/09 §9.10.4).
#
# CO ZATIM NENI (pojmenovane, ne tichy dluh):
#   * **stav planovace JE v `SimWorld.state_hash()` i v save** od 2026-10-09
#     (`register_state_source("scheduler", ...)`) - zmena TVARU hashe byla
#     ZMENA SPECU odsouhlasena uzivatelem a replaye jsou pre-pinute
#     (`tests/replays/README.md`, "Historie hashů"; doklad
#     `_analyza/p30-replay-legacy-hash.gd`). Vlastni case
#     (`tests/cases/scheduler.gd`) meri dal chovani planovace,
#   * **timer wheel z reference se nezavadi.** ModernUO ma 4096 slotu / 8 ms
#     (`_src/modernuo/Server/Timer/TimerWheel.cs:30-131`), ale udalosti tu
#     budou radove stovky - O(n) pruchod ma co merit. Wheel je optimalizace,
#     ktera by dnes nemela co zmerit (docs/09 §9.10: nepridavat "vylepseni"
#     bez mereni).
#   * **nikdo do nej zatim neplanuje.** Zije v `SimWorld.tick()`, ale prvni
#     uzivatel budou `world.spawn` (restock, doplnovani) a `sim.offline`
#     (doběh sveta). Do te doby je to mechanismus, ne funkce - a je to
#     pojmenovane tady, aby to nezapadlo.

const MAX_EVENTS_PER_ADVANCE: int = 10000

var _clock
var _next_id: int = 1
var _events: Dictionary = {}


func _init(clock = null) -> void:
	_clock = clock


func schedule(kind: String, at_ms: int, payload: Dictionary = {}) -> int:
	# Naplanuje udalost na absolutni cas sveta (ms). Vraci id pro `cancel`.
	var id: int = _next_id
	_next_id += 1
	_events[id] = {"kind": kind, "at": maxi(at_ms, 0), "payload": payload.duplicate(true)}
	return id


func schedule_in(kind: String, delay_ms: int, payload: Dictionary = {}) -> int:
	return schedule(kind, now_ms() + maxi(delay_ms, 0), payload)


func cancel(id: int) -> void:
	# Zrusena udalost se nikdy nevyrizi; `pending()` o ni klesne.
	_events.erase(id)


func pending() -> int:
	return _events.size()


func advance_to(now_ms: int) -> Array[Dictionary]:
	# Vyrizeni vsech splatnych udalosti v poradi (at_ms, id). Vraci, co se stalo,
	# aby to volajici mohl predat dal (log, spawn, restock) - planovac sam
	# nic nevykonava, jen rika "ted a v tomto poradi".
	var out: Array[Dictionary] = []
	var fired: int = 0
	while true:
		var id: int = _earliest_due(now_ms)
		if id == 0:
			break
		fired += 1
		if fired > MAX_EVENTS_PER_ADVANCE:
			push_warning("SimScheduler.advance_to: prilis mnoho splatnych udalosti v jednom kroku")
			break
		var e: Dictionary = _events[id]
		_events.erase(id)
		out.append({"id": id, "kind": e["kind"], "at": e["at"], "payload": e["payload"]})
	return out


func state() -> Dictionary:
	# Kanonicka podoba pro save/hash: udalosti serazene podle (at_ms, id),
	# aby dve stejne budoucnosti daly stejny zapis a nezalezelo na poradi klicu
	# slovniku (docs/02 §2.3).
	var ids: Array = _events.keys()
	ids.sort()
	var rows: Array = []
	for id in ids:
		var e: Dictionary = _events[id]
		rows.append({"id": id, "kind": e["kind"], "at": e["at"], "payload": e["payload"]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["at"] == b["at"]:
			return a["id"] < b["id"]
		return a["at"] < b["at"])
	return {"next_id": _next_id, "events": rows}


func restore(d: Dictionary) -> void:
	_events.clear()
	_next_id = maxi(int(d.get("next_id", 1)), 1)
	var rows = d.get("events", [])
	if not (rows is Array):
		return
	for row in rows:
		if not (row is Dictionary):
			continue
		var id: int = int(row.get("id", 0))
		if id <= 0:
			continue
		_events[id] = {
			"kind": str(row.get("kind", "")),
			"at": int(row.get("at", 0)),
			"payload": row.get("payload", {}),
		}


func now_ms() -> int:
	return int(_clock.now_ms()) if _clock != null else 0


func _earliest_due(now_ms_value: int) -> int:
	# Minimum podle (cas, id) - poradi klicu slovniku nikdy nerozhoduje.
	var best_id: int = 0
	var best_at: int = 0
	for id in _events.keys():
		var at: int = _events[id]["at"]
		if at > now_ms_value:
			continue
		if best_id == 0 or at < best_at or (at == best_at and id < best_id):
			best_id = id
			best_at = at
	return best_id
