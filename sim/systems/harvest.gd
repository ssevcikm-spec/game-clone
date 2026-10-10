extends RefCounted
# Sber surovin (granule `sim.harvest`; smlouva docs/04 §4.2, pravidla docs/05 §5.7,
# cisla research/04-gathering-crafting.md §1-2 a §2.1/§2.2; zdrojovy kod
# `_src/servuo/Scripts/Services/Harvest/`).
#
# ODKUD CISLA (nevymyslena, kazde ma zdroj):
#   * buckety: ore 8x8 dlazdic, 10-34 rudy, respawn 10-20 min; wood 4x3, 20-45
#     logu, respawn 20-30 min; fish 8x8, 5-15 ryb, respawn 10-20 min
#     (`HarvestDefinition` per system, research §1.2/§1.3/§1.4),
#   * 9 rud a 7 stromu vcetne `ReqSkill` a sanci zily = tabulky v research
#     §1.2/§1.3 (`Mining.cs`, `Lumberjacking.cs`); barvy (hue) z tabulek
#     `m_MetalInfo` / `m_WoodInfo` (research §2.2),
#   * "kdyz je zila barevna a skill na ni nestaci, padne 50 % na zelezo"
#     = `ChanceToFallback` + `MutateResource` (research §1.1 krok 3),
#   * zila je pro bucket DETERMINISTICKA (vetev pre-ML: `new Random(bx*17+by*11+3)`,
#     research §1.1) - stejny kopec dava stejny kov a nikdy se neprehodi,
#   * dlazdice: seznamy `m_MountainAndCaveTiles`, `m_TreeTiles`, `m_WaterTiles`
#     (research §1.2/§1.3/§1.4) - rozhoduje SEZNAM, ne vzhled; statik se
#     normalizuje `(ItemID & 0x3FFF) | 0x4000` (research §1.1 krok 1),
#   * usek: mining/lumber 1,6 s (EffectDelay), rybolov 8 s na pokus
#     (research §1.1 tabulka casu), dosah 2 dlazdice (rybolov 4),
#   * naradi: opotrebuje se JEN pri uspesnem skill checku (research §1.1 krok 8).
#
# TVRZENI, KTERE MUSI DRZET: rust skillu je DRUHY, NEZAVISLY hod - proto se
# uspech pocita pres `sim.skill_gain.check()` (ta po uspechu i rustu rozhoduje
# sama) a NIKDY pres `randf()` (docs/09 §9.10.4).
#
# ERA / ODCHYLKY (merene, ne prehlednute):
#   * `ConsumedPerFeluccaHarvest` (2 rudy / 20 logu) se NEPOUZIVA: jsme
#     singleplayer a docs/05 §5.7 zadava "10 logu za sek". Feluccske zdvojnase
#     je tim vedoma odchylka, ne prehlednuti,
#   * "hluboka voda od 75 skillu" je UNVERIFIED: `ValidateDeepWater` je tabulka
#     z `SpecialFishingNet`, kterou nemame. Voda se bere jako MELKA - a melka
#     voda ma podle reference jedine pravidlo: `Fishing >= 75` uspeje BEZ hodu
#     (`CheckHarvestSkill` override v `Fishing.cs`, research §1.4). Co chybi,
#     je tim pojmenovane, ne zamlcene,
#   * `skill_gain.check(m, skill, difficulty, span)` ma NOVY nepovinny parametr
#     `span`: zily maji okno 80 (25..105), coz pevnych 50 z `SKILL_SPAN`
#     netrefi. Bez nej by se rust zastavil o 30 skillu driv.
#
# STAV JE CELE CISLO: banky drzi `current`/`max` v kusech, cas v ms; float je
# jen v lokalnim vypoctu pravdepodobnosti (`rng.chance(p)`).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2):
#   * tvar navratu `{ok, reason, kind, tile, amount, serial, hue, skill, gained,
#     success, message}` - smlouva zadava jen navratovy typ; bez `reason` by
#     "nic se nestalo" a "neni to hotove" vypadalo stejne,
#   * `_init(map, tiledata, registry, rng, clock, events, skill_gain, container,
#     serials)` - zavislosti KONSTRUKTOREM (jako `world.walk`, `sim.skill_gain`),
#     aby sel sber merit bez `SimWorld`,
#   * `resource_left(x, y)` je banka RUDY (smlouva ma jen dve souradnice);
#     ostatni druhy vydava `resource_left_kind(kind, x, y)`,
#   * opotrebeni naradi: sber vi o dlazdici a mobilu, ale NE o predmetu, kterym
#     hrac kope (`sim.interaction` ho zna, ale do `mine/chop/fish` ho neposila -
#     smlouva ma 3 argumenty). Naradi se proto neopotrebuje; je to VEDOME
#     omezeni. POZOR (2026-10-10): `entity.equipment` UZ EXISTUJE (commit 36cbe5c),
#     takze "dokud nebude" uz neplati - chybi jen PROPOJENI (nova granule).
#     Do te doby nastroj vydrzi vecne.
#   * `_busy_until` (jeden sber na system, jako `GetLock` v referenci) NENI
#     v save/load - stav bank se neuklada, dokud nesaveuje `sim.world_loop`.

