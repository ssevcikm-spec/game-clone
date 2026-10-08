extends RefCounted
# Cache textur z atlasu (granule render.textures; docs/02 §2.7, docs/04 §4.2).
#
# ART ID je prostor, ktery pouziva `world.tiledata` a `tools/uoextract/art.py`:
#   art_id <  0x4000 ... land (v manifestu `kind` "land", `id` = art_id)
#   art_id >= 0x4000 ... item (v manifestu `kind` "item", `id` = art_id - 0x4000)
#   art_id >= 0x10000 .. TEXMAP (`kind` "texmap", `id` = art_id - 0x10000) - textura
#                         terenu pro svahy; pristup je pres `texmap(texmap_id)`
# `world.map.statics_at` vraci `tile` v prostoru ITEM art id (bez +0x4000, tak
# to namERil HANDOFF 2026-10-06: hodnoty 37..4758) - pro statiky se tedy vola
# `texture(tile + 0x4000)`.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `offset(art_id)` - `render.chunk` potrebuje `ox`,`oy` z manifestu, aby
#     statik sedel spodni hranou na dlazdici (vzorec je v hlavicce atlas.py);
#     smlouva uvadi jen `texture()` a `stats()`.
#   * `stats()` vraci navic `missing` a `sprites` - bez `missing` by chybejici
#     art splynul s "textura se nenacetla" (docs/08 §8.6: nula neni uspech).
#
# STRANKA ATLASU JE 2048x2048 RGBA = 16 MB. LRU pocita BAJTY ze SKUTECNYCH
# rozmeru nacteneho obrazku (ne odhadem) a drzi `MAX_BYTES`. `texture()` vraci
# hotove "okno" (`AtlasTexture`) do stranky - a to SAME pro stejne art_id, aby
# se nealokovalo 5 767x za frame (viz VYKON nize). Strankove textury drzi cache;
# kdyz se stranka vyhodi, zahodi se i jeji okna, aby strop platil.
# NamEReno 2026-10-06 (Britain 64x48 dlazdic): land je v 1 strane, statiky ve
# 25 -> strop 384 MB (24 stranek) se v te scene prekroci. Je to VEDOMY
# kompromis: prioritou je spravny obraz, ne FPS; strop je videt ve `stats()`.
#
# ⚠ VYKON, namEReno 2026-10-07 (sonda `.cache/analysis/sonda-fps.gd`):
# `AtlasTexture.new()` na kazde volani `texture()` stalo **0,118 ms**; kreslici
# smycka ji vola pro kazdy objekt kazdy frame (5 767 v Britanii) → **655 ms
# na frame, tedy 1-2 FPS**. Po zavedeni `_wrapped` (hotova okna) je frame
# **22,3 ms = 45 FPS** (vsync vypnuty) a pocet obalenych oken se po nabehu
# ustali (`wrapped 260`, 0 zmen za 300 framu). Zbylych 22 ms je GPU: 1 516
# draw callu a 11 534 primitiv za frame - to je prace pro M9 (`render.chunk_mesh`),
# ne vada teto granule.
#
# Pouziti: `var t = TextureCache.new()`; `t.texture(art_id)`, `t.offset(art_id)`.
# Druhy argument `_init` je strop v bajtech (vychozi `MAX_BYTES`) - je tam
# proto, aby sel strop ZMĚŘIT na malé hodnotě (sonda `.cache/analysis/probe-render.gd`).
# Treti argument `page_prefix` je prefix cest ke strankam z manifestu (vychozi
# `ATLAS_PREFIX`) - je tam proto, aby test mohl postavit VLASTNI atlas mimo
# `assets/uo/` (ta jsou v gitignore, takze v CI nejsou) a nemusel prepisovat
# realny manifest. `null`/prazdny znaci "cesty z manifestu jsou uz kompletni".

const ITEM_OFFSET: int = 0x4000
# TEXMAPY (textury terenu pro SVAHY) jsou treti prostor v manifestu: kind
# "texmap", art_id = id + 0x10000. Je to NAD itemy (0x4000..0xFFFF), takze se
# prostore nepotkaji a `texture()` muze zustat jedina funkce pro vsechny.
const TEXMAP_OFFSET: int = 0x10000
const MANIFEST_PATH := "res://assets/uo/manifest.json"
const ATLAS_PREFIX := "res://assets/uo/"
const MAX_BYTES: int = 402653184   # 384 MB

