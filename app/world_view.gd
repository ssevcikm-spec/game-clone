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
# --- ZOOM (19. session, V9 "CELA OBRAZOVKA JE TROCHU PIXELATA ... CHTELO BY TO
# ODDALIT OBRAZOVKU, ZVETSIT ROZHLED") ------------------------------------
# ZOOM JE VSTUP, ne konstanta (rozhodnuti v `ZADANI-19-VADY-ZE-SNIMKU.md` §4.2):
# kolecko mysi a klavesy `+`/`-` (i numpad) meni rozhled za behu.
#
# CO JE NAMERENE (2026-10-08, `_analyza/p22-zoom-sonda.gd`, okno 1280x720 s
# cernym pasem GUI 320 vpravo / 120 dole; "viditelne okno" = co hrac opravdu
# vidi, "kreslena plocha" = co se jeste kresli pod pásem):
#   * zoom 1,0 (stav pred 19. session): viditelne okno 960x600 px sveta = osy
#     `a = x - y` 44 a `b = x + y` 28 dlazdic, tedy **36,0 dlazdice na osu
#     sveta** (`(a + b) / 2`), v okne 579 land dlazdic,
#   * zoom 0,75 (VYCHOZI): viditelne okno 1280x800 px = osy 59 / 37, tedy
#     **48,0 dlazdice na osu sveta** (+33 % rozhledu), v okne 1081 land dlazdic;
#     kazda dlazdice je 33x33 px misto 44x44,
#   * zoom 0,5: 1920x1200 px = 71,5 dlazdice na osu (2344 land dlazdic),
#   * zoom 1,5: 640x400 px = 24,5 dlazdice; zoom 2,0: 480x300 px = 18,0 dlazdice.
#   * pri KAZDEM zoomu je hrac presne ve stredu viditelneho okna (odchylka
#     < 0,001 px - mereno pres `player_ground_position()`), okno seznamu
#     obrazovku pokryva (`pokryto true`) a davka se postavi bez der
#     (`der 0`, `pretek false`, `missing art 0`; pri zoomu 0,5 ma 26 528 kvadru).
#   * zoom < 1 ZVETSUJE rozhled, ale kazdy pixel artu se mapuje na MENE nez
#     jeden pixel obrazovky - to je "pixelatost", kterou uzivatel vidi. Snimky
#     (Nearest vs. Linear, zoom 0,5 / 0,75 / 1,0 / 1,5 / 2,0) a cisla jsou
#     v `_analyza/p22-zoom-sonda.txt`; doporuceni k V10 je v HANDOFFu.
#
# ⚠ PAST (namERena): seznam objektu (`_list_okraj`) se musi pri oddaleni ZVETSIT
# presne o `1 / zoom`, jinak obrazovka prestane byt pokryta a u okraju vzniknou
# DIRY. Proto `_list_okraj()` i `_obrazovka()` deli rozmer viewportu zoomem
# (`svet_rozmer()`), a `gui_odsazeni` (v px OBRAZOVKY) se naopak zoomem deli,
# aby hrac zustal ve stredu viditelneho okna.
#
# ⚠⚠ V5 "PRI POHYBU CELA OBRAZOVKA ZRNI" - NAMERENE PRICINY (2026-10-08,
# `_analyza/p22-teren-zrno.gd`, rizeny pokus: posun kamery o cely svetovy pixel
# a rozdil snimku po nejlepsim posunu obrazovky):
#   * PRI ZOOMU 1,0 JE POHYB OSTNY: zbytek **0,00 %** = obraz je jen posunuty
#     o cely pixel. V klidu se nemeni vubec (0 pixelu, `p22-teren-grain.gd`).
#     Behem 3 000 framu chuze: 0 framu pomalych (> 33 ms), 0 framu s `hold`,
#     0 framu se stavem davky != 0, 0 framu s necelociselnou kamerou.
#   * PRI ZOOMU != 1 JE POHYB ROZMAZANY: zbytek **52,27 %** (zoom 0,75) a
#     **92,45 %** (zoom 0,5) - svetovy pixel je na obrazovce zlomek pixelu.
#     Oprava `snap_na_pixely` to srazi na **0,23 %** / **0,01 %**.
#   * NEZAVISLA PRICINA (mimo tento modul): kdyz okno NEMA zakladni velikost
#     1280x720, `canvas_items` stretch skaluje canvas zlomkem (okno 1300x740 ->
#     1,0156x) a prevzorkuje se CELY obraz i pri zoomu 1,0: zbytek **96,74 %**.
#     To je vlastnost `project.godot` (`boot.project`), ne tohoto modulu; reseni
#     je `display/window/stretch/scale_mode=integer` nebo hrat v 1280x720.
#     Cisla a postup: `_analyza/p22-teren-zrno.txt`.
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.0
# Nasobny krok (1 krok = +25 % / -20 %): stejny krok na obe strany, aby se
# zoom dal vratit presne na vychozi hodnotu.
const ZOOM_KROK: float = 1.25
# Vychozi hodnota < 1 = VETSI rozhled nez pred 19. session (viz namerena cisla
# v hlavicce). Cislo je rozhodnuti: 0,75 je nejmensi oddaleni, ktere je na
# 1280x720 jeste citelne (0,5 uz je polovicni rozliseni artu).
const ZOOM_VYCHOZI: float = 0.75

