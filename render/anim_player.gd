extends RefCounted
# render.anim - prehravani animaci tela (granule render.anim; docs/04 §4.2).
#
# ODKUD FRAMY: `assets/uo/anim/anim-sheets.json` + PNG z `tools/uoextract/anim.py --export assets/uo/anim`.
# `assets/uo/` je v .gitignore, v cerstvem klonu soubor NENI - `available()` pak vraci false a zahlasime to;
# tiche "nic se nekresli" je tu vada (docs/08 §8.6). Casovani je 80 ms (docs/05 §5.1.1) = `Const.TURN_MS`.
#
# ⚠⚠ VLASTNI ANIMACE SE ZAPINAJI PO KUSECH (2026-10-11): treti (nepovinny)
# argument `_init` je `own_layers` z `assets/own-art.json` (`render/own_art.gd`).
# Vrstvy se indexuji PRED UO exportem a klic, ktery uz je ve `_sheets`, se
# neprepisuje - tak plati "vlastni vyhrava, kde je": dnes mame vlastni CHUZI
# (`400/0/*`), Beh a idle zustavaji z UO. `play()` vraci `own`, aby se dalo
# rozhodnout, ze se na vlastni sprite NESMI aplikovat UO hue sada (nasi postavu
# obarvil Blender; `app/world_view.player_hue` to preskakuje).
# `file` v kazdem listu se preklada na PLNou cestu UZ PRI INDEXACI: vrstvy lezi
# v ruznych slozkach, takze jeden prefix pro celou cache by u druhe vrstvy
# hledal PNG jinde.
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
# cislo tela. Do 2026-10-06 to bylo OTEVRENE a `serial` se bral jako cislo tela; dnes ho
# vyzvedava `body_of()` z granule `sim.entity_registry` (jedine misto, kde se mobil hleda
# podle serialu). Kdo registr nezada, dostane STARSI chovani (serial = telo), aby se dala
# merit obe cesty. Zrcadleni
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

# ⚠⚠ MAPOVANI CISLA AKCE (co posila sim v `mobile_anim`) NA SKUPINU `anim.mul`.
# Do 2026-10-09 tu ZADNE mapovani nebylo - cislo akce se bralo jako cislo
# skupiny, a to u CLOVEKA NEPLATI:
#   * reference `_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs:1721`
#     (`PeopleAnimationGroup`): 0 = WalkUnarmed, 1 = **WalkArmed**,
#     2 = **RunUnarmed**, 3 = RunArmed. ("0 = walk, 1 = run" plati jen pro
#     zvirata a monstra - `LowAnimationGroup`/`HighAnimationGroup`.)
#   * NAMERENO POHLEDEM 2026-10-09 (`_analyza/p25-groups-montaz.py` nad
#     exportem `_analyza/p25-groups`, telo 400, vsech 5 smeru): skupiny 2 a 3
#     jsou BEH (predklon, pokrcene paze), 0 a 1 jsou CHUZE. Hra proto pri behu
#     prehravala CHUZI SE ZBRANI - uzivatel to videl jako "postava jen chodi
#     rychle nebo pomalu" (2026-10-09).
#   * Art je prokazatelne jiny: prvni frame skupiny 2 ma 50x55 px, skupiny 0/1
#     40x58 px (`_analyza/p25-walk-run.py`: 25-100 % pixelu se lisi).
# Export je `tools/uoextract/anim.py --actions "0:walk,2:run,4:idle"`; kdo
# zmeni tabulku, MUSI preexportovat `assets/uo/anim` - chybejici sprite se
# hlasi (`ok:false`), netiší se.
const ACTION_GROUP := {0: 0, 1: 2, 4: 4}

# ⚠⚠ M5 (2026-10-10) - CISLO AKCE ZNAMENA U KAZDE SKUPINY NECO JINEHO.
# `ACTION_GROUP` vyse plati pro LIDI. U monster je skupina `High` ocislovana
# jinak: kde ma clovek 4 = stand (1 frame), ma kostlivec 4 = Attack1 (4 framy)
# a 2 = Die1. Manifest proto od M5 nese MAPU `groups` (ze
# `tools/uoextract/anim.py`, enumy `High/Low/PeopleAnimationGroup`
# v `_src/classicuo/.../AnimationsLoader.cs:1694-1777`, telo < 200 = high,
# 200..399 = low, 400+ = people). Cisla NIZ jsou ABSTRAKTNI ID KLIENTA; dve
# jsou nove pro boj (`sim.combat` je posila v `mobile_anim`):
const ACTION_ATTACK := 2
const ACTION_DEATH := 3
# PRACOVNI AKCE (ZADANI-28, B2): tezba/kaceni/rybareni. Cislo je ABSTRAKTNI ID
# klienta stejne jako 2/3 - skupinu v `anim.mul` pro praci NEMAME, takze se
# pouzije fallback (viz `GROUP_FALLBACK`) + kresleny svih (`render/swing.gd`).
const ACTION_WORK := 5
# Abstraktni akce -> klic v `groups[telo]`. `run` sdili `walk`: u monster beh
# neexistuje, takze se slusne pouzije chuze (a je to videt - klic `walk`).
const GROUP_KEY := {
	0: "walk", 1: "walk", ACTION_ATTACK: "attack", ACTION_DEATH: "die", 4: "idle",
}

