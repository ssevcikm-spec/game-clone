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

const VIEW_TILES_X: int = 64
const VIEW_TILES_Y: int = 48
const BRITAIN := Vector2i(1495, 1630)

var center_tile: Vector2i = BRITAIN
var drawn: int = 0                 # kolik objektu se naposledy kreslilo
var player_drawn: bool = false     # kreslila se naposledy postava?
var player_missing: bool = false   # postava je, ale nema sprite (vada, ne ticho)

var _iso
var _chunk = null
var _textures = null
var _camera: Camera2D = null
var _player = null
var _action: int = 4               # 4 = idle (viz app/player_controller.gd)
var _anim = null
var _hues = null                   # render.hue (barva kuze; bez nej je postava seda)
var _hue_cache_hit: bool = false   # tonovany sprite se pocita jen pri zmene
var _hue_last: Texture2D = null    # posledni prebarveny zaklad
var _hue_last_hued: Texture2D = null


func _ready() -> void:
	_iso = Iso.new()
	_anim = Anim.new()
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
	_chunk = Chunk.new(map, textures)
	look_at_tile(center_tile)


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
	if _chunk != null:
		_chunk.invalidate()
	queue_redraw()


func visible_count() -> int:
	return _list().size()


func counts() -> Dictionary:
	return _chunk.counts() if _chunk != null else {}


func _list() -> Array:
	if _chunk == null:
		return []
	return _chunk.visible(center_tile, VIEW_TILES_X, VIEW_TILES_Y)


func _draw() -> void:
	if _textures == null:
		return
	drawn = 0
	player_drawn = false
	var diagonal: int = 999999
	if _player != null:
		diagonal = int(_player.pos.x) + int(_player.pos.y)
	for obj in _list():
		if _player != null and not player_drawn and int(obj["x"]) + int(obj["y"]) > diagonal:
			_draw_player()
		var art: Texture2D = _textures.texture(obj["art_id"])
		if art == null:
			continue
		draw_texture(art, _chunk.screen_position(obj))
		drawn += 1
	if _player != null and not player_drawn:
		_draw_player()


func _draw_player() -> void:
	# Vraci se i to, ze se postava NEKRESLILA (`player_missing`) - prazdno se
	# nesmi tvarit jako " hotovo" (docs/08 §8.6).
	player_drawn = false
	if _player == null or _anim == null:
		return
	player_drawn = true
	var clip: Dictionary = _anim.play(int(_player.body), _action, int(_player.dir))
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
