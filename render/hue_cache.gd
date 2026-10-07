extends RefCounted
# Tonovani hue (granule render.hue; docs/04 §4.2, docs/03 §3.2b a §3.5.2).
#
# CO TO DELA: z sediveho artu (obrazy z `assets/uo/anim/`) udela barevny tim, ze
# kazdy pixel preindexuje pres 32barevnou sadu z `hues.json`. Vysledek se drzi
# v cache podle KLICE ZDROJE a hue.
#
# JAK SE PIXEL NA INDEX PREVADI (mereno, ne odhad):
#   * UO art je 5bitovy (RGB555) - kazdy kanal ma 32 urovni, horni bit je
#     pruhlednost. Prevod 5 -> 8 bitu NENI `v << 3`, ale zaobleni `v * 255 / 31`
#     (`ClassicUO HuesHelper.Color16To32`, tabulka 32 hodnot: 0, 8, 16, 24, 33,
#     41, ... 255). Kdo dela `v << 3`, dostane u tech 17 hodnot spatne barvy
#     (namEReno: v exportu animaci melo 11 493 pixelu zeleny a modry kanal
#     posunuty o 8/16/24 - presne tenhle rozdil).
#   * Index barvy v sade je 5 HORNICH bitu barvy (`(c >> 10) & 0x1F`), tedy pro
#     obrazek v 8 bitech `idx = (r * 31 + 127) / 255` (zaokrouhleni, ne posun).
#     Sediva rampa exportu ma presne tech 32 hodnot, takze index vyjde presne.
#   * Plny hue prebarvi VSECHNY netransparentni pixely (ClassicUO
#     `IsometricWorld.fx:127`, mod HUED). `partial_hue` prebarvi jen pixely, kde
#     R == G == B (tamtéz, mod PARTIAL_HUED).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `hued()` bere i TEXTURU, ne jen `art_id` - druhy zdroj obrazku v projektu
#     je `render.anim` (`anim-sheets.json` + PNG, zadne `art_id`) a prave on
#     kresli postavu. `art_id` v tele hry pouzitelny neni (tela jsou v `anim.mul`,
#     ne v artu), takze bez varianty s texturou by sla tonovat jen mapa.
#   * `stats()` vraci `missing` a `bytes` - bez `missing` by se "hue neni"
#     (nezname id, poskozeny JSON) tvarilo jako uspech (docs/08 §8.6).
#   * `HUE_SKIN` je jen VYCHOZI barva kuze pro hrace (kdyz `mobile.hue == 0`);
#     `hues.json` ma 30 sad s nazvem `SkinHue #N` (1001..1030).
#
# Pouziti:
#   var hues = HueCache.new()
#   var tex = hues.hued(base_texture, 1001)   # nebo hues.hued(base, hue, true)

const HUES_PATH := "res://assets/uo/hues.json"
const COLORS_PER_SET: int = 32
# Index sady pro barvu kuze: 0..1000 jsou v `hues.mul` PREVODNI (sede) tabulky,
# barevne sady zacínaji 1001. Sada 1002 se jmenuje "SkinHue #1001" (cislo v
# nazvu je 0-based), takze VYCHOZI kuze hrace je 1002, ne 1001 (namEReno
# 2026-10-06: se 1001 vysla postava sede).
const HUE_SKIN: int = 1002
const MAX_ENTRIES: int = 512      # strop cache; 0 = bez stropu

# 5 -> 8 bitu. HODNOTY SE OPISUJI Z REFERENCNIHO KLIENTA (ClassicUO
# `HuesHelper._table`, BSD-2) - NEJSOU to `v << 3` ANI `round(v * 255 / 31)`,
# i kdyz se to tak na prvni pohled jevi (namEReno 2026-10-06: tabulka se od
# vzorce lisi na 15 z 32 hodnot, napr. u v=3 ma 24, vzorec 25). Kvuli tomuhle
# rozdilu vypadaly pixely v exportu "barevne", i kdyz jsou sedive.
const EXPAND_5_TO_8 := [0, 8, 16, 24, 32, 41, 49, 57, 65, 74, 82, 90, 98, 106,
	115, 123, 131, 139, 148, 156, 164, 172, 180, 189, 197, 205, 213, 222, 230,
	238, 246, 255]

