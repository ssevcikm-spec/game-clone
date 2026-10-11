extends RefCounted
# AI monster a NPC (granule `sim.ai`; smlouva docs/04 §4.2 a tok §4.6.7,
# pravidla docs/05 §5.12).
#
# MAPOVANI STAVU (kontrakt M5 §5): nase stavy odpovidaji akcnimu typu
# reference `ActionType` (`_src/servuo/Scripts/Mobiles/AI/BaseAI.cs:45-53`):
#
#   nas stav   | reference      | co to znamena
#   -----------|----------------|-----------------------------------------------
#   idle       | Interact/Guard | stoji, ale mysli; po `MOVE_TIMEOUT_MS` (10 s)
#              |                | se pohne (wander), po `HOME_TIMEOUT_MS` (60 s)
#              |                | bez cile jde zpet na `home`
#   vendor     | (nesmi se tiknout) | prodejce stoji na miste - `sim.vendor`
#              |                | neni AI; kdyby ho AI tikala, odesel by z kramu
#   wander     | Wander         | nahodny krok (jen pres `sim.movement`)
#   aggro      | Combat (pribl.)| cil je viden a je nepritel -> jde k nemu
#   attack     | Combat         | cil je na dosah -> `sim.combat.attack`
#   flee       | Flee / Backoff | hp <= 20 % -> krok od cile
#   dead       | (smazano)      | hp <= 0; nehrac se maze z registru (`sim.death`)
#
# MAPOVANI JE V KODU (ne v datech), protoze je to preklad jednoho slova:
# `_STAV_REFERENCE` nize. Kdo bude chtit jmena reference, dostane je odsud.
#
# RYCHLOST MYSLENI je `CurrentSpeed` v SEKUNDACH (`BaseAI.OnCurrentSpeedChanged`,
# `_src/servuo/Scripts/Mobiles/AI/BaseAI.cs:3031-3035`:
# `m_Timer.Interval = TimeSpan.FromSeconds(m_Mobile.CurrentSpeed)`).
# Reference ma pro monstra `ActiveSpeed`/`PassiveSpeed` z `SpeedInfo`
# (`SpeedInfo.cs:141-175`: slow 0.3/0.6, fast 0.2/0.4); kontrakt M5 §5 zadava
# **0,2 s v boji / 0,4 s v klidu**, proto jsou to VYCHOZI hodnoty a
# `mobile.ai["timer_ms"]` je bere z dat monstra, kdyz je ma
# (`speed.active_seconds`/`speed.idle_seconds`). Cisla nejsou v kódu dvakrat:
# `_aktivni_ms`/`_klidne_ms` je jedna pravda pro cely modul.
#
# ⚠ AI NEMA VLASTNI PRAVIDLA PRUCHODNOSTI ANI VLASTNI SEZNAM MOBILU
# (kontrakt M5 §5, tvrde): krok jde VYHRADNE pres `sim.movement.request_step`
# (`walk.can_step` je jedine misto s pravidly) a mobily se hledaji VYHRADNE
# v `sim.entity_registry` (`registry.all()`). Cesta se hleda pres
# `sim.pathfind.next_step` (`sim/world/pathfind.gd:125`), ktery se ptá
# `world.walk`; kdo pathfind nepreda, dostane PRIMY smer s nahodnym obchazenim
# prekazky - a to je pojmenovane omezeni, ne ticha napodobenina.
#
# AGGRO (docs/04 §4.6.7): "aggro jen kdyz IsHostile/IsEnemy a CanSee/InLOS
# (notoriety do agga nevstupuje)". Notoriety tu proto NENI; `CanSee`/`InLOS`
# nahrazuje `can_see` z konstruktoru (bez nej se vidi na `AGGRO_RANGE`, a to
# je ROZHODNUTI KLONU - je videt v `can_see_source()`).
#
# ROZHODNUTI KLONU (a proc):
#   * `AGGRO_RANGE = 10` dlazdic (reference `BaseCreature.AcquireOnApproach`
#     resi 10 dlazdic pro zvirata; pro monstra plati `PerceptionRange` z AI,
#     ktera v datech neni),
#   * `MELEE_RANGE = 1` (utok na dosah ruky; dosah zbrane je vec zbrane, ne AI),
#   * `FLEE_THRESHOLD_PCT = 20` (kontrakt M5 §5: "Flee: prah 20 % HP"),
#   * `RANGE_HOME = 10` (kontrakt M5 §5: "navrat domů RangeHome = 10"),
#   * `MOVE_TIMEOUT_MS = 10000`, `HOME_TIMEOUT_MS = 60000` (kontrakt M5 §5).
#
# KDO SE NETIKUJE (a proc je to tady, ne v integraci):
#   * **HRAC** - `app/main.gd:683` registruje hrace do STEJNEHO registru jako
#     monstra (`registry.register(player)`), takze bez teto brany by AI hnala
#     i hrace (`_najdi_nepritele` bere kazdy jiny mobil jako nepritele). Hrac se
#     pozna podle `set_player(serial)`; kdyz ji integrace nerekne, pouzije se
#     STEJNA zaloha jako v `sim.death._je_hrac` (`body` 400/401 =
#     `entity.mobile.gd:25`). Je to ZALOHA, ne druha pravda: kdo vi o hraci vic,
#     zavola `set_player`.
#   * **VENDOR** (`ai.state == "vendor"`, `docs/05 §5.12`) - prodejce je NPC,
#     ale ne AI; kdyby ho AI tikala, odesel by z kramu (`app/main.gd:1112`
#     nastavuje `kovar.ai = {"state": "vendor"}`).
#   * **MRTVY** - `hp <= 0`; smrt hlasi `sim.death`, tady se jen prepne stav.
#
# CO SMLOUVA NEPINUJE: `_init(...)` - zavislosti konstruktorem (`registry`,
# `movement`, `combat`, `clock`, `events`, `rng`, `can_see`, `pathfind`),
# `set_player(serial)` - kdo je hrac (viz vyse).

