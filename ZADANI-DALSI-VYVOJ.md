# ZADÁNÍ pro další vývoj — UO-klon (stav k 2026-10-06)

> **Co je tenhle soubor:** **zadání** pro další pracovní session. Je to záznam
> o tom, co se zadalO — **nepřepisuje se**; co se z něj provede, se zapíše do
> `HANDOFF.md` (stav) a do `LESSONS.md` (ponaučení).
> **Současný stav projektu je v `HANDOFF.md`** (ten se přepisuje celý).
> **Vzniklo z auditu 2026-10-06, který NEMĚNIL kód** — všechna čísla jsou
> naměřená, ne opsaná z dřívějších předání.
>
> **Hlavní zadání hry zůstává `ZADANI-UO-KLON.md`** + `docs/01`–`docs/11`.
> Tenhle soubor ho **nenahrazuje** — zužuje ho na to, co je potřeba udělat
> **teď**, protože audit našel tři věci, které v plánu nejsou a bez nich
> zůstane hotový kód mrtvý.

---

## 0. Než začneš psát (povinné)

1. Přečti **`HANDOFF.md`** (stav) a **prvních pár záznamů z `LESSONS.md`**.
2. Přečti `docs/09` (pravidla pro agenta) a `docs/04 §4.2` (smlouvy) — bez nich
   nevymýšlej jména API.
3. Spusť předletovou kontrolu z `HANDOFF.md` a **napiš, co jsi naměřil**.
4. **Než začneš psát kód, řekni uživateli, co budeš dělat první a proč.**

**Prostředí (past, která stojí čas):** tato session potřebuje **plný přístup**.
V režimu `workspace-write` nejde zapsat do `.cache` (Low integritní label) →
brány G3/G7/G11 hlásí vadu, testy hlásí `save=false`, `run-all.py` spadne na
`summary.json`. **Neopravuj kvůli tomu kód** — je to prostředí.

---

## 1. Cíl této etapy

**Cíl jednou větou:** dostat na obrazovku **mapu Britainu** a postavu, která po ní
**chodí** — tedy dokončit milník **M1** a **M2** z `docs/07 §7.2`.

**Dílčí cíl A (vidět mapu):** `render.textures` → `render.chunk` → zapojení do
scény. Tím se poprvé vykreslí pixely a **G10 se otočí ze žluté na zelenou**.

**Dílčí cíl B (chodit):** `data.skills` → `entity.skills` → `entity.mobile` →
`world.walk` → `sim.movement` + opravené zapojení systémů a vstupu.

**Co v této etapě NEDĚLAT:** souboj, magie, obchod, řemeslo, UI okna (M3–M7).
Data (`data.weapons`, `data.spells`, …) se v této etapě negenerují.

---

## 2. Naměřená fakta (co z toho vychází)

Vše měřeno 2026-10-06 v read-only režimu. **Čísla se opakují v `HANDOFF.md`** —
tady jsou jen ta, která mění plán.

