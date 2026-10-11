extends Node2D
# Scena a start hry (docs/02 §2.5): vytvori sim, nacte data a preda rizeni
# `app/loop.gd`. HERNI PRAVIDLA TU NEJSOU (prompt granule) - jen slozeni.
#
# `SimWorld` ma sice `class_name`, ale ten je známy jen pres cache importu
# (.godot/global_script_class_cache.cfg) - v cerstvem stromu spadne parse
# ("Identifier SimWorld not declared", namEReno 2026-10-02). Proto preload
# s vlastnim jmenem, ktere s globalnim nekoliduje (docs/02 §2.6.2).
const SimScript = preload("res://sim/sim_world.gd")
# VRSTVY OBSAHU (2026-10-11, `sim.content`): JEDNO misto, kde hra preklada
# `res://data/*.json` na vrstvy (zaklad + mody z `user://mods/`). Konfigurace je
# `data/content-layers.json`; kontrakt je v `docs/04 §4.9`. Vypnout se da
# pripojnem `--no-mods`.
const ContentScript = preload("res://sim/content.gd")
const Loop = preload("res://app/loop.gd")
const InputMapScript = preload("res://app/input_map.gd")
const MapScript = preload("res://sim/world/map.gd")
const TextureCache = preload("res://render/texture_cache.gd")
# 2026-10-11 (`render.own_art`): prepinac vlastniho artu PO KUSECH. Konfiguraci
# cte `render/own_art.gd` (`assets/own-art.json`); `app.main` ji preda do
# `render.textures` (atlasovy art) a `app.world_view` (animace postavy).
const OwnArtScript = preload("res://render/own_art.gd")
const WalkScript = preload("res://sim/world/walk.gd")
# `world.doors` / `world.stairs` se zakladaji s CESTou z vrstev obsahu (S1b):
# driv si je zakladal `sim.walk` sam a mod je nemohl prebit.
const DoorsScript = preload("res://sim/world/doors.gd")
const StairsScript = preload("res://sim/world/stairs.gd")
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
# 2026-10-10 (`sim.regen`): doplnovani hp/stam/mana. Registruje se do
# `sim.systems` - `SimWorld` ho tickuje podle `SYSTEM_ORDER`.
const RegenScript = preload("res://sim/systems/regen.gd")
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
# 2026-10-10 (`ui.skill_list`, D10 - "herni zaklady"): okno se seznamem skillu.
# Bez nej neni videt, ze tezba a vyroba neco rostou - a to je pro demo klicove.
const SkillListScript = preload("res://ui/skill_list.gd")
# SESSION D (2026-10-11, `ui.hotkeys`): NAPOVEDA - klavesy a co delat. Okno je
# TENKY KLIENT; obsah se sklada TADY z `data/help.json` (text, poradi, skupiny)
# a z REALNYCH vazeb v `InputMap` (klavesy se do dat NEPISUJI - dve pravdy
# o klavesach by znamenaly, ze hrac maze klavesu, ktera nic nedela).
const HotkeysScript = preload("res://ui/hotkeys.gd")
# `HELP_DATA` tu BYLO do 2026-10-11 (S1b): cestu k napovede drzi jen `help_data`
# (plni ji `_nacti_obsah()` z vrstev obsahu). Mrtva konstanta je dluh - kdyby
# zustala, cetl by z ni nekdo "zakladni" cestu a mod by u napovedy nefungoval.
# 2026-10-10 (`ui.vendor_gump`, D10): obchodni okno. Otevre ho udalost
# `gump_open{gump:"vendor"}` (stejne jako okno vyroby) - a `sim.vendor` ji
# posle, kdyz hrac pouzije vendora (`Command{t:"use"}` -> `interaction`).
const VendorGumpScript = preload("res://ui/vendor_gump.gd")
# `sim/systems/vendor.gd` (D10): ceny a sklad z `data/vendors.json`.
const VendorScript = preload("res://sim/systems/vendor.gd")
# `sim/entity/skills.gd` kvuli `SKILL_COUNT` (58) - pocet radku seznamu se
# NEPISE natvrdo, aby se nerozesel se simulaci.
const SkillsScript = preload("res://sim/entity/skills.gd")
# 20. session (2026-10-08): obecna interakce. `sim.interaction` se registruje
# TADY (integraci misto) - do teto session nebyl v behu hry vubec, takze kazdy
# prikaz `use`/`use_on`/`interact` skoncil hlaskou "Not available yet".
const InteractionScript = preload("res://sim/systems/interaction.gd")
# M9 (15. session): typovana konfigurace a mereni vykonu. Config se ptá na
# `data/balance.json` (kontrola typu/rozsahu), metrics sbira frame cas, pocet
# kreslenych objektu, textury a stavbu davky.
const ConfigScript = preload("res://app/config.gd")
const MetricsScript = preload("res://app/metrics.gd")

# --- M5 (2026-10-10): SOUBOJ, MONSTRA, SMRT, LOOT -------------------------
# PROC ZVLASŤ: do teto chvile `attack` routoval na `sim.combat`, ale ten
# v `sim.systems` NEBYL - hrac dostal "Not available yet"
# (`DALSI-SESSION.md` sekce C). Tohle je integracni misto: instance systemu
# zaklada `app/main` (jedine misto, kde se potkava sim a klient, docs/02 §2.5).
const CombatScript = preload("res://sim/systems/combat.gd")
const DeathScript = preload("res://sim/systems/death.gd")
const LootScript = preload("res://sim/systems/loot.gd")
const PoisonScript = preload("res://sim/systems/poison.gd")
const DecayScript = preload("res://sim/systems/decay.gd")
const AiScript = preload("res://sim/systems/ai.gd")
const SpawnScript = preload("res://sim/world/spawn.gd")
# Vybava hrace: `sim.combat` z ni bere bonusy (HCI/DCI/DI). Do M5 ji `app/main`
# nemel - `entity.equipment` je hotova granule, ale nikdo ji v behu hry
# neinstancoval, takze bonusy zbrane se NEMERILY.
const EquipmentScript = preload("res://sim/entity/equipment.gd")
# Staty monstra z `data/monsters.json` (M5) - `Mobile._init` da vychozi 10/10/10,
# monstrum ale ma STR/DEX/INT z DAT (kontrakt M5 §3.4).
const StatsScript = preload("res://sim/entity/stats.gd")

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
# `ITEMS_DATA` tu BYLO do 2026-10-11 (S1b) - viz poznamka u `HELP_DATA`.
# `SKILLS_DATA` zustava: je DEFAULT PARAMETR staticke `start_skills()`, tedy
# misto, kde se cesta rozhoduje (ne cteni v tele).
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
# Jak casto se obnovuje SEZNAM SKILLU (D10, 2026-10-10). Hodnoty skillu rostou
# pomalu (desetiny), takze 2x/s staci - kazdy frame by zbytecne prebavoval uzly.
const SKILL_LIST_S: float = 0.5
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
var skill_list = null            # `ui.skill_list` (2026-10-10, D10)
var vendor_gump = null           # `ui.vendor_gump` (2026-10-10, D10)
var vendor = null                # `sim.vendor` (2026-10-10, D10)
var hotkeys = null               # `ui.hotkeys` (session D) - napoveda pro hrace
# NAPOVEDA Z DAT (`data/help.json`, session D): nacte se JEDNOU, aby se JSON
# neparsoval pri kazdem otevreni okna. Prazdny slovnik = data se neprecetla
# a kazdy, kdo se na ne ptá, to MUSI nahlasit (zadna ticha prazdna napoveda).
var _help_data: Dictionary = {}
# CESTY K DATUM ROZLISENE PRES VRSTVY OBSAHU (`sim.content`, docs/04 §4.9).
# Tady je to, co hra OPRAVDU pouzije; plni je `_nacti_obsah()` (prvni vec
# v `_ready()`, tedy driv, nez je kdokoli cte). Kdo saha na data, saha na tyhle
# promenne. Prazdno do te doby je ZAMERNE (S1b, `docs/04 §4.9.1`): konstanta
# `res://data/...` se v `app/` smi objevit jen jako default parametru, aby se
# dalo staticky overit, ze se nikde necte mimo `sim/content.gd` a `_cesta()`.
var content = null
var items_data: String = ""
var skills_data: String = ""
var help_data: String = ""
var _mods_vypnuto: bool = false      # `--no-mods` (bere se jen zakladni vrstva)
# VADY NAPOVEDY z posledniho skladani (akce, ktera v `InputMap` neni, vadny
# radek dat). Pocitaji se do vystupu a `_osvezi_napovedu()` je VYPISE - vada
# napovedy se nesmi tvarit jako "napoveda je kratka".
var _napoveda_chyby: Array[String] = []
# Dlazdice s cilem interakce -> co na ni je ("ruda", "forge", ...). Plni
# `_zkontroluj_cile_interakce()`; slouzi k tomu, aby se prekryv nasel pri
# startu a ne az tim, ze "se nic nedeje".
var _cile_interakce: Dictionary = {}
# M5 (2026-10-10): systemy souboje a smrti. Drzi se TADY (ne jen v
# `sim.systems`), aby na ne mohl `_postav_monstra_u_hrace` a debug overlay
# sahat - `sim.systems` je slovnik pro routing, ne misto pro klienta.
var combat = null
var death = null
var loot = null
var poison = null
var decay = null
var ai = null
var spawn = null
var equipment = null             # `entity.equipment` (vybava a bonusy hrace)
# Cache dat monster a skillu pro `_postav_monstra_u_hrace()` (M5): nacte se
# JEDNOU za proces, aby se JSON neparsoval pro kazde monstrum zvlast.
var _monstra_data: Dictionary = {}
var _monstra_nactena: bool = false
var _skill_ids: Dictionary = {}
var _skill_ids_nactene: bool = false
# Mnozina art ID z manifestu atlasu (pro `corpse_art_for`) - cache, aby se
# JSON nectl pri kazdem umrti.
var _atlas_arts: Dictionary = {}
var prodejce = 0                 # serial vendora NPC ve svete (0 = nikdo)
var balvany: Array = []          # pozice rudnych balvanu (pro sondu smycky)
var _skill_s: float = 0.0        # casovac obnovy seznamu skillu (2x/s)
var _skill_klic: Array = []      # posledni hodnoty (neplnit UI kazdy frame)
var debug_overlay = null         # `ui.debug_overlay` (2026-10-09)
var _batoh_klic: Array = []      # posledni obsah batohu (neplnit UI kazdy frame)
var tiledata = null
var container = null
var items: Dictionary = {}       # serial -> Item (smelt/repair hledaji podle serialu)
var harvest = null
var craft = null
var interaction = null           # `sim.interaction` - obecna interakce (20. session)
# `world.doors` a `world.stairs` zaklada `app/main` (S1b, 2026-10-11): driv je
# zakladal `sim.walk` sam, takze mod nemel jak prebit `data/doors.json` /
# `data/stairs.json` - cesta byla zapeena v konstante modulu.
var doors = null
var stairs = null
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
# Prepinace z prikazove radky (ctou se na JEDNOM miste, viz `_parsuj_prepinace`).
var _vlastni_vypnuto: bool = false   # `--no-own-art` (A/B srovnani: jen UO art)
var _policy_cesta: String = ""       # `--policy` / `--policy=<cesta>` (M10)
var _vlastni_art: Array = []         # vrstvy z `assets/own-art.json` (muze byt prazdne)


