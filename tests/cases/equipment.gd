extends RefCounted
# entity.equipment - vybava a vrstvy (granule `entity.equipment`, docs/04 §4.2,
# vrstvy docs/11 §11.7 a research/01 §2.6).
#
# Test meri CHOVANI s konkretnimi hodnotami (docs/09 §9.5), ne pritomnost metody:
#   * PRIJIMACI KRITERIUM ROADMAPY: `equip` STITU pri nasazene DVOURUCNE ZBRANI
#     vraci `{ok:false}` (obojí je vrstva 2 = `Layer.TwoHanded`),
#   * dve veci na stejne vrstve nejdou (`occupied`; `Item.cs:1631`),
#   * jednorucni + dvourucni zbran = `two_handed` (`BaseWeapon.cs:998-1016`),
#   * `unequip` vraci serial slozeneho predmetu a uvolni vrstvu; predmet jde do
#     batohu (invariant "prave jeden rodic" - z kontejneru ho `equip` vyjme),
#   * vaha = soucet nasazenych predmetu x mnozstvi; bonus = soucet `props[key]`
#     NASAZENYCH predmetu (predmet v batohu se nepocita),
#   * kdyz neni `tiledata`/`items`, vaha a bonus se NEMERI (`measured()` false)
#     a `total_weight` vraci nulu - nula, ktera neni merena, musi byt videt.
#
# Vrstvy a vahy bere test ze STUBU (`StubTiledata`), aby nezavisel na
# `assets/uo` (v CI nejsou); ART ID jsou ale REALNA z `data/items.json`
# (+0x4000, docs/03 §3.4), takze se meri i to, ze `category` ze dat u stitu
# opravdu je `shield` a u zbrane `weapon` (na tom stoji pravidlo o vrstve 2).
#
# Cesta k souboru je VSTUP: `-- --equipment-script=<cesta>`.

const Lib = preload("res://tests/lib.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")

const EQUIPMENT_SCRIPT := "res://sim/entity/equipment.gd"
const ITEM_SCRIPT := "res://sim/entity/item.gd"
const CONTAINER_SCRIPT := "res://sim/entity/container.gd"

# ART ID = tile z `data/items.json` + 0x4000 (docs/03 §3.4 "item id = art id")
const KITE_SHIELD := 7028 + 0x4000      # category `shield`, tiledata vrstva 2
const TWO_HANDED_AXE := 5186 + 0x4000   # category `weapon`, tiledata vrstva 2
const LONGSWORD := 3936 + 0x4000        # category `weapon`, tiledata vrstva 1
const KRYSS := 5120 + 0x4000            # category `weapon`, tiledata vrstva 1
const TORCH := 2578 + 0x4000            # category `light`,  tiledata vrstva 2

const LAYER_ONE := 0x01
const LAYER_TWO := 0x02
const LAYER_SHOES := 0x03
const LAYER_BANK := 0x1D                # mimo `Layer.LastUserValid` (0x18)

const MOB := 0x40000007
const MOB2 := 0x40000008
const PACK := 0x40000064


class StubTiledata:
	# Nahrazuje `world.tiledata` (vrstvy a vahy podle art id). `flags` vraci 0
	# (nic neni stackable), aby kontejner hromady neslucoval.
	var _vrstvy: Dictionary = {}
	var _vahy: Dictionary = {}

	func _init(vrstvy: Dictionary, vahy: Dictionary) -> void:
		_vrstvy = vrstvy
		_vahy = vahy

	func layer(tile: int) -> int:
		return int(_vrstvy.get(tile, 0))

	func weight(tile: int) -> int:
		return int(_vahy.get(tile, 0))

	func flags(_tile: int) -> int:
		return 0


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _serialy(a) -> Array:
	var out: Array = []
	for x in a:
		out.append(int(x))
	return out


func _predmet(item_script, items: Dictionary, serial: int, tile: int,
		amount: int = 1, props: Dictionary = {}):
	var it = item_script.new(serial, tile, amount)
	it.props = props
	items[serial] = it
	return it


