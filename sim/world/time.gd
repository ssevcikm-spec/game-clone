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

# SVETLO - ROZHODNUTO UZIVATELEM 2026-10-06: varianta **V1** (presne to, co delaji
# oba emulatory). NamEReno v referencich (podklad: research/REJSTRIK-REFERENCI.md):
#   ServUO i ModernUO `Scripts/Misc/LightCycle.cs:13-16` maji DayLevel = 0,
#   NightLevel = 12, DungeonLevel = 26, JailLevel = 9; rozsah 0..30, kde
#   **0 = NEJJASNEJSI** (ClassicUO `IsometricLight.cs:69` to rika slovem:
#   "if overall is 0, we have MAXIMUM light").
#   ZADANI §10 bod 20 ("den 12, dungeon 26") mel prvni cast nespravnou: 12 je
#   NightLevel. V ZADANI je k tomu datumova poznamka (historie se neprepisuje).
#   `JailLevel = 9` zamerne NENI konstanta - veznice nemame a mrtva konstanta
#   je jen sum (docs/09: nefunkcni metriku smazat, ne nechat lezet).
const LIGHT_DAY: int = 0         # 0 = nejjasnejsi (neni to "nic")
const LIGHT_NIGHT: int = 12
const LIGHT_DUNGEON: int = 26

# Noc je 22:00-06:00 vcetne dvouhodinovych rampu (viz `_day_night_level`).
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
	# 22:00-06:00 = nocetne rampu; `_day_night_level()` dava v techto hodinach
	# hodnoty mezi dnem a noci (12 -> 0 a 0 -> 12).
	var h: int = hour()
	return h >= NIGHT_FROM_HOUR or h < NIGHT_TO_HOUR


func light_level() -> int:
	# Svetlo je cislo 0..30, kde 0 = nejjasnejsi (viz hlavicka). V dungeonu ho
	# region PREPISE tvrde (ServUO `Scripts/Regions/DungeonRegion.cs:63-66`
	# dela `global = LightCycle.DungeonLevel`, ne `min`).
	if in_dungeon:
		return LIGHT_DUNGEON
	return _day_night_level(hour(), minute())


func _day_night_level(h: int, m: int) -> int:
	# Doslovny prepis ze `_src/servuo/Scripts/Misc/LightCycle.cs:70-82`
	# (ModernUO ma tytez hodnoty na `.../Misc/LightCycle.cs:86-93`):
	#   h < 4        -> 12 (plna noc)
	#   4 <= h < 6   -> 12 + ((h-4)*60 + m) * (0 - 12) / 120    (ramp 12 -> 0)
	#   6 <= h < 22  -> 0  (den)
	#   22 <= h < 24 -> 0 + ((h-22)*60 + m) * (12 - 0) / 120    (ramp 0 -> 12)
	# Celociselne deleni se zaokrouhluje k nule (jako v C#), proto je i v
	# zapornem rampu chovani stejne jako v predloze - proto ta citace.
	if h < 4:
		return LIGHT_NIGHT
	if h < 6:
		return LIGHT_NIGHT + ((h - 4) * 60 + m) * (LIGHT_DAY - LIGHT_NIGHT) / 120
	if h < 22:
		return LIGHT_DAY
	return LIGHT_DAY + ((h - 22) * 60 + m) * (LIGHT_NIGHT - LIGHT_DAY) / 120
