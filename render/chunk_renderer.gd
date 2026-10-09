extends RefCounted
# Kreslici seznam pro viditelne bloky (granule render.chunk; docs/02 §2.4).
#
# Postup: pro kazdou dlazdici viditelne oblasti se prida `land` s jeho `z`;
# pro kazdy dotceny blok 8x8 se projdou VSICHNI jeho statiky a prevedou se
# z lokalnich `x`,`y` (0..7) na svetove. Hotovy seznam se preda
# `render.sort.draw_order`, takze se kresli v poradi (x+y) -> vrstva -> `z`.
# Kreslici uzel ho jen projde v tom poradi: `z_index` na to pouzit NELZE,
# klic roste do milionu a Godot bere jen -4096..4096 (docs/02 past P21).
#
# CACHE: seznam je pro dany pohled hotovy; `invalidate()` ho zahodi (vola ho
# `app/world_view.gd` pri zmene pohledu, pozdeji `sim.movement` pri zmene
# bloku). Textury se v seznamu NEDRZI - drzi je `render.textures` se stropem
# pameti; kdyby je drzel seznam, strop by nic neomezoval (viz hlavicka tam).
#
# TVAR PRVKU (je to zaroven vstup do `render.sort`, ktery chce `{kind,x,y,z}`):
#   {"kind": "land"|"static", "x": int, "y": int, "z": int,
#    "art_id": int, "offset": Vector2i}
# `offset` je posun z manifestu (`ox`,`oy`), ktery se odecte od dlazdice.
#
# LAND NAVIC (2026-10-07, svahy): `texmap` (TexID z tiledata) a `z_corners`
# [horni, pravy, levy, dolni] = vysky rohu dlazdice. Roh pouziva vysku
# SOUSEDNI dlazdice (vychodni pro pravy, jizni pro levy, jihovychodni pro
# dolni) - presne jako ClassicUO (`Land.cs:113-121` `ApplyStretch`). Kresleni
# z toho pozna, ze dlazdice lezi na SVAHU, a natáhne pres ni texmap; rovna
# plocha se kresli dal land artem. Bez toho zustavala v prechodu vysky seda
# dira (uzivatel: "kde je svah, tam neni tile").
#
# Pouziti:
#   var chunk = Chunk.new(map, textures)          # bez tiledata: texmap = 0
#   for obj in chunk.visible(center, 64, 48): ...

