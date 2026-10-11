extends RefCounted
# Spawn monster: body, tabulky, obnova (granule `sim.spawn`; smlouva docs/04 §4.2
# a tok §4.6.7, pravidla docs/05 §5.12).
#
# MODEL: **regionální spawn tabulky + JEDEN world tick** misto tisicu spawner
# objektu (docs/05 §5.12: "jeden world tick misto tisíce spawnerů"; docs/04 §4.2:
# `world.spawn` je od 2026-10-08 granule M5 - rozhodnuti D1). Jeden `tick(ms)`
# projde vsechny body; zadny `Timer` na bod.
#
# ODKUD CISLA (nevymyslena):
#   * prodleva **5-10 min** a doplneni deficitu **`max((max - spawned)/3, 1)`** jsou
#     namERene (`_src/servuo/Scripts/Services/Spawner/Spawner.cs:41`,
#     `Scripts/Regions/Spawning/SpawnEntry.cs:536`; kontrakt M5 §3.5 je ma
#     v `data/spawns.json: delay_ms: [300000, 600000]`),
#   * monstrum se stavi z `data/monsters.json` (kontrakt M5 §3.4): `body`,
#     `str/dex/int` (rozsahy!), `hits` (rozsahy), `damage`, `resist`, `skills`
#     v DESETINACH (45.1 -> 451), `fame`, `karma`, `notoriety`, `loot_pack`,
#   * `home` = bod spawnu (kontrakt M5 §7) a `serial = sim.next_serial()`
#     (kontrakt M5 §2: serialy vydava `core.serial`),
#   * po zabiti se monstrum obnovi **do 10 min** (docs/04 §4.6.7 prijimaci
#     kriterium) - proto je horni mez prodlevy 10 min a je to v DATEch,
#   * po `save -> load` je stav spawnu STEJNY (docs/04 §4.6.7: "po save -> load
#     je stav mobilů i spawnu stejný"): `state()` da body + casovace, `restore()`
#     je vrati PRESNE (zadna nahoda, zadny cas z hodin).
#
# TVAR `data/spawns.json` (kontrakt M5 §3.5):
#   {"points": [{"id": "...", "x":1495, "y":1630, "radius":6, "max":3,
#                "delay_ms": [300000, 600000], "monsters": ["skeleton", ...],
#                "source": "..."}]}
#
# ⚠ `no_spawn_in_town` (data/spawns.json:config) je NACTENY, ale NEVYNUCENY:
# spawn bod je dnes jen `{x, y, radius}` a regiony (`sim/world/regions.gd`) se
# mu NEPREDAVAJI, takze se neda zjistit, jestli bod lezi ve meste. Chovani je
# proto "spiň VZDY" a je to videt pres `no_spawn_in_town()` +
# `region_check_source()` - nikdy ticha napodobenina pravidla. Kdo preda
# regions (nebo callable `in_town`), doplni branu na jednom miste v `tick`.
#
# KLIC `spawn_state`: `sim/sim_world.gd:236` ma v save pripraveny klic
# `spawn_state`; tenhle modul vraci presne `{"points": [...]}` a integrace ho
# tam ma dat (`register_state_source("spawn", spawn)`). Agent `sim_world.gd`
# needituje (kontrakt M5 §4) - pise to lead.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `register(point) -> int` vraci INDEX bodu (smlouva vraci `void`/`int` -
#     kontrakt M5 §2 pise `register(point) -> int`), aby se dalo merit
#     `alive_at(point_id)`,
#   * `_init(registry, serials, clock, events, rng, spawns, monsters, paths...)` -
#     zavislosti konstruktorem; `spawns`/`monsters` se daji predat PRIMO
#     (fixture v testu), nebo se prectou z cest,
#   * `alive_at(point_id) -> int` je POCET zivych monster daneho bodu (ne bool),
#   * `state()` vklada i `serial` a `home` kazdeho ziveho monstra - bez toho by
#     se po nacteni nedalo poznat, ktere monstrum ktery bod vlastni,
#   * obnova je vazana na PRVNI tik po `delay_ms` (jeden svetovy casovac na
#     bod), ne na `Timer` na monstrum,
#   * kdyz monstrum z registru ZMIZI (smrt), deficit se POZNA az v dalsim
#     `tick` - a to je spravne: smrt hlasi `sim.death`, spawn se ptá stavu.

