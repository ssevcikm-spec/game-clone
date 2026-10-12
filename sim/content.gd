class_name SimContent
extends RefCounted
# sim.content - VRSTVY OBSAHU: stabilni ID, poradi nacitani, jeden sev pro mody.
#
# CO TO JE: jedno misto, kde se odpovida na dve otazky, ktere dnes nikde
# nebyly:
#   * KTERA vrstva obsahu vyhrava pro dany soubor (podle PORADI, ne podle
#     poradi slovniku - docs/02 §2.3),
#   * JAK se vrstvy jmenuji, v jakem poradi se nactly a co ktera deklaruje
#     (`manifest()`) - to je identita obsahu, na kterou se povesi save
#     (dalsi krok, viz `NAVRH-MODDING-2026-10-11.md` §4 S2).
#
# PROC TO EXISTUJE (namEReno 2026-10-11, `_analyza/p59-kotvy-dat.py`: walk
# vsech .gd bez komentaru, vzor "res://data/*.json"):
#   * 18 produkcnych .gd souboru ma cestu k datum ZADRATOVANOU,
#   * z toho 27 je MODULOVYCH KONSTANT (`const X_PATH := "res://data/...")` -
#     cestu zapeenou v modulu volajici NEMUZE prebit,
#   * 17 literalu je v `app/main`, ktery je predava systemum - tam staci
#     prekladat cestu na jednom miste (to dela `_cesta()` v `app/main`).
# Tohle neni vada vernosti - je to vada MODIFIKOVATELNOSTI: modder nema jak
# rict "tenhle soubor ber odsud".
#
# STABILNI ID: `id` vrstvy je male ASCII (`[a-z0-9_.-]`), napr. `base` nebo
# `mod.example`. Je to ID ZDROJE obsahu, NE ID zaznamu v datech (klic
# predmetu je dnes `tile`; stabilni string ID zaznamu je dalsi krok, §4 S3).
# **Mod MUSI mit id jako jmenny prostor s teckou** (rozhodnuti 2026-10-11:
# mody pisou cizi lide a id je stabilni identita - pravidlo zavedene pozdeji
# by rozbilo mody, ktere uz jsou venku). Zakladni `base` tecku mit nemusi.
#
# PORADI: `order` je INT a je POVINNY; vyssi vyhrava. Pri shode `order`
# rozhoduje `id` vzestupne, takze vysledek nezalezi na poradi vlozeni ani na
# poradi slozek v adresari. Kdo poradi neurci, dostane CHYBU - tichy default
# by znamenal, ze "kdo vyhraje" je nahoda.
#
# CO MODUL NEDELA (pojmenovane, ne tichy dluh):
#   * neslucuje zaznamy - mod umi soubor PREBIT, ne do nej pridat radek
#     (slucovani je §4 S3 navrhu),
#   * nedrzi hash obsahu souboru - to je dnes `data_version` v `sim.save`,
#   * nespousti zadny skript modu (R1: mod je OBSAH, ne kod - rozhodnuti
#     agenta 2026-10-11, uzivatel potvrdil "prozatim jen uprava obsahu").
#
# CHYBY SE VRACI SEZNAMEM (`errors()`), ne vyjimkou: rozbity mod nesmi shodit
# start hry, ale musi byt VIDET (`docs/08 §8.6`).

const HashScript = preload("res://core/hash.gd")

const BASE_DECL := "res://data/content-layers.json"
const MODS_DIR := "user://mods"
const MOD_FILE := "mod.json"
# Verze FORMATU deklarace (`data/content-layers.json` i `mod.json`). Neni to
# verze hry ani verze save - meni se, kdyz se zmeni vyznam klicu.
const FORMAT_VERSION: int = 1
# Strop poctu vrstev: rozbity `user://mods` s tisici slozkami nesmi zhltnout
# start. Je to guard, ne funkce - hlaseny jako chyba.
const MAX_LAYERS: int = 64
const ID_PATTERN := "^[a-z0-9][a-z0-9_.-]*$"
# Klice, ktere smi zaznam vrstvy mit; cokoli jineho je CHYBA (preklep v modu
# se nesmi tise ignorovat). Klice zacinajici "_" jsou komentar.
const ALLOWED_KEYS: Array[String] = ["id", "version", "order", "required", "root", "files"]

