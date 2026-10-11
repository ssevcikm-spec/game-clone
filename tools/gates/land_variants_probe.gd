extends SceneTree
# SONDA PRO BRANU G17 (`tools/gates/check-land-variants.py`) - doklad, ze se
# dlazdice vybiraji VARIANTNE a DETERMINISTICKY. Neni to brana sama: brana
# spousti tenhle skript a POROVNAVA jeho cisla s prahy a s konfiguraci - kdyby
# si prahy pocitala sonda, merila by sama sebe.
#
# CO SE MERI (a proc to nejde "jen prectist z kodu"):
#   1) SEZNAM `render.chunk` na plose 20x20 JEDNOHO id:
#      * bez `groups` musi vyjit podil dlazdic shodnych s pravym sousedem (lag 1)
#        PRESNE 100 % (to je dnešní chovani - kdyby vyslo min, meri se neco jineho),
#      * s 16 variantami musi vyjit < 20 % (prah brany) a pouzit >= 8 variant.
#      Cislo se bere ze SEZNAMU, ktery je spolecny pro obe kreslici cesty
#      (`app/world_view` i `render/chunk_mesh`) - meri se tedy to, co hra kresli.
#   2) DETERMINISMUS: dva NEZAVISLE behy (dve cache, dva seznamy) musi dat stejny
#      sha256 poradi variant (zadna nahoda za behu).
#   3) OFFSET I TEXTURA ZE STEJNEHO ZAZNAMU: fixture ma u kazde varianty JINY
#      offset (v produkci maji vsechny land arty ox = oy = 0, takze by se to na
#      nich dokazat nedalo).
#   4) DAVKA (`render/chunk_mesh`) dostane STEJNE varianty: pocet slotu runtime
#      atlasu je 1 (bez skupin) vs 16 (se skupinami) - kdyby davka brala puvodni
#      id, zustal by 1.
#   5) ID MIMO SKUPINU vraci VSTUP (dnesni chovani).
#
# Fixture se vyrabi za behu v `.cache/gates/land-variants/`, takze sonda
# NEPOTREBUJE `assets/uo/` a beh je stejny lokalne i v CI.
#
# Spousteni:
#   godot --headless --path . --script res://tools/gates/land_variants_probe.gd
# Vystup: radky `[variants] klic=hodnota` (cte je brana), `[variants] chyba=...`
# znamena, ze fixture je rozbita a brana to musi videt (exit 1).

const OwnArtScript = preload("res://render/own_art.gd")
const TextureCacheScript = preload("res://render/texture_cache.gd")
const ChunkScript = preload("res://render/chunk_renderer.gd")
const MeshScript = preload("res://render/chunk_mesh.gd")

const SLUZKA := "res://.cache/gates/land-variants"
const LAND := 500
const VARIANTS := 16
const MIMO := 700                 # id, ktere ve skupine NENI (fallback kontrola)
const GRID := 20                  # 20x20 bunek jako v zadani §4 A

var _selhalo: int = 0


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


func _f(klic: String, hodnota) -> void:
	print("[variants] %s=%s" % [klic, str(hodnota)])


func _chyba(text: String) -> void:
	_selhalo += 1
	print("[variants] chyba=", text)


