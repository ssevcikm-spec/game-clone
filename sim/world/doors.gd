extends RefCounted
# Dvere (granule world.doors). Data pochazeji z instalace UO: `doors.txt`
# prevedene do `data/doors.json` nastrojem tools/uoextract/textdata.py
# (docs/03 §3.6: 37 kategorii, kazda 8 art id).
#
# KONVENCE STAVU - ZMERENO A OPRAVENO 2026-10-07 (8. session; stary omyl nize):
# Vsech 8 artu kategorie v `doors.txt` je ZAVRENY stav (kresba "ve zdi");
# OTEVRENY stav je druha kresba téhož (smer x pant) a ma art id `zavreny + 1`.
# Doklady (merene nad vsemi 230 arty z `data/doors.json`; skripty
# `_analyza/dvere-konvence.py` a `_analyza/dvere-jmena.py`):
#   1. `tiledata` (assets/uo/tiles.json) je u 8 paru pojmenovava primo:
#      11590 "wooden door closed" / 11591 "wooden door opened", 11621 "simple
#      door closed" / 11622 "simple door open" ... a ANI JEDEN par to nema
#      obracene (0 z 8 ma "closed" na strane `art`).
#   2. `Impassable` ma vsech 230 artu z `doors.txt` (0 pruchozich), kdezto
#      u 71 z 230 `art + 1` flag chybi - otevrene dvere jsou pruchozi.
#      Opacny smer by musel mit 230 pruchozich "zavrenych" a 0 "otevrenych".
#   3. `art + 1` existuje pro vsech 230 artu a ANI JEDNOU to neni druhy art
#      z `doors.json` (0 z 230): otevreny art tedy neni "jiny smer dveri",
#      ktery by se dal nekam postavit.
#   4. RunUO/ServUO/ModernUO stavi dvere jako `base(closedID, openedID)` s
#      `openedID = closedID + 1` (ServUO Scripts/Items/Functional/Doors.cs:138,
#      ModernUO .../Doors/HouseDoors.cs:48) - a `doors.txt` dodava prave
#      `closedID` (dotaz na dvere se do sveta stavi zavreny).
#
# POZOR: PARITA ANI `layer` NEJSOU KRITERIUM. Kusy jsou 120 liche a 110 sude
# (16 kategorii ma vsechny sude: 7, 9-14, 19, 23, 27, 28, 30, 32-34, 36) a
# `layer` se u 39 z 230 paru lisi - kdo pozna stav z parity nebo z vrstvy,
# rozhodne u tech kategorii presne opacne. Stav se pozna JEN z toho, ktery
# clen dvojice je v `doors.txt`.
#
# STARY OMYL (2026-10-02, ponechano jako zaznam - needituje se):
# hlavicka tehdy tvrdila, ze "kusy 1-4 jsou CTYRI ZAVRENE orientace a kusy 5-8
# tytez orientace OTEVRENE" a `toggle` paroval `index` s `index + 4`. Bylo to
# rozhodnuti OBRAZKEM (montaz assets/uo/art-preview/doors.png) a je spatne:
# kusy 1-4 a 5-8 jsou RŮZNÉ SMERY (8 dvojic smer x strana pantu), ne dva stavy.
# Nasledek: `toggle` prepsal dvere na jiny smer téhož stavu (1721 -> 1725),
# ne na otevreno - a `sim.interaction` (Úkol 4) by otviral na spatnou stranu.

const DOORS_PATH := "res://data/doors.json"
const PIECES := 8                  # artu na kategorii (8 smeru; viz hlavicka)

var _by_tile: Dictionary = {}      # art z doors.txt (= ZAVRENY) -> {category, index}
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


func _closed(tile: int) -> Variant:
	# ZAVRENY clen dvojice: bud je to sam art z doors.txt, nebo u otevreneho
	# artu `tile - 1` (viz hlavicka). `null` = art neni dvere.
	var found = _by_tile.get(tile)
	if found != null:
		return found
	return _by_tile.get(tile - 1)


func category_count() -> int:
	return _categories.size()


func is_door(tile: int) -> bool:
	# Plati pro OBA cleny dvojice - i pro pootoceny (otevreny) art.
	var found = _by_tile.get(tile)
	return found != null or _by_tile.has(tile - 1)


func category(tile: int) -> int:
	var found = _closed(tile)
	return -1 if found == null else int(found["category"])


func orientation(tile: int) -> int:
	# Index v seznamu doors.txt (0..7) - pro oba cleny dvojice stejny.
	# NENI to `index % 4`: stav se z indexu nepozna (viz hlavicka).
	var found = _closed(tile)
	return -1 if found == null else int(found["index"])


func is_open(tile: int) -> bool:
	# Otevreny art v doors.txt NENI, ale jeho `tile - 1` tam je.
	return not _by_tile.has(tile) and _by_tile.has(tile - 1)


func toggle(tile: int) -> int:
	# Zavreny <-> otevreny je `art + 1` / `art - 1` (viz hlavicka).
	if _by_tile.has(tile):
		return tile + 1
	if _by_tile.has(tile - 1):
		return tile - 1
	return 0


func open_tile(cat: int, index: int) -> int:
	# Otevreny art dane kategorie a indexu v doors.txt = zavreny + 1.
	if cat < 0 or cat >= _categories.size() or index < 0 or index >= PIECES:
		return 0
	var closed: int = int(_categories[cat]["tiles"][index])
	return 0 if closed == 0 else closed + 1


func name_of(cat: int) -> String:
	if cat < 0 or cat >= _categories.size():
		return ""
	return str(_categories[cat]["name"])
