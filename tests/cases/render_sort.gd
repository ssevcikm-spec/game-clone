extends RefCounted
# render.sort - jedina funkce razeni kresleni (granule render.sort; docs/02 §2.4).
#
# CO SE MERI (docs/09 §9.4) - chovani, ne "soubor existuje":
#   * dve statiky na stejne dlazdici: nizsi `z` se kresli prvni (prijimaci
#     kriterium granule), a to i tehdy, kdyz jsou v opacnem poradi na vstupu,
#   * v ramci jedne dlazdice plati land -> statiky podle z -> mobilove podle z,
#   * HLAVNI klic je `x + y` (diagonala), `z` je az v ramci ni - zadna vrstva
#     nesmi prelezt na sousedni diagonalou (proto se testuje I radix vrstev),
#   * razeni je STABILNI (stejny klic = poradi vstupu) a deterministicke,
#   * `z` mimo rozsah se sveruje, jinak by objekt odplul o cely diagonaly.
#
# Cesta k souboru je VSTUP: `-- --sort-script=<cesta>`, aby mutacni test
# (tools/gates/mutace-tests.py) mohl predat mutanta a aby se overilo, ze test
# meri opravdu ten soubor, ktery dostane (HANDOFF 2026-10-06, past 2).

const Lib = preload("res://tests/lib.gd")

const SORT_SCRIPT := "res://render/sort.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _tag(kind: String, x: int, y: int, z: int) -> Dictionary:
	return {"kind": kind, "x": x, "y": y, "z": z,
		"tag": "%s@%d,%d,%d" % [kind, x, y, z]}


func _tags(objects: Array) -> Array:
	var out: Array = []
	for obj in objects:
		out.append(str(obj.get("tag", "?")))
	return out


func _mix(pocet: int) -> Array:
	# Deterministicky seznam bez `randi()` (docs/02 §2.3) - LCG jako v core.rng.
	var out: Array = []
	var st := 42
	var kindy := ["land", "static", "mobile", "item"]
	for i in pocet:
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var x: int = 1495 + st % 8
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var y: int = 1630 + st % 8
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var z: int = (st % 40) - 20
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		out.append(_tag(kindy[st % 4], x, y, z))
	return out


