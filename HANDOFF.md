# Předání — UO-klon (důkazní vrstva v gitu; CI má nalezenou příčinu, 2026-10-06 noc)

> **Co je tenhle soubor:** **stav projektu** pro další session agenta. Přepisuje
> se celý; historie je v `git log`. **Současný stav se bere odtud** — a ověřuje
> se živě (je tu k tomu sekce „Předletová kontrola").
> **Zadání pro další vývoj je `ZADANI-DALSI-VYVOJ.md`** (založeno 2026-10-06
> auditem, který neměnil kód). Tenhle soubor říká, **kde jsme**; tamten, **co dělat**.
> **Datum:** 2026-10-06 (noc). **Poslední změna kódu:** tato session (důkazní
> vrstva + příčina CI; předchozí commit `505bf65` = handoff a lekce k assetům).

## ✅ CO JE NOVÉHO (tato session) — příčina CI je nalezená a důkazy jsou v gitu

| Co | Doklad (naměřeno dnes) |
|---|---|
| **Příčina 9 mrtvých běhů CI** | GitHub UI u běhu **#4 i #9** píše `Invalid workflow file: .github/workflows/ci.yml#L56 / You have an error in your yaml syntax on line 56`. Řádek 56 = `- name: Godot: import, testy, snímek (boot.ci_env)` — **dvojtečka s mezerou uvnitř neuvozovkovaného skaláru** je neplatný YAML. Hlášku vytáhl `_analyza/ci-ui-banner.mjs` z HTML běhu (API ji nenese) |
| **Oprava ověřená parserem** | jméno kroku v uvozovkách; `_analyza/yaml-kontrola.py` (PyYAML) **3 ze 3**: vrácená dvojtečka → chyba na **spočítaném** řádku, tabulátor → chyba, současný `ci.yml` bez chyby |
| **Běhů je 9, ne 5** | `GET /actions/runs?per_page=6` → `total_count: 9`; nejnovější `#9` = `505bf65` (HEAD), i `#5`–`#9` selhaly s **0 jobů** |
| **`run-all.py` poprvé 0 vad a 0 NEMĚŘENO** | `SOUHRN: měřeno 11, čeká 0, chyb 0`, **`exit 0`** (odemklo G9) |
| **G9 měřeno — a citlivost ZMĚŘENA** | `tests/replays/tic_200.json`, `tic_1000.json` (hash z běhu, ne vymyšlený). `_analyza/replay-zmer.py`: **jiné příkazy při stejných ticích = STEJNÝ hash**, jiný počet tiků = jiný. Dnes tedy replay měří čas, ne mechaniky (v `popis` replaye je to napsané) |
| **Důkazní vrstva je v GITU** | `tests/cases/render_sort.gd`, `tests/cases/world_map.gd`, `tests/fixtures/world/` (včetně `.idx` s výjimkou v `.gitignore`), `tools/gates/mutace-tests.py` |
| **Mutace: 21 z 21** | harness u každé mutace ověří **PROVEDENÁ** (text na disku) + **PROBĚHLÁ** (`N kontrol`, N>0) + **CHYCENÁ** (FAIL daného modulu) + **smlouva o vstupu** (neexistující cesta musí test shodit) |
| **Testy hry** | **276 kontrol / 0 selhání** (bylo 238) |
| **Self-testy bran** | **19 self-testů, 0 chyb**, `exit 0`; `check-render` má nový případ `bez_assetu` (5 případů, 0 chyb) |
| **G10/G6 v klonu bez assetů** | hlásí **NEMĚŘENO**, ne VADA (ověřeno self-testem `bez_assetu`); krok CI s bránami navíc **toleruje `exit 2`** s warningem — vada (`exit 1`) shodí krok vždy |
| **Simulace CI (klon bez `assets/uo`)** | worktree z `HEAD` (286 souborů, **0 B assetů**): `run-all.py` → **9 měřeno / 2 NEMĚŘENO (G6, G10) / 0 vad**, `exit 2`; self-testy **19/0**; **testy hry 270/0** (o 6 méně = reálná data se neměří); **G9 OK i v klonu** (replaye jsou v gitu). Simulace po měření uklizena (`git worktree remove`) |
| **URL Godotu v CI ověřena** | `HEAD` na `…/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` → **HTTP 200, 77 860 424 B** a jméno assetu sedí na `unzip`/`mv` ve workflow (workflow to měl jako `UNVERIFIED`) |
| **NÁLEZ: `run-all.py` u G3 nic nevypíše** | když G3 selže, je v logu jen `G3 VADA vada` — bez čísel a bez důvodu (`run_tests_gate()` nevolá `gate.finish()`). Dnes mě to dvakrát poslalo hledat vadu testů, která nebyla (jednou sandbox, jednou zapomenutý `$GODOT`) |
| **Doba běhů (kvůli limitu CI 30 min)** | naměřeno lokálně: `run-all.py` **17,8 s**, testy hry **0,6 s**, `mutace-tests.py` **14,3 s** (26 běhů Godotu). I s několikrát pomalejším runnerem je limit 30 min s rezervou |
| **NÁLEZ: harness tiše přeskočí rozbitý case** | `tests/cases/render_sort.gd` s parse errory → `258 kontrol, 0 selhání, exit 0` a **žádný FAIL** (soubor se vůbec nespustil). Otevřená věc 21 |

**Co to znamená pro „CI je zelené":** příčina, kvůli které **neběžel ani jeden
job**, je nalezená a opravená; brány jsou lokálně 0/0; a prostředí CI (klon bez
`assets/uo`) je ošetřené (G6/G10 NEMĚŘENO, testy hry projdou nad fixture).
**Že je CI zelené, se ale ještě NEMEŘILO** — ověří to až běh po pushi.

## ⚠ POVINNÉ: na konci každé session (rozhodnutí uživatele, 2026-10-03)

Uživatel volá **na každý krok novou session** a **po každé implementaci hned
následuje předání**. Proto platí:

1. **`LESSONS.md`** — přidej záznamy za tuhle session (ponaučení, chyby,
   osvědčené postupy, nové nástroje). Šablona je v hlavičce toho souboru.
   Piš i to, co **nevyšlo**; zápis bez měření je dohad.
2. **`HANDOFF.md`** — přepiš ho na stav po své práci, ale **tuhle sekci
   zkopíruj doslova dál** (jinak pravidlo zmizí). Aktualizuj hlavně: co je
   hotové a ověřené, co je **otevřené a proč**, a co je příští krok.
3. **Ověř před předáním:** brány (`run-all.py`), testy hry, self-testy —
   a napiš do předání **skutečná čísla**, ne ta z minula.
4. **Commitni** (strom čistý) — `LESSONS.md` i `HANDOFF.md` patří do gitu,
   protože další session je čte odtud.

## ⚠⚠ BLOKÁTORY

1. **„CI je zelené" NENÍ ZMĚŘENÉ — chybí jen push.** Příčina (neplatný YAML na
   řádku 56) je nalezená, opravená a ověřená parserem; běhy `#1`–`#9` přitom
   selhaly **všechny**, takže oprava nebyla nikdy vyzkoušena na GitHubu.
   **Uživatel rozhoduje o pushi** (pravidlo „nepushovat bez vyžádání" platí).
   Až se pushne: ověřit, že běh má **nenulový počet jobů**, a číst
   `summary.json` z artefaktu.
2. **`tests/run_tests.gd` tiše přeskočí case soubor s parse errory** (naměřeno,
   viz „Co je nového" a otevřená věc 21). Oprava patří vlastníkovi (`boot.tests`):
   před `script.new()` volat `script.can_instantiate()`. Do té doby platí, že
   „0 selhání" **samo o sobě** neznamená, že všechny case soubory proběhly —
   proto to hlídá `tools/gates/mutace-tests.py`.
3. ~~`tools/uoextract/atlas.py`: vada rozložení~~ — **VYŘEŠENO 2026-10-06**
   (0 překryvů, 0 prázdných, 41 874 spritů na 67 stranách, `--verify` 0 chyb)
   a **pushnuto** (`72a4c0a`).

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| **Zadání pro další vývoj** | **`ZADANI-DALSI-VYVOJ.md`** (naměřená cesta k obrazovce, zapojení bez vlastníka) |
| **Ponaučení a nástroje** | **`LESSONS.md`** — čti prvních pár záznamů, ať neopakuješ chyby |
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Generátor obsahu | `python tools/gates/gen-content.py [--check] [--only items\|recipes]` |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` pak `godot --headless --path . --script res://tests/run_tests.gd` → **276 kontrol / 0 selhání** |
| Brány | `python tools/gates/run-all.py` → **11 měřeno / 0 NEMĚŘENO / 0 chyb**, `exit 0` |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → **19 self-testů, 0 chyb**, `exit 0` |
| **Mutační důkaz testů** | `python tools/gates/mutace-tests.py [--only sort\|map]` → **21 z 21 chyceno**, `exit 0` (běží ~25× Godot, trvá minuty) |
| **Fixture pro `world.map`** | `python tests/fixtures/world/make_fixture.py [--check]` (4 soubory: `map0.meta.json`, `.land`, `.statics.idx`, `.statics.bin`) |
| **Replaye pro G9** | `tests/replays/tic_200.json`, `tic_1000.json`; citlivost měří `_analyza/replay-zmer.py` |
| **Snímek z běhu** | `godot --path . --rendering-driver opengl3 --resolution 1280x720 --write-movie .cache/render/run-<tag>/frame.png --quit-after 5` → první frame se kopíruje na `.cache/render/snapshot.png` (dělá to `.cache/analysis/mutace-snimek.py`) |
| **Sonda renderu + mutace** | `godot --headless --path . --script res://.cache/analysis/probe-render.gd` · `python .cache/analysis/mutace-render.py` · `python .cache/analysis/mutace-snimek.py` |
| **Kontrola YAML workflow** | `python _analyza/yaml-kontrola.py` (potřebuje PyYAML; `.cache/pylib` přes `PYTHONPATH`) |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable.official.ed1daf0bf) |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení; `map0.mul` tam **není** — mapa je v `map0LegacyMUL.uop`) |
| Roadmapa | `.forge/roadmap.json` — **101 granul, `done` je u všech `false`**: stav se pozná **jen měřením** |
| Data z instalace | `assets/uo/` (gitignore) — `tiles.json` 2 405 685 B, `manifest.json` **8 649 632 B** (41 874 spritů, 67 stran), `world/map0.land` 89 915 392 B, `world/map0.statics.bin` 20 386 415 B, `atlas/*.png` 115 153 521 B |
| Důkazy měření (gitignore) | `.cache/analysis/probe-render.gd`, `mutace-render.py`, `mutace-snimek.py`, `probe-input-map.py`, `probe-wiring-intrafile.py`; nově `_analyza/{ci-ui-banner.mjs,ci-vytah.py,yaml-kontrola.py,replay-zmer.py}` |

