extends RefCounted
# sim.regen - regenerace hp/stam/mana (granule `sim.regen`, docs/04 §4.2,
# docs/05 §5.14, research/01 §1.4).
#
# Test meri CHOVANI s konkretnimi hodnotami (docs/09 §9.5), ne pritomnost metody:
#   * stamina ... +1 presne za 5000 ms (AoS `1/(0,1*(2+0))`;
#                 `_src/servuo/Scripts/Misc/RegenRates.cs:82-108`) = 12 bodu/min,
#   * hp ........ +1 presne za 10 000 ms (`RegenRates.cs:77-80`),
#   * mana ...... interval z INT/Meditation (AoS vetev, `RegenRates.cs:154-178`);
#                 pri INT 20 a Meditation 0 je to 4000 ms,
#   * strop ..... nikdy nad `max_*` (i po dvou minutach),
#   * mrtvy ..... neregeneruje (`Server/Mobile.cs:1909`),
#   * hlad ...... `sim.hunger` v repu NEEXISTUJE, proto `hunger_gate_on()` vraci
#                 false a hp se NEMERI (zadna ticha napodobenina); se stubem
#                 hladu 0 je interval hp 2x delsi (rozhodnuti klonu,
#                 research/01:1774-1782) a stamina to nezpomali.
#
# Cesta k souboru je VSTUP: `-- --regen-script=<cesta>` - mutacni harness tim
# dokazuje, ze test meri opravdu ten soubor a ne vychozi.

