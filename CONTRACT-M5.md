# CONTRACT-M5 — pracovní kontrakt pro milník M5 (souboj, monstra, smrt, loot)

> **⛔ TENTO SOUBOR JE MRTVÝ — NEPOUŽÍVEJ HO.** Vznikl 2026-10-11 jako pracovní
> dohoda pro paralelní session a **byl v průběhu práce dvakrát opraven proti
> realitě** (níže). Závazná je `docs/04`, `docs/05` a `HANDOFF.md`. Nechává se
> jen proto, aby bylo vidět, CO se v dohodě rozešlo s měřením — než se smaže.

## Co se v kontraktu rozešlo s měřením (a co platí)

| # | Co tu stálo | Co je naměřeno | Kde to platí |
|---|---|---|---|
| 1 | §3.1 `speed = 50 − speed_raw` | **`speed = AosSpeed`** (ServUO `v = (Stam+100)*Speed`, `BaseWeapon.cs:1598-1615`); `50 − raw` dávalo 128/133 zbraní delay 4–100 s | `data/weapons.json: speed_source`, `docs/04 §4.6.4` |
| 2 | §3.1 příklad `Dagger … swing_delay_ms 250` | Dagger má `speed 56` → **2000 ms**; `speed 30` (→3000 ms) je **přijímací číslo**, ne hodnota v datech | `tests/cases/combat.gd` |
| 3 | §2 „tick(ms) pro všechny systémy“ | sedí, ale `sim.world_loop` volá `tick(ms)`, jen když ho systém má | `sim/sim_world.gd` |
| 4 | §2 `death.die()` u hráče | `die()` **odmítne živého** (`reason:"alive"`) — `hp` musí dát 0 volající (combat) | `sim/systems/death.gd` |
| 5 | §3.4 data monstra na mobilu | `Object.set()` na **nedeklarovanou** vlastnost je v Godotu 4 **tiché no-op** → data monster žijí v `mob.ai["data"]` | `sim/world/spawn.gd`, `sim/systems/combat.gd:_data_of` |
| 6 | §3.4 `anim.attack/die` | sedí (`high`: attack 4, die 2; `low`: attack 5, die 8) | `tools/uoextract/anim.py` |


## 0. Stav před prací (naměřeno 2026-10-10)

* `git log -1` = `b697e0f`, `git status` čistý.
* testy: **1852 kontrol / 0 selhání** (`godot --headless --script res://tests/run_tests.gd`).
* `attack` v `sim/commands.gd` routuje na `systems["combat"].attack`; systém
  v `SimWorld.SYSTEM_ORDER` je, ale **instance neexistuje** → „Not available yet“.
* `sim/entity/registry.gd` je stavový zdroj `entities` (mobily se ukládají).
* `app/main.gd` je integrační místo: registruje systémy do `sim.systems`.

## 1. Co je hotové a NEMĚNÍ SE (jen číst)

`core/`, `sim/entity/*` (mobile, item, container, equipment, registry, skills,
stats, notoriety), `sim/world/*`, `sim/commands.gd` (kromě budoucí úpravy
`attack` → hotová je), `sim/systems/{movement,interaction,harvest,craft,vendor,
regen,skill_gain}.gd`, `tests/run_tests.gd` (**needituje se**), `tools/gates/**`
(needituje se bez zápisu v `docs/`).

⚠ **`attack` do `ACTION_KINDS` politiky patří do TOHOTO milníku** — hlídat, aby
nevznikla mrtvá slovní zásoba (G4).

## 2. Sdílené rozhraní — systémy v `sim.systems`

`SimWorld` volá `tick(ms)`, když ho systém má, jinak `tick()`.
`sim.commands.dispatch` volá metody podle mapy `SYSTEM_ORDER`.

