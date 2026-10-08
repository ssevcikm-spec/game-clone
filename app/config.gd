extends RefCounted
# app.config (M9, 15. session) - TYPOVANA KONFIGURACE na jednom miste.
#
# PROC: `data/balance.json` se do M9 cetl AD HOC na nekolika mistech
# (`sim.movement`, `sim.skill_gain`, `app.main`) a nikdo nekontroloval, jestli
# hodnota existuje, ma spravny typ a je v rozsahu. Chybejici klic znamenal ticho
# (kód si vzal svuj default), preklep v klici taky. Tenhle modul drzi JEDNU
# tabulku `SCHEMA` (klic + typ + default + rozsah) a umi rict, co s daty nesedi.
#
# Vzor: ModernUO `Projects/Server/Configuration/ServerConfiguration.cs:43`
# (`GetSetting`/`GetOrUpdateSetting`) - typovany pristup k nastaveni.
#
# SMLOUVA (docs/04 §4.2, granule `app.config`; `provides` v roadmape rika
# `get`, ale to jmeno NELZE pouzit - viz `value()`):
#   `value(key, default)` - hodnota klice; neznameho klice se to NAHLASI
#                          (varovani jednou na klic) a vrati se `default`,
#   `known_keys()`       - setrideny seznam vsech klice ze `SCHEMA`,
#   `check()`            - seznam chyb (typ, rozsah, neznamy klic v datech,
#                          chybejici hodnota). Prazdny seznam = vsechno sedi.
# Navic (co smlouva nepinuje, ale volajici to potrebuje):
#   `all()`              - surova data (stejny objekt, jaky dostava `SimWorld`),
#   `values()`           - zplostely slovnik "teckovych" klicu,
#   `source(key)`        - odkud hodnota je: "data" / "default",
#   `stats()`            - pocty pro mereni (klice, chyby, nezname).
#
# ⚠ VSTUP JE `data/balance.json` (granule `data.balance`) - modul si ho nacita
# sam, aby se dal testovat na VLASTNIM souboru (`-- --config-script=…`) a aby
# mutacni test mohl vratit vadu do kopie. Neexistujici cesta NENI ticho:
# `check()` to rekne a `get()` vrati default.

const BALANCE_PATH := "res://data/balance.json"