var _sprites: Dictionary = {}      # art_id -> {page: String, rect: Rect2i, offset: Vector2i}
var _wrapped: Dictionary = {}      # art_id -> AtlasTexture (hotova "okna" do stranky)
var _pages: Dictionary = {}        # page -> Texture2D
var _sizes: Dictionary = {}        # page -> bajty
var _order: Array = []             # LRU, nejnovejsi na konci
var _limit: int = MAX_BYTES        # strop jde zmenit kvuli mereni (sonda)
var _bytes: int = 0
var _missing: int = 0
var _warned: bool = false
var _nacteni_stranek: int = 0      # POCITADLO pro mereni: kolikrat se stranka nacetla z disku
var _prefix: String = ATLAS_PREFIX # prefix cest ke strankam (viz `_init`)
# --- ASYNCHRONNI NACITANI STRANEK (18. session) ---------------------------
# Stranka atlasu je 2048x2048 = 16 MB a jeji nacteni stoji NAMERENE ~58 ms
# (`_analyza/p21-atlas-cena.gd`: 34 stranek = 1982 ms). Kdyz se nacetla uvnitr
# `build()`, byl to ZASEK OBRAZU presne ve chvili, kdy uzivatel v logu videl
# WARNING o `Image.load` - a to je vada, kterou hlasil. Nacteni proto bezi
# NA POZADI pres `ResourceLoader.load_threaded_request` (podporovana cesta
# Godotu; `load()` ve vlastnim vlakne by sahalo na cache bez zamku) a kdo
# stranku jeste nema, dostane `null` + `page_pending(art_id) == true`, takze
# se objekt pro par framu VYNECHA (ne "chybejici art" = magenta).
var _cekajici: Dictionary = {}     # path -> true (nacteni bezi na pozadi)
var _verze: int = 0                # kolik stranek uz dotecelo (volajici podle ni prestavi davku)


func _init(manifest_path: String = MANIFEST_PATH, max_bytes: int = MAX_BYTES,
		page_prefix: String = ATLAS_PREFIX) -> void:
	_limit = max_bytes
	_prefix = page_prefix
	var parsed = _read(manifest_path)
	if parsed is Dictionary:
		for sprite in parsed.get("sprites", []):
			_index(sprite)
	if _sprites.is_empty():
		# Prazdna cache neni uspech: kdo pak kresli, dostane jen `null`.
		push_warning("render.textures: %s nedal zadny pouzitelny sprite" % manifest_path)


func texture(art_id: int) -> Texture2D:
	# ⚠ VYKON (namEReno 2026-10-07): `AtlasTexture.new()` na KAZDE volani stalo
	# 0,118 ms - a kreslici smycka ji vola pro kazdy objekt kazdy frame (5 767
	# objektu v Britanii) = **683 ms/frame, hra jela na 1-2 FPS**. Proto se hotove
	# "okno" do stranky drzi v `_wrapped` a vraci se PORAD TA SAMA instance.
	# Neni to predcasna optimalizace: cislo je zmerene (sonda
	# `.cache/analysis/sonda-fps.gd`), ne odhad.
	var hotova = _wrapped.get(art_id)
	if hotova != null:
		return hotova
	var entry = _sprites.get(art_id)
	if entry == null:
		_missing += 1
		if not _warned:
			_warned = true
			push_warning("render.textures: art %d v manifestu neni (dalsi se nepocitaji)" % art_id)
		return null
	var page := _page(str(entry["page"]))
	if page == null:
		return null
	var out := AtlasTexture.new()
	out.atlas = page
	out.region = Rect2(entry["rect"])
	# POZOR: drzi se i druha reference na STRANKU (v `AtlasTexture`). Kdyby LRU
	# vyhodila stranku z `_pages`, zustane nazivu pres obal - a to je presne to,
	# co smi: obraz je porad spravny a strop se tyka jen stranek v cache.
	_wrapped[art_id] = out
	return out


func offset(art_id: int) -> Vector2i:
	var entry = _sprites.get(art_id)
	return entry["offset"] if entry != null else Vector2i.ZERO


