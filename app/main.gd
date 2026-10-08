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
# 16. session: sber surovin, vyroba a zurnal. `sim.harvest` a `sim.craft` se
# registruji TADY (integraci misto) - `sim.interaction` je pak najde dynamicky
# v `SimWorld.systems` a prestane vracet `not_available`.
const TiledataScript = preload("res://sim/world/tiledata.gd")
const ContainerScript = preload("res://sim/entity/container.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const HarvestScript = preload("res://sim/systems/harvest.gd")
const CraftScript = preload("res://sim/systems/craft.gd")
const JournalScript = preload("res://ui/journal.gd")
# 20. session (2026-10-08): obecna interakce. `sim.interaction` se registruje
# TADY (integraci misto) - do teto session nebyl v behu hry vubec, takze kazdy
# prikaz `use`/`use_on`/`interact` skoncil hlaskou "Not available yet".
const InteractionScript = preload("res://sim/systems/interaction.gd")
# M9 (15. session): typovana konfigurace a mereni vykonu. Config se ptá na
# `data/balance.json` (kontrola typu/rozsahu), metrics sbira frame cas, pocet
# kreslenych objektu, textury a stavbu davky.
const ConfigScript = preload("res://app/config.gd")
const MetricsScript = preload("res://app/metrics.gd")

const DEFAULT_SEED: int = 1234
const BRITAIN := Vector2i(1495, 1630)   # namesti Britainu (docs/01 §1.4)
const PLAYER_BODY: int = 400            # 400 = muz (tělo je jen v anim.mul)
# VSECHNY NASTROJE DO BATOHU (pokyn uzivatele 2026-10-08: "do pytliku pridej
# vsechny nastroje"). Seznam je z DAT (`data/items.json`, `category == "tool"`),
# ne z kodu - kdyz data pribudou, pribudnou i ve hre. Dva zaznamy s kategorii
# `tool` jsou CILE, ne nastroje (`TARGET_ROLES` v `sim.interaction`): kovadlina
# a vyhen. Cisla se odsud neopisuji.
const ITEMS_DATA := "res://data/items.json"
const SKILLS_DATA := "res://data/skills.json"
const TOOL_CATEGORY := "tool"
const TOOL_TARGET_ROLES: Array[String] = ["anvil", "forge"]
const ITEM_OFFSET: int = 0x4000         # tiledata id -> art id (docs/03 §3.4)
# ⚠ 18. session - CERNY PAS PRO GUI (prani uzivatele: stary zpusob UO): svet ma
# sve okno a GUI bydli v cernem pase VPRAVO a DOLE, aby zurnal nezakryval
# vyhled. Viz `_setup_ui()` a `app/world_view.gui_odsazeni`.
const GUI_PAS_VPRAVO: int = 320
const GUI_PAS_DOLE: int = 120
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
var journal = null
var tiledata = null
var container = null
var items: Dictionary = {}       # serial -> Item (smelt/repair hledaji podle serialu)
var harvest = null
var craft = null
var interaction = null           # `sim.interaction` - obecna interakce (20. session)
var config = null
var metrics = null
var world_view = null            # `app.world_view` (pro metriky)
var textures = null              # `render.textures` (pro metriky)
var _last_status_text: String = ""
var _metrics_s: float = 0.0


func _ready() -> void:
	# BARVA POZADI SVETA (rozhodnuti R2 z 2026-10-08, `ROZHODNUTI-2026-10-08.md`):
	# UO ma pozadi tmave, kdezto Godot kresli vychozi sedou 77,77,77 - v NODRAW
	# oblastech (727 dlazdic mapy) je to videt. Nastavuje se Z KODU, protoze
	# `project.godot` je bootstrap granule a agenti do nej nesmi (docs/09 §9.2);
	# efekt je stejny. Uzivatel muze tyz radek prenest do `project.godot`.
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))
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
	#
	# ⚠⚠ 18. session - CERNY PAS PRO GUI (prani uzivatele): "Herni okno se
	# sklada pouze z viditelneho sveta a journal ho prekryva. UO mela okno
	# viditelneho sveta a pak cerny okraj, kde se daly posouvat prvky GUI."
	# Je to tedy stary zpusob UO: vpravo a dole je CERNY PAS, ve kterem bydli
	# zurnal a stavovy pruh - svet maji jen v okne, ktere zbylo, takze zurnal
	# nezakryva vyhled. Pas kresli vlastni `CanvasLayer` (layer 1) POD HUD
	# (layer 2); kamera se posune o polovinu pásu (`view.gui_odsazeni`), aby
	# hrac stal ve stredu VIDITELNEHO sveta.
	var rozm: Vector2 = get_viewport_rect().size
	if rozm.x <= 0.0 or rozm.y <= 0.0:
		rozm = Vector2(1280, 720)      # NEMERENO (bez okna): deklarovane okno
	var pas := CanvasLayer.new()
	pas.name = "GuiPas"
	pas.layer = 1
	add_child(pas)
	var vpravo := ColorRect.new()
	vpravo.name = "PasVpravo"
	vpravo.color = Color(0.0, 0.0, 0.0, 1.0)
	vpravo.position = Vector2(rozm.x - float(GUI_PAS_VPRAVO), 0.0)
	vpravo.size = Vector2(float(GUI_PAS_VPRAVO), rozm.y)
	pas.add_child(vpravo)
	var dole := ColorRect.new()
	dole.name = "PasDole"
	dole.color = Color(0.0, 0.0, 0.0, 1.0)
	dole.position = Vector2(0.0, rozm.y - float(GUI_PAS_DOLE))
	dole.size = Vector2(rozm.x - float(GUI_PAS_VPRAVO), float(GUI_PAS_DOLE))
	pas.add_child(dole)
	hud = HudScript.new()
	hud.layer = 2                      # GUI lezi NA cernem pásu, ne na svete
	add_child(hud)
	status_bar = StatusBarScript.new()
	hud.add_child(status_bar)
	if not hud.register_window("status_bar", status_bar,
			Vector2(8.0, rozm.y - float(GUI_PAS_DOLE) + 8.0)):
		push_warning("app.main: status bar se nepodarilo zaregistrovat v HUD")
	# Zurnal (granule `ui.journal`, 16. session): okno v pravem pásu. Zpravy do
	# nej predava `app/loop.gd:_deliver_events` - UI je tenky klient.
	journal = JournalScript.new()
	journal.name = "Journal"
	hud.add_child(journal)
	var sirka_zurnalu: float = float(GUI_PAS_VPRAVO) - 16.0
	journal.velikost = Vector2(sirka_zurnalu, rozm.y - 24.0)
	if not hud.register_window("journal", journal,
			Vector2(rozm.x - float(GUI_PAS_VPRAVO) + 8.0, 8.0)):
		push_warning("app.main: zurnal se nepodarilo zaregistrovat v HUD")
	if loop != null:
		loop.journal = journal
	print("[main] UI: okna ", hud.layout().keys(), ", cerny pas vpravo ", GUI_PAS_VPRAVO,
		" px, dole ", GUI_PAS_DOLE, " px (svet ", rozm - Vector2(GUI_PAS_VPRAVO, GUI_PAS_DOLE), ")")


