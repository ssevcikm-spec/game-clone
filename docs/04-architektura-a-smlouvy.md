# 4. Architektura a smlouvy

> Oddíl je **zdroj pravdy pro rozhraní**. Agent nehádá jména ani tvary dat —
> bere je odsud. Když tu něco chybí, doplní se **nejdřív dokument** a pak kód
> (`09-pravidla-pro-agenta.md` §3).

## 4.1 Vrstvy a směry závislostí

Závislost jde **jen shora dolů**. Kruhová závislost je vada architektury.

| Vrstva | Odpovědnost | Smí záviset na | Nesmí |
|---|---|---|---|
| `core/` | matematika, iso projekce, RNG, čas, serialy, hash stavu, konstanty | — | na ničem jiném |
| `data/` (JSON) | statický obsah: předměty, recepty, monstra, spawny, vendory, kouzla | — | na kódu |
| `sim/world/` | mapa, statiky, průchodnost, dveře, teleporty, regiony, čas světa, spawn | `core`, `data` | `sim/entity`, `ui`, `render` |
| `sim/entity/` | mobil, předmět, kontejner, výbava, staty, skilly, notoriety | `core`, `data` | `sim/systems` |
| `sim/systems/` | pohyb, interakce, souboj, magie, sběr, výroba, AI, obchod, smrt | `core`, `data`, `sim/world`, `sim/entity` | `ui`, `render`, `app` |
| `sim/sim_world.gd` | tick, pořadí systémů, save/load, hash | všechny `sim/*` | `ui`, `render`, `app` |
| `ui/` | gumpy, kurzory, drag & drop, žurnál, makra | `core`, `data`, **read-only** snapshot `sim` | měnit stav `sim` |
| `render/` | chunkový renderer, animace, hue, světlo, jména | `core`, `data`, read-only snapshot `sim` | měnit stav `sim` |
| `app/` | scéna, vstup → `Command`, smyčka, menu, uložení | všechno | — |

**Vynucení:** `tools/gates/check-layers.py` projde `preload`/`load` cesty
a `class_name` reference a **selže**, když `sim/**` odkazuje na `ui|render|app`
nebo když `sim/**` obsahuje `Input.`, `Time.`, `OS.`, `randf(`, `randi(`.
Tohle je tvrdá brána — je to jediná obrana proti „slepení" vrstev.

## 4.2 Registry komponent

Každá komponenta = **jeden soubor** = jedna granule. `id` je zároveň klíč
v `.forge/roadmap.json`.

### core

| id | soubor | provides (signatura) | kdo to volá |
|---|---|---|---|
| `core.const` | `core/const.gd` | konstanty: `TILE_W=44`, `TILE_H=44`, `ISO_STEP=22`, `Z_SCALE=4`, `Z_MIN=-128`, `Z_MAX=127`, `TICK_MS=50`, `WALK_MS=400`, `RUN_MS=200`, `MOUNT_WALK_MS=200`, `MOUNT_RUN_MS=100`, `TURN_MS=80`, `PERSON_HEIGHT=16`, `STEP_HEIGHT=2`, `LIFT_RANGE=2`, `MAX_STACK=60000`, `CONTAINER_MAX_ITEMS=125`, `CONTAINER_MAX_WEIGHT=400`, `SKILL_CAP=7000`, `STAT_CAP=225`, `SKILL_STEP=1` (=0.1) | všichni |
| `core.iso` | `core/iso.gd` | `to_screen(x:int,y:int,z:int)->Vector2`, `to_tile(sx:float,sy:float,z:int)->Vector2i`, `block_of(x:int,y:int)->Vector2i` | render, ui, world |
| `core.rng` | `core/rng.gd` | `new(seed:int)`, `next_u32()->int`, `range_i(a:int,b:int)->int`, `chance(p:float)->bool`, `state()->Dictionary`, `restore(d:Dictionary)->void` | sim systémy |
| `core.clock` | `core/clock.gd` | `now_ms()->int`, `after(delay_ms:int, cb:Callable)->int`, `cancel(id:int)->void`, `advance(ms:int)->void` (spustí splatné timery v pořadí `(time, id)`) | sim systémy |
| `core.serial` | `core/serial.gd` | `next()->int`, `is_item(s:int)->bool`, `is_mobile(s:int)->bool`, `reset(next:int)->void` | entity, save |
| `core.events` | `core/events.gd` | `push(name:String, data:Dictionary)->void`, `drain()->Array[Dictionary]`, `clear()->void` | sim → app |
| `core.hash` | `core/hash.gd` | `of_state(parts:Array)->String` (kanonické řazení, int-only) | save, testy |

### sim/world

