extends RefCounted
# Jmena a pruhy nad objekty (granule `render.names`; docs/04 §4.4, docs/05 §5.5.2).
#
# CO TO JE: TENKY KLIENT. Nic nepocita a nic si nepamatuje - dostane hotove
# radky (`Dictionary`) a vykresli je. Kdo je sestavuje, je `app/world_view`
# (jako u ostatnich UI modulu: `ui/` a `render/` nesmi menit stav sveta).
#
# ODKUD BARVY: `notoriety` (docs/05 §5.9, `_src/servuo/Server/Notoriety.cs:8`).
# NOTORIETY_* konstanty jsou PREPSANE z `sim/entity/notoriety.gd` - kdyby se
# rozesly, `tests/cases/name_plates.gd` to chyti (test cte obe strany).
# Cisla, ktera smi klient kreslit, jsou jen ta, ktera simulace posila v udalosti
# (`mobile_added` ma `notoriety`); klient si notoriety NEDOPOCITAVA.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `barvy()` je verejne pro test a pro `app/world_view` (jedno misto, kde
#     se notoriety preklada na barvu - kdyby si ji kreslic pocital sam, byly
#     by to dve pravdy o te same veci),
#   * `text_pro_pruh(...)` vraci text, ktery se nad pruh pise; je oddeleny od
#     kresleni, aby se dal merit bez okna (headless test).
#
# PRAVIDLA KRESLENI (docs/05 §5.5.2: "jmeno cile a jeho HP pruh po kliku"):
#   * jmeno se kresli VZDY, kdyz ho objekt ma (jinak by hrac nevidel, na co
#     utoci); pruh jen kdyz `hp_max > 0` a objekt NENI hrac (vlastni pruh ma
#     stavovy pruh v HUDu),
#   * barva pruhu: cervena pod 33 %, oranzova do 66 %, zelena nad (ROZHODNUTI
#     KLONU - reference barvu pruhu neresi; je videt tady, ne schovane),
#   * pruh je SIRKA_PRUHU px siroky a VYSKA_PRUHU px vysoký, s cernym ramem -
#     na 1280x720 musi byt citelny i pri zoomu 1,0.

const Const = preload("res://core/const.gd")

# Notoriety (`sim/entity/notoriety.gd`): 1 innocent, 2 ally, 3 attackable,
# 4 criminal, 5 enemy, 6 murderer, 7 ghost. 0 = "nevim" -> neutralni barva.
const NOTORIETY_INNOCENT := 1
const NOTORIETY_ALLY := 2
const NOTORIETY_ATTACKABLE := 3
const NOTORIETY_CRIMINAL := 4
const NOTORIETY_ENEMY := 5
const NOTORIETY_MURDERER := 6
const NOTORIETY_GHOST := 7

const BARVA_INNOCENT := Color(0.35, 0.75, 1.0)     # modra (ClassicUO)
const BARVA_ALLY := Color(0.0, 1.0, 0.0)           # zelena
const BARVA_ATTACKABLE := Color(0.85, 0.85, 0.85)  # seda (monstra a zvirata)
const BARVA_CRIMINAL := Color(1.0, 0.55, 0.0)      # oranzova
const BARVA_ENEMY := Color(1.0, 0.2, 0.2)          # cervena
const BARVA_MURDERER := Color(1.0, 0.2, 0.2)       # cervena (jako enemy)
const BARVA_GHOST := Color(0.75, 0.75, 0.75, 0.6)  # pruhledna seda
const BARVA_NEZNAMA := Color(0.85, 0.85, 0.85)

const SIRKA_PRUHU := 44.0
const VYSKA_PRUHU := 5.0
const BARVA_PRUHU_NIZKO := Color(0.9, 0.15, 0.15)
const BARVA_PRUHU_STŘED := Color(0.95, 0.65, 0.1)
const BARVA_PRUHU_VYSOKO := Color(0.2, 0.8, 0.2)
const BARVA_RAMU := Color(0.0, 0.0, 0.0, 0.85)
const BARVA_TEXTU := Color(1.0, 1.0, 1.0)
const ODSAZENI_JMENA := 14.0        # jak vysoko nad linkou zeme jmeno je


