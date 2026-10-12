extends RefCounted
# sim.content - vrstvy obsahu: stabilni ID, PORADI NACITANI a sev pro mody.
#
# Co tenhle case meri (a cim): modul VOLA a porovnava vysledky - nestaci, ze
# soubor existuje (`docs/09 §9.4`: hotovo = funkce se zavolala a vysla
# konkretni hodnota). Kontroluje se:
#   1. prazdny obsah nic nevymysli (`path_for` vraci "" a `path_or_default`
#      zakladni cestu),
#   2. vrstva s vyssim `order` prebije nizsi (a `providers()` to doklada),
#   3. poradi vrstev nezalezi na poradi VLOZENI (determinismus - docs/02 §2.3),
#   4. pri shode `order` rozhoduje `id` vzestupne,
#   5. kazda vada deklarace se OHLASTI a vrstva se neprida (ne ticha pulka),
#   6. mod, ktery soubor deklaruje a NEMA ho, se preskoci - hra nesmi spadnout
#      na preklep v modu - a je videt v `missing_files()`,
#   7. `discover()` nacte zakladni deklaraci z repa a mody ze zadaneho adresare,
#      vcetne rozbiteho `mod.json`, chybejiciho `order` a preklepu v klici,
#   8. zakladni deklarace v repu se SHODUJE s obsahem `data/` (neni to rucni
#      seznam, ktery zestarne pri prvnim novem datovem souboru),
#   9. `manifest()` nese JEN identitu (id, version, order, required) - zadne
#      cesty: save nesmi zaviset na umisteni instalace.
#
# Vsechny fixture se pisi do `user://test-content-*` (ne do produktoveho
# `user://mods`), aby test nemohl ovlivnit hru a naopak.

const Lib = preload("res://tests/lib.gd")
const SCRIPT_PATH := "res://sim/content.gd"
const BASE_DECL := "res://data/content-layers.json"
const TEST_MODS := "user://test-content-mods"
const TEST_FILES := "user://test-content-files"


