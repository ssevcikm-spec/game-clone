extends RefCounted
# Fade patra/střechy na alfu 0 (2026-10-09, faze 1 bod 5.4).
#
# ZADANI UZIVATELE (doslova): "Na prvnim obrazku je videt, ze se zobrazuje i
# kousek zdi z vyssi urovne (podkroví) - to je pravda, ale ne stale. Krok nebo
# dva stranou se to uz nezobrazuje." - tedy: patro ne/zmizi SKOKEM.
#
# PRAVIDLO Z REFERENCE (precteno z kodu):
#   * `ProcessAlpha` (`_src/classicuo/.../GameSceneDrawingSorting.cs:339-368`):
#     objekt v urovni `_maxZ` a vys (nebo strecha pri `_noDrawRoofs`) se
#     NEVYHAZUJE, ale snizuje se mu alfa na 0,
#   * `CalculateAlpha` (`:398-440`): alfa se meni po **25 jednotkach** na tik,
#   * tik je `Constants.ALPHA_TIME = 20` ms (`Constants.cs:42`),
#   * `Profile.UseObjectsFading == false` fade vypne (`:400-408`).
#   Tedy 255 -> 0 je 11 tiku = **~220 ms**.
#
# CO SE MERI (chovani, ne pritomnost):
#   1. objekt, ktery pri prestavbe seznamu zmizel (strop patra), se ZACHYTI
#      a dohasina - a to presne po 25 za 20 ms, ne skokem,
#   2. po dohasnuti vypadne (a `fade_pocet()` je 0),
#   3. objekt, ktery zustal ve starem pohledu ale MIMO novy, se nechytá
#      (odjel z obrazovky, nezmizel pod stropem),
#   4. `fade_zapnuty = false` = zadny fade (reference `UseObjectsFading`),
#   5. objekt, ktery je znovu videt, z fade VYPADNE (nekresli se dvakrat).

const ITEM_OFFSET := 0x4000
const F_ROOF := 0x10000000

const CHUNK_SCRIPT := "res://render/chunk_renderer.gd"

const STŘECHA := 0x4000 + 700        # art se flagem Roof
const HODIN := 20                    # `Constants.ALPHA_TIME`


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeMap:
	# Statiky podle ABSOLUTNI dlazdice; `statics_at` dostava zaklad bloku
	# (nasobek 8) a vraci zaznamy s lokalnimi souradnicemi (jako `sim/world/map.gd`).
	var podle_dlazdice: Dictionary = {}
	var land_tile: int = 3

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
		return land_tile

	func z_at(_x: int, _y: int) -> int:
		return 0


class FakeTextures:
	func offset(_art_id: int) -> Vector2i:
		return Vector2i.ZERO


class FakeTiledata:
	var strechy: Array = []

	func flags(art_id: int) -> int:
		return F_ROOF if strechy.has(art_id) else 0

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
	td.strechy = [STŘECHA]
	# Střecha na (100,100) ve vysce 45 - hrac na (90,90) ji vidi, hrac na
	# (99,99) ji ma na (x+1,y+1) a tim se strop snizi na 45 (`strop_patra`).
	mapa.podle_dlazdice[Vector2i(100, 100)] = [{"art": STŘECHA, "z": 45}]
	return [skript.new(mapa, FakeTextures.new(), td), mapa]


func _klic(chunk) -> String:
	# Klíč objektu ma i DRUH ("static:") - viz `chunk_renderer.klic_objektu`.
	return "static:%d,%d,%d,%d" % [100, 100, 45, STŘECHA]


