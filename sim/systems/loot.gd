extends RefCounted
# Loot z tela (granule `sim.loot`; smlouva docs/04 §4.2 a tok §4.6.7,
# pravidla docs/05 §5.4 a §5.16).
#
# ERA JE PRE-AoS `LootPack.Old*` (docs/05 §5.16: "Loot = pre-AoS `LootPack.Old*`
# + magic item chance"; `data/balance.json: era.loot = "aos"` je v rozporu
# s tim - viz "ODCHYLKA" nize).
#
# ODKUD CISLA (vsechno namEReno v `_src/servuo/Scripts/Misc/LootPack.cs`,
# nic vymysleneho):
#   * `OldPoor` = `Gold 1d25` + `Instruments 0.02` (`:421-422`),
#   * `OldMeager` = `Gold 5d10+25` + `Instruments 0.10` + 2x magic (`:424-431`),
#   * `OldAverage` = `Gold 10d10+50` + `Instruments 0.40` + 3x magic (`:433-441`),
#   * `OldRich` = `Gold 10d10+250` + `Instruments 1.00` + 3x magic (`:443-451`),
#   * `OldFilthyRich` = `Gold 2d125+400` + `Instruments 2.00` + 4x magic (`:453-462`),
#   * `OldUltraRich` = `Gold 5d100+500` + `Instruments 2.00` + 6x magic (`:464-475`),
#   * `OldSuperBoss` = `Gold 5d100+500` + `Instruments 2.00` + 10x magic (`:477-492`),
#   * sance v tabulce je PROCENTO x 100: `Chance = (int)(100 * chance)`
#     (`LootPackEntry` konstruktor, `:831`) a `entry.Chance > Utility.Random(10000)`
#     (`LootPack.Generate`, `:99`). 100.00 % = 10000 = vzdy.
#   * `maxProps` = 1 pro vsechny `Old*` (`LootPackEntry(true, Gold, 100.00, "1d25")`
#     vola konstruktor s `maxProps = 0`; magic itemy maji `1` - `:796-802`).
#     **V nasem klonu je `maxProps` jen ZAZNAMENANY UDAJ** (viz D4 nize): kdo
#     by ho pouzil, musi nejdriv mit `roll_magic_item` - dnes vraci `{}`.
#
# ⚠ ROZHODNUTI D4 (kontrakt M5, zadani): `roll_magic_item(level)` vraci **`{}`**
# a HLASI TO (`push_warning` + `message`). Duvod: magicke predmety v pre-AoS
# nejsou "atributy s cislem", ale pojmenovane urovne (`Ruin/Might/Force/Power/
# Vanq`, `WeaponEnums.cs:17-45`) a jejich tvurce (`BaseRunicTool.ApplyAttributesTo`,
# `LootPack.cs:700-760`) je rozsahly system, ktery nema data. Vymyslet si
# "magicky predmet" by znamenalo vyrobit obsah, ktery v datech neni - presne to
# zadani zakazuje. Kdo ho bude chtit, dostane sem data + jednu funkci.
#
# ⚠ ODCHYLKA OD SMLOUVY (hlasim, docs/ needituje agent): `docs/05 §5.16` rika
# "Loot = pre-AoS `LootPack.Old*`", ale `data/balance.json: era.loot` je
# `"aos"`. Tenhle modul se rozhoduje podle DATA (`era.loot`), ne podle vety
# v dokumentu: je-li `aos`, `fill_corpse` to rekne do udalosti
# (`era_source: "data"`) a POUZIJE `Old*` tabulku, protoze AoS tabulky
# (`AosPoor` v `LootPack.cs:300-340`) v nasich datech nejsou - ticha nahrada
# by byla horsi. Kdo bude chtit AoS loot, doda `Aos*` tabulku a klic zmeni.
#
# ZLATO JE PREDMET (`gold_coin`, kontrakt M5 §2): art z `data/vendors.json`
# `config.gold_art` (namEReno 2026-10-10: 20205 = 0x4EED, coz je PRESNE art
# `gold_coin` z `data/items.json`), ne z hlavy; kdyz data nejsou, pouzije se
# konstanta a `gold_art_source` to rekne.
#
# ZAVISLOSTI KONSTRUKTOREM (vzor `sim.vendor`): `container` (JEDINA instance
# sveta), `items` (`{serial: Item}`), `rng`, `events`, `serials`
# (`next_serial()` - v produkci `SimWorld`), `items_path`, `vendors_path`.
# Bez `container` se loot NIKAM neda - a `fill_corpse` to hlasi.

