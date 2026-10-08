# ZADÁNÍ pro session 20 (UO-klon, 2026-10-08) — NASAZENÍ NPC A BOJOVÝ SYSTÉM

> **Co je tenhle soubor: ZADÁNÍ** (co má session udělat), **ne stav a ne záznam
> o provedení.** Vzniklo 2026-10-08 ze schváleného plánu
> `PLAN-NPC-A-SOUBOJ-2026-10-08.md` v kořeni repa (uživatel: „Souhlasím, vlož plán").
> **Datum spotřeby: začátek session 20.** Co se z něj provede, patří do
> `PLAN-NPC-A-SOUBOJ-2026-10-08.md` §13, do `HANDOFF.md` a do `LESSONS.md`.
> **Současný stav projektu je v `HANDOFF.md`** (přepisuje ho ta session, která
> končí) — tenhle soubor ho nenahrazuje.

---

## 1. Blok ke zkopírování do nové session

```text
Pracovní složka: E:\Workspaces\game-clone

Přečti ZADANI-20-NPC-A-SOUBOJ.md (celé), pak PLAN-NPC-A-SOUBOJ-2026-10-08.md
(hlavně §4 smlouvy, §5 granule, §6 vlny, §7 brány, §11 postup). Pak teprve HANDOFF.md
a docs/04 §4.2 + §4.6 a docs/05 §5.5, §5.12–§5.14.

⚠ TATO SESSION POTŘEBUJE PLNÝ PŘÍSTUP (v workspace-write padají brány G3/G7/G11).

Než začneš psát: spusť předletovou kontrolu z §3 zadání a NAPIŠ MI, co jsi přečetl,
co budeš dělat první a proč. První práce je E0 (měření animačních akcí), ne kód.

Drž se etap E0–E6 ze zadání. Piš jen do souborů, které etapa uvádí (write-scope).
tests/ jsou spec, docs/ a tools/gates/ needituj bez mého svolení.
"Hotovo" = soubor v main A brána zavolala jeho funkci A přijímací kritérium
proběhlo s konkrétní hodnotou — zelené testy samy nestačí.

Na konci (povinné): doplň PLAN-NPC-A-SOUBOJ-2026-10-08.md §13 (co se provedlo),
přepiš HANDOFF.md na stav po své práci a přidej do LESSONS.md, co tě stálo čas.
```

---

## 2. Cíl session

**Postavit to, co plán označuje za etapy E0–E6** — tedy milník **M5 „Souboj
a smrt"** včetně nasazení monster do světa:

na konci session musí v běžící hře **existovat monstrum, jít na něj zaútočit,
zabít ho, vzít mu loot, umřít, stát se duchem a nechat se vzkřísit** — a musí
to být **vidět na snímku** (ne jen v testech).

**Co je na konci měřitelné:** plán §1 tabulka V1–V7. Když některé V nevyjde,
patří to do „Co se NEOPRAVILO" v `HANDOFF.md` — ne do ticha.

---

## 3. Předletová kontrola (5 minut, než začneš psát)

```powershell
cd E:\Workspaces\game-clone
git log --oneline -1                      # očekáváno: novější než d6a1188 (session 19 commitnutá)
git status --porcelain -uall               # cílem je ČISTO; pokud visí soubory session 19, NEPIŠ do nich
python tools/plan-status.py                # očekáváno: 112 granul, hotových 59, M5 = 0/0/11
python tools/roadmap-gen.py --check        # OK: DAG je konzistentní (112 granul)
python tools/check-docs-refs.py            # OK (173 odkazů)
python tools/check-zadani.py               # OK
$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
python tools/gates/run-all.py              # očekáváno: 11 měřeno / 0 vad
python _analyza/plan-npc-kontrola.py       # kontrola citací plánu (nesmí hlásit chyby)
```

**Když se čísla liší, je to informace, ne chyba** — zapiš je do `HANDOFF.md`
a uprav podle nich další kroky. **Varování:** `tests/cases`, `sim/`, `app/`,
`render/` mohly mezitím změnit session 18/19 — **po každé cizí session přeměř
řádky**, na které se plán odkazuje (past P20 v plánu).

---

## 4. Etapy (v tomto pořadí) — co dělat a co je hotové

### E0 — měření navíc (30–60 min, **začni tady**)

| Co | Jak | Hotovo, když |
|---|---|---|
| Číslo animační akce pro **útok** a **smrt** | `tools/uoextract/anim.py` (bloky akcí) + `_src/classicuo`; sonda `_analyza/p23-*.gd` | číslo je **naměřené** a má citaci (dnes export zná jen `0:walk, 1:run, 4:idle`) |
| Export těl monster | `python tools/uoextract/anim.py --tela 50,56,… --actions … --export assets/uo/anim` | `assets/uo/anim/anim-sheets.json` obsahuje tělo kostlivce (50/56, `_src/servuo/Scripts/Mobiles/Normal/Skeleton.cs:14`) a akci útoku |
| Art těla (corpse) a body ducha | `docs/03` (tiledata) + `_src/servuo` (`Corpse.cs`, `Race.GhostBody`) | číslo je v plánu §12 (O2/O3) a je označené jako naměřené |

**Proč první:** bez animace útoku a těla monstra se „zabije kostlivce" nedá
dokázat snímkem a hrozí, že se udělá AI i souboj, které **nikdo neuvidí**
(přesně to se stalo u `uo-shadows`: 13 granul „hotovo", z toho 10, které hra
nikdy nezavolala).

### E1 — data (generátory)

`tools/gates/gen-content.py` má 15 cílů, **12 z nich `False` = „generator jeste
neni napsany"** (živě: `python tools/gates/gen-content.py --check` → 3× OK,
12× NEMĚŘENO). Napsat `gen_weapons`, `gen_armor`, `gen_item_properties`,
`gen_monsters`, `gen_spawns`, `gen_regions`:

