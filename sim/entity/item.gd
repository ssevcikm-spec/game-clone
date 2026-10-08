extends RefCounted
# Predmet (granule `entity.item`, smlouva docs/04 §4.2, tvar dat §4.5).
#
# TVAR DAT je dany smlouvou. STUPNICE KVALITY je ROZHODNUTA 2026-10-07 (11.
# session, uzivatel: "srovnat s UO"): `quality` = 0 Low (zpackany), 1 Normal,
# 2 Exceptional - merene v ServUO `Items/Internal/ItemInterfaces.cs:67-72`
# (`Low, Normal, Exceptional`) a `CraftItem.cs:1356` (exceptional = 2). Tentyz
# den se opravil docs/04 §4.2 (mel "0 normal, 1 exceptional" = posun o jedna
# a chybejici Low) i tests/cases/item.gd; vychozi hodnota je 1 = Normal.
# ZBYVA JEDNA NESHODA (hlasim, docs/ needituje agent): `provides` v
# `.forge/roadmap.json` ma `quality`, ale `max_durability` ne.
#
# INVARIANT "PRAVE JEDEN RODIC": predmet sam nevi, ve kterych kontejnerech je,
# takze ho NEDRZI tenhle soubor - drzi ho `entity.container` (`add` predmet
# nejdriv vyjme z predchoziho rodice, `remove` ho z rodice vyvaze). Vzor:
# ServUO `Server/Item.cs:3971` (`AddItem` vola `RemoveItem` na predchozim
# rodici, `:3999-4006`). `parent` je tu jen cislo (0 = na zemi).
#
# `tile` je ART ID predmetu (0x4000-0xFFFF); `docs/03` §3.4 to rika v tabulce
# artefaktů: „item id = art id". Bere ho tak `world.tiledata` (flags/weight/
# height/layer) i `render.textures`. Data (`data/items.json`, `data/recipes.json`)
# maji TILEDATA ID, takze kdo z nich predmet vyrabi, pricita `+0x4000` - stejne
# jako `world.walk` u statiku (namERena vada dvou id prostoru, 6. session).
#
# VAHA: `pile_weight(unit_weight)` = jednotkova vaha x mnozstvi - vzor ServUO
# `Server/Item.cs:3854` (`PileWeight = (int)ceil(Weight * Amount)`); jednotkovou
# vahu dava `world.tiledata.weight(tile)` (int, stones).
# ⚠ CO SE NEMODELUJE (namEReno 2026-10-07, otevrena vec): ServUO drzi vahu jako
# `double`, u chybejiciho udaje v tiledata (0 nebo 255) dosazuje 1
# (`Server/Item.cs:3806-3809`) a zlato si ji prebiji na 0.02 stones
# (`Scripts/Items/Consumables/Gold.cs:34`). Nase data maji u zlata 0 a prebijeni
# nemame - vaha zlata je tim 0, ne 0.02 stones (docs/05 §5.4). Patrí do
# rozhodnutí (vaha v setinach stones, nebo vlastnost predmetu), ne do dohadu.

# ⚠⚠ 20. session (2026-10-08) - `type` JE IDENTITA PREDMETU, ART JE JEJI PROJEV.
# Do teto session bylo identitou CISLO ARTU: `item.tile` rozhodovalo o vsem
# (role, kategorie, slucovani hromad) a `data/items.json` byla tabulka
# "art -> co to je". Jenze art neni to, co ta vec je:
#   * ruda ma CTYRI arty (velikost hromady; ServUO `Ore.cs:426` meni `ItemID`
#     `0x19B9 -> 0x19B8`) a devet kovu se pozna podle `hue`, ne podle artu,
#   * dvere maji art pro zavrene a otevrene (`world.doors`),
#   * jeden typ ma casto vic grafik (v datech 1277 typu s vic arty, 6213 artu).
# Proto plati:
#   * `type` (z `data/items.json`, napr. `iron_ore`) je IDENTITA - vsechny arty
#     tehoz jmena ji sdili, proto "vsechna ruda je ruda" NENI seznam v kódu,
#   * `role` a `category` jsou VLASTNOSTI TYPU (ctou se z typu, ne z artu),
#   * `tile` (art) zustava INDEX: kresleni, `tiledata` (vaha/flagy/vrstva)
#     a vsechno, co mluvi cislem artu, funguje dal,
#   * `hue` zustava to, cim se jedna vec od druhe LISI uvnitr typu (kov rudy,
#     barva latky) - proto se hromady slucuji podle `type` + `hue`.
# Data musi drzet: jeden typ = jedna role a jedna kategorie. Kdyz se to rozchazi,
# hlasi to generator (`gen-content.py`, kontrola typu) i `conflicts()` tady.

