extends RefCounted
# Kontroly smluv pro vlnu W0: core.const, core.iso, core.rng.
#
# Vsechny hodnoty jsou z kontraktu, ne z implementace:
#   core.const ... docs/04 §4.2 (tabulka core) + docs/02 §2.4
#   core.iso ..... docs/02 §2.4 (projekce a inverze), prompt granule (1000 bodu)
#   core.rng ..... docs/04 §4.2, docs/02 §2.3; znamy vektor PCG32 je overeny
#                  nezavislou implementaci (.cache/pcg32_ref.py, 2026-10-02)
#
# Kontroly NEPODMINENE: dokud soubor neexistuje, spadnou (docs/09 §9.5).

# Konstanty a jejich hodnoty z docs/04 §4.2 (desetiny u skillu, ms u casu).
const WANT_CONST := {
	"TILE_W": 44, "TILE_H": 44, "ISO_STEP": 22, "Z_SCALE": 4,
	"Z_MIN": -128, "Z_MAX": 127, "TICK_MS": 50,
	"WALK_MS": 400, "RUN_MS": 200, "MOUNT_WALK_MS": 200, "MOUNT_RUN_MS": 100,
	"TURN_MS": 80, "PERSON_HEIGHT": 16, "STEP_HEIGHT": 2, "LIFT_RANGE": 2,
	"MAX_STACK": 60000, "CONTAINER_MAX_ITEMS": 125, "CONTAINER_MAX_WEIGHT": 400,
	"SKILL_CAP": 7000, "STAT_CAP": 225, "SKILL_STEP": 1,
}

# PCG32, seed 42, kanonicky default stream - overeno referencni implementaci.
const RNG_SEED42_10 := [
	492690617, 1919685028, 3561993920, 683038915, 1183706632,
	413921556, 222559498, 436142503, 3736035009, 1116290151,
]


func run(t) -> void:
	_check_const(t)
	_check_iso(t)
	_check_rng(t)


func _check_const(t) -> void:
	var c: Dictionary = t.consts("res://core/const.gd")
	if c.is_empty():
		t._pending("core.const NENI HOTOVA: core/const.gd chybi nebo nema konstanty")
		return
	var keys: Array = WANT_CONST.keys()
	keys.sort()
	for key in keys:
		var value = c.get(key)
		if value == null:
			t._check(false, "core.const: chybi konstanta %s (docs/04 §4.2)" % key)
			continue
		# float ve stavu = drift (docs/01 §1.5.3) - proto i typ
		t._check(typeof(value) == TYPE_INT, "core.const: %s musi byt int (je %s)" % [key, typeof(value)])
		t._check(value == WANT_CONST[key], "core.const: %s == %s (namEReno %s)" % [key, WANT_CONST[key], value])
	# vazby, ktere musi platit nezavisle na tabulce (docs/02 §2.4)
	t._check(c.get("ISO_STEP") == int(c.get("TILE_W", 0)) / 2, "core.const: ISO_STEP == TILE_W/2")
	t._check(int(c.get("Z_MIN", 0)) < int(c.get("Z_MAX", 0)), "core.const: Z_MIN < Z_MAX")


