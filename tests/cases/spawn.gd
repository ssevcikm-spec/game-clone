extends RefCounted
# sim.spawn - spawn monster a obnova (docs/04 §4.6.7, docs/05 §5.12,
# kontrakt M5 §3.5).
#
# Test meri PRESNA prijimaci cisla na REALNYCH datech (`data/spawns.json`
# a `data/monsters.json` - kontrakt M5 §3.4/§3.5 je zadava a soubory jsou
# hotove; kdyz chybi, test SPADNE):
#   * deficit `max((max - spawned)/3, 1)`: z prazdneho bodu (max 3) se postavi
#     **1** monstrum za cyklus,
#   * prodleva je z dat **5-10 min** (`delay_ms: [300000, 600000]`),
#   * PO ZABITI (mobil zmizi z registru - `sim.death` maze nehrace) se do
#     **10 minut** herniho casu obnovi,
#   * staty se losuji z ROZSAHU dat (`str/dex/int/hits`), `body`, `notoriety`,
#     `home` = bod spawnu, `ai.state == "idle"`, serial z `sim.next_serial()`,
#   * `state()`/`restore()` round-trip sedi (save/hash),
#   * `no_spawn_in_town` z dat je nactene a `region_check_source()` rika, ze se
#     NEVYNUCUJE (spawn nema regiony) - nikdy ticha napodobenina.
#
# Cesta k souboru je VSTUP: `-- --spawn-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const HashScript = preload("res://core/hash.gd")
const SimWorldScript = preload("res://sim/sim_world.gd")

const SPAWN_SCRIPT := "res://sim/world/spawn.gd"
const SPAWNS_DATA := "res://data/spawns.json"
const MONSTERS_DATA := "res://data/monsters.json"
const POINT_ID := "graveyard_britain"
const POINT_X := 1374
const POINT_Y := 1482
const POINT_RADIUS := 6
const POINT_MAX := 3
const SKILL_WRESTLING := 43
const SEED := 20261011


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _typ_na_zaznam(data) -> Dictionary:
	var out: Dictionary = {}
	if data is Array:
		for rec in data:
			if rec is Dictionary and str(rec.get("type", "")) != "":
				out[str(rec["type"])] = rec
	return out