func run(t) -> void:
	var cesta: String = _arg("equipment-script", EQUIPMENT_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.entity.equipment NENI HOTOVA: " + cesta + " chybi nebo se neparsuje")
		return
	var item_script = Lib.script_at(_arg("item-script", ITEM_SCRIPT))
	var cont_script = Lib.script_at(_arg("container-script", CONTAINER_SCRIPT))
	if item_script == null or cont_script == null:
		t._pending("sim.entity.equipment NEMEREN: %s nebo %s nejde nacist"
			% [ITEM_SCRIPT, CONTAINER_SCRIPT])
		return
	# API musi byt CELE (chybejici metoda by case shodila s 0 kontrolami a
	# mutace by prosla jako slepa).
	var sonda = script.new()
	var chybi: Array[String] = []
	for metoda in ["equip", "unequip", "at_layer", "total_weight", "bonus",
			"measured", "unknown_equipped"]:
		if not sonda.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "sim.entity.equipment: chybi metody %s - case se neda merit" % str(chybi))
		return

	var tiledata = StubTiledata.new(
		{KITE_SHIELD: LAYER_TWO, TWO_HANDED_AXE: LAYER_TWO, TORCH: LAYER_TWO,
			LONGSWORD: LAYER_ONE, KRYSS: LAYER_ONE},
		{KITE_SHIELD: 5, TWO_HANDED_AXE: 8, TORCH: 3, LONGSWORD: 7, KRYSS: 2})
	var reg = RegistryScript.new()
	var mob = MobileScript.new(MOB, 400, Vector3i(100, 100, 0))
	mob.backpack = PACK
	reg.register(mob)
	var container = cont_script.new(tiledata)
	var items: Dictionary = {}
	var e = script.new(reg, container, items, tiledata)

	# A) CHYBEJICI ZAVISLOST JE VIDET: bez tiledata/items se vaha a bonus NEMERI
	var bez = script.new()
	t._check(bez.measured() == false and bez.total_weight(MOB) == 0
			and bez.bonus(MOB, "damage_increase") == 0,
		"sim.entity.equipment: bez tiledata/items se vaha a bonus NEMERI (measured false, nula)")
	t._check(e.measured() == true,
		"sim.entity.equipment: s tiledata i items se vaha MERI (measured true)")

	# B) DATA: kategorie z `data/items.json` rozhoduje o vrstve 2
	var mec = _predmet(item_script, items, 1, LONGSWORD, 1, {"damage_increase": 25})
	var sekera = _predmet(item_script, items, 2, TWO_HANDED_AXE, 1)
	var stit = _predmet(item_script, items, 3, KITE_SHIELD, 1, {"defense_chance_increase": 15})
	var kryss = _predmet(item_script, items, 4, KRYSS, 1)
	var louc = _predmet(item_script, items, 5, TORCH, 1)
	t._check(item_script.category_of(KITE_SHIELD) == "shield"
			and stit.type == "kite_shield",
		"sim.entity.equipment: stit je z dat `shield` (typ '%s', kategorie '%s')"
			% [stit.type, item_script.category_of(KITE_SHIELD)])
	t._check(item_script.category_of(TWO_HANDED_AXE) == "weapon"
			and item_script.category_of(LONGSWORD) == "weapon",
		"sim.entity.equipment: zbrane jsou z dat `weapon` (dvourucni '%s', jednorucni '%s')"
			% [item_script.category_of(TWO_HANDED_AXE), item_script.category_of(LONGSWORD)])

	# C) NASAZENI jednorucniho mece (vrstva z tiledata)
	var v1: Dictionary = e.equip(MOB, mec)
	t._check(v1.get("ok", false) and e.at_layer(MOB, LAYER_ONE) == 1,
		"sim.entity.equipment: mec se nasadi na vrstvu 1 (vyslo %s, at_layer %d)"
			% [str(v1), e.at_layer(MOB, LAYER_ONE)])
	t._check(mec.parent == MOB and mec.layer == LAYER_ONE,
		"sim.entity.equipment: nasazeny predmet ma parent = mobil a svoji vrstvu (parent %d, layer %d)"
			% [mec.parent, mec.layer])
	var v_idem: Dictionary = e.equip(MOB, mec)
	t._check(v_idem.get("ok", false) and v_idem.get("reason", "") == "already_equipped"
			and e.at_layer(MOB, LAYER_ONE) == 1,
		"sim.entity.equipment: opakovane nasazeni TEHOZ predmetu stav nemeni (vyslo %s)"
			% str(v_idem))

	# D) OBSAZENA VRSTVA: druha vec na vrstvu 1
	var v2: Dictionary = e.equip(MOB, kryss)
	t._check(not v2.get("ok", true) and v2.get("reason", "") == "occupied",
		"sim.entity.equipment: druha vec na obsazenou vrstvu vraci {ok:false, reason:'occupied'} (vyslo %s)"
			% str(v2))
	t._check(e.at_layer(MOB, LAYER_ONE) == 1 and kryss.parent == 0 and kryss.layer == 0,
		"sim.entity.equipment: neuspesny equip stav NEZMENI (at_layer %d, parent %d, layer %d)"
			% [e.at_layer(MOB, LAYER_ONE), kryss.parent, kryss.layer])

	# E) JEDNORUCNI + DVOURUCNI = two_handed (`BaseWeapon.cs:998-1016`)
	var v3: Dictionary = e.equip(MOB, sekera)
	t._check(not v3.get("ok", true) and v3.get("reason", "") == "two_handed",
		"sim.entity.equipment: dvourucni zbran k nasazene jednorucni vraci {ok:false, reason:'two_handed'} (vyslo %s)"
			% str(v3))

	# F) SLOZENI: unequip vraci serial a predmet jde do batohu
	var slozeno: int = e.unequip(MOB, LAYER_ONE)
	t._check(slozeno == 1 and e.at_layer(MOB, LAYER_ONE) == 0 and mec.layer == 0,
		"sim.entity.equipment: unequip vraci serial slozeneho predmetu a uvolni vrstvu (vyslo %d)"
			% slozeno)
	t._check(mec.parent == PACK and _serialy(container.contents(PACK)).has(1),
		"sim.entity.equipment: slozeny predmet jde do batohu (parent %d, obsah %s)"
			% [mec.parent, str(container.contents(PACK))])
	t._check(e.unequip(MOB, LAYER_ONE) == 0,
		"sim.entity.equipment: unequip prazdne vrstvy vraci 0")

	# G) DVOURUCNA ZBRAN se nasadi na vrstvu 2
	var v4: Dictionary = e.equip(MOB, sekera)
	t._check(v4.get("ok", false) and e.at_layer(MOB, LAYER_TWO) == 2 and sekera.layer == LAYER_TWO,
		"sim.entity.equipment: dvourucni zbran se nasadi na vrstvu 2 (vyslo %s, at_layer %d)"
			% [str(v4), e.at_layer(MOB, LAYER_TWO)])

	# H) PRIJIMACI KRITERIUM: STIT pri dvourucne zbrani
	var v5: Dictionary = e.equip(MOB, stit)
	t._check(not v5.get("ok", true) and v5.get("reason", "") == "two_handed",
		"sim.entity.equipment: STIT pri dvourucne zbrani vraci {ok:false, reason:'two_handed'} (vyslo %s)"
			% str(v5))
	t._check(stit.parent == 0 and stit.layer == 0 and e.at_layer(MOB, LAYER_TWO) == 2,
		"sim.entity.equipment: neuspesny equip stitu stav NEZMENI (parent %d, layer %d, at_layer %d)"
			% [stit.parent, stit.layer, e.at_layer(MOB, LAYER_TWO)])

	# I) Po uvolneni vrstvy 2 se stit nasadi; nova zbran na stit vraci occupied
	e.unequip(MOB, LAYER_TWO)
	var v6: Dictionary = e.equip(MOB, stit)
	t._check(v6.get("ok", false) and stit.layer == LAYER_TWO and e.at_layer(MOB, LAYER_TWO) == 3,
		"sim.entity.equipment: po uvolneni vrstvy 2 se stit nasadi (vyslo %s, at_layer %d)"
			% [str(v6), e.at_layer(MOB, LAYER_TWO)])
	var v7: Dictionary = e.equip(MOB, sekera)
	t._check(not v7.get("ok", true) and v7.get("reason", "") == "occupied",
		"sim.entity.equipment: nova dvourucni zbran na nasazeny stit vraci occupied (vyslo %s)"
			% str(v7))
	var v8: Dictionary = e.equip(MOB, louc)
	t._check(not v8.get("ok", true) and v8.get("reason", "") == "occupied",
		"sim.entity.equipment: svetlo (louc) na obsazenou vrstvu vraci occupied (vyslo %s)"
			% str(v8))

	# J) VAHA a BONUS nasazenych predmetu (mec 7 + stit 5)
	e.unequip(MOB, LAYER_TWO)
	e.equip(MOB, mec)
	e.equip(MOB, stit)
	t._check(e.total_weight(MOB) == 12,
		"sim.entity.equipment: vaha nasazeneho mece a stitu je 12 stones (7 + 5, namEReno %d)"
			% e.total_weight(MOB))
	mec.amount = 3
	t._check(e.total_weight(MOB) == 26,
		"sim.entity.equipment: vaha se pocita z MNOZSTVI (3 x 7 + 5 = 26, namEReno %d)"
			% e.total_weight(MOB))
	mec.amount = 1
	t._check(e.bonus(MOB, "damage_increase") == 25
			and e.bonus(MOB, "defense_chance_increase") == 15,
		"sim.entity.equipment: bonus secte props nasazenych predmetu (DI %d, DCI %d)"
			% [e.bonus(MOB, "damage_increase"), e.bonus(MOB, "defense_chance_increase")])
	t._check(e.bonus(MOB, "luck") == 0 and e.bonus(MOB, "") == 0,
		"sim.entity.equipment: neznamy i prazdny klic vraci 0 (zadna vymyslena hodnota)")
	kryss.props = {"damage_increase": 100}
	container.add(PACK, kryss)
	t._check(e.bonus(MOB, "damage_increase") == 25,
		"sim.entity.equipment: predmet v batohu se do bonusu NEPOCITA (namEReno %d)"
			% e.bonus(MOB, "damage_increase"))

	# K) INVARIANT "PRAVE JEDEN RODIC": nasazeny predmet opusti batoh
	var mec2 = _predmet(item_script, items, 7, LONGSWORD, 1)
	container.add(PACK, mec2)
	t._check(_serialy(container.contents(PACK)).has(7),
		"sim.entity.equipment: predmet je pred nasazenim v batohu (obsah %s)"
			% str(container.contents(PACK)))
	e.unequip(MOB, LAYER_ONE)
	var v9: Dictionary = e.equip(MOB, mec2)
	t._check(v9.get("ok", false) and mec2.parent == MOB and int(mec2.amount) == 1
			and not _serialy(container.contents(PACK)).has(7),
		"sim.entity.equipment: nasazeny predmet opusti batoh a neztrati mnozstvi (vyslo %s, parent %d, amount %d, obsah %s)"
			% [str(v9), mec2.parent, int(mec2.amount), str(container.contents(PACK))])

	# L) VRSTVA Z PREDMETU (kdyz tiledata neni) a odmitnute vrstvy
	var bez_tiledata = script.new(reg, container, items, null)
	var boty = _predmet(item_script, items, 8, LONGSWORD, 1)
	boty.layer = LAYER_SHOES
	var v10: Dictionary = bez_tiledata.equip(MOB, boty)
	t._check(v10.get("ok", false) and e.at_layer(MOB, LAYER_SHOES) == 8,
		"sim.entity.equipment: vrstva jde i z `item.layer`, kdyz tiledata neni (vyslo %s)"
			% str(v10))
	var bez_vrstvy = _predmet(item_script, items, 9, LONGSWORD, 1)
	var v11: Dictionary = bez_tiledata.equip(MOB, bez_vrstvy)
	t._check(not v11.get("ok", true) and v11.get("reason", "") == "no_layer",
		"sim.entity.equipment: predmet bez vrstvy a bez tiledata vraci {ok:false, reason:'no_layer'} (vyslo %s)"
			% str(v11))
	var banka = _predmet(item_script, items, 10, LONGSWORD, 1)
	banka.layer = LAYER_BANK
	var v12: Dictionary = bez_tiledata.equip(MOB, banka)
	t._check(not v12.get("ok", true) and v12.get("reason", "") == "invalid_layer",
		"sim.entity.equipment: vrstva 0x1D (banka) vraci {ok:false, reason:'invalid_layer'} (vyslo %s)"
			% str(v12))

	# M) DUVODY: zadny pad, kazdy duvod je videt
	t._check(e.equip(999, mec).get("reason", "") == "no_mobile",
		"sim.entity.equipment: neznameho mobila vraci no_mobile")
	t._check(e.equip(MOB, null).get("reason", "") == "no_item",
		"sim.entity.equipment: null predmet vraci no_item")
	t._check(e.equip(MOB, {"tile": 1}).get("reason", "") == "no_item",
		"sim.entity.equipment: slovnik misto predmetu vraci no_item (ne pad)")
	var bezser = _predmet(item_script, items, 0, LONGSWORD, 1)
	t._check(e.equip(MOB, bezser).get("reason", "") == "no_serial",
		"sim.entity.equipment: predmet bez serialu vraci no_serial")

	# N) CHYBEJICI PREDMET v `items` (nula neni merena nula)
	var reg2 = RegistryScript.new()
	var mob2 = MobileScript.new(MOB2, 400, Vector3i(100, 100, 0))
	reg2.register(mob2)
	var items2: Dictionary = {}
	var e2 = script.new(reg2, cont_script.new(tiledata), items2, tiledata)
	var ztraceny = _predmet(item_script, items2, 21, LONGSWORD, 1)
	e2.equip(MOB2, ztraceny)
	t._check(e2.unknown_equipped(MOB2) == 0 and e2.total_weight(MOB2) == 7,
		"sim.entity.equipment: dokud je predmet v `items`, vaha je 7 (namEReno %d)" % e2.total_weight(MOB2))
	items2.erase(21)
	t._check(e2.unknown_equipped(MOB2) == 1 and e2.total_weight(MOB2) == 0,
		"sim.entity.equipment: predmet, ktery v `items` neni, se HLASI (unknown_equipped %d) a vaha je 0"
			% e2.unknown_equipped(MOB2))
