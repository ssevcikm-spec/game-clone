extends RefCounted
# Kreslici seznam pro viditelne bloky (granule render.chunk; docs/02 §2.4).
#
# Postup: pro kazdou dlazdici viditelne oblasti se prida `land` s jeho `z`;
# pro kazdy dotceny blok 8x8 se projdou VSICHNI jeho statiky a prevedou se
# z lokalnich `x`,`y` (0..7) na svetove. Hotovy seznam se preda
# `render.sort.draw_order`, takze se kresli v poradi (x+y) -> vrstva -> `z`.
# Kreslici uzel ho jen projde v tom poradi: `z_index` na to pouzit NELZE,
# klic roste do milionu a Godot bere jen -4096..4096 (docs/02 past P21).
#
# CACHE: seznam je pro dany pohled hotovy; `invalidate()` ho zahodi (vola ho
# `app/world_view.gd` pri zmene pohledu, pozdeji `sim.movement` pri zmene
# bloku). Textury se v seznamu NEDRZI - drzi je `render.textures` se stropem
# pameti; kdyby je drzel seznam, strop by nic neomezoval (viz hlavicka tam).
#
# TVAR PRVKU (je to zaroven vstup do `render.sort`, ktery chce `{kind,x,y,z}`):
#   {"kind": "land"|"static", "x": int, "y": int, "z": int,
#    "art_id": int, "offset": Vector2i}
# `offset` je posun z manifestu (`ox`,`oy`), ktery se odecte od dlazdice.
#
# LAND NAVIC (2026-10-07, svahy): `texmap` (TexID z tiledata) a `z_corners`
# [horni, pravy, levy, dolni] = vysky rohu dlazdice. Roh pouziva vysku
# SOUSEDNI dlazdice (vychodni pro pravy, jizni pro levy, jihovychodni pro
# dolni) - presne jako ClassicUO (`Land.cs:113-121` `ApplyStretch`). Kresleni
# z toho pozna, ze dlazdice lezi na SVAHU, a natáhne pres ni texmap; rovna
# plocha se kresli dal land artem. Bez toho zustavala v prechodu vysky seda
# dira (uzivatel: "kde je svah, tam neni tile").
#
# Pouziti:
#   var chunk = Chunk.new(map, textures)          # bez tiledata: texmap = 0
#   for obj in chunk.visible(center, 64, 48): ...