func run(t) -> void:
	var cesta: String = _arg("spawn-script", SPAWN_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.spawn NENI HOTOVY: " + cesta + " chybi nebo se neparsuje")
		return
	var spawns_data = Lib.json_at(SPAWNS_DATA)
	var monsters_data = Lib.json_at(MONSTERS_DATA)
	if spawns_data == null or monsters_data == null:
		t._pending("data/spawns.json nebo data/monsters.json chybi")
		return
	var zaznamy := _typ_na_zaznam(monsters_data)

	# -- A) DATA: kazdy typ z spawns.json existuje v monsters.json ---------
	var chybejici: Array = []
	for p in (spawns_data as Dictionary).get("points", []):
		for typ in (p as Dictionary).get("monsters", []):
			if not zaznamy.has(str(typ)):
				chybejici.append(str(typ))
	t._check(chybejici.is_empty(),
		"kazdy typ z data/spawns.json je v data/monsters.json (chybi %s)" % str(chybejici))

	var sim = SimWorldScript.new(SEED, {})
	var spawn = script.new(sim.registry, sim, sim.clock(), sim.events(), sim.rng(),
		null, null)
	t._check(spawn.monsters_loaded(), "monstra z data/monsters.json se nacetla")
	t._check(spawn.point_count() == 1, "1 spawn bod (je %d)" % spawn.point_count())
	t._check(spawn.point_id(0) == POINT_ID,
		"bod 0 je '%s' (je '%s')" % [POINT_ID, spawn.point_id(0)])
	t._check(spawn.index_of(POINT_ID) == 0, "index_of('%s') == 0" % POINT_ID)
	t._check(spawn.no_spawn_in_town(),
		"data maji `no_spawn_in_town: true` (je %s)" % str(spawn.no_spawn_in_town()))
	t._check(str(spawn.region_check_source()).begins_with("none"),
		"`no_spawn_in_town` se NEVYNUCUJE a je to videt ('%s')" % spawn.region_check_source())
	t._check(spawn.config_tick_ms() == 10000,
		"tick_ms z dat je 10000 (je %d)" % spawn.config_tick_ms())

	# -- B) DEFICIT: z prazdneho bodu (max 3) jen 1 za cyklus --------------
	spawn.tick(0)
	t._check(spawn.alive_at(0) == 1,
		"deficit max((3-0)/3,1) = 1 monstrum za cyklus (je %d)" % spawn.alive_at(0))
	t._check(sim.registry.size() == 1, "registr ma 1 mobil (je %d)" % sim.registry.size())
	var ud = sim.drain_events()
	var nasel_added := false
	for e in ud:
		if str(e["name"]) == "mobile_added":
			nasel_added = true
	t._check(nasel_added, "spawn poslal mobil_added")

	# -- C) DOPLNENI DO MAX: kazdy cyklus ma prodlevu 5-10 min -------------
	var prodlevy: Array = []
	var cykly := 0
	while spawn.alive_at(0) < POINT_MAX and cykly < 10:
		var due: int = spawn.due_ms(0)
		var cekani: int = due - sim.world_time()
		prodlevy.append(cekani)
		if cekani > 0:
			sim.tick(cekani)
		spawn.tick(0)
		cykly += 1
	t._check(spawn.alive_at(0) == POINT_MAX,
		"bod se doplnil na max %d (je %d)" % [POINT_MAX, spawn.alive_at(0)])
	t._check(cykly == 2, "doplneni do max trvalo 2 cykly (deficit 1/3), je %d" % cykly)
	var prodleva_ok := true
	for c in prodlevy:
		if int(c) < 300000 or int(c) > 600000:
			prodleva_ok = false
	t._check(prodleva_ok, "kazda prodleva je v 5-10 min (%s)" % str(prodlevy))
	# ⚠ MUTACNI DIRA (namEReno 2026-10-11): test vyse projde i tehdy, kdyz je
	# prodleva ZAPSANA NAPEVNO (napr. vzdy 600000 = horni mez) - pak je sice
	# "v rozsahu", ale hra by nikdy nedoplnila driv nez za 10 min a `delay_ms`
	# z dat by se vubec nepouzila. Nahoda se proto meri na nekolika obnovech
	# ZIVOTA monstra: `due_ms` se smi posunout jen kdyz `tick()` opravdu
	# neco postavil (jinak by casovac utikal i v plnem bodu).
	# ⚠ `sim.tick()` se NESMI pouzit - `SimWorld` v sobe tickuje i `spawn`
	# (`SYSTEM_ORDER`), takze by se obnova provedla dvakrat. Cas se posouva
	# `clock().advance()` a `spawn.tick(0)` se vola rucne.
	#
	# ⚠ KAZDA OBVODA PRIDA DO REGISTRU NOVE MONSTRUM. Kdo by tuhle cast nechal
	# bez uklidu, rozbije tim pozdejsi sekce (namEReno 2026-10-11: "v registru
	# jsou 3 monstra (je 7)"). Sekce proto konci v PLNU (3 ziva) a s registrem
	# presne na tech 3 mobilech, ktere bod 0 vede.
	var prodlevy2: Array = []
	for _i in 4:
		var mob0 = sim.registry.get_mobile(int(_body_serial(spawn, 0)))
		if mob0 == null:
			prodlevy2.append(-1)
			continue
		mob0.hp = 0                        # "zabití" - presne to hlasi sim.death
		sim.clock().advance(600001)        # dost, aby byla obnova splatna
		spawn.tick(0)
		# Prodleva se meri od TECNEHO casu, ne od stareho `due_ms` (ten byl
		# v minulosti, takze by do rozdilu spadl i cely posun hodin).
		prodlevy2.append(spawn.due_ms(0) - sim.world_time())
	# Uklid: z registru zmizi vsechno, co bod 0 nevede (mrtva monstra se
	# z evidence bodu odstrani sama v `tick`).
	var zive: Dictionary = {}
	for row in (spawn.state().get("points", []) as Array):
		for m in ((row as Dictionary).get("mobiles", []) as Array):
			zive[int((m as Dictionary).get("serial", 0))] = true
	for mob in sim.registry.all():
		if not zive.has(int(mob.serial)):
			sim.registry.remove(int(mob.serial))
	var vsechny_ok := true
	for c in prodlevy2:
		if int(c) < 300000 or int(c) > 600000:
			vsechny_ok = false
	t._check(vsechny_ok, "kazda prodleva obnovy je v 5-10 min (%s)" % str(prodlevy2))
	var ruzne: Dictionary = {}
	for c in prodlevy2:
		ruzne[int(c)] = true
	t._check(ruzne.size() > 1,
		"prodleva se LOSUJE z rozsahu, neni zapsana napevno (ruznych %d z %d)"
		% [ruzne.size(), prodlevy2.size()])


	# -- D) STATY MONSTER JSOU Z DAT --------------------------------------
	var serialy: Array = []
	var vsechna_ok := true
	var neznamy_typ := ""
	for mob in sim.registry.all():
		serialy.append(int(mob.serial))
		# ⚠ NALEZ 2026-10-11: `Object.set()` na NEDEKLAROVANOU vlastnost v Godotu
		# 4 nic neudela (`entity.mobile` pole `type`/`damage`/`resist` nema), takze
		# data monstra jsou v `mob.ai["data"]`. Test to meri PRESNE - kdyby se
		# vratilo k `mob.get("type")`, vyslo by `<null>`.
		var data = (mob.ai as Dictionary).get("data", {})
		var typ: String = str((data as Dictionary).get("type", ""))
		if not zaznamy.has(typ):
			neznamy_typ = typ
			vsechna_ok = false
			continue
		var rec: Dictionary = zaznamy[typ]
		var hits = rec.get("hits", [0, 0])
		var wrest = (rec.get("skills", {}) as Dictionary).get("Wrestling", [0, 0])
		var dx: int = absi(int(mob.pos.x) - POINT_X)
		var dy: int = absi(int(mob.pos.y) - POINT_Y)
		if int(mob.body) != int(rec.get("body", -1)):
			vsechna_ok = false
		if int(mob.max_hp) < int(hits[0]) or int(mob.max_hp) > int(hits[1]):
			vsechna_ok = false
		if int(mob.hp) != int(mob.max_hp):
			vsechna_ok = false
		if int(mob.notoriety) != int(rec.get("notoriety", -1)):
			vsechna_ok = false
		if maxi(dx, dy) > POINT_RADIUS:
			vsechna_ok = false
		if str((mob.ai as Dictionary).get("state", "")) != "idle":
			vsechna_ok = false
		var w: int = int(mob.skills.value(SKILL_WRESTLING))
		if w < int(wrest[0]) or w > int(wrest[1]):
			vsechna_ok = false
		if mob.pos != (mob.ai as Dictionary).get("home", Vector3i.ZERO):
			vsechna_ok = false
		if not (data as Dictionary).has("damage") \
				or not (data as Dictionary).has("resist"):
			vsechna_ok = false
		if str((data as Dictionary).get("loot_pack", "")) != str(rec.get("loot_pack", "")):
			vsechna_ok = false
	t._check(vsechna_ok,
		"vsechna monstra maji staty z dat, home = bod a ai idle (neznamy typ '%s')" % neznamy_typ)
	t._check(sim.registry.all()[0].get("type") == null,
		"`mob.get(\"type\")` je null - `entity.mobile` pole nema (nalez 2026-10-11)")
	t._check(serialy.size() == POINT_MAX, "v registru jsou 3 monstra (je %d)" % serialy.size())
	t._check(serialy.size() == 3 and serialy[0] != serialy[1] and serialy[1] != serialy[2],
		"kazde monstrum ma svuj serial (%s)" % str(serialy))
	t._check(spawn.spawned_total() == POINT_MAX, "spawned_total() == 3")

	# -- E) PO ZABITI SE DO 10 MIN OBJEVI NOVE ----------------------------
	var obet: int = int(serialy[0])
	sim.registry.remove(obet)                # presne to dela `sim.death` pro nehrace
	spawn.tick(0)
	t._check(spawn.alive_at(0) == POINT_MAX - 1,
		"po smrti klesl pocet na %d (je %d)" % [POINT_MAX - 1, spawn.alive_at(0)])
	var t_kill: int = sim.world_time()
	var due2: int = spawn.due_ms(0)
	var cekani2: int = due2 - t_kill
	t._check(cekani2 >= 300000 and cekani2 <= 600000,
		"obnova je naplanovana za 5-10 min (%d ms)" % cekani2)
	spawn.tick(0)
	t._check(spawn.alive_at(0) == POINT_MAX - 1,
		"bez posunu casu se monstrum NEobnovi (je %d)" % spawn.alive_at(0))
	if cekani2 > 0:
		sim.tick(cekani2)
	spawn.tick(0)
	var obnova_ms: int = sim.world_time() - t_kill
	t._check(spawn.alive_at(0) == POINT_MAX,
		"po prodleve se monstrum obnovilo (je %d)" % spawn.alive_at(0))
	t._check(obnova_ms <= 600000,
		"obnova do 10 minut herniho casu (namEReno %d ms)" % obnova_ms)
	t._check(sim.registry.has_method("get_mobile") and sim.registry.get_mobile(obet) == null,
		"mrtvy serial uz v registru neni")

	# -- F) STATE/RESTORE ROUND-TRIP (save/hash) --------------------------
	var st1: Dictionary = spawn.state()
	t._check(int(st1.get("count", 0)) == 1, "state.count == 1")
	t._check((st1["points"][0]["mobiles"] as Array).size() == POINT_MAX,
		"state ma 3 mobily bodu (je %d)" % (st1["points"][0]["mobiles"] as Array).size())
	var spawn2 = script.new(sim.registry, sim, sim.clock(), sim.events(), sim.rng(),
		null, null)
	spawn2.restore(st1)
	var st2: Dictionary = spawn2.state()
	var h := HashScript.new()
	t._check(h.of_state([st1]) == h.of_state([st2]),
		"state()/restore() round-trip sedi")
	t._check(spawn2.alive_at(0) == spawn.alive_at(0),
		"po restore je stejny pocet zivych (%d vs %d)" % [spawn2.alive_at(0), spawn.alive_at(0)])
	t._check(spawn2.due_ms(0) == spawn.due_ms(0),
		"po restore sedi due_ms (%d vs %d)" % [spawn2.due_ms(0), spawn.due_ms(0)])


func _body_serial(spawn, index: int) -> int:
	# Serial N-teho monstra bodu 0 z `state()` - test tim meri "zive monstrum"
	# bez vlastni evidence (ta by byla druha pravda o stavu spawnu).
	var st: Dictionary = spawn.state()
	var body: Array = (st.get("points", []) as Array)
	if body.is_empty():
		return 0
	var mobiles: Array = (body[0] as Dictionary).get("mobiles", [])
	if index < 0 or index >= mobiles.size():
		return 0
	return int((mobiles[index] as Dictionary).get("serial", 0))
