extends RefCounted
# ui.skill_list - seznam skillu (granule `ui.skill_list`, docs/04 §4.2,
# docs/05 §5.3).
#
# Test meri CHOVANI:
#   * 58 radku pro 58 skillu z REALNYCH dat (`data/skills.json`) - hodnoty
#     dodava `entity.skills` (desetiny), UI je jen FORMATUJE (300 -> "30.0"),
#   * zamky `up/down/lock` (a nezname -> "?"), zadne tiche "lock",
#   * tlacitko "use" jen OHLASTuje (`use_pressed`); po stisku se v UI NIC nezmeni
#     (tenky klient - UI nesmi menit stav `sim`, docs/04 §4.1),
#   * prazdny vstup se VYKRESLI a preskocene (vadne) radky se pocitaji i ukazou
#     (docs/09 §9.6: nula a prazdno nejsou uspech),
#   * uzly se na konci uvolni pres `free()` (Node neni RefCounted).
#
# Cesta k souboru je VSTUP: `-- --skill-list-script=<cesta>`.

const Lib = preload("res://tests/lib.gd")
const SkillsScript = preload("res://sim/entity/skills.gd")

const SKILL_LIST_SCRIPT := "res://ui/skill_list.gd"
const SKILLS_DATA := "res://data/skills.json"
const POCET_SKILLU := 58

var _ozvena: Array = []


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _na_use(skill: int) -> void:
	_ozvena.append(skill)


func _texty_labelu(list) -> Array:
	# Texty uzlu v celem strome (nezavisly zdroj nez `row_texts()` modulu).
	var out: Array = []
	for uzel in list.get_children():
		if uzel is Label:
			out.append(str(uzel.text))
		for dite in uzel.get_children():
			if dite is Label:
				out.append(str(dite.text))
	return out


func _obsahuje(list, text: String) -> bool:
	return _texty_labelu(list).has(text)