const ItemScript = preload("res://sim/entity/item.gd")
const RngScript = preload("res://core/rng.gd")

const ITEMS_PATH := "res://data/items.json"
const VENDORS_PATH := "res://data/vendors.json"
const BALANCE_PATH := "res://data/balance.json"
const ITEM_OFFSET := 0x4000            # data maji TILEDATA ID, `Item.tile` je ART
const GOLD_TYPE := "gold_coin"
const GOLD_ART_DEFAULT := 0x4EED       # 20205; viz hlavicka (z `config.gold_art`)
const CHANCE_SCALE := 100              # `Chance = (int)(100 * chance)` (`LootPack.cs:831`)
const GOLD_CHANCE := 10000             # 100.00 % = vzdy (`LootPack.cs:421`)

# Tabulka `LootPack.Old*` (`LootPack.cs:420-493`). Kazdy radek:
#   {kind:"gold"|"instrument"|"magic", gold:"XdY+Z", chance:int (proc. x 100),
#    max_props:int, min_intensity:int, max_intensity:int}
# Je to DATA V KODU jen proto, ze je zadna session nevlastni (`data/loot.json`
# v kontraktu M5 neni); kdo ji tam presune, zmeni `_load_packs`.
const PACKS: Dictionary = {
	"poor": [
		{"kind": "gold", "gold": "1d25", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 2, "max_props": 0},
	],
	"meager": [
		{"kind": "gold", "gold": "5d10+25", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 10, "max_props": 0},
		{"kind": "magic", "chance": 100, "max_props": 1, "min": 0, "max": 60},
		{"kind": "magic", "chance": 20, "max_props": 1, "min": 10, "max": 70},
	],
	"average": [
		{"kind": "gold", "gold": "10d10+50", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 40, "max_props": 0},
		{"kind": "magic", "chance": 500, "max_props": 1, "min": 20, "max": 80},
		{"kind": "magic", "chance": 200, "max_props": 1, "min": 30, "max": 90},
		{"kind": "magic", "chance": 50, "max_props": 1, "min": 40, "max": 100},
	],
	"rich": [
		{"kind": "gold", "gold": "10d10+250", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 100, "max_props": 1},
		{"kind": "magic", "chance": 2000, "max_props": 1, "min": 60, "max": 100},
		{"kind": "magic", "chance": 1000, "max_props": 1, "min": 65, "max": 100},
		{"kind": "magic", "chance": 100, "max_props": 1, "min": 70, "max": 100},
	],
	"filthyRich": [
		{"kind": "gold", "gold": "2d125+400", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 200, "max_props": 1},
		{"kind": "magic", "chance": 3300, "max_props": 1, "min": 50, "max": 100},
		{"kind": "magic", "chance": 3300, "max_props": 1, "min": 60, "max": 100},
		{"kind": "magic", "chance": 2000, "max_props": 1, "min": 70, "max": 100},
		{"kind": "magic", "chance": 500, "max_props": 1, "min": 80, "max": 100},
	],
	"ultraRich": [
		{"kind": "gold", "gold": "5d100+500", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 200, "max_props": 1},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 40, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 40, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 50, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 50, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 60, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 60, "max": 100},
	],
	"superBoss": [
		{"kind": "gold", "gold": "5d100+500", "chance": GOLD_CHANCE, "max_props": 0},
		{"kind": "instrument", "chance": 200, "max_props": 1},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 40, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 40, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 40, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 50, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 50, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 50, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 60, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 60, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 60, "max": 100},
		{"kind": "magic", "chance": 10000, "max_props": 1, "min": 70, "max": 100},
	],
}

# Aliasy: kontrakt M5 §3.4 pouziva v `monsters.json` `loot_pack: "poor"`;
# reference ma i `Old*` jmena. Obe musi znamenat TOTEZ, jinak by monstrum
# s "OldPoor" dostalo jiny loot nez s "poor".
const PACK_ALIASES: Dictionary = {
	"oldpoor": "poor", "poor": "poor",
	"oldmeager": "meager", "meager": "meager",
	"oldaverage": "average", "average": "average",
	"oldrich": "rich", "rich": "rich",
	"oldfilthyrich": "filthyRich", "filthyrich": "filthyRich",
	"oldultrarich": "ultraRich", "ultrarich": "ultraRich",
	"oldsuperboss": "superBoss", "superboss": "superBoss",
}

