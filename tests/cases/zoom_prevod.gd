extends RefCounted
# Zoom v prevodu svet <-> obrazovka (2026-10-09, faze 1 bod 5.1).
#
# ZADANI UZIVATELE (doslova): "Zoom hry rozhazi jak hra detekuje kde je postava
# a kde vsechno ostatni v referenci k postave. Jako kdyby oddaleni sice
# zvetsilo viditelne pole, ale ten 'stredovy bod' zustal ve stejnem rozmeru,
# takze nekde v levo nahore okna."
#
# Pricina (namERena 2026-10-09 v overlayi pri zoomu 0,75): `pick=(426,280)`
# proti skutecnemu stredu postavy (480,300). Prevod se delal jako
# `world = screen + camera_offset`, coz plati JEN pri zoomu 1,0; pri zoomu != 1
# ma obrazovy pixel jinou velikost nez svetovy. Reference prevadi vstup zpet
# touz matici, kterou kresli (`_src/classicuo/src/ClassicUO.Renderer/Camera.cs:88-103`
# `ScreenToWorld`, `:162-184`).
#
# CO SE MERI (chovani, ne pritomnost):
#   1. ROUND-TRIP pres `click_at`: pro kazdou dlazdici v okoli hrace a pro
#      kazdy zoom se spocita JEJI pozice na obrazovce (a podstrci se jako klik)
#      - vysledny smer MUSI byt smer k te dlazdici. Kdyz prevod zapomene zoom,
#      vetsina dlazdic vyjde jinak; test to vidi jako pocet chyb.
#   2. `interact_command` prelozi stejny obrazovy bod na TOUZ dlazdici (druha
#      cesta týmz prevodem - kdyby se opravila jen `click_at`, spadne to tady).
#   3. PRAH BEHU (`mouse_run`) se meri od HRACE, ne od stredu okna (s cernym
#      pasem GUI je to rozdil 171 px).
#   4. ZALOZNI CESTA (`player_screen_position`) se nasobi zoomem a vraci
#      stejny stred jako klient (`viewport/2 - gui_odsazeni`) pro KAZDY zoom.
#
# Vsechny obrazove pozice se v testu pocitaji VLASTNI formulí
# `screen = (world - camera_offset) * zoom` - kdyby je test bral z modulu,
# ktery meri, meril by sam sebe (docs/09 §9.6).

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")

const MAPPER_SCRIPT := "res://app/input_map.gd"
const ISO_SCRIPT := "res://core/iso.gd"

const VELIKOST_OKNA := Vector2(1280, 720)
const PAS_GUI := Vector2(320, 120)          # jako `app/main.GUI_PAS_*`
const ZOOMY := [1.0, 0.75, 0.5, 1.5, 2.0]   # vcetne vychoziho 0,75 a obou kraju
const HRAC := Vector2i(10, 10)
const Z_HRACE := 10
const OKOLI := 4                            # dlazdice na kazdou stranu


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _bod_dlazdice(iso, x: int, y: int, z: int) -> Vector2:
	# STRED dlazdice pro KLIK - `core/iso.gd` vraci presne tu hodnotu, kterou
	# `to_tile` prevede zpet na (x, y) (dokazano v hlavicce `core/iso.gd`).
	# ⚠ NEPRIDAVEJ sem `+ (ISO_STEP, TILE_H/2)`: to je KOTVA SPRITU (viz nize)
	# a lezi presne na ROHU dlazdice, kde je zaokrouhleni nejednoznacne -
	# namEReno 2026-10-09: s kotvou vyslo 17 z 80 dlazdic o dlazdici vedle.
	return iso.to_screen(x, y, z)


func _kotva_hrace(iso, x: int, y: int, z: int) -> Vector2:
	# KOTVA SPRITU = bod, na ktery klient kresli postavu a ktery drzi ve stredu
	# viditelneho sveta (`app/world_view.player_ground_position`). Je to stred
	# dlazdice + `(ISO_STEP, TILE_H/2)`.
	return iso.to_screen(x, y, z) + Vector2(Const.ISO_STEP, Const.TILE_H / 2)


func _smer_k(from: Vector2i, to: Vector2i) -> int:
	# Smer 0..7 pocitany z TABULKY v core/const.gd (ne z modulu, ktery meri).
	var dx: int = signi(to.x - from.x)
	var dy: int = signi(to.y - from.y)
	for dir in 8:
		if Const.DIR_DX[dir] == dx and Const.DIR_DY[dir] == dy:
			return dir
	return -1