const Sort = preload("res://render/sort.gd")
const Iso = preload("res://core/iso.gd")
const Const = preload("res://core/const.gd")
const TiledataScript = preload("res://sim/world/tiledata.gd")
const ITEM_OFFSET: int = 0x4000
# `IsBackground` v tiledata: dlazdice je PODLAHA, ne prekazka. ClassicUO ji
# v `PriorityZ` odecita 1 (`Chunk.cs:246-272`), takze plocha mostu jde PRED
# jeho zabradli - bez toho se na molu u Britannie kreslilo zabradli pod
# dlazdicemi (namEReno 2026-10-07).
const F_BACKGROUND: int = 0x00000001
# ⚠⚠ 19. session (2026-10-08) - V12/V16/V17: "ZOBRAZUJE SE PATRO NADEMNOU,
# ZDIVO Z PATROVI, ZABRADLI, STUL A POSTELE Z PATRA".
#
# Do teto session se skryvalo JEN to, co je `je_strop` (Roof flag nebo
# Surface+Background) a vys nez `hrac_z + 16`. ZDIVO (`plaster wall`, `wooden
# wall`), `window`, `wooden beam`, `wooden post`, `bed` ani zabradli tim
# NEPROJDOU - takze se patro nad hracem kreslilo cele.
#
# Reference to resi JEDNIM CISLEM: `UpdateMaxDrawZ()`
# (`GameSceneDrawingSorting.cs:57-213`) spocte strop `_maxZ` a kresli jen
# objekty s `z < _maxZ` (radky 339 a 833). My ten strop pocitame stejne
# (`strop_patra()`):
#   * na dlazdici hrace a na (x+1,y+1) hleda statik VYS nez `pz + 14`
#     (`PZ_NAD`, radek 87) a strop ponizi na jeho `z`, kdyz plati
#     `(flags & (Transparent|Foliage)) == 0 && (!IsRoof || IsSurface)`
#     (radky 121-136), resp. `(flags & (Transparent|Surface)) == 0 && IsRoof`
#     (radky 168-198),
#   * strop nikdy nejde pod `pz + 16` (`PZ_SKRYT`, radky 205-209),
#   * kdyz se nad hracem nic nenajde, zustava `Const.Z_MAX` (127) = nic se
#     neskryva (pocatek `_maxZ = 127`, radek 76).
# Tim se schovaji VSECHNY objekty patra (zdivo, okno, trabec, postel, zabradli),
# ne jen strechy - a dlazdice, po ktere hrac chodi, zustava: strop je vzdy
# `>= hrac_z + 16`, takze vlastni podlaha hrace (`z <= hrac_z`) nikdy nezmizi.
#
# ⚠ CO ZUSTAVA Z 18. SESSION (`je_strop` + `hrac_z + PZ_SKRYT`) - NAMERENO
# (`_analyza/p22-patra-sonda.txt`): reference kandidat na strop ma UZSI
# podminku nez `je_strop` - strecha, ktera NEMA `Surface` (`wooden shingles`
# flags 0x14002000, `thatch roof` 0x14006000), strop NENASTAVI. V Britanii je
# takovych mist **204 z 2970** (6,9 %), kde stare pravidlo krylo a reference
# by strechu nechala videt - tam by se vratila vada "postava se zobrazuje pres
# strechu". Pravidlo je proto SJEDNOCENI:
#   skryto = (z >= strop)                                # reference
#          or (kryto and je_strop(art) and z > hrac_z + PZ_SKRYT)   # 18. session
# a `kryto` je true, kdyz reference kandidata nasla NEBO kdyz plati stare
# `pod_strechou()`. Podminka `z > hrac_z + PZ_SKRYT` u druhe casti je DULEZITA:
# `je_strop` zahrnuje i pochuznou podlahu (`Surface+Background`), takze bez ni
# by zmizela podlaha, po ktere hrac stoji.
#
# ⚠ CO SE NEDELA (zapsano, ne zamlcene): reference ma jeste vetev pro LAND
# (radky 94-111: kdyz je na dlazdici hrace land vys nez `pz + 16`, strop se
# snizi a land nad `_maxGroundZ` se take nevykresluje). U nas se land filtruje
# SCHVALNE NIKDY - land je teren, po kterem se chodi, a jeho zmizeni by byla
# horsi vada nez patro navic (docs/09: co se nedela, se pise). UO skladany
# land (jeskynni patro) u nas zatim nema mapova data.
#
# Puvodni 18. session (strechy nad hracem):
# ⚠ 18. session (2026-10-08) - STŘECHY NAD HRÁČEM (vada "v budově nevidím
# vnitřek a postava chodí po střeše"). Reference to resi v `UpdateMaxDrawZ()`
# (`GameSceneDrawingSorting.cs:57-213`): na dlazdici hrace a na (x+1,y+1) se
# hleda statik NAD hrace (vys nez `playerZ + 14`); kdyz je to strecha
# (`TileFlag.Roof = 0x10000000`, `TileDataLoader.cs:525`) nebo pochuzna plocha,
# nastavi se `_noDrawRoofs = true` a strechy se vubec nekresli.
#
# ⚠ NAMERENO na nasich datech (`assets/uo/tiles.json`): flag `Roof` ma jen 1040
# predmetu (hlavne "palm frond roof"), kdezto bezne plastove/bsidlicove strechy
# v Britanii (`slate roof`, art 17792, flags 0x04006201) maji
# `Surface|Background` a flag `Roof` NEMAJI. Proto se za strop/streshu povazuje
# i `Surface & Background` - bez toho by se v dome neuklidilo nic.
const F_SURFACE: int = 0x00000200
const F_ROOF: int = 0x10000000
const F_TRANSPARENT: int = 0x00000004
const F_FOLIAGE: int = 0x00020000
const PZ_NAD: int = 14               # `pz14 = playerZ + 14` (reference)
const PZ_SKRYT: int = 16             # `pz16 = playerZ + 16` (reference)
# Strop, kdyz nad hracem nic neni: reference zacina na 127 (`_maxZ = 127`,
# radek 76) a necha ho tak, kdyz kandidata nenajde - tehdy se neskryva NIC.
# Je to `Const.Z_MAX`, ale konstanta se vypisuje, aby bylo videt, ze to cislo
# ma v referenci vyznam (a aby se nedalo splest s `hrac_z + 16`).
const STROP_NIC: int = 127
# ⚠⚠ NEJNIŽŠÍ `z` SOUVISLÉ STŘECHY (2026-10-09, faze 1 bod 5.3). Reference
# NENASTAVI strop po nalezu strechy na jeji `z`, ale na
# `Map.CalculateNearZ(tileZ, x+1, y+1, tileZ)`
# (`_src/classicuo/src/ClassicUO.Client/Game/Map/Map.cs:164-219`): flood fill po
# souvisle strese (kazdy krok |z - z_souseda| <= 6, `:192`) a vraci NEJMENSI
# `z` teto strechy = OKAP. Teprve to je `_maxGroundZ`, a tedy `_maxZ`
# (`GameSceneDrawingSorting.cs:180-185` a `:203`); `ProcessAlpha` (`:339`) pak
# skryje vsechno s `obj.Z >= _maxZ`.
# NAMERENO 2026-10-09 (`_analyza/p27-patra-sonda.gd`): nas kod daval `z`
# NALEZENE strechy (hreben) - strop vysel az o 9 jednotek vys (49 misto 40 na
# (1477,1612)) a patro se kreslilo. V okoli Britainu se to tykalo 85 z 1369
# proskenovanych dlazdic.
const NEAR_Z_TOLERANCE: int = 6      # `Map.cs:192` (`Math.Abs(z - obj.Z) > 6`)
const NEAR_Z_LIMIT: int = 20000      # pojistka (reference ma mrizku 64x64)
const NEAR_Z_NENI: int = -32768      # "na te dlazdici strecha neni"