var center_tile: Vector2i = BRITAIN
# Aktualni zoom (1.0 = stav pred 19. session). Meni ho `nastav_zoom()`.
var zoom: float = ZOOM_VYCHOZI
# ⚠⚠ ZAOKROUHLENI NA MŘÍŽKU OBRAZOVKY (19. session, V5 "pri pohybu cela
# obrazovka zrni"). NAMERENO (`_analyza/p22-teren-zrno.gd`): pri zoomu != 1 se
# svetovy posun o CELY pixel projevi na obrazovce ZLOMKEM pixelu (0,75 px pri
# zoomu 0,75), takze Nearest vzorkuje jine texely a obraz se kazdy frame
# PREVZORKOVAVA - zrni. Cisla: zbytek po nejlepsim posunu obrazovky byl
# **52,27 %** pri zoomu 0,75 a **92,45 %** pri zoomu 0,5 (pri zoomu 1,0 je to
# **0,00 %** = cista translace). Kdyz se pozice kamery i postavy zaokrouhli na
# CELOCISELNE pixely obrazovky (`round(p * zoom) / zoom`), je zbytek **0,23 %**
# (zoom 0,75) a **0,01 %** (zoom 0,5) - svet se hybe po celych pixelech
# obrazovky, presne jako reference (`GameObject.cs:152-153` kresli `int`).
# Pri zoomu 1,0 je zaokrouhleni IDENTITA, takze se chovani pred 19. session
# nemeni ani o pixel (proto `is_equal_approx(zoom, 1.0)`).
var snap_na_pixely: bool = true
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
var _mesh_klic: int = -2147483647
var _mesh_stats: Dictionary = {}
var _mesh_pretek_hlasen: bool = false
# POCITADLA CESTY KRESLENI (18. session, pro sondy - cisla, ktera se jinak
# meri jen okem): kolik framu se kreslilo davkou / predchozi davkou / puvodni
# cestou, kolik bylo staveb a kolik framu vubec proslo kreslenim.
var _drawu: int = 0
var _davek: int = 0
var _predchozich: int = 0
var _puvodnich: int = 0
var _staveb: int = 0
# Pocet dotecenych stranek atlasu pri posledni stavbe (18. session): kdyz se
# zmeni, davka se prestavi, aby se do ni dostaly arty, ktere se jeste nacitaly.
var _textures_verze: int = 0
# Kolik framu se uz ceka na doteceni stranek atlasu (viz `_priprav_mesh`).
var _cekani_verze: int = 0
const _CEKANI_FRAMU: int = 120
# Kolik ms prace smi stavba dávky udelat v jednom framu (18. session).
# Cela stavba stoji ~130-170 ms; pri 8 ms/frame zustane frame pod 16 ms
# a davka je hotova za ~20 framu (pri 300 FPS ~70 ms), pritom se porad kresli
# PREDCHOZI davka. Kdo chce videt, jak to stoji, at si to zvedne v sonda.
const _STAVBA_MS: float = 8.0
# VYCHOZI CESTA JE MESH (M9). Vypina se jen pro mereni parity a pro pripad, ze
# se runtime atlas naplni - obe cesty musi umet to same (docs/08: modernizace
# nesmi ubrat zadne mereni).
var mesh_enabled: bool = true


