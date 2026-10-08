extends RefCounted
# ui.backpack - okno batohu (20. session). Meri se, ze je to TENKY KLIENT:
# dostane hotove radky a vykresli je; nic nepocita, nikam neposila.
#
# Co je na tom testu dulezite:
#   * PRAZDNY batoh neni ticho - okno to rekne ("(empty)"). Prazdne okno
#     vypada jako vada (presne ta trida, kterou projekt zakazuje),
#   * `flush()` se prebavi JEN kdyz se obsah zmenil (jinak by se okno stavělo
#     kazdy frame - stejna past jako u `ui.journal`),
#   * ikony jsou INJEKCE (`nastav_textury`): `ui/` nesmi sahat na `render/`
#     (docs/04 §4.1). Kdyz poskytovatel neni, okno kresli jen jmena.

const Lib = preload("res://tests/lib.gd")
const BACKPACK := "res://ui/backpack.gd"


class StubTextury:
	var pozadovane: Array = []
	var tex: Texture2D = null

	func texture(art: int) -> Texture2D:
		pozadovane.append(art)
		return tex


func run(t) -> void:
	var script = Lib.script_at(BACKPACK)
	if script == null:
		t._pending("ui.backpack NENI K DISPOZICI: " + BACKPACK)
		return
	var okno = script.new()
	t._check(okno.pocet() == 0 and not okno.je_otevreny() and not okno.radky().size(),
		"ui.backpack: nove okno je zavrene a prazdne (pocet %d, otevrene %s)"
			% [okno.pocet(), str(okno.je_otevreny())])

	# 1) obsah se bere VSTUPEM a `radky()` vraci kopii
	var vstup: Array = [
		{"art": 100, "name": "iron ore", "amount": 3},
		{"art": 200, "name": "pickaxe", "amount": 1},
	]
	okno.nastav_obsah(vstup)
	t._check(okno.pocet() == 2 and str(okno.radky()[0]["name"]) == "iron ore",
		"ui.backpack: obsah jde vstupem (pocet %d, prvni '%s')"
			% [okno.pocet(), str(okno.radky()[0]["name"])])
	var kopie: Array = okno.radky()
	kopie[0]["name"] = "ZMENENO"
	t._check(str(okno.radky()[0]["name"]) == "iron ore",
		"ui.backpack: `radky()` vraci kopii (zmena kopie nezmění okno)")
	t._check(okno.text_radku({"name": "iron ore", "amount": 3}) == "iron ore x3"
			and okno.text_radku({"name": "pickaxe", "amount": 1}) == "pickaxe",
		"ui.backpack: hromada se pise jako 'xN', jednotlivy predmet bez 'x1'")

	# 2) flush() prebavi jen pri zmene
	okno.flush()
	okno.flush()
	t._check(okno.prebaveni() == 1,
		"ui.backpack: druhy `flush()` bez zmeny nic neprebavi (prebaveni %d)"
			% okno.prebaveni())
	okno.nastav_obsah(vstup)
	okno.flush()
	t._check(okno.prebaveni() == 2,
		"ui.backpack: nova data prebavi okno (prebaveni %d)" % okno.prebaveni())

	# 3) PRAZDNY batoh neni ticho
	okno.nastav_obsah([])
	okno.flush()
	var text_prazdneho: String = ""
	var box = okno.get_node_or_null("BatohObsah")
	if box != null and box.get_child_count() > 0:
		var prvni = box.get_child(0)
		if prvni is Label:
			text_prazdneho = str(prvni.text)
	t._check(text_prazdneho == "(empty)",
		"ui.backpack: prazdny batoh rekne '(empty)' (namEReno '%s')" % text_prazdneho)

	# 4) prepinani viditelnosti
	var stav: bool = okno.toggle()
	t._check(stav and okno.je_otevreny() and not okno.toggle() and not okno.je_otevreny(),
		"ui.backpack: `toggle()` prepne otevreno/zavreno")

	# 5) IKONY: bez poskytovatele se nepta, s nim si vyzada art
	okno.nastav_obsah([{"art": 20101, "name": "pickaxe", "amount": 1}])
	okno.flush()
	var bez: int = okno.get_node("BatohObsah").get_child(0).get_child_count()
	t._check(bez == 1,
		"ui.backpack: bez textur kresli jen popis (uzlu v radku %d)" % bez)
	var obrazek := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var stub := StubTextury.new()
	stub.tex = ImageTexture.create_from_image(obrazek)
	okno.nastav_textury(stub)
	okno.nastav_obsah([{"art": 20101, "name": "pickaxe", "amount": 1}])
	okno.flush()
	var s_ikonou: int = okno.get_node("BatohObsah").get_child(0).get_child_count()
	t._check(s_ikonou == 2 and stub.pozadovane == [20101],
		"ui.backpack: s poskytovatelem si vyzada ikonu podle ARTU (uzlu %d, zadano %s)"
			% [s_ikonou, str(stub.pozadovane)])
