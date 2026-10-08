extends RefCounted
# Mapovani vstupu na `Command` - JEDINE misto v projektu, ktere smi pouzivat
# `Input` (docs/02 §2.2, docs/04 §4.1).
#
# Prevod je rozdelene na dve casti, aby se dal testovat bez okna:
#   * `step_command`, `object_command`, `key_command` - cista logika,
#   * `poll(...)` - precte skutecny vstup a pouzije je.
#
# VYCHOZI SADU KLAVES TENHLE SOUBOR NEDEFINUJE: docs/05 §5.3 ji oznacuje za
# rozhodnuti a vlastni ji `ui.hotkeys` (docs/04 §4.2). Sem se predava slovnikem
# `bindings` (nazev akce -> akce v InputMap).
#
# Co smlouva nepinuje (patri do docs/04): nazvy logickych akci nize
# ("north".."se", "war", "peace", "cancel_target", "use") a to, ze pravy klik
# jen otevira kontextove menu (posila ho UI, ne sim).
#
# ⚠⚠ ZADANI 19 (2026-10-08) - v tomhle souboru se opravily TRI vady vstupu:
#   * V14 - stred pro smer z mysi je POZICE HRACE (`center_for`), ne precet
#     z `z = 0`; namEReno 4 473 z 11 163 pozic kurzoru vracelo jiny smer
#     (sonda `_analyza/p22-mys-sonda.gd`, hlavicka u `MOUSE_RATIO_*`),
#   * V4 - AUTO-RUN obema tlacitky mysi (`auto_run_step`, stav `auto_run`),
#     zrusi ho novy stisk praveho tlacitka nebo Esc,
#   * V15a - OTOCENI NA MISTE (`turn_command`), vstup je Ctrl + smer.
# Vsechny tri jsou meritelne bez okna: `auto_run_step` bere tlacitka jako
# ARGUMENT a `poll(...)` ma pro ne posledni parametr `buttons`.

const Const = preload("res://core/const.gd")
const Iso = preload("res://core/iso.gd")

const ACTION_DIR := {
	"east": 0, "ne": 1, "north": 2, "nw": 3,
	"west": 4, "sw": 5, "south": 6, "se": 7,
}

# CHUZE DRZENIM (rozhodnuti uzivatele 2026-10-07, "Co ceka na tebe" bod 4:
# "ano, mys i klavesa"). UO krokuje, dokud je vstup drzeny:
#   * klavesa  ... `GameSceneInputHandler.cs:1277-1279` (`_flags[4] = true` pri
#                  stisku, `:1404-1406` false pri pusteni) - smer se opakuje,
#   * prave tlacitko mysi ... `GameSceneInputHandler.cs:41` (`_rightMousePressed`)
#                  volá `MoveCharacterByMouseInput()`: smer z KURZORU a
#                  `run = mouseRange >= 190` (`:66`).
# Prodleva kroku je z `core/const.gd` (400 chuze / 200 beh) - stejna cisla
# pouziva `sim.movement`, ktery krok navic zahodi jako "busy", kdyz jeste bezi.
const MOUSE_RUN_PX: float = 190.0   # ClassicUO GameSceneInputHandler.cs:66

# PRAHY SMERU Z MYSI (namEReno 2026-10-07, vada V3 z `REVIZE-POHYB-2026-10-07.md`
# §2.3). Smer se NEPOCITA z rozdilu dlazdic (`signi`), ale z pozice kurzoru na
# OBRAZOVCE - presne jako ClassicUO `GameCursor.GetMouseDirection`
# (`GameCursor.cs:670-754`): hranice rovina/uhlopricka jsou |dy| <= 0,4|dx|
# a |dy| >= 2,5|dx|, tedy celociselne `ay * 5 <= ax * 2` a `ay * 2 >= ax * 5`.
# Cisla jsou z reference, ne vymyslena.
#
# ⚠⚠ V14 (2026-10-08, zadani 19) - STRED PRO SMER Z MYSI MUSI BYT POZICE HRACE.
#   Uzivatel: "kousek pod ni a kousek vlevo me to posle nahoru". Do teto session
#   se stred skladal jako `iso.to_screen(player, z) + (22,22) - camera_offset`
#   a `app/loop.gd:39` posila `z = 0`, ale `app/world_view.look_at_tile:263`
#   posouva kameru o `z * Z_SCALE`. Na namesti Britainu je `z = 10` (namEReno
#   sondou `_analyza/p22-mys-sonda.gd`), takze stred vysel o **40 px NIZ**, nez
#   kde hrac stoji: z 11 163 merenych pozic kurzoru (3 mista, mrizka -120..+120
#   px po 4 px) vratilo **4 473 (40 %)** JINY smer nez tyz kod se spravnym
#   stredem. Podezreni na `gui_odsazeni` se NEPOTVRDILO (v `camera_offset` se
#   vykrati - stred.x vyslo spravne 480 = 1280/2 - 160).
#   Spravny stred je to, co hrac na obrazovce VIDI:
#   `world_view.player_ground_position() - camera_offset`. Nezavisi na `z`
#   (kamera ho drzi na miste) a vykrati se v nem i posun beziciho kroku
#   (`player_pixel_offset` je v obou clenech). Sklada ho klient -
#   `app/player_controller._publish_center()` - protoze jen on zna `gui_odsazeni`
#   a `world_view`. `Vector2.INF` = "klient ji nedodal" (testy, klient bez
#   `world_view`) -> pocita se stara cesta z `camera_offset` (viz `poll`).
const MOUSE_RATIO_NUM: int = 2
const MOUSE_RATIO_DEN: int = 5

