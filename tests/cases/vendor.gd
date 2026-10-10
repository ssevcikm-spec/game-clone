extends RefCounted
# sim.vendor - obchod (smlouva docs/04 §4.2 a tok §4.6.5, pravidla docs/05 §5.9).
#
# Test meri KONKRETNI CHOVANI s realnymi daty (`data/vendors.json`) a realnym
# `entity.container`:
#   * ceny: `sell_price` z tabulky vendora, `buy_price == ceil(1,90 x sell)`
#     (kovar: ingot 4/8, dyka 10/19, krumpac 11/21 - cisla z dat, NE opsana),
#   * prodej 10 kusu vrati `10 x sell_price` (přijímací kritérium docs/05 §5.9),
#   * nakup odecte zlato a prida predmet; bez zlata `{ok:false, reason:"gold"}`
#     a ZADNA zmena stavu + JE VIDET duvod (hlaska v udalostech),
#   * vyprodany sklad -> `out_of_stock` a radek zmizi z gumpu,
#   * restock az po uplynuti `restock_ms` (a pred nim NIC),
#   * fallback pro predmet, ktery v tabulce vendora neni, a STROP PROTI
#     ARBITRAZI (koupit u kovare a prodat u krejciho nesmi vydelat),
#   * determinismus (dva stejne behy = stejny hash) a `state()`/`restore()`,
#   * `gump_data` je integracni sram (data pro udalost `gump_open`).
#
# Vahu a `value` bere modul z `tiledata`; v CI nejsou `assets/uo`, proto test
# podstrkuje STUB (meri se tim i v CI). Bez tiledata se fallback NEMERI a test
# to overuje zvlast (nula jako cena je lez).
#
# Cesta k modulu je VSTUP (`-- --vendor-script=<cesta>`) a cesta k datum take
# (`-- --vendors-path=<cesta>`) - oboji kvuli mutacnimu harness.