func texmap(texmap_id: int) -> Texture2D:
	# Textura terenu pro SVAH (ClassicUO `TexmapsLoader.GetTexmap`). Vraci null,
	# kdyz zaznam neni - kresleni pak zustane u land artu (ClassicUO `Land.cs:98`).
	if texmap_id <= 0:
		return null
	return texture(texmap_id + TEXMAP_OFFSET)


func stats() -> Dictionary:
	# `loaded` je pocet stranek V PAMETI, `bytes` jejich skutecna velikost.
	# `wrapped` je pocet hotovych oken do stranek - po nabehu se ustali a pak uz
	# `texture()` nealokuje nic (viz VYKON v `texture()`).
	# `nacteni_stranek` je POCITADLO naciteni z disku za cely beh - je tu proto,
	# ze se jím dokazuje, že cache netrhá (27 načtení za běh vs. tisíce při
	# thrashingu); používá to test `tests/cases/render_textures.gd`.
	return {"loaded": _pages.size(), "bytes": _bytes, "limit": _limit,
		"missing": _missing, "sprites": _sprites.size(), "wrapped": _wrapped.size(),
		"nacteni_stranek": _nacteni_stranek, "ceka": _cekajici.size(), "verze": _verze}


func _index(sprite) -> void:
	var kind := str(sprite.get("kind", ""))
	var id := int(sprite.get("id", -1))
	var art_id: int = id if kind == "land" else (id + ITEM_OFFSET if kind == "item"
		else (id + TEXMAP_OFFSET if kind == "texmap" else -1))
	var width := int(sprite.get("w", 0))
	var height := int(sprite.get("h", 0))
	if art_id < 0 or width <= 0 or height <= 0 or _sprites.has(art_id):
		return
	_sprites[art_id] = {
		"page": _prefix + str(sprite.get("page", "")),
		"rect": Rect2i(int(sprite.get("x", 0)), int(sprite.get("y", 0)), width, height),
		"offset": Vector2i(int(sprite.get("ox", 0)), int(sprite.get("oy", 0))),
	}


func _page(path: String) -> Texture2D:
	# ⚠⚠ 18. session (2026-10-08) - VADA Z LOGU UZIVATELE: "periodicky se
	# pri chuzi sekne obraz a podle logu je to ve stejnou chvili, kdy vyskočí
	# WARNING: Loaded resource as image file, this will not work on export".
	# Dve veci se tim opravuji:
	#   1. NACITANI BEZI NA POZADI (`_zadej`), takze frame neblokuje 58 ms.
	#   2. Stranky atlasu MAJI `.import` (77 stranek, `compress/mode=0`
	#      lossless, `mipmaps/generate=false`, `vram_texture=false`), takze se
	#      nacitaji jako RESOURCE - presne ty same pixely a bez WARNINGu.
	#      Kdyz import chybi (fixture v testu, cerstvy strom bez `--import`),
	#      padá se zpet na synchronni `Image.load` (a jeho WARNING je pak
	#      pravdivy: v exportu by to nefungovalo).
	var cached = _pages.get(path)
	if cached != null:
		_touch(path)
		return cached
	if _cekajici.has(path):
		var stav: int = ResourceLoader.load_threaded_get_status(path)
		if stav == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null                     # jeste se nacita - kdo to vidi, vynecha objekt
		_cekajici.erase(path)
		if stav == ResourceLoader.THREAD_LOAD_LOADED:
			var hotova: Texture2D = ResourceLoader.load_threaded_get(path)
			if hotova != null:
				return _zarad(path, hotova)
		# chyba nacteni: zkusit synchronni cestu (a rict to)
		push_warning("render.textures: stranka %s se nenacetla na pozadi - zkousi se synchronne" % path)
	elif ResourceLoader.exists(path):
		var chyba: int = ResourceLoader.load_threaded_request(path)
		if chyba == OK:
			_cekajici[path] = true
			return null
		push_warning("render.textures: stranku %s nelze zadat k nacteni (err %d)" % [path, chyba])
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		push_warning("render.textures: strana %s se necte (err %d)" % [path, err])
		return null
	return _zarad(path, ImageTexture.create_from_image(image))