const RegistryScript = preload("res://sim/entity/registry.gd")
const RngScript = preload("res://core/rng.gd")
const ClockScript = preload("res://core/clock.gd")

const Const = preload("res://core/const.gd")

# Mapovani na akcni typ reference (`BaseAI.cs:45-53`) - viz hlavicka.
const _STAV_REFERENCE: Dictionary = {
	"idle": "Interact/Guard",
	"wander": "Wander",
	"aggro": "Combat",
	"attack": "Combat",
	"flee": "Flee",
	"dead": "-",
	"vendor": "- (AI se netikne; docs/05 §5.12)",
}

const STATE_IDLE := "idle"
const STATE_WANDER := "wander"
const STATE_AGGRO := "aggro"
const STATE_ATTACK := "attack"
const STATE_FLEE := "flee"
const STATE_DEAD := "dead"
const STATE_VENDOR := "vendor"

# Rychlost mysleni v ms (`CurrentSpeed` v sekundach, `BaseAI.cs:3031-3035`).
const ACTIVE_SPEED_MS := 200         # 0,2 s v boji (kontrakt M5 §5)
const IDLE_SPEED_MS := 400           # 0,4 s v klidu (kontrakt M5 §5)

# Rozhodnuti klonu (viz hlavicka).
const AGGRO_RANGE := 10
const MELEE_RANGE := 1
const FLEE_THRESHOLD_PCT := 20
const RANGE_HOME := 10
const MOVE_TIMEOUT_MS := 10000
# ⚠ 60 s, NE 10 s: kontrakt M5 §5 zadava `MOVE_TIMEOUT_MS` (10 s, "NPC se
# pohne") a `HOME_TIMEOUT_MS` (60 s, "po 60 s bez cile je zpet na home").
# NamEReno 2026-10-11: s `HOME_TIMEOUT_MS = 10000` se oba casovace slily do
# jednoho a NPC, ktery stoji na `home`, se po 10 s NEPOHNUL (vetev "uz stojim
# na home" vyhrala) - padaly kontroly "po 10 s ticha se NPC pohne".
const HOME_TIMEOUT_MS := 60000

