extends RefCounted
# sim.combat Z POHLEDU HRACE (session D, 2026-10-11).
#
# PROC TENHLE TEST EXISTUJE: `tests/cases/combat.gd` meri prijimaci cisla
# (swing delay, 20 swingu -> 5 zasahu, ...) a vola `resolve_swing` PRIMO.
# Cestu HRACE - tedy `attack` prikaz, ktery klient posila pri kazdem stisku
# `A` nebo kliknuti na monstrum - nemeril nikdo. A presne v ni byly dve vady:
#   1. `attack` pokazde PREPSAL stav (`due_ms = 0`) a `_planuj` nastavil novy
#      cas, takze hrac, ktery macka `A` casteji nez je prodleva zbrane, NIKDY
#      neuderi. NamEReno sondou `_analyza/p58-smycka-hracem.gd`: 30 prikazu
#      `attack` za 51 s dalo **3 swingly** (2 minely, 1 zasah) - krysa s 6 hp
#      prezila 30 utoku.
#   2. Zurnal hlasil i UDER MONSTRA jako "You hit it for N damage." (hrac nema
#      `name`, takze `_jmeno` o nem vratilo "it"): hrac cetl, ze utoci on,
#      presne ve chvili, kdy mu padaly hp (namEReno: hp 87 -> 65 a v zurnalu
#      ctyri "You hit it..."). Vedet, kdo udeřil, je zaklad toho, aby clovek
#      umel rict, co se deje.
#
# Test meri CHOVANI, ne pritomnost metody:
#   A) prvni `attack` swing NAAPLANUJE (next_swing_ms = cas + prodleva),
#   B) druhy `attack` na STEJNY cil naplanovany cas NEPOSUNE (jen obnovi cil),
#   C) `attack` na JINY cil naplanuje znovu (novy boj = novy cas),
#   D) `set_war(false)` swing zrusi a dalsi `attack` ho zase naplanuje,
#   E) hlasky souboje rikaji, KDO udeřil (hracovi zasahy "You hit X", zasahy
#      do hrace "X hits you") - a to se pozna podle `set_player`.
#
# Cesta k modulu je VSTUP (`-- --combat-script=<cesta>`), aby sel merit mutant.

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RngScript = preload("res://core/rng.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const StatsScript = preload("res://sim/entity/stats.gd")
const ItemScript = preload("res://sim/entity/item.gd")

const COMBAT_SCRIPT := "res://sim/systems/combat.gd"
const WEAPONS_FIXTURE := "res://tests/fixtures/m5/weapons.json"
const ARMOR_FIXTURE := "res://tests/fixtures/m5/armor.json"

const SERIAL_A := 0x40000011
const SERIAL_B := 0x40000022
const SERIAL_C := 0x40000033
const DAGGER_ART := 3921

# Mapovani jmeno -> id je VSTUP (kontrakt M5 §5): test nezávisí na tom, co
# prave pise jina session do `data/skills.json`.
const SKILLS := {
	"Fencing": 42, "Wrestling": 43, "Tactics": 27, "Anatomy": 1,
	"Swordsmanship": 40, "Lumberjacking": 44,
}


class FakeEquipment:
	func at_layer(_m: int, _layer: int) -> int:
		return 0

	func bonus(_m: int, _key: String) -> int:
		return 0


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _mobil(registry, serial: int):
	var mob = MobileScript.new(serial, 400, Vector3i(10, 10, 0))
	mob.stats = StatsScript.new(100, 100, 100)
	mob.max_hp = 1000
	mob.hp = 1000
	mob.max_stam = 100
	mob.stam = 100
	registry.register(mob)
	return mob


func _nasad_zbran(items, mob) -> void:
	var item = ItemScript.new(0x5000 + int(mob.serial) % 1000,
		DAGGER_ART + ItemScript.ITEM_OFFSET, 1)
	item.layer = 1
	item.parent = int(mob.serial)
	items[int(item.serial)] = item
	mob.equip[1] = int(item.serial)


func run(t) -> void:
	var script = Lib.script_at(_arg("combat-script", COMBAT_SCRIPT))
	if script == null:
		t._pending("sim.combat NENI HOTOVY: " + COMBAT_SCRIPT + " chybi nebo se neparsuje")
		return
	var weapons = Lib.json_at(WEAPONS_FIXTURE)
	var armor = Lib.json_at(ARMOR_FIXTURE)
	if weapons == null:
		t._pending("fixture " + WEAPONS_FIXTURE + " chybi")
		return

	var registry = RegistryScript.new()
	var items: Dictionary = {}
	var clock = ClockScript.new()
	var rng = RngScript.new(1234)
	var events = EventsScript.new()
	var combat = script.new(registry, weapons, items, FakeEquipment.new(), SKILLS,
		rng, clock, events, null, WEAPONS_FIXTURE, ARMOR_FIXTURE,
		"res://data/balance.json", "res://data/skills.json", armor)
	_mobil(registry, SERIAL_A)
	_mobil(registry, SERIAL_B)
	_mobil(registry, SERIAL_C)
	_nasad_zbran(items, registry.get_mobile(SERIAL_A))

	# -- A) PRVNI ATTACK SWING NAAPLANUJE ---------------------------------
	var r1: Dictionary = combat.attack(SERIAL_A, SERIAL_B)
	var cas1: int = int(combat.state_of(SERIAL_A).get("next_swing_ms", -1))
	t._check(bool(r1.get("ok", false)) and cas1 > clock.now_ms(),
		"combat: prvni `attack` naplanuje swing do budoucnosti (ok %s, next_swing_ms %d, ted %d)"
			% [str(r1.get("ok", false)), cas1, clock.now_ms()])
	t._check(int(r1.get("planned", -1)) == 1,
		"combat: prvni `attack` vraci `planned: true` (vyslo %s)" % str(r1.get("planned", null)))

	# -- B) OPAKOVANY ATTACK NA STEJNY CIL CAS NEPOSUNE -------------------
	clock.advance(100)
	var r2: Dictionary = combat.attack(SERIAL_A, SERIAL_B)
	var cas2: int = int(combat.state_of(SERIAL_A).get("next_swing_ms", -1))
	t._check(cas2 == cas1,
		"combat: druhy `attack` na STEJNY cil neposune naplanovany swing (byl %d, ted %d)"
			% [cas1, cas2])
	t._check(bool(r2.get("ok", false)) and int(r2.get("target", 0)) == SERIAL_B,
		"combat: druhy `attack` dal plati na stejny cil (vyslo %s)" % str(r2))
	# Treti prikaz (hrac macka `A` porad) - porad se nesmi posunout.
	clock.advance(100)
	combat.attack(SERIAL_A, SERIAL_B)
	t._check(int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)) == cas1,
		"combat: ani treti `attack` na stejny cil swing neposune (namEReno %d)"
			% int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)))

	# -- C) JINY CIL = NOVY BOJ = NOVY CAS --------------------------------
	clock.advance(100)
	var r3: Dictionary = combat.attack(SERIAL_A, SERIAL_C)
	var cas3: int = int(combat.state_of(SERIAL_A).get("next_swing_ms", -1))
	t._check(cas3 > cas1 and int(r3.get("target", 0)) == SERIAL_C,
		"combat: `attack` na JINY cil naplanuje znovu (byl %d, ted %d, cil %d)"
			% [cas1, cas3, int(r3.get("target", 0))])
	# Zpet na puvodni cil: i to je zmena cile, takze novy cas.
	clock.advance(100)
	combat.attack(SERIAL_A, SERIAL_B)
	t._check(int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)) > cas3,
		"combat: navrat na puvodni cil je taky novy boj (namEReno %d)"
			% int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)))

	# -- D) SET_WAR(false) SWING ZRUSI A ATTACK HO ZASE NAAPLANUJE --------
	combat.set_war(SERIAL_A, false)
	t._check(int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)) == 0,
		"combat: `set_war(false)` zrusi naplanovany swing (namEReno %d)"
			% int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)))
	var r4: Dictionary = combat.attack(SERIAL_A, SERIAL_B)
	t._check(bool(r4.get("ok", false))
			and int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)) > clock.now_ms(),
		"combat: po zruseni swing znovu naplanuje (ok %s)" % str(r4.get("ok", false)))
	# Neznamy cil se porad hlasi (zadna ticha nula) - kontrola, ze se vetev
	# pro "jiny cil" nerozbila na cokoliv.
	var r5: Dictionary = combat.attack(SERIAL_A, 0xDEAD)
	t._check(not bool(r5.get("ok", false)) and str(r5.get("reason", "")) == "no_target",
		"combat: `attack` na neznamy cil vraci `no_target` (vyslo %s)" % str(r5))

	# -- E) ZURNAL RIKA, KDO UDERIL ---------------------------------------
	# Hrac (SERIAL_A) ma zbran a je nastaveny pres `set_player`; monstrum
	# (SERIAL_B) ma zbran taky. Hlasky se ctou z UDALOSTI, ne z kódu.
	# ⚠ CTYRI KONTROLY, NE DVE: kdyz se "zasah" a "minuti" sliji do jedne
	# podminky, mutace jedne z nich projde (namEReno: vraceny text "You hit it"
	# u zasahu monstra test NECHYTIL, protoze minuti hlasilo "%s swings at you"
	# dal) - presne "brana, ktera se pta na pritomnost jednoho ze dvou".
	_nasad_zbran(items, registry.get_mobile(SERIAL_B))
	combat.set_player(SERIAL_A)
	events.clear()
	var hrac_zasah: bool = false
	var hrac_minul: bool = false
	var monstrum_zasah: bool = false
	var monstrum_minul: bool = false
	for _i in 60:
		_mobil(registry, SERIAL_B).hp = int(_mobil(registry, SERIAL_B).max_hp)
		combat.resolve_swing(SERIAL_A, SERIAL_B)
		_mobil(registry, SERIAL_A).hp = int(_mobil(registry, SERIAL_A).max_hp)
		combat.resolve_swing(SERIAL_B, SERIAL_A)
	for u in events.drain():
		if str(u.get("name", "")) != "message":
			continue
		var text: String = str((u.get("data", {}) as Dictionary).get("text", ""))
		if text.begins_with("You hit "):
			hrac_zasah = true
		if text.begins_with("You swing at "):
			hrac_minul = true
		if text.contains(" hits you"):
			monstrum_zasah = true
		if text.contains(" swings at you"):
			monstrum_minul = true
	t._check(hrac_zasah, "combat: zasah HRACE se hlasi jako 'You hit ...'")
	t._check(hrac_minul, "combat: minuti HRACE se hlasi jako 'You swing at ...'")
	t._check(monstrum_zasah, "combat: zasah DO HRACE se hlasi jako '... hits you ...'")
	t._check(monstrum_minul, "combat: minuti MONSTRA se hlasi jako '... swings at you ...'")
	# Bez `set_player` (testy, hole `SimWorld`) se modul chova jako predtim -
	# zadna veta nesmi zaviset na tom, ze si hrac serial vymysli.
	combat.set_player(0)
	events.clear()
	for _i in 30:
		_mobil(registry, SERIAL_A).hp = int(_mobil(registry, SERIAL_A).max_hp)
		combat.resolve_swing(SERIAL_B, SERIAL_A)
	var bez_hrace: bool = true
	for u in events.drain():
		if str(u.get("name", "")) == "message" \
				and str(u["data"].get("text", "")).contains("hits you"):
			bez_hrace = false
	t._check(bez_hrace,
		"combat: bez `set_player` se 'hits you' NEHLASI (nevim != hrac)")
