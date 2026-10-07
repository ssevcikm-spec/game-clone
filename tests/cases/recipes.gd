extends RefCounted
# data.recipes - OBSAH data/recipes.json (granule data.recipes; docs/06 §6.1,
# smlouva docs/04 §4.5). Soubor je v gitu, takze chybejici soubor i rozbity
# obsah je VADA a case spadne - zadne NEMERENO se tu neskryva.
#
# CO SE MERI (docs/09 §9.4 - chovani, ne "soubor existuje"):
#   * pocet zaznamu a to, ze `id` je 0..N-1 BEZ der a duplicit,
#   * povinna pole z brany G5 (`tools/gates/check-content.py`:
#     id, skill, min_skill, result, materials) a jejich typy,
#   * kazdy material ma amount >= 1, neprazdny `name`/`kind`/`type`,
#     vysledek ma amount >= 1 a kind "result",
#   * KRIZOVE: kazdy `tile` z materialu i vysledku existuje v data/items.json
#     (u vsech odkazu, ne u vzorku) - a to BEZ posunu. `data/recipes.json`
#     i `data/items.json` maji TILEDATA id; `entity.item.tile` je ART id
#     (`+0x4000`, sim/entity/item.gd). Test to overi z obou stran:
#     odkazy >= 0x4000 sedi jak jsou, a posun `-0x4000`/`+0x4000` by je
#     ROZBIL - kdyby se id prostory pletly, krizova kontrola to vi.
#   * `skill` receptu se da dohledat v data/skills.json (3 nazvy ne - viz
#     ZNAME_CHYBEJICI, je to namEReny nalezy, ne ticha vyjimka).
#
# CESTY JSOU VSTUP (`-- --recipes-path= --items-path= --skills-path=`), aby
# se dala vlozit vada do VSTUPU a dokazat, ze kontrola opravdu meri - a aby
# se nikdy nemuselo sahat na `data/`.

const Lib = preload("res://tests/lib.gd")

const RECIPES_PATH := "res://data/recipes.json"
const ITEMS_PATH := "res://data/items.json"
const SKILLS_PATH := "res://data/skills.json"
const ITEM_OFFSET := 0x4000

# Povinná pole receptu - stejny seznam jako `REQUIRED_FIELDS` v G5
# (`tools/gates/check-content.py`). Kdyby se rozešly, je to nalezy.
const REQUIRED := ["id", "skill", "min_skill", "result", "materials"]

# NALEZ (namEReno 2026-10-08): z 11 nazvu skillu v receptech 3 v `data/skills.json`
# NEJSOU (BowFletching, Glassblowing, Masonry). Neni to vyjimka "aby to proslo":
# prida-li data CTVRTY neznamy nazev, kontrola SPADNE; kdyz se tyhle tri v
# skills.json doplni, zustane zelena (podmnozina).
const ZNAME_CHYBEJICI := ["BowFletching", "Glassblowing", "Masonry"]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _je_int(v) -> bool:
	# POZOR (namEReno 2026-10-08): `JSON.parse_string` v Godotu 4.7.2 vraci
	# VSECHNA cisla jako TYPE_FLOAT (`id` z JSON je 0.0, ne 0). Kdo se pta na
	# TYPE_INT, nerozliší "spravne cislo" od "textu" a vsechno mu vyjde spatne -
	# presne to je i past pro kontrolu: cislo z JSON se overuje PRES `int()`,
	# jako to dela `tests/cases/skills_data.gd`.
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) != TYPE_FLOAT:
		return false
	var f: float = float(v)
	return not is_nan(f) and not is_inf(f) and f == floor(f)


