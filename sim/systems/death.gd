extends RefCounted
# Smrt, telo (corpse), duch a vzkriseni (granule `sim.death`; smlouva docs/04
# §4.2 a tok §4.6.6, pravidla docs/05 §5.13 a §5.4).
#
# ODKUD CISLA (nevymyslena):
#   * `hp <= 0` -> smrt a telo s obsahem krome `blessed` (docs/05 §5.13);
#     `blessed` i `newbie` po smrti ZUSTAVAJI (`docs/05 §5.4`: "blessed zustava
#     po smrti; newbie tez"; `entity.item.flags` 0x01 = blessed, 0x02 = newbie),
#   * hrac se stane DUCHEM - nema telo, nevidi ho monstra, nemuze utocit
#     (docs/05 §5.13); dnes se to nese priznakem `is_ghost` (viz nize),
#   * NEHRAC se z registru ODEBERE (`registry.remove`, docs/04 §4.6.7:
#     "NEHRÁČ se maže (jako reference), tělo zůstává 7 min"),
#   * `resurrect` -> **hp = 10** (docs/05 §5.13, docs/04 §4.6.6),
#   * telo se rozpadne za **7 min**, pravo na loot **2 min** (docs/05 §5.4);
#     casy jsou v `sim.decay` (jedno misto, kde se rozpady pocitaji) a tenhle
#     modul je sem jen PREDAVA - vlastnit dve cisla tehoz by znamenalo dve
#     pravdy (docs/05 §5.16.3, pravidlo 2),
#   * doba na loot je reference `Mobile.CorpseLootRights`/`Corpse` (ServUO
#     `Scripts/Items/Corpses/Corpse.cs`); nas model ji nese jako `loot_ms`
#     na tele (int, herni cas), protoze opravneni je vlastnost TELA.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `_init(registry, container, items, events, seriály, decay, corpse_art,
#     path)` - zavislosti KONSTRUKTOREM (vzor `sim.craft`/`sim.vendor`),
#   * `die` vraci `{ok, serial, corpse, ghost, items}` (smlouva) + `body`
#     a `loot_ms` navic, aby se dalo merit bez klienta,
#   * `is_ghost(m)` je odvozeny stav, ne druha pravda: je to `hp <= 0`
#     a byval to hrac. Drzi se v `_ghosts` (jinak by se po `resurrect`
#     s hp 10 z mrtveho hrace stal "zivy mrtvy"),
#   * `die` na uz mrtveho mobily je `{ok:false, reason:"already_dead"}` -
#     druhe telo by znamenalo duplikat inventare,
#   * `resurrect` VRAci puvodni telo (`body`), protoze duch ma v UO jine telo;
#     hrac z `body == 400` (muz) dostane zpet 400,
#   * equip se vraci podle `blessed`/`insured` (docs/05 §5.13) - dnes se vrati
#     VSECHNO, co v tele zustalo, a `resurrect` ho z tela presune do batohu
#     (rozhodnuti klonu: ztraty skillu/statů jsou `UNVERIFIED`, O5, default off).

