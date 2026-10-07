extends RefCounted
# Kontejner: obsah predmetu podle serialu kontejneru (granule `entity.container`,
# smlouva docs/04 §4.2).
#
# `c:int` je SERIAL kontejneru (smlouva to tak ma) - tenhle modul je jedine
# misto, kde se obsah drzi. Predmety jsou tu OBJEKTY (potrebujeme z nich `tile`
# a `amount` na vahu i slouceni), `contents()` vraci serialy podle smlouvy.
#
# ⚠ JEDNA INSTANCE = VSECHNY KONTEJNERY SVETA. Invariant "prave jeden rodic"
# jde drzet jen takhle: `add(c, item)` musi umet predmet vyjmout z PREDCHOZIHO
# kontejneru, a o tom vi jen instance, ktera ho spravuje. Kdo si udela instanci
# na kontejner, dostane duplikaty (a `remove` z "jineho" kontejneru nic nenajde).
#
# `item.tile` je ART ID (0x4000-0xFFFF, `docs/03` §3.4: „item id = art id") -
# v tom prostoru bere `world.tiledata` vahu i flagy, takze se nic neposouva.
#
# LIMITY (docs/05 §5.4, hodnoty z `core/const.gd`): 125 predmetu, 400 stones,
# hromada 60000. Reference: ServUO `Server/Items/Container.cs:1672-1673`
# (`m_GlobalMaxItems = 125`, `m_GlobalMaxWeight = 400`) a `CheckHold`
# (`:230-268`): `TotalItems + item + 1 > MaxItems` -> plno, jinak vaha.
#
# INVARIANT "PRAVE JEDEN RODIC": `add` predmet nejdriv vyjme z predchoziho
# kontejneru a teprve pak ho vlozi (ServUO `Server/Item.cs:3971` `AddItem`,
# `:3999-4006`). Kdo ho obejde, vyrobi duplikat - proto se obsah meni JEN pres
# `add`/`remove` a nikdo nema `_obsah` odsud. Kdyz je predchozi rodic MOBIL
# (nasadena vybava), tenhle modul o nem nevi - uklidit ho musi
# `entity.equipment`, az vznikne (dnes `equip` na mobilu).
#
# SLOUCOVANI HROMAD: dva predmety se slouci, kdyz maji stejny `tile` + `hue`
# (docs/05 §5.4) a v tiledata je flag `Generic` = stackable (ClassicUO
# `TileDataLoader.cs:281` `IsStackable => (Flags & TileFlag.Generic) != 0`,
# `TileFlag.Generic = 0x00000800`). NamEReno 2026-10-07 nad `assets/uo/tiles.json`:
# zlato, obvaz, log, ingot a reagencie flag MAJI, dagger/longsword/backpack NE
# (898 z 65536 predmetu).
#
# ⚠ ODCHYLKY OD REFERENCE (vedome, ne prehlednute - viz i HANDOFF):
#   * plna hromada (`MAX_STACK`) se za cil slouceni NEPOVAZUJE. ServUO `WillStack`
#     kapacitu nezkouma (`Server/Item.cs:2100-2107`), takze predmet prida jako
#     novy a muze prekrocit `MaxItems`; tuhle vadu nekopirujeme,
#   * kdyz se predmet cely slouci, ServUO ho maze (`Item.Delete`); objekt, ktery
#     nam predal volajici, zmazat nemuzeme - skonci prazdny a bez rodice
#     (`amount == 0`, `parent == 0`),
#   * vaha se u slouceni nekontroluje: ServUO preskoci `CheckHold`, kdyz muze
#     sloucit (`Container.cs:1790` - `CheckStack` je prvni), delame to stejne,
#   * vnorene kontejnery se do vahy nepocitaji (ServUO `TotalWeight` je
#     rekurzivni pres cely strom) - otevrena vec, vlastni cil pro dalsi session.
#
# ZAVISLOSTI KONSTRUKTOREM: `tiledata` (vahu a stackable flag) predava volajici -
# `sim/entity` NESMI preloadovat `sim/world` (docs/04 §4.1), takze tu zadny
# preload sveta neni. Bez tiledata se vaha NEMERI (`has_weights()` je false a
# `weight_of` vraci 0) - nula se nesmi tvarit jako namERena.

const Const = preload("res://core/const.gd")

const F_STACKABLE := 0x00000800   # TileFlag.Generic (ClassicUO TileDataLoader.cs:457)

var _obsah: Dictionary = {}       # serial kontejneru -> Array objektu predmetu
var _tiledata = null
var _max_items: int = Const.CONTAINER_MAX_ITEMS
var _max_weight: int = Const.CONTAINER_MAX_WEIGHT


func _init(tiledata = null, max_items: int = Const.CONTAINER_MAX_ITEMS,
		max_weight: int = Const.CONTAINER_MAX_WEIGHT) -> void:
	if tiledata == null:
		push_warning("sim.entity.container: bez tiledata se vaha nemeri "
			+ "(weight_of vraci 0 a hromady se neslucuji)")
	_tiledata = tiledata
	_max_items = max_items
	_max_weight = max_weight