const Lib = preload("res://tests/lib.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const ClockScript = preload("res://core/clock.gd")

const MOBILE_SCRIPT := "res://sim/entity/mobile.gd"
const STATS_SCRIPT := "res://sim/entity/stats.gd"
const REGEN_SCRIPT := "res://sim/systems/regen.gd"
const SERIAL := 7
const STAM_MS := 5000
const HITS_MS := 10000
const MANA_MS_INT20 := 4000


class StubHunger:
	# Nahrazuje `sim.hunger` (modul v repu neni); `level` je jeji smlouva
	# (docs/04 §4.2). Stupnice neni zmerena, proto test meri jen prah <= 0.
	var _uroven: int = 0

	func _init(uroven: int) -> void:
		_uroven = uroven

	func level(_m: int) -> int:
		return _uroven

	func eat(_m: int, _item: int) -> bool:
		return true


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _mobil(mob_script, stats_script, serial: int, sila: int, obratnost: int, inteligence: int):
	# Realny mobil (maxima jdou ze statu, docs/04 §4.2) - nic se nepodstrkuje.
	# Serial je VSTUP: akumulatory regenu jsou podle serialu, takze dva mobily
	# se stejnym serialem by si je predaly (a mereni by lhalo).
	var mob = mob_script.new(serial, 400, Vector3i(100, 100, 0))
	mob.stats = stats_script.new(sila, obratnost, inteligence)
	mob.max_hp = mob.stats.hits_max()
	mob.max_stam = mob.stats.stam_max()
	mob.max_mana = mob.stats.mana_max()
	# ZIVY mobil s polovinou hp (mrtvy neregeneruje - viz sekce H), stamina
	# a mana prazdne, aby se doplnovani dalo merit presne.
	mob.hp = mob.max_hp / 2
	mob.stam = 0
	mob.mana = 0
	return mob


func run(t) -> void:
	var cesta: String = _arg("regen-script", REGEN_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.regen NENI HOTOVA: " + cesta + " chybi nebo se neparsuje")
		return
	var mob_script = Lib.script_at(MOBILE_SCRIPT)
	var stats_script = Lib.script_at(STATS_SCRIPT)
	if mob_script == null or stats_script == null:
		t._pending("sim.regen NEMEREN: %s nebo %s nejde nacist" % [MOBILE_SCRIPT, STATS_SCRIPT])
		return
	# API musi byt CELE: chybejici metoda by case shodila s 0 kontrolami a mutace
	# by prosla jako slepa (viz hlavicka `mutace-tests.py`).
	var sonda = script.new()
	var chybi: Array[String] = []
	for metoda in ["tick", "hunger_gate_on"]:
		if not sonda.has_method(metoda):
			chybi.append(metoda)
	if not chybi.is_empty():
		t._check(false, "sim.regen: chybi metody %s - case se neda merit" % str(chybi))
		return

	var reg = RegistryScript.new()
	var clock = ClockScript.new()
	var mob = _mobil(mob_script, stats_script, SERIAL, 75, 10, 20)   # STR 75, DEX 10, INT 20
	reg.register(mob)
	var regen = script.new(reg, clock)

	# A) CHYBEJICI ZAVISLOST JE VIDET (sim.hunger v repu neni)
	t._check(regen.hunger_gate_on() == false,
		"sim.regen: bez sim.hunger je hlad NEMERENY (hunger_gate_on false)")

	# B) TIK BEZ CASU NIC NEMENI (zadny fantom bod)
	var stav_pred: Array = [mob.hp, mob.stam, mob.mana]
	regen.tick()
	t._check(mob.hp == stav_pred[0] and mob.stam == stav_pred[1] and mob.mana == stav_pred[2],
		"sim.regen: prvni tick bez uplynuleho casu nic nemeni (hp %d, stam %d, mana %d)"
			% [mob.hp, mob.stam, mob.mana])

	# C) STAMINA: +1 presne na hranici 5000 ms
	clock.advance(STAM_MS - 1)
	regen.tick()
	var stam_pred: int = mob.stam
	clock.advance(1)
	regen.tick()
	t._check(stam_pred == 0 and mob.stam == 1,
		"sim.regen: stamina +1 po 5000 ms (po 4999 = %d, po 5000 = %d)" % [stam_pred, mob.stam])

	# D) RYCHLOST STAMINY: 60 s = 12 bodu (mereny interval, ne dojem)
	var mob2 = _mobil(mob_script, stats_script, SERIAL + 1, 75, 200, 20)
	reg.register(mob2)
	clock.advance(60000)
	regen.tick()
	t._check(mob2.stam == 12,
		"sim.regen: za 60 s se doplni 12 bodu staminy (namEReno %d)" % mob2.stam)

	# E) HP: +1 presne na hranici 10 000 ms
	var mob3 = _mobil(mob_script, stats_script, SERIAL + 2, 75, 10, 20)
	reg.register(mob3)
	clock.advance(HITS_MS - 1)
	regen.tick()
	var hp_pred: int = mob3.hp
	clock.advance(1)
	regen.tick()
	t._check(mob3.hp == hp_pred + 1 and hp_pred < mob3.max_hp,
		"sim.regen: hp +1 po 10 000 ms (po 9999 = %d, po 10 000 = %d)"
			% [hp_pred, mob3.hp])

	# F) MANA roste u INT > 0 (prijimaci kriterium roadmapy) - interval 4000 ms
	var mob4 = _mobil(mob_script, stats_script, SERIAL + 3, 75, 10, 20)
	reg.register(mob4)
	clock.advance(MANA_MS_INT20 - 1)
	regen.tick()
	var mana_pred: int = mob4.mana
	clock.advance(1)
	regen.tick()
	t._check(mana_pred == 0 and mob4.mana == 1,
		"sim.regen: mana +1 po 4000 ms pri INT 20 (po 3999 = %d, po 4000 = %d)"
			% [mana_pred, mob4.mana])
	clock.advance(MANA_MS_INT20)
	regen.tick()
	t._check(mob4.mana == 2,
		"sim.regen: po 8000 ms ma mana 2 (namEReno %d)" % mob4.mana)
	# INT 0 = max_mana 0: mana zustava 0 (neni co doplnovat) - nula je videt
	var mob0 = _mobil(mob_script, stats_script, SERIAL + 4, 75, 10, 0)
	reg.register(mob0)
	clock.advance(100000)
	regen.tick()
	t._check(mob0.max_mana == 0 and mob0.mana == 0,
		"sim.regen: u INT 0 je max_mana 0 a mana zustava 0 (namEReno %d/%d)"
			% [mob0.mana, mob0.max_mana])

	# G) STROP: ani po dvou minutach se nic nedostane nad max
	var mob5 = _mobil(mob_script, stats_script, SERIAL + 5, 75, 10, 20)
	mob5.hp = mob5.max_hp
	mob5.stam = mob5.max_stam
	mob5.mana = mob5.max_mana
	reg.register(mob5)
	clock.advance(120000)
	regen.tick()
	t._check(mob5.hp == mob5.max_hp and mob5.stam == mob5.max_stam and mob5.mana == mob5.max_mana,
		"sim.regen: nikdy nad max (hp %d/%d, stam %d/%d, mana %d/%d)"
			% [mob5.hp, mob5.max_hp, mob5.stam, mob5.max_stam, mob5.mana, mob5.max_mana])

	# H) MRTVY neregeneruje (`Mobile.cs:1909`)
	var mob6 = _mobil(mob_script, stats_script, SERIAL + 6, 75, 200, 20)
	mob6.hp = 0                       # mrtvy: ani hp, ani stam, ani mana
	reg.register(mob6)
	clock.advance(600000)
	regen.tick()
	t._check(mob6.hp == 0 and mob6.stam == 0 and mob6.mana == 0,
		"sim.regen: mrtvy mobil neregeneruje (hp %d, stam %d, mana %d)"
			% [mob6.hp, mob6.stam, mob6.mana])

	# I) HLAD: se stubem hladu 0 je hp interval 2x delsi, stamina zustava 5 s
	var reg2 = RegistryScript.new()
	var mobh = _mobil(mob_script, stats_script, SERIAL + 7, 75, 200, 20)
	reg2.register(mobh)
	var clock2 = ClockScript.new()
	var hladovy = script.new(reg2, clock2, StubHunger.new(0))
	t._check(hladovy.hunger_gate_on() == true,
		"sim.regen: se stubem hladu je hlad MERENY (hunger_gate_on true)")
	var hp_start: int = mobh.hp
	var hp_hlad: int = 0
	clock2.advance(HITS_MS)
	hladovy.tick()
	hp_hlad = mobh.hp
	var stam_hlad: int = mobh.stam
	clock2.advance(HITS_MS)
	hladovy.tick()
	t._check(hp_hlad == hp_start and mobh.hp == hp_start + 1,
		"sim.regen: vyhladovely (level 0) ma hp 2x pomalejsi (start %d, po 10 s = %d, po 20 s = %d)"
			% [hp_start, hp_hlad, mobh.hp])
	t._check(stam_hlad == 2 and mobh.stam == 4,
		"sim.regen: hlad zpomaluje JEN hp - stamina je +2 za 10 s (namEReno %d, pak %d)"
			% [stam_hlad, mobh.stam])

	# J) NAJEDENY (level 6) ma hp interval 10 s - hlad se nesmi aplikovat vzdy
	var reg3 = RegistryScript.new()
	var mobn = _mobil(mob_script, stats_script, SERIAL + 8, 75, 10, 20)
	reg3.register(mobn)
	var clock3 = ClockScript.new()
	var nasyceny = script.new(reg3, clock3, StubHunger.new(6))
	var hp_nasyceny: int = mobn.hp
	clock3.advance(HITS_MS)
	nasyceny.tick()
	t._check(mobn.hp == hp_nasyceny + 1,
		"sim.regen: pri hladu 6 ma hp interval 10 s (start %d, namEReno hp %d)"
			% [hp_nasyceny, mobn.hp])

	# DUKAZ PRO ROZHODNUTI O PROTEZE (data/balance.json, meni jina granule):
	# `player_start_stats.DEX = 130` dava max_stam 130, ale regenerace doplni
	# jen 12 bodu/min pri 5 s intervalu (`RegenRates.cs:82-108`); trvala oprava
	# protezy je tedy ve SPOTREBE (vaha, `WeightOverloading.cs:109-120`), ne v DEX.
	print("[test]      mereno (regen): 1 bod staminy / %d ms = 12/min; hp 1/%d ms; "
		% [STAM_MS, HITS_MS], "mana 1/%d ms pri INT 20; DEX 130 dava max_stam 130" % MANA_MS_INT20)
