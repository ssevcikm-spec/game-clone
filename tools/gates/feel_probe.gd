extends SceneTree
# feel_probe.gd — SONDA VAD Z REALNEHO HRANI (ZADANI-28-HRAC-2026-10-19: B1-B6).
#
# PROC TO NENI `tests/cases/*`: pet vad nasel hrac pri hrani a zadna z nich
# neni o systemech `sim/` - vsechny jsou o tom, co hrac VIDI a NA CO KLIKA:
#   B1 animace utoku, B2 animace tezby, B3 klik na KRESLENOU vyhen/kovadlinu,
#   B4 zavreni okna, B5 prekryv vendora se stanici, B6 obrazek rudy na dlazdici.
# Testy `tests/cases` kresleni vubec nespousti (bez assetu, bez sceny), takze
# tuhle tridu vady nevidi. G20 jde po dlazdicich (`_tile_predmetu`), ne po
# pixelech - proto ji klik na kresleny predmet miji (namEReno 2026-10-19).
#
# CESTA KLIENTA: sonda stavi `app/main.tscn` a pouziva TOTEZ funkce, ktere
# pouziva hra: `app.input_map.interact_command` (klavesa E/T i klik),
# `app.input_map.attack_command` (klik na nepritele) a skutecne `Button` uzly
# oken (signal `pressed`, stejne jako klik mysi) -> `sim.enqueue` -> `sim.tick`
# -> `sim.commands.dispatch`. Pro kresleni se ptá `app.world_view`
# (`animace_hrace`, `klip_mobila`, `obraz_predmetu`, `obraz_mobila`,
# `pozemske_predmety`, `co_je_na_screen`) - to jsou funkce, ktere kresleni
# OPRAVDU pouziva (jedna funkce pro kresleni i pro mereni).
#
# CO SONDA ZAMERNE ZVEDA: Mining a Blacksmithy na 1000. Meri se PRUCHODNOST
# (tezba musi uspet, aby vznikl predmet v batohu), ne balance - stejna mez
# jako `tools/gates/loop_probe.gd` a `sound_probe.gd`.
#
# CAS FRAMU: kresleni animace pouziva NASTENNY cas (`render.anim.play`), ale
# sonda bezi v jednom framu, takze by se mezi vzorky nezmenil a vsechny framy
# by vysly stejne. Vzorky proto predavaji cas SIMULACE (`animace_hrace(now)` /
# `klip_mobila(serial, now)`) - meri se tim casovani animace, ne hodiny.
#
# SNIMKY: `--snimky=<cesta>` (user args, napr. `-- --snimky=res://.tmp/beh2`).
# V headless se snimek ULOZIT NEDA; sonda to REKNE (`snimky_chyba`), nikdy
# nemlci (stejna past jako u G20).
#
# Spousteni (cisla, headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/gates/feel_probe.gd
# Se snimky (okno + opengl3):
#   godot --path . --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 \
#     --script res://tools/gates/feel_probe.gd -- --snimky=res://.tmp/beh2
#
# VYSTUP PRO BRANU: jeden radek `[feel] SOUHRN {json}` (viz `_souhrn`).

const ItemScript = preload("res://sim/entity/item.gd")
const Const = preload("res://core/const.gd")
const Iso = preload("res://core/iso.gd")

# Tezba ma `swing_ms = 1600` (sim.harvest.BANKS) = 32 tiku; 34 tiku je jedna
# "prace" s rezervou (stejna hodnota jako v `loop_probe.gd`).
const CEKANI_TIKU: int = 34
const CHCI_RUDY: int = 8
# Jeden frame animace je 80 ms (`docs/05 §5.1.1`).
const FRAME_MS: int = 80
# Art rudneho balvanu (`sim.harvest.MINE_STATIC` zacina 0x453B) - sonda ho
# neopisuje z harvestu, protoze ten se preloadovat neda (dynamicky routing).
const BALVAN_ART: int = 0x453B

var _scena = null
var _iso = null
var _f: int = 0
var _snimky_dir: String = ""
var _snimky: Array[String] = []
var _snimky_chyba: String = ""
var _vysledky: Dictionary = {}
var _monstrum: int = 0
var _duvod: String = ""
var _esc_odeslan: bool = false


func _initialize() -> void:
	_iso = Iso.new()
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--snimky="):
			_snimky_dir = str(arg).substr(len("--snimky=")).strip_edges()
	if _snimky_dir != "":
		var cil: String = ProjectSettings.globalize_path(_snimky_dir)
		var chyba: int = DirAccess.make_dir_recursive_absolute(cil)
		print("[feel] snimky do ", cil, " (mkdir ", chyba, ")")
		if chyba != OK:
			_snimky_chyba = "adresar pro snimky nejde vytvorit (%d)" % chyba
			_snimky_dir = ""
	_scena = load("res://app/main.tscn").instantiate()
	root.add_child(_scena)


