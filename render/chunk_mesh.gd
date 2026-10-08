extends RefCounted
# render.chunk_mesh (M9, 15. session) - DAVKOVE KRESLENI CELEHO POHLEDU.
#
# PROC: `app/world_view` kreslil kazdy objekt zvlast (`draw_texture`), takze na
# obrazovce Britannie to bylo **1 324 draw callu a 48,75 ms/frame (24 FPS)**
# (namEReno `_analyza/m9-vykon-pred.gd`, 300 framu, vsync vypnuty; 4 655
# kreslenych objektu z 7 872 v seznamu). Scitaji se v tom dve veci: (a) 4 655
# prikazu do rendereru, (b) GDScript smycka se `screen_position` a dotazem do
# textur pro kazdy objekt na KAZDEM framu.
#
# JAK: cely viditelny seznam se prevede na JEDEN mesh (kvadr na objekt, v poradi
# ze `render.sort`), takze frame posila 1-2 prikazy (pred hracem / po hraci).
# Aby to slo, musi byt vsechny sprity v JEDNE texture - atlas z extrakce ma 77
# stranek a pohled Britannie jich pouziva 31. Modul si proto stavi VLASTNI
# STRANKU (runtime atlas) a sprity do ni SKLADA NA GPU (`SubViewport`).
#
# ⚠ PROC GPU A NE KOPIE NA CPU (namEReno 2026-10-08, prvni verze): kopirovani
# `Image.blit_rect` z originalnich stranek znamena `ImageTexture.get_image()` na
# kazdou stranku - a to je kopie 16 MB. Pri 398 sprity v pohledu se LRU stranek
# thrashoval a **stavba trvala 3 342 ms** (sonda `_analyza/m9-snimek.gd`).
# Pres SubViewport se sklada 398 kvadru za zlomek milisekundy a nic se nekopiruje.
#
# ⚠ CO JE ZMERENE A CO JE ROZHODNUTI - `_analyza/m9-cena-meshe.gd`:
#   * 343 unikatnich artu v celem pohledu = 1,3 Mpx (namEReno 1,42 Mpx i s texmapy),
#     takze se vejdou do stranky 2048x2048 (4,19 Mpx) s ~3x rezervou,
#   * `ArrayMesh.add_surface_from_arrays` stoji **~0,3 ms na surface** (2 090
#     surface = 633 ms). Proto ma mesh PRAVE JEDNU surface = jeden draw call;
#     radit kvadry podle originalnich stranek (25 surface) by bylo pomalejsi
#     nez dnesni stav,
#   * pruchod seznamem v GDScriptu stoji desitky ms, takze se NEDELA kazdy
#     frame: `build()` bezi pri prestavbe seznamu a pri zmene diagonaly hrace
#     se jen PREKRAJI (`split()`, namEReno 0,9 ms).
#
# ⚠ PRESNOST OBRAZU (podminka M9): kvadry se pridavaji v PORADI seznamu, takze
# painter's algoritmus zustava (v jednom meshi rozhoduje poradi trojuhelniku).
# UV se pocitaji STEJNE LINEARNĚ jako u `AtlasTexture` (`(region + lokalni *
# velikost) / stranka`), filtr je NEAREST (`project.godot`
# `default_texture_filter=0`), takze obraz je pixel na pixel - dokazuje to
# `_analyza/m9-parita.gd`: tri sceny (stoji, uprostred kroku, po chuzi) maji
# STEJNY HASH snimku pro dávku i pro puvodni cestu.
#
# ⚠ ZNÁMÉ OMEZENI (zapsane, ne zamlcene): stranka se na GPU kresli JEDNOU za
# zmenu (`UPDATE_ONCE`), takze art, ktery se v atlase jeste neobjevil, je videt
# o DVA frame pozdeji - dokud stranka nema obsah, kresli `app.world_view`
# puvodni cestou (`hold()`). Snimek i testy se meri na ustalenem stavu.
#
# TVAR VSTUPU: seznam z `render.chunk.visible(...)` - `{"kind","x","y","z",
# "art_id","offset"}` (+ `texmap`, `z_corners` u landu).

const Iso = preload("res://core/iso.gd")
const Const = preload("res://core/const.gd")
const Sort = preload("res://render/sort.gd")

