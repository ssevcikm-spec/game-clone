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
# Vyska listy s tlacitkem "Close" nad seznamem (ZADANI-28, B4). Tlacitko je
# NAD boxem, ne v nem: `tests/cases/vendor_gump.gd` meri, ze box ma presne
# 3 uzly (popis + radek + potvrzeni) - a hlavne se tim nezavira zadny radek.
const HEADER: float = 24.0
const TLACITKO_SIRKA: float = 70.0
const TLACITKO_VYSKA: float = 20.0
const TEXT_ZAVRIT := "Close"

# Text přepínače směru (session D): hráč musí z okna poznat, že se dá i prodávat.
# Text je ZDE (ne v datech), protože je to popis TÉTO komponenty, ne obsah hry;
# kdyby se měnil, mění se s `nastav_smer`, na kterém visí.
const PREPINAC_BUY := "Buy  -  klikni = prodej (Sell)"
const PREPINAC_SELL := "Sell  -  klikni = nakup (Buy)"

var _buy: Array[Dictionary] = []
var _sell: Array[Dictionary] = []
var _vyber: Dictionary = {"buy": {}, "sell": {}}   # smer -> {art: mnozstvi}
var _smer: String = "buy"
var _vendor: int = -1
var _id: String = ""
var _pozadavek: Dictionary = {}
var _dirty: bool = true
var _box: VBoxContainer = null
var _close: Button = null
var _prebaveni: int = 0


func _init() -> void:
	# Nove okno je ZAVRENE (Control je v Godotu viditelny ve vychozim stavu);
	# otevre ho az udalost `gump_open` - stejne jako `ui.craft_gump`.
	visible = false
	_ensure_close()


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
	# Data znamenaji "ukaz je" - okno se tim otevre (jinak by kliknuti na uzly
	# zavreneho okna nic nedelalo a `prijima_vstup()` by ho spravne ignoroval).
	_vendor = vendor
	_id = id
	_buy = _radky(buy)
	_sell = _radky(sell)
	_vyber = {"buy": {}, "sell": {}}
	if _smer != "sell":
		_smer = "buy"
	_dirty = true
	visible = true


func je_otevreny() -> bool:
	return visible


func zavri() -> bool:
	# ZAVRENI OKNA (ZADANI-28, B4). Do teto zmeny okno obchodu ZADNOU cestu
	# zavrit nemelo - ani tlacitko, ani klavesu (namEReno 2026-10-19:
	# `api_zavri false`, `tlacitko_close false`, box mel 63 tlacitek a ani
	# jedno "Close"). Hrac se tedy z obchodu nemohl dostat.
	# Vraci `true` JEN kdyz okno opravdu bylo otevrene - "zavreno" nesmi byt
	# tiche (volajici pocita, kolik oken zavrel).
	if not visible:
		return false
	visible = false
	# Nevyrizeny pozadavek se ZAHAZUJE: klik na "Potvrdit" tesne pred zavrenim
	# nesmi po zavreni odeslat prikaz (zavrene okno neprijima vstupy).
	_pozadavek = {}
	_vyber = {"buy": {}, "sell": {}}
	return true


func toggle() -> bool:
	# Tlacitko/klavesa "zpet": otevrene okno zavre. Zavrene okno se TIMHLE
	# NEOTEVIRA - k tomu je potreba udalost `gump_open` (data ma SIM).
	return zavri()


func je_zavreny() -> bool:
	return not visible


func text_zavrit() -> String:
	# Text tlacitka na JEDNOM miste (test a sonda ho ctou odsud, ne z uzlu).
	return TEXT_ZAVRIT


func smer() -> String:
	return _smer


func prijima_vstup() -> bool:
	# ZAVRENE OKNO NEPRIJIMA VSTUPY (ZADANI-28, B4): klik na radek, prepinac
	# ani potvrzeni nesmi nic udelat, kdyz okno neni videt. Je to JEDNO misto
	# rozhodnuti (ptaji se ho VSECHNY tri handlery tlacitek) - kdyby to melo
	# kazde tlacitko svoje, jedna cesta by se zapomnela a zavrene okno by
	# porad posilalo prikazy.
	# ⚠ VEREJNE API (`nastav_smer`, `stiskni_*`) se ZAMERNE nekontroluje:
	# vola je klient s DATY (a testy); "vstup hrace" je klik na uzel, tedy
	# handlery nize.
	return visible