var _map = null
var _textures = null
var _tiledata = null               # muze byt null: pak se texmap nedava
var _iso
var _sort
var _list: Array = []
var _cover: Rect2i = Rect2i()
var _built: bool = false
var _counts: Dictionary = {"land": 0, "static": 0}
# Skryvat strechy/stropy nad hracem? Nastavuje `nastav_hrace()`; dokud to nikdo
# nezavola, kresli se vsechno (chovani pred 18. session).
var skryt_strechy: bool = false
var _hrac_z: int = -9999
# Strop patra (reference `_maxZ`): kresli se jen statiky s `z < _max_z`.
# `STROP_NIC` = nad hracem nic neni a neskryva se.
var _max_z: int = STROP_NIC
# MERENI flood fillu (`near_z`): kolik dlazdic prosla posledni vypocet a jestli
# narazila na pojistku. Nula a "nevim" musi byt videt (docs/08 §8.6).
var near_z_kroku: int = 0
var near_z_limit: bool = false
# Kolikrat se `strop_patra` opravdu POCITAL (cache zásah se nepocita). Slouzi
# k dokazu, ze cache funguje - bez nej by se flood fill delal kazdy frame.
var strop_vypoctu: int = 0
# CACHE stropu podle pozice hrace. Reference pocita `UpdateMaxDrawZ()` JEN kdyz
# se zmeni dlazdice nebo vyska hrace (`GameSceneDrawingSorting.cs:63-68`,
# `_oldPlayerX/Y/Z`); nam se `strop_patra` vola z `nastav_hrace` KAZDY frame
# (pres `look_at_tile`) a s flood filleme by to bylo 2 492 dlazdic na frame
# (namEReno v Britanii). Cache je proto soucast chovani, ne optimalizace:
# bez ni by se hra zasekavala a `near_z` by byl drazsi nez uzitek.
var _strop_klic: String = ""
var _strop_vysledek: Dictionary = {}



