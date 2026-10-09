extends RefCounted
# sim.entity_registry - JEDINE misto, kde se mobil hleda podle serialu
# (granule `sim.entity_registry`, smlouva docs/04 §4.2 a §4.2.1).
#
# PROC: smlouva psala `request_step(m:int, ...)` a `play(serial, ...)`, ale
# nerikala, ODKUD se mobil podle serialu vezme. `sim.movement` si je drzel sam
# (`_mobiles`) a `render.anim` bral `serial` jako CISLO TELA. Registr je jedno
# misto pro obe diry (ZADANI-DALSI-VYVOJ-2 §3 ukol 1).
#
# TVAR (docs/04 §4.2): `register(m)->void`, `get(serial)->Mobile|null`,
# `all()->Array`, `remove(serial)->void`.
#
# ⚠ VADA SMLOUVY (hlasim, neopravuji - docs/ needituje agent): smlouva i roadmapa
# zadaji `get(serial)`. To v GDScriptu NELZE - `get()` je metoda `Object`
# (`get(StringName)`) a prekryti ji jinou signaturou je PARSE ERROR:
#     "The function signature doesn't match the parent. Parent signature is
#      get(StringName) -> Variant"  (namEReno 2026-10-06)
# A je to nejhorsi druh vady: `tests/run_tests.gd` case soubor s parse errorem
# TISE PRESKOCI, takze sada hlasi "0 selhani" a jen ubyde kontrol (otevrena vec
# 21). Metoda se proto jmenuje `get_mobile(serial)` a smlouva se musi zmenit.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `all()` vraci mobily SERAZENE podle serialu - poradi v `Dictionary` je
#     poradi VLOZENI, takze by stavovy hash i replay zavisely na historii a ne
#     na stavu (dva behy se stejnym stavem by daly jiny hash),
#   * `register(null)` a mobil bez KLADNEHO serialu se odmitne s hlasenim:
#     serial 0 je vychozi hodnota `entity.mobile`, takze "mobil na serialu 0"
#     by v `get(0)` vypadal jako platny hrac a `sim.movement` by mu dovolil
#     krok, i kdyz zadny takovy mobil neexistuje,
#   * `size()` je NAVIC proti smlouve - pouziva ho jen test (a nic jineho).
#
# Serial se NEDOSTAVA odtud: vydava ho `core.serial` (`SimWorld.next_serial`),
# aby dva mobily nikdy nemely stejny.

var _mobily: Dictionary = {}     # serial -> mobil


func register(m) -> void:
	if m == null or int(m.serial) <= 0:
		push_warning("sim.entity_registry: mobil bez kladneho serialu se neregistruje (%s)" % str(m))
		return
	_mobily[int(m.serial)] = m


func get_mobile(serial: int):
	# Neznamy serial vraci null (ne pad) - volajici se na to musi ptat.
	# Jmenuje se `get_mobile`, ne `get`: `get` je metoda `Object` (viz hlavicka).
	return _mobily.get(serial)


func all() -> Array:
	# Serazene podle serialu: na poradi vlozeni nesmi zaviset stav (viz hlavicka).
	var serialy: Array = _mobily.keys()
	serialy.sort()
	var out: Array = []
	for s in serialy:
		out.append(_mobily[s])
	return out


func remove(serial: int) -> void:
	_mobily.erase(serial)


func size() -> int:
	return _mobily.size()


# -- stav (od 2026-10-09 JE registr stavovy zdroj; granule `sim.offline`, MK) --
#
# PROC: mobily se do 2026-10-09 neukladaly. Registr je JEDINE misto, kde mobily
# jsou (`get_mobile`/`all`), takze je i jedine misto, ktere z nich umi udelat
# stav. `SimWorld` ho registruje jako zdroj `entities`.
#
# PORADI je dane `all()` (serazene podle serialu), ne poradim vlozeni: na tom
# uz stoji `state_hash()` i replay (viz hlavicka vyse) - a `restore()` ho musi
# dodrzet taky, jinak by dva behy se stejnym stavem daly jiny hash.
#
# `restore()` MOBILY VYTVARI znovu (`preload` tady, ne v `mobile` - registr je
# ten, kdo vi, z ceho je); existujici mobily se zahodi. Kdo ma mobil v ruce
# (napr. hrac v `app/`), si po nacteni musi vzit novy pres `get_mobile`.

const MobileScript = preload("res://sim/entity/mobile.gd")


func state() -> Dictionary:
	var rows: Array = []
	for m in all():
		rows.append(m.state())
	return {"mobiles": rows}


func restore(d: Dictionary) -> void:
	_mobily.clear()
	if d == null:
		return
	var rows = d.get("mobiles", [])
	if not (rows is Array):
		# Stav, ktery neni seznam, je vada vstupu - ne ticha nula. Prazdny
		# registr po neuspesnem restore by vypadal jako "svet bez mobili".
		push_warning("sim.entity_registry.restore: 'mobiles' neni seznam (%s)" % str(rows))
		return
	for row in rows:
		if not (row is Dictionary):
			continue
		var m = MobileScript.new()
		m.restore(row)
		if int(m.serial) > 0:
			_mobily[int(m.serial)] = m
