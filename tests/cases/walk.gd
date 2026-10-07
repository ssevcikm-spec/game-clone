extends RefCounted
# world.walk - pruchodnost a vysky (docs/04 §4.2, algoritmus docs/05 §5.1.2).
#
# Test meri ALGORITMUS na FAKE mape a FAKE tiledata: `assets/uo/` je v gitignore,
# takze v CI zadna realna tiledata nejsou a test nad nimi by tam nemel co merit.
# Realna data se meri NAVIC, kdyz na disku jsou - a kdyz ne, rekne se to nahlas.
#
# ⚠ KONVENCE, KTERA SE TU MERI (namEReno 2026-10-07 v realne mape): statiky z
# `world.map.statics_at` jsou v prostoru TILEDATA ID PREDMETU (0..0x3FFF), ale
# `world.tiledata` klicuje predmety jako art id (`tile >= 0x4000`). Fake data
# proto maji statiky s MALYMI id a flagy az na `id + 0x4000` - kdyby walk offset
# zapomnel, precte u statiku prazdny land slot a vsechny kontroly na blokovani
# spadnou. Presne tahle vada v kódu byla (pustila 1325 kroku do zdi v Britanii).
#
# Cesta k souboru je VSTUP: `-- --walk-script=<cesta>`, aby mutacni test
# (tools/gates/mutace-tests.py) mohl predat mutanta a aby se overilo, ze test
# meri opravdu ten soubor, ktery dostane (HANDOFF 2026-10-06, past 2).

const Lib = preload("res://tests/lib.gd")
const Const = preload("res://core/const.gd")

const WALK_SCRIPT := "res://sim/world/walk.gd"
const ITEM_OFFSET := 0x4000

const F_IMPASSABLE := 0x00000040
const F_WET := 0x00000080
const F_SURFACE := 0x00000200
const F_BRIDGE := 0x00000400
const F_CONTAINER := 0x00200000
const F_DOOR := 0x20000000


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback

const OFF := -1
const TRAVA := 3            # land, pruchodna
const VODA := 4             # land, Wet
const ZED := 0x0003         # statik, Impassable, height 0
const PLOSINA := 0x0004     # statik, Surface + height 4
const DECOR := 0x0005       # statik, Wall (pruchodnost NEovlivnuje)
const SCHOD := 0x0006       # statik, Surface + height 5, je v `world.stairs`
const DVER := 0x0007        # statik, Door + Impassable + height 20 (ZAVRENE)
const DVER_OTEVRENE := 0x0008   # statik, Door + Impassable + height 20 (OTEVRENE)
const NIZKO := 0x0009       # statik, Impassable, ale z = -40 (pod nohama)
const VYSOKO := 0x000A      # statik, Impassable, z = 60 (nad hlavou)
const PRKNO := 0x000B       # statik, Surface + height 1 (prkno mostu/mola)
const MOST := 0x000C        # statik, Surface + Bridge + height 4 (puli vysku)


class FakeTiledata:
	var f := {}
	var h := {}

	func flags(tile: int) -> int:
		return int(f.get(tile, 0))

	func height(tile: int) -> int:
		return int(h.get(tile, 0))


class FakeMap:
	var land := {}
	var zs := {}
	var statics := {}

	func land_at(x: int, y: int) -> int:
		return int(land.get(Vector2i(x, y), OFF))

	func z_at(x: int, y: int) -> int:
		return int(zs.get(Vector2i(x, y), 0))

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x, y), [])


class FakeStairs:
	# `world.stairs` v testu: schod je jen ten jedny art (bez assetu).
	func is_stair(tile: int) -> bool:
		return tile == SCHOD


class FakeDoors:
	# `world.doors` v testu: stav je dan vzorkem artu, ne flagem (ten maji oba).
	func is_door(tile: int) -> bool:
		return tile == DVER or tile == DVER_OTEVRENE

	func is_open(tile: int) -> bool:
		return tile == DVER_OTEVRENE


