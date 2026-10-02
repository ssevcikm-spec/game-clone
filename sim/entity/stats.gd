extends RefCounted
# Staty postavy (granule entity.stats, docs/04 §4.2).
#
# Vzorce jsou ze zadani (ZADANI §10 body 8 a 9, docs/01 §1.2):
#   hits_max = 50 + STR/2,  stam_max = DEX,  mana_max = INT,  stat cap = 225.
# Vse je v CELYCH cislech - staty jsou ve stavu, kde float nepatri
# (docs/01 §1.5.3). Deleni je celociselne, tedy u licheho STR se zaokrouhluje
# dolu; to je soucast vzorce, ne nahoda.
#
# `int` je v GDScriptu klicove slovo, proto se pouziva `int_` - presne jak
# predepisuje docs/04 §4.5. Ze stejneho duvodu je i `str_` (jinak by se
# prekryla globalni funkce `str()`).

const Const = preload("res://core/const.gd")

var str_: int = 10
var dex: int = 10
var int_: int = 10


func _init(strength: int = 10, dexterity: int = 10, intelligence: int = 10) -> void:
	str_ = strength
	dex = dexterity
	int_ = intelligence


func hits_max() -> int:
	return 50 + str_ / 2


func stam_max() -> int:
	return dex


func mana_max() -> int:
	return int_


func stat_total() -> int:
	return str_ + dex + int_


func at_cap() -> bool:
	# Stat cap je 225 (ZADANI §10 bod 9); kdo ho zveda, je `sim.skill_gain`.
	return stat_total() >= Const.STAT_CAP