var _container = null
var _items = null
var _rng = null
var _events = null
var _serials = null

var _packy: Dictionary = {}
var _gold_art: int = GOLD_ART_DEFAULT
var _gold_art_source: String = "default-constant"
var _instrumenty: Array = []           # [{type, art}] z `data/items.json`
var _instrumenty_ok: bool = false
var _era: String = "pre-aos"
var _era_source: String = "vychozi"


func _init(container = null, items = null, rng = null, events = null, serials = null,
		items_path: String = ITEMS_PATH, vendors_path: String = VENDORS_PATH,
		balance_path: String = BALANCE_PATH) -> void:
	_container = container
	_items = items
	_rng = rng if rng != null else RngScript.new(0)
	_events = events
	_serials = serials
	_packy = PACKS.duplicate(true)
	_load_instruments(items_path)
	_load_gold_art(vendors_path)
	_load_era(balance_path)


# -- rozhrani podle smlouvy ------------------------------------------------

func fill_corpse(mob, corpse) -> Dictionary:
	# Naplni telo podle `loot_pack` MONSTRA (kontrakt M5 §2). `mob` je slovnik
	# z `data/monsters.json` (ne serial!) - proto se loot pack bere z dat
	# monstra, ne z registru; kdo ma mobil, posle `mob` i s nim.
	# Vraci `{ok, gold, items, pack}` (+ `gold_serial`, `magic`, `era_source`,
	# `reason`) - `items` je POCET vlozenych predmetu, `gold` mnozstvi zlata.
	var out: Dictionary = {"ok": false, "gold": 0, "items": 0, "pack": "",
		"gold_serial": 0, "magic": [], "era_source": _era_source, "reason": ""}
	if corpse == null:
		return _fail(out, "no_corpse")
	var pack: String = _pack_of(mob)
	if pack == "":
		return _fail(out, "no_pack")
	var radky = _packy.get(pack)
	if not (radky is Array):
		push_warning("sim.loot: loot_pack '%s' neni v tabulce" % pack)
		return _fail(out, "unknown_pack")
	if _container == null:
		push_warning("sim.loot: bez `container` se loot nema kam vlozit")
		return _fail(out, "no_container")
	out["ok"] = true
	out["pack"] = pack
	var majitel: int = int(corpse.serial) if corpse is Object else int(corpse)
	var vlozeno: int = 0
	for radek in radky:
		if not (radek is Dictionary):
			continue
		if not _hod(int(radek.get("chance", 0))):
			continue
		var kind: String = str(radek.get("kind", ""))
		if kind == "gold":
			var mnozstvi: int = _dice(str(radek.get("gold", "")))
			if mnozstvi <= 0:
				continue                     # "0 zlata" neni loot, ale chyba dat
			var zlato = _vytvor_zlato(mnozstvi, corpse)
			if zlato == null:
				continue
			out["gold"] = int(out["gold"]) + mnozstvi
			out["gold_serial"] = int(zlato.serial)
			vlozeno += 1
		elif kind == "instrument":
			var item = _vytvor_instrument()
			if item == null:
				continue
			if _vloz(majitel, item):
				vlozeno += 1
			else:
				out["reason"] = "corpse_full"
		elif kind == "magic":
			# D4: `roll_magic_item` vraci `{}` a hlasi to - sem se tedy NIKDY
			# nedostane vymysleny predmet, jen zaznam o tom, ze kraft chybi.
			var mag = roll_magic_item(int(radek.get("max", 0)))
			out["magic"].append({"chance": int(radek.get("chance", 0)),
				"max_props": int(radek.get("max_props", 0)),
				"min": int(radek.get("min", 0)), "max": int(radek.get("max", 0)),
				"resolved": not mag.is_empty()})
	out["items"] = vlozeno
	return out


func roll_magic_item(level: int) -> Dictionary:
	# ROZHODNUTI D4 (viz hlavicka): vracime PRAZDNY slovnik a HLASIME to.
	# Prazdno tady NENI "nic se nestalo" - je to "tuhle cestu nemame" a kazdy
	# volajici to dostane slovem (push_warning i `message`).
	push_warning("sim.loot.roll_magic_item: magicke predmety nejsou (D4) - "
		+ "chybi data i `BaseRunicTool`, level=" + str(level))
	_message("No magic items are generated (no data for them).")
	return {}