var _layers: Array = []
var _errors: Array[String] = []


func format_version() -> int:
	return FORMAT_VERSION


func errors() -> Array:
	return _errors.duplicate()


# -- vrstvy ----------------------------------------------------------------

func add(id: String, version: int, order: int, files: Array, root: String,
		required: bool) -> bool:
	# Vraci true, kdyz vrstva prosla kontrolou a je zapsana. Kazda vada se
	# zapise do `errors()` - volajici ji nesmi zahodit.
	if _layers.size() >= MAX_LAYERS:
		_error("vrstev je vic nez %d - dalsi se nepridava (rozbity mods adresar?)"
			% MAX_LAYERS)
		return false
	if not _valid_id(id):
		_error("vrstva '%s': id musi byt male ASCII [a-z0-9_.-] a zacinat pismenem/cislici" % id)
		return false
	for l in _layers:
		if str(l["id"]) == id:
			_error("vrstva '%s': id uz je pouzite (druha vrstva se nepridava)" % id)
			return false
	if order < 0:
		_error("vrstva '%s': order musi byt >= 0 (namEReno %d)" % [id, order])
		return false
	if version < 1:
		_error("vrstva '%s': version musi byt >= 1 (namEReno %d)" % [id, version])
		return false
	if not (root.begins_with("res://") or root.begins_with("user://")):
		_error("vrstva '%s': root musi zacinat 'res://' nebo 'user://' (namEReno '%s')" % [id, root])
		return false
	if root.contains(".."):
		_error("vrstva '%s': root nesmi obsahovat '..' (namEReno '%s')" % [id, root])
		return false
	var ciste: Array[String] = []
	for f in files:
		var rel := str(f)
		if not _valid_rel(rel):
			_error("vrstva '%s': soubor '%s' neni relativni cesta bez '..' a ':'" % [id, rel])
			continue
		if not ciste.has(rel):
			ciste.append(rel)
	ciste.sort()
	_layers.append({
		"id": id, "version": version, "order": order, "required": required,
		"root": root, "files": ciste,
	})
	_sort()
	return true


func layers() -> Array:
	# Kopie v poradi nacitani (nizsi `order` prvni). Vracime kopie, aby si
	# volajici nerozbil vnitrni stav.
	var out: Array = []
	for l in _layers:
		out.append({
			"id": l["id"], "version": l["version"], "order": l["order"],
			"required": l["required"], "root": l["root"],
			"files": (l["files"] as Array).duplicate(),
		})
	return out


func layer_ids() -> Array:
	var out: Array = []
	for l in _layers:
		out.append(str(l["id"]))
	return out


func layer_count() -> int:
	return _layers.size()


# -- rozliseni souboru (sev) ----------------------------------------------

func providers(rel: String) -> Array:
	# Vsechny vrstvy, ktere soubor deklaruji, vzestupne podle poradi.
	# Posledni je vitez; seznam je doklad pro "kdo to prebil".
	var out: Array = []
	for l in _layers:
		if (l["files"] as Array).has(rel):
			out.append(str(l["id"]))
	return out


func path_for(rel: String) -> String:
	# Vitez je vrstva s NEJVYSSIM `order`, ktera soubor deklaruje A SOUBOR
	# EXISTUJE. Chybejici soubor se PRESKOCI - hra nesmi spadnout na preklep
	# v modu - a je VIDET v `missing_files()`; ticha nahrada to neni.
	var i: int = _layers.size() - 1
	while i >= 0:
		var l: Dictionary = _layers[i]
		if (l["files"] as Array).has(rel):
			var p: String = str(l["root"]) + rel
			if FileAccess.file_exists(p):
				return p
		i -= 1
	return ""


