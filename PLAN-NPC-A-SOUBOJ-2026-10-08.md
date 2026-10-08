# PLÁN — nasazení NPC do světa a bojový systém (UO-klon, 2026-10-08)

> **Co je tenhle soubor: PLÁN** (návrh pořadí, smluv a bran), **ne stav a ne
> záznam o provedení.** Podle plánu se má *začít stavět*; co se z něj provedlo,
> se doplní do §13 (a do `HANDOFF.md`).

| Údaj | Hodnota |
|---|---|
| **Datum vzniku** | 2026-10-08, session „plán NPC a souboje" (běžela **paralelně k session 19**) |
| **Datum spotřeby** | **2026-10-08 (první spotřeba): vloženo do zdrojů pravdy** — provedeno D1 + D7, nová granule `app.pick`, opravy promptů a smluv (§13). **Implementace sama ještě nezačala** — etapy E0–E6 čekají; zadání pro ně je [`ZADANI-20-NPC-A-SOUBOJ.md`](ZADANI-20-NPC-A-SOUBOJ.md) |
| **Současný stav projektu** | [`HANDOFF.md`](HANDOFF.md) (přepisuje se každou session); měřený stav granul: `python tools/plan-status.py` |
| **Zadání, ze kterého plán vychází** | [`ZADANI-UO-KLON.md`](ZADANI-UO-KLON.md), [`docs/05`](docs/05-mechaniky.md) §5.5, §5.12–§5.16, [`docs/06`](docs/06-obsah.md) §6.4–§6.8, [`docs/07`](docs/07-granule-a-milniky.md) §7.2 (M5) |
| **Kdo to smí provádět** | Session s **plným přístupem** (v `workspace-write` padají brány G3/G7/G11 — viz `ZADANI-19-VADY-ZE-SNIMKU.md` §0) a **až po commitu session 19** (§2.4) |
| **Co v plánu ZÁMĚRNĚ není** | magie, vendory a obchod, zvuk, 3 dungeony, 12 spawn tabulek (to je M6/M7) — seznam v §8 |

**Jak se podle plánu postupuje:** §11 je pořadí kroků (E0…E6). Každá granule má
v §5 smlouvu (co poskytuje, s jakým tvarem dat) a v §7 přijímací kritérium.
**Tvrdá pravidla projektu platí i tady** ([`docs/09`](docs/09-pravidla-pro-agenta.md)):
1 granule = 1 soubor, `tests/`, `docs/`, `.forge/` a `tools/gates/` agent needituje,
„hotovo" = soubor v `main` **A** brána zavolala jeho funkci **A** kritérium
proběhlo s konkrétní hodnotou.

---

## 1. Co má být na konci vidět (cíl a zážitek)

**Cíl jednou větou:** hráč potká v divočině kolem Britainu monstrum, zaútočí na
něj (dvojklikem), monstrum zaútočí zpět, jedno z nich umře — a když umře
monstrum, nechá tělo s lootem; když umře hráč, stane se duchem a nechá se
vzkřísit.

