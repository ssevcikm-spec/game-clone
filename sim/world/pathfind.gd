extends RefCounted
# sim.pathfind - hledani cesty A* nad dlazdicemi (granule `sim.pathfind`, M2).
#
# PROC: `sim.movement` umi jeden krok a `world.walk` rekne, jestli krok projde,
# ale "doved me z A do B" neumi nikdo. Bez toho nema click-to-move ani `sim.ai`
# co volat (ZADANI-DALSI-VYVOJ-2 §3 ukol 2, revize N6).
#
# ⚠ TVAR SMLOUVY NENI V docs/04 §4.2 - je jen v roadmape ("pathfinding v docs
# NENI vubec", ZADANI-DALSI-VYVOJ §3 ukol 5). Beru ji z roadmapy:
#   `find(from, to, limit) -> Array[Vector3i]`, `next_step(from, to) -> Vector3i`.
# Agent docs/ needituje - vada se hlasi, nezapisuje.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2):
#   * `limit` = ROZPOCET UZLU (ne delka cesty); 0 = `NODES_DEFAULT`. Je to
#     obrana proti hledani pres celou mapu: kdyz se vycerpa, vrati se prazdna
#     cesta, ne half-path (volajici se to dozvi z `find(...).is_empty()`),
#   * `next_step` vraci PRAZDNY `Vector3i` a `find` prazdne pole, kdyz cesta
#     NEEXISTUJE - "prazdno" je jedina odpoved, proto se u `next_step` nesmi
#     poznat "nenalezeno" od "uz tam jsem" (na to je `find`),
#   * cesta se hleda na souradnice x,y; `to.z` je cilova VYSKA, ktera se musi
#     trefit (jinak by cesta "nahoru na balkon" skoncila pod nim),
#   * `nodes_visited()` a `cost_last()` jsou NAVIC proti smlouvě - pouziva je
#     jen test (a budouci `app.metrics`),
#   * poradi smeru je z `core.const` (0..7), zadna vlastni tabulka.
#
# ⚠ PRUCHODNOST SE PTÁ `world.walk.can_step` - NIKDY vlastni kopie pravidel
# (zadani to zduraznuje): jinak by se pravidla rozejla na dvou mistech a cesta
# by vedla tam, kam se mobil nedostane. Dusledek: kdo zmeni `walk`, zmeni i
# cesty, a test to musi videt (proto ma test svoji `walk` a pocita jeji volani).
#
# ALGORITMUS (recept z referenci, ne z dojmu; viz tools/refs-index.py):
#   * cenik kroku: ortogonala 100, diagonala 141 (`FastAStarAlgorithm.cs:33-43`
#     nasobi 11; my mame mensi cisla, pomer je stejny) - vsechno INT, protoze
#     float v cene je drift (docs/09 §9.10 bod 3),
#   * heuristika: OCTILOVA vzdalenost (diagonala 141, zbytek 100) + |dz| * 8.
#     Krome pripustnosti splnuje i trojuhelnikovou nerovnost (je
#     KONZISTENTNI), takze A* smi skoncit prvnim nalezenym cilem. Pozor:
#     Chebyshev * 100 (driv) je taky pripustny i konzistentni - vyslo to
#     v mereni na 256 cilech (0 rozdilnych cest, jen o 13 % vic rozbalenych
#     uzlu: 19207 vs 16673), takze octil je ZEFEKTIVNENI, ne oprava vady,
#   * rozpocty: `MaxSearchNodes` = 1000 v ModernUO (`dev-docs/pathfinding.md:81`),
#     `MaxDepth` = 300 a oblast 38x38 v ServUO (`FastAStarAlgorithm.cs:26-28`),
#   * hleda se v uzavrene OBLASTI: bez `limit` by se prohledala cela mapa.
#
# CO ZATIM NENI (otevrene, hlasim - neresim tady): cesta se NEOVLIVNUJE
# pruchodnosti dveri (`world.walk` je zatim neresi, vada F9), neumi schody
# (vyska se bere z `walk.can_step`), neumi moby (druhe postavy) a neresi
# dosah/pereferenci trasy jako klient (`ClassicUO Pathfinder.cs:868`).

const Const = preload("res://core/const.gd")
const WalkScript = preload("res://sim/world/walk.gd")

const NODES_DEFAULT: int = 1000    # rozpocet uzlu na jedno hledani
const COST_STEP: int = 100         # ortogonalni krok
const COST_DIAG: int = 141         # diagonala (100 * sqrt(2), zaokrouhleno)
const COST_Z: int = 8              # cena za jednotku vysky v heuristice

var _walk = null
var _nodes: int = 0                # kolik uzlu se pri poslednim hledani rozbalilo
var _last_cost: int = -1           # cena posledni nalezene cesty (-1 = zadna)


func _init(walk = null) -> void:
	_walk = walk if walk != null else WalkScript.new()


func nodes_visited() -> int:
	# NAVIC proti smlouvě: test (a budouci `app.metrics`) se ptá, kolik prace
	# hledani stalo. Bez toho by "naslo to" neslo odlisit od "prohledalo vse".
	return _nodes


