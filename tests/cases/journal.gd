extends RefCounted
# ui.journal - zurnal zprav (docs/04 §4.2 a §4.4).
#
# Test meri CHOVANI, ne pritomnost metody:
#   * `apply_event` bere CELY slovnik `{name, data}` a jen udalost `message`;
#     jina udalost vraci false a nic nezmeni (a chybejici `data` nesmi shodit),
#   * "100 zprav nezpomali frame" (prompt granule) = 100 zprav v JEDNE davce
#     znamena JEDNO prebaveni textu (`rebuilds()`), ne 100; fronta se drzi na
#     `MAX_LINES` a starsi se pocitaji do `dropped()`,
#   * barvy podle typu (neznamy typ = barva systemu) a escapovani BBCode,
#   * `clear()` vyprázdní.
#
# Cesta k souboru je VSTUP: `-- --journal-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")

const JOURNAL_SCRIPT := "res://ui/journal.gd"
const MAX_LINES := 200


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("journal-script", JOURNAL_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("ui.journal NENI HOTOVY: " + cesta + " chybi (nebo ma parse error)")
		return
	var zurnal = script.new()

	# -- A) udalost `message` (a jen ona) --------------------------------
	t._check(zurnal.apply_event({"name": "message", "data": {"text": "Hello", "kind": "system"}}),
		"ui.journal: `message` se prijme (vyslo %s)" % str(zurnal.message_count()))
	t._check(not zurnal.apply_event({"name": "stats_changed", "data": {"hp": 1}}),
		"ui.journal: cizi udalost (`stats_changed`) vraci false a neuklada se")
	t._check(not zurnal.apply_event({"name": "message"}),
		"ui.journal: `message` bez `data` vraci false (a nepadne)")
	t._check(zurnal.message_count() == 1,
		"ui.journal: po trech udalostech je v zurnalu 1 zprava (namEReno %d)" % zurnal.message_count())
	t._check(not zurnal.add("   "),
		"ui.journal: prazdna zprava se neuklada (prazdny radek neni obsah)")

	# -- B) 100 zprav = JEDNO prebaveni textu ----------------------------
	var pred: int = zurnal.rebuilds()
	var davka: Array = []
	for i in 100:
		davka.append({"name": "message", "data": {"text": "zprava %d" % i, "kind": "combat"}})
	var prijato: int = zurnal.apply_events(davka)
	t._check(prijato == 100, "ui.journal: davka 100 zprav prijala vsech 100 (namEReno %d)" % prijato)
	t._check(zurnal.message_count() == 101,
		"ui.journal: vsech 100 zprav je ulozeno (namEReno %d)" % zurnal.message_count())
	t._check(zurnal.rebuilds() == pred,
		"ui.journal: `apply_events` text NEPREBAVUJE (rebuilds zustava %d)" % pred)
	zurnal.flush()
	t._check(zurnal.rebuilds() == pred + 1,
		"ui.journal: `flush()` prebavi text JEDNOU za davku (rebuilds %d -> %d)"
			% [pred, zurnal.rebuilds()])

	# -- C) strop fronty -------------------------------------------------
	for i in 300:
		zurnal.add("dalsi %d" % i)
	t._check(zurnal.message_count() == MAX_LINES,
		"ui.journal: fronta se drzi na %d zpravach (namEReno %d)" % [MAX_LINES, zurnal.message_count()])
	t._check(zurnal.dropped() == 201,
		"ui.journal: starsi zpravy se pocitaji do `dropped()` (namEReno %d)" % zurnal.dropped())

	# -- D) barvy podle typu ---------------------------------------------
	# Kazda dvojice musi byt RUZNA: kontrola "say != combat" sama o sobe
	# neprojde, kdyz se `combat` splete s barvou systemu (nasel mutacni test).
	var barvy: Array = []
	for druh in ["system", "say", "combat", "craft"]:
		barvy.append(zurnal.color_of(druh))
	var vsechny_ruzne: bool = true
	for x in barvy.size():
		for y in range(x + 1, barvy.size()):
			if barvy[x] == barvy[y]:
				vsechny_ruzne = false
	t._check(vsechny_ruzne,
		"ui.journal: vsechny ctyri typy maji RUZNOU barvu (namEReno %s)" % str(barvy))
	t._check(zurnal.color_of("nesmyslny_typ") == zurnal.color_of("system"),
		"ui.journal: neznamy typ ma barvu systemu (nezustane bez barvy)")

	# -- E) text a escapovani BBCode -------------------------------------
	zurnal.clear()
	t._check(zurnal.message_count() == 0, "ui.journal: `clear()` vyprázdní frontu")
	zurnal.add("najdi me", "system", 0, "Bob")
	t._check(zurnal.plain_text().find("Bob: najdi me") >= 0,
		"ui.journal: `plain_text()` sklada jmeno a text (namEReno %s)" % zurnal.plain_text())
	zurnal.add("[b]nebezpecny[/b]", "say")
	zurnal.flush()
	t._check(zurnal.label != null and zurnal.label.text.find("[lb]") >= 0,
		"ui.journal: `[` v textu se escapuje na `[lb]` (jinak by text rozbil BBCode)")
	# ⚠ VELIKOST: `RichTextLabel` s velikosti (0,0) text NEVYKRESLI - testy to
	# jinak nepoznaji (ctou `label.text`), v demu byl zurnal prazdny (namEReno
	# 16. session srovnanim snimku). Kontrola je tu proto.
	t._check(zurnal.label.size.x > 0.0 and zurnal.label.size.y > 0.0,
		"ui.journal: label ma NENULOVOU velikost %s (jinak text neni videt)"
			% str(zurnal.label.size))

	t._check(true, "ui.journal: case probehl cely (sentinel)")