const ITEMS_PATH := "res://data/items.json"
const ITEM_OFFSET := 0x4000              # tiledata id -> art id (docs/03 §3.4)

static var _typ_podle_artu: Dictionary = {}     # art -> type
static var _role_podle_typu: Dictionary = {}    # type -> role (neprazdna)
static var _kat_podle_typu: Dictionary = {}     # type -> category
static var _jmeno_podle_typu: Dictionary = {}   # type -> jmeno pro hrace
static var _arty_podle_typu: Dictionary = {}    # type -> [art, ...]
static var _nacteno: bool = false
static var _rozpory: Array = []

var serial: int = 0
var tile: int = 0                # ART ID (0x4000-0xFFFF)
var type: String = ""            # IDENTITA (`iron_ore`); prazdna = data o artu nevi
var hue: int = 0
var amount: int = 1
var parent: int = 0              # 0 = na zemi, jinak serial kontejneru/mobila
var layer: int = 0               # 0 = nenasazeny (vrstvy 0x00-0x1F, docs/05 §5.4)
var pos: Vector3i = Vector3i.ZERO  # plati JEN na zemi (parent == 0)
var flags: int = 0               # 0x01 blessed, 0x02 newbie, 0x04 locked, 0x08 insured
var durability: int = 0
var max_durability: int = 0
var quality: int = 1             # 0 = low (zpackany), 1 = normal, 2 = exceptional
var props: Dictionary = {}       # AoS properties: {"damage_increase": 25, ...}


func _init(serial_value: int = 0, tile_value: int = 0, amount_value: int = 1) -> void:
	serial = serial_value
	tile = tile_value
	amount = amount_value
	# Typ se odvodi z artu, ale JE to vlastnost predmetu: kdo vi, co vyrabi
	# (napr. budouci loot nebo recept s jinou grafikou), muze ho prepsat.
	type = type_of(tile_value)


# -- identita: art -> typ -> role/kategorie (jedno misto pro cely projekt) ----

static func nacti_data() -> bool:
	# Nacte `data/items.json` JEDNOU pro cely proces. Vraci false, kdyz data
	# nejsou - pak je `type` prazdny a `same_pile` se vraci k porovnani artu
	# (a volajici to vidi pres `known()`; ticha nahrada by predstirala data).
	if _nacteno:
		return not _typ_podle_artu.is_empty()
	_nacteno = true
	if not FileAccess.file_exists(ITEMS_PATH):
		push_warning("sim.entity.item: chybi " + ITEMS_PATH + " - typy predmetu nejsou")
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not (parsed is Array):
		push_warning("sim.entity.item: " + ITEMS_PATH + " neni seznam")
		return false
	for rec in parsed:
		if not (rec is Dictionary) or not rec.has("tile"):
			continue
		var typ: String = str(rec.get("type", ""))
		if typ == "":
			continue                      # stara data bez typu - viz hlavicka
		var art: int = int(rec["tile"]) + ITEM_OFFSET
		_typ_podle_artu[art] = typ
		if not _arty_podle_typu.has(typ):
			_arty_podle_typu[typ] = []
			_jmeno_podle_typu[typ] = str(rec.get("name", typ))
		(_arty_podle_typu[typ] as Array).append(art)
		var role: String = str(rec.get("role", ""))
		if role != "":
			if _role_podle_typu.has(typ) and str(_role_podle_typu[typ]) != role:
				_rozpory.append("typ '%s' ma role '%s' i '%s'"
					% [typ, str(_role_podle_typu[typ]), role])
			_role_podle_typu[typ] = role
		var kat: String = str(rec.get("category", ""))
		if kat != "":
			if _kat_podle_typu.has(typ) and str(_kat_podle_typu[typ]) != kat:
				_rozpory.append("typ '%s' ma kategorie '%s' i '%s'"
					% [typ, str(_kat_podle_typu[typ]), kat])
			_kat_podle_typu[typ] = kat
	for typ in _arty_podle_typu.keys():
		(_arty_podle_typu[typ] as Array).sort()
	if not _rozpory.is_empty():
		push_warning("sim.entity.item: " + str(_rozpory.size())
			+ " rozporu typu v datech (viz conflicts())")
	return true


