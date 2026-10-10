extends RefCounted
# Obchod: co vendor prodava a kupuje, ceny a restock (granule `sim.vendor`;
# smlouva docs/04 §4.2, tok §4.6.5, pravidla docs/05 §5.9).
#
# ODKUD CISLA (zadne vymyslene):
#   * CENY JSOU DATA v `data/vendors.json` (generuje `gen-content.py` z
#     `research/06` §2.4.1 = ServUO `Scripts/VendorInfo/*.cs`):
#     `buys[].price` = kolik vendor zaplati hracovi (ServUO `GetSellPriceFor`),
#   * `buy_price = ceil(buy_percent/100 * sell_price)` plati VZDY - koeficient
#     je v datech (`config.buy_percent`, 190 = 1,90x; `GenericSell.cs:126-129`),
#   * `sell_price` je z TABULKY toho vendora, ve dvou krocich: (1) `buys[].price`
#     (ServUO `GetSellPriceFor` - presne to je "cena shopu"), (2) kdyz predmet
#     vendor jen PRODAVA (`stock[].price`), odvodi se z autorske retail ceny tak,
#     aby `buy == retail` vyslo presne. `stock[].price` je zaroven STROP
#     fallbacku proti arbitrazi (viz `_postav_ceny`),
#   * restock 60 min je LINIVY (az pri pristupu) a strop gumpu je 250 radku:
#     `config.restock_ms` / `config.gump_max_rows` (research/06 §2.3,
#     `BaseVendor.cs:920-923`, `:941`),
#   * zlato je PREDMET v batohu (`config.gold_art`) a pocita se podle TYPU
#     (`gold_coin`), protoze zlato ma vic artu podle velikosti hromady,
#   * DOSAH: `buy`/`sell` chtejí hrace do 2 dlazdic od vendora a pozici vendora
#     ZNAMOU (`nastav_pozici`) - jinak `too_far` / `no_vendor_pos` (VIDET).
#     `stock`/`sellable`/`gump_data` jsou dotazy na data a dosah neresi:
#     gump se otevira jednou, transakce je to, co se hlida (`docs/04` §4.6.5),
#   * fallback pro predmet, ktery v tabulce toho vendora NENI:
#     `value(item) * value_percent / 100` (value z `world.tiledata`, procento
#     z dat). NIKDY vsak vic, nez za kolik si ho hrac muze nejlevneji KOUPIT -
#     jinak vznikne arbitraz (NAMERENO: pickaxe retail 22 vs value 58 u Krejciho).
#     Bez tiledata fallback vraci 0 - "nevim" neni cena.
#
# CO SE NEMODELUJE (pojmenovane, ne prehlednute):
#   * `Vendors.MaxSell = 500` (research/06 §2.3) - vyznam v reference neovereny,
#   * ekonomika AoS (`UseVendorEconomy`), smlouvání a slevy za mnozstvi
#     (research/06 §5.2 "Quantity discounts: None" - cena je proto linearni
#     a `amount` v `*_price` cenu nemeni),
#   * prodane predmety se do skladu vendora NEPRIDAVAJI (reference je dava do
#     `BuyPack`, ktery se v buy listu neobjevuje),
#   * ARBITRAZ MEZI DVEMA VENDORY z tabulek (NAMERENO 16 dvojic: napr.
#     `thigh_boots` koupit u Cobblera za 14 a prodat Leatherworkerovi za 28).
#     Je to vlastnost AUTORSKYCH tabulek ServUO (kazdy shop ma cenu svou), ne
#     nasich pravidel; strop nize chrani JEN cestu pres `value` fallback.
#   * `id` vendora je INDEX do `vendors` v datech (`vendor_index(id)` pro jmeno).
#
# ZAVISLOSTI KONSTRUKTOREM (vzor `sim.craft`): `container` (JEDINA instance
# sveta), `items` (`{serial: Item}`), `tiledata` (value pro fallback), `registry`
# (odkud je mobil), `serials` (`next_serial()` - v produkci `SimWorld`), `clock`
# (restock), `events` (hlasky), `path` (cesta k datum = VSTUP, kvuli mutacnimu
# testu). Nahoda tu zadna neni (ceny ani restock nehazi), proto RNG nebere.

