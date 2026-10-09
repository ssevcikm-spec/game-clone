extends RefCounted
# Jedina funkce razeni kresleni (granule render.sort; docs/02 §2.4, past P21).
#
# ⚠⚠ 18. session (2026-10-08) - PRERYVNIK KLICE: DVĚ VADY ZE SNIMKU UZIVATELE
# ("zed prosvita pres strechu", "svah prosvita pres schody/most").
#
# Do teto session se klic pocital jako
#   `(diagonala * 769) + (z - Z_MIN) * 3 + vrstva`
# a mel dve vady, obe NAMERENE proti reference (`_src/classicuo`,
# `View.cs:35-84 CalculateDepthZ`):
#
# 1) VÁHA `z` BYLA MOC MALA (769 na diagonalу). Reference pocita
#    `(x + y) + (127 + z) * 0.01f`: krok mrizky = 1.0, krok `z` = 0.01, takze
#    `z` (rozsah -128..127) prebije nejvys ~**2,55 kroku mrizky**. U nas
#    `K_PER_DIAGONAL = 769 > Z_SPAN * LAYERS = 765`, tedy `z` neprebilo ANI
#    JEDNU diagonalу - a to je presne vada "zed pres strechu": strecha je
#    o 1-2 diagonály dal a vys, ale kreslila se DRIV nez blizsi nizka zed
#    (v klientu ji prekryje). Krok je proto dnes **300** = 765 / 2,55.
#
# 2) LAND BYL VE STEJNEM PORADI JAKO STATIKY. Reference kresli land ve
#    ZVLASTNIM pruchodU PRED statiky (`RenderLists.cs:199-232`: mesh land ->
#    `_tiles` -> `_stretchedTiles` -> mesh statics -> `_statics`), takze **zadny
#    statik nemuze byt prekreslen pudou**. U nas sel svah (land s vysokym `z`)
#    ve stejnem seznamu a statik s nizsim `z` na blizsi diagonale se kreslil
#    PRED nim - presne "svah prosvita pres schody/most". Klic proto ma navic
#    PRUCHOD (land = 0, vse ostatni = 1) jako NEJVYSSI radu.
#
# ⚠ CO TIM ZUSTAVA JAKO VEDOME OMEZENI (zapsano, ne zamlceno): reference ma
# pod objekty Z-BUFFER, takze kopec (land) vpredu schova statik za sebou. My
# mame painter's algoritmus a land je VZDY pod statiky - statik za kopcem je
# tedy videt. Vymena je vedoma: presne to je cena za to, ze svah neprekryva
# schody ani most.
#
# TVAR OBJEKTU - SMLOUVA TO NEPINUJE (nalezeno pri implementaci, patri do
# docs/04 §4.2 k radku `render.sort`):
#   {"kind": "land"|"static"|"mobile"|"item", "x": int, "y": int, "z": int}
# "item" = predmet na zemi (v UO jde s mobilovymi v jednom seznamu); neznamy
# `kind` se kresli jako mobilni a vyvolava jedno varovani, ne ticho.

const Const = preload("res://core/const.gd")

