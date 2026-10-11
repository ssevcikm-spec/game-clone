extends Control
# ui.hotkeys - napoveda: co zmacknout a co ve hre delat (granule `ui.hotkeys`,
# smlouva docs/04 §4.2; `ui.hotkeys` je v planu od M2, tenhle soubor je jeji
# prvni verze).
#
# CO TENHLE MODUL JE: okno, ktere dostane RADKY VSTUPEM a vykresli je. Nic
# nepocita, nevi o `sim`, `render`, `InputMap` ani `data/` a nevola
# `Input`/`Time` (docs/09 §9.10.4). Kdo obsah sklada, je `app/main` - tam se
# potkava `data/help.json` s REALNYMI vazbami klaves z `InputMap`. Proto tu
# nejsou klavesy natvrdo: dve pravdy o klavesach znamenaji, ze hrac maze
# klavesu, ktera nic nedela.
#
# TVAR RADKU: `{sekce:String, klavesy:String, popis:String}` - poradi i
# seskupeni urcuje VOLAJICI (UI si nesmi vymyslet pravidlo, stejne jako
# `ui.skill_list` a `ui.backpack`). Hlavicku sekce kresli okno, kdyz se
# `sekce` zmeni.
#
# "NULA A PRAZDO NEJSOU USPECH" (docs/09 §9.6): prazdny vstup se VYKRESLI
# (`(napoveda neni ...)`) a preskocene (vadne) radky se pocitaji do `skipped()`
# i do viditelneho radku - ticho by vypadalo jako "napoveda je prazdna".
#
# Uzly se uvolnuji `free()` (ne `queue_free()`): to druhe uvolni az na konci
# framu, takze by v okne zustaly STARE radky (namEReno u `ui.backpack`).

const SIRKA: float = 440.0
const VYSKA: float = 540.0
# Sirka textu = sirka okna MINUS vnitrni okraj panelu (`PanelContainer` si
# kresli ramecek); kdyby text chtel celou sirku, okno by si ho samo rozsirilo.
const TEXT_SIRKA: float = 424.0
const BEZ_NAPOVEDY := "(napoveda neni - data neprisla)"
const PRESKOCENO := "(%d vadnych radku preskoceno)"
const ODDELOVAC := "  -  "

var _titulek: String = ""
var _radky: Array[Dictionary] = []
var _prazdno_text: String = BEZ_NAPOVEDY
var _skipped: int = 0
var _box: VBoxContainer = null
var _dirty: bool = false
var _prebaveni: int = 0


func _init() -> void:
	# Nove okno je ZAVRENE: `Control` je v Godotu viditelny ve vychozim stavu.
	# Kdo ho chce hned na obrazovce (hra pro cloveka, ktery hru nezna), zavola
	# `otevri()` - rozhodnuti o tom patri volajicimu, ne modulu.
	visible = false


func nastav(titulek: String, radky: Array, prazdno_text: String = BEZ_NAPOVEDY) -> int:
	# Vstup z `app/`. Vraci pocet prijatych radku; `skipped()` pocet vadnych.
	# Radky se KOPIRUJI (UI nesmi menit cizi data).
	_titulek = titulek
	_prazdno_text = prazdno_text if prazdno_text != "" else BEZ_NAPOVEDY
	_radky = []
	_skipped = 0
	for radek in radky:
		if not (radek is Dictionary):
			_skipped += 1
			continue
		_radky.append({
			"sekce": str((radek as Dictionary).get("sekce", "")),
			"klavesy": str((radek as Dictionary).get("klavesy", "")),
			"popis": str((radek as Dictionary).get("popis", "")),
		})
	_dirty = true
	return _radky.size()


func radky() -> Array[Dictionary]:
	# KOPIE radku (jako `ui.backpack.radky()`).
	return _radky.duplicate(true)


func count() -> int:
	return _radky.size()


func skipped() -> int:
	return _skipped


func titulek() -> String:
	return _titulek


func empty_text() -> String:
	return _prazdno_text


func je_otevreny() -> bool:
	return visible


func otevri() -> bool:
	visible = true
	return visible


func toggle() -> bool:
	visible = not visible
	return visible


func prebaveni() -> int:
	return _prebaveni