static func type_of(tile_hodnota: int) -> String:
	nacti_data()
	if _typ_podle_artu.has(tile_hodnota):
		return str(_typ_podle_artu[tile_hodnota])
	# Volajici mohl predat TILEDATA ID (data maji tiledata id, `Item.tile` je
	# art) - proste se zkusi i druhy prostor, ale ART je prvni (je to nas).
	if tile_hodnota < ITEM_OFFSET and _typ_podle_artu.has(tile_hodnota + ITEM_OFFSET):
		return str(_typ_podle_artu[tile_hodnota + ITEM_OFFSET])
	return ""


static func role_of(tile_hodnota: int) -> String:
	# ROLE SE CTE Z TYPU: kdyz ji ma kterykoli art typu, ma ji cely typ.
	return str(_role_podle_typu.get(type_of(tile_hodnota), ""))


static func category_of(tile_hodnota: int) -> String:
	return str(_kat_podle_typu.get(type_of(tile_hodnota), ""))


static func name_of(tile_hodnota: int) -> String:
	return str(_jmeno_podle_typu.get(type_of(tile_hodnota), ""))


static func arts_of(typ: String) -> Array:
	nacti_data()
	return (_arty_podle_typu.get(typ, []) as Array).duplicate()


static func known() -> bool:
	nacti_data()
	return not _typ_podle_artu.is_empty()


static func conflicts() -> Array:
	# Rozpory "jeden typ = jedna role/kategorie". Generator je hlasi ve svem
	# reportu; tohle je druha strana (kdo cte data, nesmi o nich mlcet).
	return _rozpory.duplicate()


func is_on_ground() -> bool:
	# Na zemi je `parent` 0 a jen tam plati `pos` (docs/04 §4.5).
	return parent == 0


func pile_weight(unit_weight: int) -> int:
	# Vaha hromady = jednotkova vaha x mnozstvi (viz hlavicka).
	return unit_weight * amount


func same_pile(other) -> bool:
	# Kandidat na slouceni podle docs/05 §5.4: STEJNA VEC (`type`) a stejna
	# barva (`hue`). ⚠ Do 20. session se porovnaval `tile` (art), takze se
	# hromady tehoz predmetu s jinou grafikou NESLILY - u rudy je to realne
	# (art se meni podle velikosti hromady, `Ore.cs:426`). Kdyz data o artu
	# nevi (`type` prazdny), porovnava se art jako driv - "nevim" nesmi
	# znamenat "nikdy neslucuj".
	# Jestli je predmet stackovatelny, vi az `entity.container` z tiledata
	# (flag `Generic`); tady se to netvrdi. Prazdna hromada se neslucuje.
	if other == null:
		return false
	var muj: String = type if type != "" else str(tile)
	var jeho: String = other.type if str(other.type) != "" else str(other.tile)
	return muj == jeho and hue == other.hue and amount > 0 and other.amount > 0
