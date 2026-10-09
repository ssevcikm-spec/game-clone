extends RefCounted
# app.window (2026-10-09, faze 1 bod 5.2) - GEOMETRIE OKNA: kde je svet, kde je
# cerny pas GUI a kde bydli okna HUDu.
#
# PROC JE TO SAMOSTATNY MODUL: do tohoto dne se geometrie pocitala JEDNOU
# v `app/main._setup_ui()` z `get_viewport_rect()`, takze se zvetsenim okna
# NIC nezmenilo. NAMERENO (`_analyza/p26-okno.gd`): okno systemu 1600x900 ->
# platno (viewport) i svet zustaly 1280x720, viditelne dlazdice tytez.
#
# JAK TO MA REFERENCE: ram sveta je VOLITELNY. Svět se kresli do obdelniku
# `Camera.Bounds`, ktery se uklada a meni (`_src/classicuo/src/ClassicUO.Client/
# Game/Scenes/GameScene.cs:102-105`), hrac ho tahne za ram
# (`Game/UI/Gumps/WorldViewportGump.cs:128-150`) a je i prepinac "fullsize"
# (`Game/UI/Gumps/OptionsGump.cs:4113-4133`). Kamera se centruje na ten
# obdelnik, ne na okno (`GameCursor.cs:655-656`).
#
# PROC PRAVE TAKHLE: funkce jsou CISTE (zadny Node, zadny Input, zadne
# `get_viewport_rect`), takze se daji merit bez okna - a `app/main` z nich jen
# stavi uzly. Kdo potrebuje rozmer, preda ho jako argument.

const Const = preload("res://core/const.gd")

# Sirka a vyska cerneho pasu s GUI v px (rozhodnuti uzivatele 2026-10-08:
# "stary zpusob UO" - okno viditelneho sveta a VEDLE nej cerny pas).
const PAS_VPRAVO: int = 320
const PAS_DOLE: int = 120

# Kde stoji okna HUDu, kdyz pas NENI (fullsize = svet je cele okno): okna
# v UO plavou NAD svetem. Cislo je ROZHODNUTI o rozlozeni (vyska stavoveho
# radku ~20 px + 8 px odsazeni), ne prevzate pravidlo - proto je tu pojmenovane.
const OKNO_ODSAZENI: float = 8.0
const STATUS_VYSKA: float = 28.0


func pas(rozmer: Vector2, fullsize: bool) -> Vector2:
	# Velikost cerneho pasu. Ve fullsize je NULOVY (svet = cele okno).
	# Vetsi nez okno byt nemuze: na malem okne by zbyl zaporny svet.
	if fullsize:
		return Vector2.ZERO
	return Vector2(minf(float(PAS_VPRAVO), rozmer.x), minf(float(PAS_DOLE), rozmer.y))


func svet_obal(rozmer: Vector2, fullsize: bool) -> Rect2:
	# OBdelnik světa v px okna (levy horni roh je 0,0 - svet je vlevo nahore,
	# pas je vpravo a dole, presne jako `app/main._setup_ui`).
	var p: Vector2 = pas(rozmer, fullsize)
	return Rect2(Vector2.ZERO, Vector2(maxf(0.0, rozmer.x - p.x), maxf(0.0, rozmer.y - p.y)))


func stred_sveta(rozmer: Vector2, fullsize: bool) -> Vector2:
	# STŘED viditelneho sveta na obrazovce = kam ma kamera postavit hrace
	# (`world_view.gui_odsazeni` je polovina pasu, proto `rozmer/2 - pas/2`).
	# Reference ma stred stejne: `Bounds.X + Width/2`
	# (`GameCursor.cs:655-656`), a `Bounds` je prave svet.
	return svet_obal(rozmer, fullsize).size / 2.0


func pozice_oken(rozmer: Vector2, fullsize: bool) -> Dictionary:
	# Kde bydli okna HUDu. S pasem: stavovy radek DOLE v pasu, zurnal VPRAVO
	# v pasu (svet nezakryvaji). Bez pasu (fullsize): plavou nad svetem -
	# stavovy radek u spodni hrany, zurnal u prave (rozhodnuti o rozlozeni).
	var p: Vector2 = pas(rozmer, fullsize)
	var svet: Rect2 = svet_obal(rozmer, fullsize)
	var status: Vector2
	var zurnal: Vector2
	if fullsize:
		status = Vector2(OKNO_ODSAZENI, maxf(0.0, rozmer.y - STATUS_VYSKA))
		zurnal = Vector2(maxf(0.0, rozmer.x - float(PAS_VPRAVO) + OKNO_ODSAZENI), OKNO_ODSAZENI)
	else:
		status = Vector2(OKNO_ODSAZENI, svet.size.y + OKNO_ODSAZENI)
		zurnal = Vector2(svet.size.x + OKNO_ODSAZENI, OKNO_ODSAZENI)
	return {"status_bar": status, "journal": zurnal}
