extends RefCounted
# sim.loot - loot z tela (docs/04 §4.2 a tok §4.6.7, docs/05 §5.4 a §5.16).
#
# Test meri PRESNE hodnoty tabulky `LootPack.Old*` (`_src/servuo/Scripts/Misc/
# LootPack.cs:420-493`), ne pritomnost metod:
#   * `loot_pack: "poor"` -> zlato **1 az 25** (`OldPoor` = `Gold 1d25`) a
#     NIKDY magicky predmet (`roll_magic_item` vraci `{}`, rozhodnuti D4),
#   * `meager` 25+5d10 (30..75), `rich` 250+10d10 (260..350),
#     `ultraRich` 500+5d100 (505..1000) - vsechno cteno z téhož souboru, kde
#     jsou data, ale ocekavane meze jsou v testu ZAPSANE (ne pocitane z tabulky),
#   * `roll_magic_item(level)` vraci PRAZDNY slovnik pro vsechny urovne (D4),
#   * zlato je PREDMET `gold_coin` s artem z `data/vendors.json: config.gold_art`
#     (namEReno 2026-10-10: 20205 = 0x4EED),
#   * neznamy `loot_pack` -> `{ok:false}`, nikdy ticha nahrada "poor".
#
# Fixture zbrani/monster je v gitu (`tests/fixtures/m5/`), proto test meri
# i v CI (docs/04 §4.8.2). Cesta k souboru je VSTUP:
# `-- --loot-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const ContainerScript = preload("res://sim/entity/container.gd")

const LOOT_SCRIPT := "res://sim/systems/loot.gd"
const ITEMS_FIXTURE := "res://tests/fixtures/m5/items.json"
const VENDORS_PATH := "res://data/vendors.json"
const CORPSE_SERIAL := 0x40000077
const GOLD_ART_EXPECTED := 20205       # `config.gold_art` v data/vendors.json

# Meze zlata z tabulky `LootPack.Old*` (viz hlavicka) - ZAPSANE, ne pocitane.
const GOLD_RANGE := {
	"poor": [1, 25],
	"meager": [30, 75],
	"average": [60, 150],
	"rich": [260, 350],
	"filthyRich": [402, 650],
	"ultraRich": [505, 1000],
	"superBoss": [505, 1000],
}


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class StubSerials:
	var hodnota: int = 1000

	func next_serial() -> int:
		hodnota += 1
		return hodnota


func _telo(container):
	# Telo = `entity.item` na zemi (kontrakt M5 §2); zde staci serial, protoze
	# `fill_corpse` ho bere jako cislo kontejneru.
	var telo = ItemScript.new(CORPSE_SERIAL, 0x2006, 1)
	telo.type = "corpse"
	telo.parent = 0
	telo.pos = Vector3i(1495, 1630, 0)
	return telo


func _obsah(container, telo) -> Array:
	var out: Array = []
	for s in container.contents(int(telo.serial)):
		out.append(s)
	return out


