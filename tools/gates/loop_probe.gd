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
# CESTA, KTEROU SONDA JDE (zadne primy volani systemu `sim/` a zadne volani
# handleru tlacitek):
#   1. TEZBA   - `Command{t:"interact"}` z klienta (`app.input_map.interact_command`,
#                stejna cesta jako klavesa E/T) na dlazdici balvanu,
#   2. TAVENI  - `interact` na dlazdici vyhne (sim si sam vybere rudu z batohu),
#   3. VYROBA  - `interact` na kovadlinu -> okno vyroby -> KLIK na skutecne
#                `Button` (radek receptu): sonda ho NAJDE v uzlech okna, overi,
#                ze ma pripojeny signal `pressed`, a ten signal VYSLJE. Pozadavek
#                si vyzvedne HRA sama (`app.main._process` -> `Command{t:"craft"}`),
#   4. PRODEJ  - `interact` na dlazdici prodejce -> okno obchodu -> KLIK na
#                `Button` "Smer" (prepinac buy/sell), pak na `Button` radku
#                s vyrobkem a na `Button` "Potvrdit" - u kazdeho se overi
#                pripojeny `pressed` a signal se VYSLJE. Pozadavek si vyzvedne
#                HRA sama (`app.main._process` -> `Command{t:"vendor"}`).
# Vsechny ctyri prikazy jdou do SIM JEDNOU branou (`sim.enqueue` -> `sim.tick`
# -> `sim.commands.dispatch`). Sonda NIKDY nevola `_recept()`/`_prodejce_pozadavek()`
# ani systemy `sim/` - kroky 3 a 4 dobehnou ve skutecnych framech hry.
#
# ⚠ CO JE "CESTA HRACE" (presne, bez zobecnovani): COMMAND cestu (od klienta do
# SIM jednou branou) jde krok 1 a 2 (`interact` vyrábí `app.input_map`) a pak
# pozadavky oken, ktere vyzvedne `app.main`; KLIK (signal `pressed` na realnem
# `Button` uzlu) jde krok 3 a 4. Sonda pritom NEMACKA klavesnici ani mys - vysila
# signal, ktery klavesa/mys vysle taky; handler se nikdy nevola primo.
# Duvod je namEReny (2026-10-19, vraceno verifikatorem): prvni verze sondy volala
# `vendor_gump.nastav_smer/stiskni_radek/stiskni_potvrzeni` a prosla i na kopii,
# kde `Button` byl `Label` a handler `_on_smer_pressed` chybel - presne ta
# historicka vada, kvuli ktere G20 vznikla.
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
	if _scena == null or _scena.get("loop") == null or _scena.get("player") == null:
		# `get()` (ne prima pristup `.loop`): kdyz scene nema skript (napr. se
		# nezkompiloval kvuli rozbite UI), kazdy frame by spadl na runtime chybe
		# a `_process` by se NIKDY nedostal k `return _f > 900` - sonda by visela
		# (namEReno 2026-10-19 pri mutaci: 10+ minut misto chyby).
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
		"zurnal_nove": nove.slice(0, 12),
		"zurnal_klice": klice, "zurnal_hledany": hledany,
		"hodnoty": hodnoty,
	}
	_kroky.append(zaznam)
	print("[smycka] krok ", id, ": ", "PASS" if ok else "VADA", " ", hodnoty,
		" | zurnal ", zurnal_pred, " -> ", zaznam["zurnal_po"],
		" | hledany '", hledany, "' ", ("NALEZEN" if klice else "NENALEZEN"))
	for radek in nove:
		print("[smycka]   zurnal: ", radek)


# -- skutecna TLACITKA: hrac macka Button, nevola handler ----------------------
# G20 ma merit CESTU HRACE. Prvni verze sondy volala `stiskni_*`/`nastav_smer`
# primo, takze prošla i na kopii, kde byl `Button` nahrazeny `Label` a handler
# `_on_smer_pressed` smazan (historicka vada, kvuli ktere G20 vznikla).
# Sonda proto: (1) NAJDE Button uzel, (2) overi, ze ma pripojeny signal
# `pressed`, (3) signal VYSLJE. Kdyz tlacitko chybi nebo je odpojene, krok to
# rekne konkretni chybou - ticho by bylo stejne jako uspech.

func _tlacitka(uzel: Node, out: Array) -> Array:
	for child in uzel.get_children():
		if child is Button:
			out.append(child)
		_tlacitka(child, out)
	return out


func _najdi_tlacitko(okno: Node, jmeno: String = "", text: String = "") -> Button:
	# Hleda se v UZLECH okna (to, co hrac vidi a muze zmacknout), ne v datech.
	for t in _tlacitka(okno, []):
		if jmeno != "" and str(t.name) == jmeno:
			return t
		if text != "" and str(t.text) == text:
			return t
	return null


func _signal_pripojen(tlacitko: Button) -> bool:
	# Kliknuti neco udela JEN kdyz je `pressed` pripojeny k platnemu handleru.
	for zaznam in tlacitko.get_signal_connection_list("pressed"):
		if not (zaznam is Dictionary):
			continue
		var cb: Callable = zaznam.get("callable", Callable())
		if cb.is_valid():
			return true
	return false