func _fake() -> Array:
	var td = FakeTiledata.new()
	td.f[TRAVA] = 0
	td.f[VODA] = F_WET
	# POZOR: flagy statiku jsou az na `id + 0x4000` (viz hlavicka).
	td.f[ZED + ITEM_OFFSET] = F_IMPASSABLE
	td.f[PLOSINA + ITEM_OFFSET] = F_SURFACE
	td.h[PLOSINA + ITEM_OFFSET] = 4
	td.f[DECOR + ITEM_OFFSET] = 0x10        # Wall - pohyb neovlivnuje
	td.h[DECOR + ITEM_OFFSET] = 20
	td.f[SCHOD + ITEM_OFFSET] = F_SURFACE
	td.h[SCHOD + ITEM_OFFSET] = 5
	td.f[DVER + ITEM_OFFSET] = F_DOOR | F_IMPASSABLE | 0x10
	td.h[DVER + ITEM_OFFSET] = 20
	td.f[DVER_OTEVRENE + ITEM_OFFSET] = F_DOOR | F_IMPASSABLE | 0x10
	td.h[DVER_OTEVRENE + ITEM_OFFSET] = 20
	td.f[NIZKO + ITEM_OFFSET] = F_IMPASSABLE
	td.h[NIZKO + ITEM_OFFSET] = 5
	td.f[VYSOKO + ITEM_OFFSET] = F_IMPASSABLE
	td.h[VYSOKO + ITEM_OFFSET] = 5
	td.f[PRKNO + ITEM_OFFSET] = F_SURFACE
	td.h[PRKNO + ITEM_OFFSET] = 1
	td.f[MOST + ITEM_OFFSET] = F_SURFACE | F_BRIDGE
	td.h[MOST + ITEM_OFFSET] = 4

	var map = FakeMap.new()
	for y in 8:
		for x in 8:
			map.land[Vector2i(x, y)] = TRAVA
			map.zs[Vector2i(x, y)] = 0
	return [map, td]


func _statik(tile: int, x: int, y: int, z: int) -> Dictionary:
	return {"tile": tile, "x": x, "y": y, "z": z, "hue": 0}


func _new(script, map, td):
	return script.new(map, td, FakeStairs.new(), FakeDoors.new())


