extends SceneTree
# snapshot-walk.gd - RIDIC, KTERY VYROBI SNIMEK PRO G10 (v repu od 2026-10-12).
#
# PROC JE V REPU: G10 meri pixely VLASTNI POSTAVY na snimku hry. Vlastni art vsak
# hra kresli jen v NEKTERYCH animacich (`anim_fallback_akce: 3`) - v klidu
# (action 4 = idle) kresli UO art. Snimek porizeny ve stoje tedy vlastni postavu
# NEOBSAHUJE a G10 spravne rekne "0 pixelu vlastni postavy" - o hre, ktera je
# v poradku (namEReno 12. 10. 2026: frame ve stoje = 0 px, frame v chuzi =
# 264-273 px po erozi, paleta `assets/own-v3/`).
# Do teto chvile lezel tenhle ridic v `.cache/analysis/demo-chuze.gd`, tedy
# v `.gitignore` - cerstvy klon si ho nedovezl a snimek delal po svem (presne
# to se stalo). Ridic je EVIDENCE/NASTROJ, ne soucast hry: lezi mimo `app/`,
# takze to neni druha cesta k `Input`, kterou zakazuje docs/02 §2.2.
#
# SPOUSTENI (snimek pro G10; cesta MUSI mit dopredna lomítka a slozka existovat):
#   godot --path . --rendering-driver opengl3 --write-movie .cache/render/chuze/frame.png \
#         --script res://tools/gates/snapshot-walk.gd
#   cp .cache/render/chuze/frame00000150.png .cache/render/snapshot.png
#
# KTERY FRAME: 150 (namEReno v chuzi, 366 px presne / 266 po erozi). Frame 130
# je ve stoje (0 px) - cislo se netyka "hezkeho obrazu", ale toho, ze postava
# prave jde. Kdyz se zmeni PLAN nize, cislo se musi premerit.
#
# Co ridic dela: nacte `app/main.tscn`, v urcenych framech posle do Godotu
# SKUTECNOU klavesu (pres `Input.parse_input_event`, tedy tou cestou, kterou jde
# hrac) a poznamena si pozici hrace a stav animace. Na konci vypise souhrn -
# z logu je videt, ze se postava posunula a ze se prepla animace.

const PLAN := [
	# (frame, keycode, stisk) - mezera 40 framu = 660 ms, tedy vic nez krok (400 ms)
	[5, KEY_RIGHT, true], [6, KEY_RIGHT, false],
	[50, KEY_RIGHT, true], [51, KEY_RIGHT, false],
	[95, KEY_UP, true], [96, KEY_UP, false],
	[140, KEY_KP_3, true], [141, KEY_KP_3, false],       # SE (diagonala)
	[170, KEY_LEFT, true], [171, KEY_LEFT, false],       # W: krok zpet na zapad
]

var _f: int = 0
var _kam: int = 0
var _pozice: Array = []
var _akce: Array = []
var _scene = null


func _initialize() -> void:
	_scene = load("res://app/main.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_f += 1
	if _scene == null or _scene.player == null:
		return _f > 240
	for krok in PLAN:
		if int(krok[0]) == _f:
			var event := InputEventKey.new()
			event.keycode = int(krok[1])
			event.pressed = bool(krok[2])
			Input.parse_input_event(event)
	var poz: Vector3i = _scene.player.pos
	if _pozice.is_empty() or _pozice[-1] != poz:
		_pozice.append(poz)
		print("[snimek] frame ", _f, ": pozice ", poz, " smer ", _scene.player.dir,
			" stav staminy ", _scene.player.stam)
	var akce: int = _scene.controller.action() if _scene.controller != null else -1
	if _akce.is_empty() or _akce[-1] != akce:
		_akce.append(akce)
	if _f >= 240:
		print("[snimek] SOUHRN: pozic ", _pozice.size(), " ", _pozice)
		print("[snimek] SOUHRN: akci animace ", _akce, " (0 = walk, 4 = idle)")
		print("[snimek] SOUHRN: kresleno objektu ", _scene.get_node("WorldView").drawn,
			", postava nakreslena ", _scene.get_node("WorldView").player_drawn,
			", chybi sprite ", _scene.get_node("WorldView").player_missing)
		print("[snimek] SOUHRN: animace dostupna ", _scene.get_node("WorldView").anim_available())
		return true
	return false
