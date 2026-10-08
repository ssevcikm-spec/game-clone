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
# LAND NAVIC (2026-10-07, svahy): `texmap` (TexID z tiledata) a `z_corners`
# [horni, pravy, levy, dolni] = vysky rohu dlazdice. Roh pouziva vysku
# SOUSEDNI dlazdice (vychodni pro pravy, jizni pro levy, jihovychodni pro
# dolni) - presne jako ClassicUO (`Land.cs:113-121` `ApplyStretch`). Kresleni
# z toho pozna, ze dlazdice lezi na SVAHU, a natáhne pres ni texmap; rovna
# plocha se kresli dal land artem. Bez toho zustavala v prechodu vysky seda
# dira (uzivatel: "kde je svah, tam neni tile").
#
# Pouziti:
#   var chunk = Chunk.new(map, textures)          # bez tiledata: texmap = 0
#   for obj in chunk.visible(center, 64, 48): ...

const Sort = preload("res://render/sort.gd")
const Iso = preload("res://core/iso.gd")
const Const = preload("res://core/const.gd")
const TiledataScript = preload("res://sim/world/tiledata.gd")
const ITEM_OFFSET: int = 0x4000
# `IsBackground` v tiledata: dlazdice je PODLAHA, ne prekazka. ClassicUO ji
# v `PriorityZ` odecita 1 (`Chunk.cs:246-272`), takze plocha mostu jde PRED
# jeho zabradli - bez toho se na molu u Britannie kreslilo zabradli pod
# dlazdicemi (namEReno 2026-10-07).
const F_BACKGROUND: int = 0x00000001

var _map = null
var _textures = null
var _tiledata = null               # muze byt null: pak se texmap nedava
var _iso
var _sort
var _list: Array = []
var _cover: Rect2i = Rect2i()
var _built: bool = false
var _counts: Dictionary = {"land": 0, "static": 0}


func _init(map, textures, tiledata = null) -> void:
	_map = map
	_textures = textures
	_tiledata = tiledata
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
	# ⚠ P20 (17. session): cena prestavby seznamu je 85-250 ms (podle velikosti
	# okna) a je to duvod, proc se prestavba ODDALUJE (`RECENTER_TILES` ve
	# `app/world_view`). Mereni: `_analyza/p20-kadence.gd`.
	_list = _build(want)
	_built = true
	return _list


func _build(area: Rect2i) -> Array:
	var objects: Array = []
	var counts := {"land": 0, "static": 0}
	var zrohy: PackedInt32Array = _z_grid(area)
	var sirka: int = area.size.x + 1
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var land: int = _map.land_at(x, y)
			if land < 0:
				continue
			var radek: int = (y - area.position.y) * sirka + (x - area.position.x)
			var z: int = zrohy[radek]
			objects.append({"kind": "land", "x": x, "y": y, "z": z,
				"art_id": land, "offset": Vector2i.ZERO,
				"texmap": _tiledata.texture(land) if _tiledata != null else 0,
				"z_corners": [z, zrohy[radek + 1], zrohy[radek + sirka],
					zrohy[radek + sirka + 1]]})
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
				var z_statiku: int = int(record["z"])
				objects.append({"kind": "static", "x": sx, "y": sy,
					"z": z_statiku, "art_id": art_id,
					"priority_z": _priorita(art_id, z_statiku),
					"offset": _textures.offset(art_id)})
				counts["static"] += 1
	_counts = counts
	return _sort.draw_order(objects)


func _priorita(art_id: int, z: int) -> int:
	# Poradova vyska pro RAZENI, ne pro kresleni (ClassicUO `PriorityZ`,
	# `Chunk.cs:246-272`): podlaha (`IsBackground`) -1, statik s vyskou +1.
	# Bez tiledata (konstruktor ji smi dostat `null`) se vrati `z` - razeni pak
	# zustane na chovani pred 2026-10-07, jen se o nem vi.
	if _tiledata == null:
		return z
	var v: int = z
	if _tiledata.flags(art_id) & F_BACKGROUND != 0:
		v -= 1
	if _tiledata.height(art_id) != 0:
		v += 1
	return v


func _z_grid(area: Rect2i) -> PackedInt32Array:
	# Vysky ROHU oblasti: (sirka+1) x (vyska+1) hodnot. Sousede se ctou JEDNOU
	# na cely pohled, ne ctyrikrat na kazdou dlazdici - pri 3 000 dlazdicich by
	# to bylo 12 000 dotazu do mapy pri kazdem prestavem seznamu (a ten se
	# prekresluje pri kazdem kroku chuze).
	# Mrizka ma o 1 radek/sloupec vic, aby mela kazda dlazdice i sve prave/dolni
	# rohy (ty patri sousedovi).
	var sirka: int = area.size.x + 1
	var out := PackedInt32Array()
	out.resize(sirka * (area.size.y + 1))
	for y in range(area.position.y, area.end.y + 1):
		for x in range(area.position.x, area.end.x + 1):
			out[(y - area.position.y) * sirka + (x - area.position.x)] = int(_map.z_at(x, y))
	return out
