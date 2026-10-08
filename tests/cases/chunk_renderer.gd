extends RefCounted
# render.chunk - kreslici seznam viditelnych bloku (granule render.chunk;
# docs/02 §2.4; soubor render/chunk_renderer.gd).
#
# CO SE MERI (docs/09 §9.4 - chovani, ne "soubor existuje"):
#   * `visible(center, tiles_x, tiles_y)` projde PRAVE oblast
#     `Rect2i(center - pulka, tiles_x, tiles_y)` a vrati ji v `cover()`,
#   * land dostane sve `z` a `art_id` == dlazdice, statik dostane
#     `art_id == tile + 0x4000` (TILEDATA id z mapy -> ART id, viz
#     `sim/entity/item.gd`) a `offset` z `render.textures`,
#   * statiky MIMO oblast se nepridaji (blok se prochazi cely, filtruje se
#     podle `area.has_point`) - kdyby filtr chybel, pribudou stovky objektu,
#   * `screen_position` je `core.iso.to_screen(x, y, z) - offset`,
#   * cache: stejny pohled vraci TUTEZ instanci seznamu, `invalidate()` ji
#     zahodi (jinak by se po presunu hrace kreslil stary pohled).
#
# ASSETY (`assets/uo/` je v .gitignore): offline cast pracuje se STUBEM mapy
# i textur, takze v CI bez assetu se API meri taky (a case nikdy neskonci
# s 0 kontrol). Cast nad realnymi daty se hlasi pojmenovane NEMERENO, kdyz
# assety na disku NEJSOU - chybejici data nejsou vada kódu, ale NESMI byt
# ticha. Kdyz assety na disku JSOU a nejdou nacist, je to vada a case
# SPADNE (`t._pending`) - viz pravidla v zadani task-1.
#
# Ktere kontroly proběhnou bez assetu: vsechny od "1)" do "6)" (stub).
# Kontroly "7)" a "8)" chteji `assets/uo/manifest.json` + `world/map0.*`.
#
# CESTA K MERENEMU SOUBORU JE VSTUP (`-- --chunk-script=<cesta>`, konvence
# jako u `tests/cases/render_sort.gd`): `tools/gates/mutace-tests.py` vraci
# vadu do KOPIE souboru a pousti ji pres tenhle prepinac, takze kontroly maji
# trvaly mutacni dukaz. Neexistujici cesta musi case SHODIT (`t._pending`).

const Lib = preload("res://tests/lib.gd")
const Sort = preload("res://render/sort.gd")
const Iso = preload("res://core/iso.gd")

const CHUNK_SCRIPT := "res://render/chunk_renderer.gd"
const MAP_SCRIPT := "res://sim/world/map.gd"
const TEXTURES_SCRIPT := "res://render/texture_cache.gd"
const REAL_MAP := "res://assets/uo/world/map0"
const REAL_MANIFEST := "res://assets/uo/manifest.json"
const ITEM_OFFSET := 0x4000
const BRITAIN := Vector2i(1495, 1630)
const VIEW_X := 64
const VIEW_Y := 48


class FakeMap:
	# Stejne rozhrani jako `sim/world/map.gd` - jen to, co `render.chunk` vola.
	var land_tile: int = 5
	var land_rect: Rect2i = Rect2i()
	var statics: Dictionary = {}     # Vector2i(blok) -> Array zaznamu (lokalni x,y)

	func land_at(x: int, y: int) -> int:
		return land_tile if land_rect.has_point(Vector2i(x, y)) else -1

	func z_at(x: int, y: int) -> int:
		return (x + y) % 7 - 3       # z se lisi, aby se dalo overit, ze se neprehazuje

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x / 8, y / 8), [])


class FakeTextures:
	var offsets: Dictionary = {}

	func offset(art_id: int) -> Vector2i:
		var v: Vector2i = offsets.get(art_id, Vector2i.ZERO)
		return v


class FakeTiledata:
	# Jen to, co `render.chunk` vola: `texture(tile)` = TexID pro texturu svahu.
	# Vraci `tile + 100`, aby se poznalo, ze se opravdu pouzil VYSLEDEK tiledata
	# (kdyby se do seznamu dala konstanta 0, test by to nerozlisil).
	# `flags`/`height` potrebuje `priority_z` statiku (vada V6): test si pres
	# ne nastavi PODLAHU (background) a statik s vyskou, aby se dalo merit, ze
	# se poradova vyska pocita z tiledata a ne z `z`.
	var background: int = 0x00000001
	var vysky: Dictionary = {}          # art_id -> vyska
	var podlahy: Array = []             # art_id, ktere jsou podlaha
	var strechy: Dictionary = {}        # art_id -> flagy strechy/stropu (18. session)

	func texture(tile: int) -> int:
		return tile + 100

	func flags(art_id: int) -> int:
		if strechy.has(art_id):
			return int(strechy[art_id])
		return background if podlahy.has(art_id) else 0

	func height(art_id: int) -> int:
		return int(vysky.get(art_id, 0))


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _keys(objects: Array, sort) -> Array:
	var out: Array = []
	for obj in objects:
		out.append(sort.sort_key(obj))
	return out


