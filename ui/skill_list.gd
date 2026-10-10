extends Control
# ui.skill_list - seznam skillu (granule `ui.skill_list`, smlouva docs/04 §4.2,
# podoba docs/05 §5.3: "58 skillu, hodnota v desetinnem formatu (0.0-100.0/120.0),
# zamky up/down/lock, tlacitko use").
#
# TENKY KLIENT (docs/05 §5.3 "Pravidlo UI"): radky dostane VSTUPEM (`update`),
# nic nepocita a nic nemeni. Co UI dela:
#   * hodnotu v DESETINACH jen naformatuje (`300 -> "30.0"`, `1200 -> "120.0"`);
#     hodnoty neopravuje ani neclampuje (stejne jako `ui.status_bar`: -5 zustava),
#   * zamek jen prelozi na text (`0 up`, `1 down`, `2 lock`; nezname -> `?`),
#   * na stisk tlacitka "use" jen OHLASI (`use_pressed(skill)`); rozhodnuti
#     patri simulaci (`sim.skill_gain` je deklarovana zavislost, ale UI ji nesmi
#     volat - zmena stavu `sim` z `ui/` je zakazana, docs/04 §4.1).
#
# "NULA A PRAZDO NEJSOU USPECH" (docs/09 §9.6): prazdny vstup se VYKRESLI
# ("(zadne skilly - data neprisla)") a preskocene (vadne) radky se pocitaji do
# `skipped()` i do viditelneho radku - ticho by vypadalo jako "58 skillu".
#
# Uzly (VBox + radky) se v testu uvolnuji pres `free()`; `Node` neni RefCounted
# a neuvolneny uzel shodi cely beh sady.

signal use_pressed(skill: int)

const BEZ_SKILLU := "(zadne skilly - data neprisla)"
const PRESKOCENO := "(%d vadnych radku preskoceno)"
const USE_TEXT := "use"
const RADEK := "Radek"

# zamky z `entity.skills` (docs/04 §4.2 / docs/05 §5.10): 0 up, 1 down, 2 lock
const LOCK_UP := 0
const LOCK_DOWN := 1
const LOCK_LOCKED := 2

var _radky: Array = []          # kopie vstupu (UI nesmi menit cizi data)
var _box: VBoxContainer = null
var _skipped: int = 0


func update(rows: Array) -> int:
	# Vraci pocet vykreslenych radku; `skipped()` pocet preskocenych vstupu.
	_vycisti()
	_box = VBoxContainer.new()
	_box.name = "Radky"
	add_child(_box)
	for radek in rows:
		if not (radek is Dictionary):
			_skipped += 1
			continue
		_radky.append((radek as Dictionary).duplicate())
		_pridej_radek(radek)
	if _radky.is_empty():
		_pridej_label("Prazdno", BEZ_SKILLU)
	if _skipped > 0:
		_pridej_label("Preskoceno", PRESKOCENO % _skipped)
	return _radky.size()


func count() -> int:
	return _radky.size()


func skipped() -> int:
	return _skipped


func empty_text() -> String:
	return BEZ_SKILLU


func format_value(desetiny: int) -> String:
	# Desetiny -> "0.0".."120.0"; znamenko se resi zvlast, aby -5 vyslo "-0.5"
	# (celociselne deleni v GDScriptu jinak da "0.-5").
	var znamenko := "-" if desetiny < 0 else ""
	var v: int = absi(desetiny)
	return "%s%d.%d" % [znamenko, v / 10, v % 10]


func lock_text(zamek: int) -> String:
	if zamek == LOCK_UP:
		return "up"
	if zamek == LOCK_DOWN:
		return "down"
	if zamek == LOCK_LOCKED:
		return "lock"
	return "?"                    # nezname = videt, ne tise "lock"


func row_texts() -> Array:
	# Text radku z UZLU (nezavisly zdroj nez `_radky`): "jmeno | hodnota | zamek".
	var out: Array = []
	if _box == null:
		return out
	for radek in _box.get_children():
		if radek is HBoxContainer:
			out.append(_text_of(radek))
	return out


func use_button_of(skill: int):
	if _box == null:
		return null
	for radek in _box.get_children():
		if not (radek is HBoxContainer):
			continue
		for uzel in radek.get_children():
			if uzel is Button and int(uzel.get_meta("skill", -1)) == skill:
				return uzel
	return null


# -- vnitrni ---------------------------------------------------------------

func _pridej_radek(radek: Dictionary) -> void:
	var hb := HBoxContainer.new()
	hb.name = RADEK
	hb.add_child(_label("Jmeno", str(radek.get("name", ""))))
	hb.add_child(_label("Hodnota", format_value(int(radek.get("value", 0)))))
	hb.add_child(_label("Zamek", lock_text(int(radek.get("lock", LOCK_UP)))))
	var skill: int = int(radek.get("id", radek.get("skill", -1)))
	var tlacitko := Button.new()
	tlacitko.name = "Use"
	tlacitko.text = USE_TEXT
	tlacitko.set_meta("skill", skill)
	tlacitko.pressed.connect(_on_use_pressed.bind(skill))
	hb.add_child(tlacitko)
	_box.add_child(hb)


func _label(jmeno: String, text: String) -> Label:
	var l := Label.new()
	l.name = jmeno
	l.text = text
	return l


func _pridej_label(jmeno: String, text: String) -> void:
	_box.add_child(_label(jmeno, text))


func _text_of(radek) -> String:
	var casti: Array = []
	for uzel in radek.get_children():
		if uzel is Label:
			casti.append(str(uzel.text))
	return " | ".join(casti)


func _on_use_pressed(skill: int) -> void:
	# Jen ohlasky - UI stav `sim` NEMENI (docs/04 §4.1).
	use_pressed.emit(skill)


func _vycisti() -> void:
	for uzel in get_children():
		remove_child(uzel)
		uzel.free()
	_box = null
	_radky = []
	_skipped = 0
