extends Control
# ui.debug_travel - okno se seznamem TESTOVACÍCH BODŮ (DEBUG POMŮCKA).
#
# ⚠ CO TO JE A CO TO NENÍ: je to DEBUG nástroj pro vývojáře (skok na těžbu,
# boj, obchod), NENÍ to herní funkce. Nemá vliv na stav simulace, na uložená
# data, na determinismus ani na art - jen ukazuje seznam bodů, které dodá
# `app/`.
#
# TENKÝ KLIENT (docs/04 §4.1): okno dostane ŘÁDKY VSTUPEM a vykreslí je. Nic
# nepočítá, neví o `sim`, `data/` ani `Input`/`Time`; neví ani to, KTERÁ klávesa
# ho otevírá (tu vlastní `app/player_controller`). Kdo obsah skládá a kdo
# teleportuje, je `app/debug_travel.gd` + `app/main.gd`.
#
# TVAR BODU: `{cislo:int, nazev:String, misto:String, proc:String, poznamka:String}`
# - `cislo` je ČÍSLICE, kterou se na bod skáče (1-9). Okno ji jen vypíše;
# kdyby si ji vymýšlelo samo, rozešlo by se to s klávesami.
#
# "NULA A PRÁZDNO NEJSOU ÚSPĚCH" (docs/09 §9.6): prázdný vstup se VYKRESLÍ
# (`(zadny testovaci bod ...)`) a vadné řádky se počítají do `skipped()` i do
# viditelného řádku - ticho by vypadalo jako "seznam je prázdný, ale v pořádku".
#
# Uzly se uvolňují `free()` (ne `queue_free()`): to druhé uvolní až na konci
# framu, takže by v okně zůstaly STARÉ řádky (naměřeno u `ui.backpack`).

const SIRKA: float = 460.0
const VYSKA: float = 210.0
# Šířka textu = šířka okna MÍNUS vnitřní okraj panelu (`PanelContainer` si
# kreslí rámeček); kdyby text chtěl celou šířku, okno by si ho samo rozšířilo.
const TEXT_SIRKA: float = 444.0
const BEZ_BODU := "(zadny testovaci bod - data/test-points.json se nepodarilo precist)"
const PRESKOCENO := "(%d vadnych bodu preskoceno)"
const ODDELOVAC := "  -  "

var _titulek: String = ""
var _body: Array[Dictionary] = []
var _prazdno_text: String = BEZ_BODU
var _skipped: int = 0
var _box: VBoxContainer = null
var _dirty: bool = false
var _prebaveni: int = 0


func _init() -> void:
	# NOVÉ OKNO JE ZAVŘENÉ: `Control` je v Godotu viditelný ve výchozím stavu.
	# O tom, kdy se otevře, rozhoduje volající (`app/player_controller`).
	visible = false


func nastav(titulek: String, body: Array, prazdno_text: String = BEZ_BODU) -> int:
	# Vstup z `app/`. Vrací počet přijatých bodů; `skipped()` počet vadných.
	# Body se KOPÍRUJÍ (UI nesmí měnit cizí data).
	_titulek = titulek
	_prazdno_text = prazdno_text if prazdno_text != "" else BEZ_BODU
	_body = []
	_skipped = 0
	for bod in body:
		if not (bod is Dictionary):
			_skipped += 1
			continue
		_body.append({
			"cislo": int((bod as Dictionary).get("cislo", 0)),
			"nazev": str((bod as Dictionary).get("nazev", "")),
			"misto": str((bod as Dictionary).get("misto", "")),
			"proc": str((bod as Dictionary).get("proc", "")),
			"poznamka": str((bod as Dictionary).get("poznamka", "")),
		})
	_dirty = true
	return _body.size()


func body() -> Array[Dictionary]:
	# KOPIE bodů (jako `ui.hotkeys.radky()`).
	return _body.duplicate(true)


func count() -> int:
	return _body.size()


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


func zavri() -> bool:
	# Vrací true, když okno bylo otevřené (volající to hlásí hráči); jinak false.
	var bylo: bool = visible
	visible = false
	return bylo