func _initialize() -> void:
	var zaklad := _vyrob_fixture()
	var cfg_bez: Dictionary = OwnArtScript.load_config(zaklad + "/bez.json")
	var cfg_se: Dictionary = OwnArtScript.load_config(zaklad + "/se.json")
	_f("cfg_ok_bez", 1 if cfg_bez["ok"] else 0)
	_f("cfg_chyb_bez", cfg_bez["errors"].size())
	_f("cfg_ok_se", 1 if cfg_se["ok"] else 0)
	_f("cfg_chyb_se", cfg_se["errors"].size())
	for e in cfg_bez["errors"] + cfg_se["errors"]:
		_f("cfg_error", e)
	if not cfg_bez["ok"] or not cfg_se["ok"]:
		quit(_verdikt())
		return

	var uo: String = zaklad + "/uo/manifest.json"
	var prefix: String = zaklad + "/uo/"
	var bez = TextureCacheScript.new(uo, 64 * 1024 * 1024, prefix, cfg_bez["layers"])
	var se = TextureCacheScript.new(uo, 64 * 1024 * 1024, prefix, cfg_se["layers"])
	# DRUHA, NEZAVISLA cache pro determinismus (kdyby se stav "pamatovalo" v cache,
	# dva seznamy z TEHOZ objektu by shodu dokazat nemohly).
	var se2 = TextureCacheScript.new(uo, 64 * 1024 * 1024, prefix, cfg_se["layers"])
	if not _cekej(bez, LAND) or not _cekej(se, LAND) or not _cekej(se2, LAND):
		_chyba("fixture: textura %d se nenacetla ani po cekani - merilo by se prazdno" % LAND)
		quit(_verdikt())
		return

	# --- 1) SEZNAM: 20x20 jednoho id, bez skupin a se skupinami --------------
	var seznam_bez: Array = _seznam(bez)
	var seznam_se: Array = _seznam(se)
	var m_bez: Dictionary = _podil(seznam_bez, GRID, 1)
	var m_se: Dictionary = _podil(seznam_se, GRID, 1)
	# KONTROLA PERIODY: naivni hash (`x*HASH_X ^ y*HASH_Y`) ma
	# `index(x + n, y) == index(x, y)` ve 100 % pripadu - vzor by se opakoval
	# presne kazdych `n` bunek. Meri se proto i lag = pocet variant.
	var m_se_perioda: Dictionary = _podil(seznam_se, GRID, VARIANTS)
	var m_bez_perioda: Dictionary = _podil(seznam_bez, GRID, VARIANTS)
	_f("n1_v_seznamu", int(m_bez["landu"]))
	_f("n1_ruznych", int(m_bez["ruznych"]))
	_f("n1_lag1_pct", "%.2f" % float(m_bez["podil"]))
	_f("n1_lagN_pct", "%.2f" % float(m_bez_perioda["podil"]))
	_f("n16_v_seznamu", int(m_se["landu"]))
	_f("n16_ruznych", int(m_se["ruznych"]))
	_f("n16_lag1_pct", "%.2f" % float(m_se["podil"]))
	_f("n16_lagN_pct", "%.2f" % float(m_se_perioda["podil"]))
	if int(m_bez["landu"]) != GRID * GRID or int(m_se["landu"]) != GRID * GRID:
		_chyba("fixture: seznam nema %d land dlazdic (bez %d, se %d)"
			% [GRID * GRID, int(m_bez["landu"]), int(m_se["landu"])])

	# --- 2) DETERMINISMUS: dva nezavisle behy daji stejny sha256 --------------
	var sha_a: String = _sha(seznam_se)
	var sha_b: String = _sha(_seznam(se2))
	_f("sha_a", sha_a)
	_f("sha_b", sha_b)
	_f("determinismus", 1 if sha_a == sha_b else 0)

	# --- 3) OFFSET I TEXTURA ZE STEJNEHO ZAZNAMU ------------------------------
	var stejny: int = 1
	var lisi_od_puvodniho: int = 0
	var offsety: Dictionary = {}
	var textur_null: int = 0
	for y in GRID:
		for x in GRID:
			var vybrany: int = se.variant_id(LAND, x, y)
			var off: Vector2i = se.offset_variant(LAND, x, y)
			offsety[off] = true
			if off != se.offset(vybrany):
				stejny = 0
			if off != se.offset(LAND):
				lisi_od_puvodniho += 1
			var tex: Texture2D = se.texture_variant(LAND, x, y)
			if tex == null:
				textur_null += 1
			elif tex.region != se.texture(vybrany).region:
				stejny = 0
	_f("offset_ze_stejneho", stejny)
	_f("offset_ruznych", offsety.size())
	_f("offset_mimo_puvodni", lisi_od_puvodniho)
	_f("textur_null", textur_null)
	_f("bez_skupin_id", 1 if bez.variant_id(LAND, 3, 4) == LAND
		and bez.texture_variant(LAND, 3, 4).region == bez.texture(LAND).region else 0)
	_f("mimo_skupinu", 1 if se.variant_id(MIMO, 3, 4) == MIMO
		and se.offset_variant(MIMO, 3, 4) == se.offset(MIMO) else 0)
	var rozsah: int = 1
	for y in 40:
		for x in 40:
			for n in [2, 3, 16]:
				var i: int = se.variant_index(x, y, n)
				if i < 0 or i >= n:
					rozsah = 0
	_f("variant_index_rozsah", rozsah)

	# --- 4) DAVKA (`render/chunk_mesh`) ma STEJNE varianty jako seznam --------
	var mesh_n1 = MeshScript.new(ChunkScript.new(FakeMap.new(), bez, FakeTiledata.new()), bez)
	mesh_n1.build(seznam_bez)
	var mesh_n16 = MeshScript.new(ChunkScript.new(FakeMap.new(), se, FakeTiledata.new()), se)
	mesh_n16.build(seznam_se)
	var slotu_n1: int = int(mesh_n1.stats().get("slotu", -1))
	var slotu_n16: int = int(mesh_n16.stats().get("slotu", -1))
	# Slot `BILY` (bily texel pro diru) je v atlase vzdy, proto se odcita 1.
	_f("mesh_slotu_n1", slotu_n1 - 1)
	_f("mesh_slotu_n16", slotu_n16 - 1)
	_f("mesh_pretek_n16", 1 if bool(mesh_n16.stats().get("pretek", true)) else 0)

	# --- 5) STATS: pocet skupin a clenu --------------------------------------
	_f("stats_bez_groups", int(bez.stats()["variants"]["groups"]))
	_f("stats_bez_members", int(bez.stats()["variants"]["members"]))
	_f("stats_se_groups", int(se.stats()["variants"]["groups"]))
	_f("stats_se_members", int(se.stats()["variants"]["members"]))

	quit(_verdikt())