var _sets: Array = []          # index (1..3000) -> PackedInt32Array[32] barev RGB
var _cache: Dictionary = {}    # klic zdroje + "|" + hue -> ImageTexture
var _order: Array = []         # LRU, nejnovejsi na konci
var _bytes: int = 0
var _hits: int = 0
var _misses: int = 0
var _missing: int = 0
var _limit: int = MAX_ENTRIES
var _ok: bool = false


func _init(hues_path: String = HUES_PATH, max_entries: int = MAX_ENTRIES) -> void:
	_limit = max_entries
	var parsed = null
	if FileAccess.file_exists(hues_path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(hues_path))
	if parsed is Dictionary:
		for zaznam in parsed.get("sets", []):
			_sets.append(_barvy(zaznam))
	_ok = not _sets.is_empty()
	if not _ok:
		# Prazdna cache neni uspech: kdo pak tonuje, dostane jen puvodni texturu
		# a nebude to videt (docs/08 §8.6).
		push_warning("render.hue: %s nedal zadnou sadu - spust `python tools/uoextract/hues.py --install \"<UO>\"`" % hues_path)


func available() -> bool: return _ok

func set_count() -> int: return _sets.size()


func hued(base: Texture2D, hue: int, partial_hue: bool = false) -> Texture2D:
	# hue 0 = "nepouzij hue" (docs/03 §3.5.2); vrací se PRESNE puvodni textura,
	# aby se v scene neplatil ani prebarvovany obraz, ani cache.
	if base == null or hue == 0:
		return base
	if hue < 0 or hue > _sets.size():
		_missing += 1
		push_warning("render.hue: sadu %d hues.json nema (sad je %d)" % [hue, _sets.size()])
		return base
	var klic := "%s|%d|%d" % [_klic_zdroje(base), hue, 1 if partial_hue else 0]
	var hotovo = _cache.get(klic)
	if hotovo != null:
		_hits += 1
		_touch(klic)
		return hotovo
	_misses += 1
	var obrazek := _obrazek(base)
	if obrazek == null:
		return base
	var out := _obarvi(obrazek, int(hue), partial_hue)
	if out == null:
		return base
	var textura := ImageTexture.create_from_image(out)
	_cache[klic] = textura
	_bytes += out.get_width() * out.get_height() * 4
	_touch(klic)
	_evict()
	return textura


func hued_art(textures, base_art_id: int, hue: int, partial_hue: bool = false) -> Texture2D:
	# Tonovani ART ID (mapa, statiky): puvodni textura se vezme z `render.textures`.
	# Tela postav tim nejdou - jsou v `anim.mul`, ne v artu (viz hlavicka).
	# POZOR: `render.chunk` dnes statiky netonuje vubec - `hue` ze zaznamu statiky
	# se prenasi do kresliciho seznamu, ale nikdo ho nepouziva (otevrena vec).
	if textures == null:
		return null
	var base: Texture2D = textures.texture(base_art_id)
	if base == null:
		_missing += 1
		return null
	return hued(base, hue, partial_hue)


func stats() -> Dictionary:
	return {"sad": _sets.size(), "polozek": _cache.size(), "bytes": _bytes,
		"limit": _limit, "hits": _hits, "misses": _misses, "missing": _missing}


func hue_color(hue: int, index: int) -> Color:
	# Barva jedne urovne sady - pouziva se v testu i pro lidskou kontrolu.
	if hue < 1 or hue > _sets.size() or index < 0 or index >= COLORS_PER_SET:
		return Color(0, 0, 0, 1)
	return _z_int(int(_sets[hue - 1][index]))


