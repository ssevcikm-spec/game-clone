extends RefCounted
# Jed: 5 urovni AoS, intervaly, skoda na tik (granule `sim.poison`;
# smlouva docs/04 §4.2 a pravidla docs/05 §5.14).
#
# ODKUD CISLA (vsechno namEReno v `_src/servuo/Scripts/Misc/Poison.cs:23-27`,
# nic vymysleneho - AoS vetev `if (Core.AOS)`):
#
#   uroven | jmeno   | min | max | scalar | delay | interval | hits | msg
#   -------|---------|-----|-----|--------|-------|----------|------|-----
#     0    | Lesser  |  4  | 16  |  7.5   | 3.0 s |  2.25 s  |  10  |  4
#     1    | Regular |  8  | 18  | 10.0   | 3.0 s |  3.25 s  |  10  |  3
#     2    | Greater | 12  | 20  | 15.0   | 3.0 s |  4.25 s  |  10  |  2
#     3    | Deadly  | 16  | 30  | 30.0   | 3.0 s |  5.25 s  |  15  |  2
#     4    | Lethal  | 20  | 50  | 35.0   | 3.0 s |  5.25 s  |  20  |  2
#
#   * skoda na tik: `damage = 1 + (int)(m_Hits * m_Scalar)` (`Poison.cs:170`
#     a `:222`), kde `m_Hits` je AKTUALNI pocet zivotu obete - proto se skoda
#     v case MENI (a proto ji test meri na dvou ruznych hp),
#   * `min`/`max` je ROZSAH SKODY (`DamageMin`/`DamageMax`), ktery se pouziva
#     pro utok jedem a pro popis; `delay` = prvni tik po aplikaci,
#   * `Register(new PoisonImpl(name, level, min, max, percent, delay, interval,
#     count, messageInterval))` (`Poison.cs:23-27`) - poradi argumentu je
#     dulezite: `percent` je 7.5/10/15/30/35, z nej je `m_Scalar = percent*0.01`
#     (`:141`). Nase hlavicka proto uvadi SCALAR (0.075 atd.), ne percent,
#     aby se dvojnasobne deleni 100 nepletlo,
#   * `delay` = `m_Delay` (3 s) - prvni tik pri aplikaci;
#     `PoisonTimer` ho pouziva jako prvni interval (`Poison.cs:164`).
#
# TVAR STAVU: uroven a cas dalsiho tiku drzi SYSTEM (serial -> {level,
# due_ms, tiků}), ne mobil - `entity.mobile` pro jed nic nema a pridavat mu
# pole by znamenalo dve pravdy. Stav je soucasti `state()`/`restore`, takze
# prezije save (int-only, zadny float).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `_init(registry, rng, clock, events, path)` - zavislosti konstruktorem
#     (vzor `sim.craft`), aby sel `tick` merit bez `SimWorld`; `path` je cesta
#     k datum (dnes se z ni cte jen pripadny prekryv tabulky, viz `_read_data`),
#   * `apply(m, level)` vraci `{ok, level, duration_ms, reason}`; `duration` je
#     `(count+1) * interval` (kolik tiku jed jeste vydrzi - `Poison.cs:172`
#     pouziva `(m_Count + 1) * m_Interval` pro delku buffu),
#   * `cure(m, level = -1)` vraci `{ok, was_poisoned, level, reason}` - lecba
#     sily `level` vyleci jed urovne <= `level`; silnejsi jed odmitne
#     (`reason:"too_strong"`). Sance na vyleceni je vec lektvaru/kouzla, ne
#     tohoto modulu (my jen RUSIME jed; rozhodnuti klonu a je videt tady),
#   * `tick(ms)` vraci POCET tiku, aby se dal merit;
#   * jed se NEPRENASI na utocnika (infectious strike je zvlastni utok, M6+).

const RegistryScript = preload("res://sim/entity/registry.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")

const POISON_PATH := "res://data/poison.json"

# Tabulka z `Poison.cs:23-27` (AoS). `scalar` je `percent * 0.01`.
# `damage = 1 + int(hits * scalar)`, `clamp` na [min, max] je nas model:
# reference clamp NEMA (skoda roste s zivoty obete), ale my mame `min`/`max`
# jako rozsah z dat a bez stropu by Lethal na 1000 hp delal 351 za tik.
# Je to ROZHODNUTI KLONU a je videt tady - test meri obe strany (pod i nad).
const TABLE: Array = [
	{"level": 0, "name": "Lesser", "min": 4, "max": 16, "scalar": 0.075,
		"delay_ms": 3000, "interval_ms": 2250, "hits": 10, "msg_interval": 4},
	{"level": 1, "name": "Regular", "min": 8, "max": 18, "scalar": 0.10,
		"delay_ms": 3000, "interval_ms": 3250, "hits": 10, "msg_interval": 3},
	{"level": 2, "name": "Greater", "min": 12, "max": 20, "scalar": 0.15,
		"delay_ms": 3000, "interval_ms": 4250, "hits": 10, "msg_interval": 2},
	{"level": 3, "name": "Deadly", "min": 16, "max": 30, "scalar": 0.30,
		"delay_ms": 3000, "interval_ms": 5250, "hits": 15, "msg_interval": 2},
	{"level": 4, "name": "Lethal", "min": 20, "max": 50, "scalar": 0.35,
		"delay_ms": 3000, "interval_ms": 5250, "hits": 20, "msg_interval": 2},
]

