extends RefCounted
# sim.policy - PRAVIDLA S PODMINKAMI (granule `sim.policy`, milnik MK).
#
# CO TO JE (rozhodnuti D3, `ROZHODNUTI-2026-10-09-SMER.md` §2): tri vrstvy.
# UMYSL zadava hrac, POLITIKA jsou pravidla s podminkami a prioritami a
# PROVEDENI dela simulace. Tenhle modul je prostredni vrstva: dostane STAV
# sveta a vrati ROZHODNUTI - sam nic nevykonava, na stav nesaha a nic si
# nepamatuje mezi volanimi (`evaluate` je funkce stavu).
#
# PRAVIDLA JSOU DATA, NE JAZYK (zadani §3, doporuceni): podminka je
# `{"kind": "...", "args": {...}}` s PEVNYM SLOVNIKEM (`CONDITION_KINDS`),
# priorita je cislo a akce je `{"kind": "...", "args": {...}}`. Vnorovane
# `and`/`or` nebo vyrazy by byly ADITIVNI rozsireni, az na ne bude konkretni
# potreba - dnes by to byl jazyk bez pripadu.
#
# TVAR DAT (JSON v `user://`, cte ho `SimWorld.load_policy`):
#   {"version": 1, "rules": [
#      {"id": "buy_pickaxe", "priority": 50,
#       "when": {"kind": "item_below", "args": {"item": "3717", "count": 1}},
#       "then": {"kind": "vendor", "args": {"action": "buy", "vendor": 1, "lines": []}}}]}
#
# STAV, KTERY PODMINKY CTou (nic jineho - chybejici klic je VIDET v duvodu):
#   world_time_ms : int               herni cas (ms)
#   inventory     : {item: count}     co ma postava u sebe
#   backpack      : {count, max}      zaplneni batohu
#   skills        : {"<index>": int}  hodnoty skillu v desetinach
#   flags         : {name: bool}      pojmenovane stavy ("u_kovare": true)
# Nula a "nevim" NEJSOU totez: chybejici klic se nikdy necte jako 0, ale jako
# duvod `stav nezna: <klic>` (`docs/09 §9.6` - nemerena nula neni uspech).
#
# DETERMINISMUS (docs/02 §2.3): pravidla se seradi uz pri `load()` podle
# (priorita sestupne, id vzestupne), takze na poradi v datech nezalezi a dve
# stejna data daji stejna rozhodnuti. Zadny `randf()`, zadny cas z `Time`.
# `evaluate` NEMENI stav (jen ho cte) - kdyby menila, rozesel by se hash
# i replay (`state_hash()` se tim NEMENI: politika neni stavovy zdroj).
#
# CO ZATIM NENI (pojmenovane, ne tichy dluh): `priority_of` neumi priority
# odvozene z kontextu (jen cislo z pravidla); akce se nevaliduji proti stavu
# (to dela `sim.executor` pres `sim.commands.validate`, aby `Command` platil).

const Const = preload("res://core/const.gd")

const DEFAULT_PRIORITY: int = 0

# Pevny slovnik PODMINEK. Kdo prida novou, musi ji mit v `_check()` - jinak se
# pravidlo pri `load()` odmitne (viditelne v `errors()`), ne tise ignoruje.
const CONDITION_KINDS: Array[String] = [
	"always",
	"item_below",
	"item_at_least",
	"inventory_full",
	"skill_below",
	"flag",
	"time_between",
]
# Pevny slovnik AKCI. Preklad na `Command` je v `sim/executor.gd` (jedno misto,
# kde se z rozhodnuti stava prikaz; tady se jen kontroluje, ze druh existuje).
const ACTION_KINDS: Array[String] = [
	"move", "use", "interact", "craft", "vendor", "say", "wait", "stop",
]

var _version: int = 0
var _rules: Array[Dictionary] = []
var _errors: Array[String] = []
var _skipped: Array[Dictionary] = []