| id | soubor | provides | poznámka |
|---|---|---|---|
| `world.tiledata` | `sim/world/tiledata.gd` | `flags(tile:int)->int`, `height(tile:int)->int`, `layer(tile:int)->int`, `weight(item:int)->int`, `value(item:int)->int`, `name(tile:int)->String`, `is_land(tile:int)->bool`; data z `assets/uo/manifest.json` + `data/tiles.json` | závisí na vyřešení §3.3.1 |
| `world.map` | `sim/world/map.gd` | `_init(prefix:String = "res://assets/uo/world/map0")` — **cesty jsou vstup, ne konstanta** (`assets/uo` je v `.gitignore`, takže v CI nejsou); `land_at(x:int,y:int)->int`, `z_at(x:int,y:int)->int`, `statics_at(x:int,y:int)->Array[Dictionary]` — vrací **celý blok 8×8**, každý záznam `{tile,x,y,z,hue}` s **lokálním** `x`,`y` (0..7), světová dlaždice je `(bx*8+x, by*8+y)`; `load_block(bx:int,by:int)->void`, `is_loaded(bx:int,by:int)->bool` | čte `.land`/`.statics` po blocích; **není to „statiky na dlaždici"** — filtr na dlaždici si dělá volající (`world.walk`, `render.chunk`); viz §4.2.1 |
| `world.walk` | `sim/world/walk.gd` | `_init(map = null, tiledata = null, stairs = null)` — **závislosti konstruktorem, ne konstantou** (jinak by `can_step` nešel změřit bez `assets/uo`); `can_step(from:Vector3i, dir:int, height:int = PERSON_HEIGHT, is_player:bool = true)->Dictionary` → `{ok:bool, z:int, reason:String}`; `surface_z(x:int,y:int)->int` | **jádro věrnosti pohybu**, algoritmus v §5.1; viz §4.2.1 |
| `world.doors` | `sim/world/doors.gd` | `is_door(tile:int)->bool`, `toggle(tile:int)->int` (vrátí nový tile), `category(tile:int)->int`, `open_tile(cat:int, orient:int)->int` | data z `doors.txt` |
| `world.teleport` | `sim/world/teleport.gd` | `teleport_target(x:int,y:int,z:int)->Variant` (`{x,y,z}` nebo `null`) | data z `teleprts.txt` + moongates z `data/moongates.json` |
| `world.stairs` | `sim/world/stairs.gd` | `is_stair(tile:int)->bool`, `stair_group(tile:int)->Dictionary` | data z `stairs.txt` |
| `world.regions` | `sim/world/regions.gd` | `region_at(x:int,y:int)->Dictionary` (`{name, is_town, is_guard_zone, music, spawn_table}`) | data z `data/regions.json` |
| `world.time` | `sim/world/time.gd` | `hour()->int`, `minute()->int`, `is_night()->bool`, `light_level()->int`, **`bind(clock)->void`, `tick(ms)->void`** (DOPLNĚNO 2026-10-06: bez nich modul nikdo nenaplní časem — `world_time_ms` dřív plnily jen testy, takže `hour()` vracelo ve hře vždy 0; viz `tests/cases/time_clock.gd`) | `SecondsPerUOMinute = 5.0` → **den = 7200 s** (ověřeno v ServUO/ModernUO; viz §10 past P12) |
| `world.spawn` | `sim/world/spawn.gd` | `register(point:Dictionary)->void`, `tick()->void`, `alive_at(point_id:int)->int` | spawnery z `data/spawns.json` |

### sim/entity

| id | soubor | provides |
|---|---|---|
| `entity.mobile` | `sim/entity/mobile.gd` | `serial:int`, `body:int`, `hue:int`, `name:String`, `pos:Vector3i`, `dir:int`, `flags:int`, `hp/max_hp:int`, `stam/max_stam:int`, `mana/max_mana:int`, `stats:Stats`, `skills:Skills` (obě **instance**, ne pole), `equip:Dictionary` (layer → serial; dřív tu stálo `equipment:Equipment`), `backpack:int`, `notoriety:int`, `fame:int`, `karma:int`, `hunger:int`, `ai:AiState` (`{state, target, home, timer_ms}`), `alive()->bool` |
| `entity.item` | `sim/entity/item.gd` | `serial:int`, `tile:int`, `hue:int`, `amount:int`, `parent:int`, `layer:int`, `pos:Vector3i`, `flags:int`, `durability:int/max_durability:int`, `props:Dictionary` |
| `entity.container` | `sim/entity/container.gd` | `can_add(c:int, item:Item)->Dictionary` (`{ok, reason}`), `add(c:int,item:Item)->bool`, `remove(c:int,item:int,amount:int)->int`, `weight_of(c:int)->int`, `contents(c:int)->Array[int]` |
| `entity.equipment` | `sim/entity/equipment.gd` | `equip(m:int, item:int)->Dictionary`, `unequip(m:int, layer:int)->int`, `at_layer(m:int, layer:int)->int`, `total_weight(m:int)->int`, `bonus(m:int, key:String)->int` |
| `entity.stats` | `sim/entity/stats.gd` | `str_:int`, `dex:int`, `int_:int` (dřív tu stálo `str/dex/int:int`; `int` je klíčové slovo a `str` by přebilo globální funkci `str()`), `hits_max()->int` (= `50 + STR/2`), `stam_max()->int` (= DEX), `mana_max()->int` (= INT), `stat_total()->int`, `at_cap()->bool` |
| `entity.skills` | `sim/entity/skills.gd` | `value(skill:int)->int` (desetiny), `set_value(skill:int,v:int)->void`, `cap(skill:int)->int`, `total()->int`, `lock(skill:int)->int`, `set_lock(skill:int,l:int)->void` |
| `entity.notoriety` | `sim/entity/notoriety.gd` | `level(m:int)->int` (1 innocent … 6 murderer, 7 invulnerable), `is_criminal(m:int)->bool`, `flag_criminal(m:int, ms:int)->void`, `murder_counts(m:int)->int`, `award_fame_karma(m:int, fame:int, karma:int)->void` |
| `sim.entity_registry` | `sim/entity/registry.gd` | **DOPLNĚNO 2026-10-06 — smlouva pro granuli `sim.entity_registry` (kód ještě není):** drží `serial -> mobil`; `register(m)->void`, `get(serial)->Mobile|null`, `all()->Array`, `remove(serial)->void`. Je to **jediné místo, kde se mobil hledá podle serialu** — dnes tuhle díru obchází `sim.movement` (`register`/`mobile`) i `render.anim` (bere `serial` jako číslo těla). Viz §4.2.1 |

