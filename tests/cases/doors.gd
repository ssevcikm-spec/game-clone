extends RefCounted
# world.doors - dvere (docs/04 §4.2, data z doors.txt pres data/doors.json).
# Testy meri chovani nad skutecnymi daty: kategorie, stav (zavreno/otevreno),
# orientace a to, ze toggle je vratna operace.
# Struktura 8 artu (1-4 zavrene, 5-8 otevrene) je rozhodnuta OBRAZKEM - viz
# hlavicka modulu a montaz assets/uo/art-preview/doors.png.

const Lib = preload("res://tests/lib.gd")


func run(t) -> void:
	var script = Lib.script_at("res://sim/world/doors.gd")
	if script == null:
		t._pending("world.doors NENI HOTOVA: sim/world/doors.gd chybi")
		return
	var doors = script.new()
	t._check(doors.category_count() == 37,
		"world.doors: kategorii 37 (docs/03 §3.6, namEReno %d)" % doors.category_count())

	# kategorie 4 = "Wood Door" (docs/03 §3.6 uvadi presne techto 8 artu)
	t._check(doors.is_door(1721), "world.doors: 1721 je dvere")
	t._check(doors.category(1721) == 4, "world.doors: 1721 patri do kategorie 4 (namEReno %d)" % doors.category(1721))
	t._check(doors.name_of(4) == "Wood Door", "world.doors: kategorie 4 se jmenuje 'Wood Door' (namEReno '%s')" % doors.name_of(4))
	t._check(not doors.is_door(0) and doors.category(0) == -1, "world.doors: 0 neni dvere")
	t._check(doors.toggle(0) == 0, "world.doors: toggle() na ne-dveri vraci 0")

	# stavy: kusy 1-4 zavrene, 5-8 otevrene (rozhodnuto obrazkem)
	t._check(not doors.is_open(1721), "world.doors: 1721 (kus 1) je zavrene")
	t._check(doors.is_open(1725), "world.doors: 1725 (kus 5) je otevrene")
	t._check(doors.toggle(1721) == 1725, "world.doors: toggle(1721) = 1725 (namEReno %d)" % doors.toggle(1721))
	t._check(doors.toggle(1725) == 1721, "world.doors: toggle(1725) = 1721 - operace je vratna")
	t._check(doors.open_tile(4, 0) == 1725, "world.doors: open_tile(4, 0) = 1725 (namEReno %d)" % doors.open_tile(4, 0))
	t._check(doors.orientation(1721) == 0 and doors.orientation(1717) == 2,
		"world.doors: orientace je index %% 4 (1721 -> %d, 1717 -> %d)" % [doors.orientation(1721), doors.orientation(1717)])
	t._check(doors.orientation(1725) == doors.orientation(1721),
		"world.doors: otevreny art ma stejnou orientaci jako zavreny")

	# kontrola na CELYCH datech: kazda kategorie ma 8 unikatnich artu a toggle
	# vraci platne dvere stejne kategorie (ne nahodny art).
	# POZOR: JSON vraci cisla jako float, takze se vse prevadi pres int();
	# art id 0 znamena "kus v teto kategorii neni" a preskakuje se.
	var checked := 0
	var bad := 0
	for row in Lib.json_at("res://data/doors.json")["rows"]:
		var pieces: Array = []
		for i in range(1, 9):
			pieces.append(int(row["piece%d" % i]))
		if pieces.size() != 8:
			bad += 1
			continue
		for index in 8:
			var tile: int = pieces[index]
			if tile == 0:
				continue
			checked += 1
			var other: int = doors.toggle(tile)
			var partner: int = pieces[index + 4] if index < 4 else pieces[index - 4]
			if partner == 0:
				# protějšek v datech není -> toggle vraci 0 a je to spravne
				if other != 0:
					bad += 1
			elif other != partner or doors.category(other) != doors.category(tile):
				bad += 1
	t._check(checked > 200, "world.doors: projito %d artu z 37 kategorii (cekano >200)" % checked)
	t._check(bad == 0, "world.doors: toggle vraci protějšek ze stejné kategorie (%d vad)" % bad)
