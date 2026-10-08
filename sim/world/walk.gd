extends RefCounted
# Pruchodnost a vysky (granule world.walk, docs/04 §4.2, algoritmus docs/05 §5.1.2).
#
# PRAVIDLA (doslovne ze zadani, ne z dojmu):
#   * PERSON_HEIGHT = 16, STEP_HEIGHT = 2 (`core/const.gd`),
#   * z cilove dlazdice = povrch, ktery je postave VYSKOVE NEJBLIZ (viz V4/V5 niz),
#   * blokuje se jen Impassable / Surface / Wet (a Door, Container);
#     Wall, Window, Roof, Foliage, NoShoot, StairBack, StairRight NE,
#   * blokujici statik blokuje jen tehdy, kdyz se jeho vyskove pasmo protne
#     s pasmem postavy (`docs/05 §5.1.2` bod 2) - statik hluboko pod nohama
#     nebo vysoko nad hlavou se netyka,
#   * diagonala je ASYMETRICKA: hrac potrebuje pruchodne OBE ortogonalni
#     sousedni dlazdice, NPC/GM jen jednu (proto je tu `is_player`).
#
# ⚠ DVE ID PROSTRANSTVI - VADA, KTERA TU BYLA (namEReno 2026-10-07 na realne mape):
#   `world.map.statics_at` vraci `tile` = TILEDATA ID PREDMETU (0..0x3FFF), ale
#   `world.tiledata` klicuje predmety jako `tile >= 0x4000` (art id). Kdo preda
#   statik syrovy, precte u nej tabulku LAND: `tiledata.flags(1717)` vratilo
#   'grass' a 0x00000000, spravne ('wooden door') 0x20006050. V Britanii melo
#   Impassable ve SPRAVNE tabulce 2743 statiku, syrove jen 1044 - a `can_step`
#   tim pustil 1325 kroku do dlazdice s Impassable statikem. Statiky se proto
#   posouvaji konstantou `ITEM_OFFSET` (stejne to dela `render/chunk_renderer`).
#
# ⚠ DVERE MAJI `Impassable` V OBOU STAVECH (namEReno: 1717 i 1718 = 0x20006050,
#   vyska 20). Stav se proto CTE z `world.doors.is_open` - z flagu ho poznat NELZE.
#   Ktery art je otevreny, rozhoduje `world.doors` KONVENCI ZMERENOU 2026-10-07:
#   art z `doors.txt` je ZAVRENY, jeho `art + 1` je OTEVRENY (doklady v hlavicce
#   `sim/world/doors.gd`; `walk` je na konvenci nezavisly, jen se na stav ptá).
#
# ⚠ SCHODY: `Surface` + vyska 5 nebo 10 (namEReno: 9 z 9 druhu schodu v Britanii)
#   a skok mezi sousednimi schody je PRESNE vyska schodu (histogram skoku povrchu
#   v okoli 180x180: 0x 436, +-5 68+68, +-1 2+2). Krok NAHORU se proto na dlazdici,
#   kde je schod, povoluje do vysky toho schodu (Sphere ma na to zvlastni pravidlo
#   `CAN_I_CLIMB` + `m_zClimbHeight`; RunUO by tytez schody zablokoval pres
#   `startTop + StepHeight`, coz by v realne mape znamenalo, ze se po schodech
#   neda jit vubec).
#
# ⚠⚠ V4 + V5 (2026-10-07, 14. session) - VYSKA SE POCITA Z HORNICH HRAN, NE Z `dz`:
#   Do teto session se krok povoloval jen kdyz `z_cil - z_start <= STEP_HEIGHT`,
#   kde `z_cil` bylo JEDNO cislo mapy (`map.z_at`). Uzivatel: "do kopce me
#   nepusti", "pres most me nepusti (nad vodou)". Reference (`_src/servuo`
#   `Scripts/Services/Pathing/Movement.cs:170-171`, `:211-343`, `Server/Map.cs:
#   552-607`, `Server/TileData.cs:112-125`) porovnava HORNI HRANU:
#
#     stepTop = startTop + StepHeight(2)      # Movement.cs:170
#     land:   povoleno, kdyz stepTop >= landLow    # :319-321 (landLow = NEJNIZSI roh cile)
#             stojna vyska = landCenter            # GetAverageZ, Map.cs:552-607
#     statik: povoleno, kdyz stepTop >= itemTop    # :216-236
#             itemTop = itemZ + (Bridge ? 0 : height)   # TileData.cs:112-125
#             stojna vyska = itemZ + CalcHeight          # CalcHeight = Bridge ? h/2 : h
#     povrchu je vic -> vyhrava ten s |ourZ - p.Z| NEJMENSI, pri rovnosti nizsi  # :222-228
#     DOLU nema reference zadny limit (zadna dolni mez v `Movement.cs` neni)
#
#   Tri veci, ktere z toho plynou a kazda byla namerena jako vada:
#     (1) svah: povoleny vzestup je `stepTop - landLow`, ne `2` - svah, ktery
#         klient kresli jako rampu (`z_corners`, `render/chunk_renderer.gd:113`),
#         simulace do teto session nevidela (`_analyza/vada-svah.py`: 4 013 kroku
#         z 165 985 = 2,4 %, ktere reference povoli a my blokovali),
#     (2) most: voda se kontrolovala DRIV nez statiky (`return _no("blocked")`),
#         takze molo nad vodou bylo nedosazitelne - pritom v UO most NENI entita,
#         je to statik se `Surface`/`Bridge` nad vodou (`TileData.cs:138-142`);
#         `_analyza/vada-most-mapa.py`: 2 973 ploch nad vodou, molo u Britannie
#         `x1522..1525 y1470..1500` (paluba z=10, voda z=-5),
#     (3) statik se `Bridge` (flag 0x400) ma `CalcHeight = height / 2` a jeho
#         strop pro krok je `itemZ` (ne `itemZ + height`).
#
#   Voda zustava blokujici: `F_WET` je u nas v datech soucasne s `Impassable`
#   (namEReno: land water flags 0x000000C0) a `canSwim` neumime - reference ji
#   blokuje tehoz (`Movement.cs:211`), takze se chovame stejne.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2): zavislosti (mapa, tiledata,
# schody, dvere) se predavaji KONSTRUKTOREM, aby se `can_step` dal merit bez
# assetu `assets/uo/` (ta jsou v .gitignore, takze v CI nejsou) - stejny duvod
# jako `world.map._init(prefix)`. Vychozi hodnoty jsou realne komponenty.
#
# ⚠⚠ ZADANI 19 (2026-10-08) - V11 "Hra mi neumozni jit na most": `_start_top`
#   bral JEN horni hranu LANDU a ignoroval statiky POD NOHAMI. Na mole u
#   Britannie (dlazdice 1522,1468: prkno art 2173 z=0, vyska 4, `Bridge`) se
#   stoji ve 2, dalsi prkno je z=5 -> nas strop `2 + 2 = 4` < `itemTop 5` a krok
#   byl BLOKOVANY ("height"); reference (`GetStartZ`, `Movement.cs:617-641`)
#   bere i statiky (`zTop = tile.Z + Height`) a krok povoli. Podezreni na
#   diagonalni pravidlo se NEPOTVRDILO (molo je 4 dlazdice siroke). NamEReno:
#   `_analyza/p22-most-koridor.txt` (pocet bloku "height" 44 -> 32), sonda
#   `_analyza/p22-most-chuze.gd` (76 dlazdic z nabrezi na konec mola).
#   Testy: `tests/cases/walk.gd` 2g a 2h (druhy je schodiste, kde se plna vyska
#   v `_blokuje_statik` ukazala jako SKODLIVA - viz komentar u `surface_z`).

