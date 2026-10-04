extends RefCounted
# Bloky mapy 8x8 (granule world.map; format docs/03 §3.4, mereno 2026-10-02).
#
# KLICOVA MATEMATIKA - nesmi zustat v hlave, ma byt v testu:
#   index bloku je x-MAJOR `bx * blocks_y + by`. Obracene poradi `by * blocks_x + bx`
#   da prazdny blok Britainu (0 statiku misto 60) a pruhovany nahled.
#   bunka v .land je 3 B `[u16 tile][i8 z]` za 4B hlavickou, 64 bunek na blok,
#   vevnitr po radku: `inner = (y % 8) * 8 + (x % 8)`.
#   zaznam statiky je 7 B `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
#
# Data se ctou z assets/uo/world/, nikdy z instalace UO za behu (docs/09 §9.10.2).
# Chybejici data se HLASI - prazdna mapa neni uspech (docs/08 §8.6).

const Const = preload("res://core/const.gd")

const META_PATH := "res://assets/uo/world/map0.meta.json"
const LAND_PATH := "res://assets/uo/world/map0.land"
const STATICS_INDEX_PATH := "res://assets/uo/world/map0.statics.idx"
const STATICS_PATH := "res://assets/uo/world/map0.statics.bin"

const CELL_BYTES := 3             # [u16 tile][i8 z]
const LAND_HEADER_BYTES := 4      # hlavicka bloku v .land
const STATIC_ENTRY_BYTES := 7
const STATIC_INDEX_BYTES := 12    # [u32 offset][u32 length][u32 extra]
const EMPTY_BLOCK := 0xFFFFFFFF   # nepouzity blok v .idx
const MAX_CACHED_BLOCKS := 2048   # LRU: 2048 * (192 B + statiky)
const OFF_MAP := -1               # land_at/z_at mimo mapu

var _blocks_x := 0
var _blocks_y := 0
var _land_tile_max := 0
var _land: FileAccess = null
var _index: FileAccess = null
var _bin: FileAccess = null
var _cache: Dictionary = {}       # index bloku -> {cells, statics, used}
var _clock := 0                   # poradi pristupu pro LRU


func _init() -> void:
	if _load_meta():
		_land = _open(LAND_PATH)
		_index = _open(STATICS_INDEX_PATH)
		_bin = _open(STATICS_PATH)


func _load_meta() -> bool:
	if not FileAccess.file_exists(META_PATH):
		push_warning("world.map: chybi " + META_PATH + " - spust "
			+ "python tools/uoextract/worldmap.py --extract assets/uo/world")
		return false
	var meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not (meta is Dictionary):
		push_warning("world.map: " + META_PATH + " neni objekt")
		return false
	_blocks_x = int(meta.get("blocks_x", 0))
	_blocks_y = int(meta.get("blocks_y", 0))
	_land_tile_max = int(meta.get("land_tile_max", 0))
	return _blocks_x > 0 and _blocks_y > 0


func _open(path: String) -> FileAccess:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("world.map: nejde otevrit " + path + " (err %d)"
			% FileAccess.get_open_error())
	return file


func width() -> int:
	return _blocks_x * Const.BLOCK_SIZE


func height() -> int:
	return _blocks_y * Const.BLOCK_SIZE


func land_tile_max() -> int:
	return _land_tile_max


func is_loaded(bx: int, by: int) -> bool:
	return _cache.has(bx * _blocks_y + by)


func load_block(bx: int, by: int) -> void:
	var entry = _entry(bx, by)
	if entry != null:
		entry["used"] = _clock


func land_at(x: int, y: int) -> int:
	# Záporné x je hlášeno, nezkračováno: `-1 / 8` je v GDScriptu 0, takže
	# bez této kontroly by `-1` spadlo do bloku 0 a na záporný offset.
	if x < 0 or y < 0:
		return OFF_MAP
	var entry = _entry(x / Const.BLOCK_SIZE, y / Const.BLOCK_SIZE)
	if entry == null:
		return OFF_MAP
	var cells: PackedByteArray = entry["cells"]
	return cells.decode_u16(_cell_at(x, y) * CELL_BYTES)


func z_at(x: int, y: int) -> int:
	if x < 0 or y < 0:
		return OFF_MAP
	var entry = _entry(x / Const.BLOCK_SIZE, y / Const.BLOCK_SIZE)
	if entry == null:
		return OFF_MAP
	var cells: PackedByteArray = entry["cells"]
	return cells.decode_s8(_cell_at(x, y) * CELL_BYTES + 2)


func statics_at(x: int, y: int) -> Array:
	# Zaznamy celeho bloku (souřadnice v bloku nejsou vratne - hledaji se podle
	# `statics_at(x, y)`, ktere znamo, ve kterem bloku se divas).
	var out: Array = []
	if x < 0 or y < 0:
		return out
	var entry = _entry(x / Const.BLOCK_SIZE, y / Const.BLOCK_SIZE)
	if entry != null:
		out = entry["statics"]
	return out


func _cell_at(x: int, y: int) -> int:
	return (y % Const.BLOCK_SIZE) * Const.BLOCK_SIZE + (x % Const.BLOCK_SIZE)


func _entry(bx: int, by: int):
	# Blok, ktery je potreba, se nacte; odlehceny se az kdyz je treba (LRU).
	if bx < 0 or by < 0 or bx >= _blocks_x or by >= _blocks_y or _land == null:
		return null
	var key := bx * _blocks_y + by
	_clock += 1
	var entry = _cache.get(key)
	if entry != null:
		entry["used"] = _clock
		return entry
	var want: int = Const.BLOCK_SIZE * Const.BLOCK_SIZE * CELL_BYTES
	# +LAND_HEADER_BYTES je povinny: po seeku na `key * 196` by se do bufferu
	# veslo 4B hlavicka a posledni 4B bloku by chybely (vsechny bunky o 4 B
	# vedle - zmereno 2026-10-04: land id lezlo az do 65521 misto 0..0x3FFF).
	_land.seek(key * (LAND_HEADER_BYTES + want) + LAND_HEADER_BYTES)
	var cells := _land.get_buffer(want)
	if cells.size() != want:
		push_warning("world.map: blok %d,%d se neprecetl (%d B z %d)"
			% [bx, by, cells.size(), want])
		return null
	entry = {"cells": cells, "statics": _statics(key), "used": _clock}
	_cache[key] = entry
	_evict()
	return entry


func _statics(key: int) -> Array:
	var out: Array = []
	if _index == null or _bin == null:
		return out
	_index.seek(key * STATIC_INDEX_BYTES)
	var head := _index.get_buffer(STATIC_INDEX_BYTES)
	if head.size() < STATIC_INDEX_BYTES:
		return out
	var offset := head.decode_u32(0)
	var length := head.decode_u32(4)
	if offset == EMPTY_BLOCK or length == 0:
		return out
	_bin.seek(offset)
	var data := _bin.get_buffer(length)
	for i in data.size() / STATIC_ENTRY_BYTES:
		var at := i * STATIC_ENTRY_BYTES
		out.append({"tile": data.decode_u16(at), "z": data.decode_s8(at + 3),
			"hue": data.decode_u16(at + 5)})
	return out


func _evict() -> void:
	while _cache.size() > MAX_CACHED_BLOCKS:
		var oldest := -1
		var when := _clock + 1
		for key in _cache:
			if int(_cache[key]["used"]) < when:
				when = int(_cache[key]["used"])
				oldest = int(key)
		if oldest < 0:
			return
		_cache.erase(oldest)