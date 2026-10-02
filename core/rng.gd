extends RefCounted
# Deterministicky generator nahody: PCG32 (PCG-XSH-RR 64/32), docs/02 §2.3.
#
# Stav je uložitelny (`state()` / `restore()`) a cely zije v simulaci - proto
# se v sim/ NESMI pouzivat `randf()` ani `randi()` (docs/09 §9.10.4).
#
# Algoritmus (kanonicky PCG32):
#   state = state * MULT + inc            (mod 2^64, int64 v GDScriptu)
#   xorshifted = ((state >> 18) ^ state) >> 27
#   rot = state >> 59
#   out = rotr32(xorshifted, rot)
#
# Pozn. k posunu: GDScript `>>` je ARITMETICKY (siri znamenko), PCG chce logicky.
# Maskovat az vysledek NESTACI - znamenkovy bit se pri posunu >> 27 posune do
# bitu 19, tedy dovnitr povinneho rozsahu (namEReno 2026-10-02: 5 z 10 hodnot
# znameho vektoru vyslo spatne, stavova posloupnost byla pritom spravna).
# Proto ma kazdy logicky posun vlastni helper `_shr`, ktery znamenkove bity
# vstupu vymaskuje. Spravnost overuje znamy vektor v tests/cases/core.gd.
#
# Seedovani je kanonicke `pcg32_srandom_r`: inc = (stream << 1) | 1, pak dva
# kroky s prictenim seedu mezi nimi. Stream je defaultni (jen jeden proud).

const MULT: int = 6364136223846793005
const DEFAULT_STREAM: int = 1442695040888963407
const MASK32: int = 0xFFFFFFFF
const U32_RANGE: float = 4294967296.0

var _state: int = 0
var _inc: int = 0


func _init(seed: int = 0) -> void:
	_inc = (DEFAULT_STREAM << 1) | 1
	_state = 0
	next_u32()
	_state = _state + seed
	next_u32()


func next_u32() -> int:
	var old: int = _state
	_state = old * MULT + _inc
	var xorshifted: int = _shr(_shr(old, 18) ^ old, 27) & MASK32
	var rot: int = _shr(old, 59) & 31
	return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & 31))) & MASK32


func _shr(value: int, bits: int) -> int:
	# Logicky posun vpravo na 64bitovem vzoru ulozenem v int64.
	if bits <= 0:
		return value
	if value >= 0:
		return value >> bits
	return (value >> bits) & ((1 << (64 - bits)) - 1)


func range_i(a: int, b: int) -> int:
	# Meze VCETNE (jako UO RandomMinMax). Modulo zaveda zanedbatelne zkresleni
	# pro male rozsahy; UO pouzivalo stejny princip.
	var lo: int = a
	var hi: int = b
	if hi < lo:
		lo = b
		hi = a
	var span: int = hi - lo + 1
	if span <= 1:
		return lo
	return lo + int(next_u32() % span)


func chance(p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	return next_u32() < int(p * U32_RANGE)


func state() -> Dictionary:
	return {"state": _state, "inc": _inc}


func restore(d: Dictionary) -> void:
	_state = int(d.get("state", 0))
	_inc = int(d.get("inc", DEFAULT_STREAM << 1 | 1)) | 1