var _registry = null
var _movement = null
var _combat = null
var _clock = null
var _events = null
var _rng = null
var _can_see = null
var _pathfind = null
# Kdo je hrac (`set_player`). Nula = "integrace to nerekla" a plati zaloha
# podle tela (viz hlavicka) - nikdy ticha nula.
var _player_serial: int = 0

# serial -> {due_ms, since_ms} - cas mysleni JE ve systemu (pravidlo 5).
var _casovace: Dictionary = {}


func _init(registry = null, movement = null, combat = null, clock = null,
		events = null, rng = null, can_see = null, pathfind = null) -> void:
	_registry = registry if registry != null else RegistryScript.new()
	_movement = movement
	_combat = combat
	_clock = clock if clock != null else ClockScript.new()
	_events = events
	_rng = rng if rng != null else RngScript.new(0)
	_can_see = can_see
	_pathfind = pathfind


# -- rozhrani podle smlouvy ------------------------------------------------

func tick(_ms: int) -> void:
	# SimWorld tickuje systemy po `advance(ms)`; mysleni ma vlastni kadenci
	# (`due_ms`), takze vetsina ticku nic nedela.
	if _registry == null:
		return
	var now: int = _now()
	for mob in _registry.all():
		if mob == null:
			continue
		if int(mob.serial) == 0:
			continue
		if not mob.alive():
			# Smrt hlasi `sim.death`; tady se jen stav prepne (a je videt).
			_stav(mob, STATE_DEAD)
			continue
		if _je_hrac(mob):
			continue                      # hrace ridi klient, ne AI (hlavicka)
		if _je_vendor(mob):
			continue                      # prodejce stoji (docs/05 §5.12)
		# Cas "bez cile" zacina v okamziku, kdy mobil poprve vidime: kdo nikdy
		# nemyslel, ma `_since` 0 = pocatek sveta (viz `_since`), ale jakmile
		# ho svet vidi, plyne mu ticho od NASEHO prvniho kroku.
		if not _casovace.has(int(mob.serial)):
			_casovace[int(mob.serial)] = {"due_ms": now, "since_ms": now}
		var due: int = int(_casovace.get(int(mob.serial), {}).get("due_ms", 0))
		if due > now:
			continue
		think(int(mob.serial))


func tick_mobile(m: int) -> Dictionary:
	# Mysleni JEDNOHO mobily (smlouva) - vraci `{state, action}`.
	return think(m)


