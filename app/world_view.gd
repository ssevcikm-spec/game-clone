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

const VIEW_TILES_X: int = 64
const VIEW_TILES_Y: int = 48
# PRESTAVBA SEZNAMU SE ODDALUJE (namEReno 2026-10-07): `render.chunk.visible()`
# stoji studeny ~44 ms (6 000 objektu) a puvodne se prestavoval pri KAZDEM kroku
# chuze (`look_at_tile` -> `invalidate`), tedy 2,5x za sekundu -> uzivatel to
# vidi jako seknuti. Seznam se proto stavi pro `_list_center` a prestavi se,
# az kdyz se hrac vzdali o `RECENTER_TILES` dlazdic; okno je o tolik vetsi,
# aby obrazovka zustala pokryta. Vykresluje se z nej jen to, co je videt
# (orezavani v `_draw`), takze vetsi okno neznamena vic draw callu.
const RECENTER_TILES: int = 4
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
var _anim = null
var _sort = null                   # render.sort (jedina funkce razeni)
var _hues = null                   # render.hue (barva kuze; bez nej je postava seda)
var _hue_cache_hit: bool = false   # tonovany sprite se pocita jen pri zmene
var _hue_last: Texture2D = null    # posledni prebarveny zaklad
var _hue_last_hued: Texture2D = null
var _hlasene_diry: Dictionary = {} # art id, o kterych uz bylo hlaseno, ze chybi
var _list_center: Vector2i = Vector2i(-99999, -99999)   # stred postaveneho seznamu


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


func set_action(action: int) -> void:
	_action = action


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


func look_at_tile(tile: Vector2i, z: int = 0) -> void:
	# `z` je VSTUP, ne konstanta: `iso.to_screen` odecita `z * Z_SCALE`, takze
	# kamera na `z = 0` postavi hrace stojiciho na `z = 10` o 40 px nad stred
	# obrazovky (namEReno 2026-10-06 prvnim snimkem s hracem). Kdo kameru
	# posouva, musi dat vysku, na ktere postava stoji.
	center_tile = tile
	if _camera != null:
		_camera.position = _iso.to_screen(tile.x, tile.y, z) \
			+ Vector2(Const.ISO_STEP, Const.TILE_H / 2)
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
	if _list_center.x < -9999 \
			or absi(center_tile.x - _list_center.x) >= RECENTER_TILES \
			or absi(center_tile.y - _list_center.y) >= RECENTER_TILES:
		_list_center = center_tile
	return _chunk.visible(_list_center, VIEW_TILES_X + 2 * RECENTER_TILES,
		VIEW_TILES_Y + 2 * RECENTER_TILES)


func _draw() -> void:
	if _textures == null:
		return
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
	var out: Array = _hlasene_diry.keys()
	out.sort()
	return out


func is_slope(obj: Dictionary) -> bool:
	# ROZHODNUTI o svahu (bez kresleni - proto se da merit testem): dlazdice ma
	# texmap, jeho textura existuje a nektery roh ma jinou vysku nez dlazdice.
	# Presne tak rozhoduje klient (`IsStretched`, ClassicUO `Land.cs:98-161`);
	# rovna plocha se kresli land artem.
	var texmap_id: int = int(obj.get("texmap", 0))
	if texmap_id <= 0:
		return false
	var body: PackedVector2Array = slope_polygon(obj, Vector2.ZERO)
	if body.is_empty():
		return false                       # rovna plocha -> land art
	return _textures.texmap(texmap_id) != null


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
	# Ctyrrohy SVAHU v poradi horni, pravy, dolni, levy (konvexni poradi -
	# dulezite pro triangulaci v `draw_polygon`). Vyska kazdeho rohu je vyska
	# SOUSEDNI dlazdice: pravy = vychodni, levy = jizni, dolni = jihovychodni
	# (ClassicUO `Land.cs:113-121`). Rovna plocha vraci PRAZDNE pole - kresleni
	# pak zustane u land artu, presne jako `IsStretched == false` v klientu.
	var rohy: Array = obj.get("z_corners", [])
	if rohy.size() != 4:
		return PackedVector2Array()
	var z: int = int(obj["z"])
	var z_pravy: int = int(rohy[1])
	var z_levy: int = int(rohy[2])
	var z_dolni: int = int(rohy[3])
	if z == z_pravy and z == z_levy and z == z_dolni:
		return PackedVector2Array()
	var krok: float = float(Const.ISO_STEP)
	var zs: float = float(Const.Z_SCALE)
	return PackedVector2Array([
		pos + Vector2(krok, 0.0),
		pos + Vector2(2.0 * krok, krok + float(z - z_pravy) * zs),
		pos + Vector2(krok, 2.0 * krok + float(z - z_dolni) * zs),
		pos + Vector2(0.0, krok + float(z - z_levy) * zs)])


static func slope_uv() -> PackedVector2Array:
	# UV rohu v texture (0..1): horni (0.5, 0), pravy (1, 0.5), dolni (0.5, 1),
	# levy (0, 0.5) - stejne jako `_cornerOffsetX/Y` v ClassicUO (`Batcher2D.cs:263`).
	return PackedVector2Array([
		Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)])


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
	var clip: Dictionary = _anim.play(int(_player.serial), _action, int(_player.dir))
	if not bool(clip.get("ok", false)) or clip.get("texture") == null:
		player_missing = true
		return
	player_missing = false
	drawn += 1
	var anchor: Vector2 = clip["anchor"]
	var ground: Vector2 = _iso.to_screen(_player.pos.x, _player.pos.y, _player.pos.z) \
		+ Vector2(Const.ISO_STEP, Const.TILE_H / 2)
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
