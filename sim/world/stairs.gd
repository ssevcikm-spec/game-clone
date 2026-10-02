extends RefCounted
# Schody (granule world.stairs). Data z instalace UO: `stairs.txt` -> `data/stairs.json`
# nastrojem tools/uoextract/textdata.py (docs/03 §3.6: 19 kategorii).
#
# Kategorie ma podle dokumentace: Block, North/East/South/West, Squared1/2,
# Rounded1/2, MultiNorth/East/South/West. Klon z toho potrebuje jen to, co je
# v datech: ktere dlazdice jsou schody a do ktere skupiny patri (podle toho se
# meni z pri chuzi - docs/05 §5.1).

const STAIRS_PATH := "res://data/stairs.json"

var _by_tile: Dictionary = {}      # tile -> {category, role}
var _groups: Array = []            # index -> {category, tiles: {role: tile}, name}


func _init() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(STAIRS_PATH):
		push_warning("world.stairs: chybi " + STAIRS_PATH)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(STAIRS_PATH))
	if not (data is Dictionary) or not (data.get("rows") is Array):
		push_warning("world.stairs: " + STAIRS_PATH + " nema tvar {rows: [...]}")
		return
	for row in data["rows"]:
		var tiles: Dictionary = {}
		for key in row.keys():
			if key == "category" or key == "comment" or key == "featuremask":
				continue
			# JSON vraci cisla jako float (viz hlavicka doors.gd) - proto int().
			var value = row[key]
			if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and int(value) != 0:
				tiles[key] = int(value)
		if tiles.is_empty():
			continue
		var category: int = int(row.get("category", -1))
		_groups.append({"category": category, "tiles": tiles,
			"name": str(row.get("comment", ""))})
		for role in tiles.keys():
			_by_tile[tiles[role]] = {"category": category, "role": role}


func group_count() -> int:
	return _groups.size()


func is_stair(tile: int) -> bool:
	return _by_tile.has(tile)


func role(tile: int) -> String:
	var found = _by_tile.get(tile)
	return "" if found == null else str(found["role"])


func stair_group(tile: int) -> Dictionary:
	# Vraci skupinu, do ktere dlazdice patri (nebo prazdny slovnik).
	var found = _by_tile.get(tile)
	if found == null:
		return {}
	for entry in _groups:
		if int(entry["category"]) == int(found["category"]):
			return entry
	return {}


func group_for_category(cat: int) -> Dictionary:
	for entry in _groups:
		if int(entry["category"]) == cat:
			return entry
	return {}
