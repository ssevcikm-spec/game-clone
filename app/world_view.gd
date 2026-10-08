extends Node2D
# Kreslici uzel sveta: JEDINE misto, kde se seznam z `render.chunk` meni na
# pixely (docs/02 §2.4). Kresli se v poradi ze `render.sort` (painter's
# algorithm) - `z_index` na to nejde pouzit (docs/02 past P21).
#
# NEMA GRANULI ANI VLASTNIKA v .forge/roadmap.json. Presne to pojmenovava
# ZADANI-DALSI-VYVOJ §3 úkol 5 (`app/player_controller.gd` = kamera +
# `queue_redraw`) a vada zadani "app/main.tscn nemá vlastníka". Je to tedy
# VADA ZADANI, ne hotova granule - agent roadmapu needituje.
#
# Kamera: stred obrazovky je stred dlazdice. `core.iso.to_screen` vraci HORNI
# VRCHOL diamantu (x-y, x+y), takze se k nemu pricte pulka dlazdice.
#
# POSTAVA (2026-10-06): mobil se kresli mezi statiky podle PORADI jako
# `render.sort`: vsechno s `x + y <=` pozice hrace je pred nim, zbytek za nim.
# Je to presne to, co dela klice `render.sort` (v ramci jedne diagonaly jdou
# mobilove za statiky), ale bez plneho trideni kazdy frame - seznam statiku je
# jiz setrideny z `render.chunk` a tridit ~3000 objektu v GDScriptu 60x za
# sekundu by bylo pomale. Nalezeno pri implementaci, patri do docs/02 §2.4.

const Iso = preload("res://core/iso.gd")
const Chunk = preload("res://render/chunk_renderer.gd")
const Const = preload("res://core/const.gd")
const Anim = preload("res://render/anim_player.gd")
const Hue = preload("res://render/hue_cache.gd")
const Sort = preload("res://render/sort.gd")
const TiledataScript = preload("res://sim/world/tiledata.gd")
# M9 (15. session): davkove kresleni - cely pohled jako JEDEN mesh (1-2 draw
# cally misto tisice). Kdyz se runtime atlas naplni, `_mesh` to NAHLASI a kresli
# se puvodni cestou (ticha degradace by byla horsi nez pomale kresleni).
const MeshScript = preload("res://render/chunk_mesh.gd")

const VIEW_TILES_X: int = 64
const VIEW_TILES_Y: int = 48
# PRESTAVBA SEZNAMU SE ODDALUJE (namEReno 2026-10-07): `render.chunk.visible()`
# stoji studeny ~44 ms (6 000 objektu) a puvodne se prestavoval pri KAZDEM kroku
# chuze (`look_at_tile` -> `invalidate`), tedy 2,5x za sekundu -> uzivatel to
# vidi jako seknuti. Seznam se proto stavi pro `_list_center` a prestavi se,
# az kdyz se hrac vzdali o `RECENTER_TILES` dlazdic; okno je o tolik vetsi,
# aby obrazovka zustala pokryta. Vykresluje se z nej jen to, co je videt
# (orezavani v `_draw`), takze vetsi okno neznamena vic draw callu.
#
# ⚠⚠ 17. session (2026-10-08) - UZIVATEL: "pri plynulem pohybu nastane po
# 4 krocich pauza a pak se jde dal". NAMERENO (`_analyza/p20-kadence.gd`):
# prestavba seznamu stoji **85-98 ms** a `RECENTER_TILES = 4` ji spousti PRESNE
# po 4 krocich (krok = 1 dlazdice) - tedy petkrat za sekundu. Rozpad ceny
# (7 872 objektu): `z_grid` 10-15 ms, land 26-31 ms, statiky 27-33 ms,
# razeni 21-25 ms. Proto je dnes margin VETSI a odvozuje se od obrazovky
# (`_list_okraj`): prestavba se deje ~5x mene casto. Cena jednoho okna roste
# jen mirne (okno obsahuje porad jen to, co muze byt videt).
const RECENTER_TILES: int = 8
const BRITAIN := Vector2i(1495, 1630)
# Land id <= 2 UO VUBEC nekresli (ClassicUO `Land.Create`:
# `AllowedToDraw = graphic > 2`; id 0 = "UNUSED", 1 = "VOID!!!!!!", 2 = "NODRAW").
# NamEReno na mape: 736 dlazdic z 29 360 128 je id <= 2 (2 = NODRAW 727x) - kdyby
# se kreslily, hrala by roli nahodna grafika archivu.
const VOID_LAND_MAX: int = 2
# Okraj, o ktery se rozsiruje obdelnik obrazovky pri OREZAVANI (px): statiky
# maji arty vysoke pres 100 px a natazene svahy az (rozsah z) * Z_SCALE px.
const CULL_MARGIN: float = 256.0
# Chybejici art se kresli VYRAZNE (magenta), ne tise preskoci - vada 61 z 5.
# session: "chybejici art se kresli jako TICHO". Dira v mape ma byt videt na
# prvni pohled, ne se schovat za barvu pozadi.
const HOLE_COLOR := Color(1.0, 0.0, 1.0, 0.85)

