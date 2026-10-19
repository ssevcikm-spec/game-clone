extends SceneTree
# loop_probe.gd - DUKAZ G20 (docs/08 §8.2): hrac projde KRATKOU SMYCKOU na
# REALNE SCENE - tezit -> vyrobit -> prodat - a kazdy krok ma hracovem
# VIDITELNY nasledek (zurnal / inventar / zlato).
#
# PROC TO NENI `tests/cases/*`: testy volaji systemy SIM primo (`sim.harvest.mine`,
# `sim.craft.smelt`). To dokazuje, ze system umi vec udelat - ale NE, ze se k nemu
# hrac dostane. NamEReno (session D, 2026-10-11): prodej byl dosazitelny jen
# sondou, protoze okno obchodu nemelo prepinac na prodej; zelene testy to
# nechytily. Presne tuhle tridu vady ma G20 merit.
#
# CESTA, KTEROU SONDA JDE (zadne primy volani systemu `sim/`):
#   1. TEZBA   - `Command{t:"interact"}` z klienta (`app.input_map.interact_command`,
#                stejna cesta jako klavesa E/T) na dlazdici balvanu,
#   2. TAVENI  - `interact` na dlazdici vyhne (sim si sam vybere rudu z batohu),
#   3. VYROBA  - `interact` na kovadlinu -> okno vyroby -> klik na recept
#                (`ui.craft_gump.stiskni`) a pozadavek si vyzvedne HRA sama
#                (`app.main._process` -> `_recept()` -> `Command{t:"craft"}`),
#   4. PRODEJ  - `interact` na dlazdici prodejce -> okno obchodu -> prepinac
#                "sell" -> radek s vyrobkem -> potvrzeni -> pozadavek si
#                vyzvedne HRA sama (`app.main._process` -> `Command{t:"vendor"}`).
# Vsechny ctyri prikazy jdou do SIM JEDNOU branou (`sim.enqueue` -> `sim.tick`
# -> `sim.commands.dispatch`). Sonda NIKDY nevola `_recept()`/`_prodejce_pozadavek()`
# ani systemy `sim/` - kroky 3 a 4 dobehnou ve skutecnych framech hry.
#
# CO SONDA ZAMERNE ZVEDA: skill Mining a Blacksmithy na 1000. Meri se
# PRUCHODNOST smycky, ne balance - s vychozim skillem umi taveni i vyroba
# nahodne selhat ("failed") a z mereni by se stalo mereni nahody (stejny duvod
# a stejna mez jako v `tools/gates/sound_probe.gd`).
#
# SNIMKY: `--snimky=<cesta>` (user args, napr. `-- --snimky=res://.tmp/g20`).
# V headless se snimek ULOZIT NEDA - `root.get_texture().get_image()` vrati null
# (namEReno 2026-10-12: `ERROR: Parameter "t" is null`, obraz null). Sonda to
# REKNE (`snimky_chyba`), nez aby mlcela: "0 snimku" nesmi vypadat jako uspech.
#
# Spousteni (mereni bez snimku, to pouziva brana):
#   godot --headless --path . --fixed-fps 60 --script res://tools/gates/loop_probe.gd
# Spousteni se snimky (vizualni dokaz, okno):
#   godot --path . --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 \
#     --script res://tools/gates/loop_probe.gd -- --snimky=res://.tmp/g20-smycka
#
# VYSTUP PRO BRANU: jeden radek `[smycka] SOUHRN {json}` (viz `_vypis_souhrn`).

const Iso = preload("res://core/iso.gd")
const Const = preload("res://core/const.gd")
const ItemScript = preload("res://sim/entity/item.gd")