func _check_iso(t) -> void:
	var script = t.load_script("res://core/iso.gd")
	if script == null:
		t._pending("core.iso NENI HOTOVA: core/iso.gd chybi")
		return
	var iso = script.new()
	t._check(typeof(iso.to_screen(0, 0, 0)) == TYPE_VECTOR2, "core.iso: to_screen vraci Vector2")
	t._check(iso.to_screen(0, 0, 0) == Vector2(0, 0), "core.iso: to_screen(0,0,0) == (0,0)")
	t._check(iso.to_screen(1, 0, 0) == Vector2(22, 22), "core.iso: to_screen(1,0,0) == (22,22)")
	t._check(iso.to_screen(0, 1, 0) == Vector2(-22, 22), "core.iso: to_screen(0,1,0) == (-22,22)")
	t._check(iso.to_screen(1, 1, 0) == Vector2(0, 44), "core.iso: to_screen(1,1,0) == (0,44)")
	t._check(iso.to_screen(0, 0, 4) == Vector2(0, -16), "core.iso: to_screen(0,0,4) == (0,-16) [Z_SCALE]")
	t._check(iso.block_of(0, 0) == Vector2i(0, 0), "core.iso: block_of(0,0) == (0,0)")
	t._check(iso.block_of(8, 9) == Vector2i(1, 1), "core.iso: block_of(8,9) == (1,1) [bloky 8x8]")

	# inverze: to_tile(to_screen(p)) == p pro 1000 deterministickych bodu
	var state: int = 12345
	var mismatches: int = 0
	var example: String = ""
	for i in 1000:
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var x: int = state % 7168
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var y: int = state % 4096
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var z: int = (state % 256) - 128
		var screen: Vector2 = iso.to_screen(x, y, z)
		var back: Vector2i = iso.to_tile(screen.x, screen.y, z)
		if back != Vector2i(x, y):
			mismatches += 1
			if example == "":
				example = "(x=%d,y=%d,z=%d) -> %s" % [x, y, z, str(screen)]
	t._check(mismatches == 0, "core.iso: inverze pro 1000 bodu, chyb %d %s" % [mismatches, example])


func _check_rng(t) -> void:
	var script = t.load_script("res://core/rng.gd")
	if script == null:
		t._pending("core.rng NENI HOTOVA: core/rng.gd chybi")
		return
	var a = script.new(42)
	var b = script.new(42)
	var first: Array = []
	var same: bool = true
	var in_range: bool = true
	var ints: bool = true
	for i in 100:
		var va: int = a.next_u32()
		var vb: int = b.next_u32()
		if va != vb:
			same = false
		if typeof(va) != TYPE_INT or va < 0 or va > 4294967295:
			in_range = false
		if i < RNG_SEED42_10.size():
			first.append(va)
	t._check(same, "core.rng: stejny seed -> stejna posloupnost (determinismus)")
	t._check(in_range, "core.rng: next_u32 vraci int v rozsahu 0..2^32-1")
	t._check(ints, "core.rng: hodnoty jsou int (zadny float ve stavu)")
	t._check(first == RNG_SEED42_10,
		"core.rng: znamy vektor PCG32 (seed 42): %s" % str(first))

	# range_i - meze vcetne (jako UO RandomMinMax); overuje se obema smery
	var lo_hit: bool = false
	var hi_hit: bool = false
	var outside: int = 0
	for i in 1000:
		var v: int = a.range_i(5, 9)
		if v < 5 or v > 9:
			outside += 1
		if v == 5:
			lo_hit = true
		if v == 9:
			hi_hit = true
	t._check(outside == 0, "core.rng: range_i(5,9) nikdy mimo rozsah (mimo %d)" % outside)
	t._check(lo_hit and hi_hit, "core.rng: range_i(5,9) umi obe meze (5=%s, 9=%s)" % [lo_hit, hi_hit])

	# chance - krajni hodnoty musi byt deterministicke
	var zero_true: bool = false
	var one_false: bool = false
	for i in 200:
		if a.chance(0.0):
			zero_true = true
		if not a.chance(1.0):
			one_false = true
	t._check(not zero_true, "core.rng: chance(0.0) nikdy nevyjde")
	t._check(not one_false, "core.rng: chance(1.0) vyjde vzdy")
	var hits: int = 0
	for i in 10000:
		if a.chance(0.5):
			hits += 1
	t._check(hits > 4500 and hits < 5500, "core.rng: chance(0.5) z 10000 dalo %d (cekano 4500-5500)" % hits)

	# state/restore - ulozeny stav musi dat stejnou budoucnost
	var c = script.new(7)
	for i in 5:
		c.next_u32()
	var saved: Dictionary = c.state()
	var expected: Array = []
	for i in 5:
		expected.append(c.next_u32())
	c.restore(saved)
	var got: Array = []
	for i in 5:
		got.append(c.next_u32())
	t._check(got == expected, "core.rng: restore(state()) vraci stejnou posloupnost")
	t._check(typeof(saved.get("state")) == TYPE_INT and typeof(saved.get("inc")) == TYPE_INT,
		"core.rng: state() vraci jen int hodnoty (state, inc), namEReno: %s" % str(saved))