var center_tile: Vector2i = BRITAIN
var drawn: int = 0                 # kolik objektu se naposledy kreslilo
var slopes: int = 0                # kolik z toho bylo svahu (texmap pres rohy)
var holes: int = 0                 # kolik objektu melo CHYBEJICI art (magenta)
var nodraw: int = 0                # kolik land dlazdic je id <= 2 (UO je nekresli)
var player_drawn: bool = false     # kreslila se naposledy postava?
var player_missing: bool = false   # postava je, ale nema sprite (vada, ne ticho)

var _iso
var _chunk = null
var _textures = null
var _tiledata = null               # world.tiledata: TexID pro texturu svahu
var _camera: Camera2D = null
var _player = null
var _action: int = 4               # 4 = idle (viz app/player_controller.gd)
var _view_dir: int = 0             # smer KRESLENI postavy (viz `set_view_dir`)
var _anim = null
var _sort = null                   # render.sort (jedina funkce razeni)
var _hues = null                   # render.hue (barva kuze; bez nej je postava seda)
var _hue_cache_hit: bool = false   # tonovany sprite se pocita jen pri zmene
var _hue_last: Texture2D = null    # posledni prebarveny zaklad
var _hue_last_hued: Texture2D = null
var _hlasene_diry: Dictionary = {} # art id, o kterych uz bylo hlaseno, ze chybi
var _list_center: Vector2i = Vector2i(-99999, -99999)   # stred postaveneho seznamu
var _player_offset: Vector2 = Vector2.ZERO  # posun postavy mezi dlazdicemi (V2)
var _mesh = null                   # render.chunk_mesh (M9) - null = puvodni cesta
var _mesh_seznam: Array = []       # seznam, pro ktery je mesh postaveny
var _mesh_diagonala: int = -2147483647
var _mesh_stats: Dictionary = {}
var _mesh_pretek_hlasen: bool = false
# VYCHOZI CESTA JE MESH (M9). Vypina se jen pro mereni parity a pro pripad, ze
# se runtime atlas naplni - obe cesty musi umet to same (docs/08: modernizace
# nesmi ubrat zadne mereni).
var mesh_enabled: bool = true


func _ready() -> void:
	_iso = Iso.new()
	_anim = Anim.new()
	_sort = Sort.new()
	_hues = Hue.new()
	_camera = get_parent().get_node_or_null("Camera") as Camera2D
	if _camera == null:
		push_warning("app.world_view: ve scene chybi uzel Camera - svet bude mimo obrazovku")
	if not _anim.available():
		push_warning("app.world_view: animace tela nejsou (chybi assets/uo/anim) - "
			+ "postava se nevykresli, mapa ano")
	if not _hues.available():
		push_warning("app.world_view: barvy (hues.json) nejsou - postava zustane seda, "
			+ "spust `python tools/uoextract/hues.py --install \"<UO>\"`")