# Recept "dagger" z `data/recipes.json` (Blacksmithy, 3x iron ingot). Kdyby
# z dat zmizel, krok 3 spadne s `okno_otevrene:false`/`dyka_po:0` - ne tise.
const RECEPT_DYKA: int = 114
# Kolik surovin si hrac predvytezi. Dyka chce 3 ingoty a neuspech material
# ztraci, takze s rezervou (stejna uvaha jako v `_analyza/p58-smycka-hracem.gd`).
const CHCI_RUDY: int = 8
const CHCI_INGOTU: int = 3
# Tezba ma `swing_ms = 1600` (`sim.harvest.BANKS`): druhy pokus driv vyjde na
# "You must wait to perform another action." 1700 ms = 34 tiku.
const CEKANI_TIKU: int = 34
const MAX_TEZBA: int = 40
const MAX_TAVENI: int = 40
# Text, ktery hrac po kazdem kroku MUSI videt v zurnalu (slovo z hlasky SIM).
# Je to HRACUV dusledek, ne dekorace: kdyz hlaska zmizi, krok se nema cim
# prokazat a brana to rekne (`zurnal_klice:false`).
const ZURNAL_KLICE: Dictionary = {
	"tezba": "gather", "taveni": "smelt", "vyroba": "create", "prodej": "sell",
}

var _scena = null
var _iso = null
var _f: int = 0
var _snimky_dir: String = ""
var _kroky: Array[Dictionary] = []
var _snimky: Array[String] = []
var _snimky_chyba: String = ""
var _duvod: String = ""
var _inv: Dictionary = {}
var _souhrn: Dictionary = {}
# Rozpracovane kroky 3 a 4: akce ve framu X, overeni ve framu X+6 (mezitim
# command vyzvedne a vyrizi realna smycka hry).
var _ceka: Dictionary = {}


func _initialize() -> void:
	_iso = Iso.new()
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--snimky="):
			_snimky_dir = str(arg).substr(len("--snimky=")).strip_edges()
	if _snimky_dir != "":
		var cil: String = ProjectSettings.globalize_path(_snimky_dir)
		var chyba: int = DirAccess.make_dir_recursive_absolute(cil)
		print("[smycka] snimky do ", cil, " (mkdir ", chyba, ")")
		if chyba != OK:
			# NESMI byt ticho: kdyz se snimky nekam nevejdou, rekne se to.
			_snimky_chyba = "adresar pro snimky nejde vytvorit (%d)" % chyba
			_snimky_dir = ""
	_scena = load("res://app/main.tscn").instantiate()
	root.add_child(_scena)


func _process(_delta: float) -> bool:
	_f += 1
	if _scena == null or _scena.loop == null or _scena.player == null:
		return _f > 900        # scena se nestaví - sonda nesmi viset vecne
	# KROKY JSOU ROZDELENE DO FRAMU (ne jeden blok jako v `_analyza/p58`):
	# mezi nimi dobiha skutecny frame hry (smycka tikuje, okna kresli, zurnal
	# se prebavuje), takze SNIMEK po kazdem kroku ukazuje stav, ktery hrac
	# opravdu vidi, a pozadavky z oken vyzvedava HRA, ne sonda.
	if _f == 60:
		_zvedni_skilly()
		_krok_tezba()
	if _f == 66:
		_snimek("krok1-tezba")
	if _f == 74:
		_krok_taveni()
	if _f == 80:
		_snimek("krok2-taveni")
	if _f == 88:
		_akce_vyroba()
	if _f == 94:
		_krok_vyroba()
		_snimek("krok3-vyroba")
	if _f == 102:
		_akce_prodej()
	if _f == 108:
		_krok_prodej()
		_snimek("krok4-prodej")
	if _f == 116:
		_vypis_souhrn()
		quit(0)
		return true
	return _f > 900


# -- krok 0: sonda meri pruchodnost, ne balance ---------------------------------

func _zvedni_skilly() -> void:
	# Vysvetleni v hlavicce; bez toho by kazdy krok mohl "nahodne" selhat a
	# brana by merila hod kostkou.
	_scena.player.skills.set_value(45, 1000)   # Mining
	_scena.player.skills.set_value(7, 1000)    # Blacksmithy
	print("[smycka] skilly: Mining ", _scena.player.skills.value(45),
		", Blacksmithy ", _scena.player.skills.value(7))


