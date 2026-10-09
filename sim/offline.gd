extends RefCounted
# sim.offline - SVET JDE DAL I BEZ HRACE (granule `sim.offline`, milnik MK).
#
# CO TO JE: dobeh sveta jako FUNKCE CASU. "Offline" znamena BEZ PRIPOJENEHO
# KLIENTA, ne "bez hrace" (rozhodnuti D9, `ROZHODNUTI-2026-10-09-SMER.md`) -
# hodiny sveta bydli v simulaci, takze singleplayer, session u hostitele
# i always-on server jsou TENTYZ KOD.
#
# Mimo obrazovku se NESIMULUJI agenti (to je `sim.ai`, M5) - pocitaji se
# ROZVRHY: kdy se doplni spawn, kdy se obnovi zasoby, kdy se prepoctou ceny.
# Kazda zmena je odvozena z ABSOLUTNIHO casu sveta, a proto:
#   * druhy dobeh na tyz cas nic nemeni (kontrola 4 brany F1),
#   * je jedno, jestli se dobeh zavola jednou, nebo po davkach (kontrola 5),
#   * dva behy se stejnym seedem daji stejny hash (kontrola 2).
#
# CAS JE ARGUMENT (`now_unix`), ne `Time`/`OS`: `sim/` nesmi cist hodiny
# (docs/09 §9.10 bod 4) a vynucuje to brana G2. Kdo modul pouziva, preda mu
# cas zvenci (`app/` smi cist hodiny, `sim/` ne).
#
# MAPA JE VSTUP, NE KONSTANTA: rozvrh doplneni spawnu potrebuje rozmery sveta,
# takze `_init(world, start_unix, map)`. V CI zadna mapa NENI (`assets/uo/` je
# v .gitignore) - proto se predava fixture (`tests/fixtures/world/`) a brana F1
# tim meri i to, ze modul na assetech nezavisi. Bez mapy je `map_blocks` nula
# (VIDITELNE v reportu), ne ticha vymyka.
#
# STROPY (docs/05 §5.12 - jeden world tick misto tisicu spawneru):
#   * `MAX_CATCHUP_MS` - rocni absence svet nedobehne; dobehne se nejvys
#     tyden realneho casu (a `capped: true` to rekne nahlas),
#   * `MAX_EVENTS_PER_CATCHUP` - strop poctu naplanovanych udalosti jednoho
#     dobehu (denni strop je dany rozvrhem: kazdy druh ma svuj interval).
#
# CO ZATIM NENI (pojmenovane, ne tichy dluh):
#   * **rozvrhy nikdo nekonzumuje.** `spawn_refill`, `vendor_restock`
#     a `price_update` jsou UDALOSTI v planovaci - vezme si je `world.spawn`
#     (M5) a `sim.vendor` (MK). Do te doby je dobeh mechanismus, ktery je ale
#     VIDET: udalosti jdou pres `SimWorld.advance_offline` do fronty jako
#     `world_event` (a `ui.journal` je umi vypsat),
#   * **dobeh netikuje `world.time`** - modul casu si precte `clock.now_ms()`
#     v nejblizsim tiku hry; behem dobehu ho nikdo nepotrebuje (rozvrhy jsou
#     absolutni, ne odvozene z `hour()`),
#   * **`sim.offline` NENI stavovy zdroj.** Vsechno, co vi, je odvodene
#     z hodin sveta a z `_start_unix` (konfigurace) - kdyby si drzel vlastni
#     "naposledy dobehnuto", muselo by to byt v save i v hashi a byla by to
#     druha pravda o case, ktery uz v hashi je (`world_time()`).

const Const = preload("res://core/const.gd")

const MS_PER_HOUR: int = 1000 * 60 * 60
const MS_PER_DAY: int = 24 * MS_PER_HOUR
# Krok dobehu = JEDNA HERNI HODINA (300 000 ms sveta = 5 realnych minut;
# `world.time` ma den = `Const.DAY_LENGTH_MS` = 2 realne hodiny).
const STEP_MS: int = Const.DAY_LENGTH_MS / 24
# Strop dobehu: tyden realneho casu. Rocni absence se dobehne jen po tento
# strop a `capped` to rekne - "svet se posunul o rok" by znamenalo hodiny CPU.
const MAX_CATCHUP_MS: int = 7 * MS_PER_DAY
const MAX_EVENTS_PER_CATCHUP: int = 512
const MAX_STEPS: int = MAX_CATCHUP_MS / STEP_MS + 2

# ROZVRHY: co se deje samo, kdyz se nikdo nediva. `every_ms` je v ms sveta;
# udalost padne na ABSOLUTNI nasobek intervalu (`k * every_ms`), nikdy na
# "interval od ted" - na tom stoji nezavislost na davkovani.
const SCHEDULE: Array[Dictionary] = [
	{"kind": "spawn_refill", "every_ms": Const.DAY_LENGTH_MS / 4, "why": "doplneni spawnu"},
	{"kind": "vendor_restock", "every_ms": Const.DAY_LENGTH_MS, "why": "denni obnova zasob"},
	{"kind": "price_update", "every_ms": Const.DAY_LENGTH_MS / 2, "why": "prepocet cen"},
]

var _world = null
var _start_unix: int = 0
var _map = null
var _report: Dictionary = {}
var _steps_total: int = 0
var _events_total: int = 0