func think(m: int) -> Dictionary:
	# Jedno kolo mysleni. Vraci `{state, action, target, moved, home}`.
	var mob = _mobile(m)
	if mob == null:
		return {"state": "", "action": "", "reason": "no_mobile"}
	if not mob.alive():
		_stav(mob, STATE_DEAD)
		return {"state": STATE_DEAD, "action": "", "target": 0, "moved": false,
			"reason": "dead"}
	# Hrac a vendor se NEMYSLI (viz hlavicka): kdo tuhle branu vypusti, necha AI
	# ovladat hrace, resp. prodejce odejit z kramu.
	if _je_hrac(mob):
		return {"state": str(_ai(mob).get("state", STATE_IDLE)), "action": "skip",
			"target": 0, "moved": false, "reason": "player"}
	if _je_vendor(mob):
		return {"state": STATE_VENDOR, "action": "skip", "target": 0,
			"moved": false, "reason": "vendor"}
	var stav: String = str(_ai(mob).get("state", STATE_IDLE))
	var pred: String = stav
	var cil: int = int(_ai(mob).get("target", 0))
	var akce: String = ""

	# 1. FLEE ma prednost pred vsim (docs/05 §5.12: "v nouzi se nikdy nesmi
	# zaseknout"; hp <= 20 % = utikej).
	if _ma_flee(mob):
		stav = STATE_FLEE
		if cil != 0:
			akce = "step_away"
			_krok_od(mob, cil)
		else:
			akce = "no_target"
	# 2. Boj: cil existuje, je zivy a viden -> aggro/attack.
	elif cil != 0 and _platny_cil(mob, cil):
		var vzdalenost: int = _vzdalenost(mob, _mobile(cil))
		if vzdalenost <= MELEE_RANGE:
			stav = STATE_ATTACK
			akce = _utok(mob, cil)
		else:
			stav = STATE_AGGRO
			akce = "step_to_target"
			_krok_ke(mob, _mobile(cil))
	else:
		# 3. Nema cil: hledej nepřítele, jinak se po domu.
		var cilny: int = _najdi_nepritele(mob)
		if cilny != 0:
			_ai(mob)["target"] = cilny
			var d_cil: int = _vzdalenost(mob, _mobile(cilny))
			if d_cil <= MELEE_RANGE:
				# Cil je na dosah UZ pri nalezene: utoc hned, ne az po kroku.
				stav = STATE_ATTACK
				akce = _utok(mob, cilny)
			else:
				stav = STATE_AGGRO
				akce = "step_to_target"
				_krok_ke(mob, _mobile(cilny))
		else:
			_ai(mob)["target"] = 0
			var doma: bool = _doma(mob)
			if not doma:
				# Dal od domu nez `RANGE_HOME` (10) -> zpet na `home`. Je to
				# pojistka z `docs/05 §5.12` ("NPC se nikdy nesmi zaseknout").
				stav = STATE_IDLE
				akce = "step_home"
				_krok_ke(mob, null, _home(mob))
			else:
				var ticho: int = _now() - _since(mob)
				if ticho >= HOME_TIMEOUT_MS:
					if _vzdalenost_domu(mob) == 0:
						# Uz stoji PRESNE na home: neni kam jit, takze se cas bez
						# cile zacne pocitat znovu (a po 10 s se zase zatoulá).
						stav = STATE_IDLE
						akce = "idle"
						_reset_ticha(mob)
					else:
						# 60 s bez cile -> zpet na home (i kdyz je bliz nez
						# `RANGE_HOME`). Tohle je prijimaci kriterium
						# `docs/04 §4.6.7` a `kontrakt M5 §5`.
						stav = STATE_IDLE
						akce = "step_home"
						_krok_ke(mob, null, _home(mob))
				elif ticho >= MOVE_TIMEOUT_MS:
					# 10 s v idle se musi pohnout (kontrakt M5 §5).
					stav = STATE_WANDER
					akce = "wander"
					_krok_nahodne(mob)
				else:
					stav = STATE_IDLE
					akce = "idle"

	_stav(mob, stav)
	var krok: int = _aktivni_ms(mob, stav)
	_casovace[int(mob.serial)] = {"due_ms": _now() + krok,
		"since_ms": int(_casovace.get(int(mob.serial), {}).get("since_ms", _now()))}
	_events_push("ai_state", {"serial": int(mob.serial), "state": stav,
		"prev": pred, "action": akce, "target": int(_ai(mob).get("target", 0))})
	return {"state": stav, "action": akce, "target": int(_ai(mob).get("target", 0)),
		"moved": akce.begins_with("step") or akce == "wander",
		"home": _doma(mob), "think_ms": krok}


# -- mereni a integrace (nad ramec smlouvy) --------------------------------

func state_of(m: int) -> String:
	var mob = _mobile(m)
	return "" if mob == null else str(_ai(mob).get("state", STATE_IDLE))


func set_player(serial: int) -> void:
	# Kdo je hrac (`app/main.gd:674` zna `sim.player_serial`). Bez toho plati
	# zaloha podle tela (viz `_je_hrac`) - a `player_source()` to rekne.
	_player_serial = int(serial)


func player_serial() -> int:
	return _player_serial


func player_source() -> String:
	return "set_player" if _player_serial > 0 else "body-400/401"


