extends Node
# app.sound - `audio.playback` (granule z `docs/07`, smlouva `docs/04 §4.2`):
# prehravani zvuku z udalosti simulace.
#
# HRANICE (docs/02 §2.2, docs/01 §1.5 bod 9): zvuk NIKDY nemeni stav simulace.
# Modul jen CTE udalosti a pousti streamy - nema referenci na `sim` jako na stav
# a nic do nej nezapisuje. Kdyby sahal do simulace, byl by to druhy zdroj pravdy.
#
# ODKUD UDALOSTI: `app/loop._deliver_events()` je jedine misto, kde klient
# odebira `sim.snapshot()["events"]`. Modul se tam jen pripoji (`apply_event`),
# takze se nikde nezavadi druha cesta k udalostem.
#
# KTERE UDALOSTI (namEReno 2026-10-12 v `sim/`):
#   * `sound {serial, kind}` - `sim.combat` posila `kind` "hit" a "death"
#     (`combat.gd:392`, `:409`); "mine"/"smith" jsou pripravene pro tezbu
#     a vyrobu (sim je zatim neposila - viz HANDOFF, "co zbyva").
#   * `stats_changed {serial, hp, ...}` - z POKLESU hp hrace se odvozuje zvuk
#     "hurt" ("dostali jsme zasah"). Udalost `sound` totiz nese jen utocnika,
#     ne cil, takze z ni "my" poznat nelze.
#   * ⚠ TVAR UDALOSTI (2026-10-12): `docs/04 §4.4` melo `{id, x, y, z}`, kod
#     posilal `{serial, kind}`. Sjednoceno na `{serial, kind, x, y, z}`:
#     `serial` je identita (kdo to zpusobil), `kind` je druh zvuku a **pozice
#     je v udalosti** - u smrti je mobil v dobe doruceni uz z registru
#     odstraneny, takze by si ji klient nedohledal (namEReno: zvuk smrti se
#     kvuli tomu nehral). Modul umi i stary tvar `{id, x, y, z}`.
#
# FORMAT ZVUKU: `assets/sounds/manifest.json` (generator `tools/audio/gen-sfx.py`,
# 44,1 kHz stereo). Soubory jsou v repu BEZ `.import` (jako vlastni art), takze
# se nacitaji `AudioStreamWAV.load_from_file` - `load("res://…wav")` by v projektu
# bez importu vratilo null.

const MANIFEST := "res://assets/sounds/manifest.json"
const SADA := "res://assets/sounds/"
const POOL := 6                 # kolik zvuku muze znit soucasne
const RANGE_TILES := 14.0       # za timhle dosahem se zvuk nehraje
const TICHE := 0.12             # pod timhle podilem hlasitosti je zvuk ticho

var _streamy: Dictionary = {}    # id -> AudioStreamWAV
var _prehravace: Array = []      # AudioStreamPlayer (pool)
var _chyby: Array = []           # kazda vada se hlasi, ne tise zmizi
var _prehrano: int = 0
var _ticho: int = 0              # preskoceno (moc daleko / nezname id)
var _podle_id: Dictionary = {}   # id -> kolikrat se prehral (doklad, KTERY zvuk)
var _hp: Dictionary = {}         # serial -> posledni zname hp (jen pro "hurt")
var _hrac: int = 0
var _registr = null
var _pripraveno: bool = false


func _ready() -> void:
	priprav()


func priprav() -> bool:
	# Nacte manifest a streamy a zalozí pool prehravacu. Vraci false, kdyz se
	# nepodarilo nic nacist - volajici to MUSI videt (`errors()`), protoze ticho
	# vypada stejne jako "hra je ticha".
	if _pripraveno:
		return not _streamy.is_empty()
	_pripraveno = true
	var surova = _json(MANIFEST)
	if surova == null:
		_chyby.append("manifest '%s' chybi nebo neni citelny JSON" % MANIFEST)
		return false
	for z in (surova as Dictionary).get("sounds", []):
		if not (z is Dictionary):
			continue
		var ident := str(z.get("id", ""))
		var soubor := str(z.get("file", ""))
		if ident == "" or soubor == "":
			_chyby.append("zaznam v manifestu bez 'id' nebo 'file'")
			continue
		var stream = AudioStreamWAV.load_from_file(SADA + soubor)
		if stream == null:
			_chyby.append("zvuk '%s': soubor %s%s nelze nacist" % [ident, SADA, soubor])
			continue
		_streamy[ident] = stream
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_prehravace.append(p)
	return not _streamy.is_empty()


func nastav_hrace(serial: int) -> void:
	_hrac = serial


func nastav_registr(registry) -> void:
	_registr = registry


# -- prehravani -------------------------------------------------------------