### sim/systems

| id | soubor | provides | acceptance (konkrétní volání) |
|---|---|---|---|
| `sim.movement` | `sim/systems/movement.gd` | **odkud bere mobily (dohodnutý tvar, dokud nebude `sim.entity_registry`):** `register(mobile)->void`, `mobile(serial:int)`, `player_serial:int` (rozhoduje o asymetrické diagonále); `request_step(m:int, dir:int, run:bool)->Dictionary` (`{ok, delay_ms, reason}`), `apply_step(m:int, dir:int)->void`, `consume_stamina(m:int, steps:int)->void`, `pending_count()->int`, `delay_ms_for(run:bool)->int` | `request_step(m, 0, false).delay_ms == 400` **pro zaregistrovaný mobil** (jinak `{ok:false, reason:"no_mobile"}`); po `apply_step` se `pos.x += 1`; viz §4.2.1 |
| `sim.interaction` | `sim/systems/interaction.gd` | `use(m:int, serial:int)->void`, `use_on(m:int, serial:int, target:Dictionary)->void`, `context_menu(m:int, serial:int)->Array[Dictionary]`, `context_action(m:int, serial:int, entry:int)->void` | `use(m, anvil)` nic neudělá; `use_on(m, ore, {"serial": forge})` spustí tavení |
| `sim.combat` | `sim/systems/combat.gd` | `set_war(m:int, on:bool)->void`, `attack(m:int, target:int)->void`, `swing_delay_ms(m:int)->int`, `resolve_swing(m:int, t:int)->Dictionary`, `stop_combat(m:int)->void` | `swing_delay_ms` na `dex=100, speed=30` vrátí hodnotu dle vzorce z §5.5 |
| `sim.magic` | `sim/systems/magic.gd` | `cast(m:int, spell:int)->Dictionary` (`{ok, delay_ms, reagents, reason}`), `interrupt(m:int)->void`, `add_spell(m:int, spell:int)->bool`, `scribe(m:int, scroll:int)->bool` | `cast` bez reagent → `{ok:false, reason:"reagents"}` |
| `sim.skill_gain` | `sim/systems/skill_gain.gd` | `check(m:int, skill:int, difficulty:int)->Dictionary` (`{success, gained, new_value}`), `gain_stat(m:int, stat:int)->void` | opakované `check` s `difficulty` 0 při `value=0` dá za 100 pokusů > 0 |
| `sim.harvest` | `sim/systems/harvest.gd` | `mine(m:int, x:int, y:int)->Dictionary`, `chop(m:int, x:int, y:int)->Dictionary`, `fish(m:int, x:int, y:int)->Dictionary`, `resource_left(x:int,y:int)->int` | `mine` s pickaxe na hoře vrátí `{ok:true, item:ore, amount:1..}` |
| `sim.craft` | `sim/systems/craft.gd` | `recipes_for(m:int, skill:int)->Array[Dictionary]`, `craft(m:int, recipe_id:int, count:int)->Dictionary`, `smelt(m:int, ore:int, forge:int)->Dictionary`, `repair(m:int, tool:int, target:int)->Dictionary` | `craft` bez materiálu → `{ok:false, reason:"materials"}` |
| `sim.ai` | `sim/systems/ai.gd` | `tick(m:int)->void`, `set_state(m:int, state:String)->void` | NPC bez cíle se pohne alespoň 1× za 10 s (wander) |
| `sim.vendor` | `sim/systems/vendor.gd` | `stock(v:int)->Array[Dictionary]`, `buy_price(v:int, item:int, amount:int)->int`, `sell_price(v:int, item:int, amount:int)->int`, `buy(m:int,v:int,lines:Array)->Dictionary`, `sell(m:int,v:int,lines:Array)->Dictionary`, `restock()->void` | `sell_price` odpovídá `value` z tiledata × koeficient; `buy_price == ceil(1.9 × sell_price)` |
| `sim.loot` | `sim/systems/loot.gd` | `fill_corpse(mob:int, corpse:int)->void`, `roll_magic_item(level:int)->Dictionary` | z monstra s `loot.gold_min>0` vznikne v těle zlato |
| `sim.death` | `sim/systems/death.gd` | `die(m:int)->Dictionary`, `resurrect(m:int, hp:int)->void`, `is_ghost(m:int)->bool` | po `die` je `is_ghost(m) == true`, `hp == 0`, vznikne tělo s obsahem |
| `sim.poison` | `sim/systems/poison.gd` | `apply(m:int, level:int)->void`, `cure(m:int, level:int)->bool`, `tick()->void` | jed 3. úrovně ubere hp během 10 s |
| `sim.regen` | `sim/systems/regen.gd` | `tick()->void` (hp/stam/mana podle statů a hladu) | `mana` roste u postavy s INT > 0 |
| `sim.hunger` | `sim/systems/hunger.gd` | `eat(m:int, item:int)->bool`, `level(m:int)->int` | jídlo sníží hlad, hlad −1 za 5 min |

