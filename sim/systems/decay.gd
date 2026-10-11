extends RefCounted
# Rozpad predmetu na zemi a tela (granule `sim.decay`; pravidla docs/05 §5.4).
#
# ODKUD CISLA (nevymyslena):
#   * predmet na zemi (polozeny): **60 minut** (docs/05 §5.4 "Rozpad na zemi
#     60 minut"; `core/const.gd` den = 2 h, takze 60 min = pul herniho dne),
#   * telo (corpse): **7 minut**, pravo na loot **2 minuty** (docs/05 §5.4
#     a §5.13; `docs/04 §4.6.7`: "tělo zůstává 7 min"),
#   * casy jsou ZDE jedina pravda: `sim.death` si je bere odsud
#     (`decay_ms()`/`loot_ms()`), takze dve cisla tehoz nemohou vzniknout
#     (docs/05 §5.16.3, pravidlo 2).
#
# MODEL: decay je JEDEN svetovy system s frontou (jako `sim.spawn`: "jeden
# world tick misto tisicu spawneru", docs/05 §5.12). Kazdy predmet ma svuj
# `due_ms` (herni cas) - stav casovacu je v SYSTEMU, ne Callable v clocku
# (pravidlo 5 kontraktu), proto se fronta da ulozit a porovnat.
#
# ODSTRANENI je ctverkrokove a kazdy krok je videt:
#   1. predmet se odebere z kontejneru (`sim.entity.container.remove`),
#   2. kdyz je to telo, odebere se i jeho OBSAH (telo se rozpadne i s obsahem -
#      docs/05 §5.4, v zadani M5: "tělo po 7 min (i s obsahem)") a obsah se
#      zapomene i v evidenci predmetu,
#   3. predmet se zapomene v evidenci predmetu (`_items` je Dictionary nebo
#      objekt s `remove`) - bez toho by objekt zustal v `items` navzdy a klient
#      by kreslil predmet, ktery uz neexistuje,
#   4. posle se udalost `item_removed{serial, kind}` (kontrakt M5 §2 udalost
#      `item_removed` nevyjmenovava, ale bez ni by klient kreslil predmet, ktery
#      uz neexistuje; je to ROZHODNUTI KLONU a je videt tady).
#
# IDENTITA TELA je na JEDNOM miste (`_je_telo`, verejne `is_corpse_entity`):
# `type == "corpse"` (co nastavuje `sim.death._vytvor_telo`), jinak
# `props["corpse"] == true` (domluva s leadem pro jine tvurce tela). Kdo vola
# `register(item)`, dostane spravny cas automaticky; `register_corpse` /
# `register_ground` zustavaji pro toho, kdo typ vi predem.
#
# CO SE NEMODELUJE (pojmenovane, ne prehlednute):
#   * predmet v KONTEJNERU (truhla, banka) se nerozpadá - reference rozpady
#     resi pres `Timer` na predmetu ve svete; nas model maze jen to, co je
#     zaregistrovane, a registruje se jen `parent == 0`,
#   * `locked` (flag 0x04) predmety na zemi se rozpadaji stejne - zamceni
#     chrani obsah, ne predmet (`item.gd:73`).

const ItemScript = preload("res://sim/entity/item.gd")
const ClockScript = preload("res://core/clock.gd")

const MS_PER_MINUTE := 60000
# Casy z docs/05 §5.4 (viz hlavicka). Telo je 7 minut - `6` tu bylo omylem
# (namEReno 2026-10-11: padaly kontroly "telo 7 min (360000)").
const GROUND_DECAY_MS := 60 * MS_PER_MINUTE     # 60 min
const CORPSE_DECAY_MS := 7 * MS_PER_MINUTE      # 7 min
const LOOT_RIGHTS_MS := 2 * MS_PER_MINUTE       # 2 min

var _clock = null
var _events = null
var _container = null
var _items = null

# serial -> {due_ms, kind, corpse_of}
var _fronta: Dictionary = {}
var _odstraneno: int = 0


func _init(clock = null, events = null, container = null, items = null) -> void:
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_container = container
	_items = items


# -- rozhrani podle smlouvy ------------------------------------------------

func tick(_ms: int) -> void:
	# SimWorld tickuje systemy po `advance(ms)`, takze cas je uz posunuty.
	if _fronta.is_empty():
		return
	var now: int = now_ms()
	var splatne: Array = []
	for serial in _fronta.keys():
		if int(_fronta[serial].get("due_ms", 0)) <= now:
			splatne.append(int(serial))
	splatne.sort()                       # na poradi klicu slovniku nezalezi
	for serial in splatne:
		_odstran(int(serial))


func register(item) -> bool:
	# AUTO-ROZPOZNANI (kontrakt M5 §5 a zadani): kdo je telo, se pozna z
	# `type == "corpse"`; kdyz `type` chybi, plati `props["corpse"] == true`
	# (na tom se lead domluvil - `sim.death._vytvor_telo` dnes nastavuje
	# `type = "corpse"`, `props` zustava jako zaloha pro jine tvurce tela).
	# Vsechno ostatni na zemi = predmet (60 min).
	if item == null:
		return false
	if _je_telo(item):
		return _registruj(item, CORPSE_DECAY_MS, "corpse")
	return _registruj(item, GROUND_DECAY_MS, "ground")


func register_ground(item) -> bool:
	# Predmet polozeny na zem (`parent == 0`) - rozpad za 60 min.
	return _registruj(item, GROUND_DECAY_MS, "ground")


