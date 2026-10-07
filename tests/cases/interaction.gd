extends RefCounted
# sim.interaction - `use` / `use_on` / kontextove menu (smlouva docs/04 §4.2 a
# §4.2.1, rozhodovani docs/05 §5.2.2, parova tabulka §5.2.3).
#
# Test meri CHOVANI, ne existenci souboru:
#   * kazda vetev §5.2.2 ma test a kazda odpovi HLASKOU, kdyz nic nedela
#     ("neznamy predmet -> hlaska, nikdy ticho"),
#   * `use` na kovadlinu (role `anvil`, v datech `category == "tool"`) nic
#     neudela a REKNE to - kdyby se kovadlina brala jako nastroj, delala by
#     "cekam na cil",
#   * dynamicky routing: chybejici system -> `{ok:false, reason:"not_available"}`,
#     pritomny stub -> ZAVOLANA metoda se spravnymi argumenty (meri se `volani`),
#   * parova tabulka §5.2.3 stoji na REALNYCH datech: kazda `od`/`na` role musi
#     v `data/items.json` existovat (jinak je to proza),
#   * pokryti §5.2.3 se meri PROTI DOKUMENTU: pocet radku tabulky + presna
#     mnozina paru (co je v kódu a co v dokumentu) - novy radek v docs/05 test
#     shodi, dokud se nedoplni pokryti,
#   * cesta k souboru granule je VSTUP (`-- --interaction-script=<cesta>`).
#
# Vsechna data, ktera test potrebuje (`data/*.json`, `docs/05`), jsou v gitu,
# takze se meri i v CI (kde `assets/uo/` nejsou). Kdyby data chybela, hlasi se
# to jako NEMERENO - ne jako zelená.

const Lib = preload("res://tests/lib.gd")

const INTERACTION_SCRIPT := "res://sim/systems/interaction.gd"
const ITEM_SCRIPT := "res://sim/entity/item.gd"
const CONTAINER_SCRIPT := "res://sim/entity/container.gd"
const REGISTRY_SCRIPT := "res://sim/entity/registry.gd"
const DOORS_SCRIPT := "res://sim/world/doors.gd"
const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const EVENTS_SCRIPT := "res://core/events.gd"
const ITEMS_PATH := "res://data/items.json"
const SKILLS_PATH := "res://data/skills.json"
const DOCS05_PATH := "res://docs/05-mechaniky.md"

const ART := 0x4000                 # tiledata id -> art id (item.gd, hlavicka)
const MAX_STACK := 60000
const HRAC := 0x40000001
const NPC := 0x40000002
const DOOR_TILE := 1721             # art z doors.txt = ZAVRENY (8. session)

# Cisla, ktera klient zna (research/01 §2.4); ostatni jsou >= 0x64 = vlastni.
const ENTRY_BACKPACK := 0x0078
const ENTRY_PAPERDOLL := 0x0193
const ENTRY_CUSTOM := 0x64

# Pokryti §5.2.3: cislo radku tabulky -> pary, ktere ho plni.
# Radek 26 ("pila / dlatо | drevo") ma dve podoby materialu (logs i boards).
# Co tu neni, pokryte NENI - a je to pojmenovane v HANDOFF (otevrena vec 68).
const ROWS := {
	1: [{"od": "iron ore", "na": "forge"}],
	2: [{"od": "iron ore", "na": "iron ore"}],
	6: [{"od": "cloth", "na": "butcher knife"}],
	14: [{"od": "scribe pen", "na": "scroll"}],
	22: [{"od": "butcher knife", "na": "logs"}],
	24: [{"od": "smith hammer", "na": "anvil"}],
	25: [{"od": "sewing kit", "na": "cloth"}],
	26: [{"od": "saw", "na": "logs"}, {"od": "saw", "na": "boards"}],
	27: [{"od": "tinker tools", "na": "iron ingot"}],
	29: [{"od": "shovel", "na": "tile"}],
}
const ROWS_TOTAL := 36              # radku tabulky §5.2.3 (docs/05)
const RADKU_POKRYTYCH := 10
# Pary z §5.2.2 ("uzel suroviny -> spust sber"), ktere v §5.2.3 nejsou.
const EXTRA_PAIRS := [
	{"od": "pickaxe", "na": "tile"},
	{"od": "hatchet", "na": "tile"},
	{"od": "axe", "na": "tile"},
	{"od": "fishing pole", "na": "tile"},
]


