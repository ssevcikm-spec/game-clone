class_name SimWorld
extends RefCounted
# JADRO SIMULACE (docs/04 §4.2 a §4.7). Bezi bez sceny - jen `tick(ms)`.
#
# Co je dane smlouvou:
#   * tick je pevny (docs/02 §2.3), cas jde z `SimClock`, nahoda z `SimRng`,
#     serialy z `SimSerial`, udalosti do `SimEvents`, hash z `SimHash`,
#     prikazy pres `sim/commands.gd` - sim/ nikdy necte `Input`, `Time`, `OS`
#     ani `randf()` (docs/09 §9.10.4),
#   * `state_hash()` je SHA-256 kanonicke serializace (docs/04 §4.7); dva behy
#     se stejnym seedem a stejnymi prikazy musi dat stejny hash,
#   * save/load je JSON + gzip s `version` a `data_version`; kdyz se data
#     zmeni, save se ODMITNE (radsi nez tichy nesmysl).
#
# CO SMLOUVA NEPINUJE (nalezeno pri implementaci, patri do docs/04):
#   * poradi systemu v ticku neni nikde vypsane (prompt rika jen "pevne
#     poradi") - tady je poradi z tabulky §4.2 a `spawn` za nimi,
#   * `tick(ms)` pro vsechny systemy (prompt) je v rozporu s §4.2, kde ma
#     `sim.ai.tick(m:int)`, `sim.regen.tick()` a `sim.poison.tick()` bez ms;
#     proto se system vola `tick(ms)`, kdyz ho ma s argumentem, jinak `tick()`,
#   * `core.serial` nema getter aktualni hodnoty, ale save potrebuje
#     `next_serial` - SimWorld si proto pocet vydanych serialu drzi sam.

const Const = preload("res://core/const.gd")
const SimClock = preload("res://core/clock.gd")
const SimRng = preload("res://core/rng.gd")
const SimSerial = preload("res://core/serial.gd")
const SimEvents = preload("res://core/events.gd")
const SimHash = preload("res://core/hash.gd")
const SimCommands = preload("res://sim/commands.gd")
const SimScheduler = preload("res://sim/scheduler.gd")
const SimSave = preload("res://sim/save.gd")
const EntityRegistry = preload("res://sim/entity/registry.gd")

# Verze schematu save je v `sim/save.gd` (`SimSave.SAVE_VERSION`) - tady se
# nedrzi druha, aby nemohly vzniknout dve pravdy o tom, co je v souboru.
# Poradi z tabulky docs/04 §4.2; `spawn` je svetovy system, jde za nimi.
const SYSTEM_ORDER: Array[String] = [
	"movement", "interaction", "combat", "magic", "skill_gain", "harvest",
	"craft", "ai", "vendor", "loot", "death", "poison", "regen", "hunger", "spawn",
]

var seed: int = 0
var player_serial: int = 0
var systems: Dictionary = {}
var data_version: String = ""
# Registr bytosti (granule `sim.entity_registry`): JEDINE misto, kde se mobil
# hleda podle serialu. Do 2026-10-09 si ho `app/main` delal sam - tim padem ho
# ale `SimWorld` nevidel a nemohl ho registrovat jako stavovy zdroj, takze se
# mobily NEUKLADALY (pojmenovany dluh v `sim/save.gd`). Ted je vlastnikem svet
# a `app/main` si ho bere odtud (`sim.registry`), aby existovala JEDNA instance.
var registry

var _clock
var _rng
var _serials
var _events
var _hash
var _commands
var _scheduler
var _save
var _sources: Dictionary = {}
var _queue: Array[Dictionary] = []
var _serials_issued: int = 0


func _init(seed_value: int = 0, data: Dictionary = {}) -> void:
	seed = seed_value
	_clock = SimClock.new()
	_rng = SimRng.new(seed)
	_serials = SimSerial.new()
	_events = SimEvents.new()
	_hash = SimHash.new()
	_commands = SimCommands.new()
	_save = SimSave.new()
	_scheduler = SimScheduler.new(_clock)
	registry = EntityRegistry.new()
	register_state_source("scheduler", _scheduler)
	# Entity (mobily) jsou stavovy zdroj od 2026-10-09: `registry.state()` da
	# vsechny mobily serazene podle serialu. Zmena TVARU vstupu do hashe -
	# doklad a prepnuti replayu je v `tests/replays/README.md` ("Historie hashů").
	register_state_source("entities", registry)
	data_version = _hash.of_state([data])


# -- rozhrani pro klienta --------------------------------------------------

func enqueue(command: Dictionary) -> void:
	if command is Dictionary:
		_queue.append(command)
	else:
		push_event("message", {"text": "Invalid command (not a dictionary).", "kind": "system"})