const PAGE_SIZE: int = 2048          # stranka runtime atlasu (px)
const PAD: int = 1                   # mezera mezi sprity (kdyby se zapnul filtr)
const TEXMAP_OFFSET: int = 0x10000
const VOID_LAND_MAX: int = 2         # land id <= 2 UO vubec nekresli
const BILY: int = -1                 # klic bileho texelu (dira)
const HOLE_COLOR := Color(1.0, 0.0, 1.0, 0.85)
const BILA_VELIKOST: int = 2         # strana bileho ctverecku v atlase
const VRCHOLU_NA_KVADR: int = 6      # dva trojuhelniky [0,1,2] a [2,3,0], bez indexu
const HOLD_FRAMU: int = 2            # frame, nez se smi pouzit nova stranka
# Kolik objektu se zpracuje, nez se zkontroluje cas (18. session). Kontrolovat
# cas po KAZDEM objektu by bylo drazsi nez prace sama (`Time.get_ticks_usec`).
const DRZKA: int = 64
# ⚠ BARVA SVAHU (18. session): reference pousti plochy land art rezimem
# `SHADER_NONE` (bez stineni) a SVah (texmapu) rezimem `SHADER_LAND`, kde se
# barva nasobi `get_light(normal)`; pro plochou normalu to je presne
# **0.85355339** (`IsometricWorld.fx:60-69`, konstanta je tam proto, aby
# `TerrainShadowsLevel` menil jen kontrast svahu, ne jas roviny). Bez tohoto
# faktoru jsou nase svahy o ~15 % svetlejsi nez rovina a nez klientsky obraz.
# ⚠ VEDOME OMEZENI: stinovani podle NORMALY (`Land.CalculateNormal`, 4 křízove
# souciny v obrazovem prostoru) tu NENI - patri k `render.light` (rozhodnuti R10
# v `ROZHODNUTI-2026-10-08.md`). Dnes tedy vsechny svahy ztmavneme stejne.
const SVAH_JAS: float = 0.85355339
const SVAH_BARVA := Color(SVAH_JAS, SVAH_JAS, SVAH_JAS, 1.0)
# Pulpixelovy inset UV u TEXMAPY (`ChunkMesh.cs:458-462`: `rect.X + 0.5`,
# `rect.Width - 1`) - bez nej se na sevech dlazdic proleva sousedni texel.
const UV_INSET_PX: float = 0.5


class Kreslic extends Node2D:
	# Sklada runtime atlas NA GPU: kazdy slot je jeden `draw_texture`.
	# Polozky plni `render.chunk_mesh` (stejny objekt pole, proto se nemeni).
	var polozky: Array = []

	func _draw() -> void:
		for p in polozky:
			if p["tex"] == null:
				var v: Vector2 = p["velikost"]
				draw_rect(Rect2(p["pos"], v), Color.WHITE)
			else:
				draw_texture(p["tex"], p["pos"])


var _chunk = null                    # render.chunk (`screen_position`)
var _textures = null                 # render.textures (`texture`/`texmap`)
var _iso = null
var _sort = null

# --- runtime atlas (na GPU) ----------------------------------------------
var _velikost: int = PAGE_SIZE
var _viewport: SubViewport = null
var _kreslic: Kreslic = null
var _polozky: Array = []             # {pos, tex, velikost} pro `Kreslic`
var _sloty: Dictionary = {}          # klic (art_id) -> Rect2i ve strance
var _x: int = 0
var _y: int = 0
var _vyska_radku: int = 0
var _pridano: int = 0                # kolik novych slotu tato stavba pridala
var _repakov: int = 0                # kolikrat se stranka zacala znovu
var _pretek: bool = false
var _hold: int = 0                   # frame, po ktere se jeste kresli puvodne

# --- geometrie (v poradi seznamu) ---------------------------------------
var _verts := PackedVector2Array()
var _uvs := PackedVector2Array()
var _barvy := PackedColorArray()
# ⚠ 18. session (2026-10-08): do teto session tu byla DIAGONALA kazdeho kvadru
# a deleni se hledalo v ni. Jenze klic `render.sort` od teto session neni
# `diagonala` (viz hlavicka `render/sort.gd`: pruchod -> diagonala -> `z` ->
# vrstva) a hlavne `z` smi prebit az ~2,5 diagonály - deleni podle diagonaly by
# tedy rozseklo seznam na spatnem miste. Drzi se proto CELY KLIC (`sort_key`),
# ktery je v poli neklesajici, takze binarni hledani zustava.
var _klic := PackedInt64Array()      # klic `render.sort` kazdeho kvadru
var _diry: Array = []                # art id, ktere v atlase nejsou (hlasi se)
var _mesh_pred: ArrayMesh = null
var _mesh_po: ArrayMesh = null
var _posledni_split: int = -2147483647
# ⚠ 18. session: PREDCHOZI davka (viz `build`). Drzi se proto, aby se `hold`
# framy (stranka se prekresluje na GPU) kreslila STARA davka - ta na starou
# stranku sedi presne, kdezto puvodni cesta stoji ~35 ms/frame.
var _predchozi_pred: ArrayMesh = null
var _predchozi_po: ArrayMesh = null
var _predchozi_stats: Dictionary = {}
var _predchozi: bool = false

var _stats: Dictionary = {}
var _hotovo: bool = false

# --- STAVBA PO CASTECH (18. session, R6) ---------------------------------
# `build()` byl jeden blok ~150 ms. Dnes se stavi `zacni()` + opakovane
# `krok(ms)`, takze frame zustane kratky a kresli se pritom PREDCHOZI davka.
var _fronta: Array = []              # seznam, ktery se stavi
var _k: int = 0                      # index ve fazi 0/2
var _faze: int = 3                   # 0 sber artu, 1 sloty, 2 geometrie, 3 hotovo
var _potreba: Dictionary = {}        # klic -> [vyska, sirka, tex] (faze 0)
var _poc: Dictionary = {"svahu": 0, "der": 0, "nodraw": 0, "ceka": 0, "bez_slotu": 0}
var _q: int = 0                      # kolik kvadru je hotovych
var _prace_us: int = 0               # kolik us skutecne zabrala stavba (pres framy)
var _kroku: int = 0                  # kolik `krok` volani stavba potrebovala
var _faze1_us: int = 0               # kolik z toho zabralo predehleni slotu (nerezene)
var _pokusu: int = 0                 # kolikrat se stavba zacala (max 2: druhy pruchod)


