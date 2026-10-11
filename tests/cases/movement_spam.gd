extends RefCounted
# sim.movement - KOMU PATRI HLASKA "You cannot move there." (session D, 2026-10-11).
#
# PROC TENHLE TEST EXISTUJE: hlaska je psana hlasem HRACE, ale `request_step`
# ji posilal za KAZDY blokovany krok - tedy i za monstra. V snde
# `_analyza/p58-smycka-hracem.gd` to za ~2 minuty behu dalo **33 240** hlasek:
# monstra, ktera se nedostanou k hraci, zkousi krok kazdy tik, a `ui.journal`
# ma `MAX_LINES = 200` - hrac v zurnalu nevidel NIC jineho nez spam. Presne to
# zabiji "umi rict, co delal a proc".
#
# Test meri CHOVANI a ma PROTIPRIKLAD (bez nej by proslo i to, kdyby hlaska
# nefungovala vubec):
#   A) hracuv blokovany krok -> hlaska JE,
#   B) krok MONSTRA -> hlaska NENI (a krok je skutecne blokovany),
#   C) bez `player_serial` ("0" = nevim, kdo je hrac) hlaska zustava - testy
#      a hole `SimWorld` se nesmi rozbit.
#
# Cesta k modulu je VSTUP (`-- --movement-script=<cesta>`), aby sel merit mutant.

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const MOVEMENT_SCRIPT := "res://sim/systems/movement.gd"
const HLASKA := "You cannot move there."
const HRAC := 0x40000001
const NPC := 0x40000002


class FakeWalk:
	# `world.walk` je tu FAKE (pruchodnost meri `tests/cases/walk.gd`): kazdy
	# krok odmitne, aby se dalo merit, KOMU se o tom rekne.
	func can_step(_from: Vector3i, _dir: int, _height: int, _is_player: bool) -> Dictionary:
		return {"ok": false, "z": 0, "reason": "blocked"}


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _texty(events) -> Array:
	var out: Array = []
	for e in events.drain():
		if str(e["name"]) == "message":
			out.append(str(e["data"].get("text", "")))
	return out


func run(t) -> void:
	var script = Lib.script_at(_arg("movement-script", MOVEMENT_SCRIPT))
	if script == null:
		t._pending("sim.movement NENI HOTOVA: " + MOVEMENT_SCRIPT + " chybi")
		return
	var registry = RegistryScript.new()
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var mv = script.new(FakeWalk.new(), clock, events, "run_only", registry)
	var hrac = MobileScript.new(HRAC, 400, Vector3i(5, 5, 0))
	var npc = MobileScript.new(NPC, 400, Vector3i(7, 7, 0))
	mv.register(hrac)
	mv.register(npc)
	mv.player_serial = HRAC

	# -- A) HRAC: blokovany krok = hlaska --------------------------------
	events.clear()
	var krok_hrace: Dictionary = mv.request_step(HRAC, 0, false)
	var texty_hrace: Array = _texty(events)
	t._check(not bool(krok_hrace.get("ok", true))
			and str(krok_hrace.get("reason", "")) == "blocked",
		"movement: blokovany krok vraci reason 'blocked' (vyslo %s)" % str(krok_hrace))
	t._check(texty_hrace.has(HLASKA),
		"movement: HRAC dostane hlasku '%s' (vyslo %s)" % [HLASKA, str(texty_hrace)])

	# -- B) MONSTRUM: krok je blokovany, ale hlaska NENI ------------------
	# (je psana hlasem hrace - a u monster z ni byl spam)
	events.clear()
	var krok_npc: Dictionary = mv.request_step(NPC, 0, false)
	var texty_npc: Array = _texty(events)
	t._check(not bool(krok_npc.get("ok", true))
			and str(krok_npc.get("reason", "")) == "blocked",
		"movement: blokovany krok MONSTRA je taky 'blocked' (vyslo %s)" % str(krok_npc))
	t._check(not texty_npc.has(HLASKA),
		"movement: MONSTRUM hlasku nedostane (vyslo %s)" % str(texty_npc))
	t._check(texty_npc.is_empty(),
		"movement: krok MONSTRA neposle ZADNOU zpravu (vyslo %s)" % str(texty_npc))

	# -- C) BEZ ZNAMEHO HRACE ("0" = nevim) hlaska zustava ----------------
	events.clear()
	mv.player_serial = 0
	mv.request_step(HRAC, 0, false)
	t._check(_texty(events).has(HLASKA),
		"movement: bez `player_serial` se hlaska posle dal (nevim != nikdo)")