func _setup_world() -> void:
	# Klient (mapa + textury) je ODDELENY od simulace: `main` je jedine misto,
	# kde se potkavaji (docs/02 §2.2). Kdyz uzel ve scene chybi, rekne se to -
	# tiche "nic se nekresli" je presne vada, kterou mel projekt 2026-10-06.
	var view := get_node_or_null("WorldView")
	if view == null:
		push_warning("app.main: ve scene chybi uzel WorldView - mapa se nevykresli")
		return
	world_view = view
	# Kamera se posune o polovinu pásu, aby hrac stal ve stredu VIDITELNEHO
	# sveta (ne pod cernym pásem) - viz `app/world_view.gui_odsazeni`.
	view.gui_odsazeni = Vector2(float(GUI_PAS_VPRAVO) / 2.0, float(GUI_PAS_DOLE) / 2.0)
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
	# ⚠⚠ 19. session (2026-10-08) - VADA V3 ZE ZADANI 19: "Postava bezi jen asi
	# 3 policka ... dosla stamina a neregeneruje se." NAMERENO: `sim.regen`
	# (doplnovani staminy) NEEXISTUJE, takze pri vychozich statech 10/10/10
	# (`sim/entity/stats.gd`) je `max_stam = DEX = 10` a po 10 krocich behu
	# postava jen chodi - NAPOZADY. Uzivatel rozhodl: "nastavil vychozi staty na
	# 130, aby se to zatim nedelo". Staty jsou VSTUP z `data/balance.json`
	# (klic `player_start_stats`), ne opsana cisla v kodu - a hodnota je
	# PROZATIMNI: trvala oprava je `sim.regen` (viz HANDOFF, "Co se NEOPRAVILO").
	var staty: Dictionary = _start_stats()
	player.stats.str_ = int(staty["STR"])
	player.stats.dex = int(staty["DEX"])
	player.stats.int_ = int(staty["INT"])
	# Maxima a aktualni hodnoty se MUSI prebrat z novych statu: `Mobile._init`
	# je nastavil z vychozich 10/10/10 (bez toho by status bar ukazoval 10/130).
	player.max_hp = player.stats.hits_max()
	player.max_stam = player.stats.stam_max()
	player.max_mana = player.stats.mana_max()
	player.hp = player.max_hp
	player.stam = player.max_stam
	player.mana = player.max_mana
	player.pos = Vector3i(BRITAIN.x, BRITAIN.y, walk.surface_z(BRITAIN.x, BRITAIN.y))
	player.dir = 0
	# TABULKA DLAZDIC a KONTEJNER: jedina instance pro cely svet (docs/04 §4.2
	# `entity.container` - dve instance = duplikaty predmetu). `walk` dostava
	# stejnou instanci, aby se `tiles.json` nectlo dvakrat.
	tiledata = TiledataScript.new()
	container = ContainerScript.new(tiledata)
	# Batoh hrace: bez nej by sber i vyroba vracely `no_pack`. Vrstva 0x15
	# (`data/items.json`, art 0x4E75) je v UO batoh; `entity.equipment` jeste
	# neni, takze batoh nema vrstvu - je to serial v `player.backpack`.
	player.backpack = sim.next_serial()
	var batoh = ItemScript.new(int(player.backpack), 0x4E75, 1)
	batoh.layer = 0
	batoh.parent = serial
	items[int(player.backpack)] = batoh
	# Nastroje (20. session): do batohu jde KAZDY nastroj z `data/items.json`.
	# Bez nich by obecna interakce nemela co vybrat a vracela by `no_pair`.
	var nastroju: int = _give_tools()
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
	# Sber a vyroba (16. session): obe dostavaji STEJNY registr, kontejner,
	# slovnik predmetu a RNG/clock z `SimWorld`. `sim.interaction` je pak najde
	# v `SimWorld.systems` a prestane na ne vracet `not_available`.
	harvest = HarvestScript.new(map, tiledata, registry, sim.rng(), sim.clock(),
		sim.events(), sim.systems["skill_gain"], container, sim, items)
	sim.systems["harvest"] = harvest
	craft = CraftScript.new(container, items, map, tiledata, sim.systems["skill_gain"],
		sim, sim.rng(), sim.clock(), sim.events(), registry)
	sim.systems["craft"] = craft
	# Obecna interakce (20. session): `sim.interaction` dostava STEJNY kontejner,
	# registr a slovnik predmetu jako sber/vyroba (dve instance = duplikaty).
	# `world.doors` zatim neexistuje, proto `null` - `use` na dvere odpovi
	# `not_available` (viditelne), dokud je nekdo nezalozi.
	interaction = InteractionScript.new(sim, sim.events(), null, container, registry, items)
	sim.systems["interaction"] = interaction
	# POCATECNI SKILLY (20. session): bez nich je sber nehratelny (viz
	# `data/balance.json` -> `player_start_skills`). Az po `interaction`, aby se
	# jmena skillu prekladala JEDNIM zdrojem (`data/skills.json`).
	var skillu: int = _apply_start_skills()

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
		", nastroju v batohu ", nastroju, ", pocatecnich skillu ", skillu,
		", systemu v sim: ", sim.systems.keys())


