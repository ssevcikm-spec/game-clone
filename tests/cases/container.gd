extends RefCounted
# entity.container - kontejner (smlouva docs/04 §4.2, limity docs/05 §5.4).
#
# Test meri, ze:
#   * `add` je JEDINA cesta, jak predmet zmeni rodice - invariant "prave jeden
#     rodic": predmet ve dvou kontejnerech byt nemuze,
#   * limity plati presne: pocet predmetu (`full`), vaha (`weight`) a hromada
#     60000 (`stack`) - a kdyz `add` neprojde, stav se NEZMENI,
#   * `contents` vraci serialy serazene (na poradi vlozeni nesmi zaviset stav),
#   * `remove` vraci, KOLIK opravdu odstranil, a nedotkne se jineho kontejneru,
#   * hromady se slucuji do `MAX_STACK` (jen kdyz ma predmet v tiledata flag
#     `Generic`), a co se nevejde, zustane predmetu.
#
# Vahu a stackable flag bere kontejner z tiledata, proto test podstrkuje STUB
# (`StubTiledata`) - meri se tim i v CI, kde `assets/uo/` nejsou. Sekce K)
# navic meri REALNA data, kdyz na disku jsou (bez nich hlasi NEMERENO).
#
# Cesta k souboru je VSTUP: `-- --container-script=<cesta>`.

const Lib = preload("res://tests/lib.gd")
const ITEM_SCRIPT := "res://sim/entity/item.gd"
const CONTAINER_SCRIPT := "res://sim/entity/container.gd"
const TILES_PATH := "res://assets/uo/tiles.json"
const REAL_TILEDATA_SCRIPT := "res://sim/world/tiledata.gd"

const GOLD := 0x4EED        # zlato - stackable (art id; docs/03 §3.4: item id = art id)
const DAGGER := 0x4F52      # dyka - NENI stackable
const LONGSWORD := 0x4F61   # mec - NENI stackable, 7 stones
const F_STACKABLE := 0x00000800  # TileFlag.Generic


class StubTiledata extends RefCounted:
	# Nahrazuje `world.tiledata` (vahu a flagy podle `tile`).
	var _vahy: Dictionary = {}
	var _flagy: Dictionary = {}

	func _init(vahy: Dictionary, flagy: Dictionary) -> void:
		_vahy = vahy
		_flagy = flagy

	func weight(tile: int) -> int:
		return int(_vahy.get(tile, 0))

	func flags(tile: int) -> int:
		return int(_flagy.get(tile, 0))


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _stub(vahy: Dictionary, stackovane: Array) -> StubTiledata:
	var flagy: Dictionary = {}
	for tile in stackovane:
		flagy[tile] = F_STACKABLE
	return StubTiledata.new(vahy, flagy)


func _serialy(a) -> Array:
	# Prevod na ne typovane pole (obsahova rovnost se pak cte snadno).
	var out: Array = []
	for x in a:
		out.append(int(x))
	return out


