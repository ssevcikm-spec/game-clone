extends RefCounted
# VARIANTY DLAZDIC PODLE SOURADNIC BUNKY (2026-10-11, granule
# `render.land_variants`): `render.own_art` (klic `groups`) + `render.textures`
# (`variant_id`/`texture_variant`/`offset_variant`) + `render.chunk` (seznam).
#
# CO SE MERI (chovani, ne "metoda existuje"):
#   * BEZ `groups` je chovani PRESNE dnesni (jedno id = jedna dlazdice),
#   * SE skupinou se varianta vybira CISTE podle souradnic bunky - dva nezavisle
#     behy daji stejny hash (`determinismus` je kontrakt: replaye a snimky v CI),
#   * TEXTURA I OFFSET jdou ze STEJNEHO zaznamu (jinak sprite sedi vedle,
#     `tools/artgen/SEAM.md` §2 bod 2),
#   * id mimo skupinu zustava beze zmeny,
#   * seznam z `render.chunk` variantu OPRAVDU pouzije - a protoze z neho bere
#     `art_id` i davka (`render/chunk_mesh`), nemohou se kreslici cesty rozejit,
#   * vadne `groups` se hlasi SEZNAMEM chyb (ne tichym prazdnem).
#
# Fixture se vyrabi za behu v `.cache/test-land-variants/` (jako `own_art.gd`),
# takze test meri i v CI, kde `assets/uo/` ani vlastni sady nejsou.
#
# Cesta k merenym souborum je VSTUP (`-- --own-script=`, `--textures-script=`,
# `--chunk-script=`), aby na nich sel pustit mutacni harness.

const Lib = preload("res://tests/lib.gd")

const OWN_SCRIPT := "res://render/own_art.gd"
const CACHE_SCRIPT := "res://render/texture_cache.gd"
const CHUNK_SCRIPT := "res://render/chunk_renderer.gd"
const SLUZKA := "res://.cache/test-land-variants"
const LAND := 500                # id, ktere je ve skupine
const VARIANTS := 16             # kolik variant (clenu skupiny) fixture ma
const MIMO := 515                # id, ktere v konfiguraci "mimo" ve skupine NENI
const GRID := 20                 # 20x20 bunek = zadani §4 A
const STROP_PODILU := 20.0       # s N >= 16 musi byt shoda se sousedem < 20 %


class FakeMap:
	# Stejne rozhrani jako `sim/world/map.gd` - jen to, co `render.chunk` vola.
	var land_id: int = LAND
	var land_rect: Rect2i = Rect2i(0, 0, GRID, GRID)

	func land_at(x: int, y: int) -> int:
		return land_id if land_rect.has_point(Vector2i(x, y)) else -1

	func z_at(_x: int, _y: int) -> int:
		return 0                          # rovina: zadny svah, zadny texmap

	func statics_at(_x: int, _y: int) -> Array:
		return []


class FakeTiledata:
	func texture(_tile: int) -> int:
		return 0

	func flags(_art_id: int) -> int:
		return 0

	func height(_art_id: int) -> int:
		return 0


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _png(cesta: String, barva: Color) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(barva)
	img.save_png(cesta)


func _zapis(cesta: String, text: String) -> void:
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ids() -> Array:
	# Id clenu skupiny: 500..515 (16 variant).
	var out: Array = []
	for i in VARIANTS:
		out.append(LAND + i)
	return out


