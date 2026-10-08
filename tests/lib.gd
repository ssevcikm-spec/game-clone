extends RefCounted
# Pomocniky pro case soubory v tests/cases/.
#
# Neni to soucast hry - jen testovaci infrastruktura (proto tu nejsou zadne
# herni nazvy API). Harness (tests/run_tests.gd) dava case souborum jen
# `_check()` a `_pending()`; cteni souboru granul si resi pres tenhle pomocnik.


static func script_at(path: String):
	# POZOR (namEReno 2026-10-07, otevrena vec 21): `load()` na soubor s PARSE
	# ERROREM vraci NENULOVY `GDScript`, ktery ale nejde instanciovat. Kdo na nem
	# zavola `new()`, dostane runtime error a jeho funkce se PRERUSI - case pak
	# tise zmeri mene kontrol a sada hlasi "0 selhani" (namEReno: 503 misto 537).
	# Vracime proto `null`, aby to case ohlasil jako NEMERENO.
	if not FileAccess.file_exists(path):
		return null
	var script = load(path)
	if script == null or not (script is GDScript) or not script.can_instantiate():
		return null
	return script


static func new_at(path: String):
	var script = script_at(path)
	return null if script == null else script.new()


static func consts_at(path: String) -> Dictionary:
	var script = script_at(path)
	return {} if script == null else script.get_script_constant_map()


static func json_at(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func text_at(path: String) -> String:
	# Text souboru pro STATICKE brany, ktere se musi zeptat na obsah (napr. "vola
	# to `_start_stats()`?"). Chybejici soubor vraci prazdny retezec - volajici
	# tim spadne (`contains` false), coz je spravne: chybejici soubor neni
	# "v poradku". (Kdyby vracel null, padl by `contains` na type error.)
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)
