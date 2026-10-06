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

const Iso = preload("res://core/iso.gd")
const Chunk = preload("res://render/chunk_renderer.gd")
const Const = preload("res://core/const.gd")

const VIEW_TILES_X: int = 64
const VIEW_TILES_Y: int = 48
const BRITAIN := Vector2i(1495, 1630)

var center_tile: Vector2i = BRITAIN
var drawn: int = 0                 # kolik objektu se naposledy kreslilo

var _iso
var _chunk = null
var _textures = null
var _camera: Camera2D = null


func _ready() -> void:
	_iso = Iso.new()
	_camera = get_parent().get_node_or_null("Camera") as Camera2D
	if _camera == null:
		push_warning("app.world_view: ve scene chybi uzel Camera - svet bude mimo obrazovku")


func setup(map, textures) -> void:
	# Vola `app.main` po nacteni dat; do te doby se nekresli (a je to videt).
	_textures = textures
	_chunk = Chunk.new(map, textures)
	look_at_tile(center_tile)


func look_at_tile(tile: Vector2i) -> void:
	center_tile = tile
	if _camera != null:
		_camera.position = _iso.to_screen(tile.x, tile.y, 0) \
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
	for obj in _list():
		var art: Texture2D = _textures.texture(obj["art_id"])
		if art == null:
			continue
		draw_texture(art, _chunk.screen_position(obj))
		drawn += 1
