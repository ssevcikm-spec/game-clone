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
# DEBUG OVERLAY (granule `ui.debug_overlay`, 2026-10-09): informace o lokaci
# a stavu na obrazovce, aby se zachytily se screenshotem (navrh uzivatele:
# "Staci mozna vlepit na obrazovku at se to zachyti se screenshotem").
const DebugOverlayScript = preload("res://ui/debug_overlay.gd")
# GEOMETRIE OKNA (granule `app.window`, 2026-10-09, faze 1 bod 5.2): kde je
# svet, kde cerny pas GUI a kde bydli okna HUDu. Je to SAMOSTATNY modul proto,
# ze se pocita z AKTUALNI velikosti okna (pri startu, pri zmene velikosti
# a pri prepnuti fullsize) - a aby se dala merit bez okna.
const WindowScript = preload("res://app/window.gd")
# 20. session: BATOH (granule `ui.backpack`). UI je tenky klient - obsah mu plni
# `app/main` z `entity.container` a ikony dostava INJEKCI z `render` (ui/ na
# render/ sahat nesmi, docs/04 §4.1).
const BackpackScript = preload("res://ui/backpack.gd")
# 20. session: OKNO VYROBY (`ui.craft_gump`). Otevre ho udalost `gump_open`
# z `sim.interaction` (par "kladivo + kovadlina"); kliknuti na recept se vrati
# jako pozadavek a `app/main` z nej posle `Command{t:"craft"}`.
const CraftGumpScript = preload("res://ui/craft_gump.gd")
# 2026-10-09 (D3 jako HUD, `ui.policy_panel`): okno PRAVIDEL POLITIKY. Pravidla
# se zadavaji rucne do `user://policy.json` a do teto chvile nebyla ve hre
# VIDET (`HANDOFF` "Co ceka na tebe" D3). Okno je JEN CTENI - pravidla needituje
# ani neuklada (rozhodnuti uzivatele 2026-10-09: "D3 prijmu jen jako HUD").
const PolicyPanelScript = preload("res://ui/policy_panel.gd")
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
# PRAVIDLA POLITIKY (ZADANI-24): JSON v `user://` - hrac je muze menit bez
# zasahu do kodu a `sim.policy` je cte jako DATA (`sim/sim_world.gd:load_policy`).
const POLICY_PATH := "user://policy.json"
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
# ⚠⚠ 2026-10-09 (faze 1 bod 5.2): geometrie UZ NENI konstanta tady - je
# v `app/window.gd` (`PAS_VPRAVO`/`PAS_DOLE`) a pocita se z AKTUALNI velikosti
# okna. NAMERENO (`_analyza/p26-okno.gd`): se starym kodem zustalo pri okne
# 1600x900 platno i svet na 1280x720, takze vetsi okno nepridalo ani dlazdici.
# Jak casto se prekresluje DEBUG OVERLAY (s). Kazdy frame by zbytecne prehanel
# text i `get_minimum_size()`; 0,2 s je pro hledani vady v obrazku dost.
const DEBUG_OVERLAY_S: float = 0.2
# Cislo animace pro CLOVEKA (`app/player_controller` / `sim.movement`) -> nazev
# do overlaye. Cisla jsou ABSTRAKTNI ID; skupina v anim.mul je jina (beh = 2,
# viz `render/anim_player.ACTION_GROUP`).
const AKCE_NAZVY := {0: "walk", 1: "run", 4: "idle"}
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
var backpack = null              # `ui.backpack` (20. session)
var craft_gump = null            # `ui.craft_gump` (20. session)
var policy_panel = null          # `ui.policy_panel` (2026-10-09, D3 jako HUD)
var debug_overlay = null         # `ui.debug_overlay` (2026-10-09)
var _batoh_klic: Array = []      # posledni obsah batohu (neplnit UI kazdy frame)
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
var window_geom = null           # `app.window` - geometrie okna (bod 5.2)
var _fullsize: bool = false      # prepina `F2` (`app/player_controller`)
var _pas_vpravo: ColorRect = null
var _pas_dole: ColorRect = null
var _debug_s: float = 0.0
var _politika_s: float = 0.0     # casovac okna pravidel (5x/s, D3 jako HUD)
# NEJDELSI FRAME od posledniho prekresleni overlaye (ms): uzivatel hlasi
# "zaseky 2 framy z ~2300 na ~130 ms" (2026-10-09) a klouzavy prumer
# (`app.metrics`) takovy spickovy frame SCHOVA. Overlay ho ukaze a vynuluje.
var _peak_ms: float = 0.0


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
	# POLITIKA (ZADANI-24, `sim.policy`/`sim.executor`): kdyz ma hrac pravidla
	# v `user://policy.json`, nactou se pri startu a kazdy tik je vyhodnoti.
	# Bez souboru je to NO-OP (proto se ptame na existenci - hlaska o chybejicim
	# souboru by byla v zurnalu kazdy start). Vykonavatel je tim dosazitelny
	# z produkce; pravidla jsou data, ne kod.
	if FileAccess.file_exists(POLICY_PATH) and sim.load_policy(POLICY_PATH):
		print("[main] politika nactena z ", POLICY_PATH)
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
	# DEBUG OVERLAY (2026-10-09): text pro SCREENSHOT - hodnoty se skladaji
	# v `_debug_values()` a prekresluji kazdych `DEBUG_OVERLAY_S` s. Overlay
	# muze byt vypnuty klavesou (F3) - hodnoty se pak pocitaji dal, jen se
	# nekresli (vypnuti nesmi znamenat "nic se nemeri").
	_peak_ms = maxf(_peak_ms, _delta * 1000.0)
	# OKNO PRAVIDEL (D3 jako HUD): aktualizuje se 5x za sekundu (stejny takt jako
	# debug overlay), ale VLASTNIM casovacem - kdyby viselo na `debug_overlay`,
	# prestalo by se obnovovat ve chvili, kdy overlay neni.
	# ⚠ PRVNI VERZE tohohle volani byla BEZ podminek (`_osvezi_politiku()` na
	# urovni tela `_process`), takze se `sim.policy.evaluate()` +
	# `policy_state()` + `last_skipped()` + `rules()` delaly KAZDY FRAME, i se
	# zavrenym oknem - a komentar pritom tvrdil "5x za sekundu". NamEReno
	# verifikaci 2026-10-09: **119 volani `evaluate()` na 120 framu**.
	# Tvrzeni v komentari musi platit na KOD, ne naopak.
	_politika_s += _delta
	if _politika_s >= DEBUG_OVERLAY_S:
		_politika_s = 0.0
		_osvezi_politiku(true)
	if debug_overlay != null:
		_debug_s += _delta
		if _debug_s >= DEBUG_OVERLAY_S:
			_debug_s = 0.0
			debug_overlay.update(_debug_values())
			_peak_ms = 0.0
	# Stavovy pruh se aktualizuje JEN kdyz se text zmeni (ne kazdy frame).
	# Hodnoty jdou z `entity.mobile` - `max_hp`/`max_stam`/`max_mana` plni
	# `Mobile._init` ze statu (`entity.stats`), takze nejsou opsane cisla.
	# Vaha a zlato jsou 0, dokud neni batoh s predmety (M3) - je to pravda,
	# ne "nevim": hrac dnes nic nema.
	if status_bar == null or player == null:
		return
	_batoh()
	_recept()
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