func _init(map, textures, tiledata = null) -> void:
	_map = map
	_textures = textures
	_tiledata = tiledata
	_iso = Iso.new()
	_sort = Sort.new()


func invalidate() -> void:
	_built = false


func je_strop(art_id: int) -> bool:
	# Je dany art strecha nebo strop (nad hrace)? `Roof` flag nebo pochuzna
	# plocha s `Background` (viz namEReno v hlavicce). Pouziva se na to, co se
	# skryva nad hracem (18. session); strop patra pocita `strop_patra()`.
	if _tiledata == null:
		return false
	var f: int = _tiledata.flags(art_id)
	return (f & F_ROOF) != 0 or ((f & F_SURFACE) != 0 and (f & F_BACKGROUND) != 0)


func je_roof(art_id: int) -> bool:
	# `TileFlag.Roof` (`TileDataLoader.cs:525`, hodnota `F_ROOF`). Jen dotaz -
	# rozhodnuti o kresleni je v `strop_patra()`/`_build()`.
	if _tiledata == null:
		return false
	return (_tiledata.flags(art_id) & F_ROOF) != 0


func pod_strechou(px: int, py: int, pz: int) -> bool:
	# Je hrac POD strechou/stropem? Hleda se na jeho dlazdici a na (x+1,y+1)
	# (presne jako reference); staci JEDEN statik vys nez `pz + 14`.
	if _tiledata == null:
		return false
	for posun in [Vector2i(0, 0), Vector2i(1, 1)]:
		for record in _statiky_na(px + posun.x, py + posun.y):
			if int(record["z"]) <= pz + PZ_NAD:
				continue
			if je_strop(int(record["tile"]) + ITEM_OFFSET):
				return true
	return false


func strecha_na(x: int, y: int, z: int) -> int:
	# Prvni statik na dlazdici, ktery je STŘECHA a jehoz `z` je od `z` nejvys
	# o `NEAR_Z_TOLERANCE` - doslovny prepis vnitrku `Map.CalculateNearZ`
	# (`Map.cs:180-197`). Vraci `z` strechy, nebo `NEAR_Z_NENI`.
	if _tiledata == null:
		return NEAR_Z_NENI
	for record in _statiky_na(x, y):
		if (_tiledata.flags(int(record["tile"]) + ITEM_OFFSET) & F_ROOF) == 0:
			continue
		var tz: int = int(record["z"])
		if absi(tz - z) > NEAR_Z_TOLERANCE:
			continue
		return tz
	return NEAR_Z_NENI


func near_z(default_z: int, x: int, y: int, z: int) -> int:
	# DOSLOVNY PREPIS `Map.CalculateNearZ` (`Map.cs:164-219`): projde SOUVISLOU
	# strechu a vrati jeji NEJMENSI `z` (okap). Reference to pouziva jako strop
	# po nalezu strechy na (x+1, y+1) - viz hlavicka `NEAR_Z_TOLERANCE`.
	#
	# Odchylky od reference (obě pojmenovane):
	#   * reference rekurzuje, my mame explicitni zasobnik (v GDScriptu by
	#     rekurze pres stovky dlazdic mohla prekrocit strop zasobniku),
	#   * navstivene dlazdice se drzi ve stejne mrizce 64x64 jako reference
	#     (`(x & 0x3F) + ((y & 0x3F) << 6)`, `Map.cs:166`), takze i "preskoceni"
	#     dlazdice vzdalene o nasobek 64 je stejne jako v referenci,
	#   * navic je POJISTKA `NEAR_Z_LIMIT` a pocitadlo `near_z_kroku`: kdyby
	#     data mela strechu pres cele mapy, nesmi to zamrznout. Narazeni na
	#     pojistku se hlasi (`near_z_limit`), ne zamlci.
	near_z_kroku = 0
	near_z_limit = false
	var nejnizsi: int = default_z
	var zasobnik: Array = [Vector3i(x, y, z)]
	var videno: Dictionary = {}
	while not zasobnik.is_empty():
		var bod: Vector3i = zasobnik.pop_back()
		var klic: int = ((bod.x & 0x3F) << 6) | (bod.y & 0x3F)
		if videno.has(klic):
			continue
		videno[klic] = true
		near_z_kroku += 1
		if near_z_kroku > NEAR_Z_LIMIT:
			near_z_limit = true
			push_warning("render.chunk: near_z narazil na pojistku %d dlazdic - strop patra muze byt vyssi, nez ma byt" % NEAR_Z_LIMIT)
			break
		var tz: int = strecha_na(bod.x, bod.y, bod.z)
		if tz == NEAR_Z_NENI:
			continue
		if tz < nejnizsi:
			nejnizsi = tz
		# Reference predava SOUSEDUM `z` teto dlazdice (`Map.cs:212-215`), ne
		# puvodni `z` - proto se souvislost pocita po krocich.
		for smer in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			zasobnik.append(Vector3i(bod.x + smer.x, bod.y + smer.y, tz))
	return nejnizsi


