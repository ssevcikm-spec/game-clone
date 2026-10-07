extends RefCounted
# sim.skill_gain - rust skillu a statu (docs/04 §4.2, docs/05 §5.10,
# research/01 §3.3).
#
# Test meri PRESNA CISLA, ne dojmy:
#   * prijimaci kriterium smlouvy: 100 pokusu s `difficulty = 0` pri `value = 0`
#     da > 0 (tady PRESNE 100, protoze krok je pevny +0,1 = 1 desetina),
#   * KLICOVE PRAVIDLO (rozhodnuti uzivatele 2026-10-07): rust pri NEUSPECHU.
#     Hod na uspech a hod na rust jsou dva NEZAVISLE hody, proto test pouziva
#     `FakeRng`, ktery na uspech vraci `false` a na rust odpovida podle fronty;
#     kdyby rust zavisel na uspechu, kontrola spadne,
#   * GGS: garantovany rust po case z tabulky (`SkillCheck.cs:798-806`) - mez
#     27 min pro skill 50.1 a total < 350.0 se meri PRESNE (1 619 999 ms jeste
#     ne, 1 620 000 ms ano),
#   * strop jednotlivy (1000) a celkovy (7000 z `core/const.gd`) vcetne
#     arbitraze skillem se zamkem `down`,
#   * zamky: `locked` i `down` rust blokuji, `up` povoluje,
#   * determinismus: dva behy se stejnym seedem daji stejnou posloupnost,
#   * staty: prodleva a sance z `data/balance.json`, capy 125 a 225, na
#     celkovem capu se staty presouvaji (atrofie).
#
# Cesta k souboru je VSTUP: `-- --skill-gain-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RngScript = preload("res://core/rng.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const SKILL_GAIN_SCRIPT := "res://sim/systems/skill_gain.gd"
const SKILL := 7                 # Blacksmithy (`data/skills.json`, id 7)
const STAT_STR := 0
const SERIAL := 0x40000001
const GGS_50_MIN_DELAY_MS := 27 * 60000   # radek 10, sloupec 0 (`SkillCheck.cs:798-806`)


class FakeRng:
	# Deterministicka nahrada `core.rng`: `results` je fronta odpovedi na
	# `chance()`; kdyz je prazdna, vraci `default_result`.
	var results: Array = []
	var default_result: bool = false
	var chance_calls: int = 0

	func chance(_p: float) -> bool:
		chance_calls += 1
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


