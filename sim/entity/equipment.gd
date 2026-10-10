extends RefCounted
# Vyba a vrstvy (granule `entity.equipment`, smlouva docs/04 §4.2, vrstvy
# docs/11 §11.7 a research/01 §2.6).
#
# TVAR (smlouva): `equip(m, item)->Dictionary`, `unequip(m, layer)->int`,
# `at_layer(m, layer)->int`, `total_weight(m)->int`, `bonus(m, key)->int`.
#
# PRAVIDLA VRSTEV (kazde ma radek v reference):
#   * vrstvy 0x01..0x18 jsou uzivatelsky pouzitelne (`Layer.FirstValid` = 0x01,
#     `Layer.LastUserValid` = 0x18; `_src/servuo/Server/Item.cs:35,160`),
#   * dve veci NESMI byt na stejne vrstve: `Item.CanEquip` pozaduje
#     `FindItemOnLayer(m_Layer) == null` (`_src/servuo/Server/Item.cs:1631`),
#   * dvourucni zbran a stit SDILEJI vrstvu 2 (`Layer.TwoHanded`, research/01
#     §2.6) - STIT pri nasazene DVOURUCNE ZBRANI vraci `{ok:false}`
#     (roadmapa `entity.equipment`: "equip stitu pri dvourucne zbrani vraci
#     {ok:false}"); duvod je `two_handed`,
#   * jednorucni zbran (vrstva 1) + nova dvourucni zbran (mimo stit a svetlo)
#     je konflikt "You can only wield one weapon at a time"
#     (`Scripts/Items/Equipment/Weapons/BaseWeapon.cs:998-1016`).
#
# ODKUD SE BERE VRSTVA: z predmetu (`item.layer`, nastavi ji volajici, napr.
# vyroba), nebo z `tiledata.layer(tile)`. `tiledata` je ZAVISLOST
# KONSTRUKTOREM (`_init`), protoze `sim/entity` nesmi preloadovat `sim/world`
# (docs/04 §4.1). Kdyz neni ani jedno, vraci `equip`
# `{ok:false, reason:"no_layer"}` - ticha nula by vypadala jako uspesne nasazeni.
#
# INVARIANT "PRAVE JEDEN RODIC" (jako `entity.container`): `equip` predmet
# nejdriv vyjme z predchoziho rodice (`_odpoj`), `unequip` ho vlozi do batohu
# (`mob.backpack`). Bez `container` (nebo bez batohu) zustane predmet bez
# rodice (`parent == 0`) a umisteni je na volajicim - to je VIDET, ne tiche.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `_init(registry, container, items, tiledata)` - zavislosti konstruktorem;
#     `items` je `serial -> Item` (stejne jako `sim.craft`),
#   * `measured()`, `unknown_equipped(m)` - VIDITELNY stav chybejici zavislosti:
#     bez `tiledata`/`items` vraci `total_weight`/`bonus` nulu a volajici to
#     musi poznat (nula, ktera neni merena, nesmi vypadat jako merena),
#   * `reason` ve vracenem slovniku (jako u `sim.movement` a `sim.harvest`),
#   * opakovane nasazeni TEHOZ predmetu vraci `{ok:true, reason:"already_equipped"}`
#     - ROZHODNUTI KLONU: reference tuhle cestu neresi a dvojklik v UI nema
#     hlasit chybu,
#   * vaha je soucet NASAZENYCH predmetu (`tiledata.weight(tile) * amount`);
#     vlastni vaha postavy a batoh patri `entity.container`/`entity.mobile`,
#   * `bonus(m, key)` secte `props[key]` nasazenych predmetu (AoS vlastnosti,
#     docs/05 §5.16); neznamy klic = 0 (zadna vymyslena hodnota),
#   * `_je_stit`/`_je_zbran` se opiraji o `category` z `data/items.json`
#     (`entity.item.category_of`), zaloha je pripona `type`. Kdyz data chybi
#     (kategorie prazdna), krizova kontrola dvourucni zbrane se NEMERI.
#
# ⚠ NALEZ PRO JINOU GRANULI (hlasim, neopravuji - `entity.container` neni moje):
# `entity.container.remove()` predmet SPOTREBUJE (pri odebrani cele hromady
# nastavi `amount = 0`). Na "vyjmi predmet z kontejneru a nech ho" API nema,
# takze `_odpoj` si mnozstvi po vyjmuti obnovi (viz komentar u `_odpoj`).
# Poradne `take_out` patri do `entity.container` a pouzije ho i drag & drop.