func _process(_delta: float) -> bool:
	_f += 1
	if _scena == null or _scena.get("loop") == null or _scena.get("player") == null:
		# `get()` (ne primy pristup): kdyz scena nema skript (rozbite UI), kazdy
		# frame by spadl na runtime chybe a sonda by visela. Rekni to a skonci.
		if _f > 900:
			_duvod = "scena se nestavi (app/main nema loop/player)"
			_souhrn()
			quit(0)
			return true
		return false
	if _f == 40:
		_start()
	if _f == 44:
		_mereni_b5()
		_snimek("b5-vendor-u-vyhe")
	if _f == 48:
		_b1_utok_hrace()
	if _f == 50:
		_snimek("b1-utok-hrace")
		# KDE JE KDO NA OBRAZOVCE (pro rucni kontrolu snimku): klient ma na to
		# jednu funkci (`world_to_screen`), takze se snimek da overit cislem.
		var p = _scena.player
		print("[feel] obrazovka: hrac ground ",
			_scena.world_view.world_to_screen(_scena.world_view.player_ground_position()),
			" | hrac stred ",
			_scena.world_view.world_to_screen(
				_scena.world_view._iso.to_screen(int(p.pos.x), int(p.pos.y), int(p.pos.z))),
			" | kovar ", _scena.world_view.world_to_screen(
				_scena.world_view.ground_mobila(
					_scena.registry.get_mobile(int(_scena.prodejce)))),
			" | viewport ", _scena.world_view.viewport_size())
	if _f == 51:
		_snimek("b1-utok-bez-svihu")
	if _f == 52:
		_b1_utok_ciziho()
	if _f == 56:
		_b2_tezba()
	if _f == 58:
		_snimek("b2-tezba")
	if _f == 62:
		_b6_ruda()
	if _f == 64:
		_snimek("b6-ruda-na-dlazdici")
	if _f == 68:
		_b3_klik_na_stanici()
	if _f == 70:
		_snimek("b3-klik-na-kovadlinu")
	if _f == 74:
		_b4_okna()
	if _f == 76:
		_snimek("b4-okno-vendora")
	if _f == 80:
		_b4_esc()
		_snimek("b4-po-esc")
	if _f == 84:
		_souhrn()
		quit(0)
		return true
	return _f > 900


# -- infrastruktura ------------------------------------------------------------

func _z() -> int:
	return int(_scena.player.pos.z)


func _tiky(n: int) -> void:
	# Tika simulaci a predava udalosti klientu - presne to, co dela `app.loop`.
	for _i in n:
		_scena.sim.tick(Const.TICK_MS)
	_scena.loop._deliver_events()


func _doruc() -> void:
	# Preda udalosti klientu BEZ tiku (zurnal, okna). Tik posouva sim cas, a ten
	# by zavrel prezentacni okno, ktere jeste potrebujeme na snimek.
	_scena.loop._deliver_events()


func _cas() -> int:
	return int(_scena.sim.world_time())


func _screen_of_svet(svet: Vector2) -> Vector2:
	# Inverz k `app.input_map._na_svet` (`world = screen / zoom + offset`).
	return (svet - _scena.loop.camera_offset) * float(_scena.loop.input_map.zoom)


func _interact_na_screen(screen: Vector2) -> Dictionary:
	# PRIKAZ VYTVARI KLIENT (stejna cesta jako klavesa E/T nebo klik).
	var prikaz: Dictionary = _scena.loop.input_map.interact_command(
		screen, _scena.loop.camera_offset, _z())
	if not prikaz.is_empty():
		_scena.sim.enqueue(prikaz)
	return prikaz


func _diagnostika_screen(screen: Vector2) -> Dictionary:
	# CO JE POD KURZOREM (pro mereni hit-testu): svetova souradnice, geometricka
	# dlazdice a vysledek hit-testu klienta (`app/world_view.co_je_na_screen`).
	var zoom: float = float(_scena.loop.input_map.zoom)
	var world: Vector2 = screen / (zoom if zoom > 0.0 else 1.0) + _scena.loop.camera_offset
	var tile: Vector2i = _iso.to_tile(world.x, world.y, _z())
	var hit = _scena.world_view.co_je_na_screen(world, _z()) if _scena.world_view != null else {}
	# VSECHNO, co ten bod obsahuje (i to, co hit-test nevrati) - bez toho by
	# se "proc klik sel jinam" hadalo.
	var vse: Array = []
	for p in _scena.world_view.pozemske_predmety():
		if bool(p["kresli_se"]) and (p["rect"] as Rect2).has_point(world):
			vse.append("predmet %d art %d tile %s amount %d" % [int(p["serial"]),
				int(p["art"]), str(p["tile"]), int(p["amount"])])
	for mob in _scena.registry.all():
		var o: Dictionary = _scena.world_view.obraz_mobila(int(mob.serial))
		if bool(o.get("ok", false)) and (o["rect"] as Rect2).has_point(world):
			vse.append("mobil %d (%s) tile %s" % [int(mob.serial), str(mob.name),
				str(Vector2i(int(mob.pos.x), int(mob.pos.y)))])
	return {"svet": str(world), "geo_tile": str(tile), "hit": str(hit),
		"zoom": zoom, "camera": str(_scena.loop.camera_offset), "vse": vse}


func _interact_na_dlazdici(tile: Vector2i) -> Dictionary:
	# Klik na STŘED DLAZDICE (puvodni cesta G20: `_mireni` pocita stred
	# dlazdice). Tady je to KALIBRACE: kdyz tenhle klik projde a klik na
	# kresleny predmet ne, vada je v hit-testu, ne v interakci.
	var svet: Vector2 = _iso.to_screen(tile.x, tile.y, _z())
	return _interact_na_screen(_screen_of_svet(svet))


func _interact_na_obrazek(serial: int) -> Dictionary:
	# Klik doprostred KRESLENEHO predmetu (to, co hrac vidi).
	var obraz: Dictionary = _scena.world_view.obraz_predmetu(serial)
	if not bool(obraz.get("ok", false)):
		return {"chyba": "predmet %d nema kresleny obraz (%s)"
			% [serial, str(obraz.get("duvod", ""))]}
	var rect: Rect2 = obraz["rect"]
	return _interact_na_screen(_screen_of_svet(rect.get_center()))