const Sort = preload("res://render/sort.gd")
const Iso = preload("res://core/iso.gd")
const Const = preload("res://core/const.gd")
const TiledataScript = preload("res://sim/world/tiledata.gd")
const ITEM_OFFSET: int = 0x4000
# `IsBackground` v tiledata: dlazdice je PODLAHA, ne prekazka. ClassicUO ji
# v `PriorityZ` odecita 1 (`Chunk.cs:246-272`), takze plocha mostu jde PRED
# jeho zabradli - bez toho se na molu u Britannie kreslilo zabradli pod
# dlazdicemi (namEReno 2026-10-07).
const F_BACKGROUND: int = 0x00000001
# ⚠⚠ 19. session (2026-10-08) - V12/V16/V17: "ZOBRAZUJE SE PATRO NADEMNOU,
# ZDIVO Z PATROVI, ZABRADLI, STUL A POSTELE Z PATRA".
#
# Do teto session se skryvalo JEN to, co je `je_strop` (Roof flag nebo
# Surface+Background) a vys nez `hrac_z + 16`. ZDIVO (`plaster wall`, `wooden
# wall`), `window`, `wooden beam`, `wooden post`, `bed` ani zabradli tim
# NEPROJDOU - takze se patro nad hracem kreslilo cele.
#
# Reference to resi JEDNIM CISLEM: `UpdateMaxDrawZ()`
# (`GameSceneDrawingSorting.cs:57-213`) spocte strop `_maxZ` a kresli jen
# objekty s `z < _maxZ` (radky 339 a 833). My ten strop pocitame stejne
# (`strop_patra()`):
#   * na dlazdici hrace a na (x+1,y+1) hleda statik VYS nez `pz + 14`
#     (`PZ_NAD`, radek 87) a strop ponizi na jeho `z`, kdyz plati
#     `(flags & (Transparent|Foliage)) == 0 && (!IsRoof || IsSurface)`
#     (radky 121-136), resp. `(flags & (Transparent|Surface)) == 0 && IsRoof`
#     (radky 168-198),
#   * strop nikdy nejde pod `pz + 16` (`PZ_SKRYT`, radky 205-209),
#   * kdyz se nad hracem nic nenajde, zustava `Const.Z_MAX` (127) = nic se
#     neskryva (pocatek `_maxZ = 127`, radek 76).
# Tim se schovaji VSECHNY objekty patra (zdivo, okno, trabec, postel, zabradli),
# ne jen strechy - a dlazdice, po ktere hrac chodi, zustava: strop je vzdy
# `>= hrac_z + 16`, takze vlastni podlaha hrace (`z <= hrac_z`) nikdy nezmizi.
#
# ⚠ CO ZUSTAVA Z 18. SESSION (`je_strop` + `hrac_z + PZ_SKRYT`) - NAMERENO
# (`_analyza/p22-patra-sonda.txt`): reference kandidat na strop ma UZSI
# podminku nez `je_strop` - strecha, ktera NEMA `Surface` (`wooden shingles`
# flags 0x14002000, `thatch roof` 0x14006000), strop NENASTAVI. V Britanii je
# takovych mist **204 z 2970** (6,9 %), kde stare pravidlo krylo a reference
# by strechu nechala videt - tam by se vratila vada "postava se zobrazuje pres
# strechu". Pravidlo je proto SJEDNOCENI:
#   skryto = (z >= strop)                                # reference
#          or (kryto and je_strop(art) and z > hrac_z + PZ_SKRYT)   # 18. session
# a `kryto` je true, kdyz reference kandidata nasla NEBO kdyz plati stare
# `pod_strechou()`. Podminka `z > hrac_z + PZ_SKRYT` u druhe casti je DULEZITA:
# `je_strop` zahrnuje i pochuznou podlahu (`Surface+Background`), takze bez ni
# by zmizela podlaha, po ktere hrac stoji.
#
# ⚠ CO SE NEDELA (zapsano, ne zamlcene): reference ma jeste vetev pro LAND
# (radky 94-111: kdyz je na dlazdici hrace land vys nez `pz + 16`, strop se
# snizi a land nad `_maxGroundZ` se take nevykresluje). U nas se land filtruje
# SCHVALNE NIKDY - land je teren, po kterem se chodi, a jeho zmizeni by byla
# horsi vada nez patro navic (docs/09: co se nedela, se pise). UO skladany
# land (jeskynni patro) u nas zatim nema mapova data.
#
# Puvodni 18. session (strechy nad hracem):
# ⚠ 18. session (2026-10-08) - STŘECHY NAD HRÁČEM (vada "v budově nevidím
# vnitřek a postava chodí po střeše"). Reference to resi v `UpdateMaxDrawZ()`
# (`GameSceneDrawingSorting.cs:57-213`): na dlazdici hrace a na (x+1,y+1) se
# hleda statik NAD hrace (vys nez `playerZ + 14`); kdyz je to strecha
# (`TileFlag.Roof = 0x10000000`, `TileDataLoader.cs:525`) nebo pochuzna plocha,
# nastavi se `_noDrawRoofs = true` a strechy se vubec nekresli.
#
# ⚠ NAMERENO na nasich datech (`assets/uo/tiles.json`): flag `Roof` ma jen 1040
# predmetu (hlavne "palm frond roof"), kdezto bezne plastove/bsidlicove strechy
# v Britanii (`slate roof`, art 17792, flags 0x04006201) maji
# `Surface|Background` a flag `Roof` NEMAJI. Proto se za strop/streshu povazuje
# i `Surface & Background` - bez toho by se v dome neuklidilo nic.
const F_SURFACE: int = 0x00000200
const F_ROOF: int = 0x10000000
const F_TRANSPARENT: int = 0x00000004
const F_FOLIAGE: int = 0x00020000
const PZ_NAD: int = 14               # `pz14 = playerZ + 14` (reference)
const PZ_SKRYT: int = 16             # `pz16 = playerZ + 16` (reference)
# Strop, kdyz nad hracem nic neni: reference zacina na 127 (`_maxZ = 127`,
# radek 76) a necha ho tak, kdyz kandidata nenajde - tehdy se neskryva NIC.
# Je to `Const.Z_MAX`, ale konstanta se vypisuje, aby bylo videt, ze to cislo
# ma v referenci vyznam (a aby se nedalo splest s `hrac_z + 16`).
const STROP_NIC: int = 127
# ⚠⚠ NEJNIŽŠÍ `z` SOUVISLÉ STŘECHY (2026-10-09, faze 1 bod 5.3). Reference
# NENASTAVI strop po nalezu strechy na jeji `z`, ale na
# `Map.CalculateNearZ(tileZ, x+1, y+1, tileZ)`
# (`_src/classicuo/src/ClassicUO.Client/Game/Map/Map.cs:164-219`): flood fill po
# souvisle strese (kazdy krok |z - z_souseda| <= 6, `:192`) a vraci NEJMENSI
# `z` teto strechy = OKAP. Teprve to je `_maxGroundZ`, a tedy `_maxZ`
# (`GameSceneDrawingSorting.cs:180-185` a `:203`); `ProcessAlpha` (`:339`) pak
# skryje vsechno s `obj.Z >= _maxZ`.
# NAMERENO 2026-10-09 (`_analyza/p27-patra-sonda.gd`): nas kod daval `z`
# NALEZENE strechy (hreben) - strop vysel az o 9 jednotek vys (49 misto 40 na
# (1477,1612)) a patro se kreslilo. V okoli Britainu se to tykalo 85 z 1369
# proskenovanych dlazdic.
const NEAR_Z_TOLERANCE: int = 6      # `Map.cs:192` (`Math.Abs(z - obj.Z) > 6`)
const NEAR_Z_LIMIT: int = 20000      # pojistka (reference ma mrizku 64x64)
const NEAR_Z_NENI: int = -32768      # "na te dlazdici strecha neni"
# --- FADE PATRA (2026-10-09, faze 1 bod 5.4) ------------------------------
# Reference objekty v urovni stropu a vys NEVYHAZUJE, ale snizuje jim ALFU:
# `ProcessAlpha` (`_src/classicuo/.../GameSceneDrawingSorting.cs:339-368`:
# `obj.Z >= _maxZ` nebo `_noDrawRoofs && IsRoof` -> `CalculateAlpha(ref alpha, 0)`)
# a `CalculateAlpha` (`:398-440`) meni alfu po **25 jednotkach** na tik; tik je
# `Constants.ALPHA_TIME = 20` ms (`Constants.cs:42`), takze cely fade
# 255 -> 0 je 11 tiku = **~220 ms**. `Profile.UseObjectsFading == false` fade
# vypne a alfa se nastavi rovnou (`:400-408`) - u nas `fade_zapnuty`.
#
# ⚠ PROC SE CHYTAJI "ZMIZELE" OBJEKTY A NE DRZI ALFA U VSECH: nas seznam se
# prestavuje po 85-250 ms (namEReno, `_analyza/p20-kadence.gd`), kdezto
# reference ma render list kazdy frame. Alfa zavislá na case by se tedy v
# seznamu "zapekla". Faduji se proto jen objekty, ktere pri prestavbe ZMIZELY
# (a kresli se mimo davku - stejne jako reference routuje fading objekty mimo
# mesh: `ChunkMesh.cs:878-882`).
const ALFA_KROK: int = 25
const ALFA_TIK_MS: int = 20
const ALFA_MAX: int = 255
# "Tik jeste nezacal": prvni volani `fade_objekty` tik NASTARTUJE a alfu
# nemeni, takze objekt je prvni frame jeste plne pruhledny (255) - presne to
# dela reference, kde alfa objektu zacina na 255 a snizuje se az dalsim tikem.
const ALFA_ZACATEK: int = -2147483647

