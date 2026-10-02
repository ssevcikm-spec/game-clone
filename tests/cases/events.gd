extends RefCounted
# core.events - fronta udalosti sim -> klient (docs/04 §4.4).
# Kriterium z promptu: push 3 udalosti, drain vraci 3 v poradi a fronta je prazdna.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://core/events.gd")
	if script == null:
		t._pending("core.events NENI HOTOVA: core/events.gd chybi")
		return
	var queue = script.new()
	t._check(queue.drain().is_empty(), "core.events: prazdna fronta vraci prazdne pole")

	queue.push("message", {"text": "You see a forge.", "kind": "system"})
	queue.push("item_added", {"serial": 7, "tile": 0x1BEF})
	queue.push("sound", {"id": 0x0035, "x": 1495, "y": 1630, "z": 0})
	var got: Array = queue.drain()
	t._check(got.size() == 3, "core.events: drain() vratil %d udalosti (cekano 3)" % got.size())
	if got.size() == 3:
		t._check(got[0]["name"] == "message" and got[1]["name"] == "item_added"
			and got[2]["name"] == "sound", "core.events: poradi udalosti se zachovava")
		t._check(got[1]["data"]["serial"] == 7, "core.events: data udalosti zustavaji u sebe")
	t._check(queue.drain().is_empty(), "core.events: po drain() je fronta prazdna")

	queue.push("message", {"text": "a"})
	queue.clear()
	t._check(queue.drain().is_empty(), "core.events: clear() frontu vyprázdní")