# -- cesta hrace (klient -> Command -> sim) ------------------------------------

func _z() -> int:
	return int(_scena.player.pos.z)


func _mireni(tile: Vector2i) -> Vector2:
	# Presny inverz k `app.input_map._na_svet` (`world = screen / zoom + offset`).
	# Kdyz by se klient a sonda rozesly, sonda by mirila jinam nez hrac - proto
	# se miri TOUTEZ cestou, jakou miri klient (`input_map.interact_command`).
	var svet: Vector2 = _iso.to_screen(tile.x, tile.y, _z())
	return (svet - _scena.loop.camera_offset) * _scena.loop.input_map.zoom


func _interact(tile: Vector2i) -> Dictionary:
	# PRIKAZ VYTVARI KLIENT, ne sonda (stejne jako klavesa E/T).
	var prikaz: Dictionary = _scena.loop.input_map.interact_command(
		_mireni(tile), _scena.loop.camera_offset, _z())
	if not prikaz.is_empty():
		_scena.sim.enqueue(prikaz)
	return prikaz


func _cekej(n: int) -> void:
	# Tika simulaci a predava udalosti klientu (to, co dela `app.loop`).
	for _i in n:
		_scena.sim.tick(Const.TICK_MS)
	_scena.loop._deliver_events()


func _tile_predmetu(role: String) -> Vector2i:
	# Dlazdice predmetu na zemi podle ROLE z dat (kovadlina/vyhen).
	for serial in _scena.items.keys():
		var it = _scena.items[serial]
		if it != null and int(it.parent) == 0 and ItemScript.role_of(int(it.tile)) == role:
			return Vector2i(int(it.pos.x), int(it.pos.y))
	return Vector2i(-9999, -9999)


func _kovar_tile() -> Vector2i:
	var mob = _scena.registry.get_mobile(int(_scena.prodejce))
	if mob == null:
		return Vector2i(-9999, -9999)
	return Vector2i(int(mob.pos.x), int(mob.pos.y))


# -- inventar a zlato (hracuv VIDITELNY stav) ----------------------------------

func _v_batohu(typ: String) -> int:
	var soucet: int = 0
	for serial in _scena.container.contents(int(_scena.player.backpack)):
		var it = _scena.items.get(int(serial))
		if it != null and ItemScript.type_of(int(it.tile)) == typ:
			soucet += int(it.amount)
	return soucet


func _dyka_art() -> int:
	# ART vyrobku v batohu: hleda se podle TYPU z dat (ne podle jmena), aby
	# sonda nedrzela druhy zdroj pravdy o tom, co je "dyka".
	for serial in _scena.container.contents(int(_scena.player.backpack)):
		var it = _scena.items.get(int(serial))
		if it != null and ItemScript.type_of(int(it.tile)) == "dagger":
			return int(it.tile)
	return 0


func _zlato() -> int:
	return int(_scena.vendor.gold_of(_scena.player))


func _zurnal_pocet() -> int:
	return int(_scena.journal.message_count())


func _zurnal_nove(od: int) -> Array:
	# Zpravy, ktere hrac v tomhle kroku VIDEL (od indexu `od`).
	var radky: Array = _scena.journal.lines()
	var out: Array = []
	for i in range(od, radky.size()):
		out.append(str(radky[i].get("text", "")))
	return out


