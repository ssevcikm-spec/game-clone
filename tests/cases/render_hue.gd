extends RefCounted
# render.hue - chovani, ne "soubor existuje" (docs/09 §9.4): tonovani se ZAVOLA
# a ZMERI se pixely. Cesta k souboru granule je VSTUP (`-- --hue-script=<cesta>`),
# stejne jako u render_sort a render_anim - aby mutacni harness
# (tools/gates/mutace-render-hue.py) mohl predat mutanta a aby se dokazalo, ze
# test meri opravdu ten soubor, ktery dostane.
#
# Test ma CTYRI casti a je to zamer:
#   A) BEZ DAT - synteticky obrazek (`Image.create`) + tabulka 5 -> 8 bitu proti
#      REFERENCNIMU KLIENTOVI. Bezi VZDY, i v CI, kde `assets/uo/` neni (je
#      v .gitignore) a `_src/` take ne.
#   B) CHYBEJICI DATA se musi HLASIT - `hued()` s neznamym hue vrati PRESNE
#      puvodni texturu a zvysi `missing` (zadne tiche prazdno, docs/08 §8.6).
#      Bezi VZDY.
#   C) PROTI SKUTECNYM DATUM (`assets/uo/hues.json`) - kontrola proti sade,
#      ktera se opravdu pouziva. Chybejici data = NEMERENO s duvodem (nikdy
#      tiche projiti a NIKDY selhani: v CI assety nejsou a byt nemaji).
#   D) FIXTURE (`tests/fixtures/hues/hues.json`, v GITU) - sada 1002 (= HUE_SKIN)
#      a 1003 prenesene z realneho exportu. Bezi VZDY - i v CI a i tehdy, kdyz
#      `assets/uo/hues.json` na disku JE. Duvod: v CI se C) preskoci, takze by
#      mutace, ktere chytala jen ona, v CI "prosly" (harness by hlasil slepe
#      kontroly). Je ZAMERNE PRED C) - C) konci `return`.
#
# POZOR (namEReno 2026-10-06, beh CI #16): prvni verze tohohle testu mela
# kontroly proti datum NEpodminene - v CI (bez `assets/uo`) tim shodila cely
# krok s 10 selhanimi. Data, ktera v CI nejsou, se NESMIJI vynucovat.

const Lib = preload("res://tests/lib.gd")
const HUE_SCRIPT := "res://render/hue_cache.gd"
const HUES := "res://assets/uo/hues.json"
const COLORS: int = 32          # urovni barvy v sade (docs/03 §3.2b)
# REFERENCNI KLIENT (BSD-2, jen ke cteni) - v nem je ta sama tabulka 5 -> 8 bitu.
# Jeji hodnoty NEJSOU vzorec (namEReno: `round(v * 255 / 31)` da u v=3 25,
# reference ma 24). Kontrola proti DRUHE IMPLEMENTACI je jedina, ktera odlisi
# spravnou tabulku od posunu `v << 3`. `_src/` je v .gitignore, takze v CI
# soubor NENI - pak je to NEMERENO (ne selhani).
const REFERENCE := "res://_src/classicuo/src/ClassicUO.Utility/HuesHelper.cs"

# --- fixture (sekce D): v gitu, takze bezi i v CI -------------------------
const FIXTURE := "res://tests/fixtures/hues/hues.json"
const FIXTURE_SETS: int = 1003   # 1001 vyplnovych + sada 1002 + sada 1003
const FIXTURE_SKIN: int = 1002   # index 1001 = "SkinHue #1001" (HUE_SKIN)
const FIXTURE_SECOND: int = 1003 # index 1002 = "SkinHue #1002" (jine hodnoty)
# NEZAVISLY vzor expanze 5 -> 8 bitu - hodnoty z referencniho klienta
# (ClassicUO `HuesHelper._table`, BSD-2). Je tu ZAMERNE jako LITERAL, ne opsany
# z mereneho `EXPAND_5_TO_8`: v CI `_src/` neni, a kdyby se vzor bral z mereneho
# souboru, byla by kontrola KRUHOVA (mutace tabulky by ji prosla).
const EXPAND_REF := [0, 8, 16, 24, 32, 41, 49, 57, 65, 74, 82, 90, 98, 106,
	115, 123, 131, 139, 148, 156, 164, 172, 180, 189, 197, 205, 213, 222, 230,
	238, 246, 255]

# ZNAME barvy obou sad z fixture - opsane z realneho exportu
# (`assets/uo/hues.json`, 2026-10-07) a ve fixture jsou 1:1. Jsou tu ZAPSANE
# schvalne: kdyby se ocekavana barva pocitala z mereneho JSONu, byla by kontrola
# KRUHOVA (poskozena fixture by zmenila i ocekavani) a sabotaz fixture by prosla.
const SKIN_COLORS := [1, 1, 1058, 2114, 3139, 4196, 5252, 6309, 7334, 8390,
	9447, 9447, 10504, 11561, 12617, 13642, 14699, 15755, 16780, 17836, 18893,
	19950, 19950, 21007, 22064, 23088, 24145, 25201, 26258, 27283, 28339, 29396]
