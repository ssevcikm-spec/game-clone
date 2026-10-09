extends RefCounted
# NASTENNY CAS KROKU (2026-10-09, vada uzivatele "svet se trepota, postava je plynula").
#
# NAMERENO (`_analyza/p31-jitter.gd`, 600 framu, 1920x1009, zoom 0,82):
# **97,8 % framu se svet nepohnul vubec** a pak skocil o 11 px (9 px na
# obrazovce) - svet se nevalil, ale teleportoval 4x za krok. Pricina: posun se
# pocital z CASU SIMULACE (`sim.world_time()`, tik 50 ms), ne z nastennych hodin.
#
# CO SE MERI (chovani, ne pritomnost):
#   1. behem kroku se posun meni s NASTENNYM casem (ne jen po ticcich sim),
#   2. opakovane `update_step` se STEJNYM krokem nezacne krok znovu (jinak by
#      se posun porad restartoval na nule - presne to delal prvni pokus),
#   3. JINY krok zacne znovu (nasteny cas se prenastavi),
#   4. bez kroku je posun nula a nasteny cas se zahodi.

const Lib = preload("res://tests/lib.gd")
const CONTROLLER_SCRIPT := "res://app/player_controller.gd"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var script = Lib.script_at(_arg("player-controller-script", CONTROLLER_SCRIPT))
	var MobileScript = Lib.script_at(MOBILE_SCRIPT)
	if script == null or MobileScript == null:
		t._pending("player_controller/mobile NENI HOTOV")
		return
	var c = script.new()
	c.player = MobileScript.new(0x40000001, 400, Vector3i(1495, 1630, 0))

	# 1) NASTENNY cas: krok zacal pred 100 ms z 200 ms -> posun je v pulce.
	var krok := {"dir": 0, "run": true, "start_ms": 1000, "delay_ms": 200,
		"due_ms": 1200, "z": 0}
	c.update_step(krok)
	var cely: Vector2 = c.player_pixel_offset(1400)          # sim-cas cesta (test)
	c._wall_start_ms = Time.get_ticks_msec() - 100           # chceme byt v pulce
	var pul: Vector2 = c.player_pixel_offset()               # default = nastenne hodiny
	t._check(absf(pul.x - cely.x * 0.5) <= 1.0 and absf(pul.y - cely.y * 0.5) <= 1.0,
		"player_controller: s nastennym casem je posun v pulce kroku (pul %s, cely %s)"
			% [str(pul), str(cely)])

	# 2) Opakovany STEJNY krok nesmi zacit znovu (jinak se posun restartuje).
	var zacatek: int = c._wall_start_ms
	for i in 5:
		c.update_step(krok)
	t._check(c._wall_start_ms == zacatek,
		"player_controller: opakovany stejny krok nezacne znovu (zacatek %d -> %d)"
			% [zacatek, c._wall_start_ms])

	# 3) JINY krok (jiny `start_ms`) zacne znovu.
	var jiny := {"dir": 1, "run": true, "start_ms": 1400, "delay_ms": 200,
		"due_ms": 1600, "z": 0}
	c.update_step(jiny)
	t._check(c._wall_start_ms != zacatek and c._wall_start_ms >= zacatek,
		"player_controller: novy krok prenastavi nasteny cas (%d -> %d)"
			% [zacatek, c._wall_start_ms])

	# 4) Bez kroku: posun nula a nasteny cas zahozeny.
	c.update_step({})
	t._check(c.player_pixel_offset() == Vector2.ZERO and c._wall_start_ms == -1,
		"player_controller: bez kroku je posun nula a nasteny cas -1 (namEReno %s, %d)"
			% [str(c.player_pixel_offset()), c._wall_start_ms])

	c.free()
