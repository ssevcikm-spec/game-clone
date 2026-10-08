extends Node
# Smycka hry: JEDINE misto, kde se potkava cas enginu a cas simulace
# (docs/04 §4.2). Fixni krok 50 ms; kdyz FPS poklesne, ticky se dohani,
# ale maximalne 5 za frame - aby se sim nezasekla ve smycce dohaneni
# (prompt granule).
#
# `extends Node` je vyjmecne zde: smycka potrebuje frame callback enginu
# (docs/02 §2.6.2 dovoluje Node nebo RefCounted s uvedenim duvodu).
# Herni pravidla tu NEJSOU - jen pumpovani tiku a prevod vstupu na Command.

const Const = preload("res://core/const.gd")

const MAX_CATCHUP_TICKS: int = 5
const REPORT_EVERY_TICKS: int = 20   # 1x za sekundu herniho casu (M0: "simulace tickuje")

var sim = null
var input_map = null
var journal = null              # `ui.journal` (16. session): zpravy dostava VSTUPEM
var camera_offset: Vector2 = Vector2.ZERO
var player_tile: Vector2i = Vector2i.ZERO
# ⚠ 20. session: VYSKA HRACE pro prepočet kliku na dlazdici. Do teto session
# chodil do `input_map.poll` i `click_at`/`interact_command` jako `z = 0`, coz
# na vysce (Britain z = 10) posune cil o 40 px - stejna vada, jakou u stredu pro
# smer z mysi opravila V14. Plni ji `app/player_controller._follow()`.
var player_z: int = 0

var _accumulator_ms: float = 0.0
var _ticks: int = 0


func _process(delta: float) -> void:
	if sim == null:
		return
	_accumulator_ms += delta * 1000.0
	var done: int = 0
	while _accumulator_ms >= float(Const.TICK_MS) and done < MAX_CATCHUP_TICKS:
		if input_map != null:
			# ⚠ CAS VSTUPU JE CAS SIMULACE, ne nastenny (namEReno 2026-10-07,
			# vada V1 z `REVIZE-POHYB-2026-10-07.md` §2.1). Prodleva kroku
			# (400/200 ms) je pravidlo SIMULACE; kdyz se merila nastenami
			# hodinami vzorkovanymi po framech (27 FPS = 37 ms), vychazela
			# kadence 430 ms misto 400 a byla rozhozene. `sim.world_time()`
			# tiká presne po 50 ms, takze krok vychazi na 8 tiku presne.
			for command in input_map.poll(player_tile, camera_offset, player_z,
					get_viewport().get_mouse_position(), sim.world_time()):
				sim.enqueue(command)
		sim.tick(Const.TICK_MS)
		_accumulator_ms -= float(Const.TICK_MS)
		_ticks += 1
		done += 1
		if _ticks % REPORT_EVERY_TICKS == 0:
			print("[loop] tick ", _ticks, " (", sim.world_time(), " ms herniho casu)")
	if done >= MAX_CATCHUP_TICKS:
		# Zbytek se zahodi - dohanet hodiny tiku v jednom frame nema smysl.
		_accumulator_ms = 0.0
	_deliver_events()


func tick_count() -> int:
	return _ticks


func _deliver_events() -> void:
	# Udalosti si klient vybere jednou za frame (docs/04 §4.4). Zpravy dostava
	# zurnal VSTUPEM (`ui.journal` je tenky klient, docs/04 §4.1); `print`
	# zustava, protoze je to jedine mereni, ktere je videt v CI (G11).
	var snapshot: Dictionary = sim.snapshot()
	for event in snapshot.get("events", []):
		if journal != null:
			journal.apply_event(event)
		if event.get("name") == "message":
			print("[sim] ", str(event.get("data", {}).get("text", "")))
