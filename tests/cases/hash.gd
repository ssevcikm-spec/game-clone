extends RefCounted
# core.hash - kanonicky hash stavu (docs/04 §4.2 a §4.7, docs/02 §2.3).
# Kriterium z promptu: dva slovniky s jinym poradim klicu daji stejny hash.
# Zakladni kontrola je i opacna: jiny stav MUSI dat jiny hash (jinak by hash
# nic nemeril - viz docs/08 §8.6).

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://core/hash.gd")
	if script == null:
		t._pending("core.hash NENI HOTOVA: core/hash.gd chybi")
		return
	var hasher = script.new()

	var a: Dictionary = {"z": 1, "a": 2, "m": {"y": 5, "b": 6}}
	var b: Dictionary = {"m": {"b": 6, "y": 5}, "a": 2, "z": 1}
	var ha: String = hasher.of_state([a])
	var hb: String = hasher.of_state([b])
	t._check(ha == hb, "core.hash: poradi klicu ve slovniku hash nemeni (docs/04 §4.2)")
	t._check(ha.length() == 64, "core.hash: vysledek je SHA-256 (64 hex znaku, namEReno %d)" % ha.length())
	t._check(ha == hasher.of_state([a]), "core.hash: stejny stav da stejny hash i pri druhem volani")
	t._check(ha != hasher.of_state([{"z": 1, "a": 3, "m": {"y": 5, "b": 6}}]),
		"core.hash: jina hodnota = jiny hash")
	t._check(ha != hasher.of_state([{"z": 1, "a": 2, "m": {"y": 5, "b": 7}}]),
		"core.hash: jina vnorena hodnota = jiny hash")
	t._check(hasher.of_state([[1, 2]]) != hasher.of_state([[2, 1]]),
		"core.hash: poradi v poli je soucasti stavu")
	t._check(hasher.of_state([true]) != hasher.of_state([1]),
		"core.hash: bool a int nejsou totez")
	t._check(hasher.of_state([{"a": -1}]) != hasher.of_state([{"a": 1}]),
		"core.hash: znamenko je soucasti stavu")
