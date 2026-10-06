extends RefCounted
# world.map - bloky mapy 8x8 (granule world.map; format docs/03 §3.4).
#
# CO SE MERI (docs/09 §9.4) - chovani, ne "soubor existuje":
#   * `land_at`/`z_at` odpovidaji BAJTUM souboru (nezavisly parser nize),
#   * index bloku je x-major `bx * blocks_y + by` a bunka uvnitr bloku je po
#     radcich `(y % 8) * 8 + (x % 8)`,
#   * `statics_at` vraci cely blok se vsemi PETI poli (`tile,x,y,z,hue`) a `z`
#     NENI lokalni `y` (presne ta vada, ktera se nasla 2026-10-06),
#   * mimo mapu se vraci OFF_MAP a prazdny seznam - ne ticha nula.
#
# MERI SE NA FIXTURE V GITU (tests/fixtures/world/, generator make_fixture.py):
# `assets/uo/` je v .gitignore, takze v CI zadna mapa NENI a test nad realnymi
# daty by tam nemel co merit. Realna data se meri NAVIC, kdyz na disku jsou;
# kdyz nejsou, je to VIDET jako NEMERENO - a schvalne to neni selhani kodu.
#
# Cesty jsou VSTUP (jako u bran): `-- --map-script=<cesta> --map-prefix=<cesta>`,
# aby mutacni test (tools/gates/mutace-tests.py) mohl predat mutanta a aby se
# overilo, ze test meri opravdu ten soubor, ktery dostane.

const Lib = preload("res://tests/lib.gd")

const MAP_SCRIPT := "res://sim/world/map.gd"
const FIXTURE := "res://tests/fixtures/world/map0"
const REAL := "res://assets/uo/world/map0"
const BLOCK := 8
const EMPTY_BLOCK := 0xFFFFFFFF

var _prefix := FIXTURE
var _blocks_y := 3
var _land := PackedByteArray()
var _idx := PackedByteArray()
var _bin := PackedByteArray()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var data := file.get_buffer(file.get_length())
	file.close()
	return data


func _nacti(prefix: String) -> bool:
	# Nacte data testu (ne pres map.gd) - jen to, co je na disku.
	var meta = Lib.json_at(prefix + ".meta.json")
	if not (meta is Dictionary):
		return false
	_prefix = prefix
	_blocks_y = int(meta.get("blocks_y", 0))
	_land = _read_bytes(prefix + ".land")
	_idx = _read_bytes(prefix + ".statics.idx")
	_bin = _read_bytes(prefix + ".statics.bin")
	return _blocks_y > 0 and not _land.is_empty()


func _raw_land(x: int, y: int) -> int:
	# Nezavisly parser .land: 4 B hlavicka na blok, bunka 3 B, uvnitr po radcich.
	var key := (x / BLOCK) * _blocks_y + (y / BLOCK)
	var at := key * (4 + BLOCK * BLOCK * 3) + 4
	at += ((y % BLOCK) * BLOCK + (x % BLOCK)) * 3
	return _land.decode_u16(at)


func _raw_z(x: int, y: int) -> int:
	var key := (x / BLOCK) * _blocks_y + (y / BLOCK)
	var at := key * (4 + BLOCK * BLOCK * 3) + 4
	at += ((y % BLOCK) * BLOCK + (x % BLOCK)) * 3 + 2
	return _land.decode_s8(at)


func _raw_statics(bx: int, by: int) -> Array:
	# Nezavisly parser .statics.idx + .statics.bin (7 B na zaznam).
	var out: Array = []
	var key := bx * _blocks_y + by
	var at := key * 12
	if _idx.size() < at + 12:
		return out
	var offset := _idx.decode_u32(at)
	var length := _idx.decode_u32(at + 4)
	if offset == EMPTY_BLOCK or length == 0:
		return out
	for i in length / 7:
		var p := offset + i * 7
		if _bin.size() < p + 7:
			break
		out.append({"tile": _bin.decode_u16(p), "x": _bin.decode_u8(p + 2),
			"y": _bin.decode_u8(p + 3), "z": _bin.decode_s8(p + 4),
			"hue": _bin.decode_u16(p + 5)})
	return out


