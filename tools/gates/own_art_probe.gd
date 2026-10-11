extends SceneTree
# PROBE pro branu G15 (`tools/gates/check-own-art.py`) - doklad, ze se vlastni
# art prepina PO KUSECH. Neni to brana sama: brana spousti tenhle skript a
# POROVNAVA jeho vystup s manifesty (`assets/own-lit/`, `assets/own/`,
# `assets/uo/`) - kdyby si probe pocital ocekavane hodnoty sam, meril by sebe.
#
# Dva rezimy:
#   1) bez argumentu: FAKTA o seamu (co se bere odkud, co zustalo z UO, co se
#      stane po vypnuti). Vypise radky `[probe] klic=hodnota`, pak `quit(0)`.
#   2) `--snimek=<cesta>`: SNIMEK hry s vlastnim artem (postava v chuzi, batoh
#      s vlastnimi ikonami) - to je lidsky doklad k rebaseline G10.
#      Dalsi prepinace: `--pole=x,y` (kam postavit hrace), `--framu=N`.
#
# Spousteni (headless staci pro fakta, snimek potrebuje okno/opengl3):
#   godot --headless --path . --script res://tools/gates/own_art_probe.gd
#   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#         --script res://tools/gates/own_art_probe.gd -- --snimek=res://.cache/render/own-art.png --pole=1300,1552

const OwnArtScript = preload("res://render/own_art.gd")
const TextureCacheScript = preload("res://render/texture_cache.gd")
const AnimScript = preload("res://render/anim_player.gd")
const WalkScript = preload("res://sim/world/walk.gd")
const MapScript = preload("res://sim/world/map.gd")

# ⚠ VLASTNI ID SE BEROU Z KONFIGURACE, NE Z KONSTANTY (opraveno 2026-10-11).
# NamEReno: sonda mela id natvrdo (`VLASTNI = [3, 1001, …]`), ale brana je bere
# z `assets/own-art.json` - takze pridani vrstvy (kamenna cesta 1001-1004) shodilo
# G15 falsenymi hlasenimi "art 1002 se nenacetl (None)". Konstantni seznam navic
# prestane byt pravdivy, aniz by si toho kdokoli vsimnul (docs/07 past "mrtva
# kotva"). Sonda proto cte `cfg["layers"]` a art_id pocita stejnym vzorcem jako
# `render/texture_cache.gd`.
# FALLBACK (id, ktera MUSI zustat z UO): kandidati niz jsou id, ktera produkce
# opravdu pouziva; sonda z nich vybere ta, ktera v konfiguraci NEJSOU. Brana si
# tyz seznam spocita SAMA z konfigurace - kdyby se obe strany rozesly, je to vada
# brany, ne ticho.
const FALLBACK_KANDIDATI: Array = [1004, 100, 116, 5, 1030, 0x4E75]

var _f: int = 0
var _scena = null
var _snimek: String = ""
var _pole: Vector2i = Vector2i(1300, 1552)
var _framu: int = 240
var _seq: int = 0
var _z: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--snimek="):
			_snimek = a.substr("--snimek=".length())
		elif a.begins_with("--pole="):
			var casti := a.substr("--pole=".length()).split(",")
			if casti.size() == 2:
				_pole = Vector2i(int(casti[0]), int(casti[1]))
		elif a.begins_with("--framu="):
			_framu = int(a.substr("--framu=".length()))
	if _snimek == "":
		_fakta()
		quit(0)
		return
	_scena = load("res://app/main.tscn").instantiate()
	root.add_child(_scena)
	print("[probe] snimek: scena nactena, cil ", _pole)