# ⚠⚠ FALLBACK NA DOSTUPNE FRAMY (ZADANI-28, B1+B2, 2026-10-19).
# CO BYLO NAMERENO: hrac (telo 400) ma v manifestu `groups["400"]["attack"] = 9`,
# ale export `assets/uo/anim` skupinu 9 NEMA (`tools/uoextract/anim.py
# --actions "0:walk,2:run,4:idle"` + bedna smrti). `play()` proto vratilo
# `ok:false` a `app/world_view._draw_player` postavu VUBEC NEKRESLIL - hrac pri
# utoku na 400 ms ZMIZEL (namEReno: `animace_hrace().ok == false`,
# `skupina 9`, `soubor ""`). Totez pro praci (B2): skupina pro praci neexistuje.
# OPRAVA: kdyz skupina abstraktni akce v exportu neni, zkusi se DALSI klic z
# poradi; kresli se prvni, ktery framy MA. Vlastni art je prvni v `_sheets`
# (indexuje se pred UO exportem), takze fallback vezme vlastni chuzi - a tim
# zustava pravidlo "vlastni art je prioritni".
# FALLBACK JE VIDET: `pouzit_fallback()` vraci true, kdyz se kresli fallback.
# Klient k nemu kresli svih (`render/swing.gd`), aby utok nebyl jen "jina
# chuze", a brana G21 meri, ze fallback nastal a ze je u nej svih nakresleny.
const GROUP_FALLBACK := {
	ACTION_ATTACK: ["attack", "walk"],
	ACTION_WORK: ["attack", "walk"],
}

var _sheets: Dictionary = {}     # "telo/akce/smer" -> {file (PLNA cesta), frames}
var _groups: Dictionary = {}     # telo -> {walk/idle/attack/die: cislo skupiny}
var _own_keys: Dictionary = {}   # klic spritu -> true (prisel z vlastni vrstvy)
var _textures: Dictionary = {}   # "soubor|rect" -> AtlasTexture, "page|soubor" -> ImageTexture
var _state: Dictionary = {}      # serial -> {key, start} pro casovani
var _ok := false
var _registry = null             # sim.entity_registry (serial -> mobil), muze byt null


func _init(manifest_path: String = MANIFEST_PATH, registry = null,
		own_layers: Array = []) -> void:
	_registry = registry
	# VLASTNI VRSTVY PRVNI - viz hlavicka (poradi = priorita).
	for vrstva in own_layers:
		if not (vrstva is Dictionary):
			continue
		_prijmi(str(vrstva.get("anim", "")), true)
	_prijmi(manifest_path, false)
	_ok = not _sheets.is_empty()
	if not _ok:
		push_warning("render.anim: %s nedal sprite - spust `python tools/uoextract/anim.py --export assets/uo/anim`" % manifest_path)

func available() -> bool: return _ok

func sprite_count() -> int: return _sheets.size()

func own_count() -> int: return _own_keys.size()

func is_own_key(body: int, action: int, dir: int) -> bool:
	# Kresli se tenhle klíč z vlastni vrstvy? (Verejne schvalne: brana i test se
	# ptaji na TUTEZ hodnotu, kterou pouziva `play()` - kdyby si ji pocitaly
	# samy, merily by neco jineho.)
	return _own_keys.has(_key(body, action, dir))


func sheet_file(body: int, action: int, dir: int) -> String:
	# PLNÁ cesta k PNG listu, ze ktereho se tenhle klic kresli (`""` = klic
	# v zadne vrstve neni). Je to doklad PUVODU framu - `AtlasTexture` z
	# `Image.load` ma prazdny `resource_path`, takze na nem by se "vlastni vs.
	# UO" dokazat nedalo. Pouziva to brana G15.
	var sheet = _sheets.get(_key(body, action, dir))
	return str(sheet["file"]) if sheet != null else ""

func frame_ms(_action: int) -> int: return Const.TURN_MS   # docs/05 §5.1.1 = 80 ms

func frame_count(body: int, action: int, dir: int) -> int:
	var sheet = _sheets.get(_key(body, action, dir))
	return 0 if sheet == null else sheet["frames"].size()