func enemy_source() -> String:
	# Odkud AI bere "nepritele": dnes jen hrac (viz `_je_nepritel`). Kdo prida
	# frakce, zmeni tuhle jednu funkci a tady to bude videt.
	return "player-only (M5: jeden hrac; frakce patri do dalsiho milniku)"


func is_vendor(m: int) -> bool:
	var mob = _mobile(m)
	return mob != null and _je_vendor(mob)


func reference_state(nas_stav: String) -> String:
	# Jmeno akcniho typu reference (`BaseAI.cs:45-53`) pro nasi stav.
	return str(_STAV_REFERENCE.get(nas_stav, "?"))


func think_interval_ms(m: int) -> int:
	var mob = _mobile(m)
	return 0 if mob == null else _aktivni_ms(mob, str(_ai(mob).get("state", STATE_IDLE)))


func aggro_range() -> int:
	return AGGRO_RANGE


func flee_threshold_pct() -> int:
	return FLEE_THRESHOLD_PCT


func range_home() -> int:
	return RANGE_HOME


func can_see_source() -> String:
	return "injected" if _can_see != null else "range-only"


func state() -> Dictionary:
	# Kdo je na rade a kdy (stav casovacu mysleni); stav mobilu sam je
	# v `registry` (`entities`).
	var out: Dictionary = {}
	for s in _casovace.keys():
		out[str(int(s))] = {"due_ms": int(_casovace[s].get("due_ms", 0)),
			"since_ms": int(_casovace[s].get("since_ms", 0))}
	return {"ai_timers": out}


func restore(d: Dictionary) -> void:
	_casovace = {}
	if not (d is Dictionary):
		return
	for k in (d.get("ai_timers", {}) as Dictionary).keys():
		var e = d["ai_timers"][k]
		if not (e is Dictionary):
			continue
		_casovace[int(str(k))] = {"due_ms": int(e.get("due_ms", 0)),
			"since_ms": int(e.get("since_ms", 0))}


# -- vnitrni: rozhodnuti ---------------------------------------------------

func _ma_flee(mob) -> bool:
	# hp <= 20 % maxima (kontrakt M5 §5). Max 0 nema smysl (prazdny mobil).
	var maxhp: int = int(mob.max_hp)
	if maxhp <= 0:
		return false
	return int(mob.hp) * 100 <= maxhp * FLEE_THRESHOLD_PCT


func _platny_cil(mob, cil: int) -> bool:
	var c = _mobile(cil)
	if c == null or not c.alive():
		return false
	return _vidi(mob, c)


func _najdi_nepritele(mob) -> int:
	# Nejbližší nepritel v `AGGRO_RANGE`, ktereho vidime. Notoriety PROTI HRACI
	# sem NEVSTUPUJE (docs/04 §4.6.7: "notoriety do agga nevstupuje") - hrac je
	# nepritel vzdy (single-player). Dva mobily proti sobe neboji: `_je_nepritel`
	# je niz (viz hlavicka) a je to pojmenovane omezeni M5.
	var nej: int = 0
	var nej_d: int = AGGRO_RANGE + 1
	for c in _registry.all():
		if c == null or int(c.serial) == int(mob.serial) or not c.alive():
			continue
		if not _je_nepritel(mob, c):
			continue
		var d: int = _vzdalenost(mob, c)
		if d > AGGRO_RANGE:
			continue
		if not _vidi(mob, c):
			continue
		if d < nej_d:
			nej = int(c.serial)
			nej_d = d
	return nej


func _je_nepritel(mob, cil) -> bool:
	# NEPRITEL = HRAC (`_je_hrac`). Proc takhle uzce:
	#   * `docs/04 §4.6.7` chce `IsHostile/IsEnemy`, ale notoriety nam v datech
	#     monstra nerozlisuje prately a neprately v ramci sveta (vsichni maji
	#     `notoriety: 3` = "lze utocit") - dva kostlivci na sobe se tedy NESMI
	#     rvat, jinak by se spawn hřbitova vybil sam,
	#   * M5 ma JEDNOHO hrace (`sim.player_serial`), takze nepratelstvi v ramci
	#     NPC patri do dalsiho milniku (frakce/guildy) - je to VIDET pres
	#     `enemy_source()`, ne ticha napodobenina pravidla.
	return _je_hrac(cil)