func _ready() -> void:
	# BARVA POZADI SVETA (rozhodnuti R2 z 2026-10-08, `ROZHODNUTI-2026-10-08.md`):
	# UO ma pozadi tmave, kdezto Godot kresli vychozi sedou 77,77,77 - v NODRAW
	# oblastech (727 dlazdic mapy) je to videt. Nastavuje se Z KODU, protoze
	# `project.godot` je bootstrap granule a agenti do nej nesmi (docs/09 §9.2);
	# efekt je stejny. Uzivatel muze tyz radek prenest do `project.godot`.
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))
	# PREPINACE PRVNÍ: `_setup_world()` se rozhoduje podle `_vlastni_vypnuto`,
	# jestli vrstvy vlastniho artu vubec nacte - kdyby se ctly az po stavbe
	# sveta, `--no-own-art` by nemelo zadny efekt (a to by se hledalo tezko).
	_parsuj_prepinace()
	# OBSAH PRED DATY: `_load_data()` i systemy dostavaji cesty z vrstev
	# (docs/04 §4.9). Kdyby se vrstvy nactly az po `_load_data()`, cetl by se
	# `balance.json` jeste ze zakladni cesty a mod by u nej nemel efekt.
	_nacti_obsah()
	# IDENTITA PREDMETU (S1b, 2026-10-11): `sim.entity.item` ma statickou cache
	# pro cely proces, takze se musi nacist PRVNI - jinak by ji prvni volani
	# `type_of()` nacetlo z KONSTANTY a mod u `data/items.json` by nemel efekt
	# (presne ta vada, kterou S1b odstranuje). `loaded_path()` rekne, co se
	# opravdu nacetlo (ne co se melo).
	ItemScript.nacti_data(items_data)
	var data: Dictionary = _load_data()
	metrics = MetricsScript.new()
	sim = SimScript.new(DEFAULT_SEED, data)
	loop = Loop.new()
	loop.sim = sim
	loop.input_map = InputMapScript.new({}, sim.registry, sim)
	add_child(loop)
	_setup_ui()
	# ⚠ VAZBY KLAVES MUSI BYT V `InputMap` DRIV, NEZ SE STAVI SVET (session D):
	# hlasky ve svete berou klavesu odtud ("press E or T to mine") - kdyby se
	# svet stavěl prvni, vyslo by v kazde hlasce "(?)" (namEReno sondou
	# `_analyza/p56-start-pozorovani.gd`). `controller.setup()` je zaklada
	# ZNOVU a je idempotentni (`register_actions` podruhe vraci 0), takze se
	# nic nezdvojuje.
	_klavesy_do_inputmap()
	_setup_world()
	# POLITIKA JE OD 2026-10-10 ZAMERNE VYPNUTA (pokyn uzivatele: „vypnul bych
	# ve hře automatizaci, spamuje to hru“). Nenacita se uz AUTOMATICKY z
	# `user://policy.json`; kdo ji chce, zapne ji PRIPOJEM na prikazove radce:
	#     godot --path . -- --policy             (vezme user://policy.json)
	#     godot --path . -- --policy=<cesta>     (jina cesta)
	# Bez prepinace je to NO-OP: `sim.policy` i `sim.executor` zustanou null
	# (`sim_world.gd:133`), takze kazdy tik se preskoci a replaye ani hash
	# se nemENI. Vypnuto je to i kdyz soubor existuje - to je ten rozdil.
	# (Samotne CTENI prepinacu je v `_parsuj_prepinace()`, protoze se podle
	# `--no-own-art` staví svet jeste pred timhle blokem.)
	if _policy_cesta != "" and FileAccess.file_exists(_policy_cesta) \
			and sim.load_policy(_policy_cesta):
		print("[main] politika nactena z ", _policy_cesta, " (zapnuta pripojmem --policy)")
	print("[main] sim spusten (seed ", DEFAULT_SEED, ", datovych souboru ", data.size(), ")")


func _parsuj_prepinace() -> void:
	# JEDNO misto pro prikazovou radku. Prepinace:
	#   --policy | --policy=<cesta> ... zapne automatizaci (M10, opt-in)
	#   --no-own-art ................. vypne vlastni art jako CELEK (A/B srovnani)
	#   --no-mods .................... ignoruje `user://mods/` (bere se jen
	#                                  zakladni vrstva obsahu; A/B a "cista hra")
	# Neznamy argument se NEPOLKNE tise - hodi se videt, kdyz se preklepne.
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a == "--policy":
			_policy_cesta = POLICY_PATH
		elif a.begins_with("--policy="):
			_policy_cesta = a.substr("--policy=".length())
		elif a == "--no-own-art":
			_vlastni_vypnuto = true
		elif a == "--no-mods":
			_mods_vypnuto = true
		elif a.begins_with("--"):
			print("[main] neznamy prepinac: ", a)


func _nacti_obsah() -> void:
	# Vrstvy obsahu (docs/04 §4.9). Rozbita deklarace nebo rozbity mod NESMI
	# shodit start - ale musi byt VIDET (chyby do warningu, cisla do logu).
	# `--no-mods` vypne jen MODY; zakladni deklarace se cte vzdy, aby cesty
	# k datum zustaly na jednom miste (jinak by existovaly dve cesty: s mody
	# a bez nich).
	content = ContentScript.new()
	var mods_dir: String = "" if _mods_vypnuto else ContentScript.MODS_DIR
	var pridano: int = content.discover(ContentScript.BASE_DECL, mods_dir)
	for chyba in content.errors():
		push_warning("app.main: obsah: " + str(chyba))
	var rep: Dictionary = content.report()
	print("[main] obsah: vrstev ", rep["layers"], " (", ", ".join(content.layer_ids()),
		"), souboru ", rep["files"], ", prekryti ", rep["overrides"],
		", chyb ", rep["errors"], ", manifest ", content.manifest_hash().substr(0, 12))
	if _mods_vypnuto:
		print("[main] mody VYPNUTY pripojnem --no-mods (bere se jen zakladni obsah)")
	elif pridano > 1:
		print("[main] mody: ", pridano - 1, " vrstva(y) z ", ContentScript.MODS_DIR)
	var chybejici: Array = content.missing_files()
	if not chybejici.is_empty():
		push_warning("app.main: obsah: " + str(chybejici.size())
			+ " deklarovanych souboru neexistuje: " + ", ".join(chybejici))
	items_data = content.path_or_default("data/items.json")
	skills_data = content.path_or_default("data/skills.json")
	help_data = content.path_or_default("data/help.json")


func _cesta(cesta: String) -> String:
	# `res://data/x.json` -> cesta z VRSTEV OBSAHU (mod muze prebit zaklad).
	# Vola se pro vsechno, co `app/main` predava systemum nebo cte samo; moduly
	# maji sve cesty jako PARAMETR (`_init`), takze se rozhoduje tady.
	if content == null:
		return cesta
	return content.path_or_default(cesta.trim_prefix("res://"))


func _nacti_vlastni_art() -> Array:
	# Vrstvy vlastniho artu z `assets/own-art.json` (granule `render.own_art`).
	# Vadna konfigurace se NESMI tvarit jako "vlastni art neni": kazda chyba se
	# vypise a hra jede na UO art - bezpecne, ale viditelne (docs/08 §8.6).
	if _vlastni_vypnuto:
		print("[main] vlastni art VYPNUT pripojmem --no-own-art (kresli se jen UO art)")
		return []
	var cfg: Dictionary = OwnArtScript.load_config()
	for chyba in cfg.get("errors", []):
		push_warning("app.main: vlastni art: " + str(chyba))
	if not bool(cfg.get("ok", false)):
		push_warning("app.main: konfigurace vlastniho artu neni v poradku - "
			+ "kresli se jen UO art (assets/own-art.json)")
		return []
	print("[main] vlastni art: ", cfg["layers"].size(), " vrstvy (",
		", ".join(_jmena_vrstev(cfg["layers"])), ")")
	return cfg["layers"]