func body_of(serial: int) -> int:
	# CISLO TELA pro `play` (granule `sim.entity_registry`): registr je jedine
	# misto, kde se mobil hleda podle serialu. Vraci -1, kdyz registr serial
	# NEZNA - "serial jako telo" by u neznamiho mobila vykreslilo CIZI postavu.
	# Bez registru se `serial` bere jako cislo tela (starsi chovani).
	if _registry == null:
		return serial
	var mob = _registry.get_mobile(serial)
	if mob == null:
		return -1
	return int(mob.body)


func play(serial: int, action: int, dir: int, now_ms: int = -1) -> Dictionary:
	var cas: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var map: Array = DIR_MAP[((dir % 8) + 8) % 8]
	var telo: int = body_of(serial)
	if telo < 0:
		_state.erase(serial)
		if _ok:
			push_warning("render.anim: serial %d neni v registru bytosti" % serial)
		return _zadny(map)
	var key: String = _key(telo, action, dir)
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
		"mirror_x": int(f["w"]) - int(f["cx"]), "sprite_dir": int(map[0]),
		"own": _own_keys.has(key)}

func _key(body: int, action: int, dir: int) -> String:
	# Klic spritu. Nezname cislo akce se bere jako cislo skupiny (starsi
	# chovani): vymyslene mapovani by u nove akce tise vybralo CIZI art.
	# U ZNAMYCH akci (utok, prace) se zkousi FALLBACK (viz `GROUP_FALLBACK`) -
	# jinak by utok hrace nemel sprite a postava by pri nem ZMIZELA.
	var sd: int = int(DIR_MAP[((dir % 8) + 8) % 8][0])
	var kandidati: Array = GROUP_FALLBACK.get(action, [])
	for klic in kandidati:
		var skupina: int = _skupina_pro_klic(body, str(klic))
		if skupina >= 0 and _sheets.has("%d/%d/%d" % [body, skupina, sd]):
			return "%d/%d/%d" % [body, skupina, sd]
	return "%d/%d/%d" % [body, sprite_group_for(body, action), sd]


func _skupina_pro_klic(body: int, klic: String) -> int:
	# Cislo skupiny pro NAZEV akce z manifestu; -1 = telo ten nazev nema.
	var mapa = _groups.get(body)
	if mapa is Dictionary and mapa.has(klic):
		return int(mapa[klic])
	return -1


func skupina_pro(body: int, action: int, dir: int) -> int:
	# KTERA skupina v `anim.mul` se nakonec pouzije (po fallbacku) - pro branu
	# a sondu; -1 = klic nema ani jednu podobu.
	var casti: PackedStringArray = _key(body, action, dir).split("/")
	return int(casti[1]) if casti.size() == 3 else -1


func ma_sprite(body: int, action: int, dir: int) -> bool:
	# Ma tahle (telo, akce, smer) opravdu framy? `false` = kreslit se neda.
	return _sheets.has(_key(body, action, dir))


func pouzit_fallback(body: int, action: int, dir: int) -> bool:
	# Kresli se FALLBACK? = skupina, kterou akce ZNAMENA (`groups[telo]`), nema
	# framy, ale nejaka pozdejsi v poradi je ma. Klient podle toho kresli svih,
	# aby utok/prace nebyly jen "jina chuze" (viz hlavicka).
	if not GROUP_FALLBACK.has(action):
		return false
	var sd: int = int(DIR_MAP[((dir % 8) + 8) % 8][0])
	var primarni: int = sprite_group_for(body, action)
	return not _sheets.has("%d/%d/%d" % [body, primarni, sd]) \
		and ma_sprite(body, action, dir)


func sprite_group(action: int) -> int:
	# Skupina v `anim.mul` pro cislo akce z `mobile_anim` (viz `ACTION_GROUP`).
	# Verejne schvalne: sonda i test se ptaji na TUTEZ hodnotu, kterou pouziva
	# klic spritu - kdyby si ji pocitaly samy, merily by neco jineho.
	return int(ACTION_GROUP.get(action, action))


func sprite_group_for(body: int, action: int) -> int:
	# SKUPINA PRO KONKRETNI TELO (M5): kdyz manifest zna `groups[telo]`, vezme
	# se z nej; jinak plati stara tabulka `ACTION_GROUP` (lidi a fixture bez
	# `groups`). Poradi je dane tim, ze `groups` je namERENA mapa z exportu -
	# `ACTION_GROUP` je jen hadani "co je pro lidi".
	var klic: String = str(GROUP_KEY.get(action, ""))
	if klic != "":
		var mapa = _groups.get(body)
		if mapa is Dictionary and mapa.has(klic):
			return int(mapa[klic])
	return sprite_group(action)


