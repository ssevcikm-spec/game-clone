extends RefCounted
# render.chunk_mesh - davkove kresleni (docs/04 §4.2; soubor render/chunk_mesh.gd).
#
# CO SE MERI (docs/09 §9.4 - chovani, ne "soubor existuje"):
#   * GEOMETRIE: kazdy kvadr ma presne ty 4 rohy, ktere by kreslil puvodni
#     `app/world_view` (`draw_texture` na pozici z `render.chunk.screen_position`,
#     svah = `slope_polygon`, dira = magenta diamant/ctverec),
#   * PORADI: kvadry jdou v PORADI seznamu - na tom stoji painter's algoritmus
#     (`render.sort`); kdyby se prerovnaly, obraz by se zmenil,
#   * ATLAS: sprity se do runtime atlasu kopiruji BAJT NA BAJT - test cte pixel
#     z `texture()` na miste, kam ukazuje UV, a srovnava ho s originalem,
#   * VYCLE: land s `art_id <= 2` se nekresli (`nodraw`), chybejici art je dira
#     s barvou `HOLE_COLOR`, svah ma `slope_polygon` + texmap,
#   * SPLIT: `split_for_player(klic)` rozkraji kvadry na "klic <= klic hrace"
#     a zbytek; zmena klice to prekraji znovu (hrac se mezi tim posune).
#     ⚠ 18. session: do teto session tu bylo `split(diagonala)` a zvlastni
#     seznam `hranice()` pro mobily na diagonale hrace - oboji zruseno, protoze
#     klic `render.sort` uz neni diagonala (muze ji prebit o 2,5 kroku).
#   * PRAZDNO NENI USPEH: kdyz se art do stranky nevejde, `build()` vrati false
#     a `pretek()` je true - `app/world_view` pak kresli puvodni cestou.
#
# Cesta k merenemu souboru je VSTUP (`-- --chunk-mesh-script=<cesta>`), aby
# mutacni test mohl predat mutanta a neexistujici cesta case SHODILA.
#
# Test si stavi VLASTNI atlas (16x16 obrazek), mapu a tiledata - nepotrebuje
# `assets/uo/` (ta jsou v .gitignore a v CI nejsou).

const Lib = preload("res://tests/lib.gd")
const ChunkScript = preload("res://render/chunk_renderer.gd")
const Const = preload("res://core/const.gd")

const CHUNK_MESH_SCRIPT := "res://render/chunk_mesh.gd"
const STRANKA: int = 64              # velikost runtime atlasu v testu
# Jas ROVNE plochy podle reference (`IsometricWorld.fx:64,67`): n = (0,0,1),
# svetlo = normalize((0,1,1)), dot = 1/sqrt(2) -> (0.7071068/2)+0.5.
# Je to SPECIFIKACE, proto je tady napsana natvrdo (ne ctena z module) - kdyby
# se cetla z mutanta, mutace konstanty by testem prosla.
const SVAH_JAS_REF: float = 0.85355339
# Smer svetla reference (`IsometricWorld.fx:14`) - taky natvrdo (specifikace).
const SVETLO_REF := Vector3(0.0, 1.0, 1.0)


static func _jas_reference(obj: Dictionary) -> float:
	# NEZAVISLY prepis reference: normala ROVINY ctyr rohu (`Land.CalculateNormal`,
	# `Land.cs:164-238`; meritka 22 px a `Z*4`) + `get_light`
	# (`IsometricWorld.fx:60-69`, `Brightlight = 1.0`). Test si ji pocita SAM,
	# aby nemeril tou funkci, kterou testuje (jinak by prosla i konstanta).
	var rohy: Array = obj.get("z_corners", [])
	if rohy.size() != 4:
		return SVAH_JAS_REF
	var zt: float = float(int(obj["z"]))
	var zr: float = float(int(rohy[1]))
	var zl: float = float(int(rohy[2]))
	var zb: float = float(int(rohy[3]))
	if zt == zr and zt == zl and zt == zb:
		return SVAH_JAS_REF
	var krok: float = float(Const.ISO_STEP)
	var zs: float = float(Const.Z_SCALE)
	var t := Vector3(0.0, -krok, zs * zt)
	var r := Vector3(krok, 0.0, zs * zr)
	var b := Vector3(0.0, krok, zs * zb)
	var l := Vector3(-krok, 0.0, zs * zl)
	# Diagonaly (soucet normal obou trojuhelniku), ne tri rohy - levy roh musi
	# do normály vstoupit taky.
	var n: Vector3 = (r - l).cross(b - t).normalized()
	return maxf(n.dot(SVETLO_REF.normalized()), 0.0) / 2.0 + 0.5


class FakeChunk:
	# STEJNY VZOREC jako `render.chunk.screen_position` (a `core/iso.to_screen`):
	#   screen.x = (x - y) * ISO_STEP
	#   screen.y = (x + y) * ISO_STEP - z * Z_SCALE   (minus `offset` statiku)
	# Modul pozici pocita INLINE (kvuli rychlosti), takze test musi merit proti
	# TOMU vzorci. Ze sedi na skutecny `render.chunk`, meri sekce D nize.
	func screen_position(obj: Dictionary) -> Vector2:
		var x: int = int(obj["x"])
		var y: int = int(obj["y"])
		var z: int = int(obj["z"])
		return Vector2(float(x - y) * float(Const.ISO_STEP),
			float(x + y) * float(Const.ISO_STEP) - float(z * Const.Z_SCALE)) \
			- Vector2(obj["offset"])