func _obarvi(obrazek: Image, hue: int, partial_hue: bool) -> Image:
	var sada: PackedInt32Array = _sets[hue - 1]
	# KOPIE se dela pres `blit_rect` do NOVEHO obrazku ve formatu RGBA8.
	# `duplicate()` tady NEDRZI format (namEReno: `ImageTexture` s alfou 128
	# vratil po duplikaci alfou 255) - alfa je pritom maska spritu.
	var out := Image.create(obrazek.get_width(), obrazek.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(obrazek, Rect2i(0, 0, obrazek.get_width(), obrazek.get_height()), Vector2i.ZERO)
	for y in out.get_height():
		for x in out.get_width():
			var c: Color = obrazek.get_pixel(x, y)
			if c.a <= 0.0:
				continue                      # pruhledne pixely se needituji
			if partial_hue and not (c.r == c.g and c.g == c.b):
				continue                      # partial hue: jen sedive pixely
			# Index barvy = 5 HORNICH bitu kanalu (u UO artu je to R). Chce se
			# ZAOKROUHLENI `r * 31 / 255`, ale v INTCICH: `round(r / 255.0 * 31)`
			# da u 255 chybou v plavouci radove 0,9999 -> 0 (namEReno), tedy
			# bila by dostala barvu urovne 0. Zelena a modra se ignoruji -
			# presne tak to dela i ClassicUO (`get_rgb(color.r, hue)`).
			var index: int = _uroven(roundi(c.r * 255.0))
			var nova: Color = _z_int(int(sada[index]))
			# Alfa se ZACHOVAVA z puvodniho pixelu - je to maska spritu.
			out.set_pixel(x, y, Color(nova.r, nova.g, nova.b, c.a))
	return out


func _uroven(k8: int) -> int:
	# 8bitova hodnota -> uroven 0..31 = NEJBLIZSI hodnota v `EXPAND_5_TO_8`.
	# POCITA SE TABULKOU, ne vzorcem. Duvod (namEReno): `EXPAND_5_TO_8` je
	# `round(v * 255 / 31)`, takze prevod zpet NENI `(k8 + 4) / 8` ani
	# `roundi(k8 / 8.0)`: u 132 vyjde 17, ale spravne je 16 (`round(132 / 8) = 17`
	# je banker's zaokrouhleni pulky). Tabulka je presna na vsech 32 hodnotach -
	# a to je prave ta kontrola, ktera odlisi zaokrouhleni od posunu `v << 3`.
	# Pro hodnoty, ktere v tabulce nejsou (antialias mezi urovnemi), se vezme
	# nejblizsi - to je presne to, co dela GPU vzorkovani hue rampy.
	var nejlepsi: int = 0
	var rozdil: int = 1 << 30
	for i in EXPAND_5_TO_8.size():
		var d: int = absi(int(EXPAND_5_TO_8[i]) - k8)
		if d < rozdil:
			rozdil = d
			nejlepsi = i
	return nejlepsi


func _barvy(zaznam) -> PackedInt32Array:
	var out := PackedInt32Array()
	var barvy: Array = zaznam.get("colors", []) if zaznam is Dictionary else []
	for i in COLORS_PER_SET:
		var c: int = int(barvy[i]) if i < barvy.size() else 0
		out.append((int(EXPAND_5_TO_8[(c >> 10) & 0x1F]) << 16)
			| (int(EXPAND_5_TO_8[(c >> 5) & 0x1F]) << 8)
			| int(EXPAND_5_TO_8[c & 0x1F]))
	return out


func _z_int(rgb: int) -> Color:
	return Color(((rgb >> 16) & 0xFF) / 255.0, ((rgb >> 8) & 0xFF) / 255.0, (rgb & 0xFF) / 255.0, 1.0)


func _obrazek(base: Texture2D) -> Image:
	# ⚠ VADA ZE SNIMKU (opraveno 2026-10-07, 12. session): dokud se tady bral
	# CELY ATLAS (stranka animace = vsechny framy v jednom pruhu), vracel
	# `hued()` texturu CELÉ STRANKY - a `app/world_view._draw_player()` ji
	# kreslil na pozici postavy. Uzivatel to videl jako "vedle postavy se
	# objevi vsechny animacni snimky" (stopa framu). Zmereno: frame chuze ma
	# 24x64 px, stranka `anim-400-0-0.png` ma vsech 10 framu vedle sebe.
	# Spravne se tedy bere OKNO (`region`), ne stranka.
	# Postup je robustni vuci tomu, co Godot v `get_image()` vrati: kdyz uz
	# vrati region (velikost sedi), nic se neorezava.
	var textura := base
	var region := Rect2i()
	if base is AtlasTexture:
		var atlas := base as AtlasTexture
		region = Rect2i(atlas.region)
		textura = atlas.atlas
	if textura == null:
		return null
	var obrazek: Image = textura.get_image()
	if obrazek == null:
		return null
	if region.size.x > 0 and region.size.y > 0 and obrazek.get_size() != Vector2i(region.size):
		obrazek = obrazek.get_region(region)
	return obrazek


func _klic_zdroje(base: Texture2D) -> String:
	# Textura sama svuj "art" nerekne, ale misto v strane ano: `resource_path`
	# (u nactene PNG) + `region` (u `AtlasTexture`).
	# ⚠ PAST (namERena 2026-10-06): textura vytvorena ZA BEHU (`ImageTexture`
	# nad `Image`) ma `resource_path` PRAZDNY - vsechny takove by dostaly stejny
	# klic a cache by vratila texturu JINEHO obrazku (v sone to bylo videt:
	# pruhledny obrazek dostal neprusvitelnou verzi obrazku predchoziho).
	# Klic je proto KRATKY OTISK OBSAHU, ne jmeno souboru.
	return _otisk(base)


func _otisk(base: Texture2D) -> String:
	# Otisk pixelu: 3 x 32bit hash (delka, pocet barevnych slozek, kumulativni
	# hash hodnot) - kolize je tim prakticky vyloucena a je to LINEARNI v poctu
	# pixelu, ale pocita se JEN JEDNOU na (textura, hue) - cache hitu se to
	# netyka. Cely obsah se cist nedá: frame ma radove 10^4 pixelu a hashovat
	# 4 bajty na pixel kazdy frame by bylo drazsi nez samotne tonovani.
	var obrazek := _obrazek(base)
	if obrazek == null:
		return "null"
	var h: int = 2166136261                        # FNV-1a, 32bit
	var soucet: int = 0
	var pocet: int = 0
	for y in obrazek.get_height():
		for x in obrazek.get_width():
			var c: Color = obrazek.get_pixel(x, y)
			var a: int = roundi(c.a * 255.0)
			if a <= 0:
				continue
			var r: int = roundi(c.r * 255.0)
			var g: int = roundi(c.g * 255.0)
			var b: int = roundi(c.b * 255.0)
			soucet = (soucet * 31 + r * 7 + g * 13 + b * 17 + a) & 0xFFFFFFFF
			h = ((h ^ (r * 65536 + g * 256 + b)) * 16777619) & 0xFFFFFFFF
			pocet += 1
	var region := ""
	if base is AtlasTexture:
		region = str((base as AtlasTexture).region)
	return "%d:%d:%d:%s:%s" % [obrazek.get_width(), obrazek.get_height(), pocet,
		str(soucet), "%08x%s" % [h, region]]


func _touch(klic: String) -> void:
	_order.erase(klic)
	_order.append(klic)


func _evict() -> void:
	# Vyhazuje se od NEJSTARSI polozky; prave vlozena je na konci, takze se
	# nikdy nevyhodi (texturu, kterou drzi volajici, cache prezije do konce frame).
	if _limit <= 0:
		return
	while _cache.size() > _limit and _order.size() > 1:
		var oldest: String = _order[0]
		_order.pop_front()
		var stara: ImageTexture = _cache[oldest]
		_bytes -= stara.get_width() * stara.get_height() * 4
		_cache.erase(oldest)