const ItemScript = preload("res://sim/entity/item.gd")
const ClockScript = preload("res://core/clock.gd")

const VENDORS_PATH := "res://data/vendors.json"
const ITEM_OFFSET := 0x4000            # data maji TILEDATA ID, `Item.tile` je ART ID
const GOLD_TYPE := "gold_coin"
const MIN_BUY_PERCENT := 100           # buy nikdy neni pod cenou (pojistka proti datum)
const DEFAULT_RESTOCK_MS := 3600000    # 60 min (research/06 §2.3)
const DEFAULT_GUMP_ROWS := 250
# Dosah na vendora. CISLO JE ROZHODNUTI, ne mereni: reference
# (`BaseVendor.CheckVendorAccess`) vzdalenost NERESI - hlida ji klient - a my
# klienta nemame, takze pravidlo musi byt v sim. Vzato stejne jako dosah na
# predmet/kovadlinu (2 dlazdice, docs/05 §5.9 "dosah 2 dlazdice").
const VENDOR_RANGE := 2

var _container = null
var _items = null
var _tiledata = null
var _registry = null
var _serials = null
var _clock = null
var _events = null

var _records: Array = []               # zaznamy z `data/vendors.json`
var _config: Dictionary = {}
var _stock: Dictionary = {}            # id vendora -> {type: aktualni mnozstvi}
var _restock: Dictionary = {}          # id vendora -> ms posledniho doplneni
var _nejlevnejsi: Dictionary = {}      # type -> nejnizsi cena, za kterou ho nekdo prodava
var _pozice: Dictionary = {}           # id vendora -> Vector3i (kde ve svete stoji)
var _serial_vendor: Dictionary = {}     # serial mobily -> index vendora (viz `zaregistruj_serial`)


func _init(container = null, items = null, tiledata = null, registry = null,
		serials = null, clock = null, events = null, path: String = VENDORS_PATH) -> void:
	_container = container
	_items = items
	_tiledata = tiledata
	_registry = registry
	_serials = serials
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_load(path)


# -- rozhrani podle smlouvy ------------------------------------------------

func stock(v: int) -> Array[Dictionary]:
	# Radky pro gump "co si hrac muze koupit": `item` = ART ID (to posila
	# klient zpet v `lines`), `amount` = co je skladem, `price` = za kus.
	# Prazdny sklad nebo neznamy vendor vraci prazdno (neni to uspech, ale
	# gump pro to ma vlastni hlasku - `ui.vendor_gump`).
	_restock_if_due(v)
	var out: Array[Dictionary] = []
	var rec := _record(v)
	if rec.is_empty():
		return out
	for e in rec.get("stock", []):
		if out.size() >= _gump_rows():
			break                        # strop 250 radku (research/06 §2.3)
		var typ: String = str(e.get("type", ""))
		var mam: int = _stock_of(v, typ)
		if mam <= 0:
			continue                     # reference preskoci `Amount <= 0`
		var art: int = _art(e)
		out.append({"item": art, "type": typ, "name": str(e.get("name", "")),
			"amount": mam, "max": int(e.get("max", 0)), "price": buy_price(v, art, 1)})
	return out


func sellable(m: int, v: int) -> Array[Dictionary]:
	# Radky pro gump "co hrac muze prodat TOMUHLE vendorovi" - z batohu hrace
	# (proto mobil), serazene podle artu (determinismus). Zlato se neprodava
	# (reference s nim ma vlastni cestu: "I thank thee.").
	var mob = _mobile(m)
	var out: Array[Dictionary] = []
	if mob == null or _record(v).is_empty():
		return out
	var podle_artu: Dictionary = {}
	for serial in _contents(int(mob.backpack)):
		var item = _item(int(serial))
		if item == null:
			continue
		var art: int = int(item.tile)
		if _je_zlato(item):
			continue
		var cena: int = sell_price(v, art, 1)
		if cena <= 0:
			continue
		if not podle_artu.has(art):
			podle_artu[art] = {"item": art, "type": str(item.type),
				"name": ItemScript.name_of(art), "amount": 0, "price": cena}
		podle_artu[art]["amount"] = int(podle_artu[art]["amount"]) + int(item.amount)
	var arty: Array = podle_artu.keys()
	arty.sort()
	for art in arty:
		if out.size() >= _gump_rows():
			break
		out.append(podle_artu[art])
	return out


