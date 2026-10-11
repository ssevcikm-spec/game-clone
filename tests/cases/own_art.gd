extends RefCounted
# Vlastni art PO KUSECH (2026-10-11) - `render.own_art`, `render.textures`
# a `render.anim` dohromady. Test meri CHOVANI, ne "soubor existuje":
#
#   * konfigurace se hlasi SEZNAMEM chyb (ne tichym prazdnem),
#   * pro (kind, id) z vlastni vrstvy vyhraje VLASTNI textura I VLASTNI offset
#     (kdyby se textura brala z vlastni a offset z UO, sprite sedi vedle -
#     `tools/artgen/SEAM.md` §2 bod 2),
#   * co vlastni vrstva NEMA (nebo co z ni vyber po kusech vyhodil), zustane
#     PRESNE totez jako s vypnutym vlastnim artem,
#   * animace se prepinaji po KLICI (vlastni chuze vyhrava, idle zustava z UO)
#     a `play()` hlasi, odkud sprite je (`own`).
#
# Fixture se vyrabi za behu v `.cache/test-own-art/` (jako `render_textures.gd`),
# takze test meri i v CI, kde `assets/uo/` ani `assets/own*/` nejsou potreba.
#
# Cesta k merenym souborum je VSTUP (`-- --own-script=`, `--textures-script=`,
# `--anim-script=`), aby na nich sel pustit mutacni harness.

const Lib = preload("res://tests/lib.gd")

const OWN_SCRIPT := "res://render/own_art.gd"
const CACHE_SCRIPT := "res://render/texture_cache.gd"
const ANIM_SCRIPT := "res://render/anim_player.gd"
const SLUZKA := "res://.cache/test-own-art"
# Typy v prostorech: land = id, item = id + 0x4000.
const ITEM := 0x4000
const LAND_VLASTNI := 7          # vlastni vrstva ho ma
const ITEM_VLASTNI := 9          # vlastni vrstva ho ma
const ITEM_VYHOZENY := 11        # JE v manifestu, ale vyber po kusech ho vyhodi
const LAND_CIZI := 8             # vlastni vrstva ho nema -> z UO


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _png(cesta: String, barva: Color) -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(barva)
	img.save_png(cesta)