func _verdikt() -> int:
	if _selhalo > 0:
		print("[variants] sonda konci s chybou (%d)" % _selhalo)
		return 1
	print("[variants] sonda dobehla")
	return 0


func _seznam(cache) -> Array:
	# Kreslici seznam pro 20x20 oblasti JEDNOHO land id (presne to, co dostane
	# kreslici uzel i davka).
	var chunk = ChunkScript.new(FakeMap.new(), cache, FakeTiledata.new())
	return chunk.visible(Vector2i(GRID / 2, GRID / 2), GRID, GRID)


func _podil(seznam: Array, grid: int, lag: int = 1) -> Dictionary:
	# Podil dlazdic, ktere maji STEJNY `art_id` jako soused vzdaleny `lag` bunek,
	# a pocet RUZNYCH spritu v oblasti. Pocita se z `art_id` ve seznamu, tedy
	# z toho, co se opravdu kresli. `lag = pocet variant` odhali periodu
	# zarovnanou s mrizkou (viz hlavicka).
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
			if mrizka.has(Vector2i(x + lag, y)):
				celkem += 1
				if int(mrizka[Vector2i(x + lag, y)]) == a:
					shoda += 1
	return {"landu": mrizka.size(), "shoda": shoda, "celkem": celkem,
		"ruznych": ruzne.size(),
		"podil": 100.0 * float(shoda) / float(maxi(celkem, 1))}


func _sha(seznam: Array) -> String:
	# sha256 poradi variant v SEZNAMU (serazene podle y,x - poradi seznamu je
	# dane `render.sort` a muze se zmenit, ale varianta bunky ne).
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var mrizka: Dictionary = {}
	for obj in seznam:
		if str(obj["kind"]) == "land":
			mrizka[Vector2i(int(obj["x"]), int(obj["y"]))] = int(obj["art_id"])
	var klice: Array = mrizka.keys()
	klice.sort_custom(func(a, b): return (a.y * 100000 + a.x) < (b.y * 100000 + b.x))
	for k in klice:
		ctx.update(("%d;%d;%d\n" % [k.x, k.y, int(mrizka[k])]).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _cekej(cache, art: int) -> bool:
	# Stranky atlasu se mohou nacitat NA POZADI (`load_threaded_request`).
	# Sonda proto na prvni texturu pocka - "nenacteno" neni "vada variant".
	var tex: Texture2D = cache.texture(art)
	var i: int = 0
	while tex == null and i < 300:
		OS.delay_msec(10)
		cache.tick_nacteni()
		tex = cache.texture(art)
		i += 1
	return tex != null


func _vyrob_fixture() -> String:
	# Fixture: 16 dlazdic 8x8 px v jedne strance, kazda s JINYM offsetem
	# (ox = i, oy = -i) - jen tak se da dokazat, ze offset jde z VYBRANEHO
	# zaznamu a ne z puvodniho id.
	var zaklad := ProjectSettings.globalize_path(SLUZKA)
	DirAccess.make_dir_recursive_absolute(zaklad + "/own")
	DirAccess.make_dir_recursive_absolute(zaklad + "/uo")
	_uloz_png(zaklad + "/own/own0.png", 128, 128, Color(0.9, 0.2, 0.1, 1.0))
	_uloz_png(zaklad + "/uo/uo0.png", 16, 16, Color(0.1, 0.4, 0.9, 1.0))

	var ids: Array = []
	var sprity: Array = []
	for i in VARIANTS:
		ids.append(LAND + i)
		sprity.append({"kind": "land", "id": LAND + i, "page": "own0.png",
			"x": 8 * i, "y": 0, "w": 8, "h": 8, "ox": i, "oy": -i})
	_zapis(zaklad + "/own/manifest.json", JSON.stringify({"sprites": sprity}))
	_zapis(zaklad + "/uo/manifest.json", JSON.stringify({"sprites": [
		{"kind": "land", "id": LAND, "page": "uo0.png", "x": 0, "y": 0,
			"w": 8, "h": 8, "ox": 0, "oy": 0},
		{"kind": "land", "id": MIMO, "page": "uo0.png", "x": 8, "y": 0,
			"w": 8, "h": 8, "ox": 0, "oy": 0},
	]}))
	var vrstva: Dictionary = {"name": "nase", "manifest": zaklad + "/own/manifest.json",
		"sprites": {"land": ids}}
	_zapis(zaklad + "/bez.json", JSON.stringify({"version": 1, "layers": [vrstva]}))
	var se: Dictionary = vrstva.duplicate(true)
	se["groups"] = {"land": [ids]}
	_zapis(zaklad + "/se.json", JSON.stringify({"version": 1, "layers": [se]}))
	return zaklad


func _uloz_png(cesta: String, w: int, h: int, barva: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(barva)
	img.save_png(cesta)


func _zapis(cesta: String, text: String) -> void:
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	f.store_string(text)
	f.close()
