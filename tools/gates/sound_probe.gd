extends SceneTree
# sound_probe.gd - DUKAZ C1 (ZADANI-27 §4): udalost -> zvuk se OPRAVDU prehraje.
#
# Proc takhle: `tests/cases/sound.gd` meri ROZHODNUTI modulu (ktera udalost da
# ktery zvuk) bez stromu a bez zvukove karty. "Zvuk se prehral" se ale takto
# merit NEDÁ - `AudioStreamPlayer` mimo bezici scenu neprehraje a modul to
# poctive vraci jako `false`. Tenhle ridic proto spusti REALNOU scenu
# (`app/main.tscn`), necha hrace utocit (klavesa `A`, stejna cesta jako hrac)
# a na konci vypise `stats()` zvukoveho modulu.
#
# Hotovo je, kdyz `prehrano > 0` (ne "soubor existuje" a ne "modul vraci true").
#
# Spousteni:
#   godot --path . --rendering-driver opengl3 --fixed-fps 60 \
#         --write-movie .cache/render/zvuk/frame.png \
#         --script res://tools/gates/sound_probe.gd
#   (bez `--write-movie` staci `--headless`; zvuk pak hraje dummy driver)

const PLAN := [
	# (frame, keycode, stisk) - `A` = utok na nejblizsi monstrum (docs: napoveda)
	[10, KEY_A, true], [11, KEY_A, false],
	[60, KEY_A, true], [61, KEY_A, false],
	[120, KEY_A, true], [121, KEY_A, false],
	[200, KEY_A, true], [201, KEY_A, false],
	[300, KEY_A, true], [301, KEY_A, false],
]

var _f: int = 0
var _scene = null
var _vypis: Array = []


func _initialize() -> void:
	_scene = load("res://app/main.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_f += 1
	if _scene == null or _scene.loop == null:
		return _f > 420
	for krok in PLAN:
		if int(krok[0]) == _f:
			var event := InputEventKey.new()
			event.keycode = int(krok[1])
			event.pressed = bool(krok[2])
			Input.parse_input_event(event)
	# kazdych 60 framu vypis, jak si zvuk stoji (je videt i to, ze nic nehraje)
	if _f % 60 == 0:
		var zvuk = _scene.loop.sound
		if zvuk == null:
			print("[zvuk] frame ", _f, ": modul NENI zapojeny (loop.sound == null)")
		else:
			var st: Dictionary = zvuk.stats()
			print("[zvuk] frame ", _f, ": ", st, " chyby ", zvuk.errors())
			_vypis.append(st)
	if _f >= 420:
		var zvuk2 = _scene.loop.sound
		if zvuk2 == null:
			print("[zvuk] SOUHRN: modul neni zapojeny - NEMERENO")
			return true
		var st2: Dictionary = zvuk2.stats()
		var ok: bool = int(st2.get("prehrano", 0)) > 0
		print("[zvuk] SOUHRN: prehrano ", st2.get("prehrano"), ", ticho ", st2.get("ticho"),
			", chyb ", st2.get("chyb"), " -> ", "OK" if ok else "VADA (nic se neprehralo)")
		return true
	return false
