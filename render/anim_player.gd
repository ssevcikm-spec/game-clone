extends RefCounted
# render.anim - prehravani animaci tela (granule render.anim; docs/04 §4.2).
#
# ODKUD FRAMY: `assets/uo/anim/anim-sheets.json` + PNG z `tools/uoextract/anim.py --export assets/uo/anim`.
# `assets/uo/` je v .gitignore, v cerstvem klonu soubor NENI - `available()` pak vraci false a zahlasime to;
# tiche "nic se nekresli" je tu vada (docs/08 §8.6). Casovani je 80 ms (docs/05 §5.1.1) = `Const.TURN_MS`.
# MAPOVANI 8 SMERU HRY NA 5 SMERU anim.mul (+ zrcadleni) - OVERENO POHLEDEM. Naivni "5 spritu
# = S,SW,W,NW,N a zrcadlem doplnime vychodni pulku" NESEDI: osa zrcadleni je SVISLA OSA
# OBRAZOVKY, protoze projekce `screen = ((x-y), (x+y)) * ISO_STEP` (core/iso.gd) se diva na
# svetovy JIHOVYCHOD (svet SE je na obrazovce dole). Zrcadlove dvojice jsou proto (E,S),
# (NE,SW) a (N,W); SE a NW lezi na ose, takze se nezkresluji - nezrcadlene jsou smery mirici
# na obrazovce DOPRAVA. Zmereno na exportu (masky pixelu vuci lince zeme `cy + h`, montaz vsech 5 smeru
# prohlednuta ocima) a krizove overeno proti ClassicUO `GetAnimDirection` (`_src/classicuo/.../
# Animation.cs:76`, BSD), ktere po prepoctu na cisla smeru z `core/const.gd` dava presne tuhle tabulku:
#     sprite 0 = celni -> svet SE (dir 7) bez zrcadla;  sprite 4 = zadni -> svet NW (dir 3) bez zrcadla
#     sprite 1 = ctvrtpredni vlevo -> svet S (6) a zrcadlene E (0);  sprite 2 = profil vlevo -> SW (5), NE (1)
#     sprite 3 = ctvrtzadni -> svet W (4) a zrcadlene N (2)
# NALEZ (hlasim, neopravuji): prompt uvadi priklad "smer 4 = zapad je zrcadleny smer 0 = vychod"; NESEDI.
# CO SMLOUVA NEPINUJE (hlasim, neopravuji): `play(serial, ...)` - ODKUD se pro serial bere
# cislo tela (registr bytosti jeste neni, proto se `serial` bere jako cislo tela). Zrcadleni
# se do deklarovaneho navratu nevejde: `anchor` je presne `Vector2(cx, cy+h)` z manifestu, ale
# zrcadleny sprite se kresli na `tile_x - (w - cx)` (ClassicUO `MobileView.cs:712`) - navrat
# proto nese navic `mirror`, `mirror_x` (= w - cx) a `sprite_dir` (0..4). `frame_ms(action)`
# ma argument, ale hodnota na akci nezavisi (docs/05 §5.1.1 dava 80 ms vsem). VRSTVY VYBAVY SE
# TU NESKLADAJI - patri k `render.hue` a `entity.equipment` (M2), otevrena vec teto granule;
# `preload`, ne `class_name`: v cerstvem stromu neni cache trid (app/main.gd:9).

const Const = preload("res://core/const.gd")
const MANIFEST_PATH := "res://assets/uo/anim/anim-sheets.json"

# smer hry (core/const.gd: 0 = E ... 7 = SE) -> [smer v anim.mul 0..4, zrcadlit]
const DIR_MAP := [[1, true], [2, true], [3, true], [4, false],
	[3, false], [2, false], [1, false], [0, false]]

var _sheets: Dictionary = {}     # "telo/akce/smer" -> {file, frames}
var _textures: Dictionary = {}   # "soubor|rect" -> AtlasTexture, "page|soubor" -> ImageTexture
var _state: Dictionary = {}      # serial -> {key, start} pro casovani
var _prefix := ""
var _ok := false