var bindings: Dictionary = {}
# ⚠⚠ 18. session (2026-10-08) - VADA UZIVATELE: "CHYBI BEH JAKO RYCHLOST
# POHYBU". Do teto session bylo `always_run = false` a NIKDO ho nezapnul, takze
# klavesy i numpad chodily vzdy 400 ms/krok; beh (200 ms) sel jen drzenym
# pravym tlacitkem dal nez 190 px od stredu. UO ma beh jako VYCHOZI pohyb
# (`PlayerMobile.cs:530` `run |= ProfileManager.CurrentProfile.AlwaysRun`
# a `:532` `Stamina <= 1` beh zakaze) a prepina se priznakem/makrem
# (`MacroType.AlwaysRun`, `MacroManager.cs:1189-1192`). Proto je vychozi stav
# BEH a `run_toggle` (Shift) ho prepne na chuzi - stav se HLAST, ne tise.
var always_run: bool = true
# Velikost herniho okna v px - potrebuje ji prave tlacitko (`run` podle
# vzdalenosti kurzoru od STREDU obrazovky). Nastavuje ji `app/player_controller`
# (RefCounted nema pristup k viewportu); kdyz zustane nulova, `run` rozhoduje
# jen `always_run`.
var view_size: Vector2 = Vector2.ZERO
# ⚠ 20. session: velikost CERNEHO PASU s GUI (vpravo, dole) - svet se do nej
# nekresli, takze obecna interakce (E/T) se v nem nespousti (`is_over_gui`).
# Plni ji `app/player_controller` z `world_view.gui_odsazeni * 2`.
var gui_pas: Vector2 = Vector2.ZERO
# ⚠ V14 (2026-10-08): pozice HRACE na obrazovce, na kterou se meri smer z mysi.
# Plni ji `app/player_controller._publish_center()`. `Vector2.INF` = nedodano.
var player_screen: Vector2 = Vector2.INF
# ⚠ AUTO-RUN (V4, zadani 19): "soucasne stisknuti obou tlacitek mysi = postava
# bezi za mysi". Stav drzi klient; meni ho `auto_run_step()` a je VIDET
# (print pri kazde zmene).
var auto_run: bool = false
var _levy_minule: bool = false
var _pravy_minule: bool = false
var _seq: int = 0
var _iso
var _krok_ms: Dictionary = {}       # nazev akce -> cas posledniho VYDANEHO kroku


func _init(binding_table: Dictionary = {}) -> void:
	bindings = binding_table
	_iso = Iso.new()


func next_seq() -> int:
	_seq += 1
	return _seq


func step_delay_ms(run: bool) -> int:
	# Prodleva opakovani drzene klavesy; stejna cisla jako `sim.movement`
	# (`delay_ms_for`), aby se drzeni nerozjelo rychleji nez simulace.
	return Const.RUN_MS if run else Const.WALK_MS


