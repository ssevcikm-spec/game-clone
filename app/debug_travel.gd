extends RefCounted
# app.debug_travel - DEBUG TELEPORT mezi testovacími body (2026-10-20).
#
# ⚠⚠ CO TO JE: **DEBUG POMŮCKA, NE HERNÍ FUNKCE.** Uživatel chtěl "teleport
# nebo jinou možnost, jak se pohybovat mezi testovacími body (těžba, boj,
# obchod)". Tenhle modul k tomu drží seznam bodů z `data/test-points.json`,
# umí je ověřit a umí na ně SKOČIT (nastaví pozici hráče a kamery). Nic jiného:
#   * nemění stav simulace (žádný příkaz, žádná událost v sim, žádný tik),
#   * nemění uložená data (save ani replay),
#   * nemění art ani determinismus - `state_hash` se po teleportu nehne,
#     protože pozice hráče je klientská věc a do hashe nevstupuje (G8/G9 beze
#     změny, viz HANDOFF blok 2026-10-20).
#
# PROČ MODUL A NE ROVNOU V UI: `ui/` je tenký klient (docs/04 §4.1) - nesmí
# vědět o `sim`, `app/` ani o klávesách. Validace dat a teleport jsou rozhodnutí,
# takže patří sem; okno `ui/debug_travel.gd` jen vypíše, co dostane.
#
# "CHYBĚJÍCÍ BOD = VADA, NE TICHO" (docs/09 §9.6): `zpracuj()` vrací seznam
# VAD (`vady()`) a vadné záznamy PŘESKAKUJE s počtem (`preskoceno()`). Kdo
# seznam staví, musí vady vypsat (`app/main` to dělá přes `push_warning`),
# a brána G22 je měří - prázdný seznam bez varování by vypadal jako
# "všechno je v pořádku".
#
# CESTA K DATŮM JE PARAMETR (G18): `_init(cesta)` - modul si `res://data/...`
# nečte z konstanty v těle.

# Co smí být v `proc`: to je smlouva s bránou G22 (každý druh musí mít svůj bod
# a brána u něj měří, že je ta věc na dosah).
const PROC_DRUHY: Array[String] = ["start", "tezba", "kovani", "obchod", "boj"]
# Maximální počet bodů: číslice 1-9 jsou klávesy (`app/player_controller`).
# Víc bodů by nebylo čím vyvolat - a tichý 10. bod by byl mrtvá data.
const MAX_BODU: int = 9
const POVINNA_POLE: Array[String] = ["id", "nazev", "x", "y", "z", "proc"]

var _cesta: String = ""
var _body: Array[Dictionary] = []
var _vady: Array[String] = []
var _titulek: String = ""
var _prazdno: String = ""
var _preskoceno: int = 0
var _panel = null                  # `ui/debug_travel.gd` (injektuje `app/main`)
var _hrac = null                   # `sim.entity.mobile` hráče
var _controller = null             # `app/player_controller.gd` (kamera + pozice)
var _teleportu: int = 0
# HLÁŠENÍ DO ŽURNÁLU (Callable z `app/main`). Když není, teleport funguje dál -
# jen se o něm hráč nedozví ze žurnálu (a `hlaseni_chybi()` to řekne nahlas).
var hlaseni: Callable = Callable()


func _init(cesta: String = "") -> void:
	# Nacte se VZDY, i s prazdnou cestou: "nic se nenacetlo" musi byt VIDET
	# ve `vady()` - ticha nula by vypadala jako "zadny bod neni potreba".
	_cesta = cesta
	nacti(cesta)


# -- validace dat (čistá funkce, testovatelná bez scény) --------------------

