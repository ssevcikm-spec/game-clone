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
const MOUSE_RATIO_NUM: int = 2
const MOUSE_RATIO_DEN: int = 5

var bindings: Dictionary = {}
var always_run: bool = false
# Velikost herniho okna v px - potrebuje ji prave tlacitko (`run` podle
# vzdalenosti kurzoru od STREDU obrazovky). Nastavuje ji `app/player_controller`
# (RefCounted nema pristup k viewportu); kdyz zustane nulova, `run` rozhoduje
# jen `always_run`.
var view_size: Vector2 = Vector2.ZERO
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
	var stred_sveta: Vector2 = _iso.to_screen(player.x, player.y, z) \
		+ Vector2(Const.ISO_STEP, Const.TILE_H / 2)
	return stred_sveta - camera_offset


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


func poll(player: Vector2i, camera_offset: Vector2, z: int = 0,
		mouse_position: Vector2 = Vector2.ZERO, now_ms: int = -1) -> Array[Dictionary]:
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
	var cas: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var out: Array[Dictionary] = []
	for action in bindings.keys():
		var input_action: String = str(bindings[action])
		if not InputMap.has_action(input_action):
			continue
		if not Input.is_action_pressed(input_action):
			_krok_ms.erase(action)
			continue
		if str(action) == "click_move":
			# Jedno zmacknuti = jeden krok (klik-to-move). Drzeni leveho
			# tlacitka v UO nechodi - to je "drag", ne chuze.
			if Input.is_action_just_pressed(input_action):
				out.append(click_at(player, mouse_position, camera_offset, z))
			continue
		if str(action) == "walk_to":
			# DRZENE PRAVE TLACITKO = chuze kursoru (ClassicUO
			# `MoveCharacterByMouseInput`). Smer je z pozice kurzoru VULCI
			# HRACI NA OBRAZOVCE (`direction_from_screen`, vada V3), `run`
			# z jeho vzdalenosti od stredu obrazovky.
			# Kurzor presne na hraci NENI krok - a prodleva se u nej
			# NESPOTREBUJE (jinak by "nic" spálilo 400 ms, presne vada V1).
			var smer: int = direction_from_screen(
				player_screen_position(player, camera_offset, z), mouse_position)
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
		var krok: Dictionary = hold_command(str(action), cas, always_run)
		if not krok.is_empty():
			out.append(krok)
	return out


func _smi_krokovat(action: String, now_ms: int, run: bool) -> bool:
	var prodleva: int = step_delay_ms(run)
	var minule: int = int(_krok_ms.get(action, -1000000))
	if now_ms - minule < prodleva:
		return false
	_krok_ms[action] = now_ms
	return true
