extends RefCounted
# world.doors - dvere (docs/04 §4.2, data z doors.txt pres data/doors.json).
# Konvence ZMERENA 2026-10-07 (8. session): art z `doors.txt` je ZAVRENY a
# jeho `art + 1` je OTEVRENY stav (doklady v hlavicce modulu, docs/03 §3.6).
# Cesta k souboru granule je VSTUP (`-- --doors-script=<cesta>`), aby mutacni
# harness mohl vymenit soubor za mutant.

const Lib = preload("res://tests/lib.gd")
const DOORS_SCRIPT := "res://sim/world/doors.gd"
const DOORS_PATH := "res://data/doors.json"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta := _arg("doors-script", DOORS_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("world.doors NENI HOTOVA: " + cesta + " chybi")
		return
	var doors = script.new()
	t._check(doors.category_count() == 37,
		"world.doors: kategorii 37 (docs/03 §3.6, namEReno %d)" % doors.category_count())

	# kategorie 4 = "Wood Door": doors.txt uvadi 1721 1723 1717 1719 1725 ... 1731
	t._check(doors.is_door(1721), "world.doors: 1721 (art z doors.txt) je dvere")
	t._check(doors.is_door(1722), "world.doors: 1722 (= 1721 + 1, otevreny art) je taky dvere")
	t._check(not doors.is_door(1733), "world.doors: 1733 neni dvere (neni v doors.txt a 1732 taky ne)")
	t._check(doors.category(1721) == 4, "world.doors: 1721 patri do kategorie 4 (namEReno %d)" % doors.category(1721))
	t._check(doors.category(1722) == 4, "world.doors: otevreny art 1722 ma stejnou kategorii (namEReno %d)" % doors.category(1722))
	t._check(doors.name_of(4) == "Wood Door", "world.doors: kategorie 4 se jmenuje 'Wood Door' (namEReno '%s')" % doors.name_of(4))
	t._check(not doors.is_door(0) and doors.category(0) == -1, "world.doors: 0 neni dvere")
	t._check(doors.toggle(0) == 0, "world.doors: toggle() na ne-dveri vraci 0")

	# stav: art z doors.txt je ZAVRENY, `art + 1` OTEVRENY
	t._check(not doors.is_open(1721), "world.doors: 1721 je ZAVRENY")
	t._check(doors.is_open(1722), "world.doors: 1722 (= 1721 + 1) je OTEVRENY")
	t._check(doors.toggle(1721) == 1722, "world.doors: toggle(1721) = 1722 (namEReno %d)" % doors.toggle(1721))
	t._check(doors.toggle(1722) == 1721, "world.doors: toggle(1722) = 1721 - operace je vratna")
	t._check(doors.open_tile(4, 0) == 1722, "world.doors: open_tile(4, 0) = 1722 (namEReno %d)" % doors.open_tile(4, 0))
	t._check(doors.orientation(1721) == 0 and doors.orientation(1717) == 2,
		"world.doors: orientace je INDEX v doors.txt (1721 -> %d, 1717 -> %d)" % [doors.orientation(1721), doors.orientation(1717)])
	t._check(doors.orientation(1725) == 4,
		"world.doors: orientace kusu 5 je 4, ne 0 - 'index %% 4' je stary omyl (namEReno %d)" % doors.orientation(1725))
	t._check(doors.orientation(1722) == doors.orientation(1721) and doors.orientation(1726) == doors.orientation(1725),
		"world.doors: otevreny art ma stejnou orientaci jako jeho zavreny clen")

	# 7 = "Tall Wrought Iron Gate": kusy jsou SUDE (2084, 2086, ...), takze
	# "otevreno = sudy art" by tuhle kategorii rozhodlo presne opacne.
	t._check(not doors.is_open(2084) and doors.is_open(2085),
		"world.doors: u sude kategorie je zavreny 2084 a otevreny 2085 (namEReno %s / %s)"
			% [str(doors.is_open(2084)), str(doors.is_open(2085))])

	# Cely soubor: 230 artu ze 37 kategorii - u kazdeho plati konvence paru.
	var data = Lib.json_at(DOORS_PATH)
	if data == null or not (data.get("rows") is Array):
		t._pending("world.doors: " + DOORS_PATH + " se nenacetl")
		return
	var vsechny: Dictionary = {}
	for row in data["rows"]:
		for i in range(1, 9):
			var art: int = int(row.get("piece%d" % i, 0))
			if art != 0:
				vsechny[art] = true
	var projito := 0
	var sudy_zavreny := 0
	var vad_stav := 0
	var vad_toggle := 0
	var vad_door := 0
	var vad_kat := 0
	var partner_v_datech := 0
	for row in data["rows"]:
		for i in range(1, 9):
			var tile: int = int(row.get("piece%d" % i, 0))
			if tile == 0:
				continue
			projito += 1
			if tile % 2 == 0:
				sudy_zavreny += 1
			if doors.is_open(tile) or not doors.is_open(tile + 1):
				vad_stav += 1
			if doors.toggle(tile) != tile + 1 or doors.toggle(tile + 1) != tile:
				vad_toggle += 1
			if not doors.is_door(tile) or not doors.is_door(tile + 1):
				vad_door += 1
			if doors.category(tile + 1) != doors.category(tile) \
					or doors.orientation(tile + 1) != doors.orientation(tile):
				vad_kat += 1
			if vsechny.has(tile + 1):
				partner_v_datech += 1
	t._check(projito == 230, "world.doors: projito %d artu z 37 kategorii (cekano 230)" % projito)
	t._check(vad_stav == 0, "world.doors: kazdy art z doors.txt je zavreny a jeho +1 otevreny (%d vad)" % vad_stav)
	t._check(vad_toggle == 0, "world.doors: toggle vraci +1/-1 a je vratny (%d vad)" % vad_toggle)
	t._check(vad_door == 0, "world.doors: is_door plati pro oba cleny dvojice (%d vad)" % vad_door)
	t._check(vad_kat == 0, "world.doors: oba cleny maji stejnou kategorii i orientaci (%d vad)" % vad_kat)
	t._check(partner_v_datech == 0, "world.doors: otevreny art neni v doors.txt ani jednou (%d pripadu)" % partner_v_datech)
	t._check(sudy_zavreny > 100, "world.doors: %d zavrenych artu je sudych - parita nemuze byt kriterium stavu" % sudy_zavreny)
