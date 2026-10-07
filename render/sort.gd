extends RefCounted
# Jedina funkce razeni kresleni (granule render.sort; docs/02 §2.4, past P21).
#
# RAZENI: po dlazdicich ve smeru rustouciho `x + y`; v ramci jedne dlazdice
# land -> statiky podle `z` vzestupne -> mobilove podle `z` vzestupne. Stejne
# poradi ma i UO: ClassicUO depth = (x + y) + (127 + z) * 0.01 (research/05
# §8.2, View.cs) - hlavni klic je `x + y`, `z` az v ramci te diagonaly.
#
# TVAR OBJEKTU - SMLOUVA TO NEPINUJE (nalezeno pri implementaci, patri do
# docs/04 §4.2 k radku `render.sort`):
#   {"kind": "land"|"static"|"mobile"|"item", "x": int, "y": int, "z": int}
# "item" = predmet na zemi (v UO jde s mobilovymi v jednom seznamu); neznamy
# `kind` se kresli jako mobilni a vyvolava jedno varovani, ne ticho.

const Const = preload("res://core/const.gd")

const LAYER_LAND: int = 0
const LAYER_STATIC: int = 1
const LAYER_MOBILE: int = 2
const LAYERS: int = 3
const Z_SPAN: int = Const.Z_MAX - Const.Z_MIN + 1
const KIND_LAYER := {"land": LAYER_LAND, "static": LAYER_STATIC,
	"mobile": LAYER_MOBILE, "item": LAYER_MOBILE}

var _warned: bool = false


func sort_key(obj: Dictionary) -> int:
	# Jedno cislo NA POROVNAVANi - ne pro `z_index`: klic neni male cislo a Godot
	# bere z_index jen -4096..4096. `z` jde do Z_MIN..Z_MAX, protoze mimo rozsahu
	# by objekt posunul o par celych diagonaly. Klic 0 = (0, 0) ve vrstve land.
	var kind := str(obj.get("kind", ""))
	var layer: int = int(KIND_LAYER[kind]) if KIND_LAYER.has(kind) else LAYER_MOBILE
	var diagonal: int = int(obj.get("x", 0)) + int(obj.get("y", 0))
	var z: int = clampi(int(obj.get("z", 0)), Const.Z_MIN, Const.Z_MAX)
	return (diagonal * LAYERS + layer) * Z_SPAN + (z - Const.Z_MIN)


func draw_order(objects: Array) -> Array:
	# Deterministicke a STABILNI (docs/02 §2.3): `sort()` stabilni neni, proto
	# poradi vstupu vleze do klicu. Stejne klic = poradi vstupu; tak to dela i UO.
	#
	# ⚠ VYKON (namEReno 2026-10-07, sonda `_analyza/vlna5-cena.gd`): puvodni
	# verze stavela `[klic, i, objekt]` a radila `sort_custom(_lower)` - porovnani
	# je GDScript a pri 6 095 objektech to je ~76 000 volani, dohromady
	# **85,7 ms** na prestavbu seznamu. A seznam se prestavuje pri KAZDEM kroku
	# chuze (`look_at_tile` -> `invalidate`) - uzivatel to vidi jako seknuti.
	# Dnes se klic a poradi vstupu sliji do JEDNOHO int64 a radi se built-in
	# `sort()` (C++): stejne poradi, zlomek casu.
	var n: int = objects.size()
	var shift: int = 1
	while (1 << shift) < n:
		shift += 1
	var mask: int = (1 << shift) - 1
	var klice := PackedInt64Array()
	klice.resize(n)
	var neznamych: int = 0
	for i in n:
		var obj: Dictionary = objects[i]
		neznamych += 0 if KIND_LAYER.has(str(obj.get("kind", ""))) else 1
		klice[i] = (sort_key(obj) << shift) | i
	if neznamych > 0 and not _warned:
		_warned = true
		push_warning("render.sort: %d objektu neznamy `kind` - kresli se jako mobilni" % neznamych)
	klice.sort()
	var out: Array = []
	out.resize(n)
	for i in n:
		out[i] = objects[int(klice[i] & mask)]
	return out
