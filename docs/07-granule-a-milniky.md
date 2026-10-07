# 7. Rozpad na granule a milníky

> Granule jsou **jednotky práce pro agenty**. Strojově čitelná podoba je
> v `.forge/roadmap.json` (klíč `grains`), tenhle oddíl vysvětluje pravidla
> a milníky.

## 7.1 Co je granule

```json
{
  "id": "sim.craft",
  "title": "Výroba — spuštění receptu",
  "kind": "code",
  "owns": ["sim/systems/craft.gd"],
  "depends_on": ["entity.container", "entity.skills", "data.recipes"],
  "provides": ["Craft.recipes_for(m, skill) -> Array",
               "Craft.craft(m, recipe_id, count) -> Dictionary"],
  "consumes": ["Container.add", "Skills.value", "SkillGain.check", "Events.push"],
  "acceptance": ["tests", "content"],
  "size_lines": "<= 120",
  "model": "strong",
  "milestone": "M4",
  "prompt": "…"
}
```

**Pravidla (vynucená lintem roadmapy):**

1. **1 granule = 1 soubor.** `owns` je výlučné; dvě granule ve stejné vlně
   nesmí mít stejný soubor.
2. **`depends_on` znamená „hotové a funkční"**, ne „je v DAGu". Do závislostí
   se staví jen na granuli, jejíž soubor je v `main` a jejíž API jde zavolat.
3. **`acceptance`** = čím se pozná hotovo (`tests`, `wiring`, `content`,
   `assets`, `render`, `save`, `determinism`, `replay`).
4. **`size_lines` a `model`** se deklarují u každé granule nad 60 řádků
   (výchozí `<= 60`, `any`). `strong` = jen silný model.
5. **Zakázané soubory** (`tests/`, `tools/gates/`, `project.godot`, `.forge/`,
   `docs/`, `assets/uo/`) nejsou v žádné granuli — patří bootstrapu
   a integračním krokům.
6. **Prompt se generuje ze schématu** a odkazuje na oddíly zadání; agent
   nedostane prózu bez smluv.

## 7.2 Milníky

Každý milník je **hratelný stav**, ne „vrstva kódu". Za každým je lidská
kontrola (snímek + projití scénáře).

| # | Milník | Co je na konci vidět | Brány |
|---|---|---|---|
| **M0** | **Kostra a pravidla** | `godot --headless --script res://tests/run_tests.gd` projde; simulace tiskne tick; vrstvy a schéma hlídá brána | G1, G2, G3, G11 |
| **M1** | **Data a svět** | na obrazovce je **mapa Britainu** s dlaždicemi a statiky; postava stojí nohama na dlaždici; manifest artu je ověřený | G5, G6, G10, G13 |
| **M2** | **Pohyb a interakce** | hráč chodí (400/200 ms), **najde cestu (click-to-move)**, otevírá dveře, projde teleportem, používá předměty kurzorem; postava je vidět **v pořadí kreslení** (mezi statiky) | G3, G4, G9 |
| **M3** | **Předměty a manipulace** | zvedne, položí, nasadí, dá do batohu a truhly; váha a stacky sedí; equippované věci jsou vidět na postavě | G3, G7, G10 |
| **M4** | **Skilly, sběr, výroba** | vytěží rudu, vytaví ingot, vyková dagger; skill roste; gump výroby funguje | G3, G5, G9 |
| **M5** | **Souboj a smrt** | zabije kostlivce, dostane loot, umře, stane se duchem, nechá se vzkřísit | G3, G8, G9 |
| **M6** | **Magie** | sesílá kouzla 1.–8. kruhu s many a reagenty; spellbook a svitky | G3, G5 |
| **M7** | **Ekonomika a svět** | koupí a prodá u vendora, uloží zlato do banky, potká spawny ve 3 dungeonech, **funguje den/noc a světlo (`render.light`)** | G3, G5, G9, G12 |
| **M8** | **Trvanlivost a uzavření** | uložení/načtení, determinismus, replaye, výkon, makra, credits, vydání (**zvuk a hudba je od 2026-10-07 VLASTNÍ TRAŤ** — viz poznámka pod tabulkou) | G7, G8, G9, G12, G13 |
| **M9** | **Modernizace** | typovaná konfigurace, dávkové kreslení bloků (mesh), měření výkonu a parity cache; **pravidlo: modernizace nesmí ubrat žádné měření** (každá změna má stejnou nebo silnější bránu) | G1–G13 (nesmí jich ubýt) |

**Pravidlo pro milníky:** milník není hotový, dokud **člověk** neprojde jeho
scénář a neuvidí ho. Zelené brány k tomu **nestačí** (naměřeno: hráč nebyl
na obrazovce, a všechny brány byly zelené).

**Zvuk a hudba je od 2026-10-07 vlastní trať** (rozhodnutí uživatele), ne
součást M8: `assets.sounds` (M1) → `audio.playback`. Kdo trať přejmenuje na
vlastní milník `A`, musí rozšířit `MILNIKY_PORADI` v `tools/roadmap-gen.py`,
`MILNIKY` v `tools/plan-status.py` a tuhle tabulku — jinak se granule přestane
řadit.

## 7.3 Vlny (co může běžet paralelně)