const Lib = preload("res://tests/lib.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const ContainerScript = preload("res://sim/entity/container.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const HashScript = preload("res://core/hash.gd")

const VENDOR_SCRIPT := "res://sim/systems/vendor.gd"
const VENDORS_PATH := "res://data/vendors.json"

const SERIAL := 0x40000099
const PACK := 0x00000099
const GOLD_ART := 0x4EED            # zlato (tile 3821 + 0x4000)
const INGOT_ART := 0x5BEF           # iron ingot (tile 7151 + 0x4000)
const PICKAXE_ART := 0x4E85         # pickaxe (tile 3717 + 0x4000)
const DAGGER_ART := 0x4F51          # dagger (tile 3921 + 0x4000)
const LEATHER_CAP_ART := 0x5DB9     # leather cap (tile 7609 + 0x4000)
const F_STACKABLE := 0x00000800

# Cisla z `data/vendors.json` (kovar) - NAMERENA, ne opsana z hlavicky modulu.
const BS_INGOT_SELL := 4
const BS_INGOT_BUY := 8
const BS_INGOT_MAX := 16
const BS_DAGGER_SELL := 10
const BS_DAGGER_BUY := 19
const BS_PICKAXE_SELL := 11
const BS_PICKAXE_BUY := 21
const RESTOCK_MS := 3600000
const VENDORU_MIN := 25              # docs/06 §6.6 "Vendor profesí: 25"


class StubTiledata:
	# `value` pro fallback ceny a `weight`/`flags` pro kontejner.
	var hodnoty: Dictionary = {}
	var vahy: Dictionary = {}

	func _init() -> void:
		# `value` u techto artu je z `data/items.json` (value_source: pocet z
		# tiledata) - u cepice 145, i kdyz jeji retail u krejciho je 10. Presne
		# tenhle rozchod je duvod, proc cena predmene, ktery vendor jen PRODAVA,
		# vychazi z tabulky a ne z `value`.
		hodnoty = {PICKAXE_ART: 58, DAGGER_ART: 20, INGOT_ART: 1, GOLD_ART: 1,
			LEATHER_CAP_ART: 145}

	func value(item: int) -> int:
		return int(hodnoty.get(item, 0))

	func weight(item: int) -> int:
		return int(vahy.get(item, 0))

	func flags(item: int) -> int:
		# Zlato a ingot se slucuji (jako v realnem tiledata) - jinak by kazdy
		# nakup udelal novou hromadu a test "amount" by meril neco jineho.
		return F_STACKABLE if item in [GOLD_ART, INGOT_ART] else 0


class StubSerials:
	var hodnota: int = 7000

	func next_serial() -> int:
		hodnota += 1
		return hodnota


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _sestav(t, s_tiledata: bool = true, s_pozici: bool = true) -> Array:
	# Vraci [vendor, mob, kontejner, predmety, events, clock]; prazdne pole =
	# granule/data nejsou (SELHANI, ne zelena). `s_pozici` nastavi pozici
	# vendora na dlazdici hrace - bez ni se OBCHODOVAT NEDA (`no_vendor_pos`).
	var cesta: String = _arg("vendor-script", VENDOR_SCRIPT)
	var data: String = _arg("vendors-path", VENDORS_PATH)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.vendor NENI HOTOVY: " + cesta + " chybi (nebo parse error)")
		return []
	if Lib.json_at(data) == null:
		t._pending("sim.vendor NEMERI: data " + data + " nejsou")
		return []
	var tiledata = StubTiledata.new()
	var kontejner = ContainerScript.new(tiledata)
	var predmety: Dictionary = {}
	var registry = RegistryScript.new()
	var events = EventsScript.new()
	var clock = ClockScript.new()
	var mob = MobileScript.new(SERIAL, 400, Vector3i(100, 100, 0))
	mob.backpack = PACK
	registry.register(mob)
	var vendor = script.new(kontejner, predmety, tiledata if s_tiledata else null,
		registry, StubSerials.new(), clock, events, data)
	if s_pozici:
		# Dosah je pravidlo (`buy`/`sell`), takze kazdy vendor stoji tam, kde
		# hrac - testy cen a skladu tak meri to, co maji (ne dosah).
		for i in range(vendor.vendor_ids().size()):
			vendor.nastav_pozici(i, Vector3i(100, 100, 0))
	return [vendor, mob, kontejner, predmety, events, clock]


func _pridej(kontejner, predmety: Dictionary, art: int, amount: int) -> void:
	var serial: int = 5000 + predmety.size()
	var item = ItemScript.new(serial, art, amount)
	item.pos = Vector3i(100, 100, 0)
	kontejner.add(PACK, item)
	predmety[serial] = item


func _pocet(kontejner, predmety: Dictionary, art: int) -> int:
	var soucet: int = 0
	for serial in kontejner.contents(PACK):
		var item = predmety.get(int(serial))
		if item != null and int(item.tile) == art:
			soucet += int(item.amount)
	return soucet


func _gold(kontejner, predmety: Dictionary) -> int:
	var soucet: int = 0
	for serial in kontejner.contents(PACK):
		var item = predmety.get(int(serial))
		if item != null and (str(item.type) == "gold_coin" or int(item.tile) == GOLD_ART):
			soucet += int(item.amount)
	return soucet


func _texty(events) -> String:
	var out: String = ""
	for event in events.drain():
		if str(event.get("name", "")) == "message":
			out += str(event["data"].get("text", "")) + " | "
	return out


func run(t) -> void:
	# -- A) data a ceny (konkretni cisla z `data/vendors.json`) ----------
	var a := _sestav(t)
	if a.is_empty():
		return
	var vendor = a[0]
	var ids: Array = vendor.vendor_ids()
	t._check(ids.size() >= VENDORU_MIN,
		"sim.vendor: dat je aspon %d vendoru (namEReno %d)" % [VENDORU_MIN, ids.size()])
	var bs: int = vendor.vendor_index("blacksmith")
	t._check(bs >= 0, "sim.vendor: kovar (`blacksmith`) v datech je (index %d)" % bs)
	if bs < 0:
		return
	t._check(vendor.sell_price(bs, INGOT_ART, 1) == BS_INGOT_SELL
			and vendor.buy_price(bs, INGOT_ART, 1) == BS_INGOT_BUY,
		"sim.vendor: kovar kupuje ingot za %d a prodava za %d (namEReno %d/%d)"
			% [BS_INGOT_SELL, BS_INGOT_BUY, vendor.sell_price(bs, INGOT_ART, 1),
				vendor.buy_price(bs, INGOT_ART, 1)])
	t._check(vendor.sell_price(bs, DAGGER_ART, 1) == BS_DAGGER_SELL
			and vendor.buy_price(bs, DAGGER_ART, 1) == BS_DAGGER_BUY,
		"sim.vendor: dyka ma sell/buy %d/%d (namEReno %d/%d)"
			% [BS_DAGGER_SELL, BS_DAGGER_BUY, vendor.sell_price(bs, DAGGER_ART, 1),
				vendor.buy_price(bs, DAGGER_ART, 1)])
	t._check(vendor.sell_price(bs, PICKAXE_ART, 1) == BS_PICKAXE_SELL
			and vendor.buy_price(bs, PICKAXE_ART, 1) == BS_PICKAXE_BUY,
		"sim.vendor: krumpac ma sell/buy %d/%d (namEReno %d/%d)"
			% [BS_PICKAXE_SELL, BS_PICKAXE_BUY, vendor.sell_price(bs, PICKAXE_ART, 1),
				vendor.buy_price(bs, PICKAXE_ART, 1)])
	# Smlouva §4.6.5: `buy_price == ceil(1,90 x sell_price)` na CELÉM skladu.
	var rozchod: String = ""
	var radky: Array = vendor.stock(bs)
	for radek in radky:
		var sell: int = vendor.sell_price(bs, int(radek["item"]), 1)
		var ma_byt: int = (sell * 190 + 99) / 100
		if vendor.buy_price(bs, int(radek["item"]), 1) != ma_byt:
			rozchod += "%s " % str(radek["name"])
	t._check(rozchod == "" and radky.size() > 0,
		"sim.vendor: buy_price == ceil(1,90 x sell_price) u vsech %d radku (rozchod: %s)"
			% [radky.size(), rozchod if rozchod != "" else "-"])
	var ingot: Dictionary = {}
	for radek in radky:
		if int(radek["item"]) == INGOT_ART:
			ingot = radek
	t._check(int(ingot.get("amount", -1)) == BS_INGOT_MAX
			and int(ingot.get("price", -1)) == BS_INGOT_BUY,
		"sim.vendor: radek skladu ingotu je {amount:%d, price:%d} (namEReno %s)"
			% [BS_INGOT_MAX, BS_INGOT_BUY, str(ingot)])
	t._check(radky.size() <= 250,
		"sim.vendor: gump ma strop 250 radku (namEReno %d)" % radky.size())

	# -- B) prodej 10 kusu = 10 x sell_price (docs/05 §5.9) --------------
	var b := _sestav(t)
	if b.is_empty():
		return
	vendor = b[0]
	bs = vendor.vendor_index("blacksmith")
	_pridej(b[2], b[3], DAGGER_ART, 10)
	var prodej: Dictionary = vendor.sell(SERIAL, bs, [{"item": DAGGER_ART, "amount": 10}])
	t._check(bool(prodej.get("ok", false)) and int(prodej.get("total", 0)) == 10 * BS_DAGGER_SELL,
		"sim.vendor: prodej 10 dyk vrati 10 x %d = %d (namEReno %s)"
			% [BS_DAGGER_SELL, 10 * BS_DAGGER_SELL, str(prodej)])
	t._check(_pocet(b[2], b[3], DAGGER_ART) == 0 and not b[2].contents(PACK).is_empty(),
		"sim.vendor: po prodeji jsou dyky pryc (%d) a v batohu zustalo %d veci"
			% [_pocet(b[2], b[3], DAGGER_ART), b[2].contents(PACK).size()])
	t._check(_gold(b[2], b[3]) == 100,
		"sim.vendor: zlato z prodeje je v batohu (namEReno %d)" % _gold(b[2], b[3]))

	# -- C) nakup: zlato pryc, predmet v batohu, sklad dolu ---------------
	var c := _sestav(t)
	if c.is_empty():
		return
	vendor = c[0]
	bs = vendor.vendor_index("blacksmith")
	_pridej(c[2], c[3], GOLD_ART, 100)
	var nakup: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": 2}])
	t._check(bool(nakup.get("ok", false)) and int(nakup.get("total", 0)) == 2 * BS_INGOT_BUY,
		"sim.vendor: nakup 2 ingotu stoji 2 x %d = %d (namEReno %s)"
			% [BS_INGOT_BUY, 2 * BS_INGOT_BUY, str(nakup)])
	t._check(_gold(c[2], c[3]) == 100 - 2 * BS_INGOT_BUY
			and _pocet(c[2], c[3], INGOT_ART) == 2,
		"sim.vendor: zlato %d a ingotu %d (ocekavano %d a 2)"
			% [_gold(c[2], c[3]), _pocet(c[2], c[3], INGOT_ART), 100 - 2 * BS_INGOT_BUY])
	t._check(vendor.stock_of(bs, "iron_ingot") == BS_INGOT_MAX - 2,
		"sim.vendor: sklad ingotu klesl na %d (namEReno %d)"
			% [BS_INGOT_MAX - 2, vendor.stock_of(bs, "iron_ingot")])

	# -- D) malo zlata -> zadna zmena a VIDITELNY duvod -------------------
	var d := _sestav(t)
	if d.is_empty():
		return
	vendor = d[0]
	bs = vendor.vendor_index("blacksmith")
	_pridej(d[2], d[3], GOLD_ART, 5)
	var chude: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(not bool(chude.get("ok", true)) and str(chude.get("reason", "")) == "gold",
		"sim.vendor: s 5 zlaty (cena %d) nakup vraci {ok:false, reason:'gold'} (namEReno %s)"
			% [BS_INGOT_BUY, str(chude)])
	t._check(_gold(d[2], d[3]) == 5 and _pocet(d[2], d[3], INGOT_ART) == 0
			and vendor.stock_of(bs, "iron_ingot") == BS_INGOT_MAX,
		"sim.vendor: po odmitnutem nakupu se stav NEZMENIL (zlato %d, ingotu %d, sklad %d)"
			% [_gold(d[2], d[3]), _pocet(d[2], d[3], INGOT_ART),
				vendor.stock_of(bs, "iron_ingot")])
	var hlasky: String = _texty(d[4])
	t._check(hlasky.contains("afford"),
		"sim.vendor: duvod je VIDET v udalostech (namEReno '%s')" % hlasky)

	# -- E) vyprodano -> out_of_stock a radek zmizi z gumpu ---------------
	var e := _sestav(t)
	if e.is_empty():
		return
	vendor = e[0]
	bs = vendor.vendor_index("blacksmith")
	_pridej(e[2], e[3], GOLD_ART, BS_INGOT_MAX * BS_INGOT_BUY)
	var vse: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": BS_INGOT_MAX}])
	t._check(bool(vse.get("ok", false)) and vendor.stock_of(bs, "iron_ingot") == 0,
		"sim.vendor: nakup celeho skladu (%d) projde a sklad je 0 (namEReno %s, sklad %d)"
			% [BS_INGOT_MAX, str(vse), vendor.stock_of(bs, "iron_ingot")])
	var ma_ingot: bool = false
	for radek in vendor.stock(bs):
		if int(radek["item"]) == INGOT_ART:
			ma_ingot = true
	t._check(not ma_ingot, "sim.vendor: vyprodany ingot v gumpu NENI (radek zustal: %s)" % str(ma_ingot))
	var podruhe: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(not bool(podruhe.get("ok", true))
			and str(podruhe.get("reason", "")) == "out_of_stock",
		"sim.vendor: z vyprodaneho skladu se koupit neda (namEReno %s)" % str(podruhe))

	# -- F) restock az po `restock_ms`, pred nim NIC ---------------------
	# (pokracuje na `e`: sklad je vyprodany a `_restock` je z `_load` na 0)
	e[5].advance(RESTOCK_MS - 1)
	vendor.restock()
	t._check(vendor.stock_of(bs, "iron_ingot") == 0,
		"sim.vendor: pred uplynutim %d ms se restock NEDELA (sklad %d)"
			% [RESTOCK_MS, vendor.stock_of(bs, "iron_ingot")])
	e[5].advance(1)
	vendor.restock()
	t._check(vendor.stock_of(bs, "iron_ingot") == BS_INGOT_MAX,
		"sim.vendor: po %d ms restock doplni sklad na %d (namEReno %d)"
			% [RESTOCK_MS, BS_INGOT_MAX, vendor.stock_of(bs, "iron_ingot")])

	# -- G) nezname id / nezaregistrovany mobil ---------------------------
	t._check(vendor.stock(999).is_empty(),
		"sim.vendor: neznamy vendor nema sklad (namEReno %d radku)" % vendor.stock(999).size())
	var neznamy: Dictionary = vendor.buy(SERIAL, 999, [{"item": INGOT_ART, "amount": 1}])
	t._check(str(neznamy.get("reason", "")) == "no_vendor",
		"sim.vendor: neznamy vendor vraci 'no_vendor' (namEReno %s)" % str(neznamy))
	var cizi: Dictionary = vendor.buy(0x40000001, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(str(cizi.get("reason", "")) == "no_mobile",
		"sim.vendor: nezaregistrovany mobil vraci 'no_mobile' (namEReno %s)" % str(cizi))

	# -- H) fallback a STROP PROTI ARBITRAZI ------------------------------
	var h := _sestav(t)
	if h.is_empty():
		return
	vendor = h[0]
	bs = vendor.vendor_index("blacksmith")
	var krejci: int = vendor.vendor_index("tailor")
	t._check(krejci >= 0, "sim.vendor: krejci (`tailor`) v datech je (index %d)" % krejci)
	var fallback: int = vendor.sell_price(krejci, PICKAXE_ART, 1)
	var u_kovare: int = vendor.buy_price(bs, PICKAXE_ART, 1)
	t._check(fallback > 0 and fallback <= u_kovare,
		"sim.vendor: fallback u krejciho (%d) neni vyssi nez nakup u kovare (%d) - zadna arbitraz"
			% [fallback, u_kovare])
	_pridej(h[2], h[3], PICKAXE_ART, 1)
	var zpet: Dictionary = vendor.sell(SERIAL, krejci, [{"item": PICKAXE_ART, "amount": 1}])
	t._check(int(zpet.get("total", -1)) <= u_kovare,
		"sim.vendor: prodej krumpace krejcimu vynese %s (max smi byt %d)"
			% [str(zpet.get("total")), u_kovare])
	t._check(vendor.sell_price(bs, GOLD_ART, 1) == 0,
		"sim.vendor: zlato se neprodava (sell_price %d)" % vendor.sell_price(bs, GOLD_ART, 1))
	# Predmet, ktery vendor jen PRODAVA (retail 10, `value` 145): cena musi
	# vychazet z TABULKY, ne z `value` - jinak by cepice stala 276 gp (mereno).
	t._check(vendor.buy_price(krejci, LEATHER_CAP_ART, 1) == 10,
		"sim.vendor: cepice u krejciho stoji retail 10, ne z `value` 145 (namEReno %d)"
			% vendor.buy_price(krejci, LEATHER_CAP_ART, 1))

	# -- I) `sellable` je z batohu a bez zlata ----------------------------
	var i := _sestav(t)
	if i.is_empty():
		return
	vendor = i[0]
	bs = vendor.vendor_index("blacksmith")
	_pridej(i[2], i[3], DAGGER_ART, 3)
	_pridej(i[2], i[3], GOLD_ART, 50)
	var k_prodeji: Array = vendor.sellable(SERIAL, bs)
	var dyk: Dictionary = {}
	var ma_zlato: bool = false
	for radek in k_prodeji:
		if int(radek["item"]) == DAGGER_ART:
			dyk = radek
		if int(radek["item"]) == GOLD_ART:
			ma_zlato = true
	t._check(int(dyk.get("amount", -1)) == 3 and int(dyk.get("price", -1)) == BS_DAGGER_SELL
			and not ma_zlato,
		"sim.vendor: `sellable` da 3 dyky po %d a zlato NE (namEReno %s, zlato %s)"
			% [BS_DAGGER_SELL, str(dyk), str(ma_zlato)])

	# -- J) `gump_data` - data pro udalost `gump_open` --------------------
	var gump: Dictionary = vendor.gump_data(SERIAL, bs)
	t._check(str(gump.get("gump", "")) == "vendor"
			and int((gump.get("data", {}) as Dictionary).get("vendor", -1)) == bs
			and ((gump.get("data", {}) as Dictionary).get("buy", []) as Array).size() > 0
			and ((gump.get("data", {}) as Dictionary).get("sell", []) as Array).size() > 0,
		"sim.vendor: `gump_data` ma {gump:'vendor', data:{vendor, buy, sell}} (namEReno %s)" % str(gump))

	# -- K) determinismus: dva stejne behy = stejny hash ------------------
	var k1 := _sestav(t)
	var k2 := _sestav(t)
	if k1.is_empty() or k2.is_empty():
		return
	for par in [k1, k2]:
		_pridej(par[2], par[3], GOLD_ART, 100)
		par[0].buy(SERIAL, par[0].vendor_index("blacksmith"), [{"item": INGOT_ART, "amount": 2}])
	var hash1: String = HashScript.new().of_state([k1[0].state()])
	var hash2: String = HashScript.new().of_state([k2[0].state()])
	t._check(hash1 == hash2,
		"sim.vendor: dva stejne behy daji stejny hash stavu (%s vs %s)" % [hash1, hash2])
	k2[0].buy(SERIAL, k2[0].vendor_index("blacksmith"), [{"item": INGOT_ART, "amount": 1}])
	t._check(HashScript.new().of_state([k2[0].state()]) != hash1,
		"sim.vendor: jiny stav (o jeden nakup vic) ma JINY hash")

	# -- L) state/restore prenese sklad ----------------------------------
	var l1 := _sestav(t)
	var l2 := _sestav(t)
	if l1.is_empty() or l2.is_empty():
		return
	_pridej(l1[2], l1[3], GOLD_ART, 100)
	var lb: int = l1[0].vendor_index("blacksmith")
	l1[0].buy(SERIAL, lb, [{"item": INGOT_ART, "amount": 3}])
	l2[0].restore(l1[0].state())
	t._check(l2[0].stock_of(lb, "iron_ingot") == BS_INGOT_MAX - 3,
		"sim.vendor: `restore(state())` prenese sklad na %d (namEReno %d)"
			% [BS_INGOT_MAX - 3, l2[0].stock_of(lb, "iron_ingot")])

	# -- M) bez tiledata se fallback NEMERI (nula jako cena je lez) -------
	var m := _sestav(t, false)
	if m.is_empty():
		return
	vendor = m[0]
	krejci = vendor.vendor_index("tailor")
	t._check(vendor.sell_price(krejci, PICKAXE_ART, 1) == 0,
		"sim.vendor: bez tiledata je fallback cena 0 (namEReno %d)"
			% vendor.sell_price(krejci, PICKAXE_ART, 1))
	_pridej(m[2], m[3], PICKAXE_ART, 1)
	var bez: Dictionary = vendor.sell(SERIAL, krejci, [{"item": PICKAXE_ART, "amount": 1}])
	t._check(not bool(bez.get("ok", true)) and str(bez.get("reason", "")) == "not_for_sale"
			and _pocet(m[2], m[3], PICKAXE_ART) == 1,
		"sim.vendor: bez ceny se neprodava a predmet zustava (namEReno %s, kusu %d)"
			% [str(bez), _pocet(m[2], m[3], PICKAXE_ART)])

	# -- M2) ART z DAT (ne z hlavy) ----------------------------------------
	# `art_of_type` vznikl pri integraci (2026-10-10): sonda si nejdriv vymyslela
	# art ID krumpace (`0x0E86`) a obchod pak hlasil `not_sold`, i kdyz data byla
	# spravna. Kdo art potrebuje, at si ho vyzvedne tady.
	var m2 := _sestav(t, true, false)
	if not m2.is_empty():
		var v2 = m2[0]
		var bs2: int = v2.vendor_index("blacksmith")
		t._check(v2.art_of_type(bs2, "pickaxe") == PICKAXE_ART,
			"sim.vendor: art krumpace z dat je %d (ocekavano %d)"
				% [v2.art_of_type(bs2, "pickaxe"), PICKAXE_ART])
		t._check(v2.art_of_type(bs2, "iron_ingot") == INGOT_ART,
			"sim.vendor: art ingotu z dat je %d (ocekavano %d)"
				% [v2.art_of_type(bs2, "iron_ingot"), INGOT_ART])
		t._check(v2.art_of_type(bs2, "neexistujici_typ") == 0,
			"sim.vendor: neznamemu typu vraci art 0 (namEReno %d)"
				% v2.art_of_type(bs2, "neexistujici_typ"))

	# -- N) DOSAH na vendora (buy/sell) -----------------------------------
	# Bez znale pozice vendora se obchodovat NEDA - a je VIDET proc.
	var n := _sestav(t, true, false)
	if n.is_empty():
		return
	vendor = n[0]
	bs = vendor.vendor_index("blacksmith")
	_pridej(n[2], n[3], GOLD_ART, 100)
	_pridej(n[2], n[3], INGOT_ART, 1)     # pro kontrolu prodejni vetve nize
	var bez_pozice: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(not bool(bez_pozice.get("ok", true))
			and str(bez_pozice.get("reason", "")) == "no_vendor_pos"
			and _gold(n[2], n[3]) == 100,
		"sim.vendor: bez pozice vendora se neobchoduje (`no_vendor_pos`, namEReno %s)"
			% str(bez_pozice))
	t._check(vendor.pozice(bs) == null,
		"sim.vendor: neznala pozice je `null`, ne (0,0,0) (namEReno %s)" % str(vendor.pozice(bs)))
	# ⚠ POZOR: `_dosah` guard je v modulu 2x (nakup i prodej). Kontrola vyse
	# meri jen NAKUP - mutace prodejni vetve ("i neznama pozice hlasi too_far")
	# tim prochazela (namEReno 2026-10-10 pri zapisu vzoru do harnessu). Proto
	# se meri i PRODEJ: zlato musi zustat a predmet taky.
	var prodej_bez_pozice: Dictionary = vendor.sell(SERIAL, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(not bool(prodej_bez_pozice.get("ok", true))
			and str(prodej_bez_pozice.get("reason", "")) == "no_vendor_pos"
			and _pocet(n[2], n[3], INGOT_ART) == 1,
		"sim.vendor: bez pozice vendora se ani NEPRODAVA (`no_vendor_pos`, namEReno %s, kusu %d)"
			% [str(prodej_bez_pozice), _pocet(n[2], n[3], INGOT_ART)])
	t._check(vendor.nastav_pozici(bs, Vector3i(110, 100, 0)) and vendor.pozice(bs) == Vector3i(110, 100, 0),
		"sim.vendor: pozice vendora jde nastavit (namEReno %s)" % str(vendor.pozice(bs)))
	var daleko: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(not bool(daleko.get("ok", true)) and str(daleko.get("reason", "")) == "too_far"
			and _gold(n[2], n[3]) == 100,
		"sim.vendor: z 10 dlazdic se neobchoduje (`too_far`, namEReno %s, zlato %d)"
			% [str(daleko), _gold(n[2], n[3])])
	var do_dosahu: String = _texty(n[4])
	t._check(do_dosahu.contains("far") or do_dosahu.contains("not here"),
		"sim.vendor: duvod dosahu je VIDET v udalostech (namEReno '%s')" % do_dosahu)
	vendor.nastav_pozici(bs, Vector3i(102, 100, 0))
	var blizko: Dictionary = vendor.buy(SERIAL, bs, [{"item": INGOT_ART, "amount": 1}])
	t._check(bool(blizko.get("ok", false)) and _gold(n[2], n[3]) == 100 - BS_INGOT_BUY,
		"sim.vendor: ze 2 dlazdic se obchoduje (namEReno %s, zlato %d)"
			% [str(blizko), _gold(n[2], n[3])])
	t._check(not vendor.nastav_pozici(999, Vector3i(100, 100, 0)),
		"sim.vendor: pozice se neda nastavit neznamemu vendorovi")