func toggle() -> bool:
	visible = not visible
	return visible


func prebaveni() -> int:
	return _prebaveni


func text_bodu(bod: Dictionary) -> String:
	# JEDNO místo, kde se text řádku skládá (test ho čte odsud, ne z uzlu).
	# Číslo a místo se píší VŽDY; prázdné pole se nevypisuje (prázdná závorka
	# by vypadala jako vada dat, kterou už ohlásil `app/`).
	var out: String = "%d) %s%s%s" % [int(bod.get("cislo", 0)),
		str(bod.get("nazev", "")), ODDELOVAC, str(bod.get("misto", ""))]
	var proc: String = str(bod.get("proc", ""))
	if proc != "":
		out += "  [" + proc + "]"
	var poznamka: String = str(bod.get("poznamka", ""))
	if poznamka != "":
		out += "  " + poznamka
	return out


func row_texts() -> Array:
	# Text řádků z UZLŮ (nezávislý zdroj než `_body`): když se uzel nekreslí,
	# je seznam prázdný - "text v proměnné není text na obrazovce".
	# Rozhoduje META, ne jméno: Godot při `add_child` PŘEJMENOVÁVÁ duplicitní
	# jména ("Bod", "Bod2", ...), takže filtr podle `name` by našel jen první.
	var out: Array = []
	if _box == null:
		return out
	for uzel in _box.get_children():
		if uzel is Label and bool(uzel.get_meta("bod", false)):
			out.append(str(uzel.text))
	return out


func flush() -> bool:
	if not _dirty:
		return false
	_dirty = false
	_prebaveni += 1
	var box: VBoxContainer = _ensure_box()
	# UVOLNĚNÍ JE OKAMŽITÉ (viz hlavička).
	for child in box.get_children():
		box.remove_child(child)
		child.free()
	if _titulek != "":
		var t := Label.new()
		t.name = "Titulek"
		t.set_meta("titulek", true)
		t.text = _titulek
		box.add_child(t)
	if _body.is_empty():
		var prazdny := Label.new()
		prazdny.name = "Prazdno"
		prazdny.text = _prazdno_text
		box.add_child(prazdny)
	else:
		for bod in _body:
			var l := Label.new()
			l.name = "Bod"
			l.set_meta("bod", true)
			l.text = text_bodu(bod)
			# AUTOWRAP + výška 0: dlouhá poznámka se ZALOMÍ (Label s pevnou
			# výškou by text odstřihl). Šířku dává kontejner.
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(TEXT_SIRKA, 0.0)
			box.add_child(l)
	if _skipped > 0:
		var chyba := Label.new()
		chyba.name = "Preskoceno"
		chyba.set_meta("preskoceno", true)
		chyba.text = PRESKOCENO % _skipped
		box.add_child(chyba)
	# POZADÍ MUSÍ NARŮST S OBSAHEM (naměřeno 2026-10-20 na snímku: zalomené
	# poznámky přetekly POD pozadí a text ležel na mapě). `PanelContainer` není
	# v kontejneru, takže mu velikost nikdo nenastaví - bere se jeho minimální
	# velikost z obsahu (řádky + rámeček).
	var panel := get_node_or_null("Panel") as Control
	if panel != null:
		panel.size = panel.get_combined_minimum_size()
	return true


func _ensure_box() -> VBoxContainer:
	if _box == null:
		# POZADÍ JE POD KRITICKY DŮLEŽITÝ TEXT: bez něj by seznam ležel přímo
		# na mapě a nedal se přečíst (stejná vada jako u okna batohu a nápovědy).
		var panel := PanelContainer.new()
		panel.name = "Panel"
		panel.custom_minimum_size = Vector2(SIRKA, VYSKA)
		panel.size = Vector2(SIRKA, VYSKA)
		add_child(panel)
		_box = VBoxContainer.new()
		_box.name = "Body"
		# MEZERA 0: každá mezera navíc odsune poslední řádek pod okraj okna.
		_box.add_theme_constant_override("separation", 0)
		panel.add_child(_box)
	return _box


func _process(_delta: float) -> void:
	flush()
