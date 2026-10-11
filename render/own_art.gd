extends RefCounted
# render.own_art - KONFIGURACE vlastniho artu po kusech (granule render.own_art).
#
# CO TO JE: jedine misto, kde je receno, KTERA (kind, id) se berou z vlastniho
# artu a z KTERE sady. `render.textures` i `render.anim` dostanou hotovy seznam
# VRSTEV a indexuji je v tomto poradi PRED UO manifestem - tim plati
# "vlastni vyhrava, kde je; co tam neni, zustane z UO" (navrh `tools/artgen/SEAM.md`
# §2 a §4, kde je misto nazvane "prepinac: data, ne nova vetev kódu").
#
# ODCHYLKA OD `SEAM.md` §4 (s duvodem, ne tise): navrh pocital s JEDNOU vlastni
# sadou a se souborem `assets/own/pieces.json` uvnitr jejiho jmenneho prostoru.
# Dnes jsou sady DVE a kazda pokryva JINY kus téhož id prostoru:
#   * `assets/own-lit/` - teren a postava (1x SE SVETLEM, zaklad integrace),
#   * `assets/own/`     - placate predmety (dyka, ingot), protoze varianta se
#                         svetlem jim vzala stin a kontrast (MERENI.md §9).
# Kdyby vyber sady zustal uvnitr kazde sady, "kdo vyhrava" by se rozhodovalo na
# DVOU mistech. Prepinac je proto jeden soubor pro obe sady a poradi vrstev v
# nem je zaroven poradi priority.
#
# CO TENHLE MODUL NEDELA: necte atlas, nekresli, nemeni geometrii. Jen overi
# konfiguraci a prelozi cesty. Chyby vraci SEZNAMEM (nikdy tise): kdo si vezme
# `layers` bez kontroly `ok`, dostane prazdno a hra pojede na UO - to je sice
# bezpecne, ale nesmi to byt neviditelne (docs/08 §8.6).
#
# Pouziti:
#   var cfg = OwnArt.load_config()
#   if not cfg["ok"]: push_warning(...)
#   textures = TextureCache.new(path, bytes, prefix, cfg["layers"])

const DEFAULT_PATH := "res://assets/own-art.json"
const VERSION: int = 1
# Ktere druhy spritu umi manifest atlasu (stejny slovnik jako `render.textures`
# a `tools/uoextract/art.py`). "anim" tu ZAMERNE neni: animace nejdou z atlasu,
# ale z `anim-sheets.json` + PNG, a vybiraji se klícem `telo/akce/smer`.
const KINDS: Array = ["land", "item", "texmap"]