const MobileScript = preload("res://sim/entity/mobile.gd")
const StatsScript = preload("res://sim/entity/stats.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")

const SPAWNS_PATH := "res://data/spawns.json"
const MONSTERS_PATH := "res://data/monsters.json"

# Prodleva a deficit (kontrakt M5 §3.5). Vychozi hodnoty se pouziji, kdyz je
# bod v datech nema - ale `delay_ms` ma prednost, takze jsou to skutecne meze,
# ne opsana cisla.
const DELAY_MIN_MS := 300000            # 5 min
const DELAY_MAX_MS := 600000            # 10 min
const DEFICIT_DIVISOR := 3              # `max((max - spawned)/3, 1)`
const DEFICIT_MIN := 1

var _registry = null
var _serials = null
var _clock = null
var _events = null
var _rng = null

var _points: Array = []                 # body z `data/spawns.json`
var _monstra: Dictionary = {}           # typ -> zaznam z `data/monsters.json`
var _body: Dictionary = {}              # index bodu -> [serial, ...]
var _dalsi: Dictionary = {}             # index bodu -> ms pristi obnovy
var _monstra_ok: bool = false
var _skill_ids: Dictionary = {}         # jmeno skillu -> id (read cache)
# `config` z `data/spawns.json` (kontrakt M5 §3.5). `no_spawn_in_town` je
# nacteny a je VIDET, ze se nevynucuje (`region_check_source`) - viz hlavicka.
var _no_spawn_in_town: bool = false
var _config_tick_ms: int = 0


func _init(registry = null, serials = null, clock = null, events = null, rng = null,
		spawns = null, monsters = null, spawns_path: String = SPAWNS_PATH,
		monsters_path: String = MONSTERS_PATH) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_serials = serials
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_rng = rng if rng != null else RngScript.new(0)
	# ⚠⚠ NAMERENO 2026-10-11: `X if podminka else Y` jako ARGUMENT volani
	# predavalo do `_load_monsters` RETEZEC `path`, ne nactena data (debug
	# `[spawn-DBG] ... hodnota=res://data/monsters.json`) - a `sim.spawn` pak
	# hlasil "neni seznam" a monstra se nevytvorila. Rozepsano na `if`:
	# tvar, ktery se neda splest s vyrazem.
	var data_monster = monsters
	if data_monster == null:
		data_monster = _read_json(monsters_path)
	var data_body = spawns
	if data_body == null:
		data_body = _read_json(spawns_path)
	_load_monsters(data_monster, monsters_path)
	_load_points(data_body, spawns_path)


# -- rozhrani podle smlouvy ------------------------------------------------

func register(point: Dictionary) -> int:
	# Zaregistruje spawn bod a vraci jeho INDEX (`point_id` pro `alive_at`).
	# Bod bez `id` dostane jmeno z poradi; bod bez `max` dostane 1 (nula by
	# znamenala "nikdy nic" a to je jina vec).
	var p: Dictionary = point.duplicate(true)
	if not p.has("x") or not p.has("y"):
		push_warning("sim.spawn: bod bez x/y se neeviduje (%s)" % str(point))
		return -1
	if str(p.get("id", "")) == "":
		p["id"] = "point_%d" % _points.size()
	if int(p.get("max", 0)) <= 0:
		p["max"] = 1
	if not (p.get("delay_ms") is Array) or (p["delay_ms"] as Array).size() < 2:
		p["delay_ms"] = [DELAY_MIN_MS, DELAY_MAX_MS]
	if not (p.get("monsters") is Array) or (p["monsters"] as Array).is_empty():
		push_warning("sim.spawn: bod '%s' nema monstra" % str(p["id"]))
	_points.append(p)
	var i: int = _points.size() - 1
	_body[i] = []
	# Prvni obnova je HNED (`due_ms = now`), aby svet po nacteni nezyl prazdny;
	# kdo chce prazdny start, da `delay_ms` a prvni tik ho nenaplni.
	_dalsi[i] = now_ms()
	return i


