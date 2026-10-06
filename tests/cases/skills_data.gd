extends RefCounted
# data.skills - data/skills.json (granule data.skills; docs/11 §11.1, docs/05 §5.16).
#
# CO SE MERI (docs/09 §9.4) - data se CTOU a srovnavaji se tremi zdroji, ktere
# nejsou ten soubor sam:
#   * 58 zaznamu, id 0..57 v poradi klienta a JMENA proti `data/skill_groups.json`
#     = extrakt `skills.mul` nastrojem `tools/uoextract/textdata.py` (docs/11 §11.1),
#   * primarni/sekundarni stat proti tabulce `research/02-skills.md` §3.9
#     (ServUO `SkillInfo.Table`) - tvrzeni se CTE z dokumentu, neopisuje se,
#   * skupina proti `skillgrp.mul` (extract) vcetne 1-baznoveho mapovani id->jmeno
#     a implicitni skupiny 0 ("Miscellaneous"), viz `_skupina_misc()`,
#   * `implemented` proti TVRZENI v docs/05 §5.16 a proti zadani granule
#     v `.forge/roadmap.json` - obe se ctou z dokumentu,
#   * `era` proti vete v research/02 §7.2 (AoS/SE/ML/SA).
#
# NALEZY (hlasene, neopravovane - menit je smi jen clovek v docs/ a .forge/):
#   1. Zadani granule uvadi `implemented: false` u SEDMI skillu (Necromancy,
#      Bushido, Ninjitsu, Spellweaving, Throwing, Imbuing, Mysticism), ale
#      docs/05 §5.16 uvadi DEVET - ti sami + Chivalry a Focus. Data sleduji
#      dokument (9); test overuje OBOJE: mnozinu z dokumentu i to, ze tech 7 ze
#      zadani v ni je. Kdyby mel klon Chivalry/Focus implementovat, je to
#      zmena rozhodnuti v docs/05 §5.16, ne ticha vyjimka v datech.
#   2. Poradi skillu 55-57 se ROZCHAZI: `skills.mul` teto instalace ma
#      55 Throwing / 56 Imbuing / 57 Mysticism (overeno primym ctenim souboru
#      i docs/11 §11.1), kdezto research/02 §3.9 a §7.3 cisluji 55 Mysticism /
#      57 Throwing (poradi tridy `SkillInfo` ze serveru; stejne i vyctovy typ
#      `SkillEntry.HardCodedName` v ClassicUO). Staty se proto berou podle
#      JMENA; poradi je ze `skills.mul` (zadani granule). Generator ten rozchod
#      zapisuje do `content-report.json`, ne do ticha.
#   3. docs/03 §3.9.3 tvrdi, ze skupina "id 6" je bez jmena. Neni: bez jmena je
#      skupina 0 a "id 6" je "Bard" (6. z 6 jmen). Dukaz je v datech i v
#      `ClassicUO:SkillsGroupManager.LoadMULFile` (groups[0] = Miscellaneous,
#      jmena groups[1..6] v poradi ze souboru).
#
# Cesta k datum je VSTUP: `-- --skills-data=<cesta>`, aby mutacni test
# (tools/gates/mutace-skills.py) mohl predat mutanta a aby se overilo, ze test
# meri opravdu ten soubor, ktery dostane (HANDOFF 2026-10-06, past 2).

const Lib = preload("res://tests/lib.gd")

const SKILLS_PATH := "res://data/skills.json"
const EXTRACT_PATH := "res://data/skill_groups.json"
const RESEARCH_PATH := "res://research/02-skills.md"
const DOCS_ERA_PATH := "res://docs/05-mechaniky.md"
const ROADMAP_PATH := "res://.forge/roadmap.json"
const COUNT := 58
const ERA_CLASSIC := "pre-aos"
const FIELDS := ["id", "name", "group", "group_id", "stat_primary",
	"stat_secondary", "implemented", "era", "source"]


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _s(rec: Dictionary, key: String) -> String:
	return str(rec.get(key, ""))


