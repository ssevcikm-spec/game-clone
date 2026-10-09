extends RefCounted
# Cache klice hrace (2026-10-09, otazka uzivatele "muzeme mit klasickych 60 fps?").
#
# NAMERENO (`_analyza/p30-fps.gd`): frame cas pri 1280x720 byl 31,25 ms a z toho
# **27,3 ms** stravil `_priprav_mesh()` - protoze `_klic_hrace()` pocita klic
# PRUCHODEM CELEHO seznamu (16 000 objektu, kazdy s dotazem do slovniku) a volal
# se KAZDY frame. Vydani davky pritom stoji 0,09 ms.
#
# Klic zavisi JEN na seznamu objektu a na dlazdici hrace, takze se drzi v cache
# (`_klic_seznam`, `_klic_pos`) a pocita se znovu jen pri zmene.
#
# CO SE MERI (chovani, ne pritomnost):
#   1. druhe volani v tomtez stavu UZ NEPOCITA (`klic_hrace_vypoctu` se nezvedne),
#   2. hodnota z cache je PRESNE to, co da primy vypocet (`_sort_key_of_player`)
#      - cache tedy nesmi lhat,
#   3. posun hrace na jinou dlazdici klic PREPOCITA a hodnota zustane spravna,
#   4. nova stavba seznamu (`invalidate()`) klic PREPOCITA - seznam je druhy
#      vstup, na kterem klic zavisi,
#   5. mnoho volani bez zmeny = ZADNY dalsi vypocet (stav se nezmenil).

const Lib = preload("res://tests/lib.gd")
const VIEW_SCRIPT := "res://app/world_view.gd"
const BRITAIN := Vector2i(1495, 1630)


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeMap:
	var land_tile: int = 7
	var land_rect: Rect2i = Rect2i()
	var statics: Dictionary = {}

	func land_at(x: int, y: int) -> int:
		return land_tile if land_rect.has_point(Vector2i(x, y)) else -1

	func z_at(_x: int, _y: int) -> int:
		return 0

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x / 8, y / 8), [])


class FakeTextures:
	var offsets: Dictionary = {}

	func texture(_art_id: int) -> Texture2D:
		return null

	func page_pending(_art_id: int) -> bool:
		return false

	func verze() -> int:
		return 0

	func tick_nacteni() -> int:
		return 0

	func offset(art_id: int) -> Vector2i:
		return offsets.get(art_id, Vector2i.ZERO)

	func texmap(_texmap_id: int) -> Texture2D:
		return null

	func stats() -> Dictionary:
		return {}


class FakeMobile:
	var pos := Vector3i(10, 20, 0)
	var serial: int = 1
	var dir: int = 0
	var hue: int = 0
	var steps: int = 0


func run(t) -> void:
	var cesta: String = _arg("world-view-script", VIEW_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("app.world_view NENI HOTOV: " + cesta + " chybi nebo nejde nacist")
		return

	var map := FakeMap.new()
	map.land_rect = Rect2i(1360, 1520, 400, 300)
	map.statics[Vector2i(182, 200)] = [{"tile": 500, "x": 7, "y": 7, "z": 3, "hue": 0}]
	var textures := FakeTextures.new()

	var scena := Node2D.new()
	scena.name = "ScenaCacheKliceHrace"
	t.root.add_child(scena)
	var cam := Camera2D.new()
	cam.name = "Camera"
	scena.add_child(cam)
	var view = script.new()
	scena.add_child(view)
	view.call("_ready")            # viz past v `tests/cases/world_view.gd`
	if view.get("_sort") == null:
		t._pending("app.world_view: `_ready` neprobehl (`_sort` je null)")
		return
	view.setup(map, textures)
	var hrac := FakeMobile.new()
	view.set_player(hrac)

	# 1) + 2) Cache: druhe volani nepocita a hodnota je stejna jako primy vypocet.
	var pred: int = int(view.klic_hrace_vypoctu)
	var k1: int = int(view.call("_klic_hrace"))
	var k2: int = int(view.call("_klic_hrace"))
	var primy: int = int(view.call("_sort_key_of_player", view.call("_list")))
	t._check(int(view.klic_hrace_vypoctu) == pred + 1,
		"app.world_view: dve volani klice = JEDEN vypocet (vypoctu %d, bylo %d)"
			% [int(view.klic_hrace_vypoctu), pred])
	t._check(k1 == k2 and k1 == primy,
		"app.world_view: klic z cache je presne primy vypocet (%d, %d, primo %d)"
			% [k1, k2, primy])

	# 3) Posun hrace na jinou dlazdici -> klic se PREPOCITA a zustane spravny.
	hrac.pos = Vector3i(11, 21, 0)
	var k3: int = int(view.call("_klic_hrace"))
	var primy3: int = int(view.call("_sort_key_of_player", view.call("_list")))
	t._check(k3 == primy3 and k3 != k1,
		"app.world_view: posun hrace klic prepocita (%d -> %d, primo %d)"
			% [k1, k3, primy3])

	# 4) Nova stavba seznamu -> klic se prepocita (seznam je druhy vstup).
	var pred4: int = int(view.klic_hrace_vypoctu)
	view.get("_chunk").invalidate()
	view.call("_list")
	var k4: int = int(view.call("_klic_hrace"))
	t._check(int(view.klic_hrace_vypoctu) > pred4 and k4 == int(view.call("_sort_key_of_player",
			view.call("_list"))),
		"app.world_view: po prestavbe seznamu se klic prepocita (vypoctu %d -> %d)"
			% [pred4, int(view.klic_hrace_vypoctu)])

	# 5) Sto volani bez zmeny = ZADNY dalsi vypocet (stav se nezmenil).
	var pred5: int = int(view.klic_hrace_vypoctu)
	for i in 100:
		view.call("_klic_hrace")
	t._check(int(view.klic_hrace_vypoctu) == pred5,
		"app.world_view: 100 volani bez zmeny = 0 vypoctu (namEReno %d)"
			% (int(view.klic_hrace_vypoctu) - pred5))

	scena.queue_free()