| Soubor | Strojový zdroj (měřeno) |
|---|---|
| `data/weapons.json` | `research/_src/weapons3.json` — 134 záznamů |
| `data/armor.json` | `research/_src/armor_raw.json` — 165 |
| `data/item_properties.json` | `research/_src/itemprops_table.tsv` — 159 řádků bez hlavičky |
| `data/monsters.json` | **žádný JSON** — tabulky `research/06 §3` (84 řádků / 81 jmen) + `loot_pack` z `GenerateLoot()` |
| `data/spawns.json` | **žádný JSON** — `research/06 §4` (+ §4.8 = 10 tabulek A–J) |
| `data/regions.json` | **žádný JSON** — `research/06 §1` (19 měst, 9 moongate) |

⚠ **`tools/gates/` je bootstrap — měnit ho smí jen se svolením uživatele.**
Když svolení není, napiš generátory jako jednorázové skripty do `_analyza/`
a **nahlas to** v `HANDOFF.md` jako dluh (data pak nejdou reprodukovat).

### E2 — sim základy (6 granul, disjunktní `owns`)

`sim.hunger`, `sim.decay` (`sim/systems/{hunger,decay}.gd`), `entity.notoriety`
(`sim/entity/notoriety.gd`), `data.regions`, `entity.equipment`
(`sim/entity/equipment.gd`), `world.regions` (`sim/world/regions.gd`),
`sim.regen` (`sim/systems/regen.gd`, až po `hunger`).

### E3 — souboj (4 granule)

`sim.combat` (`sim/systems/combat.gd`), `sim.poison`, `sim.death`, `sim.loot`.
Smlouvy a naměřená čísla: plán §4.2 a §4.6, `docs/04` §4.2 + §4.6.4 + §4.6.7.
**Přijímací číslo:** `swing_delay_ms` při stam 100 / speed 30 = **3000 ms**.

### E4 — NPC (4 granule)

`sim.ai` (`sim/systems/ai.gd` — stavy mapuj na referenční, myšlení v sekundách),
`data.spawns`, `render.names` (`render/name_plates.gd`), `app.pick`
(`app/pick.gd`, nová granule — viz `docs/04` §4.2 `app`).

### E5 — integrace (SEKVENČNĚ, 1 soubor = 1 vlastník)

`assets.anim` export → `world.spawn` (`sim/world/spawn.gd`) →
`sim.world_loop` (`sim/sim_world.gd`: `mobiles`, `items`, `spawn_state`) →
`app.main` (`app/main.gd`: registrace systémů) → `app.loop` (`app/loop.gd`:
klik → `attack`) → `app.player_view` (`app/world_view.gd`: kreslení mobilů).

⚠ **Do `app/world_view.gd`, `app/input_map.gd`, `app/player_controller.gd`,
`sim/world/walk.gd`, `sim/systems/movement.gd` sahej jen tehdy, když je
`git status` u nich čistý** (držela je session 19).

### E6 — ověření

Mutace pro nové moduly (`tools/gates/mutace-tests.py` — **bootstrap, svolení**),
nový replay s NPC, G8/G9, G7 (save s mobily), G11, snímek + `read_image`,
a **G12** (`bench_sim.gd`, 200 mobilů / tick ≤ 2 ms) — ta dnes **neexistuje**.

---

## 5. Pravidla, která platí bez výjimky

1. **Piš jen do `owns` své granule.** `tests/**`, `tools/gates/**`,
   `project.godot`, `.forge/**`, `docs/**`, `assets/uo/**` mění jen člověk nebo
   integrační krok (`docs/09` §9.2).
2. **Testy jsou spec** (`docs/09` §9.5) — a musí být **nepodmíněné**: když
   soubor granule chybí, test **spadne**. Podmíněný test je tiše zelený
   (v `tests/run_tests.gd:27-45` se case soubor s parse errorem **tiše přeskočí**).
