extends RefCounted
# Interakce mezi objekty: `use` (dvojklik), `use_on` (pouziti na cil) a
# kontextove menu (granule `sim.interaction`; smlouva docs/04 §4.2 + §4.2.1,
# rozhodovani docs/05 §5.2.2, parova tabulka §5.2.3).
#
# ODKUD SE ROZHODUJE (merena data, ne opsana proza):
#   * `data/items.json` (granule `data.items`, 8748 zaznamu) ma u kazdeho artu
#     `category` a `role` - routing se rozhoduje z nich, ne z tabulky v kódu.
#     POZOR NA ID PROSTOR: data maji TILEDATA ID (mereno: nazvy v `tiles.json`
#     sedi na indexu `tile`, i u 4744 zaznamu s `tile >= 0x4000`), `entity.item.tile`
#     je ART ID (0x4000+) - modul proto hleda NEJDRIV `tile - 0x4000`. Prostory se
#     prekryvaji, takze z cisla se to poznat neda; prima `tile` je jen fallback.
#   * `data/skills.json` dava id skillu pro craft gump (Blacksmithy 7, Carpentry
#     11, Tailoring 34, Tinkering 37, Inscription 23 - merene v datech).
#   * kontextove menu: 0x0078 (Open Backpack) a 0x0193 (Paperdoll) jsou cisla,
#     ktera klient zna (ServUO `Server/ContextMenus/ContextMenu.cs:178-256`,
#     citace v research/01 §2.4); cisla >= 0x64 jsou pro VLASTNI polozky
#     (tamtéz) - jina jmena nez ta dve maji proto `custom: true` (clilocy jsou
#     UNVERIFIED, docs/11 O7).
#
# ⚠ ODCHYLKA OD SMLOUVY (docs/04 §4.2 melo `use`/`use_on`/`context_action`
# `->void`): vraceji `Dictionary` s `{ok, reason, action}`, protoze bez toho by
# "nic se nestalo" a "neni to hotove" vypadalo stejne (presne ta vada, kterou
# cíl 10. session zakazuje). `context_menu` vraci `Array[Dictionary]` dle smlouvy.
#
# ⚠ CO NEMA PRODUCENTA (pojmenovane, ne zamlcene - HANDOFF, otevrena vec 68):
#   * PREDMETY: `entity.item` nikdo nedrzi podle serialu (vec 64); modul je bere
#     VSTUPEM (`items` = `{serial: Item}` nebo objekt s `get_item(serial)`),
#   * `sim.craft`, `sim.magic`, `sim.harvest`, `sim.vendor`, `sim.combat` ani
#     `entity.equipment` nejsou v `SimWorld.systems` - routing na ne je dynamicky
#     a vraci `{ok:false, reason:"not_available"}`, NIKDY ticho,
#   * `anvil` a `forge` maji v datech `category == "tool"`, ale jsou to CÍLE, ne
#     nastroje - proto `TARGET_ROLES`. Bez toho by dvojklik na kovadlinu delal
#     "cekam na cil" (a prijimaci kriterium chce, aby rekl, ze nic nedela),
#   * §5.2.3 ma 36 radku a pokrytych je 10 (11 paru; radek 26 ma dve podoby
#     materialu). Zbytek potrebuje data, ktera v `data/items.json` NEJSOU (ryba,
#     vlna, nit, obvaz, klic, lockpick, pochoden, svitek do knihy, reagent, runa,
#     moongate, srp, vedro, mech, sextant, hodiny) - chybejici radek odpovi
#     hlaskou, nikdy tichem,
#   * kontejner se otevira `use` (vetev `open_container`), ne parovou kombinaci;
#     "use_on na kontejner" ze smlouvy je tim pokryte pres `use_on` na cil, ktery
#     je v kontejneru (`item` cil).

const Const = preload("res://core/const.gd")

const ITEMS_PATH := "res://data/items.json"
const SKILLS_PATH := "res://data/skills.json"
const ITEM_OFFSET := 0x4000               # tiledata id -> art id (item.gd)

const MESSAGE_NOTHING := "You see nothing special."
const MESSAGE_UNAVAILABLE := "Not available yet."

const ENTRY_CUSTOM_MIN := 0x64            # >= 0x64 = vlastni polozka
const ENTRY_BACKPACK := 0x0078            # Open Backpack (self)
const ENTRY_PAPERDOLL := 0x0193           # Paperdoll (self)