const Const = preload("res://core/const.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const ITEM_OFFSET := 0x4000          # tiledata id -> art id (sim/entity/item.gd)
const MS_PER_MINUTE := 60000

const KIND_ORE := "ore"
const KIND_WOOD := "wood"
const KIND_FISH := "fish"

const SKILL_MINING := 45             # data/skills.json (mereno)
const SKILL_LUMBERJACKING := 44
const SKILL_FISHING := 18

# Druhy banku: velikost bucketu, kolik v nem je, jak dlouho se obnovuje,
# kolik se vyda za jeden usek (`HarvestDefinition`, research §1.1-§1.4).
const BANKS: Dictionary = {
	KIND_ORE: {"w": 8, "h": 8, "min_total": 10, "max_total": 34,
		"respawn_min": 10, "respawn_max": 20, "yield": 1, "swing_ms": 1600, "range": 2},
	KIND_WOOD: {"w": 4, "h": 3, "min_total": 20, "max_total": 45,
		"respawn_min": 20, "respawn_max": 30, "yield": 10, "swing_ms": 1600, "range": 2},
	KIND_FISH: {"w": 8, "h": 8, "min_total": 5, "max_total": 15,
		"respawn_min": 10, "respawn_max": 20, "yield": 1, "swing_ms": 8000, "range": 4},
}

# Predmety, ktere sber vyrobi. `tile` je ART ID (0x4000+): 0x19B8 = normalni
# hromada rudy, 0x1BDD = log (kanonicky `Log.cs:36`), 0x09CC-0x09CF = ryba
# (research §2.1). Barvu (kov/drevo) nese `hue`, ne art - v UO maji vsechny
# rudy i vsechna dreva stejny art (research §2.1/§2.2).
#
# ⚠ PROC 0x1BDD A NE 0x1BDE: `data/items.json` ma u role `logs` tiledata id
# 7134 (0x1BDE), ktere ma flagy `0x40` (Impassable) a NENI stackovatelne,
# kdezto kanonicky art pro log je 0x1BDD s flagy `0x4800` (Generic) - mereno
# v `assets/uo/tiles.json`. Kdo by vzal 7134, vyrobil by hromadu, ktera se
# NIKDY neslouci (`entity.container` stackuje jen s flagem 0x800).
const ORE_ART := 0x59B8
const LOG_ART := 0x5BDD
const FISH_ARTS: Array = [0x49CC, 0x49CD, 0x49CE, 0x49CF]

# 9 rud: `req` = ReqSkill (od jakeho skillu ji vubec vidis), `min`/`max` =
# okno rustu, `vein` = sance zily v procentech, `fallback` = sance na zelezo
# (research §1.2; hue z §2.2 `m_MetalInfo`). Hodnoty jsou v DESETINACH skillu.
const ORES: Array = [
	{"name": "iron", "hue": 0x000, "req": 0, "min": 0, "max": 1000, "vein": 49.6, "fallback": 0.0},
	{"name": "dull copper", "hue": 0x973, "req": 650, "min": 250, "max": 1050, "vein": 11.2, "fallback": 0.5},
	{"name": "shadow iron", "hue": 0x966, "req": 700, "min": 300, "max": 1100, "vein": 9.8, "fallback": 0.5},
	{"name": "copper", "hue": 0x96D, "req": 750, "min": 350, "max": 1150, "vein": 8.4, "fallback": 0.5},
	{"name": "bronze", "hue": 0x972, "req": 800, "min": 400, "max": 1200, "vein": 7.0, "fallback": 0.5},
	{"name": "gold", "hue": 0x8A5, "req": 850, "min": 450, "max": 1250, "vein": 5.6, "fallback": 0.5},
	{"name": "agapite", "hue": 0x979, "req": 900, "min": 500, "max": 1300, "vein": 4.2, "fallback": 0.5},
	{"name": "verite", "hue": 0x89F, "req": 950, "min": 550, "max": 1350, "vein": 2.8, "fallback": 0.5},
	{"name": "valorite", "hue": 0x8AB, "req": 990, "min": 590, "max": 1390, "vein": 1.4, "fallback": 0.5},
]

# 7 dreva (research §1.3 ML vetev tabulky; hue z §2.2 `m_WoodInfo`).
const WOODS: Array = [
	{"name": "normal", "hue": 0x000, "req": 0, "min": 0, "max": 1000, "vein": 49.0, "fallback": 0.0},
	{"name": "oak", "hue": 0x7DA, "req": 650, "min": 250, "max": 1050, "vein": 30.0, "fallback": 0.5},
	{"name": "ash", "hue": 0x4A7, "req": 800, "min": 400, "max": 1200, "vein": 10.0, "fallback": 0.5},
	{"name": "yew", "hue": 0x4A8, "req": 950, "min": 550, "max": 1350, "vein": 5.0, "fallback": 0.5},
	{"name": "heartwood", "hue": 0x4A9, "req": 1000, "min": 600, "max": 1400, "vein": 3.0, "fallback": 0.5},
	{"name": "bloodwood", "hue": 0x4AA, "req": 1000, "min": 600, "max": 1400, "vein": 2.0, "fallback": 0.5},
	{"name": "frostwood", "hue": 0x47F, "req": 1000, "min": 600, "max": 1400, "vein": 1.0, "fallback": 0.5},
]

# `m_MountainAndCaveTiles` (research §1.2) - land id; statiky 0x453B-0x454F.
const MINE_LAND: Array = [[220, 231], [236, 247], [252, 263], [268, 279], [286, 297],
	[321, 324], [467, 487], [492, 495], [543, 601], [610, 613], [1010, 1010],
	[1741, 1757], [1771, 1790], [1801, 1824], [1831, 1854], [1861, 1884],
	[1981, 2004], [2028, 2033], [2100, 2105]]
const MINE_STATIC: Array = [[0x453B, 0x454F]]

# `m_TreeTiles` (research §1.3) - art id statiku.
const TREE_STATIC: Array = [[0x4CCA, 0x4CCD], [0x4CD0, 0x4CD0], [0x4CD3, 0x4CD3],
	[0x4CD6, 0x4CD6], [0x4CD8, 0x4CD8], [0x4CDA, 0x4CDA], [0x4CDD, 0x4CDD],
	[0x4CE0, 0x4CE0], [0x4CE3, 0x4CE3], [0x4CE6, 0x4CE6], [0x4CF8, 0x4CF8],
	[0x4CFB, 0x4CFB], [0x4CFE, 0x4CFE], [0x4D01, 0x4D01], [0x4D41, 0x4D44],
	[0x4D57, 0x4D5B], [0x4D6E, 0x4D72], [0x4D84, 0x4D86], [0x52B5, 0x52BD],
	[0x4CCE, 0x4CCF], [0x4CD1, 0x4CD2], [0x4CD4, 0x4CD5], [0x4CD7, 0x4CD7],
	[0x4CD9, 0x4CD9], [0x4CDB, 0x4CDC], [0x4CDE, 0x4CDF], [0x4CE1, 0x4CE2],
	[0x4CE4, 0x4CE5], [0x4CE7, 0x4CE8], [0x4CF9, 0x4CFA], [0x4CFC, 0x4CFD],
	[0x4CFF, 0x4D00], [0x4D02, 0x4D03], [0x4D45, 0x4D53], [0x4D5C, 0x4D69],
	[0x4D73, 0x4D7F], [0x4D87, 0x4D90], [0x4D95, 0x4D97], [0x4D99, 0x4D9B],
	[0x4D9D, 0x4D9F], [0x4DA1, 0x4DA3], [0x4DA5, 0x4DA7], [0x4DA9, 0x4DAB],
	[0x52BE, 0x52C7]]

# `m_WaterTiles` (research §1.4): nizke rozsahy jsou land id, vysoke statiky.
const WATER_LAND: Array = [[0x00A8, 0x00AB], [0x0136, 0x0137]]
const WATER_STATIC: Array = [[0x5797, 0x579C], [0x746E, 0x7485], [0x7490, 0x74AB],
	[0x74B5, 0x75D5]]

const MESSAGE_FAIL_ORE := "You loosen some rocks but fail to find any useable ore."
const MESSAGE_FAIL_WOOD := "You chop the tree but fail to get any useable wood."
const MESSAGE_FAIL_FISH := "You fish for a while, but fail to catch anything."
const MESSAGE_FULL := "Your backpack cannot hold anything else."
# ⚠ 20. session (2026-10-08) - "NIKDY TICHO" PLATI I PRO TYHLE VETVE.
# Do teto session vracely `not_ore`/`not_tree`/`not_water`/`too_far`/`empty`/`busy`
# jen slovnik a hrac nevidel NIC: s obecnym interakcnim tlacitkem ("pouzij, co se
# na to hodi") to znamena, ze kliknuti na travu vypadalo jako rozbita hra.
# Texty jsou UO-ovske ("You can't mine that."), cisla clilocu nemame - je to text
# klonu, stejne jako `MESSAGE_FAIL_ORE` vyse (docs/11 O7).
const MESSAGE_NOT_ORE := "You can't mine that."
const MESSAGE_NOT_TREE := "You can't chop that."
const MESSAGE_NOT_WATER := "You can't fish there."
const MESSAGE_TOO_FAR := "That is too far away."
const MESSAGE_BUSY := "You must wait to perform another action."
const MESSAGE_EMPTY_ORE := "There is no metal left here."
const MESSAGE_EMPTY_WOOD := "There are no logs left here."
const MESSAGE_EMPTY_FISH := "The fish are not biting here."

var _map = null
var _tiledata = null
var _registry = null
var _rng = null
var _clock = null
var _events = null
var _skill_gain = null
var _container = null
var _serials = null
var _items = null                    # {serial: Item} - aby sel predmet dohledat (taveni)
var _banks: Dictionary = {}          # "kind:bx:by" -> bank
var _busy_until: Dictionary = {}     # kind -> ms, do kdy system "pracuje"
var _last_item = null                # posledni vydany predmet (do navratoveho slovniku)


func _init(map = null, tiledata = null, registry = null, rng = null, clock = null,
		events = null, skill_gain = null, container = null, serials = null, items = null) -> void:
	_map = map
	_tiledata = tiledata
	_registry = registry if registry != null else RegistryScript.new()
	_rng = rng if rng != null else RngScript.new(0)
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_skill_gain = skill_gain
	_container = container
	_serials = serials
	_items = items
	if _map == null or _tiledata == null:
		push_warning("sim.harvest: bez `map`/`tiledata` se neda zmerit, na cem se kope "
			+ "(sber vraci `not_ore`/`not_tree`/`not_water`)")


func register(mobile) -> void:
	_registry.register(mobile)


# -- rozhrani podle smlouvy ------------------------------------------------

func mine(m: int, x: int, y: int) -> Dictionary:
	return _harvest(KIND_ORE, m, x, y)


func chop(m: int, x: int, y: int) -> Dictionary:
	return _harvest(KIND_WOOD, m, x, y)


func fish(m: int, x: int, y: int) -> Dictionary:
	return _harvest(KIND_FISH, m, x, y)


func resource_left(x: int, y: int) -> int:
	# Banka RUDY (dve souradnice zadava smlouva); ostatni druhy viz nize.
	return resource_left_kind(KIND_ORE, x, y)


func resource_left_kind(kind: String, x: int, y: int) -> int:
	if not BANKS.has(kind) or x < 0 or y < 0:
		return 0
	return int(_bank(kind, x, y)["current"])


func resource_kind(x: int, y: int) -> String:
	# CO JE NA DLAZDICI ZA UZEL (20. session, pro obecnou interakci
	# `sim.interaction.interact`): "ore" / "wood" / "fish", nebo "" (nic).
	#
	# PROC TO NENI V `interaction`: rozhoduje SEZNAM DLAZDIC, a ten je tady
	# (`MINE_LAND`/`MINE_STATIC`/`TREE_STATIC`/`WATER_*`, docs/05 §5.7). Kdyby si
	# `interaction` vedl vlastni seznam, vznikl by druhy zdroj pravdy o tom, co je
	# "hora" - a obecne tlacitko by vybiralo nastroj podle neceho jineho, nez
	# podle ceho sbira `_harvest`.
	#
	# Poradi je dane: kdyz je dlazdice v obou seznamech (nemerene, ale mozne),
	# vyhraje ruda - stejne poradi pouziva `interact` pri volbe nastroje.
	if x < 0 or y < 0:
		return ""
	if _resource_tile(KIND_ORE, x, y) >= 0:
		return KIND_ORE
	if _resource_tile(KIND_WOOD, x, y) >= 0:
		return KIND_WOOD
	if _resource_tile(KIND_FISH, x, y) >= 0:
		return KIND_FISH
	return ""


# -- mereni (co test a sonda potrebuji videt) ------------------------------

func vein_name(kind: String, x: int, y: int) -> String:
	var tab: Array = _table(kind)
	if tab.is_empty():
		return ""
	return str(tab[int(_bank(kind, x, y)["vein"])]["name"])


func table_of(kind: String) -> Array:
	return _table(kind).duplicate(true)


func busy_until(kind: String) -> int:
	return int(_busy_until.get(kind, 0))


func stats() -> Dictionary:
	var out: Dictionary = {}
	for key in _banks:
		out[key] = int(_banks[key]["current"])
	return out


# -- vnitrni: sber ---------------------------------------------------------

func _harvest(kind: String, m: int, x: int, y: int) -> Dictionary:
	var mob = _mobile(m)
	if mob == null:
		# Neznamy mobil je VADA VOLAJICIHO, ne hracuv pokus - hlasku tu zamerne
		# NEDAVAME (hrac by videl "neco se pokazilo" za neco, co nezpusobil).
		return _fail(kind, "no_mobile")
	if x < 0 or y < 0:
		return _fail_msg(kind, "off_map")
	var p: Dictionary = BANKS[kind]
	var range_max: int = int(p["range"])
	if absi(int(mob.pos.x) - x) > range_max or absi(int(mob.pos.y) - y) > range_max:
		return _fail_msg(kind, "too_far")
	var now: int = _now()
	if now < int(_busy_until.get(kind, 0)):
		# Jeden sber na system (`GetLock` vraci `this`, research §1.1).
		return _fail_msg(kind, "busy")
	var tile: int = _resource_tile(kind, x, y)
	if tile < 0:
		return _fail_msg(kind, "not_" + ("ore" if kind == KIND_ORE else ("tree" if kind == KIND_WOOD else "water")))
	var bank: Dictionary = _bank(kind, x, y)
	var yield_amount: int = int(p["yield"])
	if int(bank["current"]) < yield_amount:
		return _fail_msg(kind, "empty")
	var skill: int = _skill_id(kind)
	var value: int = mob.skills.value(skill)
	var resource_index: int = resource_index_for(kind, int(bank["vein"]), value)
	var hod: Dictionary = _roll(kind, m, value, resource_index)
	var uspech: bool = bool(hod["success"])
	var zisk: bool = bool(hod["gained"])
	_busy_until[kind] = now + int(p["swing_ms"])
	if not uspech:
		# Neuspesny skill check nespotrebuje rudu ANI naradi (research §1.1 krok 8),
		# ale skill pri nem ROSTE (`gained` jde z `sim.skill_gain`) - proto se
		# `gained` vraci i u neuspechu, jinak by to hrac nevidel.
		_message(_fail_text(kind))
		return {"ok": false, "reason": "skill", "kind": kind, "skill": skill,
			"gained": zisk, "success": false, "tile": tile, "amount": 0, "serial": 0}
	var amount: int = yield_amount
	var hue: int = int(_table(kind)[resource_index]["hue"])
	var art: int = _art(kind, resource_index)
	if not _give(mob, art, amount, hue, x, y):
		return _fail(kind, "no_pack")
	bank["current"] = int(bank["current"]) - amount
	if int(bank["current"]) <= 0:
		bank["next_ms"] = now + _rng.range_i(int(p["respawn_min"]), int(p["respawn_max"])) * MS_PER_MINUTE
	var item = _last_item
	_message("You gather some " + str(_table(kind)[resource_index]["name"]) + ".")
	return {"ok": true, "reason": "", "kind": kind, "skill": skill, "gained": zisk,
		"success": true, "tile": tile, "art": art, "amount": amount, "hue": hue,
		"serial": int(item.serial) if item != null else 0, "item": item,
		"resource": str(_table(kind)[resource_index]["name"]),
		"left": int(bank["current"]), "busy_ms": int(p["swing_ms"])}


func _roll(kind: String, m: int, value: int, resource_index: int) -> Dictionary:
	# Vraci `{success, gained}` - `gained` je rust skillu z TEHOZ hodu
	# (`sim.skill_gain.check` rozhoduje o uspechu i rustu; docs/05 §5.10).
	var tab: Array = _table(kind)
	var r: Dictionary = tab[resource_index]
	if kind == KIND_FISH:
		# Melka voda: `Fishing >= 75` uspeje bez hodu a bez rustu (research §1.4).
		if value >= 750:
			return {"success": true, "gained": false}
		return _check(m, SKILL_FISHING, 0, 1200)
	return _check(m, _skill_id(kind), int(r["min"]), int(r["max"]) - int(r["min"]))


func _check(m: int, skill: int, difficulty: int, span: int) -> Dictionary:
	if _skill_gain == null:
		return {"success": false, "gained": false}
	var out = _skill_gain.check(m, skill, difficulty, span)
	if out is Dictionary:
		return {"success": bool(out.get("success", false)), "gained": bool(out.get("gained", false))}
	return {"success": false, "gained": false}


func _give(mob, art: int, amount: int, hue: int, x: int, y: int) -> bool:
	# Predmet jde do batohu (`entity.container`); kdyz batoh neni, hlasi se to.
	if _container == null or _serials == null or int(mob.backpack) <= 0:
		return false
	var item = ItemScript.new(int(_serials.next_serial()), art, amount)
	item.hue = hue
	item.pos = Vector3i(x, y, int(mob.pos.z))
	if not _container.add(int(mob.backpack), item):
		_last_item = null
		_message(MESSAGE_FULL)
		return false
	# Registrace podle serialu: `sim.craft.smelt` hleda rudu podle serialu
	# (predmety nikdo jiny nedrzi - otevrena vec 64).
	if _items is Dictionary:
		_items[int(item.serial)] = item
	_last_item = item
	return true


# -- vnitrni: banky a zily -------------------------------------------------

func _bank(kind: String, x: int, y: int) -> Dictionary:
	var p: Dictionary = BANKS[kind]
	var bx: int = x / int(p["w"])
	var by: int = y / int(p["h"])
	var key: String = "%s:%d:%d" % [kind, bx, by]
	var bank = _banks.get(key)
	if bank == null:
		bank = {"current": 0, "max": 0, "next_ms": 0, "vein": 0}
		_banks[key] = bank
		_refill(kind, bank, bx, by)
	elif int(bank["current"]) <= 0 and _now() >= int(bank["next_ms"]):
		_refill(kind, bank, bx, by)
	return bank


func _refill(kind: String, bank: Dictionary, bx: int, by: int) -> void:
	var p: Dictionary = BANKS[kind]
	bank["max"] = _rng.range_i(int(p["min_total"]), int(p["max_total"]))
	bank["current"] = int(bank["max"])
	bank["next_ms"] = 0
	bank["vein"] = _pick_vein(kind, bx, by)


func _pick_vein(kind: String, bx: int, by: int) -> int:
	# Deterministicky podle bucketu (vetev pre-ML reference: `new Random(bx*17+by*11+3)`,
	# research §1.1). Vlastnost, ktera se opakuje: stejny bucket = stejna zila
	# a NIKDY se neprehodi. Konkretni hodnota je jina nez `System.Random` (jiny
	# generator) - shoduje se vlastnost, ne cislo.
	var local = RngScript.new(bx * 17 + by * 11 + 3)
	var roll: float = float(local.next_u32()) / RngScript.U32_RANGE * 100.0
	var tab: Array = _table(kind)
	for i in tab.size():
		var chance: float = float(tab[i]["vein"])
		if roll <= chance:
			return i
		roll -= chance
	return 0


func resource_index_for(kind: String, vein_index: int, value: int) -> int:
	# `MutateResource` (research §1.1 krok 3): barevna zila pada na zaklad
	# (zelezo / normalni drevo), kdyz padne 50 % hod NEBO kdyz skill na zilu
	# nestaci (`ReqSkill` i `MinSkill`). Verejne, aby se pravidlo dalo merit
	# bez hodu na horu s barevnou zilou.
	if kind == KIND_FISH:
		return 0
	var tab: Array = _table(kind)
	var r: Dictionary = tab[vein_index]
	var fallback: float = float(r.get("fallback", 0.0))
	if fallback <= 0.0:
		return vein_index
	if _rng.chance(fallback):
		return 0
	if value < int(r["req"]) or value < int(r["min"]):
		return 0
	return vein_index


func _art(kind: String, resource_index: int) -> int:
	if kind == KIND_ORE:
		return ORE_ART
	if kind == KIND_WOOD:
		return LOG_ART
	return int(FISH_ARTS[resource_index % FISH_ARTS.size()])


func _table(kind: String) -> Array:
	if kind == KIND_ORE:
		return ORES
	if kind == KIND_WOOD:
		return WOODS
	return [{"name": "fish", "hue": 0, "req": 0, "min": 0, "max": 1200, "vein": 100.0, "fallback": 0.0}]


func _skill_id(kind: String) -> int:
	if kind == KIND_ORE:
		return SKILL_MINING
	if kind == KIND_WOOD:
		return SKILL_LUMBERJACKING
	return SKILL_FISHING


func _fail_text(kind: String) -> String:
	if kind == KIND_ORE:
		return MESSAGE_FAIL_ORE
	if kind == KIND_WOOD:
		return MESSAGE_FAIL_WOOD
	return MESSAGE_FAIL_FISH


# -- vnitrni: dlazdice -----------------------------------------------------

func _resource_tile(kind: String, x: int, y: int) -> int:
	# Vraci id dlazdice, ktera pro dany sber plati, nebo -1. U statiku se
	# normalizuje `(ItemID & 0x3FFF) | 0x4000` (research §1.1 krok 1).
	if kind == KIND_ORE:
		var land: int = _land(x, y)
		if land >= 0 and _in_ranges(land, MINE_LAND):
			return land
		var statik: int = _static_tile(x, y, MINE_STATIC)
		if statik >= 0:
			return statik
		# ⚠ PREDMET NA ZEMI (2026-10-10, D10 "demo"): ruda je na teto mape
		# NEJBLIZSI 132 dlazdic od Britainu (`_analyza/p35c-sonda-hory.gd`) a
		# stanice i prodejce stoji u Britainu - nez se dobehne cesta/regiony,
		# stoji u Britainu par BALVANU jako predmety (`app/main._postav_balvany`).
		# Je to stejna trida sesitku jako `_postav_stanice` (kovadlina/vyhen):
		# pozdeji ji nahradi mapa (doly) nebo `world.regions` - viz HANDOFF.
		return _item_tile(x, y, MINE_STATIC)
	if kind == KIND_WOOD:
		return _static_tile(x, y, TREE_STATIC)
	var l: int = _land(x, y)
	if l >= 0 and _in_ranges(l, WATER_LAND):
		return l
	return _static_tile(x, y, WATER_STATIC)


func _land(x: int, y: int) -> int:
	if _map == null or not _map.has_method("land_at"):
		return -1
	return int(_map.land_at(x, y))


func _static_tile(x: int, y: int, ranges: Array) -> int:
	if _map == null or not _map.has_method("statics_at"):
		return -1
	var lokalni_x: int = x % Const.BLOCK_SIZE
	var lokalni_y: int = y % Const.BLOCK_SIZE
	# `map.statics_at` vraci CELY blok, ne dlazdici - filtr na lokalni x,y je
	# povinny (stejne to dela `world.walk._statiky`).
	for s in _map.statics_at(x, y):
		if int(s.get("x", -1)) != lokalni_x or int(s.get("y", -1)) != lokalni_y:
			continue
		if _in_ranges(_art_of(int(s["tile"])), ranges):
			return _art_of(int(s["tile"]))
	return -1


func _item_tile(x: int, y: int, ranges: Array) -> int:
	# Predmet NA ZEMI jako zdroj sberu (2026-10-10, viz `_resource_tile`).
	# Hleda se stejnym pravidlem jako statik: art v `ranges` a presna dlazdice
	# (`parent == 0` = na zemi, `docs/04 §4.5`). Kdyby se ptalo jen na art,
	# "ruda" by platila i pro balvan v batohu hrace.
	if not (_items is Dictionary):
		return -1
	for serial in _items:
		var item = _items[serial]
		if item == null or int(item.parent) != 0:
			continue
		if int(item.pos.x) != x or int(item.pos.y) != y:
			continue
		var art: int = int(item.tile)
		if _in_ranges(art, ranges):
			return art
	return -1


func _art_of(tile: int) -> int:
	# Normalizace statiku na ART ID: `entity.item.tile` je art id a seznamy
	# dlazdic jsou psane v art prostoru. `map.statics_at` u nas vraci tiledata
	# id (mereno: hodnoty pod 0x4000), ale v art prostoru uz muze byt - proto
	# `tile + 0x4000`, dokud je pod offsetem (pro art >= 0x4000 je to
	# identita, coz je totez jako `(ItemID & 0x3FFF) | 0x4000`, research §1.1).
	return tile if tile >= ITEM_OFFSET else tile + ITEM_OFFSET


func _in_ranges(value: int, ranges: Array) -> bool:
	for r in ranges:
		if value >= int(r[0]) and value <= int(r[1]):
			return true
	return false


# -- vnitrni: zaklad -------------------------------------------------------

func _mobile(m: int):
	return _registry.get_mobile(m)


func _now() -> int:
	return int(_clock.now_ms())


func _fail(kind: String, reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "kind": kind, "skill": _skill_id(kind),
		"gained": false, "success": false, "tile": 0, "amount": 0, "serial": 0}


func _fail_msg(kind: String, reason: String) -> Dictionary:
	# Selhani, ktere HRAZ VIDI: hrac neco zkusil a musi se dozvedet, proc to
	# neslo (docs/05 §5.2.2 "nikdy ticho"). Text je prazdny jen u `no_mobile`
	# (vada volajiciho) - kdyby vratil prazdno i jinde, je to chyba a test to
	# pozna podle chybejici hlasky.
	var text: String = _fail_message(kind, reason)
	if text != "":
		_message(text)
	return _fail(kind, reason)


func _fail_message(kind: String, reason: String) -> String:
	match reason:
		"off_map":
			return MESSAGE_TOO_FAR
		"too_far":
			return MESSAGE_TOO_FAR
		"busy":
			return MESSAGE_BUSY
		"empty":
			if kind == KIND_ORE:
				return MESSAGE_EMPTY_ORE
			return MESSAGE_EMPTY_WOOD if kind == KIND_WOOD else MESSAGE_EMPTY_FISH
		"not_ore":
			return MESSAGE_NOT_ORE
		"not_tree":
			return MESSAGE_NOT_TREE
		"not_water":
			return MESSAGE_NOT_WATER
	return ""


func _message(text: String) -> void:
	if _events != null:
		_events.push("message", {"text": text, "kind": "system"})
