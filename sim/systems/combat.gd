extends RefCounted
# Souboj: swing delay, hit chance, damage, obrana (granule `sim.combat`;
# smlouva docs/04 §4.2 a tok §4.6.4, pravidla docs/05 §5.5, era §5.16).
#
# ERA JE AoS (docs/05 §5.16: "Swing delay, hit chance, damage, obrana = AoS";
# `data/balance.json: era.combat = "aos"`). Pre-AoS vetev tu NENI a je to
# pojmenovane, ne prehlednute: `GetDelay` ma v reference tri vetve
# (`BaseWeapon.cs:1552 SE`, `:1596 AOS`, `:1618 klasika 15000/v`) a my
# pouzivame PRESNE tu AoS - kdo bude chtit klasiku, prepne jeden klic v datech,
# ale musi dopsat vetev (docs/05 §5.16.3, pravidlo 2).
#
# ODKUD CISLA (vsechno namEReno v `_src/servuo`, nic vymysleneho):
#   * swing delay: `v = (Stam + 100) * Speed`, `delay = floor(40000/v) * 0,5 s`,
#     dolni mez 1,25 s (`Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1598-1616`);
#     SSI (`AosAttribute.WeaponSpeed`) se do `v` pricita PRES `AOS.Scale`
#     (`:1600-1602`), strop 60 % je z vetve SE (`:1560-1565`) - pouzivame jen
#     strop (horni mez atributu), ne vetev,
#   * hit chance: `((atk+20)*(100+HCI)) / (2*(def+20)*(100+DCI))`
#     (`BaseWeapon.cs:1448-1468` a `:1488`); strop HCI 45 (gargoyle 50) a DCI
#     45 (`:1451`, `:1462-1466`); AoS spodni mez sance 0,02 (`:1530-1532`),
#   * `atk`/`def` je ZBRANOVY SKILL: `atkWeapon.Skill` / `defWeapon.Skill`
#     (`BaseWeapon.cs:1430-1434`). **Tactics NENI presnost** (docs/05 §5.5.1),
#     je to damage skill - proto ho tenhle modul do hit chance NEDAVA,
#   * damage: `damage + (int)(damage * totalBonus)` (`BaseWeapon.cs:3812-3815`),
#     bonusy STR 0,300, Anatomy 0,500, Tactics 0,625, Lumberjacking 0,200
#     (`:3788-3791`), kazdy `value*scalar/100` a +offset pri `value >= 100`
#     (`GetBonus`, `:3663-3673`); DI strop 100 % (`:3804-3809`); Lumber bonus
#     plati JEN pro sekery (`:3793-3796`),
#   * obrana: `Σ(dmg * podil * (100 - resist)) / 10000`, minimum 1
#     (`Scripts/Misc/AOS.cs:168-206`), strop 35 JEN pro direct damage (`:213`);
#     rezistentni typy jsou 5 (`phys, fire, cold, pois, nrgy`; `AOS.cs:170-174`),
#   * `VirtualArmor` tvoru je pre-AoS fyzicka zbroj (`VirtualArmorMod`,
#     `Scripts/Mobiles/PlayerMobile.cs:1934`) - v AoS vetvi se skodi PRES RESIST
#     (`AOS.cs:170-176`), proto se `virtual_armor` z dat do vypoctu NEDOSTAVA.
#     Je to ROZHODNUTI KLONU (era AoS) a je VIDET tady, ne schovane.
#
# PRIJIMACI CISLO: `swing_delay_ms(stam=100, speed=30) == 3000`
# (`v = 200*30 = 6000`, `floor(40000/6000) = 6`, `6*500 = 3000`;
# `BaseWeapon.cs:1598-1609`). Test to meri PRESNE - na fixture, protoze realny
# `data/weapons.json` v dobe psani teto session jeste neexistoval (pise ho
# jina session; kontrakt M5 §3.1 ho zadava).
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `_init(...)` - zavislosti KONSTRUKTOREM (vzor `sim.craft` a `sim.vendor`):
#     `registry, weapons, items, equipment, skills_provider, rng, clock, events,
#     death` + cesty k datum jako VSTUP (`weapons_path`, `armor_path`,
#     `balance_path`, `skills_path`), aby slo merit fixtures a mutace,
#   * `skills_provider` je slovnik `jmeno -> id` z `data/skills.json`. Kdyz
#     skill zbrane v mape NENI, modul to hlasi a vrati `reason:"skill_unknown"`
#     - tichy prechod na wrestling by z jine zbrane udelal pest,
#   * `armor` (slovnik z `data/armor.json`) je taky vstup; chybi-li soubor,
#     resisty se NEMERI a `resolve_swing` to vraci v `unknown_resist: true`,
#   * stav planovani (`due_ms`) JE v systemu, ne Callable v `core.clock`
#     (pravidlo 5 kontraktu: stav casovacu patri systemu/mobilu),
#   * `state_of(m)` vraci i `delay_ms` (smlouva zadava `next_swing_ms`),
#     aby se dal swing merit bez behu simulace,
#   * chovani pri chybejicich datech: `attack` vraci `{ok:false, reason:"no_data"}`
#     a `push_warning` - NIKDY tiche nuly (docs/09 §9.10, pravidlo G4).
#
# TOK (doslovne z docs/04 §4.6.4):
#   `Command{t:"attack"}` -> `attack(m, target)` -> `war=true`, cil, swing;
#   `tick(ms)` v case `due_ms` -> `resolve_swing(m, cil)`
#     -> event `message` + `mobile_anim{action:2}` + `sound` + `stats_changed`
#     -> kdyz hp <= 0: `death.die(cil)`. Event `death` + `mobile_removed`
#        posila `sim.death`, NE tenhle modul (dve udalosti `death` by klienta
#        rozbily - jedno misto pro smrt je `sim.death`).
#
# M2 (docs/05 §5.5.1): projektil je VIZUALNI - hit se pocita v okamziku
# vypocitani swingu (`BaseRanged.cs:91-102`, `MovingEffect` na `:221`),
# let nerozhoduje. Tenhle modul zadny projektil neposila.

