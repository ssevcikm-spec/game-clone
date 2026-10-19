extends RefCounted
# render.swing — KRESLENY SVIH (granule `render.swing`; ZADANI-28-HRAC, B1+B2).
#
# PROC TO EXISTUJE: export animaci `assets/uo/anim` NEMA skupinu pro utok
# lidskeho tela (telo 400: `groups.attack = 9`, ale skupiny 0/2/4/21) ani
# zadnou skupinu pro praci. Vlastni art ma jen chuzi (`assets/own-v3`,
# `400/0/*`). Takze se utok a prace kresli z DOSTUPNYCH framu (fallback,
# `render/anim_player.GROUP_FALLBACK`) a tenhle modul k nim pridava VIDITELNY
# svih - jinak by utok byl jen "jina chuze" a hrac by ho nepoznal.
#
# JE TO VLASTNI ART, ne art z instalace UO: svih je nakresleny kodem (2x2 px
# ctverecky po oblouku), takze neporusuje pravidlo "z instalace UO nic noveho"
# (`docs/01 §1.5 bod 6`) a je deterministicky (zadny nahodny sum).
#
# CO TENHLE MODUL UMÍ: dat GEOMETRII svihu jako seznam obdelniku v OBRAZOVYCH
# souradnicich vzhledem k zemi postavy (kotva = linka zeme, stejna jako
# `app/world_view._ground_of`). Kresleni i mereni (brana G21) tak pocitaji
# TUTEZ hodnotu - modul sam nic nekresli a nezavisi na scene.
#
# SMER: cisla smeru jsou z `core/const.gd` (0 = E ... 7 = SE) a svetova osa se
# na obrazovku prevadi stejne jako projekce (`screen = ((x-y), (x+y)) * krok`),
# takze svih miri tam, kam postava hledi.

const Const = preload("res://core/const.gd")

# Pocet ctverecku oblouku. 9 je nejmensi cislo, pri kterem je oblouk videt
# jako oblouk a ne jako tecka (overeno snimkem, viz `.tmp/beh2/`).
const KUSU: int = 9
# ⚠ VELIKOST A POLOMER JSOU MERENE (2026-10-19): hra kresli ve vychozim zoomu
# 0,75, takze 2px ctverecek je na obrazovce 1,5 px a hrac ho NECTE (namEReno
# na snimku: svih nebyl videt). 4x4 px s polomerem 22 px je pri zoomu 0,75
# plocha 3x3 px - viditelny zablesk, pri zoomu 1-2 zretelny oblouk.
const VELIKOST: float = 6.0
const POLOMER: float = 26.0
const ROZSAH_STUPNU: float = 120.0   # celkovy uhel oblouku
# Stred otaceni je NAD linkou zeme: postava je ~40 px vysoka, trup je v ~18 px.
const VYSKA_TRUPU: float = -18.0
const BARVA_UTOK := Color(0.80, 0.94, 1.0, 1.0)
const BARVA_PRACE := Color(1.0, 0.86, 0.35, 1.0)


func smer_na_obrazovce(dir: int) -> Vector2:
	# Jednotkovy smer svihu v OBRAZOVYCH souradnicich (y dolu). Svetova osa
	# dlaždice se na obrazovku promita jako ((x-y), (x+y)) - stejny vzorec
	# jako `core/iso.gd`, jen bez meritka (staci smer).
	var d: int = ((dir % 8) + 8) % 8
	var dx: float = float(Const.DIR_DX[d])
	var dy: float = float(Const.DIR_DY[d])
	var s := Vector2(dx - dy, dx + dy)
	if s.length() <= 0.0:
		return Vector2(1.0, 0.0)
	return s.normalized()


func kusy(dir: int, progres: float, prace: bool = false) -> Array:
	# GEOMETRIE SVIHU: obdelniky v px vzhledem k zemni lince postavy.
	# `progres` 0..1 = jak daleko svih je (0 = zacatek, 1 = doznel); videt je
	# jen cast oblouku, takze dva snimky v case se LISI (to meri brana).
	# `prace` meni jen barvu (viz `barva`) - tvar je stejny, protoze prace
	# i utok jsou "zamachnuti".
	var stred := Vector2(0.0, VYSKA_TRUPU)
	var zaklad: float = smer_na_obrazovce(dir).angle()
	var od: float = zaklad - deg_to_rad(ROZSAH_STUPNU * 0.5)
	var krok: float = deg_to_rad(ROZSAH_STUPNU) / float(maxi(KUSU - 1, 1))
	var p: float = clampf(progres, 0.0, 1.0)
	# Na zacatku svihu je videt kratky usek, na konci cely oblouk.
	var videt: int = clampi(2 + int(round(p * float(KUSU - 2))), 2, KUSU)
	var out: Array = []
	for i in videt:
		var uhel: float = od + krok * float(i)
		var bod: Vector2 = stred + Vector2(cos(uhel), sin(uhel)) * POLOMER
		out.append(Rect2(roundf(bod.x) - VELIKOST * 0.5,
			roundf(bod.y) - VELIKOST * 0.5, VELIKOST, VELIKOST))
	return out


func barva(prace: bool) -> Color:
	# Barva svihu: prace je zluta (jiskry od nastroje), utok bila/ocelova.
	return BARVA_PRACE if prace else BARVA_UTOK