func _debug_values() -> Dictionary:
	# VSE, CO SE NA OBRAZOVCE VYPISUJE, NA JEDNOM MISTE (2026-10-09): hodnoty
	# sbira `app.main` (jedine misto, kde se potkava sim a klient), text sklada
	# `ui.debug_overlay.text_for` (UI je tenky klient, docs/04 §4.1).
	# Chybejici hodnota se v textu pozna ("?" nebo 0/0) - vymyslena nula by
	# vypadala jako namERene cislo.
	var rozm: Vector2 = get_viewport_rect().size
	var hodnoty: Dictionary = {
		"loc": "",            # nazev lokace (Felucca/Britain) zatim nema kdo dat
		"win": "%dx%d" % [int(rozm.x), int(rozm.y)],
		"map": "%dx%d" % [int(map.width()), int(map.height())] if map != null else "?",
	}
	if player != null:
		hodnoty["x"] = int(player.pos.x)
		hodnoty["y"] = int(player.pos.y)
		hodnoty["z"] = int(player.pos.z)
		hodnoty["dir"] = int(player.dir)
		hodnoty["hp"] = int(player.hp)
		hodnoty["hp_max"] = int(player.max_hp)
		hodnoty["stam"] = int(player.stam)
		hodnoty["stam_max"] = int(player.max_stam)
		hodnoty["mana"] = int(player.mana)
		hodnoty["mana_max"] = int(player.max_mana)
	if world_view != null:
		hodnoty["zoom"] = float(world_view.zoom)
		hodnoty["drawn"] = int(world_view.drawn)
		hodnoty["holes"] = int(world_view.holes)
		hodnoty["tiles"] = world_view.viditelne_dlazdice()
		hodnoty["anim_frame"] = int(world_view.player_frame)
		hodnoty["anim_count"] = int(world_view.player_frames)
	if loop != null and loop.input_map != null:
		# `player_screen` je stred, ze ktereho klient meri smer z mysi a prevadi
		# klik na dlazdici (vada V14). Kdyz neni zmereny, posila se `Vector2.INF`
		# - v textu to musi byt VIDET ("(?)"), ne jako souradnice (0,0).
		var stred: Vector2 = loop.input_map.player_screen
		if stred.is_finite():
			hodnoty["pick"] = stred
	if controller != null and controller.has_method("action"):
		var akce: int = int(controller.action())
		hodnoty["anim"] = AKCE_NAZVY.get(akce, str(akce))
		var krok: Dictionary = controller.step_state() if controller.has_method("step_state") else {}
		if not krok.is_empty():
			hodnoty["step_run"] = bool(krok.get("run", false))
			hodnoty["step_delay_ms"] = int(krok.get("delay_ms", 0))
			var sim_cas: int = int(sim.world_time()) if sim != null else 0
			hodnoty["step_elapsed_ms"] = maxi(0, sim_cas - int(krok.get("start_ms", sim_cas)))
	if metrics != null:
		var r: Dictionary = metrics.report()
		hodnoty["fps"] = float(r.get("fps", 0.0))
		hodnoty["frame_ms"] = float(r.get("frame_ms", 0.0))
	hodnoty["peak_ms"] = _peak_ms
	return hodnoty


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
	var rozm: Vector2 = _rozmery_okna()
	var pas := CanvasLayer.new()
	pas.name = "GuiPas"
	pas.layer = 1
	add_child(pas)
	var vpravo := ColorRect.new()
	vpravo.name = "PasVpravo"
	vpravo.color = Color(0.0, 0.0, 0.0, 1.0)
	pas.add_child(vpravo)
	_pas_vpravo = vpravo
	var dole := ColorRect.new()
	dole.name = "PasDole"
	dole.color = Color(0.0, 0.0, 0.0, 1.0)
	pas.add_child(dole)
	_pas_dole = dole
	hud = HudScript.new()
	hud.layer = 2                      # GUI lezi NA cernem pásu, ne na svete
	add_child(hud)
	status_bar = StatusBarScript.new()
	hud.add_child(status_bar)
	if not hud.register_window("status_bar", status_bar, Vector2.ZERO):
		push_warning("app.main: status bar se nepodarilo zaregistrovat v HUD")
	# Zurnal (granule `ui.journal`, 16. session): okno v pravem pásu. Zpravy do
	# nej predava `app/loop.gd:_deliver_events` - UI je tenky klient.
	journal = JournalScript.new()
	journal.name = "Journal"
	hud.add_child(journal)
	journal.velikost = Vector2(float(WindowScript.PAS_VPRAVO) - 16.0, rozm.y - 24.0)
	if not hud.register_window("journal", journal, Vector2.ZERO):
		push_warning("app.main: zurnal se nepodarilo zaregistrovat v HUD")
	if loop != null:
		loop.journal = journal
	# BATOH (20. session): okno se seznamem predmetu v batohu. Zavrene, dokud
	# hrac nezmackne `B` (klavesu vlastni `app/player_controller`, dokud neni
	# `ui.hotkeys`); ikony dostava INJEKCI v `_setup_world` (textury jeste
	# neexistuji - `_setup_ui` bezi prvni).
	backpack = BackpackScript.new()
	backpack.name = "Backpack"
	hud.add_child(backpack)
	backpack.visible = false
	if not hud.register_window("backpack", backpack, Vector2(8.0, 8.0)):
		push_warning("app.main: batoh se nepodarilo zaregistrovat v HUD")
	# OKNO VYROBY (20. session): otevre ho az udalost `gump_open` (dokud recepty
	# nejsou, nema co zobrazit - a prazdne okno by vypadalo jako vada).
	craft_gump = CraftGumpScript.new()
	craft_gump.name = "CraftGump"
	hud.add_child(craft_gump)
	craft_gump.visible = false
	if not hud.register_window("craft_gump", craft_gump, Vector2(8.0, 300.0)):
		push_warning("app.main: okno vyroby se nepodarilo zaregistrovat v HUD")
	if loop != null:
		loop.gump_okna.append(craft_gump)
	# OKNO PRAVIDEL (2026-10-09, D3 jako HUD): ZAVRENE, dokud hrac nezmackne `P`
	# (klavesa je v `app/player_controller.UI_KEYS`, stejne jako `B` u batohu).
	# Obsah plni `_osvezi_politiku()` - UI samo o pravidlech nic nevi.
	policy_panel = PolicyPanelScript.new()
	policy_panel.name = "PolicyPanel"
	hud.add_child(policy_panel)
	policy_panel.visible = false
	if not hud.register_window("policy_panel", policy_panel, Vector2(340.0, 520.0)):
		push_warning("app.main: okno pravidel se nepodarilo zaregistrovat v HUD")
	# DEBUG OVERLAY: neni to okno (nema titul ani se neposouva) - je to vrstva
	# textu v levem hornim rohu, VIDITELNA od startu, aby ji zachytil screenshot.
	# `F3` ji prepina (`app/player_controller`). Hodnoty plni `_debug_values()`.
	debug_overlay = DebugOverlayScript.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.position = Vector2(8.0, 8.0)
	hud.add_child(debug_overlay)
	print("[main] debug overlay: viditelny (F3 prepina, hodnoty kazdych ",
		int(DEBUG_OVERLAY_S), " s)")
	# GEOMETRIE (2026-10-09, bod 5.2): prvni prepocet - a od te doby se dela
	# PRI KAZDE ZMENE VELIKOSTI OKNA. Do tohoto dne se pocitala jen tady
	# jednou, takze vetsi okno nepridalo ani dlazdici (viz hlavicka modulu).
	_prepocitej_geometrii()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_prepocitej_geometrii):
		vp.size_changed.connect(_prepocitej_geometrii)
	print("[main] UI: okna ", hud.layout().keys(), " (geometrie z `app.window`)")


