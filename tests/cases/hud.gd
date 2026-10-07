extends RefCounted
# ui.hud - kotvy a okna (granule ui.hud, docs/07 §7.3). Test ZAVOLA API a meri
# chovani, ne "soubor existuje": registrace okna, zapamatovani a PREPSANI
# pozice, ulozeni/obnoveni rozlozeni a to, ze NEZNAME okno se nevyrobi z niceho
# (vraci null/false, ne pad).
#
# Uzly (Control/Node) se po testu UVOLNUJI pres `free()` - Node neni RefCounted,
# bez uvolneni zustane viset a spadne cely beh testovaci sady.
#
# Cesta k souboru je VSTUP: `-- --hud-script=<cesta>` - mutacni harness
# (tools/gates/mutace-tests.py) tim dokazuje, ze test meri opravdu ten soubor.

const Lib = preload("res://tests/lib.gd")
const HUD_SCRIPT := "res://ui/hud.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("hud-script", HUD_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("ui.hud NENI HOTOVA: " + cesta + " chybi nebo se neparsuje")
		return
	var hud = script.new()
	# API musi byt CELE: kdyz mutant metodu odebere nebo prejmenuje, case by na
	# "Invalid call" spadl s 0 kontrolami a mutace by prosla jako slepa. Kontrola
	# se prida JEN kdyz neco chybi, takze zdrave cislo kontrol zustava 16.
	var chybi: Array[String] = []
	for metoda in ["register_window", "window_of", "position_of", "set_position",
			"layout", "restore_layout"]:
		if not hud.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "ui.hud: chybi metody %s - case se neda merit" % str(chybi))
		hud.free()
		return
	var okno := Control.new()
	okno.position = Vector2(1, 1)

	# 1) registrace okna: pozice se ZAPAMATUJE a prenese na uzel
	t._check(hud.register_window("chat", okno, Vector2(10, 20)) == true,
		"ui.hud: register_window vraci true pro nove okno")
	t._check(hud.window_of("chat") == okno,
		"ui.hud: window_of vraci ZAREGISTROVANY uzel (ne kopii)")
	t._check(hud.position_of("chat") == Vector2(10, 20) and okno.position == Vector2(10, 20),
		"ui.hud: pozice se zapamatuje a prenese na uzel (evidence %s, uzel %s)"
			% [str(hud.position_of("chat")), str(okno.position)])

	# 2) PREPSANI pozice (druha hodnota musi vyhrat)
	t._check(hud.set_position("chat", Vector2(30, 40)) == true,
		"ui.hud: set_position na znamem okne vraci true")
	t._check(hud.position_of("chat") == Vector2(30, 40) and okno.position == Vector2(30, 40),
		"ui.hud: pozice se PREPISE (evidence %s, uzel %s)"
			% [str(hud.position_of("chat")), str(okno.position)])

	# 3) rozlozeni: ulozeni, obnoveni a to, ze `layout()` je KOPIE
	var ulozeno: Dictionary = hud.layout()
	t._check(ulozeno.get("chat") == Vector2(30, 40),
		"ui.hud: layout() vraci pozici okna (namEReno %s)" % str(ulozeno.get("chat")))
	hud.set_position("chat", Vector2(7, 8))
	t._check(hud.restore_layout(ulozeno) == 1 and hud.position_of("chat") == Vector2(30, 40),
		"ui.hud: restore_layout obnovi ulozenou pozici (namEReno %s)"
			% str(hud.position_of("chat")))
	ulozeno["chat"] = Vector2(999, 999)
	t._check(hud.position_of("chat") == Vector2(30, 40),
		"ui.hud: layout() je KOPIE - zmena slovniku nemeni HUD (namEReno %s)"
			% str(hud.position_of("chat")))

	# 4) NEZNAME okno: null/false, nikdy vymyslena pozice ani novy uzel
	t._check(hud.position_of("neexistuje") == null and hud.window_of("neexistuje") == null,
		"ui.hud: NEZNAME okno vraci null (pozice %s, uzel %s)"
			% [str(hud.position_of("neexistuje")), str(hud.window_of("neexistuje"))])
	t._check(hud.set_position("neexistuje", Vector2(1, 2)) == false,
		"ui.hud: set_position na neznamem okne vraci false (okno se nevyrobi)")
	var obnoveno: int = hud.restore_layout({"neexistuje": Vector2(3, 4)})
	t._check(obnoveno == 0 and hud.window_of("neexistuje") == null,
		"ui.hud: restore_layout neznama okna NEVYROBI (obnoveno %d)" % obnoveno)

	# 5) prazdne id / chybejici uzel: false, ne pad
	t._check(hud.register_window("", okno, Vector2(1, 2)) == false,
		"ui.hud: prazdne id se nezaregistruje (false)")
	t._check(hud.register_window("bez_uzlu", null) == false,
		"ui.hud: null uzel se nezaregistruje (false, ne pad)")
	t._check(hud.position_of("") == null and hud.position_of("bez_uzlu") == null,
		"ui.hud: po nezaregistrovani nema ani prazdne id pozici")

	# 6) uzel bez vlastnosti `position` (Node) se zaregistruje a pozice se drzi
	var holy := Node.new()
	t._check(hud.register_window("plain", holy, Vector2(5, 6)) == true
			and hud.position_of("plain") == Vector2(5, 6),
		"ui.hud: i Node bez `position` se zaregistruje a pozice se drzi")
	holy.free()

	# 7) opetovna registrace tutez id prepsat uzel i pozici
	var druhe := Control.new()
	t._check(hud.register_window("chat", druhe, Vector2(50, 60)) == true
			and hud.window_of("chat") == druhe and druhe.position == Vector2(50, 60),
		"ui.hud: opetovna registrace prepsat uzel i pozici (uzel %s, pozice %s)"
			% [str(hud.window_of("chat") == druhe), str(druhe.position)])

	hud.free()
	okno.free()
	druhe.free()