static func load_config(cesta: String = DEFAULT_PATH) -> Dictionary:
	# Vraci {"ok": bool, "cesta": String, "errors": Array[String], "layers": Array}
	# Vrstva: {"name", "manifest", "page_prefix", "anim", "sprites": {"land": [..]},
	#          "groups": {"land": [[id, id, ...]]}}
	# `groups` je NEPOVINNY (bez nej je chovani presne dnesni: jedno id = jedna
	# dlazdice) a znamena "tato id tehoz druhu jsou JEDEN MATERIAL" - variantu
	# z nich pak vybira `render.textures.variant_id(art_id, x, y)` podle
	# souradnic bunky. Skupina smi obsahovat jen id z `sprites` TE SAME vrstvy
	# (jinak by se michal vlastni art s UO) a zadne id nesmi byt ve dvou
	# skupinach - oboji je vada a hlasi se seznamem.
	var out: Dictionary = {"ok": false, "cesta": cesta, "errors": [], "layers": []}
	if not FileAccess.file_exists(cesta):
		out["errors"].append("konfigurace vlastniho artu chybi: " + cesta)
		return out
	var parsed = JSON.new()
	var chyba: int = parsed.parse(FileAccess.get_file_as_string(cesta))
	if chyba != OK:
		out["errors"].append("konfigurace se necte (%s, radek %d)"
			% [parsed.get_error_message(), parsed.get_error_line()])
		return out
	if not (parsed.data is Dictionary):
		out["errors"].append("konfigurace neni slovnik (tvar: %s)" % str(typeof(parsed.data)))
		return out
	var data: Dictionary = parsed.data
	var errors: Array = out["errors"]

	if int(data.get("version", -1)) != VERSION:
		errors.append("verze konfigurace je %s, ocekavana %d"
			% [str(data.get("version", null)), VERSION])
	var vrstvy = data.get("layers", null)
	if not (vrstvy is Array) or vrstvy.is_empty():
		errors.append("konfigurace nema zadnou vrstvu (prazdny seznam neni uspech)")
		return out

	var jmena: Dictionary = {}
	var obsazene: Dictionary = {}       # "kind|id" -> jmeno vrstvy (duplikat = vada)
	var obsazene_skupiny: Dictionary = {}   # "kind|id" -> vrstva, ktera ho ma ve skupine
	for i in vrstvy.size():
		var surova = vrstvy[i]
		var kde := "vrstva %d" % i
		if not (surova is Dictionary):
			errors.append("%s neni slovnik" % kde)
			continue
		var vrstva: Dictionary = surova
		# POZOR (namEReno 2026-10-11): `str(null)` je v GDScriptu "<null>", takze
		# `str(vrstva.get("anim",""))` na JSON `null` vyrobi NAZEV SOUBORU
		# "<null>" a konfigurace se tvari jako vadna. `null` se proto testuje
		# vyslovne, ne prevodem na retezec.
		var jmeno := "" if vrstva.get("name", null) == null else str(vrstva.get("name"))
		kde = "vrstva %d (%s)" % [i, jmeno if jmeno != "" else "bez jmena"]
		if jmeno == "":
			errors.append("%s nema 'name'" % kde)
			continue
		if jmena.has(jmeno):
			errors.append("%s: jmeno '%s' je pouzite dvakrat" % [kde, jmeno])
			continue
		jmena[jmeno] = true

		var manifest := "" if vrstva.get("manifest", null) == null else str(vrstva.get("manifest"))
		if manifest == "":
			errors.append("%s nema 'manifest'" % kde)
			continue
		if not FileAccess.file_exists(manifest):
			errors.append("%s: manifest '%s' neexistuje" % [kde, manifest])
			continue

		var sprites = vrstva.get("sprites", null)
		if not (sprites is Dictionary) or sprites.is_empty():
			errors.append("%s: 'sprites' musi byt neprazdny slovnik (jine druhy se z teto vrstvy neberou)"
				% kde)
			continue
		var vyber: Dictionary = {}
		var vyber_ok := true
		for kind in sprites.keys():
			var k := str(kind)
			if not KINDS.has(k):
				errors.append("%s: neznamy druh '%s' (povolene: %s)" % [kde, k, str(KINDS)])
				vyber_ok = false
				continue
			var ids = sprites[kind]
			if not (ids is Array) or ids.is_empty():
				errors.append("%s: druh '%s' nema zadny id" % [kde, k])
				vyber_ok = false
				continue
			var seznam: Array = []
			for id in ids:
				if not (id is float or id is int):
					errors.append("%s: '%s' obsahuje '%s', coz neni cislo id" % [kde, k, str(id)])
					vyber_ok = false
					continue
				var klicek := "%s|%d" % [k, int(id)]
				if obsazene.has(klicek):
					errors.append("%s: %s je uz ve vrstve '%s' - druha vrstva by se tise ignorovala"
						% [kde, klicek, str(obsazene[klicek])])
					vyber_ok = false
					continue
				obsazene[klicek] = jmeno
				seznam.append(int(id))
			vyber[k] = seznam
		if not vyber_ok:
			continue

		# SKUPINY VARIANT (granule `render.land_variants`, viz hlavicka
		# `render/texture_cache.gd`): nepovinny klic `groups`, napr.
		# `{"land": [[1002, 1003]]}` = "tato id jsou jeden material".
		# Kontroluje se TADY a seznamem chyb, protoze konfigurace je zdroj
		# pravdy: co neni v `sprites`, se z vrstvy nebere, takze skupina pres
		# neexistujici id by tise michala vlastni art s UO.
		var skupiny: Dictionary = {}
		var groups = vrstva.get("groups", null)
		if groups != null and not (groups is Dictionary):
			errors.append("%s: 'groups' musi byt slovnik (druh -> seznam skupin)" % kde)
			continue
		if groups is Dictionary:
			var skupiny_ok := true
			for kind in (groups as Dictionary).keys():
				var k := str(kind)
				if not KINDS.has(k):
					errors.append("%s: 'groups' ma neznamy druh '%s' (povolene: %s)" % [kde, k, str(KINDS)])
					skupiny_ok = false
					continue
				var seznam = (groups as Dictionary)[kind]
				if not (seznam is Array) or (seznam as Array).is_empty():
					errors.append("%s: 'groups.%s' musi byt neprazdny seznam skupin" % [kde, k])
					skupiny_ok = false
					continue
				var hotove: Array = []
				for g in seznam:
					if not (g is Array):
						errors.append("%s: 'groups.%s' obsahuje '%s', coz neni seznam id" % [kde, k, str(g)])
						skupiny_ok = false
						continue
					if (g as Array).size() < 2:
						errors.append("%s: 'groups.%s' ma skupinu o %d id - varianta potrebuje aspon 2"
							% [kde, k, (g as Array).size()])
						skupiny_ok = false
						continue
					var clenove: Array = []
					var skupina_ok := true
					for id in g:
						if not (id is float or id is int):
							errors.append("%s: 'groups.%s' obsahuje '%s', coz neni cislo id" % [kde, k, str(id)])
							skupina_ok = false
							continue
						var ident := int(id)
						if clenove.has(ident):
							errors.append("%s: 'groups.%s' ma id %d dvakrat v teze skupine" % [kde, k, ident])
							skupina_ok = false
							continue
						if not (vyber.get(k, []) as Array).has(ident):
							errors.append("%s: 'groups.%s' obsahuje %d, ktere vrstva v 'sprites.%s' nema - skupina smi michat jen id TE SAME vrstvy" % [kde, k, ident, k])
							skupina_ok = false
							continue
						var klicek := "%s|%d" % [k, ident]
						if obsazene_skupiny.has(klicek):
							errors.append("%s: %s je uz ve skupine vrstvy '%s' - druha by se tise ignorovala"
								% [kde, klicek, str(obsazene_skupiny[klicek])])
							skupina_ok = false
							continue
						obsazene_skupiny[klicek] = jmeno
						clenove.append(ident)
					if not skupina_ok or clenove.size() < 2:
						continue
					hotove.append(clenove)
				if not hotove.is_empty():
					skupiny[k] = hotove
			if not skupiny_ok:
				continue

		var anim := "" if vrstva.get("anim", null) == null else str(vrstva.get("anim"))
		if anim != "" and not FileAccess.file_exists(anim):
			errors.append("%s: animace '%s' neexistuje" % [kde, anim])
			continue

		out["layers"].append({
			"name": jmeno,
			"manifest": manifest,
			"page_prefix": manifest.get_base_dir() + "/",
			"anim": anim,
			"sprites": vyber,
			"groups": skupiny,
		})

	if out["layers"].is_empty() and errors.is_empty():
		errors.append("konfigurace nedala zadnou pouzitelnou vrstvu")
	out["ok"] = errors.is_empty()
	return out