# Klic -> typ, default a rozsah. `values` = povolene hodnoty (pro stringy).
# Poradi je stejne jako v `data/balance.json`, aby se to dalo cist vedle sebe.
const SCHEMA := {
	"constants.SKILL_CAP": {"type": TYPE_INT, "default": 7000, "min": 0, "max": 100000},
	"constants.STAT_CAP": {"type": TYPE_INT, "default": 225, "min": 0, "max": 10000},
	"combat_era": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	"era.combat": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	"era.loot": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	"era.content": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	"era.ui": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	"era.movement": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	# `era.skill_gain` (16. session, rozhodnuti R1): "pre-aos" = neuspech uci
	# (0,2), "aos" = neucI (0,0). Cte ho `sim.skill_gain`.
	"era.skill_gain": {"type": TYPE_STRING, "default": "aos", "values": ["pre-aos", "aos"]},
	"era.tooltips": {"type": TYPE_STRING, "default": "on", "values": ["on", "off"]},
	"stat_gain.delay_ms": {"type": TYPE_INT, "default": 2000, "min": 0, "max": 60000},
	"stat_gain.chance_percent": {"type": TYPE_INT, "default": 25, "min": 0, "max": 100},
	"stamina_drain_model": {"type": TYPE_STRING, "default": "run_only",
		"values": ["run_only", "always", "never"]},
	"ggs_on": {"type": TYPE_BOOL, "default": true},
	"insurance_on": {"type": TYPE_BOOL, "default": false},
	"anti_macro": {"type": TYPE_BOOL, "default": false},
	# POCATECNI STATY HRACE (19. session, 2026-10-08 - vada V3 ze zadani 19).
	# Uzivatel: "Postava bezi jen asi 3 policka ... dosla stamina a neregeneruje
	# se. Prozatim bych to vypnul nebo nastavil vychozi staty na 130."
	# NAMERENO: `sim.regen` (doplnovani staminy) NEEXISTUJE, takze pri vychozich
	# statech 10/10/10 je `max_stam = DEX = 10` a po 10 krocich behu uz postava
	# jen chodi - NAPOZADY. Vyssi DEX je PROZATIMNI reseni, ne oprava modelu:
	# trvala oprava je `sim.regen` (viz "Co se NEOPRAVILO" v HANDOVERu).
	# `max_hp = 50 + STR/2` a `max_mana = INT` plati dal (README vzorce).
	"player_start_stats.STR": {"type": TYPE_INT, "default": 75, "min": 10, "max": 225},
	"player_start_stats.DEX": {"type": TYPE_INT, "default": 130, "min": 10, "max": 225},
	"player_start_stats.INT": {"type": TYPE_INT, "default": 20, "min": 10, "max": 225},
	# POCATECNI SKILLY HRACE (20. session, 2026-10-08 - pokyn uzivatele "dej
	# hracovi skill z profesni sablony"). Hodnoty jsou v DESETINACH (30.0 = 300).
	# ⚠ NAMERENO (`_analyza/p23-interakce.gd`): se vsemi skilly 0 je sance sberu
	# `skill/1000` = 0 %, takze hrac za 30 uderu nevytěžil NIC; se skillem 30.0
	# dala zila rudu za 2 udery. Sablona je z `research/profese.json`
	# (Blacksmith: Blacksmith 30, Tinkering 30, Mining 30, Tailoring 30) a je
	# PROZATIMNI - trvaly mechanismus je vyber profese pri tvore postavy.
	# ⚠ JMENO JE Z NASICH DAT, NE ZE SABLONY: `skills.mul` ma "Blacksmithy",
	# kdezto profesni sablona "Blacksmith" - s druhym jmenem by se skill TISE
	# nepridal (`app.main.start_skills` to hlasi a case `interact` to chyti).
	# Kdo prida dalsi skill, prida sem radek: `app.main.start_skills()` cte
	# VSECHNY klice `player_start_skills.*` ze SCHEMA, ne z kódu.
	"player_start_skills.Blacksmithy": {"type": TYPE_INT, "default": 300, "min": 0, "max": 1200},
	"player_start_skills.Tinkering": {"type": TYPE_INT, "default": 300, "min": 0, "max": 1200},
	"player_start_skills.Mining": {"type": TYPE_INT, "default": 300, "min": 0, "max": 1200},
	"player_start_skills.Tailoring": {"type": TYPE_INT, "default": 300, "min": 0, "max": 1200},
}
# Klice, ktere v datech byt MAJI, ale nejsou nastaveni: dokumentace a zdroje.
# Kdyby se pocitaly jako "neznamy klic", hlasila by se vada u spravnych dat.
# Bere se POSLEDNI cast cesty (`stat_gain.note` je dokumentace uvnitr skupiny).
const DOKUMENTACNI := ["_popis", "sources", "note", "popis", "comment"]

var _data: Dictionary = {}
var _hodnoty: Dictionary = {}        # "teckove" klice -> hodnota
var _nezname: Array = []             # klice v datech, ktere SCHEMA nezna
var _hlasene: Dictionary = {}        # nezname klice, o kterych uz bylo hlaseno
var _cesta: String = BALANCE_PATH
var _nacteno: bool = false


func _init(path: String = BALANCE_PATH) -> void:
	_cesta = path
	nacti()


func nacti() -> bool:
	# Nacte a ZPLOSTI data (`era.combat` je v JSON zanorene). Vraci false, kdyz
	# soubor neni nebo neni JSON objekt - `check()` to pak hlasi jako chybu.
	_data = {}
	_hodnoty = {}
	_nezname = []
	_nacteno = false
	if not FileAccess.file_exists(_cesta):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_cesta))
	if not (parsed is Dictionary):
		return false
	_data = parsed
	_zplost(_data, "")
	for klic in _hodnoty.keys():
		if not SCHEMA.has(klic) and not _je_dokumentacni(str(klic)):
			_nezname.append(klic)
	_nezname.sort()
	_nacteno = true
	return true


func _je_dokumentacni(cesta: String) -> bool:
	# Dokumentace muze byt KDEKOLI v ceste: `sources.UNVERIFIED` ma posledni
	# cast "UNVERIFIED", ale dokumentacni je uz skupina `sources` (namEReno:
	# bez tohohle se hlasilo 16 falesnych "preklepu" v korektnich datech).
	var casti: PackedStringArray = cesta.split(".")
	var posledni: String = str(casti[casti.size() - 1])
	if posledni.begins_with("_"):
		return true
	for cast in casti:
		if DOKUMENTACNI.has(str(cast)):
			return true
	return false


func _zplost(uzel, prefix: String) -> void:
	for klic in uzel.keys():
		var cesta: String = str(klic) if prefix == "" else prefix + "." + str(klic)
		var hodnota = uzel[klic]
		if hodnota is Dictionary:
			_zplost(hodnota, cesta)
		else:
			_hodnoty[cesta] = _normalizuj(cesta, hodnota)