const F_IMPASSABLE := 0x00000040
const F_WET := 0x00000080
const F_SURFACE := 0x00000200
const F_BRIDGE := 0x00000400
const F_CONTAINER := 0x00200000
const F_DOOR := 0x20000000

# Statiky z mapy jsou v prostoru tiledata id predmetu; `world.tiledata` chce
# art id (viz hlavicka). Jedno misto, kde se to prevadi.
const ITEM_OFFSET := 0x4000

# Zadny kandidat na povrch cilove dlazdice (nemeni se s daty - `z` muze byt
# i zaporne, proto se "neni" neda poznat podle nuly).
const NO_SURFACE := -100000

const Const = preload("res://core/const.gd")
const MapScript = preload("res://sim/world/map.gd")
const TiledataScript = preload("res://sim/world/tiledata.gd")
const StairsScript = preload("res://sim/world/stairs.gd")
const DoorsScript = preload("res://sim/world/doors.gd")

var _map = null
var _tiledata = null
var _stairs = null
var _doors = null


func _init(map = null, tiledata = null, stairs = null, doors = null) -> void:
	_map = map if map != null else MapScript.new()
	_tiledata = tiledata if tiledata != null else TiledataScript.new()
	_stairs = stairs if stairs != null else StairsScript.new()
	_doors = doors if doors != null else DoorsScript.new()