class FakeMap:
	var land_tile: int = 3
	var land_rect: Rect2i = Rect2i()
	var void_body: Array = []            # body, kde land_at vraci 1 (nodraw)
	var z_body: Dictionary = {}          # Vector2i -> z
	var statics: Dictionary = {}

	func land_at(x: int, y: int) -> int:
		if void_body.has(Vector2i(x, y)):
			return 1                     # <= VOID_LAND_MAX -> nekresli se
		return land_tile if land_rect.has_point(Vector2i(x, y)) else -1

	func z_at(x: int, y: int) -> int:
		return int(z_body.get(Vector2i(x, y), 0))

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x / 8, y / 8), [])


class FakeTiledata:
	var texmapy: Dictionary = {}         # land art -> texmap id

	func texture(land_id: int) -> int:
		return int(texmapy.get(land_id, 0))

	func flags(_art_id: int) -> int:
		return 0

	func height(_art_id: int) -> int:
		return 0


class FakeTextures:
	# `texture()` vraci `AtlasTexture` do spolecneho obrazku; arty, ktere v mape
	# nejsou, vraci null (to je "chybejici art" = dira).
	var atlas: ImageTexture = null
	var arty: Dictionary = {}            # art_id -> Rect2i
	var offsety: Dictionary = {}

	func texture(art_id: int) -> Texture2D:
		if not arty.has(art_id):
			return null
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = Rect2(arty[art_id])
		return at

	func texmap(texmap_id: int) -> Texture2D:
		return texture(texmap_id + 0x10000)

	# `page_pending` (18. session): test si muze rict, ze se u nejakeho artu
	# jeste nacita stranka - pak se objekt VYNECHA (neni to "chybi art").
	var pending_ids: Array = []

	func page_pending(art_id: int) -> bool:
		return pending_ids.has(art_id)

	func verze() -> int:
		return 0

	func offset(art_id: int) -> Vector2i:
		return offsety.get(art_id, Vector2i.ZERO)


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _atlas() -> ImageTexture:
	# 16x16 obrazek s vyraznymi barvami na zacatcich regionu - z tech se pozna,
	# jestli se sprite do runtime atlasu zkopiroval SPRAVNE.
	var obraz := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	obraz.fill(Color(0.0, 0.0, 0.0, 0.0))
	obraz.set_pixel(0, 0, Color(1, 0, 0, 1))        # land art 3 (region 0,0,4x4)
	obraz.set_pixel(6, 0, Color(0, 1, 0, 1))        # statik 0x4005 (region 6,0,3x2)
	obraz.set_pixel(0, 8, Color(0, 0, 1, 1))        # texmap 7 (region 0,8,8x8)
	return ImageTexture.create_from_image(obraz)


func _textury() -> FakeTextures:
	var t := FakeTextures.new()
	t.atlas = _atlas()
	t.arty[3] = Rect2i(0, 0, 4, 4)                  # land art
	t.arty[0x4000 + 5] = Rect2i(6, 0, 3, 2)         # statik
	t.arty[0x10000 + 7] = Rect2i(0, 8, 8, 8)        # texmap
	t.offsety[0x4000 + 5] = Vector2i(1, 2)
	return t


func _hash_stranky(mesh) -> String:
	# HASH pixelu runtime stranky na GPU. `render_target_update_mode` neni
	# dukaz (cte porad 1) - dukaz je ZMENENY OBSAH. Kdyz se obrazek neda precist,
	# vraci "NEMERENO" (ne prazdny retezec, ktery by vypadal jako namerena nula).
	var tex: Texture2D = mesh.texture()
	if tex == null:
		return "NEMERENO"
	var img: Image = tex.get_image()
	if img == null:
		# V headless rezimu se render target necte - zkusime ho vynutit.
		RenderingServer.force_draw(false)
		img = tex.get_image()
	if img == null:
		return "NEMERENO"
	var data: PackedByteArray = img.get_data()
	if data.is_empty():
		return "NEMERENO"
	if data.is_empty():
		return "NEMERENO"
	var h: int = 1469598103934665603
	for i in range(0, data.size(), 13):
		h = (h ^ int(data[i])) * 1099511628211
		h = h & 0x7FFFFFFFFFFFFFFF
	return "%x" % h


func _obj(kind: String, x: int, y: int, art: int, ostatni: Dictionary = {}) -> Dictionary:
	var o := {"kind": kind, "x": x, "y": y, "z": 0, "art_id": art, "offset": Vector2i.ZERO}
	for k in ostatni.keys():
		o[k] = ostatni[k]
	return o


# 4 rohy jednoho kvadru z plocheho pole vrcholu (6 vrcholu = 2 trojuhelniky:
# [0,1,2] a [2,3,0], takze rohy jsou na indexech 0, 1, 2, 4).
static func _rohy(pole: PackedVector2Array, i: int) -> Array:
	var zaklad: int = i * 6
	return [pole[zaklad], pole[zaklad + 1], pole[zaklad + 2], pole[zaklad + 4]]


static func _rohy_uv(pole: PackedVector2Array, i: int) -> Array:
	var zaklad: int = i * 6
	return [pole[zaklad], pole[zaklad + 1], pole[zaklad + 2], pole[zaklad + 4]]