func _rozmery_okna() -> Vector2:
	# AKTUALNI velikost okna. Kdyz ji viewport nema (headless bez okna), bere se
	# DEKLAROVANA velikost z `project.godot` - stejna obrana jako ve
	# `world_view.viewport_size()`, jen tady kvuli layoutu.
	var rozm: Vector2 = get_viewport_rect().size
	if rozm.x <= 0.0 or rozm.y <= 0.0:
		rozm = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 900)))
	return rozm


func _prepocitej_geometrii() -> void:
	# JEDNO MISTO pro cely layout (2026-10-09, bod 5.2): svet, cerny pas,
	# `world_view.gui_odsazeni` a pozice oken HUDu. Vola se pri startu, pri
	# zmene velikosti okna a pri prepnuti fullsize. Kdyby si to pocital kazdy
	# uzel sam, rozejdou se - presne to se stalo (pocitalo se to jednou).
	if window_geom == null:
		window_geom = WindowScript.new()
	var rozm: Vector2 = _rozmery_okna()
	var p: Vector2 = window_geom.pas(rozm, _fullsize)
	var svet: Rect2 = window_geom.svet_obal(rozm, _fullsize)
	if _pas_vpravo != null:
		_pas_vpravo.visible = not _fullsize
		_pas_vpravo.position = Vector2(rozm.x - p.x, 0.0)
		_pas_vpravo.size = Vector2(p.x, rozm.y)
	if _pas_dole != null:
		_pas_dole.visible = not _fullsize
		_pas_dole.position = Vector2(0.0, svet.size.y)
		_pas_dole.size = Vector2(svet.size.x, p.y)
	if hud != null:
		var okna: Dictionary = window_geom.pozice_oken(rozm, _fullsize)
		for id in okna.keys():
			hud.set_position(str(id), okna[id])
	if journal != null:
		journal.velikost = Vector2(float(WindowScript.PAS_VPRAVO) - 16.0, rozm.y - 24.0)
	if world_view != null and world_view.has_method("nastav_gui_odsazeni"):
		# Kamera se posune o POLOVINU pasu: hrac pak stoji ve stredu
		# VIDITELNEHO sveta, ne pod cernym pasem.
		world_view.nastav_gui_odsazeni(p / 2.0)
	print("[main] geometrie okna: ", rozm, " | svet ", svet.size, " | pas ", p,
		" | fullsize ", _fullsize, " | stred sveta ",
		window_geom.stred_sveta(rozm, _fullsize))