static func zpracuj(data) -> Dictionary:
	# Vrací `{titulek, prazdno, body, vady, preskoceno}`. Nikdy nehází výjimku:
	# rozbitá data jsou VADA v seznamu, ne pád hry (docs/08 §8.6).
	var out := {"titulek": "", "prazdno": "", "body": [], "vady": [], "preskoceno": 0}
	if not (data is Dictionary):
		(out["vady"] as Array).append("data/test-points.json není slovník")
		return out
	out["titulek"] = str((data as Dictionary).get("titulek", ""))
	out["prazdno"] = str((data as Dictionary).get("_prazdno", ""))
	var zdroj = (data as Dictionary).get("body", [])
	if not (zdroj is Array):
		(out["vady"] as Array).append("`body` v data/test-points.json není seznam")
		return out
	if (zdroj as Array).is_empty():
		# Prázdný seznam NENÍ "v pořádku": seznam bez bodů je vada dat.
		(out["vady"] as Array).append("`body` je prázdné - není na co teleportovat")
		return out
	var videne_id := {}
	var videne_dlazdice := {}
	for i in range((zdroj as Array).size()):
		var rec = (zdroj as Array)[i]
		var problem: String = vadny_bod(rec, i)
		if problem == "":
			var bod: Dictionary = _normalizuj(rec, i)
			if videne_id.has(bod["id"]):
				problem = "bod [%d]: id '%s' je v datech dvakrát" % [i, bod["id"]]
			elif videne_dlazdice.has(bod["dlazdice"]):
				problem = "bod [%d]: dlaždice %s je v datech dvakrát (body musí být RŮZNÉ)" \
					% [i, bod["dlazdice"]]
			else:
				videne_id[bod["id"]] = true
				videne_dlazdice[bod["dlazdice"]] = true
				(out["body"] as Array).append(bod)
		if problem == "":
			continue
		(out["vady"] as Array).append(problem)
		out["preskoceno"] = int(out["preskoceno"]) + 1
	if (out["body"] as Array).size() > MAX_BODU:
		(out["vady"] as Array).append(
			"bodů je %d, maximum je %d (klávesy jsou číslice 1-9)"
				% [(out["body"] as Array).size(), MAX_BODU])
	return out


static func vadny_bod(rec, index: int) -> String:
	# Vrací "" (bod je v pořádku) nebo text vady. Kontroluje se tvar, ne hodnoty
	# na mapě - to umí jen živá scéna (brána G22).
	if not (rec is Dictionary):
		return "bod [%d]: není slovník" % index
	for pole in POVINNA_POLE:
		if not (rec as Dictionary).has(pole):
			return "bod [%d]: chybí pole '%s'" % [index, pole]
	var id: String = str((rec as Dictionary).get("id", ""))
	if id.strip_edges() == "":
		return "bod [%d]: prázdné 'id'" % index
	# ID je KLÍČ ROZHRANÍ: ASCII malé, bez diakritiky a mezer (jinak by se
	# v kódu, v logu a v bráně psalo třemi způsoby).
	for i in range(id.length()):
		var z: String = id[i]
		if not (z in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
				"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
				"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "_"]):
			return "bod [%d]: 'id' musí být malé ASCII (a-z, 0-9, _), je '%s'" % [index, id]
	if str((rec as Dictionary).get("nazev", "")).strip_edges() == "":
		return "bod [%d]: prázdné 'nazev' (hráč musí vidět, kam skáče)" % index
	for pole in ["x", "y", "z"]:
		var h = (rec as Dictionary).get(pole)
		if not ((h is int) or (h is float)):
			return "bod [%d]: '%s' není číslo" % [index, pole]
		if int(h) < 0:
			return "bod [%d]: '%s' je záporné (%d)" % [index, pole, int(h)]
	var proc: String = str((rec as Dictionary).get("proc", ""))
	if not (proc in PROC_DRUHY):
		return "bod [%d]: 'proc' musí být jedno z %s, je '%s'" \
			% [index, ", ".join(PackedStringArray(PROC_DRUHY)), proc]
	return ""


static func _normalizuj(rec: Dictionary, index: int) -> Dictionary:
	# JEDINÉ místo, kde se z JSONu (čísla jsou float) stanou int souřadnice.
	var x: int = int(rec.get("x", 0))
	var y: int = int(rec.get("y", 0))
	var z: int = int(rec.get("z", 0))
	return {
		"cislo": index + 1,
		"id": str(rec.get("id", "")),
		"nazev": str(rec.get("nazev", "")),
		"x": x, "y": y, "z": z,
		"dlazdice": "%d,%d" % [x, y],
		"proc": str(rec.get("proc", "")),
		"poznamka": str(rec.get("poznamka", "")),
	}


# -- načtení ---------------------------------------------------------------

func nacti(cesta: String) -> int:
	# Načte a ZVALIDUJE data; vrací počet POUŽITELNÝCH bodů. Chybějící nebo
	# rozbitý soubor se hlásí do `vady()` (nikdy tiché prázdno).
	_cesta = cesta
	_body = []
	_vady = []
	_preskoceno = 0
	if cesta == "":
		_vady.append("cesta k test-points.json není zadaná (parametr `_init`)")
		return 0
	if not FileAccess.file_exists(cesta):
		_vady.append("chybí " + cesta)
		return 0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(cesta))
	if parsed == null:
		_vady.append(cesta + " se nedá přečíst jako JSON")
		return 0
	var vysledek: Dictionary = zpracuj(parsed)
	_titulek = str(vysledek["titulek"])
	_prazdno = str(vysledek["prazdno"])
	_preskoceno = int(vysledek["preskoceno"])
	for v in vysledek["vady"]:
		_vady.append(str(v))
	for b in vysledek["body"]:
		_body.append(b)
	if _titulek == "":
		_titulek = "TEST POZICE - teleport (debug)"
	return _body.size()