const Const = preload("res://core/const.gd")
const ItemScript = preload("res://sim/entity/item.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")

const WEAPONS_PATH := "res://data/weapons.json"
const ARMOR_PATH := "res://data/armor.json"
const BALANCE_PATH := "res://data/balance.json"
const SKILLS_PATH := "res://data/skills.json"

# Vrstvy vybavy (`entity.equipment`; 1 = jednorucni, 2 = obourucni/stit;
# `_src/servuo/Server/Item.cs:35,160` - `Layer.FirstValid` .. `Layer.LastUserValid`).
const LAYER_ONE_HANDED := 0x01
const LAYER_TWO_HANDED := 0x02

# Cisla akci animace jsou ABSTRAKTNI ID klienta (kontrakt M5 §2);
# 2 = attack, 3 = death (`sim/systems/movement.gd:84-85` pro 0/1).
const ACTION_ATTACK := 2
const ACTION_DEATH := 3

# Vzorce (viz hlavicka; NEOPSANE - kazdy ma radek v reference).
const DELAY_UNIT_MS := 500          # `0.5 s` v `BaseWeapon.cs:1609`
const DELAY_MIN_MS := 1250          # 1,25 s (`:1613-1616`)
const SSI_CAP := 60                 # `:1560-1565`
const HCI_CAP := 45                 # `:1451`
const DCI_CAP := 45                 # `:1462-1466`
const HIT_MIN_CHANCE := 0.02        # `:1530-1532`
const DIRECT_DAMAGE_CAP := 35       # `AOS.cs:213`
const ARMOR_MIN_DAMAGE := 1         # `AOS.cs:205-206`
const ARMOR_SCALE := 10000          # `AOS.cs:177`

# Damage bonusy: scalar + offset, prah 100.0 skillu (`BaseWeapon.cs:3788-3791`,
# `GetBonus` `:3663-3673`).
const BONUS_STR := 0.300
const BONUS_ANATOMY := 0.500
const BONUS_TACTICS := 0.625
const BONUS_LUMBER := 0.200
const BONUS_THRESHOLD := 100.0
const OFFSET_STR := 5.00
const OFFSET_ANATOMY := 5.00
const OFFSET_TACTICS := 6.25
const OFFSET_LUMBER := 10.00
const DI_CAP := 100

# Bez zbrane (wrestling) - UO dava pestem zakladni zbran (`Fists.cs` je
# `BaseWeapon` s `Speed = 50`). Hodnoty jsou ROZHODNUTI KLONU a jsou VIDET:
# damage 1..3 a rychlost 50 = "jako bezna zbran".
const WRESTLING_MIN := 1
const WRESTLING_MAX := 3
const WRESTLING_SPEED := 50
# Posledni zaloha id wrestlingu, kdyz `skills_provider` nema "Wrestling"
# (fixture). V realnych datech je to `data/skills.json` id 43.
const WRESTLING_ID_FALLBACK := 43

# Skill v desetinach: 100.0 = 1000 (`entity.skills`).
const SKILL_PER_POINT := 10

var _registry = null
var _items = null
var _equipment = null
var _rng = null
var _clock = null
var _events = null
var _death = null

var _weapons: Dictionary = {}          # jmeno (lowercase) i typ -> zaznam z dat
var _skill_id: Dictionary = {}         # jmeno skillu -> id (z data/skills.json)
var _armor: Dictionary = {}            # typ predmetu -> zaznam z data/armor.json
var _weapons_ok: bool = false
var _armor_ok: bool = false
var _hci_cap: int = HCI_CAP
var _dci_cap: int = DCI_CAP
var _ssi_cap: int = SSI_CAP
var _direct_cap: int = DIRECT_DAMAGE_CAP

# Stav boje: serial -> {war, target, due_ms, delay_ms, started_ms}
var _state: Dictionary = {}


func _init(registry = null, weapons = null, items = null, equipment = null,
		skills_provider = null, rng = null, clock = null, events = null, death = null,
		weapons_path: String = WEAPONS_PATH, armor_path: String = ARMOR_PATH,
		balance_path: String = BALANCE_PATH, skills_path: String = SKILLS_PATH,
		armor = null) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_items = items
	_equipment = equipment
	_rng = rng if rng != null else RngScript.new(0)
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_death = death
	_load_weapons(weapons if weapons != null else _read_json(weapons_path), weapons_path)
	_load_armor(armor if armor != null else _read_json(armor_path), armor_path)
	if skills_provider is Dictionary and not (skills_provider as Dictionary).is_empty():
		_skill_id = (skills_provider as Dictionary).duplicate()
	else:
		_load_skills(skills_path)
	_read_balance(balance_path)


