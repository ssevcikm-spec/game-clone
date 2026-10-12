# ZADÁNÍ 27 — POCIT: animace postav, dosah interakce, odezva

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalo) — nepřepisuje se.
> Vzniklo **2026-10-12** z odpovědi uživatele („svět není koherentní a je mrtvý —
> postavy nemají animace, neřeší vzdálenost pro interakci, nevidím zpětnou vazbu“)
> a z **měření v téže session**. **Stav projektu:** `HANDOFF.md`. **Směr:** volba
> uživatele „POCIT: odezva + zvuk“ (12. 10.) — magie (`M6`) se tím odkládá, ne ruší.
> **Cíl zadání:** tři pojmenované vady, každá s vlastním důkazem a branou.

## 1. Cíl

Hra dnes **funguje**, ale **nevypadá, že žije**: monstra se sunou v postoji,
dveře a obchod se otevřou z druhého konce mapy a na úspěch ani neúspěch není
slyšet. Zadání je **odstranit ty tři věci**, ne přidat obsah.

**Proč zrovna tyhle tři:** jsou to tři nezávislé vrstvy (klient / simulace / zvuk),
takže se dají měřit zvlášť, a každá z nich odpovídá na jednu větu uživatele.
Všechno ostatní z „pocitu“ (tooltipy, pravé tlačítko, drag & drop, den/noc)
zůstává **otevřené a nezařazené** — plán je v `DALSI-SESSION.md` §D.

## 2. Naměřená fakta (vstup, neopakovat měření)

Měřeno **2026-10-12** v této session; každý bod je dohledatelný v kódu.

### 2.1 Animace: simulace je POSÍLÁ, klient je NEODEBÍRÁ

| Co | Kde | Naměřeno |
|---|---|---|
| Simulace publikuje událost `mobile_anim` | `sim/systems/movement.gd:196`, `sim/systems/combat.gd:987` | `{serial, action, frame_ms}`, akce 0 = chůze, 1 = běh, 2 = útok, 3 = smrt |
| Klient ji **nikde nečte** | hledáno v celém `app/` | jediný výskyt je **komentář** `app/player_controller.gd:20-21` („`mobile_anim` take nikdo neodebiral“) |
| Všichni cizí mobilové se kreslí **postojem** | `app/world_view.gd:426` + `:504-505` | `_anim.play(serial, _anim_idle(), mob.dir)`, a `_anim_idle()` vrací **natvrdo 4** |
| Hráč animovaný JE | `app/world_view.gd:1310` | bere `_action` z lokálního vstupu (`app/player_controller`) — proto to „jde“ jen jemu |
| Data ani listy nechybí | `render/anim_player.gd` | `walk`/`run`/`idle`/`attack`/`die` + mapa skupin **per tělo** (`sprite_group_for`) |

**Důsledek:** monstrum se ve světě posouvá, ale pořád stojí — a protože se to
týká **všech** NPC, je svět mrtvý jako celek, ne „jedna chybějící animace“.

### 2.2 Dosah interakce hlídá jen ČÁST systémů

| Systém | Dosah | Kde |
|---|---|---|
| výroba (kovadlina, výheň) | **2 dlaždice** | `sim/systems/craft.gd:80,84` (`STATION_RANGE`, `LIFT_RANGE`) |
| těžba (ruda, dřevo, ryba) | **2 / 2 / 4** z dat | `sim/systems/harvest.gd:294` |
| loot z těla | **2 dlaždice** | `sim/systems/interaction.gd:99` (`LOOT_RANGE`) |
| obchod (buy/sell) | **2 dlaždice** | `sim/systems/vendor.gd:63` (`VENDOR_RANGE`) |
| **útok (hráč)** | **žádný** | `sim/systems/combat.gd:175` — v celém souboru není porovnání pozice |
| **`use`: dveře, truhla, otevření obchodu, equip, světlo, svitek** | **žádný** | `sim/systems/interaction.gd:516` (`_run_use`), ověřeno i v `sim/commands.gd:77-95` (validace řeší jen `dir` a `action`, ne pozici) |
| AI (monstra) | **1 dlaždice** | `sim/systems/ai.gd:104` (`MELEE_RANGE`) |

**Důsledek a přesná formulace vady:** svět je **přísný na monstra a benevolentní
k hráči** — hráč zaútočí a otevře obchod na jakoukoli vzdálenost, kdežto monstrum
musí být na dostřel ruky. To je ta nekoherence, kterou uživatel cítí.

### 2.3 Odezva je dnes jen text v žurnálu

* **Dobrá zpráva, naměřeno:** chybějící systém nekončí tichem — `_fail()` posílá
  hlášku (`sim/systems/interaction.gd:720-724`), `sim/commands.gd:101` hlásí
  neplatný příkaz.
* **Zvuk: nula.** `AudioStream` ani `AudioStreamPlayer` nejsou v celém repu
  (grep nad `*.gd` = **0 nálezů**); `app/sound.gd` a `tools/uoextract/sounds.py`
  neexistují. Zvuk je od 2026-10-07 **vlastní trať** (rozhodnutí uživatele).
* **Vizuální odezva na úspěch chybí:** žádný plovoucí text damage, žádný záblesk
  zásahu, žádná změna kurzoru (`ui/target_cursor.gd` neexistuje).
* **Pozor na hranici:** `docs/01 §1.5 bod 8` — QoL smí zkrátit klikání a zlepšit
  čitelnost, ale **nesmí změnit výsledek** (žádný loot navíc, žádné zkrácení časovačů).