func pack_of(mob) -> String:
	return _pack_of(mob)


func packs() -> Array:
	var out: Array = _packy.keys()
	out.sort()
	return out


func gold_art() -> int:
	return _gold_art


func gold_art_source() -> String:
	return _gold_art_source


func era() -> String:
	return _era


func era_source() -> String:
	return _era_source


func instruments_loaded() -> bool:
	return _instrumenty_ok


# -- vnitrni: loot pack ----------------------------------------------------

func _pack_of(mob) -> String:
	# `loot_pack` z monstra (kontrakt M5 §3.4); chybejici = "poor" (vetsina
	# normalnich monster v `research/06` ma prave `OldPoor`). Kdo ho nema ani
	# v datech, dostane `poor` a `pack` to rekne; jinak by pulka monster
	# nemela loot.
	#
	# VSTUP MUZE BYT DVOJI (a oboji je platne):
	#   * SLOVNIK z `data/monsters.json` (testy a prime volani),
	#   * MOBIL ve svete - jeho data monstra jsou v `mob.ai["data"]`, protoze
	#     `entity.mobile` pole `loot_pack` NEMA a `Object.set()` na
	#     nedeklarovanou vlastnost nic neudela (namEReno 2026-10-11; zapisuje
	#     `sim.spawn`). Kdyby se tu cetlo `mob.get("loot_pack")`, dostal by
	#     KAZDY mobil "poor" a loot by tise lhal.
	if mob == null:
		return ""
	var pack: String = ""
	if mob is Dictionary:
		pack = str((mob as Dictionary).get("loot_pack", ""))
	else:
		var ai = mob.get("ai")
		if ai is Dictionary:
			var data = (ai as Dictionary).get("data")
			if data is Dictionary:
				pack = str((data as Dictionary).get("loot_pack", ""))
		if pack == "":
			pack = str(mob.get("loot_pack"))
	if pack == "":
		pack = "poor"
	return str(PACK_ALIASES.get(pack.to_lower(), pack))


func _hod(chance: int) -> bool:
	# `entry.Chance > Utility.Random(10000)` (`LootPack.cs:99`) - `chance` je
	# PROCENTO x 100 (viz hlavicka).
	if chance <= 0:
		return false
	if chance >= 10000:
		return true
	return _rng.next_u32() % 10000 < chance


func _dice(vyraz: String) -> int:
	# `LootPackDice` (`LootPack.cs:1088-1110`): "XdY+Z" = Z + X hodů 1..Y.
	# Neznamy tvar vraci 0 a HLASI se to (ticha nula by vypadala jako "bez zlata").
	var text: String = vyraz.strip_edges().to_lower()
	var d: int = text.find("d")
	if d <= 0:
		push_warning("sim.loot: kostkovy vyraz '%s' nema 'd'" % vyraz)
		return 0
	var pocet: int = int(text.substr(0, d))
	var zbytek: String = text.substr(d + 1)
	var bonus: int = 0
	var plus: int = zbytek.find("+")
	if plus >= 0:
		bonus = int(zbytek.substr(plus + 1))
		zbytek = zbytek.substr(0, plus)
	var steny: int = int(zbytek)
	if pocet < 0 or steny <= 0:
		push_warning("sim.loot: kostkovy vyraz '%s' je neplatny" % vyraz)
		return 0
	var soucet: int = bonus
	for _i in pocet:
		soucet += _rng.range_i(1, steny)
	return soucet


# -- vnitrni: predmety -----------------------------------------------------

func _vytvor_zlato(mnozstvi: int, corpse):
	# Zlato je PREDMET `gold_coin` (kontrakt M5 §2); do tela se vklada jako
	# kazdy jiny predmet (`entity.container`).
	var zlato = ItemScript.new(_next_serial(), _gold_art, mnozstvi)
	zlato.type = GOLD_TYPE
	if zlato.tile <= 0:
		push_warning("sim.loot: gold_art je 0 - zlato by nemelo art")
	var majitel: int = int(corpse.serial) if corpse is Object else int(corpse)
	if not _vloz(majitel, zlato):
		return null
	return zlato


