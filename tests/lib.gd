extends RefCounted
# Pomocniky pro case soubory v tests/cases/.
#
# Neni to soucast hry - jen testovaci infrastruktura (proto tu nejsou zadne
# herni nazvy API). Harness (tests/run_tests.gd) dava case souborum jen
# `_check()` a `_pending()`; cteni souboru granul si resi pres tenhle pomocnik.


static func script_at(path: String):
	return load(path) if FileAccess.file_exists(path) else null


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
