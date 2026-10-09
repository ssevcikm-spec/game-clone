extends RefCounted
# ui.policy_panel - okno PRAVIDEL POLITIKY (D3 jako HUD, 2026-10-09). Test meri
# CHOVANI, ne pritomnost souboru:
#   * co je videt u kazdeho pravidla (priorita + id + DUVOD, ne vysledek),
#   * ze se poradi NEpreusporadava v UI (to je vec `sim.policy`),
#   * ze `radky()` je KOPIE (okno si nesmi nechat sahat do sveho stavu),
#   * ze prazdno a nezname chybejici hodnoty jsou VIDET ("-" / "(zadna
#     pravidla)" / "(stav nevykonavatele neni znamy)"), ne tiche prazdno,
#   * ze se prebavuje JEN pri zmene (`flush()`).
#
# Cesta k souboru je VSTUP: `-- --policy-panel-script=<cesta>` - mutacni
# harness (tools/gates/mutace-tests.py) tim dokazuje, ze test meri opravdu
# ten soubor (mutant se predava jako cesta).

const Lib = preload("res://tests/lib.gd")
const PANEL := "res://ui/policy_panel.gd"

const ZNAMY: Array = [
	# ⚠ PORADI JE ZAMERNE "NAHODNE" (priorita 10 pred 50): kdyby si UI pravidla
	# tridilo samo, test poradi to odhali. Kdyby vstup byl uz setrideny, prosla
	# by i vada "UI tridi podle priority" - a to je prave to, co UI delat NESMI
	# (tridi `sim.policy`; namEReno pri psani mutaci pro tento case).
	{"id": "buy_pickaxe", "priority": 10, "reason": "stav nezna: inventory"},
	{"id": "go_mine", "priority": 50, "reason": "skill 45: 100 < 200"},
]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("policy-panel-script", PANEL)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("ui.policy_panel NENI K DISPOZICI: " + cesta)
		return
	var panel = script.new()

	# API musi byt CELE: chybejici metoda by case shodila s 0 kontrolami
	# a mutace by prosla jako slepa (docs/09 §9.5).
	var chybi: Array[String] = []
	for metoda in ["nastav_pravidla", "radky", "stav", "telo_text", "hlavicka_text",
			"stav_text", "text_radku", "pocet", "je_otevreny", "toggle",
			"prebaveni", "flush"]:
		if not panel.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "ui.policy_panel: chybi metody %s - case se neda merit" % str(chybi))
		panel.free()
		return

	# 0) nove okno je ZAVRENE a prazdne (jinak by pri startu prekrylo svet)
	t._check(panel.pocet() == 0 and not panel.je_otevreny(),
		"ui.policy_panel: nove okno je zavrene a bez pravidel (pocet %d, otevrene %s)"
			% [panel.pocet(), str(panel.je_otevreny())])

	# 1) PRAZDNY SEZNAM neni ticho - okno to rekne a rovnou ukaze stav
	panel.nastav_pravidla([], {})
	panel.flush()
	var prazdny_text: String = ""
	var box = panel.get_node_or_null("PravidlaObsah")
	if box != null and box.get_child_count() > 0 and box.get_child(0) is Label:
		prazdny_text = str(box.get_child(0).text)
	t._check(prazdny_text == "(zadna pravidla)",
		"ui.policy_panel: prazdny seznam rekne '(zadna pravidla)' (namEReno '%s')"
			% prazdny_text)
	t._check(panel.telo_text() == "",
		"ui.policy_panel: prazdny seznam ma prazdne telo (namEReno '%s')"
			% panel.telo_text())

	# 2) PRAVIDLO: priorita, id a DUVOD (duvod, ne vysledek)
	t._check(panel.text_radku({"id": "go_mine", "priority": 50,
			"reason": "skill 45: 100 < 200"})
			== "#50 go_mine - skill 45: 100 < 200",
		"ui.policy_panel: radek je '#priorita id - duvod' (namEReno '%s')"
			% panel.text_radku({"id": "go_mine", "priority": 50,
				"reason": "skill 45: 100 < 200"}))
	t._check(panel.text_radku({"id": "buy_pickaxe", "priority": 10}) == "#10 buy_pickaxe - -",
		"ui.policy_panel: pravidlo bez duvodu ma '-' (ne prazdno) (namEReno '%s')"
			% panel.text_radku({"id": "buy_pickaxe", "priority": 10}))

	# 3) KRIVY RADEK neni pad a nic se nevymysli (id zustane prazdne, priorita 0)
	t._check(panel.text_radku({}) == "#0  - -",
		"ui.policy_panel: prazdny radek da '#0  - -' (namEReno '%s')" % panel.text_radku({}))

	# 4) PORADI se v UI NEMENI (tridit podle priority je vec `sim.policy`;
	#    kdyby si to UI preusporadalo, vymyslelo by si pravidlo - D3)
	panel.nastav_pravidla(ZNAMY, {})
	var radky: Array = panel.radky()
	t._check(panel.pocet() == 2 and str(radky[0]["id"]) == "buy_pickaxe"
			and str(radky[1]["id"]) == "go_mine",
		"ui.policy_panel: poradi zustava vstupni (namEReno '%s')"
			% str([str(radky[0]["id"]), str(radky[1]["id"])]))

	# 5) `radky()` a `stav()` vraci KOPII (okno si nesmi nechat menit stav)
	radky[0]["id"] = "ZMENENO"
	var stav_kopie: Dictionary = panel.stav()
	stav_kopie["stopped"] = true
	t._check(str(panel.radky()[0]["id"]) == "buy_pickaxe" and panel.stav().is_empty(),
		"ui.policy_panel: radky() i stav() vraci kopii (id '%s', stav %s)"
			% [str(panel.radky()[0]["id"]), str(panel.stav())])

	# 6) flush() prebavi JEN pri zmene. Baseline se ZJISTI (ne hada): do teto
	#    chvile se prebavovalo pri kazde zmene vstupu, takze cislo zavisi na
	#    poctu volani vys - a test, ktery si baseline vymysli, meri neco jineho.
	#    Nez se idempotence meri, dorovnaji se cekajici zmeny (jinak by "druhy
	#    flush nic neprebavi" spadlo na zmene z bodu 4, ktera se jeste
	#    neprebavila - namEReno pri psani tohoto testu).
	panel.flush()
	var pred: int = panel.prebaveni()
	var prebaveno: bool = panel.flush()
	t._check(not prebaveno and panel.prebaveni() == pred,
		"ui.policy_panel: flush() bez zmeny nic neprebavi (prebaveni %d -> %d)"
			% [pred, panel.prebaveni()])
	panel.nastav_pravidla(ZNAMY, {})
	t._check(panel.flush() and panel.prebaveni() == pred + 1,
		"ui.policy_panel: nova data prebavi okno (prebaveni %d -> %d)"
			% [pred, panel.prebaveni()])

	# 7) HLAVICKA: pocet pravidel + stav vykonavatele (bez stavu se nic nevymysli)
	t._check(panel.stav_text() == "(stav nevykonavatele neni znamy)",
		"ui.policy_panel: bez stavu se rekne 'neni znamy' (namEReno '%s')"
			% panel.stav_text())
	t._check(panel.hlavicka_text().begins_with("PRAVIDLA (2)"),
		"ui.policy_panel: hlavicka rekne pocet pravidel (namEReno '%s')"
			% panel.hlavicka_text())
	panel.nastav_pravidla(ZNAMY, {"stopped": false, "reason": "no rule matched",
		"rule": "executor", "commands_sent": 3})
	t._check(panel.stav_text() == "ceka: no rule matched | pravidlo: executor | prikazu: 3",
		"ui.policy_panel: stav vykonavatele se vypise (namEReno '%s')" % panel.stav_text())
	panel.nastav_pravidla(ZNAMY, {"stopped": true, "reason": "invalid command (range:action)",
		"rule": "kup_krumpac", "commands_sent": 7})
	t._check(panel.stav_text().begins_with("zastaveno: invalid command (range:action)"),
		"ui.policy_panel: zastaveny vykonavatel je videt i s duvodem (namEReno '%s')"
			% panel.stav_text())

	# 8) PREPINANI okna (klavesa `P` v `app/player_controller`)
	var stav: bool = panel.toggle()
	t._check(stav and panel.je_otevreny() and not panel.toggle() and not panel.je_otevreny(),
		"ui.policy_panel: toggle() prepne otevreno/zavreno")

	# 9) UZLY: radky se dostanou do okna (Label funguje i bez sceny) a po
	#    prebaveni tam nejsou STARE radky (uvolnuje se `free()`, ne `queue_free()`)
	panel.nastav_pravidla([{"id": "jen_jedno", "priority": 1, "reason": "flag u_kovare: true"}], {})
	panel.flush()
	var box2 = panel.get_node_or_null("PravidlaObsah")
	var popis: String = ""
	if box2 != null and box2.get_child_count() == 1 and box2.get_child(0) is Label:
		popis = str(box2.get_child(0).text)
	t._check(popis == "#1 jen_jedno - flag u_kovare: true",
		"ui.policy_panel: radek se dostane do Labelu (uzlu %d, text '%s')"
			% [box2.get_child_count() if box2 != null else -1, popis])

	# 10) HLAVICKA MUSI BYT UZEL (namEReno 2026-10-09 snimkem): prvni verze
	#     drzela stav jen v promenne `_hlavicka`, takze `hlavicka_text()` vracel
	#     spravny retezec a testy byly zelene - a na obrazovce nebylo NIC.
	#     Kontroluje se, ze text je v Labelu a ze ho `_vycisti` nemaze.
	var hlava = panel.get_node_or_null("PravidlaHlavicka")
	t._check(hlava is Label and str((hlava as Label).text).begins_with("PRAVIDLA (1)"),
		"ui.policy_panel: hlavicka je Label s textem (uzel %s)"
			% ("null" if not (hlava is Label) else "'" + str((hlava as Label).text) + "'"))
	panel.nastav_pravidla([], {})
	panel.flush()
	t._check(hlava != null and is_instance_valid(hlava) and str((hlava as Label).text).begins_with("PRAVIDLA (0)"),
		"ui.policy_panel: hlavicka prezije prebaveni a rekne pocet 0 (text '%s')"
			% ("-" if hlava == null or not is_instance_valid(hlava) else str((hlava as Label).text)))

	# 11) VSECHNA PRAVIDLA SE OPRAVDU VYKRESLI - a ROVNOU z uzlu, ne z `telo_text()`.
	#     ⚠ NamEReno 2026-10-09 pri mutaci "do okna se dostane jen prvni pravidlo":
	#     kontrola vyse (`popis` proti `telo_text()`) mutaci NEODHALILA, protoze
	#     obe strany pocitaly z tehoz smyčky - kdyz se smyčka zkrati, zkrati se
	#     i `telo_text()` a obe strany si "sednou". Slepou branou se to opravuje
	#     tak, ze se cte to, co je v UZLECH (nezavisly zdroj).
	panel.nastav_pravidla(ZNAMY, {})
	panel.flush()
	var vykreslene: Array = []
	var box3 = panel.get_node_or_null("PravidlaObsah")
	if box3 != null:
		for dite in box3.get_children():
			if dite is Label:
				vykreslene.append(str((dite as Label).text))
	t._check(vykreslene.size() == 2 and str(vykreslene[0]) == "#10 buy_pickaxe - stav nezna: inventory"
			and str(vykreslene[1]) == "#50 go_mine - skill 45: 100 < 200",
		"ui.policy_panel: v okne jsou OBA radky v poradi vstupu (uzlu %d: %s)"
			% [vykreslene.size(), str(vykreslene)])

	# 12) GEOMETRIE: obsah nesmi zacinat POD hlavickou (namEReno verifikaci
	#     2026-10-09). Konstanta `HLAVICKA_VYSKA = 20` je jen dolni odhad, ale
	#     text ma 23 px - obsah pak zacinal o 3 px vys a prvni radek se
	#     s hlavickou prekryl. Mutace "posun obsahu na (0,0)" prochazela vsemi
	#     1671 kontrolami (slepa kontrola), dokud se nemeril PREKRYV rectu.
	#     Meri se `get_combined_minimum_size()` (to zna Godot i bez okna).
	var hlava_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
	if hlava is Label:
		hlava_rect = Rect2((hlava as Label).position, (hlava as Label).get_combined_minimum_size())
	var obsah_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
	if box3 is Control:
		obsah_rect = Rect2((box3 as Control).position, (box3 as Control).get_combined_minimum_size())
	t._check(obsah_rect.position.y >= hlava_rect.end.y and not obsah_rect.intersects(hlava_rect),
		"ui.policy_panel: obsah zacina pod hlavickou (hlavicka do y=%.1f, obsah od y=%.1f)"
			% [hlava_rect.end.y, obsah_rect.position.y])

	# 13) PRVNI VYKRESLENI I PRO PRAZDNY VSTUP (namEReno verifikaci 2026-10-09):
	#     bez `user://policy.json` je vstup `[]` + `{}`, coz je PRESNE pocatecni
	#     stav okna - takze se `flush()` nezavolal ani jednou a okno zustalo
	#     prazdne (hráč zmackl `P` a videl prazdno bez vysvetleni). Kontroluje
	#     se, že se prazdny stav VYKRESLI (uzel "(zadna pravidla)" + hlavicka).
	var cerstve = script.new()
	cerstve.nastav_pravidla([], {})
	cerstve.flush()
	var texty_prazdne: Array = []
	var box4 = cerstve.get_node_or_null("PravidlaObsah")
	if box4 != null:
		for dite in box4.get_children():
			if dite is Label:
				texty_prazdne.append(str((dite as Label).text))
	var hlava4 = cerstve.get_node_or_null("PravidlaHlavicka")
	t._check(texty_prazdne.has("(zadna pravidla)") and not texty_prazdne.is_empty()
			and hlava4 is Label and str((hlava4 as Label).text).begins_with("PRAVIDLA (0)"),
		"ui.policy_panel: prazdny vstup se VYKRESLI (texty %s, hlavicka '%s')"
			% [str(texty_prazdne),
				"-" if not (hlava4 is Label) else str((hlava4 as Label).text)])
	# 13b) PRAZDNY STAV REKNE I CESTU (namEReno verifikaci 2026-10-09): prvni
	#      verze pripominku `user://policy.json` jen SLIBOVALA v komentari a
	#      vykreslovala jen "(zadna pravidla)" - hrac se tedy nedozvedel, kam
	#      pravidla psat, a to je presne to, kvuli cemuz bylo D3 prijato
	#      "jen jako HUD" (pravidla se zadavaji rucne).
	t._check(texty_prazdne.has("pravidla se pisou do user://policy.json"),
		"ui.policy_panel: prazdny stav rekne, KAM se pravidla pisou (texty %s)"
			% str(texty_prazdne))
	cerstve.free()

	panel.free()   # Control + dite VBoxContainer - Node se uvolnuje rucne