func run(t) -> void:
	var script = Lib.script_at(SCRIPT_PATH)
	if script == null:
		t._pending("sim.content NENI HOTOVY: sim/content.gd chybi nebo se neda nacist")
		return

	# -- 1) prazdny obsah nic nevymysli ------------------------------------
	var prazdny = script.new()
	t._check(prazdny.layer_count() == 0, "sim.content: novy obsah ma 0 vrstev")
	t._check(prazdny.path_for("data/items.json") == "",
		"sim.content: bez vrstev `path_for` vraci '' (zadna cesta se nevymysli)")
	t._check(prazdny.path_or_default("data/items.json") == "res://data/items.json",
		"sim.content: `path_or_default` vraci zakladni cestu")
	t._check(prazdny.errors().is_empty(), "sim.content: prazdny obsah nema chyby")
	t._check(prazdny.manifest().is_empty(), "sim.content: prazdny manifest je prazdny")
	t._check(prazdny.manifest_hash().length() == 64,
		"sim.content: manifest_hash je SHA-256 (64 znaku, namEReno %d)" % prazdny.manifest_hash().length())

	# -- 2) vrstva s vyssim `order` prebije nizsi ---------------------------
	_smaz(TEST_FILES)
	t._check(_zapis(TEST_FILES + "/mod-a/data/items.json", "[{\"tile\": 1}]"),
		"fixture: mod-a/data/items.json zapsan")
	t._check(_zapis(TEST_FILES + "/mod-a/data/balance.json", "{\"combat_era\": 1}"),
		"fixture: mod-a/data/balance.json zapsan (nedeklarovany soubor v modu)")
	var obsah = script.new()
	t._check(obsah.add("base", 1, 0, ["data/items.json", "data/balance.json"], "res://", true),
		"sim.content: vrstva `base` prosla kontrolou")
	t._check(obsah.path_for("data/items.json") == "res://data/items.json",
		"sim.content: dokud je jen zaklad, vyhrava zaklad")
	t._check(obsah.add("mod.example", 2, 100, ["data/items.json"], TEST_FILES + "/mod-a/", false),
		"sim.content: vrstva modu prosla kontrolou")
	t._check(obsah.path_for("data/items.json") == TEST_FILES + "/mod-a/data/items.json",
		"sim.content: mod s vyssim `order` prebije zaklad (namEReno %s)"
			% obsah.path_for("data/items.json"))
	t._check(obsah.path_for("data/balance.json") == "res://data/balance.json",
		"sim.content: soubor, ktery mod NEDEKLAROVAL, zustava ze zakladu (i kdyz ho v modu ma)")
	t._check(obsah.providers("data/items.json") == ["base", "mod.example"],
		"sim.content: `providers` vraci vsechny vrstvy vzestupne (kdo to prebil, je videt)")
	t._check(obsah.override_count() == 1,
		"sim.content: `override_count` pocita prekryte soubory (namEReno %d)" % obsah.override_count())
	t._check(obsah.missing_files().is_empty(),
		"sim.content: zadny deklarovany soubor nechybi (namEReno %s)" % str(obsah.missing_files()))

	# -- 3) determinismus: poradi vlozeni nesmi rozhodovat ------------------
	var opacne = script.new()
	opacne.add("mod.example", 2, 100, ["data/items.json"], TEST_FILES + "/mod-a/", false)
	opacne.add("base", 1, 0, ["data/items.json", "data/balance.json"], "res://", true)
	t._check(opacne.layer_ids() == obsah.layer_ids(),
		"sim.content: poradi vrstev nezalezi na poradi VLOZENI (%s vs %s)"
			% [str(opacne.layer_ids()), str(obsah.layer_ids())])
	t._check(opacne.manifest_hash() == obsah.manifest_hash(),
		"sim.content: `manifest_hash` je stejny pri opacnem poradi vlozeni")
	t._check(opacne.path_for("data/items.json") == obsah.path_for("data/items.json"),
		"sim.content: i vitez je stejny pri opacnem poradi vlozeni")

	# -- 4) shoda `order` -> rozhoduje `id` vzestupne -----------------------
	var shoda = script.new()
	shoda.add("zzz", 1, 50, [], "res://", false)
	shoda.add("aaa", 1, 50, [], "res://", false)
	t._check(shoda.layer_ids() == ["aaa", "zzz"],
		"sim.content: pri shode `order` rozhoduje `id` vzestupne (namEReno %s)" % str(shoda.layer_ids()))

	# -- 5) vady deklarace se ohlasti a vrstva se neprida -------------------
	var vadne = script.new()
	t._check(vadne.add("Base", 1, 0, [], "res://", true) == false,
		"sim.content: id s velkym pismenem se odmitne")
	t._check(vadne.add("", 1, 0, [], "res://", true) == false,
		"sim.content: prazdne id se odmitne")
	t._check(vadne.add("ok", 0, 0, [], "res://", true) == false,
		"sim.content: `version` 0 se odmitne")
	t._check(vadne.add("ok", 1, -1, [], "res://", true) == false,
		"sim.content: zaporne `order` se odmitne")
	t._check(vadne.add("ok", 1, 0, [], "", true) == false,
		"sim.content: `root` mimo res:// nebo user:// se odmitne")
	t._check(vadne.add("ok", 1, 0, [], "res://../x/", true) == false,
		"sim.content: `root` s '..' se odmitne")
	t._check(vadne.add("ok", 1, 0, [], "res://", true) == true,
		"sim.content: platna vrstva prosla")
	t._check(vadne.add("ok", 1, 5, [], "res://", true) == false,
		"sim.content: duplicitni id se odmitne")
	var chyb_pred: int = vadne.errors().size()
	t._check(vadne.add("rel", 1, 6, ["../tajne.json", "/abs.json", "ok.json"], "res://", true) == true,
		"sim.content: vrstva s vadnou cestou se prida, ale vada se ohlasti")
	t._check(vadne.errors().size() == chyb_pred + 2,
		"sim.content: dve vadne cesty = dve chyby (namEReno %d)"
			% (vadne.errors().size() - chyb_pred))
	t._check(not vadne.declared_files().has("../tajne.json"),
		"sim.content: vadna cesta se do vrstvy NEDOSTALA")
	t._check(vadne.missing_files() == ["rel:ok.json"],
		"sim.content: deklarovany soubor, ktery neexistuje, je v `missing_files` (namEReno %s)"
			% str(vadne.missing_files()))

	# -- 6) mod bez souboru se preskoci, hra jede dal ----------------------
	var polovicni = script.new()
	polovicni.add("base", 1, 0, ["data/items.json"], "res://", true)
	polovicni.add("mod.prazdny", 1, 10, ["data/items.json"], TEST_FILES + "/prazdny/", false)
	t._check(polovicni.path_for("data/items.json") == "res://data/items.json",
		"sim.content: mod, ktery soubor deklaruje a NEMA ho, se preskoci - vyhraje zaklad")
	t._check(polovicni.missing_files() == ["mod.prazdny:data/items.json"],
		"sim.content: chybejici soubor modu je VIDET v `missing_files` (namEReno %s)"
			% str(polovicni.missing_files()))

	# -- 7) discover(): zaklad z repa + mody z adresare ---------------------
	_smaz(TEST_MODS)
	t._check(_zapis(TEST_MODS + "/dobry/mod.json", JSON.stringify({
		"id": "test.dobry", "version": 3, "order": 100, "files": ["data/help.json"]})),
		"fixture: dobry/mod.json zapsan")
	t._check(_zapis(TEST_MODS + "/dobry/data/help.json", "{\"uvod\": []}"),
		"fixture: dobry/data/help.json zapsan")
	_zapis(TEST_MODS + "/rozbit/mod.json", "{ to neni json")
	_zapis(TEST_MODS + "/bez-order/mod.json", "{\"id\": \"mod.bez\", \"version\": 1, \"files\": []}")
	_zapis(TEST_MODS + "/bez-tecky/mod.json",
		"{\"id\": \"bez\", \"version\": 1, \"order\": 5, \"files\": []}")
	_zapis(TEST_MODS + "/s-root/mod.json",
		"{\"id\": \"test.sroot\", \"version\": 1, \"order\": 5, \"root\": \"res://\", \"files\": []}")
	_zapis(TEST_MODS + "/preklep/mod.json",
		"{\"id\": \"test.prek\", \"version\": 1, \"order\": 5, \"files\": [], \"ordr\": 5}")
	DirAccess.make_dir_recursive_absolute(TEST_MODS + "/bez-modjson")
	DirAccess.make_dir_recursive_absolute(TEST_MODS + "/.skryty")

	var nacteny = script.new()
	var pridano: int = nacteny.discover(BASE_DECL, TEST_MODS)
	t._check(pridano == 2,
		"sim.content: discover pridal zaklad + 1 dobry mod (namEReno %d)" % pridano)
	t._check(nacteny.layer_ids() == ["base", "test.dobry"],
		"sim.content: vrstvy po discover jsou base a test.dobry (namEReno %s)"
			% str(nacteny.layer_ids()))
	t._check(nacteny.path_for("data/help.json") == TEST_MODS + "/dobry/data/help.json",
		"sim.content: mod prebil `help.json` (namEReno %s)" % nacteny.path_for("data/help.json"))
	t._check(nacteny.path_for("data/items.json") == "res://data/items.json",
		"sim.content: neprebity soubor zustava ze zakladu")
	t._check(nacteny.errors().size() == 6,
		"sim.content: rozbit/bez-order/bez-tecky/s-root/preklep/bez-modjson = 6 chyb (namEReno %d)"
			% nacteny.errors().size())
	var text_chyb: String = "\n".join(PackedStringArray(nacteny.errors()))
	for jmeno in ["rozbit", "bez-order", "bez-tecky", "s-root", "preklep", "bez-modjson"]:
		t._check(text_chyb.contains(jmeno),
			"sim.content: chyba JMENUJE vinny adresar '%s' (jinak se to hleda tezko)" % jmeno)
	t._check(text_chyb.contains("jmenny prostor"),
		"sim.content: mod s id bez tecky se odmitne S DUVODEM (jmenny prostor)")
	t._check(not nacteny.layer_ids().has(".skryty"),
		"sim.content: adresar zacinajici teckou se preskoci")

	# -- 7b) kdo co prebil je VIDET (mod muze menit, ale ne tise) ----------
	t._check(nacteny.overrides() == ["data/help.json"],
		"sim.content: `overrides()` pojmenuje soubor, ktery poskytuje vic vrstev (namEReno %s)"
			% str(nacteny.overrides()))
	t._check(nacteny.providers("data/help.json") == ["base", "test.dobry"],
		"sim.content: `providers()` u prebileho souboru vi, kdo ho prebil (namEReno %s)"
			% str(nacteny.providers("data/help.json")))
	t._check(not nacteny.overrides().has("data/items.json"),
		"sim.content: neprebity soubor v `overrides()` NENI")

	# -- 8) zakladni deklarace v repu odpovida `data/` ----------------------
	var zaklad = script.new()
	t._check(zaklad.discover(BASE_DECL, "") == 1,
		"sim.content: deklarace vrstev da prave 1 vrstvu (`base`)")
	t._check(zaklad.layer_ids() == ["base"], "sim.content: vrstva se jmenuje `base`")
	var vrstvy: Array = zaklad.layers()
	t._check(not vrstvy.is_empty() and bool(vrstvy[0]["required"]) == true,
		"sim.content: `base` je `required` (pro save v dalsim kroku)")
	t._check(zaklad.missing_files().is_empty(),
		"sim.content: zadny deklarovany soubor `base` nechybi (namEReno %s)"
			% str(zaklad.missing_files()))
	var deklarovane: Array = zaklad.declared_files()
	var na_disku: Array = []
	var dir := DirAccess.open("res://data")
	if dir != null:
		for jmeno in dir.get_files():
			var n := str(jmeno)
			if n.ends_with(".json") and n != "content-layers.json":
				na_disku.append("data/" + n)
	na_disku.sort()
	t._check(deklarovane == na_disku,
		"sim.content: `base` deklaruje PRESNE soubory, ktere v data/ jsou (deklarovano %d, na disku %d)"
			% [deklarovane.size(), na_disku.size()])
	t._check(zaklad.path_for("data/items.json") == "res://data/items.json",
		"sim.content: zakladni vrstva rozlisi `data/items.json` na res:// (namEReno %s)"
			% zaklad.path_for("data/items.json"))

	# -- 9) manifest nese jen identitu, ne cesty ---------------------------
	var manifest: Array = zaklad.manifest()
	var polozka: Dictionary = manifest[0] if not manifest.is_empty() else {}
	t._check(polozka.has("id") and polozka.has("version") and polozka.has("order")
			and polozka.has("required"),
		"sim.content: manifest ma id, version, order, required (namEReno %s)" % str(polozka.keys()))
	t._check(not polozka.has("root") and not polozka.has("files"),
		"sim.content: manifest NEMA cesty (save nesmi zaviset na umisteni instalace)")

	# -- uklid (fixture nesmi zustat ve `user://`) --------------------------
	_smaz(TEST_MODS)
	_smaz(TEST_FILES)


func _zapis(cesta: String, text: String) -> bool:
	var idx: int = cesta.rfind("/")
	if idx > 0:
		DirAccess.make_dir_recursive_absolute(cesta.substr(0, idx))
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _smaz(cesta: String) -> void:
	var d := DirAccess.open(cesta)
	if d == null:
		return
	for jmeno in d.get_files():
		DirAccess.remove_absolute(cesta + "/" + str(jmeno))
	for jmeno in d.get_directories():
		_smaz(cesta + "/" + str(jmeno))
	DirAccess.remove_absolute(cesta)
