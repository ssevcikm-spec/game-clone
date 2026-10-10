extends Control
# Obchodni gump (granule `ui.vendor_gump`; smlouva docs/04 §4.2, tok §4.6.5).
#
# CO TENHLE MODUL JE: seznam "co si koupit" a "co prodat", ktery dostane
# VSTUPEM z udalosti `gump_open` (`data.buy`, `data.sell`). Ceny, pocty a
# dostupnost pocita SIM - okno je jen zobrazuje (docs/05 §5.3) a kliknuti
# prelozi na POZADAVEK. Sam nic neodesila: `sim`/`render`/`Input` nezna a
# `Time`/`OS` nepouziva (`app/` si pozadavek vyzvedne, jako u `ui.craft_gump`).
#
# TVAR UDALOSTI je ze smlouvy (docs/04 §4.4): `{name:"gump_open", data:{gump,
# data}}`, takze seznamy jsou na `event.data.data.buy` / `.sell`. Radek ma
# `{item:int (ART ID), type:String, name:String, amount:int, price:int}` -
# `item` je to, co se vraci v `lines` (docs/04 §4.3).
#
# CO NEDELA (pojmenovane): neresi zlato ani sklad - to vi jen SIM; kdyz nakup
# nejde, vrati `{ok:false, reason:"gold"|"out_of_stock"}` a hrac to uvidi v
# zurnalu. Okno proto NESMI dovolit vybrat vic, nez je k dispozici (`amount`).

const SIRKA: float = 240.0
const VYSKA: float = 300.0
const RADEK_VYSKA: float = 22.0

var _buy: Array[Dictionary] = []
var _sell: Array[Dictionary] = []
var _vyber: Dictionary = {"buy": {}, "sell": {}}   # smer -> {art: mnozstvi}
var _smer: String = "buy"
var _vendor: int = -1
var _id: String = ""
var _pozadavek: Dictionary = {}
var _dirty: bool = true
var _box: VBoxContainer = null
var _prebaveni: int = 0


func _init() -> void:
	# Nove okno je ZAVRENE (Control je v Godotu viditelny ve vychozim stavu);
	# otevre ho az udalost `gump_open` - stejne jako `ui.craft_gump`.
	visible = false


func apply_event(event: Dictionary) -> bool:
	if str(event.get("name", "")) != "gump_open" or not (event.get("data") is Dictionary):
		return false
	var obal: Dictionary = event["data"]
	if str(obal.get("gump", "")) != "vendor":
		return false
	var obsah = obal.get("data", {})
	if not (obsah is Dictionary):
		return false
	nastav(int(obsah.get("vendor", -1)), str(obsah.get("id", "")),
		obsah.get("buy", []), obsah.get("sell", []))
	visible = true
	return true


func nastav(vendor: int, id: String, buy, sell) -> void:
	# Vstup ze SIM (jen zobrazujeme). Neznamy smer se vraci na "buy".
	_vendor = vendor
	_id = id
	_buy = _radky(buy)
	_sell = _radky(sell)
	_vyber = {"buy": {}, "sell": {}}
	if _smer != "sell":
		_smer = "buy"
	_dirty = true


func je_otevreny() -> bool:
	return visible


func smer() -> String:
	return _smer


func nastav_smer(smer: String) -> bool:
	if not (smer in ["buy", "sell"]):
		return false
	if smer != _smer:
		_smer = smer
		_dirty = true
	return true


func radky(smer: String) -> Array[Dictionary]:
	return (_buy if smer == "buy" else _sell).duplicate(true)


func pocet_buy() -> int:
	return _buy.size()


func pocet_sell() -> int:
	return _sell.size()


func prebaveni() -> int:
	return _prebaveni


func stiskni_radek(smer: String, item: int) -> bool:
	# Kliknuti na radek = pridat 1 ks; na maximu se mnozstvi vynuluje (cyklus).
	var radek := _radek(smer, item)
	if radek.is_empty():
		return false
	var maximum: int = int(radek.get("amount", 0))
	var ted: int = mnozstvi(smer, item)
	var novy: int = 0 if ted >= maximum else ted + 1
	return nastav_mnozstvi(smer, item, novy)


func nastav_mnozstvi(smer: String, item: int, amount: int) -> bool:
	# Okno NESMI dovolit vic, nez je k dispozici (stejne by to SIM odmitla).
	var radek := _radek(smer, item)
	if radek.is_empty() or not (smer in ["buy", "sell"]):
		return false
	var orezene: int = clampi(amount, 0, int(radek.get("amount", 0)))
	if orezene <= 0:
		(_vyber[smer] as Dictionary).erase(item)
	else:
		(_vyber[smer] as Dictionary)[item] = orezene
	_dirty = true
	return true


func mnozstvi(smer: String, item: int) -> int:
	var vyber: Dictionary = _vyber.get(smer, {})
	return int(vyber.get(item, 0))


func vybranych(smer: String) -> int:
	return (_vyber.get(smer, {}) as Dictionary).size()