func auto_run_step(vstup: Dictionary) -> Dictionary:
	# AUTO-RUN (vada/pozadavek V4, zadani 19): "V UO to bylo soucasne stisknuti
	# obou tlacitek mysi." Vstupy jsou ARGUMENTY (ne `Input`), aby se stav dal
	# merit bez okna - vzor `poll(...)`. Vstup:
	#   left/right        ... tlacitko je DRZENE,
	#   left_just/right_just ... tlacitko bylo STISKNUTO v tomto kroku,
	#   cancel            ... pozadavek na tvrdy stop (Esc).
	# Vraci `{on, changed, reason}`; `on` je novy stav (drzi ho `auto_run`).
	#
	# PRAVIDLA (z reference `_src/classicuo` `GameSceneInputHandler.cs`):
	#   * START  - `:422-425`: levy klik, kdyz je drzene PRAVE tlacitko, zapne
	#     `_continueRunning` (a `MoveCharacterByMouseInput` pak jede i bez
	#     drzeneho tlacitka: `:41` `(_rightMousePressed || _continueRunning)`),
	#   * STOP   - `:827-828`: NOVY stisk praveho tlacitka auto-run rusi
	#     (`_rightMousePressed = true; _continueRunning = false;`) a zaroven
	#     znovu zapne "chuze drzenim". To je odpoved na "dokud to nezrusis":
	#     rusi se PRAVYM klikem - stejne jako v UO.
	#   * Esc je NAVIC (nasi klienti): hrac, ktery se rozbehne a nevi jak
	#     zastavit, potrebuje tvrdy stop. Klavesa je zatim tady, protoze
	#     granule `ui.hotkeys` neexistuje (patri ji to).
	# Poradi vetvi je dane: kdyz se obe tlacitka stisknou v TOM SAMEM kroku,
	# musi vyhrat START (proto `left_just` pred `right_just`).
	var novy: bool = auto_run
	var duvod: String = ""
	if bool(vstup.get("cancel", false)):
		novy = false
		duvod = "cancel"
	elif bool(vstup.get("left_just", false)) and bool(vstup.get("right", false)):
		novy = true
		duvod = "both_buttons"
	elif bool(vstup.get("right_just", false)):
		novy = false
		duvod = "right_click"
	var zmena: bool = novy != auto_run
	auto_run = novy
	if zmena:
		# HLAS: ticho by znamenalo, ze hrac nevi, proc postava bezi sama.
		print("[input] auto-run (obe tlacitka): ", "ZAPNUT" if novy else "VYPNUT",
			" (", duvod, ")")
	return {"on": novy, "changed": zmena, "reason": duvod if zmena else ""}


func _precti_tlacitka() -> Dictionary:
	# Jedine misto, kde se auto-run ptá na skutecny vstup (a jedine misto,
	# ktere smi pouzivat `Input`). Testy posilaji tyz slovnik do `poll`.
	var levy: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var pravy: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var vstup: Dictionary = {
		"left": levy,
		"right": pravy,
		"left_just": levy and not _levy_minule,
		"right_just": pravy and not _pravy_minule,
		"cancel": _je_stisknuty("auto_run_cancel"),
	}
	_levy_minule = levy
	_pravy_minule = pravy
	return vstup


func mouse_run(mouse_position: Vector2) -> bool:
	# `run` pro drzene prave tlacitko: vzdalenost kurzoru od stredu obrazovky
	# (ClassicUO `mouseRange >= 190`). Kdyz velikost okna neznáme, plati
	# `always_run` - vymyslet si cislo by bylo horsi nez rict "nevim".
	if view_size == Vector2.ZERO:
		return always_run
	return (mouse_position - view_size / 2.0).length() >= MOUSE_RUN_PX


func hold_command(action: String, now_ms: int, run: bool = false) -> Dictionary:
	# Krok z DRZENEHO vstupu: vyda se jen kdyz od minuleho vydaneho kroku
	# uplynula prodleva (`step_delay_ms`). Drzeni tedy krokuje, ale ne rychleji
	# nez simulace - a `poll()` se smi volat i nekolikrat za frame.
	# Jednorazove akce (war/peace/use) se NEOPAKUJI - drzeni klavesy by jinak
	# poslalo desitky prikazu za sekundu.
	var command: Dictionary = key_command(action)
	if str(command.get("t", "")) != "move":
		return {}
	if not _smi_krokovat(action, now_ms, run):
		return {}
	return command


func direction_between(from: Vector2i, to: Vector2i) -> int:
	# Vraci cislo smeru 0..7, nebo -1 kdyz jsme na miste (neni kam krocit).
	# POZOR: tohle je pravidlo pro KLIK NA DLAZDICI (`click_at`), ne pro smer
	# z mysi pri drzeni praveho tlacitka - tam plati `direction_from_screen`
	# (nize). Rozdil je namEReny: `signi` na rozdilu dlazdic udela uhlopricku
	# z kazdeho kliku, ktery neni presne na ose nebo presne na 45 stupnich.
	if from == to:
		return -1
	var dx: int = signi(to.x - from.x)
	var dy: int = signi(to.y - from.y)
	for dir in 8:
		if Const.DIR_DX[dir] == dx and Const.DIR_DY[dir] == dy:
			return dir
	return -1


