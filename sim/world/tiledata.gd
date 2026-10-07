extends RefCounted
# Vlastnosti dlazdic a predmetu (granule world.tiledata, docs/04 §4.2).
# Data: assets/uo/tiles.json (land+item, vystup tiledata.py --extract) a
# data/items.json (hodnoty predmetu). .mul se ve hre NECTE (docs/09 §9.10.2).
#
# DVE ID PROSTRANSTVI (jako ClassicUO, docs/03 §3.6):
#   tile <  0x4000 ... land 0..16383;  tile >= 0x4000 ... predmet
#   (tiledata id predmetu = tile - 0x4000; staticky art = tiledata id + 0x4000)
#
# `value` v tiledata NENI (to pole tam neexistuje, je tam jen `count`) - bere se
# z data/items.json, kde je u zaznamu i `value_source`. Neni to tedy na dvou mistech.

const TILES_PATH := "res://assets/uo/tiles.json"
const ITEMS_PATH := "res://data/items.json"
const ITEM_OFFSET: int = 0x4000

# Poradi poli je schema souboru - viz `layout` v tiles.json.
const LAND_NAME := 2
const LAND_TEXTURE := 1        # index do texmaps.mul (kresleni svahu)
const ITEM_WEIGHT := 1
const ITEM_LAYER := 2
const ITEM_HEIGHT := 7
const ITEM_NAME := 8

var _land: Array = []
var _item: Array = []
var _item_value: Dictionary = {}


func _init() -> void:
	var tiles = _read_json(TILES_PATH)
	if tiles is Dictionary:
		_land = tiles.get("land", [])
		_item = tiles.get("item", [])
	# Prazdno se hlasi - kontrola nad prazdnym seznamem neni uspech (docs/08 §8.6).
	if _land.is_empty() or _item.is_empty():
		push_warning("world.tiledata: chybi data v %s (land %d, item %d) - spust "
			% [TILES_PATH, _land.size(), _item.size()]
			+ "`python tools/uoextract/tiledata.py --extract assets/uo`")
	var items = _read_json(ITEMS_PATH)
	if items is Array:
		for rec in items:
			if rec is Dictionary and rec.has("tile"):
				_item_value[int(rec["tile"])] = int(rec.get("value", 0))
	else:
		push_warning("world.tiledata: %s neni seznam - hodnoty predmetu nejsou" % ITEMS_PATH)


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("world.tiledata: chybi " + path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _record(tile: int) -> Array:
	if is_land(tile):
		return _land[tile] if tile < _land.size() else []
	var idx: int = tile - ITEM_OFFSET
	return _item[idx] if idx >= 0 and idx < _item.size() else []


func _num(tile: int, index: int) -> int:
	var rec := _record(tile)
	# JSON vraci cisla jako float (HANDOFF past #2) - bez int() by do stavu
	# tekl float a rozbil state_hash (docs/09 §9.10.3).
	return int(rec[index]) if index < rec.size() else 0


func is_land(tile: int) -> bool:
	return tile >= 0 and tile < ITEM_OFFSET


func flags(tile: int) -> int:
	return _num(tile, 0)


func height(tile: int) -> int:
	return 0 if is_land(tile) else _num(tile, ITEM_HEIGHT)


func texture(tile: int) -> int:
	# `texture` (TexID) z LAND zaznamu = index do `texmaps.mul`. Kresleni ho
	# pouziva pro SVAHY: rovna plocha se kresli land artem, svah TEXMAPEM
	# natazenym pres ctyrrohy dlazdice (ClassicUO `Land.cs:96-161`,
	# `LandView.cs:58-96`). Bez toho zustava v prechodu vysky seda dira.
	# U predmetu vyznam nema (item zaznam tohle pole nema) - proto 0.
	if not is_land(tile):
		return 0
	return _num(tile, LAND_TEXTURE)


func layer(tile: int) -> int:
	return 0 if is_land(tile) else _num(tile, ITEM_LAYER)


func weight(tile: int) -> int:
	return 0 if is_land(tile) else _num(tile, ITEM_WEIGHT)


func value(item: int) -> int:
	return 0 if is_land(item) else int(_item_value.get(item - ITEM_OFFSET, 0))


func name(tile: int) -> String:
	var rec := _record(tile)
	if rec.is_empty():
		return ""
	var index: int = LAND_NAME if is_land(tile) else ITEM_NAME
	return str(rec[index]) if index < rec.size() else ""