func _on_radek_pressed(smer: String, item: int) -> void:
	# Klik na radek seznamu. Zavrene okno ho ignoruje (viz `prijima_vstup`).
	if not prijima_vstup():
		return
	stiskni_radek(smer, item)


func _on_potvrdit_pressed(smer: String) -> void:
	# Klik na "Confirm". Zavrene okno ho ignoruje.
	if not prijima_vstup():
		return
	stiskni_potvrzeni(smer)


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


func _on_smer_pressed() -> void:
	# Klik na přepínač = druhý směr. UI tím NEMĚNÍ stav `sim` (docs/04 §4.1) -
	# jen si přepne, který seznam zobrazuje; příkaz vznikne až potvrzením.
	# ZAVRENE OKNO KLIK IGNORUJE (ZADANI-28, B4).
	if not prijima_vstup():
		return
	nastav_smer("sell" if _smer == "buy" else "buy")


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
	var popis := Button.new()
	popis.name = "Smer"
	# ⚠⚠ PŘEPÍNAČ NAKUP/PRODEJ (session D, 2026-10-11). Do této chvíle tu byl
	# jen `Label` "Buy"/"Sell" a `nastav_smer("sell")` volal POUZE test
	# (`tests/cases/vendor_gump.gd`) - **hráč se k prodeji nemohl dostat**:
	# okno umělo jen nakupovat, přepínač v UI nebyl. Přijímací kritérium
	# dema ("těžba -> výroba -> prodej") tím bylo splněné jen v sondě.
	# Je to `Button` na MÍSTĚ původního popisu (ne nové dítě): počet uzlů
	# v boxu zůstává 3 (popis + řádek + potvrzení) a `tests/cases/vendor_gump.gd`
	# to měří (`get_child_count() == 3`).
	popis.text = PREPINAC_BUY if _smer == "buy" else PREPINAC_SELL
	popis.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
	popis.pressed.connect(_on_smer_pressed)
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
		tlacitko.pressed.connect(_on_radek_pressed.bind(_smer, int(radek["item"])))
		box.add_child(tlacitko)
	var potvrzeni := Button.new()
	potvrzeni.name = "Potvrdit"
	potvrzeni.text = "Confirm: " + text_vyberu(_smer)
	potvrzeni.custom_minimum_size = Vector2(SIRKA, RADEK_VYSKA)
	potvrzeni.pressed.connect(_on_potvrdit_pressed.bind(_smer))
	box.add_child(potvrzeni)
	return true


func _ensure_box() -> VBoxContainer:
	if _box == null:
		_box = VBoxContainer.new()
		_box.name = "Obchod"
		# VELIKOST JE POVINNA (stejna past jako u `ui.journal` a `ui.craft_gump`).
		_box.custom_minimum_size = Vector2(SIRKA, VYSKA)
		_box.size = Vector2(SIRKA, VYSKA)
		# Pod listou s "Close" (ZADANI-28, B4) - jinak by tlacitko lezelo na
		# prvnim radku seznamu a hrac by ho nemohl zmacknout.
		_box.position = Vector2(0.0, HEADER)
		add_child(_box)
	return _box


func _ensure_close() -> Button:
	# TLACITKO "Close" (ZADANI-28, B4): hrac se z okna obchodu nemohl dostat.
	# Je to `Button` v liste NAD seznamem (ne v boxu) - box ma mit presne
	# 3 uzly na radek a `tests/cases/vendor_gump.gd` to meri.
	if _close == null:
		_close = Button.new()
		_close.name = "Zavrit"
		_close.text = TEXT_ZAVRIT
		_close.position = Vector2(SIRKA - TLACITKO_SIRKA, 2.0)
		_close.custom_minimum_size = Vector2(TLACITKO_SIRKA, TLACITKO_VYSKA)
		_close.size = Vector2(TLACITKO_SIRKA, TLACITKO_VYSKA)
		_close.pressed.connect(zavri)
		add_child(_close)
	return _close


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