### sim (jádro)

| id | soubor | provides |
|---|---|---|
| `sim.commands` | `sim/commands.gd` | `parse(d:Dictionary)->Dictionary`, `validate(c:Dictionary)->Dictionary` (`{ok, reason}`), `dispatch(sim, c:Dictionary)->void` |
| `sim.world_loop` | `sim/sim_world.gd` | `new(seed:int, data:Dictionary)`, `enqueue(c:Dictionary)->void`, `tick(ms:int)->void`, `snapshot()->Dictionary` (read-only pro UI), `state_hash()->String`, `save(path:String)->bool`, `load(path:String)->bool` |

### ui (klient) — kompaktně

| id | soubor | zodpovědnost |
|---|---|---|
| `ui.hud` | `ui/hud.gd` | kotvy oken, pozice oken, zapamatování rozložení |
| `ui.paperdoll` | `ui/paperdoll.gd` | postava, vrstvy, drag na tělo, jméno, „war/peace" přepínač |
| `ui.status_bar` | `ui/status_bar.gd` | HP/Stam/Mana, váha, zlato, jméno |
| `ui.backpack` | `ui/backpack.gd` | gump batohu (id gumpu z manifestu), mřížka položek |
| `ui.container` | `ui/container_window.gd` | obecný kontejner (truhla, tělo, banka) |
| `ui.craft_gump` | `ui/craft_gump.gd` | strom receptů (kategorie → položky), „make last / make number" |
| `ui.vendor_gump` | `ui/vendor_gump.gd` | seznam k prodeji/koupi, množství, cena, potvrzení |
| `ui.spellbook` | `ui/spellbook.gd` | 8 kruhů, ikony kouzel, drag ikony na lištu |
| `ui.skill_list` | `ui/skill_list.gd` | 58 skillů, hodnota v desetinách, zámek (up/down/lock), tlačítko „use" |
| `ui.context_menu` | `ui/context_menu.gd` | kontextové menu (pravý klik / klik na sebe) |
| `ui.target_cursor` | `ui/target_cursor.gd` | kurzor cíle (object/ground/self), timeout, zrušení |
| `ui.dragdrop` | `ui/dragdrop.gd` | zvednutí, kurzor s předmětem, drop (svět/kontejner/tělo), 2–3 dlaždice |
| `ui.journal` | `ui/journal.gd` | textový žurnál (systém, mluv, boj), barvy podle typu |
| `ui.tooltip` | `ui/tooltip.gd` | jméno, vlastnosti (AoS properties), váha, hodnota |
| `ui.options` | `ui/options.gd` | rozlišení, zoom, hlasitost, „always run", klávesy |
| `ui.hotkeys` | `ui/hotkeys.gd` | výchozí klávesy + makra (poslední cíl, použij poslední, obvaz sebe) |
| `ui.macros` | `ui/macros.gd` | uživatelská makra, ukládaná mimo save (do `user://`) |

### render (klient) — kompaktně

| id | soubor | zodpovědnost |
|---|---|---|
| `render.textures` | `render/texture_cache.gd` | načítání z manifestu, LRU, strop paměti |
| `render.hue` | `render/hue_cache.gd` | `(art_id, hue)` → textura (index 0 = použij hue) |
| `render.sort` | `render/sort.gd` | **jediná** funkce řazení (land → statics podle z → mobilové podle z) |
| `render.chunk` | `render/chunk_renderer.gd` | sestavení kreslicího seznamu pro viditelné bloky, cache |
| `render.anim` | `render/anim_player.gd` | `play(serial:int, action:int, dir:int, now_ms:int = -1)->Dictionary` → `{ok, texture, frame, count, anchor, mirror, mirror_x, sprite_dir}` (chybějící sprite = `ok:false` + `texture:null`); framy těl a worn artu podle `animdata`, časování 80 ms; **`serial` se bere jako číslo těla** (registr entit není — viz `sim.entity_registry`); zrcadlení 8 → 5 směrů a `mirror_x` viz §4.2.1 |
| `render.names` | `render/name_plates.gd` | jména a HP pruhy nad mobily (jen na dosah/po kliku) |
| `render.light` | `render/light_layer.gd` | úroveň světla z `world.time`, světelné zdroje (louče, okna) |
| `render.effects` | `render/effects.gd` | kouř, oheň, zásah, smrt, animace kouzel |