func _predmet_role(role: String) -> int:
	# Serial pozemskeho predmetu podle ROLE z dat (kovadlina/vyhen).
	for serial in _scena.items.keys():
		var it = _scena.items[serial]
		if it != null and it.ve_svete() and ItemScript.role_of(int(it.tile)) == role:
			return int(serial)
	return 0


func _balvan_serial() -> int:
	# Serial RUDNEHO BALVANU: art z `sim.harvest.MINE_STATIC` a `ve_svete()`.
	# Vybere se ten NEJDAL od prodavace: jeho jmenovka a HP pruh jinak na snimku
	# prekryje dlazdici, na ktere se tezi, a snimek B6 by nic neukazal.
	var kandidati: Array = []
	for serial in _scena.items.keys():
		var it = _scena.items[serial]
		if it != null and it.ve_svete() and int(it.tile) == BALVAN_ART:
			kandidati.append(int(serial))
	if kandidati.is_empty():
		return 0
	var kovar_pos := Vector3i.ZERO
	if int(_scena.prodejce) > 0 and _scena.registry != null:
		var kovar = _scena.registry.get_mobile(int(_scena.prodejce))
		if kovar != null:
			kovar_pos = kovar.pos
	var nej: int = 0
	var nej_d: int = -1
	for serial in kandidati:
		var it = _scena.items[serial]
		var d: int = maxi(absi(int(it.pos.x) - int(kovar_pos.x)),
			absi(int(it.pos.y) - int(kovar_pos.y)))
		if d > nej_d:
			nej_d = d
			nej = int(serial)
	return nej


func _v_batohu(typ: String) -> int:
	var soucet: int = 0
	for serial in _scena.container.contents(int(_scena.player.backpack)):
		var it = _scena.items.get(int(serial))
		if it != null and ItemScript.type_of(int(it.tile)) == typ:
			soucet += int(it.amount)
	return soucet


func _zurnal_pocet() -> int:
	return int(_scena.journal.message_count())


func _zurnal_nove(od: int) -> Array:
	var out: Array = []
	var radky: Array = _scena.journal.lines()
	for i in range(od, radky.size()):
		out.append(str(radky[i].get("text", "")))
	return out


func _bez_textury(d: Dictionary) -> Dictionary:
	# Kopie bez TEXTURY (Texture2D se neda serializovat do JSONu) - jinak by
	# `JSON.stringify` selhal a sonda by o vysledku nic nerekla.
	var out: Dictionary = {}
	for k in d.keys():
		if str(k) == "clip" and d[k] is Dictionary:
			var cc: Dictionary = {}
			for kk in (d[k] as Dictionary).keys():
				if str(kk) == "texture" or str(kk) == "anchor":
					continue
				cc[kk] = (d[k] as Dictionary)[kk]
			out["clip"] = cc
		elif d[k] is Vector2 or d[k] is Vector2i or d[k] is Rect2:
			out[k] = str(d[k])
		elif d[k] is Dictionary:
			out[k] = _bez_textury(d[k])
		elif d[k] is Array:
			var pole: Array = []
			for x in (d[k] as Array):
				pole.append(str(x) if x is Rect2 else x)
			out[k] = pole
		else:
			out[k] = d[k]
	return out


func _tlacitka(uzel: Node, out: Array) -> Array:
	for child in uzel.get_children():
		if child is Button:
			out.append(child)
		_tlacitka(child, out)
	return out


func _najdi_tlacitko(okno: Node, jmeno: String = "", text: String = "") -> Button:
	for t in _tlacitka(okno, []):
		if jmeno != "" and str(t.name) == jmeno:
			return t
		if text != "" and str(t.text) == text:
			return t
	return null


func _signal_pripojen(tlacitko: Button) -> bool:
	for zaznam in tlacitko.get_signal_connection_list("pressed"):
		if zaznam is Dictionary and (zaznam.get("callable", Callable()) as Callable).is_valid():
			return true
	return false


func _stiskni(tlacitko: Button) -> bool:
	# VYSLANI SIGNALU, ne volani handleru: presne to, co udela skutecny klik.
	tlacitko.pressed.emit()
	return true


# -- start: co je ve scene -----------------------------------------------------

func _start() -> void:
	var p = _scena.player
	print("[feel] hrac serial ", int(p.serial), " telo ", int(p.body), " na ",
		p.pos, " smer ", int(p.dir))
	_scena.player.skills.set_value(45, 1000)   # Mining
	_scena.player.skills.set_value(7, 1000)    # Blacksmithy
	# ZOOM 2x: snimky maji ukazat DETAIL (animaci a svih), ne celou obrazovku.
	# Mereni se to netyka - vsechno se pocita ve SVETOVYCH souradnicich
	# (`screen_of_svet` deli zoomem), takze se cisla pri zoomu nemeni.
	if _scena.world_view != null and _scena.world_view.has_method("nastav_zoom"):
		_scena.world_view.nastav_zoom(2.0)
		print("[feel] zoom pro snimky: 2.0")
	print("[feel] skilly: Mining ", _scena.player.skills.value(45),
		", Blacksmithy ", _scena.player.skills.value(7))
	for serial in _scena.items.keys():
		var it = _scena.items[serial]
		if it != null and it.ve_svete():
			var role: String = ItemScript.role_of(int(it.tile))
			if role in ["forge", "anvil"]:
				print("[feel] stanice ", role, " serial ", int(serial), " art ",
					int(it.tile), " na ", it.pos)
	if int(_scena.prodejce) > 0 and _scena.registry != null:
		var kovar = _scena.registry.get_mobile(int(_scena.prodejce))
		if kovar != null:
			print("[feel] prodejce serial ", int(_scena.prodejce), " na ", kovar.pos)
	print("[feel] balvany: ", _scena.balvany)
	for mob in _scena.registry.all():
		if int(mob.serial) == int(p.serial) or int(mob.serial) == int(_scena.prodejce):
			continue
		if int(mob.hp) <= 0:
			continue
		if _monstrum == 0:
			_monstrum = int(mob.serial)
			print("[feel] monstrum serial ", _monstrum, " telo ", int(mob.body),
				" na ", mob.pos)
	if _monstrum == 0:
		_duvod = "ve scene neni zadne monstrum (B1 ciziho utoku se neda merit)"