func prepni_fullsize() -> bool:
	# FULLSIZE (reference `_src/classicuo/.../OptionsGump.cs:4113-4133`:
	# "fullsize" prepinac nastavi ram sveta na cele okno): cerny pas zmizi
	# a svet dostane cele okno. Vraci NOVY stav - volajici ho hlasi hracovi
	# (ticho by znamenalo, ze hrac nevi, jestli neco zmackl).
	_fullsize = not _fullsize
	_prepocitej_geometrii()
	return _fullsize


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
	# Ikony do batohu jdou INJEKCI (`ui/` nesmi na `render/`, docs/04 §4.1).
	if backpack != null:
		backpack.nastav_textury(textures)
	view.setup(map, textures)
	# ⚠ 2026-10-09 (bod 5.5): STAVBA SEZNAMU PO CASTECH. Cela stavba stoji
	# **179-199 ms** (`_analyza/p29-zasek.gd`: spike 145 ms na framu, kdy
	# `prestaveb` stouplo; atlas to NENI - `hold 0`, `ceka 0`) a byla to jedina
	# zbylá pricina zaseku pri chuzi. Hra proto stavi po castech, stejne jako
	# davka (`_STAVBA_MS`); kdo si view postavi sam, dostane synchronni cestu.
	view.stavba_ms = view.stavba_ms_hry()
	# ⚠ 2026-10-09 (bod 5.2): `gui_odsazeni` se UZ NENASTAVUJE tady - dela ho
	# `_prepocitej_geometrii()` (jedno misto pro cely layout). Vola se po
	# `setup()`, aby kamera i seznam objektu znaly hotovy svet.
	_prepocitej_geometrii()
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
	# STANICE VE SVETE (20. session): kovadlina a vyhen. NAMERENO sondou
	# `_analyza/p24-vyroba.gd`: v okoli Britainu (160 dlazdic) NENI zadna
	# stanice jako statik mapy, takze bez tohohle by se ruda nedala vytavit -
	# `sim.craft` sice stanici jako PREDMET umi (`_station_near`), ale nikdo
	# ji do sveta nedaval. Dava se VEDLE hrace, aby na ni hrac dosahl (2 dlazdice).
	var stanic: int = _postav_stanice()
	# Barva kuze (granule `render.hue`, sada `HUE_SKIN` z `hues.json`). Bez ni je
	# telo 400 sedive: art z `anim.mul` je jen rampa jasu, barvu dava hue.
	# V UO znamena `hue == 0` "zadna barva", proto se sada dava jen kdyz je 0.
	if player.hue == 0:
		player.hue = HueScript.HUE_SKIN
	sim.player_serial = serial

	# Registr bytosti (granule `sim.entity_registry`) je JEDINE misto, kde se
	# mobil hleda podle serialu: `sim.movement` z nej mobily bere a `render.anim`
	# si z nej vyzvedava cislo tela (do 2026-10-06 bral `serial` jako telo).
	# ⚠ Od 2026-10-09 registr VLASTNI `SimWorld` (`sim.registry`), ne `app`:
	# svet ho potrebuje jako stavovy zdroj (`sources["entities"]`), aby se
	# mobily vubec ukladaly. Dve instance by znamenaly, ze se ulozi jen jedna.
	registry = sim.registry
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
	controller.backpack = backpack      # klavesa `B` prepina okno batohu
	controller.policy_panel = policy_panel   # klavesa `P` ukaze okno pravidel
	controller.debug_overlay = debug_overlay   # klavesa `F3` prepina overlay
	controller.okno = self              # klavesa `F2` prepina fullsize (bod 5.2)
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


