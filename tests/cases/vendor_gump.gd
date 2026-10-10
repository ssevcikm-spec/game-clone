extends RefCounted
# ui.vendor_gump - obchodni gump (smlouva docs/04 §4.4 `gump_open`, §4.6.5 tok
# "dvojklik na vendora -> gump; potvrzeni -> Command{t:'vendor', ...}").
#
# Meri se, ze okno:
#   * se otevre UDALOSTI (`gump_open` s `gump:"vendor"`), ne kliknutim na sebe,
#   * cizi udalost i jiny gump ignoruje (`message`, `gump_open{gump:"craft"}`),
#   * oba seznamy dostane VSTUPEM (ceny i pocty pocita SIM - UI nepocita),
#   * mnozstvi se oreze na to, co je k dispozici (vic nez je, nejde vybrat),
#   * potvrzeni prelozi vyber na POZADAVEK `{t:"vendor", action, vendor, lines}`
#     a nikam ho neposila (`app/` si ho vyzvedne - UI nezna `sim`),
#   * prazdny vyber nic neposle (zadny prazdny prikaz),
#   * `flush()` prebavi jen pri zmene, prazdny seznam neni ticho a stare uzly
#     se UVOLNI (`free()`, ne `queue_free()`).
#
# Cesta k souboru je VSTUP (`-- --vendor-gump-script=<cesta>`) - mutacni harness.
# Vsechny uzly se na konci uvolnuji (`free()`), aby v sade nezustaly leaky.

const Lib = preload("res://tests/lib.gd")
const GUMP := "res://ui/vendor_gump.gd"

const INGOT := 0x5BEF
const PICKAXE := 0x4E85
const DAGGER := 0x4F51
const VENDOR := 7


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _nove(t):
	var cesta: String = _arg("vendor-gump-script", GUMP)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("ui.vendor_gump NENI HOTOVY: " + cesta + " chybi (nebo parse error)")
		return null
	return script.new()


func _buy() -> Array:
	return [
		{"item": INGOT, "type": "iron_ingot", "name": "iron ingot", "amount": 16, "price": 8},
		{"item": PICKAXE, "type": "pickaxe", "name": "pickaxe", "amount": 20, "price": 21},
	]


func _sell() -> Array:
	return [
		{"item": DAGGER, "type": "dagger", "name": "dagger", "amount": 3, "price": 10},
		{"item": 0, "type": "bez_item", "name": "rozbitny radek", "amount": 1, "price": 5},
	]


func _otevri(okno, buy, sell) -> bool:
	return okno.apply_event({"name": "gump_open", "data": {
		"gump": "vendor", "data": {"vendor": VENDOR, "id": "blacksmith",
			"buy": buy, "sell": sell}}})


