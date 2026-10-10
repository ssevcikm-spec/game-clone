extends RefCounted
# Regenerace hp/stam/mana (granule `sim.regen`, smlouva docs/04 §4.2, hodnoty
# docs/05 §5.14 a research/01 §1.4).
#
# ODKUD CISLA (nic neni vymyslene, kazde ma radek v reference):
#   * hp   - interval `1/(0,1*(1+HitPointRegen))` s = **10 s** pri bonusu 0,
#            +1 hp za tik (`_src/servuo/Scripts/Misc/RegenRates.cs:77-80`),
#   * stam - interval `1/(0,1*(2+bonus))` s = **5 s** pri bonusu 0, +1 za tik
#            (`RegenRates.cs:82-108`); bonus = Focus*0,1 + StamRegen z predmetu,
#   * mana - AoS vetev `1/(0,1*(2+totalPoints))` (`RegenRates.cs:154-178`) s
#            `medPoints = (INT + Meditation*3) * 0,025` (0,0275 od 100,0) a
#            `totalPoints = focusPoints + medPoints`. Focus je `implemented: false`
#            (`data/skills.json`), tedy 0; bonusy z predmetu se NECTou (viz nize),
#   * vsechny tri handlery se v reference instaluji pod `Core.AOS`
#            (`RegenRates.cs:29-33`) a `data/balance.json` ma `era.combat: "aos"`,
#            proto se berou AoS intervaly. Pre-AoS fallback je 11 s / 7 s / 7 s
#            (`RegenRates.cs:23-25`) - pouzije se, az bude mit regen vlastni klic
#            v `data/balance.json` (ten soubor vlastni jina granule, ne tohle).
#
# STAV JE CELE CISLO (docs/09 §9.10.3): hp/stam/mana i akumulatory ms jsou int.
# Float je jen v LOKALNIM vypoctu intervalu many (stejne jako sance v
# `sim.skill_gain`) - do stavu se nikdy neuklada.
#
# CO SMLOUVA NEPINUJE (patri do docs/04 §4.2, agent docs/ needituje):
#   * `_init(registry, clock, hunger)` - zavislosti KONSTRUKTOREM (jako
#     `world.walk` a `sim.movement`), aby sel `tick()` merit bez `SimWorld`.
#     `tick()` nema argument casu, proto bere cas z `core.clock` (docs/04 §4.2),
#   * `hunger_gate_on()` - VIDITELNY stav chybejici zavislosti: `sim.hunger`
#     dnes v repu NEEXISTUJE (`sim/systems/hunger.gd` neni), takze se hlad
#     NEMERI a modul funguje dal. Ticha napodobenina by predstirala pravidlo,
#   * `tick()` NEPOSILA udalost: `stats_changed` (docs/04 §4.4) nese i `weight`
#     a `gold`, ktere regen nezna - poslat je jako nuly by status bar vylhal
#     (chybejici klic = 0, `ui.status_bar`),
#   * meditace sedic (`docs/05 §5.14`) neni: neexistuje stav "sedim", ktery by
#     ji nesl (patri `ui`/`sim.magic`, ne sem),
#   * akumulator ms NENI soucasti ulozeneho stavu - po `load` se ztrati nejvyse
#     jeden interval (hlasim; `sim.save` je jina granule).
#
# HLAD (docs/05 §5.14: "hlad ovlivnuje regeneraci", detail UNVERIFIED): kdyz je
# `hunger` predan a `level(m) <= 0`, je interval hp **2x delsi**. Je to
# DOPORUCENI research/01 (radky 1774-1782: "hits regen rate x2 slower or
# disabled") a ROZHODNUTI KLONU, ne opsane cislo. Stupnice `level` neni zmerena
# (modul neexistuje), proto se pouziva jen prah `<= 0`.

const ClockScript = preload("res://core/clock.gd")
const RegistryScript = preload("res://sim/entity/registry.gd")

