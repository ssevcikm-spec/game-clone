extends RefCounted
# sim.death + sim.decay - smrt, telo, duch, vzkriseni, rozpad (docs/04 §4.2,
# §4.6.6 a §4.6.7; docs/05 §5.13 a §5.4).
#
# Test meri PRESNA prijimaci kriteria smlouvy:
#   * po `die` je `is_ghost(hrac) == true` a v tele je INVENTAR
#     (`docs/04 §4.6.6`), vcetne nasazene vybavy,
#   * `blessed`/`newbie` predmety po smrti ZUSTAVAJI (`docs/05 §5.4`),
#   * nehrac se z registru ODEBERE (`registry.remove`) + event `mobile_removed`,
#   * `resurrect` -> **hp == 10** (`docs/05 §5.13`), hrac neni duch a obsah
#     tela se vraci,
#   * telo se rozpadne za **7 min** (i s obsahem) a predmet na zemi za
#     **60 min** (`docs/05 §5.4`) - casy meri `sim.decay`, ne `death`,
#   * pravo na loot **2 min** (`docs/05 §5.4`).
#
# Cesta k souborum je VSTUP: `-- --death-script=<cesta> --decay-script=<cesta>`
# (mutacni test).

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const StatsScript = preload("res://sim/entity/stats.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const ContainerScript = preload("res://sim/entity/container.gd")

const DEATH_SCRIPT := "res://sim/systems/death.gd"
const DECAY_SCRIPT := "res://sim/systems/decay.gd"

const PLAYER := 0x40000001
const NPC := 0x40000002
const BACKPACK := 0x00000099
const CORPSE_DECAY_MS := 7 * 60000
const GROUND_DECAY_MS := 60 * 60000
const LOOT_RIGHTS_MS := 2 * 60000
const FLAG_BLESSED := 0x01
const FLAG_NEWBIE := 0x02


class StubSerials:
	var hodnota: int = 5000

	func next_serial() -> int:
		hodnota += 1
		return hodnota


class StubArtProvider:
	# Predstira `app.main.corpse_art_for`: v UO je art mrtvoly `0x4000 + body`.
	# `-1` znamena "tenhle art v manifestu neni" - a telo se pak kresli
	# konstantou (proto test meri i tuhle vetev).
	var chybejici: bool = false

	func corpse_art_for(body: int) -> int:
		if chybejici:
			return 0
		return 0x4000 + int(body)


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _svet(container, items, clock, events):
	# Vrati [registry, player, npc, backpack_serial].
	var registry = RegistryScript.new()
	var player = MobileScript.new(PLAYER, 400, Vector3i(100, 100, 0))
	player.name = "Player"
	player.backpack = BACKPACK
	player.max_hp = 100
	player.hp = 100
	registry.register(player)
	var npc = MobileScript.new(NPC, 50, Vector3i(101, 100, 0))
	npc.name = "a skeleton"
	npc.backpack = BACKPACK + 1
	npc.hp = 0                              # mrtve monstrum
	registry.register(npc)
	return [registry, player, npc]


func _predmet(items, container, serial: int, typ: String, art: int, flags: int, rodic: int):
	var item = ItemScript.new(serial, art, 1)
	item.type = typ
	item.flags = flags
	if rodic != 0:
		container.add(rodic, item)
	items[serial] = item
	return item


func _jmena(events) -> Array:
	var out: Array = []
	for e in events.drain():
		out.append(str(e["name"]))
	return out


func _texty(events) -> Array:
	var out: Array = []
	for e in events.drain():
		if str(e["name"]) == "message":
			out.append(str(e["data"].get("text", "")))
	return out


func run(t) -> void:
	var cesta_d: String = _arg("death-script", DEATH_SCRIPT)
	var cesta_c: String = _arg("decay-script", DECAY_SCRIPT)
	var s_death = Lib.script_at(cesta_d)
	var s_decay = Lib.script_at(cesta_c)
	if s_death == null:
		t._pending("sim.death NENI HOTOVY: " + cesta_d + " chybi nebo se neparsuje")
		return
	if s_decay == null:
		t._pending("sim.decay NENI HOTOVY: " + cesta_c + " chybi nebo se neparsuje")
		return

	# -- A) SMRT HRACE: telo, duch, inventar ------------------------------
	var container = ContainerScript.new()
	var items: Dictionary = {}
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var decay = s_decay.new(clock, events, container, items)
	var death = s_death.new(RegistryScript.new(), container, items, events,
		StubSerials.new(), decay)
	var casti: Array = _svet(container, items, clock, events)
	var registry = casti[0]
	var player = casti[1]
	var npc = casti[2]
	death._registry = registry                # jedna instance sveta
	death.set_player(PLAYER)

	# Batoh: mec (jde do tela), zlato newbie (zustava), obvaz blessed (zustava).
	_predmet(items, container, 0x600001, "longsword", 0x4000 + 3935, 0, BACKPACK)
	_predmet(items, container, 0x600002, "gold_coin", 20205, FLAG_NEWBIE, BACKPACK)
	_predmet(items, container, 0x600003, "bandage", 0x4000 + 3617, FLAG_BLESSED, BACKPACK)
	# Nasadena zbroj (vrstva 1, rodic = hrac) - musi jit do tela.
	var zbroj = _predmet(items, container, 0x600004, "dagger", 0x4000 + 3921, 0, 0)
	zbroj.layer = 1
	zbroj.parent = PLAYER
	player.equip[1] = 0x600004
	# Nasadene blessed (zustava na hraci).
	var svatek = _predmet(items, container, 0x600005, "robe", 0x4000 + 7939, FLAG_BLESSED, 0)
	svatek.layer = 2
	svatek.parent = PLAYER
	player.equip[2] = 0x600005

	player.hp = 0
	var r: Dictionary = death.die(PLAYER)
	t._check(bool(r.get("ok", false)),
		"die vraci ok (reason=%s)" % str(r.get("reason", "")))
	t._check(bool(r.get("ghost", false)), "die hlasi ghost=true pro hrace")
	t._check(death.is_ghost(PLAYER), "po die je is_ghost(hrac) == true")
	t._check(not death.is_ghost(NPC), "mrtvy NEHRAC neni duch")
	var telo = death.corpse_of(PLAYER)
	t._check(telo != null, "die vytvorilo telo (corpse_of != null)")
	if telo != null:
		t._check(int(telo.tile) > 0, "telo ma art (%d)" % int(telo.tile))
		t._check(int(telo.parent) == 0, "telo je na zemi (parent 0)")
		t._check(int(telo.pos.x) == 100 and int(telo.pos.y) == 100,
			"telo ma pozici zemreleho (%d,%d)" % [int(telo.pos.x), int(telo.pos.y)])
		var obsah: Array = _obsah(container, telo)
		t._check(obsah.has(0x600001), "mec z batohu je v tele")
		t._check(obsah.has(0x600004), "nasadena zbroj je v tele")
		t._check(not obsah.has(0x600002), "newbie zlato v tele NENI (zustava hraci)")
		t._check(not obsah.has(0x600003), "blessed obvaz v tele NENI (zustava hraci)")
		t._check(not obsah.has(0x600005), "blessed saty v tele NEJSOU")
		t._check(int(r.get("items", 0)) == 2,
			"do tela se prenesly 2 predmety (je %d)" % int(r.get("items", 0)))
	t._check(int(player.equip.get(1, 0)) == 0, "nasadena zbroj se uklidila z vrstvy 1")
	t._check(int(player.equip.get(2, 0)) == 0x600005,
		"blessed saty zustavaji na vrstve 2 (jsou %d)" % int(player.equip.get(2, 0)))
	var jmena: Array = _jmena(events)
	t._check(jmena.has("death"), "die posle udalost death (%s)" % str(jmena))

	# -- B) SMRT NEHRACE: zmizi z registru + mobile_removed ---------------
	var r_npc: Dictionary = death.die(NPC)
	t._check(bool(r_npc.get("ok", false)), "die nehrace vraci ok")
	t._check(registry.get_mobile(NPC) == null, "NEHRAC se z registru odstranil")
	var jmena2: Array = _jmena(events)
	t._check(jmena2.has("mobile_removed"), "die nehrace posle mobile_removed (%s)" % str(jmena2))

	# -- C) DRUHA SMRT: zadne druhe telo ----------------------------------
	var r2: Dictionary = death.die(PLAYER)
	t._check(not bool(r2.get("ok", false)), "druha smrt je ok=false")
	t._check(str(r2.get("reason", "")) == "already_dead",
		"druha smrt vraci already_dead (je '%s')" % str(r2.get("reason", "")))
	# Zivy mobil se neda zabit "rucne".
	var zivy = MobileScript.new(0x40000009, 400, Vector3i(1, 1, 0))
	registry.register(zivy)
	var r3: Dictionary = death.die(0x40000009)
	t._check(not bool(r3.get("ok", false)) and str(r3.get("reason", "")) == "alive",
		"die na zivy mobil vraci alive (je '%s')" % str(r3.get("reason", "")))

	# -- D) VZKRISENI: hp == 10, neni duch, obsah se vraci ----------------
	var hp_pred: int = int(player.hp)
	var rr: Dictionary = death.resurrect(PLAYER, 0)
	t._check(bool(rr.get("ok", false)), "resurrect vraci ok")
	t._check(int(player.hp) == 10, "resurrect -> hp == 10 (je %d)" % int(player.hp))
	t._check(int(rr.get("hp", 0)) == 10, "resurrect hlasi hp == 10")
	t._check(not death.is_ghost(PLAYER), "po resurrect hrac NENI duch")
	t._check(bool(rr.get("was_ghost", false)), "resurrect hlasi, ze hrac byl duch")
	t._check(int(player.body) == 400, "resurrect vraci puvodni telo (%d)" % int(player.body))
	var obsah2: Array = _obsah(container, death.corpse_of(PLAYER))
	if death.corpse_of(PLAYER) == null:
		t._check(true, "telo po vzkriseni zmizelo z evidence (obsah se vratil)")
	else:
		t._check(obsah2.size() < 2, "telo po vzkriseni uz nema obsah (%d)" % obsah2.size())
	# Obsah batohu je v KONTEJNERU pod serialem batohu (`player.backpack`), ne
	# pod serialem hrace - `_obsah(container, player)` by cetl prazdny kontejner
	# hrace a hlasil 0 predmetu (namERena vada testu 2026-10-11).
	var v_batohu: Array = _obsah(container, player.backpack)
	t._check(v_batohu.size() >= 2,
		"po vzkriseni je obsah tela v batohu (%d predmetu)" % v_batohu.size())
	t._check(v_batohu.has(0x600001) and v_batohu.has(0x600004),
		"v batohu je mec i nasazena zbroj z tela (%s)" % str(v_batohu))

	# -- D2) ART TELA: bez providera konstanta, s providerem `0x4000 + body` --
	# Duvod: `DEFAULT_CORPSE_ART` (0x2006) v nasem manifestu atlasu NENI
	# (namEReno 2026-10-11), takze telo vzniklo a na obrazovce BYLO NEVIDITELNE.
	# `app.main` proto dava `art_provider` a UO kresli mrtvolu statickym artem
	# tvora (`0x4000 + body`) - ten v manifestu JE.
	var cart_c = ContainerScript.new()
	var items_c: Dictionary = {}
	var ev_c = EventsScript.new()
	var clk_c = ClockScript.new()
	var dec_c = s_decay.new(clk_c, ev_c, cart_c, items_c)
	var bez = s_death.new(RegistryScript.new(), cart_c, items_c, ev_c, StubSerials.new(), dec_c)
	var svet_c: Array = _svet(cart_c, items_c, clk_c, ev_c)
	bez._registry = svet_c[0]
	bez.set_player(PLAYER)
	svet_c[1].hp = 0
	bez.die(PLAYER)
	var telo_bez = bez.corpse_of(PLAYER)
	t._check(telo_bez != null and int(telo_bez.tile) > 0,
		"bez providera ma telo art z konstanty (%s)"
		% (str(int(telo_bez.tile)) if telo_bez != null else "zadne telo"))

	var cart_p = ContainerScript.new()
	var items_p: Dictionary = {}
	var ev_p = EventsScript.new()
	var clk_p = ClockScript.new()
	var dec_p = s_decay.new(clk_p, ev_p, cart_p, items_p)
	var provider = StubArtProvider.new()
	var s_prov = s_death.new(RegistryScript.new(), cart_p, items_p, ev_p, StubSerials.new(),
		dec_p, 0, "res://data/balance.json", null, provider)
	var svet_p: Array = _svet(cart_p, items_p, clk_p, ev_p)
	s_prov._registry = svet_p[0]
	s_prov.set_player(PLAYER)
	svet_p[1].hp = 0
	s_prov.die(PLAYER)
	var telo_prov = s_prov.corpse_of(PLAYER)
	t._check(telo_prov != null and int(telo_prov.tile) == 0x4000 + 400,
		"provider da art tela = 0x4000 + body (ocekavano 0x%X, je %s)"
		% [0x4000 + 400, str(int(telo_prov.tile)) if telo_prov != null else "zadne"])
	# A kdyz provider art v manifestu NEMA (vraci 0), musi se pouzit konstanta -
	# "telo bez artu" se nesmi tvarit jako uspech.
	provider.chybejici = true
	var cart_ch = ContainerScript.new()
	var items_ch: Dictionary = {}
	var ev_ch = EventsScript.new()
	var clk_ch = ClockScript.new()
	var dec_ch = s_decay.new(clk_ch, ev_ch, cart_ch, items_ch)
	var s_ch = s_death.new(RegistryScript.new(), cart_ch, items_ch, ev_ch, StubSerials.new(),
		dec_ch, 0, "res://data/balance.json", null, provider)
	var svet_ch: Array = _svet(cart_ch, items_ch, clk_ch, ev_ch)
	s_ch._registry = svet_ch[0]
	s_ch.set_player(PLAYER)
	svet_ch[1].hp = 0
	s_ch.die(PLAYER)
	var telo_ch = s_ch.corpse_of(PLAYER)
	t._check(telo_ch != null and int(telo_ch.tile) == int(telo_bez.tile),
		"provider bez artu vraci konstantu (ocekavano %s, je %s)"
		% [str(int(telo_bez.tile)), str(int(telo_ch.tile)) if telo_ch != null else "zadne"])

	# -- E) DECAY: telo po 7 min (i s obsahem), predmet na zemi po 60 min -
	var c2 = ContainerScript.new()
	var it2: Dictionary = {}
	var clk2 = ClockScript.new()
	var ev2 = EventsScript.new()
	var decay2 = s_decay.new(clk2, ev2, c2, it2)
	t._check(decay2.corpse_ms() == CORPSE_DECAY_MS,
		"decay: telo 7 min (%d)" % decay2.corpse_ms())
	t._check(decay2.ground_ms() == GROUND_DECAY_MS,
		"decay: predmet na zemi 60 min (%d)" % decay2.ground_ms())
	t._check(decay2.loot_ms() == LOOT_RIGHTS_MS,
		"decay: pravo na loot 2 min (%d)" % decay2.loot_ms())
	var telo2 = ItemScript.new(0x700001, 0x2006, 1)
	telo2.type = "corpse"
	telo2.parent = 0
	var vec = ItemScript.new(0x700002, 0x4000 + 3935, 1)
	c2.add(0x700001, vec)
	it2[0x700001] = telo2
	it2[0x700002] = vec
	var zem = ItemScript.new(0x700003, 0x4000 + 3921, 1)
	zem.parent = 0
	it2[0x700003] = zem
	t._check(decay2.register_corpse(telo2), "decay zaregistroval telo")
	t._check(decay2.register_ground(zem), "decay zaregistroval predmet na zemi")
	t._check(decay2.pending() == 2, "decay ma 2 polozky ve fronte")
	# 6:59 - jeste nic; 7:00 - telo (i s obsahem) zmizi, vec na zemi zustava.
	clk2.advance(6 * 60000 + 59000)
	decay2.tick(0)
	t._check(decay2.removed_count() == 0, "po 6:59 se jeste nic neodstranilo")
	t._check(c2.contents(0x700001).size() == 1, "telo po 6:59 jeste ma obsah")
	clk2.advance(1000)
	decay2.tick(0)
	t._check(decay2.removed_count() == 1, "po 7 min se odstranilo telo (pocet %d)" % decay2.removed_count())
	t._check(c2.contents(0x700001).is_empty(), "telo po 7 min nema obsah (rozpadlo se i s obsahem)")
	t._check(decay2.pending() == 1, "predmet na zemi zustava ve fronte")
	var jmena3: Array = _jmena(ev2)
	t._check(jmena3.has("item_removed"), "decay posle item_removed (%s)" % str(jmena3))
	# 59:59 od položení - ještě nic; 60:00 - zmizi.
	clk2.advance(52 * 60000 + 59000)
	decay2.tick(0)
	t._check(decay2.removed_count() == 1, "po 59:59 od položení predmet na zemi jeste je")
	clk2.advance(1000)
	decay2.tick(0)
	t._check(decay2.removed_count() == 2, "po 60 min predmet na zemi zmizel (pocet %d)" % decay2.removed_count())
	t._check(decay2.pending() == 0, "fronta decay je prazdna")

	# -- F) DECAY: predmet v kontejneru se nerozpadá ----------------------
	var c3 = ContainerScript.new()
	var it3: Dictionary = {}
	var clk3 = ClockScript.new()
	var decay3 = s_decay.new(clk3, EventsScript.new(), c3, it3)
	var v_truhle = ItemScript.new(0x710001, 0x4000 + 3935, 1)
	c3.add(0x99999, v_truhle)
	it3[0x710001] = v_truhle
	t._check(not decay3.register_ground(v_truhle),
		"predmet v kontejneru se do fronty rozpadu NEREGISTRUJE")
	t._check(decay3.pending() == 0, "fronta zustava prazdna")

	# -- G) DECAY: state/restore round-trip ------------------------------
	var c4 = ContainerScript.new()
	var it4: Dictionary = {}
	var clk4 = ClockScript.new()
	var decay4 = s_decay.new(clk4, EventsScript.new(), c4, it4)
	var z2 = ItemScript.new(0x720001, 0x4000 + 1, 1)
	z2.parent = 0
	it4[0x720001] = z2
	decay4.register_ground(z2)
	var stav: Dictionary = decay4.state()
	var decay5 = s_decay.new(clk4, EventsScript.new(), c4, it4)
	decay5.restore(stav)
	t._check(decay5.pending() == decay4.pending(), "decay state/restore: stejny pocet ve fronte")
	t._check(decay5.due_of(0x720001) == decay4.due_of(0x720001),
		"decay state/restore: stejny cas rozpadu")
	t._check(decay5.removed_count() == decay4.removed_count(),
		"decay state/restore: stejne pocitadlo odstranenych")

	# -- H) DEATH: state/restore -----------------------------------------
	var stav_d: Dictionary = death.state()
	var death2 = s_death.new(registry, container, items, EventsScript.new(),
		StubSerials.new(), decay)
	death2.restore(stav_d)
	t._check(death2.ghost_count() == death.ghost_count(),
		"death state/restore: stejny pocet duchu (%d vs %d)"
		% [death2.ghost_count(), death.ghost_count()])
	t._check(death2.corpse_count() == death.corpse_count(),
		"death state/restore: stejny pocet těl (%d vs %d)"
		% [death2.corpse_count(), death.corpse_count()])


func _obsah(container, majitel) -> Array:
	# `null` majitel (telo uz neexistuje) vraci prazdno - volat `int(null)`
	# by shodilo `run()` a case by TISE zmeril mene kontrol (docs/04 §4.8.1).
	var out: Array = []
	if container == null or majitel == null:
		return out
	var serial: int = int(majitel.serial) if majitel is Object else int(majitel)
	for s in container.contents(serial):
		out.append(int(s))
	return out