# -- rozhrani podle smlouvy ------------------------------------------------

func attack(m: int, target: int) -> Dictionary:
	# `Command{t:"attack", serial}` -> `sim.commands.dispatch` (`sim/commands.gd:120`).
	# Vraci `{ok, reason, target, war, delay_ms}`; `hit`/`damage`/`absorbed`/
	# `hp_left`/`killed` patri `resolve_swing` (vola se az v case swingu), proto
	# je tu NEVRACIME jako nuly - nula by vypadala jako namEReny swing.
	var mob = _mobile(m)
	if mob == null:
		return _fail("no_mobile")
	if not _weapons_ok:
		# Chybejici data se HLASI (pravidlo G4): ticha nula by vypadala jako
		# "swing bez zbrane", ale zbran MAME, jen o ni nejsou data.
		_message("You cannot fight: weapon data is missing.")
		return _fail("no_data")
	var cil = _mobile(target)
	if cil == null:
		return _fail("no_target")
	if not cil.alive():
		return _fail("target_dead")
	if _skill_atk(_weapon(mob)) < 0:
		# Skill zbrane, ktery v datech neni, je VADA DAT - a je videt uz tady,
		# ne az tise ve swingu (ticha nahrada wrestlingu by z jine zbrane
		# udelala pest).
		push_warning("sim.combat: skill zbrane '%s' neni v data/skills.json"
			% str(_weapon(mob).get("skill_used", "")))
		return _fail("skill_unknown")
	_state[m] = {"war": true, "target": int(target), "due_ms": 0, "delay_ms": 0,
		"started_ms": _now()}
	if not _planuj(m):
		return _fail("no_speed")
	return {"ok": true, "reason": "", "target": int(target), "war": true,
		"delay_ms": int(_state[m]["delay_ms"])}


func set_war(m: int, on: bool) -> Dictionary:
	# `war/peace` (docs/05 §5.5.2). Vypnuti boje RUCI swing zrusi (jinak by
	# hrac v klidu jeste jednou uderil - presne tomu ma "war" zabranit).
	if _mobile(m) == null:
		return {"ok": false, "war": false, "reason": "no_mobile"}
	var s: Dictionary = _st(m)
	s["war"] = on
	if not on:
		s["target"] = 0
		s["due_ms"] = 0
		s["delay_ms"] = 0
	return {"ok": true, "war": on, "reason": ""}


func stop_combat(m: int) -> Dictionary:
	# Uklid po smrti cile i po `war:false`: stav se maze CELY (zadny zbytek,
	# ktery by se pozdeji ozval jako druhy swing).
	var mel: bool = _state.has(m)
	_state.erase(m)
	return {"ok": true, "had_state": mel}


func state_of(m: int) -> Dictionary:
	# Smlouva: `{war, target, next_swing_ms, in_combat}`. `next_swing_ms` je
	# `due_ms` (absolutni herni cas); kdo chce zbyvajici cas, odecte `clock`.
	var s = _state.get(m, {})
	if not (s is Dictionary):
		s = {}
	var due: int = int(s.get("due_ms", 0))
	return {
		"war": bool(s.get("war", false)),
		"target": int(s.get("target", 0)),
		"next_swing_ms": due,
		"in_combat": due > 0 and due >= _now(),
		"delay_ms": int(s.get("delay_ms", 0)),
	}


func swing_delay_ms(m: int) -> int:
	# PRIJIMACI CISLO: pri stam 100 a rychlosti 30 je to 3000 ms
	# (docs/04 §4.6.4). Bere se mobil, protoze vzorec chce STAMINU;
	# rychlost zbrane je `speed = 50 - speed_raw` (kontrakt M5 §3.1).
	var mob = _mobile(m)
	if mob == null:
		return 0
	return delay_ms_for(int(mob.stam), weapon_speed(mob), _weapon(mob))


func delay_ms_for(stam: int, speed: int, weapon = null) -> int:
	# Vzorec oddeleny od mobilu, aby sel merit PRESNE (fixture, ne hra):
	#   `v = (Stam + 100) * speed` + SSI, `delay = floor(40000/v) * 500`,
	#   minimum 1250 ms (`BaseWeapon.cs:1598-1616`).
	# `speed <= 0` = "nevim" (chybejici data) -> vraci 0, NIKDY tichy wrestling:
	# kdo chce pest, at si o `WRESTLING_SPEED` rekne pres `weapon_speed`.
	var bonus: int = 0
	if weapon != null and weapon is Dictionary:
		bonus = int((weapon as Dictionary).get("speed_increase", 0))
	bonus = clampi(bonus, 0, _ssi_cap)
	var v: int = (stam + 100) * speed
	v += _scale(v, bonus)
	if v <= 0:
		return 0
	return maxi((40000 / v) * DELAY_UNIT_MS, DELAY_MIN_MS)


