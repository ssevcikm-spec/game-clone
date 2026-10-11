extends RefCounted
# sim.decay - rozpad predmetu na zemi a tela (docs/05 §5.4: predmet 60 min,
# telo 7 min, pravo na loot 2 min).
#
# Test meri CASY a SKUTECNE ODSTRANENI, ne pritomnost metod (docs/09 §9.5):
#   * predmet na zemi (`parent == 0`) zmizi po **60 min** a pred tim zustava,
#   * telo (`type == "corpse"`, jinak `props["corpse"] == true`) zmizi po
#     **7 min** I S OBSAHEM (obsah se maze z kontejneru i z evidence predmetu),
#   * predmet v kontejneru se nerozpadá (registrace se odmitne),
#   * `state()`/`restore()` round-trip sedi (fronta i pocitadlo).
#
# Cesta k souboru je VSTUP: `-- --decay-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const HashScript = preload("res://core/hash.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const ContainerScript = preload("res://sim/entity/container.gd")

const DECAY_SCRIPT := "res://sim/systems/decay.gd"
const GROUND_MS := 3600000              # 60 min
const CORPSE_MS := 420000               # 7 min
const LOOT_MS := 120000                 # 2 min

const TELO := 0x6001
const ZEME := 0x6002
const PROPS := 0x6003
const LOOT := 0x6010
const V_KONTEJNERU := 0x6020


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _predmet(serial: int, typ: String, parent: int, items: Dictionary):
	var it = ItemScript.new(serial, 0x0EED, 1)
	it.type = typ
	it.parent = parent
	it.pos = Vector3i(10, 10, 0)
	items[serial] = it
	return it


func _udalosti(events) -> Array:
	var out: Array = []
	for e in events.drain():
		out.append(e)
	return out


