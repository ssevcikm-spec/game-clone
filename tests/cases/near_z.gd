extends RefCounted
# `render.chunk.near_z` + strop patra (2026-10-09, faze 1 bod 5.3).
#
# ZADANI UZIVATELE (doslova): "Na prvnim obrazku je videt, ze se zobrazuje i
# kousek zdi z vyssi urovne (podkroví) - to je pravda, ale ne stale. Krok nebo
# dva stranou se to uz nezobrazuje."
#
# PRAVIDLO Z REFERENCE (precteno z kodu, ne z pameti):
#   * `UpdateMaxDrawZ()` (`_src/classicuo/.../GameSceneDrawingSorting.cs:57-209`)
#     hleda strop na dlazdici hrace a na (x+1, y+1); `pz14 = playerZ + 14`,
#     `pz16 = playerZ + 16`, `_maxZ` zacina na 127.
#   * Kdyz na (x+1, y+1) najde STŘECHU, nastavi `_maxGroundZ = _maxZ =
#     Map.CalculateNearZ(tileZ, x+1, y+1, tileZ)` (`Map.cs:164-219`) - flood fill
#     po SOUVISLE strese (kazdy krok |z - z_souseda| <= 6, `Map.cs:192`), ktery
#     vraci NEJMENSI `z` te strechy (OKAP), ne `z` nalezene dlazdice (HREBEN).
#   * NAMERENO 2026-10-09 (`_analyza/p27-patra-sonda.gd`): nas kod daval `z`
#     nalezene strechy, takze strop vysel az o 9 jednotek vys (49 misto 40 na
#     (1477,1612)); tykalo se to 85 z 1369 proskenovanych dlazdic v Britanii.
#
# CO SE MERI (chovani, ne pritomnost):
#   1. `near_z` vrati NEJMENSI `z` souvisle strechy (okap), ne tu nalezene,
#   2. souvislost se pocita PO KROCICH: dlazdice s `z` o vic nez 6 dal je jina
#      strecha a flood fill se tam ZASTAVI (nezahrne ji do minima),
#   3. bez strechy na vychozi dlazdici se vraci vstup beze zmeny ("nevim" neni
#      "nejnizsi"),
#   4. `strop_patra` pouzije vysledek `near_z` (a nikdy nejde pod `pz + 16`),
#   5. cache: druhe volani na TUTEZ pozici hrace se uz nepocita (bez ni by se
#      flood fill delal kazdy frame - namEReno 2 492 dlazdic v Britanii),
#   6. pocitadla `near_z_kroku`/`near_z_limit` jsou videt (nula a "nevim" se
#      nesmi tvarit jako uspech).

const ITEM_OFFSET := 0x4000
const F_ROOF := 0x10000000
const F_SURFACE := 0x00000200

const CHUNK_SCRIPT := "res://render/chunk_renderer.gd"

const STŘECHA_A := 0x4000 + 500      # hreben
const STŘECHA_B := 0x4000 + 501      # okap (spojeny)
const STŘECHA_C := 0x4000 + 502      # jina strecha (nespojena)
const ZED := 0x4000 + 600            # statik, ktery NENI strecha


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeMap:
	# Jen to, co `render.chunk` vola. `statics_at` dostava ZAKLAD bloku
	# (nasobek 8) a vraci zaznamy s LOKALNIMI souradnicemi - presne jako
	# `sim/world/map.gd` (a jako `tests/cases/chunk_renderer.gd`).
	var podle_dlazdice: Dictionary = {}      # Vector2i(x, y) -> Array [{art, z}]

	func statics_at(bx: int, by: int) -> Array:
		var out: Array = []
		for dx in 8:
			for dy in 8:
				var klic := Vector2i(bx + dx, by + dy)
				if not podle_dlazdice.has(klic):
					continue
				for s in podle_dlazdice[klic]:
					out.append({"x": dx, "y": dy,
						"tile": int(s["art"]) - ITEM_OFFSET, "z": int(s["z"])})
		return out

	func land_at(_x: int, _y: int) -> int:
		return -1

	func z_at(_x: int, _y: int) -> int:
		return 0


class FakeTextures:
	func offset(_art_id: int) -> Vector2i:
		return Vector2i.ZERO


class FakeTiledata:
	var strechy: Array = []
	var jine: Dictionary = {}       # art -> flagy pro nestresni statiky

	func flags(art_id: int) -> int:
		if strechy.has(art_id):
			return F_ROOF
		return int(jine.get(art_id, 0))

	func height(_art_id: int) -> int:
		return 0

	func texture(tile: int) -> int:
		return tile


func _sestav() -> Array:
	var skript = load(_arg("chunk-script", CHUNK_SCRIPT))
	if skript == null:
		return []
	var mapa := FakeMap.new()
	var td := FakeTiledata.new()
	td.strechy = [STŘECHA_A, STŘECHA_B, STŘECHA_C]
	td.jine[ZED] = 0
	var chunk = skript.new(mapa, FakeTextures.new(), td)
	return [chunk, mapa]