func _normalizuj(cesta: String, hodnota):
	# ⚠ NAMERENO 2026-10-08: `JSON.parse_string` vraci VSECHNA cisla jako FLOAT
	# (`7000` z `data/balance.json` je `7000.0`), takze kazdy klient SCHEMA typu
	# TYPE_INT hlasil "spatny typ" - a tim se preskocila i kontrola rozsahu.
	# Typovana konfigurace proto cele cislo na int PREVEDE (a jen kdyz je
	# skutecne cele: `1.5` u int klice zustane chybou).
	var polozka: Dictionary = SCHEMA.get(cesta, {})
	if polozka.is_empty():
		return hodnota
	if int(polozka.get("type", TYPE_NIL)) == TYPE_INT and typeof(hodnota) == TYPE_FLOAT:
		if is_equal_approx(float(hodnota), roundf(float(hodnota))):
			return int(roundf(float(hodnota)))
	return hodnota


func value(key: String, default = null):
	# ⚠ JMENO JE `value`, NE `get` (odchylka od `provides` v roadmape, zapsana
	# i v docs/04 §4.2.1): `Object` ma `get(StringName)` a GDScript hlasi
	# "The method get() overrides a method from native class Object" jako CHYBU
	# parseru - soubor se pak VUBEC nenacte. Je to stejna rodina jako `set_position`
	# u `ui.hud` (HANDOFF, vec N7).
	# Neznamy klic se NAHLASI - ticha nahrada defaultem je presne to, co
	# v projektu vedlo k hodinam hledani ("klic se preklepl a nikdo to nevidel").
	var polozka: Dictionary = SCHEMA.get(key, {})
	if polozka.is_empty():
		if not _hlasene.has(key):
			_hlasene[key] = true
			push_warning("app.config: klic '%s' neni ve SCHEMA - vracim default" % key)
		return default
	if _hodnoty.has(key):
		return _hodnoty[key]
	return polozka.get("default", default)


func known_keys() -> Array:
	var out: Array = SCHEMA.keys()
	out.sort()
	return out


func values() -> Dictionary:
	return _hodnoty.duplicate()


func all() -> Dictionary:
	# Surova data (stejny objekt dostava `SimWorld`) - `app.main` je predava dal,
	# takze se zmena zavedenim `app.config` neprojevi nikde jinde.
	return _data


func source(key: String) -> String:
	return "data" if _hodnoty.has(key) else "default"


func check() -> Array:
	# Kontrola DAT proti SCHEMA: chybejici hodnota, spatny typ, mimo rozsah,
	# hodnota mimo vycet a neznamy klic. Vsechno se hlasi i s hodnotou, aby se
	# dalo rozhodnout bez otevirani JSONu.
	var chyby: Array = []
	if not _nacteno:
		chyby.append("data se nectou: " + _cesta)
		return chyby
	for klic in known_keys():
		var polozka: Dictionary = SCHEMA[klic]
		if not _hodnoty.has(klic):
			chyby.append("%s chybi (default %s)" % [klic, str(polozka.get("default"))])
			continue
		var hodnota = _hodnoty[klic]
		var typ: int = int(polozka.get("type", TYPE_NIL))
		if typeof(hodnota) != typ:
			chyby.append("%s ma typ %s, ceka se %s (hodnota %s)"
				% [klic, type_string(typeof(hodnota)), type_string(typ), str(hodnota)])
			continue
		if typ == TYPE_INT:
			var mini_: int = int(polozka.get("min", -2147483648))
			var maxi_: int = int(polozka.get("max", 2147483647))
			if int(hodnota) < mini_ or int(hodnota) > maxi_:
				chyby.append("%s = %d je mimo rozsah %d..%d"
					% [klic, int(hodnota), mini_, maxi_])
		if polozka.has("values") and not polozka["values"].has(hodnota):
			chyby.append("%s = %s neni z povolenych %s"
				% [klic, str(hodnota), str(polozka["values"])])
	for klic in _nezname:
		chyby.append("%s v datech neni ve SCHEMA (preklep?)" % klic)
	return chyby


func stats() -> Dictionary:
	return {"cesta": _cesta, "nacteno": _nacteno, "hodnot": _hodnoty.size(),
		"znamych": SCHEMA.size(), "neznamych": _nezname.size(),
		"chyb": check().size(), "z_defaultu": _hodnoty.size() - _pocet_z_dat()}


func _pocet_z_dat() -> int:
	var n: int = 0
	for klic in SCHEMA.keys():
		if _hodnoty.has(klic):
			n += 1
	return n