class StubWorld extends RefCounted:
	# Nahrazuje `SimWorld` - `sim.interaction` z nej cte jen `systems`.
	var systems: Dictionary = {}


class StubItems extends RefCounted:
	# Nahrazuje "nekdo drzi predmety podle serialu" (vec 64: dnes nikdo).
	var predmety: Dictionary = {}

	func get_item(serial: int):
		return predmety.get(serial)


class StubSystem extends RefCounted:
	# System, ktery si pamatuje volani - tim se dokazuje dynamicky routing.
	var volani: Array = []

	func smelt(m, ore, forge) -> Dictionary:
		return _z("smelt", [m, ore, forge])

	func recipes_for(m, skill) -> Array:
		volani.append({"method": "recipes_for", "args": [m, skill]})
		return []

	func mine(m, x, y) -> Dictionary:
		return _z("mine", [m, x, y])

	func chop(m, x, y) -> Dictionary:
		return _z("chop", [m, x, y])

	func fish(m, x, y) -> Dictionary:
		return _z("fish", [m, x, y])

	func cast(m, spell) -> Dictionary:
		return _z("cast", [m, spell])

	func attack(m, target) -> Dictionary:
		return _z("attack", [m, target])

	func equip(m, item) -> Dictionary:
		return _z("equip", [m, item])

	func stock(v) -> Array:
		volani.append({"method": "stock", "args": [v]})
		return []

	func _z(method: String, args: Array) -> Dictionary:
		volani.append({"method": method, "args": args})
		return {"ok": true, "reason": ""}


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _role_tiles() -> Dictionary:
	var out: Dictionary = {}
	var parsed = Lib.json_at(ITEMS_PATH)
	if not (parsed is Array):
		return out
	for rec in parsed:
		if rec is Dictionary and str(rec.get("role", "")) != "":
			out[str(rec["role"])] = int(rec["tile"])
	return out


func _tile_of_category(cat: String) -> int:
	var parsed = Lib.json_at(ITEMS_PATH)
	if not (parsed is Array):
		return 0
	for rec in parsed:
		if rec is Dictionary and str(rec.get("category", "")) == cat and int(rec["tile"]) < ART:
			return int(rec["tile"])
	return 0


func _ma(events, name: String) -> Dictionary:
	for u in events.drain():
		if str(u["name"]) == name:
			return u["data"]
	return {}


func _najdi(udalosti: Array, name: String) -> Dictionary:
	for u in udalosti:
		if str(u["name"]) == name:
			return u["data"]
	return {}


func _radky_5_2_3(text: String) -> int:
	# Radky tabulky §5.2.3 (bez hlavicky a oddelovace).
	var radky: int = 0
	var v_sekci: bool = false
	for line in text.split("\n"):
		var l: String = line.strip_edges()
		if l.begins_with("### 5.2.3"):
			v_sekci = true
			continue
		if v_sekci and l.begins_with("## "):
			break
		if v_sekci and l.begins_with("|") and not l.contains("Pou") and not l.contains("---"):
			radky += 1
	return radky


func _je_par(pairs: Array, od: String, na: String) -> bool:
	for par in pairs:
		if par is Dictionary and str(par.get("od", "")) == od and str(par.get("na", "")) == na:
			return true
	return false