func _je_hrac(mob) -> bool:
	# Hrac se pozna z `set_player`; kdyz ji integrace nerekne, plati STEJNA
	# zaloha jako v `sim.death._je_hrac` (`body` 400/401 = `mobile.gd:25`).
	# Je to ZALOHA, ne druha pravda: kdo vi o hraci vic, zavola `set_player`.
	# ⚠ Dosah zalohy: dokud nejsou jini humanoidni NPC nez prodejci, je to
	# bezpecne (prodejce odchyti `_je_vendor`); lidsky guard by se musel
	# vyjmout pres `set_player`/vlastni branou - je to pojmenovane omezeni.
	if _player_serial > 0:
		return int(mob.serial) == _player_serial
	var body: int = int(mob.body)
	return body == 400 or body == 401


func _je_vendor(mob) -> bool:
	# `ai.state == "vendor"` (`docs/05 §5.12` a `app/main.gd:1112`). AI prodejce
	# NESMI tiknout - jinak by odesel z kramu.
	return str(_ai(mob).get("state", "")) == STATE_VENDOR


func _vidi(mob, cil) -> bool:
	# `CanSee`/`InLOS` z reference (`docs/04 §4.6.7`). Kdyz `can_see` neni
	# predan, plati jen vzdalenost - a `can_see_source()` to rekne (nikdy
	# ticha napodobenina).
	if _can_see != null and _can_see is Callable and (_can_see as Callable).is_valid():
		return bool((_can_see as Callable).call(mob, cil))
	return _vzdalenost(mob, cil) <= AGGRO_RANGE


func _vzdalenost(a, b) -> int:
	# Chebyshev (dlazdicova) vzdalenost - stejna, jakou pouziva `InRange(1)`.
	if a == null or b == null:
		return 9999
	return maxi(absi(int(a.pos.x) - int(b.pos.x)), absi(int(a.pos.y) - int(b.pos.y)))


func _doma(mob) -> bool:
	# "Doma" = do `RANGE_HOME` (10) dlazdic od `home` (kontrakt M5 §5).
	var h: Vector3i = _home(mob)
	var d: int = maxi(absi(int(mob.pos.x) - int(h.x)), absi(int(mob.pos.y) - int(h.y)))
	return d <= RANGE_HOME


func _home(mob) -> Vector3i:
	var h = _ai(mob).get("home", Vector3i.ZERO)
	if h is Vector3i:
		return h
	if h is Array and (h as Array).size() >= 3:
		return Vector3i(int((h as Array)[0]), int((h as Array)[1]), int((h as Array)[2]))
	return Vector3i.ZERO


func _since(mob) -> int:
	# Kdy naposledy mobil NEMEL cil (zacatek "ticha" pro 10s/60s timeout).
	# Kdo mobil jeste nikdy nemyslel (prime `think()` bez `tick()`), dostane 0
	# = pocatek sveta: ticho se pak meri od nuly. Je to VEN konzervativni
	# volba - mobil se muze pohnout jen DRIV, nikdy pozdeji. `tick()` pritom
	# zapisuje `since_ms = now` pri prvnim spatreni, takze v produkci ticho
	# plyne od okamziku, kdy mobil prisel do sveta.
	var e = _casovace.get(int(mob.serial), {})
	return int(e.get("since_ms", 0)) if e is Dictionary else 0


func _reset_ticha(mob) -> void:
	# "Ticho" zacina znovu: pouziva se ve chvili, kdy uz je mobil na `home` a
	# neni kam se vracet (jinak by kazdy dalsi tik znovu planoval cestu domu).
	var e: Dictionary = _casovace.get(int(mob.serial), {})
	e["since_ms"] = _now()
	_casovace[int(mob.serial)] = e