func _jmena_vrstev(vrstvy: Array) -> Array:
	var out: Array = []
	for v in vrstvy:
		out.append(str(v.get("name", "?")))
	return out


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
	# SEZNAM SKILLU (D10, 2026-10-10): obnovuje se 2x/s a jen kdyz se hodnoty
	# zmenily (`_skill_klic` je otisk posledniho stavu). Bez toho by se uzly
	# prebavovaly 60x za sekundu kvuli cislu, ktere roste po desetinach.
	if skill_list != null:
		_skill_s += _delta
		if _skill_s >= SKILL_LIST_S:
			_skill_s = 0.0
			_osvezi_skilly()
	if debug_overlay != null:
		_debug_s += _delta
		if _debug_s >= DEBUG_OVERLAY_S:
			_debug_s = 0.0
			debug_overlay.update(_debug_values())
			_peak_ms = 0.0
	# Stavovy pruh se aktualizuje JEN kdyz se text zmeni (ne kazdy frame).
	# Hodnoty jdou z `entity.mobile` - `max_hp`/`max_stam`/`max_mana` plni
	# `Mobile._init` ze statu (`entity.stats`), takze nejsou opsane cisla.
	# ⚠⚠ SESSION D (2026-10-11) - VAHA A ZLATO BYLY NATVRDO NULA. Komentar tu
	# tvrdil "hrac dnes nic nema" (byla to pravda v M3), ale od `D10` dostava
	# hrac 16 nastroju a 60 zlata: stavovy pruh tedy hracovi UKAZOVAL `weight=0,
	# gold=0`, i kdyz mel 60 zlata. NamEReno sondou `_analyza/p56-start-pozorovani.gd`
	# (status bar rikal gold=0, `_starting_kit` hlasil zlata 60). Hrac, ktery
	# nezna hru, pak nepozna, jestli prodej neco vydelal.
	#   * VAHA je `container.weight_of(batoh)` - pocita se z `tiles.json`
	#     (jedina instance kontejneru, zadne druhe scitani tady),
	#   * ZLATO je `sim.vendor.gold_of(hrac)`: pravidlo "co je zlato"
	#     (`gold_coin` + art z dat) je v `sim.vendor`, ne tady.
	#   * `weight_max` se ZAMERNE neposila: hranice nese je ze statu (UO:
	#     40 + STR/3.5) a vymyslet ji tady by bylo pravidlo v klientovi.
	if status_bar == null or player == null:
		return
	_batoh()
	_recept()
	_prodejce_pozadavek()
	var vaha: int = container.weight_of(int(player.backpack)) if container != null else 0
	var zlato: int = vendor.gold_of(player) if vendor != null else 0
	var values: Dictionary = {
		"name": player.name,
		"hp": player.hp, "hp_max": player.max_hp, "max_hp": player.max_hp,
		"stam": player.stam, "stam_max": player.max_stam,
		"mana": player.mana, "mana_max": player.max_mana,
		"weight": vaha, "gold": zlato,
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
	# M5 (2026-10-10): stav souboje a sveta monster na obrazovce. Bez toho by
	# "hra vypadá, že nic nedělá" nešlo rozeznat od "monstrum v registru není".
	if registry != null and registry.has_method("size"):
		hodnoty["mobily"] = int(registry.size())
	if world_view != null and world_view.has_method("mobily_videt"):
		# POZOR: promenna je `world_view`, ne `view` - `view` je jen lokalni
		# jmeno v `_setup_world()`. Namerено 2026-10-11 (parse error).
		hodnoty["mobilu_videt"] = int(world_view.mobily_videt())
		hodnoty["tel"] = int(world_view.tela_videt())
	if combat != null and player != null:
		var boj: Dictionary = combat.state_of(int(player.serial))
		hodnoty["war"] = bool(boj.get("war", false))
		hodnoty["target"] = int(boj.get("target", 0))
		hodnoty["swing_ms"] = int(boj.get("delay_ms", 0))
	if death != null and player != null:
		hodnoty["duch"] = bool(death.is_ghost(int(player.serial)))
	if spawn != null and spawn.has_method("spawned_total"):
		hodnoty["spawned"] = int(spawn.spawned_total())
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
	# OKNO SKILLU (2026-10-10, D10 "herní základy"): ZAVRENE, dokud hrac
	# nezmackne `K` (jako `B` u batohu a `P` u pravidel). Obsah plni
	# `_osvezi_skilly()` z `player.skills` + `data/skills.json` (jmena) - UI samo
	# o skillech nic nevi a nic nemeni.
	skill_list = SkillListScript.new()
	skill_list.name = "SkillList"
	hud.add_child(skill_list)
	skill_list.visible = false
	# ⚠ VELIKOST JE POVINNA (stejna past jako u `ui.journal`): Control s vychozi
	# velikosti (0,0) text NEKRESLI, i kdyz data ma. `ui.skill_list` si ji sam
	# nedrzi (je to tenky klient), takze ji dostava odtud.
	skill_list.custom_minimum_size = Vector2(280.0, 320.0)
	skill_list.size = Vector2(280.0, 320.0)
	if not hud.register_window("skill_list", skill_list, Vector2(8.0, 560.0)):
		push_warning("app.main: okno skillu se nepodarilo zaregistrovat v HUD")
	# OBCHODNI OKNO (2026-10-10, D10): ZAVRENE; otevira se UDALOSTI
	# `gump_open{gump:"vendor"}` - hrac ho neotevira klavesou, ale pouzitim
	# vendora (`Command{t:"use"}`), stejne jako okno vyroby.
	vendor_gump = VendorGumpScript.new()
	vendor_gump.name = "VendorGump"
	hud.add_child(vendor_gump)
	vendor_gump.visible = false
	if not hud.register_window("vendor_gump", vendor_gump, Vector2(340.0, 60.0)):
		push_warning("app.main: obchodni okno se nepodarilo zaregistrovat v HUD")
	# ⚠ DO `loop.gump_okna` SE PRIDAVA AZ TADY, po vytvoreni okna: kdyz se
	# pridavalo driv (u okna vyroby), byl v seznamu `null` a udalost
	# `gump_open{gump:"vendor"}` nemel kdo prevzit - okno se neotevrelo
	# (namEReno 2026-10-10 sondou `p34-smycka.gd`: `gump_okna` melo
	# `["CraftGump", "null"]`).
	if loop != null:
		loop.gump_okna.append(vendor_gump)
	# NAPOVEDA (session D, 2026-10-11, granule `ui.hotkeys`): okno s klavesami
	# a s tim, co ve hre delat. JE OTEVRENE OD STARTU - kdo hru nezna, se jinak
	# nedozvi, co zmacknout ani co je cilem (zadani §D: "projde kratkou smycku
	# BEZ RADY"). Zavrit/otevrit ji jde klavesou `H` (nebo `F1`); obsah plni
	# `_osvezi_napovedu()` az PO registraci vazeb (`controller.setup`), protoze
	# se klavesy berou z `InputMap`.
	hotkeys = HotkeysScript.new()
	hotkeys.name = "Hotkeys"
	hud.add_child(hotkeys)
	if not hud.register_window("hotkeys", hotkeys, Vector2(8.0, 8.0)):
		push_warning("app.main: okno napovedy se nepodarilo zaregistrovat v HUD")
	hotkeys.otevri()
	# ⚠ VELIKOST JE POVINNA (stejna past jako u `ui.journal` a `ui.skill_list`):
	# Control s vychozi velikosti (0,0) text NEKRESLI, i kdyz data ma.
	hotkeys.custom_minimum_size = Vector2(440.0, 540.0)
	hotkeys.size = Vector2(440.0, 540.0)
	# DEBUG OVERLAY: neni to okno (nema titul ani se neposouva) - je to vrstva
	# textu v levem hornim rohu, VIDITELNA od startu, aby ji zachytil screenshot.
	# `F3` ji prepina (`app/player_controller`). Hodnoty plni `_debug_values()`.
	debug_overlay = DebugOverlayScript.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.position = Vector2(8.0, 8.0)
	hud.add_child(debug_overlay)
	# ⚠⚠ SESSION D (2026-10-11) - OVERLAY JE OD STARTU VYPNUTY. Byl videt vzdy
	# (rozhodnuti 2026-10-09: "aby se info zachytilo se screenshotem"), ale hra
	# je od `M4` pro LIDI: prvni obraz hry pak nesl `loc/state/gf/c fps/holes`
	# pres pulku sveta a hrac hru neznajici nevi, co z toho je pro nej.
	# Schopnost NEZMIZELA - `F3` ho zapne (a je to v napovede), takze
	# "zachytit se screenshotem" jde dal. Cesta zpet: jeden radek
	# `debug_overlay.visible = true` tady.
	debug_overlay.visible = false
	print("[main] debug overlay: VYPNUTY (F3 zapina, hodnoty kazdych ",
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
	# VLASTNI ART PO KUSECH (2026-10-11): vrstvy se nactou PRED cache a cache je
	# indexuje PRVNÍ, takze pro (kind, id) z vlastni sady vyhraje vlastni sprite
	# a vsechno ostatni zustane z UO. Vypnute je to pripojmem `--no-own-art`.
	_vlastni_art = _nacti_vlastni_art()
	view.nastav_vlastni_art(_vlastni_art)
	if _vlastni_art.is_empty():
		textures = TextureCache.new()
	else:
		textures = TextureCache.new(TextureCache.MANIFEST_PATH, TextureCache.MAX_BYTES,
			TextureCache.ATLAS_PREFIX, _vlastni_art)
	# Ikony do batohu jdou INJEKCI (`ui/` nesmi na `render/`, docs/04 §4.1).
	if backpack != null:
		backpack.nastav_textury(textures)
	view.setup(map, textures, _cesta("res://data/items.json"))
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
	# TABULKA DLAZDIC a KONTEJNER: jedina instance pro cely svet (docs/04 §4.2
	# `entity.container` - dve instance = duplikaty predmetu). `walk` dostava
	# stejnou instanci, aby se `tiles.json` nectlo dvakrat.
	# ⚠ CESTA JE PARAMETR (S1b, 2026-10-11): hodnoty predmetu jdou z vrstev
	# obsahu, takze mod muze prebit `data/items.json` i tady.
	tiledata = TiledataScript.new(_cesta("res://data/items.json"))
	container = ContainerScript.new(tiledata)
	# DVEŘE A SCHODY (S1b): zaklada je `app/main`, aby jejich cestu rozhodovaly
	# VRSTVY OBSAHU. Do teto chvile si je `sim.walk` zakladal sam z konstanty,
	# takze mod u `data/doors.json` / `data/stairs.json` fungoval zdanlive.
	# `sim.interaction` dostava TYTÉŽ instance - dvoje dvere = dve pravdy.
	doors = DoorsScript.new(_cesta("res://data/doors.json"))
	stairs = StairsScript.new(_cesta("res://data/stairs.json"))
	var walk = WalkScript.new(map, tiledata, stairs, doors)
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
	# (Instance uz je zalozena vyse - S1b: potrebuje ji `world.walk`.)
	# Batoh hrace: bez nej by sber i vyroba vracely `no_pack`. Vrstva 0x15
	# (`data/items.json`, art 0x4E75) je v UO batoh; `entity.equipment` jeste
	# neni, takze batoh nema vrstvu - je to serial v `player.backpack`.
	player.backpack = sim.next_serial()
	var batoh = ItemScript.new(int(player.backpack), 0x4E75, 1)
	batoh.layer = 0
	batoh.parent = serial
	items[int(player.backpack)] = batoh
	# START (2026-10-10, D10 "demo"): nastroje z DAT + startovni zlato. Do teto
	# chvile hrac dostaval VSECHNY nastroje a zadne zlato - obchod se tim dal
	# jen prohlizet, ne pouzit. Nastroje zustavaji (demo ma byt hratelne hned,
	# ne o nakupovani kladiva), zlato je nove - aby slo neco KOUPIT i prodat.
	var start: Dictionary = _starting_kit()
	var nastroju: int = int(start["nastroju"])
	# STANICE VE SVETE (20. session): kovadlina a vyhen. NAMERENO sondou
	# `_analyza/p24-vyroba.gd`: v okoli Britainu (160 dlazdic) NENI zadna
	# stanice jako statik mapy, takze bez tohohle by se ruda nedala vytavit -
	# `sim.craft` sice stanici jako PREDMET umi (`_station_near`), ale nikdo
	# ji do sveta nedaval. Dava se VEDLE hrace, aby na ni hrac dosahl (2 dlazdice).
	var stanic: int = _postav_stanice()
	# BALVANY (RUDNÉ ŽÍLY) VEDLE HRÁČE (2026-10-10, D10 „demo“): nejbližší ruda
	# na této mapě je **132 dlaždic** od Britainu (`_analyza/p35c-sonda-hory.gd`),
	# ale kovadlina, výheň i prodejce stojí u Britainu. Než vznikne cesta nebo
	# `world.regions` (doly), stojí tady pár balvanů jako PŘEDMĚTY na zemi -
	# `sim.harvest` je umí těžit (`_item_tile`, art 0x453B–0x454F).
	# ⚠ Je to VĚDOMÝ SEŠITEK pro demo, ne náhrada mapy: `_analyza/p36-smycka.gd`
	# měří, že se z nich dá vytěžit ruda. Cesta zpět: smazat tohle volání.
	var balvanu: int = _postav_balvany()
	# PRODEJCE (2026-10-10, D10): do sveta se postavi JEDEN kovar (podle jmena
	# `blacksmith`) - bez vendora ve svete se obchod neda vubec spustit.
	# ⚠ PORADI JE POVINNE: `sim.vendor` se zaklada TADY, pred postavenim
	# prodejce. NamEReno 2026-10-10: kdyz se zakladal pozdeji, `_postav_vendora`
	# videl `vendor == null`, prodejce se nepostavil a sonda `p34-smycka.gd`
	# hlasila "ve svete stoji prodejce (serial 0)". Modul nema `tick` (restock
	# je LINIVY - doplni se pri pristupu, jako v referenci), takze ho `SimWorld`
	# jen preskoci; v `systems` ale byt MUSI, protoze `sim.interaction` ho
	# odtud bere pro `Command{t:"use"}`.
	# Barva kuze (granule `render.hue`, sada `HUE_SKIN` z `hues.json`). Bez ni je
	# telo 400 sedive: art z `anim.mul` je jen rampa jasu, barvu dava hue.
	# V UO znamena `hue == 0` "zadna barva", proto se sada dava jen kdyz je 0.
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
	sim.systems["skill_gain"] = SkillGainScript.new(registry, sim.rng(), sim.clock(), sim.events(),
		_cesta("res://data/balance.json"))
	# Sber a vyroba (16. session): obe dostavaji STEJNY registr, kontejner,
	# slovnik predmetu a RNG/clock z `SimWorld`. `sim.interaction` je pak najde
	# v `SimWorld.systems` a prestane na ne vracet `not_available`.
	harvest = HarvestScript.new(map, tiledata, registry, sim.rng(), sim.clock(),
		sim.events(), sim.systems["skill_gain"], container, sim, items)
	sim.systems["harvest"] = harvest
	# CESTY JSOU PARAMETRY (S1b): recepty i tabulka predmetu jdou z vrstev obsahu.
	craft = CraftScript.new(container, items, map, tiledata, sim.systems["skill_gain"],
		sim, sim.rng(), sim.clock(), sim.events(), registry,
		_cesta("res://data/recipes.json"), _cesta("res://data/items.json"))
	sim.systems["craft"] = craft
	# Obecna interakce (20. session): `sim.interaction` dostava STEJNY kontejner,
	# registr a slovnik predmetu jako sber/vyroba (dve instance = duplikaty).
	# ⚠ DVEŘE UZ EXISTUJI (S1b, 2026-10-11): do te doby tu bylo `null` s
	# poznamkou "world.doors zatim neexistuje" - jenze od chvile, kdy je zaklada
	# `app/main` (kvuli ceste z vrstev), se SEM predavaji TYTÉŽ instance.
	# Kdyby tu zustalo `null`, mod i zaklad by meli dvoje dvere.
	interaction = InteractionScript.new(sim, sim.events(), doors, container, registry, items,
		_cesta("res://data/skills.json"))
	sim.systems["interaction"] = interaction
	# MERENI PRO MODY (S1b): co si hra OPRAVDU nacetla - cisla se meni, kdyz mod
	# prebije `data/doors.json` / `data/stairs.json` / `data/recipes.json`, a
	# `loaded_path()` u `data/items.json`. E2E sonda (`_analyza/p67-*.py`) cte
	# tenhle radek; kdyby cesta zustala konstantou, cisla by byla stejna.
	print("[main] data modulu: dvere ", doors.category_count(), " kategorii, schody ",
		stairs.group_count(), " skupin, receptu ", craft.recipe_count(),
		", item typu ", ItemScript.typ_count(), " z ", ItemScript.loaded_path())
	# TLACITKO "use" V SEZNAMU SKILLU (D10): UI jen OHLASTI, co hrac zmackl
	# (`ui/` nesmi menit stav simulace); tady se z toho stane `Command`.
	# `Command{t:"skill"}` dnes v `sim/commands.gd` NENI, takze se posle jen
	# tehdy, kdyz ho smlouva zna - jinak se rekne proc (zadne tiche nic).
	if skill_list != null and not skill_list.use_pressed.is_connected(_on_skill_use):
		skill_list.use_pressed.connect(_on_skill_use)
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

	# REGENERACE (2026-10-10, `sim.regen`): doplnuje hp/stam/mana kazdy tik.
	# Poradi je v `SimWorld.SYSTEM_ORDER` (hned za `poison`) - tady se jen
	# registruje instance. `sim.hunger` zatim NEEXISTUJE, proto `null`; modul to
	# hlasi pres `hunger_gate_on()` a hlad jen zdvojnasobi interval hp (nic
	# nevymysli). ⚠ `stamina_drain_model` je dnes `"never"` (`data/balance.json`),
	# takze se stamina vubec nespotrebovava a regenerace je zatim videt jen
	# v hp/mane - az se drain prepne na `run_only`, teprve se projevi i u staminy
	# (a to je zmena `sim.movement`, ne tohohle modulu).
	sim.systems["regen"] = RegenScript.new(registry, sim.clock(), null)

	# OBCHOD (2026-10-10, D10): sklad a ceny z `data/vendors.json`. ⚠ ZAKLADA SE
	# TU, az PO `registry = sim.registry` - kdyz vznikl driv, dostal `registry`
	# jeste `null` a `vendor.buy()` pak hlasilo `no_mobile` (namEReno 2026-10-10
	# sondou `p34-smycka.gd`). Modul nema `tick` (restock je LINIVY - doplni se
	# pri pristupu k vendorovi jako v referenci), takze ho `SimWorld` jen
	# preskoci; v `systems` ale byt MUSI, protoze `sim.interaction` ho odtud
	# bere pro `Command{t:"use"}`.
	vendor = VendorScript.new(container, items, tiledata, registry, sim,
		sim.clock(), sim.events())
	sim.systems["vendor"] = vendor
	var prodanych: int = _postav_vendora(registry)

	# --- M5: SYSTEMY SOUBOJE, SMRTI, LOOTU, AI A SPAWNU -------------------
	# PORADI JE POVINNE (zavislosti konstruktorem), proto se zakladaji tady a
	# ne po jednotlivych kusech vys:
	#   loot  -> zna serialy (tela), RNG a kontejner
	#   decay -> zna hodiny a kontejner (rozpad predmetu i tel)
	#   death -> zna REGISTR (kdo umrel), kontejner (obsah tela), decay (rozpad)
	#            a loot (co monstrum necha) - bez lootu by telo bylo prazdne
	#            a `loot_reason` by to rekl
	#   combat -> zna zbrane/zbroje z DAT, smrt (kdo umre) a vybavu (bonusy)
	#   equipment -> vybava HRACE (vrstvy, bonusy) pro combat
	#   ai     -> zna movement (kroky) a combat (utok)
	#   spawn  -> zna monsters/spawns z DAT a registr (kam mobily dat)
	# Do `sim.systems` se registruji VSECHNY: `SimWorld.SYSTEM_ORDER` je radi
	# a `sim.commands` je odtud bere (dynamicky routing).
	loot = LootScript.new(container, items, sim.rng(), sim.events(), sim,
		_cesta("res://data/items.json"), _cesta("res://data/vendors.json"), _cesta("res://data/balance.json"))
	sim.systems["loot"] = loot
	decay = DecayScript.new(sim.clock(), sim.events(), container, items)
	sim.systems["decay"] = decay
	death = DeathScript.new(registry, container, items, sim.events(), sim, decay,
		0, _cesta("res://data/balance.json"), loot, self)
	death.set_player(serial)
	sim.systems["death"] = death
	equipment = EquipmentScript.new(registry, container, items, tiledata)
	combat = CombatScript.new(registry, null, items, equipment, null, sim.rng(),
		sim.clock(), sim.events(), death, _cesta("res://data/weapons.json"),
		_cesta("res://data/armor.json"), _cesta("res://data/balance.json"),
		_cesta("res://data/skills.json"))
	sim.systems["combat"] = combat
	poison = PoisonScript.new(registry, sim.rng(), sim.clock(), sim.events())
	sim.systems["poison"] = poison
	ai = AiScript.new(registry, movement, combat, sim.clock(), sim.events(), sim.rng())
	if ai.has_method("set_player"):
		ai.set_player(serial)
	sim.systems["ai"] = ai
	# KDO JE HRAC v souboji (session D): bez toho hlasky zneli vzdy z pohledu
	# hrace ("You hit it for 9 damage."), i kdyz udeřilo monstrum - hrac nemohl
	# poznat, ze je napadeny (namEReno: hp 87 -> 65 a v zurnalu ctyri "You hit
	# it..."). `sim.ai` dostava stejnou informaci uz od M5.
	if combat.has_method("set_player"):
		combat.set_player(serial)
	# ⚠ DATA SE PREDAVAJI PRIMO (2026-10-11): `sim.spawn` umi i cestu, ale
	# namEReno: kdyz dostal `null` a cetl si soubor sam, prisla do
	# `_load_monsters` cesta MISTO dat ("neni seznam") a monstra se nevytvorila.
	# `app/main` vi, kde data jsou, tak je precte a preda hodnotou.
	# Kompatibilita: 8. a 9. argument zustavaji cesty (pro pripadne dalsi
	# volajici), ale rozhoduje predany obsah.
	var d_spawns = _read_json_file(_cesta("res://data/spawns.json"))
	var d_monstra = _read_json_file(_cesta("res://data/monsters.json"))
	spawn = SpawnScript.new(registry, sim, sim.clock(), sim.events(), sim.rng(),
		d_spawns, d_monstra, _cesta("res://data/spawns.json"), _cesta("res://data/monsters.json"))
	sim.systems["spawn"] = spawn
	# SPAWN BODY ZE SOUCASTI PREDANYCH DAT: registrace je tady, protoze
	# `sim.spawn._init` cte data jen jako zaznamy; body zaklada volajici
	# (`register` vraci index a je jedine misto, kde vznikaji).
	var bodu: int = _zaregistruj_body(d_spawns)
	print("[main] spawn: dat monster ", (d_monstra as Array).size() if d_monstra is Array else -1,
		", typu ", spawn.monster_types().size(), ", bodu ", bodu)
	# STAVOVE ZDROJE (docs/04 §4.7): kdo ma stav, ktery patri do save a hashe,
	# se zaregistruje. Bez toho by se smernice boje, duchove, fronta rozpadu,
	# stavy AI a tabulka spawnu po `save -> load` ztratily (a round-trip by
	# hlásil jiný `state_hash`). `loot` stav nema (je to jen pravidlo).
	sim.register_state_source("combat", combat)
	sim.register_state_source("death", death)
	sim.register_state_source("decay", decay)
	sim.register_state_source("ai", ai)
	sim.register_state_source("spawn", spawn)
	# MONSTRA VIDET HNED (2026-10-10): hřbitov u Britainu je od hráče 120 dláždic,
	# takže by hráč na snímku žádné monstrum neměl. Vedle hráče proto stojí
	# TŘI monstra z téhož bodu (stejná data jako spawn) - je to VĚDOMÝ SEŠITEK
	# pro demo (stejná třída jako `_postav_stanice` a `_postav_balvany`).
	# Cesta zpět: smazat volání `_postav_monstra_u_hrace()`.
	var monster: int = _postav_monstra_u_hrace()
	# ZBRAN DO RUY (M5, ROZHODNUTI PRO DEMO): hrac dostaval VSECHNY NASTROJE,
	# ale ZADNOU ZBRAN v ruce - a boj beze zbrane je `damage` 1 (wrestling),
	# takze kostlivec s 38 hp se nedal zabit (namEReno: 20 swingu = 20 damage).
	# `_nasad_zbran_hraci()` vezme prvni predmet z batohu, ktery je v
	# `data/weapons.json`, a nasadi ho na vrstvu 1 (ruka).
	var zbran: String = _nasad_zbran_hraci()
	print("[main] M5: loot+decay+death+combat+poison+ai+spawn | spawn bodu ",
		bodu, ", monster u hrace ", monster, ", zbran ", zbran)
	# ⚠ CILE INTERAKCE SE NESMI PREKRYVAT (session D): kdyz je na jedne
	# dlazdici uzel suroviny, stanice i bytost, klient posle jen cil a SIM
	# vybere "co se hodi" podle jedne role - zbytek je TICHY (`no_pair`).
	# NamEReno: balvan na dlazdici vyhne = 0 rudy po 60 pokusech. Kontrola je
	# proto VIDITELNA pri startu (a sonda `_analyza/p58-smycka-hracem.gd` ji
	# meri nezavisle).
	var kolize: Array = _zkontroluj_cile_interakce()
	print("[main] cile interakce: ", _cile_interakce.size(), " dlazdic, kolizi ",
		kolize.size(), ("" if kolize.is_empty() else " -> " + str(kolize)))

	view.set_registry(registry)
	view.set_player(player)
	if view.has_method("set_mobily"):
		# Kresleni ostatnich mobili, tela a jmen (M5) - bez toho by monstrum
		# existovalo v simulaci, ale na obrazovce nebylo.
		view.set_mobily(registry, container, items)
	if view.has_method("nastav_decay"):
		view.nastav_decay(decay)
	# ROZPAD PREDMETU NA ZEMI (M5): kdo predmety poklada, musi to OHLAST
	# (`sim.decay` je jedine misto, kde se rozpady pocitaji). Tydka se to
	# stanic (kovadlina/vyhen), balvanu a startovniho batohu - bez toho by
	# predmety na zemi zustaly navzdy (60 min je smlouva, docs/05 §5.4).
	var hlaseno: int = 0
	# POZOR NA JMENO: `serial` je v `_setup_player` uz jednou deklarovany
	# (`var serial: int = sim.next_serial()`), takze druha deklarace tehoz jmena
	# v teze funkci je PARSE ERROR ("already declared"). Namerено 2026-10-11.
	for serial_predmetu in items.keys():
		var it = items[serial_predmetu]
		if it != null and int(it.parent) == 0:
			decay.register(it)
			hlaseno += 1
	print("[main] rozpad: registrovanych predmetu na zemi ", hlaseno)
	controller = get_node_or_null("PlayerController")
	if controller == null:
		push_warning("app.main: ve scene chybi uzel PlayerController - hrac se nepohne")
		return
	controller.setup(player, sim, loop.input_map, movement, view, loop)
	controller.backpack = backpack      # klavesa `B` prepina okno batohu
	controller.policy_panel = policy_panel   # klavesa `P` ukaze okno pravidel
	controller.skill_list = skill_list   # klavesa `K` ukaze seznam skillu (D10)
	controller.hotkeys = hotkeys         # klavesa `H`/`F1` ukaze napovedu (D)
	controller.debug_overlay = debug_overlay   # klavesa `F3` prepina overlay
	controller.okno = self              # klavesa `F2` prepina fullsize (bod 5.2)
	# NAPOVEDA A UVOD DO ZURNALU (session D): az TEDY, po `controller.setup()`,
	# protoze se klavesy berou z `InputMap` (registruje je `register_actions()`)
	# a z toho, co hra OPRAVDU umi. Kdyby se skladaly driv, byla by v napovede
	# prazdna mista - a to je presne "napoveda, ktera lze".
	var napoveda_radku: int = _osvezi_napovedu()
	var uvod_radku: int = _hlaseni_uvod()
	print("[main] napoveda: ", napoveda_radku, " radku (data/help.json), uvod ",
		uvod_radku, " zprav do zurnalu")
	print("[main] hrac: serial ", serial, " na ", player.pos, " (", map.land_at(player.pos.x, player.pos.y),
		" land), hue ", player.hue, " (0 = bez barvy), barvy: ", view.hue_stats(),
		", nastroju v batohu ", nastroju, ", pocatecnich skillu ", skillu,
		", prodejcu ", prodanych, ", balvanu ", balvanu, ", zlata ", int(start["zlata"]),
		", systemu v sim: ", sim.systems.keys())


func _starting_kit() -> Dictionary:
	# CO HRAC DOSTANE NA START (2026-10-10, D10 „demo“). Nahrazuje puvodni
	# `_give_tools()`, ktery daval VSECHNY nastroje a ZADNE zlato.
	#
	# Nastaveni je VEDOME a je to rozhodnuti, ne mereni:
	#   * NASTROJE zustavaji vsechny - demo ma byt hratelne hned, ne o tom, ze
	#     hrac pul hodiny shani kladivo. Bere se z DAT (`data/items.json`),
	#     kategorie `tool`, jeden od kazdeho typu.
	#   * ZLATO navic: **60** = tri nejlevnejsi veci u kovare (krumpac 21 g).
	#     Bez nej se obchod dal jen prohlizet, ne pouzit - a prodej bez nakupu
	#     nema co prodat. Castka je zamerne mala: vydelavat se ma prodejem.
	#   * Art zlata je z `data/vendors.json` (`config.gold_art`), ne z hlavy -
	#     namEReno 2026-10-10: zlato ma vic artu podle velikosti hromady.
	var zlata: int = 60
	if not FileAccess.file_exists(items_data):
		push_warning("app.main: chybi " + items_data + " - hrac nedostane zadny nastroj")
		return {"nastroju": 0, "zlata": 0}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(items_data))
	if not (parsed is Array):
		push_warning("app.main: " + items_data + " neni seznam - hrac nedostane zadny nastroj")
		return {"nastroju": 0, "zlata": 0}
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
		# grafik: krumpac 2 arty, sekera 3, kladivo 2. Do te session se bral
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
	# ZLATO: art z dat vendora (viz komentar vyse).
	var gold_art: int = 0x4EED
	if vendor != null and vendor.has_method("gold_art"):
		gold_art = int(vendor.gold_art())
	elif vendor != null:
		var gd: Dictionary = vendor.stats()
		if int(gd.get("gold_art", 0)) > 0:
			gold_art = int(gd["gold_art"])
	var mince = ItemScript.new(sim.next_serial(), gold_art, zlata)
	if container.add(int(player.backpack), mince):
		items[int(mince.serial)] = mince
	else:
		push_warning("app.main: startovni zlato se do batohu neveslo - hrac nema cim platit")
		zlata = 0
	print("[main] start: nastroju ", pocet, " (", ", ".join(PackedStringArray(jmena)),
		"), zlata ", zlata, " (art ", gold_art, ")")
	return {"nastroju": pocet, "zlata": zlata}


static func start_skills(balance_skills: Dictionary, skills_data,
		cesta: String = SKILLS_DATA) -> Dictionary:
	# Nazev skillu -> `id` (z `data/skills.json`) a hodnota v desetinach.
	# Vraci `{id: hodnota}`; nezname jmeno se NAHLASI a preskoci - ticha nula by
	# vypadala jako "skill se pridal", i kdyz se preklepl nazev.
	# `cesta` je jen pro HLASKU (od 2026-10-11 ji volajici predava ROZLISENOU
	# pres vrstvy obsahu) - funkce je `static`, takze na `skills_data` (ktery se
	# jmenuje stejne jako parametr!) sahat nesmi.
	var podle_jmena: Dictionary = {}
	if skills_data is Array:
		for rec in skills_data:
			if rec is Dictionary and rec.has("name") and rec.has("id"):
				podle_jmena[str(rec["name"])] = int(rec["id"])
	var out: Dictionary = {}
	for jmeno in balance_skills.keys():
		if not podle_jmena.has(str(jmeno)):
			push_warning("app.main: skill '" + str(jmeno)
				+ "' z `player_start_skills` neni v " + cesta)
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
	if FileAccess.file_exists(skills_data):
		data = JSON.parse_string(FileAccess.get_file_as_string(skills_data))
	else:
		push_warning("app.main: chybi " + skills_data + " - pocatecni skilly se nepridaji")
		return 0
	var hodnoty: Dictionary = start_skills(mapa, data, skills_data)
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


func _osvezi_skilly() -> void:
	# Obsah okna se skilly (D10, 2026-10-10). UI je TENKY KLIENT: tady se
	# precte `player.skills` a jmena z `data/skills.json` a preda se hotovy
	# seznam radku. Kdyz se nic nezmenilo, UI se neprebavuje.
	var radky: Array = _radky_skillu()
	var klic: Array = []
	for radek in radky:
		klic.append([int(radek.get("id", -1)), int(radek.get("value", 0)),
			int(radek.get("lock", 0))])
	if klic == _skill_klic:
		return
	_skill_klic = klic
	skill_list.update(radky)


func _radky_skillu() -> Array:
	# Radky pro `ui.skill_list`: `{id, name, value (desetiny), lock}`. Jmena
	# jsou v `data/skills.json` (58 skillu, `id` je index); chybejici jmeno se
	# NEVYMYSLI - pouzije se "#<id>", aby bylo videt, ze data chybi.
	var radky: Array = []
	if player == null or player.skills == null:
		return radky
	var jmena: Dictionary = {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(skills_data))
	if parsed is Array:
		for rec in parsed:
			if rec is Dictionary and rec.has("id"):
				jmena[int(rec["id"])] = str(rec.get("name", ""))
	else:
		push_warning("app.main: " + skills_data + " neni seznam - skilly budou bez jmen")
	for i in range(SkillsScript.SKILL_COUNT):
		radky.append({
			"id": i,
			"name": str(jmena.get(i, "#" + str(i))),
			"value": int(player.skills.value(i)),
			"lock": int(player.skills.lock(i)),
		})
	return radky


func _on_skill_use(skill: int) -> void:
	# Stisk "use" v seznamu skillu. Simulace dnes `Command{t:"skill"}` NEZNA
	# (`sim/commands.gd` -> `REQUIRED` ho nema), takze se NIC neposle - a je to
	# VIDET slovem, ne tichem ("nula a prazdno nejsou uspech", `docs/09` §9.6).
	# Az command vznikne (patri do sveho zadani, ne sem), zmeni se jen tenhle
	# blok: `sim.enqueue({t:"skill", skill})`.
	if skill < 0 or skill >= SkillsScript.SKILL_COUNT:
		print("[main] skill use: ", skill, " - mimo rozsah 0..",
			SkillsScript.SKILL_COUNT - 1, ", neposilam")
		return
	print("[main] skill use: ", skill,
		" - Command{t:\"skill\"} neni ve smlouve (sim/commands.gd), neposilam")


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
	if not FileAccess.file_exists(items_data):
		push_warning("app.main: chybi " + items_data + " - stanice se nepostavi")
		return 0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(items_data))
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
			push_warning("app.main: role '" + role + "' v " + items_data + " neni - stanice se nepostavi")
			continue
		var art: int = int(podle_role[role]) + ITEM_OFFSET
		var predmet = ItemScript.new(sim.next_serial(), art, 1)
		predmet.parent = 0
		predmet.pos = Vector3i(BRITAIN.x + int(stanice["x"]), BRITAIN.y + int(stanice["y"]),
			int(player.pos.z))
		items[int(predmet.serial)] = predmet
		postaveno += 1
		_hlaseni_do_zurnalu("A " + role + " stands to the " + str(stanice["smer"])
			+ ". (press " + _kody_akce("interact", " or ") + " on it)")
		print("[main] stanice: ", role, " (art ", art, ") na ", predmet.pos)
	return postaveno


