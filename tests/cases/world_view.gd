extends RefCounted
# app.world_view - kreslici uzel sveta (docs/02 §2.4; soubor app/world_view.gd).
#
# CO SE MERI (docs/09 §9.4 - chovani, ne "soubor existuje"):
#   * `setup(map, textures)` postavi `render.chunk` a hned zmeri pohled,
#     `counts()`/`visible_count()` odpovidaji obsahu mapy v pohledu 64x48
#     (VIEW_TILES_X/VIEW_TILES_Y z tohoto modulu, ne opsane cislo),
#   * `look_at_tile(tile, z)` posune kameru VCNETNE `z` (namERena vada
#     2026-10-06: kamera na z=0 postavila hrace o 40 px vys) a zahodi cache
#     seznamu - jinak by se po presunu kreslil stary pohled,
#   * klic hrace (`_sort_key_of_player`) je PRESNE klic z `render.sort` pro
#     vrstvu mobilu, takze sedi mezi statiky: na sve diagonale je za VSEMI
#     statiky a pred vsim z dalsi diagonaly,
#   * `set_registry` preda registr do `render.anim` (ne jen si ho necha),
#   * `player_hue`: hue 0 nebo chybejici barvy vraci ZAKLAD (ne null, ne novou
#     texturu), takze "postava zustane seda" je videt v datech.
#
# UZEL SE PRIDAVA DO STROMU: `_ready()` je to, co nastavi `_sort` (klic hrace
# by jinak neexistoval) a najde kameru v rodici. Na konci se uvolni `free()` -
# ne `queue_free()`: uvolneny uzel (nebo jeho zbyle deti) jinak shodi cely beh.
#
# ASSETY (`assets/uo/` je v .gitignore) se NEMERI potichu ani podminene:
# test se na ne pta jen tam, kde to modul sam nabizi (`anim_available()`,
# `hue_available()`) a OVE RUJE, ze odpovidaji souborum na disku - takze
# kontrola ma smysl i v CI bez assetu (a nezustane ani ticha nula, ani
# cervena za chybejici data). Vetev `player_hue` s hue != 0 se v CI probere
# jako "bez barev zustane zaklad" a cislo to rekne v nazvu kontroly.
#
# CESTA K MERENEMU SOUBORU JE VSTUP (`-- --world-view-script=<cesta>`, konvence
# jako u `tests/cases/render_sort.gd`): `tools/gates/mutace-tests.py` vraci
# vadu do KOPIE souboru a pousti ji pres tenhle prepinac, takze kontroly maji
# trvaly mutacni dukaz. Neexistujici cesta musi case SHODIT (`t._pending`).
# POZOR: modul si `render.chunk` preloaduje sam, takze prepinac meni jen
# `app/world_view.gd` - `render/chunk_renderer.gd` ma vlastni case soubor.

const Lib = preload("res://tests/lib.gd")

const VIEW_SCRIPT := "res://app/world_view.gd"
const SORT_SCRIPT := "res://render/sort.gd"
const ISO_SCRIPT := "res://core/iso.gd"
const CONST_SCRIPT := "res://core/const.gd"
const ANIM_MANIFEST := "res://assets/uo/anim/anim-sheets.json"
const HUES_PATH := "res://assets/uo/hues.json"


class FakeMap:
	# Mapa pro test: land jen v zadanem obdelniku, statiky v jednom bloku.
	# Stejne rozhrani jako `sim/world/map.gd` (land_at/z_at/statics_at).
	var land_tile: int = 7
	var land_rect: Rect2i = Rect2i()
	var statics: Dictionary = {}     # Vector2i(blok) -> Array zaznamu (lokalni x,y)

	func land_at(x: int, y: int) -> int:
		return land_tile if land_rect.has_point(Vector2i(x, y)) else -1

	func z_at(_x: int, _y: int) -> int:
		return 0

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x / 8, y / 8), [])


