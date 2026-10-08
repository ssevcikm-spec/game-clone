extends RefCounted
# sim.craft - vyroba, taveni, oprava (docs/04 §4.2, docs/05 §5.8,
# research/04 §6-§7).
#
# Pouziva REALNA data (`data/recipes.json`, `data/items.json`) a REALNY
# `entity.container`; nahrazuje jen to, co by melo merit neco jineho:
#   * `FakeRng` ridi DVA hody craftu (exceptionalita, uspech) i hod na
#     oslabeni pri oprave - proto jde zmERIT vsechny tri vysledky,
#   * `StubMap` dava kovadlinu a vyhen (role z `data/items.json`).
#
# Meri se: presna sance (`chances_for`), chybejici kovadlina -> "anvil",
# chybejici material -> "materials", maly skill -> "skill" (a NESPOTREBUJE),
# material se opravdu odecte, exceptionalita + znacka vyrobce, "Low (0) z
# vyroby NIKDY neprijde" (merene, ne predpokladane), taveni rudy 1:1 a jeho
# neuspech (pUleni), zpetne taveni 66 % a oprava vcetne oslabeni.
#
# Cesta k souboru je VSTUP: `-- --craft-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const ContainerScript = preload("res://sim/entity/container.gd")
const SkillGainScript = preload("res://sim/systems/skill_gain.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RngScript = preload("res://core/rng.gd")

const CRAFT_SCRIPT := "res://sim/systems/craft.gd"
const SERIAL := 0x40000077
const PACK := 0x00000088
const DAGGER := 114                  # recept `id 114` (`DefBlacksmithy.cs:454`)
const DAGGER_ART := 0x4F51           # 3921 (tiledata) + 0x4000
const INGOT_ART := 0x5BEF            # iron ingot 0x1BEF + 0x4000
const ORE_ART := 0x59B8
const FORGE_ART := 0x4FB1            # 0x0FB1 (role "forge") + 0x4000
const ANVIL_TILE := 0x0FAF           # tiledata id (role "anvil")
const FORGE_TILE := 0x0FB1
const HAMMER_ART := 0x53E3           # smith's hammer (role "smith hammer")
const SKILL_BLACKSMITHY := 7
const SKILL_MINING := 45

var _serial: int = 10000             # jedno misto, kde test vydava serialy


class StubMap:
	# Statiky po blocich s LOKALNIMI x,y (jako `world.map.statics_at`).
	var statics: Dictionary = {}

	func land_at(_x: int, _y: int) -> int:
		return 0

	func statics_at(x: int, y: int) -> Array:
		return statics.get(Vector2i(x, y), [])


class StubTiledata:
	# Stackovatelne je jen to, co je v UO stackovatelne (Generic 0x800);
	# bez toho by se nuz slil s dalsim nozem a mereni kvality by lhalo.
	const STACKABLE: Array = [0x5BEF, 0x59B8, 0x5BDD, 0x5BDE]

	func flags(tile: int) -> int:
		return 0x800 if tile in STACKABLE else 0

	func weight(_tile: int) -> int:
		return 0


class StubSerials:
	var hodnota: int = 5000

	func next_serial() -> int:
		hodnota += 1
		return hodnota


class FakeRng:
	# Fronta odpovedi na `chance()`; craft vola 1x exceptionalita, 1x uspech
	# (a pri oprave 1x oslabeni). Prazdna fronta vraci `default_result`.
	var results: Array = []
	var default_result: bool = false

	func chance(_p: float) -> bool:
		if results.is_empty():
			return default_result
		return bool(results.pop_front())

	func next_u32() -> int:
		return 0

	func range_i(a: int, _b: int) -> int:
		return a


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _statik(mapa, x: int, y: int, tile: int) -> void:
	var seznam: Array = mapa.statics.get(Vector2i(x, y), [])
	seznam.append({"tile": tile, "x": x % 8, "y": y % 8, "z": 0, "hue": 0})
	mapa.statics[Vector2i(x, y)] = seznam


func _pridej(kontejner, predmety: Dictionary, art: int, amount: int, hue: int = 0):
	# Vyda predmet, vlozi ho do batohu a zaregistruje podle serialu. Registruje
	# se i predmet, ktery se CELY sloucil s hromadou (`parent == 0`) - jinak by
	# ho `_item(serial)` nenasel a taveni by tvrdilo, ze ruda neni. Do poctu
	# (`_pocet_art`) se ale nepocita, protoze uz neni v batohu.
	_serial += 1
	var item = ItemScript.new(_serial, art, amount)
	item.hue = hue
	item.pos = Vector3i(100, 100, 0)
	kontejner.add(PACK, item)
	predmety[_serial] = item
	return item


func _pocet_art(predmety: Dictionary, art: int) -> int:
	var soucet: int = 0
	for serial in predmety:
		var item = predmety[serial]
		if int(item.parent) == PACK and int(item.tile) == art:
			soucet += int(item.amount)
	return soucet


func _sestav(t, rng = null, s_kovadlinou: bool = true) -> Array:
	# Vraci [craft, mobil, mapa, kontejner, predmety, skill_gain, rng];
	# prazdne pole = granule neni hotova (SELHANI, ne zelena).
	var cesta: String = _arg("craft-script", CRAFT_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.craft NENI HOTOVY: " + cesta + " chybi (nebo ma parse error)")
		return []
	var mapa := StubMap.new()
	if s_kovadlinou:
		_statik(mapa, 101, 100, ANVIL_TILE)
		_statik(mapa, 100, 101, FORGE_TILE)
	var tiledata := StubTiledata.new()
	var kontejner = ContainerScript.new(tiledata)
	var predmety: Dictionary = {}
	var serialy := StubSerials.new()
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var registry = RegistryScript.new()
	var nahoda = rng if rng != null else RngScript.new(23)
	var sg = SkillGainScript.new(registry, RngScript.new(31), clock, events)
	var mob = MobileScript.new(SERIAL, 400, Vector3i(100, 100, 0))
	mob.backpack = PACK
	registry.register(mob)
	sg.register(mob)
	var craft = script.new(kontejner, predmety, mapa, tiledata, sg, serialy, nahoda, clock,
		events, registry)
	return [craft, mob, mapa, kontejner, predmety, sg, nahoda]


func run(t) -> void:
	# -- A) sance se pocitaji PRESNE (a floor neni opsany) ---------------
	var a := _sestav(t)
	if a.is_empty():
		return
	var craft = a[0]
	var sg = a[5]
	t._check(craft.recipe_count() >= 1000,
		"sim.craft: nacteny recepty z data/recipes.json (namEReno %d)" % craft.recipe_count())
	var s_0: Dictionary = craft.chances_for(DAGGER, 0)
	t._check(is_equal_approx(float(s_0.get("chance", -1.0)), 0.008),
		"sim.craft: dagger pri skillu 0 ma sanci 0,008 = (0-(-4))/500 (namEReno %s)"
			% str(s_0.get("chance")))
	t._check(int(s_0.get("min_tenths", 0)) == -4 and int(s_0.get("max_tenths", 0)) == 496,
		"sim.craft: okno skillu daggeru je -0,4..49,6 (namEReno %d..%d)"
			% [int(s_0.get("min_tenths", 0)), int(s_0.get("max_tenths", 0))])
	var s_max: Dictionary = craft.chances_for(DAGGER, 496)
	t._check(is_equal_approx(float(s_max.get("chance", -1.0)), 1.0),
		"sim.craft: na maximalnim skillu je sance 1,0 (`val == max`, namEReno %s)"
			% str(s_max.get("chance")))
	t._check(float(s_0.get("exceptional_chance", 0.0)) < 0.0,
		"sim.craft: exceptionalita pri skillu 0 je zaporna (= nikdy, namEReno %s)"
			% str(s_0.get("exceptional_chance")))
	t._check(craft.material_tile(DAGGER, 0) == INGOT_ART,
		"sim.craft: material daggeru je iron ingot art 0x%X (namEReno 0x%X)"
			% [INGOT_ART, craft.material_tile(DAGGER, 0)])

	# -- B) bez kovadliny -> "anvil" -------------------------------------
	var b := _sestav(t, FakeRng.new(), false)
	if b.is_empty():
		return
	var bez_kovadliny: Dictionary = b[0].craft(SERIAL, DAGGER, 1)
	t._check(not bool(bez_kovadliny.get("ok", true)) and str(bez_kovadliny.get("reason", "")) == "anvil",
		"sim.craft: bez kovadliny vraci {ok:false, reason:'anvil'} (namEReno %s)" % str(bez_kovadliny))
	# Kovadlina jako PREDMET (server ji jako predmet ma; `map.statics_at` je jen
	# klientsky obraz) - bez tehle vetve by v mape bez kovadliny neslo vyrabet.
	var kovadlina = ItemScript.new(9100, 0x0FAF + 0x4000, 1)
	kovadlina.pos = Vector3i(101, 100, 0)
	b[4][9100] = kovadlina
	var vyhen = ItemScript.new(9101, 0x0FB1 + 0x4000, 1)
	vyhen.pos = Vector3i(100, 101, 0)
	b[4][9101] = vyhen
	_pridej(b[3], b[4], INGOT_ART, 3)
	b[6].results = [false, true]
	var s_predmety: Dictionary = b[0].craft(SERIAL, DAGGER, 1)
	t._check(bool(s_predmety.get("ok", false)),
		"sim.craft: kovadlina a vyhen jako PREDMETY staci (namEReno %s)" % str(s_predmety))

	# -- C) bez materialu -> "materials" (a nic se nespotrebuje) ---------
	var c := _sestav(t)
	if c.is_empty():
		return
	var bez_materialu: Dictionary = c[0].craft(SERIAL, DAGGER, 1)
	t._check(not bool(bez_materialu.get("ok", true))
		and str(bez_materialu.get("reason", "")) == "materials",
		"sim.craft: bez materialu vraci {ok:false, reason:'materials'} (namEReno %s)" % str(bez_materialu))
	t._check(c[0].craft(SERIAL, DAGGER, 1).get("item") == null,
		"sim.craft: z niceho se NEVYROBI predmet (zadny `item` v navratu)")

	# -- D) 3 ingoty + dost skillu -> dagger ------------------------------
	var d := _sestav(t, FakeRng.new())
	if d.is_empty():
		return
	var craft_d = d[0]
	var mob_d = d[1]
	var kontejner_d = d[3]
	var predmety_d = d[4]
	var rng_d = d[6]
	mob_d.skills.set_value(SKILL_BLACKSMITHY, 0)
	_pridej(kontejner_d, predmety_d, INGOT_ART, 3)
	rng_d.results = [false, true]        # 1. hod: bez exceptionality; 2. hod: uspech
	var vyroba: Dictionary = craft_d.craft(SERIAL, DAGGER, 1)
	t._check(bool(vyroba.get("ok", false)) and int(vyroba.get("made", 0)) == 1,
		"sim.craft: se 3 ingoty vznikne predmet (namEReno %s)" % str(vyroba))
	t._check(vyroba.get("item") != null and int(vyroba["item"].tile) == DAGGER_ART,
		"sim.craft: vysledek je art 0x%X (3921 + 0x4000, namEReno 0x%X)"
			% [DAGGER_ART, int(vyroba["item"].tile) if vyroba.get("item") != null else 0])
	t._check(int(vyroba.get("quality", -1)) == 1 and not bool(vyroba.get("exceptional", true)),
		"sim.craft: bez exceptionality je kvalita 1 = Normal (namEReno %s)" % str(vyroba.get("quality")))
	t._check(_pocet_art(predmety_d, INGOT_ART) == 0,
		"sim.craft: ingoty se opravdu odectly (zbyva %d)" % _pocet_art(predmety_d, INGOT_ART))
	t._check(d[5].mobile(SERIAL).skills.value(SKILL_BLACKSMITHY) > 0,
		"sim.craft: pasivni check zvedl skill (namEReno %d desetin)"
			% d[5].mobile(SERIAL).skills.value(SKILL_BLACKSMITHY))

	# -- E) neuspech: material zmizi, skill STALE roste -------------------
	var e := _sestav(t, FakeRng.new())
	if e.is_empty():
		return
	var craft_e = e[0]
	var kontejner_e = e[3]
	var predmety_e = e[4]
	var sg_e = e[5]
	e[6].results = [false, false]        # 1. hod: ne; 2. hod: neuspech
	_pridej(kontejner_e, predmety_e, INGOT_ART, 3)
	var pred_skillem: int = sg_e.mobile(SERIAL).skills.value(SKILL_BLACKSMITHY)
	var selhalo: Dictionary = craft_e.craft(SERIAL, DAGGER, 1)
	t._check(not bool(selhalo.get("ok", true)) and str(selhalo.get("reason", "")) == "failed"
		and int(selhalo.get("made", -1)) == 0,
		"sim.craft: neuspesny craft vraci {ok:false, reason:'failed'} (namEReno %s)" % str(selhalo))
	t._check(_pocet_art(predmety_e, INGOT_ART) == 0,
		"sim.craft: neuspech spotrebuje CELY material (namEReno %d)"
			% _pocet_art(predmety_e, INGOT_ART))
	t._check(sg_e.mobile(SERIAL).skills.value(SKILL_BLACKSMITHY) > pred_skillem,
		"sim.craft: skill roste I PRI NEUSPECHU (%d -> %d, dve nezavisle hody)"
			% [pred_skillem, sg_e.mobile(SERIAL).skills.value(SKILL_BLACKSMITHY)])

	# -- F) exceptionalita a znacka vyrobce ------------------------------
	var f := _sestav(t, FakeRng.new())
	if f.is_empty():
		return
	var craft_f = f[0]
	var mob_f = f[1]
	var predmety_f = f[4]
	f[6].results = [true, true]          # exceptionalita + uspech
	_pridej(f[3], predmety_f, INGOT_ART, 3)
	mob_f.skills.set_value(SKILL_BLACKSMITHY, 500)
	var dobry: Dictionary = craft_f.craft(SERIAL, DAGGER, 1)
	t._check(int(dobry.get("quality", -1)) == 2 and bool(dobry.get("exceptional", false)),
		"sim.craft: exceptionalita z PRVNIHO hodu da kvalitu 2 (namEReno %s)" % str(dobry.get("quality")))
	t._check(dobry.get("item") != null and not dobry["item"].props.has("maker"),
		"sim.craft: pod 100,0 skillu se znacka vyrobce NEDAVA (namEReno %s)"
			% str(dobry["item"].props if dobry.get("item") != null else {}))

	var g := _sestav(t, FakeRng.new())
	if g.is_empty():
		return
	var craft_g = g[0]
	var mob_g = g[1]
	var predmety_g = g[4]
	g[6].results = [true, true]
	_pridej(g[3], predmety_g, INGOT_ART, 3)
	mob_g.skills.set_value(SKILL_BLACKSMITHY, 1000)
	var mistr: Dictionary = craft_g.craft(SERIAL, DAGGER, 1)
	t._check(mistr.get("item") != null and int(mistr["item"].props.get("maker", -1)) == SERIAL,
		"sim.craft: od 100,0 skillu se znacka vyrobce ulozi do `props['maker']` (namEReno %s)"
			% str(mistr["item"].props if mistr.get("item") != null else {}))

	# -- G) maly skill -> "skill" a NESPOTREBUJE --------------------------
	var h := _sestav(t)
	if h.is_empty():
		return
	var craft_h = h[0]
	var predmety_h = h[4]
	var kandidat: int = -1
	for rec in craft_h.recipes_for(SERIAL, SKILL_BLACKSMITHY):
		if bool(rec.get("craftable", false)) and int(rec.get("min_skill", 0)) > 0:
			kandidat = int(rec["id"])
			break
	t._check(kandidat >= 0,
		"sim.craft: mezi blacksmith recepty je aspon jeden s min_skill > 0 (namEReno id %d)" % kandidat)
	if kandidat >= 0:
		_pridej(h[3], predmety_h, INGOT_ART, 50)
		var malo: Dictionary = craft_h.craft(SERIAL, kandidat, 1)
		t._check(not bool(malo.get("ok", true)) and str(malo.get("reason", "")) == "skill",
			"sim.craft: na recept s vetsim min_skill vraci `skill` (namEReno %s)" % str(malo))
		t._check(_pocet_art(predmety_h, INGOT_ART) == 50,
			"sim.craft: odmitnuty recept NESPOTREBUJE material (namEReno %d)"
				% _pocet_art(predmety_h, INGOT_ART))

	# -- H) `recipes_for` dava gumpu i NEDOSTUPNE recepty ------------------
	var i := _sestav(t)
	if i.is_empty():
		return
	var craft_i = i[0]
	i[1].skills.set_value(SKILL_BLACKSMITHY, 0)
	var seznam: Array = craft_i.recipes_for(SERIAL, SKILL_BLACKSMITHY)
	t._check(seznam.size() > 100,
		"sim.craft: `recipes_for` vraci recepty Blacksmithy (namEReno %d)" % seznam.size())
	var nedostupne: int = 0
	var nevyrobitelne: int = 0
	var ma_tile: bool = false
	for rec in seznam:
		if not bool(rec.get("available", true)):
			nedostupne += 1
		if not bool(rec.get("craftable", true)):
			nevyrobitelne += 1
		if int(rec.get("result_tile", -1)) == 3921:
			ma_tile = true
	t._check(nedostupne > 0,
		"sim.craft: nedostupne recepty jsou VIDET (`available: false`, namEReno %d)" % nedostupne)
	t._check(nevyrobitelne > 0,
		"sim.craft: recepty bez `tile` vysledku jsou `craftable: false` (namEReno %d)" % nevyrobitelne)
	t._check(ma_tile, "sim.craft: mezi recepty je dagger s `result_tile` 3921")
	t._check(craft_i.recipes_for(SERIAL, 999).is_empty(),
		"sim.craft: neznamy skill vraci prazdny seznam (nez ticha nula)")

	# -- I) taveni rudy: 1:1, neuspech pUli, gate podle kovu --------------
	var j := _sestav(t)
	if j.is_empty():
		return
	var craft_j = j[0]
	var mob_j = j[1]
	var predmety_j = j[4]
	var vyhen_j = _pridej(j[3], predmety_j, FORGE_ART, 1)
	vyhen_j.pos = Vector3i(101, 100, 0)
	var ruda = _pridej(j[3], predmety_j, ORE_ART, 10)
	mob_j.skills.set_value(SKILL_MINING, 0)
	var spatne: Dictionary = craft_j.smelt(SERIAL, int(ruda.serial), int(vyhen_j.serial))
	t._check(not bool(spatne.get("ok", true)) and int(spatne.get("left", 0)) == 5,
		"sim.craft: neuspesne taveni hromadku pUli (10 -> 5, namEReno %s)" % str(spatne))
	mob_j.skills.set_value(SKILL_MINING, 1000)
	# Jiny art nez prvni ruda (0x59B9 misto 0x59B8): jinak by se hromady
	# sloucily a taveni by meritelo prazdny predmet.
	var ruda2 = _pridej(j[3], predmety_j, 0x59B9, 10)
	var dobre: Dictionary = craft_j.smelt(SERIAL, int(ruda2.serial), int(vyhen_j.serial))
	t._check(bool(dobre.get("ok", false)) and int(dobre.get("ingots", 0)) == 10,
		"sim.craft: 10 rudy -> 10 ingotu (1:1, namEReno %s)" % str(dobre))
	t._check(_pocet_art(predmety_j, INGOT_ART) == 10,
		"sim.craft: ingoty jsou v batohu (namEReno %d)" % _pocet_art(predmety_j, INGOT_ART))
	var draha = _pridej(j[3], predmety_j, ORE_ART, 4, 0x973)   # dull copper: obtiznost 65
	mob_j.skills.set_value(SKILL_MINING, 600)
	var gate: Dictionary = craft_j.smelt(SERIAL, int(draha.serial), int(vyhen_j.serial))
	t._check(not bool(gate.get("ok", true)) and str(gate.get("reason", "")) == "no_skill",
		"sim.craft: barevna ruda pod ReqSkill vraci `no_skill` (namEReno %s)" % str(gate))

	# -- J) zpetne taveni: floor(0,66 * cena v ingotech) ------------------
	if vyroba.get("item") != null:
		var nuz = vyroba["item"]
		var vyhen_d = _pridej(kontejner_d, predmety_d, FORGE_ART, 1)
		vyhen_d.pos = Vector3i(101, 100, 0)
		mob_d.skills.set_value(SKILL_BLACKSMITHY, 1000)
		var zpetne: Dictionary = craft_d.smelt(SERIAL, int(nuz.serial), int(vyhen_d.serial))
		t._check(bool(zpetne.get("ok", false)) and int(zpetne.get("ingots", 0)) == 1,
			"sim.craft: zpetne taveni da floor(0,66 x 3) = 1 ingot (namEReno %s)" % str(zpetne))
	else:
		print("[test] sim.craft: zpetne taveni NEMERENO (dagger se nevyrobil)")

	# -- K) oprava: plna trvanlivost, oslabeni, uspech --------------------
	var k := _sestav(t, FakeRng.new())
	if k.is_empty():
		return
	var craft_k = k[0]
	var mob_k = k[1]
	var kontejner_k = k[3]
	var predmety_k = k[4]
	var nastroj = _pridej(kontejner_k, predmety_k, HAMMER_ART, 1)
	var cil = _pridej(kontejner_k, predmety_k, DAGGER_ART, 1)
	cil.max_durability = 60
	cil.durability = 20
	mob_k.skills.set_value(SKILL_BLACKSMITHY, 1000)
	k[6].results = [false]               # hod na oslabeni nepadne
	var oprava: Dictionary = craft_k.repair(SERIAL, int(nastroj.serial), int(cil.serial))
	t._check(bool(oprava.get("ok", false)) and int(oprava.get("durability", 0)) == 60,
		"sim.craft: oprava vrati plnou trvanlivost (namEReno %s)" % str(oprava))
	t._check(not bool(oprava.get("weakened", true)) and int(oprava.get("max_durability", 0)) == 60,
		"sim.craft: kdyz oslabeni nepadne, max. trvanlivost zustava 60 (namEReno %s)" % str(oprava))
	var plna: Dictionary = craft_k.repair(SERIAL, int(nastroj.serial), int(cil.serial))
	t._check(not bool(plna.get("ok", true)) and str(plna.get("reason", "")) == "full",
		"sim.craft: plna trvanlivost vraci `full` (namEReno %s)" % str(plna))
	cil.durability = 20
	k[6].results = [true]                # oslabeni padne
	var oslabena: Dictionary = craft_k.repair(SERIAL, int(nastroj.serial), int(cil.serial))
	t._check(bool(oslabena.get("weakened", false))
		and int(oslabena.get("max_durability", 0)) == 59,
		"sim.craft: oslabeni ubere 1 z MAX. trvanlivosti (60 -> 59, namEReno %s)" % str(oslabena))
	var mimo = ItemScript.new(99999, DAGGER_ART, 1)
	mimo.max_durability = 60
	mimo.durability = 10
	predmety_k[99999] = mimo
	var mimo_batoh: Dictionary = craft_k.repair(SERIAL, int(nastroj.serial), 99999)
	t._check(not bool(mimo_batoh.get("ok", true)) and str(mimo_batoh.get("reason", "")) == "not_in_pack",
		"sim.craft: predmet mimo batoh vraci `not_in_pack` (namEReno %s)" % str(mimo_batoh))

	# -- L) vsechny vysledky MERENE se seedem + "Low z vyroby neprijde" ---
	# Dve faze: na 25,0 skillu exceptionalita NEMUZE padnout (`chance - 0.6 < 0`,
	# research §6.3: "exceptional items impossible before ~60-65 skill"), na
	# 60,0 uz pada - a to je merene pravidlo, ne predpoklad.
	var l := _sestav(t)
	if l.is_empty():
		return
	var craft_l = l[0]
	var mob_l = l[1]
	var predmety_l = l[4]
	mob_l.skills.set_value(SKILL_BLACKSMITHY, 250)     # 50 % sance na uspech
	var uspechu: int = 0
	var neuspechu: int = 0
	var normalnich: int = 0
	var exceptionalnich: int = 0
	var low: int = 0
	for _pokus in 40:
		_pridej(l[3], predmety_l, INGOT_ART, 3)
		var r: Dictionary = craft_l.craft(SERIAL, DAGGER, 1)
		if not bool(r.get("ok", false)):
			neuspechu += 1
			continue
		uspechu += 1
		var kvalita: int = int(r.get("quality", -1))
		if kvalita == 2:
			exceptionalnich += 1
		elif kvalita == 1:
			normalnich += 1
		else:
			low += 1
	t._check(uspechu > 0 and neuspechu > 0,
		"sim.craft: se seedem padnou OBE strany (uspech %d, neuspech %d)" % [uspechu, neuspechu])
	t._check(normalnich > 0, "sim.craft: normalni kvalita padne (namEReno %d)" % normalnich)
	t._check(exceptionalnich == 0,
		"sim.craft: na 25,0 skillu exceptionalita NEMUZE padnout (namEReno %d, `chance - 0.6 < 0`)"
			% exceptionalnich)
	t._check(low == 0,
		"sim.craft: kvalita Low (0) z vyroby NIKDY neprijde (namEReno %d z 40)" % low)
	mob_l.skills.set_value(SKILL_BLACKSMITHY, 600)     # 100 % uspech, exceptionalita ~40 %
	var exceptionalnich2: int = 0
	for _pokus in 40:
		_pridej(l[3], predmety_l, INGOT_ART, 3)
		var r2: Dictionary = craft_l.craft(SERIAL, DAGGER, 1)
		if bool(r2.get("ok", false)) and int(r2.get("quality", -1)) == 2:
			exceptionalnich2 += 1
	t._check(exceptionalnich2 > 0,
		"sim.craft: na 60,0 skillu exceptionalita PADNE (namEReno %d ze 40)" % exceptionalnich2)

	# -- M) chybejici mobil / recept --------------------------------------
	t._check(str(craft_l.craft(0x1234, DAGGER, 1).get("reason", "")) == "no_mobile",
		"sim.craft: neznameho mobila vraci `no_mobile`")
	t._check(str(craft_l.craft(SERIAL, 99999, 1).get("reason", "")) == "no_recipe",
		"sim.craft: neznameho receptu vraci `no_recipe`")

	t._check(true, "sim.craft: case probehl cely (sentinel)")