func register_corpse(item) -> bool:
	# Telo - rozpad za 7 min (i s obsahem). Pravo na loot (2 min) nese telo
	# samo (`set_meta("loot_ms")` v `sim.death`) - decay ho jen pocita.
	return _registruj(item, CORPSE_DECAY_MS, "corpse")


func is_corpse_entity(item) -> bool:
	# Verejne pravidlo identity tela (jedno misto): `type`, jinak `props`.
	return item != null and _je_telo(item)


func unregister(serial: int) -> bool:
	# Kdo predmet zvedl nebo znicil, musi ho vyradit - jinak by decay sahl na
	# neexistujici predmet (a "0 odstraneno" by vypadalo jako klid).
	return _fronta.erase(int(serial))


func pending() -> int:
	return _fronta.size()


func removed_count() -> int:
	return _odstraneno


func due_of(serial: int) -> int:
	# Kdy se predmet rozpadne (0 = neni ve fronte). Pro test a pro UI.
	var e = _fronta.get(int(serial))
	return 0 if not (e is Dictionary) else int(e.get("due_ms", 0))


func loot_ms() -> int:
	return LOOT_RIGHTS_MS


func ground_ms() -> int:
	return GROUND_DECAY_MS


func corpse_ms() -> int:
	return CORPSE_DECAY_MS


func now_ms() -> int:
	return int(_clock.now_ms())


func state() -> Dictionary:
	# Fronta je stav sveta (co a kdy zmizi) - datas pro save/hash.
	var out: Dictionary = {}
	for serial in _fronta.keys():
		var e: Dictionary = _fronta[serial]
		out[str(int(serial))] = {"due_ms": int(e.get("due_ms", 0)),
			"kind": str(e.get("kind", ""))}
	return {"fronta": out, "odstraneno": _odstraneno}


func restore(d: Dictionary) -> void:
	_fronta = {}
	_odstraneno = 0
	if not (d is Dictionary):
		return
	for k in (d.get("fronta", {}) as Dictionary).keys():
		var e = d["fronta"][k]
		if not (e is Dictionary):
			continue
		_fronta[int(str(k))] = {"due_ms": int(e.get("due_ms", 0)),
			"kind": str(e.get("kind", ""))}
	_odstraneno = int(d.get("odstraneno", 0))


# -- vnitrni ---------------------------------------------------------------

func _registruj(item, ms: int, kind: String) -> bool:
	if item == null or int(item.serial) <= 0:
		push_warning("sim.decay: predmet bez serialu se nerozpadá (registrace odmitnuta)")
		return false
	if item.get("parent") != null and int(item.parent) != 0:
		# Predmet v kontejneru se nerozpadá (viz hlavicka) - registrace je
		# jen pro to, co je VE SVETE.
		return false
	_fronta[int(item.serial)] = {"due_ms": now_ms() + ms, "kind": kind}
	return true


func _je_telo(item) -> bool:
	# Identita tela na JEDNOM miste: `type` (co nastavuje `sim.death`), jinak
	# `props["corpse"]` (domluva s leadem) - nikdy oboji na dvou mistech.
	if str(item.get("type")) == "corpse":
		return true
	var props = item.get("props")
	return props is Dictionary and bool((props as Dictionary).get("corpse", false))


func _odstran(serial: int) -> void:
	var e: Dictionary = _fronta.get(serial, {})
	var item = _item(serial)
	_fronta.erase(serial)
	if item == null:
		# Predmet uz nikdo nema (integrace ho smazala) - jen to rekni, tise.
		push_warning("sim.decay: predmet %d uz neexistuje" % serial)
		return
	# 1. obsah tela (telo se rozpadne i s obsahem, docs/05 §5.4). Obsah se
	# bere pred `_container.remove` (jinak by seznam uz byl prazdny) a maze se
	# i z evidence predmetu, aby po tele nezustaly sirotci.
	if str(e.get("kind", "")) == "corpse" and _container != null:
		var obsahy: Array = _container.contents(serial)
		for obsah in obsahy:
			_container.remove(serial, int(obsah), 0)
			_zapomen(int(obsah))
	# 2. predmet sam z kontejneru, ve kterem lezi
	if _container != null and int(item.parent) != 0:
		_container.remove(int(item.parent), serial, 0)
	# 2b. a z EVIDENCE predmetu: predmet na zemi (`parent == 0`) neni v zadnem
	# kontejneru, takze bez tohohle kroku by objekt zustal v `items` navzdy a
	# klient by kreslil predmet, ktery uz neexistuje ("odstraneno" v pocitadle
	# by pritom tvrdilo opak). Dictionary je reference, takze se maze v miste.
	_zapomen(serial)
	# 3. event + pocitadlo
	_odstraneno += 1
	_events_push("item_removed", {"serial": serial, "kind": str(e.get("kind", "")),
		"art": int(item.tile), "x": int(item.pos.x), "y": int(item.pos.y),
		"z": int(item.pos.z)})


func _item(serial: int):
	if serial <= 0:
		return null
	if _items is Dictionary:
		return (_items as Dictionary).get(serial)
	if _items is Object and _items.has_method("get_item"):
		return _items.get_item(serial)
	return null


func _zapomen(serial: int) -> void:
	# Vyrazeni z evidence predmetu (Dictionary je reference, takze se maze
	# volajicimu). Objekt s `get_item`/`remove` (budouci `entity.items`) je
	# druha cesta; kdo neumi ani jedno, dostane aspon pocitadlo a event.
	if serial <= 0:
		return
	if _items is Dictionary:
		(_items as Dictionary).erase(serial)
	elif _items is Object and _items.has_method("remove"):
		_items.remove(serial)


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)