func run(t) -> void:
	var script = Lib.script_at(_arg("sort-script", SORT_SCRIPT))
	if script == null:
		t._pending("render.sort NENI HOTOVA: render/sort.gd chybi")
		return
	var sort = script.new()

	# 1) prijimaci kriterium granule: dva objekty stejne dlazdice, ruzne z
	var dva := [_tag("static", 10, 10, 0), _tag("static", 10, 10, 7)]
	t._check(_tags(sort.draw_order(dva)) == ["static@10,10,0", "static@10,10,7"],
		"render.sort: dva statiky na jedne dlazdici, nizsi z prvni (namEReno %s)"
		% str(_tags(sort.draw_order(dva))))

	# 1b) `priority_z` je PORADOVA vyska (ClassicUO `PriorityZ`, `Chunk.cs:246-272`):
	#     plocha dlazdice mostu (podlaha, -1) se kresli PRED zabradlim (+1), i kdyz
	#     maji STEJNE `z`. NamEReno 2026-10-07 na molu u Britannie: prkno i zabradli
	#     maji z=10, dnes je z toho remiza -> rozhoduje poradi v souboru mapy a
	#     prkno zabradli prekryje (30 dlazdic mola).
	var most := [
		{"kind": "static", "x": 10, "y": 10, "z": 10, "priority_z": 11, "tag": "zabradli"},
		{"kind": "static", "x": 10, "y": 10, "z": 10, "priority_z": 10, "tag": "plocha"},
	]
	t._check(_tags(sort.draw_order(most)) == ["plocha", "zabradli"],
		"render.sort: priority_z rozhoduje na stejne dlazdici (%s)"
		% str(_tags(sort.draw_order(most))))

	# 1c) bez `priority_z` plati `z` - vstup {kind,x,y,z} se chova jako predtim
	var bez_priority := [_tag("static", 10, 10, 5), _tag("static", 10, 10, 2)]
	t._check(_tags(sort.draw_order(bez_priority)) == ["static@10,10,2", "static@10,10,5"],
		"render.sort: bez priority_z se radi podle z (%s)"
		% str(_tags(sort.draw_order(bez_priority))))

	# 1d) `priority_z` mimo rozsah `z` se SVERUJE - jinak by objekt preskocil
	#     o cely diagonaly (stejna past jako u `z` v hlavicce modulu)
	var sveru := [
		{"kind": "static", "x": 6, "y": 6, "z": 0, "priority_z": 5000, "tag": "druha_diagonala"},
		{"kind": "static", "x": 5, "y": 6, "z": 0, "priority_z": -5000, "tag": "prvni_diagonala"},
	]
	t._check(_tags(sort.draw_order(sveru)) == ["prvni_diagonala", "druha_diagonala"],
		"render.sort: priority_z mimo rozsah nepreskoci diagonalou (%s)"
		% str(_tags(sort.draw_order(sveru))))

	# 2) jedna dlazdice: ⚠ 18. session - LAND JE VZDY PRVNI (ma vlastni pruchod,
	# reference `RenderLists.cs:199-232` kresli mesh land PRED statiky), pak
	# statiky/mobilove podle `z` vzestupne a pri stejnem `z` podle vrstvy
	# (land < static < mobile). Do 17. session byla vrstva pred `z`, takze statik
	# nad hracem sel pred hracem (vada "postava na strese").
	var smes := [_tag("mobile", 4, 4, 0), _tag("static", 4, 4, 5), _tag("land", 4, 4, 0),
		_tag("mobile", 4, 4, -3), _tag("static", 4, 4, -1)]
	t._check(_tags(sort.draw_order(smes)) == ["land@4,4,0", "mobile@4,4,-3",
		"static@4,4,-1", "mobile@4,4,0", "static@4,4,5"],
		"render.sort: land prvni (vlastni pruchod), pak podle z vzestupne, "
		+ "pri shode vrstva (namEReno %s)" % str(_tags(sort.draw_order(smes))))

	# 3) ⚠ 17. session (2026-10-08): `z` je SILNEJSI nez vrstva. Do teto session
	#    to bylo obracene a byl to duvod, proc uzivatel videl postavu "stat na
	#    strese": strecha (statik, vrstva 1) na TEZE diagonale sla PRED hracem
	#    (mobil, vrstva 2), i kdyz byla o 11 jednotek vys. Reference: ClassicUO
	#    `CalculateDepthZ()` (`View.cs:83`) = `(x + y) + (127 + z) * 0.01f` -
	#    vrstva v tom klíči NENI vubec, u nas je az ZA `z`.
	t._check(sort.sort_key(_tag("static", 10, 10, 31)) > sort.sort_key(_tag("mobile", 10, 10, 20)),
		"render.sort: vyssi `z` na TEZE diagonale jde POZDEJI (strecha z=31 za hracem z=20)")
	# stejna vyska: poradi vrstvy zustava (mobil vpred na sve dlazdici)
	t._check(sort.sort_key(_tag("static", 10, 10, 20)) < sort.sort_key(_tag("mobile", 10, 10, 20)),
		"render.sort: pri STEJNEM `z` jde statik pred mobilem")
	# diagonala je PRVOTNI klic - na tom stoji binarni deleni v `chunk_mesh.split`
	t._check(sort.sort_key(_tag("static", 1, 1, 127)) < sort.sort_key(_tag("mobile", 50, 50, -128)),
		"render.sort: diagonala je PRVOTNI klic (i statik vysoko na blizke diagonale pred hracem daleko)")
	# 3b) RADIX VRSTEV musi pojmout VSECHNY vrstvy: `LAYERS` je pocet hodnot
	#     `layer` v klíči, takze musi byt > nejvetsi vrstva (mobil = 2). Kdyz se
	#     `LAYERS` snizi na 2, vrstvy static (1) a mobile (2) se v klíči PREKRYJI
	#     a `z` je pak neoddeli - ticha vada poradi. (NamerEReno 2026-10-08:
	#     mutace "LAYERS 3 -> 2" prosla, dokud tu tahle kontrola nebyla.)
	var nejvetsi_vrstva: int = maxi(int(sort.get("LAYER_LAND")),
		maxi(int(sort.get("LAYER_STATIC")), int(sort.get("LAYER_MOBILE"))))
	t._check(int(sort.get("LAYERS")) > nejvetsi_vrstva,
		"render.sort: LAYERS (%d) je vetsi nez nejvyssi vrstva (%d) - jinak se vrstvy v klíči prekryji"
			% [int(sort.get("LAYERS")), nejvetsi_vrstva])
	# a krok `z` v klíči musi byt aspon `LAYERS`, aby se `z` a vrstva nerozpadly
	# (dva objekty s jinym `z` se nesmi prekryt ve stejnem klíči)
	t._check(int(sort.get("LAYERS")) >= 3 and int(sort.get("Z_SPAN")) >= 256,
		"render.sort: LAYERS >= 3 a Z_SPAN >= 256 (namEReno %d / %d)"
			% [int(sort.get("LAYERS")), int(sort.get("Z_SPAN"))])
	# `item` je predmet na zemi - patri do mobilni vrstvy
	t._check(sort.sort_key(_tag("item", 2, 2, 0)) == sort.sort_key(_tag("mobile", 2, 2, 0)),
		"render.sort: `item` se radi jako mobilni")

	# 3c) ⚠ 18. session: Z PREBIJE AZ ~2,5 KROKU MRIZKY (reference
	#     `(x + y) + (127 + z) * 0.01f`), ale NE 3. Do 17. session tu byl
	#     pozadavek "vsechny objekty diagonaly 8 pred vsemi z diagonaly 9" -
	#     ten v reference NEPLATI a byl to duvod vady "zed prosvita pres
	#     strechu": strecha o 1-2 diagonály dal a vys se musi kreslit PO nizke
	#     zdi bliz. Testuje se OBEMA smery: prebit se MUSI dat 1 i 2 kroky,
	#     3 kroky NESMI.
	var d8: Array = []
	var d9: Array = []
	var d10: Array = []
	var d11: Array = []
	for z in [-128, 0, 127]:
		d8.append(_tag("static", 5, 3, z))
		d9.append(_tag("static", 6, 3, z))
		d10.append(_tag("static", 7, 3, z))
		d11.append(_tag("static", 8, 3, z))
	var max8: int = sort.sort_key(d8[0])
	for obj in d8:
		max8 = maxi(max8, sort.sort_key(obj))
	var min9: int = sort.sort_key(d9[0])
	var min10: int = sort.sort_key(d10[0])
	var min11: int = sort.sort_key(d11[0])
	for obj in d9:
		min9 = mini(min9, sort.sort_key(obj))
	for obj in d10:
		min10 = mini(min10, sort.sort_key(obj))
	for obj in d11:
		min11 = mini(min11, sort.sort_key(obj))
	t._check(max8 > min9 and max8 > min10,
		"render.sort: `z` prebije 1 i 2 kroky mrizky (max diag 8 %d > min diag 9 %d, > min diag 10 %d)"
			% [max8, min9, min10])
	t._check(max8 < min11,
		"render.sort: `z` NEPREBIJE 3 kroky mrizky (max diag 8 %d < min diag 11 %d)"
			% [max8, min11])

	# 3d) ⚠ 18. session: LAND MA VLASTNI PRUCHOD - i land s nejvyssim `z` na
	#     nejblizsi diagonale jde PRED statik s nejnizsim `z` na zacatku mapy.
	#     Na tom stoji vada "svah prosvita pres schody/most".
	t._check(sort.sort_key(_tag("land", 50, 50, 127)) < sort.sort_key(_tag("static", 0, 0, -128)),
		"render.sort: land je pred statiky i pres nejvyssi `z` a nejblizsi diagonalou")

	# 4) hlavni klic je x+y, ne x ani y
	t._check(sort.sort_key(_tag("static", 0, 8, 0)) < sort.sort_key(_tag("static", 5, 5, 0)),
		"render.sort: (0,8) s x+y=8 se kresli pred (5,5) s x+y=10")
	t._check(sort.sort_key(_tag("static", 3, 4, 0)) == sort.sort_key(_tag("static", 4, 3, 0)),
		"render.sort: stejna diagonala ma stejny klic ((3,4) a (4,3))")
	t._check(sort.sort_key(_tag("land", 2, 2, 0)) < sort.sort_key(_tag("land", 3, 2, 0)),
		"render.sort: dalsi diagonala je vetsi i pri nejnizsim z")

	# 5) z mimo rozsah se sveruje (jinak by objekt prebahl o cely diagonaly)
	t._check(sort.sort_key(_tag("land", 2, 2, 99999)) == sort.sort_key(_tag("land", 2, 2, 127)),
		"render.sort: z=99999 se sveruje na Z_MAX")
	t._check(sort.sort_key(_tag("land", 2, 2, -99999)) == sort.sort_key(_tag("land", 2, 2, -128)),
		"render.sort: z=-99999 se sveruje na Z_MIN")

	# 6) vyznam absolutniho klice: 0 = (0,0), vrstva land, z = Z_MIN
	t._check(sort.sort_key(_tag("land", 0, 0, -128)) == 0,
		"render.sort: klic 0 = (0,0) land pri Z_MIN (namEReno %d)"
		% sort.sort_key(_tag("land", 0, 0, -128)))

	# 7) stabilita: stejny klic = poradi vstupu. Na TREECH prvcich se chova
	# jako stabilni i nestabilni trideni (namEReno 2026-10-04), proto i 1000.
	var stejne := [_tag("mobile", 7, 7, 0), _tag("mobile", 7, 7, 0), _tag("mobile", 7, 7, 0)]
	var tagy := ["prvni", "druhy", "treti"]
	for i in 3:
		stejne[i]["tag"] = tagy[i]
	t._check(_tags(sort.draw_order(stejne)) == tagy,
		"render.sort: tri objekty se stejnym klicem drzi poradi vstupu "
		+ "(namEReno %s)" % str(_tags(sort.draw_order(stejne))))
	var hodne: Array = []
	for i in 1000:
		var obj := _tag("mobile", 7, 7, 0)
		obj["tag"] = "m%04d" % i
		hodne.append(obj)
	var usporadano := true
	var predchozi := -1
	for obj in sort.draw_order(hodne):
		var poradi := int(str(obj["tag"]).substr(1))
		if poradi < predchozi:
			usporadano = false
		predchozi = poradi
	t._check(usporadano, "render.sort: 1000 objektu se stejnym klicem drzi poradi vstupu")

	# 8) determinismus + vysledek je serazeny podle `sort_key`
	var prvni := _tags(sort.draw_order(_mix(200)))
	t._check(prvni == _tags(sort.draw_order(_mix(200))),
		"render.sort: dva stejne vstupy daji stejne poradi (determinismus)")
	var vstup := _mix(200)
	var vysledek: Array = sort.draw_order(vstup)
	var serazeno := true
	for i in range(1, vysledek.size()):
		if sort.sort_key(vysledek[i - 1]) > sort.sort_key(vysledek[i]):
			serazeno = false
	t._check(serazeno, "render.sort: klic ve vysledku neklesa (%d objektu)" % vysledek.size())
	var klicove := vstup.duplicate()
	klicove.sort_custom(func(a, b): return sort.sort_key(a) < sort.sort_key(b))
	t._check(_tags(klicove) == _tags(vysledek),
		"render.sort: razeni podle sort_key da stejne poradi jako draw_order")

	# 9) ⚠ 18. session: puvodni zneni teto kontroly ("vsechny objekty diagonaly 8
	#    pred vsemi z diagonaly 9") je VYVRACENO referenci a nahradila ho
	#    kontrola 3c (z prebije 1 i 2 kroky, ne 3). Tady zustava jen to, co plati
	#    dal: RADIX VRSTEV se nesmi rozpadnout - kdyby `LAYERS` kleslo na 2,
	#    prekryje se statik (1) a mobil (2) a `z` je neoddeli.
	var stejna_dlazdice: Array = [
		_tag("static", 5, 3, 0), _tag("mobile", 5, 3, 0)]
	t._check(_tags(sort.draw_order(stejna_dlazdice)) == ["static@5,3,0", "mobile@5,3,0"],
		"render.sort: na stejne dlazdici a stejnem `z` jde statik pred mobilem "
		+ "(radix vrstev; namEReno %s)" % str(_tags(sort.draw_order(stejna_dlazdice))))

	# 10) neznamy `kind` nesmi byt tichy: kresli se jako mobilni
	var cizi := [{"kind": "vitr", "x": 1, "y": 1, "z": 0, "tag": "vitr"}]
	t._check(sort.draw_order(cizi).size() == 1
		and sort.sort_key(cizi[0]) == sort.sort_key(_tag("mobile", 1, 1, 0)),
		"render.sort: neznamy `kind` se kresli jako mobilni")

	# 11) prazdny vstup neni chyba, ale ani uspech
	t._check(sort.draw_order([]).is_empty(), "render.sort: prazdny seznam da prazdny vysledek")
