extends RefCounted
# render.textures - cache textur z atlasu (docs/04 §4.2; soubor render/texture_cache.gd).
#
# Test si VYROBI vlastni atlas (2 male stranky) i manifest v `.cache/`, takze
# meri i v CI bez `assets/uo/` (ta jsou v gitignore).
#
# ⚠ CO JE TU TO NEJDULEZITEJSI: `texture(art_id)` musi pro stejne art_id vracet
# **TUTEZ instanci**. Kdyz vracelo novou (stav do 2026-10-07), stalo to
# 0,118 ms x 5 767 objektu = 655 ms na frame a hra jela na 1-2 FPS. Identita se
# overuje pres `is_same()` - `==` u objektu v GDScriptu porovnava jinak.
#
# Cesta k souboru je VSTUP (`-- --textures-script=<cesta>`), aby mutacni test
# mohl predat mutanta.

const Lib = preload("res://tests/lib.gd")

const TEXTURES_SCRIPT := "res://render/texture_cache.gd"
const SLUZKA := "res://.cache/test-textures"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _vyrob_atlas() -> String:
	# Dve stranky 4x4 a manifest se ctyrmi sprity (2 land, 2 item).
	# Vrací ABSOLUTNÍ cestu k manifestu: v headless režimu Godot resource
	# filesystem nevidí soubor, který test teprve vytvořil, takže cesta musí
	# být systémová (na to je v `texture_cache` převod `globalize_path`).
	var abs_slozka := ProjectSettings.globalize_path(SLUZKA)
	DirAccess.make_dir_recursive_absolute(abs_slozka)
	for i in 2:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5 + 0.5 * i, 0.2, 0.1, 1.0))
		img.save_png(abs_slozka + "/strana%d.png" % i)
	var sprity: Array = [
		{"kind": "land", "id": 1, "page": "strana0.png", "x": 0, "y": 0, "w": 4, "h": 4, "ox": 0, "oy": 0},
		{"kind": "land", "id": 2, "page": "strana0.png", "x": 0, "y": 0, "w": 4, "h": 4, "ox": 1, "oy": 1},
		{"kind": "item", "id": 5, "page": "strana1.png", "x": 0, "y": 0, "w": 4, "h": 4, "ox": 0, "oy": 0},
		{"kind": "item", "id": 6, "page": "strana1.png", "x": 0, "y": 0, "w": 4, "h": 4, "ox": 2, "oy": 3},
	]
	var f := FileAccess.open(SLUZKA + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"sprites": sprity}))
	f.close()
	return abs_slozka + "/manifest.json"