func _recept() -> void:
	# Kliknuti na recept v okne vyroby -> Command (20. session). Okno samo
	# neodesila NIC (je to `ui/`); tady se pozadavek vyzvedne a posle do sim.
	# Stejna cesta jako u klaves: `sim.enqueue` -> `sim.tick` -> dispatch.
	if craft_gump == null or sim == null:
		return
	var pozadavek: Dictionary = craft_gump.odeber_pozadavek()
	if pozadavek.is_empty():
		return
	print("[main] vyroba: recept ", int(pozadavek.get("recipe", -1)),
		" x", int(pozadavek.get("count", 1)))
	sim.enqueue(pozadavek)


func _osvezi_politiku(prebavit: bool = false) -> void:
	# Obsah okna pravidel (2026-10-09, D3 jako HUD). TADY se potkava `sim` s UI:
	# `sim.policy` da pravidla a `sim.executor` stav; okno dostane hotove radky
	# a jen je vykresli (`ui/` o politice nevi).
	#
	# DUVOD u kazdeho pravidla (to je jadro, ne dekorace): `evaluate()` vraci
	# `why` u rozhodnuti, ktera PROSLA, a `last_skipped()` u tech, ktera
	# NEprosla ("stav nezna: inventory") - oboji je vstup z `sim/`, ne vymysl UI.
	#
	# ⚠ PRVNI RADEK JE POVINNY, NECHCENY SPECIALNI PRIPAD (namEReno verifikaci
	# 2026-10-09): bez `user://policy.json` je `sim.policy` i `sim.executor` null,
	# takze `radky=[]` a `stav={}` - a to je PRESNE pocatecni stav panelu, takze
	# se `flush()` nezavolal ANI JEDNOU a okno zustalo prazdne (hráč zmackl `P`
	# a videl prazdno BEZ vysvetleni). Vetev "(zadna pravidla)" tim byla v
	# produkci MRTVY KOD. Kdo se pta jen "zmenilo se neco?", zapomene, ze
	# poprve se musí nakreslit i to, co se "nezmenilo".
	#
	# `prebavit = true` znamena "prepocitej z `sim`" (vola ho casovac v `_process`
	# 5x/s). Bez argumentu funkce po prvnim prebaveni NIC nedela (jen se vrati) -
	# kdo ji chce vynutit obnovu, posle `true`; kdo ji zavola bez argumentu po
	# prvnim flushi, nedostane nic (namEReno verifikaci 2026-10-09: sonda to
	# takhle volala a spolehala na to, ze se neco stane).
	if policy_panel == null:
		return
	var poprve: bool = policy_panel.prebaveni() == 0
	if not (prebavit or poprve):
		return
	var radky: Array = []
	if sim != null and sim.policy != null:
		var duvody: Dictionary = {}
		var rozhodnuti: Array = sim.policy.evaluate(sim.policy_state())
		for rozhodnuti_radek in rozhodnuti:
			if not (rozhodnuti_radek is Dictionary):
				continue
			duvody[str(rozhodnuti_radek.get("rule_id", ""))] = str(rozhodnuti_radek.get("why", ""))
		var preskocena: Dictionary = {}
		for preskoceny_radek in sim.policy.last_skipped():
			if not (preskoceny_radek is Dictionary):
				continue
			preskocena[str(preskoceny_radek.get("rule_id", ""))] = str(preskoceny_radek.get("why", ""))
		for pravidlo in sim.policy.rules():
			var id: String = str(pravidlo.get("id", ""))
			var duvod: String = ""
			if duvody.has(id):
				duvod = str(duvody[id])
			elif preskocena.has(id):
				duvod = str(preskocena[id])
			radky.append({
				"id": id,
				"priority": sim.policy.priority_of(pravidlo),
				"reason": duvod,
			})
	var stav: Dictionary = {}
	if sim != null and sim.executor != null:
		stav = sim.executor.status()
	# PREBAVI se jen kdyz se obsah opravdu zmenil (5x/s se jen porovnava).
	if poprve or radky != policy_panel.radky() or stav != policy_panel.stav():
		policy_panel.nastav_pravidla(radky, stav)
		policy_panel.flush()