func _give_tools() -> int:
	# VSECHNY NASTROJE DO BATOHU (pokyn uzivatele 2026-10-08). Vraci pocet
	# vydanych predmetu; kdyz data chybi, HLASI to - ticha nula by znamenala
	# "obecna interakce nic nedela" a vypadalo by to jako vada interakce.
	if not FileAccess.file_exists(ITEMS_DATA):
		push_warning("app.main: chybi " + ITEMS_DATA + " - hrac nedostane zadny nastroj")
		return 0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_DATA))
	if not (parsed is Array):
		push_warning("app.main: " + ITEMS_DATA + " neni seznam - hrac nedostane zadny nastroj")
		return 0
	var pocet: int = 0
	var jmena: Array[String] = []
	var videne_typy: Dictionary = {}     # type -> true (jeden nastroj od kazdeho typu)
	for rec in parsed:
		if not (rec is Dictionary):
			continue
		if str(rec.get("category", "")) != TOOL_CATEGORY:
			continue
		var role: String = str(rec.get("role", ""))
		if role in TOOL_TARGET_ROLES:
			continue                     # kovadlina a vyhen jsou CILE, ne nastroje
		if not rec.has("tile"):
			continue
		# ⚠ 20. session: JEDEN NASTROJ OD KAZDEHO TYPU, ne od kazdeho artu.
		# Typ je identita (`data/items.json` -> `type`) a jeden typ ma casto vic
		# grafik: krumpac 2 arty, sekera 3, kladivo 2. Do teto session se bral
		# kazdy zaznam, takze hrac dostal 28 predmetu misto 16 (dva krumpace,
		# tri sekery...) - nasla to sonda `_analyza/p23-interakce.gd`.
		var typ: String = str(rec.get("type", ""))
		if typ == "":
			typ = "art:" + str(rec["tile"])     # stara data bez typu - neztracej je
		if videne_typy.has(typ):
			continue
		videne_typy[typ] = true
		# `data/items.json` ma TILEDATA ID; `entity.item.tile` je ART ID (docs/03 §3.4).
		var predmet = ItemScript.new(sim.next_serial(), int(rec["tile"]) + ITEM_OFFSET, 1)
		if not container.add(int(player.backpack), predmet):
			push_warning("app.main: nastroj '" + str(rec.get("name", role))
				+ "' se do batohu nevesel (plno nebo vaha)")
			continue
		items[int(predmet.serial)] = predmet
		jmena.append(str(rec.get("name", role)))
		pocet += 1
	print("[main] nastroje v batohu: ", pocet, " (", ", ".join(PackedStringArray(jmena)), ")")
	return pocet


