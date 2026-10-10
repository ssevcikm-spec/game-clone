extends RefCounted
# Regiony a mesta (granule `world.regions`, smlouva docs/04 §4.2, obsah docs/06
# §6.7 a research/06 §1.4-1.5).
#
# TVAR (smlouva): `region_at(x, y)->Dictionary` = `{name, is_town,
# is_guard_zone, music, spawn_table}`; roadmapa zadava navic `is_guard_zone(x,y)`
# a `music_at(x,y)`.
#
# ⚠ DATA DNES NEEXISTUJI: `data/regions.json` v repu NENI (docs/06 §6.7 ho
# zadava; `tools/gates/gen-content.py:55` ho vede jako neextrahovany). Modul
# proto MUSI umet rict "region neznam" a NESMI si vymyslet Britain:
#   * `known()` vraci false, kdyz soubor neni / neni seznam / nema zaznamy,
#   * `region_at(x,y)` vraci `known:false` a prazdny nazev,
#   * `region_count()` vraci 0 - a to je NEMERENO, ne "svet bez regionu".
# Kdo dostane `known:false`, nesmi z toho delat "neni mesto": je to nezmereno.
# Klic `known` je NAVIC proti smlouvě (jako `reason` u `sim.movement`) - presne
# proto, aby se "nezmereno" dalo odlisit od "zmereno: mimo regiony".
#
# TVAR ZAZNAMU (az data vzniknou; `check-content.py:41` zadava jen `name`):
#   `{name, x, y, width, height}` nebo `{name, area:{x,y,width,height},
#    is_town, is_guard_zone, music, spawn_table}`. Prijme se OBE podoby -
#   `PLAN-NPC-A-SOUBOJ-2026-10-08.md:231` ma `area`, plocha mimo `area` je
#   jednodussi na zapis. Co v zaznamu neni, je `false`/`0`/`""` (ne vymyslena
#   hodnota) a zaznam bez `name` se PRESKOCI (pocita se do `skipped()`).
#
# PREKRYV REGIONU: vyhrava PRVNI zaznam v souboru (poradi v souboru = priorita).
# Je to ROZHODNUTI KLONU - dokud `data/regions.json` neexistuje, neni na cem
# pravidlo zmerit (hlasi se jako otevrena vec, ne jako overena).
#
# ZAVISLOST "data.regions": cesta k datum je VSTUP konstruktoru (`world.map` to
# ma stejne), aby se modul dal merit bez `data/` i s testovaci sadou.

const DATA_PATH := "res://data/regions.json"

var _path: String = DATA_PATH
var _regions: Array = []
var _known: bool = false
var _skipped: int = 0


func _init(data_path: String = DATA_PATH) -> void:
	_path = data_path
	_load()


func known() -> bool:
	# false = NEMERENO (data nejsou), true = data jsou a `region_at` vraci
	# "mimo regiony" jen kdyz to opravdu zmeril.
	return _known


func region_count() -> int:
	return _regions.size()


func skipped() -> int:
	# Zaznamy, ktere se nectly (bez `name`) - ticho by vypadalo jako hotova data.
	return _skipped


func region_at(x: int, y: int) -> Dictionary:
	var out := {
		"name": "", "is_town": false, "is_guard_zone": false,
		"music": 0, "spawn_table": "", "known": _known,
	}
	if not _known:
		return out
	var rec = _find(x, y)
	if rec == null:
		return out                         # zmereno: mimo vsechny regiony
	out["name"] = str(rec.get("name", ""))
	out["is_town"] = bool(rec.get("is_town", false))
	out["is_guard_zone"] = bool(rec.get("is_guard_zone", false))
	out["music"] = int(rec.get("music", 0))
	out["spawn_table"] = str(rec.get("spawn_table", ""))
	return out


func is_guard_zone(x: int, y: int) -> bool:
	return bool(region_at(x, y).get("is_guard_zone", false))


func music_at(x: int, y: int) -> int:
	return int(region_at(x, y).get("music", 0))


# -- vnitrni ---------------------------------------------------------------

func _load() -> void:
	_regions = []
	_skipped = 0
	_known = false
	if not FileAccess.file_exists(_path):
		push_warning("sim.world.regions: chybi " + _path
			+ " - regiony jsou NEMERENE (`known()` vraci false)")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not (parsed is Array):
		push_warning("sim.world.regions: " + _path + " neni seznam - regiony jsou NEMERENE")
		return
	for rec in parsed:
		if rec is Dictionary and str(rec.get("name", "")) != "":
			_regions.append(rec)
		else:
			_skipped += 1
	_known = not _regions.is_empty()
	if _skipped > 0:
		push_warning("sim.world.regions: %d zaznamu bez `name` se preskocilo" % _skipped)


func _find(x: int, y: int):
	for rec in _regions:
		var r: Array = _rect(rec)
		if x >= r[0] and y >= r[1] and x < r[0] + r[2] and y < r[1] + r[3]:
			return rec
	return null


func _rect(rec: Dictionary) -> Array:
	var area = rec.get("area")
	var src: Dictionary = area if area is Dictionary else rec
	return [int(src.get("x", 0)), int(src.get("y", 0)),
		int(src.get("width", 0)), int(src.get("height", 0))]