# -- stav (pro `app/main`, okno, sondu a test) ------------------------------

func cesta() -> String:
	return _cesta


func body() -> Array[Dictionary]:
	return _body.duplicate(true)


func vady() -> Array[String]:
	return _vady.duplicate()


func preskoceno() -> int:
	return _preskoceno


func pocet() -> int:
	return _body.size()


func titulek() -> String:
	return _titulek


func ma_body() -> bool:
	return not _body.is_empty()


func teleportu() -> int:
	# Kolik teleportů modul provedl (měřená nula = nikdo ho nepoužil).
	return _teleportu


func hlaseni_chybi() -> bool:
	return not hlaseni.is_valid()


func radky() -> Array:
	# ŘÁDKY PRO OKNO (`ui/debug_travel.nastav`). Skládá je `app/`, ne UI.
	var out: Array = []
	for b in _body:
		out.append({
			"cislo": int(b["cislo"]),
			"nazev": str(b["nazev"]),
			"misto": "%d,%d,%d" % [int(b["x"]), int(b["y"]), int(b["z"])],
			"proc": str(b["proc"]),
			"poznamka": str(b["poznamka"]),
		})
	return out


func setup(hrac, controller, panel = null) -> void:
	# Injektované závislosti: hráč, klient (kamera) a okno. Modul si je sám
	# nehledá - jinak by existovala druhá cesta k téže věci.
	_hrac = hrac
	_controller = controller
	_panel = panel
	if _panel != null:
		_panel.nastav(_titulek, radky(),
			_prazdno if _prazdno != "" else "(zadny testovaci bod)")


func je_otevreny() -> bool:
	return _panel != null and bool(_panel.je_otevreny())


func prepni() -> bool:
	# Otevře/zavře seznam. Bez okna vrací false (a je to vidět, ne ticho).
	if _panel == null:
		return false
	return bool(_panel.toggle())


func zavri() -> bool:
	# Zavře seznam; vrátí true, když bylo co zavírat (volá `app/main` na Esc).
	if _panel == null or not bool(_panel.je_otevreny()):
		return false
	return bool(_panel.zavri())


# -- teleport --------------------------------------------------------------

func teleport(index: int) -> Dictionary:
	# SKOK NA BOD (index je 0-based; číslice 1-9 = index 0-8).
	# Vrací `{ok, reason, tile, z, kamera, bod, nazev}` - volající to hlásí.
	# Tělo teleportu je v `app/player_controller.teleport_na` (jediné místo,
	# které zná kameru i běžící krok); tady se jen vybírá bod a hlásí se to.
	if _controller == null:
		return {"ok": false, "reason": "no_controller"}
	if index < 0 or index >= _body.size():
		return {"ok": false, "reason": "no_point"}
	var bod: Dictionary = _body[index]
	var vysledek: Dictionary = _controller.teleport_na(
		Vector2i(int(bod["x"]), int(bod["y"])), int(bod["z"]))
	vysledek["bod"] = str(bod["id"])
	vysledek["nazev"] = str(bod["nazev"])
	vysledek["index"] = index
	if bool(vysledek.get("ok", false)):
		_teleportu += 1
		_hlas(bod)
	return vysledek


func teleport_cislem(cislo: int) -> Dictionary:
	# Číslice 1-9 -> index 0-8. Mimo rozsah = `no_point` (ne tichý návrat).
	return teleport(cislo - 1)


func _hlas(bod: Dictionary) -> void:
	# ZPRÁVA DO ŽURNÁLU (smlouva zadání): přesně "Teleport: <název> (debug)".
	# Text se skládá na JEDNOM místě - test i brána ho čtou odsud (kdyby si ho
	# skládal každý volající, vznikly by dvě pravdy o tom, co hráč vidí).
	if not hlaseni.is_valid():
		return
	hlaseni.call(zprava_o_teleportu(str(bod["nazev"])))


static func zprava_o_teleportu(nazev: String) -> String:
	# JEDINÉ místo, kde je tvar hlášení (test a brána ho berou odsud).
	return "Teleport: " + nazev + " (debug)"