const LAYER_LAND: int = 0
const LAYER_STATIC: int = 1
const LAYER_MOBILE: int = 2
const LAYERS: int = 3
const Z_SPAN: int = Const.Z_MAX - Const.Z_MIN + 1
# PRUCHOD: land se kresli CELY pred statiky (reference `RenderLists.cs:199-232`).
const PASS_LAND: int = 0
const PASS_OBJEKTY: int = 1
# Rozpeti jednoho pruchodU v klíči. Musi byt vetsi nez nejvetsi prostorovy
# klic (`(x + y)` mapy je nejvys 7168 + 4096 = 11264 -> 11264 * 300 = 3,4 M).
const PASS_SPAN: int = 8_000_000
# ⚠ VÁHA `z` VULCI DIAGONALE (viz hlavicka): reference `(127 + z) * 0.01`
# znamena, ze `z` prebije ~2,55 kroku mrizky. `Z_SPAN * LAYERS = 765` je
# rozpeti `z` v klíči, takze krok mrizky je `765 / 2,55 = 300`.
const K_PER_DIAGONAL: int = 300
# ⚠⚠ 19. session (2026-10-08) - V1 ZE ZADANI 19: "pri pohybu se propadam do
# textury mostu" (a nezavisle overeni k tomu naslo, ze hrac je na 4 z 5
# zkousenych dlazdic PREKRYTY statikem na VLASTNI dlazdici).
#
# NAMERENO (`_analyza/p22-teren-most.gd`): na mole u Britannie stoji hrac na
# (1524,1485) s `z = 11` (paluba 10 + vyska prkna 1) a prkno na TEZE dlazdici
# ma `priority_z` 9 (10 - 1 za `IsBackground`) - klic hrace 8 903 119 vs prkno
# 8 903 115, takze prkno je pred hracem SPRAVNE. Problem je jiny: statik na
# TEZE dlazdici, ktery ma `priority_z` VYSSI nez hrac (napr. art 16585 na
# (1501,1599): statik z=10 -> klic 8 930 418 vs hrac 8 930 416, tedy 2 jednotky
# PO hracovi), hrace prekryje - a uprostred kroku kryje hrace i prkno
# o diagonalu vpred (23,3 % viditelnych pixelu hrace).
#
# Reference to neresi klíčem, ale Z-BUFFEREM + pravidlem `mobile.Depth`:
# `GameSceneDrawingSorting.cs:159-166` pocita hloubku mobilu z `maxZ` dlazdice
# hrace, tedy ho kresli jako NEJBLIZSI. My mame painter's algoritmus, takze
# jedina cesta je poslat hrace na KONEC sve diagonaly - a to je presne to, co
# dela `klic_na_konci_diagonaly`: klic hrace je `diagonala * K_PER_DIAGONAL +
# PASS_SPAN - 1`, tedy uvnitr sveho pruchodU (PASS_OBJEKTY = 1) a sve diagonaly
# ZA VSEMI statiky i mobily na te dlazdici, ale stale PRED dalsi diagonalou.
# Invariant, ktery se tim nemení: statik o diagonalu dal ma vetsi klic, takze
# "zed prosvita pres strechu" ani "svah prosvita pres schody/most" se nevraci
# (testy `render_sort` 3c/3d meri presne tohle).
static func klic_nad_diagonalou(diagonal: int) -> int:
	# NEJVETSI klic, ktery muze mit objekt na dane diagonale (bez ohledu na `z`
	# a vrstvu). Pouziva se jako ZALOHA, kdyz volajici nema po ruce seznam
	# objektu (klic hrace se jinak pocita z REALNYCH maxim, viz
	# `app/world_view._sort_key_of_player`).
	return PASS_OBJEKTY * PASS_SPAN + diagonal * K_PER_DIAGONAL \
		+ (Const.Z_MAX - Const.Z_MIN) * LAYERS + (LAYERS - 1)

const KIND_LAYER := {"land": LAYER_LAND, "static": LAYER_STATIC,
	"mobile": LAYER_MOBILE, "item": LAYER_MOBILE}
const KIND_PASS := {"land": PASS_LAND, "static": PASS_OBJEKTY,
	"mobile": PASS_OBJEKTY, "item": PASS_OBJEKTY}

var _warned: bool = false


func priority_z(obj: Dictionary) -> int:
	# PORADOVA VYSKA pro razeni (ClassicUO `PriorityZ`, `Chunk.cs:169-272`) -
	# NENI to `z` z mapy. Statik s vyskou jde +1, podlaha (`IsBackground`) -1;
	# tim se zabradli mostu kresli AZ PO plose dlazdice, i kdyz maji v datech
	# stejne `z` (namEReno 2026-10-07: na molu u Britannie je na 30 dlazdicich
	# prkno i zabradli a prkno melo stejny klic -> prekreslilo ho).
	# Kdo rozdil zná (`render.chunk` cte flagy a vysku z tiledata), posle hotovou
	# hodnotu v `priority_z`; kdo ne, radi se podle `z` jako pred 2026-10-07.
	return int(obj.get("priority_z", obj.get("z", 0)))