func load(source) -> bool:
	# `source` je rozparsovany JSON (Dictionary) nebo TEXT JSON. Vraci false,
	# kdyz data nejdou precist NEBO nezustane ani jedno platne pravidlo -
	# "nacteno, ale prazdno" by se tvarilo jako aktivni politika.
	_errors.clear()
	_rules.clear()
	_skipped.clear()
	var data = source
	if source is String:
		# `JSON.new().parse()` (ne `JSON.parse_string`): ta druha u vady PISE
		# do logu enginu `ERROR: Parse JSON failed ...`, coz v testech vypada
		# jako selhani. Chyba se hlasi slovem - v `errors()`.
		var json := JSON.new()
		if json.parse(source) != OK:
			_errors.append("JSON: " + json.get_error_message())
			return false
		data = json.get_data()
		if data == null:
			_errors.append("JSON: prazdna data")
			return false
	if not (data is Dictionary):
		_errors.append("data nejsou slovnik (" + str(typeof(data)) + ")")
		return false
	_version = int(data.get("version", 0))
	var raw = data.get("rules", [])
	if not (raw is Array):
		_errors.append("'rules' neni seznam")
		return false
	var ids: Dictionary = {}
	var rows: Array[Dictionary] = []
	for i in raw.size():
		var rule = raw[i]
		if not (rule is Dictionary):
			_errors.append("pravidlo %d neni slovnik" % i)
			continue
		var problem: String = _validate(rule, ids)
		if problem != "":
			_errors.append("pravidlo %d: %s" % [i, problem])
			continue
		ids[str(rule["id"])] = true
		rows.append(rule)
	rows.sort_custom(_rule_before)
	_rules = rows
	if _rules.is_empty():
		_errors.append("zadne platne pravidlo (nacteno 0 z %d)" % raw.size())
		return false
	return true


func evaluate(state) -> Array[Dictionary]:
	# Vsechna pravidla, jejichz podminka plati - serazena podle priority.
	# Nesplnena (i "nevim") pravidla se ukladaji do `last_skipped()`, aby se
	# dal zapsat DUVOD, ne jen vysledek (`sim.decision_log`).
	_skipped = []
	var out: Array[Dictionary] = []
	if not (state is Dictionary):
		_skipped.append({"rule_id": "-", "why": "stav neni slovnik"})
		return out
	for rule in _rules:
		var res: Dictionary = _check(rule["when"], state)
		var why: String = str(res["why"])
		if bool(res["met"]):
			out.append({
				"rule_id": str(rule["id"]),
				"priority": priority_of(rule),
				"action": (rule["then"] as Dictionary).duplicate(true),
				"why": why,
			})
		else:
			_skipped.append({"rule_id": str(rule["id"]), "why": why})
	return out


func priority_of(rule) -> int:
	# Vyssi cislo = drive. Bere i `id` (retezec) - v logu se rozhodnuti
	# dohledava podle jmena, ne podle poradi v datech.
	if rule is Dictionary:
		return int(rule.get("priority", DEFAULT_PRIORITY))
	if rule is String:
		for r in _rules:
			if str(r.get("id", "")) == rule:
				return int(r.get("priority", DEFAULT_PRIORITY))
	return DEFAULT_PRIORITY


# -- co se hodí vedet (nad ramec `provides`) -------------------------------

func last_skipped() -> Array[Dictionary]:
	# Pravidla, ktera pri POSLEDNIM `evaluate()` neprosla - s duvodem.
	return _skipped.duplicate(true)


func errors() -> Array[String]:
	# Co se odmitlo pri `load()` (viditelne, ne tise preskocene).
	return _errors.duplicate()


func rules() -> Array[Dictionary]:
	return _rules.duplicate(true)


func rule_count() -> int:
	return _rules.size()


func version() -> int:
	return _version


# -- vnitrni ---------------------------------------------------------------

func _rule_before(a: Dictionary, b: Dictionary) -> bool:
	# Totalni poradi: priorita sestupne, pak id vzestupne (id je unikatni,
	# takze dva ruzne prvky nejsou nikdy "rovne" - jinak by poradi rozhodoval
	# vstup a determinismus by stál na nahode).
	var pa: int = priority_of(a)
	var pb: int = priority_of(b)
	if pa == pb:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return pa > pb


func _validate(rule: Dictionary, ids: Dictionary) -> String:
	var id: String = str(rule.get("id", ""))
	if id.is_empty():
		return "chybi 'id'"
	if ids.has(id):
		return "duplicitni 'id' (" + id + ")"
	if not (rule.get("when") is Dictionary):
		return "chybi 'when' (slovnik)"
	if not (rule.get("then") is Dictionary):
		return "chybi 'then' (slovnik)"
	var when: Dictionary = rule["when"]
	var then: Dictionary = rule["then"]
	if not (when.get("kind", "") in CONDITION_KINDS):
		return "neznamy druh podminky '" + str(when.get("kind", "")) + "'"
	if not (then.get("kind", "") in ACTION_KINDS):
		return "neznamy druh akce '" + str(then.get("kind", "")) + "'"
	if not (when.get("args", {}) is Dictionary):
		return "'when.args' musi byt slovnik"
	if not (then.get("args", {}) is Dictionary):
		return "'then.args' musi byt slovnik"
	return ""