3. **Test musí kód ZAVOLAT a měřit hodnotu**, ne `has_method` (`docs/08` §8.6).
4. **Ke každé nové kontrole patří mutace**, která ji shodí — a po vložení mutace
   zkontroluj, že se **našla** (harness hlásí „PATRANA VETA SE NENASLA").
5. **Stav časovačů patří do systému/mobilu** (`due_ms`), ne do
   `core.clock.after(Callable)` — Callable není v `state_hash` ani v save.
6. **Náhodu jen z `sim.rng()`**, čas z `sim.clock()`, serialy ze `sim.next_serial()`;
   `sim/` nesmí použít `Input`, `Time`, `OS`, `randf()` (brána G2).
7. **Neměň smlouvy tiše.** Když implementace odhalí díru, řekni to a čekej na
   svolení (smlouvy jsou v `docs/04`).
8. **Nedávej `done: true`** do roadmapy ručně — hotovost se **měří**
   (`python tools/plan-status.py`).
9. **„Nula a prázdno nejsou úspěch"** — když kontrola nic nezměřila, nahlas to.

---

## 6. Co NEDĚLAT (non-goals, plné znění v plánu §8)

- magie, vendorové a obchod, zvuk a hudba, 3 dungeony, 12 spawn tabulek,
  19 měst s obsluhou (to je M6/M7),
- zvláštní útoky zbraní (31), magické předměty v lootu (`roll_magic_item`
  vrací `{}` a hlásí to), krotitelství a mounty,
- ztráta statů/skillu při smrti a pojištění předmětů (`UNVERIFIED`, default vypnuto),
- **vlastní seznam mobilů** v AI/spawnu/renderu (jediné místo je
  `sim.entity_registry`) a **vlastní kopie pravidel průchodnosti** v AI
  (ptej se `world.walk.can_step`),
- přepis `sim/sim_world.gd` na jiný návrh — jen **aditivně** naplnit
  `mobiles`/`items`/`spawn_state`, které tam už jsou.

---

## 7. Co je potřeba na konci (povinné předání)

| Co | Kam |
|---|---|
| Co se z plánu provedlo (datum spotřeby + etapy) | `PLAN-NPC-A-SOUBOJ-2026-10-08.md` §13 |
| Stav projektu po session | `HANDOFF.md` (přepsat celý, včetně „Co čeká na tebe") |
| Co tě stálo čas (past, omyl, nový nástroj) | `LESSONS.md` (doplňovat, nepřepisovat) |
| Naměřené snímky a sondy | `_analyza/p23-*.png` / `p23-*.txt` (gitignore) |
| Nehotové body a otevřené otázky | `HANDOFF.md` — **nesmí zmizet** O1–O14 z plánu §12 |

**Push na GitHub** jen po zelených branách a s ověřením, že dorazil
(`git rev-list --count origin/main..HEAD` → 0). Uživatel commit i push
schválil jako práci agenta (2026-10-07), ale **před pushnutím ukázat
`git status` a `git diff --stat`**.

---

## 8. Rozhodnutí, která už jsou udělaná (neotvírat znovu)

| # | Rozhodnutí | Stav |
|---|---|---|
| **D1** | `data.spawns` + `world.spawn` přesunuty z M7 do M5 | **hotovo** 2026-10-08 (`tools/roadmap-gen.py`, `docs/07` §7.2/§7.3/§7.5) |
| **D7** | Smlouvy vloženy do `docs/04` (včetně `app.pick` a mapování stavů AI) | **hotovo** 2026-10-08 |
| **D2** | První vlna: 3 monstra (kostlivec, krysa, zombie) + 1 spawn tabulka (hřbitov u Britainu) | doporučení — platí, dokud uživatel neřekne jinak |
| **D3** | `sim.regen` + `sim.hunger` zařazeny do E2 | doporučení |
| **D4** | Loot bez magických předmětů (`roll_magic_item` → `{}` + hlášení) | doporučení |
| **D5** | Zvuk: systémy posílají událost `sound`, klient ji zatím ignoruje | doporučení |
| **D6** | Ztráta statů/skillu při smrti se nedělá | doporučení |

**Co zůstává na uživateli:** svolení k editaci `tools/gates/` (mutace, G12,
schéma `check-content`, NPC kontrola v `check-render`) a k případným dalším
změnám `docs/`.

---

## 9. Otevřené otázky, které se MUSÍ změřit (ne domyslet)

Plán §12 je vede jako O1–O14; pro session 20 jsou kritické **O1** (číslo
animační akce útoku/smrti), **O2** (art těla), **O3** (body ducha), **O7**
(souřadnice hřbitova u Britainu), **O8** (tick s 200 mobily), **O9** (cena
`sim.pathfind` v AI), **O13** (loot packy monster). **Co se nepodaří změřit,
se napíše jako NEMĚŘENO** — nikdy se nedomýšlí.