func strop_patra(px: int, py: int, pz: int) -> Dictionary:
	# STROP PATRA - doslovny prepis `UpdateMaxDrawZ()`
	# (`GameSceneDrawingSorting.cs:74-212`). Vraci
	# `{maxz, kandidat}`: kresli se jen statiky s `z < maxz` a `kandidat` je
	# true, kdyz se strop opravdu snizil (reference `_noDrawRoofs`).
	#
	# Poradi vetvi je z reference a NENI zamenne: druha smycka je jen pro
	# STŘECHU bez `Surface` na (x+1,y+1) a jen ta meni `maxground` (radek 200)
	# - a to pres `near_z()` (`Map.CalculateNearZ`), ne na `z` te strechy.
	#
	# ⚠ CACHE podle pozice hrace (2026-10-09): reference pocita `UpdateMaxDrawZ`
	# jen pri zmene dlazdice/vysky (`:63-68`); nam se sem chodi kazdy frame.
	var klic: String = "%d,%d,%d" % [px, py, pz]
	if klic == _strop_klic and not _strop_vysledek.is_empty():
		return _strop_vysledek
	strop_vypoctu += 1
	var maxz: int = STROP_NIC
	var kandidat: bool = false
	if _tiledata == null:
		return {"maxz": maxz, "kandidat": kandidat}
	var pz14: int = pz + PZ_NAD
	# 1) dlazdice hrace (radky 90-137)
	for record in _statiky_na(px, py):
		var tz: int = int(record["z"])
		if tz <= pz14 or maxz <= tz:
			continue
		var f: int = _tiledata.flags(int(record["tile"]) + ITEM_OFFSET)
		if (f & (F_TRANSPARENT | F_FOLIAGE)) == 0 \
				and ((f & F_ROOF) == 0 or (f & F_SURFACE) != 0):
			maxz = tz
			kandidat = true
	var maxground: int = maxz
	var tempz: int = maxz
	# 2) (x+1, y+1) - jen strecha bez `Surface` (radky 147-201)
	for record in _statiky_na(px + 1, py + 1):
		var tz2: int = int(record["z"])
		if tz2 > pz14 and maxz > tz2:
			var f2: int = _tiledata.flags(int(record["tile"]) + ITEM_OFFSET)
			if (f2 & (F_TRANSPARENT | F_SURFACE)) == 0 and (f2 & F_ROOF) != 0:
				maxz = tz2
				# ⚠ `CalculateNearZ`, ne `tz2` (reference `:180-185`): strop je
				# NEJNIŽŠÍ `z` souvisle strechy (okap), ne `z` nalezene dlazdice.
				maxground = near_z(tz2, px + 1, py + 1, tz2)
				kandidat = true
		tempz = maxground
	maxz = maxground
	# 3) strop nikdy nejde pod `pz + 16` (radky 205-209)
	if tempz < pz + PZ_SKRYT:
		maxz = pz + PZ_SKRYT
	var vysledek: Dictionary = {"maxz": maxz, "kandidat": kandidat}
	_strop_klic = klic
	_strop_vysledek = vysledek
	return vysledek