func _init(chunk, textures, page_size: int = PAGE_SIZE, parent: Node = null) -> void:
	_chunk = chunk
	_textures = textures
	_velikost = page_size
	_iso = Iso.new()
	_sort = Sort.new()
	_viewport = SubViewport.new()
	_viewport.name = "ChunkMeshAtlas"
	_viewport.size = Vector2i(_velikost, _velikost)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_kreslic = Kreslic.new()
	_kreslic.polozky = _polozky
	_viewport.add_child(_kreslic)
	if parent != null:
		parent.add_child(_viewport)
	_bily_slot()


func is_built() -> bool:
	return stav() == 0


func stavi_se() -> bool:
	# Bezi stavba? (Volajici musi volat `krok` - i kdyz `stav()` vraci 2,
	# protoze zadna predchozi davka neni: to znamena "kresli puvodni cestou",
	# ne "nestav".)
	return _faze < 3


func je_geometrie_hotova() -> bool:
	# Geometrie je postavena (`_hotovo`), i kdyz se stranka jeste prekresluje
	# (`hold`). Volajici ji smi ROZDELIT uz ted - kreslit se bude az se `stav()`
	# vrati 0, ale rozdeleni tim nezapadne (do 18. session se delilo jen pri
	# `stav() == 0`, takze po `invalidate()` uprostred `hold` zustaly meshe NULL
	# a prisla se o ne i PREDCHOZI davka - namEReno `puvodni` 78 framu).
	return _faze >= 3 and _hotovo


func stav() -> int:
	# 0 = hotova davka (kresli ji), 1 = stavi se / ceka se na prekresleni stranky
	# (kresli PREDCHOZI davku), 2 = neda se (pretek, nebo zadna predchozi davka
	# neni) - kresli se puvodni cestou.
	if _faze < 3 or not _hotovo or _hold > 0:
		return 1 if _predchozi else 2
	if _pretek:
		return 2
	return 0


func treba_split() -> bool:
	# Byla hotova davka uz rozdelena na "pred hracem"/"po hraci"? Po kazde
	# stavbe je potreba deleni znovu (`app/world_view` ho udela jednou).
	return _mesh_pred == null and _mesh_po == null


func pretek() -> bool:
	return _pretek


func hold() -> int:
	return _hold


func tick_hold() -> void:
	# Stranka se kresli na GPU JEDNOU za zmenu (`UPDATE_ONCE`), takze se po
	# zmene jeste `HOLD_FRAMU` framu kresli puvodni cestou - jinak by prvni
	# frame cetl prazdnou texturu (a to by byl obraz, ktery lhal).
	if _hold > 0:
		_hold -= 1
	# ⚠ 18. session: `hold` ve statistice se musi prepsat, jinak hlasi 2 i po
	# vyprseni (sonda `p21-snimky.gd` se pta na `hold == 0` a cekala by zbytecne).
	if _stats.has("hold"):
		_stats["hold"] = _hold


func texture() -> Texture2D:
	return _viewport.get_texture()


func missing_art_ids() -> Array:
	var out: Array = _diry.duplicate()
	out.sort()
	return out


func stats() -> Dictionary:
	return _stats.duplicate()


func klic_kvadru(index: int) -> int:
	# Klic `render.sort` kvadru na danem indexu (pro test a sondu deleni).
	return _klic[index] if index >= 0 and index < _klic.size() else -1


func invalidate() -> void:
	# Zahodi HOTOVOU davku (seznam se zmeni a bude se stavit znovu).
	# ⚠ 18. session: NEMAZE se pritom `_predchozi_*` - dokud se nova davka
	# nedostavi, kresli se porad ta stara (jinak by kazda zmena seznamu blikla
	# puvodni cestou, ktera stoji ~35 ms/frame).
	_hotovo = false


static func slope_polygon(obj: Dictionary, pos: Vector2) -> PackedVector2Array:
	# Ctyrrohy SVAHU v poradi horni, pravy, dolni, levy (konvexni poradi).
	# Vyska rohu je vyska SOUSEDNI dlazdice (ClassicUO `Land.cs:113-121`).
	# Rovna plocha vraci PRAZDNE pole - kresli se pak land artem.
	# (Do M9 to bylo v `app/world_view.gd`; sem se presunulo, aby geometrii
	# svahu znala i davka. `app/world_view` to predava dal, takze testy
	# i smlouva zustavaji na tom samem miste.)
	var rohy: Array = obj.get("z_corners", [])
	if rohy.size() != 4:
		return PackedVector2Array()
	var z: int = int(obj["z"])
	var z_pravy: int = int(rohy[1])
	var z_levy: int = int(rohy[2])
	var z_dolni: int = int(rohy[3])
	if z == z_pravy and z == z_levy and z == z_dolni:
		return PackedVector2Array()
	var krok: float = float(Const.ISO_STEP)
	var zs: float = float(Const.Z_SCALE)
	return PackedVector2Array([
		pos + Vector2(krok, 0.0),
		pos + Vector2(2.0 * krok, krok + float(z - z_pravy) * zs),
		pos + Vector2(krok, 2.0 * krok + float(z - z_dolni) * zs),
		pos + Vector2(0.0, krok + float(z - z_levy) * zs)])