func resolve_swing(m: int, target: int) -> Dictionary:
	# Vraci `{ok, hit, damage, absorbed, hp_left, killed, reason}` (docs/04 §4.6.4).
	# Vola se z `tick` v case `due_ms`; jde ale zavolat i PRIMO (AI a test).
	var mob = _mobile(m)
	if mob == null:
		return _fail_swing("no_mobile")
	var cil = _mobile(target)
	if cil == null:
		return _fail_swing("no_target")
	if not _weapons_ok:
		_message("You cannot fight: weapon data is missing.")
		return _fail_swing("no_data")
	if not mob.alive():
		_uklid(m)
		return _fail_swing("attacker_dead")
	if not cil.alive():
		_uklid(m)
		return _fail_swing("target_dead")

	var zbroj: Dictionary = _weapon(mob)
	var skill_atk: int = _skill_atk(zbroj)
	var skill_def: int = _skill_atk(_weapon(cil))
	if skill_atk < 0 or skill_def < 0:
		# Skill zbrane, ktery v `data/skills.json` neni, je VADA DAT: hlasime
		# a koncime - tiche dosazeni wrestlingu by z jine zbrane udelalo pest.
		push_warning("sim.combat: skill zbrane '%s' neni v data/skills.json"
			% str(zbroj.get("skill_used", "")))
		_message("You are not trained with that weapon.")
		return _fail_swing("skill_unknown")

	var atk: int = int(mob.skills.value(skill_atk))
	var def: int = int(cil.skills.value(skill_def))
	var hci: int = _hci(mob)
	var dci: int = _dci(cil)
	# Sance: `((atk+20)*(100+HCI)) / (2*(def+20)*(100+DCI))` (`BaseWeapon.cs:1453-1488`).
	# ⚠⚠ HODNOTY SE NEDELI 10 (vada nalezena 2026-10-10): skill je sice v
	# DESETINACH, ale stoji v CITATELI I VE JMENOVATELI, takze se meritko
	# VYKRATI (`(1000+200)/(1000+200) = 1`). Delenim 10 vychazela sance 10x
	# mensi (50/50 -> 0,05 misto 0,5) a padala na spodni mez 0,02 - hra by
	# nikdy netrefila. Konstantni cleny (+20) jsou v BODECH, proto se nasobi
	# 10, aby byly ve stejne jednotce jako skill (`+200` desetin).
	var horni: int = (atk + 200) * (100 + hci)
	var dolni: int = 2 * (def + 200) * (100 + dci)
	var chance: float = 0.0
	if dolni > 0:
		chance = float(horni) / float(dolni)
	chance = clampf(chance, HIT_MIN_CHANCE, 1.0)

	if not _rng.chance(chance):
		_message("You swing at %s and miss." % _jmeno(cil))
		_anim(m)
		if not _planuj(m):     # dalsi swing i po minutí (reference)
			_uklid(m)
		_combat_cleanup(m, cil)
		return {"ok": true, "hit": false, "damage": 0, "absorbed": 0,
			"hp_left": int(cil.hp), "killed": false, "reason": "miss",
			"target": int(target), "chance": chance}

	var base: int = _base_damage(mob, zbroj)
	var scaled: int = _scale_damage(mob, zbroj, base)
	var obrana: Dictionary = _obrana(cil, zbroj, scaled)
	var poskozeni: int = int(obrana["damage"])
	cil.hp = maxi(0, int(cil.hp) - poskozeni)
	var killed: bool = int(cil.hp) <= 0

	_message("You hit %s for %d damage." % [_jmeno(cil), poskozeni])
	_anim(m)
	_sound(m, "hit")
	_events_push("stats_changed", {"serial": int(cil.serial), "hp": int(cil.hp),
		"hp_max": int(cil.max_hp)})
	var out: Dictionary = {"ok": true, "hit": true, "damage": poskozeni,
		"absorbed": int(obrana["absorbed"]), "hp_left": int(cil.hp),
		"killed": killed, "reason": "", "target": int(target),
		"chance": chance, "resist": int(obrana["resist"]),
		"unknown_resist": bool(obrana["unknown"]), "direct": false}
	if killed:
		_anim_dir(cil, ACTION_DEATH)
		_events_push("sound", {"serial": int(cil.serial), "kind": "death"})
		if _death != null and _death.has_method("die"):
			# Telo, ducha a `mobile_removed` resi `sim.death` (jedno misto).
			_death.die(int(cil.serial))
		else:
			# Bez `sim.death` se smrt NESMI tvarit jako hotova - hlasime ji.
			_message("%s is dead." % _jmeno(cil))
		_uklid(m)
		return out
	if not _planuj(m):
		_uklid(m)
		return out
	_combat_cleanup(m, cil)
	return out


func tick(_ms: int) -> void:
	# SimWorld tickuje systemy po `advance(ms)`, takze cas je uz posunuty.
	# Splatne swingu se radi podle serialu (na poradi klicu slovniku nesmi
	# zaviset stav - stejny princip jako `sim.entity_registry.all()`).
	if _state.is_empty():
		return
	var now: int = _now()
	var hotovo: Array = []
	for m in _state.keys():
		var s = _state[m]
		if not (s is Dictionary):
			continue
		var mob = _mobile(int(m))
		if mob == null or not mob.alive():
			hotovo.append(int(m))
			continue
		var target: int = int(s.get("target", 0))
		if target == 0 or not bool(s.get("war", false)):
			continue
		var due: int = int(s.get("due_ms", 0))
		if due <= 0 or due > now:
			continue
		resolve_swing(int(m), target)
	for m in hotovo:
		_state.erase(m)


# -- mereni a integrace (nad ramec smlouvy) --------------------------------