func run(t) -> void:
	var s: Array = _sestav()
	if s.is_empty():
		t._pending("render.chunk NENI HOTOV: " + CHUNK_SCRIPT)
		return
	var chunk = s[0]
	var mapa = s[1]

	# Strecha: hreben 49 na (101,101), okap 43 na (102,101), okap 40 na (103,101)
	# - kazdy krok je do 6 (spojena strecha). Ctvrta dlazdice (104,101) ma 30,
	# coz je od 40 o 10 dal - to je JINA strecha.
	mapa.podle_dlazdice[Vector2i(101, 101)] = [{"art": STŘECHA_A, "z": 49}]
	mapa.podle_dlazdice[Vector2i(102, 101)] = [{"art": STŘECHA_A, "z": 43}]
	mapa.podle_dlazdice[Vector2i(103, 101)] = [{"art": STŘECHA_B, "z": 40}]
	mapa.podle_dlazdice[Vector2i(104, 101)] = [{"art": STŘECHA_C, "z": 30}]

	# 1) `near_z` vraci NEJMENSI z souvisle strechy.
	var nej: int = chunk.near_z(49, 101, 101, 49)
	t._check(nej == 40,
		"render.chunk: near_z vrati okap (nejmensi z) souvisle strechy (namEReno %d, cekano 40)"
			% nej)
	t._check(chunk.near_z_kroku >= 3,
		"render.chunk: near_z proslo aspon 3 dlazdice (namEReno %d)" % chunk.near_z_kroku)
	t._check(chunk.near_z_limit == false,
		"render.chunk: na malou strechu se pojistka nespousti (namEReno %s)"
			% str(chunk.near_z_limit))

	# 2) Nesouvisla strecha (rozdil 10 > 6) se do minima NEPOCITA.
	t._check(nej != 30,
		"render.chunk: strecha o 10 niz (jina strecha) se do minima nepocita (namEReno %d)" % nej)

	# 3) Bez strechy na vychozi dlazdici se vraci vstup (zadna vymyslena hodnota).
	t._check(chunk.near_z(49, 300, 300, 49) == 49,
		"render.chunk: bez strechy vraci near_z vstup (namEReno %d)"
			% chunk.near_z(49, 300, 300, 49))

	# 4) `strop_patra` pouzije okap: hrac na (100,100) z=20, strecha na (101,101).
	#    `pz14 = 34`, `pz16 = 36`, hreben 49 > 34 -> strop = okap 40 (ne 49).
	var strop: Dictionary = chunk.strop_patra(100, 100, 20)
	t._check(int(strop["maxz"]) == 40 and bool(strop["kandidat"]),
		"render.chunk: strop patra je okap 40, ne hreben 49 (namEReno %s)" % str(strop))

	# 4b) Strop nikdy nejde pod `pz + 16` (reference `:205-209`): strecha nad
	#     `pz14` (45 > 34) musi byt SPOJENA dolu, aby `near_z` vratil 25 - a
	#     pak strop spadne na `pz + 16` = 36. (Prvni verze testu mela strechu
	#     na 25, ktera je POD `pz14` - a ta se vubec nekandiduje.)
	for i in range(5):
		mapa.podle_dlazdice[Vector2i(110 + i, 110)] = [{"art": STŘECHA_A, "z": 45 - 5 * i}]
	var nizky: Dictionary = chunk.strop_patra(109, 109, 20)
	t._check(int(nizky["maxz"]) == 36,
		"render.chunk: strop nikdy nejde pod pz+16 = 36 (namEReno %s)" % str(nizky))

	# 5) CACHE: prvni volani pocita, druhe na TUTEZ pozici uz ne (flood fill by
	#    jinak sel kazdy frame - namEReno 2 492 dlazdic v Britanii).
	var pred: int = chunk.strop_vypoctu
	var prvni: Dictionary = chunk.strop_patra(100, 100, 20)
	var po_prvnim: int = chunk.strop_vypoctu
	var druhy: Dictionary = chunk.strop_patra(100, 100, 20)
	t._check(po_prvnim == pred + 1 and chunk.strop_vypoctu == po_prvnim,
		"render.chunk: druhe volani na tutez pozici se pocita z cache (pocitano %d, po prvnim %d)"
			% [chunk.strop_vypoctu, po_prvnim])
	t._check(prvni == druhy,
		"render.chunk: cache vraci stejny vysledek (%s vs %s)" % [str(prvni), str(druhy)])
	# ...a JINA pozice se pocita znovu (cache nesmi vracet stary vysledek).
	chunk.strop_patra(101, 100, 20)
	t._check(chunk.strop_vypoctu == po_prvnim + 1,
		"render.chunk: jina pozice hrace se pocita znovu (pocitano %d, cekano %d)"
			% [chunk.strop_vypoctu, po_prvnim + 1])

	# 6) Nestresni statik vys nad hracem strop snizi TAKY (prvni vetev,
	#    `pz14`), ale jen kdyz nema `Transparent`/`Foliage` a neni to strecha
	#    bez `Surface` - to je pravidlo z reference (`:128-131`).
	mapa.podle_dlazdice[Vector2i(200, 200)] = [{"art": ZED, "z": 45}]
	var zed: Dictionary = chunk.strop_patra(200, 200, 20)
	t._check(int(zed["maxz"]) == 45 and bool(zed["kandidat"]),
		"render.chunk: zed vys nad hracem snizi strop na sve z (namEReno %s)" % str(zed))