func _check(cond: Dictionary, state: Dictionary) -> Dictionary:
	match str(cond.get("kind", "")):
		"always":
			return _met(true, "podminka 'always' plati")
		"item_below", "item_at_least":
			return _check_item(str(cond.get("kind", "")), cond.get("args", {}), state)
		"inventory_full":
			return _check_inventory_full(state)
		"skill_below":
			return _check_skill(cond.get("args", {}), state)
		"flag":
			return _check_flag(cond.get("args", {}), state)
		"time_between":
			return _check_time(cond.get("args", {}), state)
	return _met(false, "neznamy druh podminky: " + str(cond.get("kind", "")))


func _met(ok: bool, why: String) -> Dictionary:
	return {"met": ok, "why": why}


func _check_item(kind: String, args: Dictionary, state: Dictionary) -> Dictionary:
	if not state.has("inventory"):
		return _met(false, "stav nezna: inventory")
	if not (state["inventory"] is Dictionary):
		return _met(false, "stav nezna: inventory neni slovnik")
	var inv: Dictionary = state["inventory"]
	var item: String = str(args.get("item", ""))
	var need: int = int(args.get("count", 0))
	var have: int = int(inv.get(item, 0))
	var ok: bool = (have < need) if kind == "item_below" else (have >= need)
	var znak: String = "<" if kind == "item_below" else ">="
	return _met(ok, "item %s: %d %s %d" % [item, have, znak, need])


func _check_inventory_full(state: Dictionary) -> Dictionary:
	if state.has("backpack"):
		if not (state["backpack"] is Dictionary):
			return _met(false, "stav nezna: backpack neni slovnik")
		var bp: Dictionary = state["backpack"]
		var count: int = int(bp.get("count", 0))
		var max_items: int = int(bp.get("max", 0))
		if max_items <= 0:
			return _met(false, "stav nezna: backpack.max")
		return _met(count >= max_items, "batoh: %d/%d" % [count, max_items])
	if state.has("inventory_full"):
		var full: bool = bool(state["inventory_full"])
		return _met(full, "inventory_full = " + str(full))
	return _met(false, "stav nezna: backpack")


func _check_skill(args: Dictionary, state: Dictionary) -> Dictionary:
	if not state.has("skills") or not (state["skills"] is Dictionary):
		return _met(false, "stav nezna: skills")
	var skills: Dictionary = state["skills"]
	var idx: String = str(int(args.get("skill", -1)))
	var need: int = int(args.get("value", 0))
	var have: int = int(skills.get(idx, -1))
	if have < 0:
		return _met(false, "stav nezna: skill " + idx)
	return _met(have < need, "skill %s: %d < %d" % [idx, have, need])


func _check_flag(args: Dictionary, state: Dictionary) -> Dictionary:
	if not state.has("flags") or not (state["flags"] is Dictionary):
		return _met(false, "stav nezna: flags")
	var flags: Dictionary = state["flags"]
	var jmeno: String = str(args.get("name", ""))
	if not flags.has(jmeno):
		return _met(false, "stav nezna: flag " + jmeno)
	var want: bool = bool(args.get("is", true))
	var have: bool = bool(flags[jmeno])
	return _met(have == want, "flag %s: %s (cekano %s)" % [jmeno, str(have), str(want)])


func _check_time(args: Dictionary, state: Dictionary) -> Dictionary:
	if not state.has("world_time_ms"):
		return _met(false, "stav nezna: world_time_ms")
	var ms_per_hour: int = Const.DAY_LENGTH_MS / 24
	var hour: int = posmod(int(state["world_time_ms"]), Const.DAY_LENGTH_MS) / ms_per_hour
	var from_h: int = int(args.get("from_hour", 0))
	var to_h: int = int(args.get("to_hour", 24))
	# Okno se smi preklenout pres pulnoc (22 -> 6): pak plati "od NEBO do".
	var ok: bool = false
	if from_h <= to_h:
		ok = hour >= from_h and hour < to_h
	else:
		ok = hour >= from_h or hour < to_h
	return _met(ok, "hodina %d v <%d,%d)" % [hour, from_h, to_h])
