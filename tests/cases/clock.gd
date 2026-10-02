extends RefCounted
# core.clock - herni hodiny a timery (docs/04 §4.2).
# Kriterium z promptu granule: timer na 400 ms se spusti presne po 8 ticcich po 50 ms.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://core/clock.gd")
	if script == null:
		t._pending("core.clock NENI HOTOVA: core/clock.gd chybi")
		return
	var clock = script.new()
	var fired: Array = []
	t._check(clock.now_ms() == 0, "core.clock: now_ms() na startu je 0")
	var id: int = clock.after(400, func() -> void: fired.append(clock.now_ms()))
	t._check(id > 0, "core.clock: after() vraci kladne id")

	for i in 7:
		clock.advance(50)
	t._check(fired.is_empty(), "core.clock: po 7 ticcich (350 ms) timer na 400 ms jeste nebezi")
	clock.advance(50)
	t._check(clock.now_ms() == 400, "core.clock: now_ms() == 400 po 8 ticcich (namEReno %d)" % clock.now_ms())
	t._check(fired == [400], "core.clock: spustil se presne jednou a v case 400 (namEReno %s)" % str(fired))
	clock.advance(50)
	t._check(fired.size() == 1, "core.clock: timer se neopakuje")

	var order: Array = []
	clock.after(50, func() -> void: order.append("a"))
	clock.after(50, func() -> void: order.append("b"))
	clock.advance(50)
	t._check(order == ["a", "b"],
		"core.clock: timery se stejnym casem jdou v poradi id (namEReno %s)" % str(order))

	var cancelled: Array = [false]
	var cid: int = clock.after(10, func() -> void: cancelled[0] = true)
	clock.cancel(cid)
	clock.advance(100)
	t._check(cancelled[0] == false, "core.clock: cancel() timer zrusi")

	# callback, ktery si naplanuje 0 ms timer, se stihne ve stejnem kroku
	var chain: Array = []
	var clock2 = script.new()
	clock2.after(50, func() -> void:
		chain.append("first")
		clock2.after(0, func() -> void: chain.append("second")))
	clock2.advance(50)
	t._check(chain == ["first", "second"],
		"core.clock: 0ms timer z callbacku se spusti ve stejnem kroku (namEReno %s)" % str(chain))