func _vzdalenost_domu(mob) -> int:
	# Chebyshev vzdalenost od `home` v dlazdicich (0 = stoji na home).
	var h: Vector3i = _home(mob)
	return maxi(absi(int(mob.pos.x) - int(h.x)), absi(int(mob.pos.y) - int(h.y)))


# -- vnitrni: krok (JEN pres sim.movement) ---------------------------------

func _krok_ke(mob, cil, cil_pos = null) -> String:
	# Krok k cili. PREDNOST ma `sim.pathfind.next_step` (`sim/world/pathfind.gd:125`),
	# ktery se ptá `world.walk` - AI tedy NIKDY nema vlastni pravidla
	# pruchodnosti. Bez pathfindingu (neni predan) se jde PRIMYM smerem a
	# obchazeni je nahodne: to je pojmenovane omezeni, ne tichy kompromis.
	var c: Vector3i = cil_pos if cil_pos is Vector3i else (cil.pos if cil != null else mob.pos)
	if _pathfind != null and _pathfind.has_method("next_step"):
		var krok: Vector3i = _pathfind.next_step(mob.pos, c)
		if krok != mob.pos:
			var smer_p: int = _smer_krok(mob.pos, krok)
			if smer_p >= 0 and bool(_request(mob, smer_p).get("ok", false)):
				return "step_path"
	var smer: int = _smer_k(mob.pos, c)
	if smer < 0:
		return "at_target"
	var vysledek: Dictionary = _request(mob, smer)
	if bool(vysledek.get("ok", false)):
		return "step"
	# Zablokovano: zkus sousedni smery (obe strany od primého) - "monstrum
	# obchazi rohy" (`docs/05 §5.1.2`), ale nikdy neporusuje pravidla walk.
	for odchylka in [1, -1, 2, -2, 3, -3, 4]:
		var s2: int = posmod(smer + odchylka, 8)
		if bool(_request(mob, s2).get("ok", false)):
			return "step_around"
	return str(vysledek.get("reason", "blocked"))


func _smer_krok(od: Vector3i, do_pos: Vector3i) -> int:
	# Smer kroku, ktery vrati `sim.pathfind.next_step` (sousedni dlazdice).
	var dx: int = int(do_pos.x) - int(od.x)
	var dy: int = int(do_pos.y) - int(od.y)
	for s in 8:
		if int(Const.DIR_DX[s]) == dx and int(Const.DIR_DY[s]) == dy:
			return s
	return -1



func _krok_od(mob, cil: int) -> String:
	var c = _mobile(cil)
	if c == null:
		return "no_target"
	var smer: int = _smer_k(mob.pos, c.pos)
	if smer < 0:
		return "at_target"
	var opacny: int = posmod(smer + 4, 8)
	if bool(_request(mob, opacny).get("ok", false)):
		return "step_away"
	for odchylka in [1, -1]:
		if bool(_request(mob, posmod(opacny + odchylka, 8)).get("ok", false)):
			return "step_away_around"
	return "blocked"


func _krok_nahodne(mob) -> String:
	# Nahodny smer z `sim.rng` (nikdy `randi()`); zkusi vsech 8, aby se
	# monstrum nezaseklo v rohu.
	var prvni: int = _rng.range_i(0, 7)
	for i in 8:
		var s: int = posmod(prvni + i, 8)
		if bool(_request(mob, s).get("ok", false)):
			return "wander"
	return "blocked"


func _request(mob, smer: int) -> Dictionary:
	# JEDINE misto, kde AI hybe svetem: `sim.movement.request_step`
	# (`walk.can_step` je jedina pravda o pruchodnosti). AI si NEDRZI vlastni
	# seznam kroku - ptá se `pending_step`, aby neztratila krok na "busy".
	if _movement == null or not _movement.has_method("request_step"):
		push_warning("sim.ai: bez `sim.movement` se AI nemuze pohnout")
		return {"ok": false, "reason": "no_movement"}
	if _movement.has_method("pending_step") \
			and not _movement.pending_step(int(mob.serial)).is_empty():
		return {"ok": false, "reason": "busy"}
	return _movement.request_step(int(mob.serial), smer, false)