func setup(map, textures) -> void:
	# Vola `app.main` po nacteni dat; do te doby se nekresli (a je to videt).
	_textures = textures
	# `world.tiledata` je potreba pro `TexID` (textura svahu) - bez nej by se
	# svah kreslil jako rovna plocha a zustala by v nem dira.
	_tiledata = TiledataScript.new()
	_chunk = Chunk.new(map, textures, _tiledata)
	# M9: davka se stavi nad HOTOVYM seznamem z `render.chunk` (stejna data,
	# stejne poradi) - `look_at_tile` ho necha postavit. `self` je rodic pro
	# `SubViewport`, ve kterem se sklada runtime atlas (na GPU, bez kopii).
	_mesh = MeshScript.new(_chunk, textures, MeshScript.PAGE_SIZE, self)
	look_at_tile(center_tile)


func set_registry(registry) -> void:
	# `render.anim` si z registru bere CISLO TELA pro serial (granule
	# `sim.entity_registry`); registr zaklada `app.main` (integraci misto).
	# Do 2026-10-06 bral `play()` `serial` jako telo - dnes je to jen fallback
	# pro klienta bez registru.
	_anim = Anim.new(Anim.MANIFEST_PATH, registry)


func set_player(mobile) -> void:
	_player = mobile
	player_missing = false
	# Start smeru kresleni = smer, ve kterem mobil stoji (jinak by prvni frame
	# po spusteni kreslil smer 0).
	if _player != null:
		_view_dir = ((int(_player.dir) % 8) + 8) % 8


func set_action(action: int) -> void:
	_action = action


func set_view_dir(dir: int) -> void:
	# SMER KRESLENI POSTAVY (17. session, 2026-10-08): `mob.dir` zapisuje
	# `sim.movement.apply_step` az na KONCI kroku (400 ms), takze se pri zmene
	# smeru uprostred kroku kreslil jeste stary smer ("postava klouze do
	# strany"). Klient posila smer ZAMERU hned (`app/player_controller._view_dir`
	# ve `update_step`); tady se jen pouzije pri kresleni.
	_view_dir = ((dir % 8) + 8) % 8


func set_player_offset(offset: Vector2) -> void:
	# POSUN POSTAVY MEZI DLAZDICEMI (vada V2): dokud krok neni commitnuty,
	# `player.pos` je porad stara dlazdice a obraz se posune timhle vektorem
	# (`app/player_controller.player_pixel_offset`). Svet se hybe po
	# dlazdicich (kamera v `look_at_tile`), postava plynule - jako v reference
	# (`_src/classicuo` `Mobile.cs:776-782` kresli `Offset`, `:836-844`
	# commitne dlazdici az na konci kroku).
	_player_offset = offset


func player_ground_position() -> Vector2:
	# KAM SE KRESLI POSTAVA (bez kresleni - da se merit testem i sondou).
	# Je to stred dlazdice, na ktere postava stoji, plus posun kroku.
	if _player == null:
		return Vector2.ZERO
	if _iso == null:
		_iso = Iso.new()          # testy tvori uzel bez `_ready()` (N8)
	return _iso.to_screen(int(_player.pos.x), int(_player.pos.y), int(_player.pos.z)) \
		+ Vector2(Const.ISO_STEP, Const.TILE_H / 2) + _player_offset


func anim_available() -> bool:
	return _anim != null and _anim.available()


func hue_available() -> bool:
	return _hues != null and _hues.available()


func hue_stats() -> Dictionary:
	return _hues.stats() if _hues != null else {}


func player_hue(base: Texture2D, hue: int) -> Texture2D:
	# Barva kuze/obleceni (granule `render.hue`). Sada barvy se pocita JEN PRI
	# ZMENE (frame nebo hue) - `render.hue` ma vlastni cache, ale i ta se musi
	# ptat jen jednou za frame; pri 60 fps by jinak kazdy frame proslo
	# `hued()` a hashovalo pixely.
	if base == null or hue == 0:
		return base
	if _hues == null or not _hues.available():
		return base
	if _hue_cache_hit and _hue_last != null and is_same(_hue_last, base):
		return _hue_last_hued
	_hue_last = base
	_hue_last_hued = _hues.hued(base, hue)
	_hue_cache_hit = true
	return _hue_last_hued