func text_radku(radek: Dictionary) -> String:
	# JEDNO misto, kde se text radku sklada (test ho cte odsud, ne z uzlu).
	# Chybejici klavesa se PISUJE jako '-' - prazdno by vypadalo jako rada,
	# ktera nic nerika.
	var klavesy: String = str(radek.get("klavesy", ""))
	if klavesy.strip_edges() == "":
		klavesy = "-"
	return "%s%s%s" % [klavesy, ODDELOVAC, str(radek.get("popis", ""))]


func row_texts() -> Array:
	# Text radku z UZLU (nezavisly zdroj nez `_radky`): kdyz se uzel nekresli,
	# je seznam prazdny - "text v promenne neni text na obrazovce".
	# ⚠ ROZHODUJE META, NE JMENO: Godot pri `add_child` PREJMENOVAVA duplicitni
	# jmena ("Radek", "Radek2", ...), takze filtr podle `name == "Radek"` nasel
	# jen PRVNI radek (namEReno sondou `_analyza/p56-start-pozorovani.gd`).
	var out: Array = []
	if _box == null:
		return out
	for uzel in _box.get_children():
		if uzel is Label and bool(uzel.get_meta("radek", false)):
			out.append(str(uzel.text))
	return out


func flush() -> bool:
	if not _dirty:
		return false
	_dirty = false
	_prebaveni += 1
	var box: VBoxContainer = _ensure_box()
	# UVOLNENI JE OKAMZITE (viz hlavicka).
	for child in box.get_children():
		box.remove_child(child)
		child.free()
	if _titulek != "":
		var t := Label.new()
		t.name = "Titulek"
		t.text = _titulek
		box.add_child(t)
	if _radky.is_empty():
		var prazdny := Label.new()
		prazdny.name = "Prazdno"
		prazdny.text = _prazdno_text
		box.add_child(prazdny)
	else:
		var prvni: bool = true
		var sekce: String = ""
		for radek in _radky:
			if prvni or str(radek.get("sekce", "")) != sekce:
				prvni = false
				sekce = str(radek.get("sekce", ""))
				if sekce != "":
					var h := Label.new()
					h.name = "Sekce"
					# ⚠ META, NE JMENO: Godot pri `add_child` PREJMENOVAVA
					# duplicitni jmena, takze druha hlavicka se uz nejmenuje
					# "Sekce" (namEReno testem `tests/cases/ui_hotkeys.gd`:
					# filtr podle jmena nasel 1 hlavicku misto 2).
					h.set_meta("sekce", true)
					h.text = sekce
					box.add_child(h)
			var l := Label.new()
			l.name = "Radek"
			l.set_meta("radek", true)
			l.text = text_radku(radek)
			# AUTOWRAP + vyska 0: dlouhy popis se ZALOMI (Label s pevnou vyskou
			# by text odstrihl). Sirku dava kontejner, takze se pocita spravne.
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(TEXT_SIRKA, 0.0)
			box.add_child(l)
	if _skipped > 0:
		var chyba := Label.new()
		chyba.name = "Preskoceno"
		chyba.set_meta("preskoceno", true)
		chyba.text = PRESKOCENO % _skipped
		box.add_child(chyba)
	return true


func _ensure_box() -> VBoxContainer:
	if _box == null:
		# ⚠ POZADI JE POD KRITICKY DULEZITY TEXT: bez nej lezi napoveda PRIMO
		# na mape a neda se precist (stejna vada, jakou melo okno batohu:
		# "ikony i texty lezi primo na mape"). `PanelContainer` kresli motiv
		# a ZAROVEN se roztahne na obsah - zadne rucni pocitani velikosti.
		var panel := PanelContainer.new()
		panel.name = "Panel"
		panel.custom_minimum_size = Vector2(SIRKA, VYSKA)
		panel.size = Vector2(SIRKA, VYSKA)
		add_child(panel)
		_box = VBoxContainer.new()
		_box.name = "Napoveda"
		# MEZERA 0: kazda mezera navic odsune posledni radek pod okraj okna
		# (namEReno snimkem `_analyza/p56-start-pozorovani.gd`).
		_box.add_theme_constant_override("separation", 0)
		panel.add_child(_box)
	return _box


func _process(_delta: float) -> void:
	flush()