func buy_price(v: int, item: int, amount: int = 1) -> int:
	# Cena za KUS, kterou hrac PLATI (`GenericSell.cs:126-129`). `amount` je ve
	# smlouve, ale cena na nem nezavisí (zadne slevy za mnozstvi) - je tu kvuli
	# tvaru volani z docs/04 §4.3. `ceil` v celych cislech (zadny float ve stavu).
	var zaklad: int = sell_price(v, item, amount)
	if zaklad <= 0:
		return 0
	var percent: int = maxi(int(_config.get("buy_percent", 190)), MIN_BUY_PERCENT)
	return (zaklad * percent + 99) / 100


func sell_price(v: int, item: int, amount: int = 1) -> int:
	# Cena za KUS, kterou vendor ZAPLATI hracovi. Prednost ma TABULKA vendora
	# (`buys[].price`); co v ni neni, jde na fallback z `value` (viz hlavicka).
	if item <= 0 or _record(v).is_empty():
		return 0
	var typ: String = ItemScript.type_of(item)
	if typ == GOLD_TYPE:
		return 0                         # zlato se neprodava (viz `sellable`)
	var percent: int = maxi(int(_config.get("buy_percent", 190)), MIN_BUY_PERCENT)
	for e in _record(v).get("buys", []):
		if str(e.get("type", "")) == typ:
			return maxi(1, int(e.get("price", 0)))
	# Predmet, ktery vendor PRODAVA, ale NEKUPUJE: cena se odvodi z autorske
	# retail ceny z tabulky tak, aby `buy = ceil(percent/100 * sell)` vyslo
	# PRESNE na ni. Bez toho by rozhodla az `value` - NAMERENO: leather_cap ma
	# retail 10, ale `value` 145 (nas buy by byl 276, 27x vic).
	var e := _stock_entry(v, item)
	if not e.is_empty() and int(e.get("price", 0)) > 0:
		return maxi(1, (int(e["price"]) * 100) / percent)
	return _fallback_cena(item, typ)


func buy(m: int, v: int, lines: Array) -> Dictionary:
	# Nakup: kontrola zlata a skladu je PRED zapisem; co se nevejde do batohu,
	# vrati zlato zpet (zadny castecny stav).
	var mob = _mobile(m)
	if mob == null:
		return _fail("no_mobile")
	if _record(v).is_empty():
		return _fail("no_vendor")
	if not _dosah(mob, v):
		return _fail("too_far" if _pozice.has(_vid(v)) else "no_vendor_pos")
	_restock_if_due(v)
	var nakup: Array = []
	var celkem: int = 0
	for line in lines:
		if not (line is Dictionary):
			return _fail("line")
		var art: int = int(line.get("item", 0))
		var mnozstvi: int = int(line.get("amount", 0))
		if mnozstvi <= 0:
			return _fail("amount")
		var e := _stock_entry(v, art)
		if e.is_empty():
			return _fail("not_sold")
		var typ: String = str(e.get("type", ""))
		if _stock_of(v, typ) < mnozstvi:
			return _fail("out_of_stock")
		var kus: int = buy_price(v, art, 1)
		if kus <= 0:
			return _fail("no_price")
		celkem += kus * mnozstvi
		nakup.append({"art": art, "amount": mnozstvi, "type": typ,
			"name": str(e.get("name", "")), "price": kus})
	if _gold(mob) < celkem:
		return _fail("gold")             # nic se nezmeni (kontrola pred zapisem)
	var nove: Array = []
	for n in nakup:
		var item = ItemScript.new(_next_serial(), int(n["art"]), int(n["amount"]))
		if _container == null or not _container.can_add(int(mob.backpack), item).get("ok", false):
			return _fail("pack_full")
		nove.append(item)
	_odeber_zlato(mob, celkem)
	var pridane: Array = []
	for item in nove:
		if _container == null or not _container.add(int(mob.backpack), item):
			# ZALOHA: zlato i uz pridane predmety zpet (jinak by hrac zaplatil
			# a nedostal nic - "castecny stav" je horsi nez "nešlo to").
			for serial in pridane:
				_container.remove(int(mob.backpack), int(serial), 0)
			_add_gold(mob, celkem)
			return _fail("pack_full")
		if int(item.parent) == int(mob.backpack):     # (cely slouceny predmet tu neni)
			if _items is Dictionary:
				_items[int(item.serial)] = item
			pridane.append(int(item.serial))
	for n in nakup:
		_uber_stock(v, str(n["type"]), int(n["amount"]))
	_message("You buy %d items for %d gold." % [pridane.size(), celkem])
	return {"ok": true, "reason": "", "action": "buy", "vendor": v, "total": celkem,
		"gold_left": _gold(mob), "items": pridane, "lines": nakup}