func look_at_tile(tile: Vector2i, z: int = 0, offset: Vector2 = Vector2.ZERO) -> void:
	# `z` je VSTUP, ne konstanta: `iso.to_screen` odecita `z * Z_SCALE`, takze
	# kamera na `z = 0` postavi hrace stojiciho na `z = 10` o 40 px nad stred
	# obrazovky (namEReno 2026-10-06 prvnim snimkem s hracem). Kdo kameru
	# posouva, musi dat vysku, na ktere postava stoji.
	#
	# ⚠⚠ `offset` (17. session, 2026-10-08) - VADA "OBRAZ SE POHYBUJE SKOKOVE":
	#   Do teto session se stred kamery prepsal JEN pri zmene dlazdice
	#   (`app/player_controller._follow`), takze obraz stal a pak skocil o CELOU
	#   dlazdici (namEReno 44,00 px na frame; sonda `_analyza/p20-kadence.gd`).
	#   Postava se pritom posouvala plynule (`player_pixel_offset`), takze
	#   postava a svet se rozesly. Reference (`_src/classicuo` `Mobile.cs:776-782`)
	#   drzi hrace ve stredu a posouva SVET: kamera proto dostava stejny posun
	#   v pixelech jako postava a svet se valí plynule, po 80ms framech.
	center_tile = tile
	if _camera != null:
		_camera.position = _iso.to_screen(tile.x, tile.y, z) \
			+ Vector2(Const.ISO_STEP, Const.TILE_H / 2) + offset
	# POZOR: seznam se tady NEZAHOZUJE. `render.chunk` si ho prestavi sam, kdyz
	# se zmeni stred (viz `_list` a RECENTER_TILES) - zahozeni pri kazdem kroku
	# bylo namERene seknuti (44 ms x 2,5 za sekundu).
	queue_redraw()


func visible_count() -> int:
	return _list().size()


func counts() -> Dictionary:
	return _chunk.counts() if _chunk != null else {}


func _list() -> Array:
	if _chunk == null:
		return []
	# Seznam plati pro `_list_center` (viz RECENTER_TILES v hlavicce): kdyz se
	# hrac vzdali, stred se posune a `render.chunk` seznam prestavi (cache
	# `render.chunk` se ptá na `cover`, takze staci zmenit stred).
	# ⚠ P20 (17. session): seznam se stavi pro `_list_center` a prestavi se, az
	# kdyz se hrac vzdali o `RECENTER_TILES` dlazdic - na tom stoji oprava vady
	# "po 4 krocich pauza" (viz hlavicka). Mereni: `_analyza/p20-kadence.gd`.
	if _list_center.x < -9999 \
			or absi(center_tile.x - _list_center.x) >= RECENTER_TILES \
			or absi(center_tile.y - _list_center.y) >= RECENTER_TILES:
		_list_center = center_tile
	var okraj := _list_okraj()
	return _chunk.visible(_list_center, okraj.x, okraj.y)