func has_weights() -> bool:
	# Bez tiledata se vaha nemeri - volajici to musi poznat (nula neni uspech).
	return _tiledata != null


func can_add(c: int, item) -> Dictionary:
	# JEDINE misto, kde se rozhoduje - `add` se ptá tudy; pravidla na dvou
	# mistech by se rozejla. Duvody: no_container, no_item, no_serial, amount,
	# stack, already_here, full, weight.
	if c <= 0:
		return {"ok": false, "reason": "no_container"}
	if item == null or not (item is Object) or not item.has_method("same_pile"):
		return {"ok": false, "reason": "no_item"}
	if int(item.serial) <= 0:
		return {"ok": false, "reason": "no_serial"}
	if int(item.amount) <= 0:
		return {"ok": false, "reason": "amount"}
	if int(item.amount) > Const.MAX_STACK:
		return {"ok": false, "reason": "stack"}
	if _najdi(c, int(item.serial)) != null:
		return {"ok": false, "reason": "already_here"}
	if _cil_slouceni(c, item) != null:
		# Slouceni nove misto nezabira (a ServUO u nej limit nekontroluje).
		return {"ok": true, "reason": ""}
	if _obsah.get(c, []).size() >= _max_items:
		return {"ok": false, "reason": "full"}
	if has_weights() and weight_of(c) + _vaha(item) > _max_weight:
		return {"ok": false, "reason": "weight"}
	return {"ok": true, "reason": ""}


func add(c: int, item) -> bool:
	# Vraci `bool` (smlouva §4.2); duvod, kdyz to nejde, je v `can_add`.
	if not can_add(c, item).get("ok", false):
		return false
	# INVARIANT "PRAVE JEDEN RODIC": nejdriv z predchoziho kontejneru.
	if int(item.parent) != 0 and int(item.parent) != c:
		_vyjmi(int(item.parent), item)
	var cil = _cil_slouceni(c, item)
	if cil != null:
		var prevedeno: int = mini(int(item.amount), Const.MAX_STACK - int(cil.amount))
		cil.amount = int(cil.amount) + prevedeno
		item.amount = int(item.amount) - prevedeno
	if int(item.amount) <= 0:
		# Cely predmet se vesel do existujici hromady - objekt je spotrebovany.
		item.parent = 0
		return true
	if not _obsah.has(c):
		_obsah[c] = []
	_obsah[c].append(item)
	item.parent = c
	return true


func remove(c: int, item: int, amount: int) -> int:
	# Vraci, KOLIK se opravdu odstranilo (0 = predmet v tom kontejneru neni).
	# `amount <= 0` = cely predmet. Predmetu v JINEM kontejneru se nedotkne.
	var predmet = _najdi(c, item)
	if predmet == null:
		return 0
	var brat: int = int(predmet.amount) if amount <= 0 else mini(amount, int(predmet.amount))
	predmet.amount = int(predmet.amount) - brat
	if int(predmet.amount) <= 0:
		_obsah[c].erase(predmet)
		predmet.parent = 0
	return brat


func weight_of(c: int) -> int:
	# Vaha PRIMEHO obsahu v stones (docs/05 §5.4); bez tiledata se nemeri.
	var soucet: int = 0
	for predmet in _obsah.get(c, []):
		soucet += _vaha(predmet)
	return soucet


func contents(c: int) -> Array[int]:
	# Serazene podle serialu: na poradi vlozeni nesmi zaviset stav (stejny
	# duvod jako `sim.entity_registry.all()`).
	var serialy: Array[int] = []
	for predmet in _obsah.get(c, []):
		serialy.append(int(predmet.serial))
	serialy.sort()
	return serialy


func _vaha(predmet) -> int:
	if _tiledata == null:
		return 0
	return int(_tiledata.weight(int(predmet.tile))) * int(predmet.amount)


func _stackable(tile: int) -> bool:
	return _tiledata != null and (int(_tiledata.flags(tile)) & F_STACKABLE) != 0


func _cil_slouceni(c: int, item):
	# Hromada, do ktere se `item` slouci (stejny tile + hue + stackable flag).
	# Plna hromada se za cil nepovazuje (viz hlavicka).
	if not _stackable(int(item.tile)):
		return null
	for predmet in _obsah.get(c, []):
		if predmet.same_pile(item) and int(predmet.amount) < Const.MAX_STACK:
			return predmet
	return null


func _najdi(c: int, serial: int):
	for predmet in _obsah.get(c, []):
		if int(predmet.serial) == serial:
			return predmet
	return null


func _vyjmi(c: int, predmet) -> void:
	if not _obsah.has(c):
		return
	_obsah[c].erase(predmet)
	if int(predmet.parent) == c:
		predmet.parent = 0