func _stiskni(tlacitko: Button) -> bool:
	# VYSLANI SIGNALU, ne volani handleru: presne to, co udela skutecny klik.
	tlacitko.pressed.emit()
	return true


func _popis_tlacitek(okno: Node) -> int:
	return _tlacitka(okno, []).size()


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
	# Akce hrace: "pouzij" kovadlinu -> okno vyroby -> KLIK na Button radku
	# receptu. Pozadavek si vyzvedne az HRA ve svem framu (`app.main._process` ->
	# `_recept()` -> `Command{t:"craft", recipe, count}`).
	var kovadlina: Vector2i = _tile_predmetu("anvil")
	var stav: Dictionary = {"dyka_pred": _v_batohu("dagger"), "zurnal_pred": _zurnal_pocet()}
	stav["tlacitko_recept"] = false
	stav["signal_recept"] = false
	stav["tlacitko_chyba"] = ""
	_ceka["vyroba"] = stav
	if kovadlina.x < 0:
		_duvod = "ve scene neni kovadlina (role 'anvil' z data/items.json)"
		stav["okno_otevrene"] = false
		stav["tlacitko_chyba"] = "kovadlina chybi, okno vyroby nejde otevrit"
		return
	_interact(kovadlina)
	_cekej(4)
	# V bloku nebezi `_process` uzlu, takze okno prebavime rucne (jeho vlastni
	# frame by udelal totéž - `ui.craft_gump.flush`).
	_scena.craft_gump.flush()
	stav["okno_otevrene"] = bool(_scena.craft_gump.je_otevreny())
	stav["receptu"] = int(_scena.craft_gump.pocet())
	var rec: Dictionary = {}
	for r in _scena.craft_gump.recepty():
		if int(r.get("id", -1)) == RECEPT_DYKA:
			rec = r
	var text: String = _scena.craft_gump.text_receptu(rec) if not rec.is_empty() else ""
	var tlacitko: Button = _najdi_tlacitko(_scena.craft_gump, "", text)
	stav["kliknuto"] = false
	if tlacitko == null:
		stav["tlacitko_chyba"] = ("v okne vyroby neni Button s textem '%s' (tlacitek %d, "
			+ "receptu %d)") % [text, _popis_tlacitek(_scena.craft_gump), stav["receptu"]]
	else:
		stav["tlacitko_recept"] = true
		stav["signal_recept"] = _signal_pripojen(tlacitko)
		if not bool(stav["signal_recept"]):
			stav["tlacitko_chyba"] = ("Button '%s' v okne vyroby existuje, ale nema "
				+ "pripojeny signal 'pressed'") % text
		else:
			stav["kliknuto"] = _stiskni(tlacitko)
	print("[smycka] vyroba: okno ", stav["okno_otevrene"], " receptu ", stav["receptu"],
		" tlacitko receptu ", stav["tlacitko_recept"], " signal ", stav["signal_recept"],
		" klik = ", stav["kliknuto"], " chyba '", stav["tlacitko_chyba"], "'")


func _krok_vyroba() -> void:
	# Overeni az po 6 framech: mezitim hra pozadavek vyzvedla a prikaz vyridila.
	var stav: Dictionary = _ceka.get("vyroba", {})
	var dyka_pred: int = int(stav.get("dyka_pred", 0))
	var zurnal_pred: int = int(stav.get("zurnal_pred", 0))
	var dyka_po: int = _v_batohu("dagger")
	_krok("vyroba", dyka_po > dyka_pred and bool(stav.get("okno_otevrene", false)), {
		"okno_otevrene": bool(stav.get("okno_otevrene", false)),
		"receptu": int(stav.get("receptu", 0)), "kliknuto": bool(stav.get("kliknuto", false)),
		"tlacitko_recept": bool(stav.get("tlacitko_recept", false)),
		"signal_recept": bool(stav.get("signal_recept", false)),
		"tlacitko_chyba": str(stav.get("tlacitko_chyba", "")),
		"recept": RECEPT_DYKA, "dyka_pred": dyka_pred, "dyka_po": dyka_po,
		"ingotu": _v_batohu("iron_ingot"),
	}, zurnal_pred)