func _list_okraj() -> Vector2i:
	# VELIKOST OKNA pro seznam objektu. Neni to konstanta: musi pokryt obrazovku
	# pro KAZDOU pozici kamery, kterou pripousti `RECENTER_TILES`. V izometrii
	# zabira obrazovka na osach `a = x - y` a `b = x + y` polovinu sve sirky
	# a vysky (viz `core/iso.gd`), takze polomer v dlazdicich je
	# `(sirka/2 + vyska/2) / ISO_STEP` pro `a` a `(sirka/2 - vyska/2) / ISO_STEP`
	# pro `b`; kazda osa pridava `RECENTER_TILES` (kam se hrac muze vzdalit)
	# a 2 dlazdice rezervy na zaokrouhleni a posun kroku.
	# Kdyz okno obrazovku NEPOKRYJE, `_draw` ji prestane kreslit a vzniknou DIRY.
	var rozmer: Vector2 = get_viewport_rect().size
	if rozmer.x <= 0.0 or rozmer.y <= 0.0:
		# NEMERENO (test bez okna): vrat deklarovane minimum, ne nulu - nula by
		# znamenala "nekresli se nic" a to je horsi nez mensi okno.
		return Vector2i(VIEW_TILES_X, VIEW_TILES_Y)
	var krok: float = float(Const.ISO_STEP)
	var pol_x: int = int(ceil((rozmer.x / 2.0 + rozmer.y / 2.0) / krok)) + 2
	var pol_y: int = int(ceil((rozmer.x / 2.0 - rozmer.y / 2.0) / krok)) + 2
	pol_x = maxi(pol_x, VIEW_TILES_X / 2) + RECENTER_TILES
	pol_y = maxi(pol_y, VIEW_TILES_Y / 2) + RECENTER_TILES
	return Vector2i(2 * pol_x, 2 * pol_y)


# ⚠ P20 MERENI BYLO ODSTRANENO (17. session): docasna pocitadla `p20_*` slouzila
# sondam `_analyza/p20-*.gd`. Cisla jsou v `_analyza/p20-*.txt` a v HANDOFFu;
# kdo chce merit znovu, prida pocitadla zpet (jsou popsana v `_analyza/p20-hlubka.gd`).


func _draw() -> void:
	if _textures == null:
		return
	# M9: nejdriv se zkusi davka (1-2 draw cally). Kdyz neni postavena (runtime
	# atlas se naplnil), kresli se puvodni cestou - obraz musi byt spravny vzdy.
	# POZOR: `_priprav_mesh()` vraci `_mesh.is_built()` - dokud dávka postavena
	# NENI, kresli se puvodni cestou (jinak by se kreslil prazdny mesh = cerno).
	if mesh_enabled and _mesh != null and _priprav_mesh():
		_kresli_mesh()
		return
	_draw_puvodni()


func _draw_puvodni() -> void:
	drawn = 0
	slopes = 0
	holes = 0
	nodraw = 0
	player_drawn = false
	# Postava se vklada do JIZ SETRIDENEHO seznamu. Poradi rozhoduje
	# `render.sort.sort_key` (jedina funkce razeni, docs/04 §4.2) - ne vlastni
	# porovnavani. Aby se `sort_key` nevolal 5 000x za frame, pouzije se jen
	# tam, kde opravdu rozhoduje: na stejne diagonale (`x + y`), protoze
	# pres diagonalu rozhoduje uz ten soucet.
	var klic_hrace: int = 0
	var diagonal: int = 999999
	if _player != null:
		diagonal = int(_player.pos.x) + int(_player.pos.y)
		klic_hrace = _sort_key_of_player()
	# OREZANI MIMO OBRAZOVKU (namEReno 2026-10-07): seznam je
	# (64 + 2*RECENTER) x (48 + 2*RECENTER) dlazdic (4 032 land + ~3 400 statiku),
	# ale obrazovka 1280x720 jich ukazuje zlomek. Godot kresli i to, co je mimo
	# (draw call stoji cas), takze se prvky dal od okna preskakuji. `CULL_MARGIN`
	# je velky zamerne: statiky maji arty vysoke pres 100 px a natazene svahy az
	# (Z rozsah) * Z_SCALE px. NamEReno: 46,6 -> 34,5 ms na frame.
	var okno: Rect2 = _obrazovka(CULL_MARGIN)
	for obj in _list():
		if _player != null and not player_drawn:
			var d: int = int(obj["x"]) + int(obj["y"])
			if d > diagonal or (d == diagonal and _sort.sort_key(obj) > klic_hrace):
				_draw_player()
		var pozice: Vector2 = _chunk.screen_position(obj)
		if not okno.has_point(pozice):
			continue
		var art_id: int = int(obj["art_id"])
		if str(obj["kind"]) == "land" and art_id <= VOID_LAND_MAX:
			nodraw += 1
			continue
		if str(obj["kind"]) == "land" and _draw_slope(obj, pozice):
			drawn += 1
			slopes += 1
			continue
		var art: Texture2D = _textures.texture(art_id)
		if art == null:
			# CHYBEJICI ART NENI TICHO (vada 61): vyrazna magenta + hlaseni
			# (jednou na art id, aby log nezaplavilo 5 000 radku za frame).
			holes += 1
			if not _hlasene_diry.has(art_id):
				_hlasene_diry[art_id] = true
				push_warning("app.world_view: art %d neni v atlase - kresli se magenta" % art_id)
			_draw_hole(obj, pozice)
			continue
		draw_texture(art, pozice)
		drawn += 1
	if _player != null and not player_drawn:
		_draw_player()