class FakeTextures:
	# Jen to, co `render.chunk` a `app.world_view` od textur chteji:
	# `offset(art_id)` a `texmap(texmap_id)` (textura svahu). `texture()` vraci
	# null = vsechny arty chybi, takze je `render.chunk_mesh` nakresli jako diry
	# (a i to je meritelne: pocet kvadru musi sedet na seznam).
	var offsets: Dictionary = {}
	var texmapy: Dictionary = {}      # texmap_id -> Texture2D (nebo cokoliv neprazdneho)

	func texture(_art_id: int) -> Texture2D:
		return null

	func page_pending(_art_id: int) -> bool:
		# ⚠ 18. session: `null` z `texture()` znamena "art CHYBI" (dira), ne
		# "jeste se nacita" - fixture nic nenacita, takze pending je vzdy false.
		return false

	func verze() -> int:
		return 0

	func tick_nacteni() -> int:
		return 0

	func offset(art_id: int) -> Vector2i:
		var v: Vector2i = offsets.get(art_id, Vector2i.ZERO)
		return v

	func texmap(texmap_id: int) -> Texture2D:
		return texmapy.get(texmap_id)


class FakeMobile:
	var pos: Vector3i = Vector3i(10, 20, 0)
	var serial: int = 42
	var dir: int = 0
	var hue: int = 0


class FakeRegistry:
	# `render.anim.body_of` saha na `get_mobile(serial)` a `.body`.
	func get_mobile(serial: int):
		if serial == 42:
			return {"body": 400}
		return null


class FakeAnim:
	# Nahrazuje `render.anim` v testu smeru kresleni: zapise, s jakym smerem se
	# `play()` volalo, a vrati platny klip (jinak by `_draw_player` skoncil
	# uvnitr a smer by se nedal zmerit).
	var dir: int = -1
	var akce: int = -1

	func available() -> bool:
		return true

	func play(_serial: int, action: int, direction: int, _now_ms: int = -1) -> Dictionary:
		akce = action
		dir = direction
		return {"ok": true, "texture": _textura(), "frame": 0, "count": 10,
			"anchor": Vector2.ZERO, "mirror": false, "mirror_x": 0, "sprite_dir": direction}

	func frame_count(_body: int, _action: int, _dir: int) -> int:
		return 10

	func _textura() -> Texture2D:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		return ImageTexture.create_from_image(img)


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _klic(sort, kind: String, x: int, y: int, z: int) -> int:
	return sort.sort_key({"kind": kind, "x": x, "y": y, "z": z})