func run(t) -> void:
	var cesta: String = _arg("chunk-mesh-script", CHUNK_MESH_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("render.chunk_mesh NENI HOTOV: " + cesta + " chybi nebo nejde nacist")
		return
	var krok: float = float(Const.ISO_STEP)

	# --- A) RIZENA SESTAVA: presna geometrie, poradi, atlas, barvy ----------
	var textury := _textury()
	var seznam: Array = [
		_obj("land", 0, 0, 3, {"texmap": 0, "z_corners": [0, 0, 0, 0]}),
		_obj("land", 1, 0, 1, {"texmap": 0, "z_corners": [0, 0, 0, 0]}),   # nodraw
		_obj("land", 2, 0, 3, {"z": 4, "texmap": 7, "z_corners": [4, 1, 2, 3]}),  # svah
		_obj("static", 3, 0, 0x4000 + 5),                                   # sprite
		_obj("static", 4, 0, 0x4000 + 9),                                   # dira
		_obj("mobile", 5, 5, 0x4000 + 5),                                   # hranice
	]
	var kanal := FakeChunk.new()
	var mesh = script.new(kanal, textury, STRANKA)
	var hold_framu: int = int(Lib.consts_at(cesta).get("HOLD_FRAMU", 0))
	var ok: bool = mesh.build(seznam)
	# Stranka se na GPU kresli JEDNOU za zmenu: dokud nema obsah, NESMI se
	# dávkou kreslit (`hold`) - jinak by prvni frame cetl prazdnou texturu.
	t._check(not ok and mesh.hold() == hold_framu and not mesh.pretek()
		and not mesh.is_built(),
		"render.chunk_mesh: po zmene stranky se drzi %d framu puvodni cesta (hold %d)"
			% [hold_framu, mesh.hold()])
	mesh.tick_hold()
	mesh.tick_hold()
	t._check(mesh.hold() == 0 and mesh.is_built(),
		"render.chunk_mesh: po prekresleni stranky se dávka pouzije (hold %d)" % mesh.hold())
	var ok_dalsi: bool = mesh.build(seznam)        # zadny novy art -> zadny hold
	t._check(ok_dalsi and mesh.hold() == 0 and mesh.is_built(),
		"render.chunk_mesh: stavba bez novych artu se pouzije hned (hold %d)"
			% mesh.hold())
	var st: Dictionary = mesh.stats()
	# 5 kvadru = land, svah, statik, dira a MOBIL (18. session: mobil se do
	# davky dava VZDY - deleni na "pred/po hraci" resi az klic, ne seznam).
	t._check(int(st["kvadru"]) == 5 and int(st["nodraw"]) == 1 and int(st["svahu"]) == 1
		and int(st["der"]) == 1,
		"render.chunk_mesh: 5 kvadru, 1 nodraw, 1 svah, 1 dira (namEReno %s)" % str(st))
	t._check(int(st["plocha_px"]) > 0 and int(st["slotu"]) == 4,
		"render.chunk_mesh: runtime atlas ma 4 sloty a nenulovou plochu (namEReno %s)"
			% str([st["slotu"], st["plocha_px"]]))

	# Kvadry v poradi seznamu (nodraw vypadl): land, svah, sprite, dira, mobil
	var body: PackedVector2Array = mesh.get("_verts")
	var uv: PackedVector2Array = mesh.get("_uvs")
	var barvy: PackedColorArray = mesh.get("_barvy")
	t._check(body.size() == 5 * 6 and uv.size() == body.size() and barvy.size() == body.size(),
		"render.chunk_mesh: vrcholu je 5 kvadru x 6 (namEReno %d)" % body.size())
	# Ocekavane pozice se berou z `screen_position` (stejny vzorec jako
	# `render.chunk`); tvary kvadru se overuji vuci nim.
	var p0: Vector2 = kanal.screen_position(seznam[0])     # land (0,0)
	var p2: Vector2 = kanal.screen_position(seznam[2])     # svah (2,0,z=4)
	var p3: Vector2 = kanal.screen_position(seznam[3])     # statik (3,0)
	var p4: Vector2 = kanal.screen_position(seznam[4])     # dira (4,0)
	# 1) land art 3 (4x4) na sve pozici
	var r0: Array = _rohy(body, 0)
	t._check(r0[0] == p0 and r0[1] == p0 + Vector2(4, 0)
		and r0[2] == p0 + Vector2(4, 4) and r0[3] == p0 + Vector2(0, 4),
		"render.chunk_mesh: land kvadr sedi na pozici a rozmeru artu (namEReno %s)" % str(r0))
	# 2) svah: vsechny ctyri rohy z `slope_polygon` - kazdy roh ma JINOU vysku
	#    (4/1/2/3), takze prohozeni stran se pozna.
	var zs: float = float(Const.Z_SCALE)
	var r1: Array = _rohy(body, 1)
	t._check(r1[0] == p2 + Vector2(krok, 0.0)
		and r1[1] == p2 + Vector2(2.0 * krok, krok + 3.0 * zs)
		and r1[2] == p2 + Vector2(krok, 2.0 * krok + 1.0 * zs)
		and r1[3] == p2 + Vector2(0.0, krok + 2.0 * zs),
		"render.chunk_mesh: svah ma vsechny rohy z `slope_polygon` (namEReno %s)" % str(r1))
	# 3) statik s rozmerem 3x2
	var r2: Array = _rohy(body, 2)
	t._check(r2[0] == p3 and r2[1] == p3 + Vector2(3, 0)
		and r2[2] == p3 + Vector2(3, 2),
		"render.chunk_mesh: statik ma rozmer regionu (namEReno %s)" % str(r2))
	# 4) dira: stejny tvar jako `_draw_hole` (ctverec u spodni hrany dlazdice)
	var r3: Array = _rohy(body, 3)
	t._check(r3[0] == p4 + Vector2(krok, 0.0)
		and r3[1] == p4 + Vector2(2.0 * krok, 0.0)
		and r3[2] == p4 + Vector2(2.0 * krok, krok),
		"render.chunk_mesh: dira ma tvar z `_draw_hole` (namEReno %s)" % str(r3))
	# barvy: land bile, dira magenta (jinak by zmizela), SVAH STINOVANY podle
	# normaly (task-5: reference `IsometricWorld.fx:60-69` + `:14`). Barvu svahu
	# pocita `svah_barva()`, takze se tu meri DVE veci zvlast: (1) ze dávka
	# pouziva PRAVE tu funkci (vrchol == jeji vystup), (2) ze funkce dava
	# referencni hodnotu - tu si test pocita SAM (`_jas_reference`).
	var hole_color: Color = Lib.consts_at(cesta).get("HOLE_COLOR", Color.WHITE)
	var svah_barva_davky: Color = script.svah_barva(seznam[2])
	var svah_jas_ref: float = _jas_reference(seznam[2])
	t._check(barvy[0] == Color.WHITE and barvy[1 * 6] == svah_barva_davky
		and barvy[3 * 6].is_equal_approx(hole_color),
		"render.chunk_mesh: dira ma barvu HOLE_COLOR, svah barvu z `svah_barva`, land bilou "
		+ "(namEReno %s / %s / %s)" % [str(barvy[0]), str(barvy[1 * 6]), str(barvy[3 * 6])])
	t._check(is_equal_approx(svah_barva_davky.r, svah_jas_ref)
		and absf(svah_jas_ref - SVAH_JAS_REF) > 0.001,
		"render.chunk_mesh: svah ma jas PODLE NORMALY (namEReno %.6f, reference %.6f, "
			% [svah_barva_davky.r, svah_jas_ref]
		+ "rovina %.8f)" % SVAH_JAS_REF)

	# PORADI: druhy kvadr zacina presne tam, kde prvni konci (v poradi seznamu)
	t._check(body[6] != body[0] and _rohy(body, 1)[0].x > _rohy(body, 0)[0].x,
		"render.chunk_mesh: kvadry jdou v poradi seznamu (painter's algoritmus)")
	# TVAR KVADRU: 6 vrcholu je [c0, c1, c2, c2, c3, c0] - kdyby se druhy
	# trojuhelnik spletl, `_rohy` vyse by to nepoznaly (ctou indexy 0,1,2,4).
	var tvary_ok: bool = true
	for i in 5:
		var zaklad: int = i * 6
		if body[zaklad + 3] != body[zaklad + 2] or body[zaklad + 5] != body[zaklad] \
				or uv[zaklad + 3] != uv[zaklad + 2] or uv[zaklad + 5] != uv[zaklad]:
			tvary_ok = false
	t._check(tvary_ok,
		"render.chunk_mesh: kvadr je dva trojuhelniky [0,1,2] a [2,3,0]")

	# ATLAS: UV ukazuji do runtime atlasu a `Kreslic` tam kresli SPRAVNY sprite
	# na SPRAVNE misto. (Stranka se sklada na GPU - v headless modu se nerekresli,
	# takze se pixel v testu cist NEDA; ze je obraz stejny jako puvodni cesta,
	# dokazuje snimek v behu hry: `_analyza/m9-parita.gd` a `m9-parita.py`.)
	var polozky: Array = mesh.get("_kreslic").polozky
	var uv0: Array = _rohy_uv(uv, 0)
	var misto0 := Vector2i(int(uv0[0].x * STRANKA), int(uv0[0].y * STRANKA))
	var uv2: Array = _rohy_uv(uv, 2)
	var misto2 := Vector2i(int(uv2[0].x * STRANKA), int(uv2[0].y * STRANKA))
	var v_atlase: bool = false
	for p in polozky:
		if p["tex"] == null:
			continue
		var at: AtlasTexture = p["tex"]
		if Vector2i(p["pos"]) == misto0 and at.region == Rect2(0, 0, 4, 4):
			v_atlase = true
	t._check(v_atlase,
		"render.chunk_mesh: UV land artu ukazuji na slot, kam se kresli (namEReno %s v %s)"
			% [str(misto0), str(polozky.size()) + " polozek"])
	t._check(misto0 != misto2 and polozky.size() == 4,
		"render.chunk_mesh: kazdy art ma VLASTNI slot (bily + land + statik + texmap; "
		+ "namEReno %d polozek)" % polozky.size())
	# UV rozsah == rozmer regionu / stranka (jinak by se sprite roztahl)
	t._check(is_equal_approx(absf(uv0[1].x - uv0[0].x), 4.0 / float(STRANKA))
		and is_equal_approx(absf(uv0[3].y - uv0[0].y), 4.0 / float(STRANKA)),
		"render.chunk_mesh: UV rozsah sedi na rozmer artu (namEReno %s)" % str(uv0))

	# --- B) SPLIT: deleni podle KLICE hrace (18. session) --------------------
	# Kvadry jsou v poradi seznamu: 0 = land(0,0), 1 = svah(2,0), 2 = statik(3,0),
	# 3 = dira(4,0), 4 = mobil(5,5). Land ma vlastni pruchod, takze jeho klic je
	# vzdy prvni; mobil (5,5) je posledni.
	var k0: int = mesh.klic_kvadru(0)
	var k1: int = mesh.klic_kvadru(1)
	var k4: int = mesh.klic_kvadru(4)
	t._check(k0 < k1 and k1 < k4,
		"render.chunk_mesh: klic kvadru roste v poradi seznamu (%d < %d < %d)" % [k0, k1, k4])
	# Hrac stoji na (5,5) = klic mobilu: vse ostatni je "pred hracem".
	mesh.split_for_player(k4)
	var pred: ArrayMesh = mesh.get("_mesh_pred")
	var po: ArrayMesh = mesh.get("_mesh_po")
	t._check(pred != null and po == null,
		"render.chunk_mesh: hrac na (5,5) - vse je 'pred hracem' (po prazdne %s)"
			% str(po == null))
	# UPROSTRED: klic kvadru 1 (svah) -> pred = 2 kvadry (land, svah), po = 3.
	mesh.split_for_player(k1)
	pred = mesh.get("_mesh_pred")
	po = mesh.get("_mesh_po")
	var vpred: PackedVector2Array = PackedVector2Array()
	var vpo: PackedVector2Array = PackedVector2Array()
	if pred != null:
		vpred = pred.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if po != null:
		vpo = po.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	t._check(vpred.size() == 2 * 6 and vpo.size() == 3 * 6,
		"render.chunk_mesh: split_for_player(klic svahu) da 2+3 kvadry (namEReno %d+%d)"
			% [vpred.size() / 6, vpo.size() / 6])
	t._check(vpred.size() >= 6 and vpred[0] == body[0],
		"render.chunk_mesh: 'pred hracem' zacina land kvadrem (namEReno %s)" % str(vpred[0]))
	t._check(vpo.size() >= 6 and vpo[0] == _rohy(body, 2)[0],
		"render.chunk_mesh: 'po hraci' zacina statikem (namEReno %s)" % str(vpo[0]))
	# Stejny klic znovu = zadna prace (instance zustava).
	var po_instance = mesh.get("_mesh_po")
	mesh.split_for_player(k1)
	t._check(is_same(po_instance, mesh.get("_mesh_po")),
		"render.chunk_mesh: split se stejnym klicem nic nestavi (instance zustava)")
	# Bez hrace (`klic = -1`) se kresli CELE - "pred hracem" je prazdne.
	var mesh2 = script.new(FakeChunk.new(), textury, STRANKA)
	mesh2.build(seznam)
	mesh2.split_for_player(-1)
	t._check(int(mesh2.stats()["kvadru"]) == 5 and mesh2.get("_mesh_pred") == null
		and mesh2.get("_mesh_po") != null,
		"render.chunk_mesh: bez hrace (klic -1) je vse v 'po hraci' (kvadru %s)"
			% str(mesh2.stats()["kvadru"]))

	# --- D) REALNY render.chunk: davka pouziva JEHO pozice -----------------
	var mapa := FakeMap.new()
	mapa.land_rect = Rect2i(0, 0, 6, 6)
	mapa.void_body = [Vector2i(5, 0)]
	mapa.z_body[Vector2i(0, 0)] = 4
	mapa.statics[Vector2i(0, 0)] = [
		{"tile": 5, "x": 1, "y": 1, "z": 0, "hue": 0},
		{"tile": 9, "x": 2, "y": 2, "z": 0, "hue": 0},
	]
	var tiledata := FakeTiledata.new()
	tiledata.texmapy[3] = 7
	var textury2 := _textury()
	var chunk = ChunkScript.new(mapa, textury2, tiledata)
	var seznam2: Array = chunk.visible(Vector2i(3, 3), 6, 6)
	var mesh3 = script.new(chunk, textury2, STRANKA)
	var ok3: bool = mesh3.build(seznam2)                   # bez hrace -> kresli se vse
	mesh3.tick_hold()
	mesh3.tick_hold()
	ok3 = ok3 or mesh3.is_built()                         # hold se tyka jen GPU stranky
	var telo3: PackedVector2Array = mesh3.get("_verts")
	var q: int = 0
	var shoda: bool = true
	var ocekavano: int = 0
	for obj in seznam2:
		var art_id: int = int(obj["art_id"])
		if str(obj["kind"]) == "land" and art_id <= 2:
			continue
		ocekavano += 1
		var pozice: Vector2 = chunk.screen_position(obj)
		var prvni: Vector2 = telo3[q * 6] if q * 6 < telo3.size() else Vector2(-99999, -99999)
		var svah: bool = str(obj["kind"]) == "land" and mesh3.je_svah(obj, textury2)
		# Rovny sprite zacina v `pozice`; svah i dira zacinaji o `ISO_STEP` vpravo
		# (svah je `slope_polygon`, dira ma tvar z `_draw_hole`).
		var dira: bool = not svah and textury2.texture(art_id) == null
		var ocekavany_prvni: Vector2 = pozice if not (svah or dira) \
			else pozice + Vector2(krok, 0.0)
		if prvni != ocekavany_prvni:
			shoda = false
		q += 1
	t._check(ok3 and shoda and q == ocekavano and q == int(mesh3.stats()["kvadru"]),
		"render.chunk_mesh: na REALNEM render.chunk sedi kazdy kvadr na "
		+ "`screen_position` (kvadru %d z %d, shoda %s)" % [q, ocekavano, str(shoda)])
	t._check(int(mesh3.stats()["nodraw"]) == 1 and int(mesh3.stats()["svahu"]) == 1,
		"render.chunk_mesh: realna mapa ma 1 nodraw a 1 svah (namEReno %s)"
			% str([mesh3.stats()["nodraw"], mesh3.stats()["svahu"]]))

	# --- F) ⚠ 17. session: STRANKA SE NA GPU PREKRESLI PRI KAZDE ZMENE ------
	# Uzivatel: "priblizne kazdym ctvrtým krokem se rozbiji zobrazovani ...
	# nektere textury působí rozmazaně, jakoby byly zvětšené". Pricina
	# (namERena, `_analyza/p20b-nalez.md`): `SubViewport.UPDATE_ONCE` znamena
	# "vykresli se JEDNOU PO PRIZNACENI rezimu", ne "pri kazdem queue_redraw()".
	# Stranka se proto prekreslila jen pri PRVNI stavbe a kazda dalsi zmena
	# `_sloty` nechala na strance STARE rozvrzeni, zatimco UV uz mirila jinam.
	# Hodnota `render_target_update_mode` pritom cte porad 1 - proto vada nebyla
	# v zadnem logu videt. Dukaz je ZMENENY OBSAH stranky.
	#
	# ⚠ MERITELNOST: v `--headless` se render target NECTE (`get_image()` vraci
	# null i po `RenderingServer.force_draw`), takze se tu obsah stranky zmerit
	# NEDA - a test to REKNE (NEMERENO), nez aby predstiral zelenou. Obsah
	# stranky je zmereny v behu S OKNEM: `_analyza/p20b2-stranka.gd` (hash pred
	# 465af1115c5608ae, po 283d4ac1cef3358d) a MUTACNI DUKAZ týmz telem bez
	# re-armu (hash pred == po == 3755e0ff80725c54). Tady se meri to, co meret
	# jde: ze stavba stranku posklada a ze druha stavba prida nove sloty.
	var textury3 := _textury()
	var chunk3 = ChunkScript.new(mapa, textury3, tiledata)
	var sez_a: Array = chunk3.visible(Vector2i(3, 3), 3, 3)
	var mesh_c = script.new(FakeChunk.new(), textury3, STRANKA)
	mesh_c.build(sez_a)
	var hash_c1: String = _hash_stranky(mesh_c)
	chunk3.invalidate()
	var sez_b: Array = chunk3.visible(Vector2i(1, 1), 2, 2)
	mesh_c.build(sez_b)
	var hash_c2: String = _hash_stranky(mesh_c)
	t._check(int(mesh_c.stats().get("slotu", 0)) > 0 and int(mesh_c.stats().get("kvadru", 0)) > 0,
		"render.chunk_mesh: stavba posklada stranku i kvadry (slotu %s, kvadru %s)"
			% [str(mesh_c.stats().get("slotu")), str(mesh_c.stats().get("kvadru"))])
	if hash_c1 == "NEMERENO" or hash_c2 == "NEMERENO":
		print("[test]      NEMERENO: obsah stranky na GPU se v headless necte - "
			+ "dukaz je v `_analyza/p20b2-stranka.gd` (okno): s re-armem se hash "
			+ "zmeni, bez re-armu zustane stejny")
	else:
		t._check(hash_c1 != hash_c2,
			"render.chunk_mesh: druha stavba PREKRESLI stranku na GPU "
			+ "(hash pred %s, po %s)" % [hash_c1, hash_c2])

	# --- F) ⚠ 18. session: CEKAJICI STRANKA NENI DIRA ----------------------
	# Stranky atlasu se nacitaji na pozadi; kdyz objekt potrebuje art ze stranky,
	# ktera jeste neni v pameti, objekt se VYNECHA a pocita se do `ceka`. Kreslit
	# za nej magenta diru by byla lez ("chybi art" je neco jineho nez "jeste se
	# nacita") a uzivatel by videl blikajici magenta plochy.
	var textury4 := _textury()
	textury4.pending_ids = [9 + 0x4000]        # statik 9 = stranka se jeste nacita
	textury4.arty.erase(9 + 0x4000)            # ...a texturu tedy jeste nema
	var mesh4 = script.new(FakeChunk.new(), textury4, STRANKA)
	mesh4.build(seznam)
	mesh4.tick_hold()
	mesh4.tick_hold()
	var st4: Dictionary = mesh4.stats()
	t._check(int(st4["ceka"]) == 1 and int(st4["der"]) == 0 and int(st4["kvadru"]) == 4,
		"render.chunk_mesh: cekajici stranka se VYNECHA (ceka 1, der 0, kvadru 4; namEReno %s)"
			% str(st4))

	# --- G) ⚠ 18. session: STAVBA PO CASTECH DA STEJNA DATA ------------------
	# `build()` je atomicky (jeden frame), hra stavi `zacni()` + `krok()`.
	# Obe cesty MUSI dat PRESNE stejnou geometrii - kdyby se rozechazely, obraz
	# by zavisel na zatizeni stroje (a `_draw` by kreslil jinou davku nez test).
	var atomicky = script.new(FakeChunk.new(), textury, STRANKA)
	atomicky.build(seznam)
	var po_castech = script.new(FakeChunk.new(), textury, STRANKA)
	po_castech.zacni(seznam)
	t._check(po_castech.stavi_se(),
		"render.chunk_mesh: `zacni` necha stavbu otevrenou (stavi_se %s)"
			% str(po_castech.stavi_se()))
	po_castech.krok(1.0e9)
	t._check(not po_castech.stavi_se() and po_castech.stats().size() > 0,
		"render.chunk_mesh: `krok` stavbu dokonci a zapise statistiky")
	t._check(atomicky.get("_verts") == po_castech.get("_verts")
		and atomicky.get("_uvs") == po_castech.get("_uvs")
		and atomicky.get("_barvy") == po_castech.get("_barvy")
		and atomicky.get("_klic") == po_castech.get("_klic"),
		"render.chunk_mesh: stavba po castech da STEJNA data jako atomicka "
		+ "(vrcholu %d vs %d)" % [atomicky.get("_verts").size(), po_castech.get("_verts").size()])
	# ⚠ A ROZDELENI SE MUSI OPRAVDU DIT: na velkem seznamu s drobnym rozpoctem
	# musi `krok` skoncit UPROSTRED stavby. Kdyby se cas nekontroloval, dokoncil
	# by vse v jednom volani (a frame by byl zase 150 ms) - na to upozornil az
	# mutacni test ("stavba se nedeli do framu" prochazel).
	var velky_seznam: Array = []
	for i in 4000:
		velky_seznam.append(_obj("static", i % 64, (i / 64) % 64, 0x4000 + 5))
	var kouskovany = script.new(FakeChunk.new(), textury, STRANKA)
	kouskovany.zacni(velky_seznam)
	kouskovany.krok(0.001)                      # 1 us: smi udelat jen DRZKA objektu
	t._check(kouskovany.stavi_se(),
		"render.chunk_mesh: `krok` s malym rozpoctem stavbu NEDOKONCI (stavi_se %s)"
			% str(kouskovany.stavi_se()))
	# a cas se meri jako SKUTECNA prace, ne jako stena pres framy
	t._check(float(po_castech.stats().get("stavba_ms", -1.0)) >= 0.0
		and int(po_castech.stats().get("kroku", 0)) >= 1,
		"render.chunk_mesh: `kroku` a `stavba_ms` se meri (namEReno %s / %s)"
			% [str(po_castech.stats().get("kroku")), str(po_castech.stats().get("stavba_ms"))])

	# --- E) PRETEK: co se nevejde, se NAHLASI ------------------------------	# Zamerne se bere JEN maly art (4x4) a stranka 6x6: art se vejde SAM, ale
	# s bilym slotem uz ne - tim se meri VETEV "stranka je plna", ne "art je
	# vetsi nez stranka" (to je jina vetev a jina hlaska).
	var maly_seznam: Array = [_obj("land", 0, 0, 3, {"texmap": 0, "z_corners": [0, 0, 0, 0]})]
	var maly = script.new(FakeChunk.new(), textury, 6)
	var ok4: bool = maly.build(maly_seznam)
	t._check(not ok4 and maly.pretek() and not maly.is_built(),
		"render.chunk_mesh: plna stranka se NAHLASI (build %s, pretek %s, slotu %s)"
			% [str(ok4), str(maly.pretek()), str(maly.stats()["slotu"])])
	# a druha vetev: art, ktery je sam vetsi nez stranka
	var velky = script.new(FakeChunk.new(), textury, 2)
	var ok5: bool = velky.build(maly_seznam)
	t._check(not ok5 and velky.pretek(),
		"render.chunk_mesh: art vetsi nez stranka se NAHLASI (build %s)" % str(ok5))

	# --- H) ⚠ task-5: STINOVANI SVAHU PODLE NORMALY ------------------------
	# Reference: `IsometricWorld.fx:14` (`LIGHT_DIRECTION = (0,1,1)`) a `:60-69`
	# (`get_light`); normala = rovina ctyr rohu (`Land.CalculateNormal`,
	# `Land.cs:164-238`). Co se tu meri:
	#   (a) ROVNA dlazdice = dnesni barva BEZE ZMENY (identita) - jedina
	#       kontrola, ktera pozna, ze se nemeni to, co menit nema,
	#   (b) dva svahy s OPACNYM sklonem maji RUZNY jas,
	#   (c) svah s JINOU normalou ma jas jiny nez prvni dva,
	#   (d) jas zustava v <0,1> a NEPRESVITI texturu - i kdyz volajici preda
	#       `Brightlight` profilu 15 (1.5), ktery na realnem terenu dava 1.073223.
	var rovna := _obj("land", 0, 0, 3, {"z": 5, "texmap": 0, "z_corners": [5, 5, 5, 5]})
	var svah_a := _obj("land", 0, 0, 3, {"z": 0, "texmap": 7, "z_corners": [0, 0, 0, 10]})
	var svah_b := _obj("land", 1, 0, 3, {"z": 10, "texmap": 7, "z_corners": [10, 0, 0, 0]})
	var svah_c := _obj("land", 2, 0, 3, {"z": 0, "texmap": 7, "z_corners": [0, 0, 10, 0]})
	var svah_barva: Color = Lib.consts_at(cesta).get("SVAH_BARVA", Color.WHITE)
	# (a) IDENTITA: rovna dlazdice vraci PRESNE puvodni konstantu (ne priblizne)
	# - proto se to srovnava `==`, ne `is_equal_approx` (jinak by proslo
	# i "0.8535534 misto 0.85355339", coz je zmena, ktera se merit nema).
	var n_rovna: Vector3 = script.svah_normal(rovna)
	var jas_rovna: float = script.svah_jas(rovna)
	t._check(n_rovna == Vector3.ZERO and jas_rovna == SVAH_JAS_REF
		and script.svah_barva(rovna) == svah_barva,
		"render.chunk_mesh: ROVNA dlazdice = normala 0 a PRESNE puvodni barva "
		+ "(namEReno n %s, jas %.8f vs %.8f, barva %s vs %s)" % [str(n_rovna),
			jas_rovna, SVAH_JAS_REF, str(script.svah_barva(rovna)), str(svah_barva)])
	# (b)+(c) jas podle normaly: srovnani s NEZAVISLY prepisem reference
	var ja: float = script.svah_jas(svah_a)
	var jb: float = script.svah_jas(svah_b)
	var jc: float = script.svah_jas(svah_c)
	var ra: float = _jas_reference(svah_a)
	var rb: float = _jas_reference(svah_b)
	var rc: float = _jas_reference(svah_c)
	t._check(is_equal_approx(ja, ra) and is_equal_approx(jb, rb) and is_equal_approx(jc, rc),
		"render.chunk_mesh: jas svahu sedi na referenci (namEReno %.6f/%.6f/%.6f, "
			% [ja, jb, jc]
		+ "reference %.6f/%.6f/%.6f)" % [ra, rb, rc])
	t._check(absf(ja - jb) > 0.1 and ja < jb,
		"render.chunk_mesh: dva svahy s OPACNYM sklonem maji RUZNY jas "
		+ "(namEReno %.6f vs %.6f)" % [ja, jb])
	t._check(absf(jc - ja) > 0.05 and absf(jc - jb) > 0.05,
		"render.chunk_mesh: svah s JINOU normalou ma jas jiny nez prvni dva "
		+ "(namEReno %.6f vs %.6f / %.6f)" % [jc, ja, jb])
	# (d) rozsah: s VYCHOZIM `Brightlight` (1.0) je jas v <0,1) - nikdy nic
	# nepresviti. S profilem 15 (1.5) by reference prekrocila 1.0, takze se
	# BARVA oreze na 1.0 (kresleni nesmi dat vic) - a `svah_jas` to cislo
	# ukaze nezorezane, aby byl videt rozdil.
	var rozsah_ok: bool = true
	var nejmensi: float = 9.0
	var nejvetsi: float = -9.0
	var nejvetsi_15: float = -9.0
	for o in [svah_a, svah_b, svah_c, seznam[2]]:
		var c: Color = script.svah_barva(o)
		nejmensi = minf(nejmensi, minf(c.r, minf(c.g, c.b)))
		nejvetsi = maxf(nejvetsi, maxf(c.r, maxf(c.g, c.b)))
		if c.r < 0.0 or c.r > 1.0 or c.g < 0.0 or c.g > 1.0 or c.b < 0.0 or c.b > 1.0:
			rozsah_ok = false
		var c15: Color = script.svah_barva(o, 1.5)
		nejvetsi_15 = maxf(nejvetsi_15, maxf(c15.r, maxf(c15.g, c15.b)))
		if c15.r < 0.0 or c15.r > 1.0 or c15.g < 0.0 or c15.g > 1.0 or c15.b < 0.0 or c15.b > 1.0:
			rozsah_ok = false
	t._check(rozsah_ok and nejmensi >= 0.0 and nejvetsi < 1.0 and nejvetsi_15 <= 1.0,
		"render.chunk_mesh: barva svahu je v <0,1) a NEPRESVITI ani s profilem 15 "
		+ "(namEReno min %.6f, max pri 1.0 %.6f, max pri 1.5 %.6f)"
			% [nejmensi, nejvetsi, nejvetsi_15])
	# `Brightlight` je VSTUP, ne mrtvy parametr: s 1.5 se jas ZVETSI a reference
	# by prekrocila 1.0 - kdyby se parametr ignoroval, tohle spadne.
	var base_b: float = _jas_reference(svah_b)
	var ocekavane_15: float = base_b + (1.5 * (base_b - SVAH_JAS_REF) - (base_b - SVAH_JAS_REF))
	t._check(script.svah_jas(svah_b, 1.5) > script.svah_jas(svah_b)
		and is_equal_approx(script.svah_jas(svah_b, 1.5), ocekavane_15)
		and ocekavane_15 > 1.0 and script.svah_barva(svah_b, 1.5).r <= 1.0,
		"render.chunk_mesh: `Brightlight` je VSTUP (1.5 da %.6f > 1.0, barva se oreze na %.6f)"
			% [script.svah_jas(svah_b, 1.5), script.svah_barva(svah_b, 1.5).r])
	# A CELOU CESTU: dávka da do VRCHOLU presne to, co vraci `svah_barva`
	var mesh_s = script.new(FakeChunk.new(), textury, STRANKA)
	mesh_s.build([svah_a, svah_b, svah_c])
	mesh_s.tick_hold()
	mesh_s.tick_hold()
	var barvy_s: PackedColorArray = mesh_s.get("_barvy")
	var sedi_vrcholy: bool = barvy_s.size() == 3 * 6
	for i in 3:
		var ocekavana: Color = script.svah_barva([svah_a, svah_b, svah_c][i])
		for v in 6:
			if barvy_s[i * 6 + v] != ocekavana:
				sedi_vrcholy = false
	t._check(sedi_vrcholy and int(mesh_s.stats()["svahu"]) == 3,
		"render.chunk_mesh: dávka kresli kazdy svah svou barvou z `svah_barva` "
		+ "(svahu %s, vrcholu %d)" % [str(mesh_s.stats()["svahu"]), barvy_s.size()])