func _json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func run(t) -> void:
	var recipes_path := _arg("recipes-path", RECIPES_PATH)
	if not FileAccess.file_exists(recipes_path):
		t._pending("data.recipes NEMERENO: " + recipes_path
			+ " chybi (data jsou v gitu - chybejici soubor je vada, ne ticho)")
		return
	var recipes = _json(recipes_path)
	if not (recipes is Array) or (recipes as Array).is_empty():
		t._pending("data.recipes NEMERENO: " + recipes_path + " neni JSON seznam zaznamu")
		return

	# --- 1) pocet zaznamu a jejich tvar ---------------------------------------
	var zaznamu: int = recipes.size()
	var ne_slovnik := 0
	var chybi_pole: Array = []
	var spatny_typ := 0
	var materialu := 0
	var prazdnych_materialu := 0
	var spatny_material := 0
	var spatny_vysledek := 0
	for i in zaznamu:
		var r = recipes[i]
		if not (r is Dictionary):
			ne_slovnik += 1
			continue
		for pole in REQUIRED:
			if not r.has(pole):
				chybi_pole.append("%d.%s" % [i, pole])
		if not _je_int(r.get("id")) or not (r.get("skill") is String) \
			or str(r.get("skill")).strip_edges() == "" \
			or not (r.get("result") is Dictionary) or not (r.get("materials") is Array):
			spatny_typ += 1
		var mat = r.get("materials")
		if mat is Array:
			if (mat as Array).is_empty():
				prazdnych_materialu += 1
			for m in mat:
				materialu += 1
				if not (m is Dictionary) or not _je_int(m.get("amount")) \
					or int(m.get("amount")) < 1 or str(m.get("name", "")).strip_edges() == "" \
					or str(m.get("kind", "")).strip_edges() == "" \
					or str(m.get("type", "")).strip_edges() == "":
					spatny_material += 1
		var res = r.get("result")
		if res is Dictionary:
			if not _je_int(res.get("amount")) or int(res.get("amount")) < 1 \
				or str(res.get("kind", "")) != "result" \
				or str(res.get("name", "")).strip_edges() == "":
				spatny_vysledek += 1

	t._check(zaznamu > 1000 and ne_slovnik == 0,
		"data.recipes: seznam ma tisice slovniku (namEReno %d zaznamu, ne-slovniku %d)"
			% [zaznamu, ne_slovnik])
	t._check(chybi_pole.is_empty(),
		"data.recipes: vsech 5 povinnych poli (%s) je v kazdem zaznamu (chybi %d: %s)"
			% [str(REQUIRED), chybi_pole.size(),
				str(chybi_pole.slice(0, 5))])
	t._check(spatny_typ == 0,
		"data.recipes: typy id/skill/result/materials sedi (spatne %d z %d)"
			% [spatny_typ, zaznamu])
	t._check(materialu > 0 and spatny_material == 0 and prazdnych_materialu == 0,
		"data.recipes: %d materialu ma amount >= 1 a neprazdne name/kind/type, "
		% materialu + "zadny recept nema prazdny seznam (spatne %d, prazdnych receptu %d)"
			% [spatny_material, prazdnych_materialu])
	t._check(spatny_vysledek == 0,
		"data.recipes: kazdy vysledek ma amount >= 1, kind 'result' a neprazdne name "
		+ "(spatne %d z %d)" % [spatny_vysledek, zaznamu])

	# --- 2) `id` je 0..N-1 bez der a duplicit --------------------------------
	var idy: Dictionary = {}
	var id_min: int = 0x7FFFFFFF
	var id_max: int = -1
	for r in recipes:
		if not (r is Dictionary) or not _je_int(r.get("id")):
			continue
		var id: int = int(r["id"])
		idy[id] = true
		id_min = mini(id_min, id)
		id_max = maxi(id_max, id)
	t._check(idy.size() == zaznamu and id_min == 0 and id_max == zaznamu - 1,
		"data.recipes: id je 0..N-1 bez der a duplicit (unikatnich %d z %d, min %d, max %d)"
			% [idy.size(), zaznamu, id_min, id_max])

	# --- 3) min_skill <= max_skill (1 zaznam ma obe null - je VIDET) ---------
	var obracene := 0
	var bez_skilu := 0
	for r in recipes:
		if not (r is Dictionary):
			continue
		var lo = r.get("min_skill")
		var hi = r.get("max_skill")
		if typeof(lo) == TYPE_NIL or typeof(hi) == TYPE_NIL:
			bez_skilu += 1
			continue
		if float(lo) > float(hi):
			obracene += 1
	t._check(obracene == 0,
		"data.recipes: min_skill <= max_skill (obracene %d, bez hodnot %d z %d)"
			% [obracene, bez_skilu, zaznamu])
	# skill je v datech NAZEV (docs/04 §4.5 ma `skill:int` - nalezy, neopravuji)
	var skillu := 0
	var skill_prazdny := 0
	for r in recipes:
		if not (r is Dictionary):
			continue
		var s := str(r.get("skill", ""))
		if s.strip_edges() == "":
			skill_prazdny += 1
		else:
			skillu += 1
	t._check(skill_prazdny == 0 and skillu == zaznamu,
		"data.recipes: skill je neprazdny nazev u vsech zaznamu (prazdnych %d z %d)"
			% [skill_prazdny, zaznamu])

	# --- 4) krizova kontrola proti data/items.json ---------------------------
	var items_path := _arg("items-path", ITEMS_PATH)
	if not FileAccess.file_exists(items_path):
		t._pending("data.recipes NEMERENO: krizova kontrola potrebuje " + items_path)
		return
	var items = _json(items_path)
	if not (items is Array) or (items as Array).is_empty():
		t._pending("data.recipes NEMERENO: " + items_path + " neni JSON seznam predmetu")
		return
	var tiles: Dictionary = {}
	for it in items:
		if it is Dictionary and _je_int(it.get("tile")):
			tiles[int(it["tile"])] = true
	t._check(tiles.size() > 0,
		"data.recipes: items.json dal mnozinu tiledata id (%d predmetu, %d id)"
			% [(items as Array).size(), tiles.size()])

	# vsechny odkazy (ne vzorek) a z obou stran id prostoru
	var odkazu := 0
	var nerozresenych := 0
	var malych := 0
	var malych_posun := 0
	var velkych := 0
	var velkych_posun := 0
	var prvni_selhani := ""
	for i in zaznamu:
		var r = recipes[i]
		if not (r is Dictionary):
			continue
		var odkazy: Array = []
		var mat = r.get("materials")
		if mat is Array:
			for m in mat:
				if m is Dictionary and _je_int(m.get("tile")):
					odkazy.append(["materials", int(m["tile"])])
		var res = r.get("result")
		if res is Dictionary and _je_int(res.get("tile")):
			odkazy.append(["result", int(res["tile"])])
		for odkaz in odkazy:
			var tile: int = odkaz[1]
			odkazu += 1
			if not tiles.has(tile):
				nerozresenych += 1
				if prvni_selhani == "":
					prvni_selhani = "recept %d %s tile %d" % [i, str(odkaz[0]), tile]
			if tile < ITEM_OFFSET:
				malych += 1
				if tiles.has(tile + ITEM_OFFSET):
					malych_posun += 1
			else:
				velkych += 1
				if tiles.has(tile - ITEM_OFFSET):
					velkych_posun += 1

	t._check(odkazu > 0 and nerozresenych == 0,
		"data.recipes: vsech %d odkazu na tile (materialy i vysledky) je v items.json "
		% odkazu + "(nerozresenych %d%s)"
			% [nerozresenych, "" if nerozresenych == 0 else ", prvni " + prvni_selhani])
	# TILEDATA vs ART id: odkazy >= 0x4000 sedi JAK JSOU, kdezto posunuty
	# prostor by je rozbil; u malych odkazu je to naopak. Kdyby data michala
	# dva prostory, tahle dvojice kontroly to rekne cislem.
	t._check(velkych > 0 and velkych_posun < velkych and malych_posun < malych,
		"data.recipes: odkazy jsou TILEDATA id, ne ART id "
		+ "(velkych %d sedi jak jsou, s -0x4000 jen %d; malych %d, s +0x4000 jen %d)"
			% [velkych, velkych_posun, malych, malych_posun])

	# --- 5) skill receptu proti data/skills.json ----------------------------
	var skills_path := _arg("skills-path", SKILLS_PATH)
	if not FileAccess.file_exists(skills_path):
		t._pending("data.recipes NEMERENO: kontrola skillu potrebuje " + skills_path)
		return
	var skills = _json(skills_path)
	if not (skills is Array) or (skills as Array).is_empty():
		t._pending("data.recipes NEMERENO: " + skills_path + " neni JSON seznam skillu")
		return
	var nazvy: Dictionary = {}
	for s in skills:
		if s is Dictionary and s.get("name") is String:
			nazvy[str(s["name"])] = true
	var pouzite: Dictionary = {}
	for r in recipes:
		if r is Dictionary:
			pouzite[str(r.get("skill", ""))] = true
	var bez_shody: Array = []
	var se_shodou := 0
	for nazev in pouzite.keys():
		if nazvy.has(nazev):
			se_shodou += 1
		else:
			bez_shody.append(nazev)
	bez_shody.sort()
	var nezname: Array = []
	for nazev in bez_shody:
		if not (nazev in ZNAME_CHYBEJICI):
			nezname.append(nazev)
	t._check(se_shodou > 0 and nezname.is_empty(),
		"data.recipes: skill receptu je v skills.json (%d z %d nazvu; bez shody %s, novych %s)"
			% [se_shodou, pouzite.size(), str(bez_shody), str(nezname)])
