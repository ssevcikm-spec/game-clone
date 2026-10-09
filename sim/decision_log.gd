extends RefCounted
# sim.decision_log - VIDET DO UVAZOVANI POSTAVY (granule `sim.decision_log`, MK).
#
# Zadani uzivatele 2026-10-09: „rad bych videl, jak by si hra mohla hrat sama,
# abych videl do uvazovani te postavy" (`ROZHODNUTI-2026-10-09-SMER.md` §2 D3).
#
# PROC SAMOSTATNY MODUL: `sim.policy` vi, KTERE pravidlo platilo a proc ne -
# ale je to cista funkce stavu (`evaluate` nic nedrzi). Kdo chce historii
# ("co se rozhodlo a z ceho"), potrebuje misto, kam se to zapise. Tim mistem
# je tenhle log: `decision()` a `skipped()` zapisuji DUVOD, `since(tick)` vraci
# krok za krokem, co se od `tick` stalo.
#
# KUDY TO VIDI HRAC: log je napojeny na `push_event` sveta (sink), takze kazda
# ZMENA rozhodnuti jde do fronty jako udalost `message` a vypise ji `ui.journal`
# (ta se NEEDITUJE - je to tenky klient s jednim textovym kanalem, `kind`
# zustava `system`). Text je ANGLICKY (docs/01 §1.6 - texty pro UI), takze se
# do zurnalu pozna, co prislo od politiky a co od hrace.
#
# THROTTLE: do zurnalu jde jen ZMENA (rule_id + duvod), ne kazdy tik - jinak
# by pravidlo, ktere plati kazdy tik, utopilo zurnal. Zapisuje se ale VSECHNO:
# `entries()`/`since()` maji i to, co se do zurnalu neposlalo.
#
# CO TO NENI: neni to stav sveta. Do `state_hash()` ani do save nepatri
# (v save by rostl s kazdym tikem a hash by zavisel na historii, ne na stavu;
# `docs/04 §4.7`). Je to diagnostika - a je to pojmenovane tady, ne tichy dluh.

const MAX_ENTRIES: int = 256

var _entries: Array[Dictionary] = []
var _dropped: int = 0
var _tick: int = 0
var _sink = null              # objekt s `push_event(name, data)` (SimWorld)
var _published: String = ""   # naposledy publikovany text (throttle)


func _init(sink = null) -> void:
	# `sink` je volitelny: bez nej log funguje, jen se nic nezobrazuje.
	_sink = sink


func set_tick(t: int) -> void:
	# Tik, kterym se zapisy razitkuji (`since()` ho pouziva). Nastavuje
	# volajici (SimWorld pred kazdym krokem) - log si cas sam NECTE.
	_tick = int(t)


func tick() -> int:
	return _tick


func decision(rule_id: String, why: String, state_ref = "") -> Dictionary:
	# Rozhodnuti, ktere se provede: ktere pravidlo, proc a z ceho (`state_ref`
	# je otisk stavu - u `sim.executor` hash stavu, ze ktereho se rozhodlo).
	return _record("decision", rule_id, why, state_ref)


func skipped(rule_id: String, why: String) -> Dictionary:
	# Pravidlo, ktere se NEVYHODNOTILO - s duvodem ("stav nezna: inventory",
	# "item 3717: 0 < 1", "priorita niz"). Ticho by znamenalo, ze se nedeje nic.
	return _record("skipped", rule_id, why, "")


func since(tick_value: int) -> Array[Dictionary]:
	# Zaznamy od `tick_value` VCETNE (aby se dalo plynule navazovat).
	var out: Array[Dictionary] = []
	for e in _entries:
		if int(e.get("tick", 0)) >= int(tick_value):
			out.append(e.duplicate(true))
	return out


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func size() -> int:
	return _entries.size()


func dropped() -> int:
	# Kolik zaznamu vypadlo pri prekroceni `MAX_ENTRIES` (neni to ticha ztrata).
	return _dropped


func clear() -> void:
	_entries.clear()
	_dropped = 0
	_published = ""


func _record(kind: String, rule_id: String, why: String, state_ref) -> Dictionary:
	var e: Dictionary = {
		"tick": _tick,
		"kind": kind,
		"rule_id": rule_id,
		"why": why,
		"state_ref": state_ref,
	}
	_entries.append(e)
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
		_dropped += 1
	_publish(e)
	return e.duplicate(true)


func _publish(e: Dictionary) -> void:
	if _sink == null or not _sink.has_method("push_event"):
		return
	var text: String = ""
	if str(e["kind"]) == "decision":
		text = "policy: " + str(e["rule_id"]) + " -> " + str(e["why"])
	else:
		text = "policy: " + str(e["rule_id"]) + " skipped: " + str(e["why"])
	if text == _published:
		return
	_published = text
	_sink.push_event("message", {"text": text, "kind": "system"})