func run(t) -> void:
	var okno = _nove(t)
	if okno == null:
		return

	# -- A) nove okno je zavrene a prazdne --------------------------------
	t._check(not okno.je_otevreny() and okno.pocet_buy() == 0 and okno.pocet_sell() == 0,
		"ui.vendor_gump: nove okno je zavrene a prazdne (otevrene %s, buy %d, sell %d)"
			% [str(okno.je_otevreny()), okno.pocet_buy(), okno.pocet_sell()])

	# -- B) otevreni UDALOSTI, cizi udalosti ignoruje ---------------------
	var cizi: bool = okno.apply_event({"name": "message", "data": {"text": "hi"}})
	var jiny: bool = okno.apply_event({"name": "gump_open", "data": {
		"gump": "craft", "data": {"recipes": []}}})
	var otevreno: bool = _otevri(okno, _buy(), _sell())
	t._check(otevreno and okno.je_otevreny() and not cizi and not jiny,
		"ui.vendor_gump: okno otevre POUZE `gump_open{gump:'vendor'}` (otevreno %s, message %s, craft %s)"
			% [str(otevreno), str(cizi), str(jiny)])
	t._check(okno.pocet_buy() == 2 and okno.pocet_sell() == 1,
		"ui.vendor_gump: seznamy jdou vstupem a radek bez `item` se zahodi (buy %d, sell %d)"
			% [okno.pocet_buy(), okno.pocet_sell()])

	# -- C) text radku a soucet za vyber ---------------------------------
	var radek: Dictionary = okno.radky("buy")[0]
	t._check(okno.text_radku(radek, "buy") == "iron ingot x16  8 gp",
		"ui.vendor_gump: radek je 'jmeno x<kolik> <cena> gp' (namEReno '%s')"
			% okno.text_radku(radek, "buy"))
	t._check(okno.text_vyberu("buy") == "(nothing selected)",
		"ui.vendor_gump: bez vyberu je v potvrzeni '(nothing selected)' (namEReno '%s')"
			% okno.text_vyberu("buy"))
	t._check(okno.nastav_mnozstvi("buy", INGOT, 2) and okno.mnozstvi("buy", INGOT) == 2,
		"ui.vendor_gump: mnozstvi jde nastavit (namEReno %d)" % okno.mnozstvi("buy", INGOT))
	t._check(okno.celkem("buy") == 16 and okno.text_vyberu("buy") == "2 items, 16 gp",
		"ui.vendor_gump: 2 x 8 gp = 16 gp (namEReno %d, '%s')"
			% [okno.celkem("buy"), okno.text_vyberu("buy")])
	t._check(okno.text_radku(radek, "buy") == "iron ingot x16  8 gp -> 2",
		"ui.vendor_gump: vybrany radek ukazuje mnozstvi (namEReno '%s')"
			% okno.text_radku(radek, "buy"))
	okno.nastav_mnozstvi("buy", INGOT, 99)
	t._check(okno.mnozstvi("buy", INGOT) == 16 and okno.celkem("buy") == 128,
		"ui.vendor_gump: vic nez je k dispozici nejde vybrat (namEReno %d ks, %d gp)"
			% [okno.mnozstvi("buy", INGOT), okno.celkem("buy")])
	okno.nastav_mnozstvi("buy", INGOT, -5)
	t._check(okno.mnozstvi("buy", INGOT) == 0 and okno.celkem("buy") == 0,
		"ui.vendor_gump: zaporne mnozstvi vyber zrusi (namEReno %d ks)" % okno.mnozstvi("buy", INGOT))
	t._check(not okno.nastav_mnozstvi("buy", 12345, 1),
		"ui.vendor_gump: neznamy radek nejde vybrat")
	okno.nastav_mnozstvi("buy", INGOT, 16)
	okno.stiskni_radek("buy", INGOT)
	t._check(okno.mnozstvi("buy", INGOT) == 0,
		"ui.vendor_gump: kliknuti na maximu mnozstvi vynuluje (namEReno %d)"
			% okno.mnozstvi("buy", INGOT))

	# -- D) potvrzeni -> POZADAVEK (a prazdny vyber nic neposle) ----------
	t._check(not okno.stiskni_potvrzeni() and okno.odeber_pozadavek().is_empty(),
		"ui.vendor_gump: prazdny vyber neposle zadny prikaz")
	okno.nastav_mnozstvi("buy", INGOT, 2)
	var potvrzeno: bool = okno.stiskni_potvrzeni()
	var pozadavek: Dictionary = okno.odeber_pozadavek()
	t._check(potvrzeno and str(pozadavek.get("t", "")) == "vendor"
			and str(pozadavek.get("action", "")) == "buy"
			and int(pozadavek.get("vendor", -1)) == VENDOR
			and (pozadavek.get("lines", []) as Array).size() == 1
			and int((pozadavek.get("lines", []) as Array)[0].get("amount", 0)) == 2
			and int((pozadavek.get("lines", []) as Array)[0].get("item", 0)) == INGOT,
		"ui.vendor_gump: potvrzeni da `{t:'vendor', action:'buy', vendor:%d, lines:[{item, amount}]}` (namEReno %s)"
			% [VENDOR, str(pozadavek)])
	t._check(okno.odeber_pozadavek().is_empty(),
		"ui.vendor_gump: pozadavek se vyzvedne JEDNOU (druhe volani je prazdne)")

	# -- D2) novy seznam vynuluje stary vyber -----------------------------
	okno.nastav_mnozstvi("buy", INGOT, 2)
	_otevri(okno, _buy(), _sell())
	t._check(okno.vybranych("buy") == 0 and okno.celkem("buy") == 0,
		"ui.vendor_gump: novy seznam vyber vynuluje (namEReno %d radku, %d gp)"
			% [okno.vybranych("buy"), okno.celkem("buy")])

	# -- E) smer prodeje: jiny seznam, jiny `action` ----------------------
	t._check(okno.nastav_smer("sell") and okno.smer() == "sell",
		"ui.vendor_gump: smer jde prepnout na prodej (namEReno '%s')" % okno.smer())
	t._check(not okno.nastav_smer("nonsense") and okno.smer() == "sell",
		"ui.vendor_gump: neznamy smer se neprijme (namEReno '%s')" % okno.smer())
	for _i in 3:
		okno.stiskni_radek("sell", DAGGER)
	t._check(okno.mnozstvi("sell", DAGGER) == 3 and okno.celkem("sell") == 30,
		"ui.vendor_gump: prodej 3 dyk po 10 gp = 30 gp (namEReno %d ks, %d gp)"
			% [okno.mnozstvi("sell", DAGGER), okno.celkem("sell")])
	t._check(okno.stiskni_potvrzeni(),
		"ui.vendor_gump: potvrzeni prodeje se posle")
	var prodej: Dictionary = okno.odeber_pozadavek()
	t._check(str(prodej.get("action", "")) == "sell"
			and int((prodej.get("lines", []) as Array)[0].get("item", 0)) == DAGGER
			and int((prodej.get("lines", []) as Array)[0].get("amount", 0)) == 3,
		"ui.vendor_gump: prodej posle `action:'sell'` a mnozstvi 3 (namEReno %s)" % str(prodej))

	# -- F) flush(): prebavi jen pri zmene, uvolnuje stare uzly -----------
	var druhe = _nove(t)
	if druhe == null:
		okno.free()
		return
	_otevri(druhe, _buy(), _sell())
	druhe.flush()
	var box = druhe.get_node_or_null("Obchod")
	t._check(box != null and druhe.prebaveni() == 1,
		"ui.vendor_gump: `flush()` postavi uzly (box %s, prebaveni %d)"
			% [str(box != null), druhe.prebaveni()])
	var stary = box.get_child(0)
	t._check(not druhe.flush() and druhe.prebaveni() == 1,
		"ui.vendor_gump: druhy `flush()` bez zmeny nic neprebavi (prebaveni %d)"
			% druhe.prebaveni())
	druhe.nastav(VENDOR, "blacksmith", [_buy()[0]], [])
	druhe.flush()
	t._check(not is_instance_valid(stary),
		"ui.vendor_gump: stare uzly se pri prebaveni UVOLNI (`free()`)")
	t._check(box.get_child_count() == 3,
		"ui.vendor_gump: 1 radek = 1 popis + 1 radek + potvrzeni (uzlu %d)"
			% box.get_child_count())
	t._check(druhe.nastav_smer("sell") and druhe.flush(),
		"ui.vendor_gump: prazdny seznam se prebavi")
	var prazdny_text: String = ""
	for child in box.get_children():
		if child is Label and str(child.text).begins_with("(nothing"):
			prazdny_text = str(child.text)
	t._check(prazdny_text == "(nothing to sell)",
		"ui.vendor_gump: prazdny seznam rekne '(nothing to sell)' (namEReno '%s')" % prazdny_text)

	# -- G) uvolneni: po `free()` nesmi zustat zadny uzel -----------------
	var potomek = box.get_child(0)
	okno.free()
	druhe.free()
	t._check(not is_instance_valid(okno) and not is_instance_valid(druhe)
			and not is_instance_valid(box) and not is_instance_valid(potomek),
		"ui.vendor_gump: `free()` uvolni okno i vsechny uzly (okno %s, box %s, radek %s)"
			% [str(is_instance_valid(okno)), str(is_instance_valid(box)),
				str(is_instance_valid(potomek))])