static func slope_uv(sirka: float = 0.0, vyska: float = 0.0) -> PackedVector2Array:
	# UV rohu v texture (0..1), poradi jako `slope_polygon` = horni, pravy,
	# dolni, levy.
	#
	# ⚠⚠ 18. session (2026-10-08) - VADA "SVAHY JSOU RUZNOBAREVNE / JINA
	# SVETLOST" (uzivatel, fotky 4-6): do teto session tu bylo
	# `(0.5,0) (1,0.5) (0.5,1) (0,0.5)` - tedy STREDY HRAN textury na vrcholy
	# diamantu. Reference mapuje ROHY textury (`_cornerOffsetX = {0,1,0,1}`,
	# `_cornerOffsetY = {0,0,1,1}`, `Batcher2D.cs:16-17` a `:263-270`; v meshi
	# to same `ChunkMesh.cs:464-475`): UV(0,0)->horni, (1,0)->pravy,
	# (1,1)->dolni, (0,1)->levy. Nase mapa byla vuci reference otocena o 45
	# stupnu a jinak skalovana, takze kazdy svah vzorkoval jinou cast textury
	# nez v klientu - presne "ruznobarevne svahy".
	#
	# Kdyz volajici zna velikost textury, prida se PULPIXELOVY INSET proti
	# sevum (`ChunkMesh.cs:458-462`); bez velikosti se vrati rohy 0..1.
	var ix: float = (UV_INSET_PX / sirka) if sirka > 0.0 else 0.0
	var iy: float = (UV_INSET_PX / vyska) if vyska > 0.0 else 0.0
	return PackedVector2Array([
		Vector2(ix, iy), Vector2(1.0 - ix, iy),
		Vector2(1.0 - ix, 1.0 - iy), Vector2(ix, 1.0 - iy)])


static func je_svah(obj: Dictionary, textures) -> bool:
	# ROZHODNUTI o svahu - jedine misto, kde se to pocita (do M9 to bylo
	# v `app/world_view.is_slope`). Dlazdice ma texmap, jeho textura existuje
	# a nektery roh ma jinou vysku nez dlazdice (ClassicUO `Land.cs:98-161`).
	var texmap_id: int = int(obj.get("texmap", 0))
	if texmap_id <= 0:
		return false
	if slope_polygon(obj, Vector2.ZERO).is_empty():
		return false
	return textures.texmap(texmap_id) != null


func build(objects: Array) -> bool:
	# ATOMICKA stavba: zahaji a dobuduje v JEDNOM framu. Pouziva se v testech
	# a tam, kde se na vysledek ceka (druhy pruchod po prelozeni stranky).
	# ⚠⚠ 18. session - VADA "PERIODICKY ZASEK": HRA stavi davku PO CASTECH
	# (`zacni` + `krok`), protoze cela stavba stoji **namERene ~130-170 ms**
	# (`_analyza/p21-chuze.gd`: 6 framu z 2319 ma 75-133 ms a vsechny jsou
	# prestavba). `krok(ms_limit)` udela nejvys `ms_limit` ms prace, takze frame
	# zustane pod 16 ms a pritom se kresli PREDCHOZI davka.
	zacni(objects)
	krok(1.0e9)
	return is_built()


func zacni(objects: Array) -> void:
	# Zahaji novou stavbu. PREDCHOZI davka se pritom DRZI (`_predchozi_*`), aby
	# se behem stavby kreslilo to, co uz je na obrazovce.
	#
	# ⚠ 18. session (namEReno v `p21-chuze.gd`): `_predchozi_*` se prebiraji JEN
	# kdyz zadna stavba nebezi. Kdyby se prebiraly i uprostred stavby, byly by
	# v tu chvili `_mesh_pred/_mesh_po` NULL (nova davka se jeste stavi) a
	# ztratila by se i ta stara - hra by pak cely zbytek stavby kreslila puvodni
	# cestou (namEReno: `puvodni` 75 framu misto 8).
	if _faze >= 3:
		_predchozi_pred = _mesh_pred
		_predchozi_po = _mesh_po
		_predchozi_stats = _stats.duplicate()
		_predchozi = _predchozi_pred != null or _predchozi_po != null
	_mesh_pred = null
	_mesh_po = null
	_posledni_split = -2147483647
	_hotovo = false
	_pretek = false
	_pridano = 0
	_prace_us = 0
	_fronta = objects
	_faze = 0
	_k = 0
	_pokusu = 1
	_potreba = {}
	_poc = {"svahu": 0, "der": 0, "nodraw": 0, "ceka": 0, "bez_slotu": 0}
	_q = 0
	_diry = []
	_rezervuj(objects.size())