func _batoh() -> void:
	# Obsah batohu pro okno (20. session). UI je TENKY KLIENT: tady se precte
	# kontejner a preda se hotovy seznam radku; kdyz se obsah nezmenil, UI se
	# neprebavuje (jinak by se okno stavělo 60x za sekundu).
	if backpack == null or player == null or container == null:
		return
	var radky: Array = []
	var klic: Array = []
	for serial in container.contents(int(player.backpack)):
		var predmet = items.get(int(serial))
		if predmet == null:
			continue
		var art: int = int(predmet.tile)
		var amount: int = int(predmet.amount)
		radky.append({"art": art, "name": ItemScript.name_of(art), "amount": amount})
		klic.append([int(serial), art, amount])
	if klic == _batoh_klic:
		return
	_batoh_klic = klic
	backpack.nastav_obsah(radky)


func _postav_stanice() -> int:
	# KOVADLINA A VYHEN DO SVETA (20. session). Bere se z DAT podle role
	# (`data/items.json`), ne z kódu; `parent == 0` = na zemi, `pos` plati jen
	# tam (docs/04 §4.5). Hrac stoji na `BRITAIN`, stanice jsou VEDLE nej
	# (dosah stanice je 2 dlazdice - `sim.craft.STATION_RANGE`).
	#
	# ⚠ CO ZATIM NENI: predmety na zemi se NEKRESLI (`app/world_view` kresli
	# mapu a hrace) - hrac tedy stanici nevidi, jen ji muze pouzit. Vidi to
	# v zurnalu ("A forge stands to the east."). Kresleni pozemskych predmetu
	# je dalsi krok (patri do `render` s paritni branou a snimkem).
	var chci: Array = [{"role": "forge", "x": 1, "y": 0, "smer": "east"},
		{"role": "anvil", "x": 0, "y": 1, "smer": "south"}]
	if not FileAccess.file_exists(ITEMS_DATA):
		push_warning("app.main: chybi " + ITEMS_DATA + " - stanice se nepostavi")
		return 0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_DATA))
	if not (parsed is Array):
		return 0
	var podle_role: Dictionary = {}
	for rec in parsed:
		if rec is Dictionary and str(rec.get("role", "")) != "":
			podle_role[str(rec["role"])] = int(rec.get("tile", 0))
	var postaveno: int = 0
	for stanice in chci:
		var role: String = str(stanice["role"])
		if not podle_role.has(role):
			push_warning("app.main: role '" + role + "' v " + ITEMS_DATA + " neni - stanice se nepostavi")
			continue
		var art: int = int(podle_role[role]) + ITEM_OFFSET
		var predmet = ItemScript.new(sim.next_serial(), art, 1)
		predmet.parent = 0
		predmet.pos = Vector3i(BRITAIN.x + int(stanice["x"]), BRITAIN.y + int(stanice["y"]),
			int(player.pos.z))
		items[int(predmet.serial)] = predmet
		postaveno += 1
		_hlaseni_do_zurnalu("A " + role + " stands to the " + str(stanice["smer"]) + ".")
		print("[main] stanice: ", role, " (art ", art, ") na ", predmet.pos)
	return postaveno


func _hlaseni_do_zurnalu(text: String) -> void:
	# Hlaseni hraci pri startu. sim ho posila jako udalost (UI je tenky klient).
	if sim != null and sim.has_method("push_event"):
		sim.push_event("message", {"text": text, "kind": "system"})


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