func run(t) -> void:
	var cesta: String = _arg("interaction-script", INTERACTION_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.interaction NENI HOTOVA: " + cesta + " chybi (nebo nejde nacist)")
		return
	var item_script = Lib.script_at(ITEM_SCRIPT)
	var container_script = Lib.script_at(CONTAINER_SCRIPT)
	var registry_script = Lib.script_at(REGISTRY_SCRIPT)
	var doors_script = Lib.script_at(DOORS_SCRIPT)
	var mobile_script = Lib.script_at(MOBILE_SCRIPT)
	var events_script = Lib.script_at(EVENTS_SCRIPT)
	var chybi: bool = (item_script == null or container_script == null
		or registry_script == null or doors_script == null
		or mobile_script == null or events_script == null)
	if chybi:
		t._pending("sim.interaction NEMEREN: zavislosti (item/container/registry/doors/mobile/events) nejdou nacist")
		return
	if not FileAccess.file_exists(ITEMS_PATH) or not FileAccess.file_exists(SKILLS_PATH):
		t._pending("sim.interaction NEMEREN: chybi %s nebo %s" % [ITEMS_PATH, SKILLS_PATH])
		return

	var consts: Dictionary = script.get_script_constant_map()
	var use_routes: Array = consts.get("USE_ROUTES", [])
	var pairs: Array = consts.get("PAIRS", [])
	var role_tiles: Dictionary = _role_tiles()

	var world := StubWorld.new()
	var events = events_script.new()
	var doors = doors_script.new()
	var containers = container_script.new()
	var registry = registry_script.new()
	var items := StubItems.new()
	var modul = script.new(world, events, doors, containers, registry, items)

	# A) TABULKY: §5.2.2 ma 9 vetvi (a konci "unknown"), §5.2.3 tabulka neni prazdna
	var druhy: Array = []
	for route in use_routes:
		druhy.append(str(route.get("kdo", "")))
	t._check(druhy == ["door", "container", "vendor", "tool", "scroll", "equipment",
		"light", "mobile", "unknown"],
		"sim.interaction: USE_ROUTES je poradi §5.2.2, konci `unknown` (vyslo %s)" % str(druhy))
	t._check(pairs.size() > 0 and modul.has_data(),
		"sim.interaction: data/items.json + data/skills.json se nacetla (paru %d)" % pairs.size())
	for route in use_routes:
		t._check(route.has("akce") and str(route["akce"]) != "",
			"sim.interaction: vetev '%s' ma akci" % str(route.get("kdo", "?")))

	# B) NEZNAMY SERIAL: hlaska, nikdy ticho
	var kind_neznamy: Dictionary = modul.describe(999)
	t._check(str(kind_neznamy.get("kind", "")) == "unknown",
		"sim.interaction: neznamy serial 999 je `unknown` (vyslo '%s')" % str(kind_neznamy.get("kind", "")))
	events.clear()
	var nic: Dictionary = modul.use(HRAC, 999)
	var hlaska: Dictionary = _ma(events, "message")
	t._check(not nic.get("ok", true) and str(nic.get("reason", "")) == "unknown",
		"sim.interaction: use(999) vraci {ok:false, reason:'unknown'} (vyslo %s)" % str(nic))
	t._check(str(hlaska.get("text", "")) == "You see nothing special.",
		"sim.interaction: use(999) REKNE hlasku, nezmlkne (vyslo '%s')" % str(hlaska.get("text", "")))

	# C) KOVADLINA (prijimaci kriterium): v datech `tool`, ale je to CIL
	if role_tiles.has("anvil"):
		var anvil_tile: int = int(role_tiles["anvil"]) + ART
		items.predmety = {501: item_script.new(501, anvil_tile, 1)}
		t._check(modul.role_of(anvil_tile) == "anvil" and modul.category_of(anvil_tile) == "tool",
			"sim.interaction: kovadlina ma v datech roli 'anvil' a kategorii 'tool' (role '%s', kat '%s')"
			% [modul.role_of(anvil_tile), modul.category_of(anvil_tile)])
		t._check(str(modul.describe(501).get("kind", "")) == "unknown",
			"sim.interaction: kovadlina NENI nastroj - `use` na ni nic nedela (kind '%s')"
			% str(modul.describe(501).get("kind", "")))
		events.clear()
		var na_kovadlinu: Dictionary = modul.use(HRAC, 501)
		var h2: Dictionary = _ma(events, "message")
		t._check(not na_kovadlinu.get("ok", true) and str(h2.get("text", "")) == "You see nothing special.",
			"sim.interaction: use na kovadlinu nic neudela A REKNE to (vyslo %s / '%s')"
			% [str(na_kovadlinu), str(h2.get("text", ""))])
	else:
		t._pending("sim.interaction NEMERENO: v data/items.json neni role 'anvil'")

	# D) DVEŘE: `use` projde pres `world.doors.toggle` (konvence z 8. session)
	items.predmety = {502: item_script.new(502, DOOR_TILE, 1)}
	t._check(str(modul.describe(502).get("kind", "")) == "door",
		"sim.interaction: art %d z doors.txt je dvere" % DOOR_TILE)
	events.clear()
	var dvere: Dictionary = modul.use(HRAC, 502)
	var zmena: Dictionary = _ma(events, "item_added")
	t._check(dvere.get("ok", false) and int(dvere.get("tile", 0)) == DOOR_TILE + 1
		and bool(dvere.get("open", false)) and doors.is_open(DOOR_TILE + 1),
		"sim.interaction: use na dvere zavola toggle (%d -> %s)" % [DOOR_TILE, str(dvere)])
	t._check(int(items.predmety[502].tile) == DOOR_TILE + 1 and int(zmena.get("tile", 0)) == DOOR_TILE + 1,
		"sim.interaction: dvere zmenily ART i udalost (art %d, event %d)"
		% [int(items.predmety[502].tile), int(zmena.get("tile", 0))])

	# E) NASTROJ: dvojklik = kurzor cíle (event `target_request`)
	var hammer_tile: int = int(role_tiles.get("smith hammer", 0)) + ART
	items.predmety = {503: item_script.new(503, hammer_tile, 1)}
	t._check(str(modul.describe(503).get("kind", "")) == "tool",
		"sim.interaction: kladivo je nastroj (kind '%s')" % str(modul.describe(503).get("kind", "")))
	events.clear()
	var nastroj: Dictionary = modul.use(HRAC, 503)
	var cilovy: Dictionary = _ma(events, "target_request")
	t._check(nastroj.get("ok", false) and str(nastroj.get("action", "")) == "target"
		and int(cilovy.get("cursor", 0)) > 0 and str(cilovy.get("kind", "")) == "object",
		"sim.interaction: nastroj posle target_request s kursorem (vyslo %s / %s)" % [str(nastroj), str(cilovy)])

	# F) KONTEJNER: `use` otevre gump s obsahem (docs/04 §4.4)
	var kat_kontejner: int = _tile_of_category("container")
	if kat_kontejner > 0:
		var kserial: int = 504
		var vnitrek = item_script.new(77, int(role_tiles.get("iron ore", 0)) + ART, 3)
		containers.add(kserial, vnitrek)
		items.predmety = {kserial: item_script.new(kserial, kat_kontejner + ART, 1)}
		t._check(str(modul.describe(kserial).get("kind", "")) == "container",
			"sim.interaction: predmet kategorie 'container' je kontejner")
		events.clear()
		var otevreny: Dictionary = modul.use(HRAC, kserial)
		var udalosti: Array = events.drain()
		var obsah: Dictionary = _najdi(udalosti, "container_contents")
		var gump: Dictionary = _najdi(udalosti, "gump_open")
		var ma_serialy: bool = false
		if obsah.get("items") is Array:
			var seznam: Array = obsah["items"]
			ma_serialy = seznam.size() == 1 and int(seznam[0]) == 77
		t._check(otevreny.get("ok", false) and str(otevreny.get("action", "")) == "open_container"
			and ma_serialy and str(gump.get("gump", "")) == "container",
			"sim.interaction: use na kontejner posle obsah i gump (vyslo %s / %s)" % [str(otevreny), str(obsah)])
	else:
		t._pending("sim.interaction NEMERENO: v datech neni kategorie 'container'")

	# G) VYBAVA: zbran/zbroj nasadi - system `entity.equipment` dnes neni
	var kat_zbran: int = _tile_of_category("weapon")
	if kat_zbran > 0:
		items.predmety = {505: item_script.new(505, kat_zbran + ART, 1)}
		t._check(str(modul.describe(505).get("kind", "")) == "equipment",
			"sim.interaction: predmet kategorie 'weapon' je vybava (kind '%s')"
			% str(modul.describe(505).get("kind", "")))
		events.clear()
		var nasazeni: Dictionary = modul.use(HRAC, 505)
		var h3: Dictionary = _ma(events, "message")
		t._check(not nasazeni.get("ok", true) and str(nasazeni.get("reason", "")) == "not_available"
			and str(h3.get("text", "")) != "",
			"sim.interaction: bez `entity.equipment` je nasazeni `not_available` (vyslo %s)" % str(nasazeni))
	else:
		t._pending("sim.interaction NEMERENO: v datech neni kategorie 'weapon'")

	# H) MOBIL a VENDOR: routing podle AI stavu (docs/05 §5.3)
	var mob = mobile_script.new(NPC, 400, Vector3i(1495, 1630, 0))
	registry.register(mob)
	t._check(str(modul.describe(NPC).get("kind", "")) == "mobile",
		"sim.interaction: mobil s ai.state 'idle' je `mobile`")
	mob.ai["state"] = "vendor"
	t._check(str(modul.describe(NPC).get("kind", "")) == "vendor",
		"sim.interaction: mobil s ai.state 'vendor' je `vendor`")
	var na_mobila: Dictionary = modul.use(HRAC, NPC)
	t._check(not na_mobila.get("ok", true) and str(na_mobila.get("reason", "")) == "not_available",
		"sim.interaction: bez `sim.vendor` je obchod `not_available` (vyslo %s)" % str(na_mobila))

	# I) PAROVA TABULKA: kazdy par je z realnych dat, bez systemu `not_available`,
	#    s pritomnym stubem se zavola spravna metoda se spravnymi argumenty
	var paru_mereno: int = 0
	var i: int = 0
	for par in pairs:
		i += 1
		var od: String = str(par.get("od", ""))
		var na: String = str(par.get("na", ""))
		t._check(role_tiles.has(od),
			"sim.interaction: role '%s' (zdroj paru) je v data/items.json" % od)
		if not role_tiles.has(od):
			continue
		var src_serial: int = 900 + i
		var src = item_script.new(src_serial, int(role_tiles[od]) + ART, 1)
		var target: Dictionary = {}
		var dst_serial: int = 0
		if na == "tile":
			target = {"kind": "tile", "x": 1495, "y": 1630, "z": 0}
		else:
			t._check(role_tiles.has(na),
				"sim.interaction: role '%s' (cil paru) je v data/items.json" % na)
			if not role_tiles.has(na):
				continue
			dst_serial = 950 + i
			items.predmety = {src_serial: src,
				dst_serial: item_script.new(dst_serial, int(role_tiles[na]) + ART, 1)}
			target = {"kind": "item", "serial": dst_serial}
		if na == "tile":
			items.predmety = {src_serial: src}
		world.systems.clear()
		var bez_systemu: Dictionary = modul.use_on(HRAC, src_serial, target)
		if str(par.get("akce", "")) == "merge_piles":
			continue
		t._check(not bez_systemu.get("ok", true) and str(bez_systemu.get("reason", "")) == "not_available",
			"sim.interaction: par %s -> %s bez systemu vraci not_available (vyslo %s)"
			% [od, na, str(bez_systemu)])
		var stub := StubSystem.new()
		world.systems[str(par["system"])] = stub
		var se_systemem: Dictionary = modul.use_on(HRAC, src_serial, target)
		paru_mereno += 1
		t._check(se_systemem.get("ok", false) and stub.volani.size() == 1,
			"sim.interaction: par %s -> %s zavola system (%s, volani %d)"
			% [od, na, str(se_systemem), stub.volani.size()])
		if stub.volani.size() != 1:
			continue
		var v: Dictionary = stub.volani[0]
		t._check(str(v["method"]) == str(par["method"]),
			"sim.interaction: par %s -> %s vola '%s' (vyslo '%s')"
			% [od, na, str(par["method"]), str(v["method"])])
		match str(par.get("akce", "")):
			"smelt":
				var args: Array = v["args"]
				t._check(args.size() == 3 and int(args[0]) == HRAC and int(args[1]) == src_serial
					and int(args[2]) == dst_serial,
					"sim.interaction: smelt dostane (kdo, ruda, vyhen) (vyslo %s)" % str(args))
			"craft_gump":
				var args2: Array = v["args"]
				t._check(args2.size() == 2 and int(args2[1]) == modul.skill_id(str(par.get("skill", ""))),
					"sim.interaction: craft gump dostane id skillu z data/skills.json (%s, vyslo %s)"
					% [str(par.get("skill", "")), str(args2)])
			"harvest":
				var args3: Array = v["args"]
				t._check(args3 == [HRAC, 1495, 1630],
					"sim.interaction: sber dostane (kdo, x, y) (vyslo %s)" % str(args3))
	t._check(paru_mereno == pairs.size() - 1,
		"sim.interaction: vsechny pary krome slouceni prosly stubem (%d z %d)"
		% [paru_mereno, pairs.size() - 1])

	# J) SLOUCENI HROMAD (par "ore -> ore", docs/05 §5.2.3)
	var zdroj = item_script.new(960, int(role_tiles.get("iron ore", 0)) + ART, 10)
	var cil_hromada = item_script.new(961, int(role_tiles.get("iron ore", 0)) + ART, MAX_STACK - 5)
	items.predmety = {960: zdroj, 961: cil_hromada}
	var slouceno: Dictionary = modul.use_on(HRAC, 960, {"kind": "item", "serial": 961})
	t._check(slouceno.get("ok", false) and int(slouceno.get("moved", 0)) == 5
		and int(cil_hromada.amount) == MAX_STACK and int(zdroj.amount) == 5,
		"sim.interaction: slouceni se zastavi na MAX_STACK (vyslo %s, cil %d, zdroj %d)"
		% [str(slouceno), int(cil_hromada.amount), int(zdroj.amount)])
	var ruda_jina_barva = item_script.new(963, int(role_tiles.get("iron ore", 0)) + ART, 5)
	ruda_jina_barva.hue = 1002
	items.predmety = {961: cil_hromada, 963: ruda_jina_barva}
	var jina_hromada: Dictionary = modul.use_on(HRAC, 963, {"kind": "item", "serial": 961})
	t._check(not jina_hromada.get("ok", true) and str(jina_hromada.get("reason", "")) == "no_pair",
		"sim.interaction: ruzna barva se neslucuje (vyslo %s)" % str(jina_hromada))

	# K) NEZNAMA KOMBINACE: hlaska, nikdy ticho
	var kladivo = item_script.new(970, hammer_tile, 1)
	var zlato = item_script.new(971, int(role_tiles.get("gold coin", 0)) + ART, 100)
	items.predmety = {970: kladivo, 971: zlato}
	events.clear()
	var nema_par: Dictionary = modul.use_on(HRAC, 970, {"kind": "item", "serial": 971})
	var h4: Dictionary = _ma(events, "message")
	t._check(not nema_par.get("ok", true) and str(nema_par.get("reason", "")) == "no_pair"
		and str(h4.get("text", "")) == "You see nothing special.",
		"sim.interaction: nezname kombinaci REKNE hlaskou (`no_pair`, vyslo %s)" % str(nema_par))

	# L) KONTEKSTOVE MENU: cisla, ktera klient zna, + vlastni >= 0x64
	var menu_self: Array = modul.context_menu(HRAC, 0)
	var cisla: Array = []
	for e in menu_self:
		cisla.append(int(e.get("entry", 0)))
	t._check(cisla == [ENTRY_BACKPACK, ENTRY_PAPERDOLL, ENTRY_CUSTOM, ENTRY_CUSTOM + 1],
		"sim.interaction: menu sebe ma 0x0078 a 0x0193 (vyslo %s)" % str(cisla))
	t._check(menu_self.size() == 4 and not bool(menu_self[0].get("custom", true))
		and bool(menu_self[2].get("custom", false)),
		"sim.interaction: prvni dve polozky jsou cisla klienta, zbytek `custom`")
	# cil bez dat = prazdne menu + hlaska (nikdy ticho)
	events.clear()
	var menu_neznamy: Array = modul.context_menu(HRAC, 8888)
	var h5: Dictionary = _ma(events, "message")
	t._check(menu_neznamy.is_empty() and str(h5.get("text", "")) == "You see nothing special.",
		"sim.interaction: menu neznameho cile je prazdne a REKNE to (vyslo %d polozek)" % menu_neznamy.size())

	# M) KONTEKSTOVA AKCE: batoh hrace, paperdoll, vlastni cislo, nezname cislo
	var hrac = mobile_script.new(HRAC, 400, Vector3i(1495, 1630, 0))
	registry.register(hrac)
	events.clear()
	var bez_batohu: Dictionary = modul.context_action(HRAC, 0, ENTRY_BACKPACK)
	t._check(not bez_batohu.get("ok", true) and str(bez_batohu.get("reason", "")) == "not_available",
		"sim.interaction: batoh bez `backpack` je `not_available` (vyslo %s)" % str(bez_batohu))
	hrac.backpack = 606
	events.clear()
	var batoh: Dictionary = modul.context_action(HRAC, 0, ENTRY_BACKPACK)
	var gump_batoh: Dictionary = _ma(events, "gump_open")
	t._check(batoh.get("ok", false) and str(batoh.get("action", "")) == "open_backpack"
		and int(gump_batoh.get("data", {}).get("serial", 0)) == 606,
		"sim.interaction: 0x0078 otevre batoh (vyslo %s / %s)" % [str(batoh), str(gump_batoh)])
	events.clear()
	var pd: Dictionary = modul.context_action(HRAC, 0, ENTRY_PAPERDOLL)
	var gump_pd: Dictionary = _ma(events, "gump_open")
	t._check(pd.get("ok", false) and str(gump_pd.get("gump", "")) == "paperdoll",
		"sim.interaction: 0x0193 posle paperdoll (vyslo %s)" % str(gump_pd))
	var vlastni: Dictionary = modul.context_action(HRAC, 0, ENTRY_CUSTOM)
	t._check(not vlastni.get("ok", true) and str(vlastni.get("reason", "")) == "not_available",
		"sim.interaction: vlastni cislo >= 0x64 je zatial `not_available` (vyslo %s)" % str(vlastni))
	var neznamy: Dictionary = modul.context_action(HRAC, 0, 5)
	t._check(not neznamy.get("ok", true) and str(neznamy.get("reason", "")) == "unknown_entry",
		"sim.interaction: nezname cislo je `unknown_entry` (vyslo %s)" % str(neznamy))

	# N) POKRYTI §5.2.3 PROTI DOKUMENTU
	var dok: String = ""
	if FileAccess.file_exists(DOCS05_PATH):
		dok = FileAccess.get_file_as_string(DOCS05_PATH)
	t._check(dok != "", "sim.interaction: docs/05 jde precist (pokryti tabulky se meri)")
	if dok == "":
		t._pending("sim.interaction NEMERENO: chybi " + DOCS05_PATH)
		return
	var radku: int = _radky_5_2_3(dok)
	t._check(radku == ROWS_TOTAL,
		"sim.interaction: §5.2.3 ma %d radku (test zna %d) - pri zmene dokumentu dopln pokryti"
		% [radku, ROWS_TOTAL])
	t._check(ROWS.size() == RADKU_POKRYTYCH,
		"sim.interaction: pokrytych radku je %d (test zna %d)" % [ROWS.size(), RADKU_POKRYTYCH])
	var z_dokumentu: Array = []
	for radek in ROWS.keys():
		t._check(int(radek) >= 1 and int(radek) <= ROWS_TOTAL,
			"sim.interaction: radek %s je v rozsahu tabulky" % str(radek))
		for par in ROWS[radek]:
			z_dokumentu.append(par)
			t._check(_je_par(pairs, str(par["od"]), str(par["na"])),
				"sim.interaction: radek %s ma v kódu par %s -> %s" % [str(radek), str(par["od"]), str(par["na"])])
	for par in EXTRA_PAIRS:
		t._check(_je_par(pairs, str(par["od"]), str(par["na"])),
			"sim.interaction: par z §5.2.2 %s -> %s je v kódu" % [str(par["od"]), str(par["na"])])
	t._check(z_dokumentu.size() + EXTRA_PAIRS.size() == pairs.size(),
		"sim.interaction: paru v kódu je presne tolik jako v dokumentu + §5.2.2 (%d + %d vs %d)"
		% [z_dokumentu.size(), EXTRA_PAIRS.size(), pairs.size()])
	for par in pairs:
		var v_dok: bool = _je_par(z_dokumentu, str(par.get("od", "")), str(par.get("na", "")))
		var v_extra: bool = _je_par(EXTRA_PAIRS, str(par.get("od", "")), str(par.get("na", "")))
		t._check(v_dok or v_extra,
			"sim.interaction: par %s -> %s je dohledatelny v docs/05 §5.2.3 nebo v §5.2.2"
			% [str(par.get("od", "")), str(par.get("na", ""))])