## Stav kódu (počty řádků Pythonem `splitlines()`, bez `.uid` a `__pycache__`)

| složka | souborů (kód) | řádků kódu | poznámka |
|---|---|---|---|
| `core/` | 7 | 339 | hotové a otestované |
| `sim/` | 8 | **953** | **`systems` je stále prázdné — plní ho jen testy**; `world/map.gd` 199 → **210** řádků (volitelné cesty) |
| `render/` | 3 | 311 | `sort.gd` (60) + `texture_cache.gd` + `chunk_renderer.gd`; `ui/` pořád neexistuje |
| `app/` | 4 | 306 | `world_view.gd` (bez granule!); `main.gd` připojuje sim, loop i svět |
| `tests/` | **19** | **1 602** | **16 case souborů** (+2 nové: 259 a 169 řádků), `lib.gd`, `run_tests.gd`, 2 replaye, fixture (127řádkový generátor + 4 data) |
| `tools/uoextract/` | 38 | 5 910 | 12 produkčních + 26 jednorázových experimentů |
| `tools/gates/` | **18** | **3 486** | 10 bran + `run-all.py`, `gen-content.py`, `gate_common.py`, `sim_probe.gd`, **`mutace-tests.py`** (236 řádků) |

*(Počty jsou Pythonem `splitlines()` nad kódovými soubory `.gd`/`.py`/`.sh`/`.mjs`,
bez `.uid` a `__pycache__` — `python _analyza/radky.py`.)*

