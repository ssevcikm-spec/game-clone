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
| `world.tiledata` | `sim/world/tiledata.gd` | `flags(tile:int)->int`, `height(tile:int)->int`, `layer(tile:int)->int`, `weight(item:int)->int`, `value(item:int)->int`, `name(tile:int)->String`, `is_land(tile:int)->bool`, **`texture(tile:int)->int`** (TexID z land záznamu = index do `texmaps.mul`; u předmětů 0) — doplněno 2026-10-07 pro svahy; data z `assets/uo/manifest.json` + `data/tiles.json` | závisí na vyřešení §3.3.1 |
| `world.map` | `sim/world/map.gd` | `_init(prefix:String = "res://assets/uo/world/map0")` — **cesty jsou vstup, ne konstanta** (`assets/uo` je v `.gitignore`, takže v CI nejsou); `land_at(x:int,y:int)->int`, `z_at(x:int,y:int)->int`, `statics_at(x:int,y:int)->Array[Dictionary]` — vrací **celý blok 8×8**, každý záznam `{tile,x,y,z,hue}` s **lokálním** `x`,`y` (0..7), světová dlaždice je `(bx*8+x, by*8+y)`; `load_block(bx:int,by:int)->void`, `is_loaded(bx:int,by:int)->bool` | čte `.land`/`.statics` po blocích; **není to „statiky na dlaždici"** — filtr na dlaždici si dělá volající (`world.walk`, `render.chunk`); viz §4.2.1 |
| `world.walk` | `sim/world/walk.gd` | `_init(map = null, tiledata = null, stairs = null, doors = null)` — **závislosti konstruktorem, ne konstantou** (jinak by `can_step` nešel změřit bez `assets/uo`); `can_step(from:Vector3i, dir:int, height:int = PERSON_HEIGHT, is_player:bool = true)->Dictionary` → `{ok:bool, z:int, reason:String}`; `surface_z(x:int,y:int)->int` | **jádro věrnosti pohybu**, algoritmus v §5.1; dveře rozhoduje `world.doors.is_open` (oba stavy mají v `tiledata` `Impassable`), statiky se ptají `tiledata` s `+0x4000`; viz §4.2.1 |
| `world.doors` | `sim/world/doors.gd` | `is_door(tile:int)->bool` (**i pro otevřený art**), `is_open(tile:int)->bool`, `toggle(tile:int)->int` (`art + 1` / `art - 1`; `0` = není dveře), `category(tile:int)->int`, `orientation(tile:int)->int` (index v `doors.txt`, 0..7), `open_tile(cat:int, index:int)->int` | data z `doors.txt`: **art je zavřený, `art + 1` otevřený** (měřeno 2026-10-07 nad 230 arty; důkazy v hlavičce modulu a docs/03 §3.6) |
| `world.teleport` | `sim/world/teleport.gd` | `teleport_target(x:int,y:int,z:int)->Variant` (`{x,y,z}` nebo `null`) | data z `teleprts.txt` + moongates z `data/moongates.json` |
| `world.stairs` | `sim/world/stairs.gd` | `is_stair(tile:int)->bool`, `stair_group(tile:int)->Dictionary` | data z `stairs.txt` |
| `world.regions` | `sim/world/regions.gd` | `region_at(x:int,y:int)->Dictionary` (`{name, is_town, is_guard_zone, music, spawn_table}`) | data z `data/regions.json` |
| `world.time` | `sim/world/time.gd` | `hour()->int`, `minute()->int`, `is_night()->bool`, `light_level()->int`, **`bind(clock)->void`, `tick(ms)->void`** (DOPLNĚNO 2026-10-06: bez nich modul nikdo nenaplní časem — `world_time_ms` dřív plnily jen testy, takže `hour()` vracelo ve hře vždy 0; viz `tests/cases/time_clock.gd`) | `SecondsPerUOMinute = 5.0` → **den = 7200 s** (ověřeno v ServUO/ModernUO; viz §10 past P12) |
| `world.spawn` | `sim/world/spawn.gd` | `register(point:Dictionary)->void`, `tick()->void`, `alive_at(point_id:int)->int` | spawnery z `data/spawns.json` |

### sim/entity