var _map = null
var _textures = null
var _tiledata = null               # muze byt null: pak se texmap nedava
var _iso
var _sort
var _list: Array = []
var _cover: Rect2i = Rect2i()
var _built: bool = false
var _counts: Dictionary = {"land": 0, "static": 0}
# Skryvat strechy/stropy nad hracem? Nastavuje `nastav_hrace()`; dokud to nikdo
# nezavola, kresli se vsechno (chovani pred 18. session).
var skryt_strechy: bool = false
var _hrac_z: int = -9999
# Strop patra (reference `_maxZ`): kresli se jen statiky s `z < _max_z`.
# `STROP_NIC` = nad hracem nic neni a neskryva se.
var _max_z: int = STROP_NIC
# MERENI flood fillu (`near_z`): kolik dlazdic prosla posledni vypocet a jestli
# narazila na pojistku. Nula a "nevim" musi byt videt (docs/08 §8.6).
var near_z_kroku: int = 0
var near_z_limit: bool = false
# Kolikrat se `strop_patra` opravdu POCITAL (cache zásah se nepocita). Slouzi
# k dokazu, ze cache funguje - bez nej by se flood fill delal kazdy frame.
var strop_vypoctu: int = 0
# CACHE stropu podle pozice hrace. Reference pocita `UpdateMaxDrawZ()` JEN kdyz
# se zmeni dlazdice nebo vyska hrace (`GameSceneDrawingSorting.cs:63-68`,
# `_oldPlayerX/Y/Z`); nam se `strop_patra` vola z `nastav_hrace` KAZDY frame
# (pres `look_at_tile`) a s flood filleme by to bylo 2 492 dlazdic na frame
# (namEReno v Britanii). Cache je proto soucast chovani, ne optimalizace:
# bez ni by se hra zasekavala a `near_z` by byl drazsi nez uzitek.
var _strop_klic: String = ""
var _strop_vysledek: Dictionary = {}
# FADE (bod 5.4): objekty, ktere pri posledni prestavbe zmizely a jeste
# dohasinaji. `{obj, a, t}`; `_fade_klic` brani zdvojení.
var fade_zapnuty: bool = true
var fade_zachyceno: int = 0          # celkem zachyceno (pro sondu)
var fade_aktivnich: int = 0          # kolik jich prave dohasina
var _fade: Array = []
var _fade_klic: Dictionary = {}
# MERENI PRESTAVBY SEZNAMU (bod 5.5): rozpad posledniho `_build` na faze.
var _build_stats: Dictionary = {}
var _build_poctu: int = 0
# STAVBA SEZNAMU PO CASTECH (bod 5.5): stav je v MEMBER promennych, ne ve
# slovniku - `PackedInt32Array`/`PackedInt64Array` se ze slovniku kopiruji
# (hodnotovy typ), takze by se mrizka rohu prekopirovala pri kazdem kroku.
const STAVBA_MS: float = 8.0     # kolik ms smi stavba seznamu zabrat ve framu
# FAZE STAVBY SEZNAMU (`_st_faze`). Jsou to POJMENOVANE stavy, ne cisla:
# brana G1 hlasí kazdy literal 4 jako `Z_SCALE`, proto se hodnoty ODVOZUJI
# (a je to i citelnejsi - kdo prida fazi, prida `+ 1`).
const FAZE_NIC: int = -1         # nestavi se
const FAZE_GRID: int = 0         # mrizka vysky rohu
const FAZE_LAND: int = FAZE_GRID + 1          # land dlazdice
const FAZE_STATIKY: int = FAZE_LAND + 1       # statiky po blocich
const FAZE_KLICE: int = FAZE_STATIKY + 1      # klice pro razeni
const FAZE_DOKONCI: int = FAZE_KLICE + 1      # seradit a prohodit
var _st_faze: int = FAZE_NIC     # FAZE_* vys; FAZE_NIC = nestavi se
var _st_oblast: Rect2i = Rect2i()
var _st_y: int = 0
var _st_sirka: int = 0
var _st_zrohy := PackedInt32Array()
var _st_objects: Array = []
var _st_counts: Dictionary = {}
var _st_prvni: Vector2i = Vector2i.ZERO
var _st_posledni: Vector2i = Vector2i.ZERO
var _st_by: int = 0
var _st_bx: int = 0
var _st_klice := PackedInt64Array()
var _st_shift: int = 0
var _st_i: int = 0
var _st_t0: int = 0
var _st_t_grid: int = 0
var _st_t_land: int = 0
var _st_t_statiky: int = 0
var _krok_frame: int = -1
# Kolikrat se stavba posunula po castech (`_krok_stavby` neco udelal). Slouzi
# k mereni: rozpocet plati na CELY frame, takze druhe volani v tomtez framu uz
# nic neposune - a to se jinak neda poznat.
var stavba_kroku: int = 0
# Zmenilo se pri poslednim `nastav_hrace`, co se skryva? Fade se chytá jen
# tehdy (viz `_zachyt_fade`) - jinak by se stavely klice pro vsechny objekty
# pri kazde prestavbe seznamu (namEReno ~100 ms na 16 000 objektech).
var _skryvani_zmeneno: bool = false