**Zbývá 62 granul.** `render.textures` a `render.chunk` už soubor **mají**
(`granuli_s_hotovym_souborem` 39).

## Co je hotové a ověřené (ne „soubor existuje")

**M0 celek** · **W0** (8) · **M1: uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc, anim, data.items, data.gen_content, data.recipes,
world.tiledata, world.map, render.sort, render.textures, render.chunk** ·
**M2: world.doors, world.stairs, entity.stats, world.time**.

Doklady, které jsem dnes viděl na vlastní oči (ne opsané z předání):

- **Důkazní vrstva pro `render.sort` a `world.map` je v gitu a je prokázaná
  mutacemi** — `tools/gates/mutace-tests.py`: **21 z 21** (10× `render/sort.gd`,
  11× `sim/world/map.gd`), u každé mutace PROVEDENÁ + PROBĚHLÁ + CHYCENÁ,
  navíc smlouva o vstupu (neexistující cesta test shodí).
- **`world.map` měří i bez assetů** — fixture `tests/fixtures/world/`
  (2×3 bloky) + nezávislý parser `.land`/`.statics.idx`/`.bin`; reálná data
  Británie se měří **navíc**, když na disku jsou.
- **G9 měří a je vidět, co měří** — 2 replaye, hash z běhu; citlivost na příkazy
  je dnes **nulová** (měřeno) a je to napsané v replayi i v předání.