func run(t) -> void:
	var skript = load(_arg("mapper-script", MAPPER_SCRIPT))
	if skript == null:
		t._pending("app.input NENI HOTOV: " + MAPPER_SCRIPT)
		return
	var iso_skript = load(ISO_SCRIPT)
	if iso_skript == null:
		t._pending("core.iso NENI HOTOVE: " + ISO_SCRIPT)
		return
	var iso = iso_skript.new()
	var mapper = skript.new()
	mapper.view_size = VELIKOST_OKNA
	mapper.gui_pas = PAS_GUI

	var hrac_svet: Vector2 = _kotva_hrace(iso, HRAC.x, HRAC.y, Z_HRACE)

	for zoom in ZOOMY:
		var z: float = float(zoom)
		mapper.zoom = z
		# Kamera je posunuta tak, ze hrac stoji ve stredu VIDITELNEHO sveta
		# (`viewport/2 - gui_odsazeni`); z toho plyne `camera_offset`. Je to
		# vlastni odvozeni testu, ne opsana hodnota z klienta.
		var stred_hrace: Vector2 = VELIKOST_OKNA / 2.0 - PAS_GUI
		var offset: Vector2 = hrac_svet - stred_hrace / z

		# 1) ROUND-TRIP: klik na obrazove misto dlazdice = krok k te dlazdici.
		var chyby: int = 0
		var celkem: int = 0
		for dx in range(-OKOLI, OKOLI + 1):
			for dy in range(-OKOLI, OKOLI + 1):
				var cil := Vector2i(HRAC.x + dx, HRAC.y + dy)
				if cil == HRAC:
					continue
				celkem += 1
				var cil_svet: Vector2 = _bod_dlazdice(iso, cil.x, cil.y, Z_HRACE)
				var cil_obraz: Vector2 = (cil_svet - offset) * z
				var cmd: Dictionary = mapper.click_at(HRAC, cil_obraz, offset, Z_HRACE)
				if int(cmd.get("dir", -1)) != _smer_k(HRAC, cil):
					chyby += 1
		t._check(celkem > 0 and chyby == 0,
			"app.input: klik na obrazove misto dlazdice = krok k ni (zoom %.2f: %d z %d chybne)"
				% [z, chyby, celkem])

		# 2) INTERAKCE: stejny obrazovy bod musi dat TOUZ dlazdici (druha cesta).
		var cil_inter := Vector2i(HRAC.x + 3, HRAC.y - 2)
		var inter_svet: Vector2 = _bod_dlazdice(iso, cil_inter.x, cil_inter.y, Z_HRACE)
		var inter_obraz: Vector2 = (inter_svet - offset) * z
		var prikaz: Dictionary = mapper.interact_command(inter_obraz, offset, Z_HRACE)
		var cil_v_prikazu: Dictionary = prikaz.get("target", {})
		t._check(int(cil_v_prikazu.get("x", -999)) == cil_inter.x \
				and int(cil_v_prikazu.get("y", -999)) == cil_inter.y,
			"app.input: interakce prelozi obrazovy bod na spravnou dlazdici (zoom %.2f: %s, cekano %s)"
				% [z, str(cil_v_prikazu), str(cil_inter)])

		# 4) ZALOZNI CESTA (klient stred nedodal): stred hrace musi vyjit stejne.
		var zalozni: Vector2 = mapper.player_screen_position(HRAC, offset, Z_HRACE)
		t._check((zalozni - stred_hrace).length() < 0.001,
			"app.input: zalozni stred hrace je stred viditelneho sveta (zoom %.2f: %s, cekano %s)"
				% [z, str(zalozni), str(stred_hrace)])

	# 3) PRAH BEHU SE MERI OD HRACE. Bod, kde se obe zeny ROZEJDOU: 185 px od
	#    hrace (chuze), ale 292 px od stredu okna (beh). Kdyby se merilo od
	#    stredu okna, vyslo by `true` - a to je presne vada z 2026-10-09.
	mapper.zoom = 0.75
	var stred_hrace2: Vector2 = VELIKOST_OKNA / 2.0 - PAS_GUI
	var bod: Vector2 = stred_hrace2 + Vector2(0.0, -185.0)
	t._check(mapper.mouse_run(bod, stred_hrace2) == false,
		"app.input: 185 px od hrace = CHUZE (mouse_run vratil true)")
	t._check(mapper.mouse_run(bod) == true,
		"app.input: tyz bod se stredem okna = BEH (bez predaneho stredu plati stary stred)")
	t._check(mapper.mouse_run(stred_hrace2 + Vector2(190.0, 0.0), stred_hrace2) == true,
		"app.input: 190 px od hrace = BEH (prah z ClassicUO GameSceneInputHandler.cs:66)")
	t._check(mapper.mouse_run(stred_hrace2 + Vector2(189.0, 0.0), stred_hrace2) == false,
		"app.input: 189 px od hrace = CHUZE (prah je presne 190)")