func player_screen_position(player: Vector2i, camera_offset: Vector2, z: int = 0) -> Vector2:
	# Kde je HRAC na obrazovce: kamera ho drzi ve stredu, takze stred obrazovky
	# je jeho dlazdice. `click_at` pouziva opacny prevod (`world = screen + offset`).
	#
	# ⚠ V14: tenhle vypocet je jen ZALOZNI (kdyz klient pozici hrace nedodal).
	# Zavisi na `z`, ktere musi byt vyska, na ktere postava stoji - `app/loop.gd`
	# ale posila 0, takze na vysce (Britain z = 10) vyjde stred o 40 px niz.
	# Presnou hodnotu dava klient (`player_screen`, viz hlavicka).
	var stred_sveta: Vector2 = _iso.to_screen(player.x, player.y, z) \
		+ Vector2(Const.ISO_STEP, Const.TILE_H / 2)
	return stred_sveta - camera_offset


func center_for(player: Vector2i, camera_offset: Vector2, z: int = 0) -> Vector2:
	# Stred, ze ktereho se meri smer z mysi: PRESNA pozice hrace od klienta,
	# jinak zalozni vypocet z kamery. Jedno misto rozhodnuti - `poll` i testy
	# se tak ptaji stejne (a rozdil je videt, ne schovany ve vetvi).
	if player_screen != Vector2.INF:
		return player_screen
	return player_screen_position(player, camera_offset, z)


func direction_from_screen(center: Vector2, mouse: Vector2) -> int:
	# Smer 0..7 z pozice kurzoru VULCI HRACI NA OBRAZOVCE (ClassicUO
	# `GameCursor.GetMouseDirection`, `GameCursor.cs:670-754`; prevod jeho
	# vysledku do naseho cislovani je odvozeny preklad tabulky `hashf`).
	# Vraci -1, kdyz kurzor stoji presne na hraci - "neni kam krocit" je
	# pozadavek, ktery se NEMA tise zmenit na krok nejakym smerem.
	var dx: float = mouse.x - center.x
	var dy: float = mouse.y - center.y
	if dx == 0.0 and dy == 0.0:
		return -1
	if dx == 0.0:
		return 7 if dy > 0.0 else 3          # dolu = SE, nahoru = NW
	if dy == 0.0:
		return 1 if dx > 0.0 else 5          # vpravo = NE, vlevo = SW
	var ax: float = absf(dx)
	var ay: float = absf(dy)
	if ay * float(MOUSE_RATIO_DEN) <= ax * float(MOUSE_RATIO_NUM):
		return 1 if dx > 0.0 else 5          # rovina vodorovna
	if ay * float(MOUSE_RATIO_NUM) >= ax * float(MOUSE_RATIO_DEN):
		return 7 if dy > 0.0 else 3          # rovina svisla
	if dx > 0.0:
		return 0 if dy > 0.0 else 2          # vpravo dolu = E, vpravo nahoru = N
	return 6 if dy > 0.0 else 4              # vlevo dolu = S, vlevo nahoru = W


func step_command(from: Vector2i, to: Vector2i) -> Dictionary:
	# Klik-to-move: UO krokuje po dlazdicich, takze klik na vzdalenou dlazdici
	# je pozadavek na JEDEN krok tim smerem (docs/01 V1).
	var dir: int = direction_between(from, to)
	if dir < 0:
		return {}
	return {"t": "move", "dir": dir, "run": always_run, "seq": next_seq()}


func click_at(player: Vector2i, screen: Vector2, camera_offset: Vector2, z: int = 0) -> Dictionary:
	var world: Vector2 = screen + camera_offset
	var tile: Vector2i = _iso.to_tile(world.x, world.y, z)
	return step_command(player, tile)