func _krok(id: String, ok: bool, hodnoty: Dictionary, zurnal_pred: int) -> void:
	var nove: Array = _zurnal_nove(zurnal_pred)
	var klice: bool = false
	var hledany: String = str(ZURNAL_KLICE.get(id, ""))
	for radek in nove:
		if hledany != "" and str(radek).to_lower().contains(hledany):
			klice = true
	var zaznam: Dictionary = {
		"id": id, "ok": ok,
		"zurnal_pred": zurnal_pred, "zurnal_po": _zurnal_pocet(),
		"zurnal_nove": nove.slice(0, 8),
		"zurnal_klice": klice, "zurnal_hledany": hledany,
		"hodnoty": hodnoty,
	}
	_kroky.append(zaznam)
	print("[smycka] krok ", id, ": ", "PASS" if ok else "VADA", " ", hodnoty,
		" | zurnal ", zurnal_pred, " -> ", zaznam["zurnal_po"],
		" | hledany '", hledany, "' ", ("NALEZEN" if klice else "NENALEZEN"))
	for radek in nove:
		print("[smycka]   zurnal: ", radek)


# -- kroky smycky --------------------------------------------------------------

func _krok_tezba() -> void:
	var ruda_pred: int = _v_batohu("iron_ore")
	var zurnal_pred: int = _zurnal_pocet()
	var pokusu: int = 0
	var prikaz: Dictionary = {}
	var prvni_cil: String = ""
	var balvanu: int = _scena.balvany.size()
	if balvanu <= 0:
		_duvod = "ve scene nejsou balvany (app/main.balvany je prazdne)"
		_krok("tezba", false, {"ruda_pred": ruda_pred, "ruda_po": ruda_pred, "balvanu": 0},
			zurnal_pred)
		return
	var i: int = 0
	while pokusu < MAX_TEZBA and _v_batohu("iron_ore") < CHCI_RUDY:
		var b = _scena.balvany[i % balvanu]
		var cil := Vector2i(int(b.x), int(b.y))
		prikaz = _interact(cil)
		if pokusu == 0:
			prvni_cil = str(prikaz.get("target", {}))
			print("[smycka] tezba: klient poslal ", prikaz, " na balvan ", cil)
		_cekej(CEKANI_TIKU)
		pokusu += 1
		i += 1
	var ruda_po: int = _v_batohu("iron_ore")
	_krok("tezba", ruda_po > ruda_pred, {
		"ruda_pred": ruda_pred, "ruda_po": ruda_po, "pokusu": pokusu,
		"balvanu": balvanu, "prikaz": str(prikaz.get("t", "")), "cil": prvni_cil,
	}, zurnal_pred)


func _krok_taveni() -> void:
	var ingot_pred: int = _v_batohu("iron_ingot")
	var ruda_pred: int = _v_batohu("iron_ore")
	var zurnal_pred: int = _zurnal_pocet()
	var vyhen: Vector2i = _tile_predmetu("forge")
	if vyhen.x < 0:
		_duvod = "ve scene neni vyhen (role 'forge' z data/items.json)"
		_krok("taveni", false, {"ingot_pred": ingot_pred, "ingot_po": ingot_pred}, zurnal_pred)
		return
	var pokusu: int = 0
	var prikaz: Dictionary = {}
	while pokusu < MAX_TAVENI and _v_batohu("iron_ingot") < CHCI_INGOTU \
			and _v_batohu("iron_ore") > 0:
		prikaz = _interact(vyhen)
		_cekej(CEKANI_TIKU)
		pokusu += 1
	var ingot_po: int = _v_batohu("iron_ingot")
	_krok("taveni", ingot_po > ingot_pred, {
		"ingot_pred": ingot_pred, "ingot_po": ingot_po, "ruda_pred": ruda_pred,
		"ruda_po": _v_batohu("iron_ore"), "pokusu": pokusu, "vyhen": str(vyhen),
		"prikaz": str(prikaz.get("t", "")),
	}, zurnal_pred)


