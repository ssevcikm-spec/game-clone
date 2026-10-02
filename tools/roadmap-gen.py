"""Generator .forge/roadmap.json — DAG granulí pro vývoj hry.

Proč generátor a ne ručně psaný JSON:
  * kontrola, že každé `depends_on` existuje (žádná křídová závislost),
  * kontrola, že `owns` jsou v každé vlně disjunktní,
  * jednotný tvar záznamu (prompt se skládá z povinných částí),
  * žádné chybějící uvozovky v promptu (roadmapa se čte z repa).

Spuštění:  python tools/roadmap-gen.py [--check]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".forge" / "roadmap.json"

G = []


def g(gid, title, owns, deps=(), provides=(), consumes=(), acceptance=("tests", "wiring"),
      size="<= 60", model="any", milestone="M0", kind="code", prompt=""):
    G.append({
        "id": gid,
        "title": title,
        "kind": kind,
        "owns": list(owns),
        "depends_on": list(deps),
        "provides": list(provides),
        "consumes": list(consumes),
        "acceptance": list(acceptance),
        "size_lines": size,
        "model": model,
        "milestone": milestone,
        "prompt": prompt,
    })


# ---------------------------------------------------------------- bootstrap
# Tyto položky NEJSOU pro agenty: zakládá je člověk (jsou to zakázané soubory).
g("boot.project", "Projekt Godot a konvence", ["project.godot"],
  provides=["projekt spustitelný `godot --path .`"], milestone="M0", kind="bootstrap",
  prompt="Založ projekt Godot 4.7.2 (2D), vstupní scénu a konvence z docs/02 §2.5-2.6. Jen člověk.")
g("boot.tests", "Testovací harness", ["tests/run_tests.gd", "tests/replays/"],
  provides=["_check(), spouštění přes --headless --script"], milestone="M0", kind="bootstrap",
  prompt="Harness pro headless testy bez scény a assetů (docs/04 §4.8). Jen člověk.")
g("boot.gates", "Brány a CI", ["tools/gates/", ".github/workflows/ci.yml"],
  provides=["check-schema, check-layers, check-wiring, check-content, check-assets, check-render, check-save, check-determinism, check-replay"],
  milestone="M0", kind="bootstrap",
  prompt="Brány podle docs/08 (každá umí selhat, každá má offline test). Jen člověk.")
g("boot.ci_env", "CI: Godot a APPDATA", ["tools/gates/ci-godot.sh"],
  provides=["spuštění Godotu v CI s přesměrovaným APPDATA a importem"],
  deps=["boot.gates"], milestone="M0", kind="bootstrap",
  prompt="Skript pro CI: import assetů, přesměrování APPDATA, spuštění testů a snímku (docs/08 §8.4).")

# ---------------------------------------------------------------- M0 kostra
g("core.const", "Konstanty světa", ["core/const.gd"],
  deps=["boot.project"],
  provides=["TILE_W, TILE_H, ISO_STEP, Z_SCALE, Z_MIN, Z_MAX, TICK_MS, WALK_MS, RUN_MS, MOUNT_*, TURN_MS, PERSON_HEIGHT, STEP_HEIGHT, LIFT_RANGE, MAX_STACK, CONTAINER_*, SKILL_CAP, STAT_CAP"],
  acceptance=["tests", "schema"], milestone="M0",
  prompt="Konstanty podle docs/02 §2.4 a docs/05: 44/22/4, 400/200/100 ms, PERSON_HEIGHT 16, STEP_HEIGHT 2, LIFT_RANGE 2, MAX_STACK 60000, caps 7000/225. Žádná hodnota se nesmí objevit dvakrát v projektu (brána G1).")
g("core.iso", "Izometrická projekce", ["core/iso.gd"],
  deps=["core.const"],
  provides=["to_screen(x,y,z) -> Vector2", "to_tile(sx,sy,z) -> Vector2i", "block_of(x,y) -> Vector2i"],
  acceptance=["tests"], milestone="M0",
  prompt="Projekce screen.x=(x-y)*22, screen.y=(x+y)*22-z*4 a přesná inverze (docs/02 §2.4). Test: to_tile(to_screen(p)) == p pro 1000 náhodných bodů.")
g("core.rng", "Deterministický RNG", ["core/rng.gd"],
  deps=["core.const"],
  provides=["new(seed)", "next_u32()", "range_i(a,b)", "chance(p)", "state()", "restore(d)"],
  acceptance=["tests", "determinism"], milestone="M0",
  prompt="PCG32 s uložitelným stavem. Dva běhy se stejným seedem musí dát stejnou posloupnost (docs/04 §2.3).")
g("core.clock", "Herní hodiny a timery", ["core/clock.gd"],
  deps=["core.const"],
  provides=["now_ms()", "after(delay_ms, cb) -> int", "cancel(id)", "advance(ms)"],
  acceptance=["tests"], milestone="M0",
  prompt="Fronta timerů řazená podle (čas, id) — deterministické pořadí (docs/04 §2.3). Test: timer na 400 ms se spustí přesně po 8 ticcích po 50 ms.")
g("core.serial", "Serialy entit", ["core/serial.gd"],
  deps=["core.const"],
  provides=["next()", "is_item(s)", "is_mobile(s)", "reset(next)"],
  acceptance=["tests"], milestone="M0",
  prompt="Přidělování id: mobile >= 0x40000000, item < 0x40000000 (docs/11.7). Test: 1000 id je unikátních a klasifikace sedí.")
g("core.events", "Fronta událostí", ["core/events.gd"],
  deps=["core.const"],
  provides=["push(name, data)", "drain() -> Array", "clear()"],
  acceptance=["tests"], milestone="M0",
  prompt="Simulace nikdy nevolá UI — jen plní frontu (docs/04 §4.4). Test: push 3 událostí, drain vrátí 3 v pořadí a fronta je prázdná.")
g("core.hash", "Kanonický hash stavu", ["core/hash.gd"],
  deps=["core.const"],
  provides=["of_state(parts) -> String"],
  acceptance=["tests", "determinism"], milestone="M0",
  prompt="SHA-256 kanonické serializace (seřazené klíče, jen inty) (docs/04 §4.7). Test: dva slovníky s jiným pořadím klíčů dají stejný hash.")
g("data.balance", "Vyvážení a éry", ["data/balance.json"],
  deps=["boot.project"],
  provides=["combat_era, stamina_drain_model, ggs_on, insurance_on, anti_macro, skill_cap, stat_cap"],
  acceptance=["tests", "schema"], milestone="M0",
  prompt="Rozhodnutí z docs/05 §5.16: combat_era=aos, stamina_drain_model=run_only, ggs_on=true, insurance_on=false, anti_macro=false. Každá hodnota s poznámkou `source`.")
g("sim.commands", "Příkazy klient → sim", ["sim/commands.gd"],
  deps=["core.const", "core.events"],
  provides=["parse(d)", "validate(c) -> {ok, reason}", "dispatch(sim, c)"],
  acceptance=["tests"], milestone="M0",
  prompt="Tabulka příkazů z docs/04 §4.3. Neplatný příkaz se zahodí s hláškou do žurnálu, nikdy nespadne. Test: neznámý typ příkazu vrátí {ok:false} a nic nezmění.")
g("sim.world_loop", "Jádro simulace", ["sim/sim_world.gd"],
  deps=["core.rng", "core.clock", "core.serial", "core.events", "core.hash", "sim.commands", "data.balance"],
  provides=["new(seed, data)", "enqueue(c)", "tick(ms)", "snapshot()", "state_hash()", "save(path)", "load(path)"],
  acceptance=["tests", "save", "determinism"], milestone="M0",
  prompt="Tick 50 ms, pevné pořadí systémů, save/load podle docs/04 §4.7. Umí běžet bez scény. size_lines > 60 → model strong. ZACHOVEJ signaturu tick(ms) pro všechny systémy.")
g("app.main", "Scéna a start hry", ["app/main.gd"],
  deps=["sim.world_loop"],
  provides=["spuštění hry, načtení dat, první frame"],
  acceptance=["smoke"], milestone="M0", size="<= 120", model="strong",
  prompt="Scéna, která vytvoří sim, data a předá řízení app.loop (docs/02 §2.5). Nesmí obsahovat herní pravidla.")
g("app.loop", "Smyčka a převod vstupu", ["app/loop.gd"],
  deps=["app.main", "sim.world_loop"],
  provides=["pumpne sim.tick(50)", "překlad vstupu na Command", "rozdání událostí UI"],
  acceptance=["smoke", "tests"], milestone="M0",
  prompt="Jediné místo, kde se potkává čas enginu a čas simulace. Fixní krok: při poklesu FPS se dohání ticky, maximálně 5 za frame (docs/04 §2.2).")
g("app.input", "Mapování vstupu", ["app/input_map.gd"],
  deps=["sim.commands"],
  provides=["klik → Command", "klávesy → Command/makro"],
  acceptance=["tests"], milestone="M0",
  prompt="Jediné místo v projektu, které smí používat Input (docs/02 §2.2). Test: simulovaný klik na dlaždici vytvoří move/use příkaz.")

# ---------------------------------------------------------------- M1 data a svět
g("assets.uop", "Čtení UOP kontejneru", ["tools/uoextract/uop.py"],
  deps=["boot.project"],
  provides=["UopFile: hlavička, hash tabulka, hash funkce, zlib dekomprese, get(hash) -> bytes"],
  acceptance=["assets"], milestone="M1", size="<= 150", model="strong",
  prompt="Portuj MYP0 cteni (docs/03 §3.5, research/05 §1.2, research/07). ART SE UZ EXTRAHOVAT PODARILO (soubor je v tools/uoextract/), takze vychazej z nej. Zbyvaji DVA ROZPORY, ktere rozhodni TESTEM, ne podle zdroje: (1) hash jmena zaznamu - Jenkins hashlittle2 (seed len + 0xDEADBEEF) vs CreateHash z ClassicUO (jedna vetev 100 %, druha 1636/2000); implementuj obe, změř na 2 000 indexech, pouzij tu se 100 %. (2) komprese gumpart - BWT vs zlib; dekomprimuj batoh a PODIVEJ SE na nej (read_image). Hlavicka: u64 nextBlock@12, u32 blockSize@20, i32 count@24 (u map ZAPORNE), u32 concurrency@28. Staticky art = tiledata_id + 0x4000.")
g("assets.tiledata", "Čtení tiledata", ["tools/uoextract/tiledata.py"],
  deps=["assets.uop"],
  provides=["land(tile) -> {flags, texture, name}", "item(tile) -> {flags, weight, layer, count, anim_id, hue, light, height, name}"],
  acceptance=["assets", "content"], milestone="M1", size="<= 150", model="strong",
  prompt="LAYOUT JE VYŘEŠENÝ (docs/03 §3.3.1) - nehledej ho znovu: land = offset 4, 512 skupin x (u32 hlavicka + 32 zaznamu x 30 B) = [u64 flags][u16 texId][20B jmeno]; item = offset 493568, 2048 skupin x (u32 + 32 x 41 B) = [u64 flags][u8 weight][u8 layer][i32 count][u16 animID][u16 hue][u16 light][u8 height][20B jmeno, na +21]; soucet = 3 188 736 B, rezerva 0 B. Portuj z ClassicUO (BSD-2). OVER: u vsech predmetu s flagem Wearable (0x00400000) je vrstva nenulova a sedi na jmeno (leather cap -> 6, backpack -> 21, dagger -> 1, anvil -> weight 255 layer 0). POZOR: tato instalace NEMA klasicka jmena (zadne 'leather gloves'/'gold'/'bandage') - obsah se vybira podle vlastnosti, ne podle klasickych seznamu (docs/03 §3.3.1b).")
g("assets.cliloc", "Čtení kliloků", ["tools/uoextract/cliloc.py"],
  deps=["boot.project"],
  provides=["cliloc(id) -> String", "cliloc_all() -> Dictionary"],
  acceptance=["assets", "content"], milestone="M1",
  prompt="Cliloc.enu je BWT-komprimovany (docs/03 §3.3.2): kdyz data[3] == 0x8E, rozbal BWT (port z ClassicUO ClilocLoader.cs, BSD-2), pak preskoc u32+u16 a ctni zaznamy [i32 cislo][u8 flag][i16 delka v BAJTECH][UTF-8 text]. OVER: vypis 5 po sobe jdoucich zaznamu a najdi v souboru anglicky text.")
g("assets.art", "Dekódování artu", ["tools/uoextract/art.py"],
  deps=["assets.uop"],
  provides=["art(item_id) -> RGBA obrázek", "land_art(tile_id) -> RGBA"],
  acceptance=["assets"], milestone="M1",
  prompt="RLE formát 16bit (0x8000 = neprůhledný) podle docs/03 §3.5. Ověř: 6 známých art ID ulož jako PNG, zkontroluj rozměry a podívej se na ně (read_image).")
g("assets.gump", "Dekódování gumpů", ["tools/uoextract/gump.py"],
  deps=["assets.uop"],
  provides=["gump(id) -> RGBA"],
  acceptance=["assets"], milestone="M1",
  prompt="gumpart 16bit s alfou (docs/03 §3.5.1). Ověř na známém gumpu (batoh/paperdoll) a podívej se na výsledek.")
g("assets.hues", "Barvy z hues.mul", ["tools/uoextract/hues.py"],
  deps=["boot.project"],
  provides=["hues.json: 3000 sad x 32 barev + start + end + jmeno"],
  acceptance=["assets"], milestone="M1",
  prompt="LAYOUT JE OVERENY (docs/03 §3.2b): 375 skupin x (4 B hlavicka + 8 x 88 B) = 3000 sad, 265 500 B presne; zaznam = 32 barev (u16) + start (u16) + end (u16) + 20B jmeno. POZOR: plochy model (4 + k*88) je SPATNY - posouva se o 4 B kazdych 8 zaznamu. Over semanticky: text 'Hue (X->Y)' musi sedet s poli start/end u vsech zazanamu (spravny model da ~1000/1000, plochy jen ~47).")
g("assets.anim", "Animace těl", ["tools/uoextract/anim.py"],
  deps=["assets.uop", "assets.art"],
  provides=["anim(body, action, dir) -> framy + časování"],
  acceptance=["assets"], milestone="M1", size="<= 150", model="strong",
  prompt="Rozhodni zdroj (anim*.mul vs AnimationFrame*.uop) podle pokrytí těl (docs/03 §3.5.1, O3) a zapiš rozhodnutí. Extrahuj jen těla, která obsah potřebuje.")
g("assets.worldmap", "Mapa a statiky", ["tools/uoextract/worldmap.py"],
  deps=["assets.uop", "assets.tiledata"],
  provides=["map0.land", "map0.statics.bin/.idx", "map0.meta.json"],
  acceptance=["assets", "content"], milestone="M1", size="<= 150", model="strong",
  prompt="Format a matematika bloku podle docs/03 §3.4: blok je 196 B = u32 hlavicka + 64 x 3 B (u16 tile_id, i8 z) - POZOR, bunka je 3bajtova, ne 4bajtova (overeno dekompresi bloku na presnych 0xC4000 B). Prijimaci kriterium: index statics se precte cely, Britain (1495,1630) ma statiky, voda tvori souvisle plochy.")
g("assets.textdata", "Textová a pravidlová data", ["tools/uoextract/textdata.py"],
  deps=["boot.project"],
  provides=["data z doors.txt, stairs.txt, teleprts.txt, misc.txt, body.def, Corpse.def, Bodyconv.def, Equipconv.def, animinfo, mobtypes.txt, skills.mul, skillgrp.mul"],
  acceptance=["assets", "content"], milestone="M1",
  prompt="Převeď do JSON podle docs/03 §3.6. Ověř počty: doors 37 kategorií, skills 58 jmen, skillgrp 6 skupin.")
g("assets.atlas", "Atlas a manifest", ["tools/uoextract/atlas.py"],
  deps=["assets.art", "assets.gump", "assets.anim", "assets.hues"],
  provides=["atlas/*.png (2048²)", "manifest.json (art, gumps, anim, source sha256, ox/oy)"],
  acceptance=["assets"], milestone="M1", size="<= 150", model="strong",
  prompt="Shelf-pack, deterministické řazení, offsety zarovnání (docs/03 §3.5.2). Dva běhy musí dát shodný SHA-256 manifestu.")
g("assets.verify", "Ověření extrakce", ["tools/uoextract/verify.py"],
  deps=["assets.atlas", "assets.tiledata"],
  provides=["verify() -> report (počty, chyby, NEMĚŘENO)"],
  acceptance=["assets"], milestone="M1",
  prompt="Samostatné ověření výstupu (docs/03 §3.5.3): 6 známých art ID není prázdných, offsety sedí (postava stojí nohama na dlaždici — snímek), manifest odpovídá stránkám.")
g("assets.extract_cli", "CLI extraktoru", ["tools/uoextract/extract.py"],
  deps=["assets.verify", "assets.worldmap", "assets.textdata"],
  provides=["extract.py --install <cesta> --out assets/uo [--only ...]"],
  acceptance=["assets"], milestone="M1",
  prompt="Jeden vstupní bod, který pustí kroky v pořadí a vypíše souhrn (docs/03 §3.7). Při změně SHA-256 vstupů skončí s hláškou (past P16).")
g("world.tiledata", "Vlastnosti dlaždic ve hře", ["sim/world/tiledata.gd"],
  deps=["assets.tiledata", "data.items"],
  provides=["flags(tile)", "height(tile)", "layer(tile)", "weight(tile)", "value(tile)", "name(tile)"],
  acceptance=["tests"], milestone="M1",
  prompt="Načti z extrahovaných dat (ne z .mul!), drž v paměti efektivně, jen čtení (docs/04 §4.2).")
g("world.map", "Bloky mapy", ["sim/world/map.gd"],
  deps=["core.iso", "world.tiledata"],
  provides=["land_at(x,y)", "z_at(x,y)", "statics_at(x,y)", "load_block(bx,by)", "is_loaded(bx,by)"],
  acceptance=["tests", "content"], milestone="M1", size="<= 120", model="strong",
  prompt="Čtení .land/.statics po blocích s LRU cache (docs/03 §3.4). Test: blok Britainu obsahuje statiky a land id v rozsahu 0..0x3FFF.")
g("render.textures", "Cache textur", ["render/texture_cache.gd"],
  deps=["world.tiledata"],
  provides=["texture(art_id) -> Texture2D", "stats() -> {loaded, bytes}"],
  acceptance=["tests"], milestone="M1",
  prompt="Načítání z manifestu s LRU a stropem paměti (docs/02 §2.7). Test: po 10 000 požadavcích nepřekročí strop.")
g("render.hue", "Tónování hue", ["render/hue_cache.gd"],
  deps=["render.textures", "assets.hues"],
  provides=["hued(art_id, hue) -> Texture2D"],
  acceptance=["tests"], milestone="M1",
  prompt="Index 0 v artu = použij hue; cache (art_id, hue) s LRU (docs/03 §3.5.2). Test: hue 0 vrátí původní texturu, jiný hue vrátí odlišné pixely.")
g("render.sort", "Řazení kreslení", ["render/sort.gd"],
  deps=["core.iso", "world.map"],
  provides=["sort_key(obj) -> int", "draw_order(objects) -> Array"],
  acceptance=["tests", "render"], milestone="M1",
  prompt="Jediná funkce řazení: land → statics podle z → mobilové podle z, dlaždice podle (x+y) (docs/02 §2.4, past P21). Test: dva objekty stejné dlaždice s různým z mají správné pořadí.")
g("render.chunk", "Chunkový renderer", ["render/chunk_renderer.gd"],
  deps=["render.sort", "render.textures", "world.map"],
  provides=["kreslení viditelných bloků", "invalidace při změně bloku"],
  acceptance=["render", "tests"], milestone="M1", size="<= 150", model="strong",
  prompt="Sestav kreslicí seznam pro viditelné bloky, cachuj, přepočítej při změně (docs/02 §2.4). Cíl: 60 FPS při 1280×720.")
g("render.anim", "Přehrávání animací", ["render/anim_player.gd"],
  deps=["render.textures", "assets.anim"],
  provides=["play(serial, action, dir)", "frame_ms(action)"],
  acceptance=["tests", "render"], milestone="M1", size="<= 120", model="strong",
  prompt="Framy z manifestu, časování 80 ms (docs/05 §5.1.1). Skládej vrstvy výbavy podle layerů.")
g("render.names", "Jména a pruhy", ["render/name_plates.gd"],
  deps=["render.chunk"],
  provides=["jméno nad objektem", "HP pruh", "barva podle notoriety"],
  acceptance=["render"], milestone="M1",
  prompt="Jméno po kliku/najetí, barva podle notoriety (docs/04 §4.4).")
g("render.light", "Světlo dne a zdroje", ["render/light_layer.gd"],
  deps=["world.time"],
  provides=["úroveň světla", "světelné zdroje (louče, okna)"],
  acceptance=["render"], milestone="M1",
  prompt="Úroveň z world.time (den 12, dungeon 26) + bodová světla (docs/05 §5.11).")
g("data.items", "Katalog předmětů", ["data/items.json"],
  deps=["assets.tiledata"],
  provides=["items.json: tile, name, category, weight, value, layer, flags, source, era"],
  acceptance=["content", "schema"], milestone="M1", kind="data",
  prompt="Vygeneruj z tiledata + doplňků (docs/06 §6.2). Každý záznam má `source`; chybějící art = chyba, ne tichý přeskok.")
g("data.gen_content", "Generátor obsahu", ["tools/gates/gen-content.py"],
  deps=["data.items"],
  provides=["generuje data/*.json z research/*.json + tiledata, idempotentně"],
  acceptance=["content"], milestone="M1", size="<= 150", model="strong",
  prompt="Generátor podle docs/06 §6.1: 1150 receptů, zbraně, zbroje, monstra, vendory, kouzla. Nevyřešené položky jdou do content-report.json (nikdy tiše).")

# ---------------------------------------------------------------- M2 pohyb a interakce
g("entity.stats", "Staty a odvozené hodnoty", ["sim/entity/stats.gd"],
  deps=["core.const"],
  provides=["str, dex, int_", "hits_max() = 50 + STR/2", "stam_max() = DEX", "mana_max() = INT", "stat_total()"],
  acceptance=["tests"], milestone="M2",
  prompt="Podle docs/05 §5.10 a research/01 §3.1. Test: STR 100 → hits_max 100; INT 50 → mana_max 50.")
g("entity.skills", "Skilly v desetinách", ["sim/entity/skills.gd"],
  deps=["core.const", "data.skills"],
  provides=["value(skill)", "set_value(skill, v)", "cap(skill)", "total()", "lock(skill)", "set_lock(skill, l)"],
  acceptance=["tests"], milestone="M2",
  prompt="58 hodnot v desetinách (int), strop 1000/1200, celkový strop 7000 (docs/05 §5.10). NIKDY nepoužívej float. Test: hodnota 1000 + pokus o růst = zůstane 1000.")
g("entity.mobile", "Mobil (entita)", ["sim/entity/mobile.gd"],
  deps=["entity.stats", "entity.skills", "core.serial"],
  provides=["serial, body, hue, pos, dir, hp/stam/mana, flags, equip, backpack, notoriety, fame, karma, hunger, ai"],
  acceptance=["tests"], milestone="M2",
  prompt="Tvar dat přesně podle docs/04 §4.5 (klíč pro int je `int_`, ne `int`).")
g("entity.item", "Předmět", ["sim/entity/item.gd"],
  deps=["core.serial"],
  provides=["serial, tile, hue, amount, parent, layer, pos, flags, durability, quality, props"],
  acceptance=["tests"], milestone="M2",
  prompt="Tvar podle docs/04 §4.5. Test: předmět na zemi má parent 0 a platné pos; v kontejneru má parent a pos se ignoruje.")
g("entity.container", "Kontejner", ["sim/entity/container.gd"],
  deps=["entity.item"],
  provides=["can_add(c, item)", "add(c, item)", "remove(c, item, amount)", "weight_of(c)", "contents(c)"],
  acceptance=["tests"], milestone="M2",
  prompt="Limity 125 předmětů / 400 stones, stack 60000 (docs/05 §5.4). Test: přidání nad limit vrátí {ok:false, reason:'full'} a stav se nezmění.")
g("entity.equipment", "Výbava a vrstvy", ["sim/entity/equipment.gd"],
  deps=["entity.item", "entity.container"],
  provides=["equip(m, item)", "unequip(m, layer)", "at_layer(m, layer)", "total_weight(m)", "bonus(m, key)"],
  acceptance=["tests"], milestone="M2",
  prompt="Vrstvy 0x00-0x1F (docs/11.7, research/01 §2.6). Dvouruční zbraň uvolní vrstvu štítu. Test: equip štítu při dvouručné zbrani vrátí {ok:false}.")
g("entity.notoriety", "Notoriety, fame, karma", ["sim/entity/notoriety.gd"],
  deps=["entity.mobile"],
  provides=["level(m)", "is_criminal(m)", "flag_criminal(m, ms)", "murder_counts(m)", "award_fame_karma(m, fame, karma)"],
  acceptance=["tests"], milestone="M2",
  prompt="Kriminální flag 2 min, vrah od 5 vražd, karma ±10000 (docs/05 §5.9, research/01 §3.4-3.6).")
g("sim.movement", "Pohyb", ["sim/systems/movement.gd"],
  deps=["entity.mobile", "world.walk", "core.clock"],
  provides=["request_step(m, dir, run)", "apply_step(m, dir)", "consume_stamina(m, steps)"],
  acceptance=["tests", "replay"], milestone="M2", size="<= 120", model="strong",
  prompt="Prodlevy 400/200/200/100 ms a stamina (docs/05 §5.1). Test: chůze po volné dlaždici → delay 400, posun po 8 ticcích o 1 dlaždici; voda → {ok:false}.")
g("world.walk", "Průchodnost a výšky", ["sim/world/walk.gd"],
  deps=["world.map", "world.tiledata", "world.stairs"],
  provides=["can_step(from, dir, height, is_player)", "surface_z(x,y)"],
  acceptance=["tests"], milestone="M2", size="<= 120", model="strong",
  prompt="PERSON_HEIGHT 16, STEP_HEIGHT 2, jen flagy Impassable/Surface/Wet, diagonála asymetricky (docs/05 §5.1.2). Test: hráč u rohu nesmí diagonalizovat, NPC ano.")
g("world.doors", "Dveře", ["sim/world/doors.gd"],
  deps=["assets.textdata"],
  provides=["is_door(tile)", "toggle(tile)", "category(tile)", "open_tile(cat, orient)"],
  acceptance=["tests"], milestone="M2",
  prompt="Kategorie z doors.txt (docs/03 §3.6): přepni art, změň průchodnost, přehraj zvuk. Test: dvojklik otevře a druhý zavře.")
g("world.teleport", "Teleporty a moongates", ["sim/world/teleport.gd"],
  deps=["assets.textdata", "data.regions"],
  provides=["teleport_target(x,y,z)", "moongate_target(name)"],
  acceptance=["tests"], milestone="M2",
  prompt="Dlaždice z teleprts.txt + 9 moongate s přesnými souřadnicemi (docs/05 §5.11, research/06). Test: vstup na moongate Britain přenese na 1336,1997.")
g("world.stairs", "Schody", ["sim/world/stairs.gd"],
  deps=["assets.textdata"],
  provides=["is_stair(tile)", "stair_group(tile)"],
  acceptance=["tests"], milestone="M2",
  prompt="Kategorie ze stairs.txt (Block, N/E/S/W, Squared, Rounded) (docs/03 §3.6).")
g("world.regions", "Regiony a města", ["sim/world/regions.gd"],
  deps=["data.regions"],
  provides=["region_at(x,y)", "is_guard_zone(x,y)", "music_at(x,y)"],
  acceptance=["tests"], milestone="M2",
  prompt="19 měst s hranicemi a obsluhou (research/06 §1.4-1.5, docs/06 §6.7). Test: Britain 1495,1630 je město a guard zóna.")
g("world.time", "Herní čas a světlo", ["sim/world/time.gd"],
  deps=["core.clock"],
  provides=["hour()", "minute()", "is_night()", "light_level()"],
  acceptance=["tests"], milestone="M2",
  prompt="SecondsPerUOMinute = 5.0 → den 7200 s (docs/05 §5.11, past P12). Test: po 7200 s je stejná hodina jako na začátku.")
g("sim.interaction", "Interakce (use / use-on)", ["sim/systems/interaction.gd"],
  deps=["entity.container", "entity.equipment", "world.doors", "sim.craft", "sim.magic"],
  provides=["use(m, serial)", "use_on(m, serial, target)", "context_menu(m, serial)", "context_action(m, serial, entry)"],
  acceptance=["tests", "replay"], milestone="M2", size="<= 150", model="strong",
  prompt="Routing podle docs/05 §5.2.2 a párová tabulka §5.2.3 (kontrolní seznam z Tilehelp.enu). Neznámý předmět → hláška, nikdy ticho.")
g("ui.hud", "Kotvy a okna", ["ui/hud.gd"],
  deps=["app.main"], provides=["okna, jejich pozice a ukládání rozložení"],
  acceptance=["smoke"], milestone="M2",
  prompt="Drž pozice oken, žádná herní logika.")
g("ui.journal", "Žurnál", ["ui/journal.gd"],
  deps=["app.loop"], provides=["zprávy s barvami podle typu", "scroll"],
  acceptance=["tests"], milestone="M2",
  prompt="Přijímej událost `message` (docs/04 §4.4). Test: 100 zpráv nezpomalí frame.")
g("ui.status_bar", "Stavový pruh", ["ui/status_bar.gd"],
  deps=["app.loop"], provides=["HP/Stam/Mana, váha, zlato"],
  acceptance=["tests"], milestone="M2",
  prompt="Data z události `stats_changed`, nikdy nepočítej sám.")
g("ui.paperdoll", "Paperdoll", ["ui/paperdoll.gd"],
  deps=["app.loop", "render.anim"], provides=["postava s vrstvami", "drag na tělo", "war/peace"],
  acceptance=["render"], milestone="M2",
  prompt="Vrstvy podle pořadí (docs/04 §4.2) + přepínač war/peace.")
g("ui.target_cursor", "Kurzor cíle", ["ui/target_cursor.gd"],
  deps=["app.input"], provides=["zobrazení kurzoru", "odeslání target_reply", "Esc ruší"],
  acceptance=["tests"], milestone="M2",
  prompt="Reaguj na událost `target_request` (docs/04 §4.3-4.4). Test: Esc odešle target_reply s null.")
g("ui.context_menu", "Kontextové menu", ["ui/context_menu.gd"],
  deps=["app.input"], provides=["menu z context_menu()", "odeslání context_action"],
  acceptance=["tests"], milestone="M2",
  prompt="Vlastní položky mají čísla >= 0x64 (docs/04 §4.3).")
g("ui.dragdrop", "Drag & drop", ["ui/dragdrop.gd"],
  deps=["app.input", "ui.paperdoll"], provides=["zvednutí", "kurzor s předmětem", "drop na svět/kontejner/vrstvu"],
  acceptance=["tests"], milestone="M2",
  prompt="Dosah 2 dlaždice (docs/05 §5.4), predikce jen vizuální — rozhoduje sim. Test: drop mimo dosah → hláška a předmět se vrátí.")
g("ui.tooltip", "Tooltip předmětu", ["ui/tooltip.gd"],
  deps=["app.loop"], provides=["jméno, vlastnosti, váha, hodnota"],
  acceptance=["tests"], milestone="M2",
  prompt="Vlastnosti z AoS props (docs/05 §5.16) — zobrazuj, nepočítej.")
g("ui.hotkeys", "Klávesy a makra", ["ui/hotkeys.gd"],
  deps=["app.input"], provides=["výchozí sada", "poslední cíl", "obvaz sebe"],
  acceptance=["tests"], milestone="M2",
  prompt="Výchozí sada je ROZHODNUTÍ, zapiš ji do docs/ (docs/05 §5.3).")
g("ui.options", "Nastavení", ["ui/options.gd"],
  deps=["app.main"], provides=["rozlišení, zoom, hlasitost, always run, klávesy"],
  acceptance=["smoke"], milestone="M2",
  prompt="Ukládej mimo save hry (do user://), nikdy neměň stav simulace.")

# ---------------------------------------------------------------- M3 předměty
g("ui.backpack", "Gump batohu", ["ui/backpack.gd"],
  deps=["ui.dragdrop"], provides=["mřížka položek batohu"],
  acceptance=["render"], milestone="M3",
  prompt="Gump id z manifestu, obsah z události `container_contents`.")
g("ui.container_window", "Obecný kontejner", ["ui/container_window.gd"],
  deps=["ui.backpack"], provides=["okno truhly/těla/banky"],
  acceptance=["render"], milestone="M3",
  prompt="Stejná logika jako batoh, jiný gump; tělo (corpse) má právo na loot 2 min (docs/05 §5.4).")
g("sim.regen", "Regenerace", ["sim/systems/regen.gd"],
  deps=["entity.stats", "sim.hunger"], provides=["tick() — hp/stam/mana"],
  acceptance=["tests"], milestone="M3",
  prompt="Podle statů a hladu (docs/05 §5.14). Test: mana roste u postavy s INT > 0.")
g("sim.hunger", "Hlad a jídlo", ["sim/systems/hunger.gd"],
  deps=["entity.mobile"], provides=["eat(m, item)", "level(m)"],
  acceptance=["tests"], milestone="M3",
  prompt="Hlad −1 za 5 min (docs/05 §5.14). Test: sníst jídlo sníží hlad a předmět zmizí.")
g("sim.decay", "Rozpad předmětů", ["sim/systems/decay.gd"],
  deps=["entity.item"], provides=["tick() — rozpad na zemi (60 min), těla (7 min)"],
  acceptance=["tests"], milestone="M3",
  prompt="Časy podle docs/05 §5.4; tělo se rozpadne i s obsahem. Test s posunem času.")

# ---------------------------------------------------------------- M4 skilly, sběr, výroba
g("data.skills", "Data skillů", ["data/skills.json"],
  deps=["assets.textdata"], provides=["58 skillů: id, jméno, skupina, stat primární/sekundární, implemented"],
  acceptance=["content", "schema"], milestone="M4", kind="data",
  prompt="Jména a pořadí z skills.mul (ověřeno, docs/11.1), mechaniky z research/02. `implemented: false` pro Necromancy/Bushido/Ninjitsu/Spellweaving/Throwing/Imbuing/Mysticism (docs/05 §5.16).")
g("sim.skill_gain", "Růst skillů a statů", ["sim/systems/skill_gain.gd"],
  deps=["entity.skills", "entity.stats"], provides=["check(m, skill, difficulty)", "gain_stat(m, stat)"],
  acceptance=["tests", "determinism"], milestone="M4",
  prompt="Krok +0.1, GGS zapnutý, strop 7000 a zámky (docs/05 §5.10, research/01 §3.3). Test: 100 pokusů při hodnotě 0 zvýší skill.")
g("sim.harvest", "Sběr surovin", ["sim/systems/harvest.gd"],
  deps=["world.map", "sim.skill_gain", "entity.container"], provides=["mine(m,x,y)", "chop(m,x,y)", "fish(m,x,y)", "resource_left(x,y)"],
  acceptance=["tests"], milestone="M4", size="<= 150", model="strong",
  prompt="Pravidla a čísla podle docs/05 §5.7 a research/04 §1-2 (9 rud, buckety, 10 logů, 8 s rybolov). Test: správná dlaždice + nástroj → surovina; jinak {ok:false}.")
g("sim.craft", "Výroba, tavení, oprava", ["sim/systems/craft.gd"],
  deps=["entity.container", "sim.skill_gain", "data.recipes", "world.tiledata"],
  provides=["recipes_for(m, skill)", "craft(m, recipe_id, count)", "smelt(m, ore, forge)", "repair(m, tool, target)"],
  acceptance=["tests", "content"], milestone="M4", size="<= 150", model="strong",
  prompt="Vzorce podle docs/05 §5.8 (úspěch, exceptional, dvojitý hod, spotřeba při neúspěchu, smelt 66 %). Test: dagger ze 3 ingotů, bez kovadliny {ok:false}.")
g("ui.craft_gump", "Gump výroby", ["ui/craft_gump.gd"],
  deps=["sim.craft"], provides=["strom receptů, make last / make number"],
  acceptance=["tests"], milestone="M4",
  prompt="Nedostupné recepty zešednou, ale zůstanou vidět (docs/05 §5.8).")
g("ui.skill_list", "Seznam skillů", ["ui/skill_list.gd"],
  deps=["sim.skill_gain"], provides=["58 skillů, hodnota, zámek, tlačítko use"],
  acceptance=["tests"], milestone="M4",
  prompt="Hodnota v desetinách formátovaná na 0.0–120.0, zámky up/down/lock (docs/05 §5.10).")
g("data.recipes", "Data receptů", ["data/recipes.json"],
  deps=["data.gen_content", "data.items"], provides=["1150 receptů: skill, min/max, kategorie, materiály, výsledek, era"],
  acceptance=["content", "schema"], milestone="M4", kind="data",
  prompt="Vygeneruj z research/04-craft-data.json (docs/06 §6.3). Každý recept musí odkazovat na existující materiály a výsledek.")

# ---------------------------------------------------------------- M5 souboj
g("data.weapons", "Data zbraní", ["data/weapons.json"],
  deps=["data.items"], provides=["~120 zbraní: skill, hands, damage, speed, str_req, weight, layer, special"],
  acceptance=["content", "schema"], milestone="M5", kind="data",
  prompt="Z research/03 (weapons3.json). Vrstva z tiledata, dokud není, `layer: null` + `layer_source: pending-tiledata` (past P19).")
g("data.armor", "Data zbrojí", ["data/armor.json"],
  deps=["data.items"], provides=["~90 kusů: slot, AR/resisty, str_req, weight, trvanlivost, materiál"],
  acceptance=["content", "schema"], milestone="M5", kind="data",
  prompt="Z research/03 (armor_raw.json), stejné pravidlo pro vrstvy.")
g("data.item_properties", "Vlastnosti předmětů (AoS)", ["data/item_properties.json"],
  deps=["data.items"], provides=["159 vlastností: typ, rozsahy, stupně, váhy"],
  acceptance=["content", "schema"], milestone="M5", kind="data",
  prompt="Z research/03 (itemprops_table.tsv). Slouží loot generátoru (docs/06 §6.4).")
g("data.monsters", "Data monster", ["data/monsters.json"],
  deps=["data.gen_content"], provides=["88 monster: staty, skilly, damage, resisty, fame/karma, loot, AI, flagy"],
  acceptance=["content", "schema"], milestone="M5", kind="data",
  prompt="Z research/06 §3 (docs/06 §6.5). Minimálně 45 použitých musí mít loot a AI typ.")
g("sim.combat", "Souboj", ["sim/systems/combat.gd"],
  deps=["entity.equipment", "data.weapons", "data.armor", "sim.skill_gain", "core.clock"],
  provides=["set_war(m, on)", "attack(m, target)", "swing_delay_ms(m)", "resolve_swing(m, t)", "stop_combat(m)"],
  acceptance=["tests", "replay"], milestone="M5", size="<= 150", model="strong",
  prompt="AoS vzorce podle docs/05 §5.5 (swing 40000/swiftness, hit chance s HCI/DCI, resisty, Tactics je damage skill). Test: 20 swingů dá >=5 zásahů a cíl ztratí hp.")
g("sim.poison", "Jed", ["sim/systems/poison.gd"],
  deps=["entity.mobile"], provides=["apply(m, level)", "cure(m, level)", "tick()"],
  acceptance=["tests"], milestone="M5",
  prompt="5 úrovní podle research/03 (docs/05 §5.14). Test: jed 3. úrovně ubere hp do 10 s.")
g("sim.ai", "AI monster a NPC", ["sim/systems/ai.gd"],
  deps=["sim.movement", "sim.combat", "world.regions"], provides=["tick(m)", "set_state(m, state)"],
  acceptance=["tests", "replay"], milestone="M5", size="<= 150", model="strong",
  prompt="Stavy idle/wander/aggro/attack/flee/dead + vendor/guard (docs/05 §5.12). Test: NPC v idle se do 10 s pohne (wander).")
g("sim.loot", "Loot a magické předměty", ["sim/systems/loot.gd"],
  deps=["entity.container", "data.monsters", "data.item_properties"], provides=["fill_corpse(mob, corpse)", "roll_magic_item(level)"],
  acceptance=["tests"], milestone="M5",
  prompt="pre-AoS LootPack + magic chance (docs/05 §5.16, research/06 §3). Test: monstrum se zlatem nechá v těle zlato.")
g("sim.death", "Smrt, duch, vzkříšení", ["sim/systems/death.gd"],
  deps=["entity.container", "entity.notoriety"], provides=["die(m)", "resurrect(m, hp)", "is_ghost(m)"],
  acceptance=["tests", "replay"], milestone="M5",
  prompt="Corpse + ghost + hp=10 po vzkříšení (docs/05 §5.13). Test: po die je is_ghost true a inventář v těle.")

# ---------------------------------------------------------------- M6 magie
g("data.spells", "Data kouzel", ["data/spells.json"],
  deps=["data.gen_content"], provides=["64 kouzel: kruh, mana, reagenty, cíl, efekt, prodleva"],
  acceptance=["content", "schema"], milestone="M6", kind="data",
  prompt="Z research/03 (spells_raw.json) — mana {4,6,9,11,14,20,40,50}, reagenty 1 od každého (docs/05 §5.6).")
g("sim.magic", "Sesílání kouzel", ["sim/systems/magic.gd"],
  deps=["data.spells", "entity.skills", "sim.skill_gain", "entity.container"], provides=["cast(m, spell)", "interrupt(m)", "add_spell(m, spell)", "scribe(m, scroll)"],
  acceptance=["tests", "replay"], milestone="M6", size="<= 150", model="strong",
  prompt="Prodleva (4+kruh)*0.25 - FC*0.25, FC<=2, FCR<=6, LRC = jeden hod (docs/05 §5.6). Test: bez reagent {ok:false, reason:'reagents'} a žádná mana se neodečte.")
g("ui.spellbook", "Spellbook", ["ui/spellbook.gd"],
  deps=["sim.magic"], provides=["8 kruhů, ikony, drag na lištu"],
  acceptance=["render"], milestone="M6",
  prompt="Naučená kouzla z události, sesílání přes Command{t:'cast'}.")

# ---------------------------------------------------------------- M7 ekonomika a svět
g("data.vendors", "Data vendorů a obchodů", ["data/vendors.json"],
  deps=["data.gen_content"], provides=["25 vendorů: zboží, ceny, restock, profese"],
  acceptance=["content", "schema"], milestone="M7", kind="data",
  prompt="Z research/06 §4 (docs/06 §6.6). Ceny: buy = 1.90 × sell (docs/05 §5.9).")
g("data.spawns", "Spawn tabulky", ["data/spawns.json"],
  deps=["data.monsters"], provides=["12 tabulek prostředí + 3 dungeony + města"],
  acceptance=["content", "schema"], milestone="M7", kind="data",
  prompt="Z research/06 §5 (docs/06 §6.7) — regionální tabulky, prodlevy 5-10 min, refill 1/3.")
g("data.regions", "Regiony, moongates, dungeony", ["data/regions.json", "data/moongates.json", "data/dungeons.json"],
  deps=["data.gen_content"], provides=["19 měst s hranicemi, 9 moongate, 3 dungeony"],
  acceptance=["content", "schema"], milestone="M7", kind="data",
  prompt="Z research/06 §1 (docs/06 §6.7) — přesné souřadnice.")
g("data.professions", "Profese pro tvorbu postavy", ["data/professions.json"],
  deps=["data.skills"], provides=["8 profesí: skilly, staty, výbava"],
  acceptance=["content", "schema"], milestone="M7", kind="data",
  prompt="3 klasické z Prof.txt (Warrior/Mage/Blacksmith, ověřeno) + zbytek jako ROZHODNUTÍ s `source: decision` (docs/11.1, O8).")
g("sim.vendor", "Obchod", ["sim/systems/vendor.gd"],
  deps=["entity.container", "data.vendors", "world.tiledata"], provides=["stock(v)", "buy_price(v, item, amount)", "sell_price(...)", "buy(m,v,lines)", "sell(m,v,lines)", "restock()"],
  acceptance=["tests", "replay"], milestone="M7", size="<= 120", model="strong",
  prompt="buy = 1.90 × sell, restock 60 min, gump max 250 řádků (docs/05 §5.9). Test: prodej 10 kusů vrátí 10 × sell_price.")
g("ui.vendor_gump", "Obchodní gump", ["ui/vendor_gump.gd"],
  deps=["sim.vendor"], provides=["seznam k prodeji/koupi, množství, cena, potvrzení"],
  acceptance=["tests"], milestone="M7",
  prompt="UI jen zobrazuje ceny ze simulace (docs/05 §5.3).")
g("world.spawn", "Správa spawnu", ["sim/world/spawn.gd"],
  deps=["data.spawns", "sim.ai"], provides=["register(point)", "tick()", "alive_at(point_id)"],
  acceptance=["tests", "replay"], milestone="M7",
  prompt="Jeden world tick místo tisíců spawnerů (docs/05 §5.12). Test: po zabití monstra se do 10 min obnoví.")
g("app.char_create", "Tvorba postavy", ["app/char_create.gd"],
  deps=["data.professions", "entity.skills"], provides=["volba profese, staty, skilly, jméno, barvy"],
  acceptance=["tests"], milestone="M7",
  prompt="Profese z data/professions.json, staty a skilly se nastaví podle šablony, start v Britainu (docs/06 §6.7).")
g("ui.menu", "Hlavní menu", ["ui/menu.gd"],
  deps=["app.main"], provides=["nová hra, načíst, nastavení, konec"],
  acceptance=["smoke"], milestone="M7",
  prompt="Menu je jen rozcestník; ukládání řeší sim.world_loop (docs/04 §4.7).")

# ---------------------------------------------------------------- M8 trvanlivost
g("render.effects", "Efekty", ["render/effects.gd"],
  deps=["render.chunk"], provides=["kouř, oheň, zásah, smrt, animace kouzel"],
  acceptance=["render"], milestone="M8",
  prompt="Efekty jsou jen vizuální, nikdy nemění stav simulace (docs/02 §2.2).")
g("ui.macros", "Uživatelská makra", ["ui/macros.gd"],
  deps=["ui.hotkeys"], provides=["makra uložená v user://, spouštění Commandů"],
  acceptance=["tests"], milestone="M8",
  prompt="Uložení mimo save hry, determinismus simulace nesmí záviset na macrech (docs/04 §2.3).")
g("docs.credits", "Zdroje a poděkování", ["CREDITS.md"],
  deps=["assets.extract_cli"], provides=["seznam zdrojů dat, kódu a licencí"],
  acceptance=["schema"], milestone="M8", kind="doc",
  prompt="Zapiš zdroje: instalace UO (verze, SHA-256), ClassicUO (BSD-2), SphereServer (Apache-2.0), fakta ze ServUO/ModernUO (GPL, jen čísla), volné assety (docs/03 §3.1, docs/11.2).")


def main() -> int:
    check = "--check" in sys.argv
    ids = {x["id"] for x in G}
    errs = []

    for x in G:
        for d in x["depends_on"]:
            if d not in ids:
                errs.append(f"{x['id']}: depends_on na neexistující granuli '{d}'")
        if not x["owns"]:
            errs.append(f"{x['id']}: prázdné owns")
        if not x["acceptance"]:
            errs.append(f"{x['id']}: prázdné acceptance")

    # kolize owns mezi granulemi
    owner = {}
    for x in G:
        for f in x["owns"]:
            if f in owner:
                errs.append(f"owns kolize: '{f}' v {owner[f]} i {x['id']}")
            owner[f] = x["id"]

    # cykly v DAG
    graph = {x["id"]: list(x["depends_on"]) for x in G}
    state = {}

    def visit(n, path):
        if state.get(n) == 1:
            errs.append("cyklus v DAG: " + " -> ".join(path + [n]))
            return
        if state.get(n) == 2:
            return
        state[n] = 1
        for m in graph.get(n, []):
            visit(m, path + [n])
        state[n] = 2

    for n in graph:
        visit(n, [])

    doc = {
        "_popis": [
            "UO klon — DAG granulí. Generováno z tools/roadmap-gen.py (needituj ručně).",
            "Pravidla: 1 granule = 1 soubor, owns je výlučné, depends_on znamená 'hotové a funkční'.",
            "kind: code | data | gate | bootstrap | doc. Bootstrap granule NEJSOU pro agenty (zakázané soubory).",
            "size_lines/model: výchozí '<= 60' a 'any'; 'strong' jen pro deklarované velké celky.",
            "acceptance: tests | wiring | content | assets | render | save | determinism | replay | smoke | schema.",
            "Postup a milníky: docs/07-granule-a-milniky.md; smlouvy: docs/04-architektura-a-smlouvy.md.",
        ],
        "milestones": [
            {"id": "M0", "title": "Kostra a pravidla"},
            {"id": "M1", "title": "Data a svět (extrakce assetů)"},
            {"id": "M2", "title": "Pohyb a interakce"},
            {"id": "M3", "title": "Předměty a manipulace"},
            {"id": "M4", "title": "Skilly, sběr, výroba"},
            {"id": "M5", "title": "Souboj a smrt"},
            {"id": "M6", "title": "Magie"},
            {"id": "M7", "title": "Ekonomika a svět"},
            {"id": "M8", "title": "Trvanlivost a uzavření"},
        ],
        "grains": G,
    }

    stats = {}
    for x in G:
        stats[x["milestone"]] = stats.get(x["milestone"], 0) + 1
    print(f"granulí: {len(G)}")
    for m in sorted(stats):
        print(f"  {m}: {stats[m]}")
    print(f"  strong: {sum(1 for x in G if x['model'] == 'strong')}, "
          f"bootstrap: {sum(1 for x in G if x['kind'] == 'bootstrap')}")

    if errs:
        print("\nCHYBY:")
        for e in errs:
            print("  -", e)
        return 1

    if check:
        print("\nOK: DAG je konzistentní (žádná chybějící závislost, kolize owns ani cyklus).")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(doc, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nzapsáno: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
