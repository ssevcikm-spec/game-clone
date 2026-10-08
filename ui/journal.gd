extends Control
# Žurnál zpráv (granule `ui.journal`, smlouva docs/04 §4.2, událost `message` §4.4).
#
# TVRZENI, KTERE MUSI DRZET: UI je TENKY KLIENT (docs/04 §4.1) - žurnál jen
# prijima HOTOVE zpravy a zobrazuje je. Nic nepocita, nesaha na stav `sim`
# a nevola `Input`/`Time` (docs/09 §9.10.4).
#
# ODKUD TVAR DAT: udalost `message` ma `{text, kind, hue, name?}` s
# `kind` v `system|say|combat|craft` (docs/04 §4.4). `apply_event` bere CELY
# slovnik `{name, data}` tak, jak ho vydava `core/events.gd` - `sim.snapshot()`
# frontu vyprázdní, takže kdo ji precte prvni, tomu zpravy zustanou.
#
# BARVY: `hue` v udalosti je INDEX barvy v `hues.mul`, ne RGB - prevod by
# potreboval `hues.json`, coz je vrstva `render` a `ui/` na ni nesmi sahat
# (docs/04 §4.1). Barvu proto urcuje `kind` (tabulka COLORS) a `hue` se u
# zpravy DRZI pro pozdější barveni. Je to odchylka od "barvy podle typu"
# v tom smyslu, ze se barvi typem, ne hue indexem - zapsano, ne zamlceno.
#
# "100 zprav nezpomali frame" (prompt granule) je meritelne takhle: zpravy jdou
# do fronty a text se prebuildi JEDNOU za frame (`flush()` z `_process`), ne po
# kazde zprave; fronta se drzi na `MAX_LINES` a starsi se zahazuji. Cisla vydava
# `rebuilds()` (pocet prebaveni textu) a `dropped()` (kolik zprav vypadlo).

const MAX_LINES: int = 200
const SIRKA: float = 520.0       # okno zurnalu (viz `_ensure_label`)
const VYSKA: float = 220.0
const KIND_SYSTEM := "system"
const KIND_SAY := "say"
const KIND_COMBAT := "combat"
const KIND_CRAFT := "craft"

# Barvy typu zpravy. UO kresli systemove zpravy zlutohnede, rec bilou, boj
# cervene, vyrobu zelenkave; presne hodnoty z `hues.mul` sem nepatri (viz
# hlavicka), takze jsou to barvy KLONU - rozhodnuti, ne opis.
const COLORS: Dictionary = {
	KIND_SYSTEM: Color(1.0, 0.85, 0.40),
	KIND_SAY: Color(1.0, 1.0, 1.0),
	KIND_COMBAT: Color(0.90, 0.30, 0.25),
	KIND_CRAFT: Color(0.55, 0.90, 0.55),
}

var label: RichTextLabel = null   # text kresli RichTextLabel (funguje i bez okna)
var _lines: Array[Dictionary] = []
var _dirty: bool = false
var _rebuilds: int = 0
var _dropped: int = 0


func apply_event(event: Dictionary) -> bool:
	# Bere CELY slovnik `{name, data}`; jina udalost nez `message` vraci false.
	if str(event.get("name", "")) != "message" or not (event.get("data") is Dictionary):
		return false
	var data: Dictionary = event["data"]
	add(str(data.get("text", "")), str(data.get("kind", KIND_SYSTEM)),
		int(data.get("hue", 0)), str(data.get("name", "")))
	return true


func apply_events(events: Array) -> int:
	# Davka (snapshot vydava vsechny udalosti naraz): text se prebavi JEDNOU.
	var pocet: int = 0
	for event in events:
		if event is Dictionary and apply_event(event):
			pocet += 1
	return pocet


func add(text: String, kind: String = KIND_SYSTEM, hue: int = 0, name: String = "") -> bool:
	# Prazdna zprava se neuklada (prazdny radek v zurnalu je vada, ne obsah).
	if text.strip_edges().is_empty():
		return false
	_lines.append({"text": text, "kind": kind, "hue": hue, "name": name})
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
		_dropped += 1
	_dirty = true
	return true


func lines() -> Array[Dictionary]:
	# KOPIE fronty (jako `ui.hud.layout()`) - jeji zmena nic nemeni.
	return _lines.duplicate(true)


func message_count() -> int:
	return _lines.size()


func rebuilds() -> int:
	# Pocet prebaveni textu; `apply_events` s N zpravami ho zvedne o 1.
	return _rebuilds


func dropped() -> int:
	return _dropped


func color_of(kind: String) -> Color:
	return COLORS.get(kind, COLORS[KIND_SYSTEM])


func plain_text() -> String:
	# Text bez BBCode - pro testy a pro pripad, ze okno neni ve scene.
	var out: Array[String] = []
	for line in _lines:
		var jmeno: String = str(line.get("name", ""))
		out.append((jmeno + ": " if jmeno != "" else "") + str(line.get("text", "")))
	return "\n".join(out)


func flush() -> bool:
	# Prebavi text, jen kdyz prisla zprava (ne kazdy frame).
	if not _dirty:
		return false
	_dirty = false
	_rebuilds += 1
	var rikol: RichTextLabel = _ensure_label()
	rikol.text = _bbcode()
	if rikol.get_line_count() > 0:
		rikol.scroll_to_line(rikol.get_line_count() - 1)
	return true


func clear() -> void:
	_lines.clear()
	_dirty = true


func _process(_delta: float) -> void:
	flush()


func _bbcode() -> String:
	var out: Array[String] = []
	for line in _lines:
		var barva: Color = color_of(str(line.get("kind", KIND_SYSTEM)))
		var jmeno: String = str(line.get("name", ""))
		var text: String = (jmeno + ": " if jmeno != "" else "") + str(line.get("text", ""))
		# `[` v textu by rozbilo BBCode - escapuje se na `[lb]` (Godot 4).
		out.append("[color=#%s]%s[/color]" % [barva.to_html(false), text.replace("[", "[lb]")])
	return "\n".join(out)


func _ensure_label() -> RichTextLabel:
	if label == null:
		label = RichTextLabel.new()
		label.name = "JournalText"
		label.bbcode_enabled = true
		label.scroll_following = true
		label.fit_content = false
		# ⚠ VELIKOST JE POVINNA: `RichTextLabel` kresli text JEN uvnitr sveho
		# rectu, takze s vychozi velikosti (0,0) je zurnal v demu PRAZDNY.
		# Testy to nepoznaji (ctou `label.text`) - namEReno 16. session: sada
		# byla zelena a snimek ukazal prazdne misto; chytil to az `read_image`
		# nad snimkem. Proto to ma i vlastni kontrolu v `tests/cases/journal.gd`.
		label.custom_minimum_size = Vector2(SIRKA, VYSKA)
		label.size = Vector2(SIRKA, VYSKA)
		add_child(label)
	return label
