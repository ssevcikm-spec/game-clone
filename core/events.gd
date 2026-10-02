extends RefCounted
# Fronta udalosti sim -> klient (docs/04 §4.4).
#
# Simulace nikdy nevola UI: udalosti jen prida do fronty a klient si je vybere
# jednou za frame pres `drain()`. Fronta neni soucasti stavu (nedostava se do
# `state_hash()`), takze se pri save/load nezapisuje.

var _queue: Array[Dictionary] = []


func push(name: String, data: Dictionary) -> void:
	_queue.append({"name": name, "data": data})


func drain() -> Array[Dictionary]:
	var out: Array[Dictionary] = _queue
	_queue = []
	return out


func clear() -> void:
	_queue.clear()
