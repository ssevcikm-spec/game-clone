extends RefCounted
# Kreslici seznam pro viditelne bloky (granule render.chunk; docs/02 §2.4).
#
# Postup: pro kazdou dlazdici viditelne oblasti se prida `land` s jeho `z`;
# pro kazdy dotceny blok 8x8 se projdou VSICHNI jeho statiky a prevedou se
# z lokalnich `x`,`y` (0..7) na svetove. Hotovy seznam se preda
# `render.sort.draw_order`, takze se kresli v poradi (x+y) -> vrstva -> `z`.
# Kreslici uzel ho jen projde v tom poradi: `z_index` na to pouzit NELZE,
# klic roste do milionu a Godot bere jen -4096..4096 (docs/02 past P21).
#
# CACHE: seznam je pro dany pohled hotovy; `invalidate()` ho zahodi (vola ho
# `app/world_view.gd` pri zmene pohledu, pozdeji `sim.movement` pri zmene
# bloku). Textury se v seznamu NEDRZI - drzi je `render.textures` se stropem
# pameti; kdyby je drzel seznam, strop by nic neomezoval (viz hlavicka tam).
#
# TVAR PRVKU (je to zaroven vstup do `render.sort`, ktery chce `{kind,x,y,z}`):
#   {"kind": "land"|"static", "x": int, "y": int, "z": int,
#    "art_id": int, "offset": Vector2i}
# `offset` je posun z manifestu (`ox`,`oy`), ktery se odecte od dlazdice.
#
# Pouziti:
#   var chunk = Chunk.new(map, textures)
#   for obj in chunk.visible(center, 64, 48): ...

const Sort = preload("res://render/sort.gd")
const Iso = preload("res://core/iso.gd")
const Const = preload("res://core/const.gd")
const ITEM_OFFSET: int = 0x4000

var _map = null
var _textures = null
var _iso
var _sort
var _list: Array = []
var _cover: Rect2i = Rect2i()
var _built: bool = false
var _counts: Dictionary = {"land": 0, "static": 0}


func _init(map, textures) -> void:
	_map = map
	_textures = textures
	_iso = Iso.new()
	_sort = Sort.new()


func invalidate() -> void:
	_built = false


func is_built() -> bool:
	return _built


func counts() -> Dictionary:
	return _counts.duplicate()


func cover() -> Rect2i:
	return _cover


func screen_position(obj: Dictionary) -> Vector2:
	# Kam presne se prvek kresli. `core.iso.to_screen` vraci horni vrchol
	# diamantu dlazdice; art statiku ma `ox`,`oy` tak, ze se od dlazdice
	# ODECITA (vzorec je v hlavicce `tools/uoextract/atlas.py`). Je to tady
	# (a ne v kreslicim uzlu), aby se geometrie dala merit testem.
	return _iso.to_screen(int(obj["x"]), int(obj["y"]), int(obj["z"])) \
		- Vector2(obj["offset"])


func visible(center: Vector2i, tiles_x: int, tiles_y: int) -> Array:
	var want := Rect2i(center.x - tiles_x / 2, center.y - tiles_y / 2, tiles_x, tiles_y)
	if _built and want == _cover:
		return _list
	_cover = want
	_list = _build(want)
	_built = true
	return _list


func _build(area: Rect2i) -> Array:
	var objects: Array = []
	var counts := {"land": 0, "static": 0}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var land: int = _map.land_at(x, y)
			if land < 0:
				continue
			objects.append({"kind": "land", "x": x, "y": y, "z": _map.z_at(x, y),
				"art_id": land, "offset": Vector2i.ZERO})
			counts["land"] += 1
	var first: Vector2i = _iso.block_of(area.position.x, area.position.y)
	var last: Vector2i = _iso.block_of(area.end.x - 1, area.end.y - 1)
	for by in range(first.y, last.y + 1):
		for bx in range(first.x, last.x + 1):
			var base_x: int = bx * Const.BLOCK_SIZE
			var base_y: int = by * Const.BLOCK_SIZE
			for record in _map.statics_at(base_x, base_y):
				var sx: int = base_x + int(record["x"])
				var sy: int = base_y + int(record["y"])
				if not area.has_point(Vector2i(sx, sy)):
					continue
				var art_id: int = int(record["tile"]) + ITEM_OFFSET
				objects.append({"kind": "static", "x": sx, "y": sy,
					"z": int(record["z"]), "art_id": art_id,
					"offset": _textures.offset(art_id)})
				counts["static"] += 1
	_counts = counts
	return _sort.draw_order(objects)
