extends Control
# ui.policy_panel - okno PRAVIDEL POLITIKY (granule `ui.policy_panel`, 2026-10-09).
#
# CO TENHLE MODUL JE (rozhodnuti D3, `ROZHODNUTI-2026-10-09-SMER.md` §2):
# pravidla s podminkami dnes existuji jen jako rucne psany `user://policy.json`
# a ve hre je NEBYLO VIDET. Tohle okno je dela viditelnymi: pro kazde nactene
# pravidlo rekne prioritu, id a DUVOD, proc platilo / neplatilo - a nahore stav
# vykonavatele (`sim.executor.status()`).
#
# JE TO JEN CTENI (uzivatel 2026-10-09: "D3 prijmu jen jako HUD"). Okno
# needituje pravidla, neuklada je, neposila zadny prikaz a nic nerozhoduje.
# "Hra smi provest, co hrac rozhodl - nesmi rozhodnout za nej": kdyby UI
# umelo pravidla menit, byla by to zmena politiky za hrace.
#
# JE TO TENKY KLIENT (docs/04 §4.1, stejne jako `ui.backpack` a `ui.status_bar`):
# dostane RADKY a STAV VSTUPEM a jen je vykresli. Nevi o `sim/`, `data/` ani
# `render/`, nevola `Input`/`Time`/`OS` a nic nepocita - ani netridi (poradi
# dostava hotove; kdyby si ho UI preusporadalo, vymyslelo by si pravidlo).
# Kdo obsah plni, je `app/main.gd` - tam se potkava `sim` s UI.
#
# CO SE CTE Z DUVODU (a je to jedna z hlavnich veci, ktere ma okno ukazat):
#   `sim.policy.evaluate()` vraci u kazdeho pravidla `why` (napr. "item 3717:
#   0 < 1") a `last_skipped()` vraci `why` i u pravidel, ktera NEprosla
#   ("stav nezna: inventory"). Cislo u pravidla je proto DUVOD, ne vysledek:
#   pole `reason` v radku je `why` z posledniho vyhodnoceni.
#
# PREBAVUJE SE JEN PRI ZMENE (`flush()` jako `ui.journal`/`ui.backpack`):
# seznam pravidel se v prubehu hry nemeni, ale duvod u kazdeho pravidla ano.
# Kdyby se okno stavělo kazdy frame, platilo by to framy za neco, co ma byt
# jen videt. `flush()` vola VOLAJICI po `nastav_pravidla()` - okno si samo
# `_process()` NEDRZI: namEReno 2026-10-09, automaticky flush běžel UPROSTRED
# testu (engine zavola `_process` mezi dvema volanimi) a prebaveni se rozeslo
# s tim, co test meril ("druhy flush nic neprebavi" spadlo, protoze prvni
# flush uz spotreboval engine). Vykreslovani je tim deterministicke.
#
# PRVKY: radek je `{id:String, priority:int, reason:String}`. Prazdny seznam
# neni chyba - okno to rekne ("(zadna pravidla)") a UKAZE CESTU
# (`user://policy.json`): pravidla se porad zadavaji rucne a bez te vety by hrac
# nevedel, odkud se berou (namEReno verifikaci 2026-10-09: prvni verze
# pripominku jen SLIBOVALA v komentari, ale nevykreslovala ji).
#
# ⚠ HLAVICKA JE UZEL, NE JEN TEXT (namEReno 2026-10-09 snimkem): prvni verze
# drzela stav vykonavatele jen v promenne `_hlavicka` a na obrazovku se
# NEDOSTALA - testy pritom byly zelene, protoze `hlavicka_text()` vracel
# spravny retezec. Chybu nasel az snimek (`_analyza/p33-panel-obraz.gd`),
# presne jak to pozaduje `docs/09 §9.6` u vizualni zmeny.
#
# UZLY: `PravidlaHlavicka` (Label se stavem) + `PravidlaObsah` (VBoxContainer
# s radky). Hlavicka je PRVNI dite, takze se v okne kresli nad seznamem.

