extends RefCounted
# world.walk - pruchodnost a vysky (docs/04 §4.2, algoritmus docs/05 §5.1.2).
#
# Test meri ALGORITMUS na FAKE mape a FAKE tiledata: `assets/uo/` je v gitignore,
# takze v CI zadna realna tiledata nejsou a test nad nimi by tam nemel co merit.
# Realna data se meri NAVIC, kdyz na disku jsou - a kdyz ne, rekne se to nahlas.

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")

const OFF := -1
const TRAVA := 3            # land, pruchodna
const VODA := 4             # land, Wet
const ZED := 0x4001         # statik, Impassable
const PLOSINA := 0x4002     # statik, Surface + height 4
const DECOR := 0x4003       # statik, Wall (pruchodnost NEovlivnuje)


class FakeTiledata:
	var f := {}
	var h := {}

	func flags(tile: int) -> int:
		return int(f.get(tile, 0))

	func height(tile: int) -> int:
		return int(h.get(tile, 0))


class FakeMap:
	var land := {}
	var zs := {}
	var statics := {}

	func land_at(x: int, y: int) -> int:
		return int(land.get(Vector2i(x, y), OFF))

	func z_at(x: int, y: int) -> int:
		return int(zs.get(Vector2i(x, y), 0))

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x, y), [])


func _fake() -> Array:
	var td = FakeTiledata.new()
	td.f[TRAVA] = 0
	td.f[VODA] = 0x80            # Wet
	td.f[ZED] = 0x40             # Impassable
	td.f[PLOSINA] = 0x200        # Surface
	td.h[PLOSINA] = 4
	td.f[DECOR] = 0x10           # Wall - pohyb neovlivnuje (docs/05 §5.1.2 bod 3)
	td.h[DECOR] = 20

	var map = FakeMap.new()
	for y in 8:
		for x in 8:
			map.land[Vector2i(x, y)] = TRAVA
			map.zs[Vector2i(x, y)] = 0
	return [map, td]


