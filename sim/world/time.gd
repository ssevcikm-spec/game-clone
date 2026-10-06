extends RefCounted
# Herni cas (granule world.time, docs/04 §4.2, docs/05 §5.11).
#
# Den = 24 hernich hodin = DAY_LENGTH_MS = 7 200 000 ms (2 h realneho casu).
# Vychazi z `SecondsPerUOMinute = 5.0` - overeno v ServUO/ModernUO, docs/10 P12
# (v dokumentaci je i tabulka, ktera tvrdi 120 s; spravny je kod).
# Vse je v ms (int). Modul si cas nedrzi sam: dostava ho z `core.clock`, ktery
# mu preda integracni misto (`app/main.gd`) pres `bind(clock)`, a v kazdem ticku
# si precte `now_ms()`. Do 2026-10-06 tu byl komentar, ze `world_time_ms`
# nastavuje SimWorld kazdy tick - NEBYLA to pravda (nastavovaly ho jen testy)
# a `hour()` vratilo ve hre vzdy 0; od te doby to plati (viz `tick`).
#
# ROZSIRENI SMLOUVY (patri do docs/04 §4.2 k `world.time`): `bind(clock)` a
# `tick(ms)` v tabulce komponent nejsou - bez nich ale cas v modulu nikdo
# nenaplni. Overeno testem `tests/cases/time_clock.gd`.

const Const = preload("res://core/const.gd")

# SVETLO - NAMERENO 2026-10-06 v referencich (podklad: research/REJSTRIK-REFERENCI.md):
#   ServUO i ModernUO `Scripts/Misc/LightCycle.cs:13-16` maji DayLevel = 0,
#   NightLevel = 12, DungeonLevel = 26, JailLevel = 9; rozsah 0..30, kde
#   **0 = NEJJASNEJSI** (ClassicUO `IsometricLight.cs:69` to rika slovem:
#   "if overall is 0, we have MAXIMUM light").
#   ZADANI §10 bod 20 ("den 12, dungeon 26") je tedy v PRVNI casti nespravne:
#   12 je NightLevel, ne den - dungeon 26 naopak sedi. Puvodni komentar tady
#   tvrdil "obojí overene cislo", coz byla nepravda (nalez 2026-10-06).
#
# ROZHODNUTI UZIVATELE (otevrene, docs/05 §5.11): (1) den 0 / noc 12 s rampy
#   (presne to delaji oba emulatory) vs (2) binarni OSI den/noc. Do rozhodnuti
#   vraci `light_level()` hodnotu nize a NESMI se z ni odvozovat jas sceny.
const LIGHT_DAY: int = 12        # POZOR: 12 je ve referencich NIGHT, ne day
const LIGHT_DUNGEON: int = 26    # tohle referencim sedi (DungeonLevel = 26)

# Noc je ROZHODNUTI (22:00-06:00), ne overene cislo - viz hlavicka.
const NIGHT_FROM_HOUR: int = 22
const NIGHT_TO_HOUR: int = 6

var world_time_ms: int = 0
var in_dungeon: bool = false

var _clock = null


func bind(clock) -> void:
	# Vlozena zavislost: modul se nikdy neptá `Time`/`OS` sam (docs/09 §9.10.4).
	_clock = clock


func tick(_ms: int) -> void:
	# SimWorld tickuje systemy po `advance(ms)`, takze `now_ms()` je uz posunuty.
	if _clock != null:
		world_time_ms = int(_clock.now_ms())


func hour() -> int:
	var ms_per_hour: int = Const.DAY_LENGTH_MS / 24
	return posmod(world_time_ms, Const.DAY_LENGTH_MS) / ms_per_hour


func minute() -> int:
	var ms_per_hour: int = Const.DAY_LENGTH_MS / 24
	var ms_per_minute: int = Const.DAY_LENGTH_MS / 1440
	return (posmod(world_time_ms, Const.DAY_LENGTH_MS) % ms_per_hour) / ms_per_minute


func time_of_day() -> String:
	# "HH:MM" pro zurnál a HUD (UI texty anglicky, docs/01 §1.6).
	return "%02d:%02d" % [hour(), minute()]


func is_night() -> bool:
	var h: int = hour()
	return h >= NIGHT_FROM_HOUR or h < NIGHT_TO_HOUR


func light_level() -> int:
	if in_dungeon:
		return LIGHT_DUNGEON
	return LIGHT_DAY