func _skupina_misc(text: String) -> String:
	# research/02 §7.3: "group 0 = Miscellaneous is implicit and non-deletable".
	var re := RegEx.new()
	if re.compile("group 0 = ([A-Za-z]+)") != OK:
		return ""
	for line in text.split("\n"):
		var found := re.search(line)
		if found != null:
			return found.get_string(1)
	return ""


func _false_z_dokumentu(text: String) -> Array:
	# docs/05 §5.16: "... Necromancy/Bushido/.../Focus = `implemented: false`".
	# Vzor vyzaduje lomitko, takze netrefi vetu v §5.10.1, ktera jen cituje
	# `implemented: false` bez seznamu.
	var re := RegEx.new()
	if re.compile("([A-Za-z]+(?:/[A-Za-z]+)+)\\s*=\\s*`implemented: false`") != OK:
		return []
	for line in text.split("\n"):
		var found := re.search(line)
		if found == null:
			continue
		var out: Array = []
		for jmeno in found.get_string(1).split("/"):
			if not out.has(jmeno):
				out.append(jmeno)
		return out
	return []


func _false_z_roadmapy(text: String) -> Array:
	# Zadani granule: "`implemented: false` pro Necromancy/Bushido/...".
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		return []
	for grain in data.get("grains", []):
		if str(grain.get("id", "")) != "data.skills":
			continue
		var re := RegEx.new()
		if re.compile("implemented: false`?\\s*pro\\s*([A-Za-z]+(?:/[A-Za-z]+)+)") != OK:
			return []
		var found := re.search(str(grain.get("prompt", "")))
		if found == null:
			return []
		return Array(found.get_string(1).split("/"))
	return []


func _staty_z_research(text: String) -> Dictionary:
	# Tabulka pod nadpisem "### 3.9" (dokud nezacne dalsi "### ") - stejna
	# hranice jako v generatoru, aby se do ni nepletla tabulka §7.3.
	var out: Dictionary = {}
	var re := RegEx.new()
	if re.compile("^\\|\\s*\\d+\\s*\\|\\s*([^|]+?)\\s*\\|\\s*(Str|Dex|Int)\\s*\\|\\s*(Str|Dex|Int)\\s*\\|") != OK:
		return out
	var v_tabulce := false
	for line in text.split("\n"):
		if line.begins_with("### "):
			v_tabulce = line.begins_with("### 3.9")
			continue
		if not v_tabulce:
			continue
		var found := re.search(line)
		if found != null:
			out[found.get_string(1).strip_edges()] = [found.get_string(2).to_lower(),
				found.get_string(3).to_lower()]
	return out


func _ery_z_research(text: String) -> Dictionary:
	# research/02 §7.2: "Answer to the explicit question - which of 49..57 are
	# post-classic: **all nine**. Necromancy/Focus/Chivalry = AoS (2003-02-11);
	# Bushido/Ninjitsu = SE ...". Bere se radek s "post-classic" a NEJVIC
	# shodami (radek 523 tez obsahuje "post-classic", ale zadnou eru).
	var re := RegEx.new()
	if re.compile("([A-Za-z]+(?:/[A-Za-z]+)*)\\s*=\\s*(AoS|SE|ML|SA)\\b") != OK:
		return {}
	var nejlepsi: Dictionary = {}
	for line in text.split("\n"):
		if not ("post-classic" in line):
			continue
		var found: Dictionary = {}
		for match in re.search_all(line):
			var era := match.get_string(2).to_lower()
			for jmeno in match.get_string(1).split("/"):
				found[jmeno] = era
		if found.size() > nejlepsi.size():
			nejlepsi = found
	return nejlepsi