func run(t) -> void:
	var cesta: String = _arg("loot-script", LOOT_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.loot NENI HOTOVY: " + cesta + " chybi nebo se neparsuje")
		return

	# -- A) POOR: 1 az 25 zlata, nikdy magicky predmet --------------------
	var container = ContainerScript.new()
	var items: Dictionary = {}
	var events = EventsScript.new()
	var loot = script.new(container, items, RngScript.new(42), events,
		StubSerials.new(), ITEMS_FIXTURE, VENDORS_PATH)
	t._check(loot.gold_art() == GOLD_ART_EXPECTED,
		"gold_art z data/vendors.json je %d (je %d, source=%s)"
		% [GOLD_ART_EXPECTED, loot.gold_art(), loot.gold_art_source()])
	t._check(loot.pack_of({"loot_pack": "poor"}) == "poor", "pack_of(poor) == poor")
	t._check(loot.pack_of({"loot_pack": "OldPoor"}) == "poor", "alias OldPoor -> poor")
	t._check(loot.pack_of({}) == "poor", "chybejici loot_pack = poor (vetsina monster)")

	var telo = _telo(container)
	var r: Dictionary = loot.fill_corpse({"loot_pack": "poor"}, telo)
	t._check(bool(r.get("ok", false)),
		"fill_corpse(poor) vraci ok (reason=%s)" % str(r.get("reason", "")))
	t._check(str(r.get("pack", "")) == "poor", "fill_corpse hlasi pack=poor")
	t._check(int(r.get("gold", 0)) >= 1 and int(r.get("gold", 0)) <= 25,
		"poor zlato je 1..25 (je %d)" % int(r.get("gold", 0)))
	t._check(int(r.get("gold", 0)) != 0, "poor VZDY da zlato (sance 100 %)")
	var obsah: Array = _obsah(container, telo)
	t._check(obsah.size() >= 1, "v tele je alespon zlato (%d predmetu)" % obsah.size())
	var zlato = items.get(int(r.get("gold_serial", 0)))
	t._check(zlato != null, "zlato je registrovane v `items` (serial %d)" % int(r.get("gold_serial", 0)))
	if zlato != null:
		t._check(str(zlato.type) == "gold_coin", "zlato ma typ gold_coin (je '%s')" % str(zlato.type))
		t._check(int(zlato.tile) == GOLD_ART_EXPECTED,
			"zlato ma art z config.gold_art (%d)" % int(zlato.tile))
		t._check(int(zlato.amount) == int(r.get("gold", 0)),
			"mnozstvi zlata v predmetu == hlasene zlato")
	t._check((r.get("magic", []) as Array).is_empty(),
		"poor nema zadny magic zaznam (%d)" % (r.get("magic", []) as Array).size())

	# -- B) ROLL_MAGIC_ITEM: vzdy prazdny (D4) ----------------------------
	for level in [0, 1, 5, 10, 40, 100]:
		var mag: Dictionary = loot.roll_magic_item(int(level))
		t._check(mag.is_empty(), "roll_magic_item(%d) vraci {} (D4)" % int(level))

	# -- C) 30x POOR: meze 1..25 a zadny magicky predmet -----------------
	var min_zlata: int = 99999
	var max_zlata: int = -1
	var magic_count: int = 0
	for i in 30:
		var telo_i = _telo(container)
		var ri: Dictionary = loot.fill_corpse({"loot_pack": "poor"}, telo_i)
		var g: int = int(ri.get("gold", 0))
		min_zlata = mini(min_zlata, g)
		max_zlata = maxi(max_zlata, g)
		if not (ri.get("magic", []) as Array).is_empty():
			magic_count += 1
		t._check(g >= 1 and g <= 25, "poor zlato v mezich 1..25 (pokus %d: %d)" % [i, g])
	t._check(min_zlata >= 1 and max_zlata <= 25,
		"30x poor: zlato v rozsahu 1..25 (min %d, max %d)" % [min_zlata, max_zlata])
	t._check(magic_count == 0,
		"30x poor: zadny magic zaznam (%d) - D4" % magic_count)
	t._check(max_zlata > min_zlata,
		"30x poor: zlato se MENI (nahoda funguje; min %d, max %d)" % [min_zlata, max_zlata])

	# -- D) OSTATNI PACKY: meze z tabulky --------------------------------
	for pack in GOLD_RANGE.keys():
		var c2 = ContainerScript.new()
		var it2: Dictionary = {}
		var l2 = script.new(c2, it2, RngScript.new(7), EventsScript.new(),
			StubSerials.new(), ITEMS_FIXTURE, VENDORS_PATH)
		var t2 = _telo(c2)
		var r2: Dictionary = l2.fill_corpse({"loot_pack": str(pack)}, t2)
		var meze: Array = GOLD_RANGE[pack]
		t._check(bool(r2.get("ok", false)), "fill_corpse(%s) vraci ok" % str(pack))
		t._check(str(r2.get("pack", "")) == str(pack),
			"fill_corpse hlasi pack=%s (je %s)" % [str(pack), str(r2.get("pack", ""))])
		var g2: int = int(r2.get("gold", 0))
		t._check(g2 >= int(meze[0]) and g2 <= int(meze[1]),
			"%s zlato v %d..%d (je %d)" % [str(pack), int(meze[0]), int(meze[1]), g2])

	# -- E) NEZNAMY PACK: ok=false, nikdy ticha nahrada -------------------
	var c3 = ContainerScript.new()
	var l3 = script.new(c3, {}, RngScript.new(1), EventsScript.new(),
		StubSerials.new(), ITEMS_FIXTURE, VENDORS_PATH)
	var t3 = _telo(c3)
	var r3: Dictionary = l3.fill_corpse({"loot_pack": "neexistuje"}, t3)
	t._check(not bool(r3.get("ok", false)), "neznamy pack vraci ok=false")
	t._check(str(r3.get("reason", "")) == "unknown_pack",
		"neznamy pack vraci reason=unknown_pack (je '%s')" % str(r3.get("reason", "")))
	t._check(int(r3.get("gold", 0)) == 0, "neznamy pack neda zlato")
	t._check(_obsah(c3, t3).is_empty(), "neznamy pack neda zadny predmet")

	# -- F) BEZ KONTEJNERU: ok=false a duvod ------------------------------
	var l4 = script.new(null, {}, RngScript.new(1), EventsScript.new(),
		StubSerials.new(), ITEMS_FIXTURE, VENDORS_PATH)
	var r4: Dictionary = l4.fill_corpse({"loot_pack": "poor"}, _telo(c3))
	t._check(not bool(r4.get("ok", false)) and str(r4.get("reason", "")) == "no_container",
		"bez kontejneru loot vraci no_container (je '%s')" % str(r4.get("reason", "")))