| systém | metoda (volá dispatch / jiný systém) | návrat |
|---|---|---|
| `combat` | `attack(m:int, target:int) -> Dictionary` | `{ok, reason, hit, damage, absorbed, hp_left, killed, target, delay_ms}` |
| `combat` | `set_war(m:int, on:bool) -> Dictionary` | `{ok, war}` |
| `combat` | `swing_delay_ms(m:int) -> int` | ms |
| `combat` | `stop_combat(m:int) -> Dictionary` | `{ok}` |
| `combat` | `state_of(m:int) -> Dictionary` | `{war, target, next_swing_ms, in_combat}` |
| `death` | `die(m:int) -> Dictionary` | `{ok, serial, corpse, ghost, items}` |
| `death` | `resurrect(m:int, hp:int) -> Dictionary` | `{ok, hp}` |
| `death` | `is_ghost(m:int) -> bool` | |
| `loot` | `fill_corpse(mob, corpse) -> Dictionary` | `{ok, gold, items, pack}` |
| `loot` | `roll_magic_item(level:int) -> Dictionary` | `{}` + hlášení (D4) |
| `decay` | `tick(ms)` | odstraní tělo po 7 min, předmět na zemi po 60 min |
| `ai` | `tick(ms)` (svět) + `tick_mobile(m)` / `think(m) -> Dictionary` | `{state, action}` |
| `spawn` | `tick(ms)` + `register(point) -> int` + `state()`/`restore(d)` | |
| `spawn` | `alive_at(point_id) -> int` + `state()` | počty pro měření |

### Události (jen `push_event`, nikdy přímé volání UI)

`message`, `mobile_anim{serial, action, frame_ms}`, `mobile_moved`, `mobile_added
{serial, body, hue, name, x, y, z, notoriety}`, `mobile_removed{serial}`,
`stats_changed{serial, hp, hp_max}`, `death{serial, corpse}`, `item_added{...}`
(tvar jako `sim/systems/interaction.gd:_item_event`), `sound{...}` (klient zatím
ignoruje, D5), `gump_open` (existující).

**Akce animace (abstraktní id klienta):** 0 = walk, 1 = run, **2 = attack**,
**3 = death**, 4 = idle.

## 3. Datové kontrakty (soubory `data/*.json`)

Všechny záznamy mají `source` (odkud) — bez něj brána `check-content`/schema
hlásí chybu. Id prostor: `data/items.json` má TILEDATA ID; `entity.item.tile` je
ART ID = tiledata + 0x4000.

### 3.1 `data/weapons.json` (134 záznamů, `research/_src/weapons3.json`)

```json
{"name":"Dagger","art":3921,"skill_used":"Fencing","hands":1,
 "min_damage":10,"max_damage":12,"speed":50,"speed_raw":40,"swing_delay_ms":250,
 "strength_req":10,"weight":10,"durability":30,"layer":1,"special_move":"InfectiousStrike",
 "material":"iron","era":"aos","type":"dagger","source":"research/_src/weapons3.json"}
```

* `art` = TILEDATA ID z `weapons3.json` (`ItemID & 0x3FFF`); kdo staví
  `entity.item`, přičte `0x4000`.
* **`speed` = 50 − `speed_raw`** (ServUO `BaseWeapon.Speed`). Kontrakt:
  `swing_delay_ms(stam=100, speed=30) == 3000`. Subagent MUSÍ ověřit na datech,
  že `floor(40000/((100+100)*speed))*500 ms` dá pro `speed_raw` z `weapons3.json`
  rozumné hodnoty a do záznamu zapsat i `swing_delay_ms` pro stam 100.
* `layer` z tiledata (`world.tiledata.layer`), dokud není → `layer:null` +
  `layer_source:"pending-tiledata"`.
* `skill_used` = jméno skillu z `data/skills.json` (např. `Fencing`), mapa
  z klasických jmen (Swordsmanship → Swordsmanship, MaceFighting → Mace Fighting,
  Archery → Archery, Wrestling → Wrestling, Fencing → Fencing) — **kdo mapuje,
  ověří proti `data/skills.json` a zapíše `skill_source`.**

### 3.2 `data/armor.json` (165, `research/_src/armor_raw.json`)

```json
{"name":"Leather Cap","art":5393,"slot":"head","layer":2,"ar":2,
 "resist":{"physical":2,"fire":2,"cold":2,"poison":2,"energy":2},
 "str_req":10,"weight":2,"durability":30,"material":"leather",
 "era":"aos","type":"leather_cap","source":"research/_src/armor_raw.json"}
```

### 3.3 `data/item_properties.json` (159, `research/_src/itemprops_table.tsv`)

```json
[{"name":"DamageIncrease","type":"int","range":[1,50],"scales":false,
  "source":"research/_src/itemprops_table.tsv"}]
```