func _rezervuj(n: int) -> void:
	# Pole na CELY seznam (indexuje se pozicemi, ne appendem - proto se na konci
	# zkrati na `_q`): jinak by kazdy objekt znamenal realokaci.
	_verts.resize(n * VRCHOLU_NA_KVADR)
	_uvs.resize(n * VRCHOLU_NA_KVADR)
	_barvy.resize(n * VRCHOLU_NA_KVADR)
	_klic.resize(n)


func krok(ms_limit: float) -> void:
	# Posune stavbu o nejvys `ms_limit` ms prace. Faze:
	#   0 = sber potrebnych artu, 1 = predehleni slotu, 2 = geometrie, 3 = hotovo.
	# Cas se kontroluje po `DRZKA` objektech, aby mereni casu nebylo drazsi nez
	# prace sama.
	#
	# ⚠ `_prace_us` scita jen SKUTECNOU praci stavby (ne stenu mezi framy):
	# `stavba_ms` ve statistice je proto "kolik vypocet stál", ne "za jak dlouho
	# se to stihlo" (namEReno 18. session: přes framy vyšlo 2 231 ms, coz bylo
	# zavadejici cislo).
	if _faze >= 3:
		return
	var t0: int = Time.get_ticks_usec()
	_krok_vnitrni(t0, int(ms_limit * 1000.0))
	_prace_us += Time.get_ticks_usec() - t0
	_kroku += 1
	if _faze >= 3:
		# ⚠ Statistiky se pisou ZNOVU po dokonceni: `_dokonci` je zapsalo uvnitr
		# teto prace, takze by v nich chybel tento krok a jeho cas (namEReno:
		# `kroku 0`, `stavba_ms 0.0`).
		_zapis_stats()


func _krok_vnitrni(t0: int, limit: int) -> void:
	var od: int = 0
	while _faze < 3:
		if _faze == 0:
			if _k < _fronta.size():
				_slot_objekt(_fronta[_k])
				_k += 1
				od += 1
				if od >= DRZKA and Time.get_ticks_usec() - t0 >= limit:
					return
				continue
			_faze = 1
			continue
		if _faze == 1:
			var t1: int = Time.get_ticks_usec()
			_pridel_sloty()
			_faze1_us += Time.get_ticks_usec() - t1
			_faze = 2
			_k = 0
			if Time.get_ticks_usec() - t0 >= limit:
				return
			continue
		if _k < _fronta.size():
			_kvadr(_fronta[_k])
			_k += 1
			od += 1
			if od >= DRZKA and Time.get_ticks_usec() - t0 >= limit:
				return
			continue
		_dokonci()


func _dokonci() -> void:
	# Konec stavby: kdyz se slot nevesel, zkusi se JESTE JEDNO prelozeni stranky
	# (append-only by seznam jen zaplnil, ne uvolnil); kdyz ani to nepomuze,
	# `_pretek` znamena "kresli puvodni cestou".
	if _poc["bez_slotu"] > 0 and not _pretek and _pokusu < 2:
		# Druhy pruchod se smi zkusit JEDNOU (`_pokusu`): kdyz se stranka jen
		# zaplnila, prelozeni pomuze; kdyz nepomuze, musi se skoncit - jinak by
		# se stavba zacyklila (namEReno 18. session: testy visely).
		_pokusu += 1
		_ocisti_stranku()
		_pridano = 0
		_faze = 0
		_k = 0
		_potreba = {}
		_poc = {"svahu": 0, "der": 0, "nodraw": 0, "ceka": 0, "bez_slotu": 0}
		_q = 0
		_diry = []
		_rezervuj(_fronta.size())
		return
	if _poc["bez_slotu"] > 0:
		_pretek = true
		push_warning("render.chunk_mesh: runtime atlas %dx%d staci i po prekladu - "
			% [_velikost, _velikost]
			+ "kresli se puvodni cestou; kdo to vidi, at zvedne PAGE_SIZE")
	_verts.resize(_q * VRCHOLU_NA_KVADR)
	_uvs.resize(_q * VRCHOLU_NA_KVADR)
	_barvy.resize(_q * VRCHOLU_NA_KVADR)
	_klic.resize(_q)
	if _pridano > 0:
		# Stranka ma novy obsah -> na GPU se prekresli a `HOLD_FRAMU` framu se
		# jeste kresli PREDCHOZI davka (viz `tick_hold` a `stav`).
		#
		# \u26a0\u26a0 17. session (2026-10-08) - VADA "ROZMAZANE TEXTURY, NEKTERE TAM
		# NEMAJI CO DELAT": `SubViewport.UPDATE_ONCE` znamena "vykresli se
		# JEDNOU PO PRIZNACENI rezimu", ne "pri kazdem `queue_redraw()`".
		# Stranka se proto na GPU prekreslila jen pri PRVNI stavbe a kazda
		# dalsi zmena `_sloty` (novy art i prelozeni stranky) nechala na strance
		# STARE rozvrzeni, zatimco UV v meshi uz mirila jinam - presne to je
		# "rozmazane/zvetsene/nesedi". Dokaz (minimalni repro): samotne
		# `queue_redraw()` pixel nezmeni, `UPDATE_ONCE` + `queue_redraw()` ano
		# (`_analyza/p20b-update-once.gd`, `_analyza/p20b-nalez.md` \u00a72).
		# Rezim se proto PRED kazdym prekreslenim ZNOVU NASTAVI.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_kreslic.queue_redraw()
		_hold = HOLD_FRAMU
	var pouzito: int = 0
	for r in _sloty.values():
		pouzito += int(r.size.x) * int(r.size.y)
	_stats = {"objektu": _fronta.size(), "kvadru": _klic.size(),
		"svahu": _poc["svahu"], "der": _poc["der"], "nodraw": _poc["nodraw"],
		"ceka": _poc["ceka"], "bez_slotu": _poc["bez_slotu"], "slotu": _sloty.size(),
		"plocha_px": pouzito, "stranka": _velikost, "polozek": _polozky.size(),
		"repakov": _repakov, "pretek": _pretek, "hold": _hold,
		"kroku": _kroku, "faze1_ms": _faze1_us / 1000.0,
		"stavba_ms": _prace_us / 1000.0}
	_faze = 3
	_hotovo = not _pretek


