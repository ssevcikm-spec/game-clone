extends RefCounted
# app.config - typovana konfigurace (docs/04 §4.2; soubor app/config.gd).
#
# CO SE MERI (docs/09 §9.4 - chovani, ne "soubor existuje"):
#   * `known_keys()` vraci VSECHNY klice ze `SCHEMA` (setridene) - kdyby vracel
#     jen data, nepoznalo by se, ktery klic v datech chybi,
#   * `get(key)` bere hodnotu z dat a u CHYBEJICIHO klice vrati default ze
#     `SCHEMA` (ne null, ne ticho),
#   * `get(neznamy)` vrati predany default a klic se NAHLASI (kontroluje se
#     navratova hodnota; varovani se neda chytit, ale chova se to jako vada),
#   * `check()` na REALNYCH datech (`data/balance.json`) nema co hlasit - to je
#     zaroven brana na to, ze se data a SCHEMA nerozejdou,
#   * `check()` na VLASTNIM fixture hlasi: chybejici klic, spatny typ, hodnotu
#     mimo rozsah, hodnotu mimo vycet a neznamy klic (preklep),
#   * `all()` vraci data ve stejnem tvaru, jaky dostava `SimWorld` (zanorena).
#
# Cesta k merenemu souboru je VSTUP (`-- --config-script=<cesta>`, konvence jako
# u `tests/cases/render_textures.gd`), aby mutacni test mohl predat mutanta.
# Fixture se pise do `.cache/test-config` a predava se ABSOLUTNI cestou: Godot
# resource filesystem soubor, ktery test teprve vytvoril, v headless rezimu
# nevidi (namEReno u `render.textures`).

const Lib = preload("res://tests/lib.gd")

