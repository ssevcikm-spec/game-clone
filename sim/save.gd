class_name SimSave
extends RefCounted
# sim.save - UKLADANI A NACITANI SVETA (granule `sim.save`, milnik MK).
#
# CO TO JE: mechanika persistence, ne druhy svet. Umí jen to, co je potreba,
# aby se stav dal ulozit a vratit:
#   * IO (JSON + gzip),
#   * VERZE schematu a MIGRACE (starsi save se nesmi tise rozbit),
#   * STAVOVE ZDROJE: kdo ma stav, ktery patri do save, zaregistruje se
#     (`SimWorld.register_state_source`) a musi umet `state()`/`restore(d)`.
#     Modul stavy jen posbira, zapise a vrati - co je stav, vi zdroj sam.
#
# CO ZATIM NENI (pojmenovane, ne tichy dluh):
#   * **entity (mobily, predmety) zdrojem nejsou.** `entity.mobile`
#     a `sim.entity_registry` nemaji `state()`/`restore()` - to je dalsi krok,
#     ktery se tyka jejich granul. Save proto nese `sources` (napr.
#     `scheduler`), a NE prazdne `mobiles`/`items` (ty zustavaji v obalce
#     kvuli zpetne kompatibilite a zmizi, az budou mit tvar).
#   * **PRVNI stavovy zdroj je `sim.scheduler`** (fronta budoucnosti sveta).
#     Zahrnuti jeho stavu do `state_hash()` je ZMENA SPECU odsouhlasena
#     uzivatelem 2026-10-09: hash se tim zmeni a `tests/replays/*.json` se
#     pre-pinuji (jeden zapsany prechod, ne ticha oprava).
#
# VERZE: `1` = obalka (docs/04 §4.7), `2` = obalka + `sources`.
# `migrate()` umi 1 -> 2 (doplni prazdne zdroje); novejsi verze se ODMITNE
# (radsi "nevim, co v tom je" nez tichy nesmysl).

const SAVE_VERSION: int = 2


func version() -> int:
	return SAVE_VERSION


# -- IO --------------------------------------------------------------------

func write(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func read(path: String) -> Dictionary:
	# Chyba vraci prazdny slovnik - volajici to musi rozlisit od prazdneho save.
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var payload = JSON.parse_string(text)
	if not (payload is Dictionary):
		return {}
	return payload


# -- verze a migrace -------------------------------------------------------

func migrate(payload: Dictionary, from_version: int) -> Dictionary:
	# Vraci payload ve verzi SAVE_VERSION, nebo PRAZDNY slovnik, kdyz to nejde.
	if from_version == SAVE_VERSION:
		return payload
	if from_version > SAVE_VERSION:
		return {}
	var out: Dictionary = payload.duplicate(true)
	if from_version <= 1:
		# 1 -> 2: pribyly stavove zdroje; stara obalka zadne nemela.
		if not (out.get("sources") is Dictionary):
			out["sources"] = {}
		out["version"] = 2
	return out if int(out.get("version", 0)) == SAVE_VERSION else {}


# -- stavove zdroje --------------------------------------------------------

func collect(sources: Dictionary) -> Dictionary:
	# Poradi klicu slovniku nesmi rozhodovat (docs/02 §2.3) - proto se jmena
	# zdroju seradi a stav se bere v tomto poradi.
	var names: Array = sources.keys()
	names.sort()
	var out: Dictionary = {}
	for name in names:
		var source = sources[name]
		if source != null and source.has_method("state"):
			out[str(name)] = source.state()
	return out


func apply(sources: Dictionary, states: Dictionary) -> int:
	# Vraci pocet zdroju, kterym se stav opravdu vratil (0 = nic se nenačetlo,
	# coz volajici nesmi povazovat za uspech).
	var names: Array = sources.keys()
	names.sort()
	var applied: int = 0
	for name in names:
		var source = sources[name]
		if source == null or not source.has_method("restore"):
			continue
		var state = states.get(str(name))
		if state == null:
			continue
		source.restore(state)
		applied += 1
	return applied
