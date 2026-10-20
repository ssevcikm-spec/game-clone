extends RefCounted
# app.debug_travel + ui.debug_travel - DEBUG TELEPORT MEZI TESTOVACIMI BODY
# (2026-10-20). JE TO DEBUG POMUCKA, NE HERNI FUNKCE.
#
# Test meri CHOVANI, ne existenci souboru:
#   1. VALIDACE DAT (`zpracuj`): platna data projdou, chybejici pole / duplicitni
#      dlazdice / nezname `proc` / prazdny seznam jsou VADY (a vadny zaznam se
#      PRESKOCI) - "chybejici bod = VADA, ne ticho" ze zadani,
#   2. REALNA DATA (`data/test-points.json`): pet bodu, vsech pet druhu, zadne
#      dva body na stejne dlazdici a nazvy neprazdne,
#   3. TELEPORT FUNKCE: `teleport()` preda controlleru PRESNE dlazdici a vysku
#      z dat, vrati `ok` a do zurnalu posle "Teleport: <nazev> (debug)";
#      mimo rozsah vrati `ok: false` (zadny pad, zadne tiche nic),
#   4. OKNO (`ui.debug_travel`): body dostane VSTUPEM, vykresli je do UZLU
#      (text v promenne neni text na obrazovce), otevira/zavira se a prazdny
#      vstup REKNE, ze neni co zobrazit.
#
# ⚠ SOUBOR SE JMENUJE `ui_debug_travel.gd` (ne `debug_travel.gd`): case soubory
# jdou ABECEDNE a tenhle test nic neregistruje - jmeno `ui_` ho radi za
# `player_controller.gd` a `ui_hotkeys.gd`, stejna konvence jako u nich.
#
# Cesty jsou VSTUPY (`-- --travel-module=...`, `-- --travel-panel=...`,
# `-- --travel-data=...`), aby se daly merit nad mutantem (muti harness).

const Lib = preload("res://tests/lib.gd")

const TRAVEL_MODULE := "res://app/debug_travel.gd"
const TRAVEL_PANEL := "res://ui/debug_travel.gd"
const TRAVEL_DATA := "res://data/test-points.json"


class StubController:
	# Nahrada `app/player_controller.teleport_na`: meri se, CO modul preda
	# (presna dlazdice a vyska), ne jak to dopadne ve scene - to meri G22.
	extends RefCounted
	var volani: Array = []
	var odpoved: Dictionary = {"ok": true, "reason": "", "kamera": Vector2.ZERO}

	func teleport_na(tile: Vector2i, z: int) -> Dictionary:
		volani.append({"tile": tile, "z": z})
		var out: Dictionary = odpoved.duplicate()
		out["tile"] = tile
		out["z"] = z
		return out


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _body_ok() -> Array:
	return [
		{"id": "start", "nazev": "Start", "x": 1495, "y": 1630, "z": 10, "proc": "start"},
		{"id": "kovani", "nazev": "Vyhen", "x": 1494, "y": 1630, "z": 10, "proc": "kovani"},
		{"id": "obchod", "nazev": "Kovar", "x": 1497, "y": 1629, "z": 10, "proc": "obchod"},
		{"id": "tezba", "nazev": "Balvan", "x": 1495, "y": 1633, "z": 10, "proc": "tezba"},
		{"id": "boj", "nazev": "Hrbitov", "x": 1371, "y": 1482, "z": 10, "proc": "boj"},
	]


func _data(body: Array) -> Dictionary:
	return {"titulek": "TITULEK", "body": body}


func _proc(body: Array) -> Array:
	var out: Array = []
	for b in body:
		out.append(str(b.get("proc", "")))
	return out


