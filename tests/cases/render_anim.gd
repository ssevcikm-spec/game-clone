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
# FIXTURE (tests/fixtures/anim/, je V GITU, generator make_fixture.py): sekce
# "fixture" meri VZDY - i v CI, kde `assets/uo/` neni. Bez ni by case v CI
# nepridal ani jednu kontrolu a mutace na `render/anim_player.gd` by tam prosly
# (`tests/run_tests.gd` hlasi case s 0 kontrolami jako selhani). Hodnoty se CTou
# z fixture - cisla z REALNEHO exportu (30 spritu, 10 framu) v ni proto NEJSOU
# a v teto sekci se neopakuji.
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
# Fixture je V GITU, takze sekce "fixture" (nize) meri i v CI bez assets/uo/.
const FIXTURE_MANIFEST := "res://tests/fixtures/anim/anim-sheets.json"
# Klice, ktere sekce "fixture" pouziva: vsech 5 sprite smeru akce 0 (walk) +
# akce 4 (idle). Jejich existenci sekce kontroluje - kdyby ve fixture nebyly,
# merila by PRAZDNO a "0 selhani" by neznamenalo nic.
const FIXTURE_KLICE := ["400/0/0", "400/0/1", "400/0/2", "400/0/3", "400/0/4", "400/4/1"]
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
	# FIXTURE: meri se VZDY (i v CI bez assets/uo/) - viz hlavicka souboru.
	_mer_fixture(t, script)
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