- **Na obrazovce je mapa Britainu** — snímek z běhu (2117 barev, 891 383 px mimo
  pozadí), G10 OK.
- **Hra nespadne**: G11 `smoke` → `framu 120, script_error 0, parse_error 0`.
- **Testy hry**: 276 kontrol / 0 selhání.

### ⚠ Co na obrazovce ještě NENÍ

Postava, animace (pixely `anim*.mul` **nejsou dekódované**, `pixels_decoded: false`),
pohyb, UI, světlo. Simulace pořád **nemá ani jednu systémovou jednotku**:
`SYSTEM_ORDER` (`sim/sim_world.gd:34-37`) vypisuje 15 systémů, `systems` je
prázdný slovník a v celém repu ho plní **jen `tests/cases/sim_world.gd:85-87`**.
`move` skončí hláškou „Not available yet: move -> movement.request_step".
**Hratelná mechanika: nula.**

## Co brány dnes měří (2026-10-06 noc, plný přístup)

`run-all.py`: **11 měřeno / 0 NEMĚŘENO / 0 VADA**, `exit 0`.

| Brána | Výsledek | Je to vada kódu? |
|---|---|---|
| G1, G2, G3, G4, G5, G6, G7, G8, G9, G10, G11 | **OK** | NE |
| G13 | PORADNÍ | NE — `vision.mjs` není (poradní je podle `docs/08 §8.2`) |

**Pozor na srovnání s minulým předáním (10/1/0, `exit 2`):** tehdy chybělo G9
(prázdné `tests/replays/`). Dnešní `exit 0` je **změna stavu**, ne jiné prostředí
— a prostředí přitom sehrálo roli dvakrát: v sandboxu `workspace-write` vyšlo
`7/2/2` a `run-all.py` spadl na `summary.json`, protože `.cache` nejde zapsat
(otevřená věc 20 → dnes uzavřená jako past, viz `LESSONS`).

## Předletová kontrola (5 minut, než začneš psát)

