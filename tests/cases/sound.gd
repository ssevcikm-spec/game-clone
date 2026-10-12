extends RefCounted
# `app.sound` (granule `audio.playback`) - prehravani zvuku z udalosti.
#
# Co tenhle case meri (a cim): modul se ZAVOLA a overuje se VYSLEDEK, ne
# pritomnost souboru (docs/09 §9.4). Měří se ROZHODNUTI (`rozhodni()`): ktera
# udalost da ktery zvuk a jak hlasite - to jde merit bez stromu a bez zvukove
# karty. Ze zvuk OPRAVDU hraje, dokazuje sonda `tools/gates/sound_probe.gd`
# na zive scene (`prehrano > 0`) - tady by to neslo, `AudioStreamPlayer` mimo
# bezici strom neprehraje (Godot to hlasi chybou).
#
# Kontroluje se:
#   1. manifest a zvuky se opravdu nactou (a vady se hlasí seznamem),
#   2. udalost `sound {serial, kind}` od hrace = zvuk naplno,
#   3. "dostali jsme zasah" se odvodi z POKLESU hp hrace (`stats_changed`),
#      ale stejne hp ani cizi mobil zvuk nespusti,
#   4. vzdalenost tlumi; moc daleko = ticho (volume < prah),
#   5. oba tvary udalosti (`{serial, kind}` z kodu i `{id, x, y, z}` ze smlouvy),
#   6. neznamy zvuk se OHLASI (ne tise zmizi) a nic nespadne,
#   7. mimo strom modul zvuk NEPREHRAJE a rekne to (nez aby tvrdil, ze hral).

const Lib = preload("res://tests/lib.gd")
const SCRIPT := "res://app/sound.gd"
const HRAC := 7


func run(t) -> void:
	var skript = Lib.script_at(SCRIPT)
	if skript == null:
		t._pending("app.sound NENI HOTOVY: app/sound.gd chybi nebo se neda nacist")
		return
	var zvuk = skript.new()

	# -- 1) nacteni --------------------------------------------------------
	t._check(zvuk.priprav(), "app.sound: `priprav()` nacetl manifest i zvuky")
	t._check(zvuk.available(), "app.sound: `available()` je true (aspon jeden stream)")
	t._check(zvuk.errors().is_empty(),
		"app.sound: pri nacteni nejsou vady (namEReno %s)" % str(zvuk.errors()))
	t._check(zvuk.sounds().size() >= 5,
		"app.sound: v manifestu je aspon 5 zvuku (namEReno %d)" % zvuk.sounds().size())
	zvuk.nastav_hrace(HRAC)

	# -- 2) udalost `sound` od hrace ---------------------------------------
	var d: Dictionary = zvuk.rozhodni({"name": "sound", "data": {"serial": HRAC, "kind": "hit"}})
	t._check(str(d.get("id", "")) == "hit" and is_equal_approx(float(d.get("volume", 0.0)), 1.0),
		"app.sound: `sound{kind:hit}` od hrace = 'hit' naplno (namEReno %s)" % str(d))

	# -- 3) "hurt" z poklesu hp hrace --------------------------------------
	t._check(zvuk.rozhodni({"name": "stats_changed", "data": {"serial": HRAC, "hp": 50}}).is_empty(),
		"app.sound: prvni `stats_changed` (bez poklesu) zvuk neda")
	t._check(zvuk.rozhodni({"name": "stats_changed", "data": {"serial": HRAC, "hp": 50}}).is_empty(),
		"app.sound: stejne hp zvuk neda")
	t._check(str(zvuk.rozhodni({"name": "stats_changed", "data": {"serial": HRAC, "hp": 40}}).get("id", "")) == "hurt",
		"app.sound: POKLES hp hrace = 'hurt'")
	t._check(zvuk.rozhodni({"name": "stats_changed", "data": {"serial": 99, "hp": 1}}).is_empty(),
		"app.sound: pokles hp CIZIHO mobila 'hurt' neda")

	# -- 4) vzdalenost ------------------------------------------------------
	var blizko: Dictionary = zvuk.rozhodni(
		{"name": "sound", "data": {"id": "hit", "x": 2, "y": 0, "z": 0}}, Vector3i.ZERO)
	var daleko: Dictionary = zvuk.rozhodni(
		{"name": "sound", "data": {"id": "hit", "x": 100, "y": 0, "z": 0}}, Vector3i.ZERO)
	t._check(not blizko.is_empty() and float(blizko.get("volume", 0.0)) > 0.8,
		"app.sound: 2 dlazdice = hlasite (namEReno %s)" % str(blizko))
	t._check(float(daleko.get("volume", 1.0)) < 0.12,
		"app.sound: 100 dlazdic = pod prahem ticha (namEReno %s)" % str(daleko))

	# -- 5) oba tvary udalosti ---------------------------------------------
	t._check(str(zvuk.rozhodni({"name": "sound", "data": {"serial": 99, "kind": "death"}}).get("id", "")) == "death",
		"app.sound: tvar z KODU (`{serial, kind}`) da 'death'")
	t._check(str(zvuk.rozhodni({"name": "sound", "data": {"id": "death", "x": 0, "y": 0, "z": 0}},
		Vector3i.ZERO).get("id", "")) == "death",
		"app.sound: tvar ze SMLOUVY (`{id, x, y, z}`) da 'death'")
	t._check(zvuk.rozhodni({"name": "sound", "data": {"serial": 99, "kind": "mine"}}).get("id", "") == "mine",
		"app.sound: 'mine' (az ho sim posle) se mapuje na vlastni zvuk")

	# -- 6) neznamy zvuk a nezname udalosti ---------------------------------
	t._check(not zvuk.play("neexistujici_zvuk"), "app.sound: neznamy zvuk vraci false")
	t._check(not zvuk.errors().is_empty(),
		"app.sound: neznamy zvuk se OHLASI v `errors()` (ne tise)")
	t._check(zvuk.rozhodni({"name": "nesmysl", "data": {}}).is_empty(),
		"app.sound: nezname udalosti se ignoruji (a nic neshodi)")

	# -- 7) mimo strom se zvuk NEPREHRAJE (a je to videt) -------------------
	var st_pred: Dictionary = zvuk.stats()
	t._check(not zvuk.play("hit"), "app.sound: mimo scenu `play()` vraci false")
	var st: Dictionary = zvuk.stats()
	t._check(int(st["prehrano"]) == int(st_pred["prehrano"]),
		"app.sound: 'mimo scenu' se NEPOCITA jako prehraty zvuk")
	t._check(int(st["ticho"]) > int(st_pred["ticho"]),
		"app.sound: neprehrati se POCITA v `stats()['ticho']` (ne tise)")
	t._check(int(st["streamu"]) >= 5 and int(st["prehrano"]) == 0 and int(st["prehravacu"]) > 0,
		"app.sound: `stats()` dava smysl i bez stromu: %s" % str(st))