# POSUN SVETA KVULI CERNEMU PASU PRO GUI (18. session): uzivatel chce stary
# zpusob UO - okno viditelneho sveta a VEDLE nej cerny pas, kde bydli GUI
# (zurnal, stavovy pruh). Kdyz je pas vpravo a dole, stred "okna sveta" uz neni
# stred obrazovky, takze se kamera posune o polovinu pásu - hrac pak stoji ve
# stredu VIDITELNEHO sveta, ne pod cernym pasem. Vychozi hodnota je nulova
# (testy i kdo si pas nezapne dostanou presne stare chovani).
var gui_odsazeni: Vector2 = Vector2.ZERO


func _ready() -> void:
	_iso = Iso.new()
	_anim = Anim.new()
	_sort = Sort.new()
	_hues = Hue.new()
	_camera = get_parent().get_node_or_null("Camera") as Camera2D
	if _camera == null:
		push_warning("app.world_view: ve scene chybi uzel Camera - svet bude mimo obrazovku")
	else:
		# ZOOM (V9) se na kameru nasadi HNED - bez toho by obraz do prvniho
		# `nastav_zoom()` neodpovidal deklarovanemu vychozimu zoomu.
		_aplikuj_zoom()
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


# --- ZOOM (19. session, V9) ----------------------------------------------
func svet_rozmer() -> Vector2:
	# VIDITELNA PLOCHA SVETA v px. Kamera ma `zoom`, takze svet se do viewportu
	# vejde `1 / zoom` krat vetsi. Tohle cislo je VSTUP pro `_obrazovka()`
	# (orezavani) i `_list_okraj()` (okno seznamu) - kdyz se na to zapomene,
	# obrazovka prestane byt pokryta a u okraju vzniknou DIRY (namERena past).
	#
	# Kdyz viewport rozmer NEMA (headless beh bez okna), vezme se DEKLAROVANA
	# velikost okna z `project.godot`: okno seznamu i pokryti se pak pocitaji
	# STEJNYM vzorcem jako v hre. Vracet nulu by znamenalo "nic se nekresli"
	# a to je horsi nez vetsi okno; vracet pevnou konstantu by zase znamenalo,
	# ze se vliv zoomu v testu vubec nezmeri.
	var rozmer: Vector2 = get_viewport_rect().size
	if rozmer.x <= 0.0 or rozmer.y <= 0.0:
		rozmer = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	return rozmer / zoom


func viditelne_dlazdice() -> Vector2i:
	# Rozsah viditelne plochy v izometrickych osach (`core/iso.gd`):
	# `a = x - y` (vodorovna osa obrazovky) a `b = x + y` (svisla). Pocet
	# dlazdic na jednu osu SVETA je `(a + b) / 2`; tady se vraceji oba rozsahy,
	# protoze z nich se pocita pokryti obrazovky.
	var s: Vector2 = svet_rozmer()
	var krok: float = float(Const.ISO_STEP)
	return Vector2i(int(ceil(s.x / krok)), int(ceil(s.y / krok)))


func snap_screen(p: Vector2) -> Vector2:
	# Pozice ve SVETE -> pozice na CELOCISELNEM pixelu obrazovky (viz
	# `snap_na_pixely` v hlavicce). Pri zoomu 1,0 vraci vstup beze zmeny.
	if not snap_na_pixely or is_equal_approx(zoom, 1.0):
		return p
	return (p * zoom).round() / zoom