func barvy() -> Dictionary:
	# notoriety -> barva. Verejne: test i kreslic se ptaji na TUTEZ hodnotu.
	return {
		NOTORIETY_INNOCENT: BARVA_INNOCENT,
		NOTORIETY_ALLY: BARVA_ALLY,
		NOTORIETY_ATTACKABLE: BARVA_ATTACKABLE,
		NOTORIETY_CRIMINAL: BARVA_CRIMINAL,
		NOTORIETY_ENEMY: BARVA_ENEMY,
		NOTORIETY_MURDERER: BARVA_MURDERER,
		NOTORIETY_GHOST: BARVA_GHOST,
	}


func barva(notoriety: int) -> Color:
	var b: Dictionary = barvy()
	return b.get(int(notoriety), BARVA_NEZNAMA)


func barva_pruhu(hp: int, hp_max: int) -> Color:
	# Barva podle podilu zivota. Neplatna maxima (0 a mene) = "nemerene":
	# vracime neutralni barvu, protoze "0 %" by vypadalo jako smrt.
	if hp_max <= 0:
		return BARVA_NEZNAMA
	var podil: float = float(hp) / float(hp_max)
	if podil < 0.33:
		return BARVA_PRUHU_NIZKO
	if podil < 0.66:
		return BARVA_PRUHU_STŘED
	return BARVA_PRUHU_VYSOKO


func sirka_pruhu() -> float:
	return SIRKA_PRUHU


func vyska_pruhu() -> float:
	return VYSKA_PRUHU


func text_pro_pruh(hp: int, hp_max: int) -> String:
	# Text se stavi VZDY (i pro neplatna cisla) - prazdny text by splynul
	# s "objekt nema pruh".
	if hp_max <= 0:
		return "hp ?"
	return "hp %d/%d" % [int(hp), int(hp_max)]


func ma_pruh(obj: Dictionary, je_hrac: bool = false) -> bool:
	# Hrac ma vlastni pruh v HUDu (`ui.status_bar`), takze nad hlavou ne.
	if je_hrac:
		return false
	return int(obj.get("hp_max", 0)) > 0


func kresli(cilem: CanvasItem, stred: Vector2, obj: Dictionary,
		je_hrac: bool = false) -> void:
	# `stred` je STŘED SPODNÍ HRANY objektu (linka zeme), ne jeho levý horní roh.
	var jmeno: String = str(obj.get("name", ""))
	var notoriety: int = int(obj.get("notoriety", 0))
	var font: Font = ThemeDB.fallback_font
	var velikost: int = int(ThemeDB.fallback_font_size)
	var ma_barvu: bool = jmeno != ""
	if ma_barvu:
		var sirka_textu: float = float(font.get_string_size(jmeno,
			HORIZONTAL_ALIGNMENT_LEFT, -1, velikost).x)
		cilem.draw_string(font, stred + Vector2(-sirka_textu / 2.0, -ODSAZENI_JMENA),
			jmeno, HORIZONTAL_ALIGNMENT_LEFT, -1, velikost, barva(notoriety))
	if not ma_pruh(obj, je_hrac):
		return
	var hp: int = int(obj.get("hp", 0))
	var hp_max: int = int(obj.get("hp_max", 0))
	var levy: float = stred.x - SIRKA_PRUHU / 2.0
	var horni: float = stred.y - ODSAZENI_JMENA + 4.0
	# Ram + podklad: bez ramu pruh na svetlem terenu splývá (mereno okem).
	cilem.draw_rect(Rect2(levy - 1.0, horni - 1.0, SIRKA_PRUHU + 2.0, VYSKA_PRUHU + 2.0),
		BARVA_RAMU, true)
	var podil: float = 0.0
	if hp_max > 0:
		podil = clampf(float(hp) / float(hp_max), 0.0, 1.0)
	cilem.draw_rect(Rect2(levy, horni, SIRKA_PRUHU * podil, VYSKA_PRUHU),
		barva_pruhu(hp, hp_max), true)