func _shoda_statiky(api: Array, raw: Array) -> String:
	# Vrati "" pri shode, jinak pojmenovany rozdil (aby FAIL rovnou rekl, co nesedi).
	if api.size() != raw.size():
		return "poctu zaznamu: API %d vs bajty %d" % [api.size(), raw.size()]
	for i in api.size():
		for field in ["tile", "x", "y", "z", "hue"]:
			if not api[i].has(field):
				return "zaznam %d nema pole '%s'" % [i, field]
			if int(api[i][field]) != int(raw[i][field]):
				return "zaznam %d pole '%s': API %d vs bajty %d" \
					% [i, field, int(api[i][field]), int(raw[i][field])]
	return ""


func run(t) -> void:
	var script = Lib.script_at(_arg("map-script", MAP_SCRIPT))
	if script == null:
		t._pending("world.map NENI HOTOVA: sim/world/map.gd chybi")
		return
	var prefix := _arg("map-prefix", FIXTURE)
	if not _nacti(prefix):
		t._pending("world.map: fixture %s.meta.json chybi - spust "
			% prefix + "python tests/fixtures/world/make_fixture.py")
		return
	_mer_fixture(t, script, prefix)
	_mer_realna(t, script)


func _mer_fixture(t, script, prefix: String) -> void:
	var map = script.new(prefix)
	# rozmery a strop land artu (fixture: 2x3 bloky, land id do 0x3FFF)
	t._check(map.width() == 16 and map.height() == 24,
		"world.map: rozmery z meta 16x24 (namEReno %dx%d)" % [map.width(), map.height()])
	t._check(map.land_tile_max() == 16383 and map.land_tile_max() < 0x4000,
		"world.map: land_tile_max je v prostoru land (namEReno %d)"
		% map.land_tile_max())

	# kazdy blok ma svou vlastni sadu dlazdic: prohozene poradi indexu se pozna
	t._check(map.land_at(0, 0) == 1 and map.land_at(8, 0) == 193
		and map.land_at(0, 8) == 65 and map.land_at(8, 8) == 257
		and map.land_at(0, 16) == 129 and map.land_at(8, 16) == 321,
		"world.map: index bloku je x-major (namEReno %d,%d,%d,%d,%d,%d)"
		% [map.land_at(0, 0), map.land_at(8, 0), map.land_at(0, 8),
			map.land_at(8, 8), map.land_at(0, 16), map.land_at(8, 16)])
	t._check(map.land_at(15, 23) == 384,
		"world.map: posledni bunka sveta (namEReno %d)" % map.land_at(15, 23))

	# bunka uvnitr bloku je po RADcICH: (3,5) a (5,3) musi vyjit jinak
	t._check(map.land_at(3, 5) == 44 and map.land_at(5, 3) == 30,
		"world.map: bunka v bloku je (y %% 8) * 8 + (x %% 8) (namEReno %d a %d)"
		% [map.land_at(3, 5), map.land_at(5, 3)])
	t._check(map.z_at(0, 0) == -12 and map.z_at(3, 5) == 6 and map.z_at(15, 23) == 1,
		"world.map: z_at cte z na offsetu +2 v bunce (namEReno %d, %d, %d)"
		% [map.z_at(0, 0), map.z_at(3, 5), map.z_at(15, 23)])

	# CELE platno proti bajtum: 384 bunek, pocita se jen pocet neshod
	var neshod := 0
	var prvni := ""
	for y in 24:
		for x in 16:
			if map.land_at(x, y) != _raw_land(x, y) or map.z_at(x, y) != _raw_z(x, y):
				neshod += 1
				if prvni == "":
					prvni = "(%d,%d): API %d/%d vs bajty %d/%d" % [x, y,
						map.land_at(x, y), map.z_at(x, y), _raw_land(x, y), _raw_z(x, y)]
	t._check(neshod == 0, "world.map: vsech 384 bunek odpovida bajtum .land "
		+ ("bez neshody" if neshod == 0 else "%d neshod, prvni %s" % [neshod, prvni]))

	# statiky: cely blok, vsech pet poli, `z` NENI lokalni `y`
	var prvni_blok: Array = map.statics_at(0, 0)
	t._check(prvni_blok.size() == 3,
		"world.map: statics_at vraci CELY blok (3 zaznamy, namEReno %d)" % prvni_blok.size())
	if prvni_blok.size() == 3:
		var r: Dictionary = prvni_blok[0]
		t._check(int(r.get("tile", -1)) == 500 and int(r.get("x", -1)) == 1
			and int(r.get("y", -1)) == 7 and int(r.get("z", -99)) == 40
			and int(r.get("hue", -1)) == 100,
			"world.map: zaznam ma tile,x,y,z,hue a z=40 (ne lokalni y=7): %s" % str(r))
	var neshod_s := 0
	var detail := ""
	for by in 3:
		for bx in 2:
			var rozdil := _shoda_statiky(map.statics_at(bx * BLOCK, by * BLOCK),
				_raw_statics(bx, by))
			if rozdil != "":
				neshod_s += 1
				if detail == "":
					detail = "blok %d,%d: %s" % [bx, by, rozdil]
	t._check(neshod_s == 0, "world.map: statiky vsech 6 bloku odpovidaji bajtum "
		+ ("bez neshody" if neshod_s == 0 else "%d neshod, prvni %s" % [neshod_s, detail]))

	# prazdny blok (EMPTY_BLOCK v .idx) a mimo mapu
	t._check(map.statics_at(8, 16).is_empty(),
		"world.map: blok s EMPTY_BLOCK vraci prazdny seznam, ne vymyslene statiky")
	t._check(map.land_at(-1, 0) == -1 and map.land_at(0, -1) == -1
		and map.z_at(0, -1) == -1 and map.statics_at(-1, -1).is_empty(),
		"world.map: mimo mapu vraci -1 a prazdny seznam (namEReno %d/%d/%d)"
		% [map.land_at(-1, 0), map.land_at(0, -1), map.z_at(0, -1)])

	# cache: blok se nacte az kdyz je potreba (is_loaded nesmi lhat)
	var druha = script.new(prefix)
	var pred: bool = druha.is_loaded(1, 1)
	druha.load_block(1, 1)
	t._check(druha.is_loaded(1, 1) and not pred,
		"world.map: load_block nacte blok a is_loaded to rekne (pred %s, po %s)"
		% [str(pred), str(druha.is_loaded(1, 1))])

	# chybejici data se HLASI (prazdna mapa neni uspech)
	var prazdna = script.new("res://tests/fixtures/world/neexistuje")
	t._check(prazdna.width() == 0 and prazdna.land_at(0, 0) == -1,
		"world.map: chybejici meta.json nevyrobi tichou prazdnou mapu (w %d)" % prazdna.width())