func run(t) -> void:
	var cesta: String = _arg("textures-script", TEXTURES_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("render.textures NENI HOTOVA: " + cesta + " chybi")
		return
	var manifest: String = _vyrob_atlas()
	# Treti argument je prefix cest ke strankam - testovaci atlas lezi mimo
	# `assets/uo/` (ta jsou v gitignore), takze se cesty musi predat.
	var cache = script.new(manifest, 100 * 1024 * 1024, manifest.get_base_dir() + "/")
	var st: Dictionary = cache.stats()
	t._check(int(st["sprites"]) == 4,
		"render.textures: manifest dal 4 sprity (namEReno %d)" % int(st["sprites"]))

	# 1) IDENTITA: stejne art_id -> TA SAMA instance (jádro výkonu, viz hlavička)
	var a: Texture2D = cache.texture(0x4000 + 5)
	var b: Texture2D = cache.texture(0x4000 + 5)
	t._check(a != null and b != null,
		"render.textures: art 0x4005 se nacte (namEReno %s)" % str(a))
	t._check(a != null and is_same(a, b),
		"render.textures: druhe volani vraci TUTEZ instanci (ne novou; jinak 655 ms/frame)")
	var c: Texture2D = cache.texture(0x4000 + 6)
	t._check(c != null and not is_same(a, c),
		"render.textures: jine art_id vraci jinou texturu")

	# 2) region a offset sedi na manifest
	if a != null:
		t._check(a.region == Rect2(0, 0, 4, 4),
			"render.textures: region je z manifestu (namEReno %s)" % str(a.region))
	t._check(cache.offset(0x4000 + 6) == Vector2i(2, 3),
		"render.textures: offset je z manifestu (namEReno %s)" % str(cache.offset(0x4000 + 6)))

	# 3) nezname art_id vraci null a pocita se do `missing` (nula neni uspech)
	var prazdno: Texture2D = cache.texture(0x4000 + 999)
	t._check(prazdno == null and int(cache.stats()["missing"]) == 1,
		"render.textures: nezname art vraci null a je v `missing` (namEReno %d)"
			% int(cache.stats()["missing"]))

	# 4) stranky se NEnacitaji znovu: pocitadlo se po nabehu nesmi ZVYSIT.
	#    Pozor na past: `po == pred` nic nedokazuje, kdyby bylo pred == 0
	#    (nulova stranka neni uspech) - proto se vyzaduje i presna hodnota nabehu.
	#    Oba sprity (0x4005 i 0x4006) jsou v TEZE strane, takze nabeh = 1 stranka.
	var cache2 = script.new(manifest, 100 * 1024 * 1024, manifest.get_base_dir() + "/")
	cache2.texture(0x4000 + 5)
	cache2.texture(0x4000 + 6)
	var pred: int = int(cache2.stats()["nacteni_stranek"])
	for i in 200:
		cache2.texture(0x4000 + 5)
		cache2.texture(0x4000 + 6)
	var po: int = int(cache2.stats()["nacteni_stranek"])
	t._check(pred == 1 and po == pred,
		"render.textures: 400 dotazu neprinese zadne dalsi nacteni stranky (nabeh %d, po dotazech %d)"
			% [pred, po])
	t._check(int(cache2.stats()["wrapped"]) >= 2,
		"render.textures: hotova okna se drzi ve `wrapped` (namEReno %d)"
			% int(cache2.stats()["wrapped"]))

	# 5) smlouva o vystupu: `stats()` ma vsechny slozky, ktere dokumentace slibuje
	var chybi: Array = []
	for klic in ["loaded", "bytes", "limit", "missing", "sprites", "wrapped",
			"nacteni_stranek", "ceka", "verze"]:
		if not st.has(klic):
			chybi.append(klic)
	t._check(chybi.is_empty(),
		"render.textures: stats() ma vsechny slozky (chybi %s)" % str(chybi))

	# 6) prazdny/neexistujici manifest nesmi spadnout (vraci prazdno + hlaseni)
	var prazdna = script.new(manifest.get_base_dir() + "/neexistuje.json", 1024)
	t._check(prazdna.texture(1) == null and int(prazdna.stats()["sprites"]) == 0,
		"render.textures: chybejici manifest vraci prazdno, ne pad")

	# 7) REALNA data se meri navic, jen kdyz na disku jsou (jinak nahlas NEMERENO)
	if not FileAccess.file_exists("res://assets/uo/manifest.json"):
		print("[test]      NEMERENO: render.textures nad realnym atlasem - chybi assets/uo/manifest.json")
		return
	var real = script.new()
	var rs: Dictionary = real.stats()
	t._check(int(rs["sprites"]) > 1000,
		"render.textures: realny manifest ma tisice spritu (namEReno %d)" % int(rs["sprites"]))
	var r1: Texture2D = null
	# ⚠ 18. session: stranky atlasu se nacitaji NA POZADI (`load_threaded_request`),
	# takze prvni dotaz muze vratit `null` a `page_pending(0)` je true. Test na
	# nabeh POČKÁ (a kdyby se nikdy nenacetl, `r1` zustane null = chyba).
	for i in 300:
		r1 = real.texture(0)
		if r1 != null:
			break
		OS.delay_msec(10)
	var r2: Texture2D = real.texture(0)
	t._check(r1 != null and is_same(r1, r2),
		"render.textures: i nad realnym atlasem vraci stejne art_id tutez instanci (po nabehu)")
