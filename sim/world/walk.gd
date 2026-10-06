extends RefCounted
# Pruchodnost a vysky (granule world.walk, docs/04 §4.2, algoritmus docs/05 §5.1.2).
#
# PRAVIDLA (doslovne ze zadani, ne z dojmu):
#   * PERSON_HEIGHT = 16, STEP_HEIGHT = 2 (`core/const.gd`),
#   * z cilove dlazdice = NEJVYSsi povrch (land + statiky s flagem `Surface`),
#   * blokuje se jen Impassable / Surface / Wet (a Door, Container);
#     Wall, Window, Roof, Foliage, NoShoot, StairBack, StairRight NE,
#   * diagonala je ASYMETRICKA: hrac potrebuje pruchodne OBE ortogonalni
#     sousedni dlazdice, NPC/GM jen jednu (proto je tu `is_player`).
#
# FLAGY jsou hodnoty z `tiledata.mul` (u64). Overeno proti `docs/03` §3.3.2,
# kde je `Wearable = 0x00400000` - tabulka je tedy standardni UO `TileFlag`.
const F_IMPASSABLE := 0x00000040
const F_WET := 0x00000080
const F_SURFACE := 0x00000200
const F_CONTAINER := 0x00200000
const F_DOOR := 0x20000000

const Const = preload("res://core/const.gd")
const MapScript = preload("res://sim/world/map.gd")
const TiledataScript = preload("res://sim/world/tiledata.gd")
const StairsScript = preload("res://sim/world/stairs.gd")

# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2): zavislosti (mapa, tiledata,
# schody) se predavaji KONSTRUKTOREM, aby se `can_step` dal merit bez assetu
# `assets/uo/` (ta jsou v .gitignore, takze v CI nejsou) - stejny duvod jako
# `world.map._init(prefix)`. Vychozi hodnoty jsou realne komponenty.
#
# CO ZATIM NENI (otevrene): zmena `z` na schodech (docs/05 §5.1.2) - schody se
# dnes chovaji jako `Surface` dlazdice, takze se po nich jde, ale vyska se
# z nich nepocita; `Door` se nekontroluje (otevrene dvere jsou pruchodne).

var _map = null
var _tiledata = null
var _stairs = null


func _init(map = null, tiledata = null, stairs = null) -> void:
	_map = map if map != null else MapScript.new()
	_tiledata = tiledata if tiledata != null else TiledataScript.new()
	_stairs = stairs if stairs != null else StairsScript.new()


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
	if _blokuje_statik(to.x, to.y):
		return _no("blocked")
	var z: int = _surface_z(to.x, to.y)
	if not _fits(from.z, z, height):
		return _no("height")
	return {"ok": true, "z": z, "reason": ""}


func surface_z(x: int, y: int) -> int:
	# Nejnizsi povrch, na ktery se da stanout: land, nebo vyssi statik s `Surface`.
	return _surface_z(x, y)


func _land_at(x: int, y: int) -> int:
	var tile = _map.land_at(x, y)
	return -1 if tile == null else int(tile)


func _surface_z(x: int, y: int) -> int:
	var z: int = int(_map.z_at(x, y))
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		if _tiledata.flags(tile) & F_SURFACE == 0:
			continue
		var top: int = int(s["z"]) + _tiledata.height(tile)
		if top > z:
			z = top
	return z


func _statiky(x: int, y: int) -> Array:
	# `world.map.statics_at` vraci CELY blok (s lokalnim x,y) - hledame jen
	# statiky na nasi dlazdici (dokud se smlouva nezmeni, viz vada ZADANI 15).
	var out: Array = []
	for s in _map.statics_at(x, y):
		if int(s["x"]) == x % Const.BLOCK_SIZE and int(s["y"]) == y % Const.BLOCK_SIZE:
			out.append(s)
	return out


func _blokuje_statik(x: int, y: int) -> bool:
	# Statik blokuje, kdyz ma `Impassable` nebo je to kontejner. `Door` se
	# nekontroluje (otevrene dvere jsou pruchodne) - viz otevrena vec v hlavicce.
	for s in _statiky(x, y):
		var sf: int = _tiledata.flags(int(s["tile"]))
		if sf & (F_IMPASSABLE | F_CONTAINER) != 0:
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
	for s in _statiky(x, y):
		var tile: int = int(s["tile"])
		var sf: int = _tiledata.flags(tile)
		if sf & (F_IMPASSABLE | F_CONTAINER) != 0:
			return false
		if sf & F_SURFACE != 0 and not _fits(z, int(s["z"]) + _tiledata.height(tile), height):
			return false
	return true


func _fits(z_from: int, z_to: int, height: int) -> bool:
	# Vyskova mezera: rozdil musi byt mensi nez krok (dolu i nahoru). Kdyz je
	# cilova podlaha vys, nevejde se tam postava (`height`), kdyz niz, je to pruchod.
	var dz: int = z_to - z_from
	if dz > Const.STEP_HEIGHT:
		return false
	if dz < -height:
		return false
	return true


func _no(reason: String) -> Dictionary:
	return {"ok": false, "z": 0, "reason": reason}