func _postav_vendora(reg) -> int:
	# ⚠ REGISTR JDE ARGUMENTEM, ne z `self.registry`: v teto chvili je clenská
	# promenna jeste `null` (`_setup_world` ji teprve nastavi) a `reg.register()`
	# by spadl na "Nonexistent function 'register' in base 'Nil'" - namEReno
	# 2026-10-10 sondou `p34-smycka.gd` (prodejce se pak nepostavil a sonda
	# hlasila "serial 0"). Clenska promenna se plni pozdeji, proto argument.
	# KOVAR DO SVETA (2026-10-10, D10). Vybere se podle JMENA (`blacksmith`),
	# ne podle poradi v datech - poradi je vlastnost generatoru, ne smlouva.
	# Stojí VEDLE hrace (dosah `sim.vendor.VENDOR_RANGE` = 2 dlazdice), aby se
	# dal hned pouzit: `use` na nej -> `gump_open{gump:"vendor"}` -> obchodni okno.
	#
	# `mob.ai` = {"state": "vendor"} je to, co `sim.interaction.describe()`
	# pouziva pro rozpoznani vendora (docs/05 §5.3); bez toho by to byl "mobile"
	# a `use` by nabidl boj/rozhovor, ne obchod.
	if vendor == null:
		push_warning("app.main: `sim.vendor` neni - prodejce se nepostavi")
		return 0
	var v: int = vendor.vendor_index("blacksmith")
	if v < 0:
		push_warning("app.main: v `data/vendors.json` neni vendor 'blacksmith'")
		return 0
	if player == null or reg == null:
		return 0
	# ⚠⚠ SESSION D (2026-10-11) - KOVAR NESMI STAT NA DLAZDICI VYHNĚ.
	# Do teto chvile byl na `player.pos + (1, 0)`, tedy NA STEJNE DLAZDICI jako
	# vyhen (`_postav_stanice`: forge na +1,0). Jenze "pouzij, co je pod
	# kurzorem" u bytosti posila cil `{kind:"mobile"}` - a hrac tim padem
	# nemohl vytavit rudu (vyhen na te dlazdici se uz nikdy nevybral).
	# NamEReno: `[main] stanice: forge ... na (1496, 1630, 10)` a
	# `[main] prodejce: ... na (1496, 1630, 10)` ve stejnem behu.
	# Kovar je proto o dlazdici dal (dosah `VENDOR_RANGE` = 2, takze na nej
	# hrac porad dosahne) a sonda `_analyza/p58-smycka-hracem.gd` meri, ze se
	# cile interakce na jedne dlazdici NEPREKRYVAJI.
	var pos := Vector3i(int(player.pos.x) + 2, int(player.pos.y), int(player.pos.z))
	var kovar = MobileScript.new(sim.next_serial(), PLAYER_BODY, pos)
	kovar.name = "Blacksmith"
	kovar.ai = {"state": "vendor"}
	reg.register(kovar)
	prodejce = int(kovar.serial)
	# Dosah se MUSI nastavit: bez pozice `sim.vendor` odpovi `no_vendor_pos`.
	if not vendor.nastav_pozici(v, pos):
		push_warning("app.main: pozici vendora se nepodarilo nastavit")
	if not vendor.zaregistruj_serial(prodejce, v):
		push_warning("app.main: serial vendora se nepodarilo zaregistrovat")
	# Otevreny obchod pri startu? NE - hrac si ho otevre sam (pouzij na vendora).
	# ⚠ SESSION D: do teto chvile tu stalo "use him to trade", ale `use` na
	# bytost se z klienta NEDALO poslat (`object_command` nikdo nevolal) - rada
	# byla nesplnitelna. Ted ji plni `interact` na bytost a hlaska rika cim.
	_hlaseni_do_zurnalu("A blacksmith is here. (press "
		+ _kody_akce("interact", " or ") + " on him to trade)")
	print("[main] prodejce: serial ", prodejce, " (", str(vendor.vendor_ids()[v]),
		") na ", pos, " | k dohledani pres `use`")
	return 1