func sell(m: int, v: int, lines: Array) -> Dictionary:
	# Prodej: cena je `sell_price` za kus (`prodej 10 ks = 10 x sell_price`,
	# docs/05 §5.9). Zlato se do batohu pridava az po uspesnem odectu predmetu
	# a jeho misto se kontroluje PRED nim (plny batoh nesmi sebrat predmet).
	var mob = _mobile(m)
	if mob == null:
		return _fail("no_mobile")
	if _record(v).is_empty():
		return _fail("no_vendor")
	if not _dosah(mob, v):
		return _fail("too_far" if _pozice.has(_vid(v)) else "no_vendor_pos")
	_restock_if_due(v)
	var prodej: Array = []
	var celkem: int = 0
	for line in lines:
		if not (line is Dictionary):
			return _fail("line")
		var art: int = int(line.get("item", 0))
		var mnozstvi: int = int(line.get("amount", 0))
		if mnozstvi <= 0:
			return _fail("amount")
		var kus: int = sell_price(v, art, 1)
		if kus <= 0:
			return _fail("not_for_sale")
		if _count_art(mob, art) < mnozstvi:
			return _fail("no_items")
		celkem += kus * mnozstvi
		prodej.append({"art": art, "amount": mnozstvi, "type": ItemScript.type_of(art),
			"name": ItemScript.name_of(art), "price": kus})
	var zlato = ItemScript.new(_next_serial(), int(_config.get("gold_art", 0x4EED)), celkem)
	if _container == null or not _container.can_add(int(mob.backpack), zlato).get("ok", false):
		return _fail("pack_full")
	var vzato: int = 0
	for p in prodej:
		vzato += _odeber_art(mob, int(p["art"]), int(p["amount"]))
	# Misto pro zlato je overene PRED odectem (`can_add` vyse), takze `add` tu
	# nema selhat; kdyby selhal, NESMI to byt tiche - `gold_added: false` to
	# vrati volajicimu a hlaska jde do zurnalu.
	var vlozeno: bool = _container.add(int(mob.backpack), zlato)
	if vlozeno and _items is Dictionary:
		_items[int(zlato.serial)] = zlato
	if not vlozeno:
		_fail("pack_full")
	_message("You sell %d items for %d gold." % [vzato, celkem])
	return {"ok": true, "reason": "", "action": "sell", "vendor": v, "total": celkem,
		"count": vzato, "sold": prodej, "gold_left": _gold(mob), "gold_added": vlozeno}


func restock() -> void:
	# Restock je LINIVY: reference ho pousti pri pristupu k vendorovi, kdyz od
	# posledniho uplynulo `restock_ms` (`BaseVendor.cs:920-923`). Rucni volani
	# je pro `[ForceRestock]` a pro test - doplni VSECHNY, kterym to vyprselo.
	for v in range(_records.size()):
		_restock_if_due(v)


# -- mereni a integrace (nad ramec smlouvy) --------------------------------

func zaregistruj_serial(serial: int, v: int) -> bool:
	# ⚠ SERIAL VENDORA NENI INDEX VENDORA (nalezeno pri integraci 2026-10-10):
	# `v` je poradi v `data/vendors.json` (index), kdezto `Command{t:"use"}`
	# posila SERIAL mobily ve svete. `sim.interaction` vola `vendor.stock()`
	# se serialem, takze bez tehle vazby by se ptalo na neexistujici vendory.
	# Vazbu zna jen `app/main` (on vendora staví), proto ji sem predava.
	if serial <= 0 or v < 0 or v >= _records.size():
		return false
	_serial_vendor[int(serial)] = v
	return true


func vendor_of_serial(serial: int) -> int:
	# -1 = serial neni zadny vendor (volajici to musi rict slovem, ne tise).
	return int(_serial_vendor.get(int(serial), -1))