func sort_key(obj: Dictionary) -> int:
	# Jedno cislo NA POROVNAVANi - ne pro `z_index`: klic neni male cislo a Godot
	# bere z_index jen -4096..4096.
	#
	# PORADI RADU KLICE (18. session, viz hlavicka):
	#   1. pruchod (land < vse ostatni) - krok `PASS_SPAN`,
	#   2. `x + y` (diagonala) - krok `K_PER_DIAGONAL`,
	#   3. `z` - krok `LAYERS` (stejne jako ClassicUO `CalculateDepthZ`),
	#   4. vrstva (land < static < mobile) - nejmensi vaha.
	# Kdo prehodi 2 a 3 (nebo vyhodi pruchod), dostane zpatky vady ze snimku.
	var kind := str(obj.get("kind", ""))
	var layer: int = int(KIND_LAYER[kind]) if KIND_LAYER.has(kind) else LAYER_MOBILE
	var pruchod: int = int(KIND_PASS[kind]) if KIND_PASS.has(kind) else PASS_OBJEKTY
	var diagonal: int = int(obj.get("x", 0)) + int(obj.get("y", 0))
	var z: int = clampi(priority_z(obj), Const.Z_MIN, Const.Z_MAX)
	return pruchod * PASS_SPAN + diagonal * K_PER_DIAGONAL \
		+ (z - Const.Z_MIN) * LAYERS + layer


func draw_order(objects: Array) -> Array:
	# Deterministicke a STABILNI (docs/02 §2.3): `sort()` stabilni neni, proto
	# poradi vstupu vleze do klicu. Stejne klic = poradi vstupu; tak to dela i UO.
	#
	# ⚠ VYKON (namEReno 2026-10-07, sonda `_analyza/vlna5-cena.gd`): puvodni
	# verze stavela `[klic, i, objekt]` a radila `sort_custom(_lower)` - porovnani
	# je GDScript a pri 6 095 objektech to je ~76 000 volani, dohromady
	# **85,7 ms** na prestavbu seznamu. Dnes se klic a poradi vstupu sliji do
	# JEDNOHO int64 a radi se built-in `sort()` (C++): stejne poradi, zlomek casu.
	#
	# ⚠ 2026-10-09 (bod 5.5): rozdelene na `klice()` + `serad()`, aby se dala
	# stavba seznamu delat PO CASTECH (pocitani klicu je GDScript a je to
	# nejdrazsi cast; `klice.sort()` je C++ a je levne). `draw_order` zustava
	# jako slozeni obojiho - pouzivaji ho testy i synchronni cesta.
	return serad(objects, klice(objects))


func klice(objects: Array) -> PackedInt64Array:
	# Klic kazdeho objektu + jeho poradi vstupu v jednom int64 (viz `draw_order`).
	var n: int = objects.size()
	var shift: int = klice_shift(n)
	var out := PackedInt64Array()
	out.resize(n)
	for i in n:
		out[i] = klic_objektu(objects[i], i, shift)
	return out


func klice_shift(n: int) -> int:
	# Kolik bitu potrebuje PORADI VSTUPU, aby se veslo do klice (`serad` i
	# stavba po castech musi pocitat stejnym vzorcem - jinak by se rozesly).
	var shift: int = 1
	while (1 << shift) < n:
		shift += 1
	return shift


func klic_objektu(obj: Dictionary, i: int, shift: int) -> int:
	# Klic JEDNOHO objektu. Pouziva ho `klice()` i stavba seznamu po castech
	# (`render.chunk_renderer._faze_klice`), aby se logika nezdvojovala.
	if not KIND_LAYER.has(str(obj.get("kind", ""))) and not _warned:
		_warned = true
		push_warning("render.sort: objekt s neznamym `kind` - kresli se jako mobilni")
	return (sort_key(obj) << shift) | i


func serad(objects: Array, klice_v: PackedInt64Array) -> Array:
	# Seradi objekty podle klicu z `klice()` (C++ `sort()` + jedno projiti).
	var n: int = objects.size()
	var shift: int = klice_shift(n)
	var mask: int = (1 << shift) - 1
	klice_v.sort()
	var out: Array = []
	out.resize(n)
	for i in n:
		out[i] = objects[int(klice_v[i] & mask)]
	return out