# -- B5: prodejce nesmi stat na stanici a nesmi ji prekryvat -------------------

func _tile_of(serial: int) -> Vector2i:
	if serial <= 0:
		return Vector2i(-9999, -9999)
	var it = _scena.items.get(int(serial))
	if it == null:
		return Vector2i(-9999, -9999)
	return Vector2i(int(it.pos.x), int(it.pos.y))


func _mereni_b5() -> void:
	var vyhen: int = _predmet_role("forge")
	var kovadlina: int = _predmet_role("anvil")
	var m: Dictionary = {"vyhen": vyhen, "kovadlina": kovadlina}
	m["vyhen_tile"] = str(_tile_of(vyhen))
	m["kovadlina_tile"] = str(_tile_of(kovadlina))
	var kovar_tile := Vector2i(-9999, -9999)
	if int(_scena.prodejce) > 0 and _scena.registry != null:
		var kovar = _scena.registry.get_mobile(int(_scena.prodejce))
		if kovar != null:
			kovar_tile = Vector2i(int(kovar.pos.x), int(kovar.pos.y))
	m["prodejce_tile"] = str(kovar_tile)
	# (1) DLAZDICE: prodejce nesmi byt na zadne stanici ani na uzlu suroviny.
	var kolize: Array = _scena._zkontroluj_cile_interakce()
	m["kolize_cilu"] = kolize.size()
	m["kolize"] = kolize
	m["prodejce_na_stanici"] = kovar_tile == _tile_of(vyhen) or kovar_tile == _tile_of(kovadlina)
	# (2) OBRAZ: kresleny obdelnik prodejce vs. kresleny obdelnik stanic.
	var o_kovar: Dictionary = _scena.world_view.obraz_mobila(int(_scena.prodejce))
	var o_vyhen: Dictionary = _scena.world_view.obraz_predmetu(vyhen)
	var o_kovadlina: Dictionary = _scena.world_view.obraz_predmetu(kovadlina)
	for par in [["vyhen", o_vyhen], ["kovadlina", o_kovadlina]]:
		var o: Dictionary = par[1]
		var klic: String = "prekryv_" + str(par[0])
		if bool(o_kovar.get("ok", false)) and bool(o.get("ok", false)):
			var prusecik: Rect2 = (o_kovar["rect"] as Rect2).intersection(o["rect"] as Rect2)
			m[klic + "_px"] = int(prusecik.size.x * prusecik.size.y)
			m[klic] = prusecik.size.x > 0.0 and prusecik.size.y > 0.0
		else:
			m[klic + "_px"] = -1        # NEMERENO, ne "nula"
			m[klic] = false
	m["kovar_rect"] = str(o_kovar.get("rect", Rect2()))
	m["vyhen_rect"] = str(o_vyhen.get("rect", Rect2()))
	m["kovadlina_rect"] = str(o_kovadlina.get("rect", Rect2()))
	_vysledky["B5"] = m
	print("[feel] B5 dlazdice: ", JSON.stringify(m))


# -- vzorkovani kresleneho klipu v case ---------------------------------------

func _vzorky(n: int, hrac: bool, serial: int = 0, ocekavana_akce: int = -1) -> Dictionary:
	# Vzorky kresleneho klipu po 80 ms (jeden frame animace). Sonda bezi v
	# jednom framu, takze cas se predava VSTUPEM - jinak by vsechny vzorky
	# vysly stejne (nastenny cas se mezi nimi nezmeni).
	# Zaklad je NASTENNY cas, protoze ten pouziva i kresleni (`_draw_player`
	# vola `_klip` bez casu) - sim cas by proti nemu vysel zaporny a vsechny
	# vzorky by spadly na frame 0 (namEReno).
	var zaklad: int = Time.get_ticks_msec()
	var out: Array = []
	for i in n:
		var t: int = zaklad + i * FRAME_MS
		var k: Dictionary = _scena.world_view.animace_hrace(t) if hrac \
			else _scena.world_view.klip_mobila(int(serial), t)
		var clip: Dictionary = k.get("clip", {})
		var svih: Dictionary = k.get("svih", {})
		out.append({"ok": bool(k.get("ok", false)), "akce": int(k.get("action", -1)),
			"frame": int(clip.get("frame", -1)), "framu": int(clip.get("count", 0)),
			"svih_kusu": (svih.get("kusu", []) as Array).size(),
			"svih": bool(svih.get("kresli", false))})
		# ⚠ ZAMERNE SE NETIKUJE: prezentacni okno (utok 400 ms, prace 1600 ms)
		# musi zustat OTEVRENE i pro snimek, ktery se dela po mereni. Cas framu
		# jde VSTUPEM (`now_ms`), takze se framy vystridaji i bez tiku - a obraz
		# zustane ve stavu, ktery hrac opravdu vidi.
	var akce: Dictionary = {}
	var framy: Dictionary = {}
	for v in out:
		if ocekavana_akce >= 0 and int(v["akce"]) != ocekavana_akce:
			continue
		akce[int(v["akce"])] = true
		framy[int(v["frame"])] = true
	var svih_kusu: Array = []
	for v in out:
		svih_kusu.append(int(v["svih_kusu"]))
	return {"vzorky": out, "ruznych_akci": akce.size(), "ruznych_framu": framy.size(),
		"svih_kusu": svih_kusu, "svih_max": svih_kusu.max() if not svih_kusu.is_empty() else 0}