func celkem(smer: String) -> int:
	# Soucet za vybrane radky (v SIM je cena linearni - zadne slevy za mnozstvi).
	var soucet: int = 0
	for radek in radky(smer):
		var art: int = int(radek.get("item", 0))
		soucet += mnozstvi(smer, art) * int(radek.get("price", 0))
	return soucet


func text_radku(radek: Dictionary, smer: String) -> String:
	# JEDNO misto, kde se text sklada (test ho cte odsud, ne z uzlu).
	var zaklad: String = "%s x%d  %d gp" % [str(radek.get("name", "")),
		int(radek.get("amount", 0)), int(radek.get("price", 0))]
	var vybrano: int = mnozstvi(smer, int(radek.get("item", 0)))
	return zaklad if vybrano <= 0 else zaklad + " -> %d" % vybrano


func text_vyberu(smer: String) -> String:
	var kusu: int = 0
	for c in (_vyber.get(smer, {}) as Dictionary).values():
		kusu += int(c)
	if kusu <= 0:
		return "(nothing selected)"
	return "%d items, %d gp" % [kusu, celkem(smer)]


func stiskni_potvrzeni(smer: String = "") -> bool:
	# Potvrzeni nakupu/prodeje: poskladá POZADAVEK (nikam ho neposila).
	# Prazdny vyber nic neposle a vraci `false` (nesmi vzniknout prazdny prikaz).
	var s: String = _smer if smer == "" else smer
	if not (s in ["buy", "sell"]) or vybranych(s) <= 0:
		return false
	var vyber: Dictionary = _vyber.get(s, {})
	var arty: Array = vyber.keys()
	arty.sort()
	var lines: Array = []
	for art in arty:
		lines.append({"item": int(art), "amount": int(vyber[art])})
	_pozadavek = {"t": "vendor", "action": s, "vendor": _vendor, "lines": lines}
	return true


func odeber_pozadavek() -> Dictionary:
	# `app/` si ji vyzvedne a posle jako Command; kdyz nic neni, vraci {}.
	var out: Dictionary = _pozadavek
	_pozadavek = {}
	return out


func flush() -> bool:
	if not _dirty:
		return false
	_dirty = false
	_prebaveni += 1
	var box: VBoxContainer = _ensure_box()
	# UVOLNENI JE OKAMZITE (`free()`), ne `queue_free()` - to uvolni az na konci
	# framu, takze by v okne zustaly stare radky (namEReno u `ui.craft_gump`).
	for child in box.get_children():
		if child is Button or child is Label:
			box.remove_child(child)
			child.free()
	var popis := Label.new()
	popis.text = "Buy" if _smer == "buy" else "Sell"
	box.add_child(popis)
	var seznam: Array[Dictionary] = radky(_smer)
	if seznam.is_empty():
		var prazdny := Label.new()
		prazdny.text = "(nothing to buy)" if _smer == "buy" else "(nothing to sell)"
		box.add_child(prazdny)
		return true
	for radek in seznam:
		var tlacitko := Button.new()
		tlacitko.text = text_radku(radek, _smer)
		tlacitko.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
		tlacitko.pressed.connect(stiskni_radek.bind(_smer, int(radek["item"])))
		box.add_child(tlacitko)
	var potvrzeni := Button.new()
	potvrzeni.name = "Potvrdit"
	potvrzeni.text = "Confirm: " + text_vyberu(_smer)
	potvrzeni.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
	potvrzeni.pressed.connect(stiskni_potvrzeni.bind(_smer))
	box.add_child(potvrzeni)
	return true


func _ensure_box() -> VBoxContainer:
	if _box == null:
		_box = VBoxContainer.new()
		_box.name = "Obchod"
		# VELIKOST JE POVINNA (stejna past jako u `ui.journal` a `ui.craft_gump`).
		_box.custom_minimum_size = Vector2(SIRKA, VYSKA)
		_box.size = Vector2(SIRKA, VYSKA)
		add_child(_box)
	return _box


func _process(_delta: float) -> void:
	flush()


func _radky(seznam) -> Array[Dictionary]:
	# Normalizace vstupu: `item` je ART ID, `amount` dostupne mnozstvi (>= 0),
	# `price` cena za kus. Co nema `item`, se zahodi - prazdny radek by v gumpu
	# vypadal jako nabidka, ktera neexistuje.
	var out: Array[Dictionary] = []
	if not (seznam is Array):
		return out
	for rec in seznam:
		if not (rec is Dictionary):
			continue
		var art: int = int(rec.get("item", 0))
		if art <= 0:
			continue
		out.append({"item": art, "type": str(rec.get("type", "")),
			"name": str(rec.get("name", "")), "amount": maxi(0, int(rec.get("amount", 0))),
			"price": int(rec.get("price", 0))})
	return out


func _radek(smer: String, item: int) -> Dictionary:
	for radek in radky(smer):
		if int(radek.get("item", 0)) == item:
			return radek
	return {}