func _akce_vyroba() -> void:
	# Akce hrace: "pouzij" kovadlinu -> okno vyroby -> klik na recept.
	# Pozadavek si vyzvedne az HRA ve svem framu (`app.main._process` ->
	# `_recept()` -> `Command{t:"craft", recipe, count}`).
	var kovadlina: Vector2i = _tile_predmetu("anvil")
	var stav: Dictionary = {"dyka_pred": _v_batohu("dagger"), "zurnal_pred": _zurnal_pocet()}
	_ceka["vyroba"] = stav
	if kovadlina.x < 0:
		_duvod = "ve scene neni kovadlina (role 'anvil' z data/items.json)"
		stav["okno_otevrene"] = false
		return
	_interact(kovadlina)
	_cekej(4)
	# V bloku nebezi `_process` uzlu, takze okno prebavime rucne (jeho vlastni
	# frame by udelal totéž - `ui.craft_gump.flush`).
	_scena.craft_gump.flush()
	stav["okno_otevrene"] = bool(_scena.craft_gump.je_otevreny())
	stav["receptu"] = int(_scena.craft_gump.pocet())
	stav["kliknuto"] = bool(_scena.craft_gump.stiskni(RECEPT_DYKA))
	print("[smycka] vyroba: okno ", stav["okno_otevrene"], " receptu ", stav["receptu"],
		" klik na recept ", RECEPT_DYKA, " = ", stav["kliknuto"])


func _krok_vyroba() -> void:
	# Overeni az po 6 framech: mezitim hra pozadavek vyzvedla a prikaz vyridila.
	var stav: Dictionary = _ceka.get("vyroba", {})
	var dyka_pred: int = int(stav.get("dyka_pred", 0))
	var zurnal_pred: int = int(stav.get("zurnal_pred", 0))
	var dyka_po: int = _v_batohu("dagger")
	_krok("vyroba", dyka_po > dyka_pred and bool(stav.get("okno_otevrene", false)), {
		"okno_otevrene": bool(stav.get("okno_otevrene", false)),
		"receptu": int(stav.get("receptu", 0)), "kliknuto": bool(stav.get("kliknuto", false)),
		"recept": RECEPT_DYKA, "dyka_pred": dyka_pred, "dyka_po": dyka_po,
		"ingotu": _v_batohu("iron_ingot"),
	}, zurnal_pred)


func _akce_prodej() -> void:
	# Akce hrace: "pouzij" prodejce -> okno obchodu -> prepinac "sell" ->
	# radek s vyrobkem -> potvrzeni. Pozadavek si vyzvedne az HRA ve svem framu
	# (`app.main._process` -> `Command{t:"vendor", action:"sell"}`).
	var kovar: Vector2i = _kovar_tile()
	var stav: Dictionary = {"zlato_pred": _zlato(), "dyka_pred": _v_batohu("dagger"),
		"zurnal_pred": _zurnal_pocet()}
	_ceka["prodej"] = stav
	if kovar.x < 0:
		_duvod = "ve scene neni prodejce (app/main.prodejce == 0)"
		stav["okno_otevrene"] = false
		return
	_interact(kovar)
	_cekej(4)
	_scena.vendor_gump.flush()
	stav["okno_otevrene"] = bool(_scena.vendor_gump.je_otevreny())
	# Prepinac na prodej je v okne TLACITKO (hra bez nej prodej neumela -
	# namEReno v session D); sonda macka jeho verejnou cestu.
	stav["prepnuto_na_sell"] = bool(_scena.vendor_gump.nastav_smer("sell"))
	_scena.vendor_gump.flush()
	var art: int = _dyka_art()
	stav["art"] = art
	stav["radek"] = false
	stav["potvrzeno"] = false
	if art > 0:
		stav["radek"] = bool(_scena.vendor_gump.stiskni_radek("sell", art))
		stav["potvrzeno"] = bool(_scena.vendor_gump.stiskni_potvrzeni("sell"))
	print("[smycka] prodej: okno ", stav["okno_otevrene"], " sell ", stav["prepnuto_na_sell"],
		" radek ", stav["radek"], " potvrzeno ", stav["potvrzeno"], " art ", art)