func weapon_of(m: int) -> Dictionary:
	# Zbran v ruce jako zaznam z dat (prazdny slovnik = bez zbrane = wrestling).
	var mob = _mobile(m)
	return {} if mob == null else _weapon(mob)


func skill_of(m: int) -> int:
	# Id zbranoveho skillu, kterym mobil utoci (-1 = neznama zbran/data).
	var mob = _mobile(m)
	return -1 if mob == null else _skill_atk(_weapon(mob))


func weapon_speed(mob) -> int:
	# `speed` zbrane z dat; bez zbrane `WRESTLING_SPEED` (viz hlavicka).
	var zbroj: Dictionary = _weapon(mob)
	if zbroj.is_empty():
		return WRESTLING_SPEED
	return int(zbroj.get("speed", 0))


func skill_id(skill: int) -> String:
	for jmeno in _skill_id.keys():
		if int(_skill_id[jmeno]) == skill:
			return str(jmeno)
	return ""


func weapons_loaded() -> bool:
	return _weapons_ok


func armor_loaded() -> bool:
	return _armor_ok


func hit_chance(m: int, target: int) -> float:
	# Meritelna sance BEZ hodu (testy a klient): stejny vzorec jako
	# `resolve_swing`, jen bez `_rng.chance` - jinak by se sance "měnila"
	# spotrebou nahody.
	var mob = _mobile(m)
	var cil = _mobile(target)
	if mob == null or cil == null:
		return 0.0
	var atk: int = int(mob.skills.value(_skill_atk(_weapon(mob))))
	var def: int = int(cil.skills.value(_skill_atk(_weapon(cil))))
	var horni: int = (atk + 200) * (100 + _hci(mob))
	var dolni: int = 2 * (def + 200) * (100 + _dci(cil))
	if dolni <= 0:
		return 0.0
	# Bez deleni 10 - viz komentar v `resolve_swing` (meritko se vykrati).
	return clampf(float(horni) / float(dolni), HIT_MIN_CHANCE, 1.0)


func state() -> Dictionary:
	# Stav boje JE stav sveta (kdo s kym bojuje a kdy mu to uderi) - data pro
	# save/hash, i kdyz ho smlouva v `state_hash()` nevyjmenovava.
	var out: Dictionary = {}
	for m in _state.keys():
		var s = _state[m]
		if not (s is Dictionary):
			continue
		out[str(int(m))] = {"war": bool(s.get("war", false)),
			"target": int(s.get("target", 0)), "due_ms": int(s.get("due_ms", 0)),
			"delay_ms": int(s.get("delay_ms", 0))}
	return {"combat": out}


func restore(d: Dictionary) -> void:
	_state = {}
	if not (d is Dictionary):
		return
	for k in (d.get("combat", {}) as Dictionary).keys():
		var s = d["combat"][k]
		if not (s is Dictionary):
			continue
		_state[int(str(k))] = {"war": bool(s.get("war", false)),
			"target": int(s.get("target", 0)), "due_ms": int(s.get("due_ms", 0)),
			"delay_ms": int(s.get("delay_ms", 0)), "started_ms": 0}


# -- vnitrni: planovani ----------------------------------------------------

func _planuj(m: int) -> bool:
	# Naplanuje dalsi swing. `false` = rychlost NENI ZNAMA (zbran bez `speed`)
	# a swing se neplanuje - tiche "0 ms" by znamenalo nekonecne rychly utok.
	var delay: int = swing_delay_ms(m)
	if delay <= 0:
		push_warning("sim.combat: zbran bez 'speed' - swing se neplanuje")
		_st(m)["due_ms"] = 0
		_st(m)["delay_ms"] = 0
		return false
	_st(m)["delay_ms"] = delay
	_st(m)["due_ms"] = _now() + delay
	_anim(m)
	return true


func _combat_cleanup(m: int, cil) -> void:
	# Cil umrel? Uklidime; jinak boj pokracuje (uklid po prvnim minutí by
	# znamenal, ze se hrac s monstrem nikdy neutka).
	if cil == null or not cil.alive():
		_uklid(m)


func _uklid(m: int) -> void:
	_state.erase(m)


# -- vnitrni: hit chance ---------------------------------------------------

func _hci(mob) -> int:
	# HCI z vlastnosti predmetu (`props["hit_chance"]`); strop 45 (`BaseWeapon.cs:1451`).
	var bonus: int = 0
	if _equipment != null and _equipment.has_method("bonus"):
		bonus = int(_equipment.bonus(int(mob.serial), "hit_chance"))
	return clampi(bonus, 0, _hci_cap)


func _dci(mob) -> int:
	var bonus: int = 0
	if _equipment != null and _equipment.has_method("bonus"):
		bonus = int(_equipment.bonus(int(mob.serial), "defend_chance"))
	return clampi(bonus, 0, _dci_cap)


# -- vnitrni: damage ------------------------------------------------------

