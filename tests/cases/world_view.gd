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
	# `BRITAIN` (1495,1630); okno seznamu zavisi na ZOOMU (19. session), proto
	# je land plocha s rezervou vetsi nez nejvetsi okno a pocet statiku se
	# v kontrole POCITA z dat (opsane cislo by pri zoomu lhalo).
	var map := FakeMap.new()
	map.land_rect = Rect2i(1360, 1520, 400, 300)
	# Statik v bloku (182,200) = zaklad (1456,1600); lokalni (7,7) je svetove
	# (1463,1607) a to je V okne. Dalsi dva v TEMZ bloku jsou mimo obrazovku
	# i pri oddaleni a nesmi se pocitat (stejne jako statik z jineho bloku).
	map.statics[Vector2i(182, 200)] = [
		{"tile": 500, "x": 7, "y": 7, "z": 3, "hue": 0},
		{"tile": 501, "x": 0, "y": 0, "z": 3, "hue": 0},
		{"tile": 502, "x": 60, "y": 0, "z": 3, "hue": 0},
	]
	# Blok (182,199) se pri okne porad prochazi, ale jeho statik lezi NAD oknem
	# (y = 1592) - tak se meri, ze se statiky mimo oblast SKUTECNE vynechavaji.
	map.statics[Vector2i(182, 199)] = [
		{"tile": 503, "x": 0, "y": 0, "z": 3, "hue": 0},
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
	# Kolik statiku z fixture lezi v okne: POCITA se z DAT. Okno je od 19.
	# session zavisle na zoomu, takze opsane "1 statik" by pri jinem zoomu
	# lhalo - a kontrola by merila neco jineho, nez co je v kodu.
	var okno_rect := Rect2i(1495 - sirka / 2, 1630 - vyska / 2, sirka, vyska)
	var statiku: int = 0
	for klic in map.statics.keys():
		var zaklad_bloku := Vector2i(int(klic.x) * 8, int(klic.y) * 8)
		for zaznam in map.statics[klic]:
			if okno_rect.has_point(zaklad_bloku + Vector2i(int(zaznam["x"]), int(zaznam["y"]))):
				statiku += 1
	var objekty: int = view.visible_count()
	var counts: Dictionary = view.counts()
	t._check(sirka > 0 and vyska > 0 and objekty == sirka * vyska + statiku
		and int(counts.get("land", -1)) == sirka * vyska
		and int(counts.get("static", -1)) == statiku,
		"app.world_view: pohled %dx%d = %d land + %d statiku v okne "
		% [sirka, vyska, sirka * vyska, statiku]
		+ "(namEReno %d objektu, land %s, static %s, RECENTER %d)"
			% [objekty, str(counts.get("land")), str(counts.get("static")), recenter])
	# 3a) OKNO POKRYVA OBRAZOVKU: polomer okna v izometrickych osach musi byt
	#     vetsi nez polovina VIDITELNE PLOCHY SVETA + to, kam hrac muze odjit
	#     (`RECENTER`). Viditelna plocha je `svet_rozmer()` = viewport / zoom
	#     (19. session, V9) - pri oddaleni je vetsi, takze okno musi byt vetsi.
	#     Kdyz okno obrazovku NEPOKRYJE, `_draw` ji prestane kreslit a vzniknou
	#     DIRY (namERena past).
	var rozmer: Vector2 = view.get_viewport_rect().size
	if rozmer.x <= 0.0 or rozmer.y <= 0.0:
		print("[test]      POZOR: viewport nema rozmer (headless) - pokryti se meri ",
			"s deklarovanym oknem z projektu: ", view.svet_rozmer(), " px sveta")
	var svet: Vector2 = view.svet_rozmer()
	if svet.x > 0.0 and svet.y > 0.0:
		var pol_a: float = float(sirka) / 2.0 - float(recenter)
		var pol_b: float = float(vyska) / 2.0 - float(recenter)
		var potreba_a: float = (svet.x / 2.0 + svet.y / 2.0) / float(consts["ISO_STEP"])
		var potreba_b: float = absf(svet.x / 2.0 - svet.y / 2.0) / float(consts["ISO_STEP"])
		t._check(pol_a >= potreba_a and pol_b >= potreba_b,
			"app.world_view: okno %dx%d pokryva svet %s pri zoomu %s (osa a %.1f >= %.1f, osa b %.1f >= %.1f)"
				% [sirka, vyska, str(svet), str(view.zoom), pol_a, potreba_a, pol_b, potreba_b])
	else:
		print("[test]      NEMERENO: okno vs svet - nelze zjistit viditelnou plochu")
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

	# 3c) ⚠⚠ 19. session (2026-10-08) - ZOOM JE VSTUP (V9: "cela obrazovka je
	#     jakoby trochu pixelata ... chtelo by to oddalit obrazovku, zvetsit
	#     rozhled"). Do teto session kamera `zoom` VUBEC nemela, takze vsechno
	#     bylo 1:1. Kontroluje se CHOVANI (ne jen hodnota konstanty):
	#       * vychozi zoom je < 1 = vetsi rozhled nez pred 19. session a je
	#         nasazeny na kamere,
	#       * `svet_rozmer()` = viewport / zoom (viditelna plocha sveta),
	#       * okno seznamu (`_list_okraj`) pri ODDALENI ROSTE - jinak by u okraju
	#         vznikly DIRY (namERena past),
	#       * okno obrazovku pokryva i pri nejvetsim oddaleni (ZOOM_MIN),
	#       * zoom se oreze na ZOOM_MIN / ZOOM_MAX,
	#       * `gui_odsazeni` (cerny pas GUI) je v px OBRAZOVKY, takze se do sveta
	#         deli zoomem - hrac zustane ve stredu viditelneho sveta.
	var zoom_vychozi: float = float(view_consts.get("ZOOM_VYCHOZI", 1.0))
	var zoom_min: float = float(view_consts.get("ZOOM_MIN", 1.0))
	var zoom_max: float = float(view_consts.get("ZOOM_MAX", 1.0))
	t._check(zoom_vychozi < 1.0 and is_equal_approx(float(view.zoom), zoom_vychozi),
		"app.world_view: vychozi zoom je < 1 (vetsi rozhled) a je nasazen (zoom %s, konstanta %s)"
			% [str(view.zoom), str(zoom_vychozi)])
	var rozmer_vp: Vector2 = view.get_viewport_rect().size
	var deklarovane := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	var zaklad_okna: Vector2 = rozmer_vp if rozmer_vp.x > 0.0 else deklarovane
	t._check(view.svet_rozmer().is_equal_approx(zaklad_okna / view.zoom),
		"app.world_view: svet_rozmer() = okno / zoom (namEReno %s, ocekavano %s)"
			% [str(view.svet_rozmer()), str(zaklad_okna / view.zoom)])
	var osy: Vector2i = view.viditelne_dlazdice()
	t._check(osy.x >= 1 and osy.y >= 1,
		"app.world_view: viditelne_dlazdice() vraci kladny rozsah os a/b (namEReno %s)" % str(osy))
	# okno seznamu: pri zoomu 1 vs pri ZOOM_MIN
	view.nastav_zoom(1.0)
	var svet_1: Vector2 = view.svet_rozmer()
	var okno_1: Vector2i = view.call("_list_okraj")
	var osy_1: Vector2i = view.viditelne_dlazdice()
	view.nastav_zoom(zoom_min)
	var svet_min: Vector2 = view.svet_rozmer()
	var okno_min: Vector2i = view.call("_list_okraj")
	var osy_min: Vector2i = view.viditelne_dlazdice()
	t._check(svet_min.x > svet_1.x and svet_min.y > svet_1.y,
		"app.world_view: oddaleni zvetsi viditelnou plochu (%s pri zoomu 1 -> %s pri %s)"
			% [str(svet_1), str(svet_min), str(zoom_min)])
	t._check(osy_min.x > osy_1.x and osy_min.y > osy_1.y,
		"app.world_view: oddaleni zvetsi rozsah os (%s -> %s dlazdic)" % [str(osy_1), str(osy_min)])
	t._check(okno_min.x > okno_1.x and okno_min.y >= okno_1.y,
		"app.world_view: oddaleni zvetsi okno seznamu (%s pri zoomu 1 -> %s pri %s)"
			% [str(okno_1), str(okno_min), str(zoom_min)])
	var pol_a_min: float = float(okno_min.x) / 2.0 - float(recenter)
	var pol_b_min: float = float(okno_min.y) / 2.0 - float(recenter)
	var pot_a_min: float = (svet_min.x / 2.0 + svet_min.y / 2.0) / float(consts["ISO_STEP"])
	var pot_b_min: float = absf(svet_min.x / 2.0 - svet_min.y / 2.0) / float(consts["ISO_STEP"])
	t._check(pol_a_min >= pot_a_min and pol_b_min >= pot_b_min,
		"app.world_view: okno pokryva obrazovku i pri zoomu %s (osa a %.1f >= %.1f, osa b %.1f >= %.1f)"
			% [str(zoom_min), pol_a_min, pot_a_min, pol_b_min, pot_b_min])
	t._check(is_equal_approx(cam.zoom.x, zoom_min) and is_equal_approx(cam.zoom.y, zoom_min),
		"app.world_view: nastav_zoom nasadi zoom na kameru (namEReno %s, cekano %s)"
			% [str(cam.zoom), str(zoom_min)])
	view.nastav_zoom(zoom_max * 4.0)
	t._check(is_equal_approx(float(view.zoom), zoom_max),
		"app.world_view: zoom se oreze nahoru na ZOOM_MAX (namEReno %s, konstanta %s)"
			% [str(view.zoom), str(zoom_max)])
	view.nastav_zoom(0.001)
	t._check(is_equal_approx(float(view.zoom), zoom_min),
		"app.world_view: zoom se oreze dolu na ZOOM_MIN (namEReno %s, konstanta %s)"
			% [str(view.zoom), str(zoom_min)])
	# `gui_odsazeni` je v px obrazovky -> do sveta se deli zoomem. Bez toho by
	# hrac pri oddaleni "usel" z centra viditelneho sveta pod cerny pas.
	view.gui_odsazeni = Vector2(160.0, 60.0)
	view.look_at_tile(Vector2i(10, 20), 0)
	var s_pasem_zoom: Vector2 = cam.position
	view.gui_odsazeni = Vector2.ZERO
	view.look_at_tile(Vector2i(10, 20), 0)
	var bez_pasu_zoom: Vector2 = cam.position
	t._check((s_pasem_zoom - bez_pasu_zoom).is_equal_approx(Vector2(160.0, 60.0) / zoom_min),
		"app.world_view: gui_odsazeni se pri zoomu %s deli zoomem (rozdil %s, ocekavano %s)"
			% [str(zoom_min), str(s_pasem_zoom - bez_pasu_zoom),
				str(Vector2(160.0, 60.0) / zoom_min)])
	view.nastav_zoom(zoom_vychozi)
	view.look_at_tile(Vector2i(1495, 1630), 0)

	# --- 4)-5c) meri PRESNY vzorec kamery, proto se tu prechazi na zoom 1,0:
	#     pri nem je `snap_screen` identita a nic se nezaokrouhluje (puvodni
	#     kontrakt zustava mereny presne). Chovani pri zoomu != 1 meri 5d.
	view.nastav_zoom(1.0)

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
	# ⚠ 19. session: pas je v px OBRAZOVKY, do sveta se deli zoomem (viz 3c).
	t._check(s_pasem == cam.position + Vector2(160.0, 60.0) / view.zoom,
		"app.world_view: gui_odsazeni se pricte ke kamere pres zoom (s pasem %s, bez %s, zoom %s)"
			% [str(s_pasem), str(cam.position), str(view.zoom)])
	# 5d) ⚠⚠ 19. session (V5 "pri pohybu cela obrazovka zrni"): pri zoomu != 1
	#     se pozice kamery i postavy ZAOKROUHLUJI NA MRIZKU OBRAZOVKY
	#     (`snap_screen`). Bez toho je svetovy pixel na obrazovce zlomek pixelu
	#     a obraz se kazdy frame prevzorkovava (namEReno zbytek 52,27 % pixelu
	#     pri zoomu 0,75; `_analyza/p22-teren-zrno.gd`). Meri se:
	#       (a) pri zoomu 1,0 je `snap_screen` IDENTITA (chovani pred 19.
	#           session se nesmi zmenit ani o pixel),
	#       (b) pri vychozim zoomu je pozice kamery na CELOCISELNEM pixelu
	#           obrazovky (posun o cely svetovy pixel = cely pixel obrazovky),
	#       (c) zaokrouhleni neposune kameru o vic nez jeden pixel obrazovky.
	view.nastav_zoom(1.0)
	var presna: Vector2 = iso.to_screen(10, 20, 0) \
		+ Vector2(int(consts["ISO_STEP"]), int(consts["TILE_H"]) / 2)
	t._check(view.snap_screen(presna) == presna and view.snap_screen(presna + Vector2(0.5, 0.5)) == presna + Vector2(0.5, 0.5),
		"app.world_view: snap_screen je pri zoomu 1,0 identita (i s necelym posunem)")
	view.nastav_zoom(zoom_vychozi)
	view.look_at_tile(Vector2i(10, 20), 0)
	var kam_zoom: Vector2 = cam.position
	var obrazova: Vector2 = kam_zoom * view.zoom
	t._check(absf(obrazova.x - roundf(obrazova.x)) < 0.001 \
			and absf(obrazova.y - roundf(obrazova.y)) < 0.001,
		"app.world_view: pri zoomu %s je pozice kamery na celociselnem pixelu obrazovky (%s -> %s)"
			% [str(view.zoom), str(kam_zoom), str(obrazova)])
	t._check((kam_zoom - presna).length() <= 1.0 / view.zoom + 0.001,
		"app.world_view: zaokrouhleni na mrizku obrazovky neposune kameru vic nez o pixel obrazovky (odchylka %.3f, mez %.3f)"
			% [(kam_zoom - presna).length(), 1.0 / view.zoom])
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

	# 7) klic hrace je klic z `render.sort` - a od 19. session (V1) je to
	#    NEJVETSI klic objektu na diagonale hrace (a blizsi) ZVETSENY o 1, aby
	#    hrace neprekryl statik na jeho vlastni dlazdici (namEReno: statik art
	#    16585 ma na teze dlazdici klic o 2 vyssi a hrace prekryl).
	#    Meri se to na REALNEM seznamu: do `_chunk` se vlozi vlastni objekty,
	#    mezi kterymi hrac stoji. Kontrola je na OBA smery - kdyby klic hrace
	#    byl jen "hodne velky", prosla by i vada "hrac je nad vsechno" a
	#    "zed prosvita pres strechu" by se vratila.
	var hrac := FakeMobile.new()
	hrac.pos = Vector3i(10, 20, 0)
	view.set_player(hrac)
	var sb: Dictionary = {
		"na_dlazdici": {"kind": "static", "x": 10, "y": 20, "z": 40, "art_id": 500 + 0x4000},
		"o_diag_dal": {"kind": "static", "x": 11, "y": 20, "z": 0, "art_id": 500 + 0x4000},
		"o_dva_diag": {"kind": "static", "x": 12, "y": 20, "z": 40, "art_id": 500 + 0x4000},
		"o_tri_diag": {"kind": "static", "x": 13, "y": 20, "z": 0, "art_id": 500 + 0x4000},
	}
	view._chunk._list = [sb["o_tri_diag"], sb["o_dva_diag"], sb["o_diag_dal"], sb["na_dlazdici"]]
	view._chunk._built = true
	var klic = view.call("_klic_hrace")
	var k_na: int = sort.sort_key(sb["na_dlazdici"])
	# TVRZENI, KTERE PLATI VZDY (a je to jadro opravy V1): klic hrace je vetsi
	# nez klic VSECH objektu na diagonale hrace a bliz - proto ho neprekryje
	# statik na jeho dlazdici ani plosina, na ktere stoji.
	# Druha strana je merena testem 8c: statik o 2 diagonaly dal s nejvyssim `z`
	# ma klic vyssi nez hrac, takze "strecha vepredu" se nezhorsila.
	var k_dva: int = sort.sort_key(sb["o_dva_diag"])
	var k_tri: int = sort.sort_key(sb["o_tri_diag"])
	# Rozklad klice (cisla, ne dojem): do maxima se pocital prave 1 objekt
	# (hracova diagonala 30) a nejvyssi z nich je statik na jeho dlazdici.
	var rozklad: Dictionary = view.klic_hrace_stats()
	t._check(int(rozklad["pocitano"]) == 1 and int(rozklad["nejvyssi"]) == k_na
		and int(rozklad["diagonala"]) == 30,
		"app.world_view: klic hrace pocita z REALNYCH objektu bliz (pocitano %d, nejvyssi %d, diag %d)"
			% [int(rozklad["pocitano"]), int(rozklad["nejvyssi"]), int(rozklad["diagonala"])])
	t._check(typeof(klic) == TYPE_INT and int(klic) > k_na,
		"app.world_view: klic hrace je ZA statikem na sve dlazdici (hrac %d > statik %d)"
			% [int(klic), k_na])
	# 3 diagonaly dal se stejnym `z` = 0 uz je ZA hracem (hranice pravidla).
	t._check(int(klic) < sort.sort_key({"kind": "static", "x": 13, "y": 20, "z": 0}),
		"app.world_view: klic hrace je PRED statikem o 3 diagonaly dal se z=0")
	# 7a) ⚠ 19. session - ZALOHA PRO PRAZDNY SEZNAM. Kdyz seznam nema ani jeden
	#     objekt, klic hrace se pocita z `render.sort.klic_nad_diagonalou` (horni
	#     mez diagonaly). Kdyby vracel nulu (nebo cokoli nizkeho), poslal by hrace
	#     PRED vsechno, co se teprve objevi. Meri se to na PRAZDNEM seznamu a na
	#     OBOU stranach: vysledek musi byt vetsi nez kazdy objekt na diagonale
	#     hrace a mensi nez objekt o 3 diagonaly dal.
	view._chunk._list = []
	view._chunk._built = true
	var klic_prazdny = view.call("_klic_hrace")
	t._check(int(klic_prazdny) > sort.sort_key({"kind": "static", "x": 10, "y": 20, "z": 127}),
		"app.world_view: pri prazdnem seznamu je klic hrace nad celou svoji diagonalou (%d > %d)"
			% [int(klic_prazdny), sort.sort_key({"kind": "static", "x": 10, "y": 20, "z": 127})])
	t._check(int(klic_prazdny) < sort.sort_key({"kind": "static", "x": 13, "y": 20, "z": -128}),
		"app.world_view: pri prazdnem seznamu zustava klic hrace pred vzdalenou diagonalou (%d < %d)"
			% [int(klic_prazdny), sort.sort_key({"kind": "static", "x": 13, "y": 20, "z": -128})])

	# 7b) ⚠ V2 (2026-10-07): POSUN POSTAVY MEZI DLAZDICEMI. `set_player_offset`
	#     posune KRESLENI postavy, i kdyz `player.pos` je porad stara dlazdice
	#     (presne to dela reference: `Mobile.cs:776-782` kresli `Offset`,
	#     `:836-844` commitne dlazdici az na konci kroku). Meri se to na
	#     `player_ground_position()` - to je funkce, kterou `_draw_player` vola.
	#     ⚠ 19. session: pri zoomu != 1 se pozice zaokrouhluje na mrizku
	#     obrazovky (V5), takze se meri PRESNE pri zoomu 1,0 a jinak vlastnost
	#     "posun je cely pocet pixelu obrazovky a velikost zustava".
	view.nastav_zoom(1.0)
	var zakladni: Vector2 = view.player_ground_position()
	view.set_player_offset(Vector2(11.0, -7.0))
	var posunuty: Vector2 = view.player_ground_position()
	t._check(posunuty - zakladni == Vector2(11.0, -7.0),
		"app.world_view: posun kroku se pricte ke kresleni postavy pri zoomu 1,0 (%s -> %s, rozdil %s)"
			% [str(zakladni), str(posunuty), str(posunuty - zakladni)])
	view.nastav_zoom(zoom_vychozi)
	view.set_player_offset(Vector2.ZERO)
	var zakladni_z: Vector2 = view.player_ground_position()
	view.set_player_offset(Vector2(11.0, -7.0))
	var posunuty_z: Vector2 = view.player_ground_position()
	var rozdil_z: Vector2 = posunuty_z - zakladni_z
	var obrazovy_rozdil: Vector2 = rozdil_z * view.zoom
	t._check(absf(obrazovy_rozdil.x - roundf(obrazovy_rozdil.x)) < 0.001 \
			and absf(obrazovy_rozdil.y - roundf(obrazovy_rozdil.y)) < 0.001 \
			and absf(rozdil_z.x - 11.0) <= 1.0 / view.zoom \
			and absf(rozdil_z.y + 7.0) <= 1.0 / view.zoom,
		"app.world_view: pri zoomu %s je posun postavy cely pocet pixelu obrazovky (%s -> %s) a zustava v mezich"
			% [str(view.zoom), str(rozdil_z), str(obrazovy_rozdil)])
	t._check(int(hrac.pos.x) == 10 and int(hrac.pos.y) == 20,
		"app.world_view: pri posunu se dlazdice postavy NEMENI (pos %s)" % str(hrac.pos))
	view.set_player_offset(Vector2.ZERO)
	t._check(view.player_ground_position() == zakladni_z,
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
	# 8c) ⚠ 19. session (V1) - HRANICE TOHOTO PRAVIDLA, MERENA NA OBA SMERY.
	#     Klic hrace je od teto session "nejvetsi klic objektu na diagonale hrace
	#     a blizsi, +1" (aby ho neprekryl statik na jeho vlastni dlazdici a aby
	#     pres nej neslo prkno mostu o diagonalu vpred). To ma dusledek, ktery se
	#     NESMI zamlcet: statik o JEDNU diagonalou dal se muze dostat PRED hrace
	#     uz pri strednim `z` (namEReno: hrac 8 009 506 vs statik o 1 diagonalou
	#     dal se `z = 127` ma 8 009 466, tedy je PRED hracem). Proto se tady meri
	#     to, co plati vzdy: statik na TEZE diagonale je pred hracem a statik
	#     o DVA diagonaly dal se stejnym `z` je za nim.
	var strecha_dva := {"kind": "static", "x": 11, "y": 21, "z": z_max}
	t._check(sort.sort_key(strecha_dva) > int(klic),
		"app.world_view: statik o 2 diagonaly dal s nejvyssim `z` jde ZA hracem (%d > %d)"
			% [sort.sort_key(strecha_dva), int(klic)])

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

	# 11b) ⚠ task-5: BARVA SVAHU pro PUVODNI cestu (`_draw_slope`) se pocita
	# z NORMALY svahu - a to TOUTEZ funkci jako dávka (`slope_barva` ->
	# `chunk_mesh.svah_barva`), aby se obe cesty NEMOHLY rozejit (18. session:
	# presne to byla vada "ruzne svetle svahy"). Reference: `IsometricWorld.fx:14`
	# (`LIGHT_DIRECTION = (0,1,1)`) a `:60-69` (`get_light`); normala je rovina
	# ctyr rohu (`Land.CalculateNormal`, `Land.cs:164-238`). Jas si test pocita
	# SAM (nezavisly prepis), ne ctenim z mereneho modulu.
	# ROVNA plocha = identita: presne puvodni `SVAH_BARVA` (0.85355339).
	var svah_barva_konst: Color = Lib.consts_at("res://render/chunk_mesh.gd").get(
		"SVAH_BARVA", Color.WHITE)
	t._check(script.slope_barva(rovny_obj) == svah_barva_konst,
		"app.world_view: _draw_slope na ROVNE plose vraci PRESNE puvodni barvu "
		+ "(namEReno %s vs %s)" % [str(script.slope_barva(rovny_obj)), str(svah_barva_konst)])
	var n_t := Vector3(0.0, -krok, zs * 20.0)
	var n_r := Vector3(krok, 0.0, zs * 16.0)
	var n_b := Vector3(0.0, krok, zs * 20.0)
	var n_l := Vector3(-krok, 0.0, zs * 20.0)
	# Diagonaly (soucet normal obou trojuhelniku) - stejne jako v modulu.
	var n_svah: Vector3 = (n_r - n_l).cross(n_b - n_t).normalized()
	var jas_ref: float = maxf(n_svah.dot(Vector3(0.0, 1.0, 1.0).normalized()), 0.0) / 2.0 + 0.5
	var barva_svah: Color = script.slope_barva(svah_obj)
	t._check(is_equal_approx(barva_svah.r, jas_ref)
		and absf(barva_svah.r - svah_barva_konst.r) > 0.001
		and barva_svah.r >= 0.0 and barva_svah.r <= 1.0 and barva_svah.a == 1.0,
		"app.world_view: _draw_slope na SVAHU pocita barvu z NORMALY (namEReno %.6f, reference %.6f, rovina %.8f)"
			% [barva_svah.r, jas_ref, svah_barva_konst.r])

	# 12) M9 (2026-10-08): DAVKA JE ZAPOJENA, ne mrtvy kód. `_priprav_mesh()`
	#     postavi `render.chunk_mesh` z TOHO SAMEHO seznamu a `mesh_stats()` to
	#     rekne cislem; kdyby se stavba preskocila, zustane prazdny slovnik.
	#     (Kresleni `_draw()` se v headless testu volat NEDÁ - Godot dovoli
	#     `draw_*` jen v NOTIFICATION_DRAW, takze se meri priprava dávky.)
	#     ⚠ 18. session: stavba je ROZDELENA do framu (`chunk_mesh.krok`,
	#     `_STAVBA_MS`), takze jeden `_priprav_mesh()` ji nedokonci - test ji
	#     dokonci smyckou a ZAZNAMENA, kolik framu to bylo (kdyby se stavba
	#     nikdy nedokoncila, spadne to na `stav_davky() != 0`).
	view.look_at_tile(Vector2i(1495, 1630), 0)
	var framu_stavby: int = 0
	for i in 400:
		view.call("_priprav_mesh")
		# ⚠ Pocita se, v kolika framech stavba OPRAVDU bezela (`stavi_se`), ne
		# kolik probehlo volani - samotny `hold` (2 framy) by dal "vice framu"
		# i tehdy, kdyby se cela stavba udelala v jednom (mutační test na to
		# upozornil: "stavba se nedeli do framu" prosla).
		if bool(view.call("stavi_se")):
			framu_stavby += 1
		if int(view.call("stav_davky")) == 0:
			break
	t._check(int(view.call("stav_davky")) == 0 and framu_stavby > 1,
		"app.world_view: dávka se stavi PO CASTECH a dokonci se (%d framu, stav %s)"
			% [framu_stavby, str(view.call("stav_davky"))])
	var davka: Dictionary = view.mesh_stats()
	t._check(not davka.is_empty() and int(davka.get("kvadru", 0)) > 0,
		"app.world_view: M9 dávka se postavi (_priprav_mesh) a ma kvadry "
		+ "(namEReno %s kvadru z %s objektu seznamu)"
			% [str(davka.get("kvadru")), str(view.visible_count())])
	t._check(int(davka.get("kvadru", -1)) == view.visible_count(),
		"app.world_view: dávka ma kvadr na KAZDY objekt seznamu (%s vs %s)"
			% [str(davka.get("kvadru")), str(view.visible_count())])

	# 12b) ⚠ 19. session - VYMENA TEXTUR ZA BEHU (`nastav_vymenu`). Je to
	#      pripraveny hacek pro budouci vymenu assetu (a pro sondu
	#      `_analyza/p22-sbs-hra.gd`); dnes je VYPNUTY (prazdny slovnik), takze
	#      se chovani hry nemeni. Test meri OBA smery:
	#        * zapnuti vymeny se preda DÁVCE i ulozi do view (jinak by se
	#          vymena projevila jen na puvodni ceste a na svazich ne),
	#        * vypnuti ji zase vrati na prazdno.
	#      Textura je `ImageTexture` vytvorena v testu - nic se necte z disku.
	var obrazek_vymeny := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	obrazek_vymeny.fill(Color(1.0, 0.0, 0.0, 1.0))
	var tex_vymeny := ImageTexture.create_from_image(obrazek_vymeny)
	view.nastav_vymenu({3: tex_vymeny})
	var v_davce: int = view.get("_mesh").vymena.size()
	t._check(int(view.get("vymena_textur").size()) == 1 and v_davce == 1,
		"app.world_view: nastav_vymenu preda nahradu i dávce (view %d, dávka %d)"
			% [int(view.get("vymena_textur").size()), v_davce])
	view.nastav_vymenu({})
	t._check(int(view.get("vymena_textur").size()) == 0
		and int(view.get("_mesh").vymena.size()) == 0,
		"app.world_view: prazdna vymena vypne nahrady i v dávce")

	# 13) uvolneni uzlu: `free()` (ne queue_free) - zbyly uzel shodi cely beh
	view.free()
	t._check(not is_instance_valid(view),
		"app.world_view: uzel je po testu uvolneny (is_instance_valid == false)")
	scena.free()