func run(t) -> void:
	var path := _arg("skills-data", SKILLS_PATH)
	var parsed = Lib.json_at(path)
	if not (parsed is Array):
		t._pending("data.skills NENI HOTOVA: %s chybi nebo neni JSON seznam zaznamu" % path)
		return
	var zaznamy: Array = []
	for rec in parsed:
		zaznamy.append(rec if rec is Dictionary else {})

	# 1) pocet, pole, puvod (docs/06 §6.8 C10: kazdy zaznam ma `source` a `era`)
	t._check(zaznamy.size() == COUNT,
		"data.skills: %d zaznamu (namEReno %d)" % [COUNT, zaznamy.size()])
	var chybi_pole := 0
	var pole_detail := ""
	for rec in zaznamy:
		for field in FIELDS:
			if not rec.has(field):
				chybi_pole += 1
				if pole_detail == "":
					pole_detail = "id %s nema '%s'" % [_s(rec, "id"), field]
				break
	t._check(chybi_pole == 0, "data.skills: kazdy zaznam ma pole %s (%d vad; %s)"
		% [str(FIELDS), chybi_pole, pole_detail])
	var bez_puvodu := 0
	for rec in zaznamy:
		if _s(rec, "source").strip_edges() == "" or _s(rec, "era").strip_edges() == "":
			bez_puvodu += 1
	t._check(bez_puvodu == 0,
		"data.skills: 'source' i 'era' je u vsech zaznamu (docs/06 §6.8 C10; %d prazdnych)" % bez_puvodu)

	# 2) poradi klienta: id == index (docs/11 §11.1)
	var poradi_vad := 0
	var poradi_detail := ""
	for i in zaznamy.size():
		if int(zaznamy[i].get("id", -1)) != i:
			poradi_vad += 1
			if poradi_detail == "":
				poradi_detail = "index %d ma id %s" % [i, _s(zaznamy[i], "id")]
	t._check(poradi_vad == 0, "data.skills: id == poradove cislo 0..%d (%d vad; %s)"
		% [COUNT - 1, poradi_vad, poradi_detail])

	# 3) reference: extrakt skills.mul + skillgrp.mul (tools/uoextract/textdata.py)
	var extrakt = Lib.json_at(EXTRACT_PATH)
	var ref_jmena: Array = []
	var ref_gid: Array = []
	var group_names: Array = []
	var header := -1
	if extrakt is Dictionary and extrakt.get("skills") is Array and extrakt.get("groups") is Dictionary:
		ref_jmena = extrakt["skills"]
		var groups: Dictionary = extrakt["groups"]
		ref_gid = groups.get("skill_groups", [])
		group_names = groups.get("names", [])
		header = int(groups.get("header", -1))
	t._check(ref_jmena.size() == COUNT and ref_gid.size() == COUNT,
		"data.skills: extrakt %s ma %d jmen ze skills.mul a %d skupinovych id (cekano %d/%d)"
		% [EXTRACT_PATH, ref_jmena.size(), ref_gid.size(), COUNT, COUNT])
	t._check(header == group_names.size() + 1 and not group_names.is_empty(),
		"data.skills: skillgrp.mul ma hlavicku %d = %d jmen + implicitni skupina 0 (ClassicUO: groups[0] = Miscellaneous)"
		% [header, group_names.size()])
	var jmena_vad := 0
	var jmena_detail := ""
	for i in mini(zaznamy.size(), ref_jmena.size()):
		if _s(zaznamy[i], "name") != str(ref_jmena[i]):
			jmena_vad += 1
			if jmena_detail == "":
				jmena_detail = "id %d: data '%s' vs skills.mul '%s'" % [i, _s(zaznamy[i], "name"), str(ref_jmena[i])]
	t._check(jmena_vad == 0 and zaznamy.size() == ref_jmena.size(),
		"data.skills: jmena a poradi sedi na skills.mul (%d vad; %s)" % [jmena_vad, jmena_detail])

	# 4) kotvy z docs/11 §11.1 (prvni, prostredni, Remove Trap, posledni)
	var kotvy := {0: "Alchemy", 25: "Magery", 48: "Remove Trap", 57: "Mysticism"}
	for i in kotvy.keys():
		var mam: bool = i < zaznamy.size()
		var jmeno := _s(zaznamy[i], "name") if mam else "<chybi>"
		t._check(mam and jmeno == kotvy[i],
			"data.skills: id %d = '%s' (docs/11 §11.1; namEReno '%s')" % [i, kotvy[i], jmeno])

	# 5) staty z research/02 §3.9 (podle JMENA - viz NALEZ 2 v hlavicce)
	var tabulka := _staty_z_research(_text(RESEARCH_PATH))
	t._check(tabulka.size() == COUNT,
		"data.skills: z research/02 §3.9 se nacetlo %d radku se staty (cekano %d)" % [tabulka.size(), COUNT])
	var bez_tabulky := 0
	var staty_vad := 0
	var staty_detail := ""
	for rec in zaznamy:
		var jmeno := _s(rec, "name")
		if not tabulka.has(jmeno):
			bez_tabulky += 1
			continue
		var cekane: Array = tabulka[jmeno]
		if _s(rec, "stat_primary") != str(cekane[0]) or _s(rec, "stat_secondary") != str(cekane[1]):
			staty_vad += 1
			if staty_detail == "":
				staty_detail = "%s: data %s/%s vs research/02 %s/%s" % [jmeno, _s(rec, "stat_primary"),
					_s(rec, "stat_secondary"), str(cekane[0]), str(cekane[1])]
	t._check(bez_tabulky == 0,
		"data.skills: kazde jmeno z data je i v tabulce research/02 §3.9 (%d chybi)" % bez_tabulky)
	t._check(staty_vad == 0,
		"data.skills: primarni/sekundarni stat sedi na research/02 §3.9 (%d vad; %s)" % [staty_vad, staty_detail])

	# 6) skupiny: id ze skillgrp.mul + 1-baznove mapovani id -> jmeno
	var misc := _skupina_misc(_text(RESEARCH_PATH))
	t._check(misc != "",
		"data.skills: z research/02 §7.3 se nacetlo jmeno implicitni skupiny 0 ('%s')" % misc)
	var gid_vad := 0
	var gid_detail := ""
	var nazev_vad := 0
	var nazev_detail := ""
	var misc_vad := 0
	for i in mini(zaznamy.size(), ref_gid.size()):
		var gid := int(ref_gid[i])
		if int(zaznamy[i].get("group_id", -1)) != gid:
			gid_vad += 1
			if gid_detail == "":
				gid_detail = "id %d: data %s vs skillgrp.mul %d" % [i, _s(zaznamy[i], "group_id"), gid]
		var cekany := misc if gid == 0 else str(group_names[gid - 1])
		if _s(zaznamy[i], "group") != cekany:
			nazev_vad += 1
			if nazev_detail == "":
				nazev_detail = "id %d: data '%s' vs skillgrp.mul '%s'" % [i, _s(zaznamy[i], "group"), cekany]
		if gid == 0:
			if _s(zaznamy[i], "group") != misc:
				misc_vad += 1
	t._check(gid_vad == 0, "data.skills: skupinove id sedi na skillgrp.mul (%d vad; %s)"
		% [gid_vad, gid_detail])
	t._check(nazev_vad == 0,
		"data.skills: nazev skupiny je 1-baznove mapovani id -> jmeno (%d vad; %s)" % [nazev_vad, nazev_detail])
	t._check(misc_vad == 0, "data.skills: skupina 0 se jmenuje '%s' (%d vad)" % [misc, misc_vad])

	# 7) implemented: mnozina se CTE z docs/05 §5.16 a ze zadani granule
	var dok_false := _false_z_dokumentu(_text(DOCS_ERA_PATH))
	t._check(dok_false.size() >= 7,
		"data.skills: z docs/05 §5.16 se nacetl seznam implemented:false (%d jmen: %s)"
		% [dok_false.size(), ", ".join(dok_false)])
	var prompt_false := _false_z_roadmapy(_text(ROADMAP_PATH))
	t._check(prompt_false.size() >= 7,
		"data.skills: ze zadani granule (.forge/roadmap.json) se nacetl seznam implemented:false (%d jmen: %s)"
		% [prompt_false.size(), ", ".join(prompt_false)])
	var data_false: Array = []
	for rec in zaznamy:
		if not bool(rec.get("implemented", true)):
			data_false.append(_s(rec, "name"))
	var chybi_v_datech: Array = []
	for jmeno in dok_false:
		if not data_false.has(jmeno):
			chybi_v_datech.append(jmeno)
	var navic: Array = []
	for jmeno in data_false:
		if not dok_false.has(jmeno):
			navic.append(jmeno)
	t._check(chybi_v_datech.is_empty() and navic.is_empty(),
		"data.skills: implemented:false je presne u mnoziny z docs/05 §5.16 (chybi %s; navic %s)"
		% [str(chybi_v_datech), str(navic)])
	var ze_zadani_chybi: Array = []
	for jmeno in prompt_false:
		if not data_false.has(jmeno):
			ze_zadani_chybi.append(jmeno)
	t._check(ze_zadani_chybi.is_empty(),
		"data.skills: 7 skillu ze zadani granule ma implemented:false (chybi %s)" % str(ze_zadani_chybi))
	var mimo_dokument: Array = []
	for jmeno in prompt_false:
		if not dok_false.has(jmeno):
			mimo_dokument.append(jmeno)
	t._check(mimo_dokument.is_empty(),
		"data.skills: zadani granule a docs/05 §5.16 si neodporuji v TOM, ktere skilly jsou false (mimo dokument %s)"
		% str(mimo_dokument))
	var extra: Array = []
	for jmeno in dok_false:
		if not prompt_false.has(jmeno):
			extra.append(jmeno)
	print("[test] data.skills: NALEZ - zadani uvadi %d skillu s implemented:false, docs/05 §5.16 uvadi %d (navic %s); data sleduji dokument"
		% [prompt_false.size(), dok_false.size(), str(extra)])
	var impl_vad := 0
	var impl_detail := ""
	for i in zaznamy.size():
		var ma_byt: bool = not dok_false.has(_s(zaznamy[i], "name"))
		if bool(zaznamy[i].get("implemented", not ma_byt)) != ma_byt:
			impl_vad += 1
			if impl_detail == "":
				impl_detail = "id %d %s" % [i, _s(zaznamy[i], "name")]
	t._check(impl_vad == 0, "data.skills: implemented sedi u vsech %d skillu (%d vad; %s)"
		% [COUNT, impl_vad, impl_detail])

	# 8) era z vety v research/02 §7.2 (dokument, ne opsana tabulka)
	var ery := _ery_z_research(_text(RESEARCH_PATH))
	t._check(ery.size() >= 9,
		"data.skills: z research/02 §7.2 se nacetla era pro %d pozdejsich skillu (cekano >=9)" % ery.size())
	var era_vad := 0
	var era_detail := ""
	for rec in zaznamy:
		var jmeno := _s(rec, "name")
		var cekana := str(ery.get(jmeno, ERA_CLASSIC))
		if _s(rec, "era") != cekana:
			era_vad += 1
			if era_detail == "":
				era_detail = "%s: data '%s' vs research/02 '%s'" % [jmeno, _s(rec, "era"), cekana]
	t._check(era_vad == 0, "data.skills: era sedi na research/02 §7.2 (%d vad; %s)" % [era_vad, era_detail])
	var soulad := 0
	for rec in zaznamy:
		if bool(rec.get("implemented", true)) == (_s(rec, "era") == ERA_CLASSIC):
			soulad += 1
	t._check(soulad == zaznamy.size(),
		"data.skills: implemented == (era == '%s') u vsech zaznamu (%d/%d)" % [ERA_CLASSIC, soulad, zaznamy.size()])