# -- B1: animace utoku hrace i cizich postav ----------------------------------

func _b1_utok_hrace() -> void:
	var m: Dictionary = {}
	var p = _scena.player
	# MONSTRUM VEDLE HRACE: aby utok prosel kontrolou dosahu. Je to priprava
	# SCENY (ne herni pravidlo) - stejna trida zasahu jako zvyseni skillu.
	if _monstrum > 0:
		var mob = _scena.registry.get_mobile(int(_monstrum))
		if mob != null:
			mob.pos = Vector3i(int(p.pos.x) - 1, int(p.pos.y), int(p.pos.z))
	var screen: Vector2 = _screen_of_svet(_iso.to_screen(
		int(p.pos.x) - 1, int(p.pos.y), _z()))
	var prikaz: Dictionary = _scena.loop.input_map.attack_command(
		Vector2i(int(p.pos.x), int(p.pos.y)), screen, _scena.loop.camera_offset, _z())
	m["prikaz"] = str(prikaz)
	if not prikaz.is_empty():
		_scena.sim.enqueue(prikaz)
	_tiky(2)
	var anim: Dictionary = _scena.combat.anim_of(int(p.serial)) if _scena.combat != null else {}
	m["anim_of"] = str(anim)
	var hrac: Dictionary = _scena.world_view.animace_hrace()
	m["hrac"] = _bez_textury(hrac)
	m["ok_hrac"] = bool(hrac.get("ok", false)) and not anim.is_empty()
	# DVA FRAMY: vzorky po 80 ms - kdyz se behem okna utoku nezmeni frame,
	# animace NENI. Svih (kresleny oblouk) se meri taky.
	m["vzorky"] = _vzorky(8, true, 0, 2)
	m["ok"] = bool(m["ok_hrac"]) and int(m["vzorky"]["ruznych_framu"]) >= 2 \
		and int(m["vzorky"]["svih_max"]) > 0
	print("[feel] B1 utok hrace: anim_of ", anim, " | kresleni ", JSON.stringify(m["hrac"]))
	print("[feel] B1 utok hrace: vzorky frames=", m["vzorky"]["ruznych_framu"],
		" svih_max=", m["vzorky"]["svih_max"], " ok=", m["ok"])
	# KDE SE SVIH KRESLI (pro snímek a pro rucni kontrolu): zemni linka hrace
	# a obdelniky svihu prevedene na OBRAZOVKU.
	var zem: Vector2 = _scena.world_view.player_ground_position()
	var klip: Dictionary = _scena.world_view.animace_hrace()
	var svih: Dictionary = klip.get("svih", {})
	var na_obrazovce: Array = []
	for kus in (svih.get("kusu", []) as Array):
		var r: Rect2 = kus
		na_obrazovce.append(str(_screen_of_svet(zem + r.position)))
	print("[feel] B1 svih na obrazovce: ", na_obrazovce, " (zem ", _screen_of_svet(zem), ")")
	m["svih_na_obrazovce"] = na_obrazovce
	m["svih_zem_screen"] = str(_screen_of_svet(zem))
	# SNIMEK CHCE PROSTŘEDEK SVIHU (ne jeho zacatek): sonda po mereni posune
	# sim cas o 200 ms, aby na snimku byl videt cely oblouk, ne 3 ctverecky.
	_tiky(4)
	_doruc()
	_vysledky["B1_hrac"] = m


func _b1_utok_ciziho() -> void:
	var m: Dictionary = {"serial": _monstrum}
	if _monstrum <= 0:
		_vysledky["B1_cizi"] = {"ok": false, "duvod": "zadne monstrum"}
		return
	# Monstrum utoci samo (AI) - cekame, az na nem `sim.combat.anim_of` neco
	# vrati, a pak zmerime, co se kresli.
	var anim: Dictionary = {}
	var cekano: int = 0
	for _i in 120:
		_tiky(2)
		cekano += 2
		anim = _scena.combat.anim_of(int(_monstrum)) if _scena.combat != null else {}
		if not anim.is_empty():
			break
	m["cekanych_tiku"] = cekano
	m["anim_of"] = str(anim)
	var klip: Dictionary = _scena.world_view.klip_mobila(int(_monstrum))
	m["klip"] = _bez_textury(klip)
	m["ok"] = (not anim.is_empty()) and bool(klip.get("ok", false))
	var vzorky: Dictionary = _vzorky(6, false, _monstrum, 2)
	m["vzorky"] = vzorky
	m["ok"] = bool(m["ok"]) and int(vzorky["ruznych_framu"]) >= 2
	print("[feel] B1 utok ciziho: anim_of ", anim, " | kresleni ", JSON.stringify(m["klip"]))
	print("[feel] B1 utok ciziho: vzorky frames=", vzorky["ruznych_framu"],
		" svih_max=", vzorky["svih_max"], " ok=", m["ok"])
	_vysledky["B1_cizi"] = m


# -- B2: pracovni animace pri tezbe -------------------------------------------