# `category == "tool"` obsahuje i kovadlinu a vyhen - jsou to CÍLE, ne nastroje
# (mereno nad `data/items.json`: 18 zaznamu `tool`, z toho 16 nastroju).
const TARGET_ROLES: Array[String] = ["anvil", "forge"]

const EQUIPMENT_CATEGORIES: Array[String] = ["weapon", "armor", "shield", "clothing"]

# §5.2.2 - jedina tabulka rozhodovani; poradi je poradi tabulky. `kdo` umi
# rozpoznat `describe()` a kazda vetev ma test.
const USE_ROUTES: Array[Dictionary] = [
	{"kdo": "door", "akce": "toggle_door"},
	{"kdo": "container", "akce": "open_container"},
	{"kdo": "vendor", "akce": "open_vendor"},
	{"kdo": "tool", "akce": "target"},
	{"kdo": "scroll", "akce": "cast_scroll"},
	{"kdo": "equipment", "akce": "equip"},
	{"kdo": "light", "akce": "light"},
	{"kdo": "mobile", "akce": "attack_or_talk"},
	{"kdo": "unknown", "akce": "nothing"},
]

# §5.2.3 - parova tabulka. `od`/`na` jsou `role` z `data/items.json`; `na` muze
# byt i `"tile"` (cil do sveta, docs/04 §4.3 `target.kind == "tile"`). `skill` je
# jmeno z `data/skills.json`; `system`/`method` je DYNAMICKY routing.
const PAIRS: Array[Dictionary] = [
	{"od": "iron ore", "na": "forge", "akce": "smelt", "system": "craft", "method": "smelt"},
	{"od": "iron ore", "na": "iron ore", "akce": "merge_piles"},
	{"od": "cloth", "na": "butcher knife", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Tailoring"},
	{"od": "scribe pen", "na": "scroll", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Inscription"},
	{"od": "butcher knife", "na": "logs", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Bowcraft/Fletching"},
	{"od": "smith hammer", "na": "anvil", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Blacksmithy"},
	{"od": "sewing kit", "na": "cloth", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Tailoring"},
	{"od": "saw", "na": "logs", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Carpentry"},
	{"od": "saw", "na": "boards", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Carpentry"},
	{"od": "tinker tools", "na": "iron ingot", "akce": "craft_gump", "system": "craft", "method": "recipes_for", "skill": "Tinkering"},
	{"od": "shovel", "na": "tile", "akce": "harvest", "system": "harvest", "method": "mine"},
	{"od": "pickaxe", "na": "tile", "akce": "harvest", "system": "harvest", "method": "mine"},
	{"od": "hatchet", "na": "tile", "akce": "harvest", "system": "harvest", "method": "chop"},
	{"od": "axe", "na": "tile", "akce": "harvest", "system": "harvest", "method": "chop"},
	{"od": "fishing pole", "na": "tile", "akce": "harvest", "system": "harvest", "method": "fish"},
]

var _world = null            # SimWorld (nebo stub s `systems`) - dynamicky routing
var _events = null           # core/events.gd - jedina cesta k klientovi
var _doors = null            # world.doors
var _containers = null       # entity.container (jedna instance pro cely svet)
var _registry = null         # sim.entity_registry
var _items = null            # {serial: Item} nebo objekt s `get_item(serial)`
var _by_tile: Dictionary = {}   # tiledata id -> {category, role}
var _skills: Dictionary = {}    # jmeno -> id (data/skills.json)
var _cursor: int = 0


func _init(world = null, events = null, doors = null, containers = null,
		registry = null, items = null) -> void:
	_world = world
	_events = events
	_doors = doors
	_containers = containers
	_registry = registry
	_items = items
	_load_items()
	_load_skills()


# -- rozhrani podle smlouvy ------------------------------------------------

func use(m: int, serial: int) -> Dictionary:
	# Dvojklik (docs/05 §5.2.2). Neznama vetev NIKDY neni ticho.
	var cil: Dictionary = describe(serial)
	var route: Dictionary = route_of(str(cil["kind"]))
	return _run_use(m, serial, cil, str(route["akce"]))


func use_on(m: int, serial: int, target: Dictionary) -> Dictionary:
	# "Pouzij na cil" (docs/05 §5.2.3). Chybejici system = `not_available`.
	if _item(serial) == null:
		return _fail("no_item")
	var cil: Dictionary = describe(serial)
	var na: Dictionary = _describe_target(target)
	var par: Dictionary = pair_of(cil, na)
	if par.is_empty():
		return _fail("no_pair")
	return _run_pair(m, cil, na, par)


func context_menu(m: int, serial: int) -> Array[Dictionary]:
	# Pravy klik / klik na sebe (docs/05 §5.2.1). Cisla >= 0x64 jsou vlastni.
	var out: Array[Dictionary] = []
	if serial == 0 or serial == m:
		out.append({"entry": ENTRY_BACKPACK, "text": "Open Backpack", "custom": false})
		out.append({"entry": ENTRY_PAPERDOLL, "text": "Paperdoll", "custom": false})
		out.append({"entry": ENTRY_CUSTOM_MIN, "text": "Status", "custom": true})
		out.append({"entry": ENTRY_CUSTOM_MIN + 1, "text": "Skills", "custom": true})
		return out
	var cil: Dictionary = describe(serial)
	if str(cil["kind"]) == "unknown":
		_message(MESSAGE_NOTHING)
		return out
	var kdo: String = str(cil["kind"])
	if kdo == "vendor" or kdo == "mobile":
		out.append({"entry": ENTRY_CUSTOM_MIN, "text": "Attack", "custom": true})
		out.append({"entry": ENTRY_CUSTOM_MIN + 1, "text": "Look", "custom": true})
	elif kdo == "container":
		out.append({"entry": ENTRY_CUSTOM_MIN, "text": "Open", "custom": true})
	else:
		out.append({"entry": ENTRY_CUSTOM_MIN, "text": "Look", "custom": true})
	return out


func context_action(m: int, serial: int, entry: int) -> Dictionary:
	match entry:
		ENTRY_BACKPACK:
			var mob = _mobile(m)
			if mob == null or int(mob.backpack) <= 0:
				return _fail("not_available")
			_event("gump_open", {"gump": "container", "data": {"serial": int(mob.backpack)}})
			return {"ok": true, "action": "open_backpack", "reason": ""}
		ENTRY_PAPERDOLL:
			# ⚠ docs/04 §4.4 gump "paperdoll" v seznamu NEMA (je to dira ve
			# smlouve, viz hlavicka) - dokud se nedoplni, posilame ho takhle.
			_event("gump_open", {"gump": "paperdoll", "data": {"serial": m}})
			return {"ok": true, "action": "paperdoll", "reason": ""}
	if entry >= ENTRY_CUSTOM_MIN:
		return _fail("not_available")
	return _fail("unknown_entry")


# -- to, co pouziva test (a co je merene) ----------------------------------

func describe(serial: int) -> Dictionary:
	# Co je cil: `kind` je to, podle ceho rozhoduje §5.2.2.
	var item = _item(serial)
	if item != null:
		var tile: int = int(item.tile)
		var cat: String = category_of(tile)
		var role: String = role_of(tile)
		var kind: String = "unknown"
		if _is_door(tile):
			kind = "door"
		elif cat == "container":
			kind = "container"
		elif cat == "tool" and not (role in TARGET_ROLES):
			kind = "tool"
		elif role == "scroll":
			kind = "scroll"
		elif cat in EQUIPMENT_CATEGORIES:
			kind = "equipment"
		elif cat == "light":
			kind = "light"
		return {"kind": kind, "serial": serial, "tile": tile,
			"category": cat, "role": role, "item": item}
	var mob = _mobile(serial)
	if mob != null:
		# Vendor je AI stav (docs/05 §5.3), ne novy flag - data/vendors.json
		# jeste nejsou, ale stav "vendor" je dokumentovany.
		var stav: String = str(mob.ai.get("state", "")) if mob.ai is Dictionary else ""
		return {"kind": "vendor" if stav == "vendor" else "mobile", "serial": serial,
			"tile": 0, "category": "", "role": "", "mobile": mob}
	return {"kind": "unknown", "serial": serial, "tile": 0, "category": "", "role": ""}


func route_of(kind: String) -> Dictionary:
	for route in USE_ROUTES:
		if str(route["kdo"]) == kind:
			return route
	return {"kdo": kind, "akce": "nothing"}


func pair_of(od: Dictionary, na: Dictionary) -> Dictionary:
	# `na` je role u predmetu, nebo "tile" u cíle do sveta.
	var hledane_na: String = "tile" if str(na.get("kind", "")) == "tile" else str(na.get("role", ""))
	for par in PAIRS:
		if str(par["od"]) == str(od.get("role", "")) and str(par["na"]) == hledane_na:
			return par
	return {}


func category_of(tile: int) -> String:
	return str(_record(tile).get("category", ""))


func role_of(tile: int) -> String:
	return str(_record(tile).get("role", ""))


func skill_id(name: String) -> int:
	return int(_skills.get(name, -1))


func has_data() -> bool:
	return not _by_tile.is_empty() and not _skills.is_empty()


func cursor() -> int:
	return _cursor


# -- vnitrni: vetve `use` --------------------------------------------------

func _run_use(m: int, serial: int, cil: Dictionary, akce: String) -> Dictionary:
	match akce:
		"toggle_door":
			return _toggle_door(cil)
		"open_container":
			return _open_container(serial)
		"open_vendor":
			return _call("vendor", "stock", [serial], akce)
		"target":
			_cursor += 1
			_event("target_request", {"cursor": cursor(), "kind": "object", "allow_ground": true})
			return {"ok": true, "action": akce, "reason": "", "cursor": cursor()}
		"cast_scroll":
			var spell: int = int(cil["item"].props.get("spell", 0))
			return _call("magic", "cast", [m, spell], akce)
		"equip":
			return _call("equipment", "equip", [m, serial], akce)
		"light":
			return _call("light", "toggle", [m, serial], akce)
		"attack_or_talk":
			return _call("combat", "attack", [m, serial], akce)
	return _fail("unknown")


func _toggle_door(cil: Dictionary) -> Dictionary:
	if _doors == null:
		return _fail("not_available")
	var tile: int = int(cil["tile"])
	var novy: int = int(_doors.toggle(tile))
	if novy == 0:
		return _fail("not_a_door")
	cil["item"].tile = novy            # stav dveri je ART (docs/03 §3.6)
	# ⚠ docs/04 §4.4 nema udalost "art existujiciho predmetu se zmenil" - nejbliz
	# je `item_added` se stejnym serialem (obnoveni u klienta). Je to dira ve
	# smlouve, viz hlavicka; povolane se to hlasi, ne zamlcuje.
	_event("item_added", _item_event(cil["item"]))
	return {"ok": true, "action": "toggle_door", "reason": "", "tile": novy,
		"open": bool(_doors.is_open(novy))}


func _open_container(serial: int) -> Dictionary:
	if _containers == null:
		return _fail("not_available")
	var obsah: Array = _containers.contents(serial)
	_event("container_contents", {"serial": serial, "items": obsah})
	_event("gump_open", {"gump": "container", "data": {"serial": serial, "items": obsah}})
	return {"ok": true, "action": "open_container", "reason": "", "items": obsah}


# -- vnitrni: parove kombinace --------------------------------------------

func _run_pair(m: int, od: Dictionary, na: Dictionary, par: Dictionary) -> Dictionary:
	var akce: String = str(par["akce"])
	if akce == "merge_piles":
		return _merge(od, na)
	if not par.has("system"):
		return _fail("no_pair")
	var akce2: String = akce
	var args: Array = []
	if akce2 == "smelt":
		args = [m, int(od["serial"]), int(na["serial"])]
	elif akce2 == "craft_gump":
		var skill: int = skill_id(str(par.get("skill", "")))
		if skill < 0:
			return _fail("no_data")      # chybejici skill NENI "neni to hotove"
		args = [m, skill]
	elif akce2 == "harvest":
		args = [m, int(na.get("x", 0)), int(na.get("y", 0))]
	else:
		return _fail("no_pair")
	return _call(str(par["system"]), str(par["method"]), args, akce2)


func _merge(od: Dictionary, na: Dictionary) -> Dictionary:
	# "ore | dalsi ore | spojeni hromadek" (docs/05 §5.2.3): slouci se jen
	# stejna hromada (stejny `tile` + `hue`, `item.same_pile`) do MAX_STACK.
	var cil = na.get("item")
	var zdroj = od.get("item")
	if cil == null or zdroj == null or not zdroj.same_pile(cil):
		return _fail("no_pair")
	var prevedeno: int = mini(int(zdroj.amount), Const.MAX_STACK - int(cil.amount))
	cil.amount = int(cil.amount) + prevedeno
	zdroj.amount = int(zdroj.amount) - prevedeno
	return {"ok": true, "action": "merge_piles", "reason": "",
		"moved": prevedeno, "left": int(zdroj.amount)}


# -- vnitrni: dynamicky routing -------------------------------------------

func _call(system_name: String, method: String, args: Array, akce: String) -> Dictionary:
	# Kdyz system v `SimWorld.systems` neni, vraci se `not_available` - nikdy ticho.
	var system = _system(system_name)
	if system == null or not system.has_method(method):
		return _fail("not_available")
	var res = system.callv(method, args)
	if res == null:
		# Volani selhalo (napr. spatny pocet argumentu) - NESMI se tvarit jako
		# uspech: vracime duvod, ktery je videt (a test to chyti).
		return _fail("bad_system")
	if res is Dictionary:
		return res
	return {"ok": true, "action": akce, "reason": ""}


func _system(name: String):
	if _world == null:
		return null
	var systems = _world.get("systems")
	if systems is Dictionary and systems.has(name):
		return systems[name]
	return null


func _item(serial: int):
	if _items == null or serial == 0:
		return null
	if _items is Dictionary:
		return _items.get(serial)
	if _items is Object and _items.has_method("get_item"):
		return _items.get_item(serial)
	return null


func _mobile(serial: int):
	return null if _registry == null else _registry.get_mobile(serial)


func _describe_target(target: Dictionary) -> Dictionary:
	match str(target.get("kind", "")):
		"item", "mobile":
			return describe(int(target.get("serial", 0)))
		"tile":
			return {"kind": "tile", "serial": 0, "role": "tile", "category": "tile",
				"x": int(target.get("x", 0)), "y": int(target.get("y", 0)),
				"z": int(target.get("z", 0))}
	return {"kind": "unknown", "serial": 0, "role": "", "category": ""}


func _is_door(tile: int) -> bool:
	return _doors != null and _doors.is_door(tile)


func _fail(reason: String) -> Dictionary:
	# Jedina cesta, jak rict "nic se nestalo" - vzdy s hláskou do zurnalu.
	_message(MESSAGE_NOTHING if reason in ["unknown", "no_pair", "no_item", "not_a_door",
		"unknown_entry"] else MESSAGE_UNAVAILABLE)
	return {"ok": false, "action": "", "reason": reason}


func _event(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)


func _message(text: String) -> void:
	_event("message", {"text": text, "kind": "system"})


func _item_event(item) -> Dictionary:
	return {"serial": int(item.serial), "tile": int(item.tile), "hue": int(item.hue),
		"amount": int(item.amount), "parent": int(item.parent), "layer": int(item.layer),
		"x": int(item.pos.x), "y": int(item.pos.y), "z": int(item.pos.z)}


# -- vnitrni: data ---------------------------------------------------------

func _record(tile: int) -> Dictionary:
	# Dve id prostranstvi se PREKRYVAJI (tiledata id 0-65535, art id 0x4000-0xFFFF):
	# z cisla samotneho se neda poznat, ktere to je. `entity.item.tile` je ART ID
	# (docs/03 §3.4, item.gd), proto se hleda NEJDRIV art konvence (`tile - 0x4000`)
	# a teprve pak prime `tile` (pro volajiciho, ktery preda tiledata id).
	if tile >= ITEM_OFFSET:
		var rec = _by_tile.get(tile - ITEM_OFFSET)
		if rec != null:
			return rec
	return _by_tile.get(tile, {})


func _load_items() -> void:
	if not FileAccess.file_exists(ITEMS_PATH):
		push_warning("sim.interaction: chybi " + ITEMS_PATH + " - routing bude jen `unknown`")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not (parsed is Array):
		push_warning("sim.interaction: " + ITEMS_PATH + " neni seznam")
		return
	for rec in parsed:
		if rec is Dictionary and rec.has("tile"):
			# JSON vraci cisla jako float (HANDOFF past 10) - vzdy int().
			_by_tile[int(rec["tile"])] = {
				"category": str(rec.get("category", "")),
				"role": str(rec.get("role", "")),
			}


func _load_skills() -> void:
	if not FileAccess.file_exists(SKILLS_PATH):
		push_warning("sim.interaction: chybi " + SKILLS_PATH + " - craft gump se nespusti")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	if not (parsed is Array):
		push_warning("sim.interaction: " + SKILLS_PATH + " neni seznam")
		return
	for rec in parsed:
		if rec is Dictionary and rec.has("name") and rec.has("id"):
			_skills[str(rec["name"])] = int(rec["id"])