func max_draw_z() -> int:
	# Strop patra pro soucasny stav hrace (pro testy a sondy). `STROP_NIC`
	# znamena "nad hracem nic neni" - tehdy se neskryva ani strecha.
	return _max_z


func no_draw_roofs() -> bool:
	return skryt_strechy


func nastav_hrace(px: int, py: int, pz: int) -> bool:
	# Prebira stav hrace. Vraci TRUE, kdyz se zmenilo, co se skryva - tim se
	# zahodi seznam (`invalidate`), aby se patro prekreslilo bez nich.
	# Je to vzacna zmena (vstup/vystup z budovy, prechod patra), ne kazdy krok:
	# `maxz` se meni jen tehdy, kdyz se zmeni kandidat na strop nad hracem.
	var s: Dictionary = strop_patra(px, py, pz)
	# `kryto` = reference nasla strop NEBO plati stare "pod strechou"
	# (18. session). Kdyz kryto NENI, zustava strop `STROP_NIC`.
	var kryto: bool = bool(s["kandidat"]) or pod_strechou(px, py, pz)
	var novy_max_z: int = int(s["maxz"]) if kryto else STROP_NIC
	var zmena: bool = novy_max_z != _max_z or kryto != skryt_strechy
	_max_z = novy_max_z
	skryt_strechy = kryto
	_hrac_z = pz
	if zmena:
		invalidate()
	return zmena



func _statiky_na(x: int, y: int) -> Array:
	# Statiky JEDNE dlazdice (blok 8x8 drzi lokalni souradnice 0..7).
	var bx: int = (x / Const.BLOCK_SIZE) * Const.BLOCK_SIZE
	var by: int = (y / Const.BLOCK_SIZE) * Const.BLOCK_SIZE
	var lx: int = x % Const.BLOCK_SIZE
	var ly: int = y % Const.BLOCK_SIZE
	var out: Array = []
	for record in _map.statics_at(bx, by):
		if int(record["x"]) == lx and int(record["y"]) == ly:
			out.append(record)
	return out


func is_built() -> bool:
	return _built


func counts() -> Dictionary:
	return _counts.duplicate()


func cover() -> Rect2i:
	return _cover


func screen_position(obj: Dictionary) -> Vector2:
	# Kam presne se prvek kresli. `core.iso.to_screen` vraci horni vrchol
	# diamantu dlazdice; art statiku ma `ox`,`oy` tak, ze se od dlazdice
	# ODECITA (vzorec je v hlavicce `tools/uoextract/atlas.py`). Je to tady
	# (a ne v kreslicim uzlu), aby se geometrie dala merit testem.
	return _iso.to_screen(int(obj["x"]), int(obj["y"]), int(obj["z"])) \
		- Vector2(obj["offset"])


func visible(center: Vector2i, tiles_x: int, tiles_y: int) -> Array:
	var want := Rect2i(center.x - tiles_x / 2, center.y - tiles_y / 2, tiles_x, tiles_y)
	if _built and want == _cover:
		return _list
	_cover = want
	# ⚠ P20 (17. session): cena prestavby seznamu je 85-250 ms (podle velikosti
	# okna) a je to duvod, proc se prestavba ODDALUJE (`RECENTER_TILES` ve
	# `app/world_view`). Mereni: `_analyza/p20-kadence.gd`.
	_list = _build(want)
	_built = true
	return _list