| # | Fakt | Čím je doložený |
|---|---|---|
| F1 | Na obrazovce **není nic** | `main.tscn` má jediný uzel `Node2D`; snímek má **1 barvu** (77,77,77) na 921 600 px |
| F2 | `render/` má **1 soubor ze 7** plánovaných; `ui/` neexistuje | `Get-ChildItem render -File` → 2 (z toho 1 `.uid`) |
| F3 | `render.sort` má **0 volajících z produkce** | grep v `app/`, `sim/`, `core/` → 0; hlásí to i `check-wiring.json` |
| F4 | `sim.systems` **plní jen testy** | `systems[` jen v `sim_world.gd:82` (čtení) a `tests/cases/sim_world.gd:85-87` |
| F5 | `input_map` se **nikdy nepřidá do stromu** | `app/main.gd:30` přidává jen `loop` |
| F6 | `time.world_time_ms` **nikdo nezapíše** → `hour()` je vždy 0 | `time.gd:23`; zapisuje ho jen `tests/cases/time.gd` |
| F7 | `move` skončí „Not available yet" | `sim/commands.gd` routing na neexistující systém |
| F8 | Data i mapa **jsou hotové a ověřené** | sonda mapy 18/0 (60 statik v britském bloku, 9 329 v okolí ±6 bloků); `manifest.json` 17 436 spritů |
| F9 | `atlas.py` **není v gitu** a má vadu | `git status` → `??`; **117 překryvů**, **17 prázdných spritů** |
| F10 | Atlas **není jen „nehotový"** — jeho self-test je slepý | `--self-test` hlásí 30 kontrol / 0 chyb, ale kontrolu překryvů pouští na **6 spritech** místo 17 436 |
| F11 | *(ve svém čase správné)* **12 commitů nebylo před GitHubem** a CI nikdy neproběhlo | `git rev-list --count origin/main..HEAD` → 12; `ci.yml` sám sebe značí `UNVERIFIED`. **Dnes už neplatí — viz F12 a F13** |
| F12 | **Během auditu se to vyřešilo a CI ukázalo svou vadu** | push `819c9a3..7a4f3e7` dorazil (`ahead 0`); **oba běhy CI `failure` s 0 jobů a 0 check-runs** (#1 2026-10-03 nad `819c9a3`, #2 2026-10-06 nad `7a4f3e7`) — **žádný krok se nikdy nespustil**, podpis odpovídá vyčerpané kvóte minut u privátního repa |
| F13 | `atlas.py` **je v gitu** (commit `7a4f3e7`) | `git status` → prázdný strom |

---

## 3. ÚKOLY — v tomto pořadí

### Úkol 1 — Zprovoznit CI na GitHubu (rozhoduje uživatel, ne agent)

**Stav:** **HOTOVO** je push — 2026-10-06 dorazil `819c9a3..7a4f3e7`,
`git rev-list --count origin/main..HEAD` → `0`.

**Nový nález (měřený v API, ne odhad):** CI sice **běží**, ale **každý běh
skončí `failure` okamžitě, s 0 jobů, 0 check-runs a bez logů**:

| běh | kdy (UTC) | commit | výsledek |
|---|---|---|---|
| `#1` | 2026-10-03 12:45 | `819c9a3` | `failure`, 0 jobů, okamžitě |
| `#2` | 2026-10-06 10:59 | `7a4f3e7` | `failure`, 0 jobů, okamžitě |
| `#3` | 2026-10-06 11:07 | `036150b` | `failure`, 0 jobů, okamžitě |

**Žádný krok workflow se nikdy nespustil** — neproběhl ani download Godotu,
takže `UNVERIFIED` URL a SHA v `ci.yml` zůstávají neověřené.

**Co je vyloučené měřením:** Actions `enabled: true`, `allowed_actions: all`,
workflow `active`, token má na repo `admin: true` a scope `repo, workflow`.
**Co zbývá:** podpis odpovídá **vyčerpané kvótě minut u privátního repa**
(`visibility: private`); billing API token nevidí (404).

**Co udělat:**
1. Otevřít `https://github.com/ssevcikm-spec/game-clone/actions`, kliknout na běh
   `#3` a **přečíst hlášku** — tam je přesná příčina; případně
   `Settings → Billing → Actions`.
2. Rozhodnout, jak dál — a to je **rozhodnutí uživatele, ne agenta**:
   platit minuty, nebo **zveřejnit repo** (public repo má minuty zdarma;
   v gitu jsou jen kód a dokumentace — `assets/uo/` je gitignore, autorská díla
   UO tam nejsou), případně přesunout běhy na vlastní runner.
3. Po odblokování nechat CI proběhnout a **podívat se, co řeklo** — první
   skutečný běh je sám měření a odhalí, co je v `ci.yml` neověřené.

**Přijímací kritérium:** existuje běh CI s **nenulovým počtem jobů** a je
u něj vidět, které kroky prošly a které ne (i kdyby výsledek byl `failure`).

### Úkol 2 — Opravit rozložení v `atlas.py` (granule `assets.atlas`)

**Co je špatně:** `rozloz()` umisťuje sprity bez kontroly překryvů. Naměřeno
**117 překryvů** na stejné poličce (až **27 px ze 44**) a **17 spritů je proto
plně průhledných** (např. item 4410). `atlas.py --verify` to sám hlásí.

**Co udělat:**
1. Opravit umisťování tak, aby se sprity **nepřekrývaly** (včetně zbytku police).
2. **Předělat `--self-test` tak, aby kontrolu překryvů pouštěl na datech
   v měřítku reálné stránky** (tisíce spritů na 2 048 px), ne na 6 spritech.
   **Bez toho je oprava neprokázaná.**
3. **Vrátit do kódu vadu a podívat se, že test spadne** (mutační test) —
   a ověřit, že se mutace **skutečně provedla** (sha souboru).

**Přijímací kritérium:** `atlas.py --verify` → **0 chyb**; počet prázdných
spritů v manifestu **0**; mutace (vrácený překryv) self-test **shodí**.

**Pozor:** `assets/uo/` je gitignore — manifest se negeneruje do gitu, ale
`atlas.py` **musí být v gitu** (jinak si ho každý klon musí napsat znovu).

### Úkol 3 — `render.textures` (granule, `render/texture_cache.gd`, ≤ 60 řádků)

Cache textur z `assets/uo/manifest.json` s LRU a stropem paměti.
Smlouva: `texture(art_id) -> Texture2D`, `stats() -> {loaded, bytes}`
(`docs/04 §4.2`). Přijímací kritérium granule: **po 10 000 požadavcích
nepřekročí strop** — to je potřeba skutečně změřit, ne odhadnout.

**Závislost `world.tiledata` je hotová.** Vstup `manifest.json` existuje
(3 565 629 B, 17 436 spritů).

### Úkol 4 — `render.chunk` (granule, `render/chunk_renderer.gd`, ≤ 150 řádků, `strong`)

Sestavení kreslicího seznamu pro viditelné bloky, cache, invalidace při změně
bloku (`docs/02 §2.4`). **Toto je první věc, která něco nakreslí** — a tím se
G10 poprvé měří na skutečném snímku.

Vstupy má **všechny hotové**: `render.sort` ✅, `world.map` ✅ (a `render.textures`
z úkolu 3). Tvar objektu pro řazení je v hlavičce `render/sort.gd`
(`{kind, x, y, z}`) — **a patří doplnit do `docs/04 §4.2`** (to je vada zadání,
ne kódu).

### Úkol 5 — Zapojení do scény a systémů (NEMÁ VLASTNÍKA V ROADMAPĚ)

**Tohle je nejdůležitější úkol celé etapy.** Bez něj zůstane i hotový
`chunk_renderer` **mrtvý kód** — a to se už jednou stalo (`render.sort`).

1. **Kamera a kreslicí uzel** — `app/main.tscn` dnes nemá vlastníka a v roadmapě
   pro něj není granule. Vznikne potřeba i `app/player_controller.gd`
   (kamera + `queue_redraw`), který v roadmapě **také není**.
2. **Vada zapojení 1:** `app/main.gd:30` přidává jako dítě jen `loop` →
   `input_map.poll()` se **nikdy nezavolá**. Přidat `input_map` do stromu.
3. **Vada zapojení 2:** `sim.systems` plní jen testy → zaregistrovat systémy
   v `SimWorld` (registrace systémů patří integrační session, `docs/07 §7.3`).
4. **Vada zapojení 3:** `time.world_time_ms` nikdo nezapíše → `world.time`
   napojit na `_clock` `SimWorld` (nebo jeho vlastní pole zrušit).

**Přijímací kritérium:** `render.sort` **má volajícího z produkce**
(`check-wiring` to potvrdí), `input_map` je v stromu a `hour()` vrací jinou
hodnotu než 0 po uplynutí herního času. **A na snímku je mapa.**

### Úkol 6 — Pohyb (granule M2, v tomto pořadí závislostí)

`data.skills` (`gen-content.py --only skills`) → `entity.skills` →
`entity.mobile` → `world.walk` → `sim.movement`.

Smlouvy (`docs/04 §4.2`, `docs/05 §5.1`): prodlevy **400 / 200 / 200 / 100 ms**,
`PERSON_HEIGHT 16`, `STEP_HEIGHT 2`, diagonála asymetricky (hráč nesmí
diagonalizovat u rohu, NPC ano), `request_step`/`apply_step`/`consume_stamina`.

**Přijímací kritérium granule `sim.movement` (z roadmapy):** chůze po volné
dlaždici → `delay 400`, posun po 8 ticcích o 1 dlaždici; voda → `{ok:false}`.

**Pozor na blokátor:** animace **nejsou dekódované** (`pixels_decoded: false`).
Statická mapa a pohyb po ní jdou bez nich; **animovaná postava ne** — hráč
(tělo 400/401) je jen v `anim*.mul`. Rozhodnout, zda se v této etapě kreslí
statický sprite, nebo se rozluští RLE.

### Úkol 7 — Testy pro to, co je hotové a nemá test

`render.sort` (kandidát: „dva statiky na jedné dlaždici s různým `z` vyjdou
podle `z`" + stabilita na shodných klíčích), `world/map.gd`,
`world/tiledata.gd`. **Dnes 5 z 22 produkčních souborů nemá test** a sonda
v `.cache/analysis/` je gitignore — v čerstvém klonu ji nikdo nespustí.

---

## 4. Kritická cesta k obrazovce (nejkratší varianta)

**3 granule + 2 soubory, které v roadmapě nejsou:**

| # | Co | Soubor | řádků |
|---|---|---|---|
| 1 | `render.textures` | `render/texture_cache.gd` | ≤ 60 |
| 2 | `render.chunk` | `render/chunk_renderer.gd` | ≤ 150 |
| 3 | *(bez granule)* | `app/player_controller.gd` (kamera + `queue_redraw`) | — |
| 4 | *(bez vlastníka)* | `app/main.tscn` (uzly + kamera) | — |
| 5 | *(úprava)* | `app/main.gd` (připojení renderu + systémů + `input_map`) | — |

**Chůze navíc:** `data.skills`, `entity.skills`, `entity.mobile`, `world.walk`,
`sim.movement` = **5 granul**, ~480 řádků.

---

## 5. Otázky k rozhodnutí (agent je nerozhoduje)

Tyhle věci **nejsou technické** — rozhoduje je uživatel. Agent je smí jen
předložit s naměřenými důsledky.

1. **CI na GitHubu** — push je hotový, ale **CI selhává s 0 jobů** (běhy #1 a #2).
   Zkontrolovat kvótu minut (Settings → Billing → Actions) a rozhodnout:
   platit minuty, nebo **zveřejnit repo** (public má minuty zdarma; v gitu jsou
   jen kód a dokumentace, assety UO jsou gitignore)?
2. **`size_lines` u 21 z 31 souborů přetéká deklaraci** (až 8×: `anim.py`
   516/150, `sim_world.gd` 232/60). Uvolnit deklarace, nebo dělit granule?
3. **Světelný cyklus:** `ZADANI §10` a `docs/05 §5.11` uvádějí „den 12",
   `research/01 §4.2` má `DayLevel = 0` / `NightLevel = 12`. Které číslo platí?
   Kód dnes vrací v noci denní hodnotu a **přiznává to** v hlavičce.
4. **Animace:** rozluštit pixely z `anim*.mul` (RLE) v této etapě, nebo kreslit
   statický sprite a animace odložit? Blokuje to „postava se pohne".
5. **Pathfinding** — v `docs/` **není vůbec** (0 zmínek, 0 granul), ale
   `sim.ai` a click-to-move ho potřebují. Doplnit do zadání jako novou granuli?
6. **Zvuk a hudba** — eventy existují, žádná granule je nepřehrává. Patří do
   M8, nebo je to vlastní milník?
7. **Tři vady zapojení** (F4–F6) nemají vlastníka v roadmapě. Mají být
   integrační session, nebo nové granule?

---

## 6. Počet granul: dokumenty si odporují

| Zdroj | Počet |
|---|---|
| `.forge/roadmap.json` | **101** |
| `ZADANI-UO-KLON.md` §5, `README.md` | **100** |
| `docs/07 §7.5` (odhad) | **75–90** |

**Ovlivňuje to rozhodnutí č. 2** (dělení granul). Než se začne dělit nebo
uvolňovat, musí být jasné, který počet je správný — a to je rozhodnutí člověka.

---

## 7. Co NEDĚLAT

- **Nepushovat bez vyžádání.**
- **Nemazat `.cache/render/snapshot.png`** ani `.cache/analysis/` — jsou to
  důkazy měření (a G10 na ten snímek sahá).
- **Neměnit `docs/`, `.forge/`, `tests/` ani `project.godot`** z agently session —
  vady zadání se **hlásí**, neopravují (`docs/09 §9.10.7`).
- **Nepřidávat „vylepšení", která UO nemá** (auto-loot, rychlé cestování) —
  věrnost je cíl, ne pohodlí (`START-TADY.md` §4).
- **Nepřejmenovávat soubory kvůli zelené bráně.** `run-all.py` vracející
  `exit 1` je **pravdivý stav**; přejmenování gaty neošálí, jen schová důkaz.
- **Neopravovat brány kvůli tomu, že v sandboxu nemohou zapsat** — to je
  prostředí, ne kód.
- **Nevymýšlet čísla.** Neověřenou věc piš jako `UNVERIFIED` + co je potřeba
  změřit.

---

## 8. Required výstup této etapy

1. **Obrazovka s mapou Britainu** + screenshot, který to dokazuje
   (`read_image` na snímek z běhu, **ne** na `preview-britain.png` z extrakce).
2. **G10 zelená** — a to na **novém** snímku, ne na artefaktu z 2026-10-02.
3. **`check-wiring` bez `render.sort` v seznamu neintegrovaných.**
4. **Testy** s aktuálním počtem (`238 + nové`) a **jménem každého selhání**,
   které zůstalo — včetně rozlišení „vada kódu" vs „prostředí".
5. **`atlas.py` s `--verify` na 0 chybách** (v gitu je od `7a4f3e7`).
6. **Běh CI s nenulovým počtem jobů** — i kdyby červený, musí být vidět, které
   kroky proběhly (dnes je to 0 jobů, takže se neměří nic).
7. **`HANDOFF.md` přepsaný** na stav po práci + `LESSONS.md` s novými záznamy.