func _nesestupne(keys: Array) -> bool:
	for i in range(1, keys.size()):
		if keys[i - 1] > keys[i]:
			return false
	return true


func run(t) -> void:
	var cesta: String = _arg("chunk-script", CHUNK_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("render.chunk NENI HOTOVA: " + cesta + " chybi nebo nejde nacist")
		return
	var consts: Dictionary = Lib.consts_at(cesta)
	var sort = Sort.new()
	var iso = Iso.new()

	# --- 1) offline: stub mapy -------------------------------------------------
	# Oblast pro stred (10,10) a 8x8 dlazdic je x,y v 6..13. Land je v 3x3
	# (9 dlazdic), statiky jsou ve DVOU blocich, z toho dva zaznamy mimo oblast.
	var map := FakeMap.new()
	map.land_rect = Rect2i(6, 6, 3, 3)
	map.statics[Vector2i(0, 0)] = [
		{"tile": 500, "x": 7, "y": 7, "z": 3, "hue": 0},     # svet 7,7  -> v oblasti
		{"tile": 501, "x": 5, "y": 5, "z": 3, "hue": 0},     # svet 5,5  -> mimo
		{"tile": 502, "x": 7, "y": 0, "z": 3, "hue": 0},     # svet 7,0  -> mimo
	]
	map.statics[Vector2i(1, 1)] = [
		{"tile": 600, "x": 0, "y": 0, "z": 8, "hue": 0},     # svet 8,8  -> v oblasti
	]
	var textures := FakeTextures.new()
	textures.offsets[500 + ITEM_OFFSET] = Vector2i(2, 3)
	textures.offsets[600 + ITEM_OFFSET] = Vector2i(0, 9)

	var chunk = script.new(map, textures)
	var studene: Dictionary = chunk.counts()
	t._check(int(studene.get("land", -1)) == 0 and int(studene.get("static", -1)) == 0
		and not chunk.is_built(),
		"render.chunk: pred prvnim visible() je counts 0/0 a is_built() false "
		+ "(namEReno %s, is_built %s)" % [str(studene), str(chunk.is_built())])

	var center := Vector2i(10, 10)
	var list: Array = chunk.visible(center, 8, 8)
	var counts: Dictionary = chunk.counts()
	t._check(list.size() == 11 and int(counts.get("land", -1)) == 9
		and int(counts.get("static", -1)) == 2,
		"render.chunk: 8x8 pohled da 9 land (3x3) + 2 statiky ve dvou blocich "
		+ "(namEReno %d objektu, land %s, static %s)"
			% [list.size(), str(counts.get("land")), str(counts.get("static"))])
	t._check(counts.size() == 3 and counts.has("land") and counts.has("static")
		and counts.has("skryto"),
		"render.chunk: counts() ma land, static a skryto (18. session: pocita se i to, "
		+ "co se skrylo kvuli strese; namEReno %s)" % str(counts.keys()))

	# --- 2) oblast a filtr statiku --------------------------------------------
	t._check(chunk.cover() == Rect2i(6, 6, 8, 8) and chunk.is_built(),
		"render.chunk: cover() je Rect2i(stred - pulka, 8x8) (namEReno %s)"
			% str(chunk.cover()))
	# Ze ctyr zaznamu v blocich jsou v oblasti jen DVA - kdyby filtr
	# `area.has_point` chybel, byly by tu vsechny ctyri (a stovky u realne mapy).
	var mimo := 0
	for obj in list:
		if str(obj["kind"]) == "static":
			var svet := Vector2i(int(obj["x"]), int(obj["y"]))
			if not chunk.cover().has_point(svet):
				mimo += 1
	t._check(mimo == 0, "render.chunk: statik mimo oblast se neprida (namEReno %d mimo)" % mimo)

	# --- 2b) `priority_z` statiku (vada V6) -----------------------------------
	# Podlaha (`IsBackground`) jde -1 a statik s vyskou +1 (ClassicUO `PriorityZ`,
	# `Chunk.cs:246-272`). Proto se plocha dlazdice mostu kresli PRED zabradlim,
	# i kdyz maji STEJNE `z` - a to i kdyz je v souboru mapy zabradli prvni
	# (presne to namERilo 2026-10-07 na molu u Britannie: 30 dlazdic, kde prkno
	# prekrylo zabradli).
	var td := FakeTiledata.new()
	td.podlahy = [500 + ITEM_OFFSET]
	td.vysky = {501 + ITEM_OFFSET: 20}
	var map2 := FakeMap.new()
	map2.land_rect = Rect2i(6, 6, 3, 3)
	map2.statics[Vector2i(0, 0)] = [
		{"tile": 501, "x": 7, "y": 7, "z": 10, "hue": 0},   # zabradli: z 10 + 1 = 11
		{"tile": 500, "x": 7, "y": 7, "z": 10, "hue": 0},   # podlaha:  z 10 - 1 = 9
		{"tile": 502, "x": 6, "y": 6, "z": 10, "hue": 0},   # ani jedno: z 10
	]
	var chunk2 = script.new(map2, textures, td)
	var list2: Array = chunk2.visible(center, 8, 8)
	var priority := {}
	var poradi: Array = []
	for obj in list2:
		if str(obj["kind"]) == "static":
			priority[int(obj["art_id"])] = int(obj["priority_z"])
			poradi.append(int(obj["art_id"]) - ITEM_OFFSET)
	t._check(priority.get(500 + ITEM_OFFSET, 0) == 9
			and priority.get(501 + ITEM_OFFSET, 0) == 11
			and priority.get(502 + ITEM_OFFSET, 0) == 10,
		"render.chunk: priority_z = z, -1 za podlahu, +1 za vysku (namEReno %s)"
		% str(priority))
	t._check(poradi.find(500) < poradi.find(501),
		"render.chunk: podlaha mostu se kresli PRED zabradlim na teze dlazdici"
		+ " (namEReno poradi %s)" % str(poradi))
	# bez tiledata (konstruktor ji smi dostat null) zustava razeni podle `z`
	var chunk3 = script.new(map2, textures)
	var list3: Array = chunk3.visible(center, 8, 8)
	var priority3 := {}
	for obj in list3:
		if str(obj["kind"]) == "static":
			priority3[int(obj["art_id"])] = int(obj["priority_z"])
	t._check(priority3.get(500 + ITEM_OFFSET, 0) == 10
			and priority3.get(501 + ITEM_OFFSET, 0) == 10,
		"render.chunk: bez tiledata je priority_z = z (namEReno %s)" % str(priority3))

	# --- 3) tvar prvku a preklad TILEDATA -> ART id ---------------------------
	var chybi: Array = []
	var art_spatne := 0
	var offset_spatne := 0
	var z_spatne := 0
	for obj in list:
		for klic in ["kind", "x", "y", "z", "art_id", "offset"]:
			if not obj.has(klic):
				chybi.append(klic)
		var x: int = int(obj["x"])
		var y: int = int(obj["y"])
		if str(obj["kind"]) == "land":
			if int(obj["art_id"]) != map.land_tile or obj["offset"] != Vector2i.ZERO:
				art_spatne += 1
			if int(obj["z"]) != map.z_at(x, y):
				z_spatne += 1
		elif str(obj["kind"]) == "static":
			# art_id MUSI byt tiledata + 0x4000 (literal, ne konstanta modulu:
			# jinak by se vada v konstante merila sama sebou)
			var hledany: int = int(obj["art_id"]) - ITEM_OFFSET
			if hledany != 500 and hledany != 600:
				art_spatne += 1
			if obj["offset"] != textures.offset(int(obj["art_id"])):
				offset_spatne += 1
	t._check(chybi.is_empty() and art_spatne == 0,
		"render.chunk: kazdy prvek ma kind,x,y,z,art_id,offset a art_id je "
		+ "tile + 0x4000 (chybi %s, spatne art %d)" % [str(chybi), art_spatne])
	t._check(offset_spatne == 0 and z_spatne == 0,
		"render.chunk: offset je z textur a land ma z z mapy (spatne offset %d, z %d)"
			% [offset_spatne, z_spatne])
	t._check(int(consts.get("ITEM_OFFSET", 0)) == ITEM_OFFSET,
		"render.chunk: ITEM_OFFSET je 0x4000 (namEReno %s)" % str(consts.get("ITEM_OFFSET")))

	# --- 3b) SVAH: texmap a vysky rohu (2026-10-07) ---------------------------
	# Kresleni pozna svah z `z_corners`: roh dlazdice ma vysku SOUSEDNI dlazdice
	# (vychodni = pravy, jizni = levy, jihovychodni = dolni; ClassicUO
	# `Land.cs:113-121`). Test to meri na stubu, kde `z_at` je vzorec
	# `(x + y) % 7 - 3` - kazdy roh se tedy da spocitat NEZAVISLE.
	var se_texmapem = script.new(map, textures, FakeTiledata.new())
	var seznam_tm: Array = se_texmapem.visible(center, 8, 8)
	var rohy_ok := 0
	var rohy_spatne := 0
	var texmap_ok := 0
	var landu := 0
	for obj in seznam_tm:
		if str(obj["kind"]) != "land":
			continue
		landu += 1
		var lx: int = int(obj["x"])
		var ly: int = int(obj["y"])
		var cekane := [map.z_at(lx, ly), map.z_at(lx + 1, ly),
			map.z_at(lx, ly + 1), map.z_at(lx + 1, ly + 1)]
		if obj.get("z_corners", []) == cekane and int(obj["z"]) == int(cekane[0]):
			rohy_ok += 1
		else:
			rohy_spatne += 1
		if int(obj.get("texmap", 0)) == map.land_tile + 100:
			texmap_ok += 1
	t._check(landu == 9 and rohy_ok == 9 and rohy_spatne == 0,
		"render.chunk: z_corners = [vlastni, vychodni, jizni, jihovychodni] vyska dlazdice "
		+ "(%d z %d OK, %d spatne)" % [rohy_ok, landu, rohy_spatne])
	t._check(texmap_ok == 9,
		"render.chunk: texmap je TexID z tiledata (%d z %d)" % [texmap_ok, landu])
	# Bez tiledata (starsi volani) se texmap nedava - kresli se land art.
	var bez_tiledata = script.new(map, textures)
	var bez_tm: Array = bez_tiledata.visible(center, 8, 8)
	var bez_texmapu := 0
	for obj in bez_tm:
		if str(obj["kind"]) == "land" and int(obj.get("texmap", -1)) == 0:
			bez_texmapu += 1
	t._check(bez_texmapu == 9,
		"render.chunk: bez tiledata je texmap 0 (%d z 9) - kresli se land art" % bez_texmapu)

	# --- 4) screen_position je iso - offset -----------------------------------
	var geometrie := 0
	for obj in list:
		var ocekavana: Vector2 = iso.to_screen(int(obj["x"]), int(obj["y"]), int(obj["z"])) \
			- Vector2(obj["offset"])
		if chunk.screen_position(obj) != ocekavana:
			geometrie += 1
	t._check(geometrie == 0,
		("render.chunk: screen_position = to_screen(x,y,z) - offset pro vsech %d prvku "
		+ "(neshoda %d)") % [list.size(), geometrie])

	# --- 5) razeni je hotove (predava se do render.sort) ----------------------
	var klice := _keys(list, sort)
	t._check(_nesestupne(klice),
		"render.chunk: vraceny seznam je serazeny podle render.sort (klicu %d)" % klice.size())
	var land_klice := _keys(list.filter(func(o): return str(o["kind"]) == "land"), sort)
	t._check(land_klice.size() == 9 and land_klice[0] == sort.sort_key(
		{"kind": "land", "x": 6, "y": 6, "z": map.z_at(6, 6)}),
		"render.chunk: prvni land je (6,6) s klicem z render.sort (namEReno %s)"
			% str(land_klice[0] if land_klice.size() > 0 else null))

	# --- 6) cache a invalidate ------------------------------------------------
	var znovu: Array = chunk.visible(center, 8, 8)
	t._check(is_same(list, znovu),
		"render.chunk: druhe visible() se stejnym pohledem vraci TUTEZ instanci (cache)")
	chunk.invalidate()
	t._check(not chunk.is_built(),
		"render.chunk: invalidate() zahodi seznam (is_built %s)" % str(chunk.is_built()))
	var po_invalidaci: Array = chunk.visible(center, 8, 8)
	t._check(po_invalidaci.size() == list.size() and not is_same(list, po_invalidaci),
		"render.chunk: po invalidate() se seznam postavi znovu (namEReno %d objektu, nova instance %s)"
			% [po_invalidaci.size(), str(not is_same(list, po_invalidaci))])
	var prazdna: Array = chunk.visible(Vector2i(100, 100), 8, 8)
	var prazdne_counts: Dictionary = chunk.counts()
	t._check(prazdna.is_empty() and int(prazdne_counts.get("land", -1)) == 0
		and int(prazdne_counts.get("static", -1)) == 0,
		"render.chunk: prazdna oblast vraci prazdny seznam a counts 0/0 (namEReno %s)"
			% str(prazdne_counts))

	# --- 7) realna data: jen kdyz assety na disku jsou ------------------------
	var chybi_assety: Array = []
	if not FileAccess.file_exists(REAL_MANIFEST):
		chybi_assety.append(REAL_MANIFEST)
	if not FileAccess.file_exists(REAL_MAP + ".meta.json"):
		chybi_assety.append(REAL_MAP + ".meta.json")
	if not chybi_assety.is_empty():
		print("[test] NEMERENO: render.chunk nad realnymi assety - chybi ",
			", ".join(chybi_assety))
		return
	var map_script = Lib.script_at(MAP_SCRIPT)
	var tex_script = Lib.script_at(TEXTURES_SCRIPT)
	if map_script == null or tex_script == null:
		t._pending("render.chunk NEMEREN: sim/world/map.gd nebo render/texture_cache.gd nejde nacist")
		return
	var real_map = map_script.new(REAL_MAP)
	if real_map.width() <= 0:
		t._pending("render.chunk NEMEREN: %s.meta.json je na disku, ale mapa se nenacetla (width %d)"
			% [REAL_MAP, real_map.width()])
		return
	var real_tex = tex_script.new(REAL_MANIFEST)
	var sprity: int = int(real_tex.stats().get("sprites", 0))
	if sprity <= 0:
		t._pending("render.chunk NEMEREN: %s je na disku, ale dal 0 spritu" % REAL_MANIFEST)
		return

	var real_chunk = script.new(real_map, real_tex)
	var real_list: Array = real_chunk.visible(BRITAIN, VIEW_X, VIEW_Y)
	var real_counts: Dictionary = real_chunk.counts()
	t._check(real_list.size() > 0 and int(real_counts.get("land", 0)) > 0
		and int(real_counts.get("static", 0)) > 0
		and real_list.size() == int(real_counts.get("land", 0)) + int(real_counts.get("static", 0)),
		"render.chunk: Britanie da tisice objektu (namEReno %d = land %s + static %s, spritu %d)"
			% [real_list.size(), str(real_counts.get("land")),
				str(real_counts.get("static")), sprity])
	t._check(_nesestupne(_keys(real_list, sort)),
		"render.chunk: i realny seznam je serazeny podle render.sort (%d objektu)" % real_list.size())

	# --- 8) realny preklad TILEDATA -> ART id + offset z manifestu ------------
	# Pro kazdy statik v seznamu se najde zaznam v mape (blok se cte jednou)
	# a overi se `art_id == tile + 0x4000` - to je ta smlouva dvou id prostoru,
	# kterou `sim/entity/item.gd` popisuje.
	var bloky: Dictionary = {}
	var art_neshoda := 0
	var posun_neshoda := 0
	var statiku := 0
	var statik_mimo := 0
	for obj in real_list:
		if str(obj["kind"]) != "static":
			continue
		statiku += 1
		var x: int = int(obj["x"])
		var y: int = int(obj["y"])
		if not real_chunk.cover().has_point(Vector2i(x, y)):
			statik_mimo += 1
		var zaklad := Vector2i((x / 8) * 8, (y / 8) * 8)
		if not bloky.has(zaklad):
			bloky[zaklad] = real_map.statics_at(zaklad.x, zaklad.y)
		var nalezeno := false
		for record in bloky[zaklad]:
			if zaklad.x + int(record["x"]) == x and zaklad.y + int(record["y"]) == y:
				if int(record["tile"]) + ITEM_OFFSET == int(obj["art_id"]):
					nalezeno = true
		if not nalezeno:
			art_neshoda += 1
		if obj["offset"] != real_tex.offset(int(obj["art_id"])):
			posun_neshoda += 1
	t._check(statiku > 0 and art_neshoda == 0 and statik_mimo == 0,
		"render.chunk: art_id realnych statiku je tile + 0x4000 z mapy "
		+ "(statiku %d, neshod %d, mimo oblast %d)" % [statiku, art_neshoda, statik_mimo])
	t._check(posun_neshoda == 0,
		"render.chunk: offset realnych statiku je z manifestu (neshod %d z %d)"
			% [posun_neshoda, statiku])

	# --- 9) ⚠ 18. + 19. session: STROP PATRA A STŘECHA NAD HRÁČEM -----------
	# Vada uzivatele (19. session): "zobrazuje se patro nademnou, zdivo z patra,
	# zabradli, stul a postele" (V12/V16/V17). Reference
	# (`GameSceneDrawingSorting.cs:57-213` `UpdateMaxDrawZ()`) pocita strop
	# `_maxZ` a kresli jen objekty s `z < _maxZ` - tim zmizi CELE patro
	# (zdivo, okno, trabec, postel), ne jen strechy/stropy.
	#
	# Test meri OBA SMERY - brana, ktera jen ubira, je slepa:
	#   * zmizet MA: zdivo patra nad strojem, strecha nad hracem, strop patra,
	#   * ZUSTAT MUSI: statik v urovni hrace (zed) a PODLAHA, po ktere stoji.
	var f_roof: int = int(Lib.consts_at(cesta).get("F_ROOF", 0x10000000))
	var f_surface: int = int(Lib.consts_at(cesta).get("F_SURFACE", 0x200))
	var f_background: int = int(Lib.consts_at(cesta).get("F_BACKGROUND", 0x1))
	var f_wall: int = 0x00000010
	var f_impassable: int = 0x00000040

	# Fixture "vysoka budova": hrac stoji v prizemi na (2,2), `z_at(2,2)` =
	# `(2+2) % 7 - 3` = 1. Nad nim je STROP (pochuzna podlaha patra, art 20,
	# `Surface|Background`) ve vysce 40, nad strojem ZDIVO patra (art 21,
	# `Wall|Impassable`), PRESNE ve vysce stropu ZDIVO (art 24 - to je hranice
	# `z >= strop` z reference), v jeho urovni ZED (art 22) a pod nim PODLAHA,
	# po ktere stoji (art 23, `Surface|Background`, z = 1).
	var mapa3 := FakeMap.new()
	mapa3.land_rect = Rect2i(0, 0, 8, 8)
	mapa3.statics[Vector2i(0, 0)] = [
		{"tile": 7, "x": 2, "y": 2, "z": 40, "hue": 0},      # strecha NAD hracem
		{"tile": 20, "x": 2, "y": 2, "z": 40, "hue": 0},     # STROP patra (kandidat)
		{"tile": 21, "x": 3, "y": 3, "z": 43, "hue": 0},     # ZDIVO patra nad strojem
		{"tile": 24, "x": 4, "y": 4, "z": 40, "hue": 0},     # ZDIVO presne ve stropu
		{"tile": 22, "x": 2, "y": 3, "z": 10, "hue": 0},     # zed v urovni hrace
		{"tile": 23, "x": 2, "y": 2, "z": 1, "hue": 0},      # podlaha, po ktere stoji
		{"tile": 8, "x": 5, "y": 5, "z": 40, "hue": 0},      # jina dlazdice, taky nad
	]
	var td3 := FakeTiledata.new()
	td3.strechy[7 + ITEM_OFFSET] = f_roof                     # strecha (Roof flag)
	td3.strechy[8 + ITEM_OFFSET] = f_surface | f_background
	td3.strechy[20 + ITEM_OFFSET] = f_surface | f_background  # strop patra
	td3.strechy[21 + ITEM_OFFSET] = f_wall | f_impassable     # zdivo
	td3.strechy[24 + ITEM_OFFSET] = f_wall | f_impassable     # zdivo ve stropu
	td3.strechy[22 + ITEM_OFFSET] = f_wall | f_impassable     # zed v urovni hrace
	td3.strechy[23 + ITEM_OFFSET] = f_surface | f_background  # podlaha pod hracem
	var chunk_stres = script.new(mapa3, FakeTextures.new(), td3)
	t._check(chunk_stres.je_strop(7 + ITEM_OFFSET) and chunk_stres.je_strop(8 + ITEM_OFFSET)
		and chunk_stres.je_strop(20 + ITEM_OFFSET)
		and not chunk_stres.je_strop(21 + ITEM_OFFSET)
		and not chunk_stres.je_strop(22 + ITEM_OFFSET),
		"render.chunk: je_strop() = Roof flag nebo Surface|Background (zdivo NE)")
	t._check(chunk_stres.je_roof(7 + ITEM_OFFSET) and not chunk_stres.je_roof(8 + ITEM_OFFSET),
		"render.chunk: je_roof() je jen `Roof` flag (namEReno %s/%s)"
			% [str(chunk_stres.je_roof(7 + ITEM_OFFSET)),
				str(chunk_stres.je_roof(8 + ITEM_OFFSET))])
	var z_hrace: int = int(mapa3.z_at(2, 2))
	# STROP PATRA = `z` nejblizsiho statiku nad `hrac + 14` (reference
	# `UpdateMaxDrawZ()`); tady strop (art 20) i strecha (art 7) na z=40.
	var strop: Dictionary = chunk_stres.strop_patra(2, 2, z_hrace)
	t._check(int(strop["maxz"]) == 40 and bool(strop["kandidat"]),
		"render.chunk: strop_patra() = 40 z pochuzne podlahy patra (namEReno %s)" % str(strop))
	t._check(not chunk_stres.pod_strechou(2, 2, z_hrace + 30),
		"render.chunk: NAD strechou (z=%d) se nekryje" % (z_hrace + 30))
	t._check(chunk_stres.pod_strechou(2, 2, z_hrace),
		"render.chunk: pod strechou (z=%d, strecha z=40) se kryje" % z_hrace)
	var zmena: bool = chunk_stres.nastav_hrace(2, 2, z_hrace)
	t._check(zmena and chunk_stres.skryt_strechy and chunk_stres.max_draw_z() == 40,
		"render.chunk: nastav_hrace() hlasi zmenu a strop patra (max_draw_z %d)"
			% chunk_stres.max_draw_z())
	var sez: Array = chunk_stres.visible(Vector2i(2, 2), 8, 8)
	var v_seznamu: Dictionary = {}
	for obj in sez:
		if str(obj["kind"]) == "static":
			v_seznamu[int(obj["art_id"])] = int(obj["z"])
	# ZMIZET MA: strecha (7), strop patra (20), zdivo patra nad strojem (21),
	# zdivo PRESNE ve stropu (24) a jina dlazdice nad hracem (8).
	var zmizet: Array = [7, 20, 21, 24, 8]
	var zustaly_spatne: Array = []
	for t_id in zmizet:
		if v_seznamu.has(t_id + ITEM_OFFSET):
			zustaly_spatne.append(t_id)
	t._check(zustaly_spatne.is_empty() and int(chunk_stres.counts()["skryto"]) == 5,
		"render.chunk: cely strop patra (strop, zdivo, strecha) se ze seznamu VYPUSTI "
		+ "(zustaly %s, skryto %s)" % [str(zustaly_spatne),
			str(chunk_stres.counts()["skryto"])])
	# ZUSTAT MUSI: zed v urovni hrace (22) a podlaha, po ktere stoji (23).
	t._check(v_seznamu.has(22 + ITEM_OFFSET) and v_seznamu.has(23 + ITEM_OFFSET),
		"render.chunk: statik v urovni hrace a podlaha pod nim ZUSTAVAJI "
		+ "(v seznamu %s)" % str(v_seznamu))
	# a kdyz hrac odejde mimo, strop zmizi a vse se vrati
	t._check(chunk_stres.nastav_hrace(5, 4, z_hrace) and not chunk_stres.skryt_strechy
		and chunk_stres.max_draw_z() >= 100,
		"render.chunk: mimo kryti se `skryt_strechy` vraci na false a strop na %d"
			% chunk_stres.max_draw_z())
	var sez2: Array = chunk_stres.visible(Vector2i(2, 2), 8, 8)
	var statiku2: int = 0
	for obj in sez2:
		if str(obj["kind"]) == "static":
			statiku2 += 1
	t._check(statiku2 == 7 and int(chunk_stres.counts()["skryto"]) == 0,
		"render.chunk: bez kryti se kresli vsech 7 statiku (namEReno %d)" % statiku2)

	# --- 9b) STŘECHA BEZ `Surface` NAD HRÁČEM (18. session, ochrana) --------
	# Reference kandidat na strop je UZSI nez `je_strop`: strecha, ktera NEMA
	# `Surface` (`wooden shingles` flags 0x14002000, `thatch roof` 0x14006000),
	# strop NENASTAVI - namEReno 204 z 2970 dlazdic v Britanii
	# (`_analyza/p22-patra-sonda.txt`), kde by se vada 18. session vratila.
	# Test proto meri, ze i tehdy se strecha nad hracem VYPUSTI.
	var mapa4 := FakeMap.new()
	mapa4.land_rect = Rect2i(0, 0, 8, 8)
	mapa4.statics[Vector2i(0, 0)] = [
		{"tile": 7, "x": 2, "y": 2, "z": 40, "hue": 0},      # strecha bez Surface
	]
	var td4 := FakeTiledata.new()
	td4.strechy[7 + ITEM_OFFSET] = f_roof
	var chunk4 = script.new(mapa4, FakeTextures.new(), td4)
	var strop4: Dictionary = chunk4.strop_patra(2, 2, z_hrace)
	t._check(int(strop4["maxz"]) >= 100 and not bool(strop4["kandidat"]),
		"render.chunk: strecha bez `Surface` strop NENASTAVI (namEReno %s)" % str(strop4))
	t._check(chunk4.nastav_hrace(2, 2, z_hrace) and chunk4.skryt_strechy,
		"render.chunk: `pod_strechou()` kryti zapne i bez kandidata reference")
	var sez4: Array = chunk4.visible(Vector2i(2, 2), 8, 8)
	var statiku4: int = 0
	for obj in sez4:
		if str(obj["kind"]) == "static":
			statiku4 += 1
	t._check(statiku4 == 0 and int(chunk4.counts()["skryto"]) == 1,
		"render.chunk: strecha bez `Surface` nad hracem se VYPUSTI (statiku %d, skryto %s)"
			% [statiku4, str(chunk4.counts()["skryto"])])

	# --- 9c) BEZ KRYTÍ SE NESKRÝVÁ NIC (druhý směr brány) -------------------
	# Kdyz nad hracem nic neni, strop zustava `STROP_NIC` a seznam se NESMI
	# zmensit - jinak by brána jen ubírala a "oprava" by mohla smazat i to,
	# co videt ma.
	var mapa5 := FakeMap.new()
	mapa5.land_rect = Rect2i(0, 0, 8, 8)
	mapa5.statics[Vector2i(0, 0)] = [
		{"tile": 30, "x": 2, "y": 3, "z": 10, "hue": 0},     # zed v urovni hrace
		{"tile": 31, "x": 3, "y": 2, "z": 6, "hue": 0},      # nizky statik
	]
	var td5 := FakeTiledata.new()
	td5.strechy[30 + ITEM_OFFSET] = f_wall | f_impassable
	td5.strechy[31 + ITEM_OFFSET] = f_wall
	var chunk5 = script.new(mapa5, FakeTextures.new(), td5)
	var strop5: Dictionary = chunk5.strop_patra(2, 2, z_hrace)
	t._check(int(strop5["maxz"]) >= 100 and not bool(strop5["kandidat"]),
		"render.chunk: bez statiku nad hracem zustava strop %s" % str(strop5))
	chunk5.nastav_hrace(2, 2, z_hrace)
	var sez5: Array = chunk5.visible(Vector2i(2, 2), 8, 8)
	var statiku5: int = 0
	for obj in sez5:
		if str(obj["kind"]) == "static":
			statiku5 += 1
	t._check(statiku5 == 2 and int(chunk5.counts()["skryto"]) == 0
		and not chunk5.skryt_strechy,
		"render.chunk: pod otevrenym nebem se NESKRYVA nic (statiku %d, skryto %s)"
			% [statiku5, str(chunk5.counts()["skryto"])])

	# --- 9d) SCHODY ZUSTAVAJI VIDET (V17b: "nevim jak navigovat schodiste") --
	# Kreslici cast V17b: schod je statik se `Surface` (+ `Bridge`), ale NENI
	# `Roof` ani `Surface+Background` - takze ho ani `je_strop`, ani strop patra
	# nesmi vzit, kdyz je na TOM STROPE, po kterem se jde nahoru. Schod je proto
	# vys nez `hrac + 16` (18. session pravidlo na strechy) a niz nez strop
	# patra - presne jako schodiste v hradu (schody z 30..45, hrac na 20).
	# Kdyby se schod schoval, hrac nevi, kudy nahoru.
	var f_bridge: int = int(Lib.consts_at(cesta).get("F_BRIDGE", 0x400))
	var mapa6 := FakeMap.new()
	mapa6.land_rect = Rect2i(0, 0, 8, 8)
	mapa6.statics[Vector2i(0, 0)] = [
		{"tile": 40, "x": 2, "y": 3, "z": 20, "hue": 0},     # schod na mem patre
		{"tile": 41, "x": 4, "y": 4, "z": 40, "hue": 0},     # schod o patro vys
		{"tile": 20, "x": 2, "y": 2, "z": 40, "hue": 0},     # strop patra (kandidat)
	]
	var td6 := FakeTiledata.new()
	td6.strechy[40 + ITEM_OFFSET] = f_surface | f_bridge     # schod: Surface+Bridge
	td6.strechy[41 + ITEM_OFFSET] = f_surface | f_bridge
	td6.strechy[20 + ITEM_OFFSET] = f_surface | f_background
	var chunk6 = script.new(mapa6, FakeTextures.new(), td6)
	chunk6.nastav_hrace(2, 2, z_hrace)
	var sez6: Array = chunk6.visible(Vector2i(2, 2), 8, 8)
	var v6: Dictionary = {}
	for obj in sez6:
		if str(obj["kind"]) == "static":
			v6[int(obj["art_id"])] = int(obj["z"])
	t._check(v6.has(40 + ITEM_OFFSET) and not v6.has(41 + ITEM_OFFSET)
		and int(v6.get(40 + ITEM_OFFSET, -1)) == 20,
		"render.chunk: schod na mem patre ZUSTAVA, schod o patro vys se VYPUSTI "
		+ "(v seznamu %s)" % str(v6))