func can_step(from: Vector3i, dir: int, height: int = Const.PERSON_HEIGHT,
		is_player: bool = true) -> Dictionary:
	# Vraci `{ok, z, reason}` (docs/04 §4.2). `reason` je prazdny, kdyz se jde.
	if dir < 0 or dir > 7:
		return _no("bad_dir")
	var dx: int = Const.DIR_DX[dir]
	var dy: int = Const.DIR_DY[dir]
	var to := Vector3i(from.x + dx, from.y + dy, from.z)
	if dx != 0 and dy != 0 and is_player:
		# Hrac u rohu nesmi diagonalizovat: potrebuje pruchodne OBE ortogonalni
		# dlazdice (docs/05 §5.1.2 bod 4).
		if not _passable(from.x + dx, from.y, from.z, height):
			return _no("diagonal")
		if not _passable(from.x, from.y + dy, from.z, height):
			return _no("diagonal")
	var land: int = _land_at(to.x, to.y)
	if land < 0:
		return _no("off_map")
	# Strop kroku: horni hrana toho, na cem stojim (V4), + povoleny vzestup
	# (STEP_HEIGHT, na dlazdici se schodem vyska toho schodu).
	var strop: int = _start_top(from) + _vyska_kroku(to.x, to.y)
	var vyber: Dictionary = _vyber_povrch(to, from.z, strop, height)
	if int(vyber["z"]) == NO_SURFACE:
		return _no(str(vyber["reason"]))
	var z: int = int(vyber["z"])
	return {"ok": true, "z": z, "reason": ""}


func surface_z(x: int, y: int) -> int:
	# NEJVYSSI povrch na dlazdici: land, nebo nejvyssi statik se `Surface`.
	# ⚠ POZOR (2026-10-08): na dlazdici se SCHODISTEM to NENI vyska, po ktere se
	# chodi. Stupne jsou tam nasazene po 5 ve SLOUPCI (art 1848/1850) a nad nimi
	# byva jeste strop patra (art 1407, vyska 0) - `surface_z` pak vrati strop
	# (namEReno: dlazdice hradu 1492..1497/1602..1604 vraci 60, ale chodi se po
	# nich ve 21 az 40). Kdo hleda, KAM se da stanout, musi pouzit `can_step`
	# (vybira povrch nejblizsi postave) - ne tuhle funkci.
	# Do 2026-10-08 tu stalo "nejnizsi povrch", coz byla NEPRAVDA (funkce vraci
	# maximum) a sonda `_analyza/p22-schody-sonda.gd` kvuli tomu merila zacatky
	# ve vysce 60 a vyslo ji, ze se na 1. patro neda vystoupit. Premereno sondou
	# `_analyza/p22-pohyb-schody-sonda.gd`: z namesti (1495,1630,z=10) se na
	# z=40 DOJDE (1 470 stavu BFS, cesta 29 kroku).
	return _surface_z(x, y)


func _land_at(x: int, y: int) -> int:
	var tile = _map.land_at(x, y)
	return -1 if tile == null else int(tile)


func _flags(tile: int) -> int:
	# Flagy STATIKU: `tile` je z mapy (tiledata id predmetu), tiledata chce art id.
	return _tiledata.flags(tile + ITEM_OFFSET)


func _height(tile: int) -> int:
	return _tiledata.height(tile + ITEM_OFFSET)


func _calc_height(tile: int) -> int:
	# `CalcHeight` z `TileData.cs:112-125`: most puli vysku. Pouziva se pro
	# stojnou vysku statiku i pro jeho vyskove pasmo.
	if _flags(tile) & F_BRIDGE != 0:
		return _height(tile) / 2
	return _height(tile)


