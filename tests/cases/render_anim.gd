extends RefCounted
# render.anim - chovani, ne "soubor existuje" (docs/09 §9.4): animaci ZAVOLA a ZMERI
# framy, casovani, kotvu i mapovani smeru. Cesta k souboru granule je VSTUP
# (`-- --anim-script=<cesta>`), stejne jako u render_sort - aby mutacni harness
# (tools/gates/mutace-render-anim.py) mohl predat mutanta a aby se dokazalo, ze test
# meri opravdu ten soubor, ktery dostane.
#
# Ocekavane hodnoty se CTou Z `anim-sheets.json` (nezavisly zdroj), neopisuji se:
# kotva je `(cx, cy + h)` z prvniho framu a pocet framu z `frames.size()`.
#
# Kdyz `assets/uo/anim` v klonu neni (assets/uo/ je v .gitignore), je to NEMERENO
# s duvodem - nikdy tiche projiti.
#
# POZOR: ze chybejici manifest HLA SI (`push_warning`) se z GDScriptu odchytit neda,
# proto se k tomu overuje jeste to, ze `push_warning` v merenem souboru opravdu je.

const Lib = preload("res://tests/lib.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const ANIM_SCRIPT := "res://render/anim_player.gd"
const MANIFEST := "res://assets/uo/anim/anim-sheets.json"
const CONST_SCRIPT := "res://core/const.gd"
# smer hry 0..7 (core/const.gd: 0 = E ... 7 = SE) -> [smer v anim.mul 0..4, zrcadlit];
# tabulka je zmerena v granuli (hlavicka `render/anim_player.gd`)
const SMERY := [[1, true], [2, true], [3, true], [4, false],
	[3, false], [2, false], [1, false], [0, false]]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta := _arg("anim-script", ANIM_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("render.anim NENI HOTOVA: " + cesta + " chybi")
		return
	if not FileAccess.file_exists(MANIFEST):
		# Chybějící DATA (assets/uo/ je v .gitignore) nejsou vada kódu: v CI
		# assety nejsou, a kdyby to byla selhaná kontrola, byla by celá CI
		# červená kvůli datům, která tam být nemají. Vzor: world_map.gd,
		# tests/cases/walk.gd. NEMĚŘENO se musí vidět v logu.
		print("[test]      NEMERENO: render.anim - chybi assets/uo/anim (anim-sheets.json); "
			+ "spust `python tools/uoextract/anim.py --export assets/uo/anim`")
		return
	var data = Lib.json_at(MANIFEST)
	if not (data is Dictionary):
		print("[test]      NEMERENO: render.anim - anim-sheets.json se necte (poskozeny export)")
		return
	var sprites: Dictionary = data["sprites"]
	var player = script.new()

	# 1) export je k dispozici a player ho vidi
	t._check(player.available(), "render.anim: available() nad exportem")
	t._check(player.sprite_count() == sprites.size() and sprites.size() == 30,
		"render.anim: sprite_count() = %d, v JSON je %d spritu (ocekavano 30)"
		% [player.sprite_count(), sprites.size()])

	# 2) framy z manifestu: walk muze (telo 400, akce 0) ma 10 framu; smer hry 0 (E)
	#    pouzije sprite 1, takze se pocet cte z JSONu, ne opsanim cislem
	var walk: Dictionary = sprites["400/0/1"]
	t._check(player.frame_count(400, 0, 0) == 10
		and player.frame_count(400, 0, 0) == walk["frames"].size(),
		"render.anim: frame_count(400, 0, 0) = %d, v JSON %d (ocekavano 10)"
		% [player.frame_count(400, 0, 0), walk["frames"].size()])
	t._check(player.frame_count(400, 4, 0) == 1 and player.frame_count(999, 0, 0) == 0,
		"render.anim: idle ma %d frame, neexistujici telo %d (ocekavano 1 a 0)"
		% [player.frame_count(400, 4, 0), player.frame_count(999, 0, 0)])

	# 3) casovani 80 ms - z Konstanty, ne opsane cislo
	var turn: int = int(Lib.consts_at(CONST_SCRIPT).get("TURN_MS", -1))
	t._check(player.frame_ms(0) == 80 and player.frame_ms(4) == 80 and player.frame_ms(0) == turn,
		"render.anim: frame_ms = %d (ocekavano 80 = Const.TURN_MS %d)"
		% [player.frame_ms(0), turn])

	# 4) play posune frame podle casu (deterministicky pres now_ms) a cyklus se vraci na 0
	var f0: int = int(player.play(400, 0, 0, 0)["frame"])
	var f1: int = int(player.play(400, 0, 0, 80)["frame"])
	var f2: int = int(player.play(400, 0, 0, 160)["frame"])
	var fcyklus: int = int(player.play(400, 0, 0, 10 * 80)["frame"])
	t._check(f0 == 0 and f1 == 1 and f2 == 2,
		"render.anim: cas posouva frame (0/80/160 ms -> %d/%d/%d, ocekavano 0/1/2)"
		% [f0, f1, f2])
	t._check(fcyklus == f0,
		"render.anim: po count * 80 ms se cyklus vraci na frame %d (vyslo %d)" % [f0, fcyklus])

	# 5) neexistujici sprite = ok:false (zadne tiche prazdno, docs/08 §8.6)
	var nic: Dictionary = player.play(999, 0, 0, 0)
	t._check(not bool(nic["ok"]) and int(nic["count"]) == 0 and nic["texture"] == null,
		"render.anim: neexistujici telo vraci ok=%s, count=%d, texture=%s"
		% [str(nic["ok"]), int(nic["count"]), str(nic["texture"])])

	# 6) kotva = (cx, cy + h) z JSONu; zrcadleny sprite ma navic mirror_x = w - cx
	var a: Dictionary = player.play(400, 0, 0, 0)
	var fr: Dictionary = walk["frames"][0]
	var kotva := Vector2(int(fr["cx"]), int(fr["cy"]) + int(fr["h"]))
	t._check(a["anchor"] == kotva and int(a["mirror_x"]) == int(fr["w"]) - int(fr["cx"]),
		"render.anim: anchor = %s, v JSON (cx, cy + h) = %s; mirror_x = %d (ocekavano %d)"
		% [str(a["anchor"]), str(kotva), int(a["mirror_x"]), int(fr["w"]) - int(fr["cx"])])
	# velikost se cte z textury, ale jen kdyz existuje - hlaska se stavi VZDY
	var velikost := Vector2i.ZERO
	if a["texture"] is AtlasTexture:
		velikost = Vector2i(a["texture"].get_width(), a["texture"].get_height())
	t._check(velikost == Vector2i(int(fr["w"]), int(fr["h"])),
		"render.anim: textura framu 0 ma region %s, v JSON %s"
		% [str(velikost), str(Vector2i(int(fr["w"]), int(fr["h"])))])

	# 7) mapovani 8 smeru hry na 5 spritu anim.mul + zrcadleni (merena tabulka)
	var mapa_ok := true
	var mapa := ""
	for d in 8:
		var r: Dictionary = player.play(400, 0, d, 0)
		var ch: Array = SMERY[d]
		if int(r["sprite_dir"]) != int(ch[0]) or bool(r["mirror"]) != bool(ch[1]):
			mapa_ok = false
			mapa += " %d->%d/%s (cek. %d/%s)" % [d, int(r["sprite_dir"]), str(r["mirror"]),
				int(ch[0]), str(ch[1])]
	t._check(mapa_ok, "render.anim: 8 smeru -> 5 spritu + zrcadleni sedi na merenou tabulku (rozdily:%s)" % mapa)

	# 8) zrcadlove dvojice sdileji SPRITE (stejny region) a maji opacne zrcadleni:
	#    (E,S) = 0 a 6, (NE,SW) = 1 a 5, (N,W) = 2 a 4; SE (7) a NW (3) jsou na ose
	var pary_ok := true
	var detail := ""
	for par in [[0, 6], [1, 5], [2, 4]]:
		var x: Dictionary = player.play(400, 0, int(par[0]), 0)
		var y: Dictionary = player.play(400, 0, int(par[1]), 0)
		var stejny: bool = (x["texture"] != null and y["texture"] != null
			and x["texture"].region == y["texture"].region)
		if not (stejny and bool(x["mirror"]) != bool(y["mirror"])
				and int(x["sprite_dir"]) == int(y["sprite_dir"])):
			pary_ok = false
			detail += " %s" % str(par)
	t._check(pary_ok, "render.anim: zrcadlove dvojice maji stejny sprite a opacne zrcadleni (vadne:%s)" % detail)
	var t0 = player.play(400, 0, 0, 0)["texture"]
	var t4 = player.play(400, 0, 4, 0)["texture"]
	var t7 = player.play(400, 0, 7, 0)["texture"]
	t._check(t0 != null and t4 != null and t7 != null and t0.region != t4.region
		and t4.region != t7.region and t0.region != t7.region,
		"render.anim: E, W a SE kresli tri RUZNE sprites (%s, %s, %s)"
		% [str(t0.region if t0 != null else null), str(t4.region if t4 != null else null),
			str(t7.region if t7 != null else null)])

	# 9) frame i sedi na cas i * 80 ms (ne jen "neco se zmenilo")
	var sedi := true
	for i in 10:
		if int(player.play(400, 0, 0, i * 80)["frame"]) != i:
			sedi = false
	t._check(sedi, "render.anim: frame i sedi na cas i * 80 ms (10 framu cyklu)")

	# 10) zmena akce zacina framem 0 (jinak by se animace "chytila" uprostred)
	player.play(400, 0, 0, 320)
	var po_zmene: int = int(player.play(400, 4, 0, 320)["frame"])
	t._check(po_zmene == 0, "render.anim: zmena akce zacina framem 0 (vyslo %d)" % po_zmene)

	# 11) bez now_ms se bere cas z Time.get_ticks_msec() a frame zustava v rozsahu
	var zivy: Dictionary = player.play(400, 0, 0)
	t._check(bool(zivy["ok"]) and int(zivy["frame"]) >= 0 and int(zivy["frame"]) < int(zivy["count"]),
		"render.anim: play bez now_ms funguje (frame %d z %d)"
		% [int(zivy["frame"]), int(zivy["count"])])

	# 12) chybejici manifest: available() je false a data se HLA SI
	var prazdny = script.new("res://assets/uo/anim/neexistuje.json")
	t._check(not prazdny.available() and prazdny.sprite_count() == 0,
		"render.anim: chybejici manifest -> available() = false (vyslo %s)"
		% str(prazdny.available()))
	t._check(FileAccess.get_file_as_string(cesta).contains("push_warning"),
		"render.anim: chybejici data se HLASI (push_warning v merenem souboru)")

	# 13) registr bytosti (granule `sim.entity_registry`): `play(serial, ...)` si
	#     CISLO TELA vyzvedne z registru. Srovnava se s `play(401, ...)` (starsi
	#     cesta), takze se cislo tela neopisuje - je to TATAZ textura.
	var reg = RegistryScript.new()
	var mob = MobileScript.new(0x40000001, 401, Vector3i.ZERO)
	reg.register(mob)
	var s_reg = script.new(MANIFEST, reg)
	var pres_registr: Dictionary = s_reg.play(mob.serial, 0, 0, 0)
	var pres_telo: Dictionary = player.play(401, 0, 0, 0)
	var t_r = pres_registr["texture"]
	var t_t = pres_telo["texture"]
	t._check(bool(pres_registr["ok"]) and t_r != null and t_t != null
		and int(pres_registr["count"]) == int(pres_telo["count"])
		and t_r.region == t_t.region,
		"render.anim: registr -> play(serial) kresli telo z registru (framu %d, pres telo %d)"
		% [int(pres_registr["count"]), int(pres_telo["count"])])
	t._check(s_reg.body_of(mob.serial) == 401 and s_reg.body_of(0x40009999) == -1,
		"render.anim: body_of = %d pro mobil v registru a %d pro neznameho (ocekavano 401 a -1)"
		% [s_reg.body_of(mob.serial), s_reg.body_of(0x40009999)])
	var nez: Dictionary = s_reg.play(0x40009999, 0, 0, 0)
	t._check(not bool(nez["ok"]) and nez["texture"] == null and int(nez["count"]) == 0,
		"render.anim: serial, ktery v registru NENI, vraci ok:false + null (ne telo = serial)")
	var bez_reg = script.new(MANIFEST)
	t._check(bez_reg.body_of(400) == 400,
		"render.anim: bez registru je serial cislo tela (starsi chovani, vyslo %d)"
		% bez_reg.body_of(400))