| Co | Jak | Očekáváno (2026-10-06 noc) |
|---|---|---|
| Přečtené zadání | `ZADANI-DALSI-VYVOJ.md` | cesta k obrazovce + zapojení bez vlastníka |
| Strom je čistý | `git status --porcelain -uall` | **prázdné** po commitu této session |
| Je před GitHubem | `git rev-list --count origin/main..HEAD` | **`1`+** — tato session **nepushuje bez vyžádání** |
| **Běží CI?** | `https://github.com/ssevcikm-spec/game-clone/actions` | **běhy #1–#9 `failure`, 0 jobů**; příčina (neplatný YAML) je opravená v commitu, ale **pushnutá ještě není**. V simulaci klonu bez assetů dnes `9/2/0`, `exit 2` — přesně to krok CI toleruje |
| Repo je veřejné | API bez tokenu | `visibility: public` |
| Testy | testy s `APPDATA` ve workspace | `276 kontrol, 0 selhání` |
| Brány | `python tools/gates/run-all.py` | `11/0/0`, `exit 0` |
| Self-testy | `python tools/gates/run-all.py --self-test` | `19, 0 chyb`, `exit 0` |
| Mutační důkaz | `python tools/gates/mutace-tests.py` | `21 z 21`, `exit 0` |
| Fixture sedí na generátor | `python tests/fixtures/world/make_fixture.py --check` | `4× OK`, `exit 0` |
| **Snímek je z běhu** | `Get-Item .cache/render/snapshot.png \| % LastWriteTime` | **dnešní** (ne 2026-10-02) |
| Godot běží | `& .cache\godot\...console.exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |
| Instalace UO na místě | `Test-Path 'D:\Games\...\tiledata.mul'` | `True` |
| Kontroly zadání | `check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check` | `exit 0` |
| **Sandbox** | `whoami /groups \| Select-String Mandatory` | **`Medium`** = plný přístup. `Low` znamená, že G7/G11 hlásí falešnou vadu a `run-all.py` spadne na `summary.json` |

## Otevřené věci a co je potřeba dodělat

**Přenáším z minulého předání (nic se nemaže) — u každé je dnešní stav:**

1. **`render.sort` a `world.map` neměly test v `tests/cases/`** — **VYŘEŠENO
   2026-10-06** (nové `tests/cases/render_sort.gd`, `tests/cases/world_map.gd`;
   `tests/` se tím výjimečně rozšířilo o nové soubory, **existující testy se
   nezměnily**, rozhodl uživatel). Bez testu zůstávají `world/tiledata.gd`,
   `app/main.gd`, `app/main.tscn`, `render/texture_cache.gd`,
   `render/chunk_renderer.gd` → **5 souborů** (dřív 8).
2. **`size_lines` nesedí** — **PLATÍ DÁL:** `world.map` **210**/120,
   `render/texture_cache.gd` 141/60, `render/chunk_renderer.gd` 110/150,
   `app/world_view.gd` (bez deklarace). `sim/world/map.gd` dnes navíc **+11
   řádků** (volitelné cesty). **Rozhodnutí pro uživatele:** uvolnit deklarace,
   nebo dělit granule.
3. **Tvar objektu pro `render.sort` patří do `docs/04 §4.2`** — **PLATÍ DÁL**;
   navíc tvar prvku `render.chunk` a rozšíření `world.map.statics_at` o `x`,`y`.
4. ~~G10 měří snímek z bootstrapu~~ — **VYŘEŠENO 2026-10-06.**
5. **13 generátorů v `POZADOVANÉ` chybí** — **PLATÍ DÁL.**
6. **Pixely animací** — **PLATÍ DÁL a je to blokátor** (`pixels_decoded: false`).
7. **`assets.uop` (2 rozpory) a `assets.verify`/`assets.extract_cli`** — **PLATÍ DÁL.**
8. **Zastaralé poznámky v `tools/uoextract/worldmap.py`** — **PLATÍ DÁL.**
9. ~~`atlas.py`: vada rozložení~~ — **VYŘEŠENO 2026-10-06.**
10. **`docs/11 §11.6` vs `docs/03 §3.5.1`** — **PLATÍ DÁL** (vnitřní rozpor).
11. **Počet granul v dokumentech: 101 / 100 / 75–90** — **PLATÍ DÁL.**
12. **Světlo „den 12" vs `DayLevel = 0`** — **PLATÍ DÁL.**
13. **Rešerše hlásily dvě „vady", které neobstály** — **PLATÍ DÁL** jako varování.
14. **CI neproběhlo ani jednou s nenulovým počtem jobů** — **PLATÍ DÁL**, ale
    **už je známá příčina**: neplatný YAML na řádku 56 (`ci.yml`), opraveno.
    Ověří až běh po pushi (blokátor 1).
15. **`statics_at` vrací nadmnožinu** — **PLATÍ DÁL** (vada ZADÁNÍ, `docs/` agent nemění).
16. **`check-wiring` nevidí volání UVNITŘ granule** — **PLATÍ DÁL** (vada brány).
17. **`app/world_view.gd` a uzly v `app/main.tscn` nemají vlastníka** — **PLATÍ DÁL.**
18. **`app/input_map.gd` se volá bez vazeb** (`ui.hotkeys` nemá soubor) — **PLATÍ DÁL.**
19. **Výkonnostní dluh: `AtlasTexture` na objekt** (`UNVERIFIED`, žádné tvrzení o FPS) — **PLATÍ DÁL.**
20. **⚠ AŽ CI OŽIJE, BUDE ČERVENÉ — a nebude to vada kódu** — **VYŘEŠENO
    2026-10-06 (rozhodnutí uživatele = varianta (a)):** G6 v klonu bez assetů
    hlásí NEMĚŘENO (uměla to už dřív), **G10 to nově také umí**
    (`check-render.py`: `ASSET_INPUTS`, `missing_assets`, self-test `bez_assetu`),
    a **krok CI s bránami toleruje `exit 2`** (NEMĚŘENO) s warningem, protože
    `docs/08 §8.2` to tak od začátku myslí — „proto CI nepadá na 2". Vada
    (`exit 1`) shodí krok vždy. **Zbývá ověřit živým během.**
21. **NOVÉ: `tests/run_tests.gd` tiše přeskočí case soubor s parse errory.**
    Naměřeno: `render_sort.gd` s chybou inference → `258 kontrol, 0 selhání,
    exit 0` a **žádný FAIL**; `load()` vrátí GDScript, `script.new()` vyhodí
    `Invalid call` a `_init_case()` se **přeruší dřív, než zavolá `_pending()`**.
    Oprava (vlastník `boot.tests`): `if not script.can_instantiate(): _pending(...)`.
    Do té doby je „0 selhání" slabé — proto ho váže na mutační harness.
22. **NOVÉ: replay neměří příkazy** (měřeno: jiné příkazy = stejný hash).
    Až se do `SimWorld` zaregistrují systémy (`sim.movement`…), replaye **přeměřit**
    a hash aktualizovat — jinak zůstane G9 zelená nad časem, ne nad mechanikami.
23. **NOVÉ: `sim/world/map.gd` má volitelné cesty** (`_init(prefix)`), aby šel
    testovat bez `assets/uo`. Výchozí hodnota je tatáž cesta jako dřív, takže
    chování hry se nemění; patří to do smlouvy (`docs/04 §4.2`) jako `world.map`.
24. **NOVÉ: `.gitignore` má výjimku `!tests/fixtures/world/*.idx`** — bez ní by
    fixture indexu chyběla v CI (`*.idx` je ignorováno case-insensitive).
    Kdo přidá další fixture s jinou příponou, narazí na totéž.
25. **NOVÉ: `run-all.py` u G3 nevypíše, co naměřila.** Když G3 selže, je v logu
    jen `G3 VADA vada` (souhrn) — bez čísel a bez důvodu, protože
    `run_tests_gate()` nikdy nezavolá `gate.finish()`. Naměřeno dvakrát dnes
    (sandbox s Low integritou; zapomenutý `$GODOT` → exit 127) a **pokaždé to
    vypadalo jako vada testů**. Oprava patří vlastníkovi (`boot.gates`).

## Už není otevřené (přesunuto, nemaže se)

- **„Na obrazovce není nic"** — vyřešeno 2026-10-06 (snímek z běhu, G10 zelená).
- **„`render.sort` nemá volajícího z produkce"** — vyřešeno (`draw_order`).
- **„G10 měří 4 dny starý artefakt"** — vyřešeno.
- **„Repo je privátní"** — vyřešeno 2026-10-06.
- **„12 commitů není před GitHubem"** — vyřešeno.
- **„`tools/uoextract/atlas.py` není v gitu"** — vyřešeno (`7a4f3e7`).
- **„`assets.atlas` není hotový"** — vyřešeno.
- **Podezření, že brány jsou zelené nad vadou** — **prověřeno i dnes**: každá
  nová kontrola je doložená mutací (21/21), ne dojmem.
- **Podezření, že v repu jsou tajemství** — prověřeno 2026-10-06.
- **„`render.sort`/`world.map` měří jen gitignore sonda"** — vyřešeno 2026-10-06.
- **„Replaye nemá co měřit"** (G9 NEMĚŘENO) — vyřešeno 2026-10-06 (2 replaye).

## Další kroky (v tomto pořadí)

1. **Pushnout a podívat se, jestli CI opravdu běží** (rozhodnutí uživatele;
   bez pushnutí zůstává „CI je zelené" nezměřené). Čekat **nenulový počet jobů**;
   když běh projde, přečíst artefakt `summary.json` a porovnat s lokálními čísly.
2. **Opravit slepé místo v `tests/run_tests.gd`** (`script.can_instantiate()`)
   a přidat na to self-test harnessu — jinak zůstává „0 selhání" slabé.
3. **Zapsat `tests/cases/` i pro `render/texture_cache.gd` a
   `render/chunk_renderer.gd`** (dnes je měří jen gitignore sonda; postup je
   hotový: fixture + mutační harness).
4. **`app/player_controller.gd` / pohyb kamery** — `world_view.gd` kameru jen
   nastaví; klávesy nejsou namapované (věc 18).
5. **Pixely animací** (`anim*.mul`, RLE) — blokátor „postava se pohne".
6. Pak M2: `data.skills` → `entity.skills` → `entity.mobile` → `world.walk` →
   `sim.movement`; a **zaregistrovat systémy do `SimWorld`** (věc 2 a 22).

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Mutační test je to, co odlišuje měření od dojmu** — a musí ověřit **čtyři**
  věci: že se mutace provedla, že test **proběhl** (`N kontrol`, N > 0), že
  selhal **na kontrole daného modulu**, a že test **bere měřenou cestu
  z argumentů** (zkus mu předat neexistující cestu — musí selhat).
- **Druhá implementace téhož formátu je jediná obrana** — nezávislý parser
  `.land`/`.statics.bin` našel vadu `z` za minutu a dnes je **v gitu**
  (`tests/cases/world_map.gd`).
- **Data, která v CI nejsou, testuj na fixture v gitu** — a reálná data měř
  navíc, když jsou; když nejsou, řekni to nahlas (NEMĚŘENO), ale neselhávej.
- **Hotový soubor bez volajícího je mrtvý kód** — ptej se „kdo to volá".
- **Než začneš psát, ověř, že všechny vstupy granule mají PRODUCENTA.**
- **Když implementace odhalí díru ve smlouvě, napiš ji do hlavičky souboru**
  (`sim_world.gd`, `time.gd`, `map.gd`) a zaznamenej jako otevřenou věc.

## Pasti, které už někoho stáhly čas (naměřené)

1. **`==` na `Array` v GDScriptu porovnává OBSAHEM** — na identitu `is_same()`.
2. **V mutačním harnessu musí test brát všechny měřené cesty z argumentů** —
   jinak se mutant do kontroly vůbec nedostane. Dnes to hlídá „smlouva o vstupu".
3. **Test stropu musí pracovní sadu PŘEKROČIT** (10 000 požadavků na jedné stránce).
4. **`"MERENO:"` je podřetězec `"NEMERENO:"`** — parsuj i s hranatou závorkou.
5. **`provides` bez `(` není „volatelné jméno"** (`check-wiring`).
6. **Sandbox `workspace-write` (Low integrita) blokuje zápis do `.cache`** →
   G7 hlásí falešnou vadu, G11 NEMĚŘENO a `run-all.py` padá na `summary.json`.
   **Tato práce potřebuje plný přístup** (`whoami /groups` → `Medium`).
7. **`map0.land` má na každém bloku 4B hlavičku** — čti od `key * 196 + 4`.
8. **Statika je 7 B `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`** — `z` na offsetu 4.
9. **Godot s nerozjetým skriptem visí** — vždy `--quit-after N`.
10. **`.uid` vzniká jen při `--import`** a **patří do gitu** (nové soubory dnes).
11. **`JSON.parse_string` vrací všechna čísla jako `float`** — vždy `int()`.
12. **`.gitignore` je na Windows case-insensitive** — kontroluj `git ls-files`
    (dnes: `*.idx` pohltilo fixture, proto výjimka).
13. **`Measure-Object -Line` nepočítá prázdné řádky** — měř Pythonem.
14. **Brána, která nic nezměří, není zelená** (`exit 2` = NEMĚŘENO).
15. **Heredoc v PowerShellu neexistuje** — piš skript do souboru.
16. **Snímek pro G10 vzniká jen s `--rendering-driver opengl3`.**
17. **`Get-Content \| -replace \| Set-Content` zničí `.py`** — spojí řádky do
    jednoho a přidá BOM (dnes skutečně stalo); edituj tool `edit`/`write`
    a ověř první tři bajty (`EF BB BF` = BOM).
    **A druhá polovina téhož:** Python `write_text()` na Windows vyrobí **CRLF**,
    kde git (`.gitattributes: * text=auto eol=lf`) uloží **LF** — naměřeno dnes:
    `tests/replays/tic_200.json` měl na disku **565 B**, v blobu **543 B**
    (`.cache`-style past „necommitnutá změna, která neexistuje“). Autorita je
    **blob**: `python _analyza/blob-vs-disk.py` (8 z 10 shod, pak opraveno na 10/10).
18. **`script.new()` na souboru s parse errory přeruší volající funkci** —
    ne `assert`, ale tichý skip (věc 21).

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03 §3.4` — index bloku mapy**: opraveno na `bx * blocks_y + by`.
2. **`docs/03 §3.4` — záznam statiky**: `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`.
3. **`docs/04 §4.2` u `world.tiledata`** uvádí `data/tiles.json` a
   `assets/uo/manifest.json`; správně `assets/uo/tiles.json` a `data/items.json`.
4. **`docs/04 §4.2` u `world.map`** nerozlišuje `tiledata id` a `art id` u statiků.
5. **`docs/04 §4.2` u `render.sort` neuvádí tvar objektu** (a nově ani
   u `render.chunk`, `render.textures`); **nově chybí i `world.map` s volitelnými
   cestami** (`_init(prefix)`) a tvar `tests/fixtures/world/` — věc 23.
6. **`docs/06 §6.2`** uvádí 6 nástrojů, které v instalaci NEJSOU.
7. **`.forge/roadmap.json` — `size_lines` nesedí** (věc 2).
8. **`app/main.tscn` + kamera + kreslicí uzel nemají vlastníka** v roadmapě.
9. **V roadmapě chybí vlastník pro pathfinding.**
10. **Soubor pro zvuk/hudbu nemá žádná granule** (0× `AudioStream`).
11. **`docs/07 §7.3` (vlny) pokrývá 62 granul z 101.**
12. **`ZADANI-DALSI-VYVOJ` §7 zakazuje měnit `tests/`, ale acceptance
    `render.textures`/`render.chunk` žádá `tests`** — uživatel 2026-10-06 povolil
    **nové** soubory v `tests/cases/`; rozpor v textu zadání tím ale nezmizel.
13. **NOVÉ: `docs/09 §9.6` (mutační test) neuvádí čtvrtou podmínku** — že test
    bere měřenou cestu z argumentů. Bez ní mutace „projdou" (naměřeno dřív).

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (`docs/02 §2.6.8`).
- **Nečeské znaky nepatří do identifikátorů** — GDScript je neumí.
- Piš **jen do `owns`** své granule; `tests/`, `project.godot`, `.forge/`,
  `docs/`, `assets/uo/` needituju — **výjimka 2026-10-06: nové soubory
  v `tests/cases/`, `tests/replays/`, `tests/fixtures/` a `tools/gates/`
  (rozhodl uživatel)**.
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet.
- `run-all.py`: 0 = vše měřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není zelená).
- Testy potřebují `APPDATA` ve workspace; **brány si to nastavují samy**
  (`tools/gates/gate_common.py:219`).
- **Nepushovat bez vyžádání.** Tato session commitne, ale **nepushuje**.