const RegistryScript = preload("res://sim/entity/registry.gd")
const ItemScript = preload("res://sim/entity/item.gd")

const LAYER_FIRST := 0x01          # `Layer.FirstValid` (`Item.cs:35`)
const LAYER_ONE_HANDED := 0x01
const LAYER_TWO_HANDED := 0x02
const LAYER_LAST_USER := 0x18      # `Layer.LastUserValid` (`Item.cs:160`)

var _registry = null
var _container = null
var _items = null
var _tiledata = null


func _init(registry = null, container = null, items = null, tiledata = null) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_container = container
	_items = items
	_tiledata = tiledata


func measured() -> bool:
	# Bez tiledata (vaha) nebo bez items (hledani predmetu podle serialu) se
	# `total_weight`/`bonus` NEMERI - vraceji 0 a volajici to vi odsud.
	return _tiledata != null and _items != null


func equip(m: int, item) -> Dictionary:
	var mob = _registry.get_mobile(m)
	if mob == null:
		return _fail("no_mobile")
	if item == null or not (item is Object) or not item.has_method("same_pile"):
		return _fail("no_item")
	if int(item.serial) <= 0:
		return _fail("no_serial")
	if int(item.amount) <= 0:
		return _fail("amount")           # spotrebovana hromada (amount 0) se neda nasadit
	var layer := _layer_of(item)
	if layer <= 0:
		return _fail("no_layer")
	if layer < LAYER_FIRST or layer > LAYER_LAST_USER:
		return _fail("invalid_layer")
	var zaklad: Dictionary = mob.equip
	var obsazeno := int(zaklad.get(layer, 0))
	if obsazeno == int(item.serial):
		# Opakovane nasazeni tehoz predmetu stav NEMENI (rozhodnuti klonu).
		return {"ok": true, "reason": "already_equipped", "layer": layer}
	if obsazeno != 0:
		if layer == LAYER_TWO_HANDED and _je_stit(item):
			# "You already have something in both hands" (`BaseWeapon.cs:1007`).
			return _fail("two_handed")
		return _fail("occupied")            # `Item.cs:1631`
	if _konflikt_dvourucni(mob, item, layer):
		return _fail("two_handed")
	_odpoj(mob, item)
	item.layer = layer
	item.parent = m
	zaklad[layer] = int(item.serial)
	return {"ok": true, "reason": "", "layer": layer}


func unequip(m: int, layer: int) -> int:
	# Vraci serial slozeneho predmetu (0 = na vrstve nic nebylo).
	var mob = _registry.get_mobile(m)
	if mob == null:
		return 0
	var serial := int(mob.equip.get(layer, 0))
	if serial == 0:
		return 0
	mob.equip.erase(layer)
	var item = _item(serial)
	if item != null:
		item.layer = 0
		var vlozeno: bool = false
		if _container != null and int(mob.backpack) > 0:
			vlozeno = _container.add(int(mob.backpack), item)
		if not vlozeno:
			item.parent = 0       # bez kontejneru/ batohu zustava bez rodice
	return serial


func at_layer(m: int, layer: int) -> int:
	var mob = _registry.get_mobile(m)
	return 0 if mob == null else int(mob.equip.get(layer, 0))