func run(t) -> void:
	var script = Lib.script_at(_arg("walk-script", WALK_SCRIPT))
	if script == null:
		t._pending("world.walk NENI HOTOVA: " + _arg("walk-script", WALK_SCRIPT) + " chybi")
		return
	var pair := _fake()
	var map = pair[0]
	var td = pair[1]
	var walk = _new(script, map, td)

	# 1) volna dlazdice: jde se, z se bere z ROHU (landCenter, `Map.GetAverageZ`)
	var free: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(free["ok"] == true and int(free["z"]) == 0 and str(free["reason"]) == "",
		"world.walk: volna trava na vychod (dir 0) vraci ok (namEReno %s)" % str(free))

	# 1b) ⚠ V4 (2026-10-07): vyska se pocita z HORNICH HRAN, ne z `dz` jednoho
	#     `z` mapy (`REVIZE-POHYB` §2.4; `Movement.cs:170-171,319-321`).
	#     Náhorní PLOSINA (vsechny 4 rohy vysky +3) se nevyjde - `stepTop =
	#     startTop + 2` je nizsi nez `landLow = 3`.
	var plocha := [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6), Vector2i(7, 6)]
	for bod in plocha:
		map.zs[bod] = 3
	var plosina3: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(plosina3["ok"] == false and str(plosina3["reason"]) == "height",
		"world.walk: plosina o 3 (> STEP_HEIGHT 2) vraci reason 'height' (namEReno %s)" % str(plosina3))
	for bod in plocha:
		map.zs[bod] = 2
	var step2: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(step2["ok"] == true and int(step2["z"]) == 2,
		"world.walk: plosina o 2 (STEP_HEIGHT) jeste jde a stoji se na ni (namEReno %s)" % str(step2))
	for bod in plocha:
		map.zs[bod] = 0

	# 1c) OSAMOCENA dlazdice se zvednutym `z` (rohy 3,0,0,0) se PODARI: `landLow`
	#     je z rohu (0), ne z dlazdice. Stojna vyska je `landCenter` = 0 - prumer
	#     dvojice s VETSiM rozdilem (`GetAverageZ`, Map.cs:587-594: |3-0| > |0-0|,
	#     takze se prumeruji rohy (x,y+1) a (x+1,y)). Je to vlastnost reference,
	#     ne nase volba - proto se meri, aby ji nikdo "neopravil" potichu.
	map.zs[Vector2i(6, 5)] = 3
	var spice: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(spice["ok"] == true and int(spice["z"]) == 0,
		"world.walk: osamoceny zvednuty roh je pruchozeny a stoji se na landCenter (namEReno %s)" % str(spice))
	map.zs[Vector2i(6, 5)] = 0

	# 1d) ⚠ V4: SVAH se VYJDE i kdyz je rozdil PRUMERU 4 (stare pravidlo `dz <= 2`
	#     ho blokovalo - presne to uzivatel hlasi jako "do kopce me nepusti").
	#     Dlazdice (6,5) ma rohy [4,8,4,8] (svah na vychod), stojim na (5,5) v z=2
	#     (coz je landCenter te dlazdice: jeji rohy jsou [0,4,0,4]) -> startTop =
	#     max(top(5,5)=4, 2) = 4, strop = 6 >= low(6,5) = 4 -> jde se, z = 6.
	map.zs[Vector2i(6, 5)] = 4
	map.zs[Vector2i(7, 5)] = 8
	map.zs[Vector2i(6, 6)] = 4
	map.zs[Vector2i(7, 6)] = 8
	var svah: Dictionary = walk.can_step(Vector3i(5, 5, 2), 0, Const.PERSON_HEIGHT, true)
	t._check(svah["ok"] == true and int(svah["z"]) == 6,
		"world.walk: svah o 4 se vyjde (rohy), z = prumer rohu 6 (namEReno %s)" % str(svah))
	# 1e) ⚠ V4: DOLU nema reference zadny limit (`Movement.cs` dolni mez nezna).
	#     Stare pravidlo blokovalo `dz < -PERSON_HEIGHT`; dnes se skoci i o 40 dolu.
	var dolu: Dictionary = walk.can_step(Vector3i(5, 5, 40), 0, Const.PERSON_HEIGHT, true)
	t._check(dolu["ok"] == true and int(dolu["z"]) == 6,
		"world.walk: dolu bez limitu (z 40 na svah, z=6) (namEReno %s)" % str(dolu))
	for bod in plocha:
		map.zs[bod] = 0

	# 1d2) ⚠ V4: `startTop` je HORNI HRANA (nejvyssi roh) toho, na cem postava
	#      stoji - ne jeji `z`. Stojim na (5,5), jejiz rohy jsou [0,6,0,6] (roh na
	#      vychod patri cili), takze `top = 6` a `landCenter = 3`; postava stoji
	#      v `z = 3`. Cil (6,5) ma rohy [6,10,6,10] -> `low = 6`, `landCenter = 8`.
	#      S `startTop = max(6, 3) = 6` je strop `6 + 2 = 8 >= 6` -> JDE SE
	#      (a stoji se v 8). Kdyby se `startTop` vzalo z `from.z = 3`, byl by
	#      strop 5 < 6 -> blok: tuhle vetev meri tahle kontrola.
	map.zs[Vector2i(5, 5)] = 0
	map.zs[Vector2i(5, 6)] = 0
	map.zs[Vector2i(6, 5)] = 6
	map.zs[Vector2i(7, 5)] = 10
	map.zs[Vector2i(6, 6)] = 6
	map.zs[Vector2i(7, 6)] = 10
	var start_top: Dictionary = walk.can_step(Vector3i(5, 5, 3), 0, Const.PERSON_HEIGHT, true)
	t._check(start_top["ok"] == true and int(start_top["z"]) == 8,
		"world.walk: startTop je horni hrana (nejvyssi roh), ne moje z (namEReno %s)"
			% str(start_top))
	for bod in [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6), Vector2i(7, 6)]:
		map.zs[bod] = 0

	# 2) voda (Wet) a zed (Impassable) blokuji - presne podle smlouvy
	map.land[Vector2i(6, 5)] = VODA
	var voda: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(voda["ok"] == false and str(voda["reason"]) == "blocked",
		"world.walk: voda vraci reason 'blocked' (namEReno %s)" % str(voda))
	map.land[Vector2i(6, 5)] = TRAVA
	# 2a) ZED ma v tiledata vysku 0 (jako 645 druhu Impassable artu) - i tak blokuje.
	map.statics[Vector2i(6, 5)] = [_statik(ZED, 6, 5, 0)]
	var zed: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(zed["ok"] == false and str(zed["reason"]) == "blocked",
		"world.walk: statik s Impassable vraci 'blocked' (namEReno %s)" % str(zed))
	# 2b) ID PROSTOR: `ZED` ma flagy az na `ZED + 0x4000`. Surove id je prazdne,
	#     takze kdyby je walk cetl bez offsetu, tahle kontrola spadne.
	t._check(td.flags(ZED) == 0 and td.flags(ZED + ITEM_OFFSET) == F_IMPASSABLE,
		"world.walk: fake ma flagy statiku az na id+0x4000 (surove 0x%08X, spravne 0x%08X)"
			% [td.flags(ZED), td.flags(ZED + ITEM_OFFSET)])
	map.statics.erase(Vector2i(6, 5))

	# 2c) VYSKOVE PASMO: statik hluboko pod nohama nebo vysoko nad hlavou neblokuje
	map.statics[Vector2i(6, 5)] = [_statik(NIZKO, 6, 5, -40)]
	var nizko: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(nizko["ok"] == true,
		"world.walk: Impassable statik 40 pod nohama neblokuje (namEReno %s)" % str(nizko))
	map.statics[Vector2i(6, 5)] = [_statik(VYSOKO, 6, 5, 60)]
	var vysoko: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(vysoko["ok"] == true,
		"world.walk: Impassable statik 44 nad hlavou neblokuje (namEReno %s)" % str(vysoko))
	map.statics.erase(Vector2i(6, 5))

	# 2d) DVERE: flagy maji v OBOU stavech `Impassable` - rozhoduje `world.doors`
	map.statics[Vector2i(6, 5)] = [_statik(DVER, 6, 5, 0)]
	var zavrene: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(zavrene["ok"] == false and str(zavrene["reason"]) == "blocked",
		"world.walk: ZAVRENE dvere blokuji (namEReno %s)" % str(zavrene))
	map.statics[Vector2i(6, 5)] = [_statik(DVER_OTEVRENE, 6, 5, 0)]
	var otevrene: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(otevrene["ok"] == true,
		"world.walk: OTEVRENE dvere neblokuji (namEReno %s)" % str(otevrene))
	t._check(td.flags(DVER + ITEM_OFFSET) == td.flags(DVER_OTEVRENE + ITEM_OFFSET),
		"world.walk: oba stavy dveri maji STEJNE flagy (0x%08X = 0x%08X) - stav je z `world.doors`"
			% [td.flags(DVER + ITEM_OFFSET), td.flags(DVER_OTEVRENE + ITEM_OFFSET)])
	# Zavrene dvere pod nohama (mimo pasmo) neblokuji - stejne pravidlo jako u zdi.
	map.statics[Vector2i(6, 5)] = [_statik(DVER, 6, 5, -40)]
	var dvere_nizko: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(dvere_nizko["ok"] == true,
		"world.walk: zavrene dvere 40 pod nohama neblokuji (namEReno %s)" % str(dvere_nizko))
	map.statics.erase(Vector2i(6, 5))

	# 2e) ⚠ V5 (2026-10-07): STATIK SE `Surface` ROZHODUJE I NAD VODOU. Uzivatel
	#     "pres most me nepusti (nad vodou)". Do teto session se voda kontrolovala
	#     DRIV nez statiky (`F_WET` -> `blocked`), takze molo nad vodou bylo
	#     nedosazitelne; reference ma statik kandidatem povrchu (`Movement.cs:211`)
	#     a most NENI entita - je to statik se `Surface`/`Bridge` (`TileData.cs:138`).
	#     Stojim na brehu v z=10, cilova dlazdice je VODA (z=-5), na ni prkno z=10.
	map.zs[Vector2i(5, 5)] = 10
	map.zs[Vector2i(5, 6)] = 10
	map.zs[Vector2i(6, 6)] = 10
	map.land[Vector2i(6, 5)] = VODA
	map.zs[Vector2i(6, 5)] = -5
	var voda_bez: Dictionary = walk.can_step(Vector3i(5, 5, 10), 0, Const.PERSON_HEIGHT, true)
	t._check(voda_bez["ok"] == false and str(voda_bez["reason"]) == "blocked",
		"world.walk: do vody se nesmi (bez prkna) (namEReno %s)" % str(voda_bez))
	map.statics[Vector2i(6, 5)] = [_statik(PRKNO, 6, 5, 10)]
	var molo: Dictionary = walk.can_step(Vector3i(5, 5, 10), 0, Const.PERSON_HEIGHT, true)
	t._check(molo["ok"] == true and int(molo["z"]) == 11,
		"world.walk: prkno nad vodou je pruchozeny povrch (z=11) (namEReno %s)" % str(molo))
	map.statics.erase(Vector2i(6, 5))

	# 2f) ⚠ V4 bod 3: statik s `Bridge` (0x400) ma `CalcHeight = vyska/2` a jeho
	#     strop pro krok je jen `itemZ` (`TileData.cs:112-125`, `Movement.cs:233-234`).
	#     Stejna vyska 4 na vode: s `Bridge` se vstoupi (stojim 10 + 4/2 = 12),
	#     bez nej ne (strop 12 < itemTop 14) - rozhoduje JEN flag.
	map.statics[Vector2i(6, 5)] = [_statik(MOST, 6, 5, 10)]
	var most: Dictionary = walk.can_step(Vector3i(5, 5, 10), 0, Const.PERSON_HEIGHT, true)
	t._check(most["ok"] == true and int(most["z"]) == 12,
		"world.walk: Bridge puli vysku (10 + 4/2 = 12) (namEReno %s)" % str(most))
	map.statics[Vector2i(6, 5)] = [_statik(PLOSINA, 6, 5, 10)]
	var bez_mostu: Dictionary = walk.can_step(Vector3i(5, 5, 10), 0, Const.PERSON_HEIGHT, true)
	t._check(bez_mostu["ok"] == false and str(bez_mostu["reason"]) == "height",
		"world.walk: stejne vysoka plosina BEZ Bridge se nevyjde (namEReno %s)" % str(bez_mostu))
	map.statics.erase(Vector2i(6, 5))
	map.land[Vector2i(6, 5)] = TRAVA
	map.zs[Vector2i(6, 5)] = 0
	map.zs[Vector2i(5, 5)] = 0
	map.zs[Vector2i(5, 6)] = 0
	map.zs[Vector2i(6, 6)] = 0

	# 3) statik s `Surface` ZVEDNE povrch; `Wall` (dekor) ho nezvysuje
	map.statics[Vector2i(6, 5)] = [_statik(PLOSINA, 6, 5, 10)]
	t._check(walk.surface_z(6, 5) == 14,
		"world.walk: surface_z = z 10 + height 4 = 14 (namEReno %d)" % walk.surface_z(6, 5))
	map.statics[Vector2i(6, 5)] = [_statik(DECOR, 6, 5, 10)]
	t._check(walk.surface_z(6, 5) == 0,
		"world.walk: statik bez `Surface` povrch nezveda (namEReno %d)" % walk.surface_z(6, 5))
	map.statics.erase(Vector2i(6, 5))

	# 3b) SCHODY: povrch je `z + vyska` a krok nahoru se povoluje do vysky schodu
	#     (namEReno v realne mape: skok mezi sousednimi schody = presne vyska schodu)
	map.statics[Vector2i(6, 5)] = [_statik(SCHOD, 6, 5, 0)]
	t._check(walk.surface_z(6, 5) == 5,
		"world.walk: schod z 0 s vyskou 5 ma povrch 5 (namEReno %d)" % walk.surface_z(6, 5))
	map.zs[Vector2i(5, 5)] = 3
	var schod_nahoru: Dictionary = walk.can_step(Vector3i(5, 5, 3), 0, Const.PERSON_HEIGHT, true)
	t._check(schod_nahoru["ok"] == true and int(schod_nahoru["z"]) == 5,
		"world.walk: na schod nahoru o 2 se jde (namEReno %s)" % str(schod_nahoru))
	map.zs[Vector2i(5, 5)] = 0
	var schod_z_nuly: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(schod_z_nuly["ok"] == true and int(schod_z_nuly["z"]) == 5,
		"world.walk: z nuly na schod (0 -> 5 = vyska schodu) se jde (namEReno %s)" % str(schod_z_nuly))
	map.statics[Vector2i(6, 5)] = [_statik(SCHOD, 6, 5, 3)]
	var schod_vyse: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(schod_vyse["ok"] == false and str(schod_vyse["reason"]) == "height",
		"world.walk: schod o 8 vys (vic nez jeho vyska) vraci 'height' (namEReno %s)" % str(schod_vyse))
	map.statics[Vector2i(6, 5)] = [_statik(SCHOD, 6, 5, 0)]
	var schod_dolu: Dictionary = walk.can_step(Vector3i(5, 5, 8), 0, Const.PERSON_HEIGHT, true)
	t._check(schod_dolu["ok"] == true and int(schod_dolu["z"]) == 5,
		"world.walk: ze schodu se jde i dolu (8 -> 5, namEReno %s)" % str(schod_dolu))
	# Bez schodu plati dal STEP_HEIGHT: stejna vyska 5 uz 'height' je.
	map.statics[Vector2i(6, 5)] = [_statik(PLOSINA, 6, 5, 1)]
	var plosina_5: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(plosina_5["ok"] == false and str(plosina_5["reason"]) == "height",
		"world.walk: plosina (ne schod) o 5 vraci 'height' (namEReno %s)" % str(plosina_5))
	map.zs[Vector2i(5, 5)] = 0
	map.statics.erase(Vector2i(6, 5))

	# 4) statik z JINE dlazdice v tomtez bloku se nesmi pocitat
	#    (`world.map.statics_at` vraci cely blok - vada ZADANI 15)
	map.statics[Vector2i(6, 5)] = [_statik(PLOSINA, 7, 5, 10)]
	t._check(walk.surface_z(6, 5) == 0,
		"world.walk: statik s lokalnim x=7 nepatri dlazdici 6 (namEReno %d)" % walk.surface_z(6, 5))
	map.statics.erase(Vector2i(6, 5))

	# 5) mimo mapu a neplatny smer
	map.land.erase(Vector2i(6, 5))
	var off: Dictionary = walk.can_step(Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
	t._check(off["ok"] == false and str(off["reason"]) == "off_map",
		"world.walk: dlazdice mimo mapu vraci 'off_map' (namEReno %s)" % str(off))
	map.land[Vector2i(6, 5)] = TRAVA
	var bad: Dictionary = walk.can_step(Vector3i(5, 5, 0), 8, Const.PERSON_HEIGHT, true)
	t._check(bad["ok"] == false and str(bad["reason"]) == "bad_dir",
		"world.walk: smer 8 vraci 'bad_dir' (namEReno %s)" % str(bad))

	# 6) ASYMETRICKA DIAGONALA - jadro smlouvy (docs/04 §4.6.1)
	#    hrac potrebuje pruchodne OBE ortogonalni dlazdice, NPC jen jednu.
	map.statics[Vector2i(6, 5)] = [_statik(ZED, 6, 5, 0)]
	var hrac: Dictionary = walk.can_step(Vector3i(5, 5, 0), 1, Const.PERSON_HEIGHT, true)
	t._check(hrac["ok"] == false and str(hrac["reason"]) == "diagonal",
		"world.walk: hrac u rohu nesmi diagonalizovat (namEReno %s)" % str(hrac))
	var npc: Dictionary = walk.can_step(Vector3i(5, 5, 0), 1, Const.PERSON_HEIGHT, false)
	t._check(npc["ok"] == true,
		"world.walk: NPC muze diagonalizovat i u rohu (namEReno %s)" % str(npc))
	map.statics.erase(Vector2i(6, 5))
	# 6b) ... a ani pres ZAVRENE dvere se diagonalne nesmi (stav dveri plati i pro `_passable`)
	map.statics[Vector2i(6, 5)] = [_statik(DVER, 6, 5, 0)]
	var diag_dvere: Dictionary = walk.can_step(Vector3i(5, 5, 0), 1, Const.PERSON_HEIGHT, true)
	t._check(diag_dvere["ok"] == false and str(diag_dvere["reason"]) == "diagonal",
		"world.walk: pres zavrene dvere se nesmi diagonalne (namEReno %s)" % str(diag_dvere))
	map.statics.erase(Vector2i(6, 5))

	# 7) prazdna zavislost nesmi spadnout (mapa bez dat vraci off_map, ne pád)
	var prazdny = script.new(null, null, null)
	var r: Dictionary = prazdny.can_step(Vector3i(0, 0, 0), 0, Const.PERSON_HEIGHT, false)
	t._check(r.has("ok") and r.has("z") and r.has("reason"),
		"world.walk: bez realnych dat vraci tvar {ok, z, reason} (namEReno %s)" % str(r))

	# 7b) FIXTURE mapy z gitu (funguje i v CI): `surface_z` musi byt to, co rika
	#     mapa - kdyz na dlazdici neni statik, walk si zadne z nevymysli.
	if FileAccess.file_exists("res://tests/fixtures/world/map0.meta.json"):
		# `Lib.script_at` vraci null i pro soubor s parse errorem (jinak by se
		# case pres `new()` prerusil a zbytek kontrol by tise zmizel).
		var MapScript = Lib.script_at("res://sim/world/map.gd")
		if MapScript == null:
			t._pending("world.walk: sim/world/map.gd se nenacetl (parse error?)")
			return
		var fix = MapScript.new("res://tests/fixtures/world/map0")
		var z_mapy: int = fix.z_at(0, 0)
		var z_walku: int = _new(script, fix, td).surface_z(0, 0)
		t._check(z_walku == z_mapy,
			"world.walk: bez statiku je surface_z tolik co z mapy (%d vs %d)" % [z_walku, z_mapy])
		var fix_walk = _new(script, fix, td)
		# ⚠ V4: stojna vyska je `landCenter` z ROHU cilove dlazdice, ne jeji
		# `z_at` (na fixture vychazi -7 proti -11 v mape). Test proto meri
		# ROZSAH rohu a to, ze se jde - ne jednu hodnotu, ktera by jen
		# zrcadlila implementaci.
		var rohy := [fix.z_at(1, 0), fix.z_at(2, 0), fix.z_at(1, 1), fix.z_at(2, 1)]
		var r_low: int = mini(mini(int(rohy[0]), int(rohy[1])), mini(int(rohy[2]), int(rohy[3])))
		var r_top: int = maxi(maxi(int(rohy[0]), int(rohy[1])), maxi(int(rohy[2]), int(rohy[3])))
		var krok: Dictionary = fix_walk.can_step(Vector3i(0, 0, z_mapy), 0, Const.PERSON_HEIGHT, false)
		t._check(krok["ok"] == true and int(krok["z"]) >= r_low and int(krok["z"]) <= r_top,
			"world.walk: na fixture se da jit na vychod a z je z ROHU cile (namEReno %s, rohy %d..%d, z_at cile %d)"
				% [str(krok), r_low, r_top, fix.z_at(1, 0)])
	else:
		print("[test]      NEMERENO: world.walk nad fixture - chybi tests/fixtures/world/map0.meta.json")

	# 8) REALNA DATA se meri navic, jen kdyz na disku jsou (jinak nahlas NEMERENO)
	if not FileAccess.file_exists("res://assets/uo/tiles.json"):
		print("[test]      NEMERENO: world.walk nad realnou tiledata - chybi assets/uo/tiles.json")
		return
	var real = script.new()
	t._check(real.surface_z(1495, 1630) >= Const.Z_MIN and real.surface_z(1495, 1630) <= Const.Z_MAX,
		"world.walk: realny surface_z v Britanii je v rozsahu z (%d)" % real.surface_z(1495, 1630))
	var pocet_ok := 0
	for dir in 8:
		var vysledek: Dictionary = real.can_step(Vector3i(1495, 1630, real.surface_z(1495, 1630)), dir,
			Const.PERSON_HEIGHT, true)
		if vysledek["ok"]:
			pocet_ok += 1
	t._check(pocet_ok > 0,
		"world.walk: z britskeho namesti se da jit aspon jednim smerem (namEReno %d z 8)" % pocet_ok)

	# 8b) REALNE SCHODY: `world.stairs` zna art a jeho vyska se pocita do povrchu
	#     PRES `CalcHeight` (`TileData.cs:112-125`): `Bridge` (0x400) puli vysku.
	#     NamEReno: `stone stairs` (art 1823) ma flagy 0x2600 - `Bridge` MEZI NIMI,
	#     takze stojna vyska je `z + 5/2 = z + 2` (drive test cekal `z + 5`,
	#     coz byla nase vlastni, ne referencni hodnota).
	var StairsScript = Lib.script_at("res://sim/world/stairs.gd")
	if StairsScript == null:
		t._pending("world.walk: sim/world/stairs.gd se nenacetl (parse error?)")
		return
	var schody = StairsScript.new()
	var nasel := -1
	var ocekavany := 0
	var zmereny := 0
	var flagy_nalezu := 0
	for y in range(1560, 1610):
		for x in range(1470, 1530):
			var vrchol := -99999
			var ma_schod := -1
			var flagy := 0
			for s in real._map.statics_at(x, y):
				if int(s["x"]) != x % Const.BLOCK_SIZE or int(s["y"]) != y % Const.BLOCK_SIZE:
					continue
				var tile: int = int(s["tile"])
				var fl: int = real._tiledata.flags(tile + ITEM_OFFSET)
				if fl & F_SURFACE == 0:
					continue
				var h: int = real._tiledata.height(tile + ITEM_OFFSET)
				var calc: int = h / 2 if fl & F_BRIDGE != 0 else h
				var top: int = int(s["z"]) + calc
				if top > vrchol:
					vrchol = top
					ma_schod = tile if schody.is_stair(tile) else -1
					flagy = fl
			if ma_schod >= 0 and vrchol > real._map.z_at(x, y):
				nasel = ma_schod
				ocekavany = vrchol
				zmereny = real.surface_z(x, y)
				flagy_nalezu = flagy
	t._check(nasel >= 0 and zmereny == ocekavany,
		"world.walk: povrch realneho schodu je `z + CalcHeight` (art %d, flagy 0x%08X: mereno %d, ocekavano %d)"
			% [nasel, flagy_nalezu, zmereny, ocekavany])
	t._check(flagy_nalezu & F_BRIDGE != 0,
		"world.walk: nalezeny schod ma `Bridge` (0x%08X) - proto se vyska pultí" % flagy_nalezu)

	# 8c) REALNE DVERE: stav bere walk z `world.doors` (art z `data/doors.json`).
	#     Konvence (8. session, `world.doors`): art z `doors.txt` je ZAVRENY a
	#     `art + 1` je OTEVRENY. Test netvrdi, KTERA dvojice to je (to je vec
	#     `world.doors`), jen to, ze se walk na stav opravdu ptá: zavreny art
	#     blokuje, otevreny ne.
	var DoorsScript = Lib.script_at("res://sim/world/doors.gd")
	if DoorsScript == null:
		t._pending("world.walk: sim/world/doors.gd se nenacetl (parse error?)")
		return
	var dvere = DoorsScript.new()
	var kat: int = -1
	var zavreny := 0
	var otevreny := 0
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/doors.json"))["rows"]:
		for i in range(1, 9):
			var tile: int = int(row.get("piece%d" % i, 0))
			if tile != 0 and not dvere.is_open(tile) and dvere.is_open(tile + 1):
				kat = int(row.get("category", -1))
				zavreny = tile
				otevreny = tile + 1
				break
		if kat >= 0:
			break
	t._check(kat >= 0 and zavreny != 0 and otevreny != 0,
		"world.walk: v `data/doors.json` je dvojice zavreny/otevreny art (kat %d: %d / %d)"
			% [kat, zavreny, otevreny])
	if kat >= 0:
		# Flagy se do fake tabulky daji STEJNE jako v realnych datech (oba stavy
		# maji `Door` + `Impassable`) - stav pak muze prijit jen z `world.doors`.
		td.f[zavreny + ITEM_OFFSET] = F_DOOR | F_IMPASSABLE
		td.h[zavreny + ITEM_OFFSET] = 20
		td.f[otevreny + ITEM_OFFSET] = F_DOOR | F_IMPASSABLE
		td.h[otevreny + ITEM_OFFSET] = 20
		map.statics[Vector2i(6, 5)] = [_statik(zavreny, 6, 5, 0)]
		var z_real: Dictionary = script.new(map, td, FakeStairs.new(), dvere).can_step(
			Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
		map.statics[Vector2i(6, 5)] = [_statik(otevreny, 6, 5, 0)]
		var o_real: Dictionary = script.new(map, td, FakeStairs.new(), dvere).can_step(
			Vector3i(5, 5, 0), 0, Const.PERSON_HEIGHT, true)
		map.statics.erase(Vector2i(6, 5))
		t._check(z_real["ok"] == false and o_real["ok"] == true,
			"world.walk: se stavem z `world.doors` zavreny art %d blokuje a otevreny %d ne (namEReno %s / %s)"
				% [zavreny, otevreny, str(z_real), str(o_real)])
