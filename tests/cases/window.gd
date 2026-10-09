extends RefCounted
# app.window - geometrie okna (2026-10-09, faze 1 bod 5.2).
#
# ZADANI UZIVATELE (doslova): "Hra totiz nebezi fullscreen, ale ja si ji pak do
# fullscreen zvetsim ... Prostoru je dost, muzes to zvetsit na 1600*900."
# a otazka "neumis udelat okno sveta volitelne? V UO u nekterych klientu lze ten
# ram roztahnout libovolne."
#
# NAMERENO PRED OPRAVOU (`_analyza/p26-okno.gd`): okno systemu 1600x900 ->
# viewport (platno) i svet zustaly 1280x720, viditelne dlazdice 78x44 tytéž.
# Geomerie se pocitala JEDNOU v `app/main._setup_ui()`, takze vetsi okno
# nepridalo ani dlazdici. Reference pritom ma ram sveta volitelny
# (`_src/classicuo/.../GameScene.cs:102-105`, `WorldViewportGump.cs:128-150`,
# `OptionsGump.cs:4113-4133`).
#
# CO SE MERI (chovani, ne pritomnost):
#   1. svet je to, co zbylo po pasu - a pro DVA RUZNE ROZMERY se LISI presne
#      o ubytek (kdyby modul vracel konstantu, spadne to),
#   2. fullsize: pas je nulovy a svet = cele okno,
#   3. male okno nesmi dat zaporny svet (nula je stav, ne vymyslena hodnota),
#   4. stred sveta = to, na co se centruje kamera,
#   5. okna HUDu: v pase, nebo (fullsize) nad svetem - a v obou pripadech
#      UVNITR okna,
#   6. `app/world_view.nastav_gui_odsazeni` prevezme pas a VYNUTI prestavbu
#      seznamu objektu (jinak by po zvetseni okna zustaly u okraju diry).

const Lib = preload("res://tests/lib.gd")
const WindowScript = preload("res://app/window.gd")