func _init(map, textures, tiledata = null) -> void:
	_map = map
	_textures = textures
	_tiledata = tiledata
	_iso = Iso.new()
	_sort = Sort.new()


func invalidate() -> void:
	_built = false


func je_strop(art_id: int) -> bool:
	# Je dany art strecha nebo strop (nad hrace)? `Roof` flag nebo pochuzna
	# plocha s `Background` (viz namEReno v hlavicce). Pouziva se na to, co se
	# skryva nad hracem (18. session); strop patra pocita `strop_patra()`.
	if _tiledata == null:
		return false
	var f: int = _tiledata.flags(art_id)
	return (f & F_ROOF) != 0 or ((f & F_SURFACE) != 0 and (f & F_BACKGROUND) != 0)


func je_roof(art_id: int) -> bool:
	# `TileFlag.Roof` (`TileDataLoader.cs:525`, hodnota `F_ROOF`). Jen dotaz -
	# rozhodnuti o kresleni je v `strop_patra()`/`_build()`.
	if _tiledata == null:
		return false
	return (_tiledata.flags(art_id) & F_ROOF) != 0


func pod_strechou(px: int, py: int, pz: int) -> bool:
	# Je hrac POD strechou/stropem? Hleda se na jeho dlazdici a na (x+1,y+1)
	# (presne jako reference); staci JEDEN statik vys nez `pz + 14`.
	if _tiledata == null:
		return false
	for posun in [Vector2i(0, 0), Vector2i(1, 1)]:
		for record in _statiky_na(px + posun.x, py + posun.y):
			if int(record["z"]) <= pz + PZ_NAD:
				continue
			if je_strop(int(record["tile"]) + ITEM_OFFSET):
				return true
	return false


func strecha_na(x: int, y: int, z: int) -> int:
	# Prvni statik na dlazdici, ktery je STŘECHA a jehoz `z` je od `z` nejvys
	# o `NEAR_Z_TOLERANCE` - doslovny prepis vnitrku `Map.CalculateNearZ`
	# (`Map.cs:180-197`). Vraci `z` strechy, nebo `NEAR_Z_NENI`.
	if _tiledata == null:
		return NEAR_Z_NENI
	for record in _statiky_na(x, y):
		if (_tiledata.flags(int(record["tile"]) + ITEM_OFFSET) & F_ROOF) == 0:
			continue
		var tz: int = int(record["z"])
		if absi(tz - z) > NEAR_Z_TOLERANCE:
			continue
		return tz
	return NEAR_Z_NENI


func near_z(default_z: int, x: int, y: int, z: int) -> int:
	# DOSLOVNY PREPIS `Map.CalculateNearZ` (`Map.cs:164-219`): projde SOUVISLOU
	# strechu a vrati jeji NEJMENSI `z` (okap). Reference to pouziva jako strop
	# po nalezu strechy na (x+1, y+1) - viz hlavicka `NEAR_Z_TOLERANCE`.
	#
	# Odchylky od reference (obě pojmenovane):
	#   * reference rekurzuje, my mame explicitni zasobnik (v GDScriptu by
	#     rekurze pres stovky dlazdic mohla prekrocit strop zasobniku),
	#   * navstivene dlazdice se drzi ve stejne mrizce 64x64 jako reference
	#     (`(x & 0x3F) + ((y & 0x3F) << 6)`, `Map.cs:166`), takze i "preskoceni"
	#     dlazdice vzdalene o nasobek 64 je stejne jako v referenci,
	#   * navic je POJISTKA `NEAR_Z_LIMIT` a pocitadlo `near_z_kroku`: kdyby
	#     data mela strechu pres cele mapy, nesmi to zamrznout. Narazeni na
	#     pojistku se hlasi (`near_z_limit`), ne zamlci.
	near_z_kroku = 0
	near_z_limit = false
	var nejnizsi: int = default_z
	var zasobnik: Array = [Vector3i(x, y, z)]
	var videno: Dictionary = {}
	while not zasobnik.is_empty():
		var bod: Vector3i = zasobnik.pop_back()
		var klic: int = ((bod.x & 0x3F) << 6) | (bod.y & 0x3F)
		if videno.has(klic):
			continue
		videno[klic] = true
		near_z_kroku += 1
		if near_z_kroku > NEAR_Z_LIMIT:
			near_z_limit = true
			push_warning("render.chunk: near_z narazil na pojistku %d dlazdic - strop patra muze byt vyssi, nez ma byt" % NEAR_Z_LIMIT)
			break
		var tz: int = strecha_na(bod.x, bod.y, bod.z)
		if tz == NEAR_Z_NENI:
			continue
		if tz < nejnizsi:
			nejnizsi = tz
		# Reference predava SOUSEDUM `z` teto dlazdice (`Map.cs:212-215`), ne
		# puvodni `z` - proto se souvislost pocita po krocich.
		for smer in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			zasobnik.append(Vector3i(bod.x + smer.x, bod.y + smer.y, tz))
	return nejnizsi


