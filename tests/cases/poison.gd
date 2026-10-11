extends RefCounted
# sim.poison - jed (docs/04 §4.2, docs/05 §5.14).
#
# Cisla jsou namERena v `_src/servuo/Scripts/Misc/Poison.cs:23-27` (AoS vetev)
# a test je meri PRESNE - vcetne toho, ze skoda ZAVISI NA ZIVOTECH obete
# (`damage = 1 + (int)(hits * scalar)`, `Poison.cs:170` a `:222`):
#
#   uroven | jmeno   | min | max | scalar | interval | skoda pri 100 hp
#   -------|---------|-----|-----|--------|----------|-----------------
#     0    | Lesser  |  4  | 16  | 0.075  | 2250 ms  |  8
#     1    | Regular |  8  | 18  | 0.10   | 3250 ms  | 11
#     2    | Greater | 12  | 20  | 0.15   | 4250 ms  | 16
#     3    | Deadly  | 16  | 30  | 0.30   | 5250 ms  | 30 (strop)
#     4    | Lethal  | 20  | 50  | 0.35   | 5250 ms  | 36
#
# Test meri take to, ze se jed NEDOSTANE na uroven, kterou obet uz ma vyssi,
# ze `cure` ho zrusi a ze stav prezije `state()`/`restore()`.
#
# Cesta k souboru je VSTUP: `-- --poison-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")

const POISON_SCRIPT := "res://sim/systems/poison.gd"
const SERIAL := 0x40000031
const DELAY_MS := 3000
const INTERVALY := [2250, 3250, 4250, 5250, 5250]
const SKODY_100HP := [8, 11, 16, 30, 36]
const JMENA := ["Lesser", "Regular", "Greater", "Deadly", "Lethal"]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _mobil(registry, hp: int):
	var mob = MobileScript.new(SERIAL, 400, Vector3i(5, 5, 0))
	mob.max_hp = hp
	mob.hp = hp
	registry.register(mob)
	return mob


func _ref_dano(level: int, hits: int) -> int:
	# NEZAVISLA reference vzorce z `_src/servuo/Scripts/Misc/Poison.cs:222-227`:
	# `damage = 1 + (int)(Hits * Scalar)`, pak clamp na [min, max]. `Hits` jsou
	# AKTUALNI zivoty obete (BODY, ne desetiny) - proto se skoda v case meni.
	# Test ji pouziva pro OCEKAVANI; modul se meri zvlast (`damage_for`).
	var scalar := [0.075, 0.10, 0.15, 0.30, 0.35]
	var mn := [4, 8, 12, 16, 20]
	var mx := [16, 18, 20, 30, 50]
	return clampi(1 + int(float(hits) * float(scalar[level])), int(mn[level]), int(mx[level]))