func tick(_ms: int) -> void:
	# JEDEN svetovy tick (docs/05 §5.12). Poradi bodu je INDEX registrace
	# (deterministicke); nahoda jde z `_rng`.
	for i in range(_points.size()):
		_uklid(i)
		var chybi: int = _deficit(i)
		if chybi <= 0:
			continue
		if now_ms() < int(_dalsi.get(i, 0)):
			continue
		var p: Dictionary = _points[i]
		var dalsi_cas: int = _nahodna_prodleva(p)
		for _k in chybi:
			var mob = _vytvor(i, p)
			if mob == null:
				# Chybejici typ monstra NESMI zastavit zbytek bodu: ostatni
				# typy se postavi dal (do 2026-10-10 se tu `break`-ovalo, takze
				# bod s jednim neznamym typem nedoplnil ani zname).
				continue
		# Prodleva se nastavuje i kdyz se monstrum nepostavilo (chybejici data)
		# - jinak by se pokus opakoval KAZDY tik a log by se zaplavil.
		_dalsi[i] = now_ms() + dalsi_cas


func alive_at(point_id: int) -> int:
	# POCET zivych monster bodu (ne bool): kontrakt M5 §7. Neznamy bod vraci
	# 0 a `point_id()` to ukaze (`has_point`).
	var out: int = 0
	for serial in _body.get(point_id, []):
		var m = _mobile(int(serial))
		if m != null and m.alive():
			out += 1
	return out


func state() -> Dictionary:
	# Stav pro save/hash (`spawn_state`, kontrakt M5 §4). Uklada se i cas
	# pristi obnovy a `home` kazdeho ziveho monstra - po nacteni musi byt stav
	# PRESNE stejny (docs/04 §4.6.7).
	var body: Array = []
	var indexy: Array = _body.keys()
	indexy.sort()
	for i in indexy:
		var radky: Array = []
		var serialy: Array = (_body[i] as Array).duplicate()
		serialy.sort()
		for serial in serialy:
			var m = _mobile(int(serial))
			if m == null:
				continue
			radky.append({"serial": int(m.serial), "alive": m.alive(),
				"home": _home_parts(m), "x": int(m.pos.x), "y": int(m.pos.y),
				"z": int(m.pos.z), "body": int(m.body)})
		body.append({"point": int(i),
			"id": str((_points[i] as Dictionary).get("id", "")),
			"due_ms": int(_dalsi.get(i, 0)), "mobiles": radky})
	return {"points": body, "count": _points.size()}


func restore(d: Dictionary) -> void:
	# Opak `state()`: co se ulozilo, se vraci PRESNE (round-trip meri test).
	_body = {}
	_dalsi = {}
	if not (d is Dictionary):
		return
	for row in (d.get("points", []) as Array):
		if not (row is Dictionary):
			continue
		var i: int = int((row as Dictionary).get("point", -1))
		if i < 0 or i >= _points.size():
			push_warning("sim.spawn.restore: bod %d neexistuje" % i)
			continue
		_dalsi[i] = int((row as Dictionary).get("due_ms", 0))
		var serialy: Array = []
		for m in ((row as Dictionary).get("mobiles", []) as Array):
			if m is Dictionary:
				serialy.append(int((m as Dictionary).get("serial", 0)))
		_body[i] = serialy


# -- mereni a integrace (nad ramec smlouvy) --------------------------------

