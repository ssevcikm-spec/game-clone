extends RefCounted
# Izometricka projekce dlazdice <-> obrazovka (docs/02 §2.4).
#
#   screen.x = (x - y) * ISO_STEP
#   screen.y = (x + y) * ISO_STEP - z * Z_SCALE
#
# Inverze je presna: pro cela x, y a libovolne z plati
#   to_tile(to_screen(x, y, z).x, .y, z) == Vector2i(x, y)
# (proto se zaokrouhluje - u presne inverze jsou hodnoty cele).
#
# Vsechny konstanty se berou z core/const.gd; tady se zadna hodnota neopakuje.

const Const = preload("res://core/const.gd")


func to_screen(x: int, y: int, z: int) -> Vector2:
	return Vector2(
		(x - y) * Const.ISO_STEP,
		(x + y) * Const.ISO_STEP - z * Const.Z_SCALE
	)


func to_tile(sx: float, sy: float, z: int) -> Vector2i:
	var a: float = sx / float(Const.ISO_STEP)                                # = x - y
	var b: float = (sy + float(z * Const.Z_SCALE)) / float(Const.ISO_STEP)   # = x + y
	return Vector2i(int(round((a + b) * 0.5)), int(round((b - a) * 0.5)))


func block_of(x: int, y: int) -> Vector2i:
	# Bloky 8x8 (docs/02 §2.4). Deleni se zaokrouhluje DOLU i pro zaporna cisla,
	# aby se blokovaly spravne i souradnice mimo mapu.
	return Vector2i(_floor_div(x, Const.BLOCK_SIZE), _floor_div(y, Const.BLOCK_SIZE))


func _floor_div(value: int, divisor: int) -> int:
	if value >= 0:
		return value / divisor
	return -((-value + divisor - 1) / divisor)