const SIRKA: float = 300.0
const VYSKA: float = 320.0
const RADEK_VYSKA: float = 20.0
const HLAVICKA_VYSKA: float = 20.0
const MEZERA: float = 4.0        # odstup obsahu od hlavicky (px)

const BEZ_PRAVIDEL: String = "(zadna pravidla)"
# Prazdne okno musi rict i CESTU: pravidla se zadavaji rucne do `user://`, a to
# je mimo repo - bez tehle vety hrac vi, ze nic neni, ale ne vi, co s tim.
const KDE_PRAVIDLA: String = "pravidla se pisou do user://policy.json"
const BEZ_STAVU: String = "(stav nevykonavatele neni znamy)"
const PRAZDNO: String = "-"

var _radky: Array[Dictionary] = []
var _stav: Dictionary = {}
var _telo: String = ""
var _hlavicka: String = ""
var _dirty: bool = true
var _box: VBoxContainer = null
var _hlavicka_uzel: Label = null
var _prebaveni: int = 0


func _init() -> void:
	# NOVE OKNO JE ZAVRENE (stejna past jako u `ui.backpack`): `Control` je
	# v Godotu viditelny ve vychozim stavu, takze bez tohohle by okno pri
	# startu prekrylo svet a test by meril neco jineho, nez hra dela.
	visible = false


func nastav_pravidla(radky: Array, stav: Dictionary) -> void:
	# Vstup z `app/`: seznam radku `{id, priority, reason}` + stav vykonavatele;
	# `stav` muze byt `{}` (vykonavatel jeste neni). Chybejici klic v radku neni
	# pad: id zustane prazdne, priorita 0 a duvod prazdny - a je to VIDET
	# ("#0 " s prazdnym id), proto se id nikdy nevymysli.
	#
	# ⚠ HLAVICKA NENI SOUCAST TELA: kdyby se stav vypisoval jako prvni radek
	# seznamu, mizel by s poctem pravidel a `telo_text()` by mesil dve veci
	# (seznam a stav). Drzi se zvlast; na obrazovku ji kresli `flush()`
	# (`_ensure_hlavicka()`), text vraci `hlavicka_text()`.
	_radky = []
	for radek in radky:
		if not (radek is Dictionary):
			continue
		_radky.append({
			"id": str(radek.get("id", "")),
			"priority": int(radek.get("priority", 0)),
			"reason": str(radek.get("reason", "")),
		})
	_stav = stav.duplicate(true) if stav is Dictionary else {}
	_dirty = true


func radky() -> Array[Dictionary]:
	# KOPIE (jako `ui.hud.layout()`): zmena vraceneho seznamu nesmi menit okno.
	return _radky.duplicate(true)


func stav() -> Dictionary:
	return _stav.duplicate(true)


func telo_text() -> String:
	# Text seznamu - JEDNO misto, kde se sklada (test i sonda ho ctou odsud).
	var text: String = ""
	for radek in _radky:
		text += text_radku(radek) + "\n"
	return text


func hlavicka_text() -> String:
	return _hlavicka


func stav_text() -> String:
	# Radek se stavem vykonavatele. Chybejici stav se NEVYMYSLI jako "bezi":
	# rekne se, ze neni znamy (`docs/09 §9.6` - nemerena nula neni uspech).
	if _stav.is_empty():
		return BEZ_STAVU
	var kde: String = "zastaveno" if bool(_stav.get("stopped", false)) else "ceka"
	var reason: String = str(_stav.get("reason", ""))
	if reason.is_empty():
		reason = PRAZDNO
	var pravidlo: String = str(_stav.get("rule", ""))
	if pravidlo.is_empty():
		pravidlo = PRAZDNO
	return "%s: %s | pravidlo: %s | prikazu: %d" % [
		kde, reason, pravidlo, int(_stav.get("commands_sent", 0))]