func _read_json_file(cesta: String):
	# Nacteni JSONu pro systemy, ktere chteji DATA (ne cestu): `sim.spawn` ma
	# `spawns`/`monsters` jako prvni vstupy a kdyz dostane `null`, cte si je
	# samo - jenze prave ta cesta se 2026-10-11 ukazala jako nespolehliva
	# (viz `sim/world/spawn.gd:_init`). Predavame proto hotova data.
	# Chybejici soubor vraci `null` a volajici to HLASI (zadna ticha nula).
	if not FileAccess.file_exists(cesta):
		push_warning("app.main: chybi " + cesta)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(cesta))


func _nasad_zbran_hraci() -> String:
	# NASADI ZBRAN HRACI (M5): prvni predmet z batohu, jehoz ART je v
	# `data/weapons.json` (art = `tile - 0x4000`, kontrakt M5 §3.1). Vrstva je
	# z dat zbrane (`layer`); kdyz ji data nemaji (`null`), pouzije se 1 (ruka).
	#
	# POZOR: primo pres `player.equip[vrstva] = serial` - `entity.equipment.equip`
	# chce predmet a v tomto miste je `equipment` uz vytvorena, ale volani by
	# muselo projit hledanim podle artu znovu. Tady jde o JEDNOZNACNY start.
	if player == null:
		return "(bez hrace)"
	if not FileAccess.file_exists(_cesta("res://data/weapons.json")):
		push_warning("app.main: chybi data/weapons.json - hrac zustane bez zbrane")
		return "(bez dat zbrani)"
	var zbrane = JSON.parse_string(FileAccess.get_file_as_string(_cesta("res://data/weapons.json")))
	if not (zbrane is Array):
		return "(data zbrani nejsou seznam)"
	var podle_artu: Dictionary = {}
	for rec in zbrane:
		if not (rec is Dictionary):
			continue
		# ⚠ `int(null)` v Godotu 4 HODI "Nonexistent 'int' constructor" (nemeni
		# se na 0!) - namEReno 2026-10-11. Proto se hodnota nejdriv prevezme a
		# `null` se vyradi, teprve pak se pretypuje.
		var art_h: Variant = rec.get("art")
		if art_h == null:
			continue
		podle_artu[int(art_h)] = rec
	var nasel: int = 0
	var diag: Array[String] = []
	for serial in container.contents(int(player.backpack)):
		var it = items.get(int(serial))
		if it == null:
			continue
		var tile_predmetu: int = int(it.tile)
		var art: int = tile_predmetu - ITEM_OFFSET
		diag.append(str(tile_predmetu) + "->" + str(art) + ("*" if podle_artu.has(art) else ""))
		if not podle_artu.has(art):
			continue
		var rec: Dictionary = podle_artu[art]
		# ⚠ `layer` je v datech `null` (`pending-tiledata`, docs/06 §6.4) a
		# `int(null)` HODI chybu - nejdriv se vyradi null, pak se pretypuje.
		var vrstva_h: Variant = rec.get("layer")
		var vrstva: int = 1
		if vrstva_h != null:
			vrstva = int(vrstva_h)
		if vrstva <= 0:
			vrstva = 1
		player.equip[vrstva] = int(it.serial)
		it.layer = vrstva
		it.parent = int(player.serial)
		return "%s (art %d, vrstva %d, dmg %s-%s)" % [str(rec.get("name", "?")), art,
			vrstva, str(rec.get("min_damage", "?")), str(rec.get("max_damage", "?"))]
	push_warning("app.main: v batohu neni zbran z data/weapons.json (art: "
		+ ", ".join(diag) + ")")
	return "(zadna zbran v batohu)"


