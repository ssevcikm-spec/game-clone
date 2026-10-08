extends Control
# Batoh hrace - seznam predmetu v batohu (granule `ui.backpack`; smlouva
# docs/04 §4.1 "UI je tenky klient").
#
# CO TENHLE MODUL JE: okno, ktere dostane RADKY VSTUPEM a vykresli je. Nic
# nepocita, nevi o `sim`, nevi o `data/` a nevola `Input`/`Time` (docs/09
# §9.10.4). Kdo obsah plni, je `app/main.gd` - tam se potkava `sim` s UI.
#
# ⚠ I KONY JSOU INJEKCE, NE ZAVISLOST: `ui/` NESMI sahat na `render/`
# (docs/04 §4.1 - stejny duvod, proc `ui.journal` neprevadi `hue` na barvu).
# Texturu predmetu proto dodava `app/` pres `nastav_textury(objekt)`; objekt
# musi mit `texture(art) -> Texture2D`. Kdyz dodany neni, okno kresli jen
# jmena - a je to VIDET (zadna prazdna ikona, ktera vypada jako chyba artu).
#
# PRVKY: kazdy radek je `{art:int, name:String, amount:int}`; `amount > 1` se
# pise jako "xN". Prazdny batoh neni chyba - okno to rekne ("(empty)").
#
# Prebavi se JEDNOU za frame a jen kdyz se obsah zmenil (`flush()`), stejne
# jako `ui.journal`: 100 predmetu nesmi zpomalit frame.

const SIRKA: float = 200.0
const VYSKA: float = 260.0
const RADEK_VYSKA: float = 22.0
const IKONA: float = 20.0

var textury = null                 # objekt s `texture(art)`; jinak null = bez ikon
var _radky: Array[Dictionary] = []
var _dirty: bool = true
var _box: VBoxContainer = null
var _prebaveni: int = 0


func _init() -> void:
	# NOVE OKNO JE ZAVRENE: `Control` je v Godotu viditelny ve vychozim stavu,
	# takze bez tohohle by batoh pri startu prekryl svet (a test by meril neco
	# jineho, nez hra dela). `app/main` to nastavuje taky - tady je to proto,
	# aby se modul choval rozumne i sam (a aby to nezaviselo na volajicim).
	visible = false


func nastav_textury(poskytovatel) -> void:
	# `poskytovatel` = cokoli s `texture(art) -> Texture2D` (v praxi
	# `render.textures`). Pro `ui/` je to NEZNAMA vec - jen se na ni vola.
	textury = poskytovatel
	_dirty = true


func nastav_obsah(radky: Array) -> void:
	# Vstup z `app/`: `[{art, name, amount}]`. Poradi urcuje volajici (UI ho
	# nemá "vylepšovat" - jinak by si UI vymyslelo pravidlo).
	_radky = []
	for radek in radky:
		if not (radek is Dictionary):
			continue
		_radky.append({
			"art": int(radek.get("art", 0)),
			"name": str(radek.get("name", "")),
			"amount": int(radek.get("amount", 1)),
		})
	_dirty = true


func radky() -> Array[Dictionary]:
	return _radky.duplicate(true)


func pocet() -> int:
	return _radky.size()


func je_otevreny() -> bool:
	return visible


func toggle() -> bool:
	visible = not visible
	return visible


func prebaveni() -> int:
	return _prebaveni


func flush() -> bool:
	if not _dirty:
		return false
	_dirty = false
	_prebaveni += 1
	var box: VBoxContainer = _ensure_box()
	# ⚠ UVOLNENI JE OKAMZITE (`free()`), NE `queue_free()`: to druhe uvolni az
	# na konci framu, takze by v okne zustaly STARE radky - a kdo se na ne ptá
	# (test, sonda), vidi jiný obsah, nez okno ma. NamEReno v tomto sezeni.
	_vycisti(box)
	if _radky.is_empty():
		var prazdny := Label.new()
		prazdny.name = "Prazdny"
		prazdny.text = "(empty)"
		box.add_child(prazdny)
		return true
	for radek in _radky:
		box.add_child(_radek_uzel(radek))
	return true


func _vycisti(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()


func text_radku(radek: Dictionary) -> String:
	# Text jednoho radku - jedine misto, kde se sklada (test to cte odsud).
	var zaklad: String = str(radek.get("name", ""))
	if int(radek.get("amount", 1)) > 1:
		zaklad += " x" + str(int(radek["amount"]))
	return zaklad


func _radek_uzel(radek: Dictionary) -> HBoxContainer:
	var radek_uzel := HBoxContainer.new()
	radek_uzel.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
	var art: int = int(radek.get("art", 0))
	var tex: Texture2D = null
	if textury != null and textury.has_method("texture"):
		tex = textury.texture(art)
	if tex != null:
		var ikona := TextureRect.new()
		ikona.texture = tex
		ikona.custom_minimum_size = Vector2(IKONA, IKONA)
		ikona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		radek_uzel.add_child(ikona)
	var popis := Label.new()
	popis.text = text_radku(radek)
	radek_uzel.add_child(popis)
	return radek_uzel


func _ensure_box() -> VBoxContainer:
	if _box == null:
		_box = VBoxContainer.new()
		_box.name = "BatohObsah"
		# VELIKOST JE POVINNA (stejna past jako u `ui.journal`): Control s
		# vychozi velikosti (0,0) text NEKRESLI, i kdyz data ma.
		_box.custom_minimum_size = Vector2(SIRKA, VYSKA)
		_box.size = Vector2(SIRKA, VYSKA)
		add_child(_box)
	return _box


func _process(_delta: float) -> void:
	flush()