func run(t) -> void:
	var s: Array = _sestav()
	if s.is_empty():
		t._pending("render.chunk NENI HOTOV: " + CHUNK_SCRIPT)
		return
	var chunk = s[0]
	var oblast := Vector2i(90, 90)
	var pokryti := 40

	# Hrac dal od střechy: strop je 127, střecha se kresli.
	t._check(chunk.nastav_hrace(90, 90, 20) == false,
		"render.chunk: bez kandidata na strop se nic nemeni")
	var seznam: Array = chunk.visible(oblast, pokryti, pokryti)
	var ma_strechu: bool = false
	for obj in seznam:
		if chunk.klic_objektu(obj) == _klic(chunk):
			ma_strechu = true
	t._check(ma_strechu, "render.chunk (fade): strecha je v seznamu, dokud strop neni nizky")
	t._check(chunk.fade_pocet() == 0, "render.chunk (fade): pred zmenou nic nedohasina")

	# Hrac se posune tak, ze strecha je na (x+1,y+1) -> strop 45 -> strecha
	# zmizi. FADE: musi se zachytit a dohasinat, ne zmizet skokem.
	t._check(chunk.nastav_hrace(99, 99, 20) == true,
		"render.chunk: posun pod strechu zmeni, co se skryva (invalidate)")
	var novy: Array = chunk.visible(Vector2i(99, 99), pokryti, pokryti)
	var porad_v_seznamu: bool = false
	for obj in novy:
		if chunk.klic_objektu(obj) == _klic(chunk):
			porad_v_seznamu = true
	t._check(not porad_v_seznamu,
		"render.chunk (fade): strecha uz v novem seznamu NENI (strop 45)")
	t._check(chunk.fade_pocet() == 1,
		"render.chunk (fade): zmizely objekt se chytil k dohasnuti (namEReno %d)"
			% chunk.fade_pocet())
	# Fade jeste CEKA: objekt je porad ve STARE davce, ktera se kresli, dokud se
	# nová nedostavi. Teprve `spust_fade()` (vola `app.world_view` ve chvili, kdy
	# je nova davka hotova) ho pusti do dohasinani.
	t._check(chunk.fade_ceka() == 1 and chunk.fade_aktivnich == 0,
		"render.chunk (fade): fade ceka na novou davku (ceka %d, aktivnich %d)"
			% [chunk.fade_ceka(), chunk.fade_aktivnich])
	t._check(chunk.spust_fade() == 1,
		"render.chunk (fade): spust_fade uvolni cekajici objekty")
	t._check(chunk.fade_ceka() == 0 and chunk.fade_aktivnich == 1,
		"render.chunk (fade): po spusteni objekt dohasina (ceka %d, aktivnich %d)"
			% [chunk.fade_ceka(), chunk.fade_aktivnich])

	# 1) Alfa klesa po 25 za 20 ms - PRESNE (parne hodnoty ze reference).
	var a0: int = _alfa(chunk, 0)
	var a1: int = _alfa(chunk, HODIN)
	var a2: int = _alfa(chunk, 2 * HODIN)
	t._check(a0 == 255 and a1 == 230 and a2 == 205,
		"render.chunk (fade): alfa klesa 255 -> 230 -> 205 (namEReno %d, %d, %d)"
			% [a0, a1, a2])
	# Cas pred dalším tikem alfau NEMENI.
	t._check(_alfa(chunk, 2 * HODIN + HODIN - 1) == 205,
		"render.chunk (fade): pred dalším tikem se alfa nemeni")

	# 2) Po ~11 ticcich (220 ms) dohasne a VYPADNE.
	for i in range(3, 12):
		chunk.fade_objekty(i * HODIN)
	t._check(chunk.fade_pocet() == 0,
		"render.chunk (fade): po 11 ticcich (220 ms) fade skoncil (zbyva %d)"
			% chunk.fade_pocet())
	t._check(chunk.fade_zachyceno == 1,
		"render.chunk (fade): zachyceno prave jednou (namEReno %d)" % chunk.fade_zachyceno)

	# 4) Fade vypnuty = zadne zachytavani (reference `UseObjectsFading == false`).
	var s2: Array = _sestav()
	var ch2 = s2[0]
	ch2.nastav_hrace(90, 90, 20)
	ch2.visible(Vector2i(90, 90), pokryti, pokryti)
	ch2.fade_zapnuty = false
	ch2.nastav_hrace(99, 99, 20)
	ch2.visible(Vector2i(99, 99), pokryti, pokryti)
	t._check(ch2.fade_pocet() == 0 and ch2.fade_zachyceno == 0,
		"render.chunk (fade): s `fade_zapnuty = false` se nechytá nic (namEReno %d)"
			% ch2.fade_zachyceno)

	# 3) Objekt, ktery zustal ve starem pohledu, ale je MIMO novy, se nechytá.
	var s3: Array = _sestav()
	var ch3 = s3[0]
	ch3.nastav_hrace(90, 90, 20)
	ch3.visible(Vector2i(90, 90), pokryti, pokryti)
	# Pohled odjede tak, ze strecha na (100,100) v novem pokryti NENI.
	ch3.nastav_hrace(40, 40, 20)
	ch3.visible(Vector2i(40, 40), 20, 20)
	t._check(ch3.fade_pocet() == 0,
		"render.chunk (fade): objekt mimo novy pohled se nefaduje (namEReno %d)"
			% ch3.fade_pocet())

	# 5) Objekt, ktery je znovu videt, z fade VYPADNE (nekresli se dvakrat).
	var s4: Array = _sestav()
	var ch4 = s4[0]
	ch4.nastav_hrace(90, 90, 20)
	ch4.visible(Vector2i(90, 90), pokryti, pokryti)
	ch4.nastav_hrace(99, 99, 20)
	ch4.visible(Vector2i(99, 99), pokryti, pokryti)
	t._check(ch4.fade_pocet() == 1, "render.chunk (fade): objekt dohasina")
	# Zpet na (90,90): strecha je znovu videt -> z fade zmizi.
	ch4.nastav_hrace(90, 90, 20)
	ch4.visible(Vector2i(90, 90), pokryti, pokryti)
	t._check(ch4.fade_pocet() == 0,
		"render.chunk (fade): znovu viditelny objekt z fade vypadl (zbyva %d)"
			% ch4.fade_pocet())


func _alfa(chunk, cas: int) -> int:
	# Alfa objektu v case `cas` (0 = zadny zaznam).
	for zaznam in chunk.fade_objekty(cas):
		if chunk.klic_objektu(zaznam["obj"]) == _klic(chunk):
			return int(zaznam["alfa"])
	return -1
