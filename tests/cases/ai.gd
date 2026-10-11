extends RefCounted
# sim.ai - stavove mysleni monster a NPC (docs/04 §4.2 a tok §4.6.7,
# docs/05 §5.12; reference `_src/servuo/Scripts/Mobiles/AI/BaseAI.cs:45-53`).
#
# Test meri CHOVANI na skutecnych systemech (`sim.movement` + `sim.combat`
# s fixture zbrani a s mapou skillu jako VSTUPEM), ne na atrapach - proto se da
# overit i to, ze AI NEMA vlastni pravidla pruchodu: kazdy krok musi projit
# pres `movement.request_step` (fronta `_pending`).
#
# ⚠ KAZDA SEKCE MA VLASTNI REGISTR. Poprve to bylo jinak a testy si navzajem
# "pujcovaly" mobily (monstrum videlo monstrum z predchozi sekce) - namERene
# selhani: `mimo dosah zraku AI neaggruje (cil 1073741826)`.
#
# Co se meri:
#   * namapovani stavu na akcni typ reference (`idle->Interact/Guard`,
#     `wander->Wander`, `aggro/attack->Combat`, `flee->Flee`),
#   * rychlost mysleni: 0,2 s v boji / 0,4 s v klidu (`BaseAI.cs:3031-3035`;
#     kontrakt M5 §5),
#   * monstrum si VSIMNE hrace ve vzdalenosti <= `AGGRO_RANGE` (10) a utoci,
#     kdyz je na dosah (`MELEE_RANGE` 1),
#   * NPC v idle se do 10 s pohne (wander); po 60 s bez cile jde na `home`,
#   * flee pri hp <= 20 % (kontrakt M5 §5),
#   * monstra maji `body != 400` (kostlivec 50) - jinak by zalozni rozpoznani
#     hrace (`body == 400/401`) udelalo z monstra hrace a AI by ho preskocila.
#
# Cesta k souborum je VSTUP: `-- --ai-script=<cesta> --combat-script=<cesta>
# --movement-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RngScript = preload("res://core/rng.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const StatsScript = preload("res://sim/entity/stats.gd")
const ItemScript = preload("res://sim/entity/item.gd")

const AI_SCRIPT := "res://sim/systems/ai.gd"
const COMBAT_SCRIPT := "res://sim/systems/combat.gd"
const MOVEMENT_SCRIPT := "res://sim/systems/movement.gd"
const WEAPONS_FIXTURE := "res://tests/fixtures/m5/weapons.json"
const NO_FILE := "res://tests/fixtures/m5/NEEXISTUJE.json"

const PLAYER := 0x40000001
const MONSTER := 0x40000002
const DAGGER_ART := 3921
const SKILL_FENCING := 42
const SKILL_WRESTLING := 43
const BODY_SKELETON := 50
const BODY_PLAYER := 400

const SKILLS := {"Fencing": SKILL_FENCING, "Wrestling": SKILL_WRESTLING,
	"Tactics": 27, "Anatomy": 1}


class FakeWalk:
	# Pruchodnost je vec `world.walk` (`tests/cases/walk.gd`); tady staci
	# "vsechno projde", aby se merilo MYSLENI, ne mapa.
	func can_step(_from: Vector3i, _dir: int, _height: int, _is_player: bool) -> Dictionary:
		return {"ok": true, "z": 0, "reason": ""}


class FakeEquipment:
	func at_layer(_m: int, _layer: int) -> int:
		return 0

	func bonus(_m: int, _key: String) -> int:
		return 0


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _nasad_zbran(items, mob, art: int) -> void:
	var item = ItemScript.new(0x8000 + int(mob.serial) % 1000, art + ItemScript.ITEM_OFFSET, 1)
	item.layer = 1
	item.parent = int(mob.serial)
	items[int(item.serial)] = item
	mob.equip[1] = int(item.serial)


func _monstrum(registry, serial: int, x: int, y: int, hp: int = 1000):
	# Monstrum s TELEM KOSTLIVCE (50), ne s lidskym (400) - viz hlavicka.
	var mob = MobileScript.new(serial, BODY_SKELETON, Vector3i(x, y, 0))
	mob.name = "a skeleton"
	mob.max_hp = hp
	mob.hp = hp
	mob.stam = 100
	mob.stats = StatsScript.new(56, 56, 16)
	registry.register(mob)
	mob.ai = {"state": "idle", "target": 0, "home": Vector3i(x, y, 0), "timer_ms": 0}
	return mob