const SECOND_COLORS := [1, 1, 1058, 2082, 3139, 4195, 5220, 5252, 6309, 7334,
	8390, 9447, 10471, 10504, 11560, 12585, 13642, 14698, 15723, 16779, 16812,
	17836, 18893, 19949, 20974, 22031, 22063, 23088, 24144, 25201, 26225, 27282]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _texture(bunky: Array) -> ImageTexture:
	# bunky = [[x, y, r8, a8], ...]; rozmer 8x1 staci a je videt v hlasce.
	# `fill` je tu proto, ze `Image.create` nechava obsah neinicializovany -
	# kontrola by pak merila pamet, ne fixture.
	var obrazek := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	obrazek.fill(Color(0, 0, 0, 0))
	for b in bunky:
		obrazek.set_pixel(int(b[0]), int(b[1]), Color8(int(b[2]), int(b[2]), int(b[2]), int(b[3])))
	return ImageTexture.create_from_image(obrazek)


func _texture_rgb(r8: int, g8: int) -> ImageTexture:
	# Pixel, kde se R a G LISI - jen na takovem se da overit, KTERY kanal urcuje
	# uroven barvy (u sediveho pixelu jsou R a G stejne a mutace projde).
	var obrazek := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	obrazek.set_pixel(0, 0, Color8(r8, g8, 0, 255))
	return ImageTexture.create_from_image(obrazek)


func _pixel(tex: Texture2D, x: int, y: int = 0) -> Color:
	var obrazek: Image = tex.get_image()
	return obrazek.get_pixel(x, y)


func _ref_tabulka() -> Array:
	# Vytahne z referencniho klienta rady `0x00, 0x08, ...` a vrati je jako cisla.
	# Hleda se REGEXEM (naivni `split(",")` jeden dil ztratil - namEReno: 31
	# hodnot misto 32, a vypadalo to na vadu reference).
	var soubor := FileAccess.open(REFERENCE, FileAccess.READ)
	if soubor == null:
		return []
	var vse: String = soubor.get_as_text()
	var vnitrek := vse.split("new byte[32]", true)
	if vnitrek.size() < 2:
		return []
	var telo: String = vnitrek[1].split("}", true)[0]
	var re := RegEx.new()
	re.compile("0x([0-9A-Fa-f]{2})")
	var hodnoty: Array = []
	for n in re.search_all(telo):
		hodnoty.append(n.get_string(1).hex_to_int())
	return hodnoty


func _oracle(barva5: int) -> Color:
	# 5bitova barva UO -> ocekavana 8bitova RGB, pocitana NEZAVISLYM vzorem
	# (`EXPAND_REF`), ne merenym `EXPAND_5_TO_8`. Kanály: R = (c >> 10) & 0x1F,
	# G = (c >> 5) & 0x1F, B = c & 0x1F (stejne jako `_barvy` v hue_cache.gd,
	# ale hodnoty expanze jsou odtud nezavisle).
	return Color8(int(EXPAND_REF[(barva5 >> 10) & 0x1F]),
		int(EXPAND_REF[(barva5 >> 5) & 0x1F]), int(EXPAND_REF[barva5 & 0x1F]))