const OKNO := Vector2(1600, 900)
const MALY := Vector2(1280, 720)


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var w = WindowScript.new()

	# 1) Pas a svet pro dva rozmery: rozdil MUSI byt presne ubytek okna.
	var svet_velky: Rect2 = w.svet_obal(OKNO, false)
	var svet_maly: Rect2 = w.svet_obal(MALY, false)
	t._check(svet_velky.size == Vector2(1280, 780),
		"app.window: svet v okne 1600x900 je 1280x780 (namEReno %s)" % str(svet_velky.size))
	t._check(svet_maly.size == Vector2(960, 600),
		"app.window: svet v okne 1280x720 je 960x600 (namEReno %s)" % str(svet_maly.size))
	t._check((svet_velky.size - svet_maly.size) == (OKNO - MALY),
		"app.window: vetsi okno PRIDAVA svet presne o rozdil okna (rozdil %s)"
			% str(svet_velky.size - svet_maly.size))

	# 2) Fullsize: zadny pas, svet = cele okno.
	t._check(w.pas(OKNO, true) == Vector2.ZERO,
		"app.window: fullsize nema cerny pas (namEReno %s)" % str(w.pas(OKNO, true)))
	t._check(w.svet_obal(OKNO, true).size == OKNO,
		"app.window: ve fullsize je svet cele okno (namEReno %s)"
			% str(w.svet_obal(OKNO, true).size))

	# 3) Male okno: svet nesmi byt zaporny.
	var svet_maly_pas: Rect2 = w.svet_obal(Vector2(200, 100), false)
	t._check(svet_maly_pas.size.x >= 0.0 and svet_maly_pas.size.y >= 0.0,
		"app.window: male okno nedava zaporny svet (namEReno %s)" % str(svet_maly_pas.size))

	# 4) Stred sveta = to, na co se centruje kamera (`gui_odsazeni = pas/2`).
	t._check(w.stred_sveta(OKNO, false) == Vector2(640, 390),
		"app.window: stred sveta v okne 1600x900 je (640,390) (namEReno %s)"
			% str(w.stred_sveta(OKNO, false)))
	t._check(w.stred_sveta(OKNO, true) == OKNO / 2.0,
		"app.window: ve fullsize je stred sveta stred okna (namEReno %s)"
			% str(w.stred_sveta(OKNO, true)))

	# 5) Okna HUDu: v pase (neni fullsize), nebo nad svetem (fullsize) - a VZDY
	#    uvnitr okna (mimo okno by hrac o ne prisel).
	var s_pasem: Dictionary = w.pozice_oken(OKNO, false)
	var bez_pasu: Dictionary = w.pozice_oken(OKNO, true)
	t._check(s_pasem.get("status_bar") == Vector2(8, 788)
			and s_pasem.get("journal") == Vector2(1288, 8),
		"app.window: s pasem je stavovy radek dole v pase a zurnal vpravo (namEReno %s)"
			% str(s_pasem))
	t._check(bez_pasu.get("status_bar") == Vector2(8, 872)
			and bez_pasu.get("journal") == Vector2(1288, 8),
		"app.window: ve fullsize okna plavou nad svetem (namEReno %s)" % str(bez_pasu))
	for varianta in [s_pasem, bez_pasu]:
		for id in varianta.keys():
			var poz: Vector2 = varianta[id]
			t._check(poz.x >= 0.0 and poz.y >= 0.0 and poz.x < OKNO.x and poz.y < OKNO.y,
				"app.window: okno '%s' je uvnitr okna (namEReno %s)" % [str(id), str(poz)])

	# 6) `nastav_gui_odsazeni` ve `world_view`: prevezme pas a VYNUTI prestavbu
	#    seznamu (sentinel). Bez toho by po zvetseni okna zustaly u okraju diry -
	#    stejna past jako u zmeny zoomu.
	var koren := Node2D.new()
	t.root.add_child(koren)          # bez stromu se `_ready()` vubec nezavola
	var kam := Camera2D.new()
	kam.name = "Camera"
	koren.add_child(kam)
	var view = Lib.script_at("res://app/world_view.gd").new()
	koren.add_child(view)
	# ⚠ NAMERENA PAST (2026-10-08, `tests/cases/world_view.gd:190-196`): v behu
	# `--script` se `_ready()` z `add_child` v `_initialize()` NESPUSTI (koren
	# stromu neni "inside tree"), takze by `_camera`, `_sort` i `_hues` zustaly
	# null a metoda by tise nedelala nic. Zivotni cyklus se proto volá rucne.
	view.call("_ready")
	t._check(view._camera == kam,
		"app.world_view: uzel si nasel kameru ve scene (namEReno %s)" % str(view._camera))
	view.nastav_gui_odsazeni(Vector2.ZERO)
	var stred_bez_pasu: Vector2 = kam.position
	view.nastav_gui_odsazeni(Vector2(160.0, 60.0))
	t._check(view.gui_odsazeni == Vector2(160.0, 60.0),
		"app.world_view: nastav_gui_odsazeni nastavi pas (namEReno %s)"
			% str(view.gui_odsazeni))
	t._check(int(view._list_center.x) < -9999,
		"app.world_view: nastav_gui_odsazeni vynuti prestavbu seznamu (list_center %s)"
			% str(view._list_center))
	# Posun kamery je pas/zoom (do SVETA se deli zoomem, viz `look_at_tile`);
	# tolerance je 1 px sveta kvuli zaokrouhleni na mrizku obrazovky.
	var posun: Vector2 = kam.position - stred_bez_pasu
	var cekany: Vector2 = Vector2(160.0, 60.0) / view.zoom
	t._check(kam.position != stred_bez_pasu and (posun - cekany).length() <= 1.0,
		"app.world_view: pas posune kameru o pas/zoom (posun %s, cekano %s)"
			% [str(posun), str(cekany)])
	koren.free()