func _b2_tezba() -> void:
	var m: Dictionary = {}
	m["harvest_anim_of"] = _scena.harvest.has_method("anim_of") if _scena.harvest != null else false
	var balvan: int = _balvan_serial()
	m["balvan_serial"] = balvan
	if balvan <= 0:
		m["ok"] = false
		m["duvod"] = "ve scene neni rudny balvan (art %d)" % BALVAN_ART
		_vysledky["B2"] = m
		print("[feel] B2: ", JSON.stringify(m))
		return
	var ruda_pred: int = _v_batohu("iron_ore")
	var zurnal_pred: int = _zurnal_pocet()
	# KLIK NA KRESLENY BALVAN (cesta hrace), ne na stred dlazdice.
	var prikaz: Dictionary = _interact_na_obrazek(balvan)
	m["prikaz"] = str(prikaz)
	m["ruda_pred"] = ruda_pred
	# Prikaz vyridi SIM az v tiku - 2 tiky ho dispatchnou a okno prace
	# (1600 ms) zustane otevrene i pro vzorky a snimek.
	_tiky(2)
	_doruc()
	# PRACOVNI OKNO: tezba ma `swing_ms = 1600` = 20 framu po 80 ms.
	m["vzorky"] = _vzorky(10, true, 0, 5)
	m["ruda_po"] = _v_batohu("iron_ore")
	m["zurnal_nove"] = _zurnal_nove(zurnal_pred).slice(0, 6)
	m["pracovni_akce"] = int(m["vzorky"]["ruznych_framu"]) >= 2
	m["ok"] = bool(m["harvest_anim_of"]) and bool(m["pracovni_akce"]) \
		and int(m["vzorky"]["svih_max"]) > 0
	print("[feel] B2 tezba: ", JSON.stringify(m))
	_vysledky["B2"] = m


# -- B6: zustane po tezbe nechteny obrazek na dlazdici? ----------------------

func _b6_ruda() -> void:
	var m: Dictionary = {}
	m["ruda_pred"] = _v_batohu("iron_ore")
	m["pozemskych_pred"] = (_scena.world_view.pozemske_predmety() as Array).size()
	# TEZBA DO HROMADY: prvni uspech zalozi hromadu, druhy uz jen slouci -
	# a presne pri slouceni vznikne "spotrebovany" objekt (`amount == 0`,
	# `parent == 0`), ktery se do 2026-10-19 kreslil na dlazdici zdroje.
	var balvan: int = _balvan_serial()
	var pokusu: int = 0
	while pokusu < 6 and _v_batohu("iron_ore") < CHCI_RUDY and balvan > 0:
		_interact_na_obrazek(balvan)
		_tiky(CEKANI_TIKU)
		pokusu += 1
	m["ruda_po"] = _v_batohu("iron_ore")
	m["pokusu"] = pokusu
	# ZALOHA PRO MERENI: kdyz klik na KRESLENY balvan nic neprinesl (to je vada
	# B3, ne B6), zkusi se jeste STŘED DLAZDICE - jinak by B6 měřila "0 zůstatků"
	# nad tím, že se vůbec netěžilo, což není důkaz. `tezba_klikem_na_obraz`
	# proto zůstává v JSONu: je vidět, kterou cestou se těžilo.
	m["tezba_klikem_na_obraz"] = int(m["ruda_po"]) > int(m["ruda_pred"])
	if not bool(m["tezba_klikem_na_obraz"]) and balvan > 0:
		var dalsi: int = 0
		while dalsi < 6 and _v_batohu("iron_ore") < CHCI_RUDY:
			_interact_na_dlazdici(_tile_of(balvan))
			_tiky(CEKANI_TIKU)
			dalsi += 1
		m["pokusu_dlazdici"] = dalsi
		m["ruda_po"] = _v_batohu("iron_ore")
	# (1) CO SE KRESLI NA ZEMI (to, co hrac vidi).
	var pozemske: Array = _scena.world_view.pozemske_predmety()
	var rudy: Array = []
	var zbytky: Array = []
	for p in pozemske:
		var typ: String = ItemScript.type_of(int(p["art"]))
		if typ == "iron_ore":
			rudy.append({"serial": int(p["serial"]), "amount": int(p["amount"]),
				"tile": str(p["tile"]), "kresli_se": bool(p["kresli_se"])})
		if int(p["amount"]) <= 0:
			zbytky.append({"serial": int(p["serial"]), "art": int(p["art"]),
				"typ": typ, "amount": int(p["amount"]), "tile": str(p["tile"]),
				"kresli_se": bool(p["kresli_se"])})
	m["pozemskych_po"] = pozemske.size()
	m["ruda_na_zemi_pocet"] = rudy.size()
	m["ruda_na_zemi"] = rudy
	m["zbytky_pocet"] = zbytky.size()
	m["zbytky_na_zemi"] = zbytky
	# (2) ZDROJ VADY: zustaly v registru predmetu "spotrebovane" objekty?
	# Tohle meri PRODUCENTA (`sim.harvest._give`), ne jen kresleni.
	var zbytky_v_itemech: Array = []
	for serial in _scena.items.keys():
		var it = _scena.items[serial]
		if it != null and int(it.parent) == 0 and int(it.amount) <= 0:
			zbytky_v_itemech.append({"serial": int(serial), "art": int(it.tile),
				"tile": str(Vector2i(int(it.pos.x), int(it.pos.y)))})
	m["zbytky_v_itemech_pocet"] = zbytky_v_itemech.size()
	m["zbytky_v_itemech"] = zbytky_v_itemech.slice(0, 6)
	m["ok"] = rudy.is_empty() and zbytky.is_empty() and zbytky_v_itemech.is_empty()
	print("[feel] B6 ruda na zemi: ", JSON.stringify(m))
	_vysledky["B6"] = m