func run(t) -> void:
	var cesta: String = _arg("container-script", CONTAINER_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.entity.container NENI HOTOVY: " + cesta + " chybi (nebo nejde nacist)")
		return
	var item_cesta: String = _arg("item-script", ITEM_SCRIPT)
	var item_script = Lib.script_at(item_cesta)
	if item_script == null:
		t._pending("sim.entity.container NEMEREN: predmet nejde nacist z " + item_cesta)
		return
	var st := _stub({GOLD: 2, DAGGER: 1, LONGSWORD: 7}, [GOLD])
	var k = script.new(st)

	# A) PRAZDNY KONTEJNER a stav "vaha se nemeri"
	t._check(_serialy(k.contents(1)).is_empty() and k.weight_of(1) == 0,
		"sim.entity.container: novy kontejner je prazdny a vazi 0")
	t._check(k.has_weights(), "sim.entity.container: s tiledata se vaha MERI (has_weights)")
	var bez = script.new()
	t._check(not bez.has_weights() and bez.weight_of(1) == 0,
		"sim.entity.container: bez tiledata se vaha NEMERI (has_weights false, nula neni uspech)")

	# B) ADD: rodic, obsah, a to, ze predmet opusti "na zemi"
	var zlato = item_script.new(0x00000064, GOLD, 10)
	t._check(k.can_add(1, zlato).get("ok", false),
		"sim.entity.container: prvni predmet se vejde")
	t._check(k.add(1, zlato), "sim.entity.container: add vraci true")
	t._check(zlato.parent == 1 and not zlato.is_on_ground(),
		"sim.entity.container: po add ma predmet parent = serial kontejneru")
	t._check(_serialy(k.contents(1)) == [0x00000064],
		"sim.entity.container: contents vraci serial predmetu (vyslo %s)" % str(k.contents(1)))

	# C) SERAZENE: poradi vlozeni nesmi rozhodovat
	var k2 = script.new(st)
	k2.add(7, item_script.new(300, DAGGER, 1))
	k2.add(7, item_script.new(100, DAGGER, 1))
	k2.add(7, item_script.new(200, DAGGER, 1))
	t._check(_serialy(k2.contents(7)) == [100, 200, 300],
		"sim.entity.container: contents je serazene podle serialu (vyslo %s)" % str(k2.contents(7)))

	# D) LIMIT PREDMETU: 2 se vejdou, treti ne - a stav se nezmeni
	var maly = script.new(st, 2, 4000)
	var d1 = item_script.new(11, DAGGER, 1)
	var d2 = item_script.new(12, DAGGER, 1)
	var d3 = item_script.new(13, DAGGER, 1)
	t._check(maly.add(9, d1) and maly.add(9, d2),
		"sim.entity.container: dva predmety se do limitu 2 vejdou")
	var verdikt: Dictionary = maly.can_add(9, d3)
	t._check(not verdikt.get("ok", true) and verdikt.get("reason", "") == "full",
		"sim.entity.container: nad limit vraci {ok:false, reason:'full'} (vyslo %s)" % str(verdikt))
	t._check(not maly.add(9, d3) and _serialy(maly.contents(9)).size() == 2 and d3.parent == 0,
		"sim.entity.container: neuspesny add stav NEZMENI (obsah %d, parent %d)"
		% [_serialy(maly.contents(9)).size(), d3.parent])

	# E) LIMIT VAHY: 7 + 7 > 10 stones
	var tezky = script.new(st, 125, 10)
	var m1 = item_script.new(21, LONGSWORD, 1)
	var m2 = item_script.new(22, LONGSWORD, 1)
	t._check(tezky.add(5, m1) and tezky.weight_of(5) == 7,
		"sim.entity.container: vaha obsahu je 7 stones (vyslo %d)" % tezky.weight_of(5))
	var verdikt2: Dictionary = tezky.can_add(5, m2)
	t._check(not verdikt2.get("ok", true) and verdikt2.get("reason", "") == "weight",
		"sim.entity.container: nad vahu vraci {ok:false, reason:'weight'} (vyslo %s)" % str(verdikt2))
	t._check(not tezky.add(5, m2) and _serialy(tezky.contents(5)).size() == 1,
		"sim.entity.container: neuspesny add kvuli vaze stav NEZMENI")
	# vaha se pocita z MNOZSTVI (5 zlataku po 2 stones = 10, ne 2)
	var vahovy = script.new(st, 125, 1000000)
	vahovy.add(1, item_script.new(131, GOLD, 5))
	t._check(vahovy.weight_of(1) == 10,
		"sim.entity.container: vaha 5 zlataku po 2 stones je 10 (vyslo %d)" % vahovy.weight_of(1))

	# F) LIMIT HROMADY: 60000 se vejde, 60001 ne (limit vahy tu neprekazi)
	var hromada = script.new(st, 125, 1000000000)
	var plna = item_script.new(31, GOLD, 60000)
	var moc = item_script.new(32, GOLD, 60001)
	t._check(hromada.add(3, plna), "sim.entity.container: hromada 60000 se vejde (MAX_STACK)")
	var verdikt3: Dictionary = hromada.can_add(3, moc)
	t._check(not verdikt3.get("ok", true) and verdikt3.get("reason", "") == "stack",
		"sim.entity.container: 60001 vraci {ok:false, reason:'stack'} (vyslo %s)" % str(verdikt3))
	t._check(_serialy(hromada.contents(3)).size() == 1 and plna.amount == 60000,
		"sim.entity.container: nad MAX_STACK se nepridalo (obsah %d)"
		% _serialy(hromada.contents(3)).size())

	# G) OSTATNI DUVODY: tvar odpovedi, zadny pad
	t._check(k.can_add(1, null).get("reason", "") == "no_item",
		"sim.entity.container: null predmet vraci no_item")
	t._check(k.can_add(0, zlato).get("reason", "") == "no_container",
		"sim.entity.container: kontejner 0 vraci no_container")
	t._check(k.can_add(1, {"tile": 1}).get("reason", "") == "no_item",
		"sim.entity.container: slovnik misto predmetu vraci no_item (ne pad)")
	var bezser = item_script.new(0, DAGGER, 1)
	t._check(k.can_add(1, bezser).get("reason", "") == "no_serial" and not k.add(1, bezser),
		"sim.entity.container: predmet bez serialu se neprijme")
	var prazdny = item_script.new(40, DAGGER, 0)
	t._check(k.can_add(1, prazdny).get("reason", "") == "amount" and not k.add(1, prazdny),
		"sim.entity.container: prazdna hromada (amount 0) se neprijme")

	# H) INVARIANT "PRAVE JEDEN RODIC" - jedna instance spravuje OBA kontejnery
	#    (kdyby mel kazdy kontejner vlastni instanci, `add` by o predchozim
	#    rodici nevedel a predmet by zustal v obou - viz hlavicka modulu)
	var sklad = script.new(st)
	var vec = item_script.new(50, DAGGER, 1)
	sklad.add(101, vec)
	t._check(_serialy(sklad.contents(101)).size() == 1 and vec.parent == 101,
		"sim.entity.container: predmet je v prvnim kontejneru")
	sklad.add(202, vec)
	t._check(vec.parent == 202 and _serialy(sklad.contents(202)).size() == 1
		and _serialy(sklad.contents(101)).is_empty(),
		"sim.entity.container: po add do druheho kontejneru je predmet jen v nem (c1 %s)"
		% str(sklad.contents(101)))
	t._check(not sklad.add(202, vec) and _serialy(sklad.contents(202)).size() == 1,
		"sim.entity.container: druhy add TÉHOŽ predmetu nic nezmeni (already_here)")

	# I) SLOUCOVANI HROMAD
	var k3 = script.new(st, 125, 1000000)
	var z1 = item_script.new(61, GOLD, 30)
	var z2 = item_script.new(62, GOLD, 30)
	k3.add(1, z1)
	k3.add(1, z2)
	t._check(_serialy(k3.contents(1)).size() == 1 and z1.amount == 60
		and z2.amount == 0 and z2.parent == 0,
		"sim.entity.container: zlato 30+30 splyne v jednu hromadu 60 (obsah %d, druhy %d)"
		% [_serialy(k3.contents(1)).size(), z2.amount])
	var k4 = script.new(st, 125, 1000000)
	k4.add(1, item_script.new(71, DAGGER, 1))
	k4.add(1, item_script.new(72, DAGGER, 1))
	t._check(_serialy(k4.contents(1)).size() == 2,
		"sim.entity.container: dve dyky se neslouci (nejsou stackable)")
	var k5 = script.new(st, 125, 1000000)
	k5.add(1, item_script.new(81, GOLD, 5))
	var jina = item_script.new(82, GOLD, 5)
	jina.hue = 1002
	k5.add(1, jina)
	t._check(_serialy(k5.contents(1)).size() == 2,
		"sim.entity.container: zlato jine barvy se neslouci (hue)")
	var k6 = script.new(st, 125, 1000000)
	var skoro = item_script.new(91, GOLD, 59990)
	var dosyp = item_script.new(92, GOLD, 30)
	k6.add(1, skoro)
	k6.add(1, dosyp)
	t._check(skoro.amount == 60000 and dosyp.amount == 20
		and _serialy(k6.contents(1)).size() == 2,
		"sim.entity.container: slouceni se zastavi na MAX_STACK (prvni %d, druhy %d, obsah %d)"
		% [skoro.amount, dosyp.amount, _serialy(k6.contents(1)).size()])
	var k7 = script.new(st, 1, 1000000)
	k7.add(1, item_script.new(95, GOLD, 60000))
	var navic = item_script.new(96, GOLD, 5)
	var verdikt7: Dictionary = k7.can_add(1, navic)
	t._check(not verdikt7.get("ok", true) and verdikt7.get("reason", "") == "full"
		and not k7.add(1, navic),
		"sim.entity.container: plna hromada neni cil slouceni (limit 1 predmet, vyslo %s)"
		% str(verdikt7))

	# J) REMOVE: vrati, kolik opravdu odstranil
	var k8 = script.new(st, 125, 1000000)
	var ranec = item_script.new(111, GOLD, 10)
	k8.add(1, ranec)
	var vzato: int = k8.remove(1, 111, 3)
	t._check(vzato == 3 and ranec.amount == 7,
		"sim.entity.container: remove(3) z hromady 10 vrati 3 a necha 7 (vyslo %d, zbyva %d)"
		% [vzato, ranec.amount])
	var vzato2: int = k8.remove(1, 111, 100)
	t._check(vzato2 == 7 and ranec.amount == 0 and ranec.parent == 0
		and _serialy(k8.contents(1)).is_empty(),
		"sim.entity.container: remove(100) z hromady 7 vrati 7 a predmet opusti kontejner "
		+ "(vyslo %d, parent %d)" % [vzato2, ranec.parent])
	t._check(k8.remove(1, 111, 1) == 0,
		"sim.entity.container: remove neexistujiciho predmetu vrati 0")
	var k9 = script.new(st, 125, 1000000)
	var druhy_ranec = item_script.new(121, GOLD, 10)
	k9.add(1, druhy_ranec)
	t._check(k9.remove(2, 121, 1) == 0 and druhy_ranec.amount == 10
		and _serialy(k9.contents(1)).size() == 1,
		"sim.entity.container: remove z JINEHO kontejneru predmet nevyjme (amount %d)"
		% druhy_ranec.amount)
	var vse: int = k9.remove(1, 121, 0)
	t._check(vse == 10 and _serialy(k9.contents(1)).is_empty(),
		"sim.entity.container: amount <= 0 vyjme celou hromadu (vyslo %d)" % vse)

	# K) REALNA DATA (jen kdyz jsou; v CI se to hlasi jako NEMERENO, ne jako vada)
	if not FileAccess.file_exists(TILES_PATH):
		print("[test] sim.entity.container: REALNA DATA NEMERENA (chybi ", TILES_PATH, ")")
		return
	var real = Lib.script_at(REAL_TILEDATA_SCRIPT)
	if real == null:
		print("[test] sim.entity.container: REALNA DATA NEMERENA (chybi ", REAL_TILEDATA_SCRIPT, ")")
		return
	var td = real.new()
	var kr = script.new(td, 125, 1000000)
	var zl = item_script.new(201, GOLD, 100)
	kr.add(1, zl)
	kr.add(1, item_script.new(202, DAGGER, 1))
	t._check(_serialy(kr.contents(1)).size() == 2 and zl.amount == 100,
		"sim.entity.container: v realnych datech se zlato neslucuje s dykou")
	var zl2 = item_script.new(203, GOLD, 1)
	kr.add(1, zl2)
	t._check(zl.amount == 101 and zl2.amount == 0,
		"sim.entity.container: v realnych datech se zlato sluci (flag Generic, amount %d)"
		% zl.amount)
	var mec = item_script.new(204, LONGSWORD, 3)
	t._check(mec.pile_weight(td.weight(LONGSWORD)) == 21,
		"sim.entity.container: longsword 3x7 stones = 21 (vyslo %d)"
		% mec.pile_weight(td.weight(LONGSWORD)))