func _akce_prodej() -> void:
	# Akce hrace: "pouzij" prodejce -> okno obchodu -> KLIK na Button "Smer"
	# (prepinac buy/sell), KLIK na Button radku s vyrobkem a KLIK na Button
	# "Potvrdit". Pozadavek si vyzvedne az HRA ve svem framu
	# (`app.main._process` -> `Command{t:"vendor", action:"sell"}`).
	var kovar: Vector2i = _kovar_tile()
	var stav: Dictionary = {"zlato_pred": _zlato(), "dyka_pred": _v_batohu("dagger"),
		"zurnal_pred": _zurnal_pocet()}
	for k in ["tlacitko_smer", "signal_smer", "tlacitko_radek", "signal_radek",
			"tlacitko_potvrdit", "signal_potvrdit", "radek", "potvrzeno"]:
		stav[k] = false
	stav["tlacitko_chyba"] = ""
	stav["prepnuto_na_sell"] = false
	_ceka["prodej"] = stav
	if kovar.x < 0:
		_duvod = "ve scene neni prodejce (app/main.prodejce == 0)"
		stav["okno_otevrene"] = false
		stav["tlacitko_chyba"] = "prodejce chybi, okno obchodu nejde otevrit"
		return
	_interact(kovar)
	_cekej(4)
	_scena.vendor_gump.flush()
	stav["okno_otevrene"] = bool(_scena.vendor_gump.je_otevreny())
	# 1) PREPINAC SMERU je Button "Smer" (hra bez nej prodej neumela - namEReno
	# v session D). Hrac na nej klikne; smer se cte z OKNA, ne z navratove
	# hodnoty handleru - kdyz je handler odpojeny, smer zustane "buy".
	var smer_btn: Button = _najdi_tlacitko(_scena.vendor_gump, "Smer")
	if smer_btn == null:
		stav["tlacitko_chyba"] = ("v okne obchodu neni Button 'Smer' (tlacitek %d)"
			% _popis_tlacitek(_scena.vendor_gump))
	else:
		stav["tlacitko_smer"] = true
		stav["signal_smer"] = _signal_pripojen(smer_btn)
		if bool(stav["signal_smer"]):
			_stiskni(smer_btn)
			_scena.vendor_gump.flush()
		else:
			stav["tlacitko_chyba"] = ("Button 'Smer' v okne obchodu existuje, ale nema "
				+ "pripojeny signal 'pressed'")
	stav["prepnuto_na_sell"] = str(_scena.vendor_gump.smer()) == "sell"
	# 2) RADEK S VYROBKEM je Button s textem, ktery sklada okno (`text_radku`).
	var art: int = _dyka_art()
	stav["art"] = art
	if art > 0 and bool(stav["prepnuto_na_sell"]):
		var radek: Dictionary = {}
		for r in _scena.vendor_gump.radky("sell"):
			if int(r.get("item", 0)) == art:
				radek = r
		var text: String = ""
		if not radek.is_empty():
			text = _scena.vendor_gump.text_radku(radek, "sell")
		var radek_btn: Button = _najdi_tlacitko(_scena.vendor_gump, "", text)
		if radek_btn == null:
			stav["tlacitko_chyba"] = ("v okne obchodu neni Button radku '%s' (radek v "
				+ "seznamu sell: %s)") % [text, not radek.is_empty()]
		else:
			stav["tlacitko_radek"] = true
			stav["signal_radek"] = _signal_pripojen(radek_btn)
			if bool(stav["signal_radek"]):
				_stiskni(radek_btn)
				_scena.vendor_gump.flush()
			else:
				stav["tlacitko_chyba"] = ("Button radku '%s' existuje, ale nema "
					+ "pripojeny signal 'pressed'") % text
	# 3) POTVRZENI je Button "Potvrdit".
	var potvrdit_btn: Button = _najdi_tlacitko(_scena.vendor_gump, "Potvrdit")
	if potvrdit_btn == null:
		stav["tlacitko_chyba"] = ("v okne obchodu neni Button 'Potvrdit' (tlacitek %d)"
			% _popis_tlacitek(_scena.vendor_gump))
	else:
		stav["tlacitko_potvrdit"] = true
		stav["signal_potvrdit"] = _signal_pripojen(potvrdit_btn)
		if bool(stav["signal_potvrdit"]):
			stav["potvrzeno"] = _stiskni(potvrdit_btn)
		else:
			stav["tlacitko_chyba"] = ("Button 'Potvrdit' existuje, ale nema pripojeny "
				+ "signal 'pressed'")
	stav["radek"] = bool(stav["tlacitko_radek"]) and bool(stav["signal_radek"])
	print("[smycka] prodej: okno ", stav["okno_otevrene"], " sell ", stav["prepnuto_na_sell"],
		" tlacitka smer/radek/potvrdit ", stav["tlacitko_smer"], "/",
		stav["tlacitko_radek"], "/", stav["tlacitko_potvrdit"], " signaly ",
		stav["signal_smer"], "/", stav["signal_radek"], "/", stav["signal_potvrdit"],
		" potvrzeno ", stav["potvrzeno"], " art ", art, " chyba '", stav["tlacitko_chyba"], "'")


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
		"tlacitko_smer": bool(stav.get("tlacitko_smer", false)),
		"signal_smer": bool(stav.get("signal_smer", false)),
		"tlacitko_radek": bool(stav.get("tlacitko_radek", false)),
		"signal_radek": bool(stav.get("signal_radek", false)),
		"tlacitko_potvrdit": bool(stav.get("tlacitko_potvrdit", false)),
		"signal_potvrdit": bool(stav.get("signal_potvrdit", false)),
		"tlacitko_chyba": str(stav.get("tlacitko_chyba", "")),
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