### app

| id | soubor | zodpovědnost |
|---|---|---|
| `app.main` | `app/main.gd` | scéna, kostra, načtení dat, spuštění smyčky |
| `app.loop` | `app/loop.gd` | pumpuje `sim.tick(50)`, překládá vstup na `Command`, předává události UI |
| `app.input` | `app/input_map.gd` | mapování kláves a myši na `Command` (jediné místo s `Input`) |
| `app.menu` | `app/menu.gd` | hlavní menu, výběr postavy, uložit/načíst |
| `app.char_create` | `app/char_create.gd` | tvorba postavy: profese, staty, skilly, jméno, barvy |

### 4.2.1 Co registry dosud nepinovaly (DOPLNĚNO 2026-10-06)

Doplněk smlouvy: co dělá **dnešní kód**, ale tabulky výš to neříkaly. Kde se text
změnil, je tu i **původní znění** — historie se nepřepisuje, jen doplňuje.

- **`render.anim` — tvar návratu `play(...)`:** kód vrací
  `{ok, texture, frame, count, anchor, mirror, mirror_x, sprite_dir}`; chybějící
  sprite vrací `ok:false` a `texture:null` (prázdno nesmí vypadat jako úspěch).
  Dřív tu stálo jen „framy těl a worn artu podle `animdata`, časování 80 ms" — tedy
  ani tvar návratu, ani odkud se bere tělo, ani zrcadlení.
  `mirror_x` = `w - cx` je potřeba proto, že **zrcadlený** sprite se kreslí na
  `tile_x - (w - cx)` (ClassicUO `MobileView.cs:712`, ověřeno); do `anchor`
  (`Vector2(cx, cy + h)`) se zrcadlení nevejde.
- **Odkud se bere tělo pro `play`:** registr bytostí neexistuje, proto
  `play(serial, action, dir)` bere `serial` jako **číslo těla (art id)**, ne jako
  serial mobily. Až vznikne `sim.entity_registry`, patří převod `serial -> body` tam.
- **Zrcadlení 8 směrů na 5:** `anim.mul` má **5 směrů**, hra **8**. Osa zrcadlení je
  **svislá osa obrazovky** (projekce `screen = ((x-y), (x+y)) * ISO_STEP`), proto jsou
  zrcadlové dvojice **(E,S), (NE,SW), (N,W)** a **SE/NW leží na ose** (nezrcadlí se).
  Ověřeno proti ClassicUO `GetAnimDirection`
  (`_src/classicuo/src/ClassicUO.Renderer/Animations/Animation.cs:76`).
  **Pozor:** příklad „směr 4 = západ je zrcadlený s 0 = východ" na data **nesedí** —
  západ je `sprite 3` bez zrcadla, východ `sprite 1` zrcadleně; každý má jiný sprite.
- **`world.map.statics_at` vrací CELÝ BLOK, ne dlaždici.** Dřív tu stálo
  `statics_at(x,y)->Array[Dictionary]` (`{tile,z,hue}`). Kód vrací záznamy celého
  bloku 8×8, každý s **lokálním** `x`,`y` (0..7): `{tile,x,y,z,hue}`. Filtr na dlaždici
  si dělá **volající** (`world.walk`, `render.chunk`) — blok je to, co je v souboru
  (docs/03 §3.4), a filtrováním by se zahodila informace, kterou renderer potřebuje.
- **`world.walk`: závislosti KONSTRUKTOREM.** `_init(map = null, tiledata = null,
  stairs = null)`. Dřív tu stálo jen `can_step(from, dir, height, is_player)` bez
  výchozích hodnot a bez konstruktoru. Kdyby závislosti byly konstanty, `can_step`
  by se nedal změřit bez `assets/uo` — a ta jsou v `.gitignore`, takže v CI nejsou.
  Stejný vzor jako `world.map._init(prefix)`.
- **`sim.movement`: kde bere mobily.** Smlouva uváděla jen `request_step(m, ...)`
  a neříkala, odkud systém `m` vezme. Dnes si je drží **sám** (`register(mobile)`,
  `mobile(serial)`) a `SimWorld` dostane systém z integračního místa (`app/main.gd`).
  Přijímací kritérium `request_step(m, 0, false).delay_ms == 400` proto platí **jen
  pro zaregistrovaný mobil** — jinak vrací `{ok:false, reason:"no_mobile"}`.
  `SimWorld.snapshot()` vrací `mobiles: []`, takže **klient mobily odsud nevidí**;
  přesně tuhle díru má zavřít `sim.entity_registry`.
