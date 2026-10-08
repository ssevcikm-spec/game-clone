extends Control
# Okno vyroby (granule `ui.craft_gump`; smlouva docs/04 §4.4 `gump_open` a
# §4.6.3 tok "dvojklik na kladivo -> gump s recepty").
#
# CO TENHLE MODUL JE: seznam receptu, ktery dostane VSTUPEM z udalosti
# `gump_open` (`data.recipes`) a kliknuti na recept prelozi na POZADAVEK.
# Sam nic neodesila - `Input`/`sim` nezna (docs/09 §9.10.4); pozadavek si
# vyzvedne `app/main.gd` a posle ho jako `Command{t:"craft", recipe, count}`
# (stejne jako `ui.journal` dostava hotove zpravy).
#
# CO NEDELA (pojmenovane): nedeli recepty podle dostupnosti materialu a
# neposila "make number" - to patri gumpu, az bude mit mrizku a ikony
# (dnes je to seznam; `count` je proto 1). Nedostupnost resi SIM: `craft`
# vrati `{ok:false, reason:"materials"|"skill"}` a hrac to uvidi v zurnalu.
#
# ⚠ OKNO SE OTEVRE UDALOSTI, NE KLIKEM NA SEBE: `gump_open` prijde z
# `sim.interaction` (par "kladivo + kovadlina"); `apply_event` ho prijme.

const SIRKA: float = 220.0
const VYSKA: float = 280.0
const RADEK_VYSKA: float = 22.0

var _recepty: Array[Dictionary] = []
var _pozadavek: Dictionary = {}
var _dirty: bool = true
var _box: VBoxContainer = null
var _prebaveni: int = 0


func _init() -> void:
	# Nove okno je ZAVRENE (Control je v Godotu viditelny ve vychozim stavu);
	# otevre ho az udalost `gump_open`. Stejne jako `ui.backpack`.
	visible = false


func apply_event(event: Dictionary) -> bool:
	# Bere CELY slovnik `{name, data}` (jako `ui.journal.apply_event`).
	# ⚠ TVAR JE ZE SMLOUVY (docs/04 §4.4): udalost `gump_open` ma
	# `{gump, data}` - data ulozena v `data`, tedy recepty jsou na
	# `event.data.data.recipes`. Cist je odtud JEDNIM jmenem je pravidlo
	# projektu (dve jmena tehoz = ticha ztrata dat).
	if str(event.get("name", "")) != "gump_open" or not (event.get("data") is Dictionary):
		return false
	var obal: Dictionary = event["data"]
	if str(obal.get("gump", "")) != "craft":
		return false
	var obsah = obal.get("data", {})
	nastav_recepty(obsah.get("recipes", []) if obsah is Dictionary else [])
	visible = true
	return true


func je_otevreny() -> bool:
	return visible


func nastav_recepty(seznam) -> void:
	# Vstup: `[{id:int, name:String, min_skill:float}]` (tvar z `craft.recipes_for`).
	_recepty = []
	if seznam is Array:
		for rec in seznam:
			if not (rec is Dictionary):
				continue
			_recepty.append({
				"id": int(rec.get("id", -1)),
				"name": str(rec.get("name", "")),
				"min_skill": float(rec.get("min_skill", 0.0)),
			})
	_dirty = true


func recepty() -> Array[Dictionary]:
	return _recepty.duplicate(true)


func pocet() -> int:
	return _recepty.size()


func prebaveni() -> int:
	return _prebaveni


func odeber_pozadavek() -> Dictionary:
	# `app/` si ji vyzvedne a posle jako Command; kdyz nic neni, vraci {}.
	var out: Dictionary = _pozadavek
	_pozadavek = {}
	return out


func stiskni(recept_id: int) -> bool:
	# Kliknuti na recept (vola ho i test - proto to neni v `_on_pressed`).
	for rec in _recepty:
		if int(rec["id"]) == recept_id:
			_pozadavek = {"t": "craft", "recipe": recept_id, "count": 1}
			return true
	return false


func text_receptu(rec: Dictionary) -> String:
	# Text jednoho radku - jedine misto, kde se sklada (test ho cte odsud).
	return "%s (%.1f)" % [str(rec.get("name", "")), float(rec.get("min_skill", 0.0))]


func flush() -> bool:
	if not _dirty:
		return false
	_dirty = false
	_prebaveni += 1
	var box: VBoxContainer = _ensure_box()
	# UVOLNENI JE OKAMZITE (`free()`), ne `queue_free()` - to uvolni az na konci
	# framu, takze by v okne zustaly stare radky (namEReno 20. session).
	for child in box.get_children():
		if child is Button or (child is Label and str(child.text) == "(no recipes)"):
			box.remove_child(child)
			child.free()
	if _recepty.is_empty():
		var prazdny := Label.new()
		prazdny.text = "(no recipes)"
		box.add_child(prazdny)
		return true
	for rec in _recepty:
		var tlacitko := Button.new()
		tlacitko.text = text_receptu(rec)
		tlacitko.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
		tlacitko.pressed.connect(stiskni.bind(int(rec["id"])))
		box.add_child(tlacitko)
	return true


func _ensure_box() -> VBoxContainer:
	if _box == null:
		_box = VBoxContainer.new()
		_box.name = "Recepty"
		# VELIKOST JE POVINNA (stejna past jako u `ui.journal` a `ui.backpack`).
		_box.custom_minimum_size = Vector2(SIRKA, VYSKA)
		_box.size = Vector2(SIRKA, VYSKA)
		add_child(_box)
		var popis := Label.new()
		popis.text = "Crafting"
		_box.add_child(popis)
	return _box


func _process(_delta: float) -> void:
	flush()