| id | soubor | provides |
|---|---|---|
| `entity.mobile` | `sim/entity/mobile.gd` | `serial:int`, `body:int`, `hue:int`, `name:String`, `pos:Vector3i`, `dir:int`, `flags:int`, `hp/max_hp:int`, `stam/max_stam:int`, `mana/max_mana:int`, `stats:Stats`, `skills:Skills` (obě **instance**, ne pole), `equip:Dictionary` (layer → serial; dřív tu stálo `equipment:Equipment`), `backpack:int`, `notoriety:int`, `fame:int`, `karma:int`, `hunger:int`, `ai:AiState` (`{state, target, home, timer_ms}`), `alive()->bool` |
| `entity.item` | `sim/entity/item.gd` | `serial:int`, `tile:int` (**art id** 0x4000–0xFFFF, `docs/03` §3.4: „item id = art id"), `hue:int`, `amount:int`, `parent:int` (0 = na zemi, jinak serial kontejneru/mobila), `layer:int` (0 = nenasazený), `pos:Vector3i` (platí **jen** na zemi), `flags:int`, `durability:int`, `max_durability:int`, `quality:int` (**Low 0 / Normal 1 / Exceptional 2** — měřeno v ServUO `Scripts/Items/Internal/ItemInterfaces.cs:67-72` (`Low, Normal, Exceptional`) a `CraftItem.cs:1356` (exceptional = `quality = 2`); dřív tu stálo „0 normal, 1 exceptional", což byl posun o jednu a chyběla Low — rozhodnutí uživatele 2026-10-07), `props:Dictionary`; navíc `is_on_ground()`, `pile_weight(unit_weight)->int` (jednotková váha × `amount`), `same_pile(other)->bool` (stejný `tile` + `hue` = kandidát na sloučení). **DOPLNĚNO 2026-10-07**, viz §4.2.1 |
| `entity.container` | `sim/entity/container.gd` | `_init(tiledata = null, max_items = 125, max_weight = 400)` — **jedna instance spravuje všechny kontejnery světa** (`c` = serial kontejneru; jinak by nešel držet invariant „právě jeden rodič"); `can_add(c:int, item:Item)->Dictionary` (`{ok, reason}`; reason `no_container`/`no_item`/`no_serial`/`amount`/`stack`/`already_here`/`full`/`weight`), `add(c:int,item:Item)->bool` (**při neúspěchu se stav nemění**; před vložením vyjme předmět z předchozího rodiče), `remove(c:int,item:int,amount:int)->int` (**kolik opravdu odstranil**; `amount <= 0` = celá hromada), `weight_of(c:int)->int` (stones, jen přímý obsah), `contents(c:int)->Array[int]` (seriály, **seřazené**); navíc `has_weights()` (bez `tiledata` se váha **neměří**). **DOPLNĚNO 2026-10-07**, viz §4.2.1 |
| `entity.equipment` | `sim/entity/equipment.gd` | `equip(m:int, item:int)->Dictionary`, `unequip(m:int, layer:int)->int`, `at_layer(m:int, layer:int)->int`, `total_weight(m:int)->int`, `bonus(m:int, key:String)->int` |
| `entity.stats` | `sim/entity/stats.gd` | `str_:int`, `dex:int`, `int_:int` (dřív tu stálo `str/dex/int:int`; `int` je klíčové slovo a `str` by přebilo globální funkci `str()`), `hits_max()->int` (= `50 + STR/2`), `stam_max()->int` (= DEX), `mana_max()->int` (= INT), `stat_total()->int`, `at_cap()->bool` |
| `entity.skills` | `sim/entity/skills.gd` | `value(skill:int)->int` (desetiny), `set_value(skill:int,v:int)->void`, `cap(skill:int)->int`, `total()->int`, `lock(skill:int)->int`, `set_lock(skill:int,l:int)->void` |
| `entity.notoriety` | `sim/entity/notoriety.gd` | `level(m:int)->int` (1 innocent … 6 murderer, 7 invulnerable), `is_criminal(m:int)->bool`, `flag_criminal(m:int, ms:int)->void`, `murder_counts(m:int)->int`, `award_fame_karma(m:int, fame:int, karma:int)->void` |
| `sim.entity_registry` | `sim/entity/registry.gd` | **DOPLNĚNO 2026-10-06 — smlouva pro granuli `sim.entity_registry`:** drží `serial -> mobil`; `register(m)->void`, **`get_mobile(serial)->Mobile|null`**, `all()->Array`, `remove(serial)->void`, navíc `size()->int` (používá jen test). Je to **jediné místo, kde se mobil hledá podle serialu** — `sim.movement` (`register`/`mobile` jsou průchod do registru) i `render.anim` (`body_of(serial)`) ho berou odtud. ⚠ **OPRAVA 2026-10-06 (rozhodl uživatel):** smlouva i roadmapa dřív žádaly `get(serial)`; to GDScript **neumí** — `get()` je metoda `Object` (`get(StringName)`) a jiná signatura je **parse error** (`The function signature doesn't match the parent`), který sada tiše přeskočí (otevřená věc 21). Platí `get_mobile`. Viz §4.2.1 |

### sim/systems

| id | soubor | provides | acceptance (konkrétní volání) |
|---|---|---|---|
| `sim.movement` | `sim/systems/movement.gd` | **odkud bere mobily (2026-10-06): z granule `sim.entity_registry`** — `register(mobile)->void` a `mobile(serial)` jsou jen průchod do registru; registr jde předat **konstruktorem** jako pátý argument (`_init(walk, clock, events, drain_model, registry)`), bez něj si systém založí vlastní. Dále `player_serial:int` (rozhoduje o asymetrické diagonále); `request_step(m:int, dir:int, run:bool)->Dictionary` (`{ok, delay_ms, reason}`), `apply_step(m:int, dir:int)->void`, `consume_stamina(m:int, steps:int)->void`, `pending_count()->int`, `delay_ms_for(run:bool)->int` | `request_step(m, 0, false).delay_ms == 400` **pro mobil v registru** (jinak `{ok:false, reason:"no_mobile"}`); po `apply_step` se `pos.x += 1`; viz §4.2.1 |
| `sim.interaction` | `sim/systems/interaction.gd` | **KÓD JE (DOPLNĚNO 2026-10-07, 10. session)** `use(m:int, serial:int)->Dictionary`, `use_on(m:int, serial:int, target:Dictionary)->Dictionary`, `context_menu(m:int, serial:int)->Array[Dictionary]`, `context_action(m:int, serial:int, entry:int)->Dictionary` — každý vrací `{ok, reason, action}` (**původní znění `->void` je zapsané v §4.2.1 i s důvodem, proč se změnilo**) | `use(m, anvil)` nic neudělá; `use_on(m, ore, {"serial": forge})` spustí tavení |
| `sim.combat` | `sim/systems/combat.gd` | `set_war(m:int, on:bool)->void`, `attack(m:int, target:int)->void`, `swing_delay_ms(m:int)->int`, `resolve_swing(m:int, t:int)->Dictionary`, `stop_combat(m:int)->void` | `swing_delay_ms` na `dex=100, speed=30` vrátí hodnotu dle vzorce z §5.5 |
| `sim.magic` | `sim/systems/magic.gd` | `cast(m:int, spell:int)->Dictionary` (`{ok, delay_ms, reagents, reason}`), `interrupt(m:int)->void`, `add_spell(m:int, spell:int)->bool`, `scribe(m:int, scroll:int)->bool` | `cast` bez reagent → `{ok:false, reason:"reagents"}` |
| `sim.skill_gain` | `sim/systems/skill_gain.gd` | `check(m:int, skill:int, difficulty:int)->Dictionary` (`{success, gained, new_value}`), `gain_stat(m:int, stat:int)->void` — **KÓD JE (DOPLNĚNO 2026-10-07, 11. session):** návrat je `{success, gained, new_value, reason}` s `reason` = `no_mobile`/`locked`/`too_difficult`/`cap`/`no_challenge`; `difficulty` je **`minSkill` v desetinách** a `maxSkill = difficulty + 500` (50,0 — naměřeno: 183 z 196 Blacksmithy receptů); `_init(registry, rng, clock, events)` bere **registr a RNG ze `SimWorld`** (vlastní RNG by rozbil determinismus); **růst je nezávislý na úspěchu** (naměřeno: 100 pokusů, 89 neúspěchů, skill 0 → 100) | opakované `check` s `difficulty` 0 při `value=0` dá za 100 pokusů > 0 |
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
| `ui.hud` | `ui/hud.gd` | kotvy oken, pozice oken, zapamatování rozložení — **KÓD JE (DOPLNĚNO 2026-10-07, 11. session):** `extends CanvasLayer`; `register_window(id, window, pos)->bool` (prázdné id nebo `null` uzel = `false`, okno se nevyrobí), `window_of`/`position_of` (neznámé = `null`, nikdy `(0,0)`), `set_position(id, pos)->bool` (přepíše a přenese na uzel), `layout()->Dictionary` (**kopie**), `restore_layout(data)->int` (počet obnovených; neznámé přeskočí). Kotvy oken zatím nejsou (nikdo je nečte) |
| `ui.paperdoll` | `ui/paperdoll.gd` | postava, vrstvy, drag na tělo, jméno, „war/peace" přepínač |
| `ui.status_bar` | `ui/status_bar.gd` | HP/Stam/Mana, váha, zlato, jméno — **KÓD JE (DOPLNĚNO 2026-10-07, 11. session):** `extends Control`; `update(values: Dictionary)` (hodnoty **jen vstupem**, chybějící klíč = 0), `text_for(values)->String` (čistá formátovací funkce, měřitelná bez okna), `apply_event(event)->bool` (bere jen `stats_changed`, jinak `false`); klíče `hp`/`hp_max` (alias `max_hp` podle události §4.4)/`stam`/`stam_max`/`mana`/`mana_max`/`weight`/`weight_max`/`gold`/`name`. Zapojeno v `app/main.gd` (`_setup_ui` + `_process`). ⚠ Událost `stats_changed` v §4.4 nemá `stam_max`/`mana_max` a dnes ji nikdo neposílá |
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
| `render.textures` | `render/texture_cache.gd` | načítání z manifestu, LRU, strop paměti; **tři id prostory** (land = id, item = id + `0x4000`, texmap = id + `0x10000`) a `texmap(texmap_id)->Texture2D` pro texturu svahu (doplněno 2026-10-07) |
| `render.hue` | `render/hue_cache.gd` | `(art_id, hue)` → textura (index 0 = použij hue); u `AtlasTexture` se bere **okno `region`**, ne celá stránka (opraveno 2026-10-07 — jinak se kreslily všechny framy animace) |
| `render.sort` | `render/sort.gd` | **jediná** funkce řazení (land → statics podle z → mobilové podle z) |
| `render.chunk` | `render/chunk_renderer.gd` | sestavení kreslicího seznamu pro viditelné bloky, cache; **land nese navíc `texmap` (TexID) a `z_corners` `[horní, pravý, levý, dolní]`** = výšky rohů ze sousedů (2026-10-07, pro svahy) |
| `render.anim` | `render/anim_player.gd` | `play(serial:int, action:int, dir:int, now_ms:int = -1)->Dictionary` → `{ok, texture, frame, count, anchor, mirror, mirror_x, sprite_dir}` (chybějící sprite = `ok:false` + `texture:null`); **číslo těla se bere z registru** — `body_of(serial)->int` (`-1`, když serial v registru není; bez registru je `serial` sám tělem, starší chování), registr jde předat konstruktorem `_init(manifest_path, registry)`; framy těl a worn artu podle `animdata`, časování 80 ms; zrcadlení 8 → 5 směrů a `mirror_x` viz §4.2.1 |
| `render.names` | `render/name_plates.gd` | jména a HP pruhy nad mobily (jen na dosah/po kliku) |
| `render.light` | `render/light_layer.gd` | úroveň světla z `world.time`, světelné zdroje (louče, okna) |
| `render.effects` | `render/effects.gd` | kouř, oheň, zásah, smrt, animace kouzel |

### app

| id | soubor | zodpovědnost |
|---|---|---|
| `app.main` | `app/main.gd` | scéna, kostra, načtení dat, spuštění smyčky |
| `app.loop` | `app/loop.gd` | pumpuje `sim.tick(50)`, překládá vstup na `Command`, předává události UI |
| `app.input` | `app/input_map.gd` | mapování kláves a myši na `Command` (jediné místo s `Input`); `poll(player, camera_offset, z=0, mouse_position=Vector2.ZERO, now_ms=-1)` — **držení kroky opakuje** (prodleva `step_delay_ms` = 400/200 ms), `walk_to` = držené pravé tlačítko (směr z kurzoru, `run` podle `mouse_run()` = 190 px od středu okna); `now_ms` a `view_size` jsou vstupy kvůli měřitelnosti (2026-10-07) |
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
- **`world.walk` má od 2026-10-07 ČTVRTÝ argument `doors`** (`world.doors`), protože
  **dveře mají `Impassable` v obou stavech** (naměřeno: `1717` i `1718` =
  `0x20006050`, výška 20) — stav se tedy **čte z `world.doors.is_open`**, ne z flagů.
  Kdo `doors` nepředá, dostane reálný `world.doors` (stejný vzor jako `stairs`).
- **`world.walk` čte statiky s `+0x4000` (2026-10-07, naměřená vada).**
  `world.map.statics_at` vrací `tile` v prostoru **tiledata id předmětu** (0..0x3FFF),
  ale `world.tiledata` klíčuje předměty jako **art id** (`tile >= 0x4000`); stejný
  posun dělá `render/chunk_renderer.gd`. Bez posunu `tiledata` vrátí u statiku řádek
  tabulky **LAND** (`flags(1717)` → `grass`/`0x00000000` místo `wooden door`/
  `0x20006050`) — v Británii to znamenalo, že `can_step` pustil **1 325 kroků** do
  dlaždice s `Impassable` statikem. Rozšíření smlouvy (nová konstanta `ITEM_OFFSET`).
- **`world.walk`: blokující statik platí jen ve svém výškovém pásmu** (docs/05
  §5.1.2 bod 2). Pásmo statiku je `[z, z + max(výška, 1))` — výška `0` se bere jako
  `1`, protože **645 druhů `Impassable` artů má v `tiledata` výšku 0** a prázdný
  interval by z nich udělal průchozí. Naměřeno v Británii: ze **6 750** kroků do
  dlaždice s překrývajícím se statikem jich kód před opravou pustil **1 173** (po
  opravě **0**); naopak ze **654** kroků, kde statik pásmo postavy neprotíná, jich
  před opravou **502** zbytečně blokoval.
- **`world.walk`: schody zvyšují povolený krok** (2026-10-07). Schod je statik
  s `Surface` a výškou 5 nebo 10 (**9 z 9** druhů schodů v Británii) a skok mezi
  sousedními schody je **přesně jeho výška** (histogram skoku povrchu v okolí
  180×180: `0× 436`, `±5 68+68`, `±1 2+2`). Krok nahoru se proto na dlaždici se
  schodem povoluje do výšky toho schodu (`world.stairs.is_stair`), ne jen
  `STEP_HEIGHT`. **Referenční spor:** RunUO/ServUO `Movement.Check` zná jen
  `startTop + StepHeight`, což by v reálné mapě znamenalo, že se po schodech nedá
  jít vůbec; Sphere má na schody **zvláštní** pravidlo (`CAN_I_CLIMB`,
  `m_zClimbHeight`, `zHeight/2` v `src/common/CServerMap.cpp:221`).
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
- **AKTUALIZACE 2026-10-06 (Úkol 1 hotový, kód existuje): obě díry jsou zavřené.**
  `sim/entity/registry.gd` drží `serial -> mobil`; `sim.movement` z něj mobily
  bere (`register`/`mobile` jsou průchod do registru, konstruktor ho bere pátým
  argumentem) a `render.anim` si z něj bere číslo těla (`body_of(serial)`;
  bez registru platí starší „serial = tělo"). Předchozí znění výš („kód ještě
  není", „Až vznikne `sim.entity_registry`, patří převod `serial -> body` tam")
  tím **přestalo platit** — zůstává tu jako záznam. **Otevřené zůstává:**
  `SimWorld.snapshot()` pořád vrací `mobiles: []` (věc granule `sim.world_loop`,
  ne registru), a `all()` je seřazené podle serialu (na pořadí vložení nesmí
  záviset stavový hash).
- **VADA SMLOUVY OPRAVENA 2026-10-06 (rozhodl uživatel): `get` → `get_mobile`.**
  Dřív tu stálo `get(serial)->Mobile|null` (a totéž v roadmapě). **GDScript to
  neumí:** `get()` je metoda `Object` (`get(StringName)`) a jiná signatura je
  **parse error** (`The function signature doesn't match the parent. Parent
  signature is "get(StringName) -> Variant"`). Naměřeno 2026-10-06: sada s tím
  hlásila **438 kontrol, 0 selhání** místo **480** — case soubor s parse errorem
  se tiše přeskočí (otevřená věc 21). Opraveno v tabulce §4.2 i v
  `tools/roadmap-gen.py`; `.forge/roadmap.json` se z generátoru přegeneruje.

- **`entity.item` + `entity.container` jsou HOTOVÉ (DOPLNĚNO 2026-10-07, 9. session).**
  Kód je `sim/entity/item.gd` a `sim/entity/container.gd`, testy `tests/cases/item.gd`
  a `tests/cases/container.gd` (cesta k měřenému souboru je **vstup**:
  `-- --item-script=` / `-- --container-script=`), mutační moduly `item` a
  `container` v `tools/gates/mutace-tests.py`. Co tabulka výš nepinovala a co je
  **naměřené** (doklady v HANDOFF.md, „CO JE NOVÉHO (9. session)"):
  - **`tile` je ART ID** (0x4000–0xFFFF), ne tiledata id. `docs/03` §3.4 to má
    v tabulce („item id = art id") a v tom prostoru berou `world.tiledata`
    (flags/weight/height/layer) i `render.textures`. `data/items.json`
    a `data/recipes.json` mají **tiledata id** — kdo z nich předmět vyrábí,
    přičítá `+0x4000` (stejná past jako u statiků ve `world.walk`, 6. session).
  - **Jedna instance `entity.container` = všechny kontejnery světa.** Smlouva bere
    `c:int` (serial kontejneru) a invariant „právě jeden rodič" jde držet jen
    tehdy, když `add` vidí i předchozího rodiče. Vzor: ServUO `Server/Item.cs:3971`
    (`AddItem` volá `RemoveItem` na předchozím rodiči, `:3999-4006`).
  - **`add` vrací `bool`, `can_add` vrací `{ok, reason}`.** Zadání granule
    v `.forge/roadmap.json` píše u přijímacího kritéria „přidání nad limit vrátí
    `{ok:false, reason:'full'}`", ale `provides` má `add(...)->bool` — platí
    `provides` a tvar `{ok, reason}` je v `can_add` (kritérium je tím splněné
    obojím: `add` vrátí `false` a `can_add` řekne `full`).
  - **`remove` vrací, KOLIK opravdu odstranil** (0 = předmět v tom kontejneru
    není; `amount <= 0` = celá hromada). Smlouva to neříkala.
  - **Limity:** 125 předmětů (`full`), 400 stones (`weight`), hromada 60 000
    (`stack`); váha = `tiledata.weight(tile) × amount` (ServUO `Server/Item.cs:3854`
    `PileWeight = ceil(Weight * Amount)`). Reference `Server/Items/Container.cs:1672-1673`
    (`m_GlobalMaxItems = 125`, `m_GlobalMaxWeight = 400`) a `CheckHold` `:230-268`.
  - **Sloučení hromad:** stejný `tile` + `hue` **a** flag `Generic` v tiledata =
    stackable (ClassicUO `TileDataLoader.cs:281`, `TileFlag.Generic = 0x00000800`;
    naměřeno nad `assets/uo/tiles.json`: zlato/obvaz/log/ingot/reagencie **ano**,
    dagger/longsword/backpack **ne**). Slučuje se do `MAX_STACK`; co se nevejde,
    zůstane předmětu. **Odchylky od ServUO (vědomé):** plná hromada není cíl
    sloučení (ServUO `WillStack` kapacitu nezkoumá a předmět pak přidá jako nový,
    čímž může překročit `MaxItems`) a plně sloučený předmět ServUO maže — my
    objekt volajícího smazat nemůžeme, takže skončí prázdný (`amount == 0`) a bez
    rodiče (`parent == 0`).
  - **Váha se bez `tiledata` NEMĚŘÍ** (`has_weights()`); je to závislost
    konstruktoru (ne preload), protože `sim/entity` nesmí na `sim/world` (§4.1).
  - **Co se NEMODELUJE (otevřené věci, ne dohady):** ServUO drží váhu jako
    `double`, u chybějícího údaje (tiledata 0 nebo 255) dosazuje 1
    (`Server/Item.cs:3806-3809`) a zlato si ji přebíjí na 0.02 stones
    (`Scripts/Items/Consumables/Gold.cs:34`) — naše data mají u zlata 0
    a přebíjení nemáme, takže **zlato u nás váží 0** (docs/05 §5.4 chce 0.02).
    Dále: vnořené kontejnery se do váhy nepočítají (ServUO `TotalWeight` je
    rekurzivní) a předchozí rodič **mobil** (nasazená výbava) se neuklízí —
    patří to `entity.equipment`.

- **`sim.interaction` je HOTOVÝ (DOPLNĚNO 2026-10-07, 10. session).** Kód je
  `sim/systems/interaction.gd`, test `tests/cases/interaction.gd` (cesta k měřenému
  souboru je **vstup**: `-- --interaction-script=`), mutační modul `interaction`
  v `tools/gates/mutace-tests.py` (**13 vzorů**). Co tabulka výš nepinovala a co je
  **naměřené** (doklady v HANDOFF.md, „CO JE NOVÉHO (10. session)"):
  - **Návrat `Dictionary` místo `->void`.** **Původní znění** řádku §4.2 bylo:
    `use(...)->void`, `use_on(...)->void`, `context_action(...)->void` (a jen
    `context_menu(...)->Array[Dictionary]`). Kód vrací `{ok, reason, action}`,
    protože `void` **nerozliší „nic se nestalo" od „není to hotové"** — a cíl
    10. session chce obojí rozlišit (`use_on` bez systému vrací
    `{ok:false, reason:"not_available"}`). `context_menu` vrací `Array[Dictionary]`
    podle smlouvy; položka je `{entry, text, custom}`.
  - **Konstruktor (smlouva ho neuvádí):** `_init(world, events, doors, containers,
    registry, items)` — všechno je **vstup**, aby se routing dal měřit bez assetů
    (stejný vzor jako `world.walk` a `sim.movement`). `items` je `{serial: Item}`
    nebo objekt s `get_item(serial)`: **registr předmětů neexistuje** (věc 64),
    takže „odkud je předmět podle serialu" je dnes věc volajícího.
  - **Routing se rozhoduje z DAT** (`data/items.json`, granule `data.items`):
    `category` (container/weapon/armor/shield/clothing/tool/light/misc/material)
    a `role` (pickaxe, smith hammer, anvil, forge, iron ore, …). Kdo si tabulku
    opíše do kódu, rozejde se s daty. **Pozor na dva id prostory:** `entity.item.tile`
    je **ART ID**, data mají **TILEDATA ID** (naměřeno: názvy v `tiles.json` sedí
    na indexu `tile` i u **4 744** záznamů s `tile >= 0x4000`) — modul proto hledá
    **nejdřív** `tile - 0x4000`.
  - **`anvil` a `forge` mají v datech `category == "tool"`, ale jsou to CÍLE**
    (naměřeno: 18 záznamů `tool`, z toho 16 nástrojů a tyto 2 cíle). Konstantní
    `TARGET_ROLES` z nich dělá „neznámý předmět" — proto `use` na kovadlinu nic
    neudělá **a řekne to** (přijímací kritérium).
  - **Dynamický routing** do `SimWorld.systems` (`craft`, `magic`, `harvest`,
    `vendor`, `combat`, `equipment`, `light`): když systém není nebo nemá metodu,
    vrací `{ok:false, reason:"not_available"}` **a hlášku** — nikdy ticho.
    Neúspěšné volání (`callv` vrátí `null`) je `reason:"bad_system"`, ne úspěch.
  - **§5.2.3 je pokrytá 10 řádky z 36** (11 párů; řádek 26 má dvě podoby
    materiálu — `logs` i `boards`). Zbytek potřebuje data, která v `data/items.json`
    **nejsou** (ryba, vlna, nit, obvaz, klíč, lockpick, pochodeň, svitek do knihy,
    reagent, runa, moongate, srp, vědro, měch, sextant, hodiny); chybějící řádek
    odpoví hláškou. Test to měří **proti dokumentu** (`docs/05` musí mít 36 řádků
    a množina párů v kódu = řádky + pár z §5.2.2), takže nový řádek v dokumentu
    test shodí, dokud se pokrytí nedoplní.
  - **Kontextové menu:** `0x0078` (Open Backpack) a `0x0193` (Paperdoll) jsou
    čísla, která **klient zná** (ServUO `Server/ContextMenus/ContextMenu.cs:178-256`
    přes `research/01` §2.4); ostatní jsou `>= 0x64` = vlastní (`custom: true`),
    protože clilocy jsou UNVERIFIED (docs/11 O7).
  - **⚠ Díry ve smlouvě, které kód odhalil (nezamlčené):** §4.4 **nemá událost
    „art existujícího předmětu se změnil"** — přepnutí dveří posílá `item_added`
    se **stejným serialem** (obnovení u klienta); a seznam gumpů v §4.4 **nemá
    `paperdoll`**, přesto ho `context_action` posílá. Obě věci patří do rozhodnutí,
    ne do tichého rozšíření smlouvy.

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

# Item (sim/entity/item.gd) - KÓD JE (2026-10-07); `tile` = ART ID (0x4000-0xFFFF)
{ serial:int, tile:int, hue:int, amount:int,
  parent:int,            # 0 = na zemi, jinak serial kontejneru/mobila
  layer:int,             # 0 = nenasazený
  pos:Vector3i,          # platné jen na zemi
  flags:int,             # 0x01 blessed, 0x02 newbie, 0x04 locked, 0x08 insured
  durability:int, max_durability:int, quality:int,  # 0 normal, 1 exceptional
  props:Dictionary }     # AoS properties: {"damage_increase":25, ...}

# Kontejner NENÍ pole v Item (2026-10-07): obsah drží `sim/entity/container.gd`
# podle SERIALU kontejneru (`can_add`/`add`/`remove`/`weight_of`/`contents`)
# a JEDINÁ instance spravuje všechny kontejnery světa - jinak by nešel držet
# invariant "právě jeden rodič" (viz §4.2.1). Item sám drží jen `parent` a `pos`.

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

### 4.8.1 Co harness dělá, když se case soubor NENAČTE (DOPLNĚNO 2026-10-07)

**Tiché přeskočení byla vada a je opravená.** `load()` na case soubor s parse
errorem vrací **nenulový `GDScript`**, který ale nejde instanciovat; `script.new()`
pak vyhodí runtime error, `_init_case` se **přeruší** a vrátí `null` — a smyčka to
do 2026-10-07 brala jako „už ohlášeno" a soubor přeskočila. Naměřeno: sada
hlásila **503 kontrol, 0 selhání** (správně 537) a `exit 0`. Dnes platí:

* `_init_case` se ptá `can_instantiate()` **před** `new()` a každou cestu, která
  vrátí `null`, **hlásí** (`_pending` → `FAIL`, `exit 1`);
* `tests/lib.gd:script_at()` vrací `null` i pro skript s parse errorem (jinak by
  se přerušil `run()` case souboru a zmizel by zbytek kontrol);
* case soubor, který **nepřidá ani jednu kontrolu**, je `FAIL` (`0 novych kontrol`);
* souhrn navíc vypisuje `case souboru spusteno: N z M`.

Ověřeno **třemi mutacemi** (parse error v case souboru → `27 z 28`, `504/1`,
`exit 1`; parse error v měřené granuli → tři case soubory `FAIL`, `453/3`;
parse error v granuli, kterou case `preloaduje` → `26 z 28`, `480/3`).

### 4.8.2 Fixture: aby testy měřily i v CI (DOPLNĚNO 2026-10-07)

`assets/uo/` je v `.gitignore`, takže v CI data z instalace UO nejsou. Testy
granul, které data potřebují, proto mají **fixture v gitu** a měří ji **VŽDY**
(ne jen když data chybí):

| fixture | co pokrývá | doklad |
|---|---|---|
| `tests/fixtures/world/` | bloky mapy (`world.map`, `world.walk`) | `make_fixture.py --check` |
| `tests/fixtures/hues/` | sady barev (`render.hue`) | `mutace-render-hue.py` **12/12** i bez `assets/uo/` |
| `tests/fixtures/anim/` | framy animace (`render.anim`) | `mutace-render-anim.py` **11/11** i bez `assets/uo/` |

**Pravidlo pro fixture:** očekávané hodnoty musí být v testu **zapsané**
(literály), ne přečtené z téhož souboru, který se měří — jinak je kontrola
kruhová a sabotáž fixture projde (naměřeno u obou nových fixture; odhalil to až
požadavek „vrať do fixture vadu a ukaž, že test spadne").

**Mutační harnessy v CI:** `mutace-tests.py`, `mutace-skills.py`,
`mutace-render-hue.py`, `mutace-render-anim.py` a `mutace-anim.py` — poslední
měří bez instalace UO jen `self-test` a **řekne to** (`realna sonda: NEMERENA`;
jeho sonda na reálných datech má navíc baseline na originále, aby chybějící data
nevypadala jako „mutace chycena").