func _obrazovka(margin: float) -> Rect2:
	# Obdelnik, ktery se opravdu muze objevit na obrazovce (ve svetovych
	# souradnicich). Bez kamery vraci obdelnik kolem stredu pohledu - pak se
	# neorezava nic, protoze "nevim" nema znamenat "nevykresli se".
	var velikost: Vector2 = get_viewport_rect().size
	var stred := Vector2.ZERO
	if _camera != null:
		stred = _camera.position
	else:
		stred = _iso.to_screen(center_tile.x, center_tile.y, 0)
	var roh: Vector2 = stred - velikost / 2.0 - Vector2(margin, margin)
	return Rect2(roh, velikost + Vector2(2.0 * margin, 2.0 * margin))


func missing_art_ids() -> Array:
	# Ktere art id se v tomto pohledu nekreslily (pro branu/test, ne pro kresleni).
	if _mesh != null and _mesh.is_built():
		return _mesh.missing_art_ids()
	var out: Array = _hlasene_diry.keys()
	out.sort()
	return out


func is_slope(obj: Dictionary) -> bool:
	# ROZHODNUTI o svahu (bez kresleni - proto se da merit testem): pravidlo je
	# od M9 v `render.chunk_mesh.je_svah` (jedno misto pro kresleni i pro dávku,
	# aby se nemohla rozejit). Tady se jen predava dal.
	return MeshScript.je_svah(obj, _textures)


func _diagonala_hrace() -> int:
	if _player == null:
		return -2147483647
	return int(_player.pos.x) + int(_player.pos.y)


func _priprav_mesh() -> bool:
	# Postavi (nebo prekraji) davku pro AKTUALNI seznam a diagonalу hrace.
	# Stavi se jen kdyz se seznam vymenil (`render.chunk` vraci porad TUTEZ
	# instanci, dokud se neprestavi) - ne kazdy frame.
	var seznam: Array = _list()
	return _priprav_mesh_vnitrni(seznam)


func _priprav_mesh_vnitrni(seznam: Array) -> bool:
	var diagonala: int = _diagonala_hrace()
	if _mesh.hold() > 0:
		# Runtime atlas se prave prekresluje na GPU (`UPDATE_ONCE`): do te doby
		# by davka cetla prazdnou texturu, takze se kresli puvodni cestou.
		_mesh.tick_hold()
		_nacti_mesh_stats()
		return false
	if not is_same(seznam, _mesh_seznam):
		_mesh_seznam = seznam
		if not _mesh.build(seznam, diagonala):
			# Runtime atlas se naplnil: NEMLCET a kreslit puvodni cestou.
			if not _mesh_pretek_hlasen:
				_mesh_pretek_hlasen = true
				push_warning("app.world_view: render.chunk_mesh se nevesel do atlasu ("
					+ str(_mesh.stats()) + ") - kresli se puvodni cestou")
			_nacti_mesh_stats()
			return false
		_mesh_diagonala = diagonala
		_mesh.split(diagonala)
		_nacti_mesh_stats()
		return true
	if diagonala != _mesh_diagonala:
		_mesh_diagonala = diagonala
		_mesh.split(diagonala)
		_nacti_mesh_stats()
	# ⚠⚠ 17. session (2026-10-08) - VADA "SVET JE CELY CERNY": tady se do teto
	# session vracelo `true` (tedy "davka je pripravena") i kdyz `build()`
	# SELHAL a nechal `_mesh_pred`/`_mesh_po` na `null` - `_kresli_mesh()` pak
	# nekreslil NIC (jenz pozadi je cerne). NamEReno: rozdil proti puvodni
	# ceste 909 618 px (98,70 %); sonda `_analyza/p20b-pretek-blank.gd`.
	# `_pretek` (atlas se nevesel) je proto TVRDY vypinac: kresli se puvodni
	# cestou, dokud se stranka neprelozi a `is_built()` neplatí.
	return _mesh.is_built()