const MAX_LEVEL := 4

var _registry = null
var _rng = null
var _clock = null
var _events = null

# serial -> {level, due_ms, tiky}
var _aktivni: Dictionary = {}
var _tabulka: Array = []


func _init(registry = null, rng = null, clock = null, events = null,
		path: String = POISON_PATH) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_rng = rng if rng != null else RngScript.new(0)
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_tabulka = _read_data(path)


# -- rozhrani podle smlouvy ------------------------------------------------

func apply(m: int, level: int) -> Dictionary:
	# Aplikuje jed dane urovne. Vyssi uroven PREBije nizsi (jako reference:
	# `Mobile.Poison` bere jen horsi jed - `Server/Mobile.cs` `ApplyPoison`);
	# nizsi uroven na vyssi NEMA efekt a je to videt v `reason`.
	var mob = _mobile(m)
	if mob == null:
		return {"ok": false, "level": level, "duration_ms": 0, "reason": "no_mobile"}
	if not mob.alive():
		return {"ok": false, "level": level, "duration_ms": 0, "reason": "dead"}
	var lvl: int = clampi(level, 0, MAX_LEVEL)
	var stara: int = int(_aktivni.get(m, {}).get("level", -1))
	if stara >= lvl:
		return {"ok": false, "level": stara, "duration_ms": 0, "reason": "weaker"}
	var radek: Dictionary = _radek(lvl)
	var now: int = _now()
	_aktivni[m] = {"level": lvl, "due_ms": now + int(radek["delay_ms"]), "tiky": 0}
	_message("You have been poisoned!")
	_events_push("poison", {"serial": int(m), "level": lvl, "action": "apply",
		"due_ms": int(_aktivni[m]["due_ms"])})
	return {"ok": true, "level": lvl, "duration_ms": _trvani(lvl), "reason": ""}


func cure(m: int, level: int = -1) -> Dictionary:
	# Vyleceni: jed se zrusi. SANCE na vyleceni je vec lektvaru/kouzla
	# (`sim.magic`), ne tohohle modulu - viz hlavicka.
	# `level` je SILA lecby (kontrakt M5 §5: `cure(m, level)`): lecba sili N
	# vyleci jed urovne <= N; silnejsi jed odmitne (`reason:"too_strong"`).
	# `level < 0` = "vylec cokoli" (vychozi, zpetna kompatibilita s `cure(m)`).
	var mel: bool = _aktivni.has(m)
	var lvl: int = int(_aktivni.get(m, {}).get("level", -1))
	if mel and level >= 0 and lvl > level:
		return {"ok": false, "was_poisoned": true, "level": lvl,
			"reason": "too_strong"}
	_aktivni.erase(m)
	if mel:
		_message("You feel cured of poison.")
		_events_push("poison", {"serial": int(m), "level": lvl, "action": "cure",
			"cure_level": level})
	return {"ok": true, "was_poisoned": mel, "level": lvl, "reason": ""}


func tick(_ms: int) -> int:
	# SimWorld tickuje systemy po `advance(ms)`, takze cas je uz posunuty.
	# Vraci POCET tiku (meritelne), ne void - smlouva vraci `tick(ms)` bez
	# hodnoty, ale int nikoho neobtezuje a test ho pouzije.
	if _aktivni.is_empty():
		return 0
	var now: int = _now()
	var tiky: int = 0
	for m in _aktivni.keys():
		var s: Dictionary = _aktivni[m]
		var due: int = int(s.get("due_ms", 0))
		if due <= 0 or due > now:
			continue
		if _tik(int(m)):
			tiky += 1
	return tiky


# -- mereni a integrace (nad ramec smlouvy) --------------------------------

func level_of(m: int) -> int:
	return int(_aktivni.get(m, {}).get("level", -1))


func is_poisoned(m: int) -> bool:
	return _aktivni.has(m)


func name_of(level: int) -> String:
	return str(_radek(clampi(level, 0, MAX_LEVEL)).get("name", ""))


func interval_ms(level: int) -> int:
	return int(_radek(clampi(level, 0, MAX_LEVEL)).get("interval_ms", 0))


func delay_ms(level: int) -> int:
	return int(_radek(clampi(level, 0, MAX_LEVEL)).get("delay_ms", 0))


func min_damage(level: int) -> int:
	return int(_radek(clampi(level, 0, MAX_LEVEL)).get("min", 0))