func run(t) -> void:
	var modul_skript = Lib.script_at(_arg("travel-module", TRAVEL_MODULE))
	if modul_skript == null:
		t._pending("app.debug_travel NENI HOTOV: " + TRAVEL_MODULE + " chybi")
		return

	# 1) VALIDACE DAT: platny vstup projde.
	var ok: Dictionary = modul_skript.zpracuj(_data(_body_ok()))
	t._check((ok["body"] as Array).size() == 5 and (ok["vady"] as Array).is_empty(),
		"debug_travel: platna data = 5 bodu a 0 vad (body %d, vady %s)"
			% [(ok["body"] as Array).size(), str(ok["vady"])])
	var vsech_pet: bool = true
	for druh in ["start", "tezba", "kovani", "obchod", "boj"]:
		if not (druh in _proc(ok["body"])):
			vsech_pet = false
	t._check(vsech_pet, "debug_travel: vsech pet druhu bodu proslo (%s)" % str(_proc(ok["body"])))

	# CHYBEJICI POLE = VADA a zaznam se PRESKOCI (ne tiche pouziti).
	var chybi: Array = _body_ok()
	(chybi[0] as Dictionary).erase("nazev")
	var v1: Dictionary = modul_skript.zpracuj(_data(chybi))
	t._check((v1["vady"] as Array).size() == 1 and (v1["body"] as Array).size() == 4,
		"debug_travel: chybejici pole = 1 vada, 4 pouzite body (vady %s, body %d)"
			% [str(v1["vady"]), (v1["body"] as Array).size()])
	# DVE VECI NA JEDNE DLAZDICI = VADA (druha by byla mrtva).
	var dvojita: Array = _body_ok()
	(dvojita[1] as Dictionary)["x"] = (dvojita[0] as Dictionary)["x"]
	(dvojita[1] as Dictionary)["y"] = (dvojita[0] as Dictionary)["y"]
	var v2: Dictionary = modul_skript.zpracuj(_data(dvojita))
	t._check((v2["vady"] as Array).size() == 1 and (v2["body"] as Array).size() == 4,
		"debug_travel: dve veci na jedne dlazdici = vada (vady %s)" % str(v2["vady"]))
	# NEZNÁMÝ `proc` = VADA (brana by ho neumela zmerit); zaznam se preskoci,
	# takze po nem zbyde 4 body a JEDNA vada (chybejici druh hlasi brana G22,
	# modul hlasi jen tvar dat).
	var zly: Array = _body_ok()
	(zly[0] as Dictionary)["proc"] = "neexistuje"
	var v3: Dictionary = modul_skript.zpracuj(_data(zly))
	t._check((v3["vady"] as Array).size() == 1 and (v3["body"] as Array).size() == 4,
		"debug_travel: nezname 'proc' = vada a zaznam se preskoci (vady %s, body %d)"
			% [str(v3["vady"]), (v3["body"] as Array).size()])
	# PRAZDNY SEZNAM neni uspech (a musi to rict).
	var v4: Dictionary = modul_skript.zpracuj(_data([]))
	t._check(not (v4["vady"] as Array).is_empty() and (v4["body"] as Array).is_empty(),
		"debug_travel: prazdny seznam = vada (vady %s)" % str(v4["vady"]))
	# DVANACT BODU: vic nez 9 nejde vyvolat cislice 1-9.
	var moc: Array = []
	for i in range(10):
		moc.append({"id": "bod_%d" % i, "nazev": "Bod %d" % i, "x": 1400 + i,
			"y": 1600, "z": 10, "proc": "start"})
	var v5: Dictionary = modul_skript.zpracuj(_data(moc))
	t._check(not (v5["vady"] as Array).is_empty(),
		"debug_travel: 10 bodu = vada (klavesy jsou 1-9), vady %s" % str(v5["vady"]))

	# 2) REALNA DATA: pet bodu a vsech pet druhu.
	var data = Lib.json_at(_arg("travel-data", TRAVEL_DATA))
	if not (data is Dictionary):
		t._pending("data/test-points.json se necte jako slovnik")
		return
	var real: Dictionary = modul_skript.zpracuj(data)
	t._check((real["body"] as Array).size() == 5 and (real["vady"] as Array).is_empty(),
		"data/test-points.json: 5 bodu, 0 vad (body %d, vady %s)"
			% [(real["body"] as Array).size(), str(real["vady"])])
	var dlazdice: Dictionary = {}
	var nazvy_ok: bool = true
	for b in real["body"]:
		dlazdice["%d,%d" % [int(b["x"]), int(b["y"])]] = true
		if str(b["nazev"]).strip_edges() == "":
			nazvy_ok = false
	t._check(dlazdice.size() == 5,
		"data/test-points.json: body jsou na RUZNYCH dlazdicich (%d unikatnich)" % dlazdice.size())
	t._check(nazvy_ok, "data/test-points.json: kazdy bod ma nazev (hraci se pise, kam skace)")

	# 3) TELEPORT FUNKCE: presna dlazdice + vyska, hlaseni do zurnalu.
	var modul = modul_skript.new(_arg("travel-data", TRAVEL_DATA))
	var stub := StubController.new()
	var hlaseni: Array = []
	modul.setup(null, stub, null)
	modul.hlaseni = func(text: String) -> void: hlaseni.append(text)
	t._check(modul.pocet() == 5, "debug_travel: `new(cesta)` nacte 5 bodu (namereno %d)"
		% modul.pocet())
	var skok: Dictionary = modul.teleport(1)
	var cil: Dictionary = (modul.body() as Array)[1]
	t._check(bool(skok.get("ok", false)) and stub.volani.size() == 1,
		"debug_travel: `teleport(1)` zavola controller jednou (volani %d)" % stub.volani.size())
	if stub.volani.size() == 1:
		var v: Dictionary = stub.volani[0]
		t._check((v["tile"] as Vector2i) == Vector2i(int(cil["x"]), int(cil["y"]))
			and int(v["z"]) == int(cil["z"]),
			"debug_travel: controller dostane PRESNOU dlazdici a vysku (%s, z %d)"
				% [str(v["tile"]), int(v["z"])])
	t._check(hlaseni.size() == 1 and str(hlaseni[0])
		== modul_skript.zprava_o_teleportu(str(cil["nazev"])),
		"debug_travel: do zurnalu jde 'Teleport: <nazev> (debug)' (namereno %s)"
			% str(hlaseni))
	t._check(str(hlaseni[0]).begins_with("Teleport: ") and str(hlaseni[0]).ends_with(" (debug)"),
		"debug_travel: tvar hlaseni je presne 'Teleport: ... (debug)' (namereno %s)"
			% (str(hlaseni[0]) if not hlaseni.is_empty() else ""))
	t._check(modul.teleportu() == 1,
		"debug_travel: pocitadlo teleportu je 1 (namereno %d)" % modul.teleportu())
	# CISLO 3 = treti bod (index 2); mimo rozsah = ok:false, ne tichy návrat.
	var pres_cislo: Dictionary = modul.teleport_cislem(3)
	t._check(bool(pres_cislo.get("ok", false)) and str(pres_cislo.get("bod", "")) == "obchod",
		"debug_travel: `teleport_cislem(3)` = bod 'obchod' (namereno %s)"
			% str(pres_cislo.get("bod")))
	var mimo: Dictionary = modul.teleport_cislem(9)
	t._check(not bool(mimo.get("ok", true)) and str(mimo.get("reason", "")) == "no_point",
		"debug_travel: cislo bez bodu vraci ok:false / no_point (namereno %s)" % str(mimo))
	var bez_controlleru = modul_skript.new("")
	t._check(not bool(bez_controlleru.teleport(0).get("ok", true)),
		"debug_travel: bez controlleru teleport nic nedela a rekne to")
	t._check(not (bez_controlleru.vady() as Array).is_empty(),
		"debug_travel: prazdna cesta = vada v `vady()` (ne ticha nula)")

	# 4) OKNO: radky vstupem -> uzly, otevreni/zavreni, prazdno se rekne.
	var panel_skript = Lib.script_at(_arg("travel-panel", TRAVEL_PANEL))
	if panel_skript == null:
		t._pending("ui.debug_travel NENI HOTOV: " + TRAVEL_PANEL + " chybi")
		return
	var okno = panel_skript.new()
	t._check(not okno.je_otevreny(),
		"ui.debug_travel: nove okno je zavrene (namereno %s)" % str(okno.je_otevreny()))
	var otevreno: bool = okno.toggle()
	t._check(otevreno and okno.je_otevreny() and okno.zavri() and not okno.je_otevreny(),
		"ui.debug_travel: `toggle()` otevre, `zavri()` zavre (otevreno %s)" % str(otevreno))
	var pocet: int = okno.nastav("TITULEK", modul.radky())
	t._check(pocet == 5 and okno.count() == 5,
		"ui.debug_travel: `nastav` prijme 5 radku (namereno %d/%d)" % [pocet, okno.count()])
	okno.flush()
	var texty: Array = okno.row_texts()
	t._check(texty.size() == 5,
		"ui.debug_travel: `flush()` postavi 5 radku do UZLU (namereno %d)" % texty.size())
	t._check(not texty.is_empty() and str(texty[0]).find("Start") >= 0,
		"ui.debug_travel: prvni radek je Start (namereno '%s')"
			% (str(texty[0]) if not texty.is_empty() else ""))
	okno.nastav("T", [], "NIC TU NENI")
	okno.flush()
	var prazdno_uzel: bool = false
	var box = okno.get_node_or_null("Panel/Body")
	if box != null:
		for uzel in box.get_children():
			if uzel is Label and str(uzel.name).begins_with("Prazdno"):
				prazdno_uzel = str(uzel.text) == "NIC TU NENI"
	t._check(prazdno_uzel and okno.count() == 0,
		"ui.debug_travel: prazdny vstup se VYKRESLI jako uzel 'NIC TU NENI'")
	okno.free()
	# `modul` i `bez_controlleru` jsou `RefCounted` - ti se uvolnuji sami
	# (`free()` na nich je chyba, ne uklid).
	modul.setup(null, stub, null)