- **`entity.mobile` sjednoceno s §4.5 (a s kódem).** Tabulka dřív uváděla
  `equipment:Equipment`, `skills:Skills` a `stats:Stats`, ale neměla `name`, `hunger`
  ani `ai`; §4.5 měl `str/dex/int`, `skills:PackedInt32Array` + `skill_locks` a `equip`.
  Platí **kód**: `equip:Dictionary` (layer → serial; `entity.equipment` ještě
  neexistuje), `skills` a `stats` jako **instance** (`sim/entity/skills.gd`,
  `sim/entity/stats.gd` — klíč `int_`, protože `int` je klíčové slovo), dále `name`,
  `hunger`, `ai` a `alive()->bool`.
- **`sim.entity_registry` je granule i komponenta.** Granule `sim.entity_registry`
  v `.forge/roadmap.json` **existuje** (ověřeno 2026-10-06: 111 granul, `owns:
  sim/entity/registry.gd`, `depends_on: core.serial + entity.mobile`), takže řádek
  výš a roadmapa se shodují; kód (`registry.gd`) ještě není. Kdyby se `provides`
  v roadmapě změnilo, platí roadmapa (je to klíč plánu) a smlouva se doplní.

## 4.3 Příkazy klient → simulace

**Jediná cesta, jak měnit stav.** Všechny příkazy mají tvar slovníku
s `t` (typ) a jsou validované v `sim/commands.gd`. Neplatný příkaz se
**zahodí s hláškou do žurnálu**, nikdy nespadne.

| `t` | Pole | Význam | Poznámka k věrnosti |
|---|---|---|---|
| `move` | `dir:int(0..7)`, `run:bool`, `seq:int` | krok | klient posune sprite hned (predikce), sim potvrdí/odmítne a případně vrátí zpět (`snap-back`) |
| `turn` | `dir:int` | otočení na místo | 80 ms, bez pohybu |
| `use` | `serial:int` | dvojklik | routing v `sim.interaction` |
| `use_on` | `serial:int`, `target:Dictionary` | použij na cíl | `target` = `{kind:"item"|"mobile"|"tile", serial| x,y,z}` |
| `skill` | `skill:int`, `target:Dictionary?` | použití skillu | např. `Mining` s `target` = tile hory |
| `target_reply` | `cursor:int`, `ref:Dictionary?` | odpověď na kurzor | `null` = zrušeno (Esc) |
| `drag` | `serial:int`, `amount:int` | zvednutí | dosah 2 dlaždice |
| `drop` | `serial:int`, `to:Dictionary` | položení | `to` = `{kind:"ground",x,y,z}` / `{kind:"item",serial} ` / `{kind:"layer",layer}` |
| `equip` | `serial:int` | nasaď | ekvivalent `drop` na vrstvu |
| `attack` | `serial:int` | útok | nastaví `war` a cíl |
| `war` | `on:bool` | war/peace | — |
| `cast` | `spell:int` | sesli | kontrola reagentů a many |
| `craft` | `recipe:int`, `count:int` | vyráběj | `count=0` = „make last" |
| `vendor` | `action:"buy"|"sell"`, `vendor:int`, `lines:Array` | obchod | `lines` = `[{item:int, amount:int}]` |
| `context` | `serial:int`, `entry:int` | kontextová akce | čísla ≥ 0x64 pro vlastní |
| `say` | `text:String` | mluv | dosah 12 dlaždic, slyší NPC (trigger) |
| `resurrect` | `accept:bool` | vzkříšení | — |
| `save` / `load` | `slot:int` | ulož/načti | mimo simulaci (app) |

## 4.4 Události simulace → klient

Simulace **nikdy nevolá UI**. Události se hromadí ve frontě a klient si je
vybere jednou za frame.

| `name` | `data` | Kdo to vyvolá |
|---|---|---|
| `mobile_moved` | `{serial, x, y, z, dir, run}` | `sim.movement` |
| `mobile_anim` | `{serial, action, frame_ms}` | `sim.movement`, `sim.combat` |
| `mobile_added` / `mobile_removed` | `{serial, body, hue, name, x, y, z, notoriety}` | spawn, smrt, opuštění dosahu |
| `item_added` / `item_removed` | `{serial, tile, hue, amount, parent, layer, x, y, z}` | kontejnery, svět |
| `item_moved` | `{serial, from, to}` | drag & drop |
| `container_contents` | `{serial, items:[...]}` | otevření kontejneru (odpověď, ne broadcast) |
| `stats_changed` | `{serial, hp, max_hp, stam, mana, weight, gold}` | staty, výbava |
| `skill_changed` | `{skill, value, total, cap}` | `sim.skill_gain` |
| `message` | `{text, kind:"system"|"say"|"combat"|"craft", hue, name?}` | všude |
| `target_request` | `{cursor, kind:"object"|"ground"|"self", allow_ground:bool}` | interakce, magie, sběr |
| `gump_open` | `{gump:"craft"|"vendor"|"container"|"spellbook"|"skills", data:{...}}` | interakce |
| `sound` | `{id, x, y, z}` | kroky, boj, výroba |
| `music` | `{track:String}` | změna regionu |
| `light_changed` | `{level:int}` | `world.time` |
| `combat_state` | `{serial, target, war:bool}` | `sim.combat` |
| `death` / `resurrected` | `{serial}` | `sim.death` |
| `notoriety_changed` | `{serial, level}` | flagy, karma |

