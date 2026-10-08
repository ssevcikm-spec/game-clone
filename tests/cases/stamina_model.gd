extends RefCounted
# Modely spotreby staminy (docs/05 §5.1.4, granule `sim.movement`).
#
# PROC TENHLE CASE VZNIKL (2026-10-09): uzivatel zadal "stamina se stale
# neregeneruje a ubyva prilis rychle, kazdym krokem, prestoze nevazim nic ...
# Zatim bych to vypnul". Pri te praci se namERilo, ze hodnota `never` je
# v `app/config.gd` SCHEMA POVOLENA, ale `sim.movement` ji NEZNAL: rozhodovalo
# se jen mezi "emulator" a vsim ostatnim, takze `never` se tise chovalo jako
# `run_only` a stamina ubývala dal. Tichy pruchod neznama hodnota = vada, proto
# se tu meri KAZDY model zvlast a to, ze se vzajemne lisi.
#
# Kontext z reference (proc je "never" obhajitelne, ne jen pohodlne):
#   * beh sam staminu NEBERE - spotrebu vaze az PRETIZENI
#     (`_src/servuo/Scripts/Misc/WeightOverloading.cs:111`:
#     `loss = 5 + overWeight / 25`, pri behu x2, na mountu /3),
#   * regenerace je 1 bod za interval (`_src/servuo/Server/Mobile.cs:1968-1976`)
#     a ta u nas NEEXISTUJE (`sim.regen`) - kazdy ubranny bod byl tedy nevratny.
#
# Cislo akce v eventu `mobile_anim` je ABSTRAKTNI ID klienta (0 = chuze,
# 1 = beh, 4 = idle) - viz `render/anim_player.gd` `ACTION_GROUP`.

const Const = preload("res://core/const.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const MovementScript = preload("res://sim/systems/movement.gd")

const MOVE_SCRIPT := "res://sim/systems/movement.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeWalk:
	func can_step(_from: Vector3i, _dir: int, _height: int, _is_player: bool) -> Dictionary:
		return {"ok": true, "z": 0, "reason": ""}


func _sestav(model: String) -> Array:
	var skript = load(_arg("movement-script", MOVE_SCRIPT))
	if skript == null:
		return []
	var clock = ClockScript.new()
	var mv = skript.new(FakeWalk.new(), clock, EventsScript.new(), model, null)
	var mob = MobileScript.new(0x40000001, 400, Vector3i(5, 5, 0))
	mv.player_serial = mob.serial
	mv.register(mob)
	return [mv, mob, clock]


func _krok(sestava: Array, run: bool) -> int:
	# Jeden krok (chuze nebo beh) a vrací staminu PO nem.
	var mv = sestava[0]
	var mob = sestava[1]
	var clock = sestava[2]
	mv.request_step(mob.serial, 0, run)
	clock.advance(Const.RUN_MS if run else Const.WALK_MS)
	mv.tick(Const.TICK_MS)
	return int(mob.stam)


func run(t) -> void:
	var base: Array = _sestav("run_only")
	if base.is_empty():
		t._pending("sim.movement NENI HOTOVA: " + MOVE_SCRIPT)
		return
	var mv = base[0]
	var mob = base[1]

	# 1) "never" (rozhodnuti uzivatele 2026-10-09): ani beh, ani chuze neberou NIC.
	#    Kdyby se hodnota zase tise ignorovala, spadne to tady.
	var never: Array = _sestav("never")
	if never.is_empty():
		t._pending("sim.movement NENI HOTOVA: " + MOVE_SCRIPT)
		return
	var mv_n = never[0]
	var mob_n = never[1]
	var pred_n: int = int(mob_n.stam)
	_krok(never, true)
	t._check(int(mob_n.stam) == pred_n,
		"sim.movement: model 'never' - beh staminu nebere (bylo %d, je %d)"
		% [pred_n, mob_n.stam])
	_krok(never, false)
	t._check(int(mob_n.stam) == pred_n,
		"sim.movement: model 'never' - chuze staminu nebere (bylo %d, je %d)"
		% [pred_n, mob_n.stam])
	mv_n.consume_stamina(mob_n.serial, 5)
	t._check(int(mob_n.stam) == pred_n,
		"sim.movement: model 'never' - ani prime volani consume_stamina nebere (je %d)"
		% mob_n.stam)

	# 2) Model se opravdu CTE z hodnoty, ne z konstanty: "always" bere i za chuzi.
	var always: Array = _sestav("always")
	if not always.is_empty():
		var mob_a = always[1]
		var pred_a: int = int(mob_a.stam)
		_krok(always, false)
		t._check(int(mob_a.stam) == pred_a - 1,
			"sim.movement: model 'always' - chuze bere 1 bod (bylo %d, je %d)"
			% [pred_a, mob_a.stam])

	# 3) "run_only" (stav pred 2026-10-09) se NESMI rozbit: chuze zdarma, beh 1 bod.
	var pred_r: int = int(mob.stam)
	_krok(base, false)
	t._check(int(mob.stam) == pred_r,
		"sim.movement: model 'run_only' - chuze zdarma (bylo %d, je %d)" % [pred_r, mob.stam])
	pred_r = int(mob.stam)
	_krok(base, true)
	t._check(int(mob.stam) == pred_r - 1,
		"sim.movement: model 'run_only' - beh 1 bod (bylo %d, je %d)" % [pred_r, mob.stam])

	# 4) Neznama hodnota = STARE chovani "run_only" (nic noveho se nevymysli) -
	#    a je to videt: test to pripina, aby se ticha vetev nedala "vylepsit"
	#    na neco, co nikdo nerozhodl.
	var divny: Array = _sestav("nesmysl")
	if not divny.is_empty():
		var mob_d = divny[1]
		var pred_d: int = int(mob_d.stam)
		_krok(divny, false)
		_krok(divny, true)
		t._check(int(mob_d.stam) == pred_d - 1,
			"sim.movement: neznamej model = chovani 'run_only' (bylo %d, je %d)"
			% [pred_d, mob_d.stam])

	# 5) Cislo akce v `mobile_anim` je ABSTRAKTNI ID klienta - pri behu 1.
	#    (Skupina v anim.mul je 2; preklad dela `render.anim`.)
	var events = EventsScript.new()
	var mv_e = MovementScript.new(FakeWalk.new(), ClockScript.new(), events, "run_only", null)
	var mob_e = MobileScript.new(0x40000001, 400, Vector3i(5, 5, 0))
	mv_e.player_serial = mob_e.serial
	mv_e.register(mob_e)
	mv_e.request_step(mob_e.serial, 0, true)
	var akce: Array = []
	for e in events.drain():
		if str(e["name"]) == "mobile_anim":
			akce.append(int(e["data"].get("action", -1)))
	t._check(akce.size() == 1 and akce[0] == 1,
		"sim.movement: beh posila mobile_anim s abstraktnim id 1 (vydano %s)" % str(akce))
