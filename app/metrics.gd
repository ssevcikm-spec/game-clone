extends RefCounted
# app.metrics (M9, 15. session) - CISLA MISTO DOJMU.
#
# PROC: "hra se seka" je dojem, ktery se neda porovnat pred/po. Tenhle modul
# sbira to, co uz hra zna (`app.world_view.drawn`, `render.textures.stats()`,
# `render.chunk_mesh.stats()`) a k tomu meri frame cas; `report()` z toho udela
# jeden slovnik, ktery se da vypsat nebo predat dal.
#
# SMLOUVA (docs/04 §4.2, granule `app.metrics`):
#   `fps()`            - FPS z MERENEHO frame casu (ne z `Performance`),
#   `frame_ms()`       - prumer frame casu za posledni okno (ms),
#   `drawn_objects()`  - kolik objektu se naposledy kreslilo,
#   `report()`         - vsechno vyse + textury + davka + pocet framu.
# Navic: `tick(frame_ms, drawn, textury, davka)`, `window()`, `set_window(n)`,
# `reset()` a `text()` (jednoradkovy lidsky vystup pro log).
#
# ⚠ CO MODUL NEDELA: nemeri pres `Performance` (to je cislo enginu, ne nase)
# a NEDRZI historii framu - prumer je klouzavy pres poslednich `WINDOW` framu.
# Kdo chce rozptyl, at si ho spocte z `report()["vzorku"]` (pocet vzorku v okne).
#
# Pouziti v produkci (`app.main`): kazdy frame `tick(...)`, jednou za sekundu
# `report()` do logu (viz `app/main.gd`).

const WINDOW: int = 120              # kolik framu drzi klouzavy prumer (~1-2 s)

var _okno: int = WINDOW
var _casy: PackedFloat32Array = PackedFloat32Array()
var _drawn: int = 0
var _textury: Dictionary = {}
var _davka: Dictionary = {}
var _framu: int = 0


func set_window(n: int) -> void:
	_okno = maxi(1, n)
	while _casy.size() > _okno:
		_casy.remove_at(0)


func window() -> int:
	return _okno


func reset() -> void:
	_casy = PackedFloat32Array()
	_drawn = 0
	_textury = {}
	_davka = {}
	_framu = 0


func tick(frame_ms: float, drawn: int, textury: Dictionary = {}, davka: Dictionary = {}) -> void:
	# Jeden frame: cas, pocet kreslenych objektu a snapshoty cache/davky.
	_casy.append(maxf(0.0, frame_ms))
	while _casy.size() > _okno:
		_casy.remove_at(0)
	_drawn = drawn
	_textury = textury.duplicate()
	_davka = davka.duplicate()
	_framu += 1


func frame_ms() -> float:
	if _casy.is_empty():
		return 0.0                      # NEMERENO, ne "nula ms" - a je to videt
	var soucet: float = 0.0
	for cas in _casy:
		soucet += cas
	return soucet / float(_casy.size())


func fps() -> float:
	# FPS z MERENEHO casu: 1000 / prumer. Kdyz neni co merit, vraci 0.
	var ms: float = frame_ms()
	return 0.0 if ms <= 0.0 else 1000.0 / ms


func drawn_objects() -> int:
	return _drawn


func samples() -> int:
	return _casy.size()


func report() -> Dictionary:
	var ms: float = frame_ms()
	return {"fps": fps(), "frame_ms": ms, "drawn": _drawn, "framu": _framu,
		"vzorku": _casy.size(), "okno": _okno,
		"textury": _textury.duplicate(), "davka": _davka.duplicate()}


func text() -> String:
	# Jednoradkovy vystup pro log (hodnoty pro cloveka, klice anglicky).
	var r: Dictionary = report()
	var t: Dictionary = r["textury"]
	var d: Dictionary = r["davka"]
	return "fps %.1f | frame %.2f ms | kresleno %d | textur %s (%.0f MB) | kvadru %s | stavba %s ms" % [
		float(r["fps"]), float(r["frame_ms"]), int(r["drawn"]),
		str(t.get("loaded", "?")), float(t.get("bytes", 0)) / 1048576.0,
		str(d.get("kvadru", "?")), str(d.get("stavba_ms", "?"))]