func run(t) -> void:
	var cesta := _arg("hue-script", HUE_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("render.hue NENI HOTOVA: " + cesta + " chybi")
		return

	# Hodnoty jsou v 5bitovem prostoru ZAPSANE v 8 bitech tak, jak je dava
	# expanze 5 -> 8 (tabulka referencniho klienta): 0, 8, 16, 24, 32, ... 255.
	# Presne tyhle hodnoty ma sediva rampa exportu animaci (namEReno 2026-10-06).
	var seda := [0, 8, 16, 24, 32, 41, 49, 255]
	var bunky: Array = []
	for i in seda.size():
		bunky.append([i, 0, int(seda[i]), 255])
	var base := _texture(bunky)

	var barvy = script.new(HUES, 8)     # strop 8 polozek = da se ZMERIT, ze vyhazuje

	# ---------- A) bez dat: tabulka a chovani, ktere data nepotrebuji ----------
	# 1) hue 0 = "nepouzij hue": vrací se PRESNE puvodni textura (ne kopie)
	t._check(barvy.hued(base, 0) == base,
		"render.hue: hued(tex, 0) vraci puvodni texturu (identity, ne kopie)")

	# 2) TABULKA 5 -> 8 bitu proti referencnimu klientovi. Tohle je jedina
	#    kontrola, ktera odlisi spravnou tabulku od posunu `v << 3` - inverzni
	#    kontrola (`_uroven(EXPAND[v]) == v`) je konzistentni i pro spatnou
	#    tabulku (namEReno: mutace posunem ji prosla).
	var tabulka: Array = script.get_script_constant_map()["EXPAND_5_TO_8"]
	var ref: Array = _ref_tabulka()
	if ref.size() != 32:
		print("[test]      NEMERENO: render.hue - tabulka 5 -> 8 bitu proti referenci "
			+ "(chybi ", REFERENCE, ", v CI _src/ neni); zbyva inverzni kontrola")
	else:
		var rozdily := ""
		for v in ref.size():
			if int(tabulka[v]) != int(ref[v]):
				rozdily += " v%d: %d (reference %d)" % [v, int(tabulka[v]), int(ref[v])]
		t._check(rozdily == "", "render.hue: EXPAND_5_TO_8 sedi na referencniho klienta (rozdily:%s)"
			% rozdily)

	# 3) zpetny prevod na CELYCH 32 urovnich (konzistence tabulky a `_uroven`)
	var zpet := ""
	var zpet_ok := tabulka.size() == 32
	for v in tabulka.size():
		if barvy._uroven(int(tabulka[v])) != v:
			zpet_ok = false
			zpet += " v%d(%d)->%d" % [v, int(tabulka[v]), barvy._uroven(int(tabulka[v]))]
	t._check(zpet_ok, "render.hue: prevod 8 -> 5 bitu je presny (EXPAND ma %d hodnot; chyby:%s)"
		% [tabulka.size(), zpet])

	# ---------- B) chybejici data se HLA SI (bezi vzdy) ----------
	# 4) nezname id hue se NESMI tvarit jako uspech: vrati puvodni texturu
	#    a zvysi `missing`. Tohle plati i v CI, kde nejsou ZADNA data.
	var pred_missing: int = int(barvy.stats()["missing"])
	var divny: Texture2D = barvy.hued(base, 99999)
	t._check(divny == base and int(barvy.stats()["missing"]) == pred_missing + 1,
		"render.hue: nezname id hue vraci puvodni texturu a hlasi missing (%d -> %d)"
		% [pred_missing, int(barvy.stats()["missing"])])

	# 5) chybejici data se HLA SI (nezamlcuje). POZOR (namEReno): kontrola na
	#    pouhe `contains("push_warning")` je SLEPA - soubor ma DVĚ hlaseni
	#    (chybejici sady i nezname id hue), takze druhe ji drzi zelenou, i kdyz
	#    prvni mutace smazala. Kontroluji se proto OBE konkretni hlaseni.
	var zdroj := ""
	var f := FileAccess.open(cesta, FileAccess.READ)
	if f != null:
		zdroj = f.get_as_text()
	var hlasi_sady: int = zdroj.count("nedal zadnou sadu")
	var hlasi_id: int = zdroj.count("sadu %d hues.json nema")
	t._check(hlasi_sady >= 1 and hlasi_id >= 1,
		"render.hue: chybejici data i nezname id se HLA SI (hlasi sad=%d, hlasi id=%d; ocekavano 1 a 1)"
		% [hlasi_sady, hlasi_id])

	# ---------- D) FIXTURE (`res://tests/fixtures/hues/hues.json`) ----------
	# Bezi VZDY - i v CI a i tehdy, kdyz `assets/uo/hues.json` existuje. Duvod
	# je v hlavicce: v CI se C) preskoci, takze by vady, ktere chytala jen ona,
	# v CI "prosly" (harness by hlasil slepe kontroly).
	# Ocekavana barva se bere z ZAPSANYCH hodnot (`SKIN_COLORS`/`SECOND_COLORS`)
	# a z NEZAVISLEHO vzoru (`EXPAND_REF`), NE z mereneho JSONu ani z mereneho
	# `EXPAND_5_TO_8` - jinak by kontrola byla KRUHOVA a poskozena fixture (nebo
	# vracena vada v tabulce) by ji prosla.
	var fx_data = Lib.json_at(FIXTURE)
	if not (fx_data is Dictionary) or not (fx_data.get("sets") is Array):
		# Fixture je v GITU, takze jeji absence NENI "nemereno s duvodem" - je to
		# vada. Kdyby se jen preskocila, vypnula by se presne tam, kde ma merit.
		t._pending("render.hue: fixture " + FIXTURE + " chybi nebo se necte - "
			+ "spust `python tests/fixtures/hues/make_fixture.py`")
		return
	var fx_sady: Array = fx_data["sets"]
	var fx_popis: String = str(fx_data.get("fixture", ""))
	t._check(fx_popis.begins_with("tests/fixtures/hues/make_fixture.py")
		and fx_sady.size() == FIXTURE_SETS,
		"render.hue: fixture je z generatoru a ma %d sad (ma %d; popis: %s)"
		% [FIXTURE_SETS, fx_sady.size(), fx_popis])
	if fx_sady.size() < FIXTURE_SECOND:
		t._pending("render.hue: fixture ma jen %d sad - sada %d v ni neni (ocekavano %d)"
			% [fx_sady.size(), FIXTURE_SKIN, FIXTURE_SETS])
		return

	var fx = script.new(FIXTURE, 8)
	t._check(fx.available() and fx.set_count() == fx_sady.size(),
		"render.hue: fixture se nacte CELA (%d sad z %d v JSONu)"
		% [fx.set_count(), fx_sady.size()])

	# Sada na indexu `hue - 1` (index je PRIMO hue - 1) a jeji jmeno z JSONu:
	# kdyby fixture nebyla "SkinHue", test by meril jinou sadu, nez hra pouziva.
	var fx_skin: int = int(script.get_script_constant_map().get("HUE_SKIN", -1))
	var fx_jmeno: String = str(fx_sady[FIXTURE_SKIN - 1].get("name", ""))
	t._check(fx_skin == FIXTURE_SKIN and fx_jmeno.begins_with("SkinHue"),
		"render.hue: HUE_SKIN = %d a fixture ma na tom indexu sadu '%s'"
		% [fx_skin, fx_jmeno])

	# D1) FIXTURE SEDI NA ZNAME BARVY: kdyby se fixture poskodila (nebo vymenila za
	#    jinou), test to MUSI rict - a pozna se to i na barvach nize, ktere se
	#    pocitaji z techto ZAPSANYCH hodnot, ne z fixture.
	var fx_rozchody := ""
	for i in COLORS:
		var fx_f: int = int(fx_sady[FIXTURE_SKIN - 1]["colors"][i])
		var fx_s: int = int(fx_sady[FIXTURE_SECOND - 1]["colors"][i])
		if fx_f != int(SKIN_COLORS[i]):
			fx_rozchody += " 1002/u%d: %d (test %d)" % [i, fx_f, int(SKIN_COLORS[i])]
		if fx_s != int(SECOND_COLORS[i]):
			fx_rozchody += " 1003/u%d: %d (test %d)" % [i, fx_s, int(SECOND_COLORS[i])]
	t._check(fx_rozchody == "",
		"render.hue: fixture sedi na ZNAME barvy sad %d a %d (rozchody:%s)"
		% [FIXTURE_SKIN, FIXTURE_SECOND, fx_rozchody])

	# D2) VSECH 32 urovni OBOU sad proti ZNAME barve a nezavislemu vzoru 5 -> 8
	#    bitu (odlisi prohozene kanaly i posun `v << 3`).
	var fx_vadne := ""
	for i in COLORS:
		var fx_je: Color = fx.hue_color(FIXTURE_SKIN, i)
		if not fx_je.is_equal_approx(_oracle(int(SKIN_COLORS[i]))):
			if fx_vadne.length() < 160:
				fx_vadne += " 1002/u%d: %s (cek. %s)" % [i, str(fx_je),
					str(_oracle(int(SKIN_COLORS[i])))]
		var fx_je2: Color = fx.hue_color(FIXTURE_SECOND, i)
		if not fx_je2.is_equal_approx(_oracle(int(SECOND_COLORS[i]))):
			if fx_vadne.length() < 160:
				fx_vadne += " 1003/u%d: %s (cek. %s)" % [i, str(fx_je2),
					str(_oracle(int(SECOND_COLORS[i])))]
	t._check(fx_vadne == "",
		"render.hue: hue_color() sedi na ZNAME barvy obou sad (2 x %d urovni; vadne:%s)"
		% [COLORS, fx_vadne])

	# D3) zpetny prevod na CELYCH 32 hodnotach NEZAVISLEHO vzoru. Chyti
	#    zaokrouhleni `(k8 + 4) / 8`, ktere u urovne 18 vyjde 19 (namEReno).
	var fx_zpet := ""
	for i in EXPAND_REF.size():
		if fx._uroven(int(EXPAND_REF[i])) != i:
			fx_zpet += " %d(%d)->%d" % [i, int(EXPAND_REF[i]), fx._uroven(int(EXPAND_REF[i]))]
	t._check(fx_zpet == "",
		"render.hue: _uroven() je presny na vsech %d hodnotach NEZAVISLEHO vzoru (chyby:%s)"
		% [EXPAND_REF.size(), fx_zpet])

	# D4) TONOVANI CELE RAMPA: 32 sedych hodnot -> ZNAME barvy sady 1002. Tohle je
	#    kontrola, ktera odlisi spravnou sadu (`hue - 1`) i spravny index barvy.
	var fx_rampa := Image.create(COLORS, 1, false, Image.FORMAT_RGBA8)
	fx_rampa.fill(Color(0, 0, 0, 0))
	for v in COLORS:
		fx_rampa.set_pixel(v, 0, Color8(int(EXPAND_REF[v]), int(EXPAND_REF[v]),
			int(EXPAND_REF[v]), 255))
	var fx_rampa_tex := ImageTexture.create_from_image(fx_rampa)
	var fx_ton: Texture2D = fx.hued(fx_rampa_tex, FIXTURE_SKIN)
	if fx_ton == null:
		t._pending("render.hue: fixture - hued() vratil null, dal se neda merit")
		return
	var fx_rampa_vadne := ""
	var fx_detail := ""
	for v in COLORS:
		var fx_cv: int = int(SKIN_COLORS[v])
		var fx_cekana: Color = _oracle(fx_cv)
		var fx_jev: Color = _pixel(fx_ton, v)
		fx_detail += " %d->%d" % [int(EXPAND_REF[v]), roundi(fx_jev.r * 255.0)]
		if not fx_jev.is_equal_approx(fx_cekana):
			fx_rampa_vadne += " #%d(%d): %s (cek. %s)" % [v, int(EXPAND_REF[v]),
				str(fx_jev), str(fx_cekana)]
	t._check(fx_rampa_vadne == "",
		"render.hue: fixture - rampa %d sedych hodnot -> barvy sady %d (vadne:%s)"
		% [COLORS, FIXTURE_SKIN, fx_rampa_vadne])
	print("[test]      mereno (fixture rampa -> R):", fx_detail)

	# D5) INDEX JE Z R KANALU, ne ze zeleneho: R = 41 (uroven 5), G = 247
	#    (uroven 30). U sediveho pixelu jsou R a G stejne a mutace by prosla.
	var fx_rg := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	fx_rg.set_pixel(0, 0, Color8(int(EXPAND_REF[5]), 247, 0, 255))
	var fx_rg_tex := ImageTexture.create_from_image(fx_rg)
	var fx_rg_ton: Texture2D = fx.hued(fx_rg_tex, FIXTURE_SKIN)
	var fx_c5: int = int(SKIN_COLORS[5])
	var fx_vzor_g: Color = _oracle(int(SKIN_COLORS[30]))
	t._check(not _oracle(fx_c5).is_equal_approx(fx_vzor_g)
		and _pixel(fx_rg_ton, 0).is_equal_approx(_oracle(fx_c5)),
		"render.hue: fixture - index barvy je z R (R=%d -> uroven 5 = %s, vyslo %s; uroven 30 by byla %s)"
		% [int(EXPAND_REF[5]), str(_oracle(fx_c5)), str(_pixel(fx_rg_ton, 0)), str(fx_vzor_g)])

	# D6) PARTIAL_HUE: prebarvi JEN pixely s R == G == B, barevne necha. A plny
	#    hue prebarvi i barevny pixel (jinak by "partial" byla jedina cesta).
	var fx_mix := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	fx_mix.set_pixel(0, 0, Color8(int(EXPAND_REF[12]), int(EXPAND_REF[12]),
		int(EXPAND_REF[12]), 255))                        # seda (uroven 12)
	fx_mix.set_pixel(1, 0, Color8(200, 40, 40, 255))     # cervena - NENI seda
	fx_mix.set_pixel(2, 0, Color8(0, 0, 0, 255))         # cerna (uroven 0)
	var fx_mix_tex := ImageTexture.create_from_image(fx_mix)
	var fx_castecne: Texture2D = fx.hued(fx_mix_tex, FIXTURE_SKIN, true)
	var fx_plne: Texture2D = fx.hued(fx_mix_tex, FIXTURE_SKIN, false)
	var fx_c12: int = int(SKIN_COLORS[12])
	var fx_c24: int = int(SKIN_COLORS[24])
	t._check(_pixel(fx_castecne, 0).is_equal_approx(_oracle(fx_c12))
		and _pixel(fx_castecne, 1).is_equal_approx(Color8(200, 40, 40, 255))
		and _pixel(fx_castecne, 2).is_equal_approx(_oracle(int(SKIN_COLORS[0]))),
		"render.hue: fixture - partial_hue prebarvi JEN sedive (seda %s, barevny %s, cerny %s)"
		% [str(_pixel(fx_castecne, 0)), str(_pixel(fx_castecne, 1)), str(_pixel(fx_castecne, 2))])
	t._check(not _pixel(fx_plne, 1).is_equal_approx(Color8(200, 40, 40, 255))
		and _pixel(fx_plne, 1).is_equal_approx(_oracle(fx_c24)),
		"render.hue: fixture - plny hue prebarvi i barevny pixel (R=200 -> uroven 24 = %s, vyslo %s)"
		% [str(_oracle(fx_c24)), str(_pixel(fx_plne, 1))])

	# D7) ALFA je MASKA spritu (128 zustane 128, pruhledny zustane pruhledny).
	var fx_maska_img := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	for i in 3:
		var fx_a: int = [128, 0, 255][i]
		fx_maska_img.set_pixel(i, 0, Color8(int(EXPAND_REF[8]), int(EXPAND_REF[8]),
			int(EXPAND_REF[8]), fx_a))
	var fx_maska_tex := ImageTexture.create_from_image(fx_maska_img)
	var fx_maska: Texture2D = fx.hued(fx_maska_tex, FIXTURE_SKIN)
	t._check(is_equal_approx(_pixel(fx_maska, 0).a, 128.0 / 255.0)
		and is_equal_approx(_pixel(fx_maska, 1).a, 0.0)
		and is_equal_approx(_pixel(fx_maska, 2).a, 1.0),
		"render.hue: fixture - alfa se zachova (128 -> %d, 0 -> %d, 255 -> %d)"
		% [roundi(_pixel(fx_maska, 0).a * 255.0), roundi(_pixel(fx_maska, 1).a * 255.0),
			roundi(_pixel(fx_maska, 2).a * 255.0)])

	# D8) CHYBEJICI SADA: v fixture sada 1004 NENI -> puvodni textura + `missing`.
	var fx_pred_missing: int = int(fx.stats()["missing"])
	var fx_nic: Texture2D = fx.hued(fx_rampa_tex, FIXTURE_SETS + 1)
	t._check(fx_nic == fx_rampa_tex and int(fx.stats()["missing"]) == fx_pred_missing + 1,
		"render.hue: fixture - sada %d v ni NENI -> puvodni textura a missing (%d -> %d)"
		% [FIXTURE_SETS + 1, fx_pred_missing, int(fx.stats()["missing"])])

	# D9) CACHE PODLE OBSAHU: dve RUZNE textury vytvorene ZA BEHU (obě maji
	#    `resource_path` prazdny) se stejnym hue si nesmi vymenit vysledek.
	var fx_druha_img := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	for i in 3:
		fx_druha_img.set_pixel(i, 0, Color8(int(EXPAND_REF[8]), int(EXPAND_REF[8]),
			int(EXPAND_REF[8]), 0 if i == 1 else 255))
	var fx_druha_tex := ImageTexture.create_from_image(fx_druha_img)
	var fx_druha: Texture2D = fx.hued(fx_druha_tex, FIXTURE_SKIN)
	t._check(fx_druha != fx_maska and is_equal_approx(_pixel(fx_druha, 1).a, 0.0)
		and is_equal_approx(_pixel(fx_maska, 0).a, 128.0 / 255.0),
		"render.hue: fixture - dve textury se stejnym hue maji VLASTNI vysledek (stejna instance %s, alfa 128 -> %d)"
		% [str(fx_druha == fx_maska), roundi(_pixel(fx_maska, 0).a * 255.0)])

	# D10) STROP CACHE se opravdu vyhazuje (maly strop = meritelny, ne tichy rust).
	var fx_maly = script.new(FIXTURE, 2)
	for i in 6:
		var fx_obrazek := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		fx_obrazek.set_pixel(0, 0, Color8(int(EXPAND_REF[i + 2]), int(EXPAND_REF[i + 2]),
			int(EXPAND_REF[i + 2]), 255))
		fx_maly.hued(ImageTexture.create_from_image(fx_obrazek), FIXTURE_SKIN)
	var fx_ms: Dictionary = fx_maly.stats()
	t._check(int(fx_ms["polozek"]) <= 2 and int(fx_ms["bytes"]) > 0,
		"render.hue: fixture - strop 2 polozky drzi (polozek %d, bytes %d), ne tichy rust"
		% [int(fx_ms["polozek"]), int(fx_ms["bytes"])])

	# D11) DVE RUZNE SADY daji na teze rampe RUZNE barvy (fixture je ma odlisne -
	#     kdyby ne, "sada bez posunu" by se na barvach nepoznala).
	var fx_druha_sada: Texture2D = fx.hued(fx_rampa_tex, FIXTURE_SECOND)
	var fx_lisi_se: int = 0
	for i in COLORS:
		if int(SKIN_COLORS[i]) != int(SECOND_COLORS[i]):
			fx_lisi_se += 1
	var fx_rozdil := false
	for v in COLORS:
		if not _pixel(fx_ton, v).is_equal_approx(_pixel(fx_druha_sada, v)):
			fx_rozdil = true
	t._check(fx_lisi_se > 0 and fx_rozdil,
		"render.hue: fixture - sada %d a %d maji %d odlisnych urovni a na rampe daji JINE barvy (%s)"
		% [FIXTURE_SKIN, FIXTURE_SECOND, fx_lisi_se, str(fx_rozdil)])

	# ---------- C) proti skutecnym datum (jen kdyz jsou) ----------
	if not FileAccess.file_exists(HUES):
		print("[test]      NEMERENO: render.hue - chybi ", HUES,
			" (assets/uo/ je v .gitignore); spust `python tools/uoextract/hues.py --install \"<UO>\"`")
		return
	var data = Lib.json_at(HUES)
	if not (data is Dictionary) or not (data.get("sets") is Array):
		print("[test]      NEMERENO: render.hue - hues.json se necte (poskozeny export)")
		return
	var sady: Array = data["sets"]
	t._check(sady.size() == 3000, "render.hue: hues.json ma %d sad (ocekavano 3000)" % sady.size())
	t._check(barvy.available() and barvy.set_count() == 3000,
		"render.hue: sady se nactou z " + HUES + " (set_count %d)" % barvy.set_count())

	# 6) jiny hue vrati ODLISNE pixely (pozadavek zadani granule)
	var hue := 1002            # 1002 = sada s nazvem "SkinHue #1001"
	var ton: Texture2D = barvy.hued(base, hue)
	t._check(ton != null and ton != base,
		"render.hue: hued(tex, %d) vraci jinou texturu" % hue)
	if ton == null:
		t._pending("render.hue: hued() vratil null - dal se neda merit")
		return

	# 7) index barvy = 5 HORNICH bitu: pixel s hodnotou `seda[i]` musi dostat
	#    barvu urovne `_uroven(seda[i])` (hodnoty se CTou, neopisuji).
	#    POZOR NA PAST (stala me 20 minut, namEReno): `i` v tomto testu je POZICE
	#    v rampe, ne uroven barvy! Rampa ma hodnoty 0, 8, 16, 24, 32, ... - uroven
	#    32 je 4, ne 32. Kdo preda `i` do `hue_color`, meri u vsech hodnot < 32
	#    spravnou vec a od 32 vys "vadu", ktera zadna neni.
	var vadne := ""
	var vsech := true
	var detail := ""
	for i in seda.size():
		var uroven: int = barvy._uroven(int(seda[i]))
		var cekana: Color = barvy.hue_color(hue, uroven)
		var je: Color = _pixel(ton, i)
		detail += " %d->%d" % [int(seda[i]), roundi(je.r * 255.0)]
		if not je.is_equal_approx(cekana):
			vsech = false
			vadne += " #%d(uroven %d): %s (cek. %s)" % [i, uroven, str(je), str(cekana)]
	t._check(vsech, "render.hue: 8 znamych sedych hodnot -> barvy sady (vadne:%s)" % vadne)
	print("[test]      mereno (seda -> R):", detail)

	# 8) barva urovne 0 je barva z prvniho mista sady
	var c0: Color = barvy.hue_color(hue, 0)
	t._check(_pixel(ton, 0).is_equal_approx(c0),
		"render.hue: seda 0 -> prvni barva sady %s" % str(c0))

	# 9) alfa se ZACHOVA (maska spritu, ne barva)
	var pruhledna := _texture([[0, 0, 8, 128], [1, 0, 8, 0], [2, 0, 8, 255]])
	var pt: Texture2D = barvy.hued(pruhledna, hue)
	t._check(is_equal_approx(_pixel(pt, 0).a, 128.0 / 255.0)
		and is_equal_approx(_pixel(pt, 2).a, 1.0),
		"render.hue: alfa se zachova (128 -> %d, 255 -> %d)"
		% [roundi(_pixel(pt, 0).a * 255.0), roundi(_pixel(pt, 2).a * 255.0)])
	t._check(is_equal_approx(_pixel(pt, 1).a, 0.0),
		"render.hue: plne pruhledny pixel zustava pruhledny (a = %d)"
		% roundi(_pixel(pt, 1).a * 255.0))

	# 10) CACHE PODLE OBSAHU: dve RUZNE textury se stejnym hue si nesmi vymenit
	#     vysledek. Textura vytvorena za behu ma `resource_path` PRAZDNY - klice
	#     podle jmena souboru by kolidovaly (presne to namEReno: pruhledny
	#     obrazek dostal neprusvitelnou verzi obrazku predchoziho).
	var jina: Texture2D = barvy.hued(_texture([[0, 0, 24, 255], [1, 0, 24, 0], [2, 0, 24, 255]]), hue)
	t._check(is_equal_approx(_pixel(jina, 1).a, 0.0)
		and is_equal_approx(_pixel(jina, 0).a, 1.0)
		and not _pixel(jina, 0).is_equal_approx(_pixel(pt, 0)),
		"render.hue: dve textury se stejnym hue maji VLASTNI vysledek (alfa %d/%d, barva %s vs %s)"
		% [roundi(_pixel(jina, 0).a * 255.0), roundi(_pixel(jina, 1).a * 255.0),
			str(_pixel(jina, 0)), str(_pixel(pt, 0))])

	# 11) partial_hue: sedive pixely se prebarvi, barevne zustanou
	var mix := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	mix.set_pixel(0, 0, Color8(99, 99, 99, 255))     # seda (uroven 12)
	mix.set_pixel(1, 0, Color8(200, 40, 40, 255))    # cervena - NENI seda
	mix.set_pixel(2, 0, Color8(0, 0, 0, 255))        # cerna (uroven 0)
	var mix_tex := ImageTexture.create_from_image(mix)
	var castecne: Texture2D = barvy.hued(mix_tex, hue, true)
	t._check(_pixel(castecne, 0).is_equal_approx(barvy.hue_color(hue, 12)),
		"render.hue: partial_hue prebarvi sedy pixel %s (cek. %s)"
		% [str(_pixel(castecne, 0)), str(barvy.hue_color(hue, 12))])
	t._check(_pixel(castecne, 1).is_equal_approx(Color8(200, 40, 40, 255)),
		"render.hue: partial_hue NECHAVA barevny pixel %s" % str(_pixel(castecne, 1)))
	var plne: Texture2D = barvy.hued(mix_tex, hue, false)
	t._check(not _pixel(plne, 1).is_equal_approx(Color8(200, 40, 40, 255)),
		"render.hue: plny hue prebarvi i barevny pixel (%s)" % str(_pixel(plne, 1)))

	# 12) INDEX JE Z R KANALU, ne ze zeleneho (ClassicUO `get_rgb(color.r, hue)`).
	#     Fixture ma R != G, aby se to vubec dalo odlisit: u sediveho pixelu jsou
	#     R a G stejne, takze by obe mutace prosly.
	var barevny := _texture_rgb(41, 247)             # R = 41 (uroven 5), G = 247
	var obarveny: Texture2D = barvy.hued(barevny, hue)
	t._check(_pixel(obarveny, 0).is_equal_approx(barvy.hue_color(hue, 5)),
		"render.hue: index barvy je z R kanalu (R=41 -> uroven 5 = %s, vyslo %s)"
		% [str(barvy.hue_color(hue, 5)), str(_pixel(obarveny, 0))])

	# 13) cache: druhe volani je HIT a vraci TUTEZ instanci, jiny hue je MISS
	var st: Dictionary = barvy.stats()
	var pred_hits: int = int(st["hits"])
	var pred_misses: int = int(st["misses"])
	var znovu: Texture2D = barvy.hued(base, hue)
	var po: Dictionary = barvy.stats()
	t._check(znovu == ton and int(po["hits"]) == pred_hits + 1 and int(po["misses"]) == pred_misses,
		"render.hue: druhe volani je cache HIT (hits %d -> %d, misses %d -> %d, stejna instance %s)"
		% [pred_hits, int(po["hits"]), pred_misses, int(po["misses"]), str(znovu == ton)])
	var jiny: Texture2D = barvy.hued(base, 1003)
	t._check(jiny != ton and int(barvy.stats()["misses"]) == pred_misses + 1,
		"render.hue: jiny hue je cache MISS (nova textura)")

	# 14) strop cache se opravdu vyhazuje (maly strop = meritelny), a neni tichy
	var maly = script.new(HUES, 2)
	for i in 6:
		maly.hued(base, 1002 + i)
	var ms: Dictionary = maly.stats()
	t._check(int(ms["polozek"]) <= 2 and int(ms["bytes"]) > 0,
		"render.hue: strop 2 polozky drzi (polozek %d, bytes %d), ne tichy rust"
		% [int(ms["polozek"]), int(ms["bytes"])])

	# 15) barva ze souboru: sada pro kuži se JMENUJE "SkinHue ..." (nazev z JSONu,
	#     ne opsany) a `hue_color` z ni vraci PRESNE prvni barvu sady
	var prvni: int = int(sady[1001]["colors"][0])
	var r8 := int(round(float((prvni >> 10) & 0x1F) * 255.0 / 31.0))
	var popis: Color = barvy.hue_color(1002, 0)
	t._check(str(sady[1001].get("name", "")).begins_with("SkinHue")
		and roundi(popis.r * 255.0) == r8,
		"render.hue: sada 1002 = %s, prvni barva R %d (z JSON %d)"
		% [str(sady[1001].get("name", "")), roundi(popis.r * 255.0), r8])

	# 16) dve RUZNE sady daji na stejnem obrazku RUZNE barvy (tonovani ma smysl)
	var a1: Texture2D = barvy.hued(base, 1002)
	var a2: Texture2D = barvy.hued(base, 1003)
	var rozdil := false
	for i in seda.size():
		if not _pixel(a1, i).is_equal_approx(_pixel(a2, i)):
			rozdil = true
	t._check(rozdil, "render.hue: sada 1002 a 1003 daji na teze rampe jine barvy")

	# 17) POSUN SADY A KANALY: `hue_color(hue, i)` se porovna s JSONem pro
	#     VSECHNY sady a urovne (3000 x 32). Ocekavana barva se pocita PRIMO
	#     z `colors[i]` v JSONu podle pravidla UO (`(c >> 10) & 0x1F` = R,
	#     `(c >> 5) & 0x1F` = G, `c & 0x1F` = B, expanze 5 -> 8 z MERENE tabulky).
	#     Tohle je kontrola, ktera odlisi posun sady i prohozene kanaly - obe
	#     vady na sedive rampe vypadaji "skoro dobre".
	var json_ok := true
	var json_chyby := ""
	for h in range(1, sady.size() + 1):
		var barvy_json: Array = sady[h - 1]["colors"]
		for i in COLORS:
			var c: int = int(barvy_json[i])
			var cekana := Color8(int(tabulka[(c >> 10) & 0x1F]), int(tabulka[(c >> 5) & 0x1F]),
				int(tabulka[c & 0x1F]))
			var je: Color = barvy.hue_color(h, i)
			if not je.is_equal_approx(cekana):
				json_ok = false
				if json_chyby.length() < 120:
					json_chyby += " hue%d/uroven%d: %s != %s" % [h, i, str(je), str(cekana)]
	t._check(json_ok, "render.hue: hue_color() sedi na JSON u vsech %d sad x %d urovni (chyby:%s)"
		% [sady.size(), COLORS, json_chyby])

	# 18) OKNO (AtlasTexture): `hued()` musi obarvit a vratit POUZE `region`,
	#     ne celou stranku. Vada ze snimku (uzivatel, 2026-10-07): pri chuzi se
	#     "vedle postavy zobrazily vsechny animacni snimky" - frame animace je
	#     `AtlasTexture` do stranky, ktera ma vsech 10 framu vedle sebe, a
	#     `_obrazek()` bral CELY atlas.
	#     Test meri dve veci: ROZMER vysledku (16x16, ne 48x16) a BARVU, ktera
	#     musi odpovidat DRUHEMU framu (kdyby se vzal prvni, vysla by jina
	#     uroven - kde je R == 8, tady 16).
	var stranka := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	stranka.fill(Color(0, 0, 0, 0))
	for idx in 3:
		for y in 16:
			for x in 16:
				var siva: int = 8 + idx * 8         # 8 / 16 / 24 = urovne 1 / 2 / 3
				stranka.set_pixel(idx * 16 + x, y, Color8(siva, siva, siva, 255))
	var okno := AtlasTexture.new()
	okno.atlas = ImageTexture.create_from_image(stranka)
	okno.region = Rect2(16, 0, 16, 16)
	var obarvene_okno: Texture2D = barvy.hued(okno, hue)
	t._check(obarvene_okno.get_width() == 16 and obarvene_okno.get_height() == 16,
		"render.hue: hued(AtlasTexture) vraci OKNO 16x16, ne stranku (vyslo %dx%d)"
		% [obarvene_okno.get_width(), obarvene_okno.get_height()])
	t._check(_pixel(obarvene_okno, 0).is_equal_approx(barvy.hue_color(hue, 2)),
		"render.hue: obarvene okno odpovida DRUHÉMU framu (uroven 2 = %s, vyslo %s)"
		% [str(barvy.hue_color(hue, 2)), str(_pixel(obarvene_okno, 0))])
	# A jiny region tehoz atlasu musi dat JINY vysledek (ne prvni fram)
	okno.region = Rect2(32, 0, 16, 16)
	var treti: Texture2D = barvy.hued(okno, hue)
	t._check(_pixel(treti, 0).is_equal_approx(barvy.hue_color(hue, 3)),
		"render.hue: jiny region = jiny frame (uroven 3 = %s, vyslo %s)"
		% [str(barvy.hue_color(hue, 3)), str(_pixel(treti, 0))])