# -- B3: klik na KRESLENOU stanici --------------------------------------------

func _b3_klik_na_stanici() -> void:
	var m: Dictionary = {}
	var kovadlina: int = _predmet_role("anvil")
	var vyhen: int = _predmet_role("forge")
	m["kovadlina_serial"] = kovadlina
	m["vyhen_serial"] = vyhen
	m["kovadlina_tile"] = "%d,%d" % [_tile_of(kovadlina).x, _tile_of(kovadlina).y]
	m["vyhen_tile"] = "%d,%d" % [_tile_of(vyhen).x, _tile_of(vyhen).y]
	if _scena.craft_gump.has_method("zavri") and bool(_scena.craft_gump.je_otevreny()):
		_scena.craft_gump.zavri()
	var zurnal: int = _zurnal_pocet()
	# (1) KOVADLINA: klik doprostred kresleneho predmetu -> ma se otevrit okno
	# vyroby (v batohu je "smith hammer").
	var obraz: Dictionary = _scena.world_view.obraz_predmetu(kovadlina)
	m["kovadlina_rect"] = str(obraz.get("rect", Rect2()))
	var prikaz_obraz: Dictionary = _interact_na_obrazek(kovadlina)
	m["prikaz_obraz"] = str(prikaz_obraz)
	m["tile_obraz"] = str((prikaz_obraz.get("target", {}) as Dictionary).get("x")) + "," \
		+ str((prikaz_obraz.get("target", {}) as Dictionary).get("y"))
	_tiky(4)
	_scena.craft_gump.flush()
	m["okno_po_kliku_na_obraz"] = bool(_scena.craft_gump.je_otevreny())
	m["zurnal_po_obraz"] = _zurnal_nove(zurnal)
	# Okno vyroby: ma cestu zavrit? (B4 meri okno obchodu, tohle je druhe okno.)
	m["craft_api_zavri"] = _scena.craft_gump.has_method("zavri")
	m["craft_tlacitko_close"] = _najdi_tlacitko(_scena.craft_gump,
		"Zavrit", "") != null
	if _scena.craft_gump.has_method("zavri"):
		_scena.craft_gump.zavri()
	else:
		_scena.craft_gump.visible = false
	_scena.craft_gump.flush()
	# (2) KALIBRACE: klik na stred dlazdice (cesta, kterou chodi G20).
	zurnal = _zurnal_pocet()
	var prikaz_tile: Dictionary = _interact_na_dlazdici(_tile_of(kovadlina))
	m["prikaz_tile"] = str(prikaz_tile)
	_tiky(4)
	_scena.craft_gump.flush()
	m["okno_po_kliku_na_dlazdici"] = bool(_scena.craft_gump.je_otevreny())
	if _scena.craft_gump.has_method("zavri"):
		_scena.craft_gump.zavri()
	else:
		_scena.craft_gump.visible = false
	_scena.craft_gump.flush()
	# (3) VYHEN s rudou v batohu: klik na kresleny predmet -> ma se vytavit.
	# OVESUJE SE I PRODAVAC V BLIZKOSTI (hracuv dotek: "vendor stoji na vyhni,
	# nedaří se mi interagovat ani s vyhni").
	zurnal = _zurnal_pocet()
	m["ingot_pred"] = _v_batohu("iron_ingot")
	m["ruda_pred"] = _v_batohu("iron_ore")
	var prikaz_vyhen: Dictionary = _interact_na_obrazek(vyhen)
	m["prikaz_vyhen"] = str(prikaz_vyhen)
	m["tile_vyhen"] = str((prikaz_vyhen.get("target", {}) as Dictionary).get("x")) + "," \
		+ str((prikaz_vyhen.get("target", {}) as Dictionary).get("y"))
	_tiky(6)
	m["ingot_po"] = _v_batohu("iron_ingot")
	m["zurnal_po_vyhni"] = _zurnal_nove(zurnal)
	m["vendor_gump_po_vyhni"] = bool(_scena.vendor_gump.je_otevreny())
	m["vytaveno"] = int(m["ingot_po"]) > int(m["ingot_pred"])
	m["ok"] = bool(m["okno_po_kliku_na_obraz"]) and bool(m["vytaveno"]) \
		and bool(m["craft_api_zavri"]) and bool(m["craft_tlacitko_close"])
	print("[feel] B3 klik na stanici: ", JSON.stringify(m))
	_vysledky["B3"] = m


# -- B4: zavreni oken ----------------------------------------------------------