func path_or_default(rel: String) -> String:
	# Co hra pouzije, kdyz o souboru nic nevi (zakladni cesta). Prave timhle
	# se "mod neexistuje" a "mod existuje, ale soubor nedodal" nerozlisuje
	# na urovni cesty - rozdil je v `errors()`/`missing_files()`.
	var p: String = path_for(rel)
	return p if p != "" else "res://" + rel


func declared_files() -> Array:
	var out: Array = []
	for l in _layers:
		for rel in (l["files"] as Array):
			if not out.has(rel):
				out.append(rel)
	out.sort()
	return out


func missing_files() -> Array:
	# Deklarovane soubory, ktere na disku NEJSOU ("id:rel"). Neni to prazdny
	# seznam jako "vse je v poradku" - kdo ho cte, ma ho VYPISAT.
	var out: Array = []
	for l in _layers:
		for rel in (l["files"] as Array):
			if not FileAccess.file_exists(str(l["root"]) + str(rel)):
				out.append("%s:%s" % [str(l["id"]), str(rel)])
	out.sort()
	return out


func override_count() -> int:
	return overrides().size()


func overrides() -> Array:
	# Soubory, ktere poskytuje VIC NEZ JEDNA vrstva - tedy "kdo co prebil".
	# Mod, ktery meni, co je ve hre, je legitimni (rozhodnuti uzivatele
	# 2026-10-11), ale NESMI se to stat tise: kdo se ptá "proč se to chová
	# jinak", to musi dostat pojmenovane (`providers(rel)`).
	var pocty: Dictionary = {}
	for l in _layers:
		for rel in (l["files"] as Array):
			pocty[rel] = int(pocty.get(rel, 0)) + 1
	var out: Array = []
	for rel in pocty.keys():
		if int(pocty[rel]) > 1:
			out.append(str(rel))
	out.sort()
	return out


# -- manifest (identita obsahu) -------------------------------------------

func manifest() -> Array:
	# Serazeny seznam vrstev bez cest - jen to, co je potreba k rozhodnuti
	# "je tohle tyz obsah?". Cesty do manifestu NEPATRI (save nesmi zaviset
	# na umisteni instalace).
	var out: Array = []
	for l in _layers:
		out.append({
			"id": str(l["id"]), "version": int(l["version"]),
			"order": int(l["order"]), "required": bool(l["required"]),
		})
	return out


func manifest_hash() -> String:
	return HashScript.new().of_state([FORMAT_VERSION, manifest()])


func report() -> Dictionary:
	# Pro cloveka/do logu. `overrides` a `missing` jsou pocty, ne seznamy -
	# seznamy vraci `providers()` a `missing_files()`.
	var povinnych: int = 0
	for l in _layers:
		if bool(l["required"]):
			povinnych += 1
	return {
		"layers": _layers.size(),
		"files": declared_files().size(),
		"overrides": override_count(),
		"missing": missing_files().size(),
		"required": povinnych,
		"errors": _errors.size(),
	}


# -- nacteni deklarace a modu --------------------------------------------

func discover(decl_path: String = BASE_DECL, mods_dir: String = MODS_DIR) -> int:
	# Nacte zakladni deklaraci a pak mody z `mods_dir` (prazdny retezec = jen
	# zaklad; tim se da hra spustit bez modu). Vraci pocet PRIDANYCH vrstev.
	var pred: int = _layers.size()
	_load_declaration(decl_path)
	if mods_dir != "":
		_load_mods(mods_dir)
	return _layers.size() - pred


func _load_declaration(path: String) -> void:
	var raw: Variant = _read_json(path)
	if raw == null:
		_error("deklarace vrstev '%s' chybi nebo neni citelny JSON - bere se jen zakladni cesta" % path)
		return
	if not (raw is Dictionary):
		_error("deklarace vrstev '%s' neni slovnik" % path)
		return
	var list: Variant = (raw as Dictionary).get("layers")
	if not (list is Array) or (list as Array).is_empty():
		_error("deklarace vrstev '%s' nema neprazdne pole 'layers'" % path)
		return
	for entry in (list as Array):
		if not (entry is Dictionary):
			_error("deklarace vrstev '%s': zaznam neni slovnik" % path)
			continue
		_add_from_record(entry, "res://", "vrstva z '%s'" % path, false)