func run(t) -> void:
	var cesta: String = _arg("skill-list-script", SKILL_LIST_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("ui.skill_list NENI HOTOV: " + cesta + " chybi nebo se neparsuje")
		return
	var list = script.new()
	var chybi: Array[String] = []
	for metoda in ["update", "count", "format_value", "lock_text", "row_texts",
			"use_button_of", "skipped", "empty_text"]:
		if not list.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "ui.skill_list: chybi metody %s - case se neda merit" % str(chybi))
		list.free()
		return

	# A) FORMATOVANI DESETIN: presne retezce (0.0-120.0)
	var pripady: Dictionary = {300: "30.0", 1000: "100.0", 1200: "120.0",
		5: "0.5", 0: "0.0", -5: "-0.5", 999: "99.9"}
	for hodnota in pripady.keys():
		var text: String = str(list.format_value(int(hodnota)))
		t._check(text == str(pripady[hodnota]),
			"ui.skill_list: format_value(%d) == '%s' (namEReno '%s')"
				% [int(hodnota), str(pripady[hodnota]), text])

	# B) ZAMKY: 0 up, 1 down, 2 lock; nezname = "?" (ne tise "lock")
	t._check(str(list.lock_text(0)) == "up" and str(list.lock_text(1)) == "down"
			and str(list.lock_text(2)) == "lock" and str(list.lock_text(5)) == "?",
		"ui.skill_list: zamky up/down/lock a nezname '?' (namEReno '%s/%s/%s/%s')"
			% [str(list.lock_text(0)), str(list.lock_text(1)), str(list.lock_text(2)),
				str(list.lock_text(5))])

	# C) 58 SKILLU: radky z REALNYCH dat; hodnoty/zamky z `entity.skills`
	var data = Lib.json_at(SKILLS_DATA)
	if not (data is Array):
		t._check(false, "ui.skill_list: " + SKILLS_DATA + " nejde nacist jako seznam")
		list.free()
		return
	t._check((data as Array).size() == POCET_SKILLU,
		"ui.skill_list: data/skills.json ma 58 skillu (namEReno %d)" % (data as Array).size())
	var skills = SkillsScript.new()
	skills.set_value(7, 300)                 # Blacksmithy 30.0
	skills.set_value(46, 1000)               # Meditation 100.0
	skills.set_value(45, 5)                  # Mining 0.5
	skills.set_lock(7, 1)                    # down
	skills.set_lock(46, 2)                   # lock
	var radky: Array = []
	for rec in data:
		var id: int = int(rec["id"])
		radky.append({"id": id, "name": str(rec["name"]),
			"value": skills.value(id), "lock": skills.lock(id)})
	var pocet: int = list.update(radky)
	t._check(pocet == POCET_SKILLU and list.count() == POCET_SKILLU,
		"ui.skill_list: update vykresli 58 radku z 58 vstupu (vyslo %d, count %d)"
			% [pocet, list.count()])
	var texty: Array = list.row_texts()
	t._check(texty.size() == POCET_SKILLU and str(texty[7]) == "Blacksmithy | 30.0 | down",
		"ui.skill_list: radek 7 je 'Blacksmithy | 30.0 | down' (namEReno '%s')" % str(texty[7]))
	t._check(str(texty[46]) == "Meditation | 100.0 | lock",
		"ui.skill_list: radek 46 je 'Meditation | 100.0 | lock' (namEReno '%s')" % str(texty[46]))
	t._check(str(texty[45]) == "Mining | 0.5 | up",
		"ui.skill_list: radek 45 je 'Mining | 0.5 | up' (namEReno '%s')" % str(texty[45]))
	t._check(str(texty[0]).begins_with(str(data[0]["name"]) + " | 0.0 | up"),
		"ui.skill_list: nezmeneny skill je '0.0' a zamek 'up' (namEReno '%s')" % str(texty[0]))

	# D) TLACITKO "use" JEN OHLASTuje - UI stav NEMENI
	list.use_pressed.connect(_na_use)
	var tlacitko = list.use_button_of(7)
	t._check(tlacitko is Button and str(tlacitko.text) == "use",
		"ui.skill_list: radek ma tlacitko 'use' (namEReno %s)" % str(tlacitko))
	var texty_pred: Array = list.row_texts()
	if tlacitko is Button:
		tlacitko.pressed.emit()
	t._check(_ozvena == [7],
		"ui.skill_list: stisk ohlasti `use_pressed` se skill id (namEReno %s)" % str(_ozvena))
	t._check(list.row_texts() == texty_pred and list.count() == POCET_SKILLU,
		"ui.skill_list: po stisku se v UI NIC nezmeni (tenky klient)")
	t._check(list.use_button_of(9999) == null,
		"ui.skill_list: nezname id nema tlacitko (null, ne vymysleny radek)")

	# E) PRAZDNY VSTUP JE VIDET (nula a prazdno nejsou uspech)
	list.update([])
	t._check(list.count() == 0 and list.row_texts().is_empty(),
		"ui.skill_list: prazdny vstup nema radky (count %d)" % list.count())
	t._check(_obsahuje(list, str(list.empty_text())),
		"ui.skill_list: prazdny vstup se VYKRESLI textem '%s'" % str(list.empty_text()))

	# F) VADNE RADKY SE POCITAJI I UKAZOU
	var pocet2: int = list.update([{"id": 1, "name": "Alchemy", "value": 10, "lock": 0},
		"nesmysl", 42])
	t._check(pocet2 == 1 and list.count() == 1 and list.skipped() == 2,
		"ui.skill_list: z 3 vstupu se vykresli 1 a 2 se preskoci (vyslo %d, count %d, skipped %d)"
			% [pocet2, list.count(), list.skipped()])
	t._check(_obsahuje(list, "(2 vadnych radku preskoceno)"),
		"ui.skill_list: preskocene radky jsou v okne VIDET (texty %s)" % str(_texty_labelu(list)))
	list.update([{}])
	t._check(list.count() == 1 and str(list.row_texts()[0]) == " | 0.0 | up",
		"ui.skill_list: chybejici klice jsou 0 a 'up', zadny pad (namEReno '%s')"
			% str(list.row_texts()[0]))

	# G) UZLY: pred uvolnenim musi neco byt (jinak by `free()` nic nedokazoval)
	t._check(list.get_child_count() > 0,
		"ui.skill_list: okno ma uzly, ktere je potreba uvolnit (potomku %d)"
			% list.get_child_count())
	list.free()