func corpse_art_for(body: int) -> int:
	# Art TELA podle cisla tela tvora (`sim.death` si ho bere odsud, kdyz ho
	# `app/main` preda jako `art_provider`). V UO je to `0x4000 + body`
	# (`_src/servuo` `Scripts/Items/Corpses/Corpse.cs`: mrtvola kresli staticky
	# art tvora) - a ten v nasem manifestu JE, kdezto `DEFAULT_CORPSE_ART`
	# (0x2006) v nem NENI (namEReno 2026-10-11: telo se vytvorilo a nebylo
	# videt). Kontrola proti manifestu je tu proto, aby se nevracel art, ktery
	# v atlase chybi - "telo existuje, ale neni videt" je presne to, co nechceme.
	var art: int = 0x4000 + int(body)
	if art <= 0x4000 or art > 0xFFFF:
		return 0
	if _atlas_arts.is_empty():
		_atlas_arts = _nacti_atlas_arty()
	if _atlas_arts.has(art):
		return art
	push_warning("app.main: art tela 0x%X (telo %d) v manifestu neni - telo se nekresli"
		% [art, int(body)])
	return 0


func _nacti_atlas_arty() -> Dictionary:
	# Mnozina art ID, ktera jsou v manifestu atlasu (`kind == "item"`, art ID =
	# `id + 0x4000`). Nacte se JEDNOU - je to jen pro kontrolu artu tela.
	var out: Dictionary = {}
	var cesta: String = "res://assets/uo/manifest.json"
	if not FileAccess.file_exists(cesta):
		push_warning("app.main: chybi " + cesta + " - art tel se neoveri")
		return out
	var d = JSON.parse_string(FileAccess.get_file_as_string(cesta))
	if not (d is Dictionary):
		return out
	for sp in (d as Dictionary).get("sprites", []):
		if sp is Dictionary and str(sp.get("kind", "")) == "item":
			out[int(sp.get("id", -1)) + 0x4000] = true
	return out


func _zaregistruj_body(d) -> int:
	# SPAWN BODY: kazdy bod z `data/spawns.json` se zaregistruje do `sim.spawn`
	# (index je jeho identita pro `alive_at`). Data dostava hotova volajici -
	# viz komentar u `SpawnScript.new` v `_setup_player`.
	if spawn == null:
		push_warning("app.main: `sim.spawn` neni - spawn body se nezaregistruji")
		return 0
	if not (d is Dictionary):
		push_warning("app.main: data/spawns.json nema tvar objektu")
		return 0
	var body = (d as Dictionary).get("points", [])
	if not (body is Array):
		push_warning("app.main: data/spawns.json nema seznam `points`")
		return 0
	var zapsano: int = 0
	for bod in body:
		if bod is Dictionary and spawn.register(bod) >= 0:
			zapsano += 1
			print("[main] spawn bod: ", str((bod as Dictionary).get("id", "?")),
				" na ", int((bod as Dictionary).get("x", 0)), ",",
				int((bod as Dictionary).get("y", 0)), " max ",
				int((bod as Dictionary).get("max", 0)))
	return zapsano