func _corners(x: int, y: int) -> Array:
	# Vysky ROHU dlazdice, presne jako `Map.GetAverageZ` (`Server/Map.cs:552-607`):
	# [0] = (x,y) "top", [1] = (x+1,y) "right", [2] = (x,y+1) "left",
	# [3] = (x+1,y+1) "bottom". Roh pouziva vysku SOUSEDNI dlazdice - stejne to
	# dela klient pro svah (`render/chunk_renderer.gd:153-166`).
	return [int(_map.z_at(x, y)), int(_map.z_at(x + 1, y)),
		int(_map.z_at(x, y + 1)), int(_map.z_at(x + 1, y + 1))]


func _low(c: Array) -> int:
	return mini(mini(int(c[0]), int(c[1])), mini(int(c[2]), int(c[3])))


func _top(c: Array) -> int:
	return maxi(maxi(int(c[0]), int(c[1])), maxi(int(c[2]), int(c[3])))


func _center(c: Array) -> int:
	# Stojna vyska rovne plochy (`GetAverageZ`, Map.cs:587-594): prumer dvojice
	# s VETSiM absolutnim rozdilem (tedy po spadnici svahu), celociselne DOLU
	# (`FloorAverage`, Map.cs:597-607 - u zapornych cisel se zaokrouhluje dolu).
	var z_top: int = int(c[0])
	var z_left: int = int(c[2])
	var z_right: int = int(c[1])
	var z_bottom: int = int(c[3])
	if absi(z_top - z_bottom) > absi(z_left - z_right):
		return _floor_avg(z_left, z_right)
	return _floor_avg(z_top, z_bottom)


static func _floor_avg(a: int, b: int) -> int:
	var v: int = a + b
	if v < 0:
		v -= 1
	return v / 2


func _start_top(from: Vector3i) -> int:
	# Horni hrana toho, na cem postava stoji (`GetStartZ`, Movement.cs:585-670):
	# u landu je to NEJVYSSI roh dlazdice, ale jen kdyz na ni opravdu stoji
	# (`loc.Z >= landCenter`) a neni blokujici (voda/zed). Kdo stoji na statiku
	# (molo, schod), ma `from.z` uz na jeho hrane.
	#
	# ⚠⚠ V11 (2026-10-08, zadani 19) - STATIKY POD NOHAMA SE MUSI POCITAT:
	#   Do teto session se brala JEN horni hrana LANDU. Reference ale bere
	#   i statiky na dlazdici, na ktere postava stoji (`Movement.cs:617-641`):
	#   `zCenter = tile.Z + CalcHeight` (stojna vyska) a `zTop = tile.Z +
	#   Height` (PLNA vyska, i u `Bridge` - `:634`, `:659`; proto se pro strop
	#   kroku nepouziva `CalcHeight`).
	#   NAMERENO na mole u Britannie (`_analyza/p22-most-koridor.txt`): dlazdice
	#   (1522,1468) ma prkno art 2173 z=0 (Surface+Bridge, vyska 4), takze se
	#   na nem stoji v `z = 0 + 4/2 = 2`; dalsi prkno na (1522,1469) je z=5.
	#   Nas strop byl `startTop(2) + 2 = 4` < `itemTop 5`, takze krok na molo byl
	#   BLOKOVANY ("height") - presne to uzivatel hlasi jako "neumozni mi jit na
	#   most". Reference ma `startTop = 0 + 4 = 4`, tedy `stepTop = 6 >= 5`,
	#   a krok POVOLI. Podezreni na diagonalni pravidlo se NEPOTVRDILO (molo je
	#   4 dlazdice siroke; blokovane diagonaly na nem jsou verne - ServUO
	#   `Movement.cs:550-554`).
	var land: int = _land_at(from.x, from.y)
	var z_top: int = from.z
	var z_center: int = 0
	var is_set: bool = false
	if land >= 0 and _tiledata.flags(land) & (F_IMPASSABLE | F_WET) == 0:
		var c: Array = _corners(from.x, from.y)
		if from.z >= _center(c):
			z_center = _center(c)
			z_top = _top(c)
			is_set = true
	# Statiky pod nohama: stojna vyska je `z + CalcHeight`, ale strop kroku je
	# `z + Height` (`Movement.cs:624-637`). Bere se jen ten, na kterem opravdu
	# stojime (`from.z >= zCenter`) a ktery neni nizsi nez to, co uz mame.
	for s in _statiky(from.x, from.y):
		var tile: int = int(s["tile"])
		if _flags(tile) & F_SURFACE == 0:
			continue
		var item_z: int = int(s["z"])
		var calc_top: int = item_z + _calc_height(tile)
		if is_set and calc_top < z_center:
			continue
		if from.z < calc_top:
			continue
		z_center = calc_top
		z_top = maxi(z_top, item_z + _height(tile))
		is_set = true
	if not is_set:
		return from.z                # `if (!isSet) zLow = zTop = loc.Z` (:668)
	if from.z > z_top:
		return from.z                # `else if (loc.Z > zTop) zTop = loc.Z` (:670)
	return z_top