### 3.4 `data/monsters.json` (M5 vlna: rat, skeleton, zombie + alespoň 12 z §3)

```json
{"type":"skeleton","name":"a skeleton","body":50,"anim_group":"high",
 "anim":{"walk":0,"attack":4,"die":2},
 "str":[56,80],"dex":[56,75],"int":[16,40],"hits":[34,48],"mana":[0,0],
 "damage":[3,7],"virtual_armor":16,
 "resist":{"physical":0,"fire":0,"cold":0,"poison":0,"energy":0},
 "skills":{"MagicResist":[451,600],"Tactics":[451,600],"Wrestling":[451,550]},
 "fame":450,"karma":-450,"loot_pack":"poor","ai":"melee",
 "flags":["undead"],"notoriety":4,
 "source":"research/06 §3.1 (ServUO Scripts/Mobiles/Normal/*.cs)"}
```

* `anim_group`: `high` = tělo < 200, `low` = 200..399 (`tools/uoextract/anim.py`
  `mul_slot`, NAMĚŘENÉ). `anim.walk/attack/die` = **číslo akce v `anim.mul`**
  (`high` = `HighAnimationGroup`, `low` = `LowAnimationGroup`; enumerace
  `_src/classicuo/.../AnimationsLoader.cs:1694-1777`).
* `skills` = desetiny (45.1 → 451), jak je zvykem v `entity.skills`.

### 3.5 `data/spawns.json` (M5 vlna: 1 tabulka — hřbitov u Britainu)

```json
{"points":[{"id":"graveyard_britain","x":1495,"y":1630,"radius":6,
  "max":3,"delay_ms":[300000,600000],
  "monsters":["skeleton","zombie","rat"],"source":"docs/04 §4.6.7; rozhodnutí D2"}]}
```

Prodleva 5–10 min a refill `max((max-spawned)/3, 1)` jsou naměřené
(`docs/04` §4.6.7).

## 4. Dělba souborů (jeden soubor = jeden vlastník)

| vlastník | soubory |
|---|---|
| **data** | `data/weapons.json`, `data/armor.json`, `data/item_properties.json`, `data/monsters.json`, `data/spawns.json`, `tools/gates/gen-content.py`, `_analyza/p41-gen-m5.py` |
| **sim** | `sim/systems/combat.gd`, `sim/systems/death.gd`, `sim/systems/loot.gd`, `sim/systems/poison.gd`, `sim/systems/ai.gd`, `sim/systems/decay.gd`, `sim/world/spawn.gd` |
| **assets** | `tools/uoextract/anim.py` (jen `--export` data, ne kód), `assets/uo/anim/**` |
| **tests** | `tests/cases/combat.gd`, `loot.gd`, `death.gd`, `ai.gd`, `spawn.gd`, `decay.gd`, `poison.gd`, `render_anim.gd` (jen DOPLNĚNÍ) |
| **lead (já)** | `app/main.gd`, `app/loop.gd`, `app/input_map.gd`, `app/player_controller.gd`, `app/world_view.gd`, `render/animation.gd`, `render/name_plates.gd`, `sim/commands.gd` (jen `attack` už je), `docs/**`, `HANDOFF.md`, `LESSONS.md` |

## 5. Pravidla, která platí bez výjimky

1. **`tests/run_tests.gd` se needituje**; nové case soubory jsou v pořádku.
2. **Test musí kód ZAVOLAT** a měřit hodnotu (ne `has_method`).
3. **Testy jsou nepodmíněné**: chybí-li soubor granule, test SPADNE.
4. **Náhodu jen z `sim.rng()`**, čas z `sim.clock()`, serialy `sim.next_serial()`;
   `sim/` nesmí `Input`/`Time`/`OS`/`randf()` (G2).
5. **Stav časovačů patří do systému/mobilu** (`due_ms`), ne Callable do clocku.
6. **Hotové moduly se nemění bez zápisu v `docs/`.**
7. **Nula a prázdno nejsou úspěch** — co se neměřilo, se hlásí.
8. Po každé změně spustit `godot --headless --path . --script res://tests/run_tests.gd`
   (baseline 1852/0) a `python tools/gates/run-all.py`.