func run(t) -> void:
	var cesta: String = _arg("decay-script", DECAY_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.decay NENI HOTOVY: " + cesta + " chybi nebo se neparsuje")
		return

	var clock = ClockScript.new()
	var events = EventsScript.new()
	var container = ContainerScript.new()
	var items: Dictionary = {}
	var decay = script.new(clock, events, container, items)

	# -- A) CASY Z docs/05 §5.4 -------------------------------------------
	t._check(decay.ground_ms() == GROUND_MS,
		"predmet na zemi 60 min (%d ms, je %d)" % [GROUND_MS, decay.ground_ms()])
	t._check(decay.corpse_ms() == CORPSE_MS,
		"telo 7 min (%d ms, je %d)" % [CORPSE_MS, decay.corpse_ms()])
	t._check(decay.loot_ms() == LOOT_MS,
		"pravo na loot 2 min (%d ms, je %d)" % [LOOT_MS, decay.loot_ms()])

	# -- B) IDENTITA TELA: `type`, jinak `props["corpse"]` -----------------
	var telo = _predmet(TELO, "corpse", 0, items)
	var zemni = _predmet(ZEME, "gold_coin", 0, items)
	var props = _predmet(PROPS, "", 0, items)
	props.props = {"corpse": true}
	t._check(decay.is_corpse_entity(telo), "type == 'corpse' je telo")
	t._check(not decay.is_corpse_entity(zemni), "gold_coin neni telo")
	t._check(decay.is_corpse_entity(props),
		"props['corpse'] == true je telo (zaloha, kdyz `type` chybi)")

	t._check(decay.register(telo), "register(telo) probehl")
	t._check(decay.register(zemni), "register(predmet na zemi) probehl")
	t._check(decay.register(props), "register(props-telo) probehl")
	t._check(decay.due_of(TELO) == CORPSE_MS,
		"telo ma due 7 min (%d, je %d)" % [CORPSE_MS, decay.due_of(TELO)])
	t._check(decay.due_of(ZEME) == GROUND_MS,
		"predmet ma due 60 min (%d, je %d)" % [GROUND_MS, decay.due_of(ZEME)])
	t._check(decay.due_of(PROPS) == CORPSE_MS, "props-telo ma due 7 min")

	# -- C) PREDMET V KONTEJNERU SE NEROZPADA ------------------------------
	var vnitrni = _predmet(V_KONTEJNERU, "gold_coin", 0x00000099, items)
	t._check(not decay.register(vnitrni),
		"predmet v kontejneru se nezaregistruje (parent != 0)")
	t._check(decay.due_of(V_KONTEJNERU) == 0, "a neni ve fronte")

	# -- D) TELO SE ROZPADNE PO 7 MIN I S OBSAHEM --------------------------
	var loot = ItemScript.new(LOOT, 0x0EED, 5)
	loot.parent = TELO
	items[LOOT] = loot
	container.add(TELO, loot)
	t._check(container.contents(TELO).size() == 1, "telo ma 1 predmet obsahu")

	clock.advance(CORPSE_MS - 1)
	decay.tick(0)
	t._check(items.has(TELO), "1 ms pred 7 min je telo jeste na svete")
	t._check(decay.removed_count() == 0, "a nic se neodstranilo")

	clock.advance(1)
	decay.tick(0)
	t._check(not items.has(TELO), "po 7 min telo zmizelo z evidence predmetu")
	t._check(container.contents(TELO).is_empty(), "obsah tela zmizel z kontejneru")
	t._check(not items.has(LOOT), "obsah tela zmizel i z evidence predmetu")
	t._check(not items.has(PROPS), "props-telo se rozpadlo ve stejny cas (due 7 min)")
	# PROPS mel stejne `due_ms` (oba registrovany v case 0 jako telo), takze se
	# ve stejnem tiku rozpadl taky - pocitadlo je proto 2, ne 1.
	t._check(decay.removed_count() == 2,
		"odstranena 2 tela (telo + props-telo) (je %d)" % decay.removed_count())
	t._check(decay.due_of(TELO) == 0, "telo uz neni ve fronte")
	var ud = _udalosti(events)
	var nasel := false
	for e in ud:
		if str(e["name"]) == "item_removed" and int(e["data"].get("serial", 0)) == TELO:
			nasel = true
	t._check(nasel, "telo poslalo udalost item_removed")

	# -- E) PREDMET NA ZEMI SE ROZPADNE PO 60 MIN --------------------------
	var zbyva: int = decay.due_of(ZEME) - clock.now_ms()
	t._check(zbyva == GROUND_MS - CORPSE_MS,
		"predmetu zbyva do rozpadu %d ms (je %d)" % [GROUND_MS - CORPSE_MS, zbyva])
	clock.advance(zbyva - 1)
	decay.tick(0)
	t._check(items.has(ZEME), "1 ms pred 60 min je predmet jeste na svete")
	clock.advance(1)
	decay.tick(0)
	t._check(not items.has(ZEME), "po 60 min predmet zmizel z evidence predmetu")
	t._check(decay.removed_count() == 3,
		"odstranene = 3 (telo + props-telo + predmet), je %d" % decay.removed_count())

	# -- F) STATE/RESTORE ROUND-TRIP ---------------------------------------
	var novy = _predmet(0x6030, "gold_coin", 0, items)
	decay.register(novy)
	var st1: Dictionary = decay.state()
	var decay2 = script.new(clock, EventsScript.new(), container, items)
	decay2.restore(st1)
	var st2: Dictionary = decay2.state()
	var h := HashScript.new()
	t._check(h.of_state([st1]) == h.of_state([st2]),
		"state()/restore() round-trip sedi (fronta i pocitadlo)")
	t._check(decay2.pending() == decay.pending(),
		"po restore je stejne polozek fronty (%d vs %d)" % [decay2.pending(), decay.pending()])
	t._check(decay2.removed_count() == decay.removed_count(),
		"po restore je stejne pocitadlo (%d vs %d)"
			% [decay2.removed_count(), decay.removed_count()])
	t._check(decay2.due_of(0x6030) == decay.due_of(0x6030), "po restore sedi due_ms")
