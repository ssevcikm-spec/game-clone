extends RefCounted
# world.regions - regiony a mesta (granule `world.regions`, docs/04 §4.2,
# obsah docs/06 §6.7, research/06 §1.4-1.5).
#
# ⚠ `data/regions.json` DNES V REPU NENI (`tools/gates/gen-content.py:55` ho
# vede jako neextrahovany). Prijimaci kriterium roadmapy ("Britain 1495,1630 je
# mesto a guard zona") proto dnes ZMERIT NELZE - a presne to test dela videt:
#   * cesta, ktera neexistuje -> `known()` false, `region_at` vraci
#     `known:false` a prazdny nazev (NESMI si vymyslet region),
#   * az data vzniknou, se ZAPNE i kontrola prijimaciho kriteria (dve vetve,
#     kazda neco tvrdi - ticho tu neni: NEMERENO se vypisuje),
#   * s testovaci sadou (fixture v `user://`) se meri CELE chovani: klice
#     z dat, plocha `x/y/width/height` i `area`, half-open hranice, "mimo
#     regiony" jako zmereny prazdny vysledek a poradi zaznamu pri prekryvu.
#
# Cesta k modulu je VSTUP: `-- --regions-script=<cesta>`.

const Lib = preload("res://tests/lib.gd")
const REGIONS_SCRIPT := "res://sim/world/regions.gd"
const DATA_PATH := "res://data/regions.json"
const FIXTURE := "user://zaklady-regions.json"
const FIXTURE_NELIST := "user://zaklady-regions-nelist.json"
const FIXTURE_BEZ_REGIONU := "user://zaklady-regions-bez.json"
const BRITAIN_X := 1495                    # prijimaci kriterium roadmapy
const BRITAIN_Y := 1630


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _zapis(cesta: String, text: String) -> bool:
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _fixture() -> Array:
	return [
		{"name": "Britain", "x": 1400, "y": 1500, "width": 400, "height": 400,
			"is_town": true, "is_guard_zone": true, "music": 12,
			"spawn_table": "town_fringe"},
		{"name": "Trinsic", "area": {"x": 1800, "y": 2700, "width": 200, "height": 200},
			"is_town": true, "music": 13},
		# Prekryv s Britannii: vyhrava PRVNI zaznam v souboru (rozhodnuti klonu).
		{"name": "PodBritain", "x": 1450, "y": 1550, "width": 10, "height": 10,
			"music": 99},
		{"x": 1, "y": 1, "width": 5, "height": 5},   # bez `name` -> preskoci se
		"nesmysl",                                   # neni slovnik -> preskoci se
	]


