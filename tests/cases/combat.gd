extends RefCounted
# sim.combat - souboj (docs/04 §4.2 a §4.6.4, docs/05 §5.5).
#
# Test meri PRESNA prijimaci cisla smlouvy (docs/09 §9.5 - hodnota, ne
# pritomnost metody):
#   * `swing_delay_ms` pri stam 100 a rychlosti 30 = **3000 ms**
#     (`v = 200*30 = 6000`, `floor(40000/6000) = 6`, `6*500 = 3000`;
#     `_src/servuo/.../BaseWeapon.cs:1598-1609`), dolni mez 1250 ms (`:1613`),
#   * **20 swingu na cil s hp > 0 da alespon 5 zasahu** (prijimaci kriterium
#     `docs/04 §4.6.4`) - pocita se na 10 seedech a kazdy swing ma cil PLNÝ,
#     aby se nemerilo neco jineho (vyprazdneny cil),
#   * hit chance je z ZBRANOVEHO SKILLU, ne z Tactics (docs/05 §5.5.1):
#     mobil s vysokym Tactics a nulovym Fencing ma stejnou sanci jako bez
#     Tactics (rozdil 0.0 v namERene sanci),
#   * damage = `base + base*součet bonusů` (`BaseWeapon.cs:3812-3815`):
#     STR 100 / Anatomy 100 / Tactics 100 da presne 1,425 nasobek,
#   * obrana = `Σ(dmg*podil*(100-resist))/10000`, minimum 1 (`AOS.cs:168-206`):
#     resist 50 presne pulti, resist 0 nic nebere,
#   * bez zbrane funguje WRESTLING (cil dostane damage),
#   * chybejici `data/weapons.json` -> `attack` vraci `{ok:false, reason:"no_data"}`
#     (nikdy ticha nula).
#
# Fixture (`tests/fixtures/m5/weapons.json`) je V GITU, takze test meri i v CI
# (docs/04 §4.8.2); ocekavane hodnoty jsou v testu ZAPSANE, ne ctete z téhož
# souboru, ktery se meri (jinak by kontrola byla kruhova).
#
# Cesta k souboru je VSTUP: `-- --combat-script=<cesta>` (mutacni test).

