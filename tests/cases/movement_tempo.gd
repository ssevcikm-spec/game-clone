extends RefCounted
# sim.movement - TEMPO KROKU JE Z DAT, ne zamrzle pravidlo (rozhodnuti `M1`,
# 2026-10-10; docs/05 §5.1.1 a §5.1.4; ROZHODNUTI-2026-10-10-MODERNI-UO.md).
#
# Test meri CHOVANI s konkretnimi hodnotami (docs/09 §9.5), ne pritomnost klice:
#   * vychozi hodnoty z REPO dat (`data/balance.json: movement.walk_ms/run_ms`)
#     jsou 400/200 ms - tedy se zapnutim datoveho klice se chovani NEMENI,
#   * kdyz data reknou 350/175, `delay_ms_for` i `request_step` vrati 350/175
#     (datova cesta je opravdu prectena, ne ignorovana),
#   * chybejici soubor = zpetna kompatibilita: vrati se vychozi hodnoty
#     z `core/const.gd` (400/200),
#   * castecna data (`jen walk_ms`) nechaji beh na vychozi hodnote,
#   * nesmyslna hodnota (0 nebo zaporna) se IGNORUJE a plati vychozi -
#     nula by jinak znamenala krok za 0 ms (tj. teleport).
#
# PROC TO TEST EXISTUJE: `M1` zmenil vetu „prodleva kroku je pravidlo simulace
# a nemENI se" na „je to laditelna vychozi hodnota". Bez testu by se datova
# cesta mohla tise rozbit (klik v datech by nic nedelal) a nikdo by si toho
# nevsiml - proto se meri i to, ze se hodnota opravdu PROJEVÍ v `request_step`.
#
# Cesta k souboru je VSTUP: `-- --movement-script=<cesta>`.

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const Const = preload("res://core/const.gd")

const MOVEMENT_SCRIPT := "res://sim/systems/movement.gd"
const TEMP_OK := "user://test_movement_tempo.json"
const TEMP_PARTIAL := "user://test_movement_tempo_cast.json"
const TEMP_INVALID := "user://test_movement_tempo_vadne.json"
const TEMP_MISSING := "user://test_movement_tempo_neexistuje.json"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeWalk:
	func can_step(_from: Vector3i, _dir: int, _height: int, _is_player: bool) -> Dictionary:
		return {"ok": true, "z": 0, "reason": ""}


func _zapis(cesta: String, obsah: String) -> bool:
	var f = FileAccess.open(cesta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(obsah)
	f.close()
	return true


func _system(script, cesta: String) -> Array:
	# Vraci [mv, mob]; `cesta` je soubor s daty (nebo neexistujici cesta).
	var clock = ClockScript.new()
	var mv = script.new(FakeWalk.new(), clock, EventsScript.new(), "", null, cesta)
	var mob = MobileScript.new(0x40000001, 400, Vector3i(5, 5, 0))
	mv.player_serial = mob.serial
	mv.register(mob)
	return [mv, clock, mob]


func run(t) -> void:
	var cesta: String = _arg("movement-script", MOVEMENT_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		# SELHAT, ne jen `_pending`: chybějící `sim.movement` je vada a mutační
		# harness to pozná jen podle FAIL řádku s prefixem "tempo:" (docs/09
		# §9.5: soubor, který součástí být MÁ, musí selhat - ne se přeskočit).
		t._check(false, "tempo: sim.movement NENI HOTOVA: " + cesta + " chybi")
		return

	# 1) Vychozi hodnoty: repo data maji 400/200, takze se chovani NEMENI.
	var d = _system(script, "res://data/balance.json")
	var mv = d[0]
	t._check(mv.delay_ms_for(false) == Const.WALK_MS,
		"tempo: chuze z repo dat je %d ms (namEReno %d)"
			% [Const.WALK_MS, mv.delay_ms_for(false)])
	t._check(mv.delay_ms_for(true) == Const.RUN_MS,
		"tempo: beh z repo dat je %d ms (namEReno %d)"
			% [Const.RUN_MS, mv.delay_ms_for(true)])

	# 2) Data rozhoduji: 350/175 se musi projevit i v `request_step`.
	if not _zapis(TEMP_OK, '{"stamina_drain_model":"never","movement":{"walk_ms":350,"run_ms":175}}'):
		t._pending("tempo: nelze zapsat " + TEMP_OK + " (user:// neni zapisovatelne)")
		return
	var d2 = _system(script, TEMP_OK)
	var mv2 = d2[0]
	var mob2 = d2[2]
	t._check(mv2.delay_ms_for(false) == 350,
		"tempo: walk_ms z dat je 350 (namEReno %d)" % mv2.delay_ms_for(false))
	t._check(mv2.delay_ms_for(true) == 175,
		"tempo: run_ms z dat je 175 (namEReno %d)" % mv2.delay_ms_for(true))
	var krok: Dictionary = mv2.request_step(mob2.serial, 0, false)
	t._check(int(krok.get("delay_ms", -1)) == 350,
		"tempo: request_step vraci prodlevu z dat (namEReno %s)" % str(krok))
	t._check(int(mv2.pending_step(mob2.serial).get("delay_ms", -1)) == 350,
		"tempo: pending_step nese prodlevu z dat (namEReno %s)"
			% str(mv2.pending_step(mob2.serial)))

	# 3) Castecna data: chybejici `run_ms` necha beh na vychozi hodnote.
	if _zapis(TEMP_PARTIAL, '{"movement":{"walk_ms":300}}'):
		var d3 = _system(script, TEMP_PARTIAL)
		var mv3 = d3[0]
		t._check(mv3.delay_ms_for(false) == 300 and mv3.delay_ms_for(true) == Const.RUN_MS,
			"tempo: castecna data = walk 300, beh vychozi %d (namEReno %d/%d)"
				% [Const.RUN_MS, mv3.delay_ms_for(false), mv3.delay_ms_for(true)])
	else:
		t._pending("tempo: nelze zapsat " + TEMP_PARTIAL)

	# 4) Nesmyslna hodnota se ignoruje (nula by znamenala krok za 0 ms).
	if _zapis(TEMP_INVALID, '{"movement":{"walk_ms":0,"run_ms":-5}}'):
		var d4 = _system(script, TEMP_INVALID)
		var mv4 = d4[0]
		t._check(mv4.delay_ms_for(false) == Const.WALK_MS
				and mv4.delay_ms_for(true) == Const.RUN_MS,
			"tempo: nula/zaporna hodnota se ignoruje, plati vychozi %d/%d (namEReno %d/%d)"
				% [Const.WALK_MS, Const.RUN_MS, mv4.delay_ms_for(false), mv4.delay_ms_for(true)])
	else:
		t._pending("tempo: nelze zapsat " + TEMP_INVALID)

	# 5) Chybejici soubor = zpetna kompatibilita (stare fixtury, bez dat).
	var d5 = _system(script, TEMP_MISSING)
	var mv5 = d5[0]
	t._check(mv5.delay_ms_for(false) == Const.WALK_MS
			and mv5.delay_ms_for(true) == Const.RUN_MS,
		"tempo: chybejici data = vychozi hodnoty %d/%d (namEReno %d/%d)"
			% [Const.WALK_MS, Const.RUN_MS, mv5.delay_ms_for(false), mv5.delay_ms_for(true)])
