extends RefCounted
# Pruchodnost a vysky (granule world.walk, docs/04 §4.2, algoritmus docs/05 §5.1.2).
#
# PRAVIDLA (doslovne ze zadani, ne z dojmu):
#   * PERSON_HEIGHT = 16, STEP_HEIGHT = 2 (`core/const.gd`),
#   * z cilove dlazdice = NEJVYSsi povrch (land + statiky s flagem `Surface`),
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
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2): zavislosti (mapa, tiledata,
# schody, dvere) se predavaji KONSTRUKTOREM, aby se `can_step` dal merit bez
# assetu `assets/uo/` (ta jsou v .gitignore, takze v CI nejsou) - stejny duvod
# jako `world.map._init(prefix)`. Vychozi hodnoty jsou realne komponenty.

const F_IMPASSABLE := 0x00000040
const F_WET := 0x00000080
const F_SURFACE := 0x00000200
const F_CONTAINER := 0x00200000
const F_DOOR := 0x20000000

# Statiky z mapy jsou v prostoru tiledata id predmetu; `world.tiledata` chce
# art id (viz hlavicka). Jedno misto, kde se to prevadi.
const ITEM_OFFSET := 0x4000

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
	if _tiledata.flags(land) & F_WET != 0:
		return _no("blocked")           # voda: `request_step` vraci {ok:false}
	if _tiledata.flags(land) & F_IMPASSABLE != 0:
		return _no("blocked")
	# Statiky na CILOVE dlazdici blokuji stejne jako land (docs/05 §5.1.2 bod 3).
	# Tuhle kontrolu test odhalil: `can_step` ji nejdriv nemel a zed ze statiku
	# se dala projit (namEReno 2026-10-06).
	if _blokuje_statik(to.x, to.y, from.z, height):
		return _no("blocked")
	var z: int = _surface_z(to.x, to.y)
	if not _fits(from.z, z, height, _vyska_kroku(to.x, to.y)):
		return _no("height")
	return {"ok": true, "z": z, "reason": ""}


func surface_z(x: int, y: int) -> int:
	# Nejnizsi povrch, na ktery se da stanout: land, nebo vyssi statik s `Surface`.
	return _surface_z(x, y)


func _land_at(x: int, y: int) -> int:
	var tile = _map.land_at(x, y)
	return -1 if tile == null else int(tile)


func _flags(tile: int) -> int:
	# Flagy STATIKU: `tile` je z mapy (tiledata id predmetu), tiledata chce art id.
	return _tiledata.flags(tile + ITEM_OFFSET)


func _height(tile: int) -> int:
	return _tiledata.height(tile + ITEM_OFFSET)


func _surface_z(x: int, y: int) -> int:
	var z: int = int(_map.z_at(x, y))
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		if _flags(tile) & F_SURFACE == 0:
			continue
		var top: int = int(s["z"]) + _height(tile)
		if top > z:
			z = top
	return z


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
	# Statik blokuje, kdyz ma `Impassable`/`Container`, neni to OTEVRENE dvere
	# a jeho vyskove pasmo se protne s pasmem postavy (docs/05 §5.1.2 bod 2).
	# Pasmo blokujiciho statiku je `max(height, 1)`: 645 druhu Impassable artu ma
	# v tiledata vysku 0 (namEReno) a prazdny interval by z nich udelal pruchozi.
	var nase_do: int = z + height
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		var flags: int = _flags(tile)
		if flags & F_DOOR != 0:
			# Dvere maji `Impassable` v obou stavech - rozhoduje stav z `world.doors`.
			if _doors.is_open(tile):
				continue
		elif flags & (F_IMPASSABLE | F_CONTAINER) == 0:
			continue
		var od: int = int(s["z"])
		var do: int = od + maxi(_height(tile), 1)
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
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		var sf: int = _flags(tile)
		var od: int = int(s["z"])
		var h: int = _height(tile)
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
		if sf & F_SURFACE != 0 and od < nase_do and not _fits(z, od + h, height, _vyska_kroku(x, y)):
			return false
	return true


func _fits(z_from: int, z_to: int, height: int, vyska_kroku: int) -> bool:
	# Vyskova mezera: rozdil musi byt mensi nez krok (dolu i nahoru). Kdyz je
	# cilova podlaha vys, nevejde se tam postava (`height`), kdyz niz, je to pruchod.
	var dz: int = z_to - z_from
	if dz > vyska_kroku:
		return false
	if dz < -height:
		return false
	return true


func _no(reason: String) -> Dictionary:
	return {"ok": false, "z": 0, "reason": reason}