func strop_patra(px: int, py: int, pz: int) -> Dictionary:
	# STROP PATRA - doslovny prepis `UpdateMaxDrawZ()`
	# (`GameSceneDrawingSorting.cs:74-212`). Vraci
	# `{maxz, kandidat}`: kresli se jen statiky s `z < maxz` a `kandidat` je
	# true, kdyz se strop opravdu snizil (reference `_noDrawRoofs`).
	#
	# Poradi vetvi je z reference a NENI zamenne: druha smycka je jen pro
	# STŘECHU bez `Surface` na (x+1,y+1) a jen ta meni `maxground` (radek 200)
	# - a to pres `near_z()` (`Map.CalculateNearZ`), ne na `z` te strechy.
	#
	# ⚠ CACHE podle pozice hrace (2026-10-09): reference pocita `UpdateMaxDrawZ`
	# jen pri zmene dlazdice/vysky (`:63-68`); nam se sem chodi kazdy frame.
	var klic: String = "%d,%d,%d" % [px, py, pz]
	if klic == _strop_klic and not _strop_vysledek.is_empty():
		return _strop_vysledek
	strop_vypoctu += 1
	var maxz: int = STROP_NIC
	var kandidat: bool = false
	if _tiledata == null:
		return {"maxz": maxz, "kandidat": kandidat}
	var pz14: int = pz + PZ_NAD
	# 1) dlazdice hrace (radky 90-137)
	for record in _statiky_na(px, py):
		var tz: int = int(record["z"])
		if tz <= pz14 or maxz <= tz:
			continue
		var f: int = _tiledata.flags(int(record["tile"]) + ITEM_OFFSET)
		if (f & (F_TRANSPARENT | F_FOLIAGE)) == 0 \
				and ((f & F_ROOF) == 0 or (f & F_SURFACE) != 0):
			maxz = tz
			kandidat = true
	var maxground: int = maxz
	var tempz: int = maxz
	# 2) (x+1, y+1) - jen strecha bez `Surface` (radky 147-201)
	for record in _statiky_na(px + 1, py + 1):
		var tz2: int = int(record["z"])
		if tz2 > pz14 and maxz > tz2:
			var f2: int = _tiledata.flags(int(record["tile"]) + ITEM_OFFSET)
			if (f2 & (F_TRANSPARENT | F_SURFACE)) == 0 and (f2 & F_ROOF) != 0:
				maxz = tz2
				# ⚠ `CalculateNearZ`, ne `tz2` (reference `:180-185`): strop je
				# NEJNIŽŠÍ `z` souvisle strechy (okap), ne `z` nalezene dlazdice.
				maxground = near_z(tz2, px + 1, py + 1, tz2)
				kandidat = true
		tempz = maxground
	maxz = maxground
	# 3) strop nikdy nejde pod `pz + 16` (radky 205-209)
	if tempz < pz + PZ_SKRYT:
		maxz = pz + PZ_SKRYT
	var vysledek: Dictionary = {"maxz": maxz, "kandidat": kandidat}
	_strop_klic = klic
	_strop_vysledek = vysledek
	return vysledek


func max_draw_z() -> int:
	# Strop patra pro soucasny stav hrace (pro testy a sondy). `STROP_NIC`
	# znamena "nad hracem nic neni" - tehdy se neskryva ani strecha.
	return _max_z


func no_draw_roofs() -> bool:
	return skryt_strechy


func nastav_hrace(px: int, py: int, pz: int) -> bool:
	# Prebira stav hrace. Vraci TRUE, kdyz se zmenilo, co se skryva - tim se
	# zahodi seznam (`invalidate`), aby se patro prekreslilo bez nich.
	# Je to vzacna zmena (vstup/vystup z budovy, prechod patra), ne kazdy krok:
	# `maxz` se meni jen tehdy, kdyz se zmeni kandidat na strop nad hracem.
	var s: Dictionary = strop_patra(px, py, pz)
	# `kryto` = reference nasla strop NEBO plati stare "pod strechou"
	# (18. session). Kdyz kryto NENI, zustava strop `STROP_NIC`.
	var kryto: bool = bool(s["kandidat"]) or pod_strechou(px, py, pz)
	var novy_max_z: int = int(s["maxz"]) if kryto else STROP_NIC
	var zmena: bool = novy_max_z != _max_z or kryto != skryt_strechy
	_max_z = novy_max_z
	skryt_strechy = kryto
	_hrac_z = pz
	if zmena:
		# FADE se chytá JEN kdyz se zmenilo, co se skryva (2026-10-09, bod 5.5):
		# `_zachyt_fade` stavi pro kazdy objekt klic (retezec), a pri 16 000
		# objektech to bylo ~100 ms na KAZDOU prestavbu - i tehdy, kdyz se
		# skryvani vubec nezmenilo (coz je vetsina prestaveb pri chuzi).
		_skryvani_zmeneno = true
		invalidate()
	return zmena



func _statiky_na(x: int, y: int) -> Array:
	# Statiky JEDNE dlazdice (blok 8x8 drzi lokalni souradnice 0..7).
	var bx: int = (x / Const.BLOCK_SIZE) * Const.BLOCK_SIZE
	var by: int = (y / Const.BLOCK_SIZE) * Const.BLOCK_SIZE
	var lx: int = x % Const.BLOCK_SIZE
	var ly: int = y % Const.BLOCK_SIZE
	var out: Array = []
	for record in _map.statics_at(bx, by):
		if int(record["x"]) == lx and int(record["y"]) == ly:
			out.append(record)
	return out


func is_built() -> bool:
	return _built


func counts() -> Dictionary:
	return _counts.duplicate()


func cover() -> Rect2i:
	return _cover


func screen_position(obj: Dictionary) -> Vector2:
	# Kam presne se prvek kresli. `core.iso.to_screen` vraci horni vrchol
	# diamantu dlazdice; art statiku ma `ox`,`oy` tak, ze se od dlazdice
	# ODECITA (vzorec je v hlavicce `tools/uoextract/atlas.py`). Je to tady
	# (a ne v kreslicim uzlu), aby se geometrie dala merit testem.
	return _iso.to_screen(int(obj["x"]), int(obj["y"]), int(obj["z"])) \
		- Vector2(obj["offset"])