func vendor_ids() -> Array[String]:
	var out: Array[String] = []
	for rec in _records:
		out.append(str(rec.get("id", "")))
	return out


func vendor_index(id: String) -> int:
	for i in range(_records.size()):
		if str(_records[i].get("id", "")) == id:
			return i
	return -1


func stock_of(v: int, typ: String) -> int:
	return _stock_of(v, typ)


func art_of_type(v: int, typ: String) -> int:
	# ART predmetu daneho TYPU, ktery vendor prodava nebo vykupuje (0 = nema).
	# Potrebuje to klient/sonda, aby nemusela vymyslet art ID z hlavy (namEReno
	# 2026-10-10: `0x0E86` neni krumpac teto instalace - je to 20101).
	var rec: Dictionary = _record(v)
	if rec.is_empty():
		return 0
	for seznam_v in [rec.get("stock", []), rec.get("buys", [])]:
		if not (seznam_v is Array):
			continue
		for e in seznam_v:
			if e is Dictionary and str(e.get("type", "")) == typ:
				return int(e.get("tile", 0)) + ITEM_OFFSET
	return 0


func nastav_pozici(v: int, pozice: Vector3i) -> bool:
	# ⚠ VIZ UKLID: `_serial_vendor` (nize) - serial vendora NENI index vendora.
	# `v_index` je poradi v `data/vendors.json`, `serial` je serial mobily ve
	# svete. `app/main` oboji spoji pres `zaregistruj_serial()`, protoze jen on
	# vi, ktereho mobila postavil.
	# Kde vendor ve svete stoji (dosahem se hlida obchod). Bez toho se
	# OBCHODOVAT NEDA a je to VIDET (`reason:"no_vendor_pos"`) - "nevim, kde
	# je" nesmi znamenat "je jedno, kde jsem". Zapisuje integrace pri postaveni
	# vendora; pozice NENI soucast `state()` (je to konfigurace sveta, ne stav
	# obchodu - a v save by z ni byl druhy zdroj pravdy).
	if _record(v).is_empty():
		return false
	_pozice[_vid(v)] = pozice
	return true


func pozice(v: int) -> Variant:
	# `Vector3i`, nebo `null` (nezname = neoveritelne, nikdy (0,0,0)).
	return _pozice.get(_vid(v))


func gump_data(m: int, v: int) -> Dictionary:
	# Data pro udalost `gump_open` (docs/04 §4.4/§4.6.5). UI je TENKY KLIENT:
	# dostane obe strany (co si koupit / co prodat) i ceny hotove a samo nic
	# nepocita. `data.vendor` je INDEX, `data.id` je jmeno z dat.
	return {"gump": "vendor", "data": {"vendor": v, "id": _vid(v),
		"name": str(_record(v).get("title", "")), "buy": stock(v), "sell": sellable(m, v)}}


func state() -> Dictionary:
	# Stav pro save/hash: sklad a cas posledniho doplneni. Vsechno cela cisla
	# a slovniky (hash si klice radi sam - docs/04 §4.7).
	var sklad: Dictionary = {}
	for id in _stock.keys():
		var polozky: Dictionary = {}
		for typ in (_stock[id] as Dictionary).keys():
			polozky[str(typ)] = int(_stock[id][typ])
		sklad[str(id)] = polozky
	return {"stock": sklad, "restock": _restock.duplicate()}


func restore(d: Dictionary) -> void:
	# NEMERENO: nenasel jsem, jak se stav vendora uklada v reference (`BuyPack`
	# je skutecny kontejner, ne cislo); tvar je proto nas a je popsany tady.
	_stock = {}
	_restock = {}
	if not (d is Dictionary):
		return
	for id in (d.get("stock", {}) as Dictionary).keys():
		var polozky: Dictionary = {}
		for typ in ((d["stock"][id]) as Dictionary).keys():
			polozky[str(typ)] = int(d["stock"][id][typ])
		_stock[str(id)] = polozky
	for id in (d.get("restock", {}) as Dictionary).keys():
		_restock[str(id)] = int(d["restock"][id])


func stats() -> Dictionary:
	return {"vendors": _records.size(), "stock": _stock.size(), "ceny": _nejlevnejsi.size(),
		"gump_max_rows": _gump_rows()}


