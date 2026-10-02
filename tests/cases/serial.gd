extends RefCounted
# core.serial - pridělování id (docs/04 §4.2, docs/11 §11.7).
# Kriterium z promptu: 1000 id je unikatnich a klasifikace sedi.
# Hranice: mobile >= 0x40000000, item < 0x40000000, 0 = zadna entita.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://core/serial.gd")
	if script == null:
		t._pending("core.serial NENI HOTOVA: core/serial.gd chybi")
		return
	var serials = script.new()

	var seen: Dictionary = {}
	var unique: bool = true
	var types_ok: bool = true
	var items: int = 0
	for i in 1000:
		var serial: int = serials.next()
		if typeof(serial) != TYPE_INT:
			types_ok = false
		if seen.has(serial):
			unique = false
		seen[serial] = true
		if serials.is_item(serial):
			items += 1
	t._check(unique, "core.serial: 1000 pridelenych id je unikatnich")
	t._check(types_ok, "core.serial: next() vraci int (zadny float ve stavu)")
	t._check(items == 1000, "core.serial: id z rady od 1 jsou itemy (namEReno %d z 1000)" % items)
	t._check(not seen.has(0), "core.serial: serial 0 se neprideluje (0 = zadna entita)")

	t._check(serials.is_mobile(0x40000000), "core.serial: 0x40000000 je mobile")
	t._check(serials.is_mobile(0x40000001) and not serials.is_item(0x40000001),
		"core.serial: 0x40000001 je mobile, ne item")
	t._check(serials.is_item(0x3FFFFFFF) and not serials.is_mobile(0x3FFFFFFF),
		"core.serial: 0x3FFFFFFF je item, ne mobile")
	t._check(not serials.is_item(0) and not serials.is_mobile(0),
		"core.serial: 0 neni ani item, ani mobile")

	serials.reset(0x40000000)
	t._check(serials.next() == 0x40000000, "core.serial: reset(0x40000000) -> dalsi id je mobile")
	t._check(serials.is_mobile(serials.next()), "core.serial: po resetu se priděluji mobily")
	serials.reset(1)
	t._check(serials.next() == 1, "core.serial: reset(1) vrati radu na zacatek")