func visible(center: Vector2i, tiles_x: int, tiles_y: int, rozpocet_ms: float = -1.0) -> Array:
	# SEZNAM PRO POHLED. `rozpocet_ms < 0` = postav ho CELY hned (testy, sondy,
	# kdo potrebuje hotovy vysledek). `>= 0` = postav ho PO CASTECH: dokud neni
	# hotovy, vraci se STARY seznam (presne jako `chunk_mesh` kresli predchozi
	# davku) - jinak by se kreslil neuplny seznam s dirami u okraju.
	#
	# ⚠⚠ 2026-10-09 (faze 1 bod 5.5) - ZBYVAJICI ZASEK PRI CHUZI: cela stavba
	# stoji **179-199 ms** a byla to JEDINA zbylá pricina zaseku. NAMERENO
	# sondou `_analyza/p29-zasek.gd`: frame 576 = 145,6 ms presne ve framu, kdy
	# `prestaveb` stouplo z 1 na 2; atlas to NENI (`hold 0`, `ceka 0`).
	# Rozpad: grid ~21-33 ms, land ~59-61, statiky ~53-56, klice ~46.
	var want := Rect2i(center.x - tiles_x / 2, center.y - tiles_y / 2, tiles_x, tiles_y)
	if _stavba_bezi():
		_krok_stavby(rozpocet_ms)
		if _stavba_bezi():
			return _list                    # jeste se stavi: kresli se stary seznam
	if _built and want == _cover:
		return _list
	_zacni_stavbu(want)
	if rozpocet_ms < 0.0:
		while _stavba_bezi():
			_krok_stavby(-1.0)              # synchronne: dokud neni hotovo
	else:
		_krok_stavby(rozpocet_ms)
	return _list


func stavba_seznamu() -> bool:
	# Stavi se prave ted seznam? (Pro sondu a `app.world_view`.)
	return _stavba_bezi()


func _stavba_bezi() -> bool:
	return _st_faze != FAZE_NIC


func _zacni_stavbu(oblast: Rect2i) -> void:
	# ZACATEK STAVBY SEZNAMU (faze 0 = mrizka vysky, 1 = land, 2 = statiky,
	# 3 = klice pro razeni, 4 = prohozeni hotoveho seznamu).
	_st_faze = FAZE_GRID
	_st_oblast = oblast
	_st_y = oblast.position.y
	_st_sirka = oblast.size.x + 1
	_st_zrohy = PackedInt32Array()
	_st_objects = []
	_st_counts = {"land": 0, "static": 0, "skryto": 0}
	_st_prvni = _iso.block_of(oblast.position.x, oblast.position.y)
	_st_posledni = _iso.block_of(oblast.end.x - 1, oblast.end.y - 1)
	_st_by = _st_prvni.y
	_st_bx = _st_prvni.x
	_st_klice = PackedInt64Array()
	_st_i = 0
	_st_t0 = Time.get_ticks_usec()
	_st_t_grid = 0
	_st_t_land = 0
	_st_t_statiky = 0


func _krok_stavby(rozpocet_ms: float) -> void:
	# Posune stavbu. `rozpocet_ms < 0` = bez limitu (synchronni cesta).
	# ⚠ Bez limitu se smi pracovat jen JEDNOU za frame: `_list()` se vola
	# nekolikrat za frame a rozpocet by se jinak nasobil.
	if not _stavba_bezi():
		return
	var limitovany: bool = rozpocet_ms >= 0.0
	if limitovany:
		var frame: int = Engine.get_process_frames()
		if frame == _krok_frame:
			return
		_krok_frame = frame
	stavba_kroku += 1
	var konec: int = 0
	if limitovany:
		konec = Time.get_ticks_usec() + int(maxf(0.0, rozpocet_ms) * 1000.0)
	# POJISTKA: stavba se sklada z faz, ktere se musi posouvat. Kdyby se nektera
	# zasekla, hra by zamrzla - proto strop na pocet kroku a HLASTE to (ticha
	# smycka je horsi nez chyba, docs/09).
	var kroku: int = 0
	while _stavba_bezi():
		_krok_faze()
		kroku += 1
		if kroku > 200000:
			push_error("render.chunk: stavba seznamu se zasekla ve fazi %d po %d krocich - konci se"
				% [_st_faze, kroku])
			print("[chunk] DIAG: faze=", _st_faze, " y=", _st_y, " oblast=", _st_oblast,
				" end=", _st_oblast.end, " bx=", _st_bx, " by=", _st_by,
				" i=", _st_i, " objektu=", _st_objects.size(), " sirka=", _st_sirka)
			_st_faze = FAZE_NIC
			break
		if limitovany and Time.get_ticks_usec() >= konec:
			break


func _krok_faze() -> void:
	match _st_faze:
		FAZE_GRID:
			_faze_grid()
		FAZE_LAND:
			_faze_land()
		FAZE_STATIKY:
			_faze_statiky()
		FAZE_KLICE:
			_faze_klice()
		_:
			_faze_dokonci()


func _faze_grid() -> void:
	# JEDEN radek mrizky vysky rohu (`_z_grid` po castech).
	if _st_zrohy.is_empty():
		_st_zrohy.resize(_st_sirka * (_st_oblast.size.y + 1))
	for x in range(_st_oblast.position.x, _st_oblast.end.x + 1):
		_st_zrohy[(_st_y - _st_oblast.position.y) * _st_sirka + (x - _st_oblast.position.x)] \
			= int(_map.z_at(x, _st_y))
	_st_y += 1
	if _st_y > _st_oblast.end.y:
		_st_faze = FAZE_LAND
		_st_y = _st_oblast.position.y
		_st_t_grid = Time.get_ticks_usec()


