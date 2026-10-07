extends RefCounted
# entity.item - predmet (docs/04 §4.2 a tvar dat §4.5).
#
# Test meri TVAR DAT a to, co predmet sam muze drzet:
#   * vychozi hodnoty a to, ze `_init(serial, tile, amount)` je opravdu nastavi,
#   * `parent == 0` = na zemi a jen tam plati `pos` (`is_on_ground()`),
#   * `pile_weight(unit)` = jednotkova vaha x mnozstvi (vaha hromady),
#   * `same_pile` = stejny `tile` + `hue` (kandidat na slouceni; jestli je
#     predmet stackovatelny, vi az `entity.container` z tiledata).
#
# Cesta k souboru je VSTUP: `-- --item-script=<cesta>` - mutacni harness
# (tools/gates/mutace-tests.py) tim dokazuje, ze test meri opravdu ten soubor.

const Lib = preload("res://tests/lib.gd")
const ITEM_SCRIPT := "res://sim/entity/item.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func run(t) -> void:
	var cesta: String = _arg("item-script", ITEM_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.entity.item NENI HOTOVY: " + cesta + " chybi (nebo nejde nacist)")
		return

	# 1) TVAR: pole z docs/04 §4.5 (a `quality` navic proti tabulce §4.2)
	var zlato = script.new(0x40000001, 0x0EED, 5)
	t._check(zlato.serial == 0x40000001 and zlato.tile == 0x0EED and zlato.amount == 5,
		"sim.entity.item: _init(serial, tile, amount) nastavi vsechny tri")
	t._check(zlato.hue == 0 and zlato.parent == 0 and zlato.layer == 0 and zlato.flags == 0,
		"sim.entity.item: hue/parent/layer/flags zacinaji na 0")
	t._check(zlato.durability == 0 and zlato.max_durability == 0 and zlato.quality == 1,
		"sim.entity.item: durability/max_durability zacinaji na 0, quality na 1 = Normal (Low 0 / Normal 1 / Exceptional 2, rozhodnuti 2026-10-07)")
	t._check(zlato.props is Dictionary and zlato.props.is_empty(),
		"sim.entity.item: props je slovnik (AoS properties)")
	t._check(zlato.pos is Vector3i and zlato.pos == Vector3i.ZERO,
		"sim.entity.item: pos je Vector3i")

	# 2) NA ZEMI vs V KONTEJNERU: `pos` plati jen na zemi
	t._check(zlato.is_on_ground(), "sim.entity.item: novy predmet je na zemi (parent 0)")
	zlato.pos = Vector3i(1495, 1630, 5)
	zlato.parent = 0x40000009
	t._check(not zlato.is_on_ground(),
		"sim.entity.item: predmet v kontejneru neni na zemi (parent != 0)")
	zlato.parent = 0
	t._check(zlato.is_on_ground() and zlato.pos == Vector3i(1495, 1630, 5),
		"sim.entity.item: na zemi plati pos (v kontejneru se nebere)")

	# 3) VAHA HROMADY: jednotkova vaha x mnozstvi
	var mec = script.new(0x40000002, 0x0F61, 3)
	t._check(mec.pile_weight(7) == 21,
		"sim.entity.item: 3 kusy po 7 stones = 21 (vyslo %d)" % mec.pile_weight(7))
	t._check(mec.pile_weight(0) == 0,
		"sim.entity.item: jednotkova vaha 0 da 0 (vyslo %d)" % mec.pile_weight(0))
	mec.amount = 1
	t._check(mec.pile_weight(7) == 7,
		"sim.entity.item: jedna vec vazi jednotkovou vahu (vyslo %d)" % mec.pile_weight(7))

	# 4) SAME_PILE: stejny tile + hue (kandidat na slouceni)
	var druhy = script.new(0x40000003, 0x0F61, 3)
	t._check(mec.same_pile(druhy) and druhy.same_pile(mec),
		"sim.entity.item: stejny tile a hue = kandidat na slouceni")
	druhy.hue = 1002
	t._check(not mec.same_pile(druhy),
		"sim.entity.item: jina hue se neslucuje (i kdyz je tile stejny)")
	druhy.hue = 0
	druhy.tile = 0x0F52
	t._check(not mec.same_pile(druhy), "sim.entity.item: jiny tile se neslucuje")
	t._check(not mec.same_pile(null), "sim.entity.item: same_pile(null) je false (ne pad)")
	druhy.tile = 0x0F61
	druhy.amount = 0
	t._check(not mec.same_pile(druhy),
		"sim.entity.item: prazdna hromada neni kandidat na slouceni")

	# 5) VYCHOZI KONSTRUKTOR: predmet bez argumentu ma vychozi tvar
	var holy = script.new()
	t._check(holy.serial == 0 and holy.tile == 0 and holy.amount == 1,
		"sim.entity.item: new() da serial 0, tile 0 a amount 1")
