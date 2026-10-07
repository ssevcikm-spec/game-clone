extends RefCounted
# sim.movement - pohyb (docs/04 §4.2 a tok §4.6.1, docs/05 §5.1).
#
# Test meri PRESNA prijimaci kriteria smlouvy:
#   * `request_step(m, 0, false).delay_ms == 400` (chuze) a 200 (beh),
#   * po `apply_step` se `pos.x += 1`,
#   * posun po 8 ticcich (8 x 50 ms = 400 ms),
#   * voda -> `{ok:false, reason:"blocked"}` a hlaska "You cannot move there.",
#   * diagonala: hrac `is_player = true`, NPC `false` (predava se do world.walk),
#   * stamina se spotrebovava podle modelu z `data/balance.json`.
#
# `world.walk` je tu FAKE: test meri tento system, ne pruchodnost (tu meri
# tests/cases/walk.gd). Fake si navic ZAZNAMENA, s jakym `is_player` ho system
# zavolal - jinak by se asymetricka diagonala dala "splnit" i omylem.
#
# Cesta k souboru je VSTUP: `-- --movement-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
# Cesta k SimWorld je VSTUP pro tutez sondu (mutacni test modulu `world_loop`).
const SIM_SCRIPT := "res://sim/sim_world.gd"

const MOVEMENT_SCRIPT := "res://sim/systems/movement.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeWalk:
	var vysledky := {}          # dir -> {ok, z, reason}
	var volani: Array = []      # [{dir, is_player}]

	func can_step(_from: Vector3i, dir: int, _height: int, is_player: bool) -> Dictionary:
		volani.append({"dir": dir, "is_player": is_player})
		if vysledky.has(dir):
			return vysledky[dir]
		return {"ok": true, "z": 0, "reason": ""}


