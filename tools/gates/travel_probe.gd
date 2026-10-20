extends SceneTree
# travel_probe.gd - DUVAZ pro branu G22 (DEBUG TELEPORT MEZI TESTOVACIMI BODY).
#
# PROC TAKHLE: `tests/cases/ui_debug_travel.gd` meri VALIDACI DAT a TELEPORT
# FUNKCI bez sceny (stub controller). To, co ma hrac opravdu videt, se tak
# zmerit NEDA: jestli je bod na MAPE, jestli ho kamera nasleduje a jestli se po
# skoku da dal hrat - to vi jen ZIVA scena. Sonda proto spusti REALNOU scenu
# (`app/main.tscn`) a meri:
#   1. DATA: kazdy bod z `data/test-points.json` (cteny modulem, ktery je pouziva
#      hra) - vyska povrchu (`walk.surface_z`) == `z` v datech, dlazdice je na
#      mape a ze bodu jde aspon 3 smery (`walk.can_step`),
#   2. DOSAH: od bodu je to, kvuli cemuz tam hrac jde, na skutecne vzdalenosti
#      ze systemu (kovadlina/vyhen `craft.STATION_RANGE`, prodejce
#      `vendor.VENDOR_RANGE`, balvan `harvest.BANKS["ore"].range`, monstrum
#      `input_map.ATTACK_RANGE`),
#   3. TELEPORT: `debug_travel.teleport(i)` nastavi pozici PRESNE na bod a
#      KAMERA ho nasleduje (`world_view.center_tile`, `loop.player_tile/z`),
#   4. PANEL: `F7` seznam otevre i zavre, `Esc` ho zavre, cislo 1-9 na bod skoci
#      (vsechno REALNYMI klavesami pres `Input.parse_input_event`, jako hrac),
#   5. PO SKOKU SE DA DAL HRAT: sim tickuje a hrac na stisknuti sipky udela krok.
#
# Vystup (cte ho `tools/gates/check-travel.py`):
#   [travel] MERENI: klic=hodnota, ...
#   [travel] SOUHRN: bodu N, vad M
#   [travel] VADA: ...        (kazda vada zvlast)
#
# Spousteni:
#   godot --headless --path . --fixed-fps 60 --script res://tools/gates/travel_probe.gd

const Const = preload("res://core/const.gd")
const ItemScript = preload("res://sim/entity/item.gd")
# ROZSAHY SE BEROU ZE SYSTEMU, ne opsane v sonda (docs/09 §9.4): kdyz se dosah
# zmeni v kode, sonda meri dal ten novy - jinak by "dosah" byla druha pravda.
const CraftScript = preload("res://sim/systems/craft.gd")
const VendorScript = preload("res://sim/systems/vendor.gd")
const HarvestScript = preload("res://sim/systems/harvest.gd")
const InputMapScript = preload("res://app/input_map.gd")

# Frames: kazda faze ma svuj frame, aby se klavesy mely cas zpracovat (stisk
# a pusteni jsou dva framy - stejna konvence jako `sound_probe.gd`).
const F_START: int = 40
const F_PANEL_OPEN: int = 42
const F_PANEL_OPEN_MER: int = 46
const F_PANEL_CLOSE: int = 48
const F_PANEL_CLOSE_MER: int = 52
const F_PANEL_OPEN2: int = 54
const F_DIGIT: int = 58
const F_DIGIT_MER: int = 62
const F_ESC: int = 64
const F_ESC_MER: int = 68
const F_BODY: int = 80
const F_STEP_KEY: int = 140
const F_STEP_MER: int = 200
const F_END: int = 210

var _f: int = 0
var _scene = null
var _start_got: bool = false
var _vady: Array[String] = []
var _mereni: Dictionary = {}
var _tick_pred: int = 0
var _body: Array = []
var _kroku_pred: Vector3i = Vector3i(-1, -1, -1)
var _posledni_kamera: Vector2 = Vector2.ZERO
var _hotovo_body: bool = false


func _initialize() -> void:
	_scene = load("res://app/main.tscn").instantiate()
	root.add_child(_scene)


func _vada(text: String) -> void:
	_vady.append(text)
	print("[travel] VADA: ", text)