func text_radku(radek: Dictionary) -> String:
	# Radek pravidla: "#<priorita> <id> - <duvod>". Priorita je prvni, aby
	# bylo videt, ktere pravidlo rozhoduje (vyssi cislo = drive).
	var duvod: String = str(radek.get("reason", ""))
	return "#%d %s - %s" % [
		int(radek.get("priority", 0)), str(radek.get("id", "")),
		duvod if not duvod.is_empty() else PRAZDNO]


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
	# Prebavi uzly JEN kdyz se obsah zmenil; vraci, jestli se prebavovalo.
	if not _dirty:
		return false
	_dirty = false
	_prebaveni += 1
	_hlavicka = "PRAVIDLA (%d) | %s" % [_radky.size(), stav_text()]
	# Hlavicka MUSI byt uzel (namEReno snimkem: text v promenne se nekresli).
	var hlavicka: Label = _ensure_hlavicka()
	hlavicka.text = _hlavicka
	var box: VBoxContainer = _ensure_box()
	# ⚠ OBSAH SE POSOUVA POD SKUTECNOU VYSKU HLAVICKY (namEReno verifikaci
	# 2026-10-09): konstanta `HLAVICKA_VYSKA = 20` je jen DOLNI ODRAD, ale text
	# ma vysku 23 px - obsah pak zacinal o 3 px vys, nez hlavicka konci, a prvni
	# radek se s ni prekryl. Sonda to ukazala jako `prekryv=true` a mutace
	# "posun na (0,0)" prosla vsemi 1671 kontrolami (byla to slepa kontrola).
	# Pozice se proto pocita z `get_combined_minimum_size()` - to je hodnota,
	# kterou Godot zna i bez layoutu (testy bez okna).
	var pod_hlavickou: float = maxf(HLAVICKA_VYSKA, hlavicka.get_combined_minimum_size().y)
	box.position = Vector2(0.0, pod_hlavickou + MEZERA)
	# UVOLNENI JE OKAMZITE (`free()`), ne `queue_free()`: to druhe uvolni az na
	# konci framu, takze by v okne zustaly STARE radky (namEReno u `ui.backpack`).
	_vycisti(box)
	_telo = telo_text()
	if _radky.is_empty():
		var prazdny := Label.new()
		prazdny.name = "Prazdno"
		prazdny.text = BEZ_PRAVIDEL
		box.add_child(prazdny)
		var kde := Label.new()
		kde.name = "KdePravidla"
		kde.text = KDE_PRAVIDLA
		box.add_child(kde)
		return true
	for radek in _radky:
		var radek_uzel := Label.new()
		radek_uzel.text = text_radku(radek)
		radek_uzel.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
		box.add_child(radek_uzel)
	return true


func _vycisti(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()


func _ensure_hlavicka() -> Label:
	if _hlavicka_uzel == null:
		_hlavicka_uzel = Label.new()
		_hlavicka_uzel.name = "PravidlaHlavicka"
		_hlavicka_uzel.custom_minimum_size = Vector2(SIRKA, HLAVICKA_VYSKA)
		_hlavicka_uzel.position = Vector2(0.0, 0.0)
		add_child(_hlavicka_uzel)
	return _hlavicka_uzel


func _ensure_box() -> VBoxContainer:
	if _box == null:
		_box = VBoxContainer.new()
		_box.name = "PravidlaObsah"
		# VELIKOST: `custom_minimum_size` je ta, na ktere stoji vykresleni
		# (Control s vychozi velikosti (0,0) text NEKRESLI - stejna past jako
		# u `ui.journal`; namEReno verifikaci 2026-10-09: `size` sam je pri
		# kazdem prirazeni REDUNDANTNI, protoze Godot drzi `size >= custom_minimum_size`).
		# Obe veliciny se nastavuji ZAMERNE (konvence `ui/backpack.gd` a
		# `ui/journal.gd`): kdo cte jen `size`, nesmi dostat nulu.
		_box.custom_minimum_size = Vector2(SIRKA, VYSKA)
		_box.size = Vector2(SIRKA, VYSKA)
		add_child(_box)
	return _box
