extends RefCounted
# `world.tiledata` - TexID (textura terenu pro SVAHY).
#
# Proc prave tohle: uzivatel 2026-10-07 nahlasil "kde je svah, tam neni tile".
# NamEReno: na prechodu vysky NENI chybejici art, ale NEVYKRESLENA PLOCHA -
# UO kresli rovnou dlazdici land artem a SVAH texturou z `texmaps.mul`, jejiz
# index je pole `texture` (TexID) v tiledata (ClassicUO `Land.cs:96-161`).
# Do 12. session `world.tiledata` tenhle sloupec VUBEC neumel - chybelo tedy
# to, z ceho kresleni pozna svah.
#
# Test je proto dvoucastny:
#   * VZDY se meri poradi poli v layoutu (konstanta `LAND_TEXTURE`) - to je
#     smlouva se souborem `tiles.json` a v CI (bez `assets/uo`) se overit da,
#   * s `assets/uo/tiles.json` se meri konkretni hodnoty na realnych datech
#     (bez nich se hlasi NEMERENO, ne selhani - viz HANDOFF "Předletová kontrola").

const Lib = preload("res://tests/lib.gd")

const TILEDATA_SCRIPT := "res://sim/world/tiledata.gd"
const TILES := "res://assets/uo/tiles.json"
# LAND zaznam je 30 B `[u64 flags][u16 texture][20 B jmeno]` (docs/03 §3.3.1).
# Konstanta `LAND_TEXTURE` v modulu je INDEX v poli, ne offset v bajtech.
const LAND_TEXTURE_INDEX := 1


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("tiledata-script", TILEDATA_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("world.tiledata NENI HOTOVA: " + cesta + " chybi")
		return
	var consts: Dictionary = Lib.consts_at(cesta)

	# 1) VZDY: konstanta modulu musi sedet na poradi poli v souboru. Kdyby se
	#    sablona `tiles.json` zmenila, test to rekne (a hodnoty nize by se
	#    tise cetly z jineho sloupce).
	t._check(int(consts.get("LAND_TEXTURE", -1)) == LAND_TEXTURE_INDEX,
		"world.tiledata: LAND_TEXTURE = %s (layout land_fields: flags, texture, name)"
		% str(consts.get("LAND_TEXTURE")))

	if not FileAccess.file_exists(TILES):
		# NEMERENO, ne selhani: `assets/uo` je v .gitignore, takze v CI nejsou.
		print("[test]      NEMERENO: chybi ", TILES, " (v CI) - hodnoty TexID se nedaji zmerit")
		return

	var td = script.new()
	# 2) ZNAMA DATA z realne instalace (names i TexID se ctou z tiledata):
	#    travník a pisek maji TexID == id, svahove dlazdice u pobrezi (81..100,
	#    'NoName') maji VSECHNY TexID 76 - a prave proto se dosud kreslily
	#    jako "dira" (atlas je mel podle id, ne podle TexID).
	var ocekavane := {3: 3, 6: 6, 34: 34, 76: 76, 100: 76, 168: 0}
	var chyby := ""
	for tile in ocekavane.keys():
		var je: int = td.texture(int(tile))
		if je != int(ocekavane[tile]):
			chyby += " land %d: %d != %d;" % [tile, je, int(ocekavane[tile])]
	t._check(chyby == "",
		"world.tiledata: texture() vraci TexID z realnych dat (chyby:%s)" % chyby)

	# 3) Vsech 12 druhu dlazdic u pobrezi (okno, kde byla dira) ma TexID 76.
	var u_pobrezi := 0
	var se_spatnym := 0
	for tile in range(78, 101):
		var tex: int = td.texture(tile)
		if tex == 76:
			u_pobrezi += 1
		elif tex != 0:
			se_spatnym += 1
	t._check(u_pobrezi >= 20 and se_spatnym == 0,
		"world.tiledata: dlazdice 78..100 maji TexID 76 (u pobrezi: %d, jinych: %d)"
		% [u_pobrezi, se_spatnym])

	# 4) U PREDMETU TexID neexistuje - `texture()` musi vratit 0, ne nahodny
	#    sloupec z item zaznamu (item pole `weight` je na indexu 1!).
	t._check(td.texture(0x4000 + 100) == 0 and td.texture(0x4EED) == 0,
		"world.tiledata: texture() na predmet vraci 0 (namEReno %d, %d)"
		% [td.texture(0x4000 + 100), td.texture(0x4EED)])