static func start_skills(balance_skills: Dictionary, skills_data) -> Dictionary:
	# Nazev skillu -> `id` (z `data/skills.json`) a hodnota v desetinach.
	# Vraci `{id: hodnota}`; nezname jmeno se NAHLASI a preskoci - ticha nula by
	# vypadala jako "skill se pridal", i kdyz se preklepl nazev.
	var podle_jmena: Dictionary = {}
	if skills_data is Array:
		for rec in skills_data:
			if rec is Dictionary and rec.has("name") and rec.has("id"):
				podle_jmena[str(rec["name"])] = int(rec["id"])
	var out: Dictionary = {}
	for jmeno in balance_skills.keys():
		if not podle_jmena.has(str(jmeno)):
			push_warning("app.main: skill '" + str(jmeno)
				+ "' z `player_start_skills` neni v " + SKILLS_DATA)
			continue
		out[int(podle_jmena[str(jmeno)])] = int(balance_skills[jmeno])
	return out


func _start_skills_map() -> Dictionary:
	# Vsechny klice `player_start_skills.*` ze SCHEMA `app.config` (ne z kódu):
	# kdo prida skill do schematu a do dat, tomu se objevi i ve hre.
	var out: Dictionary = {}
	if config == null:
		return out
	var prefix := "player_start_skills."
	for klic in config.known_keys():
		var cesta: String = str(klic)
		if cesta.begins_with(prefix):
			out[cesta.substr(prefix.length())] = int(config.value(cesta, 0))
	return out


func _apply_start_skills() -> int:
	# POCATECNI SKILLY HRACE (20. session). Duvod je namereny: se vsemi skilly 0
	# je sance sberu `skill/1000` = 0 % a tezba nefunguje (`_analyza/p23-interakce.gd`).
	var mapa: Dictionary = _start_skills_map()
	if mapa.is_empty():
		push_warning("app.main: zadne `player_start_skills` ve SCHEMA - hrac zacne se skilly 0")
		return 0
	var data = null
	if FileAccess.file_exists(SKILLS_DATA):
		data = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_DATA))
	else:
		push_warning("app.main: chybi " + SKILLS_DATA + " - pocatecni skilly se nepridaji")
		return 0
	var hodnoty: Dictionary = start_skills(mapa, data)
	for id in hodnoty.keys():
		player.skills.set_value(int(id), int(hodnoty[id]))
	var jmena: Array[String] = []
	for jmeno in mapa.keys():
		jmena.append("%s %s" % [str(jmeno), str(float(int(mapa[jmeno])) / 10.0)])
	print("[main] pocatecni skilly: ", ", ".join(PackedStringArray(jmena)))
	return hodnoty.size()


func _start_stats() -> Dictionary:
	# Pocatecni staty hrace z `data/balance.json` (`player_start_stats`), ne z
	# kodu (docs/08 §8.3: hodnotu nesmi tvrdit dva zdroje). Kdyz data nejsou
	# nactena (chybi soubor), pouzije se SCHEMA default z `app.config` - nikdy
	# "tise nula", ktera by postavu nechala bez staminy.
	var out := {"STR": 10, "DEX": 10, "INT": 10}
	if config == null:
		return out
	out["STR"] = int(config.value("player_start_stats.STR", 75))
	out["DEX"] = int(config.value("player_start_stats.DEX", 130))
	out["INT"] = int(config.value("player_start_stats.INT", 20))
	return out


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
