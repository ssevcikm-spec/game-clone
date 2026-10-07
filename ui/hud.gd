extends CanvasLayer
# HUD (granule ui.hud, docs/04 §4.2): drzi OKNA a jejich pozice a umi ulozit
# a obnovit rozlozeni. Zadna herni logika - jen evidence a prenos pozice na uzel.

var _windows: Dictionary = {}    # id -> Node (okno)
var _positions: Dictionary = {}  # id -> Vector2 (zapamatovana pozice)


func register_window(id: String, window: Node, pos: Vector2 = Vector2.ZERO) -> bool:
	# Nezname okno se NEVYROBI z niceho: prazdne id nebo chybejici uzel = false.
	if id.is_empty() or window == null:
		return false
	_windows[id] = window
	_positions[id] = pos
	_apply(id)
	return true


func window_of(id: String) -> Node:
	# Nezname okno vraci null (zadny pad, zadne vymyslene okno).
	return _windows.get(id)


func position_of(id: String) -> Variant:
	# Nezname okno vraci null - nikdy (0,0), aby se nepletlo s pravou pozici.
	return _positions.get(id)


func set_position(id: String, pos: Vector2) -> bool:
	# Pozici ZAPAMATUJE a PREPISE; u registrovaneho okna ji prenese na uzel.
	# Nezname okno = false (okno se z niceho nevyrobi).
	if not _positions.has(id):
		return false
	_positions[id] = pos
	_apply(id)
	return true


func layout() -> Dictionary:
	# KOPIE rozlozeni (id -> pozice) k ulozeni volajicim; jeji zmena nic nemeni.
	return _positions.duplicate()


func restore_layout(data: Dictionary) -> int:
	# Obnovi pozice z `layout()`; vraci pocet obnovenych OKEN (nezname id se preskoci).
	var count: int = 0
	for id in data:
		if not _positions.has(id) or not (data[id] is Vector2):
			continue
		_positions[id] = data[id]
		_apply(id)
		count += 1
	return count


func _apply(id: String) -> void:
	# Pozici prenese jen na uzly, ktere ji maji (Control/Node2D); ostatni ji drzi.
	var node = _windows.get(id)
	if node is Control or node is Node2D:
		node.position = _positions[id]
