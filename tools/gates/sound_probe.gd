extends SceneTree
# sound_probe.gd - DUKAZ C1 (ZADANI-27 §4): udalost -> zvuk se OPRAVDU prehraje.
#
# Proc takhle: `tests/cases/sound.gd` meri ROZHODNUTI modulu (ktera udalost da
# ktery zvuk) bez stromu a bez zvukove karty. "Zvuk se prehral" se ale takto
# merit NEDÁ - `AudioStreamPlayer` mimo bezici scenu neprehraje a modul to
# poctive vraci jako `false`. Tenhle ridic proto spusti REALNOU scenu
# (`app/main.tscn`) a meri na ZIVEM svete:
#   1. BOJ: hrac utoci klavesou `A` (stejna cesta jako hrac) -> hit/hurt/death,
#   2. TEZBA: zavola `sim.harvest.mine` na balvan vedle hrace (demo je stavi na
#      (1,1)) -> `sound{kind:"mine"}`,
#   3. KOVANI: najde vyhen ve svete a zavola `sim.craft.smelt` s rudou z tezby
#      -> `sound{kind:"smith"}`.
# Body 2 a 3 jdou pres SIMULACI, ne pres vstup: v headless se neda mirIT na
# dlazdici (klient bere cil z pozice mysi), ale "sim posle zvuk" je presne to,
# co se ma merit.
#
# Hotovo je, kdyz `prehrano > 0` a `podle_id` neni prazdne (ne "soubor existuje").
#
# Spousteni:
#   godot --headless --path . --fixed-fps 60 --script res://tools/gates/sound_probe.gd

const ItemScript = preload("res://sim/entity/item.gd")

const PLAN := [
	[10, KEY_A, true], [11, KEY_A, false],
	[60, KEY_A, true], [61, KEY_A, false],
	[120, KEY_A, true], [121, KEY_A, false],
	[200, KEY_A, true], [201, KEY_A, false],
	[300, KEY_A, true], [301, KEY_A, false],
]

var _f: int = 0
var _scene = null
var _tezba: Dictionary = {}
var _kovani: Dictionary = {}
var _smrt: Dictionary = {}
var _hurt: Dictionary = {}
var _kdo_hral: Dictionary = {}


func _initialize() -> void:
	_scene = load("res://app/main.tscn").instantiate()
	root.add_child(_scene)


func _zkus_tezbu() -> void:
	# Balvany stoji na (1,1), (2,1), (2,2), (0,2) od hrace (`app/main._postav_balvany`).
	var sim = _scene.sim
	var hrac = sim.registry.get_mobile(int(sim.player_serial))
	if hrac == null:
		return
	# ⚠ SONDA ZVYSI SKILL (Mining 45, Blacksmithy 7): meri se ZAPOJENI zvuku,
	# ne balance - s vychozim skillem umi taveni nahodne selhat ("failed")
	# a pak by se z mereni stalo mereni nahody.
	hrac.skills.set_value(45, 1000)
	hrac.skills.set_value(7, 1000)
	var tezba = sim.systems.get("harvest")
	if tezba == null:
		return
	_tezba = tezba.mine(int(sim.player_serial),
		int(hrac.pos.x) + 1, int(hrac.pos.y) + 1)
	print("[zvuk] tezba: ", _tezba.get("ok"), " / ", _tezba.get("reason"),
		" kind ", _tezba.get("kind"), " serial rudy ", _tezba.get("serial"))


func _zkus_kovani() -> void:
	var sim = _scene.sim
	var craft = sim.systems.get("craft")
	if craft == null:
		return
	var ruda: int = int(_tezba.get("serial", 0))
	if ruda <= 0:
		_kovani = {"ok": false, "reason": "zadna ruda z tezby"}
		return
	var vyhen: int = 0
	for it in _scene.items.values():
		if str(ItemScript.role_of(int(it.tile))) == "forge":
			vyhen = int(it.serial)
			break
	if vyhen <= 0:
		_kovani = {"ok": false, "reason": "vyhen se ve svete nenasla"}
		return
	_kovani = craft.smelt(int(sim.player_serial), ruda, vyhen)
	print("[zvuk] kovani: ", _kovani.get("ok"), " / ", _kovani.get("reason"),
		" ingotu ", _kovani.get("ingots"))


