extends RefCounted
# app.metrics - mereni vykonu (docs/04 §4.2; soubor app/metrics.gd).
#
# CO SE MERI (docs/09 §9.4):
#   * prazdny modul NEMERI: `frame_ms()`/`fps()` jsou 0 a `report()["vzorku"]`
#     je 0 - "nula a prazdno nejsou uspech" (docs/08 §8.6) a musi to byt videt,
#   * `tick()` meni klouzavy prumer: 10/20/30 ms -> 20 ms a 50 FPS (pocita se
#     z MERENEHO casu, ne z `Performance`),
#   * okno se da zmensit (`set_window`) a pak se pocita jen z poslednich vzorku,
#   * `drawn_objects()` vraci pocet z POSLEDNIHO ticku (ne z prumeru),
#   * `report()` nese vsechno vcetne textur a stavby davky,
#   * `reset()` vymaze vzorky (dalsi mereni zacina od nuly).
#
# Cesta k merenemu souboru je VSTUP (`-- --metrics-script=<cesta>`), aby
# mutacni test mohl predat mutanta.

const Lib = preload("res://tests/lib.gd")

const METRICS_SCRIPT := "res://app/metrics.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("metrics-script", METRICS_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("app.metrics NENI HOTOV: " + cesta + " chybi nebo nejde nacist")
		return
	var m = script.new()

	# 1) PRAZDNY MODUL MERI NULU A JE TO VIDET
	var prazdny: Dictionary = m.report()
	t._check(m.frame_ms() == 0.0 and m.fps() == 0.0 and int(prazdny["vzorku"]) == 0,
		"app.metrics: pred merenim je frame_ms 0, fps 0 a vzorku 0 (namEReno %s/%s/%s)"
			% [str(m.frame_ms()), str(m.fps()), str(prazdny["vzorku"])])

	# 2) KLOUZAVY PRUMER Z MERENEHO CASU
	m.tick(10.0, 5, {"loaded": 2}, {"kvadru": 7})
	m.tick(20.0, 6, {"loaded": 3}, {"kvadru": 8})
	m.tick(30.0, 7, {"loaded": 4}, {"kvadru": 9})
	t._check(is_equal_approx(m.frame_ms(), 20.0) and is_equal_approx(m.fps(), 50.0),
		"app.metrics: prumer 10/20/30 ms = 20 ms a 50 FPS (namEReno %.3f / %.3f)"
			% [m.frame_ms(), m.fps()])
	t._check(m.drawn_objects() == 7 and m.samples() == 3,
		"app.metrics: drawn_objects() je z posledniho ticku (namEReno %d, vzorku %d)"
			% [m.drawn_objects(), m.samples()])
	var r: Dictionary = m.report()
	t._check(int(r["framu"]) == 3 and int(r["vzorku"]) == 3
		and int(r["textury"]["loaded"]) == 4 and int(r["davka"]["kvadru"]) == 9,
		"app.metrics: report() nese framy, vzorky, textury i stavbu davky (namEReno %s)"
			% str(r))

	# 3) OKNO: zmenseni okna zahodi starsi vzorky a zmeni prumer
	m.set_window(2)
	t._check(m.samples() <= 2 and is_equal_approx(m.frame_ms(), 25.0),
		"app.metrics: okno 2 -> prumer poslednich dvou (25 ms; namEReno %.3f, vzorku %d)"
			% [m.frame_ms(), m.samples()])
	m.set_window(1)
	m.tick(4.0, 1)
	t._check(m.samples() == 1 and is_equal_approx(m.frame_ms(), 4.0) and is_equal_approx(m.fps(), 250.0),
		"app.metrics: okno 1 -> meri se posledni frame (namEReno %.3f ms, %.1f FPS)"
			% [m.frame_ms(), m.fps()])

	# 4) TEXT PRO LOG: nesmi spadnout a musi nest hodnoty
	var text: String = m.text()
	t._check(text.contains("fps") and text.contains("kresleno"),
		"app.metrics: text() je jednoradkovy vystup pro log (namEReno '%s')" % text)

	# 5) RESET
	m.reset()
	t._check(m.samples() == 0 and m.frame_ms() == 0.0 and m.drawn_objects() == 0,
		"app.metrics: reset() vymaze vzorky i pocty")