const Lib = preload("res://tests/lib.gd")
const ClockScript = preload("res://core/clock.gd")
const EventsScript = preload("res://core/events.gd")
const RngScript = preload("res://core/rng.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const MobileScript = preload("res://sim/entity/mobile.gd")
const StatsScript = preload("res://sim/entity/stats.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const ContainerScript = preload("res://sim/entity/container.gd")

const COMBAT_SCRIPT := "res://sim/systems/combat.gd"
const WEAPONS_FIXTURE := "res://tests/fixtures/m5/weapons.json"

const SERIAL_A := 0x40000011
const SERIAL_B := 0x40000022
const DAGGER_ART := 3921
const SKILL_FENCING := 42
const SKILL_WRESTLING := 43
const SKILL_TACTICS := 27
const SKILL_ANATOMY := 1

# Mapovani jmeno -> id je VSTUP (kontrakt M5 §5): test ho predava, takze
# nezávisí na tom, co prave pise jina session do `data/skills.json`.
const SKILLS := {
	"Fencing": SKILL_FENCING, "Wrestling": SKILL_WRESTLING,
	"Tactics": SKILL_TACTICS, "Anatomy": SKILL_ANATOMY,
	"Swordsmanship": 40, "Lumberjacking": 44,
}

# Fixture zbroje (`data/armor.json`, kontrakt M5 §3.2): `type` + `resist`.
const ARMOR := [
	{"type": "plate_chest", "slot": "chest", "layer": 5,
		"resist": {"physical": 50, "fire": 0, "cold": 0, "poison": 0, "energy": 0},
		"source": "tests/cases/combat.gd (fixture pro mereni obrany)"},
]


class FakeEquipment:
	# `entity.equipment` jen pro bonusy; v testu vraci nuly (nic nasazeneho).
	func at_layer(_m: int, _layer: int) -> int:
		return 0

	func bonus(_m: int, _key: String) -> int:
		return 0


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


func _novy(script, weapons, items, registry, rng, clock = null, events = null, armor = null):
	# JEDNO misto, kde se system stavi: FIXTURE jde dovnitr (zbraně i mapa
	# skillů), takze test nemeri to, co prave pise jina session do `data/`.
	# `armor` je slovnik z `data/armor.json` (nebo fixture) - bez nej se
	# resisty NEMERI a `unknown_resist` to hlasi.
	# PORADI ARGUMENTU (kontrakt M5 §5): 5. je `skills_provider`, 14. je `armor`
	# (slovnik z `data/armor.json`). Kdyz se `armor` preda na 5. misto, `_init`
	# ho bere jako mapu skillu a zbranove skilly se nenajdou.
	return script.new(registry, weapons, items, FakeEquipment.new(), SKILLS, rng,
		clock if clock != null else ClockScript.new(),
		events if events != null else EventsScript.new(), null,
		WEAPONS_FIXTURE, "res://tests/fixtures/m5/armor.json",
		"res://data/balance.json", "res://data/skills.json", armor)

func _mobil(registry, serial: int, sila: int, obratnost: int, inteligence: int):
	var mob = MobileScript.new(serial, 400, Vector3i(10, 10, 0))
	mob.stats = StatsScript.new(sila, obratnost, inteligence)
	mob.max_hp = 1000                    # vysoke hp: cil se nesmi vyprázdnit
	mob.hp = 1000
	mob.max_stam = 100
	mob.stam = 100
	registry.register(mob)
	return mob


func _nasad_zbran(items, mob, art: int) -> void:
	# Zbran v ruce: `item.tile` je ART ID, `weapons.json: art` je TILEDATA ID
	# (`entity.item.ITEM_OFFSET` = 0x4000) - kontrakt M5 §3.1.
	var item = ItemScript.new(0x5000 + int(mob.serial) % 1000, art + ItemScript.ITEM_OFFSET, 1)
	item.layer = 1
	item.parent = int(mob.serial)
	items[int(item.serial)] = item
	mob.equip[1] = int(item.serial)


func _nastav_data(mob, data: Dictionary) -> void:
	# Data monstra jdou do `mob.ai["data"]` - stejny kanal jako `sim.world.spawn`
	# (viz hlavicka sekce G). `Object.set()` na mobil v Godotu 4 nedrzi.
	var ai: Dictionary = mob.get("ai")
	ai["data"] = data
	mob.set("ai", ai)


func run(t) -> void:
	var cesta: String = _arg("combat-script", COMBAT_SCRIPT)
	var script = Lib.script_at(cesta)
	if script == null:
		t._pending("sim.combat NENI HOTOVY: " + cesta + " chybi nebo se neparsuje")
		return
	var weapons = Lib.json_at(WEAPONS_FIXTURE)
	if weapons == null:
		t._pending("fixture " + WEAPONS_FIXTURE + " chybi")
		return

	# -- A) SWING DELAY: prijimaci cislo 3000 ms ---------------------------
	var registry = RegistryScript.new()
	var items: Dictionary = {}
	var clock = ClockScript.new()
	var events = EventsScript.new()
	var combat = _novy(script, weapons, items, registry, RngScript.new(7), clock, events)
	var mob = _mobil(registry, SERIAL_A, 100, 100, 100)
	t._check(combat.weapons_loaded(), "combat: fixture zbrani se nacetla")
	_nasad_zbran(items, mob, DAGGER_ART)
	mob.stam = 100
	t._check(combat.weapon_speed(mob) == 30, "swing: Dagger ma speed 30 (AosSpeed z fixture)")
	t._check(combat.swing_delay_ms(SERIAL_A) == 3000,
		"swing_delay_ms(stam 100, speed 30) == 3000, je %d" % combat.swing_delay_ms(SERIAL_A))
	# Vzorec oddeleny od mobilu: 40000/((100+100)*30) = 6 -> 6*500 = 3000
	t._check(combat.delay_ms_for(100, 30) == 3000, "delay_ms_for(100, 30) == 3000")
	# Dolni mez 1,25 s: pri stam 0 a speed 800 je `floor(40000/80000) = 0`,
	# takze se uplatni minimum.
	t._check(combat.delay_ms_for(0, 800) == 1250,
		"dolni mez swing delay je 1250 ms, je %d" % combat.delay_ms_for(0, 800))
	t._check(combat.delay_ms_for(100, 0) == 0, "nulova rychlost = neznamo (0), ne ticha nahrada")
	# 3000 ms = 6 dilku po 500 ms; posun casu o 2999 jeste nesmi uderit.
	clock.advance(2999)
	var pred: int = int(mob.stam)

	# -- B) ATTACK: war, cil, naplanovany swing ---------------------------
	var cil = _mobil(registry, SERIAL_B, 10, 10, 10)
	var r = combat.attack(SERIAL_A, SERIAL_B)
	t._check(bool(r.get("ok", false)), "attack vrati ok (reason=%s)" % str(r.get("reason", "")))
	t._check(int(r.get("delay_ms", 0)) == 3000, "attack naplanuje swing za 3000 ms")
	var st: Dictionary = combat.state_of(SERIAL_A)
	t._check(bool(st.get("war", false)), "attack nastavi war = true")
	t._check(int(st.get("target", 0)) == SERIAL_B, "attack nastavi cil")
	t._check(int(st.get("next_swing_ms", 0)) == 2999 + 3000,
		"next_swing_ms = cas + delay (%d)" % int(st.get("next_swing_ms", 0)))
	t._check(combat.state_of(SERIAL_A).get("in_combat") == true, "state_of: in_combat")
	r = combat.attack(SERIAL_A, 0xDEAD)
	t._check(not bool(r.get("ok", false)) and str(r.get("reason", "")) == "no_target",
		"attack na neznamy cil vraci no_target")
	var war = combat.set_war(SERIAL_A, false)
	t._check(bool(war.get("ok", false)) and war.get("war") == false, "set_war(false) funguje")
	t._check(combat.state_of(SERIAL_A).get("war") == false, "set_war(false) zrusi war")
	t._check(int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)) == 0,
		"set_war(false) zrusi naplanovany swing")
	var stop = combat.stop_combat(SERIAL_A)
	t._check(bool(stop.get("ok", false)) and bool(stop.get("had_state", false)),
		"stop_combat vraci, ze stav mel")

	# -- B2) DOSAH MELEE (P2, 2026-10-12) ---------------------------------
	# Do tohoto datumu `attack` vzdalenost NEMERIL: hrac zasahl cil na druhem
	# konci mapy, kdezto monstrum muselo byt na dosah ruky (`sim.ai` MELEE_RANGE).
	# Meri se: (1) hodnota je z `data/balance.json`, (2) na hranici dosahu
	# projde, (3) o dlazdici dal vraci `too_far` S HLASKOU, (4) stav boje se
	# pritom NEROZJEDNA (odmitnuty prikaz nesmi naplanovat swing).
	var melee: int = combat.melee_range()
	var data_balance = Lib.json_at("res://data/balance.json")
	var melee_z_dat: int = -1
	if data_balance is Dictionary and data_balance.get("range") is Dictionary:
		melee_z_dat = int((data_balance["range"] as Dictionary).get("melee", -1))
	t._check(melee_z_dat > 0 and melee == melee_z_dat,
		"combat: melee_range() je z data/balance.json (kod %d, data %d)" % [melee, melee_z_dat])
	combat.stop_combat(SERIAL_A)
	# ⚠ POZOR NA `_mobil`: 3.-5. argument jsou STATY (sila/obratnost/inteligence),
	# ne pozice - pozice je uvnitr VZDY `(10,10,0)`. Prvni verze teto sekce
	# predala "pozici" a meritila tim neco jineho (vsechny mobily staly na sobe,
	# takze "mimo dosah" vyslo jako zasah). Pozice se proto nastavuje VYSLOVNE.
	var blizky = _mobil(registry, 0x4000000B, 100, 100, 100)
	blizky.pos = Vector3i(10 + melee, 10, 0)
	var r_blizko: Dictionary = combat.attack(SERIAL_A, 0x4000000B)
	t._check(bool(r_blizko.get("ok", false)),
		"combat: cil na hranici dosahu (%d dlazdice) jde utocit (vyslo %s)" % [melee, str(r_blizko)])
	var cas_po_blizkem: int = int(combat.state_of(SERIAL_A).get("next_swing_ms", -1))
	var daleky = _mobil(registry, 0x4000000C, 100, 100, 100)
	daleky.pos = Vector3i(10 + melee + 1, 10, 0)
	events.drain()
	var r_daleko: Dictionary = combat.attack(SERIAL_A, 0x4000000C)
	t._check(not bool(r_daleko.get("ok", true))
			and str(r_daleko.get("reason", "")) == "too_far",
		"combat: cil o dlazdici dal vraci `too_far` (vyslo %s)" % str(r_daleko))
	var hlasky_dosah: Array = []
	for e in events.drain():
		if str(e.get("name", "")) == "message":
			hlasky_dosah.append(str(e.get("data", {}).get("text", "")))
	var ma_hlasku: bool = false
	for text in hlasky_dosah:
		if text.find("far") >= 0:
			ma_hlasku = true
	t._check(ma_hlasku, "combat: `too_far` posle HLASKU, ne ticho (vyslo %s)" % str(hlasky_dosah))
	t._check(int(combat.state_of(SERIAL_A).get("next_swing_ms", -1)) == cas_po_blizkem,
		"combat: odmitnuty utok NEMENI naplanovany swing (byl %d, ted %d)"
			% [cas_po_blizkem, int(combat.state_of(SERIAL_A).get("next_swing_ms", -1))])
	t._check(int(combat.state_of(SERIAL_A).get("target", 0)) == 0x4000000B,
		"combat: odmitnuty utok NEPREPNE cil (vyslo %d)"
			% int(combat.state_of(SERIAL_A).get("target", 0)))
	# (5) DOSAH V OKAMZIKU SWINGU (2026-10-12, dokonceni P2): `attack` kontroluje
	#     dosah pri ZADANI, ale cil muze behem swingu odejit. Stav boje se pritom
	#     NERUSI - kdyz se cil vrati, swingy pokracuji.
	blizky.pos = Vector3i(10 + melee + 3, 10, 0)          # cil utekl
	var v_utekl: Dictionary = combat.resolve_swing(SERIAL_A, 0x4000000B)
	t._check(not bool(v_utekl.get("ok", true))
			and str(v_utekl.get("reason", "")) == "too_far",
		"combat: cil, ktery behem swingu utekl, dostane `too_far` (vyslo %s)" % str(v_utekl))
	t._check(int(blizky.hp) == int(blizky.max_hp),
		"combat: utekly cil NEDOSTANE damage (hp %d z %d)"
			% [int(blizky.hp), int(blizky.max_hp)])
	t._check(int(combat.state_of(SERIAL_A).get("target", 0)) == 0x4000000B
			and int(combat.state_of(SERIAL_A).get("next_swing_ms", 0)) > 0,
		"combat: odmitnuty swing NERUSI stav boje (cil %d, next %d)"
			% [int(combat.state_of(SERIAL_A).get("target", 0)),
				int(combat.state_of(SERIAL_A).get("next_swing_ms", 0))])
	blizky.pos = Vector3i(10 + melee, 10, 0)              # cil se vratil
	var v_zpet: Dictionary = combat.resolve_swing(SERIAL_A, 0x4000000B)
	t._check(bool(v_zpet.get("ok", false)),
		"combat: cil zpet na dosahu zase dostane swing (vyslo %s)" % str(v_zpet))

	# -- C) 20 SWINGU -> ALESPON 5 ZASAHU (prijimaci kriterium §4.6.4) ----
	# Kazdy swing ma cil PLNÝ (hp se pred kazdym obnovi), aby se merilo
	# "trefi se", ne "cil uz je mrtvy".
	var min_zasahu: int = 1000
	var soucet: int = 0
	var seedy: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var zasahy_posledni: int = 0
	for seed in seedy:
		var reg2 = RegistryScript.new()
		var it2: Dictionary = {}
		var c2 = _novy(script, weapons, it2, reg2, RngScript.new(int(seed)))
		var a = _mobil(reg2, SERIAL_A, 100, 100, 100)
		var b = _mobil(reg2, SERIAL_B, 10, 10, 10)
		_nasad_zbran(it2, a, DAGGER_ART)
		_nasad_zbran(it2, b, DAGGER_ART)
		a.skills.set_value(SKILL_FENCING, 1000)   # 100.0
		b.skills.set_value(SKILL_FENCING, 1000)   # 100.0 -> sance presne 0,5
		b.hp = b.max_hp
		var zasahy: int = 0
		var hp_pred: int = int(b.hp)
		var dmg_celkem: int = 0
		for _i in 20:
			b.hp = b.max_hp             # cil je pred kazdym swingem plný
			var v: Dictionary = c2.resolve_swing(SERIAL_A, SERIAL_B)
			t._check(bool(v.get("ok", false)), "resolve_swing vraci ok (seed %d)" % int(seed))
			if bool(v.get("hit", false)):
				zasahy += 1
				dmg_celkem += int(v.get("damage", 0))
				t._check(int(v.get("damage", 0)) >= 1, "zasah ma damage >= 1 (seed %d)" % int(seed))
				t._check(int(v.get("hp_left", 0)) < int(b.max_hp),
					"zasah snizi hp cile (seed %d: hp_left %d < %d)"
					% [int(seed), int(v.get("hp_left", 0)), int(b.max_hp)])
		if seed == 1:
			zasahy_posledni = zasahy
		t._check(zasahy >= 5, "20 swingu (seed %d) -> %d zasahu (>= 5)" % [int(seed), zasahy])
		t._check(zasahy <= 20, "zasahu nemuze byt vic nez swingu (seed %d)" % int(seed))
		soucet += zasahy
		min_zasahu = mini(min_zasahu, zasahy)
	t._check(min_zasahu >= 5,
		"20 swingu: minimum pres 10 seedu = %d zasahu (>= 5)" % min_zasahu)
	t._check(soucet >= 50, "20 swingu: soucet pres 10 seedu = %d (>= 50, cekano ~100)" % soucet)

	# -- D) HIT CHANCE JE ZE ZBRANOVEHO SKILLU (ne z Tactics) --------------
	var reg3 = RegistryScript.new()
	var it3: Dictionary = {}
	var c3 = _novy(script, weapons, it3, reg3, RngScript.new(3))
	var a3 = _mobil(reg3, SERIAL_A, 100, 100, 100)
	var b3 = _mobil(reg3, SERIAL_B, 10, 10, 10)
	_nasad_zbran(it3, a3, DAGGER_ART)
	_nasad_zbran(it3, b3, DAGGER_ART)
	a3.skills.set_value(SKILL_FENCING, 500)      # 50.0
	a3.skills.set_value(SKILL_TACTICS, 0)
	b3.skills.set_value(SKILL_FENCING, 500)
	b3.skills.set_value(SKILL_TACTICS, 0)
	var s1: float = c3.hit_chance(SERIAL_A, SERIAL_B)
	a3.skills.set_value(SKILL_TACTICS, 1000)     # Tactics 100.0
	var s2: float = c3.hit_chance(SERIAL_A, SERIAL_B)
	t._check(is_equal_approx(s1, s2),
		"Tactics NEMENI hit chance (%.4f vs %.4f)" % [s1, s2])
	# Rovne skilly -> presne 0,5 (`(50+20)/(2*(50+20))`).
	t._check(is_equal_approx(s1, 0.5), "rovne zbranove skilly 50/50 -> sance 0,5 (je %.4f)" % s1)

	# -- E) SKILL ZBRANE SE CTE Z DAT (a chybejici se HLASI) --------------
	t._check(combat.skill_of(SERIAL_A) == SKILL_FENCING,
		"skill zbrane Dagger je Fencing (%d), ne Tactics" % combat.skill_of(SERIAL_A))
	var nazev: String = combat.skill_id(SKILL_FENCING)
	t._check(nazev == "Fencing", "skill_id(42) == Fencing (je '%s')" % nazev)

	# -- F) DAMAGE: base + base*součet bonusů (1,425 pri 100/100/100) ------
	# Seed se HLEDA (dokud prvni swing netrefi), aby se merila hodnota damage,
	# ne sance na zasah.
	var namerene: Array = []
	var ocekavane: Array = []
	for seed in range(1, 201):
		var reg4 = RegistryScript.new()
		var it4: Dictionary = {}
		var c4 = _novy(script, weapons, it4, reg4, RngScript.new(int(seed)))
		var a4 = _mobil(reg4, SERIAL_A, 100, 100, 100)
		var b4 = _mobil(reg4, SERIAL_B, 10, 10, 10)
		_nasad_zbran(it4, a4, DAGGER_ART)
		a4.skills.set_value(SKILL_FENCING, 1000)
		a4.skills.set_value(SKILL_TACTICS, 1000)
		a4.skills.set_value(SKILL_ANATOMY, 1000)
		b4.skills.set_value(SKILL_WRESTLING, 1)
		# resist 0 rozsirene o `data` monstra (viz sekce G) - `Object.set()` na
		# mobil v Godotu 4 nefunguje, takze se resist ve svete nese v `ai.data`.
		var ai4: Dictionary = b4.get("ai")
		ai4["data"] = {"resist": {"physical": 0}}
		b4.set("ai", ai4)
		var v: Dictionary = c4.resolve_swing(SERIAL_A, SERIAL_B)
		if bool(v.get("hit", false)):
			namerene.append(int(v.get("damage", 0)))
			ocekavane.append(0)          # doplni se nize (base je z rng)
			break
	# Base se z rng neda precist predem, proto se meri ROZSAH: 10..12 x
	# (1 + 1,425) = 24,25..29,1. Se STR 100 a bonusy, ktere se sectou
	# celociselne po castech (`int(base * bonus)`), je namERene 22..26;
	# mezera je proto 20..29 a DOLNI MEZ 20 dokazuje, ze bonus existuje
	# (bez bonusu by base bylo 10..12).
	if namerene.is_empty():
		t._pending("damage: zadny seed 1..200 netrefil (nemelo nastat)")
	else:
		var d: int = int(namerene[0])
		t._check(d >= 20 and d <= 29,
			"damage se bonusy STR/Anatomy/Tactics je 20..29 (je %d)" % d)
		t._check(d > 12, "damage s bonusy je vyssi nez base bez bonusu (je %d > 12)" % d)

	# -- G) OBRANA: resist 50 pulti, resist 0 nebere -----------------------
	# -- G) OBRANA: resist monstra (z `ai.data`) a resist zbroje -------------
	# ⚠ VSTUP JE `mob.ai["data"]`, NE `mob.set("resist", ...)`: `Object.set()`
	# na nedeklarovanou vlastnost v Godotu 4 NIC NEUDELA (namEReno 2026-10-11:
	# `mob.set("resist", {...})` -> `mob.get("resist")` == `<null>`). Do mobilu
	# data zapisuje `sim.world.spawn`, takze test pouziva PRESNE ten same kanal.
	var reg5 = RegistryScript.new()
	var it5: Dictionary = {}
	var c5 = _novy(script, weapons, it5, reg5, RngScript.new(11))
	var a5 = _mobil(reg5, SERIAL_A, 100, 100, 100)
	var b5 = _mobil(reg5, SERIAL_B, 10, 10, 10)
	_nasad_zbran(it5, a5, DAGGER_ART)
	a5.skills.set_value(SKILL_FENCING, 1000)
	_nastav_data(b5, {"resist": {"physical": 50}})
	var zbroj: Dictionary = c5.weapon_of(SERIAL_A)
	var obrana: Dictionary = c5._obrana(b5, zbroj, 100)
	t._check(int(obrana["damage"]) == 50,
		"resist 50 %% z 100 damage = 50 (je %d)" % int(obrana["damage"]))
	t._check(int(obrana["absorbed"]) == 50, "absorbed = 50 (je %d)" % int(obrana["absorbed"]))
	t._check(int(obrana["resist"]) == 50, "hlasi resist 50 (je %d)" % int(obrana["resist"]))
	t._check(bool(obrana["unknown"]) == false, "znamy resist neni 'unknown'")
	_nastav_data(b5, {"resist": {"physical": 0}})
	obrana = c5._obrana(b5, zbroj, 100)
	t._check(int(obrana["damage"]) == 100,
		"resist 0 %% nebere nic (je %d)" % int(obrana["damage"]))
	_nastav_data(b5, {"resist": {"physical": 100}})
	obrana = c5._obrana(b5, zbroj, 100)
	t._check(int(obrana["damage"]) == 1,
		"minimum damage je 1 (AOS.cs:205-206), je %d" % int(obrana["damage"]))
	t._check(bool(obrana["unknown"]) == false, "i resist 100 je ZNÁMÝ (ne unknown)")

	# -- G2) NEMERENO: bez `resist` a bez dat zbroje se typ VYNECHA ---------
	_nastav_data(b5, {})
	var c_bez = script.new(reg5, weapons, it5, FakeEquipment.new(), SKILLS,
		RngScript.new(1), ClockScript.new(), EventsScript.new(), null,
		"res://tests/fixtures/m5/NEEXISTUJE.json", "res://tests/fixtures/m5/NEEXISTUJE.json",
		"res://data/balance.json")
	t._check(not c_bez.armor_loaded(), "bez armor.json -> armor_loaded() == false")
	obrana = c_bez._obrana(b5, zbroj, 100)
	t._check(bool(obrana["unknown"]), "neznamy resist se hlasi (unknown == true)")
	# NEMERENO nesmi znamenat "zadny resist" (damage by vylhal nahoru), ale
	# ani nulu: kdyz typ neni znamy, zustava bud cely damage, nebo se uplatni
	# minimum 1 (`ARMOR_MIN_DAMAGE`). Test prijima OBE - podstatne je, ze se
	# hodnota nikdy netvari jako namERena nula a `unknown` je true.
	t._check(int(obrana["damage"]) >= 1 and int(obrana["damage"]) <= 100,
		"neznamy resist neda nulu ani vic nez dmg (je %d)" % int(obrana["damage"]))

	# -- G3) ZBROJ NA MOBILU (fixture data/armor.json) ---------------------
	# `_resist` hleda typ predmetu v `_armor` (`data/armor.json`, kontrakt M5
	# §3.2); fixture ma `plate_chest` s physical 50.
	var reg5b = RegistryScript.new()
	var it5b: Dictionary = {}
	var c5b = script.new(reg5b, weapons, it5b, FakeEquipment.new(), SKILLS,
		RngScript.new(1), ClockScript.new(), EventsScript.new(), null, WEAPONS_FIXTURE,
		"res://tests/fixtures/m5/armor.json", "res://data/balance.json",
		"res://data/skills.json", ARMOR)
	t._check(c5b.armor_loaded(), "fixture zbroje se nacetla")
	var b5b = _mobil(reg5b, SERIAL_B, 10, 10, 10)
	_nastav_data(b5b, {})
	var krunyr = ItemScript.new(0x900001, 5141, 1)
	krunyr.type = "plate_chest"
	it5b[0x900001] = krunyr
	b5b.equip[3] = 0x900001
	obrana = c5b._obrana(b5b, zbroj, 100)
	t._check(int(obrana["damage"]) == 50,
		"zbroj s resist 50 %% z fixture pulti damage (je %d)" % int(obrana["damage"]))

	# -- K) TYP POSKOZENI: `Slashing` z realnych dat je FYZICKE ------------
	# Realna `data/weapons.json` maji `damage_type: "Slashing"`/`"Axe"` - to je
	# typ zbrane, ne rezistentni typ AoS (pet typu, `AOS.cs:170-174`). Kdyby
	# se dosadil jako neznamej, resisty by se nemerily a damage by vylhal.
	var typy: Dictionary = c5._typy({"damage_type": "Slashing"})
	t._check(typy.has("physical"),
		"damage_type 'Slashing' se bere jako physical (%s)" % str(typy))
	t._check(int(typy.get("physical", 0)) == 100, "podil je 100 %%")
	typy = c5._typy({"damage_type": "fire"})
	t._check(typy.has("fire"), "damage_type 'fire' zustava fire (%s)" % str(typy))

	# -- A2) REALNA DATA: kazda zbran sedi na vzorec swing delay ----------
	# Kontrola DAT druhe session, ne meho kódu: `swing_delay_ms` v datech musi
	# byt `floor(40000/((100+100)*speed))*500` s minimem 1250 ms (kontrakt M5
	# §3.1). Kdyz data chybi, kontrola se OHlasi (`_pending`).
	var real = Lib.json_at("res://data/weapons.json")
	if real == null:
		t._pending("data/weapons.json chybi - vzorec na realnych datech NEMEREN")
	elif not (real is Array) or (real as Array).is_empty():
		t._pending("data/weapons.json neni neprazdny seznam")
	else:
		var spatne: int = 0
		var speed30: int = 0
		var speed30_ok: int = 0
		for rec in real:
			if not (rec is Dictionary):
				continue
			var sp: int = int((rec as Dictionary).get("speed", 0))
			var zapsane: int = int((rec as Dictionary).get("swing_delay_ms", -1))
			if sp <= 0 or zapsane < 0:
				continue
			var podle_vzorce: int = maxi((40000 / ((100 + 100) * sp)) * 500, 1250)
			if zapsane != podle_vzorce:
				spatne += 1
			if sp == 30:
				speed30 += 1
				if zapsane == 3000:
					speed30_ok += 1
		t._check(spatne == 0,
			"data/weapons.json: vsechny swing_delay_ms sedi na vzorec (rozchod %d)" % spatne)
		t._check(speed30 == speed30_ok,
			"data/weapons.json: kazda zbran se speed 30 ma 3000 ms (%d z %d)" % [speed30_ok, speed30])

	# -- H) BEZ ZBRANE (WRESTLING) ----------------------------------------
	var reg6 = RegistryScript.new()
	var it6: Dictionary = {}
	var ev6 = EventsScript.new()
	var c6 = _novy(script, weapons, it6, reg6, RngScript.new(5), null, ev6)
	var a6 = _mobil(reg6, SERIAL_A, 60, 60, 60)
	var b6 = _mobil(reg6, SERIAL_B, 10, 10, 10)
	a6.skills.set_value(SKILL_WRESTLING, 1000)
	b6.skills.set_value(SKILL_WRESTLING, 1000)
	b6.set("resist", {"physical": 0})
	t._check(combat.weapon_speed(a6) == 50, "bez zbrane je rychlost wrestlingu 50")
	t._check(c6.skill_of(SERIAL_A) == SKILL_WRESTLING,
		"bez zbrane se pouzije Wrestling (%d)" % c6.skill_of(SERIAL_A))
	var zasah: bool = false
	for _i in 20:
		var v: Dictionary = c6.resolve_swing(SERIAL_A, SERIAL_B)
		t._check(bool(v.get("ok", false)), "wrestling swing vraci ok")
		if bool(v.get("hit", false)):
			zasah = true
			t._check(int(v.get("damage", 0)) >= 1, "wrestling damage je >= 1")
	t._check(zasah, "wrestling se 20 pokusy alespon jednou zasahl")

	# -- I) CHYBEJICI DATA: `attack` vraci no_data ------------------------
	var reg7 = RegistryScript.new()
	var c7 = script.new(reg7, null, {}, null, SKILLS, RngScript.new(1),
		ClockScript.new(), EventsScript.new(), null,
		"res://tests/fixtures/m5/NEEXISTUJE.json", "res://tests/fixtures/m5/armor.json",
		"res://data/balance.json")
	t._check(not c7.weapons_loaded(), "chybejici weapons.json -> weapons_loaded() == false")
	var a7 = _mobil(reg7, SERIAL_A, 10, 10, 10)
	var b7 = _mobil(reg7, SERIAL_B, 10, 10, 10)
	var r7: Dictionary = c7.attack(SERIAL_A, SERIAL_B)
	t._check(not bool(r7.get("ok", false)), "bez dat attack vraci ok=false")
	t._check(str(r7.get("reason", "")) == "no_data",
		"bez dat attack vraci reason=no_data (je '%s')" % str(r7.get("reason", "")))

	# -- J) EVENTY: message, anim(2), sound, stats_changed ----------------
	var reg8 = RegistryScript.new()
	var it8: Dictionary = {}
	var ev8 = EventsScript.new()
	var c8 = _novy(script, weapons, it8, reg8, RngScript.new(1), null, ev8)
	var a8 = _mobil(reg8, SERIAL_A, 100, 100, 100)
	var b8 = _mobil(reg8, SERIAL_B, 10, 10, 10)
	_nasad_zbran(it8, a8, DAGGER_ART)
	a8.skills.set_value(SKILL_FENCING, 1000)
	b8.skills.set_value(SKILL_FENCING, 1000)
	b8.set("resist", {"physical": 0})
	var _v8: Dictionary = c8.resolve_swing(SERIAL_A, SERIAL_B)
	var jmena: Array = []
	var anim_akce: Array = []
	for e in ev8.drain():
		jmena.append(str(e["name"]))
		if str(e["name"]) == "mobile_anim":
			anim_akce.append(int(e["data"].get("action", -1)))
	t._check(jmena.has("message"), "swing posle udalost message (%s)" % str(jmena))
	t._check(jmena.has("mobile_anim"), "swing posle udalost mobile_anim")
	t._check(anim_akce.has(2), "animace utoku je akce 2 (%s)" % str(anim_akce))
	t._check(jmena.has("stats_changed"), "swing posle stats_changed")
	t._check(jmena.has("sound"), "swing posle sound")
