extends Control
# Stavovy pruh (granule ui.status_bar, docs/04 §4.2): HP/Stam/Mana, vaha a
# zlato. Hodnoty dostava VSTUPEM (`update`/`apply_event`) - samo nic nepocita
# a nikam neleze. Text sklada zvlast (`text_for`), aby sel merit bez okna.

var label: Label = null          # text kresli Label (funguje i bez okna)
var _values: Dictionary = {}


func update(values: Dictionary) -> void:
	# Prevezme hodnoty a prepise text; chybejici klice jsou 0, nikdy pad.
	_values = values.duplicate()
	_ensure_label().text = text_for(_values)


func apply_event(event: Dictionary) -> bool:
	# Udalost sim -> klient (docs/04 §4.4): bere jen `stats_changed`, jina false.
	if str(event.get("name", "")) != "stats_changed" or not (event.get("data") is Dictionary):
		return false
	update(event["data"])
	return true


func text_for(values: Dictionary) -> String:
	# Text pro ZNAMY vstup; poradi casti je dane a testuje se presne.
	var parts: Array[String] = []
	var jmeno := str(values.get("name", ""))
	if jmeno != "":
		parts.append(jmeno)
	parts.append("hp=%d/%d" % [_num(values, "hp"), _num2(values, "hp_max", "max_hp")])
	parts.append("stam=%d/%d" % [_num(values, "stam"), _num(values, "stam_max")])
	parts.append("mana=%d/%d" % [_num(values, "mana"), _num(values, "mana_max")])
	if values.has("weight_max"):
		parts.append("weight=%d/%d" % [_num(values, "weight"), _num(values, "weight_max")])
	else:
		parts.append("weight=%d" % _num(values, "weight"))
	parts.append("gold=%d" % _num(values, "gold"))
	return ", ".join(parts)


func _num(values: Dictionary, key: String) -> int:
	# Jen cisla; text nebo null je 0 (UI nesmi spadnout na cizim vstupu).
	var v = values.get(key, 0)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return int(v) if typeof(v) == TYPE_STRING and v.is_valid_int() else 0


func _num2(values: Dictionary, key: String, alias: String) -> int:
	# `max_hp` je nazev z udalosti `stats_changed` (docs/04 §4.4).
	return _num(values, key) if values.has(key) else _num(values, alias)


func _ensure_label() -> Label:
	if label == null:
		label = Label.new()
		label.name = "StatusText"
		add_child(label)
	return label
