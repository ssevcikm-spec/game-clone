extends RefCounted
# world.stairs - schody (docs/04 §4.2, data ze stairs.txt pres data/stairs.json).
# Testy meri: 19 kategorii, rozpoznani dlazdice a skupinu, do ktere patri
# (podle ni se pri chuzi meni z - docs/05 §5.1).

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/world/stairs.gd")
	if script == null:
		t._pending("world.stairs NENI HOTOVA: sim/world/stairs.gd chybi")
		return
	var stairs = script.new()
	t._check(stairs.group_count() == 19,
		"world.stairs: kategorii 19 (docs/03 §3.6, namEReno %d)" % stairs.group_count())

	# kategorie 0 = "Dark Wood" (docs/03 §3.6 uvadi Block 1848, N 1849, E 1852, S 1851, W 1850)
	t._check(stairs.is_stair(1848), "world.stairs: 1848 je schod")
	t._check(stairs.role(1848) == "block", "world.stairs: 1848 je 'block' (namEReno '%s')" % stairs.role(1848))
	t._check(stairs.role(1849) == "north", "world.stairs: 1849 je 'north'")
	t._check(stairs.role(1852) == "east" and stairs.role(1851) == "south" and stairs.role(1850) == "west",
		"world.stairs: 1852/1851/1850 jsou east/south/west")
	t._check(not stairs.is_stair(0), "world.stairs: 0 neni schod")
	t._check(stairs.stair_group(0).is_empty(), "world.stairs: ne-schod vraci prazdnou skupinu")

	var group: Dictionary = stairs.stair_group(1848)
	t._check(int(group.get("category", -1)) == 0,
		"world.stairs: 1848 patri do kategorie 0 (namEReno %s)" % str(group.get("category")))
	t._check(str(group.get("name", "")) == "Dark Wood",
		"world.stairs: kategorie 0 se jmenuje 'Dark Wood' (namEReno '%s')" % str(group.get("name")))
	t._check(group.get("tiles", {}).has("block") and int(group["tiles"]["block"]) == 1848,
		"world.stairs: skupina obsahuje svuj block art")
	t._check(stairs.group_for_category(1).get("name", "") == "Grey Stone",
		"world.stairs: kategorie 1 je 'Grey Stone'")

	# kontrola na CELYCH datech: kazda kategorie ma aspon block a 4 smerove kusy
	# a vsechny jeji dlazdice se hlasi do te same skupiny.
	# POZOR: JSON vraci cisla jako float -> vse pres int(); 0 = kus neni.
	# NEJDRIV se zmeri, ktere art id jsou v datech vickrat (sdilene mezi
	# kategoriemi) - u tech se neda chtit, aby se hlasily do "své" skupiny.
	var occurrences: Dictionary = {}
	for row in Lib.json_at("res://data/stairs.json")["rows"]:
		for key in row.keys():
			if key in ["category", "comment", "featuremask"]:
				continue
			var tile: int = int(row[key])
			if tile != 0:
				occurrences[tile] = int(occurrences.get(tile, 0)) + 1
	var shared: int = 0
	for tile in occurrences.keys():
		if int(occurrences[tile]) > 1:
			shared += 1
	t._check(shared < 50, "world.stairs: sdilenych art id mezi kategoriemi je %d (cekano <50)" % shared)

	var checked := 0
	var mismatched := 0
	var malformed := 0
	var malformed_detail := ""
	for row in Lib.json_at("res://data/stairs.json")["rows"]:
		var has_block: bool = int(row.get("block", 0)) != 0
		var directions := 0
		for key in ["north", "east", "south", "west"]:
			if int(row.get(key, 0)) != 0:
				directions += 1
		if not has_block or directions < 4:
			# Ne uplne kazda kategorie ma vsech 5 zakladnich kusu - je to
			# vlastnost dat, ne vada modulu. Hlasi se to zvlast.
			malformed += 1
			if malformed_detail == "":
				malformed_detail = "kategorie %s (%s) block=%s smeru=%d" % [
					str(row.get("category")), str(row.get("comment")),
					str(row.get("block")), directions]
			continue
		for key in row.keys():
			if key in ["category", "comment", "featuremask"]:
				continue
			var tile: int = int(row[key])
			if tile == 0 or int(occurrences[tile]) > 1:
				continue
			checked += 1
			if int(stairs.stair_group(tile).get("category", -1)) != int(row["category"]):
				mismatched += 1
	t._check(checked > 100, "world.stairs: projito %d jednoznacnych dlazdic (cekano >100)" % checked)
	t._check(mismatched == 0, "world.stairs: jednoznacne dlazdice se hlasi do sve skupiny (%d neshod)" % mismatched)
	t._check(malformed <= 3, "world.stairs: neuplnych kategorii je %d (%s)" % [malformed, malformed_detail])