func total_weight(m: int) -> int:
	var mob = _registry.get_mobile(m)
	if mob == null or not measured():
		return 0
	var soucet := 0
	for serial in _serials(mob):
		var item = _item(serial)
		if item != null:
			soucet += int(_tiledata.weight(int(item.tile))) * int(item.amount)
	return soucet


func bonus(m: int, key: String) -> int:
	if key == "":
		return 0
	var mob = _registry.get_mobile(m)
	if mob == null or _items == null:
		return 0
	var soucet := 0
	for serial in _serials(mob):
		var item = _item(serial)
		if item != null and item.props is Dictionary:
			soucet += int(item.props.get(key, 0))
	return soucet


func unknown_equipped(m: int) -> int:
	# Nasazene serialy, ktere v `items` nejsou - jejich vaha i bonusy chybi,
	# takze "0" z `total_weight` neni namERena nula.
	var mob = _registry.get_mobile(m)
	if mob == null or _items == null:
		return 0
	var chybi := 0
	for serial in _serials(mob):
		if _item(serial) == null:
			chybi += 1
	return chybi


# -- vnitrni ---------------------------------------------------------------

func _serials(mob) -> Array:
	var out: Array = []
	for serial in mob.equip.values():
		out.append(int(serial))
	out.sort()                    # na poradi vlozeni nesmi zaviset vysledek
	return out


func _item(serial: int):
	return _items.get(serial) if _items is Dictionary else null


func _layer_of(item) -> int:
	var vrstva := int(item.layer)
	if vrstva > 0:
		return vrstva                # vrstvu zna predmet (nastavil ji volajici)
	if _tiledata != null:
		return int(_tiledata.layer(int(item.tile)))
	return 0


func _konflikt_dvourucni(mob, item, layer: int) -> bool:
	if layer == LAYER_ONE_HANDED and _je_dvourucni(_item(int(mob.equip.get(LAYER_TWO_HANDED, 0)))):
		return true
	if layer == LAYER_TWO_HANDED and _je_zbran(item) and int(mob.equip.get(LAYER_ONE_HANDED, 0)) != 0:
		return true
	return false


func _kategorie(item) -> String:
	return "" if item == null else ItemScript.category_of(int(item.tile))


func _je_stit(item) -> bool:
	# `category` z `data/items.json` (200 zaznamu); zaloha na priponu typu pro
	# pripad, ze data nejsou (pak je kategorie prazdna).
	if item == null:
		return false
	if _kategorie(item) == "shield":
		return true
	return str(item.type).ends_with("shield")


func _je_zbran(item) -> bool:
	return item != null and _kategorie(item) == "weapon"


func _je_dvourucni(item) -> bool:
	return item != null and _layer_of(item) == LAYER_TWO_HANDED and _je_zbran(item)


func _odpoj(mob, item) -> void:
	# Predchozi rodic: mobil (vrstva se musi z jeho `equip` smazat) nebo
	# kontejner (vyjmout pres `entity.container`); jinak jen `parent = 0`.
	var p := int(item.parent)
	if p == 0 or p == int(mob.serial):
		return
	var byvaly = _registry.get_mobile(p)
	if byvaly != null:
		if int(byvaly.equip.get(int(item.layer), 0)) == int(item.serial):
			byvaly.equip.erase(int(item.layer))
	elif _container != null:
		# ⚠ NAlez (patri `entity.container`): `remove(c, item, amount)` predmet
		# SPOTREBUJE - pri odebrani cele hromady nastavi `amount = 0` a vyhodi
		# ho z obsahu (`container.gd`, `remove`). "Vyjmout a nechat predmet"
		# zadne API nema, proto se mnozstvi po vyjmuti OBNOVI. Kdo prida do
		# `entity.container` poradne `take_out`, at tuhle vetev nahradi.
		var pocet: int = int(item.amount)
		if _container.remove(p, int(item.serial), pocet) > 0:
			item.amount = pocet
	else:
		item.parent = 0


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "layer": 0}
