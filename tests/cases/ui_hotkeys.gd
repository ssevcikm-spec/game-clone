extends RefCounted
# ui.hotkeys + data/help.json - napoveda pro hrace (session D, 2026-10-11).
#
# Test meri CHOVANI, ne existenci souboru:
#   1. `ui.hotkeys` je TENKY KLIENT: radky dostane vstupem, vykresli je do UZLU
#      (text v promenne neni text na obrazovce) a prazdny vstup REKNE.
#   2. `data/help.json` je ROZHRANI S REALITOU: kazda akce, kterou radek
#      zminuje, MUSI byt v `InputMap` (registruje ji `app/player_controller`) -
#      jinak napoveda radi klavesu, ktera nic nedela.
#   3. OPACNY SMER (anti-drift): kazda vazba, kterou `app/player_controller`
#      zaklada, MUSI byt v napovede uvedena. Kdo prida klavesu do kodu a ne do
#      napovedy, tomu test spadne - a to je presne cil: hrac se ma kazdou
#      klavesu dozvedet z napovedy, ne z release notes.
#
# Cesty jsou VSTUPY (`-- --hotkeys-script=...`, `-- --help-data=...`), aby se
# daly merit nad mutantem (mutacni harness).
#
# ⚠⚠ PROC SE SOUBOR JMENUJE `ui_hotkeys.gd` A NE `hotkeys.gd` (namEReno):
# case soubory jdou ABECEDNE a tenhle test VOLA `register_actions()`. Kdyby
# bezel pred `player_controller.gd`, naplnil by `InputMap` za nej - a jeho
# kontrola `added >= 9` by dostala 0 ("register_actions pridal vazby" FAIL,
# namEReno prvnim pokusem). Presne tuhle past uz znal `tests/cases/interact.gd`
# (komentar u `InputMap.add_action("interact")`). `ui_` radi soubor ZA
# `player_controller.gd`; `trade_path.gd` je na tom stejne (t > p).

const Lib = preload("res://tests/lib.gd")

const HOTKEYS_SCRIPT := "res://ui/hotkeys.gd"
const HELP_DATA := "res://data/help.json"
const CONTROLLER_SCRIPT := "res://app/player_controller.gd"

# Mapy vazeb v `app/player_controller`: vsechny musi byt v napovede.
const VAZBY_KONSTANTY := ["KEYS", "MOUSE", "TOGGLE_KEYS", "TURN_KEYS",
	"CANCEL_KEYS", "INTERACT_KEYS", "ATTACK_KEYS", "UI_KEYS"]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _radky() -> Array:
	return [
		{"sekce": "Pohyb", "klavesy": "sipky", "popis": "krok"},
		{"sekce": "Pohyb", "klavesy": "Shift", "popis": "beh"},
		{"sekce": "Okna", "klavesy": "", "popis": "okno bez klavesy"},
	]