func _init(manifest_path: String = MANIFEST_PATH) -> void:
	_prefix = manifest_path.get_base_dir() + "/"
	var parsed = null
	if FileAccess.file_exists(manifest_path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if parsed is Dictionary:
		for chyba in parsed.get("chyby", []):
			push_warning("render.anim: export hlasil chybu: %s" % chyba)
		_sheets = parsed.get("sprites", {})
	_ok = not _sheets.is_empty()
	if not _ok:
		push_warning("render.anim: %s nedal sprite - spust `python tools/uoextract/anim.py --export assets/uo/anim`" % manifest_path)

func available() -> bool: return _ok

func sprite_count() -> int: return _sheets.size()

func frame_ms(_action: int) -> int: return Const.TURN_MS   # docs/05 §5.1.1 = 80 ms

func frame_count(body: int, action: int, dir: int) -> int:
	var sheet = _sheets.get(_key(body, action, dir))
	return 0 if sheet == null else sheet["frames"].size()


func play(serial: int, action: int, dir: int, now_ms: int = -1) -> Dictionary:
	var cas: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var map: Array = DIR_MAP[((dir % 8) + 8) % 8]
	var key: String = _key(serial, action, dir)
	var sheet = _sheets.get(key)
	if sheet == null:
		_state.erase(serial)
		if _ok:
			push_warning("render.anim: serial %d akce %d smer %d nema sprite" % [serial, action, dir])
		return _zadny(map)
	var frames: Array = sheet["frames"]
	var count: int = frames.size()
	var state: Dictionary = _state.get(serial, {})
	if state.get("key", "") != key:
		state = {"key": key, "start": cas}    # zmena tela/akce/smeru zacina framem 0
		_state[serial] = state
	var tick: int = maxi(0, cas - int(state["start"]))
	var frame: int = (tick / frame_ms(action)) % count
	var f: Dictionary = frames[frame]
	var texture := _texture(str(sheet["file"]), f)
	if texture == null:
		return _zadny(map)
	return {"ok": true, "texture": texture, "frame": frame, "count": count,
		"anchor": Vector2(f["cx"], f["cy"] + f["h"]), "mirror": bool(map[1]),
		"mirror_x": int(f["w"]) - int(f["cx"]), "sprite_dir": int(map[0])}

func _key(body: int, action: int, dir: int) -> String:
	return "%d/%d/%d" % [body, action, int(DIR_MAP[((dir % 8) + 8) % 8][0])]

func _zadny(map: Array) -> Dictionary:
	# Chybejici sprite se NESMI tvarit jako "ok": prazdno by splynulo s vadou.
	return {"ok": false, "texture": null, "frame": 0, "count": 0, "anchor": Vector2.ZERO,
		"mirror": bool(map[1]), "mirror_x": 0, "sprite_dir": int(map[0])}

func _texture(file: String, f: Dictionary) -> Texture2D:
	# Stranka spritu se drzi JEDNOU na soubor ("page|soubor"), frame je jen AtlasTexture
	# nad ni - jako v `render.textures` (jinak kazdy frame drzi kopii stranky: 12,2 -> 1,3 MB).
	var key := "%s|%s" % [file, str(f["rect"])]
	if _textures.has(key):
		return _textures[key]
	var page: Texture2D = _textures.get("page|" + file)
	if page == null:
		var image := Image.new()
		if image.load(_prefix + file) != OK:
			push_warning("render.anim: PNG %s se necte" % (_prefix + file))
			_textures["page|" + file] = null
			return null
		page = ImageTexture.create_from_image(image)
		_textures["page|" + file] = page
	var out := AtlasTexture.new()
	out.atlas = page
	out.region = Rect2(int(f["rect"][0]), int(f["rect"][1]), int(f["w"]), int(f["h"]))
	_textures[key] = out
	return out