## 4.5 Datové typy (tvary, které se nesmí měnit tichou cestou)

```gdscript
# core typy
Vector3i  # pozice: x, y = dlaždice (int), z = světová výška (int)
# serial: int >= 0x40000000 = mobile, < = item (viz core.serial)

# Mobile (sim/entity/mobile.gd) - TVAR JE Z KODU (DOPLNENO 2026-10-06, sjednoceno s §4.2; viz §4.2.1)
{ serial:int, body:int, hue:int, name:String,
  pos:Vector3i, dir:int, flags:int,
  hp:int, max_hp:int, stam:int, max_stam:int, mana:int, max_mana:int,
  stats:Stats,                              # INSTANCE sim/entity/stats.gd; klice `str_`, `dex`, `int_`
                                            #   (driv tu stalo `str:int, dex:int, int:int`; `int` je
                                            #   klicove slovo a `str` by prebilo globalni funkci `str()`)
  skills:Skills,                            # INSTANCE sim/entity/skills.gd - `values` i `locks` jsou
                                            #   uvnitr (driv tu stalo `skills:PackedInt32Array` +
                                            #   `skill_locks:PackedInt32Array`)
  equip:Dictionary,                         # layer:int -> item serial:int; `entity.equipment` jeste
                                            #   neexistuje, proto `equip` (driv proti sobe §4.2
                                            #   `equipment:Equipment` a §4.5 `equip:Dictionary`)
  backpack:int,                             # serial batohu
  notoriety:int, fame:int, karma:int, hunger:int,
  ai:{ state:String, target:int, home:Vector3i, timer_ms:int },
  # metoda: alive()->bool (v puvodnim tvaru chybela, v kode je)
}

# Item (sim/entity/item.gd)
{ serial:int, tile:int, hue:int, amount:int,
  parent:int,            # 0 = na zemi, jinak serial kontejneru/mobila
  layer:int,             # 0 = nenasazený
  pos:Vector3i,          # platné jen na zemi
  flags:int,             # 0x01 blessed, 0x02 newbie, 0x04 locked, 0x08 insured
  durability:int, max_durability:int, quality:int,  # 0 normal, 1 exceptional
  props:Dictionary }     # AoS properties: {"damage_increase":25, ...}

# Recept (data/recipes.json)
{ id:int, skill:int, min_skill:int, category:[String], name:String,
  result:{tile:int, amount:int, hue:int?}, materials:[{tile:int, amount:int}],
  exceptional:bool, tool:int, source:"tiledata"|"manual" }

# Monstrum (data/monsters.json)
{ id:String, body:int, name:String, hits:int, stam:int, mana:int,
  str:int, dex:int, int_:int, skills:{wrestling:int, magery:int, ...},
  damage:[int,int], resist:{physical:int,...}, fame:int, karma:int,
  loot:{gold:[int,int], items:[{tile:int, chance:float, amount:[int,int]}],
        magic_chance:float},
  ai:"melee"|"mage"|"archer"|"animal", flags:{undead:bool, poisonous:int, tamable:int},
  taming_difficulty:int, slayer_type:String }
```

## 4.6 Smlouvy klíčových toků (přijímací kritéria)

Tyto toky jsou **jádro věrnosti**; každý má test s konkrétní hodnotou.

### 4.6.1 Krok hráče (pohyb)

```
ui klik do světa → app.input → Command{t:"move", dir, run}
sim.commands.dispatch → sim.movement.request_step(m, dir, run)
   → world.walk.can_step()   # Z, StepHeight, flagy, diagonála
   → pokud ok: naplánuj apply_step za delay_ms (400/200/100)
   → event mobile_moved + mobile_anim
   → pokud ne: event message{"You cannot move there."}
```
**Přijímací kritérium:** `request_step` na volné dlaždici vrátí
`{ok:true, delay_ms:400}` pro chůzi a `200` pro běh; na dlaždici s vodou
(`Wet`) vrátí `{ok:false, reason:"blocked"}`; diagonála vedle zdi vrátí
`{ok:false, reason:"diagonal"}` **pro hráče** a `{ok:true}` pro NPC
(ověřeno v kódu: hráč potřebuje obě ortogonální dlaždice, NPC jen jednu).

### 4.6.2 Tavení rudy (interakce předmět → předmět)