func _vytvor_instrument():
	# Nahodny nastroj z `Instruments` (`LootPack.cs:130`). V nasich datech
	# (`data/items.json`) musi mit kategorii/typ hudebniho nastroje; kdyz tam
	# zadny neni, vracime null a v `fill_corpse` to je videt v `reason`u.
	if not _instrumenty_ok or _instrumenty.is_empty():
		push_warning("sim.loot: v datech neni zadny hudebni nastroj (Instruments)")
		return null
	var i: int = _rng.range_i(0, _instrumenty.size() - 1)
	var rec: Dictionary = _instrumenty[i]
	return ItemScript.new(_next_serial(), int(rec["art"]), 1)


func _vloz(kontejner: int, item) -> bool:
	# Vlozeni do tela: `entity.container` sam vyjme predmet z predchoziho
	# rodice a vraci `bool` (invariant "prave jeden rodic").
	if _container == null or kontejner <= 0:
		return false
	var ok: bool = _container.add(kontejner, item)
	if ok and _items is Dictionary:
		(_items as Dictionary)[int(item.serial)] = item
	if not ok:
		push_warning("sim.loot: predmet %d se do tela %d nevesel" % [int(item.serial), kontejner])
	return ok


func _next_serial() -> int:
	if _serials == null:
		return 0
	if _serials is Object and _serials.has_method("next_serial"):
		return int(_serials.next_serial())
	if _serials is Object and _serials.has_method("next"):
		return int(_serials.next())
	return 0


# -- vnitrni: data ---------------------------------------------------------

func _load_instruments(path: String) -> void:
	# Hudebni nastoje z `data/items.json`: hleda se podle `role`/`category`
	# (v datech je "instrument" nema - namEReno 2026-10-10: 0 zaznamu), proto
	# se pozna i podle jmena TYPU. Kdo data nema, dostane `_instrumenty_ok`
	# false a `fill_corpse` to hlasi.
	var d = _read_json(path)
	if not (d is Array):
		push_warning("sim.loot: chybi " + path + " - hudebni nastoje nejsou")
		return
	for rec in d:
		if not (rec is Dictionary):
			continue
		var r: Dictionary = rec
		var role: String = str(r.get("role", ""))
		var kat: String = str(r.get("category", ""))
		var typ: String = str(r.get("type", ""))
		var je: bool = role.contains("instrument") or kat.contains("instrument") \
			or typ.contains("drum") or typ.contains("harp") or typ.contains("lute") \
			or typ.contains("flute") or typ.contains("tambourine") \
			or typ.contains("belled") or typ.contains("standing_harp")
		if not je:
			continue
		var art: int = int(r.get("tile", 0)) + ITEM_OFFSET
		if art <= 0:
			continue
		_instrumenty.append({"type": typ, "art": art})
	_instrumenty_ok = not _instrumenty.is_empty()
	if not _instrumenty_ok:
		push_warning("sim.loot: " + path + " nema hudebni nastroj")


func _load_gold_art(path: String) -> void:
	# Art zlata z `data/vendors.json: config.gold_art` (jedno misto, kde je
	# dnes v datech; kontrakt M5 §2 to zadava).
	var d = _read_json(path)
	if not (d is Dictionary):
		return
	var cfg = (d as Dictionary).get("config")
	if cfg is Dictionary and int((cfg as Dictionary).get("gold_art", 0)) > 0:
		_gold_art = int((cfg as Dictionary)["gold_art"])
		_gold_art_source = "data:" + path


func _load_era(path: String) -> void:
	# `era.loot` (`docs/05 §5.16`). Chybejici klic = vychozi "pre-aos"
	# (`LootPack.Old*`), protoze ty tabulky mame.
	var d = _read_json(path)
	if not (d is Dictionary):
		return
	var era = (d as Dictionary).get("era")
	if era is Dictionary and (era as Dictionary).has("loot"):
		_era = str((era as Dictionary)["loot"])
		_era_source = "data:" + path


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# -- vnitrni: zaklad -------------------------------------------------------

func _fail(out: Dictionary, reason: String) -> Dictionary:
	# "Nic se nestalo" musi byt VIDET (docs/04 §4.4).
	out["ok"] = false
	out["reason"] = reason
	if reason == "no_container":
		_message("There is nowhere to put the loot.")
	return out


func _message(text: String) -> void:
	if _events != null:
		_events.push("message", {"text": text, "kind": "loot"})
