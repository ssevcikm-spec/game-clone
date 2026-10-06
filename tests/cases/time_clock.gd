extends RefCounted
# world.time napojeny na `core.clock` (vada F6 z etapy 1, opraveno 2026-10-06).
#
# Do 2026-10-06 platilo, ze `world_time_ms` nastavovaly JEN testy: ve hre vracelo
# `hour()` vzdy 0 (a komentar v `time.gd` tvrdil, ze ho plni SimWorld - nebyla to
# pravda). Tenhle test meri, ze cas opravdu tece ze simulace:
#   * po `bind(clock)` a `tick()` se `world_time_ms` rovna casu simulace,
#   * `hour()` se po 3 600 000 ms posune o 12 hernich hodin (den = 7 200 000 ms),
#   * bez `bind` se nic nemeni a nic nespadne (modul necte `Time`/`OS` sam).

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")
const ClockScript = preload("res://core/clock.gd")
const TimeScript = preload("res://sim/world/time.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/world/time.gd")
	if script == null:
		t._pending("world.time NENI HOTOVY: sim/world/time.gd chybi")
		return
	var time = TimeScript.new()

	# 1) bez bind se nic nedeje (a nespadne to)
	time.tick(Const.TICK_MS)
	t._check(time.world_time_ms == 0 and time.hour() == 0,
		"world.time: bez bind(clock) zustava cas 0 (namEReno %d)" % time.world_time_ms)

	# 2) s bind cas tece ze simulace
	var clock = ClockScript.new()
	time.bind(clock)
	clock.advance(Const.TICK_MS)
	time.tick(Const.TICK_MS)
	t._check(time.world_time_ms == Const.TICK_MS,
		"world.time: po ticku je cas simulace (%d ms, namEReno %d)"
			% [Const.TICK_MS, time.world_time_ms])

	# 3) hodiny: den = 7 200 000 ms, takze 3 600 000 ms = 12 hernich hodin
	clock.advance(Const.DAY_LENGTH_MS / 2)
	time.tick(Const.TICK_MS)
	t._check(time.hour() == 12,
		"world.time: po pul dni je 12:00 (namEReno %d)" % time.hour())
	t._check(time.time_of_day() == "12:00",
		"world.time: time_of_day vraci '12:00' (namEReno %s)" % time.time_of_day())
	t._check(not time.is_night(), "world.time: poledne neni noc")

	# 4) noc je 22:00-06:00 (rozhodnuti, viz hlavicka time.gd)
	#    Z 12:00 na 23:00 je 11 hernich hodin (den = 24 h => 1 h = DAY_LENGTH_MS/24).
	clock.advance(Const.DAY_LENGTH_MS / 24 * 11)
	time.tick(Const.TICK_MS)
	t._check(time.is_night(), "world.time: 23:00 je noc (namEReno %s)" % time.time_of_day())

	# 5) light_level podle varianty V1 (rozhodnuti uzivatele 2026-10-06):
	#    den 0, noc 12, dungeon 26, rampy 4-6 a 22-24. Hodnoty jsou merene
	#    (`_src/servuo/Scripts/Misc/LightCycle.cs:13-16,70-82`), proto se daji
	#    tvrdit - driv tu byl test, ktery se ptal konstanty proti sobe a tvrdil
	#    12 i pro den (nalez 2026-10-06). Cas se nastavuje MODULU (`time`),
	#    ne `core.clock` - ten drzi jen cas simulace.
	time.world_time_ms = 300000 * 12
	t._check(time.light_level() == 0,
		"world.time: v poledne je svetlo 0 (namEReno %d)" % time.light_level())
	time.world_time_ms = 300000 * 2
	t._check(time.light_level() == 12,
		"world.time: ve 02:00 je svetlo 12 - noc (namEReno %d)" % time.light_level())
	time.world_time_ms = 300000 * 5
	t._check(time.light_level() == 6,
		"world.time: v 05:00 je svetlo 6 - ramp (namEReno %d)" % time.light_level())
	time.world_time_ms = 300000 * 23
	t._check(time.light_level() == 6,
		"world.time: ve 23:00 je svetlo 6 - ramp (namEReno %d)" % time.light_level())
	time.in_dungeon = true
	t._check(time.light_level() == 26,
		"world.time: v dungeonu je 26 (namEReno %d)" % time.light_level())
	time.in_dungeon = false
	t._check(script.LIGHT_DUNGEON == 26 and script.LIGHT_DAY == 0,
		"world.time: konstanty sedi na referenci (den 0, dungeon 26)")
