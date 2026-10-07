extends RefCounted
# ui.status_bar - stavovy pruh (granule ui.status_bar, docs/07 §7.3). Test meri
# TEXT pro ZNAMY vstup (presny retezec), prenos do `Labelu` a to, ze hodnoty
# chodi VSTUPEM: chybejici i vadne hodnoty jsou 0, nikdy pad. UI nic nepocita.
#
# Uzel (`Control` + dite `Label`) se po testu UVOLNI pres `free()` - Node neni
# RefCounted a nez uvolneny uzel shodi cely beh testovaci sady.
#
# Cesta k souboru je VSTUP: `-- --status-bar-script=<cesta>` - mutacni harness
# (tools/gates/mutace-tests.py) tim dokazuje, ze test meri opravdu ten soubor.

const Lib = preload("res://tests/lib.gd")
const BAR_SCRIPT := "res://ui/status_bar.gd"

# ZNAMY vstup a ZNAMY vystup: test je NEPODMINENY - rozbity status_bar.gd
# (spatny format, text se nedostane do Labelu) musi sadu shodit.
const ZNAMY := {"hp": 55, "hp_max": 100, "stam": 10, "stam_max": 10,
	"mana": 25, "mana_max": 25, "weight": 12, "weight_max": 400, "gold": 1000}
const ZNAMY_TEXT := "hp=55/100, stam=10/10, mana=25/25, weight=12/400, gold=1000"
const PRAZDNY_TEXT := "hp=0/0, stam=0/0, mana=0/0, weight=0, gold=0"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _text_of(bar) -> String:
	# Pres `get("label")`, aby chybejici Label nevyhodil runtime error a
	# neprerusil case (pak by se zmerilo mene kontrol, nez se tvrdi).
	var l = bar.get("label")
	return "" if l == null else str(l.text)


func run(t) -> void:
	var cesta: String = _arg("status-bar-script", BAR_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("ui.status_bar NENI HOTOVA: " + cesta + " chybi nebo se neparsuje")
		return
	var bar = script.new()
	# API musi byt CELE: chybejici metoda by case shodila s 0 kontrolami a mutace
	# by prosla jako slepa. Kontrola se prida JEN kdyz neco chybi (zdrave = 11).
	var chybi: Array[String] = []
	for metoda in ["text_for", "update", "apply_event"]:
		if not bar.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "ui.status_bar: chybi metody %s - case se neda merit" % str(chybi))
		bar.free()
		return

	# 1) PRESNY text pro ZNAMY vstup - a VYPISE se, aby bylo videt, ze neni prazdny
	var text: String = str(bar.text_for(ZNAMY)) if bar.has_method("text_for") else ""
	print("[test]      mereno (status_bar, znamy vstup): ", text)
	t._check(text == ZNAMY_TEXT,
		"ui.status_bar: text_for(znamy vstup) == '%s' (namEReno '%s')" % [ZNAMY_TEXT, text])

	# 2) hodnoty se dostanou do Labelu (Label funguje i bez okna)
	bar.update(ZNAMY)
	t._check(bar.get("label") is Label,
		"ui.status_bar: update() vytvori dite Label (i bez okna)")
	t._check(_text_of(bar) == ZNAMY_TEXT,
		"ui.status_bar: update() nastavi text Labelu (namEReno '%s')" % _text_of(bar))

	# 3) chybejici klice = 0 (zadny pad, zadne tiche prazdno)
	t._check(str(bar.text_for({})) == PRAZDNY_TEXT,
		"ui.status_bar: chybejici klice jsou 0 (namEReno '%s')" % str(bar.text_for({})))

	# 4) bez `weight_max` se max vahy NEVYMYSLI (max vahy patri do sim/, ne do UI)
	var bez_max: String = str(bar.text_for({"weight": 12}))
	t._check(bez_max == "hp=0/0, stam=0/0, mana=0/0, weight=12, gold=0",
		"ui.status_bar: bez weight_max vypise 'weight=12' (namEReno '%s')" % bez_max)

	# 5) volitelne jmeno se prida na zacatek (docs/04 §4.2: pruh ma i jmeno)
	var s_jmenem: String = str(bar.text_for({"name": "Lord British"}))
	t._check(s_jmenem.begins_with("Lord British, hp="),
		"ui.status_bar: volitelne 'name' je na zacatku (namEReno '%s')" % s_jmenem)

	# 6) vadne typy = 0, zaporne cislo zustava (UI nic neopravuje ani nezaokrouhluje)
	var vadne: String = str(bar.text_for({"hp": "abc", "stam": null, "gold": -5}))
	t._check(vadne == "hp=0/0, stam=0/0, mana=0/0, weight=0, gold=-5",
		"ui.status_bar: text a null jsou 0, -5 zustava (namEReno '%s')" % vadne)

	# 6b) udalost `stats_changed` ma `max_hp` (docs/04 §4.4), ne `hp_max` -
	#     jinak by status bar u skutecne udalosti vypsal hp=55/0
	var s_alias: String = str(bar.text_for({"hp": 55, "max_hp": 100}))
	t._check(s_alias == "hp=55/100, stam=0/0, mana=0/0, weight=0, gold=0",
		"ui.status_bar: prijme 'max_hp' z udalosti stats_changed (namEReno '%s')" % s_alias)

	# 7) druhy update hodnoty NAHRADI (nescita se, nededi stare)
	bar.update(ZNAMY)
	bar.update({"gold": 7})
	t._check(_text_of(bar) == "hp=0/0, stam=0/0, mana=0/0, weight=0, gold=7",
		"ui.status_bar: update() nahradi hodnoty, nededi stare (namEReno '%s')" % _text_of(bar))

	# 8) udalost `stats_changed` (docs/04 §4.4); jina udalost se neprevezme
	var cizi: bool = bar.apply_event({"name": "message", "data": {"text": "hi"}})
	var zmena: bool = bar.apply_event({"name": "stats_changed", "data": ZNAMY})
	t._check(cizi == false and zmena == true and _text_of(bar) == ZNAMY_TEXT,
		"ui.status_bar: apply_event bere jen 'stats_changed' (cizi %s, zmena %s, text '%s')"
			% [str(cizi), str(zmena), _text_of(bar)])
	t._check(bar.apply_event({}) == false
			and bar.apply_event({"name": "stats_changed", "data": "ne"}) == false,
		"ui.status_bar: vadna udalost vraci false (prazdna i s 'data' mimo slovnik)")

	bar.free()   # Control + dite Label - Node se uvolnuje rucne
