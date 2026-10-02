extends RefCounted
# Pridelovani serialu (docs/04 §4.2, docs/11 §11.7):
#   mobile >= 0x40000000, item < 0x40000000 (0 = "zadna entita").
#
# Determinismus: serial se prideluje volanim, ne casem ani nahodou, takze dva
# stejne behy daji stejna id.
#
# POZOR - otevrena otazka smlouvy: kontrakt zna jen `next()`, tedy jednu radu
# id. Mobily (hráč, NPC) tim dostanou serial az po 2^30 itemech. Hratelne to
# je (id jsou jen identifikatory), ale pro `entity.mobile` to chce rozhodnuti
# v docs/04 (napr. `next_mobile()`); do te doby se mobilni serialy pridělují
# pres `reset()`.

const MOBILE_BASE: int = 0x40000000
const FIRST_SERIAL: int = 1

var _next: int = FIRST_SERIAL


func next() -> int:
	var serial: int = _next
	_next += 1
	return serial


func is_item(s: int) -> bool:
	return s > 0 and s < MOBILE_BASE


func is_mobile(s: int) -> bool:
	return s >= MOBILE_BASE


func reset(next_serial: int) -> void:
	_next = maxi(next_serial, FIRST_SERIAL)
