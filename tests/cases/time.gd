extends RefCounted
# world.time - herni cas (docs/04 §4.2, docs/05 §5.11).
# Testy meri presne prevody: den = DAY_LENGTH_MS (7 200 000 ms = 24 hernich
# hodin), hodina = 300 000 ms, minuta = 5 000 ms (SecondsPerUOMinute = 5.0).

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/world/time.gd")
	if script == null:
		t._pending("world.time NENI HOTOVA: sim/world/time.gd chybi")
		return
	var consts: Dictionary = Lib.consts_at("res://core/const.gd")
	t._check(int(consts.get("DAY_LENGTH_MS", 0)) == 7200000,
		"world.time: DAY_LENGTH_MS v core/const.gd je 7 200 000 (namEReno %s)" % str(consts.get("DAY_LENGTH_MS")))

	var clock = script.new()
	t._check(clock.hour() == 0 and clock.minute() == 0, "world.time: na zacatku je 00:00")
	t._check(clock.is_night(), "world.time: 00:00 je noc")

	clock.world_time_ms = 300000
	t._check(clock.hour() == 1, "world.time: 300 000 ms = 1. hodina (namEReno %d)" % clock.hour())
	clock.world_time_ms = 5000
	t._check(clock.minute() == 1, "world.time: 5 000 ms = 1 minuta (namEReno %d)" % clock.minute())
	clock.world_time_ms = 300000 + 5000 * 30
	t._check(clock.hour() == 1 and clock.minute() == 30,
		"world.time: 01:30 (namEReno %d:%d)" % [clock.hour(), clock.minute()])
	t._check(clock.time_of_day() == "01:30", "world.time: format HH:MM (namEReno '%s')" % clock.time_of_day())

	clock.world_time_ms = 7200000
	t._check(clock.hour() == 0 and clock.minute() == 0,
		"world.time: po celem dni (7 200 000 ms) je zase 00:00 - cas se cykli")
	clock.world_time_ms = 7200000 * 3 + 300000 * 12
	t._check(clock.hour() == 12, "world.time: treti den ve 12:00 (namEReno %d)" % clock.hour())
	t._check(not clock.is_night(), "world.time: poledne neni noc")

	clock.world_time_ms = 300000 * 22
	t._check(clock.is_night(), "world.time: 22:00 je noc (hranice)")
	clock.world_time_ms = 300000 * 5
	t._check(clock.is_night(), "world.time: 05:00 je noc")
	clock.world_time_ms = 300000 * 6
	t._check(not clock.is_night(), "world.time: 06:00 uz neni noc")

	# svetlo: V1 (rozhodnuti uzivatele 2026-10-06) = den 0, noc 12, dungeon 26
	# a dvouhodinove rampy. Hodnoty jsou MERENE v obou emulatorech
	# (`_src/servuo/Scripts/Misc/LightCycle.cs:13-16,70-82`), ne opsane ze
	# zadani - to melo "den 12" (12 je NightLevel). 0 = nejjasnejsi.
	clock.in_dungeon = false
	clock.world_time_ms = 300000 * 12
	t._check(clock.light_level() == 0,
		"world.time: svetlo v poledne je 0 (namEReno %d)" % clock.light_level())
	clock.world_time_ms = 300000 * 2
	t._check(clock.light_level() == 12,
		"world.time: svetlo ve 02:00 je 12 (namEReno %d)" % clock.light_level())
	clock.world_time_ms = 300000 * 5
	t._check(clock.light_level() == 6,
		"world.time: svetlo v 05:00 je 6 (ramp 12->0, namEReno %d)" % clock.light_level())
	clock.world_time_ms = 300000 * 23
	t._check(clock.light_level() == 6,
		"world.time: svetlo ve 23:00 je 6 (ramp 0->12, namEReno %d)" % clock.light_level())
	clock.in_dungeon = true
	t._check(clock.light_level() == 26,
		"world.time: svetlo v dungeonu je 26 (namEReno %d)" % clock.light_level())

	# posun casu zpet (zaporne ms) nesmi rozbit hodiny
	clock.world_time_ms = -5000
	t._check(clock.hour() >= 0 and clock.hour() < 24 and clock.minute() >= 0 and clock.minute() < 60,
		"world.time: i pri zapornem case vraci platnou hodinu (%d:%d)" % [clock.hour(), clock.minute()])