func _zarad(path: String, page: Texture2D) -> Texture2D:
	# Zaradi hotovou stranku do cache (bajty, LRU) a ZVEDNE `_verze` - volajici
	# (`app/world_view`) podle ni pozna, ze ma prestavet davku, aby se nove arty
	# objevily. Bez toho by se nacetla stranka nikdy neprojevila.
	_nacteni_stranek += 1
	var size: int = page.get_width() * page.get_height() * 4
	_pages[path] = page
	_sizes[path] = size
	_bytes += size
	_touch(path)
	_evict()
	_verze += 1
	return page


func page_pending(art_id: int) -> bool:
	# Ceka se na stranku tohoto artu? ("nenacteno" NENI "chybi" - kdo to plete,
	# kresli magenta diry misto toho, aby pockal par framu.)
	var entry = _sprites.get(art_id)
	if entry == null:
		return false
	var path: String = str(entry["page"])
	return _cekajici.has(path) or (not _pages.has(path) and ResourceLoader.exists(path))


func tick_nacteni() -> int:
	# ⚠ 18. session: HOTOVE STRANKY SE MUSI VYZVEDNOUT I BEZ DOTAZU NA ART.
	# `load_threaded_request` se sice vyrizuje na pozadi, ale hotovy vysledek
	# nekdo musi prevzit (`load_threaded_get`). Kdyz se prevzeti delalo jen
	# uvnitr `texture()`, vznikl KRUH: stranka se nacitala -> `texture()` vratil
	# null -> objekt se vynechal -> prestavba se odlozila (ceka se na
	# `pending() == 0`) -> `texture()` se uz nezavolalo -> stranka zustala
	# "ceka" NAVZDY a objekty se neobjevily (namEReno: `ceka: 6` na konci
	# chuze, 1 295 objektu vynechanych). Tahle funkce se vola kazdy frame.
	# Vraci pocet prave prevzatych stranek.
	if _cekajici.is_empty():
		return 0
	var hotovo: int = 0
	for path in _cekajici.keys():
		var stav: int = ResourceLoader.load_threaded_get_status(path)
		if stav == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_cekajici.erase(path)
		if stav != ResourceLoader.THREAD_LOAD_LOADED:
			push_warning("render.textures: stranka %s se nenacetla na pozadi" % path)
			continue
		var tex: Texture2D = ResourceLoader.load_threaded_get(path)
		if tex != null:
			_zarad(path, tex)
			hotovo += 1
	return hotovo


func pending() -> int:
	# Kolik stranek se prave nacita (0 = vse, co je potreba, je v pameti).
	return _cekajici.size()


func verze() -> int:
	# Pocet dotecenych stranek za cely beh - roste, kdyz neco doslo.
	return _verze


func _touch(path: String) -> void:
	_order.erase(path)
	_order.append(path)


func _evict() -> void:
	# Vyhazuje se od NEJSTARSI stranky; prave nactena je na konci, takze se
	# nikdy nevyhodi. Textura, kterou drzi volajici, stranku prezije do konce
	# frame - proto muze byt pamet o jednu stranku vyssi, nez je strop.
	while _bytes > _limit and _order.size() > 1:
		var oldest: String = _order[0]
		_order.pop_front()
		_bytes -= int(_sizes.get(oldest, 0))
		_sizes.erase(oldest)
		# ⚠ ZAMERNE SE TU NEMAZOU OKNA (`_wrapped`) - je to namERene rozhodnuti,
		# ne opomenuti. Kdyz se mazala (zkouseno 2026-10-07), prisel **thrashing**:
		# britanska scena potrebuje 27 stranek, strop dovoli 24, takze se 3 stranky
		# vyhazely a znovu nacitaly KAZDY frame → 1 230 ms/frame (1 FPS) misto
		# 22 ms. Dusledek, ktery se nesmi zatajit: okna drzi referenci na stranku,
		# takze SKUTECNA pamet muze byt vyssi nez `MAX_BYTES` (zmereno: 27 stranek
		# = 432 MB pri stropu 384 MB). Strop tedy plati pro stranky V CACHE, ne pro
		# celkovou pamet. Kdo chce tvrdy strop, at zvysi `MAX_BYTES` nad pracovni
		# sadu sceny (27 stranek = 432 MB), nebo zmensi velikost stranky atlasu.
		_pages.erase(oldest)


func _read(path: String):
	if not FileAccess.file_exists(path):
		push_warning("render.textures: chybi " + path
			+ " - spust `python tools/uoextract/atlas.py --out assets/uo`")
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