func interact_command(screen: Vector2, camera_offset: Vector2, z: int = 0) -> Dictionary:
	# OBECNA INTERAKCE (20. session, pokyn uzivatele 2026-10-08): "tlacitko je
	# nejen na tezbu, ale vseobecne interaktivni". Klient posle JEN CIL - tedy
	# kterou dlazdici ma kurzor - a co se s ni da delat, rozhoduje SIM
	# (`sim.interaction.interact`). Tady se ZADNE pravidlo nevybira: kdyby
	# klient vybiral nastroj, byla by to herni logika v UI (docs/05 §5.3).
	#
	# Cilem je zatim DLAZDICE: predmety a bytosti ve svete jeste nejsou (jsou
	# jen v kontejneru), takze by je nebylo na co kliknout. Az pribudnou,
	# pribude sem `kind: "item"`/`"mobile"` - smlouva §4.3 je zna.
	var world: Vector2 = screen + camera_offset
	var tile: Vector2i = _iso.to_tile(world.x, world.y, z)
	return {"t": "interact",
		"target": {"kind": "tile", "x": tile.x, "y": tile.y, "z": z}}


func is_over_gui(screen: Vector2) -> bool:
	# Je kurzor v CERNEM PASU s GUI (zurnal vpravo, stavovy pruh dole)? Tam se
	# svet nekresli, takze interakce by sahala na dlazdici POD panelem.
	# Kdyz velikost okna nebo pasu neznáme, vraci `false` - "nevim" nesmi
	# znamenat "neinteraguj" (to by bylo tiche vypnuti funkce).
	if view_size.x <= 0.0 or view_size.y <= 0.0 or gui_pas == Vector2.ZERO:
		return false
	return screen.x >= view_size.x - gui_pas.x or screen.y >= view_size.y - gui_pas.y


func object_command(serial: int, doubled: bool = false) -> Dictionary:
	if doubled:
		return {"t": "use", "serial": serial}
	return {}


func key_command(action: String, serial: int = 0) -> Dictionary:
	if ACTION_DIR.has(action):
		return {"t": "move", "dir": ACTION_DIR[action], "run": always_run, "seq": next_seq()}
	match action:
		"war":
			return {"t": "war", "on": true}
		"peace":
			return {"t": "war", "on": false}
		"cancel_target":
			return {"t": "target_reply", "cursor": 0}
		"use":
			return {"t": "use", "serial": serial} if serial > 0 else {}
	return {}


func turn_command(action: String) -> Dictionary:
	# OTOCENI NA MISTE (vada V15, zadani 19): `Command{t:"turn", dir}` je ve
	# smlouve (`sim/commands.gd:21`), ale klient ho nikdy neposilal - postava se
	# tedy umela jen krocit. Uzivatel: "Postava se neumi otacet ... pokud se
	# chci jen otocit (kratkym klikem) nebo kdyz narazim do zdi."
	# Smer je ABSOLUTNI (0..7), proto staci vstup smeru; `seq` tu neni -
	# smlouva u `turn` zna jen `dir` (`sim/commands.gd:21`).
	if not ACTION_DIR.has(action):
		return {}
	return {"t": "turn", "dir": ACTION_DIR[action]}