func run(t) -> void:
	var cesta: String = _arg("poison-script", POISON_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.poison NENI HOTOVY: " + cesta + " chybi nebo se neparsuje")
		return

	# -- A) TABULKA: intervaly, skody a jmena -----------------------------
	var registry = RegistryScript.new()
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var poison = script.new(registry, null, clock, events)
	for lvl in 5:
		t._check(poison.interval_ms(int(lvl)) == int(INTERVALY[lvl]),
			"uroven %d: interval %d ms (je %d)" % [lvl, int(INTERVALY[lvl]), poison.interval_ms(int(lvl))])
		t._check(poison.delay_ms(int(lvl)) == DELAY_MS,
			"uroven %d: prvni tik po %d ms" % [lvl, DELAY_MS])
		t._check(poison.name_of(int(lvl)) == str(JMENA[lvl]),
			"uroven %d: jmeno '%s' (je '%s')" % [lvl, str(JMENA[lvl]), poison.name_of(int(lvl))])
		t._check(poison.damage_for(int(lvl), 100) == int(SKODY_100HP[lvl]),
			"uroven %d pri 100 hp: skoda %d (je %d)"
			% [lvl, int(SKODY_100HP[lvl]), poison.damage_for(int(lvl), 100)])
		# min/max z tabulky (docs/05 §5.14: "damage na tik s clampem [min,max]").
		t._check(poison.min_damage(int(lvl)) > 0, "uroven %d ma min > 0" % lvl)
		t._check(poison.max_damage(int(lvl)) >= poison.min_damage(int(lvl)),
			"uroven %d: max >= min" % lvl)
	# Clamp: pri 1 hp je skoda MIN, pri 100000 hp je MAX.
	t._check(poison.damage_for(0, 1) == poison.min_damage(0),
		"clamp dolu: pri 1 hp je skoda min (%d)" % poison.damage_for(0, 1))
	t._check(poison.damage_for(0, 100000) == poison.max_damage(0),
		"clamp nahoru: pri 100000 hp je skoda max (%d)" % poison.damage_for(0, 100000))
	t._check(poison.damage_for(4, 100000) == 50,
		"Lethal ma strop 50 (je %d)" % poison.damage_for(4, 100000))

	# -- B) APPLY + TIK: prvni tik po 3 s, pak interval -------------------
	# Cil ma PRESNE 100 hp, takze skoda na tik je hodnota ze tabulky
	# (`1 + int(100 * scalar)`, `Poison.cs:170`) - pri 1000 hp by se uplatnil
	# strop a merilo by se neco jineho.
	var mob = _mobil(registry, 100)
	var r: Dictionary = poison.apply(SERIAL, 0)
	t._check(bool(r.get("ok", false)), "apply(0) vraci ok")
	t._check(int(r.get("level", -1)) == 0, "apply hlasi level 0")
	t._check(int(r.get("duration_ms", 0)) == (10 + 1) * 2250,
		"duration = (hits+1)*interval = %d (je %d)" % [(10 + 1) * 2250, int(r.get("duration_ms", 0))])
	t._check(poison.is_poisoned(SERIAL), "po apply je mobil otráven")
	t._check(poison.level_of(SERIAL) == 0, "level_of == 0")
	clock.advance(DELAY_MS - 1)
	var tiky: int = poison.tick(0)
	t._check(tiky == 0, "po 2999 ms jed jeste netika (tiku %d)" % tiky)
	t._check(int(mob.hp) == 100, "hp se pred prvnim tikem nemeni")
	clock.advance(1)
	tiky = poison.tick(0)
	t._check(tiky == 1, "po 3000 ms jed tikne jednou (tiku %d)" % tiky)
	var hp1: int = 100 - _ref_dano(0, 100)
	t._check(int(mob.hp) == hp1,
		"hp po prvnim tiku je %d (je %d)" % [hp1, int(mob.hp)])
	# Druhy tik po presne jednom intervalu. Skoda se pocita z AKTUALNICH hp
	# (`Poison.cs:222`), takze pri 92 hp je to 7, ne 8 - proto nezavisla
	# reference, ne opsana hodnota z tabulky "pri 100 hp".
	clock.advance(INTERVALY[0] - 1)
	t._check(poison.tick(0) == 0, "pred druhym tikem se nic nedeje")
	clock.advance(1)
	t._check(poison.tick(0) == 1, "druhy tik prisel po intervalu %d" % int(INTERVALY[0]))
	var hp2: int = hp1 - _ref_dano(0, hp1)
	t._check(int(mob.hp) == hp2,
		"hp po druhem tiku je %d (je %d; skoda 2. tiku %d)"
			% [hp2, int(mob.hp), _ref_dano(0, hp1)])

	# -- C) CURE: jed se zrusi a prestane tikat --------------------------
	var c: Dictionary = poison.cure(SERIAL)
	t._check(bool(c.get("ok", false)) and bool(c.get("was_poisoned", false)),
		"cure vraci ok a was_poisoned")
	t._check(not poison.is_poisoned(SERIAL), "po cure uz mobil neni otráven")
	t._check(poison.level_of(SERIAL) == -1, "level_of po cure je -1")
	var hp_pred: int = int(mob.hp)
	clock.advance(60000)
	t._check(poison.tick(0) == 0, "po cure jed netika")
	t._check(int(mob.hp) == hp_pred, "po cure se hp nemeni")

	# -- D) SLABSI JED NEPREBIJE SILNEJSI --------------------------------
	# Dva mobily: na jednom se overi, ze silnejsi uroven PREBIJE slabsi, na
	# druhem ze slabsi uroven nezmeni NIC (`reason:"weaker"`).
	var mobA = MobileScript.new(SERIAL + 1, 400, Vector3i(5, 5, 0))
	mobA.max_hp = 500
	mobA.hp = 500
	registry.register(mobA)
	t._check(bool(poison.apply(SERIAL + 1, 0).get("ok", false)), "apply(0) na mobA")
	t._check(poison.level_of(SERIAL + 1) == 0, "mobA ma uroven 0")
	var r2: Dictionary = poison.apply(SERIAL + 1, 2)
	t._check(bool(r2.get("ok", false)), "silnejsi jed (2) se aplikuje")
	t._check(poison.level_of(SERIAL + 1) == 2, "silnejsi jed uroven prebil")

	var mobB = MobileScript.new(SERIAL + 4, 400, Vector3i(5, 5, 0))
	mobB.max_hp = 500
	mobB.hp = 500
	registry.register(mobB)
	var r4: Dictionary = poison.apply(SERIAL + 4, 4)
	t._check(bool(r4.get("ok", false)), "apply(4) vraci ok")
	t._check(poison.level_of(SERIAL + 4) == 4, "level_of == 4")
	var r0: Dictionary = poison.apply(SERIAL + 4, 0)
	t._check(not bool(r0.get("ok", false)) and str(r0.get("reason", "")) == "weaker",
		"slabsi jed vraci weaker (je '%s')" % str(r0.get("reason", "")))
	t._check(poison.level_of(SERIAL + 4) == 4, "slabsi jed uroven nezmenil")

	# -- E) MRTVY MOBIL: jed se neaplikuje -------------------------------
	var mrtvy = MobileScript.new(SERIAL + 2, 400, Vector3i(1, 1, 0))
	mrtvy.max_hp = 10
	mrtvy.hp = 0
	registry.register(mrtvy)
	var r5: Dictionary = poison.apply(SERIAL + 2, 1)
	t._check(not bool(r5.get("ok", false)) and str(r5.get("reason", "")) == "dead",
		"na mrtveho se jed neaplikuje (je '%s')" % str(r5.get("reason", "")))

	# -- F) SMRT JEDEM: hp <= 0 a jed se uklidi ---------------------------
	var mob3 = MobileScript.new(SERIAL + 3, 400, Vector3i(1, 1, 0))
	mob3.max_hp = 50
	mob3.hp = 5
	registry.register(mob3)
	poison.apply(SERIAL + 3, 4)
	clock.advance(DELAY_MS)
	poison.tick(0)
	t._check(int(mob3.hp) == 0, "jed zabil mobily s 5 hp (hp %d)" % int(mob3.hp))
	t._check(not poison.is_poisoned(SERIAL + 3), "po smrti se jed uklidil")

	# -- G) STATE/RESTORE ROUND-TRIP -------------------------------------
	var stav: Dictionary = poison.state()
	var poison2 = script.new(registry, null, clock, EventsScript.new())
	poison2.restore(stav)
	t._check(poison2.active_count() == poison.active_count(),
		"poison state/restore: stejny pocet otrávenych (%d vs %d)"
		% [poison2.active_count(), poison.active_count()])
	t._check(poison2.level_of(SERIAL + 1) == poison.level_of(SERIAL + 1),
		"poison state/restore: stejna uroven")

	# -- H) EVENTY: message + poison -------------------------------------
	var registry3 = RegistryScript.new()
	var clock3 = ClockScript.new()
	var events3 = EventsScript.new()
	var poison3 = script.new(registry3, null, clock3, events3)
	var mob5 = MobileScript.new(SERIAL + 9, 400, Vector3i(1, 1, 0))
	mob5.max_hp = 200
	mob5.hp = 200
	registry3.register(mob5)
	poison3.apply(SERIAL + 9, 1)
	clock3.advance(DELAY_MS)
	poison3.tick(0)
	var jmena: Array = []
	for e in events3.drain():
		jmena.append(str(e["name"]))
	t._check(jmena.has("message"), "jed posle message (%s)" % str(jmena))
	t._check(jmena.has("poison"), "jed posle udalost poison (%s)" % str(jmena))
	t._check(jmena.has("stats_changed"), "jed posle stats_changed (%s)" % str(jmena))

	# -- I) JED 3. UROVNE UMBERE HP DO 10 s (prijimaci kriterium) ---------
	# Uroven 3 = Deadly: prvni tik po 3 s, pak kazdych 5,25 s - do 10 s tedy
	# DVA tiky. Mob ma 1000 hp, takze se uplatni strop 30 (a druhy tik je
	# znovu 30, protoze 970*0,30+1 > 30).
	var reg4 = RegistryScript.new()
	var clk4 = ClockScript.new()
	var poison4 = script.new(reg4, null, clk4, EventsScript.new())
	var mob6 = MobileScript.new(SERIAL + 10, 400, Vector3i(5, 5, 0))
	mob6.max_hp = 1000
	mob6.hp = 1000
	reg4.register(mob6)
	var r6: Dictionary = poison4.apply(SERIAL + 10, 3)
	t._check(bool(r6.get("ok", false)) and int(r6.get("level", -1)) == 3,
		"apply(3) vraci ok (level %d)" % int(r6.get("level", -1)))
	var hp6: int = 1000
	var tiky10 := 0
	var i6 := 0
	while i6 < 100 and clk4.now_ms() < 10000:
		clk4.advance(100)
		tiky10 += poison4.tick(0)
		i6 += 1
	t._check(tiky10 == 2, "uroven 3 tikne do 10 s dvakrat (tiku %d)" % tiky10)
	hp6 -= _ref_dano(3, hp6)
	hp6 -= _ref_dano(3, hp6)
	t._check(int(mob6.hp) == hp6,
		"uroven 3 ubere hp do 10 s: 1000 -> %d (je %d)" % [hp6, int(mob6.hp)])
	t._check(int(mob6.hp) < 1000, "jed 3. urovne ubere hp do 10 s (hp %d)" % int(mob6.hp))

	# -- J) CURE(m, level): lecba sily N vyleci jed <= N -------------------
	var rc1: Dictionary = poison4.cure(SERIAL + 10, 1)
	t._check(not bool(rc1.get("ok", false)) and str(rc1.get("reason", "")) == "too_strong",
		"cure(sila 1) na jed 3 vraci too_strong ('%s')" % str(rc1.get("reason", "")))
	t._check(poison4.is_poisoned(SERIAL + 10), "po odmitnute lecbe je mobil porad otráven")
	var rc2: Dictionary = poison4.cure(SERIAL + 10, 3)
	t._check(bool(rc2.get("ok", false)) and not poison4.is_poisoned(SERIAL + 10),
		"cure(sila 3) jed 3. urovne vyleci")
	var rc3: Dictionary = poison4.cure(SERIAL + 10)
	t._check(bool(rc3.get("ok", false)) and not bool(rc3.get("was_poisoned", true)),
		"cure bez sily (vychozi) nic nezmeni, kdyz jed neni")
