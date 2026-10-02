extends RefCounted
# Herni cas (granule world.time, docs/04 §4.2, docs/05 §5.11).
#
# Den = 24 hernich hodin = DAY_LENGTH_MS = 7 200 000 ms (2 h realneho casu).
# Vychazi z `SecondsPerUOMinute = 5.0` - overeno v ServUO/ModernUO, docs/10 P12
# (v dokumentaci je i tabulka, ktera tvrdi 120 s; spravny je kod).
# Vse je v ms (int), modul si cas nedrzi sam - dostava ho od simulace
# (`world_time_ms` nastavuje SimWorld kazdy tick).

const Const = preload("res://core/const.gd")

# Svetlo: ZADANI §10 bod 20 uvadi den 12 a dungeon 26 (obojí overene cislo).
# NOC je otevrena vec - docs/11 §11.6 ji vede jako neoverenou (svetelny cyklus
# se ma merit z light.mul). Dokud se to nezmeri, vraci `light_level()` pres den
# i v noci denni hodnotu a je to videt v testu - nic se nedomysli.
const LIGHT_DAY: int = 12
const LIGHT_DUNGEON: int = 26

# Noc je ROZHODNUTI (22:00-06:00), ne overene cislo - viz hlavicka.
const NIGHT_FROM_HOUR: int = 22
const NIGHT_TO_HOUR: int = 6

var world_time_ms: int = 0
var in_dungeon: bool = false


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