func _vyrob_fixture() -> Dictionary:
	var zaklad := ProjectSettings.globalize_path(SLUZKA)
	DirAccess.make_dir_recursive_absolute(zaklad + "/own")
	DirAccess.make_dir_recursive_absolute(zaklad + "/uo")
	_png(zaklad + "/own/own0.png", Color(0.9, 0.2, 0.1, 1.0))
	_png(zaklad + "/uo/uo0.png", Color(0.1, 0.4, 0.9, 1.0))

	# 16 dlazdic 4x4 px; KAZDA MA JINY OFFSET (ox = i, oy = -i). Offset je tu
	# proto, aby se dalo dokazat, ze `offset_variant` bere offset z VYBRANEHO
	# zaznamu a ne z puvodniho id (v produkci maji vsechny land arty ox = oy = 0,
	# takze by se to na nich dokazat NEDALO).
	var sprity: Array = []
	for i in VARIANTS:
		sprity.append({"kind": "land", "id": LAND + i, "page": "own0.png",
			"x": 4 * i, "y": 0, "w": 4, "h": 4, "ox": i, "oy": -i})
	_zapis(zaklad + "/own/manifest.json", JSON.stringify({"sprites": sprity}))
	_zapis(zaklad + "/uo/manifest.json", JSON.stringify({"sprites": [
		{"kind": "land", "id": LAND, "page": "uo0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 0, "oy": 0},
		{"kind": "land", "id": MIMO, "page": "uo0.png", "x": 4, "y": 0,
			"w": 4, "h": 4, "ox": 0, "oy": 0},
	]}))

	var vrstva: Dictionary = {
		"name": "nase", "manifest": zaklad + "/own/manifest.json",
		"sprites": {"land": _ids()},
	}
	var bez: Dictionary = {"version": 1, "layers": [vrstva]}
	var se: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(se["layers"][0] as Dictionary)["groups"] = {"land": [_ids()]}
	var jen_cast: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(jen_cast["layers"][0] as Dictionary)["groups"] = {"land": [
		_ids().slice(0, VARIANTS - 1)]}     # 500..514; 515 zustava mimo skupinu

	var cesty: Dictionary = {}
	for klic in [["bez_skupin", bez], ["se_skupinami", se], ["mimo_skupinu", jen_cast]]:
		var cesta: String = zaklad + "/%s.json" % str(klic[0])
		_zapis(cesta, JSON.stringify(klic[1]))
		cesty[str(klic[0])] = cesta

	# VADNE KONFIGURACE (kazda musi dat chybu s VLASTNIM duvodem - jinak by test
	# prosel i s vadou, ktera se hlasi z jineho duvodu).
	var vadne: Dictionary = {}
	var mimo_vyber: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(mimo_vyber["layers"][0] as Dictionary)["groups"] = {"land": [[LAND, 9999]]}
	vadne["clen_mimo_sprites"] = [mimo_vyber, "sprites"]
	var kratka: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(kratka["layers"][0] as Dictionary)["groups"] = {"land": [[LAND]]}
	vadne["skupina_o_jednom"] = [kratka, "aspon 2"]
	var dvakrat: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(dvakrat["layers"][0] as Dictionary)["groups"] = {"land": [
		[LAND, LAND + 1], [LAND + 1, LAND + 2]]}
	vadne["id_ve_dvou_skupinach"] = [dvakrat, "uz ve skupine"]
	var v_teze: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(v_teze["layers"][0] as Dictionary)["groups"] = {"land": [[LAND, LAND, LAND + 1]]}
	vadne["id_dvakrat_v_teze"] = [v_teze, "dvakrat v teze skupine"]
	var neznamy: Dictionary = {"version": 1, "layers": [vrstva.duplicate(true)]}
	(neznamy["layers"][0] as Dictionary)["groups"] = {"gump": [[1, 2]]}
	vadne["neznamy_druh"] = [neznamy, "neznamy druh"]
	var vadne_cesty: Dictionary = {}
	for klic in vadne.keys():
		var cesta: String = zaklad + "/vadne-%s.json" % str(klic)
		_zapis(cesta, JSON.stringify(vadne[klic][0]))
		vadne_cesty[str(klic)] = [cesta, str(vadne[klic][1])]

	return {"zaklad": zaklad, "cesty": cesty, "vadne": vadne_cesty,
		"uo_manifest": zaklad + "/uo/manifest.json", "prefix": zaklad + "/uo/"}


func _cache(cache_script, own_script, f: Dictionary, klic: String):
	var cfg: Dictionary = own_script.load_config(f["cesty"][klic])
	return cache_script.new(f["uo_manifest"], 100 * 1024 * 1024, f["prefix"], cfg["layers"])


func _sha(cache, art: int, grid: int) -> String:
	# Determinismus dokazeme HASHem poradi variant, ne "vypada to stejne":
	# dva nezavisle behy musi dat stejny sha256.
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for y in grid:
		for x in grid:
			ctx.update(("%d,%d=%d;" % [x, y, cache.variant_id(art, x, y)]).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _podil_sousedu(cache, art: int, grid: int, lag: int = 1) -> Dictionary:
	# Metrika ze zadani §4 A: podil dlazdic, ktere maji STEJNY sprite jako
	# soused vzdaleny `lag` bunek. Na dnešním kódu (jedno id) musi vyjit 100 %.
	# `lag = pocet variant` je KONTROLA PERIODY: naivni hash
	# (`x*HASH_X ^ y*HASH_Y`) ma `index(x + n, y) == index(x, y)` ve 100 %
	# pripadu, takze by se vzor opakoval presne kazdych `n` bunek.
	var shoda: int = 0
	var celkem: int = 0
	var ruzne: Dictionary = {}
	for y in grid:
		for x in grid:
			var a: int = cache.variant_id(art, x, y)
			ruzne[a] = true
			if x + lag < grid:
				celkem += 1
				if cache.variant_id(art, x + lag, y) == a:
					shoda += 1
	return {"shoda": shoda, "celkem": celkem,
		"podil": 100.0 * float(shoda) / float(maxi(celkem, 1)),
		"ruznych": ruzne.size()}


func _podil_v_seznamu(seznam: Array, grid: int) -> Dictionary:
	# Tyz podil, ale pocitany ze SEZNAMU `render.chunk` - tedy z toho, co
	# kreslici cesty opravdu dostanou (`art_id` je uz vybrana varianta).
	var mrizka: Dictionary = {}
	for obj in seznam:
		if str(obj["kind"]) == "land":
			mrizka[Vector2i(int(obj["x"]), int(obj["y"]))] = int(obj["art_id"])
	var shoda: int = 0
	var celkem: int = 0
	var ruzne: Dictionary = {}
	for y in grid:
		for x in grid:
			if not mrizka.has(Vector2i(x, y)):
				continue
			var a: int = int(mrizka[Vector2i(x, y)])
			ruzne[a] = true
			if mrizka.has(Vector2i(x + 1, y)):
				celkem += 1
				if int(mrizka[Vector2i(x + 1, y)]) == a:
					shoda += 1
	return {"shoda": shoda, "celkem": celkem,
		"podil": 100.0 * float(shoda) / float(maxi(celkem, 1)),
		"ruznych": ruzne.size(), "landu": mrizka.size()}


func _seznam(chunk_script, cache) -> Array:
	var chunk = chunk_script.new(FakeMap.new(), cache, FakeTiledata.new())
	return chunk.visible(Vector2i(GRID / 2, GRID / 2), GRID, GRID)


func run(t) -> void:
	var own_script = Lib.script_at(_arg("own-script", OWN_SCRIPT))
	var cache_script = Lib.script_at(_arg("textures-script", CACHE_SCRIPT))
	var chunk_script = Lib.script_at(_arg("chunk-script", CHUNK_SCRIPT))
	if own_script == null or cache_script == null or chunk_script == null:
		t._pending("varianty dlazdic NEEXISTUJI: chybi render/own_art.gd, "
			+ "render/texture_cache.gd nebo render/chunk_renderer.gd")
		return
	var f: Dictionary = _vyrob_fixture()
	_mer_bez_skupin(t, own_script, cache_script, chunk_script, f)
	_mer_se_skupinami(t, own_script, cache_script, chunk_script, f)
	_mer_vadne_konfigurace(t, own_script, f)


func _mer_bez_skupin(t, own_script, cache_script, chunk_script, f: Dictionary) -> void:
	# 1) BEZ `groups` JE CHOVANI PRESNE DNEJSI (zadani §3.1): varianta vrati vstup.
	var cache = _cache(cache_script, own_script, f, "bez_skupin")
	var vsechno_vstup: bool = true
	for y in 5:
		for x in 5:
			if cache.variant_id(LAND, x, y) != LAND:
				vsechno_vstup = false
	var st: Dictionary = cache.stats()
	t._check(vsechno_vstup and int(st["variants"]["groups"]) == 0
			and int(st["variants"]["members"]) == 0,
		"render.textures: bez `groups` vraci variant_id VSTUP a stats() hlasi 0 skupin "
		+ "(namEReno %s)" % str(st["variants"]))
	t._check(cache.texture_variant(LAND, 3, 4) != null
			and cache.texture_variant(LAND, 3, 4).region == cache.texture(LAND).region
			and cache.offset_variant(LAND, 3, 4) == cache.offset(LAND),
		"render.textures: bez `groups` je textura i offset varianty TOTEZ co dnes")

	# 2) SEZNAM bez skupin: vsechny dlazdice maji puvodni id a podil je 100 %
	var bez: Dictionary = _podil_v_seznamu(_seznam(chunk_script, cache), GRID)
	t._check(int(bez["landu"]) == GRID * GRID and is_equal_approx(float(bez["podil"]), 100.0)
			and int(bez["ruznych"]) == 1,
		("render.chunk: bez skupin ma 20x20 plocha %d dlazdic jednoho id a podil se sousedem 100 %% "
			+ "(namEReno %s)") % [GRID * GRID, str(bez)])


func _mer_se_skupinami(t, own_script, cache_script, chunk_script, f: Dictionary) -> void:
	var cache = _cache(cache_script, own_script, f, "se_skupinami")
	var st: Dictionary = cache.stats()
	t._check(int(st["variants"]["groups"]) == 1 and int(st["variants"]["members"]) == VARIANTS,
		"render.textures: stats() hlasi skupinu a vsechny cleny (namEReno %s)"
			% str(st["variants"]))

	# 1) VYBER JE CISTA FUNKCE SOUZADNIC + hodnoty jsou z CLENU skupiny
	var clenove := {}
	for id in _ids():
		clenove[id] = true
	var z_skupiny: bool = true
	var vse_v_rozsahu: bool = true
	var mimo: int = 0
	var mimo_rozsah: String = ""
	for y in GRID:
		for x in GRID:
			var vybrany: int = cache.variant_id(LAND, x, y)
			if not clenove.has(vybrany):
				z_skupiny = false
				mimo += 1
			for n in [2, 3, VARIANTS]:
				var i: int = cache.variant_index(x, y, n)
				if i < 0 or i >= n:
					vse_v_rozsahu = false
					mimo_rozsah = "x=%d y=%d n=%d -> %d" % [x, y, n, i]
	t._check(z_skupiny and vse_v_rozsahu,
		("render.textures: variant_id vraci VZDY clena skupiny (%d mimo) a variant_index "
			+ "index v rozsahu (%s)") % [mimo, mimo_rozsah if mimo_rozsah != "" else "vse ok"])

	# 2) DETERMINISMUS: dva nezavisle behy (i dve cache) daji stejny sha256
	var cache2 = _cache(cache_script, own_script, f, "se_skupinami")
	var sha1: String = _sha(cache, LAND, GRID)
	var sha2: String = _sha(cache2, LAND, GRID)
	t._check(sha1 == sha2 and sha1.length() == 64,
		"render.textures: dva nezavisle behy daji stejny sha256 variant (namEReno %s vs %s)"
			% [sha1.substr(0, 12), sha2.substr(0, 12)])

	# 3) TEXTURA I OFFSET ZE STEJNEHO ZAZNAMU
	var stejny: bool = true
	var lisi_se: int = 0
	var offsety := {}
	for y in GRID:
		for x in GRID:
			var vybrany: int = cache.variant_id(LAND, x, y)
			var off: Vector2i = cache.offset_variant(LAND, x, y)
			offsety[off] = true
			if off != cache.offset(vybrany):
				stejny = false
			if off != cache.offset(LAND):
				lisi_se += 1
			var tex: Texture2D = cache.texture_variant(LAND, x, y)
			if tex == null or tex.region != cache.texture(vybrany).region:
				stejny = false
	t._check(stejny and offsety.size() >= 2 and lisi_se > 0,
		"render.textures: textura i offset varianty jdou ze STEJNEHO zaznamu "
		+ "(offsety %d, mimo puvodni id %d)" % [offsety.size(), lisi_se])

	# 4) ZMIZELO OPAKOVANI (zadani §4 A): s N = 16 musi byt podil < 20 %
	var mer: Dictionary = _podil_sousedu(cache, LAND, GRID)
	t._check(float(mer["podil"]) < STROP_PODILU and int(mer["ruznych"]) >= VARIANTS / 2,
		("render.textures: 20x20 se 16 variantami ma podil se sousedem %.1f %% < %.0f %% "
			+ "a pouzilo %d variant (namEReno %s)")
			% [float(mer["podil"]), STROP_PODILU, int(mer["ruznych"]), str(mer)])

	# 4b) ZADNA PERIODA ZAROVNANA S MRIZKOU (vlastni past, namERena 2026-10-11
	#     v `_analyza/lv-mix.py`): samotne `x*HASH_X ^ y*HASH_Y` ma
	#     `index(x + n, y) == index(x, y)` ve 100 % pripadu, takze by se vzor
	#     opakoval presne kazdych N bunek (`n = 4` = 176 px) - presne ta
	#     pravidelnost, kterou ma varianta odstranit. Meri se proto i tato
	#     perioda, ne jen bezprostredni soused.
	var perioda: Dictionary = _podil_sousedu(cache, LAND, GRID, VARIANTS)
	t._check(float(perioda["podil"]) < STROP_PODILU,
		("render.textures: varianty se NEOPAKUJI s periodou %d bunek (podil %.1f %% < %.0f %%, %s)")
			% [VARIANTS, float(perioda["podil"]), STROP_PODILU, str(perioda)])

	# 5) SEZNAM `render.chunk` VARIANTU OPRAVDU POUZIJE (a davka bere `art_id`
	#    z neho, takze se obe kreslici cesty nemohou rozejit)
	var sez: Dictionary = _podil_v_seznamu(_seznam(chunk_script, cache), GRID)
	t._check(int(sez["landu"]) == GRID * GRID and int(sez["ruznych"]) >= VARIANTS / 2
			and float(sez["podil"]) < STROP_PODILU,
		("render.chunk: seznam ma varianty z `groups` (20x20: %d dlazdic, %d ruznych, "
			+ "podil %.1f %%)") % [int(sez["landu"]), int(sez["ruznych"]), float(sez["podil"])])

	# 6) ID MIMO SKUPINU zustava beze zmeny (nesmi se "priclenit" nasilim) a
	#    pritom varianta porad funguje - kdyby se v te konfiguraci nevybirala,
	#    prosla by i slepa verze `variant_id`.
	var jen_cast = _cache(cache_script, own_script, f, "mimo_skupinu")
	var mer_cast: Dictionary = _podil_sousedu(jen_cast, LAND, GRID)
	var mimo_ok: bool = true
	for y in 5:
		for x in 5:
			if jen_cast.variant_id(MIMO, x, y) != MIMO:
				mimo_ok = false
	t._check(mimo_ok and int(mer_cast["ruznych"]) >= 2 and float(mer_cast["podil"]) < STROP_PODILU,
		("render.textures: se skupinou o %d clenech varianta funguje a id %d mimo skupinu vraci VSTUP "
			+ "(namEReno %s)") % [VARIANTS - 1, MIMO, str(mer_cast)])


func _mer_vadne_konfigurace(t, own_script, f: Dictionary) -> void:
	# 7) VADNA `groups` SE HLA SI SEZNAMEM a se SPRAVNYM duvodem (kdyby se
	#    kontroloval jen "je chyba", proslo by i hlaseni z jine priciny).
	for klic in f["vadne"].keys():
		var cesta: String = f["vadne"][klic][0]
		var ocekavany: String = f["vadne"][klic][1]
		var cfg: Dictionary = own_script.load_config(cesta)
		var text := " | ".join(cfg["errors"])
		t._check(not bool(cfg["ok"]) and text.find(ocekavany) >= 0,
			("render.own_art: vadne 'groups' (%s) se odmitne s duvodem obsahujicim '%s' "
				+ "(ok=%s, chyby: %s)") % [str(klic), ocekavany, str(cfg["ok"]), text.substr(0, 160)])