func tick(ms: int) -> void:
	_clock.advance(ms)
	# RIDKE UDALOSTI SVETA (granule `sim.scheduler`, milnik MK): cas uz plyne,
	# takze se vyrizi, co je splatne - PRED systemy i prikazy (stejne jako
	# reference: server nejdriv zpracuje frontu timeru, teprve pak packet).
	# Udalost jde do fronty udalosti, aby byla VIDET ("co se stalo, kdyz jsem
	# nebyl" - `ui.journal`); planovac sam nic nevykonava, jen rika co a kdy.
	for due in _scheduler.advance_to(_clock.now_ms()):
		push_event("world_event", due)
	var batch: Array[Dictionary] = _queue
	_queue = []
	# ⚠ PORADI JE PRAVIDLO, NE DETAIL (namEReno 2026-10-07, vada V1 z
	# `REVIZE-POHYB-2026-10-07.md` §2.1): systemy se tickuji PRED prikazy.
	# Kdyz se prikazy dispatchovaly prvni, krok, ktery je v tomto ticku na rade
	# (`due_ms <= now`), se jeste neaplikoval - a `sim.movement.request_step`
	# ho videl jako `busy`. Klient ale svuj 400ms casovac opakovani spotreboval
	# uz pri VYDANI prikazu, takze dalsi pokus prisel az za dalsich 400 ms ->
	# namERENA kadence byla **718 ms (a 530 ms) misto 400** a byla nepravidelna.
	# Cas v ticku plyne takto: nejdriv svet (timery), pak cizi zamery - stejne
	# jako server, ktery nejdriv zpracuje frontu timeru a teprve pak packet.
	for name in SYSTEM_ORDER:
		if systems.has(name):
			_tick_system(systems[name], ms)
	for command in batch:
		_commands.dispatch(self, command)


func advance_offline(ms: int) -> Array[Dictionary]:
	# DOBEH SVETA (granule `sim.offline`, milnik MK): posune hodiny sveta
	# a vyrize, co je v planovaci splatne - ale NETIKUJE systemy.
	#
	# PROC TAK: mimo obrazovku je svet FUNKCE CASU, ne simulace agentu
	# (`docs/01 §1.8` F1; `NAVRH-BRAN-FEEL-2026-10-09.md` §2). Kdyby dobeh
	# tickoval vsechno, stal by jeden navrat po tydnu absenci hodiny CPU
	# a byl by nereprodukovatelny - presne to hlida kontrola 3 brany F1.
	# Prikazy se taky nevyrizuji: nikdo nehraje, fronta je prazdna.
	#
	# Vraci vyrizene udalosti, aby je volajici mohl dat do logu (stejna
	# smlouva jako `sim.scheduler.advance_to`).
	if ms <= 0:
		return []
	_clock.advance(ms)
	var out: Array[Dictionary] = []
	for due in _scheduler.advance_to(_clock.now_ms()):
		var e: Dictionary = due
		push_event("world_event", e)
		out.append(e)
	return out


func snapshot() -> Dictionary:
	# Read-only pohled pro klienta; udalosti se vybiraji jednou za frame
	# (docs/04 §4.4), proto je snapshot rovnou vydava a fronta se vyprazdni.
	var names: Array = systems.keys()
	names.sort()
	return {
		"seed": seed,
		"world_time_ms": world_time(),
		"player_serial": player_serial,
		"systems": names,
		"mobiles": [],
		"items": [],
		"events": drain_events(),
	}


func state_hash() -> String:
	var names: Array = systems.keys()
	names.sort()
	return _hash.of_state([
		seed,
		world_time(),
		_rng.state(),
		next_serial_value(),
		player_serial,
		names,
		[],
		[],
		# Stavove zdroje (od 2026-10-09; prvni je `sim.scheduler`, od teto
		# session i `entities` = mobily): bez nich by hash netvrdil nic
		# o BUDOUCNOSTI sveta (fronta udalosti) ani o TELECH ve svete.
		# Dve prazdna pole vyse jsou obalka v1 (`mobiles`/`items`) - zustavaji
		# kvuli `docs/04 §4.7`, ale stav entit je ve zdroji `entities`.
		_save.collect(_sources),
	])