func point_id(index: int) -> String:
	if index < 0 or index >= _points.size():
		return ""
	return str((_points[index] as Dictionary).get("id", ""))


func point_count() -> int:
	return _points.size()


func index_of(id: String) -> int:
	for i in range(_points.size()):
		if str((_points[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func due_ms(index: int) -> int:
	return int(_dalsi.get(index, 0))


func spawned_total() -> int:
	var out: int = 0
	for i in range(_points.size()):
		out += alive_at(i)
	return out


func monsters_loaded() -> bool:
	return _monstra_ok


func no_spawn_in_town() -> bool:
	# Pravidlo z dat - je NACTENE. Jestli se take VYNUCUJE, rika
	# `region_check_source()` (dnes ne: regiony spawn nezna).
	return _no_spawn_in_town


func region_check_source() -> String:
	# "none" = body se nekontroluji proti regionu mesta a spiň se VZDY. Je to
	# pojmenovane omezeni, ne ticha napodobenina pravidla (viz hlavicka).
	return "none (spawn nema regiony - spiň vzdy)"


func config_tick_ms() -> int:
	# `tick_ms` z dat (doporucena kadence world ticku; sam modul tickuje, jak
	# ho vola `SimWorld` - hodnota je tu pro integraci a je videt).
	return _config_tick_ms


func monster_types() -> Array:
	var out: Array = _monstra.keys()
	out.sort()
	return out


func now_ms() -> int:
	return int(_clock.now_ms())


# -- vnitrni: obnova -------------------------------------------------------

func _deficit(i: int) -> int:
	# `max((max - spawned)/3, 1)` (`SpawnEntry.cs:536`; kontrakt M5 §3.5).
	var p: Dictionary = _points[i]
	var chybi: int = int(p.get("max", 1)) - alive_at(i)
	if chybi <= 0:
		return 0
	return maxi(chybi / DEFICIT_DIVISOR, DEFICIT_MIN)


func _nahodna_prodleva(p: Dictionary) -> int:
	# Prodleva 5-10 min z bodu (`delay_ms: [min, max]`); chybejici meze se
	# doplni vychozimi hodnotami, ale NIKDY se nerozhodi (min > max).
	var d = p.get("delay_ms")
	var lo: int = DELAY_MIN_MS
	var hi: int = DELAY_MAX_MS
	if d is Array and (d as Array).size() >= 2:
		lo = int((d as Array)[0])
		hi = int((d as Array)[1])
	if hi < lo:
		var t: int = lo
		lo = hi
		hi = t
	return _rng.range_i(lo, hi)


func _vytvor(i: int, p: Dictionary):
	# Novy mobil z `data/monsters.json` (kontrakt M5 §3.4): body, staty,
	# skilly, damage, resist, notoriety, home = bod spawnu, serial z `sim`.
	var typy: Array = p.get("monsters", [])
	if typy.is_empty():
		return null
	var typ: String = str(typy[_rng.range_i(0, typy.size() - 1)])
	var rec: Dictionary = _monstra.get(typ, {})
	if rec.is_empty():
		push_warning("sim.spawn: monstrum '%s' neni v data/monsters.json" % typ)
		return null
	var pozice: Vector3i = _pozice_v_bodu(p)
	var mob = MobileScript.new(_next_serial(), int(rec.get("body", 0)), pozice)
	mob.name = str(rec.get("name", typ))
	mob.hue = int(rec.get("hue", 0))
	mob.stats = StatsScript.new(_rozsah(rec.get("str", [10, 10])),
		_rozsah(rec.get("dex", [10, 10])), _rozsah(rec.get("int", [10, 10])))
	mob.max_hp = _rozsah(rec.get("hits", [mob.stats.hits_max(), mob.stats.hits_max()]))
	mob.hp = mob.max_hp
	mob.max_stam = mob.stats.stam_max()
	mob.stam = mob.max_stam
	mob.max_mana = mob.stats.mana_max()
	mob.mana = mob.max_mana
	mob.notoriety = int(rec.get("notoriety", 0))
	mob.fame = int(rec.get("fame", 0))
	mob.karma = int(rec.get("karma", 0))
	# Skilly jsou v datech v DESETINACH (kontrakt M5 §3.4: 45.1 -> 451).
	var skills = rec.get("skills")
	if skills is Dictionary:
		for jmeno in (skills as Dictionary).keys():
			var sid: int = _skill_id(str(jmeno))
			if sid < 0:
				push_warning("sim.spawn: skill '%s' neni v data/skills.json" % str(jmeno))
				continue
			var v = (skills as Dictionary)[jmeno]
			var hodnota: int = _rozsah(v) if v is Array else int(v)
			mob.skills.set_value(sid, hodnota)
	# DATA TVORA (M5): od 2026-10-11 je `entity.mobile` ma jako DEKLAROVANA pole
	# (`type`, `loot_pack`, `damage`, `resist`), takze se zapisuji PRIMO a
	# ukladaji se do save. Drive se tu pouzivalo `mob.set(...)` na nedeklarovanou
	# vlastnost - to je v Godotu 4 tiche no-op (namEReno) a data pak zila jen
	# v `mob.ai["data"]`, ktery `state()` neserializuje (po save/load monstrum
	# ztratilo staty). `ai["data"]` se jeste plni jako ZALOHA pro cizi tvurce
	# mobili - cte ji `sim.combat._data_of`.
	mob.type = typ
	mob.loot_pack = str(rec.get("loot_pack", ""))
	var dmg = rec.get("damage", [])
	mob.damage = [int((dmg as Array)[0]), int((dmg as Array)[1])] \
		if dmg is Array and (dmg as Array).size() >= 2 else []
	var res = rec.get("resist", {})
	var resist_kopie: Dictionary = {}
	if res is Dictionary:
		for k in (res as Dictionary).keys():
			resist_kopie[str(k)] = int((res as Dictionary)[k])
	mob.resist = resist_kopie
	var data: Dictionary = {
		"damage": mob.damage,
		"resist": mob.resist,
		"loot_pack": mob.loot_pack,
		"type": typ,
		"virtual_armor": int(rec.get("virtual_armor", 0)),
	}
	mob.ai = {"state": "idle", "target": 0, "home": pozice, "timer_ms": 0,
		"data": data}
	var think = rec.get("speed")
	if think is Dictionary:
		mob.ai["speed"] = think
	_registry.register(mob)
	var serialy: Array = _body.get(i, [])
	serialy.append(int(mob.serial))
	_body[i] = serialy
	# Udalost `mobile_added` (kontrakt M5 §2) - klient z ni stavi sprajt.
	_events_push("mobile_added", {"serial": int(mob.serial), "body": int(mob.body),
		"hue": int(mob.hue), "name": mob.name, "x": int(mob.pos.x),
		"y": int(mob.pos.y), "z": int(mob.pos.z), "notoriety": int(mob.notoriety),
		"point": str(p.get("id", "")), "type": typ})
	return mob


func _pozice_v_bodu(p: Dictionary) -> Vector3i:
	# Nahodna pozice v kruhu bodu (`radius`); `z` se bere z bodu, protoze
	# mapa/`walk` v tomhle modulu neni (spawn neurcuje vysku terénu - ta je vec
	# `world.walk`, ktery si ji pri prvnim kroku prevezme).
	var r: int = maxi(int(p.get("radius", 0)), 0)
	var dx: int = 0
	var dy: int = 0
	if r > 0:
		dx = _rng.range_i(-r, r)
		dy = _rng.range_i(-r, r)
	return Vector3i(int(p.get("x", 0)) + dx, int(p.get("y", 0)) + dy, int(p.get("z", 0)))


func _rozsah(v) -> int:
	# Rozsah `[min, max]` z dat (kontrakt M5 §3.4) - jedna hodnota z `rng`.
	if v is Array and (v as Array).size() >= 2:
		return _rng.range_i(int((v as Array)[0]), int((v as Array)[1]))
	if v is Array and (v as Array).size() == 1:
		return int((v as Array)[0])
	if v == null:
		return 0
	return int(v)


func _uklid(i: int) -> void:
	# Mrtva monstra se z evidence bodu odstrani; zivá, která uz v registru
	# nejsou (smazal je `sim.death`), taky - jinak by deficit nikdy neklesl.
	var zive: Array = []
	for serial in _body.get(i, []):
		var m = _mobile(int(serial))
		if m != null and m.alive():
			zive.append(int(serial))
	_body[i] = zive


func _home_parts(mob) -> Array:
	var h = (mob.get("ai") as Dictionary).get("home", Vector3i.ZERO)
	if h is Vector3i:
		return [h.x, h.y, h.z]
	if h is Array and (h as Array).size() >= 3:
		return [int(h[0]), int(h[1]), int(h[2])]
	return [0, 0, 0]


# -- vnitrni: data ---------------------------------------------------------

func _load_points(d, path: String) -> void:
	var points = d
	if d is Dictionary:
		points = (d as Dictionary).get("points", [])
		_read_config((d as Dictionary).get("config", {}))
	if not (points is Array):
		push_warning("sim.spawn: " + path + " nema seznam `points`")
		return
	for p in points:
		if p is Dictionary:
			register(p)


func _read_config(c) -> void:
	# `config` z `data/spawns.json` (kontrakt M5 §3.5): `no_spawn_in_town`
	# a `tick_ms`. Nectou se jako "hezke klice do kódu" - `no_spawn_in_town`
	# je pravidlo a je videt, jestli plati (`region_check_source`).
	if not (c is Dictionary):
		return
	_no_spawn_in_town = bool((c as Dictionary).get("no_spawn_in_town", false))
	_config_tick_ms = int((c as Dictionary).get("tick_ms", 0))


func _load_monsters(d, path: String) -> void:
	# `data/monsters.json` je SEZNAM zaznamu (kontrakt M5 §3.4), klicovany
	# `type`. Chybejici soubor se HLASI - ticha nula by znamenala "spawn
	# funguje, ale monstra nejsou".
	if d == null:
		push_warning("sim.spawn: chybi " + path + " - monstra se nepostavi")
		return
	if not (d is Array):
		push_warning("sim.spawn: " + path + " neni seznam")
		return
	for rec in d:
		if rec is Dictionary and str((rec as Dictionary).get("type", "")) != "":
			_monstra[str((rec as Dictionary)["type"])] = rec
	_monstra_ok = not _monstra.is_empty()
	if not _monstra_ok:
		push_warning("sim.spawn: " + path + " nema zadne monstrum")


func _skill_id(jmeno: String) -> int:
	# Id skillu z `data/skills.json` (`id` = index). Mapa se NEDRZI ve statickem
	# stavu (dva testy v jednom procesu by si ji prepsaly) - precte se z data
	# jednou pri prvnim pouziti a je to jen READ cache.
	if _skill_ids.is_empty():
		var d = _read_json("res://data/skills.json")
		if not (d is Array):
			push_warning("sim.spawn: chybi data/skills.json - skilly monster nebudou")
			return -1
		for i in (d as Array).size():
			var rec = d[i]
			if rec is Dictionary and str(rec.get("name", "")) != "":
				_skill_ids[str(rec["name"])] = int(rec.get("id", i))
	return int(_skill_ids.get(jmeno, -1))


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# -- vnitrni: zaklad -------------------------------------------------------

func _mobile(serial: int):
	return null if _registry == null else _registry.get_mobile(serial)


func _next_serial() -> int:
	if _serials == null:
		return 0
	if _serials is Object and _serials.has_method("next_serial"):
		return int(_serials.next_serial())
	if _serials is Object and _serials.has_method("next"):
		return int(_serials.next())
	return 0


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)