func nastav_zoom(novy: float) -> void:
	# ZOOM JE VSTUP (rozhodnuti v `ZADANI-19-VADY-ZE-SNIMKU.md` §4.2). Mimo
	# rozsah se oreze; stejna hodnota nic nemeni (aby se seznam neprestavoval
	# zbytecne - prestavba stoji desitky ms).
	var omezene: float = clampf(novy, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(omezene, zoom):
		return
	zoom = omezene
	_aplikuj_zoom()
	# Zmena zoomu meni VIDITELNOU PLOCHU, takze stary seznam objektu ma maly
	# okraj. Vynuti se prestavba (sentinel) - okno se pocita z `zoom`.
	_list_center = Vector2i(-99999, -99999)
	if _camera != null:
		look_at_tile(center_tile, int(_player.pos.z) if _player != null else 0,
			_player_offset)
	print("[world_view] zoom ", zoom, ": viditelna plocha ", svet_rozmer(),
		" px sveta, osy a/b ", viditelne_dlazdice(), " dlazdic, okno seznamu ",
		_list_okraj())
	queue_redraw()


func zoom_krok(smer: int) -> void:
	# Nasobny krok: 1 krok = ZOOM_KROK. Vetsi cislo = vetsi priblizeni (mensi
	# rozhled), takze "oddalit" je `smer < 0`.
	if smer > 0:
		nastav_zoom(zoom * ZOOM_KROK)
	elif smer < 0:
		nastav_zoom(zoom / ZOOM_KROK)


func _aplikuj_zoom() -> void:
	if _camera != null:
		_camera.zoom = Vector2(zoom, zoom)


func _unhandled_input(event: InputEvent) -> void:
	# VSTUP PRO ZOOM: kolecko mysi (nahoru = priblizit, dolu = oddalit) a
	# klavesy `+`/`-` vcetne numpadu a `=` (na nemecke/ceske klavesnici je `+`
	# pres shift, takze samotne `=` je "priblizit").
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_krok(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_krok(-1)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_PLUS or k == KEY_EQUAL or k == KEY_KP_ADD:
			zoom_krok(1)
			get_viewport().set_input_as_handled()
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			zoom_krok(-1)
			get_viewport().set_input_as_handled()


func player_ground_position() -> Vector2:
	# KAM SE KRESLI POSTAVA (bez kresleni - da se merit testem i sondou).
	# Je to stred dlazdice, na ktere postava stoji, plus posun kroku - a pozice
	# je ZAOKROUHLENA NA MRIZKU OBRAZOVKY (`snap_screen`), aby postava
	# neprochazela prevzorkovanim pri zoomu != 1 (V5). Tim se take zachova, ze
	# postava stoji PRESNE ve stredu viditelneho sveta: kamera je posunuta
	# o `gui_odsazeni / zoom` a zaokrouhleni je pro obe strany stejne.
	if _player == null:
		return Vector2.ZERO
	if _iso == null:
		_iso = Iso.new()          # testy tvori uzel bez `_ready()` (N8)
	return snap_screen(_iso.to_screen(int(_player.pos.x), int(_player.pos.y),
		int(_player.pos.z)) + Vector2(Const.ISO_STEP, Const.TILE_H / 2) + _player_offset)


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
	# ⚠ 18. session: stav "hrac je pod strechou" se predava seznamu objektu
	# (`render.chunk_renderer.nastav_hrace`). Kdyz se zmeni, seznam se zahodi a
	# strechy/stropy nad hracem se prekresli BEZ nich - v budove je pak videt
	# vnitrek (reference `UpdateMaxDrawZ`, `GameSceneDrawingSorting.cs:57-213`).
	if _chunk != null:
		_chunk.nastav_hrace(tile.x, tile.y, z)
	if _camera != null:
		# ⚠ `gui_odsazeni` je v PIXELECH OBRAZOVKY (o kolik je stred viditelneho
		# sveta vedle stredu okna), takze se do sveta prepocita pres `zoom`:
		# pri oddaleni je tyz posun na obrazovce vetsi ve svete. Bez deleni by
		# hrac pri zoomu != 1 stal mimo stred viditelneho sveta.
		# ⚠ A pak se pozice zaokrouhli na mrizku OBRAZOVKY (`snap_screen`) -
		# jinak by se pri zoomu != 1 obraz kazdy frame prevzorkoval (V5).
		_camera.position = snap_screen(_iso.to_screen(tile.x, tile.y, z) \
			+ Vector2(Const.ISO_STEP, Const.TILE_H / 2) + offset + gui_odsazeni / zoom)
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
	# ⚠ 19. session (V9): rozmer je VIDITELNA PLOCHA SVETA (`svet_rozmer()`),
	# tedy viewport / zoom - pri oddaleni okno roste presne o `1 / zoom`.
	var rozmer: Vector2 = svet_rozmer()
	if rozmer.x <= 0.0 or rozmer.y <= 0.0:
		# NEMERENO: neda se to ani z deklarovaneho okna - vrat deklarovane
		# minimum, ne nulu (nula by znamenala "nekresli se nic").
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


func klic_hrace_stats() -> Dictionary:
	# ROZKLAD klice hrace pro test a sondu (cisla, ne dojem): jaky objekt ho
	# urcil a kolik objektu se do maxima pocitalo. Bez toho by se "hrac je vzadu"
	# nedalo overit jinak nez okem.
	if _player == null:
		return {"klic": -1, "pocitano": 0, "nejvyssi": -1, "diagonala": 0}
	var diagonal: int = int(_player.pos.x) + int(_player.pos.y)
	var nejvyssi: int = -1
	var pocitano: int = 0
	for obj in _list():
		if int(obj["x"]) + int(obj["y"]) > diagonal:
			continue
		pocitano += 1
		nejvyssi = maxi(nejvyssi, _sort.sort_key(obj))
	return {"klic": _klic_hrace(), "pocitano": pocitano, "nejvyssi": nejvyssi,
		"diagonala": diagonal}


func _draw() -> void:
	if _textures == null:
		return
	_drawu += 1
	# M9: nejdriv se zkusi davka (1-2 draw cally). Kdyz neni postavena (runtime
	# atlas se naplnil), kresli se puvodni cestou - obraz musi byt spravny vzdy.
	# POZOR: `_priprav_mesh()` vraci `_mesh.is_built()` - dokud dávka postavena
	# NENI, kresli se puvodni cestou (jinak by se kreslil prazdny mesh = cerno).
	if mesh_enabled and _mesh != null:
		var st: int = _priprav_mesh()
		if st == 0:
			_kresli_mesh(false)
			_davek += 1
			return
		# ⚠ 18. session: dokud se davka stavi (`krok`) nebo se stranka na GPU
		# prekresluje (`hold`), kresli se PREDCHOZI davka - ta na starou stranku
		# sedi presne. Puvodni cesta stoji ~35 ms/frame.
		if st == 1:
			_kresli_mesh(true)
			_predchozich += 1
			return
	_puvodnich += 1
	_draw_puvodni()

func _draw_puvodni() -> void:
	drawn = 0
	slopes = 0
	holes = 0
	nodraw = 0
	player_drawn = false
	# Postava se vklada do JIZ SETRIDENEHO seznamu. Poradi rozhoduje
	# `render.sort.sort_key` (jedina funkce razeni, docs/04 §4.2) - ne vlastni
	# porovnavani. Klic hrace se pocita JEDNOU za frame.
	var klic_hrace: int = _klic_hrace()
	# OREZANI MIMO OBRAZOVKU (namEReno 2026-10-07): seznam je
	# (64 + 2*RECENTER) x (48 + 2*RECENTER) dlazdic (4 032 land + ~3 400 statiku),
	# ale obrazovka 1280x720 jich ukazuje zlomek. Godot kresli i to, co je mimo
	# (draw call stoji cas), takze se prvky dal od okna preskakuji. `CULL_MARGIN`
	# je velky zamerne: statiky maji arty vysoke pres 100 px a natazene svahy az
	# (Z rozsah) * Z_SCALE px. NamEReno: 46,6 -> 34,5 ms na frame.
	var okno: Rect2 = _obrazovka(CULL_MARGIN)
	for obj in _list():
		if _player != null and not player_drawn:
			# ⚠ 18. session: rozhoduje CELY klic, ne diagonala - v klíči muze
			# `z` prebit az ~2,5 diagonály (viz `render/sort.gd`). Do teto
			# session tu bylo `d > diagonal or (d == diagonal and klic > ...)`,
			# coz kreslilo hrace na spatnem miste vuci strecham o 2 diagonály dal.
			if _sort.sort_key(obj) > klic_hrace:
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
			if _textures.page_pending(art_id):
				# Stranka se jeste nacita (18. session) - "nenacteno" neni "chybi".
				continue
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
	var velikost: Vector2 = svet_rozmer()
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


func _priprav_mesh() -> int:
	# Posune stavbu dávky a vrati její STAV (0 = hotova davka, 1 = stavi se /
	# ceka se na stranku -> kresli PREDCHOZI, 2 = neda se -> puvodni cesta).
	# ⚠ 18. session: stavba je ROZDELENA do framu (`chunk_mesh.krok`) - cela
	# stavba stoji ~130-170 ms a byla to jedina zbyla vada "periodicky zasek".
	var seznam: Array = _list()
	if _textures != null:
		# Hotove stranky se prevzimaji KAZDY frame - bez toho by stranka
		# zustala "ceka" a objekty by se neobjevily (viz `tick_nacteni`).
		_textures.tick_nacteni()
		if _textures.verze() != _textures_verze:
			_textures_verze = _textures.verze()
			# ⚠ PŘESTAVBA SE ODDÁLÍ, dokud nejsou stranky dotecene: na startu
			# prichazi 33 stranek postupne a kazda zmena verze by spustila CELOU
			# stavbu (`_analyza/p21-chuze.gd`). Kdyby neco viselo, po
			# `_CEKANI_FRAMU` se prestavi i tak (jinak by art zustal vynechany).
			if _textures.pending() == 0:
				_cekani_verze = 0
				_mesh.invalidate()
				_mesh_seznam = []
			else:
				_cekani_verze += 1
				if _cekani_verze >= _CEKANI_FRAMU:
					_cekani_verze = 0
					_mesh.invalidate()
					_mesh_seznam = []
	if _mesh.hold() > 0:
		# Stranka se prekresluje na GPU: nová davka by cetla starou texturu.
		_mesh.tick_hold()
		_nacti_mesh_stats()
	if not is_same(seznam, _mesh_seznam) and not _mesh.stavi_se():
		# ⚠ 18. session: stavba se NEZAHajUJE znovu, kdyz uz jedna bezi. Kdyby
		# se zahajovala (zmena seznamu uprostred stavby), prisla by o rozdelenou
		# praci a - dokud nebyla opravena i `zacni` - i o PREDCHOZI davku
		# (namEReno: `puvodni` 75 framu). Po dokonceni stavby se novy seznam
		# pozna (`_mesh_seznam` zustava stary) a stavi se znovu.
		_mesh_seznam = seznam
		_staveb += 1
		_mesh.zacni(seznam)
	if _mesh.stavi_se():
		_mesh.krok(_STAVBA_MS)
	var st: int = _mesh.stav()
	if _mesh.je_geometrie_hotova():
		var klic: int = _klic_hrace()
		# ⚠ Rozdeleni na "pred hracem"/"po hraci" se dela HODNE po kazde stavbe
		# (i dokud se stranka prekresluje) - kdyby se preskocilo, kreslil by se
		# prazdny mesh (cerna obrazovka) a prislo by se i o predchozi davku.
		if _mesh.treba_split() or klic != _mesh_klic:
			_mesh_klic = klic
			_mesh.split_for_player(klic)
			_nacti_mesh_stats()
	return st


func stav_davky() -> int:
	# Stav davky pro testy a sondy (viz `chunk_mesh.stav`).
	return _mesh.stav() if _mesh != null else 2


func stavi_se() -> bool:
	# Bezi stavba davky? (Pro testy a sondy - viz `chunk_mesh.stavi_se`.)
	return _mesh.stavi_se() if _mesh != null else false


func _klic_hrace() -> int:
	# Klic hrace pro deleni davky. Bez hrace plati SENTINELA: vsechno ma klic
	# >= 0, takze `-1` da "pred hracem" prazdne a kresli se cela davka.
	# ⚠ 19. session: klic se pocita z REALNEHO seznamu objektu (`_list()`), proto
	# si ho `_draw` a `_priprav_mesh` berou touhle funkci (ne primo
	# `_sort_key_of_player`), aby se nemohly rozejit.
	if _player == null:
		return -1
	return _sort_key_of_player(_list())


func _nacti_mesh_stats() -> void:
	# Pocitadla se berou z POSTAVENE davky - jinak by `drawn`/`holes`/`nodraw`
	# tvrdily neco jineho, nez co je na obrazovce (docs/08 §8.6).
	_mesh_stats = _mesh.stats()
	slopes = int(_mesh_stats.get("svahu", 0))
	holes = int(_mesh_stats.get("der", 0))
	nodraw = int(_mesh_stats.get("nodraw", 0))
	drawn = int(_mesh_stats.get("kvadru", 0)) - holes
	for art_id in _mesh.missing_art_ids():
		if not _hlasene_diry.has(art_id):
			_hlasene_diry[art_id] = true
			push_warning("app.world_view: art %d neni v atlase - kresli se magenta" % art_id)


func _kresli_mesh(predchozi: bool = false) -> void:
	# PORADI: (1) vse s klicem `<=` klic hrace, (2) hrac, (3) vse s vetsim
	# klicem. Presne to dela puvodni smycka - jen se 3 prikazy misto tisice.
	# ⚠ 18. session: land je od teto session v klíči PRVNI PRUCHOD, takze je
	# cely v "pred hracem" casti - presne jako reference (`RenderLists.cs`
	# kresli mesh land pred mesh statics); statik se tak nikdy nekresli pod pudu.
	# ⚠ 18. session: `predchozi = true` kresli davku PREDCHOZI (behem `hold`,
	# kdy stranka jeste nema novy obsah) - vcetne jejich pocitadel, aby
	# `drawn`/`kvadru` nelhaly.
	player_drawn = false
	player_missing = false
	if predchozi:
		var st: Dictionary = _mesh.stats_predchozi()
		if not st.is_empty():
			# Pocitadla predchozi davky - jinak by `drawn`/`kvadru` tvrdily neco
			# jineho, nez je na obrazovce. Prazdna (prvni stavba, nez se stihla
			# zapsat) se NEPREPISUJI: "0 kvadru" by byla lez (namEReno 4 framy).
			_mesh_stats = st
			drawn = int(st.get("kvadru", 0)) - int(st.get("der", 0))
		_mesh.draw_before_predchozi(self)
		_draw_player()
		_mesh.draw_after_predchozi(self)
		return
	_mesh.draw_before(self)
	_draw_player()
	_mesh.draw_after(self)


func mesh_stats() -> Dictionary:
	# Mereni pro `app.metrics` (M9): kolik kvadru je v dávce a jak draha byla
	# stavba. Prazdny slovnik = dávka se nepouziva (a je to videt).
	return _mesh_stats.duplicate()


func cesty() -> Dictionary:
	# POCITADLA CESTY KRESLENI (18. session) - pro sondu `p21-chuze.gd`.
	# `staveb` je pocet prestaveb, `puvodnich` pocet framu, kdy se kreslilo
	# puvodni cestou (ta stoji desitky ms - proto jsou videt jako zaseky).
	return {"drawu": _drawu, "davkou": _davek, "predchozi": _predchozich,
		"puvodni": _puvodnich, "staveb": _staveb}


func _draw_slope(obj: Dictionary, pozice: Vector2) -> bool:
	# SVAH: kresli se TEXMAPEM natazenym pres ctyrrohy (ClassicUO `Batcher2D.cs:241`
	# `DrawStretchedLand`). Rozhodnuti je v `is_slope()` - tady uz jen kresleni.
	# ⚠ ZMENENO (task-5, 20. session): do teto zmeny se svah kreslil JEDNOU
	# konstantni barvou (bez srafovani svetlem). Dnes se barva bere z NORMALY
	# svahu (`chunk_mesh.svah_barva`, reference `IsometricWorld.fx:60-69`
	# `get_light` + `Land.CalculateNormal`) - kopec tim dostal smer svetla.
	# Rovna plocha vraci presne puvodni `SVAH_JAS` (identita).
	if not is_slope(obj):
		return false
	var body: PackedVector2Array = slope_polygon(obj, pozice)
	var tex: Texture2D = _textures.texmap(int(obj["texmap"]))
	# ⚠ 18. session: barva svahu a UV jsou STEJNE jako v dávce (`chunk_mesh`),
	# aby se obe cesty nerozesly (docs/08: modernizace nesmi ubrat mereni).
	# Od task-5 to plati i pro JAS: obe cesty volaji TUTEZ funkci
	# (`slope_barva` -> `chunk_mesh.svah_barva`), zadna si ji nepocita po svem
	# (na rozejiti se obou cest padala 18. session).
	# `slope_uv` dostava velikost textury, aby sel pridat pulpixelovy inset
	# proti sevum - `AtlasTexture.get_width()` vraci sirku regionu.
	var barva: Color = slope_barva(obj)
	var barvy := PackedColorArray([barva, barva, barva, barva])
	if tex == null:
		return false
	draw_polygon(body, barvy,
		MeshScript.slope_uv(float(tex.get_width()), float(tex.get_height())), tex)
	return true


static func slope_barva(obj: Dictionary, brightlight: float = 1.0) -> Color:
	# BARVA SVAHU pro PUVODNI cestu (kresleni `_draw_slope`). Je to jen
	# pruchod na `render.chunk_mesh.svah_barva` - jedna funkce pro obe cesty
	# (dávku i puvodni kresleni), aby se NEMOHLY rozejit (18. session: presne
	# to byla vada "ruzne svetle svahy"). Test porovnava tuhle funkci
	# s nezavislym prepisem reference, ne jen s `chunk_mesh`.
	# `brightlight` je vstup (vychozi 1.0 = neutralni profil; viz hlavicka
	# `render/chunk_mesh.gd`), aby ho budouci `render.light` mohl predat.
	return MeshScript.svah_barva(obj, brightlight)


static func slope_polygon(obj: Dictionary, pos: Vector2) -> PackedVector2Array:
	# Geometrie svahu je od M9 v `render.chunk_mesh` (potrebuje ji i dávka);
	# tady se jen predava dal, aby zustala smlouva i testy na tom samem miste.
	return MeshScript.slope_polygon(obj, pos)


static func slope_uv(sirka: float = 0.0, vyska: float = 0.0) -> PackedVector2Array:
	# UV rohu v texture (0..1): horni (0,0), pravy (1,0), dolni (1,1), levy (0,1)
	# - ROHY textury, presne jako reference (`_cornerOffsetX/Y` v
	# `Batcher2D.cs:16-17`; nas starsi tvar `(0.5,0) …` byl otoceny o 45 stupnu
	# a je to vada "ruznobarevne svahy", viz hlavicka `render/chunk_mesh.gd`).
	# Kdyz volajici zna velikost textury, prida se pulpixelovy inset.
	return MeshScript.slope_uv(sirka, vyska)


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


func _sort_key_of_player(seznam: Array = []) -> int:
	# ⚠⚠ 19. session (2026-10-08) - V1 ZE ZADANI 19 ("propadam se do textury
	# mostu"). Do teto session mel hrac klic `sort_key({mobile, x, y, z})`, tedy
	# PRESNE klic mobila na sve dlazdici - jenze statik na TEZE dlazdici muze mit
	# `priority_z` vyssi (podlaha -1, statik s vyskou +1) a tim i vetsi klic, takze
	# se kreslil PO hracovi a prekryl ho.
	# NAMERENO nezavislym overenim (task-4, `_analyza/p22-overeni-00-souhrn.md`):
	# hrac na (1501,1599) ma klic 8 930 416, statik art 16585 na teze dlazdici
	# 8 930 418 -> 2 jednotky PO hraci, hrac neni videt. Uprostred kroku pres most
	# kryje hrace prkno o diagonalu vpred (23,3 % viditelnych pixelu hrace).
	#
	# Reference ma Z-BUFFER a mobilum pocita hloubku z `maxZ` dlazdice
	# (`GameSceneDrawingSorting.cs:159-166`), takze je kresli jako NEJBLIZSI.
	# Painter's algoritmus to umi jen poradim, a proto se klic hrace pocita
	# z REALNYCH objektu: je to NEJVETSI klic objektu, ktere mohou hrace
	# PREKRYT - tedy vsech, ktere jsou na diagonale hrace nebo BLIZ (diagonala
	# `<= diagonala hrace`), ZVETSENY o 1. Tim plati oboji:
	#   * hrac je ZA vsim na sve diagonale (i za statikem s nejvyssim `z`),
	#   * hrac je ZA plosinami, ktere ma POD SEBOU a o 1-2 diagonaly vpred -
	#     presne to je prkno mostu, ktere jinak "reze postavu v urovni stehen"
	#     NAMERENO: kryto 187 px z 804 (23,3 %) viditelnych pixelu hrace.
	# HRANICE, KTERA SE NESMI ZATAJIT: statik o 1-2 diagonaly dal s vysokym `z`
	# (strecha, zed vepredu) se muze dostat PRED hrace, protoze jeho klic muze
	# byt nizsi nez klic hrace. Je to cena za to, ze hrace neprekryva podlaha
	# pod nim - a je to stejne chovani jako reference, ktera mobilum pocita
	# hloubku z `maxZ` dlazdice hrace (`GameSceneDrawingSorting.cs:159-166`),
	# tedy je kresli jako NEJBLIZSI. Meri to test `world_view` 7/8c na oba smery.
	if _player == null:
		return -1
	var diagonal: int = int(_player.pos.x) + int(_player.pos.y)
	var nejvyssi: int = -1
	for obj in seznam:
		var d: int = int(obj["x"]) + int(obj["y"])
		if d > diagonal:
			# Objekty BLIZ (diagonala hrace a nizsi) hrace mohou prekryt - jejich
			# maximum rozhoduje. Objekty dal se preskakuji (ne `break`: seznam je
			# setrideny podle klice a objekty o 1-2 diagonaly dal mohou mit nizsi
			# klic, takze by `break` preskocil i objekty bliz).
			continue
		nejvyssi = maxi(nejvyssi, _sort.sort_key(obj))
	if nejvyssi < 0:
		# Prazdny seznam (test bez dat): zaloha je horni mez diagonaly - ne
		# nula, ktera by hrace poslala pred vsechno.
		return _sort.klic_nad_diagonalou(diagonal) + 1
	return nejvyssi + 1

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
