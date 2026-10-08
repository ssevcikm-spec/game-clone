extends RefCounted
# sim.harvest - sber surovin (docs/04 §4.2, docs/05 §5.7, research/04 §1-2).
#
# Stub mapa vraci PRESNE to, co sber potrebuje: land id a statiky po blocich
# s LOKALNIMI x,y (jako `world.map.statics_at`). Stub `skill_gain` si zapisuje
# VOLANI (skill, difficulty, span) - proto se da merit, ze sber predava okno
# 800/1000/1200 desetin, a ne pevnych 500 z `SKILL_SPAN`.
#
# Meri se: spravna dlazdice + nastroj -> surovina; jina dlazdice -> `not_ore`;
# dosah; casek (1,6 s / 8 s); vycerpani a respawn banky; "neuspesny check
# neubira rudu"; pravidlo "skill pod ReqSkill -> zelezo"; a to, ze se PREDMET
# opravdu vlozi do batohu.
#
# Cesta k souboru je VSTUP: `-- --harvest-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RngScript = preload("res://core/rng.gd")

const HARVEST_SCRIPT := "res://sim/systems/harvest.gd"
const TILES_PATH := "res://assets/uo/tiles.json"
const SERIAL := 0x40000042
const PACK := 0x00000099
const TRAVNIK := 9999          # land id, ktery NENI v seznamu hor
const HORA := 220              # prvni land id ze seznamu hor (research §1.2)
const STROM := 0x4CCA          # prvni art ze seznamu stromu (research §1.3)
const VODA := 0x00A8           # prvni land id vody (research §1.4)

const SKILL_MINING := 45
const SKILL_LUMBERJACKING := 44
const SKILL_FISHING := 18


class StubMap:
	# `land` = {Vector2i: land id}, `statics` = {Vector2i: [{tile,x,y,z,hue}]}
	var land: Dictionary = {}
	var statics: Dictionary = {}

	func land_at(x: int, y: int) -> int:
		return int(land.get(Vector2i(x, y), TRAVNIK))

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x, y), [])


class StubSkill:
	# Vysledky se berou z fronty; prazdna fronta vraci `default_success`
	# (a `default_gained` pro rust skillu).
	var vysledky: Array = []
	var volani: Array = []
	var default_success: bool = true
	var default_gained: bool = false

	func check(_m: int, skill: int, difficulty: int, span: int = -1) -> Dictionary:
		volani.append({"skill": skill, "difficulty": difficulty, "span": span})
		var uspech: bool = default_success if vysledky.is_empty() else bool(vysledky.pop_front())
		return {"success": uspech, "gained": default_gained, "new_value": 0, "reason": ""}


class StubContainer:
	var obsah: Dictionary = {}

	func add(c: int, item) -> bool:
		if not obsah.has(c):
			obsah[c] = []
		obsah[c].append(item)
		return true

	func contents(c: int) -> Array[int]:
		var out: Array[int] = []
		for i in obsah.get(c, []):
			out.append(int(i.serial))
		return out

	func remove(c: int, item: int, amount: int) -> int:
		for i in obsah.get(c, []):
			if int(i.serial) == item:
				var brat: int = int(i.amount) if amount <= 0 else mini(amount, int(i.amount))
				i.amount = int(i.amount) - brat
				return brat
		return 0


class StubSerials:
	var hodnota: int = 100

	func next_serial() -> int:
		hodnota += 1
		return hodnota


class FakeRng:
	# Deterministicka nahrada `core.rng`: `chance()` vraci z fronty, prazdna
	# fronta vraci `default_result`; `range_i` vraci spodni mez.
	var results: Array = []
	var default_result: bool = false

	func chance(_p: float) -> bool:
		if results.is_empty():
			return default_result
		return bool(results.pop_front())

	func next_u32() -> int:
		return 0

	func range_i(a: int, _b: int) -> int:
		return a


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _statik(mapa, x: int, y: int, tile: int) -> void:
	var seznam: Array = mapa.statics.get(Vector2i(x, y), [])
	seznam.append({"tile": tile, "x": x % 8, "y": y % 8, "z": 0, "hue": 0})
	mapa.statics[Vector2i(x, y)] = seznam