func groups_of(body: int) -> Dictionary:
	# Vyznam cisel pro tohle telo (prazdny slovnik = manifest mapu nema).
	var mapa = _groups.get(body)
	return (mapa as Dictionary).duplicate() if mapa is Dictionary else {}


func has_group(body: int, klic: String) -> bool:
	return _groups.has(body) and (_groups[body] as Dictionary).has(klic)

func _zadny(map: Array) -> Dictionary:
	# Chybejici sprite se NESMI tvarit jako "ok": prazdno by splynulo s vadou.
	return {"ok": false, "texture": null, "frame": 0, "count": 0, "anchor": Vector2.ZERO,
		"mirror": bool(map[1]), "mirror_x": 0, "sprite_dir": int(map[0]), "own": false}


func _prijmi(cesta: String, own: bool) -> void:
	# Nacte jeden anim list a prIDA klice, ktere tam jeste nejsou. Vlastni vrstva
	# je indexovana prvni, takze jeji klic vyhrava; co v ni neni (dnes beh a idle),
	# zustava z UO. `file` se preklada na plnou cestu uz tady, protoze vrstvy lezi
	# v ruznych slozkach.
	if cesta == "" or not FileAccess.file_exists(cesta):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(cesta))
	if not (parsed is Dictionary):
		return
	for chyba in parsed.get("chyby", []):
		push_warning("render.anim: export %s hlasil chybu: %s" % [cesta, chyba])
	_prijmi_skupiny(parsed.get("groups", {}))
	var sprites = parsed.get("sprites", {})
	if not (sprites is Dictionary):
		return
	var zaklad: String = cesta.get_base_dir() + "/"
	for key in sprites.keys():
		if _sheets.has(key):
			continue
		var zaznam = sprites[key]
		if not (zaznam is Dictionary):
			continue
		var framy = zaznam.get("frames", [])
		# List bez framu se NEINDEXUJE: prazdny zaznam ve vlastni vrstve by jinak
		# prebil platny sprite z UO a `play()` by delil nulou.
		if not (framy is Array) or framy.is_empty():
			continue
		_sheets[key] = {"file": zaklad + str(zaznam.get("file", "")), "frames": framy}
		if own:
			_own_keys[key] = true

func _prijmi_skupiny(d) -> void:
	# MAPA VYZNAMU AKCI Z MANIFESTU (M5): `{telo: {walk, idle, attack, die}}`.
	# Klic je v JSONu TEXT, tady se prevede na int tela - kdo ji cte, nesmi
	# hadat, jestli je klic cislo nebo text. Vrstvy se doplnuji (vlastni prvni),
	# chybejici tela z UO zustavaji.
	if not (d is Dictionary):
		return
	for telo in d.keys():
		var mapa = d[telo]
		if not (mapa is Dictionary):
			continue
		if not _groups.has(int(telo)):
			_groups[int(telo)] = {}
		for klic in mapa.keys():
			_groups[int(telo)][str(klic)] = int(mapa[klic])


func _texture(file: String, f: Dictionary) -> Texture2D:
	# Stranka spritu se drzi JEDNOU na soubor ("page|soubor"), frame je jen AtlasTexture
	# nad ni - jako v `render.textures` (jinak kazdy frame drzi kopii stranky: 12,2 -> 1,3 MB).
	var key := "%s|%s" % [file, str(f["rect"])]
	if _textures.has(key):
		return _textures[key]
	var page: Texture2D = _textures.get("page|" + file)
	if page == null:
		# ⚠ 18. session: SPRITE ANIMACE SE NACTE PRES IMPORT, kdyz existuje
		# (`load()`), ne `Image.load()` - to bylo v logu uzivatele jako
		# "Loaded resource as image file, this will not work on export:
		# 'res://assets/uo/anim/anim-400-0-0.png'" a v exportu by to
		# nefungovalo vubec. Kdyz import chybi, padá se zpet na `Image.load`.
		# `file` je od 2026-10-11 PLNÁ cesta (preklada ji `_prijmi`), aby vrstvy
		# v ruznych slozkach nemusely sdilet jeden prefix.
		var cesta: String = file
		if ResourceLoader.exists(cesta):
			page = load(cesta)
		if page == null:
			var image := Image.new()
			if image.load(cesta) != OK:
				push_warning("render.anim: PNG %s se necte" % cesta)
				_textures["page|" + file] = null
				return null
			page = ImageTexture.create_from_image(image)
		_textures["page|" + file] = page
	var out := AtlasTexture.new()
	out.atlas = page
	out.region = Rect2(int(f["rect"][0]), int(f["rect"][1]), int(f["w"]), int(f["h"]))
	_textures[key] = out
	return out