func _krok_prodej() -> void:
	var stav: Dictionary = _ceka.get("prodej", {})
	var zlato_pred: int = int(stav.get("zlato_pred", 0))
	var dyka_pred: int = int(stav.get("dyka_pred", 0))
	var zurnal_pred: int = int(stav.get("zurnal_pred", 0))
	var zlato_po: int = _zlato()
	_krok("prodej", zlato_po > zlato_pred and _v_batohu("dagger") < dyka_pred, {
		"zlato_pred": zlato_pred, "zlato_po": zlato_po, "rozdil": zlato_po - zlato_pred,
		"dyka_pred": dyka_pred, "dyka_po": _v_batohu("dagger"),
		"okno_otevrene": bool(stav.get("okno_otevrene", false)),
		"prepnuto_na_sell": bool(stav.get("prepnuto_na_sell", false)),
		"radek": bool(stav.get("radek", false)),
		"potvrzeno": bool(stav.get("potvrzeno", false)), "art": int(stav.get("art", 0)),
	}, zurnal_pred)


# -- snimky a souhrn -----------------------------------------------------------

func _snimek(jmeno: String) -> void:
	# SNIMEK JE DUKAZ POHLEDEM (zadani G20). V headless se poridit neda -
	# `get_texture().get_image()` vrati null (namEReno), a to se REKNE.
	if _snimky_dir == "":
		return
	var obraz: Image = root.get_texture().get_image() if root.get_texture() != null else null
	if obraz == null:
		if _snimky_chyba == "":
			_snimky_chyba = "viewport nema obraz (headless) - snimky nelze poridit"
		return
	var cesta: String = _snimky_dir.path_join(jmeno + ".png")
	var chyba: int = obraz.save_png(cesta)
	if chyba != OK:
		_snimky_chyba = "save_png(%s) = %d" % [cesta, chyba]
		return
	_snimky.append(cesta)
	print("[smycka] snimek ", cesta, " (", obraz.get_width(), "x", obraz.get_height(), ")")


func _vypis_souhrn() -> void:
	_inv = {
		"ruda": _v_batohu("iron_ore"), "ingot": _v_batohu("iron_ingot"),
		"dyka": _v_batohu("dagger"), "zlato": _zlato(),
		"hp": int(_scena.player.hp), "hp_max": int(_scena.player.max_hp),
	}
	var ok: bool = not _kroky.is_empty() and bool(_kroky[0].get("ok", false))
	for k in _kroky:
		ok = ok and bool(k.get("ok", false))
	# ZURNAL CELY (dukaz, ze hrac neco videl) - do logu brany i do souboru.
	print("[smycka] ZURNAL (", _zurnal_pocet(), " zprav):")
	for radek in _scena.journal.lines():
		print("[zurnal] ", str(radek.get("text", "")))
	if _snimky_dir != "":
		var cesta: String = _snimky_dir.path_join("zurnal.txt")
		var f: FileAccess = FileAccess.open(cesta, FileAccess.WRITE)
		if f == null:
			_snimky_chyba = "zurnal.txt nejde zapsat (%s)" % cesta
		else:
			f.store_string(_scena.journal.plain_text())
			f.close()
	_souhrn = {
		"ok": ok and _duvod == "",
		"kroky": _kroky,
		"inv": _inv,
		"zurnal_celkem": _zurnal_pocet(),
		"snimky": _snimky,
		"snimky_chyba": _snimky_chyba,
		"snimky_zadany": _snimky_dir != "",
		"duvod": _duvod,
		"prekryv": _scena._zkontroluj_cile_interakce().size(),
	}
	print("[smycka] SOUHRN ", JSON.stringify(_souhrn))
	# Kdyby neco zustalo otevrene, sonda to rekne nahlas (ne tise).
	if not ok or _duvod != "":
		print("[smycka] VADA: ", _duvod if _duvod != "" else "nektery krok smycky neprosel")
	elif _snimky_dir != "" and _snimky.size() < 2:
		print("[smycka] POZOR: snimku je ", _snimky.size(), " (", _snimky_chyba, ")")