func _base_damage(mob, zbroj: Dictionary) -> int:
	# `min_damage`/`max_damage` zbrane (`data/weapons.json`); `mob.damage` je
	# pro TVORY, kteri zbran nemaji (monstra z `data/monsters.json`).
	var lo: int = int(zbroj.get("min_damage", 0))
	var hi: int = int(zbroj.get("max_damage", 0))
	if zbroj.is_empty() or hi <= 0:
		# `damage` monstra z `data/monsters.json`: hleda se v `ai.data`, protoze
		# `entity.mobile` pole `damage` NEMA a `Object.set()` na nedeklarovanou
		# vlastnost nic neudela (namEReno 2026-10-11; zapisuje `sim.spawn`).
		var dmg = _data_of(mob, "damage")
		if dmg is Array and (dmg as Array).size() >= 2:
			lo = int(dmg[0])
			hi = int(dmg[1])
		else:
			lo = WRESTLING_MIN
			hi = WRESTLING_MAX
	if hi < lo:
		hi = lo
	return _rng.range_i(lo, hi)


func _data_of(mob, klic: String):
	# Data monstra z `mob.ai["data"]` (`sim.spawn`), zaloha `mob.get(klic)` pro
	# pripad, ze `entity.mobile` nekdy dostane vlastni pole. JEDNO misto, kde se
	# vi, odkud data monstra jsou - druhe by znamenalo dve pravdy.
	var ai = mob.get("ai")
	if ai is Dictionary:
		var data = (ai as Dictionary).get("data")
		if data is Dictionary and (data as Dictionary).has(klic):
			return (data as Dictionary)[klic]
	return mob.get(klic)


func _scale_damage(mob, zbroj: Dictionary, base: int) -> int:
	# `damage + (int)(damage * totalBonus)` (`BaseWeapon.cs:3812-3815`).
	var bonus: float = 0.0
	bonus += _get_bonus(float(mob.stats.str_), BONUS_STR, OFFSET_STR)
	bonus += _get_bonus(float(_skill(mob, "Anatomy")), BONUS_ANATOMY, OFFSET_ANATOMY)
	bonus += _get_bonus(float(_skill(mob, "Tactics")), BONUS_TACTICS, OFFSET_TACTICS)
	if _je_axe(zbroj):
		bonus += _get_bonus(float(_skill(mob, "Lumberjacking")), BONUS_LUMBER, OFFSET_LUMBER)
	bonus += float(mini(_di(mob, zbroj), DI_CAP)) / 100.0
	return maxi(base + int(base * bonus), 1)


func _get_bonus(value: int, scalar: float, offset: float) -> float:
	# `GetBonus` (`BaseWeapon.cs:3663-3673`): `value*scalar/100`, +offset pri
	# `value >= 100`. Skill je v DESETINACH, proto se deli 10 (100.0 = 1000).
	var v: float = float(value) / float(SKILL_PER_POINT)
	var bonus: float = v * scalar
	if v >= BONUS_THRESHOLD:
		bonus += offset
	return bonus / 100.0


func _di(mob, zbroj: Dictionary) -> int:
	# Damage Increase: vlastnost zbrane (`props["damage_increase"]`,
	# `AosAttribute.WeaponDamage`), strop 100 % (`BaseWeapon.cs:3804-3809`).
	var di: int = int(zbroj.get("damage_increase", 0))
	if _equipment != null and _equipment.has_method("bonus"):
		di += int(_equipment.bonus(int(mob.serial), "damage_increase"))
	return di


func _obrana(cil, zbroj: Dictionary, dmg: int) -> Dictionary:
	# `Σ(dmg * podil * (100 - resist)) / 10000`, minimum 1 (`AOS.cs:168-206`).
	# Podily: 100 % pro jeden typ (nas model zbrane), 5 typu z AoS. Kdo ma v
	# datech `damage_types`, dostane presny rozpad.
	var typy: Dictionary = _typy(zbroj)
	var soucet: int = 0
	var vahy: int = 0
	var nezname: bool = false
	var prvni: int = 0
	var klice: Array = typy.keys()
	klice.sort()
	for typ in klice:
		var podil: int = int(typy[typ])
		if podil <= 0:
			continue
		var resist = _resist(cil, str(typ))
		if resist == null:
			# NEMERENO: bez `data/armor.json` resist NEZNAme. Dosadit nulu by
			# znamenalo "nema zbroj" a damage by vylhal nahoru, proto se typ
			# VYNECHA a volajici to vidi v `unknown`.
			nezname = true
			continue
		if prvni == 0:
			prvni = int(resist)
		soucet += dmg * podil * (100 - int(resist))
		vahy += podil
	var obrana: int = 0
	if vahy > 0:
		obrana = soucet / ARMOR_SCALE
		# Minimum 1 (`AOS.cs:205-206`) plati JEN kdyz je aspon jeden typ ZMERENY.
		# ⚠⚠ 2026-10-11 (namEReno): kdyz se typ VYNECHAL (`resist == null`), je
		# `vahy == 0` a dosazene minimum 1 snizilo damage na 1, i kdyz jsme o
		# obrane nevedeli NIC - presne to je "ticha nula", kterou smlouva
		# zakazuje (docs/09 §9.10). NEMERENO proto nechava damage CELE a hlasi
		# `unknown: true`.
		obrana = maxi(obrana, ARMOR_MIN_DAMAGE)
		obrana = mini(obrana, dmg)      # obrana nikdy nepridava zivoty
	else:
		obrana = dmg                    # NEMERENO: nic se nenizi
	return {"damage": obrana, "absorbed": maxi(dmg - obrana, 0),
		"resist": prvni, "unknown": nezname}