# -- vnitrni: ceny ---------------------------------------------------------

func _fallback_cena(item: int, typ: String) -> int:
	if _tiledata == null:
		return 0                         # "nevim" neni cena (nula jako cena je lez)
	var hodnota: int = int(_tiledata.value(item))
	if hodnota <= 0:
		return 0
	var cena: int = (hodnota * int(_config.get("value_percent", 100)) + 99) / 100
	var strop: int = int(_nejlevnejsi.get(typ, 0))
	if strop > 0 and cena > strop:
		cena = strop                     # STROP PROTI ARBITRAZI (viz `_postav_ceny`)
	return maxi(cena, 1)


func _postav_ceny() -> void:
	# `_nejlevnejsi[type]` = nejnizsi cena, za kterou se dany typ da u NEKOHO
	# koupit. Bere se (1) nase nakupni cena (`1,9 x sell`), kdyz typ je v jeho
	# `buys`, jinak (2) autorska retail cena z tabulky (`stock[].price`).
	# Bez toho by fallback (value) mohl byt vyssi nez nakupni cena - hrac by
	# koupil u Kovare a prodal u Krejciho. NAMERENO: pickaxe retail 22, value 58.
	var percent: int = maxi(int(_config.get("buy_percent", 190)), MIN_BUY_PERCENT)
	for rec in _records:
		for e in rec.get("stock", []):
			var typ: String = str(e.get("type", ""))
			var tabulkova: int = 0
			for b in rec.get("buys", []):
				if str(b.get("type", "")) == typ:
					tabulkova = int(b.get("price", 0))
			var cena: int = int(e.get("price", 0))     # autorska retail cena z tabulky
			if tabulkova > 0:
				cena = (tabulkova * percent + 99) / 100  # nase nakupni cena (1,9 x sell)
			if cena <= 0:
				continue
			var stara: int = int(_nejlevnejsi.get(typ, 0))
			_nejlevnejsi[typ] = cena if stara == 0 else mini(stara, cena)


# -- vnitrni: sklad a restock ---------------------------------------------

func _record(v: int) -> Dictionary:
	return _records[v] if v >= 0 and v < _records.size() else {}


func _vid(v: int) -> String:
	return str(_record(v).get("id", ""))


func _gump_rows() -> int:
	return maxi(int(_config.get("gump_max_rows", DEFAULT_GUMP_ROWS)), 1)


func _art(e: Dictionary) -> int:
	return int(e.get("tile", 0)) + ITEM_OFFSET


func _stock_entry(v: int, art: int) -> Dictionary:
	for e in _record(v).get("stock", []):
		if _art(e) == art:
			return e
	return {}


func _stock_of(v: int, typ: String) -> int:
	var sklad = _stock.get(_vid(v), {})
	return int(sklad.get(typ, 0)) if sklad is Dictionary else 0


func _uber_stock(v: int, typ: String, mnozstvi: int) -> void:
	var id: String = _vid(v)
	var sklad: Dictionary = _stock.get(id, {})
	sklad[typ] = maxi(0, int(sklad.get(typ, 0)) - mnozstvi)
	_stock[id] = sklad


func _restock_if_due(v: int) -> void:
	var rec := _record(v)
	if rec.is_empty():
		return
	var interval: int = int(rec.get("restock_ms", _config.get("restock_ms", DEFAULT_RESTOCK_MS)))
	if interval <= 0:
		return
	var now: int = int(_clock.now_ms())
	var id: String = str(rec.get("id", ""))
	if now - int(_restock.get(id, 0)) < interval:
		return
	_dopln(id, rec)
	_restock[id] = now


func _dopln(id: String, rec: Dictionary) -> void:
	# Restock nastavi sklad na `max` z tabulky (reference `bii.OnRestock()`);
	# `max` chybejici v datech znamena 1, nikdy 0 (nula by shop vyprázdnila).
	var sklad: Dictionary = {}
	for e in rec.get("stock", []):
		sklad[str(e.get("type", ""))] = maxi(1, int(e.get("max", 1)))
	_stock[id] = sklad


# -- vnitrni: zlato a predmety --------------------------------------------

func _contents(c: int) -> Array:
	return [] if _container == null else _container.contents(c)


