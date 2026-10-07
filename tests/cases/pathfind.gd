extends RefCounted
# sim.pathfind - hledani cesty (docs/04 §4.2 az bude smlouva; dnes roadmapa).
#
# Test meri ALGORITMUS na FAKE `walk` a na mape z `Dictionary`: `assets/uo/` je
# v gitignore, takze v CI zadna realna data nejsou a test nad nimi by tam nemel
# co merit (stejny pristup jako tests/cases/walk.gd).
#
# Cesta k souboru je VSTUP (`-- --pathfind-script=<cesta>`), aby mutacni test
# mohl predat mutanta a aby se overilo, ze test meri opravdu ten soubor.
#
# ⚠ CO TEST MERI PREDEVSIM: ze se pathfind PTÁ `walk.can_step` a neopisuje si
# pravidla. Dokazuje se to tim, ze `walk` je STUB, ktery si prohlasuje, ktere
# dlazdice jsou pruchodne - kdyby mel pathfind vlastni kopii pravidel, stub
# by neobesel a pocet kroku by nesedel.

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")

const PATHFIND_SCRIPT := "res://sim/world/pathfind.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class StubWalk:
	# Pruchodnost se urcuje podle MAPY: klice jsou `Vector2i` zakazanych
	# dlazdic. Zaznamenava si kazde volani, aby se dalo overit, ze se na nej
	# pathfind opravdu ptá (a kolikrat).
	var zakazane := {}          # Vector2i -> true (Wet/Impassable)
	var zs := {}                # Vector2i -> vyska (0, kdyz neni)
	var calls: Array = []       # [Vector3i(from), dir]
	var default_ok := true      # mimo mapu vraci `off_map`, kdyz je false

	func can_step(from: Vector3i, dir: int, _height: int = 16, _is_player: bool = true) -> Dictionary:
		calls.append([from, dir])
		if dir < 0 or dir > 7:
			return {"ok": false, "z": 0, "reason": "bad_dir"}
		var to := Vector2i(from.x + Const.DIR_DX[dir], from.y + Const.DIR_DY[dir])
		if zakazane.has(to):
			return {"ok": false, "z": 0, "reason": "blocked"}
		if not default_ok and (to.x < 0 or to.y < 0 or to.x > 9 or to.y > 9):
			return {"ok": false, "z": 0, "reason": "off_map"}
		return {"ok": true, "z": int(zs.get(to, 0)), "reason": ""}


func _walk(zakazane: Array = []) -> StubWalk:
	var w = StubWalk.new()
	for t in zakazane:
		w.zakazane[t] = true
	return w