func _b4_okna() -> void:
	var m: Dictionary = {}
	var kovar_tile := Vector2i(-9999, -9999)
	if int(_scena.prodejce) > 0 and _scena.registry != null:
		var kovar = _scena.registry.get_mobile(int(_scena.prodejce))
		if kovar != null:
			kovar_tile = Vector2i(int(kovar.pos.x), int(kovar.pos.y))
	m["prodejce_tile"] = str(kovar_tile)
	# CISTA DIAGNOSTIKA: co je pod stredem dlazdice prodejce (hit-test klienta).
	m["diag"] = _diagnostika_screen(_screen_of_svet(_iso.to_screen(
		kovar_tile.x, kovar_tile.y, _z())))
	var prikaz: Dictionary = _interact_na_dlazdici(kovar_tile)
	m["prikaz"] = str(prikaz)
	_tiky(4)
	_scena.vendor_gump.flush()
	m["okno_otevrene"] = bool(_scena.vendor_gump.je_otevreny())
	m["api_zavri"] = _scena.vendor_gump.has_method("zavri")
	m["api_toggle"] = _scena.vendor_gump.has_method("toggle")
	var texts: Array = []
	for t in _tlacitka(_scena.vendor_gump, []):
		texts.append(str(t.text))
	m["tlacitek"] = texts.size()
	m["tlacitko_close"] = texts.has("Close")
	# (1) TLACITKO "Close" -> okno se zavre (signal, jako klik mysi).
	var zavrit: Button = _najdi_tlacitko(_scena.vendor_gump, "Zavrit", "")
	m["tlacitko_zavrit_uzel"] = zavrit != null
	m["signal_zavrit"] = _signal_pripojen(zavrit) if zavrit != null else false
	if zavrit != null and bool(m["signal_zavrit"]):
		_stiskni(zavrit)
	m["zavreno_klikem"] = not bool(_scena.vendor_gump.je_otevreny())
	m["videt_po_zavreni"] = bool(_scena.vendor_gump.visible)
	# (2) ZAVRENE OKNO NEPRIJIMA VSTUPY: klik na prepinac smeru nic neudela.
	var smer_btn: Button = _najdi_tlacitko(_scena.vendor_gump, "Smer", "")
	var smer_pred: String = str(_scena.vendor_gump.smer())
	if smer_btn != null:
		_stiskni(smer_btn)
	m["smer_po_zavreni"] = str(_scena.vendor_gump.smer())
	m["vstup_odmitnut"] = str(m["smer_po_zavreni"]) == smer_pred \
		and (_scena.vendor_gump.odeber_pozadavek() as Dictionary).is_empty()
	# (3) ZNOVU OTEVRIT: `interact` na prodejce (cesta klienta).
	_interact_na_dlazdici(kovar_tile)
	_tiky(4)
	_scena.vendor_gump.flush()
	m["znovu_otevreno"] = bool(_scena.vendor_gump.je_otevreny())
	m["ok"] = bool(m["api_zavri"]) and bool(m["tlacitko_close"]) \
		and bool(m["signal_zavrit"]) and bool(m["zavreno_klikem"]) \
		and not bool(m["videt_po_zavreni"]) and bool(m["vstup_odmitnut"]) \
		and bool(m["znovu_otevreno"])
	print("[feel] B4 okna: ", JSON.stringify(m))
	_vysledky["B4"] = m


func _b4_esc() -> void:
	# KLAVESA: Escape (`ui_cancel`) - skutecna UDALOST, ne prime volani.
	# Sonda ji posle do enginu jako klavesnici; `app.main._unhandled_input` ji
	# ma zavrit okno. Kdyz udalost v headless nedojde, sonda to REKNE a zmeri
	# aspon to, ze klavesa je v `InputMap` a ze `_zavri_okna()` funguje.
	var m: Dictionary = {"pred": bool(_scena.vendor_gump.je_otevreny())}
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	var mapa_ma: bool = InputMap.has_action("ui_cancel") \
		and InputMap.action_has_event("ui_cancel", esc)
	m["ui_cancel_v_inputmap"] = mapa_ma
	if not _esc_odeslan:
		_esc_odeslan = true
		# `root.push_input` (Viewport) je cesta, kterou chodi skutecna klavesnice
		# z okna - `Input.parse_input_event` se v headless nedorucuje do
		# `_unhandled_input` (namEReno 2026-10-19).
		root.push_input(esc)
		m["odeslano"] = true
	else:
		m["odeslano"] = false
	var po_udalosti: bool = bool(_scena.vendor_gump.je_otevreny())
	m["po_udalosti_otevreno"] = po_udalosti
	# Zaloha (pojmenovana, ne ticha): prime volani klienta, kdyz udalost
	# v headless nedorazila. Meri se tim aspon to, ze cesta existuje.
	m["zavreno_volanim"] = 0
	if po_udalosti:
		m["zavreno_volanim"] = int(_scena._zavri_okna())
		m["po_volani_otevreno"] = bool(_scena.vendor_gump.je_otevreny())
	else:
		m["po_volani_otevreno"] = false
	m["ok"] = mapa_ma and not bool(m["po_volani_otevreno"])
	print("[feel] B4 esc: ", JSON.stringify(m))
	_vysledky["B4_esc"] = m


# -- snimky a souhrn -----------------------------------------------------------

func _snimek(jmeno: String) -> void:
	if _snimky_dir == "":
		return
	var obraz: Image = root.get_texture().get_image() if root.get_texture() != null else null
	if obraz == null:
		if _snimky_chyba == "":
			_snimky_chyba = "viewport nema obraz (headless) - snimky nelze poridit"
		return
	var cesta: String = _snimky_dir.path_join(jmeno + ".png")
	var chyba: int = obraz.save_png(cesta)
	if chyba != OK:
		_snimky_chyba = "save_png(%s) = %d" % [cesta, chyba]
		return
	_snimky.append(cesta)
	print("[feel] snimek ", cesta, " (", obraz.get_width(), "x", obraz.get_height(), ")")


func _souhrn() -> void:
	var chyby: Array = []
	for k in ["B1_hrac", "B1_cizi", "B2", "B3", "B4", "B4_esc", "B5", "B6"]:
		if not _vysledky.has(k):
			chyby.append("NEMERENO: " + k)
	var souhrn: Dictionary = {
		"vysledky": _vysledky,
		"snimky": _snimky,
		"snimky_chyba": _snimky_chyba,
		"snimky_zadany": _snimky_dir != "",
		"nemerene": chyby,
		"duvod": _duvod,
	}
	print("[feel] SOUHRN ", JSON.stringify(souhrn))
	if not chyby.is_empty():
		print("[feel] POZOR: ", ", ".join(PackedStringArray(chyby)))
