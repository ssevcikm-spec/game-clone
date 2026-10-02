extends RefCounted
# Dvere (granule world.doors). Data pochazeji z instalace UO: `doors.txt`
# prevedene do `data/doors.json` nastrojem tools/uoextract/textdata.py
# (docs/03 §3.6: 37 kategorii, kazda 8 art id).
#
# STRUKTURA 8 ARTU - ROZHODNUTO OBRAZKEM (2026-10-02, docs/03 §3.5.3):
# art kategorii 0 (Metal Door) a 4 (Wood Door) jsem si prohledl v montazi
# a je videt, ze kusy 1-4 jsou CTYRI ZAVRENE orientace a kusy 5-8 tytez
# orientace OTEVRENE (kridlo pootoceny). Dvojice (1,2), (3,4)... tedy NEjsou
# stavy - to byla moje prvni hypotéza a data ji vyvratila: rozdily uvnitr
# "dvojic" nejsou konstantni (-9251 az +9247). Proto:
#     orientace = index % 4,   otevreno = index >= 4,   toggle = index +- 4.

const DOORS_PATH := "res://data/doors.json"
const PIECES := 8
const ORIENTATIONS := 4

var _by_tile: Dictionary = {}      # tile -> {category, index}
var _categories: Array = []        # index -> {category, tiles: [...], feature_mask, name}


func _init() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(DOORS_PATH):
		push_warning("world.doors: chybi " + DOORS_PATH)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DOORS_PATH))
	if not (data is Dictionary) or not (data.get("rows") is Array):
		push_warning("world.doors: " + DOORS_PATH + " nema tvar {rows: [...]}")
		return
	for row in data["rows"]:
		var tiles: Array = []
		for i in range(1, PIECES + 1):
			# POZOR (namEReno 2026-10-02): Godotuv JSON.parse_string vraci
			# VSECHNA cisla jako float. Kontrola `typeof(value) != TYPE_INT`
			# proto zahodila vsechny radky a modul mel 0 kategorii - tise.
			# Cisla se tedy prevadeji pres int() a do stavu jdou jako int.
			var value = row.get("piece%d" % i)
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				tiles = []
				break
			tiles.append(int(value))
		if tiles.size() != PIECES:
			continue
		var category: int = int(row.get("category", -1))
		_categories.append({
			"category": category, "tiles": tiles,
			"feature_mask": int(row.get("featuremask", 0)),
			"name": str(row.get("comment", "")),
		})
		for index in PIECES:
			# Art id 0 znamena "v teto kategorii ten kus neni" - do indexu
			# dlazdic nepatri (jinak by se "dveri" stal tile 0).
			if tiles[index] != 0:
				_by_tile[tiles[index]] = {"category": category, "index": index}


func category_count() -> int:
	return _categories.size()


func is_door(tile: int) -> bool:
	return _by_tile.has(tile)


func category(tile: int) -> int:
	var found = _by_tile.get(tile)
	return -1 if found == null else int(found["category"])


func orientation(tile: int) -> int:
	# Orientace 0..3; kusy 5-8 jsou tytez orientace ve stavu "otevreno".
	var found = _by_tile.get(tile)
	return -1 if found == null else int(found["index"]) % ORIENTATIONS


func is_open(tile: int) -> bool:
	var found = _by_tile.get(tile)
	return false if found == null else int(found["index"]) >= ORIENTATIONS


func toggle(tile: int) -> int:
	# Zavrene <-> otevrene: posun o 4 v ramci kategorie (viz hlavicka).
	var found = _by_tile.get(tile)
	if found == null:
		return 0
	var entry: Dictionary = _categories[int(found["category"])]
	var index: int = int(found["index"])
	var other: int = index + ORIENTATIONS if index < ORIENTATIONS else index - ORIENTATIONS
	return int(entry["tiles"][other])


func open_tile(cat: int, orient: int) -> int:
	# Otevreny art pro danou kategorii a orientaci (kusy 5-8).
	if cat < 0 or cat >= _categories.size() or orient < 0 or orient >= ORIENTATIONS:
		return 0
	return int(_categories[cat]["tiles"][orient + ORIENTATIONS])


func name_of(cat: int) -> String:
	if cat < 0 or cat >= _categories.size():
		return ""
	return str(_categories[cat]["name"])