func run(t) -> void:
	var script = Lib.script_at(_arg("pathfind-script", PATHFIND_SCRIPT))
	if script == null:
		t._pending("sim.pathfind NENI HOTOVA: " + _arg("pathfind-script", PATHFIND_SCRIPT) + " chybi")
		return

	# 1) primka cesta po otevrene plani: 5 kroku na vychod, kazdy krok je soused
	var volno = _walk()
	var pf = script.new(volno)
	var cesta: Array = pf.find(Vector3i(0, 0, 0), Vector3i(5, 0, 0))
	t._check(cesta.size() == 5 and cesta[0] == Vector3i(1, 0, 0) and cesta[4] == Vector3i(5, 0, 0),
		"sim.pathfind: cesta na vychod o 5 dlazdic ma 5 kroku (namEReno %s)" % str(cesta))
	var souvisla := true
	var predchozi := Vector3i(0, 0, 0)
	for krok in cesta:
		if absi(krok.x - predchozi.x) > 1 or absi(krok.y - predchozi.y) > 1:
			souvisla = false
		predchozi = krok
	t._check(souvisla, "sim.pathfind: kazdy krok je sousedni dlazdice (namEReno %s)" % str(cesta))
	t._check(volno.calls.size() > 0,
		"sim.pathfind: pruchodnost se PTÁ `walk.can_step` (namEReno volani %d)" % volno.calls.size())

	# 2) diagonala se vyplati: na otevrene plose 5x5 musi byt 5 kroku, ne 10
	var diag: Array = script.new(_walk()).find(Vector3i(0, 0, 0), Vector3i(5, 5, 0))
	t._check(diag.size() == 5,
		"sim.pathfind: diagonala 5x5 je 5 kroku (ne 10 ortogonalnich; namEReno %d)" % diag.size())

	# 3) prekazka se OBCHAZI dirou: prekazka v x=2 na y=-1..3, dira je na y=2
	#    (rovna cesta na vychod je tedy zavrena a cesta musi jit o 2 radky niz).
	#    Cesta: (0,0) -> (1,1) -> (2,2) = dira -> (3,3) -> (4,4) -> (5,5) -> (6,6)
	var dira = _walk([Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3)])
	var okolo: Array = script.new(dira).find(Vector3i(0, 0, 0), Vector3i(6, 6, 0))
	t._check(okolo.size() == 6,
		"sim.pathfind: pres diru v prekazce to je 6 kroku (namEReno %d)" % okolo.size())
	t._check(okolo.has(Vector3i(2, 2, 0)),
		"sim.pathfind: cesta jde dirou v prekazce (namEReno %s)" % str(okolo))
	# cesta nesmi vstoupit na zakazanou dlazdici ani jednou
	var vstoupil := false
	for krok in okolo:
		if dira.zakazane.has(Vector2i(krok.x, krok.y)):
			vstoupil = true
	t._check(not vstoupil, "sim.pathfind: cesta nikdy nevstoupi na zakazanou dlazdici")

	# 4) cesta pres vodu NEEXISTUJE -> prazdno (ne half-path)
	var ostrov = _walk([Vector2i(3, -4), Vector2i(3, -3), Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 0),
		Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)])
	var za_vodou: Array = script.new(ostrov).find(Vector3i(0, 0, 0), Vector3i(6, 0, 0), 40)
	t._check(za_vodou.is_empty(),
		"sim.pathfind: neexistujici cesta vraci prazdno (namEReno %s)" % str(za_vodou))

	# 5) uz na miste = prazdna cesta; `next_step` na miste vraci (0,0,0)
	var pf2 = script.new(_walk())
	t._check(pf2.find(Vector3i(4, 4, 0), Vector3i(4, 4, 0)).is_empty(),
		"sim.pathfind: start == cil vraci prazdnou cestu")
	t._check(pf2.next_step(Vector3i(4, 4, 0), Vector3i(4, 4, 0)) == Vector3i.ZERO,
		"sim.pathfind: next_step na miste vraci Vector3i.ZERO")

	# 6) next_step vraci PRVNI krok a je to sousedni dlazdice
	var pf3 = script.new(_walk())
	var krok1: Vector3i = pf3.next_step(Vector3i(2, 3, 0), Vector3i(7, 3, 0))
	t._check(krok1 == Vector3i(3, 3, 0),
		"sim.pathfind: next_step z (2,3) na (7,3) vraci (3,3) (namEReno %s)" % str(krok1))
	t._check(absi(krok1.x - 2) <= 1 and absi(krok1.y - 3) <= 1,
		"sim.pathfind: next_step vraci sousedni dlazdici (namEReno %s)" % str(krok1))
	t._check(pf3.next_step(Vector3i(7, 3, 0), Vector3i(2, 3, 0)) == Vector3i(6, 3, 0),
		"sim.pathfind: next_step umi i na zapad")

	# 7) ROZPOCET UZLU: maly rozpocet na dlouhou cestu vraci prazdno, velky ji najde
	var mala: Array = script.new(_walk()).find(Vector3i(0, 0, 0), Vector3i(9, 0, 0), 2)
	t._check(mala.is_empty(),
		"sim.pathfind: vycerpany rozpocet vraci prazdno (namEReno %d kroku)" % mala.size())
	var velka: Array = script.new(_walk()).find(Vector3i(0, 0, 0), Vector3i(9, 0, 0), 200)
	t._check(velka.size() == 9 and script.new(_walk()).nodes_visited() >= 0,
		"sim.pathfind: dostatecny rozpocet cestu najde (namEReno %d kroku)" % velka.size())

	# 7b) CENA CESTY: ortogonala 100, diagonala 141. Tohle je jedine, cim se da
	#     rozlisit "diagonala je vyhodnejsi" od "pocita se stejne" - pocet kroku
	#     to nerozlisti (mutant s diagonalou za 200 proslo vsemi kontrolami vyse).
	#     Na (2,2) je NEJLEPSI cesta 2 diagonaly (2 x 141 = 282): kdo ceká 241,
	#     plete si ji s cestou na (2,1) - proto je tu i ta.
	var dve_diag = script.new(_walk())
	var trasa_diag: Array = dve_diag.find(Vector3i(0, 0, 0), Vector3i(2, 2, 0))
	t._check(dve_diag.cost_last() == 282 and trasa_diag.size() == 2,
		"sim.pathfind: 2 diagonaly na (2,2) stoji 282 a jsou 2 kroky (namEReno %d, %d kroku)"
			% [dve_diag.cost_last(), trasa_diag.size()])
	var smisena = script.new(_walk())
	smisena.find(Vector3i(0, 0, 0), Vector3i(2, 1, 0))
	t._check(smisena.cost_last() == 241,
		"sim.pathfind: diagonala + krok na (2,1) stoji 241 (141 + 100; namEReno %d)" % smisena.cost_last())
	var rovne = script.new(_walk())
	rovne.find(Vector3i(0, 0, 0), Vector3i(9, 0, 0))
	t._check(rovne.cost_last() == 900,
		"sim.pathfind: 9 kroku na vychod stoji 900 (9 x 100; namEReno %d)" % rovne.cost_last())
	var zadna = script.new(_walk())
	zadna.find(Vector3i(0, 0, 0), Vector3i(0, 0, 0))
	t._check(zadna.cost_last() == -1,
		"sim.pathfind: prazdna cesta nema cenu (-1; namEReno %d)" % zadna.cost_last())

	# 7c) HEURISTIKA je PRIPUSTNA i KONZISTENTNI. Kontroluje se na nekolika
	#     vzorcich cesty: odhad z mista NESMI byt vyssi nez cena, kterou z toho
	#     mista jeste opravdu stoji dojit do cile (pripustnost), a u kazde hrany
	#     cesty nesmi klesnout vic, nez kolik hrana stoji (konzistence) - prave
	#     jeji poruseni zpusobilo, ze A* vratil 282 tam, kde je cesta za 241.
	var vzorky := [Vector3i(9, 0, 0), Vector3i(2, 2, 0), Vector3i(5, 5, 0), Vector3i(8, 3, 0)]
	var pripustna := true
	var konzistentni := true
	var prosel := 0
	var chyba := ""
	for cil in vzorky:
		var trasa: Array = script.new(_walk()).find(Vector3i(0, 0, 0), cil)
		var pred := Vector3i(0, 0, 0)
		for na in trasa:
			var h_na: int = script.new(_walk())._heuristic(na, cil)
			var zbyva = script.new(_walk())
			zbyva.find(na, cil)
			if not zbyva.find(na, cil).is_empty() and h_na > zbyva.cost_last():
				pripustna = false
				chyba = "h(%s)=%d > cena %d" % [str(na), h_na, zbyva.cost_last()]
			var krok: int = 100 if (na.x == pred.x or na.y == pred.y) else 141
			if int(script.new(_walk())._heuristic(pred, cil)) - h_na > krok:
				konzistentni = false
				chyba = "h(%s) - h(%s) > %d" % [str(pred), str(na), krok]
			pred = na
			prosel += 1
	t._check(pripustna and prosel > 0,
		"sim.pathfind: heuristika nikde neprekroci skutecnou cenu (kontrolovano %d mist) %s"
			% [prosel, chyba])
	t._check(konzistentni,
		"sim.pathfind: heuristika je konzistentni (odhad neklesne vic, nez stoji krok) %s" % chyba)

	# 8) mimo mapu = prazdno (ne pad) a `nodes_visited` se pocita
	var mimo = _walk()
	mimo.default_ok = false
	var nikam: Array = script.new(mimo).find(Vector3i(0, 0, 0), Vector3i(50, 50, 0), 30)
	t._check(nikam.is_empty(), "sim.pathfind: cil mimo mapu vraci prazdno (namEReno %d)" % nikam.size())
	var pocitadlo = script.new(_walk())
	pocitadlo.find(Vector3i(0, 0, 0), Vector3i(3, 0, 0))
	t._check(pocitadlo.nodes_visited() > 0,
		"sim.pathfind: nodes_visited pocita praci (namEReno %d)" % pocitadlo.nodes_visited())

	# 8b) HEURISTIKA SETRI PRACI: po dlouhe rovne ceste (60 dlazdic) nesmi sada
	#     rozbalit skoro vsechno. Bez heuristiky (Dijkstra) to je radove vic.
	var dlouha = script.new(_walk())
	dlouha.find(Vector3i(0, 0, 0), Vector3i(60, 0, 0), 1000)
	t._check(dlouha.nodes_visited() < 200,
		"sim.pathfind: heuristika setri uzly na dlouhe rovne ceste (namEReno %d)"
			% dlouha.nodes_visited())

	# 9) VYSKA: cesta respektuje z z `walk.can_step` (schod nahoru o 2)
	var schod = _walk()
	schod.zs[Vector2i(2, 0)] = 2
	var nahoru: Array = script.new(schod).find(Vector3i(0, 0, 0), Vector3i(2, 0, 2))
	t._check(nahoru.size() == 2 and nahoru[1] == Vector3i(2, 0, 2),
		"sim.pathfind: cesta jde na cilovou vysku (namEReno %s)" % str(nahoru))

	# 10) REALNA DATA se meri navic, jen kdyz na disku jsou (jinak NEMERENO)
	if not FileAccess.file_exists("res://assets/uo/world") and not DirAccess.dir_exists_absolute("res://assets/uo/world"):
		print("[test]      NEMERENO: sim.pathfind nad realnou mapou - chybi assets/uo/world")
		return
	var real = script.new()
	var od := Vector3i(1495, 1630, real._walk.surface_z(1495, 1630))
	var kam := Vector3i(1499, 1630, real._walk.surface_z(1499, 1630))
	var realna: Array = real.find(od, kam, 4000)
	t._check(realna.size() >= 4 and realna.size() <= 20,
		"sim.pathfind: v Britanii je cesta na 4 dlazdice rozumne dlouha (namEReno %d kroku)"
			% realna.size())
	var z_ok := true
	for krok in realna:
		if krok.z < Const.Z_MIN or krok.z > Const.Z_MAX:
			z_ok = false
	t._check(z_ok, "sim.pathfind: vsechny kroky maji z v rozsahu (%d..%d)" % [Const.Z_MIN, Const.Z_MAX])
