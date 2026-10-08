extends RefCounted
# ui.craft_gump - okno vyroby (20. session; smlouva docs/04 §4.4 `gump_open`,
# tok §4.6.3 "dvojklik na kladivo -> gump s recepty").
#
# Meri se, ze okno:
#   * se otevre UDALOSTI (`gump_open` s `gump:"craft"`), ne kliknutim na sebe,
#   * cizi udalost ignoruje (`message` ho nesmi otevrit),
#   * kliknuti na recept prelozi na POZADAVEK `{t:"craft", recipe, count}`
#     a nikam ho neposila (`app/` si ji vyzvedne - UI nezna `sim`),
#   * prazdny seznam receptu rekne ("(no recipes)"), nez aby mlcel,
#   * `flush()` se prebavi jen pri zmene.

const Lib = preload("res://tests/lib.gd")
const CRAFT_GUMP := "res://ui/craft_gump.gd"


func run(t) -> void:
	var script = Lib.script_at(CRAFT_GUMP)
	if script == null:
		t._pending("ui.craft_gump NENI K DISPOZICI: " + CRAFT_GUMP)
		return
	var okno = script.new()
	t._check(okno.pocet() == 0 and not okno.je_otevreny(),
		"ui.craft_gump: nove okno je zavrene a prazdne (pocet %d, otevrene %s)"
			% [okno.pocet(), str(okno.je_otevreny())])

	# 1) otevreni UDALOSTI - TVAR ZE SMLOUVY (docs/04 §4.4): `{gump, data}`,
	# takze recepty jsou v `data.data.recipes`.
	var otevreno: bool = okno.apply_event({"name": "gump_open", "data": {
		"gump": "craft", "data": {"skill": 7, "recipes": [{"id": 7, "name": "x", "min_skill": 0.0}]}}})
	var cizi: bool = okno.apply_event({"name": "message", "data": {"text": "hi"}})
	var jiny: bool = okno.apply_event({"name": "gump_open", "data": {
		"gump": "container", "data": {"serial": 5, "items": []}}})
	t._check(otevreno and okno.je_otevreny() and not cizi and not jiny,
		"ui.craft_gump: okno otevre POUZE `gump_open{gump:'craft'}` (otevreno %s, message %s, container %s)"
			% [str(otevreno), str(cizi), str(jiny)])

	# 2) recepty vstupem + klik -> pozadavek
	var recepty: Array = [
		{"id": 42, "name": "dagger", "min_skill": 1.0},
		{"id": 43, "name": "longsword", "min_skill": 28.0},
	]
	okno.nastav_recepty(recepty)
	t._check(okno.pocet() == 2, "ui.craft_gump: recepty jdou vstupem (pocet %d)" % okno.pocet())
	t._check(okno.text_receptu(okno.recepty()[0]) == "dagger (1.0)",
		"ui.craft_gump: radek receptu je 'jmeno (min_skill)' (namEReno '%s')"
			% okno.text_receptu(okno.recepty()[0]))
	t._check(okno.odeber_pozadavek().is_empty(),
		"ui.craft_gump: bez kliknuti neni zadny pozadavek")
	var klik: bool = okno.stiskni(43)
	var pozadavek: Dictionary = okno.odeber_pozadavek()
	t._check(klik and str(pozadavek.get("t", "")) == "craft"
			and int(pozadavek.get("recipe", -1)) == 43 and int(pozadavek.get("count", 0)) == 1,
		"ui.craft_gump: klik na recept da pozadavek `{t:'craft', recipe:43, count:1}` (vyslo %s)"
			% str(pozadavek))
	t._check(okno.odeber_pozadavek().is_empty(),
		"ui.craft_gump: pozadavek se vyzvedne JEDNOU (druhe volani je prazdne)")
	t._check(not okno.stiskni(9999),
		"ui.craft_gump: klik na neznamy recept nic neposle")

	# 3) flush() se prebavi jen pri zmene a prazdny seznam neni ticho
	okno.flush()
	okno.flush()
	t._check(okno.prebaveni() == 1,
		"ui.craft_gump: druhy `flush()` bez zmeny nic neprebavi (prebaveni %d)"
			% okno.prebaveni())
	okno.nastav_recepty([])
	okno.flush()
	var text: String = ""
	var box = okno.get_node_or_null("Recepty")
	if box != null:
		for child in box.get_children():
			if child is Label and str(child.text) == "(no recipes)":
				text = str(child.text)
	t._check(text == "(no recipes)",
		"ui.craft_gump: prazdny seznam receptu rekne '(no recipes)' (namEReno '%s')" % text)