To je **milník M5 „Souboj a smrt"** z [`docs/07`](docs/07-granule-a-milniky.md) §7.2
(„zabije kostlivce, dostane loot, umře, stane se duchem, nechá se vzkřísit") —
a plán k němu přidává to, co v něm chybí: **odkud se monstrum v Mapě vezme**
(`world.spawn` + `data.spawns` jsou dnes v M7, viz rozhodnutí D1 v §3).

**Herní smyčka, kterou plán staví (věta po větě, podle `docs/01` §1.3):**

1. Hráč jde po mapě a vidí na dlaždicích **statiky, terén — a nově i mobily**
   (kostlivce, krysy, zombie) ve stejném pořadí kreslení jako dnes statiky.
2. Na dosah se monstrum **samo všimne** hráče (aggro), dojde k němu (krok za
   400/200 ms — stejná pravidla průchodnosti jako hráč) a zaútočí.
3. Hráč na monstrum **dvojklikne** → `Command{t:"attack", serial}` → `war`
   režim, cíl, švih podle zbraně a skillu; každý zásah odečte HP, pošle
   `message` do žurnálu a `mobile_anim` (útok) na klienta.
4. Když monstrum padne: `sim.death.die()` vytvoří **tělo (corpse)** s lootem
   (`sim.loot.fill_corpse`), pošle `death` + `mobile_removed`, tělo se po
   **7 minutách** rozpadne.
5. Když padne hráč: stane se **duchem** (monstra ho nevidí, nemůže útočit),
   jde k léčitelce/ankhu, `resurrect` → **hp = 10**.
6. Spawn tabulka **doplňuje** mrtvá monstra (prodleva 5–10 min, refill 1/3),
   takže svět nezůstane prázdný.

**Co se na konci měří (ne „vypadá to dobře"):**

| # | Měření | Kde |
|---|---|---|
| V1 | Na snímku je **kostlivec** (jiné tělo než hráč) a je **vidět**, ne pod terénem | `read_image` + G10 |
| V2 | 20 švihů na kostlivce dá **≥ 5 zásahů** a kostlivec ztratí HP | test `tests/cases/combat.gd` |
| V3 | Po zabití je v jeho těle **zlato/loot**, tělo je předmět ve světě | test + G5 |
| V4 | Po smrti hráče je `is_ghost == true`, po vzkříšení `hp == 10` | test |
| V5 | Spawn po zabití **obnoví** monstrum do 10 minut herního času | test `world.spawn` |
| V6 | Dva běhy se stejným seedem a stejnými příkazy (včetně NPC) dají **stejný hash** | G8 + nový replay |
| V7 | Tick s **200 mobily** ≤ 2 ms (docs/08 G12) | **nová brána — dnes neexistuje** (§7.3) |

---

## 2. Naměřený výchozí stav (co je a co není)

**Základ měření:** `HEAD = d6a1188` (2026-10-08 14:02) **+ necommitnutá práce
session 19** (`git status` níže). Kdo bude plán provádět, **zopakuje měření** —
číselné údaje tady jsou „ve svém čase správné", ne věčné.

### 2.1 Granule: soubor je, nebo není

Postup: `python tools/plan-status.py` (měří `owns` proti gitu a přítomnost
testu; **nečte `done`** — to se v roadmapě ručně nevede).

| Milník | Hotové (soubor + test) | Soubor je, test není | Soubor chybí |
|---|---|---|---|
| M3 (předměty) | 0 | 0 | **5** |
| M5 (souboj a smrt) | 0 | 0 | **9** |
| M7 (ekonomika a svět) | 0 | 0 | **9** |
| celkem | 59 z 111 | 4 | 48 |

**Všech 9 granul M5 má `owns` soubor, který na disku NENÍ:**

```
data.weapons   data/weapons.json          sim.combat  sim/systems/combat.gd
data.armor     data/armor.json            sim.poison  sim/systems/poison.gd
data.item_properties data/item_properties.json  sim.ai  sim/systems/ai.gd
data.monsters  data/monsters.json         sim.loot    sim/systems/loot.gd
                                          sim.death   sim/systems/death.gd
```

**Předpoklady, které plán povolává (a které taky chybí):**

| Granule | Soubor | Milník | Proč to plán potřebuje |
|---|---|---|---|
| `entity.equipment` | `sim/entity/equipment.gd` | M2 | **deklarovaná závislost `sim.combat`** — bez ní není odkud vzít zbraň (skill, rychlost, damage) |
| `entity.notoriety` | `sim/entity/notoriety.gd` | M2 | **deklarovaná závislost `sim.death`**; AI potřebuje „kdo je nepřítel" |
| `sim.hunger`, `sim.regen` | `sim/systems/{hunger,regen}.gd` | M3 | bez regenerace se HP ani stamina nikdy nedoplní → souboj je jednosměrný (naměřeno v 19. session: „postava běží 3 políčka a staminu nedožene") |
| `sim.decay` | `sim/systems/decay.gd` | M3 | rozpad těla za 7 minut a předmětů |
| `data.regions`, `world.regions` | `data/regions.json`, `sim/world/regions.gd` | M2 | **deklarovaná závislost `sim.ai`** (region → spawn tabulka, guard zóna) |
| `render.names` | `render/name_plates.gd` | M1 | jméno a HP pruh nad cílem (`docs/05` §5.5.2: „jméno cíle a jeho HP pruh po kliku") |
| `assets.sounds` + `audio.playback` | `tools/uoextract/sounds.py`, `app/sound.gd` | M1/M2 | zvuk zásahu — **vlastní trať, v plánu je jen `sound` událost** (§8) |

### 2.2 Co v kódu už JE (a co plán jen zapojí)

| Co | Kde (naměřeno) |
|---|---|
| Příkazy `attack {serial}` a `war {on}` **už jsou routované** na `combat.attack` / `combat.set_war` | `sim/commands.gd:37` a `:109-112` (měřeno 2026-10-08; ⚠ soubor **přepsala session 19** — čísla se posunula z 29/97, viz P20) |
| `use` na mobil **už** jde do `combat.attack` (routing `attack_or_talk`) | `sim/systems/interaction.gd:73`, `:275-276` |
| `SYSTEM_ORDER` **už** počítá s `combat, magic, skill_gain, harvest, craft, ai, vendor, loot, death, poison, regen, hunger, spawn` — chybějící systém se jen přeskočí | `sim/sim_world.gd:34-37`, `:87-89` |
| Registr bytostí (jediné místo `serial → mobil`), pohyb **umí krokovat libovolný mobil** z registru (`request_step(m, dir, run)`), `player_serial` rozhoduje jen o diagonále hráče | `sim/entity/registry.gd`; `sim/systems/movement.gd` — **funkce `request_step` / `apply_step` / `pending_step`** (⚠ soubor je rozpracovaný session 19 → **cituju jménem, ne řádkem**, past P20) |
| A* hledání cesty (`find`, `next_step`) nad `world.walk.can_step` | `sim/world/pathfind.gd` (176 řádků, M2 hotová) |
| Animace těla pro **libovolný serial** (tělo se bere z registru: `body_of(serial)`) | `render/anim_player.gd:71-114` |
| Řazení objektů **jednou funkcí** včetně `kind: "mobile"` | `render/sort.gd:65-95`; hráč se řadí `{"kind":"mobile"}` (`app/world_view.gd:738-741`) |
| Žurnál umí `message {text, kind, hue}` (barvy podle druhu) | `ui/journal.gd:54-103` |
| Stavový pruh umí `stats_changed` | `ui/status_bar.gd:10-24` |
| `data/mobtypes.json` — **1 495 řádků** `id, type, flags` (MONSTER 307, ANIMAL 166, HUMAN 26, SEA_MONSTER 4, EQUIPMENT 992), zdroj `mobtypes.txt` | měřeno Pythonem nad `data/mobtypes.json` |

### 2.3 Co v kódu NENÍ (a plán to musí postavit)

| Vada/mezera | Doklad (měřeno) | Důsledek pro plán |
|---|---|---|
| **Klient neumí vybrat, na co klikl.** `input_map.object_command(serial)` existuje, ale **nikdo ho v produkci nevolá**; `poll()` vydává jen `click_at` (krok na dlaždici) | funkce `object_command` a `poll` v `app/input_map.gd`; volající `app/loop.gd:39` (⚠ `input_map.gd` je rozpracovaný session 19 → jménem, ne řádkem) | nová granule `app.pick` (hit test) — §5.2 |
| **Svět kreslí jen statiky a terén; mobil jen hráč** | `app/world_view.gd:404-418` (`_list()` = `_chunk.visible(...)`), `:743` (`_draw_player`) | rozšíření `app.player_view` (integrace, §11 E5) |
| **Animace jsou exportované jen pro těla 400/401 a akce `0:walk, 1:run, 4:idle`** → kostlivec by se nekreslil a nebylo by čím zahrát útok | `assets/uo/anim/anim-sheets.json`: `actions = {0:walk,1:run,4:idle}`, 30 spritů, těla jen 400 a 401; výchozí `--actions` v `tools/uoextract/anim.py:823` | krok navíc: **export těl monster + akce útoku/smrti** (§11 E0) |
| **`snapshot()` vrací `mobiles: []` a `state_hash()` hashuje prázdná pole** | `sim/sim_world.gd:94-122` | dokud se nedoplní, **determinismus a save o NPC netvrdí nic** (brána měří prázdno) — §9 past P4 |
| `save()` zapisuje `mobiles: []`, `items: []`, `spawn_state: []` (připravené klíče, prázdné) | `sim/sim_world.gd:126-143` | integrace je **jen naplnit**; tvar save se nemění (docs/04 §4.7) |
| `app/main.gd` registruje jen `movement, skill_gain, harvest, craft, time` | `app/main.gd:264-287` | integrace: registrace nových systémů (§11 E5) |
| **Brána G12 (`bench_sim.gd`, tick ≤ 2 ms při 200 mobilech/3000 předmětech) je deklarovaná v `docs/08`, ale nástroj NEEXISTUJE** | `tools/gates/run-all.py:41-52` (G1,G5,G2,G4,G6,G7,G8,G9,G11,G10 + G3 + poznámka G13); `tools/gates/bench_sim.gd` na disku není | nasazení NPC je přesně to, co G12 mělo hlídat → doplnit (§7.3) |
| `sim/systems/{regen,hunger,decay}.gd` neexistují, ale jsou v `SYSTEM_ORDER` | `sim/sim_world.gd:36`; `app/main.gd` je neregistruje | bez nich se HP/stamina nedoplní — §3 rozhodnutí D3 |

### 2.4 Kolize se session 19 (write-scope) — **plán se smí provádět až po ní**

Postup: `git status --porcelain -uall` (2026-10-08, 15:0x a znovu v 15:4x). **19 modifikovaných
souborů** + necommitnuté `ZADANI-19-VADY-ZE-SNIMKU.md`, `ahead 8` commitů před
`origin/main`:

```
app/config.gd  app/input_map.gd  app/main.gd  app/player_controller.gd  app/world_view.gd
data/balance.json  render/chunk_renderer.gd  sim/commands.gd  sim/systems/movement.gd  sim/world/walk.gd
tests/cases/{balance,chunk_renderer,config,input,movement,player_controller,walk,world_view}.gd  tests/lib.gd
```

**⚠ Naměřeno v průběhu psaní tohohle plánu (P20):** session 19 přibyla mezi dvěma
měřeními **`sim/commands.gd`** (řádky `attack` se posunuly z **29 → 37** a
z **97 → 109**) a **`tests/cases/world_view.gd`**; `app/world_view.gd` se posunul
tak, že dvě moje řádkové citace přestaly platit. **Kdo plán provádí, musí čísla
řádků přeměřit** — u rozpracovaných souborů se cituje **jméno funkce**, ne řádek.

**Tři z těch souborů plán potřebuje** (a nesmí si je vzít, dokud je session 19
nemá commitnuté):

| Soubor | Proč ho plán potřebuje | Kdo ho vlastní dnes |
|---|---|---|
| `app/world_view.gd` | kreslení mobilů ze registru + jména/HP pruhy | session 19, trať **B** (terén, zoom, břeh) |
| `app/input_map.gd`, `app/player_controller.gd` | klik na mobila → `attack` | session 19, trať **A** (pohyb a míření) |
| `sim/world/walk.gd`, `sim/systems/movement.gd` | `can_step(..., is_player=false)` pro NPC (krokování moba) | session 19, trať **A** |

**Pravidlo, které z toho plyne:** plán začíná **etapou E0/E1** (§11), která se
těchto souborů **netýká** (data + nové soubory v `sim/systems/`, `sim/entity/`,
`data/`). Integrační etapa E5 se smí rozjet, až `git status` u těchto souborů
ukáže **čisto** (nebo se vlastnictví výslovně předá).

---

## 3. Rozhodnutí, která plán potřebuje (a kdo je dělá)

> Formát: **co se rozhoduje → doporučení → cena → cesta zpět.**
> Co není rozhodnuté, se v plánu **nesmí domyslet** (pravidlo z `docs/11` §11.6).

| # | Rozhodnutí | Doporučení | Cena / cesta zpět |
|---|---|---|---|
| **D1** | **`data.spawns` a `world.spawn` jsou dnes v milníku M7** — bez nich ale M5 („zabije kostlivce") nejde splnit: monstrum by se ve světě nikdy neobjevilo | ✅ **PROVEDENO 2026-10-08** (uživatel: „Souhlasím, vlož plán"): obě granule mají `milestone="M5"`, `world.spawn` dostal `state()`/`restore()`; `docs/07` §7.2 a §7.3 doplněny | Malá: 2 řádky v generátoru + tabulka v `docs/07`. Zpět = vrátit `milestone="M7"` |
| **D2** | **Rozsah obsahu pro první hratelné NPC**: `docs/06` §6.5 chce 88 monster (použít ~45) a §6.7 12 spawn tabulek + 3 dungeony — **naměřeno je ale 84 řádků/81 jmen a 10 tabulek A–J** (O11) | **První vlna: 3 monstra (kostlivec, krysa, zombie) + 1 spawn tabulka (hřbitov u Britainu)**; zbytek je M7. Grain `data.monsters` ale **vygeneruje všechny naměřené tabulky** (data jsou zdarma, práce je v AI a spawnu) | Malá — rozsah se mění jen v `data/spawns.json` a v akceptačním kritériu C6 |
| **D3** | **`sim.regen` a `sim.hunger`** (M3, chybí): bez regenerace je souboj „kdo dřív umře hlady", hráčovo HP se nikdy nevrátí | **Zařadit je do vlny V0** (jsou malé, ≤ 60 řádků) a `sim.regen` registrovat v integraci | Střední: jsou to nové systémy, ale deklarované v roadmapě i `SYSTEM_ORDER` už s nimi počítá |
| **D4** | **Magické předměty v lootu** (`data.item_properties`, 159 vlastností) | **Data vygenerovat, ale loot v první vlně bez magických vlastností** (`roll_magic_item` vrátí `{}` a hlásí to); magie předmětů patří k M5+ a je to samostatná vrstva | Malá: `loot` má `magic_chance = 0` z `data/balance.json` a je to vidět v reportu |
| **D5** | **Zvuk zásahu** (`docs/05` §5.5.2 ho vyžaduje) | **Nedělat**: `assets.sounds`/`audio.playback` jsou vlastní trať (rozhodnutí uživatele 2026-10-07). Systém **posílá `sound {id,x,y,z}`** událost, klient ji zatím zahodí (a je to vidět v logu) | Malá |
| **D6** | **Ztráta statů/skillu při smrti** — `docs/11` §11.6 ji vede jako `UNVERIFIED` | **Nedělat** (default vypnuto v `data/balance.json`), jen klíč `stat_loss_on_death: false` | Malá |
| **D7** | **Kdo smí editovat `docs/04` (smlouvy) a `tools/roadmap-gen.py`** — agent `docs/` needituje | ✅ **PROVEDENO 2026-10-08** se svolením uživatele: smlouvy vloženy do `docs/04` (§4.2 `sim.combat`/`sim.ai`/`sim.loot`/`sim.death`/`sim.poison`/`world.spawn`/`render.names`, nový `app.pick`, §4.5 `Mobile.ai`/`combat`, §4.6.4 číslo, nový tok §4.6.7) | Malá |
| **D8** | **Kolize se session 19** (§2.4) | **E0–E4 ano, E5 (integrace) až po commitu session 19** | — |

**Co z toho plyne pro uživatele:** potřebuju **D1 + D7** (souhlas se změnou
roadmapy a se zápisem smluv do `docs/04`), zbytek je doporučení, které umím
provést bez vás, pokud neřeknete jinak.

---

## 4. Smlouvy: co se přidává a v jakém tvaru

> **Proč zvlášť:** naměřeno na jiném projektu (`uo-shadows`) — tři PR prošla
> zeleným CI a **nemohla fungovat**, protože granule dostaly jméno API **bez
> tvaru dat** a brány měřily přítomnost metod. Smlouva bez tvaru dat je pozvánka
> k driftu.

### 4.1 Datové soubory (`data/*.json`)

Tvar je závazný; **každý záznam má `source` a `era`** (kritérium C10 z `docs/06` §6.8).

```jsonc
// data/weapons.json  (docs/06 §6.4) — naměřeno 134 záznamů ve zdroji
{ "id": 1, "name": "...", "tile": 0x0F5E, "skill_used": "Swords", "hands": 1,
  "min_damage": 3, "max_damage": 5, "speed": 30, "strength_req": 10, "weight": 6,
  "durability": 45, "layer": null, "layer_source": "pending-tiledata",
  "special_move": null, "material": "iron", "era": "aos",
  "source": "research/_src/weapons3.json" }

// data/armor.json    — naměřeno 165 záznamů ve zdroji; slot, AR/resisty, str_req,
//                      weight, durability, material, layer/layer_source jako u zbraní
// data/item_properties.json — naměřeno 159 vlastností (id, enum, w, scale, start, max, per_item)
// data/monsters.json  (docs/06 §6.5) — NAMĚŘENO 84 řádků / 81 unikátních jmen
//                      v research/06 §3 (roadmapa tvrdí „88" — viz O11)
{ "id": 1, "name": "a skeleton", "body": [50, 56], "hue": 0,
  "ai": "melee", "fight_mode": "closest", "perception_range": 10, "fight_range": 1,
  "passive_speed": 0.4, "active_speed": 0.2,
  "str": [56, 80], "dex": [56, 75], "int": [16, 40], "hits": [34, 48],
  "damage": [3, 7], "damage_type": "physical", "virtual_armor": 16,
  "resist": { "physical": [15, 20], "fire": [5, 10], "cold": [25, 40],
              "poison": [25, 35], "energy": [5, 15] },
  "skills": { "magic_resist": [451, 600], "tactics": [451, 600], "wrestling": [451, 550] },
  "fame": 450, "karma": -450, "loot_pack": "poor",
  "flags": ["undead", "bleed_immune", "poison_immune_lesser"],
  "corpse_name": "a skeletal corpse", "sound_id": 0x48D,
  "era": "aos", "source": "research/06 §3" }   // čísla: _src/servuo/Scripts/Mobiles/Normal/Skeleton.cs:11-40,104

// data/spawns.json   — TVAR je návrh; hodnoty v hranatých závorkách se MUSÍ změřit
{ "table_id": "graveyard_britain", "region": "britain_graveyard",
  "area": { "x": 0, "y": 0, "width": 0, "height": 0 },   // NEMĚŘENO (O7) — souřadnice až z mapy + data/regions.json
  "entries": [ { "monster": "skeleton", "max": 6, "weight": 3 },
               { "monster": "zombie",   "max": 4, "weight": 2 },
               { "monster": "rat",      "max": 8, "weight": 5 } ],   // počty: rozhodnutí D2, ne měření
  "min_delay_min": 5, "max_delay_min": 10, "refill_fraction": 0.333,  // docs/05 §5.12 (5–10 min, doplnění 1/3)
  "home_range": 10,   // NÁVRH: „kam se vrací" — přesná hodnota patří z reference (O6)
  "z": null, "era": "aos", "source": "research/06 §4" }
```

**Zakázané zkratky (past P19 z `docs/10`):** `layer` se u zbraní/zbrojí **nehádá** —
dokud není z `tiledata`, je `null` + `layer_source: "pending-tiledata"`.
**Klasická jména předmětů se nehardcodují** (tato instalace je nemá — `docs/03` §3.3.1b).

### 4.2 Simulační moduly (nové soubory, tvary vstupů a výstupů)

| Granule | Soubor | Poskytuje (přesně) | Vrací / mění |
|---|---|---|---|
| `entity.equipment` | `sim/entity/equipment.gd` | `equip(m, item)->{ok,reason}`, `unequip(m, layer)->int`, `at_layer(m, layer)->int`, `total_weight(m)->int`, `bonus(m, key)->int` | vrstva z `data/items.json`/`tiledata`; **jediné místo**, kde se čte `m.equip` |
| `entity.notoriety` | `sim/entity/notoriety.gd` | `level(m)->int` (1 innocent … 6 murderer, 7 invulnerable), `is_criminal(m)`, `flag_criminal(m, ms)`, `murder_counts(m)`, `award_fame_karma(m, fame, karma)` | zapisuje `m.notoriety`, `m.fame`, `m.karma` |
| `sim.combat` | `sim/systems/combat.gd` | `set_war(m, on)->void`, `attack(m, target)->void`, `swing_delay_ms(m)->int`, `resolve_swing(m, t)->Dictionary`, `stop_combat(m)->void` | `resolve_swing` → `{ok, hit, damage, absorbed, hp_left, killed, reason}`; stav drží **na mobilu** (`m.combat`), viz §4.5; **`swing_delay_ms` při stam 100 / speed 30 = 3000 ms** (§4.6) |
| `sim.ai` | `sim/systems/ai.gd` | `tick(m)->void`, `set_state(m, state)->void`; navíc `think(m)` (rozhodnutí), `state_of(m)->String` | stavy `idle → wander → aggro → attack → flee → dead` (+ `vendor`, `guard`) **namapované na referenční** `Wander/Combat/Flee/Guard/Backoff/Interact` (§4.6); `dead` = mobil **odstraněn** (jako reference), ne stav v `ActionType` |
| `sim.loot` | `sim/systems/loot.gd` | `fill_corpse(mob, corpse)->void`, `roll_magic_item(level)->Dictionary` | plní kontejner těla; vrací seznam vložených serialů (pro test); `loot_pack` bere **z monstra** (`data/monsters.json`), **ne z fame** (§4.6) |
| `sim.death` | `sim/systems/death.gd` | `die(m)->{ok, corpse, items}`, `resurrect(m, hp)->void`, `is_ghost(m)->bool` | vytvoří tělo (předmět v `container`), přepne mobil na duch body; tělo **7 min**, právo na loot **2 min**, `resurrect` → `hp 10`, `stam = max`, `mana = 0` (§4.6) |
| `sim.poison` | `sim/systems/poison.gd` | `apply(m, level)->void`, `cure(m, level)->bool`, `tick()->void` | 5 úrovní podle **AoS tabulky** (§4.6: intervaly 2,25 / 3,25 / 4,25 / 5,25 / 5,25 s), `tick()` bez argumentu (jako dnes v `SYSTEM_ORDER`) |
| `sim.regen` | `sim/systems/regen.gd` | `tick()->void` | hp/stam/mana podle statů (a hladu) |
| `sim.hunger` | `sim/systems/hunger.gd` | `eat(m, item)->bool`, `level(m)->int`, `tick()->void` | hlad −1 za 5 minut (`docs/05` §5.14) |
| `sim.decay` | `sim/systems/decay.gd` | `tick()->void`, `register(serial, decay_ms, kind)` | tělo 7 min (`docs/05` §5.13), předměty podle `docs/05` §5.4 |
| `world.spawn` | `sim/world/spawn.gd` | `register(point)->void`, `tick()->void`, `alive_at(point_id)->int`, **navíc `state()->Dictionary` / `restore(d)->void`** | **jeden world tick**, ne tisíc spawnerů (`docs/05` §5.12); `state()` je vstup pro `spawn_state` v save |
| `app.pick` **(nová)** | `app/pick.gd` | `at(screen:Vector2, view, registry)->{kind:"mobile"|"item"|"land", serial:int, tile:Vector2i, z:int}` | čistá funkce (měřitelná bez okna): hit test v pořadí kreslení **odzadu** |

**Pravidla, která platí pro všechny `sim` moduly (brána G2 je vynucuje):**
žádné `Input.`, `Time.`, `OS.`, `randf()`, `randi()`; čas z `sim.clock()`,
náhoda z `sim.rng()` (jeden generátor pro celý svět), serialy ze `sim.next_serial()`.

**Kritické pravidlo pro časovače (naměřeno, `sim/systems/movement.gd` — funkce `request_step` a `apply_step`; soubor je rozpracovaný, proto jménem):**
stav časovače patří **do systému** jako `due_ms` a porovnává se v `tick(ms)`,
**ne** do `core.clock.after(delay, Callable)`. Callable není serializovatelný,
takže by se stav nedostal do `state_hash()` ani do `save()` — determinismus
a round-trip by o něm **tiše netvrdily nic**.

### 4.3 Klientské moduly

| Kde | Co se mění | Pravidlo |
|---|---|---|
| `app/loop.gd` (integrace) | po `input_map.poll()` navíc `pick.at(mouse, view, registry)` → `Command{t:"attack", serial}` při dvojkliku na mobil; `{t:"use"}` při dvojkliku na předmět | klient **jen posílá příkazy**; rozhoduje `sim` |
| `app/world_view.gd` (integrace, session 19 trať B) | `_list()` obohatí o mobily z registru (`kind:"mobile"`, `x,y,z,serial,body,hue`); kreslení každého mobila `render.anim.play(serial, action, dir)` + `hue`; pořadí přes `render.sort.sort_key` | **jediná funkce řazení** — žádné vlastní `x + y` (pravidlo z `app.player_view`) |
| `render/name_plates.gd` | jméno + HP pruh nad cílem (jen na dosah / po kliku) | UI je tenký klient; bere data z událostí |
| `ui/status_bar.gd` | cíl (jméno + HP) **jen pokud uživatel chce** — jinak zůstává nad hlavou cíle | — |
| `assets` krok | `tools/uoextract/anim.py --actions 0:walk,1:run,4:idle,<útok>,<smrt>` + re-export `assets/uo/anim` pro těla monster | **číslo akce útoku/smrti se musí ZMĚŘIT** (§12 O1) — dnes export zná jen 0/1/4 |

### 4.4 Události (kontrakt `docs/04` §4.4 — nic nového se nevymýšlí)

Souboj, smrt a spawn **musí** vydávat tyto události (jména i klíče jsou dané):

| Událost | Kdo ji vydá | Co v ní musí být |
|---|---|---|
| `mobile_added` | `world.spawn` | `{serial, body, hue, name, x, y, z, notoriety}` |
| `mobile_removed` | `sim.death` (a odchod z dosahu) | `{serial}` |
| `mobile_moved` | `sim.movement` (pro NPC **už funguje**) | `{serial, x, y, z, dir, run}` |
| `mobile_anim` | `sim.combat` (útok), `sim.death` (smrt) | `{serial, action, frame_ms}` |
| `stats_changed` | `sim.combat`, `sim.death`, `sim.regen` | `{serial, hp, max_hp, stam, mana, weight, gold}` |
| `message` | všude | `{text, kind:"combat"|"system", hue, name?}` |
| `combat_state` | `sim.combat` | `{serial, target, war:bool}` |
| `death` / `resurrected` | `sim.death` | `{serial}` |
| `item_added` / `item_removed` | `sim.loot`, `sim.death` | `{serial, tile, hue, amount, parent, layer, x, y, z}` |
| `sound` | `sim.combat` | `{id, x, y, z}` — **klient zatím ignoruje** (D5) |

### 4.5 Změny STÁVAJÍCÍCH smluv (návrh do `docs/04`, potřebuje svolení D7)

| Co | Dnes | Návrh | Proč |
|---|---|---|---|
| `Mobile` (§4.5) | `ai:{state, target, home, timer_ms}` | `ai:{state, target, home, timer_ms, next_think_ms, path, path_i}` a **nově** `combat:{war:bool, target:int, next_swing_ms:int, last_hit_ms:int, bandage_ms:int}` | stav souboje i AI musí být **na mobilu**, aby ho `save`/`state_hash` viděly (systémový slovník by se neukládal) |
| `world.spawn` (§4.2) | `register`, `tick`, `alive_at` | navíc `state()->Dictionary`, `restore(d)->void` | save má klíč `spawn_state` **už dnes** (`sim/sim_world.gd:140`) a nemá ho kdo naplnit |
| `sim.entity_registry` (§4.2) | `register`, `get_mobile`, `all`, `remove`, `size` | beze změny | registr už dnes stačí; **NPC nepotřebují druhý seznam** (past: dva zdroje pravdy) |
| `sim.commands` (§4.3) | `attack {serial}`, `war {on}` | beze změny | routing **už je hotový** |
| `docs/07` §7.2 | M5 = souboj a smrt; spawn v M7 | doplnit do M5 spawn (rozhodnutí D1) | bez toho M5 nejde splnit |

### 4.6 Naměřená čísla z reference (co se má v granulích objevit)

> **Odkud:** `_src/servuo` (GPL — berou se **jen fakta a čísla**, nikdy kód)
> a `_src/classicuo` (BSD-2). Každé číslo níž má **řádek**, a ty řádky
> prošly strojovou kontrolou (`_analyza/plan-npc-kontrola.py`: 74 citací
> `soubor:řádek`, u 45 z nich i obsah řádku, 8 citací jménem funkce, 7 odkazů
> na oddíly `docs/`).
> **Zkrácené cesty:** `Scripts/…` = `_src/servuo/Scripts/…`,
> `Server/…` = `_src/servuo/Server/…`; plná cesta je tam, kde je v řádku poprvé.

**AI (`sim.ai`) — pozor, zadání a reference se v pojmenování stavů rozcházejí:**

| Co | Naměřeno | Citace |
|---|---|---|
| Stavy v referenci | `Wander, Combat, Guard, Flee, Backoff, Interact` — **žádný `idle`/`aggro`/`dead`** | `_src/servuo/Scripts/Mobiles/AI/BaseAI.cs:45-53` |
| Výchozí stav | `Wander` | tamtéž `:101` |
| **Interval myšlení** | `AITimer` = `CurrentSpeed` v **SEKUNDÁCH**; aktivní **0,2 s**, pasivní **0,4 s** — **není to „X ms"** | `Scripts/Mobiles/AI/BaseAI.cs:3046-3053`; `Scripts/Mobiles/Normal/BaseCreature.cs:2357` |
| Vnímání (aggro dosah) | default **16** dlaždic (`OldRangePerception = 10` se přepisuje na 16); kostlivec předává **10** | `Scripts/Mobiles/Normal/BaseCreature.cs:2353`; `Scripts/Mobiles/Normal/Skeleton.cs:11` |
| Opakovaná akvizice cíle | `ReacquireDelay = 10 s` | `Scripts/Mobiles/Normal/BaseCreature.cs:6536` |
| **Flee** | práh **20 % HP**; šance `Random(100) <= max(10, 10 + c.Hits − m.Hits)` → **min 10 %**; návrat do boje nad **50 % HP** | `Scripts/Mobiles/AI/MeleeAI.cs:98`, `:101`, `:133-145` |
| Domov | `RangeHome = 10`; mimo domov **10 % šance na krok domů**, po 5 selháních teleport | `Scripts/Mobiles/Normal/BaseCreature.cs:262`, `:7446-7463` |
| Co rozhoduje o aggru | `IsHostile`/`IsEnemy` + `CanSee`/`InLOS` — **notoriety do aggra přímo nevstupuje** | `Scripts/Mobiles/AI/BaseAI.cs:2888`, `:2935-2947` |
| „mrtvý" stav | v referenci **není**: nehráč se po smrti rovnou **maže** | `_src/servuo/Server/Mobile.cs:4229-4232` |

**Spawn (`world.spawn`):**

| Co | Naměřeno | Citace |
|---|---|---|
| Default spawneru | `this(1, 5, 10, 0, 4, …)` → **max 1**, prodleva **5–10 min**, rozsah **4** | `Scripts/Services/Spawner/Spawner.cs:41` |
| Domovský rozsah spawneru | `m_HomeRange = 5` (jiné číslo než `RangeHome` monstra = 10) | tamtéž `:952` |
| Region spawn | default **2–5 min**; doplnění deficitu `max((max − spawned) / 3, 1)` → **1/3, nejméně 1** | `Scripts/Regions/Spawning/SpawnEntry.cs:12-13`, `:536` |
| Kolik spawnerů je v datech | **6 465** ve 13 XML (Felucca **2 256**) — měřeno rešerší této session; u Feluccy **souhlasí** s `research/06:4206` | měřeno nad `_src/servuo/Spawns/*.xml` |

**Loot (`sim.loot`) — a jedna korekce zadání:**

| Co | Naměřeno | Citace |
|---|---|---|
| Význam `chance` | je to **procento ×100** (`20.00` = 0,20 %), test `entry.Chance > Random(10000)` | `Scripts/Misc/LootPack.cs:831`, `:99` |
| `OldPoor` (kostlivec) | zlato **`1d25`** (1–25) + nástroje 0,02 % | `Scripts/Misc/LootPack.cs:421-422`; kostlivec `AddLoot(LootPack.Poor)` — `Scripts/Mobiles/Normal/Skeleton.cs:104` |
| `OldMeager` | zlato `5d10+25`, magický předmět **1,00 %** | `Scripts/Misc/LootPack.cs:424-431` |
| `maxProps` u všech `Old*` | **1** → pre-AoS magický předmět má **jednu** vlastnost (potvrzuje D4) | `Scripts/Misc/LootPack.cs:429-491` |
| **Loot se NEŘÍDÍ fame** | fame→tier platí **jen pro paragony**; běžné monstrum si `LootPack` deklaruje samo (430 souborů má vlastní `GenerateLoot()`) | `Scripts/Mobiles/Normal/BaseCreature.cs:5386-5408`; `Scripts/Mobiles/Normal/Skeleton.cs:104` |

**Souboj (`sim.combat`) — s konkrétní akceptační hodnotou:**

| Co | Naměřeno | Citace |
|---|---|---|
| Swing delay (AoS) | `v = (Stam + 100) × Speed`; `v += Scale(v, SSI)`; `delay = floor(40000 / v) × 0,5 s`; **dolní mez 1,25 s** | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1598`, `:1602`, `:1609`, `:1613-1615` |
| **Akceptační číslo** | stam **100**, speed **30** → `v = 6000` → `floor(40000/6000) = 6` → **6 × 0,5 s = 3000 ms** | týž vzorec, dopočteno |
| Hit chance (AoS) | `ourValue/(theirValue×2)`, HCI/DCI **cap 45**, dolní mez šance **0,02**; obranu určuje **zbraň obránce** | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1451`, `:1530-1533`, `:1428-1431` |
| Damage bonusy | STR `0,300`/+5@100, Anatomy `0,500`/+5, Tactics `0,625`/+6,25, Lumberjack `0,200`/+10 (jen Axe); **DI cap 100** | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:3788-3796`, `:3804-3809` |
| Obrana resisty | `Σ(damage × podíl × (100 − resist)) / 10000`, **minimum 1** | `Scripts/Misc/AOS.cs:170-177`, `:205-206` |
| **Strop 35** | je **jen direct damage** (`ignoreArmor`) — **žádný obecný strop neexistuje**; `docs/05` §5.5 to říká správně („strop přímého damage 35") | `Scripts/Misc/AOS.cs:213` |
| Parry | štít/NPC: `(Parry − Bushido) / 400` | `Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1771` |

**Smrt a vzkříšení (`sim.death`):**

| Co | Naměřeno | Citace |
|---|---|---|
| Rozpad těla | **7 minut** (i kostra 7 min) | `Scripts/Items/Corpses/Corpse.cs:421-422` |
| Právo na loot | **2 minuty** | `Scripts/Items/Corpses/Corpse.cs:118` |
| Vzkříšení | `Hits = 10`, `Stam = StamMax`, `Mana = 0`, `Poison = null`, `Warmode = false` | `Server/Mobile.cs:3646-3678` (`Hits = 10` na `:3673`) |
| Duch | `Body = Race.GhostBody(this)`; monstra ducha nevidí (vidí ho jen když je ve `warmode`); **nemůže útočit** | `Server/Mobile.cs:4241`, `:9223-9233`, `:11851-11871` |

**Jed (`sim.poison`) — AoS tabulka 5 úrovní** (`Scripts/Misc/Poison.cs:23-27`):
`Lesser` 4–16/7,5 %/2,25 s, `Regular` 8–18/10 %/3,25 s, `Greater` 12–20/15 %/4,25 s,
`Deadly` 16–30/30 %/5,25 s, `Lethal` 20–50/35 %/5,25 s (počet tiků 10/10/10/15/20).
Damage na tik `1 + int(Hits × Scalar)` s clampem `[min, max]` (`:222-227`).

**Notoriety (`entity.notoriety`):** `Innocent=1 … Murderer=6, Invulnerable=7`
(`Server/Notoriety.cs:7-13`); murderer je `Kills >= 5` (`Server/Mobile.cs:11849`);
criminal 2 minuty (`:2102`); decay `−1 za 8 h` (short-term) a `−1 za 40 h` (kills)
(`Scripts/Mobiles/PlayerMobile.cs:5151-5170`).

**Co zůstává NEOVĚŘENÉ a do plánu se NEDÁVÁ** (jinak by se z „nevím" stalo
„pravidlo"): pre-AoS parry, wrestling base damage, cena staminy za švih
(v ServUO **není**), ztráta statů/skillu při smrti, noční spawny (v datech
samé nuly), stat bloky mořských monster — `research/_sections/99-open-questions.md`
a `docs/11` §11.6.


---

## 5. Granule — co se staví

### 5.1 Existující granule, které plán povolává (mění se jen `milestone`/`depends_on`)

| id | `owns` | Milník dnes | Co plán mění | Proč |
|---|---|---|---|---|
| `data.spawns` | `data/spawns.json` | M7 | **→ M5** (D1) | bez spawnu není co zabít |
| `world.spawn` | `sim/world/spawn.gd` | M7 | **→ M5** (D1); do `provides` přidat `state()`/`restore()` | save má klíč `spawn_state` a nemá ho kdo naplnit |
| `sim.ai` | `sim/systems/ai.gd` | M5 | do `depends_on` přidat `sim.pathfind` | pronásledování hráče je A*, ne slepé kroky; `sim.pathfind` je hotová (M2) a její prompt už `sim.ai` uvádí jako konzumenta |
| `sim.combat` | `sim/systems/combat.gd` | M5 | do `provides` přidat `state_of(m)`; `acceptance` rozšířit o `wiring` | stav souboje musí být čitelný pro klienta (war/peace, cíl) i pro test |
| `sim.death` | `sim/systems/death.gd` | M5 | do `depends_on` přidat `sim.decay` | tělo se má rozpadnout za 7 minut — jinak zůstane svět plný těl |
| `data.monsters` | `data/monsters.json` | M5 | beze změny (plní `docs/06` §6.5) | — |

### 5.2 Nové granule (návrh — v roadmapě dnes nejsou)

| id | `owns` | Milník | `depends_on` | `provides` | `acceptance` |
|---|---|---|---|---|---|
| `app.pick` | `app/pick.gd` | M2 | `app.input`, `sim.entity_registry`, `core.iso` | `at(screen, view, registry) -> {kind, serial, tile, z}` | `tests`, `wiring` |
| ~~`assets.anim_combat`~~ **ZRUŠENO 2026-10-08 při vkládání** | — | — | — | `owns` by kolidovalo s `assets.anim` (obojí `tools/uoextract/anim.py`) → generátor roadmapy by hlásil kolizi. Řešení: rozšířen **prompt `assets.anim`** o export těl monster a akcí útoku/smrti (měřeno: dnes `--actions 0:walk,1:run,4:idle`, těla jen 400/401) | — |

**Proč `app.pick` zvlášť a ne do `app.input`:** `app.input` je hotová granule
(M0) a **její soubor drží session 19** (§2.4). Hit test je navíc čistá funkce
(vstup: bod na obrazovce + seznam objektů + registr), takže se dá měřit
**bez okna** — a to je přesně to, co `tests/cases/` umí.

**Kód k vložení do `tools/roadmap-gen.py`** (za `g("app.player_controller", …)`,
řádek ~531; `owns` se nesmí krýt s žádnou jinou granulí — kontrola je v generátoru):

```python
g("app.pick", "Vyber objektu pod kurzorem", ["app/pick.gd"],
  deps=["app.input", "sim.entity_registry", "core.iso"],
  provides=["at(screen, view, registry) -> {kind, serial, tile, z}"],
  acceptance=["tests", "wiring"], milestone="M2",
  prompt="Hit test v poradi kresleni ODZADU (mobil pred statikem, kdyz ma vyssi klic). "
         "Vraci {kind:'mobile'|'item'|'land', serial, tile, z}; kdyz nic, kind='land' a serial=0 "
         "(NIKDY tise prazdny slovnik). Pouziva `render.sort.sort_key` - vlastni porovnani x+y je vada. "
         "Konzument: `app/loop.gd` meni dvojklik na Command{t:'attack'|'use'}. "
         "Vzor (BSD-2, jen fakt): ClassicUO vybira objekt BEHEM kresliciho pruchodu a nechava si ten "
         "s NEJVYSSI hloubkou - `_src/classicuo/src/ClassicUO.Client/Game/Scenes/GameSceneDrawingSorting.cs:601-610`.")
```

**Nové granule (návrh) — přehled:** jen `app.pick` (`app/pick.gd`) — **vloženo
do `tools/roadmap-gen.py` 2026-10-08**. Export akcí útoku/smrti **není nová
granule**: `tools/uoextract/anim.py` už vlastní `assets.anim`, takže by vznikla
kolize `owns`; místo toho je rozšířený **prompt `assets.anim`** (viz P11 a O1).

### 5.3 Odkud data vzniknou (naměřeno 2026-10-08)

**Generátor `tools/gates/gen-content.py` dnes umí 3 soubory** (`GENERATORY`,
ř. 512–513: `items.json`, `recipes.json`, `skills.json`); jeho vlastní seznam
`POZADAVKY` (ř. 45–62) má **15 cílů, z toho 12 s `False` = „generator jeste
neni napsany"**. Živý běh `python tools/gates/gen-content.py --check` hlásí
**3× OK, 12× NEMĚŘENO** — a mezi těmi 12 jsou **všechny** datové soubory, které
tenhle plán potřebuje.

| Datový soubor | Strojový zdroj (měřeno) | Co je potřeba udělat |
|---|---|---|
| `data/weapons.json` | **`research/_src/weapons3.json`** — 134 záznamů | napsat `gen_weapons` (prompt dnes odkazuje na „research/03", což je dokument, ne soubor) |
| `data/armor.json` | **`research/_src/armor_raw.json`** — 165 záznamů (roadmap píše „~90") | napsat `gen_armor` |
| `data/item_properties.json` | **`research/_src/itemprops_table.tsv`** — 159 řádků bez hlavičky (`research/03` §5.3 má 158: chybí `ExtendedWeaponAttribute.Bane`) | napsat `gen_item_properties` |
| `data/monsters.json` | **žádný strojový soubor** — jen tabulky v `research/06 §3` (naměřeno 84 řádků / 81 unikátních jmen; roadmap píše 88) | napsat `gen_monsters` (parser tabulek); ⚠ `loot_pack` se bere **per monstrum**, ne z fame (P18) — zdroj `GenerateLoot()` v `_src/servuo/Scripts/Mobiles/**` (430 souborů), pro první vlnu stačí 3 monstra ručně doložená |
| `data/spawns.json` | **žádný** — `research/06 §4` (model spawnu) + §4.8 (10 tabulek A–J; roadmap píše „12 + 3 dungeony") | napsat `gen_spawns` |
| `data/regions.json` | **žádný** — `research/06 §1` (19 měst ✓, 9 moongate ✓, dungeonů 15 vs „3") | napsat `gen_regions` |

**Důsledek pro plán:** E1 **není „spustit generátor"**, ale **„napsat pět
generátorů"** — a to je práce navíc, kterou plán přiznává (a která se týká
`data.gen_content`, protože ten soubor vlastní). Bez ní by `data.monsters`
a `data.spawns` musely být opsané ručně z markdownu, což je přesně ten druh
práce, u které projekt naměřil 58 selhání z 58 u nejkratších zadání.


### 5.4 Změna milníků a závislostí (D1) — kód k vložení

Rozdíl proti dnešnímu stavu `tools/roadmap-gen.py` (řádky 468–491 a 436–447):

```python
# v g("data.spawns", ...)   : milestone="M7" -> milestone="M5"
# v g("world.spawn", ...)   : milestone="M7" -> milestone="M5"
#                            a do provides pridat "state() -> Dictionary", "restore(d) -> void"
# v g("sim.ai", ...)        : deps=[... , "sim.pathfind"]
# v g("sim.death", ...)     : deps=["entity.container", "entity.notoriety", "sim.decay"]
```

Po vložení: `python tools/roadmap-gen.py` (přegeneruje `.forge/roadmap.json`)
a `python tools/roadmap-gen.py --check` (musí vrátit `OK: DAG je konzistentní`).
Generátor sám hlídá kolize `owns`, cykly i to, že závislost není v pozdějším
milníku — **když se `data.spawns` přesune do M5, projde to jen tehdy, když
i `data.monsters` (M5) zůstane před ním.**

---

## 6. Vlny a DAG (co může běžet paralelně)

**Pravidlo vln:** dvě granule běží současně, právě když mají hotové `depends_on`
**a** disjunktní `owns`. Vlny níž jsou navržené tak, aby si **žádné dva běhy
nešly po souboru**.

| Vlna | Granule (paralelně) | Soubory (write-scope) | Hotovo, když |
|---|---|---|---|
| **V0** předpoklady | `sim.hunger`, `sim.decay`, `entity.notoriety`, `data.regions` | `sim/systems/{hunger,decay}.gd`, `sim/entity/notoriety.gd`, `data/regions.json` | testy volají API a měří hodnotu |
| **V1** data | `data.weapons`, `data.armor`, `data.item_properties`, `data.monsters` | `data/*.json` | schéma + počty (G5), `source`/`era` u každého záznamu |
| **V2** sim základy | `entity.equipment`, `sim.regen`, `world.regions` | `sim/entity/equipment.gd`, `sim/systems/regen.gd`, `sim/world/regions.gd` | `regen` doplní staminu (naměřeno: před ní se nedožene) |
| **V3** souboj | `sim.combat`, `sim.poison`, `sim.death`, `sim.loot` | `sim/systems/{combat,poison,death,loot}.gd` | 20 švihů ≥ 5 zásahů; po `die` je tělo s lootem |
| **V4** NPC | `sim.ai`, `data.spawns`, `render.names`, `app.pick` | `sim/systems/ai.gd`, `data/spawns.json`, `render/name_plates.gd`, `app/pick.gd` | NPC se do 10 s pohne; spawn obnoví monstrum do 10 min |
| **V5** integrace (SEKVENČNĚ, 1 soubor = 1 vlastník) | export animací (`assets.anim`) → `world.spawn` → `sim.world_loop` → `app.main` → `app.loop` → `app.player_view` | `tools/uoextract/anim.py`, `sim/world/spawn.gd`, `sim/sim_world.gd`, `app/main.gd`, `app/loop.gd`, `app/world_view.gd` | hra se spustí, NPC je na obrazovce, save/load drží mobily |
| **V6** ověření | mutace nových modulů, replay s NPC, snímek, G12 | `tools/gates/mutace-tests.py`, `tests/cases/*`, `tests/replays/*` | každá nová brána má mutaci, která spadne |

**DAG (co na čem stojí):**

```
data.gen_content ──► data.monsters ──► data.spawns ─────────┐
data.items ──► data.weapons ──┐                             │
data.items ──► data.armor ────┼──► sim.combat ──► sim.ai ────┼──► world.spawn
data.items ──► data.item_properties ──► sim.loot             │        │
entity.item/container ──► entity.equipment ──┘               │        │
entity.mobile ──► entity.notoriety ──► sim.death ────────────┘        │
entity.stats ──► sim.hunger ──► sim.regen                             │
entity.item ──► sim.decay ──► sim.death                               │
data.gen_content ──► data.regions ──► world.regions ──► sim.ai        │
sim.movement + sim.pathfind ──────────────────────► sim.ai            │
                                                                      ▼
                            sim.world_loop (mobiles/items/spawn_state) + app.main (registrace)
                                              │
                        app.loop (klik→attack) ┴── app.player_view (kreslení mobilů)
```

**Kritická cesta** (co určuje délku): `data.monsters` → `data.spawns` →
`sim.combat` → `sim.ai` → `world.spawn` → `sim.world_loop` → `app.player_view`.
**Nic z toho není v M6/M7**, takže se to dá stavět hned po session 19 (§2.4).

---

## 7. Brány: co musí být zelené a co to znamená

### 7.1 Co musí splnit každá NOVÁ kontrola (pravidla z `docs/08` §8.1 a §8.6)

1. **Zavolá kód a měří hodnotu** — ne `has_method`, ne „soubor existuje".
   Příklad správně: `resolve_swing` vrátí `hit == false` pro cíl za zdí;
   špatně: `_check(combat.has_method("resolve_swing"), …)`.
2. **Je NEPODMÍNĚNÁ.** Když soubor granule chybí, test **spadne**
   (`_pending`), nikdy se tiše nepřeskočí. Důvod je naměřený: `load()` na case
   soubor s parse errorem vrací nenulový skript, `new()` vyhodí chybu a sada
   soubor **tiše přeskočí** (`tests/run_tests.gd:27-45`).
3. **Umí selhat** — pro každý nový modul přibude **mutace** v
   `tools/gates/mutace-tests.py` (`MODULY`, od řádku 50). Po vložení mutace
   harness hlásí `PATRANA VETA SE NENASLA`, když se text v kódu nenašel →
   **mutace, která se tiše neprovede, tvrdí totéž co mutace, která projde.**
4. **Když nic nezměřila, řekne to** (`NEMĚŘENO`), a to není zelená.

### 7.2 Povinné mutace pro nové moduly (návrh obsahu)

| Modul | Co vrátit za vadu | Co musí spadnout |
|---|---|---|
| `sim.combat` | obrana ignoruje resisty | test „vyšší resist = menší damage" |
| `sim.combat` | `Tactics` se použije jako **útočný** skill | test „hit chance na Tactics nezávisí" (`docs/05` §5.5: Tactics je damage skill) |
| `sim.combat` | swing delay ztratí dolní mez 1,25 s | test „delay ≥ 1250 ms" |
| `sim.combat` | minimální damage 1 se vynechá | test „zásah vždy ubere ≥ 1 hp" |
| `sim.ai` | aggro ignoruje vzdálenost | test „mob 20 dlaždic daleko nezaútočí" |
| `sim.ai` | `wander` nikdy nezmění cíl | test „NPC se do 10 s pohne" |
| `sim.ai` | mob zůstane v neplatném stavu (timeout na `home` se neudělá) | test „po 60 s bez cíle je zpět na `home`" (`docs/05` §5.12) |
| `sim.ai` | interval myšlení se plete (sekundy vs ms: 0,2 s → 200 ms) | test „mob změní rozhodnutí nejdřív po 200 ms" (§4.6) |
| `sim.loot` | loot se vezme podle fame místo `loot_pack` monstra | test „kostlivec (`poor`) nedá `rich` loot" (P18) |
| `world.spawn` | `tick()` nedoplní deficit | test „po zabití se do 10 min obnoví" |
| `world.spawn` | ignoruje `max` v tabulce | test „nad `max` se nespawnuje" |
| `sim.death` | `die()` nezaloží tělo | test „tělo existuje a má obsah" |
| `sim.death` | `resurrect` nedá `hp = 10` | test |
| `sim.loot` | zlato se nevloží | test „monstrum se zlatem nechá zlato" |
| `sim.regen` | `tick()` nic nedoplní | test „stamina roste, když hráč stojí" |
| `entity.equipment` | vrstva se neuloží | test `equip` → `at_layer` |
| `app.pick` | bere první objekt v pořadí kreslení (ne poslední) | test „klik na mobila před zdí vrátí mobila" |

### 7.3 Integrační brány (existující nástroje + co je potřeba doplnit)

| Brána | Co dnes měří | Co musí umět po nasazení NPC | Kdo to smí udělat |
|---|---|---|---|
| **G3** `tests/run_tests.gd` | chování simulace | nové case soubory: `combat`, `ai`, `spawn`, `death`, `loot`, `regen`, `equipment`, `pick` | session (testy jsou spec) |
| **G4** `check-wiring.py` | volání `provides` z **produkčního** kódu | `app.pick`, `render.names`, `world.spawn` musí mít volajícího v `app/` — jinak G4 hlásí mrtvý kód (a to je správně) | session (integrace E5) |
| **G5** `check-content.py` | schémata `data/*.json`, počty C1–C10 | schéma pro `weapons/armor/item_properties/monsters/spawns`; **C6 „≥ 40 monster se spawnuje"** v první vlně **nesplněno** → musí to být vidět jako nesplněné, ne zamlčené | **`tools/gates/` = bootstrap, jen člověk** (docs/09 §9.2) |
| **G7** `check-save.py` | round-trip `save → load → state_hash` | musí obsahovat **mobily, předměty a `spawn_state`** — dnes se ukládají prázdné seznamy (`sim/sim_world.gd:138-140`) | session (E5) |
| **G8** `check-determinism.py` | 20 000 ticků, dva běhy | **NPC musí být součástí běhu** — jinak brána o determinismu NPC netvrdí nic | session (E5) |
| **G9** `check-replay.py` | `tests/replays/*.json` | **nový replay** s útokem na spawnuté monstrum; ⚠ změna hashe existujícího replaye = **regrese**, dokud se nevysvětlí | session |
| **G10** `check-render.py` | „postava není překrytá", počet dlaždic | nová kontrola: **NPC je vidět** (na známé dlaždici se spawnutým monstrum se pixely v jeho oblasti liší od pozadí) | **`tools/gates/` = bootstrap, jen člověk** |
| **G11** `smoke.py` | 300 framů bez `SCRIPT ERROR` | hra se rozjede **s registrovanými systémy** (spawn, ai, combat…) | session |
| **G12** `bench_sim.gd` | **NEEXISTUJE** (docs/08 §8.2 ho deklaruje; `run-all.py` ho nezná, soubor na disku není) | **založit**: 200 mobilů + 3 000 předmětů, tick ≤ 2 ms | **`tools/gates/` = bootstrap, jen člověk** |
| **G13** vision | poradní | na snímku je **kostlivec**, ne jen hráč | session (`read_image`) |

### 7.4 Lidská kontrola (nepovinné nahradit)

Na konci E5 se **podívám na snímek** (`read_image`, případně skill `vision`):
je na něm monstrum? Je jiné než hráč? Není pod terénem? Sedí mu jméno?
Tohle žádná brána neumí — naměřeno v projektu: hráč nebyl na obrazovce
a **všechny brány byly zelené**.

---

## 8. Non-goals (co do tohohle plánu NEPATŘÍ)

Seznam je **povinný**, ne dekorativní: agent bez zákazů si domyslí sousední
vrstvu (naměřeno: `world.gd` s vlastní konstantou mřížky vedle izometrie
`level.gd` → druhý zdroj pravdy → `_retired/`).

| # | Co se NEDĚLÁ | Proč |
|---|---|---|
| N1 | **Magie** (`sim.magic`, 64 kouzel, `data.spells`) | jiný milník (M6); plán jen nechá `sim.combat` volat `magic.interrupt(m)`, když systém existuje |
| N2 | **Vendorové a obchod** (`sim.vendor`, `ui.vendor_gump`, `data.vendors`) | M7; AI stav `vendor` se **implementuje jako nečinný stav** (NPC stojí), ne obchod |
| N3 | **Zvuk a hudba** (`assets.sounds`, `audio.playback`) | vlastní trať (rozhodnutí uživatele 2026-10-07); systémy jen posílají událost `sound` |
| N4 | **12 spawn tabulek + 3 dungeony + 19 měst s obsluhou** | M7 (D2) — v první vlně 1 tabulka (hřbitov) a 3 druhy monster |
| N5 | **Zvláštní útoky zbraní** (31 útoků, `docs/05` §5.5) | samostatná vrstva nad soubojem; `special_move` zůstává `null` |
| N6 | **Magické předměty v lootu** (`roll_magic_item`) | D4 — vrací `{}` a hlásí to; data `item_properties.json` se vygenerují, ale nečtou |
| N7 | **Krotitelství, mounty, zvířata jako společníci** (`taming_difficulty`, `entity.mount`) | mimo M5 |
| N8 | **Stat/skill loss při smrti, pojištění předmětů, murder counts** | `UNVERIFIED` (`docs/11` §11.6), default vypnuto (D6) |
| N9 | **Trammel/Felucca rozdíl, guard zóny, escorts, treasure maps** | v single-playeru nemá co dělat (`docs/05` §5.16) |
| N10 | **Přepis `sim/sim_world.gd` na nový návrh** | jen **aditivně** naplnit `mobiles`/`items`/`spawn_state`, které tam už jsou |
| N11 | **Vlastní kopie pravidel průchodnosti v `sim.ai`** | AI se **musí** ptát `world.walk.can_step` (jinak dva zdroje pravdy) |
| N12 | **Druhý seznam mobilů** (AI, spawn ani render si nesmí držet vlastní) | jediné místo je `sim.entity_registry` (`sim/entity/registry.gd:2-8`) |

---

## 9. Rizika a pasti (naměřené + očekávané)

> Každá past má **číslo, soubor a důsledek** — bez toho by to bylo heslo.

| # | Past | Doklad | Jak se jí plán brání |
|---|---|---|---|
| **P1** | **Podmíněný test je tiše zelený.** Case soubor s parse errorem `load()` vrátí nenulový skript, `new()` vyhodí chybu a sada ho **tiše přeskočí** — hlásí „0 selhání" a jen ubyde kontrol | `tests/run_tests.gd:27-45`; `sim/entity/registry.gd:13-20` (otevřená věc 21) | nové testy **nepodmíněné**; když soubor chybí, `_pending` → spadne |
| **P2** | **Obecná jména přebijí engine.** `get(serial)` je parse error (`Object.get(StringName)`), tichý důsledek = přeskočený case | `sim/entity/registry.gd:13-20` (naměřeno 2026-10-06) | žádný nový modul nesmí mít metodu `get`/`set`; pro registr platí `get_mobile` |
| **P3** | **Brána na přítomnost neměří chování** (`has_method`) | `docs/08` §8.6; tři PR prošla zeleným CI a nemohla fungovat | test **volá API a měří hodnotu** (`resolve_swing` → `hit`, `damage`) |
| **P4** | **Determinismus a save o NPC netvrdí nic**, dokud jsou `mobiles: []` a `state_hash()` hashuje prázdná pole — G8/G9/G7 jsou zelené nad prázdnem | `sim/sim_world.gd:99-122`, `:138-140` | integrační krok E5 je **povinný**; do té doby se o determinismu NPC **nesmí mluvit** |
| **P5** | **Timer v `clock.after(Callable)` není ve stavu** → vypadne ze `state_hash`/save | `core/clock.gd:25` vs `sim/systems/movement.gd` (funkce `request_step`, `_pending`) | švihy, myšlení AI i spawn prodlevy drž jako `due_ms` v systému/mobilu |
| **P6** | **Dva zdroje pravdy.** Vlastní seznam mobilů, vlastní pravidla průchodnosti, vlastní tabulka spawnu | vzor: `world.gd` s duplicitní mřížkou → `_retired/` (jiný projekt) | AI jen `world.walk.can_step`; mobily jen z registru; spawn jen z `SimWorld.systems` |
| **P7** | **`request_step` při rozjetém kroku vrací `busy`** — AI, která zkusí krok každý tick, stojí | `sim/systems/movement.gd`, funkce `request_step` (naměřeno: `_pending.has(m)` → `reason:"busy"`; soubor je rozpracovaný → jménem) | AI se ptá `pending_step(serial)` a plánuje další krok až po `due_ms` |
| **P8** | **Nedeterministický spawn.** Vlastní RNG nebo iterace přes `Dictionary` v pořadí vložení rozbije G8 | `sim/entity/registry.gd:51-58` (řazení podle serialu je pravidlo) | náhoda jen z `sim.rng()`; seznamy řadit podle serialu |
| **P9** | **NPC má jinou diagonálu než hráč** (hráč potřebuje obě ortogonální dlaždice, NPC jen jednu) — je to věrné, ale test to musí vědět | `docs/04` §4.6.1; `sim/world/walk.gd` (`is_player`) | testy AI nesmí předpokládat hráčovo pravidlo |
| **P10** | **Útok na neexistující/mrtvý cíl musí vrátit `reason`**, ne ticho | vzor `sim/craft.gd` (`reason`) | `attack` na neznámý serial → `{ok:false, reason:"no_target"}` |
| **P11** | **Animace monster nejsou exportované** — dnes jen těla 400/401, akce 0/1/4 → kostlivec by se **nekreslil** (a `render.anim` to hlásí jako `ok:false`) | `assets/uo/anim/anim-sheets.json` (měřeno); `tools/uoextract/anim.py:823` | krok E0: export těl monster + akce útoku/smrti |
| **P12** | **Vizuální změna se neověřuje testy** — naměřeno: hráč nebyl na obrazovce a všechny brány byly zelené | `docs/08` §8.5 | snímek + `read_image` na konci E5 |
| **P13** | **G4 (wiring) hlásí novou veřejnou funkci bez produkčního volajícího** | `docs/08` §8.3 (G4 hledá jen `sim/`, `ui/`, `render/`, `app/`) | integrace E5 musí `app.pick`, `render.names`, `world.spawn` opravdu volat |
| **P14** | **Výkonová brána pro NPC neexistuje** (G12 je v `docs/08`, ale nástroj není) | `tools/gates/run-all.py:41-52`; `bench_sim.gd` chybí | založit G12 **před** nasazením stovek NPC (§7.3) |
| **P15** | **Save se odmítne, když se změní `data/*.json`** (`data_version`) — správně, ale testy s fixture savy to musí čekat | `sim/sim_world.gd:169-171` | testy si `data_version` počítají z dat, neopisují |
| **P16** | **Číslo v promptu nemusí být naměřené** — plán to našel u tří granul (`88` monster vs 84 řádků/81 jmen, `25` vendorů vs 54, `12+3` tabulek vs 10 A–J) | měření `research/06` (2026-10-08, §12 O11) | přijímací kritérium se **píše z naměřeného počtu**, ne z promptu |
| **P17** | **Zadání pojmenovává stavy AI, které reference nemá** (`idle/aggro/attack/dead` vs `Wander/Combat/Flee/Guard/Backoff/Interact`) — kdo to vezme doslova, napíše automat, který se nedá srovnat s referencí | `_src/servuo/Scripts/Mobiles/AI/BaseAI.cs:45-53` | stavy **namapovat** v `docs/04` (§4.6) — jména smíme mít svá, mapování musí být napsané |
| **P18** | **Loot se neřídí fame** (fame→tier je jen pro paragony; 430 monster má vlastní `GenerateLoot()`) — kdo to udělá „podle fame", dostane jiné loot tabulky, než má hra | `_src/servuo/Scripts/Mobiles/Normal/BaseCreature.cs:5386-5408` | `loot_pack` **per monstrum** v `data/monsters.json` (§5.3) |
| **P19** | **„Strop 35" je jen direct damage**, ne obecný cap — kdo ho použije obecně, sebere hře damage | `_src/servuo/Scripts/Misc/AOS.cs:213` (`:251` je Blood Oath) | v granulích uvést přesně „direct damage cap" |
| **P20** | **Řádkové citace u rozpracovaných souborů se posouvají.** `app/world_view.gd` se mezi dvěma čteními posunul (session 19 ho editovala) — moje vlastní kontrola našla 2 citace, které po posunu ukazovaly jinam | naměřeno 2026-10-08 touto session (`_analyza/plan-npc-kontrola.py`, 6 nálezů) | u souborů v `git status` cituj **jméno funkce**, ne řádek; a po každé editaci cizí session čísla **přeměř** |

---

## 10. Co je potřeba doplnit do `docs/` a nástrojů (integrační kroky)

> **Agent `docs/` needituje** (`docs/09` §9.2) a `tools/gates/` je **bootstrap**
> („jen člověk"). Tenhle oddíl je proto **hotové znění k vložení**, ne úkol pro
> granuli. Bez svolení (D7) se nic z toho nemění.

### 10.1 `tools/roadmap-gen.py` (generátor je zdroj pravdy o granulích)

1. **D1:** `data.spawns` a `world.spawn` → `milestone="M5"`.
2. `world.spawn.provides` += `"state() -> Dictionary"`, `"restore(d) -> void"`.
3. `sim.ai.deps` += `"sim.pathfind"`; `sim.death.deps` += `"sim.decay"`.
4. Nová granule `app.pick` (§5.2) — **vloženo 2026-10-08**; export akcí útoku/smrti
   zůstal v promptu `assets.anim` (nová granule by kolidovala v `owns`).
5. **Opravit cesty a počty v promptech** (naměřeno, §12):
   - `data.weapons`: `research/03 (weapons3.json)` → **`research/_src/weapons3.json`** (134 záznamů),
   - `data.armor`: `research/03 (armor_raw.json)` → **`research/_src/armor_raw.json`** (165, ne ~90),
   - `data.item_properties`: → **`research/_src/itemprops_table.tsv`** (159 řádků; `research/03` §5.3 má 158),
   - `data.vendors`: prompt říká „§4", správně je **§2.2 + §5**,
   - `data.spawns`: prompt říká „§5", správně je **§4** (model spawnu) — **oddíly jsou prohozené**,
   - `data.monsters`: „88 monster" → **naměřeno 84 řádků / 81 unikátních jmen**;
     a **`loot` není z fame** (P18) — `loot_pack` per monstrum.
7. `sim.ai`: doplnit do promptu **mapování stavů** (P17) — `idle`≙`Wander` (klid),
   `aggro`/`attack`≙`Combat`, `flee`≙`Flee`, `dead` = mobil odstraněn
   (`Scripts/Mobiles/AI/BaseAI.cs:45-53`), a **interval myšlení v sekundách** (`CurrentSpeed`,
   0,2 s aktivní / 0,4 s pasivní), ne v ms.
6. `data.gen_content` (owns `tools/gates/gen-content.py`) **rozšířit o generátory**:
   `gen_weapons`, `gen_armor`, `gen_item_properties`, `gen_monsters`, `gen_spawns`,
   `gen_regions` — v souboru už je seznam `POZADAVKY` (ř. 45–62) a **12 z 15 cílů
   má `False` = „generator jeste neni napsany"** (živý běh `--check`: 3× OK, 12× NEMĚŘENO).

### 10.2 `docs/07-granule-a-milniky.md`

- §7.2: do řádku **M5** doplnit „+ spawn monster (D1)".
- §7.3: přidat **W12** (NPC): `sim.ai`, `data.spawns`, `render.names`, `app.pick`
  — a do poznámky, že `world.spawn` se pouští **až po** `sim.ai`.

### 10.3 `docs/04-architektura-a-smlouvy.md`

- §4.2: řádky pro `entity.equipment`, `entity.notoriety`, `sim.regen`, `sim.hunger`,
  `sim.decay`, `world.spawn` (+`state`/`restore`) a **nový** `app.pick` (tabulka `app`);
  u `sim.ai` **mapování stavů** na referenční (§4.6, P17) a u `sim.combat`
  akceptační číslo `swing_delay_ms(stam 100, speed 30) == 3000` (§4.6).
- §4.5: `Mobile` — doplnit `ai.next_think_ms/path/path_i` a `combat{...}` (§4.5 plánu).
- §4.6: nový tok **4.6.7 „Nasazení NPC a návrat k domovu"** (spawn → aggro → útok →
  smrt → obnova) s přijímacím kritériem; a do §4.6.4 doplnit, že `resolve_swing`
  vrací `{ok, hit, damage, absorbed, hp_left, killed, reason}`.

### 10.4 `tools/gates/` (bootstrap — jen člověk)

| Nástroj | Co doplnit |
|---|---|
| `check-content.py` | schéma pro `data/{weapons,armor,item_properties,monsters,spawns}.json`; počty C1–C10 **hlásit i nesplněné** (např. C6 v první vlně) |
| `check-render.py` | kontrola „**NPC je vidět**": na známé dlaždici stojí monstrum a pixely v jeho oblasti se liší od pozadí |
| `run-all.py` + **nový** `bench_sim.gd` | **G12**: 200 mobilů + 3 000 předmětů, `tick ≤ 2 ms` (docs/08 §8.2) |
| `mutace-tests.py` | `MODULY` pro `combat`, `ai`, `spawn`, `death`, `loot`, `regen`, `equipment`, `pick` (§7.2) |

---

## 11. Postup provedení (etapy E0–E6)

**Předletová kontrola (5 minut) před E1** — kdykoli se začne:

```powershell
git -C E:\Workspaces\game-clone status --porcelain -uall   # musí být čisto (session 19 commitnutá, §2.4)
python tools/plan-status.py                                # M5 0/0/9 -> kolik po mé práci
python tools/roadmap-gen.py --check                        # OK: DAG je konzistentní
$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"; `
  & .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
python tools/gates/run-all.py                              # 11 měřeno / 0 vad (zdroj: HANDOFF.md, 18. session)
python _analyza/plan-npc-kontrola.py                       # kontrola citací TOHOHO plánu (nesmí hlásit chyby)
```

> ⚠ `_analyza/` je v `.gitignore` (měřicí záznamy) — **v čerstvém klonu ten
> skript není.** Co kontroluje, je v jeho hlavičce: každou citaci `soubor:řádek`
> (soubor existuje + má tolik řádků), každý odkaz na oddíl `docs/`, u 48
> klíčových citací **i obsah řádku** a odkazy na pasti `docs/10`. Když dokument
> upravíš, spusť ho znovu — je to nejrychlejší způsob, jak poznat, že číslo
> v plánu už nesedí (naměřeno: 2 citace `app/world_view.gd` přestaly platit,
> když ho session 19 posunula).

| Etapa | Co se udělá | Kdo/čím | Hotovo, když |
|---|---|---|---|
| **E0** měření navíc (30–60 min) | **Změřit číslo animační akce pro útok a smrt** a exportovat těla monster (`tools/uoextract/anim.py --tela <50,56,…> --actions …` → `assets/uo/anim`); změřit art těla (corpse) a body ducha; změřit `swing delay` formuli v `_src/servuo` (`BaseWeapon.GetDelay`) | session, `_analyza/p23-*.gd` | `assets/uo/anim/anim-sheets.json` obsahuje tělo kostlivce a akci útoku; čísla mají citaci |
| **E1** data | `data.gen_content` rozšířit o 6 generátorů → spustit → `data/{weapons,armor,item_properties,monsters,spawns,regions}.json` | session + `tools/gates/gen-content.py` | `gen-content.py --check` hlásí OK pro všech 6; G5 projde, počty odpovídají měření |
| **E2** sim základy (V0+V2) | `sim.hunger`, `sim.decay`, `entity.notoriety`, `entity.equipment`, `sim.regen`, `world.regions` | 6 granul, `any`/`strong` dle size | testy volají API; `regen` doplní staminu (naměřeno: dřív se nedožene) |
| **E3** souboj (V3) | `sim.combat`, `sim.poison`, `sim.death`, `sim.loot` | 4 granule, `strong` | 20 švihů ≥ 5 zásahů; po `die` tělo s lootem; `resurrect` → hp 10 |
| **E4** NPC (V4) | `sim.ai`, `data.spawns`, `render.names`, `app.pick` | 4 granule | NPC se do 10 s pohne; klik na mobila vrátí jeho serial |
| **E5** integrace (V5) | export animací (`assets.anim`) → `world.spawn` → `sim.world_loop` (mobiles/items/spawn_state) → `app.main` (registrace) → `app.loop` (klik → `attack`) → `app.player_view` (kreslení mobilů) | **sekvenčně**, 1 soubor = 1 vlastník, `strong` | hra se spustí (G11), NPC je na obrazovce (G10 + snímek), save/load drží mobily (G7) |
| **E6** ověření | mutace nových modulů, nový replay s NPC, G8/G9, G12, snímek + lidská kontrola | session | každá brána má mutaci, která spadne; **žádná brána neměří prázdno** |

**Stop podmínky (kdy zastavit a vrátit se o vrstvu výš, ne opravovat kód):**
když se ukáže, že smlouva v §4 nesedí na realitu (např. `can_step` pro NPC
nejde použít) — **opraví se nejdřív smlouva a test, teprve pak kód**
(`docs/09` §9.5). A když se granule nedaří: **nerozšiřovat ji, ale rozložit**.

---

## 12. Otevřené otázky (co se MUSÍ změřit, ne domyslet)

| # | Otázka | Kde se to zjistí | Stav |
|---|---|---|---|
| **O1** | Které číslo akce v `anim.mul` je **útok** a které **smrt** (pro člověka i monstrum)? | `tools/uoextract/anim.py` (bloky akcí) + `_src/classicuo` mapování; export dnes zná jen 0/1/4 | **NEMĚŘENO** |
| **O2** | Jaký art má **tělo (corpse)** pro tělo 50/56 a jak se mapuje `body → corpse art`? | `docs/03` (tiledata) + `_src/servuo` (`Corpse.cs`) | **NEMĚŘENO** |
| **O3** | Jaké **body** má duch (ghost) a jak se liší kreslení? | `_src/servuo` (`Mobile.cs`, `Ghost`), `data/mobtypes.json` | **NEMĚŘENO** |
| **O4** | Přesný tvar `swing delay` a `hit chance` (AoS) včetně dolní meze 1,25 s | `_src/servuo/Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1598-1615`, `:1451`, `:1530-1533` | **NAMĚŘENO** (§4.6; akceptační číslo 3000 ms) |
| **O5** | Kolik zlata dává `LootPack.Poor` a jaká je šance na magický předmět | `_src/servuo/Scripts/Misc/LootPack.cs:421-422`, `:429-491` | **NAMĚŘENO** (§4.6: `1d25`, maxProps 1) |
| **O6** | Prodlevy spawnu a refill (5–10 min, 1/3) — přesné hodnoty a jednotky | `_src/servuo/Scripts/Services/Spawner/Spawner.cs:41`, `Scripts/Regions/Spawning/SpawnEntry.cs:536` | **NAMĚŘENO** (§4.6: `max((max−spawned)/3, 1)`) |
| **O7** | Souřadnice **hřbitova u Britainu** (spawn area) a jeho `z` | `data/regions.json` (až vznikne) + mapa; `docs/06` §6.7 | **NEMĚŘENO** |
| **O8** | Kolik mobilů se vejde do viditelného okna a jaký je `tick` s 200 mobily | nová G12 (`bench_sim.gd`) | **NEMĚŘENO** (brána neexistuje) |
| **O9** | Je `sim.pathfind` dost rychlý na myšlení AI každých ~500 ms? | měření v E4 (`_analyza/p23-*.gd`) | **NEMĚŘENO** |
| **O10** | Které úrovně jedu mají jaké intervaly a damage (5 úrovní) | `_src/servuo/Scripts/Misc/Poison.cs:23-27`, `:222-227` | **NAMĚŘENO** (§4.6, AoS tabulka) |
| **O13** | **Které `LootPack` má které z našich monster** (loot se neurčuje z fame — P18) | `_src/servuo/Scripts/Mobiles/**/*.cs` (`GenerateLoot`, 430 souborů) + `research/06` §3.4 | **NEMĚŘENO** → práce v E1 pro `gen_monsters` |
| **O14** | **Mapování našich stavů AI na referenční** (`idle/aggro/attack/dead` → `Wander/Combat/…`) — patří do `docs/04`, ne do kódu | `_src/servuo/Scripts/Mobiles/AI/BaseAI.cs:45-53` + `docs/05` §5.12 | **NÁVRH HOTOVÝ** (§4.6), čeká na svolení D7 |
| **O11** | **Počty v zadání nesedí na měření:** monster 88 vs **84 řádků/81 jmen**; vendorů 25 vs **54 klasických**; spawn tabulek „12+3" vs **10 (A–J)**; dungeonů „3" vs **15** v §1.7 | měření `research/06` (2026-10-08) | **NAMĚŘENO, k rozhodnutí** (D2) |
| **O12** | Strojové zdroje pro monstra/spawny **neexistují** — jen `.md` tabulky; generátory v `gen-content.py` jsou deklarované jako „nenapsané" | měření `tools/gates/gen-content.py` `POZADAVKY` (12× `False`) | **NAMĚŘENO** → práce v E1 |

---

## 13. Co se z tohohle plánu provedlo (doplňuje se)

| Datum | Co | Čím doloženo |
|---|---|---|
| 2026-10-08 | **D1 + D7 vloženy** (uživatel: „Souhlasím, vlož plán"): `tools/roadmap-gen.py` — `data.spawns` a `world.spawn` do M5, `world.spawn.provides` + `state()/restore()`, `sim.ai.deps` + `sim.pathfind`, `sim.death.deps` + `sim.decay`, nová granule **`app.pick`**, opravené cesty a počty v promptech (`research/_src/*`, monstra 84/81, vendory §2.2, spawny §4), naměřená čísla do promptů `sim.combat`/`sim.ai`/`sim.loot`/`sim.death`/`sim.poison` | `python tools/roadmap-gen.py` → **112 granul** (M2 34, M5 11, M7 7); `--check` → `OK: DAG je konzistentní`; `.forge/roadmap.json` přegenerován |
| 2026-10-08 | **Smlouvy v `docs/04`**: `sim.combat` (`state_of`, přijímací číslo 3000 ms), `sim.ai` (mapování stavů + myšlení v sekundách), `sim.loot` (`loot_pack` per monstrum), `sim.death` (7 min / 2 min / hp 10), `sim.poison` (AoS tabulka), `world.spawn` (+`state`/`restore`, M5), `render.names` (HP pruh cíle), nový **`app.pick`**, `Mobile.ai`/`combat`, §4.6.4 číslo, nový tok **§4.6.7** | `python tools/check-docs-refs.py` → OK (173 odkazů); `check-zadani.py` → OK |
| 2026-10-08 | **`docs/07`**: M5 dostal spawn, nová vlna **W12**, počty granul (112) a pokrytí vlnami **73 z 112** (naměřeno `plan-status.py`); staré číslo 62/111 označeno jako „ve svém čase správné" | `python tools/roadmap-gen.py --check` → OK (docs/07 zmínky hlídá generátor) |
| 2026-10-08 | **Zadání pro implementaci** `ZADANI-20-NPC-A-SOUBOJ.md` (etapy E0–E6, write-scope, co nedělat, povinné předání) | soubor v kořeni repa |
| 2026-10-08 | **Kontrola plánu** `_analyza/plan-npc-kontrola.py`: **74** citací `soubor:řádek`, u **45** z nich i obsah řádku, **8** citací jménem funkce, 7 odkazů na oddíly `docs/`, 3 odkazy na pasti `docs/10` | `exit 0` (spuštěno vícekrát, naposledy po všech editacích) |
| 2026-10-08 | **Past P20 potvrzena 3×**: během psaní plánu posunula session 19 řádky v `app/world_view.gd`, `sim/commands.gd`, `sim/systems/movement.gd` a `app/input_map.gd` → citace u **rozpracovaných souborů se převedly na jména funkcí** a kontrola je nově ověřuje jménem | `_analyza/plan-npc-kontrola.py` (sekce „jmenné citace“), plán P20 |

**Co z plánu NENÍ provedeno:** vlastní etapy **E0–E6** (kód, data, brány) — ty
jsou náplní session 20 podle `ZADANI-20-NPC-A-SOUBOJ.md`. Dále nejsou hotové
dvě věci z §10.4 (`tools/gates/`: schéma `check-content`, NPC kontrola
v `check-render`, **G12 `bench_sim.gd`**) — `tools/gates/` je bootstrap a čeká
na výslovné svolení uživatele (uvedeno v zadání §8).

**Až se podle plánu začne stavět:** sem patří **datum spotřeby** a seznam
provedených etap (E0…E6). Plán se pak **přepisuje celý** (je to plán, ne
záznam) — ale body, které zůstaly otevřené (O1–O12, D1–D8), se **nesmí ztratit**;
patří do `HANDOFF.md` mezi otevřené věci.