func save(path: String) -> bool:
	var payload: Dictionary = {
		"version": _save.version(),
		"data_version": data_version,
		"state_hash": state_hash(),
		"seed": seed,
		"world_time_ms": world_time(),
		# POZOR (namEReno 2026-10-02): Godotuv JSON.parse_string vraci VSECHNA
		# cisla jako float (TYPE_FLOAT), takze 64bitovy stav RNG by se cestou
		# tise poskodil (748695878776107324 -> 748695878776107264). Proto se
		# hodnoty > 2^53 ukladaji jako desetinovy retezec a cte se pres int().
		"rng_state": {"state": str(_rng.state()["state"]), "inc": str(_rng.state()["inc"])},
		"next_serial": next_serial_value(),
		# ⚠ OBALKA v1 (`mobiles`, `items`, `spawn_state`) zustava, i kdyz ma stav
		# entit od 2026-10-09 svuj domov ve `sources["entities"]`: `docs/04 §4.7`
		# ji porad vyjmenovava a `spawn_state` je pripraveny klíč pro `world.spawn`
		# (M5). Prazdny seznam tady NENI tvrzeni "zadni mobily" - pravda je
		# v `sources` (a `load()` cte jen ji); kdo je chce naplnit, at je naplni
		# stavovym zdrojem, ne druhou kopii.
		"mobiles": [],
		"items": [],
		"spawn_state": [],
		"player_serial": player_serial,
		"position_serial": 0,
		# Stavove zdroje (docs/04 §4.7; `scheduler` + `entities`). Uklada se
		# CELEK, ne cast - castecny save by rozbil vazby (research/08 bod 13).
		"sources": _save.collect(_sources),
	}
	if not _save.write(path, payload):
		push_event("message", {"text": "Save failed: cannot open " + path, "kind": "system"})
		return false
	return true


func load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_event("message", {"text": "Load failed: no save at " + path, "kind": "system"})
		return false
	var payload: Dictionary = _save.read(path)
	if payload.is_empty():
		push_event("message", {"text": "Load failed: cannot read " + path, "kind": "system"})
		return false
	# Starsi save se MIGRUJE, novejsi se ODMITNE (radsi "nevim, co v tom je"
	# nez tichy nesmysl). Verze i migrace patri do `sim/save.gd`.
	var migrated: Dictionary = _save.migrate(payload, int(payload.get("version", 0)))
	if migrated.is_empty():
		push_event("message", {"text": "Load failed: unsupported save version.", "kind": "system"})
		return false
	payload = migrated
	if str(payload.get("data_version", "")) != data_version:
		push_event("message", {"text": "Load failed: data changed since the save.", "kind": "system"})
		return false

	seed = int(payload.get("seed", 0))
	_clock = SimClock.new()
	_clock.advance(int(payload.get("world_time_ms", 0)))
	_rng = SimRng.new(seed)
	var rng_state = payload.get("rng_state")
	if rng_state is Dictionary:
		_rng.restore({
			"state": int(str(rng_state.get("state", "0"))),
			"inc": int(str(rng_state.get("inc", "1"))),
		})
	_serials = SimSerial.new()
	_serials_issued = maxi(int(payload.get("next_serial", 1)) - 1, 0)
	_serials.reset(_serials_issued + 1)
	player_serial = int(payload.get("player_serial", 0))
	_queue.clear()
	# ⚠ Stavove zdroje se vraci PRED kontrolou hashe - hash je pocita, takze
	# bez tohoto poradi by round-trip hlasil rozchod, ktery v datech neni.
	_save.apply(_sources, payload.get("sources", {}))
	# Kontrola integrity: co jsme ulozili, to musi po nacteni vyjit stejne.
	var expected := str(payload.get("state_hash", ""))
	if expected != "" and state_hash() != expected:
		push_event("message", {"text": "Load failed: state hash mismatch.", "kind": "system"})
		return false
	return true


# -- to, co pouzivaji systemy a prikazy ------------------------------------

func world_time() -> int:
	return _clock.now_ms()


func clock():
	return _clock


func scheduler():
	# Ridke udalosti sveta (docs/05 §5.12: jeden world tick misto tisicu
	# spawneru). Stav planovace JE v `state_hash()` i v save od 2026-10-09
	# (jako stavovy zdroj) - zmena specu odsouhlasena uzivatelem.
	return _scheduler


func register_state_source(name: String, source) -> void:
	# Kdo ma stav, ktery patri do save a do hashe, zaregistruje se tady a musi
	# umet `state()`/`restore(d)` (docs/04 §4.7). Uklada se CELEK, ne cast.
	# Jmena se v save radi, takze poradi registrace nic neovlivnuje.
	if source == null or not source.has_method("state") or not source.has_method("restore"):
		push_warning("SimWorld.register_state_source: zdroj '%s' neumi state()/restore()" % name)
		return
	_sources[name] = source


func state_source_names() -> Array:
	var names: Array = _sources.keys()
	names.sort()
	return names


func rng():
	return _rng


func events():
	return _events


func next_serial() -> int:
	_serials_issued += 1
	return _serials.next()


func next_serial_value() -> int:
	return _serials_issued + 1


func push_event(name: String, data: Dictionary) -> void:
	_events.push(name, data)


func drain_events() -> Array[Dictionary]:
	return _events.drain()


# -- vnitrni ---------------------------------------------------------------

func _tick_system(system, ms: int) -> void:
	for method in system.get_method_list():
		if method["name"] != "tick":
			continue
		if method["args"].size() >= 1:
			system.tick(ms)
		else:
			system.tick()
		return