func _sestav(t, drain_model: String, registry = null) -> Array:
	var cesta: String = _arg("movement-script", MOVEMENT_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.movement NENI HOTOVA: " + cesta + " chybi")
		return []
	var walk = FakeWalk.new()
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var mv = script.new(walk, clock, events, drain_model, registry)
	var mob = MobileScript.new(0x40000001, 400, Vector3i(5, 5, 0))
	mv.player_serial = mob.serial
	mv.register(mob)
	return [mv, walk, clock, events, mob]


func _texty(events) -> Array:
	var out: Array = []
	for e in events.drain():
		if str(e["name"]) == "message":
			out.append(str(e["data"].get("text", "")))
	return out


func _jmena(events) -> Array:
	var out: Array = []
	for e in events.drain():
		out.append(str(e["name"]))
	return out


func run(t) -> void:
	var casti := _sestav(t, "run_only")
	if casti.is_empty():
		return
	var mv = casti[0]
	var walk = casti[1]
	var clock = casti[2]
	var events = casti[3]
	var mob = casti[4]
	var m: int = mob.serial

	# 1) prijimaci kriterium smlouvy: prodlevy 400 (chuze) a 200 (beh)
	var chuze: Dictionary = mv.request_step(m, 0, false)
	t._check(chuze["ok"] == true and int(chuze["delay_ms"]) == 400,
		"sim.movement: request_step(m, 0, false).delay_ms == 400 (namEReno %s)" % str(chuze))
	t._check(mob.pos == Vector3i(5, 5, 0),
		"sim.movement: po request_step se postava JESTE nepohnula (posun je za 400 ms)")

	# 2) krok se vykona az po 8 ticcich (8 x 50 ms = 400 ms)
	for i in 7:
		clock.advance(Const.TICK_MS)
		mv.tick(Const.TICK_MS)
	t._check(mob.pos == Vector3i(5, 5, 0),
		"sim.movement: po 7 ticcich (350 ms) se jeste stoji (pos %s)" % str(mob.pos))
	clock.advance(Const.TICK_MS)
	mv.tick(Const.TICK_MS)
	t._check(mob.pos == Vector3i(6, 5, 0),
		"sim.movement: po 8 ticcich (400 ms) se posunul o 1 na vychod (pos %s)" % str(mob.pos))
	t._check(mob.dir == 0, "sim.movement: smer se nastavi na 0 (vychod)")

	# 3) eventy: mobile_anim pri zadosti, mobile_moved pri posunu
	var jmena := _jmena(events)
	t._check(jmena.has("mobile_anim") and jmena.has("mobile_moved"),
		"sim.movement: posila mobile_anim i mobile_moved (namEReno %s)" % str(jmena))

	# 3b) ⚠ V4/V2 (2026-10-07): krok musi klientovi rict, KDY zacal a JAKA je
	#     stojna vyska (`pending_step`), a po vykonani se musi ZAPSAT do `pos.z`.
	#     Do teto session se `z` z `can_step` zahodilo, takze postava zustala
	#     ve vysce prvniho kroku (na svahu se pak kazdy dalsi krok meril proti
	#     stare vysce a cesta do kopce se zablokovala - vada V4).
	#     Krok se zadava DRUHemu mobilu, aby se `mob` (a jeho pozice pro dalsi
	#     sekce) nerozjel.
	var mob3 = MobileScript.new(0x40000007, 400, Vector3i(5, 5, 0))
	mv.register(mob3)
	var cas_zadosti: int = int(clock.now_ms())
	var krok_zadost: Dictionary = mv.request_step(mob3.serial, 0, false)
	t._check(krok_zadost["ok"] == true,
		"sim.movement: krok druheho mobilu projde (namEReno %s)" % str(krok_zadost))
	var krok_v_letu: Dictionary = mv.pending_step(mob3.serial)
	var ma_cas: bool = krok_v_letu.has("start_ms") and int(krok_v_letu["delay_ms"]) == 400 \
		and int(krok_v_letu["z"]) == 0
	t._check(ma_cas,
		"sim.movement: pending_step nese start_ms, delay_ms i z (namEReno %s)" % str(krok_v_letu))
	# `start_ms` musi byt CAS ZADOSTI (klient z nej pocita posun): hodnota 0 by
	# prosla kontrole "klic existuje", ale posun by vysel jinde.
	t._check(int(krok_v_letu.get("start_ms", -1)) == cas_zadosti,
		"sim.movement: start_ms je cas zadosti (%s, cekano %d)"
			% [str(krok_v_letu.get("start_ms")), cas_zadosti])
	t._check(mv.pending_step(0x40009999).is_empty(),
		"sim.movement: pending_step pro neznamy serial vraci prazdno")
	clock.advance(Const.WALK_MS)
	mv.tick(Const.TICK_MS)
	t._check(mv.pending_step(mob3.serial).is_empty(),
		"sim.movement: po vykonani kroku je pending_step prazdny")
	# vlastni instance se stubem, ktery vraci z=7: po kroku musi byt `pos.z == 7`
	var walkv = FakeWalk.new()
	walkv.vysledky[0] = {"ok": true, "z": 7, "reason": ""}
	var clockv = ClockScript.new()
	var MovementScript = Lib.script_at(_arg("movement-script", MOVEMENT_SCRIPT))
	var mvv = MovementScript.new(walkv, clockv, EventsScript.new(), "run_only", null)
	var mobv = MobileScript.new(0x40000002, 400, Vector3i(5, 5, 0))
	mvv.register(mobv)
	mvv.request_step(mobv.serial, 0, false)
	clockv.advance(Const.WALK_MS)
	mvv.tick(Const.TICK_MS)
	t._check(mobv.pos == Vector3i(6, 5, 7),
		"sim.movement: stojna vyska z `can_step` se zapise do pos.z (pos %s)" % str(mobv.pos))

	# 4) beh: 200 ms a 1 bod staminy za krok (model run_only)
	var beh: Dictionary = mv.request_step(m, 0, true)
	t._check(beh["ok"] == true and int(beh["delay_ms"]) == 200,
		"sim.movement: beh ma delay_ms 200 (namEReno %s)" % str(beh))
	var stam_pred: int = mob.stam
	clock.advance(Const.TICK_MS * 4)
	mv.tick(Const.TICK_MS)
	t._check(mob.pos == Vector3i(7, 5, 0), "sim.movement: beh 4 ticky (200 ms) posune o 1 (pos %s)" % str(mob.pos))
	t._check(mob.stam == stam_pred - 1,
		"sim.movement: beh ubere 1 bod staminy (bylo %d, je %d)" % [stam_pred, mob.stam])

	# 5) chuze staminu nebere (model run_only, docs/05 §5.1.4)
	var pred: int = mob.stam
	mv.request_step(m, 0, false)
	clock.advance(Const.WALK_MS)
	mv.tick(Const.TICK_MS)
	t._check(mob.stam == pred, "sim.movement: chuze staminu nebere (bylo %d, je %d)" % [pred, mob.stam])

	# 6) model "emulator": 1 bod za 16 kroku (i chuze)
	var em := _sestav(t, "emulator")
	if not em.is_empty():
		var mv2 = em[0]
		var mob2 = em[4]
		var pred2: int = mob2.stam
		mv2.consume_stamina(mob2.serial, 15)
		t._check(mob2.stam == pred2, "sim.movement: emulator - 15 kroku jeste nic nebere")
		mv2.consume_stamina(mob2.serial, 1)
		t._check(mob2.stam == pred2 - 1, "sim.movement: emulator - 16. krok ubere 1 bod (je %d)" % mob2.stam)

	# 7) blokovany krok: voda -> {ok:false, reason:"blocked"} + hlaska hraci
	walk.vysledky[0] = {"ok": false, "z": 0, "reason": "blocked"}
	var blok: Dictionary = mv.request_step(m, 0, false)
	t._check(blok["ok"] == false and str(blok["reason"]) == "blocked" and int(blok["delay_ms"]) == 0,
		"sim.movement: voda vraci {ok:false, reason:'blocked', delay_ms:0} (namEReno %s)" % str(blok))
	t._check(_texty(events).has("You cannot move there."),
		"sim.movement: pri odmitnuti posle hlasku 'You cannot move there.'")
	var pos_pred: Vector3i = mob.pos
	clock.advance(Const.WALK_MS * 2)
	mv.tick(Const.TICK_MS)
	t._check(mob.pos == pos_pred, "sim.movement: odmitnuty krok postavu neposune (pos %s)" % str(mob.pos))

	# 8) dva kroky naraz: druhy je 'busy' (fronta kroku je na klientu)
	walk.vysledky.erase(0)
	mv.request_step(m, 0, false)
	var druhy: Dictionary = mv.request_step(m, 0, false)
	t._check(druhy["ok"] == false and str(druhy["reason"]) == "busy",
		"sim.movement: druhy krok v letu vraci 'busy' (namEReno %s)" % str(druhy))
	t._check(mv.pending_count() == 1, "sim.movement: v letu je prave jeden krok")
	clock.advance(Const.WALK_MS)
	mv.tick(Const.TICK_MS)
	t._check(mv.pending_count() == 0, "sim.movement: po vykonani je fronta prazdna")

	# 9) is_player se predava do world.walk (jinak by diagonala nebyla asymetricka)
	mv.request_step(m, 1, false)
	var posledni: Dictionary = walk.volani[walk.volani.size() - 1]
	t._check(bool(posledni["is_player"]) == true and int(posledni["dir"]) == 1,
		"sim.movement: hrac jde do can_step s is_player = true (namEReno %s)" % str(posledni))
	walk.vysledky[1] = {"ok": true, "z": 0, "reason": ""}
	clock.advance(Const.WALK_MS)
	mv.tick(Const.TICK_MS)
	var cizi = MobileScript.new(0x40000009, 400, Vector3i(5, 5, 0))
	mv.register(cizi)
	mv.request_step(cizi.serial, 1, false)
	var posledni2: Dictionary = walk.volani[walk.volani.size() - 1]
	t._check(bool(posledni2["is_player"]) == false,
		"sim.movement: NPC jde do can_step s is_player = false (namEReno %s)" % str(posledni2))

	# 10) nezaregistrovany mobil a nulova stamina
	var nez: Dictionary = mv.request_step(0x40009999, 0, false)
	t._check(nez["ok"] == false and str(nez["reason"]) == "no_mobile",
		"sim.movement: nezaregistrovany mobil vraci 'no_mobile' (namEReno %s)" % str(nez))
	mob.stam = 0
	var bez: Dictionary = mv.request_step(m, 0, true)
	t._check(bez["ok"] == true and int(bez["delay_ms"]) == Const.WALK_MS,
		"sim.movement: bez staminy se jde chuzi (400 ms), ne během (namEReno %s)" % str(bez))

	# 11) mobily bere system z REGISTRU (granule `sim.entity_registry`), ne
	#     z vlastniho slovniku: mobil vlozeny PRIMO do predaneho registru musi
	#     jit pouzit i bez `mv.register` a `register()` musi zapsat do registru
	var reg = RegistryScript.new()
	var cizi2 = MobileScript.new(0x40000031, 400, Vector3i(5, 5, 0))
	reg.register(cizi2)
	var mv3 = _sestav(t, "run_only", reg)
	if not mv3.is_empty():
		var mv3s = mv3[0]
		t._check(mv3s.mobile(cizi2.serial) == cizi2,
			"sim.movement: mobil vlozeny do PREDANEHO registru je viden pres mobile()")
		var krok: Dictionary = mv3s.request_step(cizi2.serial, 0, false)
		t._check(bool(krok["ok"]) and int(krok["delay_ms"]) == Const.WALK_MS,
			"sim.movement: krok mobilu z registru projde (namEReno %s)" % str(krok))
		var jiny = MobileScript.new(0x40000032, 400, Vector3i(5, 5, 0))
		mv3s.register(jiny)
		t._check(reg.get_mobile(jiny.serial) == jiny,
			"sim.movement: register() zapisuje do registru, ne do vlastniho slovniku")
		t._check(mv3s.mobile(0x40009999) == null,
			"sim.movement: nezaregistrovany serial vraci pres mobile() null")

	# 12) PORADI V TICKU (vada V1 z `REVIZE-POHYB-2026-10-07.md` §2.1): prikaz
	#     podany v TOM SAMEM ticku, kdy je krok na rade, nesmi dostat 'busy'.
	#     Cas v ticku plyne "nejdriv svet (timery), pak cizi zamery" - kdyby to
	#     bylo obracene, krok se jeste neaplikoval, druhy prikaz se zahodil jako
	#     'busy' a klient (jehoz 400ms casovac se spotreboval uz pri VYDANI)
	#     by krok opakoval az za dalsich 400 ms. NamERena kadence pred opravou
	#     byla 718 ms (a 530 ms) misto 400 - 7 az 9 kroku za 5 s misto 13.
	#     Test jede pres `SimWorld`, aby se meritlo PORADI v nem, ne jen system;
	#     cesta k nemu je VSTUP (`--sim-script`), aby to chytil mutacni harness.
	#     Hlasky maji prefix `sim.world_loop` - to je modul, ktery se tu testuje.
	var sim_cesta: String = _arg("sim-script", SIM_SCRIPT)
	var sim_script = Lib.script_at(sim_cesta)
	if sim_script == null:
		t._pending("sim.world_loop NENI HOTOVA: " + sim_cesta + " chybi")
		return
	var sim = sim_script.new(1, {})
	var walk2 = FakeWalk.new()
	var events2 = EventsScript.new()
	var reg2 = RegistryScript.new()
	var mob2 = MobileScript.new(0x40000041, 400, Vector3i(5, 5, 0))
	reg2.register(mob2)
	var mv2 = Lib.script_at(_arg("movement-script", MOVEMENT_SCRIPT)).new(
		walk2, sim.clock(), events2, "run_only", reg2)
	sim.player_serial = mob2.serial
	sim.systems["movement"] = mv2
	sim.enqueue({"t": "move", "dir": 0, "run": false, "seq": 1})
	for i in 8:
		sim.tick(Const.TICK_MS)
	t._check(mob2.pos.x == 5,
		"sim.world_loop: po 8 ticcich (400 ms) se jeste stoji (pos %s)" % str(mob2.pos))
	# Prikaz se dispatchuje az po systmech, takze prvni krok je na rade
	# v 9. ticku (cas 450 ms) - to je ta jedna polovina tiku, kterou poradi stoji.
	sim.enqueue({"t": "move", "dir": 0, "run": false, "seq": 2})
	sim.tick(Const.TICK_MS)
	t._check(mob2.pos.x == 6,
		"sim.world_loop: prvni krok se provedl v 9. ticku (pos %s)" % str(mob2.pos))
	for i in 8:
		sim.tick(Const.TICK_MS)
	t._check(mob2.pos.x == 7,
		"sim.world_loop: druhy prikaz ve stejnem ticku NEDOSTAL 'busy' (pos %s)" % str(mob2.pos))
	t._check(int(sim.world_time()) == 17 * Const.TICK_MS,
		"sim.world_loop: hodiny simulace sly o 17 tiku (cas %d)" % int(sim.world_time()))