func _mer_fixture(t, script) -> void:
	# Sekce FIXTURE: meri se VZDY (fixture je v gitu), takze v CI bez `assets/uo/`
	# case porad neco ZMERI - a mutace ma na co spadnout. Vsechny ocekavane
	# hodnoty se CTou z `tests/fixtures/anim/anim-sheets.json`, neopisuji se.
	if not FileAccess.file_exists(FIXTURE_MANIFEST):
		# Chybejici fixture je vada REPA (je v gitu), ne "nejsou data" jako
		# u assets/uo/ - proto se hlasi jako selhana kontrola, ne jako NEMERENO.
		t._pending("render.anim: chybi fixture " + FIXTURE_MANIFEST
			+ " - spust `python tests/fixtures/anim/make_fixture.py`")
		return
	var data = Lib.json_at(FIXTURE_MANIFEST)
	if not (data is Dictionary) or not (data.get("sprites") is Dictionary):
		t._pending("render.anim: fixture " + FIXTURE_MANIFEST + " se necte")
		return
	var sprites: Dictionary = data["sprites"]

	# 1) SMLOUVA FIXTURE: klice, ktere tahle sekce meri, musi existovat, mit framy,
	#    mit svuj PNG - a framy musi byt KONZISTENTNI (rect sedi na w/h, `cx` je
	#    uvnitr framu, `cy` je nad linkou zeme a linka lezi ve framu). Bez toho by
	#    zbytek sekce meril PRAZDNO nebo NESMYSL (a "0 selhani" by neznamenalo nic):
	#    ocekavana hodnota se totiz bere ze STEJNEHO souboru jako merena, takze
	#    rozbita hodnota ve fixture se jinak vyvrati sama sebou.
	var problemy := ""
	var soubory := {}
	for k in FIXTURE_KLICE:
		if not sprites.has(k):
			problemy += " chybi klic %s;" % k
			continue
		var z: Dictionary = sprites[k]
		var framy: Array = z.get("frames", [])
		if framy.size() == 0:
			problemy += " %s ma 0 framu;" % k
		if str(z.get("file", "")) == "":
			problemy += " %s nema 'file';" % k
		else:
			soubory[str(z["file"])] = true
		for i in framy.size():
			var f: Dictionary = framy[i]
			var fw: int = int(f.get("w", 0))
			var fh: int = int(f.get("h", 0))
			var fr: Array = f.get("rect", [])
			var fcx: int = int(f.get("cx", 0))
			var fcy: int = int(f.get("cy", 0))
			if fw <= 0 or fh <= 0:
				problemy += " %s frame %d: w/h = %d/%d;" % [k, i, fw, fh]
			if fr.size() != 4 or int(fr[2]) - int(fr[0]) != fw or int(fr[3]) - int(fr[1]) != fh:
				problemy += " %s frame %d: rect %s nesedi na %dx%d;" % [k, i, str(fr), fw, fh]
			if fcx < 0 or fcx > fw:
				problemy += " %s frame %d: cx %d neni uvnitr framu 0..%d;" % [k, i, fcx, fw]
			if fcy >= 0 or fcy + fh < 0:
				problemy += " %s frame %d: cy %d neni nad linkou zeme (cy + h = %d);" \
					% [k, i, fcy, fcy + fh]
	for f in soubory:
		if not FileAccess.file_exists(FIXTURE_MANIFEST.get_base_dir() + "/" + str(f)):
			problemy += " chybi PNG %s;" % f
	t._check(problemy == "", "render.anim (fixture): manifest ma klice %s s framy, PNG a konzistentnimi framy (%s)"
		% [str(FIXTURE_KLICE), problemy if problemy != "" else "vse OK"])
	if problemy != "":
		return

	var player = script.new(FIXTURE_MANIFEST)

	# 2) dostupnost a pocet spritu - hodnoty z fixture
	t._check(player.available(),
		"render.anim (fixture): available() nad " + FIXTURE_MANIFEST)
	t._check(player.sprite_count() == sprites.size(),
		"render.anim (fixture): sprite_count() = %d, ve fixture %d spritu"
		% [player.sprite_count(), sprites.size()])

	# 3) frame_count pro vsech 8 smeru hry: pocet framu se CTE z fixture pro
	#    sprite, na ktery smer mapuje `DIR_MAP` (tabulka SMERY). Fixture ma
	#    u kazdeho sprite JINY pocet framu, takze prohozeny sprite je videt.
	var framy_ok := true
	var framy_detail := ""
	for d in 8:
		var klic := "400/0/%d" % int(SMERY[d][0])
		var ocekavano: int = int(sprites[klic]["frames"].size())
		var vyslo: int = player.frame_count(400, 0, d)
		if vyslo != ocekavano:
			framy_ok = false
			framy_detail += " smer %d -> %s: %d vs %d" % [d, klic, vyslo, ocekavano]
	t._check(framy_ok, "render.anim (fixture): frame_count pro 8 smeru = pocty framu z fixture (%s)"
		% (framy_detail if framy_detail != "" else "bez rozdilu"))
	#    akce 4 (idle) je JINY klic i jiny PNG (a jina vyska framu nez walk)
	var idle_klic := "400/4/%d" % int(SMERY[0][0])
	t._check(player.frame_count(400, 4, 0) == int(sprites[idle_klic]["frames"].size()),
		"render.anim (fixture): frame_count(400, 4, 0) = %d, ve fixture %s %d"
		% [player.frame_count(400, 4, 0), idle_klic, int(sprites[idle_klic]["frames"].size())])
	#    chybejici klice (akce 1 = run, telo 401) vraci 0, ne vymysleny pocet
	t._check(player.frame_count(400, 1, 0) == 0 and player.frame_count(401, 0, 0) == 0,
		"render.anim (fixture): chybejici klic vraci 0 framu (akce 1: %d, telo 401: %d)"
		% [player.frame_count(400, 1, 0), player.frame_count(401, 0, 0)])

	# 4) framy v CASE: 80 ms/frame z `Const.TURN_MS` (ne opsane cislo) a cyklus
	#    pres pocet framu z FIXTURE (telo 400, akce 0, smer hry 0)
	var turn: int = int(Lib.consts_at(CONST_SCRIPT).get("TURN_MS", -1))
	var walk: Dictionary = sprites["400/0/%d" % int(SMERY[0][0])]
	var pocet: int = int(walk["frames"].size())
	t._check(turn > 0 and player.frame_ms(0) == turn,
		"render.anim (fixture): frame_ms = %d, Const.TURN_MS = %d"
		% [player.frame_ms(0), turn])
	var f0: int = int(player.play(400, 0, 0, 0)["frame"])
	var f1: int = int(player.play(400, 0, 0, turn)["frame"])
	var f2: int = int(player.play(400, 0, 0, 2 * turn)["frame"])
	t._check(f0 == 0 and f1 == 1 and f2 == 2 and pocet >= 3,
		"render.anim (fixture): cas posouva frame (0/%d/%d ms -> %d/%d/%d, ocekavano 0/1/2; framu %d)"
		% [turn, 2 * turn, f0, f1, f2, pocet])
	var fcyklus: int = int(player.play(400, 0, 0, pocet * turn)["frame"])
	t._check(pocet >= 3 and fcyklus == f0,
		"render.anim (fixture): po %d * %d ms se cyklus vraci na frame %d (vyslo %d)"
		% [pocet, turn, f0, fcyklus])
	#    frame 1 kresli RECT framu 1 z fixture (cas -> frame -> rect, ne jen cislo)
	var t1 = player.play(400, 0, 0, turn)["texture"]
	var fr1: Dictionary = walk["frames"][1]
	var r1 := Rect2(int(fr1["rect"][0]), int(fr1["rect"][1]), int(fr1["w"]), int(fr1["h"]))
	t._check(t1 != null and t1.region == r1,
		"render.anim (fixture): frame 1 kresli region %s, ve fixture %s"
		% [str(t1.region if t1 != null else null), str(r1)])

	# 5) mapovani 8 smeru hry na 5 spritu anim.mul + zrcadleni: krome tabulky
	#    SMERY se overuje, ze TEXTURA je frame 0 toho spritu, ktery je ve FIXTURE
	#    - kdyby kod cetl jiny klic, region nesedi.
	var mapa_ok := true
	var mapa_detail := ""
	var videno := {}
	for d in 8:
		var r: Dictionary = player.play(400, 0, d, 0)
		var ch: Array = SMERY[d]
		var klic := "400/0/%d" % int(ch[0])
		var fr: Dictionary = sprites[klic]["frames"][0]
		var region_cek := Rect2(int(fr["rect"][0]), int(fr["rect"][1]), int(fr["w"]), int(fr["h"]))
		var region_vyslo = null if r["texture"] == null else r["texture"].region
		videno[klic] = true
		if (int(r["sprite_dir"]) != int(ch[0]) or bool(r["mirror"]) != bool(ch[1])
				or not bool(r["ok"]) or region_vyslo != region_cek):
			mapa_ok = false
			mapa_detail += " smer %d -> %s (cek. sprite %d/%s, region %s vs %s)" % [
				d, klic, int(ch[0]), str(ch[1]), str(region_vyslo), str(region_cek)]
	t._check(mapa_ok, "render.anim (fixture): 8 smeru -> 5 spritu + zrcadleni, region z fixture (%s)"
		% (mapa_detail if mapa_detail != "" else "bez rozdilu"))
	t._check(videno.size() == 5,
		"render.anim (fixture): 8 smeru pouzije vsech 5 spritu (videno %d)" % videno.size())

	# 6) kotva = (cx, cy + h) z FIXTURE a mirror_x = w - cx; meri se ZRCADLENY
	#    smer (0 = E) i NEZRCADLENY (7 = SE), aby se nezrcadlena vetev neusla
	var kotva_ok := true
	var kotva_detail := ""
	for d in [0, 7]:
		var ch: Array = SMERY[d]
		var klic := "400/0/%d" % int(ch[0])
		var fr: Dictionary = sprites[klic]["frames"][0]
		var a: Dictionary = player.play(400, 0, d, 0)
		var kotva := Vector2(int(fr["cx"]), int(fr["cy"]) + int(fr["h"]))
		if (a["anchor"] != kotva or int(a["mirror_x"]) != int(fr["w"]) - int(fr["cx"])
				or bool(a["mirror"]) != bool(ch[1])):
			kotva_ok = false
			kotva_detail += " smer %d (%s): anchor %s vs %s, mirror_x %d vs %d" % [
				d, klic, str(a["anchor"]), str(kotva), int(a["mirror_x"]),
				int(fr["w"]) - int(fr["cx"])]
	t._check(kotva_ok, "render.anim (fixture): anchor = (cx, cy + h) a mirror_x = w - cx z fixture (%s)"
		% (kotva_detail if kotva_detail != "" else "bez rozdilu"))
	#    velikost textury se cte z JSONu, ne z konstanty - a idle ma JINOU
	#    vysku framu nez walk (kdyby kod bral rozmery odjinud, pozna se to)
	var a0: Dictionary = player.play(400, 0, 0, 0)
	var fr0: Dictionary = sprites["400/0/%d" % int(SMERY[0][0])]["frames"][0]
	var velikost := Vector2i.ZERO
	if a0["texture"] is AtlasTexture:
		velikost = Vector2i(a0["texture"].get_width(), a0["texture"].get_height())
	t._check(velikost == Vector2i(int(fr0["w"]), int(fr0["h"])),
		"render.anim (fixture): textura framu 0 ma %s, ve fixture %s"
		% [str(velikost), str(Vector2i(int(fr0["w"]), int(fr0["h"])))])
	var i0: Dictionary = player.play(400, 4, 0, 0)
	var ifr: Dictionary = sprites[idle_klic]["frames"][0]
	var ivelikost := Vector2i.ZERO
	if i0["texture"] is AtlasTexture:
		ivelikost = Vector2i(i0["texture"].get_width(), i0["texture"].get_height())
	t._check(bool(i0["ok"]) and ivelikost == Vector2i(int(ifr["w"]), int(ifr["h"]))
		and i0["anchor"] == Vector2(int(ifr["cx"]), int(ifr["cy"]) + int(ifr["h"])),
		"render.anim (fixture): idle ma region %s a anchor %s, ve fixture %s / %s"
		% [str(ivelikost), str(i0["anchor"]), str(Vector2i(int(ifr["w"]), int(ifr["h"]))),
			str(Vector2(int(ifr["cx"]), int(ifr["cy"]) + int(ifr["h"])))])

	# 7) neexistujici sprite = ok:false + texture:null (zadne tiche prazdno):
	#    telo 401 (ve fixture neni) i chybejici AKCE 1 u tela, ktere ve fixture JE
	var nic: Dictionary = player.play(401, 0, 0, 0)
	t._check(not bool(nic["ok"]) and nic["texture"] == null and int(nic["count"]) == 0,
		"render.anim (fixture): telo 401 ve fixture neni -> ok=%s, texture=%s, count=%d"
		% [str(nic["ok"]), str(nic["texture"]), int(nic["count"])])
	var nic2: Dictionary = player.play(400, 1, 0, 0)
	t._check(not bool(nic2["ok"]) and nic2["texture"] == null and int(nic2["count"]) == 0,
		"render.anim (fixture): akce 1 (run) ve fixture neni -> ok=%s, texture=%s, count=%d"
		% [str(nic2["ok"]), str(nic2["texture"]), int(nic2["count"])])
	#    chybejici manifest vraci available() = false (i v CI, kde assets/uo neni)
	var prazdny = script.new(FIXTURE_MANIFEST.get_base_dir() + "/neexistuje.json")
	t._check(not prazdny.available() and prazdny.sprite_count() == 0,
		"render.anim (fixture): chybejici manifest -> available() = %s, spritu %d"
		% [str(prazdny.available()), prazdny.sprite_count()])

	# 8) registr bytosti (granule `sim.entity_registry`): `play(serial)` si CISLO
	#    TELA vyzvedne z registru. Telo 400 je ve FIXTURE, takze se meri i v CI.
	var reg = RegistryScript.new()
	var mob = MobileScript.new(0x40000001, 400, Vector3i.ZERO)
	reg.register(mob)
	var s_reg = script.new(FIXTURE_MANIFEST, reg)
	var reg_klic := "400/0/%d" % int(SMERY[0][0])
	var reg_fr: Dictionary = sprites[reg_klic]["frames"][0]
	var pres_registr: Dictionary = s_reg.play(mob.serial, 0, 0, 0)
	var t_r = pres_registr["texture"]
	t._check(bool(pres_registr["ok"]) and t_r != null
		and int(pres_registr["count"]) == int(sprites[reg_klic]["frames"].size())
		and t_r.region == Rect2(int(reg_fr["rect"][0]), int(reg_fr["rect"][1]),
			int(reg_fr["w"]), int(reg_fr["h"])),
		"render.anim (fixture): registr -> play(serial) kresli telo 400 z fixture (ok=%s, framu %d)"
		% [str(pres_registr["ok"]), int(pres_registr["count"])])
	t._check(s_reg.body_of(mob.serial) == 400 and s_reg.body_of(0x40009999) == -1,
		"render.anim (fixture): body_of = %d pro mobil v registru a %d pro neznameho (ocekavano 400 a -1)"
		% [s_reg.body_of(mob.serial), s_reg.body_of(0x40009999)])
	var nez: Dictionary = s_reg.play(0x40009999, 0, 0, 0)
	t._check(not bool(nez["ok"]) and nez["texture"] == null and int(nez["count"]) == 0,
		"render.anim (fixture): serial, ktery v registru NENI, vraci ok=%s + texture=%s (ne telo = serial)"
		% [str(nez["ok"]), str(nez["texture"])])
	var bez_reg = script.new(FIXTURE_MANIFEST)
	t._check(bez_reg.body_of(400) == 400 and bool(bez_reg.play(400, 0, 0, 0)["ok"]),
		"render.anim (fixture): bez registru je serial cislo tela (body_of(400) = %d, play ok = %s)"
		% [bez_reg.body_of(400), str(bez_reg.play(400, 0, 0, 0)["ok"])])