const CONFIG_SCRIPT := "res://app/config.gd"
const BALANCE := "res://data/balance.json"
const SLUZKA := "res://.cache/test-config"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _zapis_fixture(obsah: Dictionary) -> String:
	var abs_slozka := ProjectSettings.globalize_path(SLUZKA)
	DirAccess.make_dir_recursive_absolute(abs_slozka)
	var f := FileAccess.open(abs_slozka + "/balance.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(obsah, "  "))
	f.close()
	return abs_slozka + "/balance.json"


func run(t) -> void:
	var cesta: String = _arg("config-script", CONFIG_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("app.config NENI HOTOV: " + cesta + " chybi nebo nejde nacist")
		return

	# 1) REALNA DATA: SCHEMA a `data/balance.json` musi sedet. Tohle je
	#    nejcennejsi kontrola celeho souboru - odhalí preklep i chybejici klic.
	var real = script.new(BALANCE)
	var chyby: Array = real.check()
	t._check(chyby.is_empty(),
		"app.config: realna data/balance.json sedi na SCHEMA (chyb %d: %s)"
			% [chyby.size(), str(chyby).substr(0, 160)])
	var klice: Array = real.known_keys()
	var schema: Dictionary = script.get_script_constant_map().get("SCHEMA", {})
	t._check(klice.size() == schema.size() and klice.size() > 0,
		"app.config: known_keys() vraci vsech %d klicu SCHEMA (namEReno %d)"
			% [schema.size(), klice.size()])
	var setridene: bool = true
	for i in range(1, klice.size()):
		if str(klice[i - 1]) > str(klice[i]):
			setridene = false
	t._check(setridene, "app.config: known_keys() je setrideny (%s)" % str(klice.slice(0, 4)))
	for klic in ["era.combat", "constants.SKILL_CAP", "ggs_on", "stat_gain.delay_ms",
			"player_start_stats.STR", "player_start_stats.DEX", "player_start_stats.INT"]:
		t._check(klice.has(klic), "app.config: known_keys() obsahuje '%s'" % klic)

	# 2) HODNOTA Z DAT + odkud je
	t._check(str(real.value("era.combat", "?")) == "aos" and real.source("era.combat") == "data",
		"app.config: era.combat z dat = aos (namEReno %s, source %s)"
			% [str(real.value("era.combat", "?")), real.source("era.combat")])
	t._check(int(real.value("constants.SKILL_CAP", -1)) == 7000,
		"app.config: constants.SKILL_CAP = 7000 (namEReno %s)"
			% str(real.value("constants.SKILL_CAP", -1)))

	# 3) `all()` je STEJNY TVAR jako JSON (app.main ho predava dal `SimWorld`)
	var vse: Dictionary = real.all()
	var era: Dictionary = vse.get("era", {})
	t._check(era.get("combat", "?") == "aos" and vse.has("constants"),
		"app.config: all() vraci zanorena data (era.combat = %s)" % str(era.get("combat")))
	var hodnoty: Dictionary = real.values()
	t._check(hodnoty.has("era.combat") and not hodnoty.has("era"),
		"app.config: values() je zplostely na teckove klice (%d klicu)" % hodnoty.size())

	# 4) NEZNAMY KLIC: vrati predany default (a hodi varovani - to je zadouci)
	t._check(real.value("neexistujici.klic", 42) == 42,
		"app.config: neznameho klice se vrati default (namEReno %s)"
			% str(real.value("neexistujici.klic", 42)))

	# 5) FIXTURE: vsechny DRUHY vad musi `check()` nahlasit
	var fixture: String = _zapis_fixture({
		"constants": {"SKILL_CAP": 7000, "STAT_CAP": "dveste"},
		"combat_era": "aos",
		"era": {"combat": "aos", "loot": "pre-aos", "content": "aos", "ui": "aos",
			"movement": "aos", "tooltips": "on"},
		"stat_gain": {"delay_ms": 999999, "chance_percent": 5},
		"stamina_drain_model": "run_only",
		"ggs_on": true, "insurance_on": false, "anti_macro": false,
		"preklep": true,
	})
	var f = script.new(fixture)
	var chyby2: Array = f.check()
	var text: String = str(chyby2)
	t._check(text.contains("constants.STAT_CAP") and text.contains("typ"),
		"app.config: spatny typ se hlasi (namEReno %s)" % text.substr(0, 200))
	t._check(text.contains("stat_gain.delay_ms") and text.contains("rozsah"),
		"app.config: hodnota mimo rozsah se hlasi (namEReno %s)" % text.substr(0, 200))
	t._check(text.contains("preklep"),
		"app.config: neznamy klic v datech se hlasi (namEReno %s)" % text.substr(0, 200))

	# 6) CHYBEJICI KLIC: default ze SCHEMA (ne null) a chyba v `check()`
	var prazdny = script.new(_zapis_fixture({"combat_era": "aos"}))
	var chyby3: Array = prazdny.check()
	t._check(f.value("neexistujici.klic", -1) == -1
		and str(prazdny.value("era.tooltips", "?")) == "on",
		"app.config: neznameho klice se vrati predany default, znameho chybejiciho "
		+ "default ze SCHEMA (namEReno %s)"
			% str(prazdny.value("era.tooltips", "?")))
	t._check(chyby3.size() >= 10 and int(prazdny.value("stat_gain.delay_ms", -1)) == 2000,
		"app.config: chybejici klice se hlasí a `value` vraci default ze SCHEMA "
		+ "(chyb %d, delay_ms %s)" % [chyby3.size(), str(prazdny.value("stat_gain.delay_ms"))])

	# 7) NEEXISTUJICI SOUBOR: check() to rekne, nic nespadne
	var chybi = script.new("res://.cache/test-config/neexistuje.json")
	var chyby4: Array = chybi.check()
	t._check(chyby4.size() == 1 and str(chyby4[0]).contains("nectou"),
		"app.config: chybejici soubor se hlasi (namEReno %s)" % str(chyby4))

	# 8) stats() je mereni, ne dekorace
	var st: Dictionary = real.stats()
	t._check(int(st.get("neznamych", -1)) == 0 and int(st.get("chyb", -1)) == 0
		and int(st.get("znamych", 0)) == schema.size(),
		"app.config: stats() realnych dat: znamych %s, neznamych %s, chyb %s"
			% [str(st.get("znamych")), str(st.get("neznamych")), str(st.get("chyb"))])