func _item(serial: int):
	if _items == null or serial <= 0:
		return null
	if _items is Dictionary:
		return _items.get(serial)
	if _items is Object and _items.has_method("get_item"):
		return _items.get_item(serial)
	return null


func _je_zlato(item) -> bool:
	return str(item.type) == GOLD_TYPE or int(item.tile) == int(_config.get("gold_art", 0x4EED))


func _gold(mob) -> int:
	var soucet: int = 0
	for serial in _contents(int(mob.backpack)):
		var item = _item(int(serial))
		if item != null and _je_zlato(item):
			soucet += int(item.amount)
	return soucet


func _odeber_zlato(mob, mnozstvi: int) -> int:
	var zbyva: int = mnozstvi
	for serial in _contents(int(mob.backpack)):
		if zbyva <= 0:
			break
		var item = _item(int(serial))
		if item == null or not _je_zlato(item):
			continue
		zbyva -= int(_container.remove(int(mob.backpack), int(item.serial), zbyva))
	return mnozstvi - zbyva


func _add_gold(mob, mnozstvi: int) -> bool:
	var zlato = ItemScript.new(_next_serial(), int(_config.get("gold_art", 0x4EED)), mnozstvi)
	if _container == null or int(mob.backpack) <= 0 or not _container.add(int(mob.backpack), zlato):
		return false
	if _items is Dictionary:
		_items[int(zlato.serial)] = zlato
	return true


func _count_art(mob, art: int) -> int:
	var soucet: int = 0
	for serial in _contents(int(mob.backpack)):
		var item = _item(int(serial))
		if item != null and int(item.tile) == art:
			soucet += int(item.amount)
	return soucet


func _odeber_art(mob, art: int, mnozstvi: int) -> int:
	var zbyva: int = mnozstvi
	for serial in _contents(int(mob.backpack)):
		if zbyva <= 0:
			break
		var item = _item(int(serial))
		if item == null or int(item.tile) != art:
			continue
		zbyva -= int(_container.remove(int(mob.backpack), int(item.serial), zbyva))
	return mnozstvi - zbyva


# -- vnitrni: zaklad -------------------------------------------------------

func _mobile(m: int):
	return null if _registry == null else _registry.get_mobile(m)


func _next_serial() -> int:
	return int(_serials.next_serial()) if _serials != null else 0


func _load(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("sim.vendor: chybi " + path + " - obchod nebude fungovat")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("sim.vendor: " + path + " neni objekt")
		return
	_config = parsed.get("config", {}) if parsed.get("config") is Dictionary else {}
	var seznam = parsed.get("vendors", [])
	if not (seznam is Array):
		push_warning("sim.vendor: " + path + " nema seznam `vendors`")
		return
	for rec in seznam:
		if rec is Dictionary and str(rec.get("id", "")) != "":
			_records.append(rec)
			_dopln(str(rec["id"]), rec)          # start s plnym skladem
			_restock[str(rec["id"])] = 0
	_postav_ceny()


func _dosah(mob, v: int) -> bool:
	# Dosažení na vendora (2 dlazdice, `VENDOR_RANGE`); neznama pozice = false
	# (volajici to rozlisi pres `_pozice.has(...)` a dostane jiny duvod).
	var kde = _pozice.get(_vid(v))
	if not (kde is Vector3i):
		return false
	return absi(int(mob.pos.x) - int(kde.x)) <= VENDOR_RANGE \
		and absi(int(mob.pos.y) - int(kde.y)) <= VENDOR_RANGE


func _fail(reason: String) -> Dictionary:
	# "Nic se nestalo" musi byt VIDET - hlaska do zurnalu (docs/04 §4.4).
	match reason:
		"gold":
			_message("You cannot afford that.")
		"out_of_stock":
			_message("The vendor does not have that many.")
		"pack_full":
			_message("Your backpack cannot hold anything else.")
		"not_for_sale", "not_sold":
			_message("The vendor is not interested in that.")
		"too_far":
			_message("You are too far away.")
		"no_vendor_pos":
			_message("The vendor is not here.")
	return {"ok": false, "reason": reason, "action": "", "total": 0}


func _message(text: String) -> void:
	if _events != null:
		_events.push("message", {"text": text, "kind": "system"})