func play(id: String, volume: float = 1.0) -> bool:
	# Prehraje zvuk `id` (jmeno z manifestu). Vraci false, kdyz zvuk neexistuje,
	# kdyz hlasitost vysla pod prahem, nebo kdyz modul NENI ve strome (Godot pak
	# hlasi "Playback can only happen when a node is inside the scene tree") -
	# a POCITA to (`stats()`), aby se "nehrálo" nedalo splest s "nefunguje".
	if not _streamy.has(id):
		_ticho += 1
		if not _chyby.has("neznamy zvuk '%s'" % id):
			_chyby.append("neznamy zvuk '%s'" % id)
		return false
	var hlas: float = clampf(volume, 0.0, 1.0)
	if hlas < TICHE:
		_ticho += 1
		return false
	if not is_inside_tree():
		# Testy a sondy bez stromu: zvuk se NEPREHRAJE a nesmi se tvarit, ze ano.
		_ticho += 1
		if not _chyby.has("modul neni ve strome - zvuk nelze prehrat"):
			_chyby.append("modul neni ve strome - zvuk nelze prehrat")
		return false
	var p = _volny()
	if p == null:
		_ticho += 1
		return false
	p.stream = _streamy[id]
	p.volume_db = linear_to_db(hlas)
	p.play()
	_prehrano += 1
	_podle_id[id] = int(_podle_id.get(id, 0)) + 1
	return true


func play_at(id: String, pos: Vector3i, listener: Vector3i) -> bool:
	# Vzdalenost (Chebyshev ve dlazdicich) tlumi hlasitost; za dosahem je ticho.
	var d: int = maxi(absi(int(pos.x) - int(listener.x)), absi(int(pos.y) - int(listener.y)))
	return play(id, _hlasitost(d))


func rozhodni(event: Dictionary, listener = null) -> Dictionary:
	# CELE ROZHODNUTI modulu: ktera udalost na ktery zvuk a jak hlasite.
	# Vraci `{id, volume, vzdalenost}` nebo prazdny slovnik (zadny zvuk).
	# Je to samostatna funkce schvalne: test ji muze merit BEZ stromu a bez
	# zvukove karty (docs/09 §9.4), zatimco `play()` potrebuje bezici scenu.
	var jmeno := str(event.get("name", ""))
	var data: Dictionary = event.get("data", {}) if event.get("data") is Dictionary else {}
	if jmeno == "sound":
		return _rozhodni_zvuk(data, listener)
	if jmeno == "stats_changed":
		return _rozhodni_staty(data)
	return {}


func apply_event(event: Dictionary, listener = null) -> bool:
	# Reakce na JEDNU udalost z `sim.snapshot()["events"]`. Neznama udalost se
	# ignoruje (neni to vada), ale znamy zvuk s chybejicim souborem se hlasi.
	var d: Dictionary = rozhodni(event, listener)
	if d.is_empty():
		return false
	return play(str(d["id"]), float(d["volume"]))


func _rozhodni_zvuk(data: Dictionary, listener) -> Dictionary:
	# Dva tvary: `{serial, kind}` (co posila `sim.combat` dnes) a `{id, x, y, z}`
	# (co ma smlouva `docs/04 §4.4`). Kdo posle oba, dostane jeden zvuk.
	var kind := str(data.get("kind", data.get("id", "")))
	if kind == "":
		return {}
	var kam: Vector3i = _pozice(int(data.get("serial", 0)))
	if data.has("x") and data.has("y"):
		kam = Vector3i(int(data.get("x", 0)), int(data.get("y", 0)), int(data.get("z", 0)))
	var kde: Vector3i = _posluchac() if listener == null else listener
	# Uder, ktery uvidime my, hrajeme "naplno" (bez utlumu) - je to nas swing.
	if int(data.get("serial", 0)) == _hrac and _hrac > 0:
		return {"id": kind, "volume": 1.0, "vzdalenost": 0}
	var d: int = maxi(absi(kam.x - kde.x), absi(kam.y - kde.y))
	return {"id": kind, "volume": _hlasitost(d), "vzdalenost": d}


func _rozhodni_staty(data: Dictionary) -> Dictionary:
	# "hurt" (dostali jsme zasah) se pozna POKLESEM hp hrace - udalost `sound`
	# nese jen utocnika, takze z ni "my" zjistit nelze. Hraje se NAPLNO (utlum
	# podle vzdalenosti by u vlastniho zraneni nemel smysl).
	var serial := int(data.get("serial", 0))
	var hp := int(data.get("hp", 0))
	var pred: int = int(_hp.get(serial, hp))
	_hp[serial] = hp
	if serial == 0 or serial != _hrac or hp >= pred:
		return {}
	return {"id": "hurt", "volume": 1.0, "vzdalenost": 0}


func _hlasitost(d: int) -> float:
	# Chebyshev ve dlazdicich: do 1 dlazdice naplno, pak linearni utlum.
	if d <= 1:
		return 1.0
	return clampf(1.0 - float(d) / RANGE_TILES, 0.0, 1.0)


func _pozice(serial: int) -> Vector3i:
	if _registr == null or serial <= 0:
		return Vector3i.ZERO
	var mob = _registr.get_mobile(serial)
	return Vector3i.ZERO if mob == null else mob.pos


func _posluchac() -> Vector3i:
	return _pozice(_hrac)


func _volny():
	for p in _prehravace:
		if not p.playing:
			return p
	return null


# -- mereni (pro branu a sondu) ---------------------------------------------

func available() -> bool:
	return not _streamy.is_empty()


func sounds() -> Array:
	return _streamy.keys()


func errors() -> Array:
	return _chyby.duplicate()


func stats() -> Dictionary:
	return {
		"streamu": _streamy.size(),
		"prehravacu": _prehravace.size(),
		"prehrano": _prehrano,
		"podle_id": _podle_id.duplicate(),
		"ticho": _ticho,
		"chyb": _chyby.size(),
	}


func _json(cesta: String):
	if not FileAccess.file_exists(cesta):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(cesta))