func _nacti_mesh_stats() -> void:
	# Pocitadla se berou z POSTAVENE davky - jinak by `drawn`/`holes`/`nodraw`
	# tvrdily neco jineho, nez co je na obrazovce (docs/08 §8.6).
	_mesh_stats = _mesh.stats()
	slopes = int(_mesh_stats.get("svahu", 0))
	holes = int(_mesh_stats.get("der", 0))
	nodraw = int(_mesh_stats.get("nodraw", 0))
	drawn = int(_mesh_stats.get("kvadru", 0)) - holes + int(_mesh_stats.get("hranic", 0))
	for art_id in _mesh.missing_art_ids():
		if not _hlasene_diry.has(art_id):
			_hlasene_diry[art_id] = true
			push_warning("app.world_view: art %d neni v atlase - kresli se magenta" % art_id)


func _kresli_mesh() -> void:
	# PORADI: (1) vse s `x + y <=` diagonala hrace, (2) objekty na TEZE
	# diagonale a hrac podle `sort_key`, (3) vse s vetsi diagonalou. Presne
	# to dela puvodni smycka - jen s 1-2 prikazy misto tisice.
	player_drawn = false
	player_missing = false
	var klic_hrace: int = 0
	var hranice: Array = _mesh.hranice()
	var ma_hranici: bool = hranice.size() > 0
	if _player != null or ma_hranici:
		klic_hrace = _sort_key_of_player() if _player != null else 0
	_mesh.draw_before(self)
	if ma_hranici:
		hranice.sort_custom(func(a, b): return int(a["klic"]) < int(b["klic"]))
		for item in hranice:
			if _player != null and not player_drawn and int(item["klic"]) > klic_hrace:
				_draw_player()
			_kresli_hranicni(item)
	_mesh.draw_after(self)
	if _player != null and not player_drawn:
		_draw_player()


func _kresli_hranicni(item: Dictionary) -> void:
	# Objekt na diagonale hrace, ktery se do davky nedal (rozhoduje `sort_key`,
	# ne diagonala) - kresli se jednotlive, protoze je ve vztahu k hraci
	# "pred/po" pokazde jinak.
	var obj: Dictionary = item["obj"]
	var pozice: Vector2 = item["pozice"]
	var art_id: int = int(obj["art_id"])
	var tex: Texture2D = _textures.texture(art_id)
	if tex == null:
		_draw_hole(obj, pozice)
		return
	draw_texture(tex, pozice)


func mesh_stats() -> Dictionary:
	# Mereni pro `app.metrics` (M9): kolik kvadru je v dávce a jak draha byla
	# stavba. Prazdny slovnik = dávka se nepouziva (a je to videt).
	return _mesh_stats.duplicate()


