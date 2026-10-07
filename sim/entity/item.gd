extends RefCounted
# Predmet (granule `entity.item`, smlouva docs/04 §4.2, tvar dat §4.5).
#
# TVAR DAT je dany smlouvou. Dve veci v ni nesedi (hlasim, docs/ needituje
# agent - viz "Vady ZADANI" v HANDOFF.md):
#   * §4.2 u `entity.item` vyjmenovava `durability`/`max_durability`, ale
#     `quality` (ktery je v §4.5) tam nema - kod ma OBOJE,
#   * `provides` v `.forge/roadmap.json` ma `quality`, ale `max_durability` ne.
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

var serial: int = 0
var tile: int = 0
var hue: int = 0
var amount: int = 1
var parent: int = 0              # 0 = na zemi, jinak serial kontejneru/mobila
var layer: int = 0               # 0 = nenasazeny (vrstvy 0x00-0x1F, docs/05 §5.4)
var pos: Vector3i = Vector3i.ZERO  # plati JEN na zemi (parent == 0)
var flags: int = 0               # 0x01 blessed, 0x02 newbie, 0x04 locked, 0x08 insured
var durability: int = 0
var max_durability: int = 0
var quality: int = 0             # 0 = normal, 1 = exceptional
var props: Dictionary = {}       # AoS properties: {"damage_increase": 25, ...}


func _init(serial_value: int = 0, tile_value: int = 0, amount_value: int = 1) -> void:
	serial = serial_value
	tile = tile_value
	amount = amount_value


func is_on_ground() -> bool:
	# Na zemi je `parent` 0 a jen tam plati `pos` (docs/04 §4.5).
	return parent == 0


func pile_weight(unit_weight: int) -> int:
	# Vaha hromady = jednotkova vaha x mnozstvi (viz hlavicka).
	return unit_weight * amount


func same_pile(other) -> bool:
	# Kandidat na slouceni podle docs/05 §5.4: stejny `tile` + stejna `hue`.
	# Jestli je predmet stackovatelny, vi az `entity.container` z tiledata
	# (flag `Generic`); tady se to netvrdi. Prazdna hromada se neslucuje.
	return other != null and tile == other.tile and hue == other.hue and amount > 0 and other.amount > 0