func _zapis_stats() -> void:
	# (Prepis statistik po dokonceni stavby - viz `krok`.)
	if _stats.is_empty():
		return
	_stats["hold"] = _hold
	_stats["kroku"] = _kroku
	_stats["faze1_ms"] = _faze1_us / 1000.0
	_stats["stavba_ms"] = _prace_us / 1000.0


func _kvadr(obj: Dictionary) -> void:
	# JEDEN objekt -> jeden kvadr. Do 18. session to bylo telo smycky ve
	# `_stavba`; dnes se vola z `krok` (stavba po castech) a `q`/pocitadla jsou
	# stav objektu (`_q`, `_poc`). KOD SE NEMENIL - jen odsazeni a `continue`
	# -> `return` (ze smycky se stala funkce).
	var krok: float = float(Const.ISO_STEP)
	var zs: float = float(Const.Z_SCALE)
	var stranka_f: float = float(_velikost)
	var vnitrek: float = UV_INSET_PX / stranka_f   # pulpixelovy inset UV u texmap
	var kind: String = str(obj["kind"])
	var art_id: int = int(obj["art_id"])
	var x: int = int(obj["x"])
	var y: int = int(obj["y"])
	var z: int = int(obj["z"])
	var diagonala: int = x + y
	var offset: Vector2i = obj["offset"] if kind == "static" else Vector2i.ZERO
	var pozice := Vector2(float(x - y) * krok - float(offset.x),
		float(diagonala) * krok - float(z * Const.Z_SCALE) - float(offset.y))
	if kind == "land" and art_id <= VOID_LAND_MAX:
		_poc["nodraw"] += 1
		return
	var slot := Rect2i()
	var body0 := Vector2.ZERO
	var body1 := Vector2.ZERO
	var body2 := Vector2.ZERO
	var body3 := Vector2.ZERO
	var barva: Color = Color.WHITE
	var stred_uv := Vector2.ZERO
	var je_to_svah: bool = false
	if kind == "land" and je_svah(obj, _textures):
		slot = _slot(int(obj["texmap"]) + TEXMAP_OFFSET,
			_textures.texmap(int(obj["texmap"])))
		if slot.size.x <= 0:
			_poc["bez_slotu"] += 1
			return
		body0 = pozice + Vector2(krok, 0.0)
		body1 = pozice + Vector2(2.0 * krok,
			krok + float(z - int(obj["z_corners"][1])) * zs)
		body2 = pozice + Vector2(krok,
			2.0 * krok + float(z - int(obj["z_corners"][3])) * zs)
		body3 = pozice + Vector2(0.0,
			krok + float(z - int(obj["z_corners"][2])) * zs)
		je_to_svah = true
		barva = SVAH_BARVA       # viz `SVAH_JAS` v hlavicce
		_poc["svahu"] += 1
	else:
		var tex: Texture2D = _textures.texture(art_id)
		if tex == null and _textures.page_pending(art_id):
			# ⚠ 18. session: stranka atlasu se nacita NA POZADI (16 MB, ~58 ms).
			# Objekt se pro par framu VYNECHA - "jeste nenacteno" NENI
			# "chybi" a kreslit za to magenta diru by byla lez. Kdyz stranka
			# dotece, `app/world_view` davku prestavi (`textures.verze()`).
			_poc["ceka"] += 1
			return
		if tex == null:
			# CHYBEJICI ART NENI TICHO (vada 61 z 5. session): vyrazna
			# magenta, stejny tvar jako `app/world_view._draw_hole`.
			_poc["der"] += 1
			if not _diry.has(art_id):
				_diry.append(art_id)
			if kind == "land":
				body0 = pozice + Vector2(krok, 0.0)
				body1 = pozice + Vector2(2.0 * krok, krok)
				body2 = pozice + Vector2(krok, 2.0 * krok)
				body3 = pozice + Vector2(0.0, krok)
			else:
				body0 = pozice + Vector2(krok, 0.0)
				body1 = pozice + Vector2(2.0 * krok, 0.0)
				body2 = pozice + Vector2(2.0 * krok, krok)
				body3 = pozice + Vector2(krok, krok)
			barva = HOLE_COLOR
			slot = _sloty[BILY]
			var sx: float = (float(slot.position.x) + 0.5 * float(slot.size.x)) / stranka_f
			var sy: float = (float(slot.position.y) + 0.5 * float(slot.size.y)) / stranka_f
			stred_uv = Vector2(sx, sy)
		else:
			slot = _slot(art_id, tex)
			if slot.size.x <= 0:
				_poc["bez_slotu"] += 1
				return
			var w: float = float(slot.size.x)
			var h: float = float(slot.size.y)
			body0 = pozice
			body1 = pozice + Vector2(w, 0.0)
			body2 = pozice + Vector2(w, h)
			body3 = pozice + Vector2(0.0, h)
	var b: int = _q * VRCHOLU_NA_KVADR
	# 6 vrcholu = dva trojuhelniky [0,1,2] a [2,3,0] (rozepsano, bez smycek).
	_verts[b] = body0
	_verts[b + 1] = body1
	_verts[b + 2] = body2
	_verts[b + 3] = body2
	_verts[b + 4] = body3
	_verts[b + 5] = body0
	_barvy[b] = barva
	_barvy[b + 1] = barva
	_barvy[b + 2] = barva
	_barvy[b + 3] = barva
	_barvy[b + 4] = barva
	_barvy[b + 5] = barva
	if barva == HOLE_COLOR:
		# DIRA: barvu nese vrchol, textura je bily ctverecek.
		_uvs[b] = stred_uv
		_uvs[b + 1] = stred_uv
		_uvs[b + 2] = stred_uv
		_uvs[b + 3] = stred_uv
		_uvs[b + 4] = stred_uv
		_uvs[b + 5] = stred_uv
	else:
		var ux: float = float(slot.position.x) / stranka_f
		var uy: float = float(slot.position.y) / stranka_f
		var uw: float = float(slot.size.x) / stranka_f
		var uh: float = float(slot.size.y) / stranka_f
		var uv0 := Vector2(ux, uy)
		var uv1 := Vector2(ux + uw, uy)
		var uv2 := Vector2(ux + uw, uy + uh)
		var uv3 := Vector2(ux, uy + uh)
		if je_to_svah:
			# SVAH: rohy TEXTURY na vrcholy diamantu (reference
			# `ChunkMesh.cs:464-475`) + pulpixelovy inset proti sevum.
			uv0 = Vector2(ux + vnitrek, uy + vnitrek)
			uv1 = Vector2(ux + uw - vnitrek, uy + vnitrek)
			uv2 = Vector2(ux + uw - vnitrek, uy + uh - vnitrek)
			uv3 = Vector2(ux + vnitrek, uy + uh - vnitrek)
		_uvs[b] = uv0
		_uvs[b + 1] = uv1
		_uvs[b + 2] = uv2
		_uvs[b + 3] = uv2
		_uvs[b + 4] = uv3
		_uvs[b + 5] = uv0
	_klic[_q] = _sort.sort_key(obj)
	_q += 1


