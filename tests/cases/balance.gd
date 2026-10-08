extends RefCounted
# data.balance - vyvazeni a ery (docs/05 §5.16).
# Kriterium: hodnoty z promptu granule + kazda ma uvedeny zdroj, a dvojice
# hodnot, ktere jsou i v core/const.gd, se musi shodovat (docs/08 §8.3 - kdyz
# dva zdroje tvrdi totеz, musi to byt totеz).

const Lib = preload("res://tests/lib.gd")

const WANT := {
	"combat_era": "aos",
	"stamina_drain_model": "run_only",
	"ggs_on": true,
	"insurance_on": false,
	"anti_macro": false,
}


func run(t) -> void:
	var data = Lib.json_at("res://data/balance.json")
	if not (data is Dictionary):
		t._pending("data.balance NENI HOTOVA: data/balance.json chybi nebo neni JSON objekt")
		return
	for key in WANT.keys():
		t._check(data.get(key) == WANT[key],
			"data.balance: %s == %s (namEReno %s)" % [key, str(WANT[key]), str(data.get(key))])

	var constants: Dictionary = data.get("constants", {})
	t._check(constants.get("SKILL_CAP") == 7000,
		"data.balance: skill_cap == 7000 desetin (namEReno %s)" % str(constants.get("SKILL_CAP")))
	t._check(constants.get("STAT_CAP") == 225,
		"data.balance: stat_cap == 225 (namEReno %s)" % str(constants.get("STAT_CAP")))

	var consts: Dictionary = Lib.consts_at("res://core/const.gd")
	t._check(constants.get("SKILL_CAP") == consts.get("SKILL_CAP"),
		"data.balance: SKILL_CAP se shoduje s core/const.gd (%s vs %s)" % [str(constants.get("SKILL_CAP")), str(consts.get("SKILL_CAP"))])
	t._check(constants.get("STAT_CAP") == consts.get("STAT_CAP"),
		"data.balance: STAT_CAP se shoduje s core/const.gd (%s vs %s)" % [str(constants.get("STAT_CAP")), str(consts.get("STAT_CAP"))])

	var sources: Dictionary = data.get("sources", {})
	for key in WANT.keys():
		t._check(sources.has(key) and str(sources[key]) != "",
			"data.balance: %s ma v 'sources' uvedeny zdroj (docs/05 §5.16)" % key)

	# POCATECNI STATY HRACE (19. session, vada V3 ze zadani 19). Kontroluje se
	# TROJE, protoze kazda cast ma jiny duvod:
	#   * hodnoty existuji a DEX je 130 (rozhodnuti uzivatele),
	#   * `max_stam = DEX` plati dal - vetsi DEX je PROZATIMNI nahrada za
	#     nehotovou `sim.regen`, ne zmena modelu staminy,
	#   * kazda hodnota ma v 'sources' zapsany zdroj (cislo bez puvodu se neda
	#     za pul roku obhajit - docs/09 §9.4).
	var start: Dictionary = data.get("player_start_stats", {})
	t._check(int(start.get("STR", 0)) == 75 and int(start.get("DEX", 0)) == 130
		and int(start.get("INT", 0)) == 20,
		"data.balance: player_start_stats 75/130/20 (namEReno %s)" % str(start))
	var stats_script = Lib.script_at("res://sim/entity/stats.gd")
	if stats_script != null:
		var stats = stats_script.new(int(start.get("STR", 10)), int(start.get("DEX", 10)),
			int(start.get("INT", 10)))
		t._check(stats.stam_max() == int(start.get("DEX", 0))
			and stats.stam_max() == 130,
			"data.balance: max_stam = DEX (namEReno %d)" % stats.stam_max())
	for key in ["player_start_stats.STR", "player_start_stats.DEX", "player_start_stats.INT"]:
		t._check(sources.has(key) and str(sources[key]) != "",
			"data.balance: %s ma v 'sources' uvedeny zdroj" % key)
	t._check(str(start.get("note", "")) != "",
		"data.balance: player_start_stats ma 'note' s duvodem (PROZATIMNI)")

	# KDO TY STATY OPRAVDU POUZIJE (19. session): musi to byt `app.main`.
	# BRANA SE PTÁ NA CHOVÁNÍ, NE NA SOUBOR (docs/09 §9.4): hledá se VOLÁNÍ
	# `_start_stats()` a to, že funkce hodnoty bere z `config` - ne jen to, ze
	# soubor existuje. Kdyby se staty vracely na 10/10/10, spadne to tady.
	# (Chovani hry se meri ve hre - `app.main` nema test case; tohle je staticka
	# cast dokladu a je to receno, ne zamlceno.)
	var main_src: String = Lib.text_at("res://app/main.gd")
	t._check(main_src.contains("_start_stats()"),
		"data.balance: app.main pouziva player_start_stats (nalezeno volani _start_stats)")
	t._check(main_src.contains("player_start_stats.DEX"),
		"data.balance: app.main bere DEX z data/balance.json, ne z opsaneho cisla")