## 3. Required výstup

Tři granule, v tomhle pořadí (P1 je nejviditelnější, P2 je nejlevnější na ověření):

### P1 — animace všech postav (klient; `app/`)

`app/world_view.gd` přestane posílat natvrdo `4`. Akce se bere **ze stavu**, který
už existuje: běžící krok (`sim/movement.pending_step(serial)`) → `walk`/`run`
**a směr kroku**; jinak `idle`. `app/main.gd` předá `movement` do `world_view`
**novým aditivním setterem** (dnes `world_view` žádnou referenci na `movement`
nemá — `app/world_view.gd:297` `setup()`, `:316` `set_registry()`, `:359` `set_mobily()`).

**Útok a smrt jsou druhý krok**, ne součást P1: `sim.combat.state_of()` dnes
nenese čas posledního swingu, takže by si je klient musel domýšlet — a domýšlení
stavu v klientovi je proti `docs/01 §1.5 bod 9`.

### P2 — dosah interakce (sim; `sim/`)

* **Útok:** melee dosah **1 dlaždice** (Chebyshev) — stejná hodnota, jakou už má
  AI (`sim/systems/ai.gd:104`). Kde je dosah věcí zbraně (později luky), patří
  do dat, ne do kódu.
* **`use` na cizí objekt** (dveře, truhla, otevření obchodu): **2 dlaždice** —
  stejná hodnota jako `LOOT_RANGE`/`VENDOR_RANGE`, aby svět neměl tři různá čísla.
* **Bez dosahu:** vlastní batoh, nasazení výbavy, světlo, svitek (cíl je hráč sám).
* **Mimo dosah = `{ok:false, reason:"out_of_range"}` + hláška**, ne ticho
  (stejný vzor, jaký má `_fail()` dnes).

### P3 — odezva (zvuk, pak vizuál)

1. `tools/uoextract/sounds.py` + `app/sound.gd` s **volnými** zvuky (CC0/CC-BY;
   `README.md` to pro distribuci vyžaduje) na čtyři události: **zásah, zásah
   dostaneme, těžba/kování, smrt**.
2. Teprve pak vizuální odezva (plovoucí číslo damage) — a jen čitelnost, ne výsledek.

## 4. Jak ověřit (brány, které UMÍ selhat)

| # | Co se měří | Jak | Kdy je to vada |
|---|---|---|---|
| **A1** | **animace cizí postavy se mění** | sonda přes reálnou scénu (`app/main`): nech mobil jít krok a přečti, jakou akci `render.anim` dostal | u kroku vyjde **4** (postoj) = vada; po zastavení musí být 4 |
| **A2** | **je to vidět** | dva snímky téhož monstra v různých framech kroku | obě pózy shodné = vada |
| **B1** | **dosah platí** | nový case: útok a `use` **na dosah** projdou, **o dlaždici dál** vrátí `out_of_range` | na dosah vrátí `out_of_range` (falešná přísnost) nebo z dálky projde |
| **B2** | **test umí selhat** | mutace: vypni kontrolu dosahu → B1 musí spadnout | B1 zůstane zelený = slepá brána |
| **C1** | **zvuk se opravdu přehraje** | sonda: událost → počet spuštěných streamů **> 0** (ne „soubor existuje“) | nula = jen mrtvá deklarace |
| **D** | **nic se nerozbilo** | testy, `tools/gates/run-all.py`, replaye a determinismus **beze změny hashů** (P1 je klientská) | cokoli červené = vada |

**Hotovo je, když:** A1, A2, B1, B2, C1 a D projdou, u P2 jsou stávající testy
zelené (případná změna vzdálenosti v testu je **zapsaná s důvodem**, ne obejitá)
a uživatel projde krátkou smyčku a řekne, že se to zlepšilo.

## 5. Co NEDĚLAT

* **Nesahat na `sim/` kvůli animaci** — P1 je klientská věc; hash stavu se nesmí
  změnit (`docs/01 §1.5 bod 9`: UI nikdy nemění stav, simulace nikdy nesahá na scénu).
* **`tests/run_tests.gd` se needituje** (nové case soubory jsou v pořádku).
* **Nepoužít zvuk ani art z instalace UO** — jen volné (CC0/CC-BY); `assets/uo/`
  zůstává v `.gitignore`.
* **Neměnit geometrii** ani bránu `G1`; **nepřidávat float do stavu** (`G14`).
* **Nezavádět „jistotu“** (`docs/01 §1.8`): žádné číslo nebezpečnosti, žádný
  přesný dohled — jen čitelnost.
* **Nezapisovat nové granule do `.forge/roadmap.json`** — plán mění uživatel
  (`docs/07 §7.1 bod 5`).

## 6. Co potřebuju od tebe

1. **Sedí rozsah a pořadí P1 → P2 → P3?** (Zvuk je nejdražší; jde udělat i jako
   poslední, nebo přeskočit a vrátit se k magii.)
2. **Smí být dosah v datech** (`data/balance.json`), nebo stačí konstanta
   s odkazem na referenci? Dnes jsou obě cesty v projektu zastoupené
   (`harvest` bere dosah z dat, `craft`/`vendor` mají konstantu).
3. **Zobrazení zdraví** zůstává odložené (`docs/01 §1.8`) — uživatel se rozhodne
   **až po P1–P3**, až si to zahraje.