func _typy(zbroj: Dictionary) -> Dictionary:
	# Rozpad damage na typy; chybejici `damage_types` = 100 % fyzicke
	# (jedina hodnota, ktera je u bezne zbrane merena - `AOS.cs:170`).
	#
	# ⚠⚠ JMENA TYPU V DATEch NEJSOU AoS TYPY (namEReno 2026-10-11 nad realnym
	# `data/weapons.json`): `damage_type` je tam **`Slashing`/`Axe`/`Piercing`**
	# - to je ANIMACNI/zbranovy typ zbrane, ne rezistentni typ. Rezistentni
	# typy AoS jsou presne PET (`AOS.cs:170-174`: phys, fire, cold, pois, nrgy).
	# Dokud `sim.world.spawn` nepredava `damage_types` (rozpad na pet typu),
	# vsechno ostatni se bere jako FYZICKE - kdyby se "Slashing" dosadil jako
	# neznamej typ, `_resist` by ho nenasel a damage by spadl na minimum 1
	# (presne to se stalo a namERilo: `obrana.damage == 1`).
	var dt = zbroj.get("damage_types")
	if dt is Dictionary and not (dt as Dictionary).is_empty():
		var out: Dictionary = {}
		for k in (dt as Dictionary).keys():
			out[_typ_resist(str(k))] = int((dt as Dictionary)[k])
		return out
	return {_typ_resist(str(zbroj.get("damage_type", ""))): 100}


func _typ_resist(typ: String) -> String:
	# Normalizace na PET rezistentnich typu AoS; vsechno ostatni = physical
	# (viz komentar v `_typy`). Je to ROZHODNUTI KLONU a je videt tady.
	var t: String = typ.to_lower()
	if t == "fire" or t == "cold" or t == "poison" or t == "energy" or t == "physical":
		return t
	return "physical"


func _resist(cil, typ: String):
	# Resisty: (1) nasazena zbroj (`data/armor.json` nebo `resist` na predmetu),
	# (2) `resist` monstra z `data/monsters.json` (kontrakt M5 §3.4) - ten je
	# v `ai.data`, protoze `entity.mobile` pole `resist` NEMA a `Object.set()`
	# na nedeklarovanou vlastnost nic neudela (namEReno 2026-10-11).
	# `null` = NEMERENO (nikdy nula, ktera by vypadala jako "bez zbroje").
	var z = _equipment_resist(cil, typ)
	if z != null:
		return z
	var mv = _data_of(cil, "resist")
	if mv is Dictionary and (mv as Dictionary).has(typ):
		return int((mv as Dictionary)[typ])
	return null


func _equipment_resist(cil, typ: String):
	if _equipment == null or not _equipment.has_method("at_layer"):
		return null
	var equip = cil.get("equip")
	if not (equip is Dictionary):
		return null
	var soucet: int = 0
	var nasel: bool = false
	for layer in (equip as Dictionary).keys():
		var serial: int = int((equip as Dictionary)[layer])
		var item = _item(serial)
		if item == null:
			continue
		var r = _item_resist(item, typ)
		if r != null:
			soucet += int(r)
			nasel = true
	return soucet if nasel else null


func _item_resist(item, typ: String):
	var r = item.get("resist")
	if r is Dictionary and (r as Dictionary).has(typ):
		return int((r as Dictionary)[typ])
	if _armor_ok:
		var rec: Dictionary = _armor.get(str(item.get("type")), {})
		var rr = rec.get("resist")
		if rr is Dictionary and (rr as Dictionary).has(typ):
			return int((rr as Dictionary)[typ])
	return null


func _je_axe(zbroj: Dictionary) -> bool:
	# Lumber bonus plati JEN pro sekery (`BaseWeapon.cs:3793-3796`);
	# typ zbrane je z DAT (`data/weapons.json: type`), ne z hlavy.
	var t: String = str(zbroj.get("type", "")).to_lower()
	return t.contains("axe")


# -- vnitrni: zbran a skilly ----------------------------------------------

func _weapon(mob) -> Dictionary:
	# Zbran v ruce: vrstva 1 (jednorucni) ma prednost pred 2 (obourucni/stit).
	if mob == null:
		return {}
	var equip = mob.get("equip")
	if not (equip is Dictionary):
		return {}
	for layer in [LAYER_ONE_HANDED, LAYER_TWO_HANDED]:
		var serial: int = int((equip as Dictionary).get(layer, 0))
		if serial == 0:
			continue
		var item = _item(serial)
		if item == null:
			continue
		var rec: Dictionary = _najdi_zbran(item)
		if not rec.is_empty():
			return rec
	return {}


func _najdi_zbran(item) -> Dictionary:
	# Zbran se hleda podle ART ID (`weapons.json: art` je TILEDATA ID, `item.tile`
	# je ART = tiledata + 0x4000 - kontrakt M5 §3.1).
	var art: int = int(item.tile) - int(ItemScript.ITEM_OFFSET)
	for k in _weapons.keys():
		var rec: Dictionary = _weapons[k]
		if int(rec.get("art", -1)) == art:
			return rec
	var jmeno: String = str(item.get("type", "")).to_lower()
	if jmeno != "" and _weapons.has(jmeno):
		return _weapons[jmeno]
	return {}