func _postav_monstra_u_hrace() -> int:
	# MONSTRA VEDLE HRACE (M5, VĚDOMÝ SEŠITEK pro demo - stejná třída jako
	# `_postav_stanice` a `_postav_balvany`). Důvod je naměřený: hřbitov
	# z `data/spawns.json` je od Britainu daleko, takže by na snímku nebylo co
	# zabít a "hráč zabije monstrum" by nešlo ukázat. Data (typy, staty, skilly)
	# jdou Z MONSTER.JSON téhož bodu, ne z kódu.
	#
	# Cesta zpět: smazat volání v `_setup_player` (a ideálně i tuhle funkci).
	if spawn == null or player == null:
		return 0
	var postaveno: int = 0
	# ⚠ ROZESTUP (namEReno 2026-10-11 ze snimku `p20b-obrazky/m5-souboj.png`):
	# prvni verze stavela vsechna tri monstra na `+1..+2` dlazdice od hrace,
	# takze se v izometrii prekryla ("hromada") a na snimku nebylo poznat, co
	# je co. Jsou proto dal a vic do stran - hrac je vidi, ale nesplynou.
	#
	# ⚠⚠ SESSION D (2026-10-11) - TROJICE BYLA SMRTICI PRO HRAC, KTERY HRU NEZNA.
	# NamEReno sondou `_analyza/p58-smycka-hracem.gd` (hrac nic nedela, jen se
	# uci): monstra se do 20 s dostala na dosah a zabila ho - v zurnalu
	# 7x "skeleton hits you for 8 damage.", 7x "zombie hits you for 6 damage."
	# a "You are dead. You are a ghost."; **hp 0/87, batoh z 16 predmetu na 1
	# (vsechno zustalo v tele), zlato 0**. Hrac se tak k zadne smycce nedostane.
	# Zustava proto JEDNO slabe monstrum (krysa: 6 hp, damage 1-2 z
	# `data/monsters.json`): dost na to, aby se hrac NAUCIL utocit (`A`) a mel
	# co prodat, ale ne dost na to, aby ho zabilo - a kdyz ji zabije, dostane
	# loot (pack `poor`, 1d25 zlata), tedy presne to, co smycka potrebuje.
	# Skelet a zombie zustavaji ve svete tam, kam patri: spawn bod
	# `graveyard_britain` je zaklada sam (`sim.world.spawn`), ne tenhle sesitek.
	# Cesta zpet: puvodni trojice (3,1), (4,2), (2,4).
	var pozice: Array = [Vector3i(4, 2, 0)]
	var typy: Array = ["rat"]
	for i in mini(pozice.size(), typy.size()):
		var mob = _monstrum(str(typy[i]), player.pos + (pozice[i] as Vector3i))
		if mob == null:
			continue
		mob.ai = {"state": "idle", "target": 0, "home": mob.pos, "timer_ms": 0}
		registry.register(mob)
		sim.push_event("mobile_added", {"serial": int(mob.serial),
			"body": int(mob.body), "hue": int(mob.hue), "name": mob.name,
			"x": int(mob.pos.x), "y": int(mob.pos.y), "z": int(mob.pos.z),
			"notoriety": int(mob.notoriety), "type": str(typy[i])})
		postaveno += 1
		print("[main] monstrum: ", mob.name, " (", str(typy[i]), ", telo ",
			int(mob.body), ") na ", mob.pos, " hp ", int(mob.hp))
	if postaveno > 0:
		# ⚠ SESSION D: hlaseni musi odpovidat TOMU, co je postavene (drive
		# trojice, dnes jedno monstrum) - jinak by zurnal lhal o svete.
		# Klavesa se bere z `InputMap` (`_kody_akce`), aby se nerozesla s hrou.
		var jmena: Array[String] = []
		for i in mini(pozice.size(), typy.size()):
			var rec: Dictionary = _monstrum_data(str(typy[i]))
			var jmeno: String = str(rec.get("name", str(typy[i])))
			if not (jmeno in jmena):
				jmena.append(jmeno)
		_hlaseni_do_zurnalu("A " + ", a ".join(PackedStringArray(jmena))
			+ " is nearby. (press " + _kody_akce("attack", " or ")
			+ " to attack, or click one)")
	return postaveno


func _monstrum(typ: String, pos: Vector3i):
	# Mobil z `data/monsters.json` - STEJNÁ pravidla jako `sim.world.spawn._vytvor`
	# (staty z rozsahů, skilly v desetinách, `damage`/`resist`/`loot_pack` na
	# mobilu). Kdyby si to `app` počítalo po svém, vznikly by dva modely téhož
	# monstra - proto se bere jen to, co jde z dat, a `spawn` zůstává jediný,
	# kdo monstra plodí ve světě.
	var rec: Dictionary = _monstrum_data(typ)
	if rec.is_empty():
		push_warning("app.main: monstrum '" + typ + "' v data/monsters.json neni")
		return null
	var rec_body: int = int(rec.get("body", 0))
	if rec_body <= 0:
		push_warning("app.main: monstrum '" + typ + "' nema telo (body)")
		return null
	var mob = MobileScript.new(sim.next_serial(), rec_body, pos)
	mob.name = str(rec.get("name", typ))
	mob.hue = int(rec.get("hue", 0))
	mob.stats = _staty(rec)
	var hits_zdroj: Variant = rec.get("hits")
	if hits_zdroj == null:
		hits_zdroj = [mob.stats.hits_max(), mob.stats.hits_max()]
	var hp_hodnota: int = _rozsah(hits_zdroj)
	if hp_hodnota <= 0:
		hp_hodnota = mob.stats.hits_max()
	mob.max_hp = hp_hodnota
	mob.hp = mob.max_hp
	mob.max_stam = mob.stats.stam_max()
	mob.stam = mob.max_stam
	mob.max_mana = mob.stats.mana_max()
	mob.mana = mob.max_mana
	mob.notoriety = int(rec.get("notoriety", 3))
	mob.fame = int(rec.get("fame", 0))
	mob.karma = int(rec.get("karma", 0))
	var skills = rec.get("skills")
	if skills is Dictionary:
		for jmeno in (skills as Dictionary).keys():
			var sid: int = _skill_id(str(jmeno))
			if sid < 0:
				push_warning("app.main: skill '" + str(jmeno) + "' neni v data/skills.json")
				continue
			var v = (skills as Dictionary)[jmeno]
			mob.skills.set_value(sid, _rozsah(v) if v is Array else int(v))
	# DATA TVORA (M5): od 2026-10-11 ma `entity.mobile` DEKLAROVANA pole `type`,
	# `loot_pack`, `damage`, `resist` - zapisuji se PRIMO (a ukladaji do save).
	# Driv tu bylo `mob.set(...)`, coz je u nedeklarovane vlastnosti v Godotu 4
	# tiche no-op (namEReno 2026-10-11).
	mob.type = typ
	mob.loot_pack = str(rec.get("loot_pack", ""))
	var dmg = rec.get("damage", [])
	if dmg is Array and (dmg as Array).size() >= 2:
		mob.damage = [int((dmg as Array)[0]), int((dmg as Array)[1])]
	var res = rec.get("resist", {})
	if res is Dictionary:
		var rk: Dictionary = {}
		for k in (res as Dictionary).keys():
			rk[str(k)] = int((res as Dictionary)[k])
		mob.resist = rk
	return mob


func _monstrum_data(typ: String) -> Dictionary:
	# Cachovany pohled do `data/monsters.json` (typ -> zaznam). Nacte se jednou
	# za proces; chybejici soubor se HLASI, ne ticha nula.
	if _monstra_data.is_empty() and not _monstra_nactena:
		_monstra_nactena = true
		if not FileAccess.file_exists(_cesta("res://data/monsters.json")):
			push_warning("app.main: chybi data/monsters.json - monstra se nepostavi")
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(
			_cesta("res://data/monsters.json")))
		if not (parsed is Array):
			push_warning("app.main: data/monsters.json neni seznam")
			return {}
		for rec in parsed:
			if rec is Dictionary:
				# `type` i `id` (data maji obe jmena - viz content-report)
				var k: String = str(rec.get("type", rec.get("id", "")))
				if k != "":
					_monstra_data[k] = rec
	return _monstra_data.get(typ, {})


func _staty(rec: Dictionary):
	# ⚠ `int_` muze byt `null` (data maji obe jmena a u nekterych monster druhe
	# chybi) - `int(null)` hodi "Nonexistent 'int' constructor". Proto se bere
	# prvni NENULL hodnota a rozsah se nikdy nepredava jako `null`.
	var zdroj: Variant = rec.get("int_")
	if zdroj == null:
		zdroj = rec.get("int")
	if zdroj == null:
		zdroj = [10, 10]
	return StatsScript.new(_rozsah(rec.get("str", [10, 10])),
		_rozsah(rec.get("dex", [10, 10])), _rozsah(zdroj))


func _rozsah(v) -> int:
	# Rozsah `[min, max]` z dat - jedna hodnota z RNG simulace (determinismus).
	if v is Array and (v as Array).size() >= 2:
		return sim.rng().range_i(int((v as Array)[0]), int((v as Array)[1]))
	if v is Array and (v as Array).size() == 1:
		return int((v as Array)[0])
	if v == null:
		return 0
	return int(v)


func _skill_id(jmeno: String) -> int:
	# Jmeno skillu -> id z `data/skills.json`. Bez souboru vraci -1 ("nevim"),
	# nikdy tichy fallback na wrestling.
	if _skill_ids.is_empty() and not _skill_ids_nactene:
		_skill_ids_nactene = true
		if FileAccess.file_exists(skills_data):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(skills_data))
			if parsed is Array:
				for rec in parsed:
					if rec is Dictionary and rec.has("name") and rec.has("id"):
						_skill_ids[str(rec["name"])] = int(rec["id"])
	return int(_skill_ids.get(jmeno, -1))


func _prodejce_pozadavek() -> void:	# Potvrzeny nakup/prodej z obchodniho okna (D10). UI je TENKY KLIENT: posle
	# hotovy `Command`, tady se jen vyzvedne a preda simulaci (stejna cesta jako
	# u klaves a okna vyroby).
	if vendor_gump == null or sim == null:
		return
	var pozadavek: Dictionary = vendor_gump.odeber_pozadavek()
	if pozadavek.is_empty():
		return
	print("[main] obchod: ", pozadavek.get("action", "?"), " u vendora ",
		int(pozadavek.get("vendor", -1)), " polozek ",
		(pozadavek.get("lines", []) as Array).size())
	sim.enqueue(pozadavek)


func _postav_balvany() -> int:
	# RUDNÉ BALVANY VEDLE HRÁČE (2026-10-10, D10 „demo“). Důvod a hranice jsou
	# v komentáři u volání v `_setup_world`; tady jen stavba.
	# Art je z `sim.harvest.MINE_STATIC` (0x453B–0x454F) - kdyby se seznam
	# rozešel, `sim.harvest` by balvany netěžil a sonda by to ukázala.
	#
	# ⚠⚠ SESSION D (2026-10-11) - BALVAN NESMI LEZET NA STANICI ANI NA
	# PRODEJCI. Do teto chvile byly pozice (1,0), (2,0), (1,1), (0,2), jenze
	# vyhen stoji na (1,0) a prodejce na (2,0) - a dlazdice, kde je UZEL
	# I STANICE, se neda pouzit VUBEC: klient posle jen cil a `sim.interaction`
	# hleda "co se hodi" podle JEDNE role (`station_role` prebiji "tile"), takze
	# na rudu u vyhne vyslo `no_pair` a hrac dostal jen ticho.
	# NamEReno sondou `_analyza/p58-smycka-hracem.gd`: 0 rudy po 60 pokusech,
	# kolize "forge + balvan na (1496,1630)" a "balvan + kovar na (1497,1630)".
	# Nove pozice jsou volne; kontrolu hlida `_zkontroluj_cile_interakce()`.
	var pozice: Array = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 2)]
	var art: int = 0x453B
	var postaveno: int = 0
	balvany = []
	for p in pozice:
		var balvan = ItemScript.new(sim.next_serial(), art, 1)
		balvan.parent = 0                      # 0 = na zemi (docs/04 §4.5)
		balvan.pos = Vector3i(int(player.pos.x) + int(p.x), int(player.pos.y) + int(p.y),
			int(player.pos.z))
		items[int(balvan.serial)] = balvan
		balvany.append(Vector2i(balvan.pos.x, balvan.pos.y))
		postaveno += 1
		if postaveno == 1:
			# ⚠ SESSION D: "use them to mine" hracovi NEREKLO CIM. Klavesa se
			# bere z `InputMap` (`_kody_akce`), takze se nemuze rozejit s tim,
			# co hra opravdu poslouchá.
			_hlaseni_do_zurnalu("There are rocks to the east. (press "
				+ _kody_akce("interact", " or ") + " to mine)")
	print("[main] balvany: ", postaveno, " kusu (art ", art, ") u hrace na ", player.pos)
	return postaveno