func _smer_k(od: Vector3i, do_pos: Vector3i) -> int:
	# Smer 0..7 z `Const.DIR_DX/DIR_DY` (`core/const.gd:45-46`): 0 = vychod,
	# dale proti smeru hodinovych rucicek. Vybira se ten, ktery snizi
	# vzdalenost NEJVIC; pri rovnosti rozhoduje poradi (determinismus).
	var dx: int = int(do_pos.x) - int(od.x)
	var dy: int = int(do_pos.y) - int(od.y)
	if dx == 0 and dy == 0:
		return -1
	var nej: int = -1
	var nej_d: int = 1 << 30
	for s in 8:
		var nx: int = int(od.x) + int(Const.DIR_DX[s])
		var ny: int = int(od.y) + int(Const.DIR_DY[s])
		var d: int = maxi(absi(nx - int(do_pos.x)), absi(ny - int(do_pos.y)))
		if d < nej_d:
			nej_d = d
			nej = s
	return nej


func _utok(mob, cil: int) -> String:
	# Utok jde pres `sim.combat.attack` (AI nema vlastni vzorce) - ten
	# naplanuje swing a `sim.combat.tick` ho vykona.
	if _combat == null or not _combat.has_method("attack"):
		push_warning("sim.ai: bez `sim.combat` se AI nemuze utocit")
		return "no_combat"
	var s = _combat.state_of(int(mob.serial))
	if bool(s.get("war", false)) and int(s.get("target", 0)) == cil:
		return "already_attacking"      # neplanuj druhy swing ve stejnem case
	var r: Dictionary = _combat.attack(int(mob.serial), cil)
	return "attack" if bool(r.get("ok", false)) else "attack_failed"


# -- vnitrni: stav ---------------------------------------------------------

func _ai(mob) -> Dictionary:
	# `mobile.ai` je slovnik (`mobile.gd:47`): {state, target, home, timer_ms}.
	# Kdo ho nema (cizi objekt), dostane novy a je to jeho stav.
	var a = mob.get("ai")
	if not (a is Dictionary):
		a = {"state": STATE_IDLE, "target": 0, "home": Vector3i.ZERO, "timer_ms": 0}
		mob.set("ai", a)
	return a


func _stav(mob, stav: String) -> void:
	var a: Dictionary = _ai(mob)
	if str(a.get("state", "")) == stav:
		return                            # zmena stavu je UDALOST, ne spam
	a["state"] = stav


func _aktivni_ms(mob, stav: String) -> int:
	# `CurrentSpeed` v sekundach (`BaseAI.cs:3031-3035`) - v boji 0,2 s,
	# v klidu 0,4 s (kontrakt M5 §5). Data monstra to mohou prepsat
	# (`speed.active_seconds`/`idle_seconds`) a `mobile.ai["timer_ms"]` to
	# nese dal, aby se kadenec nemusela pocitat dvakrat.
	var v_boji: bool = stav == STATE_AGGRO or stav == STATE_ATTACK or stav == STATE_FLEE
	var ms: int = ACTIVE_SPEED_MS if v_boji else IDLE_SPEED_MS
	var prekryv = _ai(mob).get("speed")
	if prekryv is Dictionary:
		var klic: String = "active_ms" if v_boji else "idle_ms"
		if int((prekryv as Dictionary).get(klic, 0)) > 0:
			ms = int((prekryv as Dictionary)[klic])
	return ms


func _mobile(m: int):
	return null if _registry == null else _registry.get_mobile(m)


func _now() -> int:
	return int(_clock.now_ms())


func _events_push(name: String, data: Dictionary) -> void:
	if _events != null:
		_events.push(name, data)