func _sestav(t, rng = null) -> Array:
	# Vraci [system, mobil, events, clock, registry, rng]; prazdne pole =
	# granule neni hotova (a to je SELHANI, ne zelena - docs/09 §9.10.9).
	var cesta: String = _arg("skill-gain-script", SKILL_GAIN_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.skill_gain NENI HOTOVA: " + cesta + " chybi (nebo ma parse error)")
		return []
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var registry = RegistryScript.new()
	var pouzity_rng = rng if rng != null else RngScript.new(7)
	var system = script.new(registry, pouzity_rng, clock, events)
	var mob = MobileScript.new(SERIAL, 400, Vector3i(1, 1, 0))
	system.register(mob)
	return [system, mob, events, clock, registry, pouzity_rng]


func _texty(events) -> Array:
	var out: Array = []
	for e in events.drain():
		if str(e["name"]) == "message":
			out.append(str(e["data"].get("text", "")))
	return out


func _prvni_rozdil(a: String, b: String) -> int:
	var n: int = mini(a.length(), b.length())
	for i in n:
		if a[i] != b[i]:
			return i
	return n


func run(t) -> void:
	# -- A) prijimaci kriterium smlouvy: 100 pokusu -> > 0 -----------------
	var a := _sestav(t)
	if a.is_empty():
		return
	var system = a[0]
	var mob = a[1]
	var neuspechu: int = 0
	var zisku: int = 0
	for i in 100:
		var r: Dictionary = system.check(mob.serial, SKILL, 0)
		if not bool(r["success"]):
			neuspechu += 1
		if bool(r["gained"]):
			zisku += 1
	t._check(mob.skills.value(SKILL) > 0,
		"sim.skill_gain: 100 pokusu (difficulty 0, value 0) -> > 0 (namEReno %d)" % mob.skills.value(SKILL))
	t._check(mob.skills.value(SKILL) == 100 * Const.SKILL_STEP,
		"sim.skill_gain: krok je pevny +0,1 z core/const.gd, takze %d (namEReno %d)" % [100 * Const.SKILL_STEP, mob.skills.value(SKILL)])
	# Tohle je soucasne mereni KLICOVEHO PRAVIDLA s REALNYM `core.rng`:
	# sance na uspech roste s hodnotou (0 -> 0,2), takze neuspechy i uspechy
	# se v 100 pokusech vyskytnou - a rust nastane PRI KAZDEM z nich.
	t._check(zisku == 100,
		"sim.skill_gain: rust nastal pri vsech 100 pokusech (zisku %d, neuspechu %d, hodnota 0 -> %d)" % [zisku, neuspechu, mob.skills.value(SKILL)])
	t._check(neuspechu > 0 and neuspechu < 100,
		"sim.skill_gain: hod na uspech je zivy - obe varianty nastaly (neuspechu %d z 100, hodnota %d)" % [neuspechu, mob.skills.value(SKILL)])

	# -- B) tvar API (klice smlouvy a int ve stavu) ------------------------
	var b := _sestav(t)
	if b.is_empty():
		return
	var odpoved: Dictionary = b[0].check(b[1].serial, SKILL, 0)
	t._check(odpoved.has("success") and odpoved.has("gained") and odpoved.has("new_value"),
		"sim.skill_gain: check vraci success/gained/new_value (namEReno %s)" % str(odpoved.keys()))
	t._check(typeof(odpoved["new_value"]) == TYPE_INT and typeof(odpoved["success"]) == TYPE_BOOL,
		"sim.skill_gain: new_value je int, ne float (docs/09 §9.10.3; namEReno typ %d)" % typeof(odpoved["new_value"]))
	t._check(typeof(b[1].skills.value(SKILL)) == TYPE_INT and typeof(b[1].skills.total()) == TYPE_INT,
		"sim.skill_gain: hodnota i total zustavaji int (typy %d / %d)" % [typeof(b[1].skills.value(SKILL)), typeof(b[1].skills.total())])

	# -- C) KLICOVE PRAVIDLO: rust pri neuspechu (dva nezavisle hody) ------
	var c1 := _sestav(t, FakeRng.new())
	if c1.is_empty():
		return
	var c1_rng: FakeRng = c1[5]
	var c1_mob = c1[1]
	c1_mob.skills.set_value(SKILL, 500)
	var ohrev: Dictionary = c1[0].check(c1_mob.serial, SKILL, 100)
	t._check(bool(ohrev["gained"]) and c1_mob.skills.value(SKILL) == 501,
		"sim.skill_gain: prvni check ma garantovany rust GGS (500 -> %d, namEReno %s)" % [c1_mob.skills.value(SKILL), str(ohrev)])
	c1_rng.results = [false, false]
	var bez: Dictionary = c1[0].check(c1_mob.serial, SKILL, 100)
	t._check(not bool(bez["success"]) and not bool(bez["gained"]) and c1_mob.skills.value(SKILL) == 501,
		"sim.skill_gain: uspech false + rust false -> bez rustu (namEReno %s, hodnota %d)" % [str(bez), c1_mob.skills.value(SKILL)])
	c1_rng.results = [false, true]
	var s_rustem: Dictionary = c1[0].check(c1_mob.serial, SKILL, 100)
	t._check(not bool(s_rustem["success"]) and bool(s_rustem["gained"]) and c1_mob.skills.value(SKILL) == 502,
		"sim.skill_gain: uspech false + rust true -> rust NASTANE (namEReno %s, hodnota 501 -> %d)" % [str(s_rustem), c1_mob.skills.value(SKILL)])

	# -- D) GGS: garantovany rust po case z tabulky ------------------------
	var d := _sestav(t, FakeRng.new())
	if d.is_empty():
		return
	d[1].skills.set_value(SKILL, 500)
	var g1: Dictionary = d[0].check(d[1].serial, SKILL, 100)
	t._check(bool(g1["gained"]) and d[1].skills.value(SKILL) == 501,
		"sim.skill_gain: GGS - prvni check (NextGGSGain = MinValue) garantuje rust (namEReno %s, hodnota %d)" % [str(g1), d[1].skills.value(SKILL)])
	var g2: Dictionary = d[0].check(d[1].serial, SKILL, 100)
	t._check(not bool(g2["gained"]) and d[1].skills.value(SKILL) == 501,
		"sim.skill_gain: GGS - dalsi check hned po zisku neroste (namEReno %s, hodnota %d)" % [str(g2), d[1].skills.value(SKILL)])
	d[3].advance(GGS_50_MIN_DELAY_MS - 1)
	var g3: Dictionary = d[0].check(d[1].serial, SKILL, 100)
	t._check(not bool(g3["gained"]),
		"sim.skill_gain: GGS - 1 ms pred terminem (26:59.999) jeste nic (namEReno %s)" % str(g3))
	d[3].advance(1)
	var g4: Dictionary = d[0].check(d[1].serial, SKILL, 100)
	t._check(bool(g4["gained"]) and d[1].skills.value(SKILL) == 502,
		"sim.skill_gain: GGS - po 27 min (radek 10, sloupec 0) rust garantovane (namEReno %s, hodnota %d)" % [str(g4), d[1].skills.value(SKILL)])

	# -- E) hranice: "too difficult" a "no challenge" ----------------------
	var e := _sestav(t, FakeRng.new())
	if e.is_empty():
		return
	e[1].skills.set_value(SKILL, 100)
	var tezke: Dictionary = e[0].check(e[1].serial, SKILL, 600)
	t._check(not bool(tezke["success"]) and not bool(tezke["gained"]) and e[1].skills.value(SKILL) == 100,
		"sim.skill_gain: skill pod obtiznosti (100 < 600) neuspeje a NEROSTE (namEReno %s, hodnota %d)" % [str(tezke), e[1].skills.value(SKILL)])
	e[1].skills.set_value(SKILL, 600)
	var bez_vyzvy: Dictionary = e[0].check(e[1].serial, SKILL, 100)
	t._check(bool(bez_vyzvy["success"]) and not bool(bez_vyzvy["gained"]) and e[1].skills.value(SKILL) == 600,
		"sim.skill_gain: 'no challenge' (600 >= 100 + 50.0) uspeje, ale NEROSTE (namEReno %s, hodnota %d)" % [str(bez_vyzvy), e[1].skills.value(SKILL)])

	# -- F) zamky skillu rust blokuji --------------------------------------
	var f := _sestav(t, FakeRng.new())
	if f.is_empty():
		return
	var f_mob = f[1]
	f_mob.skills.set_lock(SKILL, 2)          # 2 = locked
	var zamceno: Dictionary = f[0].check(f_mob.serial, SKILL, 0)
	t._check(not bool(zamceno["gained"]) and f_mob.skills.value(SKILL) == 0 and str(zamceno["reason"]) == "locked",
		"sim.skill_gain: zamek locked (2) rust blokuje (namEReno %s)" % str(zamceno))
	f_mob.skills.set_lock(SKILL, 1)          # 1 = down
	var dolu: Dictionary = f[0].check(f_mob.serial, SKILL, 0)
	t._check(not bool(dolu["gained"]) and f_mob.skills.value(SKILL) == 0,
		"sim.skill_gain: zamek down (1) rust blokuje (namEReno %s)" % str(dolu))
	f_mob.skills.set_lock(SKILL, 0)          # 0 = up
	var nahoru: Dictionary = f[0].check(f_mob.serial, SKILL, 0)
	t._check(bool(nahoru["gained"]) and f_mob.skills.value(SKILL) == 1,
		"sim.skill_gain: zamek up (0) rust povoli (namEReno %s, hodnota %d)" % [str(nahoru), f_mob.skills.value(SKILL)])

	# -- G) jednotlivy strop 1000 a hlaska hraci ---------------------------
	var g := _sestav(t, FakeRng.new())
	if g.is_empty():
		return
	g[1].skills.set_value(SKILL, 1000)
	var na_stropu: Dictionary = g[0].check(g[1].serial, SKILL, 600)
	t._check(not bool(na_stropu["gained"]) and int(na_stropu["new_value"]) == 1000,
		"sim.skill_gain: na stropu 1000 se nezvysi (namEReno %s)" % str(na_stropu))
	t._check(_texty(g[2]).has("Your skill cannot advance further."),
		"sim.skill_gain: na stropu dostane hrac hlasku (docs/05 §5.10; namEReno jina hlaska)")

	# -- H) celkovy strop 7000 a arbitraz skillem se zamkem `down` ---------
	var h := _sestav(t, FakeRng.new())
	if h.is_empty():
		return
	var h_rng: FakeRng = h[5]
	h_rng.default_result = true              # hod na obet (total/cap = 1.0) projde
	for i in range(7):
		h[1].skills.set_value(i, 1000)
	t._check(h[1].skills.total() == Const.SKILL_CAP,
		"sim.skill_gain: testovaci stav - total == SKILL_CAP z core/const.gd (%d, namEReno %d)" % [Const.SKILL_CAP, h[1].skills.total()])
	var plno: Dictionary = h[0].check(h[1].serial, SKILL, 0)
	t._check(not bool(plno["gained"]) and h[1].skills.value(SKILL) == 0,
		"sim.skill_gain: na celkovem stropu bez skillu se zamkem down se rust zahodi (namEReno %s, hodnota %d)" % [str(plno), h[1].skills.value(SKILL)])
	h[1].skills.set_lock(0, 1)               # 1 = down
	var zaplaceno: Dictionary = h[0].check(h[1].serial, SKILL, 0)
	t._check(bool(zaplaceno["gained"]) and h[1].skills.value(SKILL) == 1,
		"sim.skill_gain: se skillem se zamkem down se rust zaplati (namEReno %s, hodnota %d)" % [str(zaplaceno), h[1].skills.value(SKILL)])
	t._check(h[1].skills.value(0) == 999,
		"sim.skill_gain: placeny skill klesl o 0,1 (1000 -> %d)" % h[1].skills.value(0))
	t._check(h[1].skills.total() == Const.SKILL_CAP,
		"sim.skill_gain: total zustava na stropu (namEReno %d)" % h[1].skills.total())

	# -- I) determinismus: dva behy se stejnym seedem ----------------------
	var i1 := _sestav(t, RngScript.new(12345))
	var i2 := _sestav(t, RngScript.new(12345))
	if i1.is_empty() or i2.is_empty():
		return
	i1[1].skills.set_value(SKILL, 500)
	i2[1].skills.set_value(SKILL, 500)
	var posl1 := ""
	var posl2 := ""
	for i in 300:
		if bool(i1[0].check(i1[1].serial, SKILL, 100)["gained"]):
			posl1 += "1"
		else:
			posl1 += "0"
		if bool(i2[0].check(i2[1].serial, SKILL, 100)["gained"]):
			posl2 += "1"
		else:
			posl2 += "0"
	t._check(posl1 == posl2,
		"sim.skill_gain: dva behy se stejnym seedem daji stejnou posloupnost (rozdil na indexu %d)" % _prvni_rozdil(posl1, posl2))
	t._check(i1[1].skills.value(SKILL) == i2[1].skills.value(SKILL),
		"sim.skill_gain: po 300 pokusech stejna hodnota (%d vs %d)" % [i1[1].skills.value(SKILL), i2[1].skills.value(SKILL)])
	t._check(posl1.count("1") > 0 and posl1.count("0") > 0,
		"sim.skill_gain: posloupnost neni trivialni - rust %d z 300" % posl1.count("1"))

	# -- J) stat gain: sance a prodleva z data/balance.json -----------------
	var bal = Lib.json_at("res://data/balance.json")
	var sg_data: Dictionary = bal.get("stat_gain", {}) if bal is Dictionary else {}
	t._check(bal is Dictionary and bool(bal.get("ggs_on", false))
		and int(sg_data.get("delay_ms", 0)) == 2000 and int(sg_data.get("chance_percent", 0)) == 25,
		"data/balance.json: ggs_on = true a stat_gain = 2000 ms / 25 %% (namEReno %s)" % str(sg_data))
	var j := _sestav(t, FakeRng.new())
	if j.is_empty():
		return
	var j_rng: FakeRng = j[5]
	j_rng.default_result = true
	var j_mob = j[1]
	var j_sg = j[0]
	var j_clock = j[3]
	t._check(j_mob.stats.str_ == 10 and j_mob.stats.dex == 10 and j_mob.stats.int_ == 10,
		"sim.skill_gain: testovaci stav - staty 10/10/10 (namEReno %d/%d/%d)" % [j_mob.stats.str_, j_mob.stats.dex, j_mob.stats.int_])
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 11, "sim.skill_gain: gain_stat(STR) zvedne silu (10 -> %d)" % j_mob.stats.str_)
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 11, "sim.skill_gain: druhe volani hned po sobe nic nezvedne - prodleva 2000 ms (namEReno %d)" % j_mob.stats.str_)
	j_clock.advance(1999)
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 11, "sim.skill_gain: po 1999 ms prodleva jeste plati (namEReno %d)" % j_mob.stats.str_)
	j_clock.advance(1)
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 12, "sim.skill_gain: po 2000 ms se stat zvedne (namEReno %d)" % j_mob.stats.str_)
	j_clock.advance(2000)
	j_rng.results = [false]
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 12, "sim.skill_gain: kdyz sance nepadne, stat neroste (namEReno %d)" % j_mob.stats.str_)
	j_rng.results = []
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 13, "sim.skill_gain: minuty hod prodlevu NEnastavi - dalsi volani zvedne (namEReno %d)" % j_mob.stats.str_)
	j_mob.stats.str_ = 125
	j_clock.advance(2000)
	j_sg.gain_stat(j_mob.serial, STAT_STR)
	t._check(j_mob.stats.str_ == 125, "sim.skill_gain: nad individualni cap 125 se stat nezvedne (namEReno %d)" % j_mob.stats.str_)
	var pred_total: int = j_mob.stats.stat_total()
	j_sg.gain_stat(j_mob.serial, 9)
	t._check(j_mob.stats.stat_total() == pred_total, "sim.skill_gain: nezname cislo statu nic nezmeni (namEReno %d)" % j_mob.stats.stat_total())
	j_sg.gain_stat(0x40009999, STAT_STR)
	var nez: Dictionary = j_sg.check(0x40009999, SKILL, 0)
	t._check(j_sg.mobile(0x40009999) == null and not bool(nez["gained"]) and str(nez["reason"]) == "no_mobile",
		"sim.skill_gain: nezaregistrovany serial vraci null a reason no_mobile (namEReno %s)" % str(nez))

	# -- K) celkovy stat cap 225: staty se PRESOUVAJI (atrofie) ------------
	var k := _sestav(t, FakeRng.new())
	if k.is_empty():
		return
	var k_rng: FakeRng = k[5]
	k_rng.default_result = true
	var k_mob = k[1]
	k_mob.stats.str_ = 100
	k_mob.stats.dex = 100
	k_mob.stats.int_ = 25
	t._check(k_mob.stats.stat_total() == Const.STAT_CAP,
		"sim.skill_gain: testovaci stav - stat_total == STAT_CAP z core/const.gd (%d, namEReno %d)" % [Const.STAT_CAP, k_mob.stats.stat_total()])
	k[0].gain_stat(k_mob.serial, STAT_STR)
	t._check(k_mob.stats.str_ == 101 and k_mob.stats.int_ == 24 and k_mob.stats.stat_total() == Const.STAT_CAP,
		"sim.skill_gain: na celkovem capu se stat presune (STR 100 -> %d, INT 25 -> %d, total %d)" % [k_mob.stats.str_, k_mob.stats.int_, k_mob.stats.stat_total()])
	t._check(k_mob.max_hp == k_mob.stats.hits_max() and k_mob.max_stam == k_mob.stats.stam_max() and k_mob.max_mana == k_mob.stats.mana_max(),
		"sim.skill_gain: maxima se po zisku statu prepoctou (max_hp %d, hits_max %d)" % [k_mob.max_hp, k_mob.stats.hits_max()])

	# -- L) udalost skill_changed (smlouva udalosti docs/04 §4.2) -----------
	var l := _sestav(t, FakeRng.new())
	if l.is_empty():
		return
	l[0].check(l[1].serial, SKILL, 0)
	var data: Dictionary = {}
	for udalost in l[2].drain():
		if str(udalost["name"]) == "skill_changed":
			data = udalost["data"]
	t._check(not data.is_empty() and int(data.get("skill", -1)) == SKILL and int(data.get("value", 0)) == 1
		and int(data.get("total", 0)) == 1 and int(data.get("cap", 0)) == 1000,
		"sim.skill_gain: event skill_changed = {skill, value, total, cap} (namEReno %s)" % str(data))

	# Sentinel: case musi dojit az sem. Kdyby se `run()` prerusil na runtime
	# chybe, sada by hlasila mene kontrol (a to je videt jen proti tomuhle
	# radku a proti poctu kontrol v reportu).
	t._check(true, "sim.skill_gain: case probehl cely (sentinel)")