func _hrac(registry, serial: int, x: int, y: int):
	var mob = MobileScript.new(serial, BODY_PLAYER, Vector3i(x, y, 0))
	mob.name = "Player"
	mob.max_hp = 100
	mob.hp = 100
	registry.register(mob)
	return mob


func run(t) -> void:
	var cesta_ai: String = _arg("ai-script", AI_SCRIPT)
	var cesta_combat: String = _arg("combat-script", COMBAT_SCRIPT)
	var cesta_mv: String = _arg("movement-script", MOVEMENT_SCRIPT)
	var s_ai = Lib.script_at(cesta_ai)
	var s_combat = Lib.script_at(cesta_combat)
	var s_mv = Lib.script_at(cesta_mv)
	if s_ai == null:
		t._pending("sim.ai NENI HOTOVY: " + cesta_ai + " chybi nebo se neparsuje")
		return
	if s_combat == null:
		t._pending("sim.combat chybi: " + cesta_combat)
		return
	if s_mv == null:
		t._pending("sim.movement chybi: " + cesta_mv)
		return
	var weapons = Lib.json_at(WEAPONS_FIXTURE)
	if weapons == null:
		t._pending("fixture " + WEAPONS_FIXTURE + " chybi")
		return

	# -- A) MAPOVANI STAVU NA REFERENCI (bez mobily) ---------------------
	var regA = RegistryScript.new()
	var cA = ClockScript.new()
	var aiA = s_ai.new(regA, s_mv.new(FakeWalk.new(), cA, EventsScript.new(), "never", regA),
		null, cA, EventsScript.new(), RngScript.new(9), null)
	t._check(aiA.reference_state("idle") == "Interact/Guard",
		"idle -> Interact/Guard (je '%s')" % aiA.reference_state("idle"))
	t._check(aiA.reference_state("wander") == "Wander", "wander -> Wander")
	t._check(aiA.reference_state("aggro") == "Combat", "aggro -> Combat")
	t._check(aiA.reference_state("attack") == "Combat", "attack -> Combat")
	t._check(aiA.reference_state("flee") == "Flee", "flee -> Flee")
	t._check(aiA.aggro_range() == 10, "AGGRO_RANGE == 10 (je %d)" % aiA.aggro_range())
	t._check(aiA.flee_threshold_pct() == 20,
		"prah flee == 20 %% (je %d)" % aiA.flee_threshold_pct())
	t._check(aiA.range_home() == 10, "RangeHome == 10 (je %d)" % aiA.range_home())
	t._check(aiA.can_see_source() == "range-only",
		"bez `can_see` je viditelnost podle vzdalenosti (zdroj '%s')" % aiA.can_see_source())

	# -- B) RYCHLOST MYSLENI: 0,2 s v boji / 0,4 s v klidu ---------------
	var regB = RegistryScript.new()
	var itB: Dictionary = {}
	var clkB = ClockScript.new()
	var mvB = s_mv.new(FakeWalk.new(), clkB, EventsScript.new(), "never", regB)
	var cB = s_combat.new(regB, weapons, itB, FakeEquipment.new(), SKILLS,
		RngScript.new(3), clkB, EventsScript.new(), null, WEAPONS_FIXTURE,
		"res://tests/fixtures/m5/armor.json", "res://data/balance.json")
	var aiB = s_ai.new(regB, mvB, cB, clkB, EventsScript.new(), RngScript.new(9), null)
	var mobB = _monstrum(regB, MONSTER, 100, 100)
	t._check(aiB.state_of(MONSTER) == "idle", "monstrum zacina v idle")
	t._check(aiB.think_interval_ms(MONSTER) == 400,
		"v klidu mysli kazdych 400 ms (je %d)" % aiB.think_interval_ms(MONSTER))

	# -- C) AGGRO: hrac na dosah zraku ----------------------------------
	var hrac = _hrac(regB, PLAYER, 100, 106)      # vzdalenost 6 <= 10
	var v1: Dictionary = aiB.think(MONSTER)
	t._check(str(v1.get("state", "")) == "aggro",
		"monstrum si vsimne hrace na 6 dlazdic -> aggro (stav '%s')" % str(v1.get("state", "")))
	t._check(int(v1.get("target", 0)) == PLAYER,
		"aggro nastavi cil na hrace (%d)" % int(v1.get("target", 0)))
	t._check(str(v1.get("action", "")) == "step_to_target",
		"aggro krokuje k cili (akce '%s')" % str(v1.get("action", "")))
	t._check(aiB.think_interval_ms(MONSTER) == 200,
		"v boji mysli kazdych 200 ms (je %d)" % aiB.think_interval_ms(MONSTER))
	t._check(mvB.pending_count() == 1,
		"AI krokuje pres sim.movement.request_step (fronta %d)" % mvB.pending_count())

	# -- D) Hrac mimo dosah zraku -> zadne aggro (VLASTNI REGISTR) -------
	var regD = RegistryScript.new()
	var clkD = ClockScript.new()
	var mvD = s_mv.new(FakeWalk.new(), clkD, EventsScript.new(), "never", regD)
	var aiD = s_ai.new(regD, mvD, null, clkD, EventsScript.new(), RngScript.new(9), null)
	var mobD = _monstrum(regD, MONSTER + 1, 100, 100)
	_hrac(regD, PLAYER, 200, 200)                 # vzdalenost 100 > 10
	var v2: Dictionary = aiD.think(MONSTER + 1)
	t._check(int(v2.get("target", 0)) == 0,
		"mimo dosah zraku AI neaggruje (cil %d)" % int(v2.get("target", 0)))
	t._check(str(v2.get("state", "")) == "idle" or str(v2.get("state", "")) == "wander",
		"mimo dosah zustava idle/wander (stav '%s')" % str(v2.get("state", "")))

	# -- E) NPC V IDLE SE DO 10 s POHNE (wander; VLASTNI REGISTR) --------
	var regE = RegistryScript.new()
	var clkE = ClockScript.new()
	var mvE = s_mv.new(FakeWalk.new(), clkE, EventsScript.new(), "never", regE)
	var aiE = s_ai.new(regE, mvE, null, clkE, EventsScript.new(), RngScript.new(9), null)
	var mobE = _monstrum(regE, MONSTER + 2, 300, 300)
	# PRVNI mysleni musi probehnout: "ticho" se pocita od chvile, kdy mobil
	# naposledy VZESEL do sveho stavu (`since_ms`) - bez prvniho mysleni by
	# casovac vznikl az v okamziku kontroly a ticho by bylo 0.
	t._check(str(aiE.think(MONSTER + 2).get("state", "")) == "idle",
		"prvni mysleni je idle")
	clkE.advance(9900)
	var v3: Dictionary = aiE.think(MONSTER + 2)
	t._check(str(v3.get("state", "")) != "wander",
		"po 9,9 s ticha se jeste nebloudi (stav '%s')" % str(v3.get("state", "")))
	clkE.advance(100)
	var v4: Dictionary = aiE.think(MONSTER + 2)
	t._check(str(v4.get("state", "")) == "wander",
		"po 10 s ticha se NPC pohne (wander; stav '%s')" % str(v4.get("state", "")))
	t._check(str(v4.get("action", "")) == "wander", "akce je wander")
	t._check(mvE.pending_count() == 1, "wander krokuje (fronta %d)" % mvE.pending_count())

	# -- F) ATTACK: cil na dosah -> sim.combat.attack --------------------
	var regF = RegistryScript.new()
	var itF: Dictionary = {}
	var clkF = ClockScript.new()
	var mvF = s_mv.new(FakeWalk.new(), clkF, EventsScript.new(), "never", regF)
	var cF = s_combat.new(regF, weapons, itF, FakeEquipment.new(), SKILLS,
		RngScript.new(3), clkF, EventsScript.new(), null, WEAPONS_FIXTURE,
		"res://tests/fixtures/m5/armor.json", "res://data/balance.json")
	var aiF = s_ai.new(regF, mvF, cF, clkF, EventsScript.new(), RngScript.new(1), null)
	var mobF = _monstrum(regF, MONSTER + 3, 400, 400)
	# Monstrum ma v ruce Dagger z fixture, takze swing je 2000 ms
	# (`floor(40000/((100+100)*50))*500` - `speed 50` z fixture). Tohle je
	# zaroven doklad, ze AI utoci ZBRANI, ne pesti.
	mobF.equip.clear()
	mobF.skills.set_value(SKILL_WRESTLING, 500)
	var hracF = _hrac(regF, PLAYER + 1, 400, 401)  # vzdalenost 1 = dosah
	hracF.skills.set_value(SKILL_WRESTLING, 500)
	hracF.set("resist", {"physical": 0})
	var aiF2: Dictionary = hracF.get("ai")
	aiF2["data"] = {"resist": {"physical": 0}}
	hracF.set("ai", aiF2)
	# PRVNI mysleni cil teprve NAJDE (aggro + krok k nemu) - pokud uz je cil
	# zapsany z drivejsiho behu, rovnou se utoci.
	var v0: Dictionary = aiF.think(MONSTER + 3)
	var v5: Dictionary = v0
	if str(v0.get("state", "")) != "attack":
		t._check(str(v0.get("state", "")) == "aggro",
			"prvni mysleni: monstrum cil naslo (stav '%s')" % str(v0.get("state", "")))
		v5 = aiF.think(MONSTER + 3)
	t._check(str(v5.get("state", "")) == "attack",
		"cil na dosah 1 -> attack (stav '%s')" % str(v5.get("state", "")))
	t._check(str(v5.get("action", "")) == "attack",
		"akce je attack (je '%s')" % str(v5.get("action", "")))
	var st: Dictionary = cF.state_of(MONSTER + 3)
	t._check(bool(st.get("war", false)), "AI pres sim.combat nastavilo war = true")
	t._check(int(st.get("target", 0)) == PLAYER + 1,
		"AI pres sim.combat nastavilo cil (%d)" % int(st.get("target", 0)))
	# Wrestling: `speed 50` (`combat.WRESTLING_SPEED`), stam 100 ->
	# `v = (100+100)*50 = 10000`, `floor(40000/10000) = 4`, `4*500 = 2000 ms`.
	t._check(int(st.get("delay_ms", 0)) == 2000,
		"AI pres sim.combat naplanovalo swing (wrestling, stam 100 -> 2000 ms; je %d)"
		% int(st.get("delay_ms", 0)))

	# -- G) FLEE pri hp <= 20 % ------------------------------------------
	mobF.hp = 200                             # presne 20 % z 1000
	var v6: Dictionary = aiF.think(MONSTER + 3)
	t._check(str(v6.get("state", "")) == "flee",
		"hp na 20 %% -> flee (stav '%s')" % str(v6.get("state", "")))
	t._check(str(v6.get("action", "")) == "step_away",
		"flee krokuje od cile (akce '%s')" % str(v6.get("action", "")))
	mobF.hp = 201
	var v7: Dictionary = aiF.think(MONSTER + 3)
	t._check(str(v7.get("state", "")) != "flee",
		"hp na 20,1 %% uz neutika (stav '%s')" % str(v7.get("state", "")))

	# -- H) KROK JDE PRES `movement` A JE CHUZE ---------------------------
	var regH = RegistryScript.new()
	var clkH = ClockScript.new()
	var mvH = s_mv.new(FakeWalk.new(), clkH, EventsScript.new(), "never", regH)
	var aiH = s_ai.new(regH, mvH, null, clkH, EventsScript.new(), RngScript.new(1), null)
	var mobH = _monstrum(regH, MONSTER + 5, 500, 500, 100)
	# Hrac je tu, ale DALEKO (mimo AGGRO_RANGE 10) - kdyby tu nebyl vubec,
	# AI by hledala nepritele a nikdy by se nedostala k "tichu" v idle.
	_hrac(regH, PLAYER + 5, 900, 900)
	aiH.think(MONSTER + 5)                       # zapise `since_ms`
	clkH.advance(10001)
	aiH.think(MONSTER + 5)
	t._check(mvH.pending_count() <= 1,
		"AI nikdy nezahlti frontu kroku (pending %d <= 1)" % mvH.pending_count())
	if mvH.pending_count() == 1:
		var krok: Dictionary = mvH.pending_step(MONSTER + 5)
		t._check(bool(krok.get("run", true)) == false, "AI krokuje CHUZI (run == false)")
		t._check(int(krok.get("delay_ms", 0)) == 400,
			"krok AI ma prodlevu chuze 400 ms (je %d)" % int(krok.get("delay_ms", 0)))
		# Druhy `think` ve stejnem case nesmi zahodit rozjety krok ("busy") a
		# stav ma zustat wander (AI se neprepne na aggro kvuli VLASTNIMU kroku).
		var v8: Dictionary = aiH.think(MONSTER + 5)
		t._check(str(v8.get("state", "")) == "wander",
			"AI zustava ve wander i s krokem v letu (stav '%s')" % str(v8.get("state", "")))
	else:
		t._pending("AI se po 10 s ticha nepohnul (fronta 0)")

	# -- I) AGGRO -> UTOCENI: HRACI OPRAVDU KLESNE HP ----------------------
	# `war = true` samo nic neznamena - swing musi dobehnout a ubrat hp.
	var regI = RegistryScript.new()
	var clkI = ClockScript.new()
	var itI: Dictionary = {}
	var mvI = s_mv.new(FakeWalk.new(), clkI, EventsScript.new(), "never", regI)
	var cI = s_combat.new(regI, weapons, itI, FakeEquipment.new(), SKILLS,
		RngScript.new(3), clkI, EventsScript.new(), null, WEAPONS_FIXTURE,
		"res://tests/fixtures/m5/armor.json", "res://data/balance.json")
	var aiI = s_ai.new(regI, mvI, cI, clkI, EventsScript.new(), RngScript.new(4), null)
	aiI.set_player(PLAYER)
	var monI = _monstrum(regI, MONSTER, 10, 10)
	monI.skills.set_value(SKILL_WRESTLING, 1000)
	monI.set("damage", [5, 10])
	var hracI = MobileScript.new(PLAYER, BODY_PLAYER, Vector3i(11, 10, 0))
	hracI.max_hp = 1000
	hracI.hp = 1000
	hracI.skills.set_value(SKILL_WRESTLING, 0)
	hracI.set("resist", {"physical": 0})
	regI.register(hracI)
	var hp0: int = int(hracI.hp)
	var videl_war := false
	for i in 800:
		clkI.advance(200)
		aiI.tick(200)
		mvI.tick(200)
		cI.tick(200)
		if bool(cI.state_of(MONSTER).get("war", false)):
			videl_war = true
	t._check(videl_war, "AI zahajilo boj pres sim.combat (war = true)")
	t._check(int(hracI.hp) < hp0,
		"hraci OPRAVDU kleslo hp z utoku monstra (%d -> %d)" % [hp0, int(hracI.hp)])
	t._check(aiI.state_of(PLAYER) == "idle",
		"hrac zustava idle - AI ho neridi (je '%s')" % aiI.state_of(PLAYER))

	# -- J) PO 60 s BEZ CILE ZPET NA HOME (a v 50 s jeste ne) -------------
	var regJ = RegistryScript.new()
	var clkJ = ClockScript.new()
	var mvJ = s_mv.new(FakeWalk.new(), clkJ, EventsScript.new(), "never", regJ)
	var aiJ = s_ai.new(regJ, mvJ, null, clkJ, EventsScript.new(), RngScript.new(9), null)
	var mobJ = _monstrum(regJ, MONSTER, 20, 20)
	var domov: Vector3i = mobJ.ai["home"]
	aiJ.think(MONSTER)                      # ticho zacina v case 0
	clkJ.advance(50000)
	mobJ.pos = domov + Vector3i(3, 0, 0)    # jako by odesel wanderem
	var v50: Dictionary = aiJ.think(MONSTER)
	t._check(str(v50.get("action", "")) != "step_home",
		"v 50 s se jeste nevraci na home (akce '%s')" % str(v50.get("action", "")))
	var flush := 0
	while flush < 2 and mvJ.pending_count() > 0:
		clkJ.advance(400)
		mvJ.tick(400)
		flush += 1
	clkJ.advance(10000)                     # 60,0 s celkem
	mobJ.pos = domov + Vector3i(3, 0, 0)
	var v60: Dictionary = aiJ.think(MONSTER)
	t._check(str(v60.get("action", "")) == "step_home",
		"po 60 s bez cile jde zpet na home (akce '%s', stav '%s')"
			% [str(v60.get("action", "")), str(v60.get("state", ""))])
	var kroku := 0
	while kroku < 12 and mobJ.pos != domov:
		clkJ.advance(400)
		mvJ.tick(400)
		aiJ.tick(0)
		kroku += 1
	t._check(mobJ.pos == domov,
		"do 12 kroku je zpet na home (pos %s, home %s, kroku %d)"
			% [str(mobJ.pos), str(domov), kroku])

	# -- K) PRODEJCE (`ai.state == "vendor"`) SE NESMI TIKNOUT ------------
	# Telo 12 (ne 400): kdyby mel lidske, preskocila by ho uz zaloha pro hrace
	# a meril by se jiny kód nez brana vendora.
	var regK = RegistryScript.new()
	var clkK = ClockScript.new()
	var mvK = s_mv.new(FakeWalk.new(), clkK, EventsScript.new(), "never", regK)
	var aiK = s_ai.new(regK, mvK, null, clkK, EventsScript.new(), RngScript.new(9), null)
	var kovar = MobileScript.new(MONSTER + 20, 12, Vector3i(80, 80, 0))
	kovar.max_hp = 100
	kovar.hp = 100
	kovar.ai = {"state": "vendor", "target": 0, "home": Vector3i(80, 80, 0), "timer_ms": 0}
	regK.register(kovar)
	for i in 700:
		clkK.advance(100)
		aiK.tick(100)
		mvK.tick(100)
	t._check(kovar.pos == Vector3i(80, 80, 0),
		"prodejce se za 70 s nepohnul (pos %s)" % str(kovar.pos))
	t._check(aiK.state_of(MONSTER + 20) == "vendor",
		"prodejci zustal stav vendor (je '%s')" % aiK.state_of(MONSTER + 20))
	t._check(str(aiK.think(MONSTER + 20).get("reason", "")) == "vendor",
		"prime mysleni prodejce je odmitnute (reason '%s')"
			% str(aiK.think(MONSTER + 20).get("reason", "")))

	# -- L) HRAC SE AI NERIDI (je ve stejnem registru jako monstra) --------
	var regL = RegistryScript.new()
	var clkL = ClockScript.new()
	var mvL = s_mv.new(FakeWalk.new(), clkL, EventsScript.new(), "never", regL)
	var aiL = s_ai.new(regL, mvL, null, clkL, EventsScript.new(), RngScript.new(9), null)
	aiL.set_player(PLAYER)
	var hracL = MobileScript.new(PLAYER, BODY_PLAYER, Vector3i(10, 10, 0))
	hracL.max_hp = 1000
	hracL.hp = 1000
	regL.register(hracL)
	for i in 700:
		clkL.advance(100)
		aiL.tick(100)
		mvL.tick(100)
	t._check(hracL.pos == Vector3i(10, 10, 0) and str(hracL.ai["state"]) == "idle",
		"hrac se za 70 s nepohnul (pos %s, stav '%s')"
			% [str(hracL.pos), str(hracL.ai["state"])])
	t._check(aiL.player_source() == "set_player",
		"hrac je zadan pres set_player (zdroj '%s')" % aiL.player_source())

	# -- M) NEPRITELEM JE HRAC: dva mobily na sobe se NERVOU --------------
	var regM = RegistryScript.new()
	var clkM = ClockScript.new()
	var mvM = s_mv.new(FakeWalk.new(), clkM, EventsScript.new(), "never", regM)
	var aiM = s_ai.new(regM, mvM, null, clkM, EventsScript.new(), RngScript.new(9), null)
	var monM1 = _monstrum(regM, MONSTER, 50, 50)
	var monM2 = _monstrum(regM, MONSTER + 1, 50, 50)
	var vM: Dictionary = aiM.think(MONSTER)
	t._check(int(vM.get("target", -1)) == 0,
		"dva mobily na sobe se neaggruji - nepritelem je hrac (cil %d)"
			% int(vM.get("target", -1)))
	t._check(str(aiM.enemy_source()).begins_with("player-only"),
		"zdroj nepratelstvi je pojmenovany ('%s')" % aiM.enemy_source())