func _surface_z(x: int, y: int) -> int:
	var z: int = int(_map.z_at(x, y))
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		if _flags(tile) & F_SURFACE == 0:
			continue
		var top: int = int(s["z"]) + _calc_height(tile)
		if top > z:
			z = top
	return z


func _vyber_povrch(to: Vector3i, from_z: int, strop: int, height: int) -> Dictionary:
	# VYBER POVRCHU cilove dlazdice presne v poradi reference
	# (`Movement.cs:177-343`): nejdriv statiky se `Surface` BEZ `Impassable`,
	# pak land. Kazdy kandidat musi projit `IsOk` (`:74-132`, u nas
	# `_blokuje_statik`); kdyz je kandidatu vic, vyhrava ten s |ourZ - p.Z|
	# NEJMENSI a pri rovnosti nizsi (`:222-228`).
	# Vraci `{z, reason}`: `z == NO_SURFACE` znamena "neprojed" a `reason` rekne
	# PROC - "height", kdyz neco padlo na vysku, jinak "blocked" (voda, zed,
	# dvere). Duvod je soucast chovani (hlaska v `movement`) i testu.
	var vybrany: int = NO_SURFACE
	var videl_vysku: bool = false
	for s in _statiky(to.x, to.y):
		var tile: int = int(s["tile"])
		var flags: int = _flags(tile)
		# `(flags & ImpassableSurface) == Surface` z `Movement.cs:211`.
		if flags & F_SURFACE == 0 or flags & F_IMPASSABLE != 0 or flags & F_WET != 0:
			continue
		var item_z: int = int(s["z"])
		# Strop statiku: u mostu jen `itemZ` (`if (!itemData.Bridge) itemTop +=
		# itemData.Height;`, Movement.cs:233-234).
		var item_top: int = item_z
		if flags & F_BRIDGE == 0:
			item_top += _height(tile)
		if strop < item_top:
			videl_vysku = true
			continue
		var our_z: int = item_z + _calc_height(tile)
		if vybrany != NO_SURFACE:
			var cmp: int = absi(our_z - from_z) - absi(vybrany - from_z)
			if cmp > 0 or (cmp == 0 and our_z > vybrany):
				continue
		if _blokuje_statik(to.x, to.y, our_z, height):
			continue
		vybrany = our_z
	var land: int = _land_at(to.x, to.y)
	if land >= 0 and _tiledata.flags(land) & (F_IMPASSABLE | F_WET) == 0:
		var c: Array = _corners(to.x, to.y)
		if strop >= _low(c):
			var our_land: int = _center(c)
			var ber: bool = true
			if vybrany != NO_SURFACE:
				var cmp2: int = absi(our_land - from_z) - absi(vybrany - from_z)
				if cmp2 > 0 or (cmp2 == 0 and our_land > vybrany):
					ber = false
			if ber and not _blokuje_statik(to.x, to.y, our_land, height):
				vybrany = our_land
		else:
			videl_vysku = true
	if vybrany == NO_SURFACE:
		return {"z": NO_SURFACE, "reason": "height" if videl_vysku else "blocked"}
	return {"z": vybrany, "reason": ""}


