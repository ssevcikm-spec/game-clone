extends RefCounted
# sim.scheduler - ridke udalosti sveta (granule `sim.scheduler`, milnik MK).
#
# Kriterium z promptu granule: tri udalosti ve stejne ms se vyrizi v poradi
# vlozeni; `cancel` nevyrizi nic; `state()`/`restore()` da stejne budouci
# chovani; dve stejne sekvence daji stejne poradi.
#
# ⚠ Co tenhle case NEMERI (aby se zelena neprecenila): ze by udalosti
# vyrizoval nekdo jiny nez `advance_to` (napr. `core.clock`), a chovani pri
# prekroceni `MAX_EVENTS_PER_ADVANCE` (10 000 udalosti v jednom kroku by pri
# O(n) hledani znamenalo O(n^2) - case by bezel minuty, ne sekundy).

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var sched_script = Lib.script_at("res://sim/scheduler.gd")
	if sched_script == null:
		t._pending("sim.scheduler NENI HOTOVA: sim/scheduler.gd chybi")
		return
	var clock_script = Lib.script_at("res://core/clock.gd")
	if clock_script == null:
		t._pending("sim.scheduler: chybi core/clock.gd (cas sveta)")
		return

	var clock = clock_script.new()
	var sch = sched_script.new(clock)

	t._check(sch.pending() == 0, "sim.scheduler: na startu neceka zadna udalost")
	var id_a: int = sch.schedule("a", 100)
	t._check(id_a > 0, "sim.scheduler: schedule() vraci kladne id")
	t._check(sch.pending() == 1, "sim.scheduler: po naplanovani ceka 1 udalost (namEReno %d)" % sch.pending())

	var before: Array = sch.advance_to(99)
	t._check(before.is_empty(), "sim.scheduler: udalost na 100 ms se v case 99 nevyrize (namEReno %s)" % str(before))
	t._check(sch.pending() == 1, "sim.scheduler: nevyrizena udalost zustava ve fronte")

	var due: Array = sch.advance_to(100)
	t._check(due.size() == 1, "sim.scheduler: udalost na 100 ms se v case 100 vyrize (namEReno %d)" % due.size())
	t._check(not due.is_empty() and due[0]["kind"] == "a",
		"sim.scheduler: vyrizena udalost nese svuj `kind` (namEReno %s)" % str(due))
	t._check(sch.pending() == 0, "sim.scheduler: vyrizena udalost z fronty zmizi")
	t._check(sch.advance_to(100).is_empty(), "sim.scheduler: udalost se nevyrizi dvakrat")

	# -- poradi pri stejne ms je poradi vlozeni (determinismus, docs/02 §2.3)
	sch.schedule("x", 200)
	sch.schedule("y", 200)
	sch.schedule("z", 200)
	var same_ms: Array = sch.advance_to(200)
	var kinds: Array = []
	for e in same_ms:
		kinds.append(e["kind"])
	t._check(kinds == ["x", "y", "z"],
		"sim.scheduler: tri udalosti ve stejne ms jdou v poradi vlozeni (namEReno %s)" % str(kinds))

	# -- cancel
	var cancelled_id: int = sch.schedule("nikdy", 300)
	sch.cancel(cancelled_id)
	t._check(sch.pending() == 0, "sim.scheduler: cancel() snizi pocet cekajicich")
	t._check(sch.advance_to(300).is_empty(), "sim.scheduler: zrusena udalost se nevyrize")

	# -- schedule_in pocita z casu SIMULACE, ne z hodin systemu
	clock.advance(500)
	sch.schedule_in("w", 50)
	t._check(sch.advance_to(549).is_empty(), "sim.scheduler: schedule_in(50) v case 500 vyjde na 550, ne na 549")
	var in_due: Array = sch.advance_to(550)
	t._check(in_due.size() == 1 and in_due[0]["at"] == 550,
		"sim.scheduler: schedule_in pouziva cas simulace (ocekavano at=550, namEReno %s)" % str(in_due))

	# -- doběh: velky skok vyrizi, co je splatne (to potrebuje `sim.offline`)
	sch.schedule("dobeh", 600)
	var jump: Array = sch.advance_to(1000000)
	t._check(jump.size() == 1 and jump[0]["kind"] == "dobeh",
		"sim.scheduler: velky skok v case vyrizi splatnou udalost (namEReno %s)" % str(jump))

	# -- payload je DATA, ne sdileny odkaz (jinak by save/log ukazoval neco jineho)
	var shared: Dictionary = {"ore": 3}
	sch.schedule("tezba", 1100, shared)
	shared["ore"] = 99
	var payload_due: Array = sch.advance_to(1100)
	t._check(payload_due.size() == 1 and payload_due[0]["payload"]["ore"] == 3,
		"sim.scheduler: payload se ulozi jako kopie (namEReno %s)" % str(payload_due))

	# -- dve stejne sekvence daji stejne poradi
	var c1 = clock_script.new()
	var c2 = clock_script.new()
	var s1 = sched_script.new(c1)
	var s2 = sched_script.new(c2)
	for s in [s1, s2]:
		s.schedule("b", 700)
		s.schedule("a", 700)
		s.schedule("c", 650)
	var seq1: Array = []
	for e in s1.advance_to(700):
		seq1.append(e["kind"])
	var seq2: Array = []
	for e in s2.advance_to(700):
		seq2.append(e["kind"])
	t._check(seq1 == seq2, "sim.scheduler: dve stejne sekvence daji stejne poradi (%s vs %s)" % [str(seq1), str(seq2)])
	t._check(seq1 == ["c", "b", "a"], "sim.scheduler: razeni je podle casu, pri shode podle id (namEReno %s)" % str(seq1))

	# -- state()/restore() prenese BUDOUCNOST
	var s3 = sched_script.new(clock_script.new())
	s3.schedule("prvni", 8000, {"x": 1})
	s3.schedule("druhy", 8100)
	var snapshot: Dictionary = s3.state()
	var s4 = sched_script.new(clock_script.new())
	s4.restore(snapshot)
	t._check(s4.pending() == s3.pending(),
		"sim.scheduler: restore() da stejny pocet cekajicich (%d vs %d)" % [s4.pending(), s3.pending()])
	var after3: Array = []
	for e in s3.advance_to(9000):
		after3.append("%s@%d" % [e["kind"], e["at"]])
	var after4: Array = []
	for e in s4.advance_to(9000):
		after4.append("%s@%d" % [e["kind"], e["at"]])
	t._check(after3 == after4 and after3.size() == 2,
		"sim.scheduler: po restore() se vyrizi tyz budouci udalosti (%s vs %s)" % [str(after3), str(after4)])

	# -- kanonicka podoba stavu: poradi v zapisu nezávisí na poradi vlozeni
	var s5 = sched_script.new(clock_script.new())
	s5.schedule("pozde", 900)
	s5.schedule("brzy", 100)
	var rows: Array = s5.state()["events"]
	var ats: Array = []
	for row in rows:
		ats.append(row["at"])
	t._check(ats == [100, 900], "sim.scheduler: state() je serazeny podle casu (namEReno %s)" % str(ats))