func _init(world = null, start_unix: int = 0, map = null) -> void:
	_world = world
	_start_unix = int(start_unix)
	_map = map
	_report = _empty_report(0)


func target_ms(now_unix: int) -> int:
	# ABSOLUTNI cil dobehu: svet ma byt presne tam, kde byl v case `now_unix`
	# (`_start_unix` je okamzik, kdy byl svet na case 0; app si ho odvodi jako
	# `now - world_time()/1000`, takze se nikam neuklada).
	return maxi((int(now_unix) - _start_unix) * 1000, 0)


func advance_to(now_unix: int) -> Dictionary:
	# Dobeh sveta na absolutni cas `now_unix`. Vraci report (jako
	# `elapsed_report()`), aby se dalo merit, co se stalo.
	if _world == null:
		_report = _empty_report(0)
		return _report
	var from_ms: int = int(_world.world_time())
	var target: int = target_ms(now_unix)
	var capped: bool = false
	if target > from_ms + MAX_CATCHUP_MS:
		target = from_ms + MAX_CATCHUP_MS
		capped = true
	# 1) Naplanuj, co ma v tom okne nastat (funkce casu, zadny stav).
	var events: int = _plan(from_ms, target)
	var capped_events: bool = events >= MAX_EVENTS_PER_CATCHUP
	# 2) Posun hodiny po krocich a vyrizuj, co je splatne. Hranice kroku jsou
	#    ABSOLUTNI nasobky `STEP_MS`, ne "od aktualniho casu" - jinak by
	#    hranice zavisely na tom, jak volajici davkuje (kontrola 5).
	var steps: int = 0
	var fired: int = 0
	var current: int = from_ms
	while current < target and steps < MAX_STEPS:
		var next: int = (current / STEP_MS + 1) * STEP_MS
		var to_ms: int = mini(next, target)
		fired += _world.advance_offline(to_ms - current).size()
		current = to_ms
		steps += 1
	_steps_total += steps
	_events_total += events
	_report = {
		"from_ms": from_ms,
		# `to_ms` se CTE z hodin sveta (ne z `current`): dobeh, ktery cas
		# preskoci nebo pricte dvakrat, se tim musi projevit v mereni.
		"to_ms": int(_world.world_time()),
		"target_ms": target,
		"advanced_ms": int(_world.world_time()) - from_ms,
		"steps": steps,
		"events": events,
		"fired": fired,
		"capped": capped,
		"capped_events": capped_events,
		"pending": _pending(),
		"mobiles": _mobiles(),
		"map_blocks": _map_blocks(),
		"steps_total": _steps_total,
		"events_total": _events_total,
	}
	return _report


func elapsed_report() -> Dictionary:
	# Naposledy zmereny dobeh (`{}` pred prvnim - nikdy "tichy uspech").
	return _report.duplicate(true)


# -- vnitrni ---------------------------------------------------------------

func _plan(from_ms: int, target: int) -> int:
	# Naplanuje vsechny rozvrhove udalosti, ktere padnou do `(from_ms, target]`.
	# POCITA SE Z ABSOLUTNIHO CASU: prvni nasobek intervalu po `from_ms`, pak
	# dalsi. Zadny stav se nedrzi, takze volani po davkach da tyz vysledek.
	if _world == null or target <= from_ms:
		return 0
	var scheduler = _world.scheduler()
	if scheduler == null:
		return 0
	var count: int = 0
	var blocks: int = _map_blocks()
	for row in SCHEDULE:
		var every: int = int(row["every_ms"])
		if every <= 0:
			continue
		var at: int = (from_ms / every + 1) * every
		while at <= target and count < MAX_EVENTS_PER_CATCHUP:
			# Payload je DATA (ne closure): da se ulozit, obnovit a precist
			# z logu - stejne pravidlo jako `sim.scheduler`.
			scheduler.schedule(str(row["kind"]), at,
				{"why": str(row["why"]), "map_blocks": blocks})
			count += 1
			at += every
	return count


func _pending() -> int:
	var scheduler = _world.scheduler() if _world != null else null
	return int(scheduler.pending()) if scheduler != null else 0


func _mobiles() -> int:
	# Pocet entit ve svete (report to ukazuje jako merenou hodnotu, aby se
	# "zadna entita netikla" dalo overit, ne jen tvrdit).
	var registry = _world.registry if _world != null else null
	if registry == null or not registry.has_method("size"):
		return 0
	return int(registry.size())


func _map_blocks() -> int:
	# Pocet bloku 8x8 v nactene mape; 0 = mapa neni (a je to VIDET).
	if _map == null or not _map.has_method("width") or not _map.has_method("height"):
		return 0
	var w: int = int(_map.width()) / int(Const.BLOCK_SIZE)
	var h: int = int(_map.height()) / int(Const.BLOCK_SIZE)
	return w * h


func _empty_report(target: int) -> Dictionary:
	return {
		"from_ms": 0, "to_ms": 0, "target_ms": target, "advanced_ms": 0,
		"steps": 0, "events": 0, "fired": 0, "capped": false, "capped_events": false,
		"pending": 0, "mobiles": 0, "map_blocks": 0,
		"steps_total": 0, "events_total": 0,
	}