const ItemScript = preload("res://sim/entity/item.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const BALANCE_PATH := "res://data/balance.json"

# Telo: art z `data/misc.json`/tiledata neni v kontraktu M5 vyjmenovany jako
# pole; ServUO bere `Corpse` art z tela tvora (`Corpse.cs`). Dokud neni art
# v datech monstra, pouzije se `corpse_art` z konstruktoru a rozsah se HLASI
# (`corpse_art_source`), viz `art_pro_telo`.
const DEFAULT_CORPSE_ART := 0x2006      # art tela (mrtvola) v UO
const CORPSE_FLAG := 0x00000000         # telo nema flag blessed/newbie
# Priznaky predmetu (`sim/entity/item.gd:73`): 0x01 blessed, 0x02 newbie.
const FLAG_BLESSED := 0x01
const FLAG_NEWBIE := 0x02

# Casy z docs/05 §5.4; sim.decay je dostane jako VSTUP (viz hlavicka).
const CORPSE_DECAY_MS := 420000         # 7 min
const LOOT_RIGHTS_MS := 120000          # 2 min
const RESURRECT_HP := 10                # docs/05 §5.13: hp = 10

var _registry = null
var _container = null
var _items = null
var _events = null
var _serials = null
var _decay = null
# Loot monstra (granule `sim.loot`, kontrakt M5 §3.4/§4). Kdo ho nezada,
# dostane telo bez lootu a `loot_reason` to rekne - "prazdne telo" nesmi
# vypadat jako "monstrum nic nemelo".
var _loot = null

var _ghosts: Dictionary = {}            # serial -> puvodni body (duch)
var _corpses: Dictionary = {}           # serial -> objekt tela (pro loot)
var _player_serial: int = 0
var _corpse_art: int = DEFAULT_CORPSE_ART
var _corpse_art_source: String = "default-constant"


func _init(registry = null, container = null, items = null, events = null,
		serials = null, decay = null, corpse_art: int = 0, path: String = BALANCE_PATH,
		loot = null) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_container = container
	_items = items
	_events = events
	_serials = serials
	_decay = decay
	_loot = loot
	if corpse_art > 0:
		_corpse_art = corpse_art
		_corpse_art_source = "constructor"
	_read_data(path)


# -- rozhrani podle smlouvy ------------------------------------------------

func die(m: int, killer: int = 0) -> Dictionary:
	# `resolve_swing` (a kdokoli dalsi) sem posle serial mrtveho. Vraci
	# `{ok, serial, corpse, ghost, items}` + `body` a `loot_ms`.
	var mob = _mobile(m)
	if mob == null:
		return {"ok": false, "serial": int(m), "corpse": 0, "ghost": false,
			"items": 0, "reason": "no_mobile"}
	if int(mob.hp) > 0:
		# Smrt se NEPREDSTIRA: kdo ji zavola s zivym mobilem, dostane duvod.
		return {"ok": false, "serial": int(m), "corpse": 0, "ghost": false,
			"items": 0, "reason": "alive"}
	if _ghosts.has(m) or _corpses.has(m):
		return {"ok": false, "serial": int(m), "corpse": 0, "ghost": bool(_ghosts.has(m)),
			"items": 0, "reason": "already_dead"}

	var je_hrac: bool = _je_hrac(mob)
	var telo = _vytvor_telo(mob)
	var presunuto: int = _napln_telo(mob, telo, je_hrac)
	var loot: Dictionary = _napln_loot(mob, telo)
	_corpses[m] = telo
	_events_push("death", {"serial": int(m), "corpse": int(telo.serial),
		"killer": int(killer), "x": int(telo.pos.x), "y": int(telo.pos.y),
		"z": int(telo.pos.z), "art": int(telo.tile), "items": presunuto,
		"gold": int(loot.get("gold", 0)), "loot_items": int(loot.get("items", 0)),
		"loot_pack": str(loot.get("pack", "")), "ghost": je_hrac})

	if je_hrac:
		# Duch: `is_ghost` je DERIVOVANY stav (viz hlavicka) - hp zustava 0,
		# telo se pozna z `_ghosts`.
		_ghosts[m] = int(mob.body)
		_message("You are dead. You are a ghost.")
	else:
		# NEHRAC se z registru ODEBERE (docs/04 §4.6.7). Telo zustava.
		_registry.remove(m)
		_events_push("mobile_removed", {"serial": int(m), "reason": "death"})
		_message("%s is dead." % _jmeno(mob))

	# Rozpad tela (7 min) a pravo na loot (2 min) - casy vlastni `sim.decay`.
	# Kdo decay nema, dostane casy aspon v udalosti (nikdy ticha nula).
	var rozpad: int = _naplanuj_rozpad(telo)
	telo.set_meta("loot_ms", _now() + LOOT_RIGHTS_MS)
	return {"ok": true, "serial": int(m), "corpse": int(telo.serial),
		"ghost": je_hrac, "items": presunuto, "body": int(mob.body),
		"decay_ms": rozpad, "loot_ms": LOOT_RIGHTS_MS,
		"gold": int(loot.get("gold", 0)), "loot_items": int(loot.get("items", 0)),
		"loot_pack": str(loot.get("pack", "")),
		"loot_reason": str(loot.get("reason", "")), "reason": ""}


func resurrect(m: int, hp: int = 0) -> Dictionary:
	# `hp = 10` (docs/05 §5.13, docs/04 §4.6.6); volajici muze dat jine
	# (lektvar/lecitel), ale NULA a zaporne se prebiji na 10 - `hp <= 0`
	# by z vzkriseneho udelalo mrtveho.
	if hp <= 0:
		hp = RESURRECT_HP
	var mob = _mobile(m)
	if mob == null:
		return {"ok": false, "hp": 0, "reason": "no_mobile"}
	var byl_duch: bool = _ghosts.has(m)
	var puvodni_body: int = int(_ghosts.get(m, int(mob.body)))
	mob.hp = hp
	mob.body = puvodni_body
	_ghosts.erase(m)
	# Co zbylo v tele, se vraci do batohu (equip se vraci podle
	# `blessed`/`insured` - dnes vse, viz hlavicka).
	var vraceno: int = _z_tela_do_batohu(m)
	_events_push("stats_changed", {"serial": int(m), "hp": int(mob.hp),
		"hp_max": int(mob.max_hp)})
	return {"ok": true, "hp": int(mob.hp), "reason": "", "was_ghost": byl_duch,
		"items_returned": vraceno, "body": int(mob.body)}


func is_ghost(m: int) -> bool:
	# Duch = hrac, kteremu `die` nastavil priznak; mrtvy NEHRAC duchem NENI
	# (je proste pryc - `registry.remove`), takze `is_ghost` na neexistujici
	# serial vraci false a volajici to pozna pres `_ghosts`.
	return _ghosts.has(m)


func corpse_of(m: int):
	# Objekt tela (nebo null) - pro `sim.loot.fill_corpse` a pro klienta.
	return _corpses.get(m)


func decay_ms() -> int:
	return CORPSE_DECAY_MS


func loot_ms() -> int:
	return LOOT_RIGHTS_MS


func corpse_art_source() -> String:
	return _corpse_art_source


func ghost_count() -> int:
	return _ghosts.size()


func corpse_count() -> int:
	return _corpses.size()


func state() -> Dictionary:
	# Stav smrti JE stav sveta: kdo je duch a ktera tela existuji. Tela sama
	# jsou predmety (jejich stav vlastni kontejner) - tady je jen MAPA
	# serial -> telo, bez ktere by se po nacteni nedalo lootovat.
	var tela: Dictionary = {}
	for m in _corpses.keys():
		tela[str(int(m))] = int(_corpses[m].serial)
	var duchove: Dictionary = {}
	for m in _ghosts.keys():
		duchove[str(int(m))] = int(_ghosts[m])
	return {"ghosts": duchove, "corpses": tela, "player_serial": _player_serial}


func restore(d: Dictionary) -> void:
	_ghosts = {}
	_corpses = {}
	if not (d is Dictionary):
		return
	for k in (d.get("ghosts", {}) as Dictionary).keys():
		_ghosts[int(str(k))] = int(d["ghosts"][k])
	for k in (d.get("corpses", {}) as Dictionary).keys():
		var serial: int = int(d["corpses"][k])
		var item = _item(serial)
		if item != null:
			_corpses[int(str(k))] = item
	_player_serial = int(d.get("player_serial", _player_serial))


func set_player(serial: int) -> void:
	# Kdo je hrac, vi integrace (`app/`) nebo test - `SimWorld.player_serial`
	# je jedina pravda o hraci a tenhle modul si ji bere ODTUD.
	_player_serial = int(serial)


# -- vnitrni: telo ---------------------------------------------------------

func _vytvor_telo(mob):
	# Telo = `entity.item` s `parent == 0` (na zemi) a pozici zemreleho
	# (kontrakt M5 §2). `pos` ma smysl JEN kdyz `parent == 0` (`item.gd:177-179`),
	# proto se telo nevnoruje do zadneho kontejneru.
	var telo = ItemScript.new(_next_serial(), _corpse_art, 1)
	telo.type = "corpse"
	telo.parent = 0
	telo.pos = Vector3i(int(mob.pos.x), int(mob.pos.y), int(mob.pos.z))
	telo.flags = CORPSE_FLAG
	if _items is Dictionary:
		(_items as Dictionary)[int(telo.serial)] = telo
	return telo


func _napln_telo(mob, telo, je_hrac: bool) -> int:
	# Obsah batohu + equipu krome `blessed`/`newbie`. Telo je KONTEJNER
	# (kontrakt M5 §2), takze predmety se do nej vkladaji pres `sim.entity.container`,
	# ktery sam vyjme predmet z predchoziho rodice (invariant "prave jeden rodic").
	var prevedeno: int = 0
	if _container == null:
		# Bez kontejneru se obsah NEPRENESE - a je to VIDET (pocet 0 neni
		# "nic v tele", ale "nemam kam").
		push_warning("sim.death: bez `container` se obsah tela nepreleje")
		return 0
	for serial in _serialy_obsahu(mob):
		var item = _item(serial)
		if item == null:
			continue
		if _zachovat(item):
			# `blessed`/`newbie` po smrti ZUSTAVAJI (docs/05 §5.4) - predmet se
			# NEBERE a ani se neodpojuje z vrstvy (jinak by hrac prisel o vec,
			# kterou mit MA); proto se preskakuje PRED uklidem vrstvy.
			continue
		if int(item.parent) != 0 and int(item.parent) != int(telo.serial):
			# Equip ma rodice MOBILA; `entity.container.add` umi vyjmout jen
			# z kontejneru, takze vrstvu uklidi `_equipment_uklid`.
			_equipment_uklid(mob, item)
		if _container.add(int(telo.serial), item):
			prevedeno += 1
		else:
			push_warning("sim.death: predmet %d se do tela nevesel" % serial)
	return prevedeno


func _serialy_obsahu(mob) -> Array:
	# Serialy batohu + nasazene vybavy, SERAZENE: na poradi vlozeni nesmi
	# zaviset stav ani poradi v tele (stejny princip jako `registry.all()`).
	var out: Array = []
	if _container != null and int(mob.backpack) > 0:
		for s in _container.contents(int(mob.backpack)):
			out.append(int(s))
	var equip = mob.get("equip")
	if equip is Dictionary:
		var vrstvy: Array = (equip as Dictionary).keys()
		vrstvy.sort()
		for layer in vrstvy:
			out.append(int((equip as Dictionary)[layer]))
	out.sort()
	return out


func _zachovat(item) -> bool:
	# `blessed` i `newbie` po smrti ZUSTAVAJI (docs/05 §5.4) - z tela se
	# neberou a z equipu se jen uklidi vrstva (predmet zustava mobilu).
	return (int(item.flags) & (FLAG_BLESSED | FLAG_NEWBIE)) != 0


func _equipment_uklid(mob, item) -> bool:
	# Uklid vrstvy u mobily: `equip[layer] = serial` -> smazat. Dela se to
	# tady, protoze `entity.equipment` chce kontejner a ten je prave TELO,
	# ktere jeste neexistuje ve chvili, kdy se vybava prelejva.
	var equip = mob.get("equip")
	if not (equip is Dictionary):
		return false
	var layer: int = int(item.layer)
	if int((equip as Dictionary).get(layer, 0)) == int(item.serial):
		(equip as Dictionary).erase(layer)
		return true
	return false


func _napln_loot(mob, telo) -> Dictionary:
	# LOOT MONSTRA (kontrakt M5 §2/§3.4): `sim.loot.fill_corpse` chce ZAZNAM
	# monstra z `data/monsters.json` (bere z nej `loot_pack`), ne mobil - proto
	# se mu predava maly slovnik. Mobil je nositelem `loot_pack` i `type`
	# (`sim.world.spawn` je tam dava), takze se hodnota NEHADA a neztraci.
	# Kdyz `sim.loot` neni, vracime `reason:"no_loot_system"` - prazdne telo
	# se pak NESMI tvarit jako "monstrum nic nemelo".
	if _loot == null or not _loot.has_method("fill_corpse"):
		return {"gold": 0, "items": 0, "pack": "", "reason": "no_loot_system"}
	# ⚠ DATA MONSTRA JSOU V `mob.ai["data"]` (namEReno 2026-10-11: `entity.mobile`
	# pole `loot_pack`/`type` NEMA a `Object.set()` na nedeklarovanou vlastnost
	# nic neudela - `mob.get("loot_pack")` vraci null, takze by KAZDY mobil
	# dostal "poor"). Zapisuje je `sim.world.spawn`; `mob.get` zustava jako
	# zaloha pro pripad, ze `entity.mobile` ta pole nekdy dostane.
	var data: Dictionary = {}
	var ai = mob.get("ai")
	if ai is Dictionary and (ai as Dictionary).get("data") is Dictionary:
		data = (ai as Dictionary)["data"]
	var zaznam: Dictionary = {
		"type": str(data.get("type", mob.get("type"))),
		"loot_pack": str(data.get("loot_pack", mob.get("loot_pack"))),
	}
	var r = _loot.fill_corpse(zaznam, telo)
	if not (r is Dictionary):
		return {"gold": 0, "items": 0, "pack": "", "reason": "bad_loot_result"}
	return {"gold": int(r.get("gold", 0)), "items": int(r.get("items", 0)),
		"pack": str(r.get("pack", "")), "reason": str(r.get("reason", ""))}


func _naplanuj_rozpad(telo) -> int:	# `sim.decay` je JEDNO misto, kde se rozpady pocitaji (docs/05 §5.4).
	# Kdyz decay neni, vracime 0 a je to VIDET (`decay_ms: 0` znamena "nikdo
	# to neuklidi", ne "telo se rozpadne hned").
	if _decay == null or not _decay.has_method("register_corpse"):
		push_warning("sim.death: bez `sim.decay` se telo neuklidi")
		return 0
	_decay.register_corpse(telo)
	return CORPSE_DECAY_MS


func _z_tela_do_batohu(m: int) -> int:
	# Vzkriseni vraci obsah tela hraci (docs/05 §5.13). Telo se pritom maze
	# z evidence - jinak by zustalo "prave lootovane" a decay by ho hledal.
	var telo = _corpses.get(m)
	if telo == null or _container == null:
		return 0
	var mob = _mobile(m)
	if mob == null or int(mob.backpack) <= 0:
		return 0
	var vraceno: int = 0
	for serial in _container.contents(int(telo.serial)):
		var item = _item(int(serial))
		if item == null:
			continue
		if _container.add(int(mob.backpack), item):
			vraceno += 1
	_corpses.erase(m)
	return vraceno


# -- vnitrni: data a zaklad -------------------------------------------------

func _read_data(_path: String) -> void:
	# Telo ma art z dat, pokud tam je (`data/balance.json: corpse_art`).
	# Chybejici klic = vychozi konstanta a `corpse_art_source` to rekne.
	var d = null
	if FileAccess.file_exists(_path):
		d = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not (d is Dictionary):
		return
	var c = (d as Dictionary).get("death")
	if c is Dictionary and int((c as Dictionary).get("corpse_art", 0)) > 0:
		_corpse_art = int((c as Dictionary)["corpse_art"])
		_corpse_art_source = "data:" + _path


func _je_hrac(mob) -> bool:
	# Kdo je hrac: (1) `_player_serial` z integrace (`set_player`), (2) kdyz
	# ji nikdo nerekne, pozná se hrac podle TELA (`entity.mobile.body`:
	# 400 = muz, 401 = zena, `mobile.gd:25`) - monstra maji jina tela
	# (`data/monsters.json: body` 50 = kostlivec). Kdo nerekne ani jedno,
	# dostane `false` a `ghost_count()` to ukaze.
	if _player_serial > 0:
		return int(mob.serial) == _player_serial
	return int(mob.body) == 400 or int(mob.body) == 401


func _mobile(m: int):
	return null if _registry == null else _registry.get_mobile(m)


func _item(serial: int):
	if serial <= 0:
		return null
	if _items is Dictionary:
		return (_items as Dictionary).get(serial)
	return null


func _next_serial() -> int:
	if _serials == null:
		return 0
	if _serials is Object and _serials.has_method("next_serial"):
		return int(_serials.next_serial())
	if _serials is Object and _serials.has_method("next"):
		return int(_serials.next())
	return 0


func _now() -> int:
	# Cas jde z `clock`, ktery je soucasti `serials`-podobnych zavislosti:
	# `death` ho bere z decay, pokud ho ma (jinak 0 = cas se NEMERI).
	if _decay != null and _decay.has_method("now_ms"):
		return int(_decay.now_ms())
	return 0


func _jmeno(mob) -> String:
	var n: String = str(mob.get("name"))
	return n if n != "" else "it"


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)


func _message(text: String) -> void:
	_events_push("message", {"text": text, "kind": "death"})