func _process(_delta: float) -> bool:
	if _snimek == "":
		return true
	_f += 1
	if _scena == null or _scena.player == null:
		return _f > 600
	# Postava se drzi v CHUZI pres signal `draw` (viz `_initialize`).
	if _scena.world_view != null:
		_scena.world_view.call_deferred("set_action", 0)
	if _f == 20:
		var mapa = MapScript.new()
		var walk = WalkScript.new(mapa)
		_z = walk.surface_z(_pole.x, _pole.y)
		_scena.player.pos = Vector3i(_pole.x, _pole.y, _z)
		_scena.player.dir = 0
		if _scena.controller != null:
			_scena.controller._follow()
		# Overlay se schova: prekryva levy horni roh (a prave tam je batoh).
		if _scena.debug_overlay != null:
			_scena.debug_overlay.visible = false
		if _scena.hud != null and _scena.backpack != null:
			_scena.hud.set_position("backpack", Vector2(8.0, 8.0))
		print("[probe] hrac na ", _pole, " (", _scena.player.pos, ")")
	# POSTAVA SE ROZJDE (ne "pózuje"): vlastni sada ma dnes jen chuzi
	# (`400/0/*`), takze ve stoje kresli hra UO idle - to je spravne chovani
	# seamu, ale na snimku by vlastni postava nebyla. Do simulace se proto
	# posila skutecny prikaz `move`; `app.player_controller` z rozjeteho kroku
	# nastavi `_action = WALK` sám. Predchozi pokusy (prime volani
	# `set_action(0)`, `call_deferred`) neuspely - `_process` kontroleru je
	# prebil (overlay psal `anim=idle`, `player_frames=1`).
	if _f >= 20 and _f % 4 == 0 and _scena.sim != null:
		_scena.sim.enqueue({"t": "move", "dir": 0, "run": false, "seq": _seq})
		_seq += 1
	# ⚠ POSTAVA SE DRZI NA MISTE (`pos` se kazdy frame vrati) a smer 0:
	# bez toho se obraz za 240 framu odveze jinam (a srovnani "pred/po" by
	# neporovnavalo TOTEZ misto - namEReno: UO a vlastni snimek mely jinou
	# kameru, takze se nedaly položit vedle sebe). Krok zustava v letu, proto
	# se porad kresli CHUZE.
	if _f >= 20:
		_scena.player.pos = Vector3i(_pole.x, _pole.y, _z)
		_scena.player.dir = 0
		if _scena.world_view != null:
			_scena.world_view.set_view_dir(0)
			# Posun mezi dlazdicemi se VYNULUJE: jinak je kamera v kazdem behu
			# o jinych par pixelu (jiny frame animace), a srovnani "UO vs.
			# vlastni" by neporovnavalo totéž misto.
			_scena.world_view.set_player_offset(Vector2.ZERO)
		if _scena.controller != null:
			_scena.controller._follow()
	# Batoh se PLNI OPAKOVANE: stranky vlastniho artu se nacitaji NA POZADI
	# (`load_threaded_request`), takze prvni `texture()` muze vratit null - a
	# `ui.backpack` si hotovy radek uz neprestavi (dokud se obsah nezmeni).
	# Kdyby se obsah nechal jednou, ikony by na snimku chybely (namereno).
	if _f >= 20 and _f % 30 == 0 and _scena.backpack != null:
		_scena.backpack.nastav_obsah([
			{"art": 0x4E85, "name": "pickaxe", "amount": 1},
			{"art": 0x4F51, "name": "dagger", "amount": 1},
			{"art": 0x59B7, "name": "iron ore", "amount": 3},
			{"art": 0x5BEF, "name": "iron ingot", "amount": 2},
		])
		_scena.backpack.visible = true
	if _f < _framu:
		return false
	var obraz: Image = root.get_texture().get_image()
	var chyba: int = obraz.save_png(_snimek)
	print("[probe] snimek ", _snimek, " (err ", chyba, ", ", obraz.get_width(), "x",
		obraz.get_height(), ")")
	if _scena.textures != null:
		print("[probe] textury ", _scena.textures.stats())
	if _scena.backpack != null:
		var diag: Array = _pocet_ikon(_scena.backpack)
		print("[probe] backpack: textury_null=", 1 if _scena.backpack.textury == null else 0,
			", uzlu=", diag[0], ", TextureRect=", diag[1], ", s_texturou=", diag[2])
	if _scena.world_view != null:
		# DOKLAD O PUVODU POSTAVY: ktera akce/smer se kresli a odkud je list.
		# Bez toho by "na snimku je vlastni postava" bylo tvrzeni od oka.
		var wv = _scena.world_view
		print("[probe] hrac: action=", wv._action, " dir=", wv._view_dir)
		if wv._player != null and wv._anim != null:
			var clip: Dictionary = wv._anim.play(int(wv._player.serial), int(wv._action),
				int(wv._view_dir), 0)
			print("[probe] hrac clip: ok=", clip["ok"], " own=", clip["own"],
				" frame=", clip["frame"], "/", clip["count"], " list=",
				wv._anim.sheet_file(400, int(wv._action), int(wv._view_dir)))
		print("[probe] postava kreslena ", wv.player_drawn, ", chybi ", wv.player_missing,
			", frame=", wv.player_frame, "/", wv.player_frames)
		if _scena.controller != null:
			print("[probe] krok: ", _scena.controller.get("_step"),
				" pos=", _scena.player.pos, " seq=", _seq)
		print("[probe] pozice_kresleni=", wv.player_ground_position(),
			" camera=", wv.get_viewport().get_camera_2d().position
				if wv.get_viewport().get_camera_2d() != null else Vector2.ZERO,
			" global=", wv.get_global_transform_with_canvas().origin)
		# KTERE DLAZDICE JSOU V ZABERU: bez toho by "na snimku je 5 dlazdic
		# vlastniho artu" bylo tvrzeni od oka. Bere se hotovy kreslici seznam
		# (`world_view._list()`), ktery obsahuje `art_id` a `kind`.
		var landy: Dictionary = {}
		for obj in wv._list():
			if str(obj.get("kind", "")) == "land":
				var art: int = int(obj.get("art_id", -1))
				landy[art] = int(landy.get(art, 0)) + 1
		print("[probe] land_id_v_zaberu=", _serazene(landy))
	quit(0)
	return true