func poll(player: Vector2i, camera_offset: Vector2, z: int = 0,
		mouse_position: Vector2 = Vector2.ZERO, now_ms: int = -1,
		buttons: Dictionary = {}) -> Array[Dictionary]:
	# Klavesy jdou pres `bindings` (vlastni je ui.hotkeys); mys jen kdyz je
	# na ni vazana akce - jinak by vstup vymyslel vazbu, kterou nikdo nerozhodl.
	# Pozici mysi predava smycka (viewport), ne tenhle mapper: `Input` v Godotu 4
	# pozici mysi nezna a RefCounted nema na strom pristup.
	#
	# DRZENI (2026-10-07): vstup se nepta jen na `just_pressed`, ale na
	# `is_action_pressed` - a krok vyda po prodleve z `hold_command()`. Kdo
	# vstup PUSTI, tomu se prodleva vynuluje, takze dalsi zmacknuti krokuje hned
	# (jinak by se prvni krok po pusteni ztratil).
	# `now_ms` je VSTUP (vychozi -1 = `Time.get_ticks_msec()`) - test tak meri
	# opakovani deterministicky, bez cekani na hodiny.
	#
	# `buttons` je VSTUP pro AUTO-RUN (V4): prazdny = precti skutecny vstup,
	# predany = pouzij ten (test tak meri obe tlacitka bez mysi).
	var cas: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var vstup_tlacitek: Dictionary = buttons if not buttons.is_empty() else _precti_tlacitka()
	auto_run_step(vstup_tlacitek)
	var out: Array[Dictionary] = []
	for action in bindings.keys():
		var input_action: String = str(bindings[action])
		if not InputMap.has_action(input_action):
			continue
		var stisknuto: bool = Input.is_action_pressed(input_action)
		# AUTO-RUN (V4): chuze kursoru bezi i BEZ drzeneho tlacitka - presne to
		# je "bezi za mysi, dokud to nezrusis". Smer se porad bere z kurzoru.
		if str(action) == "walk_to" and auto_run:
			stisknuto = true
		if not stisknuto:
			_krok_ms.erase(action)
			continue
		if str(action) == "run_toggle":
			# PREPINAC CHUZE/BEH (18. session): jedno zmacknuti = druhy rezim.
			# Hlasi se do konzole - ticho by znamenalo, ze hrac nevi, jak jede.
			if Input.is_action_just_pressed(input_action):
				always_run = not always_run
				print("[input] beh: ", "ZAPNUT" if always_run else "VYPNUT",
					" (", step_delay_ms(always_run), " ms/krok)")
			continue
		if str(action) == "click_move":
			# Jedno zmacknuti = jeden krok (klik-to-move). Drzeni leveho
			# tlacitka v UO nechodi - to je "drag", ne chuze.
			if Input.is_action_just_pressed(input_action):
				out.append(click_at(player, mouse_position, camera_offset, z))
			continue
		if str(action) == "interact":
			# OBECNA INTERAKCE (20. session): jedno zmacknuti = jeden pozadavek
			# na cil pod kurzorem. NEOPAKUJE SE pri drzeni (drzena klavesa by
			# poslala desitky pozadavku za sekundu) - stejne jako `use`.
			# V cernem pasu GUI se nespousti: tam svet neni, jen urnal.
			if Input.is_action_just_pressed(input_action) and not is_over_gui(mouse_position):
				out.append(interact_command(mouse_position, camera_offset, z))
			continue
		if str(action) == "walk_to":
			# DRZENE PRAVE TLACITKO = chuze kursoru (ClassicUO
			# `MoveCharacterByMouseInput`). Smer je z pozice kurzoru VULCI
			# HRACI NA OBRAZOVCE (`direction_from_screen`, vada V3), stred
			# dava `center_for` (presna pozice od klienta, vada V14), `run`
			# z jeho vzdalenosti od stredu obrazovky.
			# Kurzor presne na hraci NENI krok - a prodleva se u nej
			# NESPOTREBUJE (jinak by "nic" spálilo 400 ms, presne vada V1).
			var smer: int = direction_from_screen(
				center_for(player, camera_offset, z), mouse_position)
			if smer < 0:
				continue
			var bez: bool = mouse_run(mouse_position)
			if not _smi_krokovat(action, cas, bez):
				continue
			out.append({"t": "move", "dir": smer, "run": bez or always_run,
				"seq": next_seq()})
			continue
		if not ACTION_DIR.has(str(action)):
			# Jednorazove akce (war/peace/cancel_target/use) se NEOPAKUJI.
			if Input.is_action_just_pressed(input_action):
				var jednou: Dictionary = key_command(str(action))
				if not jednou.is_empty():
					out.append(jednou)
			continue
		# OTOCENI NA MISTE (V15): kdyz je stisknuty vstup pro otoceni (Ctrl +
		# smer), posle se `turn` a krok se preskoci. Vlastni kadence je
		# `TURN_MS` (80 ms) a prodlevu KROKU nespotrebovava - jinak by se
		# "jen otocit" spalilo 400 ms chuze.
		var turn_akce: String = "turn_" + str(action)
		if _je_stisknuty(turn_akce):
			if _smi_krokovat_ms(turn_akce, cas, Const.TURN_MS):
				out.append(turn_command(str(action)))
			continue
		var krok: Dictionary = hold_command(str(action), cas, always_run)
		if not krok.is_empty():
			out.append(krok)
	return out


func _smi_krokovat(action: String, now_ms: int, run: bool) -> bool:
	return _smi_krokovat_ms(action, now_ms, step_delay_ms(run))


func _smi_krokovat_ms(action: String, now_ms: int, prodleva: int) -> bool:
	var minule: int = int(_krok_ms.get(action, -1000000))
	if now_ms - minule < prodleva:
		return false
	_krok_ms[action] = now_ms
	return true


func _je_stisknuty(akce: String) -> bool:
	# Je logicka akce stisknuta? Vazbu vlastni `bindings` (kdo ji nezada,
	# vstup se nikdy nespusti - vstup si vazbu nevymysli). Pouziva ji otoceni
	# na miste (V15) i tvrdy stop auto-runu (V4).
	if not bindings.has(akce):
		return false
	var input_action: String = str(bindings[akce])
	return InputMap.has_action(input_action) and Input.is_action_pressed(input_action)