func _draw_slope(obj: Dictionary, pozice: Vector2) -> bool:
	# SVAH: kresli se TEXMAPEM natazenym pres ctyrrohy (ClassicUO `Batcher2D.cs:241`
	# `DrawStretchedLand`). Rozhodnuti je v `is_slope()` - tady uz jen kresleni.
	# ⚠ Zjednoduseni (zapsane, ne zamlcene): ClassicUO pocita jeste NORMALS pro
	# svetlo (`CalculateNormal`) - tady se svah kresli bez srafovani svetlem,
	# protoze `render.light` v projektu jeste neni.
	if not is_slope(obj):
		return false
	var body: PackedVector2Array = slope_polygon(obj, pozice)
	var tex: Texture2D = _textures.texmap(int(obj["texmap"]))
	var barvy := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	draw_polygon(body, barvy, slope_uv(), tex)
	return true


static func slope_polygon(obj: Dictionary, pos: Vector2) -> PackedVector2Array:
	# Geometrie svahu je od M9 v `render.chunk_mesh` (potrebuje ji i dávka);
	# tady se jen predava dal, aby zustala smlouva i testy na tom samem miste.
	return MeshScript.slope_polygon(obj, pos)


static func slope_uv() -> PackedVector2Array:
	# UV rohu v texture (0..1): horni (0.5, 0), pravy (1, 0.5), dolni (0.5, 1),
	# levy (0, 0.5) - stejne jako `_cornerOffsetX/Y` v ClassicUO (`Batcher2D.cs:263`).
	return MeshScript.slope_uv()


func _draw_hole(obj: Dictionary, pozice: Vector2) -> void:
	# Placeholdr chybejiciho artu: land = magenta DIAMANT (44x44 jako dlazdice),
	# statik = magenta ctverec u spodni hrany dlazdice. Neni to "kresba navic":
	# bez nej by dira splynula s pozadim a vadu by nikdo nevidel.
	var krok: float = float(Const.ISO_STEP)
	if str(obj["kind"]) == "land":
		draw_colored_polygon(PackedVector2Array([
			pozice + Vector2(krok, 0.0), pozice + Vector2(2.0 * krok, krok),
			pozice + Vector2(krok, 2.0 * krok), pozice + Vector2(0.0, krok)]), HOLE_COLOR)
		return
	draw_rect(Rect2(pozice + Vector2(krok, 0.0), Vector2(krok, krok)), HOLE_COLOR)


func _sort_key_of_player() -> int:
	# Klid pro `render.sort`: mobil ma vlastni vrstvu (za statiky na teze dlazdici).
	return _sort.sort_key({"kind": "mobile", "x": int(_player.pos.x),
		"y": int(_player.pos.y), "z": int(_player.pos.z)})

func _draw_player() -> void:
	# Vraci se i to, ze se postava NEKRESLILA (`player_missing`) - prazdno se
	# nesmi tvarit jako " hotovo" (docs/08 §8.6).
	player_drawn = false
	if _player == null or _anim == null:
		return
	player_drawn = true
	var clip: Dictionary = _anim.play(int(_player.serial), _action, _view_dir)
	if not bool(clip.get("ok", false)) or clip.get("texture") == null:
		player_missing = true
		return
	player_missing = false
	drawn += 1
	var anchor: Vector2 = clip["anchor"]
	# Pozice vcetne posunu mezi dlazdicemi (V2) - jedna funkce pro kresleni
	# i pro mereni (`player_ground_position`).
	var ground: Vector2 = player_ground_position()
	var texture: Texture2D = clip["texture"]
	texture = player_hue(texture, int(_player.hue))
	if not bool(clip.get("mirror", false)):
		draw_texture(texture, ground - anchor)
		return
	# Zrcadleni: `draw_texture` neumi zaporny scale, proto se otoci rovina
	# kresleni. Levy okraj zrcadleneho spritu je `ground.x - (w - cx)`.
	# Pozor: prebarvena textura je `ImageTexture` (ne `AtlasTexture`) - sirka se
	# proto bere z JEJI velikosti, ne z regionu (region ma jen zaklad).
	var w: float = float(texture.get_width())
	draw_set_transform(Vector2(ground.x - float(clip["mirror_x"]) + w, ground.y - anchor.y),
		0.0, Vector2(-1.0, 1.0))
	draw_texture(texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