| Vlna | Granule (paralelně, disjunktní `owns`) |
|---|---|
| **W0** | `core.const`, `core.iso`, `core.rng`, `core.clock`, `core.serial`, `core.events`, `core.hash`, `data.balance` |
| **W1** | `world.tiledata`, `world.map`, `render.textures`, `render.hue`, `render.sort` (po `core.*`) |
| **W2** | `entity.mobile`, `entity.item`, `entity.stats`, `entity.skills`, `entity.container`, `entity.equipment`, `entity.notoriety` |
| **W3** | `render.chunk`, `render.anim`, `render.names`, `render.light`, `world.walk`, `world.doors` |
| **W4** | `sim.movement`, `sim.interaction`, `world.teleport`, `world.stairs`, `world.regions`, `world.time` |
| **W5** | `ui.hud`, `ui.journal`, `ui.status_bar`, `ui.paperdoll`, `ui.target_cursor`, `ui.context_menu`, `ui.dragdrop`, `ui.tooltip` |
| **W6** | `sim.skill_gain`, `sim.harvest`, `sim.craft`, `ui.craft_gump`, `ui.skill_list` |
| **W7** | `sim.combat`, `sim.poison`, `sim.ai`, `sim.loot`, `sim.death`, `ui.backpack`, `ui.container_window` |
| **W8** | `sim.magic`, `ui.spellbook`, `sim.vendor`, `ui.vendor_gump` |
| **W9** | `world.spawn`, `app.char_create`, `ui.options`, `ui.hotkeys`, `ui.macros`, `render.effects`, `audio.playback` |
| **W10** | `sim.entity_registry`, `sim.pathfind` (po `world.walk`), `app.scene`, `app.player_view`, `app.player_controller` (integrace scény) |
| **W11** | `app.config`, `app.metrics`, `render.chunk_mesh` (M9 — až po M8) |

**Granule bez vlny (a proč):** `boot.*` (bootstrap — zakládá je člověk),
`assets.*` (extrakce dat — sekvenční, jedna po druhé, viz W1) a `app.*` integrační
uzly, které se dotýkají scény. Naměřeno 2026-10-06 (`python tools/plan-status.py`):
vlny pokrývají **62 z 111** granul; zbytek jsou právě tyhle tři druhy.
**Pravidlo: granule, která není ani ve vlně, ani v tomhle seznamu, se nesmí vydat** —
nejdřív se zařadí (jinak se nedá poznat, co může běžet paralelně).

**Pozor na sdílené místo:** `sim/sim_world.gd` a `app/loop.gd` registrují
systémy — do těch smí sahat **jen integrační granule**. Ostatní systémy se
registrují přes `provides` a registr je vyčleněný (jinak si agenti rozbijí
tick mezi sebou).

## 7.4 Jak se granule vydává (co agent dostane)

1. **Prompt** z `roadmap.json` (odkazuje na oddíly `docs/`).
2. **Soubory k editaci** = `owns` granule (a `owns` jejích závislostí jen ke čtení).
3. **Smlouvy** = `provides`/`consumes` z granule a tabulky v `docs/04`.
4. **Přijímací kritérium** = `acceptance` + konkrétní volání z `docs/04` §4.6.
5. **Non-goals** = §1.5 a zákazy z `docs/09` §9.10.

## 7.5 Odhad rozsahu

**Pozor: tabulka níž je ODHAD ze vzniku plánu (2026-10-02) a je zastaralá.**
Skutečné počty granul hlásí generátor — naměřeno 2026-10-06 po revizi plánu:

| Milník | Granulí (měřeno) |
|---|---|
| M0 | 17 |
| M1 | 23 |
| M2 | 32 |
| M3 | 5 |
| M4 | 6 |
| M5 | 9 |
| M6 | 3 |
| M7 | 9 |
| M8 | 4 |
| M9 | 3 |
| **celkem** | **111** |

*(M2 je velký, protože do něj patří integrace scény a cesta hráče; M3–M8 jsou
zatím jen deklarované — jejich obsah vzniká, až na ně dojde. Původní odhad
„~75–90“ s dnešními 111 nesedí; rozdíl je v tom, že se doplnily granule pro
soubory, které dřív neměly vlastníka, a trať M9.)*

| Milník | Granulí (odhad 2026-10-02) | Poznámka |
|---|---|---|
| M0 | 8–10 | kostra, všechny malé |
| M1 | 16–20 | **nejtěžší část** (extrakce dat) — tady je riziko, že se něco nepodaří přečíst (O1, O2) |
| M2 | 12–15 | pohyb + UI jádro |
| M3 | 8–10 | předměty, výbava, gump batohu |
| M4 | 6–8 | skilly, sběr, výroba |
| M5 | 8–10 | souboj, AI, smrt |
| M6 | 4–5 | magie |
| M7 | 6–8 | ekonomika, spawn, svět |
| M8 | 5–7 | uložení, výkon, makra, vydání |
| **celkem** | **~75–90** | `size_lines <= 60` většina, `strong` tam, kde je umělý šev (combat, craft, chunk_renderer, tiledata) |

**Když se granule nedaří:** nerozšiřuj ji. Rozlož ji na dvě (nebo zjisti, že
závislost není hotová) — a zapiš to do `docs/`.
