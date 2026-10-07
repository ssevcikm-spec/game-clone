extends SceneTree
# Headless test harness (docs/04 §4.8). Spousteni:
#   godot --headless --path . --script res://tests/run_tests.gd
#
# Testy jsou SPEC (docs/09 §9.5) - agent je NEMENI. Kontroly v tests/cases/*.gd
# jsou NEPODMINENE: kdyz soubor granule chybi, kontrola SPADNE (podmineny test
# je casovana bomba - mlci presne do chvile, kdy ma merit).
# Vystup: "N kontrol, M selhani"; exit 0 = ok, 1 = selhalo, 2 = 0 kontrol.
#
# Harness dava k dispozici jen `_check()` a `_pending()` (coz je deklarovane
# `provides`); nacteni souboru a konstant si resi kazdy case sam.
const CASES_DIR := "res://tests/cases"
var _checks: int = 0
var _failed: int = 0

func _check(ok: bool, name: String) -> void:
	_checks += 1
	if ok:
		return
	_failed += 1
	print("[test] FAIL ", name)

func _pending(text: String) -> void:
	# Kontrola, ktera se neda provest (granule neni hotova) - NENI zelena.
	_check(false, text)

func _init_case(path: String):
	# POZOR (namEReno 2026-10-07, otevrena vec 21): `load()` na case soubor
	# s PARSE ERROREM vraci NENULOVY `GDScript`, ktery nejde instanciovat.
	# `script.new()` pak vyhodi runtime error, `_init_case` se PRERUSI a vrati
	# `null` - a `_initialize` to pochopil jako "uz o hlaseno" a soubor TISE
	# preskocil (namEReno: 503 kontrol, 0 selhani; spravne 537). Proto:
	#   * ptame se `can_instantiate()` PRED `new()`,
	#   * kazdou cestu, ktera vraci `null`, hlasime (viz i guard v `_initialize`).
	if not FileAccess.file_exists(path):
		_pending("case soubor " + path + " neexistuje")
		return null
	var script = load(path)
	if script == null or not (script is GDScript) or not script.can_instantiate():
		_pending("case soubor " + path + " nelze nacist (parse error?)")
		return null
	var test_case = script.new()
	if test_case == null or not test_case.has_method("run"):
		_pending("case " + path + " nema run(t)")
		return null
	return test_case

func _initialize() -> void:
	var dir := DirAccess.open(CASES_DIR)
	if dir == null:
		print("[test] CHYBA: nelze otevrit ", CASES_DIR, " (err=", DirAccess.get_open_error(), ")")
		print("[test] 0 kontrol, 1 selhani")
		quit(1)
		return
	var files: Array[String] = []
	for name in dir.get_files():
		if name.ends_with(".gd"):
			files.append(name)
	files.sort()
	print("[test] case souboru: ", files.size())
	var spusteno: int = 0
	for name in files:
		var pred_selhani: int = _failed
		var pred_kontrol: int = _checks
		var test_case = _init_case(CASES_DIR + "/" + name)
		if test_case == null:
			# Ticha cesta je vada harnessu: `_init_case` selhani o hlasit MUSI.
			if _failed == pred_selhani:
				_pending("case soubor " + name + " se nenacetl a nikdo to neohlasil")
			continue
		print("[test] -- ", name)
		test_case.run(self)
		# Case, ktery nepridal ani jednu kontrolu, nic nezmeril - i kdyby jeho
		# `run()` probehl prazdny (nebo se prerusil na prvnim radku).
		if _checks == pred_kontrol:
			_pending("case " + name + " neprobehl: 0 novych kontrol")
		spusteno += 1
	print("[test] case souboru spusteno: ", spusteno, " z ", files.size())
	var status: int = 0
	if _checks == 0:
		status = 2
		print("[test] NEMERENO: 0 kontrol (docs/08 §8.6)")
	elif _failed > 0:
		status = 1
	print("[test] ", _checks, " kontrol, ", _failed, " selhani")
	quit(status)