func _zkus_smrt() -> void:
	# SM RT: aby to netrvalo minuty cekanim na auto-utok (swing je ~3 s),
	# zavola sonda realny soubojový system PRIMO: `attack` (zacne boj) a pak
	# `resolve_swing`, dokud cil neumre. Je to tataz cesta, kterou jde hra -
	# jen bez cekani na prodlevu swingu; meri se ZAPOJENI zvuku.
	var sim = _scene.sim
	var boj = sim.systems.get("combat")
	if boj == null:
		return
	var hrac := int(sim.player_serial)
	var ja = sim.registry.get_mobile(hrac)
	# CIL = NEJBLIZSI zivy mobil: prvni v registru muze byt spawn na hrbitove
	# 120 dlazdic dal a `resolve_swing` pak vrati `too_far` (namEReno).
	var cil: int = 0
	var nejlepsi: int = 1 << 30
	for mob in sim.registry.all():
		if int(mob.serial) == hrac or not mob.alive():
			continue
		var d: int = maxi(absi(int(mob.pos.x) - int(ja.pos.x)), absi(int(mob.pos.y) - int(ja.pos.y)))
		if d < nejlepsi:
			nejlepsi = d
			cil = int(mob.serial)
	if cil <= 0:
		_smrt = {"ok": false, "reason": "ve svete neni zadny zivy mobil"}
		return
	print("[zvuk] smrt: nejblizsi cil ", cil, " je ", nejlepsi, " dlazdic od hrace")
	boj.attack(hrac, cil)
	var posledni: Dictionary = {}
	for _i in 40:
		posledni = boj.resolve_swing(hrac, cil)
		if bool(posledni.get("killed", false)):
			break
	_smrt = posledni
	print("[zvuk] smrt: cil ", cil, " -> ", _smrt.get("killed"), " hp ",
		_smrt.get("hp_left"), " (", _smrt.get("reason"), ")")


func _zkus_hurt() -> void:
	# "DOSTALI JSME ZASAH": v modulu se odvozuje z POKLESU hp hrace, takze se
	# musi stat - a aby to nebylo na nahode (monstrum nemusi trefit v okne
	# behu), necha sonda udeřit nejblizsi monstrum PRIMO pres `resolve_swing`.
	var sim = _scene.sim
	var boj = sim.systems.get("combat")
	if boj == null:
		return
	var hrac := int(sim.player_serial)
	var ja = sim.registry.get_mobile(hrac)
	var cil: int = 0
	var nejlepsi: int = 1 << 30
	for mob in sim.registry.all():
		if int(mob.serial) == hrac or not mob.alive():
			continue
		var d: int = maxi(absi(int(mob.pos.x) - int(ja.pos.x)), absi(int(mob.pos.y) - int(ja.pos.y)))
		if d < nejlepsi:
			nejlepsi = d
			cil = int(mob.serial)
	if cil <= 0 or nejlepsi > 1:
		_hurt = {"ok": false, "reason": "zadne monstrum na dosah (%d)" % nejlepsi}
		print("[zvuk] hurt: NEMERENO - ", _hurt.get("reason"))
		return
	var hp_pred: int = int(ja.hp)
	# JEDEN HOD MUZE MINOUT (namEReno: hp 85 -> 85, "miss") - proto se hodi
	# opakuje, dokud hp neklesne. Sonda meri ZAPOJENI zvuku, ne nahodu.
	var hodu: int = 0
	for _i in 40:
		boj.resolve_swing(cil, hrac)
		hodu += 1
		if int(ja.hp) < hp_pred:
			break
	_hurt = {"ok": int(ja.hp) < hp_pred, "hp_pred": hp_pred, "hp_po": int(ja.hp),
		"hodu": hodu}
	print("[zvuk] hurt: monstrum ", cil, " -> hp ", hp_pred, " -> ", int(ja.hp),
		" po ", hodu, " hodech (ok ", _hurt.get("ok"), ")")


func _process(_delta: float) -> bool:
	_f += 1
	if _scene == null or _scene.loop == null:
		return _f > 460
	for krok in PLAN:
		if int(krok[0]) == _f:
			var event := InputEventKey.new()
			event.keycode = int(krok[1])
			event.pressed = bool(krok[2])
			Input.parse_input_event(event)
	if _f == 340:
		# HURT PRED SMRTI: `_zkus_smrt` zabije nejblizsi monstrum, po nem uz
		# nemusi byt zadne na dosah a "dostali jsme zasah" by se nemerilo.
		_zkus_hurt()
	if _f == 360:
		_zkus_smrt()
	if _f == 380:
		_zkus_tezbu()
	if _f == 420:
		_zkus_kovani()
	if _f % 120 == 0:
		var zvuk = _scene.loop.sound
		if zvuk == null:
			print("[zvuk] frame ", _f, ": modul NENI zapojeny (loop.sound == null)")
		else:
			print("[zvuk] frame ", _f, ": ", zvuk.stats(), " chyby ", zvuk.errors())
	if _f >= 460:
		var zvuk2 = _scene.loop.sound
		if zvuk2 == null:
			print("[zvuk] SOUHRN: modul neni zapojeny - NEMERENO")
			return true
		var st: Dictionary = zvuk2.stats()
		_kdo_hral = st.get("podle_id", {})
		var hralo: bool = int(st.get("prehrano", 0)) > 0 and not _kdo_hral.is_empty()
		print("[zvuk] tezba/kovani: ", _tezba.get("ok"), " / ", _kovani.get("ok"))
		print("[zvuk] smrt: ", _smrt.get("killed"))
		print("[zvuk] SOUHRN: prehrano ", st.get("prehrano"), ", podle id ", _kdo_hral,
			", ticho ", st.get("ticho"), ", chyb ", st.get("chyb"),
			" -> ", "OK" if hralo else "VADA (nic se neprehralo)")
		return true
	return false