func _pricti(klic: String, hodnota: int = 1) -> void:
	_mereni[klic] = int(_mereni.get(klic, 0)) + hodnota


func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _stiskni(klavesa: int, stisknuto: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = klavesa
	event.pressed = stisknuto
	Input.parse_input_event(event)


func _panel():
	return _scene.debug_travel_panel if _scene != null else null


func _modul():
	return _scene.debug_travel if _scene != null else null


func _walk():
	# `sim.movement` si `world.walk` drzi privatne; sonda ho cte PRIMO, protoze
	# meri MAPU, ne chovani - a druha instance `walk` by byla jina mapa.
	return _scene.movement._walk if _scene != null and _scene.movement != null else null


func _prujezdnych_smeru(tile: Vector2i, z: int) -> int:
	var walk = _walk()
	if walk == null:
		return -1
	var pocet: int = 0
	for dir in range(8):
		var r: Dictionary = walk.can_step(Vector3i(tile.x, tile.y, z), dir,
			Const.PERSON_HEIGHT, true)
		if bool(r.get("ok", false)):
			pocet += 1
	return pocet


func _pozice_veci() -> Dictionary:
	# KDE JE CO VE SVETE (cteno z ZIVEHO sveta, ne z konstant v kode): stanice,
	# balvany, prodejce a ziva monstra. Tim se overuje, ze data a realita
	# sedi - kdyby se stanice posunuly, body prestanou platit.
	var out := {"forge": [], "anvil": [], "ruda": [], "prodejce": Vector2i(-1, -1),
		"monstra": []}
	for serial in _scene.items.keys():
		var it = _scene.items[serial]
		if it == null or not it.ve_svete():
			continue
		var tile := Vector2i(int(it.pos.x), int(it.pos.y))
		var role: String = ItemScript.role_of(int(it.tile))
		if role in ["forge", "anvil"]:
			(out[role] as Array).append(tile)
		if int(it.tile) == 0x453B:
			(out["ruda"] as Array).append(tile)
	if int(_scene.prodejce) > 0 and _scene.registry != null:
		var kovar = _scene.registry.get_mobile(int(_scene.prodejce))
		if kovar != null:
			out["prodejce"] = Vector2i(int(kovar.pos.x), int(kovar.pos.y))
	for mob in _scene.registry.all():
		if int(mob.serial) == int(_scene.sim.player_serial) or not mob.alive():
			continue
		if str(mob.ai.get("state", "")) == "vendor":
			continue
		(out["monstra"] as Array).append(Vector2i(int(mob.pos.x), int(mob.pos.y)))
	return out


func _nejblizsi(tile: Vector2i, seznam: Array) -> int:
	var nej: int = 999
	for t in seznam:
		nej = mini(nej, _dist(tile, t))
	return nej


func _zkontroluj_body() -> void:
	# 1) DATA + 2) DOSAH + 3) TELEPORT a KAMERA pro kazdy bod.
	var modul = _modul()
	if modul == null:
		_vada("modul `app.debug_travel` ve scene neni (app/main ho nezaklada)")
		return
	_body = modul.body()
	_mereni["bodu"] = _body.size()
	if _body.is_empty():
		_vada("modul nema zadny bod (data/test-points.json se neprecetla)")
		return
	var veci: Dictionary = _pozice_veci()
	var walk = _walk()
	var mapa = _scene.map
	# ⚠ MAPA MUSI BYT NACHTENA (2026-10-20, namereno v cistem worktree HEAD:
	# bez dat UO vraci `land_at` -1 a `surface_z` -1, takze by VSECHNY body
	# vypadaly jako vada - a to je lez: chybi vstup, ne body. Takovy stav je
	# NEMERENO (docs/08 §8.6), ne VADA - jinak by brana cervenala na stroji,
	# kde data UO nejsou (mapa je v `assets/uo/`, ktera v gitu NENI).
	# ⚠ `land_at` vraci INT (-1 = mimo mapu), NIKDY `null` - srovnavat s null
	# znamenalo, ze se chybejici mapa tvari jako "dlazdice existuje" (namereno).
	if mapa == null or int(mapa.land_at(1495, 1630)) < 0:
		_mereni["mapa_nactena"] = 0
		print("[travel] NEMERENO: mapa neni nactena (chybi data UO) - "
			+ "body, dosah ani krok po teleportu nejde overit")
		return
	_mereni["mapa_nactena"] = 1
	var stanoviste := {"start": 0, "tezba": 0, "kovani": 0, "obchod": 0, "boj": 0}
	var kamera_pred: Vector2 = _scene.world_view._camera.position \
		if _scene.world_view._camera != null else Vector2.ZERO
	var serie: String = ""
	for i in range(_body.size()):
		var bod: Dictionary = _body[i]
		var tile := Vector2i(int(bod["x"]), int(bod["y"]))
		var z: int = int(bod["z"])
		var kdo: String = "bod %d (%s, %s)" % [i, str(bod.get("id", "?")), str(tile)]
		# (a) NA MAPE: dlazdice existuje a `z` je vyska povrchu = kam se stane.
		# `land_at` vraci -1 pro "mimo mapu" (nikdy null).
		if mapa == null or int(mapa.land_at(tile.x, tile.y)) < 0:
			_vada(kdo + ": dlazdice neni na mape")
		else:
			_pricti("na_mape")
		var vyska: int = walk.surface_z(tile.x, tile.y) if walk != null else -99999
		if vyska != z:
			_vada(kdo + ": z=%d, ale vyska povrchu je %d (postava by stala ve vzduchu/ve zdi)"
				% [z, vyska])
		else:
			_pricti("vyska_sedi")
		# (b) PRUJEZDNY: ze bodu musi jit aspon 3 smery.
		var smeru: int = _prujezdnych_smeru(tile, z)
		if smeru < 3:
			_vada(kdo + ": z bodu jde jen %d smeru (clovek by tam uvazl)" % smeru)
		else:
			_pricti("prujezd")
		# (c) TELEPORT: pozice PRESNE na bod.
		var vysledek: Dictionary = modul.teleport(i)
		if not bool(vysledek.get("ok", false)):
			_vada(kdo + ": teleport selhal (" + str(vysledek.get("reason", "")) + ")")
			continue
		var poz: Vector3i = _scene.player.pos
		if poz != Vector3i(tile.x, tile.y, z):
			_vada(kdo + ": pozice po teleportu je %s, ma byt (%d, %d, %d)"
				% [str(poz), tile.x, tile.y, z])
		else:
			_pricti("pozice_presna")
		# (d) KAMERA HO NASLEDUJE: stred sveta, dlazdice hrace i vyska pro klik.
		var stred: Vector2i = _scene.world_view.center_tile
		var loop_tile: Vector2i = _scene.loop.player_tile
		if stred != tile or loop_tile != tile or int(_scene.loop.player_z) != z:
			_vada(kdo + ": kamera nesedi (center=%s, loop=%s, z=%d)"
				% [str(stred), str(loop_tile), int(_scene.loop.player_z)])
		else:
			_pricti("kamera")
		var kamera: Vector2 = _scene.world_view._camera.position \
			if _scene.world_view._camera != null else Vector2.ZERO
		if kamera == kamera_pred:
			_vada(kdo + ": obraz se Neposunul (kamera na stejnem miste jako u minuleho bodu)")
		else:
			_pricti("kamera_se_posunula")
		kamera_pred = kamera
		# (e) DOSAH: od bodu je to, kvuli cemuz tam hrac jde.
		var proc: String = str(bod.get("proc", ""))
		if not stanoviste.has(proc):
			_vada(kdo + ": nezname 'proc' '" + proc + "' (brana ho neumi zmerit)")
		else:
			stanoviste[proc] = int(stanoviste[proc]) + 1
		match proc:
			"kovani":
				var d_forge: int = _nejblizsi(tile, veci["forge"])
				var d_anvil: int = _nejblizsi(tile, veci["anvil"])
				if d_forge > CraftScript.STATION_RANGE:
					_vada(kdo + ": vyhen je %d dlazdic (STATION_RANGE=%d)"
						% [d_forge, CraftScript.STATION_RANGE])
				elif d_anvil > CraftScript.STATION_RANGE:
					_vada(kdo + ": kovadlina je %d dlazdic (STATION_RANGE=%d)"
						% [d_anvil, CraftScript.STATION_RANGE])
				else:
					_pricti("dosah")
			"obchod":
				var d_kovar: int = _nejblizsi(tile, [veci["prodejce"]])
				if d_kovar > VendorScript.VENDOR_RANGE:
					_vada(kdo + ": prodejce je %d dlazdic (VENDOR_RANGE=%d)"
						% [d_kovar, VendorScript.VENDOR_RANGE])
				else:
					_pricti("dosah")
			"tezba":
				var d_ruda: int = _nejblizsi(tile, veci["ruda"])
				var dosah_rudy: int = int(HarvestScript.BANKS["ore"]["range"])
				if d_ruda > dosah_rudy:
					_vada(kdo + ": balvan je %d dlazdic (dosah tezby=%d)"
						% [d_ruda, dosah_rudy])
				else:
					_pricti("dosah")
			"boj":
				var d_monstrum: int = _nejblizsi(tile, veci["monstra"])
				if (veci["monstra"] as Array).is_empty():
					_vada(kdo + ": ve svete NENI zadne zive monstrum (bod je k nicemu)")
				elif d_monstrum > InputMapScript.ATTACK_RANGE:
					_vada(kdo + ": nejblizsi monstrum je %d dlazdic (ATTACK_RANGE=%d)"
						% [d_monstrum, InputMapScript.ATTACK_RANGE])
				else:
					_pricti("dosah")
			_:
				# `start` nema cim merit dosah - pocita se jako splneny, ale
				# MERI se (aby "0 bodu start" nebylo ticho).
				_pricti("dosah")
		serie += str(bod.get("id", "?")) + "=" + str(tile) + " "
	# (f) BODY MUSI BYT RUZNE: dva body na jedne dlazdici = druhy je mrtvy.
	var dlazdice := {}
	for bod in _body:
		var klic: String = "%d,%d" % [int(bod["x"]), int(bod["y"])]
		if dlazdice.has(klic):
			_vada("dva body na stejne dlazdici " + klic)
		dlazdice[klic] = true
	if dlazdice.size() == _body.size():
		_pricti("ruzne_body")
	# (g) POVINNE DRUHY: zadani pojmenovava pet bodu - chybejici je VADA.
	for druh in stanoviste.keys():
		if int(stanoviste[druh]) == 0:
			_vada("v datech chybi bod pro '" + druh + "' (zadani pojmenovava pet bodu)")
		else:
			_pricti("druh_" + druh)
	_hotovo_body = true
	print("[travel] body: ", serie)


func _process(_delta: float) -> bool:
	_f += 1
	if _scene == null or _scene.loop == null:
		if _f > F_END + 200:
			print("[travel] SOUHRN: bodu 0, vad 99")
			return true
		return false

	if _f == 20:
		_tick_pred = int(_scene.loop.tick_count())
	if _f == F_START and not _start_got:
		_start_got = true
		var panel = _panel()
		if panel == null:
			_vada("okno `ui.debug_travel` ve scene neni (app/main ho nezaklada)")
		else:
			# Panel musi byt pri startu ZAVRENY (jinak zakryva svet pri hrani).
			if bool(panel.je_otevreny()):
				_vada("panel je pri startu OTEVRENY (ma byt zavreny)")
			else:
				_pricti("panel_zavreny_na_startu")
			if int(panel.count()) != int(_mereni.get("bodu", -1)):
				# Pocet bodu se bere z MODULU (ne z dat) - panel ma mit presne
				# tolik radku, kolik bodu hra zna.
				var v_modulu: int = -1
				if _modul() != null:
					v_modulu = (_modul().body() as Array).size()
				if int(panel.count()) != v_modulu:
					_vada("panel ma %d radku, modul %d bodu (obsah se nepredal)"
						% [int(panel.count()), v_modulu])
			panel.flush()
			if (panel.row_texts() as Array).is_empty():
				_vada("panel nevykreslil zadny radek (text v promenne neni text na obrazovce)")
			else:
				_pricti("panel_radku", (panel.row_texts() as Array).size())
	if _f == F_PANEL_OPEN or _f == F_PANEL_CLOSE or _f == F_PANEL_OPEN2:
		_stiskni(KEY_F7, true)
	if _f in [F_PANEL_OPEN + 1, F_PANEL_CLOSE + 1, F_PANEL_OPEN2 + 1]:
		_stiskni(KEY_F7, false)
	if _f == F_PANEL_OPEN_MER:
		if _panel() != null and bool(_panel().je_otevreny()):
			_pricti("panel_otevreni")
		else:
			_vada("F7 seznam NEOTEVREL")
	if _f == F_PANEL_CLOSE_MER:
		if _panel() != null and not bool(_panel().je_otevreny()):
			_pricti("panel_zavreni")
		else:
			_vada("F7 seznam NEZAVREL (druhy stisk)")
	if _f == F_ESC or _f == F_DIGIT:
		_stiskni(KEY_ESCAPE if _f == F_ESC else KEY_2, true)
	if _f in [F_ESC + 1, F_DIGIT + 1]:
		_stiskni(KEY_ESCAPE if _f == F_ESC + 1 else KEY_2, false)
	if _f == F_DIGIT_MER:
		# CISLO 2 = druhy bod (index 1). Meri se pozice i to, ze seznam
		# zustal otevreny (cislo okno nezavira).
		var modul = _modul()
		if modul == null or (modul.body() as Array).size() < 2:
			_vada("cislice 1-9: modul nema druhy bod")
		else:
			var cil: Dictionary = (modul.body() as Array)[1]
			var ma: Vector3i = Vector3i(int(cil["x"]), int(cil["y"]), int(cil["z"]))
			if _scene.player.pos != ma:
				_vada("cislice 2 neteleportovala na druhy bod (pozice %s, ma byt %s)"
					% [str(_scene.player.pos), str(ma)])
			else:
				_pricti("skok_cislici")
			if _panel() != null and not bool(_panel().je_otevreny()):
				_vada("po skoku cislici se seznam ZAVREL (ma zustat otevreny)")
	if _f == F_ESC_MER:
		if _panel() != null and not bool(_panel().je_otevreny()):
			_pricti("escape_zavreni")
		else:
			_vada("Esc seznam NEZAVREL")
		# ZPRÁVA DO ZURNALU: "Teleport: <nazev> (debug)" - presne tvar ze zadani.
		var text: String = ""
		if _scene.journal != null:
			text = str(_scene.journal.plain_text())
		if text.find("Teleport:") < 0 or text.find("(debug)") < 0:
			_vada("v zurnalu neni hlaska 'Teleport: ... (debug)' (text: "
				+ text.replace("\n", " | ").substr(0, 200) + ")")
		else:
			_pricti("hlaseni")
	if _f == F_BODY:
		_zkontroluj_body()
	if _f == F_STEP_KEY:
		# PO TELEPORTU JDE DAL HRAT: hrac je na poslednim bode (hrbitov) a
		# stiskne sipku. Meri se, ze ho sim opravdu posle (krok nebo zmena
		# dlazdice) - ne ze "tlacitko existuje".
		if _modul() != null and not (_modul().body() as Array).is_empty():
			_modul().teleport((_modul().body() as Array).size() - 1)
		_kroku_pred = _scene.player.pos
		_stiskni(KEY_RIGHT, true)
	if _f == F_STEP_KEY + 1:
		_stiskni(KEY_RIGHT, false)
	if _f == F_STEP_MER:
		var po: Vector3i = _scene.player.pos
		if po != _kroku_pred:
			_pricti("vstup_po_teleportu")
		else:
			var ceka: Dictionary = _scene.movement.pending_step(int(_scene.player.serial))
			if not ceka.is_empty():
				_pricti("vstup_po_teleportu")
			else:
				_vada("po teleportu hrac nereaguje na sipku (krok nevznikl, pozice %s)"
					% str(po))
		var ticku: int = int(_scene.loop.tick_count())
		if ticku > _tick_pred:
			_pricti("tick_po_teleportu")
		else:
			_vada("sim po teleportu netikuje (%d -> %d)" % [_tick_pred, ticku])
	if _f >= F_END:
		var klicu: Array = _mereni.keys()
		klicu.sort()
		var popis: Array = []
		for k in klicu:
			popis.append("%s=%d" % [str(k), int(_mereni[k])])
		print("[travel] MERENI: ", ", ".join(PackedStringArray(popis)))
		print("[travel] SOUHRN: bodu ", int(_mereni.get("bodu", 0)), ", vad ", _vady.size())
		return true
	return false