func run(t) -> void:
	var script = Lib.script_at("res://sim/world/walk.gd")
	if script == null:
		t._pending("world.walk NENI HOTOVA: sim/world/walk.gd chybi")
		return
	var pair := _fake()
	var map = pair[0]
	var td = pair[1]
	var walk = script.new(map, td, null)

	# 1) volna dlazdice: jde se, z se bere z mapy
	var free: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(free["ok"] == true and int(free["z"]) == 0 and str(free["reason"]) == "",
		"world.walk: volna trava na vychod (dir 0) vraci ok (namEReno %s)" % str(free))
	map.zs[Vector2i(6, 5)] = 3
	var vyska: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(vyska["ok"] == false and str(vyska["reason"]) == "height",
		"world.walk: krok nahoru o 3 (> STEP_HEIGHT 2) vraci reason 'height' (namEReno %s)" % str(vyska))
	map.zs[Vector2i(6, 5)] = 2
	var step2: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(step2["ok"] == true and int(step2["z"]) == 2,
		"world.walk: krok nahoru o 2 (STEP_HEIGHT) jeste jde (namEReno %s)" % str(step2))
	map.zs[Vector2i(6, 5)] = 0

	# 2) voda (Wet) a zed (Impassable) blokuji - presne podle smlouvy
	map.land[Vector2i(6, 5)] = VODA
	var voda: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(voda["ok"] == false and str(voda["reason"]) == "blocked",
		"world.walk: voda vraci reason 'blocked' (namEReno %s)" % str(voda))
	map.land[Vector2i(6, 5)] = TRAVA
	map.statics[Vector2i(6, 5)] = [{"tile": ZED, "x": 6, "y": 5, "z": 0, "hue": 0}]
	var zed: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(zed["ok"] == false and str(zed["reason"]) == "blocked",
		"world.walk: statik s Impassable vraci 'blocked' (namEReno %s)" % str(zed))
	map.statics.erase(Vector2i(6, 5))

	# 3) statik s `Surface` ZVEDNE povrch; `Wall` (dekor) ho nezvysuje
	map.statics[Vector2i(6, 5)] = [{"tile": PLOSINA, "x": 6, "y": 5, "z": 10, "hue": 0}]
	t._check(walk.surface_z(6, 5) == 14,
		"world.walk: surface_z = z 10 + height 4 = 14 (namEReno %d)" % walk.surface_z(6, 5))
	map.statics[Vector2i(6, 5)] = [{"tile": DECOR, "x": 6, "y": 5, "z": 10, "hue": 0}]
	t._check(walk.surface_z(6, 5) == 0,
		"world.walk: statik bez `Surface` povrch nezveda (namEReno %d)" % walk.surface_z(6, 5))
	map.statics.erase(Vector2i(6, 5))

	# 4) statik z JINE dlazdice v tomtez bloku se nesmi pocitat
	#    (`world.map.statics_at` vraci cely blok - vada ZADANI 15)
	map.statics[Vector2i(6, 5)] = [{"tile": PLOSINA, "x": 7, "y": 5, "z": 10, "hue": 0}]
	t._check(walk.surface_z(6, 5) == 0,
		"world.walk: statik s lokalnim x=7 nepatri dlazdici 6 (namEReno %d)" % walk.surface_z(6, 5))
	map.statics.erase(Vector2i(6, 5))

	# 5) mimo mapu a neplatny smer
	map.land.erase(Vector2i(6, 5))
	var off: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(off["ok"] == false and str(off["reason"]) == "off_map",
		"world.walk: dlazdice mimo mapu vraci 'off_map' (namEReno %s)" % str(off))
	map.land[Vector2i(6, 5)] = TRAVA
	var bad: Dictionary = walk.can_step(Vector3i(5, 5, 0), 8, Const.PERSON_HEIGHT, true)
	t._check(bad["ok"] == false and str(bad["reason"]) == "bad_dir",
		"world.walk: smer 8 vraci 'bad_dir' (namEReno %s)" % str(bad))

	# 6) ASYMETRICKA DIAGONALA - jadro smlouvy (docs/04 §4.6.1)
	#    hrac potrebuje pruchodne OBE ortogonalni dlazdice, NPC jen jednu.
	map.statics[Vector2i(6, 5)] = [{"tile": ZED, "x": 6, "y": 5, "z": 0, "hue": 0}]
	var hrac: Dictionary = walk.can_step(Vector3i(5, 5, 0), 1, Const.PERSON_HEIGHT, true)
	t._check(hrac["ok"] == false and str(hrac["reason"]) == "diagonal",
		"world.walk: hrac u rohu nesmi diagonalizovat (namEReno %s)" % str(hrac))
	var npc: Dictionary = walk.can_step(Vector3i(5, 5, 0), 1, Const.PERSON_HEIGHT, false)
	t._check(npc["ok"] == true,
		"world.walk: NPC muze diagonalizovat i u rohu (namEReno %s)" % str(npc))
	map.statics.erase(Vector2i(6, 5))

	# 7) prazdna zavislost nesmi spadnout (mapa bez dat vraci off_map, ne pád)
	var prazdny = script.new(null, null, null)
	var r: Dictionary = prazdny.can_step(Vector3i(0, 0, 0), 0, Const.PERSON_HEIGHT, false)
	t._check(r.has("ok") and r.has("z") and r.has("reason"),
		"world.walk: bez realnych dat vraci tvar {ok, z, reason} (namEReno %s)" % str(r))

	# 7b) FIXTURE mapy z gitu (funguje i v CI): `surface_z` musi byt to, co rika
	#     mapa - kdyz na dlazdici neni statik, walk si zadne z nevymysli.
	if FileAccess.file_exists("res://tests/fixtures/world/map0.meta.json"):
		var MapScript = load("res://sim/world/map.gd")
		var fix = MapScript.new("res://tests/fixtures/world/map0")
		var z_mapy: int = fix.z_at(0, 0)
		var z_walku: int = script.new(fix, td, null).surface_z(0, 0)
		t._check(z_walku == z_mapy,
			"world.walk: bez statiku je surface_z tolik co z mapy (%d vs %d)" % [z_walku, z_mapy])
		var fix_walk = script.new(fix, td, null)
		var krok: Dictionary = fix_walk.can_step(Vector3i(0, 0, z_mapy), 0, Const.PERSON_HEIGHT, false)
		t._check(krok["ok"] == true and int(krok["z"]) == fix.z_at(1, 0),
			"world.walk: na fixture se da jit na vychod a z je z mapy (namEReno %s, mapa %d)"
				% [str(krok), fix.z_at(1, 0)])
	else:
		print("[test]      NEMERENO: world.walk nad fixture - chybi tests/fixtures/world/map0.meta.json")

	# 8) REALNA DATA se meri navic, jen kdyz na disku jsou (jinak nahlas NEMERENO)
	if not FileAccess.file_exists("res://assets/uo/tiles.json"):
		print("[test]      NEMERENO: world.walk nad realnou tiledata - chybi assets/uo/tiles.json")
		return
	var real = script.new()
	t._check(real.surface_z(1495, 1630) >= Const.Z_MIN and real.surface_z(1495, 1630) <= Const.Z_MAX,
		"world.walk: realny surface_z v Britanii je v rozsahu z (%d)" % real.surface_z(1495, 1630))
	var pocet_ok := 0
	for dir in 8:
		var vysledek: Dictionary = real.can_step(Vector3i(1495, 1630, real.surface_z(1495, 1630)), dir,
			Const.PERSON_HEIGHT, true)
		if vysledek["ok"]:
			pocet_ok += 1
	t._check(pocet_ok > 0,
		"world.walk: z britskeho namesti se da jit aspon jednim smerem (namEReno %d z 8)" % pocet_ok)