func cost_last() -> int:
	# NAVIC proti smlouvě: cena posledni nalezene cesty (ortogonala 100,
	# diagonala 141). Bez toho by se dalo merit jen KOLIK kroku cesta ma, a to
	# nerozlisti "diagonala je vyhodnejsi" od "pocita se stejne" - presne tuhle
	# slepou skvrnu odhalil mutacni test (mutant s diagonalou za 200 prosel).
	return _last_cost


func find(from: Vector3i, to: Vector3i, limit: int = 0) -> Array:
	# Cesta jako posloupnost dlazdic OD PRVNIHO KROKU do cile (start v ni NENI):
	# 3 kroky = 3 prvky. Kdyz cesta neni (voda, zed, rozpocet, mimo mapu),
	# vraci PRAZDNE pole.
	_nodes = 0
	_last_cost = -1
	if from.x == to.x and from.y == to.y:
		return []
	var budget: int = limit if limit > 0 else NODES_DEFAULT
	var start: Vector3i = from
	var g: Dictionary = {start: 0}
	var parent: Dictionary = {}
	var frontier: Array = [start]
	var in_frontier: Dictionary = {start: true}
	while not frontier.is_empty():
		var index := _best(frontier, g, to)
		var cur: Vector3i = frontier[index]
		frontier.remove_at(index)
		in_frontier.erase(cur)
		if cur.x == to.x and cur.y == to.y and cur.z == to.z:
			_last_cost = int(g[cur])
			return _path(parent, cur, from)
		_nodes += 1
		if _nodes > budget:
			break
		for dir in 8:
			var step: Dictionary = _walk.can_step(cur, dir)
			if not step["ok"]:
				continue
			var nxt := Vector3i(cur.x + Const.DIR_DX[dir], cur.y + Const.DIR_DY[dir], int(step["z"]))
			if nxt == cur:
				continue
			var cost: int = COST_STEP if dir % 2 == 0 else COST_DIAG
			var g_nxt: int = int(g[cur]) + cost
			if g.has(nxt) and int(g[nxt]) <= g_nxt:
				continue
			g[nxt] = g_nxt
			parent[nxt] = cur
			if not in_frontier.has(nxt):
				frontier.append(nxt)
				in_frontier[nxt] = true
	return []


func next_step(from: Vector3i, to: Vector3i) -> Vector3i:
	# Prvni krok cesty. Kdyz cesta neni, vraci prazdny `Vector3i` (= (0,0,0)):
	# na "nenalezeno" se ptá `find(...).is_empty()`, ne tady (viz hlavicka).
	var cesta: Array = find(from, to)
	if cesta.is_empty():
		return Vector3i.ZERO
	return cesta[0]


func _best(frontier: Array, g: Dictionary, to: Vector3i) -> int:
	# Linearni hledani minima - stejne jako reference (`FindBest` v ServUO,
	# open list v ClassicUO). Halda by usetrila cas, ale zmenila by poradi
	# rovnych uzlu, tedy i tvar cesty; determinismus je dulezitejsi.
	var best: int = 0
	var best_f: int = int(g[frontier[0]]) + _heuristic(frontier[0], to)
	for i in range(1, frontier.size()):
		var f: int = int(g[frontier[i]]) + _heuristic(frontier[i], to)
		if f < best_f:
			best = i
			best_f = f
	return best


func _heuristic(a: Vector3i, to: Vector3i) -> int:
	# OCTILOVA vzdalenost: min(dx,dy) diagonal za 141 + zbytek kroku za 100.
	# Je to PRESNA cena nejlepsi mozne cesty jen tehdy, kdyz nic nestoji v ceste
	# (jinak ji podstreluje) - tedy pripustna, a navic splnuje trojuhelnikovou
	# nerovnost, takze je KONZISTENTNI a A* smi skoncit prvnim nalezenym cilem.
	#
	# ⚠ POZOR, AT SE TO NEOPRAVUJE ZNOVU: heuristika `maxi(dx, dy) * COST_STEP`
	# (Chebyshev * 100) je TAKY pripustna i konzistentni - namEReno 2026-10-07
	# na 256 cilech: 0 rozdilnych cest, jen 19 207 rozbalenych uzlu misto
	# 16 673. Octil je tedy USPORA (o 13 %), ne oprava - a kdo si v testech
	# vymysli, ze "stara heuristika vraci spatnou cestu", meri neco jineho
	# (presne to se stalo: test cekal u (0,0)->(2,2) cenu 241, ale spravne je
	# 282, protoze dve diagonaly jsou tam nejlepsi cesta).
	var dx: int = absi(a.x - to.x)
	var dy: int = absi(a.y - to.y)
	var dz: int = absi(a.z - to.z)
	var diagonal: int = mini(dx, dy)
	var rovne: int = maxi(dx, dy) - diagonal
	return diagonal * COST_DIAG + rovne * COST_STEP + dz * COST_Z


func _path(parent: Dictionary, goal: Vector3i, start: Vector3i) -> Array:
	var out: Array = []
	var cur: Vector3i = goal
	while cur != start and parent.has(cur):
		out.append(cur)
		cur = parent[cur]
	out.reverse()
	return out