func _sestav(t, rng = null) -> Array:
	# Vraci [system, mobil, mapa, skill, kontejner, serialy, clock]; prazdne
	# pole = granule neni hotova (a to je SELHANI, ne zelena).
	var cesta: String = _arg("harvest-script", HARVEST_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.harvest NENI HOTOVY: " + cesta + " chybi (nebo ma parse error)")
		return []
	var mapa := StubMap.new()
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var skill := StubSkill.new()
	var kontejner := StubContainer.new()
	var serialy := StubSerials.new()
	var nahoda = rng if rng != null else RngScript.new(11)
	var system = script.new(mapa, true, null, nahoda, clock, events, skill, kontejner, serialy)
	var mob = MobileScript.new(SERIAL, 400, Vector3i(100, 100, 0))
	mob.backpack = PACK
	system.register(mob)
	return [system, mob, mapa, skill, kontejner, serialy, clock]


func run(t) -> void:
	# -- A) hora + spravna dlazdice -> ruda ------------------------------
	var a := _sestav(t)
	if a.is_empty():
		return
	var system = a[0]
	var mapa = a[2]
	var skill = a[3]
	var kontejner = a[4]
	var clock = a[6]
	mapa.land[Vector2i(101, 100)] = HORA
	var ruda: Dictionary = system.mine(SERIAL, 101, 100)
	t._check(bool(ruda.get("ok", false)),
		"sim.harvest: na horni dlazdici (220) se kopat da (vyslo %s)" % str(ruda))
	t._check(int(ruda.get("art", 0)) == 0x59B8,
		"sim.harvest: ruda je art 0x59B8 (0x19B8 + 0x4000), namEReno 0x%X" % int(ruda.get("art", 0)))
	t._check(int(ruda.get("amount", 0)) == 1,
		"sim.harvest: za usek je 1 ruda (`ConsumedPerHarvest`, namEReno %d)" % int(ruda.get("amount", 0)))
	t._check(int(ruda.get("hue", -1)) == 0 and str(ruda.get("resource", "")) == "iron",
		"sim.harvest: pri skillu 0 je vzdy ZELEZO (namEReno %s)" % str(ruda.get("resource", "")))
	t._check(kontejner.obsah.get(PACK, []).size() == 1,
		"sim.harvest: ruda se opravdu vlozila do batohu (polozek %d)" % kontejner.obsah.get(PACK, []).size())
	t._check(int(ruda.get("serial", 0)) > 0,
		"sim.harvest: predmet dostal serial (namEReno %d)" % int(ruda.get("serial", 0)))
	t._check(skill.volani.size() == 1 and int(skill.volani[0]["skill"]) == SKILL_MINING
		and int(skill.volani[0]["difficulty"]) == 0 and int(skill.volani[0]["span"]) == 1000,
		"sim.harvest: skill check je Mining(45) s oknem 0..1000 desetin (namEReno %s)" % str(skill.volani))
	t._check(system.resource_left(101, 100) == int(ruda.get("left", -1)),
		"sim.harvest: `resource_left` sedi na to, co sber vratil (namEReno %d)" % system.resource_left(101, 100))
	# Casek: druhy sber HNED po sobe (1,6 s na usek) - kontrola musi byt tesne
	# po uspesnem kopnuti, jinak by casek vyprsel.
	var hned: Dictionary = system.mine(SERIAL, 101, 100)
	t._check(not bool(hned.get("ok", true)) and str(hned.get("reason", "")) == "busy",
		"sim.harvest: druhy sber hned po sobe je `busy` (namEReno %s)" % str(hned))
	t._check(system.busy_until("ore") > 0,
		"sim.harvest: `busy_until` je nastaveny (namEReno %d)" % system.busy_until("ore"))
	clock.advance(1600)

	# -- B) jina dlazdice -> not_ore -------------------------------------
	mapa.land[Vector2i(102, 100)] = TRAVNIK
	var travnik: Dictionary = system.mine(SERIAL, 102, 100)
	t._check(not bool(travnik.get("ok", true)) and str(travnik.get("reason", "")) == "not_ore",
		"sim.harvest: travnik vraci {ok:false, reason:'not_ore'} (namEReno %s)" % str(travnik))

	# -- C) dosah a dalsi usek po caseku ---------------------------------
	var daleko: Dictionary = system.mine(SERIAL, 105, 100)
	t._check(not bool(daleko.get("ok", true)) and str(daleko.get("reason", "")) == "too_far",
		"sim.harvest: 5 dlazdic je `too_far` (dosah 2, namEReno %s)" % str(daleko))
	var po_case: Dictionary = system.mine(SERIAL, 101, 100)
	t._check(bool(po_case.get("ok", false)),
		"sim.harvest: po caseku se kope znovu (namEReno %s)" % str(po_case))

	# -- D) vycerpani banky a respawn -------------------------------------
	var pokusu: int = 0
	while system.resource_left(101, 100) > 0 and pokusu < 60:
		clock.advance(1600)
		system.mine(SERIAL, 101, 100)
		pokusu += 1
	t._check(system.resource_left(101, 100) == 0,
		"sim.harvest: banka se da vycerpat (pokusu %d, zbyva %d)"
			% [pokusu, system.resource_left(101, 100)])
	clock.advance(1600)
	var prazdno: Dictionary = system.mine(SERIAL, 101, 100)
	t._check(not bool(prazdno.get("ok", true)) and str(prazdno.get("reason", "")) == "empty",
		"sim.harvest: vycerpana banka vraci `empty` (namEReno %s)" % str(prazdno))
	clock.advance(20 * 60000)
	var po_respawnu: int = system.resource_left(101, 100)
	t._check(po_respawnu >= 10 and po_respawnu <= 34,
		"sim.harvest: po respawnu (20 min) je v bance 10-34 rudy (namEReno %d)" % po_respawnu)

	# -- E) neuspesny skill check NESPOTREBUJE rudu ani neda predmet -------
	var e := _sestav(t)
	if e.is_empty():
		return
	var system_e = e[0]
	var skill_e = e[3]
	var kontejner_e = e[4]
	var mapa_e = e[2]
	mapa_e.land[Vector2i(101, 100)] = HORA
	skill_e.default_success = false
	skill_e.default_gained = true          # neuspech uci (era.skill_gain = pre-aos)
	var pred_zdroje: int = system_e.resource_left(101, 100)
	var selhalo: Dictionary = system_e.mine(SERIAL, 101, 100)
	t._check(not bool(selhalo.get("ok", true)) and str(selhalo.get("reason", "")) == "skill",
		"sim.harvest: neuspesny skill check vraci `skill` (namEReno %s)" % str(selhalo))
	t._check(bool(selhalo.get("gained", false)),
		"sim.harvest: neuspesny sber vraci `gained` (skill roste i pri neuspechu)")
	t._check(system_e.resource_left(101, 100) == pred_zdroje,
		"sim.harvest: neuspesny check rudu NEUBIRA (%d -> %d, research §1.1 krok 8)"
			% [pred_zdroje, system_e.resource_left(101, 100)])
	t._check(kontejner_e.obsah.get(PACK, []).is_empty(),
		"sim.harvest: neuspesny sber nic neprida do batohu")

	# -- F) strom -> log (10 za usek, art 0x5BDD) -------------------------
	var b := _sestav(t)
	if b.is_empty():
		return
	var system_b = b[0]
	var mapa_b = b[2]
	var skill_b = b[3]
	var kontejner_b = b[4]
	var clock_b = b[6]
	_statik(mapa_b, 101, 100, STROM)
	var drevo: Dictionary = system_b.chop(SERIAL, 101, 100)
	t._check(bool(drevo.get("ok", false)) and int(drevo.get("art", 0)) == 0x5BDD,
		"sim.harvest: statik stromu (0x4CCA) da log art 0x5BDD (namEReno %s)" % str(drevo))
	t._check(int(drevo.get("amount", 0)) == 10,
		"sim.harvest: za usek je 10 logu (`ConsumedPerHarvest`, namEReno %d)" % int(drevo.get("amount", 0)))
	t._check(skill_b.volani.size() == 1 and int(skill_b.volani[0]["skill"]) == SKILL_LUMBERJACKING
		and int(skill_b.volani[0]["span"]) == 1000,
		"sim.harvest: skill check je Lumberjacking(44) s oknem 1000 (namEReno %s)" % str(skill_b.volani))
	t._check(kontejner_b.obsah.get(PACK, []).size() == 1,
		"sim.harvest: log se vlozil do batohu")
	clock_b.advance(1600)
	var bez_stromu: Dictionary = system_b.chop(SERIAL, 102, 100)
	t._check(not bool(bez_stromu.get("ok", true)) and str(bez_stromu.get("reason", "")) == "not_tree",
		"sim.harvest: bez stromu vraci `not_tree` (namEReno %s)" % str(bez_stromu))

	# -- G) rybolov: voda, 8 s, a "75+ uspeje bez hodu" -------------------
	var c := _sestav(t)
	if c.is_empty():
		return
	var system_c = c[0]
	var mob_c = c[1]
	var mapa_c = c[2]
	var skill_c = c[3]
	var clock_c = c[6]
	mapa_c.land[Vector2i(101, 100)] = VODA
	var ryba: Dictionary = system_c.fish(SERIAL, 101, 100)
	t._check(bool(ryba.get("ok", false)) and int(ryba.get("art", 0)) in [0x49CC, 0x49CD, 0x49CE, 0x49CF],
		"sim.harvest: na vode se chyti ryba (art 0x9CC-0x9CF, namEReno %s)" % str(ryba))
	t._check(skill_c.volani.size() == 1 and int(skill_c.volani[0]["skill"]) == SKILL_FISHING
		and int(skill_c.volani[0]["span"]) == 1200,
		"sim.harvest: rybolov ma okno 1200 desetin (0..120, namEReno %s)" % str(skill_c.volani))
	t._check(system_c.busy_until("fish") - clock_c.now_ms() == 8000,
		"sim.harvest: rybolov trva 8 s (namEReno %d ms)" % (system_c.busy_until("fish") - clock_c.now_ms()))
	clock_c.advance(8000)
	mob_c.skills.set_value(SKILL_FISHING, 750)
	skill_c.volani.clear()
	var ryba75: Dictionary = system_c.fish(SERIAL, 101, 100)
	t._check(bool(ryba75.get("ok", false)) and skill_c.volani.is_empty(),
		"sim.harvest: pri skillu 75 (750 desetin) rybolov uspeje BEZ hodu (namEReno %s)" % str(ryba75))
	clock_c.advance(8000)
	var sucho: Dictionary = system_c.fish(SERIAL, 102, 100)
	t._check(not bool(sucho.get("ok", true)) and str(sucho.get("reason", "")) == "not_water",
		"sim.harvest: na susi vraci `not_water` (namEReno %s)" % str(sucho))

	# -- H) chybejici mobil / batoh ---------------------------------------
	var nikdo: Dictionary = system_c.mine(0x1234, 101, 100)
	t._check(not bool(nikdo.get("ok", true)) and str(nikdo.get("reason", "")) == "no_mobile",
		"sim.harvest: neznameho mobila vraci `no_mobile` (namEReno %s)" % str(nikdo))
	clock_c.advance(1600)
	mapa_c.land[Vector2i(102, 100)] = 221
	mob_c.backpack = 0
	var bez_batohu: Dictionary = system_c.mine(SERIAL, 102, 100)
	t._check(not bool(bez_batohu.get("ok", true)) and str(bez_batohu.get("reason", "")) == "no_pack",
		"sim.harvest: bez batohu vraci `no_pack` (namEReno %s)" % str(bez_batohu))

	# -- I) pravidlo "barevna zila + maly skill = zelezo" -----------------
	var fake := FakeRng.new()
	var d := _sestav(t, fake)
	if d.is_empty():
		return
	var system_d = d[0]
	var tabulka: Array = system_d.table_of("ore")
	t._check(tabulka.size() == 9,
		"sim.harvest: tabulka rud ma 9 radku (docs/05 §5.7, namEReno %d)" % tabulka.size())
	t._check(system_d.table_of("wood").size() == 7,
		"sim.harvest: tabulka dreva ma 7 radku (namEReno %d)" % system_d.table_of("wood").size())
	t._check(int(tabulka[1]["req"]) == 650 and int(tabulka[8]["req"]) == 990,
		"sim.harvest: prahy ReqSkill jsou 65 a 99 (dull copper / valorite)")
	fake.default_result = false                      # zadny nahodny fallback
	t._check(system_d.resource_index_for("ore", 1, 0) == 0,
		"sim.harvest: dull copper pri skillu 0 spadne na zelezo (index 0)")
	t._check(system_d.resource_index_for("ore", 1, 1000) == 1,
		"sim.harvest: dull copper pri skillu 100 zustava dull copper (index 1)")
	fake.results = [true]                            # 50 % hod na fallback padl
	t._check(system_d.resource_index_for("ore", 1, 1000) == 0,
		"sim.harvest: i pri vysokem skillu muze zila spadnout na zelezo (fallback hod)")
	t._check(system_d.resource_index_for("ore", 0, 0) == 0,
		"sim.harvest: zelezna zila nema fallback (zustava 0)")

	# -- J) zila je pro bucket DETERMINISTICKA ----------------------------
	var f := _sestav(t)
	if f.is_empty():
		return
	var jina = f[0]
	t._check(system_d.vein_name("ore", 101, 100) == jina.vein_name("ore", 101, 100),
		"sim.harvest: zila je dana bucketem, ne poradim volani (namEReno %s vs %s)"
			% [system_d.vein_name("ore", 101, 100), jina.vein_name("ore", 101, 100)])

	# -- K) realna data: zvoleny art je STACKOVATELNY ---------------------
	# Neni to detail: kdyby sber vyrabel art bez flagu Generic, hromady by se
	# v batohu NIKDY nesloucily (`entity.container` stackuje jen s 0x800).
	if not FileAccess.file_exists(TILES_PATH):
		print("[test] sim.harvest: REALNA DATA NEMERENA (chybi ", TILES_PATH, ")")
	else:
		var tiledata = Lib.script_at("res://sim/world/tiledata.gd").new()
		t._check(int(tiledata.flags(0x59B8)) & 0x800 != 0,
			"sim.harvest: art rudy 0x59B8 je stackovatelny (flags 0x%X)" % int(tiledata.flags(0x59B8)))
		t._check(int(tiledata.flags(0x5BDD)) & 0x800 != 0,
			"sim.harvest: art logu 0x5BDD je stackovatelny (flags 0x%X)" % int(tiledata.flags(0x5BDD)))

	t._check(true, "sim.harvest: case probehl cely (sentinel)")
