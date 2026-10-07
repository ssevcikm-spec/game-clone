extends Node2D
# Scena a start hry (docs/02 §2.5): vytvori sim, nacte data a preda rizeni
# `app/loop.gd`. HERNI PRAVIDLA TU NEJSOU (prompt granule) - jen slozeni.
#
# `SimWorld` ma sice `class_name`, ale ten je známy jen pres cache importu
# (.godot/global_script_class_cache.cfg) - v cerstvem stromu spadne parse
# ("Identifier SimWorld not declared", namEReno 2026-10-02). Proto preload
# s vlastnim jmenem, ktere s globalnim nekoliduje (docs/02 §2.6.2).
const SimScript = preload("res://sim/sim_world.gd")
const Loop = preload("res://app/loop.gd")
const InputMapScript = preload("res://app/input_map.gd")
const MapScript = preload("res://sim/world/map.gd")
const TextureCache = preload("res://render/texture_cache.gd")
const WalkScript = preload("res://sim/world/walk.gd")
const MovementScript = preload("res://sim/systems/movement.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const TimeScript = preload("res://sim/world/time.gd")
const HueScript = preload("res://render/hue_cache.gd")
# Prvni UI v projektu (11. session): `ui.hud` je CanvasLayer, ktery drzi okna
# a jejich pozice; `ui.status_bar` je prvni z nich. Oba moduly jsou hotove a
# merene (`tests/cases/hud.gd`, `tests/cases/status_bar.gd`).
const HudScript = preload("res://ui/hud.gd")
const StatusBarScript = preload("res://ui/status_bar.gd")
# Rust skillu a statu (granule `sim.skill_gain`, 11. session). Registruje se
# s RNG ze `SimWorld` - vlastni RNG by rozbil determinismus a `state_hash`.
const SkillGainScript = preload("res://sim/systems/skill_gain.gd")
# M9 (15. session): typovana konfigurace a mereni vykonu. Config se ptá na
# `data/balance.json` (kontrola typu/rozsahu), metrics sbira frame cas, pocet
# kreslenych objektu, textury a stavbu davky.
const ConfigScript = preload("res://app/config.gd")
const MetricsScript = preload("res://app/metrics.gd")

const DEFAULT_SEED: int = 1234
const BRITAIN := Vector2i(1495, 1630)   # namesti Britainu (docs/01 §1.4)
const PLAYER_BODY: int = 400            # 400 = muz (tělo je jen v anim.mul)
# Co se nacita na start. Zbytek dat (items, recipes, monsters...) pribude
# s granulemi M1+; kdyz soubor chybi, hra se musi ozvat, ne mlcet.
const DATA_FILES := {
	"balance": "res://data/balance.json",
}

var sim = null
var loop = null
var player = null
var movement = null
var registry = null
var time = null
var map = null
var controller = null
var hud = null
var status_bar = null
var config = null
var metrics = null
var world_view = null            # `app.world_view` (pro metriky)
var textures = null              # `render.textures` (pro metriky)
var _last_status_text: String = ""
var _metrics_s: float = 0.0


func _ready() -> void:
	var data: Dictionary = _load_data()
	metrics = MetricsScript.new()
	sim = SimScript.new(DEFAULT_SEED, data)
	loop = Loop.new()
	loop.sim = sim
	loop.input_map = InputMapScript.new()
	add_child(loop)
	_setup_ui()
	_setup_world()
	print("[main] sim spusten (seed ", DEFAULT_SEED, ", datovych souboru ", data.size(), ")")


func _process(_delta: float) -> void:
	# MERENI VYKONU (M9) jde PRVNI - nesmi vypadnout, kdyz jeste neni UI.
	# Cisla se berou z toho, co uz hra zna: `app.world_view.drawn`,
	# `render.textures.stats()` a `render.chunk_mesh.stats()`.
	if metrics != null:
		var davka: Dictionary = world_view.mesh_stats() if world_view != null else {}
		var textury: Dictionary = textures.stats() if textures != null else {}
		metrics.tick(_delta * 1000.0, world_view.drawn if world_view != null else 0,
			textury, davka)
		_metrics_s += _delta
		if _metrics_s >= 1.0:
			_metrics_s = 0.0
			print("[metrics] ", metrics.text())
	# Stavovy pruh se aktualizuje JEN kdyz se text zmeni (ne kazdy frame).
	# Hodnoty jdou z `entity.mobile` - `max_hp`/`max_stam`/`max_mana` plni
	# `Mobile._init` ze statu (`entity.stats`), takze nejsou opsane cisla.
	# Vaha a zlato jsou 0, dokud neni batoh s predmety (M3) - je to pravda,
	# ne "nevim": hrac dnes nic nema.
	if status_bar == null or player == null:
		return
	var values: Dictionary = {
		"name": player.name,
		"hp": player.hp, "hp_max": player.max_hp, "max_hp": player.max_hp,
		"stam": player.stam, "stam_max": player.max_stam,
		"mana": player.mana, "mana_max": player.max_mana,
		"weight": 0, "gold": 0,
	}
	var text: String = status_bar.text_for(values)
	if text == _last_status_text:
		return
	_last_status_text = text
	status_bar.update(values)


func _setup_ui() -> void:
	# Slozeni UI (zadna herni logika): HUD je koren oken, status bar prvni okno.
	# Kdyby UI chybelo, hra se o tom ozve - tiche "nic se nezobrazuje" je vada.
	hud = HudScript.new()
	add_child(hud)
	status_bar = StatusBarScript.new()
	hud.add_child(status_bar)
	if not hud.register_window("status_bar", status_bar, Vector2(8.0, 8.0)):
		push_warning("app.main: status bar se nepodarilo zaregistrovat v HUD")
	print("[main] UI: okna ", hud.layout().keys())


func _setup_world() -> void:
	# Klient (mapa + textury) je ODDELENY od simulace: `main` je jedine misto,
	# kde se potkavaji (docs/02 §2.2). Kdyz uzel ve scene chybi, rekne se to -
	# tiche "nic se nekresli" je presne vada, kterou mel projekt 2026-10-06.
	var view := get_node_or_null("WorldView")
	if view == null:
		push_warning("app.main: ve scene chybi uzel WorldView - mapa se nevykresli")
		return
	world_view = view
	map = MapScript.new()
	textures = TextureCache.new()
	view.setup(map, textures)
	print("[main] svet: ", view.visible_count(), " objektu (", view.counts(), "), textury ",
		textures.stats())
	_setup_player(view)


func _setup_player(view) -> void:
	# Poradi je dane zavislostmi (ZADANI-DALSI-VYVOJ §3 ukol 6):
	# world.walk -> entity.mobile -> sim.movement -> registrace v SimWorld.
	# Systemy se registruji TADY (integraci misto), protoze `sim/sim_world.gd`
	# je granule `sim.world_loop` a agent ji needituje.
	var walk = WalkScript.new(map)
	var serial: int = sim.next_serial()
	player = MobileScript.new(serial, PLAYER_BODY, Vector3i(BRITAIN.x, BRITAIN.y, 0))
	player.pos = Vector3i(BRITAIN.x, BRITAIN.y, walk.surface_z(BRITAIN.x, BRITAIN.y))
	player.dir = 0
	# Barva kuze (granule `render.hue`, sada `HUE_SKIN` z `hues.json`). Bez ni je
	# telo 400 sedive: art z `anim.mul` je jen rampa jasu, barvu dava hue.
	# V UO znamena `hue == 0` "zadna barva", proto se sada dava jen kdyz je 0.
	if player.hue == 0:
		player.hue = HueScript.HUE_SKIN
	sim.player_serial = serial

	# Registr bytosti (granule `sim.entity_registry`) je JEDINE misto, kde se
	# mobil hleda podle serialu: `sim.movement` z nej mobily bere a `render.anim`
	# si z nej vyzvedava cislo tela (do 2026-10-06 bral `serial` jako telo).
	registry = RegistryScript.new()
	registry.register(player)
	movement = MovementScript.new(walk, sim.clock(), sim.events(), "", registry)
	movement.player_serial = serial
	sim.systems["movement"] = movement

	# `sim.skill_gain` dostava STEJNY registr jako `sim.movement` a RNG z
	# `SimWorld` (vlastni RNG by rozbil determinismus). System nema `tick`,
	# takze ho `SimWorld._tick_system` jen preskoci - slouzi volanim.
	sim.systems["skill_gain"] = SkillGainScript.new(registry, sim.rng(), sim.clock(), sim.events())

	# `world.time` se musi napojit na clock simulace (vada F6 z etapy 1: do
	# 2026-10-06 `world_time_ms` plnily jen testy, takze `hour()` vratilo ve hre
	# vzdy 0). Modul si cas nedrzi sam - dostava ho z `sim.clock()`.
	time = TimeScript.new()
	time.bind(sim.clock())
	sim.systems["time"] = time

	view.set_registry(registry)
	view.set_player(player)
	controller = get_node_or_null("PlayerController")
	if controller == null:
		push_warning("app.main: ve scene chybi uzel PlayerController - hrac se nepohne")
		return
	controller.setup(player, sim, loop.input_map, movement, view, loop)
	print("[main] hrac: serial ", serial, " na ", player.pos, " (", map.land_at(player.pos.x, player.pos.y),
		" land), hue ", player.hue, " (0 = bez barvy), barvy: ", view.hue_stats(),
		", systemu v sim: ", sim.systems.keys())


func _load_data() -> Dictionary:
	# `balance` jde pres `app.config` (M9): jedna typovana tabulka a kontrola,
	# co v datech nesedi. Chyby se HLASI - ticha nahrada defaultem by znamenala,
	# ze se hra chova jinak, nez data rikaji.
	var out: Dictionary = {}
	for key in DATA_FILES.keys():
		var path: String = DATA_FILES[key]
		if key == "balance":
			config = ConfigScript.new(path)
			var chyby: Array = config.check()
			for chyba in chyby:
				push_warning("app.main: app.config: " + str(chyba))
			print("[main] config: ", config.known_keys().size(), " klicu, chyb ", chyby.size(),
				", stat_gain.delay_ms ", config.value("stat_gain.delay_ms", 0),
				" (", config.source("stat_gain.delay_ms"), ")")
			if not config.all().is_empty():
				out[key] = config.all()
			continue
		if not FileAccess.file_exists(path):
			push_warning("app.main: chybi datovy soubor " + path)
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			push_warning("app.main: " + path + " se neda precist jako JSON")
			continue
		out[key] = parsed
	return out