func _slot_objekt(obj: Dictionary) -> void:
	# FAZE 0 stavby: ktery art (nebo texmap) tenhle objekt potrebuje? Slot se
	# pridava jen jednou na klic, takze se `_potreba` jen plni.
	var kind: String = str(obj["kind"])
	var klic: int = 0
	var tex: Texture2D = null
	if kind == "land" and je_svah(obj, _textures):
		klic = int(obj["texmap"]) + TEXMAP_OFFSET
		tex = _textures.texmap(int(obj["texmap"]))
	else:
		# ⚠ 18. session: MOBILY A PREDMETY se predpocitavaji TAKY. Do teto
		# session se vyjimaly (`continue` s komentarem o `hranice()`), jenze
		# `hranice()` uz neexistuje a jejich art se tim nepredpocital - stranka
		# se pak mohla naplnit az behem stavby (`_slot` uvnitr `_stavba`).
		klic = int(obj["art_id"])
		tex = _textures.texture(klic)
	if tex == null or _sloty.has(klic) or _potreba.has(klic):
		return
	_potreba[klic] = [tex.get_height(), tex.get_width(), tex]


func _pridel_sloty() -> void:
	# FAZE 1 stavby: PREDPOCITANI SLOTU (17. session) - arty se seradi podle
	# VYSKY SESTUPNE a prideli se jim sloty ("first fit decreasing height").
	# ⚠ DULEZITE: bez tohoto kroku se balí v poradi seznamu a vznikaji "zubate"
	# radky, ktere sezerou vic nez polovinu stranky (namEReno 48,7 % vyuziti).
	var potreba: Dictionary = _potreba
	var klice: Array = potreba.keys()
	# Sestupne podle vysky, pri shode podle sirky (determinismus!).
	klice.sort_custom(func(a, b):
		if int(potreba[a][0]) != int(potreba[b][0]):
			return int(potreba[a][0]) > int(potreba[b][0])
		if int(potreba[a][1]) != int(potreba[b][1]):
			return int(potreba[a][1]) > int(potreba[b][1])
		return int(a) < int(b))
	for k in klice:
		if _pretek:
			break
		_slot_rozmer(int(k), int(potreba[k][1]), int(potreba[k][0]), potreba[k][2])