func _faze_land() -> void:
	# JEDEN radek land dlazdic.
	# ⚠ `>=` (ne `>`): land se bere z rozsahu `position.y .. end.y - 1` (jako
	# puvodni `range(area.position.y, area.end.y)`). S `>` se zpracoval jeste
	# radek `end.y`, ktery uz do oblasti NEPATRI - a protoze mrizka rohu ma
	# jen `size.y + 1` radku, spadl pristup na `_st_zrohy` mimo pole. GDScript
	# pri chybe PRERUSI funkci, takze se `_st_y += 1` nikdy neprovedlo a stavba
	# se zacyklila (namEReno 2026-10-09: 200 000 kroku a 600 000 objektu).
	# ⚠ `range(pos, end)` (BEZ koncoveho sloupce) - stejna past jako u `_st_y`:
	# mrizka rohu ma o radek/sloupec vic, ale LAND se bere jen z oblasti, takze
	# `end.x` uz je mimo ni a `_st_zrohy[radek + 1]` by spadl mimo pole.
	var counts: Dictionary = _st_counts
	for x in range(_st_oblast.position.x, _st_oblast.end.x):
		var land: int = _map.land_at(x, _st_y)
		if land < 0:
			continue
		var radek: int = (_st_y - _st_oblast.position.y) * _st_sirka + (x - _st_oblast.position.x)
		var z: int = _st_zrohy[radek]
		_st_objects.append({"kind": "land", "x": x, "y": _st_y, "z": z,
			"art_id": land, "offset": Vector2i.ZERO,
			"texmap": _tiledata.texture(land) if _tiledata != null else 0,
			"z_corners": [z, _st_zrohy[radek + 1], _st_zrohy[radek + _st_sirka],
				_st_zrohy[radek + _st_sirka + 1]]})
		counts["land"] += 1
	_st_y += 1
	if _st_y >= _st_oblast.end.y:
		_st_faze = FAZE_STATIKY
		_st_t_land = Time.get_ticks_usec()


func _faze_statiky() -> void:
	# JEDEN blok statiku (8x8).
	var base_x: int = _st_bx * Const.BLOCK_SIZE
	var base_y: int = _st_by * Const.BLOCK_SIZE
	var counts: Dictionary = _st_counts
	for record in _map.statics_at(base_x, base_y):
		var sx: int = base_x + int(record["x"])
		var sy: int = base_y + int(record["y"])
		if not _st_oblast.has_point(Vector2i(sx, sy)):
			continue
		var art_id: int = int(record["tile"]) + ITEM_OFFSET
		var z_statiku: int = int(record["z"])
		# STROP PATRA (reference `_maxZ`): vsechno v urovni stropu a vys
		# je patro nad hracem - zdivo, okno, trabec, postel, zabradli
		# (V12/V16/V17). `_max_z >= hrac_z + PZ_SKRYT`, takze vlastni
		# podlaha hrace (`z <= hrac_z`) tim nikdy neprojde.
		if z_statiku >= _max_z:
			counts["skryto"] += 1
			continue
		# STŘECHY/STROPY NAD HRÁČEM (18. session): i to, co je pod
		# strojem patra, ale je to strecha/strop nad hlavou hrace.
		# `z > hrac_z + PZ_SKRYT` je tu POVINNE - `je_strop` zahrnuje
		# i pochuznou podlahu, po ktere hrac stoji.
		if skryt_strechy and z_statiku > _hrac_z + PZ_SKRYT and je_strop(art_id):
			counts["skryto"] += 1
			continue
		_st_objects.append({"kind": "static", "x": sx, "y": sy,
			"z": z_statiku, "art_id": art_id,
			"priority_z": _priorita(art_id, z_statiku),
			"offset": _textures.offset(art_id)})
		counts["static"] += 1
	_st_bx += 1
	if _st_bx > _st_posledni.x:
		_st_bx = _st_prvni.x
		_st_by += 1
		if _st_by > _st_posledni.y:
			_st_faze = FAZE_KLICE
			_st_t_statiky = Time.get_ticks_usec()


func _faze_klice() -> void:
	# Pocitani klicu pro razeni je GDScript a stoji ~46 ms na cely seznam
	# (namEReno 2026-10-09) - proto se dela po DAVKACH (256 klicu na krok).
	# `klice.sort()` je naproti tomu C++ a je levne (viz `render.sort.serad`).
	if _st_klice.is_empty():
		_st_klice.resize(_st_objects.size())
		_st_shift = _sort.klice_shift(_st_objects.size())
	var konec: int = mini(_st_i + 256, _st_objects.size())
	for i in range(_st_i, konec):
		_st_klice[i] = _sort.klic_objektu(_st_objects[i], i, _st_shift)
	_st_i = konec
	if _st_i >= _st_objects.size():
		_st_faze = FAZE_DOKONCI


func _faze_dokonci() -> void:
	# Prohozeni: seradit (C++ `sort()` je levne) a vymenit seznam.
	var stary: Array = _list
	_list = _sort.serad(_st_objects, _st_klice)
	_cover = _st_oblast
	_counts = _st_counts
	_built = true
	var t_konec: int = Time.get_ticks_usec()
	_build_stats = {"objektu": _st_objects.size(),
		"grid_ms": float(_st_t_grid - _st_t0) / 1000.0,
		"land_ms": float(_st_t_land - _st_t_grid) / 1000.0,
		"statiky_ms": float(_st_t_statiky - _st_t_land) / 1000.0,
		"razeni_ms": float(t_konec - _st_t_statiky) / 1000.0,
		"celkem_ms": float(t_konec - _st_t0) / 1000.0}
	_build_poctu += 1
	_st_faze = FAZE_NIC
	_zachyt_fade(stary, _cover)