func _mer_realna(t, script) -> void:
	# Realna data z instalace UO (docs/03 §3.4). Kdyz na disku nejsou, je to
	# VIDET - a je to NEMERENO, ne selhani: chybi DATA, ne kod.
	if not _nacti(REAL):
		print("[test] NEMERENO: world.map nad realnymi daty - chybi ", REAL,
			".land (assets/uo/ je v .gitignore; spust "
			+ "python tools/uoextract/worldmap.py --extract assets/uo/world)")
		return
	var map = script.new(REAL)
	t._check(map.width() == 7168 and map.height() == 4096,
		"world.map: rozmery realne mapy 7168x4096 (namEReno %dx%d)"
		% [map.width(), map.height()])

	# blok Britainu: statiky API vs bajty souboru
	var bx := 1495 / BLOCK
	var by := 1630 / BLOCK
	var raw := _raw_statics(bx, by)
	var api: Array = map.statics_at(bx * BLOCK, by * BLOCK)
	t._check(not raw.is_empty(),
		"world.map: blok Britainu ma v souboru statiky (namEReno %d)" % raw.size())
	var rozdil := _shoda_statiky(api, raw)
	t._check(rozdil == "", "world.map: statiky Britainu odpovidaji bajtum "
		+ ("bez neshody" if rozdil == "" else rozdil))

	# `z` statiku NENI lokalni `y`: mimo 0..7 jich musi byt vetsina
	var z_out := 0
	for record in raw:
		if int(record["z"]) < 0 or int(record["z"]) >= BLOCK:
			z_out += 1
	t._check(z_out > 0, "world.map: `z` statiku neni lokalni y "
		+ "(mimo 0..7 je %d z %d zaznamu)" % [z_out, raw.size()])

	# land: API vs bajty na nekolika mistech + rozsah land id
	var neshod := 0
	var mimo := 0
	for bod in [[1495, 1630], [1496, 1630], [1495, 1631], [1500, 1640]]:
		if map.land_at(bod[0], bod[1]) != _raw_land(bod[0], bod[1]):
			neshod += 1
	for oy in BLOCK:
		for ox in BLOCK:
			var tile: int = map.land_at(1495 + ox, 1630 + oy)
			if tile < 0 or tile >= 0x4000:
				mimo += 1
	t._check(neshod == 0, "world.map: land_at odpovida bajtum .land (%d neshod)" % neshod)
	t._check(mimo == 0, "world.map: land id bloku Britainu je v 0..0x3FFF "
		+ "(%d mimo z 64)" % mimo)