func run(t) -> void:
	var cesta: String = _arg("world-view-script", VIEW_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("app.world_view NENI HOTOV: " + cesta + " chybi nebo nejde nacist")
		return
	var sort_script = Lib.script_at(SORT_SCRIPT)
	var iso_script = Lib.script_at(ISO_SCRIPT)
	if sort_script == null or iso_script == null:
		t._pending("app.world_view NEMEREN: render/sort.gd nebo core/iso.gd nejde nacist")
		return
	var consts: Dictionary = Lib.consts_at(CONST_SCRIPT)
	var iso = iso_script.new()
	var sort = sort_script.new()

	# Mapa: land na cele plose pohledu, ktery `setup()` hned zmeri. Stred je
	# `BRITAIN` (1495,1630) a pohled 64x48, takze oblast je x 1463..1526,
	# y 1606..1653 - a presne tolik dlazdic se musi namERit (3072 = 64*48).
	var map := FakeMap.new()
	map.land_rect = Rect2i(1400, 1560, 300, 200)
	# Statik v bloku (182,200) = zaklad (1456,1600); lokalni (7,7) je svetove
	# (1463,1607) a to je V oblasti. Dva dalsi jsou mimo a nesmi se pocitat.
	map.statics[Vector2i(182, 200)] = [
		{"tile": 500, "x": 7, "y": 7, "z": 3, "hue": 0},
		{"tile": 501, "x": 0, "y": 0, "z": 3, "hue": 0},
		{"tile": 502, "x": 60, "y": 0, "z": 3, "hue": 0},
	]
	var textures := FakeTextures.new()
	textures.offsets[500 + 0x4000] = Vector2i(2, 3)

	# Uzel MUSI byt ve strome: `_ready()` nastavi `_sort` (bez toho neni klic
	# hrace) a hleda kameru v RODICI - proto kamera visi vedle, ne pod nim.
	var scena := Node2D.new()
	scena.name = "ScenaWorldViewTestu"
	t.root.add_child(scena)
	var cam := Camera2D.new()
	cam.name = "Camera"
	scena.add_child(cam)
	var view = script.new()
	scena.add_child(view)
	# POZOR (namEReno 2026-10-08): v behu `--script` se `_ready()` z `add_child`
	# v `_initialize()` JESTE nespusti (koren stromu neni "inside tree", takze
	# notifikace READY neprijde) - `_sort`, `_hues` i `_camera` by zustaly null,
	# klic hrace by neexistoval a `_ready` by se tise neprobehl. Proto se
	# zivotni cyklus zavola rucne a HODNOTI se, ze probehl: `_sort` nesmi byt
	# null a `anim_available`/`hue_available` musi odpovidat souborum na disku.
	view.call("_ready")
	t._check(view.get("_sort") != null
		and view.hue_available() == FileAccess.file_exists(HUES_PATH),
		"app.world_view: zivotni cyklus probehl (_sort %s, hue_available %s pri souboru %s)"
			% [str(view.get("_sort") != null), str(view.hue_available()),
				str(FileAccess.file_exists(HUES_PATH))])

	# 1) pred `setup()` se nekresli a je to videt (prazdno, ne vymyslena nula)
	var prazdne: Dictionary = view.counts()
	t._check(view.visible_count() == 0 and prazdne.is_empty(),
		"app.world_view: pred setup() je 0 objektu a prazdne counts (namEReno %d, %s)"
			% [view.visible_count(), str(prazdne)])

	# 2) konstanta pohledu je z modulu - kdyby byla jina, zmeni se i pocet
	var view_consts: Dictionary = Lib.consts_at(cesta)
	t._check(int(view_consts.get("VIEW_TILES_X", 0)) == 64
		and int(view_consts.get("VIEW_TILES_Y", 0)) == 48,
		"app.world_view: VIEW_TILES_X/Y je 64x48 (namEReno %sx%s)"
			% [str(view_consts.get("VIEW_TILES_X")), str(view_consts.get("VIEW_TILES_Y"))])

	# 3) setup() postavi seznam: okno ze `_list_okraj()` (land + 1 statik
	#    v oblasti, 2 mimo). Vetsi okno je ZAMERNE: seznam se prestavuje az po
	#    `RECENTER_TILES` krocich (namEReno 85-98 ms na prestavbu, viz hlavicka
	#    modulu), takze musi pokryt i to, kam hrac muze odjit.
	#    ⚠ 17. session (2026-10-08): okno se odvozuje od VELIKOSTI OBRAZOVKY
	#    (`_list_okraj()`), proto se nebere z konstant - jinak by test meril
	#    cislo, ktere uz v kodu neni. Zaroven se meri, ze okno obrazovku
	#    opravdu pokryva (kdyz ne, `_draw` ji prestane kreslit a vzniknou DIRY).
	var recenter: int = int(view_consts.get("RECENTER_TILES", 0))
	view.setup(map, textures)
	var okraj: Vector2i = view.call("_list_okraj")
	var sirka: int = okraj.x
	var vyska: int = okraj.y
	var objekty: int = view.visible_count()
	var counts: Dictionary = view.counts()
	t._check(sirka > 0 and vyska > 0 and objekty == sirka * vyska + 1
		and int(counts.get("land", -1)) == sirka * vyska
		and int(counts.get("static", -1)) == 1,
		"app.world_view: pohled %dx%d = %d land + 1 statik v oblasti "
		% [sirka, vyska, sirka * vyska]
		+ "(namEReno %d objektu, land %s, static %s, RECENTER %d)"
			% [objekty, str(counts.get("land")), str(counts.get("static")), recenter])
	# 3a) OKNO POKRYVA OBRAZOVKU: polomer okna v izometrickych osach musi byt
	#     vetsi nez polovina obrazovky + to, kam hrac muze odjit (`RECENTER`).
	var rozmer: Vector2 = view.get_viewport_rect().size
	if rozmer.x > 0.0 and rozmer.y > 0.0:
		var pol_a: float = float(sirka) / 2.0 - float(recenter)
		var pol_b: float = float(vyska) / 2.0 - float(recenter)
		var potreba_a: float = (rozmer.x / 2.0 + rozmer.y / 2.0) / float(consts["ISO_STEP"])
		var potreba_b: float = absf(rozmer.x / 2.0 - rozmer.y / 2.0) / float(consts["ISO_STEP"])
		t._check(pol_a >= potreba_a and pol_b >= potreba_b,
			"app.world_view: okno %dx%d pokryva obrazovku %s (osa a %.1f >= %.1f, osa b %.1f >= %.1f)"
				% [sirka, vyska, str(rozmer), pol_a, potreba_a, pol_b, potreba_b])
	else:
		print("[test]      NEMERENO: okno vs obrazovka - viewport nema rozmer (headless)")
	t._check(counts.size() == 3 and counts.has("land") and counts.has("static")
		and counts.has("skryto"),
		"app.world_view: counts() ma land, static a skryto (namEReno %s)" % str(counts.keys()))
	t._check(view.center_tile == Vector2i(1495, 1630),
		"app.world_view: stred po setup() je BRITAIN (namEReno %s)" % str(view.center_tile))

	# 3b) ODDALENA PRESTAVBA (2026-10-07): posun o mene nez RECENTER_TILES
	#     kroku vraci TUTEZ instanci seznamu (neprestavuje se), vzdaleni posun
	#     prestavi. Bez toho se seznam stavel pri kazdem kroku - 44 ms x 2,5/s.
	#     Meri se v OSE X i Y (jinak by prošla vada, ktera hlida jen jednu osu).
	if recenter >= 1:
		var seznam_pred: Array = view.call("_list")
		view.look_at_tile(Vector2i(1495 + recenter - 1, 1630), 0)
		var seznam_x: Array = view.call("_list")
		view.look_at_tile(Vector2i(1495, 1630 + recenter - 1), 0)
		var seznam_y: Array = view.call("_list")
		view.look_at_tile(Vector2i(1495 + recenter, 1630), 0)
		var seznam_daleko: Array = view.call("_list")
		t._check(is_same(seznam_pred, seznam_x) and is_same(seznam_pred, seznam_y)
			and not is_same(seznam_pred, seznam_daleko),
			"app.world_view: seznam se prestavi az po %d dlazdicich (x stejna %s, y stejna %s, "
			% [recenter, str(is_same(seznam_pred, seznam_x)), str(is_same(seznam_pred, seznam_y))]
			+ "vzdaleny novy seznam %s)" % str(not is_same(seznam_pred, seznam_daleko)))
		view.look_at_tile(Vector2i(1495, 1630), 0)
		view.call("_list")

	# 4) kamera stoji presne podle `core.iso` a `core.const` (z = 0)
	var stred := Vector2i(1495, 1630)
	var ocekavana: Vector2 = iso.to_screen(stred.x, stred.y, 0) \
		+ Vector2(int(consts["ISO_STEP"]), int(consts["TILE_H"]) / 2)
	t._check(cam.position == ocekavana,
		"app.world_view: kamera je na to_screen(stred, z=0) + pulka dlazdice "
		+ "(namEReno %s, ocekavano %s)" % [str(cam.position), str(ocekavana)])

	# 5) `z` je VSTUP: posun o 5 svetovych jednotek = 5 * Z_SCALE px v y.
	#    Tohle je namERena vada z 2026-10-06 (kamera z ignorovala).
	view.look_at_tile(Vector2i(10, 20), 0)
	var pri_nule: Vector2 = cam.position
	view.look_at_tile(Vector2i(10, 20), 5)
	var pri_peti: Vector2 = cam.position
	var rozdil_y: int = int(round(pri_nule.y - pri_peti.y))
	t._check(rozdil_y == 5 * int(consts["Z_SCALE"]) and pri_nule.x == pri_peti.x,
		"app.world_view: look_at_tile respektuje z (posun y %d px pri Z_SCALE %d, x %s)"
			% [rozdil_y, int(consts["Z_SCALE"]), str(pri_nule.x == pri_peti.x)])
	var ocekavana5: Vector2 = iso.to_screen(10, 20, 5) \
		+ Vector2(int(consts["ISO_STEP"]), int(consts["TILE_H"]) / 2)
	t._check(pri_peti == ocekavana5 and view.center_tile == Vector2i(10, 20),
		"app.world_view: kamera na z=5 je to_screen(10,20,5) + pulka dlazdice "
		+ "(namEReno %s, ocekavano %s)" % [str(pri_peti), str(ocekavana5)])

	# 5b) ⚠ 17. session (2026-10-08) - KAMERA SE POSOUVA O POSUN KROKU.
	#     Uzivatel: "obraz se pohybuje skokove, ne plynule - jakmile je postava
	#     na novem tile, poskoci i obrazovka". NamEReno pred opravou: skok
	#     kamery **44,00 px** na frame; po oprave **6,23 px** a hrac je presne
	#     ve stredu (`_analyza/p20-overeni.txt`). Kontroluje se, ze treti
	#     argument `look_at_tile` kameru posune PRESNE o dodany vektor - jinak
	#     by svet stal a pak skocil.
	view.look_at_tile(Vector2i(10, 20), 0)
	var bez_posunu: Vector2 = cam.position
	view.look_at_tile(Vector2i(10, 20), 0, Vector2(8.8, 8.8))
	t._check(cam.position == bez_posunu + Vector2(8.8, 8.8),
		"app.world_view: look_at_tile pricte posun kroku ke kamere (namEReno %s, bez posunu %s)"
			% [str(cam.position), str(bez_posunu)])
	view.look_at_tile(Vector2i(10, 20), 0)

	# 5c) ⚠ 18. session - CERNY PAS PRO GUI: svet ma sve okno a vpravo/dole je
	#     cerny pas, kde bydli GUI (stary zpusob UO). Stred sveta pak NENI stred
	#     obrazovky, takze se kamera posune o `gui_odsazeni` - bez toho by hrac
	#     stal pod cernym pasem (mimo viditelny svet).
	view.gui_odsazeni = Vector2(160.0, 60.0)
	view.look_at_tile(Vector2i(10, 20), 0)
	var s_pasem: Vector2 = cam.position
	view.gui_odsazeni = Vector2.ZERO
	view.look_at_tile(Vector2i(10, 20), 0)
	t._check(s_pasem == cam.position + Vector2(160.0, 60.0),
		"app.world_view: gui_odsazeni se pricte ke kamere (s pasem %s, bez %s)"
			% [str(s_pasem), str(cam.position)])
	view.look_at_tile(Vector2i(3000, 3000), 0)
	var objekty_jinde: int = view.visible_count()
	var jinde: Dictionary = view.counts()
	t._check(objekty_jinde == 0 and int(jinde.get("land", -1)) == 0
		and int(jinde.get("static", -1)) == 0,
		"app.world_view: look_at_tile zahodi cache seznamu "
		+ "(namEReno %d objektu, land %s, static %s)"
			% [objekty_jinde, str(jinde.get("land")), str(jinde.get("static"))])

	# 7c) ⚠ 17. session (2026-10-08) - SMER KRESLENI POSTAVY SE MENI HNED.
	#     Uzivatel: "animace nezmeni orientaci, takze postava jakoby klouze do
	#     strany". Pricina (namERena): `_draw_player` bral smer z `player.dir`,
	#     ktery `sim.movement.apply_step` prepise az na KONCI kroku (400 ms).
	#     Dnes ho bere z `_view_dir` (`set_view_dir`) - takze se smer animace
	#     zmeni hned se zamerem.
	view.set_view_dir(4)
	t._check(int(view.get("_view_dir")) == 4,
		"app.world_view: set_view_dir nastavi smer kresleni (namEReno %s)"
			% str(view.get("_view_dir")))
	view.set_view_dir(-1)
	t._check(int(view.get("_view_dir")) == 7,
		"app.world_view: set_view_dir normalizuje zaporny smer na 0..7 (namEReno %s)"
			% str(view.get("_view_dir")))
	view.set_view_dir(9)
	t._check(int(view.get("_view_dir")) == 1,
		"app.world_view: set_view_dir normalizuje smer > 7 (namEReno %s)"
			% str(view.get("_view_dir")))

	# 7) klic hrace je klic z render.sort pro mobil (ne vlastni aritmetika)
	var hrac := FakeMobile.new()
	hrac.pos = Vector3i(10, 20, 0)
	view.set_player(hrac)
	var klic = view.call("_sort_key_of_player")
	var ocekavany: int = sort.sort_key({"kind": "mobile", "x": 10, "y": 20, "z": 0})
	t._check(typeof(klic) == TYPE_INT and klic == ocekavany,
		"app.world_view: klic hrace == sort_key(mobile 10,20,0) (namEReno %s, ocekavano %d)"
			% [str(klic), ocekavany])

	# 7b) ⚠ V2 (2026-10-07): POSUN POSTAVY MEZI DLAZDICEMI. `set_player_offset`
	#     posune KRESLENI postavy, i kdyz `player.pos` je porad stara dlazdice
	#     (presne to dela reference: `Mobile.cs:776-782` kresli `Offset`,
	#     `:836-844` commitne dlazdici az na konci kroku). Meri se to na
	#     `player_ground_position()` - to je funkce, kterou `_draw_player` vola.
	var zakladni: Vector2 = view.player_ground_position()
	view.set_player_offset(Vector2(11.0, -7.0))
	var posunuty: Vector2 = view.player_ground_position()
	t._check(posunuty - zakladni == Vector2(11.0, -7.0),
		"app.world_view: posun kroku se pricte ke kresleni postavy (%s -> %s, rozdil %s)"
			% [str(zakladni), str(posunuty), str(posunuty - zakladni)])
	t._check(int(hrac.pos.x) == 10 and int(hrac.pos.y) == 20,
		"app.world_view: pri posunu se dlazdice postavy NEMENI (pos %s)" % str(hrac.pos))
	view.set_player_offset(Vector2.ZERO)
	t._check(view.player_ground_position() == zakladni,
		"app.world_view: vynulovany posun vraci kresleni na dlazdici")

	# 7d) ⚠ 17. session (2026-10-08) - `_draw_player` kresli SMER KRESLENI.
	#     Podstrci se falesny animator, ktery si zapise, s jakym smerem se
	#     volalo: mobil pritom stoji na STARSIM smeru (presne stav, kdy
	#     uzivatel videl "klouani do strany"). Meri se smlouva, ne cizi modul.
	hrac.dir = 0
	view.set_view_dir(2)
	var falesny := FakeAnim.new()
	view.set("_anim", falesny)
	view.call("_draw_player")
	t._check(falesny.dir == 2,
		"app.world_view: _draw_player kresli SMER KRESLENI, ne `player.dir` "
		+ "(namEReno %d, mobil %d, cekano 2)" % [falesny.dir, int(hrac.dir)])
	view.set_view_dir(0)

	# 8) ⚠ 18. session: klic hrace SEDI MEZI STATIKY sveho pruchodU. Pri STEJNEM
	#    `z` jako hrac: statiky na blizsi diagonale (29) jsou pred nim, statiky
	#    na dalsi diagonale (31) za nim. (Do 17. session tu bylo "vsechny na
	#    diagonale 30 pred hracem" - to prestalo platit, protoze `z` dnes muze
	#    prebit az 2,5 kroku mrizky, presne jako reference.)
	var z_min: int = int(consts["Z_MIN"])
	var z_max: int = int(consts["Z_MAX"])
	var za_hracem: int = -1
	for x in range(1, 30):
		za_hracem = maxi(za_hracem, _klic(sort, "static", x, 29 - x, 0))
	var pred_hracem: int = 0x7FFFFFFF
	for x in range(0, 4):
		pred_hracem = mini(pred_hracem, _klic(sort, "static", x + 20, 31 - (x + 20), 0))
	t._check(int(klic) > za_hracem and int(klic) < pred_hracem,
		"app.world_view: hrac je mezi statiky sveho pruchodu (diag 29 < %d < hrac %d < %d = diag 31)"
			% [za_hracem, int(klic), pred_hracem])
	# 8a) ⚠ 18. session: LAND JE VZDY PRED HRACEM - ma vlastni pruchod
	#     (reference `RenderLists.cs:199-232`), takze ani land s nejvyssim `z`
	#     na blizsi diagonale nejde za hrace. Na tom stoji vada "svah
	#     prosvita pres schody/most".
	var land_max: int = -1
	for x in range(0, 4):
		land_max = maxi(land_max, _klic(sort, "land", x + 20, 31 - (x + 20), z_max))
	t._check(land_max < int(klic),
		"app.world_view: land je pred hracem i s nejvyssim `z` a nejblizsi diagonalou (%d < %d)"
			% [land_max, int(klic)])
	# 8b) statik na TEZE diagonale a VYSSI nez hrac jde ZA hrace (vada (a)).
	#     Toto je vlastnost, kterou vidi uzivatel na snimku: strecha nad hracem
	#     se nesmi kreslit pred nim, jinak to vypada, ze po ni chodi.
	var hrac_obj := {"kind": "mobile", "x": 10, "y": 20, "z": 0}
	var strecha := {"kind": "static", "x": 10, "y": 20, "z": 31}
	t._check(sort.sort_key(strecha) > sort.sort_key(hrac_obj),
		"app.world_view: strecha (z=31) na TEZE diagonale jde ZA hracem (z=0) "
		+ "(%d > %d)" % [sort.sort_key(strecha), sort.sort_key(hrac_obj)])
	# 8c) ⚠ 18. session: statik o JEDNU diagonalou dal a VYSOKO jde ZA hracem -
	#     presne to je "strecha, ktera hrace prekryje" (do 17. session sla pred
	#     nim, proto byl hrac videt pres strechu). Zmereno na referencnim klíči
	#     `(x + y) + (127 + z) * 0.01`: rozdil `z` (765) je vetsi nez krok
	#     mrizky (300), takze 1-2 kroky se prebit daji.
	var strecha_dal := {"kind": "static", "x": 9, "y": 20, "z": z_max}
	t._check(sort.sort_key(strecha_dal) > int(klic),
		"app.world_view: statik o 1 diagonalу dal s nejvyssim `z` jde ZA hracem (%d > %d)"
			% [sort.sort_key(strecha_dal), int(klic)])

	# 9) set_registry preda registr do render.anim (body_of ho pouzije)
	view.set_registry(FakeRegistry.new())
	var anim = view.get("_anim")
	var telo = null if anim == null else anim.body_of(42)
	var nezname = null if anim == null else anim.body_of(999)
	t._check(telo != null and int(telo) == 400 and int(nezname) == -1,
		"app.world_view: set_registry preda registr do render.anim "
		+ "(serial 42 -> %s, neznamy -> %s)" % [str(telo), str(nezname)])
	# animace a barvy jsou z `assets/uo` (gitignore) - NEMERENO se hlasi, ne mizi
	var ma_anim := FileAccess.file_exists(ANIM_MANIFEST)
	t._check(view.anim_available() == ma_anim,
		"app.world_view: anim_available() odpovida pritomnosti %s (namEReno %s, soubor %s)"
			% [ANIM_MANIFEST, str(view.anim_available()), str(ma_anim)])
	var ma_hues := FileAccess.file_exists(HUES_PATH)
	t._check(view.hue_available() == ma_hues,
		"app.world_view: hue_available() odpovida pritomnosti %s (namEReno %s, soubor %s)"
			% [HUES_PATH, str(view.hue_available()), str(ma_hues)])

	# 10) player_hue: hue 0 a null vstup vraci ZAKLAD (zadna nova textura)
	var obrazek := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	obrazek.fill(Color(1.0, 0.5, 0.25, 1.0))
	var zaklad: Texture2D = ImageTexture.create_from_image(obrazek)
	t._check(view.player_hue(null, 5) == null,
		"app.world_view: player_hue(null, hue) vraci null (namEReno %s)"
			% str(view.player_hue(null, 5)))
	var bez_hue: Texture2D = view.player_hue(zaklad, 0)
	t._check(bez_hue != null and is_same(bez_hue, zaklad),
		"app.world_view: player_hue s hue 0 vraci TUTYz zaklad (ne novou texturu)")
	# s hue != 0: s barvami se prebarvi, bez nich zustane zaklad - oboji je
	# spravne a je VIDET, ktera vetev se namERila.
	var obarvene: Texture2D = view.player_hue(zaklad, 1002)
	if view.hue_available():
		t._check(obarvene != null and not is_same(obarvene, zaklad),
			"app.world_view: s hues.json se hue != 0 prebarvi (nova instance)")
	else:
		t._check(obarvene != null and is_same(obarvene, zaklad),
			"app.world_view: bez hues.json zustane pri hue != 0 zaklad (namEReno seda)")

	# 11) SVAH (2026-10-07): `slope_polygon()` — rovna plocha vraci prazdno
	# (kresli se land art), svah vraci 4 rohy ve vyskach SOUSEDU. Vada
	# uzivatele: "kde je svah, tam neni tile" - bez teto vetve zustava
	# v prechodu vysky seda dira (`render.chunk` dava `z_corners`).
	# Cisla se pocitaji z `core/const.gd` (ISO_STEP, Z_SCALE), ne opisuji.
	var krok: float = float(consts["ISO_STEP"])
	var zs: float = float(consts["Z_SCALE"])
	var rovna := {"kind": "land", "x": 10, "y": 10, "z": 20,
		"z_corners": [20, 20, 20, 20]}
	t._check(script.slope_polygon(rovna, Vector2.ZERO).is_empty(),
		"app.world_view: rovna plocha nema svahovy polygon (%s)"
			% str(script.slope_polygon(rovna, Vector2.ZERO)))
	# Soused na vychode je o 4 nizsi -> PRAVY roh se posune o 4 * Z_SCALE dolu
	var svah := {"kind": "land", "x": 10, "y": 10, "z": 20,
		"z_corners": [20, 16, 20, 20]}
	var body: PackedVector2Array = script.slope_polygon(svah, Vector2.ZERO)
	t._check(body.size() == 4 and body[0] == Vector2(krok, 0.0)
		and body[1] == Vector2(2.0 * krok, krok + 4.0 * zs)
		and body[2] == Vector2(krok, 2.0 * krok)
		and body[3] == Vector2(0.0, krok),
		"app.world_view: svah ma 4 rohy a pravy roh klesne o 4*Z_SCALE (namEReno %s)"
			% str(body))
	# UV musi mit 4 body a sedet na rohy (jinak se textura rozjede)
	var uv: PackedVector2Array = script.slope_uv()
	t._check(uv.size() == 4 and uv[0] == Vector2(0.0, 0.0) and uv[1] == Vector2(1.0, 0.0)
		and uv[2] == Vector2(1.0, 1.0) and uv[3] == Vector2(0.0, 1.0),
		"app.world_view: slope_uv() mapuje ROHY textury na vrcholy diamantu (namEReno %s)" % str(uv))
	# a s velikosti textury se prida pulpixelovy inset proti sevum (reference
	# `ChunkMesh.cs:458-462`: `rect.X + 0.5`, `rect.Width - 1`)
	var uv_inset: PackedVector2Array = script.slope_uv(64.0, 64.0)
	t._check(uv_inset[0] == Vector2(0.5 / 64.0, 0.5 / 64.0)
		and uv_inset[1] == Vector2(1.0 - 0.5 / 64.0, 0.5 / 64.0),
		"app.world_view: slope_uv(64, 64) prida pulpixelovy inset (namEReno %s)" % str(uv_inset))
	# Rozhodnuti `is_slope()`: svah ano, rovna plocha ne, bez textury ne.
	# Tohle je vetev, ktera rozhoduje, zda v terenu zustane dira.
	var obrazek2 := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	textures.texmapy[76] = ImageTexture.create_from_image(obrazek2)
	var svah_obj := {"kind": "land", "x": 10, "y": 10, "z": 20, "texmap": 76,
		"z_corners": [20, 16, 20, 20]}
	var rovny_obj := {"kind": "land", "x": 10, "y": 10, "z": 20, "texmap": 76,
		"z_corners": [20, 20, 20, 20]}
	var bez_texmapu := {"kind": "land", "x": 10, "y": 10, "z": 20, "texmap": 0,
		"z_corners": [20, 16, 20, 20]}
	var bez_textury := {"kind": "land", "x": 10, "y": 10, "z": 20, "texmap": 999,
		"z_corners": [20, 16, 20, 20]}
	t._check(view.is_slope(svah_obj) and not view.is_slope(rovny_obj)
		and not view.is_slope(bez_texmapu) and not view.is_slope(bez_textury),
		"app.world_view: is_slope() = svah ano, rovna/bez texmapu/bez textury ne "
		+ "(namEReno %s/%s/%s/%s)" % [str(view.is_slope(svah_obj)), str(view.is_slope(rovny_obj)),
			str(view.is_slope(bez_texmapu)), str(view.is_slope(bez_textury))])

	# 12) M9 (2026-10-08): DAVKA JE ZAPOJENA, ne mrtvy kód. `_priprav_mesh()`
	#     postavi `render.chunk_mesh` z TOHO SAMEHO seznamu a `mesh_stats()` to
	#     rekne cislem; kdyby se stavba preskocila, zustane prazdny slovnik.
	#     (Kresleni `_draw()` se v headless testu volat NEDÁ - Godot dovoli
	#     `draw_*` jen v NOTIFICATION_DRAW, takze se meri priprava dávky.)
	view.look_at_tile(Vector2i(1495, 1630), 0)
	view.call("_priprav_mesh")
	view.call("_priprav_mesh")
	view.call("_priprav_mesh")
	var davka: Dictionary = view.mesh_stats()
	t._check(not davka.is_empty() and int(davka.get("kvadru", 0)) > 0,
		"app.world_view: M9 dávka se postavi (_priprav_mesh) a ma kvadry "
		+ "(namEReno %s kvadru z %s objektu seznamu)"
			% [str(davka.get("kvadru")), str(view.visible_count())])
	t._check(int(davka.get("kvadru", -1)) == view.visible_count(),
		"app.world_view: dávka ma kvadr na KAZDY objekt seznamu (%s vs %s)"
			% [str(davka.get("kvadru")), str(view.visible_count())])

	# 13) uvolneni uzlu: `free()` (ne queue_free) - zbyly uzel shodi cely beh
	view.free()
	t._check(not is_instance_valid(view),
		"app.world_view: uzel je po testu uvolneny (is_instance_valid == false)")
	scena.free()