```
ui dvojklik na ore → Command{t:"use", serial:ore}
sim.interaction.use → hráč má v ruce/batohu ore → kurzor na cíl
ui klik na forge → Command{t:"target_reply", cursor, ref:{kind:"item", serial:forge}}
sim.interaction.use_on(m, ore, forge) → sim.craft.smelt(m, ore, forge)
   → kontrola skillu Mining, vzdálenost ≤ 2, spotřeba rudy
   → event message{"You smelt the ore..."} + item_added{ingot} + sound
```
**Přijímací kritérium:** ore (amount 5) + forge na dosah + `mining >= 0`
→ v batohu ingot(y) a ore zmizí; **bez forge** vrátí `{ok:false,
reason:"forge"}` a ruda zůstane. Přesně tohle popisuje originální nápověda
(`Tilehelp.enu`): „Double-clicking ore will bring up a targeting cursor…
target a forge… will attempt to smelt the ore into ingots using your mining
skill."

### 4.6.3 Kovářství (gump → výroba)

```
ui dvojklik na smith hammer → event gump_open{craft, data:{skill:Blacksmithy,
   recipes:[...]}} (jen recepty, na které stačí materiál+skill? NE: všechny,
   nedostupné zešednou — jako v UO)
ui klik na recept + "make number" → Command{t:"craft", recipe:r, count:n}
sim.craft.craft → kontrola anvil+forge v dosahu, materiálu, skillu
   → naplánuj dokončení za čas (0.5 s × počet?) → spotřebuj materiál
   → hod na úspěch (skill vs min_skill), hod na exceptional
   → item_added{result} + skill_gain.check(Blacksmithy, min_skill) + sound
```
**Přijímací kritérium:** recept `dagger` s `min_skill=1`, materiál 3 ingoty →
po dokončení je v batohu dagger (nebo hláška o neúspěchu) a **materiál je
spotřebován**; bez anvilu vrátí `{ok:false, reason:"anvil"}`.

### 4.6.4 Souboj

```
ui dvojklik/attack na monstrum → Command{t:"attack", serial}
sim.combat.attack → war=true, cíl nastaven, naplánuj swing
swing: resolve_swing(m, t) → hit chance (zbraňový skill vs zbraňový skill),
   damage (vzorec dle éry), obrana (parry/AR nebo resisty), efekty
   → event message + mobile_anim + sound + stats_changed + případně death
```
**Přijímací kritérium:** se zbraní a `tactics=100` dá 20 swingů na cíl s `hp`
> 0 alespoň 5 zásahů (nenulový damage) a cíl ztratí hp; **bez zbraně**
(wrestling) funguje útok dál.

### 4.6.5 Obchod

```
ui dvojklik na vendora → Command{t:"use", serial:vendor}
sim.vendor.stock → event gump_open{vendor, data:{buy:[...], sell:[...]}}
ui potvrdí nákup → Command{t:"vendor", action:"buy", vendor, lines:[{item, amount}]}
sim.vendor.buy → kontrola zlata ve váze/batohu, dosah, množství, ceny
   → zlato pryč, předmět do batohu, event message + sound
```
**Přijímací kritérium:** `buy_price == ceil(1.9 * sell_price)` (ověřeno
v ServUO), prodej vrátí zlato do batohu, nákup bez zlata vrátí
`{ok:false, reason:"gold"}` a nic nezmění.

### 4.6.6 Smrt a vzkříšení

```
hp <= 0 → sim.death.die(m) → vznikne tělo (corpse) s obsahem (kromě blessed),
   hráč se stane duchem (body duch, nemožnost útočit, průchod dveřmi? NE)
ui: hráč jde k léčitelce / ankh → Command{t:"use", serial:healer}
sim.death.resurrect → hp = 10 (ověřeno), equip se vrátí podle blessed/insured
```
**Přijímací kritérium:** po `die` je `is_ghost(m) == true` a v těle je
inventář; po `resurrect` je `hp == 10` a hráč není duch.

## 4.7 Uložení, načtení, determinismus

| Věc | Rozhodnutí |
|---|---|
| Formát | JSON + gzip, `user://saves/<slot>.sav`, s `version:int` a `data_version` (hash `data/*.json`) |
| Obsah | `{version, seed, world_time_ms, rng_state, next_serial, mobiles[], items[], spawn_state[], player_serial, position_serial}` |
| Zákaz | žádné cesty k assetům, žádné absolutní cesty, žádné `float` ve stavu |
| `state_hash()` | SHA-256 kanonické serializace; používá se v testech determinismu a round-trip |
| Round-trip kritérium | `sim.save(); sim2.load(); sim.state_hash() == sim2.state_hash()` |
| Kompatibilita | změna `data_version` → save se odmítne s jasnou hláškou (radši než tichý nesmysl) |

## 4.8 Headless test harness

Testy **nesmí** potřebovat scénu ani assety (kromě dat z `data/*.json`):

```gdscript
# tests/run_tests.gd (spouští se: godot --headless --path . --script res://tests/run_tests.gd)
var sim := SimWorld.new(1234, Data.load_all())
sim.enqueue({"t": "move", "dir": 0, "run": false, "seq": 1})
for i in 2000: sim.tick(50)     # 100 s herního času
_check(sim.player().pos.x > 1495, "hráč se pohnul na východ")
```

Replay: soubor `tests/replays/*.json` = posloupnost příkazů s ticky; testy
ověřují `state_hash` po replayi (detekce regrese v mechanikách).