func _zapis(cesta: String, text: String) -> void:
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _vyrob_fixture() -> Dictionary:
	# Vsechno ABSOLUTNE: v headless Godot nevidi resource soubor, ktery test
	# teprve vytvoril (stejna past jako v `render_textures.gd`).
	var zaklad := ProjectSettings.globalize_path(SLUZKA)
	DirAccess.make_dir_recursive_absolute(zaklad + "/own/anim")
	DirAccess.make_dir_recursive_absolute(zaklad + "/uo/anim")
	_png(zaklad + "/own/own0.png", Color(0.9, 0.2, 0.1, 1.0))
	_png(zaklad + "/uo/uo0.png", Color(0.1, 0.4, 0.9, 1.0))
	_png(zaklad + "/own/anim/ownwalk.png", Color(0.9, 0.7, 0.1, 1.0))
	_png(zaklad + "/uo/anim/uowalk.png", Color(0.2, 0.6, 0.2, 1.0))
	_png(zaklad + "/uo/anim/uoidle.png", Color(0.5, 0.5, 0.5, 1.0))

	_zapis(zaklad + "/own/manifest.json", JSON.stringify({"sprites": [
		{"kind": "land", "id": LAND_VLASTNI, "page": "own0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 1, "oy": 2},
		{"kind": "item", "id": ITEM_VLASTNI, "page": "own0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 3, "oy": 4},
		{"kind": "item", "id": ITEM_VYHOZENY, "page": "own0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 8, "oy": 8},
	]}))
	_zapis(zaklad + "/uo/manifest.json", JSON.stringify({"sprites": [
		{"kind": "land", "id": LAND_VLASTNI, "page": "uo0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 0, "oy": 0},
		{"kind": "land", "id": LAND_CIZI, "page": "uo0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 5, "oy": 6},
		{"kind": "item", "id": ITEM_VLASTNI, "page": "uo0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 9, "oy": 9},
		{"kind": "item", "id": ITEM_VYHOZENY, "page": "uo0.png", "x": 0, "y": 0,
			"w": 4, "h": 4, "ox": 7, "oy": 7},
	]}))
	# Vlastni anim list ma JEN klic `400/0/0` (chuze, smer 7 = SE, DIR_MAP[7][0] = 0).
	# UO list ma navic `400/4/0` (idle), ktery vlastni sada NEMA -> musi zustat z UO.
	_zapis(zaklad + "/own/anim/sheets.json", JSON.stringify({"sprites": {
		"400/0/0": {"file": "ownwalk.png", "frames": [
			{"cx": 2, "cy": -2, "w": 4, "h": 4, "rect": [0, 0, 4, 4]}]},
	}}))
	_zapis(zaklad + "/uo/anim/sheets.json", JSON.stringify({"sprites": {
		"400/0/0": {"file": "uowalk.png", "frames": [
			{"cx": 2, "cy": -2, "w": 4, "h": 4, "rect": [0, 0, 4, 4]}]},
		"400/4/0": {"file": "uoidle.png", "frames": [
			{"cx": 2, "cy": -2, "w": 4, "h": 4, "rect": [0, 0, 4, 4]}]},
	}}))

	var vlastni: Dictionary = {
		"name": "nase", "manifest": zaklad + "/own/manifest.json",
		"anim": zaklad + "/own/anim/sheets.json",
		"sprites": {"land": [LAND_VLASTNI], "item": [ITEM_VLASTNI]},
	}
	var config := zaklad + "/own-art.json"
	_zapis(config, JSON.stringify({"version": 1, "layers": [vlastni]}))
	return {"zaklad": zaklad, "config": config, "vrstva": vlastni,
		"own_manifest": zaklad + "/own/manifest.json",
		"uo_manifest": zaklad + "/uo/manifest.json"}


func run(t) -> void:
	var own_script = Lib.script_at(_arg("own-script", OWN_SCRIPT))
	var cache_script = Lib.script_at(_arg("textures-script", CACHE_SCRIPT))
	var anim_script = Lib.script_at(_arg("anim-script", ANIM_SCRIPT))
	if own_script == null or cache_script == null or anim_script == null:
		t._pending("vlastni art NENI HOTOVY: chybi render/own_art.gd, render/texture_cache.gd nebo render/anim_player.gd")
		return
	var f: Dictionary = _vyrob_fixture()
	_mer_konfiguraci(t, own_script, f)
	_mer_atlas(t, cache_script, f)
	_mer_animace(t, anim_script, f)


func _mer_konfiguraci(t, own_script, f: Dictionary) -> void:
	# 1) SPRAVNA konfigurace: ok, vrstvy, zadne chyby
	var cfg: Dictionary = own_script.load_config(f["config"])
	t._check(bool(cfg["ok"]) and cfg["layers"].size() == 1 and int(cfg["errors"].size()) == 0,
		"render.own_art: platna konfigurace -> ok=%s, vrstev %d, chyb %d"
			% [str(cfg["ok"]), cfg["layers"].size(), cfg["errors"].size()])
	var vrstva: Dictionary = cfg["layers"][0] if cfg["layers"].size() > 0 else {}
	t._check(str(vrstva.get("page_prefix", "")).ends_with("/own/"),
		"render.own_art: vrstva si nese VLASTNI prefix stranek (vyslo '%s')"
			% str(vrstva.get("page_prefix", "")))

	# 2) CHYBY SE Hlasi SEZNAMEM (ne tichym prazdnem) - tri zname vadne vstupy
	var zaklad: String = f["zaklad"]
	var chybujici := {}
	chybujici["neznamy_druh"] = {"version": 1, "layers": [{
		"name": "x", "manifest": zaklad + "/own/manifest.json",
		"sprites": {"gump": [1]}}]}
	var bez_manifestu: Dictionary = f["vrstva"].duplicate()
	bez_manifestu["manifest"] = zaklad + "/neexistuje.json"
	chybujici["chybi_manifest"] = {"version": 1, "layers": [bez_manifestu]}
	var prekryv: Dictionary = f["vrstva"].duplicate()
	prekryv["name"] = "druha"
	chybujici["prekryv_id"] = {"version": 1, "layers": [f["vrstva"], prekryv]}
	for klic in chybujici.keys():
		var cesta: String = zaklad + "/vadna-%s.json" % klic
		_zapis(cesta, JSON.stringify(chybujici[klic]))
		var vysledek: Dictionary = own_script.load_config(cesta)
		t._check(not bool(vysledek["ok"]) and int(vysledek["errors"].size()) > 0,
			"render.own_art: vadna konfigurace '%s' se ODmitne s duvodem (ok=%s, chyb %d)"
				% [klic, str(vysledek["ok"]), int(vysledek["errors"].size())])


func _mer_atlas(t, cache_script, f: Dictionary) -> void:
	var own_script = Lib.script_at(_arg("own-script", OWN_SCRIPT))
	var vrstvy: Array = own_script.load_config(f["config"])["layers"]
	var prefix: String = f["zaklad"] + "/uo/"
	var cache_on = cache_script.new(f["uo_manifest"], 100 * 1024 * 1024, prefix, vrstvy)
	var cache_off = cache_script.new(f["uo_manifest"], 100 * 1024 * 1024, prefix)

	# 1) VLASTNI VYHRAVA: textura I offset ze STEJNEHO (vlastniho) zaznamu
	t._check(cache_on.page_path(LAND_VLASTNI).ends_with("/own/own0.png"),
		"render.textures: land %d bere stranku z vlastni vrstvy (vyslo '%s')"
			% [LAND_VLASTNI, cache_on.page_path(LAND_VLASTNI)])
	t._check(cache_on.offset(LAND_VLASTNI) == Vector2i(1, 2),
		"render.textures: land %d ma VLASTNI offset (vyslo %s, cekano (1, 2))"
			% [LAND_VLASTNI, str(cache_on.offset(LAND_VLASTNI))])
	t._check(cache_on.is_own(LAND_VLASTNI) and cache_on.is_own(ITEM + ITEM_VLASTNI),
		"render.textures: is_own() pozna vlastni sprity")
	t._check(cache_on.page_path(ITEM + ITEM_VLASTNI).ends_with("/own/own0.png")
			and cache_on.offset(ITEM + ITEM_VLASTNI) == Vector2i(3, 4),
		"render.textures: item %d bere stranku i offset z vlastni vrstvy (page '%s', offset %s)"
			% [ITEM_VLASTNI, cache_on.page_path(ITEM + ITEM_VLASTNI),
				str(cache_on.offset(ITEM + ITEM_VLASTNI))])

	# 2) VYBER PO KUSECH: id je ve vlastnim manifestu, ale v `sprites` neni ->
	#    musi zustat z UO (jinak by "vyber po kusech" nic nevybiral)
	t._check(cache_on.page_path(ITEM + ITEM_VYHOZENY).ends_with("/uo/uo0.png")
			and cache_on.offset(ITEM + ITEM_VYHOZENY) == Vector2i(7, 7)
			and not cache_on.is_own(ITEM + ITEM_VYHOZENY),
		"render.textures: id %d mimo vyber zustava z UO (page '%s', offset %s, own %s)"
			% [ITEM_VYHOZENY, cache_on.page_path(ITEM + ITEM_VYHOZENY),
				str(cache_on.offset(ITEM + ITEM_VYHOZENY)),
				str(cache_on.is_own(ITEM + ITEM_VYHOZENY))])

	# 3) FALLBACK SE NEMENI: id, ktere vlastni sada nema, je PRESNE jako s vypnutym
	var stejne: bool = (cache_on.page_path(LAND_CIZI) == cache_off.page_path(LAND_CIZI)
		and cache_on.offset(LAND_CIZI) == cache_off.offset(LAND_CIZI)
		and cache_on.texture(LAND_CIZI) != null
		and cache_on.texture(LAND_CIZI).region == cache_off.texture(LAND_CIZI).region)
	t._check(stejne,
		"render.textures: id %d bez vlastniho artu je se zapnutym i vypnutym vlastnim artem STEJNE"
			% LAND_CIZI)

	# 4) POCITADLA PUVODU: bez nich by se "vlastni art je zapnuty" nedalo overit
	var st_on: Dictionary = cache_on.stats()
	var st_off: Dictionary = cache_off.stats()
	t._check(int(st_on["own"]) == 2 and int(st_on["uo"]) == 2 and int(st_off["own"]) == 0,
		"render.textures: stats() deli sprity podle puvodu (own %d, uo %d, vypnuto own %d)"
			% [int(st_on["own"]), int(st_on["uo"]), int(st_off["own"])])
	t._check(cache_on.own_ids() == [LAND_VLASTNI, ITEM + ITEM_VLASTNI],
		"render.textures: own_ids() vraci obe vlastni id serazene (vyslo %s)"
			% str(cache_on.own_ids()))

	# 5) VYPNUTY VLASTNI ART: tyz kod, jen bez vrstev -> vsechno z UO
	t._check(cache_off.page_path(LAND_VLASTNI).ends_with("/uo/uo0.png")
			and cache_off.offset(LAND_VLASTNI) == Vector2i(0, 0)
			and not cache_off.is_own(LAND_VLASTNI),
		"render.textures: s vypnutym vlastnim artem je land %d z UO (page '%s', offset %s)"
			% [LAND_VLASTNI, cache_off.page_path(LAND_VLASTNI),
				str(cache_off.offset(LAND_VLASTNI))])


func _mer_animace(t, anim_script, f: Dictionary) -> void:
	var own_script = Lib.script_at(_arg("own-script", OWN_SCRIPT))
	var vrstvy: Array = own_script.load_config(f["config"])["layers"]
	var anim_on = anim_script.new(f["zaklad"] + "/uo/anim/sheets.json", null, vrstvy)
	var anim_off = anim_script.new(f["zaklad"] + "/uo/anim/sheets.json")

	# 1) VLASTNI CHUZE VYHRAVA - a `play()` to HLASI (`own`)
	var chuze: Dictionary = anim_on.play(400, 0, 7, 0)
	t._check(bool(chuze["ok"]) and bool(chuze["own"])
			and str(anim_on.sheet_file(400, 0, 7)).ends_with("/own/anim/ownwalk.png"),
		"render.anim: vlastni klic chuze vyhrava (ok=%s, own=%s, list '%s')"
			% [str(chuze["ok"]), str(chuze["own"]), anim_on.sheet_file(400, 0, 7)])
	t._check(anim_on.own_count() == 1 and not anim_on.is_own_key(400, 4, 7),
		"render.anim: own_count() = %d a idle NENI vlastni klic (ocekavano 1 a false)"
			% anim_on.own_count())

	# 2) CO VLASTNI SADA NEMA, ZUSTAVA Z UO - idle (akce 4) i cely vypnuty rezim
	var idle: Dictionary = anim_on.play(400, 4, 7, 0)
	t._check(bool(idle["ok"]) and not bool(idle["own"])
			and str(anim_on.sheet_file(400, 4, 7)).ends_with("/uo/anim/uoidle.png"),
		"render.anim: idle zustava z UO (ok=%s, own=%s, list '%s')"
			% [str(idle["ok"]), str(idle["own"]), anim_on.sheet_file(400, 4, 7)])
	var vypnuto: Dictionary = anim_off.play(400, 0, 7, 0)
	t._check(bool(vypnuto["ok"]) and not bool(vypnuto["own"])
			and str(anim_off.sheet_file(400, 0, 7)).ends_with("/uo/anim/uowalk.png")
			and anim_off.own_count() == 0,
		"render.anim: bez vlastnich vrstev je chuze z UO (own=%s, list '%s', vlastnich %d)"
			% [str(vypnuto["own"]), anim_off.sheet_file(400, 0, 7), anim_off.own_count()])