func _serazene(slovnik: Dictionary) -> Array:
	# `art_id: pocet` serazene podle id - dve behy se pak daji porovnat textove.
	var out: Array = []
	var klice: Array = slovnik.keys()
	klice.sort()
	for k in klice:
		out.append("%d:%d" % [int(k), int(slovnik[k])])
	return out


func _pocet_ikon(uzel) -> Array:
	# Diagnostika batohu: kolik TextureRect uzlu existuje a kolika z nich chybi
	# textura. Bez toho by "ikona neni videt" melo dve ruzne priciny (uzel neni
	# vs. textura je null) a nedalo by se to rozlisit.
	var uzlu: int = 0
	var rectu: int = 0
	var s_texturou: int = 0
	for c in uzel.get_children():
		uzlu += 1
		if c is TextureRect:
			rectu += 1
			if c.texture != null:
				s_texturou += 1
				var atlas = c.texture
				var stranka = null if not (atlas is AtlasTexture) else atlas.atlas
				print("[probe] ikona ", rectu, ": global=", c.global_position,
					" size=", c.size, " tex=", c.texture.get_width(), "x", c.texture.get_height(),
					" region=", (Rect2() if not (atlas is AtlasTexture) else atlas.region),
					" atlas=", ("null" if stranka == null else str(stranka.get_width())))
		var d: Array = _pocet_ikon(c)
		uzlu += int(d[0])
		rectu += int(d[1])
		s_texturou += int(d[2])
	return [uzlu, rectu, s_texturou]


