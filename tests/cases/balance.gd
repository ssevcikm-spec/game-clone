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