func _zkontroluj_cile_interakce() -> Array:
	# Dlazdice -> co na ni hrac muze "pouzit". Vsechno, co se do sveta stavi
	# RUKOU (stanice, balvany, prodejce - vsechno jsou to sesitky pro demo),
	# se sejde tady: kde jsou dve veci na jedne dlazdici, jedna z nich je
	# mrtva a hrac to nema jak poznat.
	# Vraci seznam KOLIZI (a kazdou hlasi `push_warning`) - "nula kolizi" je
	# merena nula, ne prazdny seznam, ktery se tise proiteroval.
	_cile_interakce = {}
	var zdroje: Array = []
	for serial in items.keys():
		var it = items[serial]
		if it != null and int(it.parent) == 0:
			var role: String = ItemScript.role_of(int(it.tile))
			if role in ["forge", "anvil"]:
				zdroje.append({"nazev": role, "tile": Vector2i(int(it.pos.x), int(it.pos.y))})
	for b in balvany:
		zdroje.append({"nazev": "ruda", "tile": Vector2i(int(b.x), int(b.y))})
	if prodejce > 0 and registry != null:
		var mob = registry.get_mobile(int(prodejce))
		if mob != null:
			zdroje.append({"nazev": "prodejce", "tile": Vector2i(int(mob.pos.x), int(mob.pos.y))})
	var kolize: Array = []
	for z in zdroje:
		var klic: String = "%d,%d" % [int((z["tile"] as Vector2i).x), int((z["tile"] as Vector2i).y)]
		if _cile_interakce.has(klic):
			var text: String = str(_cile_interakce[klic]) + " + " + str(z["nazev"]) + " na " + klic
			kolize.append(text)
			push_warning("app.main: cile interakce se prekryvaji: " + text)
		else:
			_cile_interakce[klic] = str(z["nazev"])
	return kolize


func _hlaseni_do_zurnalu(text: String) -> void:
	# Hlaseni hraci pri startu. sim ho posila jako udalost (UI je tenky klient).
	if sim != null and sim.has_method("push_event"):
		sim.push_event("message", {"text": text, "kind": "system"})


# --- NAPOVEDA PRO HRACE (session D, 2026-10-11, granule `ui.hotkeys`) -------
#
# PROC TO TU JE: "hotovo" je, ze clovek, ktery hru NEZNA, projde kratkou smycku
# BEZ RADY. Text je v `data/help.json` (ladi se bez zasahu do kodu), ale KLAVESY
# se do dat NEPISUJI - berou se z `InputMap`, tedy z toho, co hra opravdu umi.
# Dve pravdy o klavesach znamenaji, ze hrac maze klavesu, ktera nic nedela.

func _load_help() -> Dictionary:
	# Nacte `data/help.json` JEDNOU; chybejici/rozbitý soubor se HLASI a vrati
	# prazdny slovnik (napoveda pak rekne, ze neni - nikdy tise prazdno).
	if not _help_data.is_empty():
		return _help_data
	if not FileAccess.file_exists(help_data):
		push_warning("app.main: chybi " + help_data + " - napoveda bude prazdna")
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(help_data))
	if not (parsed is Dictionary):
		push_warning("app.main: " + help_data + " neni slovnik - napoveda bude prazdna")
		return {}
	_help_data = parsed
	return _help_data


func _klavesy_do_inputmap() -> int:
	# Zaregistruje vazby klaves do `InputMap` PŘED stavbou světa. Vlastní je
	# `app.player_controller` (granule `app.player_controller`; presna sada
	# patri `ui.hotkeys`, ale ta klavesy NEDRZI - jen je zobrazuje). Kdyz
	# soubor chybi nebo funkci nema, rekne se to: ticha napoveda bez klaves
	# by vypadala jako hotova vec.
	var skript = load("res://app/player_controller.gd")
	if skript == null or not skript.has_method("register_actions"):
		push_warning("app.main: app/player_controller.gd nema `register_actions` - "
			+ "napoveda a hlášky světa zůstanou bez kláves")
		return 0
	return int(skript.register_actions())


func _klavesy_akce(akce: Array) -> String:
	# Lidsky text klaves pro seznam akci z `InputMap`. Poradi = poradi akci
	# v datech (hra ho nemeni), duplikaty se vypusti (numpad 1-9 je jedna
	# klavesa osmkrat). Prazdny seznam nebo nezname akce = "-" (videt, ne tise
	# prazdno); `_napoveda_chyby` to pocita, aby to nebylo jen v textu.
	var nazvy: Dictionary = _load_help().get("nazvy_klaves", {})
	var out: Array[String] = []
	for a in akce:
		var jmeno: String = str(a)
		if not InputMap.has_action(jmeno):
			_napoveda_chyby.append("akce '" + jmeno + "' v InputMap neni")
			continue
		for udalost in InputMap.action_get_events(jmeno):
			var popis: String = _popis_klavesy(udalost)
			if popis == "":
				continue
			popis = str(nazvy.get(popis, popis))
			if not (popis in out):
				out.append(popis)
	if out.is_empty():
		return "-"
	return ", ".join(PackedStringArray(out))


func _popis_klavesy(udalost) -> String:
	# Nazev udalosti z `InputMap` JEDNIM mistem: klavesa svym jmenem (stejne
	# jmeno, jake vraci `OS.get_keycode_string`), mys tlacitkem. Neznama
	# udalost vraci "" (radsi nic nez vymyslene jmeno).
	if udalost is InputEventKey:
		return OS.get_keycode_string((udalost as InputEventKey).keycode)
	if udalost is InputEventMouseButton:
		var tlacitko: int = int((udalost as InputEventMouseButton).button_index)
		if tlacitko == MOUSE_BUTTON_LEFT:
			return "LMB"
		if tlacitko == MOUSE_BUTTON_RIGHT:
			return "RMB"
	return ""


func _kody_akce(akce: String, spojka: String) -> String:
	# Klavesy akce pro ANGLICKE hlasky ve svete ("press E or T to mine") jako
	# holé kódy - ceske nazvy z dat by do anglicke vety nepatrily. Mys se
	# vynechava: "(press levé tlačítko myši)" by byla otrava.
	var out: Array[String] = []
	if InputMap.has_action(akce):
		for udalost in InputMap.action_get_events(akce):
			if udalost is InputEventKey:
				var kod: String = OS.get_keycode_string((udalost as InputEventKey).keycode)
				if not (kod in out):
					out.append(kod)
	if out.is_empty():
		return "(?)"           # klavesa se nenasla - VIDET, ne tise prazdno
	return spojka.join(PackedStringArray(out))


func _uvod_text(text: String) -> String:
	# Nahradi {akce} skutecnou klavesou. Neznama znacka se NAHLASI a text se
	# vrati PRAZDNY - napoveda s "{...}" v texte by byla vada, ne napoveda.
	# Bere se KOD klavesy ("E", "H"), ne lokalizovany nazev: veta ma znit
	# "stiskni E nebo T", ne "stiskni levé tlačítko myši, A".
	var out: String = text
	var chyby: Array[String] = []
	for i in range(text.count("{")):
		var od: int = out.find("{")
		var do_: int = out.find("}", od + 1)
		if od < 0 or do_ < 0:
			break
		var znacka: String = out.substr(od + 1, do_ - od - 1)
		var nahrada: String = _kody_akce(znacka, " nebo ")
		if nahrada == "(?)":
			chyby.append(znacka)
			nahrada = ""
		out = out.substr(0, od) + nahrada + out.substr(do_ + 1)
	if not chyby.is_empty():
		push_warning("app.main: uvodni napoveda zna neznamou akci " + str(chyby))
		return ""
	return out


func _napoveda_radky() -> Array:
	# Radky z DAT prelozene na to, co kresli okno: `{sekce, klavesy, popis}`.
	# Poradi: skupina (`skupiny[].poradi`) a v ni radek (`radky[].poradi`) -
	# trida se tady, aby si okno nemuselo vymyslet pravidlo (tenky klient).
	var data: Dictionary = _load_help()
	var nazvy_sekci: Dictionary = {}
	var poradi_sekci: Dictionary = {}
	for s in data.get("skupiny", []):
		if s is Dictionary:
			nazvy_sekci[str(s.get("id", ""))] = str(s.get("nazev", ""))
			poradi_sekci[str(s.get("id", ""))] = int(s.get("poradi", 0))
	var out: Array = []
	for r in data.get("radky", []):
		if not (r is Dictionary):
			_napoveda_chyby.append("radek neni slovnik: " + str(r))
			continue
		var skupina: String = str(r.get("skupina", ""))
		var klavesy: String = _klavesy_akce(r.get("akce", []))
		out.append({
			"sekce": str(nazvy_sekci.get(skupina, skupina)),
			"klavesy": klavesy,
			"popis": str(r.get("popis", "")),
			"poradi": int(poradi_sekci.get(skupina, 0)) * 1000 + int(r.get("poradi", 0)),
		})
	out.sort_custom(func(a, b): return int(a["poradi"]) < int(b["poradi"]))
	for radek in out:
		radek.erase("poradi")
	return out


func _osvezi_napovedu() -> int:
	# Naplni okno napovedi z dat a z REALNYCH vazeb. Vraci pocet radku.
	# Chyby (`_napoveda_chyby`) se VYPISUJI - jinak by se "radek chybi" tvarilo
	# jako "napoveda je kratka".
	if hotkeys == null:
		push_warning("app.main: okno napovedy neni - `ui.hotkeys` se nezaregistrovalo")
		return 0
	_napoveda_chyby.clear()
	var data: Dictionary = _load_help()
	var radky: Array = _napoveda_radky()
	hotkeys.nastav(str(data.get("titulek", "")), radky,
		str(data.get("prazdno", "")))
	if not _napoveda_chyby.is_empty():
		push_warning("app.main: napoveda ma " + str(_napoveda_chyby.size())
			+ " vad: " + str(_napoveda_chyby))
	return int(hotkeys.count())


func _hlaseni_uvod() -> int:
	# UVODNI ZPRAVY DO ZURNALU: "co je cilem a jak". Do session D dostal hrac
	# jen to, co vidi ("There are rocks to the east"), ale NE jak to udelat -
	# a u prodeje dokonce radu, ktera se nedala splnit (`use` na prodejce).
	# Text je z `data/help.json` (`uvod`), klavesy se doplnuji z `InputMap`.
	var poslano: int = 0
	for radek in _load_help().get("uvod", []):
		if not (radek is Dictionary):
			continue
		var text: String = _uvod_text(str((radek as Dictionary).get("text", "")))
		if text == "":
			continue
		_hlaseni_do_zurnalu(text)
		poslano += 1
	return poslano


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
		# Cesta se preklada pres vrstvy obsahu (`_cesta`) - `data/balance.json`
		# je taky obsah a mod ho muze prebit (docs/04 §4.9).
		var path: String = _cesta(DATA_FILES[key])
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