func _fakta() -> void:
	var cfg: Dictionary = OwnArtScript.load_config()
	print("[probe] cfg_ok=", 1 if cfg["ok"] else 0)
	print("[probe] cfg_errors=", cfg["errors"].size())
	for e in cfg["errors"]:
		print("[probe] cfg_error=", e)
	var vrstvy: Array = cfg["layers"]
	print("[probe] cfg_layers=", vrstvy.size())
	print("[probe] cfg_names=", ",".join(_jmena(vrstvy)))

	# Ktera id MAJI vlastni art: z konfigurace (ne z konstanty) - viz hlavicka.
	var vlastni: Array = []
	for v in vrstvy:
		var sp = v.get("sprites", null)
		if not (sp is Dictionary):
			continue
		for kind in sp.keys():
			for ident in sp[kind]:
				var aid: int = _art_id(str(kind), int(ident))
				if aid >= 0 and not vlastni.has(aid):
					vlastni.append(aid)
	vlastni.sort()
	# Ktera id musi zustat z UO: kandidati minus to, co je ve vlastnich vrstvach.
	var cizi: Array = []
	for k in FALLBACK_KANDIDATI:
		if not vlastni.has(int(k)):
			cizi.append(int(k))
	print("[probe] vlastni_ids=", _join_cisel(vlastni))
	print("[probe] fallback_ids=", _join_cisel(cizi))

	var ma_uo: bool = FileAccess.file_exists(TextureCacheScript.MANIFEST_PATH)
	print("[probe] uo_manifest=", 1 if ma_uo else 0)
	if not ma_uo:
		print("[probe] chybi=", TextureCacheScript.MANIFEST_PATH)
		return

	# VLASTNI ZAPNUTE: cache indexuje vrstvy prvni.
	var on = TextureCacheScript.new(TextureCacheScript.MANIFEST_PATH,
		TextureCacheScript.MAX_BYTES, TextureCacheScript.ATLAS_PREFIX, vrstvy)
	# VLASTNI VYPNUTE: tyz kod, jen bez vrstev - tim se dokazuje, ze prepinac
	# opravdu prepina (kdyby vysly stejne hodnoty, seam nic neprepnul).
	var off = TextureCacheScript.new()
	var st: Dictionary = on.stats()
	print("[probe] stats_on_sprites=", int(st["sprites"]))
	print("[probe] stats_on_own=", int(st["own"]))
	print("[probe] stats_on_uo=", int(st["uo"]))
	print("[probe] stats_on_layers=", int(st["own_layers"]))
	print("[probe] stats_off_own=", int(off.stats()["own"]))
	print("[probe] own_ids=", _join_cisel(on.own_ids()))

	for art in vlastni + cizi:
		_on(on, "on", int(art))
		_on(off, "off", int(art))

	# ANIMACE: vlastni vrstva ma dnes jen chuzi (akce 0), takze beh (akce 1 ->
	# skupina 2) MUSI zustat z UO. Dokladem je cesta k PNG listu.
	var anim_on = AnimScript.new(AnimScript.MANIFEST_PATH, null, vrstvy)
	print("[probe] anim_own_count=", anim_on.own_count())
	print("[probe] anim_sprites=", anim_on.sprite_count())
	for d in 8:
		print("[probe] anim_walk_own_", d, "=", 1 if anim_on.is_own_key(400, 0, d) else 0)
	# Cislo skupiny pro akci NENI konstanta: manifest muze nest `groups` (M5) a
	# `sprite_group_for` ho bere odtud. Sonda proto u kazde akce rekne, ODKUD
	# sprite je - brana pak netvrdi "beh = UO", ale "existuje akce, ktera z vlastni
	# sady NENI a pritom se vykresli z UO" (to plati, i kdyz se mapovani zmeni).
	for a in range(5):
		print("[probe] anim_act_%d_own=" % a, 1 if anim_on.is_own_key(400, a, 0) else 0)
		print("[probe] anim_act_%d_ok=" % a, 1 if bool(anim_on.play(400, a, 0, 0)["ok"]) else 0)
		print("[probe] anim_act_%d_file=" % a, anim_on.sheet_file(400, a, 0))
	var anim_off = AnimScript.new()
	print("[probe] anim_off_own_count=", anim_off.own_count())
	print("[probe] anim_off_walk_file_0=", anim_off.sheet_file(400, 0, 0))


func _on(cache, rezim: String, art: int) -> void:
	# Stranky atlasu se nacitaji NA POZADI (`load_threaded_request`), takze prvni
	# dotaz muze vratit null. Ceka se na hotovou stranku; kdyby se nikdy
	# nenacetla, zustane "null" a brana to vidi (nula neni uspech).
	var tex: Texture2D = cache.texture(art)
	var i: int = 0
	while tex == null and i < 300:
		OS.delay_msec(10)
		cache.tick_nacteni()
		tex = cache.texture(art)
		i += 1
	var poznamka := "null" if tex == null else "tex"
	print("[probe] %s_%d=%s" % [rezim, art, poznamka])
	print("[probe] %s_page_%d=%s" % [rezim, art, cache.page_path(art)])
	print("[probe] %s_region_%d=%s" % [rezim, art, _region(tex)])
	print("[probe] %s_offset_%d=%d,%d" % [rezim, art, cache.offset(art).x, cache.offset(art).y])
	print("[probe] %s_isown_%d=%d" % [rezim, art, 1 if cache.is_own(art) else 0])


func _region(tex: Texture2D) -> String:
	if tex == null:
		return ""
	var r: Rect2 = tex.region
	return "%d,%d,%d,%d" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


func _jmena(vrstvy: Array) -> Array:
	var out: Array = []
	for v in vrstvy:
		out.append(str(v.get("name", "?")))
	return out


func _art_id(kind: String, ident: int) -> int:
	# STEJNY vzorec jako `render/texture_cache.gd._index` a `check-own-art.py:art_id`.
	# Kdyby se sem dostal jiný, sonda by se ptala na jiná id, než brana ocekava.
	if kind == "land":
		return ident
	if kind == "item":
		return ident + 0x4000
	if kind == "texmap":
		return ident + 0x10000
	return -1


func _join_cisel(seznam: Array) -> String:
	var out: Array = []
	for v in seznam:
		out.append(str(int(v)))
	return ",".join(out)