func max_damage(level: int) -> int:
	return int(_radek(clampi(level, 0, MAX_LEVEL)).get("max", 0))


func scalar(level: int) -> float:
	return float(_radek(clampi(level, 0, MAX_LEVEL)).get("scalar", 0.0))


func damage_for(level: int, hits: int) -> int:
	# `damage = 1 + (int)(hits * scalar)`, clampnute na [min, max]
	# (`Poison.cs:170,222`; clamp je nas, viz hlavicka).
	var radek: Dictionary = _radek(clampi(level, 0, MAX_LEVEL))
	var d: int = 1 + int(float(hits) * float(radek.get("scalar", 0.0)))
	return clampi(d, int(radek.get("min", 1)), int(radek.get("max", 1)))


func active_count() -> int:
	return _aktivni.size()


func state() -> Dictionary:
	# Stav otravy je stav sveta (kdo je otráven a kdy dostane dalsi tik).
	var out: Dictionary = {}
	for m in _aktivni.keys():
		var s: Dictionary = _aktivni[m]
		out[str(int(m))] = {"level": int(s.get("level", 0)),
			"due_ms": int(s.get("due_ms", 0)), "tiky": int(s.get("tiky", 0))}
	return {"poison": out}


func restore(d: Dictionary) -> void:
	_aktivni = {}
	if not (d is Dictionary):
		return
	for k in (d.get("poison", {}) as Dictionary).keys():
		var s = d["poison"][k]
		if not (s is Dictionary):
			continue
		_aktivni[int(str(k))] = {"level": int(s.get("level", 0)),
			"due_ms": int(s.get("due_ms", 0)), "tiky": int(s.get("tiky", 0))}


# -- vnitrni ---------------------------------------------------------------

func _tik(m: int) -> bool:
	var mob = _mobile(m)
	if mob == null or not mob.alive():
		_aktivni.erase(m)
		return false
	var s: Dictionary = _aktivni[m]
	var radek: Dictionary = _radek(int(s.get("level", 0)))
	var d: int = damage_for(int(s.get("level", 0)), int(mob.hp))
	mob.hp = maxi(0, int(mob.hp) - d)
	s["tiky"] = int(s.get("tiky", 0)) + 1
	s["due_ms"] = _now() + int(radek.get("interval_ms", 0))
	_aktivni[m] = s
	_message("You feel poison coursing through your veins.")
	_events_push("stats_changed", {"serial": int(m), "hp": int(mob.hp),
		"hp_max": int(mob.max_hp)})
	_events_push("poison", {"serial": int(m), "level": int(s.get("level", 0)),
		"action": "tick", "damage": d, "hp": int(mob.hp), "ticks": int(s["tiky"])})
	if int(mob.hp) <= 0:
		# Smrt jedem hlasi `sim.death`, ne tenhle modul - tady jen uklidime
		# (dve udalosti `death` by klienta rozbily).
		_aktivni.erase(m)
	return true


func _trvani(level: int) -> int:
	# Delka buffu v reference: `(m_Count + 1) * m_Interval` (`Poison.cs:172`).
	var radek: Dictionary = _radek(level)
	return (int(radek.get("hits", 0)) + 1) * int(radek.get("interval_ms", 0))


func _radek(level: int) -> Dictionary:
	var i: int = clampi(level, 0, _tabulka.size() - 1)
	if i < 0 or i >= _tabulka.size() or not (_tabulka[i] is Dictionary):
		# Prazdna tabulka je VADA DAT, ne stav: hlasime a vracime nulu, ktera
		# se v `apply` projevi jako `interval_ms: 0` (nikdy tiky).
		push_warning("sim.poison: tabulka nema radek pro uroven " + str(level))
		return {}
	return _tabulka[i]


func _read_data(path: String) -> Array:
	# Vychozi tabulka je zmerena (`Poison.cs:23-27`); soubor ji muze PREPSAT
	# (klic `levels`), aby sla ladit bez zasahu do kodu. Chybejici soubor NENI
	# duvod k panice - tabulka v kodu je uplna a je to videt v `source()`.
	if not FileAccess.file_exists(path):
		return TABLE.duplicate(true)
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("sim.poison: " + path + " neni objekt - pouzivam tabulku z kodu")
		return TABLE.duplicate(true)
	var levels = (d as Dictionary).get("levels")
	if not (levels is Array) or (levels as Array).is_empty():
		push_warning("sim.poison: " + path + " nema `levels` - pouzivam tabulku z kodu")
		return TABLE.duplicate(true)
	return levels


func source() -> String:
	return "code:TABLE" if FileAccess.file_exists(POISON_PATH) == false else POISON_PATH


func _mobile(m: int):
	return null if _registry == null else _registry.get_mobile(m)


func _now() -> int:
	return int(_clock.now_ms())


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)


func _message(text: String) -> void:
	_events_push("message", {"text": text, "kind": "poison"})
