extends RefCounted
# app.loop - smycka: fixni krok 50 ms a dohaneni max 5 tiku za frame
# (prompt granule, docs/04 §4.2). `_process` se vola rucne, takze test meri
# presne to, co smycka dela, a ne to, co dela engine.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://app/loop.gd")
	if script == null:
		t._pending("app.loop NENI HOTOVA: app/loop.gd chybi")
		return
	var sim_script = Lib.script_at("res://sim/sim_world.gd")
	if sim_script == null:
		t._pending("app.loop: chybi sim/sim_world.gd")
		return

	var loop = script.new()
	t._check(loop != null, "app.loop: komponentu jde vytvorit")
	loop.sim = sim_script.new(5, {})

	# 1) presne 50 ms = jeden tick
	loop._process(0.05)
	t._check(loop.tick_count() == 1, "app.loop: frame 50 ms = 1 tick (namEReno %d)" % loop.tick_count())
	t._check(loop.sim.world_time() == 50, "app.loop: sim posunula cas na 50 ms")

	# 2) 100 ms = dva ticky
	loop._process(0.1)
	t._check(loop.tick_count() == 3, "app.loop: dalsích 100 ms = 2 ticky (namEReno %d)" % loop.tick_count())

	# 3) velky propad FPS: dozene se jen 5 tiku za frame
	var before: int = loop.tick_count()
	loop._process(1.0)
	t._check(loop.tick_count() - before == 5,
		"app.loop: propad 1000 ms dozene jen 5 tiku (namEReno %d)" % (loop.tick_count() - before))

	# 4) zbytek se zahodi - dalsi maly frame uz nesmi dohanet stary dluh
	var after_catchup: int = loop.tick_count()
	loop._process(0.01)
	t._check(loop.tick_count() == after_catchup,
		"app.loop: po dohnani se zbytek zahodi (namEReno %d tiku navic)" % (loop.tick_count() - after_catchup))

	# 5) bez sim smycka nespadne a netickuje
	var empty = script.new()
	empty._process(0.05)
	t._check(empty.tick_count() == 0, "app.loop: bez sim se netickuje a nic nespadne")