func _load_mods(mods_dir: String) -> void:
	var dir := DirAccess.open(mods_dir)
	if dir == null:
		# Zadny mods adresar je NORMALNI stav, ne chyba.
		return
	var names: Array[String] = []
	for d in dir.get_directories():
		names.append(str(d))
	names.sort()
	for name in names:
		if name.begins_with("."):
			continue
		var mod_dir: String = mods_dir + "/" + name + "/"
		var mod_path: String = mod_dir + MOD_FILE
		if not FileAccess.file_exists(mod_path):
			_error("mod '%s': chybi %s - adresar se preskoci" % [name, MOD_FILE])
			continue
		var raw: Variant = _read_json(mod_path)
		if not (raw is Dictionary):
			_error("mod '%s': %s neni citelny JSON slovnik" % [name, MOD_FILE])
			continue
		_add_from_record(raw, mod_dir, "mod '%s'" % name, true)


func _add_from_record(rec: Dictionary, root: String, kde: String, je_mod: bool) -> bool:
	for k in rec.keys():
		var key := str(k)
		if key.begins_with("_"):
			continue
		if not ALLOWED_KEYS.has(key):
			_error("%s: nezname pole '%s' (preklep se neignoruje)" % [kde, key])
			return false
	if je_mod and rec.has("root"):
		# Mod nesmi utect ze sve slozky: root je VZDY adresar modu. Jinak by
		# mod mohl prebit soubor mimo sebe a "odkud se to vzalo" by se nedalo
		# rict.
		_error("%s: mod nesmi mit vlastni 'root' (bere se adresar modu)" % kde)
		return false
	if je_mod:
		# ID MODU JE JMENNY PROSTOR (alespon jedna tecka). Duvod je casovy:
		# mody pisou CIZI lide a id je STABILNI identita - kdyby se pravidlo
		# zavedlo pozdeji, rozbije to mody, ktere uz jsou venku. Zakladni
		# vrstva (`base`) tecku mit nemusi - neni to cizi jmeno.
		var id_modu: String = str(rec.get("id", ""))
		if not id_modu.contains("."):
			_error("%s: id modu musi byt jmenny prostor s teckou (napr. 'autor.mod'), namEReno '%s'"
				% [kde, id_modu])
			return false
	if not rec.has("order"):
		_error("%s: chybi 'order' - poradi nacitani musi byt VYRECENE" % kde)
		return false
	var files: Variant = rec.get("files", [])
	if not (files is Array):
		_error("%s: 'files' musi byt seznam cest" % kde)
		return false
	var efektivni_root: String = str(rec.get("root", root)) if not je_mod else root
	return add(
		str(rec.get("id", "")),
		int(rec.get("version", 0)),
		int(rec.get("order", 0)),
		files as Array,
		efektivni_root,
		bool(rec.get("required", false)))


# -- pomocne ---------------------------------------------------------------

func _valid_id(id: String) -> bool:
	if id == "" or id.length() > 64:
		return false
	var re := RegEx.new()
	re.compile(ID_PATTERN)
	return re.search(id) != null


func _valid_rel(rel: String) -> bool:
	if rel == "" or rel.contains("..") or rel.contains("\\") or rel.contains(":"):
		return false
	if rel.begins_with("/"):
		return false
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _sort() -> void:
	# Poradi: `order` vzestupne, pri shode `id` vzestupne. Nikdy podle poradi
	# vlozeni (docs/02 §2.3) - jinak by vysledek zavisel na tom, v jakem
	# poradi Godot nacetl slozky v adresari.
	_layers.sort_custom(func(a, b):
		if int(a["order"]) != int(b["order"]):
			return int(a["order"]) < int(b["order"])
		return str(a["id"]) < str(b["id"]))


func _error(text: String) -> void:
	_errors.append(text)
