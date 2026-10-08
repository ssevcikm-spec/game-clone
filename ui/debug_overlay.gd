extends Control
# ui.debug_overlay - DEBUG INFO NA OBRAZOVKU (granule `ui.debug_overlay`).
#
# ZADANI UZIVATELE 2026-10-09 (doslova): "Navrhuji pridat informaci o lokaci,
# kde screenshot fotim, pripadne jakoukoliv dalsi debug informace, at to mas
# snazsi. Staci mozna vlepit na obrazovku at se to zachyti se screenshotem."
#
# PROC TO JE: uzivatel hlasi vady SNIMKEM OBRAZOVKY a bez souradnic se u vady
# "neco se zobrazuje divne" neda zjistit, KDE to je. Text je proto na obrazovce,
# ne jen v logu - screenshot ho zachyti spolu s obrazem.
#
# TVRZENI, KTERA MUSI DRZET:
#   * UI JE TENKY KLIENT (docs/04 §4.1): hodnoty dostava VSTUPEM (`update`),
#     samo nic nepocita a nikam neleze (zadny `sim`, `render`, `Input`),
#   * text sklada ZVLAST (`text_for`) - da se merit bez okna a bez grafiky
#     (vzor `ui.status_bar`),
#   * overlay je VIDITELNY od startu (proto tu je) a `F3` ho schova/zapne;
#     kdo ho chce mit jen pro jeden snimek, at si ho necha zapnuty - je to
#     debug vrstva, ne herni UI,
#   * ⚠⚠ `mouse_filter = MOUSE_FILTER_IGNORE` na overlayi I na jeho dilech:
#     `Control` ma ve Godotu vychozi `MOUSE_FILTER_STOP`, takze by PREKRYL
#     klikani do sveta pod sebou (a hra by "prestala reagovat na mys" presne
#     v miste, kde je text). Je to namERena past projektu (docs/09 §9.9).
#
# TEXTY JSOU ANGLICKY (docs/01 §1.6: UI texty anglicky, komentare cesky).

const BARVA_TEXT: Color = Color(1.0, 1.0, 0.75, 1.0)
const BARVA_POZADI: Color = Color(0.0, 0.0, 0.0, 0.55)
const VELIKOST_PISMA: int = 13

var label: Label = null
var pozadi: ColorRect = null
var _values: Dictionary = {}


func _init() -> void:
	# Overlay je od startu VIDITELNY (viz hlavicka) - neni to okno, ktere by
	# muselo cekat na klavesu. `F3` ho prepina (`app/player_controller`).
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update(values: Dictionary) -> void:
	# Prevezme hodnoty a prepise text; chybejici klice jsou 0/"?" - nikdy pad.
	_values = values.duplicate()
	_postav()
	label.text = text_for(_values)


func toggle() -> bool:
	# Vraci NOVY stav - volajici ho hlasi do konzole (ticho by znamenalo, ze
	# hrac nevi, jestli overlay zmackl on, nebo se neco pokazilo).
	visible = not visible
	return visible


func text_for(values: Dictionary) -> String:
	# TRI RADKY: kde jsem | stav postavy a animace | vykon a obraz.
	# Poradi casti je dane a testuje se presne (vzor `ui.status_bar.text_for`).
	var kde: String = str(values.get("loc", ""))
	var r1 := "loc: %sx=%d y=%d z=%d dir=%d | win=%s zoom=%.2f | pick=%s" % [
		(kde + " ") if kde != "" else "",
		_num(values, "x"), _num(values, "y"), _num(values, "z"), _num(values, "dir"),
		str(values.get("win", "?")), _fnum(values, "zoom"), _vec(values, "pick")]
	var r2 := "state: hp=%d/%d stam=%d/%d mana=%d/%d weight=%d gold=%d | anim=%s f=%d/%d | step=%s %d/%dms" % [
		_num(values, "hp"), _num(values, "hp_max"),
		_num(values, "stam"), _num(values, "stam_max"),
		_num(values, "mana"), _num(values, "mana_max"),
		_num(values, "weight"), _num(values, "gold"),
		str(values.get("anim", "?")), _num(values, "anim_frame"), _num(values, "anim_count"),
		"run" if bool(values.get("step_run", false)) else ("walk" if _num(values, "step_delay_ms") > 0 else "idle"),
		_num(values, "step_elapsed_ms"), _num(values, "step_delay_ms")]
	var r3 := "gfx: fps=%.1f frame=%.2fms peak=%.0fms drawn=%d holes=%d | tiles=%s | map=%s" % [
		_fnum(values, "fps"), _fnum(values, "frame_ms"), _fnum(values, "peak_ms"),
		_num(values, "drawn"), _num(values, "holes"), _vec(values, "tiles"),
		str(values.get("map", "?"))]
	return r1 + "\n" + r2 + "\n" + r3


func _postav() -> void:
	# Dily se zakladaji LENIVE (testy tvori uzel bez stromu) - `text_for` kvuli
	# tomu nikdy nepotrebuje zadny uzel.
	if pozadi == null:
		pozadi = ColorRect.new()
		pozadi.name = "DebugPozadi"
		pozadi.color = BARVA_POZADI
		pozadi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pozadi)
	if label == null:
		label = Label.new()
		label.name = "DebugText"
		label.add_theme_color_override("font_color", BARVA_TEXT)
		label.add_theme_font_size_override("font_size", VELIKOST_PISMA)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	# Pozadi se roztahne az na velikost textu (jinak by byl jen 1 px).
	var velikost: Vector2 = label.get_minimum_size()
	label.position = Vector2(4.0, 2.0)
	pozadi.position = Vector2.ZERO
	pozadi.size = velikost + Vector2(8.0, 4.0)


func _num(values: Dictionary, key: String) -> int:
	# Jen cisla; text nebo null je 0 (UI nesmi spadnout na cizim vstupu).
	var v = values.get(key, 0)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING and v.is_valid_int():
		return int(v)
	return 0


func _fnum(values: Dictionary, key: String) -> float:
	var v = values.get(key, 0)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	if typeof(v) == TYPE_STRING and v.is_valid_float():
		return float(v)
	return 0.0


func _vec(values: Dictionary, key: String) -> String:
	# Vektor se v textu pise jako "(x,y)"; chybejici je "(?)" - nula by
	# vypadala jako namERena souradnice (0,0).
	var v = values.get(key)
	if v is Vector2:
		return "(%d,%d)" % [int(v.x), int(v.y)]
	if v is Vector2i:
		return "(%d,%d)" % [v.x, v.y]
	return "(?)"