const SKILL_MEDITATION := 46        # `data/skills.json`: id 46 = Meditation (index = id)
const MEDITATION_3 := 0.3           # (Meditation v desetinach) * 3 / 10
const COEF_LOW := 0.025             # `Meditation < 100,0` (`RegenRates.cs:158`)
const COEF_HIGH := 0.0275           # od 100,0
const HITS_MS := 10000              # 1/(0,1*(1+0)) s
const STAM_MS := 5000               # 1/(0,1*(2+0)) s
const HUNGRY_HP_MULT := 2           # rozhodnuti klonu, viz hlavicka

var _registry = null
var _clock = null
var _hunger = null                  # `sim.hunger` (chybi) - viz `hunger_gate_on()`
var _last_ms: int = 0
var _akum: Dictionary = {}          # serial -> {"hp_ms", "stam_ms", "mana_ms"}


func _init(registry = null, clock = null, hunger = null) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_clock = clock if clock != null else ClockScript.new()
	_hunger = hunger
	# Zakladna casu je pri konstrukci: prvni `tick()` uz ma mereny interval.
	_last_ms = int(_clock.now_ms())


func hunger_gate_on() -> bool:
	# NEMERENO hlad = `false`; volajici to vidi a nesmi z toho delat "neni hlad".
	return _hunger != null and _hunger.has_method("level")


func tick() -> void:
	# Bez argumentu (smlouva): cas jde z `core.clock`. Prvni tick po konstrukci
	# ma `dt = 0` a nic nemeni - "tik bez casu" neni regen.
	var now := int(_clock.now_ms())
	var dt: int = now - _last_ms
	_last_ms = now
	if dt <= 0:
		return
	for mob in _registry.all():
		if mob == null or not mob.alive():
			continue                     # mrtvy neregeneruje (`Mobile.cs:1909`)
		_tick_mobile(mob, dt)


# -- vnitrni ---------------------------------------------------------------

func _tick_mobile(mob, dt: int) -> void:
	var acc: Dictionary = _akum.get(int(mob.serial), {})
	# Hlad zpomaluje JEN hp (docs/05 §5.14 + research/01): celociselne puleni
	# prirustku, takze zustava vse v int (ztrata < 1 ms na tik).
	var hp_dt: int = dt
	if _hungry(mob):
		hp_dt = dt / HUNGRY_HP_MULT
	_pridej(mob, acc, "hp_ms", hp_dt, HITS_MS, "hp", "max_hp")
	_pridej(mob, acc, "stam_ms", dt, STAM_MS, "stam", "max_stam")
	_pridej(mob, acc, "mana_ms", dt, _mana_ms(mob), "mana", "max_mana")
	_akum[int(mob.serial)] = acc


func _pridej(mob, acc: Dictionary, klic: String, dt: int, interval: int,
		hodnota: String, strop: String) -> void:
	# Tri resource maji stejny akumulator (int ms), proto `get`/`set` jmeny:
	# `hp`/`stam`/`mana` jsou prostě vlastnosti mobila (docs/04 §4.5).
	if interval <= 0:
		return
	var max_hodnota := int(mob.get(strop))
	if int(mob.get(hodnota)) >= max_hodnota:
		# Plno: akumulator se NESBIRA (jinak by po ubrání hp prisel "fantom" bod).
		acc[klic] = 0
		return
	var ms := int(acc.get(klic, 0)) + dt
	while ms >= interval:
		ms -= interval
		var nova := int(mob.get(hodnota)) + 1
		mob.set(hodnota, mini(nova, max_hodnota))
		if nova >= max_hodnota:
			ms = 0                       # strop: dal se neakumuluje
			break
	acc[klic] = ms


func _mana_ms(mob) -> int:
	# AoS vetev (`RegenRates.cs:154-178`); Focus = 0 (neni implementovany).
	var med := float(mob.skills.value(SKILL_MEDITATION))
	var body := float(mob.stats.int_) + med * MEDITATION_3
	var coef: float = COEF_LOW if med < 1000.0 else COEF_HIGH
	var total: float = body * coef
	if total < -1.0:
		total = -1.0
	return int(round(1000.0 / (0.1 * (2.0 + total))))


func _hungry(mob) -> bool:
	if not hunger_gate_on():
		return false
	return int(_hunger.level(int(mob.serial))) <= 0