func _build(area: Rect2i) -> Array:
	var objects: Array = []
	var counts := {"land": 0, "static": 0, "skryto": 0}
	var zrohy: PackedInt32Array = _z_grid(area)
	var sirka: int = area.size.x + 1
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var land: int = _map.land_at(x, y)
			if land < 0:
				continue
			var radek: int = (y - area.position.y) * sirka + (x - area.position.x)
			var z: int = zrohy[radek]
			objects.append({"kind": "land", "x": x, "y": y, "z": z,
				"art_id": land, "offset": Vector2i.ZERO,
				"texmap": _tiledata.texture(land) if _tiledata != null else 0,
				"z_corners": [z, zrohy[radek + 1], zrohy[radek + sirka],
					zrohy[radek + sirka + 1]]})
			counts["land"] += 1
	var first: Vector2i = _iso.block_of(area.position.x, area.position.y)
	var last: Vector2i = _iso.block_of(area.end.x - 1, area.end.y - 1)
	for by in range(first.y, last.y + 1):
		for bx in range(first.x, last.x + 1):
			var base_x: int = bx * Const.BLOCK_SIZE
			var base_y: int = by * Const.BLOCK_SIZE
			for record in _map.statics_at(base_x, base_y):
				var sx: int = base_x + int(record["x"])
				var sy: int = base_y + int(record["y"])
				if not area.has_point(Vector2i(sx, sy)):
					continue
				var art_id: int = int(record["tile"]) + ITEM_OFFSET
				var z_statiku: int = int(record["z"])
				# STROP PATRA (reference `_maxZ`): vsechno v urovni stropu a vys
				# je patro nad hracem - zdivo, okno, trabec, postel, zabradli
				# (V12/V16/V17). `_max_z >= hrac_z + PZ_SKRYT`, takze vlastni
				# podlaha hrace (`z <= hrac_z`) tim nikdy neprojde.
				if z_statiku >= _max_z:
					counts["skryto"] += 1
					continue
				# STŘECHY/STROPY NAD HRÁČEM (18. session): i to, co je pod
				# strojem patra, ale je to strecha/strop nad hlavou hrace.
				# `z > hrac_z + PZ_SKRYT` je tu POVINNE - `je_strop` zahrnuje
				# i pochuznou podlahu, po ktere hrac stoji.
				if skryt_strechy and z_statiku > _hrac_z + PZ_SKRYT and je_strop(art_id):
					counts["skryto"] += 1
					continue
				objects.append({"kind": "static", "x": sx, "y": sy,
					"z": z_statiku, "art_id": art_id,
					"priority_z": _priorita(art_id, z_statiku),
					"offset": _textures.offset(art_id)})
				counts["static"] += 1
	_counts = counts
	return _sort.draw_order(objects)


func _priorita(art_id: int, z: int) -> int:
	# Poradova vyska pro RAZENI, ne pro kresleni (ClassicUO `PriorityZ`,
	# `Chunk.cs:246-272`): podlaha (`IsBackground`) -1, statik s vyskou +1.
	# Bez tiledata (konstruktor ji smi dostat `null`) se vrati `z` - razeni pak
	# zustane na chovani pred 2026-10-07, jen se o nem vi.
	if _tiledata == null:
		return z
	var v: int = z
	if _tiledata.flags(art_id) & F_BACKGROUND != 0:
		v -= 1
	if _tiledata.height(art_id) != 0:
		v += 1
	return v


func _z_grid(area: Rect2i) -> PackedInt32Array:
	# Vysky ROHU oblasti: (sirka+1) x (vyska+1) hodnot. Sousede se ctou JEDNOU
	# na cely pohled, ne ctyrikrat na kazdou dlazdici - pri 3 000 dlazdicich by
	# to bylo 12 000 dotazu do mapy pri kazdem prestavem seznamu (a ten se
	# prekresluje pri kazdem kroku chuze).
	# Mrizka ma o 1 radek/sloupec vic, aby mela kazda dlazdice i sve prave/dolni
	# rohy (ty patri sousedovi).
	var sirka: int = area.size.x + 1
	var out := PackedInt32Array()
	out.resize(sirka * (area.size.y + 1))
	for y in range(area.position.y, area.end.y + 1):
		for x in range(area.position.x, area.end.x + 1):
			out[(y - area.position.y) * sirka + (x - area.position.x)] = int(_map.z_at(x, y))
	return out