func _vyska_kroku(x: int, y: int) -> int:
	# Jak vysoko se smi krok nahoru na tuhle dlazdici (docs/05 §5.1.2 bod 2).
	# Bez schodu je to `STEP_HEIGHT`; na dlazdici se schodem vyska toho schodu
	# (namEReno: vsechny skoky mezi sousednimi schody v Britanii = vyska schodu).
	var vyska: int = Const.STEP_HEIGHT
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		if _stairs.is_stair(tile):
			vyska = maxi(vyska, _height(tile))
	return vyska


func _statiky(x: int, y: int) -> Array:
	# `world.map.statics_at` vraci CELY blok (s lokalnim x,y) - hledame jen
	# statiky na nasi dlazdici (dokud se smlouva nezmeni, viz vada ZADANI 15).
	var out: Array = []
	for s in _map.statics_at(x, y):
		if int(s["x"]) == x % Const.BLOCK_SIZE and int(s["y"]) == y % Const.BLOCK_SIZE:
			out.append(s)
	return out


func _blokuje_statik(x: int, y: int, z: int, height: int) -> bool:
	# `IsOk` z `Movement.cs:74-132`: statik blokuje, kdyz se jeho vyskove pasmo
	# protne s pasmem postavy stojici na zvolenem povrchu (docs/05 §5.1.2 bod 2).
	# Pocita se i `Surface` (ne jen `Impassable`): kandidatem na povrch je sice
	# jen `Surface` bez `Impassable`, ale DELSI statik se stejnym pasmem kandidata
	# zablokuje - presne proto reference neprijme land pod schodem (schod svym
	# pasmem protne postavu stojici na zemi).
	# Dve ruzna pasma, kazde ma namEReny duvod:
	#   * PRUCHOZI povrch (`Surface` bez `Impassable`) - pasmo je `z + CalcHeight`
	#     PRESNE (reference `checkTop > ourZ`): nulova vyska podlahy nesmi
	#     zablokovat povrch, na kterem prave stojim,
	#   * BLOKUJICI statik (`Impassable`/`Container`/zavrene dvere) - pasmo je
	#     `z + max(CalcHeight, 1)`: 645 druhu Impassable artu ma v tiledata vysku 0
	#     (namEReno) a prazdny interval by z nich udelal pruchozi.
	var nase_do: int = z + height
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		var flags: int = _flags(tile)
		var od: int = int(s["z"])
		if flags & F_DOOR != 0:
			# Dvere maji `Impassable` v obou stavech - rozhoduje stav z `world.doors`.
			if _doors.is_open(tile):
				continue
			if od + maxi(_calc_height(tile), 1) > z and nase_do > od:
				return true
			continue
		if flags & F_SURFACE != 0 and flags & F_IMPASSABLE == 0:
			if od + _calc_height(tile) > z and nase_do > od:
				return true
			continue
		if flags & (F_IMPASSABLE | F_CONTAINER) == 0:
			continue
		var do: int = od + maxi(_calc_height(tile), 1)
		if do > z and nase_do > od:
			return true
	return false


func _passable(x: int, y: int, z: int, height: int) -> bool:
	# "Pruchodne" pro ucely diagonaly: neni tam nic, co by protlo postavu.
	var land: int = _land_at(x, y)
	if land < 0:
		return false
	var flags: int = _tiledata.flags(land)
	if flags & (F_IMPASSABLE | F_WET | F_CONTAINER) != 0:
		return false
	var nase_do: int = z + height
	var strop: int = z + _vyska_kroku(x, y)
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		var sf: int = _flags(tile)
		var od: int = int(s["z"])
		var h: int = _calc_height(tile)
		if sf & F_DOOR != 0:
			# Zavrene dvere protnou pasmo postavy (namEReno: vyska 20) - blokuji.
			if not _doors.is_open(tile) and od + maxi(h, 1) > z and nase_do > od:
				return false
			continue
		if sf & (F_IMPASSABLE | F_CONTAINER) != 0:
			if od + maxi(h, 1) > z and nase_do > od:
				return false
			continue
		# `Surface` nad hlavou (od >= nase_do) se diagonaly netyka; povrch, ktery
		# je vys, nez se da krok, naopak blokuje (neda se na nej vstoupit).
		if sf & F_SURFACE != 0 and od < nase_do and od + h > strop:
			return false
	return true


func _no(reason: String) -> Dictionary:
	return {"ok": false, "z": 0, "reason": reason}