func _ocisti_stranku() -> void:
	# Zacne stranku znovu: zahodi sloty i kurzor. Obsah na GPU se prekresli
	# (prazdna stranka + nove polozky), proto `_pridano` a `HOLD_FRAMU`.
	_sloty = {}
	_polozky = []
	_kreslic.polozky = _polozky
	_x = 0
	_y = 0
	_vyska_radku = 0
	_repakov += 1
	_bily_slot()


func split_for_player(klic_hrace: int) -> void:
	# Rozdeli hotovou geometrii na "pred hracem" a "po hraci" podle KLICE
	# (`render.sort.sort_key`), ne podle diagonaly (18. session, viz hlavicka
	# `_klic`). `render.sort` radi vzestupne podle klice, takze je to souvisly
	# usek pole - staci binarni hledani. Kdyz se klic nezmenil, nic se nestavi
	# (stojici hrac neplati nic; namEReno 0,9 ms pri zmene).
	#
	# Hranice: vse s klicem `<= klic_hrace` je PRED hracem. Stejny klic = hrac
	# se kresli po nich (ClassicUO vklada novy objekt na shodny `PriorityZ` ZA
	# existujici, `Chunk.cs:310-321`).
	if not _hotovo or _pretek or klic_hrace == _posledni_split:
		return
	var t0: int = Time.get_ticks_usec()
	var lo: int = 0
	var hi: int = _klic.size()
	while lo < hi:
		var stred: int = (lo + hi) / 2
		if _klic[stred] <= klic_hrace:
			lo = stred + 1
		else:
			hi = stred
	_mesh_pred = _mesh_z_rozsahu(0, lo)
	_mesh_po = _mesh_z_rozsahu(lo, _klic.size())
	_posledni_split = klic_hrace
	_stats["pred"] = lo
	_stats["po"] = _klic.size() - lo
	_stats["split_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


func draw_before(view) -> void:
	if _mesh_pred != null:
		view.draw_mesh(_mesh_pred, _viewport.get_texture())


func draw_after(view) -> void:
	if _mesh_po != null:
		view.draw_mesh(_mesh_po, _viewport.get_texture())


func draw_before_predchozi(view) -> void:
	if _predchozi_pred != null:
		view.draw_mesh(_predchozi_pred, _viewport.get_texture())


func draw_after_predchozi(view) -> void:
	if _predchozi_po != null:
		view.draw_mesh(_predchozi_po, _viewport.get_texture())


func stats_predchozi() -> Dictionary:
	# Pocitadla PREDCHOZI davky - kdyz se kresli ona, musi to sedet s obrazem
	# (jinak by `drawn`/`kvadru` tvrdily neco jineho, nez je na obrazovce).
	return _predchozi_stats.duplicate()


func _mesh_z_rozsahu(a: int, b: int) -> ArrayMesh:
	if b <= a:
		return null
	var pole: Array = []
	pole.resize(Mesh.ARRAY_MAX)
	pole[Mesh.ARRAY_VERTEX] = _verts.slice(a * VRCHOLU_NA_KVADR, b * VRCHOLU_NA_KVADR)
	pole[Mesh.ARRAY_TEX_UV] = _uvs.slice(a * VRCHOLU_NA_KVADR, b * VRCHOLU_NA_KVADR)
	pole[Mesh.ARRAY_COLOR] = _barvy.slice(a * VRCHOLU_NA_KVADR, b * VRCHOLU_NA_KVADR)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pole)
	return m


func _bily_slot() -> void:
	# Bily ctverecek pro diry (barvu pak dava vrchol, ne textura).
	var r := Rect2i(0, 0, BILA_VELIKOST, BILA_VELIKOST)
	_sloty[BILY] = r
	_polozky.append({"pos": Vector2(r.position), "tex": null,
		"velikost": Vector2(r.size)})
	_x = r.size.x + PAD
	_y = 0
	_vyska_radku = r.size.y
	_pridano += 1


func _slot(klic: int, tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i()
	return _slot_rozmer(klic, tex.get_width(), tex.get_height(), tex)


func _slot_rozmer(klic: int, sirka: int, vyska: int, tex) -> Rect2i:
	if _sloty.has(klic):
		return _sloty[klic]
	if _pretek:
		return Rect2i()
	if sirka <= 0 or vyska <= 0 or sirka > _velikost or vyska > _velikost:
		# Art je SAM vetsi nez stranka: to se prelozenim nespravi.
		_pretek = true
		push_warning("render.chunk_mesh: art %d ma %dx%d px - do stranky %d se nevejde"
			% [klic, sirka, vyska, _velikost])
		return Rect2i()
	if _x + sirka > _velikost:
		_y += _vyska_radku + PAD
		_x = 0
		_vyska_radku = 0
	if _y + vyska > _velikost:
		return Rect2i()                 # plno -> `build` stranku prelozi
	var r := Rect2i(_x, _y, sirka, vyska)
	_sloty[klic] = r
	_polozky.append({"pos": Vector2(r.position), "tex": tex,
		"velikost": Vector2(r.size)})
	_pridano += 1
	_x += sirka + PAD
	_vyska_radku = maxi(_vyska_radku, vyska)
	return r