func run(t) -> void:
	var cesta: String = _arg("regions-script", REGIONS_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("world.regions NENI HOTOVY: " + cesta + " chybi nebo se neparsuje")
		return
	var sonda = script.new()
	var chybi: Array[String] = []
	for metoda in ["region_at", "is_guard_zone", "music_at", "known", "region_count"]:
		if not sonda.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "world.regions: chybi metody %s - case se neda merit" % str(chybi))
		return

	# A) REALNA DATA (nebo NEMERENO) - obe vetve neco tvrdi
	var realny = script.new(DATA_PATH)
	if realny.known():
		var brit = realny.region_at(BRITAIN_X, BRITAIN_Y)
		t._check(str(brit.get("name", "")) != "" and bool(brit.get("is_town", false))
				and bool(brit.get("is_guard_zone", false)),
			"world.regions: Britain %d,%d je mesto a guard zona (namEReno %s)"
				% [BRITAIN_X, BRITAIN_Y, str(brit)])
	else:
		print("[test]      mereno (regions): ", DATA_PATH, " NEEXISTUJE -> prijimaci ",
			"kriterium roadmapy (Britain ", BRITAIN_X, ",", BRITAIN_Y, ") je NEMERENE; ",
			"modul vraci known=false")
		var prazdny = realny.region_at(BRITAIN_X, BRITAIN_Y)
		t._check(prazdny.get("known") == false and str(prazdny.get("name", "")) == ""
				and prazdny.get("is_town") == false and prazdny.get("is_guard_zone") == false
				and int(prazdny.get("music", -1)) == 0,
			"world.regions: bez dat vraci region_at {known:false, name:'', is_town:false} - NEMERENO, ne vymysleny region")
		t._check(realny.region_count() == 0,
			"world.regions: bez dat je region_count 0 (a to je NEMERENO, ne 'svet bez regionu')")

	# B) NEEXISTUJICI CESTA: NEMERENO se NESMI tvarit jako "neni mesto"
	var zadny = script.new("user://neexistuje-regions.json")
	t._check(zadny.known() == false and zadny.region_count() == 0
			and zadny.region_at(0, 0).get("known") == false,
		"world.regions: neexistujici soubor = NEMERENO (known false, count 0, region_at known:false)")
	t._check(zadny.is_guard_zone(BRITAIN_X, BRITAIN_Y) == false
			and zadny.music_at(BRITAIN_X, BRITAIN_Y) == 0,
		"world.regions: NEMERENO vraci false/0 - kdo to pouzije, musi se ptat `known()`")

	# C) FIXTURE: merene chovani s daty
	if not _zapis(FIXTURE, JSON.stringify(_fixture())):
		t._check(false, "world.regions: testovaci data nejde zapsat do " + FIXTURE)
		return
	var r = script.new(FIXTURE)
	t._check(r.known() == true and r.region_count() == 3 and r.skipped() == 2,
		"world.regions: fixture ma 3 regiony a 2 preskocene zaznamy (namEReno known %s, count %d, skipped %d)"
			% [str(r.known()), r.region_count(), r.skipped()])

	var brit = r.region_at(BRITAIN_X, BRITAIN_Y)
	t._check(str(brit.get("name", "")) == "Britain" and bool(brit.get("is_town", false))
			and bool(brit.get("is_guard_zone", false)) and int(brit.get("music", 0)) == 12
			and str(brit.get("spawn_table", "")) == "town_fringe"
			and bool(brit.get("known", false)),
		"world.regions: uvnitr Britainu vraci vsechny klice z dat (namEReno %s)" % str(brit))
	t._check(r.is_guard_zone(BRITAIN_X, BRITAIN_Y)
			and r.music_at(BRITAIN_X, BRITAIN_Y) == 12,
		"world.regions: is_guard_zone a music_at jdou z region_at")

	var tri = r.region_at(1900, 2800)
	t._check(str(tri.get("name", "")) == "Trinsic" and tri.get("is_guard_zone") == false
			and int(tri.get("music", 0)) == 13,
		"world.regions: plocha muze byt i v `area` (namEReno %s)" % str(tri))

	var mimo = r.region_at(0, 0)
	t._check(mimo.get("known") == true and str(mimo.get("name", "")) == ""
			and mimo.get("is_town") == false and mimo.get("is_guard_zone") == false,
		"world.regions: mimo regiony je known:true s prazdnym nazvem (ZMERENO, ne NEMERENO)")

	t._check(str(r.region_at(1400, 1500).get("name", "")) == "Britain"
			and str(r.region_at(1800, 1500).get("name", "")) == "",
		"world.regions: levy horni roh patri regionu, pravy dolni uz ne (half-open okno)")

	t._check(str(r.region_at(1455, 1555).get("name", "")) == "Britain"
			and int(r.region_at(1455, 1555).get("music", 0)) == 12,
		"world.regions: pri prekryvu vyhrava PRVNI zaznam v souboru (namEReno %s)"
			% str(r.region_at(1455, 1555)))

	# D) SOUBOR, KTERY NENI SEZNAM: take NEMERENO (ne ticha nula)
	_zapis(FIXTURE_NELIST, "{\"a\": 1}")
	var nelist = script.new(FIXTURE_NELIST)
	t._check(nelist.known() == false and nelist.region_count() == 0,
		"world.regions: JSON, ktery neni seznam, je NEMERENO (known false)")

	# E) SOUBOR BEZ POUZITELNEHO ZAZNAMU (existuje, ale nema `name`): je to
	#    NEMERENO, ne "svet bez regionu" - jinak by se tise tvrdilo, ze data
	#    jsou, a `region_at` by se ptal `_find` na prazdny seznam.
	_zapis(FIXTURE_BEZ_REGIONU, JSON.stringify([
		{"x": 1, "y": 1, "width": 5, "height": 5}, "nesmysl"]))
	var bez_regionu = script.new(FIXTURE_BEZ_REGIONU)
	t._check(bez_regionu.known() == false and bez_regionu.region_count() == 0
			and bez_regionu.skipped() == 2
			and bez_regionu.region_at(2, 2).get("known") == false,
		"world.regions: soubor bez zaznamu s `name` je NEMERENO (known %s, count %d, skipped %d)"
			% [str(bez_regionu.known()), bez_regionu.region_count(), bez_regionu.skipped()])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_NELIST))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_BEZ_REGIONU))