func build_stats() -> Dictionary:
	# Rozpad posledni prestavby seznamu (pro sondu k bodu 5.5). Kdo se ptá na
	# cisla, dostane je i s tim, KOLIKRAT se seznam prestevil.
	var out: Dictionary = _build_stats.duplicate()
	out["prestaveb"] = _build_poctu
	return out


func klic_objektu(obj: Dictionary) -> String:
	# Identita objektu pro fade (a pro rozdil seznamu): druh, dlazdice, vyska,
	# art. Statik ma stejny klic v kazdem seznamu, dokud stoji.
	return "%s:%d,%d,%d,%d" % [str(obj.get("kind", "?")), int(obj["x"]),
		int(obj["y"]), int(obj["z"]), int(obj["art_id"])]


func _zachyt_fade(stary: Array, oblast: Rect2i) -> void:
	# Co bylo kreslene a po prestavbe zmizelo, se FADUJE (reference snizuje
	# alfu, nevyhazuje - viz hlavicka `ALFA_KROK`). Fade vypnuty = nechytá se nic
	# (reference `Profile.UseObjectsFading == false`).
	if not fade_zapnuty or stary.is_empty() or not _skryvani_zmeneno:
		return
	_skryvani_zmeneno = false
	var nove: Dictionary = {}
	for obj in _list:
		nove[klic_objektu(obj)] = true
	# 1) Co je znovu videt, z fade VYPADNE (jinak by se kreslilo dvakrat:
	#    v davce i s alfou). Reference objektu alfu zase ZVYSI - my ho vratime
	#    rovnout alfou (pojmenovana odchylka, viz HANDOFF).
	var zbyva: Array = []
	for zaznam in _fade:
		if nove.has(klic_objektu(zaznam["obj"])):
			_fade_klic.erase(klic_objektu(zaznam["obj"]))
			continue
		zbyva.append(zaznam)
	_fade = zbyva
	# 2) Nove zmizele objekty se chyti - ale JEN ty, ktere zustaly v pohledu:
	#    objekt mimo novy pohled nezmizel "pod stropem", jen odjel z obrazovky
	#    (jinak by se pri kazdem posunu fadovaly tisice objektu).
	for obj in stary:
		var klic: String = klic_objektu(obj)
		if nove.has(klic) or _fade_klic.has(klic):
			continue
		if not oblast.has_point(Vector2i(int(obj["x"]), int(obj["y"]))):
			continue
		_fade_klic[klic] = true
		# `ceka` = fade jeste NEBEZI: objekt je porad v STARE davce, ktera se
		# kresli, dokud se nová davka nedostavi. Spusti ho `spust_fade()`.
		_fade.append({"obj": obj, "a": ALFA_MAX, "t": ALFA_ZACATEK, "ceka": true})
		fade_zachyceno += 1
	# Nove zachycene objekty CEKAJI (jsou jeste ve stare davce) - aktivni jsou
	# jen ty, ktere uz dohasinaji z drivejska.
	fade_aktivnich = _fade.size() - fade_ceka()


func fade_ceka() -> int:
	# Kolik objektu ceka na spusteni fade (jsou jeste ve stare davce).
	var n: int = 0
	for zaznam in _fade:
		if bool(zaznam["ceka"]):
			n += 1
	return n


func spust_fade() -> int:
	# SPUSTI fade objektu, ktere cekaly na novou davku (viz `_zachyt_fade`).
	# Vraci, kolik jich zacalo dohasinat. Volej az ve chvili, kdy je nova davka
	# hotova - do te doby jsou objekty jeste nakreslene tou starou.
	var spusteno: int = 0
	for zaznam in _fade:
		if not bool(zaznam["ceka"]):
			continue
		zaznam["ceka"] = false
		spusteno += 1
	fade_aktivnich = _fade.size() - fade_ceka()
	return spusteno


func fade_objekty(now_ms: int) -> Array:
	# Objekty, ktere prave dohasinaji: vrati `[{obj, alfa}]` a posune stav
	# (25 jednotek na `ALFA_TIK_MS`). Kdo dosahl nuly, vypadne.
	# Objekty, ktere jeste CEKAJI (jsou ve stare davce), se nekresli - jinak by
	# se kreslily dvakrat.
	# Vstup casu je ARGUMENT (jako `render.anim.play(..., now_ms)`), aby se
	# fade dal merit deterministicky.
	var out: Array = []
	var zbyva: Array = []
	for zaznam in _fade:
		if bool(zaznam["ceka"]):
			zbyva.append(zaznam)
			continue
		var a: int = int(zaznam["a"])
		var t: int = int(zaznam["t"])
		if t == ALFA_ZACATEK:
			zaznam["t"] = now_ms        # prvni volani tik nastartuje, alfu nemeni
		elif now_ms - t >= ALFA_TIK_MS:
			a = maxi(0, a - ALFA_KROK)
			zaznam["a"] = a
			zaznam["t"] = now_ms
		if a <= 0:
			_fade_klic.erase(klic_objektu(zaznam["obj"]))
			continue
		out.append({"obj": zaznam["obj"], "alfa": a})
		zbyva.append(zaznam)
	_fade = zbyva
	return out


func fade_pocet() -> int:
	return _fade.size()


func _priorita(art_id: int, z: int) -> int:
	# Poradova vyska pro RAZENI, ne pro kresleni (ClassicUO `PriorityZ`,
	# `Chunk.cs:246-272`): podlaha (`IsBackground`) -1, statik s vyskou +1.
	# Bez tiledata (konstruktor ji smi dostat `null`) se vrati `z` - razeni pak
	# zustane na chovani pred 2026-10-07, jen se o nem vi.
	if _tiledata == null:
		return z
	var v: int = z
	if _tiledata.flags(art_id) & F_BACKGROUND != 0:
		v -= 1
	if _tiledata.height(art_id) != 0:
		v += 1
	return v