func run(t) -> void:
	var script = Lib.script_at(_arg("hotkeys-script", HOTKEYS_SCRIPT))
	if script == null:
		t._pending("ui.hotkeys NENI HOTOV: " + HOTKEYS_SCRIPT + " chybi")
		return
	var okno = script.new()
	# 1) NOVE OKNO JE ZAVRENE (rozhodnuti o otevreni patri volajícímu).
	t._check(not okno.je_otevreny(),
		"ui.hotkeys: nove okno je zavrene (namEReno %s)" % str(okno.je_otevreny()))
	# Zavrene -> prvni `toggle()` OTEVRE (vraci true), druhe zavre (false).
	var otevreno: bool = okno.toggle()
	var zavreno: bool = okno.toggle()
	t._check(otevreno and not zavreno and not okno.je_otevreny(),
		"ui.hotkeys: `toggle()` prepina stav (1. %s, 2. %s, ted %s)"
			% [str(otevreno), str(zavreno), str(okno.je_otevreny())])
	t._check(okno.otevri() and okno.je_otevreny(),
		"ui.hotkeys: `otevri()` okno ukaze (namEReno %s)" % str(okno.je_otevreny()))

	# 2) RADKY VSTUPEM -> UZLY. Text se cte z UZLU, ne z `_radky`.
	var pocet: int = okno.nastav("TITULEK", _radky())
	t._check(pocet == 3 and okno.count() == 3,
		"ui.hotkeys: `nastav` prijme 3 radky (namEReno %d / %d)" % [pocet, okno.count()])
	t._check(okno.titulek() == "TITULEK",
		"ui.hotkeys: titulek se bere z dat (namEReno '%s')" % okno.titulek())
	var prebaveno: bool = okno.flush()
	var texty: Array = okno.row_texts()
	t._check(prebaveno and texty.size() == 3,
		"ui.hotkeys: `flush()` postavi 3 radky do UZLU (namEReno %d)" % texty.size())
	var ocekavane: Array = []
	for radek in _radky():
		ocekavane.append(okno.text_radku(radek))
	t._check(str(texty) == str(ocekavane),
		"ui.hotkeys: text z UZLU == `text_radku` (uzly %s, ocekavano %s)"
			% [str(texty), str(ocekavane)])
	# Chybejici klavesa se PISE jako "-" (prazdno by vypadalo jako hotova rada).
	var bez: Dictionary = {"sekce": "Okna", "klavesy": "", "popis": "bez klavesy"}
	t._check(okno.text_radku(bez).begins_with("-"),
		"ui.hotkeys: radek bez klavesy ma '-' (namEReno '%s')" % okno.text_radku(bez))
	# Sekce se kresli jako UZEL a jen kdyz se zmeni (2 sekce -> 2 hlavicky).
	# ⚠ META, NE JMENO: Godot prejmenovava duplicitni jmena uzlu, takze druha
	# hlavicka se nejmenuje "Sekce" (namEReno: filtr podle jmena nasel 1).
	var hlavicky: int = 0
	var box = okno.get_node_or_null("Panel/Napoveda")
	if box != null:
		for uzel in box.get_children():
			if uzel is Label and bool(uzel.get_meta("sekce", false)):
				hlavicky += 1
	t._check(hlavicky == 2,
		"ui.hotkeys: dve sekce = dve hlavicky v uzlech (namEReno %d)" % hlavicky)
	var kopie: Array = okno.radky()
	kopie.clear()
	t._check(kopie.is_empty() and okno.count() == 3,
		"ui.hotkeys: `radky()` vraci KOPII (prazdna kopie, v okne %d)" % okno.count())

	# 3) PRAZDNO A VADNY VSTUP SE REKNOU (nula neni uspech).
	okno.nastav("T", [], "NIC TU NENI")
	okno.flush()
	var prazdno_uzel: bool = false
	if box != null:
		for uzel in box.get_children():
			if uzel is Label and str(uzel.name).begins_with("Prazdno"):
				prazdno_uzel = str(uzel.text) == "NIC TU NENI"
	t._check(prazdno_uzel and okno.count() == 0,
		"ui.hotkeys: prazdny vstup se VYKRESLI jako uzel 'NIC TU NENI' (uzel %s)"
			% str(prazdno_uzel))
	okno.nastav("T", [1, "x", {"sekce": "S", "klavesy": "Q", "popis": "ok"}])
	okno.flush()
	t._check(okno.count() == 1 and okno.skipped() == 2,
		"ui.hotkeys: vadne radky se POCITAJI (prijato %d, preskoceno %d)"
			% [okno.count(), okno.skipped()])
	okno.free()

	# 4) DATA: kazda akce z `data/help.json` MUSI byt v `InputMap`.
	var data = Lib.json_at(_arg("help-data", HELP_DATA))
	if not (data is Dictionary):
		t._pending("data/help.json se necte jako slovnik (napoveda by byla prazdna)")
		return
	var radky: Array = data.get("radky", [])
	t._check(radky.size() >= 10,
		"data/help.json: radku napovedy je aspon 10 (namEReno %d)" % radky.size())
	var uvod: Array = data.get("uvod", [])
	t._check(uvod.size() >= 3,
		"data/help.json: uvodnich zprav je aspon 3 (namEReno %d)" % uvod.size())
	t._check(not (data.get("nazvy_klaves", {}) as Dictionary).is_empty(),
		"data/help.json: `nazvy_klaves` je neprazdne (jinak by se klavesy psaly kodem)")
	var skupiny: Dictionary = {}
	for s in data.get("skupiny", []):
		if s is Dictionary:
			skupiny[str(s.get("id", ""))] = str(s.get("nazev", ""))

	# Vsechny vazby zaklada `app/player_controller` - proto se registruji tady.
	var controller = Lib.script_at(_arg("controller-script", CONTROLLER_SCRIPT))
	if controller == null:
		t._pending("app/player_controller NENI K DISPOZICI: " + CONTROLLER_SCRIPT)
		return
	controller.register_actions()

	var chybejici: Array = []
	var uvedene: Dictionary = {}
	var bez_klaves: Array = []
	for radek in radky:
		if not (radek is Dictionary):
			continue
		var skupina: String = str(radek.get("skupina", ""))
		if not skupiny.has(skupina):
			chybejici.append("radek '" + str(radek.get("id", "?"))
				+ "' ma neznamou skupinu '" + skupina + "'")
		var akce: Array = radek.get("akce", [])
		if akce.is_empty():
			chybejici.append("radek '" + str(radek.get("id", "?")) + "' nema akci")
			continue
		for a in akce:
			var jmeno: String = str(a)
			uvedene[jmeno] = true
			if not InputMap.has_action(jmeno):
				chybejici.append("akce '" + jmeno + "' neni v InputMap")
			elif InputMap.action_get_events(jmeno).is_empty():
				bez_klaves.append(jmeno)
	t._check(chybejici.is_empty(),
		"data/help.json: kazda akce radku je v InputMap a skupina v datech (vady: %s)"
			% str(chybejici))
	t._check(bez_klaves.is_empty(),
		"data/help.json: kazda uvedena akce ma v InputMap klavesu (bez: %s)"
			% str(bez_klaves))

	# 5) ANTI-DRIFT: kazda vazba z kodu je v napovede uvedena.
	var konstanty: Dictionary = Lib.consts_at(_arg("controller-script", CONTROLLER_SCRIPT))
	var neuvedene: Array = []
	var v_kodu: int = 0
	for nazev in VAZBY_KONSTANTY:
		var mapa = konstanty.get(nazev, {})
		if not (mapa is Dictionary):
			continue
		for akce in (mapa as Dictionary).keys():
			v_kodu += 1
			if not uvedene.has(str(akce)):
				neuvedene.append(str(akce))
	t._check(v_kodu >= 25,
		"player_controller: vazeb v konstante je aspon 25 (namEReno %d)" % v_kodu)
	t._check(neuvedene.is_empty(),
		"data/help.json: KAZDA vazba z kodu je v napovede (chybi: %s)" % str(neuvedene))

	# 6) ZNACKY {akce} V UVODU: kazda musi byt akce, ktera v InputMap existuje
	#    (jinak by hrac dostal vetu s klavesou, ktera nic nedela).
	var chybne_znacky: Array = []
	for radek in uvod:
		if not (radek is Dictionary):
			continue
		var text: String = str((radek as Dictionary).get("text", ""))
		var zbytek: String = text
		while zbytek.find("{") >= 0 and zbytek.find("}") > zbytek.find("{"):
			var od: int = zbytek.find("{")
			var do_: int = zbytek.find("}", od + 1)
			var znacka: String = zbytek.substr(od + 1, do_ - od - 1)
			if not InputMap.has_action(znacka):
				chybne_znacky.append(znacka)
			zbytek = zbytek.substr(do_ + 1)
	t._check(chybne_znacky.is_empty(),
		"data/help.json: znacky {akce} v urodu jsou platne akce (vadne: %s)"
			% str(chybne_znacky))
	# Napoveda musi umet rict, cim se otvira (jinak ji hrac nenajde).
	var ma_otvirani: bool = false
	for radek in radky:
		if radek is Dictionary and ("hotkeys_toggle" in (radek.get("akce", []) as Array)):
			ma_otvirani = true
	t._check(ma_otvirani,
		"data/help.json: napoveda uvadi klavesu, kterou se otvira (hotkeys_toggle)")