func _skill_atk(zbroj: Dictionary) -> int:
	# Zbranovy skill utocnika (`BaseWeapon.cs:1430`); bez zbrane WRESTLING.
	var jmeno: String = str(zbroj.get("skill_used", ""))
	if jmeno == "":
		return int(_skill_id.get("Wrestling", WRESTLING_ID_FALLBACK))
	return int(_skill_id.get(jmeno, -1))


func _skill(mob, jmeno: String) -> int:
	var sid: int = int(_skill_id.get(jmeno, -1))
	return 0 if sid < 0 else int(mob.skills.value(sid))


# -- vnitrni: data --------------------------------------------------------

func _load_weapons(d, path: String) -> void:
	# `data/weapons.json` je SEZNAM zaznamu (kontrakt M5 §3.1). Chybejici
	# soubor se HLASI (push_warning) - nikdy tiche nuly.
	if d == null:
		push_warning("sim.combat: chybi " + path + " - souboj nebude fungovat")
		return
	if not (d is Array):
		push_warning("sim.combat: " + path + " neni seznam")
		return
	for rec in d:
		if not (rec is Dictionary):
			continue
		var jmeno: String = str(rec.get("name", ""))
		if jmeno == "":
			jmeno = str(rec.get("type", ""))
		if jmeno == "":
			continue
		_weapons[jmeno.to_lower()] = rec
		_weapons[str(rec.get("type", ""))] = rec
	_weapons_ok = not _weapons.is_empty()
	if not _weapons_ok:
		push_warning("sim.combat: " + path + " nema zadnou zbran")


func _load_armor(d, path: String) -> void:
	# `data/armor.json` (kontrakt M5 §3.2). Neni-li, resisty se NEMERI a
	# `_obrana` to vraci v `unknown: true` - nikdy ticha nula.
	if d == null:
		push_warning("sim.combat: chybi " + path + " - resisty zbroje se nemeri")
		return
	if not (d is Array):
		push_warning("sim.combat: " + path + " neni seznam")
		return
	for rec in d:
		if rec is Dictionary and str(rec.get("type", "")) != "":
			_armor[str(rec["type"])] = rec
	_armor_ok = not _armor.is_empty()


func _load_skills(path: String) -> void:
	# Mapa jmeno -> id z `data/skills.json` (`id` = index, docs/04 §4.2).
	var d = _read_json(path)
	if d == null:
		push_warning("sim.combat: chybi " + path + " - zbranove skilly se nedaji vyhledat")
		return
	if not (d is Array):
		return
	for i in (d as Array).size():
		var rec = d[i]
		if rec is Dictionary and str(rec.get("name", "")) != "":
			_skill_id[str(rec["name"])] = int(rec.get("id", i))


func _read_balance(path: String) -> void:
	# Stropy jsou DATA (`docs/05 §5.16.3`, pravidlo 2) - jeden klic, ne dvacet
	# `if`. Chybejici klic = vychozi hodnota z hlavicky.
	var d = _read_json(path)
	if not (d is Dictionary):
		return
	var c = (d as Dictionary).get("combat")
	if not (c is Dictionary):
		return
	_hci_cap = int((c as Dictionary).get("hci_cap", _hci_cap))
	_dci_cap = int((c as Dictionary).get("dci_cap", _dci_cap))
	_ssi_cap = int((c as Dictionary).get("ssi_cap", _ssi_cap))
	_direct_cap = int((c as Dictionary).get("direct_damage_cap", _direct_cap))


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# -- vnitrni: zaklad -------------------------------------------------------

func _st(m: int) -> Dictionary:
	if not (_state.get(m) is Dictionary):
		_state[m] = {"war": false, "target": 0, "due_ms": 0, "delay_ms": 0,
			"started_ms": _now()}
	return _state[m]


func _mobile(m: int):
	return null if _registry == null else _registry.get_mobile(m)


func _item(serial: int):
	if serial <= 0:
		return null
	if _items is Dictionary:
		return (_items as Dictionary).get(serial)
	if _items is Object and _items.has_method("get_item"):
		return _items.get_item(serial)
	return null


func _now() -> int:
	return int(_clock.now_ms())


func _scale(v: int, percent: int) -> int:
	# `AOS.Scale` (`Scripts/Misc/AOS.cs`): celociselne procento, zadny float.
	if percent == 0:
		return 0
	return int(float(v) * float(percent) / 100.0)


func _jmeno(mob) -> String:
	var n: String = str(mob.get("name"))
	return n if n != "" else "it"


func _anim(m: int) -> void:
	# `mobile_anim{serial, action, frame_ms}` (kontrakt M5 §2); 2 = attack.
	_anim_dir(m, ACTION_ATTACK)


func _anim_dir(m: int, akce: int) -> void:
	_events_push("mobile_anim", {"serial": m, "action": akce,
		"frame_ms": int(Const.TURN_MS)})


func _sound(m: int, kind: String) -> void:
	# Zvuk (kontrakt M5 §2: `sound`; klient zatim ignoruje, D5).
	_events_push("sound", {"serial": m, "kind": kind})


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)


func _message(text: String) -> void:
	_events_push("message", {"text": text, "kind": "combat"})


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "target": 0, "war": false, "delay_ms": 0}


func _fail_swing(reason: String) -> Dictionary:
	return {"ok": false, "hit": false, "damage": 0, "absorbed": 0, "hp_left": 0,
		"killed": false, "reason": reason, "target": 0, "chance": 0.0}
